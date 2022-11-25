#Region Public

// Executes the handler of automatic backup start during user working, as well as repeats 
// notification after the initial one was ignored.
//
Procedure BackupActionsHandler() Export 
	
	IBBackupClient.StartIdleHandler();
	
EndProcedure

#EndRegion
