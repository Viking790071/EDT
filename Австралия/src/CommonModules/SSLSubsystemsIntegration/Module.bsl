////////////////////////////////////////////////////////////////////////////////
// Subsystem-to-Subsystem integration.
// Here you can find processors of program events that occur in source subsystems when there are 
// several destination subsystems or the destination subsystem list is not predefined.
//

#Region Internal

#Region Core

// See CommonOverridable.OnAddSessionParametersSettingHandlers. 
Procedure OnAddSessionParameterSettingHandlers(Handlers) Export
	
	InfobaseUpdateInternal.OnAddSessionParameterSettingHandlers(Handlers);
	UsersInternal.OnAddSessionParameterSettingHandlers(Handlers);
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectVersioning.OnAddSessionParameterSettingHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.OnAddSessionParameterSettingHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitorInternal = Common.CommonModule("PerformanceMonitorInternal");
		ModulePerformanceMonitorInternal.OnAddSessionParameterSettingHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnAddSessionParameterSettingHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleScheduledJobsInternal = Common.CommonModule("ScheduledJobsInternal");
		ModuleScheduledJobsInternal.OnAddSessionParameterSettingHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnAddSessionParameterSettingHandlers(Handlers);
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddRefsSearchExceptions. 
Procedure OnAddReferenceSearchExceptions(RefSearchExclusions) Export
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectVersioning.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRates = Common.CommonModule("CurrencyRateOperations");
		ModuleCurrencyExchangeRates.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;
	
	UsersInternal.OnAddReferenceSearchExceptions(RefSearchExclusions);
	SaaSIntegration.OnAddReferenceSearchExceptions(RefSearchExclusions);
	InfobaseUpdateInternal.OnAddReferenceSearchExceptions(RefSearchExclusions);
	StandardSubsystemsServer.OnAddReferenceSearchExceptions(RefSearchExclusions);
	
EndProcedure

// See CommonOverridable.OnAddMetadataObjectsRenaming. 
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	StandardSubsystemsServer.OnAddMetadataObjectsRenaming(Total);
	
	If Common.SubsystemExists("StandardSubsystems.EventLogAnalysis") Then
		ModuleEventLogAnalysisInternal = Common.CommonModule("EventLogAnalysisInternal");
		ModuleEventLogAnalysisInternal.OnAddMetadataObjectsRenaming(Total);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnAddMetadataObjectsRenaming(Total);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactOnlineSupport") Then
		ModuleOnlineSupport = Common.CommonModule("ContactOnlineSupport");
		ModuleOnlineSupport.OnAddMetadataObjectsRenaming(Total);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnAddMetadataObjectsRenaming(Total);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.UserNotes") Then
		ModuleUserNotesInternal = Common.CommonModule("UserNotesInternal");
		ModuleUserNotesInternal.OnAddMetadataObjectsRenaming(Total);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.UserReminders") Then
		ModuleRemindersInternal = Common.CommonModule("UserRemindersInternal");
		ModuleRemindersInternal.OnAddMetadataObjectsRenaming(Total);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ApplicationSettings") Then
		ModuleDataProcessorsControlPanelSSL = Common.CommonModule("DataProcessors.SSLAdministrationPanel");
		ModuleDataProcessorsControlPanelSSL.OnAddMetadataObjectsRenaming(Total);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnAddMetadataObjectsRenaming(Total);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailInternal = Common.CommonModule("EmailOperationsInternal");
		ModuleEmailInternal.OnAddMetadataObjectsRenaming(Total);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnAddMetadataObjectsRenaming(Total);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SubordinationStructure") Then
		ModuleLinkedObjectsInternal = Common.CommonModule("SubordinationStructureInternal");
		ModuleLinkedObjectsInternal.OnAddMetadataObjectsRenaming(Total);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ToDoList") Then
		ModuleToDoListInternal = Common.CommonModule("ToDoListInternal");
		ModuleToDoListInternal.OnAddMetadataObjectsRenaming(Total);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		ModuleDigitalSignatureInternal.OnAddMetadataObjectsRenaming(Total);
	EndIf;
	
EndProcedure

// See InformationRegister.ExtensionsVersionsParameters.FillAllExtensionParameters. 
Procedure OnFillAllExtensionsParameters() Export
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnFillAllExtensionsParameters();
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnFillAllExtensionsParameters();
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnFillAllExtensionsParameters();
	EndIf;
	
EndProcedure

// See InformationRegister.ExtensionsVersionsParameters.ClearAllExtensionParameters. 
Procedure OnClearAllExtemsionParameters() Export
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnClearAllExtemsionParameters();
	EndIf;
	
EndProcedure

// See StandardSubsystemsServer.OnSendDataToMaster. 
Procedure OnSendDataToMaster(DataItem, ItemSend, Recipient) Export
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectVersioning.OnSendDataToMaster(DataItem, ItemSend, Recipient);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AddIns") Then
		ModuleAddInsInternal = Common.CommonModule("AddInsInternal");
		ModuleAddInsInternal.OnSendDataToMaster(DataItem, ItemSend, Recipient);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.AddInsSaaS") Then
		ModuleAddInsSaaSInternal = Common.CommonModule("AddInsSaaSInternal");
		ModuleAddInsSaaSInternal.OnSendDataToMaster(DataItem, ItemSend, Recipient);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.OnSendDataToMaster(DataItem, ItemSend, Recipient);
	EndIf;
	
	InfobaseUpdateInternal.OnSendDataToMaster(DataItem, ItemSend, Recipient);
	UsersInternal.OnSendDataToMaster(DataItem, ItemSend, Recipient);
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnSendDataToMaster(DataItem, ItemSend, Recipient);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnSendDataToMaster(DataItem, ItemSend, Recipient);
	EndIf;
	
	SaaSIntegration.OnSendDataToMaster(DataItem, ItemSend, Recipient);
	
EndProcedure

// See StandardSubsystemsServer.OnSendDataToSlave. 
Procedure OnSendDataToSlave(DataItem, ItemSend, InitialImageCreation, Recipient) Export
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectVersioning.OnSendDataToSlave(DataItem, ItemSend, InitialImageCreation, Recipient);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AddIns") Then
		ModuleAddInsInternal = Common.CommonModule("AddInsInternal");
		ModuleAddInsInternal.OnSendDataToSlave(DataItem, ItemSend, InitialImageCreation, Recipient);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.AddInsSaaS") Then
		ModuleAddInsSaaSInternal = Common.CommonModule("AddInsSaaSInternal");
		ModuleAddInsSaaSInternal.OnSendDataToSlave(DataItem, ItemSend, InitialImageCreation, Recipient);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.OnSendDataToSlave(DataItem, ItemSend, InitialImageCreation, Recipient);
	EndIf;
	
	InfobaseUpdateInternal.OnSendDataToSlave(DataItem, ItemSend, InitialImageCreation, Recipient);
	UsersInternal.OnSendDataToSlave(DataItem, ItemSend, InitialImageCreation, Recipient);
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnSendDataToSlave(DataItem, ItemSend, InitialImageCreation, Recipient);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnSendDataToSlave(DataItem, ItemSend, InitialImageCreation, Recipient);
	EndIf;
	
	SaaSIntegration.OnSendDataToSlave(DataItem, ItemSend, InitialImageCreation, Recipient);
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromMaster. 
Procedure OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender) Export
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectVersioning.OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AddIns") Then
		ModuleAddInsInternal = Common.CommonModule("AddInsInternal");
		ModuleAddInsInternal.OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.AddInsSaaS") Then
		ModuleAddInsSaaSInternal = Common.CommonModule("AddInsSaaSInternal");
		ModuleAddInsSaaSInternal.OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender);
	EndIf;
	
	UsersInternal.OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender);
	
	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailInternal = Common.CommonModule("EmailOperationsInternal");
		ModuleEmailInternal.OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender);
	EndIf;
	
	SaaSIntegration.OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender);
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromSlave. 
Procedure OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender) Export
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectVersioning.OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AddIns") Then
		ModuleAddInsInternal = Common.CommonModule("AddInsInternal");
		ModuleAddInsInternal.OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.AddInsSaaS") Then
		ModuleAddInsSaaSInternal = Common.CommonModule("AddInsSaaSInternal");
		ModuleAddInsSaaSInternal.OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender);
	EndIf;
	
	UsersInternal.OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender);
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailInternal = Common.CommonModule("EmailOperationsInternal");
		ModuleEmailInternal.OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender);
	EndIf;
	
	SaaSIntegration.OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender);
	
EndProcedure

// See StandardSubsystemsServer.AfterGetData. 
Procedure AfterGetData(Sender, Cancel, GetFromMasterNode) Export
	
	UsersInternal.AfterGetData(Sender, Cancel, GetFromMasterNode);
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.AfterGetData(Sender, Cancel, GetFromMasterNode);
	EndIf;
	
EndProcedure

// See SaaSOverridable.OnEnableDataSeparation. 
Procedure OnEnableSeparationByDataAreas() Export
	
	If Common.SubsystemExists("StandardSubsystems.CalendarSchedules") Then
		ModuleCalendarSchedules = Common.CommonModule("CalendarSchedules");
		ModuleCalendarSchedules.OnEnableSeparationByDataAreas();
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnEnableSeparationByDataAreas();
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ModuleJobQueueInternal = Common.CommonModule("JobQueueInternal");
		ModuleJobQueueInternal.OnEnableSeparationByDataAreas();
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		ModuleJobQueueInternalDataSeparation = Common.CommonModule("JobQueueInternalDataSeparation");
		ModuleJobQueueInternalDataSeparation.OnEnableSeparationByDataAreas();
		
		ModuleSaaS = Common.CommonModule("SaaS");
		ModuleSaaS.OnEnableSeparationByDataAreas();
	EndIf;
	
	SaaSIntegration.OnEnableSeparationByDataAreas();
	
EndProcedure

// See CommonOverridable.OnDefineSupportedInterfaceVersions. 
Procedure OnDefineSupportedInterfaceVersions(Val SupportedVersionStructure) Export
	
	SaaSIntegration.OnDefineSupportedInterfaceVersions(SupportedVersionStructure);
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.MessageExchange") Then
		ModuleMessageInterfacesSaaS = Common.CommonModule("MessageInterfacesSaaS");
		ModuleMessageInterfacesSaaS.OnDefineSupportedInterfaceVersions(SupportedVersionStructure);
		
		ModuleMessageExchangeInternal = Common.CommonModule("MessageExchangeInternal");
		ModuleMessageExchangeInternal.OnDefineSupportedInterfaceVersions(SupportedVersionStructure);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnDefineSupportedInterfaceVersions(SupportedVersionStructure);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.DataAreaBackup") Then
		ModuleDataAreaBackup = Common.CommonModule("DataAreaBackup");
		ModuleDataAreaBackup.OnDefineSupportedInterfaceVersions(SupportedVersionStructure);
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddClientParametersOnStart. 
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	SaaSIntegration.OnAddClientParametersOnStart(Parameters);
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnAddClientParametersOnStart(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.InformationOnStart") Then
		ModuleNotificationAtStartup = Common.CommonModule("InformationOnStart");
		ModuleNotificationAtStartup.OnAddClientParametersOnStart(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.UserReminders") Then
		ModuleRemindersInternal = Common.CommonModule("UserRemindersInternal");
		ModuleRemindersInternal.OnAddClientParametersOnStart(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnAddClientParametersOnStart(Parameters);
	EndIf;
	
	InfobaseUpdateInternal.OnAddClientParametersOnStart(Parameters);
	
	If Common.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		ModuleSoftwareUpdate = Common.CommonModule("ConfigurationUpdate");
		ModuleSoftwareUpdate.OnAddClientParametersOnStart(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitorInternal = Common.CommonModule("PerformanceMonitorInternal");
		ModulePerformanceMonitorInternal.OnAddClientParametersOnStart(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		ModuleSaaS.OnAddClientParametersOnStart(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Banks") Then
		ModuleBankManager = Common.CommonModule("BankManager");
		ModuleBankManager.OnAddClientParametersOnStart(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRates = Common.CommonModule("CurrencyRateOperations");
		ModuleCurrencyExchangeRates.OnAddClientParametersOnStart(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnAddClientParametersOnStart(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.IBBackup") Then
		ModuleIBBackupServer = Common.CommonModule("IBBackupServer");
		ModuleIBBackupServer.OnAddClientParametersOnStart(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.UserSessionsCompletion") Then
		ModuleIBConnections = Common.CommonModule("IBConnections");
		ModuleIBConnections.OnAddClientParametersOnStart(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		ModuleMonitoringCenterInternal = Common.CommonModule("MonitoringCenterInternal");
		ModuleMonitoringCenterInternal.OnAddClientParametersOnStart(Parameters);
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddClientParameters. 
Procedure OnAddClientParameters(Parameters) Export
	
	SaaSIntegration.OnAddClientParameters(Parameters);
	
	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
		ModuleAddressClassifierInternal.OnAddClientParameters(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnAddClientParameters(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.UserReminders") Then
		ModuleRemindersInternal = Common.CommonModule("UserRemindersInternal");
		ModuleRemindersInternal.OnAddClientParameters(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnAddClientParameters(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		ModuleSoftwareUpdate = Common.CommonModule("ConfigurationUpdate");
		ModuleSoftwareUpdate.OnAddClientParameters(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SMS") Then
		ModuleSMS = Common.CommonModule("SMS");
		ModuleSMS.OnAddClientParameters(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownloadInternal = Common.CommonModule("GetFilesFromInternetInternal");
		ModuleNetworkDownloadInternal.OnAddClientParameters(Parameters);
	EndIf;
	
	UsersInternal.OnAddClientParameters(Parameters);
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		ModuleSaaS.OnAddClientParameters(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnAddClientParameters(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.IBBackup") Then
		ModuleIBBackupServer = Common.CommonModule("IBBackupServer");
		ModuleIBBackupServer.OnAddClientParameters(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.DataAreaBackup") Then
		ModuleDataAreaBackup = Common.CommonModule("DataAreaBackup");
		ModuleDataAreaBackup.OnAddClientParameters(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.UserSessionsCompletion") Then
		ModuleIBConnections = Common.CommonModule("IBConnections");
		ModuleIBConnections.OnAddClientParameters(Parameters);
	EndIf;
	
	StandardSubsystemsServer.OnAddClientParameters(Parameters);
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnAddClientParameters(Parameters);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		ModuleDigitalSignatureInternal.OnAddClientParameters(Parameters);
	EndIf;
	
EndProcedure

// See InfobaseUpdateOverridable.OnDefineSettings 
Procedure OnDefineObjectsWithInitialFilling(Objects) Export
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnDefineObjectsWithInitialFilling(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManagerInternal = Common.CommonModule("ContactsManagerInternal");
		ModuleContactsManagerInternal.OnDefineObjectsWithInitialFilling(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperationsInternal = Common.CommonModule("EmailOperationsInternal");
		ModuleEmailOperationsInternal.OnDefineObjectsWithInitialFilling(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportMailings") Then
		ModuleReportDistribution = Common.CommonModule("ReportMailing");
		ModuleReportDistribution.OnDefineObjectsWithInitialFilling(Objects);
	EndIf;
	
EndProcedure

#EndRegion

#Region ReportsOptions

// See ReportsOptionsOverridable.CustomizeReportOptions. 
Procedure OnSetUpReportsOptions(Settings) Export
	
	If Common.SubsystemExists("StandardSubsystems.EventLogAnalysis") Then
		ModuleEventLogAnalysisInternal = Common.CommonModule("EventLogAnalysisInternal");
		ModuleEventLogAnalysisInternal.OnSetUpReportsOptions(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Survey") Then
		ModulePolls = Common.CommonModule("Survey");
		ModulePolls.OnSetUpReportsOptions(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnSetUpReportsOptions(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.OnSetUpReportsOptions(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnSetUpReportsOptions(Settings);
	EndIf;

	InfobaseUpdateInternal.OnSetUpReportsOptions(Settings);
	
	If Common.SubsystemExists("StandardSubsystems.DuplicateObjectDetection") Then
		ModuleDuplicateObjectDetection = Common.CommonModule("DuplicateObjectDetection");
		ModuleDuplicateObjectDetection.OnSetUpReportsOptions(Settings);
	EndIf;
	
	UsersInternal.OnSetUpReportsOptions(Settings);
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
		ModuleSafeModeManagerInternal.OnSetUpReportsOptions(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnSetUpReportsOptions(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnSetUpReportsOptions(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DocumentRecordsReport") Then
		ModuleRegisterRecords = Common.CommonModule("Reports.DocumentRegisterRecords");
		ModuleRegisterRecords.OnSetUpReportsOptions(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitorInternal = Common.CommonModule("PerformanceMonitorInternal");
		ModulePerformanceMonitorInternal.OnSetUpReportsOptions(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditResult = Common.CommonModule("Reports.AccountingCheckResults");
		ModuleAccountingAuditResult.OnSetUpReportsOptions(Settings);
	EndIf;
	
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.StatementOfAccount);
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.CustomerStatement);
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.SalesOrdersStatement);

EndProcedure

// See ReportOptionsOverridable.DefineObjectsWithReportCommands. 
Procedure OnDefineObjectsWithReportCommands(Objects) Export
	
	If Common.SubsystemExists("StandardSubsystems.Survey") Then
		ModulePolls = Common.CommonModule("Survey");
		ModulePolls.OnDefineObjectsWithReportCommands(Objects);
	EndIf;
	
EndProcedure

Procedure BeforeAddReportCommands(ReportCommands, FormSettings, StandardProcessing) Export
	
	If Common.SubsystemExists("StandardSubsystems.DocumentRecordsReport") Then
		ModuleRegisterRecords = Common.CommonModule("Reports.DocumentRegisterRecords");
		ModuleRegisterRecords.BeforeAddReportCommands(ReportCommands, FormSettings, StandardProcessing);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditResult = Common.CommonModule("Reports.AccountingCheckResults");
		ModuleAccountingAuditResult.BeforeAddReportCommands(ReportCommands, FormSettings, StandardProcessing);
	EndIf;
	
EndProcedure

#EndRegion

#Region BatchEditObjects

// See BatchObjectModificationOverridable.OnDetermineObjectsWithEditableAttributes. 
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	
	StandardSubsystemsServer.OnDefineObjectsWithEditableAttributes(Objects);
	UsersInternal.OnDefineObjectsWithEditableAttributes(Objects);
	
	If Common.SubsystemExists("StandardSubsystems.Survey") Then
		ModulePolls = Common.CommonModule("Survey");
		ModulePolls.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Banks") Then
		ModuleBankManager = Common.CommonModule("BankManager");
		ModuleBankManager.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRates = Common.CommonModule("CurrencyRateOperations");
		ModuleCurrencyExchangeRates.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AddIns") Then
		ModuleAddInsInternal = Common.CommonModule("AddInsInternal");
		ModuleAddInsInternal.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.AddInsSaaS") Then
		ModuleAddInsSaaSInternal = Common.CommonModule("AddInsSaaSInternal");
		ModuleAddInsSaaSInternal.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.UserNotes") Then
		ModuleUserNotesInternal = Common.CommonModule("UserNotesInternal");
		ModuleUserNotesInternal.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManagerInternal = Common.CommonModule("ContactsManagerInternal");
		ModuleContactsManagerInternal.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistribution = Common.CommonModule("ReportMailing");
		ModuleReportDistribution.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailInternal = Common.CommonModule("EmailOperationsInternal");
		ModuleEmailInternal.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.MessageExchange") Then
		ModuleMessageExchangeInternal = Common.CommonModule("MessageExchangeInternal");
		ModuleMessageExchangeInternal.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		ModuleDigitalSignatureInternal.OnDefineObjectsWithEditableAttributes(Objects);
	EndIf;
	
EndProcedure

#EndRegion

#Region PeriodClosingDates

// See PeriodClosingDatesOverridable.OnFillPeriodClosingDatesSections. 
Procedure OnFillPeriodClosingDatesSections(Sections) Export
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnFillPeriodClosingDatesSections(Sections);
	EndIf;
	
EndProcedure

// See PeriodClosingDatesOverridable.OnFillDataSourcesForPeriodClosingCheck. 
Procedure OnFillDataSourcesForPeriodClosingCheck(DataSources) Export
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnFillDataSourcesForPeriodClosingCheck(DataSources);
	EndIf;
	
EndProcedure

#EndRegion

#Region ImportDataFromFile

// See ImportDataFromFileOverridable.OnDefineCatalogsForDataImport. 
Procedure OnDefineCatalogsForDataImport(CatalogsToImport) Export
	
	StandardSubsystemsServer.OnDefineCatalogsForDataImport(CatalogsToImport);
	UsersInternal.OnDefineCatalogsForDataImport(CatalogsToImport);
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManagerInternal = Common.CommonModule("ContactsManagerInternal");
		ModuleContactsManagerInternal.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRates = Common.CommonModule("CurrencyRateOperations");
		ModuleCurrencyExchangeRates.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;
	

	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Banks") Then
		ModuleBankManager = Common.CommonModule("BankManager");
		ModuleBankManager.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ModuleJobQueueInternal = Common.CommonModule("JobQueueInternal");
		ModuleJobQueueInternal.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		ModuleSaaS.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		ModuleDigitalSignatureInternal.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnDefineCatalogsForDataImport(CatalogsToImport);
	EndIf;
	
EndProcedure

#EndRegion

#Region ObjectAttributesLock

// See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes. 
Procedure OnDefineObjectsWithLockedAttributes(Objects) Export 
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManagerInternal = Common.CommonModule("ContactsManagerInternal");
		ModuleContactsManagerInternal.OnDefineObjectsWithLockedAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnDefineObjectsWithLockedAttributes(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnDefineObjectsWithLockedAttributes(Objects);
	EndIf;
	
EndProcedure

// See PrintManagementOverridable.OnDefineObjectsWithPrintCommands. 
Procedure OnDefineObjectsWithPrintCommands(ObjectsList) Export
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnDefineObjectsWithPrintCommands(ObjectsList);
	EndIf;
	
EndProcedure

#EndRegion


#Region AccountingAudit

// See AccountingAuditOverridable.OnDefineChecks. 
Procedure OnDefineChecks(ChecksGroups, Checks) Export
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnDefineChecks(ChecksGroups, Checks);
	EndIf;
	
EndProcedure

#EndRegion

#Region UserReminders

// See UserRemindersOverridable.OnFillSourceAttributesListWithReminderDates. 
Procedure OnFillSourceAttributesListWithReminderDates(Source, AttributesWithDates) Export
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnFillSourceAttributesListWithReminderDates(Source, AttributesWithDates);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.UserNotes") Then
		ModuleUserNotesInternal = Common.CommonModule("UserNotesInternal");
		ModuleUserNotesInternal.OnFillSourceAttributesListWithReminderDates(Source, AttributesWithDates);
	EndIf;
	
EndProcedure

#EndRegion

#Region DataExchange

// See DataExchangeOverridable.OnSetUpSubordinateDIBNode. 
Procedure OnSetUpSubordinateDIBNode() Export
	
	UsersInternal.OnSetUpSubordinateDIBNode();
	
	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailInternal = Common.CommonModule("EmailOperationsInternal");
		ModuleEmailInternal.OnSetUpSubordinateDIBNode();
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleScheduledJobsInternal = Common.CommonModule("ScheduledJobsInternal");
		ModuleScheduledJobsInternal.OnSetUpSubordinateDIBNode();
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnSetUpSubordinateDIBNode();
	EndIf;
	
EndProcedure

#EndRegion

#Region IBVersionUpdate

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
		ModuleAddressClassifierInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Survey") Then
		ModulePolls = Common.CommonModule("Survey");
		ModulePolls.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Banks") Then
		ModuleCurrencyExchangeRates = Common.CommonModule("BankManager");
		ModuleCurrencyExchangeRates.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRates = Common.CommonModule("CurrencyRateOperations");
		ModuleCurrencyExchangeRates.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectVersioning.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactOnlineSupport") Then
		ModuleOnlineSupport = Common.CommonModule("ContactOnlineSupport");
		ModuleOnlineSupport.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
		ModuleWorkSchedules.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.UserSessionsCompletion") Then
		ModuleIBConnections = Common.CommonModule("IBConnections");
		ModuleIBConnections.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.InformationOnStart") Then
		ModuleNotificationAtStartup = Common.CommonModule("InformationOnStart");
		ModuleNotificationAtStartup.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.CalendarSchedules") Then
		ModuleCalendarSchedules = Common.CommonModule("CalendarSchedules");
		ModuleCalendarSchedules.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManagerInternal = Common.CommonModule("ContactsManagerInternal");
		ModuleContactsManagerInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternal = Common.CommonModule("AccountingAuditInternal");
		ModuleAccountingAuditInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	InfobaseUpdateInternal.OnAddUpdateHandlers(Handlers);
	
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitorInternal = Common.CommonModule("PerformanceMonitorInternal");
		ModulePerformanceMonitorInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FullTextSearch") Then
		ModuleFullTextSearchServer = Common.CommonModule("FullTextSearchServer");
		ModuleFullTextSearchServer.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownloadInternal = Common.CommonModule("GetFilesFromInternetInternal");
		ModuleNetworkDownloadInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	UsersInternal.OnAddUpdateHandlers(Handlers);
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		ModuleSaaS.OnAddUpdateHandlers(Handlers);
		
		ModuleJobQueueInternalDataSeparation = Common.CommonModule("JobQueueInternalDataSeparation");
		ModuleJobQueueInternalDataSeparation.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CurrenciesSaaS") Then
		ModuleCurrencyExchangeRatesInternalSaaS = Common.CommonModule("CurrencyRatesInternalSaaS");
		ModuleCurrencyExchangeRatesInternalSaaS.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.MessageExchange") Then
		ModuleMessageExchangeInternal = Common.CommonModule("MessageExchangeInternal");
		ModuleMessageExchangeInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ModuleJobQueueInternal = Common.CommonModule("JobQueueInternal");
		ModuleJobQueueInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.DataAreaBackup") Then
		ModuleDataAreaBackup = Common.CommonModule("DataAreaBackup");
		ModuleDataAreaBackup.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.AccessManagementSaaS") Then
		ModuleAccessManagementInternalSaaS = Common.CommonModule("AccessManagementInternalSaaS");
		ModuleAccessManagementInternalSaaS.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.FilesManagerSaaS") Then
		ModuleFilesManagerInternalSaaS = Common.CommonModule("FilesManagerInternalSaaS");
		ModuleFilesManagerInternalSaaS.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailInternal = Common.CommonModule("EmailOperationsInternal");
		ModuleEmailInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistribution = Common.CommonModule("ReportMailing");
		ModuleReportDistribution.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleScheduledJobsInternal = Common.CommonModule("ScheduledJobsInternal");
		ModuleScheduledJobsInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.IBBackup") Then
		ModuleIBBackupServer = Common.CommonModule("IBBackupServer");
		ModuleIBBackupServer.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	StandardSubsystemsServer.OnAddUpdateHandlers(Handlers);
	
	If Common.SubsystemExists("StandardSubsystems.MarkedObjectsDeletion") Then
		ModuleMarkedObjectDeletionInternal = Common.CommonModule("MarkedObjectsDeletionInternal");
		ModuleMarkedObjectDeletionInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.TotalsAndAggregatesManagement") Then
		ModuleTotalsAndAggregatesInternal = Common.CommonModule("TotalsAndAggregatesManagementIntenal");
		ModuleTotalsAndAggregatesInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		ModuleMonitoringCenterInternal = Common.CommonModule("MonitoringCenterInternal");
		ModuleMonitoringCenterInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessageTemplatesInternal = Common.CommonModule("MessageTemplatesInternal");
		ModuleMessageTemplatesInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		ModuleDigitalSignatureInternal.OnAddUpdateHandlers(Handlers);
	EndIf;
	
EndProcedure

// See InfobaseUpdateSSL.AfterUpdateInfobase. 
Procedure AfterUpdateInfobase(Val PreviousVersion, Val CurrentVersion,
	Val CompletedHandlers, OutputUpdateDetails, ExclusiveMode) Export
	
	If Common.SubsystemExists("StandardSubsystems.InformationOnStart") Then
		ModuleNotificationAtStartup = Common.CommonModule("InformationOnStart");
		ModuleNotificationAtStartup.AfterUpdateInfobase(PreviousVersion, CurrentVersion,
			CompletedHandlers, OutputUpdateDetails, ExclusiveMode);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.TotalsAndAggregatesManagement") Then
		ModuleTotalsAndAggregatesInternal = Common.CommonModule("TotalsAndAggregatesManagementIntenal");
		ModuleTotalsAndAggregatesInternal.AfterUpdateInfobase(PreviousVersion, CurrentVersion,
			CompletedHandlers, OutputUpdateDetails, ExclusiveMode);
	EndIf;
		
	If Common.SubsystemExists("StandardSubsystems.SaaS.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.AfterUpdateInfobase(PreviousVersion, CurrentVersion,
			CompletedHandlers, OutputUpdateDetails, ExclusiveMode);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.AfterUpdateInfobase(PreviousVersion, CurrentVersion,
			CompletedHandlers, OutputUpdateDetails, ExclusiveMode);
	EndIf;
	
EndProcedure

#EndRegion

#Region Printing

Function OnPrepareTemplateListInOfficeDocumentServerFormat(TemplatesList) Export
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnPrepareTemplateListInOfficeDocumentServerFormat(TemplatesList);
	EndIf;
	
EndFunction

#EndRegion

#Region AttachableCommands

// See AttachableCommandsOverridable.OnDefineAttachableCommandsKinds. 
Procedure OnDefineAttachableCommandsKinds(AttachableCommandsKinds) Export
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.OnDefineAttachableCommandsKinds(AttachableCommandsKinds);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsFilling") Then
		ModuleObjectFilling = Common.CommonModule("ObjectsFilling");
		ModuleObjectFilling.OnDefineAttachableCommandsKinds(AttachableCommandsKinds);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnDefineAttachableCommandsKinds(AttachableCommandsKinds);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnDefineAttachableCommandsKinds(AttachableCommandsKinds);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ItemOrderSetup") Then
		ModuleItemOrdering = Common.CommonModule("ItemOrderSetup");
		ModuleItemOrdering.OnDefineAttachableCommandsKinds(AttachableCommandsKinds);
	EndIf;
	
EndProcedure

// See AttachableCommandsOverridable.OnDefineAttachableObjectsSettingsComposition. 
Procedure OnDefineAttachableObjectsSettingsComposition(InterfaceSettings) Export
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.OnDefineAttachableObjectsSettingsComposition(InterfaceSettings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsFilling") Then
		ModuleObjectFilling = Common.CommonModule("ObjectsFilling");
		ModuleObjectFilling.OnDefineAttachableObjectsSettingsComposition(InterfaceSettings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnDefineAttachableObjectsSettingsComposition(InterfaceSettings);
	EndIf;
	
EndProcedure

// See AttachableCommandsOverridable.OnDefineCommandsAttachedToObject. 
Procedure OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands) Export
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsFilling") Then
		ModuleObjectFilling = Common.CommonModule("ObjectsFilling");
		ModuleObjectFilling.OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ItemOrderSetup") Then
		ModuleItemOrdering = Common.CommonModule("ItemOrderSetup");
		ModuleItemOrdering.OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands);
	EndIf;
	
EndProcedure

// See GenerationOverridable.OnDefineObjectsWithGenerateObjectCommands. 
Procedure OnDefineObjectsWithCreationBasedOnCommands(Objects) Export
	
	UsersInternal.OnDefineObjectsWithCreationBasedOnCommands(Objects);
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnDefineObjectsWithCreationBasedOnCommands(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnDefineObjectsWithCreationBasedOnCommands(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnDefineObjectsWithCreationBasedOnCommands(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnDefineObjectsWithCreationBasedOnCommands(Objects);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessagesTemplates = Common.CommonModule("MessageTemplates");
		ModuleMessagesTemplates.OnDefineObjectsWithCreationBasedOnCommands(Objects);
	EndIf;
	
EndProcedure

// See GenerationOverridable.BeforeAddGenerationCommands. 
Procedure BeforeAddGenerationCommands(GenerationCommands, Parameters, StandardProcessing) Export
	
	
	
EndProcedure

#EndRegion

#Region Users

// See UsersOverridable.OnDefineSettings. 
Procedure OnDefineSettings(Settings) Export
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnDefineSettings(Settings);
	EndIf;
	
EndProcedure

// See UsersOverridable.OnDefineRolesAssignment. 
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
		ModuleAddressClassifierInternal.OnDefineRoleAssignment(RolesAssignment);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Survey") Then
		ModulePolls = Common.CommonModule("Survey");
		ModulePolls.OnDefineRoleAssignment(RolesAssignment);
	EndIf;
	
	StandardSubsystemsServer.OnDefineRoleAssignment(RolesAssignment);
	
	If Common.SubsystemExists("StandardSubsystems.Banks") Then
		ModuleBankManager = Common.CommonModule("BankManager");
		ModuleBankManager.OnDefineRoleAssignment(RolesAssignment);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRates = Common.CommonModule("CurrencyRateOperations");
		ModuleCurrencyExchangeRates.OnDefineRoleAssignment(RolesAssignment);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnDefineRoleAssignment(RolesAssignment);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
		ModuleWorkSchedules.OnDefineRoleAssignment(RolesAssignment);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnDefineRoleAssignment(RolesAssignment);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.CalendarSchedules") Then
		ModuleCalendarSchedules = Common.CommonModule("CalendarSchedules");
		ModuleCalendarSchedules.OnDefineRoleAssignment(RolesAssignment);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitorInternal = Common.CommonModule("PerformanceMonitorInternal");
		ModulePerformanceMonitorInternal.OnDefineRoleAssignment(RolesAssignment);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.OnDefineRoleAssignment(RolesAssignment);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ToDoList") Then
		ModuleToDoListInternal = Common.CommonModule("ToDoListInternal");
		ModuleToDoListInternal.OnDefineRoleAssignment(RolesAssignment);
	EndIf;
	
EndProcedure

// See UsersOverridable.OnDefineActionsInForm. 
Procedure OnDefineActionsInForm(Ref, FormActions) Export
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnDefineActionsInForm(Ref, FormActions);
	EndIf;
	
EndProcedure

// Overrides comment text during the authorization of the infobase user that is created in Designer 
// and has administrative rights.
//  The procedure is called from Users.AuthenticateCurrentUser().
//  The comment is written to the event log.
// 
// Parameters:
//  Comment  - String - the initial value is set.
//
Procedure AfterWriteAdministratorOnAuthorization(Comment) Export
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.AfterWriteAdministratorOnAuthorization(Comment);
	EndIf;
	
EndProcedure

// Redefines the actions that are required after assigning an infobase user to a user or external 
// user (when filling the IBUserID attribute becomes filled).
// 
//
// For example, these actions can include the update of roles.
// 
// Parameters:
//  Ref - CatalogRef.Users, CatalogRef.ExternalUsers - the user.
//
Procedure AfterSetIBUser(Ref, ServiceUserPassword) Export
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.AfterSetIBUser(Ref, ServiceUserPassword);
	EndIf;
	
EndProcedure

// Allows you to override the question text that users see before saving the first administrator.
//  The procedure is called from the BeforeWrite handler in the user form.
//  The procedure is called if RoleEditProhibition() is set and
// the number of infobase users is zero.
// 
// Parameters:
//  QuestionText - String - the text of question to be overridden.
//
Procedure OnDefineQuestionTextBeforeWriteFirstAdministrator(QuestionText) Export
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnDefineQuestionTextBeforeWriteFirstAdministrator(QuestionText);
	EndIf;
	
EndProcedure

// Redefines actions executed when creating the administrator in the Users subsystem.
// 
// Parameters:
//  Administrator - CatalogRef.Users (changing the object is prohibited).
//  Clarification     - String - clarifies the conditions of administrator creation.
//
Procedure OnCreateAdministrator(Administrator, Clarification) Export
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnCreateAdministrator(Administrator, Clarification);
	EndIf;
	
EndProcedure

// Redefines the actions that are required after adding or modifying a user, user group, external 
// user, or external user group.
//
// Parameters:
//  Ref     - CatalogRef.Users,
//               CatalogRef.UserGroups,
//               CatalogRef.ExternalUsers,
//               CatalogRef.ExternalUserGroups - the modified object.
//
//  IsNew   - Boolean - the object is added if True, modified otherwise.
//
Procedure AfterAddChangeUserOrGroup(Ref, IsNew) Export
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.AfterAddChangeUserOrGroup(Ref, IsNew);
	EndIf;
	
EndProcedure

// Redefines the actions that are required after completing the update of relations in 
// UserGroupContents register.
//
// Parameters:
//  ItemsToChange - Arrays of type values:
//                       - CatalogRef.Users.
//                       - CatalogRef.ExternalUsers.
//                       Users that are included in group content update.
//
//  ModifiedGroups   - Array of type values:
//                       - CatalogRef.UserGroups.
//                       - CatalogRef.ExternalUserGroups.
//                       Groups whose content is changed.
//
Procedure AfterUserGroupsUpdate(ItemsToChange, ModifiedGroups) Export
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.AfterUserGroupsUpdate(ItemsToChange, ModifiedGroups);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.AfterUserGroupsUpdate(ItemsToChange, ModifiedGroups);
	EndIf;
	
EndProcedure

// Redefines the actions that are required after changing an external user authorization object.
// 
// Parameters:
//  ExternalUser     - CatalogRef.ExternalUsers - the external user.
//  PreviousAuthorizationObject - NULL - used when adding an external user.
//                          - DefinedType.ExternalUser - the authorization object type.
//  NewAuthorizationObject  - DefinedType.ExternalUser - the authorization object type.
//
Procedure AfterChangeExternalUserAuthorizationObject(ExternalUser,
                                                               PreviousAuthorizationObject,
                                                               NewAuthorizationObject) Export
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.AfterChangeExternalUserAuthorizationObject(
			ExternalUser, PreviousAuthorizationObject, NewAuthorizationObject);
	EndIf;
	
EndProcedure

// Gets options of the passed report and their presentations.
//
// Parameters:
//  ReportMetadata                - Metadata report - the report used to get report options.
//  InfobaseUser - String - the name of the infobase user.
//  ReportsOptionsInfo      - ValueTable - a table that stores report option data.
//       * ObjectKey          - String - the report key in format "Report.ReportDescription".
//       * OptionKey         - String - the report option key.
//       * Presentation        - String - the report option presentation.
//       * StandardProcessing - Boolean - if True, a report option is saved to the standard storage.
//  StandardProcessing           - Boolean - if True, a report option is saved to the standard storage.
//
Procedure OnReceiveUserReportsOptions(ReportMetadata, InfobaseUser, ReportsOptionsInfo, StandardProcessing) Export
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.UserReportOptions(ReportMetadata, InfobaseUser,
			ReportsOptionsInfo, StandardProcessing);
	EndIf;
	
EndProcedure

// Deletes the passed report option from the report option storage.
//
// Parameters:
//  ReportsOptionsInfo      - ValueTable - a table that stores report option data.
//       * ObjectKey          - String - the report key in format "Report.ReportDescription".
//       * OptionKey         - String - the report option key.
//       * Presentation        - String - the report option presentation.
//       * StandardProcessing - Boolean - if True, a report option is saved to the standard storage.
//  InfobaseUser - Строка - the name of the infobase user whose report option is to be cleared.
//  StandardProcessing           - Boolean - if True, a report option is saved to the standard storage.
//
Procedure OnDeleteUserReportOptions(ReportOptionInfo, InfobaseUser, StandardProcessing) Export
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.DeleteUserReportOption(ReportOptionInfo,
			InfobaseUser, StandardProcessing);
	EndIf;
	
EndProcedure

// See UsersOverridable.OnGetOtherSettings. 
Procedure OnGetOtherSettings(UserInfo, Settings) Export
	
	// Adding additional report and data processor settings.
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnGetOtherSettings(UserInfo, Settings);
	EndIf;
	
EndProcedure

// See UsersOverridable.OnSaveOtherSetings. 
Procedure OnSaveOtherSetings(UserInfo, Settings) Export
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnSaveOtherSetings(UserInfo, Settings);
	EndIf;
	
EndProcedure

// See UsersOverridable.OnDeleteOtherSettings. 
Procedure OnDeleteOtherSettings(UserInfo, Settings) Export
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnDeleteOtherSettings(UserInfo, Settings);
	EndIf;
	
EndProcedure

// Generates a request for changing SaaS user email address.
//
// Parameters:
//  NewEmailAddress                - String - the new email address of the user.
//  User              - CatalogRef.Users - the user whose email address is to be changed.
//                                                              
//  ServiceUserPassword - String - user password for service manager.
//
Procedure OnCreateRequestToChangeEmail(Val NewEmailAddress, Val User, Val ServiceUserPassword) Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.UsersSaaS") Then
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ModuleUsersInternalSaaS.CreateEmailAddressChangeRequest(NewEmailAddress, User, ServiceUserPassword);
	EndIf;
	
EndProcedure

// Redefines the actions needed after changing a user, group of users, external user, or group of 
// external users in a list form or item form.
//
Procedure AfterChangeUserOrGroupInForm() Export
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.AfterChangeUserOrGroupInForm();
	EndIf;
	
EndProcedure

#EndRegion

#Region SecurityProfiles

// See SafeModeManagerOverridable.OnEnableSecurityProfiles. 
Procedure OnEnableSecurityProfiles() Export
	
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownloadInternal = Common.CommonModule("GetFilesFromInternetInternal");
		ModuleNetworkDownloadInternal.OnEnableSecurityProfiles();
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.IBBackup") Then
		ModuleIBBackupServer = Common.CommonModule("IBBackupServer");
		ModuleIBBackupServer.OnEnableSecurityProfiles();
	EndIf;
	
EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources. 
Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
		ModuleAddressClassifierInternal.OnFillPermissionsToAccessExternalResources(PermissionRequests);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessorsSafeModeInternal = Common.CommonModule("AdditionalReportsAndDataProcessorsSafeModeInternal");
		ModuleAdditionalReportsAndDataProcessorsSafeModeInternal.OnFillPermissionsToAccessExternalResources(PermissionRequests);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnFillPermissionsToAccessExternalResources(PermissionRequests);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SMS") Then
		ModuleSMS = Common.CommonModule("SMS");
		ModuleSMS.OnFillPermissionsToAccessExternalResources(PermissionRequests);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitorInternal = Common.CommonModule("PerformanceMonitorInternal");
		ModulePerformanceMonitorInternal.OnFillPermissionsToAccessExternalResources(PermissionRequests);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Banks") Then
		ModuleBankManager = Common.CommonModule("BankManager");
		ModuleBankManager.OnFillPermissionsToAccessExternalResources(PermissionRequests);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRates = Common.CommonModule("CurrencyRateOperations");
		ModuleCurrencyExchangeRates.OnFillPermissionsToAccessExternalResources(PermissionRequests);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailInternal = Common.CommonModule("EmailOperationsInternal");
		ModuleEmailInternal.OnFillPermissionsToAccessExternalResources(PermissionRequests);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnFillPermissionsToAccessExternalResources(PermissionRequests);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistribution = Common.CommonModule("ReportMailing");
		ModuleReportDistribution.OnFillPermissionsToAccessExternalResources(PermissionRequests);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectPresentationDeclension") Then
		ModuleObjectPresentationDeclension = Common.CommonModule("ObjectPresentationDeclension");
		ModuleObjectPresentationDeclension.OnFillPermissionsToAccessExternalResources(PermissionRequests);
	EndIf;
	
	StandardSubsystemsServer.OnFillPermissionsToAccessExternalResources(PermissionRequests);
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.OnFillPermissionsToAccessExternalResources(PermissionRequests);
	EndIf;
	
EndProcedure

// The procedure is called when external module managers are registered.
//
// Parameters:
//  Managers - Array - references to modules.
//
Procedure OnRegisterExternalModulesManagers(Managers) Export
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessorsSafeModeInternal = Common.CommonModule("AdditionalReportsAndDataProcessorsSafeModeInternal");
		ModuleAdditionalReportsAndDataProcessorsSafeModeInternal.OnRegisterExternalModulesManagers(Managers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnRegisterExternalModulesManagers(Managers);
	EndIf;
	
EndProcedure

#EndRegion

#Region SaaS_CoreSaaS

// See SaaSOverridable.OnFillIBParametersTable. 
Procedure OnFillIIBParametersTable(Val ParametersTable) Export
	
	SaaSIntegration.OnFillIIBParametersTable(ParametersTable);
	
	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleScheduledJobsInternal = Common.CommonModule("ScheduledJobsInternal");
		ModuleScheduledJobsInternal.OnFillIIBParametersTable(ParametersTable);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.DataAreaBackup") Then
		ModuleDataAreaBackup = Common.CommonModule("DataAreaBackup");
		ModuleDataAreaBackup.OnFillIIBParametersTable(ParametersTable);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.UserSessionsCompletion") Then
		ModuleIBConnections = Common.CommonModule("IBConnections");
		ModuleIBConnections.OnFillIIBParametersTable(ParametersTable);
	EndIf;
	
EndProcedure

#EndRegion

#Region SaaS_MessageExchange

// See MessageExchangeOverridable.GetMessageChannelHandlers. 
Procedure MessageChannelHandlersOnDefine(Handlers) Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.MessageExchange") Then
		ModuleMessageInterfacesSaaS = Common.CommonModule("MessageInterfacesSaaS");
		ModuleMessageInterfacesSaaS.MessageChannelHandlersOnDefine(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.SuppliedData") Then
		ModuleSuppliedData = Common.CommonModule("SuppliedData");
		ModuleSuppliedData.MessageChannelHandlersOnDefine(Handlers);
	EndIf;
	
	SaaSIntegration.MessageChannelHandlersOnDefine(Handlers);
	
EndProcedure

// See MessageInterfacesSaaSOverridable.FillIncomingMessageHandlers. 
Procedure RecordingIncomingMessageInterfaces(HandlerArray) Export
	
	SaaSIntegration.RecordingIncomingMessageInterfaces(HandlerArray);
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.DataAreaBackup") Then
		ModuleDataAreaBackup = Common.CommonModule("DataAreaBackup");
		ModuleDataAreaBackup.RecordingIncomingMessageInterfaces(HandlerArray);
	EndIf;
	
EndProcedure

// See MessageInterfacesSaaSOverridable.FillOutgoingMessageHandlers. 
Procedure RecordingOutgoingMessageInterfaces(HandlerArray) Export
	
	SaaSIntegration.RecordingOutgoingMessageInterfaces(HandlerArray);
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.DataAreaBackup") Then
		ModuleDataAreaBackup = Common.CommonModule("DataAreaBackup");
		ModuleDataAreaBackup.RecordingOutgoingMessageInterfaces(HandlerArray);
	EndIf;
	
EndProcedure

#EndRegion

#Region SaaS_JobQueue

// See JobQueueOverridable.OnReceiveTemplateList. 
Procedure OnGetTemplateList(JobTemplates) Export
	
	SaaSIntegration.OnGetTemplateList(JobTemplates);
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnGetTemplateList(JobTemplates);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnGetTemplateList(JobTemplates);
		ModuleEmailManager = Common.CommonModule("EmailManagement");
		ModuleEmailManager.OnGetTemplateList(JobTemplates);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnGetTemplateList(JobTemplates);
	EndIf;
	
	InfobaseUpdateInternal.OnGetTemplateList(JobTemplates);
	
	UsersInternal.OnGetTemplateList(JobTemplates);
	
	StandardSubsystemsServer.OnGetTemplateList(JobTemplates);
	
	If Common.SubsystemExists("StandardSubsystems.MarkedObjectsDeletion") Then
		ModuleMarkedObjectDeletionInternal = Common.CommonModule("MarkedObjectsDeletionInternal");
		ModuleMarkedObjectDeletionInternal.OnGetTemplateList(JobTemplates);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternalSaaS = Common.CommonModule("AccessManagementInternalSaaS");
		ModuleAccessManagementInternalSaaS.OnGetTemplateList(JobTemplates);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.TotalsAndAggregatesManagement") Then
		ModuleTotalsAndAggregatesInternal = Common.CommonModule("TotalsAndAggregatesManagementIntenal");
		ModuleTotalsAndAggregatesInternal.OnGetTemplateList(JobTemplates);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.FilesManagerSaaS") Then
		ModuleFilesManagerInternalSaaS = Common.CommonModule("FilesManagerInternalSaaS");
		ModuleFilesManagerInternalSaaS.OnGetTemplateList(JobTemplates);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternal = Common.CommonModule("AccountingAuditInternal");
		ModuleAccountingAuditInternal.OnGetTemplateList(JobTemplates);
	EndIf;
	
EndProcedure

// See JobQueueOverridable.OnDefineHandlerAliases. 
Procedure OnDefineHandlerAliases(NameAndAliasMap) Export
	
	SaaSIntegration.OnDefineHandlerAliases(NameAndAliasMap);
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnDefineHandlerAliases(NameAndAliasMap);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectVersioning.OnDefineHandlerAliases(NameAndAliasMap);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CurrenciesSaaS") Then
		ModuleCurrencyExchangeRatesInternalSaaS = Common.CommonModule("CurrencyRatesInternalSaaS");
		ModuleCurrencyExchangeRatesInternalSaaS.OnDefineHandlerAliases(NameAndAliasMap);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CalendarSchedulesSaaS") Then
		ModuleCalendarSchedulesInternalSaaS = Common.CommonModule("CalendarSchedulesInternalSaaS");
		ModuleCalendarSchedulesInternalSaaS.OnDefineHandlerAliases(NameAndAliasMap);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.OnDefineHandlerAliases(NameAndAliasMap);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.SuppliedData") Then
		ModuleUpdateSuppliedData = Common.CommonModule("SuppliedData");
		ModuleUpdateSuppliedData.OnDefineHandlerAliases(NameAndAliasMap);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		ModuleSaaS.OnDefineHandlerAliases(NameAndAliasMap);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.DataAreaBackup") Then
		ModuleDataAreaBackup = Common.CommonModule("DataAreaBackup");
		ModuleDataAreaBackup.OnDefineHandlerAliases(NameAndAliasMap);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.FilesManagerSaaS") Then
		ModuleFilesManagerInternalSaaS = Common.CommonModule("FilesManagerInternalSaaS");
		ModuleFilesManagerInternalSaaS.OnDefineHandlerAliases(NameAndAliasMap);
	EndIf;
	
EndProcedure

// See JobQueueOverridable.OnDefineErrorHandlers. 
Procedure OnDefineErrorHandlers(ErrorHandlers) Export
	
	SaaSIntegration.OnDefineErrorHandlers(ErrorHandlers);
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.DataAreaBackup") Then
		ModuleDataAreaBackup = Common.CommonModule("DataAreaBackup");
		ModuleDataAreaBackup.OnDefineErrorHandlers(ErrorHandlers);
	EndIf;
	
EndProcedure

// See JobQueueOverridable.OnDetermineScheduledJobsUsage. 
Procedure OnDetermineScheduledJobsUsage(UsageTable) Export
	
	SaaSIntegration.OnDetermineScheduledJobsUsage(UsageTable);
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		ModuleSaaS.OnDetermineScheduledJobsUsage(UsageTable);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.OnDetermineScheduledJobsUsage(UsageTable);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.FilesManagerSaaS") Then
		ModuleFilesManagerInternalSaaS = Common.CommonModule("FilesManagerInternalSaaS");
		ModuleFilesManagerInternalSaaS.OnDetermineScheduledJobsUsage(UsageTable);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleScheduledJobsInternal = Common.CommonModule("ScheduledJobsInternal");
		ModuleScheduledJobsInternal.OnDetermineScheduledJobsUsage(UsageTable);
	EndIf;
	
EndProcedure

#EndRegion

#Region SaaS_SuppliedData

// See SuppliedDataOverridable.GetSuppliedDataHandlers. 
Procedure OnDefineSuppliedDataHandlers(Handlers) Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.AddressClassifierSaaS") Then
		ModuleAddressClassifierSaaSInternal = Common.CommonModule("AddressClassifierSaaSInternal");
		ModuleAddressClassifierSaaSInternal.OnDefineSuppliedDataHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.BanksSaaS") Then
		ModuleBanksInternalSaaS = Common.CommonModule("BanksInternalSaaS");
		ModuleBanksInternalSaaS.OnDefineSuppliedDataHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CurrenciesSaaS") Then
		ModuleCurrencyExchangeRatesInternalSaaS = Common.CommonModule("CurrencyRatesInternalSaaS");
		ModuleCurrencyExchangeRatesInternalSaaS.OnDefineSuppliedDataHandlers(Handlers);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		ModuleSaaS.OnDefineSuppliedDataHandlers(Handlers);
	EndIf;
	
	SaaSIntegration.OnDefineSuppliedDataHandlers(Handlers);
	
EndProcedure

#EndRegion

#Region FilesOperations

// See FilesOperationsInternal.OnDetermineFilesSynchronizationExceptionObjects. 
Procedure OnDefineFilesSynchronizationExceptionObjects(Objects) Export
	
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnDefineFileSynchronizationExceptionObjects(Objects);
	EndIf;
	
EndProcedure

#EndRegion

#Region ScheduledJobs

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings. 
Procedure OnDefineScheduledJobSettings(Settings) Export
	
	If Common.SubsystemExists("StandardSubsystems.Banks") Then
		ModuleBankManager = Common.CommonModule("BankManager");
		ModuleBankManager.OnDefineScheduledJobSettings(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnDefineScheduledJobSettings(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRates = Common.CommonModule("CurrencyRateOperations");
		ModuleCurrencyExchangeRates.OnDefineScheduledJobSettings(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectVersioning.OnDefineScheduledJobSettings(Settings);
	EndIf;
		
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnDefineScheduledJobSettings(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnDefineScheduledJobSettings(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnDefineScheduledJobSettings(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitorInternal = Common.CommonModule("PerformanceMonitorInternal");
		ModulePerformanceMonitorInternal.OnDefineScheduledJobSettings(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FullTextSearch") Then
		ModuleFullTextSearchServer = Common.CommonModule("FullTextSearchServer");
		ModuleFullTextSearchServer.OnDefineScheduledJobSettings(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnDefineScheduledJobSettings(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistribution = Common.CommonModule("ReportMailing");
		ModuleReportDistribution.OnDefineScheduledJobSettings(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnDefineScheduledJobSettings(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		ModuleMonitoringCenterInternal = Common.CommonModule("MonitoringCenterInternal");
		ModuleMonitoringCenterInternal.OnDefineScheduledJobSettings(Settings);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MarkedObjectsDeletion") Then
		ModuleMarkedObjectDeletionInternal = Common.CommonModule("MarkedObjectsDeletionInternal");
		ModuleMarkedObjectDeletionInternal.OnDefineScheduledJobSettings(Settings);
	EndIf;
	
	SaaSIntegration.OnDefineScheduledJobSettings(Settings);
	
EndProcedure

#EndRegion

#Region ToDoList

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	
	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
		ModuleAddressClassifierInternal.OnFillToDoList(ToDoList);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnFillToDoList(ToDoList);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectVersioning.OnFillToDoList(ToDoList);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnFillToDoList(ToDoList);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnFillToDoList(ToDoList);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.UserNotes") Then
		ModuleUserNotesInternal = Common.CommonModule("UserNotesInternal");
		ModuleUserNotesInternal.OnFillToDoList(ToDoList);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnFillToDoList(ToDoList);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnFillToDoList(ToDoList);
	EndIf;
	
	InfobaseUpdateInternal.OnFillToDoList(ToDoList);
	
	If Common.SubsystemExists("StandardSubsystems.FullTextSearch") Then
		ModuleFullTextSearchServer = Common.CommonModule("FullTextSearchServer");
		ModuleFullTextSearchServer.OnFillToDoList(ToDoList);
	EndIf;
	
	UsersInternal.OnFillToDoList(ToDoList);
	
	If Common.SubsystemExists("StandardSubsystems.Banks") Then
		ModuleBankManager = Common.CommonModule("BankManager");
		ModuleBankManager.OnFillToDoList(ToDoList);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRates = Common.CommonModule("CurrencyRateOperations");
		ModuleCurrencyExchangeRates.OnFillToDoList(ToDoList);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnFillToDoList(ToDoList);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistribution = Common.CommonModule("ReportMailing");
		ModuleReportDistribution.OnFillToDoList(ToDoList);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.IBBackup") Then
		ModuleIBBackupServer = Common.CommonModule("IBBackupServer");
		ModuleIBBackupServer.OnFillToDoList(ToDoList);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.UserSessionsCompletion") Then
		ModuleIBConnections = Common.CommonModule("IBConnections");
		ModuleIBConnections.OnFillToDoList(ToDoList);
	EndIf;
	
	StandardSubsystemsServer.OnFillToDoList(ToDoList);
	
	If Common.SubsystemExists("StandardSubsystems.TotalsAndAggregatesManagement") Then
		ModuleTotalsAndAggregatesInternal = Common.CommonModule("TotalsAndAggregatesManagementIntenal");
		ModuleTotalsAndAggregatesInternal.OnFillToDoList(ToDoList);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.OnFillToDoList(ToDoList);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleCatalogsAccessGroupProfiles = Common.CommonModule("Catalogs.AccessGroupProfiles");
		ModuleCatalogsAccessGroupProfiles.OnFillToDoList(ToDoList);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternal = Common.CommonModule("AccountingAuditInternal");
		ModuleAccountingAuditInternal.OnFillToDoList(ToDoList);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		ModuleMonitoringCenterInternal = Common.CommonModule("MonitoringCenterInternal");
		ModuleMonitoringCenterInternal.OnFillToDoList(ToDoList);
	EndIf;

	
EndProcedure

#EndRegion

#Region AccessManagement

// See AccessManagementOverridable.OnFillAccessKinds. 
Procedure OnFillAccessKinds(AccessKinds) Export
	
	// The first call must be made to the Users subsystems.
	UsersInternal.OnFillAccessKinds(AccessKinds);
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnFillAccessKinds(AccessKinds);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnFillAccessKinds(AccessKinds);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailInternal = Common.CommonModule("EmailOperationsInternal");
		ModuleEmailInternal.OnFillAccessKinds(AccessKinds);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnFillAccessKinds(AccessKinds);
	EndIf;
	
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnFillListsWithAccessRestriction(Lists);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnFillListsWithAccessRestriction(Lists);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnFillListsWithAccessRestriction(Lists);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnFillListsWithAccessRestriction(Lists);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.UserNotes") Then
		ModuleUserNotesInternal = Common.CommonModule("UserNotesInternal");
		ModuleUserNotesInternal.OnFillListsWithAccessRestriction(Lists);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternal = Common.CommonModule("AccountingAuditInternal");
		ModuleAccountingAuditInternal.OnFillListsWithAccessRestriction(Lists);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.UserReminders") Then
		ModuleRemindersInternal = Common.CommonModule("UserRemindersInternal");
		ModuleRemindersInternal.OnFillListsWithAccessRestriction(Lists);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Users") Then
		ModuleUsersInternal = Common.CommonModule("UsersInternal");
		ModuleUsersInternal.OnFillListsWithAccessRestriction(Lists);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailInternal = Common.CommonModule("EmailOperationsInternal");
		ModuleEmailInternal.OnFillListsWithAccessRestriction(Lists);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnFillListsWithAccessRestriction(Lists);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistribution = Common.CommonModule("ReportMailing");
		ModuleReportDistribution.OnFillListsWithAccessRestriction(Lists);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnFillListsWithAccessRestriction(Lists);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnFillListsWithAccessRestriction(Lists);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessageTemplatesInternal = Common.CommonModule("MessageTemplatesInternal");
		ModuleMessageTemplatesInternal.OnFillListsWithAccessRestriction(Lists);
	EndIf;
	
EndProcedure

// See AccessManagementOverridable.OnFillSuppliedAccessGroupsProfiles. 
Procedure OnFillSuppliedAccessGroupProfiles(ProfilesDetails, UpdateParameters) Export
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.OnFillSuppliedAccessGroupProfiles(ProfilesDetails, UpdateParameters);
	EndIf;
	
EndProcedure

// See AccessManagementOverridable.OnFillAccessRightsDependencies. 
Procedure OnFillAccessRightsDependencies(RightsDependencies) Export
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnFillAccessRightsDependencies(RightsDependencies);
	EndIf;

EndProcedure

// See AccessManagementOverridable.OnFillAvailableRightsForObjectsRightsSettings. 
Procedure OnFillAvailableRightsForObjectsRightsSettings(AvailableRights) Export
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnFillAvailableRightsForObjectsRightsSettings(AvailableRights);
	EndIf;
	
EndProcedure

// See AccessManagementOverridable.OnFillAccessKindUsage. 
Procedure OnFillAccessKindUsage(AccessKind, Usage) Export
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnFillAccessKindUsage(AccessKind, Usage);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnFillAccessKindUsage(AccessKind, Usage);
	EndIf;
	
EndProcedure

// See AccessManagementOverridable.OnFillMetadataObjectsAccessRestrictionsKinds. 
Procedure OnFillMetadataObjectsAccessRestrictionKinds(Details) Export
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnFillMetadataObjectsAccessRestrictionKinds(Details);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnFillMetadataObjectsAccessRestrictionKinds(Details);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnFillMetadataObjectsAccessRestrictionKinds(Details);
	EndIf;
	
	UsersInternal.OnFillMetadataObjectsAccessRestrictionKinds(Details);
	
	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailInternal = Common.CommonModule("EmailOperationsInternal");
		ModuleEmailInternal.OnFillMetadataObjectsAccessRestrictionKinds(Details);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnFillMetadataObjectsAccessRestrictionKinds(Details);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnFillMetadataObjectsAccessRestrictionKinds(Details);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessageTemplatesInternal = Common.CommonModule("MessageTemplatesInternal");
		ModuleMessageTemplatesInternal.OnFillMetadataObjectsAccessRestrictionKinds(Details);
	EndIf;

	
EndProcedure

// Returns a temporary table manager that contains a temporary table of users included in some 
// additional user groups, such as task performer group users that correspond to addressing keys 
// (PerformerRole + MainAddressingObject + AdditionalAddressingObject).
// 
//
//  If additional user group content changed,
// to apply the changes to the subsystem internal data, call the UpdatePerformerGroupUsers procedure 
// in the AccessManagement module.
//
// Parameters:
//  TempTablesManager - a temporary table manager. The method puts the following table to the manager:
//                            PerformersGroupTable with the following fields:
//                              PerformersGroup. For example:
//                                                   CatalogRef.TaskPerformerGroups.
//                              User - CatalogRef.Users,
//                                                   CatalogRef.ExternalUsers.
//
//  ParameterContent - the parameter is not specified, return all the data.
//                            If string value is
//                              set to "PerformerGroups", returns only the contents of the specified 
//                               performer groups.
//                              If set to "Performers", only returns the contents of performer 
//                               groups that include the specified performers.
//                               
//
//  ParameterValue is Undefined, if ParameterContent = Undefined,
//                          - For example, ParameterContent.TaskPerformerGroups if ParameterContent 
//                            = "PerformerGroups".
//                          - CatalogRef.Users,
//                            CatalogRef.ExternalUsers, if ParameterContent = "Performers".
//                            
//                            Array of the types specified above.
//
//  NoPerformerGroups - Boolean - if False, TempTablesManager contains a temporary table. Otherwise, does not.
//
Procedure OnDeterminePerformersGroups(TempTablesManager, ParameterContent,
				ParameterValue, NoPerformerGroups) Export
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksServer = Common.CommonModule("BusinessProcessesAndTasksServer");
		ModuleBusinessProcessesAndTasksServer.OnDeterminePerformersGroups(TempTablesManager,
			ParameterContent, ParameterValue, NoPerformerGroups);
	EndIf;
	
EndProcedure

#EndRegion

#Region MonitoringCenter

// See MonitoringCenterOverridable.OnCollectConfigurationStatisticsParameters. 
Procedure OnCollectConfigurationStatisticsParameters() Export
	
	InfobaseUpdateInternal.OnCollectConfigurationStatisticsParameters();
	UsersInternal.OnCollectConfigurationStatisticsParameters();
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectVersioning.OnCollectConfigurationStatisticsParameters();
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnCollectConfigurationStatisticsParameters();
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnCollectConfigurationStatisticsParameters();
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
