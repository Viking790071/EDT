
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	WriteParameters = New Structure;
	WriteParameters.Insert("Key", RegisterRecordKey(CommandParameter));
	WriteParameters.Insert("FillingValues", New Structure("Endpoint", CommandParameter));
	
	OpenForm("InformationRegister.MessageExchangeTransportSettings.RecordForm",
		WriteParameters, CommandExecuteParameters.Source);
	
EndProcedure
	
#EndRegion

#Region Private

&AtServer
Function RegisterRecordKey(Endpoint)
	
	Return InformationRegisters.MessageExchangeTransportSettings.CreateRecordKey(
		New Structure("Endpoint", Endpoint));
	
EndFunction

#EndRegion
