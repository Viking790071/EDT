#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Parameters = New Structure;
	Parameters.Insert("VariantKey", "Default");
	Parameters.Insert("PurposeUseKey", CommandParameter);
	Parameters.Insert("Filter", New Structure("TransferOrder, FilterByOrders", CommandParameter, "NoFilter"));
	Parameters.Insert("GenerateOnOpen", True);

	OpenForm("Report.TransferOrdersAnalysis.Form",
		Parameters,
		,
		"TransferOrder=" + CommandParameter,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
