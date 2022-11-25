&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter",			New Structure("FixedAsset", CommandParameter));
	FormParameters.Insert("GenerateOnOpen",	True);
	
	OpenForm(
		"Report.FixedAssetUsage.Form",
		FormParameters,
		,
		"FixedAsset=" + CommandParameter,
		CommandExecuteParameters.Window);
	
EndProcedure
