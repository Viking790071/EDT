#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If TypeOf(CommandExecuteParameters.Source) = Type("ClientApplicationForm") Then
		CommandExecuteParameters.Source.Close();
	EndIf;
	
	DataExchangeClient.DeleteSynchronizationSetting(CommandParameter);
	
EndProcedure

#EndRegion