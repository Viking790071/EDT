#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Retrieves cache version data from the ValueStorage resource of the ProgramInterfaceCache register.
//
// Parameters:
//   ID - String - cache record ID.
//   DataType - EnumRef.ProgramInterfaceCacheDataTypes.
//   ReceivingParameters - String - parameter array serialized to XML for passing into the cache update procedure.
//   ReturnObsoleteData - Boolean - a flag that shows whether the procedure must wait for cache 
//      update before retrieving data if it is obsolete.
//      True - always use cache data, if any. False - wait for the cache update if data is obsolete.
//      
//
// Returns:
//   Arbitrary.
//
Function VersionCacheData(Val ID, Val DataType, Val ReceivingParameters, Val UseObsoleteData = True) Export
		
	Query = New Query;
	Query.Text =
		"SELECT
		|	CacheTable.UpdateDate AS UpdateDate,
		|	CacheTable.Data AS Data,
		|	CacheTable.DataType AS DataType
		|FROM
		|	InformationRegister.ProgramInterfaceCache AS CacheTable
		|WHERE
		|	CacheTable.ID = &ID
		|	AND CacheTable.DataType = &DataType";
	Query.SetParameter("ID", ID);
	Query.SetParameter("DataType", DataType);
	
	BeginTransaction();
	Try
		// Managed lock is not set, so other sessions can change the value while this transaction is active.
		SetPrivilegedMode(True);
		Result = Query.Execute();
		SetPrivilegedMode(False);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	UpdateRequired = False;
	RereadDataRequired = False;
	
	If Result.IsEmpty() Then
		
		UpdateRequired = True;
		RereadDataRequired = True;
		
	Else
		
		Selection = Result.Select();
		Selection.Next();
		If Not InterfaceCacheCurrent(Selection.UpdateDate) Then
			UpdateRequired = True;
			RereadDataRequired = NOT UseObsoleteData;
		EndIf;
	EndIf;
	
	If UpdateRequired Then
		
		UpdateInCurrentSession = RereadDataRequired
			Or Common.FileInfobase()
			Or ExclusiveMode()
			Or CommonClientServer.DebugMode()
			Or CurrentRunMode() = Undefined;
		
		If UpdateInCurrentSession Then
			UpdateVersionCacheData(ID, DataType, ReceivingParameters);
			RereadDataRequired = True;
		Else
			JobMethodName = "InformationRegisters.ProgramInterfaceCache.UpdateVersionCacheData";
			JobDescription = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Обновление кэша версий. Идентификатор записи %1. Тип данных %2.'; en = 'Version cache update. Entry ID: %1. Data type: %2.'; pl = 'Aktualizowanie pamięci podręcznej wersji. Identyfikator zapisu %1. Typ danych %2.';es_ES = 'Actualizando el caché de la versión. Identificador del registro%1. Tipo de datos %2.';es_CO = 'Actualizando el caché de la versión. Identificador del registro%1. Tipo de datos %2.';tr = 'Sürüm önbelleği güncelleniyor. Kayıt tanımlayıcısı. %1Veri tipi %2.';it = 'Aggiornamento cache di versione. Registro ID %1. Tipo di dati %2.';de = 'Versionscache wird aktualisiert. Kennung der Buchung %1. Datentyp %2.'"),
				ID,
				DataType);
			JobParameters = New Array;
			JobParameters.Add(ID);
			JobParameters.Add(DataType);
			JobParameters.Add(ReceivingParameters);
			
			JobsFilter = New Structure;
			JobsFilter.Insert("MethodName", JobMethodName);
			JobsFilter.Insert("Description", JobDescription);
			JobsFilter.Insert("State", BackgroundJobState.Active);
			
			Jobs = BackgroundJobs.GetBackgroundJobs(JobsFilter);
			If Jobs.Count() = 0 Then
				// Starting a new one.
				ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(Undefined);
				ExecutionParameters.BackgroundJobDescription = JobDescription;
				TimeConsumingOperations.RunBackgroundJobWithClientContext(JobMethodName,
					ExecutionParameters, JobParameters);
			EndIf;
		EndIf;
		
		If RereadDataRequired Then
			
			BeginTransaction();
			Try
				// Managed lock is not set, so other sessions can change the value while this transaction is active.
				SetPrivilegedMode(True);
				Result = Query.Execute();
				SetPrivilegedMode(False);
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
			
			If Result.IsEmpty() Then
				MessageTemplate = NStr("ru = 'Ошибка при обновлении кэша версий. Данные не получены.
					|Идентификатор записи: %1
					|Тип данных: %2'; 
					|en = 'Version cache update error. The data is not received.
					|Entry ID: %1
					|Data type: %2'; 
					|pl = 'Błąd podczas aktualizowania pamięci podręcznej wersji. Nie otrzymano danych.
					|Id wpisu: %1
					| Typ danych: %2';
					|es_ES = 'Error al actualizar el caché de las versiones. Los datos no han sido recibidos.
					|Identificador del registro: %1
					| Tipo de datos: %2';
					|es_CO = 'Error al actualizar el caché de las versiones. Los datos no han sido recibidos.
					|Identificador del registro: %1
					| Tipo de datos: %2';
					|tr = 'Sürümler önbelleği güncellenirken bir hata oluştu. Veri alınmıyor. 
					|Kayıt tanımlayıcısı: 
					|%1Veri türü:%2';
					|it = 'Errore aggiornamento versione cache. I dati non sono stati ricevuti.
					|ID inserimento:%1
					|Tipo dati: %2';
					|de = 'Fehler beim Update des Versionscache. Keine Daten empfangen.
					|Buchungs-ID: %1
					|Datentyp: %2'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, ID, DataType);
					
				Raise(MessageText);
			EndIf;
			
			Selection = Result.Select();
			Selection.Next();
		EndIf;
		
	EndIf;
		
	Return Selection.Data.Get();
	
EndFunction

// Updates data in the version cache.
//
// Parameters:
//  ID - String - cache record ID.
//  DataType - EnumRef.APICacheDataTypes - type of data to update.
//  ReceivingParameters - Array - additional options of getting data to the cache.
//
Procedure UpdateVersionCacheData(Val ID, Val DataType, Val ReceivingParameters) Export
	
	SetPrivilegedMode(True);
	
	KeyStructure = New Structure("ID, DataType", ID, DataType);
	varKey = CreateRecordKey(KeyStructure);
	
	Try
		LockDataForEdit(varKey);
	Except
		// The data is being updated from another session.
		Return;
	EndTry;
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	CacheTable.UpdateDate AS UpdateDate,
		|	CacheTable.Data AS Data,
		|	CacheTable.DataType AS DataType
		|FROM
		|	InformationRegister.ProgramInterfaceCache AS CacheTable
		|WHERE
		|	CacheTable.ID = &ID
		|	AND CacheTable.DataType = &DataType";
	ID = ID;
	Query.SetParameter("ID", ID);
	Query.SetParameter("DataType", DataType);
	
	BeginTransaction();
	
	Try
		
		Lock = New DataLock;
		LockItem = Lock.Add("InformationRegister.ProgramInterfaceCache");
		LockItem.SetValue("ID", ID);
		LockItem.SetValue("DataType", DataType);
		Lock.Lock();
		
		Result = Query.Execute();
		
		// Commiting the transaction so that other sessions can read data.
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		UnlockDataForEdit(varKey);
		Raise;
		
	EndTry;
	
	Try
		
		// Making sure the data must be updated.
		If Not Result.IsEmpty() Then
			
			Selection = Result.Select();
			Selection.Next();
			If InterfaceCacheCurrent(Selection.UpdateDate) Then
				UnlockDataForEdit(varKey);
				Return;
			EndIf;
			
		EndIf;
		
		Set = CreateRecordSet();
		Set.Filter.ID.Set(ID);
		Set.Filter.DataType.Set(DataType);
		
		Record = Set.Add();
		Record.ID = ID;
		Record.DataType = DataType;
		Record.UpdateDate = CurrentUniversalDate();
		
		Set.AdditionalProperties.Insert("ReceivingParameters", ReceivingParameters);
		Set.PrepareDataToRecord();
		
		Set.Write();
		
		UnlockDataForEdit(varKey);
		
	Except
		
		UnlockDataForEdit(varKey);
		Raise;
		
	EndTry;
	
EndProcedure

// Prepares the data for the interface cache.
//
// Parameters:
//  DataType - EnumRef.APICacheDataTypes - type of data to update.
//  ReceivingParameters - Array - additional options of getting data to the cache.
//
Function PrepareVersionCacheData(Val DataType, Val ReceivingParameters) Export
	
	If DataType = Enums.APICacheDataTypes.InterfaceVersions Then
		Data = GetInterfaceVersionsToCache(ReceivingParameters[0], ReceivingParameters[1]);
	ElsIf DataType = Enums.APICacheDataTypes.WebServiceDetails Then
		Data = GetWSDL(ReceivingParameters[0], ReceivingParameters[1], ReceivingParameters[2], ReceivingParameters[3], ReceivingParameters[4]);
	Else
		TextPattern = NStr("ru = 'Неизвестный тип данных кэша версий: %1'; en = 'Unknown version cache data type: %1.'; pl = 'Nieznany typ danych pamięci podręcznej wersji: %1';es_ES = 'Tipo de datos desconocido del caché de versiones: %1';es_CO = 'Tipo de datos desconocido del caché de versiones: %1';tr = 'Sürüm önbelleklerinin bilinmeyen veri türü:%1';it = 'Tipo di dati della cache di versione sconosciuto: %1.';de = 'Unbekannter Datentyp von Versionen Cache: %1.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(TextPattern, DataType);
		Raise(MessageText);
	EndIf;
	
	Return Data;
	
EndFunction

// Generates a version cache record ID based on a server address and a resource name.
//
// Parameters:
//  Address - String - server address.
//  Name - String - resource name.
//
// Returns:
//  String - version cache record ID.
//
Function VersionCacheRecordID(Val Address, Val Name) Export
	
	Return Address + "|" + Name;
	
EndFunction

Function InnerWSProxy(Parameters) Export
	
	WSDLAddress = Parameters.WSDLAddress;
	NamespaceURI = Parameters.NamespaceURI;
	ServiceName = Parameters.ServiceName;
	EndpointName = Parameters.EndpointName;
	Username = Parameters.UserName;
	Password = Parameters.Password;
	Timeout = Parameters.Timeout;
	Location = Parameters.Location;
	UseOSAuthentication = Parameters.UseOSAuthentication;
	SecureConnection = Parameters.SecureConnection;
	
	Protocol = "";
	Position = StrFind(WSDLAddress, "://");
	If Position > 0 Then
		Protocol = Lower(Left(WSDLAddress, Position - 1));
	EndIf;
		
	If (Protocol = "https" Or Protocol = "ftps") AND SecureConnection = Undefined Then
		Certificates = New OSCertificationAuthorityCertificates;
		SecureConnection = CommonClientServer.NewSecureConnection();
	EndIf;
	
	WSDefinitions = WSDefinitions(WSDLAddress, Username, Password,, SecureConnection);
	
	If IsBlankString(EndpointName) Then
		EndpointName = ServiceName + "Soap";
	EndIf;
	
	InternetProxy = Undefined;
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownloadClientServer = Common.CommonModule("GetFilesFromInternetClientServer");
		InternetProxy = ModuleNetworkDownloadClientServer.GetProxy(WSDLAddress);
	EndIf;
	
	Proxy = New WSProxy(WSDefinitions, NamespaceURI, ServiceName, EndpointName,
		InternetProxy, Timeout, SecureConnection, Location, UseOSAuthentication);
	
	Proxy.User = Username;
	Proxy.Password       = Password;
	
	Return Proxy;
EndFunction

#EndRegion


#Region Private

// Returns relevance of the version cache record.
//
// Parameters:
//  UpdateDate - Date - record update date.
//
// Returns:
//  Boolean - flag that shows whether the record is obsolete.
//
Function InterfaceCacheCurrent(UpdateDate)
	
	If ValueIsFilled(UpdateDate) Then
		Return UpdateDate + 24 * 60 * 60 > CurrentUniversalDate(); // caching no more than for 24 hours.
	EndIf;
	
	Return False;
	
EndFunction

// Returns the WSDefinitions object created with the passed parameters.
//
// Comment: during the Definition retrieving, the function uses the cache that is updated when the 
//  configuration version is changed. If one needs to update cached value before this time (for 
//  example, for debug purposes), delete the respective records from the
//  ProgramInterfaceCache information register.
//
// Parameters:
//  WSDLAddress - String - the wsdl location.
//  Username - String - the username used to sign in to a server.
//  Password - String - the user password.
//  Timeout - Number - timeout for wsdl receipt.
//  SecureConnection - OpenSSLSecureConnection, Undefined - (optional) secure connection parameters.
//
// Returns:
//  WSDefinitions
//
Function WSDefinitions(Val WSDLAddress, Val Username, Val Password, Val Timeout = 10, Val SecureConnection = Undefined)
	
	If Not Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		Try
			Definitions = New WSDefinitions(WSDLAddress, Username, Password, ,Timeout, SecureConnection);
		Except
			DiagnosticsResult = CommonClientServer.ConnectionDiagnostics(WSDLAddress);
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось получить WS-определения по адресу 
				           |%1
				           |по причине:
				           |%2
				           |
				           |Результат диагностики:
				           |%3'; 
				           |en = 'Cannot get WS definitions from address
				           |%1
				           |Reason:
				           |%2
				           |
				           |Diagnostics result:
				           |%3'; 
				           |pl = 'Nie można pobrać definicji WS według adresu 
				           |%1
				           |z powodu:
				           |%2
				           |
				           |Wynik diagnostyki:
				           |%3';
				           |es_ES = 'No se ha podido recibir las descripciones WS por la dirección
				           |%1
				           |a causa de:
				           |%2
				           |
				           |El resultado de diagnóstica:
				           |%3';
				           |es_CO = 'No se ha podido recibir las descripciones WS por la dirección
				           |%1
				           |a causa de:
				           |%2
				           |
				           |El resultado de diagnóstica:
				           |%3';
				           |tr = 'Aşağıdaki nedenle 
				           |%1
				           | WS-tanımlamalar elde edilemedi: 
				           |%2
				           |
				           | Tanılama sonucu: 
				           |%3';
				           |it = 'Impossibile ottenere le definizioni WS dall''indirizzo
				           |%1
				           |A causa di:
				           |%2
				           |
				           |Risultato della diagnosi:
				           |%3';
				           |de = 'WS-Definitionen konnten nicht nach Adresse
				           |%1
				           |abgerufen werden aufgrund von:
				           |%2
				           |
				           | Diagnoseergebnis:
				           |%3'"),
				WSDLAddress,
				BriefErrorDescription(ErrorInfo()),
				DiagnosticsResult.ErrorDescription);
				
			Raise ErrorText;
		EndTry;
		Return Definitions;
	EndIf;
	
	ReceivingParameters = New Array;
	ReceivingParameters.Add(WSDLAddress);
	ReceivingParameters.Add(Username);
	ReceivingParameters.Add(Password);
	ReceivingParameters.Add(Timeout);
	ReceivingParameters.Add(SecureConnection);

	WSDLData = VersionCacheData(
		WSDLAddress, 
		Enums.APICacheDataTypes.WebServiceDetails, 
		ReceivingParameters,
		False);
		
	WSDLFileName = GetTempFileName("wsdl");
	WSDLData.Write(WSDLFileName);
	
	InternetProxy = Undefined;
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownloadClientServer = Common.CommonModule("GetFilesFromInternetClientServer");
		InternetProxy = ModuleNetworkDownloadClientServer.GetProxy(WSDLAddress);
	EndIf;
	
	Try
		Definitions = New WSDefinitions(WSDLFileName, Username, Password, InternetProxy, Timeout, SecureConnection);
	Except
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось получить WS-определения из кэша 
			           |по причине:
			           |%1'; 
			           |en = 'Cannot get WS definitions from the cache.
			           |Reason:
			           |%1'; 
			           |pl = 'Nie udało się pobrać definicji WS z pamięci podręcznej 
			           |ze względu na:
			           |%1';
			           |es_ES = 'No se ha podido recibir las descripciones WS del caché
			           |a causa de:
			           |%1';
			           |es_CO = 'No se ha podido recibir las descripciones WS del caché
			           |a causa de:
			           |%1';
			           |tr = 'WS-tanımlamalar aşağıdaki nedenle %1önbellekten alınamadı: 
			           |
			           |';
			           |it = 'Impossibile ottenere le definizioni WS dalla cache.
			           |A causa di:
			           |%1';
			           |de = 'Fehler beim Abrufen der WS-Definitionen aus dem Cache
			           |aufgrund von:
			           |%1'"),
			BriefErrorDescription(ErrorInfo()));
		Raise ErrorText;
	EndTry;
	
	Try
		DeleteFiles(WSDLFileName);
	Except
		WriteLogEvent(NStr("ru = 'Получение WSDL'; en = 'Getting WSDL'; pl = 'Pobieranie WSDL';es_ES = 'Recibir WSDL';es_CO = 'Recibir WSDL';tr = 'WSDL alın';it = 'Ricezione WSDL';de = 'Erhalte WSDL'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return Definitions;
EndFunction

Function GetInterfaceVersionsToCache(Val ConnectionParameters, Val InterfaceName)
	
	If Not ConnectionParameters.Property("URL") 
		Or Not ValueIsFilled(ConnectionParameters.URL) Then
		
		Raise(NStr("ru = 'Не задан URL сервиса.'; en = 'The service URL is not set.'; pl = 'Nie określono adresu URL serwisu.';es_ES = 'URL del servicio no está especificado.';es_CO = 'URL del servicio no está especificado.';tr = 'Hizmetin URL''si belirlenmemiş.';it = 'L''URL di servizio non è impostato.';de = 'URL des Service ist nicht angegeben.'"));
	EndIf;
	
	If ConnectionParameters.Property("UserName")
		AND ValueIsFilled(ConnectionParameters.UserName) Then
		
		Username = ConnectionParameters.UserName;
		
		If ConnectionParameters.Property("Password") Then
			UserPassword = ConnectionParameters.Password;
		Else
			UserPassword = Undefined;
		EndIf;
		
	Else
		Username = Undefined;
		UserPassword = Undefined;
	EndIf;
	
	ServiceAddress = ConnectionParameters.URL + "/ws/InterfaceVersion?wsdl";
	
	
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("WSDLAddress", ServiceAddress);
	ConnectionParameters.Insert("NamespaceURI", "http://www.1c.ru/SaaS/1.0/WS");
	ConnectionParameters.Insert("ServiceName", "InterfaceVersion");
	ConnectionParameters.Insert("UserName", Username);
	ConnectionParameters.Insert("Password", UserPassword);
	ConnectionParameters.Insert("Timeout", 7);
	
	VersioningProxy = Common.CreateWSProxy(ConnectionParameters);
	
	XDTOArray = VersioningProxy.GetVersions(InterfaceName);
	If XDTOArray = Undefined Then
		Return New FixedArray(New Array);
	Else	
		Serializer = New XDTOSerializer(VersioningProxy.XDTOFactory);
		Return New FixedArray(Serializer.ReadXDTO(XDTOArray));
	EndIf;
	
EndFunction

Function GetWSDL(Val Address, Val Username, Val Password, Val Timeout, Val SecureConnection = Undefined)
	
	ReceivingParameters = New Structure;
	If NOT IsBlankString(Username) Then
		ReceivingParameters.Insert("User", Username);
		ReceivingParameters.Insert("Password", Password);
	EndIf;
	ReceivingParameters.Insert("Timeout", Timeout);
	ReceivingParameters.Insert("SecureConnection", SecureConnection);
	
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownload = Common.CommonModule("GetFilesFromInternet");
		FileDetails = ModuleNetworkDownload.DownloadFileAtServer(Address, ReceivingParameters);
	Else
		Raise 
			NStr("ru = 'Подсистема ""Получение файлов из интернета"" не доступна.'; en = 'The ""Get files from the internet"" subsystem is unavailable.'; pl = 'Podsystem ""Pobieranie plików z Internetu"" nie jest dostępny.';es_ES = 'El subsistema ""Recepción de archivos de Internet"" no está disponible.';es_CO = 'El subsistema ""Recepción de archivos de Internet"" no está disponible.';tr = '""İnternet''ten dosya alma"" alt sistemi kullanılamaz.';it = 'Il sottosistema ""Recupero di file da Internet"" non è disponibile.';de = 'Das Subsystem ""Dateien aus dem Internet beziehen"" ist nicht verfügbar.'");
	EndIf;
	
	If Not FileDetails.Status Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось получить файл описания web-сервиса
			           |по причине:
			           |%1'; 
			           |en = 'Cannot get the web service description file.
			           |Reason:
			           |%1'; 
			           |pl = 'Nie udało się pobrać pliku opisu serwisu web
			           |z powodu:
			           |%1';
			           |es_ES = 'No se ha podido recibir el archivo de descripción del servicio web
			           |a causa de:
			           |%1';
			           |es_CO = 'No se ha podido recibir el archivo de descripción del servicio web
			           |a causa de:
			           |%1';
			           |tr = 'Aşağıdaki nedenle web-servis 
			           |açıklama dosyası alınamadı: 
			           |%1';
			           |it = 'Impossibile ottenere il file di descrizione del web service.
			           |A causa di:
			           |%1';
			           |de = 'Fehler beim Abrufen der Webservice-Beschreibungsdatei
			           |aus folgendem Grund:
			           |%1'"),
			FileDetails.ErrorMessage);
	EndIf;
	
	Try
		Definitions = New WSDefinitions(FileDetails.Path, Username, Password,, Timeout, SecureConnection);
	Except
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось получить файл описания web-сервиса
			           |по причине:
			           |Не удалось получить WS-определения для сохранения в кэше:
			           |%1'; 
			           |en = 'Cannot get the web service description file.
			           |Reason:
			           |Cannot get WS definitions for storing to the cache:
			           |%1'; 
			           |pl = 'Nie udało się pobrać pliku opisu serwisu www
			           |z powodu:
			           |Nie można pobrać definicji WS do zapisania w pamięci podręcznej:
			           |%1';
			           |es_ES = 'No se ha podido recibir el archivo de la descripción del servicio web
			           |a causa de:
			           |No se ha podido recibir las descripciones WS para guardar en el caché:
			           |%1';
			           |es_CO = 'No se ha podido recibir el archivo de la descripción del servicio web
			           |a causa de:
			           |No se ha podido recibir las descripciones WS para guardar en el caché:
			           |%1';
			           |tr = 'Aşağıdaki nedenle web-servis 
			           |açıklama dosyası alınamadı: 
			           |Önbellekte kaydedilecek WS-tanımlamalar alınamadı: 
			           |%1';
			           |it = 'Impossibile ottenere il file di descrizione del web service.
			           |A causa di:
			           |Impossibile ottenere le definizioni WS per l''archiviazione nella cache:
			           |%1';
			           |de = 'Fehler beim Abrufen der Webservice-Beschreibungsdatei
			           |aus folgendem Grund:
			           |Fehler beim Abrufen der WS-Definitionen im Cache:
			           |%1'"),
			BriefErrorDescription(ErrorInfo()));
	EndTry;
	
	If Definitions.Services.Count() = 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось получить файл описания web-сервиса
			           |по причине:
			           |В полученном файле не содержится ни одного описания сервиса.
			           |
			           |Возможно, адрес файла описания указан неверно:
			           |%1'; 
			           |en = 'Cannot get the web service description file.
			           |Reason:
			           |The file does not contain web service descriptions.
			           |
			           |Probably the file address is incorrect:
			           |%1'; 
			           |pl = 'Nie można pobrać pliku opisu serwisu www
			           |z powodu:
			           |Plik otrzymany nie zawierał opisu serwisu.
			           |
			           |Adres pliku opisu może być niepoprawny:
			           |%1';
			           |es_ES = 'No se ha podido recibir archivo de descripción del servicio web
			           |a causa de:
			           |En el archivo recibido no hay ninguna descripción del servicio.
			           |
			           |Es posible que la dirección del archivo de descripción esté indicado incorrectamente:
			           |%1';
			           |es_CO = 'No se ha podido recibir archivo de descripción del servicio web
			           |a causa de:
			           |En el archivo recibido no hay ninguna descripción del servicio.
			           |
			           |Es posible que la dirección del archivo de descripción esté indicado incorrectamente:
			           |%1';
			           |tr = 'Web hizmeti açıklamasının dosyası 
			           |aşağıdaki nedenle alınamadı: 
			           |Alınan dosya herhangi bir servis açıklaması içermiyor. 
			           |
			           |Açıklama dosya adresi yanlış olabilir:%1
			           |';
			           |it = 'Impossibile ottenere il file di descrizione del web service.
			           |A causa di:
			           |Il file non contiene le descrizioni del web service.
			           |
			           |È possibile che l''indirizzo del file non sia corretto:
			           |%1';
			           |de = 'Fehler beim Abrufen der Webservice-Beschreibungsdatei
			           |aus folgendem Grund:
			           |Die empfangene Datei enthält keine Dienstbeschreibung.
			           |
			           |Die Adresse der Beschreibungsdatei ist möglicherweise falsch:
			           |%1'"),
			Address);
	EndIf;
	Definitions = Undefined;
	
	FileData = New BinaryData(FileDetails.Path);
	
	Try
		DeleteFiles(FileDetails.Path);
	Except
		WriteLogEvent(NStr("ru = 'Получение WSDL'; en = 'Getting WSDL'; pl = 'Pobieranie WSDL';es_ES = 'Recibir WSDL';es_CO = 'Recibir WSDL';tr = 'WSDL alın';it = 'Ricezione WSDL';de = 'Erhalte WSDL'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return FileData;
	
EndFunction

#EndRegion

#EndIf