#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	OpeningParameters = New Structure;
	If TypeOf(CommandExecuteParameters.Source) = Type("ClientApplicationForm") Then
		OpeningParameters.Insert("JobID", CommandExecuteParameters.Source.MonitoringCenterJobID);
		OpeningParameters.Insert("JobResultAddress", CommandExecuteParameters.Source.MonitoringCenterJobResultAddress);
	EndIf;
	OpenForm("DataProcessor.MonitoringCenterSettings.Form.MonitoringCenterSettings", OpeningParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

#EndRegion