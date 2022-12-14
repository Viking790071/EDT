#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// See StandardSubsystemsServer.ExtensionParameter. 
Function ExtensionParameter(ParameterName, IgnoreExtensionsVersion = False) Export
	
	ExtensionsVersion = ?(IgnoreExtensionsVersion, Catalogs.ExtensionsVersions.EmptyRef(), SessionParameters.ExtensionsVersion);
	
	Query = New Query;
	Query.SetParameter("ExtensionsVersion", ExtensionsVersion);
	Query.SetParameter("ParameterName", ParameterName);
	Query.Text =
	"SELECT
	|	ExtensionVersionParameters.ParameterStorage
	|FROM
	|	InformationRegister.ExtensionVersionParameters AS ExtensionVersionParameters
	|WHERE
	|	ExtensionVersionParameters.ExtensionsVersion = &ExtensionsVersion
	|	AND ExtensionVersionParameters.ParameterName = &ParameterName";
	
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

// See StandardSubsystemsServer.SetExtensionParameter. 
Procedure SetExtensionParameter(ParameterName, Value, IgnoreExtensionsVersion = False) Export
	
	ExtensionsVersion = ?(IgnoreExtensionsVersion, Catalogs.ExtensionsVersions.EmptyRef(), SessionParameters.ExtensionsVersion);
	
	RecordSet = CreateRecordSet();
	RecordSet.Filter.ExtensionsVersion.Set(ExtensionsVersion);
	RecordSet.Filter.ParameterName.Set(ParameterName);
	
	NewRecord = RecordSet.Add();
	NewRecord.ExtensionsVersion   = ExtensionsVersion;
	NewRecord.ParameterName       = ParameterName;
	NewRecord.ParameterStorage = New ValueStorage(Value);
	
	RecordSet.DataExchange.Load = True;
	RecordSet.Write();
	
EndProcedure

// Forces all run parameters to be filled for the current extension version.
Procedure FillAllExtensionParameters() Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	// Fill extension metadata object IDs.
	If ValueIsFilled(SessionParameters.AttachedExtensions) Then
		Update = Catalogs.ExtensionObjectIDs.CurrentVersionExtensionObjectIDsFilled();
		StandardSubsystemsCached.MetadataObjectIDsUsageCheck(True, True);
	Else
		Update = True;
	EndIf;
	
	If Update Then
		Catalogs.ExtensionObjectIDs.UpdateCatalogData();
	EndIf;
	
	SSLSubsystemsIntegration.OnFillAllExtensionsParameters();
	
	ParameterName = "StandardSubsystems.Core.LastFillingDateOfAllExtensionsParameters";
	StandardSubsystemsServer.SetExtensionParameter(ParameterName, CurrentSessionDate(), True);
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.SetAccessUpdate(True);
	EndIf;
	
EndProcedure

// Returns the date of the last filling in the extension version operation parameters.
Function LastFillingDateOfAllExtensionsParameters() Export
	
	ParameterName = "StandardSubsystems.Core.LastFillingDateOfAllExtensionsParameters";
	UpdateDate = StandardSubsystemsServer.ExtensionParameter(ParameterName, True);
	
	If TypeOf(UpdateDate) <> Type("Date") Then
		UpdateDate = '00010101';
	EndIf;
	
	Return UpdateDate;
	
EndFunction

// Forces all run parameters to be cleared for the current extension version.
// Only registers are cleared, catalogs are not changed. Called to refill extension parameter values, 
// for example, when you use the StartInfobaseUpdate launch parameter.
// 
// 
// The ExtensionVersionParameters common register is cleared automatically. If you use your own 
// information registers that store extension metadata object cache versions, attach the 
// OnClearAllExtemsionRunParameters event of the SubsystemIntegrationSSL common module.
// 
//
Procedure ClearAllExtensionParameters() Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		RecordSet = InformationRegisters.ExtensionVersionObjectIDs.CreateRecordSet();
		RecordSet.Filter.ExtensionsVersion.Set(SessionParameters.ExtensionsVersion);
		RecordSet.DataExchange.Load = True;
		RecordSet.Write();
		
		RecordSet = CreateRecordSet();
		RecordSet.Filter.ExtensionsVersion.Set(SessionParameters.ExtensionsVersion);
		RecordSet.DataExchange.Load = True;
		RecordSet.Write();
		
		SSLSubsystemsIntegration.OnClearAllExtemsionParameters();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	RefreshReusableValues();
	
EndProcedure

// This is required for the Extensions common form.
Procedure FillAllExtensionParametersBackgroundJob(Parameters) Export
	
	ErrorText = "";
	UnattachedExtensions = "";
	
	If Parameters.ConfigurationName    <> Metadata.Name
	 Or Parameters.ConfigurationVersion <> Metadata.Version Then
		ErrorText =
			NStr("ru = '???? ?????????????? ???????????????? ?????? ?????????????????? ???????????? ????????????????????, ?????? ??????
			           |???????????????????? ?????? ?????? ???????????? ???????????????????????? - ?????????????????? ???????????????????? ????????????.'; 
			           |en = 'Cannot update all of the extension parameters
			           |because the configuration name or version was changed. Please restart the session.'; 
			           |pl = 'Nie uda??o si?? zaktualizowa?? wszystkich parametr??w rozszerze??, poniewa??
			           |zmieni??a si?? nazwa lub wersja konfiguracji - wymagane jest ponowne uruchomienie sesji.';
			           |es_ES = 'No se ha podido actualizar todos los par??metros de funcionamiento de extensiones, porque
			           |se ha cambiado el nombre o la versi??n de la configuraci??n - se requiere reiniciar la sesi??n.';
			           |es_CO = 'No se ha podido actualizar todos los par??metros de funcionamiento de extensiones, porque
			           |se ha cambiado el nombre o la versi??n de la configuraci??n - se requiere reiniciar la sesi??n.';
			           |tr = 'Ad?? veya yap??land??rma s??r??m?? de??i??ti??inden 
			           |t??m uzant?? ayarlar??n?? g??ncelle??tirilemedi-oturum yeniden ba??lat??lmal??d??r.';
			           |it = 'Non ?? stato possibile aggiornare tutti i parametri delle estensioni,
			           | in quanto il nome o la versione della configurazione ?? stata modificata - la sessione deve essere riavviata.';
			           |de = 'Es war nicht m??glich, alle Erweiterungseinstellungen zu aktualisieren, da sich
			           |der Name oder die Version der Konfiguration ge??ndert hat - die Sitzung muss neu gestartet werden.'");
	EndIf;
	
	If Parameters.InstalledExtensions.Main    <> SessionParameters.InstalledExtensions.Main
	 Or Parameters.InstalledExtensions.Patches <> SessionParameters.InstalledExtensions.Patches Then
		ErrorText =
			NStr("ru = '???? ?????????????? ???????????????? ?????? ?????????????????? ???????????? ????????????????????,
			           |?????? ?????? ?????????????????? ???????????? ???????????????????? ???????????????????? ???? ????????????????.'; 
			           |en = 'Cannot update all of the extension parameters
			           |because the specified list of extensions does not match the current one.'; 
			           |pl = 'Nie uda??o si?? zaktualizowa?? wszystkich parametr??w pracy rozszerze??,
			           |poniewa?? okre??lony sk??ad rozszerze?? r????ni si?? od bie????cego.';
			           |es_ES = 'No se ha podido actualizar todos los par??metros del funcionamiento de las extensiones,
			           |porque el contenido indicado de las extensiones se diferencia del actual.';
			           |es_CO = 'No se ha podido actualizar todos los par??metros del funcionamiento de las extensiones,
			           |porque el contenido indicado de las extensiones se diferencia del actual.';
			           |tr = 'Belirtilen uzant?? i??eri??i ge??erli olandan farkl?? oldu??u i??in
			           | t??m uzant?? parametreleri g??ncelle??tirilemedi.';
			           |it = 'Non ?? stato possibile aggiornare tutti i parametri delle estensioni,
			           | in quanto la composizione specificata delle estensioni differisce da quella corrente.';
			           |de = 'Es war nicht m??glich, alle Parameter der Erweiterungen zu aktualisieren,
			           |da die angegebene Zusammensetzung der Erweiterungen von der aktuellen abweicht.'");
	EndIf;
	
	If TypeOf(Parameters.ExtensionsToCheck) = Type("Map") Then
		Extensions = ConfigurationExtensions.Get(, ConfigurationExtensionsSource.SessionApplied);
		AttachedExtensions = New Array;
		For Each Extension In Extensions Do
			AttachedExtensions.Add(Extension.Name);
		EndDo;
		For Each ExtensionToCheck In Parameters.ExtensionsToCheck Do
			If AttachedExtensions.Find(ExtensionToCheck.Key) = Undefined Then
				UnattachedExtensions = UnattachedExtensions
					 + ?(UnattachedExtensions = "", "", ", ") + ExtensionToCheck.Value;
			EndIf;
		EndDo;
	EndIf;
	
	If Not ValueIsFilled(ErrorText) Then
		Try
			FillAllExtensionParameters();
		Except
			ErrorInformation = ErrorInfo();
			ErrorText = DetailErrorDescription(ErrorInformation);
		EndTry;
	EndIf;
	
	Result = New Structure;
	Result.Insert("ErrorText",              ErrorText);
	Result.Insert("UnattachedExtensions", UnattachedExtensions);
	
	PutToTempStorage(Result, Parameters.ResultAddress);
	
EndProcedure

Procedure UpdateExtensionParameters(ExtensionsToCheck = Undefined, UnattachedExtensions = "") Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("ConfigurationName",         Metadata.Name);
	ExecutionParameters.Insert("ConfigurationVersion",      Metadata.Version);
	ExecutionParameters.Insert("InstalledExtensions", Catalogs.ExtensionsVersions.InstalledExtensions());
	ExecutionParameters.Insert("ExtensionsToCheck",   ExtensionsToCheck);
	ExecutionParameters.Insert("ResultAddress",         PutToTempStorage(Undefined));
	ProcedureParameters = New Array;
	ProcedureParameters.Add(ExecutionParameters);
	
	BackgroundJob = ConfigurationExtensions.ExecuteBackgroundJobWithDatabaseExtensions(
		"StandardSubsystemsServer.FillAllExtensionParametersBackgroundJob", ProcedureParameters);
	BackgroundJob.WaitForCompletion();
	Filter = New Structure("UUID", BackgroundJob.UUID);
	BackgroundJob = BackgroundJobs.GetBackgroundJobs(Filter)[0];
	If BackgroundJob.ErrorInfo <> Undefined Then
		Raise DetailErrorDescription(BackgroundJob.ErrorInfo);
	EndIf;
	
	Result = GetFromTempStorage(ExecutionParameters.ResultAddress);
	If TypeOf(Result) <> Type("Structure") Then
		Raise NStr("ru = '?????????????? ?????????????? ???????????????????? ???????????????????? ???? ?????????????? ??????????????????.'; en = 'The background job that prepares extensions did not return the result.'; pl = 'Zadanie przygotowania rozszerze?? w tle nie zwr??ci??o wyniku.';es_ES = 'La tarea del fondo de preparaci??n de extensiones no ha devuelto el resultado.';es_CO = 'La tarea del fondo de preparaci??n de extensiones no ha devuelto el resultado.';tr = 'Uzant?? haz??rlama arka plan g??revi sonucu iade etmedi.';it = 'Il processo in background che prepara le estensioni non restituisce il risultato.';de = 'Der Hintergrundjob zur Vorbereitung von Erweiterungen lieferte kein Ergebnis.'");
	EndIf;
	
	If ValueIsFilled(Result.ErrorText) Then
		Raise Result.ErrorText;
	EndIf;
	
	If ValueIsFilled(Result.UnattachedExtensions) Then
		UnattachedExtensions = Result.UnattachedExtensions;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf