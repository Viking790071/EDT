#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		Items.ExternalResourcesOperationsLockGroup.Visible =
			ScheduledJobsServer.OperationsWithExternalResourcesLocked();
		
		Items.ScheduledAndBackgroundJobsDataProcessorGroup.Visible =
			Users.IsFullUser(, True);
	Else
		Items.ScheduledAndBackgroundJobsDataProcessorGroup.Visible = False;
		Items.ExternalResourcesOperationsLockGroup.Visible = False;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.TotalsAndAggregatesManagement") Then
		Items.TotalsAndAggregatesManagementDataProcessorOpenGroup.Visible =
			  Users.IsFullUser()
			AND Not Common.DataSeparationEnabled();
	Else
		Items.TotalsAndAggregatesManagementDataProcessorOpenGroup.Visible = False;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.IBBackup") Then
		Items.BackupAndRecoveryGroup.Visible =
			  Users.IsFullUser(, True)
			AND Not Common.DataSeparationEnabled()
			AND Not CommonClientServer.ClientConnectedOverWebServer()
			AND CommonClientServer.IsWindowsClient();
		
		UpdateBackupSettings();
	Else
		Items.BackupAndRecoveryGroup.Visible = False;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		Items.PerformanceMonitorGroup.Visible =
			Users.IsFullUser(, True);
	Else
		Items.PerformanceMonitorGroup.Visible = False;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.BatchEditObjects") Then
		Items.BulkObjectEditingDataProcessorGroup.Visible =
			Users.IsFullUser();
	Else
		Items.BulkObjectEditingDataProcessorGroup.Visible = False;
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.DuplicateObjectDetection") Then
		Items.DuplicateObjectDetectionGroup.Visible = False;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		Items.AdditionalReportsAndDataProcessorsGroup.Visible =
			ConstantsSet.UseAdditionalReportsAndDataProcessors;
	Else
		Items.AdditionalReportsAndDataProcessorsGroup.Visible = False;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		Items.UpdatesInstallationGroup.Visible =
			  Users.IsFullUser(, True)
			AND Not Common.IsStandaloneWorkplace()
			AND Not Common.DataSeparationEnabled()
			AND Not CommonClientServer.ClientConnectedOverWebServer()
			AND CommonClientServer.IsWindowsClient();
		
		Items.InstalledPatchesGroup.Visible =
			Users.IsFullUser()
			AND Not StandardSubsystemsServer.IsBaseConfigurationVersion();
			
		If StandardSubsystemsServer.IsBaseConfigurationVersion() Then
			Items.InstallUpdates.Title = NStr("ru = 'Установка обновлений'; en = 'Installing updates'; pl = 'Instalacja aktualizacji';es_ES = 'Instalar las actualizaciones';es_CO = 'Instalar las actualizaciones';tr = 'Güncellemeleri yükle';it = 'Installazione aggiornamenti';de = 'Updates installieren'");
			Items.InstallUpdates.ExtendedTooltip.Title =
				NStr("ru = 'Обновление программы из файла на локальном диске или в сетевом каталоге.'; en = 'Update the application from a file on a local disk or in a network directory.'; pl = 'Aktualizacja programu z pliku na dysku lokalnym lub w katalogu sieciowym.';es_ES = 'Actualización del programa del archivo en el disco local o en el catálogo de red.';es_CO = 'Actualización del programa del archivo en el disco local o en el catálogo de red.';tr = 'Programı yerel diskinizdeki veya ağ dizininizdeki bir dosyadan güncelleyin.';it = 'Aggiornare l''applicazione da un file su disco locale o una cartella di rete.';de = 'Aktualisieren Sie das Programm aus einer Datei auf der lokalen Festplatte oder in einem Netzwerkverzeichnis.'");
		EndIf;
	Else
		Items.UpdatesInstallationGroup.Visible = False;
		Items.InstalledPatchesGroup.Visible = False;
	EndIf;
	
	If Common.SubsystemExists("OnlineUserSupport.CloudArchive") Then
		ModuleCloudArchive = Common.CommonModule("CloudArchive");
		ModuleCloudArchive.SSLAdministrationPanel_OnCreateAtServer(ThisObject);
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		If Items.Find("AccountingCheckRules") <> Undefined Then
			Items.AccountingCheckRules.Visible = False;
		EndIf;
	EndIf;
	
	Items.AdministratorReportsGroup.Visible = False;
	
	// Update items states.
	SetAvailability();
	
	ApplicationSettingsOverridable.ServiceOnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	If CommonClient.SubsystemExists("OnlineUserSupport.CloudArchive") Then
		ModuleCloudArchiveClient = CommonClient.CommonModule("CloudArchiveClient");
		ModuleCloudArchiveClient.SSLAdministrationPanel_OnOpen(ThisObject);
	EndIf;

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "BackupSettingsFormClosed"
		AND CommonClient.SubsystemExists("StandardSubsystems.IBBackup") Then
		UpdateBackupSettings();
	ElsIf EventName = "OperationsWithExternalResourcesAllowed" Then
		Items.ExternalResourcesOperationsLockGroup.Visible = False;
	EndIf;
	
	If CommonClient.SubsystemExists("OnlineUserSupport.CloudArchive") Then
		ModuleCloudArchiveClient = CommonClient.CommonModule("CloudArchiveClient");
		ModuleCloudArchiveClient.SSLAdministrationPanel_NotificationProcessing(ThisObject, EventName, Parameter, Source);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	If Exit Then
		Return;
	EndIf;
	UpdateApplicationInterface();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure EnablePerformanceMeasurementsOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure ItemizeIBUpdateInEventLogOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

#Region UsersOnlneSupport_CloudArchive

&AtClient
Procedure CloudArchiveURLProcessing(Item, FormattedStringURL, StandardProcessing)

	StandardProcessing = True;

	If CommonClient.SubsystemExists("OnlineUserSupport.CloudArchive") Then
		ModuleCloudArchiveClient = CommonClient.CommonModule("CloudArchiveClient");
		ModuleCloudArchiveClient.URLProcessing(
			ThisObject, Item, FormattedStringURL,
			StandardProcessing, New Structure);
	EndIf;

EndProcedure

&AtClient
Procedure BackupMethodOnChange(Item)

	// Display the correct page depending on the status.
	If CommonClient.SubsystemExists("OnlineUserSupport.CloudArchive") Then
		ModuleCloudArchiveClient = CommonClient.CommonModule("CloudArchiveClient");
		ModuleCloudArchiveClient.SSLAdministrationPanel_BackupMethodOnChange(ThisObject);
	EndIf;

EndProcedure

#EndRegion

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure UnlockOperationsWithExternalResources(Command)
	UnlockExternalSourceOperationsAtServer();
	StandardSubsystemsClient.SetAdvancedApplicationCaption();
	Notify("OperationsWithExternalResourcesAllowed");
	RefreshInterface();
EndProcedure

&AtClient
Procedure DeferredDataProcessing(Command)
	FormParameters = New Structure("OpenedFromAdministrationPanel", True);
	OpenForm("DataProcessor.ApplicationUpdateResult.Form.DeferredIBUpdateProgressIndicator", FormParameters);
EndProcedure

#Region UsersOnlneSupport_CloudArchive

&AtClient
Procedure EnableCloudArchiveService(Command)

	If CommonClient.SubsystemExists("OnlineUserSupport.CloudArchive") Then
		ModuleCloudArchiveClient = CommonClient.CommonModule("CloudArchiveClient");
		ModuleCloudArchiveClient.EnableCloudArchiveService();
	EndIf;

EndProcedure

&AtClient
Procedure CloudArchiveRestoreFromBackupClick(Item)

	If CommonClient.SubsystemExists("OnlineUserSupport.CloudArchive") Then
		ModuleCloudArchiveClient = CommonClient.CommonModule("CloudArchiveClient");
		ModuleCloudArchiveClient.RestoreFromBackup();
	EndIf;

EndProcedure

&AtClient
Procedure CloudArchiveBackupSetupClick(Item)

	If CommonClient.SubsystemExists("OnlineUserSupport.CloudArchive") Then
		ModuleCloudArchiveClient = CommonClient.CommonModule("CloudArchiveClient");
		ModuleCloudArchiveClient.BackupSetup();
	EndIf;

EndProcedure

#EndRegion

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure Attachable_OnChangeAttribute(Item, NeedToRefreshInterface = True)
	
	ConstantName = OnChangeAttributeServer(Item.Name);
	
	RefreshReusableValues();
	
	If NeedToRefreshInterface Then
		RefreshInterface = True;
		AttachIdleHandler("UpdateApplicationInterface", 2, True);
	EndIf;
	
	If ConstantName <> "" Then
		Notify("Write_ConstantsSet", New Structure, ConstantName);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		CommonClient.RefreshApplicationInterface();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server call

&AtServer
Function OnChangeAttributeServer(ItemName)
	
	DataPathAttribute = Items[ItemName].DataPath;
	
	ConstantName = SaveAttributeValue(DataPathAttribute);
	
	SetAvailability(DataPathAttribute);
	
	RefreshReusableValues();
	
	Return ConstantName;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Function SaveAttributeValue(DataPathAttribute)
	
	// Saving attribute values not directly related to constants.
	If DataPathAttribute = "" Then
		Return "";
	EndIf;
	
	// Define the constant name.
	ConstantName = "";
	Position = StrFind(DataPathAttribute, "ConstantsSet.");
	If Position > 0 Then
		ConstantName = StrReplace(DataPathAttribute, "ConstantsSet.", "");
	Else
		// Define the name and record the attribute value in the constant from the ConstantsSet.
		// It is used for those form attributes that are directly related to constants (in ratio one to one).
	EndIf;
	
	// Save the constant value.
	If Lower(Left(DataPathAttribute, 14)) = Lower("ConstantsSet.") Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
	EndIf;
	
	Return ConstantName;
	
EndFunction

&AtServer
Procedure SetAvailability(DataPathAttribute = "")
	
	If Not Users.IsFullUser(, True) Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor")
		AND (DataPathAttribute = "ConstantsSet.RunPerformanceMeasurements"
		Or DataPathAttribute = "") Then
			ItemDataProcessorPerformanceMonitorImportPerformanceMeasurements = Items.Find("PerformanceEvaluationPerformanceMeasurementImportDataProcessor");
			ItemDataProcessorPerformanceMonitorExportData = Items.Find("PerformanceEvaluationDataExportDataProcessor");
			ItemCatalogKeyOperationsProfilesOpenList = Items.Find("CatalogKeyOperationsProfilesOpenList");
			ItemDataProcessorPerformanceMonitorSettings = Items.Find("PerformanceEvaluationSettingsDataProcessor");
			If (ItemDataProcessorPerformanceMonitorSettings <> Undefined
				AND ItemDataProcessorPerformanceMonitorExportData <> Undefined				
				AND ItemCatalogKeyOperationsProfilesOpenList <> Undefined
				AND ItemDataProcessorPerformanceMonitorImportPerformanceMeasurements <> Undefined
				AND ConstantsSet.Property("RunPerformanceMeasurements")) Then
				ItemDataProcessorPerformanceMonitorSettings.Enabled = ConstantsSet.RunPerformanceMeasurements;
				ItemDataProcessorPerformanceMonitorExportData.Enabled = ConstantsSet.RunPerformanceMeasurements;
				ItemCatalogKeyOperationsProfilesOpenList.Enabled = ConstantsSet.RunPerformanceMeasurements;
				ItemDataProcessorPerformanceMonitorImportPerformanceMeasurements.Enabled = ConstantsSet.RunPerformanceMeasurements;
			EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateBackupSettings()
	
	If Not Common.DataSeparationEnabled()
	   AND Users.IsFullUser(, True) Then
		
		ModuleIBBackupServer = Common.CommonModule("IBBackupServer");
		Items.IBBackupSetup.ExtendedTooltip.Title = ModuleIBBackupServer.CurrentBackupSetting();
	EndIf;
	
EndProcedure

&AtServer
Procedure UnlockExternalSourceOperationsAtServer()
	Items.ExternalResourcesOperationsLockGroup.Visible = False;
	ModuleScheduledJobsInternal = Common.CommonModule("ScheduledJobsInternal");
	ModuleScheduledJobsInternal.AllowOperationsWithExternalResources();
EndProcedure

#Region UsersOnlneSupport_CloudArchive

&AtClient
Procedure Attachable_CheckCloudArchiveState()

	If CommonClient.SubsystemExists("OnlineUserSupport.CloudArchive") Then
		ModuleCloudArchiveClient = CommonClient.CommonModule("CloudArchiveClient");
		ModuleCloudArchiveClient.SSLAdministrationPanel_CheckCloudArchiveStatus(ThisObject);
	EndIf;

EndProcedure

#EndRegion

#EndRegion