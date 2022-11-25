
#Region Variables

&AtClient
Var CurrentContext;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If StandardSubsystemsServer.IsBaseConfigurationVersion() Then
		Raise NStr("ru = 'Текущий режим работы не поддерживается.'; en = 'The current operation mode is not supported.'; pl = 'Bieżący tryb pracy nie jest obsługiwany.';es_ES = 'No se admite el modo actual de trabajo.';es_CO = 'No se admite el modo actual de trabajo.';tr = 'Geçerli çalışma modu desteklenmez.';it = 'La modalità operazione corrente non è supportata.';de = 'Die aktuelle Betriebsart wird nicht unterstützt.'");
	EndIf;
	
	Filter = Parameters.Patches;
	
	If CommonClientServer.IsWebClient()
		Or Common.DataSeparationEnabled()
		Or Common.IsSubordinateDIBNode()
		Or Not CommonClientServer.IsWindowsClient() Then
		Items.FormInstallPatch.Visible = False;
		Items.FormDeletePatch.Visible    = False;
		Items.InformationGroup.Visible           = False;
	EndIf;
	
	RefreshPatchesList();
	
	Items.InstalledPatchesApplicableTo.Visible = False;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure EventLogDecorationClick(Item)
	EventsArray = New Array;
	EventsArray.Add(NStr("ru = 'Исправления. Установка'; en = 'Patch. Install'; pl = 'Korekty. Instalacja';es_ES = 'Correcciones. Instalación';es_CO = 'Correcciones. Instalación';tr = 'Düzeltmeler. Kurulum';it = 'Patch. Installare';de = 'Korrekturen. Installation'"));
	EventsArray.Add(NStr("ru = 'Исправления. Изменение'; en = 'Patch. Change'; pl = 'Korekty. Zmiana';es_ES = 'Correcciones. Cambio';es_CO = 'Correcciones. Cambio';tr = 'Düzeltmeler. Değişiklik';it = 'Patch. Modificare';de = 'Korrekturen. Ändern'"));
	EventsArray.Add(NStr("ru = 'Исправления. Удаление'; en = 'Patch. Delete'; pl = 'Korekty. Usunięcie';es_ES = 'Correcciones. Eliminación';es_CO = 'Correcciones. Eliminación';tr = 'Düzeltmeler. Silme';it = 'Patch. Eliminare';de = 'Korrekturen. Löschung'"));
	Filter = New Structure("EventLogEvent", EventsArray);
	EventLogClient.OpenEventLog(Filter);
EndProcedure

#EndRegion

#Region InstalledPatchesFormTableItemEventHandlers

&AtClient
Procedure InstalledPatchesBeforeDelete(Item, Cancel)
	Cancel = True;
	DeleteExtensions(Item.SelectedRows);
EndProcedure

&AtClient
Procedure InstalledPatchesBeforeAdd(Item, Cancel, Clone, Parent, IsFolder, Parameter)
	Cancel = True;
	Notification = New NotifyDescription("AfterInstallUpdates", ThisObject);
	OpenForm("DataProcessor.InstallUpdates.Form.Form",,,,,, Notification);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure RefreshPatchesList()
	
	InstalledPatches.Clear();
	Items.InstalledPatchesFilePath.Visible = False;
	
	SetPrivilegedMode(True);
	Extensions = ConfigurationExtensions.Get();
	SetPrivilegedMode(False);
	
	For Each Extension In Extensions Do
		
		If Not ConfigurationUpdate.IsPatch(Extension) Then
			Continue;
		EndIf;
		
		If Filter <> Undefined AND Filter.FindByValue(Extension.Name) = Undefined Then
			Continue;
		EndIf;
		
		PatchProperties = ConfigurationUpdate.PatchProperties(Extension.Name);
		
		NewRow = InstalledPatches.Add();
		NewRow.Name = Extension.Name;
		NewRow.Checksum = Base64String(Extension.HashSum);
		NewRow.ExtensionID = Extension.UUID;
		NewRow.Version = Extension.Version;
		If PatchProperties <> Undefined Then
			NewRow.Status = 0;
			NewRow.Details = PatchProperties.Description;
			NewRow.ApplicableTo = PatchApplicableTo(PatchProperties);
		Else
			NewRow.Status = 1;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Function PatchApplicableTo(PatchProperties)
	
	ApplicableTo = New Array;
	For Each Row In PatchProperties.AppliedFor Do
		ApplicableTo.Add(Row.ConfigurationName);
	EndDo;
	
	Return StrConcat(ApplicableTo, Chars.LF);
	
EndFunction

&AtClient
Procedure DeleteExtensions(SelectedRows)
	
	If SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("SelectedRows", SelectedRows);
	
	Notification = New NotifyDescription("DeleteExtensionAfterConfirmation", ThisObject, Context);
	If SelectedRows.Count() > 1 Then
		QuestionText = NStr("ru = 'Удалить выделенные исправления?'; en = 'Do you want to delete the selected patches?'; pl = 'Usunąć zaznaczone korekty?';es_ES = '¿Eliminar las correcciones seleccionadas?';es_CO = '¿Eliminar las correcciones seleccionadas?';tr = 'Seçilen yamalar silinsin mi?';it = 'Cancellare le correzioni evidenziate?';de = 'Die ausgewählten Korrekturen entfernen?'", "ru");
	Else
		QuestionText = NStr("ru = 'Удалить исправление?'; en = 'Do you want to delete the patch?'; pl = 'Usunąć korektę?';es_ES = '¿Eliminar la corrección?';es_CO = '¿Eliminar la corrección?';tr = 'Yama silinsin mi?';it = 'Volete eliminare la patch?';de = 'Fix entfernen?'", "ru");
	EndIf;
	
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure DeleteExtensionAfterConfirmation(Result, Context) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Handler = New NotifyDescription("DeleteExtensionFollowUp", ThisObject, Context);
		
		If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
			Requests = RequestToRevokeExternalModuleUsagePermissions(Context.SelectedRows);
			ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
			ModuleSafeModeManagerClient.ApplyExternalResourceRequests(Requests, ThisObject, Handler);
		Else
			ExecuteNotifyProcessing(Handler, DialogReturnCode.OK);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteExtensionFollowUp(Result, Context) Export
	
	If Result = DialogReturnCode.OK Then
		CurrentContext = Context;
		AttachIdleHandler("DeleteExtensionCompletion", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteExtensionCompletion()
	
	Context = CurrentContext;
	
	Try
		DeleteExtensionsAtServer(Context.SelectedRows);
	Except
		ErrorInformation = ErrorInfo();
		ShowMessageBox(, BriefErrorDescription(ErrorInformation));
		Return;
	EndTry;
	
EndProcedure

&AtServer
Procedure DeleteExtensionsAtServer(SelectedRows)
	
	ExtensionsToDelete = New Array;
	
	ErrorText = "";
	Try
		ExtensionToDelete = "";
		For Each ListItem In InstalledPatches Do
			If SelectedRows.Find(ListItem.GetID()) = Undefined Then
				Continue;
			EndIf;
			Extension = FindExtension(ListItem.ExtensionID);
			If Extension <> Undefined Then
				ExtensionDetails = New Structure;
				ExtensionDetails.Insert("Deleted", False);
				ExtensionDetails.Insert("Extension", Extension);
				ExtensionDetails.Insert("ExtensionData", Extension.GetData());
				ExtensionsToDelete.Add(ExtensionDetails);
			EndIf;
		EndDo;
		Index = ExtensionsToDelete.Count() - 1;
		While Index >= 0 Do
			ExtensionDetails = ExtensionsToDelete[Index];
			DisableSecurityWarnings(ExtensionDetails.Extension);
			ExtensionToDelete = ExtensionDetails.Extension.Synonym;
			ExtensionDetails.Extension.Delete();
			ExtensionToDelete = "";
			ExtensionDetails.Deleted = True;
			Index = Index - 1;
		EndDo;
		
		If Common.SeparatedDataUsageAvailable()
		   AND ConfigurationExtensions.Get().Count() = 0 Then
			
			Catalogs.ExtensionsVersions.OnRemoveAllExtensions();
		EndIf;
	Except
		ErrorInformation = ErrorInfo();
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось удалить расширение ""%1"" по причине:
			           |
			           |%2'; 
			           |en = 'Cannot delete extension ""%1"". Reason:
			           |
			           |%2'; 
			           |pl = 'Nie udało się usunąć rozszerzenie ""%1"" z powodu:
			           |
			           |%2';
			           |es_ES = 'No se ha podido eliminar la extensión ""%1"" a causa de: 
			           |
			           |%2';
			           |es_CO = 'No se ha podido eliminar la extensión ""%1"" a causa de: 
			           |
			           |%2';
			           |tr = '""%1"" uzantısı 
			           |
			           |%2 nedeniyle silinemedi';
			           |it = 'Non è possibile eliminare l''estensione""%1"". Motivo:
			           |
			           |%2';
			           |de = 'Die Erweiterung ""%1"" konnte aus diesem Grund nicht gelöscht werden:
			           |
			           |%2'"),
			ExtensionToDelete,
			BriefErrorDescription(ErrorInformation));
	EndTry;
	
	If Not ValueIsFilled(ErrorText) Then
		Try
			InformationRegisters.ExtensionVersionParameters.UpdateExtensionParameters();
		Except
			ErrorInformation = ErrorInfo();
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'После удаления, при подготовке оставшихся расширений к работе, произошла ошибка:
				           |
				           |%1'; 
				           |en = 'After deleting extensions, an error occurred while preparing the remaining extensions for use:
				           |
				           |%1'; 
				           |pl = 'Po usunięciu, podczas przygotowania pozostałych rozszerzeń do pracy, zaistniał błąd:
				           |
				           |%1';
				           |es_ES = 'Después de eliminar, al preparar las extensiones restantes para usar se ha producido un error:
				           |
				           |%1';
				           |es_CO = 'Después de eliminar, al preparar las extensiones restantes para usar se ha producido un error:
				           |
				           |%1';
				           |tr = 'Silindikten sonra, kalan uzantıları çalışma için hazırlarken bir hata oluştu:
				           |
				           |%1';
				           |it = 'Dopo aver eliminato le estensioni, si è verificato un errore durante la preparazione delle estensioni rimanenti per l''utilizzo:
				           |
				           |%1';
				           |de = 'Nach dem Löschen, während die verbleibenden Erweiterungen für die Arbeit vorbereitet wurden, ist ein Fehler aufgetreten:
				           |
				           |%1'"), BriefErrorDescription(ErrorInformation));
		EndTry;
	EndIf;
	
	If ValueIsFilled(ErrorText) Then
		RecoveryErrorInformation = Undefined;
		RecoveryPerformed = False;
		Try
			For Each ExtensionDetails In ExtensionsToDelete Do
				If Not ExtensionDetails.Deleted Then
					Continue;
				EndIf;
				ExtensionDetails.Extension.Write(ExtensionDetails.ExtensionData);
				RecoveryPerformed = True;
			EndDo;
		Except
			RecoveryErrorInformation = ErrorInfo();
			ErrorText = ErrorText + Chars.LF + Chars.LF
				+ StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'При попытке восстановить удаленные расширения произошла еще одна ошибка:
					           |%1'; 
					           |en = 'Another error occurred while attempting to restore deleted extensions:
					           |%1'; 
					           |pl = 'Podczas próby odzyskania usuniętych rozszerzeń zaistniał jeszcze jeden błąd:
					           |%1';
					           |es_ES = 'Al intentar restablecer las extensiones eliminadas se ha producido un error más:
					           |%1';
					           |es_CO = 'Al intentar restablecer las extensiones eliminadas se ha producido un error más:
					           |%1';
					           |tr = 'Silinmiş uzantıları geri yüklemeye çalışırken bir hata daha oluştu: 
					           |%1';
					           |it = 'Un  altro errore si è registrato durante il tentativo di ripristinare le estensioni eliminate:
					           |%1';
					           |de = 'Beim Versuch, gelöschte Erweiterungen wiederherzustellen, ist noch ein Fehler aufgetreten:
					           |%1'"), BriefErrorDescription(RecoveryErrorInformation));
		EndTry;
		If RecoveryPerformed
		   AND RecoveryErrorInformation = Undefined Then
			
			ErrorText = ErrorText + Chars.LF + Chars.LF
				+ NStr("ru = 'Удаленные расширения были восстановлены.'; en = 'The deleted extensions are restored.'; pl = 'Usunięte rozszerzenia zostały odzyskane.';es_ES = 'Las extensiones eliminadas han sido restablecidas.';es_CO = 'Las extensiones eliminadas han sido restablecidas.';tr = 'Silinmiş uzantılar geri yüklendi.';it = 'Le estensioni eliminate sono state ripristinate.';de = 'Entfernte Erweiterungen wurden wiederhergestellt.'");
		EndIf;
	EndIf;
	
	If ValueIsFilled(ErrorText) Then
		Raise ErrorText;
	EndIf;
	
	RefreshPatchesList();
	
EndProcedure

&AtServer
Function FindExtension(ExtensionID)
	
	Filter = New Structure;
	Filter.Insert("UUID", New UUID(ExtensionID));
	SetPrivilegedMode(True);
	Extensions = ConfigurationExtensions.Get(Filter);
	SetPrivilegedMode(False);
	
	Extension = Undefined;
	
	If Extensions.Count() = 1 Then
		Extension = Extensions[0];
	EndIf;
	
	Return Extension;
	
EndFunction

&AtServer
Procedure DisableSecurityWarnings(Extension)
	
	If Common.HasUnsafeActionProtection() Then
		Extension.UnsafeActionProtection = Common.ProtectionWithoutWarningsDetails();
	EndIf;
	
EndProcedure

&AtServer
Function RequestToRevokeExternalModuleUsagePermissions(SelectedRows)
	
	Permissions = New Array;
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	For Each RowID In SelectedRows Do
		CurrentExtension = InstalledPatches.FindByID(RowID);
		Permissions.Add(ModuleSafeModeManager.PermissionToUseExternalModule(
			CurrentExtension.Name, CurrentExtension.Checksum));
	EndDo;
	
	Requests = New Array;
	Requests.Add(ModuleSafeModeManager.RequestToCancelPermissionsToUseExternalResources(
		Common.MetadataObjectID("InformationRegister.ExtensionVersionParameters"),
		Permissions));
		
	Return Requests;
	
EndFunction

&AtClient
Procedure AfterInstallUpdates(Result, AdditionalParameters) Export
	RefreshPatchesList();
EndProcedure

#EndRegion