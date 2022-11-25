#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	ReportsOptionsClient.ShowReportBar("Administration", CommandExecuteParameters);
EndProcedure

#EndRegion
