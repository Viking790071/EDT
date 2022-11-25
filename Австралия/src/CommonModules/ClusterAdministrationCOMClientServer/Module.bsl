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
	
	COMConnector = COMConnector();
	
	ServerAgentConnection = ServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessConnection = WorkingProcessConnection(COMConnector, ServerAgentConnection, Cluster);
	
	Infobase = GetIB(
		WorkingProcessConnection,
		Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	Result = COMAdministratorObjectModelObjectDetails(
		Infobase,
		SessionAndScheduledJobLockPropertiesDictionary());
	
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
	
	LockToSet = New Structure();
	For Each KeyAndValue In SessionAndJobLockProperties Do
		LockToSet.Insert(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
	If Not ValueIsFilled(LockToSet.DateFrom) Then
		LockToSet.DateFrom = ClusterAdministrationClientServer.EmptyDate();
	EndIf;
	
	If Not ValueIsFilled(LockToSet.DateTo) Then
		LockToSet.DateTo = ClusterAdministrationClientServer.EmptyDate();
	EndIf;
	
	COMConnector = COMConnector();
	
	ServerAgentConnection = ServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessConnection = WorkingProcessConnection(COMConnector, ServerAgentConnection, Cluster);
	
	Infobase = GetIB(
		WorkingProcessConnection,
		Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	FillCOMAdministratorObjectModelObjectPropertiesByDeclaration(
		Infobase,
		LockToSet,
		SessionAndScheduledJobLockPropertiesDictionary());
	
	WorkingProcessConnection.UpdateInfoBase(Infobase);
	
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
	
	If CheckClusterAdministrationParameters OR CheckInfobaseAdministrationParameters Then
		
		Try
			COMConnector = COMConnector();
		
			ServerAgentConnection = ServerAgentConnection(
				COMConnector,
				ClusterAdministrationParameters.ServerAgentAddress,
				ClusterAdministrationParameters.ServerAgentPort);
			
			Cluster = GetCluster(
				ServerAgentConnection,
				ClusterAdministrationParameters.ClusterPort,
				ClusterAdministrationParameters.ClusterAdministratorName,
				ClusterAdministrationParameters.ClusterAdministratorPassword);
		Except
#If WebClient OR MobileClient Then
			Raise;
#Else
			Raise BriefErrorDescription(ErrorInfo()) + Chars.LF + Chars.LF
				+ StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'В случае ошибки о несоответствии версии компоненты ""comcntr"" следует зарегистрировать ее на компьютере %1
					|для учетной записи ОС Windows, от имени которой выполняется 1С:Предприятие. Например:
					|regsvr32.exe ""%2\comcntr.dll""'; 
					|en = 'In case of comcntr version mismatch error, register comcntr on computer %1
					|for the Windows account that you use to run 1C:Enterprise. Example:
					|regsvr32.exe ""%2\comcntr.dll""'; 
					|pl = 'W przypadku wystąpienia błędu o niezgodności wersji komponentu ""comcntr"" należy zarejestrować ją na komputerze %1
					|dla konta OS Windows, w imieniu której wykonywane jest 1C:Enterprise. Na przykład:
					|regsvr32.exe ""%2\comcntr.dll""';
					|es_ES = 'En el caso de error de la incompatibilidad de la versión del componente ""comcntr"" hay que registrarlo en el ordenador %1
					|para a cuenta de OS Windows de cuyo ombre se ejecuta 1C:Enterprise. Por ejemplo:
					|regsvr32.exe ""%2\comcntr.dll""';
					|es_CO = 'En el caso de error de la incompatibilidad de la versión del componente ""comcntr"" hay que registrarlo en el ordenador %1
					|para a cuenta de OS Windows de cuyo ombre se ejecuta 1C:Enterprise. Por ejemplo:
					|regsvr32.exe ""%2\comcntr.dll""';
					|tr = 'comcntr sürüm eşleşme hatası durumunda, 1C:İşletme''yi çalıştırdığınız Windows hesabı için%1
					|comcntr''yi bilgisayara kaydedin. Örneğin:
					|regsvr32.exe ""%2\comcntr.dll""';
					|it = 'In caso di errore di incompatibilità di versione comcntr, registrare comcntr sul computer %1
					|per l''account Windows utilizzato per eseguire 1C:Enterprise. Esempio:
					|regsvr32.exe ""%2\comcntr.dll""';
					|de = 'Im Falle eines Versionsfehlers muss die Komponente ""comcntr"" auf dem %1
					|-Computer für das Windows-Konto registriert werden, auf dessen Namen 1C:Enterprise läuft. Zum Beispiel:
					|regsvr32.exe ""%2\comcntr.dll""'"), ComputerName(), BinDir());
#EndIf
		EndTry;
		
	EndIf;
	
	If CheckInfobaseAdministrationParameters Then
		
		WorkingProcessConnection = WorkingProcessConnection(COMConnector, ServerAgentConnection, Cluster);
		
		GetIB(
			WorkingProcessConnection,
			Cluster,
			IBAdministrationParameters.NameInCluster,
			IBAdministrationParameters.InfobaseAdministratorName,
			IBAdministrationParameters.InfobaseAdministratorPassword);
		
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
	
	COMConnector = COMConnector();
	
	ServerAgentConnection = ServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessConnection = WorkingProcessConnection(COMConnector, ServerAgentConnection, Cluster);
	
	Infobase = GetIB(
		WorkingProcessConnection,
		Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	Return Infobase.ScheduledJobsDenied;
	
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
	
	COMConnector = COMConnector();
	
	ServerAgentConnection = ServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessConnection = WorkingProcessConnection(COMConnector, ServerAgentConnection, Cluster);
	
	Infobase = GetIB(
		WorkingProcessConnection,
		Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	Infobase.ScheduledJobsDenied = ScheduledJobLock;
	WorkingProcessConnection.UpdateInfoBase(Infobase);
	
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
	
	COMConnector = COMConnector();
	
	ServerAgentConnection = ServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	InfobaseDetails = GetIBDetails(
		ServerAgentConnection,
		Cluster,
		IBAdministrationParameters.NameInCluster);
	
	Return GetSessions(ServerAgentConnection, Cluster, InfobaseDetails, Filter, True);
	
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
	
	COMConnector = COMConnector();
	
	ServerAgentConnection = ServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	InfobaseDetails = GetIBDetails(
		ServerAgentConnection,
		Cluster,
		IBAdministrationParameters.NameInCluster);
	
	AttemptCount = 3;
	AllSessionsTerminated = False;
	
	For CurrentAttempt = 0 To AttemptCount Do
		
		Sessions = GetSessions(ServerAgentConnection, Cluster, InfobaseDetails, Filter, False);
		
		If Sessions.Count() = 0 Then
			
			AllSessionsTerminated = True;
			Break;
			
		ElsIf CurrentAttempt = AttemptCount Then
			
			Break;
			
		EndIf;
		
		For each Session In Sessions Do
			
			Try
				
				ServerAgentConnection.TerminateSession(Cluster, Session);
				
			Except
				
				// The session might close before TerminateSession is called.
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
	
	COMConnector = COMConnector();
	
	ServerAgentConnection = ServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	Return GetConnections(
		COMConnector,
		ServerAgentConnection,
		Cluster,
		IBAdministrationParameters,
		Filter,
		True);
	
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
	
	COMConnector = COMConnector();
	
	ServerAgentConnection = ServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
		
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
		
		Connections = GetConnections(
			COMConnector,
			ServerAgentConnection,
			Cluster,
			IBAdministrationParameters,
			Filter,
			False);
	
		If Connections.Count() = 0 Then
			
			AllConnectionsTerminated = True;
			Break;
			
		ElsIf CurrentAttempt = AttemptCount Then
			
			Break;
			
		EndIf;
	
		For each Connection In Connections Do
			
			Try
				
				Connection.WorkingProcessConnection.Disconnect(Connection.Connection);
				
			Except
				
				// The connection might terminate before TerminateSession is called.
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
	
	COMConnector = COMConnector();
	
	ServerAgentConnection = ServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessConnection = WorkingProcessConnection(COMConnector, ServerAgentConnection, Cluster);
	
	Infobase = GetIB(
		WorkingProcessConnection,
		Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	If ValueIsFilled(Infobase.SecurityProfileName) Then
		Result = Infobase.SecurityProfileName;
	Else
		Result = "";
	EndIf;
	
	Infobase = Undefined;
	WorkingProcessConnection = Undefined;
	Cluster = Undefined;
	ServerAgentConnection = Undefined;
	COMConnector = Undefined;
	
	Return Result;
	
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
	
	COMConnector = COMConnector();
	
	ServerAgentConnection = ServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessConnection = WorkingProcessConnection(COMConnector, ServerAgentConnection, Cluster);
	
	Infobase = GetIB(
		WorkingProcessConnection,
		Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	If ValueIsFilled(Infobase.SafeModeSecurityProfileName) Then
		Result = Infobase.SafeModeSecurityProfileName;
	Else
		Result = "";
	EndIf;
	
	Infobase = Undefined;
	WorkingProcessConnection = Undefined;
	Cluster = Undefined;
	ServerAgentConnection = Undefined;
	COMConnector = Undefined;
	
	Return Result;
	
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
	
	COMConnector = COMConnector();
	
	ServerAgentConnection = ServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessConnection = WorkingProcessConnection(COMConnector, ServerAgentConnection, Cluster);
	
	Infobase = GetIB(
		WorkingProcessConnection,
		Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	Infobase.SecurityProfileName = ProfileName;
	
	WorkingProcessConnection.UpdateInfoBase(Infobase);
	
	Infobase = Undefined;
	WorkingProcessConnection = Undefined;
	Cluster = Undefined;
	ServerAgentConnection = Undefined;
	COMConnector = Undefined
	
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
	
	COMConnector = COMConnector();
	
	ServerAgentConnection = ServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessConnection = WorkingProcessConnection(COMConnector, ServerAgentConnection, Cluster);
	
	Infobase = GetIB(
		WorkingProcessConnection,
		Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	Infobase.SafeModeSecurityProfileName = ProfileName;
	
	WorkingProcessConnection.UpdateInfoBase(Infobase);
	
	Infobase = Undefined;
	WorkingProcessConnection = Undefined;
	Cluster = Undefined;
	ServerAgentConnection = Undefined;
	COMConnector = Undefined
	
EndProcedure

// Checks whether a security profile exists in the server cluster.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  ProfileName - String, a security profile name.
//
Function SecurityProfileExists(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	COMConnector = COMConnector();
	
	ServerAgentConnection = ServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	For Each SecurityProfile In ServerAgentConnection.GetSecurityProfiles(Cluster) Do
		
		If SecurityProfile.Name = ProfileName Then
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
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
	
	COMConnector = COMConnector();
	
	ServerAgentConnection = ServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	SecurityProfile = GetSecurityProfile(ServerAgentConnection, Cluster, ProfileName);
	
	Result = COMAdministratorObjectModelObjectDetails(
		SecurityProfile,
		SecurityProfilePropertiesDictionary());
	
	// Virtual directories
	Result.Insert("VirtualDirectories",
		COMAdministratorObjectModelObjectsDetails(
			GetVirtualDirectories(ServerAgentConnection, Cluster, ProfileName),
			VirtualDirectoryPropertiesDictionary()));
	
	// Allowed COM classes.
	Result.Insert("COMClasses",
		COMAdministratorObjectModelObjectsDetails(
			GetCOMClasses(ServerAgentConnection, Cluster, ProfileName),
			COMClassPropertiesDictionary()));
	
	// Add-ins
	Result.Insert("AddIns",
		COMAdministratorObjectModelObjectsDetails(
			GetAddIns(ServerAgentConnection, Cluster, ProfileName),
			AddInPropertiesDictionary()));
	
	// External modules
	Result.Insert("ExternalModules",
		COMAdministratorObjectModelObjectsDetails(
			GetExternalModules(ServerAgentConnection, Cluster, ProfileName),
			ExternalModulePropertiesDictionary()));
	
	// OS applications
	Result.Insert("OSApplications",
		COMAdministratorObjectModelObjectsDetails(
			GetOSApplications(ServerAgentConnection, Cluster, ProfileName),
			OSApplicationPropertiesDictionary()));
	
	// Internet resources
	Result.Insert("InternetResources",
		COMAdministratorObjectModelObjectsDetails(
			GetInternetResources(ServerAgentConnection, Cluster, ProfileName),
			InternetResourcePropertiesDictionary()));
	
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
	
	COMConnector = COMConnector();
	
	ServerAgentConnection = ServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	SecurityProfile = ServerAgentConnection.CreateSecurityProfile();
	ApplySecurityProfilePropertyChanges(ServerAgentConnection, Cluster, SecurityProfile, SecurityProfileProperties);
	
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
	
	COMConnector = COMConnector();
	
	ServerAgentConnection = ServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	SecurityProfile = GetSecurityProfile(
		ServerAgentConnection,
		Cluster,
		SecurityProfileProperties.Name);
	
	ApplySecurityProfilePropertyChanges(ServerAgentConnection, Cluster, SecurityProfile, SecurityProfileProperties);
	
EndProcedure

// Deletes a securiy profile.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the parameters for connecting the 
//    server cluster. For details, see ClusterAdministrationClientServer. ClusterAdministrationParameters().
//  ProfileName - String, a security profile name.
//
Procedure DeleteSecurityProfile(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	COMConnector = COMConnector();
	
	ServerAgentConnection = ServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	GetSecurityProfile(
		ServerAgentConnection,
		Cluster,
		ProfileName);
	
	ServerAgentConnection.UnregSecurityProfile(Cluster, ProfileName);
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

// Creates a V8*.ComConnector COM object.
//
// Returns: COMObject.
//
Function COMConnector()
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	If SafeMode() <> False Then
		Raise NStr("ru = 'Внимание! Администрирование кластера невозможно в безопасном режиме'; en = 'Warning! Cluster administration is unavailable in safe mode.'; pl = 'Uwaga! Administrowanie klastera jest niemożliwe w trybie bezpiecznym.';es_ES = '¡Atención! Administración del clúster no está disponible en el modo seguro';es_CO = '¡Atención! Administración del clúster no está disponible en el modo seguro';tr = 'Dikkat! Küme yönetimi güvenli modda kullanılamaz.';it = 'Attenzione! L''amministrazione del cluster non è disponibile in modalità sicura.';de = 'Achtung! Die Cluster-Administration ist im abgesicherten Modus nicht möglich.'");
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		Raise NStr("ru = 'Внимание! В модели сервиса недопустимо выполнение прикладной информационной базой функций администрирования кластера'; en = 'Warning! The infobase features related to cluster administration are unavailable in SaaS mode.'; pl = 'Uwaga! W modelu serwisu jest niedostępne wykonanie funkcji administrowania klastera przez zastosowaną bazę informacyjną.';es_ES = '¡Atención! En el modelo de servicio no se admite la realización de las funciones de administrar el clúster por la base de información aplicada.';es_CO = '¡Atención! En el modelo de servicio no se admite la realización de las funciones de administrar el clúster por la base de información aplicada.';tr = 'Dikkat! Hizmet modeli, küme yönetimi işlevlerinin uygulama veri tabanını çalıştırmak için kullanılmaz.';it = 'Attenzione! Nel modello del servizio non è possibile l''esecuzione del database applicato delle funzioni di amministrazione del cluster.';de = 'Achtung! Im Servicemodell ist es inakzeptabel, dass die Anwendungsinformationsbasis Cluster-Administrationsfunktionen ausführt.'");
	EndIf;
	
	Return New COMObject(CommonClientServer.COMConnectorName());
#Else
	Return New COMObject(StandardSubsystemsClient.ClientRunParameters().COMConnectorName);
#EndIf
	
EndFunction

// Establishes a connection with the server agent.
//
// Parameters:
//  COMConnector - V8*.ComConnector COMObject,
//  ServerAgentAddress - String, network address of the server agent,
//  ServerAgentPort - Number, network port of the server agent (usually 1540).
//
// Returns: a COMObject implementing IV8AgentConnection interface.
//
Function ServerAgentConnection(COMConnector, Val ServerAgentAddress, Val ServerAgentPort)
	
	ServerAgentConnectionString = "tcp://" + ServerAgentAddress + ":" + Format(ServerAgentPort, "NG=0");
	ServerAgentConnection = COMConnector.ConnectAgent(ServerAgentConnectionString);
	Return ServerAgentConnection;
	
EndFunction

// Returns a server cluster.
//
// Parameters:
//  ServerAgentConnection - COMObject implementing IV8AgentConnection interface,
//  ClusterPort - Number, network port of the cluster manager (usually 1541),
//  ClusterAdministratorName - String, cluster administrator account name,
//  ClusterAdministratorPassword - String, cluster administrator account password.
//
// Returns: a COMObject implementing IClusterInfo interface.
//
Function GetCluster(ServerAgentConnection, Val ClusterPort, Val ClusterAdministratorName, Val ClusterAdministratorPassword)
	
	For Each Cluster In ServerAgentConnection.GetClusters() Do
		
		If Cluster.MainPort = ClusterPort Then
			
			ServerAgentConnection.Authenticate(Cluster, ClusterAdministratorName, ClusterAdministratorPassword);
			
			Return Cluster;
			
		EndIf;
		
	EndDo;
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'На рабочем сервере %1 не найден кластер %2'; en = 'The cluster %2 is not found on the working server %1.'; pl = 'Nie znaleziono klastra %2 na serwerze %1.';es_ES = 'Clúster %2 no encontrado en el servidor %1';es_CO = 'Clúster %2 no encontrado en el servidor %1';tr = '%2 kümesi çalışan %1 sunucusunda bulunamadı.';it = 'Il cluster %2 non è stato trovato sul server di lavoro %1.';de = 'Der Cluster %2 wurde nicht auf dem Server %1 gefunden'"),
		ServerAgentConnection.ConnectionString,
		ClusterPort);
	
EndFunction

// Establishes a connection with the working process.
//
// Parameters:
//  COMConnector - V8*.ComConnector COMObject,
//  ServerAgentConnection - COMObject implementing IV8AgentConnection interface,
//  Cluster - COMObject implementing IClusterInfo interface.
//
// Returns: COMObject that implements the IV8ServerConnection interface.
//
Function WorkingProcessConnection(COMConnector, ServerAgentConnection, Cluster)
	
	For Each WorkingProcess In ServerAgentConnection.GetWorkingProcesses(Cluster) Do
		If WorkingProcess.Running AND WorkingProcess.IsEnable  Then
			WorkingProcessConnectionString = WorkingProcess.HostName + ":" + Format(WorkingProcess.MainPort, "NG=");
			Return COMConnector.ConnectWorkingProcess(WorkingProcessConnectionString);
		EndIf;
	EndDo;
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'В кластере серверов %1:%2 не найдено активных рабочих процессов.'; en = 'Active working processes are not found in the server cluster %1:%2.'; pl = 'Nie znaleziono aktywnych procesów w klastrze serwerów %1:%2.';es_ES = 'Procesos activos no encontrados en el clúster del servidor %1:%2.';es_CO = 'Procesos activos no encontrados en el clúster del servidor %1:%2.';tr = 'Sunucu kümesinde etkin işlemler bulunamadı%1:%2.';it = 'Non sono stati trovati processi di lavoro attivi nel cluster di server %1:%2.';de = 'Aktive Prozesse werden im Server-Cluster nicht gefunden %1: %2.'"),
		Cluster.HostName,
		Format(Cluster.MainPort, "NG=0"));
	
EndFunction

// Returns an infobase description.
//
// Parameters:
//  ServerAgentConnection - COMObject implementing IV8AgentConnection interface,
//  Cluster - COMObject implementing IClusterInfo interface,
//  NameInCluster - String, name of an infobase in the cluster server.
//
// Returns: a COMObject implementing IInfoBaseShort interface.
//
Function GetIBDetails(ServerAgentConnection, Cluster, Val NameInCluster)
	
	For Each InfobaseDetails In ServerAgentConnection.GetInfoBases(Cluster) Do
		
		If Lower(InfobaseDetails.Name) = Lower(NameInCluster) Then
			
			Return InfobaseDetails;
			
		EndIf;
		
	EndDo;
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'В кластере серверов %1:%2 не найдена информационная база ""%3""'; en = 'The infobase ""%3"" is not found in the server cluster%1:%2.'; pl = 'W klasterze serwerów %1:%2 nie odnaleziono bazy informacyjnej ""%3""';es_ES = 'En el clúster de servidores %1:%2 no se ha encontrado base de información ""%3""';es_CO = 'En el clúster de servidores %1:%2 no se ha encontrado base de información ""%3""';tr = 'Sunucu kümesinde ""%3"" veritabanı bulunamadı%1:%2.';it = 'Infobase ""%3"" non trovata nel cluster dei server%1:%2.';de = 'Im Server-Cluster %1: %2 keine Informationsbasis ""%3"" gefunden'"),
		Cluster.HostName,
		Format(Cluster.MainPort, "NG=0"),
		NameInCluster);
	
EndFunction

// Returns an infobase.
//
// Parameters:
//  WorkingProcessConnection - COMObject implementing IV8ServerConnection interface,
//  Cluster - COMObject implementing IClusterInfo interface,
//  NameInCluster - String, name of an infobase in the cluster server,
//  IBAdministratorName - String - an infobase administrator name.
//  IBAdministratorPassword - String - an infobase administrator password.
//
// Returns: a COMObject implementing IInfoBaseInfo interface.
//
Function GetIB(WorkingProcessConnection, Cluster, Val NameInCluster, Val IBAdministratorName, Val IBAdministratorPassword)
	
	WorkingProcessConnection.AddAuthentication(IBAdministratorName, IBAdministratorPassword);
	
	For Each Infobase In WorkingProcessConnection.GetInfoBases() Do
		
		If Lower(Infobase.Name) = Lower(NameInCluster) Then
			
			If Not ValueIsFilled(Infobase.DBMS) Then
				
				Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Неправильные имя и пароль администратора информационной базы %1 в кластере серверов %2:%3 (имя: ""%4"").'; en = 'Incorrect administrator name or password for infobase %1 in the server cluster %2:%3 (name: ""%4"").'; pl = 'Niepoprawna nazwa lub hasło administratora w klastrze serwerów %2:%3 w bazie informacyjnej %1 (nazwa: ""%4"").';es_ES = 'El nombre de usuario del administrador o la contraseña es incorrecto en el clúster de servidores %2:%3 en la infobase %1 (nombre: ""%4"").';es_CO = 'El nombre de usuario del administrador o la contraseña es incorrecto en el clúster de servidores %2:%3 en la infobase %1 (nombre: ""%4"").';tr = 'Sunucu kümesinin veritabanı yöneticisinin kullanıcı adı veya şifresi yanlıştır %2:%3 veritabanı %1 (isim: ""%4"").';it = 'Il nome utente o password dell''amministratore del database informatico %1 del cluster %2:%3 sono incorretti (nome: ""%4"").';de = 'Der Benutzername oder das Kennwort des Administrators ist im Cluster der Server falsch %2: %3 in der Infobase %1 (Name: ""%4"").'"),
					NameInCluster,
					Cluster.HostName, 
					Cluster.MainPort,
					IBAdministratorName);
				
			EndIf;
			
			Return Infobase;
			
		EndIf;
		
	EndDo;
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'В кластере серверов %1:%2 не найдена информационная база ""%3""'; en = 'The infobase ""%3"" is not found in the server cluster%1:%2.'; pl = 'W klasterze serwerów %1:%2 nie odnaleziono bazy informacyjnej ""%3""';es_ES = 'En el clúster de servidores %1:%2 no se ha encontrado base de información ""%3""';es_CO = 'En el clúster de servidores %1:%2 no se ha encontrado base de información ""%3""';tr = 'Sunucu kümesinde ""%3"" veritabanı bulunamadı%1:%2.';it = 'Infobase ""%3"" non trovata nel cluster dei server%1:%2.';de = 'Im Server-Cluster %1: %2 keine Informationsbasis ""%3"" gefunden'"),
		Cluster.HostName,
		Format(Cluster.MainPort, "NG=0"),
		NameInCluster);
	
EndFunction

// Returns infobase sessions.
//
// Parameters:
//  ServerAgentConnection - COMObject implementing IV8AgentConnection interface,
//  Cluster - COMObject implementing IClusterInfo interface,
//  Infobase - COMObject implementing IInfoBaseInfo interface,
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
//  Details - Boolean - If False, the function returns an array of COMObjects that implements the 
//    ISessionInfo interface. If True, returns an array of structures that describe the session properties (structure fields, for more details see return value for the function
//    ClusterAdministrationClientServer.SessionProperties()).
//
// Returns: Array(COMObject), Array(Structure).
//
Function GetSessions(ServerAgentConnection, Cluster, Infobase, Val Filter = Undefined, Val DetailsList = False)
	
	Sessions = New Array;
	
	Dictionary = SessionPropertiesDictionary();
	
	For Each Session In ServerAgentConnection.GetInfoBaseSessions(Cluster, Infobase) Do
		
		SessionDetails = COMAdministratorObjectModelObjectDetails(Session, Dictionary);
		
		If ClusterAdministrationClientServer.CheckFilterConditions(SessionDetails, Filter) Then
			
			If DetailsList Then
				Sessions.Add(SessionDetails);
			Else
				Sessions.Add(Session);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Sessions;
	
EndFunction

// Returns infobase connections.
//
// Parameters:
//  COMConnector - V8*.ComConnector COMObject,
//  ServerAgentConnection - COMObject implementing IV8AgentConnection interface,
//  Cluster - COMObject implementing IClusterInfo interface,
//  NameInCluster - String, name of an infobase in the cluster server,
//  IBAdministratorName - String - an infobase administrator name.
//  InfobaseAdministratorPassword - String - an infobase administrator password.
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
//  Boolean - if False is passed, the function returns an array of COM objects that implement the
//             IConnectionShort interface. If True, returns an array of structures that describe the connection properties (structure fields,
//             function return value.
//    ClusterAdministrationClientServer.ConnectionProperties()).
//
// Returns: Array(COMObject), Array(Structure).
//
Function GetConnections(COMConnector, ServerAgentConnection, Cluster, IBAdministrationParameters, Val Filter = Undefined, Val DetailsList = False)
	
	NameInCluster = IBAdministrationParameters.NameInCluster;
	IBAdministratorName = IBAdministrationParameters.InfobaseAdministratorName;
	IBAdministratorPassword = IBAdministrationParameters.InfobaseAdministratorPassword;
	
	Connections = New Array();
	Dictionary = ConnectionPropertiesDictionary();
	
	// Working processes that are registered in the cluster.
	For each WorkingProcess In ServerAgentConnection.GetWorkingProcesses(Cluster) Do
		
		// Administrative connection with the working process.
		WorkingProcessConnectionString = WorkingProcess.HostName + ":" + Format(WorkingProcess.MainPort, "NG=");
		WorkingProcessConnection = COMConnector.ConnectWorkingProcess(WorkingProcessConnectionString);
		
		// Getting infobases (no authentication required).
		For each Infobase In WorkingProcessConnection.GetInfoBases() Do
			
			// This is a required infobase.
			If Lower(Infobase.Name) = Lower(NameInCluster) Then
				
				// Authentication is required to get infobase connection data.
				WorkingProcessConnection.AddAuthentication(IBAdministratorName, IBAdministratorPassword);
				
				// Getting infobase connections.
				For each Connection In WorkingProcessConnection.GetInfoBaseConnections(Infobase) Do
					
					ConnectionDetails = COMAdministratorObjectModelObjectDetails(Connection, Dictionary);
					
					// Checking whether the connection passes the filters.
					If ClusterAdministrationClientServer.CheckFilterConditions(ConnectionDetails, Filter) Then
						
						If DetailsList Then
							
							Connections.Add(ConnectionDetails);
							
						Else
							
							Connections.Add(New Structure("WorkingProcessConnection, Connection", WorkingProcessConnection, Connection));
							
						EndIf;
						
					EndIf;
				
				EndDo;
				
			EndIf;
			
		EndDo;
	
	EndDo;
	
	Return Connections;
	
EndFunction

// Returns a security profile.
//
// Parameters:
//  ServerAgentConnection - COMObject implementing IV8AgentConnection interface,
//  Cluster - COMObject implementing IClusterInfo interface,
//  ProfileName - String, a security profile name.
//
// Returns: a COMObject implementing ISecurityProfile interface.
//
Function GetSecurityProfile(ServerAgentConnection, Cluster, ProfileName)
	
	For Each SecurityProfile In ServerAgentConnection.GetSecurityProfiles(Cluster) Do
		
		If Lower(SecurityProfile.Name) = Lower(ProfileName) Then
			Return SecurityProfile;
		EndIf;
		
	EndDo;
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'В кластере серверов %1:%2 не найден профиль безопасности ""%3""'; en = 'The security profile ""%3"" is not found in the server cluster %1:%2.'; pl = 'W klasterze serwerów %1:%2 nie odnaleziono profilu bezpieczeństwa ""%3""';es_ES = 'En el clúster de servidores %1:%2 no se ha encontrado perfil de seguridad ""%3""';es_CO = 'En el clúster de servidores %1:%2 no se ha encontrado perfil de seguridad ""%3""';tr = 'Güvenlik profili %2 %1 sunucu kümesinde bulunamadı:%3';it = 'Profilo di sicurezza ""%3"" non trovato nel cluster dei server %1:%2.';de = 'Im Server-Cluster %1: %2 kein Sicherheitsprofil ""%3"" gefunden'"),
		Cluster.HostName,
		Format(Cluster.MainPort, "NG=0"),
		ProfileName);
	
EndFunction

// Returns virtual directories allowed in the security profile.
//
// Parameters:
//  ServerAgentConnection - COMObject implementing IV8AgentConnection interface,
//  Cluster - COMObject implementing IClusterInfo interface,
//  ProfileName - String, a security profile name.
//
// Returns: Array(COMObject) - an array of COM objects implementing interface
// ISecurityProfileVirtualDirectory.
//
Function GetVirtualDirectories(ServerAgentConnection, Cluster, ProfileName)
	
	VirtualDirectories = New Array();
	
	For Each VirtualDirectory In ServerAgentConnection.GetSecurityProfileVirtualDirectories(Cluster, ProfileName) Do
		
		VirtualDirectories.Add(VirtualDirectory);
		
	EndDo;
	
	Return VirtualDirectories;
	
EndFunction

// Returns COM classes allowed in a security profile.
//
// Parameters:
//  ServerAgentConnection - COMObject implementing IV8AgentConnection interface,
//  Cluster - COMObject implementing IClusterInfo interface,
//  ProfileName - String, a security profile name.
//
// Returns: Array(COMObject) - an array of COM objects implementing ISecurityProfileCOMClass interface.
//
Function GetCOMClasses(ServerAgentConnection, Cluster, ProfileName)
	
	COMClasses = New Array();
	
	For Each COMClass In ServerAgentConnection.GetSecurityProfileCOMClasses(Cluster, ProfileName) Do
		
		COMClasses.Add(COMClass);
		
	EndDo;
	
	Return COMClasses;
	
EndFunction

// Returns add-ins allowed in the security profile.
//
// Parameters:
//  ServerAgentConnection - COMObject implementing IV8AgentConnection interface,
//  Cluster - COMObject implementing IClusterInfo interface,
//  ProfileName - String, a security profile name.
//
// Returns: Array(COMObject) - an array of COM objects implementing ISecurityProfileAddIn interface.
//
Function GetAddIns(ServerAgentConnection, Cluster, ProfileName)
	
	AddIns = New Array();
	
	For Each AddIn In ServerAgentConnection.GetSecurityProfileAddIns(Cluster, ProfileName) Do
		
		AddIns.Add(AddIn);
		
	EndDo;
	
	Return AddIns;
	
EndFunction

// Returns external modules allowed in the security profile.
//
// Parameters:
//  ServerAgentConnection - COMObject implementing IV8AgentConnection interface,
//  Cluster - COMObject implementing IClusterInfo interface,
//  ProfileName - String, a security profile name.
//
// Returns: Array(COMObject) - an array of COM objects implementing ISecurityProfileExternalModule interface.
//
Function GetExternalModules(ServerAgentConnection, Cluster, ProfileName)
	
	ExternalModules = New Array();
	
	For Each ExternalModule In ServerAgentConnection.GetSecurityProfileUnSafeExternalModules(Cluster, ProfileName) Do
		
		ExternalModules.Add(ExternalModule);
		
	EndDo;
	
	Return ExternalModules;
	
EndFunction

// Returns OS applications allowed in the security profile.
//
// Parameters:
//  ServerAgentConnection - COMObject implementing IV8AgentConnection interface,
//  Cluster - COMObject implementing IClusterInfo interface,
//  ProfileName - String, a security profile name.
//
// Returns: Array(COMObject) - an array of COM objects implementing ISecurityProfileApplication interface.
//
Function GetOSApplications(ServerAgentConnection, Cluster, ProfileName)
	
	OSApplications = New Array();
	
	For Each OSApplication In ServerAgentConnection.GetSecurityProfileApplications(Cluster, ProfileName) Do
		
		OSApplications.Add(OSApplication);
		
	EndDo;
	
	Return OSApplications;
	
EndFunction

// Returns OS applications allowed in the security profile.
//
// Parameters:
//  ServerAgentConnection - COMObject implementing IV8AgentConnection interface,
//  Cluster - COMObject implementing IClusterInfo interface,
//  ProfileName - String, a security profile name.
//
// Returns: Array(COMObject) - an array of COM objects implementing interface
// ISecurityProfileInternetResource.
//
Function GetInternetResources(ServerAgentConnection, Cluster, ProfileName)
	
	InternetResources = New Array();
	
	For Each InternetResource In ServerAgentConnection.GetSecurityProfileInternetResources(Cluster, ProfileName) Do
		
		InternetResources.Add(InternetResource);
		
	EndDo;
	
	Return InternetResources;
	
EndFunction

// Overwrites the security profile properties using the passed data.
//
// Parameters:
//  ServerAgentConnection - COMObject implementing IV8AgentConnection interface,
//  Cluster - COMObject implementing IClusterInfo interface,
//  SecurityProfile - a COMObject implementing ISecurityProfile interface,
//  SecurityProfileProperties - Structure that describes the security profile. Composition - for more details see
//    ClusterAdministrationClientServer.SecurityProfileProperties().
//
Procedure ApplySecurityProfilePropertyChanges(ServerAgentConnection, Cluster, SecurityProfile, SecurityProfileProperties)
	
	FillCOMAdministratorObjectModelObjectPropertiesByDeclaration(
		SecurityProfile,
		SecurityProfileProperties,
		SecurityProfilePropertiesDictionary());
	
	ProfileName = SecurityProfileProperties.Name;
	
	ServerAgentConnection.RegSecurityProfile(Cluster, SecurityProfile);
	
	// Virtual directories
	VirtualDirectoriesToDelete = GetVirtualDirectories(ServerAgentConnection, Cluster, ProfileName);
	For Each VirtualDirectoryToDelete In VirtualDirectoriesToDelete Do
		ServerAgentConnection.UnregSecurityProfileVirtualDirectory(
			Cluster,
			ProfileName,
			VirtualDirectoryToDelete.Alias);
	EndDo;
	VirtualDirectoriesToCreate = SecurityProfileProperties.VirtualDirectories;
	For Each VirtualDirectoryToCreate In VirtualDirectoriesToCreate Do
		VirtualDirectory = ServerAgentConnection.CreateSecurityProfileVirtualDirectory();
		FillCOMAdministratorObjectModelObjectPropertiesByDeclaration(
			VirtualDirectory,
			VirtualDirectoryToCreate,
			VirtualDirectoryPropertiesDictionary());
		ServerAgentConnection.RegSecurityProfileVirtualDirectory(Cluster, ProfileName, VirtualDirectory);
	EndDo;
	
	// Allowed COM classes.
	COMClassesToDelete = GetCOMClasses(ServerAgentConnection, Cluster, ProfileName);
	For Each COMClassToDelete In COMClassesToDelete Do
		ServerAgentConnection.UnregSecurityProfileCOMClass(
			Cluster,
			ProfileName,
			COMClassToDelete.Name);
	EndDo;
	COMClassesToCreate = SecurityProfileProperties.COMClasses;
	For Each COMClassToCreate In COMClassesToCreate Do
		COMClass = ServerAgentConnection.CreateSecurityProfileCOMClass();
		FillCOMAdministratorObjectModelObjectPropertiesByDeclaration(
			COMClass,
			COMClassToCreate,
			COMClassPropertiesDictionary());
		ServerAgentConnection.RegSecurityProfileCOMClass(Cluster, ProfileName, COMClass);
	EndDo;
	
	// Add-ins
	AddInsToDelete = GetAddIns(ServerAgentConnection, Cluster, ProfileName);
	For Each AddInToDelete In AddInsToDelete Do
		ServerAgentConnection.UnregSecurityProfileAddIn(
			Cluster,
			ProfileName,
			AddInToDelete.Name);
	EndDo;
	AddInsToCreate = SecurityProfileProperties.AddIns;
	For Each AddInToCreate In AddInsToCreate Do
		AddIn = ServerAgentConnection.CreateSecurityProfileAddIn();
		FillCOMAdministratorObjectModelObjectPropertiesByDeclaration(
			AddIn,
			AddInToCreate,
			AddInPropertiesDictionary());
		ServerAgentConnection.RegSecurityProfileAddIn(Cluster, ProfileName, AddIn);
	EndDo;
	
	// External modules
	ExternalModulesToDelete = GetExternalModules(ServerAgentConnection, Cluster, ProfileName);
	For Each ExternalModuleToDelete In ExternalModulesToDelete Do
		ServerAgentConnection.UnregSecurityProfileUnSafeExternalModule(
			Cluster,
			ProfileName,
			ExternalModuleToDelete.Name);
	EndDo;
	ExternalModulesToCreate = SecurityProfileProperties.ExternalModules;
	For Each ExternalModuleToCreate In ExternalModulesToCreate Do
		ExternalModule = ServerAgentConnection.CreateSecurityProfileUnSafeExternalModule();
		FillCOMAdministratorObjectModelObjectPropertiesByDeclaration(
			ExternalModule,
			ExternalModuleToCreate,
			ExternalModulePropertiesDictionary());
		ServerAgentConnection.RegSecurityProfileUnSafeExternalModule(Cluster, ProfileName, ExternalModule);
	EndDo;
	
	// OS applications
	OSApplicationsToDelete = GetOSApplications(ServerAgentConnection, Cluster, ProfileName);
	For Each OSApplicationToDelete In OSApplicationsToDelete Do
		ServerAgentConnection.UnregSecurityProfileApplication(
			Cluster,
			ProfileName,
			OSApplicationToDelete.Name);
	EndDo;
	OSApplicationsToCreate = SecurityProfileProperties.OSApplications;
	For Each OSApplicationToCreate In OSApplicationsToCreate Do
		OSApplication = ServerAgentConnection.CreateSecurityProfileApplication();
		FillCOMAdministratorObjectModelObjectPropertiesByDeclaration(
			OSApplication,
			OSApplicationToCreate,
			OSApplicationPropertiesDictionary());
		ServerAgentConnection.RegSecurityProfileApplication(Cluster, ProfileName, OSApplication);
	EndDo;
	
	// Internet resources
	InternetResourcesToDelete = GetInternetResources(ServerAgentConnection, Cluster, ProfileName);
	For Each InternetResourceToDelete In InternetResourcesToDelete Do
		ServerAgentConnection.UnregSecurityProfileInternetResource(
			Cluster,
			ProfileName,
			InternetResourceToDelete.Name);
	EndDo;
	InternetResourcesToCreate = SecurityProfileProperties.InternetResources;
	For Each InternetResourceToCreate In InternetResourcesToCreate Do
		InternetResource = ServerAgentConnection.CreateSecurityProfileInternetResource();
		FillCOMAdministratorObjectModelObjectPropertiesByDeclaration(
			InternetResource,
			InternetResourceToCreate,
			InternetResourcePropertiesDictionary());
		ServerAgentConnection.RegSecurityProfileInternetResource(Cluster, ProfileName, InternetResource);
	EndDo;
	
EndProcedure

// Generates a description for an object in COM administrator object model.
//
// Parameters:
//  Object - COMObject,
//  Dictionary - Map - containing the object property map where:
//    Key - Property name in description,
//    Value - Object property name.
//
// Returns: Structure - description of the COM administrator object model object by the passed 
//  dictionary.
//
Function COMAdministratorObjectModelObjectDetails(Val Object, Val Dictionary)
	
	Details = New Structure();
	For Each DictionaryFragment In Dictionary Do
		If ValueIsFilled(Object[DictionaryFragment.Value]) Then
			Details.Insert(DictionaryFragment.Key, Object[DictionaryFragment.Value]);
		Else
			Details.Insert(DictionaryFragment.Key, Undefined);
		EndIf;
	EndDo;
	
	Return Details;
	
EndFunction

// Generates descriptions of COM administrator object model objects.
//
// Parameters:
//  Objects - Array(COMObject),
//  Dictionary - Map - containing the object property map where:
//    Key - Property name in description,
//    Value - Object property name.
//
// Returns: Array of Structure - description of COM administrator object model objects by the passed 
//  dictionary.
//
Function COMAdministratorObjectModelObjectsDetails(Val Objects, Val Dictionary)
	
	DetailsList = New Array();
	
	For Each Object In Objects Do
		DetailsList.Add(COMAdministratorObjectModelObjectDetails(Object, Dictionary));
	EndDo;
	
	Return DetailsList;
	
EndFunction

// Fills properties of the COM administrator object model object by the properties from the passed 
//  description.
//
// Parameters:
//  Object - COMObject,
//  Description - Structure - a description used to fill object properties,
//  Dictionary - Map - containing the object property map where:
//    Key - Property name in description,
//    Value - Object property name.
//
Procedure FillCOMAdministratorObjectModelObjectPropertiesByDeclaration(Object, Val Details, Val Dictionary)
	
	For Each DictionaryFragment In Dictionary Do
		
		PropertyName = DictionaryFragment.Value;
		PropertyValue = Details[DictionaryFragment.Key];
		
		Object[PropertyName] = PropertyValue;
		
	EndDo;
	
EndProcedure

// Returns a map of the infobase property names (that describe states of session lock and scheduled 
//  jobs for structures used in the API) and COM administrator object model objects.
//  
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see
//         ClusterAdministrationClientServer.SessionAndScheduleJobLockProperties()),
//  Value - String - the name of an object property.
//
Function SessionAndScheduledJobLockPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("SessionsLock", "SessionsDenied");
	Result.Insert("DateFrom", "DeniedFrom");
	Result.Insert("DateTo", "DeniedTo");
	Result.Insert("Message", "DeniedMessage");
	Result.Insert("KeyCode", "PermissionCode");
	Result.Insert("LockParameter", "DeniedParameter");
	Result.Insert("ScheduledJobLock", "ScheduledJobsDenied");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a map of the infobase session property names used in the API and COM administrator object 
//  model objects.
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see ClusterAdministrationClientServer.SessionProperties()).
//  Value - String - the name of an object property.
//
Function SessionPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Number", "SessionID");
	Result.Insert("UserName", "UserName");
	Result.Insert("ClientComputerName", "Host");
	Result.Insert("ClientApplicationID", "AppID");
	Result.Insert("LanguageID", "Locale");
	Result.Insert("SessionCreationTime", "StartedAt");
	Result.Insert("LatestSessionActivityTime", "LastActiveAt");
	Result.Insert("DBMSLock", "blockedByDBMS");
	Result.Insert("Lock", "blockedByLS");
	Result.Insert("Passed", "bytesAll");
	Result.Insert("PassedIn5Minutes", "bytesLast5Min");
	Result.Insert("ServerCalls", "callsAll");
	Result.Insert("ServerCallsIn5Minutes", "callsLast5Min");
	Result.Insert("ServerCallsDurations", "durationAll");
	Result.Insert("CurrentServerCallDuration", "durationCurrent");
	Result.Insert("ServerCallsDurationsIn5Minutes", "durationLast5Min");
	Result.Insert("ExchangedWithDBMS", "dbmsBytesAll");
	Result.Insert("ExchangedWithDBMSIn5Minutes", "dbmsBytesLast5Min");
	Result.Insert("DBMSCallsDurations", "durationAllDBMS");
	Result.Insert("CurrentDBMSCallDuration", "durationCurrentDBMS");
	Result.Insert("DBMSCallsDurationsIn5Minutes", "durationLast5MinDBMS");
	Result.Insert("DBMSConnection", "dbProcInfo");
	Result.Insert("DBMSConnectionTime", "dbProcTook");
	Result.Insert("DBMSConnectionSeizeTime", "dbProcTookAt");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a map of the infobase connection property names used in the API and COM administrator 
//  object model objects.
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see ClusterAdministrationClientServer.ConnectionProperties()).
//  Value - String - the name of an object property.
//
Function ConnectionPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Number", "ConnID");
	Result.Insert("UserName", "UserName");
	Result.Insert("ClientComputerName", "HostName");
	Result.Insert("ClientApplicationID", "AppID");
	Result.Insert("ConnectionEstablishingTime", "ConnectedAt");
	Result.Insert("InfobaseConnectionMode", "IBConnMode");
	Result.Insert("DataBaseConnectionMode", "dbConnMode");
	Result.Insert("DBMSLock", "blockedByDBMS");
	Result.Insert("Passed", "bytesAll");
	Result.Insert("PassedIn5Minutes", "bytesLast5Min");
	Result.Insert("ServerCalls", "callsAll");
	Result.Insert("ServerCallsIn5Minutes", "callsLast5Min");
	Result.Insert("ExchangedWithDBMS", "dbmsBytesAll");
	Result.Insert("ExchangedWithDBMSIn5Minutes", "dbmsBytesLast5Min");
	Result.Insert("DBMSConnection", "dbProcInfo");
	Result.Insert("DBMSTime", "dbProcTook");
	Result.Insert("DBMSConnectionSeizeTime", "dbProcTookAt");
	Result.Insert("ServerCallsDurations", "durationAll");
	Result.Insert("DBMSCallsDurations", "durationAllDBMS");
	Result.Insert("CurrentServerCallDuration", "durationCurrent");
	Result.Insert("CurrentDBMSCallDuration", "durationCurrentDBMS");
	Result.Insert("ServerCallsDurationsIn5Minutes", "durationLast5Min");
	Result.Insert("DBMSCallsDurationsIn5Minutes", "durationLast5MinDBMS");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a map of the security profile property names used in the API and COM administrator object 
//  model objects.
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see ClusterAdministrationClientServer.SecurityProfileProperties()).
//  Value - String - the name of an object property.
//
Function SecurityProfilePropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "Name");
	Result.Insert("Details", "Descr");
	Result.Insert("SafeModeProfile", "SafeModeProfile");
	Result.Insert("FullAccessToPrivilegedMode", "PrivilegedModeInSafeModeAllowed");
	
	Result.Insert("FullFileSystemAccess", "FileSystemFullAccess");
	Result.Insert("FullCOMObjectAccess", "COMFullAccess");
	Result.Insert("FullAddInAccess", "AddInFullAccess");
	Result.Insert("FullExternalModuleAccess", "UnSafeExternalModuleFullAccess");
	Result.Insert("FullOperatingSystemApplicationAccess", "ExternalAppFullAccess");
	Result.Insert("FullInternetResourceAccess", "InternetFullAccess");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a map of the virtual directory property names used in the API and COM administrator 
//  object model objects.
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see ClusterAdministrationClientServer.VirtualDirectoryProperties()).
//  Value - String - the name of an object property.
//
Function VirtualDirectoryPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("LogicalURL", "Alias");
	Result.Insert("PhysicalURL", "PhysicalPath");
	
	Result.Insert("Details", "Descr");
	
	Result.Insert("DataReader", "AllowedRead");
	Result.Insert("DataWriter", "AllowedWrite");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a map of the COM class property names used in the API and COM administrator object model 
//  objects.
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see ClusterAdministrationClientServer.COMClassProperties()).
//  Value - String - the name of an object property.
//
Function COMClassPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "Name");
	Result.Insert("Details", "Descr");
	
	Result.Insert("FileMoniker", "FileName");
	Result.Insert("CLSID", "ObjectUUID");
	Result.Insert("Computer", "ComputerName");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a map of the add-in property names used in the API and COM administrator object model 
//  objects.
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see ClusterAdministrationClientServer.AddInProperties()).
//  Value - String - the name of an object property.
//
Function AddInPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "Name");
	Result.Insert("Details", "Descr");
	
	Result.Insert("HashSum", "AddInHash");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a map of the external module property names used in the API and COM administrator object 
//  model objects.
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see ClusterAdministrationClientServer.ExternalModuleProperties()).
//  Value - String - the name of an object property.
//
Function ExternalModulePropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "Name");
	Result.Insert("Details", "Descr");
	
	Result.Insert("HashSum", "ExternalModuleHash");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a map of the operating system application property names used in the API and COM 
//  administrator object model objects.
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see ClusterAdministrationClientServer.OSApplicationProperties()).
//  Value - String - the name of an object property.
//
Function OSApplicationPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "Name");
	Result.Insert("Details", "Descr");
	
	Result.Insert("CommandLinePattern", "CommandMask");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a map of the Internet resource property names used in the API and COM administrator 
//  object model objects.
//
// Returns: FixedStructure:
//  Key - String - the name of an API property (see ClusterAdministrationClientServer.InternetResourceProperties()).
//  Value - String - the name of an object property.
//
Function InternetResourcePropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "Name");
	Result.Insert("Details", "Descr");
	
	Result.Insert("Protocol", "Protocol");
	Result.Insert("Address", "Address");
	Result.Insert("Port", "Port");
	
	Return New FixedStructure(Result);
	
EndFunction

#EndRegion