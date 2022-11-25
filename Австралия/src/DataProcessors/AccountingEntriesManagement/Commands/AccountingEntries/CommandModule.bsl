
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterParameters = New Structure("Recorder", CommandParameter);
	FormParameters = New Structure("Filter", FilterParameters);
	OpenForm("DataProcessor.AccountingEntriesManagement.Form.DocumentAccountingEntries",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandParameter,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion