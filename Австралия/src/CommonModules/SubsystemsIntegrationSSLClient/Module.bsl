////////////////////////////////////////////////////////////////////////////////
// Subsystem-to-Subsystem integration.
// Here you can find processors of program events that occur in source subsystems when there are 
// several destination subsystems or the destination subsystem list is not predefined.
//

#Region Internal

#Region Core

// See CommonClientOverridable.BeforeStart. 
Procedure BeforeStart(Parameters) Export
	
	// Start measuring application start time.
	If CommonClient.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitorClient = CommonClient.CommonModule("PerformanceMonitorClient");
		Parameters.Modules.Add(ModulePerformanceMonitorClient);
	EndIf;
	
	// Checking whether the user has minimum rights to access the application.
	Parameters.Modules.Add(UsersInternalClient);
	
	// Checking whether the infobase is locked for updating.
	Parameters.Modules.Add(InfobaseUpdateClient);
	
	// Checking whether the current version is equal or higher than the recommended one.
	Parameters.Modules.Add(New Structure("Module, Number", StandardSubsystemsClient, 2));
	
	// Checking whether reconnection the master node is necessary. 
	Parameters.Modules.Add(New Structure("Module, Number", StandardSubsystemsClient, 3));
	
	// Checking whether data areas are locked for update.
	If CommonClient.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaSClient = CommonClient.CommonModule("SaaSClient");
		Parameters.Modules.Add(ModuleSaaSClient);
	EndIf;
	
	// Checking whether updating the infobase is legal.
	If CommonClient.SubsystemExists(
		   "StandardSubsystems.SoftwareLicenseCheck") Then
		
		ModuleSoftwareLicenseCheckClient =
			CommonClient.CommonModule("SoftwareLicenseCheckClient");
		
		Parameters.Modules.Add(ModuleSoftwareLicenseCheckClient);
	EndIf;
	
	// Asking the user to continue with or without repeating data exchange message import.
	If CommonClient.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeClient = CommonClient.CommonModule("DataExchangeClient");
		Parameters.Modules.Add(ModuleDataExchangeClient);
	EndIf;
	
	// Checking the status for deferred update handler.
	Parameters.Modules.Add(New Structure("Module, Number", InfobaseUpdateClient, 2));
	
	// Exporting and updating application operating settings.
	Parameters.Modules.Add(New Structure("Module, Number", InfobaseUpdateClient, 3));
	
	// Initial standalone workstation setup.
	If CommonClient.SubsystemExists(
	       "CloudTechnology.SaaS.DataExchangeSaaS") Then
		
		ModuleStandaloneModeInternalClient = CommonClient.CommonModule("StandaloneModeInternalClient");
		Parameters.Modules.Add(ModuleStandaloneModeInternalClient);
	EndIf;
	
	// Checking user authorization.
	Parameters.Modules.Add(New Structure("Module, Number", UsersInternalClient, 2));
	
	// Checking for locks to access the infobase.
	If CommonClient.SubsystemExists("StandardSubsystems.UserSessionsCompletion") Then
		ModuleIBConnectionsClient = CommonClient.CommonModule("IBConnectionsClient");
		Parameters.Modules.Add(ModuleIBConnectionsClient);
	EndIf;
	
	// Updating an infobase.
	Parameters.Modules.Add(New Structure("Module, Number", InfobaseUpdateClient, 4));
	
	// Handling the UpdateAndExit startup key.
	Parameters.Modules.Add(New Structure("Module, Number", InfobaseUpdateClient, 5));
	
	// Change password on exit of necessary.
	Parameters.Modules.Add(New Structure("Module, Number", UsersInternalClient, 3));
	
EndProcedure

// See CommonClientOverridable.OnStart. 
Procedure OnStart(Parameters) Export
	
	// Opening a subordinate DIB node on the initial start.
	If CommonClient.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeClient = CommonClient.CommonModule("DataExchangeClient");
		Parameters.Modules.Add(ModuleDataExchangeClient);
	EndIf;
	
	// Opening application change log.
	If CommonClient.SubsystemExists("StandardSubsystems.IBVersionUpdate") Then
		ModuleInfobaseUpdateClient = CommonClient.CommonModule("InfobaseUpdateClient");
		Parameters.Modules.Add(ModuleInfobaseUpdateClient);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		ModuleSoftwareUpdateClient = CommonClient.CommonModule("ConfigurationUpdateClient");
		Parameters.Modules.Add(ModuleSoftwareUpdateClient);
	EndIf;
	
	// Showing the form tor manage external resources locks, if necessary.
	If CommonClient.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleScheduledJobsClient = CommonClient.CommonModule("ScheduledJobsClient");
		Parameters.Modules.Add(ModuleScheduledJobsClient);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.IBBackup") Then
		ModuleIBBackupClient = CommonClient.CommonModule("IBBackupClient");
		Parameters.Modules.Add(ModuleIBBackupClient);
    EndIf;
    
    If CommonClient.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
        ModuleMonitoringCenterClientInternal = CommonClient.CommonModule("MonitoringCenterClientInternal");
        Parameters.Modules.Add(ModuleMonitoringCenterClientInternal);
    EndIf;
	
	SaaSIntegrationClient.OnStart(Parameters);
	
EndProcedure

// See CommonClientOverridable.AfterStart. 
Procedure AfterStart() Export
	
	StandardSubsystemsClient.AfterStart();
	
	If CommonClient.SubsystemExists("StandardSubsystems.Banks") Then
		ModuleBankManagerClient = CommonClient.CommonModule("BankManagerClient");
		ModuleBankManagerClient.AfterStart();
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRatesClient = CommonClient.CommonModule("CurrencyRateOperationsClient");
		ModuleCurrencyExchangeRatesClient.AfterStart();
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.UserSessionsCompletion") Then
		ModuleIBConnectionsClient = CommonClient.CommonModule("IBConnectionsClient");
		ModuleIBConnectionsClient.AfterStart();
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.InformationOnStart") Then
		ModuleNotificationAtStartupClient = CommonClient.CommonModule("InformationOnStartClient");
		ModuleNotificationAtStartupClient.AfterStart();
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.UserReminders") Then
		ModuleRemindersClient = CommonClient.CommonModule("UserRemindersClient");
		ModuleRemindersClient.AfterStart();
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeClient = CommonClient.CommonModule("DataExchangeClient");
		ModuleDataExchangeClient.AfterStart();
	EndIf;
	
	InfobaseUpdateClient.AfterStart();
	UsersInternalClient.AfterStart();
	
	If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleExternalResourcePermissionsClient = CommonClient.CommonModule("ExternalResourcePermissionSetupClient");
		ModuleExternalResourcePermissionsClient.AfterStart();
	EndIf;
	
EndProcedure

// See CommonClientOverridable.LaunchParametersOnProcess. 
Procedure LaunchParametersOnProcess(StartParameters, Cancel) Export
	
	If CommonClient.SubsystemExists("StandardSubsystems.UserSessionsCompletion") Then
		ModuleIBConnectionsClient = CommonClient.CommonModule("IBConnectionsClient");
		ModuleIBConnectionsClient.LaunchParametersOnProcess(StartParameters, Cancel);
	EndIf;
	
EndProcedure

// See CommonClientOverridable.BeforeExit. 
Procedure BeforeExit(Cancel, Warnings) Export
	
	If CommonClient.SubsystemExists("StandardSubsystems.UserSessionsCompletion") Then
		ModuleIBConnectionsClient = CommonClient.CommonModule("IBConnectionsClient");
		ModuleIBConnectionsClient.BeforeExit(Cancel, Warnings);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		ModuleSoftwareUpdateClient = CommonClient.CommonModule("ConfigurationUpdateClient");
		ModuleSoftwareUpdateClient.BeforeExit(Cancel, Warnings);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternalClient = CommonClient.CommonModule("FilesOperationsInternalClient");
		ModuleStoredFilesInternalClient.BeforeExit(Cancel, Warnings);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.IBBackup") Then
		ModuleIBBackupClient = CommonClient.CommonModule("IBBackupClient");
		ModuleIBBackupClient.BeforeExit(Cancel, Warnings);
	EndIf;
	
	SaaSIntegrationClient.BeforeExit(Cancel, Warnings);
	
EndProcedure

#EndRegion

#Region ReportFunctionality

Procedure SpreadsheetDocumentSelectionHandler(ReportForm, Item, Area, StandardProcessing) Export
	
	If CommonClient.SubsystemExists("StandardSubsystems.DocumentRecordsReport") Then
		ModuleRegisterRecordsReportInternalClient = CommonClient.CommonModule("DocumentRecordsReportInternalClient");
		ModuleRegisterRecordsReportInternalClient.SpreadsheetDocumentSelectionHandler(ReportForm, Item, Area, StandardProcessing);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternalClient = CommonClient.CommonModule("AccountingAuditInternalClient");
		ModuleAccountingAuditInternalClient.SpreadsheetDocumentSelectionHandler(ReportForm, Item, Area, StandardProcessing);
	EndIf;
	
EndProcedure

#EndRegion

#Region IBBackup

// Checks whether a backup can be performed in user mode.
//
// Parameters:
//  Result - Boolean - the return value.
//
Procedure OnCheckIfCanBackUpInUserMode(Result) Export
	
	If CommonClient.SubsystemExists("CloudTechnology.IBBackup") Then
		ModuleIBBackupClient = CommonClient.CommonModule("IBBackupClient");
		ModuleIBBackupClient.OnCheckIfCanBackUpInUserMode(Result);
	EndIf;
	
	If CommonClient.SubsystemExists("CloudTechnology.DataAreaBackup") Then
		ModuleDataAreaBackupClient = CommonClient.CommonModule("DataAreaBackupClient");
		ModuleDataAreaBackupClient.OnCheckIfCanBackUpInUserMode(Result);
	EndIf;
	
EndProcedure

// Called when the user is prompted to back up.
Procedure OnPromptUserForBackup() Export
	
	If CommonClient.SubsystemExists("CloudTechnology.IBBackup") Then
		ModuleIBBackupClient = CommonClient.CommonModule("IBBackupClient");
		ModuleIBBackupClient.OnPromptUserForBackup();
	EndIf;
	
	If CommonClient.SubsystemExists("CloudTechnology.DataAreaBackup") Then
		ModuleDataAreaBackupClient = CommonClient.CommonModule("DataAreaBackupClient");
		ModuleDataAreaBackupClient.OnPromptUserForBackup();
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
