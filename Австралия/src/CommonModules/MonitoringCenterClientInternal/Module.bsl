#Region Internal

Procedure OnExecuteStandardPeriodicChecksAtClient(Parameters) Export
	
	Windows = GetWindows();
	ActiveWindows = 0;
	If Windows <> Undefined Then
		For Each CurWindow In Windows Do
		If Not CurWindow.IsMain Then
			ActiveWindows = ActiveWindows + 1;
		EndIf;
		EndDo;
	EndIf;
	
	ApplicationParametersMonitoringCenter = GetApplicationParameters();
	ApplicationParametersMonitoringCenter["ClientInformation"].Insert("ActiveWindows", ActiveWindows);
	
	Parameters.Insert("MonitoringCenter", New FixedMap(ApplicationParametersMonitoringCenter));
	
	Measurements = New Map;
	Measurements.Insert(0, New Array);
	Measurements.Insert(1, New Map);
	Measurements.Insert(2, New Map);
	ApplicationParametersMonitoringCenter.Insert("Measurements", Measurements);
	
EndProcedure

Procedure AfterStandardPeriodicChecksAtClient(Parameters) Export
    
    ApplicationParametersMonitoringCenter = GetApplicationParameters();
    ApplicationParametersMonitoringCenter.Insert("RegisterBusinessStatistics", Parameters.MonitoringCenter["RegisterBusinessStatistics"]);
	
	If Parameters.MonitoringCenter.Get("RequestForGettingDumps") = True Then
		NotifyRequestForReceivingDumps();
		SetApplicationParametersMonitoringCenter("PromptForFullDumpDisplayed", True);
	EndIf;
	If Parameters.MonitoringCenter.Get("RequestForGettingContacts") = True Then
		NotifyContactInformationRequest();
		SetApplicationParametersMonitoringCenter("RequestForGettingContactsDisplayed", True);
	EndIf;
	If Parameters.MonitoringCenter.Get("DumpsSendingRequest") = True Then
		DumpsInformation = Parameters.MonitoringCenter.Get("DumpsInformation");
		If DumpsInformation <> ApplicationParametersMonitoringCenter["DumpsInformation"] Then
			NotifyRequestForSendingDumps();
			SetApplicationParametersMonitoringCenter("DumpsInformation", DumpsInformation);
		EndIf;
	EndIf;
        
EndProcedure

#EndRegion

#Region Private

Procedure OnStart(Parameters) Export
	
	MonitoringCenterApplicationParameters = GetApplicationParameters();
	
	If Not MonitoringCenterApplicationParameters["ClientInformation"]["ClientParameters1"]["PromptForFullDump"] = True Then
		Return;
	EndIf;
	
	If MonitoringCenterApplicationParameters["ClientInformation"]["ClientParameters1"]["RequestForGettingDumps"] = True Then
		AttachIdleHandler("MonitoringCenterDumpCollectionAndSendingRequest",90, True);
		SetApplicationParametersMonitoringCenter("PromptForFullDumpDisplayed", True);
	EndIf;
	If MonitoringCenterApplicationParameters["ClientInformation"]["ClientParameters1"]["SendingRequest"] = True Then
		AttachIdleHandler("MonitoringCenterDumpSendingRequest",90, True);
		DumpsInformation = MonitoringCenterApplicationParameters["ClientInformation"]["ClientParameters1"]["DumpsInformation"];
		SetApplicationParametersMonitoringCenter("DumpsInformation", DumpsInformation);
	EndIf;
	If MonitoringCenterApplicationParameters["ClientInformation"]["ClientParameters1"]["RequestForGettingContacts"] = True Then
		AttachIdleHandler("MonitoringCenterContactInformationRequest",120, True);
		SetApplicationParametersMonitoringCenter("RequestForGettingContactsDisplayed", True);
	EndIf;
	
EndProcedure

Function GetApplicationParameters() Export
	
	If ApplicationParameters = Undefined Then
		ApplicationParameters = New Map;
	EndIf;
	
	ParameterName = "StandardSubsystems.MonitoringCenter";
	If ApplicationParameters[ParameterName] = Undefined Then
	
		ClientParameters1 = ClientParameters1();
	
		ApplicationParameters.Insert(ParameterName, New Map);
		MonitoringCenterApplicationParameters = ApplicationParameters[ParameterName];
		MonitoringCenterApplicationParameters.Insert("RegisterBusinessStatistics", ClientParameters1["RegisterBusinessStatistics"]);
		MonitoringCenterApplicationParameters.Insert("PromptForFullDumpDisplayed", ClientParameters1["PromptForFullDumpDisplayed"]);
		MonitoringCenterApplicationParameters.Insert("DumpsInformation", ClientParameters1["DumpsInformation"]);		
		
		Measurements = New Map;
		Measurements.Insert(0, New Array);
		Measurements.Insert(1, New Map);
		Measurements.Insert(2, New Map);
		MonitoringCenterApplicationParameters.Insert("Measurements", Measurements);

		MonitoringCenterApplicationParameters.Insert("ClientInformation", GetClientInformation());

	Else
	
		MonitoringCenterApplicationParameters = ApplicationParameters["StandardSubsystems.MonitoringCenter"];
	
	EndIf;
	
	Return MonitoringCenterApplicationParameters; 
	
EndFunction

Function GetClientInformation()

	ClientInformation = New Map;

	InformationScreens = New Array;
	ClientScreens = GetClientDisplaysInformation();
	For Each CurScreen In ClientScreens Do
	    InformationScreens.Add(ScreenResolutionInString(CurScreen));
	EndDo;

	ClientInformation.Insert("ClientScreens", InformationScreens);
	ClientInformation.Insert("ClientParameters1", ClientParameters1());
	ClientInformation.Insert("SystemInformation", GetSystemInformation());
	ClientInformation.Insert("ActiveWindows", 0);

	Return ClientInformation;

EndFunction

Function ScreenResolutionInString(Screen)

	Return Format(Screen.Width, "NG=0") + "x" + Format(Screen.Height, "NG=0");

EndFunction

Function ClientParameters1()
	
	ClientParameters1 = CommonClientServer.StructureProperty(StandardSubsystemsClient.ClientParametersOnStart(),"MonitoringCenter");
	If ClientParameters1 = Undefined Then
		ClientParameters1 = New Structure;
		ClientParameters1.Insert("SessionTimeZone", Undefined);
		ClientParameters1.Insert("UserHash", Undefined);
		ClientParameters1.Insert("RegisterBusinessStatistics", False);
		ClientParameters1.Insert("PromptForFullDump", False);
		ClientParameters1.Insert("PromptForFullDumpDisplayed", False);
		ClientParameters1.Insert("DumpsInformation", "");
		ClientParameters1.Insert("RequestForGettingDumps", False);
		ClientParameters1.Insert("SendingRequest", False);
		ClientParameters1.Insert("RequestForGettingContacts", False);
		ClientParameters1.Insert("RequestForGettingContactsDisplayed", False);
	EndIf;
	
	ClientParametersInformation = New Map;
	For Each CurParameter In ClientParameters1 Do
		ClientParametersInformation.Insert(CurParameter.Key, CurParameter.Value);
	EndDo;
	
	Return ClientParametersInformation; 
	
EndFunction

Function GetSystemInformation()
	
	SysInfo = New SystemInfo();
	
	SysInfoInformation = New Map;
	SysInfoInformation.Insert("OSVersion", StrReplace(SysInfo.OSVersion, ".", "☺"));
	SysInfoInformation.Insert("RAM", Format((Int(SysInfo.RAM/512) + 1) * 512, "NG=0"));
	SysInfoInformation.Insert("Processor", StrReplace(SysInfo.Processor, ".", "☺"));
	SysInfoInformation.Insert("PlatformType", StrReplace(String(SysInfo.PlatformType), ".", "☺"));
	
	UserAgentInformation = "";
	#If ThickClientManagedApplication Then
		UserAgentInformation = "ThickClientManagedApplication";
	#ElsIf ThickClientOrdinaryApplication Then
		UserAgentInformation = "ThickClient";
	#ElsIf ThinClient Then
		UserAgentInformation = "ThinClient";
	#ElsIf WebClient Then
		UserAgentInformation = "WebClient";
	#EndIf
	
	SysInfoInformation.Insert("UserAgentInformation", UserAgentInformation);
	
	Return SysInfoInformation; 
	
EndFunction

Procedure SetApplicationParametersMonitoringCenter(Parameter, Value)
	ParameterName = "StandardSubsystems.MonitoringCenter";
	If ApplicationParameters[ParameterName] = Undefined Then
		Return;
	Else
		MonitoringCenterApplicationParameters = ApplicationParameters["StandardSubsystems.MonitoringCenter"];
		MonitoringCenterApplicationParameters.Insert(Parameter, Value);
	EndIf;
EndProcedure

Procedure NotifyRequestForReceivingDumps() Export
	ShowUserNotification(
		NStr("en = 'Error reports'; ru = 'Отчеты об ошибках'; pl = 'Raporty o błędach';es_ES = 'Informe de error';es_CO = 'Informe de error';tr = 'Hata raporları';it = 'Report di errore';de = 'Fehlerberichte'"),
		"e1cib/app/DataProcessor.MonitoringCenterSettings.Form.RequestForErrorReportsCollectionAndSending",
		NStr("en = 'Provide reports on occurred errors'; ru = 'Предоставьте отчеты о возникающих ошибках'; pl = 'Prześlij raporty o występujących błędach';es_ES = 'Proporcionar informes sobre los errores ocurridos';es_CO = 'Proporcionar informes sobre los errores ocurridos';tr = 'Oluşan hatalarla ilgili rapor sağla';it = 'Fornire report sugli errori verificatisi';de = 'Berichte über aufgetretene Fehler bieten'"),
		PictureLib.Warning32,
		UserNotificationStatus.Important, "RequestForGettingDumps");
EndProcedure

Procedure NotifyRequestForSendingDumps() Export
	ShowUserNotification(
		NStr("en = 'Error reports'; ru = 'Отчеты об ошибках'; pl = 'Raporty o błędach';es_ES = 'Informe de error';es_CO = 'Informe de error';tr = 'Hata raporları';it = 'Report di errore';de = 'Fehlerberichte'"),
		"e1cib/app/DataProcessor.MonitoringCenterSettings.Form.RequestForSendingErrorReports",
		NStr("en = 'Send reports on occurred errors'; ru = 'Отправьте отчеты о возникающих ошибках'; pl = 'Wyślij raporty o występujących błędach';es_ES = 'Enviar informes sobre los errores ocurridos';es_CO = 'Enviar informes sobre los errores ocurridos';tr = 'Oluşan hatalarla ilgili rapor gönder';it = 'Inviare report sugli errori verificatisi';de = 'Berichte über aufgetretene Fehler senden'"),
		PictureLib.Warning32,
		UserNotificationStatus.Important, "DumpsSendingRequest");
EndProcedure

Procedure NotifyContactInformationRequest() Export
	ShowUserNotification(
		NStr("en = 'Performance issues'; ru = 'Проблемы производительности'; pl = 'Problemy wydajności';es_ES = 'Problemas de rendimiento';es_CO = 'Problemas de rendimiento';tr = 'Performans sorunları';it = 'Problemi di prestazione';de = 'Leistungsprobleme'"),
		New NotifyDescription("OnClickNotifyContactInformationRequest",
			ThisObject, True),
		NStr("en = 'Inform of performance issues'; ru = 'Сообщить о проблемах производительности'; pl = 'Zgłoś problemy z wydajnością';es_ES = 'Informar de los problemas de eficiencia';es_CO = 'Informar de los problemas de eficiencia';tr = 'Performans sorunlarını bildir';it = 'Informazioni su problemi di prestazione';de = 'Leistungsprobleme melden'"),
		PictureLib.Warning32,
		UserNotificationStatus.Important, "ContactInformationRequest");
EndProcedure

Procedure OnClickNotifyContactInformationRequest(OnRequest) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("OnRequest", OnRequest);
	OpenForm("DataProcessor.MonitoringCenterSettings.Form.SendContactInformation", FormParameters);
	
EndProcedure

#EndRegion