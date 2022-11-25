#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("VariantKey, GenerateOnOpen, ReportOptionsCommandsVisibility", 
		"Default",
		True,
		False);
	
	OpenForm("Report.SalesVariance.Form",
		FormParameters,
		CommandExecuteParameters.Source,
		True,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

#EndRegion