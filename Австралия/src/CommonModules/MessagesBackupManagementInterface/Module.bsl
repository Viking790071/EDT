#Region Public

// Returns the namespace of the current (used by the calling code) message interface version.
//
// Returns:
//  String - a package description.
//
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ManageZonesBackup/" + Version();
	
EndFunction

// Returns the current (used by the calling code) message interface version.
//
// Returns:
//  String - a package version.
//
Function Version() Export
	
	Return "1.0.3.1";
	
EndFunction

// Returns the name of the application message interface.
//
// Returns:
//  String - application interface ID.
//
Function Public() Export
	
	Return "ManageZonesBackup";
	
EndFunction

// Registers message handlers as message exchange channel handler.
//
// Parameters:
//  HandlerArray - Array - an array of handlers.
//
Procedure MessageChannelHandlers(Val HandlerArray) Export
	
	HandlerArray.Add(MessagesBackupManagementMessageHandler_1_0_2_1);
	HandlerArray.Add(MessagesBackupManagementMessageHandler_1_0_3_1);
	
EndProcedure

// Registers message translation handlers.
//
// Parameters:
//  HandlerArray - Array - an array of handlers.
//
Procedure MessageTranslationHandlers(Val HandlerArray) Export
	
EndProcedure

// Returns {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}PlanZoneBackup message type.
//
// Parameters:
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTOType - a message.
//
Function MessageScheduleAreaBackup(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "PlanZoneBackup");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}CancelZoneBackup message type.
//
// Parameters:
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTOType - message.
//
Function MessageCancelAreaBackup(Val PackageUsed = Undefined) Export
	
	If PackageUsed = Undefined Then
		PackageUsed = "http://www.1c.ru/SaaS/ManageZonesBackup/1.0.2.1";
	EndIf;
	
	Return GenerateMessageType(PackageUsed, "CancelZoneBackup");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}UpdateScheduledZoneBackupSettings message type.
//
// Parameters:
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTOType - message.
//
Function MessageUpdatePeriodicBackupSettings(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "UpdateScheduledZoneBackupSettings");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}CancelScheduledZoneBackup message type.
//
// Parameters:
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTOType - message.
//
Function MessageCancelPeriodicBackup(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "CancelScheduledZoneBackup");
	
EndFunction

#EndRegion

#Region Private

Function GenerateMessageType(Val PackageUsed, Val Type)
	
	If PackageUsed = Undefined Then
		PackageUsed = Package();
	EndIf;
	
	Return XDTOFactory.Type(PackageUsed, Type);
	
EndFunction

#EndRegion
