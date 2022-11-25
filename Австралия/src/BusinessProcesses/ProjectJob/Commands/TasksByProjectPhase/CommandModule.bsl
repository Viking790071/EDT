#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Filter = New Structure("ProjectPhase", CommandParameter);
	
	OpenForm("BusinessProcess.ProjectJob.Form.TasksByProject",
		New Structure("Filter", Filter),
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
