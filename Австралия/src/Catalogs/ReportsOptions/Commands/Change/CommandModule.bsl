
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	ReportsOptionsClient.ShowReportSettings(CommandParameter);
EndProcedure

#EndRegion
