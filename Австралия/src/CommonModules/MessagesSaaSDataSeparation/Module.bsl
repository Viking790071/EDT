#Region Internal

// Called when filling an array of catalogs that can be used for message storage purposes.
// 
//
// Parameters:
//  ArrayCatalog - Array - you need to add to this parameter any managers of catalogs that can be 
//    used to store the queue jobs to this parameter.
//
Procedure OnFillMessageCatalogs(CatalogArray) Export
	
	CatalogArray.Add(Catalogs.DataAreaMessages);
	
EndProcedure

// Selects the catalog for the message.
//
// Parameters:
// MessageBody - Arbitrary - message body.
//
Function OnSelectCatalogForMessage(Val MessageBody) Export
	
	Message = Undefined;
	If MessagesSaaS.BodyContainsTypedMessage(MessageBody, Message) Then
		
		If MessagesSaaSCached.AreaBodyType().IsDescendant(Message.Body.Type()) Then
			
			Return Catalogs.DataAreaMessages;
			
		EndIf;
		
	Else
		
		If SaaS.SessionSeparatorUsage() Then
			Return Catalogs.DataAreaMessages;
		EndIf;
		
	EndIf;
	
EndFunction

// Called before writing a message catalog item.
//
// Parameters:
//  MessageObject - CatalogObject.SystemMessages, CatalogObject.DataAreaMessages,
//  StandardProcessing - Boolean.
//
Procedure BeforeWriteMessage(MessageObject, StandardProcessing) Export
	
	Message = Undefined;
	If MessagesSaaS.BodyContainsTypedMessage(MessageObject.MessageBody.Get(), Message) Then
		
		If MessagesSaaSCached.AreaBodyType().IsDescendant(Message.Body.Type()) Then
			
			MessageObject.DataAreaAuxiliaryData = Message.Body.Zone;
			
		EndIf;
		
	EndIf;
	
	StandardProcessing = False;
	SaaS.WriteAuxiliaryData(MessageObject);
	
EndProcedure

// "On send message" event handler.
// This event handler is called before a message is sent to an XML data stream.
// The handler is called separately for each message to be sent.
//
// Parameters:
//  MessageChannel - String - ID of a message channel used to receive the message.
//  MessageBody - Arbitrary - body of outgoing message. In this event handler, message body can be 
//    modified (for example, new data added).
//
Procedure OnSendMessage(MessagesChannel, MessageBody, MessageObject) Export
	
	Message = Undefined;
	If MessagesSaaS.BodyContainsTypedMessage(MessageBody, Message) Then
		
		If SaaS.SeparatedDataUsageAvailable()
			AND MessagesSaaSCached.AreaBodyType().IsDescendant(Message.Body.Type()) Then
			
			If SaaS.SessionSeparatorValue() <> Message.Body.Zone Then
				MessageTemplate = NStr("ru = 'Попытка отправить сообщение от имени области %1 из области %2'; en = 'Message delivery from area %2 on behalf of area %1 is attempted'; pl = 'Próba wysłania wiadomości w imieniu obszaru %1 z obszaru %2';es_ES = 'Intentando enviar un mensaje de parte del área %1 del área %2';es_CO = 'Intentando enviar un mensaje de parte del área %1 del área %2';tr = 'Alan %1''den alan %2 adına mesaj göndermeye çalışılıyor';it = 'Tentativo di inviare messaggio dall''area %2 per conto dell''area %1';de = 'Versucht, eine Nachricht im Auftrag des Gebiets %1 aus dem Gebiet %2 zu senden'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, Message.Body.Zone,
					SaaS.SessionSeparatorValue());
				Raise(MessageText);
			EndIf;
		EndIf;
		
		If MessagesSaaSCached.AuthentifiedAreaBodyType().IsDescendant(Message.Body.Type()) Then
			
			If SaaS.SeparatedDataUsageAvailable() Then
				Message.Body.ZoneKey = Constants.DataAreaKey.Get();
			Else
				SetPrivilegedMode(True);
				SaaS.SetSessionSeparation(True, Message.Body.Zone);
				Message.Body.ZoneKey = Constants.DataAreaKey.Get();
				SaaS.SetSessionSeparation(False);
			EndIf;
			
		EndIf;
		
		MessageBody = MessagesSaaS.WriteMessageToUntypedBody(Message);
		
	EndIf;
	
	If TypeOf(MessageObject) <> Type("CatalogObject.SystemMessages") Then
		
		MessageObjectSubstitution = Catalogs.SystemMessages.CreateItem();
		
		FillPropertyValues(MessageObjectSubstitution, MessageObject, , "Parent,Owner");
		
		MessageObjectSubstitution.SetNewObjectRef(Catalogs.SystemMessages.GetRef(
			MessageObject.Ref.UUID()));
		
		MessageObject = MessageObjectSubstitution;
		
	EndIf;
	
EndProcedure

// "On receive message" event handler.
// This event handler is called after a message is received from an XML data stream.
// The handler is called separately for each received message.
//
// Parameters:
//  MessageChannel - String - an ID of a message channel used to receive the message.
//  MessageBody - Arbitrary - body of received message. In this event handler, message body can be 
//    modified (for example, new data added).
//
Procedure OnReceiveMessage(MessagesChannel, MessageBody, MessageObject) Export
	
	SetPrivilegedMode(True);
	
	Message = Undefined;
	If MessagesSaaS.BodyContainsTypedMessage(MessageBody, Message) Then
		
		If SaaSCached.IsSeparatedConfiguration() Then
			
			OverriddenCatalog = OnSelectCatalogForMessage(MessageBody);
			
			If OverriddenCatalog <> Undefined Then
				
				If TypeOf(OverriddenCatalog.EmptyRef()) <> TypeOf(MessageObject.Ref) Then
					
					MessageObjectSubstitutionRef = OverriddenCatalog.GetRef(
						MessageObject.GetNewObjectRef().UUID());
					
					If Common.RefExists(MessageObjectSubstitutionRef) Then
						
						MessageObjectSubstitution = MessageObjectSubstitutionRef.GetObject();
						
					Else
						
						MessageObjectSubstitution = OverriddenCatalog.CreateItem();
						MessageObjectSubstitution.SetNewObjectRef(MessageObjectSubstitutionRef);
						
					EndIf;
					
					FillPropertyValues(MessageObjectSubstitution, MessageObject, , "Parent,Owner");
					MessageObjectSubstitution.DataAreaAuxiliaryData = Message.Body.Zone;
					
					MessageObject = MessageObjectSubstitution;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// This procedure is called at the start of incoming message processing.
//
// Parameters:
//  Message - XDTODataObject - an incoming message,
//  Sender - ExchangePlanRef.MessageExchange - exchange plan node matching the infobase used to send 
//    the message.
//
Procedure OnMessageProcessingStart(Val Message, Val Sender) Export
	
	If MessagesSaaSCached.AreaBodyType().IsDescendant(Message.Body.Type()) Then
		
		SaaS.SetSessionSeparation(True, Message.Body.Zone);
		ProcessAreaKeyInMessage(Message);
		
	EndIf;
	
EndProcedure

// This procedure is called after incoming message processing.
//
// Parameters:
//  Message - XDTODataObject - an incoming message,
//  Sender - ExchangePlanRef.MessageExchange - exchange plan node matching the infobase used to send 
//    the message,
//  MessageProcessed - boolean, flag specifying whether the message was processed successfully. If 
//    set to False an exception is raised after this procedure is complete. In this procedure, value 
//    of this parameter can be modified.
//
Procedure AfterMessageProcessing(Val Message, Val Sender, MessageProcessed) Export
	
	If MessagesSaaSCached.AreaBodyType().IsDescendant(Message.Body.Type()) Then
		
		SaaS.SetSessionSeparation(False);
		
	EndIf;
	
EndProcedure

// This procedure is called when a message processing error occurs.
//
// Parameters:
//  Message - XDTODataObject - an incoming message,
//  Sender - ExchangePlanRef.MessageExchange - exchange plan node matching the infobase used to send 
//    the message.
//
Procedure OnMessageProcessingError(Val Message, Val Sender) Export
	
	If MessagesSaaSCached.AreaBodyType().IsDescendant(Message.Body.Type()) Then
		
		SaaS.SetSessionSeparation(False);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure ProcessAreaKeyInMessage(Message)
	
	MessageContainsAreaKey = False;
	
	If MessagesSaaSCached.AuthentifiedAreaBodyType().IsDescendant(Message.Body.Type()) Then
		MessageContainsAreaKey = True;
	EndIf;
	
	If Not MessageContainsAreaKey Then
		
		HandlerArray = New Array();
		ModuleToCall = Common.CommonModule("RemoteAdministrationMessagesInterface");
		ModuleToCall.MessageChannelHandlers(HandlerArray);
		For Each Handler In HandlerArray Do
			
			HandlerMessageType = ModuleToCall.MessageSetDataAreaParameters(
				Handler.Package());
			
			If Message.Body.Type() = HandlerMessageType Then
				MessageContainsAreaKey = True;
				Break;
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If MessageContainsAreaKey Then
		
		CurrentAreaKey = Constants.DataAreaKey.Get();
		
		If Not ValueIsFilled(CurrentAreaKey) Then
			
			Constants.DataAreaKey.Set(Message.Body.ZoneKey);
			
		Else
			
			If CanCheckAreaKeyInMessages() Then
				
				If CurrentAreaKey <> Message.Body.ZoneKey Then
					
					Raise NStr("ru = 'Неверный ключ области данных в сообщении'; en = 'Incorrect data area key in the message'; pl = 'Nieprawidłowy klucz obszaru danych w wiadomości';es_ES = 'Clave incorrecta del área de datos en el mensaje';es_CO = 'Clave incorrecta del área de datos en el mensaje';tr = 'Mesajdaki veri alanının yanlış anahtarı.';it = 'Chiave di area dati nel messaggio non valida';de = 'Falscher Datenbereichsschlüssel in der Nachricht'");
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Function CanCheckAreaKeyInMessages()
	
	SettingsStructure = InformationRegisters.MessageExchangeTransportSettings.TransportSettingsWS(
		SaaS.ServiceManagerEndpoint());
	SaaSConnectionParameters = New Structure;
	SaaSConnectionParameters.Insert("URL",      SettingsStructure.WSWebServiceURL);
	SaaSConnectionParameters.Insert("UserName", SettingsStructure.WSUsername);
	SaaSConnectionParameters.Insert("Password", SettingsStructure.WSPassword);
	
	LatestVersion = Undefined;
	SaaSVersions = Common.GetInterfaceVersions(SaaSConnectionParameters, "MessagesSaaS");
	If SaaSVersions = Undefined Then
		Return False;
	EndIf;
	
	For Each SaaSVersion In SaaSVersions Do
		
		If LatestVersion = Undefined Then
			LatestVersion = SaaSVersion;
		Else
			LatestVersion = ?(CommonClientServer.CompareVersions(
				SaaSVersion, LatestVersion) > 0, SaaSVersion,
				LatestVersion);
		EndIf;
		
	EndDo;
	
	If SaaSVersion = Undefined Then
		Return False;
	EndIf;
	
	Return (CommonClientServer.CompareVersions(LatestVersion, "1.0.4.1") >= 0);
	
EndFunction

#EndRegion
