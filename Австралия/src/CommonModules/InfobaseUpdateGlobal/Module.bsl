#Region Private

// Checks deferred update status. If there occurred errors during an update procedure, this function 
// informs a user and an administrator about it.
//
Procedure CheckDeferredUpdateStatus() Export
	
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	
	If ClientParameters.Property("ShowInvalidHandlersMessage") Then
		OpenForm("DataProcessor.ApplicationUpdateResult.Form.DeferredIBUpdateProgressIndicator");
	Else
		InfobaseUpdateClient.NotifyDeferredHandlersNotExecuted();
	EndIf;
	
EndProcedure

#EndRegion
