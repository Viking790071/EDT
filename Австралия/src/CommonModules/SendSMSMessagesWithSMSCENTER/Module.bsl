#Region Private

// Sends a text message via SMS CENTER.
//
// Parameters:
//  RecipientsNumbers - Array - recipient numbers in format +7ХХХХХХХХХХ.
//  Text - String - a message text with length not more than 480 characters.
//  SenderName - String - a sender name that will be displayed instead of a number of incoming text message.
//  Username - String - a username in the text message sending service.
//  Password - String - a password in the text message sending service.
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
	QueryOptions.Insert("psw", Password);
	
	QueryOptions.Insert("mes", Text);
	QueryOptions.Insert("phones", RecipientsString);
	QueryOptions.Insert("sender", SenderName);
	QueryOptions.Insert("fmt", 3); // Response in JSON format.
	QueryOptions.Insert("op", 1); // Display information for each number separately.
	QueryOptions.Insert("charset", "utf-8");

	// Send the query
	ResponseText = ExecuteQuery("send.php", QueryOptions);
	If Not ValueIsFilled(ResponseText) Then
		Result.ErrorDescription = Result.ErrorDescription + NStr("ru = 'Соединение не установлено'; en = 'Connection failed'; pl = 'Połączenie nie jest ustawione';es_ES = 'Conexión no establecida';es_CO = 'Conexión no establecida';tr = 'Bağlantı kurulamadı';it = 'Connessione fallita';de = 'Verbindung nicht hergestellt'");
		Return Result;
	EndIf;
	
	JSONReader = New JSONReader;
	JSONReader.SetString(ResponseText);
	ServerResponse = ReadJSON(JSONReader);
	JSONReader.Close();
	
	If ServerResponse.Property("error") Then
		Result.ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(NStr(
			"ru = 'Не удалось отправить сообщение. Код ошибки %2.
			|Подробнее: %1'; 
			|en = 'Message sending failed with error code %2.
			|Details: %1'; 
			|pl = 'Nie udało się wysłać wiadomości. Kod błędu %2.
			|Szczegóły: %1';
			|es_ES = 'Ha ocurrido un error al enviar el mensaje con el código de error %2.
			|Detalles: %1';
			|es_CO = 'Ha ocurrido un error al enviar el mensaje con el código de error %2.
			|Detalles: %1';
			|tr = 'Mesaj gönderimi %2 hata koduyla başarısız oldu.
			|Ayrıntılar: %1';
			|it = 'Invio messaggio non riuscito con codice errore %2.
			|Dettagli: %1';
			|de = 'Senden einer Nachricht fehlgeschlagen mit Fehlercode %2.
			|Details: %1'"), SendingErrorDescription(ServerResponse["error_code"]), ServerResponse["error_code"]);
			
		WriteLogEvent(NStr("ru = 'Отправка SMS'; en = 'Text messaging'; pl = 'Wysyłanie wiadomości SMS';es_ES = 'SMS';es_CO = 'SMS';tr = 'SMS Mesajlaması';it = 'Messaggistica di testo';de = 'Senden von Textnachrichten'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, , , Result.ErrorDescription);
	Else
		MessageID = ServerResponse["id"];
		For Each SendingInfo In ServerResponse["phones"] Do
			RecipientNumber = FormatNumber(SendingInfo["phone"]);
			If SendingInfo.Property("status") AND ValueIsFilled(SendingInfo["status"]) Then
				Continue;
			EndIf;
			SentMessage = New Structure("RecipientNumber,MessageID", RecipientNumber,
				"" + RecipientNumber + "/" + Format(MessageID, "NG=0"));
			Result.SentMessages.Add(SentMessage);
		EndDo;
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
	
	IDParts = StrSplit(MessageID, "/", True);
	
	// Prepare query options.
	QueryOptions = New Structure;
	QueryOptions.Insert("login", Username);
	QueryOptions.Insert("psw", Password);
	QueryOptions.Insert("phone", IDParts[0]);
	QueryOptions.Insert("id", Number(IDParts[1]));
	QueryOptions.Insert("fmt", 3);
	
	// Send the query
	ResponseText = ExecuteQuery("status.php", QueryOptions);
	If Not ValueIsFilled(ResponseText) Then
		Return "Error";
	EndIf;
	
	JSONReader = New JSONReader;
	JSONReader.SetString(ResponseText);
	ServerResponse = ReadJSON(JSONReader);
	JSONReader.Close();
	
	If ServerResponse.Property("error") Then
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
			|Details: %1'"), StatusGettingErrorDescription(ServerResponse["error_code"]), ServerResponse["error_code"], MessageID);
		WriteLogEvent(NStr("ru = 'Отправка SMS'; en = 'Text messaging'; pl = 'Wysyłanie wiadomości SMS';es_ES = 'SMS';es_CO = 'SMS';tr = 'SMS Mesajlaması';it = 'Messaggistica di testo';de = 'Senden von Textnachrichten'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, , , ErrorDescription);
		Return "Error";
	EndIf;
	
	Return SMSMessageDeliveryStatus(ServerResponse["status"]);
	
EndFunction

Function SMSMessageDeliveryStatus(StatusCode)
	StatusesMap = New Map;
	StatusesMap.Insert(-3, "Pending");
	StatusesMap.Insert(-1, "Sending");
	StatusesMap.Insert(0, "Sent");
	StatusesMap.Insert(1, "Delivered");
	StatusesMap.Insert(3, "NotDelivered");
	StatusesMap.Insert(20, "NotDelivered");
	StatusesMap.Insert(22, "NotSent");
	StatusesMap.Insert(23, "NotSent");
	StatusesMap.Insert(24, "NotSent");
	StatusesMap.Insert(25, "NotSent");
	
	Result = StatusesMap[StatusCode];
	Return ?(Result = Undefined, "Error", Result);
EndFunction

Function SendingErrorDescription(ErrorCode)
	ErrorsDetails = New Map;
	ErrorsDetails.Insert(1, NStr("ru = 'Неверные параметры.'; en = 'Invalid parameters.'; pl = 'Niepoprawne parametry.';es_ES = 'Parámetros incorrectos.';es_CO = 'Parámetros incorrectos.';tr = 'Geçersiz parametreler.';it = 'Parametri non validi.';de = 'Ungültige Parameter.'"));
	ErrorsDetails.Insert(2, NStr("ru = 'Неверные учетные данные.'; en = 'Invalid credentials.'; pl = 'Niepoprawne dane.';es_ES = 'Credenciales no válidas.';es_CO = 'Credenciales no válidas.';tr = 'Geçersiz kimlik bilgisi.';it = 'Credenziali non valide.';de = 'Ungültige Zugangsdaten.'"));
	ErrorsDetails.Insert(3, NStr("ru = 'Недостаточно средств.'; en = 'Insufficient funds.'; pl = 'Niewystarczające środki.';es_ES = 'Fondos insuficientes.';es_CO = 'Fondos insuficientes.';tr = 'Yetersiz bakiye.';it = 'Fondi insufficienti.';de = 'Unzureichende Mittel.'"));
	ErrorsDetails.Insert(4, NStr("ru = 'IP-адрес временно заблокирован из-за серии недопустимых запросов. Подробнее: http://smsc.ru/faq/99.'; en = 'IP address temporarily blocked due to series of invalid requests. For details, see http://smsc.ru/faq/99.'; pl = 'Adres IP jest czasowo zablokowany z powodu serii niedopuszczalnych zapytań. Szczegóły: http://smsc.ru/faq/99.';es_ES = 'Dirección IP bloqueada temporalmente debido a una serie de solicitudes no válidas. Para más detalles, véase http://smsc.ru/faq/99.';es_CO = 'Dirección IP bloqueada temporalmente debido a una serie de solicitudes no válidas. Para más detalles, véase http://smsc.ru/faq/99.';tr = 'Bir dizi geçersiz sorgu nedeniyle IP adresi geçici olarak engellendi. Ayrıntılar için bkz. http://smsc.ru/faq/99.';it = 'Indirizzo IP bloccato temporaneamente a causa di una serie di richieste non valide. Per i dettagli, visualizzare http://smsc.ru/faq/99.';de = 'IP-Adresse vorübergehend gesperrt wegen mehrere ungültige Abrufe. Für weitere Informationen, siehe http://smsc.ru/faq/99.'"));
	ErrorsDetails.Insert(5, NStr("ru = 'Неверный формат даты.'; en = 'Invalid date format.'; pl = 'Nieprawidłowy format daty.';es_ES = 'Formato de fecha incorrecto.';es_CO = 'Formato de fecha incorrecto.';tr = 'Geçersiz tarik formatı.';it = 'Formato data non valido.';de = 'Ungültiges Datumsformat.'"));
	ErrorsDetails.Insert(6, NStr("ru = 'Сообщение отклонено из-за ограничений получателя или содержания.'; en = 'Message rejected due to recipient or content restrictions.'; pl = 'Wiadomość została odrzucona z powodu ograniczeń odbiorcy lub zawartości.';es_ES = 'Mensaje rechazado debido a restricciones del destinatario o del contenido.';es_CO = 'Mensaje rechazado debido a restricciones del destinatario o del contenido.';tr = 'Alıcı veya içerik kısıtlamaları nedeniyle ileti reddedildi.';it = 'Messaggio rifiutato a causa di limitazioni per il destinatario o il contenuto.';de = 'Nachricht abgelehnt wegen Begrenzungen des Empfängers oder Inhalts.'"));
	ErrorsDetails.Insert(7, NStr("ru = 'Неверный формат номера телефона.'; en = 'Invalid phone number format.'; pl = 'Niepoprawny format numeru telefonu.';es_ES = 'Formato de número de teléfono inválido.';es_CO = 'Formato de número de teléfono inválido.';tr = 'Geçersiz telefon numarası formatı.';it = 'Formato numero di telefono non valido.';de = 'Ungültiges Rufnummernformat.'"));
	ErrorsDetails.Insert(8, NStr("ru = 'Не удалось доставить сообщения получателю.'; en = 'Cannot deliver messages to the recipient.'; pl = 'Nie można dostarczyć wiadomości do odbiorcy.';es_ES = 'Ha ocurrido un error al entregar los mensajes al destinatario.';es_CO = 'Ha ocurrido un error al entregar los mensajes al destinatario.';tr = 'İletiler alıcıya iletilemedi.';it = 'Impossibile inviare i messaggi al destinatario.';de = 'Fehler beim Zustellung von Nachrichten an den Empfänger.'"));
	ErrorsDetails.Insert(9, NStr("ru = 'Повторяющиеся сообщения отправлены в течение минуты.'; en = 'Duplicate messages sent within a minute.'; pl = 'Powtarzające się wiadomości zostały wysłane w ciągu minuty.';es_ES = 'Mensajes duplicados enviados en un minuto.';es_CO = 'Mensajes duplicados enviados en un minuto.';tr = 'Aynı mesaj 1 dakika içinde birden fazla kez gönderildi.';it = 'Messaggi duplicati inviati entro un minuto.';de = 'Gesendete Nachricht in einer Minute duplizieren.'"));
	
	MessageText = ErrorsDetails[ErrorCode];
	If MessageText = Undefined Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось отправить сообщение. Код ошибки %1.'; en = 'Sending message failed with error code %1.'; pl = 'Nie udało się wysłać wiadomości. Kod błędu %1.';es_ES = 'El envío del mensaje ha fallado con el código de error %1.';es_CO = 'El envío del mensaje ha fallado con el código de error %1.';tr = 'Mesaj gönderimi %1 hata koduyla başarısız oldu.';it = 'Invio messaggio non riuscito con codice errore %1.';de = 'Senden einer Nachricht fehlgeschlagen mit Fehlercode %1.'"), ErrorCode);
	EndIf;
	Return MessageText;
EndFunction

Function StatusGettingErrorDescription(ErrorCode)
	ErrorsDetails = New Map;
	ErrorsDetails.Insert(1, NStr("ru = 'Неверные параметры.'; en = 'Invalid parameters.'; pl = 'Niepoprawne parametry.';es_ES = 'Parámetros incorrectos.';es_CO = 'Parámetros incorrectos.';tr = 'Geçersiz parametreler.';it = 'Parametri non validi.';de = 'Ungültige Parameter.'"));
	ErrorsDetails.Insert(2, NStr("ru = 'Неверные учетные данные.'; en = 'Invalid credentials.'; pl = 'Niepoprawne dane.';es_ES = 'Credenciales no válidas.';es_CO = 'Credenciales no válidas.';tr = 'Geçersiz kimlik bilgisi.';it = 'Credenziali non valide.';de = 'Ungültige Zugangsdaten.'"));
	ErrorsDetails.Insert(5, NStr("ru = 'Ошибка удаления сообщения.'; en = 'Couldn't delete message.'"));
	ErrorsDetails.Insert(4, NStr("ru = 'IP-адрес временно заблокирован из-за серии недопустимых запросов. Подробнее: http://smsc.ru/faq/99.'; en = 'IP address temporarily blocked due to series of invalid requests. For details, see http://smsc.ru/faq/99.'; pl = 'Adres IP jest czasowo zablokowany z powodu serii niedopuszczalnych zapytań. Szczegóły: http://smsc.ru/faq/99.';es_ES = 'Dirección IP bloqueada temporalmente debido a una serie de solicitudes no válidas. Para más detalles, véase http://smsc.ru/faq/99.';es_CO = 'Dirección IP bloqueada temporalmente debido a una serie de solicitudes no válidas. Para más detalles, véase http://smsc.ru/faq/99.';tr = 'Bir dizi geçersiz sorgu nedeniyle IP adresi geçici olarak engellendi. Ayrıntılar için bkz. http://smsc.ru/faq/99.';it = 'Indirizzo IP bloccato temporaneamente a causa di una serie di richieste non valide. Per i dettagli, visualizzare http://smsc.ru/faq/99.';de = 'IP-Adresse vorübergehend gesperrt wegen mehrere ungültige Abrufe. Für weitere Informationen, siehe http://smsc.ru/faq/99.'"));
	ErrorsDetails.Insert(9, NStr("ru = 'Статус сообщения запрошен более 5 раз за минуту.'; en = 'Message status requested over 5 times within a minute.'; pl = 'Status wiadomości został zapytany ponad 5 razy w ciągu minuty.';es_ES = 'El estado del mensaje fue solicitado más de 5 veces en un minuto.';es_CO = 'El estado del mensaje fue solicitado más de 5 veces en un minuto.';tr = 'Mesaj durumu 1 dakika içinde 5 kereden fazla talep edildi.';it = 'Stato messaggio richiesto più di 5 volte in un minuto.';de = 'Nachrichtenstatus abgefragt mehr als 5 Male binnen einer Minute.'"));
	
	MessageText = ErrorsDetails[ErrorCode];
	If MessageText = Undefined Then
		MessageText = NStr("ru = 'Операция не выполнена'; en = 'Operation failed'; pl = 'Operacja nie jest wykonana';es_ES = 'Operación no realizada';es_CO = 'Operación no realizada';tr = 'İşlem yapılamadı';it = 'Operazione non riuscita';de = 'Operation fehlgeschlagen'");
	EndIf;
	Return MessageText;
EndFunction

Function ExecuteQuery(MethodName, QueryOptions)
	
	HTTPRequest = SMS.PrepareHTTPRequest("/sys/" + MethodName, QueryOptions);
	HTTPResponse = Undefined;
	
	Try
		Connection = New HTTPConnection("smsc.ru", , , , GetFilesFromInternetClientServer.GetProxy("https"), 
			60, CommonClientServer.NewSecureConnection());
		HTTPResponse = Connection.Post(HTTPRequest);
	Except
		WriteLogEvent(NStr("ru = 'Отправка SMS'; en = 'Text messaging'; pl = 'Wysyłanie wiadomości SMS';es_ES = 'SMS';es_CO = 'SMS';tr = 'SMS Mesajlaması';it = 'Messaggistica di testo';de = 'Senden von Textnachrichten'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Return Undefined;
	EndTry;
	
	If HTTPResponse.StatusCode <> 200 Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Ошибка запроса: %1. Код состояния: %2.'; en = 'Request failed: %1. Status code: %2.'; pl = 'Błąd zapytania: %1. Kod statusu: %2.';es_ES = 'Solicitud fallida: %1. Código del estado: %2.';es_CO = 'Solicitud fallida: %1. Código del estado: %2.';tr = 'Sorgu başarısız: %1. Durum kodu: %2.';it = 'Richiesta non riuscita: %1. Codice stato: %2.';de = 'Abfrage fehlgeschlagen: %1. Statuscode: %2.'"), MethodName, HTTPResponse.StatusCode) + Chars.LF
			+ HTTPResponse.GetBodyAsString();
		WriteLogEvent(NStr("ru = 'Отправка SMS'; en = 'Text messaging'; pl = 'Wysyłanie wiadomości SMS';es_ES = 'SMS';es_CO = 'SMS';tr = 'SMS Mesajlaması';it = 'Messaggistica di testo';de = 'Senden von Textnachrichten'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, , , ErrorText);
		Return Undefined;
	EndIf;
	
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
	
	If StrLen(Result) > 10 Then
		FirstChar = Left(Result, 1);
		If FirstChar = "8" Then
			Result = "+7" + Mid(Result, 2);
		ElsIf FirstChar <> "+" Then
			Result = "+" + Result;
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

// This function returns the list of permissions for sending text messages using all available providers.
//
// Returns:
//  Array.
//
Function Permissions() Export
	
	Protocol = "HTTPS";
	Address = "smsc.ru";
	Port = Undefined;
	Details = NStr("ru = 'Отправка SMS через ""SMS-ЦЕНТР"".'; en = 'Send SMS via SMS CENTER.'; pl = 'Wysłanie SMS poprzez SMS-CENTR.';es_ES = 'Enviar SMS a través de ""SMS-CENTRO"".';es_CO = 'Enviar SMS a través de ""SMS-CENTRO"".';tr = 'SMS-MERKEZİ üzerinden SMS gönderimi.';it = 'Invia SMS tramite SMS CENTER.';de = 'SMS über ""SMS-ZENTRUM"" versenden.'");
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	Permissions = New Array;
	Permissions.Add(
		ModuleSafeModeManager.PermissionToUseInternetResource(Protocol, Address, Port, Details));
	
	Return Permissions;
EndFunction

Procedure FillServiceDetails(ServiceDetails) Export
	ServiceDetails.InternetAddress = "https://smsc.ru";
EndProcedure

#EndRegion

