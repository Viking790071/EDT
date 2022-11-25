////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region Public

// Handler procedure intended to close the exchange plan node settings form.
//
// Parameters:
//  Form - ClientApplicationForm - a form the procedure is called from.
// 
Procedure NodesSetupFormCloseFormCommand(Form) Export
	
	If Not Form.CheckFilling() Then
		Return;
	EndIf;
	
	Form.Modified = False;
	FillStructureData(Form);
	Form.Close(Form.Context);
	
EndProcedure

// Handler procedure intended to close the exchange plan node settings form.
//
// Parameters:
//  Form - ClientApplicationForm - a form the procedure is called from.
// 
Procedure NodeSettingsFormCloseFormCommand(Form) Export
	
	OnCloseExchangePlanNodeSettingsForm(Form, "NodeFilterStructure");
	
EndProcedure

// Handler procedure intended to close the form for setting default exchange plan node values.
//
// Parameters:
//  Form - ClientApplicationForm - a form the procedure is called from.
// 
Procedure DefaultValueSetupFormCloseFormCommand(Form) Export
	
	OnCloseExchangePlanNodeSettingsForm(Form, "NodeDefaultValues");
	
EndProcedure

// Handler procedure intended to close the exchange plan node settings form.
//
// Parameters:
//  Cancel            - Boolean           - a flag showing whether form closing is canceled.
//  Form            - ClientApplicationForm - a form the procedure is called from.
//  Exit - Boolean           - indicates whether the form closes when a user exits the application.
// 
// Example:
//
//	&AtClient
//	Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
//		DataExchangeClient.SetupFormBeforeClose(Cancel,ThisObject,WorkCompletion)
//	EndProcedure
//
Procedure SetupFormBeforeClose(Cancel, Form, WorkCompletion) Export
	
	ProcedureName = "DataExchangeClient.SetupFormBeforeClose";
	CommonClientServer.CheckParameter(ProcedureName, "Cancel", Cancel, Type("Boolean"));
	CommonClientServer.CheckParameter(ProcedureName, "Form", Form, Type("ClientApplicationForm"));
	CommonClientServer.CheckParameter(ProcedureName, "WorkCompletion", WorkCompletion, Type("Boolean"));
	
	If Not Form.Modified Then
		Return;
	EndIf;
		
	Cancel = True;
	
	If WorkCompletion Then
		Return;
	EndIf;
	
	QuestionText = NStr("ru = 'Данные были изменены. Закрыть форму без сохранения изменений?'; en = 'Data was changed. Close the form without saving the changes?'; pl = 'Dane zostały zmienione. Zamknij formularz bez zapisywania zmian?';es_ES = 'Datos se han cambiado. ¿Cerrar el formulario sin guardar los cambios?';es_CO = 'Datos se han cambiado. ¿Cerrar el formulario sin guardar los cambios?';tr = 'Veriler değiştirildi. Değişiklikleri kaydetmeden formu kapatmak istiyor musunuz?';it = 'I dati sono stati modificati. Chiudere il modulo senza salvare?';de = 'Daten wurden geändert. Schließen Sie das Formular, ohne die Änderungen zu speichern?'");
	NotifyDescription = New NotifyDescription("SetupFormBeforeCloseCompletion", ThisObject, Form);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo,, DialogReturnCode.No);
	
EndProcedure

// Opens the form of data exchange settings wizard for the specified exchange plan.
//
// Parameters:
//  ExchangePlanName         - String - a name of the exchange plan (as a metadata object) for which 
//                                    the wizard is to be opened.
//  SetupID - String - ID of data exchange settings option.
// 
Procedure OpenDataExchangeSetupWizard(Val ExchangePlanName, Val SettingID) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("ExchangePlanName", ExchangePlanName);
	FormParameters.Insert("SettingID", SettingID);
	
	FormKey = ExchangePlanName + "_" + SettingID;
	
	OpenForm("DataProcessor.DataExchangeCreationWizard.Form.ConnectionSetup", FormParameters, ,
		FormKey, , , , FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Handler of item choice start for correspondent base node settings form on setting exchange 
// through external connection.
//
// Parameters:
//	AttributeName - String - a form attribute name.
//	TableName - String - a full metadata object name.
//	Owner - ClientApplicationForm - a form of selecting correspondent base items.
//	StandardProcessing - Boolean - a flag of standard (system) event processing execution.
//	ExternalConnectionParameters - Structure - parameters of external connection.
//	ChoiceParameters - Structure - a structure of choice parameters.
//
Procedure CorrespondentInfobaseItemSelectionHandlerStartChoice(Val AttributeName, Val TableName, Val Owner,
	Val StandardProcessing, Val ExternalConnectionParameters, Val ChoiceParameters=Undefined) Export
	
	IDAttributeName = AttributeName + "_Key";
	
	ChoiceInitialValue = Undefined;
	ChoiceOfGroupsAndItems    = Undefined;
	
	OwnerType = TypeOf(Owner);
	If OwnerType=Type("FormTable") Then
		CurrentData = Owner.CurrentData;
		If CurrentData<>Undefined Then
			ChoiceInitialValue = CurrentData[IDAttributeName];
		EndIf;
		
	ElsIf OwnerType=Type("ClientApplicationForm") Then
		ChoiceInitialValue = Owner[IDAttributeName];
		
	EndIf;
	
	If ChoiceParameters<>Undefined Then
		If ChoiceParameters.Property("ChoiceFoldersAndItems") Then
			ChoiceOfGroupsAndItems = ChoiceParameters.ChoiceFoldersAndItems;
		EndIf;
	EndIf;
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("ExternalConnectionParameters",        ExternalConnectionParameters);
	FormParameters.Insert("CorrespondentInfobaseTableFullName", TableName);
	FormParameters.Insert("ChoiceInitialValue",            ChoiceInitialValue);
	FormParameters.Insert("AttributeName",                       AttributeName);
	FormParameters.Insert("ChoiceFoldersAndItems",               ChoiceOfGroupsAndItems);
	
	OpenForm("CommonForm.SelectCorrespondentInfobaseObjects", FormParameters, Owner);
	
EndProcedure

// Handler of picking up items for correspondent base node settings form on setting exchange through 
// external connection.
//
// Parameters:
//	AttributeName - String - a form attribute name.
//	TableName - String - a full metadata object name.
//	Owner - ClientApplicationForm - a form of selecting correspondent base items.
//	ExternalConnectionParameters - Structure - parameters of external connection.
//	ChoiceParameters - Structure - a structure of choice parameters.
//
Procedure CorrespondentInfobaseItemSelectionHandlerPick(Val AttributeName, Val TableName, Val Owner,
	Val ExternalConnectionParameters, Val ChoiceParameters=Undefined) Export
	
	IDAttributeName = AttributeName + "_Key";
	
	ChoiceInitialValue = Undefined;
	ChoiceOfGroupsAndItems    = Undefined;
	
	CurrentData = Owner.CurrentData;
	If CurrentData<>Undefined Then
		ChoiceInitialValue = CurrentData[IDAttributeName];
	EndIf;
	
	StandardProcessing = False;
	
	If ChoiceParameters<>Undefined Then
		If ChoiceParameters.Property("ChoiceFoldersAndItems") Then
			ChoiceOfGroupsAndItems = ChoiceParameters.ChoiceFoldersAndItems;
		EndIf;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ExternalConnectionParameters",        ExternalConnectionParameters);
	FormParameters.Insert("CorrespondentInfobaseTableFullName", TableName);
	FormParameters.Insert("ChoiceInitialValue",            ChoiceInitialValue);
	FormParameters.Insert("CloseOnChoice",                 False);
	FormParameters.Insert("AttributeName",                       AttributeName);
	FormParameters.Insert("ChoiceFoldersAndItems",               ChoiceOfGroupsAndItems);
	
	OpenForm("CommonForm.SelectCorrespondentInfobaseObjects", FormParameters, Owner);
EndProcedure

// Handler of item choice processing for correspondent base node settings form on setting exchange 
// through external connection.
//
// Parameters:
//	Item - ClientApplicationForm, FormTable - an item to process selection.
//	SelectedValue - Arbitrary - see the SelectedValue parameter description of the ChoiceProcessing event.
//	FormDataCollection - FormDataCollection - for picking from list.
//
Procedure CorrespondentInfobaseItemsSelectionHandlerChoiceProcessing(Val Item, Val SelectedValue, Val FormDataCollection=Undefined) Export
	
	If TypeOf(SelectedValue)<>Type("Structure") Then
		Return;
	EndIf;
	
	IDAttributeName = SelectedValue.AttributeName + "_Key";
	PresentationAttributeName  = SelectedValue.AttributeName;
	
	ItemType = TypeOf(Item);
	If ItemType=Type("FormTable") Then
		
		If SelectedValue.PickMode Then
			If FormDataCollection<>Undefined Then
				Filter = New Structure(IDAttributeName, SelectedValue.ID);
				ExistingRows = FormDataCollection.FindRows(Filter);
				If ExistingRows.Count() > 0 Then
					Return;
				EndIf;
			EndIf;
			
			Item.AddRow();
		EndIf;
		
		CurrentData = Item.CurrentData;
		If CurrentData<>Undefined Then
			CurrentData[IDAttributeName] = SelectedValue.ID;
			CurrentData[PresentationAttributeName]  = SelectedValue.Presentation;
		EndIf;
		
	ElsIf ItemType=Type("ClientApplicationForm") Then
		Item[IDAttributeName] = SelectedValue.ID;
		Item[PresentationAttributeName]  = SelectedValue.Presentation;
		
	EndIf;
	
EndProcedure

// Checks whether the Use flag is set for all table rows.
//
// Parameters:
//  Table - ValueTable - a table to be checked.
//
// Returns:
//  Boolean - the flag that indicates using all items.
Function AllRowsMarkedInTable(Table) Export
	
	For Each Item In Table Do
		
		If Item.Use = False Then
			
			Return False;
			
		EndIf;
		
	EndDo;
	
	Return True;
EndFunction

// Deletes data synchronization settings item.
//
// Parameters:
//   InfobaseNode - ExchangePlanRef - an exchange plan node corresponding to the exchange to be disabled.
//
Procedure DeleteSynchronizationSetting(Val InfobaseNode) Export
	
	If DataExchangeServerCall.IsMasterNode(InfobaseNode) Then
		WarningText = NStr("ru = 'Отключение информационной базы от главного узла можно выполнить
			|с помощью параметра запуска конфигуратора /ResetMasterNode.'; 
			|en = 'You can disable infobase from the main node
			|using Designer launch parameter /ResetMasterNode.'; 
			|pl = 'Odłączenie bazy informacyjnej od głównego węzła można wykonać
			|za pomocą parametrów uruchomienia konfiguratora /ResetMasterNode.';
			|es_ES = 'Se puede desactivar la base de información del nodo principal
			|con el parámetro de lanzamiento del configurador /ResetMasterNode.';
			|es_CO = 'Se puede desactivar la base de información del nodo principal
			|con el parámetro de lanzamiento del configurador /ResetMasterNode.';
			|tr = 'Yapılandırıcı çalıştırma parametresi /ResetMasterNode yardımıyla 
			|veritabanın ana ünite ile bağlantısı kapatılabilir.';
			|it = 'È possibile disattivare l''infobase dal nodo principale
			|utilizzando il parametro di lancio di Designer /ResetMasterNode.';
			|de = 'Sie können die Informationsbasis vom Hauptknoten trennen, indem Sie
			|mit dem Parameter /ResetMasterNode den Konfigurator starten.'");
		ShowMessageBox(, WarningText);
	Else
		WizardParameters = New Structure;
		WizardParameters.Insert("ExchangeNode", InfobaseNode);
		
		OpenForm("DataProcessor.DataExchangeCreationWizard.Form.DeleteSyncSetting", WizardParameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region Internal

// Modally opens the event log with filter by data export or import events for the specified 
// exchange plan node.
//
Procedure GoToDataEventLogModally(InfobaseNode, Owner, ActionOnExchange) Export
	
	// server call
	FormParameters = DataExchangeServerCall.EventLogFilterData(InfobaseNode, ActionOnExchange);
	
	OpenForm("DataProcessor.EventLog.Form", FormParameters, Owner);
	
EndProcedure

// Returns the name of the message form that contains a notification about an infobase update error that occurs due to an ORR error.
// 
// Returns:
//  String - a name of failed update message form.
//
Function FailedUpdateMessageFormName() Export
	
	Return "InformationRegister.DataExchangeRules.Form.UnsuccessfulUpdateMessage";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonClientOverridable.BeforeStart. 
Procedure BeforeStart(Parameters) Export
	
	// If the subordinate distributed infobase is started and exchange message must be reimported, the 
	// user is prompted to select further action: reimport the message or skip it.
	// 
	// 
	
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	
	If NOT ClientParameters.Property("RetryDataExchangeMessageImportBeforeStart") Then
		Return;
	EndIf;
	
	Parameters.InteractiveHandler = New NotifyDescription(
		"RetryDataExchangeMessageImportBeforeStartInteractiveHandler", ThisObject);
	
EndProcedure

// See CommonClientOverridable.OnStart. 
Procedure OnStart(Parameters) Export
	
	ClientRunParameters = StandardSubsystemsClient.ClientParametersOnStart();
	If ClientRunParameters.Property("OpenDataExchangeCreationWizardForSubordinateNodeSetup") Then
		
		For Each Window In GetWindows() Do
			If Window.IsMain Then
				Window.Activate();
				Break;
			EndIf;
		EndDo;
		
		WizardParameters = New Structure;
		WizardParameters.Insert("ExchangePlanName", ClientRunParameters.DIBExchangePlanName);
		WizardParameters.Insert("SettingID", ClientRunParameters.DIBNodeSettingID);
		WizardParameters.Insert("NewSYnchronizationSetting");
		WizardParameters.Insert("ContinueSetupInSubordinateDIBNode");
		
		OpenForm("DataProcessor.DataExchangeCreationWizard.Form.SyncSetup", WizardParameters);
	EndIf;
	
EndProcedure

// See CommonClientOverridable.AfterStart. 
Procedure AfterStart() Export
	
	ClientRunParameters = StandardSubsystemsClient.ClientParametersOnStart();
	If NOT ClientRunParameters.SeparatedDataUsageAvailable OR ClientRunParameters.DataSeparationEnabled Then
		Return;
	EndIf;
		
	If Not ClientRunParameters.IsMasterNode
		AND Not ClientRunParameters.Property("OpenDataExchangeCreationWizardForSubordinateNodeSetup")
		AND ClientRunParameters.Property("CheckSubordinateNodeConfigurationUpdateRequired") Then
		
		AttachIdleHandler("CheckSubordinateNodeConfigurationUpdateRequiredOnStart", 1, True);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Internal export functions for retrieving properties.

// Returns the maximum number of fields to be displayed in the infobase object mapping wizard.
// 
//
// Returns:
//     Number - maximum number of fields for mapping.
//
Function MaxCountOfObjectsMappingFields() Export
	
	Return 5;
	
EndFunction

// Returns the structure of data import execution statuses.
//
Function DataImportStatusPages() Export
	
	Structure = New Structure;
	Structure.Insert("Undefined", "ImportStatusUndefined");
	Structure.Insert("Error",       "ImportStatusError");
	Structure.Insert("Success",        "ImportStateSuccess");
	Structure.Insert("Execute",   "ImportStatusExecution");
	
	Structure.Insert("Warning_ExchangeMessageAlreadyAccepted", "ImportStatusWarning");
	Structure.Insert("CompletedWithWarnings",                     "ImportStatusWarning");
	Structure.Insert("Error_MessageTransport",                      "ImportStatusError");
	
	Return Structure;
EndFunction

// Returns the structure of data export execution statuses.
//
Function DataExportStatusPages() Export
	
	Structure = New Structure;
	Structure.Insert("Undefined", "ExportStatusUndefined");
	Structure.Insert("Error",       "ExportStatusError");
	Structure.Insert("Success",        "ExportStatusSuccess");
	Structure.Insert("Execute",   "ExportStatusExecution");
	
	Structure.Insert("Warning_ExchangeMessageAlreadyAccepted", "ExportStatusWarning");
	Structure.Insert("CompletedWithWarnings",                     "ExportStatusWarning");
	Structure.Insert("Error_MessageTransport",                      "ExportStatusError");
	
	Return Structure;
EndFunction

// Returns a structure with name of data import field hyperlink.
//
Function DataImportHyperlinksHeaders() Export
	
	Structure = New Structure;
	Structure.Insert("Undefined",               NStr("ru = 'Получение данных не выполнялось'; en = 'Data was not received.'; pl = 'Odbieranie danych nie zostało wykonane';es_ES = 'Recibo de los datos no se ha realizado';es_CO = 'Recibo de los datos no se ha realizado';tr = 'Veri alma işlemi gerçekleştirilmedi';it = 'I dati non sono stati ricevuti.';de = 'Der Datenempfang wurde nicht durchgeführt'"));
	Structure.Insert("Error",                     NStr("ru = 'Не удалось получить данные'; en = 'Cannot receive the data.'; pl = 'Nie można odebrać danych';es_ES = 'No se puede recibir los datos';es_CO = 'No se puede recibir los datos';tr = 'Veri alınamıyor';it = 'Impossibile ricevere i dati.';de = 'Die Daten können nicht empfangen werden'"));
	Structure.Insert("CompletedWithWarnings", NStr("ru = 'Данные получены с предупреждениями'; en = 'Data has been received with warnings.'; pl = 'Dane zostały odebrane z ostrzeżeniami';es_ES = 'Datos recibidos con avisos';es_CO = 'Datos recibidos con avisos';tr = 'Veriler uyarılarla alındı';it = 'I dati sono stati ricevuti con avvisi.';de = 'Daten werden mit Warnungen empfangen'"));
	Structure.Insert("Success",                      NStr("ru = 'Данные успешно получены'; en = 'Data has been received successfully.'; pl = 'Dane zostały pomyślnie odebrane';es_ES = 'Datos se han recibido con éxito';es_CO = 'Datos se han recibido con éxito';tr = 'Veri başarıyla alındı';it = 'I dati sono stati ricevuti con successo.';de = 'Daten werden erfolgreich empfangen'"));
	Structure.Insert("Execute",                 NStr("ru = 'Выполняется получение данных...'; en = 'Receiving data ...'; pl = 'Odbiór danych...';es_ES = 'Recibiendo datos...';es_CO = 'Recibiendo datos...';tr = 'Veri alınıyor ...';it = 'Ricevendo dati ...';de = 'Daten empfangen...'"));
	
	Structure.Insert("Warning_ExchangeMessageAlreadyAccepted", NStr("ru = 'Нет новых данных для получения'; en = 'No data to receive.'; pl = 'Brak nowych danych do odbioru';es_ES = 'No hay datos nuevos para recibir';es_CO = 'No hay datos nuevos para recibir';tr = 'Alınacak yeni veri yok';it = 'Nessun dato da ricevere.';de = 'Keine neuen Daten erhalten'"));
	Structure.Insert("Error_MessageTransport",                      NStr("ru = 'Не удалось получить данные'; en = 'Cannot receive the data.'; pl = 'Nie można odebrać danych';es_ES = 'No se puede recibir los datos';es_CO = 'No se puede recibir los datos';tr = 'Veri alınamıyor';it = 'Impossibile ricevere i dati.';de = 'Die Daten können nicht empfangen werden'"));
	
	Return Structure;
EndFunction

// Returns a structure with name of data export field hyperlink.
//
Function DataExportHyperlinksHeaders() Export
	
	Structure = New Structure;
	Structure.Insert("Undefined", NStr("ru = 'Отправка данных не выполнялась'; en = 'Data was not sent.'; pl = 'Dane nie zostały wysłane';es_ES = 'Datos no se han enviado';es_CO = 'Datos no se han enviado';tr = 'Veri gönderilmedi';it = 'I dati non è stato inviato';de = 'Daten wurden nicht gesendet'"));
	Structure.Insert("Error",       NStr("ru = 'Не удалось отправить данные'; en = 'Errors occurred during the data sending.'; pl = 'Nie można wysłać danych';es_ES = 'No se puede enviar los datos';es_CO = 'No se puede enviar los datos';tr = 'Veri gönderilemiyor.';it = 'Si sono registrati errori durante l''invio dati.';de = 'Die Daten können nicht gesendet werden'"));
	Structure.Insert("Success",        NStr("ru = 'Данные успешно отправлены'; en = 'Data has been sent successfully.'; pl = 'Dane zostały wysłane pomyślnie';es_ES = 'Datos se han enviado con éxito';es_CO = 'Datos se han enviado con éxito';tr = 'Veri başarıyla gönderildi';it = 'I dati sono stati inviati con successo.';de = 'Daten wurden erfolgreich gesendet'"));
	Structure.Insert("Execute",   NStr("ru = 'Выполняется отправка данных...'; en = 'Sending data...'; pl = 'Przesyłanie danych...';es_ES = 'Enviando los datos...';es_CO = 'Enviando los datos...';tr = 'Veri gönderiliyor...';it = 'Invio dei dati ...';de = 'Daten senden...'"));
	
	Structure.Insert("Warning_ExchangeMessageAlreadyAccepted", NStr("ru = 'Данные отправлены с предупреждениями'; en = 'Data has been sent with warnings.'; pl = 'Dane zostały wysłane z ostrzeżeniami';es_ES = 'Datos se han enviado con avisos';es_CO = 'Datos se han enviado con avisos';tr = 'Veriler uyarılarla gönderildi';it = 'I dati sono stati inviati con avvisi.';de = 'Daten werden mit Warnungen gesendet'"));
	Structure.Insert("CompletedWithWarnings",                     NStr("ru = 'Данные отправлены с предупреждениями'; en = 'Data has been sent with warnings.'; pl = 'Dane zostały wysłane z ostrzeżeniami';es_ES = 'Datos se han enviado con avisos';es_CO = 'Datos se han enviado con avisos';tr = 'Veriler uyarılarla gönderildi';it = 'I dati sono stati inviati con avvisi.';de = 'Daten werden mit Warnungen gesendet'"));
	Structure.Insert("Error_MessageTransport",                      NStr("ru = 'Не удалось отправить данные'; en = 'Errors occurred during the data sending.'; pl = 'Nie można wysłać danych';es_ES = 'No se puede enviar los datos';es_CO = 'No se puede enviar los datos';tr = 'Veri gönderilemiyor.';it = 'Si sono registrati errori durante l''invio dati.';de = 'Die Daten können nicht gesendet werden'"));
	
	Return Structure;
EndFunction

// Opens a form or hyperlink with a detailed description of data synchronization.
//
Procedure OpenSynchronizationDetails(ReferenceToDetails) Export
	
	If Upper(Left(ReferenceToDetails, 4)) = "HTTP" Then
		
		CommonClient.OpenURL(ReferenceToDetails);
		
	Else
		
		OpenForm(ReferenceToDetails);
		
	EndIf;
	
EndProcedure

// Opens a proxy server parameters form.
//
Procedure OpenProxyServerParametersForm() Export
	
	If CommonClient.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownloadClient = CommonClient.CommonModule("GetFilesFromInternetClient");
		
		FormParameters = Undefined;
		If CommonClient.FileInfobase() Then
			FormParameters = New Structure("ProxySettingAtClient", True);
		EndIf;
		
		ModuleNetworkDownloadClient.OpenProxyServerParametersForm(FormParameters);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// For internal use only.
//
Procedure RetryDataExchangeMessageImportBeforeStartInteractiveHandler(Parameters, Context) Export
	
	Form = OpenForm(
		"InformationRegister.DataExchangeTransportSettings.Form.DataReSyncBeforeStart", , , , , ,
		New NotifyDescription(
			"AfterCloseFormDataResynchronizationBeforeStart", ThisObject, Parameters));
	
	If Form = Undefined Then
		AfterCloseFormDataResynchronizationBeforeStart("Continue", Parameters);
	EndIf;
	
EndProcedure

// For internal use only. Continuation of the procedure.
// InteractiveHandlerRetryDataExchangeMessageImportBeforeStart.
//
Procedure AfterCloseFormDataResynchronizationBeforeStart(Result, Parameters) Export
	
	If Result <> "Continue" Then
		Parameters.Cancel = True;
	Else
		Parameters.RetrievedClientParameters.Insert(
			"RetryDataExchangeMessageImportBeforeStart");
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. Continuation of the procedure.
// SetupFormBeforeClose.
//
Procedure SetupFormBeforeCloseCompletion(Response, Form) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	Form.Modified = False;
	Form.Close();
	
	// Clearing cached values to reset COM connections.
	RefreshReusableValues();
EndProcedure

// Opens a file in the operating system's associated application.
//
// Parameters:
//     Object               - Arbitrary - an object from which the name of the file to open is retrieved by property name.
//     PropertyName          - String       - a name of the object property that contains the name of the file to open.
//     StandardProcessing - Boolean       - the flag of standard processing, it is set to False.
//
Procedure FileOrDirectoryOpenHandler(Object, PropertyName, StandardProcessing = False) Export
	StandardProcessing = False;
	
	FullFileName = Object[PropertyName];
	If IsBlankString(FullFileName) Then
		Return;
	EndIf;
	
	CommonClient.OpenExplorer(FullFileName);
	
EndProcedure

// Opens dialog box to select file directory and requests installation of extension for file operations.
//
// Parameters:
//     Object                - Arbitrary       - an object to set the property being selected in.
//     PropertyName           - String             - a name of the property that contains the name of the file being set in the object. 
//                                                  Source of the initial value.
//     StandardProcessing  - Boolean - a standard processing flag, set to False.
//     DialogParameters      - Structure          - optional additional parameters of the directory selection dialog.
//     CompletionNotification  - NotifyDescription - an optional notification that is called with 
//                                                  the following parameters:
//                                 Result               - String - the selected value (array of 
//                                                                    strings if multiple selection is used).
//                                 AdditionalParameters - Undefined.
//
Procedure FileDirectoryChoiceHandler(Object, Val PropertyName, StandardProcessing = False, Val DialogParameters = Undefined, CompletionNotification = Undefined) Export
	StandardProcessing = False;
	
	DialogDefaultOptions = New Structure;
	DialogDefaultOptions.Insert("Title", NStr("ru = 'Укажите каталог'; en = 'Select directory'; pl = 'Wybierz folder';es_ES = 'Seleccionar el directorio';es_CO = 'Seleccionar el directorio';tr = 'Dizini seçin';it = 'Selezionare la directory';de = 'Wählen Sie das Verzeichnis aus'") );
	
	SetDefaultStructureValues(DialogParameters, DialogDefaultOptions);
	
	WarningText = NStr("ru = 'Для данной операции необходимо установить расширение для веб-клиента 1С:Предприятие.'; en = 'This action requires the file system extension for 1C:Enterprise web client.'; pl = 'Zainstaluj rozszerzenie klienta sieci web 1C:Enterprise dla tej operacji.';es_ES = 'Instalar la extensión para el cliente web de la 1C:Empresa para esta operación.';es_CO = 'Instalar la extensión para el cliente web de la 1C:Empresa para esta operación.';tr = 'Bu işlem için 1C:Enterprise web istemcisi için uzantı yükleyin.';it = 'Questa azione richiede l''estensione del file di sistema per il client web 1C:Enterprise.';de = 'Installieren Sie die Erweiterung für 1C:Enterprise Web Client für diesen Vorgang.'");
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Object",               Object);
	AdditionalParameters.Insert("PropertyName",          PropertyName);
	AdditionalParameters.Insert("DialogParameters",     DialogParameters);
	AdditionalParameters.Insert("CompletionNotification", CompletionNotification);
	
	Notification = New NotifyDescription("FileDirectorySelectionHandlerCompletion", ThisObject, AdditionalParameters);
	CommonClient.ShowFileSystemExtensionInstallationQuestion(Notification, WarningText, False);
EndProcedure

// Handler for non-modal completion of the directory selection dialog.
//
Procedure FileDirectorySelectionHandlerCompletion(Val Result, Val AdditionalParameters) Export
	
	If Result <> True Then
		Return;
	EndIf;
	
	PropertyName = AdditionalParameters.PropertyName;
	Object      = AdditionalParameters.Object;
	
	Dialog = New FileDialog(FileDialogMode.ChooseDirectory);
	FillPropertyValues(Dialog, AdditionalParameters.DialogParameters);
	
	Dialog.Directory = Object[PropertyName];
	ChoiceDialogNotifyDescription = New NotifyDescription(
		"FileDirectoryChoiceHandlerCompletionAfterChoiceInDialog",
		ThisObject, AdditionalParameters);
	Dialog.Show(ChoiceDialogNotifyDescription);
	
EndProcedure

// Continuation of the procedure (see above).
// 
Procedure FileDirectoryChoiceHandlerCompletionAfterChoiceInDialog(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles <> Undefined Then
		
		PropertyName = AdditionalParameters.PropertyName;
		Object      = AdditionalParameters.Object;
		
		Object[PropertyName] = SelectedFiles[0];
		
		If AdditionalParameters.CompletionNotification <> Undefined Then
			ExecuteNotifyProcessing(AdditionalParameters.CompletionNotification, SelectedFiles[0]);
		EndIf;
		
	EndIf;
	
EndProcedure

// Opens a file selection dialog box and requests the installation of extension for file operations.
//
// Parameters:
//     Object                - Arbitrary       - an object to set the property being selected in.
//     PropertyName           - String             - a name of the property that contains the name of the file being set in the object. 
//                                                  Source of the initial value.
//     StandardProcessing  - Boolean - a standard processing flag, set to False.
//     DialogParameters      - Structure          - optional additional parameters of the file selection dialog.
//     CompletionNotification  - NotifyDescription - an optional notification that is called with 
//                                                  the following parameters:
//                                 Result               - String - the selected value (array of 
//                                                                                  strings if multiple selection is used) or Undefined (if nothing is selected).
//                                 AdditionalParameters - Undefined.
//
//
Procedure FileSelectionHandler(Object, Val PropertyName, StandardProcessing = False, Val DialogParameters = Undefined, CompletionNotification = Undefined) Export
	
	StandardProcessing = False;
	
	DialogDefaultOptions = New Structure;
	DialogDefaultOptions.Insert("Mode",                       FileDialogMode.Open);
	DialogDefaultOptions.Insert("CheckFileExist", True);
	DialogDefaultOptions.Insert("Title",                   NStr("ru = 'Выберите файл'; en = 'Select file'; pl = 'Wybierz plik';es_ES = 'Seleccionar un archivo';es_CO = 'Seleccionar un archivo';tr = 'Dosya seç';it = 'Selezione del file';de = 'Datei auswählen'"));
	DialogDefaultOptions.Insert("Multiselect",          False);
	DialogDefaultOptions.Insert("Preview",     False);
	
	SetDefaultStructureValues(DialogParameters, DialogDefaultOptions);
	
	WarningText = NStr("ru = 'Для данной операции необходимо установить расширение для веб-клиента 1С:Предприятие.'; en = 'This action requires the file system extension for 1C:Enterprise web client.'; pl = 'Zainstaluj rozszerzenie klienta sieci web 1C:Enterprise dla tej operacji.';es_ES = 'Instalar la extensión para el cliente web de la 1C:Empresa para esta operación.';es_CO = 'Instalar la extensión para el cliente web de la 1C:Empresa para esta operación.';tr = 'Bu işlem için 1C:Enterprise web istemcisi için uzantı yükleyin.';it = 'Questa azione richiede l''estensione del file di sistema per il client web 1C:Enterprise.';de = 'Installieren Sie die Erweiterung für 1C:Enterprise Web Client für diesen Vorgang.'");
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Object",               Object);
	AdditionalParameters.Insert("PropertyName",          PropertyName);
	AdditionalParameters.Insert("DialogParameters",     DialogParameters);
	AdditionalParameters.Insert("CompletionNotification", CompletionNotification);
	
	Notification = New NotifyDescription("FileSelectionHandlerFollowUp", ThisObject, AdditionalParameters);
	
	CommonClient.ShowFileSystemExtensionInstallationQuestion(Notification, WarningText, False);
	
EndProcedure

// Handler of asynchronous file selection dialog box (continuation).
// 
Procedure FileSelectionHandlerFollowUp(Result, AdditionalParameters) Export
	
	If Result <> True Then
		Return;
	EndIf;
	
	Object      = AdditionalParameters.Object;
	PropertyName = AdditionalParameters.PropertyName;
	
	SelectionDialogParameters = AdditionalParameters.DialogParameters;
	
	Dialog = New FileDialog(SelectionDialogParameters.Mode);
	FillPropertyValues(Dialog, SelectionDialogParameters);
	
	Dialog.FullFileName = Object[PropertyName];
	
	AdditionalNotificationParameters = New Structure;
	AdditionalNotificationParameters.Insert("Object",               AdditionalParameters.Object);
	AdditionalNotificationParameters.Insert("PropertyName",          AdditionalParameters.PropertyName);
	AdditionalNotificationParameters.Insert("CompletionNotification", AdditionalParameters.CompletionNotification);
	
	Notification = New NotifyDescription("FileSelectionHandlerCompletion", ThisObject, AdditionalNotificationParameters);
	
	Dialog.Show(Notification);
	
EndProcedure

// Handler of asynchronous file selection dialog (completion).
//
Procedure FileSelectionHandlerCompletion(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles = Undefined Then
		Return;
	EndIf;
	
	Object      = AdditionalParameters.Object;
	PropertyName = AdditionalParameters.PropertyName;
	
	Result = Undefined;
	
	If SelectedFiles.Count() > 1 Then
		Result = SelectedFiles;
	Else
		Result = SelectedFiles[0];
		
		Object[PropertyName] = Result;
	EndIf;
	
	If Not AdditionalParameters.CompletionNotification = Undefined Then
		ExecuteNotifyProcessing(AdditionalParameters.CompletionNotification, Result);
	EndIf;
	
EndProcedure

// Sends file to the server interactively without extension for file operations.
//
// Parameters:
//     CompletionNotification - NotifyDescription - an export procedure that is called with the 
//                                                 following parameters:
//                                Result               - a structure with the following fields: Name, Storage, and ErrorDescription.
//                                AdditionalParameters - Undefined.
//
//     DialogParameters     - Structure                       - optional additional parameters of 
//                                                              the files selection dialog.
//     FormID   - String, UUID - this value is used for saving data to a temporary storage.
//
Procedure SelectAndSendFileToServer(CompletionNotification, Val DialogParameters = Undefined, Val FormID = Undefined) Export
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("CompletionNotification", CompletionNotification);
	AdditionalParameters.Insert("DialogParameters", DialogParameters);
	AdditionalParameters.Insert("FormID", FormID);
	
	NotificationOfAttachingFilesOperationsExtension = New NotifyDescription(
		"SelectAndSendFileToServerAfterAttachFileSystemExtension",
		ThisObject, AdditionalParameters);
	
	BeginAttachingFileSystemExtension(NotificationOfAttachingFilesOperationsExtension);

EndProcedure

// Continuation of the procedure (see above).
// 
Procedure SelectAndSendFileToServerAfterAttachFileSystemExtension(Attached, AdditionalParameters) Export
	
	Result  = New Structure("Name, Location, ErrorDescription");
	AdditionalParameters.Insert("Result", Result);
	Notification = New NotifyDescription("SelectAndSendFileToServerCompletion", ThisObject, AdditionalParameters);
	
	If Not Attached Then
		// The extension is not available; using the selection dialog from the BeginPutFile method.
		BeginPutFile(Notification, , , True, AdditionalParameters.FormID);
		Return;
	EndIf;
	
	// The extension is available, using custom file dialog to select a file.
	DialogDefaultOptions = New Structure;
	DialogDefaultOptions.Insert("CheckFileExist", True);
	DialogDefaultOptions.Insert("Title",                   NStr("ru = 'Выберите файл'; en = 'Select file'; pl = 'Wybierz plik';es_ES = 'Seleccionar un archivo';es_CO = 'Seleccionar un archivo';tr = 'Dosya seç';it = 'Selezione del file';de = 'Datei auswählen'"));
	DialogDefaultOptions.Insert("Multiselect",          False);
	DialogDefaultOptions.Insert("Preview",     False);
	
	SetDefaultStructureValues(AdditionalParameters.DialogParameters, DialogDefaultOptions);
	
	ChoiceDialog = New FileDialog(FileDialogMode.Open);
	FillPropertyValues(ChoiceDialog, AdditionalParameters.DialogParameters);
	
	ChoiceDialogNotifyDescription = New NotifyDescription("SelectAndSendFileToServerAfterChoiceInDialog", ThisObject, AdditionalParameters);
	ChoiceDialog.Show(ChoiceDialogNotifyDescription);

EndProcedure

// Handler of completing non-modal choice and transferring files to the server.
//
Procedure SelectAndSendFileToServerCompletion(Val Success, Val Address, Val SelectedFileName, Val AdditionalParameters) Export
	If Not Success Then
		Return;
	EndIf;
	
	// Notifying the caller.
	Result = AdditionalParameters.Result;
	Result.Name      = SelectedFileName;
	Result.Location = Address;
	
	ExecuteNotifyProcessing(AdditionalParameters.CompletionNotification, Result);
EndProcedure

// Continuation of the procedure (see above).
// 
Procedure SelectAndSendFileToServerAfterChoiceInDialog(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles <> Undefined
		AND SelectedFiles.Count() = 1 Then
		
		Notification = New NotifyDescription("SelectAndSendFileToServerAfterChoiceInDialogCompletion", ThisObject, AdditionalParameters);
		ListToTransfer = New Array;
		ListToTransfer.Add(New TransferableFileDescription(SelectedFiles[0]));
		
		BeginPuttingFiles(
			Notification,
			ListToTransfer,,
			False,
			AdditionalParameters.FormID);
		
	EndIf;
	
EndProcedure

// Handler of completing non-modal choice and transferring files to the server.
//
Procedure SelectAndSendFileToServerAfterChoiceInDialogCompletion(FilesThatWerePut, AdditionalParameters) Export
	
	For Index = 0 To FilesThatWerePut.UBound() Do
		Result = AdditionalParameters.Result;
		Result.Name      = FilesThatWerePut[Index].Name;
		Result.Location = FilesThatWerePut[Index].Location;
	EndDo;
	
	// Notifying the caller.
	ExecuteNotifyProcessing(AdditionalParameters.CompletionNotification, Result);
	
EndProcedure

// Starts receiving file from server interactively without extension for file operations.
//
// Parameters:
//     FileToGet - Structure - details of the file to be received. It contains the Name and Location properties.
//     DialogParameters - Structure - optional additional parameters of file selection dialog.
//
Procedure SelectAndSaveFileAtClient(Val FileToReceive, Val DialogParameters = Undefined) Export
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("FileToReceive", FileToReceive);
	AdditionalParameters.Insert("DialogParameters", DialogParameters);
	
	NotificationOfAttachingFilesOperationsExtension = New NotifyDescription(
		"SelectAndSaveFileAtClientAfterAttachFileSystemExtension",
		ThisObject, AdditionalParameters);
	
	BeginAttachingFileSystemExtension(NotificationOfAttachingFilesOperationsExtension);
	
EndProcedure

// Continuation of the procedure (see above).
// 
Procedure SelectAndSaveFileAtClientAfterAttachFileSystemExtension(Attached, AdditionalParameters) Export
	
	If Not Attached Then
		// The extension is not available, using selection dialog from the GetFile method.
		GetFile(AdditionalParameters.FileToReceive.Location, AdditionalParameters.FileToReceive.Name, True);
		Return;
	EndIf;
	
	// The extension is available, using file dialog to specify a file.
	DialogDefaultOptions = New Structure;
	DialogDefaultOptions.Insert("Title",               NStr("ru = 'Выберите файл для сохранения'; en = 'Select file to download'; pl = 'Wybierz plik, który chcesz zapisać';es_ES = 'Seleccione un archivo para guardar';es_CO = 'Seleccione un archivo para guardar';tr = 'Kaydedilecek dosyayı seçin';it = 'Seleziona file da scaricare';de = 'Wählen Sie eine Datei zum Speichern aus'"));
	DialogDefaultOptions.Insert("Multiselect",      False);
	DialogDefaultOptions.Insert("Preview", False);
	
	SetDefaultStructureValues(AdditionalParameters.DialogParameters, DialogDefaultOptions);
	
	SavingDialog = New FileDialog(FileDialogMode.Save);
	FillPropertyValues(SavingDialog, AdditionalParameters.DialogParameters);
	
	FilesToReceive = New Array;
	FilesToReceive.Add( New TransferableFileDescription(AdditionalParameters.FileToReceive.Name,
		AdditionalParameters.FileToReceive.Location) );
	
	GetFilesNotifyDescription = New NotifyDescription;
	BeginGettingFiles(GetFilesNotifyDescription, FilesToReceive, SavingDialog, True);
	
EndProcedure

// Adds fields to the target structure if they are not there.
//
// Parameters:
//     Result - Structure - a target structure.
//     DefaultValues - Structure - default values.
//
Procedure SetDefaultStructureValues(Result, Val DefaultValues)
	
	If Result = Undefined Then
		Result = New Structure;
	EndIf;
	
	For Each KeyValue In DefaultValues Do
		PropertyName = KeyValue.Key;
		If Not Result.Property(PropertyName) Then
			Result.Insert(PropertyName, KeyValue.Value);
		EndIf;
	EndDo;
	
EndProcedure

// Opens a form for writing information register by a given filter.
Procedure OpenInformationRegisterWriteFormByFilter(
												Filter,
												FillingValues,
												Val RegisterName,
												OwnerForm,
												Val FormName = "",
												FormParameters = Undefined,
												ClosingNotification = Undefined) Export
	
	Var RecordKey;
	
	EmptyRecordSet = DataExchangeServerCall.RegisterRecordSetIsEmpty(Filter, RegisterName);
	
	If Not EmptyRecordSet Then
		// Filling value type using the Type operator because other methods are not available at client.
		
		ValueType = Type("InformationRegisterRecordKey." + RegisterName);
		Parameters = New Array(1);
		Parameters[0] = Filter;
		
		RecordKey = New(ValueType, Parameters);
	EndIf;
	
	WriteParameters = New Structure;
	WriteParameters.Insert("Key",               RecordKey);
	WriteParameters.Insert("FillingValues", FillingValues);
	
	If FormParameters <> Undefined Then
		
		For Each Item In FormParameters Do
			
			WriteParameters.Insert(Item.Key, Item.Value);
			
		EndDo;
		
	EndIf;
	
	If IsBlankString(FormName) Then
		
		FullFormName = "InformationRegister.[RegisterName].RecordForm";
		FullFormName = StrReplace(FullFormName, "[RegisterName]", RegisterName);
		
	Else
		
		FullFormName = "InformationRegister.[RegisterName].Form.[FormName]";
		FullFormName = StrReplace(FullFormName, "[RegisterName]", RegisterName);
		FullFormName = StrReplace(FullFormName, "[FormName]", FormName);
		
	EndIf;
	
	// Opening the information register record form.
	If ClosingNotification <> Undefined Then
		OpenForm(FullFormName, WriteParameters, OwnerForm, , , , ClosingNotification);
	Else
		OpenForm(FullFormName, WriteParameters, OwnerForm);
	EndIf;
	
EndProcedure

// Opens the form for importing conversion and registration rules as a single file.
//
Procedure ImportDataSyncRules(Val ExchangePlanName) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("ExchangePlanName", ExchangePlanName);
	
	OpenForm("InformationRegister.DataExchangeRules.Form.ImportDataSyncRules", FormParameters,, ExchangePlanName);
	
EndProcedure

// Opens the event log filtered by export or import events for the specified exchange plan node.
// 
Procedure GoToDataEventLog(InfobaseNode, CommandExecutionParameters, ActionOnStringExchange) Export
	
	EventLogEvent = DataExchangeServerCall.EventLogMessageKeyByActionString(InfobaseNode, ActionOnStringExchange);
	
	FormParameters = New Structure;
	FormParameters.Insert("EventLogEvent", EventLogEvent);
	
	OpenForm("DataProcessor.EventLog.Form", FormParameters, CommandExecutionParameters.Source, CommandExecutionParameters.Uniqueness, CommandExecutionParameters.Window);
	
EndProcedure

// Opens the form of data exchange execution for the specified exchange plan node.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - an exchange plan node for which the form is to open.
//  Owner               - an owner form for the form that is being opened.
// 
Procedure ExecuteDataExchangeCommandProcessing(InfobaseNode, Owner,
		AccountPasswordRecoveryAddress = "", Val AutoSynchronization = Undefined, AdditionalParameters = Undefined) Export
	
	If AutoSynchronization = Undefined Then
		AutoSynchronization = (DataExchangeServerCall.DataExchangeOption(InfobaseNode) = "Synchronization");
	EndIf;
	
	WizardFormName = "";
	
	FormParameters = New Structure;
	FormParameters.Insert("InfobaseNode", InfobaseNode);
	
	If AutoSynchronization Then
		WizardFormName = "DataProcessor.DataExchangeExecution.Form";
		FormParameters.Insert("AccountPasswordRecoveryAddress", AccountPasswordRecoveryAddress);
	Else
		WizardFormName = "DataProcessor.InteractiveDataExchangeWizard.Form";
		FormParameters.Insert("AdvancedExportAdditionMode", True);
	EndIf;

	ClosingNotification = Undefined;
	
	If Not AdditionalParameters = Undefined Then
		
		If AdditionalParameters.Property("WizardParameters") Then
			For Each CurrentParameter In AdditionalParameters.WizardParameters Do
				FormParameters.Insert(CurrentParameter.Key, CurrentParameter.Value);
			EndDo;
		EndIf;
		
		AdditionalParameters.Property("ClosingNotification", ClosingNotification);
		
	EndIf;
	
	OpenForm(WizardFormName,
		FormParameters, Owner, InfobaseNode.UUID(), , , ClosingNotification, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Opens the form of interactive data exchange execution for the specified exchange plan node.
//
// Parameters:
//  InfobaseNode  - ExchangePlanRef - an exchange plan node for which the form is to open.
//  Owner                - an owner form for the form that is being opened.
//  AdditionalParameters - Structure - a structure of additional opening parameters of the wizard.
//    * WizardsParameters  - Structure - an arbitrary structure to be passed to the wizard form that is being opened.
//    * ClosingNotification - NotifyDescription - description of a notification to be called upon closing the wizard form.
//
Procedure OpenObjectsMappingWizardCommandProcessing(InfobaseNode,
		Owner, AdditionalParameters = Undefined) Export
	
	// Opening the object mapping wizard form.
	// Setting the infobase node as a form parameter.
	FormParameters = New Structure("InfobaseNode", InfobaseNode);
	FormParameters.Insert("AdvancedExportAdditionMode", True);
	
	ClosingNotification = Undefined;
	
	If Not AdditionalParameters = Undefined Then
		
		If AdditionalParameters.Property("WizardParameters") Then
			For Each CurrentParameter In AdditionalParameters.WizardParameters Do
				FormParameters.Insert(CurrentParameter.Key, CurrentParameter.Value);
			EndDo;
		EndIf;
		
		AdditionalParameters.Property("ClosingNotification", ClosingNotification);
		
	EndIf;
	
	OpenForm("DataProcessor.InteractiveDataExchangeWizard.Form",
		FormParameters, Owner, InfobaseNode.UUID(), , , ClosingNotification, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Opens the form of results of data exchange execution for the specified list of exchange plan nodes.
//
// Parameters:
//  NodesList - Array - a list of the ExchangePlanRef type values which are the exchange plan nodes 
//                         to open the form for.
//  OpeningParameters - Structure - additional parameters being passed to the OpenForm procedure:
//    * Owner      - see description of the Owner parameter of the OpenForm procedure.
//    * Uniqueness  - see description of the Uniqueness parameter of the OpenForm procedure.
//    * Window          - see description of the Window parameter of the OpenForm procedure.
//
Procedure OpenDataExchangeResults(NodesList = Undefined, OpeningParameters = Undefined) Export
	
	FormParameters = Undefined;
	Owner       = Undefined;
	Uniqueness   = Undefined;
	Window           = Undefined;
	
	If Not NodesList = Undefined Then
		FormParameters = New Structure;
		FormParameters.Insert("ExchangeNodes", NodesList);
	EndIf;
	
	If Not OpeningParameters = Undefined Then
		OpeningParameters.Property("Owner",     Owner);
		OpeningParameters.Property("Uniqueness", Uniqueness);
		OpeningParameters.Property("Window",         Window);
	EndIf;
	
	OpenForm("InformationRegister.DataExchangeResults.Form.Form", FormParameters,
		Owner, Uniqueness, Window);
	
EndProcedure

// Opens a form for setting a new data synchronization.
//
Procedure OpenNewDataSynchronizationSettingForm(NewDataSyncForm = "", AdditionalParameters = Undefined) Export
	
	If IsBlankString(NewDataSyncForm) Then
		NewDataSyncForm = "DataProcessor.DataExchangeCreationWizard.Form.NewDataSynchronization";
	EndIf;
	
	OpenForm(NewDataSyncForm, AdditionalParameters);
	
EndProcedure

// Opens the form of data exchange execution scenarios for the specified exchange plan node.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - an exchange plan node for which the form is to open.
//  Owner               - an owner form for the form that is being opened.
//
Procedure SetExchangeExecutionScheduleCommandProcessing(InfobaseNode, Owner) Export
	
	FormParameters = New Structure("InfobaseNode", InfobaseNode);
	
	OpenForm("Catalog.DataExchangeScenarios.Form.DataExchangesScheduleSetup", FormParameters, Owner);
	
EndProcedure

// Notifies all opened dynamic lists that data that is being displayed must be refreshed.
//
Procedure RefreshAllOpenDynamicLists() Export
	
	Types = DataExchangeServerCall.AllConfigurationReferenceTypes();
	
	For Each Type In Types Do
		
		NotifyChanged(Type);
		
	EndDo;
	
EndProcedure

// Opens the form of monitor for data registered for sending.
//
Procedure OpenCompositionOfDataToSend(Val InfobaseNode) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("ExchangeNode", InfobaseNode);
	FormParameters.Insert("SelectExchangeNodeProhibited", True);
	
	// Internal data that cannot be modified if processing is called from a command.
	FormParameters.Insert("NamesOfMetadataToHide", New ValueList);
	FormParameters.NamesOfMetadataToHide.Add("InformationRegister.InfobaseObjectsMaps");
	
	NotExportByRules = DataExchangeServerCall.NotExportedNodeObjectsMetadataNames(InfobaseNode);
	For Each MetadataName In NotExportByRules Do
		FormParameters.NamesOfMetadataToHide.Add(MetadataName);
	EndDo;
	
	OpenForm("DataProcessor.RegisterChangesForDataExchange.Form", FormParameters,, InfobaseNode);
EndProcedure

// Registers a handler for opening a new form right after closing the current one.
// 
Procedure OpenFormAfterClosingCurrentOne(CurrentForm, Val FormName, Val Parameters = Undefined, Val OpeningParameters = Undefined) Export
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("FormName",          FormName);
	AdditionalParameters.Insert("Parameters",         Parameters);
	AdditionalParameters.Insert("OpeningParameters", OpeningParameters);
	
	AdditionalParameters.Insert("PreviousCloseNotification",  CurrentForm.OnCloseNotifyDescription);
	
	CurrentForm.OnCloseNotifyDescription = New NotifyDescription("OpenFormAfterCurrentFormClosedHandler", ThisObject, AdditionalParameters);
EndProcedure

// Deferred opening.
Procedure OpenFormAfterCurrentFormClosedHandler(Val ClosingResult, Val AdditionalParameters) Export
	
	OpeningParameters = New Structure("Owner, Uniqueness, Window, URL, OnCloseNotifyDescription, WindowOpeningMode");
	FillPropertyValues(OpeningParameters, AdditionalParameters.OpeningParameters);
	OpenForm(AdditionalParameters.FormName, AdditionalParameters.Parameters,
		OpeningParameters.Owner, OpeningParameters.Uniqueness, OpeningParameters.Window, 
		OpeningParameters.URL, OpeningParameters.OnCloseNotifyDescription, OpeningParameters.WindowOpeningMode);
	
	If AdditionalParameters.PreviousCloseNotification <> Undefined Then
		ExecuteNotifyProcessing(AdditionalParameters.PreviousCloseNotification, ClosingResult);
	EndIf;
	
EndProcedure

// Updates database configuration.
//
Procedure InstallConfigurationUpdate(Exit = False) Export
	
	If CommonClient.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		ModuleSoftwareUpdateClient = CommonClient.CommonModule("ConfigurationUpdateClient");
		ModuleSoftwareUpdateClient.InstallConfigurationUpdate(Exit);
	Else
		OpenForm("CommonForm.AdditionalDetails", New Structure("Title,TemplateName",
		NStr("ru = 'Установка обновления'; en = 'Update setup'; pl = 'Zainstaluj aktualizację';es_ES = 'Instalar la actualización';es_CO = 'Instalar la actualización';tr = 'Güncellemeyi yükle';it = 'Aggiornamento impostazioni';de = 'Installiere Update'"), "ManualUpdateInstruction"));
	EndIf;
	
EndProcedure

// Opens the instruction for restoring or changing the password for data synchronization with a 
// standalone workstation.
//
Procedure OpenInstructionHowToChangeDataSynchronizationPassword(Val AccountPasswordRecoveryAddress) Export
	
	If IsBlankString(AccountPasswordRecoveryAddress) Then
		
		ShowMessageBox(, NStr("ru = 'Адрес инструкции для восстановления пароля учетной записи не задан.'; en = 'Address of instruction for account password recovery is not set.'; pl = 'Adres instrukcji dla odzyskiwania hasła konta nie jest podany.';es_ES = 'Dirección de instrucción para recuperar la contraseña de la cuenta no está establecida.';es_CO = 'Dirección de instrucción para recuperar la contraseña de la cuenta no está establecida.';tr = 'Hesap şifresi kurtarma talimatının adresi belirlenmedi.';it = 'L''indirizzo delle istruzioni per il recupero password dell''account non è impostato.';de = 'Die Adresse der Anweisung zur Wiederherstellung des Kontopassworts ist nicht angegeben.'"));
		
	Else
		
		CommonClient.OpenURL(AccountPasswordRecoveryAddress);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

Procedure OnCloseExchangePlanNodeSettingsForm(Form, FormAttributeName)
	
	If Not Form.CheckFilling() Then
		Return;
	EndIf;
	
	For Each FilterSetting In Form[FormAttributeName] Do
		
		If TypeOf(Form[FilterSetting.Key]) = Type("FormDataCollection") Then
			
			TabularSectionStructure = Form[FormAttributeName][FilterSetting.Key];
			
			For Each Item In TabularSectionStructure Do
				
				TabularSectionStructure[Item.Key].Clear();
				
				For Each CollectionRow In Form[FilterSetting.Key] Do
					
					TabularSectionStructure[Item.Key].Add(CollectionRow[Item.Key]);
					
				EndDo;
				
			EndDo;
			
		Else
			
			Form[FormAttributeName][FilterSetting.Key] = Form[FilterSetting.Key];
			
		EndIf;
		
	EndDo;
	
	Form.Modified = False;
	Form.Close(Form[FormAttributeName]);
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
// INTERNAL INTERFACE FOR INTERACTIVE EXPORT ADDITION
//

// Processing interactive addition dialog boxes.
//
// Parameters:
//     ExportAddition           - Structure, FormDataStructure - export settings.
//     Owner, Uniqueness, Window - parameters for opening the form window.
//
// Returns:
//     Opened form.
//
Function OpenExportAdditionFormNodeScenario(Val ExportAddition, Val Owner=Undefined, Val Uniqueness=Undefined, Val Window=Undefined) Export
	
	FormParameters = New Structure("ChoiceMode, CloseOnChoice", True, True);
	FormParameters.Insert("InfobaseNode", ExportAddition.InfobaseNode);
	FormParameters.Insert("FilterPeriod",           ExportAddition.NodeScenarioFilterPeriod);
	FormParameters.Insert("Filter",                  ExportAddition.AdditionalNodeScenarioRegistration);

	Return OpenForm(ExportAddition.AdditionScenarioParameters.AdditionalOption.FilterFormName,
		FormParameters, Owner, Uniqueness, Window);
EndFunction

// Processing interactive addition dialog boxes.
//
// Parameters:
//     ExportAddition           - Structure, FormDataStructure - export settings.
//     Owner, Uniqueness, Window - parameters for opening the form window.
//
// Returns:
//     Opened form.
//
Function OpenExportAdditionFormAllDocuments(Val ExportAddition, Val Owner=Undefined, Val Uniqueness=Undefined, Val Window=Undefined) Export
	FormParameters = New Structure;
	
	FormParameters.Insert("Title", NStr("ru='Добавление документов для отправки'; en = 'Adding documents to send.'; pl = 'Dodaj dokument do wysłania';es_ES = 'Agregar documentos para enviar';es_CO = 'Agregar documentos para enviar';tr = 'Gönderilecek belgeleri ekle';it = 'Aggiunta documenti da inviare.';de = 'Fügen Sie Dokumente zum Senden hinzu'") );
	FormParameters.Insert("ChoiceAction", 1);
	
	FormParameters.Insert("SelectPeriod", True);
	FormParameters.Insert("DataPeriod", ExportAddition.AllDocumentsFilterPeriod);
	
	FormParameters.Insert("SettingsComposerAddress", ExportAddition.AllDocumentsComposerAddress);
	
	FormParameters.Insert("FromStorageAddress", ExportAddition.FromStorageAddress);
	
	Return OpenForm("DataProcessor.InteractiveExportModification.Form.PeriodAndFilterEdit", 
		FormParameters, Owner, Uniqueness, Window);
EndFunction

// Processing interactive addition dialog boxes.
//
// Parameters:
//     ExportAddition           - Structure, FormDataStructure - export settings.
//     Owner, Uniqueness, Window - parameters for opening the form window.
//
// Returns:
//     Opened form.
//
Function OpenExportAdditionFormDetailedFilter(Val ExportAddition, Val Owner=Undefined, Val Uniqueness=Undefined, Val Window=Undefined) Export
	FormParameters = New Structure;
	
	FormParameters.Insert("ChoiceAction", 2);
	FormParameters.Insert("ObjectSettings", ExportAddition);
	
	FormParameters.Insert("OpenByScenario", True);
	Return OpenForm("DataProcessor.InteractiveExportModification.Form", 
		FormParameters, Owner, Uniqueness, Window);
EndFunction

// Processing interactive addition dialog boxes.
//
// Parameters:
//     ExportAddition           - Structure, FormDataStructure - export settings.
//     Owner, Uniqueness, Window - parameters for opening the form window.
//
// Returns:
//     Opened form.
//
Function OpenExportAdditionFormCompositionOfData(Val ExportAddition, Val Owner=Undefined, Val Uniqueness=Undefined, Val Window=Undefined) Export
	FormParameters = New Structure;
	
	FormParameters.Insert("ObjectSettings", ExportAddition);
	If ExportAddition.ExportOption=3 Then
		FormParameters.Insert("SimplifiedMode", True);
	EndIf;
	
	Return OpenForm("DataProcessor.InteractiveExportModification.Form.ExportComposition",
		FormParameters, Owner, Uniqueness, Window);
EndFunction

// Processing interactive addition dialog boxes.
//
// Parameters:
//     ExportAddition           - Structure, FormDataStructure - export settings.
//     Owner, Uniqueness, Window - parameters for opening the form window.
//
// Returns:
//     Opened form.
//
Function OpenExportAdditionFormSaveSettings(Val ExportAddition, Val Owner=Undefined, Val Uniqueness=Undefined, Val Window=Undefined) Export
	FormParameters = New Structure("CloseOnChoice, ChoiceAction", True, 3);
	
	// Composer is not passed to the form being opened.
	ExportAddition.AllDocumentsFilterComposer = Undefined;
	
	FormParameters.Insert("CurrentSettingsItemPresentation", ExportAddition.CurrentSettingsItemPresentation);
	FormParameters.Insert("Object", ExportAddition);
	
	Return OpenForm("DataProcessor.InteractiveExportModification.Form.SettingsCompositionEdit",
		FormParameters, Owner, Uniqueness, Window);
EndFunction

// Selection handler for the export addition wizard form.
// The function determines whether the source is called from the export addition and operates with the ExportAddition data.
//
// Parameters:
//     SelectedValue  - Arbitrary                    - selection result.
//     ChoiceSource     - ClientApplicationForm                - selection is made in this form.
//     ExportAddition - Structure, FormDataCollection - selection addition settings that are being changed.
//
// Returns:
//     Boolean - True if the selection is called from one of the export addition forms, otherwise it is False.
//
Function ExportAdditionChoiceProcessing(Val SelectedValue, Val ChoiceSource, ExportAddition) Export
	
	If ChoiceSource.FormName="DataProcessor.InteractiveExportModification.Form.PeriodAndFilterEdit" Then
		// Changing the "All documents" predefined filter. The effect is determined by SelectedValue.
		Return ExportAdditionStandardOptionChoiceProcessing(SelectedValue, ExportAddition);
		
	ElsIf ChoiceSource.FormName="DataProcessor.InteractiveExportModification.Form.Form" Then
		// Changing the "In detail" predefined filter. The effect is determined by SelectedValue.
		Return ExportAdditionStandardOptionChoiceProcessing(SelectedValue, ExportAddition);
		
	ElsIf ChoiceSource.FormName="DataProcessor.InteractiveExportModification.Form.SettingsCompositionEdit" Then
		// Settings whose effect is determined by SelectedValue.
		Return ExportAdditionStandardOptionChoiceProcessing(SelectedValue, ExportAddition);
		
	ElsIf ChoiceSource.FormName=ExportAddition.AdditionScenarioParameters.AdditionalOption.FilterFormName Then
		// Changing settings according to the node scenario.
		Return ExportAdditionNodeScenarioChoiceProcessing(SelectedValue, ExportAddition);
		
	EndIf;
	
	Return False;
EndFunction

Procedure FillStructureData(Form)
	
	// Saving the values entered in this application.
	SettingsStructure = Form.Context.NodeFilterStructure;
	CorrespondingAttributes = Form.AttributesNames;
	
	For Each SettingItem In SettingsStructure Do
		
		If CorrespondingAttributes.Property(SettingItem.Key) Then
			
			AttributeName = CorrespondingAttributes[SettingItem.Key];
			
		Else
			
			AttributeName = SettingItem.Key;
			
		EndIf;
		
		FormAttribute = Form[AttributeName];
		
		If TypeOf(FormAttribute) = Type("FormDataCollection") Then
			
			TableName = SettingItem.Key;
			
			Table = New Array;
			
			For Each Item In Form[AttributeName] Do
				
				TableRow = New Structure("Use, Presentation, RefUUID");
				
				FillPropertyValues(TableRow, Item);
				
				Table.Add(TableRow);
				
			EndDo;
			
			SettingsStructure.Insert(TableName, Table);
			
		Else
			
			SettingsStructure.Insert(SettingItem.Key, Form[AttributeName]);
			
		EndIf;
		
	EndDo;
	
	Form.Context.NodeFilterStructure = SettingsStructure;
	
	// Saving values entered in another application.
	SettingsStructure = Form.Context.CorrespondentInfobaseNodeFilterSetup;
	CorrespondingAttributes = Form.CorrespondentInfobaseAttributeNames;
	
	For Each SettingItem In SettingsStructure Do
		
		If CorrespondingAttributes.Property(SettingItem.Key) Then
			
			AttributeName = CorrespondingAttributes[SettingItem.Key];
			
		Else
			
			AttributeName = SettingItem.Key;
			
		EndIf;
		
		FormAttribute = Form[AttributeName];
		
		If TypeOf(FormAttribute) = Type("FormDataCollection") Then
			
			TableName = SettingItem.Key;
			
			Table = New Array;
			
			For Each Item In Form[AttributeName] Do
				
				TableRow = New Structure("Use, Presentation, RefUUID");
				
				FillPropertyValues(TableRow, Item);
				
				Table.Add(TableRow);
				
			EndDo;
			
			SettingsStructure.Insert(TableName, Table);
			
		Else
			
			SettingsStructure.Insert(SettingItem.Key, Form[AttributeName]);
			
		EndIf;
		
	EndDo;
	
	Form.Context.CorrespondentInfobaseNodeFilterSetup = SettingsStructure;
	
	Form.Context.Insert("ContextDetails", Form.ContextDetails);
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
// INTERNAL PROCEDURES AND FUNCTIONS FOR INTERACTIVE EXPORT ADDITION
//

Function ExportAdditionStandardOptionChoiceProcessing(Val SelectedValue, ExportAddition)
	
	Result = False;
	If TypeOf(SelectedValue)=Type("Structure") Then 
		
		If SelectedValue.ChoiceAction=1 Then
			// FIlter and period for all documents.
			ExportAddition.AllDocumentsFilterComposer = Undefined;
			ExportAddition.AllDocumentsComposerAddress = SelectedValue.SettingsComposerAddress;
			ExportAddition.AllDocumentsFilterPeriod      = SelectedValue.DataPeriod;
			Result = True;
			
		ElsIf SelectedValue.ChoiceAction=2 Then
			// Detailed setting.
			SelectionObject = GetFromTempStorage(SelectedValue.ObjectAddress);
			FillPropertyValues(ExportAddition, SelectionObject, , "AdditionalRegistration");
			ExportAddition.AdditionalRegistration.Clear();
			For Each Row In SelectionObject.AdditionalRegistration Do
				FillPropertyValues(ExportAddition.AdditionalRegistration.Add(), Row);
			EndDo;
			Result = True;
			
		ElsIf SelectedValue.ChoiceAction=3 Then
			// Settings are saved, saving the current name.
			ExportAddition.CurrentSettingsItemPresentation = SelectedValue.SettingPresentation;
			Result = True;
			
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

Function ExportAdditionNodeScenarioChoiceProcessing(Val SelectedValue, ExportAddition)
	If TypeOf(SelectedValue)<>Type("Structure") Then 
		Return False;
	EndIf;
	
	ExportAddition.NodeScenarioFilterPeriod        = SelectedValue.FilterPeriod;
	ExportAddition.NodeScenarioFilterPresentation = SelectedValue.FilterPresentation;
	
	ExportAddition.AdditionalNodeScenarioRegistration.Clear();
	For Each RegistrationLine In SelectedValue.Filter Do
		FillPropertyValues(ExportAddition.AdditionalNodeScenarioRegistration.Add(), RegistrationLine);
	EndDo;
	
	Return True;
EndFunction

#EndRegion