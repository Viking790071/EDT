#Region Public

#Region ProgramInterfaceParameterConstructors

// Constructor of a structure that defines the connection parameters of the server cluster being 
// administrated.
//
// Returns:
//  Structure - a structure containing fields:
//    * ConnectionType - String - valid values:
//        "COM" - when connecting to the server agent using the V8*.ComConnector COM object,
//        "RAS" - when connecting the administration server (ras) using the console client of the 
//                administration server (rac).
//    * ServerAgentAddress - String - network address of the server agent (only for ConnectionType = "COM").
//    * ServerAgentPort - Number - network port of the server agent (only for ConnectionType = 
//      "COM"). Usually, 1540.
//    * AdministrationServerAddress - String - network address of the ras administration server 
//      (only with ConnectionType = "RAS").
//    * AdministrationServerPort - Number - network port of the ras administration server (only with
//      ConnectionType = "RAS"). Usually, 1545.
//    * ClusterPort - Number - network port of the cluster manager. Usually, 1541.
//    * ClusterAdministratorName - String - cluster administrator account name (if the list of 
//      administrators is not specified for the cluster, the value is set to empty string).
//    * ClusterAdministratorPassword - String - cluster administrator account password. If the list 
//      of administrators is not specified for the cluster or the administrator account password is 
//      not set, the value is a blank string.
//
Function ClusterAdministrationParameters() Export
	
	Result = New Structure();
	
	Result.Insert("ConnectionType", "COM"); // "COM" or "RAS"
	
	// For "COM" only
	Result.Insert("ServerAgentAddress", "");
	Result.Insert("ServerAgentPort", 1540);
	
	// For "RAS" only
	Result.Insert("AdministrationServerAddress", "");
	Result.Insert("AdministrationServerPort", 1545);
	
	Result.Insert("ClusterPort", 1541);
	Result.Insert("ClusterAdministratorName", "");
	Result.Insert("ClusterAdministratorPassword", "");
	
	Return Result;
	
EndFunction

// Constructor of a structure that defines the cluster infobase connection parameters being 
//  administered.
//
// Returns:
//  Structure - a structure containing fields:
//    * NameInCluster - String - name of the infobase in cluster server.
//    * InfobaseAdministratorName - String - name of the infobase user with administrative rights 
//      (if the list of infobase users is not set, the value is set to empty string).
//      
//    * InfobaseAdministratorPassword - String - password of the infobase user with administrative 
//      rights (if the list of infobase users is not set or the infobase user password is not set, 
//      the value is set to empty string).
//
Function ClusterInfobaseAdministrationParameters() Export
	
	Result = New Structure();
	
	Result.Insert("NameInCluster", "");
	Result.Insert("InfobaseAdministratorName", "");
	Result.Insert("InfobaseAdministratorPassword", "");
	
	Return Result;
	
EndFunction

// Checks whether administration parameters are filled correctly.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  IBAdministrationParameters  - Structure - see  ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters.
//    The parameter can be skipped if the same fields have been filled in the structure passed as 
//    the ClusterAdministrationParameters parameter value.
//  CheckClusterAdministrationParameters - Boolean - indicates whether cluster administration parameters check is required,
//  CheckClusterAdministrationParameters - Boolean - Indicates whether cluster administration 
//                                                                   parameters check is required.
//
Procedure CheckAdministrationParameters(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined,
	CheckClusterAdministrationParameters = True,
	CheckInfobaseAdministrationParameters = True) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	AdministrationManager.CheckAdministrationParameters(ClusterAdministrationParameters, IBAdministrationParameters, CheckInfobaseAdministrationParameters, CheckClusterAdministrationParameters);
	
EndProcedure

#EndRegion

#Region SessionAndScheduledJobLock

// Constructor of a structure that defines infobase session and scheduled job lock properties.
//  
//
// Returns:
//  Structure - a structure containing fields:
//    * SessionsLock - Boolean - indicates whether new infobase sessions are locked.
//    * DateFrom - Date - (Date and time) a moment of time after which new infobase sessions are prohibited.
//    * DateTo - Date - (Date and time) a moment of time after which new infobase sessions are allowed.
//    * Message - String - the message displayed to the user when a new session is being established 
//      with the locked infobase.
//    * PermissionCode - String - a pass code that allows to connect to a locked infobase.
//    * ScheduledJobLock - Boolean - flag that shows whether infobase scheduled jobs must be locked.
//      
//
Function SessionAndScheduleJobLockProperties() Export
	
	Result = New Structure();
	
	Result.Insert("SessionsLock");
	Result.Insert("DateFrom");
	Result.Insert("DateTo");
	Result.Insert("Message");
	Result.Insert("KeyCode");
	Result.Insert("LockParameter");
	Result.Insert("ScheduledJobLock");
	
	Return Result;
	
EndFunction

// Returns the current state of infobase session locks and scheduled job locks.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  IBAdministrationParameters  - Structure - see  ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters.
//    The parameter can be skipped if the same fields have been filled in the structure passed as 
//    the ClusterAdministrationParameters parameter value.
//
// Returns:
//    Structure - see ClusterAdministrationClientServer.SessionAndScheduleJobLockProperties. 
//
Function InfobaseSessionAndJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Result = AdministrationManager.InfobaseSessionAndJobLock(
		ClusterAdministrationParameters,
		IBAdministrationParameters);
	
	Return Result;
	
EndFunction

// Sets the state of infobase session locks and scheduled job locks.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  IBAdministrationParameters  - Structure - see  ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters.
//  SessionAndJobLockProperties - Structure - see ClusterAdministrationClientServer. SessionAndScheduleJobLockProperties.
//
Procedure SetInfobaseSessionAndJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val SessionAndJobLockProperties) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.SetInfobaseSessionAndJobLock(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		SessionAndJobLockProperties);
	
EndProcedure

// Unlocks infobase sessions and scheduled jobs.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  IBAdministrationParameters  - Structure - see  ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters.
//    The parameter can be skipped if the same fields have been filled in the structure passed as 
//    the ClusterAdministrationParameters parameter value.
//
Procedure RemoveInfobaseSessionAndJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	LockProperties = SessionAndScheduleJobLockProperties();
	LockProperties.SessionsLock = False;
	LockProperties.DateFrom = Undefined;
	LockProperties.DateTo = Undefined;
	LockProperties.Message = "";
	LockProperties.KeyCode = "";
	LockProperties.ScheduledJobLock = False;
	
	SetInfobaseSessionAndJobLock(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		LockProperties);
	
EndProcedure

#EndRegion

#Region ScheduledJobLock

// Returns the current state of infobase scheduled job locks.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  IBAdministrationParameters  - Structure - see  ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters.
//    The parameter can be skipped if the same fields have been filled in the structure passed as 
//    the ClusterAdministrationParameters parameter value.
//
// Returns:
//    Boolean - True if scheduled jobs are successfully locked, False otherwise.
//
Function InfobaseScheduledJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Result = AdministrationManager.InfobaseScheduledJobLock(
		ClusterAdministrationParameters,
		IBAdministrationParameters);
	
	Return Result;
	
EndFunction

// Sets the state of infobase scheduled job locks.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  IBAdministrationParameters  - Structure - see  ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters.
//  ScheduledJobLock - Boolean - indicates whether infobase scheduled jobs are locked.
//
Procedure SetInfobaseScheduledJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val ScheduledJobLock) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.SetInfobaseScheduledJobLock(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		ScheduledJobLock);
	
EndProcedure

#EndRegion

#Region InfobaseSessions

// Constructor of a structure that describes infobase session properties.
//
// Returns:
//  Structure - a structure containing fields:
//   * Number - Number - session number. The number is unique across the infobase sessions.
//   * UserName - String - infobase user's name.
//   * ClientComputerName - String - name or network address of the computer that established the 
//     session with the infobase.
//   * ClientApplicationID - String - ID of the application that established the session. See the 
//     description of the ApplicationPresentation global function.
//   * LanguageID - String - interface language ID.
//   * SessionCreationTime - Date - date and time the session was created.
//   * LatestSessionActivityTime - Date - date and time of the session last activity.
//   * Lock - Number - number of the session that resulted in managed transactional lock wait if the 
//     session sets managed transactional locks and waits for locks set by another session to be 
//     disabled. Otherwise, the value is 0.
//   * DBMSLock - Number - number of the session that caused transactional lock wait if the session 
//     performs a DBMS call and waits for a transactional lock set by another session to be disabled. 
//     Otherwise, the value is 0.
//   * Passed - Number - volume of data passed between the 1C:Enterprise server and the current 
//     session client application since the session start, in bytes.
//   * PassedIn5Minutes - Number - volume of data passed between the 1C:Enterprise server and the 
//     current session client application in the last 5 minutes, in bytes.
//   * ServerCalls - Number - number of the 1c:Enterpraise server calls made by the current session 
//     since the session started.
//   * ServerCallsIn5Minutes - Number - number of the 1C:Enterprise server calls made by the current 
//     session in the last 5 minutes.
//   * ServerCallsDurations - Number - total 1C:Enterprise server call time made by the current 
//     session since the session start, in milliseconds.
//   * CurrentServerCallDuration - Number - time interval since the 1C:Enterprise server call start. 
//     If there is no server call, the value is 0.
//   * ServerCallsDurationsIn5Minutes - Number - total time of 1C:Enterprise server calls made by 
//     the current session in the last 5 minutes, in milliseconds.
//   * ExchangedWithDBMS - Number - volume of data passed and received from DBMS on behalf of the 
//     current session since the session start, in bytes.
//   * ExchangedWithDBMSIn5Minutes - Number - volume of data passed and received from DBMS on behalf 
//     of the current session in the last 5 minutes, in bytes.
//   * DBMSCallsDurations - Number - total time spent on executing DBMS queries made on behalf of 
//     the current session since the session start, in milliseconds.
//   * CurrentDBMSCallDuration - Number - time interval since the current DBMS query execution start, 
//     in milliseconds. If there is no query, the value is 0.
//   * DBMSCallsDurationsIn5Minutes - Number - total time spent on executing DBMS queries made on 
//     behalf of the current session in the last 5 minutes (in milliseconds).
//   * DBMSConnection - String - DBMS connection number in the terms of DBMS if when the session 
//     list is retrieved, the DBMS query is executed, a transaction is opened, or temporary tables 
//     are defined (DBMS connection is seized). If the BDMS session is not seized, the value is a blank string,
//   * DBMSConnectionTime - Number - the period since the DBMS connection capture, in milliseconds. If the
//     BDMS session is not seized - the value is 0,
//   * DBMSConnectionSeizeTime - Date - the date and time of the last DBMS connection capture.
//     
//
Function SessionProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Number");
	Result.Insert("UserName");
	Result.Insert("ClientComputerName");
	Result.Insert("ClientApplicationID");
	Result.Insert("LanguageID");
	Result.Insert("SessionCreationTime");
	Result.Insert("LatestSessionActivityTime");
	Result.Insert("Lock");
	Result.Insert("DBMSLock");
	Result.Insert("Passed");
	Result.Insert("PassedIn5Minutes");
	Result.Insert("ServerCalls");
	Result.Insert("ServerCallsIn5Minutes");
	Result.Insert("ServerCallsDurations");
	Result.Insert("CurrentServerCallDuration");
	Result.Insert("ServerCallsDurationsIn5Minutes");
	Result.Insert("ExchangedWithDBMS");
	Result.Insert("ExchangedWithDBMSIn5Minutes");
	Result.Insert("DBMSCallsDurations");
	Result.Insert("CurrentDBMSCallDuration");
	Result.Insert("DBMSCallDurationsIn5Minutes");
	Result.Insert("DBMSConnection");
	Result.Insert("DBMSConnectionTime");
	Result.Insert("DBMSConnectionSeizeTime");
	
	Return Result;
	
EndFunction

// Returns descriptions of infobase sessions.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  IBAdministrationParameters  - Structure - see  ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters.
//    The parameter can be skipped if the same fields have been filled in the structure passed as 
//    the ClusterAdministrationParameters parameter value.
//  Filter - Array - an array of structures that contain session filter criteria. Each array structure has the following fields:
//             * Property - String - the name of the property to be filtered (see ClusterAdministrationClientServer.SessionProperties).
//             * ComparisonType - ComparisonType - a value of the ComparisonType system enumeration.
//             * Value - Number, String, Data, Boolean, ValueList, Array, Structure - the value the 
//               matching session property value is compared with.
//         - Structure - Structure. Key - the name of the session property (mentioned above). Value 
//           - the value to compare with. When you use this filter description, the comparison 
//           always checks for equality.
//
// Returns:
//   Array - an array of structures (see ClusterAdministrationClientServer.SessionProperties).
//
Function InfobaseSessions(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined, Val Filter = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.InfobaseSessions(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		Filter);
	
EndFunction

// Deletes infobase sessions according to filter.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  IBAdministrationParameters  - Structure - see  ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters.
//    The parameter can be skipped if the same fields have been filled in the structure passed as 
//    the ClusterAdministrationParameters parameter value.
//  Filter - Array - an array of structures that contain connection filter criteria. Each array structure has the following fields:
//             * Property - String - the name of the property to be filtered (see ClusterAdministrationClientServer.SessionProperties).
//             * ComparisonType - ComparisonType - a value of the ComparisonType system enumeration.
//             * Value - Number, String, Data, Boolean, ValueList, Array, Structure - the value the 
//               matching session property value is compared with.
//         - Structure - Structure. Key - the name of the session property (mentioned above). Value 
//           - the value to compare with. When you use this filter description, the comparison always checks for equality.
//
Procedure DeleteInfobaseSessions(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined, Val Filter = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.DeleteInfobaseSessions(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		Filter);
	
EndProcedure

#EndRegion

#Region InfobaseConnections

// Constructor of a structure that defines infobase connection properties.
//
// Returns:
//  Structure - a structure containing fields:
//    * Number - Number - the number of an infobase connection.
//    * UserName - String - the name of a 1C:Enterprise user connected to the infobase.
//    * ClientComputerName - String - the name of the computer that established the connection.
//    * ClientApplicationID - String - ID of the application that established the connection. See 
//                                                    the description of the ApplicationPresentation global function.
//    * ConnectionEstablishingTime - Date - the date and time when the connection was established.
//    * InfobaseConnectionMode - Number - the infobase connection mode (0 if shared, 1 if exclusive).
//      
//    * DatabaseConnectionMode - Number - database connection mode (0 if no connection,
//      1 if shared, 2 if exclusive).
//    * DBMSLock - Number - the ID of the connection that locks the current connection in the DBMS.
//    * Passed - Number - the volume of data sent and received over the connection.
//    * PassedIn5Minutes - Number - the volume of data sent and received over the connection in the last 5 minutes.
//    * ServerCalls - Number - the number of server calls.
//    * ServerCallsIn5Minutes - Number - the number of server calls in the last 5 minutes.
//    * ExchangedWithDBMS - Number -  the data volume passed between the 1C:Enterprise server and 
//      the database server since the connection was established.
//    * ExchangedWithDBMSIn5Minutes - Number - the volume of data passed between the 1C:Enterprise 
//        server and the database server in the last 5 minutes.
//    * DBMSConnection - String - the DBMS connection process ID if the connection is contacting a 
//      DBMS server when the list is requested. Otherwise, the value is a blank string.
//       The ID is returned in the DBMS server terms.
//    * DBMSTime - Number - the DBMS server call duration in seconds if the connection is contacting 
//      a DBMS server when the list is requested. Otherwise, the value is 0.
//      
//    * DBMSConnectionSeizeTime - Date - the date and time of the last DBMS server connection capture.
//    * ServerCallsDurations - Number - the duration of all server calls the connection initialized.
//    * DBMSCallsDurations - Number - the duration of all DBMS calls the connection initialized.
//    * CurrentServerCallDuration - Number - the duration of the current server call.
//    * CurrentDBMSCallDuration - Number - the duration of the current dastabase server call.
//    * ServerCallsDurationsIn5Minutes - Number - the duration of server calls in the last 5 minutes.
//    * DBMSCallsDurationsIn5Minutes - Number - the duration of DBMS server calls in the last 5 minutes.
//
Function ConnectionProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Number");
	Result.Insert("UserName");
	Result.Insert("ClientComputerName");
	Result.Insert("ClientApplicationID");
	Result.Insert("ConnectionEstablishingTime");
	Result.Insert("InfobaseConnectionMode");
	Result.Insert("DataBaseConnectionMode");
	Result.Insert("DBMSLock");
	Result.Insert("Passed");
	Result.Insert("PassedIn5Minutes");
	Result.Insert("ServerCalls");
	Result.Insert("ServerCallsIn5Minutes");
	Result.Insert("ExchangedWithDBMS");
	Result.Insert("ExchangedWithDBMSIn5Minutes");
	Result.Insert("DBMSConnection");
	Result.Insert("DBMSTime");
	Result.Insert("DBMSConnectionSeizeTime");
	Result.Insert("ServerCallsDurations");
	Result.Insert("DBMSCallsDurations");
	Result.Insert("CurrentServerCallDuration");
	Result.Insert("CurrentDBMSCallDuration");
	Result.Insert("ServerCallsDurationsIn5Minutes");
	Result.Insert("DBMSCallsDurationsIn5Minutes");
	
	Return Result;
	
EndFunction

// Returns descriptions of infobase connections.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  IBAdministrationParameters  - Structure - see  ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters.
//    The parameter can be skipped if the same fields have been filled in the structure passed as 
//    the ClusterAdministrationParameters parameter value.
//  Filter - Array - an array of structures that contain connection filter criteria. Each array structure has the following fields:
//             * Property - String - the name of the property to be filtered (see ClusterAdministrationClientServer.ConnectionProperties).
//             * ComparisonType - ComparisonType - the type of comparison between the connection 
//               values and the filter value.
//             * Value - Number, String, Data, Boolean, ValueList, Array, Structure - the value the 
//               matching connection property value is compared with.
//         - Structure - Structure. Key - the name of the connection property (mentioned above). 
//           Value - the value to compare with. When you use this filter description, the comparison always checks for equality.
//
// Returns:
//   Array - see ClusterAdministrationClientServer.ConnectionProperties. 
//
Function InfobaseConnections(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined, Val Filter = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.InfobaseConnections(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		Filter);
	
EndFunction

// Terminates infobase connections according to filter.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  IBAdministrationParameters  - Structure - see  ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters.
//    The parameter can be skipped if the same fields have been filled in the structure passed as 
//    the ClusterAdministrationParameters parameter value.
//  Filter - Array - an array of structures that contain connection filter criteria. Each array structure has the following fields:
//              * Property - String - the name of the property to be filtered (see ClusterAdministrationClientServer.ConnectionProperties).
//              * ComparisonType - ComparisonType - the type of comparison between the connection 
//                values and the filter value.
//              * Value - Number, String, Data, Boolean, ValueList, Array, Structure - the value the 
//                matching connection property value is compared with.
//         - Structure - Structure. Key - the name of the connection property (mentioned above). 
//           Value - the value to compare with. When you use this filter description, the comparison always checks for equality.
//
Procedure TerminateInfobaseConnections(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined, Val Filter = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.TerminateInfobaseConnections(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		Filter);
	
EndProcedure

#EndRegion

#Region SecurityProfiles

// Returns the name of a security profile assigned to the infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  IBAdministrationParameters  - Structure - see  ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters.
//    The parameter can be skipped if the same fields have been filled in the structure passed as 
//    the ClusterAdministrationParameters parameter value.
//
// Returns:
//  String - name of the security profile set for the infobase. If the infobase is not assigned with 
//  a security profile, returns an empty string.
//
Function InfobaseSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.InfobaseSecurityProfile(
		ClusterAdministrationParameters,
		IBAdministrationParameters);
	
EndFunction

// Returns the name of the security profile that was set as the infobase safe mode security profile.
//  
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  IBAdministrationParameters  - Structure - see  ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters.
//    The parameter can be skipped if the same fields have been filled in the structure passed as 
//    the ClusterAdministrationParameters parameter value.
//
// Returns:
//  String - name of the security profile set for the infobase as the safe mode security profile.
//   If the infobase is not assigned with a security profile, returns an empty string.
//  
//
Function InfobaseSafeModeSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.InfobaseSafeModeSecurityProfile(
		ClusterAdministrationParameters,
		IBAdministrationParameters);
	
EndFunction

// Assigns a security profile to an infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  IBAdministrationParameters  - Structure - see  ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters.
//    The parameter can be skipped if the same fields have been filled in the structure passed as 
//    the ClusterAdministrationParameters parameter value.
//  ProfileName - String - the security profile name. If the passed string is empty, the security 
//    profile is disabled for the infobase.
//
Procedure SetInfobaseSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined, Val ProfileName = "") Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.SetInfobaseSecurityProfile(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		ProfileName);
	
EndProcedure

// Assigns a safe-mode security profile to an infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  IBAdministrationParameters  - Structure - see  ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters.
//    The parameter can be skipped if the same fields have been filled in the structure passed as 
//    the ClusterAdministrationParameters parameter value.
//  ProfileName - String - the security profile name. If the passed string is empty, the safe mode 
//    security profile is disabled for the infobase.
//
Procedure SetInfobaseSafeModeSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined, Val ProfileName = "") Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.SetInfobaseSafeModeSecurityProfile(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		ProfileName);
	
EndProcedure

// Checks whether a security profile exists in the server cluster.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//    ProfileName - String - the security profile name.
//
// Returns:
//   Boolean - True if the profile with the specified name exists, False otherwise.
//
Function SecurityProfileExists(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.SecurityProfileExists(
		ClusterAdministrationParameters,
		ProfileName);
	
EndFunction

// Constructor of the structure that defines security profile properties.
//
// Returns:
//   Structure - a structure containing fields:
//     * Name - String - the name of the security profile.
//     * Details - String - details of the security profile.
//     * SafeModeProfile - Boolean - flag that shows whether the security profile can be used as a 
//       security profile of the safe mode (both when the profile is specified for the infobase and 
//       when the SetSafeMode(<Profile name>) is called from the applied solution script).
//     * FullAccessToPrivilegedMode - Boolean - the flag that shows whether the privileged mode can 
//       be set from the safe mode of the security profile.
//     * FileSystemFullAccess - Boolean - the flag that shows whether there are file system access 
//       restrictions. If the value is False, infobase users can access only file system directories 
//       specified in the VirtualDirectories property.
//     * COMObjectFullAccess - Boolean - the flag that shows whether there are restrictions to access
//       COM objects. If the value is False, infobase users can access only COM classes specified in 
//       the COMClasses property.
//     * FullAddInAccess - Boolean - the flag that defines whether there are add-in access 
//       restrictions. If the value is False, infobase users can access only add-ins specified in 
//       the AddIns property.
//     * FullExternalModuleAccess - Boolean - flag that shows whether there are external module 
//       (external reports and data processors, Execute() and Evaluate() calls in the unsafe mode) access restrictions.
//       If the value is False, infobase users can use in the unsafe mode only external modules 
//       specified in the ExternalModules property.
//     * FullOperatingSystemApplicationAccess - Boolean - the flag that shows whether there are 
//       operating system application access restrictions. If the value is False, infobase users can 
//       use operating system applications specified in the OSApplications property.
//     * InternetResourcesFullAccess - Boolean - the flag that shows whether there are restrictions to access
//       internet resources. If the value is False, infobase users can use internet resources 
//       specified in the InternetResources property.
//     * VirtualDirectories - Array - an array of structures (see ClusterAdministrationClientServer.
//       VirtualDirectoryProperties) that describe virtual directories available for access when FullFileSystemAccess =
//       False.
//     * VirtualDirectories - Array - an array of structures (see ClusterAdministrationClientServer.
//       COMClassProperties) that describe COM classes available for access when FullCOMObjectAccess = False.
//     * AddIns - Array - an array of structures (see ClusterAdministrationClientServer.
//       AddInProperties) that describe add-ins available for access when FullAddInAccess
//       = False.
//     * ExternalModules - Array - an array of structures (see ClusterAdministrationClientServer.
//       ExternalModuleProperties) that describe external modules available for access in unsafe mode when
//       ExternalModuleFullAccess = False.
//     * OSApplications - Array - an array of structures (see ClusterAdministrationClientServer.
//       OSApplicationProperties) that describe OS applications available for access when
//       FullOperatingSystemApplicationAccess = False.
//     * InternetResources - Array - an array of structures (see ClusterAdministrationClientServer.
//       InternetResourceProperties) that describe internet resources available for access when FullInternetResourceAccess = False.
//
Function SecurityProfileProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Name", "");
	Result.Insert("Details", "");
	Result.Insert("SafeModeProfile", False);
	Result.Insert("FullAccessToPrivilegedMode", False);
	
	Result.Insert("FullFileSystemAccess", False);
	Result.Insert("FullCOMObjectAccess", False);
	Result.Insert("FullAddInAccess", False);
	Result.Insert("FullExternalModuleAccess", False);
	Result.Insert("FullOperatingSystemApplicationAccess", False);
	Result.Insert("FullInternetResourceAccess", False);
	
	Result.Insert("VirtualDirectories", New Array());
	Result.Insert("COMClasses", New Array());
	Result.Insert("AddIns", New Array());
	Result.Insert("ExternalModules", New Array());
	Result.Insert("OSApplications", New Array());
	Result.Insert("InternetResources", New Array());
	
	Return Result;
	
EndFunction

// Constructor of a structure that describe virtual directory properties.
//
// Returns:
//   Structure - a structure containing fields:
//     * LogicalURL - String - the logical URL of a directory.
//     * PhysicalURL - String - the physical URL of the server directory where virtual directory 
//       data is stored.
//     * Details - String - virtual directory details.
//     * DataReader - Boolean - the flag that shows whether virtual directory data reading is allowed.
//     * DataWriter - Boolean - the flag that shows whether virtual directory data writing is allowed.
//
Function VirtualDirectoryProperties() Export
	
	Result = New Structure();
	
	Result.Insert("LogicalURL");
	Result.Insert("PhysicalURL");
	
	Result.Insert("Details");
	
	Result.Insert("DataReader");
	Result.Insert("DataWriter");
	
	Return Result;
	
EndFunction

// Constructor of a structure that describes COM class properties.
//
// Returns:
//   Structure - a structure containing fields:
//     * Name - String - the name of a COM class that is used as a search key.
//     * Details - String - the COM class details.
//     * FileMoniker - String - the file name used to create an object with the GetCOMObject global 
//       context method. The object second parameter has a blank value.
//     * CLSID - Sting - the COM class ID representation in the Windows system registry format 
//       without curly brackets, which the operating system uses to create the COM class.
//     * Computer - String - the name of the computer on which you can create the COM object.
//
Function COMClassProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Name");
	Result.Insert("Details");
	
	Result.Insert("FileMoniker");
	Result.Insert("CLSID");
	Result.Insert("Computer");
	
	Return Result;
	
EndFunction

// Constructor of the structure that describes the add-in properties.
//
// Returns:
//   Structure - a structure containing fields:
//     * Name - String - the name of the add-in. Used as a search key.
//     * Details - String - the add-in details.
//     * HashSum - String - the add-in hash sum.
//       The hash algorithm is SHA-1 base64.
//
Function AddInProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Name");
	Result.Insert("Details");
	
	Result.Insert("HashSum");
	
	Return Result;
	
EndFunction

// Constructor of the structure that describes external module properties.
//
// Returns:
//   Structure - a structure containing fields:
//     * Name - String - the name of the external module. Used as a search key.
//     * Details - String - the external module details.
//     * HashSum - String - the allowed external module hash sum.
//       The hash algorithm is SHA-1 base64.
//
Function ExternalModuleProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Name");
	Result.Insert("Details");
	
	Result.Insert("HashSum");
	
	Return Result;
	
EndFunction

// Constructor of a structure that defines operating system application properties.
//
// Returns:
//   Structure - a structure containing fields:
//     * Name - String - the name of the operating system application. Used as a search key.
//     * Details - String - the operating system application details.
//     * CommandLinePattern - String - application command line pattern, which consists of 
//       space-separated pattern words.
//
Function OSApplicationProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Name");
	Result.Insert("Details");
	
	Result.Insert("CommandLinePattern");
	
	Return Result;
	
EndFunction

// Constructor of a structure that describes the Internet resource.
//
// Returns:
//   Structure - a structure containing fields:
//     * Name - String - the name of the internet resource. Used as a search key.
//     * Details - String - internet resource details.
//     * Protocol - String - an allowed network protocol. Possible values:
//         HTTP,
//         HTTPS,
//         FTP,
//         FTPS,
//         POP3,
//         SMTP,
//         IMAP,
//     * Address - String - a network address with no protocol and port.
//     * Port - Number - an internet resource port.
//
Function InternetResourceProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Name");
	Result.Insert("Details");
	
	Result.Insert("Protocol");
	Result.Insert("Address");
	Result.Insert("Port");
	
	Return Result;
	
EndFunction

// Returns properties of a security profile.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  ProfileName - String - the security profile name.
//
// Returns:
//   Structure - see ClusterAdministrationClientServer.SecurityProfileProperties. 
//
Function SecurityProfile(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.SecurityProfile(
		ClusterAdministrationParameters,
		ProfileName);
	
EndFunction

// Creates a security profile on the basis of the passed description.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  SecurityProfileProperties - Structure - ClusterAdministrationClientServer. SecurityProfileProperties.
//
Procedure CreateSecurityProfile(Val ClusterAdministrationParameters, Val SecurityProfileProperties) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.CreateSecurityProfile(
		ClusterAdministrationParameters,
		SecurityProfileProperties);
	
EndProcedure

// Sets properties for a security profile on the basis of the passed description.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  SecurityProfileProperties - Structure - ClusterAdministrationClientServer. SecurityProfileProperties.
//
Procedure SetSecurityProfileProperties(Val ClusterAdministrationParameters, Val SecurityProfileProperties)  Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.SetSecurityProfileProperties(
		ClusterAdministrationParameters,
		SecurityProfileProperties);
	
EndProcedure

// Deletes a securiy profile.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  ProfileName - String - the security profile name.
//
Procedure DeleteSecurityProfile(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.DeleteSecurityProfile(
		ClusterAdministrationParameters,
		ProfileName);
	
EndProcedure

#EndRegion

#Region Infobases

// Returns an internal infobase ID.
//
// Parameters:
//  ClusterID - String - the internal ID of a server cluster.
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  ClusterInfobaseAdministrationParameters - Structure - see  ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters.
//
// Returns:
//   String - internal infobase ID.
//
Function InfoBaseID(Val ClusterID, Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.InfoBaseID(
		ClusterID,
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters);
	
EndFunction

// Returns infobase descriptions
//
// Parameters:
//  ClusterID - String - the internal ID of a server cluster.
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  Filter - Structure - infobase filtering criteria.
//
// Returns:
//  Array - an array of structures, which are infobase properties.
//
Function InfobasesProperties(Val ClusterID, Val ClusterAdministrationParameters, Val Filter = Undefined) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.InfobasesProperties(
		ClusterID,
		ClusterAdministrationParameters,
		Filter);
	
EndFunction

#EndRegion

#Region Cluster

// Returns an internal ID of a server cluster.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//
// Returns:
//   String - internal server cluster ID.
//
Function ClusterID(Val ClusterAdministrationParameters) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.ClusterID(ClusterAdministrationParameters);
	
EndFunction

// Returns server cluster descriptions.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  Filter - Structure - server cluster filtering criteria.
//
// Returns:
//   Array - an array of structures, which are cluster properties.
//
Function ClusterProperties(Val ClusterAdministrationParameters, Val Filter = Undefined) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.ClusterProperties(ClusterAdministrationParameters, Filter);
	
EndFunction

#EndRegion

#Region WorkingProcessesServers

// Returns descriptions of working processes.
//
// Parameters:
//  ClusterID - String - the internal ID of a server cluster.
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  Filter - Structure - working process filtering criteria.
//
// Returns:
//   Array - an array of structures, which are working process properties.
//
Function WorkingProcessProperties(Val ClusterID, Val ClusterAdministrationParameters, Val Filter = Undefined) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.WorkingProcessProperties(
		ClusterID,
		ClusterAdministrationParameters,
		Filter);
	
EndFunction

// Returns descriptions of working servers.
//
// Parameters:
//  ClusterID - String - the internal ID of a server cluster.
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  Filter - Structure - working server filtering criteria.
//
// Returns:
//   Array - an array of structures, which are working process properties.
//
Function WorkingServerProperties(Val ClusterID, Val ClusterAdministrationParameters, Val Filter = Undefined) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.WorkingServerProperties(
		ClusterID,
		ClusterAdministrationParameters,
		Filter);
	
EndFunction

#EndRegion

// Returns descriptions of infobase sessions.
//
// Parameters:
//  ClusterID - String - the internal ID of a server cluster.
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  InfobaseID - String - the internal ID of an infobase.
//  Filter - Array - an array of structures that contain session filter criteria. Each array structure has the following fields:
//             * Property - String - the name of the property to be filtered (see ClusterAdministrationClientServer.SessionProperties).
//             * ComparisonType - ComparisonType - a value of the ComparisonType system enumeration.
//             * Value - Number, String, Data, Boolean, ValueList, Array, Structure - the value the 
//               matching session property value is compared with.
//         - Structure - Structure. Key - the name of the session property (mentioned above). Value 
//           - the value to compare with. When you use this filter description, the comparison 
//           always checks for equality.
//  UseDictionary - Boolean - if True, the return value is generated using a dictionary. Otherwise, 
//    the dictionary is not used.
//
// Returns:
//   - Array(Structure) - Array - an array of structures (see ClusterAdministrationClientServer.
//                                  SessionProperties) that describe session properties.
//   - Array(Maps) - Array - an array of map (see ClusterAdministrationClientServer.
//     SessionProperties) that describe session properties in the rac utility notation if UseDictionary = False.
//
Function SessionsProperties(Val ClusterID, Val ClusterAdministrationParameters, Val InfobaseID, Val Filter = Undefined, Val UseDictionary = True) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.SessionsProperties(
		ClusterID,
		ClusterAdministrationParameters,
		InfobaseID,
		Filter,
		UseDictionary);
	
EndFunction

// Returns descriptions of infobase connections.
//
// Parameters:
//  ClusterID - String - the internal ID of a server cluster.
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//  InfobaseID - String - the internal ID of an infobase.
//  ClusterInfobaseAdministrationParameters - Structure - see  ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters.
//  Filter - Array - an array of structures that contain connection filter criteria. Each array structure has the following fields:
//             * Property - String - the name of the property to be filtered (see ClusterAdministrationClientServer.ConnectionsProperties).
//             * ComparisonType - ComparisonType - a value of the ComparisonType system enumeration.
//             * Value - Number, String, Data, Boolean, ValueList, Array, Structure - the value the 
//               matching connection property value is compared with.
//         - Structure - Structure. Key - the name of the connection property (mentioned above). 
//           Value - the value to compare with. When you use this filter description, the comparison 
//           always checks for equality.
//  UseDictionary - Boolean - if True, the return value is generated using a dictionary. Otherwise, 
//    the dictionary is not used.
//
// Returns:
//   - Array(Structure) - Array - an array of structures (see ClusterAdministrationClientServer.
//                                  ConnectionsProperties) that describe connection properties.
//   - Array(Maps) - Array - an array of map (see ClusterAdministrationClientServer.
//     ConnectionsProperties) that describe connection properties in the rac utility notation if UseDictionary = False.
//
Function ConnectionsProperties(Val ClusterID, Val ClusterAdministrationParameters, Val InfobaseID, Val InfobaseAdministrationParameters, Val Filter = Undefined, Val UseDictionary = False) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.ConnectionsProperties(
		ClusterID,
		ClusterAdministrationParameters,
		InfobaseID,
		InfobaseAdministrationParameters,
		Filter,
		UseDictionary);
	
EndFunction

// Returns path to the console client of the administration server.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//
// Returns:
//  String - a path to the console client of the administration server.
//
Function PathToAdministrationServerClient(Val ClusterAdministrationParameters) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.PathToAdministrationServerClient();
	
EndFunction

#EndRegion

#Region Private

// Adds a new filter condition.
//
// Parameters:
//  Filter - Array - an array of structures that contain filter criteria. Each array structure has the following fields:
//             * Property - String - the name of the property used as a filter base.
//             * ComparisonType - ComparisonType - a value of the ComparisonType system enumeration.
//             * Value - Number, String, Data, Boolean, ValueList, Array, Structure - the value the 
//               matching property value is compared with.
//         - Structure - structure: key - Property name, value - value.
//           When you use this filter description, the comparison always checks for equality.
//  Property - String - the name of the property used as a filter base.
//  ComparisonType - ComparisonType - a value of the ComparisonType system enumeration.
//  Value - Number, String, Data, Boolean, ValueList, Array, Structure - the value the matching 
//    property value is compared with.
//
Procedure AddFilterCondition(Filter, Val Property, Val ValueComparisonType, Val Value) Export
	
	If Filter = Undefined Then
		
		If ValueComparisonType = ComparisonType.Equal Then
			
			Filter = New Structure;
			Filter.Insert(Property, Value);
			
		Else
			
			Filter = New Array;
			AddFilterCondition(Filter, Property, ValueComparisonType, Value);
			
		EndIf;
		
	ElsIf TypeOf(Filter) = Type("Structure") Then
		
		NewFilter = New Array;
		
		For each KeyAndValue In Filter Do
			
			AddFilterCondition(NewFilter, KeyAndValue.Key, ComparisonType.Equal, KeyAndValue.Value);
			
		EndDo;
		
		AddFilterCondition(NewFilter, Property, ValueComparisonType, Value);
		
		Filter = NewFilter;
		
	ElsIf TypeOf(Filter) = Type("Array") Then
		
		Filter.Add(New Structure("Property, ComparisonType, Value", Property, ValueComparisonType, Value));
		
	Else
		
		Raise NStr("ru = 'Некорректно задано описание фильтра.'; en = 'Invalid filter description.'; pl = 'Niepoprawnie podano opis filtru.';es_ES = 'La descripción del filtro se ha especificado incorrectamente.';es_CO = 'La descripción del filtro se ha especificado incorrectamente.';tr = 'Geçersiz filtre açıklaması.';it = 'Descrizione filtro non valida.';de = 'Die Filterbeschreibung ist falsch.'");
		
	EndIf;
	
EndProcedure

// Checks whether object properties meet the requirements specified in the filter.
//
// Parameters:
//  ObjectToValidate - Structure.
//    * Key - the name of the property to be compared.
//    * Property - the property value to be compared with the filter value.
//  Filter - Array - an array of structures that contain filter criteria. Each array structure has the following fields:
//             * Property - String - the name of the property used as a filter base.
//             * ComparisonType - ComparisonType - a value of the ComparisonType system enumeration.
//             * Value - Number, String, Data, Boolean, ValueList, Array, Structure - the value the 
//               matching property value is compared with.
//         - Structure - structure: key - Property name, value - value.
//           When you use this filter description, the comparison always checks for equality.
//
// Returns:
//   Boolean - True if the object property values match the filter criteria.
//   Otherwise, False.
//
Function CheckFilterConditions(Val ObjectToCheck, Val Filter = Undefined) Export
	
	If Filter = Undefined Or Filter.Count() = 0 Then
		Return True;
	EndIf;
	
	ConditionsMet = 0;
	
	For Each Condition In Filter Do
		
		If TypeOf(Condition) = Type("Structure") Then
			
			Field = Condition.Property;
			RequiredValue = Condition.Value;
			ValueComparisonType = Condition.ComparisonType;
			
		ElsIf TypeOf(Condition) = Type("KeyAndValue") Then
			
			Field = Condition.Key;
			RequiredValue = Condition.Value;
			ValueComparisonType = ComparisonType.Equal;
			
		Else
			
			Raise NStr("ru = 'Некорректно задан фильтр.'; en = 'Invalid filter.'; pl = 'Niepoprawnie podano filtr.';es_ES = 'El filtro se ha especificado incorrectamente.';es_CO = 'El filtro se ha especificado incorrectamente.';tr = 'Geçersiz filtre.';it = 'Filtro non valido.';de = 'Der Filter ist falsch eingestellt.'");
			
		EndIf;
		
		ValueToCheck = ObjectToCheck[Field];
		ConditionMet = CheckFilterCondition(ValueToCheck, ValueComparisonType, RequiredValue);
		
		If ConditionMet Then
			ConditionsMet = ConditionsMet + 1;
		Else
			Break;
		EndIf;
		
	EndDo;
	
	Return ConditionsMet = Filter.Count();
	
EndFunction

// Checks whether values meet the requirements specified in the filter.
//
// Parameters:
//  ValueToCheck - Number, String, Data, Boolean - the value to compare with the criteria.
//  ComparisonType - ComparisonType - a value of the ComparisonType system enumeration.
//  Value - Number, String, Data, Boolean, ValueList, Array, Structure - the value the matching 
//    property value is compared with.
//
// Returns:
//   Boolean - True, if the value match the criteria. Otherwise, False.
//
Function CheckFilterCondition(Val ValueToCheck, Val ValueComparisonType, Val Value)
	
	If ValueComparisonType = ComparisonType.Equal Then
		
		Return ValueToCheck = Value;
		
	ElsIf ValueComparisonType = ComparisonType.NotEqual Then
		
		Return ValueToCheck <> Value;
		
	ElsIf ValueComparisonType = ComparisonType.Greater Then
		
		Return ValueToCheck > Value;
		
	ElsIf ValueComparisonType = ComparisonType.GreaterOrEqual Then
		
		Return ValueToCheck >= Value;
		
	ElsIf ValueComparisonType = ComparisonType.Less Then
		
		Return ValueToCheck < Value;
		
	ElsIf ValueComparisonType = ComparisonType.LessOrEqual Then
		
		Return ValueToCheck <= Value;
		
	ElsIf ValueComparisonType = ComparisonType.InList Then
		
		If TypeOf(Value) = Type("ValueList") Then
			
			Return Value.FindByValue(ValueToCheck) <> Undefined;
			
		ElsIf TypeOf(Value) = Type("Array") Then
			
			Return Value.Find(ValueToCheck) <> Undefined;
			
		EndIf;
		
	ElsIf ValueComparisonType = ComparisonType.NotInList Then
		
		If TypeOf(Value) = Type("ValueList") Then
			
			Return Value.FindByValue(ValueToCheck) = Undefined;
			
		ElsIf TypeOf(Value) = Type("Array") Then
			
			Return Value.Find(ValueToCheck) = Undefined;
			
		EndIf;
		
	ElsIf ValueComparisonType = ComparisonType.Interval Then
		
		Return ValueToCheck > Value.From AND ValueToCheck < Value.EndDate;
		
	ElsIf ValueComparisonType = ComparisonType.IntervalIncludingBounds Then
		
		Return ValueToCheck >= Value.From AND ValueToCheck <= Value.EndDate;
		
	ElsIf ValueComparisonType = ComparisonType.IntervalIncludingLowerBound Then
		
		Return ValueToCheck >= Value.From AND ValueToCheck < Value.EndDate;
		
	ElsIf ValueComparisonType = ComparisonType.IntervalIncludingUpperBound Then
		
		Return ValueToCheck > Value.From AND ValueToCheck <= Value.EndDate;
		
	EndIf;
	
EndFunction

// Returns the common module that implements a programming interface for administrating the server 
// cluster that corresponds the server cluster connection type.
//
// Parameters:
//  ClusterAdministrationParameters - see ClusterAdministrationClientServer. ClusterAdministrationParameters.
//
// Returns:
//   CommonModule - the common module manager.
//
Function AdministrationManager(Val AdministrationParameters)
	
	If AdministrationParameters.ConnectionType = "COM" Then
		
		Return ClusterAdministrationCOMClientServer;
		
	ElsIf AdministrationParameters.ConnectionType = "RAS" Then
		
		Return ClusterAdministrationRASClientServer;
		
	Else
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Неизвестный тип подключения: %1.'; en = 'Unknown connection type: %1.'; pl = 'Nieznany typ połączenia: %1.';es_ES = 'Tipo de conexión desconocido: %1.';es_CO = 'Tipo de conexión desconocido: %1.';tr = 'Bilinmeyen bağlantı türü: %1.';it = 'Tipo di connessione sconosciuto: %1!';de = 'Unbekannter Verbindungstyp: %1.'"), AdministrationParameters.ConnectionType);
		
	EndIf;
	
EndFunction

// Returns the date that is an empty date in the server cluster registry.
//
// Returns:
//   Date(date and time) - an empty date.
//
Function EmptyDate() Export
	
	Return Date(1, 1, 1, 0, 0, 0);
	
EndFunction

#EndRegion


