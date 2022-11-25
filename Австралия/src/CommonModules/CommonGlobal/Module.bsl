#Region Private

// Asks whether the user wants to continue the action that will discard the changes.
//
Procedure ConfirmFormClosingNow() Export
	
	CommonInternalClient.ConfirmFormClosing();
	
EndProcedure

// Asks whether the user wants to continue the action that closes the form.
//
Procedure ConfirmArbitraryFormClosingNow() Export
	
	CommonInternalClient.ConfirmArbitraryFormClosing();
	
EndProcedure

#EndRegion
