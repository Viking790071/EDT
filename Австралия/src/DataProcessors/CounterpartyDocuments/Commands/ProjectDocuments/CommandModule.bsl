
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("Filter, SettingKey, GenerateOnOpen",
		New Structure("Project", CommandParameter),
		"Project",
		True);
	
	OpenForm("DataProcessor.CounterpartyDocuments.Form.ProjectDocuments",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
