
#Region EventSubscriptionHandler

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInfo, StandardProcessing)
	
	StandardProcessing = False;
	SelectedForm = "DataProcessor.IBBackupSetup.Form.BackupSetupClientServer";
	
	#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		
		If Common.FileInfobase() Then
			SelectedForm = "DataProcessor.IBBackupSetup.Form.BackupSetup";
		EndIf;
		
	#EndIf
	
EndProcedure

#EndRegion