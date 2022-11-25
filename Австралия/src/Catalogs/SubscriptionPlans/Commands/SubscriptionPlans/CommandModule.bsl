
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure;
	
	OpenForm(
		"Catalog.SubscriptionPlans.ListForm", 
		FormParameters, 
		CommandExecuteParameters.Source, 
		"SalesInvoice", 
		CommandExecuteParameters.Window, 
		CommandExecuteParameters.URL);
	
EndProcedure

#EndRegion