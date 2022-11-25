#Region Private

// Called every 20 minutes, for example, for dynamic control of updates and user account expiration.
// 
//
Procedure StandardPeriodicCheckIdleHandler() Export
	
	StandardSubsystemsClient.OnExecuteStandardDynamicChecks();
	
EndProcedure

// Continues exiting in the mode of interactive interaction with the user after setting Cancel = 
// True.
//
Procedure BeforeExitInteractiveHandlerIdleHandler() Export
	
	StandardSubsystemsClient.StartInteractiveHandlerBeforeExit();
	
EndProcedure

// Continues starting the application in interaction with a user.
Procedure OnStartIdleHandler() Export
	
	StandardSubsystemsClient.OnStart(, False);
	
EndProcedure

// Called when the application is started, opens the information window.
Procedure ShowInformationAfterStart() Export
	ModuleNotificationAtStartupClient = CommonClient.CommonModule("InformationOnStartClient");
	ModuleNotificationAtStartupClient.Show();
EndProcedure

// Called when the application is started, opens the security warning window.
Procedure ShowSecurityWarningAfterStart() Export
	UsersInternalClient.ShowSecurityWarning();
EndProcedure

// Shows users a message about insufficient RAM.
Procedure ShowRAMRecommendation() Export
	StandardSubsystemsClient.NotifyLowMemory();
EndProcedure

// Displays a popup warning message about additional actions that have to be performed before exit 
// the application.
//
Procedure ShowExitWarning() Export
	Warnings = StandardSubsystemsClient.ClientParameter("ExitWarnings");
	Note = NStr("ru = 'и выполнить дополнительные действия'; en = 'and perform additional actions.'; pl = 'i wykonać dodatkowe działania';es_ES = 'y hacer acciones adicionales';es_CO = 'y hacer acciones adicionales';tr = 've ek eylemleri yerine getir';it = 'ed eseguire ulteriori azioni.';de = 'und mache zusätzliche Aktionen'");
	If Warnings.Count() = 1 AND Not IsBlankString(Warnings[0].HyperlinkText) Then
		Note = Warnings[0].HyperlinkText;
	EndIf;
	ShowUserNotification(NStr("ru = 'Нажмите, чтобы завершить работу'; en = 'Click here to exit'; pl = 'Kliknij, aby wyjść';es_ES = 'Hacer clic para salir';es_CO = 'Hacer clic para salir';tr = 'Çıkmak için tıklayın';it = 'Premi qui per uscire';de = 'Klicken Sie, um zu beenden'"), "e1cib/command/CommonCommand.ExitWarnings",
		Note, PictureLib.ExitApplication);
EndProcedure

#EndRegion
