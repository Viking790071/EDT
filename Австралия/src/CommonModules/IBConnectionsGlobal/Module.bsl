#Region Private

// Terminates active sessions if infobase connection lock is set.
// 
//
Procedure SessionTerminationModeManagement() Export

	// Getting the current lock parameter values.
	CurrentMode = IBConnectionsServerCall.SessionLockParameters();
	LockSet = CurrentMode.Use;
	
	If Not LockSet Then
		Return;
	EndIf;
		
	LockBeginTime = CurrentMode.Begin;
	LockEndTime = CurrentMode.End;
	
	// ExitWithConfirmationTimeout and StopTimeout have negative values, that is why "<=" is used when 
	// these parameters are compared with the difference (LockBeginTime - CurrentMoment) as this 
	// difference keeps getting smaller.
	WaitTimeout    = CurrentMode.SessionTerminationTimeout;
	ExitWithConfirmationTimeout = WaitTimeout / 3;
	StopTimeoutSaaS = 60; // One minute before the lock initiation.
	StopTimeout        = 0; // At the moment of lock initiation.
	CurrentMoment             = CurrentMode.CurrentSessionDate;
	
	If LockEndTime <> '00010101' AND CurrentMoment > LockEndTime Then
		Return;
	EndIf;
	
	LockBeginTimeDate  = Format(LockBeginTime, "DLF=DD");
	LockBeginTimeTime = Format(LockBeginTime, "DLF=T");
	
	MessageText = IBConnectionsClientServer.ExtractLockMessage(CurrentMode.Message);
	Template = NStr("ru = 'Рекомендуется завершить текущую работу и сохранить все свои данные. Работа программы будет завершена %1 в %2. 
		|%3'; 
		|en = 'We recommend that you finish the current session and save data. The application will be closed on %1 at %2.
		|%3'; 
		|pl = 'Zaleca się zakończyć bieżącą pracę i zapisać wszystkie dane. Aplikacja zostanie zamknięta %1w %2. 
		|%3';
		|es_ES = 'Se recomienda finalizar el trabajo actual y guardar todos los datos. La aplicación se cerrará %1 en %2. 
		|%3';
		|es_CO = 'Se recomienda finalizar el trabajo actual y guardar todos los datos. La aplicación se cerrará %1 en %2. 
		|%3';
		|tr = 'Mevcut çalışmayı sonlandırmanızı ve tüm verileri kaydetmenizi tavsiye edilir. Uygulama %1 içinde kapatılacak%2.
		|%3';
		|it = 'Si consiglia di terminare la sessione corrente e di salvare tutti i dati. L''applicazione verrà chiusa il %1 alle %2.
		|%3';
		|de = 'Es wird empfohlen, die aktuelle Arbeit zu beenden und alle Daten zu speichern. Die Anwendung wird geschlossen %1 in %2.
		|%3'");
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(Template, LockBeginTimeDate, LockBeginTimeTime, MessageText);
	
	DataSeparationEnabled = StandardSubsystemsClient.ClientRunParameters().DataSeparationEnabled;
	If Not DataSeparationEnabled
		AND (Not ValueIsFilled(LockBeginTime) Or LockBeginTime - CurrentMoment < StopTimeout) Then
		
		StandardSubsystemsClient.SkipExitConfirmation();
		Exit(False, CurrentMode.RestartOnCompletion);
		
	ElsIf DataSeparationEnabled
		AND (Not ValueIsFilled(LockBeginTime) Or LockBeginTime - CurrentMoment < StopTimeoutSaaS) Then
		
		StandardSubsystemsClient.SkipExitConfirmation();
		Exit(False, False);
		
	ElsIf LockBeginTime - CurrentMoment <= ExitWithConfirmationTimeout Then
		
		IBConnectionsClient.AskOnTermination(MessageText);
		
	ElsIf LockBeginTime - CurrentMoment <= WaitTimeout Then
		
		IBConnectionsClient.ShowWarningOnExit(MessageText);
		
	EndIf;
	
EndProcedure

// Terminates active sessions upon timeout, and then terminates the current session.
// 
//
Procedure EndUserSessions() Export

	// Getting the current lock parameter values.
	CurrentMode = IBConnectionsServerCall.SessionLockParameters(True);
	
	LockBeginTime = CurrentMode.Begin;
	CurrentMoment = CurrentMode.CurrentSessionDate;
	
	If CurrentMoment < LockBeginTime Then
		MessageText = NStr("ru = 'Блокировка работы пользователей запланирована на %1.'; en = 'User sessions will be locked at %1.'; pl = 'Blokada operacji użytkowników jest zaplanowana na %1.';es_ES = 'Bloqueo de la operación de usuario está programado para %1.';es_CO = 'Bloqueo de la operación de usuario está programado para %1.';tr = 'Kullanıcı işleminin kilitlenmesi %1 planlandı.';it = 'La sessione utente verrà bloccata alle %1.';de = 'Die Sperre der Benutzeroperation ist geplant auf %1.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, LockBeginTime);
		ShowUserNotification(NStr("ru = 'Завершение работы пользователей'; en = 'User sessions'; pl = 'Sesje użytkownika';es_ES = 'Sesiones de usuario';es_CO = 'Sesiones de usuario';tr = 'Kullanıcı oturumları';it = 'Sessioni utente';de = 'Benutzersitzungen'"), 
			"e1cib/app/DataProcessor.ApplicationLock", 
			MessageText, PictureLib.Information32);
		Return;
	EndIf;
		
	SessionCount = CurrentMode.SessionCount;
	If SessionCount <= 1 Then
		// All users except the current session are disconnected.
		// The session started with the "TerminateSessions" parameter should be terminated last.
		// This termination order is required to update the configuration with a batch file.
		IBConnectionsClient.SetUserTerminationInProgressFlag(False);
		Notify("UserSessionsCompletion", New Structure("Status, SessionCount", "Finish", SessionCount));
		IBConnectionsClient.TerminateThisSession();
		Return;
	EndIf; 
	
	LockSet = CurrentMode.Use;
	If Not LockSet Then
		Return;
	EndIf;
	
	// If the infobase is file-based, some connections cannot be forcibly terminated.
	If StandardSubsystemsClient.ClientParameter("FileInfobase") Then
		Return;
	EndIf;
	
	// Once the session lock is enabled, all user sessions must be terminated. Terminating connections 
	// for users that are still connected.
	DetachIdleHandler("EndUserSessions");
	
	Try
		AdministrationParameters = IBConnectionsClient.SavedAdministrationParameters();
		If CommonClient.ClientConnectedOverWebServer() Then
			IBConnectionsServerCall.DeleteAllSessionsExceptCurrent(AdministrationParameters);
		Else 
			IBConnectionsClientServer.DeleteAllSessionsExceptCurrent(AdministrationParameters);
		EndIf;
		IBConnectionsClient.SaveAdministrationParameters(Undefined);
	Except
		IBConnectionsClient.SetUserTerminationInProgressFlag(False);
			ShowUserNotification(NStr("ru = 'Завершение работы пользователей'; en = 'User sessions'; pl = 'Sesje użytkownika';es_ES = 'Sesiones de usuario';es_CO = 'Sesiones de usuario';tr = 'Kullanıcı oturumları';it = 'Sessioni utente';de = 'Benutzersitzungen'"),
			"e1cib/app/DataProcessor.ApplicationLock", 
			NStr("ru = 'Завершение сеансов не выполнено. Подробности см. в Журнале регистрации.'; en = 'Sessions are not closed. For more information, see the event log.'; pl = 'Zakończenie sesji nie powiodło się. Szczegóły patrz Dzienniku rejestracji.';es_ES = 'Sesiones no se han finalizado. Para más información, ver el Registro de eventos.';es_CO = 'Sesiones no se han finalizado. Para más información, ver el Registro de eventos.';tr = 'Oturumlar tamamlanmadı. Daha fazla bilgi için olay günlüğüne bakın.';it = 'La sessione non è chiusa. Per maggiori informazioni consultare registro eventi.';de = 'Die Sitzungen wurden nicht abgeschlossen. Siehe Ereignisprotokoll für Details.'"), PictureLib.Warning32);
		EventLogClient.AddMessageForEventLog(IBConnectionsClientServer.EventLogEvent(),
			"Error", DetailErrorDescription(ErrorInfo()),, True);
		Notify("UserSessionsCompletion", New Structure("Status,SessionCount", "Error", SessionCount));
		Return;
	EndTry;
	
	IBConnectionsClient.SetUserTerminationInProgressFlag(False);
	ShowUserNotification(NStr("ru = 'Завершение работы пользователей'; en = 'User sessions'; pl = 'Sesje użytkownika';es_ES = 'Sesiones de usuario';es_CO = 'Sesiones de usuario';tr = 'Kullanıcı oturumları';it = 'Sessioni utente';de = 'Benutzersitzungen'"),
		"e1cib/app/DataProcessor.ApplicationLock", 
		NStr("ru = 'Завершение сеансов выполнено успешно'; en = 'User sessions are terminated'; pl = 'Sesje zostały zamknięte pomyślnie';es_ES = 'Sesiones se han cerrado con éxito';es_CO = 'Sesiones se han cerrado con éxito';tr = 'Oturumlar başarıyla kapatıldı';it = 'Le sessioni utente sono state terminate';de = 'Sitzungen werden erfolgreich geschlossen'"), PictureLib.Information32);
	Notify("UserSessionsCompletion", New Structure("Status,SessionCount", "Finish", SessionCount));
	IBConnectionsClient.TerminateThisSession();
	
EndProcedure

#EndRegion
