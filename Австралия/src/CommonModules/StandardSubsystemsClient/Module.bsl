#Region Public

// Sets the application main window caption using the value of the
// ApplicationCaption constant and application caption by default.
//
// Parameters:
//   OnStart - Boolean - True if the procedure is called on the application start.
//
Procedure SetAdvancedApplicationCaption(OnStart = False) Export
	
	ClientParameters = ?(OnStart, ClientParametersOnStart(),
		ClientRunParameters());
		
	If ClientParameters.SeparatedDataUsageAvailable Then
		CaptionPresentation = ClientParameters.ApplicationCaption;
		ConfigurationPresentation = ClientParameters.DetailedInformation;
		
		If IsBlankString(TrimAll(CaptionPresentation)) Then
			If ClientParameters.Property("DataAreaPresentation") Then
				CaptionPattern = "%1 / %2";
				ApplicationCaption = StringFunctionsClientServer.SubstituteParametersToString(CaptionPattern, ClientParameters.DataAreaPresentation,
					ConfigurationPresentation);
			Else
				CaptionPattern = "%1";
				ApplicationCaption = StringFunctionsClientServer.SubstituteParametersToString(CaptionPattern, ConfigurationPresentation);
			EndIf;
		Else
			CaptionPattern = "%1 / %2";
			ApplicationCaption = StringFunctionsClientServer.SubstituteParametersToString(CaptionPattern,
				TrimAll(CaptionPresentation), ConfigurationPresentation);
		EndIf;
	Else
		CaptionPattern = "%1 / %2";
		ApplicationCaption = StringFunctionsClientServer.SubstituteParametersToString(CaptionPattern, NStr("ru = 'Не установлены разделители'; en = 'Separators are not set'; pl = 'Separatory nie są ustawione';es_ES = 'Separadores no establecidos';es_CO = 'Separadores no establecidos';tr = 'Ayırıcılar belirlenmedi';it = 'I separatori non sono impostati';de = 'Trennzeichen sind nicht festgelegt'"), ClientParameters.DetailedInformation);
	EndIf;
	
	If ClientParameters.Property("OperationsWithExternalResourcesLocked")
		AND ClientParameters.Property("DataSeparationEnabled")
		AND Not ClientParameters.DataSeparationEnabled Then
		ApplicationCaption = NStr("ru = '[COPY]'; en = '[COPY]'; pl = '[COPY]';es_ES = '[COPY]';es_CO = '[COPY]';tr = '[COPY]';it = '[COPY]';de = '[COPY]'") + " " + ApplicationCaption;
	EndIf;
	
	CommonClientOverridable.ClientApplicationCaptionOnSet(ApplicationCaption, OnStart);
	
	ClientApplication.SetCaption(ApplicationCaption);
	
EndProcedure

// Show the question form.
//
// Parameters:
//   CompletionNotifyDescription - NotifyDescription - description of the procedures to be called 
//                                                        after the question window is closed with the following parameters:
//                                                          QuestionResult - Structure - a structure with the following properties:
//                                                            Value - a user selection result: a 
//                                                                       system enumeration value or 
//                                                                       a value associated with the clicked button. 
//                                                                       If the dialog is closed by a timeout - value
//                                                                       Timeout.
//                                                            DontAskAgain - Boolean - a user 
//                                                                                                  
//                                                                                                  selection result in the check box with the same name.
//                                                          AdditionalParameters - Structure
//   QuestionText - String - a question text.
//   Buttons - QuestionDialogMode, ValuesList - a values list may be specified in which
//                                       Value - contains the value connected to the button and 
//                                                  returned when the button is selected. You can 
//                                                  pass a value of the DialogReturnCode enumeration 
//                                                  or any value that can be XDTO serialized.
//                                                  
//                                       Presentation - sets the button text.
//
//   AdditionalParameters - Structure - see StandardSubsystemsClient.QuestionToUserParameters 
//
// Returns:
//   The user selection result is passed to the method specified in the NotifyDescriptionOnCompletion parameter.
//
Procedure ShowQuestionToUser(CompletionNotifyDescription, QuestionText, Buttons, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters <> Undefined Then
		Parameters = AdditionalParameters;
	Else
		Parameters = New Structure;
	EndIf;
	
	CommonClientServer.SupplementStructure(Parameters, QuestionToUserParameters(), False);
	
	If TypeOf(Buttons) = Type("QuestionDialogMode") Then
		If      Buttons = QuestionDialogMode.YesNo Then
			ButtonsParameter = "QuestionDialogMode.YesNo";
		ElsIf Buttons = QuestionDialogMode.YesNoCancel Then
			ButtonsParameter = "QuestionDialogMode.YesNoCancel";
		ElsIf Buttons = QuestionDialogMode.OK Then
			ButtonsParameter = "QuestionDialogMode.OK";
		ElsIf Buttons = QuestionDialogMode.OKCancel Then
			ButtonsParameter = "QuestionDialogMode.OKCancel";
		ElsIf Buttons = QuestionDialogMode.RetryCancel Then
			ButtonsParameter = "QuestionDialogMode.RetryCancel";
		ElsIf Buttons = QuestionDialogMode.AbortRetryIgnore Then
			ButtonsParameter = "QuestionDialogMode.AbortRetryIgnore";
		EndIf;
	Else
		ButtonsParameter = Buttons;
	EndIf;
	
	If TypeOf(Parameters.DefaultButton) = Type("DialogReturnCode") Then
		Parameters.DefaultButton = DialogReturnCodeToString(Parameters.DefaultButton);
	EndIf;
	
	If TypeOf(Parameters.TimeoutButton) = Type("DialogReturnCode") Then
		Parameters.TimeoutButton = DialogReturnCodeToString(Parameters.TimeoutButton);
	EndIf;
	
	Parameters.Insert("Buttons",         ButtonsParameter);
	Parameters.Insert("MessageText", QuestionText);
	
	OpenForm("CommonForm.Question", Parameters,,,,,CompletionNotifyDescription);
	
EndProcedure

// Returns a new structure with additional parameters for the ShowQuestionToUser procedure.
//
// Returns:
//  Structure - structure with the following properties:
//    * DefaultButton - Arbitrary - defines the default button by the button type or by the value 
//                                                     associated with it.
//    * Timeout - Number - a period of time in seconds in which the question window waits for user 
//                                                     to respond.
//    * TimeoutButton - Arbitrary - a button (by button type or value associated with it) on which 
//                                                     the timeout remaining seconds are displayed.
//                                                     
//    * Title - String - a question title.
//    * SuggestDontAskAgain - Boolean - True means the same name check box is available in the window.
//    * DontAskAgain - Boolean - a value set by the user in the matching check box.
//                                                     
//    * LockWholeInterface - Boolean - True means the question window is opened locking all other 
//                                                     opened windows include the main one.
//    * Picture - Picture - a picture displayed in the question window.
//
Function QuestionToUserParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("DefaultButton", Undefined);
	Parameters.Insert("Timeout", 0);
	Parameters.Insert("TimeoutButton", Undefined);
	Parameters.Insert("Title", ClientApplication.GetCaption());
	Parameters.Insert("SuggestDontAskAgain", True);
	Parameters.Insert("DoNotAskAgain", False);
	Parameters.Insert("LockWholeInterface", False);
	Parameters.Insert("Picture", PictureLib.Question32);
	Return Parameters;
	
EndFunction	

// Is called if there is a need to open the list of active users to see who is logged on to the 
// system now.
//
// Parameters:
//    FormParameters - Structure - see description of Parameters parameter of OpenForm method in the Syntax Assistant.
//    FormOwner - ClientApplicationForm - see description of parameter Owner, method OpenForm in the Syntax Assistant.
//
Procedure OpenActiveUserList(FormParameters = Undefined, FormOwner = Undefined) Export
	
	If CommonClient.SubsystemExists("StandardSubsystems.UserSessionsCompletion") Then
		
		FormName = "";
		ModuleIBConnectionsClient = CommonClient.CommonModule("IBConnectionsClient");
		ModuleIBConnectionsClient.OnDefineActiveUserForm(FormName);
		OpenForm(FormName, FormParameters, FormOwner);
		
	Else
		
		ShowMessageBox(,
			NStr("ru = 'Для того чтобы открыть список активных пользователей, перейдите в меню
				       |Все функции - Стандартные - Активные пользователи.'; 
				       |en = 'To open the list of active users, on the main menu, click
				       |All functions—Standard—Active users.'; 
				       |pl = 'Aby otworzyć listę aktywnych użytkowników, przejdź do menu
				       |Wszystkie funkcje - Standardowe - Aktywni użytkownicy.';
				       |es_ES = 'Para abrir una lista de usuarios activos, ir al menú
				       |Todas las funciones - Estándares - Usuarios activos.';
				       |es_CO = 'Para abrir una lista de usuarios activos, ir al menú
				       |Todas las funciones - Estándares - Usuarios activos.';
				       |tr = 'Aktif kullanıcıların listesini açmak için, 
				       |Tüm işlevler - Standart - Aktif kullanıcılar menüsüne gidin.';
				       |it = 'Per aprire la lista di utenti attivi, nel menu principale, premere
				       |Tutte le funzioni—Standard—Utenti attivi.';
				       |de = 'Um die Liste der aktiven Benutzer zu öffnen, gehen Sie zum Menü
				       |Alle Funktionen - Standard - Aktive Benutzer.'"));
		
	EndIf;
	
EndProcedure

// Disables the exit confirmation.
//
Procedure SkipExitConfirmation() Export
	
	ApplicationParameters.Insert("StandardSubsystems.SkipExitConfirmation", True);
	
EndProcedure

// Performs the standard actions before the user starts working with a data area or with an infobase 
// in the local mode.
//
// Is intended for calling modules of the managed or ordinary application from the BeforeStart handler.
//
// Parameters:
//  CompletionNotification - NotifyDescription - is skipped if managed or ordinary application 
//                         modules are called from the BeforeStart handler. In other cases, after 
//                         the application started up, the notification with a parameter of the Structure type is called. The structure fields are:
//                         - Cancel - Boolean - False if the application started successfully, True if authorization is not
//                         executed.
//                         - Restart - Boolean - if the aaplication should be restarted.
//                         - AdditionalParametersOfCommandLine - String - for restart.
//
Procedure BeforeStart(Val CompletionNotification = Undefined) Export
	
	StartTime = CurrentUniversalDateInMilliseconds();
	
	If ApplicationParameters = Undefined Then
		ApplicationParameters = New Map;
	EndIf;
	
	ApplicationParameters.Insert("StandardSubsystems.PerformanceMonitor.StartTime", StartTime);
	
	If CompletionNotification <> Undefined Then
		CommonClientServer.CheckParameter("StandardSubsystemsClient.BeforeStart", 
			"CompletionNotification", CompletionNotification, Type("NotifyDescription"));
	EndIf;
	
	SetSessionSeparation();
	
	Parameters = New Structure;
	
	// External parameters of the result description.
	Parameters.Insert("Cancel", False);
	Parameters.Insert("Restart", False);
	Parameters.Insert("AdditionalParametersOfCommandLine", "");
	
	// External parameters of the execution management.
	Parameters.Insert("InteractiveHandler", Undefined); // NotifyDescription.
	Parameters.Insert("ContinuationHandler",   Undefined); // NotifyDescription.
	Parameters.Insert("ContinuousExecution", True);
	Parameters.Insert("RetrievedClientParameters", New Structure);
	
	// Internal parameters.
	Parameters.Insert("CompletionNotification", CompletionNotification);
	Parameters.Insert("CompletionProcessing", New NotifyDescription(
		"ActionsBeforeStartCompletionHandler", ThisObject, Parameters));
	
	UpdateClientParameters(Parameters, True, CompletionNotification <> Undefined);
	
	// Preparing to proceed to the next procedure
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsBeforeStartInIntegrationProcedure", ThisObject, Parameters));
	
	If ApplicationStartupLogicDisabled() Then
		Try
			StandardSubsystemsServerCall.CheckDisableStartupLogicRight();
		Except
			ErrorInformation = ErrorInfo();
			UsersInternalClient.InstallInteractiveDataProcessorOnInsufficientRightsToSignInError(
				Parameters, BriefErrorDescription(ErrorInformation));
		EndTry;
		If BeforeStartInteractiveHandler(Parameters) Then
			Return;
		EndIf;
		HideDesktopOnStart(True, True);
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Performs the standard actions when the user starts working with a data area or with an infobase 
// in the local mode.
//
// Is intended for calling modules of the managed or ordinary application from the OnStart handler.
//
// Parameters:
//  CompletionNotification - NotifyDescription - is skipped if managed or ordinary application 
//                         modules are called from the OnStart handler. In other cases, after the 
//                         application started up, the notification with a parameter of the Structure type is called. The structure fields are:
//                         - Cancel - Boolean - False if the application started successfully, True if authorization is not
//                         executed.
//                         - Restart - Boolean - if the aaplication should be restarted.
//                         - AdditionalParametersOfCommandLine - String - for restart.
//
//  ContinuousExecution - Boolean - for internal use only.
//                          For proceeding from the BeforeStart handler executed in the interactive 
//                          processing mode.
//
Procedure OnStart(Val CompletionNotification = Undefined, ContinuousExecution = True) Export
	
	If InteractiveHandlerBeforeStartInProgress() Then
		Return;
	EndIf;
	
	If ApplicationStartupLogicDisabled() Then
		Return;
	EndIf;
	
	If CompletionNotification <> Undefined Then
		CommonClientServer.CheckParameter("StandardSubsystemsClient.OnStart", 
			"CompletionNotification", CompletionNotification, Type("NotifyDescription"));
	EndIf;
	CommonClientServer.CheckParameter("StandardSubsystemsClient.OnStart", 
		"ContinuousExecution", ContinuousExecution, Type("Boolean"));
	
	Parameters = New Structure;
	
	// External parameters of the result description.
	Parameters.Insert("Cancel", False);
	Parameters.Insert("Restart", False);
	Parameters.Insert("AdditionalParametersOfCommandLine", "");
	
	// External parameters of the execution management.
	Parameters.Insert("InteractiveHandler", Undefined); // NotifyDescription.
	Parameters.Insert("ContinuationHandler",   Undefined); // NotifyDescription.
	Parameters.Insert("ContinuousExecution", ContinuousExecution);
	
	// Internal parameters.
	Parameters.Insert("CompletionNotification", CompletionNotification);
	Parameters.Insert("CompletionProcessing", New NotifyDescription(
		"ActionsOnStartCompletionHandler", ThisObject, Parameters));
	
	// Preparing to proceed to the next procedure
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsOnStartInIntegrationProcedure", ThisObject, Parameters));
	
	Try
		SetAdvancedApplicationCaption(True); // For the main window
		
		If NOT ProcessStartParameters() Then
			Parameters.Cancel = True;
			ExecuteNotifyProcessing(Parameters.CompletionProcessing);
			Return;
		EndIf;
	Except
		HandleErrorOnStart(Parameters, ErrorInfo(), True);
	EndTry;
	If OnStartInteractiveHandler(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Performs the standard actions when the user logs off from a data area or exits the application in 
// the local mode.
//
// Is intended for calling modules of the managed or ordinary application from the BeforeExit handler.
//
// Parameters:
//  Cancel - Boolean - a return value. A flag that shows whether the exit must be canceled, both for 
//                         program or for interactive cases.
//                          In the result of the interaction with the user, the application exit can 
//                         be continued.
//  WarningText - String - see BeforeExit() in the Syntax Assistant. 
//
Procedure BeforeExit(Cancel = False, WarningText = "") Export
	
	If ApplicationStartupLogicDisabled() Then
		Return;
	EndIf;
	
	ApplicationStartParameters = ApplicationParameters["StandardSubsystems.ApplicationRunParameters"];
	
	If ApplicationStartParameters.Property("HideDesktopOnStart") Then
		// The error related to the attempt of closing before the application has started is occurred
	#If WebClient Then
		// In the web client mode such situation can occur in the standard case (the page is closed), that 
		// is why the exit is interrupted, because it can be executed forcibly but if the user closed the 
		// window by accident, they must have an option to stay on the page.
		Cancel = True;
	#Else
		// Not in the web client mode such situation can occur if there are errors in the nonmodal start sequence.
		// That is there is no window that locks the whole interface. The application exit must be continued 
		// but without standard procedures executed before the exit, because they can lead to an exit error 
		// related to the unfinished startup.
	#EndIf
		Return;
	EndIf;
	
	// In thick client (standard application) mode, warning list is not displayed.
#If ThickClientOrdinaryApplication Then
	Return;
#EndIf
	
	If ApplicationParameters["StandardSubsystems.SkipExitConfirmation"] = True Then
		Return;
	EndIf;
	
	If Not ClientParameter("SeparatedDataUsageAvailable") Then
		Return;
	EndIf;
	
	Warnings = New Array;
	SubsystemsIntegrationSSLClient.BeforeExit(Cancel, Warnings);
	CommonClientOverridable.BeforeExit(Cancel, Warnings);
	
	If Warnings.Count() = 0 Then
		If Not ClientParameter("AskConfirmationOnExit") Then
			Return;
		EndIf;
		WarningText = NStr("ru = 'Завершить работу с программой?'; en = 'Do you want to exit the application?'; pl = 'Czy chcesz zamknąć aplikację?';es_ES = '¿Quiere salir de la aplicación?';es_CO = '¿Quiere salir de la aplicación?';tr = 'Uygulamadan çıkmak istiyor musunuz?';it = 'Terminare il lavoro con il programma?';de = 'Möchten Sie die Anwendung beenden?'");
		Cancel = True;
	Else
		Cancel = True;
		WarningArray = New Array;
		For Each Warning In Warnings Do
			WarningArray.Add(Warning.WarningText);
		EndDo;
		If Not IsBlankString(WarningText) Then
			WarningText = WarningText + Chars.LF;
		EndIf;
		WarningText = WarningText + StrConcat(WarningArray, Chars.LF);
		AttachIdleHandler("ShowExitWarning", 0.1, True);
	EndIf;
	SetClientParameter("ExitWarnings", Warnings);
	
EndProcedure

// Returns a structure parameters for showing the warnings before exit the application.
// To use in CommonClientOverridable.BeforeExit.
//
// Returns:
//  Structure - with the following properties:
//    WarningText - String - a text displayed in the window of web browser (or thin client) when closing the application.
//                                    For example, "There are edited files that are not placed to the application".
//                                    Other parameters determine the appearance of the warning form 
//                                    opened after confirmation in the web browser window (or thin client).
//    CheckBoxText - String - if specified, a check box with the specified text is displayed in the warning form.
//                                    For example, "Finish file editing (5)".
//    NoteText - String - a text to be shown on the top of the managed item (check box or hyperlink).
//                                    For example, "Edited files are not placed in the application".
//    HyperlinkText - String - if specified, a hyperlink is displayed with the specified text.
//                                    For example, "Edited files (5)".
//    ExtendedTooltip - String - a text of the tooltip to be shown to the right from the managed 
//                                    item (check box or hyperlink). For example, "Click to go to 
//                                    the list of files opened for editing".
//    Priorities - Number - a relative order in the list of warnings on the form (the greater, the higher).
//    OutputSingleWarning - Boolean - if True, this warning is the only one warning to be shown in 
//                                         the warning list. That is such a warning is incompatible with any other.
//    ActionIfFlagSet - a structure with the following properties:
//      * Form - String - if a user selected the check box, the specified form should be opened.
//                                     For example, "DataProcessor.Files.FilesToEdit".
//      * FormParameters - Structure - an arbitrary structure of parameters to open the form.
//    ActionOnClickHyperlink - a structure with the following properties:
//      * Form - String - a path to the form to be opened when the user clicks the hyperlink.
//                                     For example, "DataProcessor.Files.FilesToEdit".
//      * FormParameters - Structure - an arbitrary structure of parameters for the form to be opened.
//      * ApplicationWarningForm - String - a path to the form to be opened instead of the standard 
//                                        form if the current warning is the only one in the list.
//                                        
//                                        For example, "DataProcessor.Files.FilesToEdit".
//      * ApplicationWarningFormParameters - Structure - an arbitrary structure of parameters for 
//                                                 the form described above.
//      * WindowOpeningMode - FormWindowOpeningMode - a mode of opening the Form or ApplicationWarningForm forms.
// 
Function WarningOnExit() Export
	
	ActionIfFlagSet = New Structure;
	ActionIfFlagSet.Insert("Form", "");
	ActionIfFlagSet.Insert("FormParameters", Undefined);
	
	ActionOnClickHyperlink = New Structure;
	ActionOnClickHyperlink.Insert("Form", "");
	ActionOnClickHyperlink.Insert("FormParameters", Undefined);
	ActionOnClickHyperlink.Insert("ApplicationWarningForm", "");
	ActionOnClickHyperlink.Insert("ApplicationWarningFormParameters", Undefined);
	ActionOnClickHyperlink.Insert("WindowOpeningMode", Undefined);
	
	WarningParameters = New Structure;
	WarningParameters.Insert("CheckBoxText", "");
	WarningParameters.Insert("NoteText", "");
	WarningParameters.Insert("WarningText", "");
	WarningParameters.Insert("ExtendedToolTip", "");
	WarningParameters.Insert("HyperlinkText", "");
	WarningParameters.Insert("ActionIfFlagSet", ActionIfFlagSet);
	WarningParameters.Insert("ActionOnClickHyperlink", ActionOnClickHyperlink);
	WarningParameters.Insert("Priority", 0);
	WarningParameters.Insert("OutputSingleWarning", False);
	
	Return WarningParameters;
	
EndFunction

// Returns the values of parameters required for the operation of the client code when starting 
// configuration for one server call (to minimize client-server interaction and reduce startup time).
// 
// Using this function, you can access parameters in client code called from the event handlers:
// - BeforeStart,
// - OnStart.
//
// In these handlers, when starting the application, do not use cache reset commands of modules that 
// reuse return values because this can lead to unpredictable errors and unneeded server calls.
// 
// 
// Returns:
//   FixedStructure - client parameters at startup.
//                            See at CommonOverridable.OnAddClientParametersOnStart.
//
//
Function ClientParametersOnStart() Export
	
	Return StandardSubsystemsClientCached.ClientParametersOnStart();
	
EndFunction

// Returns parameters values required for the operation of the client code configuration without 
// additional server calls.
// 
// Returns:
//   FixedStructure - client parameters.
//                            See the content of properties at CommonOverridable.OnAddClientParameters.
//
Function ClientRunParameters() Export
	
	Return StandardSubsystemsClientCached.ClientRunParameters();
	
EndFunction

#EndRegion

#Region Internal

Function ApplicationStartCompleted() Export
	
	ParameterName = "StandardSubsystems.ApplicationStartCompleted";
	If ApplicationParameters[ParameterName] = True Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Function ClientParameter(ParameterName = Undefined) Export
	
	GlobalParameterName = "StandardSubsystems.ClientParameters";
	ClientParameters = ApplicationParameters[GlobalParameterName];
	
	If ClientParameters = Undefined Then
		// Filling the permanent parameters of the client.
		StandardSubsystemsClientCached.ClientParametersOnStart();
	EndIf;
	
	If ParameterName = Undefined Then
		Return ClientParameters;
	Else
		Return ClientParameters[ParameterName];
	EndIf;
	
EndFunction

Procedure SetClientParameter(ParameterName, Value) Export
	GlobalParameterName = "StandardSubsystems.ClientParameters";
	ApplicationParameters[GlobalParameterName].Insert(ParameterName, Value);
EndProcedure

Procedure FillClientParameters(ClientParameters) Export
	
	ParameterName = "StandardSubsystems.ClientParameters";
	If TypeOf(ApplicationParameters[ParameterName]) <> Type("Structure") Then
		ApplicationParameters[ParameterName] = New Structure;
		ApplicationParameters[ParameterName].Insert("DataSeparationEnabled");
		ApplicationParameters[ParameterName].Insert("FileInfobase");
		ApplicationParameters[ParameterName].Insert("IsExternalUserSession");
		ApplicationParameters[ParameterName].Insert("AuthorizedUser");
		ApplicationParameters[ParameterName].Insert("AskConfirmationOnExit");
		ApplicationParameters[ParameterName].Insert("SeparatedDataUsageAvailable");
		ApplicationParameters[ParameterName].Insert("StandaloneModeParameters");
		ApplicationParameters[ParameterName].Insert("PersonalFilesOperationsSettings");
		ApplicationParameters[ParameterName].Insert("LockedFilesCount");
		ApplicationParameters[ParameterName].Insert("IBBackupOnExit");
		ApplicationParameters[ParameterName].Insert("ClientDateOffset");
		ApplicationParameters[ParameterName].Insert("DefaultLanguageCode");
		If ClientParameters.Property("PerformanceMonitor") Then
			ApplicationParameters[ParameterName].Insert("PerformanceMonitor");
		EndIf;
	EndIf;
	
	FillPropertyValues(ApplicationParameters[ParameterName], ClientParameters);
	
EndProcedure

// After the warning, calls the procedure with the following parameters: Result, AdditionalParameters.
//
// Parameters:
//  Parameters - a structure containing the properties:
//                          ContinuationHandler - NotifyDescription that contains a procedure with 
//                          two parameters:
//                            Result, AdditionalParameters.
//
//  WarningDetails - undefined - warning is not required.
//  WarningDetails - String - a warning text that should be shown.
//  WarningDetails - Structure - with the following properties:
//       * MessageText - String - a warning text that should be shown.
//       * Buttons - ValuesList - for the ShowQuestionToUser procedure.
//       * QuestionParameters - Structure - contains a subset of the properties to be overridden 
//                                 from among ones that returned by the QuestionToUserParameters 
//                                 function.
//
Procedure ShowMessageBoxAndContinue(Parameters, WarningDetails) Export
	
	NotificationWithResult = Parameters.ContinuationHandler;
	
	If WarningDetails = Undefined Then
		ExecuteNotifyProcessing(NotificationWithResult);
		Return;
	EndIf;
	
	Buttons = New ValueList;
	QuestionParameters = QuestionToUserParameters();
	QuestionParameters.SuggestDontAskAgain = False;
	QuestionParameters.LockWholeInterface = True;
	QuestionParameters.Picture = PictureLib.Warning32;
	
	If Parameters.Cancel Then
		Buttons.Add("ExitApplication", NStr("ru = 'Завершить работу'; en = 'Exit'; pl = 'Zakończ';es_ES = 'Salir';es_CO = 'Salir';tr = 'Çıkış';it = 'Uscita';de = 'Ausgang'"));
		QuestionParameters.DefaultButton = "ExitApplication";
	Else
		Buttons.Add("Continue", NStr("ru = 'Продолжить'; en = 'Continue'; pl = 'Kontynuuj';es_ES = 'Continuar';es_CO = 'Continuar';tr = 'Devam';it = 'Continua';de = 'Weiter'"));
		Buttons.Add("ExitApplication",  NStr("ru = 'Завершить работу'; en = 'Exit'; pl = 'Zakończ';es_ES = 'Salir';es_CO = 'Salir';tr = 'Çıkış';it = 'Uscita';de = 'Ausgang'"));
		QuestionParameters.DefaultButton = "Continue";
	EndIf;
	
	If TypeOf(WarningDetails) = Type("Structure") Then
		WarningText = WarningDetails.WarningText;
		Buttons = WarningDetails.Buttons;
		FillPropertyValues(QuestionParameters, WarningDetails.QuestionParameters);
	Else
		WarningText = WarningDetails;
	EndIf;
	
	ClosingNotification = New NotifyDescription("ShowMessageBoxAndContinueExit", ThisObject, Parameters);
	ShowQuestionToUser(ClosingNotification, WarningText, Buttons, QuestionParameters);
	
EndProcedure

// Shows a file selection dialog and puts the selected files to a temporary storage.
//  This method provides the functionality of both BeginPuttingFiles and PutFiles global context 
//  methods. Its return value is not affected by availability of the file system extension.
//
// Parameters:
//   CompletionHandler - NotifyDescription - description of the procedure that receives the selection result.
//   FormID - UUID - a UUID of the form used to put the files.
//                                                     
//   OriginalFileName - String - a default file name and path in the selection dialog box.
//   DialogParameters - Structure, Undefined - See FileDialog properties in the Syntax Assistant.
//       It is used if the file system extension is available.
//
// Value of the first parameter returned to ResultHandler:
//   FilesThatWerePut - a selection result.
//       * - Undefined - a user canceled the selection.
//       * - Array of TransferredFileDescription, Structure -a user selected a file.
//           ** Name - String - a full name of the selected file.
//           ** Store - String - an address in a storage where file is placed.
//
// Restrictions:
//   This procedure is used only for interactive selection in dialogs.
//   Not used to select catalogs -this option is not supported in the web client mode.
//   Multiple selection in the web client is only supported if the file system extension is available.
//   Putting files to a temporary storage is not supported.
//
Procedure ShowPutFile(CompletionHandler, FormID, OriginalFileName, DialogParameters) Export
	Parameters = New Structure;
	Parameters.Insert("CompletionHandler", CompletionHandler);
	Parameters.Insert("FormID", FormID);
	Parameters.Insert("OriginalFileName", OriginalFileName);
	Parameters.Insert("DialogParameters", DialogParameters);
	
	NotifyDescription = New NotifyDescription("ShowPutFileOnAttachFileSystemExtension", ThisObject, Parameters);
	CommonClient.ShowFileSystemExtensionInstallationQuestion(NotifyDescription);
EndProcedure

// Returns a name of the executable file depending on the client type and the platform version.
//
Function ApplicationExecutableFileName(GetDesignerFile = False) Export
	
	FileNameTemplate = "1cv8[ThinClient][TrainingPlatform].exe";
	
	IsTrainingPlatform = ClientParametersOnStart().IsTrainingPlatform;
	
	#If ThinClient Then
		IsThinClient = Not GetDesignerFile;
	#Else
		IsThinClient = False;
	#EndIf
	
	FileName = StrReplace(FileNameTemplate, "[ThinClient]", ?(IsThinClient, "c", ""));
	FileName = StrReplace(FileName, "[TrainingPlatform]", ?(IsTrainingPlatform, "t", ""));
	
	Return FileName;
	
EndFunction

// Sets or cancels managed form reference storing in a global variable.
// Required when a reference to a form is passed through AdditionalParameters in the 
// NotifyDescription object that does not lock the release of a closed form.
//
Procedure SetFormStorage(Form, Store) Export
	
	Storage = ApplicationParameters["StandardSubsystems.TemporaryManagedFormsRefStorage"];
	If Storage = Undefined Then
		Storage = New Map;
		ApplicationParameters.Insert("StandardSubsystems.TemporaryManagedFormsRefStorage", Storage);
	EndIf;
	
	If Store Then
		Storage.Insert(Form, New Structure("Form", Form));
	ElsIf Storage.Get(Form) <> Undefined Then
		Storage.Delete(Form);
	EndIf;
	
EndProcedure

// Checks that the current data is not defined and not a group.
// Intended for dynamic list form table handlers.
//
// Parameters:
//  TableOrCurrentData - FormTable - a dynamic list form table to check the current data.
//                          - Undefined, FormDataStructure, Structure - current data to be checked.
//
// Returns:
//  Boolean.
//
Function IsDynamicListItem(TableOrCurrentData) Export
	
	If TypeOf(TableOrCurrentData) = Type("FormTable") Then
		CurrentData = TableOrCurrentData.CurrentData;
	Else
		CurrentData = TableOrCurrentData;
	EndIf;
	
	If TypeOf(CurrentData) <> Type("FormDataStructure")
	   AND TypeOf(CurrentData) <> Type("Structure") Then
		Return False;
	EndIf;
	
	If CurrentData.Property("RowGroup") Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Checks whether startup procedures are unsafe disabled for the purposes of automated tests.
Function ApplicationStartupLogicDisabled() Export
	Return StrFind(LaunchParameter, "DisableSystemStartupLogic") > 0;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Spreadsheet document

// Calculates the sum, average, and other indicators for numeric spreadsheet document cells, and 
// then shows the results of the calculation.
// Also see StandardSubsystemsClientServer.CalculateCells.
//
// Parameters:
//   Form - ClientApplicationForm, Undefined - an owner form from which the form is opened.
//   SpreadsheetDocument - SpreadsheetDocument - A table used for calculations.
//   SelectedAreas - Undefined, Array - optional. Document areas to be calculated.
//       If Undefined, calculation will be made by the areas selected interactively.
//       See the return value of the StandardSubsystemsClient.SelectedAreas fucntion.
//
Procedure ShowCellCalculation(Form, SpreadsheetDocument, SelectedAreas = Undefined) Export
	If SelectedAreas = Undefined Then
		SelectedAreas = SelectedAreas(SpreadsheetDocument);
	EndIf;
	FormParameters = New Structure;
	FormParameters.Insert("SpreadsheetDocument", SpreadsheetDocument);
	FormParameters.Insert("SelectedAreas", SelectedAreas);
	WindowMode = FormWindowOpeningMode.LockOwnerWindow;
	OpenForm("CommonForm.SelectedCellsAggregateValues", FormParameters, Form, True, , , , WindowMode);
EndProcedure

// Modifies the notification without result to the notification with result
Function NotificationWithoutResult(NotificationWithResult) Export
	
	Return New NotifyDescription("NotifyWithEmptyResult", ThisObject, NotificationWithResult);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Displaying execution result.

// Expands nodes of the specified tree on the form.
//
// Parameters:
//   Form - ClientApplicationForm - a form where the control item with a value tree.
//   FormItemName - String - a name of the item with a form table (value tree) and the associated 
//                                                  with it form attribute (should match).
//   TreeRowID - Arbitrary - an ID of the tree row to be expanded.
//                                                  If "*" is passed, only top-level nodes are expanded.
//                                                  If Undefined is passed, tree rows are not expanded.
//                                                  By default: "*".
//   ExpandWithSubordinates - Boolean - If True, all subordinate nodes should also be expanded.
//                                                  The default value is False.
//
Procedure ExpandTreeNodes(Form, FormItemName, TreeRowID = "*", ExpandWithSubordinates = False) Export
	
	TableItem = Form.Items[FormItemName];
	If TreeRowID = "*" Then
		Nodes = Form[FormItemName].GetItems();
		For Each Node In Nodes Do
			TableItem.Expand(Node.GetID(), ExpandWithSubordinates);
		EndDo;
	Else
		TableItem.Expand(TreeRowID, ExpandWithSubordinates);
	EndIf;
	
EndProcedure

// Notifies the forms opening and dynamic lists about mass changes in objects of various types, 
// using Notify and NotifyChanged global context methods.
//
// Parameters:
//  ModifiedObjectsTypes - Map - see StandardSubsystemsServer.PrepareFormsChangeNotification 
//  FormNotificationParameter - Arbitrary - a message parameter for the Notify method.
//
Procedure NotifyFormsAboutChange(ModifiedObjectTypes, FormNotificationParameter = Undefined) Export
	
	For Each ObjectType In ModifiedObjectTypes Do
		Notify(ObjectType.Value.EventName, 
			?(FormNotificationParameter <> Undefined, FormNotificationParameter, New Structure), 
			ObjectType.Value.EmptyRef);
		NotifyChanged(ObjectType.Key);
	EndDo;
	
EndProcedure

// Opens the object list form with positioning on the object.
//
// Parameters:
//   Reference - AnyReference - an object to be shown in the list.
//   ListFormName - String - a list form name.
//       If Undefined the transfer will automatically defined requires Server call).
//   FormParameters - Structure - optional. Additional list form opening parameters.
//
Procedure ShowInList(Ref, ListFormName, FormParameters = Undefined) Export
	If Ref = Undefined Then
		Return;
	EndIf;
	
	If ListFormName = Undefined Then
		FullName = StandardSubsystemsServerCall.FullMetadataObjectName(TypeOf(Ref));
		If FullName = Undefined Then
			Return;
		EndIf;
		ListFormName = FullName + ".ListForm";
	EndIf;
	
	If FormParameters = Undefined Then
		FormParameters = New Structure;
	EndIf;
	
	FormParameters.Insert("CurrentRow", Ref);
	
	Form = GetForm(ListFormName, FormParameters, , True);
	Form.Open();
	Form.ExecuteNavigation(Ref);
EndProcedure

// Displays the text, which users can copy.
//
// Parameters:
//   Handler - NotifyDescription - description of the procedure to be called after showing the message.
//       Returns a value like ShowQuestionToUser().
//   Text - String - an information text.
//   Title - String - Optional. window title. "Details" by default.
//
Procedure ShowDetailedInfo(Handler, Text, Header = Undefined) Export
	DialogSettings = New Structure;
	DialogSettings.Insert("SuggestDontAskAgain", False);
	DialogSettings.Insert("Picture", Undefined);
	DialogSettings.Insert("ShowPicture", False);
	DialogSettings.Insert("CanCopy", True);
	DialogSettings.Insert("DefaultButton", 0);
	DialogSettings.Insert("HighlightDefaultButton", False);
	DialogSettings.Insert("Title", Header);
	
	If Not ValueIsFilled(DialogSettings.Title) Then
		DialogSettings.Title = NStr("ru = 'Описание'; en = 'Details'; pl = 'Szczegóły';es_ES = 'Detalles';es_CO = 'Detalles';tr = 'Ayrıntılar';it = 'Dettagli';de = 'Details'");
	EndIf;
	
	Buttons = New ValueList;
	Buttons.Add(0, NStr("ru = 'Закрыть'; en = 'Close'; pl = 'Zamknij';es_ES = 'Cerrar';es_CO = 'Cerrar';tr = 'Kapat';it = 'Chiudi';de = 'Schließen'"));
	
	ShowQuestionToUser(Handler, Text, Buttons, DialogSettings);
EndProcedure

// System applications folder.
// Used only for Windows.
Function SystemApplicationFolder() Export
	
	Shell = New COMObject("Shell.Application");
	
	SystemInfo = New SystemInfo;
	If SystemInfo.PlatformType = PlatformType.Windows_x86 Then 
		// For 32-bit system "C:\Windows\System32".
		// For 64-bit system "C:\Windows\ SysWOW64".
		Folder = Shell.Namespace(41);
		Return Folder.Self.Path + "\";
	ElsIf SystemInfo.PlatformType = PlatformType.Windows_x86_64 Then 
		// For any system "C:\Windows\System32".
		Folder = Shell.Namespace(37);
		Return Folder.Self.Path + "\";
	EndIf;
	
EndFunction

// The file header for technical support.
Function SupportInformation() Export
	
	Text = NStr("ru = 'Название программы: [ApplicationName] 
	                   |Версия программы: [ApplicationVersion]; 
	                   |Версия Платформы 1С:Предприятие: [PlatformVersion] [PlatformBitness]; 
	                   |Версия Библиотеки стандартных подсистем: [SSLVersion];
	                   |Операционная система: [OperatingSystem];
	                   |Размер оперативной памяти: [RAM];
	                   |Имя COM соединителя: [COMConnectorName];
	                   |Базовая: [IsBaseConfigurationVersion]
	                   |Полноправный пользователь: [IsFullUser]
	                   |Учебная: [IsTrainingPlatform]
	                   |Конфигурация изменена: [ConfigurationChanged]'; 
	                   |en = 'Application name: [ApplicationName]
	                   |Application version: [ApplicationVersion]
	                   |1C:Enterprise platform version: [PlatformVersion][PlatformBitness]
	                   |Standard Subsystems Library version: [SSLVersion]
	                   |Operating system: [OperatingSystem]
	                   |RAM: [RAM]
	                   |COM connector: [COMConnectorName]
	                   |Base configuration: [IsBaseConfigurationVersion]
	                   |Full user: [IsFullUser]
	                   |Training platform: [IsTrainingPlatform]
	                   |Configuration changed: [ConfigurationChanged]'; 
	                   |pl = 'Nazwa programu: [ApplicationName] 
	                   | Wersja programu: [ApplicationVersion]; 
	                   | Wersja Platformy 1C:Enterprise: [PlatformVersion] [PlatformBitness]; 
	                   |Wersja Biblioteki standardowych podsystemów: [SSLVersion];
	                   | System operacyjny: [OperatingSystem];
	                   |Rozmiar pamięci ram: [RAM];
	                   |Nazwa COM łącznika: [COMConnectorName];
	                   |Podstawowa: [IsBaseConfigurationVersion]
	                   |Pełnoprawny użytkownik: [IsFullUser]
	                   |Szkoleniowa: [IsTrainingPlatform]
	                   |Konfiguracja zmieniona: [ConfigurationChanged]';
	                   |es_ES = 'Nombre del programa:[ApplicationName]
	                   |Versión del programa: [ApplicationVersion]
	                   |Versión de la Plataforma 1C:Enterprise:[PlatformVersion][PlatformBitness]
	                   |Versión de la Biblioteca de los subsistemas estándares: [SSLVersion]
	                   |Sistema operativo: [OperatingSystem]
	                   |Volumen de memoria operativa:[RAM]
	                   |Nombre del conector COM: [COMConnectorName]
	                   |Básica: [IsBaseConfigurationVersion]
	                   |Usuario con derechos completos: [IsFullUser]
	                   |De estudio: [IsTrainingPlatform]
	                   |Configuración cambiada: [ConfigurationChanged]';
	                   |es_CO = 'Nombre del programa:[ApplicationName]
	                   |Versión del programa: [ApplicationVersion]
	                   |Versión de la Plataforma 1C:Enterprise:[PlatformVersion][PlatformBitness]
	                   |Versión de la Biblioteca de los subsistemas estándares: [SSLVersion]
	                   |Sistema operativo: [OperatingSystem]
	                   |Volumen de memoria operativa:[RAM]
	                   |Nombre del conector COM: [COMConnectorName]
	                   |Básica: [IsBaseConfigurationVersion]
	                   |Usuario con derechos completos: [IsFullUser]
	                   |De estudio: [IsTrainingPlatform]
	                   |Configuración cambiada: [ConfigurationChanged]';
	                   |tr = 'Uygulama adı: [ApplicationName]
	                   |Uygulama sürümü: [ApplicationVersion]
	                   |1C:Enterprise Platform sürümü: [PlatformVersion][PlatformBitness]
	                   |Standart alt sistemler kütüphanesi sürümü: [SSLVersion]
	                   |İşletim sistemi: [OperatingSystem]
	                   |RAM boyutu: [RAM];
	                   |COM bağlayıcının adı: [COMConnectorName]
	                   |Baz: [IsBaseConfigurationVersion]
	                   |Tam kullanıcı: [IsFullUser]
	                   |Eğitim: [IsTrainingPlatform]
	                   |Yapılandırı değişti: [ConfigurationChanged]';
	                   |it = 'Nome del programma: [ApplicationName] 
	                   |Versione del programma: [ApplicationVersion]; 
	                   |Versione della Piattaforma 1C:Enterprise: [PlatformVersion] [PlatformBitness]; 
	                   |Versione Della Biblioteca dei sottosistemi standard: [SSLVersion];
	                   |Sistema operativo: [OperatingSystem];
	                   |Dimensione della memoria operativa: [RAM];
	                   |Nome collegamento COM: [COMConnectorName];
	                   |Di base: [IsBaseConfigurationVersion]
	                   |Utente completo: [IsFullUser]
	                   |Formativa:[IsTrainingPlatform]
	                   |Configurazione modificata: [ConfigurationChanged]';
	                   |de = 'Programmname: [ApplicationName]
	                   |Programmversion: [ApplicationVersion]
	                   |Plattformversion 1C:Enterprise: [PlatformVersion][PlatformBitness]
	                   |Version der Bibliothek der Standard-Subsysteme: [SSLVersion]
	                   |Betriebssystem: [OperatingSystem]
	                   |RAM-Größe: [RAM]
	                   |Name des COM-Anschlusses: [COMConnectorName]
	                   |Grundlegend: [IsBaseConfigurationVersion]
	                   |Vollständiger Benutzer: [IsFullUser]
	                   |Training: [IsTrainingPlatform]
	                   |Konfiguration geändert: [ConfigurationChanged]'") + Chars.LF;
	
	Parameters = ClientRunParameters();
	
	SystemInfo = New SystemInfo;
	
	Text = StrReplace(Text, "[ApplicationName]", Parameters.DetailedInformation);
	Text = StrReplace(Text, "[ApplicationVersion]", Parameters.ConfigurationVersion);
	Text = StrReplace(Text, "[PlatformVersion]", SystemInfo.AppVersion);
	Text = StrReplace(Text, "[PlatformBitness]", SystemInfo.PlatformType);
	Text = StrReplace(Text, "[SSLVersion]", StandardSubsystemsServerCall.LibraryVersion());
	Text = StrReplace(Text, "[OperatingSystem]", SystemInfo.OSVersion);
	Text = StrReplace(Text, "[RAM]", SystemInfo.RAM);
	Text = StrReplace(Text, "[COMConnectorName]", Parameters.COMConnectorName);
	Text = StrReplace(Text, "[IsBaseConfigurationVersion]", Parameters.IsBaseConfigurationVersion);
	Text = StrReplace(Text, "[IsFullUser]", Parameters.IsFullUser);
	Text = StrReplace(Text, "[IsTrainingPlatform]", Parameters.IsTrainingPlatform);
	
	If Parameters.Property("UpdateSettings") Then 
		Text = StrReplace(Text, "[ConfigurationChanged]", Parameters.UpdateSettings.ConfigurationChanged);
	EndIf;
	
	Return Text;
	
EndFunction

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// BeforeStart

// For internal use only. Continues the execution of BeforeStart procedure.
Procedure ActionsBeforeStartInIntegrationProcedure(NotDefined, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsBeforeStartInIntegrationProcedureModules", ThisObject, Parameters));
	
	Parameters.Insert("CurrentModuleIndex", 0);
	Parameters.Insert("AddedModules", New Array);
	Try
		Parameters.Insert("Modules", New Array);
		SubsystemsIntegrationSSLClient.BeforeStart(Parameters);
		Parameters.Insert("AddedModules", Parameters.Modules);
		Parameters.Delete("Modules");
	Except
		HandleErrorBeforeStart(Parameters, ErrorInfo(), True);
	EndTry;
	If BeforeStartInteractiveHandler(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. Continues the execution of BeforeStart procedure.
Procedure ActionsBeforeStartInIntegrationProcedureModules(NotDefined, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	If Parameters.CurrentModuleIndex >= Parameters.AddedModules.Count() Then
		ActionsBeforeStartInOverridableProcedure(Undefined, Parameters);
		Return;
	EndIf;
	
	ModuleDetails = Parameters.AddedModules[Parameters.CurrentModuleIndex];
	Parameters.CurrentModuleIndex = Parameters.CurrentModuleIndex + 1;
	
	Try
		If TypeOf(ModuleDetails) <> Type("Structure") Then
			CurrentModule = ModuleDetails;
			CurrentModule.BeforeStart(Parameters);
		Else
			CurrentModule = ModuleDetails.Module;
			If ModuleDetails.Number = 2 Then
				CurrentModule.BeforeStart2(Parameters);
			ElsIf ModuleDetails.Number = 3 Then
				CurrentModule.BeforeStart3(Parameters);
			ElsIf ModuleDetails.Number = 4 Then
				CurrentModule.BeforeStart4(Parameters);
			ElsIf ModuleDetails.Number = 5 Then
				CurrentModule.BeforeStart5(Parameters);
			EndIf;
		EndIf;
	Except
		HandleErrorBeforeStart(Parameters, ErrorInfo(), True);
	EndTry;
	If BeforeStartInteractiveHandler(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. Continues the execution of BeforeStart procedure.
Procedure ActionsBeforeStartInOverridableProcedure(NotDefined, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsBeforeStartInOverridableProcedureModules", ThisObject, Parameters));
	
	Parameters.InteractiveHandler = Undefined;
	
	Parameters.Insert("CurrentModuleIndex", 0);
	Parameters.Insert("AddedModules", New Array);
	
	ClientParameters = ClientParametersOnStart();
	If ClientParameters.SeparatedDataUsageAvailable Then
		Try
			Parameters.Insert("Modules", New Array);
			CommonClientOverridable.BeforeStart(Parameters);
			Parameters.Insert("AddedModules", Parameters.Modules);
			Parameters.Delete("Modules");
		Except
			HandleErrorBeforeStart(Parameters, ErrorInfo());
		EndTry;
		If BeforeStartInteractiveHandler(Parameters) Then
			Return;
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. Continues the execution of BeforeStart procedure.
Procedure ActionsBeforeStartInOverridableProcedureModules(NotDefined, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	If Parameters.CurrentModuleIndex >= Parameters.AddedModules.Count() Then
		ActionsBeforeStartAfterAllProcedures(Undefined, Parameters);
		Return;
	EndIf;
	
	CurrentModule = Parameters.AddedModules[Parameters.CurrentModuleIndex];
	Parameters.CurrentModuleIndex = Parameters.CurrentModuleIndex + 1;
	
	Try
		CurrentModule.BeforeStart(Parameters);
	Except
		HandleErrorBeforeStart(Parameters, ErrorInfo());
	EndTry;
	If BeforeStartInteractiveHandler(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. Continues the execution of BeforeStart procedure.
Procedure ActionsBeforeStartAfterAllProcedures(NotDefined, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationHandler", Parameters.CompletionProcessing);
	
	Try
		SetInterfaceFunctionalOptionParametersOnStart();
	Except
		HandleErrorBeforeStart(Parameters, ErrorInfo(), True);
	EndTry;
	If BeforeStartInteractiveHandler(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. The BeforeStart procedure completion.
Procedure ActionsBeforeStartCompletionHandler(NotDefined, Parameters) Export
	
	Parameters.ContinuationHandler = Undefined;
	Parameters.CompletionProcessing  = Undefined;
	
	ApplicationStartParameters = ApplicationParameters["StandardSubsystems.ApplicationRunParameters"];
	ApplicationStartParameters.Delete("RetrievedClientParameters");
	ApplicationParameters["StandardSubsystems.ApplicationStartCompleted"] = True;
	
	If Parameters.CompletionNotification <> Undefined Then
		Result = New Structure;
		Result.Insert("Cancel", Parameters.Cancel);
		Result.Insert("Restart", Parameters.Restart);
		Result.Insert("AdditionalParametersOfCommandLine", Parameters.AdditionalParametersOfCommandLine);
		ExecuteNotifyProcessing(Parameters.CompletionNotification, Result);
		Return;
	EndIf;
	
	If Parameters.Cancel Then
		If Parameters.Restart <> True Then
			Terminate();
		ElsIf ValueIsFilled(Parameters.AdditionalParametersOfCommandLine) Then
			Terminate(Parameters.Restart, Parameters.AdditionalParametersOfCommandLine);
		Else
			Terminate(Parameters.Restart);
		EndIf;
		
	ElsIf Not Parameters.ContinuousExecution Then
		If ApplicationStartParameters.Property("ProcessingParameters") Then
			ApplicationStartParameters.Delete("ProcessingParameters");
		EndIf;
		AttachIdleHandler("OnStartIdleHandler", 0.1, True);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// OnStart

// For internal use only. Continues the execution of OnStart procedure.
Procedure ActionsOnStartInIntegrationProcedure(NotDefined, Parameters) Export
	
	If Not ContinueActionsOnStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsOnStartInIntegrationProcedureModules", ThisObject, Parameters));
	
	Parameters.Insert("CurrentModuleIndex", 0);
	Parameters.Insert("AddedModules", New Array);
	Try
		Parameters.Insert("Modules", New Array);
		SubsystemsIntegrationSSLClient.OnStart(Parameters);
		Parameters.Insert("AddedModules", Parameters.Modules);
		Parameters.Delete("Modules");
	Except
		HandleErrorOnStart(Parameters, ErrorInfo());
	EndTry;
	If OnStartInteractiveHandler(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. Continues the execution of OnStart procedure.
Procedure ActionsOnStartInIntegrationProcedureModules(NotDefined, Parameters) Export
	
	If Not ContinueActionsOnStart(Parameters) Then
		Return;
	EndIf;
	
	If Parameters.CurrentModuleIndex >= Parameters.AddedModules.Count() Then
		ActionsOnStartInOverridableProcedure(Undefined, Parameters);
		Return;
	EndIf;
	
	ModuleDetails = Parameters.AddedModules[Parameters.CurrentModuleIndex];
	Parameters.CurrentModuleIndex = Parameters.CurrentModuleIndex + 1;
	
	Try
		If TypeOf(ModuleDetails) <> Type("Structure") Then
			CurrentModule = ModuleDetails;
			CurrentModule.OnStart(Parameters);
		Else
			CurrentModule = ModuleDetails.Module;
			If ModuleDetails.Number = 2 Then
				CurrentModule.OnStart2(Parameters);
			ElsIf ModuleDetails.Number = 3 Then
				CurrentModule.OnStart3(Parameters);
			ElsIf ModuleDetails.Number = 4 Then
				CurrentModule.OnStart4(Parameters);
			EndIf;
		EndIf;
	Except
		HandleErrorOnStart(Parameters, ErrorInfo());
	EndTry;
	If OnStartInteractiveHandler(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. Continues the execution of OnStart procedure.
Procedure ActionsOnStartInOverridableProcedure(NotDefined, Parameters) Export
	
	If Not ContinueActionsOnStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsOnStartInOverridableProcedureModules", ThisObject, Parameters));
	
	Parameters.Insert("CurrentModuleIndex", 0);
	Parameters.Insert("AddedModules", New Array);
	Try
		Parameters.Insert("Modules", New Array);
		CommonClientOverridable.OnStart(Parameters);
		Parameters.Insert("AddedModules", Parameters.Modules);
		Parameters.Delete("Modules");
	Except
		HandleErrorOnStart(Parameters, ErrorInfo());
	EndTry;
	If OnStartInteractiveHandler(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. Continues the execution of OnStart procedure.
Procedure ActionsOnStartInOverridableProcedureModules(NotDefined, Parameters) Export
	
	If Not ContinueActionsOnStart(Parameters) Then
		Return;
	EndIf;
	
	If Parameters.CurrentModuleIndex >= Parameters.AddedModules.Count() Then
		ActionsOnStartAfterAllProcedures(Undefined, Parameters);
		Return;
	EndIf;
	
	CurrentModule = Parameters.AddedModules[Parameters.CurrentModuleIndex];
	Parameters.CurrentModuleIndex = Parameters.CurrentModuleIndex + 1;
	
	Try
		CurrentModule.OnStart(Parameters);
	Except
		HandleErrorOnStart(Parameters, ErrorInfo());
	EndTry;
	If OnStartInteractiveHandler(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. Continues the execution of OnStart procedure.
Procedure ActionsOnStartAfterAllProcedures(NotDefined, Parameters) Export
	
	If Not ContinueActionsOnStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationHandler", Parameters.CompletionProcessing);
	
	Try
		SubsystemsIntegrationSSLClient.AfterStart();
		CommonClientOverridable.AfterStart();
	Except
		HandleErrorOnStart(Parameters, ErrorInfo());
	EndTry;
	If OnStartInteractiveHandler(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. The OnStart procedure completion.
Procedure ActionsOnStartCompletionHandler(NotDefined, Parameters) Export
	
	Parameters.ContinuationHandler = Undefined;
	Parameters.CompletionProcessing  = Undefined;
	
	If NOT Parameters.Cancel Then
		ApplicationStartParameters = ApplicationParameters["StandardSubsystems.ApplicationRunParameters"];
		If ApplicationStartParameters.Property("SkipClearingDesktopHiding") Then
			ApplicationStartParameters.Delete("SkipClearingDesktopHiding");
		EndIf;
		HideDesktopOnStart(False);
	EndIf;
	
	If Parameters.CompletionNotification <> Undefined Then
		
		Result = New Structure;
		Result.Insert("Cancel", Parameters.Cancel);
		Result.Insert("Restart", Parameters.Restart);
		Result.Insert("AdditionalParametersOfCommandLine", Parameters.AdditionalParametersOfCommandLine);
		ExecuteNotifyProcessing(Parameters.CompletionNotification, Result);
		Return;
		
	Else
		If Parameters.Cancel Then
			If Parameters.Restart <> True Then
				Terminate();
				
			ElsIf ValueIsFilled(Parameters.AdditionalParametersOfCommandLine) Then
				Terminate(Parameters.Restart, Parameters.AdditionalParametersOfCommandLine);
			Else
				Terminate(Parameters.Restart);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// Processes the application start parameters.
//
// Returns:
//   Boolean - True if the OnStart procedure execution should be aborted.
//
Function ProcessStartParameters()

	If IsBlankString(LaunchParameter) Then
		Return True;
	EndIf;
	
	// The parameter can be separated with the semicolons symbol (;).
	StartParameters = StrSplit(LaunchParameter, ";", False);
	
	Cancel = False;
	SubsystemsIntegrationSSLClient.LaunchParametersOnProcess(StartParameters, Cancel);
	CommonClientOverridable.LaunchParametersOnProcess(StartParameters, Cancel);
	
	Return Not Cancel;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// BeforeExit

// For internal use only. Continues the execution of BeforeExit procedure.
Procedure ActionsBeforeExit(Parameters) Export
	
	Parameters.Insert("ContinuationHandler", Parameters.CompletionProcessing);
	
	ClientParameters = ClientRunParameters();
	If ClientParameters.SeparatedDataUsageAvailable Then
		Try
			OpenMessageFormOnExit(Parameters);
		Except
			HandleErrorOnStartOrExit(Parameters, ErrorInfo(), "End");
		EndTry;
		If InteractiveHandlerBeforeExit(Parameters) Then
			Return;
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. The BeforeExit procedure completion.
Procedure ActionsBeforeExitCompletionHandler(NotDefined, Parameters) Export
	
	Parameters.ContinuationHandler = Undefined;
	Parameters.CompletionProcessing  = Undefined;
	
	If Not Parameters.Cancel
	   AND Not Parameters.ContinuousExecution Then
		
		ParameterName = "StandardSubsystems.SkipExitConfirmation";
		ApplicationParameters.Insert(ParameterName, True);
		Exit();
	EndIf;
	
EndProcedure

// For internal use only. The BeforeExit procedure completion.
Procedure ActionsBeforeExitAfterErrorProcessing(NotDefined, AdditionalParameters) Export
	
	Parameters = AdditionalParameters.Parameters;
	Parameters.ContinuationHandler = AdditionalParameters.ContinuationHandler;
	
	If Parameters.Cancel Then
		Parameters.Cancel = False;
		ExecuteNotifyProcessing(Parameters.CompletionProcessing);
	Else
		ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions for application start and exit.

// See CommonClientOverridable.BeforeStart. 
Procedure BeforeStart2(Parameters) Export
	
	// Checks whether the current version is equal or higher than the recommended one.
	// If the platform version is later than RecommendedPlatformVersion, showing a warning.
	//  Closing the application if ClientParameters.MustExit = True.
	// 
	
	ClientParameters = ClientParametersOnStart();
	If NOT ClientParameters.Property("ShowDeprecatedPlatformVersion") Then
		Return;
	EndIf;
	
	Parameters.InteractiveHandler = New NotifyDescription(
		"VersionPlatformCheckOnStartInteractiveHandler", ThisObject, Parameters);
	
EndProcedure

// For internal use only. Continues the execution of CheckPlatformVersionOnStart procedure.
Procedure VersionPlatformCheckOnStartInteractiveHandler(Parameters, Context) Export
	
	ClosingNotification = New NotifyDescription("AfterClosingDeprecatedPlatformVersionForm", ThisObject, Parameters);
	If CommonClient.SubsystemExists("OnlineUserSupport.GetApplicationUpdates") Then
		StandardProcessing = True;
		ModuleGetApplicationUpdatesClient = CommonClient.CommonModule("GetApplicationUpdatesClient");
		ModuleGetApplicationUpdatesClient.OnCheckThePlatformVersionOnStart(ClosingNotification, StandardProcessing);
		If Not StandardProcessing Then
			Return;
		EndIf;
	EndIf;
	
	ClientParameters = ClientParametersOnStart();
	
	SystemInfo = New SystemInfo;
	ActualVersion             = SystemInfo.AppVersion;
	Min         = ClientParameters.MinPlatformVersion;
	
	If CommonClientServer.CompareVersions(ActualVersion, Min) < 0 Then
		If ClientParameters.HasAccessForUpdatingPlatformVersion Then
			MessageText =
				NStr("ru = 'Вход в программу невозможен.
				           |Необходимо предварительно обновить версию платформы 1С:Предприятие.'; 
				           |en = 'Cannot start the application.
				           |1C:Enterprise update is required.'; 
				           |pl = 'Nie można uruchomić aplikacji.
				           |Konieczna jest aktualizacja 1C:Enterprise.';
				           |es_ES = 'Es imposible iniciar la sesión en la aplicación.
				           |Es necesario actualizar la versión de la plataforma de la 1C:Empresa previamente.';
				           |es_CO = 'Es imposible iniciar la sesión en la aplicación.
				           |Es necesario actualizar la versión de la plataforma de la 1C:Empresa previamente.';
				           |tr = 'Uygulama başlatılamıyor.
				           |1C:Enterprise''ın güncellenmesi gerekiyor.';
				           |it = 'Non è possibile accedere al programma.
				           |È necessario prima aggiornare la versione della piattaforma 1C:Enterprise.';
				           |de = 'Es ist nicht möglich, die Anwendung einzuloggen.
				           |Es ist notwendig, die Version der 1C:Enterprise-Plattform zuvor zu aktualisieren.'");
		Else
			MessageText =
				NStr("ru = 'Вход в программу невозможен.
				           |Необходимо обратиться к администратору для обновления версии платформы 1С:Предприятие.'; 
				           |en = 'Cannot start the application.
				           |1C:Enterprise update is required. Please contact the administrator.'; 
				           |pl = 'Nie można zalogować się do aplikacji.
				           |Konieczne jest skontaktowanie się z administratorem, aby zaktualizować wersję platformy 1C:Enterprise.';
				           |es_ES = 'Es imposible iniciar la sesión en la aplicación.
				           |Es necesario contactar el administrador para actualizar la versión de la plataforma de la 1C:Empresa.';
				           |es_CO = 'Es imposible iniciar la sesión en la aplicación.
				           |Es necesario contactar el administrador para actualizar la versión de la plataforma de la 1C:Empresa.';
				           |tr = 'Uygulama başlatılamıyor.
				           |1C:Enterprise güncellemesi gerekiyor. Lütfen, yöneticiye başvurun.';
				           |it = 'Non è possibile accedere al programma.
				           |È necessario contattare l''amministratore per aggiornare la versione della piattaforma 1C:Enterprise.';
				           |de = 'Es ist nicht möglich, die Anwendung einzuloggen.
				           |Es ist erforderlich, den Administrator zu kontaktieren, um die Version 1C:Enterprise-Plattform zu aktualisieren.'");
		EndIf;
	Else
		If ClientParameters.HasAccessForUpdatingPlatformVersion Then
			MessageText =
				NStr("ru='Рекомендуется завершить работу программы и обновить версию платформы 1С:Предприятия.
				         |В противном случае некоторые возможности программы будут недоступны или будут работать некорректно.'; 
				         |en = 'It is recommended that you exit the application and update 1C:Enterprise.
				         |Otherwise, some of the application features might malfunction or become unavailable.'; 
				         |pl = 'Zaleca się wyłączenie aplikacji i aktualizację wersji platformy 1C:Enterprise.
				         |Inaczej niektóre możliwości zastosowania będą niedostępne lub zadziałają niepoprawnie.';
				         |es_ES = 'Se recomienda apagar la aplicación y actualizar la versión de la plataforma de la 1C:Empresa.
				         |En caso contrario, algunas posibilidades de la aplicación no se encontrarán disponibles, o trabajarán de forma incorrecta.';
				         |es_CO = 'Se recomienda apagar la aplicación y actualizar la versión de la plataforma de la 1C:Empresa.
				         |En caso contrario, algunas posibilidades de la aplicación no se encontrarán disponibles, o trabajarán de forma incorrecta.';
				         |tr = 'Uygulamadan çıkıp 1C:Enterprise''ı güncellemeniz önerilir.
				         |Aksi takdirde, bazı uygulama özellikleri kullanılamayabilir veya yanlış çalışabilir.';
				         |it = 'Si consiglia di uscire dall''applicazione e di aggiornare 1C:Enterprise.
				         |Altrimenti alcune funzioni dell''applicazione potrebbero non funzionare correttamente o non essere disponibili.';
				         |de = 'Es wird empfohlen, die Anwendung herunterzufahren und die Version 1C:Enterprise-Plattform zu aktualisieren.
				         |Andernfalls sind einige Anwendungsmöglichkeiten nicht verfügbar oder funktionieren nicht korrekt.'");
		Else
			MessageText = 
				NStr("ru='Рекомендуется завершить работу программы и обратиться к администратору для обновления версии платформы 1С:Предприятия.
				         |В противном случае некоторые возможности программы будут недоступны или будут работать некорректно.'; 
				         |en = 'It is recommended that you exit the application and contact your administrator to update 1C:Enterprise.
				         |Otherwise, some of the application features might malfunction or become unavailable.'; 
				         |pl = 'Zaleca się wyłączenie aplikacji i kontakt z administratorem w celu aktualizacji wersji platformy 1C:Enterprise
				         |W przeciwnym wypadku niektóre możliwości aplikacji będą niedostępne lub będą działać niepoprawnie.';
				         |es_ES = 'Se recomienda cerrar la aplicación y contactar el administrador para actualizar la versión de la plataforma de la 1C:Empresa.
				         |En caso contrario, algunas posibilidades de la aplicación no se encontrarán disponibles, o trabajarán de forma incorrecta.';
				         |es_CO = 'Se recomienda cerrar la aplicación y contactar el administrador para actualizar la versión de la plataforma de la 1C:Empresa.
				         |En caso contrario, algunas posibilidades de la aplicación no se encontrarán disponibles, o trabajarán de forma incorrecta.';
				         |tr = 'Uygulamadan çıkmanız ve 1C:Enterprise''ı güncellemesi için yöneticinizle iletişime geçmeniz önerilir.
				         |Aksi takdirde, bazı uygulama özellikleri kullanılamayabilir veya yanlış çalışabilir.';
				         |it = 'Si consiglia di uscire dall''applicazione e di contattare l''amministratore per aggiornare 1C:Enterprise.
				         |Altrimenti alcune funzioni dell''applicazione potrebbero non funzionare correttamente o non essere disponibili.';
				         |de = 'Es wird empfohlen, die Anwendung zu schließen und den Administrator zu kontaktieren, um die Version der 1C:Enterprise-Plattform zu aktualisieren.
				         |Andernfalls sind einige Anwendungen nicht verfügbar oder funktionieren nicht ordnungsgemäß.'");
		EndIf;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("MessageText", MessageText);
	FormParameters.Insert("RecommendedPlatformVersion", ClientParameters.RecommendedPlatformVersion);
	FormParameters.Insert("MinPlatformVersion", ClientParameters.MinPlatformVersion);
	FormParameters.Insert("OpenByScenario", True);
	FormParameters.Insert("SkipExit", True);
	
	Form = OpenForm("DataProcessor.PlatformUpdateRecommended.Form.PlatformUpdateRecommended", FormParameters,
		, , , , ClosingNotification);
	
	If Form = Undefined Then
		AfterClosingDeprecatedPlatformVersionForm("Continue", Parameters);
	EndIf;
	
EndProcedure

// For internal use only. Continues the execution of CheckPlatformVersionOnStart procedure.
Procedure AfterClosingDeprecatedPlatformVersionForm(Result, Parameters) Export
	
	If Result <> "Continue" Then
		Parameters.Cancel = True;
	Else
		Parameters.RetrievedClientParameters.Insert("ShowDeprecatedPlatformVersion");
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// See CommonClientOverridable.BeforeStart. 
Procedure BeforeStart3(Parameters) Export
	
	// Checks whether the master node must be reconnected and starts the reconnection if it is required.
	// 
	
	ClientParameters = ClientParametersOnStart();
	
	If NOT ClientParameters.Property("ReconnectMasterNode") Then
		Return;
	EndIf;
	
	Parameters.InteractiveHandler = New NotifyDescription(
		"MasterNodeReconnectionInteractiveHandler", ThisObject, Parameters);
	
EndProcedure

// For internal use only. Continues the execution of CheckReconnectToMasterNodeRequired procedure.
Procedure MasterNodeReconnectionInteractiveHandler(Parameters, Context) Export
	
	ClientParameters = ClientParametersOnStart();
	
	If ClientParameters.ReconnectMasterNode = False Then
		Parameters.Cancel = True;
		ShowMessageBox(
			NotificationWithoutResult(Parameters.ContinuationHandler),
			NStr("ru = 'Вход в программу временно невозможен до восстановления связи с главным узлом.
			           |Обратитесь к администратору за подробностями.'; 
			           |en = 'Cannot sign in because the connection to the master node is lost.
			           |Please contact the administrator.'; 
			           |pl = 'Logowanie do aplikacji jest tymczasowo niedostępne do przywrócenia połączenia z węzłem głównym.
			           |Skontaktuj się z administratorem, aby uzyskać szczegółowe informacje.';
			           |es_ES = 'Temporalmente no se puede iniciar la sesión en la aplicación antes de restaurar la conexión con el nodo principal.
			           |Contactar el administrador para los detalles.';
			           |es_CO = 'Temporalmente no se puede iniciar la sesión en la aplicación antes de restaurar la conexión con el nodo principal.
			           |Contactar el administrador para los detalles.';
			           |tr = 'Uygulamaya giriş, ana ünite ile bağlantının geri yüklenmesinden önce geçici olarak kullanılamıyor. 
			           |Ayrıntılar için yöneticiyle iletişime geçin.';
			           |it = 'L''accesso al programma è temporaneamente impossibile finché non viene ripristinata la connessione con il nodo principale.
			           |Per ulteriori dettagli contattare l''amministratore.';
			           |de = 'Die Anmeldung bei der Anwendung ist vor der Wiederherstellung der Verbindung mit dem Hauptknoten vorübergehend nicht möglich.
			           |Wenden Sie sich an den Administrator für die Details.'"),
			15);
		Return;
	EndIf;
	
	Form = OpenForm("CommonForm.ReconnectToMasterNode",,,,,,
		New NotifyDescription("ReconnectToMasterNodeAfterCloseForm", ThisObject, Parameters));
	
	If Form = Undefined Then
		ReconnectToMasterNodeAfterCloseForm(New Structure("Cancel", True), Parameters);
	EndIf;
	
EndProcedure

// For internal use only. Continues the execution of CheckReconnectToMasterNodeRequired procedure.
Procedure ReconnectToMasterNodeAfterCloseForm(Result, Parameters) Export
	
	If TypeOf(Result) <> Type("Structure") Then
		Parameters.Cancel = True;
		
	ElsIf Result.Cancel Then
		Parameters.Cancel = True;
	Else
		Parameters.RetrievedClientParameters.Insert("ReconnectMasterNode");
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Hides the desktop when the application starts using flag that prevents form creation on the 
// desktop.
// Makes the desktop visible and updates it when possible if the desktop is hidden.
// 
//
// Parameters:
//  Hide - Boolean. pass False to make desktop visible if it is hidden.
//           
//
//  AlreadyDoneAtServer - Boolean. pass True if the method was already executed in the 
//           StandardSubsystemsServerCall module and it should not be executed again here but only 
//           set the flag showing that desktop is hidden and it will be shown lately.
//           
//
Procedure HideDesktopOnStart(Hide = True, AlreadyDoneAtServer = False) Export
	
	ApplicationStartParameters = ApplicationParameters["StandardSubsystems.ApplicationRunParameters"];
	
	If Hide Then
		If NOT ApplicationStartParameters.Property("HideDesktopOnStart") Then
			ApplicationStartParameters.Insert("HideDesktopOnStart");
			If NOT AlreadyDoneAtServer Then
				StandardSubsystemsServerCall.HideDesktopOnStart();
			EndIf;
			RefreshInterface();
		EndIf;
	Else
		If ApplicationStartParameters.Property("HideDesktopOnStart") Then
			ApplicationStartParameters.Delete("HideDesktopOnStart");
			If NOT AlreadyDoneAtServer Then
				StandardSubsystemsServerCall.HideDesktopOnStart(False);
			EndIf;
			CurrentActiveWindow = ActiveWindow();
			RefreshInterface();
			If CurrentActiveWindow <> Undefined Then
				CurrentActiveWindow.Activate();
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// For internal use only.
Procedure NotifyWithEmptyResult(NotificationWithResult) Export
	
	ExecuteNotifyProcessing(NotificationWithResult);
	
EndProcedure

// For internal use only.
Procedure StartInteractiveHandlerBeforeExit() Export
	
	ApplicationStartParameters = ApplicationParameters["StandardSubsystems.ApplicationRunParameters"];
	If NOT ApplicationStartParameters.Property("ExitProcessingParameters") Then
		Return;
	EndIf;
	
	Parameters = ApplicationStartParameters.ExitProcessingParameters;
	ApplicationStartParameters.Delete("ExitProcessingParameters");
	
	InteractiveHandler = Parameters.InteractiveHandler;
	Parameters.InteractiveHandler = Undefined;
	ExecuteNotifyProcessing(InteractiveHandler, Parameters);
	
EndProcedure

// For internal use only.
Procedure AfterClosingWarningFormOnExit(Result, AdditionalParameters) Export
	
	Parameters = AdditionalParameters.Parameters;
	
	If AdditionalParameters.FormOption = "Question" Then
		
		If Result = Undefined Or Result.Value <> DialogReturnCode.Yes Then
			Parameters.Cancel = True;
		EndIf;
		
	ElsIf AdditionalParameters.FormOption = "StandardForm" Then
	
		If Result = True Or Result = Undefined Then
			Parameters.Cancel = True;
		EndIf;
		
	Else // AppliedForm
		If Result = True Or Result = Undefined Or Result = DialogReturnCode.No Then
			Parameters.Cancel = True;
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// See CommonClientOverridable.AfterStart. 
Procedure AfterStart() Export
	
	If MustShowRAMSizeRecommendations() Then
		AttachIdleHandler("ShowRAMRecommendation", 10, True);
	EndIf;
	
	AttachStandardPeriodicChecksIdleHandler();
	
EndProcedure

// Called from an idle handler every 20 minutes, for example, for controlling dynamic update or user 
// account expiration.
//
Procedure OnExecuteStandardDynamicChecks() Export
	
	Parameters = New Structure;
	
	MonitoringCenterSubsystemExists = False;
	If CommonClient.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		MonitoringCenterSubsystemExists = True;
		ModuleMonitoringCenterClientInternal = CommonClient.CommonModule("MonitoringCenterClientInternal");
		ModuleMonitoringCenterClientInternal.OnExecuteStandardPeriodicChecksAtClient(Parameters);
	EndIf;
	
	StandardSubsystemsServerCall.OnExecuteStandardDinamicChecksAtServer(Parameters);
	
	If MonitoringCenterSubsystemExists Then
		ModuleMonitoringCenterClientInternal.AfterStandardPeriodicChecksAtClient(Parameters);
	EndIf;
	
	Context = New Structure("Parameters", Parameters);
	
	ContinuationHandler = New NotifyDescription(
		"OnExecuteStandardDynamicChecksUsersSubsystem", ThisObject, Context);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ContinuationHandler", ContinuationHandler);
	
	If Not Parameters.DataBaseConfigurationChangedDynamically Then
		ExecuteNotifyProcessing(ContinuationHandler);
		Return;
	EndIf;
	
	MessageText =
		NStr("ru = 'Версия программы обновлена (внесены изменения в конфигурацию информационной базы).
		           |Для дальнейшей работы рекомендуется перезапустить программу.
		           |Перезапустить?'; 
		           |en = 'The application is updated (the infobase configuration is updated).
		           |It is recommended that you restart the application.
		           |Do you want to restart it?'; 
		           |pl = 'Wersja aplikacji została zaktualizowana (zmiany wprowadzono w konfiguracji bazy informacyjnej).
		           |Zaleca się ponowne uruchomienie aplikacji w celu dalszych operacji.
		           |Czy chcesz teraz zrestartować?';
		           |es_ES = 'Versión de la aplicación se ha actualizado (cambios se han hecho para la configuración de la infobase).
		           |Se recomienda reiniciar la aplicación para futuras operaciones.
		           |¿Reiniciar ahora?';
		           |es_CO = 'Versión de la aplicación se ha actualizado (cambios se han hecho para la configuración de la infobase).
		           |Se recomienda reiniciar la aplicación para futuras operaciones.
		           |¿Reiniciar ahora?';
		           |tr = 'Uygulama sürümü güncellendi (veritabanı yapılandırmasında değişiklikler yapıldı). 
		           |Diğer işlemler için uygulamayı tekrar başlatmanız önerilir. 
		           |Şimdi yeniden başlatmak istiyor musunuz?';
		           |it = 'L''applicazione è stata aggiornata (la configurazione è stata aggiornata(.
		           |Si consiglia di riavviare l''applicazione.
		           |Volete riavviarla?';
		           |de = 'Die Anwendungsversion wurde aktualisiert (Änderungen wurden an der Konfiguration der Infobase vorgenommen).
		           |Es wird empfohlen, die Anwendung für weitere Operationen neu zu starten.
		           |Jetzt neu starten?'");
	
	NotifyDescription = New NotifyDescription(
		"OnExecuteStandardDynamicChecksCompletion", ThisObject, AdditionalParameters);
	
	ShowQueryBox(NotifyDescription, MessageText, QuestionDialogMode.YesNo,,, ClientApplication.GetCaption());
	
EndProcedure

// OnExecuteStandardDinamicChecks procedure continuation.
Procedure OnExecuteStandardDynamicChecksCompletion(Response, Context) Export
	
	If Response = DialogReturnCode.Yes Then
		SkipExitConfirmation();
		Exit(True, True);
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Context.ContinuationHandler);
	
EndProcedure

// OnExecuteStandardDinamicChecks procedure continuation.
Procedure OnExecuteStandardDynamicChecksUsersSubsystem(Result, Context) Export

	ContinuationHandler = New NotifyDescription(
		"OnExecuteStandardDynamicChecksUsersSubsystemCompletion", ThisObject, Context);
	
	UsersInternalClient.OnExecuteStandardDynamicChecks(
		Context.Parameters, ContinuationHandler);
	
EndProcedure

// OnExecuteStandardDinamicChecks procedure continuation.
Procedure OnExecuteStandardDynamicChecksUsersSubsystemCompletion(Result, Context) Export
	
	AttachStandardPeriodicChecksIdleHandler();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For the MetadataObjectIDs catalog.

// For internal use only.
Procedure MetadataObjectIDsListFormListValueChoice(Form, Item, Value, StandardProcessing) Export
	
	If Not Form.SelectMetadataObjectsGroups
	   AND Item.CurrentData <> Undefined
	   AND Not Item.CurrentData.DeletionMark
	   AND Not ValueIsFilled(Item.CurrentData.Parent) Then
		
		StandardProcessing = False;
		
		If Item.Representation = TableRepresentation.Tree Then
			If Item.Expanded(Item.CurrentRow) Then
				Item.Collapse(Item.CurrentRow);
			Else
				Item.Expand(Item.CurrentRow);
			EndIf;
			
		ElsIf Item.Representation = TableRepresentation.HierarchicalList Then
			
			If Item.CurrentParent <> Item.CurrentRow Then
				Item.CurrentParent = Item.CurrentRow;
			Else
				CurrentRow = Item.CurrentRow;
				Item.CurrentParent = Undefined;
				Item.CurrentRow = CurrentRow;
			EndIf;
		Else
			ShowMessageBox(,
				NStr("ru = 'Невозможно выбрать группу объектов метаданных.
				           |Выберите объект метаданных.'; 
				           |en = 'Cannot select a group of metadata objects.
				           |Please select a metadata object.'; 
				           |pl = 'Nie ma opcji wyboru grupy obiektów metadanych.
				           |Wybierz obiekt metadanych.';
				           |es_ES = 'No hay opción para seleccionar el grupo de objetos de metadatos.
				           |Eligir el objeto de metadatos.';
				           |es_CO = 'No hay opción para seleccionar el grupo de objetos de metadatos.
				           |Eligir el objeto de metadatos.';
				           |tr = 'Bir meta veri nesnesi grubu seçilemez. 
				           |Meta veri nesnesini seçin.';
				           |it = 'Impossibile selezionare un gruppo di oggetti di metadati.
				           |Selezionate un oggetto di metadati.';
				           |de = 'Es gibt keine Option zum Auswählen der Metadatenobjektgruppe.
				           |Wählen Sie das Metadatenobjekt aus.'"));
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

Procedure AttachStandardPeriodicChecksIdleHandler()
	
	// Standard periodic checks are called once per 20 minutes.
	AttachIdleHandler("StandardPeriodicCheckIdleHandler", 20 * 60, True);
	
EndProcedure

// Returns a string presentation of the DialogReturnCode type.
Function DialogReturnCodeToString(Value)
	
	Result = "DialogReturnCode." + String(Value);
	
	If Value = DialogReturnCode.Yes Then
		Result = "DialogReturnCode.Yes";
	ElsIf Value = DialogReturnCode.No Then
		Result = "DialogReturnCode.No";
	ElsIf Value = DialogReturnCode.OK Then
		Result = "DialogReturnCode.OK";
	ElsIf Value = DialogReturnCode.Cancel Then
		Result = "DialogReturnCode.Cancel";
	ElsIf Value = DialogReturnCode.Retry Then
		Result = "DialogReturnCode.Retry";
	ElsIf Value = DialogReturnCode.Abort Then
		Result = "DialogReturnCode.Abort";
	ElsIf Value = DialogReturnCode.Ignore Then
		Result = "DialogReturnCode.Ignore";
	EndIf;
	
	Return Result;
	
EndFunction

// Set session separation before starting any action in the application.
Procedure SetSessionSeparation()
	
	If IsBlankString(LaunchParameter) Then
		Return;
	EndIf;
	
	StartParameters = StrSplit(LaunchParameter, ";", False);
	StartParameterValue = Upper(StartParameters[0]);
	
	If StartParameterValue <> Upper("SignInToDataArea") Then
		Return;
	EndIf;
	
	If StartParameters.Count() < 2 Then
		Raise
			NStr("ru = 'При указании параметра запуска SignInToDataArea,
			           |дополнительным параметром необходимо указать значение разделителя.'; 
			           |en = 'A separator value is required as an additional parameter
			           |of SignInToDataArea startup option.'; 
			           |pl = 'Po określeniu opcji uruchamiania dodatkowym parametrem
			           | SignInToDataArea należy określiić wartość separatora.';
			           |es_ES = 'Al especificar el parámetro de lanzamiento EnterDataArea,
			           |especificar un valor de separador con un parámetro adicional.';
			           |es_CO = 'Al especificar el parámetro de lanzamiento EnterDataArea,
			           |especificar un valor de separador con un parámetro adicional.';
			           |tr = 'VeriAlanınaGirin 
			           |başlatma parametresini belirtirken, bir ek parametre olarak bir ayırıcı değeri belirtin.';
			           |it = 'Quando si specifica il parametro di avvio EntrareNellAreaDati,
			           |come parametro aggiuntivo è necessario specificare il valore del separatore.';
			           |de = 'Bei der Angabe des Login-Parameters BetretenDesDatenbereichs
			           |ist ein zusätzlicher Parameter erforderlich, um den Wert des Trennzeichens anzugeben.'");
	EndIf;
	
	Try
		SeparatorValue = Number(StartParameters[1]);
	Except
		Raise
			NStr("ru = 'Значением разделителя в параметре SignInToDataArea должно быть число.'; en = 'Only a number can be passed as a separator value in the SignInToDataArea startup option.'; pl = 'Tylko liczba może być przekazana jako wartość separatora w opcji uruchamiania SignInToDataArea.';es_ES = 'El valor del separador en el parámetro LogOnDataArea tiene que ser un número.';es_CO = 'El valor del separador en el parámetro LogOnDataArea tiene que ser un número.';tr = 'SignInToDataArea parametresindeki ayırıcı değeri bir sayı olmalıdır.';it = 'Come valore del padre nel parametro EntrareNellAreaDati deve essere un numero.';de = 'Der Trennwert im Parameterbereich Anmeldedatenbereich muss eine Zahl sein.'");
	EndTry;
	
	StandardSubsystemsServerCall.SetSessionSeparation(True, SeparatorValue);
	
EndProcedure

// Updates the client parameters after interactive data processing on application start.
Procedure UpdateClientParameters(Parameters, InitialCall = False, UpdateCachedValues = True)
	
	If InitialCall Then
		ParameterName = "StandardSubsystems.ApplicationRunParameters";
		If ApplicationParameters[ParameterName] = Undefined Then
			ApplicationParameters.Insert(ParameterName, New Structure);
		EndIf;
		ParameterName = "StandardSubsystems.ApplicationStartCompleted";
		If ApplicationParameters[ParameterName] = Undefined Then
			ApplicationParameters.Insert(ParameterName, False);
		EndIf;
	ElsIf Parameters.CountOfReceivedClientParameters = Parameters.RetrievedClientParameters.Count() Then
		Return;
	EndIf;
	
	Parameters.Insert("CountOfReceivedClientParameters", Parameters.RetrievedClientParameters.Count());
	
	ApplicationParameters["StandardSubsystems.ApplicationRunParameters"].Insert(
		"RetrievedClientParameters", Parameters.RetrievedClientParameters);
	
	If UpdateCachedValues Then
		RefreshReusableValues();
	EndIf;
	
EndProcedure


// Checks the result of the interactive processing. If False, calls the exit handler.
// If a new received client parameter is added, it updates the client operation parameters.
//
// Parameters:
//   Parameters - Structure - see CommonClientOverridable.BeforeStart. 
//
// Returns:
//   Boolean - True if the execution can continue and, accordingly, the notification handler 
//            specified in the CompletionProcessing properties has not been executed.
//
Function ContinueActionsBeforeStart(Parameters)
	
	If Parameters.Cancel Then
		ExecuteNotifyProcessing(Parameters.CompletionProcessing);
		Return False;
	EndIf;
	
	UpdateClientParameters(Parameters);
	
	Return True;
	
EndFunction

// Processes the error found when calling the OnStart event handler.
//
// Parameters:
//   Parameters - Structure - see CommonClientOverridable.OnStart. 
//   ErrorInformation - ErrorInformation - error information.
//   Shutdown - Boolean - if True is set, you will not be able to continue operation in case of startup error.
//
Procedure HandleErrorBeforeStart(Parameters, ErrorInformation, Shutdown = False)
	
	HandleErrorOnStartOrExit(Parameters, ErrorInformation, "Startup", Shutdown);
	
EndProcedure

// Checks the result of the BeforeStart event handler and executes the notification handler.
//
// Parameters:
//   Parameters - Structure - see CommonClientOverridable.BeforeStart. 
//
// Returns:
//   Boolean - True if the notification handler, specified
//            CompletionProcessing CompletionProcessing or planned moving to the execution of the 
//            interactive processing specified in the InteractiveProcessing property, was executed.
//
Function BeforeStartInteractiveHandler(Parameters)
	
	ApplicationStartParameters = ApplicationParameters["StandardSubsystems.ApplicationRunParameters"];
	
	If Parameters.InteractiveHandler = Undefined Then
		If Parameters.Cancel Then
			ExecuteNotifyProcessing(Parameters.CompletionProcessing);
			Return True;
		EndIf;
		Return False;
	EndIf;
	
	UpdateClientParameters(Parameters);
	
	If NOT Parameters.ContinuousExecution Then
		InteractiveHandler = Parameters.InteractiveHandler;
		Parameters.InteractiveHandler = Undefined;
		ExecuteNotifyProcessing(InteractiveHandler, Parameters);
		
	Else
		// Preparing to execute an interactive handler that was requested in BeforeStart. The handler 
		// assumes to hide the desktop and to update the interface before continue when running OnStart for 
		// the first time.
		// 
		ApplicationStartParameters.Insert("ProcessingParameters", Parameters);
		HideDesktopOnStart();
		ApplicationStartParameters.Insert("SkipClearingDesktopHiding");
		
		If Parameters.CompletionNotification = Undefined Then
			// The platform called the BeforeStart procedure as an event handler, before the main 1C:Enterprise 
			// 8 window is opened.
			If Not ApplicationStartupLogicDisabled() Then
				SetInterfaceFunctionalOptionParametersOnStart();
			EndIf;
		Else
			// The BeforeStart procedure was called programmatically, as signing in to the data area, that is 
			// why continuation after the interface update can be implemented only using an idle handler.
			AttachIdleHandler("OnStartIdleHandler", 0.1, True);
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction


// Checks the result of the interactive processing. If False, calls the exit handler.
//
// Parameters:
//   Parameters - Structure - see CommonClientOverridable.OnStart. 
//
// Returns:
//   Boolean - True if the execution can continue and, accordingly, the notification handler 
//            specified in the CompletionProcessing properties has not been executed.
//
Function ContinueActionsOnStart(Parameters)
	
	If Parameters.Cancel Then
		ExecuteNotifyProcessing(Parameters.CompletionProcessing);
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Processes the error found when calling the OnStart event handler.
//
// Parameters:
//   Parameters - Structure - see CommonClientOverridable.OnStart. 
//   ErrorInformation - ErrorInformation - error information.
//   Shutdown - Boolean - if True is set, you will not be able to continue operation in case of startup error.
//
Procedure HandleErrorOnStart(Parameters, ErrorInformation, Shutdown = False)
	
	HandleErrorOnStartOrExit(Parameters, ErrorInformation, "Startup", Shutdown);
	
EndProcedure

// Checks the result of the OnStart event handler and executes the notification handler.
//
// Parameters:
//   Parameters - Structure - see CommonClientOverridable.OnStart. 
//
// Returns:
//   Boolean - True if notification handler, specified in the CompletionProcessing or 
//            InteractiveHandler properties, was executed.
//
Function OnStartInteractiveHandler(Parameters)
	
	If Parameters.InteractiveHandler = Undefined Then
		If Parameters.Cancel Then
			ExecuteNotifyProcessing(Parameters.CompletionProcessing);
			Return True;
		EndIf;
		Return False;
	EndIf;
	
	InteractiveHandler = Parameters.InteractiveHandler;
	
	Parameters.ContinuousExecution = False;
	Parameters.InteractiveHandler = Undefined;
	
	ExecuteNotifyProcessing(InteractiveHandler, Parameters);
	
	Return True;
	
EndFunction

Function InteractiveHandlerBeforeStartInProgress()
	
	ApplicationStartParameters = ApplicationParameters["StandardSubsystems.ApplicationRunParameters"];
	
	If NOT ApplicationStartParameters.Property("ProcessingParameters") Then
		Return False;
	EndIf;
	
	Parameters = ApplicationStartParameters.ProcessingParameters;
	
	If Parameters.InteractiveHandler <> Undefined Then
		Parameters.ContinuousExecution = False;
		InteractiveHandler = Parameters.InteractiveHandler;
		Parameters.InteractiveHandler = Undefined;
		ExecuteNotifyProcessing(InteractiveHandler, Parameters);
		ApplicationStartParameters.Delete("ProcessingParameters");
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Function InteractiveHandlerBeforeExit(Parameters)
	
	If Parameters.InteractiveHandler = Undefined Then
		If Parameters.Cancel Then
			ExecuteNotifyProcessing(Parameters.CompletionProcessing);
			Return True;
		EndIf;
		Return False;
	EndIf;
	
	If Not Parameters.ContinuousExecution Then
		InteractiveHandler = Parameters.InteractiveHandler;
		Parameters.InteractiveHandler = Undefined;
		ExecuteNotifyProcessing(InteractiveHandler, Parameters);
		
	Else
		// Was called from the BeforeStart event handler for preparing the interactive processing through 
		// the idle handler.
		ApplicationParameters["StandardSubsystems.ApplicationRunParameters"].Insert("ExitProcessingParameters", Parameters);
		Parameters.ContinuousExecution = False;
		AttachIdleHandler(
			"BeforeExitInteractiveHandlerIdleHandler", 0.1, True);
	EndIf;
	
	Return True;
	
EndFunction

// Displays a user message form or a message.
Procedure OpenMessageFormOnExit(Parameters)
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Parameters", Parameters);
	AdditionalParameters.Insert("FormOption", "Question");
	
	ResponseHandler = New NotifyDescription("AfterClosingWarningFormOnExit",
		ThisObject, AdditionalParameters);
		
	Warnings = Parameters.Warnings;
	Parameters.Delete("Warnings");
	
	FormParameters = New Structure;
	FormParameters.Insert("Warnings", Warnings);
	
	FormName = "CommonForm.ExitWarnings";
	
	If Warnings.Count() = 1 Then
		If Not IsBlankString(Warnings[0].CheckBoxText) Then 
			AdditionalParameters.Insert("FormOption", "StandardForm");
			FormOpenParameters = New Structure;
			FormOpenParameters.Insert("FormName", FormName);
			FormOpenParameters.Insert("FormParameters", FormParameters);
			FormOpenParameters.Insert("ResponseHandler", ResponseHandler);
			FormOpenParameters.Insert("WindowOpeningMode", Undefined);
			Parameters.InteractiveHandler = New NotifyDescription(
				"WarningInteractiveHandlerOnExit", ThisObject, FormOpenParameters);
		Else
			AdditionalParameters.Insert("FormOption", "AppliedForm");
			OpenApplicationWarningForm(Parameters, ResponseHandler, Warnings[0], FormName, FormParameters);
		EndIf;
	Else
		AdditionalParameters.Insert("FormOption", "StandardForm");
		FormOpenParameters = New Structure;
		FormOpenParameters.Insert("FormName", FormName);
		FormOpenParameters.Insert("FormParameters", FormParameters);
		FormOpenParameters.Insert("ResponseHandler", ResponseHandler);
		FormOpenParameters.Insert("WindowOpeningMode", Undefined);
		Parameters.InteractiveHandler = New NotifyDescription(
			"WarningInteractiveHandlerOnExit", ThisObject, FormOpenParameters);
	EndIf;
	
EndProcedure

// Continues the execution of OpenOnExitMessageForm procedure.
Procedure WarningInteractiveHandlerOnExit(Parameters, FormOpenParameters) Export
	
	OpenForm(
		FormOpenParameters.FormName,
		FormOpenParameters.FormParameters, , , , ,
		FormOpenParameters.ResponseHandler,
		FormOpenParameters.WindowOpeningMode);
	
EndProcedure

// Continues the execution of ShowMessageBoxAndContinue procedure.
Procedure ShowMessageBoxAndContinueExit(Result, Parameters) Export
	
	If Result <> Undefined Then
		If Result.Value = "ExitApplication" Then
			Parameters.Cancel = True;
		ElsIf Result.Value = "Restart" Or Result.Value = DialogReturnCode.Timeout Then
			Parameters.Cancel = True;
			Parameters.Restart = True;
		EndIf;
	EndIf;
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Generates representation of a single question.
//
//	If UserWarning has the HyperlinkText property, IndividualOpeningForm is opened from
//	the Structure of the question.
//	If UserWarning has the CheckBoxText property,
//	the CommonForm.QuestionBeforeExit form will be opened.
//
// Parameters:
//  Parameters - pass-through parameter of the BeforeExit procedure call chain.
//  ResponseHandler - NotifyDescription to continue once the user answered the question.
//  UserWarning - Structure - a structure of the passed warning.
//  FormName - String - a name of the common form with questions.
//  FormParameters - Structure - parameters for the form with questions.
//
Procedure OpenApplicationWarningForm(Parameters, ResponseHandler, UserWarning, FormName, FormParameters)
	
	HyperlinkText = "";
	If NOT UserWarning.Property("HyperlinkText", HyperlinkText) Then
		Return;
	EndIf;
	If IsBlankString(HyperlinkText) Then
		Return;
	EndIf;
	
	ActionOnClickHyperlink = Undefined;
	If NOT UserWarning.Property("ActionOnClickHyperlink", ActionOnClickHyperlink) Then
		Return;
	EndIf;
	
	ActionHyperlink = UserWarning.ActionOnClickHyperlink;
	Form = Undefined;
	
	If ActionHyperlink.Property("ApplicationWarningForm", Form) Then
		FormParameters = Undefined;
		If ActionHyperlink.Property("ApplicationWarningFormParameters", FormParameters) Then
			If TypeOf(FormParameters) = Type("Structure") Then 
				FormParameters.Insert("ApplicationShutdown", True);
			ElsIf FormParameters = Undefined Then 
				FormParameters = New Structure;
				FormParameters.Insert("ApplicationShutdown", True);
			EndIf;
			
			FormParameters.Insert("YesButtonTitle",  NStr("ru = 'Завершить'; en = 'Exit'; pl = 'Zakończ';es_ES = 'Salir';es_CO = 'Salir';tr = 'Çıkış';it = 'Uscita';de = 'Ausgang'"));
			FormParameters.Insert("NoButtonTitle", NStr("ru = 'Отмена'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal et';it = 'Annulla';de = 'Abbrechen'"));
			
		EndIf;
		FormOpenParameters = New Structure;
		FormOpenParameters.Insert("FormName", Form);
		FormOpenParameters.Insert("FormParameters", FormParameters);
		FormOpenParameters.Insert("ResponseHandler", ResponseHandler);
		FormOpenParameters.Insert("WindowOpeningMode", ActionHyperlink.WindowOpeningMode);
		Parameters.InteractiveHandler = New NotifyDescription(
			"WarningInteractiveHandlerOnExit", ThisObject, FormOpenParameters);
		
	ElsIf ActionHyperlink.Property("Form", Form) Then 
		FormParameters = Undefined;
		If ActionHyperlink.Property("FormParameters", FormParameters) Then
			If TypeOf(FormParameters) = Type("Structure") Then 
				FormParameters.Insert("ApplicationShutdown", True);
			ElsIf FormParameters = Undefined Then 
				FormParameters = New Structure;
				FormParameters.Insert("ApplicationShutdown", True);
			EndIf;
		EndIf;
		FormOpenParameters = New Structure;
		FormOpenParameters.Insert("FormName", Form);
		FormOpenParameters.Insert("FormParameters", FormParameters);
		FormOpenParameters.Insert("ResponseHandler", ResponseHandler);
		FormOpenParameters.Insert("WindowOpeningMode", ActionHyperlink.WindowOpeningMode);
		Parameters.InteractiveHandler = New NotifyDescription(
			"WarningInteractiveHandlerOnExit", ThisObject, FormOpenParameters);
		
	EndIf;
	
EndProcedure

// If Shutdown = True is specified, abort the further execution of the client code and shut down the application.
//
Procedure HandleErrorOnStartOrExit(Parameters, ErrorInformation, Event, Shutdown = False)
	
	If Event = "Startup" Then
		If Shutdown Then
			Parameters.Cancel = True;
			Parameters.ContinuationHandler = Parameters.CompletionProcessing;
		EndIf;
	Else
		AdditionalParameters = New Structure(
			"Parameters, ContinuationHandler", Parameters, Parameters.ContinuationHandler);
		
		Parameters.ContinuationHandler = New NotifyDescription(
			"ActionsBeforeExitAfterErrorProcessing", ThisObject, AdditionalParameters);
	EndIf;
	
	ErrorDescriptionBeginning = StandardSubsystemsServerCall.WriteErrorToEventLogOnStartOrExit(
		Shutdown, Event, DetailErrorDescription(ErrorInformation));	
	ErrorDescriptionBeginning = "";
	
	WarningText = ErrorDescriptionBeginning + Chars.LF
		+ NStr("ru = 'Техническая информация об ошибке записана в журнал регистрации.'; en = 'Technical error details have been saved to the event log.'; pl = 'Informacje techniczne dotyczące błędu są rejestrowane w dzienniku wydarzeń.';es_ES = 'Información técnica sobre el error se ha grabado en el registro de eventos.';es_CO = 'Información técnica sobre el error se ha grabado en el registro de eventos.';tr = 'Hata hakkındaki teknik bilgiler olay günlüğüne kaydedildi.';it = 'I dettagli tecnici dell''errore sono stati salvati nel registro degli eventi.';de = 'Technische Informationen zum Fehler werden im Ereignisprotokoll aufgezeichnet.'")
		+ Chars.LF + Chars.LF
		+ BriefErrorDescription(ErrorInformation);
	
	InteractiveHandler = New NotifyDescription(
		"ShowMessageBoxAndContinue",
		ThisObject,
		WarningText);
	
	Parameters.InteractiveHandler = InteractiveHandler;
	
EndProcedure

Procedure SetInterfaceFunctionalOptionParametersOnStart()
	
	ApplicationStartParameters = ApplicationParameters["StandardSubsystems.ApplicationRunParameters"];
	
	If TypeOf(ApplicationStartParameters) <> Type("Structure")
	 Or Not ApplicationStartParameters.Property("InterfaceOptions") Then
		// Startup error processing.
		Return;
	EndIf;
	
	If ApplicationStartParameters.Property("InterfaceOptionsSet") Then
		Return;
	EndIf;
	
	InterfaceOptions = New Structure(ApplicationStartParameters.InterfaceOptions);
	
	// Parameters of the functional options are set only if they are specified
	If InterfaceOptions.Count() > 0 Then
		SetInterfaceFunctionalOptionParameters(InterfaceOptions);
	EndIf;
	
	ApplicationStartParameters.Insert("InterfaceOptionsSet");
	
EndProcedure

Procedure ShowPutFileOnAttachFileSystemExtension(ExtensionAttached, AdditionalParameters) Export
	
	CompletionHandler = AdditionalParameters.CompletionHandler;
	FormID = AdditionalParameters.FormID;
	OriginalFileName = AdditionalParameters.OriginalFileName;
	DialogParameters = AdditionalParameters.DialogParameters;
	
	If Not ExtensionAttached Then
		Handler = New NotifyDescription("ProcessPutFileResult", ThisObject, CompletionHandler);
		BeginPutFile(Handler, , OriginalFileName, True, FormID);
		Return;
	EndIf;
	
	If DialogParameters = Undefined Then
		DialogParameters = New Structure;
	EndIf;
	If DialogParameters.Property("Mode") Then
		Mode = DialogParameters.Mode;
		If Mode = FileDialogMode.ChooseDirectory Then
			Raise NStr("ru = 'Выбор каталога не поддерживается'; en = 'Directory selection is not supported.'; pl = 'Wybór katalogu nie jest obsługiwany.';es_ES = 'Sección del directorio no se admite.';es_CO = 'Sección del directorio no se admite.';tr = 'Katalog seçimi desteklenmiyor.';it = 'La scelta della directory non è supportata.';de = 'Die Verzeichnisauswahl wird nicht unterstützt.'");
		EndIf;
	Else
		Mode = FileDialogMode.Open;
	EndIf;
	
	Dialog = New FileDialog(Mode);
	Dialog.FullFileName = OriginalFileName;
	FillPropertyValues(Dialog, DialogParameters);
	
	NotifyDescription = New NotifyDescription("ProcessPutFilesResult", ThisObject, CompletionHandler);
	
	If FormID <> Undefined Then
		BeginPuttingFiles(NotifyDescription, , Dialog, True, FormID);
	Else
		BeginPuttingFiles(NotifyDescription, , Dialog, True);
	EndIf;
	
EndProcedure

Procedure ProcessPutFilesResult(FilesThatWerePut, CompletionHandler) Export
	SelectionDone = FilesThatWerePut <> Undefined;
	ProcessPutFileResult(SelectionDone, FilesThatWerePut, Undefined, CompletionHandler);
EndProcedure

Procedure ProcessPutFileResult(SelectionDone, AddressOrSelectionResult, SelectedFileName, CompletionHandler) Export
	If SelectionDone = True Then
		If TypeOf(AddressOrSelectionResult) = Type("Array") Then
			FilesThatWerePut = AddressOrSelectionResult;
		Else
			FileDetails = New Structure;
			FileDetails.Insert("Location", AddressOrSelectionResult);
			FileDetails.Insert("Name",      SelectedFileName);
			FilesThatWerePut = New Array;
			FilesThatWerePut.Add(FileDetails);
		EndIf;
	Else
		FilesThatWerePut = Undefined;
	EndIf;
	
	ExecuteNotifyProcessing(CompletionHandler, FilesThatWerePut);
EndProcedure

Function MustShowRAMSizeRecommendations()
	ClientParameters = ClientParametersOnStart();
	Return ClientParameters.MustShowRAMSizeRecommendations;
EndFunction

Procedure NotifyLowMemory() Export
	RecommendedSize = ClientParametersOnStart().RecommendedRAM;
	
	Header = NStr("ru = 'Скорость работы снижена'; en = 'Application performance degraded'; pl = 'Szybkość pracy została zmniejszona';es_ES = 'Velocidad del funcionamiento ha sido disminuida';es_CO = 'Velocidad del funcionamiento ha sido disminuida';tr = 'Çalışma hızı düştü';it = 'Velocità di lavoro abbassata';de = 'Die Betriebsgeschwindigkeit wird reduziert'");
	Text = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Рекомендуется увеличить
		| объем памяти до %1 Гб.'; 
		|en = 'Consider increasing RAM size
		|to %1 GB.'; 
		|pl = 'Zaleca się zwiększyć
		| pojemność pamięci do %1 GB.';
		|es_ES = 'Se recomienda aumentar
		| el volumen de memoria hasta %1 Gb.';
		|es_CO = 'Se recomienda aumentar
		| el volumen de memoria hasta %1 Gb.';
		|tr = 'Bellek %1kapasitesini 
		|GB''ye yükseltmeniz önerilir.';
		|it = 'Si consiglia di aumentare il volume
		|della memoria RAM a %1 GB.';
		|de = 'Es wird empfohlen, die
		|Speicherkapazität auf %1 GB zu erhöhen.'"), RecommendedSize);
	
	ShowUserNotification(Header, 
	"e1cib/app/DataProcessor.SpeedupRecommendation",
	Text, PictureLib.Warning32);
EndProcedure

// Generates details on the selected spreadsheet document areas that can be passed to the server.
// Serves as a replacement for the SpreadsheetDocumentSelectedAreas type when you need eval sum of 
// cells on the server without a context.
// Also see StandardSubsystemsServerCall.CalculateCells.
//
// Parameters:
//   SpreadsheetDocument - SpreadsheetDocument- a table, for which the details of selected cells are generated.
//
// Returns:
//   Array - contains structure with the following properties:
//       * Top - Number - a row number of the upper area boun.
//       * Bottom - Number - a row number of the lower area boundary.
//       * Left - Number - a column number of the upper area boundary.
//       * Right - Number - a column number of the lower area boundary.
//       * AreaType - SpreadsheetDocumentCellsAreaType - Columns, Rectangle, Rows, Table.
//
Function SelectedAreas(SpreadsheetDocument)
	Result = New Array;
	For Each SelectedArea In SpreadsheetDocument.SelectedAreas Do
		If TypeOf(SelectedArea) <> Type("SpreadsheetDocumentRange") Then
			Continue;
		EndIf;
		Structure = New Structure("Top, Bottom, Left, Right, AreaType");
		FillPropertyValues(Structure, SelectedArea);
		Result.Add(Structure);
	EndDo;
	Return Result;
EndFunction

#EndRegion