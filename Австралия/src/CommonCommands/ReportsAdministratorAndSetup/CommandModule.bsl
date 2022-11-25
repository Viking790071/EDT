#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, ExecuteParameters)
	ReportsOptionsClient.ShowReportBar("SetupAndAdministration", ExecuteParameters);
EndProcedure

#EndRegion
