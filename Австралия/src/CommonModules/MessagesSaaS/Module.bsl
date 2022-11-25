#Region Public

// Returns a new message.
//
// Parameters:
//  MessageBodyType - XDTOObjectType - body type for the message to be created.
//
// Returns:
//  XDTODataObject - object of the specified type.
Function NewMessage(Val MessageBodyType) Export
	
	Message = XDTOFactory.Create(MessagesSaaSCached.MessageType());
	
	Message.Header = XDTOFactory.Create(MessagesSaaSCached.MessageTitleType());
	Message.Header.Id = New UUID;
	Message.Header.Created = CurrentUniversalDate();
	
	Message.Body = XDTOFactory.Create(MessageBodyType);
	
	Return Message;
	
EndFunction

// Sends a message.
//
// Parameters:
//  Message - XDTODataObject - a message.
//  Recipient - ExchangePlanRef.MessageExchange - message recipient.
//  Now - Boolean - flag specifying whether the message will be sent through the quick message delivery.
//
Procedure SendMessage(Val Message, Val Recipient = Undefined, Val Now = False) Export
	
	Message.Header.Sender = MessageExchangeNodeDescription(ExchangePlans.MessageExchange.ThisNode());
	
	If ValueIsFilled(Recipient) Then
		Message.Header.Recipient = MessageExchangeNodeDescription(Recipient);
	EndIf;
	
	SettingsStructure = InformationRegisters.MessageExchangeTransportSettings.TransportSettingsWS(Recipient);
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("URL",      SettingsStructure.WSWebServiceURL);
	ConnectionParameters.Insert("UserName", SettingsStructure.WSUsername);
	ConnectionParameters.Insert("Password", SettingsStructure.WSPassword);

	TranslateMessageToCorrespondentVersionIfNecessary(
		Message, 
		ConnectionParameters,
		String(Recipient));
	
	UntypedBody = WriteMessageToUntypedBody(Message);
	
	MessagesChannel = ChannelNameByMessageType(Message.Body.Type());
	
	If Now Then
		MessageExchange.SendMessageImmediately(MessagesChannel, UntypedBody, Recipient);
	Else
		MessageExchange.SendMessage(MessagesChannel, UntypedBody, Recipient);
	EndIf;
	
EndProcedure

// Gets a list of message handlers by namespace.
// 
// Parameters:
//  Handlers - ValueTable - with the following columns:
//    * Channel - String - a message channel.
//    * Handler - CommonModule - a message handler.
//  Namespace - String - URL of a namespace that has message body types defined.
//  CommonModule - CommonModule - common module containing message handlers.
// 
Procedure GetMessageChannelHandlers(Val Handlers, Val Namespace, Val CommonModule) Export
	
	ChannelNames = MessagesSaaSCached.GetPackageChannels(Namespace);
	
	For each ChannelName In ChannelNames Do
		Handler = Handlers.Add();
		Handler.Canal = ChannelName;
		Handler.Handler = CommonModule;
	EndDo;
	
EndProcedure

// Returns a name of message channel matching the message type.
//
// Parameters:
//  MessageType - XDTOObjectType - remote administration message type.
//
// Returns:
//  String - name of a message channel matching the sent message type.
//
Function ChannelNameByMessageType(Val MessageType) Export
	
	Return XDTOSerializer.XMLString(New XMLExpandedName(MessageType.NamespaceURI, MessageType.Name));
	
EndFunction

// Returns remote administration message type by the message channel name.
// 
//
// Parameters:
//  ChannelName - String - name of a message channel matching the sent message type.
//
// Returns:
//  XDTOObjectType - remote administration message type.
//
Function MessageTypeByChannelName(Val ChannelName) Export
	
	Return XDTOFactory.Type(XDTOSerializer.XMLValue(Type("XMLExpandedName"), ChannelName));
	
EndFunction

// Raises an exception when a message is received in an unknown channel.
//
// Parameters:
//  MessageChannel - String - name of unknown message channel.
//
Procedure UnknownChannelNameError(Val MessagesChannel) Export
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Неизвестное имя канала сообщений %1'; en = 'Unknown message channel name %1'; pl = 'Nieznana nazwa kanału wiadomości %1';es_ES = 'Nombre del canal de mensajes desconocido %1';es_CO = 'Nombre del canal de mensajes desconocido %1';tr = 'Bilinmeyen mesaj kanalı adı%1';it = 'Nome del canale del messaggio sconosciuto %1';de = 'Unbekannter Nachrichtenkanalname %1'"), MessagesChannel);
	
EndProcedure

// Reads a message from the untyped message body.
//
// Parameters:
//  UntypedBody - String - untyped message body.
//
// Returns:
//  {http://www.1c.ru/SaaS/Messages}Message - message.
//
Function ReadMessageFromUntypedBody(Val UntypedBody) Export
	
	Read = New XMLReader;
	Read.SetString(UntypedBody);
	
	Message = XDTOFactory.ReadXML(Read, MessagesSaaSCached.MessageType());
	
	Read.Close();
	
	Return Message;
	
EndFunction

// Writes a message to the untyped message body.
//
// Parameters:
//  Message - Message - {http://www.1c.ru/SaaS/Messages}Message message type.
//
// Returns:
//  String - untyped message body.
//
Function WriteMessageToUntypedBody(Val Message) Export
	
	Record = New XMLWriter;
	Record.SetString();
	XDTOFactory.WriteXML(Record, Message, , , , XMLTypeAssignment.Explicit);
	
	Return Record.Close();
	
EndFunction

// Writes a message processing start event to the event log.
//
// Parameters:
//  Message - Message - {http://www.1c.ru/SaaS/Messages}Message message type.
//
Procedure WriteProcessingStartEvent(Val Message) Export
	
	WriteLogEvent(NStr("ru = 'Сообщения в модели сервиса.Начало обработки'; en = 'Messages SaaS.Start processing'; pl = 'Komunikaty SaaS. Rozpoczęcie przetwarzania';es_ES = 'Mensajes SaaS. Iniciar el procesamiento';es_CO = 'Mensajes SaaS. Iniciar el procesamiento';tr = 'SaaS mesajları. İşleme başlama';it = 'Messaggio SaaS. Inizio elaborazione';de = 'SaaS-Nachrichten. Starten Sie die Verarbeitung'",
		CommonClientServer.DefaultLanguageCode()),
		EventLogLevel.Information,
		,
		,
		MessagePresentationForLog(Message));
	
EndProcedure

// Writes a message processing end event to the event log.
//
// Parameters:
//  Message - Message - {http://www.1c.ru/SaaS/Messages}Message message type.
//
Procedure WriteProcessingEndEvent(Val Message) Export
	
	WriteLogEvent(NStr("ru = 'Сообщения в модели сервиса.Окончание обработки'; en = 'Messages SaaS.End processing'; pl = 'Komunikaty SaaS. Koniec przetwarzania';es_ES = 'Mensajes SaaS. Finalizar el procesamiento';es_CO = 'Mensajes SaaS. Finalizar el procesamiento';tr = 'SaaS mesajları. İşlem sonu';it = 'Messaggi SaaS. Fine elaborazione';de = 'SaaS-Nachrichten. Bearbeitung beenden'",
		CommonClientServer.DefaultLanguageCode()),
		EventLogLevel.Information,
		,
		,
		MessagePresentationForLog(Message));
	
EndProcedure

// Performs quick message delivery.
//
Procedure DeliverQuickMessages() Export
	
	If TransactionActive() Then
		Raise(NStr("ru = 'Доставка быстрых сообщений невозможна в транзакции'; en = 'Quick message delivery is not available during transaction'; pl = 'Wysyłanie wiadomości błyskawicznych nie jest dostępna w transakcji';es_ES = 'Envío rápido de mensajes no está disponible en la transacción';es_CO = 'Envío rápido de mensajes no está disponible en la transacción';tr = 'Hızlı mesaj teslimi işlemlerde mevcut değil';it = 'L''invio di messaggio rapidi di sistema non è disponibile durante la transazione';de = 'Schnellnachrichtenübermittlung ist in der Transaktion nicht verfügbar'"));
	EndIf;
	
	JobMethodName = "MessageExchange.DeliverMessages";
	JobKey = 1;
	
	SetPrivilegedMode(True);
	
	JobsFilter = New Structure;
	JobsFilter.Insert("MethodName", JobMethodName);
	JobsFilter.Insert("Key", JobKey);
	JobsFilter.Insert("State", BackgroundJobState.Active);
	
	Jobs = BackgroundJobs.GetBackgroundJobs(JobsFilter);
	If Jobs.Count() > 0 Then
		Try
			Jobs[0].WaitForCompletion(3);
		Except
			
			Job = BackgroundJobs.FindByUUID(Jobs[0].UUID);
			If Job.State = BackgroundJobState.Failed
				AND Job.ErrorInfo <> Undefined Then
				
				Raise(DetailErrorDescription(Job.ErrorInfo));
			EndIf;
			
			Return;
		EndTry;
	EndIf;
		
	Try
		BackgroundJobs.Execute(JobMethodName, , JobKey, NStr("ru = 'Доставка быстрых сообщений'; en = 'Quick message delivery'; pl = 'Wysyłanie wiadomości błyskawicznych';es_ES = 'Envío de mensajes instante';es_CO = 'Envío de mensajes instante';tr = 'Anında mesaj teslimi';it = 'Consegna messaggio rapido';de = 'Sofortige Nachrichtenübermittlung'"))
	Except
		// Additional exception processing is not required. The expected exception is duplicating a job with 
		// identical key.
		WriteLogEvent(NStr("ru = 'Доставка быстрых сообщений'; en = 'Quick message delivery'; pl = 'Wysyłanie wiadomości błyskawicznych';es_ES = 'Envío de mensajes instante';es_CO = 'Envío de mensajes instante';tr = 'Anında mesaj teslimi';it = 'Consegna messaggio rapido';de = 'Sofortige Nachrichtenübermittlung'",
			CommonClientServer.DefaultLanguageCode()), EventLogLevel.Error, , ,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

// Returns XDTO type - message.
//
// Returns:
//  XDTOObjectType - message type.
//
Function MessageType() Export
	
	Return MessagesSaaSCached.MessageType();
	
EndFunction

// Returns base type for all body types of messages SaaS.
// 
//
// Returns:
//  XDTOObjectType - base body type for messages SaaS.
//
Function TypeBody() Export
	
	Return MessagesSaaSCached.TypeBody();
	
EndFunction

// Returns base type for all body types of data area messages SaaS.
// 
//
// Returns:
//  XDTOObjectType - base body type for data area messages SaaS.
//
Function AreaBodyType() Export
	
	Return MessagesSaaSCached.AreaBodyType();
	
EndFunction

// Returns base type for all body types of data area messages with area authentication SaaS.
// 
//
// Returns:
//  XDTOObjectType - base body type for data area messages with authentication SaaS.
//   
//
Function AuthentifiedAreaBodyType() Export
	
	Return MessagesSaaSCached.AuthentifiedAreaBodyType();
	
EndFunction

// Returns type - message title.
//
// Returns:
//  XDTOObjectType - message SaaS title type.
//
Function MessageTitleType() Export
	
	Return MessagesSaaSCached.MessageTitleType();
	
EndFunction

// Returns type - message SaaS exchange node.
//
// Returns:
//  XDTOObjectType - message SaaS exchange node type.
//
Function MessageExchangeNodeType() Export
	
	Return MessagesSaaSCached.MessageExchangeNodeType();
	
EndFunction

// Returns types of XDTO objects in the package that match the remote administration message types.
// 
//
// Parameters:
//  PackageURL - String - URL of XDTO package whose message types to be received.
//   
//
// Returns:
//  FixedArray(XDTOObjectType) - message types in the package.
//
Function GetPackageMessageTypes(Val PackageURL) Export
	
	Return MessagesSaaSCached.GetPackageMessageTypes(PackageURL);
	
EndFunction

// Returns the message channel names used in a specified package.
//
// Parameters:
//  PackageURL - String - URL of XDTO package whose message types to be received.
//   
//
// Returns:
//  FixedArray(String) - channel names in the package.
//
Function GetPackageChannels(Val PackageURL) Export
	
	Return MessagesSaaSCached.GetPackageChannels(PackageURL);
	
EndFunction

#EndRegion

#Region Internal

// "Before send message" event handler.
// This event handler is called before writing a message to be sent.
// The handler is called separately for each message to be sent.
//
//  Parameters:
// MessageChannel - String - an ID of a message channel used to receive the message.
// MessageBody - Arbitrary - body of the message to be written.
//
Procedure MessagesBeforeSend(Val MessagesChannel, Val MessageBody) Export
	
	If Not SaaS.SessionSeparatorUsage() Then
		Return;
	EndIf;
	
	Message = Undefined;
	If BodyContainsTypedMessage(MessageBody, Message) Then
		If MessagesSaaSCached.AreaBodyType().IsDescendant(Message.Body.Type()) Then
			If SaaS.SessionSeparatorValue() <> Message.Body.Zone Then
				WriteLogEvent(NStr("ru = 'Сообщения в модели сервиса.Отправка сообщения'; en = 'Messages SaaS.Sending message'; pl = 'Komunikaty SaaS. Wiadomość e-mail';es_ES = 'Mensajes SaaS.Mensaje de correo electrónico';es_CO = 'Mensajes SaaS.Mensaje de correo electrónico';tr = 'SaaS mesajları. Mesaj e-posta ile gönder';it = 'Messaggi SaaS.Invio messaggio';de = 'SaaS-Nachrichten. E-Mail- Nachricht'",
					CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					,
					,
					MessagePresentationForLog(Message));
					
				ErrorTemplate = NStr("ru = 'Ошибка при отправке сообщения. Область данных %1 не совпадает с текущей (%2).'; en = 'An error occurred when sending the message. Data area %1 does not match the current one (%2).'; pl = 'Podczas wysyłania wiadomości wystąpił błąd. Obszar danych %1 nie odpowiada bieżącemu (%2).';es_ES = 'Ha ocurrido un error al enviar el mensaje. Área de datos %1 no coincide con la actual (%2).';es_CO = 'Ha ocurrido un error al enviar el mensaje. Área de datos %1 no coincide con la actual (%2).';tr = 'Mesaj gönderilirken hata oluştu. %1 veri alanı mevcut olanla (%2) uyuşmuyor.';it = 'Si è verificato un errore durante l''invio del messaggio. L''area dati %1 non corrisponde a quella corrente (%2).';de = 'Beim Senden der Nachricht ist ein Fehler aufgetreten. Datenbereich %1 stimmt nicht mit dem aktuellen überein (%2).'");
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate,
					Message.Body.Zone, SaaS.SessionSeparatorValue());
					
				Raise(ErrorText);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// "On send message" event handler.
// This event handler is called before a message is sent to an XML data stream.
// The handler is called separately for each message to be sent.
//
//  Parameters:
// MessageChannel - String - ID of a message channel used to receive the message.
// MessageBody - Arbitrary - body of outgoing message. In this event handler, message body can be 
//    modified (for example, new data added).
//
Procedure OnSendMessage(MessagesChannel, MessageBody, MessageObject) Export
	
	Message = Undefined;
	If BodyContainsTypedMessage(MessageBody, Message) Then
		
		Message.Header.Sent = CurrentUniversalDate();
		MessageBody = WriteMessageToUntypedBody(Message);
		
		WriteLogEvent(NStr("ru = 'Сообщения в модели сервиса.Отправка'; en = 'Messages SaaS.Sending'; pl = 'Wiadomości SaaS. Wysyłanie';es_ES = 'Mensajes SaaS.Enviar';es_CO = 'Mensajes SaaS.Enviar';tr = 'SaaS mesajları. Gönderme';it = 'Messaggi SaaS.Invio';de = 'SaaS-Nachrichten. Senden'",
			CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Information,
			,
			,
			MessagePresentationForLog(Message));
		
	EndIf;
	
	If SaaSCached.IsSeparatedConfiguration() Then
		
		ModuleMessagesSaaSDataSeparation = Common.CommonModule("MessagesSaaSDataSeparation");
		ModuleMessagesSaaSDataSeparation.OnSendMessage(MessagesChannel, MessageBody, MessageObject);
		
	EndIf;
	
	MessagesSaaSOverridable.OnSendMessage(MessagesChannel, MessageBody, MessageObject);
	
EndProcedure

// "On receive message" event handler.
// This event handler is called after a message is received from an XML data stream.
// The handler is called separately for each received message.
//
//  Parameters:
// MessageChannel - String - an ID of a message channel used to receive the message.
// MessageBody - Arbitrary - body of received message. In this event handler, message body can be 
//    modified (for example, new data added).
//
Procedure OnReceiveMessage(MessagesChannel, MessageBody, MessageObject) Export
	
	Message = Undefined;
	If BodyContainsTypedMessage(MessageBody, Message) Then
		
		Message.Header.Delivered = CurrentUniversalDate();
		
		MessageBody = WriteMessageToUntypedBody(Message);
		
		WriteLogEvent(NStr("ru = 'Сообщения в модели сервиса.Получение'; en = 'Messages SaaS.Receiving'; pl = 'Wiadomości SaaS. Odbiór';es_ES = 'Mensajes SaaS.Recibir';es_CO = 'Mensajes SaaS.Recibir';tr = 'SaaS mesajları. Alma';it = 'Messaggi SaaS.Ricezione';de = 'SaaS-Nachrichten. Empfangen'",
			CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Information,
			,
			,
			MessagePresentationForLog(Message));
		
	EndIf;
	
	If SaaSCached.IsSeparatedConfiguration() Then
		
		ModuleMessagesSaaSDataSeparation = Common.CommonModule("MessagesSaaSDataSeparation");
		ModuleMessagesSaaSDataSeparation.OnReceiveMessage(MessagesChannel, MessageBody, MessageObject);
		
	EndIf;
	
	MessagesSaaSOverridable.OnReceiveMessage(MessagesChannel, MessageBody, MessageObject);
	
EndProcedure

Function MessageExchangeNodeDescription(Val Node)
	
	Attributes = Common.ObjectAttributesValues(
		Node,
		New Structure("Code, Description"));
	
	Details = XDTOFactory.Create(MessagesSaaSCached.MessageExchangeNodeType());
	Details.Code = Attributes.Code;
	Details.Presentation = Attributes.Description;
	
	Return Details;
	
EndFunction

// For internal use.
//
Function BodyContainsTypedMessage(Val UntypedBody, Message) Export
	
	If TypeOf(UntypedBody) <> Type("String") Then
		Return False;
	EndIf;
	
	If Not StrStartsWith(UntypedBody, "<") OR Not StrEndsWith(UntypedBody, ">") Then
		Return False;
	EndIf;
	
	Try
		Read = New XMLReader;
		Read.SetString(UntypedBody);
		
		Message = XDTOFactory.ReadXML(Read);
		
		Read.Close();
		
	Except
		Return False;
	EndTry;
	
	Return Message.Type() = MessagesSaaSCached.MessageType();
	
EndFunction

Function MessagePresentationForLog(Val Message)
	
	Template = NStr("ru = 'Канал: %1'; en = 'Channel: %1'; pl = 'Kanał: %1';es_ES = 'Canal: %1';es_CO = 'Canal: %1';tr = 'Kanal: %1';it = 'Canale: %1';de = 'Kanal: %1'", CommonClientServer.DefaultLanguageCode());
	Presentation = StringFunctionsClientServer.SubstituteParametersToString(Template, ChannelNameByMessageType(Message.Body.Type()));
	
	Record = New XMLWriter;
	Record.SetString();
	XDTOFactory.WriteXML(Record, Message.Header, , , , XMLTypeAssignment.Explicit);
	
	Template = NStr("ru = 'Заголовок:
		|%1'; 
		|en = 'Title:
		|%1'; 
		|pl = 'Nagłówek:
		|%1';
		|es_ES = 'Título:
		|%1';
		|es_CO = 'Título:
		|%1';
		|tr = 'Başlık:
		|%1';
		|it = 'Titolo:
		|%1';
		|de = 'Überschrift:
		|%1'", CommonClientServer.DefaultLanguageCode());
	Presentation = Presentation + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(Template, Record.Close());
		
	If MessagesSaaSCached.AreaBodyType().IsDescendant(Message.Body.Type()) Then
		Template = NStr("ru = 'Область данных: %1'; en = 'Data area: %1'; pl = 'Obszar danych: %1';es_ES = 'Área de datos: %1';es_CO = 'Área de datos: %1';tr = 'Veri alanı: %1';it = 'Area dati: %1';de = 'Datenbereich: %1'", CommonClientServer.DefaultLanguageCode());
		Presentation = Presentation + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(Template, Format(Message.Body.Zone, "NZ=0; NG="));
	EndIf;
		
	Return Presentation;
	
EndFunction

// Translates the message to be sent to a version supported by the correspondent infobase.
//
// Parameters:
//  Message: XDTODataObject, message to be sent.
//  ConnectionInformation - structure, correspondent infobase connection parameters.
//  RecipientPresentation - string, recipient infobase presentation.
//
// Returns:
//  XDTODataObject - message translated to the recipient infobase version.
//
Procedure TranslateMessageToCorrespondentVersionIfNecessary(Message, Val ConnectionInformation, Val RecipientPresentation)
	
	MessageInterface = XDTOTranslationInternal.GetMessageInterface(Message);
	If MessageInterface = Undefined Then
		Raise NStr("ru = 'Не удалось определить интерфейс отправляемого сообщения: ни для одного из типов, используемых в сообщении, не зарегистрирован обработчик интерфейса.'; en = 'Cannot define an interface of the message being sent: interface handler is not registered for any type used in the message.'; pl = 'Nie można zdefiniować interfejsu wysyłanego komunikatu: procedura obsługi interfejsu nie jest zarejestrowana dla żadnego typu używanego w komunikacie.';es_ES = 'No se puede definir una interfaz del mensaje que se está enviando: manipulador de interfaces no está registrado para ningún tipo utilizado en el mensaje.';es_CO = 'No se puede definir una interfaz del mensaje que se está enviando: manipulador de interfaces no está registrado para ningún tipo utilizado en el mensaje.';tr = 'Gönderilen mesajın bir arayüzü tanımlanamıyor: mesajda kullanılan herhangi bir tür için arayüz işleyici kayıtlı değil.';it = 'Non è possibile definire un''interfaccia del messaggio inviato: gestore di interfaccia non è registrato per qualsiasi tipo usato nel messaggio.';de = 'Die Schnittstelle der gesendeten Nachricht kann nicht definiert werden: Der Schnittstellenhandler ist für keinen der in der Nachricht verwendeten Typen registriert.'");
	EndIf;
	
	If Not ConnectionInformation.Property("URL") 
			Or Not ValueIsFilled(ConnectionInformation.URL) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не задан URL сервиса обмена сообщениями с информационной базой %1'; en = 'URL for service performing message exchange with infobase %1 is not specified'; pl = 'Adres URL serwisu wymiany komunikatów z bazą informacyjną %1 nie jest określony.';es_ES = 'URL del servicio del intercambio de mensajes con la infobase %1 no está especificado';es_CO = 'URL del servicio del intercambio de mensajes con la infobase %1 no está especificado';tr = '%1Veritabanı ile mesaj alışverişinin servisinin URL''si belirtilmemiş';it = 'URL del servizio di scambio messaggi con infobase %1 non è specificato';de = 'Die URL für den Service, der den Nachrichtenaustausch mit der Infobase %1 durchführt, ist nicht angegeben.'"), RecipientPresentation);
	EndIf;
	
	CorrespondentVersion = MessageInterfacesSaaS.CorrespondentInterfaceVersion(
			MessageInterface.Public, ConnectionInformation, RecipientPresentation);
	
	If CorrespondentVersion = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Корреспондент %1 не поддерживает получение версий сообщений интерфейса %2, поддерживаемых текущей информационной базой.'; en = 'Correspondent %1 does not support receiving versions of interface %2 messages supported by the current infobase.'; pl = 'Korespondent %1 nie obsługuje odbierania wersji komunikatów interfejsu %2 obsługiwanych przez bieżącą bazę informacyjną';es_ES = 'Corresponsal %1 no admite las versiones de recepción de los mensajes %2 de la interfaz admitidos por la infobase actual.';es_CO = 'Corresponsal %1 no admite las versiones de recepción de los mensajes %2 de la interfaz admitidos por la infobase actual.';tr = 'Muhabir%1, mevcut veritabanı tarafından desteklenen arayüz mesajlarının %2alım sürümlerini desteklememektedir.';it = 'Il corrispondente %1 non supporta la ricezione versioni di interfaccia %2 messaggi supportati dal infobase corrente.';de = 'Korrespondent %1 unterstützt nicht das Empfangen von Versionen von Schnittstellen%2nachrichten, die von der aktuellen Infobase unterstützt werden.'"),
			RecipientPresentation, MessageInterface.Public);
	EndIf;
	
	VersionToSend = MessageInterfacesSaaS.GetOutgoingMessageVersions().Get(MessageInterface.Public);
	If VersionToSend = CorrespondentVersion Then
		Return;
	EndIf;
	
	Message = XDTOTranslation.TranslateToVersion(Message, CorrespondentVersion, MessageInterface.Namespace);
	
EndProcedure

#EndRegion
