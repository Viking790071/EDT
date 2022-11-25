
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Not Parameters.OpenProgrammatically Then
		Raise
			NStr("ru = 'Обработка не предназначена для непосредственного использования.'; en = 'The data processor is not intended for direct usage.'; pl = 'Opracowanie nie jest przeznaczone do bezpośredniego użycia.';es_ES = 'Procesador de datos no está destinado al uso directo.';es_CO = 'Procesador de datos no está destinado al uso directo.';tr = 'Veri işlemcisi doğrudan kullanıma yönelik değil.';it = 'L''elaboratore dati non è inteso per un uso diretto.';de = 'Der Datenprozessor ist nicht für den direkten Gebrauch bestimmt.'");
	EndIf;
	
	SkipRestart = Parameters.SkipRestart;
	
	DocumentTemplate = DataProcessors.LegitimateSoftware.GetTemplate(
		"UpdateDistributionTerms");
	
	#If NOT ThickClientManagedApplication AND NOT WebClient AND NOT ExternalConnection Then
		
		DocumentTemplate.TemplateLanguageCode = "en";
		
	#EndIf
	
	WarningText = DocumentTemplate.GetText();
	ConfirmSoftwareLicense = 0; // The user needs to explicitly select one of the options.
	Items.Comment.Visible = Parameters.ShowRestartWarning;
	FileInfobase = Common.FileInfobase();
	
	// StandardSubsystems.MonitoringCenter
	MonitoringCenterExists = Common.SubsystemExists("StandardSubsystems.MonitoringCenter");
	If MonitoringCenterExists Then
		ModuleMonitoringCenterInternal = Common.CommonModule("MonitoringCenterInternal");
		MonitoringCenterParameters = ModuleMonitoringCenterInternal.GetMonitoringCenterParametersExternalCall();
				
		If (NOT MonitoringCenterParameters.EnableMonitoringCenter AND  NOT MonitoringCenterParameters.ApplicationInformationProcessingCenter) Then
			AllowSendStatistics = True;
			Items.SendStatisticsGroup.Visible = True;
		Else
			AllowSendStatistics = True;
			Items.SendStatisticsGroup.Visible = False;	
		EndIf;
	Else
		Items.SendStatisticsGroup.Visible = False;
	EndIf;
	// End StandardSubsystems.MonitoringCenter
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	#If MobileClient Then
		
		ShowMessageBox(, NStr("ru = 'Для корректной работы необходим режим толстого, тонкого или ВЕБ-клиента.'; en = 'Thin, thick, or web client mode is required.'; pl = 'Do prawidłowego działania wymagany jest gruby, cienki tryb klienta lub tryb klienta WEB.';es_ES = 'Para el funcionamiento correcto es necesario el modo del cliente grueso, ligero o cliente web.';es_CO = 'Para el funcionamiento correcto es necesario el modo del cliente grueso, ligero o cliente web.';tr = 'Doğu çalışma için kalın, ince veya WEB istemci modu gerekmektedir.';it = 'La modalità Thin, thick, o web client è richiesta.';de = 'Für den korrekten Betrieb ist es notwendig, den Thick-, Thin- oder WEB-Client Modus zu verwenden.'"));
		Cancel = True;
		Return;
		
	#EndIf
	
	If FileInfobase
	   AND StrFind(LaunchParameter, "UpdateAndExit") > 0 Then
		
		WriteLegitimateSoftwareConfirmation();
		Cancel = True;
		StandardSubsystemsClient.SetFormStorage(ThisObject, True);
		AttachIdleHandler("ConfirmSoftwareLicense", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ContinueFormMainActions(Command)
	
	Result = ConfirmSoftwareLicense = 1;
	
	If Result <> True Then
		If Parameters.ShowRestartWarning AND NOT SkipRestart Then
			Terminate();
		EndIf;
	Else
		WriteLegalityAndStatisticsSendingConfirmation(AllowSendStatistics);
	EndIf;
	
	Close(Result);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	ElsIf Result <> True Then
		If Parameters.ShowRestartWarning AND NOT SkipRestart Then
			Terminate();
		EndIf;
	Else
		WriteLegalityAndStatisticsSendingConfirmation(AllowSendStatistics);
	EndIf;
	
	Notify("LegitimateSoftware", Result);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ConfirmSoftwareLicense()
	
	StandardSubsystemsClient.SetFormStorage(ThisObject, False);
	
	ExecuteNotifyProcessing(ThisObject.OnCloseNotifyDescription, True);
	
EndProcedure

&AtServerNoContext
Procedure WriteLegalityAndStatisticsSendingConfirmation(AllowSendStatistics)
	
	WriteLegitimateSoftwareConfirmation();
	
	SetPrivilegedMode(True);
	
	MonitoringCenterExists = Common.SubsystemExists("StandardSubsystems.MonitoringCenter");
	If MonitoringCenterExists Then
		ModuleMonitoringCenterInternal = Common.CommonModule("MonitoringCenterInternal");
		
		SendStatisticsParameters = New Structure("EnableMonitoringCenter, ApplicationInformationProcessingCenter", Undefined, Undefined);
		SendStatisticsParameters = ModuleMonitoringCenterInternal.GetMonitoringCenterParametersExternalCall(SendStatisticsParameters);
		
		If (NOT SendStatisticsParameters.EnableMonitoringCenter AND SendStatisticsParameters.ApplicationInformationProcessingCenter) Then
			// Statistics are configured to be sent to a third-party developer. Do not change settings.
			// 
			//
		Else
			ModuleMonitoringCenterInternal.SetMonitoringCenterParameterExternalCall("EnableMonitoringCenter", AllowSendStatistics);
			ModuleMonitoringCenterInternal.SetMonitoringCenterParameterExternalCall("ApplicationInformationProcessingCenter", False);
			ModuleMonitoringCenterInternal.SetMonitoringCenterParameterExternalCall("UpdateInstalled", True);
			
			SetDefaultSendServiceParameters();
			
			If AllowSendStatistics Then
				ScheduledJob = ModuleMonitoringCenterInternal.GetScheduledJobExternalCall("StatisticsDataCollectionAndSending", True);
				ModuleMonitoringCenterInternal.SetDefaultScheduleExternalCall(ScheduledJob);
			Else
				ModuleMonitoringCenterInternal.DeleteScheduledJobExternalCall("StatisticsDataCollectionAndSending");
			EndIf;
			
			StartSendUpdateInstalledPackage();
			
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure WriteLegitimateSoftwareConfirmation()
	SetPrivilegedMode(True);
	InfobaseUpdateInternal.WriteLegitimateSoftwareConfirmation();
EndProcedure

&AtServerNoContext
Procedure StartSendUpdateInstalledPackage()
	
	SetPrivilegedMode(True);
	LaunchParameterStr = SessionParameters.ClientParametersAtServer.Get("LaunchParameter"); 
	SetPrivilegedMode(False);
	
	If StrFind(LaunchParameterStr, "WithoutSendingStatistics") > 0 Then
		Return;
	EndIf;
	
	JobSettings = New Structure;
	JobSettings.Insert("Iterator", 0);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.WaitForCompletion = 0;
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Send information about updating'; ru = 'Отправить информацию об обновлении';pl = 'Wyślij informacje dotyczące aktualizacji';es_ES = 'Enviar información sobre la actualización';es_CO = 'Enviar información sobre la actualización';tr = 'Güncelleme hakkında bilgi gönder';it = 'Inviare informazioni sull''aggiornamento';de = 'Informationen über Aktualisierung senden'");
	
	TimeConsumingOperations.ExecuteInBackground(
		"MonitoringCenterInternal.SendUpdateInstalledPackage",
		JobSettings,
		ExecutionParameters);
	
EndProcedure

&AtServerNoContext
Procedure SetDefaultSendServiceParameters()
	
	Parameters = New Structure;
	Parameters.Insert("Server");
	Parameters.Insert("ResourceAddress");
	MonitoringCenterParameters = MonitoringCenterInternal.GetMonitoringCenterParametersExternalCall(Parameters);
	
	If Not ValueIsFilled(MonitoringCenterParameters.Server) Or Not ValueIsFilled(MonitoringCenterParameters.ResourceAddress) Then
		MonitoringCenterInternal.SetDefaultSendServiceParametersExternalCall(True);
	EndIf;
	
EndProcedure

#EndRegion