#Region Public

// Opens the form for entering infobase and/or cluster administration parameters.
//
// Parameters:
//	OnCloseNotifyDescription - NotifyDescription - handler that will be called once the 
//	                                                   administration parameters are entered.
//	PromptForIBAdministrationParameters - Boolean - shows whether the infobase administration 
//	                                                   parameters must be entered.
//	PromptForClusterAdministrationParameters - Boolean - shows whether the cluster administration 
//	                                                         parameters must be entered.
//	AdministrationParameters - Structure - administration parameters that were entered earlier.
//                                           See StandardSubsystemsServer.AdministrationParameters. 
//	Title - String - form title that explains the purpose of requesting the administration parameters.
//	CommentLabel - String - description of the action in whose context the administration parameters are requested.
//
Procedure ShowAdministrationParameters(OnCloseNotifyDescription, PromptForIBAdministrationParameters,
	PromptForClusterAdministrationParameters, AdministrationParameters = Undefined,
	Header = "", NoteLabel = "") Export
	
	FormParameters = New Structure;
	FormParameters.Insert("PromptForIBAdministrationParameters", PromptForIBAdministrationParameters);
	FormParameters.Insert("PromptForClusterAdministrationParameters", PromptForClusterAdministrationParameters);
	FormParameters.Insert("AdministrationParameters", AdministrationParameters);
	FormParameters.Insert("Title", Header);
	FormParameters.Insert("NoteLabel", NoteLabel);
	
	OpenForm("CommonForm.ApplicationAdministrationParameters", FormParameters,,,,,OnCloseNotifyDescription);
	
EndProcedure

#EndRegion

#Region Internal

// Attaches the SessionTerminationModeManagement idle handler or.
// The TerminateSessions idle handler depending on the SetConnectionLock parameter.
//
Procedure SetSessionTerminationHandlers(Val SetConnectionLock) Export
	
	SetUserTerminationInProgressFlag(SetConnectionLock);
	If SetConnectionLock Then
		// As the lock is not set yet, a session termination handler was attached for this user during the 
		// authorization.
		// Disabling it now. For this user, a special idle handler
		// called "TerminateSessions" is attached. It takes into account that this user should be 
		// disconnected last.
		
		DetachIdleHandler("SessionTerminationModeManagement");
		AttachIdleHandler("EndUserSessions", 60);
		EndUserSessions();
	Else
		DetachIdleHandler("EndUserSessions");
		AttachIdleHandler("SessionTerminationModeManagement", 60);
	EndIf;
	
EndProcedure

// Terminates the last remaining session of the administrator who initiated user session termination.
//
Procedure TerminateThisSession(OutputQuestion = True) Export
	
	SetUserTerminationInProgressFlag(False);
	DetachIdleHandler("EndUserSessions");
	
	If TerminateAllSessionsExceptCurrent() Then
		Return;
	EndIf;
	
	If Not OutputQuestion Then 
		Exit(False);
		Return;
	EndIf;
	
	Notification = New NotifyDescription("TerminateThisSessionCompletion", ThisObject);
	MessageText = NStr("ru = '???????????? ?????????????????????????? ?? ???????????????????? ??????????????????. ?????????????????? ???????????? ?????????? ?????????????'; en = 'User operation in the application is prohibited. Close this session?'; pl = 'Operacja u??ytkownika w aplikacji jest zabroniona. Zamkn???? t?? sesj???';es_ES = 'Operaci??n de usuario en la aplicaci??n est?? prohibida. ??Cerrar esta sesi??n?';es_CO = 'Operaci??n de usuario en la aplicaci??n est?? prohibida. ??Cerrar esta sesi??n?';tr = 'Uygulamada kullan??c?? i??lemi yasakt??r. Bu oturumu kapatmak istiyor musunuz?';it = 'operazione utente nell''applicazione ?? vietata. Chiudere questa sessione?';de = 'Benutzerbedienung in der Anwendung ist untersagt. Diese Sitzung schlie??en?'");
	Header = NStr("ru = '???????????????????? ???????????? ???????????????? ????????????'; en = 'Terminate current session'; pl = 'Zako??czy?? bie????c?? sesj??';es_ES = 'Finalizar la sesi??n actual';es_CO = 'Finalizar la sesi??n actual';tr = 'Mevcut oturumu sonland??r';it = 'Terminare la sessione corrente';de = 'Beende die aktuelle Sitzung'");
	ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo, 60, DialogReturnCode.Yes, Header, DialogReturnCode.Yes);
	
EndProcedure

// Sets the TerminateAllSessionsExceptCurrent variable to Value.
//
// Parameters:
//   Value - Boolean - value being set.
//
Procedure SetTerminateAllSessionsExceptCurrentFlag(Value) Export
	
	ParameterName = "StandardSubsystems.UserSessionTerminationParameters";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New Structure);
	EndIf;
	
	ApplicationParameters["StandardSubsystems.UserSessionTerminationParameters"].Insert("TerminateAllSessionsExceptCurrent", Value);
	
EndProcedure

// Sets the SessionTerminationInProgress variable to Value.
//
// Parameters:
//   Value - Boolean - value being set.
//
Procedure SetUserTerminationInProgressFlag(Value) Export
	
	ParameterName = "StandardSubsystems.UserSessionTerminationParameters";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New Structure);
	EndIf;
	
	ApplicationParameters["StandardSubsystems.UserSessionTerminationParameters"].Insert("SessionTerminationInProgress", Value);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// The procedure is called when a user works interactively with a data area.
//
// Parameters:
//  LaunchParameters - Array - an array of strings separated with semicolons ";" in the start 
//                     parameter passed to the configuration using the /C command line key.
//  Cancel - Boolean (return value). If True, the OnStart event processing is canceled.
//                     
//
Procedure LaunchParametersOnProcess(StartParameters, Cancel) Export
	
	Cancel = Cancel Or ProcessStartParameters(StartParameters);
	
EndProcedure

// See CommonClientOverridable.BeforeStart. 
Procedure BeforeStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	
	If Not ClientParameters.Property("DataAreaSessionsLocked") Then
		Return;
	EndIf;
	
	Parameters.InteractiveHandler = New NotifyDescription(
		"BeforeStartInteractiveHandler", ThisObject);
	
EndProcedure

// See CommonClientOverridable.AfterStart. 
Procedure AfterStart() Export
	
	RunParameters = StandardSubsystemsClient.ClientParametersOnStart();
	If NOT RunParameters.SeparatedDataUsageAvailable Then
		Return;
	EndIf;
	
	If GetClientConnectionSpeed() <> ClientConnectionSpeed.Normal Then
		Return;
	EndIf;
	
	LockMode = RunParameters.SessionLockParameters;
	CurrentTime = LockMode.CurrentSessionDate;
	If LockMode.Use 
		 AND (NOT ValueIsFilled(LockMode.Begin) OR CurrentTime >= LockMode.Begin) 
		 AND (NOT ValueIsFilled(LockMode.End) OR CurrentTime <= LockMode.End) Then
		// If the user logged on to a locked infobase, they must have used the /UC key.
		// Sessions by these users should not be terminated.
		Return;
	EndIf;
	
	If StrFind(Upper(LaunchParameter), Upper("EndUserSessions")) > 0 Then
		Return;
	EndIf;
	
	AttachIdleHandler("SessionTerminationModeManagement", 60);
	
EndProcedure

// See also CommonClientOverridable.BeforeExit. 
Procedure BeforeExit(Cancel, Warnings) Export
	
	If SessionTerminationInProgress() Then
		WarningParameters = StandardSubsystemsClient.WarningOnExit();
		WarningParameters.HyperlinkText = NStr("ru = '???????????????????? ???????????? ??????????????????????????'; en = 'Application lock'; pl = 'Blokowanie operacji u??ytkownika';es_ES = 'Bloqueo de la operaci??n del usuario';es_CO = 'Bloqueo de la operaci??n del usuario';tr = 'Kullan??c?? operasyon kilitleme';it = 'Blocco applicazione';de = 'Sperrung der Benutzerbedienung'");
		WarningParameters.WarningText = NStr("ru = '???? ???????????????? ???????????? ?????????????????????? ???????????????????? ???????????? ??????????????????????????'; en = 'User session is being closed from the current session'; pl = 'W bie????cej sesji trwa ko??czenie pracy u??ytkownik??w';es_ES = 'De la sesi??n actual se realiza la terminaci??n del trabajo de usuarios';es_CO = 'De la sesi??n actual se realiza la terminaci??n del trabajo de usuarios';tr = 'Ge??erli oturumdan kullan??c?? kapatma i??lemi yap??l??r';it = 'La sessione utente viene chiusa dalla sessione corrente';de = 'Aus der aktuellen Sitzung wird die Benutzersitzung beendet'");
		WarningParameters.OutputSingleWarning = True;
		
		Form = "DataProcessor.ApplicationLock.Form.InfobaseConnectionsLock";
		
		ActionOnClickHyperlink = WarningParameters.ActionOnClickHyperlink;
		ActionOnClickHyperlink.Form = Form;
		ActionOnClickHyperlink.ApplicationWarningForm = Form;
		
		Warnings.Add(WarningParameters);
	EndIf;
	
EndProcedure

// The procedure is called during an unsuccessful attempt to set exclusive mode in a file infobase.
//
// Parameters:
//  Notification - NotifyDescription - describes the object which must be passed control after closing this form.
//
Procedure OnOpenExclusiveModeSetErrorForm(Notification = Undefined, FormParameters = Undefined) Export
	
	OpenForm("DataProcessor.ApplicationLock.Form.ExclusiveModeSettingError", FormParameters,
		, , , , Notification);
	
EndProcedure

// Opens the user activity lock form.
//
Procedure OnOpenUserActivityLockForm(Notification = Undefined, FormParameters = Undefined) Export
	
	OpenForm("DataProcessor.ApplicationLock.Form.InfobaseConnectionsLock", FormParameters,
		, , , , Notification);
	
EndProcedure

// Replaces the default notification with a custom form containing the active user list.
//
// Parameters:
//  FormName - String (return value).
//
Procedure OnDefineActiveUserForm(FormName) Export
	
	FormName = "DataProcessor.ActiveUsers.Form.ActiveUsers";
	
EndProcedure

#EndRegion

#Region Private

///////////////////////////////////////////////////////////////////////////////
// Core subsystem event handlers.

Function SessionTerminationInProgress() Export
	
	UserSessionTerminationParameters = ApplicationParameters["StandardSubsystems.UserSessionTerminationParameters"];
	
	Return TypeOf(UserSessionTerminationParameters) = Type("Structure")
		AND UserSessionTerminationParameters.Property("SessionTerminationInProgress")
		AND UserSessionTerminationParameters.SessionTerminationInProgress;
	
EndFunction

Function TerminateAllSessionsExceptCurrent()
	
	UserSessionTerminationParameters = ApplicationParameters["StandardSubsystems.UserSessionTerminationParameters"];
	
	Return TypeOf(UserSessionTerminationParameters) = Type("Structure")
		AND UserSessionTerminationParameters.Property("TerminateAllSessionsExceptCurrent")
		AND UserSessionTerminationParameters.TerminateAllSessionsExceptCurrent;
	
EndFunction

Function SavedAdministrationParameters() Export
	
	UserSessionTerminationParameters = ApplicationParameters["StandardSubsystems.UserSessionTerminationParameters"];
	AdministrationParameters = Undefined;
	
	If TypeOf(UserSessionTerminationParameters) = Type("Structure")
		AND UserSessionTerminationParameters.Property("AdministrationParameters") Then
		
		AdministrationParameters = UserSessionTerminationParameters.AdministrationParameters;
		
	EndIf;
		
	Return AdministrationParameters;
	
EndFunction

Procedure SaveAdministrationParameters(Value) Export
	
	ParameterName = "StandardSubsystems.UserSessionTerminationParameters";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New Structure);
	EndIf;
	
	ApplicationParameters["StandardSubsystems.UserSessionTerminationParameters"].Insert("AdministrationParameters", Value);

EndProcedure

Procedure FillInClusterAdministrationParameters(StartParameters)
	AdministrationParameters = IBConnectionsServerCall.AdministrationParameters();
	
	ParametersCount = StartParameters.Count();
	If ParametersCount > 1 Then
		AdministrationParameters.ClusterAdministratorName = StartParameters[1];
	EndIf;
	
	If ParametersCount > 2 Then
		AdministrationParameters.ClusterAdministratorPassword = StartParameters[2];
	EndIf;
	SaveAdministrationParameters(AdministrationParameters);
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Notification handlers.

// Suggests to remove the application lock and sign in, or to shut down the application.
Procedure BeforeStartInteractiveHandler(Parameters, Context) Export
	
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	
	QuestionText   = ClientParameters.PromptToAuthorize;
	MessageText = ClientParameters.DataAreaSessionsLocked;
	
	If Not IsBlankString(QuestionText) Then
		Buttons = New ValueList();
		Buttons.Add(DialogReturnCode.Yes, NStr("ru = '??????????'; en = 'Sign in'; pl = 'Wejd??';es_ES = 'Entrar';es_CO = 'Entrar';tr = 'Login';it = 'Accedere';de = 'Anmelden'"));
		If ClientParameters.CanUnlock Then
			Buttons.Add(DialogReturnCode.No, NStr("ru = '?????????? ???????????????????? ?? ??????????'; en = 'Remove lock and sign in'; pl = 'Odblokowa?? i wyj????';es_ES = 'Desbloquear e iniciar la sesi??n';es_CO = 'Desbloquear e iniciar la sesi??n';tr = 'Kilidini a?? ve oturumu a??';it = 'Togliere il blocco e accedere';de = 'Entsperren und anmelden'"));
		EndIf;
		Buttons.Add(DialogReturnCode.Cancel, NStr("ru = '????????????'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = '??ptal et';it = 'Annulla';de = 'Abbrechen'"));
		
		ResponseHandler = New NotifyDescription(
			"AfterAnswerToPromptToAuthorizeOrUnlock", ThisObject, Parameters);
		
		ShowQueryBox(ResponseHandler, QuestionText, Buttons, 15,
			DialogReturnCode.Cancel,, DialogReturnCode.Cancel);
		Return;
	Else
		Parameters.Cancel = True;
		ShowMessageBox(
			StandardSubsystemsClient.NotificationWithoutResult(Parameters.ContinuationHandler),
			MessageText, 15);
	EndIf;
	
EndProcedure

// Continues from the above procedure.
Procedure AfterAnswerToPromptToAuthorizeOrUnlock(Response, Parameters) Export
	
	If Response = DialogReturnCode.Yes Then // Logging on to the locked application.
		
	ElsIf Response = DialogReturnCode.No Then // Removing the application lock and logging on.
		IBConnectionsServerCall.SetDataAreaSessionLock(
			New Structure("Use", False));
	Else
		Parameters.Cancel = True;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

Procedure ShowWarningOnExit(MessageText) Export
	
	ParameterName = "StandardSubsystems.WarningShownBeforeExit";
	If ApplicationParameters[ParameterName] <> True Then
		ShowUserNotification(NStr("ru = '???????????? ?????????????????? ?????????? ??????????????????'; en = 'Application will be closed'; pl = 'Praca programu zostanie zako??czona';es_ES = 'El programa se terminar??';es_CO = 'El programa se terminar??';tr = 'Uygulama kapat??lacak';it = 'L''applicazione sar?? chiusa';de = 'Das Programm wird abgeschlossen sein'"),, MessageText,, 
			UserNotificationStatus.Important);
		ApplicationParameters.Insert(ParameterName, True);
	EndIf;	
	ShowMessageBox(, MessageText, 30);
	
EndProcedure

Procedure AskOnTermination(MessageText) Export
	
	ParameterName = "StandardSubsystems.WarningShownBeforeExit";
	If ApplicationParameters[ParameterName] <> True Then
		ShowUserNotification(NStr("ru = '???????????? ?????????????????? ?????????? ??????????????????'; en = 'Application will be closed'; pl = 'Praca programu zostanie zako??czona';es_ES = 'El programa se terminar??';es_CO = 'El programa se terminar??';tr = 'Uygulama kapat??lacak';it = 'L''applicazione sar?? chiusa';de = 'Das Programm wird abgeschlossen sein'"),, MessageText,, UserNotificationStatus.Important);
		ApplicationParameters.Insert("StandardSubsystems.WarningShownBeforeExit", True);
	EndIf;	
		
	QuestionText = NStr("ru = '%1
		|?????????????????? ?????????????'; 
		|en = '%1
		|Exit?'; 
		|pl = '%1
		|Zako??czy?? prac???';
		|es_ES = '%1
		|??Terminar el trabajo?';
		|es_CO = '%1
		|??Terminar el trabajo?';
		|tr = '%1
		|Uygulama kapat??ls??n m???';
		|it = '%1
		|Uscire?';
		|de = '%1
		|Herunterfahren?'");
	QuestionText = StringFunctionsClientServer.SubstituteParametersToString(QuestionText, MessageText);
	NotifyDescription = New NotifyDescription("AskQuestionOnTerminateCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, 30, DialogReturnCode.Yes);
	
EndProcedure

Procedure AskQuestionOnTerminateCompletion(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		StandardSubsystemsClient.SkipExitConfirmation();
		Exit(True, False);
	EndIf;
	
EndProcedure

Procedure TerminateThisSessionCompletion(Response, Parameters) Export
	
	If Response <> DialogReturnCode.No Then
		StandardSubsystemsClient.SkipExitConfirmation();
		Exit(False);
	EndIf;
	
EndProcedure	

// Processes start parameters related to allowing or terminating infobase connections.
//
// Parameters:
//  LaunchParameterValue - String - main launch parameter.
//  LaunchParameters - Array - additional start parameters separated by semicolons.
//                                       
//
// Returns:
//   Boolean - True if system start must be canceled.
//
Function ProcessStartParameters(Val StartParameters)

	RunParameters = StandardSubsystemsClient.ClientParametersOnStart();
	If NOT RunParameters.SeparatedDataUsageAvailable Then
		Return False;
	EndIf;
	
	// Processing the application start parameters -
	// ProhibitUserAuthorization and AllowUserAuthorization.
	If StartParameters.Find("AllowUserAuthorization") <> Undefined Then
		
		If NOT IBConnectionsServerCall.AllowUserAuthorization() Then
			MessageText = NStr("ru = '???????????????? ?????????????? AllowUserAuthorization ???? ??????????????????. ?????? ???????? ???? ?????????????????????????????????? ???????????????????????????? ????????.'; en = 'Parameter of the AllowUserAuthorization launch is not processed. You are not authorized to administer the infobase.'; pl = 'Parametr uruchamiania AllowUserAuthorization nie zosta?? przetworzony. Nie masz uprawnie?? do administrowania bazy informacyjnej.';es_ES = 'Par??metro de lanzamiento AllowUserAuthorization no se ha procesado. Usted no est?? autorizado a administrar la infobase.';es_CO = 'Par??metro de lanzamiento AllowUserAuthorization no se ha procesado. Usted no est?? autorizado a administrar la infobase.';tr = 'AllowUserAuthorization ba??latma parametresi i??lenmedi. Veritaban??n?? y??netme yetkiniz yok.';it = 'Il parametro di avvio AllowUserAuthorization non ?? stato eseguito. Non sei autorizzato ad amministrare l''infobase.';de = 'Der Parameter des Starts der AllowUserAuthorization wird nicht verarbeitet. Sie sind nicht berechtigt, die Infobase zu verwalten.'");
			ShowMessageBox(,MessageText);
			Return False;
		EndIf;
		
		EventLogClient.AddMessageForEventLog(IBConnectionsClientServer.EventLogEvent(),,
			NStr("ru = '???????????????? ???????????? ?? ???????????????????? ""AllowUserAuthorization"". ???????????? ?????????????????? ?????????? ??????????????????.'; en = 'Launch with parameterAllowUserAuthorization is performed. The application will be closed.'; pl = 'Wykonano uruchomienie z parametremAllowUserAuthorization is performed. Aplikacja zostanie zamkni??ta.';es_ES = 'Iniciado con el par??metro AllowUserAuthorization. La aplicaci??n se cerrar??.';es_CO = 'Iniciado con el par??metro AllowUserAuthorization. La aplicaci??n se cerrar??.';tr = '""AllowUserAuthorization"" parametresi ile ba??lad??. Uygulama kapat??lacak.';it = '?? stato eseguito l''avvio con il parametro AllowUserAuthorization. L''applicazione verr?? chiusa.';de = 'Der Start mit dem Parameter AllowUserAuthorization wird durchgef??hrt. Die Anwendung wird geschlossen.'"), ,True);
		Exit(False);
		Return True;
		
	// The parameter can contain two additional semicolon-separated parts: a name and a password of the 
	// infobase administrator running server cluster connection in client/server mode of the system.
	//  These parameters must be passed if the current user is not an infobase administrator.
	// 
	// For usage examples, see the TerminateSessions() procedure.
	ElsIf StartParameters.Find("EndUserSessions") <> Undefined Then
		
		If NOT IBConnectionsServerCall.SetConnectionLock() Then
			MessageText = NStr("ru = '???????????????? ?????????????? AllowUserAuthorization ???? ??????????????????. ?????? ???????? ???? ?????????????????????????????????? ???????????????????????????? ????????.'; en = 'The AllowUserAuthorization launch parameter is not processed. You are not authorized to administer the infobase.'; pl = 'Parametr uruchomienia AllowUserAuthorization nie zosta?? przetworzony. Nie masz uprawnie?? do administrowania bazy informacyjnej..';es_ES = 'El par??metro de lanzamiento AllowUserAuthorization no se ha procesado. Usted no est?? autorizado a administrar la infobase.';es_CO = 'El par??metro de lanzamiento AllowUserAuthorization no se ha procesado. Usted no est?? autorizado a administrar la infobase.';tr = 'AllowUserAuthorization ba??latma parametresi i??lenmez. Veritaban??n?? y??netme yetkiniz yok.';it = 'Il parametro di avvio AllowUserAuthorization non ?? stato eseguito. Non sei autorizzato ad amministrare l''infobase.';de = 'Der Startparameter AllowUserAuthorization wird nicht verarbeitet. Sie sind nicht berechtigt, die Infobase zu verwalten.'");
			ShowMessageBox(,MessageText);
			Return False;
		EndIf;
		
		// Offset cluster administration parameters in case of startup with a key.
		FillInClusterAdministrationParameters(StartParameters);
		
		AttachIdleHandler("EndUserSessions", 60);
		EndUserSessions();
		Return False; // Proceed with the application start.
		
	EndIf;
	Return False;
	
EndFunction

#EndRegion
