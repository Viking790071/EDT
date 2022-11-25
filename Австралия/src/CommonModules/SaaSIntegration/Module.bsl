////////////////////////////////////////////////////////////////////////////////
// Integration with Service Technology Library (STL).
// Here you can find processors of program events that make calls between SSL and STL.
// 
//


// Processing program events that occur in STL subsystems.
// Only for calls from STL libraries to SSL.

#Region Public

#Region ForCallsFromOtherSubsystems

// CloudTechnology.Core

#Region ExportImportData

// See ExportImportDataOverridable.OnFillCommonDataTypesSupportingReferenceComparisonOnImport. 
Procedure OnFillCommonDataTypesSupportingRefMappingOnExport(Types) Export
	
	StandardSubsystemsServer.OnFillCommonDataTypesSupportingRefMappingOnExport(Types);
	
	If Common.SubsystemExists("StandardSubsystems.Banks") Then
		ModuleBankManager = Common.CommonModule("BankManager");
		ModuleBankManager.OnFillCommonDataTypesSupportingRefMappingOnExport(Types);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnFillCommonDataTypesSupportingRefMappingOnExport(Types);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.OnFillCommonDataTypesSupportingRefMappingOnExport(Types);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.CalendarSchedules") Then
		ModuleCalendarSchedules = Common.CommonModule("CalendarSchedules");
		ModuleCalendarSchedules.OnFillCommonDataTypesSupportingRefMappingOnExport(Types);
	EndIf;
	
EndProcedure

// See ExportImportDataOverridable.OnFillCommonDataTypesThatDoNotRequireMappingRefsOnImport. 
Procedure OnFillCommonDataTypesThatDoNotRequireMappingRefsOnImport(Types) Export
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFilesInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleStoredFilesInternal.OnFillCommonDataTypesThatDoNotRequireMappingRefsOnImport(Types);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnFillCommonDataTypesThatDoNotRequireMappingRefsOnImport(Types);
	EndIf;
	
EndProcedure

// See ExportImportDataOverridable.OnFillTypesExcludedFromExportImport. 
Procedure OnFillTypesExcludedFromExportImport(Types) Export
	
	StandardSubsystemsServer.OnFillTypesExcludedFromExportImport(Types);
		
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnFillTypesExcludedFromExportImport(Types);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnFillTypesExcludedFromExportImport(Types);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AddIns") Then
		ModuleAddInsInternal = Common.CommonModule("AddInsInternal");
		ModuleAddInsInternal.OnFillTypesExcludedFromExportImport(Types);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.AddInsSaaS") Then
		ModuleAddInsSaaSInternal = Common.CommonModule("AddInsSaaSInternal");
		ModuleAddInsSaaSInternal.OnFillTypesExcludedFromExportImport(Types);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.UserSessionsCompletion") Then
		ModuleIBConnections = Common.CommonModule("IBConnections");
		ModuleIBConnections.OnFillTypesExcludedFromExportImport(Types);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternal = Common.CommonModule("AccountingAuditInternal");
		ModuleAccountingAuditInternal.OnFillTypesExcludedFromExportImport(Types);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.AddressClassifierSaaS") Then
		ModuleAddressClassifierSaaSInternal = Common.CommonModule("AddressClassifierSaaSInternal");
		ModuleAddressClassifierSaaSInternal.OnFillTypesExcludedFromExportImport(Types);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		ModuleSaaS.OnFillTypesExcludedFromExportImport(Types);
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.SaaS.MessageExchange") Then
		ModuleMessageExchangeInternal = Common.CommonModule("MessageExchangeInternal");
		ModuleMessageExchangeInternal.OnFillTypesExcludedFromExportImport(Types);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.OnFillTypesExcludedFromExportImport(Types);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ModuleJobQueueInternalDataSeparation = Common.CommonModule("JobQueueInternalDataSeparation");
		ModuleJobQueueInternalDataSeparation.OnFillTypesExcludedFromExportImport(Types);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.DataAreaBackup") Then
		ModuleDataAreaBackup = Common.CommonModule("DataAreaBackup");
		ModuleDataAreaBackup.OnFillTypesExcludedFromExportImport(Types);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.FilesManagerSaaS") Then
		ModuleFilesManagerInternalSaaS = Common.CommonModule("FilesManagerInternalSaaS");
		ModuleFilesManagerInternalSaaS.OnFillTypesExcludedFromExportImport(Types);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnFillTypesExcludedFromExportImport(Types);
	EndIf;
	
EndProcedure

// See ExportImportDataOverridable.AfterDataImport. 
Procedure AfterImportData(Container) Export
	
	UsersInternal.AfterImportData(Container);
	
	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleScheduledJobsInternal = Common.CommonModule("ScheduledJobsInternal");
		ModuleScheduledJobsInternal.AfterImportData(Container);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		ModuleSaaS.AfterImportData(Container);
	EndIf;
	
	If Common.SubsystemExists("SaaS.CurrenciesSaaS") Then
		ModuleCurrencyExchangeRatesInternalSaaS = Common.CommonModule("CurrencyRatesInternalSaaS");
		ModuleCurrencyExchangeRatesInternalSaaS.AfterImportData(Container);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		ModuleJobQueueInternalDataSeparation = Common.CommonModule("JobQueueInternalDataSeparation");
		ModuleJobQueueInternalDataSeparation.AfterImportData(Container);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.AfterImportData(Container);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.AccessManagementSaaS") Then
		ModuleAccessManagementInternalSaaS = Common.CommonModule("AccessManagementInternalSaaS");
		ModuleAccessManagementInternalSaaS.AfterImportData(Container);
	EndIf;
	
	InfobaseUpdateInternal.AfterImportData(Container);
	
EndProcedure

// See ExportImportDataOverridable.OnRegisterDataExportHandlers. 
Procedure OnRegisterDataExportHandlers(HandlersTable) Export
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnRegisterDataExportHandlers(HandlersTable);
	EndIf;
	
EndProcedure

#EndRegion

// End CloudTechnology.Core

#EndRegion

#EndRegion

// Processing program events that occur in SSL subsystems.
// Only for calls from SSL libraries to STL.

#Region Internal

#Region Core

// See CommonOverridable.OnAddRefsSearchExceptions. 
Procedure OnAddReferenceSearchExceptions(RefSearchExclusions) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnAddReferenceSearchExceptions(RefSearchExclusions);
	EndIf;
	
EndProcedure

// See the Syntax Assistant for OnSendDataToMaster. 
Procedure OnSendDataToMaster(DataItem, ItemSend, Recipient) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnSendDataToMaster(DataItem, ItemSend, Recipient);
	EndIf;
	
EndProcedure

// See the Syntax Assistant for OnSendDataToSlave. 
Procedure OnSendDataToSlave(DataItem, ItemSend, InitialImageCreation, Recipient) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnSendDataToSlave(DataItem, ItemSend, InitialImageCreation, Recipient);
	EndIf;
	
EndProcedure

// See the Syntax Assistant for OnReceiveDataFromMaster. 
Procedure OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender);
	EndIf;
	
EndProcedure

// See the Syntax Assistant for OnReceiveDataFromSlave. 
Procedure OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender);
	EndIf;
	
EndProcedure

// See SaaSOverridable.OnEnableDataSeparation. 
Procedure OnEnableSeparationByDataAreas() Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnEnableSeparationByDataAreas();
	EndIf;
	
EndProcedure

// See CommonOverridable.OnDefineSupportedInterfaceVersions. 
Procedure OnDefineSupportedInterfaceVersions(Val SupportedVersionStructure) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnDefineSupportedInterfaceVersions(SupportedVersionStructure);
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddClientParametersOnStart. 
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnAddClientParametersOnStart(Parameters);
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddClientParameters. 
Procedure OnAddClientParameters(Parameters) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnAddClientParameters(Parameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region AdditionalReportsAndDataProcessors

// Call to determine whether the current user has right to add an additional report or data 
// processor to a data area.
//
// Parameters:
//  AdditionalDataProcessor - CatalogObject.AdditionalReportsAndDataProcessors, catalog item written 
//    by user.
//  Result - Boolean - the flag that shows whether the required rights are granted.
//  StandardProcessing - Boolean - flag specifying whether standard processing is used to validate 
//    rights.
//
Procedure OnCheckAddRight(Val AdditionalDataProcessor, Result, StandardProcessing) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnCheckAddRight(AdditionalDataProcessor, Result, StandardProcessing);
	EndIf;
	
EndProcedure

// Called to check whether an additional report or data processor can be imported from file.
//
// Parameters:
//  AdditionalDataProcessor - CatalogRef.AdditionalReportsAndDataProcessors,
//  Result - Boolean - flag specifying whether additional reports or data processors can be imported 
//    from files.
//  StandardProcessing - Boolean - flag specifying whether standard processing checks if additional 
//    reports or data processors can be imported from files.
//
Procedure OnCheckCanImportDataProcessorFromFile(Val AdditionalDataProcessor, Result, StandardProcessing) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnCheckCanImportDataProcessorFromFile(AdditionalDataProcessor, Result, StandardProcessing);
	EndIf;
	
EndProcedure

// Called to check whether an additional report or data processor can be exported to a file.
//
// Parameters:
//  AdditionalDataProcessor - CatalogRef.AdditionalReportsAndDataProcessors,
//  Result - Boolean - flag specifying whether additional reports or data processors can be exported 
//    to files.
//  StandardProcessing - Boolean - flag specifying whether standard processing checks if an 
//    additional reports or data processors can be exported to files.
//
Procedure OnCheckCanExportDataProcessorToFile(Val AdditionalDataProcessor, Result, StandardProcessing) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnCheckCanExportDataProcessorToFile(AdditionalDataProcessor, Result, StandardProcessing);
	EndIf;
	
EndProcedure

// Fills additional report or data processor publication kinds that cannot be used in the current 
// infobase model.
//
// Parameters:
//  UnavailablePublicationKinds - an array of strings.
//
Procedure OnFillUnavailablePublicationKinds(Val UnavailablePublicationKinds) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnFillUnavailablePublicationKinds(UnavailablePublicationKinds);
	EndIf;
	
EndProcedure

// The procedure is called from the BeforeWrite event of the
//  AdditionalReportsAndDataProcessors. Validates changes to the directory item attributes for 
//  additional data processors retrieved from the service manager additional data processors 
//  directory.
//
// Parameters:
//  Source - CatalogObject.AdditionalReportsAndDataProcessors.
//  Cancel - Boolean - the flag specifying whether writing a catalog item must be canceled.
//
Procedure BeforeWriteAdditionalDataProcessor(Source, Cancel) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.BeforeWriteAdditionalDataProcessor(Source, Cancel);
	EndIf;
	
EndProcedure

// The procedure is called from the BeforeDelete event of catalog
//  AdditionalReportsAndDataProcessors.
//
// Parameters:
//  Source - CatalogObject.AdditionalReportsAndDataProcessors.
//  Boolean - flag specifying whether catalog item deletion must be cancelled.
//
Procedure BeforeDeleteAdditionalDataProcessor(Source, Cancel) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.BeforeDeleteAdditionalDataProcessor(Source, Cancel);
	EndIf;
	
EndProcedure

// Called to get registration data for a new additional report or data processor.
// 
//
Procedure OnGetRegistrationData(Object, RegistrationData, StandardProcessing) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnGetRegistrationData(Object, RegistrationData, StandardProcessing);
	EndIf;
	
EndProcedure

// Called to attach an external data processor.
//
// Parameters:
//  Ref - CatalogRef.AdditionalReportsAndDataProcessors.
//  StandardProcessing - Boolean - flag specifying whether standard processing is required to attach 
//    an external data processor.
//  Result - String - the name of attached external report or data processor (provided that the 
//    handler StandardProcessing parameter is set to False).
//
Procedure OnAttachExternalDataProcessor(Val Ref, StandardProcessing, Result) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnAttachExternalDataProcessor(Ref, StandardProcessing, Result);
	EndIf;
	
EndProcedure

// Called to create an external data processor object.
//
// Parameters:
//  Ref - CatalogRef.AdditionalReportsAndDataProcessors.
//  StandardProcessing - Boolean - flag specifying whether standard processing is required to attach 
//    an external data processor.
//  Result - ExternalDataProcessorObject - the object of attached external report or data processor 
//    (provided that the handler StandardProcessing parameter is set to False).
//
Procedure OnCreateExternalDataProcessor(Val Ref, StandardProcessing, Result) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnCreateExternalDataProcessor(Ref, StandardProcessing, Result);
	EndIf;
	
EndProcedure

// Called to get permissions for a safe mode session.
//
// Parameters:
//  SessionKey - UUID.
//  PermissionDetailsList - ValueTable:
//    * PermissionKind - String.
//    * Parameters - ValueStorage.
//  StandardProcessing - Boolean - flag specifying whether standard processing is required.
//
Procedure OnGetSafeModeSessionPermissions(Val SessionKey, PermissionDetailsList, StandardProcessing) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnGetSafeModeSessionPermissions(SessionKey, PermissionDetailsList, StandardProcessing);
	EndIf;
	
EndProcedure

// Called before writing changes in scheduled job for additional reports and data processors in SaaS.
//
// Parameters:
//   Object - CatalogRef.AdditionalReportsAndDataProcessors - an object of an additional report or data processor.
//   Command - CatalogTabularSectionRow.AdditionalReportsAndDataProcessors.Commands - the command details.
//   Job - ScheduledJob.ValueTableRow - the scheduled job details.
//       See the details on the ScheduledJobsServer.Job() function return value.
//   Changes - Structure - the job attribute values to be modified.
//       See the details on the ScheduledJobsServer.ChangeJob procedure second parameter.
//       If the value is Undefined, the scheduled job stays unchanged.
//
Procedure BeforeUpdateJob(Object, Command, Job, Changes) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.BeforeUpdateJob(Object, Command, Job, Changes);
	EndIf;
	
EndProcedure

#EndRegion

#Region IBVersionUpdate

// With it, you can override update priority. The default priority order is stored in the IBUpdateInfo constant.
// For example, STL can override update priority for each data area in SaaS mode.
//
// Parameters:
//  Priority - String - new update priority value (return value). Valid return values:
//              * "UserWork" - user processing priority (single thread).
//              * "DataProcessing" - data processing priority (several threads).
//              * Another - apply the priority as specified in the IBUpdateInfo constant (do not override).
//
Procedure OnGetUpdatePriority(Priority) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		RequiredSTLVersion = "1.0.17.3";
		ModuleSaaSTechnology = Common.CommonModule("CloudTechnology");
		CurrentSTLVersion = ModuleSaaSTechnology.LibraryVersion();
		
		If CommonClientServer.CompareVersions(CurrentSTLVersion, RequiredSTLVersion) >= 0  Then
			ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
			ModuleSaaSTechnologyIntegrationWithSSL.OnGetUpdatePriorityForDataAreas(Priority);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Users

// The procedure is called if the current infobase user cannot be found in the user catalog.
//  For such cases, you can enable auto creation of a Users catalog item for the current user.
// 
//
// Parameters:
//  CreateUser - Boolean - (return value) - if True, a new user is created in the Users catalog.
//       
//       To override the default user settings before its creation, use 
//       OnAutoCreateCurrentUserInCatalog.
//
Procedure OnNoCurrentUserInCatalog(CreateUser) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnNoCurrentUserInCatalog(CreateUser);
	EndIf;
	
EndProcedure

// The procedure is called when a Users catalog item is created automatically as a result of 
// interactive sign in or on the call from code.
//
// Parameters:
//  NewUser - CatalogObject.Users - the new user, not written.
//
Procedure OnAutoCreateCurrentUserInCatalog(NewUser) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnAutoCreateCurrentUserInCatalog(NewUser);
	EndIf;
	
EndProcedure

// The procedure is called during the authorization of a new infobase user.
//
// Parameters:
//  IBUser - InfobaseUser - the current infobase user.
//  StandardProcessing - Boolean - the value can be set in the handler. If False, standard 
//    processing of new infobase user authorization is not executed.
//
Procedure OnAuthorizeNewIBUser(InfobaseUser, StandardProcessing) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnAuthorizeNewIBUser(InfobaseUser, StandardProcessing);
	EndIf;
	
EndProcedure

// The procedure is called at the start of infobase user processing.
//
// Parameters:
//  ProcessingParameters - Structure - see the comment to the StartIBUserProcessing() procedure.
//  StartIBUserProcessing - Structure - see the comment to the StartIBUserProcessing() procedure.
//
Procedure OnStartIBUserProcessing(ProcessingParameters, IBUserDetails) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnStartIBUserProcessing(ProcessingParameters, IBUserDetails);
	EndIf;
	
EndProcedure

// Called before writing an infobase user.
//
// Parameters:
//  IBUser - InfobaseUser - the user to be written.
//
Procedure BeforeWriteIBUser(InfobaseUser) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.BeforeWriteIBUser(InfobaseUser);
	EndIf;
	
EndProcedure

// Called before deleting an infobase user.
//
// Parameters:
//  IBUser - InfobaseUser - the user to be deleted.
//
Procedure BeforeDeleteIBUser(InfobaseUser) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.BeforeDeleteIBUser(InfobaseUser);
	EndIf;
	
EndProcedure

#EndRegion

#Region SecurityProfiles

// Called when checking whether security profiles can be set.
//
// Parameters:
//  Cancel - Boolean. If security profiles cannot be used for the infobase, set the value of this 
//    parameter to True.
//
Procedure CanSetupSecurityProfilesOnCheck(Cancel) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.CanSetupSecurityProfilesOnCheck(Cancel);
	EndIf;
	
EndProcedure

// See SafeModeManagerOverridable.OnRequestPermissionsToUseExternalResources. 
Procedure OnRequestPermissionsToUseExternalResources(Val ProgramModule, Val Owner, Val ReplacementMode, Val PermissionsToAdd, Val PermissionsToDelete, StandardProcessing, Result) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnRequestPermissionsToUseExternalResources(ProgramModule, Owner, ReplacementMode, PermissionsToAdd, PermissionsToDelete, StandardProcessing, Result);
	EndIf;
	
EndProcedure

// See SafeModeManagerOverridable.OnRequestToCreateSecurityProfile. 
Procedure OnRequestToCreateSecurityProfile(Val ProgramModule, StandardProcessing, Result) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnRequestToCreateSecurityProfile(ProgramModule, StandardProcessing, Result);
	EndIf;
	
EndProcedure

// See SafeModeManagerOverridable.OnRequestToDeleteSecurityProfile. 
Procedure OnRequestToDeleteSecurityProfile(Val ProgramModule, StandardProcessing, Result) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnRequestToDeleteSecurityProfile(ProgramModule, StandardProcessing, Result);
	EndIf;
	
EndProcedure

// See SafeModeManagerOverridable.OnAttachExternalModule. 
Procedure OnAttachExternalModule(Val ExternalModule, SafeMode) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnAttachExternalModule(ExternalModule, SafeMode);
	EndIf;
	
EndProcedure

#EndRegion

#Region SaaS_CoreSaaS

// See SaaSOverridable.OnFillIBParametersTable. 
Procedure OnFillIIBParametersTable(Val ParametersTable) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnFillIIBParametersTable(ParametersTable);
	EndIf;
	
EndProcedure

// Called when determining the user alias to be displayed in the interface.
//
// Parameters:
//  UserID - UUID.
//  Alias - String - the user alias.
//
Procedure OnDetermineUserAlias(UserID, Alias) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnDetermineUserAlias(UserID, Alias);
	EndIf;
	
EndProcedure

// The procedure called on defining a list of unseparated metadata that can be written from a 
// separated session. The procedure adds references to metadata objects to be excluded to the 
// Exceptions array. The metadata might not exist in subscriptions that check if writing unseparated 
// data from the separated session is restricted.
Procedure OnDefineSharedDataExceptions(Exceptions) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnDefineSharedDataExceptions(Exceptions);
	EndIf;
	
EndProcedure

#EndRegion

#Region SaaS_MessageExchange

// See MessageExchangeOverridable.GetMessageChannelHandlers. 
Procedure MessageChannelHandlersOnDefine(Handlers) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.MessageChannelHandlersOnDefine(Handlers);
	EndIf;
	
EndProcedure

// See MessageInterfacesSaaSOverridable.FillIncomingMessageHandlers. 
Procedure RecordingIncomingMessageInterfaces(HandlerArray) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.RecordingIncomingMessageInterfaces(HandlerArray);
	EndIf;
	
EndProcedure

// See MessageInterfacesSaaSOverridable.FillOutgoingMessageHandlers. 
Procedure RecordingOutgoingMessageInterfaces(HandlerArray) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.RecordingOutgoingMessageInterfaces(HandlerArray);
	EndIf;
	
EndProcedure

// See MessageInterfacesSaaSOverridable.OnDetermineCorrespondentInterfaceVersion. 
Procedure OnDetermineCorrespondentInterfaceVersion(Val MessageInterface, Val ConnectionParameters, Val RecipientPresentation, Result) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnDetermineCorrespondentInterfaceVersion(MessageInterface, ConnectionParameters, RecipientPresentation, Result);
	EndIf;
	
EndProcedure

#EndRegion

#Region SaaS_JobQueue

// See JobQueueOverridable.OnReceiveTemplateList. 
Procedure OnGetTemplateList(JobTemplates) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnGetTemplateList(JobTemplates);
	EndIf;
	
EndProcedure

// See JobQueueOverridable.OnDefineHandlerAliases. 
Procedure OnDefineHandlerAliases(NameAndAliasMap) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnDefineHandlerAliases(NameAndAliasMap);
	EndIf;
	
EndProcedure

// See JobQueueOverridable.OnDefineErrorHandlers. 
Procedure OnDefineErrorHandlers(ErrorHandlers) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnDefineErrorHandlers(ErrorHandlers);
	EndIf;
	
EndProcedure

// See JobQueueOverridable.OnDetermineScheduledJobsUsage. 
Procedure OnDetermineScheduledJobsUsage(UsageTable) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnDetermineScheduledJobsUsage(UsageTable);
	EndIf;
	
EndProcedure

#EndRegion

#Region SaaS_SuppliedData

// See SuppliedDataOverridable.GetSuppliedDataHandlers. 
Procedure OnDefineSuppliedDataHandlers(Handlers) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnDefineSuppliedDataHandlers(Handlers);
	EndIf;
	
EndProcedure

#EndRegion

#Region ScheduledJobs

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings. 
Procedure OnDefineScheduledJobSettings(Settings) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnology = Common.CommonModule("CloudTechnology");
		If CommonClientServer.CompareVersions(ModuleSaaSTechnology.LibraryVersion(), "1.0.13.1") >= 0 Then
			ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
			ModuleSaaSTechnologyIntegrationWithSSL.OnDefineScheduledJobSettings(Settings);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region AccessManagement

// This procedure is called when updating the infobase user roles.
//
// Parameters:
//  IBUserID - UUID.
//  Cancel - Boolean. If this parameter is set to False in the event handler, roles are not updated 
//    for this infobase user.
//
Procedure OnUpdateIBUserRoles(IBUserID, Cancel) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnologyIntegrationWithSSL = Common.CommonModule("CTLAndSSLIntegration");
		ModuleSaaSTechnologyIntegrationWithSSL.OnUpdateIBUserRoles(IBUserID, Cancel);
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
