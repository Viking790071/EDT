
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.Ref.IsEmpty() Then
		InitializeForm();
	EndIf;
	
	CurrentUser = Users.CurrentUser();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	BusinessProcessesAndTasksClient.UpdateAcceptForExecutionCommandsAvailability(ThisObject);

EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	ExecuteTask = False;
	If Not (WriteParameters.Property("ExecuteTask", ExecuteTask) And ExecuteTask) Then
		Return;
	EndIf;
	
	If Not JobCompleted And Not ValueIsFilled(CurrentObject.ExecutionResult) Then
		CommonClientServer.MessageToUser(
			NStr("en = 'Specify the reason why the task is declined.'; ru = 'Укажите причину, по которой задача отклоняется.';pl = 'Określ przyczynę czemu zadanie jest odrzucane.';es_ES = 'Especificar la razón por la que se ha rechazado la tarea.';es_CO = 'Especificar la razón por la que se ha rechazado la tarea.';tr = 'Görevin reddedilmesinin sebebini belirtin.';it = 'Indicare il motivo del rifiuto del compito.';de = 'Geben Sie den Grund ein, warum die Aufgabe abgelehnt ist.'"), ,
			"Object.ExecutionResult",,
			Cancel);
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	WriteBusinessProcessAttributes(CurrentObject);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	BusinessProcessesAndTasksClient.TaskFormNotificationProcessing(ThisObject, EventName, Parameter, Source);
	If EventName = "Write_ProjectJob" Then
		If (Source = Object.BusinessProcess Or (TypeOf(Source) = Type("Array") 
			And Source.Find(Object.BusinessProcess) <> Undefined)) Then
			Read();
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	InitializeForm();
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ExecutionStartDateScheduledOnChange(Item)
	
	If Object.StartDate = BegOfDay(Object.StartDate) Then
		Object.StartDate = EndOfDay(Object.StartDate);
	EndIf;
	
EndProcedure

&AtClient
Procedure CompletionDateOnChange(Item)
	
	If Object.CompletionDate = BegOfDay(Object.CompletionDate) Then
		Object.CompletionDate = EndOfDay(Object.CompletionDate);
	EndIf;
	
EndProcedure

&AtClient
Procedure SubjectClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(, Object.Topic);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("Project", Object.Project);
	NotificationParameters.Insert("ProjectPhase", Object.ProjectPhase);
	
	BusinessProcessesAndTasksClient.WriteAndCloseComplete(ThisObject, , NotificationParameters);
	
EndProcedure

&AtClient
Procedure CompletedComplete(Command)
	
	JobCompleted = True;
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("Project", Object.Project);
	NotificationParameters.Insert("ProjectPhase", Object.ProjectPhase);
	
	BusinessProcessesAndTasksClient.WriteAndCloseComplete(ThisObject, True, NotificationParameters);
	
EndProcedure

&AtClient
Procedure Canceled(Command)
	
	JobCompleted = False;
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("Project", Object.Project);
	NotificationParameters.Insert("ProjectPhase", Object.ProjectPhase);
	
	BusinessProcessesAndTasksClient.WriteAndCloseComplete(ThisObject, True, NotificationParameters);
	
EndProcedure

&AtClient
Procedure More(Command)
	
	BusinessProcessesAndTasksClient.OpenAdditionalTaskInfo(Object.Ref);
	
EndProcedure

&AtClient
Procedure AcceptForExecution(Command)
	
	BusinessProcessesAndTasksClient.AcceptTaskForExecution(ThisObject, CurrentUser);
	
EndProcedure

&AtClient
Procedure CancelAcceptForExecution(Command)
	
	BusinessProcessesAndTasksClient.CancelAcceptTaskForExecution(ThisObject);
	
EndProcedure

&AtClient
Procedure ChangeJob(Command)
	
	If Modified Then
		Write();
	EndIf;
	
	ShowValue(, Object.BusinessProcess);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure InitializeForm()
	
	InitialExecutionFlag = Object.Executed;
	ReadBusinessProcessAttributes();
	SetItemsState();
	
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	Items.ExecutionStartDateScheduledTime.Visible = UseDateAndTimeInTaskDeadlines;
	Items.CompletionDateTime.Visible = UseDateAndTimeInTaskDeadlines;
	Items.AcceptForExecutionDateTime.Visible = UseDateAndTimeInTaskDeadlines;
	BusinessProcessesAndTasksServer.SetDateFormat(Items.DueDate);
	BusinessProcessesAndTasksServer.SetDateFormat(Items.Date);
	
	BusinessProcessesAndTasksServer.TaskFormOnCreateAtServer(ThisObject,
		Object,
		Items.StateGroup,
		Items.CompletionDate);
	
	Items.ResultDetails.ReadOnly = Object.Executed;
	
	Items.ChangeJob.Visible = (Object.Author = Users.CurrentUser());
	Performer = ?(ValueIsFilled(Object.Performer), Object.Performer, Object.PerformerRole);
	
	If AccessRight("Update", Metadata.BusinessProcesses.ProjectJob) Then
		Items.Completed.Enabled = True;
		Items.Rejected.Enabled = True;
	Else
		Items.Completed.Enabled = False;
		Items.Rejected.Enabled = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure ReadBusinessProcessAttributes()
	
	TaskObject = FormAttributeToValue("Object");
	
	SetPrivilegedMode(True);
	
	JobObject = TaskObject.BusinessProcess.GetObject();
	JobCompleted = JobObject.JobCompleted;
	JobContent = JobObject.Content;
	
EndProcedure

&AtServer
Procedure WriteBusinessProcessAttributes(TaskObject)
	
	SetPrivilegedMode(True);
	
	BusinessProcessesAndTasksServer.LockBusinessProcesses(TaskObject.BusinessProcess);
	
	BusinessProcessObject = TaskObject.BusinessProcess.GetObject();
	
	LockDataForEdit(BusinessProcessObject.Ref);
	
	BusinessProcessObject.JobCompleted = JobCompleted;
	BusinessProcessObject.Write();

EndProcedure

&AtServer
Procedure SetItemsState()
	
	BusinessProcesses.Job.SetTaskFormItemsState(ThisObject);
	
EndProcedure

#EndRegion
