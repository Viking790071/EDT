
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	DataExchangeClient.GoToDataEventLog(CommandParameter, CommandExecuteParameters, "DataImport");
	
EndProcedure

#EndRegion
