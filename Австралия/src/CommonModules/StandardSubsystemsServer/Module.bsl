#Region Public

///////////////////////////////////////////////////////////////////////////////
// Initializing session parameters.

// The call of this procedure should be placed in session module in the SessionParametersSetting 
// procedure according to the documentation.
//
// Parameters:
//  SessionParameterNames - Array, Undefined - the session parameter names for initialization.
//                                                 An array of the set IDs of session parameters 
//                                                 that should be initialized if the handler is 
//                                                 called before using uninitialized session parameters.
//                                                 Undefined if event handler is called by the system on session start.
//
// Returns:
//  Array - session parameters names whose values were successfully set.
//
Function SessionParametersSetting(SessionParameterNames) Export
	
	// Session parameters, whose initialization required retrieving the same data, must be initialized 
	// in one group . To avoid reinitialization, names of the specified session parameters are saved in 
	// the SpecifiedParameters array.
	SpecifiedParameters = New Array;
	
	If SessionParameterNames = Undefined Then
		SessionParameters.ClientParametersAtServer = New FixedMap(New Map);
		Catalogs.ExtensionsVersions.SessionParametersSetting(SessionParameterNames, SpecifiedParameters);
		
		NativeLanguagesSupportServer.SessionParametersSetting(SessionParameterNames, SpecifiedParameters);
		
		// When establishing the connections with the infobase before calling all other handlers.
		BeforeStartApplication();
		Return SpecifiedParameters;
	EndIf;
	
	If SessionParameterNames.Find("ClientParametersAtServer") <> Undefined Then
		SessionParameters.ClientParametersAtServer = New FixedMap(New Map);
		SpecifiedParameters.Add("ClientParametersAtServer");
	EndIf;
	
	If SessionParameterNames.Find("CachedDataKey") <> Undefined Then
		SessionParameters.CachedDataKey = New UUID;
		SpecifiedParameters.Add("CachedDataKey");
	EndIf;
	
	Catalogs.ExtensionsVersions.SessionParametersSetting(SessionParameterNames, SpecifiedParameters);
	NativeLanguagesSupportServer.SessionParametersSetting(SessionParameterNames, SpecifiedParameters);
	
	If SessionParameterNames.Find("Clipboard") <> Undefined Then
		SessionParameters.Clipboard = New FixedStructure(New Structure("Source, Data"));
		SpecifiedParameters.Add("Clipboard");
	EndIf;
	
	Handlers = New Map;
	SSLSubsystemsIntegration.OnAddSessionParameterSettingHandlers(Handlers);
	
	CustomHandlers = New Map;
	CommonOverridable.OnAddSessionParameterSettingHandlers(CustomHandlers);
	For Each Record In CustomHandlers Do
		Handlers.Insert(Record.Key, Record.Value);
	EndDo;
	
	ExecuteSessionParameterSettingHandlers(SessionParameterNames, Handlers, SpecifiedParameters);
	Return SpecifiedParameters;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Additional procedures and functions.

// Returns a flag that shows whether this is the base configuration.
// The basic configuration versions may have application restrictions that can be enforced using 
// this function.
// The configuration is considered basic if its name contains the term "Basic", for example, 
// "TradeManagementBasic".
//
// Returns:
//   Boolean - True if this is the basic configuration.
//
Function IsBaseConfigurationVersion() Export
	
	Return StrFind(Upper(Metadata.Name), "BASE") > 0;
	
EndFunction

// Updates metadata property caches, which speed up session startup and infobase update, especially 
// in the SaaS mode.
// They are updated before the infobase update.
//
// To be used in other libraries and configurations.
//
Procedure UpdateAllApplicationParameters() Export
	
	InformationRegisters.ApplicationParameters.UpdateAllApplicationParameters();
	
EndProcedure

// Returns the Subsystems Library version number (SL) built in the configuration.
// 
//
// Returns:
//  String - SL version, for example, "1.0.1.1".
//
Function LibraryVersion() Export
	
	Return StandardSubsystemsCached.SubsystemsDetails().ByNames["StandardSubsystems"].Version;
	
EndFunction

// Gets an infobase UUID that allows you to distinguish different instances of infobases, for 
// example, when collecting statistics or in the mechanisms of the external management of databases.
// 
// If the ID is not filled in, its value is set and returned automatically.
//
// The ID is stored in the InfobaseID constant.
// The InfobaseID constant cannot be included in the exchange plan contents in order to have the 
// same value in each infobase (in DIB node).
//
// Returns:
//  String - an infobase ID.
//
Function InfoBaseID() Export
	
	InfobaseID = Constants.InfoBaseID.Get();
	
	If IsBlankString(InfobaseID) Then
		
		InfobaseID = String(New UUID());
		Constants.InfoBaseID.Set(InfobaseID);
		
	EndIf;
	
	Return InfobaseID;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase and server cluster administration parameters.

// Returns the administration parameter saved in the infobase.
// Designed for using in the mechanisms that require the input of infobase and server cluster 
// administration parameters.
// For example, infobase connection lock.
// See also: SetAdministrationParameters.
//
// Returns:
//  Structure - contains the properties of two structures
//              ClusterAdministrationClientServer.ClusterAdministrationParameters and 
//              ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters.
//              In this case, fields containing passwords are returned empty. If administration 
//              parameters were not saved using the SetAdministrationParameters function, the 
//              automatically calculated administration parameters will be returned by default.
//
Function AdministrationParameters() Export
	
	If Common.DataSeparationEnabled()
	   AND Common.SeparatedDataUsageAvailable() Then
		
		If Not Users.IsFullUser() Then
			Raise NStr("ru ='Недостаточно прав для выполнения операции'; en = 'Insufficient rights to perform the operation.'; pl = 'Niewystarczające uprawnienia do wykonania operacji.';es_ES = 'Insuficientes derechos para realizar la operación.';es_CO = 'Insuficientes derechos para realizar la operación.';tr = 'İşlem için gerekli yetkiler yok.';it = 'Autorizzazioni insufficienti per eseguire l''operazione.';de = 'Unzureichende Rechte auf Ausführen der Operation.'");
		EndIf;
	Else
		If Not Users.IsFullUser(, True) Then
			Raise NStr("ru ='Недостаточно прав для выполнения операции'; en = 'Insufficient rights to perform the operation.'; pl = 'Niewystarczające uprawnienia do wykonania operacji.';es_ES = 'Insuficientes derechos para realizar la operación.';es_CO = 'Insuficientes derechos para realizar la operación.';tr = 'İşlem için gerekli yetkiler yok.';it = 'Autorizzazioni insufficienti per eseguire l''operazione.';de = 'Unzureichende Rechte auf Ausführen der Operation.'");
		EndIf;
	EndIf;
	
	SetPrivilegedMode(True);
	IBAdministrationParameters = Constants.IBAdministrationParameters.Get().Get();
	DefaultAdministrationParameters = DefaultAdministrationParameters();
	
	If TypeOf(IBAdministrationParameters) = Type("Structure") Then
		FillPropertyValues(DefaultAdministrationParameters, IBAdministrationParameters);
	EndIf;
	IBAdministrationParameters = DefaultAdministrationParameters;
	
	If Not Common.FileInfobase() Then
		ReadParametersFromConnectionString(IBAdministrationParameters);
	EndIf;
	
	Return IBAdministrationParameters;
	
EndFunction

// Saves the infobase and server cluster administration parameters.
// When saving, the fields that contain passwords will be cleared for security reasons.
//
// Parameters:
//  IBAdministrationParameters - Structure - see the AdministrationParameters function.
//
// Example:
//  AdministrationParameters = StandardSubsystemsServer.AdministrationParameters();
//  // Showing the administration parameters to the administrator to validate them and enter passwords.
//  // Next, executing actions related to connecting to the server cluster.
//  StandardSubsystemsServer.AdministrationParameters(AdministrationParameters).
//
Procedure SetAdministrationParameters(IBAdministrationParameters) Export
	
	IBAdministrationParameters.ClusterAdministratorPassword = "";
	IBAdministrationParameters.InfobaseAdministratorPassword = "";
	Constants.IBAdministrationParameters.Set(New ValueStorage(IBAdministrationParameters));
	
EndProcedure

// Sets presentation of the Date field in the lists containing attribute with the Date and time date content.
// For more information, see the "The "Date" field in the lists" standard.
//
// Parameters:
//   ThisObject - ClientApplicationForm - a for with a list.
//   AttributeFullName - String - a full path to the attribute of the Date type in the format: "<ListName>.<FieldName>".
//   ItemName - String - a name of the form item associated with a list attribute of the Date type.
//
// Example:
//
//	Procedure OnCreateAtServer(Cancel, StandardProcessing)
//		StandardSubsystemsServer.SetDateFieldConditionalAppearance(ThisObject).
//
Procedure SetDateFieldConditionalAppearance(ThisObject, 
	FullAttributeName = "List.Date", ItemName = "Date") Export
	
	CommonClientServer.CheckParameter("StandardSubsystemsServer.SetDateFieldConditionalAppearance",
		"ThisObject", ThisObject, Type("ClientApplicationForm"));
	
	FullNameParts = StrSplit(FullAttributeName, ".");
	
	If FullNameParts.Count() <> 2 Then 
		// Invalid value of the AttributeFullName parameter.
		// Attribute name should be in the ""<ListName>.<FieldName>""'") format.
		Return;
	EndIf;
	
	ListName = FullNameParts[0];
	AttributeList = ThisObject[ListName];
	
	If TypeOf(AttributeList) = Type("DynamicList") Then 
		// DynamicList allows to set conditional appearance using the native composer.
		// And the ItemName parameter is ignored as the dynamic list composer does not know how the list 
		// attributes will be displayed, thus the name of the dynamic list attribute is the path to the 
		// attribute, and filter and appearance values.
		ConditionalAppearance = AttributeList.ConditionalAppearance;
		AttributePath = FullNameParts[1];
		FormattedFieldName = AttributePath;
	Else 
		// Other lists, for example, TreeFormData:
		// do not have their own composer, thus the composer of the form is used.
		ConditionalAppearance = ThisObject.ConditionalAppearance;
		AttributePath = FullAttributeName;
		FormattedFieldName = ItemName;
	EndIf;
	
	If Not ValueIsFilled(ConditionalAppearance.UserSettingID) Then
		ConditionalAppearance.UserSettingID = "MainAppearance";
	EndIf;
	
	// The default presentation is "10.06.2012".
	AppearanceItem = ConditionalAppearance.Items.Add();
	AppearanceItem.Use = True;
	AppearanceItem.Presentation = NStr("ru = 'Представление даты: ""10.06.2012""'; en = 'Date presentation: ""10.06.2012""'; pl = 'Wyświetlanie daty: ""10.06.2012""';es_ES = 'Presentación de fecha: ""10.06.2012""';es_CO = 'Presentación de fecha: ""10.06.2012""';tr = 'Tarih görünümü: ""10.06.2012""';it = 'Visualizzazione data: ""10.06.2012""';de = 'Präsentation des Datums: ""10.06.2012""'");
	AppearanceItem.Appearance.SetParameterValue("Format", "DLF=D");
	
	FormattedField = AppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField(FormattedFieldName);
	
	// Current day is presented as time only: "09:46".
	AppearanceItem = ConditionalAppearance.Items.Add();
	AppearanceItem.Use = True;
	AppearanceItem.Presentation = NStr("ru = 'Представление даты сегодня: ""09:46""'; en = 'Today''s date presentation: ""09:46""'; pl = 'Dzisiejsza prezentacja daty: ""09:46""';es_ES = 'Presentación de fecha hoy: ""09:46""';es_CO = 'Presentación de fecha hoy: ""09:46""';tr = 'Bugünkü tarihin görünümü: ""09:46""';it = 'Orario della presentazione odierna: ""09:46""';de = 'Präsentation des Datums heute: ""09:46""'");
	AppearanceItem.Appearance.SetParameterValue("Format", "DF=HH:mm");
	
	FormattedField = AppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField(FormattedFieldName);
	
	FilterItem = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue  = New DataCompositionField(AttributePath);
	FilterItem.ComparisonType   = DataCompositionComparisonType.GreaterOrEqual;
	FilterItem.RightValue = New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisDay);
	
	FilterItem = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue  = New DataCompositionField(AttributePath);
	FilterItem.ComparisonType   = DataCompositionComparisonType.Less;
	FilterItem.RightValue = New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfNextDay);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Exit confirmation.

// Gets the setting to display a confirmation on application exit for the current user.
//  Designed for using in the form of personal user settings.
//  Example of using see in the common form _DemoMySettings.
// 
// Returns:
//   Boolean - If True, show the session closing confirmation window upon application exit.
//            
// 
Function AskConfirmationOnExit() Export
	Result = Common.CommonSettingsStorageLoad("UserCommonSettings", "AskConfirmationOnExit");
	
	If Result = Undefined Then
		Result = Common.CommonCoreParameters().AskConfirmationOnExit;
		Settings = New Structure("AskConfirmationOnExit", Result);
	EndIf;
	
	Return Result;
EndFunction

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use StandardSubsystemsCached.ExchangePlanDataRegistrationMode instead.
//
// Parameters:
//  Object - MetadataObject - an object to check.
// 
// Returns:
//  Boolean - True if the object is used in DIB only when creating an initial image of a subordinate node.
// 
Function IsDIBNodeInitialImageObject(Val Object) Export
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeCached = Common.CommonModule("DataExchangeCached");
		If ModuleDataExchangeCached.StandaloneModeSupported() Then
			RegistrationMode = StandardSubsystemsCached.ExchangePlanDataRegistrationMode(
				Object.FullName(), ModuleDataExchangeCached.StandaloneModeExchangePlan());
			If RegistrationMode = "AutoRecordDisabled" Then
				Return True;
			EndIf;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

// Validates the exchange plan content. Checks whether mandatory objects are included and exception 
// objects are excluded.
//
// Parameters:
//  ExchangePlanName - String, ExchangePlanRef - an exchange plan name or a reference to the 
//                                              exchange plan node to be checked.
//
Procedure ValidateExchangePlanComposition(Val ExchangePlanName) Export
	
	If TypeOf(ExchangePlanName) <> Type("String") Then
		ExchangePlanName = ExchangePlanName.Metadata().Name;
	EndIf;
	
	DistributedInfobase = Metadata.ExchangePlans[ExchangePlanName].DistributedInfoBase;
	ExchangePlanComposition = Metadata.ExchangePlans[ExchangePlanName].Content;
	
	AddToComposition = New Array;
	ExcludeFromComposition = New Array;
	DisableAutoRecording = New Array;
	
	// Retrieving the list of the mandatory objects and the objects to be excluded.
	MandatoryObjects = New Array;
	ExceptionObjects = New Array;
	InitialImageObjects = New Array;
	
	// Retrieving objects to be excluded.
	If Common.SubsystemExists("StandardSubsystems.SaaS.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.OnGetExchangePlanObjectsToExclude(ExceptionObjects,
			DistributedInfobase);
	EndIf;
	
	If DistributedInfobase Then
		
		// Retrieving initial image objects.
		InfobaseUpdateInternal.OnGetExchangePlanInitialImageObjects(InitialImageObjects);
		
		For Each Object In InitialImageObjects Do
			
			MandatoryObjects.Add(Object);
			
		EndDo;
		
	EndIf;
	
	// Validating the list of mandatory objects for the exchange plan content.
	For Each Object In MandatoryObjects Do
		
		If ExchangePlanComposition.Find(Object) = Undefined Then
			
			AddToComposition.Add(Object);
			
		EndIf;
		
	EndDo;
	
	// Validating the list of objects to be excluded from the exchange plan content.
	For Each Object In ExceptionObjects Do
		
		If ExchangePlanComposition.Find(Object) <> Undefined Then
			
			ExcludeFromComposition.Add(Object);
			
		EndIf;
		
	EndDo;
	
	// Checking the autorecord flag.
	// Auto record must be disabled for all objects of the initial image.
	For Each CompositionItem In ExchangePlanComposition Do
		
		If InitialImageObjects.Find(CompositionItem.Metadata) <> Undefined
			AND CompositionItem.AutoRecord <> AutoChangeRecord.Deny Then
			
			DisableAutoRecording.Add(CompositionItem.Metadata);
			
		EndIf;
		
	EndDo;
	
	// Generating and displaying an exception text if necessary.
	If AddToComposition.Count() <> 0
		OR ExcludeFromComposition.Count() <> 0
		OR DisableAutoRecording.Count() <> 0 Then
		
		If AddToComposition.Count() <> 0 Then
			
			ExceptionDetails1 = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'В состав плана обмена %1 должны входить следующие объекты метаданных: %2'; en = 'Exchange plan %1 must include the following metadata objects: %2.'; pl = 'W planie wymiany należy uwzględnić następujące obiekty metadanych %1: %2';es_ES = 'Los siguientes objetos de metadatos tienen que estar incluidos en el plan de intercambio %1: %2';es_CO = 'Los siguientes objetos de metadatos tienen que estar incluidos en el plan de intercambio %1: %2';tr = '%1 değişim planı şu meta veri nesnelerini içermeli: %2.';it = 'Il piano di scambio %1 deve includere i seguenti oggetti metadati: %2.';de = 'Die folgenden Metadatenobjekte sollten im Austauschplan enthalten sein %1: %2.'"),
				ExchangePlanName,
				StrConcat(MetadataObjectsPresentation(AddToComposition), ", "));
			
		EndIf;
		
		If ExcludeFromComposition.Count() <> 0 Then
			
			ExceptionDetails2 = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'В состав плана обмена %1 НЕ должны входить следующие объекты метаданных: %2'; en = 'Exchange plan %1 CANNOT include the following metadata objects: %2.'; pl = 'Następujące obiekty metadanych NIE powinny być uwzględnione w planie wymiany %1: %2';es_ES = 'Los siguientes objetos de metadatos NO tienen que estar incluidos en el plan de intercambio %1: %2';es_CO = 'Los siguientes objetos de metadatos NO tienen que estar incluidos en el plan de intercambio %1: %2';tr = '%1 değişim planı şu meta veri nesnelerini İÇEREMEZ: %2.';it = 'Il piano di scambio %1 NON DEVE includere i seguenti oggetti metadati: %2.';de = 'Die folgenden Metadatenobjekte sollten NICHT im Austauschplan enthalten sein %1: %2.'"),
				ExchangePlanName,
				StrConcat(MetadataObjectsPresentation(ExcludeFromComposition), ", "));
			
		EndIf;
		
		If DisableAutoRecording.Count() <> 0 Then
			
			ExceptionDetails3 = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'В составе плана обмена %1 не должно быть элементов с установленным флажком ""Авторегистрация"".
					|Требуется запретить авторегистрацию для следующих объектов метаданных: %2.'; 
					|en = 'Exchange plan %1 cannot contain any items with the Autostage checkbox selected.
					|Prohibit auto registration for the following metadata objects: %2.'; 
					|pl = 'Plan wymiany %1 nie może zawierać żadnych obiektów z zaznaczonym polem wyboru Automatyczna rejestracja.
					|Należy zabronić automatyczną rejestrację dla następujących obiektów metadanych: %2.';
					|es_ES = 'El plan de intercambio %1 no puede contener ningún elemento con la casilla de verificación Auto registro seleccionada.
					| Se requiere prohibir el registro automático para los siguientes objetos de metadatos: %2.';
					|es_CO = 'El plan de intercambio %1 no puede contener ningún elemento con la casilla de verificación Auto registro seleccionada.
					| Se requiere prohibir el registro automático para los siguientes objetos de metadatos: %2.';
					|tr = '%1 değişim planı, Otomatik hazırlama onay kutusu seçilmiş öğeler içeremez.
					|Şu meta veri nesneleri için otomatik kaydı engelleyin:%2.';
					|it = 'Il piano di scambio %1 non può contenere nessun elemento con la casella di controllo Autostage selezionata.
					|Vietare la registrazione automatica per i seguenti oggetti di metadati: %2.';
					|de = 'Der Austauschplan %1 darf keine Objekte mit dem aktivierten Kontrollkästchen Automatische Aufbereitung enthalten.
					| Untersagen Sie automatische Registrierung für die folgenden Metadatenobjekte: %2.'"),
				ExchangePlanName,
				StrConcat(MetadataObjectsPresentation(DisableAutoRecording), ", "));
			
		EndIf;
		
		ExceptionDetails = "[ExceptionDetails1]
		|
		|[ExceptionDetails2]
		|
		|[ExceptionDetails3]
		|";
		
		ExceptionDetails = StrReplace(ExceptionDetails, "[ExceptionDetails1]", ExceptionDetails1);
		ExceptionDetails = StrReplace(ExceptionDetails, "[ExceptionDetails2]", ExceptionDetails2);
		ExceptionDetails = StrReplace(ExceptionDetails, "[ExceptionDetails3]", ExceptionDetails3);
		
		Raise TrimAll(ExceptionDetails);
		
	EndIf;
	
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// Procedure and function for handling forms.

// Sets the bold font for form group titles so they are correctly displayed in the 8.2 interface.2.
// In the Taxi interface, group titles with standard highlight and without one are displayed in large font.
// In the 8.2 interface such titles are displayed as regular labels and are not associated with titles.
// This function is designed for visually highlighting (in bold) of group titles in the mode of the 8.2 interface.
//
// Parameters:
//  Form - ClientApplicationForm - a form where group title fonts are changed.
//  GroupsNames - String - a list of the form group names separated with commas. If the group names 
//                        are not specified, the appearance will be applied to all groups on the form.
//
// Example:
//  Procedure OnCreateAtServer(Cancel, StandardProcessing)
//    StandardSubsystemsServer.SetGroupsTitlesRepresentation(ThisObject);
//
Procedure SetGroupTitleRepresentation(Form, GroupNames = "") Export
	
	If ClientApplication.CurrentInterfaceVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		BoldFont = New Font(,, True);
		If NOT ValueIsFilled(GroupNames) Then 
			For Each Item In Form.Items Do 
				If Type(Item) = Type("FormGroup")
					AND Item.Type = FormGroupType.UsualGroup
					AND Item.ShowTitle = True 
					AND (Item.Representation = UsualGroupRepresentation.NormalSeparation
					Or Item.Representation = UsualGroupRepresentation.None) Then 
						Item.TitleFont = BoldFont;
				EndIf;
			EndDo;
		Else
			TitleArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(GroupNames,,, True);
			For Each TitleName In TitleArray Do
				Item = Form.Items[TitleName];
				If Item.Representation = UsualGroupRepresentation.NormalSeparation OR Item.Representation = UsualGroupRepresentation.None Then 
					Item.TitleFont = BoldFont;
				EndIf;
			EndDo;
		EndIf;
	EndIf;

EndProcedure

#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Additional base functionality for analyzing client parameters on the server.

// Returns a fixed map that contains the following client parameters:
//  StartParameter - String,
//  InfobaseConnectionString - String - a connection string retrieved on the client.
//
// Returns an empty fixed match if CurrentRunMode() = Undefined.
//
Function ClientParametersAtServer() Export
	
	SetPrivilegedMode(True);
	ClientParameters = SessionParameters.ClientParametersAtServer;
	SetPrivilegedMode(False);
	
	If ClientParameters.Count() = 0
	   AND CurrentRunMode() <> Undefined Then
		
		Raise NStr("ru = 'Не заполнены параметры клиента на сервере.'; en = 'The client parameters on the server are blank.'; pl = 'Parametry klienta na serwerze nie są wprowadzane.';es_ES = 'Parámetros del cliente en el servidor no introducidos.';es_CO = 'Parámetros del cliente en el servidor no introducidos.';tr = 'Sunucudaki istemci parametreleri girilmedi.';it = 'Non sono compilati i parametri del client sul server.';de = 'Client-Parameter auf dem Server werden nicht eingegeben.'");
	EndIf;
	
	Return ClientParameters;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedure for setting, upgrading, or retrieving application parameters (caches).

// Checks whether the latest version of the application is available in the current session, 
// otherwise raises an exception with the requirement to restart the session.
//
// You cannot update the parameters of the application operation in previous sessions and also 
// cannot change some data, so as not to overwrite the new version of the data (received using the 
// new version of the application) with the previous version of the data (received using the 
// previous version of the application).
//
Procedure CheckApplicationVersionDynamicUpdate() Export
	
	If ApplicationVersionUpdatedDynamically() Then
		RequireRestartDueToApplicationVersionDynamicUpdate();
	EndIf;
	
EndProcedure

// Checks whether there is the dynamic change of base configuration in the current session and there 
// is no infobase update mode.
//
// Returns:
//  Boolean - True if the application version is updated.
//
Function ApplicationVersionUpdatedDynamically() Export
	
	If Not DataBaseConfigurationChangedDynamically() Then
		Return False;
	EndIf;
	
	// In the database configuration is changed dynamically after the update of the infobase is started, 
	// but before it is completed, the update should be continued despite the change.
	// 
	
	If Common.DataSeparationEnabled() Then
		// The application operation parameters are only shared, thus their update is completed if the 
		// shared data update is completed.
		Return Not InfobaseUpdateInternal.SharedInfobaseDataUpdateRequired();
	EndIf;
	
	Return Not InfobaseUpdate.InfobaseUpdateRequired();
	
EndFunction

// Raises an exception with a recommendation to restart a session due to an update of the application version.
Procedure RequireRestartDueToApplicationVersionDynamicUpdate() Export
	
	ErrorText = NStr("ru = 'Версия программы обновлена, требуется перезапустить сеанс.'; en = 'The application version is updated. Session update is required.'; pl = 'Wersja programu została zaktualizowana, należy ponownie uruchomić sesję.';es_ES = 'La versión del programa se ha actualizado, se requiere reiniciar la sesión.';es_CO = 'La versión del programa se ha actualizado, se requiere reiniciar la sesión.';tr = 'Uygulamanın sürümü güncellendi. Oturum tekrar başlatılmalıdır.';it = 'La versione del programma è stata aggiornata, è necessario riavviare la sessione.';de = 'Die Version des Programms wurde aktualisiert und die Sitzung muss neu gestartet werden.'");
	Raise ErrorText;
	
EndProcedure

// Returns the value of the application operation parameter.
//
// In the previous session (when the program version is updated dynamically), if the parameter is 
// not found, an exception is raised with a recommendation to restart, if the parameter is found, 
// the value is returned without considering the version.
//
// In the separated SaaS mode, if the parameter is not found or the version of the parameter is not 
// equal to the version of the configuration, an exception is raised as the shared data cannot be 
// updated.
//
// Parameters:
//  ParameterName - String - cannot exceed 128 characters. Example:
//                 StandardSubsystems.ReportsOptions.ReportsWithSettings.
//
// Returns:
//  Arbitrary - Undefined is returned when the parameter is not found or the version of the 
//                 parameter is not equal to the version of the configuration in the new session.
//
Function ApplicationParameter(ParameterName) Export
	
	Return InformationRegisters.ApplicationParameters.ApplicationParameter(ParameterName);
	
EndFunction

// Sets the value of the application operation parameter.
// You have to set the privileged mode before the procedure call.
//
// Parameters:
//  ParameterName - String - cannot exceed 128 characters. Example:
//                 StandardSubsystems.ReportsOptions.ReportsWithSettings.
//
//  Value     - Arbitrary - a value that can be put in a value storage.
//
Procedure SetApplicationParameter(ParameterName, Value) Export
	
	InformationRegisters.ApplicationParameters.SetApplicationParameter(ParameterName, Value);
	
EndProcedure

// Updates the value of the application operation parameter, if it has changed.
// You have to set the privileged mode before the procedure call.
//
// Parameters:
//  ParameterName - String - cannot exceed 128 characters. Example:
//                   StandardSubsystems.ReportsOptions.ReportsWithSettings.
//
//  Value       - Arbitrary - a value that can be put in a value storage.
//
//  HasChanges - Boolean - (return value). It is set to True if a previous and a new parameter 
//                   values do not match.
//
//  PreviousValue - Arbitrary - (return value) before an update.
//
Procedure UpdateApplicationParameter(ParameterName, Value, HasChanges = False, PreviousValue = Undefined) Export
	
	InformationRegisters.ApplicationParameters.UpdateApplicationParameter(ParameterName,
		Value, HasChanges, PreviousValue);
	
EndProcedure

// Returns application parameter changes according to the current configuration version and the 
// current infobase version.
//
// Parameters:
//  ParameterName - String - cannot exceed 128 characters. Example:
//                 StandardSubsystems.ReportsOptions.ReportsWithSettings.
//
// Returns:
//  Undefined - means everything changed. Is returned in case of initial infobase or data area 
//                 filling.
//  Array - contains values of changes. If the array is empty, there are no changes.
//                 Can contain several changes, for example, when data area has not been updated for a long time.
//
Function ApplicationParameterChanges(ParameterName) Export
	
	Return InformationRegisters.ApplicationParameters.ApplicationParameterChanges(ParameterName);
	
EndFunction

// Add the changes of th application operation parameter during update to the current version of configuration metadata.
// Later changes are used for conditional adding of mandatory update handlers.
// In case of initial infobase or shared data filling, changes are not added.
//
//  ParameterName - String - cannot exceed 128 characters. Example:
//                 StandardSubsystems.ReportsOptions.ReportsWithSettings.
//
//  Changes - Arbitrary - fixed data that is registered as changes.
//                 Changes are not added if the value of ParameterChange is not filled.
//
Procedure AddApplicationParameterChanges(ParameterName, Changes) Export
	
	InformationRegisters.ApplicationParameters.AddApplicationParameterChanges(ParameterName, Changes);
	
EndProcedure

// For internal use only.
Procedure RegisterPriorityDataChangeForSubordinateDIBNodes() Export
	
	If Common.IsSubordinateDIBNode()
	 Or Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	If Not StandardSubsystemsCached.DisableMetadataObjectsIDs() Then
		Catalogs.MetadataObjectIDs.RegisterTotalChangeForSubordinateDIBNodes();
	EndIf;
	
	DIBExchangePlansNodes = New Map;
	For Each ExchangePlan In Metadata.ExchangePlans Do
		If Not ExchangePlan.DistributedInfoBase Then
			Continue;
		EndIf;
		DIBNodes = New Array;
		DIBExchangePlansNodes.Insert(ExchangePlan.Content, DIBNodes);
		ExchangePlanManager = Common.ObjectManagerByFullName(ExchangePlan.FullName());
		Selection = ExchangePlanManager.Select();
		While Selection.Next() Do
			If Selection.Ref <> ExchangePlanManager.ThisNode() Then
				DIBNodes.Add(Selection.Ref);
			EndIf;
		EndDo;
	EndDo;
	
	If DIBExchangePlansNodes.Count() > 0 Then
		RegisterPredefinedItemChanges(DIBExchangePlansNodes, Metadata.Catalogs);
		RegisterPredefinedItemChanges(DIBExchangePlansNodes, Metadata.ChartsOfCharacteristicTypes);
		RegisterPredefinedItemChanges(DIBExchangePlansNodes, Metadata.ChartsOfAccounts);
		RegisterPredefinedItemChanges(DIBExchangePlansNodes, Metadata.ChartsOfCalculationTypes);
	EndIf;
	
EndProcedure

// Creates the missing predefined items with new references (UUID) in all lists.
// For a call after disconnecting a subordinate node of the DIB from the main one, or for automatic 
// recovery of missing predefined items.
//
Procedure RestorePredefinedItems() Export
	
	If ExchangePlans.MasterNode() <> Undefined Then
		Raise NStr("ru = 'Восстановление предопределенных элементов следует выполнять только в главном узле РИБ.
			|Затем выполнить синхронизацию с подчиненными узлами.'; 
			|en = 'Restore the predefined items in the master node of the distributed infobase.
			|Then synchronize the other nodes with the master node.'; 
			|pl = 'Przywróć predefiniowane elementy w węźle głównym dystrybucji bazy informacyjnej.
			|Następnie zsynchronizuj pozostałe węzły z węzłem głównym.';
			|es_ES = 'Hay que restablecer los elementos predeterminados solo en el nodo principal de la base de información distribuida.
			|Al sincronizar con los nodos principales.';
			|es_CO = 'Hay que restablecer los elementos predeterminados solo en el nodo principal de la base de información distribuida.
			|Al sincronizar con los nodos principales.';
			|tr = 'Önceden tanımlanmış öğeler sadece RIB ana ünitesinde yenilenmelidir. 
			| Sonra alt üniteler ile senkronizasyon yapılmalıdır.';
			|it = 'Il ripristino degli elementi di default dovrebbe essere effettuato solo nel nodo principale del database informatico distribuito.
			|Dopo di chè effettuare una sincronizzazione con i nodi subordinati.';
			|de = 'Das Wiederherstellen vordefinierter Elemente sollte nur am Hauptknoten der verteilten Informationsbasis durchgeführt werden.
			|Dann mit den Slave-Knoten synchronisieren.'");
	EndIf;
	
	BeginTransaction();
	Try
		SetAllPredefinedDataInitialization();
		SetInfoBasePredefinedDataUpdate(PredefinedDataUpdate.Auto);
		CreateMissingPredefinedData();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure	

////////////////////////////////////////////////////////////////////////////////
// Procedure to set or get extension parameters (caches).

// Returns the parameter values for the current extension version.
// Returns Undefined if no storage is set.
//
// Parameters:
//  ParameterName - String - cannot exceed 128 characters. Example:
//                 StandardSubsystems.ReportsOptions.ReportsWithSettings.
//
// Returns:
//  Arbitrary - Undefined is returned if the parameter is not filled for current the extension 
//                 version.
//
Function ExtensionParameter(ParameterName, IgnoreExtensionsVersion = False) Export
	
	Return InformationRegisters.ExtensionVersionParameters.ExtensionParameter(ParameterName, IgnoreExtensionsVersion);
	
EndFunction

// Sets parameter value storage for the current extension version.
// Used to fill parameter values.
// You have to set the privileged mode before the procedure call.
//
// Parameters:
//  ParameterName - String - cannot exceed 128 characters. Example:
//                 StandardSubsystems.ReportsOptions.ReportsWithSettings.
//
//  Value - Arbitrary - a parameter value.
//
Procedure SetExtensionParameter(ParameterName, Value, IgnoreExtensionsVersion = False) Export
	
	InformationRegisters.ExtensionVersionParameters.SetExtensionParameter(ParameterName, Value, IgnoreExtensionsVersion);
	
EndProcedure

// DeleteObsoleteExtensionsVersionsParameters scheduled job handler.
Procedure DeleteObsoleteExtensionsVersionsParametersJobHandler() Export
	
	Common.OnStartExecuteScheduledJob(
		Metadata.ScheduledJobs.DeleteObsoleteExtensionsVersionsParameters);
	
	Catalogs.ExtensionsVersions.DeleteObsoleteParametersVersions();
	
EndProcedure

// For internal use only.
Procedure FillAllExtensionParametersBackgroundJob(Parameters) Export
	
	InformationRegisters.ExtensionVersionParameters.FillAllExtensionParametersBackgroundJob(Parameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Initial filling of items with data.

Procedure FillItemsWithInitialData(UpdateMultilanguageStrings = False) Export
	
	ObjectsWithInitialFilling = ObjectsWithInitialFilling();
	Languages = ConfigurationLanguages();
	AttributesToLocalize = New Map;
	
	For Each ObjectMetadata In ObjectsWithInitialFilling Do
		
		ObjectAttributesToLocalize = NativeLanguagesSupportServer.ObjectAttributesToLocalizeDescriptions(ObjectMetadata);
		
		MultilanguageStringsInAttributes = NativeLanguagesSupportServer.MultilanguageStringsInAttributes(ObjectMetadata);
		
		ObjectManager = Common.ObjectManagerByFullName(ObjectMetadata.FullName());
		PredefinedData = PredefinedObjectData(ObjectMetadata, ObjectManager, ObjectAttributesToLocalize);
		PredefinedItemsSettings = PredefinedItemsSettings(ObjectManager, PredefinedData);
		
		ExceptionAttributes = ?(StrStartsWith(ObjectMetadata.FullName(), "ChartOfCharacteristicTypes"), "ValueType", "");
		HierarchySupported =  PredefinedData.Columns.Find("IsFolder") <> Undefined;
		
		BeginTransaction();
		Try
			
			For Each TableRow In PredefinedData Do
				
				If ValueIsFilled(TableRow.PredefinedDataName) Then
					
					ObjectRef = ObjectManager[TableRow.PredefinedDataName];
					
					DataLock = New DataLock;
					DataLockItem = DataLock.Add(ObjectMetadata.FullName());
					DataLockItem.SetValue("Ref", ObjectRef);
					DataLock.Lock();
					
					ItemToFill = ObjectRef.GetObject();
					
				ElsIf Not UpdateMultilanguageStrings Then
					If HierarchySupported AND TableRow.IsFolder = True Then
						ItemToFill = ObjectManager.CreateFolder();
					Else
						ItemToFill = ObjectManager.CreateItem();
					EndIf;
				Else
					Continue;
				EndIf;
				
				If Not UpdateMultilanguageStrings Then
					FillPropertyValues(ItemToFill, TableRow,, ExceptionAttributes);
				EndIf;
				
				If ObjectAttributesToLocalize.Count() > 0 Then
					If MultilanguageStringsInAttributes Then
						
						LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
						If ValueIsFilled(LanguageCode) Then
							For Each NameOfAttributeToLocalize In ObjectAttributesToLocalize Do
								ItemToFill[NameOfAttributeToLocalize.Key] = TableRow[NameOfAttributeToLocalize.Key + "_" + LanguageCode];
							EndDo;
						EndIf;
						
						LanguageCode = NativeLanguagesSupportServer.FirstAdditionalInfobaseLanguageCode();
						If ValueIsFilled(LanguageCode) Then
							For Each NameOfAttributeToLocalize In ObjectAttributesToLocalize Do
								ItemToFill[NameOfAttributeToLocalize.Key + "Language1"] = TableRow[NameOfAttributeToLocalize.Key + "_" + LanguageCode];
							EndDo;
						EndIf;
						
						LanguageCode = NativeLanguagesSupportServer.SecondAdditionalInfobaseLanguageCode();
						If ValueIsFilled(LanguageCode) Then
							For Each NameOfAttributeToLocalize In ObjectAttributesToLocalize Do
								ItemToFill[NameOfAttributeToLocalize.Key + "Language2"] = TableRow[NameOfAttributeToLocalize.Key + "_" + LanguageCode];
							EndDo;
						EndIf;
						
						LanguageCode = NativeLanguagesSupportServer.ThirdAdditionalInfobaseLanguageCode();
						If ValueIsFilled(LanguageCode) Then
							For Each NameOfAttributeToLocalize In ObjectAttributesToLocalize Do
								ItemToFill[NameOfAttributeToLocalize.Key + "Language3"] = TableRow[NameOfAttributeToLocalize.Key + "_" + LanguageCode];
							EndDo;
						EndIf;
						
						LanguageCode = NativeLanguagesSupportServer.FourthAdditionalInfobaseLanguageCode();
						If ValueIsFilled(LanguageCode) Then
							For Each NameOfAttributeToLocalize In ObjectAttributesToLocalize Do
								ItemToFill[NameOfAttributeToLocalize.Key + "Language4"] = TableRow[NameOfAttributeToLocalize.Key + "_" + LanguageCode];
							EndDo;
						EndIf;
						
					Else
						
						For each LanguageCode In Languages Do
							NewPresentation = ItemToFill.Presentations.Add();
							NewPresentation.LanguageCode = LanguageCode;
							For Each NameOfAttributeToLocalize In ObjectAttributesToLocalize Do
								Value = TableRow[NameOfAttributeToLocalize.Key + "_" + LanguageCode];
								NewPresentation[NameOfAttributeToLocalize.Key] = ?(ValueIsFilled(Value), Value, TableRow[NameOfAttributeToLocalize.Key]);
							EndDo;
						EndDo;
						
					EndIf;
				EndIf;
				
				If Not UpdateMultilanguageStrings AND PredefinedItemsSettings.OnInitialItemFilling Then
					ObjectManager.OnInitialItemFilling(ItemToFill, TableRow, PredefinedItemsSettings.AdditionalParameters);
				EndIf;
				
				InfobaseUpdate.WriteObject(ItemToFill);
				
				TableRow.Ref = ItemToFill.Ref;
				
			EndDo;
			
			CommitTransaction();
			
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
	EndDo;
	
EndProcedure

// Registration for the deferred handler.
//
Procedure RegisterPredefinedItemsToUpdate(Parameters) Export
	
	ObjectsWithPredefinedItems = ObjectsWithInitialFilling();
	ObjectsToProcess = New Array;
	
	Language1 = NativeLanguagesSupportServer.FirstAdditionalInfobaseLanguageCode();
	Language2 = NativeLanguagesSupportServer.SecondAdditionalInfobaseLanguageCode();
	Language3 = NativeLanguagesSupportServer.ThirdAdditionalInfobaseLanguageCode();
	Language4 = NativeLanguagesSupportServer.FourthAdditionalInfobaseLanguageCode();
	MainLanguage = CommonClientServer.DefaultLanguageCode();
	
	QueryTemplate = "SELECT
		|	Table.Ref AS Ref,
		|	Table.PredefinedDataName AS PredefinedDataName,
		|	%1
		|FROM
		|	%2 AS Table
		|WHERE
		|	Table.Predefined = TRUE";
	
	For Each MetadataObject In ObjectsWithPredefinedItems Do
		
		ObjectAttributesToLocalize = NativeLanguagesSupportServer.ObjectAttributesToLocalizeDescriptions(MetadataObject);
		If ObjectAttributesToLocalize.Count() = 0 Then
			Continue;
		EndIf;
		
		NameObjectAttribute = New Array;
		For Each ObjectAttribute In ObjectAttributesToLocalize Do
			
			AttributeName = "Table." + ObjectAttribute.Key;
			NameObjectAttribute.Add(AttributeName);
			
			If ValueIsFilled(Language1) Then
				NameObjectAttribute.Add(AttributeName + "Language1");
			EndIf;
			If ValueIsFilled(Language2) Then
				NameObjectAttribute.Add(AttributeName + "Language2");
			EndIf;
			If ValueIsFilled(Language3) Then
				NameObjectAttribute.Add(AttributeName + "Language3");
			EndIf;
			If ValueIsFilled(Language4) Then
				NameObjectAttribute.Add(AttributeName + "Language4");
			EndIf;
			
		EndDo;
		
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(QueryTemplate, StrConcat(NameObjectAttribute, ", " + Chars.LF), MetadataObject.FullName());
		Query = New Query(QueryText);
	
		QueryResult = Query.Execute();
		If QueryResult.IsEmpty() Then
			Continue;
		EndIf;
		
		ObjectManager = Common.ObjectManagerByFullName(MetadataObject.FullName());
		PredefinedData = PredefinedObjectData(MetadataObject, ObjectManager, ObjectAttributesToLocalize);
		PredefinedItemsSettings = PredefinedItemsSettings(ObjectManager, PredefinedData);
		
		QueryData = QueryResult.Select();
		While QueryData.Next() Do
			Item = PredefinedData.Find(QueryData.PredefinedDataName, "PredefinedDataName");
			If Item <> Undefined Then
				For Each AttributeDetails In ObjectAttributesToLocalize Do
					AttributeName = AttributeDetails.Key;
					
					If StrCompare(Item[NativeLanguagesSupportServer.NameOfAttributeToLocalize(AttributeName, MainLanguage)], QueryData[AttributeName]) <> 0 Then
						ObjectsToProcess.Add(QueryData.Ref);
						Continue;
					EndIf;
						
					If ValueIsFilled(Language1)
						AND StrCompare(Item[NativeLanguagesSupportServer.NameOfAttributeToLocalize(AttributeName, Language1)], QueryData[AttributeName + "Language1"]) <> 0 Then
							ObjectsToProcess.Add(QueryData.Ref);
							Continue;
					EndIf;
					
					If ValueIsFilled(Language2)
						AND StrCompare(Item[NativeLanguagesSupportServer.NameOfAttributeToLocalize(AttributeName, Language2)], QueryData[AttributeName + "Language2"]) <> 0 Then
							ObjectsToProcess.Add(QueryData.Ref);
					EndIf;
					
				EndDo;
			EndIf;
		EndDo;
		
	EndDo;
	
	If ObjectsToProcess.Count() > 0 Then
		InfobaseUpdate.MarkForProcessing(Parameters, ObjectsToProcess);
	EndIf;
	
EndProcedure

Procedure UpdatePredefinedItemsPresentations(Parameters) Export
	
	ObjectsWithPredefinedItems = ObjectsWithInitialFilling();
	
	MetadataObject              = Undefined;
	NoObjectsToProcess = True;
	ObjectRefs                = New Array;
	
	For Each ObjectWithPredefinedItems In ObjectsWithPredefinedItems Do
		ObjectRefs = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, ObjectWithPredefinedItems.FullName());
		If ObjectRefs.Count() > 0 Then
			NoObjectsToProcess = False;
			Parameters.ProcessingCompleted  = False;
			MetadataObject = ObjectWithPredefinedItems;
			Break;
		EndIf;
	EndDo;
	
	If NoObjectsToProcess Then
		Parameters.ProcessingCompleted = True;
		Return;
	EndIf;
	
	ObjectRef = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, MetadataObject.FullName());
	
	Result = UpdatePredefinedObjectItemsPresentations(ObjectRef, MetadataObject);
	
	If Result.ObjectsProcessed = 0 AND Result.ObjectsWithIssues <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Процедуре UpdatePredefinedItemsPresentations не удалось обработать некоторые элементы (пропущены): %1'; en = 'The UpdatePredefinedItemsPresentations procedure cannot process some items (skipped): %1.'; pl = 'Procedura UpdatePredefinedItemsPresentations nie może przetworzyć kilku pozycji (pominięto): %1.';es_ES = 'El UpdatePredefinedItemsPresentations no ha podido procesar algunos artículos (saltados): %1.';es_CO = 'El UpdatePredefinedItemsPresentations no ha podido procesar algunos artículos (saltados): %1.';tr = 'The UpdatePredefinedItemsPresentations işlemi bazı nesneleri işleyemedi (atlattı): %1.';it = 'La procedura UpdatePredefinedItemsPresentations non è in grado di elaborare alcuni elementi (ignorati): %1.';de = 'Der Vorgang von UpdatePredefinedItemsPresentations kann einige Positionen nicht bearbeiten (übersprungen): %1.'"),
				Result.ObjectsWithIssues);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			MetadataObject,, StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Процедура UpdatePredefinedItemsPresentations обработала очередную порцию элементов: %1'; en = 'The UpdatePredefinedItemsPresentations procedure processed the next batch of items: %1.'; pl = 'Procedura UpdatePredefinedItemsPresentations przetworzyła następną partię pozycji: %1.';es_ES = 'El UpdatePredefinedItemsPresentations ha procesado el siguiente lote de artículos: %1.';es_CO = 'El UpdatePredefinedItemsPresentations ha procesado el siguiente lote de artículos: %1.';tr = 'The UpdatePredefinedItemsPresentations işlemi şu nesne partisini işledi: %1.';it = 'La procedura UpdatePredefinedItemsPresentations ha elaborato un ulteriore porzione di oggetti: %1.';de = 'Der Vorgang von UpdatePredefinedItemsPresentations verarbeitete die nächste Charge von Positionen: %1.'"),
					Result.ObjectsProcessed));
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Additional base functionality for data exchange .

// Records changes of the object for all exchange plan nodes.
// The separated configurations must meet the following conditions:
//  - Exchange plan should be separated.
//  - Object to be registered should be shared.
//
//  Parameters:
//    Object - Object - CatalogObject, DocumentObject, and any other object that needs to be registered.
//                              The object must be shared, otherwise an exception is raised.
//
//    ExchangePlanName - String - a name of the exchange plan where the object is registered in all nodes.
//                              The exchange plan must be shared, otherwise an exception is raised.
//
//    IncludeMasterNode - Boolean - if False, registration of the master node will not be performed 
//                         in the subordinate node.
// 
//
Procedure RecordObjectChangesInAllNodes(Val Object, Val ExchangePlanName, Val IncludeMasterNode = True) Export
	
	If Metadata.ExchangePlans[ExchangePlanName].Content.Find(Object.Metadata()) = Undefined Then
		Return;
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		
		If Common.SeparatedDataUsageAvailable() Then
			Raise NStr("ru = 'Регистрация изменений неразделенных данных в разделенном режиме.'; en = 'Registering changes of shared data in separated mode.'; pl = 'Rejestracja zmian danych, udostępnianych w trybie podziału.';es_ES = 'Registro de cambios de los datos compartidos en el modo de división.';es_CO = 'Registro de cambios de los datos compartidos en el modo de división.';tr = 'Bölünmüş modda paylaşılan verilerin kayıtlarını değiştirir.';it = 'Registrazione delle modifiche dei dati non condivisi in modalità condivisa.';de = 'Änderungen der Registrierung getrennter Daten im Split-Modus.'");
		EndIf;
		
		If Common.SubsystemExists("StandardSubsystems.SaaS") Then
			ModuleSaaS = Common.CommonModule("SaaS");
			IsSeparatedExchangePlan = ModuleSaaS.IsSeparatedMetadataObject(
				"ExchangePlan." + ExchangePlanName, ModuleSaaS.MainDataSeparator());
		Else
			IsSeparatedExchangePlan = False;
		EndIf;
		
		If Not IsSeparatedExchangePlan Then
			Raise NStr("ru = 'Регистрация изменений для неразделенных планов обмена не поддерживается.'; en = 'Registering changes of shared exchange plans is not supported.'; pl = 'Rejestracja zmian w niepodzielnych planach wymiany nie jest obsługiwana.';es_ES = 'Registro de cambios para los planes de intercambio indivisos no se admite.';es_CO = 'Registro de cambios para los planes de intercambio indivisos no se admite.';tr = 'Bölünmemiş değişim planları için değişiklik kaydı desteklenmemektedir.';it = 'La registrazione delle modifiche dei piani di scambio condivisi non è supportata.';de = 'Die Änderung der Registrierung für ungeteilte Austauschpläne wird nicht unterstützt.'");
		EndIf;
		
		If Common.SubsystemExists("StandardSubsystems.SaaS") Then
			ModuleSaaS = Common.CommonModule("SaaS");
			IsSeparatedMetadataObject = ModuleSaaS.IsSeparatedMetadataObject(
				Object.Metadata().FullName(), ModuleSaaS.MainDataSeparator());
		Else
			IsSeparatedMetadataObject = False;
		EndIf;
		
		If IsSeparatedMetadataObject Then
				Raise NStr("ru = 'Регистрация изменений для разделенных объектов не поддерживается.'; en = 'Registering changes of separated objects is not supported.'; pl = 'Rejestracja zmian dla podzielonych obiektów nie jest obsługiwana.';es_ES = 'Registro de cambios para los objetos divididos no está admitido.';es_CO = 'Registro de cambios para los objetos divididos no está admitido.';tr = 'Bölünmemiş nesneler için değişiklik kaydı desteklenmemektedir.';it = 'La registrazione delle modifiche di oggetti separati non è supportata.';de = 'Änderungen der Registrierung für geteilte Objekte werden nicht unterstützt.'");
		EndIf;
		
		QueryText =
		"SELECT
		|	ExchangePlan.Ref AS Recipient
		|FROM
		|	ExchangePlan.[ExchangePlanName] AS ExchangePlan
		|WHERE
		|	ExchangePlan.RegisterChanges
		|	AND NOT ExchangePlan.DeletionMark";
		
		QueryText = StrReplace(QueryText, "[ExchangePlanName]", ExchangePlanName);
		
		Query = New Query;
		Query.Text = QueryText;
		
		Recipients = Query.Execute().Unload().UnloadColumn("Recipient");
		
		For Each Recipient In Recipients Do
			
			Object.DataExchange.Recipients.Add(Recipient);
			
		EndDo;
		
	Else
		
		QueryText =
		"SELECT
		|	ExchangePlan.Ref AS Recipient
		|FROM
		|	ExchangePlan.[ExchangePlanName] AS ExchangePlan
		|WHERE
		|	ExchangePlan.Ref <> &ThisNode
		|	AND NOT ExchangePlan.DeletionMark";
		
		QueryText = StrReplace(QueryText, "[ExchangePlanName]", ExchangePlanName);
		
		Query = New Query;
		Query.SetParameter("ThisNode", ExchangePlans[ExchangePlanName].ThisNode());
		Query.Text = QueryText;
		
		Recipients = Query.Execute().Unload().UnloadColumn("Recipient");
		
		MasterNode = ExchangePlans.MasterNode();
		
		For Each Recipient In Recipients Do
			If Not IncludeMasterNode AND Recipient = MasterNode Then
				Continue;
			EndIf;
			Object.DataExchange.Recipients.Add(Recipient);
		EndDo;
		
	EndIf;
	
EndProcedure

// Saves the reference to master node in the MasterNode constant for recovery opportunity.
Procedure SaveMasterNode() Export
	
	MasterNodeManager = Constants.MasterNode.CreateValueManager();
	MasterNodeManager.Value = ExchangePlans.MasterNode();
	InfobaseUpdate.WriteData(MasterNodeManager);
	
EndProcedure

// Checks whether the application is running on the training platform, which has limitations (for 
// example, the OSUser property is not available).
//
Function IsTrainingPlatform() Export
	
	SetPrivilegedMode(True);
	
	CurrentUser = InfoBaseUsers.CurrentUser();
	
	Try
		OSUser = CurrentUser.OSUser;
	Except
		OSUser = Undefined;
	EndTry;
	
	Return OSUser = Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of exchange data sending and receiving in a DIB.

// Handler for the event of the same name that occurs during data exchange in a distributed infobase.
// 
//
// Parameters:
// see the OnSendDataToSlave() event handler details in the Syntax Assistant.
// 
Procedure OnSendDataToSlave(DataItem, ItemSend, Val InitialImageCreation, Val Recipient) Export
	
	If ItemSend = DataItemSend.Ignore Then
		Return;
	EndIf;
	
	// Metadata object IDs are sent in another exchange message section.
	IgnoreSendingMetadataObjectIDs(DataItem, ItemSend, InitialImageCreation);
	
	IgnoreSendingDataProcessedOnMasterDIBNodeOnInfobaseUpdate(DataItem, InitialImageCreation, Recipient);
	
	If ItemSend = DataItemSend.Ignore Then
		Return;
	EndIf;
	
	DataExchangeSubsystemExists = Common.SubsystemExists("StandardSubsystems.DataExchange");
	
	// Adding data exchange subsystem script first.
	If DataExchangeSubsystemExists Then
		ModuleDataExchangeEvents = Common.CommonModule("DataExchangeEvents");
		ModuleDataExchangeEvents.OnSendDataToRecipient(DataItem, ItemSend, InitialImageCreation, Recipient, False);
		
		If ItemSend = DataItemSend.Ignore Then
			Return;
		EndIf;
	EndIf;
	
	SSLSubsystemsIntegration.OnSendDataToSlave(DataItem, ItemSend, InitialImageCreation, Recipient);
	If ItemSend = DataItemSend.Ignore Then
		Return;
	EndIf;
	
	// Insertion of data exchange subsystem script in the SaaS model should be the last one to affect the sending logic.
	If Common.SubsystemExists("CloudTechnology.SaaS.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnSendDataToSlave(DataItem, ItemSend, InitialImageCreation, Recipient);
		
		If ItemSend = DataItemSend.Ignore Then
			Return;
		EndIf;
	EndIf;
	
	If DataExchangeSubsystemExists Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.CalculateDIBDataExportPercentage(Recipient, InitialImageCreation);
	EndIf;
	
EndProcedure

// Handler for the event of the same name that occurs during data exchange in a distributed infobase.
// 
//
// Parameters:
// see the OnReceiveDataFromSlave() event handler details in the Syntax Assistant.
// 
Procedure OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Val Sender) Export
	
	// Metadata object IDs can be changes only in the master node.
	IgnoreGettingMetadataObjectIDs(DataItem, GetItem);
	
	If GetItem = DataItemReceive.Ignore Then
		Return;
	EndIf;
	
	SSLSubsystemsIntegration.OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender);
	If GetItem = DataItemReceive.Ignore Then
		Return;
	EndIf;
	
	// Calling an overridden handler to execute the applied logic of DIB exchange.
	CommonOverridable.OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender);
	
	DataExchangeSubsystemExists = Common.SubsystemExists("StandardSubsystems.DataExchange");
	
	// Insertion of data exchange subsystem script should be the last one to affect the receiving logic.
	If DataExchangeSubsystemExists Then
		ModuleDataExchangeEvents = Common.CommonModule("DataExchangeEvents");
		ModuleDataExchangeEvents.OnReceiveDataFromSlaveInEnd(DataItem, GetItem, Sender);
	EndIf;
	
	If DataExchangeSubsystemExists Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.CalculateDIBDataImportPercentage(Sender);
	EndIf;
	
EndProcedure

// Handler for the event of the same name that occurs during data exchange in a distributed infobase.
// 
//
// Parameters:
// see the OnReceiveDataFromMaster() event handler details in the Syntax Assistant.
// The Sender parameter can be empty, for example, when getting the initial image message in SWP.
// 
Procedure OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender = Undefined) Export
	
	If GetItem = DataItemReceive.Ignore Then
		Return;
	EndIf;
	
	DataExchangeSubsystemExists = Common.SubsystemExists("StandardSubsystems.DataExchange");
	
	// Adding data exchange subsystem script first.
	If DataExchangeSubsystemExists Then
		ModuleDataExchangeEvents = Common.CommonModule("DataExchangeEvents");
		ModuleDataExchangeEvents.OnReceiveDataFromMasterInBeginning(DataItem, GetItem, SendBack, Sender);
		
		If GetItem = DataItemReceive.Ignore Then
			Return;
		EndIf;
		
	EndIf;
	
	SSLSubsystemsIntegration.OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender);
	If GetItem = DataItemReceive.Ignore Then
		Return;
	EndIf;
	
	// Calling an overridden handler to execute the applied logic of DIB exchange.
	CommonOverridable.OnReceiveDataFromMaster(Sender, DataItem, GetItem, SendBack);
	
	// Insertion of data exchange subsystem script should be the last one to affect the receiving logic.
	If DataExchangeSubsystemExists
		AND Not InitialImageCreation(DataItem) Then
		
		ModuleDataExchangeEvents = Common.CommonModule("DataExchangeEvents");
		ModuleDataExchangeEvents.OnReceiveDataFromMasterInEnd(DataItem, GetItem, Sender);
		
	EndIf;
	
	If DataExchangeSubsystemExists Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.CalculateDIBDataImportPercentage(Sender);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Additional functions for handling types.

// Returns the reference type or the record key type of the specified metadata object .
//
// Parameters:
//  MetadataObject - MetadataObject - a register or a reference object.
// 
//  Returns:
//   Type.
//
Function MetadataObjectReferenceOrMetadataObjectRecordKeyType(MetadataObject) Export
	
	If Common.IsRegister(MetadataObject) Then
		
		If Common.IsInformationRegister(MetadataObject) Then
			RegisterKind = "InformationRegister";
			
		ElsIf Common.IsAccumulationRegister(MetadataObject) Then
			RegisterKind = "AccumulationRegister";
			
		ElsIf Common.IsAccountingRegister(MetadataObject) Then
			RegisterKind = "AccountingRegister";
			
		ElsIf Common.IsCalculationRegister(MetadataObject) Then
			RegisterKind = "CalculationRegister";
		EndIf;
		Type = Type(RegisterKind + "RecordKey." + MetadataObject.Name);
	Else
		Manager = Common.ObjectManagerByFullName(MetadataObject.FullName());
		Type = TypeOf(Manager.EmptyRef());
	EndIf;
	
	Return Type;
	
EndFunction

// Returns the object type or the record set type of the specified metadata object.
//
// Parameters:
//  MetadataObject - MetadataObject - a register or a reference object.
// 
//  Returns:
//   Type.
//
Function MetadataObjectOrMetadataObjectRecordSetType(MetadataObject) Export
	
	If Common.IsRegister(MetadataObject) Then
		
		If Common.IsInformationRegister(MetadataObject) Then
			RegisterKind = "InformationRegister";
			
		ElsIf Common.IsAccumulationRegister(MetadataObject) Then
			RegisterKind = "AccumulationRegister";
			
		ElsIf Common.IsAccountingRegister(MetadataObject) Then
			RegisterKind = "AccountingRegister";
			
		ElsIf Common.IsCalculationRegister(MetadataObject) Then
			RegisterKind = "CalculationRegister";
		EndIf;
		Type = Type(RegisterKind + "RecordSet." + MetadataObject.Name);
	Else
		Manager = Common.ObjectManagerByFullName(MetadataObject.FullName());
		ObjectKind = Common.ObjectKindByType(TypeOf(Manager.EmptyRef()));
		Type = Type(ObjectKind + "Object." + MetadataObject.Name);
	EndIf;
	
	Return Type;
	
EndFunction

// Checks whether the passed object is one of the CatalogObject.MetadataObjectIDs type.
//
Function IsMetadataObjectID(Object) Export
	
	Return TypeOf(Object) = Type("CatalogObject.MetadataObjectIDs");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedure and function for handling forms.

// Sets the form purpose key (the purpose use key and the window options key).
//  If necessary, it copies the current form settings if they were not recorded for the new 
// associated key.
//
// Parameters:
//  Form - ClientApplicationForm - the OnCreateAtServer form for which a key is set.
//  Key - String - a new form assignment key.
//  SpecifySettings - Boolean - set settings saved for the current key to the new one.
//
Procedure SetFormAssignmentKey(Form, varKey, LocationKey = "", SpecifySettings = True) Export
	
	SetFormAssignmentUsageKey(Form, varKey, SpecifySettings);
	SetFormWindowOptionsSaveKey(Form, ?(LocationKey = "", varKey, LocationKey), SpecifySettings);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions.

// Returns additional details when application parameter problem occurs.
Function ApplicationRunParameterErrorClarificationForDeveloper() Export
	
	Return Chars.LF + Chars.LF 
		+ NStr("ru = 'Для разработчика: возможно требуется обновить вспомогательные данные,
					|которые влияют на работу программы. Для выполнения обновления можно:
					|- воспользоваться внешней обработкой
					|  ""Инструменты разработчика: Обновление вспомогательных данных"",
					|- либо запустить программу с параметром командной строки 1С:Предприятия 8
					|  ""/С StartInfobaseUpdate"",
					|- либо увеличить номер версии конфигурации, чтобы при очередном запуске
					|  выполнились процедуры обновления данных информационной базы.'; 
					|en = 'Note to application developer: perhaps update of auxiliary data
					|that affects application operation is required. To update the data, do one of the following:
					|- Run external data processor
					|  ""Developer tools: Update auxiliary data.""
					|- Run the application with 1C:Enterprise command-line option
					|/C StartInfobaseUpdate.
					|Increase the configuration version number to have the infobase
					|data update procedures run next time the application is started.'; 
					|pl = 'Uwaga dla dewelopera: możliwie, że należy zaktualizować dane pomocnicze
					|które wpływają na pracę programu. W celu wykonania aktualizacji można:
					|- Uruchomić zewnętrzną obróbkę danych
					|  ""Narzędzia dewoloperskie: Aktualizacja danych pomocniczych.""
					|- Uruchomić aplikację z parametrem wiersza poleceń 1C:Enterprise
					|/C StartInfobaseUpdate.
					|Zwiększ numer wersji konfiguracji, aby mieć bazę informacji
					|procedury aktualizacji danych uruchamiane przy następnym uruchomieniu aplikacji.';
					|es_ES = 'Para el desarrollador: es posible que se requiera actualizar los datos
					|que influyen en el funcionamiento del programa. Para actualizar se puede:
					|- usar un procesamiento externo
					| ""Herramientas del desarrollador: Actualización de datos adicionales"",
					|- o lanzar el programa con el parámetro de la línea de comando de 1C:Enterprise 
					| /C StartInfobaseUpdate.
					|Aumentar el número de la versión de la configuración para que al lanzar otra vez
					| se realicen los procedimientos de actualización de datos de la base de información.';
					|es_CO = 'Para el desarrollador: es posible que se requiera actualizar los datos
					|que influyen en el funcionamiento del programa. Para actualizar se puede:
					|- usar un procesamiento externo
					| ""Herramientas del desarrollador: Actualización de datos adicionales"",
					|- o lanzar el programa con el parámetro de la línea de comando de 1C:Enterprise 
					| /C StartInfobaseUpdate.
					|Aumentar el número de la versión de la configuración para que al lanzar otra vez
					| se realicen los procedimientos de actualización de datos de la base de información.';
					|tr = 'Geliştirici için: programın çalışmasını etkileyen 
					|yardımcı verileri güncelleştirmeniz gerekebilir. 
					|Güncelleme yapmak için şunları yapabilirsiniz: 
					|- ""Geliştirici Araçları: yardımcı verileri güncelle"" dış işleme kullanın, 
					| - ya da uygulamayı 1C:Enterprise 8"" /C StartInfobaseUpdate"", 
					|- ya da yapılandırma sürüm numarasını artırmak, 
					|böylece bir sonraki başlatma bilgi veritabanı veri 
					|güncelleme prosedürü çalıştırmak için.';
					|it = 'Nota per lo sviluppatore dell''applicazione: forse è necessario aggiornare
					|i dati ausiliari che influiscono sul funzionamento dell''applicazione. Per aggiornare i dati, eseguire una delle seguenti azioni:
					|- Esegui il elaboratore dati esterno
					| ""Strumenti di sviluppo: Aggiorna dati ausiliari.""
					|- Esegui l''applicazione con l''opzione della riga di comando 1C:Enterprise
					|/C StartInfobaseUpdate.
					|- Passa alla versione successiva della configurazione per avviare la procedura di aggiornamento di dati dell''infobase
					|al prossimo avvio dell''applicazione.';
					|de = 'Für den Entwickler: Es kann notwendig sein, die Hilfsdaten zu aktualisieren,
					|die den Programmablauf beeinflussen. Um das Update durchzuführen, können Sie:
					|- die externe Verarbeitung
					|""Entwickler-Werkzeuge: Update Hilfsdaten"" verwenden,
					|- oder das Programm mit dem Kommandozeilenparameter 1C:Enterprise 8
					|""/S StartInfobaseUpdate"" ausführen,
					|- oder die Nummer der Version der Konfiguration erhöhen, so dass beim nächsten Start
					|die Verfahren zum Aktualisieren der Datenbankdaten durchgeführt werden.'");
	
EndFunction

// Returns the current infobase user.
//
Function CurrentUser() Export
	
	// Determining the actual user name even if it has been changed in the current session;
	// For example, to connect to the current infobase through an external connection from this session;
	// In all other cases, getting InfobaseUsers.CurrentUser() is sufficient.
	CurrentUser = InfoBaseUsers.FindByUUID(
		InfoBaseUsers.CurrentUser().UUID);
	
	If CurrentUser = Undefined Then
		CurrentUser = InfoBaseUsers.CurrentUser();
	EndIf;
	
	Return CurrentUser;
	
EndFunction

// Transforming a string to a valid description of a value table column values replacing invalid 
// characters with the character code escaped with the underscore character.
//
// Parameters:
//  String - String - a string to be transformed.
// 
// Returns:
//  String - a string containing only admissible characters for the description of values table columns.
//
Function TransformStringToValidColumnDescription(Row) Export
	
	DisallowedCharacters = ":;!@#$%^&-~`'.,?{}[]+=*/|\ ()_""";
	Result = "";
	For Index = 1 To StrLen(Row) Do
		Char =  Mid(Row, Index, 1);
		If StrFind(DisallowedCharacters, Char) > 0 Then
			Result = Result + "_" + CharCode(Char) + "_";
		Else
			Result = Result + Char;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Transforms adapted column description with prohibited characters replaced by the character code 
// escaped with the underscore character (_) into a usual string.
//
// Parameters:
//  ColumnDescription - String - an adapted description of a column.
// 
// Returns:
//  String - a converted string.
//
Function TransformAdaptedColumnDescriptionToString(ColumnDescription) Export
	
	Result = "";
	For Index = 1 To StrLen(ColumnDescription) Do
		Char = Mid(ColumnDescription, Index, 1);
		If Char = "_" Then
			ClosingCharacterPosition = StrFind(ColumnDescription, "_", SearchDirection.FromBegin, Index + 1);
			CharCode = Mid(ColumnDescription, Index + 1, ClosingCharacterPosition - Index - 1);
			Result = Result + Char(CharCode);
			Index = ClosingCharacterPosition;
		Else
			Result = Result + Char;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Generates data required to notify open forms and dynamic lists on client on bunch object changes 
// made on a server.
//
// Parameters:
//   ModifiedObjects - AnyRef, Type, Array - contains info about the changed objects.
//                       You can pass a reference or an array of references or specify a type or an 
//                       array of types for changed objects.
//
Function PrepareFormChangeNotification(ModifiedObjects) Export
	
	Result = New Map;
	If ModifiedObjects = Undefined Then
		Return Result;
	EndIf;
	
	TypesArray = New Array;
	RefOrTypeOrArrayType = TypeOf(ModifiedObjects);
	If RefOrTypeOrArrayType = Type("Array") Then
		For Each Item In ModifiedObjects Do
			ItemType = TypeOf(Item);
			If ItemType = Type("Type") Then
				ItemType = Item;
			EndIf;
			If TypesArray.Find(ItemType) = Undefined Then
				TypesArray.Add(ItemType);
			EndIf;
		EndDo;
	Else
		TypesArray.Add(ModifiedObjects);
	EndIf;
	
	For Each ItemType In TypesArray Do
		MetadataObject = Metadata.FindByType(ItemType);
		If TypeOf(MetadataObject) <> Type("MetadataObject") Then
			Continue;
		EndIf;
		EventName = "Write_" + MetadataObject.Name;
		Try
			BlankRef = PredefinedValue(MetadataObject.FullName() + ".EmptyRef");
		Except
			BlankRef = Undefined;
		EndTry;
		Result.Insert(ItemType, New Structure("EventName,EmptyRef", EventName, BlankRef));
	EndDo;
	Return Result;
	
EndFunction

// Sets the BlankHomePage common form for a desktop with empty form content.
//
// The separated desktop in web client requires the shared desktop form content to be filled, and 
// vice versa.
//
Procedure SetBlankFormOnBlankHomePage() Export
	
	ObjectKey = "Common/HomePageSettings";
	
	CurrentSettings = SystemSettingsStorage.Load(ObjectKey);
	If CurrentSettings = Undefined Then
		CurrentSettings = New HomePageSettings;
	EndIf;
	
	CurrentFormComposition = CurrentSettings.GetForms();
	
	If CurrentFormComposition.LeftColumn.Count() = 0
	   AND CurrentFormComposition.RightColumn.Count() = 0 Then
		
		CurrentFormComposition.LeftColumn.Add("CommonForm.BlankHomePage");
		CurrentSettings.SetForms(CurrentFormComposition);
		SystemSettingsStorage.Save(ObjectKey, "", CurrentSettings);
	EndIf;
	
EndProcedure

// Checks whether documents list posting is available for the current user.
//
// Parameters:
//  DocumentsList - Array - document for checking.
//
// Returns:
//  Boolean - True if the user has the right to post at least one document.
//
Function HasRightToPost(DocumentsList) Export
	DocumentTypes = New Array;
	For Each Document In DocumentsList Do
		DocumentType = TypeOf(Document);
		If DocumentTypes.Find(DocumentType) <> Undefined Then
			Continue;
		Else
			DocumentTypes.Add(DocumentType);
		EndIf;
		If AccessRight("Posting", Metadata.FindByType(DocumentType)) Then
			Return True;
		EndIf;
	EndDo;
	Return False;
EndFunction

// Returns a home page presentation.
//
// Returns:
//   String - a home page presentation.
//
Function HomePagePresentation() Export 
	
	Return NStr("ru = 'Основной'; en = 'Main'; pl = 'Podstawowe';es_ES = 'Principal';es_CO = 'Principal';tr = 'Genel';it = 'Principale';de = 'Haupt'");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See ImportDataFromFileOverridable.OnDefineCatalogsForDataImport. 
Procedure OnDefineCatalogsForDataImport(CatalogsToImport) Export
	
	// Cannot import to the MetadataObjectIDs.
	TableRow = CatalogsToImport.Find(Metadata.Catalogs.MetadataObjectIDs.FullName(), "FullName");
	If TableRow <> Undefined Then 
		CatalogsToImport.Delete(TableRow);
	EndIf;
	
	// Cannot import to the ExtensionObjectIDs catalog.
	TableRow = CatalogsToImport.Find(Metadata.Catalogs.ExtensionObjectIDs.FullName(), "FullName");
	If TableRow <> Undefined Then 
		CatalogsToImport.Delete(TableRow);
	EndIf;
	
EndProcedure

// See BatchObjectModificationOverridable.OnDetermineObjectsWithEditableAttributes. 
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	
	Objects.Insert(Metadata.Catalogs.MetadataObjectIDs.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.ExtensionObjectIDs.FullName(), "AttributesToEditInBatchProcessing");
	
EndProcedure

// See CommonOverridable.OnAddRefsSearchExceptions. 
Procedure OnAddReferenceSearchExceptions(RefSearchExclusions) Export
	
	RefSearchExclusions.Add(Metadata.InformationRegisters.SafeDataStorage.Dimensions.Owner);
	RefSearchExclusions.Add(Metadata.InformationRegisters.SafeDataAreaDataStorage.Dimensions.Owner);
	
EndProcedure

// See CommonOverridable.OnAddClientParameters. 
Procedure OnAddClientParameters(Parameters) Export
	
	AddClientParameters(Parameters);
	
EndProcedure

// See ExportImportDataOverridable.OnFillCommonDataTypesSupportingReferenceComparisonOnImport. 
Procedure OnFillCommonDataTypesSupportingRefMappingOnExport(Types) Export
	
	Types.Add(Metadata.Catalogs.MetadataObjectIDs);
	
EndProcedure

// See ExportImportDataOverridable.OnFillTypesExcludedFromExportImport. 
Procedure OnFillTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.Constants.InfobasePublicationURL);
	Types.Add(Metadata.Constants.LocalInfobasePublishingURL);
	
	Types.Add(Metadata.Catalogs.ExtensionsVersions);
	Types.Add(Metadata.Catalogs.ExtensionObjectIDs);
	Types.Add(Metadata.InformationRegisters.ExtensionVersionObjectIDs);
	Types.Add(Metadata.InformationRegisters.ExtensionVersionParameters);
	Types.Add(Metadata.InformationRegisters.ExtensionVersionSessions);
	
EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources. 
Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	Permissions = New Array();
	
	Permissions.Add(ModuleSafeModeManager.PermissionToUseTempDirectory(True, True,
		NStr("ru = 'Для возможности работы программы.'; en = 'Basic permissions required to run the application'; pl = 'Do operacji aplikacji.';es_ES = 'Para la operación de la aplicación.';es_CO = 'Para la operación de la aplicación.';tr = 'Uygulama çalışması için.';it = 'Per la possibilità di lavoro del programma';de = 'Für die Anwendungsoperation.'")));
	Permissions.Add(ModuleSafeModeManager.PermissionToUsePrivilegedMode());
	
	PermissionRequests.Add(
		ModuleSafeModeManager.RequestToUseExternalResources(Permissions));
	
	AddRequestForPermissionToUseExtensions(PermissionRequests);
	
EndProcedure

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If ModuleToDoListServer.UserTaskDisabled("SpeedupRecommendation") Then
		Return;
	EndIf;
	
	ID = "SpeedupRecommendation";
	UserTask = ToDoList.Add();
	UserTask.ID = ID;
	UserTask.HasUserTasks      = MustShowRAMSizeRecommendations();
	UserTask.Important        = True;
	UserTask.Presentation = NStr("ru = 'Скорость работы снижена'; en = 'Application performance degraded'; pl = 'Szybkość pracy została zmniejszona';es_ES = 'Velocidad del funcionamiento ha sido disminuida';es_CO = 'Velocidad del funcionamiento ha sido disminuida';tr = 'Çalışma hızı düştü';it = 'Velocità di lavoro abbassata';de = 'Die Betriebsgeschwindigkeit wird reduziert'");
	UserTask.Form         = "DataProcessor.SpeedupRecommendation.Form.Form";
	UserTask.Owner      = NStr("ru = 'Скорость работы программы'; en = 'Application performance'; pl = 'Szybkość pracy programu';es_ES = 'Velocidad de funcionamiento del programa';es_CO = 'Velocidad de funcionamiento del programa';tr = 'Uygulama hızı';it = 'Performance dell''applicazione';de = 'Programmgeschwindigkeit'");
	
EndProcedure

// See UsersOverridable.OnDefineRolesAssignment. 
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	// ForSystemAdministratorsOnly.
	RolesAssignment.ForSystemAdministratorsOnly.Add(
		Metadata.Roles.SystemAdministrator.Name);
	
	RolesAssignment.ForSystemAdministratorsOnly.Add(
		Metadata.Roles.Administration.Name);
	
	RolesAssignment.ForSystemAdministratorsOnly.Add(
		Metadata.Roles.UpdateDataBaseConfiguration.Name);
	
	// ForSystemUsersOnly.
	RolesAssignment.ForSystemUsersOnly.Add(
		Metadata.Roles.StartThickClient.Name);
	
	RolesAssignment.ForSystemUsersOnly.Add(
		Metadata.Roles.StartExternalConnection.Name);
	
	RolesAssignment.ForSystemUsersOnly.Add(
		Metadata.Roles.StartAutomation.Name);
	
	RolesAssignment.ForSystemUsersOnly.Add(
		Metadata.Roles.AllFunctionsMode.Name);
	
	RolesAssignment.ForSystemUsersOnly.Add(
		Metadata.Roles.InteractiveOpenExtReportsAndDataProcessors.Name);
	
	// ForExternalUsersOnly.
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.BasicSSLRightsForExternalUsers.Name);
	
	// BothForUsersAndExternalUsers.
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.StartThinClient.Name);
	
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.StartWebClient.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.OutputToPrinterFileClipboard.Name);
	
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.SaveUserData.Name);
	
EndProcedure

// See JobQueueOverridable.OnReceiveTemplateList. 
Procedure OnGetTemplateList(JobTemplates) Export
	
	JobTemplates.Add(Metadata.ScheduledJobs.DeleteObsoleteExtensionsVersionsParameters.Name);
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "StandardSubsystemsServer.SetConstantDoNotUseSeparationByDataAreas";
	Handler.Priority = 99;
	Handler.SharedData = True;
	Handler.ExclusiveMode = True;
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "StandardSubsystemsServer.MarkVersionCacheRecordsObsolete";
	Handler.Priority = 99;
	Handler.SharedData = True;
	Handler.ExclusiveMode = False;
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.2.10";
	Handler.SharedData = True;
	Handler.Procedure = "StandardSubsystemsServer.UpdateInfobaseAdministrationParameters";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.4.17";
	Handler.SharedData = True;
	Handler.Procedure = "StandardSubsystemsServer.SetMasterNodeConstantValue";
	
	Handler = Handlers.Add();
	Handler.Version = "2.3.1.18";
	Handler.SharedData = True;
	Handler.Procedure = "StandardSubsystemsServer.MovePasswordsToSecureStorageSharedData";
	
	Handler = Handlers.Add();
	Handler.Version = "2.3.1.18";
	Handler.SharedData = False;
	Handler.Procedure = "StandardSubsystemsServer.MovePasswordsToSecureStorage";
	
EndProcedure

// Returns a table of available formats for saving a spreadsheet document.
//
// Returns
//  ValueTable:
//                   SpreadsheetDocumentFileType - SpreadsheetDocumentFileType - a value in the 
//                                                                                               
//                                                                                               platform that matches the format.
//                   Ref - EnumRef.ReportsSaveFormats - a reference to metadata that stores 
//                                                                                               
//                                                                                               presentation.
//                   Presentation - String - a file type presentation (filled in from enumeration).
//                                                          
//                   Extension - String - a file type for an operating system.
//                                                          
//                   Picture - Picture - a format icon.
//
Function SpreadsheetDocumentSaveFormatsSettings() Export
	
	FormatsTable = New ValueTable;
	
	FormatsTable.Columns.Add("SpreadsheetDocumentFileType", New TypeDescription("SpreadsheetDocumentFileType"));
	FormatsTable.Columns.Add("Ref", New TypeDescription("EnumRef.ReportSaveFormats"));
	FormatsTable.Columns.Add("Presentation", New TypeDescription("String"));
	FormatsTable.Columns.Add("Extension", New TypeDescription("String"));
	FormatsTable.Columns.Add("Picture", New TypeDescription("Picture"));

	// DocumentDF document (.pdf)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.PDF;
	NewFormat.Ref = Enums.ReportSaveFormats.PDF;
	NewFormat.Extension = "pdf";
	NewFormat.Picture = PictureLib.PDFFormat;
	
	// Spreadsheet document (.mxl)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.MXL;
	NewFormat.Ref = Enums.ReportSaveFormats.MXL;
	NewFormat.Extension = "mxl";
	NewFormat.Picture = PictureLib.MXLFormat;
	
	If NOT CommonClientServer.IsMobileClient() Then
		
		// Microsoft Excel Worksheet 2007 (.xlsx)
		NewFormat = FormatsTable.Add();
		NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.XLSX;
		NewFormat.Ref = Enums.ReportSaveFormats.XLSX;
		NewFormat.Extension = "xlsx";
		NewFormat.Picture = PictureLib.Excel2007Format;

		// Microsoft Excel 97-2003 worksheet (.xls)
		NewFormat = FormatsTable.Add();
		NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.XLS;
		NewFormat.Ref = Enums.ReportSaveFormats.XLS;
		NewFormat.Extension = "xls";
		NewFormat.Picture = PictureLib.ExcelFormat;

		// OpenDocument spreadsheet (.ods).
		NewFormat = FormatsTable.Add();
		NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.ODS;
		NewFormat.Ref = Enums.ReportSaveFormats.ODS;
		NewFormat.Extension = "ods";
		NewFormat.Picture = PictureLib.OpenOfficeCalcFormat;
		
		// Document 2007 document (.docx)
		NewFormat = FormatsTable.Add();
		NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.DOCX;
		NewFormat.Ref = Enums.ReportSaveFormats.DOCX;
		NewFormat.Extension = "docx";
		NewFormat.Picture = PictureLib.Word2007Format;
		
		// Web page (.html)
		NewFormat = FormatsTable.Add();
		NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.HTML5;
		NewFormat.Ref = Enums.ReportSaveFormats.HTML;
		NewFormat.Extension = "html";
		NewFormat.Picture = PictureLib.HTMLFormat;
		
		// Text document, UTF-8 (.txt).
		NewFormat = FormatsTable.Add();
		NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.TXT;
		NewFormat.Ref = Enums.ReportSaveFormats.TXT;
		NewFormat.Extension = "txt";
		NewFormat.Picture = PictureLib.TXTFormat;
		
		// Text document, ANSI (.txt).
		NewFormat = FormatsTable.Add();
		NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.ANSITXT;
		NewFormat.Ref = Enums.ReportSaveFormats.ANSITXT;
		NewFormat.Extension = "txt";
		NewFormat.Picture = PictureLib.TXTFormat;
		
	EndIf;
	
	For Each SaveFormat In FormatsTable Do
		SaveFormat.Presentation = String(SaveFormat.Ref);
	EndDo;
		
	Return FormatsTable;
	
EndFunction

#EndRegion

#Region Private

// Handler for the event of the same name that occurs during data exchange in a distributed infobase.
// 
//
// Parameters:
// see the OnSendDataToMaster() event handler details in the Syntax Assistant.
// 
Procedure OnSendDataToMaster(DataItem, ItemSend, Val Recipient)
	
	If ItemSend = DataItemSend.Ignore Then
		Return;
	EndIf;
	
	// Metadata object IDs are sent in another exchange message section.
	IgnoreSendingMetadataObjectIDs(DataItem, ItemSend);
	If ItemSend = DataItemSend.Ignore Then
		Return;
	EndIf;
	
	SSLSubsystemsIntegration.OnSendDataToMaster(DataItem, ItemSend, Recipient);
	
	// Calling an overridden handler to execute the applied logic of DIB exchange.
	CommonOverridable.OnSendDataToMaster(DataItem, ItemSend, Recipient);
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.CalculateDIBDataExportPercentage(Recipient, False);
	EndIf;
	
EndProcedure

// Returns a parameter structure required for this subsystem client script execution when the 
// application starts, that is in following event handlers:
// - BeforeStart,
// - OnStart.
//
// Important: when starting the application, do not use cache reset commands of modules that reuse 
// return values because this can lead to unpredictable errors and unneeded service calls.
// 
//
// Parameters:
//   Parameters - Structure - a parameter structure.
//
// Returns:
//   Boolean - False if further parameters filling should be aborted.
//
Function AddClientParametersOnStart(Parameters) Export
	
	IsCallBeforeStart = Parameters.RetrievedClientParameters <> Undefined;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		IsSeparatedConfiguration = ModuleSaaS.IsSeparatedConfiguration();
	Else
		IsSeparatedConfiguration = False;
	EndIf;
	
	// Mandatory parameters to continue application running.
	Parameters.Insert("DataSeparationEnabled", Common.DataSeparationEnabled());
	
	Parameters.Insert("SeparatedDataUsageAvailable", 
		Common.SeparatedDataUsageAvailable());
	
	Parameters.Insert("IsSeparatedConfiguration", IsSeparatedConfiguration);
	Parameters.Insert("HasAccessForUpdatingPlatformVersion", Users.IsFullUser(,True));
	
	Parameters.Insert("SubsystemNames", StandardSubsystemsCached.SubsystemNames());
	Parameters.Insert("IsBaseConfigurationVersion", IsBaseConfigurationVersion());
	Parameters.Insert("IsTrainingPlatform", IsTrainingPlatform());
	Parameters.Insert("UserCurrentName", CurrentUser().Name);
	Parameters.Insert("COMConnectorName", CommonClientServer.COMConnectorName());
	Parameters.Insert("DefaultLanguageCode", Metadata.DefaultLanguage.LanguageCode);
	
	Parameters.Insert("AskConfirmationOnExit", AskConfirmationOnExit());
	
	CommonParameters = Common.CommonCoreParameters();
	
	Parameters.Insert("MinPlatformVersion",   CommonParameters.MinPlatformVersion);
	Parameters.Insert("RecommendedPlatformVersion", CommonParameters.RecommendedPlatformVersion);
	// Obsolete. For backward compatibility.
	Parameters.Insert("MinPlatformVersion", CommonParameters.MinPlatformVersion);
	Parameters.Insert("MustExit",            CommonParameters.MustExit);
	
	Parameters.Insert("RecommendedRAM", CommonParameters.RecommendedRAM);
	Parameters.Insert("MustShowRAMSizeRecommendations", MustShowRAMSizeRecommendations()
		AND Not Common.SubsystemExists("StandardSubsystems.ToDoList"));
	
	Parameters.Insert("IsExternalUserSession", UsersClientServer.IsExternalUserSession());
	Parameters.Insert("FileInfobase",   Common.FileInfobase());
	
	If IsCallBeforeStart
	   AND Not Parameters.RetrievedClientParameters.Property("InterfaceOptions") Then
		
		Parameters.Insert("InterfaceOptions", CommonCached.InterfaceOptions());
	EndIf;
	
	If IsCallBeforeStart Then
		ErrorInsufficientRightsForAuthorization = UsersInternal.ErrorInsufficientRightsForAuthorization(
			Not Parameters.RetrievedClientParameters.Property("ErrorInsufficientRightsForAuthorization"));
		
		If ValueIsFilled(ErrorInsufficientRightsForAuthorization) Then
			Parameters.Insert("ErrorInsufficientRightsForAuthorization", ErrorInsufficientRightsForAuthorization);
			Return False;
		EndIf;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleScheduledJobsInternal = Common.CommonModule("ScheduledJobsInternal");
		// Only administrators can see this form.
		ShowDataLockForm = ModuleScheduledJobsInternal.ExternalResourceUsageLockSet(
			IsCallBeforeStart, True) AND Users.IsFullUser();
		Parameters.Insert("ShowExternalResourceLockForm", ShowDataLockForm);
		If ScheduledJobsServer.OperationsWithExternalResourcesLocked() Then
			Parameters.Insert("OperationsWithExternalResourcesLocked");
		EndIf;
	EndIf;
	
	If Not InfobaseUpdateInternal.AddClientParametersOnStart(Parameters)
	   AND IsCallBeforeStart Then
		Return False;
	EndIf;
	
	If IsCallBeforeStart
	   AND Not Parameters.RetrievedClientParameters.Property("ShowDeprecatedPlatformVersion")
	   AND ShowDeprecatedPlatformVersion(Parameters) Then
		
		Parameters.Insert("ShowDeprecatedPlatformVersion");
		StandardSubsystemsServerCall.HideDesktopOnStart();
		Return False;
	EndIf;
	
	SetPrivilegedMode(True);
	If IsCallBeforeStart
	   AND Not Parameters.RetrievedClientParameters.Property("ReconnectMasterNode")
	   AND Not Common.DataSeparationEnabled()
	   AND ExchangePlans.MasterNode() = Undefined
	   AND ValueIsFilled(Constants.MasterNode.Get()) Then
		
		SetPrivilegedMode(False);
		Parameters.Insert("ReconnectMasterNode", Users.IsFullUser(, True, False));
		StandardSubsystemsServerCall.HideDesktopOnStart();
		Return False;
	EndIf;
	SetPrivilegedMode(False);
	
	If IsCallBeforeStart
	   AND NOT (Parameters.DataSeparationEnabled AND Not Parameters.SeparatedDataUsageAvailable)
	   AND Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		
		ModuleSaaS = Common.CommonModule("SaaS");
		ErrorDescription = "";
		ModuleSaaS.LockDataAreaOnStartOnCheck(ErrorDescription);
		If ValueIsFilled(ErrorDescription) Then
			Parameters.Insert("DataAreaLocked", ErrorDescription);
			// Application will be closed.
			Return False;
		EndIf;
	EndIf;
	
	If Not Parameters.DataSeparationEnabled
		AND InfobaseUpdate.InfobaseUpdateRequired()
		AND InfobaseUpdateInternal.UncompletedHandlersStatus(True) = "UncompletedStatus" Then
		Parameters.Insert("MustRunDeferredUpdateHandlers");
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
		ModuleSafeModeManagerInternal.OnAddClientParametersOnStart(Parameters, True);
	EndIf;
	
	If IsCallBeforeStart
	   AND NOT Parameters.RetrievedClientParameters.Property("RetryDataExchangeMessageImportBeforeStart")
	   AND Common.IsSubordinateDIBNode()
	   AND Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		
		ModuleDataExchangeServerCall = Common.CommonModule("DataExchangeServerCall");
		If ModuleDataExchangeServerCall.RetryDataExchangeMessageImportBeforeStart() Then
			Parameters.Insert("RetryDataExchangeMessageImportBeforeStart");
			Return False;
		EndIf;
	EndIf;
	
	// Checking whether preliminary application parameter update is required.
	If IsCallBeforeStart
	   AND NOT Parameters.RetrievedClientParameters.Property("ApplicationParametersUpdateRequired") Then
		
		If InformationRegisters.ApplicationParameters.UpdateRequired() Then
			// Preliminary update will be executed.
			Parameters.Insert("ApplicationParametersUpdateRequired");
			Return False;
		EndIf;
	EndIf;
	
	// Mandatory parameters for all modes.
	Parameters.Insert("DetailedInformation", Metadata.DetailedInformation);
	
	If InfobaseUpdateInternal.SharedInfobaseDataUpdateRequired() Then
		Parameters.Insert("SharedInfobaseDataUpdateRequired");
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
		ModuleSafeModeManagerInternal.OnAddClientParametersOnStart(Parameters);
	EndIf;
	
	If Parameters.DataSeparationEnabled AND Not Parameters.SeparatedDataUsageAvailable Then
		Return False;
	EndIf;
	
	// Parameters for running the application in the local mode or in the session with separator values 
	// set in the SaaS mode.
	
	If InfobaseUpdate.InfobaseUpdateRequired() Then
		Parameters.Insert("InfobaseUpdateRequired");
		StandardSubsystemsServerCall.HideDesktopOnStart();
	EndIf;
	
	If Not Parameters.DataSeparationEnabled
		AND Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		If ModuleDataExchangeServer.LoadDataExchangeMessage() Then
			Parameters.Insert("LoadDataExchangeMessage");
		EndIf;
	EndIf;
	
	If Common.SubsystemExists("CloudTechnology.SaaS.DataExchangeSaaS") Then
		ModuleStandaloneMode = Common.CommonModule("StandaloneMode");
		If ModuleStandaloneMode.ContinueSettingUpStandaloneWorkstation(Parameters) Then
			Return False;
		EndIf;
	EndIf;
	
	Cancel = False;
	If IsCallBeforeStart Then
		UsersInternal.OnAddClientParametersOnStart(Parameters, Cancel, True);
	EndIf;
	If Cancel Then
		Return False;
	EndIf;
	
	AddCommonClientParameters(Parameters);
	
	If IsCallBeforeStart
	   AND Parameters.Property("InfobaseUpdateRequired") Then
		// Do not add other parameters before the infobase update is complete, as they can expect that the 
		// data is updated.
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Fills a structure parameters required for client script execution when starting the application 
// and later.
//
// Parameters:
//   Parameters - Structure - a parameter structure.
//
Procedure AddCommonClientParameters(Parameters)
	
	If Not Parameters.DataSeparationEnabled Or Parameters.SeparatedDataUsageAvailable Then
		
		SetPrivilegedMode(True);
		Parameters.Insert("AuthorizedUser", Users.AuthorizedUser());
		Parameters.Insert("ApplicationCaption", TrimAll(Constants.SystemTitle.Get()));
		SetPrivilegedMode(False);
		
	EndIf;
	
	Parameters.Insert("IsMasterNode", NOT Common.IsSubordinateDIBNode());
	
	Parameters.Insert("DIBNodeConfigurationUpdateRequired",
		Common.SubordinateDIBNodeConfigurationUpdateRequired());
	
EndProcedure

// Returns the version numbers supported by the InterfaceName application interface.
// See Common.GetInterfaceVersionsViaExternalConnection. 
//
// Parameters:
//   InterfaceName - String - an application interface name.
//
// Returns:
//  Array - a list of versions of the String type.
//
Function SupportedVersions(InterfaceName) Export
	
	VersionsArray = Undefined;
	SupportedVersionStructure = New Structure;
	
	SSLSubsystemsIntegration.OnDefineSupportedInterfaceVersions(SupportedVersionStructure);
	SupportedVersionStructure.Property(InterfaceName, VersionsArray);
	
	If VersionsArray = Undefined Then
		Return Common.ValueToXMLString(New Array);
	Else
		Return Common.ValueToXMLString(VersionsArray);
	EndIf;
	
EndFunction

// Sets the BlankHomePage common form on the desktop.
Procedure SetBlankFormOnHomePage() Export
	
	ObjectKey = "Common/HomePageSettings";
	CurrentSettings = SystemSettingsStorage.Load(ObjectKey);
	
	If TypeOf(CurrentSettings) = Type("HomePageSettings") Then
		CurrentFormComposition = CurrentSettings.GetForms();
		If CurrentFormComposition.RightColumn.Count() = 0
		   AND CurrentFormComposition.LeftColumn.Count() = 1
		   AND CurrentFormComposition.LeftColumn[0] = "CommonForm.BlankHomePage" Then
			Return;
		EndIf;
	EndIf;
	
	FormComposition = New HomePageForms;
	FormComposition.LeftColumn.Add("CommonForm.BlankHomePage");
	Settings = New HomePageSettings;
	Settings.SetForms(FormComposition);
	SystemSettingsStorage.Save(ObjectKey, "", Settings);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

// Sets the correct value of the DontUseSeparationByDataAreas constant.
//
Procedure SetConstantDoNotUseSeparationByDataAreas(Parameters) Export
	
	SetPrivilegedMode(True);
	
	NewValues = New Map;
	
	If Constants.UseSeparationByDataAreas.Get() Then
		
		NewValues.Insert("DoNotUseSeparationByDataAreas", False);
		NewValues.Insert("IsStandaloneWorkplace", False)
		
	ElsIf Constants.IsStandaloneWorkplace.Get() Then
		
		NewValues.Insert("DoNotUseSeparationByDataAreas", False);
		
	Else
		
		NewValues.Insert("DoNotUseSeparationByDataAreas", True);
		
	EndIf;
	
	For Each KeyAndValues In NewValues Do
		
		If Constants[KeyAndValues.Key].Get() <> KeyAndValues.Value Then
			
			If NOT Parameters.ExclusiveMode Then
				Parameters.ExclusiveMode = True;
				Return; // Must be changed
			EndIf;
			
			Constants[KeyAndValues.Key].Set(KeyAndValues.Value);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Clears update date for each version cache record, so all version cache records become out-of-date.
// 
//
Procedure MarkVersionCacheRecordsObsolete() Export
	
	BeginTransaction();
	Try
		RecordSet = InformationRegisters.ProgramInterfaceCache.CreateRecordSet();
		
		Lock = New DataLock;
		Lock.Add("InformationRegister.ProgramInterfaceCache");
		Lock.Lock();
		
		RecordSet.Read();
		For each Record In RecordSet Do
			Record.UpdateDate = Undefined;
		EndDo;
		
		InfobaseUpdate.WriteData(RecordSet);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// See CommonOverridable.OnAddMetadataObjectsRenaming. 
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	OldName = "Role.BasicRights";
	NewName  = "Role.BasicSSLRights";
	Common.AddRenaming(Total, "3.0.1.19", OldName, NewName, Library);
	
	OldName = "Role.ExternalUserBasicRights";
	NewName  = "Role.BasicSSLRightsForExternalUsers";
	Common.AddRenaming(Total, "3.0.1.19", OldName, NewName, Library);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers.

// Predefined item BeforeWrite event handler.
Procedure ProhibitMarkingPredefinedItemsForDeletionBeforeWrite(Source, Cancel) Export
	
	If Source.DataExchange.Load
	 Or Source.PredefinedDataName = ""
	 Or Source.DeletionMark <> True Then
		Return;
	EndIf;
	
	If Source.IsNew() Then
		Raise
			NStr("ru = 'Недопустимо создавать предопределенный элемент помеченный на удаление.'; en = 'Cannot create a predefined item marked for deletion.'; pl = 'Nie można utworzyć predefiniowanego elementu, oznaczonego do usunięcia.';es_ES = 'No se puede crear un artículo predefinido marcado para borrar.';es_CO = 'No se puede crear un artículo predefinido marcado para borrar.';tr = 'Silinmek üzere işaretlenmiş önceden tanımlanmış bir öğe oluşturulamıyor.';it = 'Non è consentito creare un elemento predefinito contrassegnato per la cancellazione.';de = 'Es kann kein vordefinierter Artikel zum Löschen erstellt werden.'");
	Else
		PreviousProperties = Common.ObjectAttributesValues(
			Source.Ref, "DeletionMark, PredefinedDataName");
		
		If PreviousProperties.PredefinedDataName <> ""
		   AND PreviousProperties.DeletionMark <> True Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Недопустимо помечать на удаление предопределенный элемент:
				           |""%1"".'; 
				           |en = 'Cannot mark the predefined item for deletion:
				           |""%1.""'; 
				           |pl = 'Niedopuszczalne jest oznaczanie na usuwanie predefiniowanego elementu:
				           |""%1""';
				           |es_ES = 'No se admite marcar para borrar un elemento predeterminado:
				           |""%1"".';
				           |es_CO = 'No se admite marcar para borrar un elemento predeterminado:
				           |""%1"".';
				           |tr = 'Silinmek üzere önceden tanımlanmış 
				           |öğe işaretlenemez: %1';
				           |it = 'Non è consentito contrassegnare un elemento predefinito per la cancellazione:
				           |""%1""';
				           |de = 'Es ist nicht erlaubt, ein vordefiniertes Element zum Löschen zu markieren:
				           |""%1"".'"),
				String(Source.Ref));
			
		ElsIf PreviousProperties.PredefinedDataName = ""
		        AND PreviousProperties.DeletionMark = True Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Недопустимо связывать с именем предопределенного элемент, помеченный на удаление:
				           |""%1"".'; 
				           |en = 'Cannot map a predefined item name to an item marked for deletion:
				           |%1.""'; 
				           |pl = 'Niedopuszczalne jest powiązywać z nazwą predefiniowany element, zaznaczony na usunięcie:
				           |""%1"".';
				           |es_ES = 'No se admite vincular con el nombre del elemento predeterminado marcado para borrar:
				           |""%1"".';
				           |es_CO = 'No se admite vincular con el nombre del elemento predeterminado marcado para borrar:
				           |""%1"".';
				           |tr = 'Silinmek üzere işaretlenmiş olan öğeyi 
				           |önceden tanımlanmış isimle bağlamak kabul edilemez:%1.';
				           |it = 'Non è consentito associare il nome di un elemento predefinito, contrassegnato per la cancellazione:
				           |""%1""';
				           |de = 'Es ist nicht zulässig, sich mit dem Namen eines vordefinierten Elements zu verbinden, das zum Löschen markiert ist:
				           |""%1"".'"),
				String(Source.Ref));
		EndIf;
	EndIf;
	
EndProcedure

// Predefined item BeforeDelete event handler.
Procedure ProhibitPredefinedItemDeletionBeforeDelete(Source, Cancel) Export
	
	If Source.DataExchange.Load
	 Or Source.PredefinedDataName = "" Then
		Return;
	EndIf;
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Недопустимо удалять предопределенный элемент
		           |""%1"".'; 
		           |en = 'Cannot delete the predefined item 
		           |""%1.""'; 
		           |pl = 'Niedopuszczalne jest usuwać predefiniowany element
		           |""%1"".';
		           |es_ES = 'No se admite eliminar un elemento predeterminado 
		           |""%1"".';
		           |es_CO = 'No se admite eliminar un elemento predeterminado 
		           |""%1"".';
		           |tr = 'Önceden tanımlanmış öğe silinemez 
		           |""%1"".';
		           |it = 'Impossibile eliminare l''elemento predefinito 
		           |""%1.""';
		           |de = 'Das vordefinierte Element
		           |""%1"" darf nicht gelöscht werden.'"),
		String(Source.Ref));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// DIB exchange plan event subscription processing.

// Handler for the event of the same name that occurs during data exchange in a distributed infobase.
// 
//
// Parameters:
// see the OnSendDataToSlave() event handler details in the Syntax Assistant.
// 
Procedure OnSendDataToSubordinateEvent(Source, DataItem, ItemSend, InitialImageCreation) Export
	
	OnSendDataToSlave(DataItem, ItemSend, InitialImageCreation, Source);
	
	If ItemSend <> DataItemSend.Ignore Then
		// Calling an overridden handler to execute the applied logic of DIB exchange.
		CommonOverridable.OnSendDataToSlave(Source, DataItem, ItemSend, InitialImageCreation);
	EndIf;
	
EndProcedure

// Handler for the event of the same name that occurs during data exchange in a distributed infobase.
// 
//
// Parameters:
// see the OnSendDataToMaster() event handler details in the Syntax Assistant.
// 
Procedure OnSendDataToMasterEvent(Source, DataItem, ItemSend) Export
	
	OnSendDataToMaster(DataItem, ItemSend, Source);
	
	If ItemSend <> DataItemSend.Ignore Then
		// Calling an overridden handler to execute the applied logic of DIB exchange.
		CommonOverridable.OnSendDataToMaster(Source, DataItem, ItemSend);
	EndIf;
	
EndProcedure

// Handler for the event of the same name that occurs during data exchange in a distributed infobase.
// 
//
// Parameters:
// See the Syntax Assistant for OnReceiveDataFromSlave() event handler details.
// 
Procedure OnReceiveDataFromSubordinateEvent(Source, DataItem, GetItem, SendBack) Export
	
	OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Source);
	
	If GetItem <> DataItemReceive.Ignore Then
		// Calling an overridden handler to execute the applied logic of DIB exchange.
		CommonOverridable.OnReceiveDataFromSlave(Source, DataItem, GetItem, SendBack);
	EndIf;
	
EndProcedure

// Handler for the event of the same name that occurs during data exchange in a distributed infobase.
// 
//
// Parameters:
// see the OnReceiveDataFromMaster() event handler details in the Syntax Assistant.
// 
Procedure OnReceiveDataFromMasterEvent(Source, DataItem, GetItem, SendBack) Export
	
	OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Source);
	
	If GetItem <> DataItemReceive.Ignore Then
		// Calling an overridden handler to execute the applied logic of DIB exchange.
		CommonOverridable.OnReceiveDataFromMaster(Source, DataItem, GetItem, SendBack);
	EndIf;
	
EndProcedure

// WriteBefore event subscription handler for ExchangePlanObject.
// Is used for calling the AfterReceiveData event handler when exchanging in DIB.
//
Procedure AfterGetData(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Source.Metadata().DistributedInfoBase Then
		Return;
	EndIf;
	
	If Source.IsNew()
		Or Source.ReceivedNo = Common.ObjectAttributeValue(Source.Ref, "ReceivedNo") Then
		Return;
	EndIf;
	
	GetFromMasterNode = (ExchangePlans.MasterNode() = Source.Ref);
	
	SSLSubsystemsIntegration.AfterGetData(Source, Cancel, GetFromMasterNode);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

Procedure SetAllPredefinedDataInitialization()
	
	MetadataCollections = New Array;
	MetadataCollections.Add(Metadata.Catalogs);
	MetadataCollections.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataCollections.Add(Metadata.ChartsOfAccounts);
	MetadataCollections.Add(Metadata.ChartsOfCalculationTypes);
	
	For each Collection In MetadataCollections Do
		For Each MetadataObject In Collection Do
			Manager = Common.ObjectManagerByFullName(MetadataObject.FullName());
			Manager.SetPredefinedDataInitialization(True);
		EndDo;
	EndDo;
	
EndProcedure

Procedure CreateMissingPredefinedData()
	
	MetadataCollections = New Array;
	MetadataCollections.Add(Metadata.Catalogs);
	MetadataCollections.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataCollections.Add(Metadata.ChartsOfAccounts);
	MetadataCollections.Add(Metadata.ChartsOfCalculationTypes);
	
	Query = New Query;
	QueryText =
	"SELECT
	|	SpecifiedTableAlias.Ref AS Ref,
	|	ISNULL(SpecifiedTableAlias.Parent.PredefinedDataName, """") AS ParentName,
	|	SpecifiedTableAlias.PredefinedDataName AS Name
	|FROM
	|	&CurrentTable AS SpecifiedTableAlias
	|WHERE
	|	SpecifiedTableAlias.Predefined";
	
	SavedItemsDescriptions = New Array;
	For Each Collection In MetadataCollections Do
		IsChartOfAccounts = (Collection = Metadata.ChartsOfAccounts);
		For Each MetadataObject In Collection Do
			If MetadataObject.PredefinedDataUpdate
					= Metadata.ObjectProperties.PredefinedDataUpdate.DontAutoUpdate Then
				Continue;
			EndIf;
			FullName = MetadataObject.FullName();
			Query.Text = StrReplace(QueryText, "&CurrentTable", FullName);
			
			If Collection = Metadata.ChartsOfAccounts
			 Or Collection = Metadata.ChartsOfCalculationTypes
			 Or Not MetadataObject.Hierarchical Then
				
				Query.Text = StrReplace(Query.Text,
					"ISNULL(SpecifiedTableAlias.Parent.PredefinedDataName, """")", """""");
			EndIf;
			
			NameTable = Query.Execute().Unload();
			NameTable.Indexes.Add("Name");
			Names = MetadataObject.GetPredefinedNames();
			SaveExistingPredefinedObjectsBeforeCreateMissingOnes(
				MetadataObject, FullName, NameTable, Names, Query, SavedItemsDescriptions, IsChartOfAccounts);
		EndDo;
	EndDo;
	
	InitializePredefinedData();
	
	// Restoring predefined items that were before the initialization.
	For Each SavedItemsDescription In SavedItemsDescriptions Do
		Query.Text = SavedItemsDescription.QueryText;
		NameTable = Query.Execute().Unload();
		NameTable.Indexes.Add("Name");
		For Each SavedItemDescription In SavedItemsDescription.NameTable Do
			If Not SavedItemDescription.ObjectExist Then
				Continue;
			EndIf;
			Row = NameTable.Find(SavedItemDescription.Name, "Name");
			If Row <> Undefined Then
				NewObject = Row.Ref.GetObject();
				If SavedItemsDescription.IsChartOfAccounts Then
					AddNewExtraAccountDimensionTypes(SavedItemDescription.Object, NewObject);
				EndIf;
				InfobaseUpdate.DeleteData(NewObject);
				Row.Name = "";
			EndIf;
			InfobaseUpdate.WriteData(SavedItemDescription.Object);
		EndDo;
		For Each Row In NameTable Do
			If Not ValueIsFilled(Row.Name)
			 Or Not ValueIsFilled(Row.ParentName) Then
				Continue;
			EndIf;
			ParentLevelRow = SavedItemsDescription.NameTable.Find(Row.ParentName, "Name");
			If ParentLevelRow <> Undefined Then
				NewObject = Row.Ref.GetObject();
				NewObject.Parent = ParentLevelRow.Ref;
				InfobaseUpdate.WriteData(NewObject);
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

Procedure AddNewExtraAccountDimensionTypes(Account, SampleAccount)
	
	For Each Row In SampleAccount.ExtDimensionTypes Do
		Index = SampleAccount.ExtDimensionTypes.IndexOf(Row);
		If Account.ExtDimensionTypes.Count() > Index Then
			If Account.ExtDimensionTypes[Index].ExtDimensionType <> Row.ExtDimensionType Then
				WriteLogEvent(
					NStr("ru = 'Обмен данными.Отключение связи с главным узлом'; en = 'Data exchange.Disconnection from the master node'; pl = 'Wymiana danych.Wyłączenie połączenia z węzłem głównym';es_ES = 'Intercambio de datos.Desconectar los vínculos con el nodo principal';es_CO = 'Intercambio de datos.Desconectar los vínculos con el nodo principal';tr = 'Veri alışverişi. Ana ünite ile bağlantının kesilmesi';it = 'Scambio dati.Disabilitazione della comunicazione con il nodo principale';de = 'Datenaustausch. Die Kommunikation mit dem Hauptknoten wird deaktiviert'",
						CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					Account.Metadata(),
					Account,
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'У счета ""%1"" субконто №%2 ""%3"" не совпадает с предопределенным субконто ""%4"".'; en = 'The extra dimension #%2 ""%3"" in chart of accounts ""%1"" does not match the predefined extra dimension ""%4.""'; pl = 'Dla rachunku ""%1"" subkonto nr%2 ""%3"" nie zgadza się z subkontem predefiniowanym ""%4"".';es_ES = 'La cuenta analítica №%2 ""%3"" de la cuenta ""%1"" no coincide con la cuenta analítica predeterminada ""%4"".';es_CO = 'La cuenta analítica №%2 ""%3"" de la cuenta ""%1"" no coincide con la cuenta analítica predeterminada ""%4"".';tr = '""%1"" hesabın %2 sayılı alt hesabı ""%3"" önceden tanımlanmış alt hesap ""%4"" ile aynı değildir.';it = 'Al conto ""%1"" sottoconto №%2 ""%3"" non corrisponde al sottoconto predefinito ""%4""';de = 'Das Konto ""%1"" Subkonto-Nummer%2 ""%3"" stimmt nicht mit dem vordefinierten Subkonto ""%4"" überein.'"),
						String(Account),
						Index + 1,
						String(Account.ExtDimensionTypes[Index].ExtDimensionType),
						String(Row.ExtDimensionType)),
					EventLogEntryTransactionMode.Transactional);
			ElsIf Not Account.ExtDimensionTypes[Index].Predefined Then
				Account.ExtDimensionTypes[Index].Predefined = True;
			EndIf;
		Else
			FillPropertyValues(Account.ExtDimensionTypes.Add(), Row);
		EndIf;
	EndDo;
	
EndProcedure

Procedure SaveExistingPredefinedObjectsBeforeCreateMissingOnes(
		MetadataObject, FullName, NameTable, Names, Query, SavedItemsDescriptions, IsChartOfAccounts)
	
	InitializationRequired = False;
	PredefinedItemsExist = False;
	NameTable.Columns.Add("ObjectExist", New TypeDescription("Boolean"));
	
	For each Name In Names Do
		Rows = NameTable.FindRows(New Structure("Name", Name));
		If Rows.Count() = 0 Then
			InitializationRequired = True;
		Else
			For Each Row In Rows Do
				Row.ObjectExist = True;
			EndDo;
			PredefinedItemsExist = True;
		EndIf;
	EndDo;
	
	If Not InitializationRequired Then
		Return;
	EndIf;
	
	If PredefinedItemsExist Then
		SavedItemsDescription = New Structure;
		SavedItemsDescription.Insert("QueryText",  Query.Text);
		SavedItemsDescription.Insert("NameTable",   NameTable);
		SavedItemsDescription.Insert("IsChartOfAccounts", IsChartOfAccounts);
		SavedItemsDescriptions.Add(SavedItemsDescription);
		
		NameTable.Columns.Add("Object");
		For each Row In NameTable Do
			If Row.ObjectExist Then
				Object = Row.Ref.GetObject();
				Object.PredefinedDataName = "";
				If IsChartOfAccounts Then
					PredefinedExtraDimensionKindRows = New Array;
					For Each ExtraDimensionKindRow In Object.ExtDimensionTypes Do
						If ExtraDimensionKindRow.Predefined Then
							ExtraDimensionKindRow.Predefined = False;
							PredefinedExtraDimensionKindRows.Add(ExtraDimensionKindRow);
						EndIf;
					EndDo;
				EndIf;
				InfobaseUpdate.WriteData(Object);
				If IsChartOfAccounts Then
					For Each ExtraDimensionKindRow In PredefinedExtraDimensionKindRows Do
						ExtraDimensionKindRow.Predefined = True;
					EndDo;
				EndIf;
				Object.PredefinedDataName = Row.Name;
				Row.Object = Object;
			EndIf;
		EndDo;
	EndIf;
	
	Manager = Common.ObjectManagerByFullName(FullName);
	Manager.SetPredefinedDataInitialization(False);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

Procedure BeforeStartApplication()
	
	// Privileged mode (set by the platform).
	
	// Checking the default programming language set in the configuration.
	//If Metadata.ScriptVariant <> Metadata.ObjectsProperties.ScriptVariant.Russian Then
	//	RaiseException StringFunctionsClientServer.SubstituteParametersToString(
	//		NStr("en = 1C:Enterprise script option ""%1"" is not supported.
	//		           |Use script option ""%2""."' instead),
	//		Metadata.ScriptVariant,
	//		Metadata.ObjectProperties.ScriptVariant.Russian).
	//EndIf
	
	// Checking settings of compatibility between the configuration and the platform version.
	SystemInfo = New SystemInfo;
	MinPlatformVersion = "8.3.12.1412";
	If CommonClientServer.CompareVersions(SystemInfo.AppVersion, MinPlatformVersion) < 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Для запуска необходима версия платформы 1С:Предприятие %1 или выше.'; en = 'The application requires 1C:Enterprise version %1 or later.'; pl = 'Do uruchomienia wymagana jest wersja %1 platformy 1C:Enterprise lub nowsza.';es_ES = 'Para lanzar la plataforma de la 1C:Empresa, se requiere la versión %1 o más alta.';es_CO = 'Para lanzar la plataforma de la 1C:Empresa, se requiere la versión %1 o más alta.';tr = '1C:Enterprise platformunun %1 veya daha yeni sürümü gerekiyor.';it = 'Per l''avvio è necessaria la versione della piattaforma 1C:Enterprise %1 o superiore.';de = 'Für Start 1C:Enterprise-Plattform-Version %1 oder höher ist erforderlich.'"), MinPlatformVersion);
	EndIf;
	
	Modes = Metadata.ObjectProperties.CompatibilityMode;
	CurrentMode = Metadata.CompatibilityMode;
	
	SupportedPlatformVersion = "8.3.12";
	PlatformVersion = CommonClientServer.ConfigurationVersionWithoutBuildNumber(SystemInfo.AppVersion);
	If CurrentMode = Modes.DontUse Then
		If CommonClientServer.CompareVersionsWithoutBuildNumber(PlatformVersion, SupportedPlatformVersion) = 0 Then
			UnsupportedPlatformVersion = "";
		Else
			UnsupportedPlatformVersion = PlatformVersion;
		EndIf;	
	ElsIf CurrentMode = Modes.Version8_1 Then
		UnsupportedPlatformVersion = "8.1"
	ElsIf CurrentMode = Modes.Version8_2_13 Then
		UnsupportedPlatformVersion = "8.2.13"
	ElsIf CurrentMode = Modes.Version8_2_16 Then
		UnsupportedPlatformVersion = "8.2.16";
	ElsIf CurrentMode = Modes.Version8_3_1 Then
		UnsupportedPlatformVersion = "8.3.1";
	ElsIf CurrentMode = Modes.Version8_3_2 Then
		UnsupportedPlatformVersion = "8.3.2";
	ElsIf CurrentMode = Modes.Version8_3_3 Then
		UnsupportedPlatformVersion = "8.3.3";
	ElsIf CurrentMode = Modes.Version8_3_4 Then
		UnsupportedPlatformVersion = "8.3.4";
	ElsIf CurrentMode = Modes.Version8_3_5 Then
		UnsupportedPlatformVersion = "8.3.5";
	ElsIf CurrentMode = Modes.Version8_3_6 Then
		UnsupportedPlatformVersion = "8.3.6";
	ElsIf CurrentMode = Modes.Version8_3_7 Then
		UnsupportedPlatformVersion = "8.3.7";
	ElsIf CurrentMode = Modes.Version8_3_8 Then
		UnsupportedPlatformVersion = "8.3.8";
	ElsIf CurrentMode = Modes.Version8_3_9 Then
		UnsupportedPlatformVersion = "8.3.9";
	ElsIf CurrentMode = Modes.Version8_3_10 Then
		UnsupportedPlatformVersion = "8.3.10";
	ElsIf CurrentMode = Modes.Version8_3_11 Then
		UnsupportedPlatformVersion = "8.3.11";
	Else
		UnsupportedPlatformVersion = ?(StrEndsWith(String(CurrentMode), "8_3_12"), "", String(CurrentMode));
	EndIf;
	
	//If ValueIsFilled(UnsupportedPlatformVersion) Then
	//	Raise StringFunctionsClientServer.SubstituteParametersToString(
	//		NStr("ru = 'Режим совместимости конфигурации с 1С:Предприятием версии %1 не поддерживается.
	//		           |Для запуска установите в конфигурации режим совместимости ""Не использовать"" при разработке на версии %2
	//		           |(или ""Версия %2"" при разработке на более старших версиях).'; 
	//		           |en = 'Configuration compatibility mode ""Version %1"" is not supported. 
	//		           |To start the application, set the compatibility mode to ""None"" (on 1C:Enterprise version %2)
	//		           | or to ""Version %2"" (on a later 1C:Enterprise version).'"),
	//		UnsupportedPlatformVersion, SupportedPlatformVersion);
	//EndIf;
	
	// Checking whether the configuration version is filled.
	If IsBlankString(Metadata.Version) Then
		Raise NStr("ru = 'Не заполнено свойство конфигурации Версия.'; en = 'The Version configuration property is blank.'; pl = 'Właściwość Wersja konfiguracji nie została wprowadzona.';es_ES = 'Versión de la Propiedad de la configuración no introducida.';es_CO = 'Versión de la Propiedad de la configuración no introducida.';tr = 'Yapılandırmanın Özellik Sürümü girilmemiş.';it = 'Il parametro della configurazione Versione non è compilato.';de = 'Die Eigenschaft der Version der Konfiguration wurde nicht eingegeben.'");
	Else
		Try
			ZeroVersion = CommonClientServer.CompareVersions(Metadata.Version, "0.0.0.0") = 0;
		Except
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не правильно заполнено свойство конфигурации Версия: ""%1"".
				           |Правильный формат, например: ""1.2.3.45"".'; 
				           |en = 'The Version configuration property has invalid value: %1.
				           |Use the following format: ""1.2.3.45"".'; 
				           |pl = 'Nieprawidłowo wypełniona właściwość Wersja konfiguracji: %1
				           |Przykład prawidłowego formatu: ""1.2.3.45"".';
				           |es_ES = 'La propiedad de la configuración de la Versión está rellenada de forma incorrecta: %1
				           |Formato correcto, por ejemplo: ""1.2.3.45"".';
				           |es_CO = 'La propiedad de la configuración de la Versión está rellenada de forma incorrecta: %1
				           |Formato correcto, por ejemplo: ""1.2.3.45"".';
				           |tr = 'Sürüm yapılandırmasının özelliği yanlış şekilde dolduruldu: %1
				           |Doğru biçim, örneğin: ""1.2.3.45"".';
				           |it = 'La proprietà della configurazione Versione: ""%1"" non è stata compilata correttamente.
				           |Il formato corretto è, ad esempio: ""1.2.3.45"".';
				           |de = 'Die Eigenschaft der Version-Konfiguration ist falsch ausgefüllt: %1
				           |Korrektes Format, zum Beispiel: ""1.2.3.45"".'"),
				Metadata.Version);
		EndTry;
		If ZeroVersion Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не правильно заполнено свойство конфигурации Версия: ""%1"".
				           |Версия не может быть нулевой.'; 
				           |en = 'The Version configuration property has invalid value: %1.
				           |The version cannot be zero.'; 
				           |pl = 'Nieprawidłowo wypełniona właściwość Wersja konfiguracji:%1
				           |Wersja nie może być zerowa.';
				           |es_ES = 'La propiedad de la configuración de la Versión está rellenada de forma incorrecta: %1
				           |Versión no puede ser cero.';
				           |es_CO = 'La propiedad de la configuración de la Versión está rellenada de forma incorrecta: %1
				           |Versión no puede ser cero.';
				           |tr = 'Sürüm yapılandırmasının özelliği yanlış şekilde dolduruldu: %1
				           |Sürüm sıfır olamaz.';
				           |it = 'La proprietà della configurazione Versione: ""%1"" non è stata compilata correttamente.
				           |La versione non può essere zero.';
				           |de = 'Die Eigenschaft der Version-Konfiguration ist falsch ausgefüllt: %1
				           |Version kann nicht die Null sein.'"),
				Metadata.Version);
		EndIf;
	EndIf;
	
	If (Metadata.DefaultRoles.Count() <> 2 AND Metadata.DefaultRoles.Count() <> 3)
	 Or Not Metadata.DefaultRoles.Contains(Metadata.Roles.SystemAdministrator)
	 Or Not Metadata.DefaultRoles.Contains(Metadata.Roles.FullRights) Then
		Raise
			NStr("ru = 'В конфигурации в свойстве ""Основные роли"" не указаны стандартные роли
			           |SystemAdministrator и FullAccess или указаны лишние роли.'; 
			           |en = 'The ""Default roles"" configuration property does not include the standard roles SystemAdministrator and FullAccess,
			           |or it includes redundant roles.'; 
			           |pl = 'W konfiguracji we właściwości ""Domyślne role"" nie podano standardowych ról SystemAdministrator i FullAccess,
			           |lub są zbędne role.';
			           |es_ES = 'En la configuración en la propiedad DefaultRoles los roles estándares
			           | SystemAdministrator y FullRights no están especificados, o extra roles están especificados.';
			           |es_CO = 'En la configuración en la propiedad DefaultRoles los roles estándares
			           | SystemAdministrator y FullRights no están especificados, o extra roles están especificados.';
			           |tr = 'TemelRoller özelliğindeki yapılandırmada, SistemYöneticisi
			           | ve TamHaklar standart rolleri belirtilmez veya fazladan roller belirtilir.';
			           |it = 'La proprietà di configurazione ""Ruoli predefiniti"" non include i ruoli standard SystemAdministrator e FullAccess,
			           |né include ruoli accessori.';
			           |de = 'In der Konfiguration werden in der Eigenschaft BasisRollen nicht die Standardrollen
			           |AdminSysteme und VollständigeRechte oder die zusätzlichen Rollen angegeben.'");
	EndIf;
	
	// Checking whether the session parameter setting handlers for the application start can run.
	CheckIfCanStart();
	
	If Not ValueIsFilled(InfoBaseUsers.CurrentUser().Name)
	   AND (Not Common.DataSeparationEnabled()
	      Or Not Common.SeparatedDataUsageAvailable())
	   AND InfobaseUpdateInternal.IBVersion("StandardSubsystems",
	       Common.DataSeparationEnabled()) = "0.0.0.0" Then
		
		UsersInternal.SetInitialSettings("");
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		ModuleSaaS.EnablingDataSeparationSafeModeOnCheck();
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.DataAreaBackup") Then
		// Setting flag that shows whether users are active in the area.
		ModuleDataAreaBackup = Common.CommonModule("DataAreaBackup");
		ModuleDataAreaBackup.SetUserActivityInAreaFlag();
	EndIf;
	
	CorrectSharedUserHomePage();
	HandleCopiedSettingsQueue();
	
EndProcedure

// This method is required by BeforeApplicationStart procedure.
Procedure CorrectSharedUserHomePage()
	
	If CurrentRunMode() = Undefined
	 Or Not Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		SessionWithoutSeparators = ModuleSaaS.SessionWithoutSeparators();
	Else
		SessionWithoutSeparators = False;
	EndIf;
	
	If Not SessionWithoutSeparators Then
		Return;
	EndIf;
	
	ObjectKey  = "Core";
	SettingsKey = "MetadataHomePageFormComposition";
	
	PreviousFormCompositionInMetadata = CommonSettingsStorage.Load(ObjectKey, SettingsKey);
	If PreviousFormCompositionInMetadata = Undefined Then
		// Clearing the home page on the first sign-in.
		SetBlankFormOnHomePage();
	Else
		SetBlankFormOnBlankHomePage();
	EndIf;
	
	// Compensation of form content change in the metadata of the home page.
	NewSettings = New HomePageSettings;
	FormCompositionInMetadata = NewSettings.GetForms();
	
	If TypeOf(PreviousFormCompositionInMetadata) <> Type("Structure")
	 Or Not PreviousFormCompositionInMetadata.Property("LeftColumn")
	 Or TypeOf(PreviousFormCompositionInMetadata.LeftColumn) <> Type("Array")
	 Or Not PreviousFormCompositionInMetadata.Property("RightColumn")
	 Or TypeOf(PreviousFormCompositionInMetadata.RightColumn) <> Type("Array") Then
		
		PreviousFormCompositionInMetadata = New HomePageForms;
		
	ElsIf FormCompositionMatches(PreviousFormCompositionInMetadata.LeftColumn,  FormCompositionInMetadata.LeftColumn)
	        AND FormCompositionMatches(PreviousFormCompositionInMetadata.RightColumn, FormCompositionInMetadata.RightColumn) Then
		
		// Form content in the metadata of the home page is not changed.
		Return;
	EndIf;
	
	CompensateChangesOfFormCompositionInHomePageMetadata(PreviousFormCompositionInMetadata);
	
	SavedFormCompositionInMetadata = New Structure("LeftColumn, RightColumn");
	FillPropertyValues(SavedFormCompositionInMetadata, FormCompositionInMetadata);
	
	CommonSettingsStorage.Save(ObjectKey, SettingsKey, SavedFormCompositionInMetadata);
	
EndProcedure

// This method is required by CorrectSharedUserHomePage procedure.
Function FormCompositionMatches(PreviousFormsInMetadata, FormsInMetadata)
	
	If PreviousFormsInMetadata.Count() <> FormsInMetadata.Count() Then
		Return False;
	EndIf;
	
	For Each FormName In FormsInMetadata Do
		If PreviousFormsInMetadata.Find(FormName) = Undefined Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// This method is required by CorrectSharedUserHomePage procedure.
Procedure CompensateChangesOfFormCompositionInHomePageMetadata(PreviousFormCompositionInMetadata)
	
	// The compensation takes into account that the settings of the home page can be saved within the 
	// desktop hiding procedure.
	
	ObjectKey         = "Common/HomePageSettings";
	StorageObjectKey = "Common/HomePageSettingsBeforeClear";
	SavedSettings = SystemSettingsStorage.Load(StorageObjectKey, "");
	SettingsSaved   = TypeOf(SavedSettings) = Type("ValueStorage");
	
	If SettingsSaved Then
		CurrentSettings = SavedSettings.Get();
	Else
		CurrentSettings = SystemSettingsStorage.Load(ObjectKey);
	EndIf;
	If TypeOf(CurrentSettings) = Type("HomePageSettings") Then
		FormComposition = CurrentSettings.GetForms();
	Else
		FormComposition = New HomePageForms;
	EndIf;
	
	NewSettings = New HomePageSettings;
	FormCompositionInMetadata = NewSettings.GetForms();
	
	DeleteNewHomePageForms(FormComposition.LeftColumn,
		PreviousFormCompositionInMetadata.LeftColumn, FormCompositionInMetadata.LeftColumn);
	
	DeleteNewHomePageForms(FormComposition.RightColumn,
		PreviousFormCompositionInMetadata.RightColumn, FormCompositionInMetadata.RightColumn);
	
	CurrentSettings = New HomePageSettings;
	CurrentSettings.SetForms(FormComposition);
	
	If SettingsSaved Then
		SettingsToSave = New ValueStorage(CurrentSettings);
		SystemSettingsStorage.Save(StorageObjectKey, "", SettingsToSave);
		SetBlankFormOnHomePage();
	Else
		SystemSettingsStorage.Save(ObjectKey, "", CurrentSettings);
	EndIf;
	
EndProcedure

// This method is required by CompensateChangesOfFormContentInHomePageMetadata procedure.
Procedure DeleteNewHomePageForms(CurrentForms, PreviousFormsInMetadata, FormsInMetadata)
	
	For Each FormName In FormsInMetadata Do
		If PreviousFormsInMetadata.Find(FormName) <> Undefined Then
			Continue;
		EndIf;
		Index = CurrentForms.Find(FormName);
		If Index <> Undefined Then
			CurrentForms.Delete(Index);
		EndIf;
	EndDo;
	
EndProcedure

Procedure HandleCopiedSettingsQueue()
	
	If CurrentRunMode() = Undefined Then
		Return;
	EndIf;
	
	SettingsQueue = CommonSettingsStorage.Load("SettingsQueue", "NotAppliedSettings");
	If TypeOf(SettingsQueue) <> Type("ValueStorage") Then
		Return;
	EndIf;
	SettingsQueue = SettingsQueue.Get();
	If TypeOf(SettingsQueue) <> Type("Map") Then
		Return;
	EndIf;
	
	For Each QueueItem In SettingsQueue Do
		Try
			Setting = SystemSettingsStorage.Load(QueueItem.Key, QueueItem.Value);
		Except
			Continue;
		EndTry;
		SystemSettingsStorage.Save(QueueItem.Key, QueueItem.Value, Setting);
	EndDo;
	
	CommonSettingsStorage.Save("SettingsQueue", "NotAppliedSettings", Undefined);
	
EndProcedure

Procedure ExecuteSessionParameterSettingHandlers(SessionParameterNames, Handlers, SpecifiedParameters)
	
	// Array with the keys of the session parameter is specified by the initial word in the name of the 
	// session parameter and the "*" character.
	SessionParameterKeys = New Array;
	
	For Each Record In Handlers Do
		If StrFind(Record.Key, "*") > 0 Then
			ParameterKey = TrimAll(Record.Key);
			SessionParameterKeys.Add(Left(ParameterKey, StrLen(ParameterKey)-1));
		EndIf;
	EndDo;
	
	For each ParameterName In SessionParameterNames Do
		If SpecifiedParameters.Find(ParameterName) <> Undefined Then
			Continue;
		EndIf;
		
		Handler = Handlers.Get(ParameterName);
		If Handler <> Undefined Then
			HandlerParameters = New Array();
			HandlerParameters.Add(ParameterName);
			HandlerParameters.Add(SpecifiedParameters);
			Common.ExecuteConfigurationMethod(Handler, HandlerParameters);
			Continue;
		EndIf;
		
		For Each ParameterKeyName In SessionParameterKeys Do
			If StrStartsWith(ParameterName, ParameterKeyName) Then
				Handler = Handlers.Get(ParameterKeyName + "*");
				HandlerParameters = New Array();
				HandlerParameters.Add(ParameterName);
				HandlerParameters.Add(SpecifiedParameters);
				Common.ExecuteConfigurationMethod(Handler, HandlerParameters);
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

Procedure IgnoreSendingMetadataObjectIDs(DataItem, ItemSend, Val InitialImageCreation = False)
	
	If Not InitialImageCreation
		AND MetadataObject(DataItem) = Metadata.Catalogs.MetadataObjectIDs Then
		
		ItemSend = DataItemSend.Ignore;
		
	EndIf;
	
EndProcedure

Procedure IgnoreGettingMetadataObjectIDs(DataItem, GetItem)
	
	If MetadataObject(DataItem) = Metadata.Catalogs.MetadataObjectIDs Then
		GetItem = DataItemReceive.Ignore;
	EndIf;
	
EndProcedure

Function MetadataObject(Val DataItem)
	
	Return ?(TypeOf(DataItem) = Type("ObjectDeletion"), DataItem.Ref.Metadata(), DataItem.Metadata());
	
EndFunction

Function InitialImageCreation(Val DataItem)
	
	Return ?(TypeOf(DataItem) = Type("ObjectDeletion"), False, DataItem.AdditionalProperties.Property("InitialImageCreation"));
	
EndFunction

Function ShowDeprecatedPlatformVersion(Parameters)
	
	If Parameters.DataSeparationEnabled Then
		Return False;
	EndIf;
	
	// Checking whether the user is not an external one.
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("IBUserID",
		InfoBaseUsers.CurrentUser().UUID);
	
	Query.Text = 
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.IBUserID = &IBUserID";
	
	If NOT Query.Execute().IsEmpty() Then
		Return False;
	EndIf;
	
	SystemInfo = New SystemInfo;
	ActualVersion       = SystemInfo.AppVersion;
	Min   = Parameters.MinPlatformVersion;
	Recommended = Parameters.RecommendedPlatformVersion;
	
	Return CommonClientServer.CompareVersions(ActualVersion, Min) < 0
		Or CommonClientServer.CompareVersions(ActualVersion, Recommended) < 0;
	
EndFunction

Function DefaultAdministrationParameters()
	
	ClusterAdministrationParameters = ClusterAdministrationClientServer.ClusterAdministrationParameters();
	IBAdministrationParameters = ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters();
	
	// Combining parameter structures.
	AdministrationParameterStructure = ClusterAdministrationParameters;
	For Each Item In IBAdministrationParameters Do
		AdministrationParameterStructure.Insert(Item.Key, Item.Value);
	EndDo;
	
	AdministrationParameterStructure.Insert("OpenExternalReportsAndDataProcessorsDecisionMade", False);
	
	Return AdministrationParameterStructure;
	
EndFunction

Procedure ReadParametersFromConnectionString(AdministrationParameterStructure)
	
	ConnectionStringSubstrings = StrSplit(InfoBaseConnectionString(), ";");
	
	ServerNameString = StringFunctionsClientServer.RemoveDoubleQuotationMarks(Mid(ConnectionStringSubstrings[0], 7));
	AdministrationParameterStructure.NameInCluster = StringFunctionsClientServer.RemoveDoubleQuotationMarks(Mid(ConnectionStringSubstrings[1], 6));
	
	ClusterServerList = StrSplit(ServerNameString, ",");
	
	ServerName = ClusterServerList[0];
	
	// TCP is the only possible protocol. We can discard it.
	If StrStartsWith(Upper(ServerName), "TCP://") Then
		ServerName = Mid(ServerName, 7);
	EndIf;
	
	// If an IPv6 address is passed as the server name, the port can go after the closing bracket (]) only.
	StartPosition = StrFind(ServerName, "]");
	If StartPosition <> 0 Then
		PortSeparator = StrFind(ServerName, ":",, StartPosition);
	Else
		PortSeparator = StrFind(ServerName, ":");
	EndIf;
	
	If PortSeparator > 0 Then
		ServerAgentAddress = Mid(ServerName, 1, PortSeparator - 1);
		ClusterPort = Number(Mid(ServerName, PortSeparator + 1));
		If AdministrationParameterStructure.ClusterPort = 1541 Then
			AdministrationParameterStructure.ClusterPort = ClusterPort;
		EndIf;
	Else
		ServerAgentAddress = ServerName;
	EndIf;
	
	AdministrationParameterStructure.ServerAgentAddress = ServerAgentAddress;
	
EndProcedure

// Checks whether handlers that set session parameters, update handlers, and other basic mechanisms 
// of configuration that execute configuration code on the full procedure name can be executed.
// 
//
// If the current settings of the security profiles (in the server cluster and in the infobase) do 
// not allow the handlers execution, an exception is generated that contains reason details and the 
// list of actions to solve this problem.
//
Procedure CheckIfCanStart()
	
	If Common.FileInfobase(InfoBaseConnectionString()) Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		InfobaseProfile = StandardSubsystemsSafeMode.InfobaseSecurityProfile();
	Else
		InfobaseProfile = "";
	EndIf;
	
	If ValueIsFilled(InfobaseProfile) Then
		
		// Infobase is configured to use the security profile that denied full access to external modules.
		// 
		
		SetSafeMode(InfobaseProfile);
		If SafeMode() <> InfobaseProfile Then
			
			// Infobase profile does not allow the handler execution.
			
			SetSafeMode(False);
			
			Try
				PrivilegedModeAvailable = CanExecuteHandlersWithoutSafeMode();
			Except
				PrivilegedModeAvailable = False;
			EndTry;
				
			If Not PrivilegedModeAvailable Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Невозможно установить параметры сеанса по причине: профиль безопасности %1 отсутствует в кластере серверов 1С:Предприятия, или для него запрещено использование в качестве профиля безопасности безопасного режима.
						|
						|Для восстановления работоспособности программы требуется отключить использование профиля безопасности через консоль кластера и заново настроить профили безопасности с помощью интерфейса конфигурации (соответствующие команды находятся в разделе настроек программы).'; 
						|en = 'Cannot set session parameters. Reason: security profile %1 is not found in 1C:Enterprise server cluster or it cannot be applied in safe mode.
						|
						|To restore application functionality, disable the security profile using the cluster console and reconfigure the security profiles using the configuration interface (see the commands in the application settings section).'; 
						|pl = 'Nie można ustawić parametry sesji z powodu: profil bezpieczeństwa %1 nie ma w klastrze serwerów 1C:Enterprise, lub dla niego zabronione jest używanie jako profilu bezpieczeństwa trybu bezpiecznego.
						|
						|W celu przywrócenia działania programu trzeba wyłączyć korzystanie z profilu bezpieczeństwa poprzez konsolę klastra i ponownie skonfigurować profile zabezpieczeń przy użyciu interfejsu konfiguracyjnego (odpowiednie polecenia znajdują się w ustawieniach programu).';
						|es_ES = 'No se puede instalar los parámetros de la sesión debido a: el perfil de seguridad %1 es ausente en el clúster del servidor de la 1C:Enterprise, o está prohibido utilizarlo como el perfil de seguridad del modo seguro.
						|
						|Para restaurar el programa, se requiere desactivar el uso del perfil de seguridad a través de la consola del clúster, y reconfigurar los perfiles de seguridad utilizando la interfaz de configuraciones (comandos correspondientes están ubicados en la sección de las configuraciones del programa).';
						|es_CO = 'No se puede instalar los parámetros de la sesión debido a: el perfil de seguridad %1 es ausente en el clúster del servidor de la 1C:Enterprise, o está prohibido utilizarlo como el perfil de seguridad del modo seguro.
						|
						|Para restaurar el programa, se requiere desactivar el uso del perfil de seguridad a través de la consola del clúster, y reconfigurar los perfiles de seguridad utilizando la interfaz de configuraciones (comandos correspondientes están ubicados en la sección de las configuraciones del programa).';
						|tr = 'Oturum parametreleri ayarının işleyicilerini yürütemiyor çünkü:
						|güvenlik profili %1 1C:Enterprise sunucu kümesinde bulunmamaktadır 
						|ya da güvenli modun güvenlik profili olarak bunun kullanılması yasaklanmıştır. Uygulamanın geri yüklenmesi için güvenlik profilinin kullanımını küme konsolunda devre bırakmak ve yapılandırma arayüzü kullanılarak güvenlik profillerini yeniden yapılandırmak gereklidir (karşılık gelen komutlar uygulama ayarları bölümünde yer alır).';
						|it = 'I parametri di sessione non possono essere impostati a causa di quanto segue: il profilo di sicurezza %1 non si trova nel cluster di server 1C:Enterprise o è vietato utilizzare la modalità provvisoria come profilo di sicurezza.
						|
						|Per ripristinare la funzionalità del programma, è necessario disabilitare l''uso del profilo di sicurezza tramite la console del cluster e riconfigurare i profili di sicurezza utilizzando l''interfaccia di configurazione (i comandi corrispondenti si trovano nella sezione delle impostazioni del programma).';
						|de = 'Es ist unmöglich, Sitzungsparameter einzustellen, weil: das Sicherheitsprofil %1 im Cluster der Server 1C:Enterprise fehlt, oder es ist verboten, es als Sicherheitsprofil des abgesicherten Modus zu verwenden.
						|
						|Um die Funktionalität des Programms wiederherzustellen, ist es notwendig, die Verwendung des Sicherheitsprofils über die Clusterkonsole zu deaktivieren und die Sicherheitsprofile über die Konfigurationsschnittstelle neu zu konfigurieren (die entsprechenden Befehle finden Sie im Abschnitt Programmeinstellungen).'"),
					InfobaseProfile);
			EndIf;
			
		EndIf;
		
		PrivilegedModeAvailable = SwichingToPrivilegedModeAvailable();
		
		SetSafeMode(False);
		
		If Not PrivilegedModeAvailable Then
			
			// Infobase profile allows the handler execution but the privileged mode cannot be set.
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Невозможно установить параметры сеанса по причине: профиль безопасности %1 не содержит разрешения на установку привилегированного режима. Возможно, он был отредактирован через консоль кластера.
					|
					|Для восстановления работоспособности программы требуется отключить использование профиля безопасности через консоль кластера и заново настроить профили безопасности с помощью интерфейса конфигурации (соответствующие команды находятся в разделе настроек программы).'; 
					|en = 'Cannot set the session parameters. Reason: security profile %1 does not contain the permission to set privileged mode. Probably it was edited using the cluster console.
					|
					|To restore the application functionality, disable the security profile using the cluster console and reconfigure the security profiles using the configuration interface (see the commands in the application settings section).'; 
					|pl = 'Nie można ustawić parametry sesji z powodu: profil bezpieczeństwa %1 nie zawiera zgody na instalację uprzywilejowanego trybu. Może był edytowany przez konsolę klastra.
					|
					|W celu przywrócenia działania programu trzeba wyłączyć korzystanie z profilu bezpieczeństwa poprzez konsolę klastra i ponownie skonfigurować profile zabezpieczeń przy użyciu interfejsu konfiguracyjnego (odpowiednie polecenia znajdują się w ustawieniach programu).';
					|es_ES = 'Es imposible especificar los parámetros de la sesión debido a: el perfil de seguridad %1 no contiene un permiso de establecer el modo privilegiado. Puede ser que se haya editado a través de la consola del clúster.
					|
					|Para restaurar la aplicación, se requiere desactivar el uso del perfil de seguridad a través de la consola del clúster, y reconfigurar los perfiles de seguridad utilizando la interfaz de configuraciones (comandos correspondientes están ubicados en la sección de los ajustes del programa).';
					|es_CO = 'Es imposible especificar los parámetros de la sesión debido a: el perfil de seguridad %1 no contiene un permiso de establecer el modo privilegiado. Puede ser que se haya editado a través de la consola del clúster.
					|
					|Para restaurar la aplicación, se requiere desactivar el uso del perfil de seguridad a través de la consola del clúster, y reconfigurar los perfiles de seguridad utilizando la interfaz de configuraciones (comandos correspondientes están ubicados en la sección de los ajustes del programa).';
					|tr = 'Aşağıdaki nedenlerle oturum parametreleri kurulumu işleyicilerini yürütmek mümkün değildir:
					|güvenlik profili%1 ayrıcalıklı modu ayarlama iznini içermez. 
					|Küme konsolu üzerinden düzenlenmiş olabilir. Uygulamanın geri yüklenmesi için, küme konsolu üzerinden güvenlik profilinin kullanımını devre dışı bırakmak ve yapılandırma arayüzünü kullanarak güvenlik profillerini yeniden yapılandırmak gerekir (karşılık gelen komutlar uygulama ayarlarının bölümünde bulunur).';
					|it = 'Impossibile impostare i parametri di sessione per il seguente motivo: il profilo di sicurezza %1 non contiene il permesso di impostare la modalità privilegiata. Potrebbe essere stato modificato tramite la console del cluster.
					|
					|Per ripristinare la funzionalità del programma, è necessario disabilitare l''uso del profilo di sicurezza tramite la console del cluster e riconfigurare i profili di sicurezza utilizzando l''interfaccia di configurazione (i comandi corrispondenti si trovano nella sezione delle impostazioni del programma).';
					|de = 'Es ist nicht möglich, Sitzungsparameter festzulegen, da das Sicherheitsprofil %1 keine Berechtigung zum Setzen des privilegierten Modus enthält. Es kann über die Cluster-Konsole bearbeitet worden sein.
					|
					|Um die Funktionalität des Programms wiederherzustellen, müssen Sie die Verwendung des Sicherheitsprofils über die Cluster-Konsole deaktivieren und die Sicherheitsprofile über die Konfigurationsschnittstelle neu konfigurieren (die entsprechenden Befehle finden Sie im Abschnitt Programmeinstellungen).'"),
				InfobaseProfile);
			
		EndIf;
		
	Else
		
		// Infobase is not configured to use the security profile that denied full access to external 
		// modules.
		
		Try
			PrivilegedModeAvailable = CanExecuteHandlersWithoutSafeMode();
		Except
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Невозможно установить параметры сеанса по причине: %1.
					|
					|Возможно, для информационной базы через консоль кластера был установлен профиль безопасности, не допускающий выполнения внешних модулей без установки безопасного режима. В этом случае для восстановления работоспособности программы требуется отключить использование профиля безопасности через консоль кластера и заново настроить профили безопасности с помощью интерфейса конфигурации (соответствующие команды находятся в разделе настроек программы). При этом программа будет автоматически корректно настроена на использование совместно с включенными профилями безопасности.'; 
					|en = 'Cannot set the session parameters. Reason: %1.
					|
					|Probably a security profile that does not allow execution of external modules in unsafe mode was set using the cluster console. If this is the case, to restore the application functionality, disable the security profile using the cluster console and reconfigure the security profiles using the configuration interface (see the commands in the application settings section).The application will be automatically configured to use the enabled security profiles.'; 
					|pl = 'Nie można ustawić parametry sesji z powodu: %1 .
					|
					|Być może, dla bazy informacyjnej za pośrednictwem konsoli klastra został ustalony profil bezpieczeństwa, nie dopuszczający do wykonywania zewnętrznych modułów bez zabudowy trybu bezpiecznego. W tym przypadku, w celu przywrócenia działania programu trzeba wyłączyć korzystanie z profilu bezpieczeństwa poprzez konsolę klastra i ponownie skonfigurować profile zabezpieczeń przy użyciu interfejsu konfiguracyjnego (odpowiednie polecenia znajdują się w ustawieniach programu). Program będzie automatycznie poprawnie skonfigurowana do korzystania wspólnie z włączonymi profilami bezpieczeństwa.';
					|es_ES = 'No se puede ejecutar los manipuladores de la configuración de los parámetros de la sesión debido a: %1.
					|
					|Quizás un perfil de seguridad se haya establecido para la infobase a través de la consola del clúster que no permite ejecutar los módulos externos sin la configuración del modo seguro. En este caso, para restaurar la operación de la aplicación, se requiere desactivar el uso del perfil de seguridad a través de la consola del clúster, y reconfigurar los perfiles de seguridad utilizando la interfaz de configuraciones (comandos correspondientes están ubicados en la sección de las configuraciones de la aplicación). Al mismo tiempo, la aplicación se configurará automáticamente para el uso compartido con los perfiles de seguridad activados.';
					|es_CO = 'No se puede ejecutar los manipuladores de la configuración de los parámetros de la sesión debido a: %1.
					|
					|Quizás un perfil de seguridad se haya establecido para la infobase a través de la consola del clúster que no permite ejecutar los módulos externos sin la configuración del modo seguro. En este caso, para restaurar la operación de la aplicación, se requiere desactivar el uso del perfil de seguridad a través de la consola del clúster, y reconfigurar los perfiles de seguridad utilizando la interfaz de configuraciones (comandos correspondientes están ubicados en la sección de las configuraciones de la aplicación). Al mismo tiempo, la aplicación se configurará automáticamente para el uso compartido con los perfiles de seguridad activados.';
					|tr = 'Aşağıdaki nedenlerle oturum parametreleri kurulumu işleyicileri çalıştırılamıyor: %1. 
					|
					|Güvenli modun kurulumu yapılmadan dış modüllerin çalıştırılmasına izin vermeyen küme konsolu üzerinden veritabanı için bir güvenlik profili ayarlanmış olabilir. Bu durumda, uygulama çalışmasını geri yüklemek için, küme konsolu üzerinden güvenlik profilinin kullanımını devre dışı bırakmak ve yapılandırma arayüzünü kullanarak güvenlik profillerini yeniden yapılandırmak gerekir (karşılık gelen komutlar uygulama ayarlarının bölümünde bulunur). Aynı zamanda, uygulama etkin güvenlik profilleri ile paylaşılan kullanım için otomatik olarak yapılandırılacaktır.';
					|it = 'È impossibile impostare i parametri di sessione a causa di: %1.
					|
					|È possibile che sia stato impostato un profilo di sicurezza per il database tramite la console del cluster, impedendo l''esecuzione di moduli esterni senza impostare la modalità sicura. In questo caso, per ripristinare la funzionalità del programma, è necessario disabilitare l''uso del profilo di sicurezza tramite la console del cluster e riconfigurare i profili di sicurezza utilizzando l''interfaccia di configurazione (i comandi corrispondenti si trovano nella sezione delle impostazioni del programma). Allo stesso tempo, il programma verrà automaticamente configurato correttamente per l''utilizzo con i profili di sicurezza inclusi.';
					|de = 'Die Sitzungseinstellungen können nicht festgelegt werden aufgrund von: %1.
					|
					|Es ist möglich, dass über die Cluster-Konsole ein Sicherheitsprofil für die Datenbank eingestellt wurde, das die Ausführung von externen Modulen verhindert, ohne einen sicheren Modus einzurichten. In diesem Fall ist es notwendig, die Verwendung des Sicherheitsprofils über die Cluster-Konsole zu deaktivieren und die Sicherheitsprofile über die Konfigurationsschnittstelle neu zu konfigurieren (die entsprechenden Befehle finden Sie im Abschnitt Programmeinstellungen). Gleichzeitig wird das Programm automatisch korrekt konfiguriert, um zusammen mit den aktivierten Sicherheitsprofilen verwendet zu werden.'"),
				BriefErrorDescription(ErrorInfo()));
			
		EndTry;
		
	EndIf;
	
EndProcedure

// Checks whether the handlers can be executed without safe mode.
//
// Returns:
//   Boolean.
//
Function CanExecuteHandlersWithoutSafeMode()
	
	// The Common.CalculateInSafeMode call is not required as this is a test of the privileged mode 
	// setting in the Calculate without safe mode function.
	Return Eval("SwichingToPrivilegedModeAvailable()");
		
EndFunction

// Checks whether the privilege mode can be set from the current safe mode.
//
// Returns: Boolean.
//
Function SwichingToPrivilegedModeAvailable()
	
	SetPrivilegedMode(True);
	Return PrivilegedMode();
	
EndFunction

// This method is required by RegisterPriorityDataChangeForSubordinateDIBNode procedure.
Procedure RegisterPredefinedItemChanges(DIBExchangePlansNodes, MetadataCollection)
	
	Query = New Query;
	
	For Each MetadataObject In MetadataCollection Do
		DIBNodes = New Array;
		
		For Each ExchangePlanNodes In DIBExchangePlansNodes Do
			If Not ExchangePlanNodes.Key.Contains(MetadataObject) Then
				Continue;
			EndIf;
			For Each DIBNode In ExchangePlanNodes.Value Do
				DIBNodes.Add(DIBNode);
			EndDo;
		EndDo;
		
		If DIBNodes.Count() = 0 Then
			Continue;
		EndIf;
		
		Query.Text =
		"SELECT
		|	CurrentTable.Ref AS Ref
		|FROM
		|	&CurrentTable AS CurrentTable
		|WHERE
		|	CurrentTable.Predefined";
		Query.Text = StrReplace(Query.Text, "&CurrentTable", MetadataObject.FullName());
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			ExchangePlans.RecordChanges(DIBNodes, Selection.Ref);
		EndDo;
	EndDo;
	
EndProcedure

// This method is required by SetFormAssignmentKey procedure.
Procedure SetFormAssignmentUsageKey(Form, varKey, SpecifySettings)
	
	If Not ValueIsFilled(varKey)
	 Or Form.PurposeUseKey = varKey Then
		
		Return;
	EndIf;
	
	If Not SpecifySettings Then
		Form.PurposeUseKey = varKey;
		Return;
	EndIf;
	
	SettingsTypes = New Array;
	// Russian variant.
	SettingsTypes.Add("/CurrentVariantKey");
	SettingsTypes.Add("/CurrentUserSettingsKey");
	SettingsTypes.Add("/CurrentUserSettings");
	SettingsTypes.Add("/CurrentDataSettingsKey");
	SettingsTypes.Add("/CurrentData");
	SettingsTypes.Add("/FormSettings");
	// English variant.
	SettingsTypes.Add("/CurrentVariantKey");
	SettingsTypes.Add("/CurrentUserSettingsKey");
	SettingsTypes.Add("/CurrentUserSettings");
	SettingsTypes.Add("/CurrentDataSettingsKey");
	SettingsTypes.Add("/CurrentData");
	SettingsTypes.Add("/FormSettings");
	If SystemSettingsStorage.Load(varKey, "FormAssignmentRuleKey") <> True 
		 AND AccessRight("SaveUserData", Metadata) Then
		SetSettingsForKey(varKey, SettingsTypes, Form.FormName, Form.PurposeUseKey);
		SystemSettingsStorage.Save(varKey, "FormAssignmentRuleKey", True);
	EndIf;
	
	Form.PurposeUseKey = varKey;
	
EndProcedure

// This method is required by SetFormAssignmentKey procedure.
Procedure SetFormWindowOptionsSaveKey(Form, varKey, SpecifySettings)
	
	If Not ValueIsFilled(varKey)
	 Or Form.WindowOptionsKey = varKey Then
		
		Return;
	EndIf;
	
	If Not SpecifySettings Then
		Form.WindowOptionsKey = varKey;
		Return;
	EndIf;
	
	SettingsTypes = New Array;
	// Russian variant.
	SettingsTypes.Add("/WindowSettings");
	SettingsTypes.Add("/Taxi/WindowSettings");
	SettingsTypes.Add("/WebClientWindowSettings");
	SettingsTypes.Add("/Taxi/WebClientWindowSettings");
	// English variant.
	SettingsTypes.Add("/WindowSettings");
	SettingsTypes.Add("/Taxi/WindowSettings");
	SettingsTypes.Add("/WebClientWindowSettings");
	SettingsTypes.Add("/Taxi/WebClientWindowSettings");
	
	If SystemSettingsStorage.Load(varKey, "FormWindowOptionsKey") <> True 
		AND AccessRight("SaveUserData", Metadata) Then
		SetSettingsForKey(varKey, SettingsTypes, Form.FormName, Form.WindowOptionsKey);
		SystemSettingsStorage.Save(varKey, "FormWindowOptionsKey", True);
	EndIf;
	
	Form.WindowOptionsKey = varKey;
	
EndProcedure

// This method is required by SetFormAssignmentUseKey and SetFormWindowOptionsSaveKey procedures.
Procedure SetSettingsForKey(varKey, SettingsTypes, FormName, CurrentKey)
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Return;
	EndIf;
	
	NewKey = "/" + varKey;
	Filter = New Structure;
	Filter.Insert("User", InfoBaseUsers.CurrentUser().Name);
	
	For each SettingsType In SettingsTypes Do
		Filter.Insert("ObjectKey", FormName + NewKey + SettingsType);
		Selection = SystemSettingsStorage.Select(Filter);
		If Selection.Next() Then
			Return; // Key settings are already set.
		EndIf;
	EndDo;
	
	If ValueIsFilled(CurrentKey) Then
		CurrentKey = "/" + CurrentKey;
	EndIf;
	
	// Setting the initial settings key by copying them from the current key.
	For Each SettingsType In SettingsTypes Do
		Filter.Insert("ObjectKey", FormName + CurrentKey + SettingsType);
		Selection = SystemSettingsStorage.Select(Filter);
		ObjectKey = FormName + NewKey + SettingsType;
		While Selection.Next() Do
			SettingsDetails = New SettingsDescription;
			SettingsDetails.Presentation = Selection.Presentation;
			SystemSettingsStorage.Save(ObjectKey, Selection.SettingsKey,
				Selection.Settings, SettingsDetails);
		EndDo;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Initial filling of items with data.

Procedure AddPredefinedDataTableColumn(PredefinedData, Attribute, AttributesToLocalize, Languages)
	
	If AttributesToLocalize[Attribute.Name] = True Then
		PredefinedData.Columns.Add(Attribute.Name, Attribute.Type, AttributeToLocalizeFlag());
		For each Language In Languages Do
			PredefinedData.Columns.Add(Attribute.Name + "_" + Language, Attribute.Type, AttributeToLocalizeFlag());
		EndDo;
	Else
		If IsAttributeToLocalize(Attribute) Then
			NameWithoutSuffix = NameWithoutSuffixLanguage(Attribute);
			AttributesToLocalize.Insert(NameWithoutSuffix, True);
			For each Language In Languages Do
				PredefinedData.Columns.Add(NameWithoutSuffix + "_" + Language, Attribute.Type, AttributeToLocalizeFlag());
			EndDo;
		Else
			PredefinedData.Columns.Add(Attribute.Name, Attribute.Type);
		EndIf;
	EndIf;

EndProcedure

Function UpdatePredefinedObjectItemsPresentations(ObjectRef, MetadataObject)
	
	Result = New Structure();
	Result.Insert("ObjectsWithIssues", 0);
	Result.Insert("ObjectsProcessed", 0);
	
	MainLanguage = CommonClientServer.DefaultLanguageCode();
	Language1Code = NativeLanguagesSupportServer.FirstAdditionalInfobaseLanguageCode();
	Language2Code = NativeLanguagesSupportServer.SecondAdditionalInfobaseLanguageCode();
	Language3Code = NativeLanguagesSupportServer.ThirdAdditionalInfobaseLanguageCode();
	Language4Code = NativeLanguagesSupportServer.FourthAdditionalInfobaseLanguageCode();
	
	ObjectAttributesToLocalize = NativeLanguagesSupportServer.ObjectAttributesToLocalizeDescriptions(MetadataObject);
	
	ObjectManager = Common.ObjectManagerByFullName(MetadataObject.FullName());
	
	PredefinedData = PredefinedObjectData(MetadataObject, ObjectManager, ObjectAttributesToLocalize);
	PredefinedItemsSettings = PredefinedItemsSettings(ObjectManager, PredefinedData);
	
	While ObjectRef.Next() Do
		
		Try
			
			PredefinedDataName = Common.ObjectAttributeValue(ObjectRef.Ref, "PredefinedDataName");
			If Not ValueIsFilled(PredefinedDataName) Then
				InfobaseUpdate.MarkProcessingCompletion(ObjectRef.Ref);
				Continue;
			EndIf;
			
			Item = PredefinedData.Find(PredefinedDataName, "PredefinedDataName");
			If Item <> Undefined Then
				Object = ObjectRef.Ref.GetObject();
				
				For each ObjectAttributeToLocalize In ObjectAttributesToLocalize Do
					Name = ObjectAttributeToLocalize.Key;
					Object[Name] = Item[NativeLanguagesSupportServer.NameOfAttributeToLocalize(Name, MainLanguage)];
					
					If NativeLanguagesSupportServer.FirstAdditionalLanguageUsed() Then
						Object[Name + "Language1"] = Item[NativeLanguagesSupportServer.NameOfAttributeToLocalize(Name, Language1Code)];
					EndIf;
					If NativeLanguagesSupportServer.SecondAdditionalLanguageUsed() Then
						Object[Name + "Language2"] = Item[NativeLanguagesSupportServer.NameOfAttributeToLocalize(Name, Language2Code)];
					EndIf;
					If NativeLanguagesSupportServer.ThirdAdditionalInfobaseLanguageCode() Then
						Object[Name + "Language3"] = Item[NativeLanguagesSupportServer.NameOfAttributeToLocalize(Name, Language3Code)];
					EndIf;
					If NativeLanguagesSupportServer.FourthAdditionalInfobaseLanguageCode() Then
						Object[Name + "Language4"] = Item[NativeLanguagesSupportServer.NameOfAttributeToLocalize(Name, Language4Code)];
					EndIf;
					
				EndDo;
				InfobaseUpdate.WriteData(Object);
				
			EndIf;
			Result.ObjectsProcessed = Result.ObjectsProcessed + 1;
			
		Except
			// If an item cannot be processed, try again.
			Result.ObjectsWithIssues = Result.ObjectsWithIssues + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось обработать элемент: %1. Причина: %2'; en = 'Cannot process the item: %1. Reason: %2'; pl = 'Nie można przetworzyć pozycji: %1. Przyczyna: %2';es_ES = 'No puede procesar el artículo: %1. Razón: %2';es_CO = 'No puede procesar el artículo: %1. Razón: %2';tr = 'Nesne işlenemiyor: %1. Sebep: %2';it = 'Non è stato possibile elaborare il documento: %1 a causa di: %2';de = 'Kann die Position nicht bearbeiten: %1. Grund: %2'"),
				ObjectRef.Ref, DetailErrorDescription(ErrorInfo()));
				
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
			MetadataObject, ObjectRef.Ref, MessageText);
			
		EndTry;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function NameWithoutSuffixLanguage(Val Attribute)
	
	Return Left(Attribute.Name, StrLen(Attribute.Name) - 5);

EndFunction

Function IsAttributeToLocalize(Attribute)
	Return StrEndsWith(Attribute.Name, "Language1") Or StrEndsWith(Attribute.Name, "Language2");
EndFunction

Function AttributeToLocalizeFlag()
	Return "ToLocalize";
EndFunction

Function ConfigurationLanguages()
	
	Languages = New Array;
	For each Language In Metadata.Languages Do
		Languages.Add(Language.LanguageCode);
	EndDo;
	Return Languages;

EndFunction

Function ObjectsWithInitialFilling()
	
	SubsystemSettings = InfobaseUpdateInternal.SubsystemSettings();
	ObjectsWithInitialFilling = SubsystemSettings.ObjectsWithInitialFilling;
	Return ObjectsWithInitialFilling;
	
EndFunction

Function PredefinedItemsSettings(ObjectManager, PredefinedData)
	
	ItemsFillingSettings = New Structure;
	ItemsFillingSettings.Insert("OnInitialItemFilling", False);
	ItemsFillingSettings.Insert("AdditionalParameters", New Structure);
	ItemsFillingSettings.AdditionalParameters.Insert("PredefinedData", PredefinedData);
	
	ObjectManager.OnSetUpInitialItemsFilling(ItemsFillingSettings);
	
	Return ItemsFillingSettings;
	
EndFunction

Function PredefinedObjectData(Val ObjectMetadata, ObjectManager, ObjectAttributesToLocalize)
	
	Languages = ConfigurationLanguages();
	
	PredefinedData = New ValueTable;
	
	For Each Attribute In ObjectMetadata.StandardAttributes Do
		AddPredefinedDataTableColumn(PredefinedData, Attribute, ObjectAttributesToLocalize, Languages);
	EndDo;
	
	For Each Attribute In ObjectMetadata.Attributes Do
		AddPredefinedDataTableColumn(PredefinedData, Attribute, ObjectAttributesToLocalize, Languages);
	EndDo;
	
	If PredefinedData.Columns.Find("PredefinedDataName") <> Undefined Then
		PredefinedData.Indexes.Add("PredefinedDataName");
	EndIf;
	
	ObjectManager.OnInitialItemsFilling(Languages, PredefinedData);
	Return PredefinedData;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions.

// This method is required by OnFillPermissionsToAccessExternalResources procedure.
Procedure AddRequestForPermissionToUseExtensions(PermissionRequests)
	
	If Common.DataSeparationEnabled()
	   AND Common.SeparatedDataUsageAvailable() Then
		
		Return;
	EndIf;
	
	Permissions = New Array;
	AllExtensions = ConfigurationExtensions.Get();
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	For Each Extension In AllExtensions Do
		Permissions.Add(ModuleSafeModeManager.PermissionToUseExternalModule(
			Extension.Name, Base64String(Extension.HashSum)));
	EndDo;
	
	PermissionRequests.Add(ModuleSafeModeManager.RequestToUseExternalResources(Permissions,
		Common.MetadataObjectID("InformationRegister.ExtensionVersionParameters")));

EndProcedure

Function MustShowRAMSizeRecommendations()
	
	If CommonClientServer.IsWebClient()
		OR CommonClientServer.IsMobileClient()
		OR Not Common.FileInfobase() Then
		
		Return False;
		
	EndIf;
	
	RAM = ClientParametersAtServer().Get("RAM");
	If TypeOf(RAM) <> Type("Number") Then
		Return False; // The client parameter on the server is not filled (there is no client application).
	EndIf;
	
	RecommendedSize = Common.CommonCoreParameters().RecommendedRAM;
	SavedRecommendation = Common.CommonSettingsStorageLoad("UserCommonSettings",
		"RAMRecommendation");
	
	Recommendation = New Structure;
	Recommendation.Insert("Show", True);
	Recommendation.Insert("PreviousShowDate", Date(1, 1, 1));
	
	If TypeOf(SavedRecommendation) = Type("Structure") Then
		FillPropertyValues(Recommendation, SavedRecommendation);
	EndIf;
	
	Return RAM < RecommendedSize
		AND (Recommendation.Show
		   Or (CurrentSessionDate() - Recommendation.PreviousShowDate) > 60*60*24*60)
	
EndFunction

Procedure IgnoreSendingDataProcessedOnMasterDIBNodeOnInfobaseUpdate(DataItem, InitialImageCreation, Recipient)
	
	Var Index, SetRow;
	
	If Recipient <> Undefined
		AND Not InitialImageCreation
		AND TypeOf(DataItem) = Type("InformationRegisterRecordSet.DataProcessedInMasterDIBNode") Then
		
		Index = DataItem.Count() - 1;
		
		While Index > 0 Do
			
			SetRow = DataItem[Index];
			
			If SetRow.ExchangePlanNode <> Recipient Then
				DataItem.Delete(SetRow);
			EndIf;
			
			Index = Index - 1;
			
		EndDo;
		
	EndIf;

EndProcedure

// Fills a parameter structure required for this subsystem client script execution.
// 
//
// Parameters:
//   Parameters - Structure - a parameter structure.
//
Procedure AddClientParameters(Parameters) Export
	
	Parameters.Insert("SubsystemNames", StandardSubsystemsCached.SubsystemNames());
	Parameters.Insert("SeparatedDataUsageAvailable",
		Common.SeparatedDataUsageAvailable());
	Parameters.Insert("DataSeparationEnabled", Common.DataSeparationEnabled());
	
	Parameters.Insert("IsBaseConfigurationVersion", IsBaseConfigurationVersion());
	Parameters.Insert("IsTrainingPlatform", IsTrainingPlatform());
	Parameters.Insert("COMConnectorName", CommonClientServer.COMConnectorName());
	
	AddCommonClientParameters(Parameters);
	
	Parameters.Insert("ConfigurationName",     Metadata.Name);
	Parameters.Insert("ConfigurationSynonym", Metadata.Synonym);
	Parameters.Insert("ConfigurationVersion",  Metadata.Version);
	Parameters.Insert("DetailedInformation", Metadata.DetailedInformation);
	Parameters.Insert("DefaultLanguageCode",   Metadata.DefaultLanguage.LanguageCode);
	
	Parameters.Insert("AskConfirmationOnExit",
		AskConfirmationOnExit());
	
	Parameters.Insert("FileInfobase", Common.FileInfobase());
	
	If ScheduledJobsServer.OperationsWithExternalResourcesLocked() Then
		Parameters.Insert("OperationsWithExternalResourcesLocked");
	EndIf;
	
EndProcedure

// Deletes password hashes and changes the settings storage structure.
//
Procedure UpdateInfobaseAdministrationParameters() Export
	
	SetPrivilegedMode(True);
	
	OldParameterValue = Constants.IBAdministrationParameters.Get().Get();
	NewParameterValue = DefaultAdministrationParameters();
	
	If OldParameterValue <> Undefined Then
		
		If OldParameterValue.Property("InfobaseAdministratorName") Then
			Return; // The parameters have already been updated.
		EndIf;
		
		If OldParameterValue.Property("ServerAgentPort")
			AND ValueIsFilled(OldParameterValue.ServerAgentPort) Then
			NewParameterValue.ServerAgentPort = OldParameterValue.ServerAgentPort;
		EndIf;
		
		If OldParameterValue.Property("ServerClusterPort")
			AND ValueIsFilled(OldParameterValue.ServerClusterPort) Then
			NewParameterValue.ClusterPort = OldParameterValue.ServerClusterPort;
		EndIf;
		
		If OldParameterValue.Property("ClusterAdministratorName")
			AND Not IsBlankString(OldParameterValue.ClusterAdministratorName) Then
			NewParameterValue.ClusterAdministratorName = OldParameterValue.ClusterAdministratorName;
		EndIf;
		
		If OldParameterValue.Property("IBAdministratorName")
			AND Not IsBlankString(OldParameterValue.IBAdministratorName) Then
			NewParameterValue.InfobaseAdministratorName = OldParameterValue.IBAdministratorName;
		EndIf;
		
	EndIf;
	
	SetAdministrationParameters(NewParameterValue);
	
EndProcedure

// Updates the Master node constant value in SWP nodes.
//
Procedure SetMasterNodeConstantValue() Export
	
	If Common.IsStandaloneWorkplace() Then
		SaveMasterNode();
	EndIf;
	
EndProcedure

// Intended for moving passwords to a secure storage.
// This procedure is used in the infobase update handler.
Procedure MovePasswordsToSecureStorageSharedData() Export

	// Data exchange
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.MovePasswordsToSecureStorage();
	EndIf;
	
EndProcedure

// Intended for moving passwords to a secure storage.
// This procedure is used in the infobase update handler.
Procedure MovePasswordsToSecureStorage() Export
	
	// Authentication on the user site.
	Result = New Structure("Username,Password");
	Result.Username = Common.CommonSettingsStorageLoad("AuthenticationOnSupportSite", "UserCode", "");
	Result.Password = Common.CommonSettingsStorageLoad("AuthenticationOnSupportSite", "Password", "");
	If NOT IsBlankString(Result.Username) Then
		Owner = Common.MetadataObjectID("Catalog.MetadataObjectIDs");
		SetPrivilegedMode(True);
		Common.WriteDataToSecureStorage(Owner, Result.Username, "Username");
		Common.WriteDataToSecureStorage(Owner, Result.Password);
		SetPrivilegedMode(False);
	EndIf;
	
	// SMS sending subsystem
	If Common.SubsystemExists("StandardSubsystems.SMS") Then
		ModuleSMS = Common.CommonModule("SMS");
		ModuleSMS.MovePasswordsToSecureStorage();
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailInternal = Common.CommonModule("EmailOperationsInternal");
		ModuleEmailInternal.MovePasswordsToSecureStorage();
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistribution = Common.CommonModule("ReportMailing");
		ModuleReportDistribution.MovePasswordsToSecureStorage();
	EndIf;
	
EndProcedure

Function MetadataObjectsPresentation(Objects)
	
	Result = New Array;
	
	For Each Object In Objects Do
		
		Result.Add(Object.FullName());
		
	EndDo;
	
	Return Result;
EndFunction

#EndRegion
