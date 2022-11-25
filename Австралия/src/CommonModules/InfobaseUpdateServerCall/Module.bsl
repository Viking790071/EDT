#Region Internal

// Used for integration with the subsystem "Configurations update".
// See the ConfigurationUpdateFileTemplate template for UpdateInstallation processing.
//
Function UpdateInfobase(ExecuteDeferredHandlers = False) Export
	
	StartDate = CurrentSessionDate();
	Result = InfobaseUpdate.UpdateInfobase(ExecuteDeferredHandlers);
	EndDate = CurrentSessionDate();
	InfobaseUpdateInternal.WriteUpdateExecutionTime(StartDate, EndDate);
	
	Return Result;
	
EndFunction

#EndRegion
