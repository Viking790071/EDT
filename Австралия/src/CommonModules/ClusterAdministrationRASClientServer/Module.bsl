#If Not WebClient AND NOT MobileClient Then

#Region Internal

#Region SessionAndJobLock

// Returns the current state of infobase session locks and scheduled job locks.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  IBAdministrationParameters - a structure that describes infobase connection parameters. For 
//    details, see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(). 
//
// Returns: Structure that describes the state of session and scheduled job lock. For details, see 
//  ClusterAdministrationClientServer.SessionAndScheduleJobLockProperties(). 
//
Function InfobaseSessionAndJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters) Export
	
	Result = InfobaseProperties(ClusterAdministrationParameters, IBAdministrationParameters, SessionAndScheduledJobLockPropertiesDictionary());
	
	If Result.DateFrom = ClusterAdministrationClientServer.EmptyDate() Then
		Result.DateFrom = Undefined;
	EndIf;
	
	If Result.DateTo = ClusterAdministrationClientServer.EmptyDate() Then
		Result.DateTo = Undefined;
	EndIf;
	
	If Not ValueIsFilled(Result.KeyCode) Then
		Result.KeyCode = "";
	EndIf;
	
	If Not ValueIsFilled(Result.Message) Then
		Result.Message = "";
	EndIf;
	
	If Not ValueIsFilled(Result.LockParameter) Then
		Result.LockParameter = "";
	EndIf;
	
	Return Result;
	
EndFunction

// Sets the state of infobase session locks and scheduled job locks.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  IBAdministrationParameters - a structure that describes infobase connection parameters. For 
//    details, see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(). 
//  SessionAndJobLockProperties - Structure that describes the state of session and scheduled job 
//    lock. For details, see ClusterAdministrationClientServer.SessionAndScheduleJobLockProperties(). 
//
Procedure SetInfobaseSessionAndJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val SessionAndJobLockProperties) Export
	
	SetInfobaseProperties(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		SessionAndScheduledJobLockPropertiesDictionary(),
		SessionAndJobLockProperties);
	
EndProcedure

// Checks whether administration parameters are filled correctly.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  IBAdministrationParameters - a structure that describes infobase connection parameters. For 
//    details, see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(). 
//    The parameter can be skipped if the same fields have been filled in the structure passed as 
//    the ClusterAdministrationParameters parameter value,
//  CheckClusterAdministrationParameters - Boolean - indicates whether cluster administration 
//                                                parameters check is required,
//  CheckClusterAdministrationParameters - Boolean - Indicates whether cluster administration 
//                                                          parameters check is required.
//
Procedure CheckAdministrationParameters(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined,
	CheckInfobaseAdministrationParameters = True,
	CheckClusterAdministrationParameters = True) Export
	
	
	If CheckClusterAdministrationParameters Or CheckInfobaseAdministrationParameters Then
		
		ClusterID = ClusterID(ClusterAdministrationParameters);
		WorkingProcessProperties(ClusterID, ClusterAdministrationParameters);
		
	EndIf;
	
	If CheckInfobaseAdministrationParameters Then
		
		Dictionary = New Structure();
		Dictionary.Insert("SessionsLock", "sessions-deny");
		
		InfobaseProperties(ClusterAdministrationParameters, IBAdministrationParameters, Dictionary);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ScheduledJobLock

// Returns the current state of infobase scheduled job locks.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  IBAdministrationParameters - a structure that describes infobase connection parameters. For 
//    details, see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(). 
//
// Returns: Boolean.
//
Function InfobaseScheduledJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters) Export
	
	Dictionary = New Structure("JobsLock", "scheduled-jobs-deny");
	
	IBProperties = InfobaseProperties(ClusterAdministrationParameters, IBAdministrationParameters, Dictionary);
	Return IBProperties.JobsLock;
	
EndFunction

// Sets the state of infobase scheduled job locks.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  IBAdministrationParameters - a structure that describes infobase connection parameters. For 
//    details, see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(). 
//  ScheduledJobLock - Boolean, indicates whether infobase scheduled jobs are locked.
//
Procedure SetInfobaseScheduledJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val ScheduledJobLock) Export
	
	Dictionary = New Structure("JobsLock", "scheduled-jobs-deny");
	Properties = New Structure("JobsLock", ScheduledJobLock);
	
	SetInfobaseProperties(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		Dictionary,
		Properties);
	
EndProcedure

#EndRegion

#Region InfobaseSessions

// Returns descriptions of infobase sessions.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  IBAdministrationParameters - a structure that describes infobase connection parameters. For 
//    details, see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(). 
//  Filter - Description of filter criteria for sessions whose descriptions are required.
//    Options:
//      1. Array of structures that describe session filter criteria. Each array structure has the following fields:
//        Property - String - property name to be used in the filter. For valid values, see
//          Return value of ClusterAdministrationClientServer.SessionProperties(),
//        ComparisonType - ComparisonType - value of system enumeration ComparisonType, the type of 
//          comparing the session values and the filter values. The following values are available:
//            ComparisonType.Equal,
//            ComparisonType.NotEqual,
//            ComparisonType.Greater (for numeric values only),
//            ComparisonType.GreaterOrEqual (for numeric values only),
//            ComparisonType.Less (for numeric values only),
//            ComparisonType.LessOrEqual (for numeric values only),
//            ComparisonType.InList,
//            ComparisonType.NotInList,
//            ComparisonType.Interval (for numeric values only),
//            ComparisonType.IntervalIncludingBoundaries (for numeric values only),
//            ComparisonType.IntervalIncludingLowerBoundary (for numeric values only),
//            ComparisonType.IntervalIncludingUpperBoundary (for numeric values only),
//        Value - Number, String, Data, Boolean, ValueList, Array, Structure - the value the 
//          matching session property value is compared with. For ComparisonType.InList and 
//          ComparisonType.NotInList, the passed values are ValueList or Array that contain the set 
//          of values to compare to. For ComparisonType.Interval, ComparisonType.IntervalIncludingBoundaries,
//          ComparisonType.IntervalIncludingLowerBoundary, and ComparisonType.
//          IntervalIncludingUpperBoundary, the passed value contains a structure with the From and 
//          To fields that forms an interval to be compared to.
//    2. Structure (simplified). Key - the session property Name (mentioned above). Value - the 
//    value to compare to. When you use this filter description, the comparison always checks for 
//    equality.
//
// Returns: Array of Structure that describes session properties. For structure descriptions, see 
//  ClusterAdministrationClientServer.SessionProperties(). 
//
Function InfobaseSessions(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Filter = Undefined) Export
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	InfobaseID = InfoBaseID(ClusterID, ClusterAdministrationParameters, IBAdministrationParameters);
	Return SessionsProperties(ClusterID, ClusterAdministrationParameters, InfobaseID, Filter);
	
EndFunction

// Deletes infobase sessions according to filter.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  IBAdministrationParameters - a structure that describes infobase connection parameters. For 
//    details, see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(). 
//  Filter - Description of filter criteria for sessions to be deleted.
//    Options:
//      1. Array of structures that describe session filter criteria. Each array structure has the following fields:
//        Property - String - property name to be used in the filter. For valid values, see
//          Return value of ClusterAdministrationClientServer.SessionProperties(),
//        ComparisonType - ComparisonType - value of system enumeration ComparisonType, the type of 
//          comparing the session values and the filter values. The following values are available:
//            ComparisonType.Equal,
//            ComparisonType.NotEqual,
//            ComparisonType.Greater (for numeric values only),
//            ComparisonType.GreaterOrEqual (for numeric values only),
//            ComparisonType.Less (for numeric values only),
//            ComparisonType.LessOrEqual (for numeric values only),
//            ComparisonType.InList,
//            ComparisonType.NotInList,
//            ComparisonType.Interval (for numeric values only),
//            ComparisonType.IntervalIncludingBoundaries (for numeric values only),
//            ComparisonType.IntervalIncludingLowerBoundary (for numeric values only),
//            ComparisonType.IntervalIncludingUpperBoundary (for numeric values only),
//        Value - Number, String, Data, Boolean, ValueList, Array, Structure - the value the 
//          matching session property value is compared with. For ComparisonType.InList and 
//          ComparisonType.NotInList, the passed values are ValueList or Array that contain the set 
//          of values to compare to. For ComparisonType.Interval, ComparisonType.IntervalIncludingBoundaries,
//          ComparisonType.IntervalIncludingLowerBoundary, and ComparisonType.
//          IntervalIncludingUpperBoundary, the passed value contains a structure with the From and 
//          To fields that forms an interval to be compared to.
//    2. Structure (simplified). Key - the session property Name (mentioned above). Value - the 
//    value to compare to. When you use this filter description, the comparison always checks for 
//    equality.
//
Procedure DeleteInfobaseSessions(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Filter = Undefined) Export
	
	Template = "%rac session --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% terminate --session=%session%";
	
	Parameters = New Map();
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	InfobaseID = InfoBaseID(ClusterID, ClusterAdministrationParameters, IBAdministrationParameters);
	
	AttemptCount = 3;
	AllSessionsTerminated = False;
	
	For CurrentAttempt = 0 To AttemptCount Do
		
		Sessions = SessionsProperties(ClusterID, ClusterAdministrationParameters, InfobaseID, Filter, False);
		
		If Sessions.Count() = 0 Then
			
			AllSessionsTerminated = True;
			Break;
			
		ElsIf CurrentAttempt = AttemptCount Then
			
			Break;
			
		EndIf;
		
		For each Session In Sessions Do
			
			Try
				
				Parameters.Insert("session", Session.Get("session"));
				ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
				
			Except
				
				// The session might close before rac session terminate is called.
				Continue;
				
			EndTry;
			
		EndDo;
		
	EndDo;
	
	If NOT AllSessionsTerminated Then
	
		Raise NStr("ru = 'Не удалось удалить сеансы.'; en = 'Cannot delete sessions.'; pl = 'Nie udało się usunąć sesji.';es_ES = 'No se ha podido eliminar las sesiones.';es_CO = 'No se ha podido eliminar las sesiones.';tr = 'Oturumlar silinemiyor.';it = 'Non è possibile eliminare le sessioni.';de = 'Die Sitzungen konnten nicht gelöscht werden.'");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InfobaseConnections

// Returns descriptions of infobase connections.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  IBAdministrationParameters - a structure that describes infobase connection parameters. For 
//    details, see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(). 
//  Filter - Description of filter criteria for connections whose descriptions are required.
//    Options:
//      1. Array of structures that describes connection filter criteria. Each array structure has the following fields:
//        Property - String - property name to be used in the filter. For valid values, see
//          Return value of ClusterAdministrationClientServer.ConnectionProperties().
//        ComparisonType - ComparisonType - value of system enumeration ComparisonType, the type of 
//          comparing the connection values and the filter values. The following values are available:
//            ComparisonType.Equal,
//            ComparisonType.NotEqual,
//            ComparisonType.Greater (for numeric values only),
//            ComparisonType.GreaterOrEqual (for numeric values only),
//            ComparisonType.Less (for numeric values only),
//            ComparisonType.LessOrEqual (for numeric values only),
//            ComparisonType.InList,
//            ComparisonType.NotInList,
//            ComparisonType.Interval (for numeric values only),
//            ComparisonType.IntervalIncludingBoundaries (for numeric values only),
//            ComparisonType.IntervalIncludingLowerBoundary (for numeric values only),
//            ComparisonType.IntervalIncludingUpperBoundary (for numeric values only),
//        Value - Number, String, Data, Boolean, ValueList, Array, Structure - the value the 
//          matching connection property value is compared with. For ComparisonType.InList and
//          and ComparisonType.NotInList, the passed values are ValueList or Array that contain the 
//          set of values to compare to. For ComparisonType.Interval,
//          ComparisonType.IntervalIncludingBoundaries,
//          ComparisonType.IntervalIncludingLowerBoundary, and ComparisonType.
//          IntervalIncludingUpperBoundary, the passed value contains a structure with the From and 
//          To fields that forms an interval to be compared to.
//    2. Structure (simplified). Key - the connection property Name (mentioned above). Value - the 
//    value to compare to. When you use this filter description, the comparison always checks for 
//    equality.
//
// Returns: Array of Structure that describes connection properties. For structure descriptions, see 
//  ClusterAdministrationClientServer.ConnectionProperties(). 
//
Function InfobaseConnections(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Filter = Undefined) Export
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	InfobaseID = InfoBaseID(ClusterID, ClusterAdministrationParameters, IBAdministrationParameters);
	Return ConnectionsProperties(ClusterID, ClusterAdministrationParameters, InfobaseID, IBAdministrationParameters, Filter, True);
	
EndFunction

// Terminates infobase connections according to filter.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  IBAdministrationParameters - a structure that describes infobase connection parameters. For 
//    details, see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(). 
//  Filter - Description of filter criteria for connections to be terminated.
//    Options:
//      1. Array of structures that describe filter criteria for the connections to be terminated. Each array structure has the following fields:
//        Property - String - property name to be used in the filter. For valid values, see
//          Return value of ClusterAdministrationClientServer.ConnectionProperties().
//        ComparisonType - ComparisonType - value of system enumeration ComparisonType, the type of 
//          comparing the connection values and the filter values. The following values are available:
//            ComparisonType.Equal,
//            ComparisonType.NotEqual,
//            ComparisonType.Greater (for numeric values only),
//            ComparisonType.GreaterOrEqual (for numeric values only),
//            ComparisonType.Less (for numeric values only),
//            ComparisonType.LessOrEqual (for numeric values only),
//            ComparisonType.InList,
//            ComparisonType.NotInList,
//            ComparisonType.Interval (for numeric values only),
//            ComparisonType.IntervalIncludingBoundaries (for numeric values only),
//            ComparisonType.IntervalIncludingLowerBoundary (for numeric values only),
//            ComparisonType.IntervalIncludingUpperBoundary (for numeric values only),
//        Value - Number, String, Data, Boolean, ValueList, Array, Structure - the value the 
//          matching connection property value is compared with. For ComparisonType.InList and
//          and ComparisonType.NotInList, the passed values are ValueList or Array that contain the 
//          set of values to compare to. For ComparisonType.Interval,
//          ComparisonType.IntervalIncludingBoundaries,
//          ComparisonType.IntervalIncludingLowerBoundary, and ComparisonType.
//          IntervalIncludingUpperBoundary, the passed value contains a structure with the From and 
//          To fields that forms an interval to be compared to.
//    2. Structure (simplified). Key - the connection property Name (mentioned above). Value - the 
//    value to compare to. When you use this filter description, the comparison always checks for 
//    equality.
//
Procedure TerminateInfobaseConnections(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Filter = Undefined) Export
	
	Template = "%rac connection --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% disconnect --process=%process% --connection=%connection% --infobase-user=%?infobase-user% --infobase-pwd=%?infobase-pwd%";
	
	Parameters = New Map();
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	InfobaseID = InfoBaseID(ClusterID, ClusterAdministrationParameters, IBAdministrationParameters);
	Parameters.Insert("infobase", InfobaseID);
	FillIBAuthenticationParameters(IBAdministrationParameters, Parameters);
	
	Value = New Array;
	Value.Add("1CV8");               // ID of 1C:Enterprise application running in thick client mode.
	Value.Add("1CV8C");              // ID of 1C:Enterprise application running in thin client mode.
	Value.Add("WebClient");          // ID of 1C:Enterprise application running in web client mode.
	Value.Add("Designer");           // ID of Designer.
	Value.Add("COMConnection");      // ID of 1C:Enterprise external COM connection session.
	Value.Add("WSConnection");       // ID of web service session.
	Value.Add("BackgroundJob");      // ID of job processing session.
	Value.Add("WebServerExtension"); // ID of web server extension.

	ClusterAdministrationClientServer.AddFilterCondition(Filter, "ClientApplicationID", ComparisonType.InList, Value);
	
	AttemptCount = 3;
	AllConnectionsTerminated = False;
	
	For CurrentAttempt = 0 To AttemptCount Do
	
		Connections = ConnectionsProperties(ClusterID, ClusterAdministrationParameters, InfobaseID, IBAdministrationParameters, Filter, False);
		
		If Connections.Count() = 0 Then
			
			AllConnectionsTerminated = True;
			Break;
			
		ElsIf CurrentAttempt = AttemptCount Then
			
			Break;
			
		EndIf;
	
		For each Connection In Connections Do
			
			Try
				
				Parameters.Insert("process", Connection.Get("process"));
				Parameters.Insert("connection", Connection.Get("connection"));
				ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
				
			Except
				
				// The connection might terminate before rac connection disconnect is called.
				Continue;
				
			EndTry;
			
		EndDo;
		
	EndDo;
	
	If NOT AllConnectionsTerminated Then
	
		Raise NStr("ru = 'Не удалось разорвать соединения.'; en = 'Cannot close connections.'; pl = 'Nie udało się przerwać połączenie.';es_ES = 'No se ha podido desconectar.';es_CO = 'No se ha podido desconectar.';tr = 'Bağlantılar kapatılamıyor.';it = 'Non è possibile terminare le connessioni.';de = 'Die Verbindungen konnten nicht unterbrochen werden.'");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region SecurityProfiles

// Returns the name of a security profile assigned to the infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  IBAdministrationParameters - a structure that describes infobase connection parameters. For 
//    details, see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(). 
//
// Returns: String - name of the security profile set for the infobase. If the infobase is not 
//  assigned with a security profile, returns an empty string.
//
Function InfobaseSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters) Export
	
	Dictionary = New Structure();
	Dictionary.Insert("ProfileName", "security-profile-name");
	
	Result = InfobaseProperties(ClusterAdministrationParameters, IBAdministrationParameters, Dictionary).ProfileName;
	If ValueIsFilled(Result) Then
		Return Result;
	Else
		Return "";
	EndIf;
	
EndFunction

// Returns the name of the security profile that was set as the infobase safe mode security profile.
//  
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  IBAdministrationParameters - a structure that describes infobase connection parameters. For 
//    details, see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(). 
//
// Returns: String - name of the security profile set for the infobase as the safe mode security 
//  profile. If the infobase is not assigned with a security profile, returns an empty string.
//  
//
Function InfobaseSafeModeSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters) Export
	
	Dictionary = New Structure();
	Dictionary.Insert("ProfileName", "safe-mode-security-profile-name");
	
	Result = InfobaseProperties(ClusterAdministrationParameters, IBAdministrationParameters, Dictionary).ProfileName;
	If ValueIsFilled(Result) Then
		Return Result;
	Else
		Return "";
	EndIf;
	
EndFunction

// Assigns a security profile to an infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  IBAdministrationParameters - a structure that describes infobase connection parameters. For 
//    details, see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(). 
//  ProfileName - String, a security profile name. If the passed string is empty, the security 
//    profile is disabled for the infobase.
//
Procedure SetInfobaseSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val ProfileName = "") Export
	
	Dictionary = New Structure();
	Dictionary.Insert("ProfileName", "security-profile-name");
	
	Values = New Structure();
	Values.Insert("ProfileName", ProfileName);
	
	SetInfobaseProperties(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		Dictionary,
		Values);
	
EndProcedure

// Assigns a safe-mode security profile to an infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  IBAdministrationParameters - a structure that describes infobase connection parameters. For 
//    details, see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(). 
//  ProfileName - String, a security profile name. If the passed string is empty, the safe mode 
//    security profile is disabled for the infobase.
//
Procedure SetInfobaseSafeModeSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val ProfileName = "") Export
	
	Dictionary = New Structure();
	Dictionary.Insert("ProfileName", "safe-mode-security-profile-name");
	
	Values = New Structure();
	Values.Insert("ProfileName", ProfileName);
	
	SetInfobaseProperties(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		Dictionary,
		Values);
	
EndProcedure

// Checks whether a security profile exists in the server cluster.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  ProfileName - String, a security profile name.
//
Function SecurityProfileExists(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	Filter = New Structure("Name", ProfileName);
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	
	SecurityProfiles = GetSecurityProfiles(ClusterID, ClusterAdministrationParameters, Filter);
	
	Return (SecurityProfiles.Count() = 1);
	
EndFunction

// Returns properties of a security profile.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  ProfileName - String, a security profile name.
//
// Returns: Structure describing a security profile. For description, see
//  ClusterAdministrationClientServer.SecurityProfileProperties().
//
Function SecurityProfile(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	Filter = New Structure("Name", ProfileName);
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	
	SecurityProfiles = GetSecurityProfiles(ClusterID, ClusterAdministrationParameters, Filter);
	
	If SecurityProfiles.Count() <> 1 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'В кластере серверов %1 не зарегистрирован профиль безопасности %2.'; en = 'The security profile %2 is not registered in the server cluster %1.'; pl = 'W klasterze serwerów %1 nie zarejestrowano profilu bezpieczeństwa %2.';es_ES = 'En el clúster de servidores %1 no se ha registrado perfil de seguridad %2.';es_CO = 'En el clúster de servidores %1 no se ha registrado perfil de seguridad %2.';tr = 'Güvenlik profili %2 %1 sunucu kümesinde kayıtlı değil.';it = 'Nel cluster di server %1 non è registrato un profilo di sicurezza %2.';de = 'Im Server-Cluster %1 ist kein Sicherheitsprofil %2 registriert.'"), ClusterID, ProfileName);
	EndIf;
	
	Result = SecurityProfiles[0];
	Result = ConvertAccessListsUsagePropertyValues(Result);
	
	// Virtual directories
	Result.Insert("VirtualDirectories",
		GetVirtualDirectories(ClusterID, ClusterAdministrationParameters, ProfileName));
	
	// Allowed COM classes.
	Result.Insert("COMClasses",
		GetAllowedCOMClasses(ClusterID, ClusterAdministrationParameters, ProfileName));
	
	// Add-ins
	Result.Insert("AddIns",
		GetAllowedAddIns(ClusterID, ClusterAdministrationParameters, ProfileName));
	
	// External modules
	Result.Insert("ExternalModules",
		GetAllowedExternalModules(ClusterID, ClusterAdministrationParameters, ProfileName));
	
	// OS applications
	Result.Insert("OSApplications",
		GetAllowedOSApplications(ClusterID, ClusterAdministrationParameters, ProfileName));
	
	// Internet resources
	Result.Insert("InternetResources",
		GetAllowedInternetResources(ClusterID, ClusterAdministrationParameters, ProfileName));
	
	Return Result;
	
EndFunction

// Creates a security profile on the basis of the passed description.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  SecurityProfileProperties - Structure that describes the properties of the security profile. For 
//    the description details, see ClusterAdministrationClientServer.SecurityProfileProperties(). 
//
Procedure CreateSecurityProfile(Val ClusterAdministrationParameters, Val SecurityProfileProperties) Export
	
	ProfileName = SecurityProfileProperties.Name;
	
	Filter = New Structure("Name", ProfileName);
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	
	SecurityProfiles = GetSecurityProfiles(ClusterID, ClusterAdministrationParameters, Filter);
	
	If SecurityProfiles.Count() = 1 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'В кластере серверов %1 уже зарегистрирован профиль безопасности %2.'; en = 'The security profile %2 is already registered in the server cluster %1.'; pl = 'W klasterze serwerów %1 już jest zarejestrowany profil bezpieczeństwa %2.';es_ES = 'En el clúster de servidores %1 ya se ha registrado perfil de seguridad %2.';es_CO = 'En el clúster de servidores %1 ya se ha registrado perfil de seguridad %2.';tr = 'Güvenlik profili %2, %1 sunucu kümesinde zaten kayıtlı.';it = 'Nel cluster di server %1 è già registrato un profilo di sicurezza %2.';de = 'Im Servercluster %1 ist bereits ein Sicherheitsprofil %2 registriert.'"), ClusterID, ProfileName);
	EndIf;
	
	UpdateSecurityProfileProperties(ClusterAdministrationParameters, SecurityProfileProperties, False);
	
EndProcedure

// Sets properties for a security profile on the basis of the passed description.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  SecurityProfileProperties - Structure that describes the properties of the security profile. For 
//    the description details, see ClusterAdministrationClientServer.SecurityProfileProperties(). 
//
Procedure SetSecurityProfileProperties(Val ClusterAdministrationParameters, Val SecurityProfileProperties)  Export
	
	ProfileName = SecurityProfileProperties.Name;
	
	Filter = New Structure("Name", ProfileName);
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	
	SecurityProfiles = GetSecurityProfiles(ClusterID, ClusterAdministrationParameters, Filter);
	
	If SecurityProfiles.Count() <> 1 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'В кластере серверов %1 не зарегистрирован профиль безопасности %2.'; en = 'The security profile %2 is not registered in the server cluster %1.'; pl = 'W klasterze serwerów %1 nie zarejestrowano profilu bezpieczeństwa %2.';es_ES = 'En el clúster de servidores %1 no se ha registrado perfil de seguridad %2.';es_CO = 'En el clúster de servidores %1 no se ha registrado perfil de seguridad %2.';tr = 'Güvenlik profili %2 %1 sunucu kümesinde kayıtlı değil.';it = 'Nel cluster di server %1 non è registrato un profilo di sicurezza %2.';de = 'Im Server-Cluster %1 ist kein Sicherheitsprofil %2 registriert.'"), ClusterID, ProfileName);
	EndIf;
	
	UpdateSecurityProfileProperties(ClusterAdministrationParameters, SecurityProfileProperties, True);
	
EndProcedure

// Deletes a securiy profile.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  ProfileName - String, a security profile name.
//
Procedure DeleteSecurityProfile(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	Template = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% remove --name=%name%";
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	Parameters.Insert("name", ProfileName);
	
	ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	
EndProcedure

#EndRegion

#Region Infobases

// Returns an internal infobase ID.
//
// Parameters:
//  ClusterID - String - internal ID of a server cluster,
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  InfobaseAdministrationParameters - Structure that describes the infobase connection parameters. 
//    For more details, see ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters().
//
// Returns: String, an internal infobase ID.
//
Function InfoBaseID(Val ClusterID, Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters) Export
	
	Filter = New Structure("name", InfobaseAdministrationParameters.NameInCluster);
	
	Infobases = InfobasesProperties(ClusterID, ClusterAdministrationParameters, Filter);
	
	If Infobases.Count() = 1 Then
		Return Infobases[0].Get("infobase");
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'В кластере серверов %1 не зарегистрирована информационная база %2.'; en = 'The infobase %2 is not registered in the server cluster %1.'; pl = 'W klasterze serwerów %1 nie zarejestrowano bazy informacyjnej %2.';es_ES = 'En el clúster de servidores %1 no se ha registrado base de información %2.';es_CO = 'En el clúster de servidores %1 no se ha registrado base de información %2.';tr = 'Veritabanı %2 %1 sunucu kümesinde kayıtlı değil.';it = 'Nel cluster di server %1 non è registrato un database %2.';de = 'Im Server-Cluster %1 ist die Informationsbasis %2 nicht registriert.'"), ClusterID, InfobaseAdministrationParameters.NameInCluster);
	EndIf;
	
EndFunction

// Returns infobase descriptions
//
// Parameters:
//  ClusterID - String - internal ID of a server cluster,
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  Filter - Structure - infobase filtering criteria.
//
// Returns: Array(Structure).
//
Function InfobasesProperties(Val ClusterID, Val ClusterAdministrationParameters, Val Filter = Undefined) Export
	
	Template = "%rac infobase summary --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% list";
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	OutputStream = ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	Result = OutputParser(OutputStream, Undefined, Filter);
	Return Result;
	
EndFunction

#EndRegion

#Region Cluster

// Returns an internal ID of a server cluster.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//
// Returns: String - an internal ID of a server cluster.
//
Function ClusterID(Val ClusterAdministrationParameters) Export
	
	Filter = New Structure("port", ClusterAdministrationParameters.ClusterPort);
	
	Clusters = ClusterProperties(ClusterAdministrationParameters, Filter);
	
	If Clusters.Count() = 1 Then
		Return Clusters[0].Get("cluster");
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не обнаружен кластер серверов с портом %1.'; en = 'The server cluster with port %1 is not found.'; pl = 'Nie znaleziono klastera serwerów z portem %1.';es_ES = 'Clúster del servidor con el puerto .%1 no encontrado';es_CO = 'Clúster del servidor con el puerto .%1 no encontrado';tr = '%1Bağlantı noktası olan sunucu kümesi bulunamadı';it = 'Non è stato trovato un cluster di server con la porta %1.';de = 'Keine Server-Cluster mit %1 Port erkannt.'"), ClusterAdministrationParameters.ClusterPort);
	EndIf;
	
EndFunction

// Returns server cluster descriptions.
//
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  Filter - Structure - server cluster filtering criteria.
//
// Returns: Array(Structure).
//
Function ClusterProperties(Val ClusterAdministrationParameters, Val Filter = Undefined) Export
	
	Template = "%rac cluster list";
	OutputStream = ExecuteCommand(Template, ClusterAdministrationParameters);
	Result = OutputParser(OutputStream, Undefined, Filter);
	Return Result;
	
EndFunction

#EndRegion

#Region WorkingProcessesServers

// Returns descriptions of working processes.
//
// Parameters:
//  ClusterID - String - internal ID of a server cluster,
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  Filter - Structure - working process filtering criteria.
//
// Returns: Array(Structure).
//
Function WorkingProcessProperties(Val ClusterID, Val ClusterAdministrationParameters, Val Filter = Undefined) Export
	
	Template = "%rac process --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% list --server=%server%";
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	Result = New Array();
	WorkingServers = WorkingServerProperties(ClusterID, ClusterAdministrationParameters);
	For Each WorkingServer In WorkingServers Do
		Parameters.Insert("server", WorkingServer.Get("server"));
		OutputStream = ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
		ServerWorkingProcesses = OutputParser(OutputStream, Undefined, Filter);
		For Each WorkingProcess In ServerWorkingProcesses Do
			Result.Add(WorkingProcess);
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

// Returns descriptions of working servers.
//
// Parameters:
//  ClusterID - String - internal ID of a server cluster,
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  Filter - Structure - working server filtering criteria.
//
// Returns: Array(Structure).
//
Function WorkingServerProperties(Val ClusterID, Val ClusterAdministrationParameters, Val Filter = Undefined) Export
	
	Template = "%rac server --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% list";
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	OutputStream = ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	Result = OutputParser(OutputStream, Undefined, Filter);
	Return Result;
	
EndFunction

#EndRegion

// Returns descriptions of infobase sessions.
//
// Parameters:
//  ClusterID - String - internal ID of a server cluster,
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  InfobaseID - String - an internal ID of an infobase,
//  InfobaseAdministrationParameters - Structure that describes the infobase connection parameters. 
//    For more details, see ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters().
//  Filter - Description of filter criteria for sessions whose descriptions are required.
//    Options:
//      1. Array of structures that describe session filter criteria. Each array structure has the following fields:
//        Property - String - property name to be used in the filter. For valid values, see
//          Return value of ClusterAdministrationClientServer.SessionProperties(),
//        ComparisonType - ComparisonType - value of system enumeration ComparisonType, the type of 
//          comparing the session values and the filter values. The following values are available:
//            ComparisonType.Equal,
//            ComparisonType.NotEqual,
//            ComparisonType.Greater (for numeric values only),
//            ComparisonType.GreaterOrEqual (for numeric values only),
//            ComparisonType.Less (for numeric values only),
//            ComparisonType.LessOrEqual (for numeric values only),
//            ComparisonType.InList,
//            ComparisonType.NotInList,
//            ComparisonType.Interval (for numeric values only),
//            ComparisonType.IntervalIncludingBoundaries (for numeric values only),
//            ComparisonType.IntervalIncludingLowerBoundary (for numeric values only),
//            ComparisonType.IntervalIncludingUpperBoundary (for numeric values only),
//        Value - Number, String, Data, Boolean, ValueList, Array, Structure - the value the 
//          matching session property value is compared with. For ComparisonType.InList and 
//          ComparisonType.NotInList, the passed values are ValueList or Array that contain the set 
//          of values to compare to. For ComparisonType.Interval, ComparisonType.IntervalIncludingBoundaries,
//          ComparisonType.IntervalIncludingLowerBoundary, and ComparisonType.
//          IntervalIncludingUpperBoundary, the passed value contains a structure with the From and 
//          To fields that forms an interval to be compared to.
//    2. Structure (simplified). Key - the session property Name (mentioned above). Value - the 
//    value to compare to. When you use this description option, the comparison filter always checks 
//    for equality
//  UseDictionary - Boolean - If True, apply the dictionary to fill in the return result. If False, 
//    do not apply the dictionaty.
//
// Return value: Array(Structure), Array(Map) - an array of structures that describe session 
// properties (structure description, for more details see ClusterAdministrationClientServer. 
// SessionProperties()) or (If UseDictionary = False) an array of map that describes session properties in rac notation.
//
Function SessionsProperties(Val ClusterID, Val ClusterAdministrationParameters, Val InfobaseID, Val Filter = Undefined, Val UseDictionary = True) Export
	
	Template = "%rac session --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% list --infobase=%infobase%";	
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	Parameters.Insert("infobase", InfobaseID);
	
	If UseDictionary Then
		Dictionary = SessionPropertiesDictionary();
	Else
		Dictionary = Undefined;
		Filter = FilterToRacNotation(Filter, SessionPropertiesDictionary());
	EndIf;
	
	OutputStream = ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	Result = OutputParser(OutputStream, Dictionary, Filter);
	Return Result;
	
EndFunction

// Returns descriptions of infobase connections.
//
// Parameters:
//  ClusterID - String - internal ID of a server cluster,
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  InfobaseID - String - an internal ID of an infobase,
//  InfobaseAdministrationParameters - Structure that describes the infobase connection parameters. 
//    For more details, see ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters().
//  Filter - Description of filter criteria for connections whose descriptions are required.
//    Options:
//      1. Array of structures that describes connection filter criteria. Each array structure has the following fields:
//        Property - String - property name to be used in the filter. For valid values, see
//          Return value of ClusterAdministrationClientServer.ConnectionProperties().
//        ComparisonType - ComparisonType - value of system enumeration ComparisonType, the type of 
//          comparing the connection values and the filter values. The following values are available:
//            ComparisonType.Equal,
//            ComparisonType.NotEqual,
//            ComparisonType.Greater (for numeric values only),
//            ComparisonType.GreaterOrEqual (for numeric values only),
//            ComparisonType.Less (for numeric values only),
//            ComparisonType.LessOrEqual (for numeric values only),
//            ComparisonType.InList,
//            ComparisonType.NotInList,
//            ComparisonType.Interval (for numeric values only),
//            ComparisonType.IntervalIncludingBoundaries (for numeric values only),
//            ComparisonType.IntervalIncludingLowerBoundary (for numeric values only),
//            ComparisonType.IntervalIncludingUpperBoundary (for numeric values only),
//        Value - Number, String, Data, Boolean, ValueList, Array, Structure - the value the 
//          matching connection property value is compared with. For ComparisonType.InList and
//          and ComparisonType.NotInList, the passed values are ValueList or Array that contain the 
//          set of values to compare to. For ComparisonType.Interval,
//          ComparisonType.IntervalIncludingBoundaries,
//          ComparisonType.IntervalIncludingLowerBoundary, and ComparisonType.
//          IntervalIncludingUpperBoundary, the passed value contains a structure with the From and 
//          To fields that forms an interval to be compared to.
//    2. Structure (simplified). Key - the connection property Name (mentioned above). Value - the 
//    value to compare to. When you use this description option, the comparison filter always checks 
//    for equality
//  UseDictionary - Boolean - If True, apply the dictionary to fill in the return result. If False, 
//    do not apply the dictionaty.
//
// Return value: Array(Structure), Array(Map) - an array of structures that describe connection 
// properties (structure description, for more details see ClusterAdministrationClientServer. 
// ConnectionProperties()) or (If UseDictionary = False) an array of map that describes connection properties in rac notation.
//
Function ConnectionsProperties(Val ClusterID, Val ClusterAdministrationParameters, Val InfobaseID, Val InfobaseAdministrationParameters, Val Filter = Undefined, Val UseDictionary = False) Export
	
	Template = "%rac connection --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% list --process=%process% --infobase=%infobase% --infobase-user=%?infobase-user% --infobase-pwd=%?infobase-pwd%";
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	Parameters.Insert("infobase", InfobaseID);
	FillIBAuthenticationParameters(InfobaseAdministrationParameters, Parameters);
	
	If UseDictionary Then
		Dictionary = ConnectionPropertiesDictionary();
	Else
		Dictionary = Undefined;
		Filter = FilterToRacNotation(Filter, ConnectionPropertiesDictionary());
	EndIf;
	
	Result = New Array();
	WorkingProcesses = WorkingProcessProperties(ClusterID, ClusterAdministrationParameters);
	
	For Each WorkingProcess In WorkingProcesses Do
		
		Parameters.Insert("process", WorkingProcess.Get("process"));
		OutputStream = ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
		WorkingProcessConnections = OutputParser(OutputStream, Dictionary, Filter);
		For Each Connection In WorkingProcessConnections Do
			If Not UseDictionary Then
				Connection.Insert("process", WorkingProcess.Get("process"));
			EndIf;
			Result.Add(Connection);
		EndDo;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Returns path to the console client of the administration server.
//
// Returns:
//  String - a path to the console client of the administration server.
//
Function PathToAdministrationServerClient() Export
	
	StartDirectory = PlatformExecutableFilesDirectory();
	Client = StartDirectory + "rac";
	
	SysInfo = New SystemInfo();
	If (SysInfo.PlatformType = PlatformType.Windows_x86) Or (SysInfo.PlatformType = PlatformType.Windows_x86_64) Then
		Client = Client + ".exe";
	EndIf;
	
	Return Client;
	
EndFunction

#EndRegion

#Region Private

// Returns a directory of platform executable files.
//
// Returns:
//  String - a directory of platform executable files.
//
Function PlatformExecutableFilesDirectory()
	
	Result = BinDir();
	SeparatorChar = GetPathSeparator();
	
	If Not StrEndsWith(Result, SeparatorChar) Then
		Result = Result + SeparatorChar;
	EndIf;
	
	Return Result;
	
EndFunction

// Returns values of infobase properties.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  InfobaseAdministrationParameters - Structure that describes the infobase connection parameters. 
//    For more details, see ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters().
//  Dictionary - Structure - correspondence between names of API properties and rac output stream.
//
// Returns:
//   Structure - an infobase description generated from the passed dictionary.
//
Function InfobaseProperties(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Dictionary)
	
	Template = "%rac infobase --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% info --infobase=%infobase% --infobase-user=%?infobase-user% --infobase-pwd=%?infobase-pwd%";
	
	Parameters = New Map();
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	InfobaseID = InfoBaseID(ClusterID, ClusterAdministrationParameters, IBAdministrationParameters);
	Parameters.Insert("infobase", InfobaseID);
	FillIBAuthenticationParameters(IBAdministrationParameters, Parameters);
	
	OutputStream = ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	Result = OutputParser(OutputStream, Dictionary);
	Return Result[0];
	
EndFunction

// Sets values of infobase properties.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  InfobaseAdministrationParameters - Structure that describes the infobase connection parameters. 
//    For more details, see ClusterAdministrationClientServer. ClusterInfobaseAdministrationParameters().
//  Dictionary - Structure - correspondence between names of API properties and rac output stream.
//  PropertyValues - Structure - values of infobase properties to set:
//    * Key - property name in API notation.
//    * Value - a value to set for the property.
//
Procedure SetInfobaseProperties(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Dictionary, Val PropertiesValues)
	
	Template = "%rac infobase --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% update --infobase=%infobase% --infobase-user=%?infobase-user% --infobase-pwd=%?infobase-pwd%";
	
	Parameters = New Map();
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	InfobaseID = InfoBaseID(ClusterID, ClusterAdministrationParameters, IBAdministrationParameters);
	Parameters.Insert("infobase", InfobaseID);
	FillIBAuthenticationParameters(IBAdministrationParameters, Parameters);
	
	FillParametersByDictionary(Dictionary, PropertiesValues, Parameters, Template);
	
	ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	
EndProcedure

// Returns security profile descriptions.
//
// Parameters:
//  ClusterID - String - internal ID of a server cluster,
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  Filter - Structure - security profile filtering criteria.
//
// Returns: Array(Structure).
//
Function GetSecurityProfiles(Val ClusterID, Val ClusterAdministrationParameters, Val Filter = Undefined)
	
	Template = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% list";
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	OutputStream = ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	Result = OutputParser(OutputStream, SecurityProfilePropertiesDictionary(), Filter);
	Return Result;
	
EndFunction

// Returns descriptions of virtual directories.
//
// Parameters:
//  ClusterID - String - internal ID of a server cluster,
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  ProfileName - String - name of a security profile,
//  Filter - Structure - virtual directory filtering criteria.
//
// Returns: Array(Structure).
//
Function GetVirtualDirectories(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return AccessManagementLists(
		ClusterID,
		ClusterAdministrationParameters,
		ProfileName,
		"directory", // Do not localize.
		VirtualDirectoryPropertiesDictionary());
	
EndFunction

// Returns descriptions of COM classes.
//
// Parameters:
//  ClusterID - String - internal ID of a server cluster,
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  ProfileName - String - name of a security profile,
//  Filter - Structure - COM class filtering criteria.
//
// Returns: Array(Structure).
//
Function GetAllowedCOMClasses(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return AccessManagementLists(
		ClusterID,
		ClusterAdministrationParameters,
		ProfileName,
		"com", // Do not localize.
		COMClassPropertiesDictionary());
	
EndFunction

// Returns descriptions of add-ins.
//
// Parameters:
//  ClusterID - String - internal ID of a server cluster,
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  ProfileName - String - name of a security profile,
//  Filter - Structure - add-in filtering criteria.
//
// Returns: Array(Structure).
//
Function GetAllowedAddIns(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return AccessManagementLists(
		ClusterID,
		ClusterAdministrationParameters,
		ProfileName,
		"addin", // Do not localize.
		AddInPropertiesDictionary());
	
EndFunction

// Returns descriptions of external modules.
//
// Parameters:
//  ClusterID - String - internal ID of a server cluster,
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  ProfileName - String - name of a security profile,
//  Filter - Structure - external module filtering criteria.
//
// Returns: Array(Structure).
//
Function GetAllowedExternalModules(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return AccessManagementLists(
		ClusterID,
		ClusterAdministrationParameters,
		ProfileName,
		"module", // Do not localize.
		ExternalModulePropertiesDictionary());
	
EndFunction

// Returns descriptions of OS applications.
//
// Parameters:
//  ClusterID - String - internal ID of a server cluster,
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  ProfileName - String - name of a security profile,
//  Filter - Structure - OS application filtering criteria.
//
// Returns: Array(Structure).
//
Function GetAllowedOSApplications(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return AccessManagementLists(
		ClusterID,
		ClusterAdministrationParameters,
		ProfileName,
		"app", // Do not localize.
		OSApplicationPropertiesDictionary());
	
EndFunction

// Returns descriptions of Internet resources.
//
// Parameters:
//  ClusterID - String - internal ID of a server cluster,
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  ProfileName - String - name of a security profile,
//  Filter - Structure - Internet resource filtering criteria.
//
// Returns: Array(Structure).
//
Function GetAllowedInternetResources(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return AccessManagementLists(
		ClusterID,
		ClusterAdministrationParameters,
		ProfileName,
		"inet", // Do not localize.
		InternetResourcePropertiesDictionary());
	
EndFunction

// Returns descriptions of access control list items.
//
// Parameters:
//  ClusterID - String - internal ID of a server cluster,
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  ProfileName - String - name of a security profile,
//  ListName - String - name of an access control list (acl) in rac notation,
//  Dictionary - Structure - correspondence between property names in rac output stream and in the required description,
//  Filter - Structure - access control list item filtering criteria.
//
// Returns: Array(Structure).
//
Function AccessManagementLists(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val ListName, Val Dictionary, Val Filter = Undefined)
	
	Template = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% acl --name=%name% directory list";
	Template = StrReplace(Template, "directory", ListName);
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	Parameters.Insert("name", ProfileName);
	
	OutputStream = ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	Result = OutputParser(OutputStream, Dictionary, Filter);
	Return Result;
	
EndFunction

// Updates the security profile properties (including acl content and usage updates).
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  SecurityProfileProperties - Structure that describes the properties of the security profile. For 
//    the description details, see ClusterAdministrationClientServer.SecurityProfileProperties(). 
//  ClearAccessManagementLists - Boolean - indicates whether the current acl content must be cleared in advance.
//
Procedure UpdateSecurityProfileProperties(Val ClusterAdministrationParameters, Val SecurityProfileProperties, Val ClearAccessManagementLists)
	
	ProfileName = SecurityProfileProperties.Name;
	
	Template = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% update ";
	
	Parameters = New Map();
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	Parameters.Insert("cluster", ClusterID);
	
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	FillParametersByDictionary(SecurityProfilePropertiesDictionary(False), SecurityProfileProperties, Parameters, Template);
	
	ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	
	AccessManagementListsUsagePropertiesDictionary = AccessManagementListUsagePropertiesDictionary();
	For Each DictionaryFragment In AccessManagementListsUsagePropertiesDictionary Do
		SetAccessManagementListUsage(ClusterID, ClusterAdministrationParameters, ProfileName, DictionaryFragment.Value, Not SecurityProfileProperties[DictionaryFragment.Key]);
	EndDo;
	
	// Virtual directories
	ListName = "directory";
	CurrentDictionary = VirtualDirectoryPropertiesDictionary();
	If ClearAccessManagementLists Then
		VirtualDirectoriesToDelete = AccessManagementLists(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary);
		For Each VirtualDirectoryToDelete In VirtualDirectoriesToDelete Do
			DeleteAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, VirtualDirectoryToDelete.LogicalURL);
		EndDo;
	EndIf;
	VirtualDirectoriesToCreate = SecurityProfileProperties.VirtualDirectories;
	For Each VirtualDirectoryToCreate In VirtualDirectoriesToCreate Do
		CreateAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary, VirtualDirectoryToCreate);
	EndDo;
	
	// Allowed COM classes.
	ListName = "com";
	CurrentDictionary = COMClassPropertiesDictionary();
	If ClearAccessManagementLists Then
		COMClassesToDelete = AccessManagementLists(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary);
		For Each COMClassToDelete In COMClassesToDelete Do
			DeleteAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, COMClassToDelete.Name);
		EndDo;
	EndIf;
	COMClassesToCreate = SecurityProfileProperties.COMClasses;
	For Each COMClassToCreate In COMClassesToCreate Do
		CreateAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary, COMClassToCreate);
	EndDo;
	
	// Add-ins
	ListName = "addin";
	CurrentDictionary = AddInPropertiesDictionary();
	If ClearAccessManagementLists Then
		AddInsToDelete = AccessManagementLists(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary);
		For Each AddInToDelete In AddInsToDelete Do
			DeleteAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, AddInToDelete.Name);
		EndDo;
	EndIf;
	AddInsToCreate = SecurityProfileProperties.AddIns;
	For Each AddInToCreate In AddInsToCreate Do
		CreateAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary, AddInToCreate);
	EndDo;
	
	// External modules
	ListName = "module";
	CurrentDictionary = ExternalModulePropertiesDictionary();
	If ClearAccessManagementLists Then
		ExternalModulesToDelete = AccessManagementLists(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary);
		For Each ExternalModuleToDelete In ExternalModulesToDelete Do
			DeleteAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, ExternalModuleToDelete.Name);
		EndDo;
	EndIf;
	ExternalModulesToCreate = SecurityProfileProperties.ExternalModules;
	For Each ExternalModuleToCreate In ExternalModulesToCreate Do
		CreateAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary, ExternalModuleToCreate);
	EndDo;
	
	// OS applications
	ListName = "app";
	CurrentDictionary = OSApplicationPropertiesDictionary();
	If ClearAccessManagementLists Then
		OSApplicationsToDelete = AccessManagementLists(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary);
		For Each OSApplicationToDelete In OSApplicationsToDelete Do
			DeleteAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, OSApplicationToDelete.Name);
		EndDo;
	EndIf;
	OSApplicationsToCreate = SecurityProfileProperties.OSApplications;
	For Each OSApplicationToCreate In OSApplicationsToCreate Do
		CreateAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary, OSApplicationToCreate);
	EndDo;
	
	// Internet resources
	ListName = "inet";
	CurrentDictionary = InternetResourcePropertiesDictionary();
	If ClearAccessManagementLists Then
		InternetResourcesToDelete = AccessManagementLists(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary);
		For Each InternetResourceToDelete In InternetResourcesToDelete Do
			DeleteAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, InternetResourceToDelete.Name);
		EndDo;
	EndIf;
	InternetResourcesToCreate = SecurityProfileProperties.InternetResources;
	For Each InternetResourceToCreate In InternetResourcesToCreate Do
		CreateAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary, InternetResourceToCreate);
	EndDo;
	
EndProcedure

// Sets acl usage for security profiles.
//
// Parameters:
//  ClusterID - String - internal ID of a server cluster,
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  ProfileName - String - name of a security profile,
//  ListName - String - name of an access control list (acl) in rac notation,
//  Usage - Boolean - indicates whether the access control list is used.
//
Procedure SetAccessManagementListUsage(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val ListName, Val Usage)
	
	Template = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% acl --name=%name% directory --access=%access%";
	Template = StrReplace(Template, "directory", ListName);
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	Parameters.Insert("name", ProfileName);
	If Usage Then
		Parameters.Insert("access", "list");
	Else
		Parameters.Insert("access", "full");
	EndIf;
	
	ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	
EndProcedure

// Deletes acl item from a security profile.
//
// Parameters:
//  ClusterID - String - internal ID of a server cluster,
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  ProfileName - String - name of a security profile,
//  ListName - String - name of an access control list (acl) in rac notation,
//  ItemKey - String - a value of a key property of acl item.
//
Procedure DeleteAccessManagementListItem(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val ListName, Val ItemKey)
	
	ListKey = AccessManagementListsKeys()[ListName];
	
	Template = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% acl --name=%name% directory remove --key=%key%";
	Template = StrReplace(Template, "directory", ListName);
	Template = StrReplace(Template, "key", ListKey);
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	Parameters.Insert("name", ProfileName);
	Parameters.Insert(ListKey, ItemKey);
	
	ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	
EndProcedure

// Creates acl item for a security profile.
//
// Parameters:
//  ClusterID - String - internal ID of a server cluster,
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  ProfileName - String - name of a security profile,
//  ListName - String - name of an access control list (acl) in rac notation,
//  Dictionary - Structure - correspondence between property names in rac output stream and in the required description,
//  ItemProperties - Structure with values of access control list item properties.
//
Procedure CreateAccessManagementListItem(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val ListName, Val Dictionary, Val ItemProperties)
	
	Template = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% acl --name=%profile_name% directory update";
	Template = StrReplace(Template, "directory", ListName);
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	Parameters.Insert("profile_name", ProfileName);
	
	FillParametersByDictionary(Dictionary, ItemProperties, Parameters, Template);
	
	ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	
EndProcedure

// Converts values of the access control list usage property values (nonstandard value format are 
// used when passing the values to the rac utility: True = "full", False = "list").
//
// Parameters:
//  DetailsStructure - Structure - contains the object description received from the output thread 
//    of the rac utility.
//
// Returns: Structure where "full" and "list" have been converted to True and False.
//
Function ConvertAccessListsUsagePropertyValues(Val DetailsStructure)
	
	Dictionary = AccessManagementListUsagePropertiesDictionary();
	
	Result = New Structure;
	
	For Each KeyAndValue In DetailsStructure Do
		
		If Dictionary.Property(KeyAndValue.Key) Then
			
			If KeyAndValue.Value = "list" Then
				
				Value = False;
				
			ElsIf KeyAndValue.Value = "full" Then
				
				Value = True;
				
			EndIf;
			
			Result.Insert(KeyAndValue.Key, Value);
			
		Else
			
			Result.Insert(KeyAndValue.Key, KeyAndValue.Value);
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Converts 1C:Enterprise script values into the notation of the console client of the 
//  administration server.
//
// Parameters:
//  Value - Arbitrary - value to convert.
//
// Returns:
//  String - a value converted to the notation of console client of the administration server.
//
Function CastValue(Val Value, Val ParameterName = "")
	
	If TypeOf(Value) = Type("Date") Then
		Return Format(Value, "DF=yyyy-mm-ddTHH:mm:ss");
	EndIf;
	
	If TypeOf(Value) = Type("Boolean") Then
		
		If IsBlankString(ParameterName) Then
			FormatString = "BF=off; BT=on";
		Else
			FormatString = BooleanPropertyFormatDictionary()[ParameterName];
		EndIf;
		
		Return Format(Value, FormatString);
		
	EndIf;
	
	If TypeOf(Value) = Type("Number") Then
		Return Format(Value, "NDS=,; NZ=0; NG=0; NN=1");
	EndIf;
	
	If TypeOf(Value) = Type("String") Then
		If StrFind(Value, """") > 0 Or StrFind(Value, " ") > 0 Or StrFind(Value, "-") > 0 Or StrFind(Value, "!") > 0 Then
			Return """" + StrReplace(Value, """", """""") + """";
		EndIf;
	EndIf;
	
	Return String(Value);
	
EndFunction

// Converts the output thread item that contains a value into the notation of the console client of 
//  the administration server.
//
// Parameters:
//  OutputItem - String - output thread item that contains the value in the notation of the console 
//    client of the administration server.
//
// Returns:
//  Arbitrary - a value of 1C:Enterprise language.
//
Function CastOutputItem(OutputItem)
	
	If IsBlankString(OutputItem) Then
		Return Undefined;
	EndIf;
	
	OutputItem = StrReplace(OutputItem, """""", """");
	
	If OutputItem = "on" Or OutputItem = "yes" Then
		Return True;
	EndIf;
	
	If OutputItem = "off" Or OutputItem = "no" Then
		Return False;
	EndIf;
	
	If StringFunctionsClientServer.OnlyNumbersInString(OutputItem) Then
		Return Number(OutputItem);
	EndIf;
	
	Try
		Return XMLValue(Type("Date"), OutputItem);
	Except
		// No exception processing required. Expected exception - the value cannot be converted into Date.
		// 
		Return OutputItem;
	EndTry;
	
EndFunction

// Starts the console client of the administration server to execute the command.
//
// Parameters:
//  Template - String - a command line template (unique for each command).
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  ParameterValues - Structure - contains values of the parameters to be substituted into the 
//    pattern.
//
// Returns:
//  String - result of redirecting the standard output stream when rac utility is started.
//
Function ExecuteCommand(Val Template, Val ClusterAdministrationParameters, Val ParameterValues = Undefined)
	
	#If Server Then
		
		If SafeMode() <> False Then
			Raise NStr("ru = 'Внимание! Администрирование кластера невозможно в безопасном режиме.'; en = 'Warning! Cluster administration is unavailable in safe mode.'; pl = 'Uwaga! Administrowanie klastera jest niemożliwe w trybie bezpiecznym.';es_ES = '¡Atención! Administración del clúster no está disponible en el modo seguro';es_CO = '¡Atención! Administración del clúster no está disponible en el modo seguro';tr = 'Dikkat! Küme yönetimi güvenli modda kullanılamaz.';it = 'Attenzione! L''amministrazione del cluster non è disponibile in modalità sicura.';de = 'Achtung! Die Cluster-Administration ist im abgesicherten Modus nicht möglich.'");
		EndIf;
		
		If Common.DataSeparationEnabled() Then
			Raise NStr("ru = 'Внимание! В модели сервиса недопустимо выполнение прикладной информационной базой функций администрирования кластера.'; en = 'Warning! The infobase features related to cluster administration are unavailable in SaaS mode.'; pl = 'Uwaga! W modelu serwisu jest niedostępne wykonanie funkcji administrowania klastera przez zastosowaną bazę informacyjną.';es_ES = '¡Atención! En el modelo de servicio no se admite la realización de las funciones de administrar el clúster por la base de información aplicada.';es_CO = '¡Atención! En el modelo de servicio no se admite la realización de las funciones de administrar el clúster por la base de información aplicada.';tr = 'Dikkat! Hizmet modeli, küme yönetimi işlevlerinin uygulama veri tabanını çalıştırmak için kullanılmaz.';it = 'Attenzione! Nel modello del servizio non è possibile l''esecuzione del database applicato delle funzioni di amministrazione del cluster.';de = 'Achtung! Im Servicemodell ist es inakzeptabel, dass die Anwendungsinformationsbasis Cluster-Administrationsfunktionen ausführt.'");
		EndIf;
		
	#EndIf
	
	// Substituting path to the rac utility and the ras server address to the command line.
	Client = PathToAdministrationServerClient();
	ClientFile = New File(Client);
	If Not ClientFile.Exist() Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Невозможно выполнить операцию администрирования кластера серверов по причине: файл %1 не найден.
			      |
			      |Для администрирования кластера через сервер администрирования (ras) требуется установить на данном
			      |компьютере клиент сервера администрирования (rac).
			      |Для его установки:
			      |- Для компьютеров с ОС Windows требуется переустановить платформу, установив компонент ""Администрирование сервера 1С:Предприятия"";
			      |- Для компьютеров с ОС Linux требуется установить пакет 1c-enterprise83-server*.'; 
			      |en = 'Cannot perform the server cluster administration operation because the file %1 is not found.
			      |
			      |To administer the cluster using the administration server (ras),
			      |install the administration client (rac) on this computer.
			      |To install the administration client:
			      |- On Windows, reinstall 1C:Enterprise with ""Administration of 1C:Enterprise server"" component.
			      |- On Linux, install the 1c-enterprise83-server* package.'; 
			      |pl = 'Nie można wykonać operacji administrowania klastrem serwerów, ponieważ plik %1 nie został znaleziony.
			      |
			      |Aby administrować klastrem przy użyciu serwera administracyjnego (ras),
			      |zainstaluj klienta administracyjnego (rac) na tym komputerze.
			      |Aby zainstalować klienta administracyjnego:
			      |- W systemie Windows zainstaluj ponownie 1C:Enterprise z komponentem ""Administration of 1C:Enterprise server"".
			      |-W systemie Linux zainstaluj pakiet 1c-enterprise83-server *.';
			      |es_ES = 'No se puede lanzar la operación de la administración del clúster de servidores como: archivo %1 no encontrado.
			      |
			      |Para administrar el clúster a través de la administración del servidor (ras), usted necesita instalar un cliente de administrar el servidor (rac) en este
			      |ordenador.
			      |Para instalarlo: 
			      |- Para los ordenadores con Windows OS usted necesita reinstalar la plataforma instalando el componente ""1C:Enterprise administrar el servidor"";
			      |- Para los ordenadores con Linux OS usted necesita instalar el paquete 1c-empresa83-servidor*.';
			      |es_CO = 'No se puede lanzar la operación de la administración del clúster de servidores como: archivo %1 no encontrado.
			      |
			      |Para administrar el clúster a través de la administración del servidor (ras), usted necesita instalar un cliente de administrar el servidor (rac) en este
			      |ordenador.
			      |Para instalarlo: 
			      |- Para los ordenadores con Windows OS usted necesita reinstalar la plataforma instalando el componente ""1C:Enterprise administrar el servidor"";
			      |- Para los ordenadores con Linux OS usted necesita instalar el paquete 1c-empresa83-servidor*.';
			      |tr = 'Sunucu küme yönetiminin operasyonunu çalıştırılamıyor: %1 dosya bulunamadı.
			      |
			      |nKümeyi yönetici sunucusu (ras) aracılığıyla yönetmek için, bu bilgisayara
			      |n bir yönetim sunucusu (ras) istemcisi yüklemeniz gerekir.
			      |nYüklemek için:
			      |n- Windows işletim sistemine sahip bilgisayarlar için, 1C: İşletme sunucu yönetimi bileşenini kurarak platformu yeniden yüklemeniz gerekir"";
			      |- Linux OS''li bilgisayarlar için 1c-enterprise83-server * paketini yüklemeniz gerekir.';
			      |it = 'Impossibile eseguire l''operazione di amminsitrazione del cluster di server poiché il file %1 non è stato trovato.
			      |
			      |Per gestire il cluster utilizzando il server di amministrazione (ras),
			      |installare il client di amministrazione (rac) su questo computer.
			      |Per installare il client di amministrazione:
			      |- Su Windows, reinstallare 1C:Enterprise con la componente ""Amministrazione del server 1C:Enterprise"".
			      |- Su Linux installare il pacchetto 1c-enterprise83-server*.';
			      |de = 'Es ist nicht möglich, de Operation der Server-Cluster-Administration durchzuführen, da die Datei %1 nicht gefunden wurde.
			      |
			      |Um den Cluster über den Administrationsserver (ras) zu verwalten, müssen Sie den Administrationsserver-Client (rac) auf diesem
			      |Computer installieren.
			      |Um es zu installieren:
			      |- Für Windows-Computer müssen Sie die Plattform durch Installation der Komponente ""Serveradministration 1C:Enterprise"" neu installieren;
			      |- Für Computer mit Linux müssen Sie das Paket 1c-enterprise83-server* installieren.'"),
			ClientFile.FullName);
		
	EndIf;
	
	If ValueIsFilled(ClusterAdministrationParameters.AdministrationServerAddress) Then
		Server = TrimAll(ClusterAdministrationParameters.AdministrationServerAddress);
		If ValueIsFilled(ClusterAdministrationParameters.AdministrationServerPort) Then
			Server = Server + ":" + CastValue(ClusterAdministrationParameters.AdministrationServerPort);
		Else
			Server = Server + ":1545";
		EndIf;
	Else
		Server = "";
	EndIf;
	
	CommandLine = """" + Client + """ " + StrReplace(Template, "%rac", Server);
	
	// Substituting parameter values to the command line.
	If ValueIsFilled(ParameterValues) Then
		For Each Parameter In ParameterValues Do
			// Filling the parameter value.
			CommandLine = StrReplace(CommandLine, "%" + Parameter.Key + "%", CastValue(Parameter.Value, Parameter.Key));
			If ValueIsFilled(Parameter.Value) Then
				// Optional parameters can be used.
				CommandLine = StrReplace(CommandLine, "%?" + Parameter.Key + "%", CastValue(Parameter.Value, Parameter.Key));
			Else
				// Removing the optional parameter from the command line if its value was not specified.
				CommandLine = StrReplace(CommandLine, "--" + Parameter.Key + "=%?" + Parameter.Key + "%", "");
			EndIf;
		EndDo;
	EndIf;
	
	ApplicationStartupParameters = CommonClientServer.ApplicationStartupParameters();
	ApplicationStartupParameters.CurrentDirectory = PlatformExecutableFilesDirectory();
	ApplicationStartupParameters.WaitForCompletion = True;
	ApplicationStartupParameters.GetOutputStream = True;
	ApplicationStartupParameters.GetErrorStream = True;
	
	Result = CommonClientServer.StartApplication(CommandLine, ApplicationStartupParameters);
	
	OutputStream = Result.OutputStream;
	ErrorStream = Result.ErrorStream;
	
	If ValueIsFilled(ErrorStream) Then
		Raise ErrorStream;
	EndIf;
	
	Return OutputStream;
	
EndFunction

// Converts redirected output thread of the console client of the administration server into the 
// array of maps (array elements -objects; map keys - property names; map values - property values).
// 
//
// Parameters:
//  OutputStream - String - a redirected output stream,
//  Dictionary - Structure - a mapping dictionary for object property names.
//    In the rac utility notation and API notation,
//  Filter - Structure - object filter criteria (only for the threads of output commands that return 
//    object collections).
//
// Returns:
//  Array(Map)
//
Function OutputParser(Val OutputStream, Val Dictionary, Val Filter = Undefined)
	
	Result = New Array();
	ResultItem = New Map();
	
	OutputSize = StrLineCount(OutputStream);
	For Step = 1 To OutputSize Do
		StreamItem = StrGetLine(OutputStream, Step);
		StreamItem = TrimAll(StreamItem);
		SeparatorLocation = StrFind(StreamItem, ":");
		If SeparatorLocation > 0 Then
			
			PropertyName = TrimAll(Left(StreamItem, SeparatorLocation - 1));
			PropertyValue = CastOutputItem(TrimAll(Right(StreamItem, StrLen(StreamItem) - SeparatorLocation)));
			
			If PropertiesEscapedWithQuotationMarks().Find(PropertyName) <> Undefined Then
				If StrStartsWith(PropertyValue, """") AND StrEndsWith(PropertyValue, """") Then
					PropertyValue = Left(PropertyValue, StrLen(PropertyValue) - 1);
					PropertyValue = Right(PropertyValue, StrLen(PropertyValue) - 1)
				EndIf;
			EndIf;
			
			ResultItem.Insert(PropertyName, PropertyValue);
			
		Else
			
			If ResultItem.Count() > 0 Then
				
				OutputItemParser(ResultItem, Result, Dictionary, Filter);
				
				ResultItem = New Map();
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If ResultItem.Count() > 0 Then
		OutputItemParser(ResultItem, Result, Dictionary, Filter);
	EndIf;
	
	Return Result;
	
EndFunction

// Converts the item of the redirected output thread of the console client of the administration 
//  server into a map. Map keys - property names; map values - property values.
//
// Parameters:
//  ResultItem - String - an item of output stream,
//  Result - Array - array where the parsed object must be added,
//  Dictionary - Structure - a mapping dictionary for object property names.
//    In the rac utility notation and API notation,
//  Filter - Structure - object filter criteria (only for the threads of output commands that return 
//    object collections).
//
Procedure OutputItemParser(ResultItem, Result, Dictionary, Filter)
	
	If Dictionary <> Undefined Then
		Object = ParseOutputItem(ResultItem, Dictionary);
	Else
		Object = ResultItem;
	EndIf;
	
	If Filter <> Undefined AND Not ClusterAdministrationClientServer.CheckFilterConditions(Object, Filter) Then
		Return;
	EndIf;
	
	Result.Add(Object);
	
EndProcedure

// Parses an item of the redirected output stream of the administration server console client.
//
// Parameters:
//  OutputItem - String - item of the redirected output stream of the administration server client,
//  Dictionary - Structure - a mapping dictionary for object property names.
//    In the rac utility notation and API notation.
//
// Returns: Structure where keys are property names in API notation, values are property values from 
//  redirected output thread.
//
Function ParseOutputItem(Val OutputItem, Val Dictionary)
	
	Result = New Structure();
	
	For Each DictionaryFragment In Dictionary Do
		
		Result.Insert(DictionaryFragment.Key, OutputItem[DictionaryFragment.Value]);
		
	EndDo;
	
	Return Result;
	
EndFunction

// Adds cluster administrator authentication parameters to the rac startup parameters.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  Parameters - Map - map of the rac startup parameters to be generated.
//
Procedure FillClusterAuthenticationParameters(Val ClusterAdministrationParameters, Parameters)
	
	Parameters.Insert("cluster-user", ClusterAdministrationParameters.ClusterAdministratorName);
	Parameters.Insert("cluster-pwd", ClusterAdministrationParameters.ClusterAdministratorPassword);
	
EndProcedure

// Adds the infobase administrator authentication parameters to the rac startup parameters.
//
// Parameters:
//  IBAdministrationParameters - a structure that describes infobase connection parameters. For 
//    details, see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(). 
//  Parameters - Map - map of the rac startup parameters to be generated.
//
Procedure FillIBAuthenticationParameters(Val IBAdministrationParameters, Parameters)
	
	Parameters.Insert("infobase-user", IBAdministrationParameters.InfobaseAdministratorName);
	Parameters.Insert("infobase-pwd", IBAdministrationParameters.InfobaseAdministratorPassword);
	
EndProcedure

// Supplements the rac startup parameters by the dictionary.
//
// Parameters:
//  Dictionary - Structure - map dictionary for object property names in the rac notation and in the 
//    API notations
//  Source - Structure where key - property name in API notation, value - property value,
//  Parameters - Map - rac startup parameters,
//  Template - String - rac startup command template.
//
Procedure FillParametersByDictionary(Val Dictionary, Val Source, Parameters, Template)
	
	For Each DictionaryFragment In Dictionary Do
		
		Template = Template + " --" + DictionaryFragment.Value + "=%" + DictionaryFragment.Value + "%";
		Parameters.Insert(DictionaryFragment.Value, Source[DictionaryFragment.Key]);
		
	EndDo;
	
EndProcedure

// Converts filter into the rac utility notation.
//
// Parameters:
//  Filter - Structure, Array(Structure) - filter in API notation,
//  Dictionary - Structure - correspondence between property names in API notation and in the rac utility notation.
//
// Returns: Structure, Array(Structure) - filter in the rac utility notation.
//
Function FilterToRacNotation(Val Filter, Val Dictionary)
	
	If Filter = Undefined Then
		Return Undefined;
	EndIf;
	
	If Dictionary = Undefined Then
		Return Filter;
	EndIf;
	
	Result = New Array();
	
	For Each Condition In Filter Do
		
		If TypeOf(Condition) = Type("KeyAndValue") Then
			
			Result.Add(New Structure("Property, ComparisonType, Value", Dictionary[Condition.Key], ComparisonType.Equal, Condition.Value));
			
		ElsIf TypeOf(Condition) = Type("Structure") Then
			
			Result.Add(New Structure("Property, ComparisonType, Value", Dictionary[Condition.Property], Condition.ComparisonType, Condition.Value));
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Returns a map of infobase property names that describe the session lock state and scheduled jobs. 
//  Is used for structures used in the API and for object descriptions in the rac output.
//  
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see
//         ClusterAdministrationClientServer.SessionAndScheduleJobLockProperties()),
//  Value - String - the name of an object property.
//
Function SessionAndScheduledJobLockPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("SessionsLock", "sessions-deny");
	Result.Insert("DateFrom", "denied-from");
	Result.Insert("DateTo", "denied-to");
	Result.Insert("Message", "denied-message");
	Result.Insert("KeyCode", "permission-code");
	Result.Insert("LockParameter", "denied-parameter");
	Result.Insert("ScheduledJobLock", "scheduled-jobs-deny");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a map of infobase session property names for structures used in the API and object 
//  descriptions in the rac output.
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see ClusterAdministrationClientServer.SessionProperties()).
//  Value - String - the name of an object property.
//
Function SessionPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Number", "session-id");
	Result.Insert("UserName", "user-name");
	Result.Insert("ClientComputerName", "host");
	Result.Insert("ClientApplicationID", "app-id");
	Result.Insert("LanguageID", "locale");
	Result.Insert("SessionCreationTime", "started-at");
	Result.Insert("LatestSessionActivityTime", "last-active-at");
	Result.Insert("DBMSLock", "blocked-by-dbms");
	Result.Insert("Lock", "blocked-by-ls");
	Result.Insert("Passed", "bytes-all");
	Result.Insert("PassedIn5Minutes", "bytes-last-5min");
	Result.Insert("ServerCalls", "calls-all");
	Result.Insert("ServerCallsIn5Minutes", "calls-last-5min");
	Result.Insert("ServerCallsDurations", "duration-all");
	Result.Insert("CurrentServerCallDuration", "duration-current");
	Result.Insert("ServerCallsDurationsIn5Minutes", "duration-last-5min");
	Result.Insert("ExchangedWithDBMS", "dbms-bytes-all");
	Result.Insert("ExchangedWithDBMSIn5Minutes", "dbms-bytes-last-5min");
	Result.Insert("DBMSCallsDurations", "duration-all-dbms");
	Result.Insert("CurrentDBMSCallDuration", "duration-current-dbms");
	Result.Insert("DBMSCallsDurationsIn5Minutes", "duration-last-3min-dbms");
	Result.Insert("DBMSConnection", "db-proc-info");
	Result.Insert("DBMSConnectionTime", "db-proc-took");
	Result.Insert("DBMSConnectionSeizeTime", "db-proc-took-at");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a map of infobase connection property names for structures used in the API and object 
//  descriptions in the rac output.
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see ClusterAdministrationClientServer.ConnectionProperties()).
//  Value - String - the name of an object property.
//
Function ConnectionPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Number", "conn-id");
	Result.Insert("UserName", "user-name");
	Result.Insert("ClientComputerName", "host");
	Result.Insert("ClientApplicationID", "app-id");
	Result.Insert("ConnectionEstablishingTime", "connected-at");
	Result.Insert("InfobaseConnectionMode", "ib-conn-mode");
	Result.Insert("DataBaseConnectionMode", "db-conn-mode");
	Result.Insert("DBMSLock", "blocked-by-dbms");
	Result.Insert("Passed", "bytes-all");
	Result.Insert("PassedIn5Minutes", "bytes-last-5min");
	Result.Insert("ServerCalls", "calls-all");
	Result.Insert("ServerCallsIn5Minutes", "calls-last-5min");
	Result.Insert("ExchangedWithDBMS", "dbms-bytes-all");
	Result.Insert("ExchangedWithDBMSIn5Minutes", "dbms-bytes-last-5min");
	Result.Insert("DBMSConnection", "db-proc-info");
	Result.Insert("DBMSTime", "db-proc-took");
	Result.Insert("DBMSConnectionSeizeTime", "db-proc-took-at");
	Result.Insert("ServerCallsDurations", "duration-all");
	Result.Insert("DBMSCallsDurations", "duration-all-dbms");
	Result.Insert("CurrentServerCallDuration", "duration-current");
	Result.Insert("CurrentDBMSCallDuration", "duration-current-dbms");
	Result.Insert("ServerCallsDurationsIn5Minutes", "duration-last-5min");
	Result.Insert("DBMSCallsDurationsIn5Minutes", "duration-last-5min-dbms");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a map of security profile property names for structures used in the API and object 
//  descriptions in the rac output.
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see ClusterAdministrationClientServer.SecurityProfileProperties()).
//  Value - String - the name of an object property.
//
Function SecurityProfilePropertiesDictionary(Val IncludeAccessManagementListsUsageProperties = True)
	
	Result = New Structure();
	
	Result.Insert("Name", "name");
	Result.Insert("Details", "descr");
	Result.Insert("SafeModeProfile", "config");
	Result.Insert("FullAccessToPrivilegedMode", "priv");
	
	If IncludeAccessManagementListsUsageProperties Then
		
		AccessManagementListsUsagePropertiesDictionary = AccessManagementListUsagePropertiesDictionary();
		
		For Each DictionaryFragment In AccessManagementListsUsagePropertiesDictionary Do
			Result.Insert(DictionaryFragment.Key, DictionaryFragment.Value);
		EndDo;
		
	EndIf;
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a map of security profile property names for structures used in the API and object 
//  descriptions in the rac output.
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see ClusterAdministrationClientServer.SecurityProfileProperties()).
//  Value - String - the name of an object property.
//
Function AccessManagementListUsagePropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("FullFileSystemAccess", "directory");
	Result.Insert("FullCOMObjectAccess", "com");
	Result.Insert("FullAddInAccess", "addin");
	Result.Insert("FullExternalModuleAccess", "module");
	Result.Insert("FullOperatingSystemApplicationAccess", "app");
	Result.Insert("FullInternetResourceAccess", "inet");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a map of virtual directory property names for structures used in the API and object 
//  descriptions in the rac output.
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see ClusterAdministrationClientServer.VirtualDirectoryProperties()).
//  Value - String - the name of an object property.
//
Function VirtualDirectoryPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("LogicalURL", "alias");
	Result.Insert("PhysicalURL", "physicalPath");
	
	Result.Insert("Details", "descr");
	
	Result.Insert("DataReader", "allowedRead");
	Result.Insert("DataWriter", "allowedWrite");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a map of COM class property names for structures used in the API and object descriptions 
//  in the rac output.
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see ClusterAdministrationClientServer.COMClassProperties()).
//  Value - String - the name of an object property.
//
Function COMClassPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "name");
	Result.Insert("Details", "descr");
	
	Result.Insert("FileMoniker", "fileName");
	Result.Insert("CLSID", "id");
	Result.Insert("Computer", "host");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a map of add-in property names for structures used in the API and object descriptions in 
//  the rac output.
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see ClusterAdministrationClientServer.AddInProperties()).
//  Value - String - the name of an object property.
//
Function AddInPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "name");
	Result.Insert("Details", "descr");
	
	Result.Insert("HashSum", "hash");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a map of external module property names for structures used in the API and object 
//  descriptions in the rac output.
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see ClusterAdministrationClientServer.ExternalModuleProperties()).
//  Value - String - the name of an object property.
//
Function ExternalModulePropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "name");
	Result.Insert("Details", "descr");
	
	Result.Insert("HashSum", "hash");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a map of OS application property names for structures used in the API and object 
//  descriptions in the rac output.
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see ClusterAdministrationClientServer.OSApplicationProperties()).
//  Value - String - the name of an object property.
//
Function OSApplicationPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "name");
	Result.Insert("Details", "descr");
	
	Result.Insert("CommandLinePattern", "wild");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a map of Internet resource property names for structures used in the API and object 
//  descriptions in the rac output.
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see ClusterAdministrationClientServer.InternetResourceProperties()).
//  Value - String - the name of an object property.
//
Function InternetResourcePropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "name");
	Result.Insert("Details", "descr");
	
	Result.Insert("Protocol", "protocol");
	Result.Insert("Address", "url");
	Result.Insert("Port", "port");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns names of the key acl properties (in the rac utility notation).
//
// Returns: FixedStructure:
//  Key - String - acl name,
//  Value - String, key property name.
//
Function AccessManagementListsKeys()
	
	Result = New Structure();
	
	Result.Insert("directory", "alias");
	Result.Insert("com", "name");
	Result.Insert("addin", "name");
	Result.Insert("module", "name");
	Result.Insert("inet", "name");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns the rules for formatting boolean properties according to the rac utility notation.
//  
//
// Returns: FixedMap:
//  Key - String - property name,
//  Value - String, formatted string for property values.
//
Function BooleanPropertyFormatDictionary()
	
	OnOffFormat = "BF=off; BT=on";
	YesNoFormat = "BF=no; BT=yes";
	
	Result = New Map();
	
	// Session and job lock properties
	Dictionary = SessionAndScheduledJobLockPropertiesDictionary();
	Result.Insert(Dictionary.SessionsLock, OnOffFormat);
	Result.Insert(Dictionary.ScheduledJobLock, OnOffFormat);
	
	// Security profile properties.
	Dictionary = SecurityProfilePropertiesDictionary(False);
	Result.Insert(Dictionary.SafeModeProfile, YesNoFormat);
	Result.Insert(Dictionary.FullAccessToPrivilegedMode, YesNoFormat);
	
	// Virtual directory properties.
	Dictionary = VirtualDirectoryPropertiesDictionary();
	Result.Insert(Dictionary.DataReader, YesNoFormat);
	Result.Insert(Dictionary.DataWriter, YesNoFormat);
	
	Return New FixedMap(Result);
	
EndFunction

// Returns the list of properties whose values are enclosed with quotation marks in the output 
// thread of the rac utility.
//
// Returns: Array(String) - a list of property names.
//
Function PropertiesEscapedWithQuotationMarks()
	
	Result = New Array();
	
	Result.Add("denied-message");
	Result.Add("permission-code");
	Result.Add("denied-parameter");
	
	Return New FixedArray(Result);
	
EndFunction

#EndRegion

#EndIf