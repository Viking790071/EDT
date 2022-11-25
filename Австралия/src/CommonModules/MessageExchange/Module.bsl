#Region Public

// Sends a message to a targeted message channel.
// Corresponds to the "endpoint/endpoint" delivery type.
//
// Parameters:
//  MessageChannel - String - targeted message channel ID.
//  MessageBody - Arbitrary - body of the system message to be delivered.
//  Recipient - Undefined - message recipient is not specified. The message will be sent to 
//                              endpoints determined by the current information system settings:
//                              both the MessageExchangeOverridable.MessageRecipients handler (on 
//                              application level) and the SenderSettings information register (on system settings level).
//             - ExchangePlanRef.MessageExchange - exchange plan node matching the message recipient 
//                                                   endpoint. The message is delivered to the 
//                                                   specified endpoint.
//             - Array - array of message recipient names; all array items must conform to ExchangePlanRef.MessageExchange type.
//                        The message is delivered to all endpoints listed in the array.
//
Procedure SendMessage(MessagesChannel, MessageBody = Undefined, Recipient = Undefined) Export
	
	SendMessageToMessageChannel(MessagesChannel, MessageBody, Recipient);
	
EndProcedure

// Sends a message to a targeted message channel.
// Corresponds to the "endpoint/endpoint" delivery type.
//
// Parameters:
//  MessageChannel - String - targeted message channel ID.
//  MessageBody - Arbitrary - body of the system message to be delivered.
//  Recipient - Undefined - message recipient is not specified. The message will be sent to 
//                              endpoints determined by the current information system settings:
//                              both the MessageExchangeOverridable.MessageRecipients handler (on 
//                              application level) and the SenderSettings information register (on system settings level).
//             - ExchangePlanRef.MessageExchange - exchange plan node matching the message recipient 
//                                                   endpoint. The message is delivered to the 
//                                                   specified endpoint.
//             - Array - array of message recipient names; all array items must conform to ExchangePlanRef.MessageExchange type.
//                        The message is delivered to all endpoints listed in the array.
//
Procedure SendMessageImmediately(MessagesChannel, MessageBody = Undefined, Recipient = Undefined) Export
	
	SendMessageToMessageChannel(MessagesChannel, MessageBody, Recipient, True);
	
EndProcedure

// Sends a message to a broadcast message channel.
// Corresponds to the "publication/subscription" delivery type.
// The message is delivered to all endpoints that subscribe to the broadcast channel.
// RecipientSubscriptions information register is used for broadcast channel subscription management.
//
// Parameters:
//  MessageChannel - String - broadcast message channel ID.
//  MessageBody - Arbitrary - body of the system message to be delivered.
//
Procedure SendMessageToSubscribers(MessagesChannel, MessageBody = Undefined) Export
	
	SendMessageToSubscribersInMessageChannel(MessagesChannel, MessageBody);
	
EndProcedure

// Sends a quick message to a broadcast message channel.
// Corresponds to the "publication/subscription" delivery type.
// The message is delivered to all endpoints that subscribe to the broadcast channel.
// RecipientSubscriptions information register is used for broadcast channel subscription management.
//
// Parameters:
//  MessageChannel - String - broadcast message channel ID.
//  MessageBody - Arbitrary - body of the system message to be delivered.
//
Procedure SendMessageToSubscribersImmediately(MessagesChannel, MessageBody = Undefined) Export
	
	SendMessageToSubscribersInMessageChannel(MessagesChannel, MessageBody, True);
	
EndProcedure

// Immediately sends quick messages from the common message queue.
// Message delivery cycle continues until all quick messages in the message queue are delivered.
// 
// Immediate message delivery for other sessions is blocked until this message delivery is completed.
//
Procedure DeliverMessages() Export
	
	If TransactionActive() Then
		Raise NStr("ru = 'Доставка быстрых сообщений системы не может выполняться в активной транзакции.'; en = 'Quick system message delivery is not available in active transactions.'; pl = 'Nie można odebrać szybkich komunikatów systemowych w aktywnej transakcji.';es_ES = 'Usted no puede recibir mensajes rápidos del sistema en una transacción activa.';es_CO = 'Usted no puede recibir mensajes rápidos del sistema en una transacción activa.';tr = 'Etkin bir işlemde hızlı sistem mesajları alamazsınız.';it = 'L''invio di messaggi rapidi di sistema non è disponibile nelle transazioni attive.';de = 'Sie können keine schnellen Systemmeldungen in einer aktiven Transaktion erhalten.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not StartSendingInstantMessages() Then
		Return;
	EndIf;
	
	QueryText = "";
	MessageCatalogs = MessagesExchangeCached.GetMessageCatalogs();
	For Each CatalogMessage In MessageCatalogs Do
		
		IsFirstFragment = IsBlankString(QueryText);
		
		If Not IsFirstFragment Then
			
			QueryText = QueryText + "
			|
			|UNION ALL
			|"
			
		EndIf;
		
		QueryText = QueryText
			+ "SELECT
			|	ChangesTable.Node AS Endpoint,
			|	ChangesTable.Ref AS Message
			|[INTO]
			|FROM
			|	[CatalogMessage].Changes AS ChangesTable
			|WHERE
			|	ChangesTable.Ref.IsInstantMessage
			|	AND ChangesTable.MessageNo IS NULL
			|	AND NOT ChangesTable.Node IN (&UnavailableEndpoints)";
		
		QueryText = StrReplace(QueryText, "[CatalogMessage]", CatalogMessage.EmptyRef().Metadata().FullName());
		If IsFirstFragment Then
			QueryText = StrReplace(QueryText, "[INTO]", "INTO TT_Changes");
		Else
			QueryText = StrReplace(QueryText, "[INTO]", "");
		EndIf;		
	EndDo;
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Changes.Endpoint AS Endpoint,
	|	TT_Changes.Message
	|FROM
	|	TT_Changes AS TT_Changes
	|
	|ORDER BY
	|	TT_Changes.Message.Code
	|TOTALS BY
	|	Endpoint";
	
	Query = New Query;
	Query.Text = QueryText;
	
	UnavailableEndpoints = New Array;
	
	Try
		
		While True Do
			
			Query.SetParameter("UnavailableEndpoints", UnavailableEndpoints);
			
			QueryResult = SaaS.ExecuteQueryOutsideTransaction(Query);
			
			If QueryResult.IsEmpty() Then
				Break;
			EndIf;
			
			Groups = QueryResult.Unload(QueryResultIteration.ByGroupsWithHierarchy);
			
			For Each Folder In Groups.Rows Do
				
				Messages = Folder.Rows.UnloadColumn("Message");
				
				Try
					
					DeliverMessagesToRecipient(Folder.Endpoint, Messages);
					
					DeleteChangesRegistration(Folder.Endpoint, Messages);
					
				Except
					
					UnavailableEndpoints.Add(Folder.Endpoint);
					
					WriteLogEvent(MessageExchangeInternal.ThisSubsystemEventLogMessageText(),
											EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
				EndTry;
				
			EndDo;
			
		EndDo;
		
	Except
		CancelSendingInstantMessages();
		Raise;
	EndTry;
	
	FinishSendingInstantMessages();
	
EndProcedure

// Establishes endpoint connection.
// Prior to establishing endpoint connection, both sender-to-recipient and recipient-to-sender 
// connections are checked.
// It is also verified whether the current sender is correctly specified in the recipient connection settings.
//
// Parameters:
//  Cancel - Boolean - flag specifying whether any errors occur during endpoint connection.
//  SenderConnectionSettings - Structure - sender connection parameters. The DataExchangeServer.
//                                    WSParameterStructure function is used for initialization. Contains the following properties:
//    * WSURL - String - URL of the endpoint to be connected.
//    * WSUserName - Name of the user to be authenticated at the endpoint to be connected when 
//                          working via the message exchange subsystem web service.
//    * WSPassword - user password in the endpoint to be connected.
//  RecipientConnectionSettings - Structure - recipient connection parameters. The 
//                                   DataExchangeServer.WSParameterStructure function is used for initialization. Contains the following properties:
//    * WSURL - String - URL of the infobase from the endpoint to be connected.
//    * WSUserName - name of the user to be authenticated at the infobase when working via the 
//                          message exchange subsystem web service.
//    * WSPassword - user password for this infobase.
//  Endpoint - ExchangePlanRef.MessageExchange, Undefined - if endpoint connection is successful, 
//                  returns a reference to the exchange plan node matching the connected endpoint.
//                  
//                  If endpoint connection is unsuccessful, returns Undefined.
//  RecipientEndpointDescription - String - description of the endpoint to be connected. If not 
//                                        specified, the endpoint configuration synonym is used.
//                                        
//  SenderEndpointDescription - String - description of the endpoint corresponding to this infobase.
//                                         If not specified, the infobase configuration synonym is 
//                                        used.
//
Procedure ConnectEndpoint(Cancel,
									SenderConnectionSettings,
									RecipientConnectionSettings,
									Endpoint = Undefined,
									RecipientEndpointDescription = "",
									SenderEndpointDescription = "") Export
	
	MessageExchangeInternal.ConnectEndpointAtSender(Cancel, 
														SenderConnectionSettings,
														RecipientConnectionSettings,
														Endpoint,
														RecipientEndpointDescription,
														SenderEndpointDescription);
	
EndProcedure

// Updates connection parameters for an endpoint.
// Both infobase-to-endpoint and endpoint-to-infobase connection settings are updated.
// 
// Before applying the connection settings, they are validated.
// It is also verified whether the current sender is correctly specified in the recipient connection settings.
//
// Parameters:
//  Cancel - Boolean - flag specifying whether any errors have occurred.
//  Endpoint - ExchangePlanRef.MessageExchange - reference to an exchange plan node matching the 
//                                                      endpoint.
//  SenderConnectionSettings - Structure - sender connection parameters. The DataExchangeServer.
//                                    WSParameterStructure function is used for initialization. Contains the following properties:
//    * WSURL - String - URL of the endpoint to be connected.
//    * WSUserName - Name of the user to be authenticated at the endpoint to be connected when 
//                          working via the message exchange subsystem web service.
//    * WSPassword - user password in the endpoint to be connected.
//  RecipientConnectionSettings - Structure - recipient connection parameters. The 
//                                   DataExchangeServer.WSParameterStructure function is used for initialization. Contains the following properties:
//    * WSURL - String - URL of the infobase from the endpoint to be connected.
//    * WSUserName - name of the user to be authenticated at the infobase when working via the 
//                          message exchange subsystem web service.
//    * WSPassword - user password for this infobase.
//
Procedure UpdateEndpointConnectionSettings(Cancel,
									Endpoint,
									SenderConnectionSettings,
									RecipientConnectionSettings) Export
	
	MessageExchangeInternal.UpdateEndpointConnectionParameters(Cancel, Endpoint, SenderConnectionSettings, RecipientConnectionSettings);
	
EndProcedure

#EndRegion

#Region Private

Procedure SendMessageToMessageChannel(MessagesChannel, MessageBody, Recipient, IsInstantMessage = False)
	
	If TypeOf(Recipient) = Type("ExchangePlanRef.MessageExchange") Then
		
		SendMessageToRecipient(MessagesChannel, MessageBody, Recipient, IsInstantMessage);
		
	ElsIf TypeOf(Recipient) = Type("Array") Then
		
		For Each Item In Recipient Do
			
			If TypeOf(Item) <> Type("ExchangePlanRef.MessageExchange") Then
				
				Raise NStr("ru = 'Указан неправильный получатель для метода MessageExchange.SendMessage().'; en = 'Invalid recipient is specified for MessageExchange method.SendMessage().'; pl = 'W metodzie MessageExchange wskazano nieprawidłowego odbiorcę.SendMessage().';es_ES = 'Destinatario incorrecto está especificado para el método MessagesExchange.SendMessage().';es_CO = 'Destinatario incorrecto está especificado para el método MessagesExchange.SendMessage().';tr = 'MessageExchange.SendMessage() yöntemi için yanlış alıcı belirtildi.';it = 'Il destinatario indicato non è valido per il metodo MessageExchange method.SendMessage().';de = 'Für den Nachrichtenaustausch wurde ein falscher Empfänger angegeben. NachrichtSenden() Methode.'");
				
			EndIf;
			
			SendMessageToRecipient(MessagesChannel, MessageBody, Item, IsInstantMessage);
			
		EndDo;
		
	ElsIf Recipient = Undefined Then
		
		SendMessageToRecipients(MessagesChannel, MessageBody, IsInstantMessage);
		
	Else
		
		Raise NStr("ru = 'Указан неправильный получатель для метода MessageExchange.SendMessage().'; en = 'Invalid recipient is specified for MessageExchange method.SendMessage().'; pl = 'W metodzie MessageExchange wskazano nieprawidłowego odbiorcę.SendMessage().';es_ES = 'Destinatario incorrecto está especificado para el método MessagesExchange.SendMessage().';es_CO = 'Destinatario incorrecto está especificado para el método MessagesExchange.SendMessage().';tr = 'MessageExchange.SendMessage() yöntemi için yanlış alıcı belirtildi.';it = 'Il destinatario indicato non è valido per il metodo MessageExchange method.SendMessage().';de = 'Für den Nachrichtenaustausch wurde ein falscher Empfänger angegeben. NachrichtSenden() Methode.'");
		
	EndIf;
	
EndProcedure

Procedure SendMessageToSubscribersInMessageChannel(MessagesChannel, MessageBody, IsInstantMessage = False)
	
	SetPrivilegedMode(True);
	
	Recipients = InformationRegisters.RecipientSubscriptions.MessageChannelSubscribers(MessagesChannel);
	
	// Sending message to a recipient (endpoint.
	For Each Recipient In Recipients Do
		
		SendMessageToRecipient(MessagesChannel, MessageBody, Recipient, IsInstantMessage);
		
	EndDo;
	
EndProcedure

Procedure SendMessageToRecipients(MessagesChannel, MessageBody, IsInstantMessage)
	Var DynamicallyAddedRecipients;
	
	SetPrivilegedMode(True);
	
	// List of message recipients obtained from information register.
	Recipients = InformationRegisters.SenderSettings.MessageChannelSubscribers(MessagesChannel);
	
	// List of message recipients obtained from code.
	MessagesExchangeOverridable.MessageRecipients(MessagesChannel, DynamicallyAddedRecipients);
	
	// Combining two arrays to create an array of unique recipients.
	// Using a temporary value table for this purpose.
	RecipientsTable = New ValueTable;
	RecipientsTable.Columns.Add("Recipient");
	For Each Recipient In Recipients Do
		RecipientsTable.Add().Recipient = Recipient;
	EndDo;
	
	If TypeOf(DynamicallyAddedRecipients) = Type("Array") Then
		
		For Each Recipient In DynamicallyAddedRecipients Do
			RecipientsTable.Add().Recipient = Recipient;
		EndDo;
		
	EndIf;
	
	RecipientsTable.GroupBy("Recipient");
	
	Recipients = RecipientsTable.UnloadColumn("Recipient");
	
	// Sending message to a recipient (endpoint.
	For Each Recipient In Recipients Do
		
		SendMessageToRecipient(MessagesChannel, MessageBody, Recipient, IsInstantMessage);
		
	EndDo;
	
EndProcedure

Procedure SendMessageToRecipient(MessagesChannel, MessageBody, Recipient, IsInstantMessage)
	
	SetPrivilegedMode(True);
	
	If Not TransactionActive() Then
		
		Raise NStr("ru = 'Отправка сообщений может выполняться только в транзакции.'; en = 'Message delivery is only available in transactions.'; pl = 'Wysyłanie wiadomości jest możliwe tylko w transakcji.';es_ES = 'Mensajes pueden enviarse solo en una transacción.';es_CO = 'Mensajes pueden enviarse solo en una transacción.';tr = 'Mesajlar sadece bir işlemde gönderilebilir.';it = 'La consegna del messaggio è disponibile solo nelle transazioni.';de = 'Nachrichten können nur in einer Transaktion gesendet werden.'");
		
	EndIf;
	
	If Not ValueIsFilled(MessagesChannel) Then
		
		Raise NStr("ru = 'Не задано значение параметра ""MessageChannel"" для метода MessageExchange.SendMessage.'; en = 'MessageChannel parameter value is not set for MessageExchange method.SendMessage.'; pl = 'Wartość parametru Recipient metody MessagesExchange.SendMessage nie jest określona.';es_ES = 'Valor del parámetro MessagesChannel no está especificado para el método MessagesExchange.SendMessage.';es_CO = 'Valor del parámetro MessagesChannel no está especificado para el método MessagesExchange.SendMessage.';tr = 'MesajKanalı parametresinin değeri, MesajAlışverişi.MesajGönder yöntemi için belirtilmemiş.';it = 'Valore parametro MessageChannel per il metodo MessageExchange.SendMessage non è impostato.';de = 'Der Wert des Parameters Nachrichtenkanal ist nicht für den Nachrichtenaustausch angegeben. NachrichtSenden Methode.'");
		
	ElsIf StrLen(MessagesChannel) > 150 Then
		
		Raise NStr("ru = 'Длина имени канала сообщений не должна превышать 150 символов.'; en = 'The length of message channel name cannot exceed 150 characters.'; pl = 'Długość nazwy kanału wiadomości nie może być dłuższa niż 150 znaków.';es_ES = 'La longitud del nombre del canal de mensajes no puede ser más larga de 150 símbolos.';es_CO = 'La longitud del nombre del canal de mensajes no puede ser más larga de 150 símbolos.';tr = 'Mesaj kanalı adının uzunluğu 150 karakterden uzun olamaz.';it = 'L lunghezza del nome del canale di messaggi non deve superare 150 caratteri.';de = 'Die Länge des Nachrichtenkanals darf nicht länger als 150 Zeichen sein.'");
		
	ElsIf Not ValueIsFilled(Recipient) Then
		
		Raise NStr("ru = 'Не задано значение параметра ""Recipient"" для метода MessageExchange.SendMessage.'; en = 'Recipient parameter value is not set for MessageExchange method.SendMessage.'; pl = 'Wartość parametru Recipient metody MessageExchange SendMessagenie jest określona.';es_ES = 'Valor del parámetro Destinatario no está especificado para el método MessagesExchange.SendMessage.';es_CO = 'Valor del parámetro Destinatario no está especificado para el método MessagesExchange.SendMessage.';tr = 'Alıcı parametresinin değeri, MesajAlışverişi.MesajGönder yöntemi için belirtilmemiş.';it = 'Valore parametro Destinatario non è impostato per il metodo MessageExchange.SendMessage.';de = 'Der Wert des Empfänger-Parameters ist für den Nachrichtenaustausch nicht angegeben. NachrichtSenden Methode'");
		
	ElsIf Common.ObjectAttributeValue(Recipient, "Locked") Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Попытка отправки сообщения заблокированной конечной точке ""%1"".'; en = 'Attempting to send message to locked endpoint %1.'; pl = 'Próba wysłania wiadomości do zablokowanego punktu końcowego ""%1"".';es_ES = 'Intentando enviar el mensaje al punto extremo bloqueado ""%1"".';es_CO = 'Intentando enviar el mensaje al punto extremo bloqueado ""%1"".';tr = 'Kilitli uç noktaya ""%1"" mesaj gönderilmeye çalışılıyor.';it = 'Tentativo di inviare un messaggio a endpoint bloccato %1.';de = 'Versuch, eine Nachricht an den gesperrten Endpunkt zu senden ""%1"".'"),
			String(Recipient));
	EndIf;
	
	CatalogForMessage = Catalogs.SystemMessages;
	StandardProcessing = True;
	
	If SaaSCached.IsSeparatedConfiguration() Then
		ModuleMessagesSaaSDataSeparation = Common.CommonModule("MessagesSaaSDataSeparation");
		OverriddenCatalog = ModuleMessagesSaaSDataSeparation.OnSelectCatalogForMessage(MessageBody);
		If OverriddenCatalog <> Undefined Then
			CatalogForMessage = OverriddenCatalog;
		EndIf;
	EndIf;
	
	NewMessage = CatalogForMessage.CreateItem();
	NewMessage.Description = MessagesChannel;
	NewMessage.Code = 0;
	NewMessage.MessageProccesAttemptCount = 0;
	NewMessage.Locked = False;
	NewMessage.MessageBody = New ValueStorage(MessageBody);
	NewMessage.Sender = MessageExchangeInternal.ThisNode();
	NewMessage.IsInstantMessage = IsInstantMessage;
	
	If Recipient = MessageExchangeInternal.ThisNode() Then
		
		NewMessage.Recipient = MessageExchangeInternal.ThisNode();
		
	Else
		
		NewMessage.DataExchange.Recipients.Add(Recipient);
		NewMessage.DataExchange.Recipients.AutoFill = False;
		
		NewMessage.Recipient = Recipient;
		
	EndIf;
	
	StandardWriteProcessing = True;
	If SaaSCached.IsSeparatedConfiguration() Then
		ModuleMessagesSaaSDataSeparation = Common.CommonModule("MessagesSaaSDataSeparation");
		ModuleMessagesSaaSDataSeparation.BeforeWriteMessage(NewMessage, StandardWriteProcessing);
	EndIf;
	
	If StandardWriteProcessing Then
		NewMessage.Write();
	EndIf;
	
EndProcedure

Function StartSendingInstantMessages()
	
	StartSending = True;
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		LockItem = Lock.Add("Constant.InstantMessageSendingLocked");
		Lock.Lock();
		
		InstantMessageSendingLocked = Constants.InstantMessageSendingLocked.Get();
		
		// CurrentSessionDate() method cannot be used.
		// In this case, the current server date is used an a unique key.
		If InstantMessageSendingLocked >= CurrentDate() Then
			StartSending = False;
		Else
			Constants.InstantMessageSendingLocked.Set(CurrentDate() + 60 * 5);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return StartSending;
EndFunction

Procedure FinishSendingInstantMessages()
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		LockItem = Lock.Add("Constant.InstantMessageSendingLocked");
		Lock.Lock();
		
		Constants.InstantMessageSendingLocked.Set(Date('00010101'));
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure CancelSendingInstantMessages()
	
	FinishSendingInstantMessages();
	
EndProcedure

Procedure DeleteChangesRegistration(Endpoint, Val Messages)
	
	For Each Message In Messages Do
		
		ExchangePlans.DeleteChangeRecords(Endpoint, Message);
		
	EndDo;
	
EndProcedure

Procedure DeliverMessagesToRecipient(Endpoint, Val Messages)
	
	Thread = "";
	
	MessageExchangeInternal.SerializeDataToStream(Messages, Thread);
	
	MessagesExchangeCached.WSEndpointProxy(Endpoint, 10).DeliverMessages(MessageExchangeInternal.ThisNodeCode(), New ValueStorage(Thread, New Deflation(9)));
	
EndProcedure

#EndRegion
