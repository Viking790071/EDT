#Region Public

////////////////////////////////////////////////////////////////////////////////
// Locking the infobase and terminating connections.

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
Function SetConnectionLock(Val MessageText = "",
	Val KeyCode = "KeyCode") Export
	
	If Common.DataSeparationEnabled() AND Common.SeparatedDataUsageAvailable() Then
		
		If Not Users.IsFullUser() Then
			Return False;
		EndIf;
		
		Lock = NewConnectionLockParameters();
		Lock.Use = True;
		Lock.Begin = CurrentSessionDate();
		Lock.Message = GenerateLockMessage(MessageText, KeyCode);
		Lock.Exclusive = Users.IsFullUser(, True);
		SetDataAreaSessionLock(Lock);
		Return True;
	Else
		If Not Users.IsFullUser(, True) Then
			Return False;
		EndIf;
		
		Lock = New SessionsLock;
		Lock.Use = True;
		Lock.Begin = CurrentSessionDate();
		Lock.KeyCode = KeyCode;
		Lock.Message = GenerateLockMessage(MessageText, KeyCode);
		SetSessionsLock(Lock);
		Return True;
	EndIf;
	
EndFunction

// Determines whether connection lock is set for the infobase configuration batch update.
// 
//
// Returns:
//    Boolean - True if the lock is set, otherwise False.
//
Function ConnectionsLocked() Export
	
	LockParameters = CurrentConnectionLockParameters();
	Return LockParameters.ConnectionsLocked;
	
EndFunction

// Gets the infobase connection lock parameters to be used at client side.
//
// Parameters:
//    GetSessionCount - Boolean - if True, then the SessionCount field is filled in the returned 
//                                         structure.
//
// Returns:
//   Structure - with the following properties:
//     * IsSet - Boolean - True if the lock is set, otherwise False.
//     * Start - Date - lock start date.
//     * End - Date - lock end date.
//     * Message - String - message to a user.
//     * SessionTerminationTimeout - Number - interval in seconds.
//     * SessionCount - Number - 0 if the GetSessionCount parameter value is False.
//     * CurrentSessionDate - Date - current session date.
//
Function SessionLockParameters(Val GetSessionCount = False) Export
	
	LockParameters = CurrentConnectionLockParameters();
	Return AdvancedSessionLockParameters(GetSessionCount, LockParameters);
	
EndFunction

// Removes the infobase lock.
//
// Returns:
//   Boolean - True if the operation is successful.
//              False if the operation cannot be performed due to insufficient rights.
//
Function AllowUserAuthorization() Export
	
	If Common.DataSeparationEnabled() AND Common.SeparatedDataUsageAvailable() Then
		
		If Not Users.IsFullUser() Then
			Return False;
		EndIf;
		
		CurrentMode = GetDataAreaSessionLock();
		If CurrentMode.Use Then
			NewMode = NewConnectionLockParameters();
			NewMode.Use = False;
			SetDataAreaSessionLock(NewMode);
		EndIf;
		Return True;
		
	Else
		If NOT Users.IsFullUser(, True) Then
			Return False;
		EndIf;
		
		CurrentMode = GetSessionsLock();
		If CurrentMode.Use Then
			NewMode = New SessionsLock;
			NewMode.Use = False;
			SetSessionsLock(NewMode);
		EndIf;
		Return True;
	EndIf;
	
EndFunction

// Returns information about the current connections to the infobase.
// If necessary, writes a message to the event log.
//
// Parameters:
//    GetConnectionString - Boolean - add the connection string to the return value.
//    MessagesForEventLog - ValueList - if the parameter is not blank, the events from the list will 
//                                                      be written to the event log.
//    ClusterPort - Number - Non-standard port of a server cluster.
//
// Returns:
//    Structure - structure with the following properties:
//        * HasActiveConnections - Boolean - shows if there are active connections.
//        * HasCOMConnections - Boolean - shows if there are COM connections.
//        * HasDesignerConnection - shows if there is a designer connection.
//        * HasActiveUsers - Boolean - shows if there are active users.
//        * InfoBaseConnectionString - String - infobase connection string. The property is present 
//                                                        only if the GetConnectionString parameter value is True.
//
Function ConnectionsInformation(GetConnectionString = False,
	MessagesForEventLog = Undefined, ClusterPort = 0) Export
	
	SetPrivilegedMode(True);
	
	Result = New Structure();
	Result.Insert("HasActiveConnections", False);
	Result.Insert("HasCOMConnections", False);
	Result.Insert("HasDesignerConnection", False);
	Result.Insert("HasActiveUsers", False);
	
	If InfoBaseUsers.GetUsers().Count() > 0 Then
		Result.HasActiveUsers = True;
	EndIf;
	
	If GetConnectionString Then
		Result.Insert("InfobaseConnectionString",
			IBConnectionsClientServer.GetInfobaseConnectionString(ClusterPort));
	EndIf;
		
	EventLogOperations.WriteEventsToEventLog(MessagesForEventLog);
	
	SessionsArray = GetInfoBaseSessions();
	If SessionsArray.Count() = 1 Then
		Return Result;
	EndIf;
	
	Result.HasActiveConnections = True;
	
	For Each Session In SessionsArray Do
		If Upper(Session.ApplicationName) = Upper("COMConnection") Then // COM connection
			Result.HasCOMConnections = True;
		ElsIf Upper(Session.ApplicationName) = Upper("Designer") Then // Designer
			Result.HasDesignerConnection = True;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Data area session lock.

// Gets an empty structure with data area session lock parameters.
// 
// Returns:
//   Structure - with the following fields:
//     Start - Date - time the lock became active.
//     End - Date - time the lock ended.
//     Message - String - messages for users attempting to access the locked data area.
//     IsSet - Boolean - shows if the lock is set.
//     IsExclusive - Boolean - the lock cannot be modified by the application administrator.
//
Function NewConnectionLockParameters() Export
	
	Result = New Structure;
	Result.Insert("End", Date(1,1,1));
	Result.Insert("Begin", Date(1,1,1));
	Result.Insert("Message", "");
	Result.Insert("Use", False);
	Result.Insert("Exclusive", False);
	
	Return Result;
	
EndFunction

// Sets the data area session lock.
// 
// Parameters:
//   Parameters - Structure - see NewConnectionLockParameters. 
//   LocalTime - Boolean - lock beginning time and lock end time are specified in the local session time.
//                                If the parameter is False, they are specified in universal time.
//   DataArea - Number - number of the data area to be locked.
//     When calling this procedure from a session with separator values set, only a value equal to 
//       the session separator value (or unspecified) can be passed.
//     When calling this procedure from a session with separator values not set, the parameter value must be specified.
//
Procedure SetDataAreaSessionLock(Parameters, Val LocalTime = True, Val DataArea = -1) Export
	
	If Not Users.IsFullUser() Then
		Raise NStr("ru ='???????????????????????? ???????? ?????? ???????????????????? ????????????????'; en = 'Insufficient rights to perform the operation'; pl = 'Nie masz wystarczaj??cych uprawnie?? do wykonania operacji';es_ES = 'Insuficientes derechos para realizar la operaci??n';es_CO = 'Insuficientes derechos para realizar la operaci??n';tr = '????lem i??in gerekli yetkiler yok';it = 'Autorizzazioni insufficienti per eseguire l''operazione';de = 'Unzureichende Rechte auf Ausf??hren der Operation'");
	EndIf;
	
	Exclusive = False;
	If Not Parameters.Property("Exclusive", Exclusive) Then
		Exclusive = False;
	EndIf;
	If Exclusive AND Not Users.IsFullUser(, True) Then
		Raise NStr("ru ='???????????????????????? ???????? ?????? ???????????????????? ????????????????'; en = 'Insufficient rights to perform the operation'; pl = 'Nie masz wystarczaj??cych uprawnie?? do wykonania operacji';es_ES = 'Insuficientes derechos para realizar la operaci??n';es_CO = 'Insuficientes derechos para realizar la operaci??n';tr = '????lem i??in gerekli yetkiler yok';it = 'Autorizzazioni insufficienti per eseguire l''operazione';de = 'Unzureichende Rechte auf Ausf??hren der Operation'");
	EndIf;
	
	If Common.SeparatedDataUsageAvailable() Then
		
		If Common.SubsystemExists("StandardSubsystems.SaaS") Then
			ModuleSaaS = Common.CommonModule("SaaS");
			SessionSeparatorValue = ModuleSaaS.SessionSeparatorValue();
		Else
			SessionSeparatorValue = 0;
		EndIf;
		
		If DataArea = -1 Then
			DataArea = SessionSeparatorValue;
		ElsIf DataArea <> SessionSeparatorValue Then
			Raise NStr("ru = '???? ???????????? ?? ?????????????????????????? ???????????????????? ???????????????????????? ???????????? ???????????????????? ???????????????????? ?????????????? ?????????????? ????????????, ???????????????? ???? ???????????????????????? ?? ????????????.'; en = 'Running a session with used separator values, you cannot set a session lock for a data area that is different from the one used in the session.'; pl = 'Uruchamiaj??c sesj?? z u??ywanymi warto??ciami separatora, nie mo??na ustawi?? blokady sesji dla obszaru danych innego ni?? u??ywane w sesji.';es_ES = 'Lanzando una sesi??n con los valores del separador utilizado, usted no puede establecer un bloqueo de sesi??n para un ??rea de datos que es diferente de aquella utilizada en la sesi??n.';es_CO = 'Lanzando una sesi??n con los valores del separador utilizado, usted no puede establecer un bloqueo de sesi??n para un ??rea de datos que es diferente de aquella utilizada en la sesi??n.';tr = 'Kullan??lan ay??r??c?? de??erleri olan bir oturumdan, oturumda kullan??landan farkl?? bir veri alan?? i??in bir oturum kilidi ayarlayamazs??n??z.';it = 'Esecuzione di una sessione con valori separatore utilizzato, non ?? possibile impostare un blocco di sessione per un''area di dati che ?? diverso da quello utilizzato nella sessione.';de = 'Wenn Sie eine Sitzung mit verwendeten Trennzeichenwerten ausf??hren, k??nnen Sie keine Sitzungssperre f??r einen Datenbereich festlegen, der sich von dem in der Sitzung verwendeten unterscheidet.'");
		EndIf;
		
	Else
		
		If DataArea = -1 Then
			Raise NStr("ru = '???????????????????? ???????????????????? ???????????????????? ?????????????? ?????????????? ???????????? - ???? ?????????????? ?????????????? ????????????.'; en = 'Cannot lock data area sessions - data area is not specified.'; pl = 'Nie mo??na ustawi?? blokad?? sesji obszarze danych - nie okre??lono obszar danych.';es_ES = 'No se puede establecer el bloqueo para las sesiones del ??rea de datos, porque el ??rea de datos no se ha especificado.';es_CO = 'No se puede establecer el bloqueo para las sesiones del ??rea de datos, porque el ??rea de datos no se ha especificado.';tr = 'Veri alan?? belirlenmedi??inden dolay??, veri alan?? oturumlar?? kilitlenemedi.';it = 'Impossibile impostare il blocco delle sessioni dell''area dati: l''area dati non ?? specificata.';de = 'Datensitzungssitzungssperre kann nicht festgelegt werden- Es wurde kein Datenbereich angegeben.'");
		EndIf;
		
	EndIf;
	
	SettingsStructure = Parameters;
	If TypeOf(Parameters) = Type("SessionsLock") Then
		SettingsStructure = NewConnectionLockParameters();
		FillPropertyValues(SettingsStructure, Parameters);
	EndIf;

	SetPrivilegedMode(True);
	LockSet = InformationRegisters.DataAreaSessionLocks.CreateRecordSet();
	LockSet.Filter.DataAreaAuxiliaryData.Set(DataArea);
	LockSet.Read();
	LockSet.Clear();
	If Parameters.Use Then 
		Lock = LockSet.Add();
		Lock.DataAreaAuxiliaryData = DataArea;
		Lock.LockStart = ?(LocalTime AND ValueIsFilled(SettingsStructure.Begin), 
			ToUniversalTime(SettingsStructure.Begin), SettingsStructure.Begin);
		Lock.LockEnd = ?(LocalTime AND ValueIsFilled(SettingsStructure.End), 
			ToUniversalTime(SettingsStructure.End), SettingsStructure.End);
		Lock.LockMessage = SettingsStructure.Message;
		Lock.Exclusive = SettingsStructure.Exclusive;
	EndIf;
	LockSet.Write();
	
EndProcedure

// Gets information on the data area session lock.
// 
// Parameters:
//   LocalTime - Boolean - lock beginning time and lock end time are returned in the local session 
//                                time zone. If the parameter is False, they are returned in 
//                                universal time.
//
// Returns:
//   Structure - see NewConnectionLockParameters. 
//
Function GetDataAreaSessionLock(Val LocalTime = True) Export
	
	Result = NewConnectionLockParameters();
	If Not Common.DataSeparationEnabled() Or Not Common.SeparatedDataUsageAvailable() Then
		Return Result;
	EndIf;
	
	If Not Users.IsFullUser() Then
		Raise NStr("ru ='???????????????????????? ???????? ?????? ???????????????????? ????????????????'; en = 'Insufficient rights to perform the operation'; pl = 'Nie masz wystarczaj??cych uprawnie?? do wykonania operacji';es_ES = 'Insuficientes derechos para realizar la operaci??n';es_CO = 'Insuficientes derechos para realizar la operaci??n';tr = '????lem i??in gerekli yetkiler yok';it = 'Autorizzazioni insufficienti per eseguire l''operazione';de = 'Unzureichende Rechte auf Ausf??hren der Operation'");
	EndIf;
	
	ModuleSaaS = Common.CommonModule("SaaS");
	
	SetPrivilegedMode(True);
	LockSet = InformationRegisters.DataAreaSessionLocks.CreateRecordSet();
	LockSet.Filter.DataAreaAuxiliaryData.Set(
		ModuleSaaS.SessionSeparatorValue());
	LockSet.Read();
	If LockSet.Count() = 0 Then
		Return Result;
	EndIf;
	Lock = LockSet[0];
	Result.Begin = ?(LocalTime AND ValueIsFilled(Lock.LockStart), 
		ToLocalTime(Lock.LockStart), Lock.LockStart);
	Result.End = ?(LocalTime AND ValueIsFilled(Lock.LockEnd), 
		ToLocalTime(Lock.LockEnd), Lock.LockEnd);
	Result.Message = Lock.LockMessage;
	Result.Exclusive = Lock.Exclusive;
	Result.Use = True;
	If ValueIsFilled(Lock.LockEnd) AND CurrentSessionDate() > Lock.LockEnd Then
		Result.Use = False;
	EndIf;
	Return Result;
	
EndFunction

#EndRegion

#Region Internal

// Returns a text string containing the active infobase connection list.
// The connection names are separated by line breaks.
//
// Parameters:
//	Message - String - string to pass.
//
// Returns:
//   String - connection names.
//
Function ActiveSessionsMessage() Export
	
	Message = NStr("ru = '???? ?????????????? ?????????????????? ????????????:'; en = 'Cannot disable sessions:'; pl = 'Nie mo??na wy????czy?? sesji:';es_ES = 'No se puede desactivar las sesiones:';es_CO = 'No se puede desactivar las sesiones:';tr = 'Oturumlar devre d?????? b??rak??lamaz:';it = 'Impossibile disconnettere le sessioni:';de = 'Sitzungen k??nnen nicht deaktiviert werden:'");
	CurrentSessionNumber = InfoBaseSessionNumber();
	For Each Session In GetInfoBaseSessions() Do
		If Session.SessionNumber <> CurrentSessionNumber Then
			Message = Message + Chars.LF + "??? " + Session;
		EndIf;
	EndDo;
	
	Return Message;
	
EndFunction

// Gets the number of active infobase sessions.
//
// Parameters:
//   IncludeConsole - Boolean - if False, the server cluster console sessions are excluded.
//                               The server cluster console sessions do not prevent execution of 
//                               administrative operations (enabling the exclusive mode, and so on).
//
// Returns:
//   Number - number of active infobase sessions.
//
Function InfobaseSessionCount(IncludeConsole = True, IncludeBackgroundJobs = True) Export
	
	IBSessions = GetInfoBaseSessions();
	If IncludeConsole AND IncludeBackgroundJobs Then
		Return IBSessions.Count();
	EndIf;
	
	Result = 0;
	
	For Each IBSession In IBSessions Do
		
		If Not IncludeConsole AND IBSession.ApplicationName = "SrvrConsole"
			Or Not IncludeBackgroundJobs AND IBSession.ApplicationName = "BackgroundJob" Then
			Continue;
		EndIf;
		
		Result = Result + 1;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Determines the number of infobase sessions and checks if there are sessions that cannot be 
// forcibly disabled. Generates error message text.
// 
//
Function BlockingSessionsInformation(MessageText = "") Export
	
	BlockingSessionsInformation = New Structure;
	
	CurrentSessionNumber = InfoBaseSessionNumber();
	InfobaseSessions = GetInfoBaseSessions();
	
	HasBlockingSessions = False;
	If Common.FileInfobase() Then
		ActiveSessionNames = "";
		For Each Session In InfobaseSessions Do
			If Session.SessionNumber <> CurrentSessionNumber
				AND Session.ApplicationName <> "1CV8"
				AND Session.ApplicationName <> "1CV8C"
				AND Session.ApplicationName <> "WebClient" Then
				ActiveSessionNames = ActiveSessionNames + Chars.LF + "??? " + Session;
				HasBlockingSessions = True;
			EndIf;
		EndDo;
	EndIf;
	
	BlockingSessionsInformation.Insert("HasBlockingSessions", HasBlockingSessions);
	BlockingSessionsInformation.Insert("SessionCount", InfobaseSessions.Count());
	
	If HasBlockingSessions Then
		Message = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '?????????????? ???????????????? ???????????? ???????????? ?? ????????????????????,
			|?????????????? ???? ?????????? ???????? ?????????????????? ??????????????????????????:
			|%1
			|%2'; 
			|en = 'There are active sessions for the application that cannot be ended forcefully:
			|
			|%1
			|%2'; 
			|pl = 'S?? aktywne sesje pracy z programem,
			|kt??re nie mog?? by?? zako??czone przymusowo:
			|%1
			|%2';
			|es_ES = 'Hay sesiones activas del uso del programa 
			|que no pueden ser terminadas obligatoriamente:
			|%1
			|%2';
			|es_CO = 'Hay sesiones activas del uso del programa 
			|que no pueden ser terminadas obligatoriamente:
			|%1
			|%2';
			|tr = 'Uygulamada kapat??lmaya zorlanamayacak aktif oturumlar var:
			|
			|%1
			|%2';
			|it = 'Ci sono delle sessioni attive per l''applicazione che non possono essere terminate forzandole:
			|
			|%1
			|%2';
			|de = 'Es gibt aktive Sitzungen mit dem Programm,
			|die nicht gewaltsam beendet werden k??nnen:
			|%1
			|%2'"),
			ActiveSessionNames, MessageText);
		BlockingSessionsInformation.Insert("MessageText", Message);
		
	EndIf;
	
	Return BlockingSessionsInformation;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See SaaSOverridable.OnFillIBParametersTable. 
Procedure OnFillIIBParametersTable(Val ParametersTable) Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		ModuleSaaS.AddConstantToIBParametersTable(ParametersTable, "LockMessageOnConfigurationUpdate");
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddClientParametersOnStart. 
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	LockParameters = CurrentConnectionLockParameters();
	Parameters.Insert("SessionLockParameters", New FixedStructure(AdvancedSessionLockParameters(False, LockParameters)));
	
	If Not LockParameters.ConnectionsLocked
		Or Not Common.DataSeparationEnabled()
		Or Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	// The following code is intended for locked data areas only.
	If InfobaseUpdate.InfobaseUpdateInProgress() 
		AND Users.IsFullUser() Then
		// The application administrator can sign in regardless of the incomplete area update status (and the data area lock).
		// The administrator initiates area update.
		Return; 
	EndIf;
	
	CurrentMode = LockParameters.CurrentDataAreaMode;
	
	If ValueIsFilled(CurrentMode.End) Then
		LockPeriod = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '???? ???????????? ?? %1 ???? %2'; en = 'for period from %1 to %2'; pl = 'za okres od %1 do %2';es_ES = 'para el per??odo desde %1 hasta %2';es_CO = 'para el per??odo desde %1 hasta %2';tr = '%1 ile%2 aras?? bir d??nem i??in';it = 'per il periodo da %1 a %2';de = 'f??r den Zeitraum von %1 bis %2'"), CurrentMode.Begin, CurrentMode.End);
	Else
		LockPeriod = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '?? %1'; en = 'from %1'; pl = 'od %1';es_ES = 'desde %1';es_CO = 'desde %1';tr = 'itibaren%1';it = 'dal %1';de = 'von %1'"), CurrentMode.Begin);
	EndIf;
	If ValueIsFilled(CurrentMode.Message) Then
		LockReason = NStr("ru = '???? ??????????????:'; en = 'for the following reason:'; pl = 'z powodu:';es_ES = 'debido a:';es_CO = 'debido a:';tr = 'nedeniyle:';it = 'per il seguente motivo:';de = 'aufgrund:'") + Chars.LF + CurrentMode.Message;
	Else
		LockReason = NStr("ru = '?????? ???????????????????? ???????????????????????? ??????????'; en = 'for routine maintenance'; pl = 'przeprowadzenia zaplanowanych operacji';es_ES = 'realizar las operaciones programadas';es_CO = 'realizar las operaciones programadas';tr = 'planlanm???? operasyonlar y??r??tmek';it = 'per manutenzione di routine';de = 'zur Durchf??hrung geplanter Operationen'");
	EndIf;
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = '?????????????????????????????? ???????????????????? ?????????????????????? ???????????????????? ???????????? ?????????????????????????? %1 %2.
			|
			|???????????????????? ???????????????? ????????????????????.'; 
			|en = 'Application administrator blocked users %1 %2.
			|
			|The application is temporarily unavailable.'; 
			|pl = 'Administrator aplikacji ustawi?? %1 %2 blokad?? pracy u??ytkownik??w.
			|
			|Aplikacja jest tymczasowo niedost??pna.';
			|es_ES = 'Bloqueo de trabajo de usuarios %1 %2 del conjunto de administradores de la aplicaci??n.
			|
			|Aplicaci??n no se encuentra temporalmente disponible.';
			|es_CO = 'Bloqueo de trabajo de usuarios %1 %2 del conjunto de administradores de la aplicaci??n.
			|
			|Aplicaci??n no se encuentra temporalmente disponible.';
			|tr = 'Uygulama y??neticisi, %1 %2 kullan??c??lar??n ??al????ma kilidini ayarlad??.
			|
			|Uygulama ge??ici olarak kullan??lam??yor.';
			|it = 'L''amministratore dell''applicazione ha bloccato gli utenti %1 %2.
			|
			|L''applicazione ?? temporaneamente non disponibile.';
			|de = 'Anwendungsadministrator setzen %1 %2 Benutzer Arbeitssperre.
			|
			|Die Anwendung ist vor??bergehend nicht verf??gbar.'"), LockPeriod, LockReason);
	Parameters.Insert("DataAreaSessionsLocked", MessageText);
	MessageText = "";
	If Users.IsFullUser() Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '?????????????????????????????? ???????????????????? ?????????????????????? ???????????????????? ???????????? ?????????????????????????? %1 %2.
				|
				|?????????? ?? ?????????????????????????????? ?????????????????????'; 
				|en = 'Application administrator blocked users %1 %2.
				|
				|Sign in to the locked application?'; 
				|pl = 'Administrator aplikacji ustawi?? %1 %2 blokad?? pracy u??ytkownik??w.
				|
				|Czy chcesz wej???? do zablokowanej aplikacji?';
				|es_ES = 'Bloqueo de trabajo de usuarios %1 %2 del conjunto de administradores de la aplicaci??n.
				|
				|??Quiere entrar en la aplicaci??n bloqueada?';
				|es_CO = 'Bloqueo de trabajo de usuarios %1 %2 del conjunto de administradores de la aplicaci??n.
				|
				|??Quiere entrar en la aplicaci??n bloqueada?';
				|tr = 'Uygulama y??neticisi %1 %2 kullan??c??lar??n i?? kilidini ayarlad??. 
				|
				|Kilitli uygulamaya girmek istiyor musunuz?';
				|it = 'L''amministratore dell''applicazione ha bloccato gli utenti %1 %2.
				|
				|Accedere all''applicazione bloccata?';
				|de = 'Anwendungsadministrator setzen %1 %2 Benutzer Arbeitssperre.
				|
				|M??chten Sie in die gesperrte Anwendung einsteigen?'"),
			LockPeriod, LockReason);
	EndIf;
	Parameters.Insert("PromptToAuthorize", MessageText);
	If (Users.IsFullUser() AND Not CurrentMode.Exclusive) 
		Or Users.IsFullUser(, True) Then
		
		Parameters.Insert("CanUnlock", True);
	Else
		Parameters.Insert("CanUnlock", False);
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddClientParameters. 
Procedure OnAddClientParameters(Parameters) Export
	
	Parameters.Insert("SessionLockParameters", New FixedStructure(SessionLockParameters()));
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.9";
	Handler.Procedure = "IBConnections.MoveDataAreasSessionLocksToAuxiliaryData";
	Handler.SharedData = True;
	
EndProcedure

// See ExportImportDataOverridable.OnFillTypesExcludedFromExportImport. 
Procedure OnFillTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.InformationRegisters.DataAreaSessionLocks);
	
EndProcedure

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If Not AccessRight("DataAdministration", Metadata)
		Or ModuleToDoListServer.UserTaskDisabled("SessionsLock") Then
		Return;
	EndIf;
	
	// This procedure is only called when To-do list subsystem is available. Therefore, the subsystem 
	// availability check is redundant.
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.DataProcessors.ApplicationLock.FullName());
	
	LockParameters = SessionLockParameters(False);
	CurrentSessionDate = CurrentSessionDate();
	
	If LockParameters.Use Then
		If CurrentSessionDate < LockParameters.Begin Then
			If LockParameters.End <> Date(1, 1, 1) Then
				Message = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '?????????????????????????? ?? %1 ???? %2'; en = 'Scheduled between %1 and %2'; pl = 'Zaplanowane od %1 do %2';es_ES = 'Programado desde %1 hasta %2';es_CO = 'Programado desde %1 hasta %2';tr = '%1 ile %2 aras?? i??in planland??';it = 'Pianificato tra %1 e %2';de = 'Geplant von %1 bis %2'"),
					Format(LockParameters.Begin, "DLF=DT"), Format(LockParameters.End, "DLF=DT"));
			Else
				Message = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '?????????????????????????? ?? %1'; en = 'Scheduled for %1'; pl = 'Zaplanowane od %1';es_ES = 'Programado desde %1';es_CO = 'Programado desde %1';tr = '%1 itibaren planland??';it = 'Pianificato per %1';de = 'Geplant von %1'"), Format(LockParameters.Begin, "DLF=DT"));
			EndIf;
			Importance = False;
		ElsIf LockParameters.End <> Date(1, 1, 1) AND CurrentSessionDate > LockParameters.End AND LockParameters.Begin <> Date(1, 1, 1) Then
			Importance = False;
			Message = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '???? ?????????????????? (?????????? ???????? %1)'; en = 'Inactive (expired on %1)'; pl = 'Niewa??ny (przeterminowany %1)';es_ES = 'No v??lido (caducado %1)';es_CO = 'No v??lido (caducado %1)';tr = 'Ge??erli de??il (s??resi doldu%1)';it = 'Non attivo (scaduto il %1)';de = 'Nicht g??ltig (abgelaufen %1)'"), Format(LockParameters.End, "DLF=DT"));
		Else
			If LockParameters.End <> Date(1, 1, 1) Then
				Message = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '?? %1 ???? %2'; en = 'from %1 to %2'; pl = 'od %1 do %2';es_ES = 'desde %1 hasta %2';es_CO = 'desde %1 hasta %2';tr = '%1 itibaren %2 kadar';it = 'da %1 a %2';de = 'von %1 bis %2'"),
					Format(LockParameters.Begin, "DLF=DT"), Format(LockParameters.End, "DLF=DT"));
			Else
				Message = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '?? %1'; en = 'from %1'; pl = 'od %1';es_ES = 'desde %1';es_CO = 'desde %1';tr = 'itibaren%1';it = 'dal %1';de = 'von %1'"), 
					Format(LockParameters.Begin, "DLF=DT"));
			EndIf;
			Importance = True;
		EndIf;
	Else
		Message = NStr("ru = '???? ??????????????????'; en = 'Not valid'; pl = 'Nie aktywny';es_ES = 'No v??lido';es_CO = 'No v??lido';tr = 'Ge??erli de??il';it = 'Non valido';de = 'Nicht g??ltig'");
		Importance = False;
	EndIf;

	
	For Each Section In Sections Do
		
		UserTaskID = "SessionsLock" + StrReplace(Section.FullName(), ".", "");
		
		UserTask = ToDoList.Add();
		UserTask.ID  = UserTaskID;
		UserTask.HasUserTasks       = LockParameters.Use;
		UserTask.Presentation  = NStr("ru = '???????????????????? ???????????? ??????????????????????????'; en = 'Application lock'; pl = 'Blokowanie operacji u??ytkownika';es_ES = 'Bloqueo de la operaci??n del usuario';es_CO = 'Bloqueo de la operaci??n del usuario';tr = 'Kullan??c?? operasyon kilitleme';it = 'Blocco applicazione';de = 'Sperrung der Benutzerbedienung'");
		UserTask.Form          = "DataProcessor.ApplicationLock.Form";
		UserTask.Important         = Importance;
		UserTask.Owner       = Section;
		
		UserTask = ToDoList.Add();
		UserTask.ID  = "SessionLockDetails";
		UserTask.HasUserTasks       = LockParameters.Use;
		UserTask.Presentation  = Message;
		UserTask.Owner       = UserTaskID; 
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// INFOBASE UPDATE HANDLERS

// Transfers data from the RemoveDataAreaSessionLocks information register to the 
//  DataAreaSessionLocks information register.
Procedure MoveDataAreasSessionLocksToAuxiliaryData() Export
	
	If Not Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	BeginTransaction();
	
	Try
		
		Lock = New DataLock();
		Lock.Add("InformationRegister.DataAreaSessionLocks");
		Lock.Lock();
		
		QueryText =
			"SELECT
			|	ISNULL(DataAreaSessionLocks.DataAreaAuxiliaryData, DeleteDataAreaSessionLocks.DataArea) AS DataAreaAuxiliaryData,
			|	ISNULL(DataAreaSessionLocks.LockStart, DeleteDataAreaSessionLocks.LockStart) AS LockStart,
			|	ISNULL(DataAreaSessionLocks.LockEnd, DeleteDataAreaSessionLocks.LockEnd) AS LockEnd,
			|	ISNULL(DataAreaSessionLocks.LockMessage, DeleteDataAreaSessionLocks.LockMessage) AS LockMessage,
			|	ISNULL(DataAreaSessionLocks.Exclusive, DeleteDataAreaSessionLocks.Exclusive) AS Exclusive
			|FROM
			|	InformationRegister.DeleteDataAreaSessionLocks AS DeleteDataAreaSessionLocks
			|		LEFT JOIN InformationRegister.DataAreaSessionLocks AS DataAreaSessionLocks
			|		ON DeleteDataAreaSessionLocks.DataArea = DataAreaSessionLocks.DataAreaAuxiliaryData";
		Query = New Query(QueryText);
		
		Set = InformationRegisters.DataAreaSessionLocks.CreateRecordSet();
		Set.Load(Query.Execute().Unload());
		InfobaseUpdate.WriteData(Set);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other.

// Returns session lock message text.
//
// Parameters:
//	Message - String - message for the lock.
//  KeyCode - String - infobase access key code.
//
// Returns:
//   String - lock message.
//
Function GenerateLockMessage(Val Message, Val KeyCode) Export
	
	AdministrationParameters = StandardSubsystemsServer.AdministrationParameters();
	FileModeFlag = False;
	IBPath = IBConnectionsClientServer.InfobasePath(FileModeFlag, AdministrationParameters.ClusterPort);
	InfobasePathString = ?(FileModeFlag = True, "/F", "/S") + IBPath;
	MessageText = "";
	If NOT IsBlankString(Message) Then
		MessageText = Message + Chars.LF + Chars.LF;
	EndIf;
	
	If Common.DataSeparationEnabled() AND Common.SeparatedDataUsageAvailable() Then
		MessageText = MessageText + NStr("ru = '%1
			|?????? ???????????????????? ???????????? ?????????????????????????? ?????????? ?????????????? ???????????????????? ?? ???????????????????? AllowUserAuthorization. ????????????????:
			|http://<??????-?????????? ??????????????>/?C=AllowUserAuthorization.'; 
			|en = '%1
			|To allow user operations, you can open the application with the AllowUserAuthorization parameter. Example:
			|http://<web server address>/?C=AllowUserAuthorization'; 
			|pl = '%1
			|Aby zezwoli?? u??ytkownikom na prac??, mo??na otworzy?? aplikacj?? za pomoc?? parametru AllowUserAuthorization. Example:
			|http://<web server address>/?C=AllowUserAuthorization';
			|es_ES = '%1
			|Para permitir el trabajo de usos, usted puede abrir la aplicaci??n con el par??metro AllowUsersWork. Por
			|ejemplo:??http://<server web address>/?C=AllowUsersWork';
			|es_CO = '%1
			|Para permitir el trabajo de usos, usted puede abrir la aplicaci??n con el par??metro AllowUsersWork. Por
			|ejemplo:??http://<server web address>/?C=AllowUsersWork';
			|tr = '%1
			|Kullan??mlara izin vermek i??in, AllowUserAuthorization parametresiyle uygulamay?? a??abilirsiniz.
			| ??rne??in: http: // <sunucu web adresi> /? C = AllowUserAuthorization';
			|it = '%1
			|Per consentire le operazioni degli utenti, ?? possibile aprire l''applicazione con parametro ConsentireAutorizzazioneUtente. Esempio:
			|http://<web server address>/?C=AllowUserAuthorization';
			|de = '%1
			|Damit Anwendungen verwendet werden k??nnen, k??nnen Sie die Anwendung mit dem Parameter BenutzernErlaubenZuArbeiten ??ffnen. Zum
			|Beispiel: http://<web server address>/?C=BenutzernErlaubenZuArbeiten'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, IBConnectionsClientServer.TextForAdministrator());
	Else
		MessageText = MessageText + NStr("ru = '%1
			|?????? ???????? ?????????? ?????????????????? ???????????? ??????????????????????????, ???????????????????????????? ???????????????? ???????????????? ???????????????? ?????? ?????????????????? ""1??:??????????????????????"" ?? ??????????????????????:
			|ENTERPRISE %2 /CAllowUserOperations/UC%3'; 
			|en = '%1
			|To allow user operations, use the server cluster console or run ""1C: Enterprise"" with parameters:
			|ENTERPRISE %2 /CAllowUserOperations /UC%3'; 
			|pl = '%1
			|Aby zezwoli?? prac?? u??ytkownikom, skorzystaj z konsoli klastra serwer??w lub uruchom ""1C: Enterprise"" z parameterami:
			|ENTERPRISE %2 /CAllowUserOperations /UC%3';
			|es_ES = '%1
			|Para permitir el trabajo de usos, utilizar la consola del cl??ster de servidores, o iniciar la ""1C:Enterprise"" con los par??metros:
			|ENTERPRISE %2/CAllowUserOperations /UCC%3';
			|es_CO = '%1
			|Para permitir el trabajo de usos, utilizar la consola del cl??ster de servidores, o iniciar la ""1C:Enterprise"" con los par??metros:
			|ENTERPRISE %2/CAllowUserOperations /UCC%3';
			|tr = '%1
			|Kullan??c??lar??n ??al????mas??na izin vermek i??in sunucu k??mesi konsolu veya ""1C: Enterprise"" a??a????daki parametrelerle ba??lat??n:
			|ENTERPRISE %2 /  CAllowUserOperations / UC%3';
			|it = '%1
			|Per permettere le operazioni degli utenti, usare la console del cluster del server o eseguire ""1C: Enterprise"" con i parametri:
			|ENTERPRISE %2 /CAllowUserOperations /UC%3';
			|de = '%1
			|Um Benutzern die Arbeit zu erm??glichen, verwenden Sie die Server Cluster-Konsole oder f??hren Sie ""1C:Enterprise"" mit den Parametern:
			|ENTERPRISE %2 /CCAllowUserOperations /UC%3 aus'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, IBConnectionsClientServer.TextForAdministrator(),
			InfobasePathString, NStr("ru = '<?????? ??????????>'; en = '<key code>'; pl = '<kod uprawnienia>';es_ES = '<c??digo del permiso>';es_CO = '<key code>';tr = '<izin kodu>';it = '<codice chiave>';de = 'Schl??sselcode'"));
	EndIf;
	
	Return MessageText;
	
EndFunction

// Returns the flag specifying whether a connection lock is set for a specific date.
//
// Parameters:
//  CurrentMode - SessionsLock - sessions lock.
//  CurrentDate - Date - date to check.
//
// Returns:
//  Boolean - True if set.
//
Function ConnectionsLockedForDate(CurrentMode, CurrentDate)
	
	Return (CurrentMode.Use AND CurrentMode.Begin <= CurrentDate 
		AND (Not ValueIsFilled(CurrentMode.End) Or CurrentDate <= CurrentMode.End));
	
EndFunction

// See the description in the SessionLockParameters function.
//
Function AdvancedSessionLockParameters(Val GetSessionCount, LockParameters)
	
	If LockParameters.IBConnectionLockSetForDate Then
		CurrentMode = LockParameters.CurrentIBMode;
	ElsIf LockParameters.DataAreaConnectionLockSetForDate Then
		CurrentMode = LockParameters.CurrentDataAreaMode;
	ElsIf LockParameters.CurrentIBMode.Use Then
		CurrentMode = LockParameters.CurrentIBMode;
	Else
		CurrentMode = LockParameters.CurrentDataAreaMode;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Result = New Structure;
	Result.Insert("Use", CurrentMode.Use);
	Result.Insert("Begin", CurrentMode.Begin);
	Result.Insert("End", CurrentMode.End);
	Result.Insert("Message", CurrentMode.Message);
	Result.Insert("SessionTerminationTimeout", 15 * 60);
	Result.Insert("SessionCount", ?(GetSessionCount, InfobaseSessionCount(), 0));
	Result.Insert("CurrentSessionDate", LockParameters.CurrentDate);
	Result.Insert("RestartOnCompletion", True);
	
	IBConnectionsOverridable.OnDetermineSessionLockParameters(Result);
	
	Return Result;
	
EndFunction

Function CurrentConnectionLockParameters()
	
	// CurrentSessionDate is not applied, because the lock is set in the server time zone.
	CurrentDate = CurrentDate();
	
	SetPrivilegedMode(True);
	CurrentIBMode = GetSessionsLock();
	CurrentDataAreaMode = GetDataAreaSessionLock();
	SetPrivilegedMode(False);
	
	IBLockedForDate = ConnectionsLockedForDate(CurrentIBMode, CurrentDate);
	AreaLockedAtDate = ConnectionsLockedForDate(CurrentDataAreaMode, CurrentDate);
	ConnectionsLocked = IBLockedForDate Or AreaLockedAtDate;
	
	Parameters = New Structure;
	Parameters.Insert("CurrentDate", CurrentDate);
	Parameters.Insert("CurrentIBMode", CurrentIBMode);
	Parameters.Insert("CurrentDataAreaMode", CurrentDataAreaMode);
	Parameters.Insert("IBConnectionLockSetForDate", IBLockedForDate);
	Parameters.Insert("DataAreaConnectionLockSetForDate", AreaLockedAtDate);
	Parameters.Insert("ConnectionsLocked", ConnectionsLocked);
	
	Return Parameters;
	
EndFunction

#EndRegion
