#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Parameters = New Structure;
	Parameters.Insert("VariantKey", "Default");
	Parameters.Insert("PurposeUseKey", CommandParameter);
	Parameters.Insert("Order", CommandParameter[0]);
	Parameters.Insert("GenerateOnOpen", True);

	
	OpenForm("Report.TransferOrderAnalysis.Form",
		Parameters,
		,
		"TransferOrder=" + CommandParameter,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
