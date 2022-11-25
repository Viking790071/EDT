#Region Private

// Sends a text message via Beeline.
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
	
	Result = New Structure("SentMessages,ErrorDetails", New Array, "");
	
	// Prepare a string of recipients.
	RecipientsString = RecipientsArrayAsString(RecipientsNumbers);
	
	// Check whether required parameters are filled in.
	If IsBlankString(RecipientsString) Or IsBlankString(Text) Then
		Result.ErrorDetails = NStr("ru = 'Неверные параметры сообщения'; en = 'Invalid message parameters'; pl = 'Błędne parametry komunikatu';es_ES = 'Parámetros incorrectos del mensaje';es_CO = 'Parámetros incorrectos del mensaje';tr = 'Mesaj parametreleri yanlış';it = 'Parametri messaggio non validi';de = 'Falsche Nachrichtenparameter'");
		Return Result;
	EndIf;
	
	// Prepare query options.
	QueryOptions = New Map;
	QueryOptions.Insert("user", Username);
	QueryOptions.Insert("pass", Password);
	QueryOptions.Insert("gzip", "none");
	QueryOptions.Insert("action", "post_sms");
	QueryOptions.Insert("message", Text);
	QueryOptions.Insert("target", RecipientsString);
	QueryOptions.Insert("sender", SenderName);
	
	// Send the query.
	Response = ExecuteQuery(QueryOptions);
	If Response = Undefined Then
		Result.ErrorDetails = Result.ErrorDetails + NStr("ru = 'Соединение не установлено'; en = 'Connection failed'; pl = 'Połączenie nie jest ustawione';es_ES = 'Conexión no establecida';es_CO = 'Conexión no establecida';tr = 'Bağlantı kurulamadı';it = 'Connessione fallita';de = 'Verbindung nicht hergestellt'");
		Return Result;
	EndIf;		
	
	// Process the query result (get messages IDs).
	ResponseStructure = New XMLReader;
	ResponseStructure.SetString(Response);
	ErrorDetails = "";
	While ResponseStructure.Read() Do 
		If ResponseStructure.NodeType = XMLNodeType.StartElement Then
			If ResponseStructure.Name = "sms" Then 
				MessageID = "";
				RecipientNumber = "";
				While ResponseStructure.ReadAttribute() Do 
					If ResponseStructure.Name = "id" Then 
						MessageID = ResponseStructure.Value;
					ElsIf ResponseStructure.Name = "phone" Then
						RecipientNumber = ResponseStructure.Value;
					EndIf;
				EndDo;
				If Not IsBlankString(RecipientNumber) Then
					SentMessage = New Structure("RecipientNumber,MessageID",
														 RecipientNumber,MessageID);
					Result.SentMessages.Add(SentMessage);
				EndIf;
			ElsIf ResponseStructure.Name = "error" Then
				ResponseStructure.Read();
				ErrorDetails = ErrorDetails + ResponseStructure.Value + Chars.LF;
			EndIf;
		EndIf;
	EndDo;
	ResponseStructure.Close();
	
	Result.ErrorDetails = TrimR(ErrorDetails);
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
	QueryOptions = New Map;
	QueryOptions.Insert("user", Username);
	QueryOptions.Insert("pass", Password);
	QueryOptions.Insert("gzip", "none");
	QueryOptions.Insert("action", "status");
	QueryOptions.Insert("sms_id", MessageID);
	
	// Send the query.
	Response = ExecuteQuery(QueryOptions);
	If Response = Undefined Then
		Return "Error";
	EndIf;
	
	// Process the query result.
	SMSSTS_CODE = "";
	CurrentSMSMessage_ID = "";
	ResponseStructure = New XMLReader;
	ResponseStructure.SetString(Response);
	While ResponseStructure.Read() Do 
		If ResponseStructure.NodeType = XMLNodeType.StartElement Then
			If ResponseStructure.Name = "MESSAGE" Then 
				While ResponseStructure.ReadAttribute() Do 
					If ResponseStructure.Name = "SMS_ID" Then 
						CurrentSMSMessage_ID = ResponseStructure.Value;
					EndIf;
				EndDo;
			ElsIf ResponseStructure.Name = "SMSSTC_CODE" AND MessageID = CurrentSMSMessage_ID Then
				ResponseStructure.Read();
				SMSSTS_CODE = ResponseStructure.Value;
			EndIf;
		EndIf;
	EndDo;
	ResponseStructure.Close();
	
	Return SMSMessageDeliveryStatus(SMSSTS_CODE); 
	
EndFunction

Function SMSMessageDeliveryStatus(StatusAsString)
	StatusesMapping = New Map;
	StatusesMapping.Insert("", "Pending");
	StatusesMapping.Insert("queued", "Pending");
	StatusesMapping.Insert("wait", "Sending");
	StatusesMapping.Insert("accepted", "Sent");
	StatusesMapping.Insert("delivered", "Delivered");
	StatusesMapping.Insert("failed", "NotDelivered");
	
	Result = StatusesMapping[Lower(StatusAsString)];
	Return ?(Result = Undefined, "Error", Result);
EndFunction

Function ExecuteQuery(QueryOptions)
	
	HTTPRequest = SMS.PrepareHTTPRequest("/sendsms/", QueryOptions);
	HTTPResponse = Undefined;
	
	Try
		Connection = New HTTPConnection("beeline.amega-inform.ru",,,, 
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
	Result = "";
	For Each Item In Array Do
		Number = FormatNumber(Item);
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
	Address = "beeline.amega-inform.ru";
	Port = Undefined;
	Details = NStr("ru = 'Отправка SMS через Билайн.'; en = 'Text messaging via Beeline.'; pl = 'Wysyłanie wiadomości SMS poprzez Beeline.';es_ES = 'SMS a través de Beeline.';es_CO = 'SMS a través de Beeline.';tr = 'Beeline ile mesajlaşma.';it = 'Messaggistica di testo tramite Beeline.';de = 'Senden von Textnachrichten über Beeline.'");
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	Permissions = New Array;
	Permissions.Add(
		ModuleSafeModeManager.PermissionToUseInternetResource(Protocol, Address, Port, Details));
	
	Return Permissions;
EndFunction

Procedure FillServiceDetails(ServiceDetails) Export
	ServiceDetails.InternetAddress = "http://b2b.beeline.ru/msk/sb/mobile/services/index.wbp?id=3a15308a-7b14-4f8e-acda-0841dd6c750e";
EndProcedure

#EndRegion
