#Region Public

// Gets the file from the Internet via http(s) protocol or ftp protocol and saves it at the specified path on client
// Unavailable in web client. If you work in web client, use similar server procedures for 
// downloading files.
//
// Parameters:
//   URL - String - file URL in the following format: [Protocol://]<Server>/<Path to the file on the server>.
//   ReceivingParameters - Structure - see GetFilesFromInternetClientServer.FileReceivingParameters. 
//   WriteError - Boolean - indicates the need to write errors to event log while getting the file.
//
// Returns:
//   Structure - structure with the following properties:
//      * Status - Boolean - file getting result.
//      * Path - String - path to the file on the client. This key is used only if Status is True.
//      * ErrorMessage - String - error message if Status is False.
//      * Headers - Map - see the details of the Headers parameter of the HTTPResponse object in Syntax Assistant.
//      * StatusCode - Number - adds in case of an error.
//                                    See the details of the StatusCode parameter of the HTTPResponse object in Syntax Assistant.
//
Function DownloadFileAtClient(Val URL, Val ReceivingParameters = Undefined, Val WriteError = True) Export
	
#If WebClient Then
	Raise NStr("ru = 'Скачивание файлов на клиент недоступно при работе в веб-клиенте.'; en = 'Cannot download files to the client when working in web client.'; pl = 'Pobieranie danych z klienta nie jest możliwe dla tego klienta Web.';es_ES = 'No se puede descargar los archivos al cliente en el cliente web.';es_CO = 'No se puede descargar los archivos al cliente en el cliente web.';tr = 'Web istemcisinde çalışırken dosyalar istemciye indirilemez.';it = 'Impossibile scaricare file nel client quando si lavora come web client.';de = 'Das Herunterladen von Dateien auf den Client ist auf dem Webclient nicht möglich.'");
#EndIf
	
	ReceivingSettings = GetFilesFromInternetClientServer.FileGettingParameters();
	
	If ReceivingParameters <> Undefined Then
		
		FillPropertyValues(ReceivingSettings, ReceivingParameters);
		
	EndIf;
	
	SavingSetting = New Map;
	SavingSetting.Insert("Storage", "Client");
	SavingSetting.Insert("Path", ReceivingSettings.PathForSaving);
	
	Return GetFilesFromInternetClientServer.DownloadFile(URL, ReceivingParameters, SavingSetting, WriteError);
	
EndFunction

// Opens a proxy server parameters form.
//
// Parameters:
//    FormParameters - Structure - parameters of the form being opened.
//
Procedure OpenProxyServerParametersForm(FormParameters = Undefined) Export
	
	OpenForm("CommonForm.ProxyServerParameters", FormParameters);
	
EndProcedure

#EndRegion
