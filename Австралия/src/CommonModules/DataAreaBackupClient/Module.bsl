#Region Public

// Prompt users for back up.
//
Procedure PromptUserToBackUp() Export
	
	If StandardSubsystemsClient.ClientRunParameters().DataAreaBackup Then
		
		FormName = "CommonForm.BackupCreation";
		
	Else
		
		FormName = "CommonForm.DataExport";
		
	EndIf;
	
	OpenForm(FormName);
	
EndProcedure

#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See SSLSubsystemsIntegrationClient.OnCheckIfCanBackUpInUserMode. 
Procedure OnCheckIfCanBackUpInUserMode(Result) Export
	
	If StandardSubsystemsClient.ClientRunParameters().DataSeparationEnabled Then
		
		Result = True;
		
	EndIf;
	
EndProcedure

// See SSLSubsystemsIntegrationClient.OnPromptUserForBackup. 
Procedure OnPromptUserForBackup() Export
	
	If StandardSubsystemsClient.ClientRunParameters().DataSeparationEnabled Then
		
		PromptUserToBackUp();
		
	EndIf;
	
EndProcedure

#EndRegion