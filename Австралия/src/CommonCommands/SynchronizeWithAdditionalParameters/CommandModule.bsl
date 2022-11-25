
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	DataExchangeClient.OpenObjectsMappingWizardCommandProcessing(CommandParameter, CommandExecuteParameters.Source);
	
EndProcedure

#EndRegion
