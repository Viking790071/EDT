#Region Internal

// Sets the parameter that cancels the desktop form creating.
// The procedure is used if there is a need to interact with the user during the startup.
// 
//
// Used from the StandardSubsystemsClient module procedure of the same name.
// The direct call on server has the meaning for reducing server call numbers if during preparing 
// client parameters with Cached module it is already known that interactive processing is required.
// 
//
// If the client parameter getting procedure directly calls this procedure, the state on the client 
// is updated automatically, otherwise use the StandardSubsystemsClient module procedure of the same 
// name to update it.
// 
//
// Parameters:
//  Hide - Boolean - pass True to set the state or False to clear it. You can call the 
//           RefreshInterface method once the procedure is executed to recreate the interface.
//           
//           
//
Procedure HideDesktopOnStart(Hide = True) Export
	
	If CurrentRunMode() = Undefined Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	// Saving or restoring the home page form content.
	ObjectKey         = "Common/HomePageSettings";
	StorageObjectKey = "Common/HomePageSettingsBeforeClear";
	SavedSettings = SystemSettingsStorage.Load(StorageObjectKey, "");
	
	If TypeOf(Hide) <> Type("Boolean") Then
		Hide = TypeOf(SavedSettings) = Type("ValueStorage");
	EndIf;
	
	If Hide Then
		If TypeOf(SavedSettings) <> Type("ValueStorage") Then
			CurrentSettings = SystemSettingsStorage.Load(ObjectKey);
			SettingsToSave = New ValueStorage(CurrentSettings);
			SystemSettingsStorage.Save(StorageObjectKey, "", SettingsToSave);
		EndIf;
		StandardSubsystemsServer.SetBlankFormOnHomePage();
	Else
		If TypeOf(SavedSettings) = Type("ValueStorage") Then
			SavedSettings = SavedSettings.Get();
			If SavedSettings = Undefined Then
				SystemSettingsStorage.Delete(ObjectKey, Undefined,
					InfoBaseUsers.CurrentUser().Name);
			Else
				SystemSettingsStorage.Save(ObjectKey, "", SavedSettings);
			EndIf;
			SystemSettingsStorage.Delete(StorageObjectKey, Undefined,
				InfoBaseUsers.CurrentUser().Name);
		EndIf;
	EndIf;
	
	CurrentParameters = New Map(SessionParameters.ClientParametersAtServer);
	
	If Hide Then
		CurrentParameters.Insert("HideDesktopOnStart", True);
		
	ElsIf CurrentParameters.Get("HideDesktopOnStart") <> Undefined Then
		CurrentParameters.Delete("HideDesktopOnStart");
	EndIf;
	
	SessionParameters.ClientParametersAtServer = New FixedMap(CurrentParameters);
	
EndProcedure

#EndRegion

#Region Private

// Returns the structure of parameters required for the operation of the client code configuration, 
// that is in the BeforeStart, OnStart event handlers.
//
// To be called only from StandardSubsystemsClientCached.ClientParametersOnStart.
//
Function ClientParametersOnStart(Parameters) Export
	
	NewParameters = New Structure;
	AddTimeAdjustments(NewParameters, Parameters);
	
	StoreTempParameters(Parameters);
	CommonClientServer.SupplementStructure(Parameters, NewParameters);
	
	HandleClientParametersAtServer(Parameters);
	
	If Parameters.RetrievedClientParameters <> Undefined Then
		If NOT Parameters.Property("SkipClearingDesktopHiding") Then
			// Update the home page hiding state if when the previous start was failed before the regular 
			// recovery.
			HideDesktopOnStart(Undefined);
		EndIf;
	EndIf;
	
	If NOT StandardSubsystemsServer.AddClientParametersOnStart(Parameters) Then
		Return FixedClientParametersWithoutTemporaryParameters(Parameters);
	EndIf;
	
	UsersInternal.OnAddClientParametersOnStart(Parameters, Undefined, False);
	
	SSLSubsystemsIntegration.OnAddClientParametersOnStart(Parameters);
	
	AppliedParameters = New Structure;
	CommonOverridable.ClientParametersOnStart(AppliedParameters);
	For Each Parameter In AppliedParameters Do
		Parameters.Insert(Parameter.Key, Parameter.Value);
	EndDo;
	
	AppliedParameters = New Structure;
	CommonOverridable.OnAddClientParametersOnStart(AppliedParameters);
	For Each Parameter In AppliedParameters Do
		Parameters.Insert(Parameter.Key, Parameter.Value);
	EndDo;
	
	Return FixedClientParametersWithoutTemporaryParameters(Parameters);
	
EndFunction

// Returns the structure of parameters required for the operation of the client code configuration.
// To be called only from StandardSubsystemsClientCached.ClientRunParameters.
//
Function ClientRunParameters(ClientProperties) Export
	
	Parameters = New Structure;
	AddTimeAdjustments(Parameters, ClientProperties);
	
	SSLSubsystemsIntegration.OnAddClientParameters(Parameters);
	
	AppliedParameters = New Structure;
	CommonOverridable.ClientRunParameters(AppliedParameters);
	For Each Parameter In AppliedParameters Do
		Parameters.Insert(Parameter.Key, Parameter.Value);
	EndDo;
	
	AppliedParameters = New Structure;
	CommonOverridable.OnAddClientParameters(AppliedParameters);
	For Each Parameter In AppliedParameters Do
		Parameters.Insert(Parameter.Key, Parameter.Value);
	EndDo;
	
	Return Common.FixedData(Parameters);
	
EndFunction

// See SaaS.SetSessionSeparation. 
Procedure SetSessionSeparation(Val Usage, Val DataArea = Undefined) Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		ModuleSaaS.SetSessionSeparation(Usage, DataArea);
	EndIf;
	
EndProcedure

// Checks the right to disable the system logic and hides the desktop on the server if there is the 
// right, otherwise an exception is thrown.
// 
// 
Procedure CheckDisableStartupLogicRight() Export
	
	HideDesktopOnStart(True);
	
	SignInToDataArea = Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable();
	
	If Not SignInToDataArea
	   AND Not AccessRight("Administration", Metadata)
	 Or SignInToDataArea
	   AND Not AccessRight("DataAdministration", Metadata) Then
		
		Raise NStr("ru = 'Недостаточно прав для работы с отключенной логикой работы системы.'; en = 'Insufficient rights to disable startup logic.'; pl = 'Nie masz wystarczających uprawnień do pracy z odłączoną logiką działania systemu.';es_ES = 'Insuficientes derechos para usar lógica del uso del sistema desactivada.';es_CO = 'Insuficientes derechos para usar lógica del uso del sistema desactivada.';tr = 'Devre dışı bırakılmış sistem mantığı ile çalışmak için yeterli hak yok.';it = 'Diritti insufficienti per lavorare con logica di inizio di funzionamento del sistema disabilitata.';de = 'Unzureichende Rechte für die Arbeit mit deaktivierter Systemlogik.'");
	EndIf;
	
	UsersInternal.CheckCurrentUserRightsOnAuthorization();
	
EndProcedure

// For internal use only.
Function WriteErrorToEventLogOnStartOrExit(Shutdown, Val Event, Val ErrorText) Export
	
	If Event = "Startup" Then
		EventName = NStr("ru = 'Запуск программы'; en = 'Application startup'; pl = 'Uruchom aplikację';es_ES = 'Iniciar la aplicación';es_CO = 'Iniciar la aplicación';tr = 'Uygulamayı başlat';it = 'Avvio del programma';de = 'Starten Sie die Anwendung'", CommonClientServer.DefaultLanguageCode());
		If Shutdown Then
			ErrorDescriptionBeginning = NStr("ru = 'Возникла исключительная ситуация при запуске программы. Запуск программы аварийно завершен.'; en = 'An exception occurred during the application startup. The application is closed.'; pl = 'Wyjątek jest zgłaszany podczas uruchamiania aplikacji. Uruchomienie aplikacji zostało przerwane.';es_ES = 'Ha surgido una excepción al iniciar la aplicación. Lanzamiento de la aplicación tiene que cancelarse.';es_CO = 'Ha surgido una excepción al iniciar la aplicación. Lanzamiento de la aplicación tiene que cancelarse.';tr = 'Uygulamayı başlatırken bir olağandışı durum oluştu. Uygulama başlaması iptal edildi.';it = 'Si è verificata un''eccezione all''avvio dell''applicazione. L''applicazione è stata chiusa.';de = 'Beim Starten der Anwendung wird eine Ausnahme ausgelöst. Anwendungsstart wird abgebrochen.'");
		Else
			ErrorDescriptionBeginning = NStr("ru = 'Возникла исключительная ситуация при запуске программы.'; en = 'An exception occurred during the application startup.'; pl = 'Wyjątek jest zgłaszany podczas uruchamiania aplikacji.';es_ES = 'Ha surgido una excepción al iniciar la aplicación.';es_CO = 'Ha surgido una excepción al iniciar la aplicación.';tr = 'Uygulamayı başlatırken bir olağandışı durum oluştu.';it = 'Si è verificata un''eccezione all''avvio del programma.';de = 'Beim Starten der Anwendung wird eine Ausnahme ausgelöst.'");
		EndIf;
	Else
		EventName = NStr("ru = 'Завершение программы'; en = 'Exit from application'; pl = 'Zamknij aplikację';es_ES = 'Salir de la aplicación';es_CO = 'Salir de la aplicación';tr = 'Uygulamadan çık';it = 'Uscita dall''applicazione';de = 'Anwendung verlassen'", CommonClientServer.DefaultLanguageCode());
		ErrorDescriptionBeginning = NStr("ru = 'Возникла исключительная ситуация при завершении программы.'; en = 'An exception occurred while exiting the application.'; pl = 'Podczas zamykania aplikacji generowany jest wyjątek.';es_ES = 'Ha surgido una excepción al cerrar la aplicación.';es_CO = 'Ha surgido una excepción al cerrar la aplicación.';tr = 'Uygulama kapatılırken olağandışı bir durum oluştu';it = 'Si è verificata un''eccezione durante la chiusura del programma.';de = 'Beim Schließen der Anwendung wird eine Ausnahme ausgelöst.'");
	EndIf;
	
	ErrorDescription = ErrorDescriptionBeginning
		+ Chars.LF + Chars.LF
		+ ErrorText;
	WriteLogEvent(EventName, EventLogLevel.Error,,, ErrorDescription);
	Return ErrorDescriptionBeginning;

EndFunction

// Called from an idle handler every 20 minutes, for example, for controlling dynamic update or user 
// account expiration.
//
// Parameters:
//  Parameters - Structure - properties should be inserted to the structure for further analysis on the client.
//
Procedure OnExecuteStandardDinamicChecksAtServer(Parameters) Export
	
	Parameters.Insert("DataBaseConfigurationChangedDynamically", DataBaseConfigurationChangedDynamically()
		Or Catalogs.ExtensionsVersions.ExtensionsChangedDynamically());
	
	UsersInternal.OnExecuteStandardDinamicChecksAtServer(Parameters);
    
    If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
        
        ModuleMonitoringCenterInternal = Common.CommonModule("MonitoringCenterInternal");
		ModuleMonitoringCenterInternal.OnExecuteStandardDinamicChecksAtServer(Parameters.MonitoringCenter);
               
    EndIf;
    	
EndProcedure

// Returns full metadata object name by its type.
Function FullMetadataObjectName(Type) Export
	MetadataObject = Metadata.FindByType(Type);
	If MetadataObject = Undefined Then
		Return Undefined;
	EndIf;
	Return MetadataObject.FullName();
EndFunction

// Returns a metadata object name by type.
//
// Parameters:
//  Source - Type - object.
// 
// Returns:
//   String.
Function MetadataObjectName(Type) Export
	MetadataObject = Metadata.FindByType(Type);
	If MetadataObject = Undefined Then
		Return Undefined;
	EndIf;
	Return MetadataObject.Name;
EndFunction

// See StandardSubsystemsServer.LibraryVersion. 
Function LibraryVersion() Export
	
	Return StandardSubsystemsServer.LibraryVersion();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Predefined data processing.

// See StandardSubsystemsCached.RefsByPredefinedItemsNames 
Function RefsByPredefinedItemsNames(FullMetadataObjectName) Export
	
	Return StandardSubsystemsCached.RefsByPredefinedItemsNames(FullMetadataObjectName);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

Procedure AddTimeAdjustments(Parameters, ClientProperties)
	
	SessionDate = CurrentSessionDate();
	UniversalSessionDate = ToUniversalTime(SessionDate, SessionTimeZone());
	
	Parameters.Insert("SessionTimeOffset", SessionDate - ClientProperties.CurrentDateOnClient);
	Parameters.Insert("UniversalTimeCorrection", UniversalSessionDate - SessionDate);
	Parameters.Insert("StandardTimeOffset", StandardTimeOffset(SessionTimeZone()));
	Parameters.Insert("ClientDateOffset", CurrentUniversalDateInMilliseconds()
		- ClientProperties.CurrentUniversalDateInMillisecondsOnClient);
	
EndProcedure

Procedure StoreTempParameters(Parameters)
	
	Parameters.Insert("TempParameterNames", New Array);
	
	For each KeyAndValue In Parameters Do
		Parameters.TempParameterNames.Add(KeyAndValue.Key);
	EndDo;
	
EndProcedure

Procedure HandleClientParametersAtServer(Val Parameters)
	
	PrivilegedModeSetOnStart = PrivilegedMode();
	SetPrivilegedMode(True);
	
	If SessionParameters.ClientParametersAtServer.Count() = 0 Then
		// First server call from client after start.
		ClientParameters = New Map;
		ClientParameters.Insert("LaunchParameter", Parameters.LaunchParameter);
		ClientParameters.Insert("InfobaseConnectionString", Parameters.InfobaseConnectionString);
		ClientParameters.Insert("PrivilegedModeSetOnStart", PrivilegedModeSetOnStart);
		ClientParameters.Insert("IsWebClient", Parameters.IsWebClient);
		ClientParameters.Insert("IsMacOSWebClient", Parameters.IsMacOSWebClient);
		ClientParameters.Insert("IsMobileClient", Parameters.IsMobileClient);
		ClientParameters.Insert("IsLinuxClient", Parameters.IsLinuxClient);
		ClientParameters.Insert("IsOSXClient", Parameters.IsOSXClient);
		ClientParameters.Insert("IsWindowsClient", Parameters.IsWindowsClient);
		ClientParameters.Insert("ClientUsed", Parameters.ClientUsed);
		ClientParameters.Insert("RAM", Parameters.RAM);
		ClientParameters.Insert("ApplicationDirectory", Parameters.ApplicationDirectory);
		ClientParameters.Insert("ClientID", Parameters.ClientID);
		ClientParameters.Insert("MainDisplayResolution", Parameters.MainDisplayResolution);
		SessionParameters.ClientParametersAtServer = New FixedMap(ClientParameters);
		
		If StrFind(Lower(Parameters.LaunchParameter), Lower("StartInfobaseUpdate")) > 0 Then
			InfobaseUpdateInternal.SetInfobaseUpdateStartup(True);
		EndIf;
		
		If Not Common.DataSeparationEnabled() Then
			If ExchangePlans.MasterNode() <> Undefined
				Or ValueIsFilled(Constants.MasterNode.Get()) Then
				// Preventing accidental predefined data update in a subordinate DIB node:
				// - when starting with temporarily disabled master node.
				// - when restructing data during a node recovery process.
				If GetInfoBasePredefinedData()
					<> PredefinedDataUpdate.DontAutoUpdate Then
					SetInfoBasePredefinedDataUpdate(
					PredefinedDataUpdate.DontAutoUpdate);
				EndIf;
				If ExchangePlans.MasterNode() <> Undefined
					AND Not ValueIsFilled(Constants.MasterNode.Get()) Then
					// Saving the master node for recovery purpose.
					StandardSubsystemsServer.SaveMasterNode();
				EndIf;
			EndIf;
		EndIf;
	EndIf;

EndProcedure

Function FixedClientParametersWithoutTemporaryParameters(Parameters)
	
	ClientParameters = Parameters;
	Parameters = New Structure;
	
	For each TemporaryParameterName In ClientParameters.TempParameterNames Do
		Parameters.Insert(TemporaryParameterName, ClientParameters[TemporaryParameterName]);
		ClientParameters.Delete(TemporaryParameterName);
	EndDo;
	Parameters.Delete("TempParameterNames");
	
	SetPrivilegedMode(True);
	
	Parameters.HideDesktopOnStart =
		SessionParameters.ClientParametersAtServer.Get(
			"HideDesktopOnStart") <> Undefined;
	
	SetPrivilegedMode(False);
	
	Return Common.FixedData(ClientParameters);
	
EndFunction

#EndRegion
