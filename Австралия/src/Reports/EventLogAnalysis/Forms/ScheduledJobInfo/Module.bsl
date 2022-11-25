
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	DetailsFromReport = CommonClientServer.StructureProperty(Parameters, "DetailsFromReport");
	If DetailsFromReport <> Undefined Then
		Report = Reports.EventLogAnalysis.ScheduledJobDetails(DetailsFromReport).Report;
		
		ScheduledJobName = DetailsFromReport.Get(1);
		EventDescription = DetailsFromReport.Get(2);
		Title = EventDescription;
		If ScheduledJobName <> "" Then
			EventName = StrReplace(ScheduledJobName, "ScheduledJob.", "");
			
			SetPrivilegedMode(True);
			FilterByScheduledJobs = New Structure;
			ScheduledJobMetadata = Metadata.ScheduledJobs.Find(EventName);
			If ScheduledJobMetadata <> Undefined Then
				FilterByScheduledJobs.Insert("Metadata", ScheduledJobMetadata);
				If EventDescription <> Undefined Then
					FilterByScheduledJobs.Insert("Description", EventDescription);
				EndIf;
				ScheduledJob = ScheduledJobsServer.FindJobs(FilterByScheduledJobs);
				If ValueIsFilled(ScheduledJob) Then
					ScheduledJobID = ScheduledJob[0].UUID;
				EndIf;
			EndIf;
			SetPrivilegedMode(False);
		EndIf;
	Else
		Report = Parameters.Report;
		ScheduledJobID = Parameters.ScheduledJobID;
		Title = Parameters.Title;
	EndIf;
	
	Items.EditSchedule.Visible = Common.SubsystemExists("StandardSubsystems.ScheduledJobs");
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DetailsProcessingReport(Item, Details, StandardProcessing)
	
	StandardProcessing = False;
	StartDate = Details.Get(0);
	EndDate = Details.Get(1);
	ScheduledJobSession.Clear();
	ScheduledJobSession.Add(Details.Get(2)); 
	EventLogFilter = New Structure("Session, StartDate, EndDate", ScheduledJobSession, StartDate, EndDate);
	OpenForm("DataProcessor.EventLog.Form.EventLog", EventLogFilter);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ConfigureJobSchedule(Command)
	
	If ValueIsFilled(ScheduledJobID) Then
		
		Dialog = New ScheduledJobDialog(GetSchedule());
		
		NotifyDescription = New NotifyDescription("ConfigureJobScheduleCompletion", ThisObject);
		Dialog.Show(NotifyDescription);
		
	Else
		ShowMessageBox(,NStr("ru = 'Невозможно получить расписание регламентного задания: регламентное задание было удалено или не указано его наименование.'; en = 'Cannot get job schedule. The scheduled job might have been deleted or its name was not specified.'; pl = 'Nie można uzyskać harmonogramu prac. Harmonogram prac mógł być usunięty albo nie określono jego nazwy.';es_ES = 'No se puede obtener el horario de tareas. La tarea programada puede haber sido borrada, o su nombre no se había especificado.';es_CO = 'No se puede obtener el horario de tareas. La tarea programada puede haber sido borrada, o su nombre no se había especificado.';tr = 'İş programı alınamıyor. Zamanlanan iş silinmiş veya adı belirtilmemiş olabilir.';it = 'Impossibile ottenere la pianificazione del processo. Il processo pianificato è stato cancellato o il suo nome non è stato specificato.';de = 'Jobplan kann nicht abgerufen werden. Der geplante Job wurde möglicherweise gelöscht oder sein Name wurde nicht angegeben.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToEventLog(Command)
	
	For Each Area In Report.SelectedAreas Do
		If Area.AreaType = SpreadsheetDocumentCellAreaType.Rectangle Then
			Details = Area.Details;
		Else
			Details = Undefined;
		EndIf;
		If Details = Undefined
			OR Area.Top <> Area.Bottom Then
			ShowMessageBox(,NStr("ru = 'Выберите строку или ячейку нужного сеанса задания'; en = 'Select a line or cell of the required job session'; pl = 'Zaznacz wiersz lub komórkę potrzebnej sesji pracy';es_ES = 'Seleccionar una línea o una celda de la sesión de la tarea requerid';es_CO = 'Seleccionar una línea o una celda de la sesión de la tarea requerid';tr = 'Gerekli iş oturumunun bir satırını veya hücresini seçin';it = 'Selezionare una linea o una cella della sessione lavoro richiesta';de = 'Wählen Sie eine Zeile oder Zelle der gewünschten Jobsitzung aus'"));
			Return;
		EndIf;
		StartDate = Details.Get(0);
		EndDate = Details.Get(1);
		ScheduledJobSession.Clear();
		ScheduledJobSession.Add(Details.Get(2));
		
		UniqueKey = String(StartDate) + "-" + EndDate + "-" + Details.Get(2);
		EventLogFilter = New Structure("Session, StartDate, EndDate", ScheduledJobSession, StartDate, EndDate);
		OpenForm("DataProcessor.EventLog.Form.EventLog", EventLogFilter, , UniqueKey);
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function GetSchedule()
	
	SetPrivilegedMode(True);
	
	ModuleScheduledJobsServer = Common.CommonModule("ScheduledJobsServer");
	Return ModuleScheduledJobsServer.JobSchedule(ScheduledJobID);
	
EndFunction

&AtClient
Procedure ConfigureJobScheduleCompletion(Schedule, AdditionalParameters) Export
	
	If Schedule <> Undefined Then
		SetJobSchedule(Schedule);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetJobSchedule(Schedule)
	
	SetPrivilegedMode(True);
	
	JobParameters = New Structure;
	JobParameters.Insert("Schedule", Schedule);
	ModuleScheduledJobsServer = Common.CommonModule("ScheduledJobsServer");
	ModuleScheduledJobsServer.ChangeJob(ScheduledJobID, JobParameters);
	
EndProcedure

#EndRegion
