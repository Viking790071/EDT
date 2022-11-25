///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchObjectsModification

// Returns object attributes allowed to be edited using batch attribute change data processor.
// 
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToEditInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("Author");
	Result.Add("Importance");
	Result.Add("Performer");
	Result.Add("CheckExecution");
	Result.Add("Supervisor");
	Result.Add("DueDate");
	Result.Add("VerificationDueDate");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchObjectsModification

// StandardSubsystems.BusinessProcessesAndTasks

// Gets a structure with description of a task execution form.
// The function is called when opening the task execution form.
//
// Parameters:
//   TaskRef                - TaskRef.PerformerTask - a task.
//   BusinessProcessRoutePoint - BusinessProcessRoutePointRef - a route point.
//
// Returns:
//   Structure   - a structure with description of the task execution form.
//                 Key FormName contains the form name that is passed to the OpenForm() context method.
//                 Key FormOptions contains the form parameters.
//
Function TaskExecutionForm(TaskRef, BusinessProcessRoutePoint) Export
	
	Result = New Structure;
	Result.Insert("FormParameters", New Structure("Key", TaskRef));
	Result.Insert("FormName", "BusinessProcess.Job.Form.Action" + BusinessProcessRoutePoint.Name);
	Return Result;
	
EndFunction

// The function is called when forwarding a task.
//
// Parameters:
//   TaskRef  - TaskRef.PerformerTask - a forwarded task.
//   NewTaskRef  - TaskRef.PerformerTask - a task for a new assignee.
//
Procedure OnForwardTask(TaskRef, NewTaskRef) Export
	
	// ACC:1327-off The business process lock is set earlier in the BusinessProcessesAndTasksServerCall.
	// ForwardTasks calling function.
	BusinessProcessObject = TaskRef.BusinessProcess.GetObject();
	LockDataForEdit(BusinessProcessObject.Ref);
	BusinessProcessObject.ExecutionResult = ExecutionResultOnForward(TaskRef) 
		+ BusinessProcessObject.ExecutionResult;
	SetPrivilegedMode(True);
	BusinessProcessObject.Write();
	// ACC:1327-on
	
EndProcedure

// The function is called when a task is executed from a list form.
//
// Parameters:
//   TaskRef  - TaskRef.PerformerTask - a task.
//   BusinessProcessRef - BusinessProcessRef - a business process for which the TaskRef task is generated.
//   BusinessProcessRoutePoint - BusinessProcessRoutePointRef - a route point.
//
Procedure DefaultCompletionHandler(TaskRef, BusinessProcessRef, BusinessProcessRoutePoint) Export
	
	IsRoutePointComplete = (BusinessProcessRoutePoint = BusinessProcesses.Job.RoutePoints.Execute);
	IsRoutePointCheck = (BusinessProcessRoutePoint = BusinessProcesses.Job.RoutePoints.Check);
	If Not IsRoutePointComplete AND Not IsRoutePointCheck Then
		Return;
	EndIf;
	
	// Setting default values for batch task execution.
	BeginTransaction();
	Try
		BusinessProcessesAndTasksServer.LockBusinessProcesses(BusinessProcessRef);
		
		SetPrivilegedMode(True);
		JobObject = BusinessProcessRef.GetObject();
		LockDataForEdit(JobObject.Ref);
		
		If IsRoutePointComplete Then
			JobObject.JobCompleted = True;	
		ElsIf IsRoutePointCheck Then
			JobObject.JobCompleted = True;
			JobObject.Confirmed = True;
		EndIf;
		JobObject.Write(); // ACC:1327 The lock is set in the BusinessProcessesAndTasksServer.LockBusinessProcesses.
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;	
	
EndProcedure	

// End StandardSubsystems.BusinessProcessesAndTasks

// StandardSubsystems.AccessManagement

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AttachAdditionalTables
	|ThisList AS Job
	|
	|LEFT JOIN InformationRegister.TaskPerformers AS TaskPerformers
	|ON
	|	TaskPerformers.PerformerRole = Job.Performer
	|	AND TaskPerformers.MainAddressingObject = Job.MainAddressingObject
	|	AND TaskPerformers.AdditionalAddressingObject = Job.AdditionalAddressingObject
	|
	|LEFT JOIN InformationRegister.TaskPerformers AS TaskSupervisors
	|ON
	|	TaskSupervisors.PerformerRole = Job.Supervisor
	|	AND TaskSupervisors.MainAddressingObject = Job.MainAddressingObjectSupervisor
	|	AND TaskSupervisors.AdditionalAddressingObject = Job.AdditionalAddressingObjectSupervisor
	|;
	|AllowRead
	|WHERE
	|	ValueAllowed(Author)
	|	OR ValueAllowed(Performer EXCEPT Catalog.PerformerRoles)
	|	OR ValueAllowed(TaskPerformers.Performer)
	|	OR ValueAllowed(Supervisor EXCEPT Catalog.PerformerRoles)
	|	OR ValueAllowed(TaskSupervisors.Performer)
	|;
	|AllowUpdateIfReadingAllowed
	|WHERE
	|	ValueAllowed(Author)";
	
EndProcedure

// End StandardSubsystems.AccessManagement

// StandardSubsystems.AttachableCommands

// Defined the list of commands for creating on the basis.
//
// Parameters:
//  GenerationCommands - ValueTable - see GenerationOverridable.BeforeAddGenerationCommands. 
//  Parameters - Structure - see GenerationOverridable.BeforeAddGenerationCommands. 
//
Procedure AddGenerationCommands(GenerationCommands, Parameters) Export
	
EndProcedure

// Use this procedure in the AddGenerationCommands procedure of other object manager modules.
// Adds this object to the list of object generation commands.
//
// Parameters:
//  GenerationCommands - ValueTable - see GenerationOverridable.BeforeAddGenerationCommands. 
//
// Returns:
//  ValueTableRow, Undefined - details of the added command.
//
Function AddGenerateCommand(GenerationCommands) Export
	
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleGeneration = Common.CommonModule("Generate");
		Return ModuleGeneration.AddGenerationCommand(GenerationCommands, Metadata.BusinessProcesses.Job);
	EndIf;
	
	Return Undefined;
	
EndFunction

// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion

#EndIf

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Other

// Sets the state of the task form items.
Procedure SetTaskFormItemsState(Form) Export
	
	If Form.Items.Find("ExecutionResult") <> Undefined 
		AND Form.Items.Find("ExecutionHistory") <> Undefined Then
			Form.Items.ExecutionHistory.Picture = CommonClientServer.CommentPicture(Form.JobExecutionResult);
	EndIf;
	
	Form.Items.Topic.Hyperlink = Form.Object.Topic <> Undefined AND NOT Form.Object.Topic.IsEmpty();
	Form.SubjectString = Common.SubjectString(Form.Object.Topic);	
	
EndProcedure

Function ExecutionResultOnForward(Val TaskRef)
	
	StringFormat = "%1, %2 " + NStr("ru = 'перенаправил(а) задачу'; en = 'redirected the task'; pl = 'przekierowano zadanie';es_ES = 'redirigir la tarea';es_CO = 'redirigir la tarea';tr = 'görev yeniden yönlendirildi';it = 'incarico reindirizzato';de = 'die Aufgabe weitergeleitet'") + ":
		|%3
		|";
	
	Comment = TrimAll(TaskRef.ExecutionResult);
	Comment = ?(IsBlankString(Comment), "", Comment + Chars.LF);
	Result = StringFunctionsClientServer.SubstituteParametersToString(StringFormat, TaskRef.CompletionDate, TaskRef.Performer, Comment);
	Return Result;

EndFunction

#EndRegion

#EndIf