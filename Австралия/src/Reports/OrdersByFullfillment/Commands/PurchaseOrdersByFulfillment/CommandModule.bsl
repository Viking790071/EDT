#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Parameters = New Structure;
	Parameters.Insert("VariantKey", "PurchaseOrdersByFulfillment");
	
	OpenForm("Report.OrdersByFullfillment.Form",
		Parameters,
		,
		"PurchaseOrdersByFulfillment",
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion