#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	DataExchangeClient.OpenCompositionOfDataToSend(CommandParameter);
	
EndProcedure

#EndRegion