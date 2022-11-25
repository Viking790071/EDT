#Region Internal

// Sends and receives system messages.
// 
Procedure SendAndReceiveMessages() Export
	
	Cancel = False;
	
	MessagesExchangeServerCall.SendAndReceiveMessages(Cancel);
	
	If Cancel Then
		
		ShowUserNotification(NStr("ru = 'Возникли ошибки при отправке и получении сообщений.'; en = 'Errors occurred while sending and receiving emails.'; pl = 'Powstały błędy przy wysłaniu i otrzymaniu komunikatów.';es_ES = 'Errores ocurridos al enviar y recibir mensajes.';es_CO = 'Errores ocurridos al enviar y recibir mensajes.';tr = 'Mesaj gönderilirken ve alınırken hatalar oluştu.';it = 'Si sono registrati errori durante l''invio e la ricezione delle email.';de = 'Beim Senden und Empfangen von Nachrichten sind Fehler aufgetreten.'"),,
				NStr("ru = 'Используйте журнал регистрации для диагностики ошибок.'; en = 'Use the event log to diagnose errors.'; pl = 'Użyj dziennika wydarzeń do diagnostyki błędów.';es_ES = 'Utilizar el registro de eventos para diagnosticar los errores.';es_CO = 'Utilizar el registro de eventos para diagnosticar los errores.';tr = 'Hataları teşhis etmek için olay günlüğünü kullanın.';it = 'Utilizzare il registro eventi per diagnosticare gli errori.';de = 'Verwenden Sie das Ereignisprotokoll, um Fehler zu diagnostizieren.'"), PictureLib.Error32);
		
	Else
		
		ShowUserNotification(NStr("ru = 'Электронная почта синхронизирована.'; en = 'Emails are synced.'; pl = 'Wiadomości E-mail są synchronizowane.';es_ES = 'Los correos electrónicos se sincronizan.';es_CO = 'Los correos electrónicos se sincronizan.';tr = 'E-postalar senkronize ediliyor.';it = 'Le email sono sincronizzate.';de = 'E-Mails sind synchronisiert.'"),,, PictureLib.Information32);
		
	EndIf;
	
	Notify(EventNameSendAndReceiveMessageExecuted());
	
EndProcedure

#EndRegion

#Region Private

// For internal use only.
//
// Returns:
// String.
//
Function EndpointAddedEventName() Export
	
	Return "MessageExchange.EndpointAdded";
	
EndFunction

// For internal use only.
//
// Returns:
// String.
//
Function EventNameSendAndReceiveMessageExecuted() Export
	
	Return "MessageExchange.SendAndReceiveExecuted";
	
EndFunction

// For internal use only.
//
// Returns:
// String.
//
Function EndpointFormClosedEventName() Export
	
	Return "MessageExchange.EndpointFormClosed";
	
EndFunction

// For internal use only.
//
// Returns:
// String.
//
Function EventNameLeadingEndpointSet() Export
	
	Return "MessageExchange.LeadingEndpointSet";
	
EndFunction

#EndRegion
