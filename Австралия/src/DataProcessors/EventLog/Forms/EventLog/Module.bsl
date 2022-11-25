
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	SetConditionalAppearance();
	
	SaaSModel = Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable();
	
	EventLogFilter = New Structure;
	DefaultEventLogFilter = New Structure;
	FilterValues = GetEventLogFilterValues("Event").Event;
	
	If Not IsBlankString(Parameters.User) Then
		If TypeOf(Parameters.User) = Type("ValueList") Then
			FilterByUser = Parameters.User;
		Else
			Username = Parameters.User;
			FilterByUser = New ValueList;
			FilterByUser.Add(Username, Username);
		EndIf;
		EventLogFilter.Insert("User", FilterByUser);
	EndIf;
	
	If ValueIsFilled(Parameters.EventLogEvent) Then
		FilterByEvent = New ValueList;
		If TypeOf(Parameters.EventLogEvent) = Type("Array") Then
			For Each Event In Parameters.EventLogEvent Do
				EventPresentation = FilterValues[Event];
				FilterByEvent.Add(Event, EventPresentation);
			EndDo;
		Else
			FilterByEvent.Add(Parameters.EventLogEvent, Parameters.EventLogEvent);
		EndIf;
		EventLogFilter.Insert("Event", FilterByEvent);
	EndIf;
	
	If SaaSModel Then
		EventLogFilter.Insert("StartDate", BegOfDay(CurrentSessionDate()));
		EventLogFilter.Insert("EndDate", EndOfDay(CurrentSessionDate()));
	Else
		If ValueIsFilled(Parameters.StartDate) Then
			EventLogFilter.Insert("StartDate", Parameters.StartDate);
		Else
			EventLogFilter.Insert("StartDate", BegOfDay(CurrentSessionDate()));
		EndIf;
		
		If ValueIsFilled(Parameters.EndDate) Then
			EventLogFilter.Insert("EndDate", Parameters.EndDate + 1);
		Else
			EventLogFilter.Insert("EndDate", EndOfDay(CurrentSessionDate()));
		EndIf;
	EndIf;
	
	If Parameters.Data <> Undefined Then
		EventLogFilter.Insert("Data", Parameters.Data);
	EndIf;
	
	If Parameters.Session <> Undefined Then
		EventLogFilter.Insert("Session", Parameters.Session);
	EndIf;
	
	// Level - value list.
	If Parameters.Level <> Undefined Then
		FilterByLevel = New ValueList;
		If TypeOf(Parameters.Level) = Type("Array") Then
			For Each LevelPresentation In Parameters.Level Do
				FilterByLevel.Add(LevelPresentation, LevelPresentation);
			EndDo;
		ElsIf TypeOf(Parameters.Level) = Type("String") Then
			FilterByLevel.Add(Parameters.Level, Parameters.Level);
		Else
			FilterByLevel = Parameters.Level;
		EndIf;
		EventLogFilter.Insert("Level", FilterByLevel);
	EndIf;
	
	// ApplicationName - value list.
	If Parameters.ApplicationName <> Undefined Then
		ApplicationsList = New ValueList;
		For Each Application In Parameters.ApplicationName Do
			ApplicationsList.Add(Application, ApplicationPresentation(Application));
		EndDo;
		EventLogFilter.Insert("ApplicationName", ApplicationsList);
	EndIf;
	
	EventsCountLimit = 200;
	
	DefaultFilter = DefaultFilter(FilterValues);
	If Not EventLogFilter.Property("Event") Then
		EventLogFilter.Insert("Event", DefaultFilter);
	EndIf;
	DefaultEventLogFilter.Insert("Event", DefaultFilter);
	Items.SessionDataSeparationPresentation.Visible = Not Common.SeparatedDataUsageAvailable();
	
	Severity = "All events"; // id.
	
	// Switched to True if the event log must not be generated in background.
	RunNotInBackground = Parameters.RunNotInBackground;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		CommonClientServer.SetFormItemProperty(Items, "Severity",	"TitleLocation",		FormItemTitleLocation.None);
		CommonClientServer.SetFormItemProperty(Items, "Severity",	"ChoiceButton",				True);
		CommonClientServer.SetFormItemProperty(Items, "Log", 		"CommandBarLocation", FormItemCommandBarLabelLocation.None);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Data.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Log.Data");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Visible", False);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.MetadataPresentation.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Log.MetadataPresentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Visible", False);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AttachIdleHandler("RefreshCurrentList", 0.1, True);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure EventsCountLimitOnChange(Item)
	
#If WebClient OR MobileClient Then
	EventsCountLimit = ?(EventsCountLimit > 1000, 1000, EventsCountLimit);
#EndIf
	
	RefreshCurrentList();
	
EndProcedure

&AtClient
Procedure CriticalityOnChange(Item)
	
	If Severity = "Error" Then
		FilterByLevel = New ValueList;
		FilterByLevel.Add("Error", "Error");
		EventLogFilter.Delete("Level");
		EventLogFilter.Insert("Level", FilterByLevel);
		RefreshCurrentList();
	ElsIf Severity = "Warning" Then
		FilterByLevel = New ValueList;
		FilterByLevel.Add("Warning", "Warning");
		EventLogFilter.Delete("Level");
		EventLogFilter.Insert("Level", FilterByLevel);
		RefreshCurrentList();
	Else
		EventLogFilter.Delete("Level");
		RefreshCurrentList();
	EndIf;
	
EndProcedure

#EndRegion

#Region LogFormTableItemsEventHandlers

&AtClient
Procedure EventLogChoice(Item, RowSelected, Field, StandardProcessing)
	
	EventLogClient.EventsChoice(
		Items.Log.CurrentData, 
		Field, 
		DateInterval, 
		EventLogFilter);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If TypeOf(SelectedValue) = Type("Structure") AND SelectedValue.Property("Event") Then
		
		If SelectedValue.Event = "EventLogFilterSet" Then
			
			EventLogFilter.Clear();
			For Each ListItem In SelectedValue.Filter Do
				EventLogFilter.Insert(ListItem.Presentation, ListItem.Value);
			EndDo;
			
			If EventLogFilter.Property("Level") Then
				If EventLogFilter.Level.Count() > 0 Then
					Severity = String(EventLogFilter.Level);
				EndIf;
			EndIf;
			
			RefreshCurrentList();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RefreshCurrentList()
	
	Items.Pages.CurrentPage = Items.TimeConsumingOperationProgress;
	CommonClientServer.SetSpreadsheetDocumentFieldState(Items.TimeConsumingOperationProgressField, "ReportGeneration");
	
	ExecutionResult = ReadEventLog();
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	CompletionNotification = New NotifyDescription("RefreshCurrentListCompletion", ThisObject);
	
	TimeConsumingOperationsClient.WaitForCompletion(ExecutionResult, CompletionNotification, IdleParameters);
	
EndProcedure

&AtClient
Procedure RefreshCurrentListCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Completed" Then
		LoadPreparedData();
		CommonClientServer.SetSpreadsheetDocumentFieldState(Items.TimeConsumingOperationProgressField, "DontUse");
		Items.Pages.CurrentPage = Items.EventLog;
		MoveToListEnd();
	ElsIf Result.Status = "Error" Then
		CommonClientServer.SetSpreadsheetDocumentFieldState(Items.TimeConsumingOperationProgressField, "DontUse");
		Items.Pages.CurrentPage = Items.EventLog;
		MoveToListEnd();
		Raise Result.BriefErrorPresentation;
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearFilter()
	
	EventLogFilter = DefaultEventLogFilter;
	Severity = "All events"; // id.
	RefreshCurrentList();
	
EndProcedure

&AtClient
Procedure OpenDataForViewing()
	
	EventLogClient.OpenDataForViewing(Items.Log.CurrentData);
	
EndProcedure

&AtClient
Procedure ViewCurrentEventInNewWindow()
	
	EventLogClient.ViewCurrentEventInNewWindow(Items.Log.CurrentData);
	
EndProcedure

&AtClient
Procedure SetPeriodForViewing()
	
	Notification = New NotifyDescription("SetViewDateIntervalCompletion", ThisObject);
	EventLogClient.SetPeriodForViewing(DateInterval, EventLogFilter, Notification)
	
EndProcedure

&AtClient
Procedure SetFilter()
	
	SetFilterOnClient();
	
EndProcedure

&AtClient
Procedure FilterPresentationClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	SetFilterOnClient();
	
EndProcedure

&AtClient
Procedure SetFilterByValueInCurrentColumn()
	
	ExcludeColumns = New Array;
	ExcludeColumns.Add("Date");
	
	If EventLogClient.SetFilterByValueInCurrentColumn(
			Items.Log.CurrentData,
			Items.Log.CurrentItem,
			EventLogFilter,
			ExcludeColumns) Then
		
		RefreshCurrentList();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportLogForTechnicalSupport(Command)
	NotifyDescription = New NotifyDescription("ExportLogFollowUp", ThisObject);
	BeginAttachingFileSystemExtension(NotifyDescription);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetViewDateIntervalCompletion(IntervalSet, AdditionalParameters) Export
	
	If IntervalSet Then
		RefreshCurrentList();
	EndIf;
	
EndProcedure

&AtServer
Function DefaultFilter(EventsList)
	
	DefaultFilter = New ValueList;
	
	For Each LogEvent In EventsList Do
		
		If LogEvent.Key = "_$Transaction$_.Commit"
			Or LogEvent.Key = "_$Transaction$_.Begin"
			Or LogEvent.Key = "_$Transaction$_.Rollback" Then
			Continue;
		EndIf;
		
		DefaultFilter.Add(LogEvent.Key, LogEvent.Value);
		
	EndDo;
	
	Return DefaultFilter;
EndFunction

&AtServer
Function ReadEventLog()
	
	If ExecutionResult <> Undefined
		AND ExecutionResult.JobID <> New UUID("00000000-0000-0000-0000-000000000000") Then
		TimeConsumingOperations.CancelJobExecution(ExecutionResult.JobID);
	EndIf;
	
	ReportParameters = ReportParameters();
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.WaitForCompletion = 0; // run immediately
	ExecutionParameters.BackgroundJobDescription = NStr("ru = 'Обновление журнала регистрации'; en = 'Update event log'; pl = 'Zaktualizuj dziennik wydarzeń';es_ES = 'Actualizar el registro de eventos';es_CO = 'Actualizar el registro de eventos';tr = 'Olay günlüğünü güncelle';it = 'Aggiornamento del registro eventi';de = 'Aktualisieren Sie das Ereignisprotokoll'");
	ExecutionParameters.RunNotInBackground = RunNotInBackground;
	
	ExecutionResult = TimeConsumingOperations.ExecuteInBackground("EventLogOperations.ReadEventLogEvents",
		ReportParameters, ExecutionParameters);
	
	If ExecutionResult.Status = "Error" Then
		Items.Pages.CurrentPage = Items.EventLog;
		Raise ExecutionResult.BriefErrorPresentation;
	EndIf;
	
	EventLogOperations.GenerateFilterPresentation(FilterPresentation, EventLogFilter, DefaultEventLogFilter);
	
	Return ExecutionResult;
	
EndFunction

&AtServer
Function ReportParameters()
	ReportParameters = New Structure;
	ReportParameters.Insert("EventLogFilter", EventLogFilter);
	ReportParameters.Insert("EventsCountLimit", EventsCountLimit);
	ReportParameters.Insert("UUID", UUID);
	ReportParameters.Insert("OwnerManager", DataProcessors.EventLog);
	ReportParameters.Insert("AddAdditionalColumns", False);
	ReportParameters.Insert("Log", FormAttributeToValue("Log"));

	Return ReportParameters;
EndFunction

&AtServer
Procedure LoadPreparedData()
	Result = GetFromTempStorage(ExecutionResult.ResultAddress);
	LogEvents      = Result.LogEvents;
	
	EventLogOperations.PutDataInTempStorage(LogEvents, UUID);
	
	ValueToFormData(LogEvents, Log);
EndProcedure

&AtClient
Procedure MoveToListEnd()
	If Log.Count() > 0 Then
		Items.Log.CurrentRow = Log[Log.Count() - 1].GetID();
	EndIf;
EndProcedure 

&AtClient
Procedure SetFilterOnClient()
	
	FormFilter = New ValueList;
	For Each KeyAndValue In EventLogFilter Do
		FormFilter.Add(KeyAndValue.Value, KeyAndValue.Key);
	EndDo;
	
	OpenForm(
		"DataProcessor.EventLog.Form.EventLogFilter", 
		New Structure("Filter, DefaultEvents", FormFilter, DefaultEventLogFilter.Event), 
		ThisObject);
	
EndProcedure

&AtClient
Procedure CriticalityClear(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure ExportLogFollowUp(Attached, AdditionalParameters) Export
	
	If Attached Then
		Mode = FileDialogMode.Save;
		SavingDialog = New FileDialog(Mode);
		SavingDialog.Multiselect = False;
		SavingDialog.Filter = NStr("ru = 'Данные журнала регистрации'; en = 'Event log data'; pl = 'Dane dziennika rejestracji';es_ES = 'Datos del registro de eventos';es_CO = 'Datos del registro de eventos';tr = 'Olay günlüğü verileri';it = 'Dati del registro eventi';de = 'Ereignisprotokolldaten'") + "(*.xml)|*.xml";
		SavingDialog.FullFileName = "EventLog";
		NotifyDescription = New NotifyDescription("ExportLogCompletion", ThisObject);
		SavingDialog.Show(NotifyDescription);
	Else
		GetFile(ExportRegistrationLog(), "EventLog.xml", True);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportLogCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	EventLogData = ExportRegistrationLog();
	
	FullFileName = Result[0];
	FilesToReceive = New Array;
	FilesToReceive.Add(New TransferableFileDescription(FullFileName, EventLogData));
	
	Handler = New NotifyDescription();
	BeginGettingFiles(Handler, FilesToReceive, FullFileName, False);
	
EndProcedure

&AtServer
Function ExportRegistrationLog()
	Return EventLogOperations.TechnicalSupportLog(EventLogFilter, EventsCountLimit);
EndFunction

#EndRegion
