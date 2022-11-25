
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Filter              = New Structure("Correspondent", CommandParameter);
	FillingValues = New Structure("Correspondent", CommandParameter);
	
	DataExchangeClient.OpenInformationRegisterWriteFormByFilter(Filter,
		FillingValues, "DataExchangeTransportSettings", CommandExecuteParameters.Source);
	
EndProcedure

#EndRegion
