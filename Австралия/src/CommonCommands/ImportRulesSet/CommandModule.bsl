#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ExchangePlanInfo = ExchangePlanInfo(CommandParameter);
	
	If ExchangePlanInfo.SeparatedMode Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Загрузка правил обмена данными в разделенном режиме недоступна.'; en = 'Cannot import data exchange rules in the split mode.'; pl = 'Pobieranie reguł wymiany danych w rozdzielonym trybie jest niedostępne.';es_ES = 'Carga de reglas de intercambio de datos en el modo separado no disponible.';es_CO = 'Carga de reglas de intercambio de datos en el modo separado no disponible.';tr = 'Bölünmüş modda veri alışverişi kuralları içe aktarılamaz.';it = 'Impossibili importate le regole di scambio dati in modalità separata.';de = 'Das Herunterladen von Datenaustauschregeln im Split-Modus ist nicht möglich.'"));
		Return;
	EndIf;
	
	If ExchangePlanInfo.ConversionRulesAreUsed Then
		DataExchangeClient.ImportDataSyncRules(ExchangePlanInfo.ExchangePlanName);
	Else
		Filter              = New Structure("ExchangePlanName, RulesKind", ExchangePlanInfo.ExchangePlanName, ExchangePlanInfo.ORRRulesKind);
		FillingValues = New Structure("ExchangePlanName, RulesKind", ExchangePlanInfo.ExchangePlanName, ExchangePlanInfo.ORRRulesKind);
		
		DataExchangeClient.OpenInformationRegisterWriteFormByFilter(Filter, FillingValues, "DataExchangeRules", 
			CommandParameter, "ObjectsRegistrationRules");
	EndIf;
		
EndProcedure

#EndRegion

#Region Private

&AtServer
Function ExchangePlanInfo(Val InfobaseNode)
	
	Result = New Structure("SeparatedMode",
		Common.DataSeparationEnabled() AND Common.SeparatedDataUsageAvailable());
		
	If Not Result.SeparatedMode Then
		Result.Insert("ExchangePlanName",
			DataExchangeCached.GetExchangePlanName(InfobaseNode));
			
		Result.Insert("ConversionRulesAreUsed",
			DataExchangeCached.HasExchangePlanTemplate(Result.ExchangePlanName, "ExchangeRules"));
			
		Result.Insert("ORRRulesKind", Enums.DataExchangeRulesTypes.ObjectsRegistrationRules);
	EndIf;
	
	Return Result;
	
EndFunction


#EndRegion