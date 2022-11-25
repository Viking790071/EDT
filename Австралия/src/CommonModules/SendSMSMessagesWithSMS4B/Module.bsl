#Region Private

// Sends a text message via SMS4B.
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
	
	QueryOptions = New Structure;
	QueryOptions.Insert("Login", Username);
	QueryOptions.Insert("Password", Password);
	QueryOptions.Insert("Source", SenderName);
	QueryOptions.Insert("Text", Text);
	
	For Each RecipientNumber In RecipientsNumbers Do
		QueryOptions.Insert("Phone", FormatNumber(RecipientNumber));
		QueryResult = ExecuteQuery("SendTXT", QueryOptions);
		
		If StrLen(QueryResult) = 20 Then
			SentMessage = New Structure("RecipientNumber,MessageID", RecipientNumber, QueryResult);
			Result.SentMessages.Add(SentMessage);
		Else
			Result.ErrorDescription = Result.ErrorDescription + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось отправить сообщение на %1'; en = 'Couldn''t send message to %1'; pl = 'Nie udało się wysłać wiadomości do %1';es_ES = 'No se ha podido enviar el mensaje a %1';es_CO = 'No se ha podido enviar el mensaje a %1';tr = 'Mesaj şuraya gönderilemedi: %1';it = 'Impossibile inviare messaggio a %1';de = 'Fehler beim Senden der Nachricht an %1'"), RecipientNumber) + ": " + SendingErrorDescription(QueryResult) + Chars.LF;
		EndIf;
	EndDo;
	
	Result.ErrorDescription = TrimR(Result.ErrorDescription);
	If Not IsBlankString(Result.ErrorDescription) Then
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
	QueryOptions.Insert("Login", Username);
	QueryOptions.Insert("Password", Password);
	QueryOptions.Insert("MessageId", MessageID);
	
	// Send the query
	StatusCode = ExecuteQuery("StatusTXT", QueryOptions);
	If IsBlankString(StatusCode) Then
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

Function SMSMessageDeliveryStatus(Val StatusCode)
	StatusesMap = New Map;
	StatusesMap.Insert("-21", "Pending");
	StatusesMap.Insert("-22", "Pending");
	
	If IsBlankString(StatusCode) Or StrStartsWith(StatusCode, "-") 
		Or Not StringFunctionsClientServer.OnlyNumbersInString(StatusCode) Then
			Result = StatusesMap[Lower(StatusCode)];
			Return ?(Result = Undefined, "Error", Result);
	EndIf;
	
	StatusCode = Number(StatusCode);
	
	TotalFragments = StatusCode % 256;
	FragmentsSent = Int(StatusCode / 256) % 256;
	FinalStatus = StatusCode >= 256*256;
	
	If FinalStatus Then
		If TotalFragments = 0 Or TotalFragments > FragmentsSent Then
			Result = "NotDelivered";
		Else
			Result = "Delivered";
		EndIf;
	Else
		If TotalFragments = 0 Or TotalFragments > FragmentsSent Then
			Result = "Sending";
		Else
			Result = "Sent";
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

Function ErrorsDetails()
	ErrorsDetails = New Map;
	
	ErrorsDetails.Insert("0", NStr("ru = 'Превышен лимит открытых сеансов.'; en = 'Open session limit exceeded.'; pl = 'Przekroczono limit otwartych sesji.';es_ES = 'Se ha superado el límite de sesiones abiertas.';es_CO = 'Se ha superado el límite de sesiones abiertas.';tr = 'Açık oturum limiti aşıldı.';it = 'Limite di sessione aperta superato.';de = 'Das Limit für offene Sitzungen wurde überschritten.'"));
	ErrorsDetails.Insert("-1", NStr("ru = 'Неверные учетные данные.'; en = 'Invalid credentials.'; pl = 'Niepoprawne dane.';es_ES = 'Credenciales no válidas.';es_CO = 'Credenciales no válidas.';tr = 'Geçersiz kimlik bilgisi.';it = 'Credenziali non valide.';de = 'Ungültige Zugangsdaten.'"));
	ErrorsDetails.Insert("-10", NStr("ru = 'Сбой сервиса.'; en = 'Service failed.'; pl = 'Błąd usługi.';es_ES = 'Servicio fallido.';es_CO = 'Servicio fallido.';tr = 'Servis başarısız oldu.';it = 'Servizio non riuscito.';de = 'Service fehlgeschlagen.'"));
	ErrorsDetails.Insert("-20", NStr("ru = 'Сбой сеанса.'; en = 'Session failed.'; pl = 'Błąd sesji.';es_ES = 'Sesión fallida.';es_CO = 'Sesión fallida.';tr = 'Oturum başarısız oldu.';it = 'Sessione non riuscita.';de = 'Servicefehler.'"));
	ErrorsDetails.Insert("-21", NStr("ru = 'Идентификатор сообщения не найден.'; en = 'Message ID not found.'; pl = 'Nie znaleziono identyfikatora wiadomości.';es_ES = 'No se ha encontrado el identificador del mensaje.';es_CO = 'No se ha encontrado el identificador del mensaje.';tr = 'Mesaj kodu bulunamadı.';it = 'ID messaggio non trovato.';de = 'Nachrichten-ID nicht gefunden.'"));
	ErrorsDetails.Insert("-22", NStr("ru = 'Неверный идентификатор сообщения.'; en = 'Invalid message ID.'; pl = 'Niepoprawny identyfikator wiadomości.';es_ES = 'Identificador del mensaje no válido.';es_CO = 'Identificador del mensaje no válido.';tr = 'Geçersiz mesaj kodu.';it = 'Messaggio ID non valido.';de = 'Ungültige Nachrichten ID.'"));
	ErrorsDetails.Insert("-29", NStr("ru = 'Отклонено спам-фильтром.'; en = 'Rejected by anti-spam filter.'; pl = 'Odrzucono przez filtr antyspamowy.';es_ES = 'Rechazado por el filtro contra spam.';es_CO = 'Rechazado por el filtro contra spam.';tr = 'Spam filtresi tarafından reddedildi.';it = 'Rifiutato dal filtro anti-spam.';de = 'Vom Spamfilter abgelehnt.'"));
	ErrorsDetails.Insert("-30", NStr("ru = 'Недопустимая кодировка.'; en = 'Invalid encoding.'; pl = 'Nieprawidłowe kodowanie.';es_ES = 'Codificación no válida.';es_CO = 'Codificación no válida.';tr = 'Geçersiz şifreleme.';it = 'Codifica non valida.';de = 'Ungültige Verschlüsselung.'"));
	ErrorsDetails.Insert("-31", NStr("ru = 'Неподдерживаемая зона тарификации.'; en = 'Unsupported tariff zone.'; pl = 'Nieobsługiwana strefa taryfowa.';es_ES = 'Zona de tarificación no soportada.';es_CO = 'Zona de tarificación no soportada.';tr = 'Desteklenmeyen tarife bölgesi.';it = 'Zona tariffaria non supportata.';de = 'Nicht unterstützte Abrechnungszone.'"));
	ErrorsDetails.Insert("-50", NStr("ru = 'Неверный отправитель.'; en = 'Invalid sender.'; pl = 'Niepoprawny nadawca.';es_ES = 'Remitente incorrecto.';es_CO = 'Remitente incorrecto.';tr = 'Geçersiz gönderici.';it = 'Mittente non valido.';de = 'Ungültiger Absender.'"));
	ErrorsDetails.Insert("-51", NStr("ru = 'Получатель ограничен.'; en = 'Restricted recipient.'; pl = 'Ograniczony odbiorca.';es_ES = 'Destinatario restringido.';es_CO = 'Destinatario restringido.';tr = 'Kısıtlanmış alıcı.';it = 'Destinatario limitato.';de = 'Begrenzter Empfänger.'"));
	ErrorsDetails.Insert("-52", NStr("ru = 'Недостаточно средств.'; en = 'Insufficient funds.'; pl = 'Niewystarczające środki.';es_ES = 'Fondos insuficientes.';es_CO = 'Fondos insuficientes.';tr = 'Yetersiz bakiye.';it = 'Fondi insufficienti.';de = 'Unzureichende Mittel.'"));
	ErrorsDetails.Insert("-53", NStr("ru = 'Незарегистрированный отправитель.'; en = 'Unregistered sender.'; pl = 'Nie zarejestrowany nadawca.';es_ES = 'Remitente no registrado.';es_CO = 'Remitente no registrado.';tr = 'Gönderen kayıtlı değil.';it = 'Mittente non registrato.';de = 'Nicht registrierter Absender.'"));
	ErrorsDetails.Insert("-65", NStr("ru = 'Требуется подтверждение отправителя. Свяжитесь со службой поддержки.'; en = 'Sender assurance required. Please contact the support.'; pl = 'Wymagane jest potwierdzenie nadawcy. Skontaktuj się z pomocą techniczną.';es_ES = 'Se requiere la garantía del remitente. Póngase en contacto con el soporte.';es_CO = 'Se requiere la garantía del remitente. Póngase en contacto con el soporte.';tr = 'Gönderen onayı gerekiyor. Lütfen, destek ekibiyle irtibata geçin.';it = 'Richiesta di garanzia del mittente. Contattare il supporto.';de = 'Sicherheit des Absenders benötigt. Wenden Sie Sich bitte an Support.'"));
	ErrorsDetails.Insert("-66", NStr("ru = 'Не задан отправитель.'; en = 'Sender not specified.'; pl = 'Nie jest podany nadawca.';es_ES = 'Remitente no especificado.';es_CO = 'Remitente no especificado.';tr = 'Gönderen belirtilmedi.';it = 'Mittente non specificato.';de = 'Kein Absender zugeordnet.'"));
	ErrorsDetails.Insert("-68", NStr("ru = 'Учетная запись заблокирована.'; en = 'Account blocked.'; pl = 'Konto jest zablokowane.';es_ES = 'Se ha bloqueado la cuenta.';es_CO = 'Se ha bloqueado la cuenta.';tr = 'Hesap engellendi.';it = 'Account bloccato.';de = 'Account gesperrt.'"));
	
	Return ErrorsDetails;
EndFunction

Function SendingErrorDescription(ErrorCode)
	ErrorsDetails = ErrorsDetails();
	MessageText = ErrorsDetails[ErrorCode];
	If MessageText = Undefined Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Код ошибки: %1.'; en = 'Error code: %1.'; pl = 'Kod błędu: %1.';es_ES = 'Código de error: %1.';es_CO = 'Código de error: %1.';tr = 'Hata kodu: %1.';it = 'Codice errore: %1.';de = 'Fehlercode: %1.'"), ErrorCode);
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
	
	HTTPRequest = SMS.PrepareHTTPRequest("/ws/s1c.asmx/" + MethodName, QueryOptions);
	HTTPResponse = Undefined;
	
	Try
		Connection = New HTTPConnection("sms4b.ru",,,, 
			GetFilesFromInternetClientServer.GetProxy("https"),
			60, 
			CommonClientServer.NewSecureConnection());
			
		HTTPResponse = Connection.Post(HTTPRequest);
	Except
		WriteLogEvent(NStr("ru = 'Отправка SMS'; en = 'Text messaging'; pl = 'Wysyłanie wiadomości SMS';es_ES = 'SMS';es_CO = 'SMS';tr = 'SMS Mesajlaması';it = 'Messaggistica di testo';de = 'Senden von Textnachrichten'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Result = "";
	If HTTPResponse <> Undefined Then
		ResponseText = HTTPResponse.GetBodyAsString();
		XMLReader = New XMLReader;
		XMLReader.SetString(ResponseText);
		XMLReader.Read();
		If XMLReader.Name = "string" Then
			If XMLReader.Read() Then
				Result = XMLReader.Value;
			EndIf;
		EndIf;
		XMLReader.Close();
	EndIf;
	
	Return Result;
	
EndFunction

Function FormatNumber(Number)
	Result = "";
	AllowedChars = "1234567890";
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
	
	Protocol = "HTTPS";
	Address = "sms4b.ru";
	Port = Undefined;
	Details = NStr("ru = 'Отправка SMS через SMS4B.'; en = 'Text messaging via SMS4B.'; pl = 'Wysyłanie wiadomości SMS poprzez SMS4B.';es_ES = 'SMS a través de SMS4B.';es_CO = 'SMS a través de SMS4B.';tr = 'SMS4B ile mesajlaşma.';it = 'Messaggistica di testo tramite SMS4B.';de = 'Senden von Textnachrichten über SMS4B.'");
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	Permissions = New Array;
	Permissions.Add(
		ModuleSafeModeManager.PermissionToUseInternetResource(Protocol, Address, Port, Details));
	
	Return Permissions;
EndFunction

Procedure FillServiceDetails(ServiceDetails) Export
	ServiceDetails.InternetAddress = "http://sms4b.ru";
EndProcedure

#EndRegion

