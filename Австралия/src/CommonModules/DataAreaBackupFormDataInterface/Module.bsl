#Region Private

Function GetSettingsFormParameters(Val DataArea) Export
	
	Parameters = Sales().GetSettingsFormParameters(DataArea);
	Parameters.Insert("DataArea", DataArea);
	
	Return Parameters;
	
EndFunction

Function GetAreaSettings(Val DataArea) Export
	
	Return Sales().GetAreaSettings(DataArea);
	
EndFunction

Procedure SetAreaSettings(Val DataArea, Val NewSettings, Val InitialSettings) Export
	
	Sales().SetAreaSettings(DataArea, NewSettings, InitialSettings);
	
EndProcedure

Function GetStandardSettings() Export
	
	Return Sales().GetStandardSettings();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

Function Sales()
	
	If Common.SubsystemExists("StandardSubsystems.SMDataAreaBackup") Then
		Return Common.CommonModule("DataAreaBackupFormDataInterface");
	Else
		Return Common.CommonModule("DataAreaBackupFormDataImplementationWebService");
	EndIf;
	
EndFunction

#EndRegion
