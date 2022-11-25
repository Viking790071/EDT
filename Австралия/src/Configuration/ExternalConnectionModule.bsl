
#Region EventHandlers

Procedure OnStart()
	
	// Skip initialization if the infobase update is not completed.
	If InfobaseUpdate.InfobaseUpdateRequired() Then
		Return;
	EndIf;
	
	WriteInformation(NStr("en = 'External connection session started.'; ru = 'Начат сеанс внешнего соединения.';pl = 'Rozpoczęto sesję połączenia zewnętrznego.';es_ES = 'Se inició la sesión de conexión externa.';es_CO = 'Se inició la sesión de conexión externa.';tr = 'Harici bağlantı oturumu başladı.';it = 'Sessione di connessione esterna avviata.';de = 'Externe Verbindungssitzung gestartet.'"));
	
EndProcedure

Procedure OnExit()
	
	// Skip processing if the infobase update is not completed.
	If InfobaseUpdate.InfobaseUpdateRequired() Then
		Return;
	EndIf;
	
	WriteInformation(NStr("en = 'External connection session closed.'; ru = 'Завершен сеанс внешнего соединения.';pl = 'Zamknięto sesję połączenia zewnętrznego.';es_ES = 'Se terminó la sesión de conexión externa.';es_CO = 'Se terminó la sesión de conexión externa.';tr = 'Harici bağlantı oturumu kapatıldı.';it = 'Sessione di connessione esterna terminata.';de = 'Externe Verbindungssitzung geschlossen.'"));
	
EndProcedure

#EndRegion

#Region Private

Procedure WriteInformation(Val Text)
	
	WriteLogEvent(NStr("en = 'External connection'; ru = 'Внешнее соединение';pl = 'Połączenie zewnętrzne';es_ES = 'Conexión externa';es_CO = 'Conexión externa';tr = 'Harici bağlantı';it = 'Collegamento esterno';de = 'Externe Verbindung'", CommonClientServer.DefaultLanguageCode()),
		EventLogLevel.Information,,, Text);
	
EndProcedure

#EndRegion
