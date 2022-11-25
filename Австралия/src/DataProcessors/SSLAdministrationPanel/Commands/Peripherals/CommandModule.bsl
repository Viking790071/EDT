#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.SSLAdministrationPanel.Form.Peripherals",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.SSLAdministrationPanel.Form.Peripherals" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window
	);
	
EndProcedure

#EndRegion
