
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("Catalog.ProjectTemplates.ObjectForm", New Structure("Basis", CommandParameter));
	
EndProcedure

#EndRegion
