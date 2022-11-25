#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	EDIClient.CheckConnection(CommandParameter);
	
EndProcedure

#EndRegion