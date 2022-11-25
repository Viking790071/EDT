
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("CommonForm.ServiceUsers",, CommandExecuteParameters.Source);
	
EndProcedure

#EndRegion
