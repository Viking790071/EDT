
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If DriveReUse.SettingsForSynchronizationSaaS() Then
		
		If StandardSubsystemsClientCached.ClientRunParameters().CanUseSeparatedData Then
			
			OpenForm(
				"DataProcessor.AdministrationPaneIIntegration.Form.DataSynchronizationSettings",
				New Structure,
				CommandExecuteParameters.Source,
				"DataProcessor.AdministrationPaneIIntegration.Form.DataSynchronizationSettings" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
				CommandExecuteParameters.Window);
				
		EndIf;
			
	Else
			
		OpenForm(
			"DataProcessor.AdministrationPaneIIntegration.Form.DataSynchronizationSettings",
			New Structure,
			CommandExecuteParameters.Source,
			"DataProcessor.AdministrationPaneIIntegration.Form.DataSynchronizationSettings" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
			CommandExecuteParameters.Window);
		
	EndIf;
	
EndProcedure

#EndRegion
