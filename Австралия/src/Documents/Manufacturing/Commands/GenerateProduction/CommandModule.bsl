#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("Basis", CommandParameter);
	OpenForm("Document.Manufacturing.ObjectForm",
		FormParameters);

EndProcedure

#EndRegion