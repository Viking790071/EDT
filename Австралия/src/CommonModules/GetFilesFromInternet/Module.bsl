#Region Public

// Gets the file from the Internet via http(s) protocol or ftp protocol and saves it at the specified path on server.
//
// Parameters:
//   URL - String - file URL in the following format: [Protocol://]<Server>/<Path to the file on the server>.
//   ReceivingParameters - Structure - see GetFilesFromInternetClientServer.FileReceivingParameters. 
//   WriteError - Boolean - indicates the need to write errors to event log while getting the file.
//
// Returns:
//   Structure - structure with the following properties:
//      * Status - Boolean - file getting result.
//      * Path - String - path to the file on the server. This key is used only if Status is True.
//      * ErrorMessage - String - error message if Status is False.
//      * Headers - Map - see the details of the Headers parameter of the HTTPResponse object in Syntax Assistant.
//      * StatusCode - Number - adds in case of an error.
//                                    See the details of the StatusCode parameter of the HTTPResponse object in Syntax Assistant.
//
Function DownloadFileAtServer(Val URL, ReceivingParameters = Undefined, Val WriteError = True) Export
	
	SavingSetting = New Map;
	SavingSetting.Insert("Storage", "Server");
	
	Return GetFilesFromInternetClientServer.DownloadFile(URL,
		ReceivingParameters, SavingSetting, WriteError);
	
EndFunction

// Gets a file from the internet over HTTP(S) or FTP and saves it to a temporary storage.
// Note: After getting the file, clear the temporary storage by using the DeleteFromTempStorage 
// method. If you do not do it, the file will remain in the server memory until the session is over.
// 
//
// Parameters:
//   URL - String - file URL in the following format: [Protocol://]<Server>/<Path to the file on the server>.
//   ReceivingParameters - Structure - see GetFilesFromInternetClientServer.FileReceivingParameters. 
//   WriteError - Boolean - indicates the need to write errors to event log while getting the file.
//
// Returns:
//   Structure - structure with the following properties:
//      * Status - Boolean - file getting result.
//      * Path - String - temporary storage address with the file binary data, the key is used only 
//                            if Status is True.
//      * ErrorMessage - String - error message if Status is False.
//      * Headers - Map - see the details of the Headers parameter of the HTTPResponse object in Syntax Assistant.
//      * StatusCode - Number - adds in case of an error.
//                                    See the details of the StatusCode parameter of the HTTPResponse object in Syntax Assistant.
//
Function DownloadFileToTempStorage(Val URL, ReceivingParameters = Undefined, Val WriteError = True) Export
	
	SavingSetting = New Map;
	SavingSetting.Insert("Storage", "TemporaryStorage");
	
	Return GetFilesFromInternetClientServer.DownloadFile(URL,
		ReceivingParameters, SavingSetting, WriteError);
	
EndFunction

// Returns proxy settings of Internet access on the client side of the currnet user.
// 
//
// Returns:
//   Map - properties:
//		UseProxy - indicates whether to use proxy server.
//		BypassProxyOnLocal - indicates whether to use proxy server for local addresses.
//		UseSystemSettings - indicates whether to use proxy server system settings.
//		Server - proxy server address.
//		Port - proxy server port.
//		User - username for authorization on proxy server.
//		Password - user password.
//
Function ProxySettingsAtClient() Export
	
	Return Common.CommonSettingsStorageLoad("ProxyServerSetting", "");
	
EndFunction

// Returns proxy setting parameters on the 1C:Enterprise server side.
//
// Returns:
//   Map - properties:
//		UseProxy - indicates whether to use proxy server.
//		BypassProxyOnLocal - indicates whether to use proxy server for local addresses.
//		UseSystemSettings - indicates whether to use proxy server system settings.
//		Server - proxy server address.
//		Port - proxy server port.
//		User - username for authorization on proxy server.
//		Password - user password.
//
Function ProxySettingsAtServer() Export
	
	If Common.FileInfobase() Then
		Return ProxySettingsAtClient();
	Else
		SetPrivilegedMode(True);
		ProxySettingsAtServer = Constants.ProxyServerSetting.Get().Get();
		Return ?(TypeOf(ProxySettingsAtServer) = Type("Map"),
			ProxySettingsAtServer,
			Undefined);
	EndIf;
	
EndFunction

#EndRegion
