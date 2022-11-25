#Region Private

// Sends a text message via MTS.
//
// Parameters:
//  RecipientsNumbers - Array - recipient numbers in format +7ХХХХХХХХХХ (as string).
//  Text - String - a message text with length not more than 1000 characters.
//  SenderName 	 - String - a sender name that will be displayed instead of a number of incoming text message.
//  Username - String - a username in the text message sending service.
//  Password - String - a password in the text message sending service.
//
// Returns:
//  Structure: SentMessages - an array of structures: RecipientNumber.
//                                                  MessageID.
//             ErrorDescription - String - a user presentation of an error. If the string is empty, 
//                                          there is no error.
Function SendSMSMessage(RecipientsNumbers, Text, SenderName, Username, Val Password) Export
	Result = New Structure("SentMessages,ErrorDetails", New Array, "");
	
	Password = Common.CheckSumString(Password);
	
	RecipientsIDs = New Array;
	For Each Item In RecipientsNumbers Do
		RecipientID = FormatNumber(Item);
		If RecipientsIDs.Find(RecipientID) = Undefined Then
			RecipientsIDs.Add(RecipientID);
		EndIf;
	EndDo;
	
	Try
		WebService = AttachWebService();
	Except
		ProcessException(ErrorInfo(), Result.ErrorDetails);
		Return Result;
	EndTry;
	
	TypeArrayOfString = WebService.XDTOFactory.Packages.Get("http://mcommunicator.ru/M2M").Get("ArrayOfString");
	ArrayOfString = WebService.XDTOFactory.Create(TypeArrayOfString);
	
	For Each RecipientID In RecipientsIDs Do
		ArrayOfString.string.Add(RecipientID);
	EndDo;
		
	If RecipientsIDs.Count() > 0 Then
		ResponseReceived = False;
		Try
			ArrayOfSendMessageIDs = WebService.SendMessages(ArrayOfString, Left(Text, 1000), SenderName, Username, Password);
			ResponseReceived = True;
		Except
			ProcessException(ErrorInfo(), Result.ErrorDetails, True, WebService);
			Return Result;
		EndTry;
		
		If ResponseReceived Then
			For Each SendMessageID In ArrayOfSendMessageIDs.SendMessageIDs Do
				RecipientNumber = SendMessageID.Msid;
				MessageID = SendMessageID.MessageID;
				Result.SentMessages.Add(New Structure("RecipientNumber,MessageID",
					"+" +  RecipientNumber, Format(MessageID, "NG=")));
			EndDo;
		EndIf;
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
	Result = "Error";
	
	Username = SMSMessageSendingSettings.Username;
	Password = Common.CheckSumString(SMSMessageSendingSettings.Password);
	WebService = AttachWebService();
	Try
		ArrayOfDeliveryInfo = WebService.GetMessageStatus(MessageID, Username, Password);
	Except
		ProcessException(ErrorInfo(),, True, WebService);
		Return Result;
	EndTry;
	
	For Each DeliveryInfo In ArrayOfDeliveryInfo.DeliveryInfo Do
		Result = SMSMessageDeliveryStatus(DeliveryInfo.DeliveryStatus);
	EndDo;
	
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

Function SMSMessageDeliveryStatus(StatusAsString)
	StatusesMapping = New Map;
	StatusesMapping.Insert("Pending", "Pending");
	StatusesMapping.Insert("Sending", "Sending");
	StatusesMapping.Insert("Sent", "Sent");
	StatusesMapping.Insert("NotSent", "NotSent");
	StatusesMapping.Insert("Delivered", "Delivered");
	StatusesMapping.Insert("NotDelivered", "NotDelivered");
	StatusesMapping.Insert("TimedOut", "NotDelivered");
	
	Result = StatusesMapping[StatusAsString];
	Return ?(Result = Undefined, "Error", Result);
EndFunction

Function AttachWebService()
	
	ConnectionParameters = Common.WSProxyConnectionParameters();
	ConnectionParameters.WSDLAddress = "https://www.mcommunicator.ru/m2m/m2m_api.asmx?WSDL";
	ConnectionParameters.NamespaceURI = "http://mcommunicator.ru/M2M";
	ConnectionParameters.ServiceName = "MTS_x0020_Communicator_x0020_M2M_x0020_XML_x0020_API";
	ConnectionParameters.EndpointName = "MTS_x0020_Communicator_x0020_M2M_x0020_XML_x0020_APISoap12";
	ConnectionParameters.Timeout = 60;
	ConnectionParameters.SecureConnection = CommonClientServer.NewSecureConnection();
	
	Return Common.CreateWSProxy(ConnectionParameters);
	
EndFunction

Function ErrorsDetails()
	ErrorsDetails = New Map;
	ErrorsDetails.Insert("SYSTEM_FAILURE", NStr("ru = 'Временная проблема на стороне МТС.'; en = 'Temporary issue on MTS side.'; pl = 'Tymczasowy problem na stronie MTS.';es_ES = 'Edición temporal en el lado del MTS.';es_CO = 'Edición temporal en el lado del MTS.';tr = 'MTS üzerinde geçici sorun.';it = 'Emissione temporanea su lato MTS.';de = 'Temporäres Problem auf MTS-Seite.'"));
	ErrorsDetails.Insert("TOO_MANY_PARAMETERS", NStr("ru = 'Превышено максимальное число параметров.'; en = 'Maximum number of parameters exceeded.'; pl = 'Przekroczono maksymalną liczbę parametrów.';es_ES = 'Número máximo de parámetros excedidos.';es_CO = 'Número máximo de parámetros excedidos.';tr = 'Maksimum parametre sayısı aşıldı.';it = 'Numero massimo di parametri superato.';de = 'Maximale Anzahl der Parameter überschritten.'"));
	ErrorsDetails.Insert("INCORRECT_PASSWORD", NStr("ru = 'Предоставленные логин/пароль не верны.'; en = 'The username or password is incorrect.'; pl = 'Nazwa użytkownika lub hasło są nieprawidłowe.';es_ES = 'El nombre de usuario o la contraseña son incorrectos.';es_CO = 'El nombre de usuario o la contraseña son incorrectos.';tr = 'Kullanıcı adı veya şifre yanlış.';it = 'Il nome utente o la password sono non corretti.';de = 'Der Benutzername oder das Passwort ist falsch.'"));
	ErrorsDetails.Insert("MSID_FORMAT_ERROR", NStr("ru = 'Формат номера неверный.'; en = 'Incorrect number format.'; pl = 'Błędny format numeru.';es_ES = 'Formato de número incorrecto.';es_CO = 'Formato de número incorrecto.';tr = 'Yanlış numara formatı.';it = 'Formato del numero non corretto.';de = 'Falsches Zahlenformat.'"));
	ErrorsDetails.Insert("MESSAGE_FORMAT_ERROR", NStr("ru = 'Ошибка в формате сообщения.'; en = 'An error occurred in the message format.'; pl = 'Wystąpił błąd w formacie wiadomości.';es_ES = 'Se ha producido un error en el formato del mensaje.';es_CO = 'Se ha producido un error en el formato del mensaje.';tr = 'Mesaj formatında hata oluştu.';it = 'Si è verificato un errore nel formato del messaggio.';de = 'Im Nachrichtenformat ist ein Fehler aufgetreten.'"));
	ErrorsDetails.Insert("WRONG_ID", NStr("ru = 'Передан неверный идентификатор.'; en = 'Incorrect ID passed.'; pl = 'Przekazano niepoprawny Id.';es_ES = 'ID incorrecto transmitido.';es_CO = 'ID incorrecto transmitido.';tr = 'Yanlış kimlik verildi.';it = 'Passato ID incorretto.';de = 'Falsche ID übergeben.'"));
	ErrorsDetails.Insert("MESSAGE_HANDLING_ERROR", NStr("ru = 'Ошибка в обработке сообщения'; en = 'An error occurred when processing the message'; pl = 'Wystąpił błąd podczas przetwarzania wiadomości';es_ES = 'Se ha producido un error al procesar el mensaje';es_CO = 'Se ha producido un error al procesar el mensaje';tr = 'Mesaj işlenirken hata oluştu';it = 'Si è verificato un errore durante l''elaborazione del messaggio';de = 'Bei der Verarbeitung der Nachricht ist ein Fehler aufgetreten'"));
	ErrorsDetails.Insert("NO_SUCH_SUBSCRIBER", NStr("ru = 'Данный абонент не зарегистрирован в Услуге в учетной записи клиента (или еще не дал подтверждение).'; en = 'This subscriber is not registered in the Service in the client account (or has not confirmed it yet).'; pl = 'Ten subskrybent nie jest zarejestrowany w serwisie na koncie klienta (lub jeszcze to nie potwierdził).';es_ES = 'Este suscriptor no está registrado en el Servicio en la cuenta del cliente (o no lo ha confirmado todavía).';es_CO = 'Este suscriptor no está registrado en el Servicio en la cuenta del cliente (o no lo ha confirmado todavía).';tr = 'Bu abone, Müşteri hesabına Hizmete kayıtlı değil (veya henüz onaylamadı).';it = 'Questo abbonato non è registrato nel Servizio nel conto client (oppure non lo ha ancora confermato).';de = 'Dieser Abonnent ist nicht im Service im Kundenkonto registriert (oder hat es noch nicht bestätigt).'"));
	ErrorsDetails.Insert("TEST_LIMIT_EXCEEDED", NStr("ru = 'Превышен лимит по количеству сообщений в тестовой эксплуатации.'; en = 'Limited number of messages in the test operation is exceeded.'; pl = 'Przekroczono ograniczoną liczbę komunikatów podczas operacji testowej.';es_ES = 'Se supera el número limitado de mensajes en la operación de prueba.';es_CO = 'Se supera el número limitado de mensajes en la operación de prueba.';tr = 'Test işlemindeki sınırlı sayıda mesaj aşıldı.';it = 'Il numero di messaggi limitato nell''operazione di test è stato superato.';de = 'Die begrenzte Anzahl von Nachrichten im Testbetrieb wird überschritten.'"));
	ErrorsDetails.Insert("TRUSTED_LIMIT_EXCEEDED", NStr("ru = 'Превышен лимит по количеству сообщений для абонентов, которые были добавлены без подтверждения.'; en = 'Number of messages for subscribers added without confirmation exceeds the limit.'; pl = 'Liczba wiadomości dla subskrybentów, dodanych bez potwierdzenia, przekracza limit.';es_ES = 'El número de mensajes para los suscriptores añadidos sin confirmación excede el límite.';es_CO = 'El número de mensajes para los suscriptores añadidos sin confirmación excede el límite.';tr = 'Onay olmadan eklenen abonelerin mesaj sayısı limiti aşıyor.';it = 'Il numero di messaggi per abbonati aggiunti senza conferma supera il limite.';de = 'Die Anzahl der ohne Bestätigung hinzugefügten Nachrichten für Abonnenten überschreitet das Limit.'"));
	ErrorsDetails.Insert("IP_NOT_ALLOWED", NStr("ru = 'Доступ к сервису с данного IP невозможен (список допустимых IP-адресов можно указывается при подключении услуги).'; en = 'Cannot access the service from this IP (you can specify valid IP addresses when enabling the service).'; pl = 'Nie można uzyskać dostępu do usługi z tego adresu IP (można określić prawidłowe adresy IP podczas włączania serwisu).';es_ES = 'No se puede acceder al Servicio desde este IP (puede especificar direcciones IP válidos al habilitar el Servicio).';es_CO = 'No se puede acceder al Servicio desde este IP (puede especificar direcciones IP válidos al habilitar el Servicio).';tr = 'Servise bu IP üzerinden erişilemiyor (servisi etkinleştirirken geçerli IP adresleri belirleyebilirsiniz).';it = 'Impossibile accedere al servizio da questo IP (è possibile specificare un indirizzo IP valido all''attivazione del servizio).';de = 'Der Zugriff auf den Service über diese IP-Adresse ist nicht möglich (Sie können bei der Aktivierung des Services gültige IP-Adressen angeben).'"));
	ErrorsDetails.Insert("MAX_LENGTH_EXCEEDED", NStr("ru = 'Превышена максимальная длина сообщения (1000 символов).'; en = 'Maximum message length exceeded (1000 characters).'; pl = 'Przekroczono maksymalną długość wiadomości (1000 znaków).';es_ES = 'Longitud máxima del mensaje excedida (1000 caracteres).';es_CO = 'Longitud máxima del mensaje excedida (1000 caracteres).';tr = 'Maksimum mesaj uzunluğu aşıldı (1000 karakter).';it = 'Lunghezza massima del messaggio superata (1000 caratteri).';de = 'Maximale Nachrichtenlänge überschritten (1000 Zeichen).'"));
	ErrorsDetails.Insert("OPERATION_NOT_ALLOWED", NStr("ru = 'Пользователь услуги не имеет прав на выполнение данной операции.'; en = 'User of the service has no rights to execute this operation.'; pl = 'Użytkownik serwisu nie ma uprawnień do wykonania tej operacji.';es_ES = 'El usuario del servicio no tiene derecho de ejecutar esta operación.';es_CO = 'El usuario del servicio no tiene derecho de ejecutar esta operación.';tr = 'Hizmetin kullanıcısı bu işlemi yürütme hakkına sahip değildir.';it = 'L''utente del servizio non possiede i diritti per eseguire questa operazione.';de = 'Der Benutzer des Services hat keine Rechte, diese Operation auszuführen.'"));
	ErrorsDetails.Insert("EMPTY_MESSAGE_NOT_ALLOWED", NStr("ru = 'Отправка пустых сообщений не допускается.'; en = 'Cannot send empty messages.'; pl = 'Nie można wysłać pustych wiadomości.';es_ES = 'No se puede enviar mensajes vacíos.';es_CO = 'No se puede enviar mensajes vacíos.';tr = 'Boş mesajlar gönderilemiyor.';it = 'Impossibile inviare messaggi vuoti.';de = 'Es können keine leeren Nachrichten gesendet werden.'"));
	ErrorsDetails.Insert("ACCOUNT_IS_BLOCKED", NStr("ru = 'Учетная запись заблокирована, отправка сообщений не возможна.'; en = 'Account is locked. Cannot send messages.'; pl = 'Konto zostało zablokowane. Nie można wysyłać wiadomości.';es_ES = 'La cuenta está bloqueada. No se puede enviar mensajes.';es_CO = 'La cuenta está bloqueada. No se puede enviar mensajes.';tr = 'Hesap kilitli. Mesaj gönderilemiyor.';it = 'L''account è bloccato. Impossibile inviare messaggi.';de = 'Das Konto ist gesperrt. Es können keine Nachrichten gesendet werden.'"));
	ErrorsDetails.Insert("OBJECT_ALREADY_EXISTS", NStr("ru = 'Список рассылки с указанным названием уже существует в рамках компании.'; en = 'Bulk email list with the specified name already exists in the company.'; pl = 'Lista masowej wysyłki e-mail o określonej nazwie już istnieje w tej firmie.';es_ES = 'Lista de correo electrónico masivo con el nombre especificado ya existe en la empresa.';es_CO = 'Lista de correo electrónico masivo con el nombre especificado ya existe en la empresa.';tr = 'Belirtilen adı taşıyan toplu e-posta listesi, iş yerinde zaten var.';it = 'L''elenco email massive con il nome specificato già esista nella azienda.';de = 'Eine Bulk-Mail-Liste mit dem angegebenen Namen ist bereits in der Firma vorhanden.'"));
	ErrorsDetails.Insert("MSID_IS_IN_BLACKLIST", NStr("ru = 'Номер абонента находится в черном списке, отправка сообщений запрещена.'; en = 'Subscriber number is in the black list, cannot send messages.'; pl = 'Numer subskrybenta znajduje się na czarnej liście, nie można wysyłać wiadomości.';es_ES = 'El número de suscriptor está en la lista negra, no se puede enviar mensajes.';es_CO = 'El número de suscriptor está en la lista negra, no se puede enviar mensajes.';tr = 'Abone numarası kara listede; mesaj gönderemiyor.';it = 'Il numero dell''abbonato è nella lista nera, impossibile inviare messaggi.';de = 'Die Teilnehmernummer ist in der schwarzen Liste, kann keine Nachrichten senden.'"));
	ErrorsDetails.Insert("MSIDS_ARE_IN_BLACKLIST", NStr("ru = 'Все указанные номера абонентов находятся в черном списке, отправка сообщений запрещена.'; en = 'All specified subscriber numbers are in the black list, cannot send messages.'; pl = 'Wszyscy określeni numery subskrybentów znajdują się na czarnej liście, nie można wysyłać wiadomości.';es_ES = 'Todos los números de suscriptores especificados están en la lista negra, no se puede enviar mensajes.';es_CO = 'Todos los números de suscriptores especificados están en la lista negra, no se puede enviar mensajes.';tr = 'Belirtilen tüm abone numaraları kara listede; mesajlar gönderilemiyor.';it = 'Tutti i numeri di abbonati specificati sono nella lista nera, impossibile inviare messaggi.';de = 'Alle angegebenen Teilnehmernummern befinden sich in der schwarzen Liste, können keine Nachrichten senden.'"));
	ErrorsDetails.Insert("TIME_IS_IN_THE_PAST", NStr("ru = 'Переданное время в прошлом.'; en = 'Transferred time in the past.'; pl = 'Przeniesiony czas w przeszłości.';es_ES = 'Tiempo transferido en el pasado.';es_CO = 'Tiempo transferido en el pasado.';tr = 'Aktarılan zaman geçmiştedir.';it = 'Tempo trasferito nel passato.';de = 'Übertragene Zeit in der Vergangenheit.'"));
	
	Return ErrorsDetails;
EndFunction

Function ErrorDetailsByCode(ErrorCode)
	ErrorsDetails = ErrorsDetails();
	MessageText = ErrorsDetails[ErrorCode];
	If MessageText = Undefined Then
		MessageText = NStr("ru = 'Операция не выполнена.'; en = 'Operation failed.'; pl = 'Operacja nie jest wykonana.';es_ES = 'Operación no realizada.';es_CO = 'Operación no realizada.';tr = 'İşlem yapılamadı.';it = 'Operazione non riuscita.';de = 'Operation fehlgeschlagen.'");
	EndIf;
	Return MessageText;
EndFunction

Function ErrorCodeFromDetails(Val ErrorText)
	Result = Undefined;
	Position = StrFind(ErrorText, "<description");
	If Position > 0 Then
		ErrorText = Mid(ErrorText, Position);
		Position = StrFind(ErrorText, "</description");
		If Position > 0 Then
			ErrorText = Left(ErrorText, Position - 1);
			Position = StrFind(ErrorText, ">");
			If Position > 0 Then
				ErrorText = Mid(ErrorText, Position + 1);
				Result = ErrorText;
			EndIf;
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
	Address = "https://mcommunicator.ru";
	Port = Undefined;
	Details = NStr("ru = 'Отправка SMS через МТС.'; en = 'Text messaging via MTS.'; pl = 'Wysyłanie wiadomości SMS poprzez MTS.';es_ES = 'SMS a través de MTS.';es_CO = 'SMS a través de MTS.';tr = 'MTS ile mesajlaşma.';it = 'Messaggistica di testo via MTS.';de = 'Senden von Textnachrichten über MTS.'");
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	Permissions = New Array;
	Permissions.Add(
		ModuleSafeModeManager.PermissionToUseInternetResource(Protocol, Address, Port, Details));
	
	Return Permissions;
EndFunction

Procedure FillServiceDetails(ServiceDetails) Export
	ServiceDetails.InternetAddress = "http://www.mtscommunicator.ru/service/";
EndProcedure

Procedure ProcessException(ErrorInformation, ErrorText = Undefined, RunDiagnostics = False, WebService = Undefined)
	
	WriteLogEvent(
		NStr("ru = 'Отправка SMS'; en = 'Text messaging'; pl = 'Wysyłanie wiadomości SMS';es_ES = 'SMS';es_CO = 'SMS';tr = 'SMS Mesajlaması';it = 'Messaggistica di testo';de = 'Senden von Textnachrichten'", CommonClientServer.DefaultLanguageCode()),
		EventLogLevel.Error,
		,
		,
		DetailErrorDescription(ErrorInformation));
	
	ErrorCode = ErrorCodeFromDetails(DetailErrorDescription(ErrorInformation));
	
	If ErrorCode = Undefined Then 
		
		If RunDiagnostics Then 
			EndpointAddress = WebService.Endpoint.Location;
			DiagnosticsResult = CommonClientServer.ConnectionDiagnostics(EndpointAddress);
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '%1
				           |
				           |Результат диагностики:
				           |%2'; 
				           |en = '%1
				           |
				           |Diagnostics result:
				           |%2'; 
				           |pl = '%1
				           |
				           |Wynik diagnostyki:
				           |%2';
				           |es_ES = '%1
				           |
				           |Resultado de diagnóstica:
				           |%2';
				           |es_CO = '%1
				           |
				           |Resultado de diagnóstica:
				           |%2';
				           |tr = '%1
				           |
				           |Teşhis sonucu:
				           |%2';
				           |it = '%1
				           |
				           |Risultato diagnostica:
				           |%2';
				           |de = '%1
				           |
				           |Ergebnis der Diagnose:
				           |%2'"),
				BriefErrorDescription(ErrorInformation),
				DiagnosticsResult.ErrorDetails);
		Else 
			ErrorText = BriefErrorDescription(ErrorInformation);
		EndIf;
		
	Else 
		ErrorText = ErrorDetailsByCode(ErrorCode);
	EndIf;
	
EndProcedure

#EndRegion
