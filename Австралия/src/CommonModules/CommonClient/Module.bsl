////////////////////////////////////////////////////////////////////////////////
// Client procedures and functions of common use:
// - to manage lists on forms.
// - event logs
// - for user action processing during the user works with multiline text like comments in documents.
//   
// - other.
//  
////////////////////////////////////////////////////////////////////////////////

#Region Public

////////////////////////////////////////////////////////////////////////////////
// Functions to manage lists on forms.

// Checking that the Parameter command contains an ExpectedType object.
// Otherwise, returns False and displays the standard user message.
// This situation is possible, for example, when a row that contains a group is selected in a list.
//
// Application: commands that manage dynamic list items in forms.
// 
// Parameters:
//  Parameter - Array, AnyRef - the command parameter.
//  ExpectedType - Type - the expected type.
//
// Returns:
//  Boolean - True if the parameter type matches the expected type.
//
// Example:
// 
//   If Not CheckCommandParameterType(Items.List.SelectedRows,
//      Type("TaskRef.PerformerTask")) Then
//      Return;
//   EndIf
//   ...
Function CheckCommandParameterType(Val Parameter, Val ExpectedType) Export
	
	If Parameter = Undefined Then
		Return False;
	EndIf;
	
	Result = True;
	
	If TypeOf(Parameter) = Type("Array") Then
		// Checking whether the array contains only one element, and its type does not match the expected type.
		Result = NOT (Parameter.Count() = 1 AND TypeOf(Parameter[0]) <> ExpectedType);
	Else
		Result = TypeOf(Parameter) = ExpectedType;
	EndIf;
	
	If NOT Result Then
		ShowMessageBox(,NStr("ru = 'Действие не может быть выполнено для выбранного элемента.'; en = 'The operation cannot be executed for the current object.'; pl = 'Nie można wykonać czynności dla wybranego elementu.';es_ES = 'Acción no puede ejecutarse para el artículo seleccionado.';es_CO = 'Acción no puede ejecutarse para el artículo seleccionado.';tr = 'Seçilen öğe için işlem yapılamaz.';it = 'L''operazione non può essere eseguita per l''oggetto corrente.';de = 'Die Operation kann für das ausgewählte Element nicht ausgeführt werden.'"));
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Client procedures of common use.

// Returns current date in the session time zone.
//
// Returned time is close to the CurrentSessionDate() function result in the server context.
// The time inaccuracy is associated with the server call execution time.
// The function replaced the obsolete function CurrentDate().
//
// Returns:
//  Date - the actual session date.
//
Function SessionDate() Export
	
	If StandardSubsystemsClient.ApplicationStartCompleted() Then
		ClientParameters = StandardSubsystemsClient.ClientRunParameters();
	Else
		ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	EndIf;
	
	Return CurrentDate() + ClientParameters.SessionTimeOffset;
	
EndFunction

// Returns the GMT session date converted from the local session date.
//
// The returned time is close to the ToUniversalTime() function result in the server context.
// The time inaccuracy is associated with the server call execution time.
// The function replaced the obsolete function ToUniversalTime().
//
// Returns:
//  Date - the universal session date.
//
Function UniversalDate() Export
	
	If StandardSubsystemsClient.ApplicationStartCompleted() Then
		ClientParameters = StandardSubsystemsClient.ClientRunParameters();
	Else
		ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	EndIf;
	
	SessionDate = CurrentDate() + ClientParameters.SessionTimeOffset;
	Return SessionDate + ClientParameters.UniversalTimeCorrection;
	
EndFunction

// Suggests the user to install the file system extension in the web client.
// The function to be incorporated in the beginning of code areas that process files.
//
// Parameters:
//   ClosingNotifyDescription - NotifyDescription - the description of the procedure to be called 
//                                    once a form is closed. Parameters:
//                                      ExtensionAttached - Boolean - True if the extension is attached.
//                                      AdditionalParameters - Arbitrary - the parameters specified in
//                                                                               OnCloseNotifyDescription.
//   SuggestionText - String - the message text. If the text is not specified, the default text is displayed.
//   CanContinueWithoutInstalling - If True, show the ContinueWithoutInstalling button. If False, 
//                                              show the Cancel button.
//
// Example:
//
//    Notification = New NotifyDescription("PrintDocumentCompletion", ThisObject);
//    MessageText = NStr("en = 'To print the document, install the file system extension.'");
//    CommonClient.ShowFileSystemExtensionInstallationQuestion(Notification, MessageText);
//
//    Procedure PrintDocumentCompletion(ExtensionAttached, AdditionalParameters) Export
//      If ExtensionAttached Then
//        // Script that print a document only if the file system extension is attached.
//        // ...
//      Else
//        // Script that print a document if the file system extension is not attached.
//        // ...
//      EndIf
Procedure ShowFileSystemExtensionInstallationQuestion(OnCloseNotifyDescription, SuggestionText = "", 
	CanContinueWithoutInstalling = True) Export
	
	NotifyDescriptionCompletion = New NotifyDescription("ShowFileSystemExtensionInstallationQuestionCompletion",
		CommonInternalClient, OnCloseNotifyDescription);
	
#If Not WebClient Then
	// In the thin, thick, and web clients the extension is always attached.
	ExecuteNotifyProcessing(NotifyDescriptionCompletion, "AttachmentNotRequired");
	Return;
#EndIf
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("NotifyDescriptionCompletion", NotifyDescriptionCompletion);
	AdditionalParameters.Insert("SuggestionText", SuggestionText);
	AdditionalParameters.Insert("CanContinueWithoutInstalling", CanContinueWithoutInstalling);
	
	Notification = New NotifyDescription("ShowFileSystemExtensionInstallationOnInstallExtension",
		CommonInternalClient, AdditionalParameters);
	BeginAttachingFileSystemExtension(Notification);
	
EndProcedure

// Suggests the user to attach the file system extension in the web client and, in case of refuse, 
// notifies about impossibility of action continuation.
// Is intended to be used at the beginning of a script that can process files only if the file 
// system extension is attached.
//
// Parameters:
//  ClosingNotifyDescription - NotifyDescription - the description of the procedure to be called if 
//                                                     the extension is attached. Parameters:
//                                                      Result - Boolean - always True.
//                                                      AdditionalParameters - Undefined.
//  SuggestionText - String - text of suggestion to attach the file system extension.
//                                 If the text is not specified, the default text is displayed.
//  WarningText - String - warning text that notifies the user that the action cannot be continued.
//                                 If the text is not specified, the default text is displayed.
//
// Returns:
//  Boolean - True if the extension is attached.
//   
// Example:
//
//    Notification = New NotifyDescription("PrintDocumentCompletion", ThisObject);
//    MessageText = NStr("en = 'To print the document, install the file system extension.'");
//    CommonClient.CheckFileSystemExtensionAttached(Notification, MessageText);
//
//    Procedure PrintDocumentCompletion(Result, AdditionalParameters) Export
//        // Script that print a document only if the file system extension is attached.
//        // ...
Procedure CheckFileSystemExtensionAttached(OnCloseNotifyDescription, Val SuggestionText = "", 
	Val WarningText = "") Export
	
	Parameters = New Structure("OnCloseNotifyDescription,WarningText", 
		OnCloseNotifyDescription, WarningText, );
	Notification = New NotifyDescription("CheckFileSystemExtensionAttachedCompletion",
		CommonInternalClient, Parameters);
	ShowFileSystemExtensionInstallationQuestion(Notification, SuggestionText);
	
EndProcedure

// Returns the value of the "Suggest file system extension installation" user setting.
//
// Returns:
//  Boolean - True if the installation is suggested.
//
Function SuggestFileSystemExtensionInstallation() Export
	
	SystemInfo = New SystemInfo();
	ClientID = SystemInfo.ClientID;
	Return CommonServerCall.CommonSettingsStorageLoad(
		"ApplicationSettings/SuggestFileSystemExtensionInstallation", ClientID, True);
	
EndFunction

// Saves personal application user settings.
//
// Parameters:
//	Setting - Structure - a collection of settings:
//	 * RemindAboutFileSystemExtensionInstallation - Boolean - the flag indicating whether to notify 
//                                                               users on extension installation.
//	 * AskConfirmationOnExit - Boolean - the flag indicating whether to ask confirmation before the user exits the application.
//
Procedure SavePersonalSettings(Settings) Export
	
	If Settings.Property("RemindAboutFileSystemExtensionInstallation") Then
		ApplicationParameters["StandardSubsystems.SuggestFileSystemExtensionInstallation"] = 
			Settings.RemindAboutFileSystemExtensionInstallation;
	EndIf;
	
	If Settings.Property("AskConfirmationOnExit") Then
		StandardSubsystemsClient.SetClientParameter("AskConfirmationOnExit",
			Settings.AskConfirmationOnExit);
	EndIf;
		
	If Settings.Property("PersonalFilesOperationsSettings") Then
		StandardSubsystemsClient.SetClientParameter("PersonalFilesOperationsSettings",
			Settings.PersonalFilesOperationsSettings);
	EndIf;
	
EndProcedure

// Registers the comcntr.dll component for the current platform version.
// If the registration is successful, the procedure suggests the user to restart the client session 
// in order to registration takes effect.
//
// Is called before a client script that uses the COM connection manager (V83.COMConnector) and is 
// initiated by interactive user actions.
// 
// Parameters:
//  RestartSession - Boolean - if True, after the add-in is registered, the session restart dialog box is called.
//
// Example:
//  RegisterCOMConnector();
//    // Script that uses the COM connection manager (V83.COMConnector).
//    // ...
//
Procedure RegisterCOMConnector(Val RestartSession = True) Export
	
#If Not WebClient AND NOT MobileClient Then
	
	If ClientConnectedOverWebServer() Then
		Return;
	EndIf;
	
	ClientParametersOnStart = StandardSubsystemsClient.ClientParametersOnStart();
	
	If ClientParametersOnStart.IsBaseConfigurationVersion
		Or ClientParametersOnStart.IsTrainingPlatform Then
		Return;
	EndIf;
	
	CommandText = "regsvr32.exe /n /i:user /s comcntr.dll";
	
	ApplicationStartupParameters = CommonClientServer.ApplicationStartupParameters();
	ApplicationStartupParameters.CurrentDirectory = BinDir();
	ApplicationStartupParameters.WaitForCompletion = True;
	
	Result = CommonClientServer.StartApplication(CommandText, ApplicationStartupParameters);
	
	ReturnCode = Result.ReturnCode;
	
	If ReturnCode = Undefined Or ReturnCode <> 0 Then
		
		MessageText = NStr("ru = 'Ошибка при регистрации компоненты comcntr.'; en = 'Cannot register the comcntr component.'; pl = 'Wystąpił błąd podczas rejestrowania komponentu comcntr.';es_ES = 'Ha ocurrido un error al registrar el componente comcntr.';es_CO = 'Ha ocurrido un error al registrar el componente comcntr.';tr = 'comcntr bileşeni kaydedilemiyor.';it = 'Impossibile registrare la componente comcntr.';de = 'Bei der Registrierung der Komponente comcntr ist ein Fehler aufgetreten.'") + Chars.LF
			+ NStr("ru = 'Код ошибки regsvr32:'; en = 'regsvr32 error code:'; pl = 'Kod błędu Regsvr32:';es_ES = 'Código de error refsvr32:';es_CO = 'Código de error refsvr32:';tr = 'Regsvr32 hata kodu:';it = 'codice di errore Regsvr32:';de = 'regsvr32 Fehlercode:'") + " " + ReturnCode;
			
		If ReturnCode = 5 Then
			MessageText = MessageText + " " + NStr("ru = 'Недостаточно прав доступа.'; en = 'Insufficient access rights.'; pl = 'Niewystarczające prawa dostępu.';es_ES = 'Insuficientes derechos de acceso.';es_CO = 'Insuficientes derechos de acceso.';tr = 'Yetersiz erişim hakları.';it = 'Diritti di accesso insufficienti.';de = 'Unzureichende Zugriffsrechte.'");
		EndIf;
		
		EventLogClient.AddMessageForEventLog(
			NStr("ru = 'Регистрация компоненты comcntr'; en = 'Registering comcntr component'; pl = 'Rejestracja komponentu Comcntr';es_ES = 'Registro del componente comcntr';es_CO = 'Registro del componente comcntr';tr = 'comcntr bileşen kaydı';it = 'Registrazione componente comcntr';de = 'Registrierung der Comcntr-Komponente'", CommonClientServer.DefaultLanguageCode()), "Error", MessageText);
		EventLogServerCall.WriteEventsToEventLog(ApplicationParameters["StandardSubsystems.MessagesForEventLog"]);
		ShowMessageBox(,MessageText + Chars.LF + NStr("ru = 'Подробности см. в журнале регистрации.'; en = 'See the event log for details.'; pl = 'Szczegóły w Dzienniku wydarzeń';es_ES = 'Ver detalles en el registro.';es_CO = 'Ver detalles en el registro.';tr = 'Ayrıntılar için olay günlüğüne bakın.';it = 'Guarda il registro eventi per dettagli.';de = 'Siehe Details im Protokoll.'"));
	ElsIf RestartSession Then
		Notification = New NotifyDescription("RegisterCOMConnectorCompletion",
			CommonInternalClient);
		QuestionText = NStr("ru = 'Для завершения перерегистрации компоненты comcntr необходимо перезапустить программу.
			|Перезапустить сейчас?'; 
			|en = 'To complete the registration of comcntr component, restart the application.
			|Do you want to restart it now?'; 
			|pl = 'Dla zakończenia ponownej rejestracji komponentu comcntr należy ponownie uruchomić program.
			|Zrestartować teraz?';
			|es_ES = 'Para finalizar el registro del componente comcntr, usted tiene que reiniciar la aplicación.
			|¿Reiniciar ahora?';
			|es_CO = 'Para finalizar el registro del componente comcntr, usted tiene que reiniciar la aplicación.
			|¿Reiniciar ahora?';
			|tr = 'comcntr bileşeninin kaydını tamamlamak için uygulamayı yeniden başlatın.
			|Şimdi yeniden başlatılsın mı?';
			|it = 'Per completare la ri-registrazione della componente comcntr, è necessario riavviare il programma.
			|Riavviarlo ora?';
			|de = 'Um die Rückmeldung von Comcntr-Komponenten abzuschließen, müssen Sie das Programm neu starten.
			|Jetzt neu starten?'");
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo);
	EndIf;
	
#EndIf
	
EndProcedure

// Returns True if a client application is connected to the infobase through a web server.
//
// Returns:
//  Boolean - True if the application is connected.
//
Function ClientConnectedOverWebServer() Export
	
	Return StrFind(Upper(InfoBaseConnectionString()), "WS=") = 1;
	
EndFunction

// Asks whether the user wants to continue the action that will discard the changes:
// "Data was changed. Save the changes?"
// Use in form modules BeforeClose event handlers of the objects that can be written to infobase.
// 
// The message presentation depends on the form modification property.
// To display an arbitrary form question:
//  see the Common.ShowArbitraryFormClosingConfirmation() procedure.
//
// Parameters:
//  SaveAndCloseNotification - NotifyDescription - name of the procedure to be called once the OK button is clicked.
//  Cancel - Boolean - a return parameter that indicates whether the action is canceled.
//  Exit - Boolean - indicates whether the form closes on exit the application.
//  WarningText - String - the warning message text. The deafult text is:
//                                          "Data was changed. Save the changes?"
//  WarningTextOnExit - String - the return value that contains warning text displayed to users on 
//                                          exit the application. The default value is:
//                                          "Data was changed. All changes will be lost.".
//
// Example:
//
//  &AtClient
//  Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
//    Notification = New NotifyDescription("SelectAndClose", ThisObject);
//    CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
//  EndProcedure
//  
//  &AtClient
//  Procedure SelectAndClose(Result= Undefined, AdditionalParameters = Undefined) Export
//     // Writing form data.
//     // ...
//     Modified = False; // Do not show form closing notification again.
//     Close(<SelectionResult>);
//  EndProcedure
//
Procedure ShowFormClosingConfirmation(Val SaveAndCloseNotification, Cancel, 
	Val WorkCompletion, Val WarningText = "", WarningTextOnExit = Undefined) Export
	
	Form = SaveAndCloseNotification.Module;
	If Not Form.Modified Then
		Return;
	EndIf;
	
	Cancel = True;
	
	If WorkCompletion Then
		If WarningTextOnExit = "" Then // Parameter from BeforeClose is passed.
			WarningTextOnExit = NStr("ru = 'Данные были изменены. Все изменения будут потеряны.'; en = 'The data was changed. All changes will be lost.'; pl = 'Dane zostały zmienione. Wszystkie zmiany zostaną utracone.';es_ES = 'Datos cambiados. Todos los cambios se perderán.';es_CO = 'Datos cambiados. Todos los cambios se perderán.';tr = 'Veri değişti. Tüm değişiklikler kaybolacak.';it = 'I dati sono stati modificati. Tutte le modifiche verranno perse.';de = 'Daten geändert. Alle Änderungen gehen verloren.'");
		EndIf;
		Return;
	EndIf;
	
	Parameters = New Structure();
	Parameters.Insert("SaveAndCloseNotification", SaveAndCloseNotification);
	Parameters.Insert("WarningText", WarningText);
	
	ParameterName = "StandardSubsystems.FormClosingConfirmationParameters";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	
	CurrentParameters = ApplicationParameters["StandardSubsystems.FormClosingConfirmationParameters"];
	If CurrentParameters <> Undefined
	   AND CurrentParameters.SaveAndCloseNotification.Module = Parameters.SaveAndCloseNotification.Module Then
		Return;
	EndIf;
	
	ApplicationParameters["StandardSubsystems.FormClosingConfirmationParameters"] = Parameters;
	
	Form.Activate();
	AttachIdleHandler("ConfirmFormClosingNow", 0.1, True);
	
EndProcedure

// Asks whether the user wants to continue the action that closes the form.
// Is intended to be used in BeforeClose event notification handlers.
// To display a question in a form that can be written to the infobase:
//  see the CommonClient.ShowFormClosingConfirmation() procedure.
//
// Parameters:
//  Form - ClientApplicationForm - the form that calls the warning dialog.
//  Cancel - Boolean - a return parameter that indicates whether the action is canceled.
//  Exit - Boolean - indicates whether the application will be closed.
//  WarningText - String - the warning message text.
//  CloseFormWithoutConfirmationAttributeName - String - the name of the flag attribute that 
//                                 indicates whether to show the warning.
//  CloseNotifyDescription - NotifyDescription - name of the procedure to call once the OK button is clicked.
//
// Example: 
//  WarningText = NStr("en = 'Close the wizard?'");
//  CommonClient.ShowArbitraryFormClosingConfirmation(
//      ThisObject, Cancel, MessageText, "CloseFormWithoutConfirmation");
//
Procedure ShowArbitraryFormClosingConfirmation(Val Form, Cancel, Val WorkCompletion, 
	Val WarningText, Val CloseFormWithoutConfirmationAttributeName, Val CloseNotifyDescription = Undefined) Export
	
	If Form[CloseFormWithoutConfirmationAttributeName] Then
		Return;
	EndIf;
	
	Cancel = True;
	If WorkCompletion Then
		Return;
	EndIf;
	
	Parameters = New Structure();
	Parameters.Insert("Form", Form);
	Parameters.Insert("WarningText", WarningText);
	Parameters.Insert("CloseFormWithoutConfirmationAttributeName", CloseFormWithoutConfirmationAttributeName);
	Parameters.Insert("CloseNotifyDescription", CloseNotifyDescription);
	
	ParameterName = "StandardSubsystems.FormClosingConfirmationParameters";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	ApplicationParameters["StandardSubsystems.FormClosingConfirmationParameters"] = Parameters;
	
	AttachIdleHandler("ConfirmArbitraryFormClosingNow", 0.1, True);
	
EndProcedure

// The function gets the style color by a style item name.
//
// Parameters:
//  StyleColorName - String - style item name.
//
// Returns:
//    Color - the style color.
//
Function StyleColor(StyleColorName) Export
	
	Return CommonClientCached.StyleColor(StyleColorName);
	
EndFunction

// The function gets the style font by a style item name.
//
// Parameters:
//   StyleFontName - String - the style item name.
//
// Returns:
//  Font - the style font.
//
Function StyleFont(StyleFontName) Export
	
	Return CommonClientCached.StyleFont(StyleFontName);
	
EndFunction

// Updates the application interface keeping the current active window.
//
Procedure RefreshApplicationInterface() Export
	
	CurrentActiveWindow = ActiveWindow();
	RefreshInterface();
	If CurrentActiveWindow <> Undefined Then
		CurrentActiveWindow.Activate();
	EndIf;
	
EndProcedure

// Notifies opened forms and dynamic lists about changes in a single object.
//
// Parameters:
//  Source   - AnyRef,
//             InformationRegisterRecordKey,
//             AccumulationRegisterRecordKey,
//             AccountingRegisterRecordKey,
//             CalculationRegisterRecordKey - a changed object reference or changed register record 
//                                        key, whose update status to be provided to dynamic lists and forms.
//  AdditionalParameters - Arbitrary - parameters to be passed in the Notify method.
//
Procedure NotifyObjectChanged(Source, Val AdditionalParameters = Undefined) Export
	If AdditionalParameters = Undefined Then
		AdditionalParameters = New Structure;
	EndIf;
	Notify("Write_" + CommonInternalClient.MetadataObjectName(TypeOf(Source)), AdditionalParameters, Source);
	NotifyChanged(Source);
EndProcedure

// Notifies opened forms and dynamic lists about changes in multiple objects.
//
// Parameters:
//  Source - Type, TypeDescription - object type or types, whose update status to be provided to 
//                                  dynamic lists and forms.
//           - Array - a list of changed references or register record keys, whose update status to 
//                      be provided to dynamic lists and forms.
//  AdditionalParameters - Arbitrary - parameters to be passed in the Notify method.
//
Procedure NotifyObjectsChanged(Source, Val AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = New Structure;
	EndIf;
	
	If TypeOf(Source) = Type("Type") Then
		NotifyChanged(Source);
		Notify("Write_" + CommonInternalClient.MetadataObjectName(Source), AdditionalParameters);
	ElsIf TypeOf(Source) = Type("TypeDescription") Then
		For Each Type In Source.Types() Do
			NotifyChanged(Type);
			Notify("Write_" + CommonInternalClient.MetadataObjectName(Type), AdditionalParameters);
		EndDo;
	ElsIf TypeOf(Source) = Type("Array") Then
		If Source.Count() = 1 Then
			NotifyObjectChanged(Source[0], AdditionalParameters);
		Else
			NotifiedTypes = New Map;
			For Each Ref In Source Do
				NotifiedTypes.Insert(TypeOf(Ref));
			EndDo;
			For Each Type In NotifiedTypes Do
				NotifyChanged(Type.Key);
				Notify("Write_" + CommonInternalClient.MetadataObjectName(Type.Key), AdditionalParameters);
			EndDo;
		EndIf;
	EndIf;

EndProcedure

// Returns the client platform type.
//
// Returns:
//  PlatformType, Undefined - the type of the platform running a client. In the web client mode, if 
//                               the actual platform type does not match the PlatformType value, returns Undefined.
//
Function ClientPlatformType() Export
	
	Return CommonClientCached.ClientPlatformType();
	
EndFunction

// See Common.FileInfobase. 
Function FileInfobase(Val InfobaseConnectionString = "") Export
	
	If Not IsBlankString(InfobaseConnectionString) Then
		Return StrFind(Upper(InfobaseConnectionString), "FILE=") = 1;
	EndIf;
	
	Return StandardSubsystemsClient.ClientParameter("FileInfobase");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for processing and calling optional subsystems.

// Returns True if the "functional" subsystem exists in the configuration.
// Intended for calling optional subsystems (conditional calls).
//
// A subsystem is considered functional if its "Include in command interface" check box is cleared.
//
// Parameters:
//  FullSubsystemName - String - the full name of the subsystem metadata object without the 
//                        "Subsystem." part, case-sensitive.
//                        Example: "StandardSubsystems.ReportOptions".
//
// Example:
//
//  If Common.SubsystemExists("StandardSubsystems.ReportOptions") Then
//  	ModuleReportOptionsClient = CommonClient.CommonModule("ReportOptionsClient");
//  	ModuleReportOptionsClient.<Method name>()
//  EndIf
//
// Returns:
//  Boolean - True if exists.
//
Function SubsystemExists(FullSubsystemName) Export
	
	ParameterName = "StandardSubsystems.ConfigurationSubsystems";
	If ApplicationParameters[ParameterName] = Undefined Then
		SubsystemNames = StandardSubsystemsClient.ClientParametersOnStart().SubsystemNames;
		ApplicationParameters.Insert(ParameterName, SubsystemNames);
	EndIf;
	SubsystemNames = ApplicationParameters[ParameterName];
	Return SubsystemNames.Get(FullSubsystemName) <> Undefined;
	
EndFunction

// Returns a reference to a common module or manager module by name.
//
// Parameters:
//  Name - String - name of a common module.
//
// Returns:
//  CommonModule, ObjectManagerModule - a common module.
//
// Example:
//	If CommonClient.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
//		ModuleSoftwareUpdateClient = CommonClient.CommonModule("ConfigurationUpdateClient");
//		ModuleSoftwareUpdateClient.<Method name>();
//	EndIf
//
//	If CommonClient.SubsystemExists("StandardSubsystems.FullTextSearch") Then
//		ModuleFullTextSearchClient = CommonClient.CommonModule("FullTextSearchClient");
//		ModuleFullTextSearchClient.<Method name>();
//	EndIf
//
Function CommonModule(Name) Export
	
	Module = Eval(Name);
	
#If Not WebClient Then
	
	// The check is skipped as the module does not exist for this server type in the web client.
	// 
	
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Общий модуль ""%1"" не найден.'; en = 'Common module %1 is not found.'; pl = 'Nie znaleziono wspólnego modułu ""%1"".';es_ES = 'Módulo común ""%1"" no se ha encontrado.';es_CO = 'Módulo común ""%1"" no se ha encontrado.';tr = 'Ortak modül ""%1"" bulunamadı.';it = 'Il modulo comune %1 non è stato trovato.';de = 'Gemeinsames Modul ""%1"" wurde nicht gefunden.'"), 
			Name);
	EndIf;
	
#EndIf
	
	Return Module;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions that process multiline text edition (for example, document comments).
// 

// Opens the multiline text edit form.
//
// Parameters:
//  ClosingNotification - NotifyDescription - the details of the procedure to be called when the 
//                            text entry form is closed. Contains the same parameters as method
//                            ShowInputString.
//  MultilineText - String - a text to be edited.
//  Title - String - the text to be displayed in the from title.
//
// Example:
//
//   Notification = New NotifyDescription("CommentEndEntering", ThisObject);
//   CommonClient.FormMultilineTextEditingShow(Notification, Item.EditingText);
//
//   &AtClient
//   Procedure CommentEndEntering(Val EnteredText, Val AdditionalParameters) Export
//      If EnteredText = Undefined Then
//		   Return;
//   	EndIf;
//	
//	   Object.MultilineComment = EnteredText;
//	   Modified = True;
//   EndProcedure
//
Procedure ShowMultilineTextEditingForm(Val ClosingNotification, 
	Val MultilineText, Val Header = Undefined) Export
	
	If Header = Undefined Then
		ShowInputString(ClosingNotification, MultilineText,,, True);
	Else
		ShowInputString(ClosingNotification, MultilineText, Header,, True);
	EndIf;
	
EndProcedure

// Opens the multiline comment editing form.
//
// Parameters:
//  MultilineText - String - a text to be edited.
//  OwnerForm - ClientApplicationForm - the form that owns the field a user entering a comment into.
//  AttributeName - String - the name of the form attribute the user comment will be stored to.
//                                     
//  Title - String - the text to be displayed in the from title.
//                                     The default value is "Comment".
//
// Example:
//  CommonClient.ShowCommentEditingForm(Item.EditingText, ThisObject, "Object.Comment");
//
Procedure ShowCommentEditingForm(
	Val MultilineText, 
	Val OwnerForm, 
	Val AttributeName = "Object.Comment", 
	Val Title = Undefined) Export
	
	Context = New Structure;
	Context.Insert("OwnerForm", OwnerForm);
	Context.Insert("AttributeName", AttributeName);
	
	Notification = New NotifyDescription(
		"CommentInputCompletion", 
		CommonInternalClient, 
		Context);
	
	FormHeader = ?(Title <> Undefined, Title, NStr("ru = 'Комментарий'; en = 'Comment'; pl = 'Uwagi';es_ES = 'Comentario';es_CO = 'Comentario';tr = 'YORUM';it = 'Commento';de = 'Kommentar'"));
	
	ShowMultilineTextEditingForm(Notification, MultilineText, FormHeader);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for backup in the user mode.

// Checks whether the backup can be done in the user mode.
//
// Returns:
//  Boolean - True if the installation is suggested.
//
Function PromptToBackUp() Export
	
	Result = False;
	SubsystemsIntegrationSSLClient.OnCheckIfCanBackUpInUserMode(Result);
	Return Result;
	
EndFunction

// Prompt users for back up.
Procedure PromptUserToBackUp() Export
	
	SubsystemsIntegrationSSLClient.OnPromptUserForBackup();
	
EndProcedure

// Opens an attachment format selection form.
//
// Parameters:
//  NotifyDescription - NotifyDescription - a choice result handler.
//  FormatSetings - Structure - default settings in the form of:
//   * PackToArchive   - Boolean - shows whether it is necessary to archive attachments.
//   * SaveFormats - Array - a list of selected save formats.
//   * TransliterateFilesNames - Boolean - convert Cyrillic characters to Latin characters.
//  Owner - ClientApplicationForm - the form used to call the attachment selection form.
//
Procedure ShowAttachmentsFormatSelection(NotifyDescription, FormatSettings, Owner = Undefined) Export
	
	FormParameters = New Structure("FormatSettings", FormatSettings);
	OpenForm("CommonForm.SelectAttachmentFormat",
		FormParameters, , , , ,
		NotifyDescription,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#Region AddIns

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions to connect and install add-ins from configuration templates.

// Returns parameter structure. See the AttachAddInFromTemplate procedure.
//
// Returns:
//  Structure - a collection of the following parameters:
//      * Cached - Boolean - use component caching on the client (the default value is True).
//      * SuggestInstall - Boolean - (default value is True) prompt to install and update an add-in.
//      * NoteText       - String - a text that describes the add-in purpose and which functionality requires the add-in.
//      * ObjectCreationIDs - Array - the creation IDs of object module instances. Applicable only 
//                 with add-ins that have a number of object creation IDs. Ignored if the ID 
//                 parameter is specified.
//
// Example:
//
//  AttachmentParameters = CommonClient.AddInAttachmentParameters();
//  AttachmentParameters.NoteText = NStr("en = 'To use a barcode scanner, install
//                                             |the 1C:Barcode scanners (NativeApi) add-in.'");
//
Function AddInAttachmentParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("Cached", True);
	Parameters.Insert("SuggestInstall", True);
	Parameters.Insert("NoteText", "");
	Parameters.Insert("ObjectCreationIDs", New Array);
	
	Return Parameters;
	
EndFunction

// Connects an add-in based on Native API and COM technology in an asynchronous mode.
// The add-inn must be stored in the configuration template in as a ZIP file.
// Web client can display dialog with installation tips.
//
// Parameters:
//  Notification - NotifyDescription - connection notification details with the following parameters:
//      * Result - Structure - add-in connection result:
//          ** Connected - Boolean - connection flag.
//          ** AttachableModule - AddIn - an instance of the add-in.
//                                - FixedMap - the add-in object instances stored in 
//                                     AttachmentParameters.ObjectCreationIDs.
//                                     Key - ID, Value - object instance.
//          ** ErrorDescription     - String - a brief error description. Empty string on cancel by user.
//      * AdditionalParameters - Structure - a value that was specified when creating the NotifyDescription object.
//  ID - String - the add-in identification code.
//  FullTemplateName - String - the full name of the template used as the add-in location.
//  AttachmentParameters - Structure, Undefined - see the AddInAttachmentParameters function.
//
// Example:
//
//  Notification = New NotifyDescription("AttachAddInSSLCompletion", ThisObject);
//
//  AttachmentParameters = CommonClient.AddInAttachmentParameters();
//  AttachmentParameters.NoteText = NStr("en = 'To apply for the certificate,
//                                             install the CryptS add-in.'");
//
//  CommonClient.AttachAddInFromTemplate(Notification,
//      "CryptS",
//      "DataProcessor.ApplicationForNewQualifiedCertificateIssue.Template.ExchangeComponent",
//      AttachmentParameters);
//
//  &AtClient
//  Procedure AttachAddInSSLCompletion(Result, AdditionalParameters) Export
//
//      AttachableModule = Undefined;
//
//      If Result.Attached Then
//          AttachableModule = Result.AttachableModule;
//      Else
//          If Not IsBlankString(Result.ErrorDescription) Then
//              ShowMessageBox (, Result.ErrorDescription);
//          EndIf
//      EndIf
//
//      If AttachableModule <> Undefined Then
//          // AttachableModule contains the instance of the attached add-in.
//      EndIf
//
//      AttachableModule = Undefined;
//
//  EndProcedure
//
Procedure AttachAddInFromTemplate(Notification, ID, FullTemplateName,
	AttachmentParameters = Undefined) Export
	
	Parameters = AddInAttachmentParameters();
	If AttachmentParameters <> Undefined Then
		FillPropertyValues(Parameters, AttachmentParameters);
	EndIf;
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	Context.Insert("ID", ID);
	Context.Insert("Location", FullTemplateName);
	Context.Insert("Cached", Parameters.Cached);
	Context.Insert("SuggestInstall", Parameters.SuggestInstall);
	Context.Insert("NoteText", Parameters.NoteText);
	Context.Insert("ObjectCreationIDs", Parameters.ObjectCreationIDs);
	
	CommonInternalClient.AttachAddInSSL(Context);
	
EndProcedure

// Returns a parameter structure. See the InstallAddInFromTemplate procedure.
//
// Returns:
//  Structure - a collection of the following parameters:
//      * NoteText - String - purpose of an add-in and what applications do not operate without it.
//
// Example:
//
//  InstallationParameters = CommonClient.AddInInstallParameters();
//  InstallationParameters.NoteText = NStr("en = 'To use a barcode scanner, install
//                                           |the 1C:Barcode scanners (NativeApi) add-in.'");
//
Function AddInInstallParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("NoteText", "");
	
	Return Parameters;
	
EndFunction

// Connects an add-in based on Native API and COM technology in an asynchronous mode.
// The add-inn must be stored in the configuration template in as a ZIP file.
//
// Parameters:
//  Notification - Notification details - Notification details of add-in installation:
//      * Structure - Completed - install component result:
//          ** Installed - Boolean - installation flag.
//          ** ErrorDescription - String - a brief error description. Empty string on cancel by user.
//      * AdditionalParameters - Structure - a value that was specified when creating the NotifyDescription object.
//  FullTemplateName - String - the full name of the template used as the add-in location.
//  InstallationParameters - Structure, Undefined - see the AddInInstallParameters function.
//
// Example:
//
//  Notification = New NotifyDescription("SetCompletionComponent", ThisObject);
//
//  InstallationParameters = CommonClient.AddInInstallParameters();
//  InstallationParameters.NoteText = NStr("en = 'To apply for the certificate,
//                                           install the CryptS add-in.'");
//
//  CommonClient.InstallAddInFromTemplate(Notification,
//      "DataProcessor.ApplicationForNewQualifiedCertificateIssue.Template.ExchangeComponent",
//      InstallationParameters);
//
//  &AtClient
//  Procedure InstallAddInEnd(Result, AdditionalParameters) Export
//
//      If Not Result.Installed and Not IsBlankString(Result.ErrorDescription) Then
//          ShowMessageBox (, Result.ErrorDescription);
//      EndIf
//
//  EndProcedure
//
Procedure InstallAddInFromTemplate(Notification, FullTemplateName, InstallationParameters = Undefined) Export
	
	Parameters = AddInInstallParameters();
	If InstallationParameters <> Undefined Then
		FillPropertyValues(Parameters, InstallationParameters);
	EndIf;
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	Context.Insert("Location", FullTemplateName);
	Context.Insert("NoteText", Parameters.NoteText);
	
	CommonInternalClient.InstallAddInSSL(Context);
	
EndProcedure

#EndRegion

#Region RunExternalApplications

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for managing external applications.

// Opens Windows Explorer to the specified directory.
// If a file path is specified, the pointer is placed on the file.
//
// Parameters:
//  PathToDirectoryOrFile - String - the full path to a file or folder on the drive.
//
// Example:
//  // For Windows OS
//  CommonClient.OpenExplorer("C:\Users");
//  CommonClient.OpenExplorer("C:\Program Files\1cv8\common\1cestart.exe");
//  // For Linux OS
//  CommonClient.OpenExplorer("/home/");
//  CommonClient.OpenExplorer("/opt/1C/v8.3/x86_64/1cv8c");
//
Procedure OpenExplorer(PathToDirectoryOrFile) Export
	
	FileInfo = New File(PathToDirectoryOrFile);
	
	Context = New Structure;
	Context.Insert("FileInfo", FileInfo);
	
	Notification = New NotifyDescription(
		"OpenExplorerAfterCheckFileSystemExtension", CommonInternalClient, Context);
		
	SuggestionText = NStr("ru = 'Для открытия папки необходимо установить расширение работы с файлами.'; en = 'To be able to open the directory, install the file system extension.'; pl = 'Dla otwarcia foldera należy zainstalować rozszerzenie pracy z plikami.';es_ES = 'Para abrir la carpeta es necesario instalar la extensión de la operación de archivos.';es_CO = 'Para abrir la carpeta es necesario instalar la extensión de la operación de archivos.';tr = 'Klasörü açmak için, dosyalarla çalışmak için bir uzantı yüklenmelidir.';it = 'Per poter aprire la directory, installare l''estensione del file di sistema.';de = 'Um einen Ordner zu öffnen, müssen Sie die Dateierweiterung installieren.'");
	ShowFileSystemExtensionInstallationQuestion(Notification, SuggestionText, False);
	
EndProcedure

// Opens the file in the application associated with the file type.
// Prevents executable files from opening.
//
// Parameters:
//  PathToFile - String - the full path to the file to open.
//  Notification - NotifyDescription, Undefined - notification on file open attempt.
//                            - If the notification description is not specified and an error occurs, the method shows a warning.
//      * ApplicationStarted - Boolean - True if the external application opened successfully.
//      * AdditionalParameters - Structure - a value that was specified when creating the NotifyDescription object.
//
// Example:
//  CommonClient.OpenFileInViewer(DocumentsDir() + "test.pdf");
//  CommonClient.OpenFileInViewer(DocumentsDir() + "test.xlsx");
//
Procedure OpenFileInViewer(PathToFile, Val Notification = Undefined) Export
	
	FileInfo = New File(PathToFile);
	
	Context = New Structure;
	Context.Insert("FileInfo", FileInfo);
	Context.Insert("Notification", Notification);
	
	Notification = New NotifyDescription(
		"OpenFileInViewerAfterCheckFileSystemExtension", CommonInternalClient, Context);
	
	SuggestionText = NStr("ru = 'Для открытия файла необходимо установить расширение работы с файлами.'; en = 'To be able to open the file, install the file system extension.'; pl = 'Dla otwarcia pliku należy zainstalować rozszerzenie pracy z plikami.';es_ES = 'Para abrir el archivo es necesario instalar la extensión de la operación de archivos.';es_CO = 'Para abrir el archivo es necesario instalar la extensión de la operación de archivos.';tr = 'Dosyayı açmak için, dosyalarla çalışmak için bir uzantı yüklenmelidir.';it = 'Per poter aprire il file, installare l''estensione del file di sistema.';de = 'Um eine Datei zu öffnen, sollten Sie die Dateierweiterung installieren.'");
	ShowFileSystemExtensionInstallationQuestion(Notification, SuggestionText, False);
	
EndProcedure

// Opens a URL in an application associated with URL protocol.
//
// Valid protocols: http, https, e1c, v8help, mailto, tel, skype.
//
// Do not use protocol file:// to open Explorer or a file.
// - To Open Explorer, use OpenExplorer. 
// - To open a file in an associated application, use OpenFileInViewer. 
//
// Parameters:
//  URL - Reference - a link to open.
//  Notification - NotifyDescription, Undefined - notification on file open attempt.
//                            - If the notification description is not specified and an error occurs, the method shows a warning.
//      * ApplicationStarted - Boolean - True if the external application opened successfully.
//      * AdditionalParameters - Structure - a value that was specified when creating the NotifyDescription object.
//
// Example:
//  CommonClient.OpenURL("e1cib/navigationpoint/startpage"); // Home page.
//  CommonClient.OpenURL("v8help://1cv8/QueryLanguageFullTextSearchInData");
//  CommonClient.OpenURL("https://1c.ru");
//  CommonClient.OpenURL("mailto:help@1c.ru");
//  CommonClient.OpenURL("skype:echo123?call");
//
Procedure OpenURL(URL, Val Notification = Undefined) Export
	
	Context = New Structure;
	Context.Insert("URL", URL);
	Context.Insert("Notification", Notification);
	
	ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось перейти по ссылке ""%1"" по причине: 
			           |Неверно задана навигационная ссылка.'; 
			           |en = 'Cannot follow link ""%1."" Reason: 
			           |Invalid URL.'; 
			           |pl = 'Nie udało się przejść pod linkiem ""%1"" z powodu: 
			           |Błędnie jest podany link nawigacyjny.';
			           |es_ES = 'No se ha podido pasar por enlace ""%1"" a causa de: 
			           |Enlace de navegación está especificado incorrectamente.';
			           |es_CO = 'No se ha podido pasar por enlace ""%1"" a causa de: 
			           |Enlace de navegación está especificado incorrectamente.';
			           |tr = 'Aşağıdaki nedenle ""%1"" linke geçemedi: 
			           |Gezinme bağlantısı yanlış ayarlandı.';
			           |it = 'Impossibile seguire il collegamento ""%1"". Motivo:
			           |URL non valido.';
			           |de = 'Konnte dem Link ""%1"" nicht folgen, weil:
			           |Der Navigationslink wurde nicht korrekt gesetzt.'"),
			URL);
	
	If Not CommonInternalClient.IsAllowedRef(URL) Then 
		CommonInternalClient.OpenURLNotifyOnError(ErrorDescription, Context);
		Return;
	EndIf;
	
	If CommonInternalClient.IsWebURL(URL)
		Or CommonInternalClient.IsURL(URL) Then 
		
		Try
		
#If ThickClientOrdinaryApplication Then
			// Platform design feature: GotoURL is not supported by ordinary applications running in the thick client mode.
			Notification = New NotifyDescription(,, Context,
				"OpenURLOnProcessError", CommonInternalClient);
			BeginRunningApplication(Notification, URL);
#Else
			GotoURL(URL);
#EndIf
		
		Except
			CommonInternalClient.OpenURLNotifyOnError(ErrorDescription, Context);
			Return;
		EndTry;
		
		If Notification <> Undefined Then 
			ApplicationStarted = True;
			ExecuteNotifyProcessing(Notification, ApplicationStarted);
		EndIf;
		
		Return;
	EndIf;
	
	If CommonInternalClient.IsHelpRef(URL) Then 
		OpenHelp(URL);
		Return;
	EndIf;
	
	Notification = New NotifyDescription(
		"OpenURLAfterCheckFileSystemExtension", CommonInternalClient, Context);
		
	SuggestionText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Для открытия ссылки ""%1"" необходимо установить расширение работы с файлами.'; en = 'To be able to open link ""%1,"" install the file system extension.'; pl = 'Dla otwarcia linku ""%1"" należy zainstalować rozszerzenie pracy z plikami.';es_ES = 'Para abrir el enlace ""%1"" es necesario instalar la extensión de la operación de archivos.';es_CO = 'Para abrir el enlace ""%1"" es necesario instalar la extensión de la operación de archivos.';tr = '""%1"" linki açmak için, dosyalarla çalışma uzantısı yüklenmelidir.';it = 'Per poter aprire il collegamento ""%1"", installare l''estensione del file di sistema.';de = 'Um den Link ""%1"" zu öffnen, müssen Sie die Dateierweiterung installieren.'"),
		URL);
	ShowFileSystemExtensionInstallationQuestion(Notification, SuggestionText, False);
	
EndProcedure

// Returns parameter structure. See the StartApplication procedure.
//
// Returns:
//  CurrentDirectory - String - returns the application location directory.
//  Notification - Boolean - NotifyDescription, Undefined - notification on closing an application.
//                                         
//                                         If the notification description is not specified and an error occurs, the method shows a warning.
//      * Result - Structure - the application operation result.
//          ** ApplicationStarted - Boolean - True if the external application opened successfully.
//          ** ErrorDescription     - String - a brief error description. Empty string on cancel by user.
//          ** ReturnCode - Number - application return code.
//      * AdditionalParameters - Structure - a value that was specified when creating the NotifyDescription object.
//
Function ApplicationStartupParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("CurrentDirectory", "");
	Parameters.Insert("Notification", Undefined);
	
	Return Parameters;
	
EndFunction

// (RunApplication) Starts an external application with specified startup parameters.
//
// Parameters:
//  StartupCommand - String, Array - application startup command line.
//      If Array, the first element is the path to the application, the rest of the elements are its 
//      startup parameters. The procedure generates an argv string from the array.
//  ApplicationStartupParameters - Structure, Undefined - see the ApplicationStartupParameters function.
//
// Example:
//
//
Procedure StartApplication(Val StartupCommand, ApplicationStartupParameters = Undefined) Export
	
	If ApplicationStartupParameters = Undefined Then 
		ApplicationStartupParameters = ApplicationStartupParameters();
	EndIf;
	
	CurrentDirectory      = ApplicationStartupParameters.CurrentDirectory;
	Notification          = ApplicationStartupParameters.Notification;
	
	CommandString = CommonClientServer.SafeCommandString(StartupCommand);
	
	Context = New Structure;
	Context.Insert("CommandString", CommandString);
	Context.Insert("CurrentDirectory", CurrentDirectory);
	Context.Insert("Notification", Notification);
	
	Notification = New NotifyDescription(
		"StartApplicationAfterCheckFileSystemExtension", CommonInternalClient, Context);
		
	SuggestionText = NStr("ru = 'Для создания временного каталога необходимо установить расширение работы с файлами.'; en = 'To be able to create a temporary directory, install the file system extension.'; pl = 'W celu utworzenia tymczasowego katalogu należy zainstalować rozszerzenie pracy z plikami.';es_ES = 'Para crear un catálogo temporal es necesario instalar la extensión del uso de archivos.';es_CO = 'Para crear un catálogo temporal es necesario instalar la extensión del uso de archivos.';tr = 'Geçici dizini oluşturmak için, dosyalarla çalışmak için bir uzantı yüklenmelidir.';it = 'Per poter creare una directory temporanea, installare l''estensione del file di sistema.';de = 'Um ein temporäres Verzeichnis zu erstellen, müssen Sie eine Dateierweiterung installieren.'");
	ShowFileSystemExtensionInstallationQuestion(Notification, SuggestionText, False);
	
EndProcedure

#EndRegion

#Region TemporaryFiles

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions to manage temporary files.

// Gets temporary directory name.
//
// Parameters:
//  Notification - NotifyDescription - notification on getting directory name attempt.
//      * DirectoryName - String - path to the directory.
//      * AdditionalParameters - Structure - a value that was specified when creating the NotifyDescription object.
//  Extension - Sting - the suffix in the directory name, which helps to identify the directory for analysis.
//
Procedure CreateTemporaryDirectory(Val Notification, Extension = "") Export 
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	Context.Insert("Extension", Extension);
	
	Notification = New NotifyDescription("CreateTemporaryDirectoryAfterCheckFileSystemExtension",
		CommonInternalClient, Context);
		
	SuggestionText = NStr("ru = 'Для создания временного каталога необходимо установить расширение работы с файлами.'; en = 'To be able to create a temporary directory, install the file system extension.'; pl = 'W celu utworzenia tymczasowego katalogu należy zainstalować rozszerzenie pracy z plikami.';es_ES = 'Para crear un catálogo temporal es necesario instalar la extensión del uso de archivos.';es_CO = 'Para crear un catálogo temporal es necesario instalar la extensión del uso de archivos.';tr = 'Geçici dizini oluşturmak için, dosyalarla çalışmak için bir uzantı yüklenmelidir.';it = 'Per poter creare una directory temporanea, installare l''estensione del file di sistema.';de = 'Um ein temporäres Verzeichnis zu erstellen, müssen Sie eine Dateierweiterung installieren.'");
	ShowFileSystemExtensionInstallationQuestion(Notification, SuggestionText, False);
	
EndProcedure

#EndRegion

#Region CurrentEnvironment

// Returns True if the client application is running on macOS.
//
// See Common.IsMacOSClient 
//
// Returns:
//  Boolean - False if no client application is available.
//
Function IsMacOSClient() Export
	
	ClientPlatformType = ClientPlatformType();
	Return ClientPlatformType = PlatformType.MacOS_x86
		Or ClientPlatformType = PlatformType.MacOS_x86_64;
	
EndFunction

#EndRegion

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use instead:
//  OpenURL to pass a URL or a website link.
//  OpenExplorer to pass the path to a file or directory in Explorer.
//  OpenFileInViewer to open a file in a associated application.
//
// Follows a link to visit an infobase object or external object.
// For example a link to a site or path to a folder.
//
// Parameters:
//  Reference - Reference - a link to follow.
//
Procedure GoToLink(Ref) Export
	
	#If ThickClientOrdinaryApplication Then
		// Platform design feature: GotoURL is not supported by ordinary applications running in the thick client mode.
		Notification = New NotifyDescription;
		BeginRunningApplication(Notification, Ref);
	#Else
		GotoURL(Ref);
	#EndIf
	
EndProcedure

#EndRegion

#EndRegion
