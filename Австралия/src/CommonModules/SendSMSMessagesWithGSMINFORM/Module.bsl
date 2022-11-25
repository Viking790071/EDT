#Region Private

// Sends a text message via GSM-INFORM.
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
	QueryOptions.Insert("id", Username);
	QueryOptions.Insert("api_key", Password);
	
	QueryOptions.Insert("cmd", "send");
	QueryOptions.Insert("message", Text);
	QueryOptions.Insert("to", RecipientsString);
	QueryOptions.Insert("sender", SenderName);
	
	// Send the query
	Response = ExecuteQuery(QueryOptions);
	If Response = Undefined Then
		Result.ErrorDescription = Result.ErrorDescription + NStr("ru = 'Соединение не установлено'; en = 'Connection failed'; pl = 'Połączenie nie jest ustawione';es_ES = 'Conexión no establecida';es_CO = 'Conexión no establecida';tr = 'Bağlantı kurulamadı';it = 'Connessione fallita';de = 'Verbindung nicht hergestellt'");
		Return Result;
	EndIf;
	
	JSONReader = New JSONReader;
	JSONReader.SetString(Response);
	ServerResponse = ReadJSON(JSONReader);
	JSONReader.Close();
	
	If ServerResponse["error_no"] = 0 Then
		For Each Item In ServerResponse["items"] Do
			If Item["error_no"] = 0 Then
				SentMessage = New Structure("RecipientNumber,MessageID", Item["phone"], Format(Item["sms_id"], "NG=0"));
				Result.SentMessages.Add(SentMessage);
			Else
				ErrorCode = Item["error_no"];
				Result.ErrorDescription = Result.ErrorDescription + Item["phone"] + ": " + StatusGettingErrorDescription(ErrorCode) + Chars.LF;
			EndIf;
		EndDo;
		If Not IsBlankString(Result.ErrorDescription) Then
			Result.ErrorDescription = NStr("ru = 'Не удалось отправить SMS'; en = 'Cannot send SMS'; pl = 'Nie udało się wysłać SMS';es_ES = 'No se ha podido enviar SMS';es_CO = 'No se ha podido enviar SMS';tr = 'SMS gönderilemedi';it = 'Impossibile inviare SMS';de = 'SMS konnte nicht gesendet werden'") + ":" + TrimR(Result.ErrorDescription);
		EndIf;
	Else
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
			|Details: %1'"), SendingErrorDescription(ServerResponse["error_no"]), ServerResponse["error_no"]);
			
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
	QueryOptions.Insert("id", Username);
	QueryOptions.Insert("api_key", Password);
	QueryOptions.Insert("sms_id", MessageID);
	QueryOptions.Insert("cmd", "status");
	
	// Send the query
	Response = ExecuteQuery(QueryOptions);
	If Response = Undefined Then
		Return "Error";
	EndIf;
	
	JSONReader = New JSONReader;
	JSONReader.SetString(Response);
	ServerResponse = ReadJSON(JSONReader);
	JSONReader.Close();
	
	ErrorDescription = "";
	ErrorCode = Undefined;
	Result = "Error";
	
	If ServerResponse["error_no"] = 0 Then
		For Each Item In ServerResponse["items"] Do
			If Item.Property("error_no") Then
				ErrorCode = Item["error_no"];
				Break;
			Else
				Result = SMSMessageDeliveryStatus(Item["status_no"]);
			EndIf;
		EndDo;
	Else
		ErrorCode = ServerResponse["error_no"];
	EndIf;
	
	If ErrorCode <> Undefined Then
		ErrorDescription = StatusGettingErrorDescription(ErrorCode);
		Comment = StringFunctionsClientServer.SubstituteParametersToString(NStr(
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
			|Details: %1'"), ErrorDescription, ErrorCode, MessageID);
		WriteLogEvent(NStr("ru = 'Отправка SMS'; en = 'Text messaging'; pl = 'Wysyłanie wiadomości SMS';es_ES = 'SMS';es_CO = 'SMS';tr = 'SMS Mesajlaması';it = 'Messaggistica di testo';de = 'Senden von Textnachrichten'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, , , Comment);
	EndIf;
	
	Return Result;
	
EndFunction

Function SMSMessageDeliveryStatus(StatusCode)
	StatusesMap = New Map;
	StatusesMap.Insert("1", "Sent");
	StatusesMap.Insert("2", "Delivered");
	StatusesMap.Insert("3", "NotDelivered");
	StatusesMap.Insert("4", "Sending");
	StatusesMap.Insert("6", "NotDelivered");
	StatusesMap.Insert("7", "Pending");
	StatusesMap.Insert("8", "Sending");
	StatusesMap.Insert("9", "NotSent");
	StatusesMap.Insert("10", "Sending");
	StatusesMap.Insert("11", "Sent");
	
	Result = StatusesMap[StatusCode];
	Return ?(Result = Undefined, "Pending", Result);
EndFunction

Function ErrorsDetails()
	Result = New Map;
	Result.Insert(1, NStr("ru = 'Неверный API-ключ.'; en = 'Incorrect API key.'; pl = 'Błędny API-klucz.';es_ES = 'Clave API incorrecta.';es_CO = 'Clave API incorrecta.';tr = 'API anahtarı yanlış.';it = 'API key non corretta';de = 'Falscher API-Schlüssel.'"));
	Result.Insert(2, NStr("ru = 'Неизвестная команда.'; en = 'Unknown command.'; pl = 'Nieznane polecenie.';es_ES = 'Comando desconocido.';es_CO = 'Comando desconocido.';tr = 'Bilinmeyen komut.';it = 'Comando sconosciuto.';de = 'Unbekannter Befehl.'"));
	Result.Insert(3, NStr("ru = 'Пользователь с указанным ID кабинета не найден.'; en = 'User with the specified account ID is not found.'; pl = 'Użytkownik ze wskazanym ID konta nie jest znaleziony.';es_ES = 'El usuario con ID indicado no se ha encontrado.';es_CO = 'El usuario con ID indicado no se ha encontrado.';tr = 'Belirtilen hesap kimliğine sahip kullanıcı bulunamadı.';it = 'L''utente con lD specificato non è stato trovato.';de = 'Der Benutzer mit der angegebenen Konto-ID wurde nicht gefunden.'"));
	Result.Insert(4, NStr("ru = 'Пустой список телефонов для отправки сообщений.'; en = 'Empty list of phone numbers to send messages.'; pl = 'Pusta lista telefonów do wysłania komunikatów.';es_ES = 'Lista vacía de teléfonos para enviar los mensajes.';es_CO = 'Lista vacía de teléfonos para enviar los mensajes.';tr = 'Mesaj göndermek için boş telefon listesi.';it = 'L''elenco di numeri di telefono per inviare i messaggi è vuota.';de = 'Leere Telefonliste zum Senden von Nachrichten.'"));
	Result.Insert(5, NStr("ru = 'Не указан текст сообщения.'; en = 'The message text is not entered.'; pl = 'Nie jest wskazany tekst komunikatu.';es_ES = 'El texto del mensaje no está indicado.';es_CO = 'El texto del mensaje no está indicado.';tr = 'Mesaj metni belirtilmedi.';it = 'Nessun messaggio inserito.';de = 'Der Text der Nachricht wird nicht angegeben.'"));
	Result.Insert(6, NStr("ru = 'Не удалось отправить сообщение на указанный номер.'; en = 'Cannot send the message to the specified number.'; pl = 'Nie udało się wysłać komunikat do wskazanego numeru.';es_ES = 'No se ha podido enviar el mensaje al número indicado.';es_CO = 'No se ha podido enviar el mensaje al número indicado.';tr = 'Mesaj belirtilen numaraya gönderilemedi.';it = 'Impossibile inviare il messaggio al numero specificato.';de = 'Die Nachricht konnte nicht an die angegebene Nummer gesendet werden.'"));
	Result.Insert(7, NStr("ru = 'Не указан отправитель по приоритетному трафику.'; en = 'Priority traffic sender is not specified.'; pl = 'Nie jest wskazany nadawca według ruchu priorytetowego.';es_ES = 'No se ha indicado el destinatario por el tráfico prioritario.';es_CO = 'No se ha indicado el destinatario por el tráfico prioritario.';tr = 'Öncelikli trafik için gönderen belirtilmedi.';it = 'Il mittente del traffico prioritario non è specificato.';de = 'Der Absender des Prioritätsverkehrs ist nicht angegeben.'"));
	Result.Insert(8, NStr("ru = 'Некорректный отправитель, допускается только латиница и цифры.'; en = 'Incorrect sender. Use Latin letters and numbers.'; pl = 'Niepoprawny nadawca. Używaj liter i cyfr łacińskich.';es_ES = 'Remitente incorrecto, se admiten solo letras latinas y cifras.';es_CO = 'Remitente incorrecto, se admiten solo letras latinas y cifras.';tr = 'Yanlış gönderen, sadece Latin karakter ve rakamlara izin verilir.';it = 'Mittente non valido. Sono ammesse solo lettere latine e numeri.';de = 'Falscher Absender. Verwenden Sie lateinische Buchstaben und Zahlen.'"));
	Result.Insert(9, NStr("ru = 'Пустой список идентификаторов сообщений для получения статусов.'; en = 'Empty list of message IDs to receive statuses.'; pl = 'Pusta lista identyfikatorów komunikatów do pobierania statusów.';es_ES = 'Lista vacía de los identificadores de los mensajes para recibir los estados.';es_CO = 'Lista vacía de los identificadores de los mensajes para recibir los estados.';tr = 'Durumları almak için mesaj kimlikleri listesi boş.';it = 'Elenco vuoto di ID messaggio per stati di ricezione.';de = 'Leere Liste der Nachrichtenbezeichner um Status abzurufen.'"));
	Result.Insert(10, NStr("ru = 'Не найдено сообщение с таким идентификатором.'; en = 'Message with this ID is not found.'; pl = 'Nie znaleziono komunikat z takim identyfikatorem.';es_ES = 'No está encontrado ningún mensaje con este identificador.';es_CO = 'No está encontrado ningún mensaje con este identificador.';tr = 'Bu kimliğe sahip mesaj bulunamadı.';it = 'Il messaggio con questo ID non è stato trovato.';de = 'Es wurde keine Nachricht mit einem solchen Identifikator gefunden.'"));
	Result.Insert(11, NStr("ru = 'Не удалось оплатить рассылку, проверьте баланс.'; en = 'Cannot pay for bulk email. Check your balance.'; pl = 'Nie udało się opłacić masowej wysyłki e-mail. Sprawdź bilans.';es_ES = 'No se ha podido pagar el envío, compruebe el saldo.';es_CO = 'No se ha podido pagar el envío, compruebe el saldo.';tr = 'Gönderim bedeli ödenemedi, bakiyeyi kontrol edin.';it = 'Non posso pagare per email massiva. Controllare il saldo.';de = 'Die Bulk Mail konnte nicht bezahlt werden, überprüfen Sie den Kontostand.'"));
	
	Return Result;
EndFunction

Function SendingErrorDescription(ErrorCode)
	ErrorsDetails = ErrorsDetails();
	MessageText = ErrorsDetails[ErrorCode];
	If MessageText = Undefined Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Сообщение не отправлено (код ошибки: %1).'; en = 'Message is not sent (error code: %1).'; pl = 'Komunikat nie jest wysłany (kod błędu: %1).';es_ES = 'Mensaje no enviado (código del error: %1).';es_CO = 'Mensaje no enviado (código del error: %1).';tr = 'Mesaj gönderilemedi (hata kodu: %1).';it = 'Il messaggio non è stato inviato (codice errore: %1).';de = 'Nachricht nicht gesendet (Fehlercode: %1).'"), ErrorCode);
	EndIf;
	Return MessageText;
EndFunction

Function StatusGettingErrorDescription(ErrorCode)
	ErrorsDetails = ErrorsDetails();
	MessageText = ErrorsDetails[ErrorCode];
	If MessageText = Undefined Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Статус сообщения не получен (код ошибки: %1).'; en = 'Message status is not received (error code: %1).'; pl = 'Status komunikatu nie otrzymano (kod błędu: %1).';es_ES = 'Estado del mensaje no recibido (código del error. %1).';es_CO = 'Estado del mensaje no recibido (código del error. %1).';tr = 'Mesaj durumu alınamadı: (hata kodu: %1).';it = 'Lo stato del messaggio non è stato ricevuto (codice errore: %1).';de = 'Nachrichtenstatus nicht empfangen (Fehlercode: %1).'"), ErrorCode);
	EndIf;
	Return MessageText;
EndFunction

Function ExecuteQuery(QueryOptions)
	
	HTTPRequest = SMS.PrepareHTTPRequest("/api/", QueryOptions);
	HTTPResponse = Undefined;
	
	Try
		Connection = New HTTPConnection("gsm-inform.ru",,,, 
			GetFilesFromInternetClientServer.GetProxy("http"), 
			60);
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
	Address = "gsm-inform.ru";
	Port = Undefined;
	Details = NStr("ru = 'Отправка SMS через ""GSM-INFORM"".'; en = 'Send SMS via GSM-INFORM.'; pl = 'Wysłanie SMS poprzez ""GSM-INFORM"".';es_ES = 'Envío de SMS a través de ""GSM-INFORM"".';es_CO = 'Envío de SMS a través de ""GSM-INFORM"".';tr = 'GSM-INFORM üzerinden SMS gönderimi.';it = 'Invio di SMS via GSM-INFORM.';de = 'SMS über ""GSM-INFORM"" versenden.'");
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	Permissions = New Array;
	Permissions.Add(
		ModuleSafeModeManager.PermissionToUseInternetResource(Protocol, Address, Port, Details));
	
	Return Permissions;
EndFunction

Procedure FillServiceDetails(ServiceDetails) Export
	ServiceDetails.InternetAddress = "http://gsm-inform.ru";
	ServiceDetails.UsernamePresentation = NStr("ru = 'ID кабинета'; en = 'Account ID'; pl = 'ID konta';es_ES = 'ID de la cuenta';es_CO = 'ID de la cuenta';tr = 'Hesap kimliği';it = 'ID dell''account';de = 'Konto-ID'");
	ServiceDetails.PasswordPresentation = NStr("ru = 'API-ключ'; en = 'API key'; pl = 'API-klucz';es_ES = 'Clave API';es_CO = 'Clave API';tr = 'API anahtarı';it = 'Chiave API';de = 'API-Schlüssel'");
EndProcedure

#EndRegion

