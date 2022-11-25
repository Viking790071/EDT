#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ShowValue(, UsersClientServer.AuthorizedUser());
	
EndProcedure

#EndRegion