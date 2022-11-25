
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Parameters = New Structure;
	
	// External parameters of the result description.
	Parameters.Insert("Cancel", False);
	Parameters.Insert("Warnings", StandardSubsystemsClient.ClientParameter("ExitWarnings"));
	
	// External parameters of the execution management.
	Parameters.Insert("InteractiveHandler", Undefined); // NotifyDescription.
	Parameters.Insert("ContinuationHandler",   Undefined); // NotifyDescription.
	Parameters.Insert("ContinuousExecution", True);
	
	// Internal parameters.
	Parameters.Insert("CompletionProcessing", New NotifyDescription(
		"ActionsBeforeExitCompletionHandler", StandardSubsystemsClient, Parameters));
	
	StandardSubsystemsClient.ActionsBeforeExit(Parameters);
	
EndProcedure

#EndRegion