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
	
	DataSeparationEnabled = Common.DataSeparationEnabled();
	
	SubsystemExistsDataExchange         = Common.SubsystemExists("StandardSubsystems.DataExchange");
	SubsystemExistsPeriodClosingDates = Common.SubsystemExists("StandardSubsystems.PeriodClosingDates");
	
	SetVisibility();
	SetAvailability();
	
	ApplicationSettingsOverridable.DataSynchronizationOnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	NotificationsHandler(EventName, Parameter, Source);
	
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
Procedure UseDataSynchronizationOnChange(Item)
	
	RefreshSecurityProfilesPermissions(Item);
	
EndProcedure

&AtClient
Procedure DistributedInfobaseNodePrefixOnChange(Item)
	
	BackgroundJob = StartIBPrefixChangeInBackgroundJob();
	
	If BackgroundJob <> Undefined
		AND BackgroundJob.Status = "Running" Then
		
		Items.DistributedInfobaseNodePrefix.Enabled = False;
		Items.WaitForPrefixChangeDecoration.Visible = True;
		
	EndIf;
	
	WaitSettings = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	WaitSettings.OutputIdleWindow = False;;
	
	Handler = New NotifyDescription("AfterChangePrefix", ThisObject);
	TimeConsumingOperationsClient.WaitForCompletion(BackgroundJob, Handler, WaitSettings);
	
EndProcedure

&AtServer
Function StartIBPrefixChangeInBackgroundJob()
	
	ProcedureParameters = New Structure("NewIBPrefix, ContinueNumbering",
		ConstantsSet.DistributedInfobaseNodePrefix, True);
		
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("ru = 'Изменение префикса'; en = 'Change prefix'; pl = 'Zmiana prefiksu';es_ES = 'Cambiar el prefijo';es_CO = 'Cambiar el prefijo';tr = 'Önek değişikliği';it = 'Modifica prefisso';de = 'Präfix ändern'");
	ExecutionParameters.WaitForCompletion = 0;
	
	Return TimeConsumingOperations.ExecuteInBackground("ObjectsPrefixesInternal.ChangeIBPrefix", ProcedureParameters, ExecutionParameters);
	
EndFunction

&AtClient
Procedure AfterChangePrefix(BackgroundJob, AdditionalParameters) Export

	If Not Items.DistributedInfobaseNodePrefix.Enabled Then
		Items.DistributedInfobaseNodePrefix.Enabled = True;
	EndIf;
	If Items.WaitForPrefixChangeDecoration.Visible Then
		Items.WaitForPrefixChangeDecoration.Visible = False;
	EndIf;
	
	If BackgroundJob <> Undefined
		AND BackgroundJob.Status = "Completed" Then
		
		ShowUserNotification(NStr("ru = 'Префикс изменен.'; en = 'Prefix is changed.'; pl = 'Prefiks został zmieniony.';es_ES = 'Prefijo cambiado.';es_CO = 'Prefijo cambiado.';tr = 'Önek değiştirildi.';it = 'Il prefisso è stato modificato.';de = 'Präfix geändert.'"));
		
	Else
		
		ConstantsSet.DistributedInfobaseNodePrefix = PrefIxReadFromInfobase();
		Items.DistributedInfobaseNodePrefix.UpdateEditText();
		
		If BackgroundJob <> Undefined Then
			ErrorText = NStr("ru='Не удалось изменить префикс.
				|См. подробности в журнале регистрации.'; 
				|en = 'Cannot change prefix.
				|For more details, see the event log.'; 
				|pl = 'Nie udało się zmienić prefiks.
				|Szczegóły w dzienniku rejestracji.';
				|es_ES = 'No se ha podido cambiar el prefijo.
				|Véase más en el registro.';
				|es_CO = 'No se ha podido cambiar el prefijo.
				|Véase más en el registro.';
				|tr = 'Önek değiştirilemedi.
				|Ayrıntılar için olay günlüğüne bakın.';
				|it = 'Impossibile modificare il prefisso.
				|Per maggiori dettagli, vedere il registro eventi.';
				|de = 'Das Präfix konnte nicht geändert werden.
				| Details im Ereignisprotokoll.'");
			CommonClientServer.MessageToUser(ErrorText);
		EndIf;
		
	EndIf;

EndProcedure

&AtServerNoContext
Function PrefIxReadFromInfobase()
	
	Return Constants.DistributedInfobaseNodePrefix.Get();
	
EndFunction

&AtClient
Procedure DataExchangeMessagesDirectoryForWindowsOnChange(Item)
	
	RefreshSecurityProfilesPermissions(Item);
	
EndProcedure

&AtClient
Procedure DataExchangeMessagesDirectoryForLinuxOnChange(Item)
	
	RefreshSecurityProfilesPermissions(Item);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

// Processing notification from other open forms.
//
// Parameters:
//   EventName - String - name of the event. It can be used to identify messages by forms that accept them.
//   Parameter - Arbitrary - message parameter. You can pass all needed data.
//   Source - Arbitrary - an event source. For example, another form can be specified as a source.
//
// Example:
//   If EventName = "ConstantsSet.DistributedInfobaseNodePrefix" Then
//     ConstantsSet.DistributedInfobaseNodePrefix = Parameter;
//   EndIf
//
&AtClient
Procedure NotificationsHandler(EventName, Parameter, Source)
	
	
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure Attachable_OnChangeAttribute(Item, UpdateInterface = True)
	
	ConstantName = OnChangeAttributeServer(Item.Name);
	
	RefreshReusableValues();
	
	If UpdateInterface Then
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

&AtClient
Procedure RefreshSecurityProfilesPermissions(Item)
	
	ClosingNotification = New NotifyDescription("RefreshSecurityProfilesPermissionsCompletion", ThisObject, Item);
	If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		
		QueriesArray = CreateRequestToUseExternalResources(Item.Name);
		
		If QueriesArray = Undefined Then
			Return;
		EndIf;
		
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.ApplyExternalResourceRequests(
			QueriesArray, ThisObject, ClosingNotification);
	Else
		ExecuteNotifyProcessing(ClosingNotification, DialogReturnCode.OK);
	EndIf;
	
EndProcedure

&AtServer
Function CreateRequestToUseExternalResources(ConstantName)
	
	ConstantManager = Constants[ConstantName];
	ConstantValue = ConstantsSet[ConstantName];
	
	If ConstantManager.Get() = ConstantValue Then
		Return Undefined;
	EndIf;
	
	If ConstantName = "UseDataSynchronization" Then
		
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		If ConstantValue Then
			Query = ModuleDataExchangeServer.RequestToUseExternalResourcesOnEnableExchange();
		Else
			Query = ModuleDataExchangeServer.RequestToClearPermissionsToUseExternalResources();
		EndIf;
		Return Query;
		
	Else
		
		ValueManager = ConstantManager.CreateValueManager();
		ConstantID = Common.MetadataObjectID(ValueManager.Metadata());
		
		ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
		If IsBlankString(ConstantValue) Then
			
			Query = ModuleSafeModeManager.RequestToClearPermissionsToUseExternalResources(ConstantID);
			
		Else
			
			Permissions = CommonClientServer.ValueInArray(
				ModuleSafeModeManager.PermissionToUseFileSystemDirectory(ConstantValue, True, True));
			Query = ModuleSafeModeManager.RequestToUseExternalResources(Permissions, ConstantID);
			
		EndIf;
		
		Return CommonClientServer.ValueInArray(Query);
		
	EndIf;
	
EndFunction

&AtClient
Procedure RefreshSecurityProfilesPermissionsCompletion(Result, Item) Export
	
	If Result = DialogReturnCode.OK Then
	
		Attachable_OnChangeAttribute(Item);
		
	Else
		
		ThisObject.Read();
	
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
	
	// Save values of attributes not directly related to constants (in ratio one to one).
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
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
	EndIf;
	
	Return ConstantName;
	
EndFunction

&AtServer
Procedure SetVisibility()
	
	If DataSeparationEnabled Then
		Items.SectionDetails.Title = NStr("ru = 'Синхронизация данных с моими приложениями.'; en = 'Synchronize data with my applications.'; pl = 'Synchronizacja danych z moimi aplikacjami.';es_ES = 'Sincronización de datos con mis aplicaciones.';es_CO = 'Sincronización de datos con mis aplicaciones.';tr = 'Uygulamalarım ile veri senkronizasyonu';it = 'Sincronizzare dati con la mia applicazione.';de = 'Synchronisation von Daten mit meinen Anwendungen.'");
	EndIf;
	
	If SubsystemExistsDataExchange Then
		ArrayOfAvailableVersions = New Map;
		ModuleDataExchangeOverridable = Common.CommonModule("DataExchangeOverridable");
		ModuleDataExchangeOverridable.OnGetAvailableFormatVersions(ArrayOfAvailableVersions);
		
		Items.EnterpriseDataLoadingGroup.Visible = ?(ArrayOfAvailableVersions.Count() = 0, False, True);
		
		Items.DistributedInfobaseNodePrefixGroup.ExtendedTooltip.Title =
			Metadata.Constants.DistributedInfobaseNodePrefix.Tooltip;
			
		If DataSeparationEnabled Then
			Items.UseDataSynchronizationGroup.Visible   = False;
			Items.TemporaryServerClusterDirectoriesGroup.Visible = False;
			
			Items.DistributedInfobaseNodePrefix.Title = NStr("ru = 'Префикс в этой программе'; en = 'Prefix in this application'; pl = 'Prefiks w tym programie';es_ES = 'Prefijo en este programa';es_CO = 'Prefijo en este programa';tr = 'Bu uygulamadaki önek';it = 'Prefisso in questa applicazione';de = 'Das Präfix in diesem Programm'");
		Else
			Items.TemporaryServerClusterDirectoriesGroup.Visible = Not Common.FileInfobase()
				AND Users.IsFullUser(, True);
		EndIf;
	Else
		Items.DataSynchronizationGroup.Visible = False;
		Items.DistributedInfobaseNodePrefixGroup.Visible = False;
		Items.DataSynchronizationMoreGroup.Visible  = False;
		Items.TemporaryServerClusterDirectoriesGroup.Visible = False;
	EndIf;
	
	If SubsystemExistsPeriodClosingDates Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		SectionsProperties = ModulePeriodClosingDatesInternal.SectionsProperties();
		
		Items.ImportRestrictionDatesGroup.Visible = SectionsProperties.ImportRestrictionDatesImplemented;
		
		If DataSeparationEnabled
			AND SectionsProperties.ImportRestrictionDatesImplemented Then
			Items.UseImportForbidDates.ExtendedTooltip.Title =
				NStr("ru = 'Запрет загрузки данных прошлых периодов из других приложений.
				           |Не влияет на загрузку данных из автономных рабочих мест.'; 
				           |en = 'Prohibit import of previous period data from other applications.
				           |It does not impact data import from offline workplaces.'; 
				           |pl = 'Zapobiegaj wczytywaniu danych ubiegłych okresów z innych aplikacji.
				           |Nie wpływa to na ładowanie danych z offline stacji roboczych.';
				           |es_ES = 'La prohibición de la carga de datos de los períodos anteriores de otras aplicaciones.
				           |No influye en la carga de datos de los lugares de trabajo autónomos.';
				           |es_CO = 'La prohibición de la carga de datos de los períodos anteriores de otras aplicaciones.
				           |No influye en la carga de datos de los lugares de trabajo autónomos.';
				           |tr = 'Diğer uygulamalardan geçmiş dönemlerin veri indirme engeli.
				           |Çevrimdışı çalışma alanlarından veri içe aktarımını etkilemez.';
				           |it = 'Vietare importazione dati dei periodi precedenti da altre applicazioni.
				           |Non influisce sull''importazione di dati da postazioni di lavoro offline.';
				           |de = 'Das Herunterladen historischer Daten aus anderen Anwendungen ist untersagt.
				           |Beeinflusst nicht den Download von Daten von Einzelarbeitsplätzen.'");
		EndIf;
	Else
		Items.ImportRestrictionDatesGroup.Visible = False;
	EndIf;
	
	Items.WaitForPrefixChangeDecoration.Visible = False;
	
EndProcedure

&AtServer
Procedure SetAvailability(DataPathAttribute = "")
	
	If (DataPathAttribute = "ConstantsSet.UseImportForbidDates"
			Or DataPathAttribute = "")
		AND SubsystemExistsPeriodClosingDates Then
		
		Items.ImportRestrictionDatesSettingsGroup.Enabled = ConstantsSet.UseImportForbidDates;
			
	EndIf;
	
	If (DataPathAttribute = "ConstantsSet.UseDataSynchronization"
			Or DataPathAttribute = "")
		AND SubsystemExistsDataExchange Then
		
		Items.DataSyncSettings.Enabled            = ConstantsSet.UseDataSynchronization;
		Items.ImportRestrictionDatesGroup.Enabled               = ConstantsSet.UseDataSynchronization;
		Items.DataSynchronizationResults.Enabled           = ConstantsSet.UseDataSynchronization;
		Items.TemporaryServerClusterDirectoriesGroup.Enabled = ConstantsSet.UseDataSynchronization;
		
	EndIf;
	
EndProcedure

#EndRegion
