#Region Private

// Sends a text message via SMS.RU.
//
// Parameters:
//  RecipientsNumbers - Array - recipient numbers in format +7ХХХХХХХХХХ.
//  Text			  - String - a message text with length not more than 480 characters.
//  SenderName 	 - String - a sender name that will be displayed instead of a number of incoming text message.
//  Username			 - String - a username in the text message sending service.
//  Password			 - String - a password in the text message sending service.
//
// Returns:
//  Structure: SentMessages - an array of structures: RecipientNumber.
//                                                  MessageID.
//             ErrorDescription - String - a user presentation of an error. If the string is empty, 
//                                          there is no error.
Function SendSMSMessage(RecipientsNumbers, Text, SenderName, Username, Password) Export
	
	Result = New Structure("SentMessages,ErrorDescription", New Array, "");
	
	// Prepare a string of recipients.
	RecipientsString = RecipientsArrayAsString(RecipientsNumbers);
	
	// Check whether required parameters are filled in.
	If IsBlankString(RecipientsString) Or IsBlankString(Text) Then
		Result.ErrorDescription = NStr("ru = 'Неверные параметры сообщения'; en = 'Invalid message parameters'; pl = 'Błędne parametry komunikatu';es_ES = 'Parámetros incorrectos del mensaje';es_CO = 'Parámetros incorrectos del mensaje';tr = 'Mesaj parametreleri yanlış';it = 'Parametri messaggio non validi';de = 'Falsche Nachrichtenparameter'");
		Return Result;
	EndIf;
	
	// Prepare query options.
	QueryOptions = New Structure;
	QueryOptions.Insert("login", Username);
	QueryOptions.Insert("password", Password);
	QueryOptions.Insert("text", Text);
	QueryOptions.Insert("to", RecipientsString);
	QueryOptions.Insert("from", SenderName);
	
	// Send the query
	ResponseText = ExecuteQuery("sms/send", QueryOptions);
	If Not ValueIsFilled(ResponseText) Then
		Result.ErrorDescription = Result.ErrorDescription + NStr("ru = 'Соединение не установлено'; en = 'Connection failed'; pl = 'Połączenie nie jest ustawione';es_ES = 'Conexión no establecida';es_CO = 'Conexión no establecida';tr = 'Bağlantı kurulamadı';it = 'Connessione fallita';de = 'Verbindung nicht hergestellt'");
		Return Result;
	EndIf;
	
	MessagesIDs = StrSplit(ResponseText, Chars.LF);
	
	ServerResponse = MessagesIDs[0];
	MessagesIDs.Delete(0);
	
	If ServerResponse = "100" Then
		RecipientsNumbers = StrSplit(RecipientsString, ",", False);
		If MessagesIDs.Count() < RecipientsNumbers.Count() Then
			Result.ErrorDescription = NStr("ru = 'Не удалось разобрать ответ сервера'; en = 'Couldn''t parse the server response'; pl = 'Nie udało się przeanalizować odpowiedzi serwera';es_ES = 'No se ha podido analizar la respuesta del servidor';es_CO = 'No se ha podido analizar la respuesta del servidor';tr = 'Sunucu yanıtı ayrıştırılamadı';it = 'Impossibile analizzare la risposta del server';de = 'Fehler beim Analysieren der Server-Antwort'");
			Return Result;
		EndIf;
		
		For Index = 0 To RecipientsNumbers.UBound() Do
			RecipientNumber = RecipientsNumbers[Index];
			MessageID = MessagesIDs[Index];
			If Not IsBlankString(RecipientNumber) Then
				SentMessage = New Structure("RecipientNumber,MessageID",
					RecipientNumber,MessageID);
				Result.SentMessages.Add(SentMessage);
			EndIf;
		EndDo;
	Else
		Result.ErrorDescription = SendingErrorDescription(ServerResponse);
		WriteLogEvent(NStr("ru = 'Отправка SMS'; en = 'Text messaging'; pl = 'Wysyłanie wiadomości SMS';es_ES = 'SMS';es_CO = 'SMS';tr = 'SMS Mesajlaması';it = 'Messaggistica di testo';de = 'Senden von Textnachrichten'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, , , Result.ErrorDescription);
	EndIf;
	
	Return Result;
	
EndFunction

// This function returns a text presentation of message delivery status.
//
// Parameters:
//  MessageID - String - ID assigned to a text message upon sending.
//  SMSMessageSendingSettings - Structure - see SMSMessageSendingCached.SMSMessageSendingSettings. 
//
// Returns:
//  String - a delivery status. See details of the SMSMessageSending.DeliveryStatus function.
Function DeliveryStatus(MessageID, SMSMessageSendingSettings) Export
	
	Username = SMSMessageSendingSettings.Username;
	Password = SMSMessageSendingSettings.Password;
	
	// Prepare query options.
	QueryOptions = New Structure;
	QueryOptions.Insert("login", Username);
	QueryOptions.Insert("password", Password);
	QueryOptions.Insert("id", MessageID);
	
	// Send the query
	StatusCode = ExecuteQuery("sms/status", QueryOptions);
	If Not ValueIsFilled(StatusCode) Then
		Return "Error";
	EndIf;
	
	Result = SMSMessageDeliveryStatus(StatusCode);
	If Result = "Error" Then
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(NStr(
			"ru = 'Не удалось получить статус доставки SMS-сообщения с идентификатором %3. Код ошибки %2.
			|Подробнее: %1'; 
			|en = 'Getting delivery status for SMS message with ID %3 failed with error code %2.
			|Details: %1'; 
			|pl = 'Nie udało się odebrać statusu dostarczenia SMS z identyfikatorem %3. Kod błędu %2.
			|Szczegóły: %1';
			|es_ES = 'Ha ocurrido un error al obtener el estado de entrega para un mensaje SMS con el identificador %3 con el código de error %2.
			|Detalles: %1';
			|es_CO = 'Ha ocurrido un error al obtener el estado de entrega para un mensaje SMS con el identificador %3 con el código de error %2.
			|Detalles: %1';
			|tr = '%3 kodlu SMS için teslimat durumu alımı %2 hata koduyla başarısız oldu.
			|Ayrıntılar: %1';
			|it = 'Ricezione fallita dello stato di consegna per il messaggio SMS con ID %3 con codice errore %2.
			|Dettagli: %1';
			|de = 'Empfangen con Zustellungsstatus für Textnachricht mit ID %3 fehlgeschlagen mit Fehlercode %2. 
			|Details: %1'"), StatusGettingErrorDescription(StatusCode), StatusCode, MessageID);
		WriteLogEvent(NStr("ru = 'Отправка SMS'; en = 'Text messaging'; pl = 'Wysyłanie wiadomości SMS';es_ES = 'SMS';es_CO = 'SMS';tr = 'SMS Mesajlaması';it = 'Messaggistica di testo';de = 'Senden von Textnachrichten'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, , , ErrorDescription);
	EndIf;
	
	Return Result;
	
EndFunction

Function SMSMessageDeliveryStatus(StatusCode)
	StatusesMap = New Map;
	StatusesMap.Insert("-1", "Pending");
	StatusesMap.Insert("100", "Pending");
	StatusesMap.Insert("101", "Sending");
	StatusesMap.Insert("102", "Sent");
	StatusesMap.Insert("103", "Delivered");
	StatusesMap.Insert("104", "NotDelivered");
	StatusesMap.Insert("105", "NotDelivered");
	StatusesMap.Insert("106", "NotDelivered");
	StatusesMap.Insert("107", "NotDelivered");
	StatusesMap.Insert("108", "NotDelivered");
	
	Result = StatusesMap[Lower(StatusCode)];
	Return ?(Result = Undefined, "Error", Result);
EndFunction

Function ErrorsDetails()
	ErrorsDetails = New Map;
	ErrorsDetails.Insert("200", NStr("ru = 'Ошибка авторизации: Неверный api_id.'; en = 'Authorization failed: Invalid api_id.'; pl = 'Błąd uwierzytelnienia: Niepoprawny api_id.';es_ES = 'La autorización ha fallado: Api_id inválido.';es_CO = 'La autorización ha fallado: Api_id inválido.';tr = 'Kimlik doğrulama başarısız: Geçersiz api_id.';it = 'Autorizzazione non riuscita: api_id non valido.';de = 'Autorisierung fehlgeschlagen: Ungültige api_id.'"));
	ErrorsDetails.Insert("201", NStr("ru = 'Недостаточно средств.'; en = 'Insufficient funds.'; pl = 'Niewystarczające środki.';es_ES = 'Fondos insuficientes.';es_CO = 'Fondos insuficientes.';tr = 'Yetersiz bakiye.';it = 'Fondi insufficienti.';de = 'Unzureichende Mittel.'"));
	ErrorsDetails.Insert("202", NStr("ru = 'Неверный получатель.'; en = 'Invalid recipient.'; pl = 'Niepoprawny odbiorca.';es_ES = 'Destinatario incorrecto.';es_CO = 'Destinatario incorrecto.';tr = 'Geçersiz alıcı.';it = 'Destinatario non valido.';de = 'Ungültiger Empfänger.'"));
	ErrorsDetails.Insert("203", NStr("ru = 'Пустое сообщение.'; en = 'Blank text message.'; pl = 'Pusta wiadomość SMS.';es_ES = 'SMS vacío.';es_CO = 'SMS vacío.';tr = 'Boş SMS.';it = 'Messaggio di testo vuoto.';de = 'Klartextnachricht.'"));
	ErrorsDetails.Insert("204", NStr("ru = 'Имя отправителя не согласовано с провайдером (SMS.RU).'; en = 'Sender name not approved by provider (SMS.RU).'; pl = 'Nazwa nadawcy nie jest uzgodniona z operatorem (SMS.RU).';es_ES = 'Nombre del remitente no aprobado por el proveedor (SMS.RU).';es_CO = 'Nombre del remitente no aprobado por el proveedor (SMS.RU).';tr = 'Gönderenin adı, sağlayıcı tarafından (SMS.RU) onaylanmadı.';it = 'Nome mittente non approvato dal provider (SMS.RU).';de = 'Der Name des Absenders ist nicht mit dem Anbieter abgestimmt (SMS.RU).'"));
	ErrorsDetails.Insert("205", NStr("ru = 'Сообщение превышает лимит в 8 SMS-сообщений.'; en = 'Message exceeds the limit of 8 SMS messages.'; pl = 'Wiadomość przekracza limit 8 wiadomości SMS.';es_ES = 'El mensaje supera el límite de 8 mensajes SMS.';es_CO = 'El mensaje supera el límite de 8 mensajes SMS.';tr = 'Mesaj, 8 SMS limitini aşıyor.';it = 'Il messaggio eccede il limite di 8 messaggi SMS.';de = 'Nachricht überschreitend die Grenze von 8 SMS-Nachrichten.'"));
	ErrorsDetails.Insert("206", NStr("ru = 'Достигнут дневной лимит исходящих сообщений.'; en = 'Daily outbound message limit reached.'; pl = 'Osiągnięto limit wychodzących wiadomości SMS.';es_ES = 'Se ha alcanzado el límite diario de mensajes salientes.';es_CO = 'Se ha alcanzado el límite diario de mensajes salientes.';tr = 'Giden mesajlar için günlük limite ulaşıldı.';it = 'Limite giornaliero di messaggi in uscita raggiunto.';de = 'Tägliches Limit von ausgehenden Nachrichten erreicht.'"));
	ErrorsDetails.Insert("207", NStr("ru = 'Не удалось отправить сообщения на один из телефонных номеров, или превышен лимит в 100 получателей.'; en = 'Cannot send messages to one of the phone numbers, or 100 recipient limit is exceeded.'; pl = 'Nie można wysłać wiadomości SMS na jeden z numerów telefonicznych, lub przekroczono limit 100 odbiorców.';es_ES = 'Ha ocurrido un error al enviar mensajes a uno de los números de teléfono, o se ha superado el límite de 100 destinatarios.';es_CO = 'Ha ocurrido un error al enviar mensajes a uno de los números de teléfono, o se ha superado el límite de 100 destinatarios.';tr = 'Telefon numaralarından birine mesaj gönderilemiyor ya da 100 alıcı limiti aşıldı.';it = 'Impossibile inviare messaggi a uno dei numeri di telefono, oppure il limite di 100 destinatari è stato superato.';de = 'Fehler beim Senden Nachrichten an eine der Telefonnummern, oder 100 Empfängergrenze ist überschritten.'"));
	ErrorsDetails.Insert("208", NStr("ru = 'Неверный параметр ""Время"".'; en = 'Invalid ""time"" parameter.'; pl = 'Błędny pierwszy parametr ""czas"".';es_ES = 'Parámetro ""tiempo"" incorrecto.';es_CO = 'Parámetro ""tiempo"" incorrecto.';tr = 'Geçersiz ""zaman"" parametresi.';it = 'Parametro ""tempo"" non valido.';de = 'Ungültiger ""Zeit""-Parameter.'"));
	ErrorsDetails.Insert("209", NStr("ru = 'Получатель находится в стоп-листе. Проверьте стоп-лист в своей учетной записи на веб-сайте провайдера.'; en = 'A recipient is on a stop list. Consider stop list in your account on the provider website.'; pl = 'Odbiorca jest na stop liście w twoim koncie na stronie operatora.';es_ES = 'Un destinatario se encuentra en una lista de detención. Considere la lista de detención en su cuenta en el sitio web del proveedor.';es_CO = 'Un destinatario se encuentra en una lista de detención. Considere la lista de detención en su cuenta en el sitio web del proveedor.';tr = 'Alıcılardan biri kara listede. Sağlayıcının web sitesindeki hesabınızda kara listeyi gözden geçirin.';it = 'Un destinatario è nell''elenco dei bloccati. Valutare l''utilizzo di elenchi di bloccati nel proprio account sul sito web del provider.';de = 'Ein Empfänger ist in der Stoppliste. Überprüfen Sie die Stoppliste in Ihrem Account auf der Website des Anbieters.'"));
	ErrorsDetails.Insert("210", NStr("ru = 'Используется GET, где необходимо использовать POST.'; en = 'GET is used where POST is required.'; pl = 'Wykorzystywana GET, gdzie należy stosować POST.';es_ES = 'Se usa GET donde hay que usar POST.';es_CO = 'Se usa GET donde hay que usar POST.';tr = 'POST kullanılması gereken yerde GET kullanılıyor.';it = 'GET è usato dove POST è richiesto';de = 'Es wird von GET verwendet, wo es notwendig ist, POST zu verwenden.'"));
	ErrorsDetails.Insert("211", NStr("ru = 'Метод не найден.'; en = 'Method not found.'; pl = 'Nie znaleziono metody.';es_ES = 'Método no encontrado.';es_CO = 'Método no encontrado.';tr = 'Yöntem bulunamadı.';it = 'Metodo non trovato.';de = 'Methode nicht gefunden.'"));
	ErrorsDetails.Insert("212", NStr("ru = 'Недопустимая кодировка текста сообщения; требуется UTF-8.'; en = 'Invalid message text encoding; UTF-8 required.'; pl = 'Niedopuszczalne kodowanie tekstu wiadomości SMS; wymaga się UTF-8.';es_ES = 'La codificación del SMS no es válida; se requiere UTF-8.';es_CO = 'La codificación del SMS no es válida; se requiere UTF-8.';tr = 'Geçersiz mesaj metni şifrelemesi; UTF-8 gerekli.';it = 'Codificazione testo del messaggio non valida; è richiesta UTF-8.';de = 'Ungültige Nachrichtentextverschlüsselung; UTF-8 benötigt.'"));
	ErrorsDetails.Insert("220", NStr("ru = 'Сервис временно недоступен.'; en = 'Service temporarily unavailable.'; pl = 'Serwis tymczasowo jest niedostępny.';es_ES = 'El servicio está temporalmente indisponible.';es_CO = 'El servicio está temporalmente indisponible.';tr = 'Servis geçici olarak hizmet dışı.';it = 'Servizio momentaneamente non disponibile.';de = 'Der Service ist vorübergehend nicht verfügbar.'"));
	ErrorsDetails.Insert("230", NStr("ru = 'Достигнут ежедневный лимит в 60 сообщений для одного получателя.'; en = 'Daily limit of 60 messages to single recipient reached.'; pl = 'Osiągnięto dzienny limit 60 wiadomości SMS dla jednego odbiorcy.';es_ES = 'Se ha alcanzado el límite diario de 60 mensajes a un solo destinatario.';es_CO = 'Se ha alcanzado el límite diario de 60 mensajes a un solo destinatario.';tr = 'Tek kullanıcıya günlük 60 mesaj limitine ulaşıldı.';it = 'Raggiunto il limite giornaliero di 60 messaggi per singolo destinatario.';de = 'Tageslimit von 60 Nachrichten an einen Empfänger erreicht.'"));
	ErrorsDetails.Insert("300", NStr("ru = 'Ошибка авторизации: Истек срок действия токена или изменился IP-адрес отправителя.'; en = 'Authorization failed: Token expired or sender IP address changed.'; pl = 'Błąd uwierzytelnienia: Token jest przestarzały lub został zmieniony adres IP nadawcy.';es_ES = 'La autorización ha fallado: El token ha caducado o la dirección IP del remitente ha cambiado.';es_CO = 'La autorización ha fallado: El token ha caducado o la dirección IP del remitente ha cambiado.';tr = 'Kimlik doğrulama hatası: Belirtecin süresi doldu veya gönderenin IP adresi değişti.';it = 'Autorizzazione non riuscita: Il Token è scaduto o l''indirizzo IP del mittente è stato modificato.';de = 'Autorisierung fehlgeschlagen: Token ist veraltet oder die IP-Adresse des Absenders hat sich geändert.'"));
	ErrorsDetails.Insert("301", NStr("ru = 'Ошибка авторизации: неверные учетные данные.'; en = 'Authorization failed: Invalid credentials.'; pl = 'Błąd uwierzytelnienia: Niepoprawne dane.';es_ES = 'La autorización ha fallado: Credenciales no válidas.';es_CO = 'La autorización ha fallado: Credenciales no válidas.';tr = 'Kimlik doğrulama başarısız: Geçersiz kimlik bilgisi.';it = 'Autorizzazione non riuscita: credenziali non valide.';de = 'Autorisierung fehlgeschlagen: Ungültige Zugangsdaten.'"));
	ErrorsDetails.Insert("302", NStr("ru = 'Ошибка авторизации: учетная запись пользователя не подтверждена.'; en = 'Authorization failed: User account not confirmed.'; pl = 'Błąd uwierzytelnienia: Konto użytkownika nie jest potwierdzone.';es_ES = 'La autorización ha fallado: Cuenta de usuario no confirmada.';es_CO = 'La autorización ha fallado: Cuenta de usuario no confirmada.';tr = 'Kimlik doğrulama başarısız: Kullanıcı hesabı doğrulanmadı.';it = 'Autorizzazione non riuscita: Account utente non confermato.';de = 'Autorisierung fehlgeschlagen: Benutzer-Account nicht bestätigt.'"));
	
	Return ErrorsDetails;
EndFunction

Function SendingErrorDescription(ErrorCode)
	ErrorsDetails = ErrorsDetails();
	MessageText = ErrorsDetails[ErrorCode];
	If MessageText = Undefined Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось отправить сообщение. Код ошибки %1.'; en = 'Sending message failed with error code %1.'; pl = 'Nie udało się wysłać wiadomości. Kod błędu %1.';es_ES = 'El envío del mensaje ha fallado con el código de error %1.';es_CO = 'El envío del mensaje ha fallado con el código de error %1.';tr = 'Mesaj gönderimi %1 hata koduyla başarısız oldu.';it = 'Invio messaggio non riuscito con codice errore %1.';de = 'Senden einer Nachricht fehlgeschlagen mit Fehlercode %1.'"), ErrorCode);
	EndIf;
	Return MessageText;
EndFunction

Function StatusGettingErrorDescription(ErrorCode)
	ErrorsDetails =ErrorsDetails();
	MessageText = ErrorsDetails[ErrorCode];
	If MessageText = Undefined Then
		MessageText = NStr("ru = 'Операция не выполнена'; en = 'Operation failed'; pl = 'Operacja nie jest wykonana';es_ES = 'Operación no realizada';es_CO = 'Operación no realizada';tr = 'İşlem yapılamadı';it = 'Operazione non riuscita';de = 'Operation fehlgeschlagen'");
	EndIf;
	Return MessageText;
EndFunction

Function ExecuteQuery(MethodName, QueryOptions)
	
	HTTPRequest = SMS.PrepareHTTPRequest("/" + MethodName, QueryOptions);
	HTTPResponse = Undefined;
	
	Try
		Connection = New HTTPConnection("sms.ru", , , , GetFilesFromInternetClientServer.GetProxy("https"),
			60, CommonClientServer.NewSecureConnection());
			
		HTTPResponse = Connection.Post(HTTPRequest);
	Except
		WriteLogEvent(NStr("ru = 'Отправка SMS'; en = 'Text messaging'; pl = 'Wysyłanie wiadomości SMS';es_ES = 'SMS';es_CO = 'SMS';tr = 'SMS Mesajlaması';it = 'Messaggistica di testo';de = 'Senden von Textnachrichten'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	If HTTPResponse <> Undefined Then
		Return HTTPResponse.GetBodyAsString();
	EndIf;
	
	Return Undefined;
	
EndFunction

Function RecipientsArrayAsString(Array)
	Recipients = New Array;
	CommonClientServer.SupplementArray(Recipients, Array, True);
	
	Result = "";
	For Each Recipient In Recipients Do
		Number = FormatNumber(Recipient);
		If NOT IsBlankString(Number) Then 
			If Not IsBlankString(Result) Then
				Result = Result + ",";
			EndIf;
			Result = Result + Number;
		EndIf;
	EndDo;
	Return Result;
EndFunction

Function FormatNumber(Number)
	Result = "";
	AllowedChars = "+1234567890";
	For Position = 1 To StrLen(Number) Do
		Char = Mid(Number,Position,1);
		If StrFind(AllowedChars, Char) > 0 Then
			Result = Result + Char;
		EndIf;
	EndDo;
	Return Result;	
EndFunction

// This function returns the list of permissions for sending text messages using all available providers.
//
// Returns:
//  Array.
//
Function Permissions() Export
	
	Protocol = "HTTP";
	Address = "sms.ru";
	Port = Undefined;
	Details = NStr("ru = 'Отправка SMS через SMS.RU.'; en = 'Text messaging via SMS.RU.'; pl = 'Wysyłanie wiadomości SMS poprzez SMS.RU.';es_ES = 'SMS a través de SMS.RU.';es_CO = 'SMS a través de SMS.RU.';tr = 'SMS.RU ile mesajlaşma.';it = 'Messaggistica di testo tramite SMS.RU.';de = 'Senden von Textnachrichten über SMS.RU.'");
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	Permissions = New Array;
	Permissions.Add(
		ModuleSafeModeManager.PermissionToUseInternetResource(Protocol, Address, Port, Details));
	
	Return Permissions;
EndFunction

Procedure FillServiceDetails(ServiceDetails) Export
	ServiceDetails.InternetAddress = "http://sms.ru";
EndProcedure

#EndRegion

