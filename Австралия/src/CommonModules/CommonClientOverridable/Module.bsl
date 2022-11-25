#Region Public

// Is executed before a user starts interactive work with a data area or in the local mode.
// Corresponds to the BeforeStart handler.
//
// Parameters:
//  Parameters - Structure - a structure with the following properties:
//   * Cancel - Boolean - a return value. If True, the application is terminated.
//   * Restart - Boolean - the return value. If True and the Cancel parameter is True, restarts the 
//                              application.
// 
//   * AdditionalParametersOfCommandLine - String - the return value. Has a point when Cancel and 
//                              Restart are True.
//
//   * InteractiveHandler - NotifyDescription - the return value. To open the window that locks the 
//                              application start, pass the notification description handler that 
//                              opens the window. See the example below.
//
//   * ContinuationHandler - NotifyDescription - if there is a window that blocks signing in to an 
//                              application, this window close handler must execute the ContinuationHandler notification. See the example below.
//
//   * Modules - Array - references to the modules that will run the procedure after the return.
//                              You can add modules only by calling an overridable module procedure.
//                              It helps to simplify the design where a sequence of asynchronous 
//                              calls are made to a number of subsystems. See the example for SSLSubsystemsIntegrationClient.BeforeStart.
//
// Example:
//  The below code opens a window that blocks signing in to an application.
//
//		If OpenWindowOnStart Then
//			Parameter.InteractiveHandler = New NotificationDescription("OpenWindow", ThisObject);
//		EndIf
//
//	Procedure OpenWindow(Parameters, AdditionalParameters) Export
//		// Showing the window. Once the window is closed, calling the OpenWindowCompletion notification handler.
//		Notification = New NotificationDescription("OpenWindowCompletion", ThisObject, Parameters);
//		Form = OpenForm(... ,,, ... Notification);
//		If Not Form.IsOpen() Then //  If OnCreateAtServer Cancel is True.
//			ExecuteNotifyProcessing(Parameters.ContinuationHandler);
//		EndIf
//	EndProcedure
//
//	Procedure OpenWindowCompletion(Result, Parameters) Export
//		...
//		ExecuteNotifyProcessing(Parameters.ContinuationHandler);
//		
//	EndProcedure
//
Procedure BeforeStart(Parameters) Export
	DriveClient.BeforeStart(Parameters);
EndProcedure

// The procedure is executed when a user accesses a data area interactively or starts the application in the local mode.
// Corresponds to the OnStart handler.
//
// Parameters:
//  Parameters - Structure - a structure with the following properties:
//   * Cancel - Boolean - a return value. If True, the application is terminated.
//   * Restart - Boolean - the return value. If True and the Cancel parameter is True, restarts the 
//                              application.
//
//   * AdditionalParametersOfCommandLine - String - the return value. Has a point when Cancel and 
//                              Restart are True.
//
//   * InteractiveHandler - NotifyDescription - the return value. To open the window that locks the 
//                              application start, pass the notification description handler that 
//                              opens the window. See the BeforeStart for an example.
//
//   * ContinuationHandler - NotifyDescription - if there is a window that blocks signing in to an 
//                              application, this window close handler must execute the ContinuationHandler notification.
//                              See the CommonClientOverridable.BeforeStart for an example.
//
Procedure OnStart(Parameters) Export
	
	DriveParameters = New Structure("SettingsModified", False);
	DriveClient.OnStart(DriveParameters);
	
	If DriveParameters.SettingsModified Then
		RefreshInterface();
	EndIf;
	
EndProcedure

// The procedure is called to process the application startup parameters passed in the /C command 
// line. For example, 1cv8.exe ... /CDebugMode.
//
// Parameters:
//  LaunchParameters - Array - an array of strings separated with semicolons ";" in the start 
//                      parameter passed to the configuration using the /C command line key.
//  Cancel - Boolean - if True, the start is aborted.
//
Procedure LaunchParametersOnProcess(StartParameters, Cancel) Export
	
EndProcedure

// The procedure is executed when a user accesses a data area interactively or starts the application in the local mode.
// It is called after OnStart handler execution.
// Attaches the idle handlers that are only required after OnStart.
// 
//
// The home page is not open at the moment, that is why you cannot open forms directly but use an 
// idle handler instead.
// This event is not allowed for user interaction (for example, for ShowQueryBox).
//  For such scenarios, place your code in the OnStart procedure.
//
Procedure AfterStart() Export
	
#Region Version_1_3_10

	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	
	If ClientParameters.UserTemplateUsed <> Undefined
		And ClientParameters.UserTemplateUsed Then
		DriveClient.ShowMessageAboutUserTemplateUsed();
	EndIf;
	
#EndRegion
	
EndProcedure

// Is executed before the user logged off from the data area or exits the application in the local mode.
// Corresponds to the BeforeExit handler.
// Defines the list of user warnings on exit.
//
// Parameters:
//  Cancel - Boolean - if True, the application exit is interrupted.
//                            
//  Warning - Array - elements of the Structure type that describe the warning appearance and the 
//                            next steps.
//                            For the property descriptions, see StandardSubsystemsClient.WarningOnExit.
//
Procedure BeforeExit(Cancel, Warnings) Export
	
EndProcedure

// Used to override application captions.
//
// Parameters:
//  ApplicationCaption - String - the text displayed on the title bar.
//  OnStart - Boolean - True if the procedure is called on the application start.
//                                 It is forbidden to call configuration server functions that 
//                                 require the application start to be completed first.
//                                 For example, instead of StandardSubsystemsClientCached.
//                                 ClientRunParameters use StandardSubsystemsClientCached.ClientParametersOnStart.
//
// Example:
//  To display the project title on the application start, define parameter
//  CurrentProject in the CommonOverridable.OnAddClientParameters procedure and add the following code:
//
//  If OnStart Then
//    Return;
//  EndIf
//  ClientParameters = StandardSubsystemsClient.ClientRunParameters();
//  CurrentProject = Undefined;
//  If ClientParameters.SeparatedDataUsageAvailable And ClientParameters.Property("CurrentProject", CurrentProject)
//	  And Not ClientParameters.CurrentProject.Empty() Then
//	  ApplicationCaption = String(ClientParameters.CurrentProject) + "/" + ApplicationCaption;
//  EndIf
//
Procedure ClientApplicationCaptionOnSet(ApplicationCaption, OnStart) Export
	
	
	
EndProcedure

#EndRegion
