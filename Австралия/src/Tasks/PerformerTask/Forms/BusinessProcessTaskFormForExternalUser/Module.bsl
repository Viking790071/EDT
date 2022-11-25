///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Executing form initialization script. For new objects it is executed in OnCreateAtServer.
	// For an existing object it is executed in OnReadAtServer.
	If Object.Ref.IsEmpty() Then
		InitializeForm();
	EndIf;
	
	SetPrivilegedMode(True);
	AuthorString = String(Object.Author);
	
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

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	BusinessProcessesAndTasksClient.TaskFormNotificationProcessing(ThisObject, EventName, Parameter, Source);
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
Procedure OpenTaskFormDecorationClick(Item)
	
	ShowValue(,Object.Ref);
	Modified = False;
	Close();
	
EndProcedure

&AtClient
Procedure SubjectClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(,Object.Topic);
	
EndProcedure

&AtClient
Procedure CompletionDateOnChange(Item)
	
	If Object.CompletionDate = BegOfDay(Object.CompletionDate) Then
		Object.CompletionDate = EndOfDay(Object.CompletionDate);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WriteAndCloseComplete(Command)
	
	BusinessProcessesAndTasksClient.WriteAndCloseComplete(ThisObject);
	
EndProcedure

&AtClient
Procedure ExecutedExecute(Command)

	BusinessProcessesAndTasksClient.WriteAndCloseComplete(ThisObject, True);

EndProcedure

&AtClient
Procedure More(Command)
	
	BusinessProcessesAndTasksClient.OpenAdditionalTaskInfo(Object.Ref);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure InitializeForm()
	
	If ValueIsFilled(Object.BusinessProcess) Then
		FormParameters = BusinessProcessesAndTasksServerCall.TaskExecutionForm(Object.Ref);
		HasBusinessProcessTaskForm = FormParameters.Property("FormName");
		Items.ExecutionFormGroup.Visible = HasBusinessProcessTaskForm;
		Items.Executed.Enabled = NOT HasBusinessProcessTaskForm;
	Else
		Items.ExecutionFormGroup.Visible = False;
	EndIf;
	InitialExecutionFlag = Object.Executed;
	If Object.Ref.IsEmpty() Then
		Object.Importance = Enums.TaskImportanceOptions.Normal;
		Object.DueDate = CurrentSessionDate();
	EndIf;
	
	Items.Topic.Hyperlink = (Object.Topic <> Undefined) And (Not Object.Topic.IsEmpty());
	SubjectString = Common.SubjectString(Object.Topic);	
	
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	Items.ExecutionStartDateScheduledTime.Visible = UseDateAndTimeInTaskDeadlines;
	Items.CompletionDateTime.Visible = UseDateAndTimeInTaskDeadlines;
	BusinessProcessesAndTasksServer.SetDateFormat(Items.DueDate);
	BusinessProcessesAndTasksServer.SetDateFormat(Items.Date);
	
	BusinessProcessesAndTasksServer.TaskFormOnCreateAtServer(ThisObject, Object,
		Items.StateGroup, Items.CompletionDate);
		
	If UsersClientServer.IsExternalUserSession() Then
		Items.Author.Visible = False;
		Items.AuthorString.Visible = True;
		Items.Performer.OpenButton = False;
	EndIf;
	
	Items.Executed.Enabled = AccessRight("Update", Metadata.Tasks.PerformerTask);
	
EndProcedure

#EndRegion
