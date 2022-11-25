#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	EmailOperationsClient.CheckAccount(CommandParameter);
	
EndProcedure

#EndRegion
