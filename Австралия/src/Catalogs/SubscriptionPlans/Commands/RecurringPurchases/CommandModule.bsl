
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("PurchaseDocumentsSchedule", True);
	
	OpenForm(
		"Catalog.SubscriptionPlans.ListForm", 
		FormParameters, 
		CommandExecuteParameters.Source, 
		"PurchaseOrder", 
		CommandExecuteParameters.Window, 
		CommandExecuteParameters.URL);
	
EndProcedure

#EndRegion