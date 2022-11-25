#Region Public

// Retrieves a list of handlers for messages processed by the current infobase.
// 
// 
// Parameters:
//  Handlers - ValueTable - with columns:
//    * Channel - String - a message channel.
//    * Handler - CommonModule - a message handler.
//
Procedure GetMessageChannelHandlers(Handlers) Export
	
	
	
EndProcedure

// Handler that returns a dynamic list of message endpoints.
//
// Parameters:
//  MessageChannel - String - message channel ID whose endpoints are to be determined.
//  Recipients - Array - array of endpoints assigned as message recipients. Contains items of 
//                            ExchangePlanRef.MessageExchange type.
//                            This parameter must be defined in the handler body.
//
Procedure MessageRecipients(Val MessagesChannel, Recipients) Export
	
	
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Message sending/receiving event handlers.

// "On send message" event handler.
// This event handler is called before a message is sent to an XML data stream.
// The handler is called separately for each message to be sent.
//
// Parameters:
//  MessageChannel - String - ID of a message channel used to receive the message.
//  MessageBody - Arbitrary - body of outgoing message. In this event handler, message body can be 
//                                modified (for example, new data added).
//
Procedure OnSendMessage(MessagesChannel, MessageBody) Export
	
EndProcedure

// "On receive message" event handler.
// This event handler is called after a message is received from an XML data stream.
// The handler is called separately for each received message.
//
// Parameters:
//  MessageChannel - String - an ID of a message channel used to receive the message.
//  MessageBody - Arbitrary - body of received message. In this event handler, message body can be 
//                                 modified (for example, new data added).
//
Procedure OnReceiveMessage(MessagesChannel, MessageBody) Export
	
EndProcedure

#EndRegion
