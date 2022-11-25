#Region Public

// Processes message body from the channel according to the algorithm of the current message channel.
//
// Parameters:
//  MessageChannel - String - an ID of a message channel used to receive the message.
//  MessageBody - Arbitrary - the body of the message received from the channel to be processed.
//  Sender - ExchangePlanRef.MessageExchange - the endpoint that is the sender of the message.
//
Procedure ProcessMessage(Val MessagesChannel, Val MessageBody, Val Sender) Export
	
	SetPrivilegedMode(True);
	
	If SaaSCached.IsSeparatedConfiguration() Then
		SeparatedModule = Common.CommonModule("MessagesSaaSDataSeparation");
	EndIf;
	
	// Message reading
	MessageType = MessagesSaaS.MessageTypeByChannelName(MessagesChannel);
	Message = MessagesSaaS.ReadMessageFromUntypedBody(MessageBody);
	
	MessagesSaaS.WriteProcessingStartEvent(Message);
	
	Try
		
		If SaaSCached.IsSeparatedConfiguration() Then
			SeparatedModule.OnMessageProcessingStart(Message, Sender);
		EndIf;
		
		MessagesSaaSOverridable.OnMessageProcessingStart(Message, Sender);
		
		// Getting and executing the message interface handler.
		Handler = GetMessageChannelHandlerSaaS(MessagesChannel);
		If Handler <> Undefined Then
			
			MessageProcessed = False;
			Handler.ProcessSaaSMessage(Message, Sender, MessageProcessed);
			
		Else
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось определить обработчик канала сообщений в модели сервиса %1'; en = 'Cannot determine the message channel handler for SaaS messages %1'; pl = 'Nie można zdefiniować programu obsługi kanałów komunikatów w usłudze SaaS %1';es_ES = 'No se puede definir el manipulador de canales de mensajes en SaaS %1';es_CO = 'No se puede definir el manipulador de canales de mensajes en SaaS %1';tr = 'Servis''te mesaj kanalı işleyicisi tanımlanamıyor%1';it = 'Impossibile determinare il gestore del canale di messaggio per messaggi SaaS %1';de = 'Kann den Nachrichtenkanalhandler nicht in SaaS definieren %1'"), MessagesChannel);
			
		EndIf;
		
		If SaaSCached.IsSeparatedConfiguration() Then
			SeparatedModule.AfterMessageProcessing(Message, Sender, MessageProcessed);
		EndIf;
		
		MessagesSaaSOverridable.AfterMessageProcessing(Message, Sender, MessageProcessed);
		
	Except
		
		If SaaSCached.IsSeparatedConfiguration() Then
			SeparatedModule.OnMessageProcessingError(Message, Sender);
		EndIf;
		
		MessagesSaaSOverridable.OnMessageProcessingError(Message, Sender);
		
		Raise;
		
	EndTry;
	
	MessagesSaaS.WriteProcessingEndEvent(Message);
	
	If NOT MessageProcessed Then
		
		MessagesSaaS.UnknownChannelNameError(MessagesChannel);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function GetMessageChannelHandlerSaaS(MessagesChannel)
	
	InterfaceHandlers = MessageInterfacesSaaS.GetIncomingMessageInterfaceHandlers();
	
	For Each InterfaceHandler In InterfaceHandlers Do
		
		InterfaceChannelHandlers  = New Array();
		InterfaceHandler.MessageChannelHandlers(InterfaceChannelHandlers);
		
		For Each InterfaceChannelHandler In InterfaceChannelHandlers Do
			
			Package = InterfaceChannelHandler.Package();
			BaseType = InterfaceChannelHandler.BaseType();
			
			ChannelNames = MessageInterfacesSaaS.GetPackageChannels(Package, BaseType);
			
			For Each ChannelName In ChannelNames Do
				If ChannelName = MessagesChannel Then
					
					Return InterfaceChannelHandler;
					
				EndIf;
			EndDo;
			
		EndDo;
		
	EndDo;
	
EndFunction

#EndRegion
