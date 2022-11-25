///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Executing form initialization script. For new objects it is executed in OnCreateAtServer.
	// For an existing object it is executed in OnReadAtServer.
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
	If NOT (WriteParameters.Property("ExecuteTask", ExecuteTask) AND ExecuteTask) Then
		Return;
	EndIf;
	
	If NOT JobCompleted AND NOT ValueIsFilled(CurrentObject.ExecutionResult) Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Укажите причину, по которой задача отклоняется.'; en = 'Specify the reason why the task is declined.'; pl = 'Określ powód, dla którego zadanie jest odrzucone.';es_ES = 'Especificar la razón por la que se ha rechazado la tarea.';es_CO = 'Especificar la razón por la que se ha rechazado la tarea.';tr = 'Görevin reddedilmesinin sebebini belirtin.';it = 'Indicare il motivo del rifiuto dell''incarico.';de = 'Geben Sie den Grund ein, warum die Aufgabe abgelehnt ist.'"),,
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
	If EventName = "Write_Job" Then
		If (Source = Object.BusinessProcess OR (TypeOf(Source) = Type("Array") 
			AND Source.Find(Object.BusinessProcess) <> Undefined)) Then
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
Procedure WriteAndCloseComplete()
	
	BusinessProcessesAndTasksClient.WriteAndCloseComplete(ThisObject);
	
EndProcedure

&AtClient
Procedure SubjectClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(,Object.Topic);
	
EndProcedure

// StandardSubsystems.FilesOperations
&AtClient
Procedure Attachable_PreviewFieldClick(Item, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldClick(ThisObject, Item, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_PreviewFieldDragCheck(Item, DragParameters, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldCheckDragging(ThisObject, Item,
			DragParameters, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_PreviewFieldDrag(Item, DragParameters, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldDrag(ThisObject, Item,
			DragParameters, StandardProcessing);
	EndIf;
	
EndProcedure
// End StandardSubsystems.FilesOperations

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CompletedComplete(Command)
	
	JobCompleted = True;
	BusinessProcessesAndTasksClient.WriteAndCloseComplete(ThisObject, True);
	
EndProcedure

&AtClient
Procedure Canceled(Command)
	
	JobCompleted = False;
	BusinessProcessesAndTasksClient.WriteAndCloseComplete(ThisObject, True);
	
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
	ShowValue(,Object.BusinessProcess);
	
EndProcedure

// StandardSubsystems.FilesOperations
&AtClient
Procedure Attachable_AttachedFilesPanelCommand(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.AttachmentsControlCommand(ThisObject, Command);
	EndIf;
	
EndProcedure
// End StandardSubsystems.FilesOperations

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
	BusinessProcessesAndTasksServer.SetDateFormat(Items.DueDate);
	BusinessProcessesAndTasksServer.SetDateFormat(Items.Date);
	
	BusinessProcessesAndTasksServer.TaskFormOnCreateAtServer(ThisObject, Object,
		Items.StateGroup, Items.CompletionDate);
	Items.ResultDetails.ReadOnly = Object.Executed;
	
	Items.ChangeJob.Visible = (Object.Author = Users.CurrentUser());
	Performer = ?(ValueIsFilled(Object.Performer), Object.Performer, Object.PerformerRole);
	
	If AccessRight("Update", Metadata.BusinessProcesses.Job) Then
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
	JobExecutionResult = JobObject.ExecutionResult;
	JobContent = JobObject.Content;
	
EndProcedure

&AtServer
Procedure WriteBusinessProcessAttributes(TaskObject)
	
	SetPrivilegedMode(True);
	BusinessProcessesAndTasksServer.LockBusinessProcesses(TaskObject.BusinessProcess);
	BusinessProcessObject = TaskObject.BusinessProcess.GetObject();
	LockDataForEdit(BusinessProcessObject.Ref);
	BusinessProcessObject.JobCompleted = JobCompleted;
	BusinessProcessObject.Write(); // ACC:1327 The lock is set in the BusinessProcessesAndTasksServer.LockBusinessProcesses.

EndProcedure

&AtServer
Procedure SetItemsState()
	
	BusinessProcesses.Job.SetTaskFormItemsState(ThisObject);
	
EndProcedure	

#EndRegion
