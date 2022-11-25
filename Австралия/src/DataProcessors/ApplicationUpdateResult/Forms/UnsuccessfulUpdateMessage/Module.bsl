
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Preparing to open the form for data resynchronization before startup with two options, 
	// "Synchronize and continue" and "Continue".
	If ValueIsFilled(Parameters.DetailedErrorPresentation)
	   AND Common.SubsystemExists("StandardSubsystems.DataExchange")
	   AND Common.IsSubordinateDIBNode() Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.EnableDataExchangeMessageImportRecurrenceBeforeStart();
	EndIf;
	
	If ValueIsFilled(Parameters.DetailedErrorPresentation) Then
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Error,
			, , Parameters.DetailedErrorPresentation);
	EndIf;
	
	ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'При обновлении версии программы возникла ошибка:
		|
		|%1'; 
		|en = 'Application update error:
		|
		|%1'; 
		|pl = 'Przy aktualizacji wersji programu wystąpił błąd:
		|
		|%1';
		|es_ES = 'Al actualizar la versión del programa se ha producido un error:
		|
		|%1';
		|es_CO = 'Al actualizar la versión del programa se ha producido un error:
		|
		|%1';
		|tr = 'Uygulama güncelleme hatası:
		|
		|%1';
		|it = 'Errore aggiornamento applicazione:
		|
		|%1';
		|de = 'Beim Aktualisieren der Softwareversion ist ein Fehler aufgetreten:
		|
		|%1'"),
		Parameters.BriefErrorPresentation);
	
	Items.ErrorMessageText.Title = ErrorMessageText;
	
	UpdateStartTime = Parameters.UpdateStartTime;
	UpdateEndTime = CurrentSessionDate();
	
	If Not Users.IsFullUser(, True) Then
		Items.FormOpenExternalDataProcessor.Visible = False;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
		UseSecurityProfiles = ModuleSafeModeManager.UseSecurityProfiles();
	Else
		UseSecurityProfiles = False;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		ModuleSoftwareUpdate = Common.CommonModule("ConfigurationUpdate");
		ScriptDirectory = ModuleSoftwareUpdate.ScriptDirectory();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not IsBlankString(ScriptDirectory) Then
		ModuleSoftwareUpdateClient = CommonClient.CommonModule("ConfigurationUpdateClient");
		ModuleSoftwareUpdateClient.WriteErrorProtocolFile(ScriptDirectory);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ShowUpdateResultInfoClick(Item)
	
	FormParameters = New Structure;
	FormParameters.Insert("StartDate", UpdateStartTime);
	FormParameters.Insert("EndDate", UpdateEndTime);
	FormParameters.Insert("RunNotInBackground", True);
	
	OpenForm("DataProcessor.EventLog.Form.EventLog", FormParameters,,,,,, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ExitApplication(Command)
	Close(True);
EndProcedure

&AtClient
Procedure RestartApplication(Command)
	Close(False);
EndProcedure

&AtClient
Procedure OpenExternalDataProcessor(Command)
	
	ContinuationHandler = New NotifyDescription("OpenExternalDataProcessorAfterConfirmSafety", ThisObject);
	OpenForm("DataProcessor.ApplicationUpdateResult.Form.SecurityWarning",,,,,, ContinuationHandler);
	
EndProcedure

&AtClient
Procedure OpenExternalDataProcessorAfterConfirmSafety(Result, AdditionalParameters) Export
	If Result <> True Then
		Return;
	EndIf;
	
	If UseSecurityProfiles Then
		
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.OpenExternalDataProcessorOrReport(ThisObject);
		Return;
		
	EndIf;
	
#If WebClient Then
	Notification = New NotifyDescription("OpenExternalDataProcessorWithoutExtension", ThisObject);
	BeginPutFile(Notification,,, True, UUID);
	Return;
#EndIf
	
	OpenFileDialog = New FileDialog(FileDialogMode.Open);
	OpenFileDialog.Filter = NStr("ru = 'Внешняя обработка'; en = 'External data processor'; pl = 'Zewnętrzny procesor danych';es_ES = 'Procesador de datos externo';es_CO = 'Procesador de datos externo';tr = 'Harici veri işlemcisi';it = 'Elaboratore dati esterno';de = 'Externer Datenprozessor'") + "(*.epf)|*.epf";
	OpenFileDialog.Multiselect = False;
	OpenFileDialog.Title = NStr("ru = 'Выберите внешнюю обработку'; en = 'Select external data processor'; pl = 'Wybierz zewnętrzne opracowanie';es_ES = 'Seleccionar el procesador de datos externo';es_CO = 'Seleccionar el procesador de datos externo';tr = 'Harici veri işlemcisi seç';it = 'Selezionate elaboratore dati esterno';de = 'Wählen Sie einen externen Datenprozessor'");
	
	NotifyDescription = New NotifyDescription("OpenExternalDataProcessorCompletion", ThisObject);
	OpenFileDialog.Show(NotifyDescription);
EndProcedure

&AtClient
Procedure OpenExternalDataProcessorCompletion(Result, AdditionalParameters) Export
	
	If Result <> Undefined
		AND Result.Count() = 1 Then
		FullFileName = Result[0];
		SelectedDataProcessor = New BinaryData(FullFileName);
		AddressInTempStorage = PutToTempStorage(SelectedDataProcessor, UUID);
		ExternalDataProcessorName = AttachExternalDataProcessor(AddressInTempStorage);
		OpenForm(ExternalDataProcessorName + ".Form");
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenExternalDataProcessorWithoutExtension(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		ExternalDataProcessorName = AttachExternalDataProcessor(Address);
		OpenForm(ExternalDataProcessorName + ".Form",, ThisObject,,,,, FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

&AtServer
Function AttachExternalDataProcessor(AddressInTempStorage)
	
	If Not Users.IsFullUser(, True) Then
		Raise NStr("ru = 'Недостаточно прав доступа.'; en = 'Insufficient access rights.'; pl = 'Niewystarczające prawa dostępu.';es_ES = 'Insuficientes derechos de acceso.';es_CO = 'Insuficientes derechos de acceso.';tr = 'Yetersiz erişim yetkileri.';it = 'Diritti di accesso insufficienti.';de = 'Unzureichende Zugriffsrechte.'");
	EndIf;
	
	Manager = ExternalDataProcessors;
	
	If Common.HasUnsafeActionProtection() Then
		DataProcessorName = Manager.Connect(AddressInTempStorage, , False,
			Common.ProtectionWithoutWarningsDetails());
	Else
		DataProcessorName = Manager.Connect(AddressInTempStorage, , False);
	EndIf;
	
	Return Manager.Create(DataProcessorName, False).Metadata().FullName();
	
EndFunction

#EndRegion
