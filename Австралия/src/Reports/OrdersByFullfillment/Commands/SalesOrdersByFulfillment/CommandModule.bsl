#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Parameters = New Structure;
	Parameters.Insert("VariantKey", "SalesOrdersByFulfillment");
	
	OpenForm("Report.OrdersByFullfillment.Form",
		Parameters,
		,
		"SalesOrdersByFulfillment",
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion