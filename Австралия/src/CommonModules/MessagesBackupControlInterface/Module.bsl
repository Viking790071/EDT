#Region Public

// Returns the namespace of the current (used by the calling code) message interface version.
// 
// Returns:
//   String - a namespace.
//
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ControlZonesBackup/" + Version();
	
EndFunction

// Returns the current (used by the calling code) message interface version.
// 
// Returns:
//   String - an interface version.
//
Function Version() Export
	
	Return "1.0.3.1";
	
EndFunction

// Returns the name of the application message interface.
// 
// Returns:
//   String - an interface name.
//
Function Public() Export
	
	Return "ControlZonesBackup";
	
EndFunction

// Registers message handlers as message exchange channel handler.
//
// Parameters:
//  HandlerArray - Array - an array of handlers.
//
Procedure MessageChannelHandlers(Val HandlerArray) Export
	
EndProcedure

// Registers message translation handlers.
//
// Parameters:
//  HandlerArray - Array - an array of handlers.
//
Procedure MessageTranslationHandlers(Val HandlerArray) Export
	
	HandlerArray.Add(MessagesBackupControlTranslationHandler_1_0_2_1);
	
EndProcedure

// Returns {http://www.1c.ru/SaaS/ControlZonesBackup/a.b.c.d}ZoneBackupSuccessfull message type.
//
// Parameters:
//  PackageUsed - String - a namespace of the message interface version for which the message type is being received.
//
// Returns:
//  XDTOType - message type.
//
Function AreaBackupCreatedMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "ZoneBackupSuccessfull");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ControlZonesBackup/a.b.c.d}ZoneBackupFailed message type.
//
// Parameters:
//  PackageUsed - String - a namespace of the message interface version for which the message type is being received.
//
// Returns:
//  XDTOType - message type.
//
Function AreaBackupErrorMessage(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "ZoneBackupFailed");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ControlZonesBackup/a.b.c.d}ZoneBackupSkipped message type.
//
// Parameters:
//  PackageUsed - String - a namespace of the message interface version for which the message type is being received.
//
// Returns:
//  XDTOType - message type.
//
Function AreaBackupSkippedMessage(Val PackageUsed = Undefined) Export
	
	If PackageUsed = Undefined Then
		PackageUsed = "http://www.1c.ru/SaaS/ControlZonesBackup/1.0.2.1";
	EndIf;
	
	Return GenerateMessageType(PackageUsed, "ZoneBackupSkipped");
	
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
