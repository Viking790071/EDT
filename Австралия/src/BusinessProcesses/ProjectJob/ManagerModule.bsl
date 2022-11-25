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
	Result.Add("DueDate");
	
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
	Result.Insert("FormName", "BusinessProcess.ProjectJob.Form.ActionExecute");
	
	Return Result;
	
EndFunction

// The function is called when forwarding a task.
//
// Parameters:
//   TaskRef  - TaskRef.PerformerTask - a forwarded task.
//   NewTaskRef  - TaskRef.PerformerTask - a task for a new assignee.
//
Procedure OnForwardTask(TaskRef, NewTaskRef) Export
	
	BusinessProcessObject = TaskRef.BusinessProcess.GetObject();
	LockDataForEdit(BusinessProcessObject.Ref);
	SetPrivilegedMode(True);
	BusinessProcessObject.Write();
	
EndProcedure

// The function is called when a task is executed from a list form.
//
// Parameters:
//   TaskRef  - TaskRef.PerformerTask - a task.
//   BusinessProcessRef - BusinessProcessRef - a business process for which the TaskRef task is generated.
//   BusinessProcessRoutePoint - BusinessProcessRoutePointRef - a route point.
//
Procedure DefaultCompletionHandler(TaskRef, BusinessProcessRef, BusinessProcessRoutePoint) Export
	
	IsRoutePointComplete = (BusinessProcessRoutePoint = BusinessProcesses.ProjectJob.RoutePoints.Execute);
	If Not IsRoutePointComplete Then
		Return;
	EndIf;
	
	BeginTransaction();
	
	Try
		
		BusinessProcessesAndTasksServer.LockBusinessProcesses(BusinessProcessRef);
		
		SetPrivilegedMode(True);
		
		JobObject = BusinessProcessRef.GetObject();
		LockDataForEdit(JobObject.Ref);
		
		If IsRoutePointComplete Then
			JobObject.JobCompleted = True;
		EndIf;
		
		JobObject.Write();
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// End StandardSubsystems.BusinessProcessesAndTasks

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
		Return ModuleGeneration.AddGenerationCommand(GenerationCommands, Metadata.BusinessProcesses.ProjectJob);
	EndIf;
	
	Return Undefined;
	
EndFunction

// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion

#Region Private

// Sets the state of the task form items.
Procedure SetTaskFormItemsState(Form) Export
	
	Form.Items.Topic.Hyperlink = (Form.Object.Topic <> Undefined And Not Form.Object.Topic.IsEmpty());
	Form.SubjectString = Common.SubjectString(Form.Object.Topic);
	
EndProcedure

#EndRegion

#EndIf