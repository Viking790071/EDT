#Region Internal

// Checks whether it is necessary to update the shared infobase data during configuration version 
// change.
//
Function SharedInfobaseDataUpdateRequired() Export
	
	SetPrivilegedMode(True);
	
	If Common.DataSeparationEnabled() Then
		
		MetadataVersion = Metadata.Version;
		If IsBlankString(MetadataVersion) Then
			MetadataVersion = "0.0.0.0";
		EndIf;
		
		SharedDataVersion = IBVersion(Metadata.Name, True);
		
		If UpdateRequired(MetadataVersion, SharedDataVersion) Then
			Return True;
		EndIf;
		
		If NOT Common.SeparatedDataUsageAvailable() Then
			
			SetPrivilegedMode(True);
			Run = SessionParameters.ClientParametersAtServer.Get("StartInfobaseUpdate");
			SetPrivilegedMode(False);
			
			If Run <> Undefined AND CanUpdateInfobase() Then
				Return True;
			EndIf;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

// Execute noninteractive infobase update.
//
// Parameters:
// 
//  UpdateParameters - Structure - properties:
//    * ExceptionOnCannotLockIB - Boolean - if False, then in case of unsuccessful attempt to set an 
//                 exclusive mode, an exception is not called and a "ExclusiveModeSettingError" 
//                 string returns.
// 
//    * OnClientStart - Boolean - False by default. If set to True, the application operating 
//                 parameters are not updated, because on client start they are updated first 
//                 (before user authorization and infobase update).
//                 This parameter is used to optimize the client start mode by avoiding repeated 
//                 updates of application operating parameters.
//                 In case of external call (for example, in external connection session), 
//                 application operating parameters must be updated before the infobase update can proceed.
//    * Restart             - Boolean - (return value) restart is necessary in some OnClientStart 
//                                  cases (for example, in case the subordinate DIB node is being 
//                                  returned to the database configuration). See the common module 
//                                  DataExchangeServer procedure.
//                                  SynchronizeWithoutInfobaseUpdate.
//    * IBLockSet - Structure - for the list of properties, see InfobaseLock(). 
//    * InBackground                     - Boolean - if an infobase update is executed on a 
//                 background, the True value should be passed, otherwise it will be False.
//    * ExecuteDeferredHandlers - Boolean - if True, then a deferred update will be executed in the 
//                 default update mode. Only for a client-server mode.
// 
// Returns:
//  String -  update hadlers execution flag:
//           "Done", "NotRequired", "ExclusiveModeSettingError".
//
Function UpdateInfobase(UpdateParameters) Export
	
	If Not UpdateParameters.OnClientStart Then
		Try
			InformationRegisters.ApplicationParameters.ImportUpdateApplicationParameters();
		Except
			WriteError(DetailErrorDescription(ErrorInfo()));
			Raise;
		EndTry;
	EndIf;
	
	DeferredUpdateMode = DeferredUpdateMode(UpdateParameters);
	
	// Checking whether the configuration name is changed.
	
	DataUpdateMode = DataUpdateMode();
	MetadataVersion = Metadata.Version;
	If IsBlankString(MetadataVersion) Then
		MetadataVersion = "0.0.0.0";
	EndIf;
	DataVersion = IBVersion(Metadata.Name);
	
	// Before infobase update.
	//
	If Common.SubsystemExists("StandardSubsystems.SaaS.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.BeforeUpdateInfobase();
		
		// Enabling privileged mode to allow infobase update SaaS, in case the data area administrator 
		// accesses the area before it is fully updated.
		If Common.DataSeparationEnabled() AND Common.SeparatedDataUsageAvailable() Then
			SetPrivilegedMode(True);
		EndIf;
		
	EndIf;
	
	// Importing and exporting exchange messages after restart, as configuration changes are received.
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.BeforeUpdateInfobase(UpdateParameters.OnClientStart, UpdateParameters.Restart);
	EndIf;
		
	If NOT InfobaseUpdate.InfobaseUpdateRequired() Then
		Return "NotRequired";
	EndIf;
	
	If UpdateParameters.InBackground Then
		TimeConsumingOperations.ReportProgress(1);
	EndIf;
	
	SubsystemsDetails  = StandardSubsystemsCached.SubsystemsDetails();
	For each SubsystemName In SubsystemsDetails.Order Do
		SubsystemDetails = SubsystemsDetails.ByNames.Get(SubsystemName);
		If NOT ValueIsFilled(SubsystemDetails.MainServerModule) Then
			Continue;
		EndIf;
		Module = Common.CommonModule(SubsystemDetails.MainServerModule);
		Module.BeforeUpdateInfobase();
	EndDo;
	InfobaseUpdateOverridable.BeforeUpdateInfobase();
	
	// Verifying rights to update the infobase.
	If NOT CanUpdateInfobase() Then
		Message = NStr("ru = 'Недостаточно прав для обновления версии программы.'; en = 'Insufficient rights for upgrading to a new application version.'; pl = 'Nie posiadasz wystarczających uprawnień, aby zaktualizować wersję aplikacji.';es_ES = 'Insuficientes derechos para actualizar la versión de la aplicación.';es_CO = 'Insuficientes derechos para actualizar la versión de la aplicación.';tr = 'Uygulama sürümünü güncellemek için yetersiz haklar.';it = 'Autorizzazioni sufficienti per aggiornare la versione del programma.';de = 'Unzureichende Rechte zum Aktualisieren der Anwendungsversion.'");
		WriteError(Message);
		Raise Message;
	EndIf;
	
	If DataUpdateMode = "MigrationFromAnotherApplication" Then
		Message = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Изменилось имя конфигурации на ""%1"".
			           |Будет выполнен переход с другой программы.'; 
			           |en = 'The configuration name changed to ""%1"".
			           |Migration from another application will be performed.'; 
			           |pl = 'Zmiana nazwy konfiguracji na %1.
			           |Zostaniesz przeniesiony z innej aplikacji.';
			           |es_ES = 'Cambiar el nombre de la configuración para %1.
			           |Usted estará transitado desde otra aplicación.';
			           |es_CO = 'Cambiar el nombre de la configuración para %1.
			           |Usted estará transitado desde otra aplicación.';
			           |tr = 'Yapılandırma adını değiştirin%1.
			           | Başka bir uygulamadan aktarılacaksınız.';
			           |it = 'Il nome della configurazione è cambiato in ""%1"".
			           |Si passa da un altro programma.';
			           |de = 'Ändern Sie den Konfigurationsnamen in %1.
			           |Sie werden von einer anderen Anwendung weitergeleitet.'"),
			Metadata.Name);
	ElsIf DataUpdateMode = "VersionUpdate" Then
		Message = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Изменился номер версии конфигурации: с ""%1"" на ""%2"".
			           |Будет выполнено обновление информационной базы.'; 
			           |en = 'The configuration version number changed from %1 to %2.
			           |Infobase update will be performed.'; 
			           |pl = 'Zmiana numeru wersji konfiguracji: z %1 na %2.
			           |Zostanie przeprowadzona aktualizacja bazy informacyjnej.';
			           |es_ES = 'Número de la versión de la configuración: desde %1 hasta %2.
			           |Actualización de la infobase se realizará.';
			           |es_CO = 'Número de la versión de la configuración: desde %1 hasta %2.
			           |Actualización de la infobase se realizará.';
			           |tr = 'Yapılandırma versiyonunun numarası: %2 ile 
			           | arasında %1 veri tabanı güncellenecektir.';
			           |it = 'Il numero della versione di configurazione è cambiato da %1 a %2.
			           |L''infobase verrà aggiornato.';
			           |de = 'Nummer der Konfigurationsversion: von %1 bis %2.
			           |Infobase-Update wird durchgeführt.'"),
			DataVersion, MetadataVersion);
	Else
		Message = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Выполняется начальное заполнение данных до версии ""%1"".'; en = 'Populating initial data for version %1.'; pl = 'Trwa początkowe wypełnienie danych do wersji ""%1"".';es_ES = 'Población de datos iniciales hasta la versión ""%1"" está en progreso.';es_CO = 'Población de datos iniciales hasta la versión ""%1"" está en progreso.';tr = '""%1"" Sürümüne kadar ilk veri doldurulması devam ediyor.';it = 'Inserimento dei dati iniziali per la versione %1.';de = 'Die erste Datenpopulation bis zur Version ""%1"" ist in Bearbeitung.'"),
			MetadataVersion);
	EndIf;
	WriteInformation(Message);
	
	// Locking the infobase.
	LockAlreadySet = UpdateParameters.IBLockSet <> Undefined 
		AND UpdateParameters.IBLockSet.Use;
	If LockAlreadySet Then
		UpdateIterations = UpdateIterations();
		IBLock = UpdateParameters.IBLockSet;
	Else
		IBLock = Undefined;
		UpdateIterations = LockIB(IBLock, UpdateParameters.ExceptionOnCannotLockIB);
		If IBLock.Error <> Undefined Then
			Return IBLock.Error;
		EndIf;
	EndIf;
	
	SeamlessUpdate = IBLock.NonexclusiveUpdate;
	RecordKey = IBLock.RecordKey;
	
	Try
		
		If DataUpdateMode = "MigrationFromAnotherApplication" Then
			
			MigrateFromAnotherApplication();
			
			DataUpdateMode = DataUpdateMode();
			SeamlessUpdate = False;
			UpdateIterations = UpdateIterations();
		EndIf;
		
	Except
		If Not LockAlreadySet Then
			UnlockIB(IBLock);
		EndIf;
		Raise;
	EndTry;
	
	If UpdateParameters.InBackground Then
		TimeConsumingOperations.ReportProgress(10);
	EndIf;
	
	If Not Common.DataSeparationEnabled()
		Or Common.SeparatedDataUsageAvailable() Then
		GenerateDeferredUpdateHandlerList(UpdateIterations);
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("HandlerExecutionProgress", HandlerCountForCurrentVersion(UpdateIterations, DeferredUpdateMode));
	Parameters.Insert("NonexclusiveUpdate", SeamlessUpdate);
	Parameters.Insert("InBackground", UpdateParameters.InBackground);
	Parameters.Insert("OnClientStart", UpdateParameters.OnClientStart);
	Parameters.Insert("DeferredUpdateMode", DeferredUpdateMode);
	
	Message = NStr("ru = 'Для обновления программы на новую версию будут выполнены обработчики: %1'; en = 'The following handlers will be executed during the application update: %1'; pl = 'Aby zaktualizować aplikację do nowej wersji, zostaną wykonane następujące procedury obsługi: %1';es_ES = 'Para actualizar la aplicación a una nueva versión, los siguientes manipuladores se ejecutarán: %1';es_CO = 'Para actualizar la aplicación a una nueva versión, los siguientes manipuladores se ejecutarán: %1';tr = 'Uygulamayı yeni sürüme güncellemek için aşağıdaki işleyiciler çalıştırılacak:%1';it = 'I gestori verranno eseguiti per aggiornare il programma alla nuova versione: %1';de = 'Um die Anwendung auf eine neue Version zu aktualisieren, werden die folgenden Handler ausgeführt: %1'");
	Message = StringFunctionsClientServer.SubstituteParametersToString(Message, Parameters.HandlerExecutionProgress.TotalHandlerCount);
	WriteInformation(Message);

	Try
		
		// Executing all update handlers for configuration subsystems.
		For Each UpdateIteration In UpdateIterations Do
			UpdateIteration.CompletedHandlers = ExecuteUpdateIteration(UpdateIteration, Parameters);
		EndDo;
		
		// Clearing a list of new subsystems.
		UpdateInfo = InfobaseUpdateInfo();
		UpdateInfo.NewSubsystems = New Array;
		FillDataForParallelDeferredUpdate(UpdateInfo, Parameters);
		WriteInfobaseUpdateInfo(UpdateInfo);
		
		// During file infobase updates, the deferred handlers are executed in the primary update cycle.
		If DeferredUpdateMode = "Exclusive" Then
			
			ClientLaunchParameter = SessionParameters.ClientParametersAtServer.Get("LaunchParameter");
			If StrFind(Lower(ClientLaunchParameter), Lower("DeferredUpdateDebug")) = 0 Then
				ExecuteDeferredUpdateNow(Parameters);
			EndIf;
			
		EndIf;
		
	Except
		If Not LockAlreadySet Then
			UnlockIB(IBLock);
		EndIf;
		Raise;
	EndTry;
	
	// Disabling the exclusive mode.
	If Not LockAlreadySet Then
		UnlockIB(IBLock);
	EndIf;

	Message = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Обновление информационной базы на версию ""%1"" выполнено успешно.'; en = 'The infobase was updated to version %1.'; pl = 'Aktualizacja bazy informacyjnej do wersji ""%1"" zakończona pomyślnie.';es_ES = 'Infobase se ha actualizado con éxito a la versión ""%1"".';es_CO = 'Infobase se ha actualizado con éxito a la versión ""%1"".';tr = 'Infobase %1 sürümüne güncellendi.';it = 'L''aggiornamento del database di informazioni alla versione ""%1"" ha avuto esito positivo.';de = 'Infobase wurde erfolgreich auf Version ""%1"" aktualisiert.'"), MetadataVersion);
	WriteInformation(Message);
	
	OutputUpdateDetails = (DataUpdateMode <> "InitialFilling");
	
	RefreshReusableValues();
	
	// After infobase update.
	//
	ExecuteHandlersAfterInfobaseUpdate(
		UpdateIterations,
		Constants.WriteIBUpdateDetailsToEventLog.Get(),
		OutputUpdateDetails,
		SeamlessUpdate);
	
	InfobaseUpdateOverridable.AfterUpdateInfobase(
		DataVersion,
		MetadataVersion,
		UpdateIterations,
		OutputUpdateDetails,
		Not SeamlessUpdate);
	
	// Exporting the exchange message after restart, due to configuration changes received
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.AfterUpdateInfobase();
	EndIf;
	
	// Scheduling execution of the deferred update handlers (for client-server infobases).
	If DeferredUpdateMode <> Undefined
		AND DeferredUpdateMode = "Deferred" Then
		ScheduleDeferredUpdate();
	EndIf;
	
	DefineUpdateDetailsDisplay(OutputUpdateDetails);
	
	// Clearing unsuccessful configuration update status in case of manual (without using scripts) update completion
	If Common.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		ModuleSoftwareUpdate = Common.CommonModule("ConfigurationUpdate");
		ModuleSoftwareUpdate.AfterUpdateInfobase();
	EndIf;
	
	RefreshReusableValues();
	
	SetPrivilegedMode(True);
	ClientLaunchParameter = SessionParameters.ClientParametersAtServer.Get("LaunchParameter");
	If StrFind(Lower(ClientLaunchParameter), Lower("StartInfobaseUpdate")) > 0 Then
		StandardSubsystemsServer.RegisterPriorityDataChangeForSubordinateDIBNodes();
	EndIf;
	SetPrivilegedMode(False);
	
	SetInfobaseUpdateStartup(False);
	SessionParameters.IBUpdateInProgress = False;
	
	Return "Success";
	
EndFunction

// Get configuration or parent configuration (library) version that is stored in the infobase.
// 
//
// Parameters:
//  LibraryID - String - a configuration name or a library ID.
//  GetSharedDataVersion - Boolean - if you set a True value, a version in shared data will return 
//                                       for SaaS.
//
// Returns:
//   String   - version.
//
// Usage example:
//   IBConfigurationVersion = IBVersion(Metadata.Name);
//
Function IBVersion(Val LibraryID, Val GetSharedDataVersion = False) Export
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	StandardProcessing = True;
	Result = "";
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.IBVersionUpdateSaaS") Then
		
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.OnDetermineIBVersion(LibraryID, GetSharedDataVersion,
			StandardProcessing, Result);
		
	EndIf;
	
	If StandardProcessing Then
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	SubsystemsVersions.Version
		|FROM
		|	InformationRegister.SubsystemsVersions AS SubsystemsVersions
		|WHERE
		|	SubsystemsVersions.SubsystemName = &SubsystemName";
		
		Query.SetParameter("SubsystemName", LibraryID);
		ValueTable = Query.Execute().Unload();
		Result = "";
		If ValueTable.Count() > 0 Then
			Result = TrimAll(ValueTable[0].Version);
		EndIf;
		
		If IsBlankString(Result) Then
			
			// Support for SL 2.1.2 updates.
			QueryText =
				"SELECT
				|	DeleteSubsystemVersions.Version
				|FROM
				|	InformationRegister.DeleteSubsystemVersions AS DeleteSubsystemVersions
				|WHERE
				|	DeleteSubsystemVersions.SubsystemName = &SubsystemName
				|	AND DeleteSubsystemVersions.DataArea = &DataArea";
			Query = New Query(QueryText);
			Query.SetParameter("SubsystemName", LibraryID);
			If Common.DataSeparationEnabled() Then
				Query.SetParameter("DataArea", -1);
			Else
				Query.SetParameter("DataArea", 0);
			EndIf;
			ValueTable = Query.Execute().Unload();
			If ValueTable.Count() > 0 Then
				Result = TrimAll(ValueTable[0].Version);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return ?(IsBlankString(Result), "0.0.0.0", Result);
	
EndFunction

// Writes a configuration or parent configuration (library) version to the infobase.
//
// Parameters:
//  LibraryID - String - configuration (library) name or parent configuration (library) name,
//  VersionNumber             - String - version number.
//  IsMainConfiguration - Boolean - a flag indicating that the LibraryID corresponds to the configuration name.
//
Procedure SetIBVersion(Val LibraryID, Val VersionNumber, Val IsMainConfiguration) Export
	
	StandardProcessing = True;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.IBVersionUpdateSaaS") Then
		
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.OnSetIBVersion(LibraryID, VersionNumber, StandardProcessing);
		
	EndIf;
	
	If Not StandardProcessing Then
		Return;
	EndIf;
		
	RecordSet = InformationRegisters.SubsystemsVersions.CreateRecordSet();
	RecordSet.Filter.SubsystemName.Set(LibraryID);
	
	NewRecord = RecordSet.Add();
	NewRecord.SubsystemName = LibraryID;
	NewRecord.Version = VersionNumber;
	NewRecord.IsMainConfiguration = IsMainConfiguration;
	
	RecordSet.Write();
	
EndProcedure

// Records details for deferred handlers registration on the exchange plan.
//
Procedure CanlcelDeferredUpdateHandlersRegistration(SubsystemName = Undefined, Value = True) Export
	
	StandardProcessing = True;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.OnMarkDeferredUpdateHandlersRegistration(SubsystemName, Value, StandardProcessing);
	EndIf;
	
	If Not StandardProcessing Then
		Return;
	EndIf;
	
	RecordSet = InformationRegisters.SubsystemsVersions.CreateRecordSet();
	If SubsystemName <> Undefined Then
		RecordSet.Filter.SubsystemName.Set(SubsystemName);
	EndIf;
	RecordSet.Read();
	
	If RecordSet.Count() = 0 Then
		Return;
	EndIf;
	
	For Each RegisterRecord In RecordSet Do
		RegisterRecord.DeferredHandlersRegistrationCompleted = Value;
	EndDo;
	RecordSet.Write();
	
EndProcedure

// Returns an infobase data update mode.
// Can only be called before the infobase update starts (returns VersionUpdate otherwise).
// 
// Returns:
//   String   - "InitialFilling" in case it is a first opening of an empty database (data area);
//              "VersionUpdate" in case it is a first start after an infobase configuration update.
//              "MigrationFromAnotherApplication" in case it is a first start after an infobase 
//              configuration update where a base configuration name was changed.
//
Function DataUpdateMode() Export
	
	SetPrivilegedMode(True);
	
	StandardProcessing = True;
	DataUpdateMode = "";
	
	BaseConfigurationName = Metadata.Name;
	SubsystemsDetails  = StandardSubsystemsCached.SubsystemsDetails();
	For each SubsystemName In SubsystemsDetails.Order Do
		SubsystemDetails = SubsystemsDetails.ByNames.Get(SubsystemName);
		If NOT ValueIsFilled(SubsystemDetails.MainServerModule) Then
			Continue;
		EndIf;
		
		If SubsystemDetails.Name <> BaseConfigurationName Then
			Continue;
		EndIf;
		
		Module = Common.CommonModule(SubsystemDetails.MainServerModule);
		Module.OnDefineDataUpdateMode(DataUpdateMode, StandardProcessing);
	EndDo;
	
	If NOT StandardProcessing Then
		CommonClientServer.CheckParameter("OnDefineDataUpdateMode", "DataUpdateMode",
			DataUpdateMode, Type("String"));
		Message = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Недопустимое значение параметра %1 в %2. 
			|Ожидалось: %3; передано значение: %4 (тип %5).'; 
			|en = 'Invalid value for the %1 parameter in %2.
			|Expected value: %3, passed value: %4 (type: %5).'; 
			|pl = 'Niepoprawna wartość %1 parametru w %2. 
			|Oczekiwana: %3; wysłana wartość: %4 (typ %5).';
			|es_ES = 'Valor inválido del %1 parámetro en %2.
			|Esperado: %3; valor enviado: %4 (%5 tipo).';
			|es_CO = 'Valor inválido del %1 parámetro en %2.
			|Esperado: %3; valor enviado: %4 (%5 tipo).';
			|tr = '%1''deki %2 parametrenin geçersiz değeri.
			|Beklenen %5 ; gönderilen değer %3 (%4 tür).';
			|it = 'Valore non valido per il parametro %1 in %2.
			|Valore atteso: %3, valore trasmesso: %4 (del tipo: %5).';
			|de = 'Ungültiger Wert des %1 Parameters in %2.
			|Erwartet: %3; gesendeter Wert: %4 (%5Typ).'"),
			"DataUpdateMode", "OnDefineDataUpdateMode", 
			NStr("ru = 'InitialFilling, VersionUpdate или MigrationFromAnotherApplication'; en = 'InitialFilling, VersionUpdate, or MigrationFromAnotherApplication'; pl = 'InitialFilling, VersionUpdate, lub TransferFromAnotherApplication';es_ES = 'InitialFilling, VersionUpdate o TransferFromAnotherApplication';es_CO = 'InitialFilling, VersionUpdate o TransferFromAnotherApplication';tr = 'İlk Doldurma, Sürüm Güncelleme veya Başka Bir Uygulamadan Aktarım';it = 'Riempimento iniziale, aggiornamento della versione o passaggio da un altro programma';de = 'InitialFilling, VersionUpdate, oder MigrationFromAnotherApplication'"), 
			DataUpdateMode, TypeOf(DataUpdateMode));
		CommonClientServer.Validate(DataUpdateMode = "InitialFilling" 
			Or DataUpdateMode = "VersionUpdate" Or DataUpdateMode = "MigrationFromAnotherApplication", Message);
		Return DataUpdateMode;
	EndIf;

	Result = Undefined;
	If Common.SubsystemExists("StandardSubsystems.SaaS.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.OnDetermineFirstSignInToDataArea(StandardProcessing, Result);
	EndIf;
	
	If NOT StandardProcessing Then
		Return ?(Result = True, "InitialFilling", "VersionUpdate");
	EndIf;
	
	Return DataUpdateModeInLocalMode();
	
EndFunction

// For internal use.
Function HandlerFIlteringParameters() Export
	
	Result = New Structure;
	Result.Insert("GetSeparated", False);
	Result.Insert("UpdateMode", "Exclusive");
	Result.Insert("IncludeFirstExchangeInDIB", False);
	Result.Insert("FirstExchangeInDIB", False);
	Return Result;
	
EndFunction

// For internal use.
Function UpdateInIntervalHandlers(Val InitialHandlerTable, Val VersionFrom, Val VersionTo, 
	Val HandlerFIlteringParameters = Undefined) Export
	
	FilterParameters = HandlerFIlteringParameters;
	If FilterParameters = Undefined Then
		FilterParameters = HandlerFIlteringParameters();
	EndIf;
	// Adding numbers to a table, to be sorted by adding order.
	AllHandlers = InitialHandlerTable.Copy();
	
	AllHandlers.Columns.Add("SerialNumber", New TypeDescription("Number", New NumberQualifiers(10, 0)));
	For Index = 0 To AllHandlers.Count() - 1 Do
		HandlerRow = AllHandlers[Index];
		HandlerRow.SerialNumber = Index + 1;
	EndDo;
	
	SelectNewSubsystemHandlers(AllHandlers);
	
	// Preparing parameters
	SelectSeparatedHandlers = True;
	SelectSharedHandlers = True;
	
	If Common.DataSeparationEnabled() Then
		If FilterParameters.GetSeparated Then
			SelectSharedHandlers = False;
		Else
			If Common.SeparatedDataUsageAvailable() Then
				SelectSharedHandlers = False;
			Else
				SelectSeparatedHandlers = False;
			EndIf;
		EndIf;
	EndIf;
	
	// Generating a handler tree.
	Schema = GetCommonTemplate("GetUpdateHandlersTree");
	Schema.Parameters.Find("SelectSeparatedHandlers").Value = SelectSeparatedHandlers;
	Schema.Parameters.Find("SelectSharedHandlers").Value = SelectSharedHandlers;
	Schema.Parameters.Find("VersionFrom").Value = VersionFrom;
	Schema.Parameters.Find("VersionTo").Value = VersionTo;
	Schema.Parameters.Find("VersionWeightFrom").Value = VersionWeight(Schema.Parameters.Find("VersionFrom").Value);
	Schema.Parameters.Find("VersionWeightTo").Value = VersionWeight(Schema.Parameters.Find("VersionTo").Value);
	Schema.Parameters.Find("NonexclusiveUpdate").Value = (FilterParameters.UpdateMode = "Seamless");
	Schema.Parameters.Find("DeferredUpdate").Value = (FilterParameters.UpdateMode = "Deferred");
	If FilterParameters.IncludeFirstExchangeInDIB Then
		Schema.Parameters.Find("FirstExchangeInDIB").Value = FilterParameters.FirstExchangeInDIB;
		Schema.Parameters.Find("IsDIBWithFilter").Value = StandardSubsystemsCached.DIBUsed("WithFilter");
	EndIf;
	
	Composer = New DataCompositionTemplateComposer;
	Template = Composer.Execute(Schema, Schema.DefaultSettings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(Template, New Structure("Handlers", AllHandlers), , True);
	
	OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
	OutputProcessor.SetObject(New ValueTree);
	
	HandlersToExecute = OutputProcessor.Output(CompositionProcessor);
	
	HandlersToExecute.Columns.Version.Name = "RegistrationVersion";
	HandlersToExecute.Columns.VersionGroup.Name = "Version";
	
	// Sorting handlers by SharedData flag.
	For Each Version In HandlersToExecute.Rows Do
		Version.Rows.Sort("SharedData Desc", True);
	EndDo;
	
	Return HandlersToExecute;
	
EndFunction

// For internal use.
//
Function UpdateRequired(Val MetadataVersion, Val DataVersion) Export
	Return NOT IsBlankString(MetadataVersion) AND DataVersion <> MetadataVersion;
EndFunction

// For internal use.
//
Function DeferredUpdateHandlersRegistered() Export
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	If Common.DataSeparationEnabled()
		AND Not Common.SeparatedDataUsageAvailable() Then
		Return True; // When in shared mode, the deferred update is not performed.
	EndIf;
	
	StandardProcessing = True;
	Result = "";
	If Common.SubsystemExists("StandardSubsystems.SaaS.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.OnCheckDeferredUpdateHandlersRegistration(Result, StandardProcessing);
	EndIf;
	
	If Not StandardProcessing Then
		Return Result;
	EndIf;
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	SubsystemsVersions.SubsystemName
		|FROM
		|	InformationRegister.SubsystemsVersions AS SubsystemsVersions
		|WHERE
		|	SubsystemsVersions.DeferredHandlersRegistrationCompleted = FALSE";
	
	Result = Query.Execute().Unload();
	Return Result.Count() = 0;
	
EndFunction

// Returns True when a user enabled showing update details and new update details are available.
// 
//
Function ShowApplicationReleaseNotes() Export
	
	UpdateInfo = InfobaseUpdateInfo();
	If UpdateInfo.OutputUpdateDetails = False Then
		Return False;
	EndIf;
	
	If Not AccessRight("SaveUserData", Metadata) Then
		// Hiding "what's new in this version" from anonymous users.
		Return False;
	EndIf;
	
	If Not AccessRight("View", Metadata.CommonForms.ApplicationReleaseNotes) Then
		Return False;
	EndIf;
	
	If Common.DataSeparationEnabled()
		AND Users.IsFullUser(, True) Then
		Return False;
	EndIf;
	
	OutputChangeDetailsForAdministrator = Common.CommonSettingsStorageLoad("IBUpdate", "OutputChangeDescriptionForAdministrator",,, UserName());
	If OutputChangeDetailsForAdministrator = True Then
		Return True;
	EndIf;
	
	LatestVersion = SystemChangesDisplayLastVersion();
	If LatestVersion = Undefined Then
		Return True;
	EndIf;
	
	Sections = UpdateDetailsSections();
	
	If Sections = Undefined Then
		Return False;
	EndIf;
	
	Return GetLaterVersions(Sections, LatestVersion).Count() > 0;
	
EndFunction

// Validates status of deferred update handlers.
//
Function UncompletedHandlersStatus(OnUpdate = False) Export
	
	UpdateInfo = InfobaseUpdateInfo();
	
	If OnUpdate Then
		DataVersion = IBVersion(Metadata.Name);
		DataVersionWithoutBuildNumber = CommonClientServer.ConfigurationVersionWithoutBuildNumber(DataVersion);
		MetadataVersionWithoutBuildNumber = CommonClientServer.ConfigurationVersionWithoutBuildNumber(Metadata.Version);
		IdenticalSubrevisions = (DataVersionWithoutBuildNumber = MetadataVersionWithoutBuildNumber);
		
		If DataVersion = "0.0.0.0" Or IdenticalSubrevisions Then
			// Can update on build level even if any deferred update handlers are not completed.
			// 
			Return "";
		EndIf;
		
		HandlerTreeVersion = UpdateInfo.HandlerTreeVersion;
		If HandlerTreeVersion <> "" AND CommonClientServer.CompareVersions(HandlerTreeVersion, DataVersion) > 0 Then
			// If an error occurs in the main update loop, do not check the deferred handler tree on restart as 
			// it will contain uncompleted handlers for the current version.
			// 
			Return "";
		EndIf;
	EndIf;
	
	HasHandlersWithErrors = False;
	HasUncompletedHandlers = False;
	HasPausedHandlers = False;
	For Each TreeRowLibrary In UpdateInfo.HandlersTree.Rows Do
		For Each TreeRowVersion In TreeRowLibrary.Rows Do
			For Each Handler In TreeRowVersion.Rows Do
				If Handler.Status = "Error" Then
					// If any handlers completed with errors are found, the loop continues to ensure that all handlers 
					// are completed.
					HasHandlersWithErrors = True;
				ElsIf Handler.Status <> "Completed" Then
					HasUncompletedHandlers = True;
					Break;
				ElsIf Handler.Status = "Paused" Then
					HasPausedHandlers = True;
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	If HasUncompletedHandlers Then
		Return "UncompletedStatus";
	ElsIf HasHandlersWithErrors Then
		Return "ErrorStatus";
	ElsIf HasPausedHandlers Then
		Return "SuspendedStatus";
	Else
		Return "";
	EndIf;
	
EndFunction

// Executes all deferred update procedures in a single-call cycle.
//
Procedure ExecuteDeferredUpdateNow(UpdateParameters = Undefined) Export
	
	UpdateInfo = InfobaseUpdateInfo();
	
	If UpdateInfo.DeferredUpdateEndTime <> Undefined Then
		Return;
	EndIf;

	If UpdateInfo.DeferredUpdateStartTime = Undefined Then
		UpdateInfo.DeferredUpdateStartTime = CurrentSessionDate();
	EndIf;
	
	If TypeOf(UpdateInfo.SessionNumber) <> Type("ValueList") Then
		UpdateInfo.SessionNumber = New ValueList;
	EndIf;
	UpdateInfo.SessionNumber.Add(InfoBaseSessionNumber());
	WriteInfobaseUpdateInfo(UpdateInfo);
	
	HandlersExecutedEarlier = True;
	While HandlersExecutedEarlier Do
		HandlersExecutedEarlier = ExecuteDeferredUpdateHandler(UpdateInfo, UpdateParameters);
	EndDo;
	
	WriteInfobaseUpdateInfo(UpdateInfo);
	
EndProcedure

// For internal use.
Function AddClientParametersOnStart(Parameters) Export
	
	Parameters.Insert("MainConfigurationDataVersion", IBVersion(Metadata.Name));
	
	// Checking whether the application run will be continued.
	IsCallBeforeStart = Parameters.RetrievedClientParameters <> Undefined;
	ErrorDescription = InfobaseLockedForUpdate(, IsCallBeforeStart);
	If ValueIsFilled(ErrorDescription) Then
		Parameters.Insert("InfobaseLockedForUpdate", ErrorDescription);
		// Application will be closed.
		Return False;
	EndIf;
	
	If MustCheckLegitimateSoftware() Then
		Parameters.Insert("CheckLegitimateSoftware");
	EndIf;
	
	Return True;
	
EndFunction

// Used for testing purposes.
Function MustCheckLegitimateSoftware() Export
	
	If NOT Common.SubsystemExists("StandardSubsystems.SoftwareLicenseCheck") Then
		Return False;
	EndIf;
	
	If StandardSubsystemsServer.IsBaseConfigurationVersion() Then
		Return False;
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		Return False;
	EndIf;
	
	If Common.IsSubordinateDIBNode() Then
		Return False;
	EndIf;
	
	LegitimateVersion = "";
	
	If DataUpdateModeInLocalMode() = "InitialFilling" Then
		LegitimateVersion = Metadata.Version;
	Else
		UpdateInfo = InfobaseUpdateInfo();
		LegitimateVersion = UpdateInfo.LegitimateVersion;
	EndIf;
	
	Return LegitimateVersion <> Metadata.Version;
	
EndFunction

// Returns a string containing infobase lock reasons in case the current user has insufficient 
// rights to update the infobase; returns an empty string otherwise.
//
// Parameters:
//  ForPrivilegedMode - Boolean - if set to False, the current user rights check will ignore 
//                                    privileged mode.
//  
// Returns:
//  String - blank string if the infobase is not locked, or lock reason message otherwise.
// 
Function InfobaseLockedForUpdate(ForPrivilegedMode = True, OnStart = Undefined) Export
	
	Message = "";
	
	CurrentIBUser = InfoBaseUsers.CurrentUser();
	
	// Administration rights are sufficient to access a locked infobase.
	If ForPrivilegedMode Then
		HasAdministrationRight = AccessRight("Administration", Metadata);
	Else
		HasAdministrationRight = AccessRight("Administration", Metadata, CurrentIBUser);
	EndIf;
	
	MessageForSystemAdministrator =
		NStr("ru = 'Вход в программу временно невозможен в связи с обновлением на новую версию.
		           |Для завершения обновления версии программы требуются административные права
		           |(роли ""Администратор системы"" и ""Полные права"").'; 
		           |en = 'The application is temporarily unavailable due to version update.
		           |To complete the version update, administrative rights are required
		           |(""System administrator"" and ""Full access"" roles).'; 
		           |pl = 'Wejście do programu tymczasowo jest niemożliwe w związku z aktualizacją do nowej wersji.
		           |Dla zakończenia aktualizacji wersji programu wymagane są prawa administracyjne
		           |(role ""Administrator systemu"" i Pełny dostęp"").';
		           |es_ES = 'Entrada en la aplicación es temporalmente imposible debido a la actualización para la nueva versión.
		           |Para terminar la actualización de la versión de la aplicación se requieren los derechos de administrador
		           |(""Administrador del sistema"" y ""Derechos completos"").';
		           |es_CO = 'Entrada en la aplicación es temporalmente imposible debido a la actualización para la nueva versión.
		           |Para terminar la actualización de la versión de la aplicación se requieren los derechos de administrador
		           |(""Administrador del sistema"" y ""Derechos completos"").';
		           |tr = 'Güncelleme nedeniyle uygulamaya geçici olarak erişilemiyor.
		           |Sürüm güncellemesini tamamlamak yönetici yetkileri gereklidir
		           |(""Sistem yöneticisi"" ve ""Tam erişim"" rolleri).';
		           |it = 'L''accesso al programma è temporaneamente non disponibile a causa dell''aggiornamento alla nuova versione.
		           |Per completare l''aggiornamento della versione del programma, è necessario disporre di diritti amministrativi 
		           |(ruoli amministratore di sistema e diritti completi).';
		           |de = 'Die Anmeldung am Programm ist aufgrund eines Upgrades auf eine neue Version vorübergehend nicht möglich.
		           |Für den Abschluss des Upgrades sind Administratorrechte erforderlich
		           |(die Rollen ""Systemadministrator"" und ""Vollrechte"").'");
	
	SetPrivilegedMode(True);
	DataSeparationEnabled = Common.DataSeparationEnabled();
	SeparatedDataUsageAvailable = Common.SeparatedDataUsageAvailable();
	SetPrivilegedMode(False);
	
	If SharedInfobaseDataUpdateRequired() Then
		
		MessageForDataAreaAdministrator =
			NStr("ru = 'Вход в приложение временно невозможен в связи с обновлением на новую версию.
			           |Обратитесь к администратору сервиса за подробностями.'; 
			           |en = 'The application is temporarily unavailable due to version update.
			           |For details, contact the service administrator.'; 
			           |pl = 'Dostęp do aplikacji jest tymczasowo niemożliwy z powodu aktualizacji do nowej wersji.
			           |Aby uzyskać więcej informacji, skontaktuj się z administratorem serwisu.';
			           |es_ES = 'Es imposible temporalmente entrar en el programa a causa de actualización a la nueva versión.
			           |Diríjase al administrador para la información.';
			           |es_CO = 'Es imposible temporalmente entrar en el programa a causa de actualización a la nueva versión.
			           |Diríjase al administrador para la información.';
			           |tr = 'Uygulamaya giriş, yeni sürüme yapılan güncellemeden dolayı geçici olarak yapılamaz.
			           | Ayrıntılar için yöneticiye başvurun.';
			           |it = 'L''accesso all''applicazione non è temporaneamente disponibile a causa dell''aggiornamento alla nuova versione.
			           |Contattare l''amministratore del servizio per i dettagli.';
			           |de = 'Die Anmeldung am Programm ist aufgrund eines Upgrades auf eine neue Version vorübergehend nicht möglich.
			           |Wenden Sie sich für weitere Informationen an den Service-Administrator.'");
		
		If SeparatedDataUsageAvailable Then
			Message = MessageForDataAreaAdministrator;
			
		ElsIf NOT CanUpdateInfobase(ForPrivilegedMode, False) Then
			
			If HasAdministrationRight Then
				Message = MessageForSystemAdministrator;
			Else
				Message = MessageForDataAreaAdministrator;
			EndIf;
		EndIf;
		
		Return Message;
	EndIf;
	
	// No message is sent to the service administrator.
	If DataSeparationEnabled AND Not SeparatedDataUsageAvailable Then
		Return "";
	EndIf;
		
	If CanUpdateInfobase(ForPrivilegedMode, True) Then
		If InfobaseUpdate.InfobaseUpdateRequired()
			AND OnStart = True Then
			Result = UpdateStartMark();
			
			If CommonClientServer.IsMobileClient() Then
				
				Return NStr("ru = 'Вход в программу временно невозможен в связи с обновлением на новую версию.
								|Для завершения обновления версии программы требуются запуск в режиме толстого, тонкого или ВЕБ-клиента'; 
								|en = 'The application is temporarily unavailable due to version update.
								|To complete the version update, run the application in thick, thin, or web client mode.'; 
								|pl = 'Wejście do programu tymczasowo jest niemożliwe w związku z aktualizacją do nowej wersji.
								|Dla zakończenia aktualizacji wersji programu jest potrzebne uruchomienie w trybie grubego, cienkiego lub WEB-klienta';
								|es_ES = 'Es imposible temporalmente entrar en el programa a causa de actualización a la nueva versión.
								|Para terminar la actualización de la versión del programa se requiere lanzar en el modo de cliente grueso, ligero o cliente web';
								|es_CO = 'Es imposible temporalmente entrar en el programa a causa de actualización a la nueva versión.
								|Para terminar la actualización de la versión del programa se requiere lanzar en el modo de cliente grueso, ligero o cliente web';
								|tr = 'Programa giriş geçici olarak yeni sürüme yükseltme nedeniyle mümkün değildir. 
								|Programın sürümünü güncellemeyi tamamlamak için kalın, ince veya Web istemcisi modunda çalıştırmalıdır';
								|it = 'L''applicazione è temporaneamente non disponibile a causa dell''aggiornamento della versione.
								|Per completare l''aggiornamento della versione, esegui l''applicazione in modalità thick, thin o web client.';
								|de = 'Die Anmeldung am Programm ist aufgrund eines Upgrades auf eine neue Version vorübergehend nicht möglich.
								|Um das Upgrade abzuschließen, müssen Sie das Programm im Thick, Thin oder Web-Client-Modus ausführen.'");
				
			ElsIf Not Result.CanUpdate Then
				Message = NStr("ru = 'Вход в программу временно невозможен в связи с обновлением на новую версию.
					|Обновление уже выполняется:
					|  компьютер - %1
					|  пользователь - %2
					|  сеанс - %3
					|  начат - %4
					|  приложение - %5'; 
					|en = 'The application is temporarily unavailable due to version update.
					|Now updating:
					|  computer: %1
					|  user: %2
					|  session: %3
					|  start time: %4
					|  application: %5'; 
					|pl = 'Wejście do programu tymczasowo jest niemożliwe w związku z aktualizacją do nowej wersji.
					|Aktualizacja już jest wykonywana:
					|  komputer - %1
					|  użytkownik - %2
					|  sesja - %3
					|  rozpoczęta - %4
					|  aplikacja - %5';
					|es_ES = 'Es imposible temporalmente entrar en el programa a causa de actualización a la nueva versión.
					|La actualización ya está ejecutando:
					| ordenador - %1
					| usuario - %2
					| sesión - %3
					| empezada - %4
					| aplicación - %5';
					|es_CO = 'Es imposible temporalmente entrar en el programa a causa de actualización a la nueva versión.
					|La actualización ya está ejecutando:
					| ordenador - %1
					| usuario - %2
					| sesión - %3
					| empezada - %4
					| aplicación - %5';
					|tr = 'Programa giriş geçici olarak yeni sürüme yükseltme nedeniyle mümkün değildir.
					|Güncelleme zaten çalışıyor: 
					|bilgisayar-%1
					|kullanıcı-%2
					|oturum-%3
					|başlat-%4
					|uygulama -%5';
					|it = 'L''accesso al programma è temporaneamente non disponibile a causa dell''aggiornamento alla nuova versione.
					|L''aggiornamento è già in corso: 
					|computer - %1
					| utente - %2
					| sessione - %3
					| avviato -  %4
					| applicazione - %5';
					|de = 'Die Anmeldung am Programm ist aufgrund eines Upgrades auf eine neue Version vorübergehend nicht möglich.
					|Die Aktualisierung ist bereits im Gange:
					| Computer - %1
					|  Benutzer - %2
					|  Sitzung - %3
					|  Start - %4
					|Anwendung - %5'");
				
				Message = StringFunctionsClientServer.SubstituteParametersToString(Message,
					Result.UpdateSession.ComputerName,
					Result.UpdateSession.User,
					Result.UpdateSession.SessionNumber,
					Result.UpdateSession.SessionStarted,
					Result.UpdateSession.ApplicationName);
				Return Message;
			EndIf;
		EndIf;
		
		Return "";
	EndIf;
	
	RepeatedDataExchangeMessageImportRequiredBeforeStart = False;
	If Common.IsSubordinateDIBNode()
	   AND Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServerCall = Common.CommonModule("DataExchangeServerCall");
		RepeatedDataExchangeMessageImportRequiredBeforeStart = 
			ModuleDataExchangeServerCall.RetryDataExchangeMessageImportBeforeStart();
	EndIf;
	
	// In this situation, start is not prevented.
	If Not InfobaseUpdate.InfobaseUpdateRequired()
	   AND Not MustCheckLegitimateSoftware()
	   AND Not RepeatedDataExchangeMessageImportRequiredBeforeStart Then
		Return "";
	EndIf;
	
	// In all other situations, start is prevented.
	If HasAdministrationRight Then
		Return MessageForSystemAdministrator;
	EndIf;

	If DataSeparationEnabled Then
		// Message to service user.
		Message =
			NStr("ru = 'Вход в приложение временно невозможен в связи с обновлением на новую версию.
			           |Обратитесь к администратору сервиса за подробностями.'; 
			           |en = 'The application is temporarily unavailable due to version update.
			           |For details, contact the service administrator.'; 
			           |pl = 'Dostęp do aplikacji jest tymczasowo niemożliwy z powodu aktualizacji do nowej wersji.
			           |Aby uzyskać więcej informacji, skontaktuj się z administratorem serwisu.';
			           |es_ES = 'Es imposible temporalmente entrar en el programa a causa de actualización a la nueva versión.
			           |Diríjase al administrador para la información.';
			           |es_CO = 'Es imposible temporalmente entrar en el programa a causa de actualización a la nueva versión.
			           |Diríjase al administrador para la información.';
			           |tr = 'Uygulamaya giriş, yeni sürüme yapılan güncellemeden dolayı geçici olarak yapılamaz.
			           | Ayrıntılar için yöneticiye başvurun.';
			           |it = 'L''accesso all''applicazione non è temporaneamente disponibile a causa dell''aggiornamento alla nuova versione.
			           |Contattare l''amministratore del servizio per i dettagli.';
			           |de = 'Die Anmeldung am Programm ist aufgrund eines Upgrades auf eine neue Version vorübergehend nicht möglich.
			           |Wenden Sie sich für weitere Informationen an den Service-Administrator.'");
	Else
		// Message to local mode user.
		Message =
			NStr("ru = 'Вход в приложение временно невозможен в связи с обновлением на новую версию.
			           |Обратитесь к администратору сервиса за подробностями.'; 
			           |en = 'The application is temporarily unavailable due to version update.
			           |For details, contact the service administrator.'; 
			           |pl = 'Dostęp do aplikacji jest tymczasowo niemożliwy z powodu aktualizacji do nowej wersji.
			           |Aby uzyskać więcej informacji, skontaktuj się z administratorem serwisu.';
			           |es_ES = 'Es imposible temporalmente entrar en el programa a causa de actualización a la nueva versión.
			           |Diríjase al administrador para la información.';
			           |es_CO = 'Es imposible temporalmente entrar en el programa a causa de actualización a la nueva versión.
			           |Diríjase al administrador para la información.';
			           |tr = 'Uygulamaya giriş, yeni sürüme yapılan güncellemeden dolayı geçici olarak yapılamaz.
			           | Ayrıntılar için yöneticiye başvurun.';
			           |it = 'L''accesso all''applicazione non è temporaneamente disponibile a causa dell''aggiornamento alla nuova versione.
			           |Contattare l''amministratore del servizio per i dettagli.';
			           |de = 'Die Anmeldung am Programm ist aufgrund eines Upgrades auf eine neue Version vorübergehend nicht möglich.
			           |Wenden Sie sich für weitere Informationen an den Service-Administrator.'");
	EndIf;
	
	Return Message;
	
EndFunction

// Sets the infobase update start state.
// Privileged mode required.
//
// Parameters:
//  Startup - Boolean - True sets the state, and False clears the state.
//           
//
Procedure SetInfobaseUpdateStartup(Startup) Export
	
	SetPrivilegedMode(True);
	CurrentParameters = New Map(SessionParameters.ClientParametersAtServer);
	
	If Startup = True Then
		CurrentParameters.Insert("StartInfobaseUpdate", True);
		
	ElsIf CurrentParameters.Get("StartInfobaseUpdate") <> Undefined Then
		CurrentParameters.Delete("StartInfobaseUpdate");
	EndIf;
	
	SessionParameters.ClientParametersAtServer = New FixedMap(CurrentParameters);
	
EndProcedure

// Gets infobase update information from the IBUpdateInfo constant.
// 
Function InfobaseUpdateInfo() Export
	
	SetPrivilegedMode(True);
	
	If Common.DataSeparationEnabled()
	   AND Not Common.SeparatedDataUsageAvailable() Then
		
		Return NewUpdateInfo();
	EndIf;
	
	IBUpdateInfo = Constants.IBUpdateInfo.Get().Get();
	If TypeOf(IBUpdateInfo) <> Type("Structure") Then
		Return NewUpdateInfo();
	EndIf;
	If IBUpdateInfo.Count() = 1 Then
		Return NewUpdateInfo();
	EndIf;
		
	IBUpdateInfo = NewUpdateInfo(IBUpdateInfo);
	Return IBUpdateInfo;
	
EndFunction

// Writes update data to the IBUpdateInfo constant.
//
Procedure WriteInfobaseUpdateInfo(Val UpdateInfo) Export
	
	If UpdateInfo = Undefined Then
		NewValue = NewUpdateInfo();
	Else
		NewValue = UpdateInfo;
	EndIf;
	
	ConstantManager = Constants.IBUpdateInfo.CreateValueManager();
	ConstantManager.Value = New ValueStorage(NewValue);
	InfobaseUpdate.WriteData(ConstantManager);
	
EndProcedure

// Writes the duration of the main update cycle to a constant.
//
Procedure WriteUpdateExecutionTime(UpdateStartTime, UpdateEndTime) Export
	
	If Common.DataSeparationEnabled() AND Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	UpdateInfo = InfobaseUpdateInfo();
	UpdateInfo.UpdateStartTime = UpdateStartTime;
	UpdateInfo.UpdateEndTime = UpdateEndTime;
	
	TimeInSeconds = UpdateEndTime - UpdateStartTime;
	
	Hours = Int(TimeInSeconds/3600);
	Minutes = Int((TimeInSeconds - Hours * 3600) / 60);
	Seconds = TimeInSeconds - Hours * 3600 - Minutes * 60;
	
	DurationHours = ?(Hours = 0, "", StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 час'; en = '%1 h'; pl = '%1 g.';es_ES = '%1 hora';es_CO = '%1 hora';tr = '%1 s';it = '%1 h';de = '%1 Stunde'"), Hours));
	DurationMinutes = ?(Minutes = 0, "", StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 мин'; en = '%1 min'; pl = '%1 min.';es_ES = '%1 minuto';es_CO = '%1 minuto';tr = '%1 dk';it = '%1 min';de = '%1 min'"), Minutes));
	DurationSeconds = ?(Seconds = 0, "", StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 сек'; en = '%1 sec'; pl = '%1 sek.';es_ES = '%1 segundo';es_CO = '%1 segundo';tr = '%1 sn';it = '%1 sec';de = '%1 s'"), Seconds));
	UpdateDuration = DurationHours + " " + DurationMinutes + " " + DurationSeconds;
	UpdateInfo.UpdateDuration = TrimAll(UpdateDuration);
	
	WriteInfobaseUpdateInfo(UpdateInfo);
	
EndProcedure

// For internal use only.
Procedure WriteLegitimateSoftwareConfirmation() Export
	
	If Common.DataSeparationEnabled()
	   AND Not Common.SeparatedDataUsageAvailable()
	   Or StandardSubsystemsServer.IsBaseConfigurationVersion() Then
		
		Return;
	EndIf;
	
	UpdateInfo = InfobaseUpdateInfo();
	UpdateInfo.LegitimateVersion = Metadata.Version;
	WriteInfobaseUpdateInfo(UpdateInfo);
	
EndProcedure

// Sets the version change details display flag both for the current version and earlier versions, 
// provided that the flag is not yet set for this user.
// 
//
// Parameters:
//  Username - String - the name of the user to set the flag for.
//   
//
Procedure SetShowDetailsToNewUserFlag(Val Username) Export
	
	If SystemChangesDisplayLastVersion(Username) = Undefined Then
		SetShowDetailsToCurrentVersionFlag(Username);
	EndIf;
	
EndProcedure

// Reregisters the data to be updated in exchange plan.
// InfobaseUpdate, required when importing data from service or exporting data to service.
// 
//
Procedure ReregisterDataForDeferredUpdate() Export
	
	UpdateInfo = InfobaseUpdateInfo();
	LibraryDetailsList    = StandardSubsystemsCached.SubsystemsDetails().ByNames;
	DataToProcess = New Map;
	ParametersInitialized = False;
	
	For Each RowLibrary In UpdateInfo.HandlersTree.Rows Do
		
		If LibraryDetailsList[RowLibrary.LibraryName].DeferredHandlerExecutionMode <> "Parallel" Then
			Continue;
		EndIf;
		
		ParallelSinceVersion = LibraryDetailsList[RowLibrary.LibraryName].ParralelDeferredUpdateFromVersion;
		
		If Not ParametersInitialized Then
			HandlerParametersStructure = InfobaseUpdate.MainProcessingMarkParameters();
			HandlerParametersStructure.ReRegistration = True;
			ParametersInitialized = True;
		EndIf;
		
		For Each VersionRow In RowLibrary.Rows Do
			
			If VersionRow.VersionNumber = "*" Then
				Continue;
			EndIf;
			
			If ValueIsFilled(ParallelSinceVersion)
				AND CommonClientServer.CompareVersions(VersionRow.VersionNumber, ParallelSinceVersion) < 0 Then
				Continue;
			EndIf;
			
			For Each Handler In VersionRow.Rows Do
				
				HandlerParametersStructure.PositionInQueue = Handler.DeferredProcessingQueue;
				HandlerParametersStructure.Insert("HandlerData", New Map);
				
				HandlerParameters = New Array;
				HandlerParameters.Add(HandlerParametersStructure);
				Try
					Message = NStr("ru = 'Выполняется процедура заполнения данных
						                   |""%1""
						                   |отложенного обработчика обновления
						                   |""%2"".'; 
						                   |en = 'Executing data population procedure
						                   |%1
						                   |of deferred update handler
						                   |%2.'; 
						                   |pl = 'Jest wykonywana procedura wypełnienia danych
						                   |""%1""
						                   |odroczonego programu przetwarzania aktualizacji
						                   |""%2"".';
						                   |es_ES = 'Se está realizando el procedimiento de relleno de datos
						                   |""%1""
						                   | del procesador aplazado de actualización
						                   |""%2"".';
						                   |es_CO = 'Se está realizando el procedimiento de relleno de datos
						                   |""%1""
						                   | del procesador aplazado de actualización
						                   |""%2"".';
						                   |tr = '"
"%1Ertelenmiş güncelleme işleyicisinin 
						                   |veri doldurma prosedürü yürütülüyor 
						                   |%2.';
						                   |it = 'Eseguendo la procedura di popolazione dati
						                   |%1
						                   |del gestore aggiornamento posticipato
						                   |%2';
						                   |de = 'Der Vorgang zum Ausfüllen der Daten
						                   |""%1""
						                   |des verzögerten Aktualisierung-Handlers
						                   |""%2"" wird durchgeführt.'");
					Message = StringFunctionsClientServer.SubstituteParametersToString(Message,
						Handler.UpdateDataFillingProcedure,
						Handler.HandlerName);
					WriteInformation(Message);
					
					Common.ExecuteConfigurationMethod(Handler.UpdateDataFillingProcedure, HandlerParameters);
				Except
					WriteError(StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'При вызове процедуры заполнения данных
								   |""%1""
								   |отложенного обработчика обновления
								   |""%2""
								   |произошла ошибка:
								   |""%3"".'; 
								   |en = 'Error while calling data population procedure 
								   |%1
								   |of deferred update handler
								   |%2:
								   |%3
								   |'; 
								   |pl = 'Podczas wywołania procedury wypełnienia danych
								   |""%1""
								   |odroczonego programu przetwarzania aktualizacji
								   |""%2""
								   |zaistniał błąd:
								   |""%3"".';
								   |es_ES = 'Al llamar el procedimiento del relleno de datos
								   |""%1""
								   | del procesador aplazado de actualización
								   |""%2""
								   |se ha producido un error:
								   |""%3"".';
								   |es_CO = 'Al llamar el procedimiento del relleno de datos
								   |""%1""
								   | del procesador aplazado de actualización
								   |""%2""
								   |se ha producido un error:
								   |""%3"".';
								   |tr = 'Ertelenen güncelleştirme işleyicisi "
" %1
								   |veri doldurma %3prosedürü çağrıldığında bir 
								   |
								   |hata oluştu:%2 "
".';
								   |it = 'Errore durante la chiamata alla procedura di inserimento dati 
								   |%1
								   |del gestore di aggiornamenti differiti
								   |%2:
								   |%3
								   |';
								   |de = 'Beim Aufrufen der Prozedur zum Füllen der Daten
								   |""%1""
								   |des verzögerten Aktualisierungs-Handlers
								   |""%2""
								   |ist ein Fehler aufgetreten:
								   |""%3"".'"),
						Handler.UpdateDataFillingProcedure,
						Handler.HandlerName,
						DetailErrorDescription(ErrorInfo())));
					
					Raise;
				EndTry;
				
				DataToProcess.Insert(Handler.HandlerName, HandlerParametersStructure.HandlerData);
			EndDo;
		EndDo;
		
	EndDo;
	
	UpdateInfo.DataToProcess = DataToProcess;
	WriteInfobaseUpdateInfo(UpdateInfo);
	
EndProcedure

// Returns parameters of the deferred update handler.
// Checks whether the update handler has saved parameters and returns these parameters.
// 
// 
// Parameters:
//  ID - String, UUID - the name or unique ID of the handler procedure.
//                  
//
// Returns:
//  Structure - saved parameters of the update handler.
//
Function DeferredUpdateHandlerParameters(ID) Export
	UpdateInfo = InfobaseUpdateInfo();
	HandlersTree = UpdateInfo.HandlersTree.Rows;
	
	If TypeOf(ID) = Type("UUID") Then
		UpdateHandler = HandlersTree.Find(ID, "ID", True);
	Else
		UpdateHandler = HandlersTree.Find(ID, "HandlerName", True);
	EndIf;
	
	If UpdateHandler = Undefined Then
		Return Undefined;
	EndIf;
	
	Parameters = UpdateHandler.ExecutionStatistics["HandlerParameters"];
	If Parameters = Undefined Then
		Parameters = New Structure;
	EndIf;
	
	Return Parameters;
EndFunction

// Saves parameters of the deferred update handler.
// 
// Parameters:
//  ID - String, UUID - the name or unique ID of the handler procedure.
//                  
//  Parameters     - Structure - parameters to save.
//
Procedure WriteDeferredUpdateHandlerParameters(ID, Parameters) Export
	UpdateInfo = InfobaseUpdateInfo();
	HandlersTree = UpdateInfo.HandlersTree.Rows;
	
	If TypeOf(ID) = Type("UUID") Then
		UpdateHandler = HandlersTree.Find(ID, "ID", True);
	Else
		UpdateHandler = HandlersTree.Find(ID, "HandlerName", True);
	EndIf;
	
	If UpdateHandler = Undefined Then
		Return;
	EndIf;
	
	UpdateHandler.ExecutionStatistics.Insert("HandlerParameters", Parameters);
	WriteInfobaseUpdateInfo(UpdateInfo);
EndProcedure

// Returns the number of infobase update threads.
//
// If this number is specified in the UpdateThreadCount command-line parameter, returns the value of the parameter.
// Otherwise, returns the value of the InfobaseUpdateThreadCount constant (if defined).
// Otherwise, returns the default value (see DefaultInfobaseUpdateThreadCount())
//
// Returns:
//  Number - number of threads.
//
Function InfobaseUpdateThreadCount() Export
	
	If MultithreadUpdateAllowed() Then
		Count = 0;
		ParameterName = "UpdateThreadCount=";
		Parameters = SessionParameters.ClientParametersAtServer.Get("LaunchParameter");
		ParameterPosition = StrFind(Parameters, ParameterName);
		
		If ParameterPosition > 0 Then
			SeparatorPosition = StrFind(Parameters, ";",, ParameterPosition + StrLen(ParameterName));
			Length = ?(SeparatorPosition > 0, SeparatorPosition, StrLen(Parameters) + 1) - ParameterPosition;
			UpdateThreads = StrSplit(Mid(Parameters, ParameterPosition, Length), "=");
			
			Try
				Count = Number(UpdateThreads[1]);
			Except
				ExceptionText = NStr(
					"ru = 'Параметр запуска программы ""UpdateThreadCount"" необходимо указать в формате
					|""UpdateThreadCount=Х"", где ""Х"" - максимальное количество потоков обновления.'; 
					|en = 'Specify the application startup parameter UpdateThreadCount in the ""UpdateThreadCount=X"" format,
					|where X is the maximum number of update threads.'; 
					|pl = 'Parametr uruchomienia programu UpdateThreadCount w ""UpdateThreadCount=X"" formacie,
					|gdzie X maksymalna ilość przepływów aktualizacji.';
					|es_ES = 'Es necesario indicar parámetro de lanzar el programa ""UpdateThreadCount"" en el formato
					| ""UpdateThreadCount=X"" donde ""X"" es la cantidad máxima de los flujos de actualización.';
					|es_CO = 'Es necesario indicar parámetro de lanzar el programa ""UpdateThreadCount"" en el formato
					| ""UpdateThreadCount=X"" donde ""X"" es la cantidad máxima de los flujos de actualización.';
					|tr = '""GüncellemeAkışısayısı"" uygulamasının başlatma seçeneği ""GüncelleştirmeAkışıSayısı = X"" 
					|biçiminde belirtilmelidir; burada ""X"" en fazla güncelleme akışı sayısıdır.';
					|it = 'Specificare il parametro di avvio dell''applicazione AggiornareConteggioThread nel formato ""UpdateThreadCount=X"", 
					|dove X è il numero massimo di thread aggiornati.';
					|de = 'Der Startparameter des Programms ""AnzahlThreadUpdates"" muss im Format
					|""AnzahlThreadUpdates=X"" angegeben werden, wobei ""X"" die maximale Anzahl von Update-Threads ist.'");
				Raise ExceptionText;
			EndTry;
		EndIf;
		
		If Count = 0 Then
			Count = Constants.InfobaseUpdateThreadCount.Get();
			
			If Count = 0 Then
				Count = DefaultInfobaseUpdateThreadCount();
			EndIf;
		EndIf;
		
		Return Count;
	Else
		Return 1;
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddSessionParametersSettingHandlers. 
Procedure OnAddSessionParameterSettingHandlers(Handlers) Export
	
	Handlers.Insert("IBUpdateInProgress", "InfobaseUpdateInternal.SessionParametersSetting");
	Handlers.Insert("UpdateHandlerParameters", "InfobaseUpdateInternal.SessionParametersSetting");
	Handlers.Insert("CanceledTimeConsumingOperations", "TimeConsumingOperations.SessionParametersSetting");
	
EndProcedure

// See CommonOverridable.OnAddRefsSearchExceptions. 
Procedure OnAddReferenceSearchExceptions(RefSearchExclusions) Export
	
	RefSearchExclusions.Add(Metadata.InformationRegisters.DataProcessedInMasterDIBNode.FullName());

EndProcedure

// See MonitoringCenterOverridable.OnCollectConfigurationStatisticsParameters. 
Procedure OnCollectConfigurationStatisticsParameters() Export
	
	If Not Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		Return;
	EndIf;
	
	ModuleMonitoringCenter = Common.CommonModule("MonitoringCenter");
	
	UpdateInfo = InfobaseUpdateInfo();
	If UpdateInfo.DeferredUpdateCompletedSuccessfully <> True Then
		Return; // Getting information only when the deferred update has completed successfully.
	EndIf;
	
	For Each TreeRowLibrary In UpdateInfo.HandlersTree.Rows Do
		For Each TreeRowVersion In TreeRowLibrary.Rows Do
			For Each Handler In TreeRowVersion.Rows Do
				ModuleMonitoringCenter.WriteConfigurationObjectStatistics("DeferredHandlerExecutionTime." + Handler.HandlerName, Handler.ExecutionStatistics["ExecutionDuration"] / 1000);
			EndDo;
		EndDo;
	EndDo;
	
	StartTime = UpdateInfo.UpdateStartTime;
	EndTime = UpdateInfo.UpdateEndTime;
	
	If ValueIsFilled(StartTime) AND ValueIsFilled(EndTime) Then
		ModuleMonitoringCenter.WriteConfigurationObjectStatistics("HandlersExecutionTime",
			EndTime - StartTime);
	EndIf;
	
	StartTime = UpdateInfo.DeferredUpdateStartTime;
	EndTime = UpdateInfo.DeferredUpdateEndTime;
	
	If ValueIsFilled(StartTime) AND ValueIsFilled(EndTime) Then
		ModuleMonitoringCenter.WriteConfigurationObjectStatistics("DeferredHandlersExecutionTime",
			EndTime - StartTime);
	EndIf;
	
EndProcedure

// See StandardSubsystemsServer.OnSendDataToSlave. 
Procedure OnSendDataToSlave(DataItem, ItemSend, InitialImageCreation, Recipient) Export
	
	OnSendSubsystemVersions(DataItem, ItemSend, InitialImageCreation);
	
EndProcedure

// See StandardSubsystemsServer.OnSendDataToMaster. 
Procedure OnSendDataToMaster(DataItem, ItemSend, Recipient) Export
	
	OnSendSubsystemVersions(DataItem, ItemSend);
	
EndProcedure

// See CommonOverridable.OnAddClientParametersOnStart. 
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	Parameters.Insert("InitialDataFilling", DataUpdateMode() = "InitialFilling");
	Parameters.Insert("ShowApplicationReleaseNotes", ShowApplicationReleaseNotes());
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	HandlersStatus = UncompletedHandlersStatus();
	If HandlersStatus = "" Then
		Return;
	EndIf;
	If HandlersStatus = "ErrorStatus"
		AND Users.IsFullUser(, True) Then
		Parameters.Insert("ShowInvalidHandlersMessage");
	Else
		Parameters.Insert("ShowUncompletedHandlersNotification");
	EndIf;
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	If Common.SubsystemExists("StandardSubsystems.SoftwareLicenseCheck") Then
		Handler = Handlers.Add();
		Handler.InitialFilling = True;
		Handler.Procedure = "InfobaseUpdateInternal.WriteLegitimateSoftwareConfirmation";
	EndIf;
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.4";
	Handler.Procedure = "InfobaseUpdateInternal.SetReleaseNotesVersion";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.19";
	Handler.Procedure = "InfobaseUpdateInternal.MoveSubsystemVersionsToSharedData";
	Handler.SharedData = True;
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.2.7";
	Handler.Procedure = "InfobaseUpdateInternal.FillAttributeIsMainConfiguration";
	Handler.SharedData = True;
	
EndProcedure

// See JobQueueOverridable.OnReceiveTemplateList. 
Procedure OnGetTemplateList(JobTemplates) Export
	
	JobTemplates.Add("DeferredIBUpdate");
	
EndProcedure

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If Not Users.IsFullUser(, True)
		Or ModuleToDoListServer.UserTaskDisabled("DeferredUpdate") Then
		Return;
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	// This procedure is only called when To-do list subsystem is available. Therefore, the subsystem 
	// availability check is redundant.
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.DataProcessors.ApplicationUpdateResult.FullName());
	
	HandlersStatus           = UncompletedHandlersStatus();
	HasHandlersWithErrors      = (HandlersStatus = "ErrorStatus");
	HasUncompletedHandlers = (HandlersStatus = "UncompletedStatus");
	HasPausedHandlers = (HandlersStatus = "SuspendedStatus");
	
	For Each Section In Sections Do
		ID = "DeferredUpdate" + StrReplace(Section.FullName(), ".", "");
		UserTask = ToDoList.Add();
		UserTask.ID = ID;
		UserTask.HasUserTasks      = (HasHandlersWithErrors Or HasUncompletedHandlers Or HasPausedHandlers);
		UserTask.Important        = HasHandlersWithErrors;
		UserTask.Presentation = NStr("ru = 'Обновление программы не завершено'; en = 'Application update is not completed'; pl = 'Aktualizacja aplikacji nie została zakończona';es_ES = 'Actualización de la aplicación no se ha finalizado';es_CO = 'Actualización de la aplicación no se ha finalizado';tr = 'Uygulama güncellemesi tamamlanmadı';it = 'L''aggiornamento dell''applicazione non viene completato';de = 'Anwendungsupdate ist nicht abgeschlossen'");
		UserTask.Form         = "DataProcessor.ApplicationUpdateResult.Form.DeferredIBUpdateProgressIndicator";
		UserTask.Owner      = Section;
	EndDo;
	
EndProcedure

// See ReportsOptionsOverridable.CustomizeReportOptions. 
Procedure OnSetUpReportsOptions(Settings) Export
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.DeferredUpdateProgress);
EndProcedure

// See StandardSubsystemsServer.ValidateExchangePlanComposition. 
Procedure OnGetExchangePlanInitialImageObjects(Objects) Export
	
	Objects.Add(Metadata.InformationRegisters.SubsystemsVersions);
	
EndProcedure

// Restarts the deferred handlers running in the master node when the first exchange message is 
// received.
//
Procedure OnGetFirstDIBExchangeMessageAfterUpdate() Export
	
	SetPrivilegedMode(True);
	
	FileInfobase = Common.FileInfobase();
	UpdateInfo       = InfobaseUpdateInfo();
	If UpdateInfo.DeferredUpdateCompletedSuccessfully = Undefined
		AND Not FileInfobase Then
		CancelDeferredUpdate();
		FilterParameters = New Structure;
		FilterParameters.Insert("MethodName", "InfobaseUpdateInternal.ExecuteDeferredUpdate");
		FilterParameters.Insert("State", BackgroundJobState.Active);
		BackgroundJobArray = BackgroundJobs.GetBackgroundJobs(FilterParameters);
		If BackgroundJobArray.Count() = 1 Then
			BackgroundJob = BackgroundJobArray[0];
			BackgroundJob.Cancel();
		EndIf;
	EndIf;
	
	UpdateIterations = UpdateIterations();
	GenerateDeferredUpdateHandlerList(UpdateIterations, True);
	ReregisterDataForDeferredUpdate();
	If FileInfobase Then
		ExecuteDeferredUpdateNow();
	Else
		ScheduleDeferredUpdate();
	EndIf;
	
EndProcedure

// Called while executing the update script in procedure ConfigurationUpdate.FinishUpdate().
Procedure AfterUpdateCompletion() Export
	
	WriteLegitimateSoftwareConfirmation();
	
EndProcedure

// See ExportImportDataOverridable.AfterDataImport. 
Procedure AfterImportData(Container) Export
	UpdateInfo = InfobaseUpdateInfo();
	
	If UpdateInfo.DeferredUpdateCompletedSuccessfully <> True Then
		ScheduleDeferredUpdate();
	EndIf;
EndProcedure

#EndRegion

#Region Private

// Returns the flag indicating whether multithread updates are allowed.
// You can enable multithread updates in InfobaseUpdateOverridable.OnDefineSettings().
//
// Returns:
//  Boolean - multithread updates are allowed if True. The default value is False (for backward compatibility).
//
Function MultithreadUpdateAllowed() Export
	
	Parameters = SubsystemSettings();
	Return Parameters.MultiThreadUpdate;
	
EndFunction

// See CommonOverridable.OnAddSessionParametersSettingHandlers. 
Procedure SessionParametersSetting(Val ParameterName, SpecifiedParameters) Export
	
	If ParameterName = "IBUpdateInProgress" Then
		SessionParameters.IBUpdateInProgress = InfobaseUpdate.InfobaseUpdateRequired();
		SpecifiedParameters.Add("IBUpdateInProgress");
	ElsIf ParameterName = "UpdateHandlerParameters" Then
		SessionParameters.UpdateHandlerParameters = New FixedStructure(NewUpdateHandlerParameters());
		SpecifiedParameters.Add("UpdateHandlerParameters");
	EndIf;
	
EndProcedure

Function SubsystemSettings() Export
	
	UncompletedDeferredHandlersMessageParameters = New Structure;
	UncompletedDeferredHandlersMessageParameters.Insert("MessageText", "");
	UncompletedDeferredHandlersMessageParameters.Insert("MessagePicture", Undefined);
	UncompletedDeferredHandlersMessageParameters.Insert("ProhibitContinuation", False);
	
	
	Settings = New Structure;
	Settings.Insert("UpdateResultNotes", "");
	Settings.Insert("ApplicationReleaseNotesLocation", "");
	Settings.Insert("UncompletedDeferredHandlersMessageParameters", UncompletedDeferredHandlersMessageParameters);
	Settings.Insert("MultiThreadUpdate", False);
	Settings.Insert("DefaultInfobaseUpdateThreadCount", 1);
	
	Settings.Insert("ObjectsWithInitialFilling", New Array);
	SSLSubsystemsIntegration.OnDefineObjectsWithInitialFilling(Settings.ObjectsWithInitialFilling);
	
	InfobaseUpdateOverridable.OnDefineSettings(Settings);
	
	Return Settings;
	
EndFunction

// Returns numeric weight coefficient of a version, used to compare and prioritize between versions.
//
// Parameters:
//  Version - String - Version in string format.
//
// Returns:
//  Number - weight of the version.
//
Function VersionWeight(Val Version) Export
	
	If Version = "" Then
		Return 0;
	EndIf;
	
	Return VersionWeightFromStringArray(StrSplit(Version, "."));
	
EndFunction

// For internal use.
//
Function UpdateIteration(ConfigurationOrLibraryName, Version, Handlers, IsMainConfiguration = Undefined) Export
	
	UpdateIteration = New Structure;
	UpdateIteration.Insert("Subsystem",  ConfigurationOrLibraryName);
	UpdateIteration.Insert("Version",      Version);
	UpdateIteration.Insert("IsMainConfiguration", 
		?(IsMainConfiguration <> Undefined, IsMainConfiguration, ConfigurationOrLibraryName = Metadata.Name));
	UpdateIteration.Insert("Handlers", Handlers);
	UpdateIteration.Insert("CompletedHandlers", Undefined);
	UpdateIteration.Insert("MainServerModuleName", "");
	UpdateIteration.Insert("MainServerModule", "");
	UpdateIteration.Insert("PreviousVersion", "");
	Return UpdateIteration;
	
EndFunction

// For internal use.
//
Function UpdateIterations()
	
	BaseConfigurationName = Metadata.Name;
	MainSubsystemUpdateIteration = Undefined;
	
	UpdateIterations = New Array;
	SubsystemsDetails  = StandardSubsystemsCached.SubsystemsDetails();
	For each SubsystemName In SubsystemsDetails.Order Do
		SubsystemDetails = SubsystemsDetails.ByNames.Get(SubsystemName);
		If NOT ValueIsFilled(SubsystemDetails.MainServerModule) Then
			Continue;
		EndIf;
		Module = Common.CommonModule(SubsystemDetails.MainServerModule);
		
		UpdateIteration = UpdateIteration(SubsystemDetails.Name, SubsystemDetails.Version, 
			InfobaseUpdate.NewUpdateHandlerTable(), SubsystemDetails.Name = BaseConfigurationName);
		UpdateIteration.MainServerModuleName = SubsystemDetails.MainServerModule;
		UpdateIteration.MainServerModule = Module;
		UpdateIteration.PreviousVersion = IBVersion(SubsystemDetails.Name);
		UpdateIterations.Add(UpdateIteration);
		
		Module.OnAddUpdateHandlers(UpdateIteration.Handlers);
		
		If SubsystemDetails.Name = BaseConfigurationName Then
			MainSubsystemUpdateIteration = UpdateIteration;
		EndIf;
		
		ValidateHandlerProperties(UpdateIteration);
	EndDo;
	
	If MainSubsystemUpdateIteration = Undefined AND BaseConfigurationName = "StandardSubsystemsLibrary" Then
		MessageText = NStr("ru = 'Файл поставки 1С:Библиотека стандартных подсистем не предназначен для создания
			|информационных баз по шаблону. Перед использованием необходимо
			|ознакомиться с документацией на ИТС (http://its.1c.ru/db/bspdoc)'; 
			|en = 'The 1C:Standard Subsystems Library distribution file is not intended
			|for template-based infobase creation. Before you start using it, 
			|read the documentation available on ITS (http://its.1c.ru/db/bspdoc, in Russian).'; 
			|pl = 'Plik dystrybucji 1C:Standard Subsystems Library nie jest przeznaczony do
			|tworzenia baz informacyjnych opartych na szablonach. Zanim zaczniesz go używać, przeczytaj
			|dokumentację dostępną w ITS (http://its.1c.ru/db/bspdoc, w języku rosyjskim).';
			|es_ES = 'El archivo de suministro 1C:Biblioteca de los subsistema estándares no está destinado para crear
			|las bases de información por la plantilla. Antes de usar es necesario
			|leer la documentación en ITS (http://its.1c.ru/db/bspdoc)';
			|es_CO = 'El archivo de suministro 1C:Biblioteca de los subsistema estándares no está destinado para crear
			|las bases de información por la plantilla. Antes de usar es necesario
			|leer la documentación en ITS (http://its.1c.ru/db/bspdoc)';
			|tr = '1C:Standart alt sistemler kitaplığı teslimat dosyası, 
			|veri tabanlarını şablondan oluşturmak üzere tasarlanmamıştır. Kullanmadan önce, 
			|ITS belgeleri incelenmelidir (http://its.1c.ru/db/bspdoc)';
			|it = 'File di consegna 1C:La libreria di sottosistemi standard non è progettata per creare
			|basi informative basate su modelli. Prima di utilizzare, è necessario
			|consultare la documentazione dell''ITS (http://its.1c.ru/db/bspdoc).';
			|de = 'Die Lieferdatei 1C:Bibliothek von Standard-Subsystemen ist nicht für die Erstellung von
			|Informationsbasen auf einer Vorlage vorgesehen. Vor der Verwendung ist es notwendig,
			|die Dokumentation zum ITS (http://its.1c.ru/db/bspdoc) zu lesen.'");
		Raise MessageText;
	EndIf;
	
	Return UpdateIterations;
	
EndFunction

// For internal use.
//
Function ExecuteUpdateIteration(Val UpdateIteration, Val Parameters) Export
	
	LibraryID = UpdateIteration.Subsystem;
	IBMetadataVersion      = UpdateIteration.Version;
	UpdateHandlers   = UpdateIteration.Handlers;
	
	CurrentIBVersion = UpdateIteration.PreviousVersion;
	
	NewIBVersion = CurrentIBVersion;
	MetadataVersion = IBMetadataVersion;
	If IsBlankString(MetadataVersion) Then
		MetadataVersion = "0.0.0.0";
	EndIf;
	
	If CurrentIBVersion <> "0.0.0.0"
		AND Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable() Then
		
		// Getting an update plan generated during the shared handler execution phase.
		HandlersToExecute = GetUpdatePlan(LibraryID, CurrentIBVersion, MetadataVersion);
		If HandlersToExecute = Undefined Then
			If UpdateIteration.IsMainConfiguration Then 
				MessageTemplate = NStr("ru = 'Не найден план обновления конфигурации %1 с версии %2 на версию %3'; en = 'Update plan for configuration %1 (version %2 to %3) is not found.'; pl = 'Nie znaleziono planu aktualizacji konfiguracji %1 (z wersji %2 do wersji %3).';es_ES = 'Plan de actualización de la configuración %1 de la versión %2 a la versión %3 no se ha encontrado';es_CO = 'Plan de actualización de la configuración %1 de la versión %2 a la versión %3 no se ha encontrado';tr = 'Sürümden sürüme yapılandırmanın%1 güncelleme%2 planı bulunamadı%3';it = 'Piano di aggiornamento della configurazione %1 (dalla versione %2 alla %3) non trovato.';de = 'Aktualisierungsplan der Konfiguration %1 von Version %2 zu Version %3 wurde nicht gefunden'");
			Else
				MessageTemplate = NStr("ru = 'Не найден план обновления библиотеки %1 с версии %2 на версию %3'; en = 'Update plan for library %1 (version %2 to %3) is not found.'; pl = 'Nie znaleziono planu aktualizacji biblioteki %1 (z wersji %2 do wersji %3).';es_ES = 'Plan de actualización de la biblioteca %1 de la versión %2 a la versión %3 no se ha encontrado';es_CO = 'Plan de actualización de la biblioteca %1 de la versión %2 a la versión %3 no se ha encontrado';tr = 'Sürümden sürümüne kütüphanenin %1 güncelleme %2 planı bulunamadı %3';it = 'Piano di aggiornamento della libreria %1 (dalla versione %2 alla %3) non trovato.';de = 'Der Aktualisierungsplan der Bibliothek %1 von Version %2 zu Version %3 wurde nicht gefunden'");
			EndIf;
			Message = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, LibraryID, CurrentIBVersion, MetadataVersion);
			WriteInformation(Message);
			
			HandlersToExecute = UpdateInIntervalHandlers(UpdateHandlers, CurrentIBVersion, MetadataVersion);
		EndIf;
	Else
		HandlersToExecute = UpdateInIntervalHandlers(UpdateHandlers, CurrentIBVersion, MetadataVersion);
	EndIf;
	
	DetachUpdateHandlers(LibraryID, HandlersToExecute, MetadataVersion, Parameters.HandlerExecutionProgress);
	
	MandatorySeparatedHandlers = InfobaseUpdate.NewUpdateHandlerTable();
	SourceIBVersion = CurrentIBVersion;
	WriteToLog = Constants.WriteIBUpdateDetailsToEventLog.Get();
	
	For Each Version In HandlersToExecute.Rows Do
		
		If Version.Version = "*" Then
			Message = NStr("ru = 'Выполняются обязательные процедуры обновления информационной базы.'; en = 'Executing mandatory infobase update procedures.'; pl = 'Trwają wymagane procedury aktualizacji bazy informacyjnej.';es_ES = 'Procedimientos requeridos de la actualización de la infobase están en progreso.';es_CO = 'Procedimientos requeridos de la actualización de la infobase están en progreso.';tr = 'Zorunlu Infobase güncellemesi prosedürleri yürütülüyor.';it = 'Processi di aggiornamento obbligatorio di infobase in corso.';de = 'Die erforderlichen Verfahren zur Aktualisierung der Infobase sind in Bearbeitung.'");
		Else
			NewIBVersion = Version.Version;
			If CurrentIBVersion = "0.0.0.0" Then
				Message = NStr("ru = 'Выполняется начальное заполнение данных.'; en = 'Populating data.'; pl = 'Trwa początkowe wypełnienie danych.';es_ES = 'Población de los datos iniciales está en progreso.';es_CO = 'Población de los datos iniciales está en progreso.';tr = 'İlk veri doldurulması devam ediyor';it = 'Riempendo i dati.';de = 'Die anfängliche Datenpopulation ist in Bearbeitung.'");
			ElsIf UpdateIteration.IsMainConfiguration Then 
				Message = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Выполняется обновление информационной базы с версии %1 на версию %2.'; en = 'Updating infobase version %1 to version %2.'; pl = 'Trwa aktualizacja bazy informacyjnej z wersji %1 do wersji %2.';es_ES = 'Actualizando la infobase de la versión %1 a la versión %2.';es_CO = 'Actualizando la infobase de la versión %1 a la versión %2.';tr = 'Infobase %1 sürümünden %2 sürümüne güncelleniyor.';it = 'Viene aggiornato il database di informazioni dalla versione %1 alla versione %2.';de = 'Aktualisieren der Infobase von Version %1 zu Version %2.'"), 
					CurrentIBVersion, NewIBVersion);
			Else
				Message = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Выполняется обновление данных библиотеки %3 с версии %1 на версию %2.'; en = 'Updating %3 library version %1 to version %2.'; pl = 'Aktualizacja danych biblioteki %3 z wersji %1 do wersji %2.';es_ES = 'Actualizando los datos de la biblioteca %3 de la versión %1 a la versión %2.';es_CO = 'Actualizando los datos de la biblioteca %3 de la versión %1 a la versión %2.';tr = '%3 kütüphanesi %1 sürümünden %2 sürümüne güncelleniyor.';it = 'Aggiorna i dati della libreria %3 dalla versione %1 alla versione %2.';de = 'Aktualisieren von Daten der Bibliothek %3 von Version %1 zu Version %2.'"), 
					CurrentIBVersion, NewIBVersion, LibraryID);
			EndIf;
		EndIf;
		WriteInformation(Message);
		
		For Each Handler In Version.Rows Do
			
			HandlerParameters = Undefined;
			If Handler.RegistrationVersion = "*" Then
				
				If Handler.HandlerManagement Then
					HandlerParameters = New Structure;
					HandlerParameters.Insert("SeparatedHandlers", MandatorySeparatedHandlers);
				EndIf;
				
				If Handler.ExclusiveMode = True Or Handler.ExecutionMode = "Exclusive" Then
					If Parameters.NonexclusiveUpdate Then
						// Checks are performed in CanExecuteNonexclusiveUpdate(). For these handlers, the update is only 
						// performed in case of regular update.
						Continue;
					EndIf;
					
					If HandlerParameters = Undefined Then
						HandlerParameters = New Structure;
					EndIf;
					HandlerParameters.Insert("ExclusiveMode", True);
				EndIf;
			EndIf;
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("WriteToLog", WriteToLog);
			AdditionalParameters.Insert("LibraryID", LibraryID);
			AdditionalParameters.Insert("HandlerExecutionProgress", Parameters.HandlerExecutionProgress);
			AdditionalParameters.Insert("InBackground", Parameters.InBackground);
			
			ExecuteUpdateHandler(Handler, HandlerParameters, AdditionalParameters);
		EndDo;
		
		If Version.Version = "*" Then
			Message = NStr("ru = 'Выполнены обязательные процедуры обновления информационной базы.'; en = 'Mandatory infobase update procedures are completed.'; pl = 'Żądane procedury aktualizacji bazy informacyjnej zostały przeprowadzone.';es_ES = 'Procedimientos requeridos de la actualización de la infobase se han realizado.';es_CO = 'Procedimientos requeridos de la actualización de la infobase se han realizado.';tr = 'Zorunlu Infobase güncellemesi prosedürleri tamamlandı.';it = 'Processi di aggiornamento obbligatorio di infobase completati.';de = 'Erforderliche Prozeduren der Infobase-Aktualisierung werden durchgeführt.'");
		Else
			If UpdateIteration.IsMainConfiguration Then 
				Message = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Выполнено обновление информационной базы с версии %1 на версию %2.'; en = 'Infobase update from version %1 to version %2 is completed.'; pl = 'Baza informacyjna została zaktualizowana z wersji %1 do wersji %2.';es_ES = 'Actualización de la infobase de la versión %1 a la versión %2 se ha finalizado.';es_CO = 'Actualización de la infobase de la versión %1 a la versión %2 se ha finalizado.';tr = '%1 sürümünden %2 sürümüne Infobase güncellemesi tamamlandı.';it = 'InfoBase è stato aggiornato dalla versione %1 al %2.';de = 'Infobase-Update von Version %1 zu Version %2 ist abgeschlossen.'"), 
					CurrentIBVersion, NewIBVersion);
			Else
				Message = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Выполнено обновление данных библиотеки %3 с версии %1 на версию %2.'; en = 'The update of %3 library from version %1 to version %2 is completed.'; pl = 'Dane biblioteki %3 zostały zaktualizowane z wersji %1 do wersji %2.';es_ES = 'Datos de la biblioteca %3 se han actualizado de la versión %1 a la versión %2.';es_CO = 'Datos de la biblioteca %3 se han actualizado de la versión %1 a la versión %2.';tr = '%3 kütüphanesi %2 sürümünden %1 sürümüne güncellendi.';it = 'Sono aggiornati i dati della libreria %3 dalla versione %1 alla versione %2.';de = 'Daten der Bibliothek %3 werden von Version %1 zu Version %2 aktualisiert.'"), 
					CurrentIBVersion, NewIBVersion, LibraryID);
			EndIf;
		EndIf;
		WriteInformation(Message);
		
		If Version.Version <> "*" Then
			// Setting infobase version number.
			SetIBVersion(LibraryID, NewIBVersion, UpdateIteration.IsMainConfiguration);
			CurrentIBVersion = NewIBVersion;
		EndIf;
		
	EndDo;
	
	// Setting infobase version number.
	If IBVersion(LibraryID) <> IBMetadataVersion Then
		SetIBVersion(LibraryID, IBMetadataVersion, UpdateIteration.IsMainConfiguration);
	EndIf;
	
	If CurrentIBVersion <> "0.0.0.0" Then
		
		If Common.SubsystemExists("StandardSubsystems.SaaS.IBVersionUpdateSaaS") Then
			
			ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
			ModuleInfobaseUpdateInternalSaaS.GenerateDataAreaUpdatePlan(LibraryID, UpdateHandlers,
				MandatorySeparatedHandlers, SourceIBVersion, IBMetadataVersion);
			
		EndIf;
		
	EndIf;
	
	Return HandlersToExecute;
	
EndFunction

// Verifies whether the current user has sufficient rights to update an infobase.
Function CanUpdateInfobase(ForPrivilegedMode = True, SeparatedData = Undefined) Export
	
	CheckSystemAdministrationRights = True;
	
	If SeparatedData = Undefined Then
		SeparatedData = NOT Common.DataSeparationEnabled()
			OR Common.SeparatedDataUsageAvailable();
	EndIf;
	
	If Common.DataSeparationEnabled()
	   AND SeparatedData Then
		
		If NOT Common.SeparatedDataUsageAvailable() Then
			Return False;
		EndIf;
		CheckSystemAdministrationRights = False;
	EndIf;
	
	Return Users.IsFullUser(
		, CheckSystemAdministrationRights, ForPrivilegedMode);
	
EndFunction

// For internal use.
//
Function UpdateInfobaseInBackground(UUIDOfForm, IBLock) Export
	
	// Run the background job
	IBUpdateParameters = New Structure;
	IBUpdateParameters.Insert("ExceptionOnCannotLockIB", False);
	IBUpdateParameters.Insert("IBLock", IBLock);
	IBUpdateParameters.Insert("ClientParametersAtServer", SessionParameters.ClientParametersAtServer);
	
	// Enabling exclusive mode before starting the update procedure in background
	Try
		LockIB(IBUpdateParameters.IBLock, False);
	Except
		ErrorInformation = ErrorInfo();
		
		Result = New Structure;
		Result.Insert("Status",    "Error");
		Result.Insert("IBLock", IBUpdateParameters.IBLock);
		Result.Insert("BriefErrorPresentation", BriefErrorDescription(ErrorInformation));
		Result.Insert("DetailedErrorPresentation", DetailErrorDescription(ErrorInformation));
		
		Return Result;
	EndTry;
	
	IBUpdateParameters.Insert("InBackground", Not IBUpdateParameters.IBLock.DebugMode);
	
	If Not IBUpdateParameters.InBackground Then
		IBUpdateParameters.Delete("ClientParametersAtServer");
	EndIf;
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUIDOfForm);
	ExecutionParameters.WaitForCompletion = 0;
	ExecutionParameters.BackgroundJobDescription = NStr("ru = 'Фоновое обновление информационной базы'; en = 'Background infobase update'; pl = 'Aktualizacja bazy informacyjnej w tle';es_ES = 'Actualización del fondo de la infobase';es_CO = 'Actualización del fondo de la infobase';tr = 'Arka plan Infobase güncellemesi';it = 'Aggiornamento infobase in background';de = 'Hintergrund-Update der Infobase'");
	
	Result = TimeConsumingOperations.ExecuteInBackground("InfobaseUpdateInternal.RunInfobaseUpdateInBackground",
		IBUpdateParameters, ExecutionParameters);
	
	Result.Insert("IBLock", IBUpdateParameters.IBLock);
	
	// Unlocking the infobase if the infobase update has completed.
	If Result.Status <> "Running" Then
		UnlockIB(IBUpdateParameters.IBLock);
	EndIf;
	
	Return Result;
	
EndFunction

// Starts infobase update as a time-consuming operation.
Function RunInfobaseUpdateInBackground(IBUpdateParameters, StorageAddress) Export
	
	If IBUpdateParameters.InBackground Then
		SessionParameters.ClientParametersAtServer = IBUpdateParameters.ClientParametersAtServer;
	EndIf;
	
	ErrorInformation = Undefined;
	Try
		UpdateParameters = UpdateParameters();
		UpdateParameters.ExceptionOnCannotLockIB = IBUpdateParameters.ExceptionOnCannotLockIB;
		UpdateParameters.OnClientStart = True;
		UpdateParameters.Restart = False;
		UpdateParameters.IBLockSet = IBUpdateParameters.IBLock;
		UpdateParameters.InBackground = IBUpdateParameters.InBackground;
		
		Result = UpdateInfobase(UpdateParameters);
	Except
		ErrorInformation = ErrorInfo();
		// Preparing to open the form for data resynchronization before startup with two options, 
		// "Synchronize and continue" and "Continue".
		If Common.SubsystemExists("StandardSubsystems.DataExchange")
		   AND Common.IsSubordinateDIBNode() Then
			ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
			ModuleDataExchangeServer.EnableDataExchangeMessageImportRecurrenceBeforeStart();
		EndIf;
	EndTry;
	
	If ErrorInformation <> Undefined Then
		UpdateResult = New Structure;
		UpdateResult.Insert("BriefErrorPresentation", BriefErrorDescription(ErrorInformation));
		UpdateResult.Insert("DetailedErrorPresentation", DetailErrorDescription(ErrorInformation));
	ElsIf Not IBUpdateParameters.InBackground Then
		UpdateResult = Result;
	Else
		UpdateResult = New Structure;
		UpdateResult.Insert("ClientParametersAtServer", SessionParameters.ClientParametersAtServer);
		UpdateResult.Insert("Result", Result);
	EndIf;
	PutToTempStorage(UpdateResult, StorageAddress);
	
EndFunction

// For internal use.
//
Function LockIB(IBLock, ExceptionOnCannotLockIB)
	
	UpdateIterations = Undefined;
	If IBLock = Undefined Then
		IBLock = IBLock();
	EndIf;
	
	IBLock.Use = True;
	If Common.DataSeparationEnabled() Then
		IBLock.DebugMode = False;
	Else
		IBLock.DebugMode = CommonClientServer.DebugMode();
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		IBLock.RecordKey = ModuleInfobaseUpdateInternalSaaS.LockDataAreaVersions();
	EndIf;
	
	UpdateIterations = UpdateIterations();
	IBLock.NonexclusiveUpdate = False;
	
	If IBLock.DebugMode Then
		Return UpdateIterations;
	EndIf;
	
	// Enabling exclusive mode for the infobase update purpose
	ErrorInformation = Undefined;
	Try
		If NOT ExclusiveMode() Then
			SetExclusiveMode(True);
		EndIf;
		Return UpdateIterations;
	Except
		If CanExecuteSeamlessUpdate(UpdateIterations) Then
			IBLock.NonexclusiveUpdate = True;
			Return UpdateIterations;
		EndIf;
		ErrorInformation = ErrorInfo();
	EndTry;
	
	// Processing a failed attempt to enable the exclusive mode
	Message = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Невозможно выполнить обновление информационной базы:
			|- Невозможно установить монопольный режим
			|- Версия конфигурации не предусматривает обновление без установки монопольного режима
			|
			|Подробности ошибки:
			|%1'; 
			|en = 'Cannot update the infobase:
			|- Cannot switch to exclusive mode.
			|- The configuration version does not support update in nonexclusive mode.
			|
			|Error details:
			|%1'; 
			|pl = 'Nie można zaktualizować bazy informacyjnej:
			|- Nie można ustawić
			|trybu wyłączności - Wersja konfiguracji nie zawiera aktualizacji ustawień
			|trybu
			| wyłączności 
			|Więcej o błędzie: %1';
			|es_ES = 'No se puede actualizar la infobase:
			|- No se puede establecer un
			|modo exclusivo - Versión de la configuración no incluye la actualización sin configurar
			|un
			|modo exclusivo
			|Más sobre el error: %1';
			|es_CO = 'No se puede actualizar la infobase:
			|- No se puede establecer un
			|modo exclusivo - Versión de la configuración no incluye la actualización sin configurar
			|un
			|modo exclusivo
			|Más sobre el error: %1';
			|tr = 'Veritabanı güncellenemedi: 
			|- Özel bir mod 
			|belirlenemedi - Yapılandırma sürümü, ayarları olmayan%1 modu güncellemeyi
			| içermiyor 
			|Hata hakkında daha fazla bilgi:
			|';
			|it = 'Impossibile eseguire l''aggiornamento della base di informazioni:
			| - impossibile installare la modalità esclusiva
			| - La versione di configurazione non prevede l''aggiornamento senza installare la modalità esclusiva
			|
			|Dettagli dell''errore:
			|%1';
			|de = 'Infobase kann nicht aktualisiert werden:
			|- Es kann kein exklusiver Modus eingestellt werden.
			|- Die Konfigurationsversion enthält kein Update, ohne einen exklusiven Modus.
			|
			|Fehlerdetails:
			| %1'"),
		BriefErrorDescription(ErrorInformation));
	
	WriteError(Message);
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.UnlockDataAreaVersions(IBLock.RecordKey);
	EndIf;
	
	If Not ExceptionOnCannotLockIB
	   AND Common.FileInfobase()
	   AND Common.SubsystemExists("StandardSubsystems.UserSessionsCompletion") Then
		
		ClientLaunchParameter = SessionParameters.ClientParametersAtServer.Get("LaunchParameter");
		If StrFind(ClientLaunchParameter, "ScheduledJobsDisabled") = 0 Then
			IBLock.Error = "LockScheduledJobsExecution";
		Else
			IBLock.Error = "ExclusiveModeSettingError";
		EndIf;
	EndIf;
	
	Raise Message;
	
EndFunction

// For internal use.
//
Procedure UnlockIB(IBLock) Export
	
	If IBLock.DebugMode Then
		Return;
	EndIf;
		
	If ExclusiveMode() Then
		While TransactionActive() Do
			RollbackTransaction();
		EndDo;
		
		SetExclusiveMode(False);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.UnlockDataAreaVersions(IBLock.RecordKey);
	EndIf;
	
EndProcedure

// For internal use.
//
Function IBLock()
	
	Result = New Structure;
	Result.Insert("Use", False);
	Result.Insert("Error", Undefined);
	Result.Insert("NonexclusiveUpdate", Undefined);
	Result.Insert("RecordKey", Undefined);
	Result.Insert("DebugMode", Undefined);
	Return Result;
	
EndFunction

// For internal use.
//
Function UpdateParameters() Export
	
	Result = New Structure;
	Result.Insert("ExceptionOnCannotLockIB", True);
	Result.Insert("OnClientStart", False);
	Result.Insert("Restart", False);
	Result.Insert("IBLockSet", Undefined);
	Result.Insert("InBackground", False);
	Result.Insert("ExecuteDeferredHandlers", False);
	Return Result;
	
EndFunction

// For internal use.
//
Function NewApplicationMigrationHandlerTable()
	
	Handlers = New ValueTable;
	Handlers.Columns.Add("PreviousConfigurationName",	New TypeDescription("String", New StringQualifiers(0)));
	Handlers.Columns.Add("Procedure",					New TypeDescription("String", New StringQualifiers(0)));
	Return Handlers;
	
EndFunction

// For internal use.
//
Function ApplicationMigrationHandlers(PreviousConfigurationName) 
	
	MigrationHandlers = NewApplicationMigrationHandlerTable();
	BaseConfigurationName = Metadata.Name;
	
	SubsystemsDetails  = StandardSubsystemsCached.SubsystemsDetails();
	For each SubsystemName In SubsystemsDetails.Order Do
		SubsystemDetails = SubsystemsDetails.ByNames.Get(SubsystemName);
		If NOT ValueIsFilled(SubsystemDetails.MainServerModule) Then
			Continue;
		EndIf;
		
		If SubsystemDetails.Name <> BaseConfigurationName Then
			Continue;
		EndIf;
		
		Module = Common.CommonModule(SubsystemDetails.MainServerModule);
		Module.OnAddApplicationMigrationHandlers(MigrationHandlers);
	EndDo;
	
	Filter = New Structure("PreviousConfigurationName", "*");
	Result = MigrationHandlers.FindRows(Filter);
	
	Filter.PreviousConfigurationName = PreviousConfigurationName;
	CommonClientServer.SupplementArray(Result, MigrationHandlers.FindRows(Filter), True);
	
	Return Result;
	
EndFunction

Procedure MigrateFromAnotherApplication()
	
	// Previous name of the configuration to be used as migration source.
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	SubsystemsVersions.SubsystemName AS SubsystemName,
	|	SubsystemsVersions.Version AS Version
	|FROM
	|	InformationRegister.SubsystemsVersions AS SubsystemsVersions
	|WHERE
	|	SubsystemsVersions.IsMainConfiguration = TRUE";
	QueryResult = Query.Execute();
	// If the FillAttributeIsMainConfiguration update handler fails for any reason.
	If QueryResult.IsEmpty() Then 
		Return;
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		Raise NStr("ru = 'При работе в модели сервиса переход с другой программы не предусмотрен.'; en = 'Migration from another application is unavailable in SaaS mode.'; pl = 'Podczas pracy w SaaS, przemieszczenie z innej aplikacji nie jest przewidziane.';es_ES = 'Trabajando en SaaS, transferencia de otra aplicación es inesperada.';es_CO = 'Trabajando en SaaS, transferencia de otra aplicación es inesperada.';tr = 'SaaS''de çalışırken, başka bir uygulamadan aktarma beklenmiyor.';it = 'Quando si lavora in un modello di servizio, la transizione da un altro programma non è prevista.';de = 'Wenn Sie in SaaS arbeiten, ist die Übertragung von einer anderen Anwendung unerwartet.'");
	EndIf;
	
	QueryResult = Query.Execute().Unload()[0];
	PreviousConfigurationName = QueryResult.SubsystemName;
	PreviousConfigurationVersion = QueryResult.Version;
	
	Filter = New Structure;
	Filter.Insert("LibraryName", PreviousConfigurationName);
	UpdateInfo = InfobaseUpdateInfo();
	SearchResult = UpdateInfo.HandlersTree.Rows.FindRows(Filter, True);
	For Each FoundRow In SearchResult Do
		FoundRow.LibraryName = Metadata.Name;
	EndDo;
	If SearchResult.Count() > 0 Then
		WriteInfobaseUpdateInfo(UpdateInfo);
	EndIf;
	
	Handlers = ApplicationMigrationHandlers(PreviousConfigurationName);
	
	SubsystemExists = Common.SubsystemExists("StandardSubsystems.AccessManagement");
	// Executing all migration handlers
	For Each Handler In Handlers Do
		
		TransactionActiveAtExecutionStartTime = TransactionActive();
		DisableAccessKeysUpdate(True, SubsystemExists);
		Try
			Common.ExecuteConfigurationMethod(Handler.Procedure);
			DisableAccessKeysUpdate(False, SubsystemExists);
		Except
			DisableAccessKeysUpdate(False, SubsystemExists);
			HandlerName = Handler.Procedure;
			WriteError(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'При вызове обработчика перехода с другой программы
				           |""%1""
				           |произошла ошибка:
				           |""%2"".'; 
				           |en = 'Error while calling the handler of migration from another application
				           |%1:
				           |%2
				           |'; 
				           |pl = 'Podczas wywołania programu przetwarzania przejścia z innego programu
				           |""%1""
				           |zaistniał błąd:
				           |""%2"".';
				           |es_ES = 'Error al llamar al controlador de migración desde otra aplicación
				           |%1:
				           |%2
				           |';
				           |es_CO = 'Error al llamar al controlador de migración desde otra aplicación
				           |%1:
				           |%2
				           |';
				           |tr = 'Başka bir programdan geçiş işleyicisini çağırdığınızda 
				           |"
" %2bir hata oluştu: 
				           |""%1"".';
				           |it = 'Si è verificato un errore quando si chiama il gestore di transizione
				           |""%1""
				           | da un altro programma:
				           |""%2""';
				           |de = 'Beim Aufruf des Migrationshandlers aus einem anderen Programm
				           |""%1""
				           |ist ein Fehler aufgetreten:
				           |""%2"".'"),
				HandlerName,
				DetailErrorDescription(ErrorInfo())));
			
			Raise;
		EndTry;
		ValidateNestedTransaction(TransactionActiveAtExecutionStartTime, Handler.Procedure);
		
	EndDo;
		
	Parameters = New Structure();
	Parameters.Insert("ExecuteUpdateFromVersion", True);
	Parameters.Insert("ConfigurationVersion", Metadata.Version);
	Parameters.Insert("ClearPreviousConfigurationInfo", True);
	OnCompleteApplicationMigration(PreviousConfigurationName, PreviousConfigurationVersion, Parameters);
	
	// Setting current configuration name and version.
	BeginTransaction();
	Try
		If Parameters.ClearPreviousConfigurationInfo Then
			RecordSet = InformationRegisters.SubsystemsVersions.CreateRecordSet();
			RecordSet.Filter.SubsystemName.Set(PreviousConfigurationName);
			RecordSet.Write();
		EndIf;
		
		RecordSet = InformationRegisters.SubsystemsVersions.CreateRecordSet();
		RecordSet.Filter.SubsystemName.Set(Metadata.Name);
		
		ConfigurationVersion = Metadata.Version; 
		If Parameters.ExecuteUpdateFromVersion Then
			ConfigurationVersion = Parameters.ConfigurationVersion;
		EndIf;
		NewRecord = RecordSet.Add();
		NewRecord.SubsystemName = Metadata.Name;
		NewRecord.Version = ConfigurationVersion;
		NewRecord.UpdatePlan = Undefined;
		NewRecord.IsMainConfiguration = True;
		
		RecordSet.Write();
		CommitTransaction();
	Except	
		RollbackTransaction();
		Raise;
	EndTry;
	
	RefreshReusableValues();
	
EndProcedure

Procedure OnCompleteApplicationMigration(PreviousConfigurationName, PreviousConfigurationVersion, Parameters)
	
	ConfigurationName = Metadata.Name;
	SubsystemsDetails  = StandardSubsystemsCached.SubsystemsDetails();
	For each SubsystemName In SubsystemsDetails.Order Do
		SubsystemDetails = SubsystemsDetails.ByNames.Get(SubsystemName);
		If NOT ValueIsFilled(SubsystemDetails.MainServerModule) Then
			Continue;
		EndIf;
		
		If SubsystemDetails.Name <> ConfigurationName Then
			Continue;
		EndIf;
		
		Module = Common.CommonModule(SubsystemDetails.MainServerModule);
		Module.OnCompleteApplicationMigration(PreviousConfigurationName, PreviousConfigurationVersion, Parameters);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Logging the update progress.

// Returns a string constant for generating event log messages.
//
// Returns:
//   Row
//
Function EventLogEvent() Export
	
	Return NStr("ru = 'Обновление информационной базы'; en = 'Infobase update'; pl = 'Aktualizacja bazy informacyjnej';es_ES = 'Actualización de la infobase';es_CO = 'Actualización de la infobase';tr = 'Infobase güncellemesi';it = 'Aggiornamento del database';de = 'Infobase-Aktualisierung'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

// Returns a string constant used to create event log messages describing update handler execution 
// progress.
//
// Returns:
//   Row
//
Function EventLogEventProtocol() Export
	
	Return EventLogEvent() + "." + NStr("ru = 'Протокол выполнения'; en = 'Execution log'; pl = 'Protokół wykonania';es_ES = 'Protocolo de ejecución';es_CO = 'Protocolo de ejecución';tr = 'Yürütme protokolü';it = 'Registro esecuzione';de = 'Ausführungsprotokoll'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Update details

// Generates a spreadsheet document containing change description for each version in the Sections 
// version list.
//
Function DocumentUpdateDetails(Val Sections) Export
	
	DocumentUpdateDetails = New SpreadsheetDocument();
	If Sections.Count() = 0 Then
		Return DocumentUpdateDetails;
	EndIf;
	
	UpdateDetailsTemplate = Metadata.CommonTemplates.Find("ApplicationReleaseNotes");
	If UpdateDetailsTemplate <> Undefined Then
		UpdateDetailsTemplate = GetCommonTemplate(UpdateDetailsTemplate);
	Else
		Return New SpreadsheetDocument();
	EndIf;
	
	For Each Version In Sections Do
		
		OutputUpdateDetails(Version, DocumentUpdateDetails, UpdateDetailsTemplate);
		
	EndDo;
	
	Return DocumentUpdateDetails;
	
EndFunction

// Returns an array containing a list of versions later than the last displayed version, provided 
// that change descriptions are available for these versions.
//
// Returns:
//  Array - contains strings with version numbers.
//
Function NotShownUpdateDetailSections() Export
	
	Sections = UpdateDetailsSections();
	
	LatestVersion = SystemChangesDisplayLastVersion();
	
	If LatestVersion = Undefined Then
		Return New Array;
	EndIf;
	
	Return GetLaterVersions(Sections, LatestVersion);
	
EndFunction

// Sets the version change details display flag both for the current version and earlier versions.
// 
//
// Parameters:
//  Username - String - the name of the user to set the flag for.
//   
//
Procedure SetShowDetailsToCurrentVersionFlag(Val Username = Undefined) Export
	
	Common.CommonSettingsStorageSave("IBUpdate",
		"SystemChangesDisplayLastVersion", Metadata.Version, , Username);
		
	If Username = Undefined AND Users.IsFullUser() Then
		
		Common.CommonSettingsStorageDelete("IBUpdate", "OutputChangeDescriptionForAdministrator", UserName());
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Deferred update mechanism.

// Generates the deferred update handler tree and writes it to the IBUpdateInfo constant.
//
Procedure GenerateDeferredUpdateHandlerList(UpdateIterations, FirstExchangeInDIB = False)
	
	CheckDeferredHandlerIDUniqueness(UpdateIterations);
	
	HandlersTree = PreviousVersionHandlersCompleted(UpdateIterations);
	UpdateInfo = InfobaseUpdateInfo();
	
	Constants.DeferredUpdateCompletedSuccessfully.Set(False);
	// Setting initial field values
	UpdateInfo.Insert("UpdateStartTime");
	UpdateInfo.Insert("UpdateEndTime");
	UpdateInfo.Insert("UpdateDuration");
	UpdateInfo.Insert("DeferredUpdateStartTime");
	UpdateInfo.Insert("DeferredUpdateEndTime");
	UpdateInfo.Insert("SessionNumber", New ValueList());
	UpdateInfo.Insert("UpdateHandlerParameters");
	UpdateInfo.Insert("DeferredUpdateCompletedSuccessfully");
	UpdateInfo.Insert("HandlersTree", New ValueTree());
	UpdateInfo.Insert("OutputUpdateDetails", False);
	UpdateInfo.Insert("PausedUpdateProcedures", New Array);
	UpdateInfo.Insert("StartedUpdateProcedures", New Array);
	UpdateInfo.Insert("DeferredUpdateManagement", New Structure);
	UpdateInfo.Insert("DataToProcess", New Map);
	UpdateInfo.Insert("CurrentUpdateIteration", 1);
	UpdateInfo.Insert("DeferredUpdatePlan");
	UpdateInfo.Insert("FillingProceduresDetails");
	
	LibraryName = "";
	VersionNumber   = "";
	ErrorsText   = "";
	
	LibraryDetailsList = StandardSubsystemsCached.SubsystemsDetails().ByNames;
	
	For each UpdateIteration In UpdateIterations Do
		
		PreviousVersion = ?(FirstExchangeInDIB, "1.0.0.0", UpdateIteration.PreviousVersion);
		LibraryName = UpdateIteration.Subsystem;
		DeferredHandlerExecutionMode = LibraryDetailsList[LibraryName].DeferredHandlerExecutionMode;
		ParallelSinceVersion = LibraryDetailsList[LibraryName].ParralelDeferredUpdateFromVersion;
		
		If FirstExchangeInDIB AND DeferredHandlerExecutionMode = "Sequentially" Then
			Continue;
		EndIf;
		
		FilterParameters = HandlerFIlteringParameters();
		FilterParameters.GetSeparated = True;
		FilterParameters.UpdateMode = "Deferred";
		FilterParameters.IncludeFirstExchangeInDIB = (DeferredHandlerExecutionMode = "Parallel");
		FilterParameters.FirstExchangeInDIB = FirstExchangeInDIB;
		
		HandlersByVersion = UpdateInIntervalHandlers(UpdateIteration.Handlers,
			PreviousVersion, UpdateIteration.Version, FilterParameters);
		If HandlersByVersion.Rows.Count() = 0 Then
			Continue;
		EndIf;
		
		// Adding a library string
		FoundRow = HandlersTree.Rows.Find(LibraryName, "LibraryName");
		If FoundRow <> Undefined Then
			TreeRowLibrary = FoundRow;
		Else
			TreeRowLibrary = HandlersTree.Rows.Add();
			TreeRowLibrary.LibraryName = LibraryName;
		EndIf;
		TreeRowLibrary.Status = "";
		
		For Each VersionRow In HandlersByVersion.Rows Do
			
			If FirstExchangeInDIB
				AND DeferredHandlerExecutionMode = "Parallel"
				AND (VersionRow.Version = "*"
					Or ValueIsFilled(ParallelSinceVersion)
						AND CommonClientServer.CompareVersions(VersionRow.Version, ParallelSinceVersion) < 0) Then
				Continue;
			EndIf;
			
			FoundRow = TreeRowLibrary.Rows.Find(VersionRow.Version, "VersionNumber");
			HasUncompletedHandlers = False;
			If FoundRow <> Undefined Then
				FoundRow.Status = "";
				
				For Each UncompletedHandler In FoundRow.Rows Do
					HasUncompletedHandlers = True;
					UncompletedHandler.AttemptCount = 0;
					UncompletedHandler.ExecutionStatistics = New Map;
				EndDo;
				VersionsTreeRow = FoundRow;
			Else
				VersionsTreeRow = TreeRowLibrary.Rows.Add();
				VersionsTreeRow.VersionNumber   = VersionRow.Version;
				VersionsTreeRow.Status = "";
			EndIf;
			
			ParallelSinceVersionMode = DeferredHandlerExecutionMode = "Parallel" AND ValueIsFilled(ParallelSinceVersion);
			
			For Each Handler In VersionRow.Rows Do
				
				If ParallelSinceVersionMode Then
					If VersionRow.Version = "*" Then
						DeferredHandlerMode = "Sequentially";
					Else
						Result = CommonClientServer.CompareVersions(VersionRow.Version, ParallelSinceVersion);
						DeferredHandlerMode = ?(Result > 0, "Parallel", "Sequentially");
					EndIf;
				Else
					DeferredHandlerMode = DeferredHandlerExecutionMode;
				EndIf;
				CheckDeferredHandlerProperties(Handler, DeferredHandlerMode, ErrorsText);
				
				If HasUncompletedHandlers Then
					FoundRow = VersionsTreeRow.Rows.Find(Handler.Procedure, "HandlerName");
					If FoundRow <> Undefined Then
						FillPropertyValues(FoundRow, Handler);
						Continue; // This handler already exists for this version.
					EndIf;
				EndIf;
				
				HandlersTreeRow = VersionsTreeRow.Rows.Add();
				
				FillPropertyValues(HandlersTreeRow, Handler);
				HandlersTreeRow.LibraryName = LibraryName;
				HandlersTreeRow.VersionNumber = Handler.Version;
				HandlersTreeRow.HandlerName = Handler.Procedure;
				HandlersTreeRow.Status = "NotCompleted";
				HandlersTreeRow.AttemptCount = 0;
			EndDo;
			
		EndDo;
		
	EndDo;
	
	If Not IsBlankString(ErrorsText) Then
		Raise ErrorsText; 
	EndIf;
	
	// Sorting the handler tree.
	LibrariesOrder = StandardSubsystemsCached.SubsystemsDetails().Order;
	Index = 0;
	For Each Library In LibrariesOrder Do
		FoundRow = HandlersTree.Rows.Find(Library, "LibraryName");
		If FoundRow <> Undefined Then
			RowIndex = HandlersTree.Rows.IndexOf(FoundRow);
			Offset = Index - RowIndex;
			If Offset <> 0 Then
				HandlersTree.Rows.Move(FoundRow, Offset);
			EndIf;
			Index = Index + 1
		EndIf;
	EndDo;
	
	HandlersQueue = New Map;
	InfobaseUpdateOverridable.OnFormingDeferredHandlersQueues(HandlersQueue);
	For Each HandlerAndQueue In HandlersQueue Do
		FoundHandler = HandlersTree.Rows.Find(HandlerAndQueue.Key, "HandlerName", True);
		If FoundHandler <> Undefined Then
			FoundHandler.DeferredProcessingQueue = HandlerAndQueue.Value;
		EndIf;
	EndDo;
	
	UpdateInfo.HandlerTreeVersion = Metadata.Version;
	
	CheckDeferredHandlerTree(HandlersTree);
	UpdateInfo.HandlersTree = HandlersTree;
	
	GenerateDeferredUpdatePlan(UpdateInfo);
	WriteInfobaseUpdateInfo(UpdateInfo);
	
EndProcedure

Procedure CheckDeferredHandlerProperties(Val Handler, Val DeferredHandlerExecutionMode, ErrorsText)
	
	If DeferredHandlerExecutionMode = "Parallel"
		AND Not ValueIsFilled(Handler.UpdateDataFillingProcedure) Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не указана процедура заполнения данных
					   |отложенного обработчика обновления
					   |""%1"".'; 
					   |en = 'No data population procedure is specified
					   |for deferred update handler
					   |%1.'; 
					   |pl = 'Nie jest wskazana procedura wypełnienia danych
					   |odroczonego programu przetwarzania aktualizacji
					   |""%1"".';
					   |es_ES = 'No se ha indicado procedimiento de rellenar los datos
					   |del procesador aplazado de la actualización
					   |%1.';
					   |es_CO = 'No se ha indicado procedimiento de rellenar los datos
					   |del procesador aplazado de la actualización
					   |%1.';
					   |tr = 'Bekleyen güncelleştirme işleyicisi "
" verilerini doldurmak için prosedür 
					   |belirtilmedi%1.';
					   |it = 'Non è specificata la procedura di riempimento
					   |del gestore aggiornamenti
					   |""%1"".';
					   |de = 'Die Vorgehensweise beim Ausfüllen der Daten
					   |des verzögerten Aktualisierungs-Handlers ist nicht spezifiziert
					   |""%1"".'"),
			Handler.Procedure);
		
		WriteError(ErrorText);
		ErrorsText = ErrorsText + ErrorText + Chars.LF;
	EndIf;

	If Handler.ExclusiveMode = True Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'У отложенного обработчика ""%1""
			|не должен быть установлен признак ""ExclusiveMode"".'; 
			|en = 'Deferred handler %1
			|cannot have the ExclusiveMode flag set.'; 
			|pl = 'Odroczony program przetwarzania %1
			|nie powinien mieć ExclusiveMode oznaki.';
			|es_ES = 'Para el procesador aplazado %1
			|no puede tener el ExclusiveMode establecido atributo.';
			|es_CO = 'Para el procesador aplazado %1
			|no puede tener el ExclusiveMode establecido atributo.';
			|tr = 'Gecikmiş işleyici %1
			|Özel Mod özelliğine sahip olmamalıdır.';
			|it = 'Il gestore differito ""%1"" non deve avere 
			|un segno ""Modalità esclusiva"" impostato.';
			|de = 'Die Funktion ""MonopolModus"" sollte nicht für den ausstehenden Handler ""%1""
			|festgelegt werden.'"), 
			Handler.Procedure);
		WriteError(ErrorText);
		ErrorsText = ErrorsText + ErrorText + Chars.LF;
	EndIf;

	If DeferredHandlerExecutionMode = "Parallel" AND Handler.ExecuteInMasterNodeOnly
		AND Handler.RunAlsoInSubordinateDIBNodeWithFilters Then
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'У отложенного обработчика ""%1""
			|некорректно заполнены значения свойств:
			| - ""ExecuteInMasterNodeOnly""
			| - ""ExecuteAlsoInSubordinateDIBNodeWithFilters"".
			|
			|Данные свойства не могут одновременно принимать значение ""True"".'; 
			|en = 'In deferred handler %1,
			|the following properties have invalid values:
			| - ExecuteInMasterNodeOnly
			| - ExecuteAlsoInSubordinateDIBNodeWithFilters
			|
			|These properties cannot both be True at the same time.'; 
			|pl = 'W odroczonym programie przetwarzania %1,
			|Dane właściwości nie mogą jednocześnie przyjmować wartość:
			| - ExecuteInMasterNodeOnly
			| - ExecuteAlsoInSubordinateDIBNodeWithFilters
			|
			|Te właściwości nie mogą być True jednocześnie.';
			|es_ES = 'Para el procesador aplazado ""%1"
"están rellenados incorrectamente los valores de las propiedades:
			| - ExecuteInMasterNodeOnly
			| - ExecuteAlsoInSubordinateDIBNodeWithFilters.
			|
			|Estas propiedades no pueden simultáneamente tener el valor True.';
			|es_CO = 'Para el procesador aplazado ""%1"
"están rellenados incorrectamente los valores de las propiedades:
			| - ExecuteInMasterNodeOnly
			| - ExecuteAlsoInSubordinateDIBNodeWithFilters.
			|
			|Estas propiedades no pueden simultáneamente tener el valor True.';
			|tr = 'Ertelenmiş işleyicinin ""%1""
			|özelliklerinin değerleri yanlış doldurulmuştur:
			| - ""SadeceAnaÜnitedeBaşlat""
			| - ""AltÜnitedeRIBSFiltresindeDeBaşlat"".
			|
			|Bu özellikler, aynı anda ""Doğru"" değerini alamaz.';
			|it = 'Il gestore posticipato ""%1""
			|ha valori di proprietà popolati in modo errato:
			| -""Eseguire solo nel nodo principale""
			| - ""Eseguire e nel nodo slave con filtri"".
			|
			|Queste proprietà non possono assumere contemporaneamente il valore ""True"".';
			|de = 'Der aufgeschobene Handler ""%1""
			|hat die Eigenschaftswerte falsch ausgefüllt:
			| - ""NurImHauptknotenAusführen""
			| - ""AusführenUndImUntergeordnetenKnotenEinerVerteiltenInformationsbasisMitFiltern"".
			|
			|Diese Eigenschaften können nicht gleichzeitig auf ""True"" gesetzt werden.'"), 
			Handler.Procedure);
		WriteError(ErrorText);
		ErrorsText = ErrorsText + ErrorText + Chars.LF;
	EndIf;

	If Handler.SharedData = True Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'У отложенного обработчика ""%1""
			|указано недопустимое значение свойства ""SharedData"".
			|
			|Данное свойство не может принимать значение ""True"" у отложенного обработчика.'; 
			|en = 'In deferred handler %1,
			|SharedData property has invalid value.
			|
			|This property cannot be True in deferred handlers.'; 
			|pl = 'W odroczonym programie przetwarzania %1,
			|SharedData jest wskazana niedopuszczalna wartość właściwości.
			|
			|Ta właściwość nie może przyjmować wartość True dla odroczonego programu przetwarzania.';
			|es_ES = 'Para el procesador aplazado ""%1""
			|está indicado el valor de la propiedad ""SharedData"".
			|
			|Esta propiedad no puede tener el valor True del procesador aplazado.';
			|es_CO = 'Para el procesador aplazado ""%1""
			|está indicado el valor de la propiedad ""SharedData"".
			|
			|Esta propiedad no puede tener el valor True del procesador aplazado.';
			|tr = 'Ertelenmiş işleyicinin ""%1"
"OrtakVeriler"" özelliğinin belirtilen değeri kabul edilemez.
			|
			|Bu özellik, ertelenmiş işleyicide ""Doğru"" değerini alamaz.';
			|it = 'Il gestore posticipato ""%1""
			|ha un valore non valido per la ""Proprietà Generale"".
			|
			|Questa proprietà non può essere impostata su ""True"" nel gestore differito.';
			|de = 'Ein verzögerter Handler ""%1""
			|hat einen ungültigen Wert der Eigenschaft ""AllgemeineDaten"".
			|
			|Diese Eigenschaft kann für einen ausstehenden Handler nicht auf ""True"" gesetzt werden.'"), 
			Handler.Procedure);
		WriteError(ErrorText);
		ErrorsText = ErrorsText + ErrorText + Chars.LF;
	EndIf;
	
EndProcedure

Procedure CheckDeferredHandlerIDUniqueness(UpdateIterations)
	
	UniquenessCheckTable = New ValueTable;
	UniquenessCheckTable.Columns.Add("ID");
	UniquenessCheckTable.Columns.Add("IndexOf");
	
	For Each UpdateIteration In UpdateIterations Do
		
		FilterParameters = New Structure;
		FilterParameters.Insert("ExecutionMode", "Deferred");
		HandlersTable = UpdateIteration.Handlers;
		
		Handlers = HandlersTable.FindRows(FilterParameters);
		For Each Handler In Handlers Do
			If Not ValueIsFilled(Handler.ID) Then
				Continue;
			EndIf;
			TableRow = UniquenessCheckTable.Add();
			TableRow.ID = String(Handler.ID);
			TableRow.IndexOf        = 1;
		EndDo;
		
	EndDo;
	
	InitialRowCount = UniquenessCheckTable.Count();
	UniquenessCheckTable.GroupBy("ID", "IndexOf");
	FinalRowCount = UniquenessCheckTable.Count();
	
	// Running a quick check.
	If InitialRowCount = FinalRowCount Then
		Return; // All IDs are unique.
	EndIf;
	
	UniquenessCheckTable.Sort("IndexOf Desc");
	MessageText = NStr("ru = 'Обнаружены отложенные обработчики обновления,
		|у которых совпадают уникальные идентификаторы. Следующие идентификаторы не уникальны:'; 
		|en = 'Deferred update handlers with duplicate IDs are found.
		|The following IDs are duplicate:'; 
		|pl = 'Wykryto odroczone programy przetwarzania aktualizacji,
		|które mają zgodne unikalne identyfikatory. Następujące identyfikatory nie są unikalne:';
		|es_ES = 'Se han encontrado los procesador aplazados de la actualización
		|cuyos identificadores únicos no coinciden. Los siguientes identificadores no son únicos:';
		|es_CO = 'Se han encontrado los procesador aplazados de la actualización
		|cuyos identificadores únicos no coinciden. Los siguientes identificadores no son únicos:';
		|tr = 'Benzersiz tanımlayıcıları aynı olan
		| bekleyen güncelleme işleyicileri tespit edildi. Aşağıdaki tanımlayıcılar benzersiz değildir:';
		|it = 'Sono stati rilevati gestori di aggiornamento differito con ID identici.
		|I seguenti ID sono identici:';
		|de = 'Verzögerte Aktualisierungs-Handler
		|mit eindeutigen Kennungen wurden erkannt. Die folgenden Bezeichner sind nicht eindeutig:'");
	For Each IDRow In UniquenessCheckTable Do
		If IDRow.IndexOf = 1 Then
			Break;
		Else
			MessageText = MessageText + Chars.LF + IDRow.ID;
		EndIf;
	EndDo;
	
	Raise MessageText;
	
EndProcedure

// Schedules the deferred update in client/server infobase.
//
Procedure ScheduleDeferredUpdate()
	
	// Scheduling a job.
	// Adding the scheduled job to queue when in SaaS.
	If Not Common.FileInfobase() Then
		OnEnableDeferredUpdate(True);
	EndIf;
	
EndProcedure

// Controls execution of the deferred update handlers.
// 
Procedure ExecuteDeferredUpdate() Export
	
	Common.OnStartExecuteScheduledJob();
	
	If InfobaseUpdateInternalCached.InfobaseUpdateRequired() Then
		Return;
	EndIf;
	
	UpdateInfo = InfobaseUpdateInfo();
	
	If UpdateInfo.DeferredUpdateEndTime <> Undefined Then
		CancelDeferredUpdate();
		Return;
	EndIf;
	
	If UpdateInfo.DeferredUpdateStartTime = Undefined Then
		UpdateInfo.DeferredUpdateStartTime = CurrentSessionDate();
	EndIf;
	If TypeOf(UpdateInfo.SessionNumber) <> Type("ValueList") Then
		UpdateInfo.SessionNumber = New ValueList;
	EndIf;
	UpdateInfo.SessionNumber.Add(InfoBaseSessionNumber());
	WriteInfobaseUpdateInfo(UpdateInfo);
	
	// Disabling the period-end closing date check in the scheduled job session.
	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.SkipPeriodClosingCheck(True);
	EndIf;
	
	HandlersExecutedEarlier = True;
	
	Try
		If ForceUpdate(UpdateInfo) Then
			If UpdateInfo.ThreadDetails <> Undefined Then
				CancelAllThreadsExecution(UpdateInfo.ThreadDetails, UpdateInfo);
			EndIf;
			
			ThreadDetails = NewDetailsOfDeferredUpdateHandlerThreads();
			UpdateInfo.ThreadDetails = ThreadDetails;
			
			While HandlersExecutedEarlier Do
				Thread = AddDeferredUpdateHandlerThread(ThreadDetails, UpdateInfo);
				
				If TypeOf(Thread) = Type("ValueTableRow") Then
					ExecuteThread(ThreadDetails, Thread);
					WaitForAvailableThread(ThreadDetails, UpdateInfo);
				ElsIf Thread = True Then
					WaitForAnyThreadCompletion(ThreadDetails, UpdateInfo);
				ElsIf Thread = False Then
					HandlersExecutedEarlier = False;
					WaitForAllThreadsCompletion(ThreadDetails, UpdateInfo);
					SaveThreadsStateToUpdateInfo(ThreadDetails, UpdateInfo);
					Break;
				EndIf;
				
				SaveThreadsStateToUpdateInfo(ThreadDetails, UpdateInfo);
				Job = ScheduledJobsServer.Job(Metadata.ScheduledJobs.DeferredIBUpdate);
				ExecutionRequired = Job.Schedule.ExecutionRequired(CurrentSessionDate());
				
				If Not ExecutionRequired Or Not ForceUpdate(UpdateInfo) Then
					WaitForAllThreadsCompletion(ThreadDetails, UpdateInfo);
					SaveThreadsStateToUpdateInfo(Undefined, UpdateInfo);
					Break;
				EndIf;
			EndDo;
		Else
			HandlersExecutedEarlier = ExecuteDeferredUpdateHandler(UpdateInfo);
			WriteInfobaseUpdateInfo(UpdateInfo);
		EndIf;
	Except
		WriteError(DetailErrorDescription(ErrorInfo()));
		CancelAllThreadsExecution(UpdateInfo.ThreadDetails, UpdateInfo);
		SaveThreadsStateToUpdateInfo(Undefined, UpdateInfo);
	EndTry;
	
	If Not HandlersExecutedEarlier Or AllDeferredHandlersCompleted(UpdateInfo) Then
		SaveThreadsStateToUpdateInfo(Undefined, UpdateInfo);
		CancelDeferredUpdate();
	EndIf;
	
EndProcedure

// Called when enabling or disabling the deferred update.
//
// Parameters:
// Use - Boolean - True if the job must be enabled, otherwise, False.
//
Procedure OnEnableDeferredUpdate(Usage) Export
	
	If Not Common.DataSeparationEnabled() Then
		JobsFilter = New Structure;
		JobsFilter.Insert("Metadata", Metadata.ScheduledJobs.DeferredIBUpdate);
		Jobs = ScheduledJobsServer.FindJobs(JobsFilter);
		
		For Each Job In Jobs Do
			JobParameters = New Structure("Use", Usage);
			ScheduledJobsServer.ChangeJob(Job, JobParameters);
		EndDo;
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.OnEnableDeferredUpdate(Usage);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Multithread update mechanism.

// Creates a new description of deferred update data registration threads.
//
// Returns:
//  Structure - see NewThreadsDetails(). 
//
Function NewDetailsOfDeferredUpdateDataRegistrationThreads()
	
	Details = NewThreadDetails();
	Details.Procedure =
		"InfobaseUpdateInternal.FillDeferredHandlerData";
	Details.CompletionProcedure =
		"InfobaseUpdateInternal.CompleteDeferredUpdateDataRegistration";
	
	Return Details;
	
EndFunction

// Adds a deferred update data registration thread.
//
// Parameters:
//  ThreadsDetails - Structure - see NewThreadsDetails(). 
//  ProcedureDetails - Structure - details of the filling procedure.
//
// Returns:
//  ValueTableRow - a new thread (see NewThreadsDetails()).
//
Function AddDeferredUpdateDataRegistrationThread(ThreadDetails, ProcedureDetails)
	
	DescriptionTemplate = NStr("ru = 'Регистрация данных обработчика обновления ""%1""'; en = 'Register data of %1 update handler'; pl = 'Rejestracja danych programu przetwarzania aktualizacji ""%1""';es_ES = 'El registro de los datos del procesador de la actualización ""%1""';es_CO = 'El registro de los datos del procesador de la actualización ""%1""';tr = '""%1"" güncelleme işleyicisinin verilerinin kaydı';it = 'Registrazione dei dati del gestore aggiornamenti ""%1""';de = 'Registrierung der Handlerdaten aktualisieren ""%1"".'");
	ProcedureDetails.Status = "Running";
	
	Thread = ThreadDetails.Threads.Add();
	Thread.ProcedureParameters = ProcedureDetails;
	Thread.CompletionProcedureParameters = ProcedureDetails;
	Thread.Description = StringFunctionsClientServer.SubstituteParametersToString(DescriptionTemplate,
		ProcedureDetails.HandlerName);
	
	Return Thread;
	
EndFunction

// Complete registration of the deferred update data.
// Called automatically in the main thread after FillDeferredHandlerData() has completed.
//
// Parameters:
//  ProcedureDetails - Structure - details of the filling procedure.
//  ResultAddress - String - address of the temporary storage used to store the result returned by FillDeferredHandlerData().
//  UpdateInfo - update information (see NewUpdateInfo()).
//
Procedure CompleteDeferredUpdateDataRegistration(ProcedureDetails,
                                                          ResultAddress,
                                                          UpdateInfo) Export
	
	Result = GetFromTempStorage(ResultAddress);
	
	If TypeOf(UpdateInfo.DataToProcess) <> Type("Map") Then
		UpdateInfo.DataToProcess = New Map;
	EndIf;
	
	UpdateInfo.FillingProceduresDetails[ProcedureDetails.HandlerName].Status = "Completed";
	UpdateInfo.DataToProcess.Insert(ProcedureDetails.HandlerName, Result.HandlerData);
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		If Result.UpdateData <> Undefined Then
			ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
			ModuleDataExchangeServer.SaveUpdateData(Result.UpdateData, Result.NameOfChangedFile);
		EndIf;
	EndIf;
	
EndProcedure

// Creates a new description of deferred update handler threads.
//
// Returns:
//  Structure - see NewThreadsDetails(). 
//
Function NewDetailsOfDeferredUpdateHandlerThreads()
	
	Details = NewThreadDetails();
	Details.Procedure =
		"InfobaseUpdateInternal.ExecuteDeferredHandler";
	Details.CompletionProcedure =
		"InfobaseUpdateInternal.CompleteDeferredHandlerExecution";
	Details.OnAbnormalTermination =
		"InfobaseUpdateInternal.OnDeferredHandlerThreadAbnormalTermination";
	Details.OnCancelThread =
		"InfobaseUpdateInternal.OnCancelDeferredHandlerThread";
	
	Return Details;
	
EndFunction

// Adds a deferred update handler thread.
//
// Parameters:
//  ThreadsDetails - Structure - see NewDetailsOfDeferredUpdateDataRegistrationThreads(). 
//  UpdateInfo - update information (see NewUpdateInfo()).
//
// Returns:
//  * ValueTableRow - a new thread (see NewThreadsDetails()).
//  * Boolean - True if the handler does not need to be completed, or False if the handler needs to be completed.
//
Function AddDeferredUpdateHandlerThread(ThreadDetails, UpdateInfo)
	
	HandlerContext = NewHandlerContext();
	UpdateHandler = FindUpdateHandler(HandlerContext, UpdateInfo);
	
	If TypeOf(UpdateHandler) = Type("ValueTreeRow") Then
		If HandlerContext.ExecuteHandler Then
			DescriptionTemplate = NStr("ru = 'Выполнение обработчика обновления ""%1""'; en = 'Execute %1 update handler'; pl = 'Wykonanie programu przetwarzania aktualizacji ""%1""';es_ES = 'Se ejecuta el procesador de la actualización ""%1""';es_CO = 'Se ejecuta el procesador de la actualización ""%1""';tr = '""%1"" güncelleme işleyicisi yürütülüyor';it = 'Esecuzione del gestore aggiornamenti %1';de = 'Ausführung des Update-Handlers ""%1""'");
			Thread = ThreadDetails.Threads.Add();
			Thread.ProcedureParameters = HandlerContext;
			Thread.CompletionProcedureParameters = HandlerContext;
			Thread.Description = StringFunctionsClientServer.SubstituteParametersToString(DescriptionTemplate,
				UpdateHandler.HandlerName);
		Else
			Thread = True;
		EndIf;
	Else
		Thread = UpdateHandler;
	EndIf;
	
	Return Thread;
	
EndFunction

// Runs the deferred handler in a background job.
// Executed only when HandlerContext.ExecuteHandler = True (i.e. not in a subordinate DIB node).
//
// Parameters:
//  HandlerContext - Structure - see NewHandlerContext(). 
//  ResultAddress - String - an address of the temporary storage for storing the procedure result.
//
Procedure ExecuteDeferredHandler(HandlerContext, ResultAddress) Export
	
	SessionParameters.UpdateHandlerParameters = HandlerContext.UpdateHandlerParameters;
	
	SubsystemExists = Common.SubsystemExists("StandardSubsystems.AccessManagement");
	DisableAccessKeysUpdate(True, SubsystemExists);
	Try
		CallParameters = New Array;
		CallParameters.Add(HandlerContext.Parameters);
		Common.ExecuteConfigurationMethod(HandlerContext.HandlerName, CallParameters);
		
		Result = NewDeferredHandlerResult();
		Result.Parameters = HandlerContext.Parameters;
		Result.UpdateHandlerParameters = SessionParameters.UpdateHandlerParameters;
		Try
			ValidateNestedTransaction(HandlerContext.TransactionActiveAtExecutionStartTime,
				HandlerContext.HandlerName);
		Except
			Result.ErrorInfo = DetailErrorDescription(ErrorInfo());
			Result.HasOpenTransactions = True;
			
			While TransactionActive() Do
				RollbackTransaction();
			EndDo;
		EndTry;
		
		PutToTempStorage(Result, ResultAddress);
		DisableAccessKeysUpdate(False, SubsystemExists);
		SessionParameters.UpdateHandlerParameters = New FixedStructure(NewUpdateHandlerParameters());
	Except
		DisableAccessKeysUpdate(False, SubsystemExists);
		SessionParameters.UpdateHandlerParameters = New FixedStructure(NewUpdateHandlerParameters());
		Raise;
	EndTry;
	
EndProcedure

// Completes execution of a deferred handler.
// Called automatically in the main thread after ExecuteDeferredHandler() has completed.
//
// Parameters:
//  HandlerContext - Structure - see NewHandlerContext(). 
//  ResultAddress - String - address of the temporary storage used to store the result returned by ExecuteDeferredHandler().
//  UpdateInfo - Structure - see NewUpdateInfo(). 
//
Procedure CompleteDeferredHandlerExecution(HandlerContext, ResultAddress, UpdateInfo) Export
	
	UpdateHandler = FindHandlerInTree(UpdateInfo.HandlersTree.Rows,
		HandlerContext.HandlerID,
		HandlerContext.HandlerName);
	UpdateHandler.BatchProcessingCompleted = True;
	
	ImportHandlerExecutionResult(HandlerContext, ResultAddress);
	HandlersTree = UpdateInfo.HandlersTree;
	SessionParameters.UpdateHandlerParameters = HandlerContext.UpdateHandlerParameters;
	
	If HandlerContext.StartedWithoutErrors Then
		AfterStartDataProcessingProcedure(HandlerContext, UpdateHandler, HandlersTree);
	EndIf;
	
	EndDataProcessingProcedure(HandlerContext, UpdateHandler);
	SessionParameters.UpdateHandlerParameters = New FixedStructure(NewUpdateHandlerParameters());
	EndDeferredUpdateHandlerExecution(HandlerContext, UpdateInfo);
	
EndProcedure

// Deferred update thread termination handler.
//
// Parameters:
//  Thread - ValueTableRow - description of the thread (see NewThreadsDetails()).
//  ErrorInformation - ErrorInformation - description of the error.
//  UpdateInfo - Structure - see NewUpdateInfo(). 
//
Procedure OnDeferredHandlerThreadAbnormalTermination(Thread, ErrorInformation, UpdateInfo) Export
	
	UpdateHandler = FindHandlerInTree(UpdateInfo.HandlersTree.Rows,
		Thread.ProcedureParameters.HandlerID,
		Thread.ProcedureParameters.HandlerName);
	
	ProcessHandlerException(Thread.ProcedureParameters, UpdateHandler, ErrorInformation);
	
EndProcedure

// Thread cancellation handler.
//
// Parameters:
//  Thread - ValueTableRow - description of the thread (see NewThreadsDetails()).
//  UpdateInfo - Structure - see NewUpdateInfo(). 
//
Procedure OnCancelDeferredHandlerThread(Thread, UpdateInfo) Export
	
	UpdateHandler = FindHandlerInTree(UpdateInfo.HandlersTree.Rows,
		Thread.ProcedureParameters.HandlerID,
		Thread.ProcedureParameters.HandlerName);
	
	If UpdateHandler.Status <> "Error" Then
		UpdateHandler.Status = Undefined;
	EndIf;
	
EndProcedure

// Imports handler execution result data from temporary storage to the update handler context.
//
// Parameters:
//  HandlerContext - Structure - see NewHandlerContext(). 
//  ResultAddress - String - address of the result in the temporary storage.
//
Procedure ImportHandlerExecutionResult(HandlerContext, ResultAddress)
	
	Result = GetFromTempStorage(ResultAddress);
	
	If Result <> Undefined Then
		If HandlerContext.WriteToLog Then
			HandlerContext.HandlerFullDetails.Parameters = Result.Parameters;
		EndIf;
		
		HandlerContext.HasOpenTransactions = Result.HasOpenTransactions;
		HandlerContext.ErrorInfo = Result.ErrorInfo;
		HandlerContext.Parameters = Result.Parameters;
		HandlerContext.UpdateHandlerParameters = Result.UpdateHandlerParameters;
	EndIf;
	
EndProcedure

// Saves the update thread execution status to the update information.
//
// Parameters:
//  ThreadDetails - Structure - collection of the threads (see NewThreadsDetails()).
//  UpdateInfo - Structure - see NewUpdateInfo(). 
//
Procedure SaveThreadsStateToUpdateInfo(ThreadDetails, UpdateInfo)
	
	UpdateInfo.ThreadDetails = ThreadDetails;
	WriteInfobaseUpdateInfo(UpdateInfo);
	
EndProcedure

// Update handler execution context.
//
// Returns:
//  Structure - description of the context (serialized before passing to a background job):
//   * ExecuteHandler - Boolean - if True, the handler is ready for execution.
//   * HandlerFullDetails - Structure - see PrepareUpdateProgressDetails(). 
//   * WriteToLog - Boolean - see Constants.WriteIBUpdateDetailsToEventLog. 
//   * StartedWithoutErrors - Boolean - if True, no exceptions were raised during handler start.
//   * HandlerID - UUID - the ID of the update handler.
//   * HandlerName - String - the name of the update handler.
//   * UpdateCycleDetailsIndex - Number - index of the update plan item.
//   * CurrentUpdateCycleIndex - Number - index of the current update plan item.
//   * DataProcessingStart - Date - start time of the update handler.
//   * ParallelMode - Boolean - indicates whether the update handler runs in parallel mode.
//   * Parameters - Structure - parameters of the update handler.
//   * UpdateParameters - Structure - description of the update parameters.
//   * UpdateHandlerParameters - FixedStructure - see SessionParameters.UpdateHandlerParameters. 
//   * SkipProcessedDataCheck - Boolean - skip check in a subordinate DIB node.
//   * CurrentUpdateIteration - Number - number of the current update iteration.
//   * TransactionActiveAtExecutionStartTime - Boolean - transaction activity status before running the handler.
//
Function NewHandlerContext()
	
	HandlerContext = New Structure;
	
	HandlerContext.Insert("ExecuteHandler", False);
	HandlerContext.Insert("HandlerFullDetails");
	HandlerContext.Insert("HasOpenTransactions", False);
	HandlerContext.Insert("WriteToLog");
	HandlerContext.Insert("StartedWithoutErrors", False);
	HandlerContext.Insert("HandlerID");
	HandlerContext.Insert("HandlerName");
	HandlerContext.Insert("UpdateCycleDetailsIndex");
	HandlerContext.Insert("CurrentUpdateCycleIndex");
	HandlerContext.Insert("ErrorInfo");
	HandlerContext.Insert("DataProcessingStart");
	HandlerContext.Insert("ParallelMode");
	HandlerContext.Insert("Parameters");
	HandlerContext.Insert("UpdateParameters");
	HandlerContext.Insert("UpdateHandlerParameters");
	HandlerContext.Insert("SkipProcessedDataCheck", False);
	HandlerContext.Insert("CurrentUpdateIteration");
	HandlerContext.Insert("TransactionActiveAtExecutionStartTime");
	
	Return HandlerContext;
	
EndFunction

// Result of deteffed update handler, to be passed to the handler completion procedure in the 
// control thread.
//
// Returns:
//  Structure - result description.
//   * Parameters - Structure - parameters that were passed to the update handler.
//   * UpdateHandlerParameters - FixedStructure - the value of session parameter
//                                      UpdateHandlerParameters
//
Function NewDeferredHandlerResult()
	
	Result = New Structure;
	Result.Insert("ErrorInfo");
	Result.Insert("Parameters");
	Result.Insert("UpdateHandlerParameters");
	Result.Insert("HasOpenTransactions", False);
	
	Return Result;
	
EndFunction

// The default number of update threads.
//
// Returns:
//  Number - the number of threads; it is equal to 1 (for backward compatibility) unless redefined in
//          InfobaseUpdateOverridable.OnDefineSettings().
//
Function DefaultInfobaseUpdateThreadCount()
	
	Parameters = SubsystemSettings();
	Return Parameters.DefaultInfobaseUpdateThreadCount;
	
EndFunction

// Determines the update priority.
//
// Parameters:
//  UpdateInfo - Structure - see NewUpdateInfo(). 
//
// Returns:
//  Boolean - True if data processing has priority, False if user operations have priority.
//
Function ForceUpdate(UpdateInfo)
	
	If Not Common.DataSeparationEnabled() Then
		Return UpdateInfo.DeferredUpdateManagement.Property("ForceUpdate");
	Else
		Priority = Undefined;
		SaaSIntegration.OnGetUpdatePriority(Priority);
		
		If Priority = "UserWork" Then
			Return False;
		ElsIf Priority = "DataProcessing" Then
			Return True;
		Else
			Return UpdateInfo.DeferredUpdateManagement.Property("ForceUpdate");
		EndIf;
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Thread operation mechanism.

// Executes the specified thread.
//
// Parameters:
//  ThreadDetails - Structure - collection of the threads (see NewThreadsDetails()).
//  Thread - ValueTableRow - description of the thread (see Threads in NewThreadsDetails()).
//  FormID - UUID - the form ID, if any.
//
// Returns:
//  Boolean - True if the thread is running or has completed, False if the thread is not started or was terminated.
//
Procedure ExecuteThread(ThreadDetails, Thread, FormID = Undefined)
	
	If Not IsBlankString(ThreadDetails.Procedure) AND Thread.ProcedureParameters <> Undefined Then
		ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(FormID);
		ExecutionParameters.BackgroundJobDescription = Thread.Description;
		ExecutionParameters.WaitForCompletion = 0;
		
		If FormID = Undefined Then
			ExecutionParameters.ResultAddress = PutToTempStorage(Undefined, New UUID);
		EndIf;
		
		RunResult = TimeConsumingOperations.ExecuteInBackground(ThreadDetails.Procedure,
			Thread.ProcedureParameters,
			ExecutionParameters);
		
		Thread.ResultAddress = RunResult.ResultAddress;
		Status = RunResult.Status;
		
		If Status = "Running" Then
			Thread.JobID = RunResult.JobID;
		ElsIf Status <> "Running" AND Status <> "Completed" Then
			Raise RunResult.BriefErrorPresentation;
		EndIf;
	EndIf;
	
EndProcedure

// Stops the threads that have completed their background jobs.
//
// Parameters:
//  ThreadDetails - Structure - collection of the threads (see NewThreadsDetails()).
//  Parameters - Arbitrary - parameters of the calling thread to be passed to the completion procedure.
//
// Returns:
//  Boolean - True if one or several threads were stopped, False otherwise.
//
Function StopThreadsWithCompletedBackgroundJobs(ThreadDetails, Parameters = Undefined)
	
	HasCompletedThreads = False;
	Threads = ThreadDetails.Threads;
	Index = Threads.Count() - 1;
	
	While Index >= 0 Do
		Thread = Threads[Index];
		JobID = Thread.JobID;
		
		If JobID <> Undefined Then
			Try
				JobCompleted = TimeConsumingOperations.JobCompleted(JobID);
			Except
				ErrorInformation = ErrorInfo();
				JobCompleted = Undefined;
				
				If Not IsBlankString(ThreadDetails.OnAbnormalTermination) Then
					CallParameters = New Array;
					CallParameters.Add(Thread);
					CallParameters.Add(ErrorInformation);
					CallParameters.Add(Parameters);
					
					Common.ExecuteConfigurationMethod(ThreadDetails.OnAbnormalTermination, CallParameters);
				Else
					Raise;
				EndIf;
			EndTry;
		EndIf;
		
		If JobID = Undefined Or JobCompleted <> False Then
			ExecuteJob = Not IsBlankString(ThreadDetails.CompletionProcedure)
			          AND Thread.CompletionProcedureParameters <> Undefined
			          AND (JobID = Undefined Or JobCompleted = True);
			
			If ExecuteJob Then
				CallParameters = New Array;
				CallParameters.Add(Thread.CompletionProcedureParameters);
				CallParameters.Add(Thread.ResultAddress);
				CallParameters.Add(Parameters);
				
				Common.ExecuteConfigurationMethod(ThreadDetails.CompletionProcedure, CallParameters);
			EndIf;
			
			DeleteFromTempStorage(Thread.ResultAddress);
			Threads.Delete(Thread);
			HasCompletedThreads = True;
		EndIf;
		
		Index = Index - 1;
	EndDo;
	
	Return HasCompletedThreads;
	
EndFunction

// Waits for completion of all threads.
//
// Parameters:
//  ThreadDetails - Structure - collection of the threads (see NewThreadsDetails()).
//  Parameters - Arbitrary - parameters of the calling thread to be passed to the completion procedure.
//
Procedure WaitForAllThreadsCompletion(ThreadDetails, Parameters = Undefined)
	
	Threads = ThreadDetails.Threads;
	
	While Threads.Count() > 0 Do
		If Not StopThreadsWithCompletedBackgroundJobs(ThreadDetails, Parameters) Then
			WaitForThreadCompletion(Threads[0]);
		EndIf;
	EndDo;
	
EndProcedure

// Waits for completion of any thread.
//
// Parameters:
//  ThreadDetails - Structure - collection of the threads (see NewThreadsDetails()).
//  Parameters - Arbitrary - parameters of the calling thread to be passed to the completion procedure.
//
Procedure WaitForAnyThreadCompletion(ThreadDetails, Parameters = Undefined)
	
	Threads = ThreadDetails.Threads;
	ThreadsCount = Threads.Count();
	
	While ThreadsCount > 0 AND Threads.Count() >= ThreadsCount Do
		If Not StopThreadsWithCompletedBackgroundJobs(ThreadDetails, Parameters) Then
			WaitForThreadCompletion(Threads[0]);
		EndIf;
	EndDo;
	
EndProcedure

// Waits until the number of active threads drops below the maximum limit.
//
// Parameters:
//  ThreadDetails - Structure - collection of the threads (see NewThreadsDetails()).
//  Parameters - Arbitrary - parameters of the calling thread to be passed to the completion procedure.
//
Procedure WaitForAvailableThread(ThreadDetails, Parameters = Undefined)
	
	MaxThreads = InfobaseUpdateThreadCount();
	Threads = ThreadDetails.Threads;
	
	While Threads.Count() >= MaxThreads Do
		If StopThreadsWithCompletedBackgroundJobs(ThreadDetails, Parameters) Then
			Return;
		EndIf;
		
		WaitForThreadCompletion(Threads[0]);
		MaxThreads = InfobaseUpdateThreadCount();
	EndDo;
	
EndProcedure

// Terminates active threads.
//
// Parameters:
//  ThreadDetails - Structure - collection of the threads (see NewThreadsDetails()).
//  CancellationParameters - Arbitrary - parameters of the OnCancelThread procedure.
//
Procedure CancelAllThreadsExecution(ThreadDetails, CancellationParameters = Undefined) Export
	
	If ThreadDetails <> Undefined Then
		Threads = ThreadDetails.Threads;
		
		If Threads <> Undefined Then
			Index = Threads.Count() - 1;
			
			While Index >= 0 Do
				Thread = Threads[Index];
				
				If Thread.JobID <> Undefined Then
					TimeConsumingOperations.CancelJobExecution(Thread.JobID);
				EndIf;
				
				If ThreadDetails.OnCancelThread <> Undefined Then
					CallParameters = New Array;
					CallParameters.Add(Thread);
					CallParameters.Add(CancellationParameters);
					Common.ExecuteConfigurationMethod(ThreadDetails.OnCancelThread, CallParameters);
				EndIf;
				
				Threads.Delete(Thread);
				Index = Index - 1;
			EndDo;
		EndIf;
	EndIf;
	
EndProcedure

// Description of a group of threads.
//
// Returns:
//  Structure - general description of the threads and a separate description of each thread, containing the following fields:
//   * Procedure - String - the name of the procedure executed in the background job. Declaration:
//                 ProcedureName(ProcedureDetails, ResultAddress), where:
//                  ** ProcedureDetails - Structure - details of the filling procedure.
//                  ** ResultAddress - String - an address of the temporary storage for storing the result.
//   * CompletionProcedure - String -  the name of the procedure to execute after the background job has completed. Declaration:
//                           CompletionProcedure(ProcedureDetails, ResultAddress, AdditionalParameters), where:
//                            ** ProcedureDetails - Structure - details of the filling procedure.
//                            ** ResultAddress - String - address of the temporary storage used to store the result.
//                            ** AdditionalParameters - Arbitrary - the additional parameter.
//   * OnAbnormalTermination - String - the thread abonrmal termination handler. Declaration:
//                              OnAbnormalTermination(Thread, ErrorInformation, AdditionalParameters), where:
//                               ** Thread - ValueTableRow - description of the thread (see NewThreadsDetails()).
//                               ** ErrorInformation - ErrorInformation - description of the error.
//                               ** AdditionalParameters - Arbitrary - the additional parameter.
//   * OnCancelThread - String - the thread cancelation handler. Declaration:
//                       OnCancelThread(Thread, AdditionalParameters), where:
//                        ** Thread - ValueTableRow - description of the thread (see NewThreadsDetails()).
//                        ** AdditionalParameters - Arbitrary - the additional parameter.
//   * Threads - ValueTable - description of the threads containing the following columns:
//    ** Description - String - arbitrary name of the thread (used in the description of the background job).
//    ** JobID - UUID - unique ID of the background job.
//    ** ProcedureParameters - Arbitrary - parameters for Procedure.
//    ** CompletionProcedureParameters - Arbitrary - parameters for CompletionProcedure.
//    ** ResultAddress - String - an address of the temporary storage for storing the background job result.
//
Function NewThreadDetails()
	
	Threads = New ValueTable;
	Columns = Threads.Columns;
	Columns.Add("Description");
	Columns.Add("JobID");
	Columns.Add("ProcedureParameters");
	Columns.Add("CompletionProcedureParameters");
	Columns.Add("ResultAddress");
	
	Details = New Structure;
	Details.Insert("Procedure");
	Details.Insert("CompletionProcedure");
	Details.Insert("OnAbnormalTermination");
	Details.Insert("OnCancelThread");
	Details.Insert("Threads", Threads);
	
	Return Details;
	
EndFunction

// Waits the specified duration for a thread to stop.
//
// Parameters:
//   Thread - ValueTableRow - the thread.
//   Duration - Number - timeout duration, in seconds.
//
// Returns:
//  Boolean - True if the thread has stopped, False if the thread is still running.
//
Function WaitForThreadCompletion(Thread, Duration = 1)
	
	If Thread.JobID <> Undefined Then
		Job = BackgroundJobs.FindByUUID(Thread.JobID);
		
		If Job <> Undefined Then
			Try
				Job.WaitForCompletion(Duration);
				Return True;
			Except
				// No special processing is required. Perhaps the exception was raised because a time-out occurred.
				Return False;
			EndTry;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INFOBASE UPDATE HANDLERS

// Transfers data from the DELETE information register to the SubsystemVersions information register.
//
Procedure MoveSubsystemVersionsToSharedData() Export
	
	BeginTransaction();
	
	Try
		
		If Common.DataSeparationEnabled() Then
			SharedDataArea = -1;
		Else
			SharedDataArea = 0;
		EndIf;
		
		QueryText =
		"SELECT
		|	DeleteSubsystemVersions.SubsystemName,
		|	DeleteSubsystemVersions.Version,
		|	DeleteSubsystemVersions.UpdatePlan
		|FROM
		|	InformationRegister.DeleteSubsystemVersions AS DeleteSubsystemVersions
		|WHERE
		|	DeleteSubsystemVersions.DataArea = &DataArea";
		
		Query = New Query(QueryText);
		Query.SetParameter("DataArea", SharedDataArea);
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			Manager = InformationRegisters.SubsystemsVersions.CreateRecordManager();
			Manager.SubsystemName = Selection.SubsystemName;
			Manager.Version = Selection.Version;
			Manager.UpdatePlan = Selection.UpdatePlan;
			Manager.Write();
			
		EndDo;
		
		Set = InformationRegisters.DeleteSubsystemVersions.CreateRecordSet();
		Set.Filter.DataArea.Set(SharedDataArea);
		Set.Write();
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Fills the IsMainConfiguration attribute value for SubsystemVersions information register records.
//
Procedure FillAttributeIsMainConfiguration() Export
	
	SetIBVersion(Metadata.Name, IBVersion(Metadata.Name), True);
	
EndProcedure

// Overwrites the current version of release notes (according to the SubsystemVersions register) 
// with the latest displayed version for all data area users.
//
Procedure SetReleaseNotesVersion() Export
	
	CurrentVersion = IBVersion(Metadata.Name);
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Users.IBUserID AS ID
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.Internal = FALSE
	|	AND Users.IBUserID <> &BlankID";
	Query.SetParameter("BlankID", New UUID("00000000-0000-0000-0000-000000000000"));
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		InfobaseUser = InfoBaseUsers.FindByUUID(Selection.ID);
		If InfobaseUser = Undefined Then
			Continue;
		EndIf;
		
		LatestVersion = SystemChangesDisplayLastVersion(InfobaseUser.Name);
		If LatestVersion <> Undefined Then
			Return;
		EndIf;
		
		LatestVersion = CurrentVersion;
		
		CompletedHandlers = Common.CommonSettingsStorageLoad("IBUpdate", 
			"CompletedHandlers", , , InfobaseUser.Name);
			
		If CompletedHandlers <> Undefined Then
			
			If CompletedHandlers.Rows.Count() > 0 Then
				Version = CompletedHandlers.Rows[CompletedHandlers.Rows.Count() - 1].Version;
				If Version <> "*" Then
					LatestVersion = Version;
				EndIf;
			EndIf;
			
		EndIf;
		
		Common.CommonSettingsStorageSave("IBUpdate",
			"SystemChangesDisplayLastVersion", LatestVersion, , InfobaseUser.Name);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Common use

Procedure DisableAccessKeysUpdate(Value, SubsystemExists)
	If SubsystemExists Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.DisableAccessKeysUpdate(Value);
	EndIf;
EndProcedure

Function DataUpdateModeInLocalMode()
	
	SetPrivilegedMode(True);
	Query = New Query;
	Query.Text = 
		"SELECT
		|	1 AS HasSubsystemVersions
		|FROM
		|	InformationRegister.SubsystemsVersions AS SubsystemsVersions
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1
		|FROM
		|	InformationRegister.DeleteSubsystemVersions AS DeleteSubsystemVersions";
	
	BatchExecutionResult = Query.ExecuteBatch();
	If BatchExecutionResult[0].IsEmpty() AND BatchExecutionResult[1].IsEmpty() Then
		Return "InitialFilling";
	ElsIf BatchExecutionResult[0].IsEmpty() AND Not BatchExecutionResult[1].IsEmpty() Then
		Return "VersionUpdate"; // Support for SL 2.1.2 updates.
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	1 AS HasSubsystemVersions
		|FROM
		|	InformationRegister.SubsystemsVersions AS SubsystemsVersions
		|WHERE
		|	SubsystemsVersions.IsMainConfiguration = TRUE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS HasSubsystemVersions
		|FROM
		|	InformationRegister.SubsystemsVersions AS SubsystemsVersions
		|WHERE
		|	SubsystemsVersions.SubsystemName = &BaseConfigurationName
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS HasSubsystemVersions
		|FROM
		|	InformationRegister.SubsystemsVersions AS SubsystemsVersions
		|WHERE
		|	SubsystemsVersions.IsMainConfiguration = TRUE
		|	AND SubsystemsVersions.SubsystemName = &BaseConfigurationName";
	Query.SetParameter("BaseConfigurationName", Metadata.Name);
	BatchExecutionResult = Query.ExecuteBatch();
	If BatchExecutionResult[0].IsEmpty() AND Not BatchExecutionResult[1].IsEmpty() Then
		Return "VersionUpdate"; // IsMainConfiguration attribute is not yet filled.
	EndIf;
	
	// Making decision based on the IsMainConfiguration attribute filled earlier
	Return ?(BatchExecutionResult[2].IsEmpty(), "MigrationFromAnotherApplication", "VersionUpdate");
	
EndFunction	

Function CanExecuteSeamlessUpdate(UpdateIterationsToCheck = Undefined) Export
	
	If UpdateIterationsToCheck = Undefined Then
		// Call mode intended for determining the full list of procedures for update handlers that require 
		// exclusive mode (without writing any messages to the event log).
		UpdateIterations = UpdateIterations();
	Else
		UpdateIterations = UpdateIterationsToCheck;
	EndIf;
	
	HandlerSeparationFilters = New Array;
	If NOT Common.SeparatedDataUsageAvailable() Then
		HandlerSeparationFilters.Add(False);
	EndIf;
	HandlerSeparationFilters.Add(True);
	
	// In the check mode, this parameter is ignored.
	MandatorySeparatedHandlers = InfobaseUpdate.NewUpdateHandlerTable();
	
	WriteToLog = Constants.WriteIBUpdateDetailsToEventLog.Get();
	HandlerProcedures = New Array;
	
	// Validating update handlers with the ExclusiveMode flag for configuration subsystems.
	For each UpdateIteration In UpdateIterations Do
		
		FilterParameters = HandlerFIlteringParameters();
		FilterParameters.UpdateMode = "Seamless";
		
		For each SeparationFlag In HandlerSeparationFilters Do
		
			FilterParameters.GetSeparated = SeparationFlag;
			
			HandlersTree = UpdateInIntervalHandlers(UpdateIteration.Handlers, UpdateIteration.PreviousVersion,
				UpdateIteration.Version, FilterParameters);
			If HandlersTree.Rows.Count() = 0 Then
				Continue;
			EndIf;
				
			If HandlersTree.Rows.Count() > 1 
				OR HandlersTree.Rows[0].Version <> "*" Then
				For Each VersionRow In HandlersTree.Rows Do
					If VersionRow.Version = "*" Then
						Continue;
					EndIf;
					For Each Handler In VersionRow.Rows Do
						HandlerProcedures.Add(Handler.Procedure);
					EndDo;
				EndDo;
			EndIf;
			
			If SeparationFlag 
				AND Common.DataSeparationEnabled() 
				AND NOT Common.SeparatedDataUsageAvailable() Then
				
				// When updating a shared infobase version, the exclusive mode for separated mandatory update 
				// handlers is controlled by a shared handler.
				Continue;
			EndIf;
			
			FoundHandlers = HandlersTree.Rows[0].Rows.FindRows(New Structure("ExclusiveMode", Undefined));
			For Each Handler In FoundHandlers Do
				HandlerProcedures.Add(Handler.Procedure);
			EndDo;
			
			// Calling the mandatory update handlers in check mode.
			For each Handler In HandlersTree.Rows[0].Rows Do
				If Handler.RegistrationVersion <> "*" Then
					HandlerProcedures.Add(Handler.Procedure);
					Continue;
				EndIf;
				
				HandlerParameters = New Structure;
				If Handler.HandlerManagement Then
					HandlerParameters.Insert("SeparatedHandlers", MandatorySeparatedHandlers);
				EndIf;
				HandlerParameters.Insert("ExclusiveMode", False);
				
				AdditionalParameters = New Structure;
				AdditionalParameters.Insert("WriteToLog", WriteToLog);
				AdditionalParameters.Insert("LibraryID", UpdateIteration.Subsystem);
				AdditionalParameters.Insert("HandlerExecutionProgress", Undefined);
				AdditionalParameters.Insert("InBackground", False);
				
				ExecuteUpdateHandler(Handler, HandlerParameters, AdditionalParameters);
				
				If HandlerParameters.ExclusiveMode = True Then
					HandlerProcedures.Add(Handler.Procedure);
				EndIf;
			EndDo;
			
		EndDo;
	EndDo;
	
	If UpdateIterationsToCheck = Undefined Then
		UpdateIterationsToCheck = HandlerProcedures;
		Return HandlerProcedures.Count() = 0;
	EndIf;
	
	If HandlerProcedures.Count() <> 0 Then
		MessageText = NStr("ru = 'Следующие обработчики не поддерживают обновление без установки монопольного режима:'; en = 'The following handlers support update in exclusive mode only:'; pl = 'Następujące programy przetwarzania nie obsługują aktualizacji bez ustanowienia trybu wyłączności:';es_ES = 'Los siguientes procesadores no admiten la actualización sin instalar el modo monopolio:';es_CO = 'Los siguientes procesadores no admiten la actualización sin instalar el modo monopolio:';tr = 'Aşağıdaki işleyicileri tekel modu yüklemeden güncelleştirme desteklemez:';it = 'I seguenti gestori non supportano l''aggiornamento senza l''installazione in modalità esclusiva:';de = 'Die folgenden Handler unterstützen keine Upgrades, ohne den Monopol-Modus einzustellen:'");
		MessageText = MessageText + Chars.LF;
		For Each HandlerProcedure In HandlerProcedures Do
			MessageText = MessageText + Chars.LF + HandlerProcedure;
		EndDo;
		WriteError(MessageText);
	EndIf;
	
	Return HandlerProcedures.Count() = 0;
	
EndFunction

Procedure CopyRowsToTree(Val DestinationRows, Val SourceRows, Val ColumnStructure)
	
	For each SourceRow In SourceRows Do
		FillPropertyValues(ColumnStructure, SourceRow);
		FoundRows = DestinationRows.FindRows(ColumnStructure);
		If FoundRows.Count() = 0 Then
			DestinationRow = DestinationRows.Add();
			FillPropertyValues(DestinationRow, SourceRow);
		Else
			DestinationRow = FoundRows[0];
		EndIf;
		
		CopyRowsToTree(DestinationRow.Rows, SourceRow.Rows, ColumnStructure);
	EndDo;
	
EndProcedure

Function GetUpdatePlan(Val LibraryID, Val VersionFrom, Val VersionTo)
	
	RecordManager = InformationRegisters.SubsystemsVersions.CreateRecordManager();
	RecordManager.SubsystemName = LibraryID;
	RecordManager.Read();
	If NOT RecordManager.Selected() Then
		Return Undefined;
	EndIf;
	
	PlanDetails = RecordManager.UpdatePlan.Get();
	If PlanDetails = Undefined Then
		
		Return Undefined;
		
	Else
		
		If PlanDetails.VersionFrom <> VersionFrom
			OR PlanDetails.VersionTo <> VersionTo Then
			
			// The update plan is outdated and cannot be applied to the current version.
			Return Undefined;
		EndIf;
		
		Return PlanDetails.Plan;
		
	EndIf;
	
EndFunction

// Disables the upadte handlers filled in the procedure.
// InfobaseUpdateOverridable.OnDetachUpdateHandlers.
//
// Parameters:
//  LibraryID - String - the configuration name or library ID.
//  HandlersToExecute  - ValueTree - the infobase update handlers.
//  IBMetadataVersion      - String - a metadata version. Only the handlers with versions matching 
//                                     the metadata version are detached.
//
Procedure DetachUpdateHandlers(LibraryID, HandlersToExecute, MetadataVersion, HandlerExecutionProgress)
	
	DetachableHandlers = New ValueTable;
	DetachableHandlers.Columns.Add("LibraryID");
	DetachableHandlers.Columns.Add("Procedure");
	DetachableHandlers.Columns.Add("Version");
	
	InfobaseUpdateOverridable.OnDetachUpdateHandlers(DetachableHandlers);
	
	// Searching for a tree row containing update handlers of version "*.
	LibraryHandlers = HandlersToExecute.Rows.Find("*", "Version", False);
	
	For Each DetachableHandler In DetachableHandlers Do
		
		// Checking whether the detachable handler belongs to the passed library.
		If LibraryID <> DetachableHandler.LibraryID Then
			Continue;
		EndIf;
		
		// Checking whether the handler is in the exception list.
		HandlerToExecute = HandlersToExecute.Rows.Find(DetachableHandler.Procedure, "Procedure", True);
		If HandlerToExecute <> Undefined AND HandlerToExecute.Version = "*"
			AND DetachableHandler.Version = MetadataVersion Then
			LibraryHandlers.Rows.Delete(HandlerToExecute);
			HandlerExecutionProgress.HandlerCountForVersion = HandlerExecutionProgress.HandlerCountForVersion - 1;
		ElsIf HandlerToExecute <> Undefined AND HandlerToExecute.Version <> "*"
			AND DetachableHandler.Version = MetadataVersion Then
			ExceptionText = NStr("ru='Обработчик обновления %1 не может быть отключен, 
										|так как он выполняется только при переходе на версию %2'; 
										|en = 'Update handler %1 cannot be detached
										|because it is only executed when updating to version %2.'; 
										|pl = 'Program przetwarzania aktualizacji %1 nie może być odłączony, 
										|ponieważ jest on wykonywany tylko podczas przejścia do wersji %2';
										|es_ES = 'El procesador de la actualización %1 no puede estar desactivado, 
										|porque está ejecutado solo al cambiar para la versión %2';
										|es_CO = 'El procesador de la actualización %1 no puede estar desactivado, 
										|porque está ejecutado solo al cambiar para la versión %2';
										|tr = 'Güncelleme işleyicisi, yalnızca %1 sürüme geçirilirken çalıştırıldığı 
										|için devre dışı bırakılamaz%2.';
										|it = 'Gestore aggiornamenti %1 non può essere disattivato
										|perché viene eseguito solo durante l''aggiornamento alla versione %2.';
										|de = 'Der Update-Handler %1 kann nicht deaktiviert werden,
										|da er nur beim Upgrade auf die Version ausgeführt wird %2'");
			ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(ExceptionText, HandlerToExecute.Procedure, HandlerToExecute.Version);
			
			Raise ExceptionText;
		ElsIf HandlerToExecute = Undefined Then
			ExceptionText = NStr("ru='Отключаемый обработчик обновления %1 не существует'; en = 'Detachable update handler %1 does not exist.'; pl = 'Wyłączany moduł obsługi %1 nie istnieje';es_ES = 'Manipulador de la actualización desactivado %1 no existe';es_CO = 'Manipulador de la actualización desactivado %1 no existe';tr = 'Ayrılabilir güncelleme işleyicisi %1 mevcut değil.';it = 'Gestore aggiornamenti disattivabile %1 non esiste.';de = 'Deaktivierter Update-Handler %1 existiert nicht'");
			ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(ExceptionText, DetachableHandler.Procedure);
			
			Raise ExceptionText;
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ExecuteUpdateHandler(Handler, Parameters, AdditionalParameters)
	
	WriteUpdateProgressInformation(Handler, AdditionalParameters.HandlerExecutionProgress, AdditionalParameters.InBackground);
	HandlerDetails = 
		PrepareUpdateProgressDetails(Handler, Parameters, AdditionalParameters.LibraryID);
	
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		MeasurementStart = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	If Parameters <> Undefined Then
		HandlerParameters = New Array;
		HandlerParameters.Add(Parameters);
	Else
		HandlerParameters = Undefined;
	EndIf;
	
	TransactionActiveAtExecutionStartTime = TransactionActive();
	
	SubsystemExists = Common.SubsystemExists("StandardSubsystems.AccessManagement");
	DisableAccessKeysUpdate(True, SubsystemExists);
	Try
		SetUpdateHandlerParameters(Handler);
		Common.ExecuteConfigurationMethod(Handler.Procedure, HandlerParameters);
		SetUpdateHandlerParameters(Undefined);
		DisableAccessKeysUpdate(False, SubsystemExists);
	Except
		
		DisableAccessKeysUpdate(False, SubsystemExists);
		If AdditionalParameters.WriteToLog Then
			WriteUpdateProgressDetails(HandlerDetails);
		EndIf;
		
		HandlerName = Handler.Procedure + "(" + ?(HandlerParameters = Undefined, "", "Parameters") + ")";
		
		WriteError(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'При вызове обработчика обновления:
					   |""%1""
					   |произошла ошибка:
					   |""%2"".'; 
					   |en = 'An error occurred while calling update handler
					   |%1:
					   |%2.
					   |'; 
					   |pl = 'Podczas wywołania programu przetwarzania aktualizacji:
					   |""%1""
					   |zaistniał błąd:
					   |""%2"".';
					   |es_ES = 'Al llamar el procesador de actualización:
					   |""%1""
					   | se ha producido un error:
					   |""%2"".';
					   |es_CO = 'Al llamar el procesador de actualización:
					   |""%1""
					   | se ha producido un error:
					   |""%2"".';
					   |tr = 'Güncelleştirme işleyicisi çağrıldığında: 
					   |""%1"" %2bir hata oluştu:
					   |"
".';
					   |it = 'Quando si chiama il gestore di aggiornamento:
					   |""%1""
					   |si è verificato un errore:
					   |""%2""';
					   |de = 'Beim Aufruf des Update-Handlers:
					   |""%1""
					   |ist ein Fehler aufgetreten:
					   |""%2"".'"),
			HandlerName,
			DetailErrorDescription(ErrorInfo())));
		
		Raise;
	EndTry;
	
	ValidateNestedTransaction(TransactionActiveAtExecutionStartTime, Handler.Procedure);
	
	If AdditionalParameters.WriteToLog Then
		WriteUpdateProgressDetails(HandlerDetails);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		ModulePerformanceMonitor.EndTechnologicalTimeMeasurement("UpdateHandlerExecutionTime." + HandlerDetails.Procedure, MeasurementStart);
	EndIf;
	
EndProcedure

Procedure ExecuteHandlersAfterInfobaseUpdate(Val UpdateIterations, Val WriteToLog, OutputUpdateDetails, Val SeamlessUpdate)
	
	For Each UpdateIteration In UpdateIterations Do
		
		If WriteToLog Then
			Handler = New Structure();
			Handler.Insert("Version", "*");
			Handler.Insert("RegistrationVersion", "*");
			Handler.Insert("ExecutionMode", "Seamless");
			Handler.Insert("Procedure", UpdateIteration.MainServerModuleName + ".AfterUpdateInfobase");
			HandlerDetails =  PrepareUpdateProgressDetails(Handler, Undefined, UpdateIteration.Subsystem);
		EndIf;
		
		Try
			
			UpdateIteration.MainServerModule.AfterUpdateInfobase(
				UpdateIteration.PreviousVersion,
				UpdateIteration.Version,
				UpdateIteration.CompletedHandlers,
				OutputUpdateDetails,
				NOT SeamlessUpdate);
				
		Except
			
			If WriteToLog Then
				WriteUpdateProgressDetails(HandlerDetails);
			EndIf;
			
			Raise;
			
		EndTry;
		
		If WriteToLog Then
			WriteUpdateProgressDetails(HandlerDetails);
		EndIf;
		
	EndDo;
	
EndProcedure

Function PrepareUpdateProgressDetails(Handler, Parameters, LibraryID, HandlerDeferred = False)
	
	HandlerDetails = New Structure;
	HandlerDetails.Insert("Library", LibraryID);
	If HandlerDeferred Then
		HandlerDetails.Insert("Version", Handler.VersionNumber);
		HandlerDetails.Insert("Procedure", Handler.HandlerName);
	Else
		HandlerDetails.Insert("Version", Handler.Version);
		HandlerDetails.Insert("Procedure", Handler.Procedure);
	EndIf;
	HandlerDetails.Insert("RegistrationVersion", Handler.RegistrationVersion);
	HandlerDetails.Insert("Parameters", Parameters);
	
	If HandlerDeferred Then
		HandlerDetails.Insert("ExecutionMode", "Deferred");
	ElsIf ValueIsFilled(Handler.ExecutionMode) Then
		HandlerDetails.Insert("ExecutionMode", Handler.ExecutionMode);
	Else
		HandlerDetails.Insert("ExecutionMode", "Exclusive");
	EndIf;
	
	If Common.DataSeparationEnabled()
	   AND Common.SeparatedDataUsageAvailable() Then
		
		ModuleSaaS = Common.CommonModule("SaaS");
		
		HandlerDetails.Insert("DataAreaValue",
			ModuleSaaS.SessionSeparatorValue());
		HandlerDetails.Insert("DataAreaUsage", True);
		
	Else
		
		HandlerDetails.Insert("DataAreaValue", -1);
		HandlerDetails.Insert("DataAreaUsage", False);
		
	EndIf;
	
	HandlerDetails.Insert("ValueAtStart", CurrentUniversalDateInMilliseconds());
	
	Return HandlerDetails;
	
EndFunction

Procedure WriteUpdateProgressDetails(HandlerDetails)
	
	Duration = CurrentUniversalDateInMilliseconds() - HandlerDetails.ValueAtStart;
	
	HandlerDetails.Insert("Completed", False);
	HandlerDetails.Insert("Duration", Duration / 1000); // In seconds
	
	WriteLogEvent(
		EventLogEventProtocol(),
		EventLogLevel.Information,
		,
		,
		Common.ValueToXMLString(HandlerDetails));
		
EndProcedure

Procedure ValidateNestedTransaction(TransactionActiveAtExecutionStartTime, HandlerName)
	
	EventName = EventLogEvent() + "." + NStr("ru = 'Выполнение обработчиков'; en = 'Execute handlers'; pl = 'Wykonywanie procedur obsługi';es_ES = 'Manipuladores de ejecución';es_CO = 'Manipuladores de ejecución';tr = 'İşleyiciler yürütülüyor';it = 'Esegui gestori';de = 'Handler ausführen'", CommonClientServer.DefaultLanguageCode());
	If TransactionActiveAtExecutionStartTime Then
		
		If TransactionActive() Then
			// Checking the absorbed exceptions in handlers.
			Try
				Constants.UseSeparationByDataAreas.Get();
			Except
				CommentTemplate = NStr("ru = 'Ошибка выполнения обработчика обновления %1:
				|Обработчиком обновления было поглощено исключение при активной внешней транзакции.
				|При активных транзакциях, открытых выше по стеку, исключение также необходимо пробрасывать выше по стеку.'; 
				|en = 'Error while executing update handler %1:
				|The update handler intercepted an exception while an external transaction was active.
				|If active transactions are open at higher stack levels, the exceptions also must be passed to higher stack levels.'; 
				|pl = 'Błąd podczas wykonywania procedury obsługi aktualizacji %1:
				|Program obsługi aktualizacji przechwycił wyjątek podczas aktywacji transakcji zewnętrznej.
				|Jeśli aktywne transakcje są otwarte na wyższych poziomach, wyjątki muszą być również przekazywane do wyższych poziomów.';
				|es_ES = 'Un error ejecutando el procesador de la actualización %1:
				| El procesador de actualización ha absorbido la excepción durante la transacción externa activa.
				|En el caso de las transacciones activas abiertas arriba de la pila, la excepción también tiene que ubicarse arriba de la pila.';
				|es_CO = 'Un error ejecutando el procesador de la actualización %1:
				| El procesador de actualización ha absorbido la excepción durante la transacción externa activa.
				|En el caso de las transacciones activas abiertas arriba de la pila, la excepción también tiene que ubicarse arriba de la pila.';
				|tr = 'İşleyici 
				|güncelleştirmesi yürütülürken bir hata oluştu: Güncelleme işleyicisi, etkin dış işlem sırasında özel durumu absorbe etti. %1Yığının üstünde açılmış etkin işlemlerin söz konusu olması durumunda, 
				|istisnanın da yığının üzerine yerleştirilmesi gerekir.';
				|it = 'Errore di esecuzione del gestore aggiornamenti %1:
				|l''eccezione viene assorbita dal gestore aggiornamenti quando la transazione esterna è attiva.
				|Con le transazioni attive aperte sopra lo stack, l''eccezione deve anche essere lanciata sopra lo stack.';
				|de = 'Ausführungsfehler des Update-Handlers %1:
				|Der Update-Handler hat eine Ausnahme in Anspruch genommen, während eine externe Transaktion aktiv ist.
				|Wenn aktive Transaktionen oberhalb des Stapels geöffnet werden, sollte die Ausnahme auch über den Stapel geworfen werden.'");
				Comment = StringFunctionsClientServer.SubstituteParametersToString(CommentTemplate, HandlerName);
				
				WriteLogEvent(EventName, EventLogLevel.Error,,, Comment);
				Raise(Comment);
			EndTry;
		Else
			CommentTemplate = NStr("ru = 'Ошибка выполнения обработчика обновления %1:
			|Обработчиком обновления была закрыта лишняя транзакция, открытая ранее (выше по стеку).'; 
			|en = 'Error while executing update handler %1:
			|The update handler closed an excessive transaction that was opened earlier (at a higher stack level).'; 
			|pl = 'Błąd podczas wykonywania procedury obsługi aktualizacji %1:
			|Program obsługi aktualizacji zamknął nadmierną transakcję, która została wcześniej otwarta (na wyższym poziomie stosu).';
			|es_ES = 'Ha ocurrido un error ejecutando el procesador de la actualización %1:
			| El procesador de la actualización ha cerrado una extra transacción previamente abierta (arriba en una pila).';
			|es_CO = 'Ha ocurrido un error ejecutando el procesador de la actualización %1:
			| El procesador de la actualización ha cerrado una extra transacción previamente abierta (arriba en una pila).';
			|tr = 'Güncelleme işleyicisini 
			|yürütürken bir hata %1 oluştu: Güncelleştirmenin işleyicisi, daha önce açılmış bir ek işlemi kapattı (yığında).';
			|it = 'Errore di esecuzione del gestore aggiornamenti %1:
			|la transazione in eccesso aperta in precedenza (sopra lo stack) è stata chiusa dal gestore aggiornamenti.';
			|de = 'Ausführungsfehler des Update-Handlers %1:
			|Der Update-Handler schloss eine zusätzliche Transaktion, die zuvor geöffnet wurde (höher im Stapel).'");
			Comment = StringFunctionsClientServer.SubstituteParametersToString(CommentTemplate, HandlerName);
			
			WriteLogEvent(EventName, EventLogLevel.Error,,, Comment);
			Raise(Comment);
		EndIf;
	Else
		If TransactionActive() Then
			CommentTemplate = NStr("ru = 'Ошибка выполнения обработчика обновления %1:
			|Открытая внутри обработчика обновления транзакция осталась активной (не была закрыта или отменена).'; 
			|en = 'Error while executing update handler %1:
			|A transaction that was opened in the update handler is still active (as it was not committed or rolled back).'; 
			|pl = 'Błąd podczas wykonywania procedury obsługi aktualizacji%1:
			|Transakcja, która została otwarta w programie obsługi aktualizacji, jest nadal aktywna (ponieważ nie została zatwierdzona lub wycofana).';
			|es_ES = 'Ha ocurrido un error ejecutando el procesador de la actualización %1:
			| La transacción abierta dentro del procesador de la actualización se ha quedado activa (no se ha cerrado o cancelado).';
			|es_CO = 'Ha ocurrido un error ejecutando el procesador de la actualización %1:
			| La transacción abierta dentro del procesador de la actualización se ha quedado activa (no se ha cerrado o cancelado).';
			|tr = 'Güncelleme işleyicisi 
			|yürütülürken bir hata oluştu: %1İşleyici içinde açılan işlem etkin kaldı (kapatılmadı veya iptal edilmedi).';
			|it = 'Errore di esecuzione del gestore di aggiornamento %1:
			|la transazione rimane attiva All''interno del gestore di aggiornamento (non chiusa o annullata).';
			|de = 'Ausführungsfehler des Update-Handlers %1:
			|Die im Update-Handler geöffnete Transaktion blieb aktiv (wurde nicht geschlossen oder abgebrochen).'");
			Comment = StringFunctionsClientServer.SubstituteParametersToString(CommentTemplate, HandlerName);
			
			WriteLogEvent(EventName, EventLogLevel.Error,,, Comment);
			Raise(Comment);
		EndIf;
	EndIf;
	
EndProcedure

Procedure ValidateHandlerProperties(UpdateIteration)
	
	For each Handler In UpdateIteration.Handlers Do
		ErrorDescription = "";
		
		If IsBlankString(Handler.Version) Then
			
			If Handler.InitialFilling <> True Then
				ErrorDescription = NStr("ru = 'У обработчика не заполнено свойство Version или свойство InitialFilling.'; en = 'One of the following handler properties is blank: Version or InitialFilling.'; pl = 'W module obsługi nie wypełniono wersji właściwości InitialFilling.';es_ES = 'La propiedad Versión o InitialFilling no está rellenada en el manipulador.';es_CO = 'La propiedad Versión o InitialFilling no está rellenada en el manipulador.';tr = 'Sürüm veya InitialFilling özelliği işleyicide doldurulmadı.';it = 'Il gestore non ha la proprietà Versione o la proprietà seeding iniziale.';de = 'Die Version oder Erstbefüllungs-Eigenschaft wird in dem Handler nicht ausgefüllt.'");
			EndIf;
			
		ElsIf Handler.Version <> "*" Then
			
			Try
				ZeroVersion = CommonClientServer.CompareVersions(Handler.Version, "0.0.0.0") = 0;
			Except
				ZeroVersion = False;
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'У обработчика неправильно заполнено свойство Версия: ""%1"".
					           |Правильный формат, например: ""2.1.3.70"".'; 
					           |en = 'The Version property of the handler has invalid value: %1.
					           |Valid version example: 2.1.3.70.'; 
					           |pl = 'W programie przetwarzania niepoprawnie wypełniono właściwość Wersja: ""%1"".
					           |Prawidłowy format, na przykład: ""2.1.3.70"".';
					           |es_ES = 'Para el procesador está rellenado incorrectamente Versión: ""%1"".
					           |Formato correcto, por ejemplo: ""2.1.3.70"".';
					           |es_CO = 'Para el procesador está rellenado incorrectamente Versión: ""%1"".
					           |Formato correcto, por ejemplo: ""2.1.3.70"".';
					           |tr = 'İşleyici Sürüm özelliği yanlış dolduruldu:""%1"". 
					           |Doğru biçim, örneğin: 21.3.70.';
					           |it = 'Il gestore ha una proprietà Versione: ""%1""
					           |popolata in modo errato. Il formato corretto, ad esempio: ""2.1.3.70"".';
					           |de = 'Der Handler hat die Eigenschaft Version: ""%1"" falsch ausgefüllt.
					           |Korrektes Format, z.B: ""2.1.3.70"".'"),
					Handler.Version);
			EndTry;
			
			If ZeroVersion Then
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'У обработчика неправильно заполнено свойство Версия: ""%1"".
					           |Версия не может быть нулевой.'; 
					           |en = 'The Version property of the handler has invalid value: %1.
					           |Zero versions are not allowed.'; 
					           |pl = 'W programie przetwarzania niepoprawnie wypełniono właściwość Wersja: ""%1"".
					           |Wersja nie może być zerowa.';
					           |es_ES = 'Para el procesador está rellenado incorrectamente Versión: ""%1"".
					           |La versión no puede ser nula.';
					           |es_CO = 'Para el procesador está rellenado incorrectamente Versión: ""%1"".
					           |La versión no puede ser nula.';
					           |tr = 'İşleyici Sürüm özelliği yanlış dolduruldu: ""%1"".
					           | Sürüm sıfır olamaz.';
					           |it = 'La proprietà della Versione: ""%1""
					           | non è stata compilata correttamente. La versione non può essere zero.';
					           |de = 'Der Handler hat die Eigenschaft Version: ""%1"" falsch ausgefüllt.
					           |Die Version darf nicht Null sein.'"),
					Handler.Version);
			EndIf;
			
			If NOT ValueIsFilled(ErrorDescription)
			   AND Handler.ExecuteInMandatoryGroup <> True
			   AND Handler.Priority <> 0 Then
				
				ErrorDescription = NStr("ru = 'У обработчика неправильно заполнено свойство Priority или
				                            |свойство ExecuteInMandatoryGroup.'; 
				                            |en = 'One of the following handler properties has invalid value: Priority or
				                            |ExecuteInMandatoryGroup.'; 
				                            |pl = 'W programie przetwarzania niepoprawnie wypełniono właściwość Priorytet lub
				                            |ExecuteInMandatoryGroup.';
				                            |es_ES = 'Para el procesador está rellenado incorrectamente Propiedad o 
				                            |la propiedad ExecuteInMandatoryGroup.';
				                            |es_CO = 'Para el procesador está rellenado incorrectamente Propiedad o 
				                            |la propiedad ExecuteInMandatoryGroup.';
				                            |tr = 'Bir işleyicinin, Priority özelliği veya
				                            |ExecuteInMandatoryGroup özelliği yanlış dolduruldu.';
				                            |it = 'Il gestore ha la proprietà priorità o la proprietà 
				                            |Esegui nel gruppo obbligatorio popolata in modo errato.';
				                            |de = 'Die Eigenschaft Priorität oder
				                            |die Eigenschaft InPflichtgruppeAusführen wurde vom Handler falsch ausgefüllt.'");
			EndIf;
		EndIf;
		
		If Handler.ExecutionMode <> ""
			AND Handler.ExecutionMode <> "Exclusive"
			AND Handler.ExecutionMode <> "Seamless"
			AND Handler.ExecutionMode <> "Deferred" Then
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'У обработчика ""%1"" неправильно заполнено свойство ExecutionMode.
				           |Допустимое значение: ""Exclusive"", ""Deferred"", ""Seamless"".'; 
				           |en = 'The ExecutionMode property of handler %1 has invalid value.
				           |Valid values are: ""Exclusive"", ""Deferred"", and ""Seamless.""'; 
				           |pl = 'Program przetwarzania ExecutionMode %1 ma nieprawidłową wartość.
				           |Prawidłowe wartości to: ""Exclusive"", ""Deferred"", i ""Seamless.""';
				           |es_ES = 'Para el procesador ""%1"" está rellenada incorrectamente la propiedad ExecutionMode.
				           |Valor admitido: ""Monopolio"", ""Aplazado"", ""Operativo""';
				           |es_CO = 'Para el procesador ""%1"" está rellenada incorrectamente la propiedad ExecutionMode.
				           |Valor admitido: ""Monopolio"", ""Aplazado"", ""Operativo""';
				           |tr = 'İşleyici Yürütme Modu özelliği işleyicide 
				           |yanlış dolduruldu.%1 İzin verilen değer: ""Exclusive"", ""Deferred"", ""Seamless"".';
				           |it = 'Il gestore ""%1"" ha compilato in modo errato la proprietà di modalità.
				           |Valore valido: ""Esclusivo"", ""Ritardato"", ""Immediato""';
				           |de = 'Der Handler ""%1"" hat die Eigenschaft AusführungModus falsch ausgefüllt.
				           |Zulässiger Wert: ""Monopol"", "" Verzögert "", "" Operativ "".'"),
				Handler.Procedure);
		EndIf;
		
		If NOT ValueIsFilled(ErrorDescription)
		   AND Handler.Optional = True
		   AND Handler.InitialFilling = True Then
			
			ErrorDescription = NStr("ru = 'У обработчика не правильно заполнено свойство Optional или
			                            |свойство InitialFilling.'; 
			                            |en = 'One of the following handler properties has invalid value: Optional or
			                            |InitialFilling.'; 
			                            |pl = 'W programie przetwarzania nie poprawnie wypełniono właściwość Opcjonalny lub
			                            |InitialFilling.';
			                            |es_ES = 'Para el procesador no está rellenado incorrectamente la propiedad Opcional o
			                            |la propiedad InitialFilling.';
			                            |es_CO = 'Para el procesador no está rellenado incorrectamente la propiedad Opcional o
			                            |la propiedad InitialFilling.';
			                            |tr = 'Optional veya InitialFilling özelliği 
			                            |işleyicide yanlış dolduruldu.';
			                            |it = 'Il gestore non ha la proprietà seeding opzionale o
			                            |seeding.';
			                            |de = 'Der Handler hat die Eigenschaft Optional oder
			                            |Anfangsausfüllung nicht korrekt ausgefüllt.'");
		EndIf;
			
		If Not ValueIsFilled(ErrorDescription) Then
			Continue;
		EndIf;
		
		If UpdateIteration.IsMainConfiguration Then
			ErrorTitle = NStr("ru = 'Ошибка в свойстве обработчика обновления конфигурации'; en = 'Configuration update handler property error'; pl = 'We właściwości konfiguracji modułu obsługi aktualizacji wystąpił błąd';es_ES = 'Ha ocurrido un error en la propiedad del manipulador de la actualización de la configuración';es_CO = 'Ha ocurrido un error en la propiedad del manipulador de la actualización de la configuración';tr = 'Yapılandırma güncelleme işleyicisinin özelliğinde bir hata oluştu';it = 'Errore nella proprietà del gestore aggiornamenti di configurazione';de = 'In der Eigenschaft des Konfigurationsaktualisierungshandlers ist ein Fehler aufgetreten'");
		Else
			ErrorTitle = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка в свойстве обработчика обновления библиотеки %1 версии %2'; en = 'Error in a property of library %1 (version %2) update handler'; pl = 'We właściwości biblioteki modułu obsługi aktualizacji %1 (wersji %2) wystąpił błąd';es_ES = 'Ha ocurrido un error en la propiedad del manipulador de la actualización de la biblioteca %1 de la versión %2';es_CO = 'Ha ocurrido un error en la propiedad del manipulador de la actualización de la biblioteca %1 de la versión %2';tr = '%1Sürüm kütüphane güncelleme işleyicisi %2özelliğinde bir hata oluştu';it = 'Errore nella proprietà del gestore di aggiornamento della libreria %1 di versione %2';de = 'In der Eigenschaft des Bibliotheksupdate-Handlers %1 der Version ist ein Fehler aufgetreten %2'"),
				UpdateIteration.Subsystem,
				UpdateIteration.Version);
		EndIf;
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			ErrorTitle + Chars.LF
			+ NStr("ru = '(%1).'; en = '(%1).'; pl = '(%1).';es_ES = '(%1).';es_CO = '(%1).';tr = '(%1).';it = '(%1).';de = '(%1).'") + Chars.LF
			+ Chars.LF
			+ ErrorDescription,
			Handler.Procedure);
		
		WriteError(ErrorDescription);
		Raise ErrorDescription;

	EndDo;
	
EndProcedure

Function HandlerCountForCurrentVersion(UpdateIterations, DeferredUpdateMode)
	
	HandlerCount = 0;
	
	// Exclusive update handlers.
	For Each UpdateIteration In UpdateIterations Do
		
		HandlersByVersion = UpdateInIntervalHandlers(
			UpdateIteration.Handlers, UpdateIteration.PreviousVersion, UpdateIteration.Version);
		For Each HandlersRowVersion In HandlersByVersion.Rows Do
			HandlerCount = HandlerCount + HandlersRowVersion.Rows.Count();
		EndDo;
		
	EndDo;
	
	UpdateInfo = InfobaseUpdateInfo();
	// Deferred update handlers.
	If DeferredUpdateMode = "Exclusive" Then
		DeferredUpdatePlan = UpdateInfo.DeferredUpdatePlan;
		For Each UpdateCycle In DeferredUpdatePlan Do
			HandlerCount = HandlerCount + UpdateCycle.Handlers.Count();
		EndDo;
	EndIf;
	
	// Parallel deferred update handler registration procedures.
	LibraryDetailsList = StandardSubsystemsCached.SubsystemsDetails().ByNames;
	If Common.SeparatedDataUsageAvailable() Then
		For Each RowLibrary In UpdateInfo.HandlersTree.Rows Do
			If LibraryDetailsList[RowLibrary.LibraryName].DeferredHandlerExecutionMode <> "Parallel" Then
				Continue;
			EndIf;
			For Each VersionRow In RowLibrary.Rows Do
				ParallelSinceVersion = LibraryDetailsList[RowLibrary.LibraryName].ParralelDeferredUpdateFromVersion;
				If VersionRow.VersionNumber = "*"
					Or (ValueIsFilled(ParallelSinceVersion)
						AND CommonClientServer.CompareVersions(VersionRow.VersionNumber, ParallelSinceVersion) < 0) Then
					Continue;
				EndIf;
				
				HandlerCount = HandlerCount + VersionRow.Rows.Count();
			EndDo;
		EndDo;
	EndIf;
	
	Return New Structure("TotalHandlerCount, CompletedHandlersCount", HandlerCount, 0);
	
EndFunction

Function MetadataObjectNameByManagerName(ManagerName)
	
	Position = StrFind(ManagerName, ".");
	If Position = 0 Then
		Return "CommonModule." + ManagerName;
	EndIf;
	ManagerType = Left(ManagerName, Position - 1);
	
	TypesNames = New Map;
	TypesNames.Insert("Catalogs", "Catalog");
	TypesNames.Insert("Documents", "Document");
	TypesNames.Insert("DataProcessors", "DataProcessor");
	TypesNames.Insert("ChartsOfCharacteristicTypes", "ChartOfCharacteristicTypes");
	TypesNames.Insert("AccountingRegisters", "AccountingRegister");
	TypesNames.Insert("AccumulationRegisters", "AccumulationRegister");
	TypesNames.Insert("CalculationRegisters", "CalculationRegister");
	TypesNames.Insert("InformationRegisters", "InformationRegister");
	TypesNames.Insert("BusinessProcesses", "BusinessProcess");
	TypesNames.Insert("DocumentJournals", "DocumentJournal");
	TypesNames.Insert("Tasks", "Task");
	TypesNames.Insert("Reports", "Report");
	TypesNames.Insert("Constants", "Constant");
	TypesNames.Insert("Enums", "Enum");
	TypesNames.Insert("ChartsOfCalculationTypes", "ChartOfCalculationTypes");
	TypesNames.Insert("ExchangePlans", "ExchangePlan");
	TypesNames.Insert("ChartsOfAccounts", "ChartOfAccounts");
	
	TypeName = TypesNames[ManagerType];
	If TypeName = Undefined Then
		Return ManagerName;
	EndIf;
	
	Return TypeName + Mid(ManagerName, Position);
EndFunction

Procedure SelectNewSubsystemHandlers(AllHandlers)
	
	// List of objects in new subsystems.
	NewSubsystemObjects = New Array;
	For Each SubsystemName In InfobaseUpdateInfo().NewSubsystems Do
		Subsystem = Metadata.FindByFullName(SubsystemName);
		If Subsystem = Undefined Then
			Continue;
		EndIf;
		For Each MetadataObject In Subsystem.Content Do
			NewSubsystemObjects.Add(MetadataObject.FullName());
		EndDo;
	EndDo;
	
	// Determines handlers in the new subsystems.
	AllHandlers.Columns.Add("IsNewSubsystem", New TypeDescription("Boolean"));
	For Each HandlerDetails In AllHandlers Do
		Position = StrFind(HandlerDetails.Procedure, ".", SearchDirection.FromEnd);
		ManagerName = Left(HandlerDetails.Procedure, Position - 1);
		If NewSubsystemObjects.Find(MetadataObjectNameByManagerName(ManagerName)) <> Undefined Then
			HandlerDetails.IsNewSubsystem = True;
		EndIf;
	EndDo;
	
EndProcedure

// See StandardSubsystemsServer.OnSendDataToSlave. 
Procedure OnSendSubsystemVersions(DataItem, ItemSend, Val InitialImageCreation = False)
	
	StandardProcessing = True;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.OnSendSubsystemVersions(DataItem, ItemSend, 
			InitialImageCreation, StandardProcessing);
	EndIf;
	
	If Not StandardProcessing Then
		Return;
	EndIf;
	
	If ItemSend = DataItemSend.Delete
		OR ItemSend = DataItemSend.Ignore Then
		
		// No overriding for standard processing.
		
	ElsIf TypeOf(DataItem) = Type("InformationRegisterRecordSet.SubsystemsVersions") Then
		
		If Not InitialImageCreation Then
			
			// Exporting the register during the initial image creation only.
			ItemSend = DataItemSend.Ignore;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Function UpdateStartMark()
	
	SessionDetails = New Structure;
	SessionDetails.Insert("ComputerName");
	SessionDetails.Insert("ApplicationName");
	SessionDetails.Insert("SessionStarted");
	SessionDetails.Insert("SessionNumber");
	SessionDetails.Insert("ConnectionNumber");
	SessionDetails.Insert("User");
	FillPropertyValues(SessionDetails, GetCurrentInfoBaseSession());
	SessionDetails.User = SessionDetails.User.Name;
	
	ParameterName = "StandardSubsystems.IBVersionUpdate.InfobaseUpdateSession";
	
	CanUpdate = True;
	
	Lock = New DataLock;
	If Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable() Then
		LockItem = Lock.Add("Constant.IBUpdateInfo");
	Else
		LockItem = Lock.Add("InformationRegister.ApplicationParameters");
		LockItem.SetValue("ParameterName", ParameterName);
	EndIf;
	
	BeginTransaction();
	Try
		Lock.Lock();
		SavedParameters = UpdateSessionInfo(ParameterName);
		
		If SavedParameters = Undefined Then
			SessionsMatch = False;
		Else
			SessionsMatch = DataMatch(SessionDetails, SavedParameters);
		EndIf;
		
		If Not SessionsMatch Then
			UpdateSessionActive = SessionActive(SavedParameters);
			If UpdateSessionActive Then
				UpdateSession = SavedParameters;
				CanUpdate = False;
			Else
				WriteUpdateSessionInfo(ParameterName, SessionDetails);
				UpdateSession = SessionDetails;
			EndIf;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Result = New Structure;
	Result.Insert("CanUpdate", CanUpdate);
	Result.Insert("UpdateSession", UpdateSession);
	
	Return Result;
	
EndFunction

Function UpdateSessionInfo(ParameterName)
	If Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable() Then
		Information = InfobaseUpdateInfo();
		UpdateSession = Information.UpdateSession;
	Else
		UpdateSession = StandardSubsystemsServer.ApplicationParameter(ParameterName);
	EndIf;
	
	Return UpdateSession;
EndFunction

Procedure WriteUpdateSessionInfo(ParameterName, SessionDetails)
	If Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable() Then
		Information = InfobaseUpdateInfo();
		Information.UpdateSession = SessionDetails;
		WriteInfobaseUpdateInfo(Information);
	Else
		StandardSubsystemsServer.SetApplicationParameter(ParameterName, SessionDetails);
	EndIf;
EndProcedure

Function SessionActive(SessionDetails)
	If SessionDetails = Undefined Then
		Return False;
	EndIf;
	
	InfobaseSessions = GetInfoBaseSessions();
	
	For Each Session In InfobaseSessions Do
		Match = DataMatch(SessionDetails, Session);
		If Match Then
			Break;
		EndIf;
	EndDo;
	
	Return Match;
EndFunction

Function DataMatch(Data1, Data2)
	
	Match = True;
	For Each KeyAndValue In Data1 Do
		If KeyAndValue.Key = "User" Then
			Continue;
		EndIf;
		
		If Data2[KeyAndValue.Key] <> KeyAndValue.Value Then
			Match = False;
			Break;
		EndIf;
	EndDo;
	
	Return Match;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Logging the update progress.

Procedure WriteInformation(Val Text)
	
	WriteLogEvent(EventLogEvent(), EventLogLevel.Information,,, Text);
	
EndProcedure

Procedure WriteError(Val Text)
	
	WriteLogEvent(EventLogEvent(), EventLogLevel.Error,,, Text);
	
EndProcedure

Procedure WriteUpdateProgressInformation(Handler, HandlerExecutionProgress, InBackground)
	
	If HandlerExecutionProgress = Undefined Then
		Return;
	EndIf;
	
	HandlerExecutionProgress.CompletedHandlersCount = HandlerExecutionProgress.CompletedHandlersCount + 1;
	
	If Not Common.DataSeparationEnabled() Then
		Message = NStr("ru = 'Выполняется обработчик обновления %1 (%2 из %3).'; en = 'Executing update handler %1 (%2 out of %3).'; pl = 'Trwa procedura aktualizacji %1 (%2 z %3).';es_ES = 'Manipulador de la actualización %1 está en progreso (%2 de %3).';es_CO = 'Manipulador de la actualización %1 está en progreso (%2 de %3).';tr = 'Güncelleme işleyicisi %1 devam ediyor (%2/%3).';it = 'Viene eseguito il gestore aggiornamenti %1(%2 da %3).';de = 'Update-Handler %1 ist in Bearbeitung (%2 von %3).'");
		Message = StringFunctionsClientServer.SubstituteParametersToString(
			Message, Handler.Procedure,
			HandlerExecutionProgress.CompletedHandlersCount, HandlerExecutionProgress.TotalHandlerCount);
		WriteInformation(Message);
	EndIf;
	
	If InBackground Then
		Progress = 10 + HandlerExecutionProgress.CompletedHandlersCount / HandlerExecutionProgress.TotalHandlerCount * 90;
		TimeConsumingOperations.ReportProgress(Progress);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Update details

// Displays update change description for a specified version.
//
// Parameters:
//  VersionNumber  - String - version number that is used to output the description from the 
//                          UpdateDetailsTemplate spreadsheet document template to the spreadsheet document.
//                          DocumentUpdateDetails.
//
Procedure OutputUpdateDetails(Val VersionNumber, DocumentUpdateDetails, UpdateDetailsTemplate)
	
	Number = StrReplace(VersionNumber, ".", "_");
	
	If UpdateDetailsTemplate.Areas.Find("Header" + Number) = Undefined Then
		Return;
	EndIf;
	
	DocumentUpdateDetails.Put(UpdateDetailsTemplate.GetArea("Header" + Number));
	DocumentUpdateDetails.StartRowGroup("Version" + Number);
	DocumentUpdateDetails.Put(UpdateDetailsTemplate.GetArea("Version" + Number));
	DocumentUpdateDetails.EndRowGroup();
	DocumentUpdateDetails.Put(UpdateDetailsTemplate.GetArea("Indent"));
	
EndProcedure

Function SystemChangesDisplayLastVersion(Val Username = Undefined) Export
	
	If Username = Undefined Then
		Username = UserName();
	EndIf;
	
	LatestVersion = Common.CommonSettingsStorageLoad("IBUpdate",
		"SystemChangesDisplayLastVersion", , , Username);
	
	Return LatestVersion;
	
EndFunction

Procedure DefineUpdateDetailsDisplay(OutputUpdateDetails)
	
	If OutputUpdateDetails AND Not Common.DataSeparationEnabled() Then
		Common.CommonSettingsStorageSave("IBUpdate", "OutputChangeDescriptionForAdministrator", True, , UserName());
	EndIf;
	
	If Common.SeparatedDataUsageAvailable() Then
		IBUpdateInfo = InfobaseUpdateInfo();
		IBUpdateInfo.OutputUpdateDetails = OutputUpdateDetails;
		
		WriteInfobaseUpdateInfo(IBUpdateInfo);
	EndIf;
	
EndProcedure

// Returns a list of update change details sections.
//
// Returns:
//  ListValue - Value - version weight (numeric).
//    Presentation - version string.
//
Function UpdateDetailsSections() Export
	
	Sections = New ValueList;
	MetadataVersionWeight = VersionWeight(Metadata.Version);
	
	UpdateDetailsTemplate = Metadata.CommonTemplates.Find("ApplicationReleaseNotes");
	If UpdateDetailsTemplate <> Undefined Then
		VersionPredicate = "Version";
		HeaderPredicate = "Header";
		Template = GetCommonTemplate(UpdateDetailsTemplate);
		
		For each Area In Template.Areas Do
			If StrFind(Area.Name, VersionPredicate) = 0 Then
				Continue;
			EndIf;
			
			VersionInDescriptionFormat = Mid(Area.Name, StrLen(VersionPredicate) + 1);
			
			If Template.Areas.Find(HeaderPredicate + VersionInDescriptionFormat) = Undefined Then
				Continue;
			EndIf;
			
			VersionDigitsAsStrings = StrSplit(VersionInDescriptionFormat, "_");
			If VersionDigitsAsStrings.Count() <> 4 Then
				Continue;
			EndIf;
			
			VersionWeight = VersionWeightFromStringArray(VersionDigitsAsStrings);
			
			Version = ""
				+ Number(VersionDigitsAsStrings[0]) + "."
				+ Number(VersionDigitsAsStrings[1]) + "."
				+ Number(VersionDigitsAsStrings[2]) + "."
				+ Number(VersionDigitsAsStrings[3]);
			
			If VersionWeight > MetadataVersionWeight Then
				ExceptionText = NStr("ru = 'В общем макете ApplicationReleaseNotes для одного из разделов изменений
					|установлена версия выше, чем в метаданных. (%1, должна быть %2)'; 
					|en = 'The version specified for a change description section in ApplicationReleaseNotes common template
					|is greater than the version specified in the metadata (%1 instead of correct version %2).'; 
					|pl = 'Wersja określona dla sekcji opisu zmiany w ApplicationReleaseNotes ogólnej makiecie
					|jest określona wersja wyższa, niż w metadanych (%1 zamiast poprawnej wersji %2).';
					|es_ES = 'En la plantilla común ApplicationReleaseNotes para uno de los apartados de los cambios
					|está establecida la versión superior que en los metadatos. (%1 debe ser %2)';
					|es_CO = 'En la plantilla común ApplicationReleaseNotes para uno de los apartados de los cambios
					|está establecida la versión superior que en los metadatos. (%1 debe ser %2)';
					|tr = 'ApplicationReleaseNotes genel düzeninde, değişiklik bölümlerinden biri
					|için sürüm meta verilerden daha yüksek (%1 olmalıdır %2).';
					|it = 'La versione specificata per una sezione descrizione modifiche nel modello comune ApplicationReleaseNotes
					| è superiore alla versione specificata nei metadati (%1 invece della versione corretta %2).';
					|de = 'Im allgemeinen Layout BeschreibungVonSystemänderungen ist einer der Änderungsabschnitte
					|in einer höheren Version als in den Metadaten. (%1, muss sein %2)'");
				ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(ExceptionText,
					Version, Metadata.Version);
				Raise ExceptionText;
			EndIf;
			
			Sections.Add(VersionWeight, Version);
		EndDo;
		
		Sections.SortByValue(SortDirection.Desc);
	EndIf;
	
	
	Return Sections;
	
EndFunction

Function VersionWeightFromStringArray(VersionDigitsAsStrings)
	
	Return 0
		+ Number(VersionDigitsAsStrings[0]) * 1000000000
		+ Number(VersionDigitsAsStrings[1]) * 1000000
		+ Number(VersionDigitsAsStrings[2]) * 1000
		+ Number(VersionDigitsAsStrings[3]);
	
EndFunction

Function GetLaterVersions(Sections, Version)
	
	Result = New Array;
	
	If Sections = Undefined Then
		Sections = UpdateDetailsSections();
	EndIf;
	
	VersionWeight = VersionWeight(Version);
	For each ListItem In Sections Do
		If ListItem.Value <= VersionWeight Then
			Continue;
		EndIf;
		
		Result.Add(ListItem.Presentation);
	EndDo;
	
	Return Result;
	
EndFunction

Function PreviousVersionHandlersCompleted(UpdateIterations)
	
	UpdateInfo = InfobaseUpdateInfo();
	SearchParameters = New Structure;
	SearchParameters.Insert("Status");
	SearchParameters.Insert("LibraryName");
	
	If UpdateInfo.DeferredUpdateCompletedSuccessfully <> True
		AND UpdateInfo.HandlersTree <> Undefined
		AND UpdateInfo.HandlersTree.Rows.Count() > 0 Then
		
		CheckDeferredHandlerTree(UpdateInfo.HandlersTree, True);
		
		SaveUncompletedHandlersRequired = False;
		For Each Library In UpdateIterations Do
			SearchParameters.LibraryName = Library.Subsystem;
			
			// Resetting the attempt count for handlers with Error status.
			SearchParameters.Status = "Error";
			HandlersWithErrors = UpdateInfo.HandlersTree.Rows.FindRows(SearchParameters, True);
			CheckDeferredHandlers(HandlersWithErrors, Library, SaveUncompletedHandlersRequired);
			
			// Searching for uncompleted handlers that must be saved for further restart.
			SearchParameters.Status = "NotCompleted";
			UncompletedHandlers = UpdateInfo.HandlersTree.Rows.FindRows(SearchParameters, True);
			CheckDeferredHandlers(UncompletedHandlers, Library, SaveUncompletedHandlersRequired);
			
			// Searching for handlers with Running status.
			SearchParameters.Status = "Running";
			HandlersRunning = UpdateInfo.HandlersTree.Rows.FindRows(SearchParameters, True);
			CheckDeferredHandlers(HandlersRunning, Library, SaveUncompletedHandlersRequired);
			
			If SaveUncompletedHandlersRequired Then
				SaveUncompletedHandlersRequired = False;
			Else
				RowLibrary = UpdateInfo.HandlersTree.Rows.Find(Library.Subsystem, "LibraryName");
				If RowLibrary <> Undefined Then
					UpdateInfo.HandlersTree.Rows.Delete(RowLibrary);
				EndIf;
			EndIf;
			
		EndDo;
		
		// Deleting successfully completed handlers
		CompletedHandlers = UpdateInfo.HandlersTree.Rows.FindRows(New Structure("Status", "Completed"), True);
		For Each PreviousHandler In CompletedHandlers Do
			VersionRow = PreviousHandler.Parent.Rows;
			VersionRow.Delete(PreviousHandler);
		EndDo;
		
		Return UpdateInfo.HandlersTree;
		
	EndIf;
	
	Return NewUpdateHandlersInfo();
	
EndFunction

Procedure CheckDeferredHandlers(HandlersToCheck, Library, SaveUncompletedHandlersRequired)
	For Each HandlerToCheck In HandlersToCheck Do
		HandlerRenamed = False;
		If Not ValueIsFilled(HandlerToCheck.ID) Then
			FoundHandler = Library.Handlers.Find(HandlerToCheck.HandlerName, "Procedure");
			If FoundHandler <> Undefined Then
				HandlerToCheck.ID = FoundHandler.ID;
			EndIf;
		Else
			CheckHandlerRenaming(HandlerToCheck, Library);
		EndIf;
		
		SaveUncompletedHandlers = SaveUncompletedDeferredHandlerRequired(Library, HandlerToCheck);
		If SaveUncompletedHandlers Then
			SaveUncompletedHandlersRequired = True;
		Else
			VersionRow = HandlerToCheck.Parent.Rows;
			VersionRow.Delete(HandlerToCheck);
		EndIf;
	EndDo;
EndProcedure

Function SaveUncompletedDeferredHandlerRequired(Library, Handler)
	If Handler.VersionNumber = "*" Then
		// The handler is added automatically during each update; saving the handler is not necessary.
		Return False;
	EndIf;
	
	FoundHandler = Library.Handlers.Find(Handler.HandlerName, "Procedure");
	If FoundHandler <> Undefined
		AND CommonClientServer.CompareVersions(FoundHandler.Version, Handler.VersionNumber) > 0
		AND CommonClientServer.CompareVersions(FoundHandler.Version, Library.PreviousVersion) > 0 Then
		// Version of the handler has changed; it is now greater than the current version of the library.
		// The handler will be added automatically; saving the handler is not necessary.
		Return False;
	EndIf;
	
	If CommonClientServer.CompareVersions(Handler.VersionNumber, Library.PreviousVersion) <= 0 Then
		// Version of the handler is equal to or less than the current version of the library. The handler 
		// will not be added to the execution list. You need to save it.
		If FoundHandler = Undefined Then
			// Ignoring and not saving the deleted handler.
			Return False;
		EndIf;
		FillPropertyValues(Handler, FoundHandler);
		
		HandlerParameters = Handler.ExecutionStatistics["HandlerParameters"];
		
		Handler.Status = "NotCompleted";
		Handler.ExecutionStatistics.Clear();
		If HandlerParameters <> Undefined Then
			Handler.ExecutionStatistics.Insert("HandlerParameters", HandlerParameters);
		EndIf;
		Handler.ErrorInfo = "";
		Handler.AttemptCount = 0;
		Return True;
	EndIf;
	
	Return False;
EndFunction

Procedure CheckHandlerRenaming(PreviousHandler, Library)
	NewHandler = Library.Handlers.Find(PreviousHandler.ID, "ID");
	If NewHandler <> Undefined
		AND NewHandler.Procedure <> PreviousHandler.HandlerName Then
		PreviousHandler.HandlerName = NewHandler.Procedure;
	EndIf;
EndProcedure

Procedure CheckDeferredHandlerTree(HandlersTree, InitialCheck = False)
	
	If InitialCheck Then
		NewHandlerTree = NewUpdateHandlersInfo();
		For Each Column In NewHandlerTree.Columns Do
			If HandlersTree.Columns.Find(Column.Name) = Undefined Then
				HandlersTree.Columns.Add(Column.Name, Column.ValueType);
			EndIf;
		EndDo;
		
		LibrariesToDelete = New Array;
		SubsystemsDetails = StandardSubsystemsCached.SubsystemsDetails().ByNames;
		For Each Library In HandlersTree.Rows Do
			LibraryExists = (SubsystemsDetails.Get(Library.LibraryName) <> Undefined);
			If LibraryExists Then
				Continue;
			EndIf;
			LibrariesToDelete.Add(Library);
		EndDo;
		
		For Each LibraryToDelete In LibrariesToDelete Do
			HandlersTree.Rows.Delete(LibraryToDelete);
		EndDo;
		
		Return;
	EndIf;
	
	AllHandlers = New Map;
	HandlersToDelete = New Array;
	For Each TreeRowLibrary In HandlersTree.Rows Do
		
		Index = 1;
		RowToMove = Undefined;
		Offset = 0;
		For Each TreeRowVersion In TreeRowLibrary.Rows Do
			
			If TreeRowVersion.VersionNumber = "*"
				AND Index <> 1 Then
				RowToMove = TreeRowVersion;
				Offset = Index - 1;
			EndIf;
			
			If TreeRowVersion.Rows.Count() = 0 Then
				TreeRowVersion.Status = "Completed";
			Else
				TreeRowVersion.Status = "";
			EndIf;
			
			// Checking for multiple copies of any update handler added.
			For Each TreeRowHandler In TreeRowVersion.Rows Do
				If AllHandlers[TreeRowHandler.HandlerName] = Undefined Then
					AllHandlers.Insert(TreeRowHandler.HandlerName, TreeRowHandler.HandlerName);
				Else
					HandlersToDelete.Add(TreeRowHandler);
				EndIf;
			EndDo;
			
			For Each Deleted In HandlersToDelete Do
				TreeRowVersion.Rows.Delete(Deleted);
			EndDo;
			HandlersToDelete.Clear();
			
			Index = Index + 1;
		EndDo;
		
		If RowToMove <> Undefined Then
			TreeRowLibrary.Rows.Move(RowToMove, Offset * (-1));
			RowToMove = Undefined;
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure CancelDeferredUpdate()
	
	OnEnableDeferredUpdate(False);
	
EndProcedure

Function AllDeferredHandlersCompleted(UpdateInfo)
	
	CompletedHandlersCount = 0;
	TotalHandlerCount     = 0;
	For Each TreeRowLibrary In UpdateInfo.HandlersTree.Rows Do
		For Each TreeRowVersion In TreeRowLibrary.Rows Do
			TotalHandlerCount = TotalHandlerCount + TreeRowVersion.Rows.Count();
			For Each Handler In TreeRowVersion.Rows Do
				
				If Handler.Status = "Completed" Then
					CompletedHandlersCount = CompletedHandlersCount + 1;
				EndIf;
				
			EndDo;
		EndDo;
	EndDo;
	
	If TotalHandlerCount = CompletedHandlersCount Then
		UpdateInfo.DeferredUpdateEndTime = CurrentSessionDate();
		UpdateInfo.DeferredUpdateCompletedSuccessfully = True;
		WriteInfobaseUpdateInfo(UpdateInfo);
		Constants.DeferredUpdateCompletedSuccessfully.Set(True);
		If Not Common.IsSubordinateDIBNode() Then
			Constants.DeferredMasterNodeUpdateCompleted.Set(True);
		EndIf;
		
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and deferred update functions.

// For internal use only.
//
Function ExecuteDeferredUpdateHandler(UpdateInfo, UpdateParameters = Undefined)
	
	HandlerContext = NewHandlerContext();
	UpdateHandler = FindUpdateHandler(HandlerContext, UpdateInfo, UpdateParameters);
	
	If TypeOf(UpdateHandler) = Type("ValueTreeRow") Then
		ResultAddress = PutToTempStorage(Undefined);
		
		Try
			ExecuteDeferredHandler(HandlerContext, ResultAddress);
			CompleteDeferredHandlerExecution(HandlerContext, ResultAddress, UpdateInfo);
		Except
			ProcessHandlerException(HandlerContext, UpdateHandler, ErrorInfo());
		EndTry;
	ElsIf UpdateHandler = False Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Finds an update handler that needs to be executed.
//
// Parameters:
//  HandlerContext - Structure - see NewHandlerContext(). 
//  UpdateInfo - Structure - see NewUpdateInfo(). 
//  UpdateParameters - Structure - see ExecuteInfobaseUpdate(). 
//
// Returns:
//  * ValueTreeRow - the update handler represented as a row of the handler tree.
//  * Boolean - True if executing the handler is not necessary, False otherwise.
//
Function FindUpdateHandler(HandlerContext, UpdateInfo, UpdateParameters = Undefined)
	
	AttachDetachDeferredUpdateHandlers(UpdateInfo);
	
	UpdatePlan = UpdateInfo.DeferredUpdatePlan;
	CurrentUpdateIteration = UpdateInfo.CurrentUpdateIteration;
	CurrentUpdateCycle     = Undefined;
	CompletedSuccessfully = True;
	While True Do
		HasUncompleted = False;
		HasRunning = False;
		PreviousUpdateCycle = Undefined;
		For Each UpdateCycleDetails In UpdatePlan Do
			If UpdateCycleDetails.Property("CompletedWithErrors")
				Or UpdateCycleDetails.Property("HasStopped") Then
				CompletedSuccessfully = False;
			Else
				
				If (PreviousUpdateCycle <> Undefined
						AND PreviousUpdateCycle.Handlers.Count() <> 0
						AND UpdateCycleDetails.DependsOnPrevious)
					Or UpdateCycleDetails.Handlers.Count() = 0 Then
					PreviousUpdateCycle = UpdateCycleDetails;
					Continue;
				EndIf;
				
				HasErrors = False;
				HasStopped = False;
				For Each HandlerDetails In UpdateCycleDetails.Handlers Do
					
					If HandlerDetails.Iteration = CurrentUpdateIteration Then
						HasUncompleted = True;
						Continue;
					EndIf;
					
					HandlersTree = UpdateInfo.HandlersTree.Rows;
					UpdateHandler = FindHandlerInTree(HandlersTree,
						HandlerDetails.ID,
						HandlerDetails.HandlerName);
					
					If UpdateHandler.Status = "Running" AND Not UpdateHandler.BatchProcessingCompleted Then
						HasRunning = True;
						Continue;
					EndIf;
					
					If UpdateHandler.Status = "Paused" Then
						HasStopped = True;
						Continue;
					EndIf;
					
					If UpdateHandler.Status = "Error" Then
						HasErrors = True;
						Continue;
					EndIf;
					
					If UpdateHandler.AttemptCount >= 3
					   AND AllHandlersLoop(UpdateInfo.HandlersTree) Then
						MarkLoopingHandlers(UpdateInfo.HandlersTree);
						HasErrors = True;
						Continue;
					EndIf;
					
					CurrentUpdateCycle = UpdateCycleDetails;
					Break;
					
				EndDo;
				
				If CurrentUpdateCycle = Undefined Then
					If HasErrors Then
						UpdateCycleDetails.Insert("CompletedWithErrors");
						CompletedSuccessfully = False;
					ElsIf HasStopped Then
						UpdateCycleDetails.Insert("HasStopped");
					EndIf;
				Else
					Break;
				EndIf;
			EndIf;
			
			PreviousUpdateCycle = UpdateCycleDetails;
		EndDo;
		
		If CurrentUpdateCycle <> Undefined Then
			HandlerCollection = CurrentUpdateCycle.Handlers;
			Break;
		ElsIf HasUncompleted Then
			CurrentUpdateIteration = CurrentUpdateIteration + 1;
			UpdateInfo.CurrentUpdateIteration = CurrentUpdateIteration;
		Else
			Break;
		EndIf;
	EndDo;
	
	If CurrentUpdateCycle = Undefined Then
		If HasRunning Then
			Return True;
		Else
			UpdateInfo.DeferredUpdatePlan = UpdatePlan;
			UpdateInfo.DeferredUpdateEndTime = CurrentSessionDate();
			UpdateInfo.DeferredUpdateCompletedSuccessfully = CompletedSuccessfully;
			WriteInfobaseUpdateInfo(UpdateInfo);
			Constants.DeferredUpdateCompletedSuccessfully.Set(CompletedSuccessfully);
			If Not Common.IsSubordinateDIBNode() Then
				Constants.DeferredMasterNodeUpdateCompleted.Set(CompletedSuccessfully);
			EndIf;
			
			Return False;
		EndIf;
	EndIf;
	
	ParallelMode = (CurrentUpdateCycle.Mode = "Parallel");
	UpdateParameters = ?(UpdateParameters = Undefined, New Structure, UpdateParameters);
	UpdateParameters.Insert("ParallelMode", ParallelMode);
	If ParallelMode Then
		Filter = New Structure("ExecuteInMasterNodeOnly", True);
		SearchResult = HandlersTree.FindRows(Filter, True);
		UpdateParameters.Insert("HandlersQueue", CurrentUpdateCycle.HandlersQueue);
		UpdateParameters.Insert("UpdatePlan", UpdatePlan);
		UpdateParameters.Insert("DataToProcess", UpdateInfo.DataToProcess);
		UpdateParameters.Insert("HasMasterNodeHandlers", (SearchResult.Count() > 0));
	EndIf;
	
	HandlersTree = UpdateInfo.HandlersTree;
	SetUpdateHandlerParameters(UpdateHandler, True, ParallelMode);
	BeforeStartDataProcessingProcedure(HandlerContext,
		UpdateHandler,
		UpdateParameters,
		HandlersTree);
	
	HandlerContext.HandlerID = HandlerDetails.ID;
	HandlerContext.HandlerName = HandlerDetails.HandlerName;
	HandlerContext.UpdateCycleDetailsIndex = UpdatePlan.Find(UpdateCycleDetails);
	HandlerContext.CurrentUpdateCycleIndex = UpdatePlan.Find(CurrentUpdateCycle);
	HandlerContext.ParallelMode = ParallelMode;
	HandlerContext.UpdateParameters = UpdateParameters;
	HandlerContext.UpdateHandlerParameters = SessionParameters.UpdateHandlerParameters;
	HandlerContext.CurrentUpdateIteration = CurrentUpdateIteration;
	
	SetUpdateHandlerParameters(Undefined);
	
	Return UpdateHandler;
	
EndFunction

// Completes execution of the deferred handler in the main thread after the background job has completed.
//
// Parameters:
//  HandlerContext - Structure - see NewHandlerContext(). 
//  UpdateInfo - Structure - see NewUpdateInfo(). 
//
Procedure EndDeferredUpdateHandlerExecution(HandlerContext, UpdateInfo)
	
	ParallelMode = HandlerContext.ParallelMode;
	CurrentUpdateIteration = HandlerContext.CurrentUpdateIteration;
	UpdatePlan = UpdateInfo.DeferredUpdatePlan;
	CurrentUpdateCycle = UpdatePlan[HandlerContext.CurrentUpdateCycleIndex];
	HandlerCollection = CurrentUpdateCycle.Handlers;
	UpdateCycleDetails = UpdatePlan[HandlerContext.UpdateCycleDetailsIndex];
	HandlerDetailsList = UpdateCycleDetails.Handlers;
	
	HandlerDetails = FindHandlerInTable(HandlerDetailsList,
		HandlerContext.HandlerID,
		HandlerContext.HandlerName);
	
	UpdateHandler = FindHandlerInTree(UpdateInfo.HandlersTree.Rows,
		HandlerContext.HandlerID,
		HandlerContext.HandlerName);
	
	If UpdateHandler.Status = "Completed" Then
		HandlerCollection.Delete(HandlerCollection.Find(HandlerDetails));
		LockedObjectsInfo = LockedObjectsInfo();
		HandlerInfo = LockedObjectsInfo.Handlers[UpdateHandler.HandlerName];
		If HandlerInfo <> Undefined Then
			HandlerInfo.Completed = True;
			WriteLockedObjectsInfo(LockedObjectsInfo);
		EndIf;
		
		// Removing the handler from the queue when in parallel mode, in order to determine which queues 
		// have uncompleted handlers.
		If ParallelMode Then
			Row = CurrentUpdateCycle.HandlersQueue.Find(UpdateHandler.HandlerName, "Handler");
			CurrentUpdateCycle.HandlersQueue.Delete(Row);
		EndIf;
	ElsIf UpdateHandler.Status = "Running" Then
		
		// If the handler has high priority it is called five times, after which the next handler is called.
		// 
		StartsWithPriority = Undefined;
		If UpdateHandler.Priority = "HighPriority" Then
			StartsWithPriority = UpdateHandler.ExecutionStatistics["StartsWithPriority"];
			StartsWithPriority = ?(StartsWithPriority = Undefined, 1, ?(StartsWithPriority = 4, 0, StartsWithPriority + 1));
			UpdateHandler.ExecutionStatistics.Insert("StartsWithPriority", StartsWithPriority);
		EndIf;
		
		If StartsWithPriority = Undefined Or StartsWithPriority = 0 Then
			HandlerDetails.Iteration = CurrentUpdateIteration;
		EndIf;
		
	Else
		
		HandlerDetails.Iteration = CurrentUpdateIteration;
	EndIf;
	
	UpdateInfo.DeferredUpdatePlan = UpdatePlan;
	
	// Stopping the update in parallel mode if the handler failed to complete, because other handlers 
	// might depend on the data to be processed by it.
	If ParallelMode
		AND UpdateHandler.Status = "Error"
		AND UpdateHandler.AttemptCount >= 3 Then
		UpdateInfo.DeferredUpdateEndTime = CurrentSessionDate();
		UpdateInfo.DeferredUpdateCompletedSuccessfully = False;
		WriteInfobaseUpdateInfo(UpdateInfo);
		Constants.DeferredUpdateCompletedSuccessfully.Set(False);
		If Not Common.IsSubordinateDIBNode() Then
			Constants.DeferredMasterNodeUpdateCompleted.Set(False);
		EndIf;
		
		ErrorTemplate = NStr("ru = 'Не удалось выполнить обработчик обновления ""%1"". Подробнее в журнале регистрации.'; en = 'Cannot execute update handler %1. See the event log for details.'; pl = 'Nie udało się wykonać program przetwarzania aktualizacji ""%1"". Szczegółowo w dzienniku rejestracji.';es_ES = 'No se ha podido ejecutar el procesador de la actualización ""%1"". Véase más en el registro de eventos.';es_CO = 'No se ha podido ejecutar el procesador de la actualización ""%1"". Véase más en el registro de eventos.';tr = 'Güncelleme işleyicisi başarısız oldu ""%1"". Daha fazla bilgi için olay günlüğüne bakın.';it = 'Impossibile eseguire il gestore aggiornamenti ""%1"". Leggi di più nel registro di registrazione.';de = 'Der Update-Handler konnte ""%1"" nicht ausführen. Details im Ereignisprotokoll.'");
		Raise StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate,
			HandlerContext.HandlerName);
	EndIf;
	
	If Common.FileInfobase() Then
		WriteInfobaseUpdateInfo(UpdateInfo);
	Else
		BeginTransaction();
		Try
			Lock = New DataLock;
			LockItem = Lock.Add("Constant.IBUpdateInfo");
			Lock.Lock();
			
			NewUpdateInfo = InfobaseUpdateInfo();
			UpdateInfo.DeferredUpdateManagement = NewUpdateInfo.DeferredUpdateManagement;
			
			WriteInfobaseUpdateInfo(UpdateInfo);
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
	
EndProcedure

Function PassedUpdateHandlerParameters(Parameters)
	PassedParameters = New Structure;
	For Each Parameter In Parameters Do
		If Parameter.Key <> "ProcessingCompleted"
			AND Parameter.Key <> "ExecutionProgress"
			AND Parameter.Key <> "PositionInQueue" Then
			PassedParameters.Insert(Parameter.Key, Parameter.Value);
		EndIf;
	EndDo;
	
	Return PassedParameters;
EndFunction

Function NewUpdateInfo(PreviousInfo = Undefined)
	
	UpdateInfo = New Structure;
	UpdateInfo.Insert("UpdateStartTime");
	UpdateInfo.Insert("UpdateEndTime");
	UpdateInfo.Insert("UpdateDuration");
	UpdateInfo.Insert("DeferredUpdateStartTime");
	UpdateInfo.Insert("DeferredUpdateEndTime");
	UpdateInfo.Insert("SessionNumber", New ValueList());
	UpdateInfo.Insert("UpdateHandlerParameters");
	UpdateInfo.Insert("DeferredUpdateCompletedSuccessfully");
	UpdateInfo.Insert("HandlersTree", New ValueTree());
	UpdateInfo.Insert("HandlerTreeVersion", "");
	UpdateInfo.Insert("OutputUpdateDetails", False);
	UpdateInfo.Insert("LegitimateVersion", "");
	UpdateInfo.Insert("NewSubsystems", New Array);
	UpdateInfo.Insert("DeferredUpdateManagement", New Structure);
	UpdateInfo.Insert("DataToProcess", New Map);
	UpdateInfo.Insert("CurrentUpdateIteration", 1);
	UpdateInfo.Insert("DeferredUpdatePlan");
	UpdateInfo.Insert("FillingProceduresDetails");
	UpdateInfo.Insert("UpdateSession");
	UpdateInfo.Insert("ThreadDetails");
	
	If TypeOf(PreviousInfo) = Type("Structure") Then
		FillPropertyValues(UpdateInfo, PreviousInfo);
	EndIf;
	
	Return UpdateInfo;
	
EndFunction

Function NewUpdateHandlersInfo()
	
	HandlersTree = New ValueTree;
	HandlersTree.Columns.Add("LibraryName");
	HandlersTree.Columns.Add("VersionNumber");
	HandlersTree.Columns.Add("RegistrationVersion");
	HandlersTree.Columns.Add("ID");
	HandlersTree.Columns.Add("HandlerName");
	HandlersTree.Columns.Add("Status");
	HandlersTree.Columns.Add("AttemptCount");
	HandlersTree.Columns.Add("ExecutionStatistics", New TypeDescription("Map"));
	HandlersTree.Columns.Add("ErrorInfo");
	HandlersTree.Columns.Add("Comment");
	HandlersTree.Columns.Add("Priority");
	HandlersTree.Columns.Add("CheckProcedure");
	HandlersTree.Columns.Add("ObjectsToLock");
	HandlersTree.Columns.Add("UpdateDataFillingProcedure");
	HandlersTree.Columns.Add("DeferredProcessingQueue");
	HandlersTree.Columns.Add("ExecuteInMasterNodeOnly", New TypeDescription("Boolean"));
	HandlersTree.Columns.Add("RunAlsoInSubordinateDIBNodeWithFilters", New TypeDescription("Boolean"));
	HandlersTree.Columns.Add("BatchProcessingCompleted", New TypeDescription("Boolean"));
	
	Return HandlersTree;
	
EndFunction

Function DeferredUpdateMode(UpdateParameters)
	
	FileInfobase             = Common.FileInfobase();
	DataSeparationEnabled                     = Common.DataSeparationEnabled();
	SeparatedDataUsageAvailable = Common.SeparatedDataUsageAvailable();
	ExecuteDeferredHandlers         = UpdateParameters.ExecuteDeferredHandlers;
	ClientLaunchParameter                 = SessionParameters.ClientParametersAtServer.Get("LaunchParameter");
	
	If Not DataSeparationEnabled Or SeparatedDataUsageAvailable Then
		If FileInfobase
			Or StrFind(Lower(ClientLaunchParameter), Lower("ExecuteDeferredUpdateNow")) > 0
			Or ExecuteDeferredHandlers Then
			Return "Exclusive";
		Else
			Return "Deferred";
		EndIf;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Gets infobase update information from the IBUpdateInfo constant.
// 
Function LockedObjectsInfo() Export
	
	SetPrivilegedMode(True);
	
	If Common.DataSeparationEnabled()
	   AND Not Common.SeparatedDataUsageAvailable() Then
		
		Return NewLockedObjectsInfo();
	EndIf;
	
	LockedObjectsInfo = Constants.LockedObjectsInfo.Get().Get();
	If TypeOf(LockedObjectsInfo) <> Type("Structure") Then
		Return NewLockedObjectsInfo();
	EndIf;
	
	LockedObjectsInfo = NewLockedObjectsInfo(LockedObjectsInfo);
	Return LockedObjectsInfo;
	
EndFunction

// Preparing to run the update handler in the main thread.
//
//  HandlerContext - Structure - see NewHandlerContext(). 
//  UpdateHandler - ValueTreeRow - the update handler represented as a row of the handler tree.
//  UpdateParameters - Structure - see ExecuteInfobaseUpdate(). 
//
Procedure BeforeStartDataProcessingProcedure(HandlerContext,
                                                UpdateHandler,
                                                UpdateParameters,
                                                HandlersTree)
	
	HandlerContext.WriteToLog = Constants.WriteIBUpdateDetailsToEventLog.Get();
	HandlerContext.TransactionActiveAtExecutionStartTime = TransactionActive();
	HandlerName = UpdateHandler.HandlerName;
	
	Try
		HandlerContext.StartedWithoutErrors = True;
		HandlerExecutionMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Выполняется процедура обновления ""%1"".'; en = 'Executing update procedure %1.'; pl = 'Aktualizacja ""%1"".';es_ES = 'Actualizando ""%1"".';es_CO = 'Actualizando ""%1"".';tr = '%1 güncelleme prosedürü yürütülüyor.';it = 'Viene eseguita la procedura di aggiornamento ""%1"".';de = 'Aktualisierung ""%1"".'"), HandlerName);
		WriteLogEvent(EventLogEvent(), 
				EventLogLevel.Information,,, HandlerExecutionMessage);
		
		// Data processing procedure progress.
		ExecutionProgress = New Structure;
		ExecutionProgress.Insert("TotalObjectCount", 0);
		ExecutionProgress.Insert("ProcessedObjectsCount", 0);
		If UpdateHandler.ExecutionStatistics["ExecutionProgress"] <> Undefined
			AND TypeOf(UpdateHandler.ExecutionStatistics["ExecutionProgress"]) = Type("Structure") Then
			FillPropertyValues(ExecutionProgress, UpdateHandler.ExecutionStatistics["ExecutionProgress"]);
		EndIf;
		
		// Initialization of handler parameters.
		Parameters = UpdateHandler.ExecutionStatistics["HandlerParameters"];
		If Parameters = Undefined Then
			Parameters = New Structure;
		EndIf;
		
		HandlerContext.Parameters = Parameters;
		
		If UpdateParameters.ParallelMode Then
			Parameters.Insert("ProcessingCompleted", Undefined);
		Else
			Parameters.Insert("ProcessingCompleted", True);
		EndIf;
		
		Parameters.Insert("ExecutionProgress", ExecutionProgress);
		
		Parameters.Insert("PositionInQueue", UpdateHandler.DeferredProcessingQueue);
		
		If HandlerContext.WriteToLog Then
			HandlerContext.HandlerFullDetails = PrepareUpdateProgressDetails(UpdateHandler,
				Parameters,
				UpdateHandler.LibraryName,
				True);
		EndIf;
		
		UpdateProcedureStartCount = UpdateProcedureStartCount(UpdateHandler);
		
		If UpdateProcedureStartCount > 10000 Then // Protection from looping.
			If UpdateParameters.ParallelMode
				AND Common.IsSubordinateDIBNode()
				AND UpdateParameters.HasMasterNodeHandlers Then
				ErrorText = NStr("ru = 'Превышено допустимое количество запусков процедуры обновления.
					|Убедитесь, что дополнительные процедуры обработки данных в главном узле
					|полностью завершились, выполните синхронизацию данных и повторно
					|запустите выполнение процедур обработки данных в данном узле.'; 
					|en = 'The maximum number of update handler execution attempts is exceeded.
					|Ensure that all additional update handlers in the main node
					|are completed, synchronize the data,
					|and execute the update handlers in this node again.'; 
					|pl = 'Przekroczono maksymalną liczbę prób wykonania programu obsługi aktualizacji.
					|Upewnij się, że wszystkie dodatkowe programy obsługi aktualizacji w głównym węźle
					|zostały ukończone, zsynchronizuj dane,
					|i ponownie uruchom programy obsługi aktualizacji w tym węźle.';
					|es_ES = 'Se ha superado la cantidad de lanzamientos del procedimiento de la actualización.
					|Asegúrese de que los procedimientos adicionales del procesamiento de datos en el nodo principal
					|se ha terminado completamente, sincronice los datos y vuelva
					|a lanzar la realización de los procedimientos del procesamiento de datos en este nodo.';
					|es_CO = 'Se ha superado la cantidad de lanzamientos del procedimiento de la actualización.
					|Asegúrese de que los procedimientos adicionales del procesamiento de datos en el nodo principal
					|se ha terminado completamente, sincronice los datos y vuelva
					|a lanzar la realización de los procedimientos del procesamiento de datos en este nodo.';
					|tr = 'Güncelleştirme prosedürünün geçerli başlatma sayısı aşıldı. 
					|Ana düğümdeki ek veri işleme yordamlarının 
					|tam olarak tamamlandığından emin olun, verileri eşitleyin ve bu ünitedeki 
					|veri işleme prosedürlerini yeniden çalıştırın.';
					|it = 'È stato superato il numero consentito di avvii della procedura di aggiornamento.
					|Assicurarsi che ulteriori procedure di elaborazione dei dati principale nodo
					| completamente concluse, eseguire la sincronizzazione dei dati e eseguire nuovamente
					|l''esecuzione di procedure di elaborazione dei dati in questo sito.';
					|de = 'Die zulässige Anzahl der Starts des Aktualisierungsvorgangs wird überschritten.
					|Stellen Sie sicher, dass die zusätzlichen Datenverarbeitungsverfahren im Hauptknoten
					|vollständig abgeschlossen sind, synchronisieren Sie die Daten und starten
					|Sie die Datenverarbeitungsverfahren in diesem Knoten neu.'");
			Else
				ErrorText = NStr("ru = 'Превышено допустимое количество запусков процедуры обновления.
					|Выполнение прервано для предотвращения зацикливания механизма обработки данных.'; 
					|en = 'The maximum number of update attempts is exceeded.
					|The update is canceled to prevent an endless loop.'; 
					|pl = 'Przekroczono maksymalną liczbę prób aktualizacji.
					|Aktualizacja jest anulowana, aby zapobiec niekończącej się pętli.';
					|es_ES = 'Se ha superado la cantidad de lanzamientos del procedimiento de la actualización.
					|La realización ha sido interrumpida para evitar que el mecanismo del procesamiento de datos entre en ciclo.';
					|es_CO = 'Se ha superado la cantidad de lanzamientos del procedimiento de la actualización.
					|La realización ha sido interrumpida para evitar que el mecanismo del procesamiento de datos entre en ciclo.';
					|tr = 'Güncelleştirme prosedürünün geçerli başlatma sayısı aşıldı. 
					|Yürütme veri işleme mekanizması döngü önlemek için durduruldu.';
					|it = 'È stato superato il numero consentito di avvii della procedura di aggiornamento.
					|Esecuzione interrotta per evitare loop di un meccanismo di elaborazione dei dati.';
					|de = 'Die zulässige Anzahl der Starts des Aktualisierungsvorgangs wird überschritten.
					|Die Ausführung wird unterbrochen, um zu verhindern, dass der Datenverarbeitungsmechanismus zyklisch läuft.'");
			EndIf;
			
			UpdateHandler.AttemptCount = 3;
			Raise ErrorText;
		EndIf;
		
		// Starting the deffered update handler.
		UpdateHandler.Status = "Running";
		UpdateHandler.BatchProcessingCompleted = False;
		If UpdateHandler.ExecutionStatistics["DataProcessingStart"] = Undefined Then
			UpdateHandler.ExecutionStatistics.Insert("DataProcessingStart", CurrentSessionDate());
		EndIf;
		
		HandlerContext.DataProcessingStart = CurrentUniversalDateInMilliseconds();
		If UpdateParameters.ParallelMode
			AND Common.IsSubordinateDIBNode()
			AND UpdateHandler.ExecuteInMasterNodeOnly Then
			// In the subordinate DIB node, we only check that the data processed by the handler came from the 
			// main node and update the status of the handler.
			HandlerContext.SkipProcessedDataCheck = True;
			DataToProcess = UpdateParameters.DataToProcess[UpdateHandler.HandlerName];
			If DataToProcess.Count() = 0 Then
				Parameters.ProcessingCompleted = True;
			Else
				For Each ObjectToProcess In DataToProcess Do
					Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(
						UpdateHandler.DeferredProcessingQueue,
						ObjectToProcess.Key);
					If Not Parameters.ProcessingCompleted Then
						Break;
					EndIf;
				EndDo;
			EndIf;
		Else
			HandlerContext.ExecuteHandler = True;
			Return;
		EndIf;
	Except
		ProcessHandlerException(HandlerContext, UpdateHandler, ErrorInfo());
		HandlerContext.StartedWithoutErrors = False;
	EndTry;
	
	EndDataProcessingProcedure(HandlerContext, UpdateHandler);
	
EndProcedure

// End of the startup of the data processing procedure in the main thread.
//
// Parameters:
//  HandlerContext - Structure - see NewHandlerContext(). 
//  UpdateHandler - ValueTreeRow - the update handler represented as a row of the handler tree.
//
Procedure AfterStartDataProcessingProcedure(HandlerContext, UpdateHandler, HandlersTree)
	
	Parameters = HandlerContext.Parameters;
	UpdateParameters = HandlerContext.UpdateParameters;
	
	Try
		DataProcessingCompletion = CurrentUniversalDateInMilliseconds();
		
		If Parameters.ProcessingCompleted = Undefined Then
			ErrorText = NStr("ru = 'Обработчик обновления не инициализировал параметр ProcessingCompleted.
			|Выполнение прервано из-за явной ошибки в коде обработчика.'; 
			|en = 'The update handler did not initialize ProcessingCompleted parameter.
			|The execution is canceled due to explicit error in the handler code.'; 
			|pl = 'Program obsługi aktualizacji nie zainicjował parametru ProcessingCompleted.
			|Wykonanie jest anulowane z powodu wyraźnego błędu w kodzie obsługi.';
			|es_ES = 'El procesador de la actualización no ha inicializado el parámetro ProcessingCompleted.
			|La realización ha sido interrumpida a causa del error en el código del procesador.';
			|es_CO = 'El procesador de la actualización no ha inicializado el parámetro ProcessingCompleted.
			|La realización ha sido interrumpida a causa del error en el código del procesador.';
			|tr = 'Güncelleme işleyicisi ProcessingCompleted parametresini başlatmamıştır.
			|Yürütme, işleyicinin kodundaki belirli bir hata yüzünden durduruldu.';
			|it = 'Il gestore aggiornamenti non ha inizializzato L''opzione Elaborazione completata.
			|Esecuzione interrotta a causa di un errore Esplicito nel codice del gestore.';
			|de = 'Der Update-Handler hat den Parameter BearbeitungAbgeschlossen nicht initialisiert.
			|Die Ausführung wird aufgrund eines offensichtlichen Fehlers im Handlercode unterbrochen.'");
			Raise ErrorText;
		EndIf;
		
		If Parameters.ProcessingCompleted Then
			UpdateHandler.Status = "Completed";
			UpdateHandler.Priority = "OnSchedule";
			UpdateHandler.ExecutionStatistics.Insert("DataProcessingCompletion", CurrentSessionDate());
			
			// Writing the progress update.
			If UpdateParameters.Property("InBackground")
				AND UpdateParameters.InBackground Then
				HandlerExecutionProgress = UpdateParameters.HandlerExecutionProgress;
				HandlerExecutionProgress.CompletedHandlersCount = HandlerExecutionProgress.CompletedHandlersCount + 1;
				Progress = 10 + HandlerExecutionProgress.CompletedHandlersCount / HandlerExecutionProgress.TotalHandlerCount * 90;
				TimeConsumingOperations.ReportProgress(Progress);
			EndIf;
		ElsIf UpdateParameters.ParallelMode AND Not HandlerContext.SkipProcessedDataCheck Then
			HasProcessedObjects = SessionParameters.UpdateHandlerParameters.HasProcessedObjects;
			HandlerQueue = UpdateHandler.DeferredProcessingQueue;
			
			MinQueue = 0;
			If Not HasProcessedObjects Then
				For Each UpdateCycle In UpdateParameters.UpdatePlan Do
					If UpdateCycle.Mode = "Sequentially"
						Or UpdateCycle.HandlersQueue.Count() = 0 Then
						Continue;
					EndIf;
					
					If MinQueue = 0 Then
						MinQueue = UpdateCycle.HandlersQueue[0].PositionInQueue;
					Else
						MinCycleQueue = UpdateCycle.HandlersQueue[0].PositionInQueue;
						MinQueue = Min(MinQueue, MinCycleQueue);
					EndIf;
				EndDo;
			EndIf;
			
			If Not HasProcessedObjects
				AND HandlerQueue = MinQueue Then
				AttemptCount = UpdateHandler.AttemptCount;
				If AttemptCount >= 2 AND AllHandlersLoop(HandlersTree) Then
					ExceptionText = NStr("ru = 'Произошло зацикливание процедуры обработки данных. Выполнение прервано.'; en = 'The data processing procedure went into an endless loop and was canceled.'; pl = 'Nastąpiło zapętlenie procedury przetwarzania danych. Wykonanie przerwano.';es_ES = 'El procedimiento del procesamiento de datos ha entrado en ciclo. Realización interrumpida.';es_CO = 'El procedimiento del procesamiento de datos ha entrado en ciclo. Realización interrumpida.';tr = 'Veri işleme prosedürü döngüsü takıldı. Yürütme durduruldu.';it = 'Si è verificato un ciclo di procedure di elaborazione dei dati. Esecuzione interrotta.';de = 'Das Datenverarbeitungsverfahren läuft zyklisch ab. Die Ausführung wird unterbrochen.'");
					Raise ExceptionText;
				Else
					UpdateHandler.AttemptCount = AttemptCount + 1;
				EndIf;
			Else
				UpdateHandler.AttemptCount = 0;
			EndIf;
		EndIf;
		
		// Saving data for the data processing procedure.
		UpdateHandler.ExecutionStatistics.Insert("ExecutionProgress", Parameters.ExecutionProgress);
		
		UpdateProcedureStartCount = UpdateProcedureStartCount(UpdateHandler) + 1;
		ExecutionDuration = DataProcessingCompletion - HandlerContext.DataProcessingStart;
		If UpdateHandler.ExecutionStatistics["ExecutionDuration"] <> Undefined Then
			ExecutionDuration = ExecutionDuration + UpdateHandler.ExecutionStatistics["ExecutionDuration"];
		EndIf;
		UpdateHandler.ExecutionStatistics.Insert("ExecutionDuration", ExecutionDuration);
		UpdateHandler.ExecutionStatistics.Insert("StartsCount", UpdateProcedureStartCount);
	Except
		ProcessHandlerException(HandlerContext, UpdateHandler, ErrorInfo());
	EndTry;
	
EndProcedure

// Completing the data processing procedure.
//
// Parameters:
//  HandlerContext - Structure - see NewHandlerContext(). 
//  UpdateHandler - ValueTreeRow - the update handler represented as a row of the handler tree.
//
Procedure EndDataProcessingProcedure(HandlerContext, UpdateHandler)
	
	Parameters = HandlerContext.Parameters;
	
	// Saving the parameters passed by the update handler, if any.
	PassedParameters = PassedUpdateHandlerParameters(Parameters);
	UpdateHandler.ExecutionStatistics.Insert("HandlerParameters", PassedParameters);
	
	If HandlerContext.HasOpenTransactions Then
		// If a nested transaction is found, the update handler is not called again.
		UpdateHandler.Status = "Error";
		UpdateHandler.ErrorInfo = String(UpdateHandler.ErrorInfo)
			+ Chars.LF + HandlerContext.ErrorInfo;
		
		UpdateHandler.AttemptCount = 3;
	EndIf;
	
	If HandlerContext.WriteToLog Then
		WriteUpdateProgressDetails(HandlerContext.HandlerFullDetails);
	EndIf;
	
EndProcedure

Procedure GenerateDeferredUpdatePlan(IBUpdateInfo, RepeatedGeneration = False) Export
	
	IsSubordinateDIBNode = Common.IsSubordinateDIBNode();
	IsSubordinateDIBNodeWithFilter = Common.IsSubordinateDIBNodeWithFilter();
	
	HandlersTree = IBUpdateInfo.HandlersTree;
	SubsystemsDetails = StandardSubsystemsCached.SubsystemsDetails();
	
	// Initialize parameters.
	UpdatePlan = New Array;
	HasMasterNodeHandlersOnly = False;
	
	LockedObjectsInfo = NewLockedObjectsInfo();
	For Each Subsystem In SubsystemsDetails.Order Do
		
		CollectionName = "";
		SubsystemDetails = SubsystemsDetails.ByNames[Subsystem];
		ExecutionMode    = SubsystemDetails.DeferredHandlerExecutionMode;
		ParallelSinceVersion = SubsystemDetails.ParralelDeferredUpdateFromVersion;
		
		HandlerTreeLibrary = HandlersTree.Rows.Find(Subsystem, "LibraryName");
		If HandlerTreeLibrary = Undefined Then
			Continue;
		EndIf;
		
		HandlersTable = New ValueTable;
		HandlersTable.Columns.Add("Handler", New TypeDescription("String"));
		HandlersTable.Columns.Add("ID", New TypeDescription("UUID"));
		HandlersTable.Columns.Add("PositionInQueue", New TypeDescription("Number"));
		
		Iteration = 1;
		CreateNewIteration = True;
		SkipCheck     = False;
		For Each HandlerTreeVersion In HandlerTreeLibrary.Rows Do
			If Not RepeatedGeneration Then
				FillLockedItems(HandlerTreeVersion, IBUpdateInfo, LockedObjectsInfo);
			EndIf;
			
			If CreateNewIteration Then
				UpdateIteration = New Structure;
				UpdateIteration.Insert("Mode", "");
				UpdateIteration.Insert("DependsOnPrevious", False);
				UpdateIteration.Insert("Handlers");
			EndIf;
			
			If ExecutionMode = "Sequentially" Then
				UpdateIteration.Mode = ExecutionMode;
				UpdateIteration.DependsOnPrevious = ?(Iteration = 1, False, True);
				UpdateIteration.Handlers = New Array;
			ElsIf ExecutionMode = "Parallel" AND Not ValueIsFilled(ParallelSinceVersion) AND Iteration = 1 Then
				UpdateIteration.Mode = ExecutionMode;
				UpdateIteration.Handlers = HandlersTable.Copy();
				CreateNewIteration = False;
			ElsIf ExecutionMode = "Parallel" AND ValueIsFilled(ParallelSinceVersion) AND Not SkipCheck Then
				VersionNumber = HandlerTreeVersion.VersionNumber;
				If VersionNumber = "*" Then
					Result = -1;
				Else
					Result = CommonClientServer.CompareVersions(VersionNumber, ParallelSinceVersion);
				EndIf;
				
				If Result < 0 Then
					UpdateIteration.Mode = "Sequentially";
					UpdateIteration.DependsOnPrevious = (Iteration <> 1);
					UpdateIteration.Handlers = New Array;
				Else
					UpdateIteration.Mode = ExecutionMode;
					UpdateIteration.DependsOnPrevious = (Iteration <> 1);
					UpdateIteration.Handlers = HandlersTable.Copy();
					SkipCheck = True;
					CreateNewIteration = False;
				EndIf;
			EndIf;
			
			For Each Handler In HandlerTreeVersion.Rows Do
				If RepeatedGeneration AND Handler.Status = "Completed" Then
					Continue;
				EndIf;
				
				If UpdateIteration.Mode = "Parallel" AND Not IsSubordinateDIBNode
					AND Handler.ExecuteInMasterNodeOnly = True Then
					HasMasterNodeHandlersOnly = True;
				EndIf;
				
				If UpdateIteration.Mode = "Parallel" AND IsSubordinateDIBNodeWithFilter
					AND Not Handler.RunAlsoInSubordinateDIBNodeWithFilters Then
					HasMasterNodeHandlersOnly = True;
					Continue;
				EndIf;
				
				If UpdateIteration.Mode = "Parallel" Then
					RowHandler = UpdateIteration.Handlers.Add();
					RowHandler.Handler    = Handler.HandlerName;
					RowHandler.ID = Handler.ID;
					RowHandler.PositionInQueue       = Handler.DeferredProcessingQueue;
				Else
					HandlerDetails = New Structure;
					HandlerDetails.Insert("HandlerName", Handler.HandlerName);
					HandlerDetails.Insert("ID", Handler.ID);
					HandlerDetails.Insert("Iteration", 0);
					
					UpdateIteration.Handlers.Add(HandlerDetails);
				EndIf;
				
			EndDo;
			
			// In parallel mode, only handlers with ExecuteAlsoInSubordinateDIBNodeWithFilters = True are 
			// executed in DIB with filters in a subordinate node.
			If IsSubordinateDIBNodeWithFilter AND UpdateIteration.Mode = "Parallel" Then
				FilterParameters = New Structure;
				FilterParameters.Insert("RunAlsoInSubordinateDIBNodeWithFilters", False);
				MasterNodeHandlersOnly = HandlerTreeVersion.Rows.FindRows(FilterParameters);
				For Each MasterNodeHandler In MasterNodeHandlersOnly Do
					HandlerTreeVersion.Rows.Delete(MasterNodeHandler);
				EndDo;
			EndIf;
			
			If CreateNewIteration Then
				UpdatePlan.Add(UpdateIteration);
			EndIf;
			
			Iteration = Iteration + 1 ;
			
		EndDo;
		
		If Not CreateNewIteration Then
			UpdatePlan.Add(UpdateIteration);
		EndIf;
	EndDo;
	
	If Not RepeatedGeneration Then
		WriteLockedObjectsInfo(LockedObjectsInfo);
		Constants.DeferredMasterNodeUpdateCompleted.Set(Not HasMasterNodeHandlersOnly);
	EndIf;
	
	HandlerDetails = New Structure;
	HandlerDetails.Insert("HandlerName", "");
	HandlerDetails.Insert("Iteration", 0);
	
	// Converting the handler storage format.
	For Each UpdateCycle In UpdatePlan Do
		If TypeOf(UpdateCycle.Handlers) = Type("Array") Then
			Continue;
		EndIf;
		HandlersTable = UpdateCycle.Handlers.Copy();
		HandlersTable.Sort("PositionInQueue Asc");
		
		UpdateCycle.Handlers = New Array;
		For Each Item In HandlersTable Do
			HandlerDetails = New Structure;
			HandlerDetails.Insert("HandlerName", Item.Handler);
			HandlerDetails.Insert("ID", Item.ID);
			HandlerDetails.Insert("Iteration", 0);
			
			UpdateCycle.Handlers.Add(HandlerDetails);
		EndDo;
		
		UpdateCycle.Insert("HandlersQueue", HandlersTable);
	EndDo;
	
	IBUpdateInfo.DeferredUpdatePlan = UpdatePlan;
	
EndProcedure

Procedure FillLockedItems(VersionRow, UpdateInfo, LockedObjectsInfo)
	
	For Each Handler In VersionRow.Rows Do
		CheckProcedure  = Handler.CheckProcedure;
		ObjectsToLock = Handler.ObjectsToLock;
		If ValueIsFilled(CheckProcedure) AND ValueIsFilled(ObjectsToLock) Then
			HandlerProperties = New Structure;
			HandlerProperties.Insert("Completed", False);
			HandlerProperties.Insert("CheckProcedure", CheckProcedure);
			
			LockedObjectsInfo.Handlers.Insert(Handler.HandlerName, HandlerProperties);
			LockedObjectArray = StrSplit(ObjectsToLock, ",");
			For Each LockedObject In LockedObjectArray Do
				LockedObject = StrReplace(TrimAll(LockedObject), ".", "");
				ObjectInformation = LockedObjectsInfo.ObjectsToLock[LockedObject];
				If ObjectInformation = Undefined Then
					HandlerArray = New Array;
					HandlerArray.Add(Handler.HandlerName);
					LockedObjectsInfo.ObjectsToLock.Insert(LockedObject, HandlerArray);
				Else
					LockedObjectsInfo.ObjectsToLock[LockedObject].Add(Handler.HandlerName);
				EndIf;
			EndDo;
		ElsIf ValueIsFilled(ObjectsToLock) AND Not ValueIsFilled(CheckProcedure) Then
			ExceptionText = NStr("ru = 'У отложенного обработчика обновления ""%1""
				|заполнен список блокируемых объектов, но не задано свойство ""CheckProcedure"".'; 
				|en = 'The list of locked objects is filled for deferred update handler %1
				|but the CheckProcedure property is not set.'; 
				|pl = 'W odroczonym programie przetwarzania aktualizacji %1
				|ale CheckProcedure nie jest ustawiona właściwość.';
				|es_ES = 'Para el procesador aplazado de la actualización ""%1""
				|está rellenada la lista de los objetos bloqueados pero no está establecido la propiedad ""CheckProcedure"".';
				|es_CO = 'Para el procesador aplazado de la actualización ""%1""
				|está rellenada la lista de los objetos bloqueados pero no está establecido la propiedad ""CheckProcedure"".';
				|tr = 'Ertelenmiş güncelleştirme işleyicisi ""%1"" engellenen nesnelerin bir listesini dolduruldu, 
				|ancak ""CheckProcedure"" özelliği ayarlanmamıştır.';
				|it = 'Il gestore di aggiornamento posticipato ""%1""
				|ha un elenco di oggetti bloccati, ma non è stata impostata la ""ProprietàRoutine"".';
				|de = 'Die Liste der zu sperrenden Objekte wird im verzögerten Aktualisierungs-Handler ""%1""
				|ausgefüllt, aber die Eigenschaft CheckProcedure ist nicht eingestellt.'");
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(ExceptionText, Handler.HandlerName);
		EndIf;
	EndDo;
	
EndProcedure

Procedure AttachDetachDeferredUpdateHandlers(UpdateInfo)
	
	UpdatePlan          = UpdateInfo.DeferredUpdatePlan;
	HandlerManagement = UpdateInfo.DeferredUpdateManagement;
	StartHandlers    = Undefined;
	StopHandlers   = Undefined;
	SpeedPriority = Undefined;
	SchedulePriority  = Undefined;
	
	UpdateInfo.DeferredUpdateManagement.Property("RunHandlers", StartHandlers);
	UpdateInfo.DeferredUpdateManagement.Property("StopHandlers", StopHandlers);
	UpdateInfo.DeferredUpdateManagement.Property("SpeedPriority", SpeedPriority);
	UpdateInfo.DeferredUpdateManagement.Property("SchedulePriority", SchedulePriority);
	
	// Starting the deferred update handlers that were stopped.
	If StartHandlers <> Undefined Then
		For Each RunningHandler In StartHandlers Do
			FoundHandler = UpdateInfo.HandlersTree.Rows.Find(RunningHandler, "HandlerName", True);
			If FoundHandler <> Undefined Then
				FoundHandler.Status = "NotCompleted";
				
				For Each UpdateCycle In UpdatePlan Do
					For Each HandlerDetails In UpdateCycle.Handlers Do
						If HandlerDetails.HandlerName = FoundHandler.HandlerName Then
							If UpdateCycle.Property("HasStopped") Then
								UpdateCycle.Delete("HasStopped");
							EndIf;
							Break;
						EndIf;
					EndDo;
				EndDo;
				
			EndIf;
		EndDo;
		
		UpdateInfo.DeferredUpdateManagement.Delete("RunHandlers");
	EndIf;
	
	// Stopping the deferred update handlers that are running.
	If StopHandlers <> Undefined Then
		For Each StoppedHandler In StopHandlers Do
			FoundHandler = UpdateInfo.HandlersTree.Rows.Find(StoppedHandler, "HandlerName", True);
			If FoundHandler <> Undefined
				AND FoundHandler.Status <> "Completed" Then
				FoundHandler.Status = "Paused";
			EndIf;
		EndDo;
		
		UpdateInfo.DeferredUpdateManagement.Delete("StopHandlers");
	EndIf;
	
	// Increasing priority of the data processing procedure.
	If SpeedPriority <> Undefined Then
		For Each Handler In SpeedPriority Do
			FoundHandler = UpdateInfo.HandlersTree.Rows.Find(Handler, "HandlerName", True);
			If FoundHandler <> Undefined
				AND FoundHandler.Status <> "Completed" Then
				FoundHandler.Priority = "HighPriority";
			EndIf;
		EndDo;
		
		UpdateInfo.DeferredUpdateManagement.Delete("SpeedPriority");
	EndIf;
	
	// Decreasing priority of the data processing procedure.
	If SchedulePriority <> Undefined Then
		For Each Handler In SchedulePriority Do
			FoundHandler = UpdateInfo.HandlersTree.Rows.Find(Handler, "HandlerName", True);
			If FoundHandler <> Undefined
				AND FoundHandler.Status <> "Completed" Then
				FoundHandler.Priority = "OnSchedule";
			EndIf;
		EndDo;
		
		UpdateInfo.DeferredUpdateManagement.Delete("SchedulePriority");
	EndIf;
	
	If StartHandlers <> Undefined
		Or StopHandlers <> Undefined
		Or SpeedPriority <> Undefined
		Or SchedulePriority <> Undefined Then
		WriteInfobaseUpdateInfo(UpdateInfo);
	EndIf;
	
EndProcedure

Function NewLockedObjectsInfo(PreviousInfo = Undefined)
	
	LockedObjectsInfo = New Structure;
	LockedObjectsInfo.Insert("ObjectsToLock", New Map);
	LockedObjectsInfo.Insert("Handlers", New Map);
	
	If TypeOf(PreviousInfo) = Type("Structure") Then
		FillPropertyValues(LockedObjectsInfo, PreviousInfo);
	EndIf;
	
	Return LockedObjectsInfo;
	
EndFunction

Procedure WriteLockedObjectsInfo(Information)
	
	If Information = Undefined Then
		NewValue = NewLockedObjectsInfo();
	Else
		NewValue = Information;
	EndIf;
	
	ConstantManager = Constants.LockedObjectsInfo.CreateValueManager();
	ConstantManager.Value = New ValueStorage(NewValue);
	InfobaseUpdate.WriteData(ConstantManager);
	
EndProcedure

Procedure FillDataForParallelDeferredUpdate(UpdateInfo, Parameters)
	
	If Not Common.SeparatedDataUsageAvailable() Then
		CanlcelDeferredUpdateHandlersRegistration();
		Return;
	EndIf;
	
	If Parameters.OnClientStart
		AND Parameters.DeferredUpdateMode = "Deferred" Then
		ClientServer  = Not Common.FileInfobase();
		Box       = Not Common.DataSeparationEnabled();
		
		If ClientServer AND Box Then
			// Skipping data registration for now.
			Return;
		EndIf;
	EndIf;
	
	If Not (StandardSubsystemsCached.DIBUsed("WithFilter") AND Common.IsSubordinateDIBNode()) Then
		Query = New Query;
		Query.Text = 
		"SELECT
		|	InfobaseUpdate.Ref AS Node
		|FROM
		|	ExchangePlan.InfobaseUpdate AS InfobaseUpdate
		|WHERE
		|	NOT InfobaseUpdate.ThisNode";
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			ExchangePlans.DeleteChangeRecords(Selection.Node);
		EndDo;
	EndIf;
	
	If Not Common.IsSubordinateDIBNode()
		AND Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.ClearConstantValueWithChangesForSUbordinateDIBNodeWithFilters();
	EndIf;
	
	DataToProcess = New Map;
	LibraryDetailsList = StandardSubsystemsCached.SubsystemsDetails().ByNames;
	ParametersInitialized = False;
	
	For Each RowLibrary In UpdateInfo.HandlersTree.Rows Do
		
		If LibraryDetailsList[RowLibrary.LibraryName].DeferredHandlerExecutionMode <> "Parallel" Then
			Continue;
		EndIf;
		
		ParallelSinceVersion = LibraryDetailsList[RowLibrary.LibraryName].ParralelDeferredUpdateFromVersion;
		
		If Not ParametersInitialized Then
			
			HandlerParametersStructure = InfobaseUpdate.MainProcessingMarkParameters();
			ParametersInitialized = True;
			
			If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
				ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
				ModuleDataExchangeServer.InitializeUpdateDataFile(HandlerParametersStructure);
			EndIf;
			
		EndIf;
		
		For Each VersionRow In RowLibrary.Rows Do
			If VersionRow.VersionNumber = "*" Then
				Continue;
			EndIf;
			
			If ValueIsFilled(ParallelSinceVersion)
				AND CommonClientServer.CompareVersions(VersionRow.VersionNumber, ParallelSinceVersion) < 0 Then
				Continue;
			EndIf;
			
			For Each Handler In VersionRow.Rows Do
				
				HandlerParametersStructure.PositionInQueue = Handler.DeferredProcessingQueue;
				HandlerParametersStructure.Insert("HandlerData", New Map);
				
				HandlerParameters = New Array;
				HandlerParameters.Add(HandlerParametersStructure);
				Try
					Message = NStr("ru = 'Выполняется процедура заполнения данных
						                   |""%1""
						                   |отложенного обработчика обновления
						                   |""%2"".'; 
						                   |en = 'Executing data population procedure
						                   |%1
						                   |of deferred update handler
						                   |%2.'; 
						                   |pl = 'Jest wykonywana procedura wypełnienia danych
						                   |""%1""
						                   |odroczonego programu przetwarzania aktualizacji
						                   |""%2"".';
						                   |es_ES = 'Se está realizando el procedimiento de relleno de datos
						                   |""%1""
						                   | del procesador aplazado de actualización
						                   |""%2"".';
						                   |es_CO = 'Se está realizando el procedimiento de relleno de datos
						                   |""%1""
						                   | del procesador aplazado de actualización
						                   |""%2"".';
						                   |tr = '"
"%1Ertelenmiş güncelleme işleyicisinin 
						                   |veri doldurma prosedürü yürütülüyor 
						                   |%2.';
						                   |it = 'Eseguendo la procedura di popolazione dati
						                   |%1
						                   |del gestore aggiornamento posticipato
						                   |%2';
						                   |de = 'Der Vorgang zum Ausfüllen der Daten
						                   |""%1""
						                   |des verzögerten Aktualisierungs-Handlers
						                   |""%2"" wird durchgeführt.'");
					Message = StringFunctionsClientServer.SubstituteParametersToString(Message,
						Handler.UpdateDataFillingProcedure,
						Handler.HandlerName);
					WriteInformation(Message);
					
					Common.ExecuteConfigurationMethod(Handler.UpdateDataFillingProcedure, HandlerParameters);
					
					// Writing the progress update.
					If Parameters.InBackground Then
						HandlerExecutionProgress = Parameters.HandlerExecutionProgress;
						HandlerExecutionProgress.CompletedHandlersCount = HandlerExecutionProgress.CompletedHandlersCount + 1;
						Progress = 10 + HandlerExecutionProgress.CompletedHandlersCount / HandlerExecutionProgress.TotalHandlerCount * 90;
						TimeConsumingOperations.ReportProgress(Progress);
					EndIf;
				Except
					CanlcelDeferredUpdateHandlersRegistration(RowLibrary.LibraryName, False);
					WriteError(StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'При вызове процедуры заполнения данных
								   |""%1""
								   |отложенного обработчика обновления
								   |""%2""
								   |произошла ошибка:
								   |""%3"".'; 
								   |en = 'Error while calling data population procedure 
								   |%1
								   |of deferred update handler
								   |%2:
								   |%3
								   |'; 
								   |pl = 'Podczas wywołania procedury wypełnienia danych
								   |""%1""
								   |odroczonego programu przetwarzania aktualizacji
								   |""%2""
								   |zaistniał błąd:
								   |""%3"".';
								   |es_ES = 'Al llamar el procedimiento del relleno de datos
								   |""%1""
								   | del procesador aplazado de actualización
								   |""%2""
								   |se ha producido un error:
								   |""%3"".';
								   |es_CO = 'Al llamar el procedimiento del relleno de datos
								   |""%1""
								   | del procesador aplazado de actualización
								   |""%2""
								   |se ha producido un error:
								   |""%3"".';
								   |tr = 'Ertelenen güncelleştirme işleyicisi "
" %1
								   |veri doldurma %3prosedürü çağrıldığında bir 
								   |
								   |hata oluştu:%2 "
".';
								   |it = 'Errore durante la chiamata alla procedura di inserimento dati 
								   |%1
								   |del gestore di aggiornamenti differiti
								   |%2:
								   |%3
								   |';
								   |de = 'Beim Aufrufen der Prozedur zum Füllen der Daten
								   |""%1""
								   |des verzögerten Aktualisierungs-Handlers
								   |""%2""
								   |ist ein Fehler aufgetreten:
								   |""%3"".'"),
						Handler.UpdateDataFillingProcedure,
						Handler.HandlerName,
						DetailErrorDescription(ErrorInfo())));
					
					Raise;
				EndTry;
				
				DataToProcess.Insert(Handler.HandlerName, HandlerParametersStructure.HandlerData);
			EndDo;
		EndDo;
		
	EndDo;
	
	UpdateInfo.DataToProcess = DataToProcess;
	CanlcelDeferredUpdateHandlersRegistration();
	
	If ParametersInitialized AND Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.CompleteWriteUpdateDataFile(HandlerParametersStructure);
	EndIf;
	
EndProcedure

// Fills data for parallel deferred update in background using multiple threads.
//
// Parameters:
//  FormID - UUID - the ID of the form that displays the update progress.
//  ResultAddress - String - address of the temporary storage used to store the procedure result.
//
Procedure StartDeferredHandlerDataRegistration(FormID, ResultAddress) Export
	
	UpdateInfo = InfobaseUpdateInfo();
	
	If UpdateInfo.ThreadDetails <> Undefined Then
		CancelAllThreadsExecution(UpdateInfo.ThreadDetails);
	EndIf;
	
	ThreadDetails = NewDetailsOfDeferredUpdateDataRegistrationThreads();
	UpdateInfo.ThreadDetails = ThreadDetails;
	
	Try
		For each CurrentProcedure In UpdateInfo.FillingProceduresDetails Do
			Thread = AddDeferredUpdateDataRegistrationThread(ThreadDetails, CurrentProcedure.Value);
			ExecuteThread(ThreadDetails, Thread, FormID);
			WaitForAvailableThread(ThreadDetails, UpdateInfo);
			WriteInfobaseUpdateInfo(UpdateInfo);
		EndDo;
		
		WaitForAllThreadsCompletion(ThreadDetails, UpdateInfo);
		SaveThreadsStateToUpdateInfo(Undefined, UpdateInfo);
	Except
		CancelAllThreadsExecution(UpdateInfo.ThreadDetails);
		SaveThreadsStateToUpdateInfo(Undefined, UpdateInfo);
		Raise;
	EndTry;
	
EndProcedure

// Fills data for the deferred handler in a background job.
//
// Parameters:
//  ProcedureDetails - Structure - details of the filling procedure.
//  ResultAddress - String - an address of the temporary storage for storing the procedure result.
//
Procedure FillDeferredHandlerData(ProcedureDetails, ResultAddress) Export
	
	ProcessingMarkParameters = InfobaseUpdate.MainProcessingMarkParameters();
	DataExchangeSubsystemExists = Common.SubsystemExists("StandardSubsystems.DataExchange");
	
	If DataExchangeSubsystemExists Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.InitializeUpdateDataFile(ProcessingMarkParameters);
	EndIf;
	
	ProcessingMarkParameters.PositionInQueue = ProcedureDetails.PositionInQueue;
	ProcessingMarkParameters.Insert("HandlerData", New Map);
	
	HandlerParameters = New Array;
	HandlerParameters.Add(ProcessingMarkParameters);
	
	MessageTemplate = NStr(
		"ru = 'Выполняется процедура заполнения данных
		|""%1""
		|отложенного обработчика обновления
		|""%2"".'; 
		|en = 'Executing data population procedure
		|%1
		|of deferred update handler
		|%2.'; 
		|pl = 'Jest wykonywana procedura wypełnienia danych
		|""%1""
		|odroczonego programu przetwarzania aktualizacji
		|""%2"".';
		|es_ES = 'Se está realizando el procedimiento de relleno de datos
		|""%1""
		| del procesador aplazado de actualización
		|""%2"".';
		|es_CO = 'Se está realizando el procedimiento de relleno de datos
		|""%1""
		| del procesador aplazado de actualización
		|""%2"".';
		|tr = '"
"%1Ertelenmiş güncelleme işleyicisinin 
		|veri doldurma prosedürü yürütülüyor 
		|%2.';
		|it = 'Eseguendo la procedura di popolazione dati
		|%1
		|del gestore aggiornamento posticipato
		|%2';
		|de = 'Der Vorgang zum Ausfüllen der Daten
		|""%1""
		|des verzögerten Aktualisierungs-Handlers
		|""%2"" wird durchgeführt.'");
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate,
		ProcedureDetails.FillingProcedure,
		ProcedureDetails.HandlerName);
	WriteInformation(MessageText);
	
	Try
		Common.ExecuteConfigurationMethod(ProcedureDetails.FillingProcedure, HandlerParameters);
	Except
		ErrorInformation = DetailErrorDescription(ErrorInfo());
		ErrorTemplate = NStr(
			"ru = 'При вызове процедуры заполнения данных
			|""%1""
			|отложенного обработчика обновления
			|""%2""
			|произошла ошибка:
			|""%3"".'; 
			|en = 'Error while calling data population procedure 
			|%1
			|of deferred update handler
			|%2:
			|%3
			|'; 
			|pl = 'Podczas wywołania procedury wypełnienia danych
			|""%1""
			|odroczonego programu przetwarzania aktualizacji
			|""%2""
			|zaistniał błąd:
			|""%3"".';
			|es_ES = 'Al llamar el procedimiento del relleno de datos
			|""%1""
			| del procesador aplazado de actualización
			|""%2""
			|se ha producido un error:
			|""%3"".';
			|es_CO = 'Al llamar el procedimiento del relleno de datos
			|""%1""
			| del procesador aplazado de actualización
			|""%2""
			|se ha producido un error:
			|""%3"".';
			|tr = 'Ertelenen güncelleştirme işleyicisi "
" %1
			|veri doldurma %3prosedürü çağrıldığında bir 
			|
			|hata oluştu:%2 "
".';
			|it = 'Errore durante la chiamata alla procedura di inserimento dati 
			|%1
			|del gestore di aggiornamenti differiti
			|%2:
			|%3
			|';
			|de = 'Beim Aufrufen der Prozedur zum Füllen der Daten
			|""%1""
			|des verzögerten Aktualisierungs-Handlers
			|""%2""
			|ist ein Fehler aufgetreten:
			|""%3"".'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate,
			ProcedureDetails.FillingProcedure,
			ProcedureDetails.HandlerName,
			ErrorInformation);
		WriteError(MessageText);
		Raise;
	EndTry;
	
	Result = New Structure;
	Result.Insert("HandlerData", ProcessingMarkParameters.HandlerData);
	
	If DataExchangeSubsystemExists Then
		UpdateData = ModuleDataExchangeServer.CompleteWriteFileAndGetUpdateData(ProcessingMarkParameters);
		Result.Insert("UpdateData", UpdateData);
		Result.Insert("NameOfChangedFile", ProcessingMarkParameters.NameOfChangedFile);
	EndIf;
	
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

Procedure SetUpdateHandlerParameters(UpdateHandler, Deferred = False, Parallel = False)
	
	If UpdateHandler = Undefined Then
		SessionParameters.UpdateHandlerParameters = New FixedStructure(NewUpdateHandlerParameters());
		Return;
	EndIf;
	
	If Deferred Then
		ExecutionMode = "Deferred";
		HandlerName = UpdateHandler.HandlerName;
	Else
		ExecutionMode = "Exclusive";
		HandlerName = UpdateHandler.Procedure;
	EndIf;
	
	If Parallel Then
		DeferredHandlerExecutionMode = "Parallel";
	Else
		DeferredHandlerExecutionMode = "Sequentially";
	EndIf;
	
	UpdateHandlerParameters = NewUpdateHandlerParameters();
	UpdateHandlerParameters.ExecuteInMasterNodeOnly = UpdateHandler.ExecuteInMasterNodeOnly;
	UpdateHandlerParameters.RunAlsoInSubordinateDIBNodeWithFilters = UpdateHandler.RunAlsoInSubordinateDIBNodeWithFilters;
	UpdateHandlerParameters.DeferredProcessingQueue = UpdateHandler.DeferredProcessingQueue;
	UpdateHandlerParameters.ExecutionMode = ExecutionMode;
	UpdateHandlerParameters.DeferredHandlerExecutionMode = DeferredHandlerExecutionMode;
	UpdateHandlerParameters.HasProcessedObjects = False;
	UpdateHandlerParameters.HandlerName = HandlerName;
	
	SessionParameters.UpdateHandlerParameters = New FixedStructure(UpdateHandlerParameters);
	
EndProcedure

Function NewUpdateHandlerParameters() Export
	UpdateHandlerParameters = New Structure;
	UpdateHandlerParameters.Insert("ExecuteInMasterNodeOnly", False);
	UpdateHandlerParameters.Insert("RunAlsoInSubordinateDIBNodeWithFilters", False);
	UpdateHandlerParameters.Insert("DeferredProcessingQueue", 0);
	UpdateHandlerParameters.Insert("ExecutionMode", "");
	UpdateHandlerParameters.Insert("DeferredHandlerExecutionMode", "");
	UpdateHandlerParameters.Insert("HasProcessedObjects", False);
	UpdateHandlerParameters.Insert("HandlerName", "");
	
	Return UpdateHandlerParameters;
EndFunction

// Processes an exception that was raised while preparing or completing handler execution in the main thread.
//
// Parameters:
//  HandlerContext - Structure - see NewHandlerContext(). 
//  UpdateHandler - ValueTreeRow - the update handler represented as a row of the handler tree.
//
Procedure ProcessHandlerException(HandlerContext, UpdateHandler, ErrorInformation)
	
	If HandlerContext.WriteToLog Then
		WriteUpdateProgressDetails(HandlerContext.HandlerFullDetails);
	EndIf;
	
	While TransactionActive() Do
		RollbackTransaction();
	EndDo;
	
	UpdateHandler.AttemptCount = UpdateHandler.AttemptCount + 1;
	DetailedErrorPresentation = DetailErrorDescription(ErrorInformation);
	WriteError(DetailedErrorPresentation);
	
	If UpdateHandler.Status <> "Error" Then
		UpdateHandler.Status = "Error";
		UpdateHandler.ErrorInfo = DetailedErrorPresentation;
	EndIf;
	
EndProcedure

// Sets error status for all looped handlers.
//
// Parameters:
//  HandlerTree - ValueTreeRowCollection - top level of the tree.
//
// Returns:
//  Boolean - True if all running handlers are looped (AttemptCount >= 2), False if at least one handler is running normally.
//
Procedure MarkLoopingHandlers(HandlersTree)
	
	Filter = New Structure("Status", "Running");
	Running = HandlersTree.Rows.FindRows(Filter, True);
	
	For each UpdateHandler In Running Do
		If UpdateHandler.AttemptCount >= 2 Then
			UpdateHandler.Status = "Error";
			UpdateHandler.ErrorInfo = NStr("ru = 'Произошло зацикливание процедуры обработки данных. Выполнение прервано.'; en = 'The data processing procedure went into an endless loop and was canceled.'; pl = 'Nastąpiło zapętlenie procedury przetwarzania danych. Wykonanie przerwano.';es_ES = 'El procedimiento del procesamiento de datos ha entrado en ciclo. Realización interrumpida.';es_CO = 'El procedimiento del procesamiento de datos ha entrado en ciclo. Realización interrumpida.';tr = 'Veri işleme prosedürü döngüsü takıldı. Yürütme durduruldu.';it = 'Si è verificato un ciclo di procedure di elaborazione dei dati. Esecuzione interrotta.';de = 'Das Datenverarbeitungsverfahren läuft zyklisch ab. Die Ausführung wird unterbrochen.'");
		EndIf;
	EndDo;
	
EndProcedure

// Checks whether all running handlers are looped.
// Handlers are considered to be looped if any of these conditions are met:
// - All running handlers have attempt count >=2
// - or
// - At least one running handler has attempt count >=2
// - and
// - At least one handler has completed with errors.
//
// Parameters:
//  HandlerTree - ValueTreeRowCollection - top level of the tree.
//
// Returns:
//  Boolean - True if all  handlers are looped.
//
Function AllHandlersLoop(HandlersTree)
	
	Filter = New Structure("Status", "Running");
	Running = HandlersTree.Rows.FindRows(Filter, True);
	
	If Running.Count() > 0 Then
		HasExceeding = False;
		HasNormal = False;
		
		For each UpdateHandler In Running Do
			If UpdateHandler.AttemptCount < 2 Then
				HasNormal = True;
			Else
				HasExceeding = True;
			EndIf;
			
			If HasNormal AND HasExceeding Then
				Break;
			EndIf;
		EndDo;
		
		If HasExceeding Then
			If HasNormal Then
				Filter = New Structure("Status", "Error");
				WithErrors = HandlersTree.Rows.FindRows(Filter, True);
				
				Return WithErrors.Count() > 0;
			Else
				Return True;
			EndIf;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

// Gets the number of times the update procedure was started.
//
// Parameters:
//  UpdateHandler - ValueTreeRow - the update handler represented as a row of the handler tree.
//
// Returns:
//  Number - number of startups.
//
Function UpdateProcedureStartCount(UpdateHandler)
	
	UpdateProcedureStartCount = UpdateHandler.ExecutionStatistics["StartsCount"];
	
	If UpdateProcedureStartCount = Undefined Then
		UpdateProcedureStartCount = 0;
	EndIf;
	
	Return UpdateProcedureStartCount;
	
EndFunction

// Finds the update handler in the handler tree.
//
// Parameters:
//  HandlerTree - ValueTreeRowCollection - top level of the tree.
//  ID - UUID - the unique ID of the update handler.
//  HandlerName - String - the name of the update handler.
//
// Returns:
//  * ValueTreeRow - the found handler.
//  * Undefined - if no handler was found.
//
Function FindHandlerInTree(HandlersTree, ID, HandlerName)
	
	If ValueIsFilled(ID) Then
		UpdateHandler = HandlersTree.Find(ID, "ID", True);
		If UpdateHandler = Undefined Then
			UpdateHandler = HandlersTree.Find(HandlerName, "HandlerName", True);
		EndIf;
	Else
		UpdateHandler = HandlersTree.Find(HandlerName, "HandlerName", True);
	EndIf;
	
	Return UpdateHandler;
	
EndFunction

// Finds the update handler in a value table.
//
// Parameters:
//  HandlerTable - ValueTable - the handler table.
//  ID - UUID - the unique ID of the update handler.
//  HandlerName - String - the name of the update handler.
//
// Returns:
//  * ValueTableRow - the found handler.
//  * Undefined - if no handler was found.
//
Function FindHandlerInTable(HandlersTable, ID, HandlerName)
	
	For each Handler In HandlersTable Do
		If Handler.ID = ID AND Handler.HandlerName = HandlerName Then
			Return Handler;
		EndIf;
	EndDo;
	
EndFunction

#EndRegion