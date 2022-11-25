#Region Internal

// Returns the full path to the infobase (connection string).
//
// Parameters:
//  FileModeFlag - Boolean - output parameter. Takes the following value.
//                                     True if the current infobase is a file infobase.
//                                     False if the infobase is of client/server type.
//  ServerClusterPort - Number - input parameter. Used if a custom server cluster port is set.
//                                     
//                                     Default value is 0, which means that the default server 
//                                     cluster port is set.
//
// Returns:
//   String   - an infobase connection string.
//
Function InfobasePath(FileModeFlag = Undefined, Val ServerClusterPort = 0) Export
	
	ConnectionString = GetInfobaseConnectionString(ServerClusterPort);
	
	SearchPosition = StrFind(Upper(ConnectionString), "FILE=");
	
	If SearchPosition = 1 Then // A file infobase.
		
		IBPath = Mid(ConnectionString, 6, StrLen(ConnectionString) - 6);
		FileModeFlag = True;
		
	Else
		FileModeFlag = False;
		
		SearchPosition = StrFind(Upper(ConnectionString), "SRVR=");
		
		If NOT (SearchPosition = 1) Then
			Return Undefined;
		EndIf;
		
		SemicolonPosition = StrFind(ConnectionString, ";");
		StartPositionForCopying = 6 + 1;
		EndPositionForCopying = SemicolonPosition - 2;
		
		ServerName = Mid(ConnectionString, StartPositionForCopying, EndPositionForCopying - StartPositionForCopying + 1);
		
		ConnectionString = Mid(ConnectionString, SemicolonPosition + 1);
		
		// server name position
		SearchPosition = StrFind(Upper(ConnectionString), "REF=");
		
		If NOT (SearchPosition = 1) Then
			Return Undefined;
		EndIf;
		
		StartPositionForCopying = 6;
		SemicolonPosition = StrFind(ConnectionString, ";");
		EndPositionForCopying = SemicolonPosition - 2;
		
		IBNameAtServer = Mid(ConnectionString, StartPositionForCopying, EndPositionForCopying - StartPositionForCopying + 1);
		
		IBPath = """" + ServerName + "\" + IBNameAtServer + """";
	EndIf;
	
	Return IBPath;
	
EndFunction

#EndRegion

#Region Private

// Deletes all infobase sessions except the current one.
//
Procedure DeleteAllSessionsExceptCurrent(AdministrationParameters) Export
	
	AllExceptCurrent = New Structure;
	AllExceptCurrent.Insert("Property", "Number");
	AllExceptCurrent.Insert("ComparisonType", ComparisonType.NotEqual);
	AllExceptCurrent.Insert("Value", IBConnectionsServerCall.CurrentSessionNumber());
	
	Filter = New Array;
	Filter.Add(AllExceptCurrent);

	ClusterAdministrationClientServer.DeleteInfobaseSessions(AdministrationParameters,, Filter);
	
EndProcedure

// Gets the infobase connection string if a custom server cluster port is set.
//
// Parameters:
//  ServerClusterPort - Number - non-standard port of a server cluster.
//
// Returns:
//   String   - an infobase connection string.
//
Function GetInfobaseConnectionString(Val ServerClusterPort = 0) Export
	
	Result = InfoBaseConnectionString();
	If FileInfobase() Or (ServerClusterPort = 0) Then
		Return Result;
	EndIf;
	
#If AtClient Then
	If CommonClient.ClientConnectedOverWebServer() Then
		Return Result;
	EndIf;
#EndIf
	
	ConnectionStringSubstrings  = StrSplit(Result, ";");
	ServerName = StringFunctionsClientServer.RemoveDoubleQuotationMarks(Mid(ConnectionStringSubstrings[0], 7));
	IBName = StringFunctionsClientServer.RemoveDoubleQuotationMarks(Mid(ConnectionStringSubstrings[1], 6));
	ClusterPort = ?(StrFind(ServerName, ":") > 0, "", ":" + Format(ServerClusterPort, "NG=0"));
	
	Result = "Srvr=""%1%2"";Ref=""%3"";";
	Result = StringFunctionsClientServer.SubstituteParametersToString(Result, ServerName, ClusterPort, IBName);
	
	Return Result;
	
EndFunction

// Returns a text constant used to generate messages.
// The function is used for localization purposes.
//
// Returns:
//	String - text intended for the administrator.
//
Function TextForAdministrator() Export
	
	Return NStr("ru = 'Для администратора:'; en = 'For administrator:'; pl = 'Dla administratora:';es_ES = 'Para el administrador:';es_CO = 'Para el administrador:';tr = 'Yönetici için:';it = 'Per l''amministratore:';de = 'Für den Administrator:'");
	
EndFunction

// Returns session lock message text intended for a user.
//
// Parameters:
//	 Message - String - full message.
// 
// Returns:
//	String - lock message.
//
Function ExtractLockMessage(Val Message) Export
	
	MarkerIndex = StrFind(Message, TextForAdministrator());
	If MarkerIndex = 0  Then
		Return Message;
	ElsIf MarkerIndex >= 3 Then
		Return Mid(Message, 1, MarkerIndex - 3);
	Else
		Return "";
	EndIf;
		
EndFunction

// Returns a string constant for generating event log messages.
//
// Returns:
//   String - an event description for the event log.
//
Function EventLogEvent() Export
	
	Return NStr("ru = 'Завершение работы пользователей'; en = 'User sessions'; pl = 'Sesje użytkownika';es_ES = 'Sesiones de usuario';es_CO = 'Sesiones de usuario';tr = 'Kullanıcı oturumları';it = 'Sessioni utente';de = 'Benutzersitzungen'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

// Returns the flag specifying whether the infobase is file-based.
//
// Returns:
//	Boolean - True if the infobase is file-based.
//
Function FileInfobase()
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Result = Common.FileInfobase();
#Else
	Result = CommonClient.FileInfobase();
#EndIf
	Return Result;
EndFunction

#EndRegion
