#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	OpenForm("DataProcessor.MonitoringCenterSettings.Form.SendContactInformation", , ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

#EndRegion