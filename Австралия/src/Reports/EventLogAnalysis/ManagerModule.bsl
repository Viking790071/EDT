#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// See ReportsOptionsOverridable.CustomizeReportOptions. 
//
Procedure CustomizeReportOptions(Settings, ReportSettings) Export
	ReportSettings.DefineFormSettings = True;
	
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.SetOutputModeInReportPanes(Settings, ReportSettings, False);
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UsersActivityAnalysis");
	OptionSettings.Details = 
		NStr("ru = 'Позволяет выполнять мониторинг активности пользователей
		|в программе (насколько интенсивно и с какими объектами работают пользователи).'; 
		|en = 'Users activity in the application 
		|(total load and affected objects).'; 
		|pl = 'Umożliwia monitorowanie aktywności użytkowników
		|w programie (jak intensywnie i z jakimi obiektami pracują użytkownicy).';
		|es_ES = 'Eso permite vigilar la actividad de usuarios
		|en la aplicación (cuánto intensivo y con qué objetos los usuarios trabajan).';
		|es_CO = 'Eso permite vigilar la actividad de usuarios
		|en la aplicación (cuánto intensivo y con qué objetos los usuarios trabajan).';
		|tr = 'Uygulamadaki kullanıcı aktivitesinin izlenmesini 
		|sağlar (kullanıcıların ne kadar yoğun ve hangi nesnelerle çalıştığı).';
		|it = 'Permette di monitorare l''attività degli utenti 
		| nel programma (quanto intensamente e con quali oggetti gli utenti lavorano).';
		|de = 'Ermöglicht die Überwachung der Benutzeraktivitäten
		|im Programm (wie intensiv und mit welchen Objekten die Benutzer arbeiten).'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UserActivity");
	OptionSettings.Details = 
		NStr("ru = 'Подробная информация о том,
		|с какими объектами работал пользователь в программе.'; 
		|en = 'Objects affected by user activities
		|(detailed).'; 
		|pl = 'Obiekty z którymi pracował użytkownik,
		|(szczegółowe).';
		|es_ES = 'Información detallada sobre
		|los objetos con los cuales el usuario ha trabajado en la aplicación.';
		|es_CO = 'Información detallada sobre
		|los objetos con los cuales el usuario ha trabajado en la aplicación.';
		|tr = 'Kullanıcının uygulamada 
		|çalıştığı nesneler hakkında ayrıntılı bilgi.';
		|it = 'Informazioni dettagliate su 
		| quali oggetti ha lavorato con l''utente nel programma.';
		|de = 'Ausführliche Informationen über die Objekte,
		|mit denen der Benutzer im Programm gearbeitet hat.'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "EventLogMonitor");
	OptionSettings.Details = NStr("ru = 'Список критичных записей журнала регистрации.'; en = 'Event log records with ""Critical"" importance.'; pl = 'Lista krytycznych wpisów w dzienniku wydarzeń.';es_ES = 'Lista de entradas críticas en el registro de eventos.';es_CO = 'Lista de entradas críticas en el registro de eventos.';tr = 'Olay günlüğündeki kritik girişlerin listesi.';it = 'Elenco delle voci di registro critiche.';de = 'Liste kritischer Einträge im Ereignisprotokoll.'");
	OptionSettings.SearchSettings.TemplatesNames = "EvengLogErrorReportTemplate";
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "ScheduledJobsDuration");
	OptionSettings.Details = NStr("ru = 'Выводит график выполнения регламентных заданий в программе.'; en = 'Scheduled jobs schedule.'; pl = 'Wyświetla harmonogram zaplanowanych prac w aplikacji.';es_ES = 'Visualiza el horario de tareas programadas en la aplicación.';es_CO = 'Visualiza el horario de tareas programadas en la aplicación.';tr = 'Uygulamada zamanlanmış iş programını görüntüler.';it = 'Programma processi pianificati:';de = 'Zeigt den geplanten Jobplan in der Anwendung an.'");
	OptionSettings.SearchSettings.TemplatesNames = "ScheduledJobsDuration, ScheduledJobsDetails";
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region Private

// Gets information on user activity during the specified period from the event log.
// 
//
// Parameters:
//    ReportParameters - Structure - with the following properties:
//    * StartDate          - Date   - the beginning of the report period.
//    * EndDate       - Date   - the end of the report period.
//    * User        - String - a user to analyze activity.
//                                     Use this parameter for the "User activity" report option.
//    * UsersAndGroups - ValueList - the values are user group(s) and/or user(s) to analyze activity.
//                                     
//                                     Use this parameter for the "Users activity analysis" report option.
//    * ReportOption       - String - "UserActivity" or "UsersActivityAnalysis".
//    * OutputTasks      - Boolean - shows whether to get tasks data from the event log.
//    * OutputCatalogs - Boolean - shows whether to get catalogs data from the event log.
//    * OutputDocuments   - Булево -shows whether to get documents data from the event log.
//    * OutputBusinessProcesses - Boolean - shows whether to get business processes data from the event log.
//
// Returns:
//  ValueTable - a table with ungrouped user activity data from the event log.
//     
//
Function EventLogData(ReportParameters) Export
	
	// Preparing report parameters.
	StartDate = ReportParameters.StartDate;
	EndDate = ReportParameters.EndDate;
	User = ReportParameters.User;
	UsersAndGroups = ReportParameters.UsersAndGroups;
	ReportOption = ReportParameters.ReportOption;
	
	If ReportOption = "UserActivity" Then
		OutputBusinessProcesses = ReportParameters.OutputBusinessProcesses;
		OutputTasks = ReportParameters.OutputTasks;
		OutputCatalogs = ReportParameters.OutputCatalogs;
		OutputDocuments = ReportParameters.OutputDocuments;
	Else
		OutputCatalogs = True;
		OutputDocuments = True;
		OutputBusinessProcesses = False;
		OutputTasks = False;
	EndIf;
	
	// Generating source data table.
	SourceData = New ValueTable();
	SourceData.Columns.Add("Date", New TypeDescription("Date", , , New DateQualifiers(DateFractions.Date)));
	SourceData.Columns.Add("Week", New TypeDescription("String", , New StringQualifiers(10)));
	SourceData.Columns.Add("User");
	SourceData.Columns.Add("WorkHours", New TypeDescription("Number", New NumberQualifiers(15,2)));
	SourceData.Columns.Add("StartsCount", New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("DocumentsCreated", New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("CatalogsCreated", New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("DocumentsChanged", New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("BusinessProcessesCreated",	New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("TasksCreated", New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("BusinessProcessesChanged", New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("TasksChanged", New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("CatalogsChanged",	New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("Errors", New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("Warnings", New TypeDescription("Number", New NumberQualifiers(10)));
	SourceData.Columns.Add("ObjectKind", New TypeDescription("String", , New StringQualifiers(50)));
	SourceData.Columns.Add("CatalogDocumentObject");
	
	// Calculating the maximum number of concurrent sessions.
	ConcurrentSessions = New ValueTable();
	ConcurrentSessions.Columns.Add("ConcurrentUsersDate",
		New TypeDescription("Date", , , New DateQualifiers(DateFractions.Date)));
	ConcurrentSessions.Columns.Add("ConcurrentUsers",
		New TypeDescription("Number", New NumberQualifiers(10)));
	ConcurrentSessions.Columns.Add("ConcurrentUsersList");
	
	EventLogData = New ValueTable;
	
	Levels = New Array;
	Levels.Add(EventLogLevel.Information);
	
	Events = New Array;
	Events.Add("_$Session$_.Start"); //  Start session
	Events.Add("_$Session$_.Finish"); //  End session
	Events.Add("_$Data$_.New"); // Add data
	Events.Add("_$Data$_.Update"); // Change data
	
	ApplicationName = New Array;
	ApplicationName.Add("1CV8C");
	ApplicationName.Add("WebClient");
	ApplicationName.Add("1CV8");
	
	UserFilter = New Array;
	
	// Getting a list of users.
	If ReportOption = "UserActivity" Then
		UserFilter.Add(IBUserName(User));
	ElsIf TypeOf(UsersAndGroups) = Type("ValueList") Then
		
		For Each Item In UsersAndGroups Do
			UsersToAnalyze(UserFilter, Item.Value);
		EndDo;
		
	Else
		UsersToAnalyze(UserFilter, UsersAndGroups);
	EndIf;
	
	DatesInServerTimeZone = CommonClientServer.StructureProperty(ReportParameters, "DatesInServerTimeZone", False);
	If DatesInServerTimeZone Then
		ServerTimeOffset = 0;
	Else
		ServerTimeOffset = EventLogOperations.ServerTimeOffset();
	EndIf;
	
	EventLogFilter = New Structure;
	EventLogFilter.Insert("StartDate", StartDate + ServerTimeOffset);
	EventLogFilter.Insert("EndDate", EndDate + ServerTimeOffset);
	EventLogFilter.Insert("ApplicationName", ApplicationName);
	EventLogFilter.Insert("Level", Levels);
	EventLogFilter.Insert("Event", Events);
	
	If UserFilter.Count() = 0 Then
		Return New Structure("UsersActivityAnalysis, ConcurrentSessions, ReportIsBlank", SourceData, ConcurrentSessions, True);
	EndIf;
	
	If UserFilter.Find("AllUsers") = Undefined Then
		EventLogFilter.Insert("User", UserFilter);
	EndIf;
	
	SetPrivilegedMode(True);
	UnloadEventLog(EventLogData, EventLogFilter);
	SetPrivilegedMode(False);
	
	ReportIsBlank = (EventLogData.Count() = 0);
	
	EventLogData.Sort("Session, Date");
	
	// Adding a UUID-UserRef mapping for future use.
	UsersIDs = EventLogData.UnloadColumn("User");
	UsersIDsMap = UsersUUIDs(UsersIDs);
	
	CurrentSession        = Undefined;
	WorkHours         = 0;
	StartsCount  = 0;
	DocumentsCreated   = 0;
	CatalogsCreated = 0;
	DocumentsChanged  = 0;
	CatalogsChanged= 0;
	ObjectKind          = Undefined;
	SourceDataString= Undefined;
	SessionStart        = Undefined;
	
	// Calculating data required for the report.
	For Each EventLogDataRow In EventLogData Do
		EventLogDataRow.Date = EventLogDataRow.Date - ServerTimeOffset;
		If EventLogDataRow.UserName = "" Then
			Continue;
		EndIf;
		Session = EventLogDataRow.Session; 
		
		If Not ValueIsFilled(EventLogDataRow.Session)
			Or Not ValueIsFilled(EventLogDataRow.Date) Then
			Continue;
		EndIf;
		
		UsernameRef = UsersIDsMap[EventLogDataRow.User];
		
		// Calculating the duration of user activity and the number of times the application was started.
		If CurrentSession <> Session
			Or EventLogDataRow.Event = "_$Session$_.Start" Then
			If SourceDataString <> Undefined Then
				SourceDataString.WorkHours  = WorkHours;
				SourceDataString.StartsCount = StartsCount;
			EndIf;
			SourceDataString = SourceData.Add();
			SourceDataString.Date		  = EventLogDataRow.Date;
			SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
			SourceDataString.User = UsernameRef;
			WorkHours			= 0;
			StartsCount	= 0; 
			CurrentSession			= Session; 
			SessionStart		= EventLogDataRow.Date;
		EndIf;
		
		If EventLogDataRow.Event = "_$Session$_.Finish" Then
			
			StartsCount	= StartsCount + 1;
			If SessionStart <> Undefined Then 
				
				// Checking whether a user session has ended the day it had started, or the next day.
				If BegOfDay(EventLogDataRow.Date) > BegOfDay(SessionStart) Then
					// If the session has ended the next day, filling the work hours for the previous day.
					Diff = EndOfDay(SessionStart) - SessionStart;
					WorkHours = Diff/60/60;
					SourceDataString.WorkHours = WorkHours;
					SessionDay = EndOfDay(SessionStart) + 86400;
					While EndOfDay(EventLogDataRow.Date) > SessionDay Do
						SourceDataString = SourceData.Add();
						SourceDataString.Date = SessionDay;
						SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
						SourceDataString.User = UsernameRef;
						WorkHours = (SessionDay - BegOfDay(SessionDay))/60/60;
						SourceDataString.WorkHours  = WorkHours;
						SessionDay = SessionDay + 86400;
					EndDo;	
					SourceDataString = SourceData.Add();
					SourceDataString.Date = EventLogDataRow.Date;
					SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
					SourceDataString.User = UsernameRef;
					WorkHours = (EventLogDataRow.Date - BegOfDay(SessionDay))/60/60;
					SourceDataString.WorkHours  = WorkHours;
				Else
					Diff =  (EventLogDataRow.Date - SessionStart)/60/60;
					WorkHours = WorkHours + Diff;
				EndIf;
				
			EndIf;
			
		EndIf;
		
		// Calculating the number of created documents and catalogs.
		If EventLogDataRow.Event = "_$Data$_.New" Then
			
			If StrFind(EventLogDataRow.Metadata, "Document.") > 0 
				AND OutputDocuments Then
				ObjectKind = EventLogDataRow.MetadataPresentation;
				CatalogDocumentObject = EventLogDataRow.Data;
				DocumentsCreated = DocumentsCreated + 1;
				SourceDataString = SourceData.Add();
				SourceDataString.Date		  = EventLogDataRow.Date;
				SourceDataString.User = UsernameRef;
				SourceDataString.ObjectKind = ObjectKind;
				SourceDataString.DocumentsCreated = DocumentsCreated;
				SourceDataString.CatalogDocumentObject = CatalogDocumentObject;
				SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date); 
			EndIf;
			
			If StrFind(EventLogDataRow.Metadata, "Catalog.") > 0
				AND OutputCatalogs Then
				ObjectKind = EventLogDataRow.MetadataPresentation;
				CatalogDocumentObject = EventLogDataRow.Data;
				CatalogsCreated = CatalogsCreated + 1;
				SourceDataString = SourceData.Add();
				SourceDataString.Date		  = EventLogDataRow.Date;
				SourceDataString.User = UsernameRef;
				SourceDataString.ObjectKind = ObjectKind;
				SourceDataString.CatalogsCreated = CatalogsCreated;
				SourceDataString.CatalogDocumentObject = CatalogDocumentObject;
				SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
			EndIf;
			
		EndIf;
		
		// Calculating the number of changed documents and catalogs.
		If EventLogDataRow.Event = "_$Data$_.Update" Then
			
			If StrFind(EventLogDataRow.Metadata, "Document.") > 0
				AND OutputDocuments Then
				ObjectKind = EventLogDataRow.MetadataPresentation;
				CatalogDocumentObject = EventLogDataRow.Data;
				DocumentsChanged = DocumentsChanged + 1;
				SourceDataString = SourceData.Add();
				SourceDataString.Date		  = EventLogDataRow.Date;
				SourceDataString.User = UsernameRef;
				SourceDataString.DocumentsChanged = DocumentsChanged;  	
				SourceDataString.ObjectKind = ObjectKind;
				SourceDataString.CatalogDocumentObject = CatalogDocumentObject;
				SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
			EndIf;
			
			If StrFind(EventLogDataRow.Metadata, "Catalog.") > 0
				AND OutputCatalogs Then
				ObjectKind = EventLogDataRow.MetadataPresentation;
				CatalogDocumentObject = EventLogDataRow.Data;
				CatalogsChanged = CatalogsChanged + 1;
				SourceDataString = SourceData.Add();
				SourceDataString.Date		  = EventLogDataRow.Date;
				SourceDataString.User = UsernameRef;
				SourceDataString.CatalogsChanged = CatalogsChanged;
				SourceDataString.ObjectKind = ObjectKind;
				SourceDataString.CatalogDocumentObject = CatalogDocumentObject;
				SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
			EndIf;
			
		EndIf;
		
		// Calculating the number of created BusinessProcesses and Tasks.
		If EventLogDataRow.Event = "_$Data$_.New" Then
			
			If StrFind(EventLogDataRow.Metadata, "BusinessProcess.") > 0 
				AND OutputBusinessProcesses Then
				ObjectKind = EventLogDataRow.MetadataPresentation;
				CatalogDocumentObject = EventLogDataRow.Data;
				BusinessProcessesCreated = BusinessProcessesCreated + 1;
				SourceDataString = SourceData.Add();
				SourceDataString.Date		  = EventLogDataRow.Date;
				SourceDataString.User = UsernameRef;
				SourceDataString.ObjectKind = ObjectKind;
				SourceDataString.BusinessProcessesCreated = BusinessProcessesCreated;
				SourceDataString.CatalogDocumentObject = CatalogDocumentObject;
				SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date); 
			EndIf;
			
			If StrFind(EventLogDataRow.Metadata, "Task.") > 0 
				AND OutputTasks Then
				ObjectKind = EventLogDataRow.MetadataPresentation;
				CatalogDocumentObject = EventLogDataRow.Data;
				TasksCreated = TasksCreated + 1;
				SourceDataString = SourceData.Add();
				SourceDataString.Date		  = EventLogDataRow.Date;
				SourceDataString.User = UsernameRef;
				SourceDataString.ObjectKind = ObjectKind;
				SourceDataString.TasksCreated = TasksCreated;
				SourceDataString.CatalogDocumentObject = CatalogDocumentObject;
				SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
			EndIf;
			
		EndIf;
		
		// Calculating the number of changed BusinessProcesses and Tasks.
		If EventLogDataRow.Event = "_$Data$_.Update" Then
			
			If StrFind(EventLogDataRow.Metadata, "BusinessProcess.") > 0
				AND OutputBusinessProcesses Then
				ObjectKind = EventLogDataRow.MetadataPresentation;
				CatalogDocumentObject = EventLogDataRow.Data;
				BusinessProcessesChanged = BusinessProcessesChanged + 1;
				SourceDataString = SourceData.Add();
				SourceDataString.Date		  = EventLogDataRow.Date;
				SourceDataString.User = UsernameRef;
				SourceDataString.ObjectKind = ObjectKind;
				SourceDataString.BusinessProcessesChanged = BusinessProcessesChanged;
				SourceDataString.CatalogDocumentObject = CatalogDocumentObject;
				SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
			EndIf;
			
			If StrFind(EventLogDataRow.Metadata, "Task.") > 0 
				AND OutputTasks Then
				ObjectKind = EventLogDataRow.MetadataPresentation;
				CatalogDocumentObject = EventLogDataRow.Data;
				TasksChanged = TasksChanged + 1;
				SourceDataString = SourceData.Add();
				SourceDataString.Date		  = EventLogDataRow.Date;
				SourceDataString.User = UsernameRef;
				SourceDataString.ObjectKind = ObjectKind;
				SourceDataString.TasksChanged = TasksChanged;
				SourceDataString.CatalogDocumentObject = CatalogDocumentObject;
				SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
			EndIf;
			
		EndIf;
		
		DocumentsCreated       = 0;
		CatalogsCreated     = 0;
		DocumentsChanged      = 0;
		CatalogsChanged    = 0;
		BusinessProcessesCreated  = 0;
		BusinessProcessesChanged = 0;
		TasksChanged           = 0;
		TasksCreated            = 0;
		ObjectKind              = Undefined;
		
	EndDo; 
	
	If SourceDataString <> Undefined Then
		SourceDataString.WorkHours  = WorkHours;
		SourceDataString.StartsCount = StartsCount;
	EndIf;
	
	If ReportOption = "UsersActivityAnalysis" Then
	
		EventLogData.Sort("Date");
		
		UsersArray 	= New Array;
		MaxUsersArray = New Array;
		ConcurrentUsers  = 0;
		Counter                 = 0;
		CurrentDate             = Undefined;
		
		For Each EventLogDataRow In EventLogData Do
			
			If Not ValueIsFilled(EventLogDataRow.Date)
				Or EventLogDataRow.UserName = "" Then
				Continue;
			EndIf;
			
			UsernameRef = UsersIDsMap[EventLogDataRow.User];
			If UsernameRef = Undefined Then
				Continue;
			EndIf;
			
			UsernameRow = IBUserName(UsernameRef);
			
			ConcurrentUsersDate = BegOfDay(EventLogDataRow.Date);
			
			// If the day is changed, clearing all concurrent sessions data and filling the data for the previous day.
			If CurrentDate <> ConcurrentUsersDate Then
				If ConcurrentUsers <> 0 Then
					GenerateConcurrentSessionsRow(ConcurrentSessions, MaxUsersArray, 
						ConcurrentUsers, CurrentDate);
				EndIf;
				ConcurrentUsers = 0;
				Counter    = 0;
				UsersArray.Clear();
				CurrentDate = ConcurrentUsersDate;
			EndIf;
			
			If EventLogDataRow.Event = "_$Session$_.Start" Then
				Counter = Counter + 1;
				UsersArray.Add(UsernameRow);
			ElsIf EventLogDataRow.Event = "_$Session$_.Finish" Then
				UserIndex = UsersArray.Find(UsernameRow);
				If Not UserIndex = Undefined Then 
					UsersArray.Delete(UserIndex);
					Counter = Counter - 1;
				EndIf;
			EndIf;
			
			// Reading the counter value and comparing it with the maximum value.
			Counter = Max(Counter, 0);
			If Counter > ConcurrentUsers Then
				MaxUsersArray = New Array;
				For Each Item In UsersArray Do
					MaxUsersArray.Add(Item);
				EndDo;
			EndIf;
			ConcurrentUsers = Max(ConcurrentUsers, Counter);
			
		EndDo;
		
		If ConcurrentUsers <> 0 Then
			GenerateConcurrentSessionsRow(ConcurrentSessions, MaxUsersArray, 
				ConcurrentUsers, CurrentDate);
		EndIf;
		
		// Calculating the number of errors and warnings.
		EventLogData = Undefined;
		Errors 					 = 0;
		Warnings			 = 0;
		EventLogData = EventLogErrorsInformation(StartDate, EndDate, ServerTimeOffset);
		
		ReportIsBlank =  ReportIsBlank Or (EventLogData.Count() = 0);
		
		For Each EventLogDataRow In EventLogData Do
			
			If EventLogDataRow.UserName = "" Then
				Continue;
			EndIf;
			
			If UserFilter.Find(EventLogDataRow.UserName) = Undefined
				AND UserFilter.Count() <> 0 Then
				Continue;
			EndIf;
			
			UsernameRef = UsersIDsMap[EventLogDataRow.User];
			
			If EventLogDataRow.Level = EventLogLevel.Error Then
				Errors = Errors + 1;
				SourceDataString = SourceData.Add();
				SourceDataString.Date = EventLogDataRow.Date;
				SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
				SourceDataString.User = UsernameRef;
				SourceDataString.Errors = Errors;
			EndIf;
			
			If EventLogDataRow.Level = EventLogLevel.Warning Then
				Warnings = Warnings + 1;
				SourceDataString = SourceData.Add();
				SourceDataString.Date = EventLogDataRow.Date;
				SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
				SourceDataString.User = UsernameRef;
				SourceDataString.Warnings = Warnings;
			EndIf;
			
			Errors         = 0;
			Warnings = 0;
		EndDo;
		
	EndIf;
	
	Return New Structure("UsersActivityAnalysis, ConcurrentSessions, ReportIsBlank", SourceData, ConcurrentSessions, ReportIsBlank);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Users activity analysis.

Function UsersToAnalyze(UserFilter, Item)
	
	If TypeOf(Item) = Type("CatalogRef.Users") Then
		IBUserName = IBUserName(Item);
		
		If IBUserName <> Undefined Then
			UserFilter.Add(IBUserName);
		EndIf;
		
	ElsIf TypeOf(Item) = Type("CatalogRef.UserGroups") Then
		
		AllUsers = Catalogs.UserGroups.AllUsers;
		If Item = AllUsers Then
			UserFilter.Add("AllUsers");
			Return UserFilter;
		EndIf;
		
		For Each GroupUser In Item.Content Do
			IBUserName = IBUserName(GroupUser.User);
			
			If IBUserName <> Undefined Then
				UserFilter.Add(IBUserName);
			EndIf;
		
		EndDo;
		
	EndIf;
	
	Return UserFilter;
EndFunction

Function UsersUUIDs(UsersIDs)
	UsersUUIDsArray = New Array;
	
	CommonClientServer.SupplementArray(UsersUUIDsArray,
		UsersIDs, True);
	UUIDMap = New Map;
	For Each Item In UsersUUIDsArray Do
		
		If ValueIsFilled(Item) Then
			UsernameRef = UserRef(Item);
			IBUserID = Common.ObjectAttributeValue(UsernameRef, "IBUserID");
			
			If IBUserID <> Undefined Then
				UUIDMap.Insert(Item, UsernameRef);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return UUIDMap;
EndFunction

Function UserRef(UserUUID)
	Return Catalogs.Users.FindByAttribute("IBUserID", UserUUID);
EndFunction

Function IBUserName(UserRef) Export
	SetPrivilegedMode(True);
	IBUserID = Common.ObjectAttributeValue(UserRef, "IBUserID");
	InfobaseUser = InfoBaseUsers.FindByUUID(IBUserID);
	
	If InfobaseUser <> Undefined Then
		Return InfobaseUser.Name; 
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function WeekOfYearString(DateInYear)
	Return StringFunctionsClientServer.SubstituteParametersToString(NStr("ru='Неделя %1'; en = 'Week %1'; pl = 'Tydzień %1';es_ES = 'Semana %1';es_CO = 'Semana %1';tr = 'Hafta %1';it = 'Settimana %1';de = 'Woche %1'"), WeekOfYear(DateInYear));
EndFunction

Procedure GenerateConcurrentSessionsRow(ConcurrentSessions, MaxUsersArray,
			ConcurrentUsers, CurrentDate)
	
	TemporaryArray = New Array;
	Index = 0;
	For Each Item In MaxUsersArray Do
		TemporaryArray.Insert(Index, Item);
		UserSessionsCounter = 0;
		
		For Each Username In TemporaryArray Do
			If Username = Item Then
				UserSessionsCounter = UserSessionsCounter + 1;
				UserAndNumber = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 (%2)'; en = '%1 (%2)'; pl = '%1 (%2)';es_ES = '%1 (%2)';es_CO = '%1 (%2)';tr = '%1 (%2)';it = '%1 (%2)';de = '%1 (%2)'"),
					Item,
					UserSessionsCounter);
			EndIf;
		EndDo;
		
		TableRow = ConcurrentSessions.Add();
		TableRow.ConcurrentUsersDate = CurrentDate;
		TableRow.ConcurrentUsers = ConcurrentUsers;
		TableRow.ConcurrentUsersList = UserAndNumber;
		Index = Index + 1;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Duration of scheduled jobs.

// Generates a report on scheduled jobs.
//
// Parameters:
// FillingParameters - Structure - a set of parameters required for the report:
// 	ДатаНачала    - Date - the beginning of the report period.
// 	EndDate - Date - the end of the report period.
// 	ConcurrentSessionsSize	 - Number - the minimum number of concurrent scheduled jobs to display in 
// 		the table.
// 	MinScheduledJobSessionDuration - Number - the minimum duration of a scheduled job session (in 
// 		seconds).
// 	DisplayBackgroundJobs - Boolean - if True, display a line with intervals of background jobs 
// 		sessions on the Gantt chart.
// 	OutputTitle - DataCompositionTextOutputType - shows whether to show the title.
// 	OutputFilter - DataCompositionTextOutputType - shows whether to show the filter.
// 	HideScheduledJobs - ValueList - a list of scheduled jobs to exclude from the report.
//
Function GenerateScheduledJobsDurationReport(FillingParameters) Export
	
	// Report parameters
	StartDate = FillingParameters.StartDate;
	EndDate = FillingParameters.EndDate;
	MinScheduledJobSessionDuration = 
		FillingParameters.MinScheduledJobSessionDuration;
	OutputTitle = FillingParameters.OutputTitle;
	OutputFilter = FillingParameters.OutputFilter;
	
	Result = New Structure;
	Report = New SpreadsheetDocument;
	
	// Getting data to generate the report.
	GetData = DataForScheduledJobsDurationsReport(FillingParameters);
	ScheduledJobsSessionsTable = GetData.ScheduledJobsSessionsTable;
	ConcurrentSessions = GetData.TotalConcurrentScheduledJobs;
	StartsCount = GetData.StartsCount;
	ReportIsBlank        = GetData.ReportIsBlank;
	Template = GetTemplate("ScheduledJobsDuration");
	
	// A set of colors for the chart and table backgrounds.
	BackColors = New Array;
	BackColors.Add(WebColors.White);
	BackColors.Add(WebColors.LightYellow);
	BackColors.Add(WebColors.LemonChiffon);
	BackColors.Add(WebColors.NavajoWhite);
	
	// Generating the report header.
	If OutputTitle.Value = DataCompositionTextOutputType.Output
		AND OutputTitle.Use
		OR Not OutputTitle.Use Then
		Report.Put(Template.GetArea("ReportHeader"));
	EndIf;
	
	If OutputFilter.Value = DataCompositionTextOutputType.Output
		AND OutputFilter.Use
		Or Not OutputFilter.Use Then
		Area = Template.GetArea("Filter");
		If MinScheduledJobSessionDuration > 0 Then
			IntervalsViewMode = NStr("ru = 'Отключено'; en = 'Disabled'; pl = 'Wyłączony';es_ES = 'Desactivado';es_CO = 'Desactivado';tr = 'Devre dışı';it = 'Disabilitato';de = 'Deaktiviert'");
		Else
			IntervalsViewMode = NStr("ru = 'Включено'; en = 'Enabled'; pl = 'Włączono';es_ES = 'Activado';es_CO = 'Activado';tr = 'Etkin';it = 'Abilitato';de = 'Aktiviert'");
		EndIf;
		Area.Parameters.StartDate = StartDate;
		Area.Parameters.EndDate = EndDate;
		Area.Parameters.IntervalsViewMode = IntervalsViewMode;
		Report.Put(Area);
	EndIf;
	
	If ValueIsFilled(ConcurrentSessions) Then
	
		Report.Put(Template.GetArea("TableHeader"));
		
		// Generating a table of the maximum number of concurrent scheduled jobs.
		CurrentSessionsCount = 0; 
		ColorIndex = 3;
		For Each ConcurrentSessionsRow In ConcurrentSessions Do
			Area = Template.GetArea("Table");
			If CurrentSessionsCount <> 0 
				AND CurrentSessionsCount <> ConcurrentSessionsRow.ConcurrentScheduledJobs
				AND ColorIndex <> 0 Then
				ColorIndex = ColorIndex - 1;
			EndIf;
			If ConcurrentSessionsRow.ConcurrentScheduledJobs = 1 Then
				ColorIndex = 0;
			EndIf;
			Area.Parameters.Fill(ConcurrentSessionsRow);
			TableBackColor = BackColors.Get(ColorIndex);
			Area.Areas.Table.BackColor = TableBackColor;
			Report.Put(Area);
			CurrentSessionsCount = ConcurrentSessionsRow.ConcurrentScheduledJobs;
			ScheduledJobsArray = ConcurrentSessionsRow.ScheduledJobsList;
			ScheduledJobIndex = 0;
			Report.StartRowGroup(, False);
			For Each Item In ScheduledJobsArray Do
				If Not TypeOf(Item) = Type("Number")
					AND Not TypeOf(Item) = Type("Date") Then
					Area = Template.GetArea("ScheduledJobsList");
					Area.Parameters.ScheduledJobsList = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 (сеанс %2)'; en = '%1 (session %2)'; pl = '%1 (sesja %2)';es_ES = '%1 (sesión %2)';es_CO = '%1 (sesión %2)';tr = '%1 (oturum %2)';it = '%1 (sessione %2)';de = '%1 (Sitzung - %2)'"),
						Item,
						ScheduledJobsArray[ScheduledJobIndex+1]);
				ElsIf Not TypeOf(Item) = Type("Date")
					AND Not TypeOf(Item) = Type("String") Then	
					Area.Parameters.JobDetails = New Array;
					Area.Parameters.JobDetails.Add("ScheduledJobDetails");
					Area.Parameters.JobDetails.Add(Item);
					ScheduledJobName = ScheduledJobsArray.Get(ScheduledJobIndex-1);
					Area.Parameters.JobDetails.Add(ScheduledJobName);
					Area.Parameters.JobDetails.Add(StartDate);
					Area.Parameters.JobDetails.Add(EndDate);
					Report.Put(Area);
				EndIf;
				ScheduledJobIndex = ScheduledJobIndex + 1;
			EndDo;
			Report.EndRowGroup();
		EndDo;
	EndIf;
	
	Report.Put(Template.GetArea("BlankRow"));
	
	// Getting a Gantt chart and specifying the parameters required to fill the chart.
	Area = Template.GetArea("Chart");
	GanttChart = Area.Drawings.GanttChart.Object;
	GanttChart.RefreshEnabled = False;  
	
	Series = GanttChart.Series.Add();

	CurrentEvent			 = Undefined;
	OverallScheduledJobsDuration = 0;
	Dot					 = Undefined;
	StartsCountRow = Undefined;
	ScheduledJobStarts = 0;
	PointChangedFlag        = False;
	
	// Filling the Gantt chart.	
	For Each ScheduledJobsRow In ScheduledJobsSessionsTable Do
		ScheduledJobIntervalDuration =
			ScheduledJobsRow.JobEndDate - ScheduledJobsRow.JobStartDate;
		If ScheduledJobIntervalDuration >= MinScheduledJobSessionDuration Then
			If CurrentEvent <> ScheduledJobsRow.EventName Then
				If CurrentEvent <> Undefined
					AND PointChangedFlag Then
					Dot.Details.Add(ScheduledJobStarts);
					Dot.Details.Add(OverallScheduledJobsDuration);
					Dot.Details.Add(StartDate);
					Dot.Details.Add(EndDate);
					PointName = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 (%2 из %3)'; en = '%1 (%2 out of %3)'; pl = '%1 (%2 z %3)';es_ES = '%1 (%2 de %3)';es_CO = '%1 (%2 de %3)';tr = '%1 (%2''den %3)';it = '%1 (%2 su %3)';de = '%1 (%2 von %3)'"),
						Dot.Value,
						ScheduledJobStarts,
						String(StartsCountRow.Starts));
					Dot.Value = PointName;
				EndIf;
				StartsCountRow = StartsCount.Find(
					ScheduledJobsRow.EventName, "EventName");
				// Leaving the details of background jobs blank.
				If ScheduledJobsRow.EventMetadata <> "" Then 
					PointName = ScheduledJobsRow.EventName;
					Dot = GanttChart.SetPoint(PointName);
					Dot.Details = New Array;
					IntervalStart	  = New Array;
					IntervalEnd	  = New Array;
					ScheduledJobSession = New Array;
					Dot.Details.Add("PointDetails");
					Dot.Details.Add(ScheduledJobsRow.EventMetadata);
					Dot.Details.Add(ScheduledJobsRow.EventName);
					Dot.Details.Add(StartsCountRow.Canceled);
					Dot.Details.Add(StartsCountRow.ExecutionError);                                                             
					Dot.Details.Add(IntervalStart);
					Dot.Details.Add(IntervalEnd);
					Dot.Details.Add(ScheduledJobSession);
					Dot.Details.Add(MinScheduledJobSessionDuration);
					CurrentEvent = ScheduledJobsRow.EventName;
					OverallScheduledJobsDuration = 0;				
					ScheduledJobStarts = 0;
					Dot.Picture = PictureLib.ScheduledJob;
				ElsIf Not ValueIsFilled(ScheduledJobsRow.EventMetadata) Then
					PointName = NStr("ru = 'Фоновые задания'; en = 'Background jobs'; pl = 'Zadania w tle';es_ES = 'Tareas de fondo';es_CO = 'Tareas de fondo';tr = 'Arka plan işleri';it = 'Processi in background';de = 'Hintergrund Aufgaben'");
					Dot = GanttChart.SetPoint(PointName);
					OverallScheduledJobsDuration = 0;
				EndIf;
			EndIf;
			Value = GanttChart.GetValue(Dot, Series);
			Interval = Value.Add();
			Interval.Begin = ScheduledJobsRow.JobStartDate;
			Interval.End = ScheduledJobsRow.JobEndDate;
			Interval.Text = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 - %2'; en = '%1 - %2'; pl = '%1 - %2';es_ES = '%1 - %2';es_CO = '%1 - %2';tr = '%1 - %2';it = '%1 - %2';de = '%1 - %2'"),
				Format(Interval.Begin, "DLF=T"),
				Format(Interval.End, "DLF=T"));
			PointChangedFlag = False;
			// Leaving the details of background jobs blank.
			If ScheduledJobsRow.EventMetadata <> "" Then
				IntervalStart.Add(ScheduledJobsRow.JobStartDate);
				IntervalEnd.Add(ScheduledJobsRow.JobEndDate);
				ScheduledJobSession.Add(ScheduledJobsRow.Session);
				OverallScheduledJobsDuration = ScheduledJobIntervalDuration + OverallScheduledJobsDuration;
				ScheduledJobStarts = ScheduledJobStarts + 1;
				PointChangedFlag = True;
			EndIf;
		EndIf;
	EndDo; 
	
	If ScheduledJobStarts <> 0
		AND ValueIsFilled(Dot.Details) Then
		// Assigning details to the last point.
		Dot.Details.Add(ScheduledJobStarts);
		Dot.Details.Add(OverallScheduledJobsDuration);
		Dot.Details.Add(StartDate);
		Dot.Details.Add(EndDate);	
		PointName = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 (%2 из %3)'; en = '%1 (%2 out of %3)'; pl = '%1 (%2 z %3)';es_ES = '%1 (%2 de %3)';es_CO = '%1 (%2 de %3)';tr = '%1 (%2''den %3)';it = '%1 (%2 su %3)';de = '%1 (%2 von %3)'"),
			Dot.Value,
			ScheduledJobStarts,
			String(StartsCountRow.Starts));
		Dot.Value = PointName;
	EndIf;
		
	// Setting up chart view settings.
	GanttChartColors(StartDate, GanttChart, ConcurrentSessions, BackColors);
	AnalysisPeriod = EndDate - StartDate;
	GanttChartTimescale(GanttChart, AnalysisPeriod);
	
	ColumnsNumber = GanttChart.Points.Count();
	Area.Drawings.GanttChart.Height				 = 15 + 10 * ColumnsNumber;
	Area.Drawings.GanttChart.Width 				 = 450;
	GanttChart.AutoDetectWholeInterval	 = False; 
	GanttChart.IntervalRepresentation   			 = GanttChartIntervalRepresentation.Flat;
	GanttChart.LegendArea.Placement       = ChartLegendPlacement.None;
	GanttChart.VerticalStretch 			 = GanttChartVerticalStretch.StretchRowsAndData;
	GanttChart.SetWholeInterval(StartDate, EndDate);
	GanttChart.RefreshEnabled = True;

	Report.Put(Area);
	
	Result.Insert("Report", Report);
	Result.Insert("ReportIsBlank", ReportIsBlank);
	Return Result;
EndFunction

// Gets scheduled jobs data from the event log.
//
// Parameters:
// FillingParameters - Structure - a set of parameters required for the report:
// 	ДатаНачала    - Date - the beginning of the report period.
// 	EndDate - Date - the end of the report period.
// 	ConcurrentSessionsSize	 - Number - the minimum number of concurrent scheduled jobs to display in 
// 		the table.
// 	MinScheduledJobSessionDuration - Number - the minimum duration of a scheduled job session (in 
// 		seconds).
// 	DisplayBackgroundJobs - Boolean - if True, display a line with intervals of background jobs 
// 		sessions on the Gantt chart.
// 	HideScheduledJobs - ValueList - a list of scheduled jobs to exclude from the report.
//
// Returns a value table. The table contains scheduled jobs data from the event log.
// 
// 
//
Function DataForScheduledJobsDurationsReport(FillingParameters)
	
	StartDate = FillingParameters.StartDate;
	EndDate = FillingParameters.EndDate;
	ConcurrentSessionsSize = FillingParameters.ConcurrentSessionsSize;
	DisplayBackgroundJobs = FillingParameters.DisplayBackgroundJobs;
	MinScheduledJobSessionDuration =
		FillingParameters.MinScheduledJobSessionDuration;
	HideScheduledJobs = FillingParameters.HideScheduledJobs;
	ServerTimeOffset = FillingParameters.ServerTimeOffset;
	
	EventLogData = New ValueTable;
	
	Levels = New Array;
	Levels.Add(EventLogLevel.Information);
	Levels.Add(EventLogLevel.Warning);
	Levels.Add(EventLogLevel.Error);
	
	ScheduledJobEvents = New Array;
	ScheduledJobEvents.Add("_$Job$_.Start");
	ScheduledJobEvents.Add("_$Job$_.Cancel");
	ScheduledJobEvents.Add("_$Job$_.Fail");
	ScheduledJobEvents.Add("_$Job$_.Succeed");
	
	SetPrivilegedMode(True);
	LogFilter = New Structure;
	LogFilter.Insert("Level", Levels);
	LogFilter.Insert("StartDate", StartDate + ServerTimeOffset);
	LogFilter.Insert("EndDate", EndDate + ServerTimeOffset);
	LogFilter.Insert("Event", ScheduledJobEvents);
	
	UnloadEventLog(EventLogData, LogFilter);
	ReportIsBlank = (EventLogData.Count() = 0);
	
	If ServerTimeOffset <> 0 Then
		For Each TableRow In EventLogData Do
			TableRow.Date = TableRow.Date - ServerTimeOffset;
		EndDo;
	EndIf;
	
	// Generating data to filter by scheduled jobs.
	AllScheduledJobsList = ScheduledJobsServer.FindJobs(New Structure);
	MetadataIDMap = New Map;
	MetadataNameMap = New Map;
	DescriptionIDMap = New Map;
	SetPrivilegedMode(False);
	
	For Each ScheduledJob In AllScheduledJobsList Do
		MetadataIDMap.Insert(ScheduledJob.Metadata, String(ScheduledJob.UUID));
		DescriptionIDMap.Insert(ScheduledJob.Description, String(ScheduledJob.UUID));
		If ScheduledJob.Description <> "" Then
			MetadataNameMap.Insert(ScheduledJob.Metadata, ScheduledJob.Description);
		Else
			MetadataNameMap.Insert(ScheduledJob.Metadata, ScheduledJob.Metadata.Synonym);
		EndIf;
	EndDo;
	
	// Filling the parameters required to define concurrent scheduled jobs.
	ConcurrentSessionsParameters = New Structure;
	ConcurrentSessionsParameters.Insert("EventLogData", EventLogData);
	ConcurrentSessionsParameters.Insert("DescriptionIDMap", DescriptionIDMap);
	ConcurrentSessionsParameters.Insert("MetadataIDMap", MetadataIDMap);
	ConcurrentSessionsParameters.Insert("MetadataNameMap", MetadataNameMap);
	ConcurrentSessionsParameters.Insert("HideScheduledJobs", HideScheduledJobs);
	ConcurrentSessionsParameters.Insert("MinScheduledJobSessionDuration",
		MinScheduledJobSessionDuration);
	
	// The maximum number of concurrent scheduled jobs sessions.
	ConcurrentSessions = ConcurrentScheduledJobs(ConcurrentSessionsParameters);
	
	// Selecting values from the ConcurrentSessions table.
	ConcurrentSessions.Sort("ConcurrentScheduledJobs Desc");
	
	TotalConcurrentScheduledJobsRow = Undefined;
	TotalConcurrentScheduledJobs = New ValueTable();
	TotalConcurrentScheduledJobs.Columns.Add("ConcurrentScheduledJobsDate", 
		New TypeDescription("String", , New StringQualifiers(50)));
	TotalConcurrentScheduledJobs.Columns.Add("ConcurrentScheduledJobs", 
		New TypeDescription("Number", New NumberQualifiers(10))); 
	TotalConcurrentScheduledJobs.Columns.Add("ScheduledJobsList");
	
	For Each ConcurrentSessionsRow In ConcurrentSessions Do
		If ConcurrentSessionsRow.ConcurrentScheduledJobs >= ConcurrentSessionsSize
			AND ConcurrentSessionsRow.ConcurrentScheduledJobs >= 2 Then
			TotalConcurrentScheduledJobsRow = TotalConcurrentScheduledJobs.Add();
			TotalConcurrentScheduledJobsRow.ConcurrentScheduledJobsDate = 
				ConcurrentSessionsRow.ConcurrentScheduledJobsDate;
			TotalConcurrentScheduledJobsRow.ConcurrentScheduledJobs = 
				ConcurrentSessionsRow.ConcurrentScheduledJobs;
			TotalConcurrentScheduledJobsRow.ScheduledJobsList = 
				ConcurrentSessionsRow.ScheduledJobsList;
		EndIf;
	EndDo;
	
	EventLogData.Sort("Metadata, Data, Date, Session");
	
	// Filling the parameters required to get data on each scheduled jobs session.
	ScheduledJobsSessionsParameters = New Structure;
	ScheduledJobsSessionsParameters.Insert("EventLogData", EventLogData);
	ScheduledJobsSessionsParameters.Insert("DescriptionIDMap", DescriptionIDMap);
	ScheduledJobsSessionsParameters.Insert("MetadataIDMap", MetadataIDMap);
	ScheduledJobsSessionsParameters.Insert("MetadataNameMap", MetadataNameMap);
	ScheduledJobsSessionsParameters.Insert("DisplayBackgroundJobs", DisplayBackgroundJobs);
	ScheduledJobsSessionsParameters.Insert("HideScheduledJobs", HideScheduledJobs);
	
	// Scheduled jobs
	ScheduledJobsSessionsTable = 
		ScheduledJobsSessions(ScheduledJobsSessionsParameters).ScheduledJobsSessionsTable;
	StartsCount = ScheduledJobsSessions(ScheduledJobsSessionsParameters).StartsCount;
	
	Result = New Structure;
	Result.Insert("ScheduledJobsSessionsTable", ScheduledJobsSessionsTable);
	Result.Insert("TotalConcurrentScheduledJobs", TotalConcurrentScheduledJobs);
	Result.Insert("StartsCount", StartsCount);
	Result.Insert("ReportIsBlank", ReportIsBlank);
	
	Return Result;
EndFunction

Function ConcurrentScheduledJobs(ConcurrentSessionsParameters)
	
	EventLogData 			  = ConcurrentSessionsParameters.EventLogData;
	DescriptionIDMap = ConcurrentSessionsParameters.DescriptionIDMap;
	MetadataIDMap   = ConcurrentSessionsParameters.MetadataIDMap;
	MetadataNameMap 		  = ConcurrentSessionsParameters.MetadataNameMap;
	HideScheduledJobs 			  = ConcurrentSessionsParameters.HideScheduledJobs;
	MinScheduledJobSessionDuration = ConcurrentSessionsParameters.	
		MinScheduledJobSessionDuration;
										
	ConcurrentSessions = New ValueTable();
	
	ConcurrentSessions.Columns.Add("ConcurrentScheduledJobsDate",
										New TypeDescription("String", , New StringQualifiers(50)));
	ConcurrentSessions.Columns.Add("ConcurrentScheduledJobs",
										New TypeDescription("Number", New NumberQualifiers(10)));
	ConcurrentSessions.Columns.Add("ScheduledJobsList");
	
	ScheduledJobsArray = New Array;
	
	ConcurrentScheduledJobs	  = 0;
	Counter     				  = 0;
	CurrentDate 					  = Undefined;
	TableRow 				  = Undefined;
	MaxScheduledJobsArray = Undefined;
	
	For Each EventLogDataRow In EventLogData Do 
		If Not ValueIsFilled(EventLogDataRow.Date)
			Or Not ValueIsFilled(EventLogDataRow.Metadata) Then
			Continue;
		EndIf;
		
		NameAndUUID = ScheduledJobSessionNameAndUUID(
			EventLogDataRow, DescriptionIDMap,
			MetadataIDMap, MetadataNameMap);
			
		ScheduledJobName = NameAndUUID.SessionName;
		ScheduledJobUUID = 
			NameAndUUID.ScheduledJobUUID;
		
		If Not HideScheduledJobs = Undefined
			AND Not TypeOf(HideScheduledJobs) = Type("String") Then
			ScheduledJobsFilter = HideScheduledJobs.FindByValue(
				ScheduledJobUUID);
			If Not ScheduledJobsFilter = Undefined Then
				Continue;
			EndIf;
		ElsIf Not HideScheduledJobs = Undefined
			AND TypeOf(HideScheduledJobs) = Type("String") Then	
			If ScheduledJobUUID = HideScheduledJobs Then
				Continue;
			EndIf;
		EndIf;	
		
		ConcurrentScheduledJobsDate = BegOfHour(EventLogDataRow.Date);
		
		If CurrentDate <> ConcurrentScheduledJobsDate Then
			If TableRow <> Undefined Then
				TableRow.ConcurrentScheduledJobs = ConcurrentScheduledJobs;
				TableRow.ConcurrentScheduledJobsDate = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 - %2'; en = '%1 - %2'; pl = '%1 - %2';es_ES = '%1 - %2';es_CO = '%1 - %2';tr = '%1 - %2';it = '%1 - %2';de = '%1 - %2'"),
					Format(CurrentDate, "DLF=T"),
					Format(EndOfHour(CurrentDate), "DLF=T"));
				TableRow.ScheduledJobsList = MaxScheduledJobsArray;
			EndIf;
			TableRow = ConcurrentSessions.Add();
			ConcurrentScheduledJobs = 0;
			Counter    = 0;
			ScheduledJobsArray.Clear();
			CurrentDate = ConcurrentScheduledJobsDate;
		EndIf;
		
		If EventLogDataRow.Event = "_$Job$_.Start" Then
			Counter = Counter + 1;
			ScheduledJobsArray.Add(ScheduledJobName);
			ScheduledJobsArray.Add(EventLogDataRow.Session);
			ScheduledJobsArray.Add(EventLogDataRow.Date);
		Else
			ScheduledJobIndex = ScheduledJobsArray.Find(ScheduledJobName);
			If ScheduledJobIndex = Undefined Then 
				Continue;
			EndIf;
			
			If ValueIsFilled(MaxScheduledJobsArray) Then
				ArrayStringIndex = MaxScheduledJobsArray.Find(ScheduledJobName);
				If ArrayStringIndex <> Undefined 
					AND MaxScheduledJobsArray[ArrayStringIndex+1] = ScheduledJobsArray[ScheduledJobIndex+1]
					AND EventLogDataRow.Date - MaxScheduledJobsArray[ArrayStringIndex+2] <
						MinScheduledJobSessionDuration Then
					MaxScheduledJobsArray.Delete(ArrayStringIndex);
					MaxScheduledJobsArray.Delete(ArrayStringIndex);
					MaxScheduledJobsArray.Delete(ArrayStringIndex);
					ConcurrentScheduledJobs = ConcurrentScheduledJobs - 1;
				EndIf;
			EndIf;    						
			ScheduledJobsArray.Delete(ScheduledJobIndex);
			ScheduledJobsArray.Delete(ScheduledJobIndex); // Deleting a session value.
			ScheduledJobsArray.Delete(ScheduledJobIndex); // Deleting a date value.
			Counter = Counter - 1;
		EndIf;
		
		Counter = Max(Counter, 0);
		If Counter > ConcurrentScheduledJobs Then
			MaxScheduledJobsArray = New Array;
			For Each Item In ScheduledJobsArray Do
				MaxScheduledJobsArray.Add(Item);
			EndDo;
		EndIf;
		ConcurrentScheduledJobs = Max(ConcurrentScheduledJobs, Counter);
	EndDo;
		
	If ConcurrentScheduledJobs <> 0 Then
		TableRow.ConcurrentScheduledJobs  = ConcurrentScheduledJobs;
		TableRow.ConcurrentScheduledJobsDate = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 - %2'; en = '%1 - %2'; pl = '%1 - %2';es_ES = '%1 - %2';es_CO = '%1 - %2';tr = '%1 - %2';it = '%1 - %2';de = '%1 - %2'"),
			Format(CurrentDate, "DLF=T"),
			Format(EndOfHour(CurrentDate), "DLF=T"));
		TableRow.ScheduledJobsList = MaxScheduledJobsArray;
	EndIf;
	
	Return ConcurrentSessions;
EndFunction

Function ScheduledJobsSessions(ScheduledJobsSessionsParameters)

	EventLogData = ScheduledJobsSessionsParameters.EventLogData;
	DescriptionIDMap = ScheduledJobsSessionsParameters.DescriptionIDMap;
	MetadataIDMap = ScheduledJobsSessionsParameters.MetadataIDMap;
	MetadataNameMap = ScheduledJobsSessionsParameters.MetadataNameMap;
	HideScheduledJobs = ScheduledJobsSessionsParameters.HideScheduledJobs;
	DisplayBackgroundJobs = ScheduledJobsSessionsParameters.DisplayBackgroundJobs;  
	
	ScheduledJobsSessionsTable = New ValueTable();
	ScheduledJobsSessionsTable.Columns.Add("JobStartDate",New TypeDescription("Date", , , New DateQualifiers(DateFractions.DateTime)));
	ScheduledJobsSessionsTable.Columns.Add("JobEndDate",New TypeDescription("Date", , , New DateQualifiers(DateFractions.DateTime)));
    ScheduledJobsSessionsTable.Columns.Add("EventName",New TypeDescription("String", , New StringQualifiers(100)));
	ScheduledJobsSessionsTable.Columns.Add("EventMetadata",New TypeDescription("String", , New StringQualifiers(100)));
	ScheduledJobsSessionsTable.Columns.Add("Session",New TypeDescription("Number", 	New NumberQualifiers(10)));
	
	StartsCount = New ValueTable();
	StartsCount.Columns.Add("EventName",New TypeDescription("String", , New StringQualifiers(100)));
	StartsCount.Columns.Add("Starts",New TypeDescription("Number", 	New NumberQualifiers(10)));
	StartsCount.Columns.Add("Canceled",New TypeDescription("Number", 	New NumberQualifiers(10)));
	StartsCount.Columns.Add("ExecutionError",New TypeDescription("Number", 	New NumberQualifiers(10))); 	
	
	ScheduledJobsRow = Undefined;
	EventName			  = Undefined;
	JobEndDate	  = Undefined;
	JobStartDate		  = Undefined;
	EventMetadata		  = Undefined;
	Starts				  = 0;
	CurrentEvent			  = Undefined;
	StartsCountRow  = Undefined;
	CurrentSession			  = 0;
	Canceled				  = 0;
	ExecutionError		  = 0;
	
	For Each EventLogDataRow In EventLogData Do
		If Not ValueIsFilled(EventLogDataRow.Metadata)
			AND DisplayBackgroundJobs = False Then
			Continue;
		EndIf;
		
		NameAndUUID = ScheduledJobSessionNameAndUUID(
			EventLogDataRow, DescriptionIDMap,
			MetadataIDMap, MetadataNameMap);
			
		EventName = NameAndUUID.SessionName;
		ScheduledJobUUID = NameAndUUID.
														ScheduledJobUUID;

		If Not HideScheduledJobs = Undefined
			AND Not TypeOf(HideScheduledJobs) = Type("String") Then
			ScheduledJobsFilter = HideScheduledJobs.FindByValue(
				ScheduledJobUUID);
			If Not ScheduledJobsFilter = Undefined Then
				Continue;
			EndIf;
		ElsIf Not HideScheduledJobs = Undefined
			AND TypeOf(HideScheduledJobs) = Type("String") Then	
			If ScheduledJobUUID = HideScheduledJobs Then
				Continue;
			EndIf;
		EndIf;
	
		Session = EventLogDataRow.Session;
		If CurrentEvent = Undefined Then                             
			CurrentEvent = EventName;
			Starts = 0;
		ElsIf CurrentEvent <> EventName Then
			StartsCountRow = StartsCount.Add();
			StartsCountRow.EventName = CurrentEvent;
			StartsCountRow.Starts = Starts;
			StartsCountRow.Canceled = Canceled;
			StartsCountRow.ExecutionError = ExecutionError;
			Starts = 0; 
			Canceled = 0;
			ExecutionError = 0;
			CurrentEvent = EventName;
		EndIf;  
		
		If CurrentSession <> Session Then
			ScheduledJobsRow = ScheduledJobsSessionsTable.Add();
			JobStartDate = EventLogDataRow.Date;
			ScheduledJobsRow.JobStartDate = JobStartDate;    
		EndIf;
		
		If CurrentSession = Session Then
			JobEndDate = EventLogDataRow.Date;
			EventMetadata = EventLogDataRow.Metadata;
			ScheduledJobsRow.EventName = EventName;
			ScheduledJobsRow.EventMetadata = EventMetadata;
			ScheduledJobsRow.JobEndDate = JobEndDate;
			ScheduledJobsRow.Session = CurrentSession;
		EndIf;
		CurrentSession = Session;
		
		If EventLogDataRow.Event = "_$Job$_.Cancel" Then
			Canceled = Canceled + 1;
		ElsIf EventLogDataRow.Event = "_$Job$_.Fail" Then
			ExecutionError = ExecutionError + 1;
		ElsIf EventLogDataRow.Event = "_$Job$_.Start" Then
			Starts = Starts + 1
		EndIf;		
	EndDo;
	
	StartsCountRow = StartsCount.Add();
	StartsCountRow.EventName = CurrentEvent;
	StartsCountRow.Starts = Starts;
	StartsCountRow.Canceled = Canceled;
	StartsCountRow.ExecutionError = ExecutionError;
	
	ScheduledJobsSessionsTable.Sort("EventMetadata, EventName, JobStartDate");
	
	Return New Structure("ScheduledJobsSessionsTable, StartsCount",
					ScheduledJobsSessionsTable, StartsCount);
EndFunction

// Generates a report for a single scheduled job.
// Parameters:
// Details - scheduled job details.
//
Function ScheduledJobDetails(Details) Export
	Result = New Structure;
	Report = New SpreadsheetDocument;
	JobsCanceled = 0;
	ExecutionError = 0;
	
	JobStartDate = Details.Get(5);
	JobEndDate = Details.Get(6);
	SessionsList = Details.Get(7);
	Template = GetTemplate("ScheduledJobsDetails");
	
	Area = Template.GetArea("Title");
	StartDate = Details.Get(11);
	EndDate = Details.Get(12);
	Area.Parameters.StartDate = StartDate;
	Area.Parameters.EndDate = EndDate;
	If Details.Get(8) = 0 Then
		IntervalsViewMode = NStr("ru = 'Включено'; en = 'Enabled'; pl = 'Włączono';es_ES = 'Activado';es_CO = 'Activado';tr = 'Etkin';it = 'Abilitato';de = 'Aktiviert'");
	Else
		IntervalsViewMode = NStr("ru = 'Отключено'; en = 'Disabled'; pl = 'Wyłączony';es_ES = 'Desactivado';es_CO = 'Desactivado';tr = 'Devre dışı';it = 'Disabilitato';de = 'Deaktiviert'");
	EndIf;
	Area.Parameters.SessionViewMode = IntervalsViewMode;
	Report.Put(Area);
	
	Report.Put(Template.GetArea("BlankRow"));
	
	Area = Template.GetArea("Table");
	Area.Parameters.JobType = NStr("ru = 'Регламентное'; en = 'Scheduled'; pl = 'Planowany';es_ES = 'Planificado';es_CO = 'Planificado';tr = 'Planlanmış';it = 'In programma';de = 'Geplant'");
	Area.Parameters.EventName = Details.Get(2);
	Area.Parameters.Starts = Details.Get(9);
	JobsCanceled = Details.Get(3);
	ExecutionError = Details.Get(4);
	If JobsCanceled = 0 Then
		Area.Parameters.Canceled = "0";
	Else
		Area.Parameters.Canceled = JobsCanceled;
	EndIf;
	If ExecutionError = 0 Then 
		Area.Parameters.ExecutionError = "0";
	Else
		Area.Parameters.ExecutionError = ExecutionError;
	EndIf;
	OverallScheduledJobsDuration = Details.Get(10);
	OverallScheduledJobsDurationTotal = ScheduledJobDuration(OverallScheduledJobsDuration);
	Area.Parameters.OverallScheduledJobsDuration = OverallScheduledJobsDurationTotal;
	Report.Put(Area);
	
	Report.Put(Template.GetArea("BlankRow")); 
	
	Report.Put(Template.GetArea("IntervalsTitle"));
		
	Report.Put(Template.GetArea("BlankRow"));
	
	Report.Put(Template.GetArea("TableHeader"));
	
	// Filling the table of intervals.
	ArraySize = JobStartDate.Count();
	IntervalNumber = 1; 	
    Report.StartRowGroup(, False);
	For Index = 0 To ArraySize-1 Do
		Area = Template.GetArea("IntervalsTable");
		IntervalStart = JobStartDate.Get(Index);
		IntervalEnd = JobEndDate.Get(Index);
		SJDuration = ScheduledJobDuration(IntervalEnd - IntervalStart);
		Area.Parameters.IntervalNumber = IntervalNumber;
		Area.Parameters.IntervalStart = Format(IntervalStart, "DLF=T");
		Area.Parameters.IntervalEnd = Format(IntervalEnd, "DLF=T");
		Area.Parameters.SJDuration = SJDuration;
		Area.Parameters.Session = SessionsList.Get(Index);
		Area.Parameters.IntervalDetails = New Array;
		Area.Parameters.IntervalDetails.Add(IntervalStart);
		Area.Parameters.IntervalDetails.Add(IntervalEnd);
		Area.Parameters.IntervalDetails.Add(SessionsList.Get(Index));
		Report.Put(Area);
		IntervalNumber = IntervalNumber + 1;
	EndDo;
	Report.EndRowGroup();
	
	Result.Insert("Report", Report);
	Return Result;
EndFunction

// Sets interval and background colors for a Gantt chart.
//
// Parameters:
// StartDate - the day for which a chart is generated.
// GanttChart - a Gantt chart with SpreadsheetDocumentDrawing type.
// ConcurrentSessions - a value table with data on the number of concurrent scheduled jobs during 
// 		the day.
// BackColors - an array of colors for background intervals.
//
Procedure GanttChartColors(StartDate, GanttChart, ConcurrentSessions, BackColors)
	// Chart intervals colors.
	IntervalsColors = New Array;
	ColorStart = 153;
	ColorEnd = 253;
	While ColorStart <= ColorEnd Do
		IntervalsColors.Add(ColorStart);
		ColorStart = ColorStart + 10;
	EndDo;
	
	Index = 0;
	For Each GanttChartPoint In GanttChart.Points Do
		GanttChartPoint.ColorPriority = True;
		BlueColor = IntervalsColors.Get(Index);
		SeriesColor = New Color(204,204,BlueColor);
		GanttChartPoint.Color = SeriesColor;
		Index = Index + 1;
		If Index = 11 Then
			Index = 0;
		EndIf;
	EndDo;
	
	// Adding colors of background intervals.
	CurrentSessionsCount = 0;
	ColorIndex = 3;
	For Each ConcurrentSessionsRow In ConcurrentSessions Do
		If ConcurrentSessionsRow.ConcurrentScheduledJobs = 1 Then
			Continue
		EndIf;
		DateString = Left(ConcurrentSessionsRow.ConcurrentScheduledJobsDate, 8);
		BackIntervalStartDate =  Date(Format(StartDate,"DLF=D") + " " + DateString);
		BackIntervalEndDate = EndOfHour(BackIntervalStartDate);
		GanttChartInterval = GanttChart.BackgroundIntervals.Add(BackIntervalStartDate, BackIntervalEndDate);
		If CurrentSessionsCount <> 0 
			AND CurrentSessionsCount <> ConcurrentSessionsRow.ConcurrentScheduledJobs 
			AND ColorIndex <> 0 Then
			ColorIndex = ColorIndex - 1;
		EndIf;
		BackColor = BackColors.Get(ColorIndex);
		GanttChartInterval.Color = BackColor;
		
		CurrentSessionsCount = ConcurrentSessionsRow.ConcurrentScheduledJobs;
	EndDo;
EndProcedure

// Generates a timescale of a Gantt chart.
//
// Parameters:
// GanttChart - a Gantt chart with SpreadsheetDocumentDrawing type.
//
Procedure GanttChartTimescale(GanttChart, AnalysisPeriod)
	TimescaleItems = GanttChart.PlotArea.TimeScale.Items;
	
	FirstItem = TimescaleItems[0];
	For Index = 1 To TimescaleItems.Count()-1 Do
		TimescaleItems.Delete(TimescaleItems[1]);
	EndDo; 
		
	FirstItem.Unit = TimeScaleUnitType.Day;
	FirstItem.PointLines = New Line(ChartLineType.Solid, 1);
	FirstItem.DayFormat =  TimeScaleDayFormat.MonthDay;
	
	Item = TimescaleItems.Add();
	Item.Unit = TimeScaleUnitType.Hour;
	Item.PointLines = New Line(ChartLineType.Dotted, 1);
	
	If AnalysisPeriod <= 3600 Then
		Item = TimescaleItems.Add();
		Item.Unit = TimeScaleUnitType.Minute;
		Item.PointLines = New Line(ChartLineType.Dotted, 1);
	EndIf;
EndProcedure

Function ScheduledJobDuration(SJDuration)
	If SJDuration = 0 Then
		OverallScheduledJobsDuration = "0";
	ElsIf SJDuration <= 60 Then
		OverallScheduledJobsDuration = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 сек'; en = '%1 sec'; pl = '%1 sek.';es_ES = '%1 segundo';es_CO = '%1 segundo';tr = 'saniye%1';it = '%1 sec';de = '%1 sek'"), SJDuration);
	ElsIf 60 < SJDuration <= 3600 Then
		DurationMinutes  = Format(SJDuration/60, "NFD=0");
		DurationSeconds = Format((Format(SJDuration/60, "NFD=2")
			- Int(SJDuration/60)) * 60, "NFD=0");
		OverallScheduledJobsDuration = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 мин %2 сек'; en = '%1 min %2 sec'; pl = '%1 min %2 sek.';es_ES = '%1 minutos %2 segundos';es_CO = '%1 minutos %2 segundos';tr = '%1 dak %2 san';it = '%1 min %2 sec';de = '%1 min %2 s'"), DurationMinutes, DurationSeconds);
	ElsIf SJDuration > 3600 Then
		DurationHours    = Format(SJDuration/60/60, "NFD=0");
		DurationMinutes  = (Format(SJDuration/60/60, "NFD=2") - Int(SJDuration/60/60))*60;
		DurationMinutes  = Format(DurationMinutes, "NFD=0");
		OverallScheduledJobsDuration = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 ч %2 мин'; en = '%1 h %2 min'; pl = '%1 h %2 min';es_ES = '%1 horas %2 minutos';es_CO = '%1 horas %2 minutos';tr = '%1 sa %2 dk';it = '%1 ore %2 min';de = '%1 h %2 min'"), DurationHours, DurationMinutes);
	EndIf;
	
	Return OverallScheduledJobsDuration;
EndFunction

Function ScheduledJobMetadata(ScheduledJobData)
	If ScheduledJobData <> "" Then
		Return Metadata.ScheduledJobs.Find(
			StrReplace(ScheduledJobData, "ScheduledJob." , ""));
	EndIf;
EndFunction

Function ScheduledJobSessionNameAndUUID(EventLogDataRow,
			DescriptionIDMap, MetadataIDMap, MetadataNameMap)
	If Not EventLogDataRow.Data = "" Then
		ScheduledJobUUID = DescriptionIDMap[
														EventLogDataRow.Data];
		SessionName = EventLogDataRow.Data;
	Else 
		ScheduledJobUUID = MetadataIDMap[
			ScheduledJobMetadata(EventLogDataRow.Metadata)];
		SessionName = MetadataNameMap[ScheduledJobMetadata(
														EventLogDataRow.Metadata)];
	EndIf;
													
	Return New Structure("SessionName, ScheduledJobUUID",
								SessionName, ScheduledJobUUID)
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Event log monitor.

// Generates a report on errors registered in the event log.
//
// Parameters:
// Event Log Data - ValueTable - a table exported from the event log.
//
// It must have the following columns: Date, Username, ApplicationPresentation,
//                                          EventPresentation, Comment, and Level.
//
Function GenerateEventLogMonitorReport(StartDate, EndDate, ServerTimeOffset) Export
	
	Result = New Structure; 	
	Report = New SpreadsheetDocument; 	
	Template = GetTemplate("EvengLogErrorReportTemplate");
	EventLogData = EventLogErrorsInformation(StartDate, EndDate, ServerTimeOffset);
	EventLogRecordsCount = EventLogData.Count();
	
	ReportIsBlank = (EventLogRecordsCount = 0); // Checking report filling.
		
	///////////////////////////////////////////////////////////////////////////////
	// Data preparation block.
	//
	
	CollapseByComments = EventLogData.Copy();
	CollapseByComments.Columns.Add("TotalByComment");
	CollapseByComments.FillValues(1, "TotalByComment");
	CollapseByComments.GroupBy("Level, Comment, Event, EventPresentation", "TotalByComment");
	
	RowsArray_ErrorLevel = CollapseByComments.FindRows(
									New Structure("Level", EventLogLevel.Error));
	
	RowsArray_WarningLevel = CollapseByComments.FindRows(
									New Structure("Level", EventLogLevel.Warning));
	
	Collapse_Errors         = CollapseByComments.Copy(RowsArray_ErrorLevel);
	Collapse_Errors.Sort("TotalByComment Desc");
	Collapse_Warnings = CollapseByComments.Copy(RowsArray_WarningLevel);
	Collapse_Warnings.Sort("TotalByComment Desc");
	
	///////////////////////////////////////////////////////////////////////////////
	// Report generation block.
	//
	
	Area = Template.GetArea("ReportHeader");
	Area.Parameters.SelectionPeriodStart    = StartDate;
	Area.Parameters.SelectionPeriodEnd = EndDate;
	Area.Parameters.InfobasePresentation = InfobasePresentation();
	Report.Put(Area);
	
	TSCompositionResult = GenerateTabularSection(Template, EventLogData, Collapse_Errors);
	
	Report.Put(Template.GetArea("BlankRow"));
	Area = Template.GetArea("ErrorBlockTitle");
	Area.Parameters.ErrorsCount = String(TSCompositionResult.Total);
	Report.Put(Area);
	
	If TSCompositionResult.Total > 0 Then
		Report.Put(TSCompositionResult.TabularSection);
	EndIf;
	
	Result.Insert("TotalByErrors", TSCompositionResult.Total); 	
	TSCompositionResult = GenerateTabularSection(Template, EventLogData, Collapse_Warnings);
	
	Report.Put(Template.GetArea("BlankRow"));
	Area = Template.GetArea("WarningBlockTitle");
	Area.Parameters.WarningsCount = TSCompositionResult.Total;
	Report.Put(Area);
	
	If TSCompositionResult.Total > 0 Then
		Report.Put(TSCompositionResult.TabularSection);
	EndIf;
	
	Result.Insert("TotalByWarnings", TSCompositionResult.Total);	
	Report.ShowGrid = False; 	
	Result.Insert("Report", Report); 
	Result.Insert("ReportIsBlank", ReportIsBlank);
	Return Result;
	
EndFunction

// Gets a presentation of the physical infobase location to display it to an administrator.
//
// Returns:
//   String - an infobase presentation.
//
// Return value example:
// - For a file infobase: \\FileServer\1C_ib
// - For a client/server infobase: ServerName:1111 / infobase_name.
//
Function InfobasePresentation()
	
	DatabaseConnectionString = InfoBaseConnectionString();
	
	If Common.FileInfobase(DatabaseConnectionString) Then
		Return Mid(DatabaseConnectionString, 6, StrLen(DatabaseConnectionString) - 6);
	EndIf;
		
	// Adding the infobase name to the server name.
	SearchPosition = StrFind(Upper(DatabaseConnectionString), "SRVR=");
	If SearchPosition <> 1 Then
		Return Undefined;
	EndIf;
	
	SemicolonPosition = StrFind(DatabaseConnectionString, ";");
	StartPositionForCopying = 6 + 1;
	EndPositionForCopying = SemicolonPosition - 2; 
	
	ServerName = Mid(DatabaseConnectionString, StartPositionForCopying, EndPositionForCopying - StartPositionForCopying + 1);
	
	DatabaseConnectionString = Mid(DatabaseConnectionString, SemicolonPosition + 1);
	
	// Server name position
	SearchPosition = StrFind(Upper(DatabaseConnectionString), "REF=");
	If SearchPosition <> 1 Then
		Return Undefined;
	EndIf;
	
	StartPositionForCopying = 6;
	SemicolonPosition = StrFind(DatabaseConnectionString, ";");
	EndPositionForCopying = SemicolonPosition - 2; 
	
	IBNameAtServer = Mid(DatabaseConnectionString, StartPositionForCopying, EndPositionForCopying - StartPositionForCopying + 1);
	PathToDatabase = ServerName + "/ " + IBNameAtServer;
	Return PathToDatabase;
	
EndFunction

// Gets error details for the specified period from the event log.
//
// Parameters:
// StartDate    - Date - the beginning of the period.
// EndDate - Date - the end of the period.
//
// Returns a value table. The table contains event log records with the following filter:
// 
//                    EventLogLevel - EventLogLevel.Error
//                    The beginning and end of period are taken from the parameters.
//
Function EventLogErrorsInformation(Val StartDate, Val EndDate, ServerTimeOffset)
	
	EventLogData = New ValueTable;
	
	LogLevels = New Array;
	LogLevels.Add(EventLogLevel.Error);
	LogLevels.Add(EventLogLevel.Warning);
	
	StartDate = StartDate + ServerTimeOffset;
	EndDate = EndDate + ServerTimeOffset;
	
	SetPrivilegedMode(True);
	UnloadEventLog(EventLogData,
							   New Structure("Level, StartDate, EndDate",
											   LogLevels,
											   StartDate,
											   EndDate));
	SetPrivilegedMode(False);
	
	If ServerTimeOffset <> 0 Then
		For Each TableRow In EventLogData Do
			TableRow.Date = TableRow.Date - ServerTimeOffset;
		EndDo;
	EndIf;
	
	Return EventLogData;
	
EndFunction

// Adds a tabular section with errors to the report. The errors are grouped by comment.
// 
//
// Parameters:
// Template  - SpreadsheetDocument - a source of formatted areas for report generation.
//                              
// EventLogData   - ValueTable - errors and warnings from the event log "as is."
//                              
// CollapsedData - ValueTable - contains their total numbers (collapsed by comment).
//
Function GenerateTabularSection(Template, EventLogData, CollapsedData)
	
	Report = New SpreadsheetDocument;	
	Total = 0;
	
	If CollapsedData.Count() > 0 Then
		Report.Put(Template.GetArea("BlankRow"));
		
		For Each Record In CollapsedData Do
			Total = Total + Record.TotalByComment;
			RowsArray = EventLogData.FindRows(
				New Structure("Level, Comment",
					EventLogLevel.Error,
					Record.Comment));
			
			Area = Template.GetArea("TabularSectionBodyHeader");
			Area.Parameters.Fill(Record);
			Report.Put(Area);
			
			Report.StartRowGroup(, False);
			For Each Row In RowsArray Do
				Area = Template.GetArea("TabularSectionBodyDetails");
				Area.Parameters.Fill(Row);
				Report.Put(Area);
			EndDo;
			Report.EndRowGroup();
			Report.Put(Template.GetArea("BlankRow"));
		EndDo;
	EndIf;
	
	Result = New Structure("TabularSection, Total", Report, Total);
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf