
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	ProxySettingAtClient = Parameters.ProxySettingAtClient;
	If NOT Parameters.ProxySettingAtClient
		AND NOT Users.IsFullUser(, True) Then
		Raise NStr("ru = 'Недостаточно прав доступа.
			|
			|Настройка прокси-сервера выполняется администратором.'; 
			|en = 'Insufficient access rights.
			|
			|Proxy server is being set up only by administrator.'; 
			|pl = 'Niewystarczające uprawnienia.
			|
			|Serwer proxy jest konfigurowany przez administratora.';
			|es_ES = 'Insuficientes derechos de acceso.
			|
			|Servidor proxy está configurado por el administrador.';
			|es_CO = 'Insuficientes derechos de acceso.
			|
			|Servidor proxy está configurado por el administrador.';
			|tr = 'Yetersiz erişim hakları. 
			|
			|Proxy sunucusu yönetici tarafından yapılandırılmıştır.';
			|it = 'Permessi di accesso non sufficienti.
			|
			|Il server proxy è stato impostato solo dall''amministratore.';
			|de = 'Unzureichende Zugriffsrechte.
			|
			|Proxy-Server wird vom Administrator konfiguriert.'");
	EndIf;
	
	If ProxySettingAtClient Then
		ProxyServerSetting = GetFilesFromInternet.ProxySettingsAtClient();
	Else
		AutoTitle = False;
		Title = NStr("ru = 'Параметры прокси-сервера на сервере 1С:Предприятия'; en = 'Proxy server parameters on 1C:Enterprise server'; pl = 'Parametry serwera prozy na serwerze 1C:Enterprise';es_ES = 'Parámetros del servidor proxy en el servidor de la 1C:Enterprise';es_CO = 'Parámetros del servidor proxy en el servidor de la 1C:Enterprise';tr = '1C:Enterprise sunucusunda proxy sunucu parametreleri';it = 'Parametri server proxy sul server 1C:Enterprise';de = 'Proxy-Server-Einstellungen auf 1C:Enterprise Server'");
		ProxyServerSetting = GetFilesFromInternet.ProxySettingsAtServer();
	EndIf;
	
	UseProxy = True;
	UseSystemSettings = True;
	If TypeOf(ProxyServerSetting) = Type("Map") Then
		
		UseProxy = ProxyServerSetting.Get("UseProxy");
		UseSystemSettings = ProxyServerSetting.Get("UseSystemSettings");
		
		If UseProxy AND NOT UseSystemSettings Then
			
			// Complete the forms with manual settings.
			Server       = ProxyServerSetting.Get("Server");
			User = ProxyServerSetting.Get("User");
			Password       = ProxyServerSetting.Get("Password");
			Port         = ProxyServerSetting.Get("Port");
			BypassProxyOnLocal = ProxyServerSetting.Get("BypassProxyOnLocal");
			ParameterValue = ProxyServerSetting.Get("UseOSAuthentication");
			UseOSAuthentication = ?(ParameterValue = Undefined, 0, Number(ParameterValue));
			
			ExceptionServerAddressesArray = ProxyServerSetting.Get("BypassProxyOnAddresses");
			If TypeOf(ExceptionServerAddressesArray) = Type("Array") Then
				ExceptionServers.LoadValues(ExceptionServerAddressesArray);
			EndIf;
			
			AdditionalProxy = ProxyServerSetting.Get("AdditionalProxySettings");
			
			If TypeOf(AdditionalProxy) <> Type("Map") Then
				AllProtocolsThroughSingleProxy = True;
			Else
				
				// If additional proxy servers are specified in the settings, then read them from the settings.
				// 
				For each ProtocolServer In AdditionalProxy Do
					Protocol             = ProtocolServer.Key;
					ProtocolSettings = ProtocolServer.Value;
					ThisObject["Server" + Protocol] = ProtocolSettings.Address;
					ThisObject["Port"   + Protocol] = ProtocolSettings.Port;
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Proxy server use options:
	// 0 - Do not use proxy server (default value, corresponds to New InternetProxy(False)).
	// 1 - Use proxy server system settings (corresponds to New InternetProxy(True)).
	// 2 - Use custom proxy server settings (corresponds to manual customization of proxy server parameters).
	// In case of the last option, manual modification of proxy server parameters becomes available.
	ProxyServerUseCase = ?(UseProxy, ?(UseSystemSettings = True, 1, 2), 0);
	If ProxyServerUseCase = 0 Then
		InitializeFormItems(ThisObject, EmptyProxyServerSettings());
	ElsIf ProxyServerUseCase = 1 AND Not ProxySettingAtClient Then
		InitializeFormItems(ThisObject, ProxyServerSystemSettings());
	EndIf;
	
	SetVisibilityAvailability(ThisObject);
	
	If Not AccessRight("SaveUserData", Metadata) Then
		ReadOnly = True;
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		CommonClientServer.SetFormItemProperty(Items, "ProxyServerUsageOptions", "RadioButtonType", RadioButtonType.RadioButton);
		CommonClientServer.SetFormItemProperty(Items, "CancelButton", "Visible", False);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ProxySettingAtClient Then
#If WebClient Then
		ShowMessageBox(, NStr("ru = 'В веб-клиенте параметры прокси-сервера необходимо задавать в настройках браузера.'; en = 'Proxy server parameters for web client are entered in the browser settings.'; pl = 'Ustaw parametry serwera proxy klienta sieci Web w ustawieniach przeglądarki.';es_ES = 'Establecer los parámetros del servidor proxy del cliente web en las configuraciones del navegador.';es_CO = 'Establecer los parámetros del servidor proxy del cliente web en las configuraciones del navegador.';tr = 'Tarayıcı ayarlarında web istemcisinin proxy sunucu parametrelerini ayarlayın.';it = 'I parametri del server proxy per il web client sono inseriti nelle impostazioni del Browser.';de = 'Legen Sie die Proxy-Server-Parameter des Web-Clients in den Browsereinstellungen fest.'"));
		Cancel = True;
		Return;
#EndIf
		
		If ProxyServerUseCase = 1 Then
			InitializeFormItems(ThisObject, ProxyServerSystemSettings());
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.AdditionalProxyServerParameters") Then
		
		If TypeOf(SelectedValue) <> Type("Structure") Then
			Return;
		EndIf;
		
		For Each KeyAndValue In SelectedValue Do
			If KeyAndValue.Key <> "BypassProxyOnAddresses" Then
				ThisObject[KeyAndValue.Key] = KeyAndValue.Value;
			EndIf;
		EndDo;
		
		ExceptionServers = SelectedValue.BypassProxyOnAddresses;
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("SelectAndClose", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ProxyServerUsageOptionsOnChange(Item)
	
	UseProxy = (ProxyServerUseCase > 0);
	UseSystemSettings = (ProxyServerUseCase = 1);
	
	ProxySettings = Undefined;
	// Proxy server customization options:
	// 0 - Do not use proxy server (default value, corresponds to New InternetProxy(False)).
	// 1 - Use proxy server system settings (corresponds to New InternetProxy(True)).
	// 2 - Use custom proxy server settings (corresponds to manual customization of proxy server parameters).
	// In case of the last option, manual modification of proxy server parameters becomes available.
	If ProxyServerUseCase = 0 Then
		ProxySettings = EmptyProxyServerSettings();
	ElsIf ProxyServerUseCase = 1 Then
		ProxySettings = ?(ProxySettingAtClient,
							ProxyServerSystemSettings(),
							ProxyServerSystemSettingsAtServer());
	EndIf;
	
	InitializeFormItems(ThisObject, ProxySettings);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AdditionalProxyServerParameters(Command)
	
	// Configure parameters for additional settings.
	FormParameters = New Structure;
	FormParameters.Insert("ReadOnly", Not EditingAvailable);
	
	FormParameters.Insert("AllProtocolsThroughSingleProxy", AllProtocolsThroughSingleProxy);
	
	FormParameters.Insert("Server"     , Server);
	FormParameters.Insert("Port"       , Port);
	FormParameters.Insert("HTTPServer" , HTTPServer);
	FormParameters.Insert("HTTPPort"   , HTTPPort);
	FormParameters.Insert("HTTPSServer", HTTPSServer);
	FormParameters.Insert("HTTPSPort"  , HTTPSPort);
	FormParameters.Insert("FTPServer"  , FTPServer);
	FormParameters.Insert("FTPPort"    , FTPPort);
	
	FormParameters.Insert("BypassProxyOnAddresses", ExceptionServers);
	
	OpenForm("CommonForm.AdditionalProxyServerParameters", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure OKButton(Command)
	
	// Saves proxy server settings and closes the form, passing proxy parameters as returned results.
	// 
	SaveProxyServerSettings();
	
EndProcedure

&AtClient
Procedure CancelButton(Command)
	
	Modified = False;
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtClientAtServerNoContext
Procedure InitializeFormItems(Form, ProxySettings)
	
	If ProxySettings <> Undefined Then
		
		Form.Server       = ProxySettings.Server;
		Form.Port         = ProxySettings.Port;
		Form.HTTPServer   = ProxySettings.HTTPServer;
		Form.HTTPPort     = ProxySettings.HTTPPort;
		Form.HTTPSServer  = ProxySettings.HTTPSServer;
		Form.HTTPSPort    = ProxySettings.HTTPSPort;
		Form.FTPServer    = ProxySettings.FTPServer;
		Form.FTPPort      = ProxySettings.FTPPort;
		Form.User = ProxySettings.User;
		Form.Password       = ProxySettings.Password;
		Form.BypassProxyOnLocal = ProxySettings.BypassProxyOnLocal;
		Form.ExceptionServers.LoadValues(ProxySettings.BypassProxyOnAddresses);
		Form.UseOSAuthentication = ?(ProxySettings.UseOSAuthentication, 1, 0);
		
		// If the settings for all the protocols correspond to the default proxy settings, then a single 
		// proxy is used for all protocols.
		Form.AllProtocolsThroughSingleProxy = (Form.Server = Form.HTTPServer
			AND Form.HTTPServer = Form.HTTPSServer
			AND Form.HTTPSServer = Form.FTPServer
			AND Form.Port = Form.HTTPPort
			AND Form.HTTPPort = Form.HTTPSPort
			AND Form.HTTPSPort = Form.FTPPort);
		
	EndIf;
	
	SetVisibilityAvailability(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetVisibilityAvailability(Form)
	
	// Change the accessibility of the proxy parameter editing group according to the variant of proxy 
	// server use.
	Form.EditingAvailable = (Form.ProxyServerUseCase = 2);
	
	Form.Items.ServerAddressGroup.Enabled = Form.EditingAvailable;
	Form.Items.AuthenticationGroup.Enabled = Form.EditingAvailable;
	Form.Items.BypassProxyOnLocal.Enabled = Form.EditingAvailable;
	
EndProcedure

// Saves proxy server settings interactively as a result of user actions and reflects messages for 
// users, then closes the form and returns proxy server settings.
// 
//
&AtClient
Procedure SaveProxyServerSettings(CloseForm = True)
	
	ProxyServerSetting = New Map;
	
	ProxyServerSetting.Insert("UseProxy", UseProxy);
	ProxyServerSetting.Insert("User"      , User);
	ProxyServerSetting.Insert("Password"            , Password);
	ProxyServerSetting.Insert("Server"            , NormalizedProxyServerAddress(Server));
	ProxyServerSetting.Insert("Port"              , Port);
	ProxyServerSetting.Insert("BypassProxyOnLocal", BypassProxyOnLocal);
	ProxyServerSetting.Insert("BypassProxyOnAddresses", ExceptionServers.UnloadValues());
	ProxyServerSetting.Insert("UseSystemSettings", UseSystemSettings);
	ProxyServerSetting.Insert("UseOSAuthentication", Boolean(UseOSAuthentication));
	
	
	// Configure additional proxy server addresses.
	
	If NOT AllProtocolsThroughSingleProxy Then
		
		AdditionalSettings = New Map;
		If NOT IsBlankString(HTTPServer) Then
			AdditionalSettings.Insert("http",
				New Structure("Address,Port", NormalizedProxyServerAddress(HTTPServer), HTTPPort));
		EndIf;
		
		If NOT IsBlankString(HTTPSServer) Then
			AdditionalSettings.Insert("https",
				New Structure("Address,Port", NormalizedProxyServerAddress(HTTPSServer), HTTPSPort));
		EndIf;
		
		If NOT IsBlankString(FTPServer) Then
			AdditionalSettings.Insert("ftp",
				New Structure("Address,Port", NormalizedProxyServerAddress(FTPServer), FTPPort));
		EndIf;
		
		If AdditionalSettings.Count() > 0 Then
			ProxyServerSetting.Insert("AdditionalProxySettings", AdditionalSettings);
		EndIf;
		
	EndIf;
	
	WriteProxyServerSettingsToInfobase(ProxySettingAtClient, ProxyServerSetting);
	
	Modified = False;
	
	If CloseForm Then
		
		Close(ProxyServerSetting);
		
	EndIf;
	
EndProcedure

// Saves proxy server settings.
&AtServerNoContext
Procedure WriteProxyServerSettingsToInfobase(ProxySettingAtClient, ProxyServerSetting)
	
	If ProxySettingAtClient
	 Or Common.FileInfobase() Then
		
		Common.CommonSettingsStorageSave("ProxyServerSetting", "", ProxyServerSetting);
	Else
		GetFilesFromInternetInternal.SaveServerProxySettings(ProxyServerSetting);
	EndIf;
	RefreshReusableValues();
	
EndProcedure

&AtClientAtServerNoContext
Function EmptyProxyServerSettings()
	
	Result = New Structure;
	Result.Insert("Server"      , "");
	Result.Insert("Port"        , 0);
	Result.Insert("HTTPServer"  , "");
	Result.Insert("HTTPPort"    , 0);
	Result.Insert("HTTPSServer" , "");
	Result.Insert("HTTPSPort"   , 0);
	Result.Insert("FTPServer"   , "");
	Result.Insert("FTPPort"     , 0);
	Result.Insert("User", "");
	Result.Insert("Password"      , "");
	
	Result.Insert("UseOSAuthentication", False);
	
	Result.Insert("BypassProxyOnLocal", False);
	Result.Insert("BypassProxyOnAddresses", New Array);
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Function ProxyServerSystemSettings()

#If WebClient Then

	Return EmptyProxyServerSettings();
	
#Else	
	
	Proxy = New InternetProxy(True);
	
	Result = New Structure;
	Result.Insert("Server", Proxy.Server());
	Result.Insert("Port"  , Proxy.Port());
	
	Result.Insert("HTTPServer" , Proxy.Server("http"));
	Result.Insert("HTTPPort"   , Proxy.Port("http"));
	Result.Insert("HTTPSServer", Proxy.Server("https"));
	Result.Insert("HTTPSPort"  , Proxy.Port("https"));
	Result.Insert("FTPServer"  , Proxy.Server("ftp"));
	Result.Insert("FTPPort"    , Proxy.Port("ftp"));
	
	Result.Insert("User", Proxy.User(""));
	Result.Insert("Password"      , Proxy.Password(""));
	Result.Insert("UseOSAuthentication", Proxy.UseOSAuthentication(""));
	
	Result.Insert("BypassProxyOnLocal",
		Proxy.BypassProxyOnLocal);
	
	BypassProxyOnAddresses = New Array;
	For Each ServerAddress In Proxy.BypassProxyOnAddresses Do
		BypassProxyOnAddresses.Add(ServerAddress);
	EndDo;
	Result.Insert("BypassProxyOnAddresses", BypassProxyOnAddresses);
	
	Return Result;
	
#EndIf
	
EndFunction

&AtServerNoContext
Function ProxyServerSystemSettingsAtServer()
	
	Return ProxyServerSystemSettings();
	
EndFunction

// Returns normalized proxy server address that contains no spaces.
// If there are spaces between meaningful characters, then ignore everything after the first space.
// 
//
// Parameters:
//	ProxyServerAddress (String) - proxy server address to normalize.
//
// Returns: String - normalized proxy server address.
//
&AtClientAtServerNoContext
Function NormalizedProxyServerAddress(Val ProxyServerAddress)
	
	ProxyServerAddress = TrimAll(ProxyServerAddress);
	SpacePosition = StrFind(ProxyServerAddress, " ");
	If SpacePosition > 0 Then
		// If the server address has problems, then skip everything after the first space.
		// 
		ProxyServerAddress = Left(ProxyServerAddress, SpacePosition - 1);
	EndIf;
	
	Return ProxyServerAddress;
	
EndFunction

&AtClient
Procedure SelectAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	SaveProxyServerSettings();
	
EndProcedure

#EndRegion
