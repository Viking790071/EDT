
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey",						"Statement");
	FormParameters.Insert("Filter",							New Structure("Products", CommandParameter));
	FormParameters.Insert("GenerateAtOpen",					True);
	FormParameters.Insert("ReportVariantCommandVisible",	False);
	
	OpenForm("Report.StockSummary.Form",
		FormParameters,
		,
		"Products=" + CommandParameter,
		CommandExecuteParameters.Window);
	
EndProcedure
