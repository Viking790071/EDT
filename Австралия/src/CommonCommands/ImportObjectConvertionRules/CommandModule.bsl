
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	// server call
	ExchangePlanName = ExchangePlanName(CommandParameter);
	
	// server call
	RulesKind = PredefinedValue("Enum.DataExchangeRulesTypes.ObjectConversionRules");
	
	Filter              = New Structure("ExchangePlanName, RulesKind", ExchangePlanName, RulesKind);
	FillingValues = New Structure("ExchangePlanName, RulesKind", ExchangePlanName, RulesKind);
	
	DataExchangeClient.OpenInformationRegisterWriteFormByFilter(Filter, FillingValues, "DataExchangeRules", CommandExecuteParameters.Source, "ObjectConversionRules");
	
EndProcedure

&AtServer
Function ExchangePlanName(Val InfobaseNode)
	
	Return DataExchangeCached.GetExchangePlanName(InfobaseNode);
	
EndFunction

#EndRegion
