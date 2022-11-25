
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	ReportsOptionsClient.OpenOptionArrangeInSectionsDialog(CommandParameter, CommandExecuteParameters.Source);
EndProcedure

#EndRegion
