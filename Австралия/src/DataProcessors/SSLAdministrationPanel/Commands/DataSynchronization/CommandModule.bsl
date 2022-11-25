
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If StandardSubsystemsClient.ClientRunParameters().SeparatedDataUsageAvailable Then
		NameOfFormToOpen = "DataProcessor.SSLAdministrationPanel.Form.DataSynchronization";
	Else
		NameOfFormToOpen = "DataProcessor.SSLAdministrationPanelSaaS.Form.DataSynchronizationForServiceAdministrator";
	EndIf;
	
	OpenForm(
		NameOfFormToOpen,
		New Structure,
		CommandExecuteParameters.Source,
		NameOfFormToOpen + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
