
#Region Private

Procedure MonitoringCenterDumpSendingRequest() Export
	MonitoringCenterClientInternal.NotifyRequestForSendingDumps();
EndProcedure

Procedure MonitoringCenterDumpCollectionAndSendingRequest() Export
	MonitoringCenterClientInternal.NotifyRequestForReceivingDumps();
EndProcedure

Procedure MonitoringCenterContactInformationRequest() Export
	MonitoringCenterClientInternal.NotifyContactInformationRequest();
EndProcedure

#EndRegion
