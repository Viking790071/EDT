
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	ReportsOptionsClient.OpenResetPlacementSettingsDialog(CommandParameter, CommandExecuteParameters.Source);
EndProcedure

#EndRegion
