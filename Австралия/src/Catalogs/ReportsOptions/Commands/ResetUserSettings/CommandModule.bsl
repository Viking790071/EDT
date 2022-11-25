
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	ReportsOptionsClient.OpenResetUserSettingsDialog(CommandParameter, CommandExecuteParameters.Source);
EndProcedure

#EndRegion
