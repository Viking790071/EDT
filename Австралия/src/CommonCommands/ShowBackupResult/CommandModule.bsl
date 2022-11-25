
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	RunParameters = StandardSubsystemsClient.ClientParametersOnStart();
	BackupParameters = RunParameters.IBBackup;
	
	FormParameters = New Structure();
	
	If BackupParameters.Property("CopyingResult") Then
		FormParameters.Insert("RunMode", ?(BackupParameters.CopyingResult, "CompletedSuccessfully", "NotCompleted"));
		FormParameters.Insert("BackupFileName", BackupParameters.BackupFileName);
	EndIf;
	
	OpenForm("DataProcessor.IBBackup.Form.DataBackup", FormParameters);
	
EndProcedure

#EndRegion
