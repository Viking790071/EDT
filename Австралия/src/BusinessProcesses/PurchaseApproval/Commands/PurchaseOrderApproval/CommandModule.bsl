
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("BusinessProcess.PurchaseApproval.ObjectForm", New Structure("Basis",  CommandParameter));
	
EndProcedure

#EndRegion