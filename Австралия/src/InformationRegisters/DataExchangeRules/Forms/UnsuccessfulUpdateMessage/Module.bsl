
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	ExchangePlanName = Parameters.ExchangePlanName;
	ExchangePlanSynonym = Metadata.ExchangePlans[ExchangePlanName].Synonym;
	
	ObjectConversionRules = Enums.DataExchangeRulesTypes.ObjectConversionRules;
	ObjectsRegistrationRules = Enums.DataExchangeRulesTypes.ObjectsRegistrationRules;
	
	WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Error,,,
		Parameters.DetailedErrorPresentation);
		
	ErrorMessage = Items.ErrorMessageText.Title;
	ErrorMessage = StrReplace(ErrorMessage, "%2", Parameters.BriefErrorPresentation);
	ErrorMessage = StrReplaceWithFormalization(ErrorMessage, "%1", ExchangePlanSynonym);
	Items.ErrorMessageText.Title = ErrorMessage;
	
	RulesFromFile = InformationRegisters.DataExchangeRules.RulesFromFileUsed(ExchangePlanName, True);
	
	If RulesFromFile.ConversionRules AND RulesFromFile.RecordRules Then
		RulesType = NStr("ru = 'конвертации и регистрации'; en = 'conversions and registrations'; pl = 'konwersje i rejestracje';es_ES = 'conversiones y registros';es_CO = 'conversiones y registros';tr = 'dönüşümler ve kayıtlar';it = 'Conversioni e registrazioni';de = 'Umrechnungen und Registrierungen'");
	ElsIf RulesFromFile.ConversionRules Then
		RulesType = NStr("ru = 'конвертации'; en = 'conversions'; pl = 'konwersje';es_ES = 'de conversión';es_CO = 'de conversión';tr = 'dönüştürme';it = 'conversioni';de = 'Konvertierungen'");
	ElsIf RulesFromFile.RecordRules Then
		RulesType = NStr("ru = 'регистрации'; en = 'registrations'; pl = 'rejestracje';es_ES = 'de registro';es_CO = 'de registro';tr = 'kayıt';it = 'registrazioni';de = 'Registrierungen'");
	EndIf;
	
	Items.RulesTextFromFile.Title = StringFunctionsClientServer.SubstituteParametersToString(
		Items.RulesTextFromFile.Title, ExchangePlanSynonym, RulesType);
	
	UpdateStartTime = Parameters.UpdateStartTime;
	If Parameters.UpdateEndTime = Undefined Then
		UpdateEndTime = CurrentSessionDate();
	Else
		UpdateEndTime = Parameters.UpdateEndTime;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ExitApplication(Command)
	Close(True);
EndProcedure

&AtClient
Procedure GoToEventLog(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("StartDate", UpdateStartTime);
	FormParameters.Insert("EndDate", UpdateEndTime);
	FormParameters.Insert("RunNotInBackground", True);
	EventLogClient.OpenEventLog(FormParameters);
	
EndProcedure

&AtClient
Procedure Restart(Command)
	Close(False);
EndProcedure

&AtClient
Procedure ImportRulesSet(Command)
	
	DataExchangeClient.ImportDataSyncRules(ExchangePlanName);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function StrReplaceWithFormalization(Row, SearchSubstring, ReplaceSubstring)
	
	StartPosition = StrFind(Row, SearchSubstring);
	
	StringArray = New Array;
	
	StringArray.Add(Left(Row, StartPosition - 1));
	StringArray.Add(New FormattedString(ReplaceSubstring, New Font(,,True)));
	StringArray.Add(Mid(Row, StartPosition + StrLen(SearchSubstring)));
	
	Return New FormattedString(StringArray);
	
EndFunction

#EndRegion