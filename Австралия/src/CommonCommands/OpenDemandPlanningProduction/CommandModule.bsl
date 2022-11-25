#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"DataProcessor.DemandPlanning.Form",
		New Structure("PurchasesOnly", False),
		CommandExecuteParameters.Source,
		"DemandPlanningProduction",
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion