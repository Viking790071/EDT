
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.SSLAdministrationPanel.Form.FilesOperationSettings",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.SSLAdministrationPanel.Form.FilesOperationSettings" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
