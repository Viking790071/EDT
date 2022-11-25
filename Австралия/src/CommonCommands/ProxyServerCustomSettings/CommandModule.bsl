
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
#If WebClient Then
	ShowMessageBox(, NStr("ru = 'В веб-клиенте параметры прокси-сервера необходимо задавать в настройках браузера.'; en = 'Proxy server parameters for web client are entered in the browser settings.'; pl = 'Ustaw parametry serwera proxy klienta sieci Web w ustawieniach przeglądarki.';es_ES = 'Establecer los parámetros del servidor proxy del cliente web en las configuraciones del navegador.';es_CO = 'Establecer los parámetros del servidor proxy del cliente web en las configuraciones del navegador.';tr = 'Tarayıcı ayarlarında web istemcisinin proxy sunucu parametrelerini ayarlayın.';it = 'I parametri del server proxy per il web client sono inseriti nelle impostazioni del Browser.';de = 'Legen Sie die Proxy-Server-Parameter des Web-Clients in den Browsereinstellungen fest.'"));
	Return;
#EndIf
	
	OpenForm("CommonForm.ProxyServerParameters", New Structure("ProxySettingAtClient", True));
	
EndProcedure

#EndRegion
