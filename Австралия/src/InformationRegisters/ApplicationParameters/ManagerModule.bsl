#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Checks whether the update or configuration of the infobase is required before you start using it.
// 
//
// Parameters:
//  SubordinateDIBNodeSetup - Boolean - (return value), it is set to True if the update is required 
//                                 due to the subordinate DIB node setup.
//
// Returns:
//  Boolean - returns True, if update or setup of the infobase is required.
//
Function UpdateRequired(SubordinateDIBNodeSetup = False) Export
	
	If Common.DataSeparationEnabled() Then
		// Updating in SaaS.
		If Common.SeparatedDataUsageAvailable() Then
			If InfobaseUpdate.InfobaseUpdateRequired() Then
				// Filling separated extension parameters.
				Return True;
			EndIf;
			
		ElsIf InfobaseUpdateInternal.SharedInfobaseDataUpdateRequired() Then
			// Updating shared application parameters.
			Return True;
		EndIf;
	Else
		// Updating in the local mode.
		If InfobaseUpdate.InfobaseUpdateRequired() Then
			Return True;
		EndIf;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		
		// When starting the created initial image of a subordinate DIB node, no import is required but the 
		// update must be executed.
		If ModuleDataExchangeServer.SubordinateDIBNodeSetup() Then
			SubordinateDIBNodeSetup = True;
			Return True;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

// Calls forced filling of all application parameters.
Procedure UpdateAllApplicationParameters() Export
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	
	UpdateApplicationParameters();
	
EndProcedure

// Returns the date of a successful check or update of application parameters.
Function AllApplicationParametersUpdateDate() Export
	
	ParameterName = "StandardSubsystems.Core.AllApplicationParametersUpdateDate";
	UpdateDate = StandardSubsystemsServer.ApplicationParameter(ParameterName);
	
	If TypeOf(UpdateDate) <> Type("Date") Then
		UpdateDate = '00010101';
	EndIf;
	
	Return UpdateDate;
	
EndFunction


// See StandardSubsystemsServer.ApplicationParameter. 
Function ApplicationParameter(ParameterName) Export
	
	ValueDetails = ApplicationParameterValueDescription(ParameterName);
	
	If StandardSubsystemsServer.ApplicationVersionUpdatedDynamically() Then
		Return ValueDetails.Value;
	EndIf;
	
	If ValueDetails.Version <> Metadata.Version Then
		Value = Undefined;
		CheckIfCanUpdateSaaS(ParameterName, Value, "Get");
		Return Value;
	EndIf;
	
	Return ValueDetails.Value;
	
EndFunction

// See StandardSubsystemsServer.SetApplicationParameter. 
Procedure SetApplicationParameter(ParameterName, Value) Export
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	CheckIfCanUpdateSaaS(ParameterName, Value, "Set");
	
	ValueDetails = New Structure;
	ValueDetails.Insert("Version", Metadata.Version);
	ValueDetails.Insert("Value", Value);
	
	SetApplicationParameterStoredData(ParameterName, ValueDetails);
	
EndProcedure

// See StandardSubsystemsServer.UpdateApplicationParameter. 
Procedure UpdateApplicationParameter(ParameterName, Value, HasChanges = False, PreviousValue = Undefined) Export
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	
	ValueDetails = ApplicationParameterValueDescription(ParameterName, False);
	PreviousValue = ValueDetails.Value;
	
	If Not Common.DataMatch(Value, PreviousValue) Then
		HasChanges = True;
	ElsIf ValueDetails.Version = Metadata.Version Then
		Return;
	EndIf;
	
	SetApplicationParameter(ParameterName, Value);
	
EndProcedure


// See StandardSubsystemsServer.ApplicationParameterChanges. 
Function ApplicationParameterChanges(ParameterName) Export
	
	ChangeStorageParameterName = ParameterName + ":Changes";
	LastChanges = ApplicationParameterStoredData(ChangeStorageParameterName);
	
	Version = Metadata.Version;
	NextVersion = NextVersion(Version);
	
	If Common.DataSeparationEnabled()
	   AND NOT Common.SeparatedDataUsageAvailable() Then
		
		// The area update plan is created only for areas whose versions are not lower then the version of 
		// shared data.
		// For other areas, all update handlers are executed.
		
		// Version of shared (common) data.
		IBVersion = InfobaseUpdateInternal.IBVersion(Metadata.Name, True);
	Else
		IBVersion = InfobaseUpdateInternal.IBVersion(Metadata.Name);
	EndIf;
	
	// In case of initial filling, application parameter changes are not defined.
	If CommonClientServer.CompareVersions(IBVersion, "0.0.0.0") = 0 Then
		Return Undefined;
	EndIf;
	
	UpdateOutsideIBUpdate = CommonClientServer.CompareVersions(IBVersion, Version) = 0;
	
	If Not IsApplicationParameterChanges(LastChanges) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '?????? ?????????????????? ???????????? ?????????????????? ""%1"" ???? ?????????????? ??????????????????.'; en = 'No changes are found for application parameter ""%1.""'; pl = 'Nie znaleziono ??adnych zmian dla parametru pracy programu ""%1"".';es_ES = 'Para el par??metro del funcionamiento del programa ""%1"" no se han encontrado los cambios.';es_CO = 'Para el par??metro del funcionamiento del programa ""%1"" no se han encontrado los cambios.';tr = '""%1"" program??n??n ??al????mas?? i??in herhangi bir de??i??iklik bulunamad??.';it = 'Non sono state trovate modifiche per il parametro di operazione del programma ""%1""';de = 'Es wurden keine ??nderungen f??r den Programmbetriebsparameter ""%1"" gefunden.'"), ParameterName)
			+ StandardSubsystemsServer.ApplicationRunParameterErrorClarificationForDeveloper();
	EndIf;
	
	// Not updating to the higher versions except when updating outside the infobase update, which is 
	// when the infobase version equals the configuration version.
	// 
	// In this case, the changes to the next version are selected as well.
	
	Index = LastChanges.Count()-1;
	While Index >= 0 Do
		RevisionVersion = LastChanges[Index].ConfigurationVersion;
		
		If CommonClientServer.CompareVersions(IBVersion, RevisionVersion) >= 0
		   AND NOT (  UpdateOutsideIBUpdate
		         AND CommonClientServer.CompareVersions(NextVersion, RevisionVersion) = 0) Then
			
			LastChanges.Delete(Index);
		EndIf;
		Index = Index - 1;
	EndDo;
	
	Return LastChanges.UnloadColumn("Changes");
	
EndFunction

// See StandardSubsystemsServer.AddApplicationParameterChanges. 
Procedure AddApplicationParameterChanges(ParameterName, Val Changes) Export
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	
	// Retrieving the infobase or shared data version.
	IBVersion = InfobaseUpdateInternal.IBVersion(Metadata.Name);
	
	// When you migrate to another application, the current configuration version is used.
	If Not Common.DataSeparationEnabled()
	   AND InfobaseUpdateInternal.DataUpdateMode() = "MigrationFromAnotherApplication" Then
		
		IBVersion = Metadata.Version;
	EndIf;
	
	// In case of initial filling, parameter changes are not added.
	If CommonClientServer.CompareVersions(IBVersion, "0.0.0.0") = 0 Then
		Changes = Undefined;
	EndIf;
	
	ChangeStorageParameterName = ParameterName + ":Changes";
	
	Lock = New DataLock;
	LockItem = Lock.Add("InformationRegister.ApplicationParameters");
	LockItem.SetValue("ParameterName", ChangeStorageParameterName);
	
	BeginTransaction();
	Try
		Lock.Lock();
		
		UpdateChangesComposition = False;
		LastChanges = ApplicationParameterStoredData(ChangeStorageParameterName);
		
		If Not IsApplicationParameterChanges(LastChanges) Then
			LastChanges = Undefined;
		EndIf;
		
		If LastChanges = Undefined Then
			UpdateChangesComposition = True;
			LastChanges = New ValueTable;
			LastChanges.Columns.Add("ConfigurationVersion");
			LastChanges.Columns.Add("Changes");
		EndIf;
		
		If ValueIsFilled(Changes) Then
			
			// If there is an update outside the infobase update, add the changes to the next version to keep 
			// these changes when updating the infobase.
			// 
			// 
			Version = Metadata.Version;
			
			UpdateOutsideIBUpdate =
				CommonClientServer.CompareVersions(IBVersion , Version) = 0;
			
			If UpdateOutsideIBUpdate Then
				Version = NextVersion(Version);
			EndIf;
			
			UpdateChangesComposition = True;
			Row = LastChanges.Add();
			Row.Changes          = Changes;
			Row.ConfigurationVersion = Version;
		EndIf;
		
		EarliestIBVersion = InfobaseUpdateInternalCached.EarliestIBVersion();
		
		// Deleting changes for infobase versions earlier than minimum one instead of versions earlier or 
		// equal to the minimum one, to make update outside the infobase update possible.
		// 
		Index = LastChanges.Count()-1;
		While Index >=0 Do
			RevisionVersion = LastChanges[Index].ConfigurationVersion;
			
			If CommonClientServer.CompareVersions(EarliestIBVersion, RevisionVersion) > 0 Then
				LastChanges.Delete(Index);
				UpdateChangesComposition = True;
			EndIf;
			Index = Index - 1;
		EndDo;
		
		If UpdateChangesComposition Then
			CheckIfCanUpdateSaaS(ParameterName, Changes, "AddChanges");
			SetApplicationParameterStoredData(ChangeStorageParameterName,
				LastChanges);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure


// This method is required for call from the ExecuteInfobaseUpdate procedure.
Procedure ImportUpdateApplicationParameters() Export
	
	If Common.DataSeparationEnabled()
	   AND Common.SeparatedDataUsageAvailable() Then
		
		ProcessExtensionBersionParameters();
		Return;
	EndIf;
	
	If ValueIsFilled(SessionParameters.AttachedExtensions)
	   AND Not UpdateWithoutBackgroundJob() Then
		
		// Starting background job.
		Result = ImportUpdateApplicationParametersInBackground(Undefined, Undefined, False);
		ProcessedResult = ProcessedTimeConsumingOperationResult(Result);
		
		If ValueIsFilled(ProcessedResult.BriefErrorPresentation) Then
			Raise ProcessedResult.DetailedErrorPresentation;
		EndIf;
	Else
		ImportUpdateApplicationParametersIncludingRunMode(False);
		ProcessExtensionBersionParameters(); // It is called above on result processing.
	EndIf;
	
EndProcedure

// This is required to call from the InfobaseUpdateProgressIndicator form.
Function ImportUpdateApplicationParametersInBackground(WaitForCompletion, FormID, ReportProgress) Export
	
	OperationParameters = TimeConsumingOperations.BackgroundExecutionParameters(FormID);
	OperationParameters.BackgroundJobDescription = NStr("ru = '?????????????? ???????????????????? ???????????????????? ???????????? ??????????????????'; en = 'Update application parameters in background'; pl = 'Aktualizacja w tle parametr??w pracy aplikacji';es_ES = 'Actualizaci??n de fondo de los par??metros de la aplicaci??n';es_CO = 'Actualizaci??n de fondo de los par??metros de la aplicaci??n';tr = 'Uygulama parametrelerini arka planda g??ncelle';it = 'Aggiornamento in background dei parametri del programma';de = 'Hintergrundaktualisierung der Anwendungsparameter'");
	OperationParameters.WaitForCompletion = WaitForCompletion;
	OperationParameters.NoExtensions = True;
	
	If CommonClientServer.DebugMode()
	   AND Not ValueIsFilled(SessionParameters.AttachedExtensions) Then
		ReportProgress = False;
	EndIf;
	
	If Not CanExecuteBackgroundJobs() Then
		Raise
			NStr("ru = '???????????????????? ???????????????????? ???????????? ?????????????????? ???? ?????????? ???????? ??????????????????,
			           |??.??. ???????????????????? ???????????????????? ????????????????????????, ???????????????????????????? ?????????? ?? ?????????? ????????????????????????.
			           |?????? ???????????????????? ???????????????????? ???????????????????? ?????????????????? ?????????? ????????????????????.'; 
			           |en = 'Cannot update the application parameters
			           |because configuration extensions that modify rights in configuration roles are attached.
			           |Detach these extensions before performing the update.'; 
			           |pl = 'Aktualizacja parametr??w pracy programu nie mo??e by?? wykonana,
			           |poniewa?? s?? po????czone rozszerzenia konfiguracji, modyfikuj??ce prawa w rolach konfiguracji.
			           |Aby wykona?? aktualizacj??, musisz od????czy?? te rozszerzenia.';
			           |es_ES = 'La actualizaci??n de los par??metros del funcionamiento del programa,
			           |porque est??n conectadas las extensiones de la configuraci??n que modifican los derechos en los roles de configuraci??n.
			           |Para actualizar es necesario desactivar estas extensiones.';
			           |es_CO = 'La actualizaci??n de los par??metros del funcionamiento del programa,
			           |porque est??n conectadas las extensiones de la configuraci??n que modifican los derechos en los roles de configuraci??n.
			           |Para actualizar es necesario desactivar estas extensiones.';
			           |tr = 'Yap??land??rma rol??ndeki haklar?? de??i??tiren yap??land??rma uzant??lar?? ba??l?? oldu??undan, 
			           |program??n ??al????ma ayarlar??n?? g??ncelleyemezsiniz.
			           | G??ncellemeyi ger??ekle??tirmek i??in bu uzant??lar?? devre d?????? b??rakman??z gerekir.';
			           |it = 'Impossibile aggiornare i parametri dell''applicazione
			           |perch?? le estensioni della configurazioni che modificano i diritti nei ruoli di configurazione sono collegate.
			           |Scollega le estensioni prima di eseguire l''aggiornamento.';
			           |de = 'Die Aktualisierung der Programmbetriebsparameter kann nicht durchgef??hrt werden,
			           |da die Konfigurationserweiterungen, die die Rechte in den Konfigurationsrollen ??ndern, verbunden sind.
			           |Um das Update durchzuf??hren, m??ssen Sie diese Erweiterungen deaktivieren.'");
	EndIf;
	
	Return TimeConsumingOperations.ExecuteInBackground(
		"InformationRegisters.ApplicationParameters.UpdateDownloadTimeConsumingOperationHandler",
		ReportProgress,
		OperationParameters);
	
EndFunction

// This is required to call from the InfobaseUpdateProgressIndicator form.
Function ProcessedTimeConsumingOperationResult(Result) Export
	
	BriefErrorPresentation   = Undefined;
	DetailedErrorPresentation = Undefined;
	
	If Result = Undefined Or Result.Status = "Canceled" Then
		
		BriefErrorPresentation =
			NStr("ru = '???? ?????????????? ???????????????? ?????????????????? ???????????? ?????????????????? ???? ??????????????:
			           |?????????????? ??????????????, ?????????????????????? ???????????????????? ????????????????.'; 
			           |en = 'Cannot update application parameters. Reason:
			           |The update background job is canceled.'; 
			           |pl = 'Nie uda??o si?? zaktualizowa?? parametr??w pracy programu z powodu:
			           |Zadanie w tle, kt??re wykonuje aktualizacj??, zosta??o anulowane.';
			           |es_ES = 'No se ha podido actualizar los par??metros del funcionamiento a causa de:
			           |La tarea del fondo que realizaba la actualizaci??n ha sido cancelada.';
			           |es_CO = 'No se ha podido actualizar los par??metros del funcionamiento a causa de:
			           |La tarea del fondo que realizaba la actualizaci??n ha sido cancelada.';
			           |tr = 'Uygulama parametreleri g??ncellenemedi. Nedeni:
			           |G??ncelleme arka plan i??i iptal edildi.';
			           |it = 'Impossibile aggiornare i parametri di funzionamento del programma a causa di:
			           | Il processo in background che esegue l''aggiornamento ?? stato annullato.';
			           |de = 'Die Parameter des Programms konnten nicht aktualisiert werden, da:
			           |Der Hintergrundjob, der die Aktualisierung durchf??hrte, wurde abgebrochen.'");
		
	ElsIf Result.Status = "Completed" Then
		ExecutionResult = GetFromTempStorage(Result.ResultAddress);
		
		If TypeOf(ExecutionResult) = Type("Structure") Then
			BriefErrorPresentation   = ExecutionResult.BriefErrorPresentation;
			DetailedErrorPresentation = ExecutionResult.DetailedErrorPresentation;
		Else
			BriefErrorPresentation =
				NStr("ru = '???? ?????????????? ???????????????? ?????????????????? ???????????? ?????????????????? ???? ??????????????:
				           |?????????????? ??????????????, ?????????????????????? ???????????????????? ???? ?????????????? ??????????????????.'; 
				           |en = 'Cannot update application parameters. Reason:
				           |The update background job did not return the result.'; 
				           |pl = 'Nie uda??o si?? zaktualizowa?? parametr??w pracy programu z powodu:
				           |Zadanie w tle, kt??re wykonuje aktualizacj??, nie zwr??ci??o wyniku.';
				           |es_ES = 'No se ha podido actualizar los par??metros del funcionamiento a causa de:
				           |La tarea del fondo que realizaba la actualizaci??n no ha devuelto el resultado.';
				           |es_CO = 'No se ha podido actualizar los par??metros del funcionamiento a causa de:
				           |La tarea del fondo que realizaba la actualizaci??n no ha devuelto el resultado.';
				           |tr = 'Uygulama parametreleri g??ncellenemedi. Nedeni:
				           |G??ncelleme arka plan i??i sonu?? vermedi.';
				           |it = 'Impossibile aggiornare i parametri dell''applicazione. Motivo:
				           |Il processo in backgroud di aggiornamento non ha restituito il risultato.';
				           |de = 'Die Parameter des Programms konnten nicht aktualisiert werden, da:
				           |Der Hintergrundjob, der die Aktualisierung durchf??hrte, hat das Ergebnis nicht zur??ckgegeben.'");
		EndIf;
	ElsIf Result.Status <> "StartupNotRequired" Then
		// Background job error.
		BriefErrorPresentation   = Result.BriefErrorPresentation;
		DetailedErrorPresentation = Result.DetailedErrorPresentation;
	EndIf;
	
	If Not ValueIsFilled(DetailedErrorPresentation)
	   AND    ValueIsFilled(BriefErrorPresentation) Then
		
		DetailedErrorPresentation = BriefErrorPresentation;
	EndIf;
	
	If Not ValueIsFilled(BriefErrorPresentation)
	   AND    ValueIsFilled(DetailedErrorPresentation) Then
		
		BriefErrorPresentation = DetailedErrorPresentation;
	EndIf;
	
	ProcessedResult = New Structure;
	ProcessedResult.Insert("BriefErrorPresentation",   BriefErrorPresentation);
	ProcessedResult.Insert("DetailedErrorPresentation", DetailedErrorPresentation);
	
	If Not ValueIsFilled(BriefErrorPresentation) Then
		ProcessExtensionBersionParameters();
	EndIf;
	
	Return ProcessedResult;
	
EndFunction

#EndRegion

#Region Private

// To call from the background job without attached configuration extensions.
Procedure UpdateDownloadTimeConsumingOperationHandler(ReportProgress, StorageAddress) Export
	
	ExecutionResult = New Structure;
	ExecutionResult.Insert("BriefErrorPresentation",   Undefined);
	ExecutionResult.Insert("DetailedErrorPresentation", Undefined);
	
	Try
		ImportUpdateApplicationParametersIncludingRunMode(ReportProgress);
	Except
		ErrorInformation = ErrorInfo();
		ExecutionResult.BriefErrorPresentation   = BriefErrorDescription(ErrorInformation);
		ExecutionResult.DetailedErrorPresentation = DetailErrorDescription(ErrorInformation);
		// Preparing to open the form for data resynchronization before startup with two options, 
		// "Synchronize and continue" and "Continue".
		If Common.SubsystemExists("StandardSubsystems.DataExchange")
		   AND Common.IsSubordinateDIBNode() Then
			ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
			ModuleDataExchangeServer.EnableDataExchangeMessageImportRecurrenceBeforeStart();
		EndIf;
	EndTry;
	
	PutToTempStorage(ExecutionResult, StorageAddress);
	
EndProcedure

Procedure ImportUpdateApplicationParametersIncludingRunMode(ReportProgress)

	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	
	If ValueIsFilled(SessionParameters.AttachedExtensions)
	   AND Not UpdateWithoutBackgroundJob() Then
		Raise
			NStr("ru = '???? ?????????????? ???????????????? ?????????????????? ???????????? ?????????????????? ???? ??????????????:
			           |?????????????? ???????????????????????? ???????????????????? ????????????????????????.'; 
			           |en = 'Cannot update application parameters. Reason:
			           |Attached configuration extensions are found.'; 
			           |pl = 'Nie uda??o si?? zaktualizowa?? parametr??w pracy programu z powodu:
			           |Znaleziono po????czone rozszerzenia konfiguracji.';
			           |es_ES = 'No se ha podido actualizar los par??metros del funcionamiento a causa de:
			           |Se han encontrado las extensiones conectadas de la configuraci??n.';
			           |es_CO = 'No se ha podido actualizar los par??metros del funcionamiento a causa de:
			           |Se han encontrado las extensiones conectadas de la configuraci??n.';
			           |tr = 'Bir nedenle program ayarlar??n?? g??ncelle??tirilemedi: 
			           |Ba??l?? yap??land??rma uzant??lar?? bulundu.';
			           |it = 'Impossibile aggiornare i parametri di funzionamento del programma a causa di:
			           | Trovate estensioni di configurazione.';
			           |de = 'Die Parameter des Programms konnten nicht aktualisiert werden, da:
			           |Verbundene Konfigurationserweiterungen gefunden.'");
	EndIf;
	
	If Common.DataSeparationEnabled()
	   AND Common.SeparatedDataUsageAvailable() Then
		Raise
			NStr("ru = '???? ?????????????? ???????????????? ?????????????????? ???????????? ?????????????????? ???? ??????????????:
			           |???????????????????? ???????????????????? ?????????????????? ?? ?????????????? ????????????.'; 
			           |en = 'Cannot update application parameters. Reason:
			           |Cannot perform the update in the data area.'; 
			           |pl = 'Nie uda??o si?? zaktualizowa?? parametr??w pracy programu z powodu:
			           |Aktualizacji nie mo??na wykona?? w obszarze danych.';
			           |es_ES = 'No se ha podido actualizar los par??metros del funcionamiento a causa de:
			           |Es imposible actualizar en el ??rea de datos.';
			           |es_CO = 'No se ha podido actualizar los par??metros del funcionamiento a causa de:
			           |Es imposible actualizar en el ??rea de datos.';
			           |tr = 'Uygulama parametreleri g??ncellenemiyor. Nedeni:
			           |Veri alan??nda g??ncelleme yap??lam??yor.';
			           |it = 'Impossibile aggiornare i parametri di funzionamento del programma a causa di
			           |: L''aggiornamento non pu?? essere eseguito nell''area dati.';
			           |de = 'Die Parameter des Programms konnten nicht aktualisiert werden, da:
			           |Die Aktualisierung im Datenbereich kann nicht durchgef??hrt werden.'");
	EndIf;
	
	SubordinateDIBNodeSetup = False;
	If Not UpdateRequired(SubordinateDIBNodeSetup) Then
		Return;
	EndIf;
	
	ModulePerformanceMonitor = Undefined;
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		StartTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	SetPrivilegedMode(True);
	If Common.IsSubordinateDIBNode() Then
		// There are a DIB data exchange and an update in the subordinate node.
		
		If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
			ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		EndIf;
		
		If Not SubordinateDIBNodeSetup Then
			
			StandardProcessing = True;
			CommonOverridable.BeforeImportPriorityDataInSubordinateDIBNode(
				StandardProcessing);
			
			If StandardProcessing = True
			   AND Common.SubsystemExists("StandardSubsystems.DataExchange") Then
				
				// Importing predefined items and metadata object IDs from the master node.
				ModuleDataExchangeServer.ImportPriorityDataToSubordinateDIBNode();
			EndIf;
			
			If ReportProgress Then
				TimeConsumingOperations.ReportProgress(5);
			EndIf;
		EndIf;
		
		// Checking metadata object ID import from the master node.
		ListOfCriticalChanges = "";
		Try
			Catalogs.MetadataObjectIDs.RunDataUpdate(False, False, True, , ListOfCriticalChanges);
		Except
			// Preparing to open the form for data resynchronization before startup with one option, 
			// "Synchronize and continue".
			If Not SubordinateDIBNodeSetup
			   AND Common.SubsystemExists("StandardSubsystems.DataExchange") Then
				ModuleDataExchangeServer.EnableDataExchangeMessageImportRecurrenceBeforeStart();
			EndIf;
			Raise;
		EndTry;
		
		If ValueIsFilled(ListOfCriticalChanges) Then
			
			EventName = NStr("ru = '???????????????????????????? ???????????????? ????????????????????.?????????????????? ?????????????????? ?????????????????? ??????????????????'; en = 'Metadata object IDs.Import of critical changes required'; pl = 'Identyfikator obiektu IDs.Importuj krytyczne zmiany';es_ES = 'Identificadores de objetos de metadatos.Importar los cambios cr??ticos';es_CO = 'Identificadores de objetos de metadatos.Importar los cambios cr??ticos';tr = 'Meta veri nesne kimlikleri. Kritik de??i??iklikleri i??e aktar';it = 'Identificatori degli oggetti dei metadati. ?? necessario caricare modifiche critiche';de = 'Metadatenobjekt-IDs. Importieren Sie wichtige ??nderungen'",
				CommonClientServer.DefaultLanguageCode());
			
			WriteLogEvent(EventName, EventLogLevel.Error, , , ListOfCriticalChanges);
			
			// Preparing to open the form for data resynchronization before startup with one option, 
			// "Synchronize and continue".
			If Not SubordinateDIBNodeSetup
			   AND Common.SubsystemExists("StandardSubsystems.DataExchange") Then
				ModuleDataExchangeServer.EnableDataExchangeMessageImportRecurrenceBeforeStart();
			EndIf;
			
			ErrorText =
				NStr("ru = '???????????????????????????? ???????? ???? ?????????? ???????? ?????????????????? ????-???? ???????????????? ?? ?????????????? ????????:
				           |- ?????????????? ???????? ?????? ?????????????????????? ???????????????? (???????????????? ???? ?????? ???????????????? ?????????? ???????????? ????????????????????????,
				           |  ????-???? ???????? ???? ???????????????????? ???????????????????? ???????????????????????????? ???????????????? ????????????????????);
				           |- ???????? ???????? ???????????????? ?? ???????????????? ???????????????????????? ???????????? (????????????????
				           |  ?????????????????????? ???????????????????????????? ???????????????? ????????????????????).
				           |
				           |???????????????????? ???????????? ?????????????????? ???????????????????? ???????????????? ????????, ???????????????????????????????? ?? ????????????????
				           |???????????????????????? ???????????? ?? ?????????????????? ?????????????????????????? ????????????:
				           |- ?? ?????????????? ???????? ?????????????????? ?????????????????? ?? ???????????????????? /C StartInfobaseUpdate;
				           |%1'; 
				           |en = 'The infobase cannot be updated. Possible reasons:
				           |- The master node was updated incorrectly (the configuration version number might not be incremented),
				           |  therefore, the ""Metadata object IDs"" catalog was not populated).
				           |- Export of priority data (items of ""Metadata object IDs"" catalog)
				           |was canceled in the master node.
				           |
				           |Update the master node again, register priority data for export,
				           |and repeat data synchronization:
				           |- In the master node, run the application with /C StartInfobaseUpdate command-line option.
				           |%1'; 
				           |pl = 'Nie mo??na zaktualizowa?? bazy informacyjnej.Mo??liwy pow??d:
				           |- g????wny w??ze?? zosta?? niepoprawnie zaktualizowany (prawdopodobnie nie zosta?? zwi??kszony numer wersji konfiguracji,
				           | przez co nie zosta?? wype??niony katalog ""Identyfikatory obiekt??w metadanych"");
				           |- Dane priorytetowe do wyeksportowania zosta??y anulowane (elementy
				           | katalogu Identyfikatory obiekt??w metadanych).
				           |
				           |Nale??y ponownie wykona?? aktualizacj?? g????wnego w??z??a, zarejestrowa?? do wyeksportowania
				           |dane priorytetowe i powt??rzy?? synchronizacj?? danych:
				           |- w g????wnym w????le nale??y uruchomi?? program z parametrem /C Uruchomi??Aktualizacj??BazyInformacyjnej;
				           |%1';
				           |es_ES = 'La base de informaci??n no puede ser actualizada a causa del problema en el nodo principal:
				           |- el nodo principal ha sido actualizado incorrectamente (es posible que no haya sido aumentado el n??mero de la versi??n de la configuraci??n,
				           |as?? que no se ha rellenado el cat??logo Identificadores de los objetos de metadatos);
				           |- o han sido cancelados los datos prioritarios para subir (elementos
				           | del cat??logo Identificadores de los objetos de metadatos).
				           |
				           |Es necesario volver a actualizar el nodo principal, registrar para la subida
				           | los datos prioritarios y volver a sincronizar los datos:
				           |- en el nodo principal lance el programa con el par??metro /C StartInfobaseUpdate;
				           |%1';
				           |es_CO = 'La base de informaci??n no puede ser actualizada a causa del problema en el nodo principal:
				           |- el nodo principal ha sido actualizado incorrectamente (es posible que no haya sido aumentado el n??mero de la versi??n de la configuraci??n,
				           |as?? que no se ha rellenado el cat??logo Identificadores de los objetos de metadatos);
				           |- o han sido cancelados los datos prioritarios para subir (elementos
				           | del cat??logo Identificadores de los objetos de metadatos).
				           |
				           |Es necesario volver a actualizar el nodo principal, registrar para la subida
				           | los datos prioritarios y volver a sincronizar los datos:
				           |- en el nodo principal lance el programa con el par??metro /C StartInfobaseUpdate;
				           |%1';
				           |tr = 'Veri taban??, ana ??nitedeki sorun nedeniyle g??ncellenemez: 
				           |- ana ??nite yanl???? g??ncelle??tirildi (yap??land??rma s??r??m numaras??n?? art??rmam???? olabilir, 
				           |????nk?? meta veri nesne tan??mlay??c??lar?? dizini doldurulmam???? olabilir); - 
				           |veya ??ncelikli verilerin (meta veri nesne tan??mlay??c??lar?? 
				           |????eleri) bo??alt??lmas?? iptal edildi. 
				           |
				           |Ana ??nite yeniden g??ncelle??tirilmeli, ??ncelikli veriler d????a aktar??lmak ??zere kaydedilmeli ve veri senkronizasyonu tekrarlanmal??d??r: 
				           |- ana ??nitede, /C VeriTaban??G??ncellemesini??al????t??r parametresiyle uygulamay?? ??al????t??r??n;
				           |
				           |%1';
				           |it = 'L''infobase non pu?? essere aggiornata a causa di un problema nel nodo principale:
				           | - il nodo principale ?? stato aggiornato in modo errato (il numero di versione della configurazione probabilmente non ?? aumentato,
				           | la directory non ha riempito gli identificatori degli oggetti dei metadati);
				           |
				           | oppure elementi di directory Identificatori di oggetti di metadati)
				           |
				           |. ?? necessario eseguire nuovamente l''aggiornamento del nodo principale, registrare i dati di priorit?? per lo scarico 
				           | e ripetere la sincronizzazione dei dati:
				           | - nel nodo principale, eseguire il programma con il parametro LanciaAggiornamentoDatabase;
				           |%1';
				           |de = 'Die Informationsbasis kann aufgrund eines Problems im Hauptknoten nicht aktualisiert werden:
				           |- Der Hauptknoten wurde falsch aktualisiert (die Nummer der Konfigurationsversion wurde m??glicherweise nicht erh??ht,
				           |weshalb das Verzeichnis ""Metadaten Objekt ID"" nicht ausgef??llt wurde);
				           |- oder Priorit??tsdaten (Elemente des
				           |Verzeichnisses ""Metadaten Objekt ID"") wurden zum Hochladen gel??scht.
				           |
				           |Es ist notwendig, den Hauptknoten zu aktualisieren, sich f??r das Hochladen
				           |der Priorit??tsdaten zu registrieren und die Synchronisation der Daten zu wiederholen:
				           |- im Hauptknoten starten Sie das Programm mit dem Parameter /C StartInfobaseUpdate.
				           |%1'");
			
			If SubordinateDIBNodeSetup Then
				// Setting up a subordinate DIB node during the first start.
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText,
					NStr("ru = '- ?????????? ?????????????????? ???????????????? ???????????????????????? ????????.'; en = '- Then retry creating a subordinate node.'; pl = '- nast??pnie powt??rz tworzenie w??z??a podrz??dnego.';es_ES = '- despu??s vuelva a crear el nodo principal.';es_CO = '- despu??s vuelva a crear el nodo principal.';tr = '- sonra alt ??niteyi tekrar olu??turun.';it = '- quindi ripetere la creazione del nodo subordinato.';de = '- wiederholen Sie dann das Erstellen des Slave-Knotens.'"));
			Else
				// Updating a subordinate DIB node.
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText,
					NStr("ru = '- ?????????? ?????????????????? ?????????????????????????? ???????????? ?? ???????? ???????????????????????????? ??????????
					           | (?????????????? ?? ?????????????? ????????, ?????????? ?? ???????? ???????????????????????????? ???????? ?????????? ??????????????????????).'; 
					           |en = '- Then repeat data synchronization with this infobase: 
					           | first in the master node, then in the infobase (restart the infobase before the synchronization).'; 
					           |pl = '- nast??pnie powt??rz synchronizacj?? danych z t?? baz?? informacji
					           | (najpierw w g????wnym w????le, a nast??pnie w tej bazie informacyjnej po ponownym uruchomieniu).';
					           |es_ES = '- despu??s vuelva a sincronizar los datos con esta base de informaci??n
					           | (al principio en el nodo principal, despu??s en esta base de informaci??n al reiniciar).';
					           |es_CO = '- despu??s vuelva a sincronizar los datos con esta base de informaci??n
					           | (al principio en el nodo principal, despu??s en esta base de informaci??n al reiniciar).';
					           |tr = '- ard??ndan, verileri bu veritaban??yla yeniden senkronize edin
					           | (ilk ??nce ana ??nitede, daha sonra yeniden ba??lat??ld??ktan sonra bu veritaban??nda).';
					           |it = '- quindi ripetere la sincronizzazione dei dati con questo database 
					           |(prima nel nodo principale, quindi in questo database dopo il riavvio).';
					           |de = '- wiederholen Sie dann die Synchronisation mit dieser Datenbank
					           |(zuerst im Hauptknoten, dann in dieser Datenbank nach dem Neustart).'"));
			EndIf;
			
			Raise ErrorText;
		EndIf;
		If ReportProgress Then
			TimeConsumingOperations.ReportProgress(10);
		EndIf;
	EndIf;
	
	// No DIB data exchange or master infobase node update or initial subordinate node update or update 
	// after importing the Metadata object IDs catalog from the master node.
	// 
	// 
	UpdateApplicationParameters(ReportProgress);
	
	If ModulePerformanceMonitor <> Undefined Then
		ModulePerformanceMonitor.EndTimeMeasurement("MetadataCacheUpdateTime", StartTime);
	EndIf;
	
EndProcedure

Procedure ProcessExtensionBersionParameters()
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	ClientLaunchParameter = SessionParameters.ClientParametersAtServer.Get("LaunchParameter");
	SetPrivilegedMode(False);
	If StrFind(Lower(ClientLaunchParameter), Lower("StartInfobaseUpdate")) > 0 Then
		InformationRegisters.ExtensionVersionParameters.ClearAllExtensionParameters();
	EndIf;
	
	InformationRegisters.ExtensionVersionParameters.FillAllExtensionParameters();
	
EndProcedure

// This method is required by ApplicationParameterChanges function.
Function NextVersion(Version)
	
	Array = StrSplit(Version, ".");
	
	Return CommonClientServer.ConfigurationVersionWithoutBuildNumber(
		Version) + "." + Format(Number(Array[3]) + 1, "NG=");
	
EndFunction

// This method is required by ImportUpdateApplicationParameters and UpdateAllApplicationParameters procedures.
Procedure UpdateApplicationParameters(ReportProgress = False)
	
	If ReportProgress Then
		TimeConsumingOperations.ReportProgress(30);
	EndIf;
	
	If Not StandardSubsystemsCached.DisableMetadataObjectsIDs() Then
		Catalogs.MetadataObjectIDs.RunDataUpdate(False, False, False);
	EndIf;
	If ReportProgress Then
		TimeConsumingOperations.ReportProgress(60);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.UpdateAccessRestrictionParameters();
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternal = Common.CommonModule("AccountingAuditInternal");
		ModuleAccountingAuditInternal.UpdateAccountingChecksParameters();
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.UpdateDataExchangeRules();
	EndIf;
	
	If ReportProgress Then
		TimeConsumingOperations.ReportProgress(100);
	EndIf;
	
	ParameterName = "StandardSubsystems.Core.AllApplicationParametersUpdateDate";
	StandardSubsystemsServer.SetApplicationParameter(ParameterName, CurrentSessionDate());
	
	If Common.SeparatedDataUsageAvailable()
	   AND Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.SetAccessUpdate(True);
	EndIf;
	
EndProcedure

// This method is required by ApplicationParameter function and UpdateApplicationParameter procedure.
Function ApplicationParameterValueDescription(ParameterName, CheckIfCanUpdateSaaS = True)
	
	ValueDetails = ApplicationParameterStoredData(ParameterName);
	
	If TypeOf(ValueDetails) <> Type("Structure")
	 Or ValueDetails.Count() <> 2
	 Or Not ValueDetails.Property("Version")
	 Or Not ValueDetails.Property("Value") Then
		
		If StandardSubsystemsServer.ApplicationVersionUpdatedDynamically() Then
			StandardSubsystemsServer.RequireRestartDueToApplicationVersionDynamicUpdate();
		EndIf;
		ValueDetails = New Structure("Version, Value");
		If CheckIfCanUpdateSaaS Then
			CheckIfCanUpdateSaaS(ParameterName, Null, "Get");
		EndIf;
	EndIf;
	
	Return ValueDetails;
	
EndFunction

// This is required for the ApplicationParameterValueDetails, ApplicationParameterChanges functions 
// and the AddApplicationParameterChanges procedures.
//
Function ApplicationParameterStoredData(ParameterName)
	
	Query = New Query;
	Query.SetParameter("ParameterName", ParameterName);
	Query.Text =
	"SELECT
	|	ApplicationParameters.ParameterStorage
	|FROM
	|	InformationRegister.ApplicationParameters AS ApplicationParameters
	|WHERE
	|	ApplicationParameters.ParameterName = &ParameterName";
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.ParameterStorage.Get();
	EndIf;
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
	Return Undefined;
	
EndFunction

// This method is required by SetApplicationParameter and AddApplicationParameterChanges procedures.
Procedure SetApplicationParameterStoredData(ParameterName, StoredData)
	
	RecordSet = CreateRecordSet();
	RecordSet.Filter.ParameterName.Set(ParameterName);
	
	NewRecord = RecordSet.Add();
	NewRecord.ParameterName       = ParameterName;
	NewRecord.ParameterStorage = New ValueStorage(StoredData);
	
	InfobaseUpdate.WriteRecordSet(RecordSet, , False, False);
	
EndProcedure

Procedure CheckIfCanUpdateSaaS(ParameterName, NewValue, Operation)
	
	If Not Common.DataSeparationEnabled()
	 Or Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	// Writing the error context to the event log for the service administrator.
	ValueDetails = ApplicationParameterStoredData(ParameterName);
	
	ChangeStorageParameterName = ParameterName + ":Changes";
	LastChanges = ApplicationParameterStoredData(ChangeStorageParameterName);
	
	EventName = NStr("ru = '?????????????????? ???????????? ??????????????????.???? ?????????????????? ???????????????????? ?? ?????????????????????????? ????????????'; en = 'Application parameters.Not updated in shared mode'; pl = 'Parametry pracy programu. Brak aktualizacji w trybie nierozdzielonym';es_ES = 'Par??metros del uso del programa.No se ha realizado la actualizaci??n en el modo no distribuido';es_CO = 'Par??metros del uso del programa.No se ha realizado la actualizaci??n en el modo no distribuido';tr = 'Uygulama parametreleri. B??l??nmemi?? modda g??ncelleme yap??lmad??';it = 'Parametri del programma L''aggiornamento non viene eseguito in modalit?? non suddivisa';de = 'Parameter des Programmablaufs. Die Aktualisierung wird nicht im ungeteilten Modus durchgef??hrt'",
		CommonClientServer.DefaultLanguageCode());
	
	Comment =
		NStr("ru = '1. ?????????????????? ?????????????????? ?? ?????????????????????? ??????????????????.
		           |2. ?????????????????????? ?????????????????? ???????????????? ????????????????????????????. ?????? ??????????
		           |?????????????????? ?????????????????? ?? ???????????????????? ?????????????????? ???????????? 1??:?????????????????????? 8
		           |""/?? StartInfobaseUpdate"" ???? ?????????? ????????????????????????
		           |?? ?????????????? ???????????????????????????? ??????????????, ???? ???????? ?? ?????????????????????????? ????????????.
		           |
		           |???????????????? ???? ???????????????????? ??????????????????:'; 
		           |en = '1. Send the message to the technical support.
		           |2. Attempt to resolve the issue manually: run the application
		           |with /C StartInfobaseUpdate command-line option
		           |on behalf of a user with service administrator rights
		           |(in shared mode).
		           |
		           |Invalid application parameter:'; 
		           |pl = '1. Przeka?? wiadomo???? do dzia??u pomocy technicznej.
		           |2. Spr??buj rozwi??za?? problem samodzielnie. Aby to zrobi??
		           |, uruchom program za pomoc?? parametru wiersza polece?? 1C: Enterprise 8
		           |""/C StartInfobaseUpdate "" w imieniu u??ytkownika
		           |z uprawnieniami administratora us??ugi, czyli w trybie bez partycji. 
		           |
		           |Informacja o parametrze problemu:';
		           |es_ES = '1. Reenv??e el mensaje al soporte t??cnico.
		           |2. Prueba de solucionar el problema por su cuenta. Para hacerlo
		           | lance el programa con el par??metro de la l??nea de comando de 1C:Enterprise 8
		           |/C StartInfobaseUpdate del nombre de usuario
		           |con los derechos de administrador del servicio, es decir, en el modo no distribuido.
		           |
		           |Informaci??n del par??metro de dificultad:';
		           |es_CO = '1. Reenv??e el mensaje al soporte t??cnico.
		           |2. Prueba de solucionar el problema por su cuenta. Para hacerlo
		           | lance el programa con el par??metro de la l??nea de comando de 1C:Enterprise 8
		           |/C StartInfobaseUpdate del nombre de usuario
		           |con los derechos de administrador del servicio, es decir, en el modo no distribuido.
		           |
		           |Informaci??n del par??metro de dificultad:';
		           |tr = '1. Teknik deste??e bir mesaj g??nderin. 
		           |2. Sorunu kendiniz d??zeltmeye ??al??????n. Bunu yapmak i??in, 1C:????letme 8
		           |""/S VeriTaban??G??ncellemesiniBa??lat"" komut sat??r?? se??ene??i ile program?? y??netici ayr??cal??klar?? olan kullan??c?? ad??na"", yani kar????l??ks??z modda ??al????t??r??n. 
		           |
		           |
		           |Sorunlu parametre bilgileri:
		           |';
		           |it = '1. Inoltrare il messaggio al supporto tecnico.
		           |2. Prova a risolvere il problema da soli. Per fare ci??,
		           | eseguire il programma con il parametro della riga di comando 1C: Enterprise 8 
		           |""/ ?? LanciaAggiornamentoDatabase"" per conto dell''utente 
		           | con i diritti dell''amministratore del servizio, ovvero in modalit?? non partizionata.
		           |
		           | Informazioni sui parametri del problema:';
		           |de = '1. Leiten Sie die Nachricht an den technischen Support weiter.
		           |2. Versuchen Sie, das Problem selbst zu beheben. F??hren Sie dazu
		           |das Programm mit dem Befehlszeilenparameter 1C:Enterprise 8
		           |""/ C StartInfobaseUpdate"" im Namen des Benutzers
		           |mit Serviceadministrator-Rechten aus, d.h. im nicht partitionierten Modus.
		           |
		           |Informationen ??ber den Problemparameter:'");

	Comment = Comment + Chars.LF +
	"MetadataVersion = " + Metadata.Version + "
	|ParameterName = " + ParameterName + "
	|Operation = " + Operation + "
	|ValueDetails =
	|" + XMLString(New ValueStorage(ValueDetails)) + "
	|NewValue =
	|" + XMLString(New ValueStorage(NewValue)) + "
	|LastChanges =
	|" + XMLString(New ValueStorage(LastChanges));
	
	WriteLogEvent(EventName, EventLogLevel.Error,,, Comment);
	
	// Exception for a user.
	ErrorText =
		NStr("ru = '?????????????????? ???????????? ?????????????????? ???? ?????????????????? ?? ?????????????????????????? ????????????.
		           |???????????????????? ?? ???????????????????????????? ??????????????. ?????????????????????? ?? ?????????????? ??????????????????????.'; 
		           |en = 'The application parameters are not updated in shared mode.
		           |Please contact the service administrator. See the event log for details.'; 
		           |pl = 'Parametry dzia??ania programu nie s?? aktualizowane w trybie bez partycji.
		           |Skontaktuj si?? z administratorem us??ugi. Szczeg????y w dzienniku rejestracji.';
		           |es_ES = 'Los par??metros del funcionamiento del programa no han sido actualizados en el modo no distribuido.
		           |Dir??jase al administrador del servicio. V??ase los detalles en el registro eventos.';
		           |es_CO = 'Los par??metros del funcionamiento del programa no han sido actualizados en el modo no distribuido.
		           |Dir??jase al administrador del servicio. V??ase los detalles en el registro eventos.';
		           |tr = 'Uygulaman??n parametreleri b??l??nmemi?? modda g??ncellenmedi. 
		           |Servis y??neticisine ba??vurun. Detaylar kay??t g??nl??????ndedir.';
		           |it = 'I parametri di funzionamento del programma non vengono aggiornati in modalit?? non partizionata.
		           | Contattare l''amministratore del servizio. Dettagli nel registro.';
		           |de = 'Die Programmbetriebsparameter werden im ungeteilten Modus nicht aktualisiert.
		           |Wenden Sie sich an den Service-Administrator. Details im Ereignisprotokoll.'");
	
	Raise ErrorText;
	
EndProcedure

Function IsApplicationParameterChanges(LastChanges)
	
	If TypeOf(LastChanges)              <> Type("ValueTable")
	 OR LastChanges.Columns.Count() <> 2
	 OR LastChanges.Columns[0].Name       <> "ConfigurationVersion"
	 OR LastChanges.Columns[1].Name       <> "Changes" Then
		
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Function UpdateWithoutBackgroundJob()
	
	If Not CanExecuteBackgroundJobs()
	   AND Not HasRolesModifiedByExtensions() Then
		
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Function HasRolesModifiedByExtensions()
	
	For Each Role In Metadata.Roles Do
		If Role.ChangedByConfigurationExtensions() Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function CanExecuteBackgroundJobs()
	
	If CurrentRunMode() = Undefined
	   AND Common.FileInfobase() Then
		
		Session = GetCurrentInfoBaseSession();
		If Session.ApplicationName = "COMConnection" Then
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

#EndRegion

#EndIf
