#Region Public

#Region ObsoleteProceduresAndFunctions

// Obsolete. It will be removed in the next library version.
// Returns an array of methods that can be executed in safe mode.
// 
//
// Returns:
//   Array - an array of strings that store the allowed methods.
//
Function GetAllowedMethods() Export
	
	Result = New Array();
	
	Return New FixedArray(Result);
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns a dictionary of synonyms and parameters of additional report and data processor 
// permission types (for displaying in the user interface).
//
// Returns:
//  FixedMap - keys:
//    * Key - XDTOType - a key appropriate to the permission kind.
//    * Value - Structure - keys:
//        * Presentation - String - a short presentation of the permission kind.
//        * Description - String - detailed description of the permission kind.
//        * Parameters - ValueTable - columns:
//            * Name - String - name of the attribute defined for XDTOType.
//            * Description - String - description of permission effects for the specified parameter value.
//        * AnyValueDetails - String - description of permission effects for an undefined parameter value.
//
Function Dictionary() Export
	
	Result = New Map();
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}GetFileFromInternet
	
	Presentation = NStr("ru = 'Получение данных из сети Интернет'; en = 'Receive data from the Internet'; pl = 'Pobieranie danych z Internetu';es_ES = 'Recibiendo datos de Internet';es_CO = 'Recibiendo datos de Internet';tr = 'İnternetten veri al';it = 'Ricevere dati da internet';de = 'Empfangen von Daten aus dem Internet'");
	Details = NStr("ru = 'Дополнительному отчету или обработке будет разрешено получать данные из сети Интернет'; en = 'Additional report or data processor is allowed to receive data from the Internet.'; pl = 'Dodatkowe sprawozdanie lub procedura przetwarzania danych będą mogły odbierać dane z Internetu';es_ES = 'Se permitirá al informe adicional o el procesador recibir los datos de Internet';es_CO = 'Se permitirá al informe adicional o el procesador recibir los datos de Internet';tr = 'Ek rapor veya veri işlemcisinin internetten veri almasına izin verilir.';it = 'Report aggiuntivo o elaboratore dati abilitato a ricevere dati da internet.';de = 'Ein zusätzlicher Bericht oder Datenprozessor darf Daten aus dem Internet empfangen'");
	
	Parameters = ParametersTable();
	AddParameter(Parameters, "Host", NStr("ru = 'с сервера %1'; en = 'from server %1'; pl = 'z serwera %1';es_ES = 'del servidor %1';es_CO = 'del servidor %1';tr = 'sunucudan %1';it = 'dal server %1';de = 'vom Server %1'"), NStr("ru = 'с любого сервера'; en = 'from any server'; pl = 'z dowolnego serwera';es_ES = 'de cualquier servidor';es_CO = 'de cualquier servidor';tr = 'herhangi bir sunucudan';it = 'da qualsiasi server';de = 'von jedem Server'"));
	AddParameter(Parameters, "Protocol", NStr("ru = 'по протоколу %1'; en = 'using protocol: %1'; pl = 'protokołem %1';es_ES = 'según el protocolo %1';es_CO = 'según el protocolo %1';tr = 'protokole göre%1';it = 'utilizzo protocollo: %1';de = 'nach Protokoll %1'"), NStr("ru = 'по любому протоколу'; en = 'with any protocol'; pl = 'dowolnym protokołem';es_ES = 'según cualquier protocolo';es_CO = 'según cualquier protocolo';tr = 'herhangi bir protokole göre';it = 'con qualsiasi protocollo';de = 'durch irgendein Protokoll'"));
	AddParameter(Parameters, "Port", NStr("ru = 'через порт %1'; en = 'through port: %1'; pl = 'przez port %1';es_ES = 'a través del puerto %1';es_CO = 'a través del puerto %1';tr = 'port ile%1';it = 'tramite la porta: %1';de = 'über Port %1'"), NStr("ru = 'через любой порт'; en = 'through any port'; pl = 'przez dowolny port';es_ES = 'a través cualquier puerto';es_CO = 'a través cualquier puerto';tr = 'herhangi port ile';it = 'tramite qualsiasi porta';de = 'über einen beliebigen Port'"));
	
	Value = New Structure;
	Value.Insert("Presentation", Presentation);
	Value.Insert("Details", Details);
	Value.Insert("Parameters", Parameters);
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsSafeModeInterface.DataReceivingFromInternetType(),
		Value);
	
	// End {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}GetFileFromInternet
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}SendFileToInternet
	
	Presentation = NStr("ru = 'Передача данных в сеть Интернет'; en = 'Send data to the Internet'; pl = 'Transfer danych do Internetu';es_ES = 'Traslado de datos a Internet';es_CO = 'Traslado de datos a Internet';tr = 'İnternete veri gönder';it = 'Inviare dati a internet';de = 'Datenübertragung ins Internet'");
	Details = NStr("ru = 'Дополнительному отчету или обработке будет разрешено отправлять данные в сеть Интернет'; en = 'Additional report or data processor is allowed to send data to the Internet'; pl = 'Dodatkowe sprawozdanie lub przetwarzanie danych będą mogły wysyłać dane do Internetu';es_ES = 'Se permitirá al informe adicional o el procesador de datos enviar los datos a Internet';es_CO = 'Se permitirá al informe adicional o el procesador de datos enviar los datos a Internet';tr = 'Ek rapor veya veri işlemcisinin internete veri göndermesine izin verilir';it = 'Report aggiuntivo o elaboratore dati abilitato a inviare dati a internet';de = 'Ein zusätzlicher Bericht oder Datenprozessor darf Daten an das Internet senden'");
	Consequences = NStr("ru = 'Внимание! Отправка данных потенциально может использоваться дополнительным
                        |отчетом или обработкой для совершения действий, не предполагаемых администратором
                        |информационной базы.
                        |
                        |Используйте данный дополнительный отчет или обработку только в том случае, если доверяете
                        |ее разработчику и контролируйте ограничения (сервер, протокол и порт), накладываемые на
                        |выданные разрешения.'; 
                        |en = 'Warning! Additional report or data processor may potentially use data sending for actions
                        |that are not intended by
                        |the infobase administrator.
                        |
                        |Use this additional report or data processor only if you trust
                        |the developer and control restrictions (server, protocol and port) applied to
                        |the issued permissions.'; 
                        |pl = 'Uwaga! Wysłanie danych potencjalnie może być używane przez sprawozdanie
                        |lub przetwarzanie dodatkowe do dokonania czynności, nie zakładanych przez administratora
                        |bazy informacyjnej.
                        |
                        |Korzystaj z danego sprawozdania lub przetwarzania dodatkowego tylko wtedy, gdy ufasz
                        |jej programisty i kontroluj ograniczenia (serwer, protokół i port), nałożone na
                        |wydane zezwolenia.';
                        |es_ES = '¡Aviso! El envío de los datos potencialmente puede utilizarse por un informe
                        |adicional o un procesador de datos para actos, que no están alegados por el administrador
                        |de las infobases.
                        |
                        |Utilizar este informe adicional o el procesador de datos solo si usted confía
                        |en el desarrollador, y controlar la restricción (servidor, protocolo y puerto),
                        |adjuntada a los permisos emitidos.';
                        |es_CO = '¡Aviso! El envío de los datos potencialmente puede utilizarse por un informe
                        |adicional o un procesador de datos para actos, que no están alegados por el administrador
                        |de las infobases.
                        |
                        |Utilizar este informe adicional o el procesador de datos solo si usted confía
                        |en el desarrollador, y controlar la restricción (servidor, protocolo y puerto),
                        |adjuntada a los permisos emitidos.';
                        |tr = 'Uyarı! Potansiyel olarak veri gönderimi, 
                        |veritabanları yöneticisi tarafından öngörülmeyen eylemler için ek bir rapor veya veri işlemcisi tarafından kullanılabilir. 
                        |
                        |Bu ek raporu veya veri işlemciyi, yalnızca yayımlanmış izinlere eklenmiş geliştiriciye ve denetim kısıtlamasına (sunucu, protokol ve bağlantı noktası) 
                        |
                        |güveniyorsanız kullanın.
                        |';
                        |it = 'Attenzione! Il report aggiuntivo o l''elaboratore dati potrebbe utilizzare l''invio dati per azioni
                        |non previste dall''amministratore
                        |dell''infobase.
                        |
                        |Utilizzare questo report aggiuntivo o elaboratore dati solo in caso vi fidiate dello sviluppator
                        |e e delle restrizioni di controllo (server, protocollo e porte) applicate ai permessi
                        |emessi.';
                        |de = 'Achtung: Das Senden von Daten kann möglicherweise von einem zusätzlichen
                        |Bericht oder einer zusätzlichen Verarbeitung verwendet werden, um Aktionen durchzuführen, die vom Administrator
                        |der Datenbank nicht erwartet werden.
                        |
                        |Verwenden Sie diesen zusätzlichen Bericht oder diese Verarbeitung nur, wenn Sie
                        |dem Entwickler vertrauen und die Einschränkungen (Server, Protokoll und Port) kontrollieren, die sich
                        |aus den erteilten Berechtigungen ergeben.'");
	
	Parameters = ParametersTable();
	AddParameter(Parameters, "Host", NStr("ru = 'на сервер %1'; en = 'to server %1'; pl = 'na serwer %1';es_ES = 'al servidor %1';es_CO = 'al servidor %1';tr = 'sunucuya %1';it = 'al server %1';de = 'zum Server %1'"), NStr("ru = 'на любой сервера'; en = 'on any  server'; pl = 'na dowolny serwer';es_ES = 'en cualquier servidor';es_CO = 'en cualquier servidor';tr = 'herhangi bir sunucuda';it = 'su qualsiasi server';de = 'auf jedem Server'"));
	AddParameter(Parameters, "Protocol", NStr("ru = 'по протоколу %1'; en = 'using protocol: %1'; pl = 'protokołem %1';es_ES = 'según el protocolo %1';es_CO = 'según el protocolo %1';tr = 'protokole göre%1';it = 'utilizzo protocollo: %1';de = 'nach Protokoll %1'"), NStr("ru = 'по любому протоколу'; en = 'with any protocol'; pl = 'dowolnym protokołem';es_ES = 'según cualquier protocolo';es_CO = 'según cualquier protocolo';tr = 'herhangi bir protokole göre';it = 'con qualsiasi protocollo';de = 'durch irgendein Protokoll'"));
	AddParameter(Parameters, "Port", NStr("ru = 'через порт %1'; en = 'through port: %1'; pl = 'przez port %1';es_ES = 'a través del puerto %1';es_CO = 'a través del puerto %1';tr = 'port ile%1';it = 'tramite la porta: %1';de = 'über Port %1'"), NStr("ru = 'через любой порт'; en = 'through any port'; pl = 'przez dowolny port';es_ES = 'a través cualquier puerto';es_CO = 'a través cualquier puerto';tr = 'herhangi port ile';it = 'tramite qualsiasi porta';de = 'über einen beliebigen Port'"));
	
	Value = New Structure;
	Value.Insert("Presentation", Presentation);
	Value.Insert("Details", Details);
	Value.Insert("Consequences", Consequences);
	Value.Insert("Parameters", Parameters);
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsSafeModeInterface.DataSendingToInternetType(),
		Value);
	
	// End {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}SendFileToInternet
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}SoapConnect
	
	Presentation = NStr("ru = 'Обращение к веб-сервисам в сети Интернет'; en = 'Access web services in the Internet'; pl = 'Kontakt z serwisami sieci Web w Internecie';es_ES = 'Contactando los servicios web en Internet';es_CO = 'Contactando los servicios web en Internet';tr = 'İnternette web servislerine başvurma';it = 'Accesso ai servizi web su internet';de = 'Kontaktaufnahme mit Internetservices im Internet'");
	Details = NStr("ru = 'Дополнительному отчету или обработке будет разрешено обращаться к веб-сервисам, расположенным в сети Интернет (при этом возможно как получение дополнительным отчетом или обработкой информации из сети Интернет, так и передача.'; en = 'Additional report or data processor is allowed to access web services located in the Internet. This can include sending data to the Internet or receiving data from the Internet.'; pl = 'Dodatkowy raport lub przetwarzanie danych będzie mogło odwoływać się do usług sieciowych w Internecie. On może zawierać wysyłane dane do Internetu lub przyjmowane dane z Internetu.';es_ES = 'Se permitirá al informe adicional o el procesador de datos referirse a los servicios web en Internet (informe adicional o procesador de datos puede recibir y enviar alguna información en Internet.';es_CO = 'Se permitirá al informe adicional o el procesador de datos referirse a los servicios web en Internet (informe adicional o procesador de datos puede recibir y enviar alguna información en Internet.';tr = 'Ek rapor veya veri işlemcisinin internetteki web servislerine başvurmasına izin verilecektir (ek rapor veya veri işlemcisi İnternet hakkında bazı bilgiler alabilir ve gönderebilir.';it = 'Report aggiuntivo o elaboratore dati abilitati ad accedere ai servizi web su internet. Questo include l''invio di dati a internet o la ricezione dati da esso.';de = 'Ein zusätzlicher Bericht oder Datenverarbeiter darf auf Webservices im Internet verweisen (ein zusätzlicher Bericht oder Datenprozessor kann einige Informationen im Internet empfangen und senden).'");
	Consequences = NStr("ru = 'Внимание! Обращение к веб-сервисам потенциально может использоваться дополнительным
                        |отчетом или обработкой для совершения действий, не предполагаемых администратором
                        |информационной базы.
                        |
                        |Используйте данный дополнительный отчет или обработку только в том случае, если доверяете
                        |ее разработчику и контролируйте ограничения (адрес подключения), накладываемые на
                        |выданные разрешения.'; 
                        |en = 'Warning! The additional report or data processor might invoke web services to perform actions
                        |that are not intended by
                        |the infobase administrator.
                        |
                        |Use this additional report or data processor only if you trust
                        |the developer, and verify the restrictions applied to
                        |the issued permissions (the connection address).'; 
                        |pl = 'Uwaga! Zwrócenie się do usług internetowych potencjalnie może być używane przez sprawozdanie lub przetwarzanie dodatkowe
                        | do dokonania czynności, nie zakładanych przez administratora
                        |bazy informacyjnej.
                        |
                        |Korzystaj z danego sprawozdania lub przetwarzania dodatkowego tylko wtedy, gdy ufasz
                        |jej programisty i kontroluj ograniczenia (adres podłączenia), nałożone na
                        |wydane zezwolenia.';
                        |es_ES = '¡Aviso! Llamada a los servicios web potencialmente puede utilizarse por un informe
                        |adicional o un procesador de datos para acciones que no están alegadas por el administrador
                        |de las infobases.
                        |
                        |Utilizar este informe adicional o el procesador de datos solo si usted
                        |confía en el desarrollador, y controlar la restricción (dirección de la conexión), adjuntada
                        |a los permisos emitidos.';
                        |es_CO = '¡Aviso! Llamada a los servicios web potencialmente puede utilizarse por un informe
                        |adicional o un procesador de datos para acciones que no están alegadas por el administrador
                        |de las infobases.
                        |
                        |Utilizar este informe adicional o el procesador de datos solo si usted
                        |confía en el desarrollador, y controlar la restricción (dirección de la conexión), adjuntada
                        |a los permisos emitidos.';
                        |tr = 'Uyarı! Potansiyel olarak web hizmetlerine başvuru, 
                        |veritabanları yöneticisi tarafından öngörülmeyen 
                        |eylemler için ek bir rapor veya veri işlemcisi tarafından kullanılabilir. 
                        |
                        |Bu ek raporu veya veri işlemciyi, yalnızca yayımlanmış 
                        |izinlere eklenmiş geliştiriciye ve denetim kısıtlamasına (sunucu, protokol ve bağlantı noktası) 
                        |güveniyorsanız kullanın.';
                        |it = 'Attenzione! Il report aggiuntivo o elaboratore dati potrebbe richiedere servizi web per eseguire azioni
                        |non richieste da parte
                        |dell''amministratore di infobase.
                        |
                        |Utilizzare questo report aggiuntivo o elaboratore dati solo in caso vi fidiate dello sviluppatore
                        | e verificare le restrizioni applicate ai permessi
                        |emessi (indirizzo della connessione).';
                        |de = 'Achtung! Der Zugriff auf Webservice kann möglicherweise von einem zusätzlichen
                        |Bericht oder einer zusätzlichen Verarbeitung verwendet werden, um Aktionen auszuführen, die vom Administrator
                        |der Informationsbasis nicht beabsichtigt sind.
                        |
                        |Verwenden Sie diesen zusätzlichen Bericht oder diese Verarbeitung nur, wenn Sie
                        |dem Entwickler darauf vertrauen und die Einschränkungen (Verbindungsadresse) für die
                        |erteilten Berechtigungen kontrollieren.'");
	
	Parameters = ParametersTable();
	AddParameter(Parameters, "WsdlDestination", NStr("ru = 'по адресу %1'; en = 'at address: %1'; pl = 'pod adresem %1';es_ES = 'en la dirección %1';es_CO = 'en la dirección %1';tr = 'adreste %1';it = 'all''indirizzo: %1';de = 'an die Adresse %1'"), NStr("ru = 'по любому адресу'; en = 'at any address'; pl = 'pod dowolnym adresem';es_ES = 'por cualquier dirección';es_CO = 'por cualquier dirección';tr = 'herhangi bir adrese göre';it = 'a qualsiasi indirizzo';de = 'durch irgendeine Adresse'"));
	
	Value = New Structure;
	Value.Insert("Presentation", Presentation);
	Value.Insert("Details", Details);
	Value.Insert("Consequences", Consequences);
	Value.Insert("Parameters", Parameters);
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsSafeModeInterface.WSConnectionType(),
		Value);
	
	// End {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}SoapConnect
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}CreateComObject
	
	Presentation = NStr("ru = 'Создание COM-объекта'; en = 'Create COM objects'; pl = 'Utwórz obiekt COM';es_ES = 'Crear el objeto COM';es_CO = 'Crear el objeto COM';tr = 'COM nesnesini oluştur';it = 'Creare oggetti COM';de = 'Erstellen Sie ein COM-Objekt'");
	Details = NStr("ru = 'Дополнительному отчету или обработке будет разрешено использовать механизмы внешнего программного обеспечения с помощью COM-соединения'; en = 'Additional report or data processor is allowed to utilize third-party software functionality using COM connections.'; pl = 'Dodatkowe sprawozdanie lub przetwarzanie danych będzie mogło korzystać z mechanizmów oprogramowania zewnętrznego korzystającego z połączenia COM';es_ES = 'Se permitirá al informe adicional o el procesador de datos utilizar los mecanismos del software externo utilizando la conexión COM';es_CO = 'Se permitirá al informe adicional o el procesador de datos utilizar los mecanismos del software externo utilizando la conexión COM';tr = 'Ek rapor veya veri işlemcisinin COM bağlantısı kullanarak harici yazılım mekanizmalarını kullanmasına izin verilecektir.';it = 'Report aggiuntivo o elaboratore dati abilitati a utilizzare le funzionalità di software di terze parti utilizzando connessioni COM.';de = 'Zusätzlicher Bericht oder Datenprozessor darf Mechanismen externer Software über COM-Verbindung verwenden'");
	Consequences = NStr("ru = 'Внимание! Использование средств стороннего программного обеспечения может использоваться
                        |дополнительным отчетом или обработкой для совершения действий, не предполагаемых администратором
                        |информационной базы, а также для несанкционированного обхода ограничений, накладываемых на дополнительную обработку
                        |в безопасном режиме.
                        |
                        |Используйте данный дополнительный отчет или обработку только в том случае, если доверяете
                        |ее разработчику и контролируйте ограничения (программный идентификатор), накладываемые на
                        |выданные разрешения.'; 
                        |en = 'Warning! Additional report or data processor may use third-party software features for actions
                        |that are not intended by the infobase administrator,
                        |and for unauthorized circumvention of restrictions applied to additional data processor
                        |in the safe mode.
                        |
                        |Use this additional report or data processor only if you trust
                        |the developer and control restrictions (application ID)
                        |applied to the issued permissions.'; 
                        |pl = 'Uwaga! Użycie środków oprogramowania postronnego może być stosowane
                        |przez sprawozdanie lub przetwarzanie dodatkowe do dokonania czynności, nie zakładanych przez administratora
                        |bazy informacyjnej oraz do niedozwolonego obejścia ograniczeń, nałożonych na przetwarzanie dodatkowe
                        |w trybie bezpiecznym.
                        |
                        |Korzystaj z danego sprawozdania lub przetwarzania dodatkowego tylko wtedy, gdy ufasz
                        |jej programisty i kontroluj ograniczenia (identyfikator programowy), nałożone na
                        |wydane zezwolenia.';
                        |es_ES = '¡Aviso! Uso de los fondos del software de la tercera parte puede utilizarse
                        |por un informe adicional o un procesador de datos para acciones que no están alegadas por el administrador
                        |de la infobase, y también para una circunvención no autorizada de las restricciones impuestas por el procesamiento adicional
                        |en el modo seguro.
                        |
                        |Utilizar este informe adicional o el procesador de datos solo si
                        |usted confía en el desarrollador, y controlar la restricción (identificador de la aplicación),
                        |adjuntada a los permisos emitidos.';
                        |es_CO = '¡Aviso! Uso de los fondos del software de la tercera parte puede utilizarse
                        |por un informe adicional o un procesador de datos para acciones que no están alegadas por el administrador
                        |de la infobase, y también para una circunvención no autorizada de las restricciones impuestas por el procesamiento adicional
                        |en el modo seguro.
                        |
                        |Utilizar este informe adicional o el procesador de datos solo si
                        |usted confía en el desarrollador, y controlar la restricción (identificador de la aplicación),
                        |adjuntada a los permisos emitidos.';
                        |tr = 'Uyarı! Üçüncü taraf yazılım fonlarının kullanımı, 
                        | veritabanı yöneticisi tarafından öngörülmeyen eylemler için ek bir rapor veya veri işlemcisi tarafından kullanılabilir ve ayrıca ek işlemin güvenli 
                        |modda getirdiği kısıtlamaların izinsiz olarak atlatılması için kullanılabilir. 
                        |
                        |Bu ek raporu veya veri işlemcisini, 
                        |yalnızca verilen izinlere eklenmiş geliştiriciye 
                        |ve kontrol kısıtlamasına (uygulama kimliği) 
                        |güveniyorsanız kullanın.';
                        |it = 'Attenzione! Il report aggiuntivo o elaboratore dati potrebbe utilizzare funzionalità di software di terze parti
                        |non richieste dall''amministratore dell''infobase,
                        |e per elusione non autorizzata delle restrizioni applicate all''elaboratore dati aggiuntivo
                        |in modalità sicura.
                        |
                        |Utilizzare questo report aggiuntivo o elaboratore dati solo nel caso vi fidiate dello sviluppatore
                        | e se controllate le restrizioni (ID applicazione)
                        |applicate ai permessi emessi.';
                        |de = 'Achtung: Die Verwendung von Softwaretools von Drittanbietern kann durch
                        |zusätzliche Berichterstattung oder Verarbeitung genutzt werden, um Aktionen durchzuführen, die nicht vom Administrator
                        |der Informationsdatenbank angenommen werden, sowie zur unbefugten Umgehung von Einschränkungen der zusätzlichen Verarbeitung
                        |im abgesicherten Modus.
                        |
                        |Verwenden Sie diesen zusätzlichen Bericht oder diese Verarbeitung nur, wenn Sie
                        |dem Entwickler vertrauen und die Einschränkungen (Softwarekennung) für die
                        |erteilten Berechtigungen kontrollieren.'");
	
	Parameters = ParametersTable();
	AddParameter(Parameters, "ProgId", NStr("ru = 'с программным идентификатором %1'; en = 'with software ID: %1'; pl = 'z dowolnym identyfikatorem programowym %1';es_ES = 'con el identificador programático %1';es_CO = 'con el identificador programático %1';tr = 'program tanımlayıcısıyla %1';it = 'con ID software: %1';de = 'mit Programmkennung %1'"), NStr("ru = 'с любым программным идентификатором'; en = 'with any software ID'; pl = 'z dowolnym identyfikatorem programowym';es_ES = 'con cualquier identificados programático';es_CO = 'con cualquier identificados programático';tr = 'herhangi bir program tanımlayıcı ile';it = 'con qualsiasi ID software';de = 'mit irgendeiner Programmkennung'"));
	
	Value = New Structure;
	Value.Insert("Presentation", Presentation);
	Value.Insert("Details", Details);
	Value.Insert("Consequences", Consequences);
	Value.Insert("Parameters", Parameters);
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsSafeModeInterface.COMObjectCreationType(),
		Value);
	
	// End {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}CreateComObject
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}AttachAddin
	
	Presentation = NStr("ru = 'Создание объекта внешней компоненту'; en = 'Create add-in objects'; pl = 'Utwórz obiekt komponentu zewnętrznego';es_ES = 'Crear el objeto del componente externo';es_CO = 'Crear el objeto del componente externo';tr = 'Harici bileşenin nesnesini oluştur';it = 'Creare componenti aggiuntive';de = 'Objekt der externen Komponente erstellen'");
	Details = NStr("ru = 'Дополнительному отчету или обработке будет разрешено использовать механизмы внешнего программного обеспечения с помощью создания объекта внешней компоненты, поставляемой в макете конфигурации'; en = 'Additional report or data processor is allowed to utilize third-party software functionality through creation of add-in objects based on add-ins supplied in the configuration template.'; pl = 'Dodatkowe sprawozdanie lub przetwarzanie danych będzie mogło korzystać z mechanizmów oprogramowania zewnętrznego poprzez tworzenie obiektu komponentu zewnętrznego, który jest dostarczany w szablonie konfiguracji';es_ES = 'Se permitirá al informe adicional o el procesador de datos utilizar los mecanismos del software externo creando un objeto del componente externo, que se proporciona en el modelo de la configuración.';es_CO = 'Se permitirá al informe adicional o el procesador de datos utilizar los mecanismos del software externo creando un objeto del componente externo, que se proporciona en el modelo de la configuración.';tr = 'Ek rapor veya veri işlemcisinin, yapılandırma şablonunda sağlanan harici bileşen nesnesini oluşturarak harici yazılım mekanizmalarını kullanmasına izin verilir.';it = 'Il report aggiuntivo o elaboratore dati sono abilitati a utilizzare le funzionalità di software di terze parti tramite la creazione di oggetti di componenti aggiuntive basati su componenti aggiuntive fornite nel modello di configurazione.';de = 'Ein zusätzlicher Bericht oder Datenprozessor kann Mechanismen externer Software verwenden, indem er ein Objekte einer externen Komponente erstellt, die in der Konfigurationsvorlage enthalten ist.'");
	Consequences = NStr("ru = 'Внимание! Использование средств стороннего программного обеспечения может использоваться
                        |дополнительным отчетом или обработкой для совершения действий, не предполагаемых администратором
                        |информационной базы, а также для несанкционированного обхода ограничений, накладываемых на дополнительную обработку
                        |в безопасном режиме.
                        |
                        |Используйте данный дополнительный отчет или обработку только в том случае, если доверяете
                        |ее разработчику и контролируйте ограничения (имя макета, из которого выполняется подключение внешней
                        |компоненты), накладываемые на выданные разрешения.'; 
                        |en = 'Warning! The additional report or data processor might use third-party software features to perform actions
                        |that are not intended by the infobase administrator,
                        |and also to bypass restrictions applied to the additional data processor
                        |in safe mode.
                        |
                        |Use this additional report or data processor only if you trust
                        |the developer, and verify the restrictions applied to
                        |the issued permissions (the name of the source template).'; 
                        |pl = 'Uwaga! Użycie środków oprogramowania postronnego może być stosowane
                        |przez sprawozdanie lub przetwarzanie dodatkowe do dokonania czynności, nie zakładanych przez administratora
                        |bazy informacyjnej oraz do niedozwolonego obejścia ograniczeń nałożonych na przetwarzanie dodatkowe
                        |w trybie bezpiecznym.
                        |
                        |Korzystaj z danego sprawozdania lub przetwarzania dodatkowego tylko wtedy, gdy ufasz
                        |jej programisty i kontroluj ograniczenia (nazwa makiety, z której jest wykonywane podłączenie komponentu
                        |zewnętrznego), nałożone na wydane zezwolenia.';
                        |es_ES = '¡Aviso! Uso de los fondos del software de la tercera perta puede utilizarse
                        |por un informe adicional o un procesador de datos para acciones que no están alegadas por el administrador
                        |de la infobase, y también para una circunvención no autorizada por el procesamiento adicional
                        |en el modo seguro.
                        |
                        |Utilizar este informe adicional o el procesador de datos solo si usted
                        |confía en el desarrollador, y controlar la restricción (nombre del modelo, desde el cual la conexión
                        |es un componente externo), adjuntada a los permisos emitidos.';
                        |es_CO = '¡Aviso! Uso de los fondos del software de la tercera perta puede utilizarse
                        |por un informe adicional o un procesador de datos para acciones que no están alegadas por el administrador
                        |de la infobase, y también para una circunvención no autorizada por el procesamiento adicional
                        |en el modo seguro.
                        |
                        |Utilizar este informe adicional o el procesador de datos solo si usted
                        |confía en el desarrollador, y controlar la restricción (nombre del modelo, desde el cual la conexión
                        |es un componente externo), adjuntada a los permisos emitidos.';
                        |tr = 'Uyarı! Üçüncü taraf yazılım fonlarının kullanımı, 
                        | veritabanı yöneticisi tarafından öngörülmeyen eylemler için ek bir rapor veya veri işlemcisi tarafından kullanılabilir ve ayrıca ek işlemin güvenli 
                        |modda getirdiği kısıtlamaların izinsiz olarak atlatılması için kullanılabilir. 
                        |
                        |Bu ek raporu veya veri işlemcisini, 
                        |yalnızca verilen izinlere eklenmiş geliştiriciye 
                        |ve kontrol kısıtlamasına (bağlantının harici bileşen olan
                        |şablonun adı) güveniyorsanız kullanın.';
                        |it = 'Attenzione! Il report aggiuntivo o elaboratore dati potrebbero utilizzare funzionalità di software di terze parti per eseguire azioni
                        |non previste dall''amministratore dell''infobase
                        |o per bypassare le restrizioni applicate all''elaboratore dati aggiuntivo
                        |in modalità sicura.
                        |
                        |Utilizzare questo report aggiuntivo o elaboratore dati solo in caso vi fidiate dello sviluppatore
                        |e verificare le restrizioni applicate ai permessi
                        |emessi (nome del modello fonte).';
                        |de = 'Achtung: Die Verwendung von Softwaretools von Drittanbietern kann durch
                        |zusätzliche Berichterstattung oder Verarbeitung genutzt werden, um Aktionen durchzuführen, die nicht vom Administrator
                        |der Informationsdatenbank angenommen werden, sowie zur unbefugten Umgehung von Einschränkungen der zusätzlichen Verarbeitung
                        |im abgesicherten Modus.
                        |
                        |Verwenden Sie den gegebenen zusätzlichen Bericht oder die Verarbeitung nur in diesem Fall, wenn Sie
                        |dem Entwickler vertrauen und Einschränkungen (der Name des Layouts, von dem aus die externen
                        |Komponenten verbunden wird) für die gegebenen Berechtigungen kontrollieren.'");
	
	Parameters = ParametersTable();
	AddParameter(Parameters, "TemplateName", NStr("ru = 'из макета %1'; en = 'from template %1'; pl = 'z szablonu %1';es_ES = 'desde el modelo %1';es_CO = 'desde el modelo %1';tr = '%1 şablonundan';it = 'dal layout %1';de = 'von Vorlage %1'"), NStr("ru = 'из любого макета'; en = 'from any template'; pl = 'z dowolnego szablonu';es_ES = 'desde cualquier modelo';es_CO = 'desde cualquier modelo';tr = 'herhangi bir şablondan';it = 'da qualsiasi layout';de = 'von jeder Vorlage'"));
	
	Value = New Structure;
	Value.Insert("Presentation", Presentation);
	Value.Insert("Details", Details);
	Value.Insert("Consequences", Consequences);
	Value.Insert("Parameters", Parameters);
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsSafeModeInterface.AddInAttachmentType(),
		Value);
	
	// End {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}AttachAddin
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}GetFileFromExternalSoftware
	
	Presentation = NStr("ru = 'Получение файлов из внешнего объекта'; en = 'Receive files from external objects'; pl = 'Pobieranie plików od obiektu zewnętrznego';es_ES = 'Recibir archivos del objeto externo';es_CO = 'Recibir archivos del objeto externo';tr = 'Dosyaları harici nesneden al';it = 'Ricevi file da oggetti esterni';de = 'Empfangen von Dateien von einem externen Objekt'");
	Details = NStr("ru = 'Дополнительному отчету или обработке будет разрешено получать файлы из внешнего программного обеспечения (например, с помощью COM-соединения или внешней компоненты)'; en = 'Additional report or data processor is allowed to receive files from third-party software (for example, using a COM connection or an add-in).'; pl = 'Dodatkowe sprawozdanie lub przetwarzanie danych będzie mogło odbierać pliki z zewnętrznego oprogramowania (na przykład przy użyciu połączenia COM lub komponentu zewnętrznego)';es_ES = 'Se permitirá al informe adicional o el procesador de datos recibir archivos del software externo (por ejemplo, utilizando la conexión COM o un componente externo)';es_CO = 'Se permitirá al informe adicional o el procesador de datos recibir archivos del software externo (por ejemplo, utilizando la conexión COM o un componente externo)';tr = 'Ek rapor veya veri işlemcisinin harici yazılımdan dosya almasına izin verilir (örneğin, COM bağlantısı veya harici bileşen kullanılarak)';it = 'Il report o elaboratore dati aggiuntivo sono abilitati a ricevere file da software di terze parti (ad esempio utilizzando una connessione COM o componente aggiuntivo).';de = 'Zusätzlicher Bericht oder Datenprozessor darf Dateien von externer Software empfangen (z. B. über COM-Verbindung oder externe Komponente)'");
	
	Value = New Structure;
	Value.Insert("Presentation", Presentation);
	Value.Insert("Details", Details);
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsSafeModeInterface.FileReceivingFromExternalObjectType(),
		Value);
	
	// End {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}GetFileFromExternalSoftware
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}SendFileToExternalSoftware
	
	Presentation = NStr("ru = 'Передача файлов во внешний объект'; en = 'Send files to external objects'; pl = 'Przesyłanie plików do obiektu zewnętrznego';es_ES = 'Traslado de archivos al objeto externo';es_CO = 'Traslado de archivos al objeto externo';tr = 'Harici nesneye dosya aktarımı';it = 'Inviare file a oggetti esterni';de = 'Dateiübertragung an das externe Objekt'");
	Details = NStr("ru = 'Дополнительному отчету или обработке будет разрешено передавать файлы во внешнее программное обеспечение (например, с помощью COM-соединения или внешней компоненты)'; en = 'Additional report or data processor is allowed to send files to third-party software (for example, using a COM connection or an add-in).'; pl = 'Dodatkowe sprawozdanie lub przetwarzanie danych będzie mogło przesyłać pliki do zewnętrznego oprogramowania (na przykład za pomocą połączenia COM lub komponentu zewnętrznego)';es_ES = 'Se permitirá al informe adicional o el procesador de datos trasladar archivos al software externo (por ejemplo, utilizando la conexión COM o un componente externo)';es_CO = 'Se permitirá al informe adicional o el procesador de datos trasladar archivos al software externo (por ejemplo, utilizando la conexión COM o un componente externo)';tr = 'Ek rapor veya veri işlemcisinin dosyaları harici yazılıma aktarmasına izin verilir (örneğin, COM bağlantısı veya harici bileşen kullanılarak).';it = 'Il report o elaboratore dati aggiuntivo sono abilitati a inviare file a software di terze parti (ad esempio utilizzando una connessione COM o componente aggiuntivo).';de = 'Zusätzlicher Bericht oder Datenprozessor darf Dateien an externe Software übertragen (z. B. über COM-Verbindung oder externe Komponente)'");
	
	Value = New Structure;
	Value.Insert("Presentation", Presentation);
	Value.Insert("Details", Details);
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsSafeModeInterface.TypeTransferFileToExternalObject(),
		Value);
	
	// End {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}SendFileToExternalSoftware
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}SendFileToInternet
	
	Presentation = NStr("ru = 'Провести документы'; en = 'Post documents'; pl = 'Zaksięgowania dokumentów';es_ES = 'Envío de documentos';es_CO = 'Envío de documentos';tr = 'Belgeleri kaydet';it = 'Pubblica documenti';de = 'Dokumente buchen'");
	Details = NStr("ru = 'Дополнительному отчету или обработке будет разрешено изменять состояние проведенности документов'; en = 'Additional report or data processor is allowed to post documents or clear posting.'; pl = 'Dodatkowy raport lub procesor danych ma zezwolenie do zatwierdzenia dokumentów lub zmieniać zatwierdzenie.';es_ES = 'Se permitirá al informe adicional o el procesador de datos cambiar el estado de envío de documentos';es_CO = 'Se permitirá al informe adicional o el procesador de datos cambiar el estado de envío de documentos';tr = 'Ek rapor veya veri işlemcinin belgelerin gönderim durumunu değiştirmesine izin verilecektir';it = 'Report o elaboratore dati aggiuntivo abilitati a pubblicare documenti o annullare la pubblicazione.';de = 'Ein zusätzlicher Bericht oder Datenverarbeiter darf Belege buchen oder die Buchung ausgleichen.'");
	
	Parameters = ParametersTable();
	AddParameter(Parameters, "DocumentType", NStr("ru = 'документы с типом %1'; en = 'documents with type %1'; pl = 'dokumenty z typem %1';es_ES = 'documentos con el tipo %1';es_CO = 'documentos con el tipo %1';tr = '%1 tür belgeler';it = 'Documenti con tipo %1';de = 'Dokumente mit Typ %1'"), NStr("ru = 'любые документы'; en = 'any documents'; pl = 'wszelkie dokumenty';es_ES = 'cualquier documento';es_CO = 'cualquier documento';tr = 'herhangi belgeler';it = 'tutti i documenti';de = 'irgendwelche Dokumente'"));
	AddParameter(Parameters, "Action", NStr("ru = 'разрешенное действие: %1'; en = 'allowed action: %1'; pl = 'dozwolone czynności: %1';es_ES = 'acción permitida: %1';es_CO = 'acción permitida: %1';tr = 'izin verilen eylem: %1';it = 'azione consentita: %1';de = 'zulässige Aktion: %1'"), NStr("ru = 'любое изменение состояния проведения'; en = 'both post and clear posting'; pl = 'dowolne zmiany statusu dekretowania';es_ES = 'cualquier cambio del estado de envío';es_CO = 'cualquier cambio del estado de envío';tr = 'herhangi bir gönderi durumu değişikliği';it = 'Sia pubblica che cancella pubblicazioni';de = 'sowohl Buchung als auch Buchung ausgleichen'"));
	
	Value = New Structure;
	Value.Insert("Presentation", Presentation);
	Value.Insert("Details", Details);
	Value.Insert("Parameters", Parameters);
	Value.Insert("DisplayToUser", Undefined);
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsSafeModeInterface.DocumentPostingType(),
		Value);
	
	// End {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}SendFileToInternet
	
	Return Result;
	
EndFunction

#EndRegion

#EndRegion

#Region Private

Procedure AddParameter(Val ParametersTable, Val Name, Val Details, Val AnyValueDetails)
	
	Parameter = ParametersTable.Add();
	Parameter.Name = Name;
	Parameter.Details = Details;
	Parameter.AnyValueDetails = AnyValueDetails;
	
EndProcedure

Function ParametersTable()
	
	Result = New ValueTable();
	Result.Columns.Add("Name", New TypeDescription("String"));
	Result.Columns.Add("Details", New TypeDescription("String"));
	Result.Columns.Add("AnyValueDetails", New TypeDescription("String"));
	
	Return Result;
	
EndFunction

#EndRegion
