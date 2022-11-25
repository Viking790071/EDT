#Region Private

// Sends a text message via SMS Services.
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
	
	// Prepare recipients.
	Recipients = New Array;
	For Each Item In RecipientsNumbers Do
		Recipient = FormatNumberToSend(Item);
		If Recipients.Find(Recipient) = Undefined Then
			Recipients.Add(Recipient);
		EndIf;
	EndDo;
	
	// Check whether required parameters are filled in.
	If RecipientsNumbers.Count() = 0 Or IsBlankString(Text) Then
		Result.ErrorDescription = NStr("ru = 'Неверные параметры сообщения'; en = 'Invalid message parameters'; pl = 'Błędne parametry komunikatu';es_ES = 'Parámetros incorrectos del mensaje';es_CO = 'Parámetros incorrectos del mensaje';tr = 'Mesaj parametreleri yanlış';it = 'Parametri messaggio non validi';de = 'Falsche Nachrichtenparameter'");
		Return Result;
	EndIf;
	
	// Prepare query options.
	QueryOptions = New Structure;
	QueryOptions.Insert("login", Username);
	QueryOptions.Insert("password", Password);
	QueryOptions.Insert("action", "send");
	QueryOptions.Insert("text", Text);
	QueryOptions.Insert("to", Recipients);
	QueryOptions.Insert("source", SenderName);
	
	// Send the query
	ResponseText = ExecuteQuery("send.php", QueryOptions);
	If Not ValueIsFilled(ResponseText) Then
		Result.ErrorDescription = Result.ErrorDescription + NStr("ru = 'Соединение не установлено'; en = 'Connection failed'; pl = 'Połączenie nie jest ustawione';es_ES = 'Conexión no establecida';es_CO = 'Conexión no establecida';tr = 'Bağlantı kurulamadı';it = 'Connessione fallita';de = 'Verbindung nicht hergestellt'");
		Return Result;
	EndIf;
	
	XMLReader = New XMLReader;
	XMLReader.SetString(ResponseText);
	ServerResponse = New Structure("code,descr,smsid");
	FillPropertyValues(ServerResponse, XDTOFactory.ReadXML(XMLReader));
	XMLReader.Close();
	
	ResultCode = ServerResponse.code;
	If ResultCode = "1" Then
		MessageID = ServerResponse.smsid;
		For Each Recipient In Recipients Do
			SentMessage = New Structure("RecipientNumber,MessageID", 
				FormatNumberFromSendingResult(Recipient), Recipient + "/" + MessageID);
			Result.SentMessages.Add(SentMessage);
		EndDo;
	Else
		Result.ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(NStr(
			"ru = 'Не удалось отправить сообщение. Код ошибки %2.
			|Подробнее: %1'; 
			|en = 'Message sending failed with error code %2
			|Details: %1.'; 
			|pl = 'Nie udało się wysłać wiadomości. Kod błędu %2
			|Szczegóły: %1.';
			|es_ES = 'Ha ocurrido un error al enviar el mensaje con el código de error %2.
			|Detalles: %1.';
			|es_CO = 'Ha ocurrido un error al enviar el mensaje con el código de error %2.
			|Detalles: %1.';
			|tr = 'Mesaj gönderimi %2 hata koduyla başarısız oldu
			|Ayrıntılar: %1.';
			|it = 'Invio messaggio non riuscito con codice errore %2.
			|Dettagli: %1.';
			|de = 'Senden einer Nachricht fehlgeschlagen mit Fehlercode %2
			|Details: %1.'"), ServerResponse.descr, ResultCode);
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
Function DeliveryStatus(Val MessageID, SMSMessageSendingSettings) Export
	
	IDParts = StrSplit(MessageID, "/", True);
	RecipientNumber = IDParts[0];
	MessageID = IDParts[1];
	
	Username = SMSMessageSendingSettings.Username;
	Password = SMSMessageSendingSettings.Password;
	
	DeliveryStatuses = New Map;
	
	// Prepare query options.
	QueryOptions = New Structure;
	QueryOptions.Insert("login", Username);
	QueryOptions.Insert("password", Password);
	QueryOptions.Insert("smsid", MessageID);
	
	// Send the query
	ResponseText = ExecuteQuery("report.php", QueryOptions);
	If Not ValueIsFilled(ResponseText) Then
		Return "Error";
	EndIf;
	
	XMLReader = New XMLReader;
	XMLReader.SetString(ResponseText);
	ServerResponse = New Structure("code,descr,detail");
	FillPropertyValues(ServerResponse, XDTOFactory.ReadXML(XMLReader));
	XMLReader.Close();

	ResultCode = ServerResponse.code;
	If ResultCode = "1" Then
		For Each Status In ServerResponse.detail.Properties() Do
			Recipients = ServerResponse.detail[Status.Name].Sequence();
			For Index = 0 To Recipients.Count()-1 Do
				Recipient = Recipients.GetValue(Index);
				DeliveryStatuses.Insert(Recipient, SMSMessageDeliveryStatus(Status.Name));
			EndDo;
		EndDo;
	Else
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
			|Details: %1'"), ServerResponse.descr, ResultCode, MessageID);
		WriteLogEvent(NStr("ru = 'Отправка SMS'; en = 'Text messaging'; pl = 'Wysyłanie wiadomości SMS';es_ES = 'SMS';es_CO = 'SMS';tr = 'SMS Mesajlaması';it = 'Messaggistica di testo';de = 'Senden von Textnachrichten'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, , , ErrorDescription);
		Return "Error";
	EndIf;
	
	Result = DeliveryStatuses[RecipientNumber];
	If Result = Undefined Then
		Result = "Pending";
	EndIf;
	
	Return Result;
	
EndFunction

Function SMSMessageDeliveryStatus(StatusCode)
	StatusesMap = New Map;
	StatusesMap.Insert("enqueued", "Sending");
	StatusesMap.Insert("onModer", "Sending");
	StatusesMap.Insert("process", "Sending");
	StatusesMap.Insert("waiting", "Sent");
	StatusesMap.Insert("delivered", "Delivered");
	StatusesMap.Insert("notDelivered", "NotDelivered");
	StatusesMap.Insert("cancel", "NotSent");
	
	Result = StatusesMap[StatusCode];
	Return ?(Result = Undefined, "Pending", Result);
EndFunction

Function ExecuteQuery(MethodName, QueryOptions)
	
	HTTPRequest = SMS.PrepareHTTPRequest("/API/XML/" + MethodName, GenerateHTTPRequestBody(QueryOptions));
	HTTPResponse = Undefined;
	
	Try
		Connection = New HTTPConnection("lcab.sms-uslugi.ru",,,, 
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

Function GenerateHTTPRequestBody(QueryOptions)
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.WriteXMLDeclaration();
	XMLWriter.WriteStartElement("data");
	For Each Parameter In QueryOptions Do
		If Parameter.Key = "to" Then
			For Each Number In Parameter.Value Do
				XMLWriter.WriteStartElement(Parameter.Key);
				XMLWriter.WriteAttribute("number", Number);
				XMLWriter.WriteEndElement();
			EndDo;
		Else
			XMLWriter.WriteStartElement(Parameter.Key);
			XMLWriter.WriteText(Parameter.Value);
			XMLWriter.WriteEndElement();
		EndIf;
	EndDo;
	XMLWriter.WriteEndElement();
	Return XMLWriter.Close();
	
EndFunction

Function FormatNumberToSend(Number)
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

Function FormatNumberFromSendingResult(Number)
	Result = Number;
	
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
	
	Protocol = "HTTP";
	Address = "lcab.sms-uslugi.ru";
	Port = Undefined;
	Details = NStr("ru = 'Отправка SMS через ""СМС-Услуги"".'; en = 'Send SMS via SMS Services'; pl = 'Wysłanie SMS poprzez ""SMS-Usługi"".';es_ES = 'Enviar SMS a través de ""SMS-Servicios "".';es_CO = 'Enviar SMS a través de ""SMS-Servicios "".';tr = 'SMS-Hizmetler üzerinden SMS gönderimi';it = 'Invia SMS tramite servizio SMS';de = 'SMS über ""SMS-Services"" versenden.'");
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	Permissions = New Array;
	Permissions.Add(
		ModuleSafeModeManager.PermissionToUseInternetResource(Protocol, Address, Port, Details));
	
	Return Permissions;
EndFunction

Procedure FillServiceDetails(ServiceDetails) Export
	ServiceDetails.InternetAddress = "http://sms-uslugi.ru";
EndProcedure

#EndRegion

