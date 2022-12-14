#Region Public

#Region ForCallsFromOtherSubsystems

// OnlineUserSupport.GetApplicationUpdates

// Gets configuration update settings.
//
// Returns:
//   Structure - with the following properties:
//     * UpdateMode - Number - 0 for a file infobase, 2 for a client/server infobase.
//     * UpdateDateTime - Date - a scheduled configuration update date.
//     * EmailReport - Boolean - shows whether update reports are sent by email.
//     * EmailAddress - String - an email address for sending update reports.
//     * SchedulerTaskCode - Number - a Windows scheduler task code.
//     * UpdateFileName - String - an update file name.
//     * CreateBackup - Number - shows whether a backup is created.
//     * IBBackupDirectoryName - String - a backup directory.
//     * RestoreInfobase - Boolean - shows whether an infobase is restored from a backup in case of 
//                                                    update errors.
//
Function ConfigurationUpdateSettings() Export
	
	DefaultSettings = DefaultSettings();
	Settings = Common.CommonSettingsStorageLoad("ConfigurationUpdate", "ConfigurationUpdateSettings");
	
	If Settings <> Undefined Then
		FillPropertyValues(DefaultSettings, Settings);
	EndIf;
	
	Return DefaultSettings;
	
EndFunction

// Saves configuration update settings.
//
// Parameters:
//    Settings - Structure - See ConfigurationUpdateSettings procedure return value.
//
Procedure SaveConfigurationUpdateSettings(Settings) Export
	
	DefaultSettings = DefaultSettings();
	FillPropertyValues(DefaultSettings, Settings);
	
	Common.CommonSettingsStorageSave(
		"ConfigurationUpdate",
		"ConfigurationUpdateSettings",
		DefaultSettings);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Managing patches.

// Returns details of patches installed in the configuration.
//
// Returns:
//  Array - structures with the following keys:
//     * ID - String - a patch UUID.
//                     - Undefined - if a patch was installed in the current session and the 
//                                application has not been restarted yet.
//     * Description  - String - a patch description.
//
Function InstalledPatches() Export
	
	Result = New Array;
	InstalledExtensions = ConfigurationExtensions.Get();
	For Each Extension In InstalledExtensions Do
		If Not IsPatch(Extension) Then
			Continue;
		EndIf;
		PatchInformation = New Structure("ID, Description");
		PatchProperties = PatchProperties(Extension.Name);
		
		If PatchProperties <> Undefined Then
			PatchInformation.ID = PatchProperties.UUID;
		EndIf;
		PatchInformation.Description  = Extension.Name;
		
		Result.Add(PatchInformation);
	EndDo;
	
	Return Result;
	
EndFunction

// Installs and deletes patches.
//
// Parameters:
//  Patches - Structure - with the following keys:
//     * Install - Array - paths to the patch files in a temporary storage.
//                             
//     * Delete    - Array - UUIDs of patches to be deleted (String).
//
// Returns:
//  Structure - with the following keys:
//     * PatchesInstalled - Array - names of installed patches (String).
//     * PatchesNotInstalled - Number - the number of patches that are not installed.
//     * PatchesNotDeleted     - Number - the number of patches that are not deleted.
//
Function InstallAndDeletePatches(Patches) Export
	
	PatchesToInstall = Undefined;
	PatchesNotInstalled   = 0;
	PatchesInstalled   = New Array;
	If Patches.Property("Set", PatchesToInstall)
		AND PatchesToInstall <> Undefined
		AND PatchesToInstall.Count() > 0 Then
		
		For Each Patch In PatchesToInstall Do
			Try
				Extension = ConfigurationExtensions.Create();
				Extension.SafeMode = False;
				If Common.HasUnsafeActionProtection() Then
					Extension.UnsafeActionProtection = Common.ProtectionWithoutWarningsDetails();
				EndIf;
				Extension.UsedInDistributedInfoBase = True;
				Extension.Write(GetFromTempStorage(Patch));
				
				InstalledPatch = ExtensionByID(Extension.UUID);
				PatchesInstalled.Add(InstalledPatch.Name);
			Except
				PatchesNotInstalled = PatchesNotInstalled + 1;
				ErrorInformation = ErrorInfo();
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '?????? ?????????????????? ?????????????????????? ""%1"" ?????????????????? ????????????:
					           |
					           |%2'; 
					           |en = 'An error occurred while installing patch ""%1"":
					           |
					           |%2'; 
					           |pl = 'Podczas ustawienia korekty ""%1"" zaistnia?? b????d:
					           |
					           |%2';
					           |es_ES = 'Al instalar la correcci??n ""%1"" se ha producido un error:
					           |
					           |%2';
					           |es_CO = 'Al instalar la correcci??n ""%1"" se ha producido un error:
					           |
					           |%2';
					           |tr = '""%1"" yamas?? y??klenirken hata olu??tu:
					           |
					           |%2';
					           |it = 'Si ?? verificato un errore durante l''installazione della patch ""%1"":
					           |
					           |%2';
					           |de = 'Bei der Installation der ""%1"" Korrektur ist ein Fehler aufgetreten:
					           |
					           |%2'"), Extension.Name, BriefErrorDescription(ErrorInformation));
				WriteLogEvent(NStr("ru = '??????????????????????.??????????????????'; en = 'Patch.Install'; pl = 'Korekty.Instalacja';es_ES = 'Correcciones.Instalaci??n';es_CO = 'Correcciones.Instalaci??n';tr = 'D??zeltmeler. Kurulum';it = 'Rettifiche.Installazione';de = 'Korrekturen.Installation'", CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,,, ErrorText);
			EndTry;
		EndDo;
		
	EndIf;
	
	PatchesToDelete = Undefined;
	PatchesNotDeleted = 0;
	If Patches.Property("Delete", PatchesToDelete)
		AND PatchesToDelete <> Undefined
		AND PatchesToDelete.Count() > 0 Then
		AllExtensions = ConfigurationExtensions.Get();
		For Each Extension In AllExtensions Do
			If Not IsPatch(Extension) Then
				Continue;
			EndIf;
			Try
				PatchProperties = PatchProperties(Extension.Name);
				ID = PatchProperties.UUID;
				If PatchesToDelete.Find(String(ID)) <> Undefined Then
					Extension.Delete();
				EndIf;
			Except
				PatchesNotDeleted = PatchesNotDeleted + 1;
				ErrorInformation = ErrorInfo();
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '???? ?????????????? ?????????????? ?????????????????????? ""%1"" ???? ??????????????:
					           |
					           |%2'; 
					           |en = 'Cannot delete patch ""%1."" Reason:
					           |
					           |%2'; 
					           |pl = 'Nie uda??o si?? usun???? poprawk?? ""%1"" z powodu:
					           |
					           |%2';
					           |es_ES = 'No se ha podido eliminar la correcci??n ""%1"" a causa de:
					           |
					           |%2';
					           |es_CO = 'No se ha podido eliminar la correcci??n ""%1"" a causa de:
					           |
					           |%2';
					           |tr = '""%1"" yamas?? silinemedi. Nedeni:
					           |
					           |%2';
					           |it = 'Non ?? possibile eliminare la patch ""%1."" Motivo:
					           |
					           |%2';
					           |de = 'Die ""%1""-Korrektur konnte aus diesem Grund nicht entfernt werden:
					           |
					           |%2'"), Extension.Name, BriefErrorDescription(ErrorInformation));
				WriteLogEvent(NStr("ru = '??????????????????????.????????????????'; en = 'Patch.Delete'; pl = 'Korekty.Usuni??cie';es_ES = 'Correcciones.Eliminaci??n';es_CO = 'Correcciones.Eliminaci??n';tr = 'D??zeltmeler. Silme';it = 'Patch.Eliminare';de = 'Korrekturen.L??schung'", CommonClientServer.DefaultLanguageCode())
					, EventLogLevel.Error,,, ErrorText);
			EndTry;
		EndDo;
	EndIf;
	
#If Not ExternalConnection Then
	InformationRegisters.ExtensionVersionParameters.UpdateExtensionParameters();
#EndIf
	
	Result = New Structure;
	Result.Insert("NotInstalled", PatchesNotInstalled);
	Result.Insert("NotDeleted", PatchesNotDeleted);
	Result.Insert("Installed", PatchesInstalled);
	
	Return Result;
	
EndFunction

// Checks whether extensions that require to show the warning about existing extensions are present.
// 
// Checks whether extensions that are not patches are present.
//
// Returns:
//  Boolean - the result of the check.
//
Function WarnAboutExistingExtensions() Export 
	
	AllExtensions = ConfigurationExtensions.Get();
	
	For Each Extension In AllExtensions Do
		If Not IsPatch(Extension) Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// End OnlineUserSupport.GetApplicationUpdates

#EndRegion

#EndRegion

#Region Internal

// This method is called when a configuration update over a COM connection is completed.
//
// Parameters:
//  UpdateResult  - Boolean - an update result.
//
Procedure CompleteUpdate(Val UpdateResult, Val Email, Val UpdateAdministratorName, Val ScriptDirectory = Undefined) Export

	MessageText = NStr("ru = '???????????????????? ???????????????????? ???? ???????????????? ??????????????.'; en = 'Completing update from the external script.'; pl = 'Zako??czenie aktualizacji ze skryptu zewn??trznego.';es_ES = 'Finalizando la actualizaci??n desde el script externo.';es_CO = 'Finalizando la actualizaci??n desde el script externo.';tr = 'Harici komut dosyas??ndan g??ncelleme tamamlan??yor.';it = 'Completamento aggiornamento dal script esterno.';de = 'Aktualisierung vom externen Skript abschlie??en.'");
	WriteLogEvent(EventLogEvent(), EventLogLevel.Information,,,MessageText);
	
	If Not HasRightsToInstallUpdate() Then
		MessageText = NStr("ru = '???????????????????????? ???????? ?????? ???????????????????? ???????????????????? ????????????????????????.'; en = 'Insufficient rights to complete the configuration update.'; pl = 'Za ma??o praw do zako??czenia aktualizacji konfiguracji.';es_ES = 'Insuficientes derechos para finalizar la actualizaci??n de configuraciones.';es_CO = 'Insuficientes derechos para finalizar la actualizaci??n de configuraciones.';tr = 'Yap??land??rma g??ncellemesini tamamlamak i??in yetersiz haklar.';it = 'Autorizzazioni insufficienti per completare l''aggiornamento della configurazione.';de = 'Unzureichende Rechte, um das Konfigurationsupdate abzuschlie??en.'");
		WriteLogEvent(EventLogEvent(), EventLogLevel.Error,,,MessageText);
		Raise MessageText;
	EndIf;
	
	If ScriptDirectory = Undefined Then 
		ScriptDirectory = ScriptDirectory();
	EndIf;
	
	WriteUpdateStatus(UpdateAdministratorName, False, True, UpdateResult, ScriptDirectory);
	
	If Common.SubsystemExists("StandardSubsystems.EmailOperations")
		AND Not IsBlankString(Email) Then
		Try
			SendUpdateNotification(UpdateAdministratorName, Email, UpdateResult);
			MessageText = NStr("ru = '?????????????????????? ???? ???????????????????? ?????????????? ???????????????????? ???? ?????????? ?????????????????????? ??????????:'; en = 'An update notification is sent to:'; pl = 'Komunikat o aktualizacji zosta?? pomy??lnie przes??any na adres poczty e-mail:';es_ES = 'Notificaci??n de la actualizaci??n se ha enviado con ??xito a la direcci??n de correo electr??nico:';es_CO = 'Notificaci??n de la actualizaci??n se ha enviado con ??xito a la direcci??n de correo electr??nico:';tr = 'G??ncelleme bildirimi e-posta adresine ba??ar??yla g??nderildi:';it = 'Una notifica di aggiornamento ?? stato inviato a:';de = 'Die Update-Benachrichtigung wurde erfolgreich an die E-Mail-Adresse gesendet:'")
				+ " " + Email;
			WriteLogEvent(EventLogEvent(), EventLogLevel.Information,,,MessageText);
		Except
			MessageText = NStr("ru = '???????????? ?????? ???????????????? ???????????? ?????????????????????? ??????????:'; en = 'An error occurred when sending the email:'; pl = 'Wyst??pi?? b????d podczas wysy??ania wiadomo??ci e-mail:';es_ES = 'Ha ocurrido un error al enviar el correo electr??nico:';es_CO = 'Ha ocurrido un error al enviar el correo electr??nico:';tr = 'E-posta g??nderilirken bir hata olu??tu:';it = 'Si ?? verificato un errore durante l''invio della e-mail:';de = 'Beim Senden der E-Mail ist ein Fehler aufgetreten:'")
				+ " " + Email + Chars.LF + DetailErrorDescription(ErrorInfo());
			WriteLogEvent(EventLogEvent(), EventLogLevel.Error,,,MessageText);
		EndTry;
	EndIf;
	
	If UpdateResult Then
		InfobaseUpdateInternal.AfterUpdateCompletion();
	EndIf;
	
EndProcedure

Function ScriptDirectory() Export
	
	ScriptDirectory = "";
	
	If Not Common.DataSeparationEnabled() Then 
		
		UpdateStatus = Constants.ConfigurationUpdateStatus.Get().Get();
		If UpdateStatus <> Undefined
			AND UpdateStatus.Property("ScriptDirectory") Then
			
			ScriptDirectory = UpdateStatus.ScriptDirectory;
		EndIf;
		
	EndIf;
	
	Return ScriptDirectory;
	
EndFunction

// Returns the full name of the main form of the InstallUpdates data processor.
//
Function InstallUpdatesFormName() Export
	
	Return "DataProcessor.InstallUpdates.Form.Form";
	
EndFunction

// Deletes obsolete patches and updates properties of new patches.
//
Function PatchesChanged() Export
	
	PatchesChanged = False;
	
	// A version check is required for newly attached extensions.
	Patches = New Array;
	Extensions = ConfigurationExtensions.Get(, ConfigurationExtensionsSource.SessionApplied);
	For Each Extension In Extensions Do
		If IsPatch(Extension) Then
			Patches.Add(Extension);
		EndIf;
	EndDo;
	
	If Patches.Count() > 0 Then
		
		SubsystemsDetails = StandardSubsystemsCached.SubsystemsDetails();
		
		ConfigurationLibraries = New Map;
		For Each Subsystem In SubsystemsDetails.ByNames Do
			ConfigurationLibraries.Insert(Subsystem.Key, Subsystem.Value.Version);
		EndDo;
		
		For Each Patch In Patches Do
			DeletePatch = True;
			PatchProperties = PatchProperties(Patch.Name);
			If PatchProperties = Undefined Then
				// The patch is not applied yet.
				DeletePatch = False;
			Else
				For Each ApplicabilityInformation In PatchProperties.AppliedFor Do
					ConfigurationLibraryVersion = ConfigurationLibraries.Get(ApplicabilityInformation.ConfigurationName);
					
					If ConfigurationLibraryVersion <> Undefined
						AND StrFind(ApplicabilityInformation.Versions, ConfigurationLibraryVersion) > 0 Then
						DeletePatch = False;
					EndIf;
				EndDo;
			EndIf;
			
			If DeletePatch Then
				Try
					Patch.Delete();
					PatchesChanged = True;
				Except
					ErrorInformation = ErrorInfo();
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = '???? ?????????????? ?????????????? ?????????????????????? ""%1"" ???? ??????????????:
						           |
						           |%2'; 
						           |en = 'Cannot delete patch ""%1."" Reason:
						           |
						           |%2'; 
						           |pl = 'Nie uda??o si?? usun???? poprawk?? ""%1"" z powodu:
						           |
						           |%2';
						           |es_ES = 'No se ha podido eliminar la correcci??n ""%1"" a causa de:
						           |
						           |%2';
						           |es_CO = 'No se ha podido eliminar la correcci??n ""%1"" a causa de:
						           |
						           |%2';
						           |tr = '""%1"" yamas?? silinemedi. Nedeni:
						           |
						           |%2';
						           |it = 'Non ?? possibile eliminare la patch ""%1."" Motivo:
						           |
						           |%2';
						           |de = 'Die ""%1""-Korrektur konnte aus diesem Grund nicht entfernt werden:
						           |
						           |%2'"), Patch.Name, BriefErrorDescription(ErrorInformation));
					WriteLogEvent(NStr("ru = '??????????????????????.????????????????'; en = 'Patch.Delete'; pl = 'Korekty.Usuni??cie';es_ES = 'Correcciones.Eliminaci??n';es_CO = 'Correcciones.Eliminaci??n';tr = 'D??zeltmeler. Silme';it = 'Patch.Eliminare';de = 'Korrekturen.L??schung'", CommonClientServer.DefaultLanguageCode()),
						EventLogLevel.Error,,, ErrorText);
					Raise ErrorText;
				EndTry;
			Else
				WritingRequired = False;
				If Common.HasUnsafeActionProtection() Then
					UnsafeOperationProtection = Common.ProtectionWithoutWarningsDetails();
					If Patch.UnsafeActionProtection.UnsafeOperationWarnings
							<> UnsafeOperationProtection.UnsafeOperationWarnings Then
						Patch.UnsafeActionProtection = UnsafeOperationProtection;
						WritingRequired = True;
					EndIf;
				EndIf;
				If Patch.SafeMode <> False Then
					Patch.SafeMode = False ;
					PatchesChanged = True;
				EndIf;
				
				If WritingRequired Then
					Try
						Patch.Write();
						PatchesChanged = True;
					Except
						ErrorInformation = ErrorInfo();
						ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("ru = '?????? ???????????? ?????????????????????? ""%1"" ?????????????????? ????????????:
							           |
							           |%2'; 
							           |en = 'An error occurred while writing patch ""%1"":
							           |
							           |%2'; 
							           |pl = 'Podczas zapisu korekty ""%1"" zaistnia?? b????d:
							           |
							           |%2';
							           |es_ES = 'Al guardar la correcci??n ""%1"" se ha producido un error:
							           |
							           |%2';
							           |es_CO = 'Al guardar la correcci??n ""%1"" se ha producido un error:
							           |
							           |%2';
							           |tr = '""%1"" yamas?? kaydedilirken hata olu??tu:
							           |
							           |%2';
							           |it = 'Si ?? verificato un errore durante la scrittura della patch ""%1"":
							           |
							           |%2';
							           |de = 'Beim Schreiben der ""%1"" Korrektur ist ein Fehler aufgetreten:
							           |
							           |%2'"), Patch.Name, BriefErrorDescription(ErrorInformation));
						WriteLogEvent(NStr("ru = '??????????????????????.??????????????????'; en = 'Patch.Change'; pl = 'Korekty.Zmiana';es_ES = 'Correcci??n.Cambio';es_CO = 'Correcci??n.Cambio';tr = 'D??zeltme.De??i??iklik';it = 'Patch.Modificare';de = 'Korrekturen.??nderung'", CommonClientServer.DefaultLanguageCode()),
							EventLogLevel.Error,,, ErrorText);
						Raise ErrorText;
					EndTry;
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	// Deleting patches that are not attached without checking their versions.
	Extensions = ConfigurationExtensions.Get(, ConfigurationExtensionsSource.SessionDisabled);
	For Each Extension In Extensions Do
		If IsPatch(Extension) Then
			Try
				Extension.Delete();
				PatchesChanged = True;
			Except
				ErrorInformation = ErrorInfo();
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '???? ?????????????? ?????????????? ?????????????????????? ?????????????????????? ""%1"" ???? ??????????????:
					           |
					           |%2'; 
					           |en = 'Cannot delete the disabled patch ""%1."" Reason:
					           |
					           |%2'; 
					           |pl = 'Nie uda??o si?? usun???? od????czon?? poprawk?? ""%1"" z powodu:
					           |
					           |%2';
					           |es_ES = 'No se ha podido eliminar la correcci??n desactivada ""%1"" a causa de:
					           |
					           |%2';
					           |es_CO = 'No se ha podido eliminar la correcci??n desactivada ""%1"" a causa de:
					           |
					           |%2';
					           |tr = 'Devre d?????? b??rak??lm???? ""%1"" yamas?? silinemedi. Nedeni:
					           |
					           |%2';
					           |it = 'Impossibile rimuovere l''hotfix disabilitato ""%1"" perch??:
					           |
					           |%2';
					           |de = 'Die deaktivierte ""%1"" Korrektur konnte aus diesem Grund nicht gel??scht werden:
					           |
					           |%2'"), Extension.Name, BriefErrorDescription(ErrorInformation));
				WriteLogEvent(NStr("ru = '??????????????????????.????????????????'; en = 'Patch.Delete'; pl = 'Korekty.Usuni??cie';es_ES = 'Correcciones.Eliminaci??n';es_CO = 'Correcciones.Eliminaci??n';tr = 'D??zeltmeler. Silme';it = 'Patch.Eliminare';de = 'Korrekturen.L??schung'", CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,,, ErrorText);
				Raise ErrorText;
			EndTry;
		EndIf;
	EndDo;
	
	Return PatchesChanged;
	
EndFunction

// Reads patch properties from a template. The template name must be identical to the patch name.
// XML template format. It matches the ErrorFix XDTO package.
//
Function PatchProperties(PatchName) Export
	
	If Metadata.CommonTemplates.Find(PatchName) = Undefined Then
		Return Undefined;
	EndIf;
	
	XMLString = GetCommonTemplate(PatchName).GetText();
	
	XMLReader = New XMLReader;
	XMLReader.SetString(XMLString);
	
	Return XDTOFactory.ReadXML(XMLReader, XDTOFactory.Type("http://www.v8.1c.ru/ssl/patch", "Patch"));
	
EndFunction

Function IsPatch(Extension) Export
	
	Return Extension.Purpose = Metadata.ObjectProperties.ConfigurationExtensionPurpose.Patch
		AND StrStartsWith(Extension.Name, "EF");
	
EndFunction

Procedure UpdatePatchesFromScript(NewPatches, PatchesToDelete) Export
	
	PatchesChanged();
	
	PatchesToInstall = New Array;
	If ValueIsFilled(NewPatches) Then
		NewPatchesArray = StrSplit(NewPatches, Chars.LF);
		For Each Patch In NewPatchesArray Do
			PatchData = New BinaryData(Patch);
			PatchesToInstall.Add(PutToTempStorage(PatchData));
		EndDo;
	EndIf;
	
	PatchesToDeleteArray = New Array;
	If ValueIsFilled(PatchesToDelete) Then
		PatchesToDeleteArray = StrSplit(PatchesToDelete, Chars.LF);
	EndIf;
	
	Patches = New Structure("Set, Delete", PatchesToInstall, PatchesToDeleteArray);
	Result = InstallAndDeletePatches(Patches);
	Result.Insert("TotalPatchCount", PatchesToInstall.Count());
	
	StorageValue = Constants.ConfigurationUpdateStatus.Get();
	If StorageValue = Undefined Then
		Return;
	EndIf;
	Status = StorageValue.Get();
	If Status = Undefined Then
		Return;
	EndIf;
	If Not Status.Property("PatchInstallationResult") Then
		Status.Insert("PatchInstallationResult");
	EndIf;
	Status.PatchInstallationResult = Result;
	Constants.ConfigurationUpdateStatus.Set(New ValueStorage(Status));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.AfterUpdateInfobase. 
Procedure AfterUpdateInfobase() Export
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	StorageValue = Constants.ConfigurationUpdateStatus.Get();
	
	Status = Undefined;
	If StorageValue <> Undefined Then
		Status = StorageValue.Get();
	EndIf;
	
	If Status <> Undefined AND Status.UpdateComplete AND Status.ConfigurationUpdateResult <> Undefined
		AND Not Status.ConfigurationUpdateResult Then
		
		Status.ConfigurationUpdateResult = True;
		Constants.ConfigurationUpdateStatus.Set(New ValueStorage(Status));
		
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddClientParametersOnStart. 
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	OnAddClientParameters(Parameters);
	
EndProcedure

// See CommonOverridable.OnAddClientParameters. 
Procedure OnAddClientParameters(Parameters) Export
	
	If Not Common.SeparatedDataUsageAvailable()
		Or Not CommonClientServer.IsWindowsClient() Then
		Return;
	EndIf;
	
	Parameters.Insert("UpdateSettings", New FixedStructure(UpdateSettings()));

EndProcedure

Procedure CheckUpdateStatus(UpdateResult, ScriptDirectory, InstalledPatches) Export
	
	// If it is the first start after a configuration update, storing and resetting status.
	UpdateResult = ConfigurationUpdateSuccessful(ScriptDirectory, InstalledPatches);
	If UpdateResult <> Undefined Then
		ResetConfigurationUpdateStatus();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Gets global update settings for a 1C:Enterprise session.
//
Function UpdateSettings()
	
	Settings = New Structure;
	Settings.Insert("ConfigurationChanged",?(HasRightsToInstallUpdate(), ConfigurationChanged(), False));
	Settings.Insert("CheckPreviousInfobaseUpdates", ConfigurationUpdateSuccessful() <> Undefined);
	Settings.Insert("ConfigurationUpdateSettings", ConfigurationUpdateSettings());
	
	Return Settings;
	
EndFunction

// Returns the flag that shows whether configuration update is successful (based on the constant from the settings).
Function ConfigurationUpdateSuccessful(ScriptDirectory = "", InstalledPatches = "") Export

	If Not AccessRight("Read", Metadata.Constants.ConfigurationUpdateStatus) Then
		Return Undefined;
	EndIf;
	
	StorageValue = Constants.ConfigurationUpdateStatus.Get();
	
	Status = Undefined;
	If StorageValue <> Undefined Then
		Status = StorageValue.Get();
	EndIf;

	If Status = Undefined Then
		Return Undefined;
	EndIf;
	
	If Not StandardSubsystemsServer.IsBaseConfigurationVersion()
		AND Not Status.UpdateComplete
		Or (Status.NameOfUpdateAdministrator <> UserName()) Then
		
		Return Undefined;
		
	EndIf;
	
	If Status.ConfigurationUpdateResult <> Undefined Then
		Status.Property("ScriptDirectory", ScriptDirectory);
		Status.Property("PatchInstallationResult", InstalledPatches);
	EndIf;
	
	Return Status.ConfigurationUpdateResult;

EndFunction

// Sets a new value to the update settings constant based on the success of the last configuration 
// update attempt.
Procedure WriteUpdateStatus(Val UpdateAdministratorName, Val UpdateScheduled,
	Val UpdateComplete, Val UpdateResult, ScriptDirectory = "", MessagesForEventLog = Undefined) Export
	
	EventLogOperations.WriteEventsToEventLog(MessagesForEventLog);
	
	Status = New Structure;
	Status.Insert("NameOfUpdateAdministrator", UpdateAdministratorName);
	Status.Insert("UpdateScheduled", UpdateScheduled);
	Status.Insert("UpdateComplete", UpdateComplete);
	Status.Insert("ConfigurationUpdateResult", UpdateResult);
	Status.Insert("ScriptDirectory", ScriptDirectory);
	Status.Insert("PatchInstallationResult", Undefined);
	
	StorageValue = Constants.ConfigurationUpdateStatus.Get();
	OldStatus = Undefined;
	If StorageValue <> Undefined Then
		OldStatus = StorageValue.Get();
	EndIf;
	If OldStatus <> Undefined
		AND OldStatus.Property("PatchInstallationResult")
		AND OldStatus.PatchInstallationResult <> Undefined Then
		Status.PatchInstallationResult = OldStatus.PatchInstallationResult;
	EndIf;
	
	Constants.ConfigurationUpdateStatus.Set(New ValueStorage(Status));
	
EndProcedure

// Clears all configuration update settings.
Procedure ResetConfigurationUpdateStatus() Export
	
	Constants.ConfigurationUpdateStatus.Set(New ValueStorage(Undefined));
	
EndProcedure

// Checking access to the ConfigurationUpdate subsystem.
Function HasRightsToInstallUpdate() Export
	Return Users.IsFullUser(, True);
EndFunction

Procedure SendUpdateNotification(Val Username, Val DestinationAddress, Val SuccessfulUpdate)
	
	NotificationSubject = ? (SuccessfulUpdate, NStr("ru = '???????????????? ???????????????????? ???????????????????????? ""%1"", ???????????? %2'; en = '""%1"" configuration is updated, version %2'; pl = 'Konfiguracja zaktualizowana pomy??lnie ""%1"", wersja %2';es_ES = 'Configuraci??n ""%1"" se ha actualizado con ??xito, versi??n %2';es_CO = 'Configuraci??n ""%1"" se ha actualizado con ??xito, versi??n %2';tr = 'Yap??land??rma ""%1"" ba??ar??yla g??ncellendi, s??r??m%2';it = 'La configurazione ""%1"" ?? aggiornata, versione %2';de = 'Konfiguration ""%1"" wurde erfolgreich aktualisiert, Version %2'"), 
		NStr("ru = '???????????? ???????????????????? ???????????????????????? ""%1"", ???????????? %2'; en = '""%1"" configuration update error, version %2'; pl = 'B????d aktualizacji konfiguracji ""%1"", wersja %2';es_ES = 'Configuraci??n ""%1"" error de actualizaci??n, versi??n %2';es_CO = 'Configuraci??n ""%1"" error de actualizaci??n, versi??n %2';tr = 'Yap??land??rma ""%1"" g??ncelleme hatas??, s??r??m%2';it = 'Errore di aggiornamento di configurazione ""%1"", versione %2';de = 'Konfiguration ""%1"" Update Fehler, Version %2'"));
	NotificationSubject = StringFunctionsClientServer.SubstituteParametersToString(NotificationSubject, Metadata.BriefInformation, Metadata.Version);
	
	Details = ?(SuccessfulUpdate, NStr("ru = '???????????????????? ???????????????????????? ?????????????????? ??????????????.'; en = 'The configuration is updated.'; pl = 'Aktualizacja konfiguracji zosta??a zako??czona pomy??lnie.';es_ES = 'Configuraci??n se ha actualizado con ??xito.';es_CO = 'Configuraci??n se ha actualizado con ??xito.';tr = 'Yap??land??rma ba??ar??yla g??ncellendi.';it = 'La configurazione ?? aggiornata.';de = 'Die Konfiguration wurde erfolgreich aktualisiert.'"), 
		NStr("ru = '?????? ???????????????????? ???????????????????????? ?????????????????? ????????????. ?????????????????????? ???????????????? ?? ???????????? ??????????????????????.'; en = 'The configuration update failed. The details have been written to the event log.'; pl = 'Aktualizacja konfiguracji nie powiod??a si??. Szczeg????y zosta??y zapisane w dzienniku wydarze??.';es_ES = 'Actualizaci??n de la configuraci??n ha fallado. Detalles se han grabado en el registro de eventos.';es_CO = 'Actualizaci??n de la configuraci??n ha fallado. Detalles se han grabado en el registro de eventos.';tr = 'Yap??land??rma g??ncellemesi ba??ar??s??z oldu. Ayr??nt??lar olay g??nl??????ne yaz??ld??.';it = 'Aggiornamento dell''applicazione non riuscito. I dettagli sono salvati nel Registro degli eventi.';de = 'Konfigurationsaktualisierung fehlgeschlagen. Details wurden in das Ereignisprotokoll geschrieben.'"));
	Text = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1
		|
		|????????????????????????: %2
		|????????????: %3
		|???????????? ????????????????????: %4'; 
		|en = '%1
		|
		|Configuration: %2
		|Version: %3
		|Connection string: %4'; 
		|pl = '%1
		|
		|Konfiguracja: %2
		|Wersja: %3
		|Wiersz po????czenia: %4';
		|es_ES = '%1
		|
		|Configuraci??n: %2
		|Versi??n: %3
		|L??nea de conexi??n: %4';
		|es_CO = '%1
		|
		|Configuraci??n: %2
		|Versi??n: %3
		|L??nea de conexi??n: %4';
		|tr = '%1
		|
		|Yap??land??rma:
		|%2 S??r??m:
		|%3 Ba??lant?? sat??r??: %4';
		|it = '%1
		|
		|Configurazione: %2
		|Versione: %3
		|Stringa di connessione: %4';
		|de = '%1
		|
		|Konfiguration: %2
		|Version: %3
		|erbindungszeichenfolge: %4'"),
	Details, Metadata.BriefInformation, Metadata.Version, InfoBaseConnectionString());
	
	EmailParameters = New Structure;
	EmailParameters.Insert("Subject", NotificationSubject);
	EmailParameters.Insert("Body", Text);
	EmailParameters.Insert("SendTo", DestinationAddress);
	
	ModuleEmail = Common.CommonModule("EmailOperations");
	ModuleEmail.SendEmailMessage(
		ModuleEmail.SystemAccount(), EmailParameters);
	
EndProcedure

// Returns the event name for writing to the event log.
Function EventLogEvent()
	Return NStr("ru = '???????????????????? ????????????????????????'; en = 'Configuration update'; pl = 'Aktualizacja konfiguracji';es_ES = 'Actualizaci??n de la configuraci??n';es_CO = 'Actualizaci??n de la configuraci??n';tr = 'Yap??land??rma g??ncellemesi';it = 'Aggiornamento della configurazione';de = 'Konfigurations-Update'", CommonClientServer.DefaultLanguageCode());
EndFunction

// Fills the configuration update settings structure and returns them.
//
// Returns:
//   Structure   - an update settings structure.
//
Function DefaultSettings()
	
	Result = New Structure;
	Result.Insert("UpdateMode", ?(Common.FileInfobase(), 0, 2));
	Result.Insert("UpdateDateTime", BegOfDay(CurrentSessionDate()) + 24*60*60);
	Result.Insert("EmailReport", False);
	Result.Insert("EmailAddress", "");
	Result.Insert("SchedulerTaskCode", 0);
	Result.Insert("NameOfUpdateFile", "");
	Result.Insert("CreateBackup", 1);
	Result.Insert("IBBackupDirectoryName", "");
	Result.Insert("RestoreInfobase", True);
	Result.Insert("PatchesFiles", New Array);
	Result.Insert("Patches", Undefined);
	Return Result;

EndFunction

Function ExecuteDeferredHandlers() Export
	
	Return Not StandardSubsystemsServer.IsBaseConfigurationVersion()
		AND InfobaseUpdateInternal.UncompletedHandlersStatus() = "UncompletedStatus";
	
EndFunction

// Gets an extension by ID.
//
Function ExtensionByID(ID) Export
	Filter = New Structure;
	Filter.Insert("UUID", ID);
	Return ConfigurationExtensions.Get(Filter)[0];
EndFunction

#EndRegion
