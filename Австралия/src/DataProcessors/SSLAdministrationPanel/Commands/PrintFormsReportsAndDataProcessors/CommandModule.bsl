
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.SSLAdministrationPanel.Form.PrintFormsReportsAndDataProcessors",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.SSLAdministrationPanel.Form.PrintFormsReportsAndDataProcessors" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
