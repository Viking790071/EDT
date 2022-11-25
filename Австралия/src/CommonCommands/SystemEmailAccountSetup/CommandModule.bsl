
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"Catalog.EmailAccounts.ObjectForm",
		New Structure("Key", Account()),
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function Account()
	
	Return EmailOperations.SystemAccount();
	
EndFunction

#EndRegion
