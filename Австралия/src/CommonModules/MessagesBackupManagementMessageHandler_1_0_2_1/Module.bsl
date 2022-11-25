#Region Public

// Returns message interface version namespace.
//
// Returns:
//  String - a package description.
//
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ManageZonesBackup/" + Version();
	
EndFunction

// Returns message interface version supported by the handler.
//
// Returns:
//  String - a package version.
//
Function Version() Export
	
	Return "1.0.2.1";
	
EndFunction

// Returns the base type for version messages.
//
// Returns:
//  XDTOObjectType - base body type for messages SaaS.
//
Function BaseType() Export
	
	Return MessagesSaaSCached.TypeBody();
	
EndFunction

// Processes incoming SaaS messages.
//
// Parameters:
//  Message - XDTODataObject - an incoming message,
//  Sender - ExchangePlanRef.MessageExchange - exchange plan node that matches the message sender.
//  MessageProcessed - Boolean - flag that shows that processing is successful. The value of this 
//    parameter must be set to True if the message was successfully read in this handler.
//
Procedure ProcessSaaSMessage(Val Message, Val Sender, MessageProcessed) Export
	
	MessageProcessed = True;
	
	Dictionary = MessagesBackupManagementInterface;
	MessageType = Message.Body.Type();
	
	If MessageType = Dictionary.MessageScheduleAreaBackup(Package()) Then
		ScheduleAreaBackup(Message, Sender);
	ElsIf MessageType = Dictionary.MessageCancelAreaBackup(Package()) Then
		CancelAreaBackup(Message, Sender);
	Else
		MessageProcessed = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure ScheduleAreaBackup(Val Message, Val Sender)
	
	MessageBody = Message.Body;
	MessagesBackupManagementImplementation.ScheduleAreaBackingUp(
		MessageBody.Zone,
		MessageBody.BackupId,
		MessageBody.Date,
		MessageBody.Forced);
	
EndProcedure

Procedure CancelAreaBackup(Val Message, Val Sender)
	
	MessageBody = Message.Body;
	MessagesBackupManagementImplementation.CancelAreaBackingUp(
		MessageBody.Zone,
		MessageBody.BackupId);
	
EndProcedure

#EndRegion
