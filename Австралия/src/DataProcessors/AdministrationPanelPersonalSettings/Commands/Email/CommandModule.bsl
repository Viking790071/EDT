#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	UniqueParm = ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", "");
	
	OpenForm("DataProcessor.AdministrationPanelPersonalSettings.Form.Email",
		New Structure,
		CommandExecuteParameters.Source,
		"DataProcessor.AdministrationPanelPersonalSettings.Form.Email" + UniqueParm,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
