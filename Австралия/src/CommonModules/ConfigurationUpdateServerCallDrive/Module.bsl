#Region Private

// Receives the settings of update assistant from common settings storage.
//
// Details - see description InstallUpdates.ReceiveAssistantSettingsStructure().
//
Function GetSettingsStructureOfAssistant() Export
	
	Return DataProcessors.InstallUpdates.GetSettingsStructureOfAssistant();
	
EndFunction

// Writes the settings of update assistant to common settings storage.
//
// Details - see description InstallUpdates.WriteAssistantSettingsStructure().
//
Procedure WriteStructureOfAssistantSettings(ConfigurationUpdateOptions, MessagesForEventLogMonitor = Undefined) Export
	
	DataProcessors.InstallUpdates.WriteStructureOfAssistantSettings(ConfigurationUpdateOptions, MessagesForEventLogMonitor);
	
EndProcedure

// It returns the structure of the parameters
// required for the client configuration code working. 
//
Function ClientWorkParameters() Export
	
	Parameters = New Structure;
	
	DataProcessors.InstallUpdates.AddClientWorkParameters(Parameters);
	
	Return Common.FixedData(Parameters);
	
EndFunction


#EndRegion
