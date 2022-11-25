&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructure = New Structure("Counterparty", CommandParameter);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey", "StatementBrieflyContext");
	FormParameters.Insert("PurposeUseKey", "StatementBrieflyContextByCounterparty");
	FormParameters.Insert("Filter", FilterStructure);
	FormParameters.Insert("GenerateOnOpen", True);
	FormParameters.Insert("ReportOptionsCommandsVisibility", False);
	
	OpenForm("Report.StatementOfAccount.Form",
		FormParameters,
		,
		"Counterparty=" + CommandParameter,
		CommandExecuteParameters.Window
	);
	
EndProcedure
