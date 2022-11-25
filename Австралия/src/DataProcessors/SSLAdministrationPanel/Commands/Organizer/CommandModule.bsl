
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.SSLAdministrationPanel.Form.Organizer",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.SSLAdministrationPanel.Form.Organizer" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
