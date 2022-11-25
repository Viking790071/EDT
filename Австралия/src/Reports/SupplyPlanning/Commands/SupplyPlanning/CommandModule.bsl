&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("Report.SupplyPlanning.Form",
		New Structure("Filter, GenerateOnOpen", New Structure("SalesOrder", CommandParameter), True),
		,
		"SalesOrder=" + CommandParameter,
		CommandExecuteParameters.Window);
	
EndProcedure
