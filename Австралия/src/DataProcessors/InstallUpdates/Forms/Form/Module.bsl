#Region Variables

&AtClient
Var AdministrationParameters;

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If CommonClientServer.IsLinuxClient() Then
		Return; // Fail is set in OnOpen().
	EndIf;
	
	StandardSubsystemsServer.SetGroupTitleRepresentation(ThisObject);
	
	WriteLogEvent(DataProcessors.InstallUpdates.EventLogEvent(), EventLogLevel.Information,,,
		NStr("en = 'Opening configuration update wizard...'; ru = 'Открытие помощника обновления конфигурации...';pl = 'Otwarcie kreatora aktualizacji konfiguracji...';es_ES = 'Abriendo el asistente de actualización de configuraciones...';es_CO = 'Abriendo el asistente de actualización de configuraciones...';tr = 'Yapılandırma güncelleme sihirbazı açılıyor ...';it = 'Apertura procedura guidata di aggiornamento configurazione...';de = 'Konfigurationsassistent wird geöffnet...'"));
	DataProcessors.InstallUpdates.AbortExecuteIfExternalUserAuthorized();
	
	// Setting the update flag at the end of assistant work.
	ExecuteUpdate = False;
	
	// If it is the first start after the configuration update, we save and reset the status.
	Object.UpdateResult = ConfigurationUpdate.ConfigurationUpdateSuccessful();
	If Object.UpdateResult <> Undefined Then
		DataProcessors.InstallUpdates.ResetStatusOfConfigurationUpdate();
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		Items.PanelMail.Visible = False;
	EndIf;
	
	// Check each time when opening the assistant.
	ConfigurationChanged = ConfigurationChanged();
	
	If Parameters.CompletingOfWorkSystem Then
		Items.SwitchFileUpdates.Visible = False;
		Items.RadioButtonUpdateServer.Visible = False;
		Items.UpdateDateGroup.Visible = False;
	EndIf;
	
	If Parameters.ConfigurationUpdateReceived Then
		
		Items.PagesUpdateMethodFile.CurrentPage = Items.PageReceivedUpdateFromFileApplications;
		
	EndIf;
	
	InformationOnAvailabilityOfConnections = IBConnections.ConnectionsInformation();
	ThereAreActiveSessions = Not InformationOnAvailabilityOfConnections.HasActiveUsers;
	
	Items.LabelConfigurationUpdateInProgressWhenDataExchangeWithHost.Title = StringFunctionsClientServer.SubstituteParametersToString(
		Items.LabelConfigurationUpdateInProgressWhenDataExchangeWithHost.Title, ExchangePlans.MasterNode());
	
	AuthenticationParameters = DataProcessors.InstallUpdates.AuthenticationParametersOnSite();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not ItIsPossibleToStartUpdate() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	RestoreSettingsUpdateConfigurations();
	
	If Parameters.ExecuteUpdate Then
		If ThereAreActiveSessions Then
			GoToChoiceOfUpdateMode();
			Return;
		ElsIf CheckAccessToIB() Then
			ExecuteUpdate = True;
			ConfigurationUpdateClientOverridable.BeforeExit();
			ApplicationParameters.Insert("StandardSubsystems.SkipAlertBeforeExit", True);
			Exit(False);
			Close();
		EndIf;
	EndIf;
	
	Pages = Items.AssistantPages.ChildItems;
	PageName = Pages.Welcome.Name;
	
	AvailableUpdate = ConfigurationUpdateClientDrive.GetAvailableConfigurationUpdate();
	// If there is an update in the Internet network...
	If AvailableUpdate.UpdateSource = 0 AND AvailableUpdate.FlagOfAutoTransitionToPageWithUpdate Then
		TimeOfObtainingUpdate = AvailableUpdate.TimeOfObtainingUpdate;
		If TimeOfObtainingUpdate <> Undefined AND CommonClient.SessionDate() - TimeOfObtainingUpdate < 30 Then
			PageName = GetUpdateFilesViaInternet(True);
		EndIf;
	// If the configuration is changed, we will apply it to the data base.
	ElsIf AvailableUpdate.UpdateSource = 2 AND AvailableUpdate.NeedUpdateFile = 0 
		AND AvailableUpdate.FlagOfAutoTransitionToPageWithUpdate Then
		PageName = Pages.UpdateFile.Name;
	EndIf;
	
	If Object.SchedulerTaskCode <> 0 Then
		If GetSchedulerTask(Object.SchedulerTaskCode) = Undefined Then
			Object.SchedulerTaskCode = 0;
		EndIf;
	EndIf;
	
	// If the form opens at the application start after updating.
	If Object.UpdateResult <> Undefined Then	
		
		FileNameOrderUpdate = GetNameOfLocalFileOfUpdateOrder();
		If Not FileExistsAtClient(FileNameOrderUpdate) Then
			FileNameOrderUpdate = "";
		EndIf; 
		
		FileNameInformationAboutUpdate	= GetNameOfLocalFileOfUpdateDescription();
		If Not FileExistsAtClient(FileNameInformationAboutUpdate) Then
			FileNameInformationAboutUpdate = "";
		EndIf; 
		
		PageName = ? (Object.UpdateResult, Pages.SuccessfulRefresh.Name, Pages.FailureRefresh.Name);
		Object.UpdateResult = Undefined;
		
	Else
		
		ConfigurationIsReadyForUpgrade = ConfigurationUpdateClientOverridable.ReadinessForConfigurationUpdate(True);
		If ConfigurationIsReadyForUpgrade = Undefined Then
			ConfigurationIsReadyForUpgrade = True;
		EndIf;
		ConfigurationUpdateClientOverridable.WhenDeterminingConfigurationReadinessForUpdate(
			ConfigurationIsReadyForUpgrade);
		
		If Not ConfigurationIsReadyForUpgrade Then
			NameLogEvents = ConfigurationUpdateClient.EventLogEvent();
			EventLogClient.AddMessageForEventLog(NameLogEvents, "Information",
				NStr("en = 'Configuration can not be updated. Update verification completion.'; ru = 'Конфигурация не может быть обновлена. Завершение проверки обновления.';pl = 'Konfiguracja nie może być aktualizowana. Zaktualizuj weryfikację.';es_ES = 'Configuración no puede actualizarse. Finalización de la verificación de la actualización.';es_CO = 'Configuración no puede actualizarse. Finalización de la verificación de la actualización.';tr = 'Yapılandırma güncellenemez. Doğrulama işlemini tamamlayın.';it = 'La configurazione non può essere aggiornata. Completamento del controllo di aggiornamento.';de = 'Die Konfiguration kann nicht aktualisiert werden. Aktualisiere Verifikationsabschluss.'"));
			Cancel = True;
			Return;
		EndIf; 
		
		If Object.SchedulerTaskCode <> 0 Then
			DenialParameter	= False; // It is not used in this case.
			PageName		= RestoreResultsOfPreviousStart(DenialParameter);
		ElsIf ConfigurationChanged AND
				Object.UpdateSource = 2 Then
			Object.NeedUpdateFile	= 0;
			PageName		= Pages.UpdateFile.Name;
		EndIf;
		
		If Not ConfigurationUpdateClientCachedDrive.ClientWorkParameters().IsMasterNode Then
			If ConfigurationChanged Then
				GoToChoiceOfUpdateMode();
				Return;
			Else
				PageName = Pages.UpdatesNotDetected.Name;
			EndIf;
		EndIf
		
	EndIf;
	
	If PageName = Undefined Then
		Return;
	EndIf;
	
	BeforePageOpen(Pages[PageName]);
	Items.AssistantPages.CurrentPage = Pages[PageName];
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("DataProcessor.InstallUpdates.Form.ScheduleSetup") Then
		
		If TypeOf(ValueSelected) = Type("Structure") Then
			FillPropertyValues(Object, ValueSelected);
		EndIf;
		
		BeforePageOpen();
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.ActiveUsers.Form.ActiveUsers") Then
		
		BeforePageOpen();
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.InstallUpdates.Form.BackupSetup") Then
		
		If TypeOf(ValueSelected) = Type("Structure") Then
			FillPropertyValues(Object, ValueSelected);
		EndIf;
		
		BeforePageOpen();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SoftwareUpdateLegality" AND Not Parameter Then
		
		ToWorkClickButtonsBack();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	AvailableUpdate = ConfigurationUpdateClientDrive.GetAvailableConfigurationUpdate();
	If AvailableUpdate.UpdateSource <> -1 Then
		AvailableUpdate.FlagOfAutoTransitionToPageWithUpdate = False;
	EndIf;
	
	// Save update settings.
	SaveSettingsOfConfigurationUpdate();
	
	// Configuration update.
	If ExecuteUpdate Then
		RunConfigurationUpdate();
	EndIf;
	
	// event log record
	EventLogServerCall.WriteEventsToEventLog(ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);

EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

////////////////////////////////////////////////////////////////////////////////
// Welcome page

&AtClient
Procedure UpdateSourceOnChange(Item)
	BeforePageOpen();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// InternetConnection page

&AtClient
Procedure Decoration7URLProcessing(Item, FormattedStringURL, StandardProcessing)
		OpenForm("DataProcessor.EventLog.Form", New Structure("User", UserName()));
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// ConnectionToSite page

&AtClient
Procedure LabelInformationAboutObtainingAccessClick(Item)
	
	GotoURL(
		ConfigurationUpdateClientDrive.GetUpdateParameters().InfoAboutObtainingAccessToUserSitePageAddress);
		
EndProcedure

&AtClient
Procedure LabelOpenEventLogMonitorClick(Item)
	
	ApplicationsList = New Array;
	ApplicationsList.Add("COMConnection");
	ApplicationsList.Add("Designer");
	ApplicationsList.Add("1CV8");
	ApplicationsList.Add("1CV8C");
	
	EventLogMonitorFilter = New Structure;
	EventLogMonitorFilter.Insert("User", UserName());
	EventLogMonitorFilter.Insert("ApplicationName", ApplicationsList);
	
	OpenForm("DataProcessor.EventLog.Form", EventLogMonitorFilter);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// UpdateFile page

&AtClient
Procedure RadioButtonNeedUpdateFileOnChange(Item)
	BeforePageOpen();
EndProcedure

&AtClient
Procedure FieldUpdateFileStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	
	Dialog				= New FileDialog(FileDialogMode.Open);
	Dialog.Directory		= ConfigurationUpdateClientDrive.GetFileDir(Object.UpdateFileName);
	Dialog.CheckFileExist = True;
	Dialog.Filter		= NStr("en = 'All delivery files (*.cf*;*.cfu)|*.cf*;*.cfu|Configuration delivery files (*.cf)|*.cf|Configuration update delivery files(*.cfu)|*.cfu'; ru = 'Все файлы поставки (*.cf*;*.cfu)|*.cf*;*.cfu|Файлы поставки конфигурации (*.cf)|*.cf|Файлы поставки обновления конфигурации(*.cfu)|*.cfu';pl = 'Wszystkie pliki dostawy (*.cf*;*.cfu)|*.cf*;*.cfu|Pliki dostawy konfiguracji (*.cf)|*.cf|Pliki dostawy aktualizacji konfiguracji(*.cfu)|*.cfu';es_ES = 'Todos archivos de envío (*.cf*;*.cfu)|*.cf*;*.cfu|Archivos de envío de configuraciones(*.cf)|*.cf|Archivos de envío de la actualización de configuraciones(*.cfu)|*.cfu';es_CO = 'Todos archivos de envío (*.cf*;*.cfu)|*.cf*;*.cfu|Archivos de envío de configuraciones(*.cf)|*.cf|Archivos de envío de la actualización de configuraciones(*.cfu)|*.cfu';tr = 'Tüm  teslim dosyaları (* .cf *; *. Cfu) | * .cf *; *. cfu | Yapılandırma  teslim dosyaları (*.cf) | * .cf | Yapılandırma güncelleme teslim  dosyaları (*. cfu) | * .cfu';it = 'Tutti i file di consegna (*.cf*;*.cfu)|*.cf*;*.cfu|I file di consegna di configurazione (*.cf)|*.cf|I file della consegna di aggiornamento della configurazione(*.cfu)|*.cfu';de = 'Alle Lieferdateien(*.cf*;*.cfu)|*.cf*;*.cfu|Konfiguration Lieferdateien(*.cf)|*.cf| Konfiguration Update Lieferdateien(*.cfu)|*.cfu'");
	Dialog.Title	= NStr("en = 'Select a configuration update delivery'; ru = 'Выбор поставки обновления конфигурации';pl = 'Wybierz dostarczanie aktualizacji konfiguracji';es_ES = 'Seleccionar un envío de la actualización de configuraciones';es_CO = 'Seleccionar un envío de la actualización de configuraciones';tr = 'Bir yapılandırma güncellemesi teslimatı seçin';it = 'Selezione della consegna del aggiornamento della configurazione';de = 'Wählen Sie eine Konfigurations-Update Lieferung'");
	
	If Dialog.Choose() Then
		Object.UpdateFileName = Dialog.FullFileName;
	EndIf;
EndProcedure

&AtClient
Procedure DecorationUpdatePlatformNavigationRefDataProcessor(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("InstructionForNextEdition", True);
	OpenForm("DataProcessor.PlatformUpdateRecommended.Form.PlatformUpdateOrder", FormParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// AvailableUpdate page

&AtClient
Procedure DecorationUpdateOrderNavigationRefDataProcessor(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	DisplayUpdateOrder();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// UpdateModeSelectionFile page

&AtClient
Procedure LabelActionListClick(Item)
	FormParameters = New Structure;
	FormParameters.Insert("NoticeOfClosure", True);
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsers", , ThisObject);
EndProcedure

&AtClient
Procedure LabelActionList1Click(Item)
	FormParameters = New Structure;
	FormParameters.Insert("NoticeOfClosure", True);
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsers", , ThisObject);
EndProcedure

&AtClient
Procedure LabelActionList3Click(Item)
	FormParameters = New Structure;
	FormParameters.Insert("NoticeOfClosure", True);
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsers", , ThisObject);
EndProcedure

&AtClient
Procedure LabelBackupCopyClick(Item)
	FormParameters = New Structure;
	FormParameters.Insert("CreateBackup",           Object.CreateBackup);
	FormParameters.Insert("InfobaseBackupDirectoryName",       Object.InfobaseBackupDirectoryName);
	FormParameters.Insert("RestoreInfobase", Object.RestoreInfobase);
	OpenForm("DataProcessor.InstallUpdates.Form.BackupSetup", FormParameters, ThisObject);
EndProcedure

&AtClient
Procedure LabelUpdateOrderFileNavigationRefDataProcessor(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	DisplayUpdateOrder();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// UpdateModeSelectionServer page

&AtClient
Procedure RadioButtonUpdatesOnChange(Item)
	BeforePageOpen();
EndProcedure

&AtClient
Procedure SendReportToEMailOnChange(Item)
	BeforePageOpen();
EndProcedure

&AtClient
Procedure LabelUpdateOrderServerNavigationRefDataProcessor(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	DisplayUpdateOrder();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ButtonBackClick(Command)
	
	ToWorkClickButtonsBack();
	
EndProcedure

&AtClient
Procedure ButtonNextClick(Command)
	FlagCompleteJobs = False;
	ProcessPressOfButtonNext(FlagCompleteJobs);
	If FlagCompleteJobs Then
		ConfigurationUpdateClientOverridable.BeforeExit();
		ApplicationParameters.Insert("StandardSubsystems.SkipAlertBeforeExit", True);
		Exit(False);
		Close();
	EndIf;
EndProcedure

&AtClient
Procedure ConfigureProxyServerParameters(Command)
	OpenForm("CommonForm.ProxyServerParameters", New Structure("ProxySettingAtClient", True), ThisObject);
EndProcedure

&AtClient
Procedure NewInVersion(Command)
	
	If Not IsBlankString(FileNameInformationAboutUpdate) Then
		ConfigurationUpdateClientDrive.OpenWebPage(FileNameInformationAboutUpdate);
	Else
		ShowMessageBox(, NStr("en = 'No update information is available.'; ru = 'Информация об обновлении отсутствует.';pl = 'Nie ma Informacji o aktualizacji';es_ES = 'No hay información de actualización disponible.';es_CO = 'No hay información de actualización disponible.';tr = 'Güncelleme bilgisi mevcut değil.';it = 'Nessuna informazione di aggiornamento è disponibile.';de = 'Keine Update-Informationen verfügbar.'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Check active connections with the infobase.
//
// Returns:
//  Boolean       - True if there
//                 is a connection, False if there is no connection.
&AtServerNoContext
Function HasActiveUsers(MessagesForEventLogMonitor = Undefined)
	// Write accumulated ELM events.
	EventLogOperations.WriteEventsToEventLog(MessagesForEventLogMonitor);
	Return IBConnections.InfobaseSessionCount(False, False) > 1;
EndFunction

&AtServer
Function GetTextsOfTemplates(TemplateNames, ParametersStructure, MessagesForEventLogMonitor)
	// Write accumulated ELM events.
	EventLogOperations.WriteEventsToEventLog(MessagesForEventLogMonitor);
	Result = New Array();
	Result.Add(GetScriptText(ParametersStructure));

	TemplateNamesArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(TemplateNames);
	For Each TemplateName In TemplateNamesArray Do
		Result.Add(DataProcessors.InstallUpdates.GetTemplate(TemplateName).GetText());
	EndDo;
	Return Result;
EndFunction

&AtServer
Function GetScriptText(ParametersStructure)
	
	// Configuration update file: main.js.
	ScriptTemplate = DataProcessors.InstallUpdates.GetTemplate("TemplateOfConfigurationUpdateFile");
	
	Script = ScriptTemplate.GetArea("ParameterArea");
	Script.DeleteLine(1);
	Script.DeleteLine(Script.LineCount() - 1);
	
	Text = ScriptTemplate.GetArea("AreaUpdateConfiguration");
	Text.DeleteLine(1);
	Text.DeleteLine(Text.LineCount());
	
	Return InsertScriptParameters(Script.GetText(), ParametersStructure) + Text.GetText();
	
EndFunction

&AtServer
Function InsertScriptParameters(Val Text, Val ParametersStructure)
	
	Result = Text;
	
	If Object.CreateBackup = 2 Then
		Object.RestoreInfobase = True;
	ElsIf Object.CreateBackup = 0 Then
		Object.RestoreInfobase = False;
	EndIf;
	
	FileNamesUpdate = "";
	For Each Update In Object.AvailableUpdates Do
		FileNamesUpdate = FileNamesUpdate + DoFormat(Update.PathToLocalUpdateFile) + ",";
	EndDo;
	If StrLen(FileNamesUpdate) > 0 Then
		FileNamesUpdate = Left(FileNamesUpdate, StrLen(FileNamesUpdate) - 1);
	EndIf;
	FileNamesUpdate = "[" + FileNamesUpdate + "]";
	
	InfobaseConnectionString = ParametersStructure.ScriptParameters.InfobaseConnectionString +
											ParametersStructure.ScriptParameters.ConnectionString;
	
	If Right(InfobaseConnectionString, 1) = ";" Then
		InfobaseConnectionString = Left(InfobaseConnectionString, StrLen(InfobaseConnectionString) - 1);
	EndIf;

	NameOfExecutableDesignerFile = ParametersStructure.BinDir + ParametersStructure.NameOfExecutableDesignerFile;
	NameOfExecutableFileOfClient       = ParametersStructure.BinDir + ParametersStructure.NameOfExecutableFileOfClient;
	
	// Define a path to infobase.
	FileModeFlag = Undefined;
	InformationBasePath = IBConnectionsClientServer.InfobasePath(FileModeFlag, ParametersStructure.AdministrationParameters.ClusterPort);
	
	ParameterOfPathToInformationBase = ?(FileModeFlag, "/F", "/S") + InformationBasePath; 
	InfobasePathString	= ?(FileModeFlag, InformationBasePath, "");
	BlockIBConnections = Not ParametersStructure.FileInfobase OR SimulationModeOfClientServerIB();
	
	Result = StrReplace(Result, "[FileNamesUpdate]"					, FileNamesUpdate);
	Result = StrReplace(Result, "[NameOfExecutableDesignerFile]"	, DoFormat(NameOfExecutableDesignerFile));
	Result = StrReplace(Result, "[NameOfExecutableFileOfClient]"	, DoFormat(NameOfExecutableFileOfClient));
	Result = StrReplace(Result, "[ParameterOfPathToInformationBase]", DoFormat(ParameterOfPathToInformationBase));
	Result = StrReplace(Result, "[PathStringToInfobaseFile]"		, DoFormat(ConfigurationUpdateClientServer.AddFinalPathSeparator(StrReplace(InfobasePathString, """", "")) + "1Cv8.1CD"));
	Result = StrReplace(Result, "[InfobaseConnectionString]"		, DoFormat(InfobaseConnectionString));
	Result = StrReplace(Result, "[DirectoryBackupCopies]"			, DoFormat(?(Object.CreateBackup = 2, ConfigurationUpdateClientServer.AddFinalPathSeparator(Object.InfobaseBackupDirectoryName), "")));
	Result = StrReplace(Result, "[RestoreInfobase]"					, ?(Object.RestoreInfobase, "true", "false"));
	Result = StrReplace(Result, "[CreateBackup]"					, ?(FileModeFlag AND Object.CreateBackup <> 0, "true", "false"));
	Result = StrReplace(Result, "[EventLogEvent]"					, DoFormat(ParametersStructure.EventLogEvent));
	Result = StrReplace(Result, "[EmailAddress]"					, DoFormat(?(Object.UpdateMode = 2 AND Object.SendReportToEMail, Object.EmailAddress, "")));
	Result = StrReplace(Result, "[UpdateAdministratorName]"			, DoFormat(UserName()));
	Result = StrReplace(Result, "[BlockIBConnections]"				, ?(BlockIBConnections, "true", "false"));
	Result = StrReplace(Result, "[COMConnectorName]"				, DoFormat(ParametersStructure.COMConnectorName));
	Result = StrReplace(Result, "[UseCOMConnector]"					, ?(ParametersStructure.UseCOMConnector, "false", "true"));
	Result = StrReplace(Result, "[SessionLaunchAfterUpdate]"		, ?(Parameters.CompletingOfWorkSystem, "false", "true"));
	Result = StrReplace(Result, "[PerformIBTableCompression]"		, ?(PerformIBTableCompression(), "true", "false"));
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function DoFormat(Val Text)
	
	Text = StrReplace(Text, "\", "\\");
	Text = StrReplace(Text, """", "\""");
	Text = StrReplace(Text, "'", "\'");
	
	Return "'" + Text + "'";
	
EndFunction

&AtServerNoContext
Procedure ConfigurationUpdatesTableNewRow(TableConfigurationUpdates, Update)
	
	NewRow = TableConfigurationUpdates.Add();
	
	FillPropertyValues(NewRow, Update);
	VersionNumber = StringFunctionsClientServer.SplitStringIntoSubstringsArray(Update.Version, ".");
	NewRow.Version1Digit = Number(VersionNumber[0]);
	NewRow.Version2Digit = Number(VersionNumber[1]);
	NewRow.Version3Digit = Number(VersionNumber[2]);
	NewRow.Version4Digit = Number(VersionNumber[3]);
	
	FilePath = StringFunctionsClientServer.SplitStringIntoSubstringsArray(StrReplace(Update.PathToUpdateFile, "\", "/"), "/");
	If FilePath.Count() > 0 Then
    	NewRow.UpdateFile = FilePath[FilePath.Count() - 1];
	EndIf;
	
EndProcedure

// Receive the list of all incremental updates using the layout list which sequential setting updates the VersionFrom
// version to VersionBefore version.
//
// Parameters:
//  VersionFrom    - String - initial version.
//  VersionBefore  - String - the last version to which
// 					          the configuration is updated from the source one.
//
// Returns:
//   Array   - ValueTable string array.
&AtServer
Procedure GetAvailableUpdatesInInterval(Val VersionFrom, Val VersionBefore, FileURLTempStorage, 
	MessagesForEventLogMonitor) 

	// Write accumulated ELM events.
	EventLogOperations.WriteEventsToEventLog(MessagesForEventLogMonitor);
	TableUpdates = Undefined;
	RunImportOfListOfUpdates(FileURLTempStorage, TableUpdates);
	
	If TableUpdates = Undefined Then // errors at file reading
		Return;
	EndIf;
	
	TableConfigurationUpdates = Object.AvailableUpdates.Unload();
	TableConfigurationUpdates.Clear();
	
	TableOfAvailableUpdatesConfiguration = TableConfigurationUpdates.Copy();
	
	For Each Update In TableUpdates Do
		ConfigurationUpdatesTableNewRow(TableConfigurationUpdates, Update);
	EndDo;
	
	TableConfigurationUpdates.Sort("
		|Version1Digit Desc,
		|Version2Digit Desc,
		|Version3Digit Desc,
		|Version4Digit Desc");
	
	CurrentVersionFrom = VersionFrom;
	While CurrentVersionFrom <> VersionBefore Do
	
		Filter = New Structure("VersionForUpdate", CurrentVersionFrom);
		ArrayOfAvailableUpdates = TableConfigurationUpdates.FindRows(Filter);

		For Each Update In ArrayOfAvailableUpdates Do
			ConfigurationUpdatesTableNewRow(TableOfAvailableUpdatesConfiguration, Update);
		EndDo;

		TableOfAvailableUpdatesConfiguration.Sort("
		|Version1Digit Desc,
		|Version2Digit Desc,
		|Version3Digit Desc,
		|Version4Digit Desc");
		
		If TableOfAvailableUpdatesConfiguration.Count() = 0 Then
			Break;
		EndIf;
		
		Filter							= New Structure("Version", TableOfAvailableUpdatesConfiguration[0].Version);
		ArrayAlreadyFoundUpdates	= Object.AvailableUpdates.FindRows(Filter);
		If ArrayAlreadyFoundUpdates.Count() = 0 Then
			// add new update
			NewAvailableUpdate	= Object.AvailableUpdates.Add();
			FillPropertyValues(NewAvailableUpdate, TableOfAvailableUpdatesConfiguration[0]);
		ElsIf IsBlankString(ArrayAlreadyFoundUpdates[0].PathToLocalUpdateFile) Then
			// Update the information in the already found update.
			FillPropertyValues(ArrayAlreadyFoundUpdates[0], TableOfAvailableUpdatesConfiguration[0]);
		EndIf;
		NewCurrentVersionFrom = TableOfAvailableUpdatesConfiguration[0].Version;
		If CurrentVersionFrom = NewCurrentVersionFrom AND NewCurrentVersionFrom <> VersionBefore Then
			TableOfAvailableUpdatesConfiguration.Clear();
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Update to version %1 from the current version %2 is not available'; ru = 'Недоступно обновление на версию %1 с текущей версии %2';pl = 'Aktualizacja do wersji %1 z bieżącej wersji %2 jest niedostępna';es_ES = 'Actualización a la versión %1 de la versión actual %2 no se encuentra disponible';es_CO = 'Actualización a la versión %1 de la versión actual %2 no se encuentra disponible';tr = 'Mevcut sürümden%1 üst sürüme %2 güncelleme mevcut değil';it = 'Aggiornamento alla versione %1 rispetto alla versione corrente %2 non è disponibile';de = 'Update auf Version %1 von der aktuellen Version %2 ist nicht verfügbar'"), VersionBefore, VersionFrom);
		EndIf;
		CurrentVersionFrom	= NewCurrentVersionFrom;
	
	EndDo;
	
EndProcedure

// Update list importing from XML file.
&AtServerNoContext
Procedure RunImportOfListOfUpdates(Val ImportFileAddress, TableUpdates = Undefined)
	
	FullPathFileExport = ImportFileAddress;
	If IsTempStorageURL(ImportFileAddress) Then
		FullPathFileExport = StrReplace(GetTempFileName(), ".tmp", ".xml");
		FileData = GetFromTempStorage(ImportFileAddress);
		FileData.Write(FullPathFileExport);
	EndIf;
	
	ErrorInfo = NStr("en = 'An error occurred when reading the update list file'; ru = 'Ошибка при чтении файла списка обновлений';pl = 'Błąd podczas odczytu pliku listy aktualizacji';es_ES = 'Ha ocurrido un error al leer el archivo de la lista de actualizaciones';es_CO = 'Ha ocurrido un error al leer el archivo de la lista de actualizaciones';tr = 'Güncelleme listesi dosyası okunurken hata oluştu';it = 'Si è verificato un errore durante la lettura del file di elenco aggiornamento';de = 'Beim Lesen der Update List-Datei ist ein Fehler aufgetreten'") + " " + FullPathFileExport;
	If Not FileExistsAtServer(FullPathFileExport) Then
		Raise ErrorInfo;
	EndIf;
	
	TableUpdates = New ValueTable;
	// Main columns
	TableUpdates.Columns.Add("Configuration"			, Common.StringTypeDetails(0));
	TableUpdates.Columns.Add("Vendor"				, Common.StringTypeDetails(0));
	TableUpdates.Columns.Add("Version"					, Common.StringTypeDetails(0));
	TableUpdates.Columns.Add("VersionForUpdate"	, Common.StringTypeDetails(0));
	TableUpdates.Columns.Add("PathToUpdateFile"	, Common.StringTypeDetails(0));
	TableUpdates.Columns.Add("ITSDiskNumber"			, Common.StringTypeDetails(0));
	TableUpdates.Columns.Add("PlatformVersion"		, Common.StringTypeDetails(0));
	TableUpdates.Columns.Add("UpdateFileSize"	, Common.TypeDescriptionNumber(15, 0));
	
	XMLReader = New XMLReader;
	XMLReader.OpenFile(FullPathFileExport);
	XMLReader.Read();  
	
	// File generation date.
	XMLReader.Read();
	XMLReader.Read();
	GeneratingDate = XMLReader.Value;
	XMLReader.Read();
	
	// Read the Update item beginning or the UpdateList item end.
	While XMLReader.Read() Do
		
		If XMLReader.Name = "v8u:updateList" Then
			Break;
		EndIf;
		Vendor				= "";
		Version					= "";
		PathToUpdateFile	= "";
		ITSDiskNumber			= "";
		UpdateFileSize	= 0;
		Configuration			= StringFunctionsClientServer.RemoveDoubleQuotationMarks(TrimAll(XMLReader.GetAttribute("configuration")));
		PlatformVersion = Undefined;
		
		// Read update item content.
		VersionsArrayForUpdate = New Array;
		While XMLReader.Read() Do
			If XMLReader.Name = "v8u:update" Then
				Break;
			EndIf;
			If XMLReader.Name = "v8u:vendor" Then
				XMLReader.Read();
				Vendor = StringFunctionsClientServer.RemoveDoubleQuotationMarks(TrimAll(XMLReader.Value));
			ElsIf XMLReader.Name = "v8u:version" Then
				PlatformVersion = XMLReader.GetAttribute("platform");
				XMLReader.Read();
				Version = XMLReader.Value;
			ElsIf XMLReader.Name = "v8u:file" Then
				XMLReader.Read();
				PathToUpdateFile = StringFunctionsClientServer.RemoveDoubleQuotationMarks(TrimAll(XMLReader.Value));
			ElsIf XMLReader.Name = "v8u:size" Then
				XMLReader.Read();
				UpdateFileSize = StringFunctionsClientServer.RemoveDoubleQuotationMarks(TrimAll(XMLReader.Value));
			ElsIf XMLReader.Name = "v8u:its" Then
				XMLReader.Read();
				ITSDiskNumber = StringFunctionsClientServer.RemoveDoubleQuotationMarks(TrimAll(XMLReader.Value));
			ElsIf XMLReader.Name = "v8u:target" Then
				XMLReader.Read();
				VersionsArrayForUpdate.Add(XMLReader.Value);
			EndIf;
			
			XMLReader.Read();
		EndDo;
		
		// Create update table.
		For Each VersionForUpdate In VersionsArrayForUpdate Do
			
			NewRow = TableUpdates.Add();
			NewRow.Configuration			= Configuration;
			NewRow.Vendor				= Vendor;
			NewRow.Version					= Version;
			NewRow.VersionForUpdate		= VersionForUpdate;
			NewRow.PathToUpdateFile	= PathToUpdateFile;
			NewRow.ITSDiskNumber			= ITSDiskNumber;
			NewRow.UpdateFileSize	= UpdateFileSize;
			NewRow.PlatformVersion			= PlatformVersion;

		EndDo;
		
	EndDo;
	XMLReader.Close();
	
	If TableUpdates = Undefined Then // errors at file reading
		Raise NStr("en = 'An error occurred when reading the file'; ru = 'Ошибка при чтении файла';pl = 'Błąd podczas odczytu pliku';es_ES = 'Ha ocurrido un error al leer el archivo';es_CO = 'Ha ocurrido un error al leer el archivo';tr = 'Dosya okunurken bir hata oluştu';it = 'Si è verificato un errore durante la lettura del file';de = 'Beim Lesen der Datei ist ein Fehler aufgetreten'") + " " + FullPathFileExport;
   	EndIf;
	
EndProcedure

&AtServerNoContext
Function FileExistsAtServer(Val PathToFile)
	File = New File(PathToFile);
	Return File.Exist();
EndFunction

&AtServerNoContext
Function ScriptDebugMode()
	Result = False;
	StructureSettings = Common.CommonSettingsStorageLoad(
		"ConfigurationUpdate", 
		"ConfigurationUpdateOptions");
	If StructureSettings <> Undefined Then 
		StructureSettings.Property("ScriptDebugMode", Result);
	EndIf;
	Return Result = True;
EndFunction

&AtServerNoContext
Function SimulationModeOfClientServerIB()
	Result = False;
	StructureSettings = Common.CommonSettingsStorageLoad(
		"ConfigurationUpdate", 
		"ConfigurationUpdateOptions");
	If StructureSettings <> Undefined Then 
		StructureSettings.Property("SimulationModeOfClientServerIB", Result);
	EndIf;
	Return Result = True;
EndFunction

&AtClient
Procedure SaveSettingsOfConfigurationUpdate()
	
	ClientWorkParameters = ConfigurationUpdateClientCachedDrive.ClientWorkParameters();
	
	ParameterName = "StandardSubsystems.ConfigurationUpdateOptions";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	Settings = ConfigurationUpdateClientServer.GetUpdatedConfigurationUpdateSettings(ApplicationParameters[ParameterName]);
	
	Settings.UpdateServerUserCode = Object.UpdateServerUserCode;
	Settings.UpdatesServerPassword = ?(Object.SaveUpdatesServerPassword, Object.UpdatesServerPassword, "");
	Settings.SaveUpdatesServerPassword = Object.SaveUpdatesServerPassword;
	
	Settings.CheckUpdateExistsOnStart = Object.CheckUpdateExistsOnStart;
	Settings.ScheduleOfUpdateExistsCheck = CommonClientServer.ScheduleToStructure(Object.ScheduleOfUpdateExistsCheck);
	Settings.UpdateSource = Object.UpdateSource;
	Settings.UpdateMode = Object.UpdateMode;
	Settings.UpdateDateTime = Object.UpdateDateTime;
	Settings.SendReportToEMail = Object.SendReportToEMail;
	Settings.EmailAddress = Object.EmailAddress;
	Settings.SchedulerTaskCode = Object.SchedulerTaskCode;
	Settings.SecondStart = Object.SecondStart;
	Settings.UpdateFileName = Object.UpdateFileName;
	Settings.NeedUpdateFile = Object.NeedUpdateFile;
	
	Settings.CreateBackup = Object.CreateBackup;
	Settings.RestoreInfobase = Object.RestoreInfobase;
	Settings.InfobaseBackupDirectoryName = Object.InfobaseBackupDirectoryName;
	
	Settings.ServerAddressForVerificationOfUpdateAvailability = ClientWorkParameters.UpdateSettings.ServerAddressForVerificationOfUpdateAvailability;
	Settings.UpdatesDirectory = ClientWorkParameters.UpdateSettings.UpdatesDirectory;
	Settings.ConfigurationShortName = ClientWorkParameters.UpdateSettings.ConfigurationShortName;
	Settings.AddressOfResourceForVerificationOfUpdateAvailability = ClientWorkParameters.UpdateSettings.AddressOfResourceForVerificationOfUpdateAvailability;
	
	ConfigurationUpdateServerCallDrive.WriteStructureOfAssistantSettings(
		ApplicationParameters["StandardSubsystems.ConfigurationUpdateOptions"]);
	
EndProcedure

&AtClient
Procedure RestoreSettingsUpdateConfigurations()
	
	Object.RestoreInfobase = True;
	
	// Restoration settings
	ParameterName = "StandardSubsystems.ConfigurationUpdateOptions";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, ConfigurationUpdateServerCallDrive.GetSettingsStructureOfAssistant());
		ConfigurationUpdateClientServer.GetUpdatedConfigurationUpdateSettings(ApplicationParameters[ParameterName]);
	EndIf;
	FillPropertyValues(Object, ApplicationParameters[ParameterName]);
	
	If AuthenticationParameters <> Undefined
		AND Not IsBlankString(AuthenticationParameters.Login)
		AND Not IsBlankString(AuthenticationParameters.Password) Then
		
		Object.UpdateServerUserCode = AuthenticationParameters.Login;
		Object.UpdatesServerPassword = AuthenticationParameters.Password;
		
	EndIf;
	
	Object.ScheduleOfUpdateExistsCheck = CommonClientServer.StructureToSchedule(Object.ScheduleOfUpdateExistsCheck);
	ClientWorkParameters = ConfigurationUpdateClientCachedDrive.ClientWorkParameters();
	If ClientWorkParameters.FileInfobase AND Object.UpdateMode > 1 Then
		Object.UpdateMode = 0;
	EndIf;
	
	If ConfigurationChanged Then
		UpdateParameters = ConfigurationUpdateClientDrive.GetAvailableConfigurationUpdate();
		UpdateParameters.UpdateSource = 2;  // Local or network directory.
		UpdateParameters.NeedUpdateFile = False;
		UpdateParameters.FlagOfAutoTransitionToPageWithUpdate = True;
	EndIf;
	
	If Parameters.CompletingOfWorkSystem Then
		Object.UpdateMode = 0;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforePageOpen(NewCurrentPage = Undefined)
	
	ParameterName = "StandardSubsystems.MessagesForEventLogMonitor";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New ValueList);
	EndIf;
	
	Pages = Items.AssistantPages.ChildItems;
	If NewCurrentPage = Undefined Then
		NewCurrentPage = Items.AssistantPages.CurrentPage;
	EndIf;
	
	ButtonBackAvailability		= True;
	EnabledButtonsNextStep		= True;
	EnabledButtonsClose	= True;
	NextButtonFunction			= True; // True = "GoToNext", False = "Done"
	
	If NewCurrentPage = Pages.Welcome Then
		ButtonBackAvailability = False;
	ElsIf NewCurrentPage = Pages.ConnectionToSite Then
		
		ErrorsPaneVisibleConnection = ? (ValueIsFilled(Object.UpdateServerUserCode) 
			OR ValueIsFilled(Object.UpdatesServerPassword), True, False);
														
		Items.PanelErrorConnection.Visible = ErrorsPaneVisibleConnection;
		Items.PanelEventLogMonitor.Visible = ErrorsPaneVisibleConnection;
		If ConfigurationUpdateClientCachedDrive.ClientWorkParameters().ThisIsBasicConfigurationVersion Then
			Items.AccessGroupOnSite.CurrentPage = Items.AccessGroupOnSite.ChildItems.Basic;
		EndIf;
		
		If Not IsBlankString(Object.TechnicalErrorInfo) Then
			Object.TechnicalErrorInfo = NStr("en = 'Technical information on the error:'; ru = 'Техническая информация об ошибке:';pl = 'Informacja techniczna o błędzie:';es_ES = 'Información técnica sobre el error:';es_CO = 'Información técnica sobre el error:';tr = 'Hata ile ilgili teknik bilgiler:';it = 'Le informazioni tecniche sull''errore:';de = 'Technische Informationen zum Fehler:'") + Chars.LF + Object.TechnicalErrorInfo;
		EndIf;
		
	ElsIf NewCurrentPage = Pages.AvailableUpdate Then
		
		AvailableUpdateStructure = GetAvailableUpdate(True);
		If AvailableUpdateStructure <> Undefined Then
			Items.NewInVersion.Visible = Not IsBlankString(FileNameInformationAboutUpdate);
			Items.LabelAvailableUpdate.Title = AvailableUpdateStructure.Version;
			Items.LabelSizeUpdates.Title = AvailableUpdateStructure.SizeUpdate;
			Items.DecorationUpdateOrder.Visible = Not IsBlankString(FileNameOrderUpdate);
			PlatformUpdateIsNeeded = PlatformUpdateIsNeeded(AvailableUpdateStructure.PlatformVersion);
			If AvailableUpdateForNextEdition Or PlatformUpdateIsNeeded Then
				
				PlatformVersion = ?(PlatformUpdateIsNeeded, AvailableUpdateStructure.PlatformVersion,
					ConfigurationUpdateClientDrive.PlatformNextEdition());
				CaptionPattern = NStr("en = 'To update this version 1C:Enterprise platform
				                      |higher than <b>%1<b> version is required. It is required to <a href = ""HowToUpdatePlatform>update to a new platform version</a>, after that you can install this update.'; 
				                      |ru = 'Для обновления на эту версию требуется платформа 1С:Предприятие
				                      |не ниже версии <b>%1<b>. Необходимо <a href = ""HowToUpdatePlatform>перейти на новую версию платформы</a>, после чего можно будет установить это обновление.';
				                      |pl = 'W celu aktualizacji tej wersji wymagana jest platforma 1C:Enterprise 
				                      |starsza niż wersja <b>%1<b>. Wymagana jest <a href = ""HowToUpdatePlatform> aktualizacja do nowej wersji platformy </a>, dalej możesz zainstalować tę aktualizację.';
				                      |es_ES = 'Para actualizar esta versión, se requiere la versión <b>%1<b> más alta de
				                      |la plataforma de la 1C:Empresa. Se requiere actualizar a <a href = ""HowToUpdatePlatform> a una nueva versión de la plataforma</a>, después, usted puede instalar esta actualización.';
				                      |es_CO = 'Para actualizar esta versión, se requiere la versión <b>%1<b> más alta de
				                      |la plataforma de la 1C:Empresa. Se requiere actualizar a <a href = ""HowToUpdatePlatform> a una nueva versión de la plataforma</a>, después, usted puede instalar esta actualización.';
				                      |tr = 'Bu sürümü güncelleyebilmek için 1C:Enterprise platformunun
				                      |<b>%1<b> veya daha yeni sürümü gerekiyor. <a href = ""HowToUpdatePlatform>Platform sürümü güncellendikten sonra</a> bu güncellemeyi yükleyebilirsiniz.';
				                      |it = 'Per aggiornare questa versione della piattaforma 1C:Enterprise
				                      |una versione <b>%1<b>successiva è richiesta. Si richiede di <a href = ""HowToUpdatePlatform>aggiornare la nuova versione della piattaforma</a>dopo l''installazione di questo aggiornamento.';
				                      |de = 'So aktualisieren Sie diese Version 1C:Enterprise Plattform
				                      |höher als <b>%1<b>Version erforderlich ist. Es ist erforderlich, <a href = ""HowToUpdatePlatform>auf eine neue Plattformversion zu aktualisieren</a>, danach können Sie dieses Update installieren.'");
				TitleString = StringFunctionsClientServer.SubstituteParametersToString(CaptionPattern, AvailableUpdateStructure.PlatformVersion);
				Items.DecorationUpdatePlatform.Title = StringFunctionsClientServer.FormattedString(TitleString);
				
				Items.DecorationUpdatePlatform.Visible = True;
				EnabledButtonsNextStep = False;
				EnabledButtonsClose = True;
			Else
				Items.DecorationUpdatePlatform.Visible = False;
				Items.DecorationUpdateOrder.Height = 2;
			EndIf;
			
			If IsBlankString(FileNameOrderUpdate) AND Not (AvailableUpdateForNextEdition Or PlatformUpdateIsNeeded) Then
				Items.GroupAdditionalInformation.Visible = False;
			EndIf;
			
		EndIf;
		
	ElsIf NewCurrentPage = Pages.UpdatesNotDetected Then
		
		AvailableUpdateStructure	= GetAvailableUpdate();
		NextButtonFunction										= False;
		EnabledButtonsNextStep									= False;
		Items.LabelDetailsCurrentConfiguration.Title	= ConfigurationUpdateClientCachedDrive.ClientWorkParameters().ConfigurationSynonym;
		Items.LabelVersionCurrentConfiguration.Title		= ConfigurationUpdateClientCachedDrive.ClientWorkParameters().ConfigurationVersion;
		Items.InscriptionVersionForUpdate.Title			= ?(TypeOf(AvailableUpdateStructure) = Type("Structure"), NStr("en = 'Version available for update -'; ru = 'Доступная версия для обновления -';pl = 'Dostępna wersja dla aktualizacji -';es_ES = 'Versión disponible para actualizar -';es_CO = 'Versión disponible para actualizar -';tr = 'Güncelleme için mevcut sürüm -';it = 'Versione disponibile per l''aggiornamento -';de = 'Version für Update verfügbar -'") + " " + AvailableUpdateStructure.Version, "");
		Items.InscriptionVersionForUpdate.Visible			= Not IsBlankString(Items.InscriptionVersionForUpdate.Title);
		
		If CommonClientServer.CompareVersions(ConfigurationUpdateClientCachedDrive.ClientWorkParameters().ConfigurationVersion,
			LastConfigurationVersion) >= 0
			Or AvailableUpdateStructure <> Undefined
			Or (Object.UpdateSource = 0 AND Object.AvailableUpdates.Count() = 0) Then // this is the last version.
			
			Items.PanelInformationAboutUpdate.CurrentPage = Items.PanelInformationAboutUpdate.ChildItems.RefreshEnabledNotNeeded;
			Items.GroupUpdateIsNotDetected.Title = NStr("en = 'No update required'; ru = 'Обновление не требуется';pl = 'Aktualizacja nie jest potrzebna';es_ES = 'No se requiere una actualización';es_CO = 'No se requiere una actualización';tr = 'Güncelleme gerekmiyor';it = 'Nessun aggiornamento richiesto';de = 'Aktualisierung nicht erforderlich'");
		ElsIf ConfigurationUpdateClientCachedDrive.ClientWorkParameters().MasterNode <> Undefined Then
			Items.PanelInformationAboutUpdate.CurrentPage = Items.UpdatePerformedAtMainNode;
			Items.GroupUpdateIsNotDetected.Title = NStr("en = 'No update required'; ru = 'Обновление не требуется';pl = 'Aktualizacja nie jest potrzebna';es_ES = 'No se requiere una actualización';es_CO = 'No se requiere una actualización';tr = 'Güncelleme gerekmiyor';it = 'Nessun aggiornamento richiesto';de = 'Aktualisierung nicht erforderlich'");
		Else 
			Items.PanelInformationAboutUpdate.CurrentPage = Items.PanelInformationAboutUpdate.ChildItems.RefreshEnabledIsNotFound;
			Items.GroupUpdateIsNotDetected.Title = NStr("en = 'Configuration update is not detected'; ru = 'Обновления конфигурации не обнаружено';pl = 'Aktualizację konfiguracji nie znaleziono';es_ES = 'Actualización de configuraciones no se ha detectado';es_CO = 'Actualización de configuraciones no se ha detectado';tr = 'Yapılandırma güncellemesi algılanmadı';it = 'Nessun aggiornamento della configurazione trovato';de = 'Konfigurationsaktualisierung wurde nicht erkannt'");
		EndIf;
		
		If Not ConfigurationUpdateClientCachedDrive.ClientWorkParameters().IsMasterNode Then
			ButtonBackAvailability = False;
		EndIf;
		
	ElsIf NewCurrentPage = Pages.LongAction Then
		
		EnabledButtonsNextStep = False;
		ButtonBackAvailability = False;
		EnabledButtonsClose = False;
		
	ElsIf NewCurrentPage = Pages.CaseUpdateFile Then
		
		NextButtonFunction = (Object.UpdateMode = 0);// If it is NOT updated now, then Finish.
		
		Items.UpdateOrderFile.Visible = Not IsBlankString(FileNameOrderUpdate);
		
		ConnectionsInfo = IBConnectionsServerCall.ConnectionsInformation(False, ApplicationParameters["StandardSubsystems.MessagesForEventLog"]);
		Items.GroupConnections.Visible = ?(ConnectionsInfo.HasActiveUsers, True, False);
			
		If ConnectionsInfo.HasActiveUsers Then
			AllPages = Items.PanelActiveUsers.ChildItems;
			EnabledButtonsNextStep	= True;
			If ConnectionsInfo.HasCOMConnections Then
				Items.PanelActiveUsers.CurrentPage = AllPages.ActiveConnection;
			ElsIf ConnectionsInfo.HasDesignerConnection Then
				Items.PanelActiveUsers.CurrentPage = AllPages.ConnectionConfigurator;
			Else
				Items.PanelActiveUsers.CurrentPage = AllPages.ActiveUsers;
			EndIf;
		EndIf;
		
		Items.LabelBackupFile.Title = LabelTextInfobaseBackup();
		
		If Not ConfigurationUpdateClientCachedDrive.ClientWorkParameters().IsMasterNode Then
			ButtonBackAvailability = False;
		EndIf;
	ElsIf NewCurrentPage = Pages.UpdateModeChoiceServer Then

		If Object.SchedulerTaskCode = 0 AND Not UpdateDateTimeIsSet Then
			Object.UpdateDateTime		= ReturnDate(ConfigurationUpdateClientServer.AddDays(
				BegOfDay(CommonClient.SessionDate()), 1), Object.UpdateDateTime);
			UpdateDateTimeIsSet	= True;
		EndIf; 
		
		NextButtonFunction = (Object.UpdateMode = 0);// If it is NOT updated now, then Finish.
		
		Items.UpdateOrderServer.Visible = Not IsBlankString(FileNameOrderUpdate);
		
		PanelPagesInformationReboot1						= Items.PagesInformationReboot1.ChildItems;
		Items.PagesInformationReboot1.CurrentPage	= ?(Object.UpdateMode = 0,
			PanelPagesInformationReboot1.PageRebootNow1,
			PanelPagesInformationReboot1.ScheduledRebootPage);
		
		ConnectionsInfo = IBConnectionsServerCall.ConnectionsInformation(False, ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
		AvailabilityOfConnections	= ConnectionsInfo.HasActiveUsers AND NextButtonFunction; 
		Items.ConnectionsGroup1.Visible = AvailabilityOfConnections;
		If AvailabilityOfConnections Then
			AllPages = Items.PanelActiveUsers1.ChildItems;
			Items.PanelActiveUsers1.CurrentPage = ? (ConnectionsInfo.COMConnectionsExist, 
				AllPages.ActiveConnection1, AllPages.ActiveUsers1);
		EndIf;
			
		Items.FieldUpdateDateTime.Enabled = (Object.UpdateMode = 2);
		Items.EmailAddress.Enabled	= Object.SendReportToEMail;
		
		If Not ConfigurationUpdateClientCachedDrive.ClientWorkParameters().IsMasterNode Then
			ButtonBackAvailability = False;
		EndIf;
	ElsIf NewCurrentPage = Pages.SuccessfulRefresh Then
		
		GetToKnowAdditionalInstructions = Not IsBlankString(FileNameOrderUpdate);
		ShowNewInVersion = Not GetToKnowAdditionalInstructions;
		Items.GetToKnowAdditionalInstructions.Visible = GetToKnowAdditionalInstructions;
		NextButtonFunction = False;
		ButtonBackAvailability = False;
		EnabledButtonsClose = False;
		
	ElsIf NewCurrentPage = Pages.FailureRefresh Then
		
		NextButtonFunction = False;
		EnabledButtonsClose = False;
		
	ElsIf NewCurrentPage = Pages.UpdateFile Then
		
		If Object.NeedUpdateFile = 0 Then
			If ConfigurationChanged Then
				Items.PagesConfigurationChangedInscriptions.CurrentPage = Items.PagesConfigurationChangedInscriptions.ChildItems.HasChanges;
			Else
				Items.PagesConfigurationChangedInscriptions.CurrentPage = Items.PagesConfigurationChangedInscriptions.ChildItems.NoneChanges;
				EnabledButtonsNextStep = False;
			EndIf;
		EndIf;
		Items.PanelUpdateFromMainConfiguration.Visible	= Object.NeedUpdateFile = 0;
		Items.FieldUpdateFile.Enabled						= Object.NeedUpdateFile = 1;
		Items.FieldUpdateFile.AutoMarkIncomplete		= Object.NeedUpdateFile = 1;
		
	EndIf;
	
	If ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"].Count() > 0 Then
		// It is necessary to record the log on pages with errors.
		EventLogServerCall.WriteEventsToEventLog(ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
	EndIf;
	
	ButtonNext		= Items.ButtonNext;
	ButtonBack		= Items.ButtonBack;
	CloseButton	= Items.CloseButton;
	ButtonBack.Enabled		= ButtonBackAvailability;
	ButtonNext.Enabled		= EnabledButtonsNextStep;
	CloseButton.Enabled	= EnabledButtonsClose;
	If EnabledButtonsNextStep Then
		If Not ButtonNext.DefaultButton Then
			ButtonNext.DefaultButton = True;
		EndIf;
	ElsIf EnabledButtonsClose Then
		If Not CloseButton.DefaultButton Then
			CloseButton.DefaultButton = True;
		EndIf;
	EndIf;
	
	ButtonNext.Title = ?(NextButtonFunction, NStr("en = 'Next >'; ru = 'Далее >';pl = 'Dalej >';es_ES = 'Siguiente >';es_CO = 'Siguiente >';tr = 'Sonraki >';it = 'Avanti >';de = 'Weiter >'"), NStr("en = 'Finish'; ru = 'Готово';pl = 'Koniec';es_ES = 'Finalizar';es_CO = 'Finalizar';tr = 'Bitiş';it = 'Termina';de = 'Abschluss'"));
	
	If NewCurrentPage = Pages.LongAction Then
		AttachIdleHandler("RunUpdateObtaining", 1, True);
	EndIf;

EndProcedure

&AtClient
Function RestoreResultsOfPreviousStart(Cancel = False)
	
	Pages	= Items.AssistantPages.ChildItems;
	RestorationOfPreLaunch = True;
	PageName	= ProcessPageWelcome(False);
	Processed	= 	PageName = Pages.AvailableUpdate.Name Or
				 	PageName = Pages.UpdateModeChoiceServer.Name Or
				 	PageName = Pages.CaseUpdateFile.Name;

	RestorationOfPreLaunch = False;
	If Not Processed Then
		Cancel = True;
		Return PageName;
	EndIf;

	If PageName = Pages.AvailableUpdate.Name Then
		FileListForObtaining.LoadValues(CreateFileListForObtaining());
		If CheckUpdateFilesReceived() Then
			NameLogEvents = ConfigurationUpdateClient.EventLogEvent();
			
			EventLogClient.AddMessageForEventLog(NameLogEvents, "Information",
				NStr("en = 'Configuration update files have already been received and saved locally.'; ru = 'Обнаружено, что файлы обновления конфигурации уже были получены и сохранены локально.';pl = 'Pliki aktualizacji konfiguracji zostały już odebrane i zapisane lokalnie.';es_ES = 'Archivos de la actualización de configuraciones ya se han recibido y guardado a nivel local.';es_CO = 'Archivos de la actualización de configuraciones ya se han recibido y guardado a nivel local.';tr = 'Yapılandırma güncelleme dosyaları zaten alınmış ve yerel olarak kaydedilmiştir.';it = 'I file di aggiornamento della configurazione sono stati già ricevuti e salvati localmente.';de = 'Konfigurationsaktualisierungsdateien wurden bereits empfangen und lokal gespeichert.'"));
				
			GoToChoiceOfUpdateMode();
			Return Undefined;
		EndIf;
	EndIf;
	
	Return PageName;
	
EndFunction

&AtClient
Function ProcessPageWelcome(OutputMessages = True)
	ClearAvailableUpdates = True;
	If Object.UpdateSource = 0 Then
		Return CheckUpdateInternet(OutputMessages);
	ElsIf Object.UpdateSource = 2 Then
		Return CheckUpdateFile(OutputMessages);
	EndIf;
	Return Undefined;
EndFunction

&AtClient
Function ProcessPageConnectionToInternet(OutputMessages = True)
	Pages		= Items.AssistantPages.ChildItems;
	Object.TechnicalErrorInfo = "";
	If FileListForObtaining.Count() > 0 Then
		Return Pages.LongActions.Name;
	ElsIf Object.AvailableUpdates.Count() > 0 Then
		Return Pages.AvailableUpdate.Name;
	EndIf;
		
	Return ?(Object.AvailableUpdates.Count() = 0, CheckUpdateInternet(OutputMessages), Pages.ConnectionToSite.Name);
EndFunction

&AtClient
Function ProcessPageConnectionToSite(OutputMessages = True)
	Pages		= Items.AssistantPages.ChildItems;
	Object.TechnicalErrorInfo = "";
	If Not ValueIsFilled(Object.UpdateServerUserCode) Then
		If OutputMessages Then
			ShowMessageBox(, NStr("en = 'Specify a user code for update.'; ru = 'Укажите код пользователя для обновления.';pl = 'Określ kod użytkownika do aktualizacji.';es_ES = 'Especificar un código de usuario para actualizar.';es_CO = 'Especificar un código de usuario para actualizar.';tr = 'Güncelleme için bir kullanıcı kodu belirtin.';it = 'Specificare un codice utente per l''aggiornamento.';de = 'Geben Sie einen Benutzercode für die Aktualisierung an.'"));
		EndIf;
		CurrentItem = Items.UpdateServerUserCode;
		Return Pages.ConnectionToSite.Name;
	EndIf;
	
	If Not ValueIsFilled(Object.UpdatesServerPassword) Then
		If OutputMessages Then
			ShowMessageBox(, NStr("en = 'Specify a user password for update.'; ru = 'Укажите пароль пользователя для обновления.';pl = 'Określ hasło użytkownika do aktualizacji.';es_ES = 'Especificar una contraseña de usuario para actualizar.';es_CO = 'Especificar una contraseña de usuario para actualizar.';tr = 'Güncelleme için bir kullanıcı şifresi belirtin.';it = 'Specificare una password utente per l''aggiornamento.';de = 'Geben Sie ein Benutzerkennwort für das Update an.'"));
		EndIf;
		CurrentItem = Items.UpdatesServerPassword;
		Return Pages.ConnectionToSite.Name;
	EndIf;
	
	If FileListForObtaining.Count() > 0 Then
		Return Pages.LongActions.Name;
	ElsIf Object.AvailableUpdates.Count() > 0 Then
		Return Pages.AvailableUpdate.Name;
	EndIf;
	
	Return CheckUpdateInternet(OutputMessages);
EndFunction

&AtClient
Function ProcessPageLongOperation(OutputMessages = True)
	Return ResultGetFiles;
EndFunction

&AtClient
Function ProcessPageChoiceUpdateMode(OutputMessages = True, FlagCompleteJobs = False)
	CurrentPage = Items.AssistantPages.CurrentPage;
	
	FileInfobase = ConfigurationUpdateClientCachedDrive.ClientWorkParameters().FileInfobase;
	ExecuteUpdate = False;
	
	If FileInfobase AND Not SimulationModeOfClientServerIB() AND Object.CreateBackup = 2 Then
		
		File = New File(Object.InfobaseBackupDirectoryName);
		If Not File.Exist() Or Not File.IsDirectory() Then
			ShowMessageBox(, NStr("en = 'Specify an existing directory to save the IB backup.'; ru = 'Укажите существующий каталог для сохранения резервной копии ИБ.';pl = 'Wskaż istniejący katalog dla zachowania kopii zapasowej BI.';es_ES = 'Especificar un directorio existente para guardar la copia de respaldo de la infobase.';es_CO = 'Especificar un directorio existente para guardar la copia de respaldo de la infobase.';tr = 'IB yedeğini kaydetmek için varolan bir dizini belirtin.';it = 'Indicare una directory esistente per salvare il backup dell''infobase.';de = 'Geben Sie ein vorhandenes Verzeichnis an, um die IB-Sicherung zu speichern.'"));
		EndIf;
		
		Return CurrentPage.Name;
		
	EndIf;
	
	If Object.UpdateMode = 0 Then   // Update now
		If FileInfobase AND Not SimulationModeOfClientServerIB() Then
			AvailabilityOfConnections = HasActiveUsers(ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
			If AvailabilityOfConnections Then
				ShowMessageBox(, NStr("en = 'The configuration update cannot proceed as connections with infobase were not terminated.'; ru = 'Невозможно продолжить обновление конфигурации, так как не завершены все соединения с информационной базой.';pl = 'Nie można kontynuować aktualizacji konfiguracji, ponieważ nie zostały zakończone wszystkie połączenia z bazą informacyjną.';es_ES = 'Esta actualización de configuraciones no puede procederse porque las conexiones con la infobase no se han finalizado.';es_CO = 'Esta actualización de configuraciones no puede procederse porque las conexiones con la infobase no se han finalizado.';tr = 'Infobase ile bağlantılar sonlandırılmadığından yapılandırma güncellemesi devam edemiyor.';it = 'L''aggiornamento configurazione non può procedere dato che collegamenti con infobase non sono stati chiusi.';de = 'Das Konfigurationsupdate kann nicht fortgesetzt werden, da Verbindungen mit der Infobase nicht beendet wurden.'"));
				Return CurrentPage.Name;
			EndIf; 
		EndIf;
		ExecuteUpdate		= True;
		FlagCompleteJobs	= True;
		Return CurrentPage.Name;
	ElsIf Object.UpdateMode = 1 Then  // On closing application
		
	ElsIf Object.UpdateMode = 2 Then  // Plan update
		If Not CheckValidUpdateDate(Object.UpdateDateTime, OutputMessages) Then
			CurrentItem = Items.FieldUpdateDateTime;
			Return CurrentPage.Name;
		EndIf;
		If Object.SendReportToEMail Then
			NameNewPages = CheckEMailSettings(CurrentPage.Name, OutputMessages);
			If Not IsBlankString(NameNewPages) Then
				Return NameNewPages;
			EndIf;
		EndIf;
		
		If Not WMIInstalled(OutputMessages) Then
			Return CurrentPage.Name;
		EndIf;
		
		If Not PlanConfigurationChange() Then
			ShowMessageBox(, NStr("en = 'It is impossible to schedule the configuration update. Error information is saved in the log.'; ru = 'Невозможно запланировать обновление конфигурации. Сведения об ошибке сохранены в журнал регистрации.';pl = 'Niemożliwe jest zaplanowanie aktualizacji konfiguracji. Informacje o błędach są zapisywane w dzienniku.';es_ES = 'Es imposible programar la actualización de configuraciones. Información del error se ha guardado en el registro.';es_CO = 'Es imposible programar la actualización de configuraciones. Información del error se ha guardado en el registro.';tr = 'Yapılandırma güncellemesini programlamak mümkün değildir. Hata bilgileri günlüğe kaydedilir.';it = 'Impossibile programmare l''aggiornamento della configurazione. Le informazioni sull''errore sono state salvate nel registro eventi.';de = 'Es ist nicht möglich, das Konfigurationsupdate zu planen. Fehlerinformationen werden im Protokoll gespeichert.'"));
			Return CurrentPage.Name;
		EndIf;
		
	Else
		Return CurrentPage.Name;
	EndIf;
	
	ParameterName = "StandardSubsystems.OfferInfobaseUpdateOnSessionExit";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	ApplicationParameters[ParameterName] = Object.UpdateMode = 1;
	
	Message = NStr("en = 'Update mode is selected:'; ru = 'Выбран режим обновления:';pl = 'Jest wybrany tryb aktualizacji:';es_ES = 'Modo de actualización se ha seleccionado:';es_CO = 'Modo de actualización se ha seleccionado:';tr = 'Güncelleme modu seçildi:';it = 'Selezionata la modalità di aggiornamento:';de = 'Der Aktualisierungsmodus ist ausgewählt:'") + " ";
	If Object.UpdateMode = 0 Then   // Update now
		Message = Message + NStr("en = 'now'; ru = 'сейчас';pl = 'teraz';es_ES = 'ahora';es_CO = 'ahora';tr = 'şimdi';it = 'adesso';de = 'jetzt'");
	ElsIf Object.UpdateMode = 1 Then  // On closing application
		Message = Message + NStr("en = 'On exiting the application'; ru = 'При завершении работы';pl = 'Przy zakończeniu pracy';es_ES = 'Al salir de la aplicación';es_CO = 'Al salir de la aplicación';tr = 'Uygulamadan çıkarken';it = 'All''uscita dell''applicazione';de = 'Beim Herunterfahren'");
	ElsIf Object.UpdateMode = 2 Then  // Plan update
		Message = Message + NStr("en = 'schedule'; ru = 'расписание';pl = 'Harmonogram';es_ES = 'horario';es_CO = 'horario';tr = 'program';it = 'pianificazione';de = 'zeitplan'");
	EndIf;
	Message = Message + ".";
	NameLogEvents = ConfigurationUpdateClient.EventLogEvent();
	EventLogClient.AddMessageForEventLog(NameLogEvents, 
		"Information", Message);

	Close();
	Return CurrentPage.Name;
	
EndFunction

&AtClient
Procedure ProcessPressOfButtonNext(FlagCompleteJobs = False)
	ClearMessages();
	CurrentPage			= Items.AssistantPages.CurrentPage;
	Pages				= Items.AssistantPages.ChildItems;
	NewCurrentPage		= CurrentPage;
	ButtonNext			= Items.ButtonNext;
	ButtonBack			= Items.ButtonBack;
	CloseButton			= Items.CloseButton;
	
	CurrentPage.Enabled	= False;
	ButtonNext.Enabled		= False;
	ButtonBack.Enabled		= False;
	CloseButton.Enabled	= False;
	
	If CurrentPage = Pages.Welcome Then
		NewPage = ProcessPageWelcome();
		If NewPage = Undefined Then
			Return;
		Else
			NewCurrentPage = Pages[NewPage];
		EndIf;
	ElsIf CurrentPage = Pages.InternetConnection Then
		NewCurrentPage = Pages[ProcessPageConnectionToInternet()];
	ElsIf CurrentPage = Pages.ConnectionToSite Then
		NewCurrentPage = Pages[ProcessPageConnectionToSite()];
	ElsIf CurrentPage = Pages.AvailableUpdate Then
		NewPage = ProcessPageAvailableUpdate();
		If NewPage = Undefined Then
			Return;
		Else
			NewCurrentPage = Pages[NewPage];
		EndIf;
	ElsIf CurrentPage = Pages.UpdatesNotDetected Then
		NewCurrentPage = Pages[ProcessPageUpdateNotDetected()];
	ElsIf CurrentPage = Pages.LongAction Then
		NewCurrentPage = Pages[ProcessPageLongOperation()];
	ElsIf CurrentPage = Pages.CaseUpdateFile OR
		CurrentPage		= Pages.UpdateModeChoiceServer Then
		NewCurrentPage = Pages[ProcessPageChoiceUpdateMode(, FlagCompleteJobs)];
	ElsIf CurrentPage = Pages.SuccessfulRefresh Then
		NewCurrentPage = Pages[ProcessPageSuccessfulUpdate()];
	ElsIf CurrentPage = Pages.FailureRefresh Then
		NewCurrentPage = Pages[ProcessPageFailedUpdate()];
	ElsIf CurrentPage = Pages.UpdateFile Then
		NewPage = ProcessPageUpdateFile();
		If NewPage = Undefined Then
			Return;
		Else
			NewCurrentPage = Pages[NewPage];
		EndIf;
	EndIf;
	
	Cancel = False;
	
	OnTransitionToAssistantsPage(CurrentPage.Name, NewCurrentPage.Name, Cancel);
	
	CurrentPage.Enabled = True;
	
	// Check that the configuration update is available.
	If Not  ConfigurationUpdateClientCachedDrive.ClientWorkParameters().UpdateSettings.IsAccessForUpdate
		AND (NewCurrentPage = Pages.ConnectionToSite OR
										NewCurrentPage = Pages.LongAction OR
										NewCurrentPage = Pages.CaseUpdateFile OR
										NewCurrentPage = Pages.UpdateModeChoiceServer OR
										NewCurrentPage = Pages.UpdateFile) Then
		Cancel						= True;
		ButtonBack.Enabled		= True;
		ButtonNext.Enabled		= True;
		CloseButton.Enabled	= True;
		ShowMessageBox(, NStr("en = 'Insufficient rights to update the configuration.'; ru = 'Недостаточно прав для выполнения обновления конфигурации.';pl = 'Niewystarczające prawa do aktualizacji konfiguracji.';es_ES = 'Insuficientes derechos para actualizar la configuración.';es_CO = 'Insuficientes derechos para actualizar la configuración.';tr = 'Yapılandırmayı güncellemek için yetersiz haklar.';it = 'Diritti insufficienti per aggiornare la configurazione.';de = 'Unzureichende Rechte zum Aktualisieren der Konfiguration.'"));
	EndIf;
	
	If Cancel Then
		ToWorkClickButtonsBack();
	Else
		BeforePageOpen(NewCurrentPage);
		Items.AssistantPages.CurrentPage = NewCurrentPage;
	EndIf;
EndProcedure

&AtClient
Procedure ToWorkClickButtonsBack()
	
	Pages             = Items.AssistantPages.ChildItems;
	CurrentPage      = Items.AssistantPages.CurrentPage;
	NewCurrentPage = CurrentPage;
	
	If CurrentPage = Pages.Welcome Then
		NewCurrentPage = Pages.Welcome;
	ElsIf CurrentPage = Pages.InternetConnection Then
		NewCurrentPage = Pages.Welcome;
	ElsIf CurrentPage = Pages.ConnectionToSite Then
		NewCurrentPage = Pages.AvailableUpdate;
	ElsIf CurrentPage = Pages.AvailableUpdate Then
		NewCurrentPage = Pages.Welcome;
	ElsIf CurrentPage = Pages.UpdatesNotDetected Then
		NewCurrentPage = Pages.Welcome;
	ElsIf CurrentPage = Pages.LongAction Then
		NewCurrentPage = Pages.Welcome;
	ElsIf CurrentPage = Pages.CaseUpdateFile OR 
		CurrentPage = Pages.UpdateModeChoiceServer Then
		If Object.UpdateSource = 0 Then // Internet
			NewCurrentPage = Pages.AvailableUpdate;
		Else // file
			NewCurrentPage = Pages.UpdateFile;
		EndIf;
	ElsIf CurrentPage = Pages.SuccessfulRefresh Then
		NewCurrentPage = Pages.Welcome;
	ElsIf CurrentPage = Pages.FailureRefresh Then
		NewCurrentPage = Pages.Welcome;
		If Not ConfigurationUpdateClientCachedDrive.ClientWorkParameters().IsMasterNode Then
			GoToChoiceOfUpdateMode();
			Return;
		EndIf;
	ElsIf CurrentPage = Pages.UpdateFile Then
		NewCurrentPage = Pages.Welcome;
	ElsIf CurrentPage = Pages.AvailableUpdate Then
		NewCurrentPage = Pages.Welcome;
	EndIf;
	
	BeforePageOpen(NewCurrentPage);
	
	Items.AssistantPages.CurrentPage = NewCurrentPage;
	
EndProcedure

&AtClient
Procedure OnTransitionToAssistantsPage(PreviousPage, NextPage, Cancel)
	
	If PreviousPage = "UpdateFile" AND NextPage <> "UpdateFile" Then
		
		Notification = New NotifyDescription("OnTransitionToAssistantPageEnd", ThisObject);
		ConfigurationUpdateClientDrive.CheckSoftwareUpdateLegality(Notification);
		
	EndIf;
	
	ConfigurationUpdateClientOverridable.OnTransitionToAssistantsPage(PreviousPage, NextPage, Cancel);
	
EndProcedure

&AtClient
Procedure OnTransitionToAssistantPageEnd(RefreshReceivedLegally, AdditionalParameters) Export
	
	If RefreshReceivedLegally = False
		Or RefreshReceivedLegally = Undefined Then
		ToWorkClickButtonsBack();
	EndIf;
	
EndProcedure

&AtClient
Function ProcessPageAvailableUpdate(OutputMessages = True)
	
	Pages = Items.AssistantPages.ChildItems;
	Object.TechnicalErrorInfo = "";
	
	If Not ConfigurationUpdateClientCachedDrive.ClientWorkParameters().UpdateSettings.IsAccessForUpdate Then
		ShowMessageBox(, NStr("en = 'Insufficient rights to update the configuration.'; ru = 'Недостаточно прав для выполнения обновления конфигурации.';pl = 'Niewystarczające prawa do aktualizacji konfiguracji.';es_ES = 'Insuficientes derechos para actualizar la configuración.';es_CO = 'Insuficientes derechos para actualizar la configuración.';tr = 'Yapılandırmayı güncellemek için yetersiz haklar.';it = 'Diritti insufficienti per aggiornare la configurazione.';de = 'Unzureichende Rechte zum Aktualisieren der Konfiguration.'"));
		Return Pages.AvailableUpdate.Name;
	EndIf;
	
	FileListForObtaining.LoadValues(CreateFileListForObtaining());
	If CheckUpdateFilesReceived() Then
		NameLogEvents  = ConfigurationUpdateClient.EventLogEvent();
		EventLogClient.AddMessageForEventLog(NameLogEvents, "Information",
			NStr("en = 'Configuration update files have already been received and saved locally.'; ru = 'Обнаружено, что файлы обновления конфигурации уже были получены и сохранены локально.';pl = 'Pliki aktualizacji konfiguracji zostały już odebrane i zapisane lokalnie.';es_ES = 'Archivos de la actualización de configuraciones ya se han recibido y guardado a nivel local.';es_CO = 'Archivos de la actualización de configuraciones ya se han recibido y guardado a nivel local.';tr = 'Yapılandırma güncelleme dosyaları zaten alınmış ve yerel olarak kaydedilmiştir.';it = 'I file di aggiornamento della configurazione sono stati già ricevuti e salvati localmente.';de = 'Konfigurationsaktualisierungsdateien wurden bereits empfangen und lokal gespeichert.'"));
		GoToChoiceOfUpdateMode(True);
		Return Undefined;
	EndIf;
	
	Return Pages.LongAction.Name;
	
EndFunction

&AtClient
Function ProcessPageUpdateNotDetected(OutputMessages = True)
	Pages		= Items.AssistantPages.ChildItems;
	Close();
	Return Pages.UpdatesNotDetected.Name;
EndFunction

&AtClient
Function ProcessPageSuccessfulUpdate(OutputMessages = True)
	
	If ShowNewInVersion Then
		OpenForm("CommonForm.ApplicationReleaseNotes", New Structure("ShowOnlyChanges", True));
	EndIf;
	
	If GetToKnowAdditionalInstructions Then
		ConfigurationUpdateClientDrive.OpenWebPage(FileNameOrderUpdate);
	EndIf;
	
	Close();
	Return Items.SuccessfulRefresh.Name;
	
EndFunction

&AtClient
Function ProcessPageFailedUpdate(OutputMessages = True)
	Pages		= Items.AssistantPages.ChildItems;
	Close();
	Return Pages.FailureRefresh.Name;
EndFunction

&AtClient
Function ProcessPageUpdateFile(OutputMessages = True)
	
	Pages = Items.AssistantPages.ChildItems;
	If Object.NeedUpdateFile = 1 Then
		
		If Not ValueIsFilled(Object.UpdateFileName) Then
			If OutputMessages Then
				CommonClientServer.MessageToUser(NStr("en = 'Specify a configuration update delivery file.'; ru = 'Укажите файл поставки обновления конфигурации.';pl = 'Określ dostarczony plik aktualizacji konfiguracji.';es_ES = 'Especificar un archivo de envío de la actualización de configuraciones.';es_CO = 'Especificar un archivo de envío de la actualización de configuraciones.';tr = 'Bir yapılandırma güncelleme teslim dosyası belirtin.';it = 'Indicare il file di consegna dell''aggiornamento della configurazione.';de = 'Geben Sie eine Konfigurationsaktualisierungslieferdatei an.'"),,"Object.UpdateFileName");
			EndIf;
			CurrentItem = Items.FieldUpdateFile;
			Return Pages.UpdateFile.Name;
		EndIf;
		
		File = New File(Object.UpdateFileName);
		If Not File.Exist() OR Not File.IsFile() Then
			If OutputMessages Then
				CommonClientServer.MessageToUser(NStr("en = 'Delivery file of configuration update is not found.'; ru = 'Файл поставки обновления конфигурации не найден.';pl = 'Dostarczany plik aktualizacji konfiguracji nie został znaleziony.';es_ES = 'Archivo de envío de la actualización de configuraciones no se ha encontrado.';es_CO = 'Archivo de envío de la actualización de configuraciones no se ha encontrado.';tr = 'Yapılandırma güncellemesinin teslim dosyası bulunamadı.';it = 'File di consegna del aggiornamento della configurazione non è stato trovato.';de = 'Die Lieferdatei der Konfigurationsaktualisierung wurde nicht gefunden.'"),,"Object.UpdateFileName");
			EndIf;
			CurrentItem = Items.FieldUpdateFile;
			Return Pages.UpdateFile.Name;
		EndIf;
		
	EndIf;
	
	UpdateFilesDir = ConfigurationUpdateClientDrive.GetUpdateParameters().UpdateFilesDir; 
	If Not IsBlankString(UpdateFilesDir) Then
		Try
			DeleteFiles(UpdateFilesDir, "*");
		Except
			// Ignore the failed attempt of the temporary directory deletion.
		EndTry;
	EndIf;
	GetAvailableUpdateFromFile(?(Object.NeedUpdateFile = 1, Object.UpdateFileName, Undefined),True);
	GoToChoiceOfUpdateMode(True);
	Return Undefined;
	
EndFunction

&AtClient
Function CheckUpdateFilesReceived()
	
	FilesReceivedSuccessfully = True;
	For Each File In FileListForObtaining Do
		If File.Value.IsRequired AND Not File.Value.Received Then
			FilesReceivedSuccessfully = False;
			Break;
		EndIf;
	EndDo;
	
	If FilesReceivedSuccessfully Then
		FilesReceivedSuccessfully = UnpackUpdateInstallationPackage();
	EndIf;
	
	Return FilesReceivedSuccessfully;
	
EndFunction

&AtClient
Function GetAvailableUpdate(GetUpdateSize = False)
	
	If Object.AvailableUpdates.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	UpdateString = Object.AvailableUpdates[Object.AvailableUpdates.Count()-1];
	
	UpdateStructure = New Structure;
	UpdateStructure.Insert("Version", UpdateString.Version);
	UpdateStructure.Insert("PlatformVersion", UpdateString.PlatformVersion);
	
	If GetUpdateSize = True Then
		UpdateStructure.Insert("SizeUpdate", FileSizeString(SizeOfUpdates()));
	EndIf;
	
	Return UpdateStructure;
	
EndFunction

// Calculate the total size of the update files.
//
// Parameters:
//  Object.AvailableUpdates  - array - list of updates.
//
// Returns:
//   Number   - update size in bytes.
&AtClient
Function SizeOfUpdates()
	SizeOfUpdates = 0;
	For Each Update In Object.AvailableUpdates Do
		SizeOfUpdates = SizeOfUpdates + Update.UpdateFileSize;
	EndDo;
	Return SizeOfUpdates;
EndFunction

// Receive the string presentation of the file size.
//
// Parameters:
//  Size  - Number - size in bytes.
//
// Returns:
//   String   - String presentation of the file size, for example, "10.5 Mb".
&AtClient
Function FileSizeString(Val Size)

	If Size < 1024 Then
		Return Format(Size, "NFD=1") + " " + "byte";
	ElsIf Size < 1024 * 1024 Then	
		Return Format(Size / 1024, "NFD=1") + " " + "KB";
	ElsIf Size < 1024 * 1024 * 1024 Then	
		Return Format(Size / (1024 * 1024), "NFD=1") + " " + "MB";
	Else
		Return Format(Size / (1024 * 1024 * 1024), "NFD=1") + " " + "GB";
	EndIf; 

EndFunction

// Definition of the configuration and update layout directory on this computer.
&AtClient
Function TemplatesDirectory()
	
	Postfix = "1C\1C8\tmplts\";
	
	DirectoryDefault	= DirectoryAppData() + Postfix;
	FileName			= DirectoryAppData() + "1C\1CEStart\1CEStart.cfg";
	If Not FileExistsAtClient(FileName) Then 
		Return DirectoryDefault;
	EndIf;
	
	#If Not WebClient Then
		Text	= New TextReader(FileName, "UTF-16");
		Str		= "";
		
		While Str <> Undefined Do
			
			Str = Text.ReadLine();
			If Str = Undefined Then
				Break;
			EndIf; 
			
			If Find(Upper(Str), Upper("ConfigurationTemplatesLocation")) = 0 Then
				Continue;
			EndIf; 
			
			SeparatorPosition = Find(Str, "=");
			If SeparatorPosition = 0 Then
				Continue;
			EndIf;
			
			FoundDirectory = ConfigurationUpdateClientServer.AddFinalPathSeparator(TrimAll(Mid(Str, SeparatorPosition + 1)));
			
			Return ?(FileExistsAtClient(FoundDirectory), FoundDirectory, DirectoryDefault);
			
		EndDo; 
	#EndIf
	
	Return DirectoryDefault;

EndFunction

// Define the My documents directory of the current Windows user.
//
&AtClient
Function DirectoryAppData() 
	
	App				= New COMObject("Shell.Application");
	Folder			= App.Namespace(26);
	Result		= Folder.Self.Path;
	Return ConfigurationUpdateClientServer.AddFinalPathSeparator(Result);
	
EndFunction

// Check that the file is the update distribution.
//
// Parameter:
//  PathToFile   - String - file path.
//
// Returns:
//  Boolean - True if the file is the update distribution.
//
&AtClient
Function ThisIsUpdateInstallationPackage(Val PathToFile)
	File = New File(PathToFile);
	Return File.Exist() AND Lower(File.Extension) = ".zip";
EndFunction

&AtClient
Function GoToChoiceOfUpdateMode(IsGoNext = False)
	
	If AdministrationParameters = Undefined Then
		
		ThisIsFileBase = ConfigurationUpdateClientCachedDrive.ClientWorkParameters().FileInfobase;
		
		NotifyDescription = New NotifyDescription("AfterAdministrationParametersReceiving", ThisObject, IsGoNext);
		FormTitle = NStr("en = 'Install update'; ru = 'Установка обновления';pl = 'Zainstaluj aktualizację';es_ES = 'Instalar la actualización';es_CO = 'Instalar la actualización';tr = 'Güncellemeyi yükle';it = 'Installazione dell''aggiornamento';de = 'Installiere Update'");
		If ThisIsFileBase Then
			ExplanatoryInscription = NStr("en = 'To set the update
			                              |it is necessary to enter the infobase administration parameters'; 
			                              |ru = 'Для установки
			                              |обновления необходимо ввести параметры администрирования информационной базы';
			                              |pl = 'Aby ustawić aktualizację,
			                              |należy wprowadzić parametry administrowania bazy informacyjnej';
			                              |es_ES = 'Para establecer la actualización
			                              |es necesario introducir los parámetros de administración de la infobase';
			                              |es_CO = 'Para establecer la actualización
			                              |es necesario introducir los parámetros de administración de la infobase';
			                              |tr = 'Güncellemeyi ayarlamak için veritabanı
			                              | yönetim parametrelerini girmek gereklidir';
			                              |it = 'Per configurare l''aggiornamento
			                              |è necessario inserire i parametri di amministrazione dell''infobase';
			                              |de = 'Um das Update zu setzen,
			                              |müssen die Infobase Administrationsparameter eingegeben werden'");
			QueryClusterAdministrationParameters = False;
		Else
			ExplanatoryInscription = NStr("en = 'To install the update it
			                              |is necessary to enter the administration parameters for the server and infobase cluster'; 
			                              |ru = 'Для установки обновления
			                              |необходимо ввести параметры администрирования кластера серверов и информационной базы';
			                              |pl = 'Aby zainstalować aktualizację,
			                              |konieczne jest wprowadzenie parametrów administracyjnych dla serwera i klastra bazy informacyjnej';
			                              |es_ES = 'Para instalar la actualización, es
			                              |necesario introducir los parámetros de administración para el servidor y el clúster de la infobase';
			                              |es_CO = 'Para instalar la actualización, es
			                              |necesario introducir los parámetros de administración para el servidor y el clúster de la infobase';
			                              |tr = 'Güncelleştirmeyi yüklemek için sunucu ve veritabanı kümesi için 
			                              |yönetim parametrelerini girmek gerekir';
			                              |it = 'Per installare l''aggiornamento
			                              |è necessario inserire i parametri di amministrazione del server e del cluster infobase';
			                              |de = 'Um das Update zu installieren,
			                              |müssen die Administrationsparameter für den Server und den Infobase-Cluster eingegeben werden'");
			QueryClusterAdministrationParameters = True;
		EndIf;
		
		IBConnectionsClient.ShowAdministrationParameters(NotifyDescription, True, QueryClusterAdministrationParameters,
			AdministrationParameters, FormTitle, ExplanatoryInscription);
		
	Else
		
		AfterAdministrationParametersReceiving(AdministrationParameters, IsGoNext);
		
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Procedure AfterAdministrationParametersReceiving(Result, IsGoNext) Export
	
	If Result <> Undefined Then
		
		AdministrationParameters = Result;
		Pages = Items.AssistantPages.ChildItems;
		ThisIsFileBase = ConfigurationUpdateClientCachedDrive.ClientWorkParameters().FileInfobase;
		NewCurrentPage = ?(ThisIsFileBase AND Not SimulationModeOfClientServerIB(), Pages.CaseUpdateFile, Pages.UpdateModeChoiceServer);
		SetAdministratorPassword(AdministrationParameters);
		
		If IsGoNext Then
			
			Items.AssistantPages.CurrentPage.Enabled = True;
			
			// Check that the configuration update is available.
			If Not ConfigurationUpdateClientCachedDrive.ClientWorkParameters().UpdateSettings.IsAccessForUpdate Then
				
				Items.ButtonBack.Enabled = True;
				Items.ButtonNext.Enabled = True;
				Items.CloseButton.Enabled = True;
				ShowMessageBox(, NStr("en = 'Insufficient rights to update the configuration.'; ru = 'Недостаточно прав для выполнения обновления конфигурации.';pl = 'Niewystarczające prawa do aktualizacji konfiguracji.';es_ES = 'Insuficientes derechos para actualizar la configuración.';es_CO = 'Insuficientes derechos para actualizar la configuración.';tr = 'Yapılandırmayı güncellemek için yetersiz haklar.';it = 'Diritti insufficienti per aggiornare la configurazione.';de = 'Unzureichende Rechte zum Aktualisieren der Konfiguration.'"));
				ToWorkClickButtonsBack();
			EndIf;
			
		EndIf;
		
		BeforePageOpen(NewCurrentPage);
		Items.AssistantPages.CurrentPage = NewCurrentPage;
		
	Else
		
		If IsGoNext Then
			
			Items.AssistantPages.CurrentPage.Enabled = True;
			
		EndIf;
		
		WarningText = NStr("en = 'To install the update, enter the administration parameters.'; ru = 'Для установки обновления необходимо ввести параметры администрирования.';pl = 'Aby zainstalować aktualizację, wprowadź parametry administracyjne.';es_ES = 'Para instalar la actualización, introducir los parámetros de administración.';es_CO = 'Para instalar la actualización, introducir los parámetros de administración.';tr = 'Güncellemeyi yüklemek için yönetim parametrelerini girin.';it = 'Per installare l''aggiornamento, è necessario inserire i parametri di amministrazione.';de = 'Um das Update zu installieren, geben Sie die Administrationsparameter ein.'");
		ShowMessageBox(, WarningText);
		
		NameLogEvents = ConfigurationUpdateClient.EventLogEvent();
		MessageText = NStr("en = 'Failed to install the application update, i.e. correct
		                   |infobase administration parameters were not entered.'; 
		                   |ru = 'Не удалось установить обновление программы, т.к. не были введены
		                   |корректные параметры администрирования информационной базы.';
		                   |pl = 'Nie udało się zainstalować aktualizacji aplikacji, ponieważ poprawne parametry
		                   |administrowania bazy informacyjnej nie zostały wprowadzone.';
		                   |es_ES = 'Fallado a instalar la actualización de la aplicación, por ejemplo, parámetros de administración de la infobase
		                   |correctos no se han introducido.';
		                   |es_CO = 'Fallado a instalar la actualización de la aplicación, por ejemplo, parámetros de administración de la infobase
		                   |correctos no se han introducido.';
		                   |tr = 'Uygulama güncellemesi yüklenemedi:
		                   |doğru Infobase yönetim parametreleri girilmedi.';
		                   |it = 'Installazione dell''aggiornamento dell''applicazione non riuscita, cioè
		                   |non sono stati inseriti i parametri corretti di amministrazione di Infobase.';
		                   |de = 'Fehler beim Installieren der Anwendungsaktualisierung, d.H., die korrekten
		                   |Infobase Verwaltungsparameter wurden nicht eingegeben.'");
		EventLogClient.AddMessageForEventLog(NameLogEvents, "Error", MessageText);
		
		NewCurrentPage = Items.FailureRefresh;
		BeforePageOpen(NewCurrentPage);
		Items.AssistantPages.CurrentPage = NewCurrentPage;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetAdministratorPassword(AdministrationParameters)
	
	InfobaseAdministrator = InfobaseUsers.FindByName(AdministrationParameters.InfobaseAdministratorName);
	
	If Not InfobaseAdministrator.StandardAuthentication Then
		
		InfobaseAdministrator.StandardAuthentication = True;
		InfobaseAdministrator.Password = AdministrationParameters.InfobaseAdministratorPassword;
		InfobaseAdministrator.Write();
		
	EndIf;
	
EndProcedure

// Receive the user authentication parameters for the update.
// Creates a virtual user if needed.
//
// Return
//  value Structure       - virtual user parameters.
//
&AtClient
Function GetAuthenticationParametersOfUpdateAdministrator()

	Result = New Structure("UserName,
								|UserPassword,
								|ConnectionString,
								|InfobaseConnectionString",
								Undefined, "", "", "", "", "");
								
	ClusterPort = AdministrationParameters.ClusterPort;
	CurrentConnections = IBConnectionsServerCall.ConnectionsInformation(True,
		ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"], ClusterPort);
	Result.InfobaseConnectionString = CurrentConnections.InfobaseConnectionString;
	// Diagnostics of the case when the role security is not provided in the system. 
	// It is a situation when any user "may" do everything in the system.
	If Not CurrentConnections.HasActiveUsers Then
		Return Result;
	EndIf;
	
	User = AdministrationParameters.InfobaseAdministratorName;
	Password = AdministrationParameters.InfobaseAdministratorPassword;
	
	Result.UserName			= User;
	Result.UserPassword		= Password;
	Result.ConnectionString			= "Usr=""{0}"";Pwd=""{1}""";
	Return Result;
	
EndFunction

&AtClient
Function CheckAccessToIB()
	
	NameLogEvents = ConfigurationUpdateClient.EventLogEvent();
	Result = True;
	DetectedConnectionError = "";
	// IN basic versions the connection is not checked;
	// in case of incorrect name and password entry the update fails.
	ClientWorkParameters = ConfigurationUpdateClientCachedDrive.ClientWorkParameters();
	If ClientWorkParameters.ThisIsBasicConfigurationVersion Or ClientWorkParameters.IsTrainingPlatform Then
		Return Result;
	EndIf;
	
	// Check the connection to the infobase.
	Try
		ClusterAdministrationClientServer.CheckAdministrationParameters(AdministrationParameters,, False);
	Except
		Result = False;
		MessageText = NStr("en = 'Cannot connect to the infobase:'; ru = 'Не удалось выполнить подключение к информационной базе:';pl = 'Nie można połączyć się z bazą informacyjną:';es_ES = 'No se puede conectar a la infobase:';es_CO = 'No se puede conectar a la infobase:';tr = 'Infobase''e bağlanılamıyor:';it = 'Non è possibile collegarsi all''infobase';de = 'Verbindung zur Infobase nicht möglich:'") + Chars.LF;
		EventLogClient.AddMessageForEventLog(NameLogEvents, 
			"Error", MessageText + DetailErrorDescription(ErrorInfo()));
		DetectedConnectionError = MessageText + BriefErrorDescription(ErrorInfo());
	EndTry;
	
	// Check connection to the cluster.
	If Result AND Not ClientWorkParameters.FileInfobase Then
		Try
			ClusterAdministrationClientServer.CheckAdministrationParameters(AdministrationParameters,,, False);
		Except
			Result = False;
			MessageText = NStr("en = 'Cannot connect to the server cluster:'; ru = 'Не удалось выполнить подключение к кластеру серверов:';pl = 'Nie można połączyć się z klastrem serwerów:';es_ES = 'No se puede conectar al clúster del servidor:';es_CO = 'No se puede conectar al clúster del servidor:';tr = 'Sunucu kümesine bağlanılamıyor:';it = 'Impossibile connettersi al cluster di server:';de = 'Verbindung zum Servercluster kann nicht hergestellt werden:'") + Chars.LF;
			EventLogClient.AddMessageForEventLog(NameLogEvents,
				"Error", MessageText + DetailErrorDescription(ErrorInfo()));
			DetectedConnectionError = MessageText + BriefErrorDescription(ErrorInfo());
		EndTry;
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Function CheckEMailSettings(CurrentPageName, OutputMessages = True)
	If Not CommonClientServer.EmailAddressMeetsRequirements(Object.EmailAddress) Then
		If OutputMessages Then
			ShowMessageBox(, NStr("en = 'Specify an allowable email address.'; ru = 'Укажите допустимый адрес электронной почты.';pl = 'Podaj dopuszczalny adres poczty e-mail.';es_ES = 'Especificar una dirección de correo electrónico admisible.';es_CO = 'Especificar una dirección de correo electrónico admisible.';tr = 'İzin verilen bir e-posta adresi belirtin.';it = 'Specificare un indirizzo email consentito.';de = 'Geben Sie eine zulässige E-Mail-Adresse an.'"));
		EndIf;
		CurrentItem	= Items.FieldEmailAddress;
		Return CurrentPageName;
	EndIf;
	Return "";
EndFunction

&AtClient
Function DefineScriptName()
	App	= New COMObject("Shell.Application");
	Try
   		Folder = App.Namespace(41);
   		Return Folder.Self.Path + "\wscript.exe";
	Except
		Return "wscript.exe";
	EndTry;
EndFunction

&AtServer
Function AuthenticationParameters()
	
	CheckParameters = New Structure;
	
	SystemInfo = New SystemInfo;
	InfobaseIdentifier = StandardSubsystemsServer.InfoBaseID();

	CheckParameters.Insert("login"               , Object.UpdateServerUserCode);
	CheckParameters.Insert("password"            , Object.UpdatesServerPassword);
	CheckParameters.Insert("variantBPED"         , "authorizationChecking");
	CheckParameters.Insert("versionConfiguration", TrimAll(Metadata.Version));
	CheckParameters.Insert("versionPlatform"     , String(SystemInfo.AppVersion));
	CheckParameters.Insert("nameConfiguration"   , Metadata.Name);
	CheckParameters.Insert("language"            , TrimAll(CurrentLocaleCode()));
	CheckParameters.Insert("enterPoint"          , "authorizationChecking");
	CheckParameters.Insert("InfobaseID"          , InfobaseIdentifier);
	
	Return CheckParameters;
	
EndFunction

// Plan the configuration update.
&AtClient
Function PlanConfigurationChange()
	If Not DeleteSchedulerTask(Object.SchedulerTaskCode) Then
		Return False;
	EndIf; 
	ScriptMainFileName = GenerateUpdateScriptFiles(False);
	
	NameOfScriptToRun = DefineScriptName();
	PathOfScriptToRun = StringFunctionsClientServer.SubstituteParametersToString("%1 %2 //nologo ""%3"" /p1:""%4"" /p2:""%5""",
		NameOfScriptToRun, ?(ScriptDebugMode(), "//X //D", ""), ScriptMainFileName,
		AdministrationParameters.InfobaseAdministratorPassword, AdministrationParameters.ClusterAdministratorPassword);
	
	Object.SchedulerTaskCode = CreateSchedulerTask(PathOfScriptToRun, Object.UpdateDateTime);
	WriteUpdateStatus(UserName(), Object.SchedulerTaskCode <> 0, False, False);
	Return Object.SchedulerTaskCode <> 0;
EndFunction

// Create Windows OS scheduler task.
//
// Parameters:
//  ApplicationFileName	- String	- path to the running application or file.
//  DateTime  			  - Date		- Start date and time. Date value may
// 							     	vary within [current date, current date + 30 days).
//
// Returns:
//   Number   - the code of the created scheduler task or Undefined in case of an error.
&AtClient
Function CreateSchedulerTask(Val ApplicationFileName, Val DateTime)
	NameLogEvents = ConfigurationUpdateClient.EventLogEvent();
	Try
		Scheduler		= ObjectWMI().Get("Win32_ScheduledJob");
		CodeTasks		= 0;
		ErrorCode		= Scheduler.Create(ApplicationFileName, // Command
			ConvertTimeToCIMFormat(DateTime),	// StartTime
			False,		// RunRepeatedly
			,           // DaysOfWeek
			Pow(2, Day(DateTime) - 1),         // DaysOfMonth
			False, 		// InteractWithDesktop
			CodeTasks);// out JobId
		If ErrorCode <> 0 Then	// Error codes: http://msdn2.microsoft.com/en-us/library/aa389389(VS.85).aspx.
			EventLogClient.AddMessageForEventLog(NameLogEvents, 
				"Error", NStr("en = 'An error occurred while creating a scheduler task:'; ru = 'Ошибка при создании задачи планировщика:';pl = 'Wystąpił błąd podczas tworzenia zadania planisty:';es_ES = 'Ha ocurrido un error al crear una tarea del organizador:';es_CO = 'Ha ocurrido un error al crear una tarea del organizador:';tr = 'Zamanlayıcı görevi oluştururken bir hata oluştu:';it = 'Si è verificato un errore durante la creazione di una operazione di pianificazione:';de = 'Beim Erstellen einer Planer-Aufgabe ist ein Fehler aufgetreten:'")
					+ " " + ErrorCode);
			Return 0;
		EndIf;
		MessageText = NStr("en = 'Scheduler task is successfully planned (command: %1; date: %2; task code: %3).'; ru = 'Задача планировщика успешно запланирована (команда: %1; дата: %2; код задачи: %3).';pl = 'Zadanie planisty zostało pomyślnie zaplanowane (polecenie: %1; data: %2; kod zadania: %3).';es_ES = 'Tarea del organizador se ha programado con éxito (comando: %1; fecha: %2; código de tarea: %3).';es_CO = 'Tarea del organizador se ha programado con éxito (comando: %1; fecha: %2; código de tarea: %3).';tr = 'Zamanlayıcı görevi başarıyla planlandı (komut:%1; tarih:%2; görev kodu:%3).';it = 'L''operazione di pianificazione è stata pianificata (comando: %1; data: %2; codice operazione: %3).';de = 'Planer-Aufgabe wird erfolgreich geplant (Befehl: %1; Datum: %2; Aufgabencode: %3).'");
		
		EventLogClient.AddMessageForEventLog(NameLogEvents,
			"Information", 
			StringFunctionsClientServer.SubstituteParametersToString(MessageText, ApplicationFileName, DateTime, CodeTasks));
			
	Except
			
		EventLogClient.AddMessageForEventLog(NameLogEvents, "Error",
			NStr("en = 'An error occurred while creating a scheduler task:'; ru = 'Ошибка при создании задачи планировщика:';pl = 'Wystąpił błąd podczas tworzenia zadania planisty:';es_ES = 'Ha ocurrido un error al crear una tarea del organizador:';es_CO = 'Ha ocurrido un error al crear una tarea del organizador:';tr = 'Zamanlayıcı görevi oluştururken bir hata oluştu:';it = 'Si è verificato un errore durante la creazione di una operazione di pianificazione:';de = 'Beim Erstellen einer Planer-Aufgabe ist ein Fehler aufgetreten:'")
				+ " " + ErrorDescription());
		Return 0;
	EndTry;
	
	Return CodeTasks;

EndFunction

&AtClient
Function ConvertTimeToCIMFormat(DateTime)
	Locator			= New COMObject("WbemScripting.SWbemLocator");
	Service			= Locator.ConnectServer(".", "\root\cimv2");
	ComputerSystems	= Service.ExecQuery("SELECT * FROM Win32_ComputerSystem");
	For Each ComputerSystem In ComputerSystems Do
		Difference	= ComputerSystem.CurrentTimeZone;
		Hour		= Format(DateTime,"DF=HH");
		Minute	= Format(DateTime,"DF=mm");
		Difference	= ?(Difference > 0, "+" + Format(Difference, "NG=0"), Format(Difference, "NG=0"));
		Return "********" + Hour + Minute + "00.000000" + Difference;
	EndDo;

	Return Undefined;
EndFunction

&AtClient
Function GenerateUpdateScriptFiles(Val InteractiveMode) 
	
	UpdateParameters		= ConfigurationUpdateClientDrive.GetUpdateParameters();
	ClientWorkParameters	= ConfigurationUpdateClientCachedDrive.ClientWorkParameters();
	CreateDirectory(UpdateParameters.UpdateTempFilesDir);
	
	// Structure of the parameters is required for defining them on client and passing to server.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("NameOfExecutableDesignerFile",	UpdateParameters.NameOfExecutableDesignerFile);
	ParametersStructure.Insert("NameOfExecutableFileOfClient",	StandardSubsystemsClient.ApplicationExecutableFileName());
	ParametersStructure.Insert("EventLogEvent",					UpdateParameters.EventLogEvent);
	ParametersStructure.Insert("COMConnectorName",				ClientWorkParameters.COMConnectorName);
	ParametersStructure.Insert("UseCOMConnector",				ClientWorkParameters.ThisIsBasicConfigurationVersion OR ClientWorkParameters.IsTrainingPlatform);
	ParametersStructure.Insert("FileInfobase",					ClientWorkParameters.FileInfobase);
	ParametersStructure.Insert("ScriptParameters",				GetAuthenticationParametersOfUpdateAdministrator());
	ParametersStructure.Insert("AdministrationParameters",		AdministrationParameters);
	
	// Add to the structure and the name of the running application.
	
	#If Not WebClient Then
		ParametersStructure.Insert("BinDir", BinDir());
	#Else
		ParametersStructure.Insert("BinDir", "");
	#EndIf
	
	TemplateNames = "AdditFileOfUpdateOfConfiguration";
	If InteractiveMode Then
		TemplateNames = TemplateNames + ",SplashOfConfigurationUpdate";
	Else
		TemplateNames = TemplateNames + ",OfflineConfigurationUpdate";
	EndIf;
	
	TemplateTexts = GetTextsOfTemplates(TemplateNames, ParametersStructure, ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
	
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(TemplateTexts[0]);
	
	ScriptFileName = UpdateParameters.UpdateTempFilesDir + "main.js";
	ScriptFile.Write(ScriptFileName, "UTF-16");
	
	// Helper file: helpers.js.
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(TemplateTexts[1]);
	ScriptFile.Write(UpdateParameters.UpdateTempFilesDir + "helpers.js", "UTF-16");
	
	ScriptMainFileName = Undefined;
	If InteractiveMode Then
		// Helper file: splash.png.
		PictureLib.ExternalOperationSplash.Write(UpdateParameters.UpdateTempFilesDir + "splash.png");
		// Helper file: splash.ico.
		PictureLib.ExternalOperationSplashIcon.Write(UpdateParameters.UpdateTempFilesDir + "splash.ico");
		// Helper file: progress.gif.
		PictureLib.TimeConsumingOperation48.Write(UpdateParameters.UpdateTempFilesDir + "progress.gif");
		// Main splash screen file: splash.hta.
		ScriptMainFileName = UpdateParameters.UpdateTempFilesDir + "splash.hta";
		
		ScriptFile = New TextDocument;
		ScriptFile.Output = UseOutput.Enable;
		ScriptFile.SetText(TemplateTexts[2]);
		ScriptFile.Write(ScriptMainFileName, "UTF-16");
		
	Else
		
		ScriptMainFileName = UpdateParameters.UpdateTempFilesDir + "updater.js";
		
		ScriptFile = New TextDocument;
		ScriptFile.Output = UseOutput.Enable;
		ScriptFile.SetText(TemplateTexts[2]);
		ScriptFile.Write(ScriptMainFileName, "UTF-16");
		
	EndIf;
	
	Return ScriptMainFileName;
	
EndFunction

&AtClient
Function WMIInstalled(Val OutputMessages = True)
	Try
		Return ObjectWMI() <> Undefined;
	Except
		NameLogEvents = ConfigurationUpdateClient.EventLogEvent();
		EventLogClient.AddMessageForEventLog(NameLogEvents, "Error", ErrorDescription());
		Return False;
	EndTry;
EndFunction

&AtClient
Function CheckValidUpdateDate(DateTime, OutputMessages = True)
	MessageText = ValidateAcceptableDateUpdateAtServer(DateTime);
	Result = IsBlankString(MessageText);
	If Not Result AND OutputMessages Then
		ShowMessageBox(, MessageText);
	EndIf;
	Return Result;
EndFunction

&AtServerNoContext
Function ValidateAcceptableDateUpdateAtServer(DateTime)
	
	Now = CurrentSessionDate();
	If DateTime < Now Then
		Return NStr("en = 'Configuration update can be scheduled only for a future date and time.'; ru = 'Обновление конфигурации может быть запланировано только на будущую дату и время.';pl = 'Aktualizacja konfiguracji może być zaplanowana tylko na przyszłą datę i czas.';es_ES = 'Actualización de configuraciones puede programarse solo para una fecha y una hora en el futuro.';es_CO = 'Actualización de configuraciones puede programarse solo para una fecha y una hora en el futuro.';tr = 'Yapılandırma güncellemesi sadece ileri bir tarih ve saat için planlanabilir.';it = 'L''aggiornamento della configurazione può essere programmato solo per una data e ora future.';de = 'Das Konfigurationsupdate kann nur für ein zukünftiges Datum und eine geplante Uhrzeit geplant werden.'");
	EndIf;
	If DateTime > AddMonth(Now, 1) Then
		Return NStr("en = 'Configuration update can be scheduled not later than in a month from the current date.'; ru = 'Обновление конфигурации может быть запланировано не позднее, чем через месяц относительно текущей даты.';pl = 'Aktualizacja konfiguracji może być zaplanowana nie później niż po miesiącu od bieżącej daty.';es_ES = 'Actualización de configuraciones puede programarse no más tarde que en un mes a partir de la fecha actual.';es_CO = 'Actualización de configuraciones puede programarse no más tarde que en un mes a partir de la fecha actual.';tr = 'Yapılandırma güncellemesi, geçerli tarihten itibaren bir ay içinde geçmeyecek şekilde programlanabilir.';it = 'L''aggiornamento della configurazione può essere programmato non più tardi di un mese dalla data corrente.';de = 'Die Aktualisierung der Konfiguration kann nicht später als in einem Monat ab dem aktuellen Datum geplant werden.'");
	EndIf;
	
	Return "";
	
EndFunction

&AtClient
Function DeleteSchedulerTask(CodeTasks)
	NameLogEvents = ConfigurationUpdateClient.EventLogEvent();
	If CodeTasks = 0 Then
		Return True;
	EndIf; 
	
	Try
		Service = ObjectWMI();
		
		Task = GetSchedulerTask(CodeTasks);
		If Task = Undefined Then
			CodeTasks = 0;
			Return True;
		EndIf; 
		
		ErrorCode = Task.Delete();
		Result = ErrorCode = 0;
		If Not Result Then	// Error codes: http://msdn2.microsoft.com/en-us/library/aa389957(VS.85).aspx.
			EventLogClient.AddMessageForEventLog(NameLogEvents, "Error",
				NStr("en = 'An error occurred while deleting the scheduler task:'; ru = 'Ошибка при удалении задачи планировщика:';pl = 'Wystąpił błąd podczas usuwania zadania planisty :';es_ES = 'Ha ocurrido un error al eliminar la tarea del organizador:';es_CO = 'Ha ocurrido un error al eliminar la tarea del organizador:';tr = 'Zamanlayıcı görevi silinirken bir hata oluştu:';it = 'Si è verificato un errore durante l''eliminazione dello schedulatore attività:';de = 'Beim Löschen der Planer-Aufgabe ist ein Fehler aufgetreten:'")
					+ " " + ErrorCode);
			Return Result;
		EndIf;
		MessageText = NStr("en = 'Scheduler task is successfully removed (task code: %1).'; ru = 'Задача планировщика успешно удалена (код задачи: %1).';pl = 'Zadanie planisty zostało pomyślnie usunięte (kod zadania : %1).';es_ES = 'Tarea del organizador se ha eliminado con éxito (código de tarea: %1).';es_CO = 'Tarea del organizador se ha eliminado con éxito (código de tarea: %1).';tr = 'Zamanlayıcı görevi başarıyla kaldırıldı (görev kodu:%1).';it = 'Il processo pianificato viene rimosso correttamente (codice compito: %1).';de = 'Planer-Aufgabe wurde erfolgreich entfernt (Aufgabencode: %1).'");
		EventLogClient.AddMessageForEventLog(NameLogEvents, "Information",
			StringFunctionsClientServer.SubstituteParametersToString(MessageText, CodeTasks));
		CodeTasks = 0;
		
		Return Result;
	Except
		
		EventLogClient.AddMessageForEventLog(NameLogEvents, "Error",
			NStr("en = 'An error occurred while deleting the scheduler task:'; ru = 'Ошибка при удалении задачи планировщика:';pl = 'Wystąpił błąd podczas usuwania zadania planisty :';es_ES = 'Ha ocurrido un error al eliminar la tarea del organizador:';es_CO = 'Ha ocurrido un error al eliminar la tarea del organizador:';tr = 'Zamanlayıcı görevi silinirken bir hata oluştu:';it = 'Si è verificato un errore durante l''eliminazione dello schedulatore attività:';de = 'Beim Löschen der Planer-Aufgabe ist ein Fehler aufgetreten:'")
				+ " " + ErrorDescription());
		Return False;
	EndTry;

EndFunction

&AtClient
Function CreateFileListForObtaining() 
	
	FileList = New Array;
	UpdateParameters = ConfigurationUpdateClientDrive.GetUpdateParameters();
	DirectoryUpdateInSource = UpdateParameters.TemplatesDirectoryAddressAtUpdatesServer;
	
	For Each Update In Object.AvailableUpdates Do
		If Not IsBlankString(Update.PathToUpdateFile) AND IsBlankString(Update.PathToLocalUpdateFile) Then
			StructureInformationFile	= New Structure("Address, LocalPath, Obligatory, Received");
			
			FileDirectoryUpdate						= GetUpdateFileDir(Update);
			Update.LocalRelativeDirectory	= FileDirectoryUpdate;
			Update.PathToLocalFile				= UpdateParameters.UpdateFilesDir +
				FileDirectoryUpdate + Update.UpdateFile;
			// Update attachment description.
			StructureInformationFile.Clear();
			StructureInformationFile.Insert("Address"					, DirectoryUpdateInSource + Update.PathToUpdateFile);
			StructureInformationFile.Insert("LocalPath"			, Update.PathToLocalFile);
			StructureInformationFile.Insert("IsRequired"			, True);
			StructureInformationFile.Insert("Received"				, DefineFileReceived(StructureInformationFile,
																								Update.UpdateFileSize));
			FileList.Add(StructureInformationFile);
		EndIf;
	EndDo;
	
	Return FileList;
	
EndFunction

&AtClient
Function DefineFileReceived(FileDescription, Size)
	File = New File(FileDescription.LocalPath);
	Return File.Exist() AND File.Size() = Size;
EndFunction

// Receiving the update description file from the server.
&AtClient
Function GetFileOfUpdateDescription()
	
	UpdateSettings = ConfigurationUpdateClientCachedDrive.ClientWorkParameters().UpdateSettings;
	UpdateParameters = ConfigurationUpdateClientDrive.GetUpdateParameters();
	FileName	= GetNameOfLocalFileOfUpdateDescription();
	Result	= GetFilesFromInternetClient.DownloadFileAtClient(UpdateSettings.ServerAddressForVerificationOfUpdateAvailability +
		UpdateParameters.AddressOfResourcesForVerificationOfUpdateAvailability +	UpdateParameters.UpdateDescriptionFileName,
		New Structure("PathForSaving", ? (IsBlankString(FileName), Undefined, FileName)));
	If Result.Status Then
		Return FileName;
	EndIf;
	
	Try
		DeleteFiles(FileName);
	Except
		MessageText = NStr("en = 'Error while deleting the
		                   |temporary file %1 %2'; 
		                   |ru = 'Ошибка при удалении
		                   |временного файла %1 %2';
		                   |pl = 'Błąd podczas usuwania
		                   |pliku tymczasowego %1 %2';
		                   |es_ES = 'Error el eliminar el
		                   |archivo temporal %1 %2';
		                   |es_CO = 'Error el eliminar el
		                   |archivo temporal %1 %2';
		                   |tr = 'Geçici dosya 
		                   |silinirken hata oluştu%1 %2';
		                   |it = 'Errore durante l''eliminazione
		                   |del file temporaneo %1 %2';
		                   |de = 'Fehler beim Löschen der
		                   |temporären Datei %1 %2'");
		NameLogEvents =	ConfigurationUpdateClient.EventLogEvent();
		EventLogClient.AddMessageForEventLog(NameLogEvents,
			"Error", StringFunctionsClientServer.SubstituteParametersToString(MessageText, FileName,
			DetailErrorDescription(ErrorInfo())));
	EndTry;
	Return Undefined;
	
EndFunction

&AtClient
Function GetNameOfLocalFileOfUpdateOrder()
	
	UpdateParameters = ConfigurationUpdateClientDrive.GetUpdateParameters();
	Return UpdateParameters.UpdateFilesDir + UpdateParameters.UpdateOrderFileName;
	
EndFunction

&AtClient
Function GetNameOfLocalFileOfUpdateDescription()
	
	UpdateParameters = ConfigurationUpdateClientDrive.GetUpdateParameters();
	Return UpdateParameters.UpdateFilesDir + UpdateParameters.UpdateDescriptionFileName;
			
EndFunction

// Receiving the update order file from the server.
&AtClient
Function GetFileOfUpdateOrder()
	
	UpdateSettings = ConfigurationUpdateClientCachedDrive.ClientWorkParameters().UpdateSettings;
	UpdateParameters = ConfigurationUpdateClientDrive.GetUpdateParameters();
	FileName = GetNameOfLocalFileOfUpdateOrder();
	Result	= GetFilesFromInternetClient.DownloadFileAtClient(UpdateSettings.ServerAddressForVerificationOfUpdateAvailability +
		UpdateParameters.AddressOfResourcesForVerificationOfUpdateAvailability +	UpdateParameters.UpdateOrderFileName,
		New Structure("PathForSaving", ? (IsBlankString(FileName), Undefined, FileName)), False);
	If Result.Status Then
		Return FileName;
	EndIf;
	Try
		DeleteFiles(FileName);
	Except
		MessageText = NStr("en = 'Error while deleting the
		                   |temporary file %1 %2'; 
		                   |ru = 'Ошибка при удалении
		                   |временного файла %1 %2';
		                   |pl = 'Błąd podczas usuwania
		                   |pliku tymczasowego %1 %2';
		                   |es_ES = 'Error el eliminar el
		                   |archivo temporal %1 %2';
		                   |es_CO = 'Error el eliminar el
		                   |archivo temporal %1 %2';
		                   |tr = 'Geçici dosya 
		                   |silinirken hata oluştu%1 %2';
		                   |it = 'Errore durante l''eliminazione
		                   |del file temporaneo %1 %2';
		                   |de = 'Fehler beim Löschen der
		                   |temporären Datei %1 %2'");
			
		NameLogEvents = ConfigurationUpdateClient.EventLogEvent();
		EventLogClient.AddMessageForEventLog(NameLogEvents,
			"Error", StringFunctionsClientServer.SubstituteParametersToString(MessageText, FileName,
			DetailErrorDescription(ErrorInfo())));
	EndTry;
	Return Undefined;
	
EndFunction

&AtClient
Procedure GetAvailableUpdateFromFile(Val FileName, FileVariant = False)
	If ValueIsFilled(FileName) Then
		If FileVariant Then
			Object.AvailableUpdates.Clear();
		EndIf;
		NewAvailableUpdate								= Object.AvailableUpdates.Add();
		NewAvailableUpdate.PathToLocalFile			= FileName;
		NewAvailableUpdate.PathToLocalUpdateFile	= FileName;
	EndIf;
EndProcedure

// Receiving the update file directory. 
// 
// Parameter:
//  AvailableUpdate - Value table string containing information
//                        of the available update.
// 
// Returns:
//  String - update file directory.
//
&AtClient
Function GetUpdateFileDir(AvailableUpdate)
	
	If AvailableUpdate = Undefined Then
		Return Undefined;
	EndIf;
	
	ConfigurationShortName = ConfigurationUpdateClientCachedDrive.ClientWorkParameters().UpdateSettings.ConfigurationShortName;
	ConfigurationShortName = StrReplace(ConfigurationShortName, "/", "\");
	ConfigurationShortName = ConfigurationUpdateClientServer.AddFinalPathSeparator(ConfigurationShortName);
	Result = StrReplace(AvailableUpdate.PathToUpdateFile, "/", "\");
	Result = ConfigurationUpdateClientDrive.GetFileDir(Result);
	Result = ConfigurationUpdateClientServer.AddFinalPathSeparator(Result);
	Return Result;
	
EndFunction

// Update distribution unpacking.
&AtClient
Function UnpackUpdateInstallationPackage()
	#If Not WebClient Then
	NameLogEvents = ConfigurationUpdateClient.EventLogEvent();
	EventLogClient.AddMessageForEventLog(NameLogEvents, 
		"Information", NStr("en = 'Unpacking update distribution...'; ru = 'Выполняется распаковка дистрибутива обновления...';pl = 'Trwa rozpakowywanie pliku aktualizacji...';es_ES = 'Desembalando la distribución de actualizaciones...';es_CO = 'Desembalando la distribución de actualizaciones...';tr = 'Güncelleme dağıtımını aç ...';it = 'Apertura della distribuzione dell''aggiornamento...';de = 'Auspacken Update-Verteilung...'"));
		
	For Each Update In Object.AvailableUpdates Do
	
		If Not ThisIsUpdateInstallationPackage(Update.PathToLocalFile) Then
			Update.PathToLocalUpdateFile = ?(IsBlankString(Update.PathToLocalUpdateFile), 
				Update.PathToLocalFile, Update.PathToLocalUpdateFile);
			Continue;
		EndIf;
		
		Try 
			
			ZipReader			= New ZipFileReader(Update.PathToLocalFile);
			DestinationDirectory	= TemplatesDirectory() + Update.LocalRelativeDirectory;
			ZipReader.ExtractAll(DestinationDirectory, ZIPRestoreFilePathsMode.Restore);
			UpdateFileName	= DestinationDirectory + "1cv8.cfu";
			If Not FileExistsAtClient(UpdateFileName) Then
				EventLogClient.AddMessageForEventLog(NameLogEvents, "Error",
					NStr("en = 'Update distribution does not contain 1cv8.cfu:'; ru = 'Дистрибутив обновления не содержит 1cv8.cfu:';pl = 'Plik aktualizacji nie zawiera 1cv8.cfu:';es_ES = 'Distribución de actualizaciones no contiene 1cv8.cfu:';es_CO = 'Distribución de actualizaciones no contiene 1cv8.cfu:';tr = 'Güncelleme dağıtımı 1cv8.cfu içermiyor:';it = 'La distribuzione dell''aggiornamento non contiene 1cv8.cfu:';de = 'Update-Verteilung enthält nicht 1cv8.cfu:'")
						+ " " + Update.PathToLocalFile);
				Return False;
			EndIf;
			Update.PathToLocalUpdateFile = UpdateFileName;
			
			EventLogClient.AddMessageForEventLog(NameLogEvents, "Information",
				NStr("en = 'Update distribution files are successfully uncompressed:'; ru = 'Файлы дистрибутива обновления успешно распакованы:';pl = 'Pliki dystrybucyjne zostały pomyślnie rozpakowane:';es_ES = 'Archivos de la distribución de actualizaciones se han descomprimido con éxito:';es_CO = 'Archivos de la distribución de actualizaciones se han descomprimido con éxito:';tr = 'Güncelleme dağıtım dosyaları başarıyla sıkıştırılmamış:';it = 'File della distribuzione dell''aggiornamento decompressi con successo:';de = 'Update-Distributionsdateien wurden erfolgreich dekomprimiert:'")
					+ " " + UpdateFileName);
		Except
			EventLogClient.AddMessageForEventLog(NameLogEvents, "Error",
				NStr("en = 'Error while unzipping the updates distribution'; ru = 'Ошибка при распаковке дистрибутива обновления:';pl = 'Błąd podczas rozpakowywania pliku aktualizacji';es_ES = 'Error al descomprimir la distribución de actualizaciones';es_CO = 'Error al descomprimir la distribución de actualizaciones';tr = 'Güncelleme dağıtımını açarken hata oluştu';it = 'Errore durante la decompressione della distribuzione degli aggiornamenti';de = 'Fehler beim Entpacken der Update-Verteilung'")
					+ " " + ErrorDescription());
			Return False;
		EndTry;
		
		Try
			ZipReader			= New ZipFileReader(Update.PathToLocalFile);
			DestinationDirectory	= ConfigurationUpdateClientDrive.GetUpdateParameters().UpdateFilesDir + Update.LocalRelativeDirectory;
			ZipReader.ExtractAll(DestinationDirectory, ZIPRestoreFilePathsMode.Restore);
			UpdateFileName	= DestinationDirectory + "1cv8.cfu";
			If Not FileExistsAtClient(UpdateFileName) Then
				EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), 
					"Error", NStr("en = 'Update distribution does not contain 1cv8.cfu:'; ru = 'Дистрибутив обновления не содержит 1cv8.cfu:';pl = 'Plik aktualizacji nie zawiera 1cv8.cfu:';es_ES = 'Distribución de actualizaciones no contiene 1cv8.cfu:';es_CO = 'Distribución de actualizaciones no contiene 1cv8.cfu:';tr = 'Güncelleme dağıtımı 1cv8.cfu içermiyor:';it = 'La distribuzione dell''aggiornamento non contiene 1cv8.cfu:';de = 'Update-Verteilung enthält nicht 1cv8.cfu:'")
						+ " " + Update.PathToLocalFile);
				Return False;
			EndIf;
			Update.PathToLocalUpdateFile = UpdateFileName;
			EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), 
				"Information", NStr("en = 'Update distribution files are successfully uncompressed:'; ru = 'Файлы дистрибутива обновления успешно распакованы:';pl = 'Pliki dystrybucyjne zostały pomyślnie rozpakowane:';es_ES = 'Archivos de la distribución de actualizaciones se han descomprimido con éxito:';es_CO = 'Archivos de la distribución de actualizaciones se han descomprimido con éxito:';tr = 'Güncelleme dağıtım dosyaları başarıyla sıkıştırılmamış:';it = 'File della distribuzione dell''aggiornamento decompressi con successo:';de = 'Update-Distributionsdateien wurden erfolgreich dekomprimiert:'")
					+ " " + UpdateFileName);
			ZipReader.Close();
		Except
			EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), 
				"Error",  NStr("en = 'Error while unzipping the updates distribution'; ru = 'Ошибка при распаковке дистрибутива обновления:';pl = 'Błąd podczas rozpakowywania pliku aktualizacji';es_ES = 'Error al descomprimir la distribución de actualizaciones';es_CO = 'Error al descomprimir la distribución de actualizaciones';tr = 'Güncelleme dağıtımını açarken hata oluştu';it = 'Errore durante la decompressione della distribuzione degli aggiornamenti';de = 'Fehler beim Entpacken der Update-Verteilung'")
					+ " " + ErrorDescription());
			Return False;
		EndTry;
	EndDo;
	Return True;
	#EndIf
EndFunction

&AtClient
Procedure GetAvailableUpdates(UpdateParameters, ConfigurationVersion, OutputMessages, AvailableUpdateForNextEdition = False)
	
	UpdateParameters = ConfigurationUpdateClientDrive.GetUpdateParameters(AvailableUpdateForNextEdition);
	PathToUpdateListFile = UpdateParameters.UpdateFilesDir +
		UpdateParameters.ListTemplatesFileName;
	FileURLTempStorage = PutToTempStorage(New BinaryData(PathToUpdateListFile));
	Try
		GetAvailableUpdatesInInterval(ConfigurationUpdateClientCachedDrive.ClientWorkParameters().ConfigurationVersion,
			ConfigurationVersion, FileURLTempStorage, ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
	Except
		If OutputMessages Then
			ShowMessageBox(, BriefErrorDescription(ErrorInfo()));
		EndIf;
	EndTry;
	
EndProcedure

// Receiving the layout list file from the server.
&AtClient
Function GetFileOfTemplatesList(Val OutputMessages = True, AvailableUpdateForNextEdition = False)
    #If Not WebClient Then
	UpdateParameters = ConfigurationUpdateClientDrive.GetUpdateParameters(AvailableUpdateForNextEdition);
	UpdateSettings = ConfigurationUpdateClientCachedDrive.ClientWorkParameters().UpdateSettings;
	PathToTemplatesListFile = UpdateParameters.UpdateFilesDir + UpdateParameters.ZIPFileNameOfListOfTemplates;
	
	Result = GetFilesFromInternetClient.DownloadFileAtClient(UpdateSettings.ServerAddressForVerificationOfUpdateAvailability +
		UpdateParameters.AddressOfResourcesForVerificationOfUpdateAvailability +	UpdateParameters.ZIPFileNameOfListOfTemplates,
		New Structure("PathForSaving", ? (IsBlankString(PathToTemplatesListFile), Undefined, PathToTemplatesListFile)));
	If Result.Status <> True Then
		Try
			DeleteFiles(PathToTemplatesListFile);
		Except
			EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(),
				"Error", 
				NStr("en = 'An error occurred while deleting a temporary file'; ru = 'Ошибка при удалении временного файла';pl = 'Podczas usuwania pliku tymczasowego wystąpił błąd';es_ES = 'Ha ocurrido un error al eliminar un archivo temporal';es_CO = 'Ha ocurrido un error al eliminar un archivo temporal';tr = 'Geçici bir dosya silinirken bir hata oluştu';it = 'Si è verificato un errore durante l''eliminazione di un file temporaneo';de = 'Beim Löschen einer temporären Datei ist ein Fehler aufgetreten'") + " " + PathToTemplatesListFile + Chars.LF +
				DetailErrorDescription(ErrorInfo()));
		EndTry;
		ErrorText = NStr("en = 'An error occurred when receiving a template list file:'; ru = 'Ошибка при получении файла списка шаблонов:';pl = 'Wystąpił błąd podczas pobierania pliku listy szablonów:';es_ES = 'Ha ocurrido un error al recibir un archivo de la lista de modelos:';es_CO = 'Ha ocurrido un error al recibir un archivo de la lista de modelos:';tr = 'Şablon listesi dosyası alınırken bir hata oluştu:';it = 'Si è verificato un errore durante la ricezione di un file di template elenco:';de = 'Beim Empfang einer Vorlagenlistendatei ist ein Fehler aufgetreten:'") + " " + Result.ErrorInfo;
		If OutputMessages Then
			ShowMessageBox(, ErrorText);
		EndIf; 
		Return ErrorText;
	EndIf;
	
	If Not FileExistsAtClient(PathToTemplatesListFile) Then
		Return NStr("en = 'File does not exist:'; ru = 'Файл не существует:';pl = 'Plik nie istnieje:';es_ES = 'Archivo no existe:';es_CO = 'Archivo no existe:';tr = 'Dosya bulunmuyor:';it = 'File inesistente:';de = 'Die Datei existiert nicht:'") + " " + PathToTemplatesListFile;
	EndIf;
	
	Try 
		ZipReader = New ZipFileReader(PathToTemplatesListFile);
		ZipReader.ExtractAll(UpdateParameters.UpdateFilesDir, ZIPRestoreFilePathsMode.DontRestore);
	Except
		ErrorText	= NStr("en = 'An error occurred when unpacking a file with available update list:'; ru = 'Ошибка при распаковке файла со списком доступных обновлений:';pl = 'Wystąpił błąd podczas rozpakowywania pliku z listą dostępnych aktualizacji:';es_ES = 'Ha ocurrido un error al descomprimir un archivo con la lista de actualizaciones disponibles:';es_CO = 'Ha ocurrido un error al descomprimir un archivo con la lista de actualizaciones disponibles:';tr = 'Mevcut güncelleme listesindeki bir dosya çıkarılırken hata oluştu:';it = 'Si è verificato un errore durante l''estrazione di un file con l''elenco aggiornamento disponibile:';de = 'Beim Entpacken einer Datei mit verfügbarer Update-Liste ist ein Fehler aufgetreten:'") + " ";
		InfoErrors	= ErrorInfo();
		EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), 
			"Error", ErrorText + DetailErrorDescription(InfoErrors));
		ErrorText	= ErrorText + BriefErrorDescription(InfoErrors);
		Return ErrorText;
	EndTry;
	DeleteFiles(UpdateParameters.UpdateFilesDir, UpdateParameters.ZIPFileNameOfListOfTemplates);
	Return "";
	#EndIf
EndFunction

// Check the existence of the file or directory.
//
// Parameter:
//  PathToFile   - String - path to the file or
//                 directory which existence shall be checked.
//
// Returns:
//  Boolean - flag showing the existence of file or directory.
&AtClient
Function FileExistsAtClient(Val PathToFile)
	File = New File(PathToFile);
	Return File.Exist();
EndFunction

&AtClient
Function GetUpdate(OutputMessages = True)
	
	Pages = Items.AssistantPages.ChildItems;
	Message = "";
	If Object.UpdateSource = 0 Then
		Message = Message + NStr("en = 'Receiving files from the Internet...'; ru = 'Получение файлов из Интернета...';pl = 'Pobieranie plików z Internetu...';es_ES = 'Recibiendo los archivos de Internet...';es_CO = 'Recibiendo los archivos de Internet...';tr = 'İnternet''ten dosya alma ...';it = 'Ricezione di file da Internet ...';de = 'Dateien aus dem Internet empfangen...'");
	Else
		Message = Message + NStr("en = 'Receiving update file from the specified source...'; ru = 'Получение файла обновления из указанного источника...';pl = 'Pobieranie pliku aktualizacji ze wskazanego źródła...';es_ES = 'Recibiendo el archivo de actualizaciones de la fuente especificada...';es_CO = 'Recibiendo el archivo de actualizaciones de la fuente especificada...';tr = 'Belirtilen kaynaktan güncelleme dosyası alınıyor ...';it = 'Acquisizione del file di aggiornamento dalla sorgente specificata...';de = 'Update-Datei von der angegebenen Quelle empfangen...'");
	EndIf;
	EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), 
		"Information", Message);
	
	Object.TechnicalErrorInfo = "";
	FileNumber = 1;
	For Each File In FileListForObtaining Do
		
		If File.Value <> Undefined AND File.Value.Received <> True Then	// It can also be Undefined.
			If Object.UpdateSource = 0 Then
				
				AuthenticationResult = ConfigurationUpdateClientDrive.CheckUpdateImportLegality(
					AuthenticationParameters());
				
				If Not AuthenticationResult.ResultValue Then
					
					Items.AccessGroupOnSite.CurrentPage = Items.AccessGroupOnSite.ChildItems.LegalityCheckError;
					ErrorText = NStr("en = 'Failed to confirm the update authentication through the Internet
					                 |due to: %1'; 
					                 |ru = 'Не удалось подтвердить легальность получения обновления через
					                 |Интернет по причине: %1';
					                 |pl = 'Nie udało się potwierdzić uwierzytelnienia aktualizacji przez Internet
					                 |z powodu: %1';
					                 |es_ES = 'Fallado a confirmar la autenticación de actualizaciones a través de Internet
					                 |debido a: %1';
					                 |es_CO = 'Fallado a confirmar la autenticación de actualizaciones a través de Internet
					                 |debido a: %1';
					                 |tr = 'İnternet üzerinden güncelleme kimlik doğrulaması aşağıdaki nedenle
					                 |doğrulanamadı: %1';
					                 |it = 'Non è stato possibile confermare la legittimità della ricezione dell''aggiornamento
					                 |Internet a causa di: %1';
					                 |de = 'Fehler beim Bestätigen der Update-Authentifizierung über das Internet
					                 |aufgrund von: %1'");
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, AuthenticationResult.ErrorText);
					Items.LegalityCheckErrorText.Title = ErrorText;
					Return Pages.ConnectionToSite.Name;
					
				EndIf;
				
				// Display the message of the file exporting to the log.
				Message = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = ' Get file %1 to %2'; ru = ' Получаем файл %1 в %2';pl = ' Pobierz plik %1 do %2';es_ES = 'Obtener el archivo %1 para %2';es_CO = 'Obtener el archivo %1 para %2';tr = '%1 dosyasını %2''den al';it = ' Acquisizione file %1 nel %2';de = 'Datei %1 nach %2 abrufen'"),
						ConfigurationUpdateClientDrive.GetUpdateParameters().AddressOfUpdatesServer + File.Value.Address,
						? (IsBlankString(File.Value.LocalPath), Undefined, File.Value.LocalPath));
				Items.LabelProgres.Title = Message;
				EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), , Message);
				
				CreateDirectory(ConfigurationUpdateClientDrive.GetFileDir(File.Value.LocalPath));
				Result	= GetFilesFromInternetClient.DownloadFileAtClient(
					ConfigurationUpdateClientDrive.GetUpdateParameters().AddressOfUpdatesServer + File.Value.Address,
					New Structure("PathForSaving, User, Password",
						? (IsBlankString(File.Value.LocalPath), Undefined, File.Value.LocalPath),
						Object.UpdateServerUserCode,
						Object.UpdatesServerPassword));
				ErrorText = "";
				If Result.Status <> True Then
					ErrorText = Result.ErrorInfo;
					Try
						DeleteFiles(File.Value.LocalPath);
					Except
						EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), 
							"Error", NStr("en = 'An error occurred while deleting a temporary file'; ru = 'Ошибка при удалении временного файла';pl = 'Podczas usuwania pliku tymczasowego wystąpił błąd';es_ES = 'Ha ocurrido un error al eliminar un archivo temporal';es_CO = 'Ha ocurrido un error al eliminar un archivo temporal';tr = 'Geçici bir dosya silinirken bir hata oluştu';it = 'Si è verificato un errore durante l''eliminazione di un file temporaneo';de = 'Beim Löschen einer temporären Datei ist ein Fehler aufgetreten'") + " " +
							File.Value.LocalPath + Chars.LF + DetailErrorDescription(ErrorInfo()));
					EndTry;
					If Not IsBlankString(ErrorText) Then
						If File.Value.IsRequired AND OutputMessages Then
							ShowMessageBox(, ErrorText);
							Return Pages.ConnectionToSite.Name;
						EndIf; 
					EndIf;
				EndIf;
				
				File.Value.Received = IsBlankString(ErrorText);
				
				If Not File.Value.Received AND File.Value.IsRequired Then
					Return Pages.ConnectionToSite.Name;
				EndIf;
			Else
				// Moving the message of the file copying to the log.
				Message = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = ' Get file %1 to %2'; ru = ' Получаем файл %1 в %2';pl = ' Pobierz plik %1 do %2';es_ES = 'Obtener el archivo %1 para %2';es_CO = 'Obtener el archivo %1 para %2';tr = '%1 dosyasını %2''den al';it = ' Acquisizione file %1 nel %2';de = 'Datei %1 nach %2 abrufen'"), File.Value.Address, File.Value.LocalPath);
				Items.LabelProgres.Title = Message;
				EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), , Message);
				
				File.Value.Received = CopyFile(File.Value.Address, File.Value.LocalPath, File.Value.IsRequired AND OutputMessages);
			EndIf;
		EndIf;
		FileNumber = FileNumber + 1;
	EndDo;
	
	PageName = "";
	If CheckUpdateFilesReceived() Then
		EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), 
			"Information", NStr("en = 'Update files are successfully received.'; ru = 'Файлы обновления успешно получены.';pl = 'Pliki aktualizacji odebrane pomyślnie.';es_ES = 'Archivos de actualización se han recibido con éxito.';es_CO = 'Archivos de actualización se han recibido con éxito.';tr = 'Güncelleme dosyaları başarıyla alındı.';it = 'File di aggiornamento ricevuti correttamente.';de = 'Update-Dateien werden erfolgreich empfangen.'"));
		GoToChoiceOfUpdateMode(True);
		Return Undefined;
	Else
		Message = NStr("en = 'An error occurred when receiving update files.'; ru = 'Ошибка при получении файлов обновления.';pl = 'Podczas odbierania plików aktualizacji wystąpił błąd.';es_ES = 'Ha ocurrido un error al recibir los archivos de actualizaciones.';es_CO = 'Ha ocurrido un error al recibir los archivos de actualizaciones.';tr = 'Güncelleme dosyaları alınırken bir hata oluştu.';it = 'Si è verificato un errore durante la ricezione di file di aggiornamento.';de = 'Beim Empfang von Update-Dateien ist ein Fehler aufgetreten.'");
		EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), 
			"Error", Message);
		PageName = Pages.FailureRefresh.Name;
	EndIf;
	Return PageName;
	
EndFunction

// The function that copyies the specified file to another one.
//
// Parameters:
// SourceFileName: string, path to the file to be copied.
// DestinationFileName: string, path to the file where the source shall be copied.
// DisplayMessage: Boolean, flag of the error message output.
//
&AtClient
Function CopyFile(FileNameSource, FileNamePurpose, OutputMessages = False)
	Try
		CreateDirectory(ConfigurationUpdateClientDrive.GetFileDir(FileNamePurpose));
		FileCopy(FileNameSource, FileNamePurpose);
	Except
		Message = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Error while
			     |copying: %1 (source:%2; receiver: %3)'; 
			     |ru = 'Ошибка
			     |при копировании: %1 (источник: %2; приемник: %3)';
			     |pl = 'Błąd podczas
			     |kopiowania: %1 (źródło:%2; cel: %3)';
			     |es_ES = 'Error al
			     |copiar: %1 (fuente:%2; destinatario: %3)';
			     |es_CO = 'Error al
			     |copiar: %1 (fuente:%2; destinatario: %3)';
			     |tr = 'Kopyalanırken 
			     |hata oluştu:%1 (kaynak:%2; alıcı:%3)';
			     |it = 'Errore durante
			     |la copia: %1 (fonte:%2; ricevitore: %3)';
			     |de = 'Fehler beim
			     |Kopieren: %1 (Quelle: %2; Empfänger: %3)'"), 
				DetailErrorDescription(ErrorInfo()),
				FileNameSource, FileNamePurpose);
		EventLogClient.AddMessageForEventLog(
			ConfigurationUpdateClient.EventLogEvent(), "Warning", Message);
		Return False;
	EndTry;
	Return True;
EndFunction

&AtClient
Function GetUpdateFilesViaInternet(OutputMessages, AvailableUpdateForNextEdition = False)
	
	Pages = Items.AssistantPages.ChildItems;
	AvailableUpdate = ConfigurationUpdateClientDrive.GetAvailableConfigurationUpdate();
	If AvailableUpdate.PageName = Pages.AvailableUpdate.Name Then
		
		ErrorText = GetFileOfTemplatesList(OutputMessages, AvailableUpdateForNextEdition);
		If Not IsBlankString(ErrorText) Then
			Return Pages.InternetConnection.Name;
		EndIf;
		
		FileNameInformationAboutUpdate	= GetFileOfUpdateDescription();
		FileNameOrderUpdate		= GetFileOfUpdateOrder();
		
		GetAvailableUpdates(AvailableUpdate.FileParametersUpdateChecks,
			AvailableUpdate.LastConfigurationVersion, OutputMessages, AvailableUpdateForNextEdition);
		LastConfigurationVersion = AvailableUpdate.LastConfigurationVersion;
		If Object.AvailableUpdates.Count() = 0 Then
			EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), 
				"Information", NStr("en = 'The update cannot proceed: no updates available.'; ru = 'Невозможно продолжить обновление: нет доступных обновлений.';pl = 'Kontynuacja aktualizacji nie jest możliwa: brak dostępnych aktualizacji.';es_ES = 'La actualización no puede procederse: no hay actualizaciones disponibles.';es_CO = 'La actualización no puede procederse: no hay actualizaciones disponibles.';tr = 'Güncelleme devam edemiyor: güncelleme yok.';it = 'L''aggiornamento non può procedere: nessuno aggiornamento disponibile.';de = 'Das Update kann nicht fortgesetzt werden: Keine Updates verfügbar.'"));
			Return Pages.UpdatesNotDetected.Name;
		EndIf;
		
	EndIf;
	
	Return AvailableUpdate.PageName;
	
EndFunction

&AtClient
Function CheckUpdateInternet(OutputMessages = True) 
	Pages		= Items.AssistantPages.ChildItems;
	EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), 
		"Information", NStr("en = 'Checking for updates online...'; ru = 'Проверка обновления в Интернете...';pl = 'Sprawdzanie aktualizacji w Internecie...';es_ES = 'Revisando las actualizaciones online...';es_CO = 'Revisando las actualizaciones online...';tr = 'Çevrimiçi güncellemeler kontrol ediliyor...';it = 'Verifica di aggiornamenti online...';de = 'Online nach Updates suchen...'"));
	AvailableUpdate = Undefined;
	Object.AvailableUpdates.Clear();
	
	ConfigurationUpdateClientDrive.CheckUpdateExistsViaInternet(OutputMessages, AvailableUpdateForNextEdition);
	
	Return GetUpdateFilesViaInternet(OutputMessages, AvailableUpdateForNextEdition);
EndFunction

&AtClient
Procedure RunUpdateObtaining()
	CurrentPage = Items.AssistantPages.CurrentPage;
	ResultGetFiles = GetUpdate();
	If ResultGetFiles = Undefined Then
		Return;
	EndIf;
	Items.AssistantPages.CurrentPage = CurrentPage;
	ProcessPressOfButtonNext();
EndProcedure

&AtClient
Function ReturnDate(Date, Time)
	Return Date(Year(Date), Month(Date), Day(Date), Hour(Time), Minute(Time), Second(Time));
EndFunction

&AtClient
Function CheckUpdateFile(OutputMessages = True)
	
	Pages = Items.AssistantPages.ChildItems;
	
	EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), 
		"Information",  NStr("en = 'Checking for updates online...'; ru = 'Проверка обновления в Интернете...';pl = 'Sprawdzanie aktualizacji w Internecie...';es_ES = 'Revisando las actualizaciones online...';es_CO = 'Revisando las actualizaciones online...';tr = 'Çevrimiçi güncellemeler kontrol ediliyor...';it = 'Verifica di aggiornamenti online...';de = 'Online nach Updates suchen...'"));
		
	Object.AvailableUpdates.Clear();
	
	If RestorationOfPreLaunch <> True Then
		Return Pages.UpdateFile.Name;
	EndIf;
	
	If Object.NeedUpdateFile = 1 Then
		File = New File(Object.UpdateFileName);
		If Not File.Exist() OR Not File.IsFile() Then
			
			EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), "Information",
				NStr("en = 'The update cannot proceed: the delivery file for configuration update was not found.'; ru = 'Невозможно продолжить обновление: файл поставки обновления конфигурации не найден.';pl = 'Kontynuacja aktualizacji nie jest możliwa: nie znaleziono pliku aktualizacji konfiguracji.';es_ES = 'La actualización no puede procederse: el archivo de envío para la actualización de configuraciones no se ha encontrado.';es_CO = 'La actualización no puede procederse: el archivo de envío para la actualización de configuraciones no se ha encontrado.';tr = 'Güncelleme devam edemiyor: yapılandırma güncellemesi için teslimat dosyası bulunamadı.';it = 'L''aggiornamento non può procedere: non è stato trovato il file di consegna per l''aggiornamento della configurazione.';de = 'Das Update kann nicht fortgesetzt werden: Die Lieferdatei für die Konfigurationsaktualisierung wurde nicht gefunden.'"));
				
			Return Pages.UpdateFile.Name;
		EndIf;
	EndIf;
	
	GetAvailableUpdateFromFile(?(Object.NeedUpdateFile = 1, Object.UpdateFileName, Undefined));
	GoToChoiceOfUpdateMode(True);
	Return Undefined;
	
EndFunction

&AtClient
Function LabelTextInfobaseBackup()
	
	Result = NStr("en = 'Do not back up the infobase'; ru = 'Не создавать резервную копию ИБ';pl = 'Nie twórz kopii zapasowej bazy informacyjnej';es_ES = 'No crear la copia de respaldo de la infobase';es_CO = 'No crear la copia de respaldo de la infobase';tr = 'Infobase''i yedekleme';it = 'Non eseguire il backup InfoBase';de = 'Die Infobase nicht sichern'");
	
	If Object.CreateBackup = 1 Then
		Result = NStr("en = 'Create temporary backup of infobase'; ru = 'Создавать временную резервную копию ИБ';pl = 'Utwórz tymczasową kopię zapasową bazy informacyjnej';es_ES = 'Crear una copia de respaldo temporal de la infobase';es_CO = 'Crear una copia de respaldo temporal de la infobase';tr = 'Geçici Infobase yedeği oluştur';it = 'Creare backup temporaneo del infobase';de = 'Erstellen Sie eine temporäre Sicherung der Infobase'");
	ElsIf Object.CreateBackup = 2 Then
		Result = NStr("en = 'Create infobase backup'; ru = 'Создавать резервную копию ИБ';pl = 'Utwórz kopię zapasową bazy informacyjnej';es_ES = 'Crear una copia de respaldo de la infobase';es_CO = 'Crear una copia de respaldo de la infobase';tr = 'Infobase yedeği oluştur';it = 'Creazione immagine database';de = 'Erstellen Sie eine Infobase-Sicherung'");
	EndIf; 
	
	If Object.RestoreInfobase Then
		Result = Result + " " + NStr("en = 'and roll back in case of error'; ru = 'и выполнять откат при нештатной ситуации';pl = 'i wycofaj w przypadku błędu';es_ES = 'y retroceder en el caso de un error';es_CO = 'y retroceder en el caso de un error';tr = 've hata durumunda geri dön';it = 'e tornare indietro in caso di errore';de = 'und im Falle eines Fehlers zurückrollen'");
	Else
		Result = Result + " " + NStr("en = 'and do not roll back in case of error'; ru = 'и не выполнять откат при нештатной ситуации';pl = 'i nie wycofuj w przypadku błędu';es_ES = 'y no retroceder en el caso de un error';es_CO = 'y no retroceder en el caso de un error';tr = 've hata durumunda geri dönme';it = 'e non tornare indietro in caso di errore';de = 'und im Falle eines Fehlers nicht zurückrollen'");
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure RunConfigurationUpdate()
	
	DeleteSchedulerTask(Object.SchedulerTaskCode);
	ScriptMainFileName = GenerateUpdateScriptFiles(True);
	EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), "Information",
		NStr("en = 'Updating configuration:'; ru = 'Выполняется процедура обновления конфигурации:';pl = 'Trwa aktualizacja konfiguracji:';es_ES = 'Actualizando la configuración:';es_CO = 'Actualizando la configuración:';tr = 'Güncelleme yapılandırması:';it = 'Aggiornamento configurazione in corso:';de = 'Konfiguration aktualisieren:'")
			+ " " + ScriptMainFileName);
	WriteUpdateStatus(UserName(), True, False, False, ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
	
	LaunchString = "cmd /c """"%1"""" [p1]%2[/p1][p2]%3[/p2]";
	LaunchString = StringFunctionsClientServer.SubstituteParametersToString(LaunchString, ScriptMainFileName,
		AdministrationParameters.InfobaseAdministratorPassword, AdministrationParameters.ClusterAdministratorPassword);
	Shell = New COMObject("Wscript.Shell");
	Shell.RegWrite("HKCU\Software\Microsoft\Internet Explorer\Styles\MaxScriptStatements", 1107296255, "REG_DWORD");
	Shell.Run(LaunchString, 0);
	
EndProcedure

&AtServerNoContext
Procedure WriteUpdateStatus(UpdateAdministratorName, RefreshEnabledPlanned, RefreshCompleted, UpdateResult,
	MessagesForEventLogMonitor = Undefined)
	
	ConfigurationUpdate.WriteUpdateStatus(
		UpdateAdministratorName,
		RefreshEnabledPlanned,
		RefreshCompleted,
		UpdateResult,
		MessagesForEventLogMonitor);
	
EndProcedure

&AtClient
Function ObjectWMI()
	// WMI: http://www.microsoft.com/technet/scriptcenter/resources/wmifaq.mspx.
	Locator = New COMObject("WbemScripting.SWbemLocator");
	Return Locator.ConnectServer(".", "\root\cimv2");
EndFunction

&AtClient
Function GetSchedulerTask(Val CodeTasks)
	If CodeTasks = 0 Then
		Return Undefined;
	EndIf; 
	
	Try
		Return ObjectWMI().Get("Win32_ScheduledJob.JobID=" + CodeTasks);
	Except
		Return Undefined;
	EndTry; 
EndFunction

&AtClient
Function ItIsPossibleToStartUpdate()
	
	ItIsPossibleToStartUpdate = True;
	
	#If WebClient Then
		ItIsPossibleToStartUpdate = False;
		MessageText = NStr("en = 'Updating the application in web client is unavailable.'; ru = 'Обновление программы недоступно в веб-клиенте.';pl = 'Aktualizacja aplikacji w kliencie sieci Web jest niedostępna.';es_ES = 'Actualización de la aplicación en el cliente web no se encuentra disponible.';es_CO = 'Actualización de la aplicación en el cliente web no se encuentra disponible.';tr = 'Uygulamanın web istemcisinde güncellenmesi mümkün değildir.';it = 'Aggiornamento dell''applicazione nel client Web non è disponibile.';de = 'Das Aktualisieren der Anwendung im Webclient ist nicht möglich.'");
	#EndIf
	
	If CommonClientServer.IsLinuxClient() Then
		ItIsPossibleToStartUpdate = False;
		MessageText = NStr("en = 'Updating the application is unavailable under Linux OS.'; ru = 'Обновление программы недоступно в клиенте под управлением ОС Linux.';pl = 'Aktualizacja aplikacji w systemie operacyjnym Linux jest niedostępna.';es_ES = 'Actualización de la aplicación no se encuentra disponible bajo el sistema operativo Linux.';es_CO = 'Actualización de la aplicación no se encuentra disponible bajo el sistema operativo Linux.';tr = 'Uygulamanın güncellenmesi Linux OS altında mevcut değildir.';it = 'Aggiornamento dell''applicazione non è disponibile con sistema operativo Linux.';de = 'Die Aktualisierung der Anwendung ist unter Linux Betriebssystem nicht möglich.'");
	EndIf;
	
	If CommonClient.ClientConnectedOverWebServer() Then
		ItIsPossibleToStartUpdate = False;
		MessageText = NStr("en = 'Updating the application using web server connection is unavailable.'; ru = 'Обновление программы недоступно при подключении через веб-сервер.';pl = 'Aktualizacja aplikacji przy użyciu połączenia z serwerem sieciowym jest niedostępna.';es_ES = 'Actualización de la aplicación utilizando la conexión del servidor web no se encuentra disponible.';es_CO = 'Actualización de la aplicación utilizando la conexión del servidor web no se encuentra disponible.';tr = 'Web sunucusu bağlantısını kullanarak uygulamanın güncellenmesi mümkün değildir.';it = 'L''aggiornamento del programma non è disponibile durante la connessione tramite un server web.';de = 'Das Aktualisieren der Anwendung über die Webserververbindung ist nicht möglich.'");
	EndIf;
	
	If Not ItIsPossibleToStartUpdate Then
		
		ShowMessageBox(, MessageText);
		EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(),,
			MessageText,,True);
		
	EndIf;
		
	Return ItIsPossibleToStartUpdate;
	
EndFunction

&AtClient
Procedure DisplayUpdateOrder()
	
	If Not IsBlankString(FileNameOrderUpdate) Then
		ConfigurationUpdateClientDrive.OpenWebPage(FileNameOrderUpdate);
	Else
		ShowMessageBox(, NStr("en = 'Update order description is missing.'; ru = 'Описание порядка обновления отсутствует.';pl = 'Brak opisu kolejności aktualizacji.';es_ES = 'Falta la descripción del orden de la actualización.';es_CO = 'Falta la descripción del orden de la actualización.';tr = 'Güncelleme siparişi açıklaması eksik.';it = 'La descrizione dell''ordine aggiornato è mancante.';de = 'Update Bestellbeschreibung fehlt.'"));
	EndIf;
	
EndProcedure

&AtServer
Function PerformIBTableCompression()
	
	If Object.AvailableUpdates.Count() = 0 Then
		Return False;
	EndIf;
	
	AvailableVersion = CommonClientServer.ConfigurationVersionWithoutBuildNumber(Object.AvailableUpdates[Object.AvailableUpdates.Count()-1].Version);
	
	If IsBlankString(AvailableVersion) Then
		Return False;
	EndIf;
	
	CurrentVersion = CommonClientServer.ConfigurationVersionWithoutBuildNumber(Metadata.Version);
	
	Return CommonClientServer.CompareVersionsWithoutBuildNumber(AvailableVersion, CurrentVersion) > 0;
	
EndFunction

&AtServer
Function PlatformUpdateIsNeeded(RequiredVersion)
	
	If Not ValueIsFilled(RequiredVersion) Then
		Return False;
	EndIf;
	
	SystemInfo = New SystemInfo;
	CurrentPlatformVersion = SystemInfo.AppVersion;
	
	Return CommonClientServer.CompareVersions(RequiredVersion, CurrentPlatformVersion) > 0;
	
EndFunction

#EndRegion

