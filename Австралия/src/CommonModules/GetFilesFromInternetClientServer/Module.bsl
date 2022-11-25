#Region Public

// Returns InternetProxy object for Internet access.
// The following protocols are acceptable for creating InternetProxy: http, https, ftp, and ftps.
//
// Parameters:
//    URLOrProtocol - String - url in the following format: [Protocol://]<Server>/<Path to file on 
//                              server>, or protocol ID (http, ftp, ...).
//
// Returns:
//    InternetProxy - describes proxy server parameters for various protocols.
//                     If the network protocol scheme cannot be recognized, the proxy will be 
//                     created based on the HTTP protocol.
//
Function GetProxy(Val URLOrProtocol) Export
	
#If WebClient Then
	Raise NStr("ru='Прокси не доступен в веб-клиенте.'; en = 'Proxy is not available in web client.'; pl = 'Serwer proxy nie jest dostępny w kliencie Web.';es_ES = 'Proxy no disponible en el cliente web.';es_CO = 'Proxy no disponible en el cliente web.';tr = 'Proxy web istemcide kullanılamaz.';it = 'Il proxy non è disponibile nel web client';de = 'Der Proxy ist im Webclient nicht verfügbar.'");
#Else
	
	AcceptableProtocols = New Map();
	AcceptableProtocols.Insert("HTTP",  True);
	AcceptableProtocols.Insert("HTTPS", True);
	AcceptableProtocols.Insert("FTP",   True);
	AcceptableProtocols.Insert("FTPS",  True);
	
	ProxyServerSetting = ProxyServerSetting();
	
	If StrFind(URLOrProtocol, "://") > 0 Then
		Protocol = SplitURL(URLOrProtocol).Protocol;
	Else
		Protocol = Lower(URLOrProtocol);
	EndIf;
	
	If AcceptableProtocols[Upper(Protocol)] = Undefined Then
		Protocol = "HTTP";
	EndIf;
	
	Return NewInternetProxy(ProxyServerSetting, Protocol);
	
#EndIf
	
EndFunction

// Splits URL: protocol, server, path to resource
//
// Parameters:
//    URL - String - link to a web resource.
//
// Returns:
//    Structure - a structure containing fields:
//        * Protocol - String - protocol of access to the resource.
//        * ServerName - String - server the resource is located on.
//        * PathToFileAtServer - String - path to the resource on the server.
//
Function SplitURL(Val URL) Export
	
	URLStructure = CommonClientServer.URIStructure(URL);
	
	Result = New Structure;
	Result.Insert("Protocol", ?(IsBlankString(URLStructure.Schema), "http", URLStructure.Schema));
	Result.Insert("ServerName", URLStructure.ServerName);
	Result.Insert("PathToFileAtServer", URLStructure.PathAtServer);
	
	Return Result;
	
EndFunction

// Splits the URI string and returns it as a structure.
// The following normalizations are described based on RFC 3986.
//
// Parameters:
//     URIString - String - link to the resource in the following format:
//                          <schema>://<username>:<password>@<domain>:<port>/<path>?<query_string>#<fragment_id.
//
// Returns:
//    Structure - composite parts of the URI according to the format:
//        * Scheme - String - URI scheme.
//        * Username - String - user name.
//        * Password - String - user password.
//        * ServerName - String - part <host>:<port> of the input parameter.
//        * Host - String - server name.
//        * Port - String - server port.
//        * PathAtServer - String - part <path>?<parameters>#<anchor> of the input parameter.
//
Function URIStructure(Val URIString) Export
	
	Return CommonClientServer.URIStructure(URIString);
	
EndFunction

// Returns the parameter structure for getting a file from the Internet.
//
// Returns:
//  Structure - with the following properties:
//     * PathForSaving - String - path on the server (including file name) for saving the downloaded file.
//                                                     Not filled in if a file is saved to the temporary storage.
//     * User - String - user that established the connection.
//     * Password - String - password of the user that established the connection.
//     * Port - Number - port used for connecting to the server.
//     * Timeout - Number - file getting timeout in seconds.
//     * SecureConnection - Boolean - indicates the use of secure ftps or https connection.
//                                    - SecureConnection - see the description of the 
//                                                             SecureConnection property of the FTPConnection and HTTPConnection objects in SyntaxAssistant.
//                                    - Undefined - in case the secure connection is not used.
//
//    Parameters only for http (https) connection:
//     * Headers - Map - see the details of the Headers parameter of the HTTPRequest object in Syntax Assistant.
//     * UseOSAuthentication - Boolean - in Syntax Assistant, see the details of parameter
//                                                     UseOSAuthentication of the HTTPConnection object.
//
//    Parameters only for ftp (ftps) connection:
//     * PassiveConnection - Boolean - a flag that indicates that the connection should be passive (or active).
//     * SecureConnectionUsageLevel - FTPSecureConnectionUsageLevel - see the details of the 
//         same-name property in the platform Syntax Assistant. Default value is Auto.
//
Function FileGettingParameters() Export
	
	ReceivingParameters = New Structure;
	ReceivingParameters.Insert("PathForSaving", Undefined);
	ReceivingParameters.Insert("User", Undefined);
	ReceivingParameters.Insert("Password", Undefined);
	ReceivingParameters.Insert("Port", Undefined);
	ReceivingParameters.Insert("Timeout", AutomaticTimeoutDetermination());
	ReceivingParameters.Insert("SecureConnection", Undefined);
	ReceivingParameters.Insert("PassiveConnection", Undefined);
	ReceivingParameters.Insert("Headers", New Map);
	ReceivingParameters.Insert("UseOSAuthentication", False);
	ReceivingParameters.Insert("SecureConnectionUsageLevel", Undefined);
	
	Return ReceivingParameters;
	
EndFunction

#EndRegion

#Region Internal

// Service information that displays current settings and proxy states to perform diagnostics.
//
// Returns:
//  Structure - with the following properties:
//     * ProxyConnection - Boolean - flag that indicates that proxy connection should be used.
//     * Presentation - String - presentation of the current set up proxy.
//
Function ProxySettingsStatus() Export
	
#If WebClient Then
	
	Result = New Structure;
	Result.Insert("ProxyConnection", False);
	Result.Insert("Presentation", NStr("ru = 'Прокси не доступен в веб-клиенте.'; en = 'Proxy is not available in web client.'; pl = 'Serwer proxy nie jest dostępny w kliencie Web.';es_ES = 'Proxy no disponible en el cliente web.';es_CO = 'Proxy no disponible en el cliente web.';tr = 'Proxy web istemcide kullanılamaz.';it = 'Il proxy non è disponibile nel web client';de = 'Der Proxy ist im Webclient nicht verfügbar.'"));
	Return Result;
	
#Else
	
	Proxy = GetProxy("http");
	ProxySettings = ProxyServerSetting();
	
	Log = New Array;
	
	If ProxySettings = Undefined Then 
		Log.Add(NStr("ru = 'Параметры прокси-сервера в ИБ не указаны (используются системные настройки прокси).'; en = 'Proxy server parameters are not specified in infobase (proxy system settings are used).'; pl = 'Ustawienia serwera proxy w bazie informacyjnej nie są określone (używane są ustawienia proxy systemu).';es_ES = 'Parámetros del servidor proxy en la BI no están indicados (se usan los ajustes proxy de sistema).';es_CO = 'Parámetros del servidor proxy en la BI no están indicados (se usan los ajustes proxy de sistema).';tr = 'Proxy sunucunun ayarları IB''de belirtilmemiştir (sistem proxy ayarları kullanılır).';it = 'I parametri del server proxy non sono stati specificati nel DB (si usano le impostazioni proxy del sistema).';de = 'Proxy-Server-Parameter werden in der IB nicht angegeben (es werden System-Proxy-Einstellungen verwendet).'"));
	ElsIf Not ProxySettings.Get("UseProxy") Then
		Log.Add(NStr("ru = 'Параметры прокси-сервера в ИБ: Не использовать прокси-сервер.'; en = 'Proxy server parameters in infobase: Do not use proxy server.'; pl = 'Ustawienia serwera proxy w IB: Nie używaj serwera proxy.';es_ES = 'Parámetros del servidor proxy en la BI: No usar el servidor proxy.';es_CO = 'Parámetros del servidor proxy en la BI: No usar el servidor proxy.';tr = 'Proxy sunucunun IB''deki ayarları: Proxy sunucusu kullanılamaz.';it = 'I parametri del server proxy nel database: Non utilizzare il server proxy.';de = 'Proxy-Server-Parameter in der IB: Verwenden Sie keinen Proxy-Server.'"));
	ElsIf ProxySettings.Get("UseSystemSettings") Then
		Log.Add(NStr("ru = 'Параметры прокси-сервера в ИБ: Использовать системные настройки прокси-сервера.'; en = 'Proxy server parameters in infobase: Use proxy server system settings.'; pl = 'Ustawienia serwera proxy w IB: Użyj ustawień systemu serwera proxy.';es_ES = 'Parámetros del servidor proxy en la BI: Usar los ajustes del sistema del servidor proxy.';es_CO = 'Parámetros del servidor proxy en la BI: Usar los ajustes del sistema del servidor proxy.';tr = 'Proxy sunucunun IB''deki ayarları: Proxy sunucunun sistem ayarlarını kullan.';it = 'I parametri del server proxy nel DB: Usare impostazioni proxy del sistema.';de = 'Proxy-Server-Parameter in der IB: Verwenden Sie die Systemeinstellungen des Proxy-Servers.'"));
	Else
		Log.Add(NStr("ru = 'Параметры прокси-сервера в ИБ: Использовать другие настройки прокси-сервера.'; en = 'Proxy server parameters in infobase: Use other proxy server settings.'; pl = 'Ustawienia proxy w bazie IB: Użyj innych ustawień serwera proxy.';es_ES = 'Parámetros del servidor proxy en la BI: Usar otros ajustes del servidor proxy.';es_CO = 'Parámetros del servidor proxy en la BI: Usar otros ajustes del servidor proxy.';tr = 'Proxy sunucunun IB''deki ayarları: Proxy sunucunun sistem diğer ayarlarını kullan.';it = 'I parametri del server proxy nel database: Utilizzare altre impostazioni del server proxy.';de = 'Proxy-Server-Parameter in der IB: Verwenden Sie andere Proxy-Server-Einstellungen.'"));
	EndIf;
	
	If Proxy = Undefined Then 
		Proxy = New InternetProxy(True);
	EndIf;
	
	AllAddressesProxySpecified = Not IsBlankString(Proxy.Server());
	HTTPProxySpecified = Not IsBlankString(Proxy.Server("http"));
	HTTPSProxySpecified = Not IsBlankString(Proxy.Server("https"));
	
	ProxyConnection = AllAddressesProxySpecified Or HTTPProxySpecified Or HTTPSProxySpecified;
	
	If ProxyConnection Then 
		Log.Add(NStr("ru = 'Соединение выполняется через прокси-сервер:'; en = 'Connecting via proxy server:'; pl = 'Połączenie jest nawiązywane za pośrednictwem serwera proxy:';es_ES = 'La conexión se realiza a través del servidor proxy:';es_CO = 'La conexión se realiza a través del servidor proxy:';tr = 'Bağlantı proxy sunucusu üzerinden yapılıyor:';it = 'Connessione attraverso server proxy:';de = 'Die Verbindung erfolgt über einen Proxy-Server:'"));
		Log.Add(InternetProxyPresentation(Proxy));
	Else
		Log.Add(NStr("ru = 'Соединение выполняется без использования прокси-сервера.'; en = 'Connecting without proxy server.'; pl = 'Połączenie jest wykonywane bez użycia serwera proxy.';es_ES = 'La conexión se realiza sin usar el servidor proxy.';es_CO = 'La conexión se realiza sin usar el servidor proxy.';tr = 'Bağlantı proxy sunucu kullanılmadan yapılıyor.';it = 'Connessione senza server proxy.';de = 'Die Verbindung wird ohne Verwendung eines Proxy-Servers durchgeführt.'"));
	EndIf;
	
	Result = New Structure;
	Result.Insert("ProxyConnection", ProxyConnection);
	Result.Insert("Presentation", StrConcat(Log, Chars.LF));
	Return Result;
	
#EndIf
	
EndFunction

#EndRegion

#Region Private

Function AutomaticTimeoutDetermination()
	
	Return -1;
	
EndFunction

#If Not WebClient Then

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// function meant for getting files from the Internet
//
// Parameters:
// URL - String - file URL in the following format:
// ReceivingSettings - Structure with properties.
//    * PathForSaving - String - path on the server (including file name) for saving the downloaded file.
//    * User - String - user that established the connection.
//    * Password - String - password of the user that established the connection.
//    * Port - Number - port used for connecting to the server.
//    * Timeout - Number - file getting timeout in seconds.
//    * SecureConnection - Boolean - in case of http download the flag shows that the connection 
//                                             must be established via https.
//    * PassiveConnection - Boolean - in case of ftp download the flag shows that the connection 
//                                             must be passive (or active).
//    * Headers - Map - see the details of the Headers parameter of the HTTPRequest object.
//    * UseOSAuthentication - Boolean - see the details of the UseOSAuthentication parameter of the HTTPConnection object.
//
// SavingSetting - Map - contains parameters to save the downloaded file keys:
//                 
//                 Storage - String - may contain
//                        "Client" - client,
//                        "Server" - server,
//                        "TemporaryStorage" - temporary storage.
//                 Path - String (optional parameter) - path to folder at client or at server or 
//                        temporary storage address will be generated if not specified.
//                        
//
// Returns:
// structure success - Boolean - success or failure of the operation string - String - in case of 
// success either a string that contains file saving path or an address in the temporary storage; in 
// case of failure an error message.
//                   
//                   
//
Function DownloadFile(Val URL, Val ReceivingParameters, Val SavingSetting, Val WriteError = True) Export
	
	ReceivingSettings = FileGettingParameters();
	If ReceivingParameters <> Undefined Then
		FillPropertyValues(ReceivingSettings, ReceivingParameters);
	EndIf;
	
	If SavingSetting.Get("Storage") <> "TemporaryStorage" Then
		SavingSetting.Insert("Path", ReceivingSettings.PathForSaving);
	EndIf;
	
	ProxyServerSetting = ProxyServerSetting();
	
	Redirections = New Array;
	
	Return GetFileFromInternet(URL, SavingSetting, ReceivingSettings,
		ProxyServerSetting, WriteError, Redirections);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

// function meant for getting files from the Internet
//
// Parameters:
// URL - String - file URL in the following format: [Protocol://]<Server>/<Path to the file on the server>.
//
// ConnectionSetting - Map -
//		SecureConnection* - Boolean - the connection is secure.
//		PassiveConnection* - Boolean - the connection is secure.
//		User - String - user that established the connection.
//		Password - String - password of the user that established the connection.
//		Port - Number - port used for connecting to the server.
//		* - mutually exclusive keys.
//
// ProxySettings - Map:
//		UseProxy - indicates whether to use proxy server.
//		BypassProxyOnLocal - indicates whether to use proxy server for local addresses.
//		UseSystemSettings - indicates whether to use proxy server system settings.
//		Server - proxy server address.
//		Port - proxy server port.
//		User - username for authorization on proxy server.
//		Password - user password.
//		UseOSAuthentication - Boolean - a flag that indicates the use of authentication by means of the operating system.
//
// SavingSetting - Map - contains parameters to save the downloaded file.
//		Storage - String - may contain
//			"Client" - client,
//			"Server" - server,
//			"TemporaryStorage" - temporary storage.
//		Path - String (optional parameter) - path to folder at client or at server or temporary storage 
//			address will be generated if not specified.
//
// Returns:
// structure success - Boolean - success or failure of the operation string - String - in case of 
// success either a string that contains file saving path or an address in the temporary storage; in 
// case of failure an error message.
//                   
//                   
//
Function GetFileFromInternet(Val URL, Val SavingSetting, Val ConnectionSetting,
	Val ProxySettings, Val WriteError, Redirections = Undefined)
	
	URIStructure = CommonClientServer.URIStructure(URL);
	
	Server        = URIStructure.Host;
	PathAtServer = URIStructure.PathAtServer;
	Protocol      = URIStructure.Schema;
	
	If IsBlankString(Protocol) Then 
		Protocol = "http";
	EndIf;
	
	SecureConnection = ConnectionSetting.SecureConnection;
	Username      = ConnectionSetting.User;
	UserPassword   = ConnectionSetting.Password;
	Port                 = ConnectionSetting.Port;
	Timeout              = ConnectionSetting.Timeout;
	
	If (Protocol = "https" Or Protocol = "ftps") AND SecureConnection = Undefined Then
		SecureConnection = True;
	EndIf;
	
	If SecureConnection = True Then
		SecureConnection = CommonClientServer.NewSecureConnection();
	ElsIf SecureConnection = False Then
		SecureConnection = Undefined;
		// Otherwise the SecureConnection parameter was specified explicitly.
	EndIf;
	
	If Port = Undefined Then
		Port = URIStructure.Port;
	EndIf;
	
	If ProxySettings = Undefined Then 
		Proxy = Undefined;
	Else 
		Proxy = NewInternetProxy(ProxySettings, Protocol);
	EndIf;
	
	If SavingSetting["Path"] <> Undefined Then
		PathForSaving = SavingSetting["Path"];
	Else
		// The temporary file must be deleted by the calling code.
		PathForSaving = GetTempFileName();
	EndIf;
	
	If Timeout = Undefined Then 
		Timeout = AutomaticTimeoutDetermination();
	EndIf;
	
	FTPProtocolISUsed = (Protocol = "ftp" Or Protocol = "ftps");
	
	If FTPProtocolISUsed Then
		
		PassiveConnection                       = ConnectionSetting.PassiveConnection;
		SecureConnectionUsageLevel = ConnectionSetting.SecureConnectionUsageLevel;
		
		Try
			
			If Timeout = AutomaticTimeoutDetermination() Then
				
				Connection = New FTPConnection(
					Server, 
					Port, 
					Username, 
					UserPassword,
					Proxy, 
					PassiveConnection, 
					7, 
					SecureConnection, 
					SecureConnectionUsageLevel);
				
				FileSize = FTPFileSize(Connection, PathAtServer);
				Timeout = TimeoutByFileSize(FileSize);
				
			EndIf;
			
			Connection = New FTPConnection(
				Server, 
				Port, 
				Username, 
				UserPassword,
				Proxy, 
				PassiveConnection, 
				Timeout, 
				SecureConnection, 
				SecureConnectionUsageLevel);
			
			Server = Connection.Host;
			Port   = Connection.Port;
			
			Connection.Get(PathAtServer, PathForSaving);
			
		Except
			
			DiagnosticsResult = CommonClientServer.ConnectionDiagnostics(URL);
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось получить файл %1 с сервера %2:%3
				           |по причине:
				           |%4
				           |Результат диагностики:
				           |%5'; 
				           |en = 'Cannot receive file %1 from server %2:%3
				           |due to:
				           |%4
				           |Diagnostics result:
				           |%5'; 
				           |pl = 'Nie można pobrać plik %1 z serwera %2:%3
				           | w wyniku:
				           |%4
				           |Wynik diagnostyki:
				           |%5';
				           |es_ES = 'No se ha podido recibir el archivo %1 del servidor %2: %3
				           |a causa de:
				           |%4
				           |Resultado de diagnóstico:
				           |%5';
				           |es_CO = 'No se ha podido recibir el archivo %1 del servidor %2: %3
				           |a causa de:
				           |%4
				           |Resultado de diagnóstico:
				           |%5';
				           |tr = 'Dosyayı %1 sunucudan %2: %3
				           |aşağıdaki nedenle alınamadı:
				           |%4
				           |Tanılama sonuçları:
				           |%5';
				           |it = 'Impossibile ricevere il file %1 dal server%2:%3
				           |a causa di:
				           |%4
				           |Risultato diagnostico:
				           |%5';
				           |de = 'Die Datei konnte nicht %1 vom Server heruntergeladen werden %2:%3
				           |wegen:
				           |%4
				           |Diagnoseergebnis:
				           |%5'"),
				URL, Server, Format(Port, "NG="),
				BriefErrorDescription(ErrorInfo()),
				DiagnosticsResult.ErrorDescription);
				
			If WriteError Then
				ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '%1
					           |
					           |Трассировка:
					           |SecureConnection: %2
					           |Таймаут: %3'; 
					           |en = '%1
					           |
					           |Tracing:
					           |SecureConnection: %2
					           |Timeout: %3'; 
					           |pl = '%1
					           |
					           |Śledzenie:
					           |SecureConnection: %2
					           |Limit Czasu: %3';
					           |es_ES = '%1
					           |
					           |Trazabilidad:
					           |SecureConnection: %2
					           |Tiempo muerto: %3';
					           |es_CO = '%1
					           |
					           |Trazabilidad:
					           |SecureConnection: %2
					           |Tiempo muerto: %3';
					           |tr = '%1
					           |
					           |İzleme:
					           |SecureConnection: %2
					           |Timeout: %3';
					           |it = '%1
					           |
					           |Tracing:
					           |SecureConnection: %2
					           |Timeout: %3';
					           |de = '%1
					           |
					           |Ablaufverfolgung:
					           |GeschützteVerbindung: %2
					           |Timeout: %3'"),
					ErrorText,
					Format(Connection.IsSecure, "BF=Нет; BT=Да"),
					Format(Connection.Timeout, "NG=0"));
					
				WriteErrorToEventLog(ErrorMessage);
			EndIf;
			
			Return FileAcquisitionResult(False, ErrorText);
			
		EndTry;
		
	Else // HTTP protocol is used.
		
		Headers                    = ConnectionSetting.Headers;
		UseOSAuthentication = ConnectionSetting.UseOSAuthentication;
		
		Try
			
			If Timeout = AutomaticTimeoutDetermination() Then
				
				Connection = New HTTPConnection(
					Server, 
					Port, 
					Username, 
					UserPassword,
					Proxy, 
					7, 
					SecureConnection, 
					UseOSAuthentication);
				
				FileSize = HTTPFileSize(Connection, PathAtServer, Headers);
				Timeout = TimeoutByFileSize(FileSize);
				
			EndIf;
			
			Connection = New HTTPConnection(
				Server, 
				Port, 
				Username, 
				UserPassword,
				Proxy, 
				Timeout, 
				SecureConnection, 
				UseOSAuthentication);
			
			Server = Connection.Host;
			Port   = Connection.Port;
			
			HTTPRequest = New HTTPRequest(PathAtServer, Headers);
			HTTPRequest.Headers.Insert("Accept-Charset", "UTF-8");
			HTTPRequest.Headers.Insert("X-1C-Request-UID", String(New UUID));
			HTTPResponse = Connection.Get(HTTPRequest, PathForSaving);
			
		Except
			
			DiagnosticsResult = CommonClientServer.ConnectionDiagnostics(URL);
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось установить HTTP-соединение с сервером %1:%2
				           |по причине:
				           |%3
				           |
				           |Результат диагностики:
				           |%4'; 
				           |en = 'Cannot establish HTTP connection with server %1:%2
				           |due to:
				           |%3
				           |
				           |Diagnostic results:
				           |%4'; 
				           |pl = 'Nie udało się powiązać połączenie HTTP z serwerem %1:%2
				           |z powodu:
				           |%3
				           |
				           |Rezultat diagnostyki:
				           |%4';
				           |es_ES = 'No se ha podido instalar la conexión HTTP con el servidor %1:%2
				           |a causa de:
				           |%3
				           |
				           |Resultado de diagnóstico:
				           |%4';
				           |es_CO = 'No se ha podido instalar la conexión HTTP con el servidor %1:%2
				           |a causa de:
				           |%3
				           |
				           |Resultado de diagnóstico:
				           |%4';
				           |tr = 'Sunucu ile HTTP-bağlantı yapılamadı %1:%2
				           |nedenle:
				           |%3
				           |
				           |Tanılama sonuçları:
				           |%4';
				           |it = 'Impossibile stabilire la connessione HTTP con il server %1:%2
				           |a causa di:
				           |%3
				           |
				           |Risultato diagnostico:
				           |%4';
				           |de = 'Es konnte keine HTTP-Verbindung zum Server aufgebaut werden %1:%2
				           |aufgrund von:
				           |%3
				           |
				           |Diagnoseergebnis:
				           |%4'"),
				Server, Format(Port, "NG="),
				BriefErrorDescription(ErrorInfo()),
				DiagnosticsResult.ErrorDescription);
			
			AddRedirectionsPresentation(Redirections, ErrorText);
			
			If WriteError Then
				WriteErrorToEventLog(ErrorText);
			EndIf;
				
			Return FileAcquisitionResult(False, ErrorText);
			
		EndTry;
		
		Try
			
			If HTTPResponse.StatusCode = 301 // 301 Moved Permanently
				Or HTTPResponse.StatusCode = 302 // 302 Found, 302 Moved Temporarily
				Or HTTPResponse.StatusCode = 303 // 303 See Other by GET
				Or HTTPResponse.StatusCode = 307 // 307 Temporary Redirect
				Or HTTPResponse.StatusCode = 308 Then // 308 Permanent Redirect
				
				If Redirections.Count() > 7 Then
					Raise 
						NStr("ru = 'Превышено количество перенаправлений.'; en = 'You have exceeded the number of redirections.'; pl = 'Przekroczono liczbę przekierowań.';es_ES = 'Se ha superado la cantidad de desviación.';es_CO = 'Se ha superado la cantidad de desviación.';tr = 'Tekrar yönlendirme sayısı arttı.';it = 'Hai superato il numero di reindirizzamenti.';de = 'Anzahl der Umleitungen überschritten.'");
				Else 
					
					NewURL = HTTPResponse.Headers["Location"];
					
					If NewURL = Undefined Then 
						Raise 
							NStr("ru = 'Некорректное перенаправление, отсутствует HTTP-заголовок ответа ""Location"".'; en = 'Incorrect redirection, HTTP title of the ""Location"" response is missing.'; pl = 'Niepoprawne przekierowanie, brak nagłówka odpowiedzi HTTP ""Location"".';es_ES = 'Desviación incorrecta no hay título HTTP de la respuesta ""Location"".';es_CO = 'Desviación incorrecta no hay título HTTP de la respuesta ""Location"".';tr = 'Yanlış yönlendirme, ""Konum"" yanıtının HTTP üstbilgisi eksik.';it = 'Reindirizzamento errato, manca il titolo HTTP della risposta ""Posizione"".';de = 'Falsche Umleitung, kein ""Location"" HTTP-Antwort-Header.'");
					EndIf;
					
					NewURL = TrimAll(NewURL);
					
					If IsBlankString(NewURL) Then
						Raise 
							NStr("ru = 'Некорректное перенаправление, пустой HTTP-заголовок ответа ""Location"".'; en = 'Incorrect redirection, empty HTTP title of the ""Location"" response.'; pl = 'Niepoprawne przekierowanie, pusty nagłówek odpowiedzi HTTP ""Location"".';es_ES = 'Desviación incorrecta título HTTP vacío de la respuesta ""Location"".';es_CO = 'Desviación incorrecta título HTTP vacío de la respuesta ""Location"".';tr = 'Yanlış yönlendirme, ""Konum"" yanıtının HTTP üstbilgisi boş.';it = 'Reindirizzamento errato, titolo HTTP della risposta ""Posizione"" è vuoto.';de = 'Falsche Umleitung, leerer ""Location"" HTTP-Antwort-Header.'");
					EndIf;
					
					If Redirections.Find(NewURL) <> Undefined Then
						Raise StringFunctionsClientServer.SubstituteParametersToString(
							NStr("ru = 'Циклическое перенаправление.
							           |Попытка перейти на %1 уже выполнялась ранее.'; 
							           |en = 'Circular redirect.
							           |An attempt to go to %1 was made before.'; 
							           |pl = 'Cykliczne przekierowanie.
							           |Próba przejścia na %1 już uruchomione wcześniej.';
							           |es_ES = 'Desviación cíclica.
							           |Prueba de pasar a %1 se ha realizado anteriormente.';
							           |es_CO = 'Desviación cíclica.
							           |Prueba de pasar a %1 se ha realizado anteriormente.';
							           |tr = 'Döngüsel yönlendirme. 
							           |Daha önce zaten devam etmeye %1çalışıyor.';
							           |it = 'Reindirizzamento circolare.
							           |Si è già tentato di accedere a %1.';
							           |de = 'Zyklische Umleitung.
							           |Ein Versuch, auf %1 umzusteigen, wurde bereits unternommen.'"),
							NewURL);
					EndIf;
					
					Redirections.Add(URL);
					
					If Not StrStartsWith(NewURL, "http") Then
						// <scheme>://<host>:<port>/<path>
						NewURL = StringFunctionsClientServer.SubstituteParametersToString(
							"%1://%2:%3/%4", Protocol, Server, Format(Port, "NG="), NewURL);
					EndIf;
					
					Return GetFileFromInternet(NewURL, SavingSetting, ConnectionSetting,
						ProxySettings, WriteError, Redirections);
					
				EndIf;
				
			EndIf;
			
			If HTTPResponse.StatusCode < 200 Or HTTPResponse.StatusCode >= 300 Then
				
				If HTTPResponse.StatusCode = 304 Then
					
					If (HTTPRequest.Headers["If-Modified-Since"] <> Undefined
						Or HTTPRequest.Headers["If-None-Match"] <> Undefined) Then
						WriteError = False;
					EndIf;
					
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Сервер убежден, что с вашего последнего запроса его ответ не изменился:
						           |%1'; 
						           |en = 'The server responded that its response has not changed since your last request:
						           |%1'; 
						           |pl = 'Serwer odpowiedział, że jego odpowiedź nie zmieniła się od czasu ostatniego żądania:
						           |%1';
						           |es_ES = 'El servidor está seguro de que desde su última consulta de usted su respuesta no se ha cambiado:
						           |%1';
						           |es_CO = 'El servidor está seguro de que desde su última consulta de usted su respuesta no se ha cambiado:
						           |%1';
						           |tr = 'Sunucu, son sorgunuzdan cevabının değişmediğine düşünüyor: 
						           |%1';
						           |it = 'Il server ha risposto dicendo che nulla è cambiato rispetto all''ultima vostra richiesta:
						           |%1';
						           |de = 'Der Server hat geantwortet, dass sich seine Antwort seit Ihrer letzten Anfrage nicht geändert hat:
						           |%1'"),
						HTTPConnectionCodeDecryption(HTTPResponse.StatusCode));
					
					AddServerResponseBody(PathForSaving, ErrorText);
					
					Raise ErrorText;
					
				ElsIf HTTPResponse.StatusCode < 200
					Or HTTPResponse.StatusCode >= 300 AND HTTPResponse.StatusCode < 400 Then
					
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Неподдерживаемый ответ сервера:
						           |%1'; 
						           |en = 'Unsupported server response:
						           |%1'; 
						           |pl = 'Nieobsługiwana odpowiedź serwera:
						           |%1';
						           |es_ES = 'Respuesta del servidor no admitida:
						           |%1';
						           |es_CO = 'Respuesta del servidor no admitida:
						           |%1';
						           |tr = 'Sunucunun desteklenmeyen cevabı:
						           |%1';
						           |it = 'Risposta del server non supportata:
						           |%1';
						           |de = 'Nicht unterstützte Serverantwort:
						           |%1'"),
						HTTPConnectionCodeDecryption(HTTPResponse.StatusCode));
					
					AddServerResponseBody(PathForSaving, ErrorText);
					
					Raise ErrorText;
					
				ElsIf HTTPResponse.StatusCode >= 400 AND HTTPResponse.StatusCode < 500 Then 
					
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Ошибка при выполнении запроса:
						           |%1'; 
						           |en = 'An error occurred while executing a query:
						           |%1'; 
						           |pl = 'Błąd podczas wykonywania kwerendy:
						           |%1';
						           |es_ES = 'Error al realizar la consulta:
						           |%1';
						           |es_CO = 'Error al realizar la consulta:
						           |%1';
						           |tr = 'Sorgu yürütülürken hata oluştu:
						           |%1';
						           |it = 'Si è verificato un errore durante l''esecuzione della query:
						           |%1';
						           |de = 'Fehler beim Ausführen der Anfrage:
						           |%1'"),
						HTTPConnectionCodeDecryption(HTTPResponse.StatusCode));
					
					AddServerResponseBody(PathForSaving, ErrorText);
					
					Raise ErrorText;
					
				Else 
					
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Ошибка сервера при обработке запроса к ресурсу:
						           |%1'; 
						           |en = 'A server error occurred while processing a resource query:
						           |%1'; 
						           |pl = 'Błąd serwera podczas przetwarzania żądania zasobu: 
						           |%1';
						           |es_ES = 'Error del servidor al procesar la consulta del recurso: 
						           |%1';
						           |es_CO = 'Error del servidor al procesar la consulta del recurso: 
						           |%1';
						           |tr = 'Kaynak isteği işlenirken sunucu hatası:
						           |%1';
						           |it = 'Errore del server durante l''elaborazione di una richiesta alla risorsa:
						           |%1';
						           |de = 'Serverfehler bei der Verarbeitung von Ressourcenanfragen:
						           |%1'"),
						HTTPConnectionCodeDecryption(HTTPResponse.StatusCode));
					
					AddServerResponseBody(PathForSaving, ErrorText);
					
					Raise ErrorText;
					
				EndIf;
				
			EndIf;
			
		Except
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось получить файл %1 с сервера %2:%3
				           |по причине:
				           |%4'; 
				           |en = 'Cannot receive file %1 from server %2:%3
				           |due to:
				           |%4'; 
				           |pl = 'Nie udało się pobrać pliku %1 z serwera %2:%3
				           | z powodu:
				           |%4';
				           |es_ES = 'No se ha podido recibir el archivo %1 del servidor %2: %3
				           |a causa de:
				           |%4';
				           |es_CO = 'No se ha podido recibir el archivo %1 del servidor %2: %3
				           |a causa de:
				           |%4';
				           |tr = 'Dosyayı %1 sunucudan %2: %3
				           |aşağıdaki nedenle alınamadı:
				           |%4';
				           |it = 'Impossibile acquisire file %1 dal server %2:%3
				           |a causa di:
				           |%4';
				           |de = 'Die Datei %1 konnte aus dem Server nicht abgerufen werden %2:%3
				           |Aus folgendem Grund:
				           |%4'"),
				URL, Server, Format(Port, "NG="),
				BriefErrorDescription(ErrorInfo()));
			
			AddRedirectionsPresentation(Redirections, ErrorText);
			
			If WriteError Then
				ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '%1
					           |
					           |Трассировка:
					           |SecureConnection: %2
					           |Таймаут: %3
					           |UseOSAuthentication: %4'; 
					           |en = '%1
					           |
					           |Tracing:
					           |SecureConnection: %2
					           |Timeout: %3
					           |UseOSAuthentication: %4'; 
					           |pl = '%1
					           |
					           |Śledzenie:
					           |SecureConnection: %2
					           |Limit czasu: %3
					           |UseOSAuthentication: %4';
					           |es_ES = '%1
					           |
					           |Trazabilidad:
					           |SecureConnection: %2
					           |Tiempo muerto: %3 
					           |UseOSAuthentication: %4';
					           |es_CO = '%1
					           |
					           |Trazabilidad:
					           |SecureConnection: %2
					           |Tiempo muerto: %3 
					           |UseOSAuthentication: %4';
					           |tr = '%1
					           |
					           |İzleme:
					           |SecureConnection: %2
					           |Timeout: %3UseOSAuthentication: 
					           |%4';
					           |it = '%1
					           |
					           |Tracing:
					           |SecureConnection: %2
					           |Timeout: %3
					           |UseOSAuthentication: %4';
					           |de = '%1
					           |
					           |Ablaufverfolgung:
					           |GeschützteVerbindung: %2
					           |Timeout: %3
					           |AuthentifizierungBetriebssystemVerwenden: %4'"),
					ErrorText,
					Format(Connection.IsSecure, "BF=Нет; BT=Да"),
					Format(Connection.Timeout, "NG=0"),
					Format(Connection.UseOSAuthentication, "BF=Нет; BT=Да"));
				
				AddHTTPHeaders(HTTPRequest, ErrorMessage);
				AddHTTPHeaders(HTTPResponse, ErrorMessage);
				
				WriteErrorToEventLog(ErrorMessage);
			EndIf;
			
			Return FileAcquisitionResult(False, ErrorText, HTTPResponse);
			
		EndTry;
		
	EndIf;
	
	// If the file is saved in accordance with the setting.
	If SavingSetting["Storage"] = "TemporaryStorage" Then
		UniqueKey = New UUID;
		Address = PutToTempStorage (New BinaryData(PathForSaving), UniqueKey);
		Return FileAcquisitionResult(True, Address, HTTPResponse);
	ElsIf SavingSetting["Storage"] = "Client"
		Or SavingSetting["Storage"] = "Server" Then
		Return FileAcquisitionResult(True, PathForSaving, HTTPResponse);
	Else
		Raise NStr("ru = 'Не указано место для сохранения файла.'; en = 'Place for saving the file is not specified.'; pl = 'Brak miejsca do zapisania pliku.';es_ES = 'No se ha indicado el lugar para guardar el archivo.';es_CO = 'No se ha indicado el lugar para guardar el archivo.';tr = 'Dosyanın kaydedileceği yer belirtilmedi.';it = 'Il luogo di salvataggio del file non è specificato.';de = 'Es gibt keinen Platz, um die Datei zu speichern.'");
	EndIf;
	
EndFunction

// function meant for completing the structure according to parameters
//
// Parameters:
// OperationSuccess - Boolean - success or failure of the operation.
// MessagePath - String -
//
// Returns - Structure:
//          field success - Boolean field path - String.
//          
//
Function FileAcquisitionResult(Val Status, Val MessagePath, HTTPResponse = Undefined)
	
	Result = New Structure("Status", Status);
	
	If Status Then
		Result.Insert("Path", MessagePath);
	Else
		Result.Insert("ErrorMessage", MessagePath);
		Result.Insert("StatusCode", 1);
	EndIf;
	
	If HTTPResponse <> Undefined Then
		ResponseHeadings = HTTPResponse.Headers;
		If ResponseHeadings <> Undefined Then
			Result.Insert("Headers", ResponseHeadings);
		EndIf;
		
		Result.Insert("StatusCode", HTTPResponse.StatusCode);
		
	EndIf;
	
	Return Result;
	
EndFunction

Function HTTPFileSize(HTTPConnection, Val PathAtServer, Val Headers = Undefined)
	
	HTTPRequest = New HTTPRequest(PathAtServer, Headers);
	Try
		ReceivedHeaders = HTTPConnection.Head(HTTPRequest);// HEAD
	Except
		Return 0;
	EndTry;
	SizeInString = ReceivedHeaders.Headers["Content-Length"];
	
	NumberType = New TypeDescription("Number");
	FileSize = NumberType.AdjustValue(SizeInString);
	
	Return FileSize;
	
EndFunction

Function FTPFileSize(FTPConnection, Val PathAtServer)
	
	FileSize = 0;
	
	Try
		FilesFound = FTPConnection.FindFiles(PathAtServer);
		If FilesFound.Count() > 0 Then
			FileSize = FilesFound[0].Size();
		EndIf;
	Except
		FileSize = 0;
	EndTry;
	
	Return FileSize;
	
EndFunction

Function TimeoutByFileSize(Size)
	
	BytesInMegabyte = 1048576;
	
	If Size > BytesInMegabyte Then
		SecondsCount = Round(Size / BytesInMegabyte * 128);
		Return ?(SecondsCount > 43200, 43200, SecondsCount);
	EndIf;
	
	Return 128;
	
EndFunction

Function HTTPConnectionCodeDecryption(StatusCode)
	
	If StatusCode = 304 Then // Not Modified
		Details = NStr("ru = 'Нет необходимости повторно передавать запрошенные ресурсы.'; en = 'It is not required to transfer the requested resources again.'; pl = 'Nie trzeba ponownie przesyłać żądanych zasobów.';es_ES = 'No hay necesidad de volver a transmitir los recursos solicitados.';es_CO = 'No hay necesidad de volver a transmitir los recursos solicitados.';tr = 'Talep edilen kaynaklar tekrar aktarılmaz.';it = 'Non è necessario trasferire di nuovo le risorse richieste.';de = 'Es ist nicht erforderlich, die angeforderten Ressourcen erneut einzureichen.'");
	ElsIf StatusCode = 400 Then // Bad Request
		Details = NStr("ru = 'Запрос не может быть исполнен.'; en = 'Query cannot be executed.'; pl = 'Żądanie nie może zostać wykonane.';es_ES = 'La consulta no ha sido realizada.';es_CO = 'La consulta no ha sido realizada.';tr = 'Talep yerine getirilemez.';it = 'Query non può essere eseguita.';de = 'Die Anforderung kann nicht ausgeführt werden.'");
	ElsIf StatusCode = 401 Then // Unauthorized
		Details = NStr("ru = 'Попытка авторизации на сервере была отклонена.'; en = 'Server authorization attempt was rejected.'; pl = 'Próba autoryzacji na serwerze została odrzucona.';es_ES = 'Prueba de autorizar en el servidor ha sido declinada.';es_CO = 'Prueba de autorizar en el servidor ha sido declinada.';tr = 'Sunucudaki doğrulama girişimi reddedildi.';it = 'Il tentativo di autorizzazione del server è stato respinto.';de = 'Der Versuch, sich auf dem Server zu autorisieren, wurde abgelehnt.'");
	ElsIf StatusCode = 402 Then // Payment Required
		Details = NStr("ru = 'Требуется оплата.'; en = 'Payment is required.'; pl = 'Wymagana płatność.';es_ES = 'Se requiere pagar.';es_CO = 'Se requiere pagar.';tr = 'Ödeme gerekli.';it = 'Il pagamento è richiesto.';de = 'Zahlung erforderlich.'");
	ElsIf StatusCode = 403 Then // Forbidden
		Details = NStr("ru = 'К запрашиваемому ресурсу нет доступа.'; en = 'No access to the requested resource.'; pl = 'Nie ma dostępu do żądanego zasobu.';es_ES = 'No hay acceso al recurso solicitado.';es_CO = 'No hay acceso al recurso solicitado.';tr = 'Sorgulanan kaynak erişilemez.';it = 'Non c''è accesso alla risorsa richiesta.';de = 'Es besteht kein Zugriff auf die angeforderte Ressource.'");
	ElsIf StatusCode = 404 Then // Not Found
		Details = NStr("ru = 'Запрашиваемый ресурс не найден на сервере.'; en = 'Requested resource was not found on the server.'; pl = 'Żądany zasób nie został znaleziony na serwerze.';es_ES = 'El recurso solicitado no se ha encontrado en el servidor.';es_CO = 'El recurso solicitado no se ha encontrado en el servidor.';tr = 'Sorgulanan kaynak sunucuda bulunamadı.';it = 'La risorsa richiesta non è stata trovata sul server.';de = 'Die angeforderte Ressource wird auf dem Server nicht gefunden.'");
	ElsIf StatusCode = 405 Then // Method Not Allowed
		Details = NStr("ru = 'Метод запроса не поддерживается сервером.'; en = 'Request method is not supported by server.'; pl = 'Metoda żądania nie jest obsługiwana przez serwer.';es_ES = 'E método de la consulta no se admite por el servidor.';es_CO = 'E método de la consulta no se admite por el servidor.';tr = 'Sorgu yöntemi sunucu tarafından desteklenmez.';it = 'Il metodo di richiesta non è supportata dal server.';de = 'Die Anforderungsmethode wird vom Server nicht unterstützt.'");
	ElsIf StatusCode = 406 Then // Not Acceptable
		Details = NStr("ru = 'Запрошенный формат данных не поддерживается сервером.'; en = 'Requested data format is not supported by the server.'; pl = 'Żądany format danych nie jest obsługiwany przez serwer.';es_ES = 'El formato solicitado de datos no se admite por el servidor.';es_CO = 'El formato solicitado de datos no se admite por el servidor.';tr = 'Sorgulanan veri formatı sunucu tarafından desteklenmez.';it = 'Il formato dati richiesto non è supportato dal server.';de = 'Angefragtes Datenformat wird vom Server nicht unterstützt.'");
	ElsIf StatusCode = 407 Then // Proxy Authentication Required
		Details = NStr("ru = 'Ошибка аутентификации на прокси-сервере'; en = 'Authentication error on proxy server'; pl = 'Błąd uwierzytelniania na serwerze proxy';es_ES = 'Error de autenticación en el servidor proxy';es_CO = 'Error de autenticación en el servidor proxy';tr = 'Proxy sunucu doğrulama hatası';it = 'Errore di autentificazione sul server proxy';de = 'Authentifizierungsfehler auf dem Proxy-Server'");
	ElsIf StatusCode = 408 Then // Request Timeout
		Details = NStr("ru = 'Время ожидания сервером передачи от клиента истекло.'; en = 'Server timeout of customer transfer has expired.'; pl = 'Limit czasu transferu serwera z klienta wygasł.';es_ES = 'El tiempo de espera del servidor de la transmisión se ha expirado.';es_CO = 'El tiempo de espera del servidor de la transmisión se ha expirado.';tr = 'İstemciden aktarım sunucusu zaman aşımına uğradı.';it = 'Il timeout del server per il trasferimento cliente è scaduto.';de = 'Serverübertragungszeitlimit des Kunden ist abgelaufen.'");
	ElsIf StatusCode = 409 Then // Conflict
		Details = NStr("ru = 'Запрос не может быть выполнен из-за конфликтного обращения к ресурсу.'; en = 'Cannot execute the request due to the conflict access to the resource.'; pl = 'Żądanie nie mogło zostać wykonane z powodu sprzecznego wywołania zasobu.';es_ES = 'La consulta no puede ser realizada a causa de la llamada de conflicto al recurso.';es_CO = 'La consulta no puede ser realizada a causa de la llamada de conflicto al recurso.';tr = 'Sorgu, kaynak çakışması nedeniyle gerçekleştirilemez.';it = 'Impossibile eseguire la richiesta a causa di un conflitto di accesso alla risorsa.';de = 'Die Anforderung konnte aufgrund eines widersprüchlichen Aufrufs der Ressource nicht ausgeführt werden.'");
	ElsIf StatusCode = 410 Then // Gone
		Details = NStr("ru = 'Ресурс на сервере был перемешен.'; en = 'Resource on server was transferred.'; pl = 'Zasób na serwerze został przeniesiony.';es_ES = 'El recurso en el servidor ha sido trasladado.';es_CO = 'El recurso en el servidor ha sido trasladado.';tr = 'Sunucudaki kaynak taşındı.';it = 'La risorsa sul server è stata spostata.';de = 'Die Ressource auf dem Server wurde vertauscht.'");
	ElsIf StatusCode = 411 Then // Length Required
		Details = NStr("ru = 'Сервер требует указание ""Content-length."" в заголовке запроса.'; en = 'Server requires the ""Content-length."" specification in request title.'; pl = 'Serwer wymaga wskazania ""Content-length."" w nagłówku żądania.';es_ES = 'El servidor requiere indicar ""Content-length."" en el título de la consulta.';es_CO = 'El servidor requiere indicar ""Content-length."" en el título de la consulta.';tr = 'Sunucu, sorgu başlığında ""İçerik uzunluğu"" belirtilmesini gerektirir.';it = 'Il server richiede la specifica ""Content-length."" nel titolo della richiesta.';de = 'Der Server benötigt die Angabe ""Content-length."" im Anforderungs-Header.'");
	ElsIf StatusCode = 412 Then // Precondition Failed
		Details = NStr("ru = 'Запрос не применим к ресурсу'; en = 'Request is not applicable for the resource'; pl = 'Żądanie nie dotyczy zasobu';es_ES = 'La consulta no se aplica al recurso';es_CO = 'La consulta no se aplica al recurso';tr = 'Sorgu kaynağa uygulanmaz';it = 'Richiesta non applicabile alla risorsa';de = 'Die Anforderung gilt nicht für die Ressource'");
	ElsIf StatusCode = 413 Then // Request Entity Too Large
		Details = NStr("ru = 'Сервер отказывается обработать, слишком большой объем передаваемых данных.'; en = 'The server is refusing to service the request because the passed data volume is too large.'; pl = 'Serwer odmawia przetwarzania zbyt dużej ilości danych.';es_ES = 'El servidor rechaza procesar el tamaño demasiado grande de los datos trasmitidos.';es_CO = 'El servidor rechaza procesar el tamaño demasiado grande de los datos trasmitidos.';tr = 'Sunucu işlemeyi reddediyor, aktarılan verilerin hacmi fazladır.';it = 'Il server si rifiuta di eseguire la richiesta, il volume di dati trasferiti è troppo grande.';de = 'Der Server verweigert die Serviceleistung der Anfrage, weil das übergebene Datenvolumen zu groß ist.'");
	ElsIf StatusCode = 414 Then // Request-URL Too Long
		Details = NStr("ru = 'Сервер отказывается обработать, слишком длинный URL.'; en = 'The server refuses to process as URL is too long.'; pl = 'Serwer odmawia przetworzenia, adres URL jest za długi.';es_ES = 'El servidor rechaza procesar URL demasiado largo.';es_CO = 'El servidor rechaza procesar URL demasiado largo.';tr = 'Sunucu işlemeyi reddediyor, URL aşırı uzun.';it = 'Il server si rifiuta di elaborare perché l''URL è troppo lungo.';de = 'Der Server verweigert die Verarbeitung, die URL ist zu lang.'");
	ElsIf StatusCode = 415 Then // Unsupported Media-Type
		Details = NStr("ru = 'Сервер заметил, что часть запроса была сделана в неподдерживаемом формат'; en = 'Server noticed that part of the request was made in the unsupported format'; pl = 'Serwer zauważył, że część żądania została wykonana w nieobsługiwanym formacie';es_ES = 'El servidor ha notado que la parte de la consulta ha sido realizada en el formato no admitido';es_CO = 'El servidor ha notado que la parte de la consulta ha sido realizada en el formato no admitido';tr = 'Sunucu, sorgunun bir kısmının desteklenmeyen bir biçimde yapıldığını fark etti';it = 'Il server ha notato che parte della richiesta era in un formato non supportato';de = 'Der Server hat festgestellt, dass ein Teil der Anforderung in einem nicht unterstützten Format erfolgt ist'");
	ElsIf StatusCode = 416 Then // Requested Range Not Satisfiable
		Details = NStr("ru = 'Часть запрашиваемого ресурса не может быть предоставлена'; en = 'Part of requested resource cannot be provided'; pl = 'Nie można dostarczyć części żądanego zasobu';es_ES = 'Una parte del recurso solicitado no puede ser presentada';es_CO = 'Una parte del recurso solicitado no puede ser presentada';tr = 'İstenen kaynağın bir kısmı sağlanamaz';it = 'Parte della risorsa richiesta non può essere fornita';de = 'Ein Teil der angeforderten Ressource kann nicht bereitgestellt werden'");
	ElsIf StatusCode = 417 Then // Expectation Failed
		Details = NStr("ru = 'Сервер не может предоставить ответ на указанный запрос.'; en = 'Server cannot response to the specified request.'; pl = 'Serwer nie może dostarczyć odpowiedzi na określone żądanie.';es_ES = 'El servidor no puede presentar la respuesta de la consulta indicada.';es_CO = 'El servidor no puede presentar la respuesta de la consulta indicada.';tr = 'Sunucu, belirtilen sorgu yanıtını sağlayamaz.';it = 'Il server non può rispondere alla richiesta specificata.';de = 'Der Server kann auf diese Anforderung keine Antwort geben.'");
	ElsIf StatusCode = 429 Then // Too Many Requests
		Details = NStr("ru = 'Слишком много запросов за короткое время.'; en = 'Too many requests for a short time.'; pl = 'Zbyt wiele próśb w krótkim czasie.';es_ES = 'Demasiadas consultas en poco tiempo.';es_CO = 'Demasiadas consultas en poco tiempo.';tr = 'Kısa sürede çok fazla sorgu.';it = 'Troppe richieste in poco tempo.';de = 'Zu viele Anforderungen in kurzer Zeit.'");
	ElsIf StatusCode = 500 Then // Internal Server Error
		Details = NStr("ru = 'Внутренняя ошибка сервера.'; en = 'Internal server error.'; pl = 'Wewnętrzny błąd serwera.';es_ES = 'Error interno del servidor.';es_CO = 'Error interno del servidor.';tr = 'Sunucu dahili hatası.';it = 'Errore interno del server.';de = 'Interner Serverfehler.'");
	ElsIf StatusCode = 501 Then // Not Implemented
		Details = NStr("ru = 'Сервер не поддерживает метод запроса.'; en = 'Server does not support request method.'; pl = 'Serwer nie obsługuje metody żądania.';es_ES = 'El servidor no admite el método de la consulta.';es_CO = 'El servidor no admite el método de la consulta.';tr = 'Sunucu sorgu yöntemini desteklemiyor.';it = 'Il server non supporta il metodo di richiesta.';de = 'Der Server unterstützt die Anforderungsmethode nicht.'");
	ElsIf StatusCode = 502 Then // Bad Gateway
		Details = NStr("ru = 'Сервер, выступая в роли шлюза или прокси-сервера, 
		                         |получил недействительное ответное сообщение от вышестоящего сервера.'; 
		                         |en = 'The server received an invalid response from the upstream server 
		                         |while acting as a gateway or proxy server.'; 
		                         |pl = 'Serwer, działający jako brama lub serwer proxy, 
		                         |odebrał komunikat o nieprawidłowej odpowiedzi z serwera nadrzędnego.';
		                         |es_ES = 'El servidor que es puerta o servidor proxy 
		                         |ha recibido el mensaje de respuesta no válido del servidor superior.';
		                         |es_CO = 'El servidor que es puerta o servidor proxy 
		                         |ha recibido el mensaje de respuesta no válido del servidor superior.';
		                         |tr = 'Ağ geçidi veya proxy rolü konuşan sunucu, 
		                         |üst düzey bir sunucudan geçersiz bir yanıt iletisi aldı.';
		                         |it = 'Il server, che funge da gateway o server proxy, 
		                         |ha ricevuto un messaggio di risposta non valido dal server upstream.';
		                         |de = 'Der Server, der als Gateway- oder Proxy-Server fungiert,
		                         |erhielt eine ungültige Antwortnachricht von einem übergeordneten Server.'");
	ElsIf StatusCode = 503 Then // Server Unavailable
		Details = NStr("ru = 'Сервер временно не доступен.'; en = 'Server is temporarily unavailable.'; pl = 'Serwer jest chwilowo niedostępny.';es_ES = 'El servidor no está disponible temporalmente.';es_CO = 'El servidor no está disponible temporalmente.';tr = 'Sunucu geçici olarak kullanım dışında.';it = 'Il server è temporaneamente non disponibile.';de = 'Der Server ist vorübergehend nicht verfügbar.'");
	ElsIf StatusCode = 504 Then // Gateway Timeout
		Details = NStr("ru = 'Сервер в роли шлюза или прокси-сервера 
		                         |не дождался ответа от вышестоящего сервера для завершения текущего запроса.'; 
		                         |en = 'Server as a gateway or proxy server
		                         |failed to receive a response from the upstream server to complete the current query.'; 
		                         |pl = 'Serwer bramki lub serwer proxy 
		                         |nie czekał na odpowiedź z serwera nadrzędnego, aby ukończyć bieżące żądanie.';
		                         |es_ES = 'El servidor es puerta o servidor proxy 
		                         |no ha esperado la respuesta del servidor superior para terminar la consulta actual.';
		                         |es_CO = 'El servidor es puerta o servidor proxy 
		                         |no ha esperado la respuesta del servidor superior para terminar la consulta actual.';
		                         |tr = 'Ağ geçidi veya proxy rolündeki sunucu, 
		                         |geçerli sorguyu tamamlamak için bir üst sunucudan yanıt beklemedi.';
		                         |it = 'Il server come gateway o server proxy
		                         |non è riuscito a ricevere una risposta dal server upstream per completare la query corrente.';
		                         |de = 'Der Server als Gateway- oder Proxy-Server
		                         |hat nicht auf eine Antwort eines übergeordneten Servers gewartet, um die aktuelle Anfrage abzuschließen.'");
	ElsIf StatusCode = 505 Then // HTTP Version Not Supported
		Details = NStr("ru = 'Сервер не поддерживает указанную в запросе версию протокола HTTP'; en = 'The server does not support HTTP protocol version specified in the query'; pl = 'Serwer nie obsługuje wersji protokołu HTTP określonej w żądaniu.';es_ES = 'El servidor no admite la versión de protocolo HTTP indicada en la consulta';es_CO = 'El servidor no admite la versión de protocolo HTTP indicada en la consulta';tr = 'Sunucu HTTP protokolünün sorguda belirtilen sürümünü desteklemiyor';it = 'Questo server non supporta la versione del protocollo HTTP specificata nella query';de = 'Der Server unterstützt nicht die in der Anforderung angegebene Version des HTTP-Protokolls'");
	ElsIf StatusCode = 506 Then // Variant Also Negotiates
		Details = NStr("ru = 'Сервер настроен некорректно, и не способен обработать запрос.'; en = 'Server is configured incorrectly and cannot process a request.'; pl = 'Serwer jest skonfigurowany niepoprawnie i nie może przetworzyć żądania.';es_ES = 'El servidor está ajustado incorrectamente y no es capaz de procesar la consulta.';es_CO = 'El servidor está ajustado incorrectamente y no es capaz de procesar la consulta.';tr = 'Sunucu düzgün yapılandırılmamış ve isteği işleyemiyor.';it = 'Il server non è configurato correttamente e non riesce a processare la richiesta.';de = 'Der Server ist nicht korrekt konfiguriert und kann die Anforderung nicht bearbeiten.'");
	ElsIf StatusCode = 507 Then // Insufficient Storage
		Details = NStr("ru = 'На сервере недостаточно места для выполнения запроса.'; en = 'Not enough space on the server to run the query.'; pl = 'Na serwerze brakuje miejsca, aby spełnić żądanie.';es_ES = 'En el servidor no hay suficiente espacio para realizar la consulta.';es_CO = 'En el servidor no hay suficiente espacio para realizar la consulta.';tr = 'Sunucu isteği gerçekleştirmek için yeterli alan yok.';it = 'Spazio non sufficiente per eseguire la query.';de = 'Es ist nicht genügend Platz auf dem Server vorhanden, um die Anforderung auszuführen.'");
	ElsIf StatusCode = 509 Then // Bandwidth Limit Exceeded
		Details = NStr("ru = 'Сервер превысил отведенное ограничение на потребление трафика.'; en = 'Server exceeded bandwidth limit.'; pl = 'Serwer przekroczył przydzielony limit na zużycie ruchu.';es_ES = 'El servidor ha superado la restricción concedida del consumo de tráfico.';es_CO = 'El servidor ha superado la restricción concedida del consumo de tráfico.';tr = 'Sunucu, ayrılan trafik tüketim kısıtlamasını aştı.';it = 'Il server ha superato il limite di consumo di traffico.';de = 'Der Server hat die Grenze für den Traffic-Verbrauch überschritten.'");
	ElsIf StatusCode = 510 Then // Not Extended
		Details = NStr("ru = 'Сервер требует больше информации о совершаемом запросе.'; en = 'Server requires more information on the current request.'; pl = 'Serwer wymaga więcej informacji o żądaniu.';es_ES = 'El servidor requiere más información de la consulta realizada.';es_CO = 'El servidor requiere más información de la consulta realizada.';tr = 'Sunucu, işlenen sorgu hakkında daha fazla bilgi gerektirir.';it = 'Il server richiede più informazioni sulla richiesta corrente.';de = 'Der Server benötigt weitere Informationen über die gestellte Anforderung.'");
	ElsIf StatusCode = 511 Then // Network Authentication Required
		Details = NStr("ru = 'Требуется авторизация на сервере.'; en = 'Authorization on server is required.'; pl = 'Wymagana autoryzacja na serwerze.';es_ES = 'Se requiere autorización en el servidor.';es_CO = 'Se requiere autorización en el servidor.';tr = 'Sunucuda yetkilendirme gereklidir.';it = 'Autorizzazione richiesta sul server.';de = 'Erfordert Autorisierung auf dem Server.'");
	Else 
		Details = NStr("ru = '<Неизвестный код состояния>.'; en = '<Unknown state code>.'; pl = '<Nieznany kod statusu>.';es_ES = '<Código desconocido del estado>.';es_CO = '<Código desconocido del estado>.';tr = '<Bilinmeyen durum kodu>.';it = '<Codice stato sconosciuto>.';de = 'Unbekannte Statuscode'");
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = '[%1] %2'; en = '[%1] %2'; pl = '[%1] %2';es_ES = '[%1] %2';es_CO = '[%1] %2';tr = '[%1] %2';it = '[%1] %2';de = '[%1] %2'"), 
		StatusCode, 
		Details);
	
EndFunction

Procedure AddRedirectionsPresentation(Redirections, ErrorText)
	
	If Redirections.Count() > 0 Then 
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '%1
			           |
			           |Выполненные перенаправления (%2):
			           |%3'; 
			           |en = '%1
			           |
			           |Performed redirections (%2):
			           |%3'; 
			           |pl = '%1
			           |
			           |Przekierowania zakończone (%2):
			           |%3';
			           |es_ES = '%1
			           |
			           |Redirecciones realizadas (%2):
			           |%3';
			           |es_CO = '%1
			           |
			           |Redirecciones realizadas (%2):
			           |%3';
			           |tr = '%1
			           |
			           |Yapılan yönlendirmeler (%2):
			           |%3';
			           |it = '%1
			           |
			           |Reindirizzamenti eseguiti (%2):
			           |%3';
			           |de = '%1
			           |
			           |Umleitungen durchgeführt (%2):
			           |%3'"),
			ErrorText,
			Redirections.Count(),
			StrConcat(Redirections, Chars.LF));
	EndIf;
	
EndProcedure

Procedure AddServerResponseBody(PathToFile, ErrorText)
	
	ServerResponseBody = TextFromHTMLFromFile(PathToFile);
	
	If Not IsBlankString(ServerResponseBody) Then 
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '%1
			           |
			           |Сообщение, полученное от сервера:
			           |%2'; 
			           |en = '%1
			           |
			           |Message received from server:
			           |%2'; 
			           |pl = '%1
			           |
			           |Wiadomość odebrana z serwera: 
			           |%2';
			           |es_ES = '%1
			           |
			           |Mensaje recibido del servidor:
			           |%2';
			           |es_CO = '%1
			           |
			           |Mensaje recibido del servidor:
			           |%2';
			           |tr = '%1
			           |
			           |Sunucudan gelen mesaj:
			           |%2';
			           |it = '%1
			           |
			           |Messaggio ricevuto dal server:
			           |%2';
			           |de = '%1
			           |
			           |Nachricht, vom Server erhalten:
			           |%2'"),
			ErrorText,
			ServerResponseBody);
	EndIf;
	
EndProcedure

Function TextFromHTMLFromFile(PathToFile)
	
	ResponseFile = New TextReader(PathToFile, TextEncoding.UTF8);
	SourceText = ResponseFile.Read(1024 * 15);
	ErrorText = StringFunctionsClientServer.ExtractTextFromHTML(SourceText);
	ResponseFile.Close();
	
	Return ErrorText;
	
EndFunction

Procedure AddHTTPHeaders(Object, ErrorText)
	
	If TypeOf(Object) = Type("HTTPRequest") Then 
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '%1
			           |
			           |HTTP запрос:
			           |Адрес ресурса: %2
			           |Заголовки: %3'; 
			           |en = '%1
			           |
			           |HTTP request:
			           |Resource address: %2
			           |Headers: %3'; 
			           |pl = '%1
			           |
			           |Żądanie HTTP:
			           |Adres zasobu: %2
			           |Nagłówki: %3';
			           |es_ES = '%1
			           |
			           |Consulta HTTP:
			           |Dirección del recurso: %2
			           |Títulos: %3';
			           |es_CO = '%1
			           |
			           |Consulta HTTP:
			           |Dirección del recurso: %2
			           |Títulos: %3';
			           |tr = '%1
			           |
			           |HTTP sorgu:
			           |Kaynağın adresi: %2
			           |Başlıklar: %3';
			           |it = '%1
			           |
			           |Richiesta HTTP:
			           |Indirizzo risorsa: %2
			           |Intestazioni: %3';
			           |de = '%1
			           |
			           |HTTP-Anforderung:
			           |Ressourcenadresse: %2
			           |Header: %3'"),
			ErrorText,
			Object.ResourceAddress,
			HTTPHeadersPresentation(Object.Headers));
	ElsIf TypeOf(Object) = Type("HTTPResponse") Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '%1
			           |
			           |HTTP ответ:
			           |Код ответа: %2
			           |Заголовки: %3'; 
			           |en = '%1
			           |
			           |HTTP response:
			           |Response code: %2
			           |Titles: %3'; 
			           |pl = '%1
			           |
			           |Żądanie HTTP:
			           |Kod odpowiedzi: %2
			           |Nagłówki: %3';
			           |es_ES = '%1
			           |
			           |Respuesta HTTP:
			           |Código de la respuesta: %2
			           |Títulos: %3';
			           |es_CO = '%1
			           |
			           |Respuesta HTTP:
			           |Código de la respuesta: %2
			           |Títulos: %3';
			           |tr = '%1
			           |
			           |HTTP cevap:
			           |Cevap kodu: %2
			           |Başlıklar: %3';
			           |it = '%1
			           |
			           |Risposta HTTP:
			           |Codice della risposta: %2
			           |Titoli: %3';
			           |de = '%1
			           |
			           |HTTP-Antwort
			           |Antwortcode: %2
			           |Header: %3'"),
			ErrorText,
			Object.StatusCode,
			HTTPHeadersPresentation(Object.Headers));
	EndIf;
	
EndProcedure

Function HTTPHeadersPresentation(Headers)
	
	HeadersPresentation = "";
	
	For each Header In Headers Do 
		HeadersPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '%1
			           |%2: %3'; 
			           |en = '%1
			           |%2: %3'; 
			           |pl = '%1
			           |%2: %3';
			           |es_ES = '%1
			           |%2: %3';
			           |es_CO = '%1
			           |%2: %3';
			           |tr = '%1
			           |%2: %3';
			           |it = '%1
			           |%2: %3';
			           |de = '%1
			           |%2: %3'"), 
			HeadersPresentation,
			Header.Key, Header.Value);
	EndDo;
		
	Return HeadersPresentation;
	
EndFunction

Function ProxyServerSetting()
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	ProxyServerSetting = GetFilesFromInternet.ProxySettingsAtServer();
#Else
	ProxyServerSetting = StandardSubsystemsClient.ClientRunParameters().ProxyServerSettings;
#EndIf
	
	Return ProxyServerSetting;
	
EndFunction

Function InternetProxyPresentation(Proxy)
	
	Log = New Array;
	Log.Add(StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Адрес:  %1:%2
		           |HTTP:   %3:%4
		           |Secure: %5:%6
		           |FTP:    %7:%8'; 
		           |en = 'Address:  %1:%2
		           |HTTP:   %3:%4
		           |Secure: %5:%6
		           |FTP:    %7:%8'; 
		           |pl = 'Adres:  %1:%2
		           |HTTP:   %3:%4
		           |Secure: %5:%6
		           |FTP:    %7:%8';
		           |es_ES = 'Dirección:  %1:%2
		           |HTTP:   %3:%4
		           |Secure: %5:%6
		           |FTP:    %7:%8';
		           |es_CO = 'Dirección:  %1:%2
		           |HTTP:   %3:%4
		           |Secure: %5:%6
		           |FTP:    %7:%8';
		           |tr = 'Adres:  %1:%2
		           |HTTP:   %3:%4
		           |Secure: %5:%6
		           |FTP:    %7:%8';
		           |it = 'Indirizzo:  %1:%2
		           |HTTP:   %3:%4
		           |Sicurezza: %5:%6
		           |FTP:    %7:%8';
		           |de = 'Adresse: %1:%2
		           |HTTP: %3:%4
		           |Secure: %5:%6
		           |FTP: %7:%8'"),
		Proxy.Server(),        Format(Proxy.Port(),        "NG="),
		Proxy.Server("http"),  Format(Proxy.Port("http"),  "NG="),
		Proxy.Server("https"), Format(Proxy.Port("https"), "NG="),
		Proxy.Server("ftp"),   Format(Proxy.Port("ftp"),   "NG=")));
	
	If Proxy.UseOSAuthentication("") Then 
		Log.Add(NStr("ru = 'Используется аутентификация операционной системы'; en = 'OS authentication is used'; pl = 'Używanie uwierzytelniania systemu operacyjnego';es_ES = 'Se usa autenticación del sistema operativo';es_CO = 'Se usa autenticación del sistema operativo';tr = 'İşletim sistemi kimlik doğrulaması kullanılır';it = 'L''autotenticazione da sistema operativo è usata';de = 'Die Authentifizierung des Betriebssystems wird verwendet'"));
	Else 
		User = Proxy.User("");
		Password = Proxy.Password("");
		PasswordState = ?(IsBlankString(Password), NStr("ru = '<не указано>'; en = '<not specified>'; pl = '<nieokreślony>';es_ES = '<no especificado>';es_CO = '<no especificado>';tr = '<belirtilmedi>';it = '<Non specificato>';de = '<nicht eingegeben>'"), NStr("ru = '********'; en = '********'; pl = '********';es_ES = '********';es_CO = '********';tr = '********';it = '********';de = '********'"));
		
		Log.Add(NStr("ru = 'Используется аутентификация по имени пользователя и паролю'; en = 'Authentication by user name and password is used'; pl = 'Wykorzystywane jest uwierzytelnianie według nazwy użytkownika i hasła';es_ES = 'Se usa la autenticación por el nombre de usuario y la contraseña';es_CO = 'Se usa la autenticación por el nombre de usuario y la contraseña';tr = 'Kullanıcı adı ve şifre kimlik doğrulaması kullanılır';it = 'L''autenticazione per username e password è utilizzata';de = 'Die Authentifizierung von Benutzername und Passwort wird verwendet.'"));
		Log.Add(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Пользователь: %1
			           |Пароль: %2'; 
			           |en = 'User: %1
			           |Password: %2'; 
			           |pl = 'Użytkownik: %1
			           |Hasło: %2';
			           |es_ES = 'Usuario: %1
			           |Contraseña: %2';
			           |es_CO = 'Usuario: %1
			           |Contraseña: %2';
			           |tr = 'Kullanıcı: %1
			           |Şifre: %2';
			           |it = 'Utente: %1
			           |Password: %2';
			           |de = 'Benutzer: %1
			           |Passwort: %2'"),
			User,
			PasswordState));
	EndIf;
	
	If Proxy.BypassProxyOnLocal Then 
		Log.Add(NStr("ru = 'Не использовать прокси для локальных адресов'; en = 'Bypass proxy for local URLs'; pl = 'Nie używać proxy dla lokalnych adresów';es_ES = 'Proxy de bypass para URLs locales';es_CO = 'Proxy de bypass para URLs locales';tr = 'Yerel URL''ler için baypas proxy''si';it = 'Ignora proxy per gli URL locali';de = 'Proxyserver für lokale URLs'"));
	EndIf;
	
	If Proxy.BypassProxyOnAddresses.Count() > 0 Then 
		Log.Add(NStr("ru = 'Не использовать для следующих адресов:'; en = 'Do not use for the following addresses:'; pl = 'Nie używaj dla następujących adresów:';es_ES = 'No usar para las siguientes direcciones:';es_CO = 'No usar para las siguientes direcciones:';tr = 'Aşağıdaki adresler için kullanma:';it = 'Non utilizzare i seguenti indirizzi:';de = 'Nicht für die folgenden Adressen verwenden:'"));
		For Each AddressToExclude In Proxy.BypassProxyOnAddresses Do
			Log.Add(AddressToExclude);
		EndDo;
	EndIf;
	
	Return StrConcat(Log, Chars.LF);
	
EndFunction

// Returns proxy according to settings ProxyServerSetting for the specified Protocol protocol.
//
// Parameters:
//   ProxyServerSetting - Map:
//		UseProxy - indicates whether to use proxy server.
//		BypassProxyOnLocal - indicates whether to use proxy server for local addresses.
//		UseSystemSettings - indicates whether to use proxy server system settings.
//		Server - proxy server address.
//		Port - proxy server port.
//		User - username for authorization on proxy server.
//		Password - user password.
//		UseOSAuthentication - Boolean - a flag that indicates the use of authentication by means of the operating system.
//   Protocol - String - protocol for which proxy server parameters are set, for example "http", "https",
//                       "ftp".
// 
// Returns:
//   InternetProxy
// 
Function NewInternetProxy(ProxyServerSetting, Protocol)
	
	If ProxyServerSetting = Undefined Then
		// Proxy server system settings.
		Return Undefined;
	EndIf;
	
	UseProxy = ProxyServerSetting.Get("UseProxy");
	If Not UseProxy Then
		// Do not use proxy server.
		Return New InternetProxy(False);
	EndIf;
	
	UseSystemSettings = ProxyServerSetting.Get("UseSystemSettings");
	If UseSystemSettings Then
		// Proxy server system settings.
		Return New InternetProxy(True);
	EndIf;
	
	// Manually configured proxy settings.
	Proxy = New InternetProxy;
	
	// Detect proxy server address and port.
	AdditionalSettings = ProxyServerSetting.Get("AdditionalProxySettings");
	ProxyToProtocol = Undefined;
	If TypeOf(AdditionalSettings) = Type("Map") Then
		ProxyToProtocol = AdditionalSettings.Get(Protocol);
	EndIf;
	
	UseOSAuthentication = ProxyServerSetting.Get("UseOSAuthentication");
	UseOSAuthentication = ?(UseOSAuthentication = True, True, False);
	
	If TypeOf(ProxyToProtocol) = Type("Structure") Then
		Proxy.Set(Protocol, ProxyToProtocol.Address, ProxyToProtocol.Port,
			ProxyServerSetting["User"], ProxyServerSetting["Password"], UseOSAuthentication);
	Else
		Proxy.Set(Protocol, ProxyServerSetting["Server"], ProxyServerSetting["Port"], 
			ProxyServerSetting["User"], ProxyServerSetting["Password"], UseOSAuthentication);
	EndIf;
	
	Proxy.BypassProxyOnLocal = ProxyServerSetting["BypassProxyOnLocal"];
	
	ExceptionsAddresses = ProxyServerSetting.Get("BypassProxyOnAddresses");
	If TypeOf(ExceptionsAddresses) = Type("Array") Then
		For each ExceptionAddress In ExceptionsAddresses Do
			Proxy.BypassProxyOnAddresses.Add(ExceptionAddress);
		EndDo;
	EndIf;
	
	Return Proxy;
	
EndFunction

// Writes error messages to the event log Event name
// "Getting files from the Internet".
// Parameters:
//   ErrorMessage - String - error message.
// 
Procedure WriteErrorToEventLog(Val ErrorMessage)
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	WriteLogEvent(
		EventLogEvent(),
		EventLogLevel.Error, , ,
		ErrorMessage);
#Else
	EventLogClient.AddMessageForEventLog(EventLogEvent(),
		"Error", ErrorMessage,,True);
#EndIf
	
EndProcedure

Function EventLogEvent() Export
	
	Return NStr("ru = 'Получение файлов из Интернета'; en = 'Get files from the Internet'; pl = 'Pobieranie plików z internetu';es_ES = 'Recepción de los archivos de Internet';es_CO = 'Recepción de los archivos de Internet';tr = 'İnternetten dosya al';it = 'Ricevere file da internet';de = 'Empfangen von Dateien aus dem Internet'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

#EndIf

#EndRegion