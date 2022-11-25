#Region Internal

// See IBConnections.ConnectionsInformation. 
Function ConnectionsInformation(GetConnectionString = False, MessagesForEventLog = Undefined, ClusterPort = 0) Export
	
	Return IBConnections.ConnectionsInformation(GetConnectionString, MessagesForEventLog, ClusterPort);
	
EndFunction

// Sets the infobase connection lock.
// If this function is called from a session with separator values set, it sets the data area 
// session lock.
//
// Parameters:
//  MessageText - String - text to be used in the error message displayed when someone attempts to 
//                             connect to a locked infobase.
//                             
// 
//  KeyCode - String - string to be added to "/uc" command line parameter or to "uc" connection 
//                             string parameter in order to establish connection to the infobase 
//                             regardless of the lock.
//                             
//                             Cannot be used for data area session locks.
//
// Returns:
//   Boolean - True if the lock is set successfully.
//              False if the lock cannot be set due to insufficient rights.
//
Function SetConnectionLock(MessageText = "",
	KeyCode = "KeyCode") Export
	
	Return IBConnections.SetConnectionLock(MessageText, KeyCode);
	
EndFunction

// Removes the infobase lock.
//
// Returns:
//   Boolean - True if the operation is successful.
//              False if the operation cannot be performed due to insufficient rights.
//
Function AllowUserAuthorization() Export
	
	Return IBConnections.AllowUserAuthorization();
	
EndFunction

#EndRegion

#Region Private

// Gets the infobase connection lock parameters to be used at client side.
//
// Parameters:
//  GetSessionCount - Boolean - if True, then the SessionCount field is filled in the returned 
//                                       structure.
//
// Returns:
//   Structure - with the following fields:
//     IsSet - Boolean - True if the lock is set, otherwise False.
//     Start - Date - lock start date.
//     End - Date - lock end date.
//     Message - String - message to a user.
//     SessionTerminationTimeout - Number - interval in seconds.
//     SessionCount - 0 if the GetSessionCount parameter value is False.
//     CurrentSessionDate - Date - current session date.
//
Function SessionLockParameters(GetSessionCount = False) Export
	
	Return IBConnections.SessionLockParameters(GetSessionCount);
	
EndFunction

// Sets the data area session lock.
// 
// Parameters:
//   Parameters - Structure - see NewConnectionLockParameters. 
//   LocalTime - Boolean - lock beginning time and lock end time are specified in the local session time.
//                                If the parameter is False, they are specified in universal time.
//
Procedure SetDataAreaSessionLock(Parameters, LocalTime = True) Export
	
	IBConnections.SetDataAreaSessionLock(Parameters, LocalTime);
	
EndProcedure

// Returns the number of the current infobase session.
//
Function CurrentSessionNumber() Export
	
	Return InfoBaseSessionNumber();
	
EndFunction

// Gets saved administration parameters.
//
Function AdministrationParameters() Export
	Return StandardSubsystemsServer.AdministrationParameters();
EndFunction

// Deletes all infobase sessions except the current one.
//
Procedure DeleteAllSessionsExceptCurrent(AdministrationParameters) Export
	
	IBConnectionsClientServer.DeleteAllSessionsExceptCurrent(AdministrationParameters);
	
EndProcedure

#EndRegion