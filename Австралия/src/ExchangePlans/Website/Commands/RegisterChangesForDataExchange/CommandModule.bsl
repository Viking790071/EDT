#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("ExchangeNode", CommandParameter);
	OpenForm("DataProcessor.RegisterChangesForDataExchange.Form.Form",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
		
EndProcedure

#EndRegion