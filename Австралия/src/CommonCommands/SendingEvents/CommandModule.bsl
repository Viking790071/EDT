
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	DataExchangeClient.GoToDataEventLog(CommandParameter, CommandExecuteParameters, "DataExport");
	
EndProcedure

#EndRegion
