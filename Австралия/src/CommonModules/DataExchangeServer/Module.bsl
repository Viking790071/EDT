#Region Public

// Gets the exchange plan setting value by the setting name.
// For non-existent settings, Undefined is returned.
// 
// Parameters:
//   ExchangePlanName         - String - a name of the exchange plan from the metadata.
//   ParameterNameĀ            - String - an exchange plan parameter name or list of parameters separated by commas.
//                                     For the list of allowed values, see functions DefaultExchangePlanSettings,
//                                     ExchangeSettingOptionDetailsByDefault.
//   SetupID - String - a name of a predefinedĀ setting of exchange plan.
//   CorrespondentVersion   - String - correspondent configuration version.
// 
// Returns:
//   Arbitrary - the type of a value to return depends on the type of value of the setting being received.
//   Structure - if the ParameterName contains a list of comma-separated parameters.
//
Function ExchangePlanSettingValue(ExchangePlanName, ParameterName, SettingID = "", CorrespondentVersion = "") Export
	
	ParameterValue = New Structure;
	ExchangePlanSettings = Undefined;
	SettingOptionDetails = Undefined;
	ParameterName = StrReplace(ParameterName, Chars.LF, "");
	ParametersNames = StringFunctionsClientServer.SplitStringIntoSubstringsArray(ParameterName,,True);
	DefaultExchangePlanSettings = DefaultExchangePlanSettings(ExchangePlanName);
	DefaultOptionDetails = ExchangeSettingOptionDetailsByDefault(ExchangePlanName);
	If ParametersNames.Count() = 0 Then
		Return Undefined;
	EndIf;
	For Each SingleParameter In ParametersNames Do
		SingleParameterValue = Undefined;
		If DefaultExchangePlanSettings.Property(SingleParameter) Then
			If ExchangePlanSettings = Undefined Then
				ExchangePlanSettings = DataExchangeCached.ExchangePlanSettings(ExchangePlanName);
			EndIf;
			ExchangePlanSettings.Property(SingleParameter, SingleParameterValue);
		ElsIf DefaultOptionDetails.Property(SingleParameter) Then
			If SettingOptionDetails = Undefined Then
				SettingOptionDetails = DataExchangeCached.SettingOptionDetails(ExchangePlanName, SettingID, CorrespondentVersion);
			EndIf;
			SettingOptionDetails.Property(SingleParameter, SingleParameterValue);
		EndIf;
		If ParametersNames.Count() = 1 Then
			Return SingleParameterValue;
		Else
			ParameterValue.Insert(SingleParameter, SingleParameterValue);
		EndIf;
	EndDo;
	Return ParameterValue;
	
EndFunction

// OnCreateAtServer event handler for the exchange plan node form.
//
// Parameters:
//  Form - ClientApplicationForm - a form the procedure is called from.
//  Cancel - Boolean           - a flag showing whether form creation is denied. If this parameter is set to True, the form is not created.
// 
Procedure NodeFormOnCreateAtServer(Form, Cancel) Export
	
	If Form.Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	ExchangePlanPresentation = ExchangePlanSettingValue(
		Form.Object.Ref.Metadata().Name,
		"ExchangePlanNodeTitle",
		DataExchangeOption(Form.Object.Ref));
	
	Form.AutoTitle = False;
	Form.Title = StringFunctionsClientServer.SubstituteParametersToString(Form.Object.Description + " (%1)",
		ExchangePlanPresentation);
	
EndProcedure

// OnWriteAtServer event handler for the exchange plan node form.
//
// Parameters:
//  CurrentObject - ExchangePlanObject - an exchange plan node to be written.
//  Cancel         - Boolean           - the incoming parameter showing whether writing the exchange node is canceled.
//                                     If it is set to True, synchronization setup completion is not 
//                                     committed for the node.
//
Procedure NodeFormOnWriteAtServer(CurrentObject, Cancel) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	If Not SynchronizationSetupCompleted(CurrentObject.Ref) Then
		CompleteDataSynchronizationSetup(CurrentObject.Ref);
	EndIf;
	
EndProcedure

// OnCreateAtServer event handler for the node setup form.
//
// Parameters:
//  Form          - ClientApplicationForm - a form the procedure is called from.
//  ExchangePlanName - String           - a name of the exchange plan the form is created for.
// 
Procedure NodeSettingsFormOnCreateAtServer(Form, ExchangePlanName) Export
	
	If Form.Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	SettingID = "";
	
	If Form.Parameters.Property("SettingID") Then
		SettingID = Form.Parameters.SettingID;
	EndIf;
	
	CheckMandatoryFormAttributes(Form, "NodeFilterStructure, CorrespondentVersion");
	
	Form.CorrespondentVersion   = Form.Parameters.CorrespondentVersion;
	Form.NodeFilterStructure = NodeFilterStructure(ExchangePlanName, Form.CorrespondentVersion, SettingID);
	
	NodeSettingsFormOnCreateAtServerHandler(Form, "NodeFilterStructure");
	
EndProcedure

// Determines whether the AfterDataExport event handler must be executed on exchange in the DIB.
//
// Parameters:
//  Object - ExchangePlanObject - an exchange plan for which the handler is executed.
//  Ref - ExchangePlanObject - a reference to an exchange plan for which the handler is executed.
//
// Returns:
//   Boolean - True if the AfterDataExport handler must be executed. Otherwise, False.
//
Function MustExecuteHandlerAfterDataExport(Object, Ref) Export
	
	Return MustExecuteHandler(Object, Ref, "SentNo");
	
EndFunction

// Determines whether the AfterDataImport event handler is to be executed upon exchange in DIB.
//
// Parameters:
//  Object - ExchangePlanObject - an exchange plan for which the handler is executed.
//  Ref - ExchangePlanObject - a reference to an exchange plan for which the handler is executed.
//
// Returns:
//   Boolean - True if the AfterDataImport handler must be executed. Otherwise, False.
//
Function MustExecuteHandlerAfterDataImport(Object, Ref) Export
	
	Return MustExecuteHandler(Object, Ref, "ReceivedNo");
	
EndFunction

// Returns a prefix of the current infobase.
//
// Returns:
//   String - this infobase prefix.
//
Function InfobasePrefix() Export
	
	Return GetFunctionalOption("InfobasePrefix");
	
EndFunction

// Returns the correspondent configuration version.
// If the correspondent configuration version is not defined, returns an empty version - 0.0.0.0.
//
// Parameters:
//  CorrespondentĀ - ExchangePlanObject - a reference to an exchange plan for which you need to get the configuration version.
// 
// Returns:
//  String - correspondent configuration version.
//
// Example:
//  If CommonClientServer.CompareVersions(DataExchangeServer.CorrespondentVersion(Correspondent), "2.1.5.1")
//  >= 0 Then ...
//
Function CorrespondentVersion(Val Correspondent) Export
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.CommonInfobasesNodesSettings.CorrespondentVersion(Correspondent);
EndFunction

// Sets prefix for the current infobase.
//
// Parameters:
//   Prefix - String - a new value of the infobase prefix.
//
Procedure SetInfobasePrefix(Val Prefix) Export
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsPrefixes")
		AND Not OpenDataExchangeCreationWizardForSubordinateNodeSetup() Then
		
		ModuleObjectPrefixesInternal = Common.CommonModule("ObjectsPrefixesInternal");
		
		PrefixChangeParameters = New Structure("NewIBPrefix, ContinueNumbering",
			TrimAll(Prefix), True);
		ModuleObjectPrefixesInternal.ChangeIBPrefix(PrefixChangeParameters);
		
	Else
		// Data changes to renumber directories and documents must not be performed
		// - If the prefix system is not embedded.
		// - On the first start of the subordinate DIB node.
		Constants.DistributedInfobaseNodePrefix.Set(TrimAll(Prefix));
	EndIf;
	
	DataExchangeServerCall.ResetObjectsRegistrationMechanismCache();
	
EndProcedure

// Checks whether the current infobase is restored from backup.
// If the infobase is restored from backup, numbers of sent and received messages must be 
// synchronized for the infobases. Number of a sent message in the current infobase is set equal to 
// the received message number in the correspondent infobase.
// If the infobase is restored from backup, we recommend that you do not delete change registration 
// on the current infobase node because this data might not have been sent to the correspondent infobase yet.
//
// Parameters:
//   Sender    - ExchangePlanRef - a node on behalf of which the exchange message was created and sent.
//   ReceivedMessageNumber - Number            - a number of received message in the correspondent infobase.
//
// Returns:
//   FixedStructure - structure properties:
//     * Sender                 - ExchangePlanRef - see the Sender parameter above.
//     * ReceivedMessageNumber              - Number            - see the ReceivedMessageNumber parameter above.
//     * BackupRestored - Boolean - True if the infobase is restored from backup.
//
Function BackupParameters(Val Sender, Val ReceivedMessageNumber) Export
	
	// For the base restored from backup, the number of sent message is less than the number of received 
	// message in the correspondent.
	// It means that the base receives the number of the received message that it has not sent yet, "a 
	// message from the future".
	Result = New Structure("Sender, ReceivedNo, BackupRestored");
	Result.Sender = Sender;
	Result.ReceivedNo = ReceivedMessageNumber;
	Result.BackupRestored = (ReceivedMessageNumber > Common.ObjectAttributeValue(Sender, "SentNo"));
	
	Return New FixedStructure(Result);
EndFunction

// Synchronizes numbers of sent and received messages for both infobases. In the current infobase, 
// sent message number is set to the value of the received message number in the correspondent 
// infobase.
//
// Parameters:
//   BackupParameters - FixedStructure - structure properties:
//     * Sender                 - ExchangePlanRef - a node on behalf of which the exchange message 
//                                                        is created and sent.
//     * ReceivedMessageNumber              - Number            - a number of received message in the correspondent infobase.
//     * BackupRestored - Boolean           - shows whether the current infobase is restored from the backup.
//
Procedure OnRestoreFromBackup(Val BackupParameters) Export
	
	If BackupParameters.BackupRestored Then
		
		// Setting sent message number in the current infobase equal to the received message number in the correspondent infobase.
		NodeObject = BackupParameters.Sender.GetObject();
		NodeObject.SentNo = BackupParameters.ReceivedNo;
		NodeObject.DataExchange.Load = True;
		NodeObject.Write();
		
	EndIf;
	
EndProcedure

// Returns an ID of the saved exchange plan setting option.
// Parameters:
//   ExchangePlanNode - ExchangePlanRef - an exchange plan node to get predefined name for.
//                                                
//
// Returns:
//  String - saved setting ID as it is set in Designer.
//
Function SavedExchangePlanNodeSettingOption(ExchangePlanNode) Export
	
	SetupOption = "";
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangePlanNode);
	
	If Common.HasObjectAttribute("SettingsMode", ExchangePlanNode.Metadata()) Then
		
		SetPrivilegedMode(True);
		SetupOption = Common.ObjectAttributeValue(ExchangePlanNode, "SettingsMode");
		
	EndIf;
	
	Return SetupOption;
	
EndFunction

// Returns an array of all exchange message transport kinds defined in the configuration.
//
// Returns:
//   Array - array items have the EnumRef.ExchangeMessageTransportKinds type.
//
Function AllConfigurationExchangeMessagesTransports() Export
	
	Result = New Array;
	Result.Add(Enums.ExchangeMessagesTransportTypes.COM);
	Result.Add(Enums.ExchangeMessagesTransportTypes.WS);
	Result.Add(Enums.ExchangeMessagesTransportTypes.FILE);
	Result.Add(Enums.ExchangeMessagesTransportTypes.FTP);
	Result.Add(Enums.ExchangeMessagesTransportTypes.EMAIL);
	Result.Add(Enums.ExchangeMessagesTransportTypes.WSPassiveMode);
	
	Return Result;
EndFunction

// Sends or receives data for an infobase node using any of the communication channels available for 
// the exchange plan, except for COM connection and web service.
//
// Parameters:
//  Cancel                        - Boolean - a cancellation flag. True if errors occurred when 
//                                 running the procedure.
//  InfobaseNode - EchangeNodeRef - ExchangePlanRef - an exchange plan node, for which data is being 
//                                 exchanged.
//  ActionOnExchange            - EnumRef.ActionsOnExchange - a running data exchange action.
//  ExchangeMessagesTransportKindĀ - EnumRef.Enumerations.ExchangeMessagesTransportKinds - a 
//                                 transport kind that will be used in the data exchange. If it is 
//                                 not specified, it is determined from transport parameters 
//                                 specified for the exchange plan node on exchange setup. Optional, the default value is Undefined.
//  ParametersOnly              - Boolean - indicates that data are imported selectively on DIB exchange.
//  AdditionalParameters      - Structure - reserved for internal use.
// 
Procedure ExecuteExchangeActionForInfobaseNode(
		Cancel,
		InfobaseNode,
		ActionOnExchange,
		ExchangeMessagesTransportKind = Undefined,
		Val ParametersOnly = False,
		AdditionalParameters = Undefined) Export
		
	If AdditionalParameters = Undefined Then
		AdditionalParameters = New Structure;
	EndIf;
		
	SetPrivilegedMode(True);
	
	// INITIALIZING DATA EXCHANGE
	ExchangeSettingsStructure = DataExchangeCached.ExchangeSettingsOfInfobaseNode(
		InfobaseNode, ActionOnExchange, ExchangeMessagesTransportKind);
	
	If ExchangeSettingsStructure.Cancel Then
		
		// If settings contain errors, canceling the exchange.
		AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
		
		Cancel = True;
		
		Return;
	EndIf;
	
	For Each Parameter In AdditionalParameters Do
		ExchangeSettingsStructure.AdditionalParameters.Insert(Parameter.Key, Parameter.Value);
	EndDo;
	
	ExchangeSettingsStructure.ExchangeExecutionResult = Undefined;
	ExchangeSettingsStructure.StartDate = CurrentSessionDate();
	
	MessageString = NStr("ru = 'ŠŠ°ŃŠ°Š»Š¾ ŠæŃŠ¾ŃŠµŃŃŠ° Š¾Š±Š¼ŠµŠ½Š° Š“Š°Š½Š½ŃŠ¼Šø Š“Š»Ń ŃŠ·Š»Š° %1'; en = 'Data exchange process started for %1 node'; pl = 'PoczÄtek procesu wymiany danych dla wÄzÅa %1';es_ES = 'Inicio de proceso de intercambio de datos para el nodo %1';es_CO = 'Inicio de proceso de intercambio de datos para el nodo %1';tr = '%1Ćnite iĆ§in veri deÄiÅimi sĆ¼reci baÅlatÄ±lÄ±yor';it = 'Il processo di scambio dati iniziato per il nodo %1';de = 'Datenaustausch beginnt fĆ¼r Knoten %1'", CommonClientServer.DefaultLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, ExchangeSettingsStructure.InfobaseNodeDescription);
	WriteEventLogDataExchange(MessageString, ExchangeSettingsStructure);
	
	// DATA EXCHANGE
	ExecuteDataExchangeOverFileResource(ExchangeSettingsStructure, ParametersOnly);
	
	AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
	
	For Each Parameter In ExchangeSettingsStructure.AdditionalParameters Do
		AdditionalParameters.Insert(Parameter.Key, Parameter.Value);
	EndDo;
	
	If Not ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

// Returns the count of unresolved data exchange issues. It is used to display the number of 
// exchange issues in the user interface. For example, it can be used in a hyperlink title to 
// navigate to the exchange issue monitor.
//
// Parameters:
//   Nodes - Array - an array of ExchangePlanRef values.
//
// Returns:
//   Number - the number of unresolved data exchange issues.
// 
Function UnresolvedIssuesCount(Nodes = Undefined) Export
	
	Return DataExchangeIssueCount(Nodes) + VersioningIssuesCount(Nodes);
	
EndFunction

// Returns a structure of title of the hyperlink to navigate to the data exchange issue monitor.
// 
// Parameters:
//   Nodes - Array - an array of ExchangePlanRef values.
//
// Returns:
//	Structure - with the following properties:
//	  * Title - String   - a hyperlink title.
//	  * Picture  - Picture - a picture for the hyperlink.
//
Function IssueMonitorHyperlinkTitleStructure(Nodes = Undefined) Export
	
	Count = UnresolvedIssuesCount(Nodes);
	
	If Count > 0 Then
		
		Header = NStr("ru = 'ŠŃŠµŠ“ŃŠæŃŠµŠ¶Š“ŠµŠ½ŠøŃ (%1)'; en = 'Warnings (%1)'; pl = 'OstrzeÅ¼enia (%1)';es_ES = 'Avisos (%1)';es_CO = 'Avisos (%1)';tr = 'UyarÄ±lar (%1)';it = 'Avvisi (%1)';de = 'Warnungen (%1)'");
		Header = StringFunctionsClientServer.SubstituteParametersToString(Header, Count);
		Picture = PictureLib.Warning;
		
	Else
		
		Header = NStr("ru = 'ŠŃŠµŠ“ŃŠæŃŠµŠ¶Š“ŠµŠ½ŠøŠ¹ Š½ŠµŃ'; en = 'No warnings to display'; pl = 'Brak ostrzeÅ¼eÅ';es_ES = 'No hay avisos';es_CO = 'No hay avisos';tr = 'UyarÄ± yok';it = 'Nessun avviso da mostrare';de = 'Keine Warnungen'");
		Picture = New Picture;
		
	EndIf;
	
	TitleStructure = New Structure;
	TitleStructure.Insert("Title", Header);
	TitleStructure.Insert("Picture", Picture);
	
	Return TitleStructure;
	
EndFunction

// It determines whether the FTP server has the directory.
//
// Parameters:
//  Path - String - path to the file directory.
//  DirectoryName - String - a file directory name.
//  FTPConnection - FTPConnection - FTPConnection used to connect to the FTP server.
// 
// Returns:
//  Boolean - if True, the directory exists. Oherwise, False.
//
Function FTPDirectoryExists(Val Path, Val DirectoryName, Val FTPConnection) Export
	
	For Each FTPFile In FTPConnection.FindFiles(Path) Do
		
		If FTPFile.IsDirectory() AND FTPFile.Name = DirectoryName Then
			
			Return True;
			
		EndIf;
		
	EndDo;
	
	Return False;
EndFunction

// Returns table data for exchange node attributes.
// 
// Parameters:
//  Tables        - Array - an array of strings containing names of exchange plan node attributes.
//  ExchangePlanName - String - an exchange plan name.
// 
// Returns:
//  Map - a map of tables and their data.
//
Function CorrespondentTablesData(Tables, Val ExchangePlanName) Export
	
	Result = New Map;
	ExchangePlanAttributes = Metadata.ExchangePlans[ExchangePlanName].Attributes;
	
	For Each Item In Tables Do
		
		Attribute = ExchangePlanAttributes.Find(Item);
		
		If Attribute <> Undefined Then
			
			AttributeTypes = Attribute.Type.Types();
			
			If AttributeTypes.Count() <> 1 Then
				
				MessageString = NStr("ru = 'Š”Š¾ŃŃŠ°Š²Š½Š¾Š¹ ŃŠøŠæ Š“Š°Š½Š½ŃŃ Š“Š»Ń Š·Š½Š°ŃŠµŠ½ŠøŠ¹ ŠæŠ¾ ŃŠ¼Š¾Š»ŃŠ°Š½ŠøŃ Š½Šµ ŠæŠ¾Š“Š“ŠµŃŠ¶ŠøŠ²Š°ŠµŃŃŃ.
					|Š ŠµŠŗŠ²ŠøŠ·ŠøŃ ""%1"".'; 
					|en = 'Composite data type is not supported for default values.
					|Attribute ""%1"".'; 
					|pl = 'Typ danych zÅoÅ¼onych nie jest obsÅugiwany przez wartoÅci domyÅlne.
					|Atrybut %1.';
					|es_ES = 'Tipo de datos compuestos no estĆ” admitido por los valores por defecto.
					|Atributo %1.';
					|es_CO = 'Tipo de datos compuestos no estĆ” admitido por los valores por defecto.
					|Atributo %1.';
					|tr = 'BileÅik veri tĆ¼rĆ¼, varsayÄ±lan deÄerler tarafÄ±ndan desteklenmez.
					|Ćzellik ""%1"".';
					|it = 'Il tipo di dati composto non ĆØ supportato per valori predefiniti.
					|Attributo ""%1"".';
					|de = 'Zusammengesetzter Datentyp wird von Standardwerten nicht unterstĆ¼tzt.
					|Attribut %1.'");
				MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, Attribute.FullName());
				Raise MessageString;
			EndIf;
			
			MetadataObject = Metadata.FindByType(AttributeTypes.Get(0));
			
			If Not Common.IsCatalog(MetadataObject) Then
				
				MessageString = NStr("ru = 'ŠŃŠ±Š¾Ń Š·Š½Š°ŃŠµŠ½ŠøŠ¹ ŠæŠ¾ ŃŠ¼Š¾Š»ŃŠ°Š½ŠøŃ ŠæŠ¾Š“Š“ŠµŃŠ¶ŠøŠ²Š°ŠµŃŃŃ ŃŠ¾Š»ŃŠŗŠ¾ Š“Š»Ń ŃŠæŃŠ°Š²Š¾ŃŠ½ŠøŠŗŠ¾Š².
					|Š ŠµŠŗŠ²ŠøŠ·ŠøŃ ""%1"".'; 
					|en = 'Selection of default values is supported only for catalogs.
					|Attribute ""%1"".'; 
					|pl = 'WybĆ³r wartoÅci domyÅlnych jest obsÅugiwany tylko dla katalogĆ³w.
					|Atrybut %1.';
					|es_ES = 'SelecciĆ³n de valores por defecto estĆ” admitida solo para los catĆ”logos.
					|Atributo %1.';
					|es_CO = 'SelecciĆ³n de valores por defecto estĆ” admitida solo para los catĆ”logos.
					|Atributo %1.';
					|tr = 'VarsayÄ±lan deÄerler seĆ§imi sadece kataloglar iĆ§in desteklenir.
					|Ćzellik ""%1"".';
					|it = 'La selezione dei valori predefiniti ĆØ supportato solo per i cataloghi.
					|Attributo ""%1"".';
					|de = 'Auswahl von Standardwerten ist nur fĆ¼r Kataloge unterstĆ¼tzt.
					|Attribut %1.'");
				MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, Attribute.FullName());
				Raise MessageString;
			EndIf;
			
			FullMetadataObjectName = MetadataObject.FullName();
			
			TableData = New Structure("MetadataObjectProperties, CorrespondentInfobaseTable");
			TableData.MetadataObjectProperties = MetadataObjectProperties(FullMetadataObjectName);
			TableData.CorrespondentInfobaseTable = GetTableObjects(FullMetadataObjectName);
			
			Result.Insert(FullMetadataObjectName, TableData);
			
		EndIf;
		
	EndDo;
	
	Result.Insert("{AdditionalData}", New Structure); // For backward compatibility with 2.4.x.
	
	Return Result;
	
EndFunction

// Sets the number of items in a data import transaction as the constant value.
//
// Parameters:
//  Count - Number - the number of items in transaction.
// 
Procedure SetDataImportTransactionItemsCount(Count) Export
	
	SetPrivilegedMode(True);
	Constants.DataImportTransactionItemCount.Set(Count);
	
EndProcedure

// Returns the synchronization date presentation.
//
// Parameters:
//  SynchronizationDate - Date - absolute date of data synchronization.
//
// Returns:
//  String - string presentation of date.
//
Function SynchronizationDatePresentation(Val SynchronizationDate) Export
	
	If Not ValueIsFilled(SynchronizationDate) Then
		Return NStr("ru = 'Š”ŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŃ Š½Šµ Š²ŃŠæŠ¾Š»Š½ŃŠ»Š°ŃŃ.'; en = 'Synchronization is not performed.'; pl = 'Synchronizacja nie zostaÅa przeprowadzona.';es_ES = 'SincronizaciĆ³n nunca se ha realizado.';es_CO = 'SincronizaciĆ³n nunca se ha realizado.';tr = 'Senkronizasyon hiĆ§ yapÄ±lmadÄ±.';it = 'La sincronizzazione non ĆØ stata eseguita.';de = 'Die Synchronisation wurde noch nie durchgefĆ¼hrt.'");
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'ŠŠ¾ŃŠ»ŠµŠ“Š½ŃŃ ŃŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŃ: %1'; en = 'The last synchronization: %1'; pl = 'Ostatnia synchronizacja: %1';es_ES = 'Ćltima sincronizaciĆ³n: %1';es_CO = 'Ćltima sincronizaciĆ³n: %1';tr = 'Son senkronizasyon: %1';it = 'L''ultima sincronizzazione: %1';de = 'Letzte Synchronisation: %1'"), RelativeSynchronizationDate(SynchronizationDate));
EndFunction

// Returns presentation for the relative synchronization date.
//
// Parameters:
//  SynchronizationDate - Date - absolute date of data synchronization.
//
// Returns:
//  String - presentation for the relative synchronization date.
//    *Never             (T = blank date).
//    *Now              (T < 5 min).
//    *5 minutes ago       (5 min < T < 15 min).
//    *15 minutes ago      (15 min < T < 30 min).
//    *30 minutes ago      (30 min < T < 1 hour).
//    *1 hour ago         (1 hour < T < 2 hours).
//    *2 hours ago        (2 hours < T < 3 hours).
//    *Today, 12:44:12   (3 hours  < Š¢ < yesterday).
//    *Yesterday, 22:30:45     (yesterday  < Š¢ < one day ago).
//    *One day ago, 21:22:54 (one day ago  < Š¢ < two days ago).
//    *<March 12, 2012>   (two days ago < T).
//
Function RelativeSynchronizationDate(Val SynchronizationDate) Export
	
	If Not ValueIsFilled(SynchronizationDate) Then
		
		Return NStr("ru = 'ŠŠøŠŗŠ¾Š³Š“Š°'; en = 'Never'; pl = 'Nigdy';es_ES = 'Nunca';es_CO = 'Nunca';tr = 'HiĆ§ bir zaman';it = 'Mai';de = 'Niemals'");
		
	EndIf;
	
	DateCurrent = CurrentSessionDate();
	
	Interval = DateCurrent - SynchronizationDate;
	
	If Interval < 0 Then // 0 min
		
		Result = Format(SynchronizationDate, "DLF=DD");
		
	ElsIf Interval < 60 * 5 Then // 5 min
		
		Result = NStr("ru = 'Š”ŠµŠ¹ŃŠ°Ń'; en = 'Now'; pl = 'Teraz';es_ES = 'Ahora';es_CO = 'Ahora';tr = 'Åimdi';it = 'Adesso';de = 'Jetzt'");
		
	ElsIf Interval < 60 * 15 Then // 15 min
		
		Result = NStr("ru = '5 Š¼ŠøŠ½ŃŃ Š½Š°Š·Š°Š“'; en = '5 minutes ago'; pl = '5 minut temu';es_ES = 'Hace 5 minutos';es_CO = 'Hace 5 minutos';tr = '5 dakika Ć¶nce';it = '5 minuti fa';de = 'Vor 5 Minuten'");
		
	ElsIf Interval < 60 * 30 Then // 30 min
		
		Result = NStr("ru = '15 Š¼ŠøŠ½ŃŃ Š½Š°Š·Š°Š“'; en = '15 minutes ago'; pl = '15 minut temu';es_ES = 'Hace 15 minutos';es_CO = 'Hace 15 minutos';tr = '15 dakika Ć¶nce';it = '15 minuti fa';de = 'Vor 15 Minuten'");
		
	ElsIf Interval < 60 * 60 * 1 Then // 1 hour
		
		Result = NStr("ru = '30 Š¼ŠøŠ½ŃŃ Š½Š°Š·Š°Š“'; en = '30 minutes ago'; pl = '30 minut temu';es_ES = 'Hace 30 minutos';es_CO = 'Hace 30 minutos';tr = '30 dakika Ć¶nce';it = '30 minuti fa';de = 'Vor 30 Minuten'");
		
	ElsIf Interval < 60 * 60 * 2 Then // 2 hours
		
		Result = NStr("ru = '1 ŃŠ°Ń Š½Š°Š·Š°Š“'; en = '1 hour ago'; pl = 'godzinÄ temu';es_ES = 'Hace 1 hora';es_CO = 'Hace 1 hora';tr = '1 saat Ć¶nce';it = '1 ora fa';de = 'Vor 1 Stunde'");
		
	ElsIf Interval < 60 * 60 * 3 Then // 3 hours
		
		Result = NStr("ru = '2 ŃŠ°ŃŠ° Š½Š°Š·Š°Š“'; en = '2 hours ago'; pl = '2 godziny temu';es_ES = 'Hace 2 horas';es_CO = 'Hace 2 horas';tr = '2 saat Ć¶nce';it = '2 ore fa';de = 'Vor 2 Stunde'");
		
	Else
		
		DifferenceDaysCount = DifferenceDaysCount(SynchronizationDate, DateCurrent);
		
		If DifferenceDaysCount = 0 Then // today
			
			Result = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Š”ŠµŠ³Š¾Š“Š½Ń, %1'; en = 'Today, %1'; pl = 'Dzisiaj, %1';es_ES = 'Hoy, %1';es_CO = 'Hoy, %1';tr = 'BugĆ¼n, %1';it = 'Oggi, %1';de = 'Heute, %1'"), Format(SynchronizationDate, "DLF=T"));
			
		ElsIf DifferenceDaysCount = 1 Then // yesterday
			
			Result = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'ŠŃŠµŃŠ°, %1'; en = 'Yesterday, %1'; pl = 'Wczoraj, %1';es_ES = 'Ayer, %1';es_CO = 'Ayer, %1';tr = 'DĆ¼n, %1';it = 'Ieri, %1';de = 'Gestern, %1'"), Format(SynchronizationDate, "DLF=T"));
			
		ElsIf DifferenceDaysCount = 2 Then // dayĀ beforeĀ yesterday
			
			Result = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'ŠŠ¾Š·Š°Š²ŃŠµŃŠ°, %1'; en = 'Day before yesterday, %1'; pl = 'Przedwczoraj, %1';es_ES = 'Anteayer, %1';es_CO = 'Anteayer, %1';tr = 'Ćnceki gĆ¼n, %1';it = 'L''altro ieri, %1';de = 'Vorgestern, %1'"), Format(SynchronizationDate, "DLF=T"));
			
		Else // long ago
			
			Result = Format(SynchronizationDate, "DLF=DD");
			
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

// Returns an ID of the supplied profile of the "Data synchronization with other applications" access groups.
//
// Returns:
//  String - ID of the supplied access group profile.
//
Function DataSynchronizationWithOtherApplicationsAccessProfile() Export
	
	Return "04937803-5dba-11df-a1d4-005056c00008";
	
EndFunction

// Checks whether the current user can administer exchanges.
//
// Returns:
//  Boolean - True if the user has rights. Otherwise, False.
//
Function HasRightsToAdministerExchanges() Export
	
	Return Users.IsFullUser();
	
EndFunction

// The function returns the WSProxy object of the Exchange web service created with the passed parameters.
//
// Parameters:
//  SettingsStructure - Structure - parameters for WSProxy.
//    * WebServiceWSURL - String - WSDL file location.
//    * WSServiceName - String - a service name.
//    * WSURLServiceNamespace - String - webĀ service namespace URI.
//    * WSUserName - String - a user name to sign in to server.
//    * WSPassword - String - a user password.
//    * WSTimeout - Number - the timeout for operations executed over the proxy.
//  ErrorMessageString - String - contains detailed error description in case of unsuccessful connection.
//  UserMessage - String - contains brief error description in case of unsuccessful connection.
//
// Returns:
//  WSProxy - a WSProxy object of the Exchange web service.
//
Function GetWSProxy(SettingsStructure, ErrorMessageString = "", UserMessage = "") Export
	
	DeleteInsignificantCharactersInConnectionSettings(SettingsStructure);
	
	SettingsStructure.Insert("WSServiceNamespaceURL", "http://www.1c.ru/SSL/Exchange");
	SettingsStructure.Insert("WSServiceName",                 "Exchange");
	SettingsStructure.Insert("WSTimeout", 600);
	
	Return GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString, UserMessage);
EndFunction

// The function returns the WSProxy object of the Exchange_2_0_1_6 web service created with the passed parameters.
//
// Parameters:
//  SettingsStructure - Structure - parameters for WSProxy.
//    * WebServiceWSURL - String - WSDL file location.
//    * WSServiceName - String - a service name.
//    * WSURLServiceNamespace - String - webĀ service namespace URI.
//    * WSUserName - String - a user name to sign in to server.
//    * WSPassword - String - a user password.
//    * WSTimeout - Number - the timeout for operations executed over the proxy.
//  ErrorMessageString - String - contains detailed error description in case of unsuccessful connection.
//  UserMessage - String - contains brief error description in case of unsuccessful connection.
//
// Returns:
//  WSProxy - a WSProxy object of the Exchange_2_0_1_6 web service.
//
Function GetWSProxy_2_0_1_6(SettingsStructure, ErrorMessageString = "", UserMessage = "") Export
	
	DeleteInsignificantCharactersInConnectionSettings(SettingsStructure);
	
	SettingsStructure.Insert("WSServiceNamespaceURL", "http://www.1c.ru/SSL/Exchange_2_0_1_6");
	SettingsStructure.Insert("WSServiceName",                 "Exchange_2_0_1_6");
	SettingsStructure.Insert("WSTimeout", 600);
	
	Return GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString, UserMessage);
EndFunction

// The function returns the WSProxy object of the Exchange_2_0_1_7 web service created with the passed parameters.
//
// Parameters:
//  SettingsStructure - Structure - parameters for WSProxy.
//    * WebServiceWSURL - String - WSDL file location.
//    * WSServiceName - String - a service name.
//    * WSURLServiceNamespace - String - webĀ service namespace URI.
//    * WSUserName - String - a user name to sign in to server.
//    * WSPassword - String - a user password.
//    * WSTimeout - Number - the timeout for operations executed over the proxy.
//  ErrorMessageString - String - contains detailed error description in case of unsuccessful connection.
//  UserMessage - String - contains brief error description in case of unsuccessful connection.
//  Timeout - Number - timeout.
//
// Returns:
//  WSProxy - a WSProxy object of the Exchange_2_0_1_7 web service.
//
Function GetWSProxy_2_1_1_7(SettingsStructure, ErrorMessageString = "", UserMessage = "", Timeout = 600) Export
	
	DeleteInsignificantCharactersInConnectionSettings(SettingsStructure);
	
	SettingsStructure.Insert("WSServiceNamespaceURL", "http://www.1c.ru/SSL/Exchange_2_0_1_6");
	SettingsStructure.Insert("WSServiceName",                 "Exchange_2_0_1_6");
	SettingsStructure.Insert("WSTimeout", Timeout);
	
	Return GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString, UserMessage, True);
EndFunction

// The function returns the WSProxy object of the Exchange_3_0_1_1 web service created with the passed parameters.
//
// Parameters:
//  SettingsStructure - Structure - parameters for WSProxy.
//    * WebServiceWSURL - String - WSDL file location.
//    * WSServiceName - String - a service name.
//    * WSURLServiceNamespace - String - webĀ service namespace URI.
//    * WSUserName - String - a user name to sign in to server.
//    * WSPassword - String - a user password.
//    * WSTimeout - Number - the timeout for operations executed over the proxy.
//  ErrorMessageString - String - contains detailed error description in case of unsuccessful connection.
//  UserMessage - String - contains brief error description in case of unsuccessful connection.
//  Timeout - Number - timeout.
//
// Returns:
//  WSProxy - a WSProxy object of the Exchange_3_0_1_1 web service.
//
Function GetWSProxy_3_0_1_1(SettingsStructure, ErrorMessageString = "", UserMessage = "", Timeout = 600) Export
	
	DeleteInsignificantCharactersInConnectionSettings(SettingsStructure);
	
	SettingsStructure.Insert("WSServiceNamespaceURL", "http://www.1c.ru/SSL/Exchange_3_0_1_1");
	SettingsStructure.Insert("WSServiceName",                 "Exchange_3_0_1_1");
	SettingsStructure.Insert("WSTimeout",                    Timeout);
	
	Return GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString, UserMessage, True);
	
EndFunction

// Returns allowed number of items processed in a single data import transaction.
//
// Returns:
//   Number - allowed number of items processed in a single data import transaction.
// 
Function DataImportTransactionItemCount() Export
	
	SetPrivilegedMode(True);
	Return Constants.DataImportTransactionItemCount.Get();
	
EndFunction

// Returns allowed number of items processed in a single data export transaction.
//
// Returns:
//   Number - allowed number of items processed in a single data export transaction.
// 
Function DataExportTransactionItemsCount() Export
	
	Return 1;
	
EndFunction

// Returns a table with data of nodes of all configured SSL exchanges.
//
// Returns:
//   ValueTable - a value table with the following columns:
//     * InfobaseNode - ExchangePlanRef - a reference to the exchange plan node.
//     * Description - String - description of the exchange plan node.
//     * ExchangePlanName - String - an exchange plan name.
//
Function SSLExchangeNodes() Export
	
	Query = New Query(ExchangePlansForMonitorQueryText());
	SetPrivilegedMode(True);
	SSLExchangeNodes = Query.Execute().Unload();
	SetPrivilegedMode(False);
	
	Return SSLExchangeNodes;
	
EndFunction

// Determines whether standard conversion rules are used for the exchange plan.
//
// Parameters:
//	ExchangePlanName - String - a name of the exchange plan for which the rules are being imported.
//
// Returns:
//   Boolean - if True, the rules are used. Otherwise, False.
//
Function StandardRulesUsed(ExchangePlanName) Export
	
	Return InformationRegisters.DataExchangeRules.StandardRulesUsed(ExchangePlanName);
	
EndFunction

// Sets an external connection with the infobase and returns the connection description.
//
// Parameters:
//  Parameters - Structure - external connection parameters.
//                          For the properties, see function
//                          CommonClientServer.ParametersStructureForExternalConnection:
//
//	  * InfobaseOperationMode - Number - the infobase operation mode. File mode - 0. Client/server 
//	                                                           mode - 1.
//	  * InfobaseDirectory - String - the infobase directory.
//	  * NameOf1CEnterpriseServer - String - the name of the 1C:Enterprise server.
//	  * NameOfInfobaseOn1CEnterpriseServer - String - a name of the infobase on 1C Enterprise server.
//	  * OperatingSystemAuthentication - Boolean - indicates whether the operating system is 
//	                                                           authenticated on establishing a connection to the infobase.
//	  * UserName - String - the name of an infobase user.
//	  * UserPassword - String - the user password.
//
// Returns:
//  Structure - connection details.
//    * Connection - COMObject, Undefined - if the connection is established, returns a COM object 
//                                    reference. Otherwise, returns Undefined.
//    * BriefErrorDescription       - String - a brief error description.
//    * DetailedErrorDescription     - String - a detailed error description.
//    * ErrorAttachingAddIn - Boolean - a COM connection error flag.
//
Function ExternalConnectionToInfobase(Parameters) Export
	
	// Converting external connection parameters to transport parameters.
	TransportSettings = TransportSettingsByExternalConnectionParameters(Parameters);
	Return EstablishExternalConnectionWithInfobase(TransportSettings);
	
EndFunction

#Region SaveDataSynchronizationSettings

// Starts saving data synchronization settings in time-consuming operation.
// On saving the settings, the data is transferred to the node of passed filling data exchange, and 
// synchronization setup completion flag is set.
// We recommend you to use it in data synchronization setup wizard.
// 
// Parameters:
//  SynchronizationSettings - Structure - parameter structure to save the settings.
//   * ExchangeNode - ExchangePlanRef - an exchange plan node for which synchronization settings are being saved.
//   * FillingData - Structure - arbitrary structure to fill settings on the node.
//                                    It is passed to the OnSaveDataSynchronizationSettings algorithm, if any.
//  HandlerParameters - Structure - outgoing internal parameter. Reserved for internal use.
//                                       It is intended to track the state of time-consuming operation.
//                                       Initial value must be a form attribute of the Arbitrary 
//                                       type which is not used in any other operation.
//  ContinueWait     - Boolean    - outgoing parameter. True, if setting saving is running in a time-consuming operation.
//                                       In this case, to track the state, use procedure
//                                       DataExchangeServer.OnWaitSaveSynchronizationSettings.
//
Procedure OnStartSaveSynchronizationSettings(SynchronizationSettings, HandlerParameters, ContinueWait = True) Export
	
	ModuleDataExchangeCreationWizard().OnStartSaveSynchronizationSettings(SynchronizationSettings,
		HandlerParameters,
		ContinueWait);
	
EndProcedure

// It is used when waiting for data synchronization setup to complete.
// Checks the status of a time-consuming operation of saving the settings. Returns a flag indicating 
// that it is necessary to continue waiting or reports that the saving operation is completed.
// 
// Parameters:
//  HandlerParameters - Structure - incoming/outgoing service parameter. Reserved for internal use.
//                                       It is intended to track the state of time-consuming operation.
//                                       Initial value must be a form attribute of the Arbitrary 
//                                       type used on starting synchronization setup by calling the 
//                                       DataExchangeServer.OnStartSaveSynchronizationSettings method.
//  ContinueWait     - Boolean    - outgoing parameter. True if it is necessary to continue waiting 
//                                       for completion of synchronization settings saving, False - 
//                                       if synchronization setup is completed.
//
Procedure OnWaitForSaveSynchronizationSettings(HandlerParameters, ContinueWait) Export

	ModuleDataExchangeCreationWizard().OnWaitForSaveSynchronizationSettings(HandlerParameters,
		ContinueWait);
	
EndProcedure

// Gets the status of synchronization setup completion. It is called, when procedure
// DataExchangeServer.OnStartSaveSynchronizationSettings or DataExchangeServer.
// OnWaitSaveSynchronizationSettings sets the ContinueWaiting flag to False.
// 
// Parameters:
//  HandlerParameters - Structure - incoming service parameter. Reserved for internal use.
//                                       It is intended to get the state of a time-consuming operation.
//                                       Initial value must be a form attribute of the Arbitrary 
//                                       type used on starting synchronization setup by calling the 
//                                       DataExchangeServer.OnStartSaveSynchronizationSettings method.
//  CompletionStatus       - Structure - an outgoing parameter that returns the state of completion of a time-consuming operation.
//   * Cancel             - Boolean - True if an error occurred on startup or on execution of a time-consuming operation.
//   * ErrorMessage - String - text of the error that occurred on executing a time-consuming operation if Cancel = True.
//   * Result         - Structure - a state of synchronization settings saving.
//    ** SettingsSaved - Boolean - True, if synchronization setup is successfully completed.
//    ** ErrorMessage  - String - text of the error that occurred right in the synchronization settings saving transaction.
//
Procedure OnCompleteSaveSynchronizationSettings(HandlerParameters, CompletionStatus) Export
	
	ModuleDataExchangeCreationWizard().OnCompleteSaveSynchronizationSettings(HandlerParameters,
		CompletionStatus);
	
EndProcedure

#EndRegion

#Region CommonInfobasesNodesSettings

// Sets a flag of completing data synchronization setup.
//
// Parameters:
//   ExchangeNode - ExchangePlanRef - an exchange node to set the flag for.
//
Procedure CompleteDataSynchronizationSetup(ExchangeNode) Export
	
	InformationRegisters.CommonInfobasesNodesSettings.SetFlagSettingCompleted(ExchangeNode);
	
EndProcedure

// Returns a flag of completing data synchronization setup for the exchange node.
//
// Parameters:
//   ExchangeNode - ExchangePlanRef - an exchange node to get a flag for.
//
// Returns:
//   Boolean - True if synchronization setup for the passed node is completed.
//
Function SynchronizationSetupCompleted(ExchangeNode) Export
	
	If DataExchangeCached.IsMessagesExchangeNode(ExchangeNode) Then
		Return True;
	Else
		SetPrivilegedMode(True);
		
		Return InformationRegisters.CommonInfobasesNodesSettings.SetupCompleted(ExchangeNode);
	EndIf;
	
EndFunction

// Indicates that DIB node initial image is created successfully.
//
// Parameters:
//   ExchangeNode - ExchangePlanRef - an exchange node to set the flag for.
//
Procedure CompleteInitialImageCreation(ExchangeNode) Export
	
	InformationRegisters.CommonInfobasesNodesSettings.SetFlagInitialImageCreated(ExchangeNode);
	
EndProcedure

#EndRegion

#Region ForCallsFromOtherSubsystems

// CloudTechnology.SaaS.DataExchangeSaaS

// Returns a reference to the exchange plan node found by its code.
// If the node is not found, Undefined is returned.
//
// Parameters:
//  ExchangePlanName - String - an exchange plan name as it is set in Designer.
//  NodeCode - String - an exchange plan node code.
//
// Returns:
//  ExchangePlanRef - a reference to the found exchange plan node.
//  Undefined - if the exchange plan node is not found.
//
Function ExchangePlanNodeByCode(ExchangePlanName, NodeCode) Export
	
	NodeRef = ExchangePlans[ExchangePlanName].FindByCode(NodeCode);
	
	If Not ValueIsFilled(NodeRef) Then
		Return Undefined;
	EndIf;
	
	Return NodeRef;
	
EndFunction

// Returns True if the session is started on a standalone workplace.
// Returns:
//  Boolean - indicates whether the session is started on a standalone workplace.
//
Function IsStandaloneWorkplace() Export
	
	SetPrivilegedMode(True);
	
	If Constants.SubordinateDIBNodeSetupCompleted.Get() Then
		
		Return Constants.IsStandaloneWorkplace.Get();
		
	Else
		
		MasterNodeOfThisInfobase = MasterNode();
		Return MasterNodeOfThisInfobase <> Undefined
			AND DataExchangeCached.IsStandaloneWorkstationNode(MasterNodeOfThisInfobase);
		
	EndIf;
	
EndFunction

// Determines whether the passed exchange plan node is a standalone workstation.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - a node to be checked.
//
// Returns:
//  Boolean -indicates whetherĀ the passed node is a standalone workplace.
//
Function IsStandaloneWorkstationNode(Val InfobaseNode) Export
	
	Return DataExchangeCached.IsStandaloneWorkstationNode(InfobaseNode);
	
EndFunction

// Deletes a record set for the passed structure values from the register.
//
// Parameters:
//  RecordStructure - Structure - a structure whose values are used to delete a record set.
// 
Procedure DeleteDataExchangesStateRecords(RecordStructure) Export
	
	DeleteRecordSetFromInformationRegister(RecordStructure, "DataExchangesStates");
	
EndProcedure

// Deletes a record set for the passed structure values from the register.
//
// Parameters:
//  RecordStructure - Structure - a structure whose values are used to delete a record set.
// 
Procedure DeleteSuccessfulDataExchangesStateRecords(RecordStructure) Export
	
	DeleteRecordSetFromInformationRegister(RecordStructure, "SuccessfulDataExchangesStates");
	
EndProcedure

// Deletes supplied rules for the exchange plan (clears data in the register).
//
// Parameters:
//	ExchangePlanName - String - a name of the exchange plan for which the rules are being deleted.
//
Procedure DeleteSuppliedRules(ExchangePlanName) Export
	
	InformationRegisters.DataExchangeRules.DeleteSuppliedRules(ExchangePlanName);	
	
EndProcedure

// Imports supplied rules for the exchange plan.
//
// Parameters:
//	ExchangePlanName - String - a name of the exchange plan for which the rules are being imported.
//	RulesFileName - String - a full name of exchange rules file (ZIP).
//
Procedure ImportSuppliedRules(ExchangePlanName, RulesFileName) Export
	
	InformationRegisters.DataExchangeRules.ImportSuppliedRules(ExchangePlanName, RulesFileName);	
	
EndProcedure

// Returns exchange setting ID matching the specific correspondent.
// 
// Parameters:
//  ExchangePlanName       - String - a name of an exchange plan used for exchange setup.
//  CorrespondentVersion - String - a number of version of the  correspondent to setup data exchange with.
//  CorrespondentName    - String - a correspondent name (see the SourceConfigurationName function 
//                               in the correspondent configuration).
//
// Returns:
//  Array - an array of strings with setting IDs for the correspondent.
// 
Function CorrespondentExchangeSettingsOptions(ExchangePlanName, CorrespondentVersion, CorrespondentName) Export
	
	ExchangePlanSettings = ExchangePlanSettings(ExchangePlanName, CorrespondentVersion, CorrespondentName, True);
	If ExchangePlanSettings.ExchangeSettingsOptions.Count() = 0 Then
		Return New Array;
	Else
		Return ExchangePlanSettings.ExchangeSettingsOptions.UnloadColumn("SettingID");
	EndIf;
	
EndFunction

// Returns exchange setting ID matching the specific correspondent.
// 
// Parameters:
//  ExchangePlanName    - String - a name of exchange plan to use for exchange setup.
//  CorrespondentName - String - a correspondent name (see the SourceConfigurationName function in 
//                               the correspondent configuration).
//
// Returns:
//  String - ID of data exchange setup.
// 
Function ExchangeSettingOptionForCorrespondent(ExchangePlanName, CorrespondentName) Export
	
	ExchangePlanSettings = ExchangePlanSettings(ExchangePlanName, "", CorrespondentName, True);
	If ExchangePlanSettings.ExchangeSettingsOptions.Count() = 0 Then
		Return "";
	Else
		Return ExchangePlanSettings.ExchangeSettingsOptions[0].SettingID;
	EndIf;
	
EndFunction

// End SaaSTechnology.SaaS.DataExchangeSaaS

#EndRegion

#Region ObsoleteProceduresAndFunctions

// Adds information on number of items per transaction set in the constant to the structure that 
// contains parameters of exchange message transport.
//
// Parameters:
//  Result - Structure - contains parameters of exchange message transport.
// 
Procedure AddTransactionItemCountToTransportSettings(Result) Export
	
	Result.Insert("DataExportTransactionItemsCount", DataExportTransactionItemsCount());
	Result.Insert("DataImportTransactionItemCount", DataImportTransactionItemCount());
	
EndProcedure

// Returns the area number by the exchange plan node code (message exchange).
// 
// Parameters:
//  NodeCode - String - an exchange plan node code.
// 
// Returns:
//  Number - area number.
//
Function DataAreaNumberByExchangePlanNodeCode(Val NodeCode) Export
	
	If TypeOf(NodeCode) <> Type("String") Then
		Raise NStr("ru = 'ŠŠµŠæŃŠ°Š²ŠøŠ»ŃŠ½ŃŠ¹ ŃŠøŠæ ŠæŠ°ŃŠ°Š¼ŠµŃŃŠ° ā1.'; en = 'The type of parameter #1 is incorrect.'; pl = 'Typ parametru nr 1 jest niepoprawny.';es_ES = 'Tipo invĆ”lido del nĆŗmero del parĆ”metro No.1';es_CO = 'Tipo invĆ”lido del nĆŗmero del parĆ”metro No.1';tr = 'GeĆ§ersiz parametre numarasÄ± #1.';it = 'Il tipo di paramentro #1 non ĆØ corretto.';de = 'UngĆ¼ltiger Typ der Parameternummer Nr 1.'");
	EndIf;
	
	Result = StrReplace(NodeCode, "S0", "");
	
	Return Number(Result);
EndFunction

// Returns data of the first record of query result as a structure.
// 
// Parameters:
//  QueryResult - QueryResult - a query result containing the data to be processed.
// 
// Returns:
//  Structure - a structure with the result.
//
Function QueryResultToStructure(Val QueryResult) Export
	
	Result = New Structure;
	For Each Column In QueryResult.Columns Do
		Result.Insert(Column.Name);
	EndDo;
	
	If QueryResult.IsEmpty() Then
		Return Result;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	FillPropertyValues(Result, Selection);
	
	Return Result;
EndFunction

// Obsolete. Use the ExchangePlanSettingValue function by setting ParameterName to one of the 
// following values:
//  - NewDataExchangeCreationCommandTitle
//  - ExchangeCreateWizardTitle
//  - ExchangePlanNodeTitle
//  - CorrespondentConfigurationDescription
//
// Returns an overridableĀ exchange plan name if set, depending on the predefined exchange setting.
// 
// Parameters:
//   ExchangePlanNode - ExchangePlanRef - an exchange plan node to get predefined name for.
//                                                
//   ParameterNameWithNodeName - String - a name of default parameter to get the node name from.
//   SetupOption        - String - exchange setup option.
//
// Returns:
//  String - a predefined exchange plan name as it is set in Designer.
//
Function OverridableExchangePlanNodeName(Val ExchangePlanNode, ParameterNameWithNodeName, SetupOption = "") Export
	
	SetPrivilegedMode(True);
	
	ExchangePlanPresentation = ExchangePlanSettingValue(
		ExchangePlanNode.Metadata().Name,
		ParameterNameWithNodeName,
		SetupOption);
	
	SetPrivilegedMode(False);
	
	Return ExchangePlanPresentation;
	
EndFunction

#EndRegion

#EndRegion

#Region Internal

#Region DifferentPurpose

// Imports the priority data received from the master DIB node.
Procedure ImportPriorityDataToSubordinateDIBNode(Cancel = False) Export
	
	If DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
			"SkipImportDataExchangeMessageBeforeStart") Then
		Return;
	EndIf;
	
	If DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
			"SkipImportPriorityDataBeforeStart") Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", True);
	SetPrivilegedMode(False);
	
	Try
		
		If NOT GetFunctionalOption("UseDataSynchronization") Then
			
			If Common.DataSeparationEnabled() Then
				
				UseDataSynchronization = Constants.UseDataSynchronization.CreateValueManager();
				UseDataSynchronization.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
				UseDataSynchronization.DataExchange.Load = True;
				UseDataSynchronization.Value = True;
				UseDataSynchronization.Write();
				
			Else
				
				If GetExchangePlansInUse().Count() > 0 Then
					
					UseDataSynchronization = Constants.UseDataSynchronization.CreateValueManager();
					UseDataSynchronization.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
					UseDataSynchronization.DataExchange.Load = True;
					UseDataSynchronization.Value = True;
					UseDataSynchronization.Write();
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If GetFunctionalOption("UseDataSynchronization") Then
			
			InfobaseNode = MasterNode();
			
			If InfobaseNode <> Undefined Then
				
				InformationRegisters.DeleteExchangeTransportSettings.TransferSettingsOfCorrespondentDataExchangeTransport(InfobaseNode);
				TransportKind = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(InfobaseNode);
				
				// Importing application parameters only.
				ExchangeParameters = ExchangeParameters();
				ExchangeParameters.ExchangeMessagesTransportKind = TransportKind;
				ExchangeParameters.ExecuteImport = True;
				ExchangeParameters.ExecuteExport = False;
				ExchangeParameters.ParametersOnly   = True;
				ExecuteDataExchangeForInfobaseNode(InfobaseNode, ExchangeParameters, Cancel);
				
			EndIf;
			
		EndIf;
		
	Except
		SetPrivilegedMode(True);
		SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", False);
		SetPrivilegedMode(False);
		
		EnableDataExchangeMessageImportRecurrenceBeforeStart();
		
		WriteLogEvent(
			NStr("ru = 'ŠŠ±Š¼ŠµŠ½ Š“Š°Š½Š½ŃŠ¼Šø.ŠŠ°Š³ŃŃŠ·ŠŗŠ° ŠæŃŠøŠ¾ŃŠøŃŠµŃŠ½ŃŃ Š“Š°Š½Š½ŃŃ'; en = 'Data exchange.Priority data import'; pl = 'Wymiana danych.Pobieranie danych priorytetowych';es_ES = 'Intercambio de datos.Descarga de los datos de prioridad';es_CO = 'Intercambio de datos.Descarga de los datos de prioridad';tr = 'Veri alÄ±ÅveriÅi. Ćncelikli verilerin iĆ§e aktarÄ±lmasÄ±';it = 'Scambio dati. Importazione dati prioritĆ ';de = 'Datenaustausch.Herunterladen von PrioritĆ¤tsdaten'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
		
		Raise
			NStr("ru = 'ŠŃŠøŠ±ŠŗŠ° Š·Š°Š³ŃŃŠ·ŠŗŠø ŠæŃŠøŠ¾ŃŠøŃŠµŃŠ½ŃŃ Š“Š°Š½Š½ŃŃ ŠøŠ· ŃŠ¾Š¾Š±ŃŠµŠ½ŠøŃ Š¾Š±Š¼ŠµŠ½Š°.
			           |Š”Š¼. ŠæŠ¾Š“ŃŠ¾Š±Š½Š¾ŃŃŠø Š² Š¶ŃŃŠ½Š°Š»Šµ ŃŠµŠ³ŠøŃŃŃŠ°ŃŠøŠø.'; 
			           |en = 'An error occurred when importing priority data from the exchange message.
			           |For more information, see the event log.'; 
			           |pl = 'BÅÄd pobierania danych priorytetowych z komunikatu wymiany.
			           |Zob. szczegĆ³Åy w dzienniku rejestracji.';
			           |es_ES = 'Error de descargar los datos de prioridad del mensaje de intercambio.
			           |VĆ©ase los detalles en el registro.';
			           |es_CO = 'Error de descargar los datos de prioridad del mensaje de intercambio.
			           |VĆ©ase los detalles en el registro.';
			           |tr = 'Ćncelikli veriler deÄiÅim mesajÄ±ndan iĆ§e aktarÄ±lÄ±rken hata oluÅtu.
			           |Detaylar iĆ§in olay gĆ¼nlĆ¼ÄĆ¼ne bakÄ±n.';
			           |it = 'Si ĆØ verificato un errore durante l''importazione di dati prioritari dal messaggio di scambio.
			           |Per maggiori informazioni, consultare il registro degli eventi.';
			           |de = 'Fehler beim Herunterladen von PrioritĆ¤tsdaten aus der Austauschnachricht.
			           |Siehe das Ereignisprotokoll fĆ¼r Details.'");
	EndTry;
	SetPrivilegedMode(True);
	SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", False);
	SetPrivilegedMode(False);
	
	If Cancel Then
		
		If ConfigurationChanged() Then
			Raise
				NStr("ru = 'ŠŠ°Š³ŃŃŠ¶ŠµŠ½Ń ŠøŠ·Š¼ŠµŠ½ŠµŠ½ŠøŃ ŠæŃŠ¾Š³ŃŠ°Š¼Š¼Ń, ŠæŠ¾Š»ŃŃŠµŠ½Š½ŃŠµ ŠøŠ· Š³Š»Š°Š²Š½Š¾Š³Š¾ ŃŠ·Š»Š°.
				           |ŠŠ°Š²ŠµŃŃŠøŃŠµ ŃŠ°Š±Š¾ŃŃ ŠæŃŠ¾Š³ŃŠ°Š¼Š¼Ń. ŠŃŠŗŃŠ¾Š¹ŃŠµ ŠæŃŠ¾Š³ŃŠ°Š¼Š¼Ń Š² ŠŗŠ¾Š½ŃŠøŠ³ŃŃŠ°ŃŠ¾ŃŠµ
				           |Šø Š²ŃŠæŠ¾Š»Š½ŠøŃŠµ ŠŗŠ¾Š¼Š°Š½Š“Ń ""ŠŠ±Š½Š¾Š²ŠøŃŃ ŠŗŠ¾Š½ŃŠøŠ³ŃŃŠ°ŃŠøŃ Š±Š°Š·Ń Š“Š°Š½Š½ŃŃ (F7)"".
				           |
				           |ŠŠ¾ŃŠ»Šµ ŃŃŠ¾Š³Š¾ Š·Š°ŠæŃŃŃŠøŃŠµ ŠæŃŠ¾Š³ŃŠ°Š¼Š¼Ń.'; 
				           |en = 'Application changes received from the main node are imported.
				           |Exit the application. Open the application in Designer
				           |and run command ""Update database configuration (F7)"".
				           |
				           |Then run the application.'; 
				           |pl = 'ZostaÅy pobrane zmiany programu, otrzymane z gÅĆ³wnego wÄzÅa.
				           |ZakoÅcz pracÄ programu. OtwĆ³rz program w konfiguratorze
				           |i wykonaj polecenie ""Aktualizacja konfiguracji bazy danych (F7)"".
				           |
				           |Po tym uruchom program.';
				           |es_ES = 'Modificaciones del programa descargadas desde el nodo principal.
				           |Termine el trabajo del programa. Abra el programa en el configurador
				           |y lance el comando ""Actualizar la configuraciĆ³n de la base de datos (F7)"".
				           |
				           |DespuĆ©s reinicie el programa.';
				           |es_CO = 'Modificaciones del programa descargadas desde el nodo principal.
				           |Termine el trabajo del programa. Abra el programa en el configurador
				           |y lance el comando ""Actualizar la configuraciĆ³n de la base de datos (F7)"".
				           |
				           |DespuĆ©s reinicie el programa.';
				           |tr = 'Ana Ć¼niteden alÄ±nan uygulama deÄiÅiklikleri iĆ§e aktarÄ±ldÄ±. 
				           |Uygulama Ć§alÄ±ÅmalarÄ±nÄ± bitirin. UygulamayÄ± 
				           |yapÄ±landÄ±rÄ±cÄ±da aĆ§Ä±n ve GĆ¼ncelleme veri tabanÄ± yapÄ±landÄ±rmasÄ±nÄ± (F7) komutunu Ć§alÄ±ÅtÄ±rÄ±n. 
				           |
				           |Ondan sonra uygulamayÄ± baÅlatÄ±n.';
				           |it = 'Le modifiche all''applicazione ricevute dal nodo principale sono state importate.
				           |Uscire dall''applicazione. Aprire l''applicazione in Deisgner
				           |ed eseguire il comando ""Update database configuration (F7)"".
				           |
				           |Poi eseguire l''applicazione.';
				           |de = 'Vom Hauptknoten empfangene ProgrammĆ¤nderungen werden geladen.
				           |SchlieĆen Sie das Programm. Ćffnen Sie das Programm im Konfigurator
				           |und fĆ¼hren Sie den Befehl ""Datenbankkonfiguration aktualisieren (F7)"" aus.
				           |
				           |Starten Sie dann das Programm.'");
		EndIf;
		
		EnableDataExchangeMessageImportRecurrenceBeforeStart();
		
		Raise
			NStr("ru = 'ŠŃŠøŠ±ŠŗŠ° Š·Š°Š³ŃŃŠ·ŠŗŠø ŠæŃŠøŠ¾ŃŠøŃŠµŃŠ½ŃŃ Š“Š°Š½Š½ŃŃ ŠøŠ· ŃŠ¾Š¾Š±ŃŠµŠ½ŠøŃ Š¾Š±Š¼ŠµŠ½Š°.
			           |Š”Š¼. ŠæŠ¾Š“ŃŠ¾Š±Š½Š¾ŃŃŠø Š² Š¶ŃŃŠ½Š°Š»Šµ ŃŠµŠ³ŠøŃŃŃŠ°ŃŠøŠø.'; 
			           |en = 'An error occurred when importing priority data from the exchange message.
			           |For more information, see the event log.'; 
			           |pl = 'BÅÄd pobierania danych priorytetowych z komunikatu wymiany.
			           |Zob. szczegĆ³Åy w dzienniku rejestracji.';
			           |es_ES = 'Error de descargar los datos de prioridad del mensaje de intercambio.
			           |VĆ©ase los detalles en el registro.';
			           |es_CO = 'Error de descargar los datos de prioridad del mensaje de intercambio.
			           |VĆ©ase los detalles en el registro.';
			           |tr = 'Ćncelikli veriler deÄiÅim mesajÄ±ndan iĆ§e aktarÄ±lÄ±rken hata oluÅtu.
			           |Detaylar iĆ§in olay gĆ¼nlĆ¼ÄĆ¼ne bakÄ±n.';
			           |it = 'Si ĆØ verificato un errore durante l''importazione di dati prioritari dal messaggio di scambio.
			           |Per maggiori informazioni, consultare il registro degli eventi.';
			           |de = 'Fehler beim Herunterladen von PrioritĆ¤tsdaten aus der Austauschnachricht.
			           |Siehe das Ereignisprotokoll fĆ¼r Details.'");
	EndIf;
	
EndProcedure

// Sets the RetryDataExchangeMessageImportBeforeStart constant value to True.
// Clears exchange messages received from the master node.
//
Procedure EnableDataExchangeMessageImportRecurrenceBeforeStart() Export
	
	ClearDataExchangeMessageFromMasterNode();
	
	Constants.RetryDataExchangeMessageImportBeforeStart.Set(True);
	
EndProcedure

// Initializes the XML file to write information on objects marked for update processing, to pass 
// them to a subordinate DIB node.
//
Procedure InitializeUpdateDataFile(Parameters) Export
	
	FileToWriteXML = Undefined;
	NameOfChangedFile = Undefined;
	
	If StandardSubsystemsCached.DIBUsed("WithFilter") Then
		
		NameOfChangedFile = FileOfDeferredUpdateDataFullName();
		
		FileToWriteXML = New FastInfosetWriter;
		FileToWriteXML.OpenFile(NameOfChangedFile);
		FileToWriteXML.WriteXMLDeclaration();
		FileToWriteXML.WriteStartElement("Objects");
		
	EndIf;
	
	Parameters.NameOfChangedFile = NameOfChangedFile;
	Parameters.WriteChangesForSubordinateDIBNodeWithFilters = FileToWriteXML;
	
EndProcedure

// Initializes the XML file to write information on objects.
//
Procedure WriteUpdateDataToFile(Parameters, Data, DataKind, FullObjectName = "") Export
	
	If Not StandardSubsystemsCached.DIBUsed("WithFilter") Then
		Return;
	EndIf;
	
	If Parameters.WriteChangesForSubordinateDIBNodeWithFilters = Undefined Then
		ExceptionText = NStr("ru = 'Š Š¾Š±ŃŠ°Š±Š¾ŃŃŠøŠŗŠµ Š½ŠµŠæŃŠ°Š²ŠøŠ»ŃŠ½Š¾ Š¾ŃŠ³Š°Š½ŠøŠ·Š¾Š²Š°Š½Š° ŃŠ°Š±Š¾ŃŠ° Ń ŠæŠ°ŃŠ°Š¼ŠµŃŃŠ°Š¼Šø ŃŠµŠ³ŠøŃŃŃŠ°ŃŠøŠø Š“Š°Š½Š½ŃŃ Šŗ Š¾Š±ŃŠ°Š±Š¾ŃŠŗŠµ.'; en = 'Operations with data registration parameters for processing are invalid in the handler.'; pl = 'W programie przetwarzania jest nieprawidÅowo zorganizowana praca z parametrami rejestracji danych do przetwarzania.';es_ES = 'En el procesador se ha organizado incorrectamente el uso de los parĆ”metros de registro de datos para procesar.';es_CO = 'En el procesador se ha organizado incorrectamente el uso de los parĆ”metros de registro de datos para procesar.';tr = 'Ä°Åleyicide, iÅleme iĆ§in veri kaydÄ± parametreleri ile Ć§alÄ±Åma doÄru ayarlanmadÄ±.';it = 'Operazioni con i parametri di registrazione dei dati per l''elaborazione sono invalidi nel gestore.';de = 'Im Handler ist die Arbeit mit den Datenprotokollierungsparametern fĆ¼r die Verarbeitung falsch organisiert.'");
		Raise ExceptionText;
	EndIf;
	
	XMLWriter = Parameters.WriteChangesForSubordinateDIBNodeWithFilters;
	XMLWriter.WriteStartElement("Object");
	XMLWriter.WriteAttribute("Queue", String(Parameters.PositionInQueue));
	
	If Not ValueIsFilled(FullObjectName) Then
		FullObjectName = Data.Metadata().FullName();
	EndIf;
	
	XMLWriter.WriteAttribute("Type", FullObjectName);
	
	If Upper(DataKind) = "REFS" Then
		XMLWriter.WriteAttribute("Ref", XMLString(Data.Ref));
	Else
		
		If Upper(DataKind) = "INDEPENDENTREGISTER" Then
			
			XMLWriter.WriteStartElement("Filter");
			For Each FilterItem In Data.Filter Do
				
				If ValueIsFilled(FilterItem.Value) Then
					XMLWriter.WriteStartElement(FilterItem.Name);
					
					DataType = TypeOf(FilterItem.Value);
					MetadataObject =  Metadata.FindByType(DataType);
					
					If MetadataObject <> Undefined Then
						XMLWriter.WriteAttribute("Type", MetadataObject.FullName());
					ElsIf DataType = Type("UUID") Then
						XMLWriter.WriteAttribute("Type", "UUID");
					Else
						XMLWriter.WriteAttribute("Type", String(DataType));
					EndIf;
					
					XMLWriter.WriteAttribute("Val", XMLString(FilterItem.Value));
					XMLWriter.WriteEndElement();
				EndIf;
				
			EndDo;
			XMLWriter.WriteEndElement();
			
		Else
			Recorder = Data.Filter.Recorder.Value;
			XMLWriter.WriteAttribute("FilterType", String(Recorder.Metadata().FullName()));
			XMLWriter.WriteAttribute("Ref",        XMLString(Recorder.Ref));
		EndIf;
		
	EndIf;
	
	XMLWriter.WriteEndElement();

EndProcedure

// Executes registration in the subordinate DIB node with filtered objects registered for deferred 
// update in the master DIB node.
//
Procedure ProcessDataToUpdateInSubordinateNode(Val ConstantValue) Export
	
	If Not StandardSubsystemsCached.DIBUsed("WithFilter")
		Or Not IsSubordinateDIBNode()
		Or ExchangePlanPurpose(MasterNode().Metadata().Name) <> "DIBWithFilter" Then
		Return;
	EndIf;
	
	ArrayOfValues    = ConstantValue.Value.Get();
	If TypeOf(ArrayOfValues) <> Type("Array") Then
		Return;
	EndIf;
	
	For Each ValueStorage In ArrayOfValues Do
		FileName = FileOfDeferredUpdateDataFullName();
		
		If ValueStorage = Undefined Then
			Return;
		EndIf;
		
		BinaryData = ValueStorage.Get();
		If BinaryData = Undefined Then
			Return;
		EndIf;
		
		If Common.IsSubordinateDIBNode() Then
			Query = New Query;
			Query.Text = 
			"SELECT
			|	InfobaseUpdate.Ref AS Node
			|FROM
			|	ExchangePlan.InfobaseUpdate AS InfobaseUpdate
			|WHERE
			|	NOT InfobaseUpdate.ThisNode";
			
			Selection = Query.Execute().Select();
			While Selection.Next() Do
				ExchangePlans.DeleteChangeRecords(Selection.Node);
			EndDo;
		EndIf;
		
		BinaryData.Write(FileName);
		
		XMLReader = New FastInfosetReader;
		XMLReader.OpenFile(FileName);
		
		HandlerParametersStructure = InfobaseUpdate.MainProcessingMarkParameters();
		
		While XMLReader.Read() Do
			
			If XMLReader.Name = "Object"
				AND XMLReader.NodeType = XMLNodeType.StartElement Then
				
				HandlerParametersStructure.PositionInQueue = Number(XMLReader.AttributeValue("Queue"));
				FullMetadataObjectName            = TrimAll(XMLReader.AttributeValue("Type"));
				MetadataObjectType                  = Metadata.FindByFullName(FullMetadataObjectName);
				ObjectManager                       = Common.ObjectManagerByFullName(FullMetadataObjectName);
				IsReferenceObjectType                = Common.IsRefTypeObject(MetadataObjectType);
				
				If IsReferenceObjectType Then
					ObjectToProcess = ObjectManager.GetRef(New UUID(XMLReader.AttributeValue("Ref")));
				Else
					
					ObjectToProcess = ObjectManager.CreateRecordSet();
					
					If Common.IsInformationRegister(MetadataObjectType)
						AND MetadataObjectType.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
						
						XMLReader.Read();
						
						If XMLReader.Name = "Filter"
							AND XMLReader.NodeType = XMLNodeType.StartElement Then
							
							WritingFilter = True;
							
							While WritingFilter Do
								
								XMLReader.Read();
								
								If XMLReader.Name = "Filter" AND XMLReader.NodeType = XMLNodeType.EndElement Then
									WritingFilter = False;
									Continue;
								ElsIf XMLReader.NodeType = XMLNodeType.EndElement Then
									Continue;
								Else
									
									FilterValue = XMLReader.AttributeValue("Val");
									If ValueIsFilled(FilterValue) Then
										
										FilterName         = XMLReader.Name;
										FilterValueType = XMLReader.AttributeValue("Type");
										FullFilterItemName = Metadata.FindByFullName(FilterValueType);
										
										If FullFilterItemName <> Undefined Then
											
											FilterObjectManager = Common.ObjectManagerByFullName(FilterValueType);
											
											If StrFind(Upper(FilterValueType), "ENUM") > 0 Then
												ValueRef = FilterObjectManager[FilterValue];
											Else
												ValueRef = FilterObjectManager.GetRef(New UUID(FilterValue));
											EndIf;
											
											ObjectToProcess.Filter[FilterName].Set(ValueRef);
											
										Else
											If Upper(StrReplace(FilterValueType, " ", "")) = "UUID" Then
												ObjectToProcess.Filter[FilterName].Set(XMLValue(Type("UUID"), FilterValue));
											Else
												ObjectToProcess.Filter[FilterName].Set(XMLValue(Type(FilterValueType), FilterValue));
											EndIf;
										EndIf;
										
									EndIf;
									
								EndIf;
								
							EndDo;
							
						EndIf;
						
					Else
						
						RecorderValue  = New UUID(XMLReader.AttributeValue("Ref"));
						FullRecorderName = XMLReader.AttributeValue("FilterType");
						RecorderManager  = Common.ObjectManagerByFullName(FullRecorderName);
						RecorderRef   = RecorderManager.GetRef(RecorderValue);
						ObjectToProcess.Filter.Recorder.Set(RecorderRef);
						
					EndIf;
					
					ObjectToProcess.Read();
					
				EndIf;
				
				InfobaseUpdate.MarkForProcessing(HandlerParametersStructure, ObjectToProcess);
				
			Else
				Continue;
			EndIf;
			
		EndDo;
		
		XMLReader.Close();
		
		File = New File(FileName);
		If File.Exist() Then
			DeleteFiles(FileName);
		EndIf;
	EndDo;
	
EndProcedure

// Closes the XML file with written information on objects registered for deferred update.
// 
//
Procedure CompleteWriteUpdateDataFile(Parameters) Export
	
	UpdateData = CompleteWriteFileAndGetUpdateData(Parameters);
	
	If UpdateData <> Undefined Then
		SaveUpdateData(UpdateData, Parameters.NameOfChangedFile);
	EndIf;
	
EndProcedure

// Closes the XML file with written information on objects registered for deferred update and 
// returns file content.
//
// Parameters:
//  Parameters - Structure - see InfobaseUpdate.MainProcessingMarkParameters(). 
//
// Returns:
//  ValueStorage - file content.
//
Function CompleteWriteFileAndGetUpdateData(Parameters) Export
	
	If Not StandardSubsystemsCached.DIBUsed("WithFilter")
		Or Common.IsSubordinateDIBNode() Then
		Return Undefined;
	EndIf;
	
	If Parameters.WriteChangesForSubordinateDIBNodeWithFilters = Undefined Then
		ExceptionText = NStr("ru = 'Š Š¾Š±ŃŠ°Š±Š¾ŃŃŠøŠŗŠµ Š½ŠµŠæŃŠ°Š²ŠøŠ»ŃŠ½Š¾ Š¾ŃŠ³Š°Š½ŠøŠ·Š¾Š²Š°Š½Š° ŃŠ°Š±Š¾ŃŠ° Ń ŠæŠ°ŃŠ°Š¼ŠµŃŃŠ°Š¼Šø ŃŠµŠ³ŠøŃŃŃŠ°ŃŠøŠø Š“Š°Š½Š½ŃŃ Šŗ Š¾Š±ŃŠ°Š±Š¾ŃŠŗŠµ.'; en = 'Operations with data registration parameters for processing are invalid in the handler.'; pl = 'W programie przetwarzania jest nieprawidÅowo zorganizowana praca z parametrami rejestracji danych do przetwarzania.';es_ES = 'En el procesador se ha organizado incorrectamente el uso de los parĆ”metros de registro de datos para procesar.';es_CO = 'En el procesador se ha organizado incorrectamente el uso de los parĆ”metros de registro de datos para procesar.';tr = 'Ä°Åleyicide, iÅleme iĆ§in veri kaydÄ± parametreleri ile Ć§alÄ±Åma doÄru ayarlanmadÄ±.';it = 'Operazioni con i parametri di registrazione dei dati per l''elaborazione sono invalidi nel gestore.';de = 'Im Handler ist die Arbeit mit den Datenprotokollierungsparametern fĆ¼r die Verarbeitung falsch organisiert.'");
		Raise ExceptionText;
	EndIf;
	
	XMLWriter = Parameters.WriteChangesForSubordinateDIBNodeWithFilters;
	XMLWriter.WriteEndElement();
	XMLWriter.Close();
	
	NameOfChangedFile = Parameters.NameOfChangedFile;
	FileBinaryData = New BinaryData(NameOfChangedFile);
	
	Return New ValueStorage(FileBinaryData, New Deflation(9));
	
EndFunction

// Saves file content from CompleteWriteFileAndGetUpdateData() to the DeferredUpdateData constant.
// 
//
// Parameters:
//  UpdateData - ValueStorage - file content.
//  NameOfChangedFile - String - a name of data file.
//
Procedure SaveUpdateData(UpdateData, NameOfChangedFile) Export
	
	If NameOfChangedFile = Undefined Then
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		LockItem = Lock.Add("Constant.DataForDeferredUpdate");
		Lock.Lock();
		
		ConstantValue = Constants.DataForDeferredUpdate.Get().Get();
		If TypeOf(ConstantValue) <> Type("Array") Then
			ConstantValue = New Array;
		EndIf;
		
		ConstantValue.Add(UpdateData);

		Constants.DataForDeferredUpdate.Set(New ValueStorage(ConstantValue));
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	FileWithData = New File(NameOfChangedFile);
	If FileWithData.Exist() Then
		DeleteFiles(NameOfChangedFile);
	EndIf;
	
EndProcedure

// Clears the WriteChangesForSubordinateDIBNodeWithFilters constant value on update.
//
Procedure ClearConstantValueWithChangesForSUbordinateDIBNodeWithFilters() Export
	
	Constants.DataForDeferredUpdate.Set(Undefined);
	
EndProcedure

// Returns True if the DIB node setup is not completed and it is required to update the application 
// parameters that are not used in DIB.
//
Function SubordinateDIBNodeSetup() Export
	
	SetPrivilegedMode(True);
	
	Return IsSubordinateDIBNode()
	      AND NOT Constants.SubordinateDIBNodeSetupCompleted.Get();
	
EndFunction

// Updates object conversion or registration rules.
// Update is performed for all exchange plans that use SSL functionality.
// Updates only standard rules.
// Rules loaded from a file are not updated.
//
Procedure UpdateDataExchangeRules() Export
	
	// If an exchange plan was renamed or deleted from the configuration.
	DeleteObsoleteRecordsFromDataExchangeRuleRegister();
	
	If Not GetFunctionalOption("UseDataSynchronization")
		AND Not Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	LoadedFromFileExchangeRules = New Array;
	RegistrationRulesImportedFromFile = New Array;
	
	CheckLoadedFromFileExchangeRulesAvailability(LoadedFromFileExchangeRules, RegistrationRulesImportedFromFile);
	UpdateStandardDataExchangeRuleVersion(LoadedFromFileExchangeRules, RegistrationRulesImportedFromFile);
	
EndProcedure

#EndRegion

#Region ProgressBar

// Calculates export progress and writes as a message to user.
//
// Parameters:
//  ExportedCount - Number - a number of objects exported at the moment.
//  ObjectsToExportCount - Number - number of objects to export.
//
Procedure CalculateExportPercent(ExportedCount, ObjectsToExportCount) Export
	
	// Showing export progress message every 100 objects.
	If ExportedCount = 0 OR ExportedCount / 100 <> Int(ExportedCount / 100) Then
		Return;
	EndIf;
	
	If ObjectsToExportCount = 0 Or ExportedCount > ObjectsToExportCount Then
		ProgressPercent = 95;
		Template = NStr("ru = 'ŠŠ±ŃŠ°Š±Š¾ŃŠ°Š½Š¾: %1 Š¾Š±ŃŠµŠŗŃŠ¾Š².'; en = 'Processed: %1 objects.'; pl = 'Przetworzono: %1 obiektĆ³w.';es_ES = 'Procesado: %1 objetos.';es_CO = 'Procesado: %1 objetos.';tr = 'Ä°Ålenen: %1 nesne.';it = 'Processati: %1 oggetti.';de = 'Bearbeitet: %1 Objekte.'");
		Text = StringFunctionsClientServer.SubstituteParametersToString(Template, Format(ExportedCount, "NZ=0; NG="));
	Else
		// Reserving 5% of the bar for export by references, calculating the number percent basing on 95.
		ProgressPercent = Round(Min(ExportedCount * 95 / ObjectsToExportCount, 95));
		Template = NStr("ru = 'ŠŠ±ŃŠ°Š±Š¾ŃŠ°Š½Š¾: %1 ŠøŠ· %2 Š¾Š±ŃŠµŠŗŃŠ¾Š².'; en = 'Processed: %1 out of %2 objects.'; pl = 'Przetworzono: %1 z %2 obiektĆ³w.';es_ES = 'Procesado: %1 de %2 objetos.';es_CO = 'Procesado: %1 de %2 objetos.';tr = 'Ä°Ålendi: %1 nesneden %2.';it = 'Elaborati: %1 di %2 oggetti.';de = 'Bearbeitet: %1 von %2 Objekten.'");
		Text = StringFunctionsClientServer.SubstituteParametersToString(
			Template,
			Format(ExportedCount, "NZ=0; NG="),
			Format(ObjectsToExportCount, "NZ=0; NG="));
	EndIf;
	
	// Register a message to read it from the client session.
	TimeConsumingOperations.ReportProgress(ProgressPercent, Text);
EndProcedure

// Calculates import progress and writes as a message to user.
//
// Parameters:
//  ImportedCount - Number - a number of objects imported at the moment.
//  ObjectsToImportCount - Number - a number of objects to import.
//  ExchangeMessageFileSize - Number - the size of exchange message file in megabytes.
//
Procedure CalculateImportPercent(ExportedCount, ObjectsToImportCount, ExchangeMessageFileSize) Export
	// Showing import progress message every 10 objects.
	If ExportedCount = 0 OR ExportedCount / 10 <> Int(ExportedCount / 10) Then
		Return;
	EndIf;

	If ObjectsToImportCount = 0 Then
		// It is possible when importing through COM connection if progress bar is not used on the other side.
		ProgressPercent = 95;
		Template = NStr("ru = 'ŠŠ±ŃŠ°Š±Š¾ŃŠ°Š½Š¾ %1 Š¾Š±ŃŠµŠŗŃŠ¾Š².'; en = '%1 objects processed.'; pl = 'Przetworzono %1 obiektĆ³w.';es_ES = 'Procesado %1 objetos.';es_CO = 'Procesado %1 objetos.';tr = '%1 nesne iÅlendi.';it = '%1 oggetti processati.';de = 'Bearbeitet: %1 Objekte.'");
		Text = StringFunctionsClientServer.SubstituteParametersToString(Template, Format(ExportedCount, "NZ=0; NG="));
	Else
		// Reserving 5% of the bar for deferred filling, calculating number percent based on 95.
		ProgressPercent = Round(Min(ExportedCount * 95 / ObjectsToImportCount, 95));
		
		Template = NStr("ru = 'ŠŠ±ŃŠ°Š±Š¾ŃŠ°Š½Š¾: %1 ŠøŠ· %2 Š¾Š±ŃŠµŠŗŃŠ¾Š².'; en = 'Processed: %1 out of %2 objects.'; pl = 'Przetworzono: %1 z %2 obiektĆ³w.';es_ES = 'Procesado: %1 de %2 objetos.';es_CO = 'Procesado: %1 de %2 objetos.';tr = 'Ä°Ålendi: %1 nesneden %2.';it = 'Elaborati: %1 di %2 oggetti.';de = 'Bearbeitet: %1 von %2 Objekten.'");
		Text = StringFunctionsClientServer.SubstituteParametersToString(
			Template,
			Format(ExportedCount, "NZ=0; NG="),
			Format(ObjectsToImportCount, "NZ=0; NG="));
	EndIf;
	
	// Adding file size.
	If ExchangeMessageFileSize <> 0 Then
		Template = NStr("ru = 'Š Š°Š·Š¼ŠµŃ ŃŠ¾Š¾Š±ŃŠµŠ½ŠøŃ %1 ŠŠ'; en = 'Message size is %1 MB'; pl = 'Rozmiar komunikatu %1 MB';es_ES = 'TamaĆ±o del mensaje %1 MB';es_CO = 'TamaĆ±o del mensaje %1 MB';tr = 'Mesaj boyutu %1 MB';it = 'La dimensione del messaggio ĆØ %1 MB';de = 'NachrichtengrĆ¶Će %1 MB'");
		TextAddition = StringFunctionsClientServer.SubstituteParametersToString(Template, ExchangeMessageFileSize);
		Text = Text + " " + TextAddition;
	EndIf;
	
	// Register a message to read it from the client session.
	TimeConsumingOperations.ReportProgress(ProgressPercent, Text);

EndProcedure

// Increasing counter of exported objects and calculating export percent. Only for DIB.
//
// Parameters:
// Recipient - an exchange plan object.
// InitialImageCreation - Boolean.
//
Procedure CalculateDIBDataExportPercentage(Recipient, InitialImageCreation) Export
	
	If Recipient = Undefined
		Or Not DataExchangeCached.IsDistributedInfobaseNode(Recipient.Ref) Then
		Return;
	EndIf;
	
	// Counting the number of objects to be exported.
	If NOT Recipient.AdditionalProperties.Property("ObjectsToExportCount") Then
		ObjectsToExportCount = 0;
		If InitialImageCreation Then
			ObjectsToExportCount = CalculateObjectsCountInDatabase(Recipient);
		Else
			// Extracting the total number of objects to be exported.
			CurrentSessionParameter = Undefined;
			SetPrivilegedMode(True);
			Try
				CurrentSessionParameter = SessionParameters.DataSynchronizationSessionParameters.Get();
			Except
				Return;
			EndTry;
			SetPrivilegedMode(False);
			If TypeOf(CurrentSessionParameter) = Type("Map") Then
				SynchronizationData = CurrentSessionParameter.Get(Recipient.Ref);
				If NOT (SynchronizationData = Undefined 
					OR TypeOf(SynchronizationData) <> Type("Structure")) Then
					ObjectsToExportCount = SynchronizationData.ObjectsToExportCount;
				EndIf;
			EndIf;
		EndIf;
		Recipient.AdditionalProperties.Insert("ObjectsToExportCount", ObjectsToExportCount);
		Recipient.AdditionalProperties.Insert("ExportedObjectCounter", 1);
		Return; // In this case, there is no need to calculate export percent. This is the very beginning of export.
	Else
		If Recipient.AdditionalProperties.Property("ExportedObjectCounter") Then
			Recipient.AdditionalProperties.ExportedObjectCounter = Recipient.AdditionalProperties.ExportedObjectCounter + 1;
		Else
			Return;
		EndIf;
	EndIf;
	
	CalculateExportPercent(Recipient.AdditionalProperties.ExportedObjectCounter,
		Recipient.AdditionalProperties.ObjectsToExportCount);
EndProcedure

// Increasing counter of imported objects and calculating import percent. Only for DIB.
//
// Parameters:
// Sender - an exchange plan object.
//
Procedure CalculateDIBDataImportPercentage(Sender) Export
	
	If Sender = Undefined
		Or Not DataExchangeCached.IsDistributedInfobaseNode(Sender.Ref) Then
		Return;
	EndIf;
	If NOT Sender.AdditionalProperties.Property("ObjectsToImportCount")
		OR NOT Sender.AdditionalProperties.Property("ExchangeMessageFileSize") Then
		ObjectsToImportCount = 0;
		ExchangeMessageFileSize = 0;
		// Extracting the total number of objects to be imported and the size of exchange message file.
		CurrentSessionParameter = Undefined;
		SetPrivilegedMode(True);
		Try
			CurrentSessionParameter = SessionParameters.DataSynchronizationSessionParameters.Get();
		Except
			Return;
		EndTry;
		SetPrivilegedMode(False);
		If TypeOf(CurrentSessionParameter) = Type("Map") Then
			SynchronizationData = CurrentSessionParameter.Get(Sender.Ref);
			If SynchronizationData = Undefined 
				OR TypeOf(SynchronizationData) <> Type("Structure") Then
				Return;
			EndIf;
			Sender.AdditionalProperties.Insert("ObjectsToImportCount", 
														SynchronizationData.ObjectsToImportCount);
			Sender.AdditionalProperties.Insert("ExchangeMessageFileSize", 
														SynchronizationData.ExchangeMessageFileSize);
		EndIf;
	EndIf;
	If Not Sender.AdditionalProperties.Property("ImportedObjectCounter") Then
		Sender.AdditionalProperties.Insert("ImportedObjectCounter", 1);
	Else
		Sender.AdditionalProperties.ImportedObjectCounter = Sender.AdditionalProperties.ImportedObjectCounter + 1;
	EndIf;
	
	CalculateImportPercent(Sender.AdditionalProperties.ImportedObjectCounter,
		Sender.AdditionalProperties.ObjectsToImportCount,
		Sender.AdditionalProperties.ExchangeMessageFileSize);
	
EndProcedure

// Analyzes data to import:
// Calculates the number of objects to be imported, the size of exchange message file, and other service data.
// Parameters:
//  ExchangeFileName - String - an exchange message file name.
//  IsXDTOExchange - Boolean - indicates that exchange via universal format is being executed.
// 
// Returns:
//  Structure - structure properties:
//    * ExchangeMessageFileSize - Number - the size of the exchange message file in megabytes, 0 by default.
//    * ObjectsToImportCount - Number - number of objects to import, 0 by default.
//    * From - String - code of message sender node.
//    * To - String - code of message recipient node.
//    * NewFrom - String - a sender node code in new format (to convert current exchanges to a new encoding).
Function DataAnalysisResultToExport(Val ExchangeFileName, IsXDTOExchange, IsDIBExchange = False) Export
	
	Result = New Structure;
	Result.Insert("ExchangeMessageFileSize", 0);
	Result.Insert("ObjectsToImportCount", 0);
	Result.Insert("From", "");
	Result.Insert("NewFrom", "");
	Result.Insert("To", "");
	
	If NOT ValueIsFilled(ExchangeFileName) Then
		Return Result;
	EndIf;
	
	FileWithData = New File(ExchangeFileName);
	If Not FileWithData.Exist() Then
		Return Result;
	EndIf;
	
	ExchangeFile = New XMLReader;
	Try
		// Converting the size to megabytes.
		Result.ExchangeMessageFileSize = Round(FileWithData.Size() / 1048576, 1);
		ExchangeFile.OpenFile(ExchangeFileName);
	Except
		Return Result;
	EndTry;
	
	// The algorithm of exchange file analysis depends on exchange kind.
	If IsXDTOExchange Then
		ExchangeFile.Read(); // Message.
		ExchangeFile.Read();  // Header start.
		StartObjectsAccount = False;
		While ExchangeFile.Read() Do
			If ExchangeFile.LocalName = "Header" Then
				// Header is read.
				StartObjectsAccount = True;
				ExchangeFile.Skip(); 
			ElsIf ExchangeFile.LocalName = "Confirmation" Then
				ExchangeFile.Read();
			ElsIf ExchangeFile.LocalName = "From" Then
				ExchangeFile.Read();
				Result.From = ExchangeFile.Value;
				ExchangeFile.Skip();
			ElsIf ExchangeFile.LocalName = "To" Then
				ExchangeFile.Read();
				Result.To = ExchangeFile.Value;
				ExchangeFile.Skip();
			ElsIf ExchangeFile.LocalName = "NewFrom" Then
				ExchangeFile.Read();
				Result.NewFrom = ExchangeFile.Value;
				ExchangeFile.Skip();
			ElsIf StartObjectsAccount 
				AND ExchangeFile.NodeType = XMLNodeType.StartElement 
				AND ExchangeFile.LocalName <> "ObjectDeletion" 
				AND ExchangeFile.LocalName <> "Body" Then
				Result.ObjectsToImportCount = Result.ObjectsToImportCount + 1;
				ExchangeFile.Skip();
			EndIf;
		EndDo;

	ElsIf IsDIBExchange Then
		ExchangeFile.Read(); // Message.
		ExchangeFile.Read();  // Header start.
		ExchangeFile.Skip(); // Header end.
		ExchangeFile.Read(); //Body start.
		While ExchangeFile.Read() Do
			If ExchangeFile.LocalName = "Changes"
				OR ExchangeFile.LocalName = "Data" Then
				Continue;
			ElsIf StrFind(ExchangeFile.LocalName, "Config") = 0 
				AND StrFind(ExchangeFile.LocalName, "Signature") = 0
				AND StrFind(ExchangeFile.LocalName, "Nodes") = 0
				AND ExchangeFile.LocalName <> "Parameters"
				AND ExchangeFile.LocalName <> "Body" Then
				Result.ObjectsToImportCount = Result.ObjectsToImportCount + 1;
			EndIf;
			ExchangeFile.Skip();
		EndDo;	
	Else
		
		ExchangeFile.Read(); // Exchange file.
		ExchangeFile.Read();  // ExchangeRules start.
		ExchangeFile.Skip(); // ExchangeRules end.

		ExchangeFile.Read();  // DataTypes start.
		ExchangeFile.Skip(); // DataTypes end.

		ExchangeFile.Read();  // Exchange data start.
		ExchangeFile.Skip(); // Exchange data end.
		While ExchangeFile.Read() Do
			If ExchangeFile.LocalName = "Object"
				OR ExchangeFile.LocalName = "RegisterRecordSet"
				OR ExchangeFile.LocalName = "ObjectDeletion"
				OR ExchangeFile.LocalName = "ObjectRegistrationInformation" Then
				Result.ObjectsToImportCount = Result.ObjectsToImportCount + 1;
			EndIf;
			ExchangeFile.Skip();
		EndDo;
	EndIf;
	ExchangeFile.Close();
	
	Return Result;
EndFunction

#EndRegion

#Region OperationsWithFTPConnectionObject

Function FTPConnection(Val Settings) Export
	
	Return New FTPConnection(
		Settings.Server,
		Settings.Port,
		Settings.UserName,
		Settings.UserPassword,
		ProxyServerSettings(Settings.SecureConnection),
		Settings.PassiveConnection,
		Settings.Timeout,
		Settings.SecureConnection);
	
EndFunction

Function FTPConnectionSettings(Val Timeout = 180) Export
	
	Result = New Structure;
	Result.Insert("Server", "");
	Result.Insert("Port", 21);
	Result.Insert("UserName", "");
	Result.Insert("UserPassword", "");
	Result.Insert("PassiveConnection", False);
	Result.Insert("Timeout", Timeout);
	Result.Insert("SecureConnection", Undefined);
	
	Return Result;
EndFunction

// Returns server name and FTP server path. This data is gotten from FTP server connection string.
//
// Parameters:
//  StringForConnection - String - an FTP resource connection string.
// 
// Returns:
//  Structure - FTP server connection settings. The structure includes the following fields:
//              Server - String - a server name.
//              Path   - String - a server path.
//
//  Example (1):
// Result = FTPServerNameAndPath("ftp://server");
// Result.Server = "server";
// Result.Path = "/";
//
//  Example (2):
// Result = FTPServerNameAndPath("ftp://server/saas/exchange");
// Result.Server = "server";
// Result.Path = "/saas/exchange/";
//
Function FTPServerNameAndPath(Val StringForConnection) Export
	
	Result = New Structure("Server, Path");
	StringForConnection = TrimAll(StringForConnection);
	
	If (Upper(Left(StringForConnection, 6)) <> "FTP://"
		AND Upper(Left(StringForConnection, 7)) <> "FTPS://")
		OR StrFind(StringForConnection, "@") <> 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Š”ŃŃŠ¾ŠŗŠ° ŠæŠ¾Š“ŠŗŠ»ŃŃŠµŠ½ŠøŃ Šŗ FTP-ŃŠµŃŃŃŃŃ Š½Šµ ŃŠ¾Š¾ŃŠ²ŠµŃŃŃŠ²ŃŠµŃ ŃŠ¾ŃŠ¼Š°ŃŃ: ""%1""'; en = 'FTP server connection string does not match the format: %1'; pl = 'Wiersz poÅÄczenia FTP nie jest zgodny z formatem: ""%1""';es_ES = 'LĆ­nea de conexiĆ³n FTP no coincide con el formato: ""%1""';es_CO = 'LĆ­nea de conexiĆ³n FTP no coincide con el formato: ""%1""';tr = 'FTP baÄlantÄ± dizesi Åu biĆ§imle eÅleÅmiyor: ""%1""';it = 'La stringa di connessione del server FTP non corrisponde al formato: %1';de = 'FTP-Verbindungszeichenfolge stimmt nicht mit dem Format Ć¼berein: ""%1""'"), StringForConnection);
	EndIf;
	
	ConnectionParameters = StrSplit(StringForConnection, "/");
	
	If ConnectionParameters.Count() < 3 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Š ŃŃŃŠ¾ŠŗŠµ ŠæŠ¾Š“ŠŗŠ»ŃŃŠµŠ½ŠøŃ Šŗ FTP-ŃŠµŃŃŃŃŃ Š½Šµ ŃŠŗŠ°Š·Š°Š½Š¾ ŠøŠ¼Ń ŃŠµŃŠ²ŠµŃŠ°: ""%1""'; en = 'Server name is not specified in the connection string to FTP server: %1'; pl = 'Nie okreÅlono nazwy ciÄgu poÅÄczenia zasobĆ³w FTP: ""%1""';es_ES = 'Nombre del servidor no estĆ” especificado en la lĆ­nea de conexiĆ³n del recurso FTP: ""%1""';es_CO = 'Nombre del servidor no estĆ” especificado en la lĆ­nea de conexiĆ³n del recurso FTP: ""%1""';tr = 'FTP kaynak baÄlantÄ± dizesinde sunucu adÄ± belirtilmemiÅ: ""%1""';it = 'Il nome del server non ĆØ indicato nella stringa di connessione al server FTP: %1';de = 'Der Servername wird in der Zeichenkette FTP-Ressourcenverbindung nicht angegeben: ""%1""'"), StringForConnection);
	EndIf;
	
	Result.Server = ConnectionParameters[2];
	
	ConnectionParameters.Delete(0);
	ConnectionParameters.Delete(0);
	ConnectionParameters.Delete(0);
	
	ConnectionParameters.Insert(0, "@");
	
	If Not IsBlankString(ConnectionParameters.Get(ConnectionParameters.UBound())) Then
		
		ConnectionParameters.Add("@");
		
	EndIf;
	
	Result.Path = StrConcat(ConnectionParameters, "/");
	Result.Path = StrReplace(Result.Path, "@", "");
	
	Return Result;
EndFunction

Function OpenDataExchangeCreationWizardForSubordinateNodeSetup() Export
	
	Return Not Common.DataSeparationEnabled()
		AND Not IsStandaloneWorkplace()
		AND IsSubordinateDIBNode()
		AND Not Constants.SubordinateDIBNodeSetupCompleted.Get();
	
EndFunction

#EndRegion

#Region SecurityProfiles

Function RequestToUseExternalResourcesOnEnableExchange() Export
	
	Queries = New Array();
	CreateRequestsToUseExternalResources(Queries);
	Return Queries;
	
EndFunction

Function RequestToClearPermissionsToUseExternalResources() Export
	
	Queries = New Array;
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	For Each ExchangePlanName In DataExchangeCached.SSLExchangePlans() Do
		
		QueryText =
		"SELECT
		|	ExchangePlan.Ref AS Node
		|FROM
		|	ExchangePlan.[ExchangePlanName] AS ExchangePlan";
		
		QueryText = StrReplace(QueryText, "[ExchangePlanName]", ExchangePlanName);
		
		Query = New Query;
		Query.Text = QueryText;
		
		Result = Query.Execute();
		Selection = Result.Select();
		
		While Selection.Next() Do
			
			Queries.Add(ModuleSafeModeManager.RequestToClearPermissionsToUseExternalResources(Selection.Node));
			
		EndDo;
		
	EndDo;
	
	Queries.Add(ModuleSafeModeManager.RequestToClearPermissionsToUseExternalResources(
		Common.MetadataObjectID(Metadata.Constants.DataExchangeMessageDirectoryForLinux)));
	Queries.Add(ModuleSafeModeManager.RequestToClearPermissionsToUseExternalResources(
		Common.MetadataObjectID(Metadata.Constants.DataExchangeMessageDirectoryForWindows)));
	
	Return Queries;
	
EndFunction

#EndRegion

#Region OtherProceduresAndFunctions

// Returns a string of invalid characters in the username used for authentication when creating 
// WSProxy.
//
// Returns:
//	String - a string of invalid characters in the username.
//
Function ProhibitedCharsInWSProxyUserName() Export
	
	Return ":";
	
EndFunction

Function NodeIDForExchange(ExchangeNode) Export
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangeNode);
	
	NodeCode = TrimAll(Common.ObjectAttributeValue(ExchangePlans[ExchangePlanName].ThisNode(), "Code"));
	
	If DataExchangeCached.IsSeparatedSSLDataExchangeNode(ExchangeNode) Then
		NodePrefixes = InformationRegisters.CommonInfobasesNodesSettings.NodePrefixes(ExchangeNode);
		
		If StrLen(NodeCode) = 2
			AND Not IsBlankString(NodePrefixes.Prefix) Then
			// Prefix specified on connection setup is used as identification code on exchange.
			// 
			NodeCode = NodePrefixes.Prefix;
		EndIf;
	EndIf;
	
	Return NodeCode;
	
EndFunction

Function CorrespondentNodeIDForExchange(ExchangeNode) Export
	
	NodeCode = TrimAll(Common.ObjectAttributeValue(ExchangeNode, "Code"));
	
	If DataExchangeCached.IsSeparatedSSLDataExchangeNode(ExchangeNode) Then
		NodePrefixes = InformationRegisters.CommonInfobasesNodesSettings.NodePrefixes(ExchangeNode);
		
		If StrLen(NodeCode) = 2
			AND Not IsBlankString(NodePrefixes.CorrespondentPrefix) Then
			// Prefix specified on connection setup is used as identification code on exchange.
			// 
			NodeCode = NodePrefixes.CorrespondentPrefix;
		EndIf;
	EndIf;
	
	Return NodeCode;
	
EndFunction

// Determines whether the SSL exchange plan is a separated one.
//
// Parameters:
//	ExchangePlanName - String - a name of the exchange plan to check.
//
// Returns:
//	Type - Boolean.
//
Function IsSeparatedSSLExchangePlan(Val ExchangePlanName) Export
	
	Return DataExchangeCached.SeparatedSSLExchangePlans().Find(ExchangePlanName) <> Undefined;
	
EndFunction

// Creates the selection of changed data to pass it to an exchange plan node.
// If the method is called in the active transaction, an exception is raised.
// See the ExchangePlansManager.SelectChanges() method in Syntax Assistant.
//
Function SelectChanges(Val Node, Val MessageNumber, Val SelectionFilter = Undefined) Export
	
	If TransactionActive() Then
		Raise NStr("ru = 'ŠŃŠ±Š¾ŃŠŗŠ° ŠøŠ·Š¼ŠµŠ½ŠµŠ½ŠøŠ¹ Š“Š°Š½Š½ŃŃ Š·Š°ŠæŃŠµŃŠµŠ½Š° Š² Š°ŠŗŃŠøŠ²Š½Š¾Š¹ ŃŃŠ°Š½Š·Š°ŠŗŃŠøŠø.'; en = 'Selection of data changes in an active transaction is not allowed.'; pl = 'WybĆ³r zmiany danych jest zabroniony dla aktywnej transakcji.';es_ES = 'SelecciĆ³n de cambio de datos estĆ” prohibida en una transacciĆ³n activa.';es_CO = 'SelecciĆ³n de cambio de datos estĆ” prohibida en una transacciĆ³n activa.';tr = 'Etkin bir iÅlemde veri deÄiÅikliÄi seĆ§imi yasaktÄ±r.';it = 'Selezione delle modifiche ai dati in una transazione attiva non disponibile.';de = 'Die Auswahl der DatenĆ¤nderung ist in einer aktiven Transaktion verboten.'");
	EndIf;
	
	Return ExchangePlans.SelectChanges(Node, MessageNumber, SelectionFilter);
EndFunction

Function WSParameterStructure() Export
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("WSWebServiceURL");
	ParametersStructure.Insert("WSUsername");
	ParametersStructure.Insert("WSPassword");
	
	Return ParametersStructure;
	
EndFunction

Function DataExchangeMonitorTable(Val ExchangePlans, Val ExchangePlanAdditionalProperties = "") Export
	
	Query = New Query(
	"SELECT
	|	DataExchangeScenarioExchangeSettings.InfobaseNode AS InfobaseNode
	|INTO DataSynchronizationScenarios
	|FROM
	|	Catalog.DataExchangeScenarios.ExchangeSettings AS DataExchangeScenarioExchangeSettings
	|WHERE
	|	DataExchangeScenarioExchangeSettings.Ref.UseScheduledJob = TRUE
	|
	|GROUP BY
	|	DataExchangeScenarioExchangeSettings.InfobaseNode
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExchangePlans.InfobaseNode AS InfobaseNode,
	|
	|	[ExchangePlanAdditionalProperties]
	|
	|	ISNULL(DataExchangeStatesExport.ExchangeExecutionResult, 0) AS LastDataExportResult,
	|	ISNULL(DataExchangeStatesImport.ExchangeExecutionResult, 0) AS LastDataImportResult,
	|	ISNULL(DataExchangeStatesImport.StartDate, DATETIME(1, 1, 1)) AS LastImportStartDate,
	|	ISNULL(DataExchangeStatesImport.EndDate, DATETIME(1, 1, 1)) AS LastImportEndDate,
	|	ISNULL(DataExchangeStatesExport.StartDate, DATETIME(1, 1, 1)) AS LastExportStartDate,
	|	ISNULL(DataExchangeStatesExport.EndDate, DATETIME(1, 1, 1)) AS LastExportEndDate,
	|	ISNULL(SuccessfulDataExchangeStatesImport.EndDate, DATETIME(1, 1, 1)) AS LastSuccessfulExportEndDate,
	|	ISNULL(SuccessfulDataExchangeStatesExport.EndDate, DATETIME(1, 1, 1)) AS LastSuccessfulImportEndDate,
	|	CASE
	|		WHEN DataSynchronizationScenarios.InfobaseNode IS NULL
	|			THEN 0
	|		ELSE 1
	|	END AS ScheduleConfigured,
	|	CommonInfobasesNodesSettings.CorrespondentVersion AS CorrespondentVersion,
	|	CommonInfobasesNodesSettings.CorrespondentPrefix AS CorrespondentPrefix,
	|	CommonInfobasesNodesSettings.SetupCompleted AS SetupCompleted,
	|	CASE
	|		WHEN ISNULL(DataExchangeStatesExport.ExchangeExecutionResult, 0) = 0
	|				AND ISNULL(DataExchangeStatesImport.ExchangeExecutionResult, 0) = 0
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS HasErrors,
	|	ISNULL(MessagesForDataMapping.EmailReceivedForDataMapping, FALSE) AS EmailReceivedForDataMapping,
	|	ISNULL(MessagesForDataMapping.LastMessageStoragePlacementDate, DATETIME(1, 1, 1)) AS DataMapMessageDate
	|FROM
	|	ConfigurationExchangePlans AS ExchangePlans
	|		LEFT JOIN CommonInfobasesNodesSettings AS CommonInfobasesNodesSettings
	|		ON (CommonInfobasesNodesSettings.InfobaseNode = ExchangePlans.InfobaseNode)
	|		LEFT JOIN DataExchangeStatesImport AS DataExchangeStatesImport
	|		ON (DataExchangeStatesImport.InfobaseNode = ExchangePlans.InfobaseNode)
	|		LEFT JOIN DataExchangeStatesExport AS DataExchangeStatesExport
	|		ON (DataExchangeStatesExport.InfobaseNode = ExchangePlans.InfobaseNode)
	|		LEFT JOIN SuccessfulDataExchangeStatesImport AS SuccessfulDataExchangeStatesImport
	|		ON (SuccessfulDataExchangeStatesImport.InfobaseNode = ExchangePlans.InfobaseNode)
	|		LEFT JOIN SuccessfulDataExchangeStatesExport AS SuccessfulDataExchangeStatesExport
	|		ON (SuccessfulDataExchangeStatesExport.InfobaseNode = ExchangePlans.InfobaseNode)
	|		LEFT JOIN DataSynchronizationScenarios AS DataSynchronizationScenarios
	|		ON (DataSynchronizationScenarios.InfobaseNode = ExchangePlans.InfobaseNode)
	|		LEFT JOIN MessagesForDataMapping AS MessagesForDataMapping
	|		ON MessagesForDataMapping.InfobaseNode = ExchangePlans.InfobaseNode
	|
	|ORDER BY
	|	ExchangePlans.Description");
	
	Query.Text = StrReplace(Query.Text, "[ExchangePlanAdditionalProperties]",
		AdditionalExchangePlanPropertiesAsString(ExchangePlanAdditionalProperties));
		
	TempTablesManager = New TempTablesManager;
	Query.TempTablesManager = TempTablesManager;
	
	SetPrivilegedMode(True);
	GetExchangePlansForMonitor(TempTablesManager, ExchangePlans, ExchangePlanAdditionalProperties);
	GetExchangeResultsForMonitor(TempTablesManager);
	GetDataExchangeStates(TempTablesManager);
	GetMessagesToMapData(TempTablesManager);
	GetCommonInfobaseNodesSettings(TempTablesManager);
	
	SynchronizationSettings = Query.Execute().Unload();
	
	SynchronizationSettings.Columns.Add("DataExchangeOption", New TypeDescription("String"));
	SynchronizationSettings.Columns.Add("ExchangePlanName",       New TypeDescription("String"));
	
	SynchronizationSettings.Columns.Add("LastRunDate", New TypeDescription("Date"));
	SynchronizationSettings.Columns.Add("LastStartDatePresentation", New TypeDescription("String"));
	
	SynchronizationSettings.Columns.Add("LastImportDatePresentation", New TypeDescription("String"));
	SynchronizationSettings.Columns.Add("LastExportDatePresentation", New TypeDescription("String"));
	
	SynchronizationSettings.Columns.Add("LastSuccessfulImportDatePresentation", New TypeDescription("String"));
	SynchronizationSettings.Columns.Add("LastSuccessfulExportDatePresentation", New TypeDescription("String"));
	
	SynchronizationSettings.Columns.Add("MessageDatePresentationForDataMapping", New TypeDescription("String"));
	
	For Each SyncSetup In SynchronizationSettings Do
		
		SyncSetup.LastRunDate = Max(SyncSetup.LastImportStartDate,
			SyncSetup.LastExportStartDate);
		SyncSetup.LastStartDatePresentation = RelativeSynchronizationDate(
			SyncSetup.LastRunDate);
		
		SyncSetup.LastImportDatePresentation = RelativeSynchronizationDate(
			SyncSetup.LastImportEndDate);
		SyncSetup.LastExportDatePresentation = RelativeSynchronizationDate(
			SyncSetup.LastExportEndDate);
		SyncSetup.LastSuccessfulImportDatePresentation = RelativeSynchronizationDate(
			SyncSetup.LastSuccessfulExportEndDate);
		SyncSetup.LastSuccessfulExportDatePresentation = RelativeSynchronizationDate(
			SyncSetup.LastSuccessfulImportEndDate);
		
		SyncSetup.MessageDatePresentationForDataMapping = RelativeSynchronizationDate(
			ToLocalTime(SyncSetup.DataMapMessageDate));
		
		SyncSetup.DataExchangeOption = DataExchangeOption(SyncSetup.InfobaseNode);
		SyncSetup.ExchangePlanName = DataExchangeCached.GetExchangePlanName(SyncSetup.InfobaseNode);
		
	EndDo;
	
	Return SynchronizationSettings;
	
EndFunction

Procedure CheckCanSynchronizeData(OnlineApplication = False) Export
	
	If Not AccessRight("View", Metadata.CommonCommands.Synchronize) Then
		
		If OnlineApplication Then
			Raise NStr("ru = 'ŠŠµŠ“Š¾ŃŃŠ°ŃŠ¾ŃŠ½Š¾ ŠæŃŠ°Š² Š“Š»Ń ŃŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŠø Š“Š°Š½Š½ŃŃ Ń ŠæŃŠøŠ»Š¾Š¶ŠµŠ½ŠøŠµŠ¼ Š² ŠŠ½ŃŠµŃŠ½ŠµŃŠµ.'; en = 'Insufficient rights to synchronize data with the online application.'; pl = 'Nie wystarczajÄce uprawnienia dla synchronizacji danych z aplikacjÄ w Internecie.';es_ES = 'Insuficientes derechos para sincronizar los datos de aplicaciĆ³n en Internet.';es_CO = 'Insuficientes derechos para sincronizar los datos de aplicaciĆ³n en Internet.';tr = 'Verilerin Ä°nternet''teki uygulama ile eÅleÅmesi iĆ§in olan haklar yetersizdir.';it = 'Diritti insufficienti per sincronizzare i dati con l''applicazione online.';de = 'Unzureichende Rechte zur Synchronisation von Daten mit der Anwendung im Internet.'");
		Else
			Raise NStr("ru = 'ŠŠµŠ“Š¾ŃŃŠ°ŃŠ¾ŃŠ½Š¾ ŠæŃŠ°Š² Š“Š»Ń ŃŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŠø Š“Š°Š½Š½ŃŃ.'; en = 'Insufficient rights to perform the data synchronization.'; pl = 'NiewystarczajÄce uprawnienia do synchronizacji danych.';es_ES = 'Insuficientes derechos para sincronizar los datos.';es_CO = 'Insuficientes derechos para sincronizar los datos.';tr = 'Veri senkronizasyonu iĆ§in yetersiz haklar.';it = 'Permessi insufficienti per eseguire la sincronizzazione dati.';de = 'Unzureichende Rechte fĆ¼r die Datensynchronisierung.'");
		EndIf;
		
	ElsIf InfobaseUpdate.InfobaseUpdateRequired()
	        AND Not DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart("ImportPermitted") Then
		
		If OnlineApplication Then	
			Raise NStr("ru = 'ŠŃŠøŠ»Š¾Š¶ŠµŠ½ŠøŠµ Š² ŠŠ½ŃŠµŃŠ½ŠµŃŠµ Š½Š°ŃŠ¾Š“ŠøŃŃŃ Š² ŃŠ¾ŃŃŠ¾ŃŠ½ŠøŠø Š¾Š±Š½Š¾Š²Š»ŠµŠ½ŠøŃ.'; en = 'Online application is being updated.'; pl = 'Aplikacja w Internecie znajduje siÄ w statusie aktualizacji.';es_ES = 'La aplicaciĆ³n en Internet se encuentra en el estado de actualizaciĆ³n.';es_CO = 'La aplicaciĆ³n en Internet se encuentra en el estado de actualizaciĆ³n.';tr = 'Ä°nternetteki uygulama gĆ¼ncelleniyor.';it = 'Applicazione online in aggiornamento.';de = 'Die Internetanwendung wird derzeit aktualisiert.'");
		Else
			Raise NStr("ru = 'ŠŠ½ŃŠ¾ŃŠ¼Š°ŃŠøŠ¾Š½Š½Š°Ń Š±Š°Š·Š° Š½Š°ŃŠ¾Š“ŠøŃŃŃ Š² ŃŠ¾ŃŃŠ¾ŃŠ½ŠøŠø Š¾Š±Š½Š¾Š²Š»ŠµŠ½ŠøŃ.'; en = 'Current infobase is updating now.'; pl = 'Baza informacyjna zostaÅa zaktualizowana.';es_ES = 'Infobase se estĆ” actualizando.';es_CO = 'Infobase se estĆ” actualizando.';tr = 'VeritabanÄ± gĆ¼ncelleniyor.';it = 'L''infobase corrente ĆØ in aggiornamento al momento.';de = 'Infobase wird aktualisiert.'");
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CheckDataExchangeUsage(SetUsing = False) Export
	
	If Not GetFunctionalOption("UseDataSynchronization") Then
		
		If Not Common.DataSeparationEnabled()
			AND SetUsing
			AND AccessRight("Edit", Metadata.Constants.UseDataSynchronization) Then
			
			Try
				Constants.UseDataSynchronization.Set(True);
			Except
				MessageText = DetailErrorDescription(ErrorInfo());
				WriteLogEvent(EventLogMessageTextDataExchange(), EventLogLevel.Error,,,MessageText);
				Raise MessageText;
			EndTry;
			
		Else
			MessageText = NStr("ru = 'Š”ŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŃ Š“Š°Š½Š½ŃŃ Š·Š°ŠæŃŠµŃŠµŠ½Š° Š°Š“Š¼ŠøŠ½ŠøŃŃŃŠ°ŃŠ¾ŃŠ¾Š¼.'; en = 'Synchronization is disabled by your administrator.'; pl = 'Synchronizacja danych zostaÅa zabroniona przez administratora.';es_ES = 'SincronicazaciĆ³n de datos estĆ” prohibida por el administrador.';es_CO = 'SincronicazaciĆ³n de datos estĆ” prohibida por el administrador.';tr = 'Veri senkronizasyonu yĆ¶netici tarafÄ±ndan yasaklanmÄ±ÅtÄ±r.';it = 'La sincronizzazione ĆØ stata disattivata dal Vostro amministratore.';de = 'Die Datensynchronisierung ist vom Administrator untersagt.'");
			WriteLogEvent(EventLogMessageTextDataExchange(), EventLogLevel.Error,,,MessageText);
			Raise MessageText;
		EndIf;
		
	EndIf;
	
EndProcedure

Function ExchangeParameters() Export
	
	ParametersStructure = New Structure;
	
	ParametersStructure.Insert("ExchangeMessagesTransportKind", Undefined);
	ParametersStructure.Insert("ExecuteImport", True);
	ParametersStructure.Insert("ExecuteExport", True);
	
	ParametersStructure.Insert("ParametersOnly",     False);
	
	ParametersStructure.Insert("TimeConsumingOperationAllowed", False);
	ParametersStructure.Insert("TimeConsumingOperation", False);
	ParametersStructure.Insert("OperationID", "");
	ParametersStructure.Insert("FileID", "");
	ParametersStructure.Insert("AuthenticationParameters", Undefined);
	
	ParametersStructure.Insert("MessageForDataMapping", False);
	
	Return ParametersStructure;
	
EndFunction

// An entry point to iterate data exchange, that is export and import data for the exchange plan node.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - an exchange plan node for which data exchange iteration is being executed.
//  ExchangeParametersForNode - Structure - contains the following parameters:
//    * PerformImport - Boolean - indicates whether data export is required.
//        Optional, the default value is True.
//    * PerformExport - Boolean - indicates whether data export is required.
//        Optional, the default value is True.
//    * ExchangeMessagesTransportKindĀ - EnumRef.ExchangeMessagesTransportKinds - a transport kind to 
//        use in the data exchange.
//        If the value is not set in the information register, then the default value is Enums.ExchangeMessageTransportKinds.FILE.
//        Optional, the default value is Undefined.
//    * TimeConsumingOperation - Boolean - indicates whether it is a time-consuming operation.
//        Optional, the default value is False.
//    * ActionID - String - contains a time-consuming operation ID as a string.
//        Optional, default value is an empty string.
//    * FileID - String - message file ID in the service.
//        Optional, default value is an empty string.
//    * TimeConsumingOperationAllowed - Boolean - indicates whether time-consuming operation is allowed.
//        Optional, the default value is False.
//    * AuthenticationParameters - Structure - contains authentication parameters for exchange via Web service.
//        Optional, the default value is Undefined.
//    * ParametersOnly - Boolean - indicates whether data is imported selectively on DIB exchange.
//        Optional, the default value is False.
//  Cancel - Boolean - a cancel flag, appears if errors occur on data exchange.
//  AdditionalParameters - Structure - reserved for internal use.
// 
Procedure ExecuteDataExchangeForInfobaseNode(InfobaseNode,
		ExchangeParameters, Cancel, AdditionalParameters = Undefined) Export
		
	If AdditionalParameters = Undefined Then
		AdditionalParameters = New Structure;
	EndIf;
		
	ActionImport = Enums.ActionsOnExchange.DataImport;
	ActionExport = Enums.ActionsOnExchange.DataExport;
	
	CheckCanSynchronizeData();
	
	CheckDataExchangeUsage();
	
	// Exchanging data through external connection.
	If ExchangeParameters.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.COM Then
		
		CheckExternalConnectionAvailable();
		
		If ExchangeParameters.ExecuteImport Then
			ExecuteExchangeActionForInfobaseNodeUsingExternalConnection(Cancel,
				InfobaseNode, ActionImport, Undefined);
		EndIf;
		
		If ExchangeParameters.ExecuteExport Then
			ExecuteExchangeActionForInfobaseNodeUsingExternalConnection(Cancel,
				InfobaseNode, ActionExport, Undefined, ExchangeParameters.MessageForDataMapping);
		EndIf;
		
	ElsIf ExchangeParameters.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS Then // Exchanging data through web service.
		
		If ExchangeParameters.ExecuteImport Then
			ExecuteExchangeActionForInfobaseNodeUsingWebService(Cancel,
				InfobaseNode, ActionImport, ExchangeParameters);
		EndIf;
		
		If ExchangeParameters.ExecuteExport Then
			ExecuteExchangeActionForInfobaseNodeUsingWebService(Cancel,
				InfobaseNode, ActionExport, ExchangeParameters);
		EndIf;
		
	Else // Exchanging data through ordinary channels.
		
		ParametersOnly = ExchangeParameters.ParametersOnly;
		ExchangeMessagesTransportKind = ExchangeParameters.ExchangeMessagesTransportKind;
		
		If ExchangeParameters.ExecuteImport Then
			ExecuteExchangeActionForInfobaseNode(Cancel, InfobaseNode,
				ActionImport, ExchangeMessagesTransportKind, ParametersOnly, AdditionalParameters);
		EndIf;
		
		If ExchangeParameters.ExecuteExport Then
			ExecuteExchangeActionForInfobaseNode(Cancel, InfobaseNode,
				ActionExport, ExchangeMessagesTransportKind, ParametersOnly, AdditionalParameters);
		EndIf;
		
	EndIf;
	
EndProcedure

Function GetWSProxyByConnectionParameters(
					SettingsStructure,
					ErrorMessageString = "",
					UserMessage = "",
					ProbingCallRequired = False) Export
	
	Try
		CheckWSProxyAddressFormatCorrectness(SettingsStructure.WSWebServiceURL);
	Except
		UserMessage = BriefErrorDescription(ErrorInfo());
		ErrorMessageString = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(EventLogEventEstablishWebServiceConnection(), EventLogLevel.Error,,, ErrorMessageString);
		Return Undefined;
	EndTry;

	Try
		CheckProhibitedCharsInWSProxyUserName(SettingsStructure.WSUsername);
	Except
		UserMessage = BriefErrorDescription(ErrorInfo());
		ErrorMessageString = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(EventLogEventEstablishWebServiceConnection(), EventLogLevel.Error,,, ErrorMessageString);
		Return Undefined;
	EndTry;
	
	WSDLLocation = "[WebServiceURL]/ws/[ServiceName]?wsdl";
	WSDLLocation = StrReplace(WSDLLocation, "[WebServiceURL]", SettingsStructure.WSWebServiceURL);
	WSDLLocation = StrReplace(WSDLLocation, "[ServiceName]",    SettingsStructure.WSServiceName);
	
	ConnectionParameters = Common.WSProxyConnectionParameters();
	ConnectionParameters.WSDLAddress = WSDLLocation;
	ConnectionParameters.NamespaceURI = SettingsStructure.WSServiceNamespaceURL;
	ConnectionParameters.ServiceName = SettingsStructure.WSServiceName;
	ConnectionParameters.UserName = SettingsStructure.WSUsername; 
	ConnectionParameters.Password = SettingsStructure.WSPassword;
	ConnectionParameters.Timeout = SettingsStructure.WSTimeout;
	ConnectionParameters.ProbingCallRequired = ProbingCallRequired;
	
	Try
		WSProxy = Common.CreateWSProxy(ConnectionParameters);
	Except
		UserMessage = BriefErrorDescription(ErrorInfo());
		ErrorMessageString = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(EventLogEventEstablishWebServiceConnection(), EventLogLevel.Error,,, ErrorMessageString);
		Return Undefined;
	EndTry;
	
	Return WSProxy;
EndFunction

// Deletes data synchronization setting.
// 
// Parameters:
//   InfobaseNode - ExchangePlanRef - a reference to the exchange plan node to be deleted.
// 
Procedure DeleteSynchronizationSetting(InfobaseNode) Export
	
	CheckExchangeManagementRights();
	
	NodeObject = InfobaseNode.GetObject();
	If NodeObject = Undefined Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	Common.DeleteDataFromSecureStorage(InfobaseNode);
	NodeObject.Delete();
	
EndProcedure

// Deletes setting of data synchronization with master DIB node.
// 
// Parameters:
//   InfobaseNode - ExchangePlanRef - a reference to the master node.
// 
Procedure DeleteSynchronizationSettingsForMasterDIBNode(InfobaseNode) Export
	
	DeleteSynchronizationSetting(InfobaseNode);
	
	SubordinateDIBNodeSetupCompleted = Constants.SubordinateDIBNodeSetupCompleted.CreateValueManager();
	SubordinateDIBNodeSetupCompleted.Read();
	If SubordinateDIBNodeSetupCompleted.Value Then
		SubordinateDIBNodeSetupCompleted.Value = False;
		InfobaseUpdate.WriteData(SubordinateDIBNodeSetupCompleted);
	EndIf;
	
EndProcedure

// Sets the Load parameter value for the DataExchange object property.
//
// Parameters:
//  Object - Any object - an object whose property is being set.
//  Value - Boolean - a value of the Import property being set.
//  SendBack - Boolean - shows that data must be registered to send it back.
//  ExchangeNode - ExchangePlanRef - shows that data must be registered to send it back.
//
Procedure SetDataExchangeLoad(Object, Value = True, SendBack = False, ExchangeNode = Undefined) Export
	
	Object.DataExchange.Load = Value;
	
	If Not SendBack
		AND ExchangeNode <> Undefined
		AND NOT ExchangeNode.IsEmpty() Then
	
		ObjectValueType = TypeOf(Object);
		MetadataObject = Metadata.FindByType(ObjectValueType);
		
		If Metadata.ExchangePlans[ExchangeNode.Metadata().Name].Content.Contains(MetadataObject) Then
			Object.DataExchange.Sender = ExchangeNode;
		EndIf;
	
	EndIf;
	
EndProcedure

Function ExchangePlanPurpose(ExchangePlanName) Export
	
	Return DataExchangeCached.ExchangePlanPurpose(ExchangePlanName);
	
EndFunction

// Procedure of deleting existing document register records upon reposting (posting cancellation).
//
// Parameters:
//   DocumentObject - DocumentObject - a document whose register records must be deleted.
//
Procedure DeleteDocumentRegisterRecords(DocumentObject) Export
	
	RecordTableRowToProcessArray = New Array();
	
	// Getting a list of registers with existing records.
	RegisterRecordTable = GetDocumentHasRegisterRecords(DocumentObject.Ref);
	RegisterRecordTable.Columns.Add("RecordSet");
	RegisterRecordTable.Columns.Add("ForceDelete", New TypeDescription("Boolean"));
		
	For Each RegisterRecordRow In RegisterRecordTable Do
		// The register name is passed as a value received using the FullName() function of register 
		// metadata.
		PointPosition = StrFind(RegisterRecordRow.Name, ".");
		TypeRegister = Left(RegisterRecordRow.Name, PointPosition - 1);
		RegisterName = TrimR(Mid(RegisterRecordRow.Name, PointPosition + 1));

		RecordTableRowToProcessArray.Add(RegisterRecordRow);
		
		If TypeRegister = "AccumulationRegister" Then
			SetMetadata = Metadata.AccumulationRegisters[RegisterName];
			Set = AccumulationRegisters[RegisterName].CreateRecordSet();
		ElsIf TypeRegister = "AccountingRegister" Then
			SetMetadata = Metadata.AccountingRegisters[RegisterName];
			Set = AccountingRegisters[RegisterName].CreateRecordSet();
		ElsIf TypeRegister = "InformationRegister" Then
			SetMetadata = Metadata.InformationRegisters[RegisterName];
			Set = InformationRegisters[RegisterName].CreateRecordSet();
		ElsIf TypeRegister = "CalculationRegister" Then
			SetMetadata = Metadata.CalculationRegisters[RegisterName];
			Set = CalculationRegisters[RegisterName].CreateRecordSet();
		EndIf;
		
		If Not AccessRight("Update", Set.Metadata()) Then
			// Insufficient access rights for the entire register table.
			ExceptionText = NStr("ru = 'ŠŠ°ŃŃŃŠµŠ½ŠøŠµ ŠæŃŠ°Š² Š“Š¾ŃŃŃŠæŠ°: %1'; en = 'Access %1 right violation'; pl = 'Naruszenia praw dostÄpu: %1';es_ES = 'ViolaciĆ³n del derecho de acceso: %1';es_CO = 'ViolaciĆ³n del derecho de acceso: %1';tr = 'EriÅim haklarÄ±nÄ±n ihlali: %1';it = 'Violazione del diritto %1 di accesso';de = 'Zugriffsrechtsverletzung: %1'");
			ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(ExceptionText, RegisterRecordRow.Name);
			Raise ExceptionText;
		EndIf;

		Set.Filter.Recorder.Set(DocumentObject.Ref);

		// The set is not recorded immediately so that not to roll back the transaction if it turns out 
		// later that user does not have sufficient rights to one of the registers.
		RegisterRecordRow.RecordSet = Set;
		
	EndDo;
	
	SkipPeriodClosingCheck();
	
	For Each RegisterRecordRow In RecordTableRowToProcessArray Do		
		Try
			RegisterRecordRow.RecordSet.Write();
		Except
			// It is possible that the restriction at the record level or the period-end closing date subsystem has activated.
			ExceptionText = NStr("ru = 'ŠŠæŠµŃŠ°ŃŠøŃ Š½Šµ Š²ŃŠæŠ¾Š»Š½ŠµŠ½Š°: %1
				|%2'; 
				|en = 'Operation failed: %1
				|%2'; 
				|pl = 'Operacja nie jest wykonana: %1
				|%2';
				|es_ES = 'OperaciĆ³n no realizada: %1
				|%2';
				|es_CO = 'OperaciĆ³n no realizada: %1
				|%2';
				|tr = 'Ä°Ålem yapÄ±lamadÄ±: %1
				|%2';
				|it = 'Operazione non riuscita: %1
				|%2';
				|de = 'Operation fehlgeschlagen: %1
				|%2'");
			ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(ExceptionText, RegisterRecordRow.Name, BriefErrorDescription(ErrorInfo()));
			Raise ExceptionText;
		EndTry;
	EndDo;
	
	SkipPeriodClosingCheck(False);
	
	For Each RegisterRecord In DocumentObject.RegisterRecords Do
		If RegisterRecord.Count() > 0 Then
			RegisterRecord.Clear();
		EndIf;
	EndDo;
	
	// Deleting registration records from all sequences.
	If DocumentObject.Metadata().SequenceFilling = Metadata.ObjectProperties.SequenceFilling.AutoFill Then
		QueryText = "";
		
		For Each Sequence In DocumentObject.BelongingToSequences Do
			// In the query, getting names of the sequences where the document is registered.
			QueryText = QueryText + "
			|" + ?(QueryText = "", "", "UNION ALL ") + "
			|SELECT """ + Sequence.Metadata().Name
			+  """ AS Name FROM " + Sequence.Metadata().FullName()
			+ " WHERE Recorder = &Recorder";
			
		EndDo;
		
		If QueryText = "" Then
			RecordChangeTable = New ValueTable();
		Else
			Query = New Query(QueryText);
			Query.SetParameter("Recorder", DocumentObject.Ref);
			RecordChangeTable = Query.Execute().Unload();
		EndIf;
		
		// Getting the list of the sequences where the document is registered.
		SequenceCollection = DocumentObject.BelongingToSequences;
		For Each SequenceRecordRecordSet In SequenceCollection Do
			If (SequenceRecordRecordSet.Count() > 0)
				OR (NOT RecordChangeTable.Find(SequenceRecordRecordSet.Metadata().Name,"Name") = Undefined) Then
				SequenceRecordRecordSet.Clear();
			EndIf;
		EndDo;
	EndIf;

EndProcedure

// Indicates whether it is necessary to import data exchange message.
//
// Returns:
//   Boolean - if True, the message is to be imported. Otherwise, False.
//
Function LoadDataExchangeMessage() Export
	
	SetPrivilegedMode(True);
	
	Return Constants.LoadDataExchangeMessage.Get();
	
EndFunction

// Intended for moving passwords to a secure storage.
// This procedure is used in the infobase update handler.
Procedure MovePasswordsToSecureStorage() Export
	
	Query = New Query(
	"SELECT
	|	TransportSettings.InfobaseNode,
	|	TransportSettings.DeleteCOMUserPassword,
	|	TransportSettings.DeleteFTPConnectionPassword,
	|	TransportSettings.DeleteWSPassword,
	|	TransportSettings.DeleteExchangeMessageArchivePassword
	|FROM
	|	InformationRegister.DeleteExchangeTransportSettings AS TransportSettings");
	
	QueryResult = Query.Execute().Select();
	While QueryResult.Next() Do
		If Not IsBlankString(QueryResult.DeleteCOMUserPassword)
			Or Not IsBlankString(QueryResult.DeleteFTPConnectionPassword)
			Or Not IsBlankString(QueryResult.DeleteWSPassword) 
			Or Not IsBlankString(QueryResult.DeleteExchangeMessageArchivePassword) Then
			BeginTransaction();
			Try
				SetPrivilegedMode(True);
				Common.WriteDataToSecureStorage(QueryResult.InfobaseNode, QueryResult.DeleteCOMUserPassword, "COMUserPassword");
				Common.WriteDataToSecureStorage(QueryResult.InfobaseNode, QueryResult.DeleteFTPConnectionPassword, "FTPConnectionPassword");
				Common.WriteDataToSecureStorage(QueryResult.InfobaseNode, QueryResult.DeleteWSPassword, "WSPassword");
				Common.WriteDataToSecureStorage(QueryResult.InfobaseNode, QueryResult.DeleteExchangeMessageArchivePassword, "ExchangeMessageArchivePassword");
				SetPrivilegedMode(False);
				
				RecordStructure = New Structure("InfobaseNode", QueryResult.InfobaseNode);
				RecordStructure.Insert("DeleteCOMUserPassword", "");
				RecordStructure.Insert("DeleteFTPConnectionPassword", "");
				RecordStructure.Insert("DeleteWSPassword", "");
				RecordStructure.Insert("DeleteExchangeMessageArchivePassword", "");
				
				UpdateInformationRegisterRecord(RecordStructure, "DeleteExchangeTransportSettings");
				
				CommitTransaction();
			Except
				RollbackTransaction();
				
				ErrorMessageString = DetailErrorDescription(ErrorInfo());
				WriteLogEvent(EventLogMessageTextDataExchange(), EventLogLevel.Error,,, ErrorMessageString);
			EndTry;
		EndIf;
	EndDo;

EndProcedure

#EndRegion

#Region ConfigurationSubsystemsEventHandlers

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "DataExchangeServer.SetPredefinedNodeCodes";
	Handler.ExecutionMode = "Seamless";

	Handler = Handlers.Add();
	Handler.Version = "1.1.1.2";
	Handler.Procedure = "DataExchangeServer.SetMappingDataAdjustmentRequiredForAllInfobaseNodes";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.1.2";
	Handler.Procedure = "DataExchangeServer.SetExportModeForAllInfobaseNodes";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.1.2";
	Handler.SharedData = True;
	Handler.Procedure = "DataExchangeServer.UpdateDataExchangeScenarioScheduledJobs";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.2.0";
	Handler.Procedure = "DataExchangeServer.UpdateSubordinateDIBNodeSetupCompletedConstant";
	
	Handler = Handlers.Add();
	Handler.Version = "2.0.1.10";
	Handler.SharedData = True;
	Handler.Procedure = "DataExchangeServer.CheckFunctionalOptionsAreSetOnUpdateIB";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.1.5";
	Handler.SharedData = True;
	Handler.Procedure = "DataExchangeServer.SetExchangePasswordSaveOverInternetFlag";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.12";
	Handler.Procedure = "DataExchangeServer.ClearExchangeMonitorSettings";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.21";
	Handler.SharedData = True;
	Handler.Procedure = "DataExchangeServer.CheckFunctionalOptionsAreSetOnUpdateIB_2_1_2_21";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.2.4";
	Handler.SharedData = True;
	Handler.Procedure = "DataExchangeServer.SetItemCountForDataImportTransaction_2_2_2_4";
	
	Handler = Handlers.Add();
	Handler.Version = "2.4.1.1";
	Handler.Procedure = "DataExchangeServer.DeleteDataSynchronizationSetupRole";
	Handler.ExecutionMode = "Seamless";
	
	Handler = Handlers.Add();
	Handler.Version = "3.0.1.91";
	Handler.Comment =
		NStr("ru = 'ŠŠµŃŠµŠ½Š¾Ń Š½Š°ŃŃŃŠ¾ŠµŠŗ ŠæŠ¾Š“ŠŗŠ»ŃŃŠµŠ½ŠøŃ Š¾Š±Š¼ŠµŠ½Š¾Š² Š“Š°Š½Š½ŃŠ¼Šø Š² Š½Š¾Š²ŃŠ¹ ŃŠµŠ³ŠøŃŃŃ ""ŠŠ°ŃŃŃŠ¾Š¹ŠŗŠø ŃŃŠ°Š½ŃŠæŠ¾ŃŃŠ° Š¾Š±Š¼ŠµŠ½Š° Š“Š°Š½Š½ŃŠ¼Šø"".'; en = 'Transfer of data exchange connection settings to the new register ""Data exchange transport settings"".'; pl = 'Przeniesienie ustawieÅ podÅÄczenia wymian danych do nowego rejestru ""Ustawienia transportu wymiany danych"".';es_ES = 'El traslado de los ajustes de conexiĆ³n de intercambios de datos al registro nuevo ""Ajustes del transporte de intercambio de datos"".';es_CO = 'El traslado de los ajustes de conexiĆ³n de intercambios de datos al registro nuevo ""Ajustes del transporte de intercambio de datos"".';tr = 'Veri alÄ±ÅveriÅi baÄlantÄ± ayarlarÄ±nÄ± yeni ""Veri alÄ±ÅveriÅi aktarÄ±m ayarlarÄ±"" kaydÄ±na aktarma.';it = 'Trasferimento delle impostazioni di connessione dello scambio dati al nuovo registro ""Impostazioni di trasporto dello scambio dati"".';de = 'Ćbertragung der Datenaustausch-Verbindungseinstellungen in das neue Register ""Datenaustausch-Transporteinstellungen"".'");
	Handler.ID = New UUID("8d5f1092-f569-4c03-aca9-65625809b853");
	Handler.Procedure = "InformationRegisters.DeleteExchangeTransportSettings.ProcessDataForMigrationToNewVersion";
	Handler.ExecutionMode = "Deferred";
	Handler.ObjectsToRead = "InformationRegister.DeleteExchangeTransportSettings";
	Handler.ObjectsToChange = "InformationRegister.DeleteExchangeTransportSettings,InformationRegister.DataExchangeTransportSettings";
	Handler.DeferredProcessingQueue = 1;
	Handler.RunAlsoInSubordinateDIBNodeWithFilters = True;
	Handler.UpdateDataFillingProcedure = "InformationRegisters.DeleteExchangeTransportSettings.RegisterDataToProcessForMigrationToNewVersion";
	Handler.CheckProcedure = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.ObjectsToLock = "InformationRegister.DeleteExchangeTransportSettings,InformationRegister.DataExchangeTransportSettings";
	
	Handler = Handlers.Add();
	Handler.Version = "3.0.1.281";
	Handler.Comment =
		NStr("ru = 'ŠŠ°ŠæŠ¾Š»Š½ŠµŠ½ŠøŠµ Š²ŃŠæŠ¾Š¼Š¾Š³Š°ŃŠµŠ»ŃŠ½ŃŃ Š½Š°ŃŃŃŠ¾ŠµŠŗ Š¾Š±Š¼ŠµŠ½Š° Š“Š°Š½Š½ŃŠ¼Šø Š² ŃŠµŠ³ŠøŃŃŃŠµ ""ŠŠ±ŃŠøŠµ Š½Š°ŃŃŃŠ¾Š¹ŠŗŠø ŃŠ·Š»Š¾Š² ŠøŠ½ŃŠ¾ŃŠ¼Š°ŃŠøŠ¾Š½Š½ŃŃ Š±Š°Š·"".'; en = 'Fill in auxiliary data exchange settings in the ""General settings of infobase nodes"" register.'; pl = 'WypeÅnienie ustawieÅ pomocniczych wymiany danych w rejestrze ""OgĆ³lne ustawienia wÄzÅĆ³w informacyjnych baz"".';es_ES = 'Relleno de los ajustes auxiliares del intercambio de datos en el registro ""Configuraciones generales de los nodos de la infobase"".';es_CO = 'Relleno de los ajustes auxiliares del intercambio de datos en el registro ""Configuraciones generales de los nodos de la infobase"".';tr = '""Ortak Infobase dĆ¼ÄĆ¼m ayarlarÄ±"" kayÄ±tlarÄ±nda veri alÄ±ÅveriÅi destek ayarlarÄ±nÄ± doldur.';it = 'Compilare le impostazioni di scambio dati ausiliare nel registro ""Impostazioni generale dei nodi di infobase"".';de = 'AusfĆ¼llen der zusĆ¤tzlichen Datenaustausch-Einstellungen im Register ""Allgemeine Einstellungen von Infobaseknoten"".'");
	Handler.ID = New UUID("e1cd64f1-3df9-4ea6-8076-1ba0627ba104");
	Handler.Procedure = "InformationRegisters.CommonInfobasesNodesSettings.ProcessDataForMigrationToNewVersion";
	Handler.ExecutionMode = "Deferred";
	Handler.ObjectsToRead = "InformationRegister.CommonInfobasesNodesSettings";
	Handler.ObjectsToChange = "InformationRegister.CommonInfobasesNodesSettings";
	Handler.DeferredProcessingQueue = 1;
	Handler.RunAlsoInSubordinateDIBNodeWithFilters = True;
	Handler.UpdateDataFillingProcedure = "InformationRegisters.CommonInfobasesNodesSettings.RegisterDataToProcessForMigrationToNewVersion";
	Handler.CheckProcedure = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.ObjectsToLock = "InformationRegister.CommonInfobasesNodesSettings";
	
	Handler = Handlers.Add();
	Handler.Version = "3.0.1.91";
	Handler.Comment =
		NStr("ru = 'ŠŠµŃŠ²Š¾Š½Š°ŃŠ°Š»ŃŠ½Š¾Šµ Š·Š°ŠæŠ¾Š»Š½ŠµŠ½ŠøŠµ Š½Š°ŃŃŃŠ¾ŠµŠŗ Š¾Š±Š¼ŠµŠ½Š° Š“Š°Š½Š½ŃŠ¼Šø XDTO.'; en = 'Initial filling of XDTO data exchange settings.'; pl = 'PoczÄtkowe wypeÅnienie ustawieÅ wymiany danych XDTO.';es_ES = 'Relleno inicial de los ajustes de intercambio de datos XDTO.';es_CO = 'Relleno inicial de los ajustes de intercambio de datos XDTO.';tr = 'XDTO veri alÄ±ÅveriÅi ayarlarÄ±nÄ± ilk doldurma.';it = 'Compilazione iniziale delle impostazioni di scambio dati XDTO.';de = 'Erstmaliges AusfĆ¼llen der XDTO-Kommunikationseinstellungen.'");
	Handler.ID = New UUID("2ea5ec7e-547b-4e8b-9c3f-d2d8652c8cdf");
	Handler.Procedure = "InformationRegisters.XDTODataExchangeSettings.ProcessDataForMigrationToNewVersion";
	Handler.ExecutionMode = "Deferred";
	Handler.ObjectsToRead = "InformationRegister.XDTODataExchangeSettings";
	Handler.ObjectsToChange = "InformationRegister.XDTODataExchangeSettings";
	Handler.DeferredProcessingQueue = 1;
	Handler.RunAlsoInSubordinateDIBNodeWithFilters = True;
	Handler.UpdateDataFillingProcedure = "InformationRegisters.XDTODataExchangeSettings.RegisterDataToProcessForMigrationToNewVersion";
	Handler.CheckProcedure = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.ObjectsToLock = "InformationRegister.XDTODataExchangeSettings";
	
EndProcedure

// See InfobaseUpdateSSL.InfobaseBeforeUpdate. 
Procedure BeforeUpdateInfobase(OnClientStart, Restart) Export
	
	If Common.DataSeparationEnabled() Then
		Return;	
	EndIf;
	
	If NOT InfobaseUpdate.InfobaseUpdateRequired() Then
		ExecuteSynchronizationWhenInfobaseUpdateAbsent(OnClientStart, Restart);
	Else	
		ImportMessageBeforeInfobaseUpdate();
	EndIf;

EndProcedure

// See InfobaseUpdateSSL.AfterUpdateInfobase. 
Procedure AfterUpdateInfobase() Export
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	InformationRegisters.DataSyncEventHandlers.RegisterInfobaseDataUpdate();
	
	ExportMessageAfterInfobaseUpdate();
	
EndProcedure	

// See BatchObjectModificationOverridable.OnDetermineObjectsWithEditableAttributes. 
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.DataExchangeScenarios.FullName(), "AttributesToSkipInBatchProcessing");
EndProcedure

// See SaaSOverridable.OnEnableDataSeparation. 
Procedure OnEnableSeparationByDataAreas() Export
	
	If NOT GetFunctionalOption("UseDataSynchronization") Then
		Constants.UseDataSynchronization.Set(True);
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddSessionParametersSettingHandlers. 
Procedure OnAddSessionParameterSettingHandlers(Handlers) Export
	
	Handlers.Insert("DataExchangeMessageImportModeBeforeStart", "DataExchangeServerCall.SessionParametersSetting");
	
	Handlers.Insert("ORMCachedValuesRefreshDate",    "DataExchangeServerCall.SessionParametersSetting");
	Handlers.Insert("SelectiveObjectsRegistrationRules",             "DataExchangeServerCall.SessionParametersSetting");
	Handlers.Insert("ObjectsRegistrationRules",                       "DataExchangeServerCall.SessionParametersSetting");
	Handlers.Insert("DataSynchronizationPasswords",                        "DataExchangeServerCall.SessionParametersSetting");
	Handlers.Insert("PriorityExchangeData",                         "DataExchangeServerCall.SessionParametersSetting");
	Handlers.Insert("VersionMismatchErrorOnGetData",        "DataExchangeServerCall.SessionParametersSetting");
	Handlers.Insert("DataSynchronizationSessionParameters",               "DataExchangeServerCall.SessionParametersSetting");
EndProcedure

// See CommonOverridable.OnDefineSupportedInterfaceVersions. 
Procedure OnDefineSupportedInterfaceVersions(Val SupportedVersionStructure) Export
	
	VersionsArray = New Array;
	VersionsArray.Add("2.0.1.6");
	VersionsArray.Add("2.1.1.7");
	VersionsArray.Add("3.0.1.1");
	SupportedVersionStructure.Insert("DataExchange", VersionsArray);
	
EndProcedure

// See CommonOverridable.OnAddClientParametersOnStart. 
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	SetPrivilegedMode(True);
	
	Parameters.Insert("DIBExchangePlanName", ?(IsSubordinateDIBNode(), MasterNode().Metadata().Name, ""));
	Parameters.Insert("MasterNode", MasterNode());
	
	If OpenDataExchangeCreationWizardForSubordinateNodeSetup() Then
		
		If Common.SubsystemExists("StandardSubsystems.Interactions") Then
			ModuleInteractions = Common.CommonModule("Interactions");
			ModuleInteractions.PerformCompleteStatesRecalculation();
		EndIf;
		
		Parameters.Insert("OpenDataExchangeCreationWizardForSubordinateNodeSetup");
		
	EndIf;
	
	SetPrivilegedMode(False);
	
	If Parameters.Property("OpenDataExchangeCreationWizardForSubordinateNodeSetup") Then
		
		ThisNode = ExchangePlans[Parameters.DIBExchangePlanName].ThisNode();
		Parameters.Insert("DIBNodeSettingID", SavedExchangePlanNodeSettingOption(ThisNode));
		
	EndIf;
	
	If Not Parameters.Property("OpenDataExchangeCreationWizardForSubordinateNodeSetup")
		AND AccessRight("View", Metadata.CommonCommands.Synchronize) Then
		
		Parameters.Insert("CheckSubordinateNodeConfigurationUpdateRequired");
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddClientParameters. 
Procedure OnAddClientParameters(Parameters) Export
	
	SetPrivilegedMode(True);
	
	Parameters.Insert("MasterNode", MasterNode());
	
EndProcedure

// See AccessManagementOverridable.OnFillSuppliedAccessGroupsProfiles. 
Procedure OnFillSuppliedAccessGroupProfiles(ProfilesDetails, UpdateParameters) Export
	
	// "Data synchronization with other applications" profile.
	ProfileDetails = Common.CommonModule("AccessManagement").NewAccessGroupProfileDescription();
	ProfileDetails.ID = DataSynchronizationWithOtherApplicationsAccessProfile();
	ProfileDetails.Description =
		NStr("ru = 'Š”ŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŃ Š“Š°Š½Š½ŃŃ Ń Š“ŃŃŠ³ŠøŠ¼Šø ŠæŃŠ¾Š³ŃŠ°Š¼Š¼Š°Š¼Šø'; en = 'Data synchronization with other applications'; pl = 'Synchronizacja danych z innymi aplikacjami';es_ES = 'SincronizaciĆ³n de datos con otras aplicaciones';es_CO = 'SincronizaciĆ³n de datos con otras aplicaciones';tr = 'DiÄer uygulamalarla veri senkronizasyonu';it = 'Sincronizzazione dei dati con altre applicazioni';de = 'Datensynchronisierung mit anderen Anwendungen'", Metadata.DefaultLanguage.LanguageCode);
	ProfileDetails.Details =
		NStr("ru = 'ŠŠ¾ŠæŠ¾Š»Š½ŠøŃŠµŠ»ŃŠ½Š¾ Š½Š°Š·Š½Š°ŃŠ°ŠµŃŃŃ ŃŠµŠ¼ ŠæŠ¾Š»ŃŠ·Š¾Š²Š°ŃŠµŠ»ŃŠ¼, ŠŗŠ¾ŃŠ¾ŃŃŠ¼ Š“Š¾Š»Š¶Š½Ń Š±ŃŃŃ Š“Š¾ŃŃŃŠæŠ½Ń ŃŃŠµŠ“ŃŃŠ²Š°
		           |Š“Š»Ń Š¼Š¾Š½ŠøŃŠ¾ŃŠøŠ½Š³Š° Šø ŃŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŠø Š“Š°Š½Š½ŃŃ Ń Š“ŃŃŠ³ŠøŠ¼Šø ŠæŃŠ¾Š³ŃŠ°Š¼Š¼Š°Š¼Šø.'; 
		           |en = 'Additionally assigned to those users who must have access
		           |to monitoring and data synchronization with other applications.'; 
		           |pl = 'Jest dodatkowo wyznaczana dla tych uÅ¼ytkownikĆ³w, dla ktĆ³rych powinny byÄ dostÄpne Årodki
		           |do monitoringu i synchronizacji danych z innymi programami.';
		           |es_ES = 'Se establece adicionalmente para los usuarios a los que deben estar disponibles las propiedades
		           | de controlar y sincronizar los datos con otros programas.';
		           |es_CO = 'Se establece adicionalmente para los usuarios a los que deben estar disponibles las propiedades
		           | de controlar y sincronizar los datos con otros programas.';
		           |tr = 'DiÄer uygulamalarla izleme ve veri senkronizasyonu iĆ§in 
		           |araĆ§lara eriÅimi olan kullanÄ±cÄ±lara ek olarak atandÄ±.';
		           |it = 'Assegnato in modo aggiuntivo agli utenti che devono avere accesso
		           |al monitoraggio e sincronizzazione dati con altre applicazioni.';
		           |de = 'DarĆ¼ber hinaus ist es denjenigen Benutzern zugeordnet, die Zugriff auf die Tools
		           |zur Ćberwachung und Synchronisation von Daten mit anderen Programmen haben sollen.'",
			Metadata.DefaultLanguage.LanguageCode);
	
	// Basic profile features
	ProfileRoles = StrSplit(DataSynchronizationAccessProfileWithOtherApplicationsRoles(), ",");
	For Each Role In ProfileRoles Do
		ProfileDetails.Roles.Add(TrimAll(Role));
	EndDo;
	ProfilesDetails.Add(ProfileDetails);
	
EndProcedure

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	
	OnFillToDoListSynchronizationWarnings(ToDoList);
	OnFillToDoListUpdateRequired(ToDoList);
	OnFillToDoListValidateCompatibilityWithCurrentVersion(ToDoList);
	
EndProcedure

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings. 
Procedure OnDefineScheduledJobSettings(Dependencies) Export
	Dependence = Dependencies.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.ObsoleteSynchronizationDataDeletion;
	Dependence.FunctionalOption = Metadata.FunctionalOptions.UseDataSynchronization;
	Dependence.UseExternalResources = True;
	
	Dependence = Dependencies.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.DataSynchronization;
	Dependence.UseExternalResources = True;
	Dependence.IsParameterized = True;
EndProcedure

// See CommonOverridable.OnAddMetadataObjectsRenaming. 
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	Common.AddRenaming(
		Total, "2.1.2.5", "Role.ExecuteDataExchange", "Role.DataSynchronizationInProgress", Library);
	
EndProcedure

// See CommonOverridable.OnAddRefsSearchExceptions. 
Procedure OnAddReferenceSearchExceptions(Array) Export
	
	Array.Add(Metadata.InformationRegisters.DataExchangeResults.FullName());
	
EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources. 
Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	If NOT GetFunctionalOption("UseDataSynchronization") Then
		Return;
	EndIf;
	
	CreateRequestsToUseExternalResources(PermissionRequests);
	
EndProcedure

// See SubsystemIntegrationSSL.ExternalModuleManagersOnRegistration. 
Procedure OnRegisterExternalModulesManagers(Managers) Export
	
	Managers.Add(DataExchangeServer);
	
EndProcedure


Procedure SetPredefinedNodeCodes() Export
	BeginTransaction();
	
	Try
		
		CodeFromSaaSMode = "";
		VirtualCodes = InformationRegisters.PredefinedNodesAliases.CreateRecordSet();
		
		If Common.DataSeparationEnabled()
			AND Common.SeparatedDataUsageAvailable()
			AND Common.SubsystemExists("StandardSubsystems.SaaS") Then
			
			ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
			ModuleSaaS = Common.CommonModule("SaaS");
			
			CodeFromSaaSMode = TrimAll(ModuleDataExchangeSaaS.ExchangePlanNodeCodeInService(ModuleSaaS.SessionSeparatorValue()));
			
		EndIf;
		
		For Each NodeRef In PredefinedNodesOfSSLExchangePlans() Do
			
			If Not IsXDTOExchangePlan(NodeRef) Then
				Continue;
			ElsIf Not DataExchangeXDTOServer.VersionWithDataExchangeIDSupported(NodeRef) Then
				Continue;
			EndIf;
			
			PredefinedNodeCode = TrimAll(Common.ObjectAttributeValue(NodeRef, "Code"));
			If Not ValueIsFilled(PredefinedNodeCode)
				// Migration to a new node encoding was not carried out.
				Or StrLen(PredefinedNodeCode) < 36
				// Re-encoding is required because the code is generated using STL logic.
				Or PredefinedNodeCode = CodeFromSaaSMode Then
				
				DataExchangeUUID = String(New UUID);
				
				ObjectNode = NodeRef.GetObject();
				ObjectNode.Code = DataExchangeUUID;
				ObjectNode.DataExchange.Load = True;
				ObjectNode.Write();
				
				If ValueIsFilled(PredefinedNodeCode) Then
					// Saving the previous node code to the register of virtual codes.
					QueryText = 
					"SELECT
					|	T.Ref AS Ref
					|FROM
					|	#ExchangePlanTable AS T
					|WHERE
					|	NOT T.ThisNode
					|	AND NOT T.DeletionMark";
					
					QueryText = StrReplace(QueryText,
						"#ExchangePlanTable", "ExchangePlan." + DataExchangeCached.GetExchangePlanName(NodeRef));
					
					Query = New Query(QueryText);
					
					ExchangePlanCorrespondents = Query.Execute().Select();
					While ExchangePlanCorrespondents.Next() Do
						VirtualCode = VirtualCodes.Add();
						VirtualCode.Correspondent = ExchangePlanCorrespondents.Ref;
						VirtualCode.NodeCode       = PredefinedNodeCode;
					EndDo;
				EndIf;
				
			EndIf;
		EndDo;
		
		If VirtualCodes.Count() > 0 Then
			VirtualCodes.Write();
		EndIf;
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure


#EndRegion

#EndRegion

#Region Private

Function ModuleDataSynchronizationBetweenWebApplicationsSetupWizard() Export
	
	If Common.SubsystemExists("CloudTechnology.SaaS.DataExchangeSaaS") Then
		Return Common.CommonModule("DataProcessors.DataSynchronizationBetweenWebApplicationsSetupWizard");
	EndIf;
	
	Return Undefined;
	
EndFunction

Function ModuleInteractiveDataExchangeWizardInSaaS() Export
	
	If Common.SubsystemExists("CloudTechnology.SaaS.DataExchangeSaaS") Then
		Return Common.CommonModule("DataProcessors.InteractiveDataExchangeWizardSaaS");
	EndIf;
	
	Return Undefined;
	
EndFunction

Function ModuleDataExchangeCreationWizard() Export
	
	Return Common.CommonModule("DataProcessors.DataExchangeCreationWizard");
	
EndFunction

Function ModuleInteractiveDataExchangeWizard() Export
	
	Return Common.CommonModule("DataProcessors.InteractiveDataExchangeWizard");
	
EndFunction

Function MessageWithDataForMappingReceived(ExchangeNode) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT
	|	MessagesForDataMapping.EmailReceivedForDataMapping AS EmailReceivedForDataMapping
	|FROM
	|	#ExchangePlanTable AS ExchangePlanTable
	|		INNER JOIN MessagesForDataMapping AS MessagesForDataMapping
	|		ON (MessagesForDataMapping.InfobaseNode = ExchangePlanTable.Ref)
	|WHERE
	|	ExchangePlanTable.Ref = &ExchangeNode");
	Query.SetParameter("ExchangeNode", ExchangeNode);
	Query.TempTablesManager = New TempTablesManager;
	
	Query.Text = StrReplace(Query.Text, "#ExchangePlanTable", "ExchangePlan." + DataExchangeCached.GetExchangePlanName(ExchangeNode));
	
	GetMessagesToMapData(Query.TempTablesManager);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return Selection.EmailReceivedForDataMapping;
	EndIf;
	
	Return False;
	
EndFunction

Function PredefinedNodesOfSSLExchangePlans()
	
	Result = New Array;
	
	For Each ExchangePlanName In DataExchangeCached.SSLExchangePlans() Do
		Result.Add(ExchangePlans[ExchangePlanName].ThisNode());
	EndDo;
	
	Return Result;
	
EndFunction

Procedure SkipPeriodClosingCheck(Ignore = True) Export
	
	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.SkipPeriodClosingCheck(Ignore);
	EndIf;
	
EndProcedure

Procedure OnContinueSubordinateDIBNodeSetup() Export
	
	SSLSubsystemsIntegration.OnSetUpSubordinateDIBNode();
	DataExchangeOverridable.OnSetUpSubordinateDIBNode();
	
EndProcedure

Procedure CheckProhibitedCharsInWSProxyUserName(Val Username)
	
	DisallowedCharacters = ProhibitedCharsInWSProxyUserName();
	
	If StringContainsCharacter(Username, DisallowedCharacters) Then
		
		MessageString = NStr("ru = 'Š ŠøŠ¼ŠµŠ½Šø ŠæŠ¾Š»ŃŠ·Š¾Š²Š°ŃŠµŠ»Ń %1 ŃŠ¾Š“ŠµŃŠ¶Š°ŃŃŃ Š½ŠµŠ“Š¾ŠæŃŃŃŠøŠ¼ŃŠµ ŃŠøŠ¼Š²Š¾Š»Ń.
			|ŠŠ¼Ń ŠæŠ¾Š»ŃŠ·Š¾Š²Š°ŃŠµŠ»Ń Š½Šµ Š“Š¾Š»Š¶Š½Š¾ ŃŠ¾Š“ŠµŃŠ¶Š°ŃŃ ŃŠøŠ¼Š²Š¾Š»Ń %2.'; 
			|en = 'Username %1 contains invalid characters. 
			|Username cannot contain characters %2.'; 
			|pl = '%1Nazwa uÅ¼ytkownika zawiera nieprawidÅowe znaki.
			|Nazwa uÅ¼ytkownika nie moÅ¼e zawieraÄ %2 symboli.';
			|es_ES = 'El %1 nombre de usuario contiene sĆ­mbolos invĆ”lidos.
			|Nombre de usuario no tiene que contener los sĆ­mbolos %2.';
			|es_CO = 'El %1 nombre de usuario contiene sĆ­mbolos invĆ”lidos.
			|Nombre de usuario no tiene que contener los sĆ­mbolos %2.';
			|tr = 'KullanÄ±cÄ± adÄ± %1 geĆ§ersiz karakterler iĆ§eriyor. 
			|KullanÄ±cÄ± adÄ± %2.sembol iĆ§ermemelidir.';
			|it = 'Il nome utente %1 contiene caratteri non validi. 
			|Il nome utente non puĆ² contenere caratteri %2.';
			|de = 'Der %1 Benutzername enthĆ¤lt ungĆ¼ltige Zeichen. Der
			|Benutzername darf keine %2 Symbole enthalten.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, Username, DisallowedCharacters);
		
		Raise MessageString;
		
	EndIf;
	
EndProcedure

Procedure CheckWSProxyAddressFormatCorrectness(Val WSProxyAddress)
	
	IsInternetAddress           = False;
	WSProxyAllowedPrefixes = WSProxyAllowedPrefixes();
	
	For Each Prefix In WSProxyAllowedPrefixes Do
		If Left(Lower(WSProxyAddress), StrLen(Prefix)) = Lower(Prefix) Then
			IsInternetAddress = True;
			Break;
		EndIf;
	EndDo;
	
	If Not IsInternetAddress Then
		PrefixesString = "";
		For Each Prefix In WSProxyAllowedPrefixes Do
			PrefixesString = PrefixesString + ?(IsBlankString(PrefixesString), """", " or """) + Prefix + """";
		EndDo;
		
		MessageString = NStr("ru = 'ŠŠµŠ²ŠµŃŠ½ŃŠ¹ ŃŠ¾ŃŠ¼Š°Ń Š°Š“ŃŠµŃŠ° ""%1"".
			|ŠŠ“ŃŠµŃ Š“Š¾Š»Š¶ŠµŠ½ Š½Š°ŃŠøŠ½Š°ŃŃŃŃ Ń ŠæŃŠµŃŠøŠŗŃŠ° ŠŠ½ŃŠµŃŠ½ŠµŃ ŠæŃŠ¾ŃŠ¾ŠŗŠ¾Š»Š° %2 (Š½Š°ŠæŃŠøŠ¼ŠµŃ: ""http://myserver.com/service"").'; 
			|en = 'Incorrect address format ""%1"".
			|Address shall start with a prefix of Internet protocol %2 (for example, ""http://myserver.com/service"").'; 
			|pl = 'BÅÄdny format adresu ""%1"".
			|Adres musi zaczynaÄ siÄ od prefiksu protokoÅu Internetu %2 (na przykÅad: ""http://myserver.com/service"").';
			|es_ES = 'Formato incorrecto de direcciĆ³n ""%1"".
			|La direcciĆ³n debe empezarse con el prefijo del protocolo de Internet %2 (por ejemplo: ""http://myserver.com/service"").';
			|es_CO = 'Formato incorrecto de direcciĆ³n ""%1"".
			|La direcciĆ³n debe empezarse con el prefijo del protocolo de Internet %2 (por ejemplo: ""http://myserver.com/service"").';
			|tr = 'YanlÄ±Å Adres biĆ§imi ""%1""
			|. Adres Internet ProtokolĆ¼ Ć¶neki ile baÅlamalÄ±dÄ±r%2 (Ć¶rneÄin, ""http://myserver.com/service"").';
			|it = 'Formato di indirizzo ""%1"" errato.
			|L''indirizzo deve iniziare con un prefisso di protocollo internet %2 (per esempio ""http://myserver.com/service"").';
			|de = 'Falsches Adressformat ""%1"".
			|Die Adresse muss mit dem PrĆ¤fix des Internetprotokolls beginnen %2 (z.B.: ""http://myserver.com/service"").'");
			
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, WSProxyAddress, PrefixesString);
		
		Raise MessageString;
	EndIf;
	
EndProcedure

Function StringContainsCharacter(Val Row, Val CharactersString)
	
	For Index = 1 To StrLen(CharactersString) Do
		Char = Mid(CharactersString, Index, 1);
		
		If StrFind(Row, Char) <> 0 Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function WSProxyAllowedPrefixes()
	
	Result = New Array();
	
	Result.Add("http");
	Result.Add("https");
	
	Return Result;
	
EndFunction

Procedure ExecuteExchangeSettingsUpdate(InfobaseNode)
	
	If DataExchangeCached.IsMessagesExchangeNode(InfobaseNode) Then
		Return;
	EndIf;
	
	DeleteExchangeTransportSettingsSet = InformationRegisters.DeleteExchangeTransportSettings.CreateRecordSet();
	DeleteExchangeTransportSettingsSet.Filter.InfobaseNode.Set(InfobaseNode);
	DeleteExchangeTransportSettingsSet.Read();
	
	ProcessingState = InfobaseUpdate.ObjectProcessed(DeleteExchangeTransportSettingsSet);
	If Not ProcessingState.Processed Then
		InformationRegisters.DeleteExchangeTransportSettings.TransferSettingsOfCorrespondentDataExchangeTransport(InfobaseNode);
	EndIf;
	
	CommonInfobaseNodesSettingsSet = InformationRegisters.CommonInfobasesNodesSettings.CreateRecordSet();
	CommonInfobaseNodesSettingsSet.Filter.InfobaseNode.Set(InfobaseNode);
	CommonInfobaseNodesSettingsSet.Read();
	
	If CommonInfobaseNodesSettingsSet.Count() = 0 Then
		InformationRegisters.CommonInfobasesNodesSettings.UpdateCorrespondentCommonSettings(InfobaseNode);
	Else
		ProcessingState = InfobaseUpdate.ObjectProcessed(CommonInfobaseNodesSettingsSet);
		If Not ProcessingState.Processed Then
			InformationRegisters.CommonInfobasesNodesSettings.UpdateCorrespondentCommonSettings(InfobaseNode);
		EndIf;
	EndIf;
	
	If IsXDTOExchangePlan(InfobaseNode) Then
		XDTODataExchangeSettingsSet = InformationRegisters.XDTODataExchangeSettings.CreateRecordSet();
		XDTODataExchangeSettingsSet.Filter.InfobaseNode.Set(InfobaseNode);
		XDTODataExchangeSettingsSet.Read();
		
		If XDTODataExchangeSettingsSet.Count() = 0 Then
			InformationRegisters.XDTODataExchangeSettings.RefreshDataExchangeSettingsOfCorrespondentXDTO(InfobaseNode);
		EndIf;
	EndIf;
	
EndProcedure

#Region InfobaseUpdate

// Sets the flag that indicates whether mapping data adjustment for all exchange plan nodes must be 
// executed on the next data exchange.
//
Procedure SetMappingDataAdjustmentRequiredForAllInfobaseNodes() Export
	
	InformationRegisters.CommonInfobasesNodesSettings.SetMappingDataAdjustmentRequiredForAllInfobaseNodes();
	
EndProcedure

// Sets the following value for export mode flags of all universal data exchange nodes:
// Export by condition.
//
Procedure SetExportModeForAllInfobaseNodes() Export
	
	For Each ExchangePlanName In DataExchangeCached.SSLExchangePlans() Do
		
		If DataExchangeCached.IsDistributedInfobaseExchangePlan(ExchangePlanName) Then
			Continue;
		EndIf;
		
		For Each Node In ExchangePlanNodes(ExchangePlanName) Do
			
			AttributesNames = Common.AttributeNamesByType(Node, Type("EnumRef.ExchangeObjectExportModes"));
			
			If IsBlankString(AttributesNames) Then
				Continue;
			EndIf;
			
			AttributesNames = StrReplace(AttributesNames, " ", "");
			
			Attributes = StrSplit(AttributesNames, ",");
			
			ObjectIsModified = False;
			
			ObjectNode = Node.GetObject();
			
			For Each AttributeName In Attributes Do
				
				If Not ValueIsFilled(ObjectNode[AttributeName]) Then
					
					ObjectNode[AttributeName] = Enums.ExchangeObjectExportModes.ExportByCondition;
					
					ObjectIsModified = True;
					
				EndIf;
				
			EndDo;
			
			If ObjectIsModified Then
				
				ObjectNode.AdditionalProperties.Insert("GettingExchangeMessage");
				ObjectNode.Write();
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Refreshes scheduled job data for all data exchange scenarios except for those marked for deletion.
//
Procedure UpdateDataExchangeScenarioScheduledJobs() Export
	
	QueryText = "
	|SELECT
	|	DataExchangeScenarios.Ref
	|FROM
	|	Catalog.DataExchangeScenarios AS DataExchangeScenarios
	|WHERE
	|	NOT DataExchangeScenarios.DeletionMark
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		Cancel = False;
		
		Object = Selection.Ref.GetObject();
		
		Catalogs.DataExchangeScenarios.UpdateScheduledJobData(Cancel, Undefined, Object);
		
		If Cancel Then
			Raise NStr("ru = 'ŠŃŠøŠ±ŠŗŠ° ŠæŃŠø Š¾Š±Š½Š¾Š²Š»ŠµŠ½ŠøŠø ŃŠµŠ³Š»Š°Š¼ŠµŠ½ŃŠ½Š¾Š³Š¾ Š·Š°Š“Š°Š½ŠøŃ Š“Š»Ń ŃŃŠµŠ½Š°ŃŠøŃ Š¾Š±Š¼ŠµŠ½Š° Š“Š°Š½Š½ŃŠ¼Šø.'; en = 'Error updating the scheduled job for the data exchange scenario.'; pl = 'BÅÄd podczas aktualizacji zadania reglamentowanego dla scenariusza wymiany danych.';es_ES = 'Error al actualizar la tarea programada para el script de intercambio de datos.';es_CO = 'Error al actualizar la tarea programada para el script de intercambio de datos.';tr = 'Veri alÄ±ÅveriÅi komut dosyasÄ± iĆ§in rutin gĆ¶rev gĆ¼ncelleÅtirilirken hata oluÅtu.';it = 'Errore di aggiornamento del compito pianificato per lo scenario di scambio dati.';de = 'Fehler bei der Aktualisierung der Routineaufgabe fĆ¼r ein Datenaustauschszenario.'");
		EndIf;
		
		InfobaseUpdate.WriteData(Object);
		
	EndDo;
	
EndProcedure

// Sets the SubordinateDIBNodeSetupCompleted constant to True for the subordinate DIB node, because 
// exchange in DIB is already set.
//
Procedure UpdateSubordinateDIBNodeSetupCompletedConstant() Export
	
	If  IsSubordinateDIBNode()
		AND InformationRegisters.DataExchangeTransportSettings.NodeTransportSettingsAreSet(MasterNode()) Then
		
		Constants.SubordinateDIBNodeSetupCompleted.Set(True);
		
		RefreshReusableValues();
		
	EndIf;
	
EndProcedure

// Redefines the UseDataSynchronization constant value if necessary.
//
Procedure CheckFunctionalOptionsAreSetOnUpdateIB() Export
	
	If Constants.UseDataSynchronization.Get() Then
		
		Constants.UseDataSynchronization.Set(True);
		
	EndIf;
	
EndProcedure

// Redefines the UseDataSynchronization constant value if necessary.
// Because the constant has become shared and its value reset.
//
Procedure CheckFunctionalOptionsAreSetOnUpdateIB_2_1_2_21() Export
	
	If NOT GetFunctionalOption("UseDataSynchronization") Then
		
		If Common.DataSeparationEnabled() Then
			
			Constants.UseDataSynchronization.Set(True);
			
		Else
			
			If GetExchangePlansInUse().Count() > 0 Then
				
				Constants.UseDataSynchronization.Set(True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Sets the number of items per an export transaction equal to one.
//
Procedure SetItemCountForDataImportTransaction_2_2_2_4() Export
	
	SetDataImportTransactionItemsCount(1);
	
EndProcedure

// Sets the WSRememberPassword attribute value to True in InformationRegister.DeleteExchangeTransportSettings.
//
Procedure SetExchangePasswordSaveOverInternetFlag() Export
	
	QueryText =
	"SELECT
	|	TransportSettings.InfobaseNode AS InfobaseNode
	|FROM
	|	InformationRegister.DeleteExchangeTransportSettings AS TransportSettings
	|WHERE
	|	TransportSettings.DefaultExchangeMessagesTransportKind = VALUE(Enum.ExchangeMessagesTransportTypes.WS)";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", Selection.InfobaseNode);
		RecordStructure.Insert("WSRememberPassword", True);
		
		UpdateInformationRegisterRecord(RecordStructure, "DeleteExchangeTransportSettings");
		
	EndDo;
	
EndProcedure

// Clears saved settings of the DataSynchronization common form.
//
Procedure ClearExchangeMonitorSettings() Export
	
	FormSettingsArray = New Array;
	FormSettingsArray.Add("/FormSettings");
	FormSettingsArray.Add("/WindowSettings");
	FormSettingsArray.Add("/WebClientWindowSettings");
	FormSettingsArray.Add("/CurrentData");
	
	For Each FormItem In FormSettingsArray Do
		SystemSettingsStorage.Delete("CommonForm.DataSynchronization" + FormItem, Undefined, Undefined);
	EndDo;
	
EndProcedure

// Deletes the DataSynchronizationSetup role from all profiles that include it.
Procedure DeleteDataSynchronizationSetupRole() Export
	
	If Not Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Return;
	EndIf;
	
	ModuleAccessManagement = Common.CommonModule("AccessManagement");
	
	NewRoles = New Array;
	RolesToReplace = New Map;
	RolesToReplace.Insert("? DataSynchronizationSetup", NewRoles);
	
	ModuleAccessManagement.ReplaceRolesInProfiles(RolesToReplace);
	
EndProcedure

#EndRegion

#Region DataExchangeExecution

// Executes data exchange process separately for each exchange setting line.
// Data exchange process consists of two stages:
// - Exchange initialization - preparation of data exchange subsystem to perform data exchange.
// - Data exchange - a process of reading a message file and then importing this data to infobase or 
//                          exporting changes to the message file.
// The initialization stage is performed once per session and is saved to the session cache at 
// server until the session is restarted or cached values of data exchange subsystem are reset.
// Cached values are reset when data that affects data exchange process is changed (transport 
// settings, exchange settings, filter settings on exchange plan nodes).
//
// The exchange can be executed completely for all scenario lines or can be executed for a single 
// row of the exchange scenario TS.
//
// Parameters:
//  Cancel                     - Boolean - a cancelation flag. It appears when scenario execution errors occur.
//  ExchangeExecutionSettings - CatalogRef.DataExchangeScenarios - a catalog item whose attribute 
//                              values are used to perform data exchange.
//  LineNumber - Number - a number of the line to use for performing data exchange.
//                              If it is not specified, all lines are involved in data exchange.
// 
Procedure ExecuteDataExchangeUsingDataExchangeScenario(Cancel, ExchangeExecutionSettings, RowNumber = Undefined) Export
	
	CheckCanSynchronizeData();
	
	CheckDataExchangeUsage();
	
	SetPrivilegedMode(True);
	
	QueryText = "
	|SELECT
	|	ExchangeExecutionSettingsExchangeSettings.Ref                         AS ExchangeExecutionSettings,
	|	ExchangeExecutionSettingsExchangeSettings.LineNumber                    AS LineNumber,
	|	ExchangeExecutionSettingsExchangeSettings.CurrentAction            AS CurrentAction,
	|	ExchangeExecutionSettingsExchangeSettings.ExchangeTransportKind            AS ExchangeTransportKind,
	|	ExchangeExecutionSettingsExchangeSettings.InfobaseNode         AS InfobaseNode,
	|
	|	CASE WHEN ExchangeExecutionSettingsExchangeSettings.ExchangeTransportKind = VALUE(Enum.ExchangeMessagesTransportTypes.COM)
	|	THEN TRUE
	|	ELSE FALSE
	|	END AS ExchangeOverExternalConnection,
	|
	|	CASE WHEN ExchangeExecutionSettingsExchangeSettings.ExchangeTransportKind = VALUE(Enum.ExchangeMessagesTransportTypes.WS)
	|	THEN TRUE
	|	ELSE FALSE
	|	END AS ExchangeOverWebService
	|FROM
	|	Catalog.DataExchangeScenarios.ExchangeSettings AS ExchangeExecutionSettingsExchangeSettings
	|WHERE
	|	ExchangeExecutionSettingsExchangeSettings.Ref = &ExchangeExecutionSettings
	|	[LineNumberCondition]
	|ORDER BY
	|	ExchangeExecutionSettingsExchangeSettings.LineNumber
	|";
	
	LineNumberCondition = ?(RowNumber = Undefined, "", "AND ExchangeExecutionSettingsExchangeSettings.LineNumber = &LineNumber");
	
	QueryText = StrReplace(QueryText, "[LineNumberCondition]", LineNumberCondition);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ExchangeExecutionSettings", ExchangeExecutionSettings);
	Query.SetParameter("LineNumber", RowNumber);
	
	Selection = Query.Execute().Select();
	
	IsSubordinateDIBNodeRequiringUpdates = 
		IsSubordinateDIBNode()
		AND DataExchangeServerCall.UpdateInstallationRequired();
	
	While Selection.Next() Do
		CancelByScenarioString = False;
		If IsSubordinateDIBNodeRequiringUpdates
			AND DataExchangeCached.IsDistributedInfobaseNode(Selection.InfobaseNode) Then
			// Scheduled exchange is not performed.
			Continue;
		EndIf;
		
		If Selection.ExchangeOverExternalConnection Then
			
			CheckExternalConnectionAvailable();
			
			TransactionItemsCount = ItemsCountInTransactionOfActionBeingExecuted(Selection.CurrentAction);
			
			ExecuteExchangeActionForInfobaseNodeUsingExternalConnection(CancelByScenarioString,
				Selection.InfobaseNode, Selection.CurrentAction, TransactionItemsCount);
			
		ElsIf Selection.ExchangeOverWebService Then
			
			ExchangeParameters = ExchangeParameters();
			ExecuteExchangeActionForInfobaseNodeUsingWebService(CancelByScenarioString,
				Selection.InfobaseNode, Selection.CurrentAction, ExchangeParameters);
			
		Else
			
			// INITIALIZING DATA EXCHANGE
			ExchangeSettingsStructure = DataExchangeCached.DataExchangeSettings(Selection.ExchangeExecutionSettings, Selection.LineNumber);
			
			// If settings contain errors, canceling the exchange.
			If ExchangeSettingsStructure.Cancel Then
				
				CancelByScenarioString = True;
				
				// Registering data exchange log in the event log.
				AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
				Continue;
			EndIf;
			
			ExchangeSettingsStructure.ExchangeExecutionResult = Undefined;
			ExchangeSettingsStructure.StartDate = CurrentSessionDate();
			
			// Adding data exchange message to the event log.
			MessageString = NStr("ru = 'ŠŠ°ŃŠ°Š»Š¾ ŠæŃŠ¾ŃŠµŃŃŠ° Š¾Š±Š¼ŠµŠ½Š° Š“Š°Š½Š½ŃŠ¼Šø ŠæŠ¾ Š½Š°ŃŃŃŠ¾Š¹ŠŗŠµ %1'; en = 'Data exchange process started by %1 setting'; pl = 'PoczÄtek procesu wymiany danych po ustawieniu %1';es_ES = 'Inicio del proceso del intercambio de datos para la configuraciĆ³n %1';es_CO = 'Inicio del proceso del intercambio de datos para la configuraciĆ³n %1';tr = 'Ayar iĆ§in veri deÄiÅim sĆ¼reci baÅlatÄ±lÄ±yor%1';it = 'Processo di scambio dati avviato dall''impostazione %1';de = 'Der Datenaustausch beginnt mit der Einstellung %1'", CommonClientServer.DefaultLanguageCode());
			MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, ExchangeSettingsStructure.ExchangeExecutionSettingDescription);
			WriteEventLogDataExchange(MessageString, ExchangeSettingsStructure);
			
			// DATA EXCHANGE
			ExecuteDataExchangeOverFileResource(ExchangeSettingsStructure);
			
			// Registering data exchange log in the event log.
			AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
			
			If Not ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
				
				CancelByScenarioString = True;
				
			EndIf;
			
		EndIf;
		If CancelByScenarioString Then
			Cancel = True;
		EndIf;
	EndDo;
	
EndProcedure

// An entry point for data exchange using scheduled job exchange scenario.
//
// Parameters:
//  ExchangeScenarioCode - String - a code of the Data exchange scenarios catalog item for which 
//                               data exchange is to be executed.
// 
Procedure ExecuteDataExchangeWithScheduledJob(ExchangeScenarioCode) Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.DataSynchronization);
	
	CheckCanSynchronizeData();
	
	CheckDataExchangeUsage();
	
	If Not ValueIsFilled(ExchangeScenarioCode) Then
		Raise NStr("ru = 'ŠŠµ Š·Š°Š“Š°Š½ ŃŃŠµŠ½Š°ŃŠøŠ¹ Š¾Š±Š¼ŠµŠ½Š° Š“Š°Š½Š½ŃŠ¼Šø.'; en = 'Data exchange scenario is not specified.'; pl = 'Nie okreÅlono scenariusza wymiany danych.';es_ES = 'Escenarios del intercambio de datos no estĆ” especificado.';es_CO = 'Escenarios del intercambio de datos no estĆ” especificado.';tr = 'Veri deÄiÅimi senaryosu belirtilmemiÅ.';it = 'Non specificato lo scenario di scambio dati.';de = 'Datenaustauschszenario ist nicht angegeben.'");
	EndIf;
	
	QueryText = "
	|SELECT
	|	DataExchangeScenarios.Ref AS Ref
	|FROM
	|	Catalog.DataExchangeScenarios AS DataExchangeScenarios
	|WHERE
	|		 DataExchangeScenarios.Code = &Code
	|	AND NOT DataExchangeScenarios.DeletionMark
	|";
	
	Query = New Query;
	Query.SetParameter("Code", ExchangeScenarioCode);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		// Performing exchange using scenario.
		ExecuteDataExchangeUsingDataExchangeScenario(False, Selection.Ref);
	Else
		MessageString = NStr("ru = 'Š”ŃŠµŠ½Š°ŃŠøŠ¹ Š¾Š±Š¼ŠµŠ½Š° Š“Š°Š½Š½ŃŠ¼Šø Ń ŠŗŠ¾Š“Š¾Š¼ %1 Š½Šµ Š½Š°Š¹Š“ŠµŠ½.'; en = 'The data exchange script with the %1 code is not found.'; pl = 'Nie znaleziono skryptu wymiany danych z kodem %1.';es_ES = 'Script del intercambio de datos con el cĆ³digo %1 no encontrado.';es_CO = 'Script del intercambio de datos con el cĆ³digo %1 no encontrado.';tr = '%1Kodu ile veri deÄiÅim betiÄi bulunamadÄ±.';it = 'Script di scambio dati con codice %1 non trovato.';de = 'Datenaustauschskript mit Code %1 wurde nicht gefunden.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, ExchangeScenarioCode);
		Raise MessageString;
	EndIf;
	
EndProcedure

// Gets an exchange message to OS user's temporary directory.
//
// Parameters:
//  Cancel - Boolean - indicates whether an error occurred on data exchange.
//  InfobaseNode - ExchangePlanRef - an exchange plan node for which the exchange message is being 
//                                                    received.
//  ExchangeMessagesTransportKind - EnumRef.ExchangeMessagesTransportKinds - a transport kind for 
//                                                                                    receiving exchange messages.
//  OutputMessages - Boolean - if True, user messages are displayed.
//
//  Returns:
//   Structure with the following keys:
//     * TempExchangeMessageCatalogName - a full name of the exchange directory that stores the exchange message.
//     * ExchangeMessageFileName - a full name of the exchange message file.
//     * DataPackageFileID - date of changing the exchange message file.
//
Function GetExchangeMessageToTemporaryDirectory(Cancel, InfobaseNode, ExchangeMessagesTransportKind, OutputMessages = True) Export
	
	// Function return value.
	Result = New Structure;
	Result.Insert("TempExchangeMessageCatalogName", "");
	Result.Insert("ExchangeMessageFileName",              "");
	Result.Insert("DataPackageFileID",       Undefined);
	
	ExchangeSettingsStructure = DataExchangeCached.TransportSettingsOfExchangePlanNode(InfobaseNode, ExchangeMessagesTransportKind);
	
	ExchangeSettingsStructure.ExchangeExecutionResult = Undefined;
	ExchangeSettingsStructure.StartDate = CurrentSessionDate();
	
	// If the setting contains errors, canceling exchange message receiving and setting the exchange status to Canceled.
	If ExchangeSettingsStructure.Cancel Then
		
		If OutputMessages Then
			NString = NStr("ru = 'ŠŃŠø ŠøŠ½ŠøŃŠøŠ°Š»ŠøŠ·Š°ŃŠøŠø Š¾Š±ŃŠ°Š±Š¾ŃŠŗŠø ŃŃŠ°Š½ŃŠæŠ¾ŃŃŠ° ŃŠ¾Š¾Š±ŃŠµŠ½ŠøŠ¹ Š¾Š±Š¼ŠµŠ½Š° Š²Š¾Š·Š½ŠøŠŗŠ»Šø Š¾ŃŠøŠ±ŠŗŠø.'; en = 'Error initializing exchange message transport processing.'; pl = 'W trakcie inicjalizacji przetwarzania transportu komunikatĆ³w wymiany zaistniaÅy bÅÄdy.';es_ES = 'Errores ocurridos durante la iniciaciĆ³n del proceso del transporte de mensajes de intercambio.';es_CO = 'Errores ocurridos durante la iniciaciĆ³n del proceso del transporte de mensajes de intercambio.';tr = 'DeÄiÅim mesajÄ± aktarÄ±mÄ±nÄ±n iÅlenmesi baÅlatÄ±lÄ±rken hatalar oluÅtu.';it = 'Errore di inizializzazione dell''elaborazione di trasporto del messaggio di scambio.';de = 'Beim Initialisieren der Verarbeitung des Nachrichtenaustauschs sind Fehler aufgetreten.'");
			CommonClientServer.MessageToUser(NString,,,, Cancel);
		EndIf;
		
		AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
		Return Result;
	EndIf;
	
	// Creating a temporary directory.
	ExecuteExchangeMessageTransportBeforeProcessing(ExchangeSettingsStructure);
	
	If ExchangeSettingsStructure.ExchangeExecutionResult = Undefined Then
		
		// Receiving the message and putting it in the temporary directory.
		ExecuteExchangeMessageTransportReceiving(ExchangeSettingsStructure);
		
	EndIf;

	If ExchangeSettingsStructure.ExchangeExecutionResult <> Undefined Then
		
		If OutputMessages Then
			NString = NStr("ru = 'ŠŃŠø ŠæŠ¾Š»ŃŃŠµŠ½ŠøŠø ŃŠ¾Š¾Š±ŃŠµŠ½ŠøŠ¹ Š¾Š±Š¼ŠµŠ½Š° Š²Š¾Š·Š½ŠøŠŗŠ»Šø Š¾ŃŠøŠ±ŠŗŠø.'; en = 'Error receiving exchange messages.'; pl = 'Podczas otrzymywaniu komunikatĆ³w wymiany zaistniaÅy bÅÄdy.';es_ES = 'Errores ocurridos al recibir los mensajes de intercambio.';es_CO = 'Errores ocurridos al recibir los mensajes de intercambio.';tr = 'DeÄiÅim mesajlarÄ± alÄ±nÄ±rken hatalar oluÅtu.';it = 'Errore di ricezione dei messaggi di scambio.';de = 'Beim Empfangen von Austauschnachrichten sind Fehler aufgetreten.'");
			CommonClientServer.MessageToUser(NString,,,, Cancel);
		EndIf;
		
		// Deleting temporary directory with all its content.
		ExecuteExchangeMessageTransportAfterProcessing(ExchangeSettingsStructure);
		
		AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
		Return Result;
	EndIf;
	
	Result.TempExchangeMessageCatalogName = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.ExchangeMessageCatalogName();
	Result.ExchangeMessageFileName              = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.ExchangeMessageFileName();
	Result.DataPackageFileID       = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.ExchangeMessageFileDate();
	
	Return Result;
EndFunction

// Gets an exchange message from the correspondent infobase to OS user's temporary directory.
//
// Parameters:
//  Cancel - Boolean - indicates whether an error occurred on data exchange.
//  InfobaseNode - ExchangePlanRef - an exchange plan node for which the exchange message is being 
//                                                    received.
//  OutputMessages - Boolean - if True, user messages are displayed.
//
//  Returns:
//   Structure with the following keys:
//     * TempExchangeMessageCatalogName - a full name of the exchange directory that stores the exchange message.
//     * ExchangeMessageFileName - a full name of the exchange message file.
//     * DataPackageFileID - date of changing the exchange message file.
//
Function GetExchangeMessageFromCorrespondentInfobaseToTempDirectory(Cancel, InfobaseNode, OutputMessages = True) Export
	
	// Function return value.
	Result = New Structure;
	Result.Insert("TempExchangeMessageCatalogName", "");
	Result.Insert("ExchangeMessageFileName",              "");
	Result.Insert("DataPackageFileID",       Undefined);
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
	CurrentExchangePlanNode = DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName);
	CurrentExchangePlanNodeCode = NodeIDForExchange(InfobaseNode);

	MessageFileNamePattern = MessageFileNamePattern(CurrentExchangePlanNode, InfobaseNode, False);
	
	// Parameters to be defined in the function.
	ExchangeMessageFileDate = Date('00010101');
	ExchangeMessageCatalogName = "";
	ErrorMessageString = "";
	
	Try
		ExchangeMessageCatalogName = CreateTempExchangeMessageDirectory();
	Except
		If OutputMessages Then
			Message = NStr("ru = 'ŠŠµ ŃŠ“Š°Š»Š¾ŃŃ ŠæŃŠ¾ŠøŠ·Š²ŠµŃŃŠø Š¾Š±Š¼ŠµŠ½: %1'; en = 'Errors occurred during the data exchange: %1'; pl = 'Nie moÅ¼na wymieniÄ: %1';es_ES = 'No se puede intercambiar: %1';es_CO = 'No se puede intercambiar: %1';tr = 'DeÄiÅim yapÄ±lamadÄ±: %1';it = 'Si sono verificati degli errori durante lo scambio dati: %1';de = 'Kann nicht austauschen: %1'");
			Message = StringFunctionsClientServer.SubstituteParametersToString(Message, DetailErrorDescription(ErrorInfo()));
			CommonClientServer.MessageToUser(Message,,,, Cancel);
		EndIf;
		Return Result;
	EndTry;
	
	// Getting external connection for the infobase node.
	ConnectionData = DataExchangeCached.ExternalConnectionForInfobaseNode(InfobaseNode);
	ExternalConnection = ConnectionData.Connection;
	
	If ExternalConnection = Undefined Then
		
		Message = NStr("ru = 'ŠŠµ ŃŠ“Š°Š»Š¾ŃŃ ŠæŃŠ¾ŠøŠ·Š²ŠµŃŃŠø Š¾Š±Š¼ŠµŠ½: %1'; en = 'Errors occurred during the data exchange: %1'; pl = 'Nie moÅ¼na wymieniÄ: %1';es_ES = 'No se puede intercambiar: %1';es_CO = 'No se puede intercambiar: %1';tr = 'DeÄiÅim yapÄ±lamadÄ±: %1';it = 'Si sono verificati degli errori durante lo scambio dati: %1';de = 'Kann nicht austauschen: %1'");
		If OutputMessages Then
			UserMessage = StringFunctionsClientServer.SubstituteParametersToString(Message, ConnectionData.BriefErrorDescription);
			CommonClientServer.MessageToUser(UserMessage,,,, Cancel);
		EndIf;
		
		// Adding two records to the event log: one for data import and one for data export.
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = EventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
		
		Message = StringFunctionsClientServer.SubstituteParametersToString(Message, ConnectionData.DetailedErrorDescription);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndIf;
	
	ExchangeMessageFileName = CommonClientServer.GetFullFileName(ExchangeMessageCatalogName, MessageFileNamePattern + ".xml");
	
	NodeAlias = PredefinedNodeAlias(InfobaseNode);
	If ValueIsFilled(NodeAlias) Then
		// You need to check the node code in the correspondent because it can be already re-encoded.
		// In this case, alias is not required.
		ExchangePlanManager = ExternalConnection.ExchangePlans[ExchangePlanName];
		If ExchangePlanManager.FindByCode(NodeAlias) <> ExchangePlanManager.EmptyRef() Then
			CurrentExchangePlanNodeCode = NodeAlias;
			CheckNodeExistenceInCorrespondent = False;
		EndIf;
	EndIf;
	
	ExternalConnection.DataExchangeExternalConnection.ExportForInfobaseNode(Cancel, ExchangePlanName, CurrentExchangePlanNodeCode, ExchangeMessageFileName, ErrorMessageString);
	
	If Cancel Then
		
		If OutputMessages Then
			// Displaying error message.
			Message = NStr("ru = 'ŠŠµ ŃŠ“Š°Š»Š¾ŃŃ Š²ŃŠ³ŃŃŠ·ŠøŃŃ Š“Š°Š½Š½ŃŠµ: %1'; en = 'Errors occurred during the data export: %1'; pl = 'Nie moÅ¼na eksportowaÄ danych: %1';es_ES = 'No se puede exportar los datos: %1';es_CO = 'No se puede exportar los datos: %1';tr = 'Veri dÄ±Åa aktarÄ±lamadÄ±: %1';it = 'Si sono verificati degli errori durante l''esportazione dei dati: %1';de = 'Daten kĆ¶nnen nicht exportiert werden: %1'");
			Message = StringFunctionsClientServer.SubstituteParametersToString(Message, ConnectionData.BriefErrorDescription);
			CommonClientServer.MessageToUser(Message,,,, Cancel);
		EndIf;
		
		Return Result;
	EndIf;
	
	FileExchangeMessages = New File(ExchangeMessageFileName);
	If FileExchangeMessages.Exist() Then
		ExchangeMessageFileDate = FileExchangeMessages.GetModificationTime();
	EndIf;
	
	Result.TempExchangeMessageCatalogName = ExchangeMessageCatalogName;
	Result.ExchangeMessageFileName              = ExchangeMessageFileName;
	Result.DataPackageFileID       = ExchangeMessageFileDate;
	
	Return Result;
EndFunction

// Gets an exchange message from the correspondent infobase via web service to the temporary directory of the
// OS user.
//
// Parameters:
//  Cancel                   - Boolean - indicates whether an error occurred on data exchange.
//  InfobaseNode - ExchangePlanRef - an exchange plan node for which exchange message is being received.
//  FileID      - UUID - a file ID.
//  TimeConsumingOperation      - Boolean - indicates that time-consuming operation is used.
//  OperationID   - UUID - an UUID of the time-consuming operation.
//  AuthenticationParameters - Structure. Contains web service authentication parameters (User, Password).
//
//  Returns:
//   Structure with the following keys:
//     * TempExchangeMessageCatalogName - a full name of the exchange directory that stores the exchange message.
//     * ExchangeMessageFileName - a full name of the exchange message file.
//     * DataPackageFileID - date of changing the exchange message file.
//
Function GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebService(
											Cancel,
											InfobaseNode,
											FileID,
											TimeConsumingOperation,
											OperationID,
											AuthenticationParameters = Undefined) Export
	
	CheckCanSynchronizeData();
	
	CheckDataExchangeUsage();
	
	SetPrivilegedMode(True);
	
	// Function return value.
	Result = New Structure;
	Result.Insert("TempExchangeMessageCatalogName", "");
	Result.Insert("ExchangeMessageFileName",              "");
	Result.Insert("DataPackageFileID",       Undefined);
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
	CurrentExchangePlanNode = DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName);
	CurrentExchangePlanNodeCode = NodeIDForExchange(InfobaseNode);
	
	// Parameters to be defined in the function.
	ExchangeMessageCatalogName = "";
	ExchangeMessageFileName = "";
	ExchangeMessageFileDate = Date('00010101');
	ErrorMessageString = "";
	
	// Getting web service proxy for the infobase node.
	Proxy = WSProxyForInfobaseNode(InfobaseNode, ErrorMessageString, AuthenticationParameters);
	
	If Proxy = Undefined Then
		
		Cancel = True;
		Message = NStr("ru = 'ŠŃŠøŠ±ŠŗŠ° ŠæŃŠø ŃŃŃŠ°Š½Š¾Š²ŠŗŠµ ŠæŠ¾Š“ŠŗŠ»ŃŃŠµŠ½ŠøŃ ŠŗŠ¾ Š²ŃŠ¾ŃŠ¾Š¹ ŠøŠ½ŃŠ¾ŃŠ¼Š°ŃŠøŠ¾Š½Š½Š¾Š¹ Š±Š°Š·Šµ: %1'; en = 'Error establishing connection with the correspondent infobase: %1'; pl = 'WystÄpiÅ bÅÄd podczas nawiÄzywania poÅÄczenia z drugÄ bazÄ informacyjnÄ: %1';es_ES = 'Ha ocurrido un error al establecer la conexiĆ³n con la segunda infobase: %1';es_CO = 'Ha ocurrido un error al establecer la conexiĆ³n con la segunda infobase: %1';tr = 'Ä°kinci veritabanÄ±na baÄlantÄ± kurulurken bir hata oluÅtu:%1';it = 'Si ĆØ verificato un errore alla connessione con l''infobase corrispondente: %1';de = 'Beim Herstellen der Verbindung zur zweiten Infobase ist ein Fehler aufgetreten: %1'");
		Message = StringFunctionsClientServer.SubstituteParametersToString(Message, ErrorMessageString);
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = EventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndIf;
	
	NodeAlias = PredefinedNodeAlias(InfobaseNode);
	If ValueIsFilled(NodeAlias) Then
		// You need to check the node code in the correspondent because it can be already re-encoded.
		// In this case, alias is not required.
		If ValueIsFilled(NodeAlias) Then
			// Check whether correspondent has such node (probably it is re-encoded).
			NodeAliasExists = True;
			ErrorMessage = "";
			ProxyDestinationParameters = Proxy.GetIBParameters(ExchangePlanName, NodeAlias, ErrorMessage);
			Try
				DestinationParameters = XDTOSerializer.ReadXDTO(ProxyDestinationParameters);
			Except
				DestinationParameters = ValueFromStringInternal(ProxyDestinationParameters);
			EndTry;
			If DestinationParameters.Property("NodeExists") Then
				NodeAliasExists = (DestinationParameters.NodeExists = True);
			EndIf;
			If NodeAliasExists Then
				CurrentExchangePlanNodeCode = NodeAlias;
			EndIf;
		EndIf;
	EndIf;
	
	Try
		
		Proxy.UploadData(
			ExchangePlanName,
			CurrentExchangePlanNodeCode,
			FileID,
			TimeConsumingOperation,
			OperationID,
			True);
		
	Except
		
		Cancel = True;
		Message = NStr("ru = 'ŠŃŠø Š²ŃŠ³ŃŃŠ·ŠŗŠµ Š“Š°Š½Š½ŃŃ Š²Š¾Š·Š½ŠøŠŗŠ»Šø Š¾ŃŠøŠ±ŠŗŠø Š²Š¾ Š²ŃŠ¾ŃŠ¾Š¹ ŠøŠ½ŃŠ¾ŃŠ¼Š°ŃŠøŠ¾Š½Š½Š¾Š¹ Š±Š°Š·Šµ: %1'; en = 'Error exporting data in the correspondent infobase: %1'; pl = 'Podczas eksportowania danych wystÄpiÅy bÅÄdy w drugiej bazie informacyjnej: %1';es_ES = 'Al exportar los datos, han ocurrido errores en la segunda infobase: %1';es_CO = 'Al exportar los datos, han ocurrido errores en la segunda infobase: %1';tr = 'Verileri dÄ±Åa aktarÄ±rken, ikinci veritabanÄ±nda hatalar oluÅtu:%1';it = 'Si ĆØ verificato un errore durante l''esportazione dei dati all''infobase corrispondente: %1';de = 'Beim Exportieren von Daten sind Fehler in der zweiten Infobase aufgetreten: %1'", CommonClientServer.DefaultLanguageCode());
		Message = StringFunctionsClientServer.SubstituteParametersToString(Message, DetailErrorDescription(ErrorInfo()));
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = EventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndTry;
	
	If TimeConsumingOperation Then
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = EventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(NStr("ru = 'ŠŠ¶ŠøŠ“Š°Š½ŠøŠµ ŠæŠ¾Š»ŃŃŠµŠ½ŠøŃ Š“Š°Š½Š½ŃŃ Š¾Ń Š±Š°Š·Ń-ŠŗŠ¾ŃŃŠµŃŠæŠ¾Š½Š“ŠµŠ½ŃŠ°...'; en = 'Waiting for data from the correspondent infobase...'; pl = 'Oczekiwanie odbioru danych z bazy korespondenta...';es_ES = 'Datos pendientes de la base corresponsal...';es_CO = 'Datos pendientes de la base corresponsal...';tr = 'Muhabir tabandan veri bekleniyor ...';it = 'In attesa di dati dall''infobase corrispondente...';de = 'Ausstehende Daten von der Korrespondenzbasis...'",
			CommonClientServer.DefaultLanguageCode()), ExchangeSettingsStructure);
		Return Result;
	EndIf;
	
	Try
		FileTransferServiceFileName = GetFileFromStorageInService(New UUID(FileID), InfobaseNode,, AuthenticationParameters);
	Except
		
		Cancel = True;
		Message = NStr("ru = 'ŠŠ¾Š·Š½ŠøŠŗŠ»Šø Š¾ŃŠøŠ±ŠŗŠø ŠæŃŠø ŠæŠ¾Š»ŃŃŠµŠ½ŠøŠø ŃŠ¾Š¾Š±ŃŠµŠ½ŠøŃ Š¾Š±Š¼ŠµŠ½Š° ŠøŠ· ŃŠµŃŠ²ŠøŃŠ° ŠæŠµŃŠµŠ“Š°ŃŠø ŃŠ°Š¹Š»Š¾Š²: %1'; en = 'Error receiving exchange message from the file transfer service: %1'; pl = 'WystÄpiÅy bÅÄdy podczas odbierania wiadomoÅci wymiany z usÅugi przesyÅania plikĆ³w: %1';es_ES = 'Han ocurrido errores al recibir un mensaje de intercambio del servicio de transferencia de archivos: %1';es_CO = 'Han ocurrido errores al recibir un mensaje de intercambio del servicio de transferencia de archivos: %1';tr = 'Dosya aktarÄ±m hizmetinden bir deÄiÅim mesajÄ± alÄ±nÄ±rken hatalar oluÅtu:%1';it = 'Errore di ricezione del messaggio di scambio dal servizio di trasferimento del file: %1';de = 'Beim Empfang einer Austauschnachricht vom DateiĆ¼bertragungsservice sind Fehler aufgetreten: %1'", CommonClientServer.DefaultLanguageCode());
		Message = StringFunctionsClientServer.SubstituteParametersToString(Message, DetailErrorDescription(ErrorInfo()));
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = EventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndTry;
	
	Try
		ExchangeMessageCatalogName = CreateTempExchangeMessageDirectory();
	Except
		Cancel = True;
		Message = NStr("ru = 'ŠŃŠø ŠæŠ¾Š»ŃŃŠµŠ½ŠøŠø ŃŠ¾Š¾Š±ŃŠµŠ½ŠøŃ Š¾Š±Š¼ŠµŠ½Š° Š²Š¾Š·Š½ŠøŠŗŠ»Šø Š¾ŃŠøŠ±ŠŗŠø: %1'; en = 'Error receiving exchange message: %1'; pl = 'Podczas odbioru wiadomoÅci wymiany wystÄpiÅy bÅÄdy: %1';es_ES = 'Han ocurrido errores al recibir los mensajes de intercambio: %1';es_CO = 'Han ocurrido errores al recibir los mensajes de intercambio: %1';tr = 'DeÄiÅim mesajlarÄ± alÄ±nÄ±rken hatalar oluÅtu: %1';it = 'Errore di ricezione dei messaggi di scambio: %1';de = 'Beim Empfangen von Austauschnachrichten sind Fehler aufgetreten: %1'", CommonClientServer.DefaultLanguageCode());
		Message = StringFunctionsClientServer.SubstituteParametersToString(Message, DetailErrorDescription(ErrorInfo()));
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = EventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndTry;
	
	MessageFileNamePattern = MessageFileNamePattern(CurrentExchangePlanNode, InfobaseNode, False);
	
	ExchangeMessageFileName = CommonClientServer.GetFullFileName(ExchangeMessageCatalogName, MessageFileNamePattern + ".xml");
	
	MoveFile(FileTransferServiceFileName, ExchangeMessageFileName);
	
	FileExchangeMessages = New File(ExchangeMessageFileName);
	If FileExchangeMessages.Exist() Then
		ExchangeMessageFileDate = FileExchangeMessages.GetModificationTime();
	EndIf;
	
	Result.TempExchangeMessageCatalogName = ExchangeMessageCatalogName;
	Result.ExchangeMessageFileName              = ExchangeMessageFileName;
	Result.DataPackageFileID       = ExchangeMessageFileDate;
	
	Return Result;
EndFunction

// The function receives an exchange message from the correspondent infobase using web service
// and saves it to the temporary directory.
// It is used if the exchange message receipt is a part of a background job in the correspondent 
// infobase.
//
// Parameters:
//  Cancel                   - Boolean - indicates whether an error occurred on data exchange.
//  InfobaseNode - ExchangePlanRef - an exchange plan node for which exchange message is being received.
//  FileID      - UUID - a file ID.
//  AuthenticationParameters - Structure. Contains web service authentication parameters (User, Password).
//
//  Returns:
//   Structure with the following keys:
//     * TempExchangeMessageCatalogName - a full name of the exchange directory that stores the exchange message.
//     * ExchangeMessageFileName - a full name of the exchange message file.
//     * DataPackageFileID - date of changing the exchange message file.
//
Function GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebServiceTimeConsumingOperationCompletion(
							Cancel,
							InfobaseNode,
							FileID,
							Val AuthenticationParameters = Undefined) Export
	
	// Function return value.
	Result = New Structure;
	Result.Insert("TempExchangeMessageCatalogName", "");
	Result.Insert("ExchangeMessageFileName",              "");
	Result.Insert("DataPackageFileID",       Undefined);
	
	// Parameters to be defined in the function.
	ExchangeMessageCatalogName = "";
	ExchangeMessageFileName = "";
	ExchangeMessageFileDate = Date('00010101');
	ErrorMessageString = "";
	
	Try
		
		FileTransferServiceFileName = GetFileFromStorageInService(New UUID(FileID), InfobaseNode,, AuthenticationParameters);
	Except
		
		Cancel = True;
		Message = NStr("ru = 'ŠŠ¾Š·Š½ŠøŠŗŠ»Šø Š¾ŃŠøŠ±ŠŗŠø ŠæŃŠø ŠæŠ¾Š»ŃŃŠµŠ½ŠøŠø ŃŠ¾Š¾Š±ŃŠµŠ½ŠøŃ Š¾Š±Š¼ŠµŠ½Š° ŠøŠ· ŃŠµŃŠ²ŠøŃŠ° ŠæŠµŃŠµŠ“Š°ŃŠø ŃŠ°Š¹Š»Š¾Š²: %1'; en = 'Error receiving exchange message from the file transfer service: %1'; pl = 'WystÄpiÅy bÅÄdy podczas odbierania wiadomoÅci wymiany z usÅugi przesyÅania plikĆ³w: %1';es_ES = 'Han ocurrido errores al recibir un mensaje de intercambio del servicio de transferencia de archivos: %1';es_CO = 'Han ocurrido errores al recibir un mensaje de intercambio del servicio de transferencia de archivos: %1';tr = 'Dosya aktarÄ±m hizmetinden bir deÄiÅim mesajÄ± alÄ±nÄ±rken hatalar oluÅtu:%1';it = 'Errore di ricezione del messaggio di scambio dal servizio di trasferimento del file: %1';de = 'Beim Empfang einer Austauschnachricht vom DateiĆ¼bertragungsservice sind Fehler aufgetreten: %1'", CommonClientServer.DefaultLanguageCode());
		Message = StringFunctionsClientServer.SubstituteParametersToString(Message, DetailErrorDescription(ErrorInfo()));
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = EventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndTry;
	
	Try
		ExchangeMessageCatalogName = CreateTempExchangeMessageDirectory();
	Except
		Cancel = True;
		Message = NStr("ru = 'ŠŃŠø ŠæŠ¾Š»ŃŃŠµŠ½ŠøŠø ŃŠ¾Š¾Š±ŃŠµŠ½ŠøŃ Š¾Š±Š¼ŠµŠ½Š° Š²Š¾Š·Š½ŠøŠŗŠ»Šø Š¾ŃŠøŠ±ŠŗŠø: %1'; en = 'Error receiving exchange message: %1'; pl = 'Podczas odbioru wiadomoÅci wymiany wystÄpiÅy bÅÄdy: %1';es_ES = 'Han ocurrido errores al recibir los mensajes de intercambio: %1';es_CO = 'Han ocurrido errores al recibir los mensajes de intercambio: %1';tr = 'DeÄiÅim mesajlarÄ± alÄ±nÄ±rken hatalar oluÅtu: %1';it = 'Errore di ricezione dei messaggi di scambio: %1';de = 'Beim Empfangen von Austauschnachrichten sind Fehler aufgetreten: %1'", CommonClientServer.DefaultLanguageCode());
		Message = StringFunctionsClientServer.SubstituteParametersToString(Message, DetailErrorDescription(ErrorInfo()));
		ExchangeSettingsStructure = New Structure("EventLogMessageKey");
		ExchangeSettingsStructure.EventLogMessageKey = EventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
		WriteEventLogDataExchange(Message, ExchangeSettingsStructure, True);
		
		Return Result;
	EndTry;
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
	CurrentExchangePlanNode = DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName);
	
	MessageFileNamePattern = MessageFileNamePattern(CurrentExchangePlanNode, InfobaseNode, False);
	
	ExchangeMessageFileName = CommonClientServer.GetFullFileName(ExchangeMessageCatalogName, MessageFileNamePattern + ".xml");
	FileExchangeMessages = New File(ExchangeMessageFileName);
	If NOT FileExchangeMessages.Exist() Then
		// Probably the file can be received if you apply the virtual code of the node.
		TemplateOfMessageFileNamePrevious = MessageFileNamePattern;
		MessageFileNamePattern = MessageFileNamePattern(CurrentExchangePlanNode, InfobaseNode, False,, True);
		If MessageFileNamePattern <> TemplateOfMessageFileNamePrevious Then
			ExchangeMessageFileName = CommonClientServer.GetFullFileName(ExchangeMessageCatalogName, MessageFileNamePattern + ".xml");
			FileExchangeMessages = New File(ExchangeMessageFileName);
		EndIf;
	EndIf;
	
	MoveFile(FileTransferServiceFileName, ExchangeMessageFileName);
	
	If FileExchangeMessages.Exist() Then
		ExchangeMessageFileDate = FileExchangeMessages.GetModificationTime();
	EndIf;
	
	Result.TempExchangeMessageCatalogName = ExchangeMessageCatalogName;
	Result.ExchangeMessageFileName              = ExchangeMessageFileName;
	Result.DataPackageFileID       = ExchangeMessageFileDate;
	
	Return Result;
EndFunction

// Gets exchange message file from a correspondent infobase using web service.
// Imports exchange message file to the current infobase.
//
// Parameters:
//  Cancel                   - Boolean - indicates whether an error occurred on data exchange.
//  InfobaseNode - ExchangePlanRef - an exchange plan node for which exchange message is being received.
//  FileID      - UUID - a file ID.
//  OperationStartDate      - Date - the date of import start.
//  AuthenticationParameters - Structure. Contains web service authentication parameters (User, Password).
//
Procedure ExecuteDataExchangeForInfobaseNodeTimeConsumingOperationCompletion(
															Cancel,
															Val InfobaseNode,
															Val FileID,
															Val OperationStartDate,
															Val AuthenticationParameters = Undefined,
															ShowError = False) Export
	
	CheckCanSynchronizeData();
	
	CheckDataExchangeUsage();
	
	SetPrivilegedMode(True);
	
	Try
		FileExchangeMessages = GetFileFromStorageInService(New UUID(FileID), InfobaseNode,, AuthenticationParameters);
	Except
		RecordExchangeCompletionWithError(InfobaseNode,
			Enums.ActionsOnExchange.DataImport,
			OperationStartDate,
			DetailErrorDescription(ErrorInfo()));
		If ShowError Then
			Raise;
		Else
			Cancel = True;
		EndIf;
		Return;
	EndTry;
	
	// Importing the exchange message file into the current infobase.
	DataExchangeParameters = DataExchangeParametersThroughFileOrString();
	
	DataExchangeParameters.InfobaseNode        = InfobaseNode;
	DataExchangeParameters.FullNameOfExchangeMessageFile = FileExchangeMessages;
	DataExchangeParameters.ActionOnExchange             = Enums.ActionsOnExchange.DataImport;
	DataExchangeParameters.OperationStartDate            = OperationStartDate;
	
	Try
		ExecuteDataExchangeForInfobaseNodeOverFileOrString(DataExchangeParameters);
	Except
		RecordExchangeCompletionWithError(InfobaseNode,
			Enums.ActionsOnExchange.DataImport,
			OperationStartDate,
			DetailErrorDescription(ErrorInfo()));
		If ShowError Then
			Raise;
		Else
			Cancel = True;
		EndIf;
	EndTry;
	
	Try
		DeleteFiles(FileExchangeMessages);
	Except
		WriteLogEvent(EventLogMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

// Deletes exchange message files that are not deleted due to system failures.
// Exchange files placed earlier than 24 hours ago from the current universal date and mapping files 
// placed earlier than 7 days ago from the current universal date are to be deleted.
// Analyzing IR.DataExchangeMessages and IR.DataAreaDataExchangeMessages.
//
// Parameters:
// No.
//
Procedure DeleteObsoleteExchangeMessage() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.ObsoleteSynchronizationDataDeletion);
	
	If Not GetFunctionalOption("UseDataSynchronization") Then
		Return;
	EndIf;
	
	CheckExchangeManagementRights();
	
	SetPrivilegedMode(True);
	
	If Common.SeparatedDataUsageAvailable() Then
		// Deleting obsolete exchange messages marked in IR.DataExchangeMessages.
		QueryText =
		"SELECT
		|	DataExchangeMessages.MessageID AS MessageID,
		|	DataExchangeMessages.MessageFileName AS FileName,
		|	DataExchangeMessages.MessageStoredDate AS MessageStoredDate,
		|	CommonInfobasesNodesSettings.InfobaseNode AS InfobaseNode,
		|	CASE
		|		WHEN CommonInfobasesNodesSettings.InfobaseNode IS NULL
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS MessageForMapping
		|INTO TTExchangeMessages
		|FROM
		|	InformationRegister.DataExchangeMessages AS DataExchangeMessages
		|		LEFT JOIN InformationRegister.CommonInfobasesNodesSettings AS CommonInfobasesNodesSettings
		|		ON (CommonInfobasesNodesSettings.MessageForDataMapping = DataExchangeMessages.MessageID)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TTExchangeMessages.MessageID AS MessageID,
		|	TTExchangeMessages.FileName AS FileName,
		|	TTExchangeMessages.MessageForMapping AS MessageForMapping,
		|	TTExchangeMessages.InfobaseNode AS InfobaseNode
		|FROM
		|	TTExchangeMessages AS TTExchangeMessages
		|WHERE
		|	CASE
		|			WHEN TTExchangeMessages.MessageForMapping
		|				THEN TTExchangeMessages.MessageStoredDate < &RelevanceDateForMapping
		|			ELSE TTExchangeMessages.MessageStoredDate < &UpdateDate
		|		END";
		
		Query = New Query;
		Query.SetParameter("UpdateDate",                 CurrentUniversalDate() - 60 * 60 * 24);
		Query.SetParameter("RelevanceDateForMapping", CurrentUniversalDate() - 60 * 60 * 24 * 7);
		Query.Text = QueryText;
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			
			MessageFileFullName = CommonClientServer.GetFullFileName(TempFilesStorageDirectory(), Selection.FileName);
			
			MessageFile = New File(MessageFileFullName);
			
			If MessageFile.Exist() Then
				
				Try
					DeleteFiles(MessageFile.FullName);
				Except
					WriteLogEvent(EventLogMessageTextDataExchange(),
						EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
					Continue;
				EndTry;
			EndIf;
			
			// Deleting information about message file from the storage.
			RecordStructure = New Structure;
			RecordStructure.Insert("MessageID", String(Selection.MessageID));
			InformationRegisters.DataExchangeMessages.DeleteRecord(RecordStructure);
			
			If Selection.MessageForMapping Then
				RecordStructure = New Structure;
				RecordStructure.Insert("InfobaseNode",          Selection.InfobaseNode);
				RecordStructure.Insert("MessageForDataMapping", "");
				
				UpdateInformationRegisterRecord(RecordStructure, "CommonInfobasesNodesSettings");
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// Deleting obsolete exchange messages marked in IR.DataAreaDataExchangeMessages.
	If Common.SubsystemExists("CloudTechnology.SaaS.DataExchangeSaaS") Then
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnDeleteObsoleteExchangeMessages();
	EndIf;
	
EndProcedure

Function ItemsCountInTransactionOfActionBeingExecuted(Action)
	
	If Action = Enums.ActionsOnExchange.DataExport Then
		ItemsCount = DataExportTransactionItemsCount();
	Else
		ItemsCount = DataImportTransactionItemCount();
	EndIf;
	
	Return ItemsCount;
	
EndFunction

// Exports the exchange message that contained configuration changes before infobase update.
// 
//
Procedure ExportMessageAfterInfobaseUpdate()
	
	// The repeat mode can be disabled if messages are imported and the infobase is updated successfully.
	DisableDataExchangeMessageImportRepeatBeforeStart();
	
	Try
		If GetFunctionalOption("UseDataSynchronization") Then
			
			InfobaseNode = MasterNode();
			
			If InfobaseNode <> Undefined Then
				
				ExecuteExport = True;
				
				TransportSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettings(InfobaseNode);
				
				TransportKind = TransportSettings.DefaultExchangeMessagesTransportKind;
				
				If TransportKind = Enums.ExchangeMessagesTransportTypes.WS
					AND Not TransportSettings.WSRememberPassword Then
					
					ExecuteExport = False;
					
					InformationRegisters.CommonInfobasesNodesSettings.SetDataSendingFlag(InfobaseNode);
					
				EndIf;
				
				If ExecuteExport Then
					
					// Export only.
					Cancel = False;
					
					ExchangeParameters = ExchangeParameters();
					ExchangeParameters.ExchangeMessagesTransportKind = TransportKind;
					ExchangeParameters.ExecuteImport = False;
					ExchangeParameters.ExecuteExport = True;
					
					ExecuteDataExchangeForInfobaseNode(InfobaseNode, ExchangeParameters, Cancel);
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	Except
		WriteLogEvent(EventLogMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

#EndRegion

#Region ToWorkThroughExternalConnections

Procedure ExportToTempStorageForInfobaseNode(Val ExchangePlanName, Val InfobaseNodeCode, Address) Export
	
	FullNameOfExchangeMessageFile = GetTempFileName("xml");
	
	DataExchangeParameters = DataExchangeParametersThroughFileOrString();
	
	DataExchangeParameters.FullNameOfExchangeMessageFile = FullNameOfExchangeMessageFile;
	DataExchangeParameters.ActionOnExchange             = Enums.ActionsOnExchange.DataExport;
	DataExchangeParameters.ExchangePlanName                = ExchangePlanName;
	DataExchangeParameters.InfobaseNodeCode     = InfobaseNodeCode;
	
	ExecuteDataExchangeForInfobaseNodeOverFileOrString(DataExchangeParameters);
	
	Address = PutToTempStorage(New BinaryData(FullNameOfExchangeMessageFile));
	
	DeleteFiles(FullNameOfExchangeMessageFile);
	
EndProcedure

Procedure ExportToFileTransferServiceForInfobaseNode(ProcedureParameters, StorageAddress) Export
	
	ExchangePlanName            = ProcedureParameters["ExchangePlanName"];
	InfobaseNodeCode = ProcedureParameters["InfobaseNodeCode"];
	FileID        = ProcedureParameters["FileID"];
	
	UseCompression = ProcedureParameters.Property("UseCompression") AND ProcedureParameters["UseCompression"];
	
	SetPrivilegedMode(True);
	
	MessageFileName = CommonClientServer.GetFullFileName(
		TempFilesStorageDirectory(),
		UniqueExchangeMessageFileName());
	
	DataExchangeParameters = DataExchangeParametersThroughFileOrString();
	
	DataExchangeParameters.FullNameOfExchangeMessageFile = MessageFileName;
	DataExchangeParameters.ActionOnExchange             = Enums.ActionsOnExchange.DataExport;
	DataExchangeParameters.ExchangePlanName                = ExchangePlanName;
	DataExchangeParameters.InfobaseNodeCode     = InfobaseNodeCode;
	
	ExecuteDataExchangeForInfobaseNodeOverFileOrString(DataExchangeParameters);
	
	NameOfFileToPutInStorage = MessageFileName;
	If UseCompression Then
		NameOfFileToPutInStorage = CommonClientServer.GetFullFileName(
			TempFilesStorageDirectory(),
			UniqueExchangeMessageFileName("zip"));
		
		Archiver = New ZipFileWriter(NameOfFileToPutInStorage, , , , ZIPCompressionLevel.Maximum);
		Archiver.Add(MessageFileName);
		Archiver.Write();
		
		DeleteFiles(MessageFileName);
	EndIf;
	
	PutFileInStorage(NameOfFileToPutInStorage, FileID);
	
EndProcedure

Procedure ExportForInfobaseNodeViaFile(Val ExchangePlanName,
	Val InfobaseNodeCode,
	Val FullNameOfExchangeMessageFile) Export
	
	DataExchangeParameters = DataExchangeParametersThroughFileOrString();
	
	DataExchangeParameters.FullNameOfExchangeMessageFile = FullNameOfExchangeMessageFile;
	DataExchangeParameters.ActionOnExchange             = Enums.ActionsOnExchange.DataExport;
	DataExchangeParameters.ExchangePlanName                = ExchangePlanName;
	DataExchangeParameters.InfobaseNodeCode     = InfobaseNodeCode;
	
	ExecuteDataExchangeForInfobaseNodeOverFileOrString(DataExchangeParameters);
	
EndProcedure

Procedure ExportForInfobaseNodeViaString(Val ExchangePlanName, Val InfobaseNodeCode, ExchangeMessage) Export
	
	DataExchangeParameters = DataExchangeParametersThroughFileOrString();
	
	DataExchangeParameters.ActionOnExchange             = Enums.ActionsOnExchange.DataExport;
	DataExchangeParameters.ExchangePlanName                = ExchangePlanName;
	DataExchangeParameters.InfobaseNodeCode     = InfobaseNodeCode;
	DataExchangeParameters.ExchangeMessage               = ExchangeMessage;
	
	ExecuteDataExchangeForInfobaseNodeOverFileOrString(DataExchangeParameters);
	
	ExchangeMessage = DataExchangeParameters.ExchangeMessage;
	
EndProcedure

Procedure ImportForInfobaseNodeViaString(Val ExchangePlanName, Val InfobaseNodeCode, ExchangeMessage) Export
	
	DataExchangeParameters = DataExchangeParametersThroughFileOrString();
	
	DataExchangeParameters.ActionOnExchange             = Enums.ActionsOnExchange.DataImport;
	DataExchangeParameters.ExchangePlanName                = ExchangePlanName;
	DataExchangeParameters.InfobaseNodeCode     = InfobaseNodeCode;
	DataExchangeParameters.ExchangeMessage               = ExchangeMessage;
	
	ExecuteDataExchangeForInfobaseNodeOverFileOrString(DataExchangeParameters);
	
	ExchangeMessage = DataExchangeParameters.ExchangeMessage;
	
EndProcedure

Procedure ImportFromFileTransferServiceForInfobaseNode(ProcedureParameters, StorageAddress) Export
	
	ExchangePlanName            = ProcedureParameters["ExchangePlanName"];
	InfobaseNodeCode = ProcedureParameters["InfobaseNodeCode"];
	FileID        = ProcedureParameters["FileID"];
	
	SetPrivilegedMode(True);
	
	TempFileName = GetFileFromStorage(FileID);
	
	DataExchangeParameters = DataExchangeParametersThroughFileOrString();
	
	DataExchangeParameters.FullNameOfExchangeMessageFile = TempFileName;
	DataExchangeParameters.ActionOnExchange             = Enums.ActionsOnExchange.DataImport;
	DataExchangeParameters.ExchangePlanName                = ExchangePlanName;
	DataExchangeParameters.InfobaseNodeCode     = InfobaseNodeCode;
	
	Try
		ExecuteDataExchangeForInfobaseNodeOverFileOrString(DataExchangeParameters);
	Except
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		DeleteFiles(TempFileName);
		Raise ErrorPresentation;
	EndTry;
	
	DeleteFiles(TempFileName);
EndProcedure

Function DataExchangeParametersThroughFileOrString() Export
	
	ParametersStructure = New Structure;
	
	ParametersStructure.Insert("InfobaseNode");
	ParametersStructure.Insert("FullNameOfExchangeMessageFile", "");
	ParametersStructure.Insert("ActionOnExchange");
	ParametersStructure.Insert("ExchangePlanName", "");
	ParametersStructure.Insert("InfobaseNodeCode", "");
	ParametersStructure.Insert("ExchangeMessage", "");
	ParametersStructure.Insert("OperationStartDate", "");
	
	Return ParametersStructure;
	
EndFunction

Procedure ExecuteDataExchangeForInfobaseNodeOverFileOrString(ExchangeParameters) Export
	
	CheckCanSynchronizeData();
	
	CheckDataExchangeUsage();
	
	SetPrivilegedMode(True);
	
	If ExchangeParameters.InfobaseNode = Undefined Then
		
		ExchangePlanName = ExchangeParameters.ExchangePlanName;
		InfobaseNodeCode = ExchangeParameters.InfobaseNodeCode;
		
		ExchangeParameters.InfobaseNode = ExchangePlans[ExchangePlanName].FindByCode(InfobaseNodeCode);
			
		If ExchangeParameters.InfobaseNode.IsEmpty()
			AND IsXDTOExchangePlan(ExchangePlanName) Then
			MigrationError = False;
			SynchronizationSetupViaCF = ExchangePlans[ExchangePlanName].MigrateToDataSyncViaUniversalFormatInternet(
				InfobaseNodeCode, MigrationError);
			If ValueIsFilled(SynchronizationSetupViaCF) Then
				ExchangeParameters.InfobaseNode = SynchronizationSetupViaCF;
			ElsIf MigrationError Then
				ErrorMessageString = NStr("ru = 'ŠŠµ ŃŠ“Š°Š»Š¾ŃŃ Š²ŃŠæŠ¾Š»Š½ŠøŃŃ ŠæŠµŃŠµŃŠ¾Š“ Š½Š° ŃŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŃ Š“Š°Š½Š½ŃŃ ŃŠµŃŠµŠ· ŃŠ½ŠøŠ²ŠµŃŃŠ°Š»ŃŠ½ŃŠ¹ ŃŠ¾ŃŠ¼Š°Ń.'; en = 'Cannot transfer to data synchronization via universal format.'; pl = 'Nie udaÅo siÄ wykonaÄ przejÅcie do synchronizacji danych za pomocÄ formatu uniwersalnego.';es_ES = 'No se ha podido pasar a la sincronizaciĆ³n de datos a travĆ©s del frmato universal.';es_CO = 'No se ha podido pasar a la sincronizaciĆ³n de datos a travĆ©s del frmato universal.';tr = 'Genel biĆ§im Ć¼zerinden veri eÅleÅtirmeye geĆ§iÅ baÅarÄ±sÄ±z oldu.';it = 'Impossibile trasferire alla sincronizzazione dati tramite formato universale.';de = 'Fehler beim Migrieren zum Synchronisieren der Daten Ć¼ber das universelle Format.'");
				Raise ErrorMessageString;
			EndIf;
		EndIf;
		
		If ExchangeParameters.InfobaseNode.IsEmpty() Then
			ErrorMessageString = NStr("ru = 'Š£Š·ŠµŠ» ŠæŠ»Š°Š½Š° Š¾Š±Š¼ŠµŠ½Š° %1 Ń ŠŗŠ¾Š“Š¾Š¼ %2 Š½Šµ Š½Š°Š¹Š“ŠµŠ½.'; en = 'The %1 exchange plan node with the %2 code is not found.'; pl = 'Nie znaleziono wÄzÅa planu wymiany %1 z kodem %2.';es_ES = 'Nodo del plan de intercambio %1 con el cĆ³digo %2 no encontrado.';es_CO = 'Nodo del plan de intercambio %1 con el cĆ³digo %2 no encontrado.';tr = '%1 Kod ile deÄiÅim planÄ± Ć¼nitesi %2 bulunamadÄ±.';it = 'Nodo di piano di scambio %1 con codice %2 non trovato.';de = 'Austauschplan-Knoten %1 mit Code %2 wurde nicht gefunden.'");
			ErrorMessageString = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageString, ExchangePlanName, InfobaseNodeCode);
			Raise ErrorMessageString;
		EndIf;
		
	EndIf;
	
	ExecuteExchangeSettingsUpdate(ExchangeParameters.InfobaseNode);
	
	If Not SynchronizationSetupCompleted(ExchangeParameters.InfobaseNode) Then
		
		ApplicationPresentation = ?(Common.DataSeparationEnabled(),
			Metadata.Synonym, DataExchangeCached.ThisInfobaseName());
			
		CorrespondentData = Common.ObjectAttributesValues(ExchangeParameters.InfobaseNode,
			"Code, Description");
		
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Š ""%1"" Š½Š°ŃŃŃŠ¾Š¹ŠŗŠ° ŃŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŠø Š“Š°Š½Š½ŃŃ Ń ""%2"" (ŠøŠ“ŠµŠ½ŃŠøŃŠøŠŗŠ°ŃŠ¾Ń ""%3"") ŠµŃŠµ Š½Šµ Š·Š°Š²ŠµŃŃŠµŠ½Š°.'; en = 'In ""%1"", data synchronization with ""%2"" (ID ""%3"") has not been set up.'; pl = 'W ""%1"" ustawienie synchronizacji danych z ""%2"" (identyfikator ""%3"") jeszcze nie jest zakoÅczone.';es_ES = 'En ""%1"" el ajuste de sincronizaciĆ³n de datos con ""%2"" (identificador ""%3"") todavĆ­a no se ha terminado.';es_CO = 'En ""%1"" el ajuste de sincronizaciĆ³n de datos con ""%2"" (identificador ""%3"") todavĆ­a no se ha terminado.';tr = '""%1"" ""%2""(kimlik""%3"") ile veri senkronizasyonu ayarÄ± henĆ¼z tamamlanmadÄ±.';it = 'In ""%1"" la sincronizzazione con ""%2"" (ID ""%3"") non ĆØ stata impostata.';de = 'In ""%1"" ist die Einstellung der Datensynchronisation mit ""%2"" (Bezeichner ""%3"") noch nicht abgeschlossen.'"),
			ApplicationPresentation, CorrespondentData.Description, CorrespondentData.Code);
			
		Raise ErrorMessageString;
	EndIf;
	
	// INITIALIZING DATA EXCHANGE
	ExchangeSettingsStructure = DataExchangeCached.ExchangeSettingsOfInfobaseNode(
		ExchangeParameters.InfobaseNode, ExchangeParameters.ActionOnExchange, Undefined, False);
	
	If ExchangeSettingsStructure.Cancel Then
		ErrorMessageString = NStr("ru = 'ŠŃŠøŠ±ŠŗŠ° ŠæŃŠø ŠøŠ½ŠøŃŠøŠ°Š»ŠøŠ·Š°ŃŠøŠø ŠæŃŠ¾ŃŠµŃŃŠ° Š¾Š±Š¼ŠµŠ½Š° Š“Š°Š½Š½ŃŠ¼Šø.'; en = 'Error initializing data exchange process.'; pl = 'Podczas inicjowania procesu wymiany danych wystÄpiÅ bÅÄd.';es_ES = 'Ha ocurrido un error al iniciar el proceso de intercambio de datos.';es_CO = 'Ha ocurrido un error al iniciar el proceso de intercambio de datos.';tr = 'Veri alÄ±ÅveriÅi sĆ¼recini baÅlatÄ±rken bir hata oluÅtu.';it = 'Errore durante l''inizializzazione del processo di scambio dati.';de = 'Bei der Initialisierung des Datenaustauschprozesses ist ein Fehler aufgetreten.'");
		AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
		Raise ErrorMessageString;
	EndIf;
	
	ExchangeSettingsStructure.ExchangeExecutionResult = Undefined;
	ExchangeSettingsStructure.StartDate = ?(ExchangeParameters.OperationStartDate = Undefined, CurrentSessionDate(), ExchangeParameters.OperationStartDate);
	
	MessageString = NStr("ru = 'ŠŠ°ŃŠ°Š»Š¾ ŠæŃŠ¾ŃŠµŃŃŠ° Š¾Š±Š¼ŠµŠ½Š° Š“Š°Š½Š½ŃŠ¼Šø Š“Š»Ń ŃŠ·Š»Š° %1'; en = 'Data exchange process started for %1 node'; pl = 'PoczÄtek procesu wymiany danych dla wÄzÅa %1';es_ES = 'Inicio de proceso de intercambio de datos para el nodo %1';es_CO = 'Inicio de proceso de intercambio de datos para el nodo %1';tr = '%1Ćnite iĆ§in veri deÄiÅimi sĆ¼reci baÅlatÄ±lÄ±yor';it = 'Il processo di scambio dati iniziato per il nodo %1';de = 'Datenaustausch beginnt fĆ¼r Knoten %1'", CommonClientServer.DefaultLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, ExchangeSettingsStructure.InfobaseNodeDescription);
	WriteEventLogDataExchange(MessageString, ExchangeSettingsStructure);
	
	If ExchangeSettingsStructure.DoDataImport Then
		
		TemporaryFileCreated = False;
		If ExchangeParameters.FullNameOfExchangeMessageFile = ""
			AND ExchangeParameters.ExchangeMessage <> "" Then
			
			ExchangeParameters.FullNameOfExchangeMessageFile = GetTempFileName(".xml");
			TextFile = New TextDocument;
			TextFile.SetText(ExchangeParameters.ExchangeMessage);
			TextFile.Write(ExchangeParameters.FullNameOfExchangeMessageFile);
			TemporaryFileCreated = True;
		EndIf;
		
		ReadMessageWithNodeChanges(ExchangeSettingsStructure, ExchangeParameters.FullNameOfExchangeMessageFile, ExchangeParameters.ExchangeMessage);
		
		// {Handler: AfterExchangeMessageRead} Start
		StandardProcessing = True;
		
		AfterExchangeMessageRead(
					ExchangeSettingsStructure.InfobaseNode,
					ExchangeParameters.FullNameOfExchangeMessageFile,
					ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult),
					StandardProcessing);
		// {Handler: AfterExchangeMessageRead} End
		
		If TemporaryFileCreated Then
			
			Try
				DeleteFiles(ExchangeParameters.FullNameOfExchangeMessageFile);
			Except
				WriteLogEvent(EventLogMessageTextDataExchange(),
					EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			EndTry;
		EndIf;
		
	ElsIf ExchangeSettingsStructure.DoDataExport Then
		
		WriteMessageWithNodeChanges(ExchangeSettingsStructure, ExchangeParameters.FullNameOfExchangeMessageFile, ExchangeParameters.ExchangeMessage);
		
	EndIf;
	
	AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
	
	If Not ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
		Raise ExchangeSettingsStructure.ErrorMessageString;
	EndIf;
	
EndProcedure

Procedure AddExchangeOverExternalConnectionFinishEventLogMessage(ExchangeSettingsStructure) Export
	
	SetPrivilegedMode(True);
	
	AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
	
EndProcedure

Function ExchangeOverExternalConnectionSettingsStructure(Structure) Export
	
	CheckDataExchangeUsage();
	
	SetPrivilegedMode(True);
	
	InfobaseNode = ExchangePlans[Structure.ExchangePlanName].FindByCode(Structure.CurrentExchangePlanNodeCode);
	
	ActionOnExchange = Enums.ActionsOnExchange[Structure.ActionOnStringExchange];
	
	ExchangeSettingsStructureExternalConnection = New Structure;
	ExchangeSettingsStructureExternalConnection.Insert("ExchangePlanName",                   Structure.ExchangePlanName);
	ExchangeSettingsStructureExternalConnection.Insert("DebugMode",                     Structure.DebugMode);
	
	ExchangeSettingsStructureExternalConnection.Insert("InfobaseNode",             InfobaseNode);
	ExchangeSettingsStructureExternalConnection.Insert("InfobaseNodeDescription", Common.ObjectAttributeValue(InfobaseNode, "Description"));
	
	ExchangeSettingsStructureExternalConnection.Insert("EventLogMessageKey",  EventLogMessageKey(InfobaseNode, ActionOnExchange));
	
	ExchangeSettingsStructureExternalConnection.Insert("ExchangeExecutionResult",        Undefined);
	ExchangeSettingsStructureExternalConnection.Insert("ExchangeExecutionResultString", "");
	
	ExchangeSettingsStructureExternalConnection.Insert("ActionOnExchange", ActionOnExchange);
	
	ExchangeSettingsStructureExternalConnection.Insert("ExportHandlersDebug", False);
	ExchangeSettingsStructureExternalConnection.Insert("ImportHandlersDebug", False);
	ExchangeSettingsStructureExternalConnection.Insert("ExportDebugExternalDataProcessorFileName", "");
	ExchangeSettingsStructureExternalConnection.Insert("ImportDebugExternalDataProcessorFileName", "");
	ExchangeSettingsStructureExternalConnection.Insert("DataExchangeLoggingMode", False);
	ExchangeSettingsStructureExternalConnection.Insert("ExchangeProtocolFileName", "");
	ExchangeSettingsStructureExternalConnection.Insert("ContinueOnError", False);
	
	SetDebugModeSettingsForStructure(ExchangeSettingsStructureExternalConnection, True);
	
	ExchangeSettingsStructureExternalConnection.Insert("ProcessedObjectsCount", 0);
	
	ExchangeSettingsStructureExternalConnection.Insert("StartDate",    Undefined);
	ExchangeSettingsStructureExternalConnection.Insert("EndDate", Undefined);
	
	ExchangeSettingsStructureExternalConnection.Insert("MessageOnExchange",      "");
	ExchangeSettingsStructureExternalConnection.Insert("ErrorMessageString", "");
	
	ExchangeSettingsStructureExternalConnection.Insert("TransactionItemsCount", Structure.TransactionItemsCount);
	
	ExchangeSettingsStructureExternalConnection.Insert("IsDIBExchange", False);
	
	Return ExchangeSettingsStructureExternalConnection;
EndFunction

Function GetObjectConversionRulesViaExternalConnection(ExchangePlanName, GetCorrespondentRules = False) Export
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.DataExchangeRules.ParsedRulesOfObjectConversion(ExchangePlanName, GetCorrespondentRules);
	
EndFunction

Procedure ExecuteExchangeActionForInfobaseNodeUsingWebService(Cancel,
		InfobaseNode, ActionOnExchange, ExchangeParameters)
	
	ParametersOnly = ExchangeParameters.ParametersOnly;
	
	SetPrivilegedMode(True);
	
	// INITIALIZING DATA EXCHANGE
	ExchangeSettingsStructure = DataExchangeCached.ExchangeSettingsOfInfobaseNode(InfobaseNode, ActionOnExchange, Enums.ExchangeMessagesTransportTypes.WS, False);
	
	If ExchangeSettingsStructure.Cancel Then
		// If settings contain errors, canceling the exchange.
		AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
		Cancel = True;
		Return;
	EndIf;
	
	ExchangeSettingsStructure.ExchangeExecutionResult = Undefined;
	ExchangeSettingsStructure.StartDate = CurrentSessionDate();
	
	MessageString = NStr("ru = 'ŠŠ°ŃŠ°Š»Š¾ ŠæŃŠ¾ŃŠµŃŃŠ° Š¾Š±Š¼ŠµŠ½Š° Š“Š°Š½Š½ŃŠ¼Šø Š“Š»Ń ŃŠ·Š»Š° %1'; en = 'Data exchange process started for %1 node'; pl = 'PoczÄtek procesu wymiany danych dla wÄzÅa %1';es_ES = 'Inicio de proceso de intercambio de datos para el nodo %1';es_CO = 'Inicio de proceso de intercambio de datos para el nodo %1';tr = '%1Ćnite iĆ§in veri deÄiÅimi sĆ¼reci baÅlatÄ±lÄ±yor';it = 'Il processo di scambio dati iniziato per il nodo %1';de = 'Datenaustausch beginnt fĆ¼r Knoten %1'", CommonClientServer.DefaultLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, ExchangeSettingsStructure.InfobaseNodeDescription);
	WriteEventLogDataExchange(MessageString, ExchangeSettingsStructure);
	
	If ExchangeSettingsStructure.DoDataImport Then
		
		If ExchangeSettingsStructure.UseLargeDataTransfer Then
			
			// {Handler: BeforeExchangeMessageRead} Start
			FileExchangeMessages = "";
			StandardProcessing = True;
			
			BeforeExchangeMessageRead(ExchangeSettingsStructure.InfobaseNode, FileExchangeMessages, StandardProcessing);
			// {Handler: BeforeExchangeMessageRead} End
			
			If StandardProcessing Then
				
				ErrorMessageString = "";
				
				// Getting web service proxy for the infobase node.
				Proxy = WSProxyForInfobaseNode(
					InfobaseNode,
					ErrorMessageString,
					ExchangeParameters.AuthenticationParameters);
				
				If Proxy = Undefined Then
					
					// Adding the event log entry.
					WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
					
					// If settings contain errors, canceling the exchange.
					ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
					AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
					Cancel = True;
					Return;
				EndIf;
				
				FileExchangeMessages = "";
				
				Try
					
					Proxy.UploadData(ExchangeSettingsStructure.ExchangePlanName,
						ExchangeSettingsStructure.CurrentExchangePlanNodeCode,
						ExchangeParameters.FileID,
						ExchangeParameters.TimeConsumingOperation,
						ExchangeParameters.OperationID,
						ExchangeParameters.TimeConsumingOperationAllowed);
					
					If ExchangeParameters.TimeConsumingOperation Then
						WriteEventLogDataExchange(NStr("ru = 'ŠŠ¶ŠøŠ“Š°Š½ŠøŠµ ŠæŠ¾Š»ŃŃŠµŠ½ŠøŃ Š“Š°Š½Š½ŃŃ Š¾Ń Š±Š°Š·Ń-ŠŗŠ¾ŃŃŠµŃŠæŠ¾Š½Š“ŠµŠ½ŃŠ°...'; en = 'Waiting for data from the correspondent infobase...'; pl = 'Oczekiwanie odbioru danych z bazy korespondenta...';es_ES = 'Datos pendientes de la base corresponsal...';es_CO = 'Datos pendientes de la base corresponsal...';tr = 'Muhabir tabandan veri bekleniyor ...';it = 'In attesa di dati dall''infobase corrispondente...';de = 'Ausstehende Daten von der Korrespondenzbasis...'",
							CommonClientServer.DefaultLanguageCode()), ExchangeSettingsStructure);
						Return;
					EndIf;
					
					FileExchangeMessages = GetFileFromStorageInService(
						New UUID(ExchangeParameters.FileID),
						InfobaseNode,,
						ExchangeParameters.AuthenticationParameters);
				Except
					WriteEventLogDataExchange(DetailErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
					ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
					Cancel = True;
				EndTry;
				
			EndIf;
			
			If Not Cancel Then
				
				ReadMessageWithNodeChanges(ExchangeSettingsStructure, FileExchangeMessages,, ParametersOnly);
				
			EndIf;
			
			// {Handler: AfterExchangeMessageRead} Start
			StandardProcessing = True;
			
			AfterExchangeMessageRead(
						ExchangeSettingsStructure.InfobaseNode,
						FileExchangeMessages,
						ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult),
						StandardProcessing,
						Not ParametersOnly);
			// {Handler: AfterExchangeMessageRead} End
			
			If StandardProcessing Then
				
				Try
					If Not IsBlankString(FileExchangeMessages) AND TypeOf(DataExchangeMessageFromMasterNode()) <> Type("Structure") Then
						DeleteFiles(FileExchangeMessages);
					EndIf;
				Except
					WriteLogEvent(EventLogMessageTextDataExchange(),
						EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
				EndTry;
				
			EndIf;
			
		Else
			
			ErrorMessageString = "";
			
			// Getting web service proxy for the infobase node.
			Proxy = WSProxyForInfobaseNode(
				InfobaseNode,
				ErrorMessageString,
				ExchangeParameters.AuthenticationParameters);
			
			If Proxy = Undefined Then
				
				// Adding the event log entry.
				WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
				
				// If settings contain errors, canceling the exchange.
				ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
				AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
				Cancel = True;
				Return;
			EndIf;
			
			ExchangeMessageStorage = Undefined;
			NodeAlias = PredefinedNodeAlias(InfobaseNode);

			Try
				If ValueIsFilled(NodeAlias) Then
					// Check whether correspondent has such node (probably it is re-encoded).
					NodeAliasExists = True;
					ErrorMessage = "";
					ProxyDestinationParameters = Proxy.GetIBParameters(ExchangeSettingsStructure.ExchangePlanName, NodeAlias, ErrorMessage);
					Try
						DestinationParameters = XDTOSerializer.ReadXDTO(ProxyDestinationParameters);
					Except
						DestinationParameters = ValueFromStringInternal(ProxyDestinationParameters);
					EndTry;
					If DestinationParameters.Property("NodeExists") Then
						NodeAliasExists = (DestinationParameters.NodeExists = True);
					EndIf;
					If NodeAliasExists Then
						ExchangeSettingsStructure.CurrentExchangePlanNodeCode = NodeAlias;
					EndIf;
				EndIf;

				Proxy.Upload(ExchangeSettingsStructure.ExchangePlanName, ExchangeSettingsStructure.CurrentExchangePlanNodeCode, ExchangeMessageStorage);
				
				ReadMessageWithNodeChanges(ExchangeSettingsStructure,, ExchangeMessageStorage.Get());
				
			Except
				WriteEventLogDataExchange(DetailErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
				ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
			EndTry;
			
		EndIf;
		
	ElsIf ExchangeSettingsStructure.DoDataExport Then
		
		ErrorMessageString = "";
		
		// Getting web service proxy for the infobase node.
		EarliestVersion = "";
		If ExchangeParameters.MessageForDataMapping Then
			EarliestVersion = "3.0.1.1";
		EndIf;
		
		Proxy = WSProxyForInfobaseNode(
			InfobaseNode,
			ErrorMessageString,
			ExchangeParameters.AuthenticationParameters,
			EarliestVersion);
		
		If Proxy = Undefined Then
			// Adding the event log entry.
			WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
			
			// If settings contain errors, canceling the exchange.
			ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
			AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
			Cancel = True;
			Return;
		EndIf;
		
		NodeAlias = PredefinedNodeAlias(InfobaseNode);
		
		HasMappingSupport            = True;
		DataSynchronizationSetupCompleted = True;
		If ValueIsFilled(NodeAlias) Then
			// Check whether correspondent has such node (probably it is re-encoded).
			NodeAliasExists = True;
			ErrorMessageString = "";
			ProxyDestinationParameters = Proxy.GetIBParameters(ExchangeSettingsStructure.ExchangePlanName, NodeAlias, ErrorMessageString);
			Try
				DestinationParameters = XDTOSerializer.ReadXDTO(ProxyDestinationParameters);
			Except
				DestinationParameters = ValueFromStringInternal(ProxyDestinationParameters);
			EndTry;
			If DestinationParameters.Property("NodeExists") Then
				NodeAliasExists = (DestinationParameters.NodeExists = True);
			EndIf;
			If NodeAliasExists Then
				ExchangeSettingsStructure.CurrentExchangePlanNodeCode = NodeAlias;
			EndIf;
			If DestinationParameters.Property("DataMappingSupported") Then
				HasMappingSupport = DestinationParameters.DataMappingSupported;
			EndIf;
			If DestinationParameters.Property("DataSynchronizationSetupCompleted") Then
				DataSynchronizationSetupCompleted = DestinationParameters.DataSynchronizationSetupCompleted;
			EndIf;
		Else
			ProxyDestinationParameters = Proxy.GetIBParameters(
				ExchangeSettingsStructure.ExchangePlanName,
				ExchangeSettingsStructure.CurrentExchangePlanNodeCode,
				ErrorMessageString);
			Try
				DestinationParameters = XDTOSerializer.ReadXDTO(ProxyDestinationParameters);
			Except
				DestinationParameters = ValueFromStringInternal(ProxyDestinationParameters);
			EndTry;
			If DestinationParameters.Property("DataMappingSupported") Then
				HasMappingSupport = DestinationParameters.DataMappingSupported;
			EndIf;
			If DestinationParameters.Property("DataSynchronizationSetupCompleted") Then
				DataSynchronizationSetupCompleted = DestinationParameters.DataSynchronizationSetupCompleted;
			EndIf;
		EndIf;
		
		If ExchangeSettingsStructure.UseLargeDataTransfer Then
			
			TemporaryDirectory = GetTempFileName();
			CreateDirectory(TemporaryDirectory);
			
			FileExchangeMessages = CommonClientServer.GetFullFileName(
				TemporaryDirectory, UniqueExchangeMessageFileName());
			
			Try
				WriteMessageWithNodeChanges(ExchangeSettingsStructure, FileExchangeMessages);
			Except
				WriteEventLogDataExchange(DetailErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
				ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
				Cancel = True;
			EndTry;
			
			// Sending exchange message only if data is exported successfully.
			If ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) AND Not Cancel Then
				
				Try
					
					FileIDAsString = String(PutFileInStorageInService(
						FileExchangeMessages, InfobaseNode,, ExchangeParameters.AuthenticationParameters));
					
					Try
						DeleteFiles(TemporaryDirectory);
					Except
						WriteLogEvent(EventLogMessageTextDataExchange(),
							EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
					EndTry;
						
					If ExchangeParameters.MessageForDataMapping
						AND (HasMappingSupport Or Not DataSynchronizationSetupCompleted) Then
						Proxy.PutMessageForDataMatching(ExchangeSettingsStructure.ExchangePlanName,
							ExchangeSettingsStructure.CurrentExchangePlanNodeCode,
							FileIDAsString);
					Else
						Proxy.DownloadData(ExchangeSettingsStructure.ExchangePlanName,
							ExchangeSettingsStructure.CurrentExchangePlanNodeCode,
							FileIDAsString,
							ExchangeParameters.TimeConsumingOperation,
							ExchangeParameters.OperationID,
							ExchangeParameters.TimeConsumingOperationAllowed);
					
						If ExchangeParameters.TimeConsumingOperation Then
							WriteEventLogDataExchange(NStr("ru = 'ŠŠ¶ŠøŠ“Š°Š½ŠøŠµ Š·Š°Š³ŃŃŠ·ŠŗŠø Š“Š°Š½Š½ŃŃ Š² Š±Š°Š·Šµ-ŠŗŠ¾ŃŃŠµŃŠæŠ¾Š½Š“ŠµŠ½ŃŠµ...'; en = 'Waiting for data import in correspondent infobase...'; pl = 'Oczekiwanie importu danych z bazy korespondenta...';es_ES = 'ImportaciĆ³n de datos pendiente en la base corresponsal...';es_CO = 'ImportaciĆ³n de datos pendiente en la base corresponsal...';tr = 'Muhabir bazÄ±nda veri iĆ§e aktarma bekleniyor ...';it = 'In attesa dell''importazione dati all''infobase corrispondente...';de = 'Ausstehende Datenimport in der Korrespondenzbasis...'",
								CommonClientServer.DefaultLanguageCode()), ExchangeSettingsStructure);
							Return;
						EndIf;
					EndIf;
					
				Except
					WriteEventLogDataExchange(DetailErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
					ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
					Cancel = True;
				EndTry;
				
			EndIf;
			
			Try
				DeleteFiles(TemporaryDirectory);
			Except
				WriteLogEvent(EventLogMessageTextDataExchange(),
					EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			EndTry;
			
		Else
			
			ExchangeMessage = "";
			
			Try
				
				WriteMessageWithNodeChanges(ExchangeSettingsStructure,, ExchangeMessage);
				
				// Sending exchange message only if data is exported successfully.
				If ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
					
					Proxy.Download(ExchangeSettingsStructure.ExchangePlanName,
						ExchangeSettingsStructure.CurrentExchangePlanNodeCode,
						New ValueStorage(ExchangeMessage, New Deflation(9)));
						
				EndIf;
				
			Except
				WriteEventLogDataExchange(DetailErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
				ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
			EndTry;
			
		EndIf;
		
	EndIf;
	
	AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
	
	If Not ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
		Cancel = True;
	EndIf;
	
EndProcedure

Procedure ExecuteExchangeActionForInfobaseNodeUsingExternalConnection(Cancel, InfobaseNode,
	ActionOnExchange,
	TransactionItemsCount,
	MessageForDataMapping = False)
	
	SetPrivilegedMode(True);
	
	// INITIALIZING DATA EXCHANGE
	ExchangeSettingsStructure = ExchangeSettingsForExternalConnection(
		InfobaseNode,
		ActionOnExchange,
		TransactionItemsCount);
	
	ExchangeSettingsStructure.StartDate = CurrentSessionDate();
	
	WriteLogEventDataExchangeStart(ExchangeSettingsStructure);
	
	If ExchangeSettingsStructure.Cancel Then
		// If settings contain errors, canceling the exchange.
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
		AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
		Cancel = True;
		Return;
	EndIf;
	
	ErrorMessageString = "";
	
	// Getting external connection for the infobase node.
	ExternalConnection = DataExchangeCached.GetExternalConnectionForInfobaseNode(
		InfobaseNode,
		ErrorMessageString);
	
	If ExternalConnection = Undefined Then
		
		// Adding the event log entry.
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		// If settings contain errors, canceling the exchange.
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
		AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
		Cancel = True;
		Return;
	EndIf;
	
	// Getting remote infobase version.
	SSLVersionByExternalConnection = ExternalConnection.StandardSubsystemsServer.LibraryVersion();
	ExchangeWithSSL20 = CommonClientServer.CompareVersions("2.1.1.10", SSLVersionByExternalConnection) > 0;
	
	// INITIALIZING DATA EXCHANGE (USING EXTERNAL CONNECTION)
	Structure = New Structure("ExchangePlanName, CurrentExchangePlanNodeCode, TransactionItemsCount");
	FillPropertyValues(Structure, ExchangeSettingsStructure);
	
	// Reversing enumeration values.
	ActionOnStringExchange = ?(ActionOnExchange = Enums.ActionsOnExchange.DataExport,
								Common.EnumValueName(Enums.ActionsOnExchange.DataImport),
								Common.EnumValueName(Enums.ActionsOnExchange.DataExport));
	//
	
	Structure.Insert("ActionOnStringExchange", ActionOnStringExchange);
	Structure.Insert("DebugMode", False);
	Structure.Insert("ExchangeProtocolFileName", "");
	
	IsXDTOExchangePlan = IsXDTOExchangePlan(InfobaseNode);
	If IsXDTOExchangePlan Then
		// Checking predefined node alias.
		PredefinedNodeAlias = PredefinedNodeAlias(InfobaseNode);
		ExchangePlanManager = ExternalConnection.ExchangePlans[Structure.ExchangePlanName];
		CheckNodeExistenceInCorrespondent = True;
		If ValueIsFilled(PredefinedNodeAlias) Then
			// You need to check the node code in the correspondent because it can be already re-encoded.
			// In this case, alias is not required.
			If ExchangePlanManager.FindByCode(PredefinedNodeAlias) <> ExchangePlanManager.EmptyRef() Then
				Structure.CurrentExchangePlanNodeCode = PredefinedNodeAlias;
				CheckNodeExistenceInCorrespondent = False;
			EndIf;
		EndIf;
		If CheckNodeExistenceInCorrespondent Then
			// Checking whether the node exists in the correspondent infobase.
			ExchangePlanRef = ExchangePlanManager.FindByCode(Structure.CurrentExchangePlanNodeCode);
			If NOT ValueIsFilled(ExchangePlanRef.Code) Then
				// If necessary, start migration to data synchronization via universal format.
				MessageText = NStr("ru = 'ŠŠµŠ¾Š±ŃŠ¾Š“ŠøŠ¼ ŠæŠµŃŠµŃŠ¾Š“ Š½Š° ŃŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŃ Š“Š°Š½Š½ŃŃ ŃŠµŃŠµŠ· ŃŠ½ŠøŠ²ŠµŃŃŠ°Š»ŃŠ½ŃŠ¹ ŃŠ¾ŃŠ¼Š°Ń Š² Š±Š°Š·Šµ-ŠŗŠ¾ŃŃŠµŃŠæŠ¾Š½Š“ŠµŠ½ŃŠµ.'; en = 'Data in the correspondent base must be synced via universal format.'; pl = 'Jest potrzebne przejÅcie do synchronizacji danych za pomocÄ formatu uniwersalnego w bazie-korespondencie.';es_ES = 'Es necesario pasar a la sincronizaciĆ³n de datos a travĆ©s del formato universal en la base-correspondiente.';es_CO = 'Es necesario pasar a la sincronizaciĆ³n de datos a travĆ©s del formato universal en la base-correspondiente.';tr = 'Muhabir veritabanÄ±nda genel bir format Ć¼zerinden veri senkronizasyonu iĆ§in bir geĆ§iÅ gereklidir.';it = 'I dati nella base corrispondente devono essere sincronizzati attraverso il formato universale.';de = 'Es ist erforderlich, auf die Synchronisation von Daten Ć¼ber das Universalformat in der entsprechenden Datenbank umzuschalten.'");
				WriteEventLogDataExchange(MessageText, ExchangeSettingsStructure, False);

				ParametersStructure = New Structure();
				ParametersStructure.Insert("Code", Structure.CurrentExchangePlanNodeCode);
				ParametersStructure.Insert("SettingsMode", 
					Common.ObjectAttributeValue(InfobaseNode, "SettingsMode"));
				ParametersStructure.Insert("Error", False);
				ParametersStructure.Insert("ErrorMessage", "");
				
				HasErrors = False;
				ErrorMessageString = "";
				TransferResult = 
					ExchangePlanManager.MigrateToDataSyncViaUniversalFormatExternalConnection(ParametersStructure);
				If ParametersStructure.Error Then
					HasErrors = True;
					NString = NStr("ru = 'ŠŃŠøŠ±ŠŗŠ° ŠæŃŠø ŠæŠµŃŠµŃŠ¾Š“Šµ Š½Š° ŃŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŃ Š“Š°Š½Š½ŃŃ ŃŠµŃŠµŠ· ŃŠ½ŠøŠ²ŠµŃŃŠ°Š»ŃŠ½ŃŠ¹ ŃŠ¾ŃŠ¼Š°Ń: %1. ŠŠ±Š¼ŠµŠ½ Š¾ŃŠ¼ŠµŠ½ŠµŠ½.'; en = 'An error occurred when moving to the data synchronization via universal format: %1. Exchange canceled.'; pl = 'BÅÄd podczas przejÅcia do synchronizacji danych za pomocÄ formatu uniwersalnego: %1. Wymiana zostaÅa anulowana.';es_ES = 'Error al pasar a la sincronizaciĆ³n de datos a travĆ©s del formato universal: %1. Intercambio cancelado.';es_CO = 'Error al pasar a la sincronizaciĆ³n de datos a travĆ©s del formato universal: %1. Intercambio cancelado.';tr = 'Genel biĆ§im Ć¼zerinden veri senkronizasyonu geĆ§iÅ yaparken bir hata oluÅtu:%1 . Veri alÄ±ÅveriÅi iptal edildi.';it = 'Si ĆØ verificato un errore durante il passaggio alla sincronizzazione dati tramite formato universale: %1. Scambio annullato.';de = 'Fehler bei der Umstellung auf Datensynchronisation Ć¼ber das Universalformat: %1. Der Austausch wird abgebrochen.'",
						CommonClientServer.DefaultLanguageCode());
					ErrorMessageString = StringFunctionsClientServer.SubstituteParametersToString(NString, 
						ParametersStructure.ErrorMessage);
				ElsIf TransferResult = Undefined Then
					HasErrors = True;
					ErrorMessageString = NStr("ru = 'ŠŠµŃŠµŃŠ¾Š“ Š½Š° ŃŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŃ Š“Š°Š½Š½ŃŃ ŃŠµŃŠµŠ· ŃŠ½ŠøŠ²ŠµŃŃŠ°Š»ŃŠ½ŃŠ¹ ŃŠ¾ŃŠ¼Š°Ń Š½Šµ Š²ŃŠæŠ¾Š»Š½ŠµŠ½'; en = 'Transition to data synchronization via universal format was not completed'; pl = 'PrzejÅcie do synchronizacji danych za pomocÄ formatu uniwersalnego nie jest wykonane';es_ES = 'No se ha pasado a la sincronizaciĆ³n de datos a travĆ©s del formato universal';es_CO = 'No se ha pasado a la sincronizaciĆ³n de datos a travĆ©s del formato universal';tr = 'Genel biĆ§im Ć¼zerinden veri eÅitlemeye geĆ§iÅ baÅarÄ±sÄ±z oldu';it = 'La transizione alla sincronizzazione dati tramite formato universale non ĆØ stata completata';de = 'Der Ćbergang zur Synchronisation von Daten durch das Universalformat wird nicht durchgefĆ¼hrt'");
				EndIf;
				If HasErrors Then
					// Data synchronization is not possible.
					WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
					ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
					AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
					Cancel = True;
					Return;
				Else
					Message = NStr("ru = 'ŠŠµŃŠµŃŠ¾Š“ Š½Š° ŃŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŃ Š“Š°Š½Š½ŃŃ ŃŠµŃŠµŠ· ŃŠ½ŠøŠ²ŠµŃŃŠ°Š»ŃŠ½ŃŠ¹ ŃŠ¾ŃŠ¼Š°Ń Š·Š°Š²ŠµŃŃŠµŠ½ ŃŃŠæŠµŃŠ½Š¾.'; en = 'Transition to data synchronization via universal format succeeded.'; pl = 'PrzejÅcie do synchronizacji danych za pomocÄ formatu uniwersalnego jest zakoÅczone pomyÅlnie.';es_ES = 'Se ha pasado con Ć©xito a la sincronizaciĆ³n de datos a travĆ©s del formato universal.';es_CO = 'Se ha pasado con Ć©xito a la sincronizaciĆ³n de datos a travĆ©s del formato universal.';tr = 'Genel biĆ§im Ć¼zerinden veri eÅitlemeye geĆ§iÅ baÅarÄ±lÄ± oldu.';it = 'Transizione alla sincronizzazione dati tramite formato universale riuscita.';de = 'Der Ćbergang zur Synchronisation von Daten Ć¼ber das Universalformat wurde erfolgreich abgeschlossen.'");
					WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, False);
				EndIf;
			EndIf;  // If NOT ValueIsFilled(ExchangePlanRef.Code) Then
		EndIf; // If CheckNodeExistenceInCorrespondent Then
	EndIf; //If IsXDTOExchangePlan Then
	
	Try
		ExchangeSettingsStructureExternalConnection = ExternalConnection.DataExchangeExternalConnection.ExchangeSettingsStructure(Structure);
	Except
		// Adding the event log entry.
		WriteEventLogDataExchange(DetailErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
		
		// If settings contain errors, canceling the exchange.
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
		AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
		Cancel = True;
		Return;
	EndTry;
	
	ExchangeSettingsStructure.ExchangeExecutionResult = Undefined;
	ExchangeSettingsStructureExternalConnection.StartDate = ExternalConnection.CurrentSessionDate();
	
	ExternalConnection.DataExchangeExternalConnection.WriteLogEventDataExchangeStart(ExchangeSettingsStructureExternalConnection);
	// DATA EXCHANGE
	If ExchangeSettingsStructure.DoDataImport Then
		If NOT IsXDTOExchangePlan Then
			// Getting exchange rules from the correspondent infobase.
			ObjectConversionRules = ExternalConnection.DataExchangeExternalConnection.GetObjectConversionRules(ExchangeSettingsStructureExternalConnection.ExchangePlanName);
			
			If ObjectConversionRules = Undefined Then
				
				// Exchange rules must be specified.
				NString = NStr("ru = 'ŠŠµ Š·Š°Š“Š°Š½Ń ŠæŃŠ°Š²ŠøŠ»Š° ŠŗŠ¾Š½Š²ŠµŃŃŠ°ŃŠøŠø Š²Š¾ Š²ŃŠ¾ŃŠ¾Š¹ ŠøŠ½ŃŠ¾ŃŠ¼Š°ŃŠøŠ¾Š½Š½Š¾Š¹ Š±Š°Š·Šµ Š“Š»Ń ŠæŠ»Š°Š½Š° Š¾Š±Š¼ŠµŠ½Š° %1. ŠŠ±Š¼ŠµŠ½ Š¾ŃŠ¼ŠµŠ½ŠµŠ½.'; en = 'Conversion rules for exchange plan %1 are not specified in the second infobase. Exchange is canceled.'; pl = 'ReguÅy konwersji dla planu wymiany %1 nie sÄ okreÅlone w drugiej bazie informacyjnej. Wymiana zostanie anulowana.';es_ES = 'Reglas de conversiĆ³n para el plan de intercambio %1 no estĆ”n especificadas en la segunda infobase. Intercambio se ha cancelado.';es_CO = 'Reglas de conversiĆ³n para el plan de intercambio %1 no estĆ”n especificadas en la segunda infobase. Intercambio se ha cancelado.';tr = '%1 deÄiÅim planÄ±nÄ±n dĆ¶nĆ¼ÅĆ¼m kurallarÄ± ikinci Infobase''de belirtilmedi. DeÄiÅim iptal edildi.';it = 'Nessuna regola di conversione ĆØ specificata nella seconda base di informazioni per il piano di scambio %1. Scambio annullato';de = 'Konvertierungsregeln fĆ¼r den Austauschplan %1 sind in der zweiten Infobase nicht angegeben. Austausch wird abgebrochen.'",
					CommonClientServer.DefaultLanguageCode());
				ErrorMessageString = StringFunctionsClientServer.SubstituteParametersToString(NString, ExchangeSettingsStructureExternalConnection.ExchangePlanName);
				WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
				SetExchangeInitEnd(ExchangeSettingsStructure);
				Return;
			EndIf;
		EndIf;
		
		// Data processor for importing data.
		DataProcessorForDataImport = ExchangeSettingsStructure.DataExchangeDataProcessor;
		DataProcessorForDataImport.ExchangeFileName = "";
		DataProcessorForDataImport.ObjectCountPerTransaction = ExchangeSettingsStructure.TransactionItemsCount;
		DataProcessorForDataImport.UseTransactions = (DataProcessorForDataImport.ObjectCountPerTransaction <> 1);
		If NOT IsXDTOExchangePlan Then
			DataProcessorForDataImport.DataImportedOverExternalConnection = True;
		EndIf;
		
		// Getting the initialized data processor for exporting data.
		If IsXDTOExchangePlan Then
			DataExchangeDataProcessorExternalConnection = ExternalConnection.DataProcessors.ConvertXTDOObjects.Create();
			DataExchangeDataProcessorExternalConnection.ExchangeMode = "DataExported";
		Else
			DataExchangeDataProcessorExternalConnection = ExternalConnection.DataProcessors.InfobaseObjectConversion.Create();
			DataExchangeDataProcessorExternalConnection.SavedSettings = ObjectConversionRules;
			DataExchangeDataProcessorExternalConnection.DataImportExecutedInExternalConnection = False;
			DataExchangeDataProcessorExternalConnection.ExchangeMode = "DataExported";
			Try
				DataExchangeDataProcessorExternalConnection.RestoreRulesFromInternalFormat();
			Except
				WriteEventLogDataExchange(
					StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'ŠŠ¾Š·Š½ŠøŠŗŠ»Š° Š¾ŃŠøŠ±ŠŗŠ° Š²Š¾ Š²ŃŠ¾ŃŠ¾Š¹ ŠøŠ½ŃŠ¾ŃŠ¼Š°ŃŠøŠ¾Š½Š½Š¾Š¹ Š±Š°Š·Šµ: %1'; en = 'Error occurred in the second infobase: %1'; pl = 'WystÄpiÅ bÅÄd w drugiej bazie informacyjnej: %1';es_ES = 'Ha ocurrido un error en la segunda infobase: %1';es_CO = 'Ha ocurrido un error en la segunda infobase: %1';tr = 'Ä°kinci veritabanÄ±nda bir hata oluÅtu:%1';it = 'Si ĆØ verificato un errore nella seconda infobase: %1';de = 'In der zweiten Infobase ist ein Fehler aufgetreten: %1'"),
					DetailErrorDescription(ErrorInfo())), ExchangeSettingsStructure, True);
				
				// If settings contain errors, canceling the exchange.
				ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
				AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
				Cancel = True;
				Return;
			EndTry;
			// Specifying exchange nodes.
			DataExchangeDataProcessorExternalConnection.BackgroundExchangeNode = Undefined;
			DataExchangeDataProcessorExternalConnection.DoNotExportObjectsByRefs = True;
			DataExchangeDataProcessorExternalConnection.ExchangeRuleFileName = "1";
			DataExchangeDataProcessorExternalConnection.ExternalConnection = Undefined;
		EndIf;

		// Specifying exchange nodes (common for all exchange kinds).
		DataExchangeDataProcessorExternalConnection.NodeForExchange = ExchangeSettingsStructureExternalConnection.InfobaseNode;
		
		SetCommonParametersForDataExchangeProcessing(DataExchangeDataProcessorExternalConnection, ExchangeSettingsStructureExternalConnection, ExchangeWithSSL20);
		
		If NOT IsXDTOExchangePlan Then
			DestinationConfigurationVersion = "";
			SourceVersionFromRules = "";
			MessageText = "";
			ExternalConnectionParameters = New Structure;
			ExternalConnectionParameters.Insert("ExternalConnection", ExternalConnection);
			ExternalConnectionParameters.Insert("SSLVersionByExternalConnection", SSLVersionByExternalConnection);
			ExternalConnectionParameters.Insert("EventLogMessageKey", ExchangeSettingsStructureExternalConnection.EventLogMessageKey);
			ExternalConnectionParameters.Insert("InfobaseNode", ExchangeSettingsStructureExternalConnection.InfobaseNode);
			
			ObjectConversionRules.Get().Conversion.Property("SourceConfigurationVersion", DestinationConfigurationVersion);
			DataProcessorForDataImport.SavedSettings.Get().Conversion.Property("SourceConfigurationVersion", SourceVersionFromRules);
			
			If DifferentCorrespondentVersions(ExchangeSettingsStructure.ExchangePlanName, ExchangeSettingsStructure.EventLogMessageKey,
				SourceVersionFromRules, DestinationConfigurationVersion, MessageText, ExternalConnectionParameters) Then
				
				DataExchangeDataProcessorExternalConnection = Undefined;
				Return;
				
			EndIf;
		EndIf;
		// EXPORT (CORRESPONDENT) - IMPORT (CURRENT INFOBASE)
		DataExchangeDataProcessorExternalConnection.RunDataExport(DataProcessorForDataImport);
		
		// Commiting data exchange state.
		ExchangeSettingsStructure.ExchangeExecutionResult    = DataProcessorForDataImport.ExchangeExecutionResult();
		ExchangeSettingsStructure.ProcessedObjectsCount = DataProcessorForDataImport.ImportedObjectCounter();
		ExchangeSettingsStructureExternalConnection.ExchangeExecutionResultString = DataExchangeDataProcessorExternalConnection.ExchangeExecutionResultString();
		ExchangeSettingsStructureExternalConnection.ProcessedObjectsCount     = DataExchangeDataProcessorExternalConnection.ExportedObjectCounter();
		ExchangeSettingsStructure.MessageOnExchange           = DataProcessorForDataImport.CommentOnDataImport;
		ExchangeSettingsStructure.ErrorMessageString      = DataProcessorForDataImport.ErrorMessageString();
		ExchangeSettingsStructureExternalConnection.MessageOnExchange               = DataExchangeDataProcessorExternalConnection.CommentOnDataExport;
		ExchangeSettingsStructureExternalConnection.ErrorMessageString          = DataExchangeDataProcessorExternalConnection.ErrorMessageString();
		
		DataExchangeDataProcessorExternalConnection = Undefined;
		
	ElsIf ExchangeSettingsStructure.DoDataExport Then
		
		// Data processor for importing data.
		If IsXDTOExchangePlan Then
			DataProcessorForDataImport = ExternalConnection.DataProcessors.ConvertXTDOObjects.Create();
		Else
			DataProcessorForDataImport = ExternalConnection.DataProcessors.InfobaseObjectConversion.Create();
			DataProcessorForDataImport.DataImportedOverExternalConnection = True;
		EndIf;
		DataProcessorForDataImport.ExchangeMode = "Load";
		DataProcessorForDataImport.ExchangeNodeDataImport = ExchangeSettingsStructureExternalConnection.InfobaseNode;
		
		SetCommonParametersForDataExchangeProcessing(DataProcessorForDataImport, ExchangeSettingsStructureExternalConnection, ExchangeWithSSL20);
		
		HasMappingSupport            = True;
		DataSynchronizationSetupCompleted = True;
		InterfaceVersions = InterfaceVersionsThroughExternalConnection(ExternalConnection);
		If InterfaceVersions.Find("3.0.1.1") <> Undefined Then
			ErrorMessage = "";
			InfobaseParameters = ExternalConnection.DataExchangeExternalConnection.GetInfobaseParameters_2_0_1_6(
				ExchangeSettingsStructure.ExchangePlanName, ExchangeSettingsStructure.CurrentExchangePlanNodeCode, ErrorMessage);
			CorrespondentParameters = Common.ValueFromXMLString(InfobaseParameters);
			If CorrespondentParameters.Property("DataMappingSupported") Then
				HasMappingSupport = CorrespondentParameters.DataMappingSupported;
			EndIf;
			If CorrespondentParameters.Property("DataSynchronizationSetupCompleted") Then
				DataSynchronizationSetupCompleted = CorrespondentParameters.DataSynchronizationSetupCompleted;
			EndIf;
		EndIf;
		
		If MessageForDataMapping
			AND (HasMappingSupport Or Not DataSynchronizationSetupCompleted) Then
			DataProcessorForDataImport.DataImportMode = "ImportMessageForDataMapping";
		EndIf;
		
		DataProcessorForDataImport.ObjectCountPerTransaction = ExchangeSettingsStructure.TransactionItemsCount;
		DataProcessorForDataImport.UseTransactions = (DataProcessorForDataImport.ObjectCountPerTransaction <> 1);
		
		// Getting the initialized data processor for exporting data.
		DataExchangeXMLDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
		DataExchangeXMLDataProcessor.ExchangeFileName = "";
		
		If Not IsXDTOExchangePlan Then
			
			DataExchangeXMLDataProcessor.ExternalConnection = ExternalConnection;
			DataExchangeXMLDataProcessor.DataImportExecutedInExternalConnection = True;
			
		EndIf;
		
		// EXPORT (THIS INFOBASE) - IMPORT (CORRESPONDENT)
		DataExchangeXMLDataProcessor.RunDataExport(DataProcessorForDataImport);
		
		// Commiting data exchange state.
		ExchangeSettingsStructure.ExchangeExecutionResult    = DataExchangeXMLDataProcessor.ExchangeExecutionResult();
		ExchangeSettingsStructure.ProcessedObjectsCount = DataExchangeXMLDataProcessor.ExportedObjectCounter();
		ExchangeSettingsStructureExternalConnection.ExchangeExecutionResultString = DataProcessorForDataImport.ExchangeExecutionResultString();
		ExchangeSettingsStructureExternalConnection.ProcessedObjectsCount     = DataProcessorForDataImport.ImportedObjectCounter();
		ExchangeSettingsStructure.MessageOnExchange           = DataExchangeXMLDataProcessor.CommentOnDataExport;
		ExchangeSettingsStructure.ErrorMessageString      = DataExchangeXMLDataProcessor.ErrorMessageString();
		ExchangeSettingsStructureExternalConnection.MessageOnExchange               = DataProcessorForDataImport.CommentOnDataImport;
		ExchangeSettingsStructureExternalConnection.ErrorMessageString          = DataProcessorForDataImport.ErrorMessageString();
		DataProcessorForDataImport = Undefined;
		
	EndIf;
	
	AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
	
	ExternalConnection.DataExchangeExternalConnection.AddExchangeCompletionEventLogMessage(ExchangeSettingsStructureExternalConnection);
	
	If Not ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

Procedure ExecuteDataExchangeOverFileResource(ExchangeSettingsStructure, Val ParametersOnly = False)
	
	If ExchangeSettingsStructure.DoDataImport Then
		
		// {Handler: BeforeExchangeMessageRead} Start
		ExchangeMessage = "";
		StandardProcessing = True;
		
		BeforeExchangeMessageRead(ExchangeSettingsStructure.InfobaseNode, ExchangeMessage, StandardProcessing);
		// {Handler: BeforeExchangeMessageRead} End
		
		If StandardProcessing Then
			
			ExecuteExchangeMessageTransportBeforeProcessing(ExchangeSettingsStructure);
			
			If ExchangeSettingsStructure.ExchangeExecutionResult = Undefined Then
				
				ExecuteExchangeMessageTransportReceiving(ExchangeSettingsStructure);
				
				If ExchangeSettingsStructure.ExchangeExecutionResult = Undefined Then
					
					ExchangeMessage = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.ExchangeMessageFileName();
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		// Data is imported only if the exchange message is received successfully.
		If ExchangeSettingsStructure.ExchangeExecutionResult = Undefined Then
			
			HasMappingSupport = ExchangePlanSettingValue(
				DataExchangeCached.GetExchangePlanName(ExchangeSettingsStructure.InfobaseNode),
				"DataMappingSupported",
				SavedExchangePlanNodeSettingOption(ExchangeSettingsStructure.InfobaseNode));
			
			If ExchangeSettingsStructure.AdditionalParameters.Property("MessageForDataMapping")
				AND (HasMappingSupport 
					Or Not SynchronizationSetupCompleted(ExchangeSettingsStructure.InfobaseNode)) Then
				
				NameOfFileToPutInStorage = CommonClientServer.GetFullFileName(
					TempFilesStorageDirectory(),
					UniqueExchangeMessageFileName());
					
				// Saving a new message for data mapping.
				FileID = PutFileInStorage(NameOfFileToPutInStorage);
				MoveFile(ExchangeMessage, NameOfFileToPutInStorage);
				
				DataExchangeInternal.PutMessageForDataMapping(
					ExchangeSettingsStructure.InfobaseNode, FileID);
				
				StandardProcessing = True;
			Else
				
				ReadMessageWithNodeChanges(ExchangeSettingsStructure, ExchangeMessage, , ParametersOnly);
				
				// {Handler: AfterExchangeMessageRead} Start
				StandardProcessing = True;
				
				AfterExchangeMessageRead(
							ExchangeSettingsStructure.InfobaseNode,
							ExchangeMessage,
							ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult),
							StandardProcessing,
							Not ParametersOnly);
				// {Handler: AfterExchangeMessageRead} End
				
			EndIf;
			
		EndIf;
		
		If StandardProcessing Then
			
			ExecuteExchangeMessageTransportAfterProcessing(ExchangeSettingsStructure);
			
		EndIf;
		
	ElsIf ExchangeSettingsStructure.DoDataExport Then
		
		ExecuteExchangeMessageTransportBeforeProcessing(ExchangeSettingsStructure);
		
		// Exporting data.
		If ExchangeSettingsStructure.ExchangeExecutionResult = Undefined Then
			
			WriteMessageWithNodeChanges(ExchangeSettingsStructure, ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.ExchangeMessageFileName());
			
		EndIf;
		
		// Sending exchange message only if data is exported successfully.
		If ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
			
			ExecuteExchangeMessageTransportSending(ExchangeSettingsStructure);
			
		EndIf;
		
		ExecuteExchangeMessageTransportAfterProcessing(ExchangeSettingsStructure);
		
	EndIf;
	
EndProcedure

Procedure BeforeExchangeMessageRead(Val Recipient, ExchangeMessage, StandardProcessing)
	
	If IsSubordinateDIBNode()
		AND TypeOf(MasterNode()) = TypeOf(Recipient) Then
		
		SavedExchangeMessage = DataExchangeMessageFromMasterNode();
		
		If TypeOf(SavedExchangeMessage) = Type("BinaryData") Then
			// Converting to a new storage format and re-reading the DataExchangeMessageFromMasterNode constant 
			// value.
			SetDataExchangeMessageFromMasterNode(SavedExchangeMessage, Recipient);
			SavedExchangeMessage = DataExchangeMessageFromMasterNode();
		EndIf;
		
		If TypeOf(SavedExchangeMessage) = Type("Structure") Then
			
			StandardProcessing = False;
			
			ExchangeMessage = SavedExchangeMessage.PathToFile;
			
			WriteDataReceiveEvent(Recipient, NStr("ru = 'Š”Š¾Š¾Š±ŃŠµŠ½ŠøŠµ Š¾Š±Š¼ŠµŠ½Š° ŠæŠ¾Š»ŃŃŠµŠ½Š¾ ŠøŠ· ŠŗŃŃŠ°.'; en = 'The exchange message is received from the cached values.'; pl = 'WiadomoÅÄ wymiany zostaÅa odebrana z pamiÄci podrÄcznej.';es_ES = 'El mensaje de intercambio se ha recibido del cachĆ©.';es_CO = 'El mensaje de intercambio se ha recibido del cachĆ©.';tr = 'DeÄiÅim mesajÄ± Ć¶nbellekten alÄ±ndÄ±.';it = 'Il messaggio di scambio ĆØ stato ricevuto dai valori di cache.';de = 'Die Austauschnachricht wurde vom Cache empfangen.'"));
			
			SetPrivilegedMode(True);
			SetDataExchangeMessageImportModeBeforeStart("MessageReceivedFromCache", True);
			SetPrivilegedMode(False);
			
		Else
			SetPrivilegedMode(True);
			SetDataExchangeMessageImportModeBeforeStart("MessageReceivedFromCache", False);
			SetPrivilegedMode(False);
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure AfterExchangeMessageRead(Val Recipient, Val ExchangeMessage, Val MessageRead, StandardProcessing, Val DeleteMessage = True)
	
	If IsSubordinateDIBNode()
		AND TypeOf(MasterNode()) = TypeOf(Recipient) Then
		
		If NOT MessageRead
		   AND DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart("MessageReceivedFromCache") Then
			// Cannot read the message received from cache. Cache requires cleaning.
			ClearDataExchangeMessageFromMasterNode();
			Return;
		EndIf;
		
		UpdateCachedMessage = False;
		
		If ConfigurationChanged() Then
			
			// If obsolete exchange message is stored in the cache, cached values must be updated, because 
			// configuration can be changed again.
			// 
			UpdateCachedMessage = True;
			
			If Not MessageRead Then
				
				If NOT Constants.LoadDataExchangeMessage.Get() Then
					Constants.LoadDataExchangeMessage.Set(True);
				EndIf;
				
			EndIf;
			
		Else
			
			If DeleteMessage Then
				
				ClearDataExchangeMessageFromMasterNode();
				If Constants.LoadDataExchangeMessage.Get() Then
					Constants.LoadDataExchangeMessage.Set(False);
				EndIf;
				
			Else
				// Exchange message can be read without importing metadata. After reading the application parameters, 
				// the exchange message is to be saved so that not to import it again for basic reading.
				// 
				UpdateCachedMessage = True;
			EndIf;
			
		EndIf;
		
		If UpdateCachedMessage Then
			
			PreviousMessage = DataExchangeMessageFromMasterNode();
			
			UpdateCachedValues = False;
			NewMessage = New BinaryData(ExchangeMessage);
			
			StructureType = TypeOf(PreviousMessage) = Type("Structure");
			
			If StructureType Or TypeOf(PreviousMessage) = Type("BinaryData") Then
				
				If StructureType Then
					PreviousMessage = New BinaryData(PreviousMessage.PathToFile);
				EndIf;
				
				If PreviousMessage.Size() <> NewMessage.Size() Then
					UpdateCachedValues = True;
				ElsIf NewMessage <> PreviousMessage Then
					UpdateCachedValues = True;
				EndIf;
				
			Else
				
				UpdateCachedValues = True;
				
			EndIf;
			
			If UpdateCachedValues Then
				SetDataExchangeMessageFromMasterNode(NewMessage, Recipient);
			EndIf;
		EndIf;
		
	EndIf;
	
	If MessageRead AND Common.SeparatedDataUsageAvailable() Then
		InformationRegisters.DataSyncEventHandlers.ExecuteHandlers(Recipient, "AfterGetData");
	EndIf;
	
EndProcedure

// Writes infobase node changes to file in the temporary directory.
//
// Parameters:
//  ExchangeSettingsStructure - Structure - a structure with all necessary data and objects to execute exchange.
// 
Procedure WriteMessageWithNodeChanges(ExchangeSettingsStructure, Val ExchangeMessageFileName = "", ExchangeMessage = "")
	
	If ExchangeSettingsStructure.IsDIBExchange Then // Performing exchange in DIB.
		
		Cancel = False;
		ErrorMessage = "";
		
		// Getting the exchange data processor.
		DataExchangeDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
		
		// Specifying the name of the exchange message file to be read.
		DataExchangeDataProcessor.SetExchangeMessageFileName(ExchangeMessageFileName);
		
		DataExchangeDataProcessor.RunDataExport(Cancel, ErrorMessage);
		
		If Cancel Then
			
			ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
			ExchangeSettingsStructure.ErrorMessageString = ErrorMessage;
			
		EndIf;
		
	Else
		
		// {Handler: OnDataExport} Start. Overriding the standard export data processor.
		StandardProcessing = True;
		ProcessedObjectsCount = 0;
		
		Try
			OnSSLDataExportHandler(StandardProcessing,
											ExchangeSettingsStructure.InfobaseNode,
											ExchangeMessageFileName,
											ExchangeMessage,
											ExchangeSettingsStructure.TransactionItemsCount,
											ExchangeSettingsStructure.EventLogMessageKey,
											ProcessedObjectsCount);
			
			If StandardProcessing = True Then
				
				ProcessedObjectsCount = 0;
				
				OnDataExportHandler(StandardProcessing,
												ExchangeSettingsStructure.InfobaseNode,
												ExchangeMessageFileName,
												ExchangeMessage,
												ExchangeSettingsStructure.TransactionItemsCount,
												ExchangeSettingsStructure.EventLogMessageKey,
												ProcessedObjectsCount);
				
			EndIf;
			
		Except
			
			ErrorMessageString = DetailErrorDescription(ErrorInfo());
			
			WriteLogEvent(ExchangeSettingsStructure.EventLogMessageKey, EventLogLevel.Error,
					ExchangeSettingsStructure.InfobaseNode.Metadata(), 
					ExchangeSettingsStructure.InfobaseNode, ErrorMessageString);
			ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
			ExchangeSettingsStructure.ErrorMessageString = ErrorMessageString;
			Return;
		EndTry;
		
		If StandardProcessing = False Then
			ExchangeSettingsStructure.ProcessedObjectsCount = ProcessedObjectsCount;
			Return;
		EndIf;
		// {Handler: OnDataExport} End
		
		// Universal exchange (exchange using conversion rules).
		If ExchangeSettingsStructure.ExchangeByObjectConversionRules Then
			
			GenerateExchangeMessage = IsBlankString(ExchangeMessageFileName);
			If GenerateExchangeMessage Then
				ExchangeMessageFileName = GetTempFileName(".xml");
			EndIf;
			
			// Getting the initialized exchange data processor.
			DataExchangeXMLDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
			DataExchangeXMLDataProcessor.ExchangeFileName = ExchangeMessageFileName;
			
			// Exporting data.
			DataExchangeXMLDataProcessor.RunDataExport();
			
			If GenerateExchangeMessage Then
				TextFile = New TextDocument;
				TextFile.Read(ExchangeMessageFileName, TextEncoding.UTF8);
				ExchangeMessage = TextFile.GetText();
				DeleteFiles(ExchangeMessageFileName);
			EndIf;
			
			ExchangeSettingsStructure.ExchangeExecutionResult = DataExchangeXMLDataProcessor.ExchangeExecutionResult();
			
			// Commiting data exchange state.
			ExchangeSettingsStructure.ProcessedObjectsCount = DataExchangeXMLDataProcessor.ExportedObjectCounter();
			ExchangeSettingsStructure.MessageOnExchange           = DataExchangeXMLDataProcessor.CommentOnDataExport;
			ExchangeSettingsStructure.ErrorMessageString      = DataExchangeXMLDataProcessor.ErrorMessageString();
			
		Else // Standard exchange (platform serialization).
			
			Cancel = False;
			ProcessedObjectsCount = 0;
			
			ExecuteStandardNodeChangeExport(Cancel,
								ExchangeSettingsStructure.InfobaseNode,
								ExchangeMessageFileName,
								ExchangeMessage,
								ExchangeSettingsStructure.TransactionItemsCount,
								ExchangeSettingsStructure.EventLogMessageKey,
								ProcessedObjectsCount);
			
			ExchangeSettingsStructure.ProcessedObjectsCount = ProcessedObjectsCount;
			
			If Cancel Then
				
				ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Gets an exchange message with new data and imports the data to the infobase.
//
// Parameters:
//  ExchangeSettingsStructure - Structure - a structure with all necessary data and objects to execute exchange.
// 
Procedure ReadMessageWithNodeChanges(ExchangeSettingsStructure,
		Val ExchangeMessageFileName = "", ExchangeMessage = "", Val ParametersOnly = False)
	
	If ExchangeSettingsStructure.IsDIBExchange Then // Performing exchange in DIB.
		
		Cancel = False;
		
		// Getting the exchange data processor.
		DataExchangeDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
		
		// Specifying the name of the exchange message file to be read.
		DataExchangeDataProcessor.SetExchangeMessageFileName(ExchangeMessageFileName);
		
		DataExchangeDataProcessor.RunDataImport(Cancel, ParametersOnly);
		
		If Cancel Then
			
			ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
			
		EndIf;
		
	Else
		
		// {Handler: OnDataImport} Start. Overriding the standard import data processor.
		StandardProcessing = True;
		ProcessedObjectsCount = 0;
		
		Try
			OnSSLDataImportHandler(StandardProcessing,
											ExchangeSettingsStructure.InfobaseNode,
											ExchangeMessageFileName,
											ExchangeMessage,
											ExchangeSettingsStructure.TransactionItemsCount,
											ExchangeSettingsStructure.EventLogMessageKey,
											ProcessedObjectsCount);
			
			If StandardProcessing = True Then
				
				ProcessedObjectsCount = 0;
				
				OnDataImportHandler(StandardProcessing,
												ExchangeSettingsStructure.InfobaseNode,
												ExchangeMessageFileName,
												ExchangeMessage,
												ExchangeSettingsStructure.TransactionItemsCount,
												ExchangeSettingsStructure.EventLogMessageKey,
												ProcessedObjectsCount);
				
			EndIf;
			
		Except
			ErrorMessageString = DetailErrorDescription(ErrorInfo());
			
			WriteLogEvent(ExchangeSettingsStructure.EventLogMessageKey, EventLogLevel.Error,
					ExchangeSettingsStructure.InfobaseNode.Metadata(), 
					ExchangeSettingsStructure.InfobaseNode, ErrorMessageString);
			ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
			ExchangeSettingsStructure.ErrorMessageString = ErrorMessageString;
			Return;
		EndTry;
		
		If StandardProcessing = False Then
			ExchangeSettingsStructure.ProcessedObjectsCount = ProcessedObjectsCount;
			Return;
		EndIf;
		// {Handler: OnDataImport} End
		
		// Universal exchange (exchange using conversion rules).
		If ExchangeSettingsStructure.ExchangeByObjectConversionRules Then
			
			// Getting the initialized exchange data processor.
			DataExchangeXMLDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
			DataExchangeXMLDataProcessor.ExchangeFileName = ExchangeMessageFileName;
			
			// Importing data.
			DataExchangeXMLDataProcessor.RunDataImport();
			
			If DataExchangeCached.IsXDTOExchangePlan(ExchangeSettingsStructure.ExchangePlanName) Then
				DataReceivedForMapping = False;
				If Not DataExchangeXMLDataProcessor.ExchangeComponents.ErrorFlag Then
					DataReceivedForMapping = (DataExchangeXMLDataProcessor.ExchangeComponents.IncomingMessageNumber > 0
						AND DataExchangeXMLDataProcessor.ExchangeComponents.MessageNumberReceivedByCorrespondent = 0);
				EndIf;
				ExchangeSettingsStructure.AdditionalParameters.Insert("DataReceivedForMapping", DataReceivedForMapping);
			EndIf;
			
			ExchangeSettingsStructure.ExchangeExecutionResult = DataExchangeXMLDataProcessor.ExchangeExecutionResult();
			
			// Commiting data exchange state.
			ExchangeSettingsStructure.ProcessedObjectsCount = DataExchangeXMLDataProcessor.ImportedObjectCounter();
			ExchangeSettingsStructure.MessageOnExchange           = DataExchangeXMLDataProcessor.CommentOnDataImport;
			ExchangeSettingsStructure.ErrorMessageString      = DataExchangeXMLDataProcessor.ErrorMessageString();
			
		Else // Standard exchange (platform serialization).
			
			ProcessedObjectsCount = 0;
			ExchangeExecutionResult = Undefined;
			
			ExecuteStandardNodeChangeImport(
				ExchangeSettingsStructure.InfobaseNode,
				ExchangeMessageFileName,
				ExchangeMessage,
				ExchangeSettingsStructure.TransactionItemsCount,
				ExchangeSettingsStructure.EventLogMessageKey,
				ProcessedObjectsCount,
				ExchangeExecutionResult);
								
			ExchangeSettingsStructure.ProcessedObjectsCount = ProcessedObjectsCount;
			ExchangeSettingsStructure.ExchangeExecutionResult = ExchangeExecutionResult;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region SerializationMethodsExchangeExecution

// Records changes for the exchange message.
// Can be applied if the infobases have the same metadata structure for all objects involved in the exchange.
//
Procedure ExecuteStandardNodeChangeExport(Cancel,
							InfobaseNode,
							FileName,
							ExchangeMessage,
							TransactionItemsCount = 0,
							EventLogMessageKey = "",
							ProcessedObjectsCount = 0)
	
	If IsBlankString(EventLogMessageKey) Then
		EventLogMessageKey = EventLogMessageTextDataExchange();
	EndIf;
	
	InitialDataExport = InitialDataExportFlagIsSet(InfobaseNode);
	
	WriteToFile = Not IsBlankString(FileName);
	
	XMLWriter = New XMLWriter;
	
	If WriteToFile Then
		
		XMLWriter.OpenFile(FileName);
	Else
		
		XMLWriter.SetString();
	EndIf;
	
	XMLWriter.WriteXMLDeclaration();
	
	// Creating a new message.
	WriteMessage = ExchangePlans.CreateMessageWriter();
	
	WriteMessage.BeginWrite(XMLWriter, InfobaseNode);
	
	// Counting the number of written objects.
	WrittenObjectCount = 0;
	ProcessedObjectsCount = 0;
	
	UseTransactions = TransactionItemsCount <> 1;
	
	DataExchangeServerCall.CheckObjectsRegistrationMechanismCache();
	
	// Getting changed data selection.
	ChangesSelection = SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo);
	
	If UseTransactions Then
		BeginTransaction();
	EndIf;
	
	Try
		
		RecipientObject = WriteMessage.Recipient.GetObject();
		
		While ChangesSelection.Next() Do
			
			Data = ChangesSelection.Get();
			
			ProcessedObjectsCount = ProcessedObjectsCount + 1;
			
			// Checking whether the object passes the ORR filter. If the object does not pass the ORR filter, 
			// sending object deletion to the target infobase. If the object is a record set, verifying each 
			// record. All record sets are exported, even empty ones. An empty set is the object deletion analog.
			// 
			ItemSend = DataItemSend.Auto;
			
			StandardSubsystemsServer.OnSendDataToSlave(Data, ItemSend, InitialDataExport, RecipientObject);
			
			If ItemSend = DataItemSend.Delete Then
				
				If Common.IsRegister(Data.Metadata()) Then
					
					// Sending an empty record set upon the register deletion.
					
				Else
					
					Data = New ObjectDeletion(Data.Ref);
					
				EndIf;
				
			ElsIf ItemSend = DataItemSend.Ignore Then
				
				Continue;
				
			EndIf;
			
			// Writing data to the message.
			WriteXML(XMLWriter, Data);
			
			WrittenObjectCount = WrittenObjectCount + 1;
			
			If UseTransactions
				AND TransactionItemsCount > 0
				AND WrittenObjectCount = TransactionItemsCount Then
				
				// Completing the subtransaction and beginning a new one.
				CommitTransaction();
				BeginTransaction();
				
				WrittenObjectCount = 0;
			EndIf;
			
		EndDo;
		
		// Finishing writing the message.
		WriteMessage.EndWrite();
		
		ExchangeMessage = XMLWriter.Close();
		
		If UseTransactions Then
			
			CommitTransaction();
			
		EndIf;
		
	Except
		
		If UseTransactions Then
			
			RollbackTransaction();
			
		EndIf;
		
		WriteMessage.CancelWrite();
		
		XMLWriter.Close();
		
		Cancel = True;
		
		WriteLogEvent(EventLogMessageKey, EventLogLevel.Error,
			InfobaseNode.Metadata(), InfobaseNode, DetailErrorDescription(ErrorInfo()));
		//
		Return;
	EndTry;
	
EndProcedure

// The procedure for reading changes from the exchange message.
// Can be applied if the infobases have the same metadata structure for all objects involved in the exchange.
//
Procedure ExecuteStandardNodeChangeImport(
		InfobaseNode,
		FileName,
		ExchangeMessage,
		TransactionItemsCount,
		EventLogMessageKey,
		ProcessedObjectsCount,
		ExchangeExecutionResult)
		
	If IsBlankString(EventLogMessageKey) Then
		EventLogMessageKey = EventLogMessageTextDataExchange();
	EndIf;
	
	ExchangePlanManager = DataExchangeCached.GetExchangePlanManager(InfobaseNode);
	
	Try
		XMLReader = New XMLReader;
		
		If Not IsBlankString(ExchangeMessage) Then
			XMLReader.SetString(ExchangeMessage);
		Else
			XMLReader.OpenFile(FileName);
		EndIf;
		
		MessageReader = ExchangePlans.CreateMessageReader();
		MessageReader.BeginRead(XMLReader, AllowedMessageNo.Greater);
	Except
		
		ErrorInformation = ErrorInfo();
		
		If IsErrorMessageNumberLessOrEqualToPreviouslyAcceptedMessageNumber(BriefErrorDescription(ErrorInformation)) Then
			
			ExchangeExecutionResult = Enums.ExchangeExecutionResults.Warning_ExchangeMessageAlreadyAccepted;
			
			WriteLogEvent(EventLogMessageKey, EventLogLevel.Warning,
				InfobaseNode.Metadata(), InfobaseNode, BriefErrorDescription(ErrorInformation));
			//
		Else
			
			ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
			
			WriteLogEvent(EventLogMessageKey, EventLogLevel.Error,
				InfobaseNode.Metadata(), InfobaseNode, DetailErrorDescription(ErrorInformation));
			//
		EndIf;
		
		Return;
	EndTry;
	
	If MessageReader.Sender <> InfobaseNode Then // The message is not intended for this node.
		
		ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
		
		WriteLogEvent(EventLogMessageKey, EventLogLevel.Error,
			InfobaseNode.Metadata(), InfobaseNode, NStr("ru = 'Š”Š¾Š¾Š±ŃŠµŠ½ŠøŠµ Š¾Š±Š¼ŠµŠ½Š° ŃŠ¾Š“ŠµŃŠ¶ŠøŃ Š“Š°Š½Š½ŃŠµ Š“Š»Ń Š“ŃŃŠ³Š¾Š³Š¾ ŃŠ·Š»Š° ŠøŠ½ŃŠ¾ŃŠ¼Š°ŃŠøŠ¾Š½Š½Š¾Š¹ Š±Š°Š·Ń.'; en = 'Exchange message contains data for another infobase node.'; pl = 'Komunikat wymiany zawiera dane dla innego wÄzÅa bazy informacyjnej.';es_ES = 'El mensaje de intercambio contiene datos para el nodo de otra infobase.';es_CO = 'El mensaje de intercambio contiene datos para el nodo de otra infobase.';tr = 'DeÄiÅim mesajÄ± baÅka bir veritabanÄ± Ć¼nitesi iĆ§in veri iĆ§erir.';it = 'Il messaggio di scambio contiene dati per un altro nodo di infobase.';de = 'Die Austauschnachricht enthĆ¤lt Daten fĆ¼r einen anderen Infobaseknoten.'",
			CommonClientServer.DefaultLanguageCode()));
		//
		Return;
	EndIf;
	
	BackupParameters = BackupParameters(MessageReader.Sender, MessageReader.ReceivedNo);
	
	DeleteChangesRegistration = Not BackupParameters.BackupRestored;
	
	If DeleteChangesRegistration Then
		
		// Deleting changes registration for the sender node.
		ExchangePlans.DeleteChangeRecords(MessageReader.Sender, MessageReader.ReceivedNo);
		
		InformationRegisters.CommonInfobasesNodesSettings.ClearInitialDataExportFlag(MessageReader.Sender, MessageReader.ReceivedNo);
		
	EndIf;
	
	// Counting the number of read objects.
	WrittenObjectCount = 0;
	ProcessedObjectsCount = 0;
	
	UseTransactions = TransactionItemsCount <> 1;
	
	// If transactions are used, beginning a new one.
	
	DataExchangeInternal.DisableAccessKeysUpdate(True, Not BackupParameters.BackupRestored);
	If UseTransactions Then
		BeginTransaction();
	EndIf;
	Try
		
		// Reading data from the message.
		While CanReadXML(XMLReader) Do
			
			// Reading the next value.
			Data = ReadXML(XMLReader);
			
			GetItem = DataItemReceive.Auto;
			SendBack = False;
			
			StandardSubsystemsServer.OnReceiveDataFromMaster(Data,
				GetItem, SendBack, MessageReader.Sender.GetObject());
			
			If GetItem = DataItemReceive.Ignore Then
				Continue;
			EndIf;
				
			IsObjectDeletion = (TypeOf(Data) = Type("ObjectDeletion"));
			
			ProcessedObjectsCount = ProcessedObjectsCount + 1;
			
			If Not SendBack Then
				Data.DataExchange.Sender = MessageReader.Sender;
			EndIf;
			
			Data.DataExchange.Load = True;
			
			// Overriding standard system behavior on getting object deletion.
			// Setting deletion mark instead of deleting objects without checking reference integrity.
			// 
			If IsObjectDeletion Then
				
				ObjectDeletion = Data;
				
				Data = Data.Ref.GetObject();
				
				If Data = Undefined Then
					
					Continue;
					
				EndIf;
				
				If Not SendBack Then
					Data.DataExchange.Sender = MessageReader.Sender;
				EndIf;
				
				Data.DataExchange.Load = True;
				
				Data.DeletionMark = True;
				
				If Common.IsDocument(Data.Metadata()) Then
					
					Data.Posted = False;
					
				EndIf;
				
			EndIf;
			
			If IsObjectDeletion Then
				
				Data = ObjectDeletion;
				
			EndIf;
			
			// Attempting to write the object.
			Try
				Data.Write();
			Except
				
				ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
				
				ErrorDescription = DetailErrorDescription(ErrorInfo());
				
				WriteLogEvent(EventLogMessageKey, EventLogLevel.Error,
					Data.Metadata(), String(Data), ErrorDescription);
				//
				Break;
			EndTry;
			
			WrittenObjectCount = WrittenObjectCount + 1;
			
			If UseTransactions
				AND TransactionItemsCount > 0
				AND WrittenObjectCount = TransactionItemsCount Then
				
				// Completing the subtransaction and beginning a new one.
				CommitTransaction();
				BeginTransaction();
				
				WrittenObjectCount = 0;
			EndIf;
			
		EndDo;
		
		If ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error Then
			Raise(NStr("ru = 'Š ŠæŃŠ¾ŃŠµŃŃŠµ ŠæŠ¾Š»ŃŃŠµŠ½ŠøŃ Š“Š°Š½Š½ŃŃ Š²Š¾Š·Š½ŠøŠŗŠ»Šø Š¾ŃŠøŠ±ŠŗŠø.'; en = 'Errors occurred when receiving data.'; pl = 'W procesie pobierania danych wystÄpiÅy bÅÄdy.';es_ES = 'Al recibir los datos se han producido errores.';es_CO = 'Al recibir los datos se han producido errores.';tr = 'Veriler alÄ±nÄ±rken hatalar oluÅtu.';it = 'Si ĆØ verificato un errore durante la ricezione dati.';de = 'Beim Abrufen der Daten sind Fehler aufgetreten.'"));
		EndIf;
		
		DataExchangeInternal.DisableAccessKeysUpdate(False, Not BackupParameters.BackupRestored);
		If UseTransactions Then
			CommitTransaction();
		EndIf;
	Except
		If UseTransactions Then
			RollbackTransaction();
			DataExchangeInternal.DisableAccessKeysUpdate(False, False);
		Else
			DataExchangeInternal.DisableAccessKeysUpdate(False, Not BackupParameters.BackupRestored);
		EndIf;
		ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
		WriteLogEvent(EventLogMessageKey, EventLogLevel.Error,
			InfobaseNode.Metadata(), InfobaseNode, DetailErrorDescription(ErrorInfo()));
			
	EndTry;
	
	If ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error Then
		MessageReader.CancelRead();
	Else
		MessageReader.EndRead();
		OnRestoreFromBackup(BackupParameters);
	EndIf;
	
	XMLReader.Close();
	
EndProcedure

#EndRegion

#Region PropertyFunctions

Function FileOfDeferredUpdateDataFullName()
	
	Return GetTempFileName(".xml");
	
EndFunction

// Returns the name of exchange message file by sender node and recipient node data.
//
Function ExchangeMessageFileName(SenderNodeCode, RecipientNodeCode, IsOutgoingMessage)
	
	NamePattern = "[Prefix]_[SenderNode]_[RecipientNode]";
	If StrLen(SenderNodeCode) = 36 AND IsOutgoingMessage Then
		SourceIBPrefix = Constants.DistributedInfobaseNodePrefix.Get();
		If ValueIsFilled(SourceIBPrefix) Then
			NamePattern = "[Prefix]_[SourceIBPrefix]_[SenderNode]_[RecipientNode]";
		EndIf;
	EndIf;
	NamePattern = StrReplace(NamePattern, "[Prefix]",         "Message");
	NamePattern = StrReplace(NamePattern, "[SourceIBPrefix]",SourceIBPrefix);
	NamePattern = StrReplace(NamePattern, "[SenderNode]", SenderNodeCode);
	NamePattern = StrReplace(NamePattern, "[RecipientNode]",  RecipientNodeCode);
	
	Return NamePattern;
EndFunction

// Returns the name of temporary directory for data exchange messages.
// The directory name is written in the following way:
// Exchange82 {GUID}, where GUID is a UUID string.
// 
//
// Parameters:
//  No.
// 
// Returns:
//  String - Ā a name of temporary directory for data exchange messages.
//
Function TempExchangeMessageCatalogName()
	
	Return StrReplace("Exchange82 {GUID}", "GUID", Upper(String(New UUID)));
	
EndFunction

// Returns the name of exchange message transport data processor.
//
// Parameters:
//  TransportKind - EnumRef.ExchangeMessageTransportKinds - a transport kind to get a data processor 
//                                                                     name for.
// 
//  Returns:
//  String - a name of exchange message transport data processor.
//
Function DataExchangeMessageTransportDataProcessorName(TransportKind)
	
	Return StrReplace("ExchangeMessageTransport[TransportKind]", "[TransportKind]", Common.EnumValueName(TransportKind));
	
EndFunction

// The DataExchangeClient.MaxObjectMappingFieldsCount() procedure duplicate at server.
//
Function MaxCountOfObjectsMappingFields() Export
	
	Return 5;
	
EndFunction

// Determines whether the exchange plan is in the list of exchange plans that use XDTO data exchange.
//
// Parameters:
//  ExchangePlan - a reference to the exchange plan node or the exchange plan name.
//
// Returns: Boolean.
//
Function IsXDTOExchangePlan(ExchangePlan) Export
	Return DataExchangeCached.IsXDTOExchangePlan(ExchangePlan);
EndFunction

// Returns the unlimited length string literal.
//
// Returns:
//  String - an unlimited length string literal.
//
Function UnlimitedLengthString() Export
	
	Return "(string of unlimited length)";
	
EndFunction

// Function for retrieving property: returns literal of the XML node that contains the ORR constant value.
//
// Returns:
//  String literal of the XML node that contains the ORR constant value.
//
Function FilterItemPropertyConstantValue() Export
	
	Return "ConstantValue";
	
EndFunction

// Function for retrieving property: returns literal of the XML node that contains the value getting algorithm.
//
// Returns:
//  String - returns an XML node literal that contains the value getting algorithm.
//
Function FilterItemPropertyValueAlgorithm() Export
	
	Return "ValueAlgorithm";
	
EndFunction

// Function for retrieving property: returns a name of the file that is used for checking whether transport data processor is attached.
//
// Returns:
//  String - returns a name of the file that is used for checking whether transport data processor is attached.
//
Function TempConnectionTestFileName() Export
	FilePostfix = String(New UUID());
	Return "ConnectionCheckFile_" + FilePostfix + ".tmp";
	
EndFunction

Function IsErrorMessageNumberLessOrEqualToPreviouslyAcceptedMessageNumber(ErrorDescription)
	
	Return StrFind(Lower(ErrorDescription), Lower("ru = 'Number messages less than or equal'")) > 0;
	
EndFunction

Function EventLogEventEstablishWebServiceConnection() Export
	
	Return NStr("ru = 'ŠŠ±Š¼ŠµŠ½ Š“Š°Š½Š½ŃŠ¼Šø.Š£ŃŃŠ°Š½Š¾Š²ŠŗŠ° ŠæŠ¾Š“ŠŗŠ»ŃŃŠµŠ½ŠøŃ Šŗ web-ŃŠµŃŠ²ŠøŃŃ'; en = 'Data exchange.Establishing connection to web service.'; pl = 'Wymiana danych. PoÅÄczenie z usÅugÄ sieciowÄ';es_ES = 'Intercambio de datos.Conectando al servicio web';es_CO = 'Intercambio de datos.Conectando al servicio web';tr = 'Veri alÄ±ÅveriÅi. Web servisine baÄlanma';it = 'Scambio dati. Connessione al servizio web in corso.';de = 'Datenaustausch. Verbindung mit dem Webservice'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

Function DataExchangeRuleImportEventLogEvent() Export
	
	Return NStr("ru = 'ŠŠ±Š¼ŠµŠ½ Š“Š°Š½Š½ŃŠ¼Šø.ŠŠ°Š³ŃŃŠ·ŠŗŠ° ŠæŃŠ°Š²ŠøŠ»'; en = 'Data exchange.Importing rules'; pl = 'Wymiana danych. Import reguÅ';es_ES = 'Intercambio de datos.ImportaciĆ³n de la regla';es_CO = 'Intercambio de datos.ImportaciĆ³n de la regla';tr = 'Veri deÄiÅimi. KuralÄ± iĆ§e aktarma';it = 'Scambio dati.Regole di importazione';de = 'Datenaustausch. Regelimport'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

Function DataExchangeCreationEventLogMessageText() Export
	
	Return NStr("ru = 'ŠŠ±Š¼ŠµŠ½ Š“Š°Š½Š½ŃŠ¼Šø.Š”Š¾Š·Š“Š°Š½ŠøŠµ Š¾Š±Š¼ŠµŠ½Š° Š“Š°Š½Š½ŃŠ¼Šø'; en = 'Data exchange.Creating data exchange.'; pl = 'Wymiana danych. Utworzenie wymiany danych';es_ES = 'Intercambio de datos.Creando el intercambio de datos';es_CO = 'Intercambio de datos.Creando el intercambio de datos';tr = 'Veri deÄiÅimi. Veri deÄiÅimin oluÅturulmasÄ±';it = 'Scambio dati.Creazione scambio dati.';de = 'Datenaustausch. Datenaustausch erstellen'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

Function DataExchangeDeletionEventLogEvent() Export
	
	Return NStr("ru = 'ŠŠ±Š¼ŠµŠ½ Š“Š°Š½Š½ŃŠ¼Šø.Š£Š“Š°Š»ŠµŠ½ŠøŠµ Š¾Š±Š¼ŠµŠ½Š° Š“Š°Š½Š½ŃŠ¼Šø'; en = 'Data exchange.Data exchange deletion'; pl = 'Wymiana danych.UsuniÄcie wymiany danych';es_ES = 'Intercambio de datos.Eliminar intercambio de datos';es_CO = 'Intercambio de datos.Eliminar intercambio de datos';tr = 'Veri alÄ±ÅveriÅi. Veri alÄ±ÅveriÅin kaldÄ±rÄ±lmasÄ±';it = 'Scambio dati.Eliminazione scambio dati';de = 'Datenaustausch.Datenaustausch lĆ¶schen'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

Function RegisterDataForInitialExportEventLogEvent() Export
	
	Return NStr("ru = 'ŠŠ±Š¼ŠµŠ½ Š“Š°Š½Š½ŃŠ¼Šø.Š ŠµŠ³ŠøŃŃŃŠ°ŃŠøŃ Š“Š°Š½Š½ŃŃ Š“Š»Ń Š½Š°ŃŠ°Š»ŃŠ½Š¾Š¹ Š²ŃŠ³ŃŃŠ·ŠŗŠø'; en = 'Data exchange.Data registration for initial export'; pl = 'Wymiana danych.Rejestracja danych do wysÅania poczÄtkowego';es_ES = 'Intercambio de datos.Registro de datos para subida inicial';es_CO = 'Intercambio de datos.Registro de datos para subida inicial';tr = 'Veri alÄ±ÅveriÅi. Ä°lk dÄ±Åa aktarma iĆ§in veri kaydÄ±';it = 'Scambio dati.Registrazione dati per esportazione iniziale';de = 'Datenaustausch.Daten fĆ¼r den erstmaligen Upload registrieren'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

Function DataImportToMapEventLogEvent() Export
	
	Return NStr("ru = 'ŠŠ±Š¼ŠµŠ½ Š“Š°Š½Š½ŃŠ¼Šø.ŠŃŠ³ŃŃŠ·ŠŗŠ° Š“Š°Š½Š½ŃŃ Š“Š»Ń ŃŠ¾ŠæŠ¾ŃŃŠ°Š²Š»ŠµŠ½ŠøŃ'; en = 'Data exchange.Data export for mapping'; pl = 'Wymiana danych.Pobieranie danych do porĆ³wnania';es_ES = 'Intercambio de datos.Subida de datos para comparar';es_CO = 'Intercambio de datos.Subida de datos para comparar';tr = 'Veri alÄ±ÅveriÅi. KarÅÄ±laÅtÄ±rÄ±lacak verilerin dÄ±Åa aktarÄ±mÄ±';it = 'Scambio dati.Esportazione dati per mappatura';de = 'Datenaustausch.Daten zu Mapping exportiert'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

Function TempFileDeletionEventLogMessageText() Export
	
	Return NStr("ru = 'ŠŠ±Š¼ŠµŠ½ Š“Š°Š½Š½ŃŠ¼Šø.Š£Š“Š°Š»ŠµŠ½ŠøŠµ Š²ŃŠµŠ¼ŠµŠ½Š½Š¾Š³Š¾ ŃŠ°Š¹Š»Š°'; en = 'Data exchange.Deletion of temporary file'; pl = 'Wymiana danych. UsuniÄcie pliku tymczasowego';es_ES = 'Intercambio de datos.Eliminando el archivo temporal';es_CO = 'Intercambio de datos.Eliminando el archivo temporal';tr = 'Veri deÄiÅimi. GeĆ§ici dosyayÄ± kaldÄ±rma';it = 'Scambio dati.Eliminazione file temporaneo';de = 'Datenaustausch.Entfernen der temporĆ¤ren Datei'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

Function EventLogMessageTextDataExchange() Export
	
	Return NStr("ru = 'ŠŠ±Š¼ŠµŠ½ Š“Š°Š½Š½ŃŠ¼Šø'; en = 'Data exchange'; pl = 'Wymiana danych';es_ES = 'Intercambio de datos';es_CO = 'Intercambio de datos';tr = 'Veri deÄiÅimi';it = 'Scambio dati';de = 'Datenaustausch'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

Function EventLogEventExportDataToFilesTransferService() Export
	
	Return NStr("ru = 'ŠŠ±Š¼ŠµŠ½ Š“Š°Š½Š½ŃŠ¼Šø.Š”ŠµŃŠ²ŠøŃ ŠæŠµŃŠµŠ“Š°ŃŠø ŃŠ°Š¹Š»Š¾Š².ŠŃŠ³ŃŃŠ·ŠŗŠ° Š“Š°Š½Š½ŃŃ'; en = 'Data exchange.File transfer service.Data export'; pl = 'Wymiana danych.Serwis przekazania plikĆ³w.WysÅanie danych';es_ES = 'Intercambio de datos.Servicio de pasar los archivos.Subida de datos';es_CO = 'Intercambio de datos.Servicio de pasar los archivos.Subida de datos';tr = 'Veri alÄ±ÅveriÅi. Dosya transfer hizmetleri. Veri dÄ±Åa aktarma';it = 'Scambio dati.Servizio di trasferimento file.Esportazione dati';de = 'Datenaustausch.DateiĆ¼bertragungsservice.Daten exportieren'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

Function ExportDataFromFileTransferServiceEventLogEvent() Export
	
	Return NStr("ru = 'ŠŠ±Š¼ŠµŠ½ Š“Š°Š½Š½ŃŠ¼Šø.Š”ŠµŃŠ²ŠøŃ ŠæŠµŃŠµŠ“Š°ŃŠø ŃŠ°Š¹Š»Š¾Š².ŠŠ°Š³ŃŃŠ·ŠŗŠ° Š“Š°Š½Š½ŃŃ'; en = 'Data exchange.Files transfer service.Import data'; pl = 'Wymiana danych.Serwis przekazania plikĆ³w.Pobieranie danych';es_ES = 'Intercambio de datos.Servicio de pasar los archivos.Descarga de datos';es_CO = 'Intercambio de datos.Servicio de pasar los archivos.Descarga de datos';tr = 'Veri alÄ±ÅveriÅi. Dosya transfer hizmetleri. Veri iĆ§e aktarma';it = 'Scambio dati.Servizio di trasferimento file.Importare dati';de = 'Datenaustausch.DateiĆ¼bertragungsservice.Daten importieren'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

#EndRegion

#Region ExchangeMessageTransport

Procedure ExecuteExchangeMessageTransportBeforeProcessing(ExchangeSettingsStructure)
	
	// Getting the initialized message transport data processor.
	ExchangeMessageTransportDataProcessor = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor;
	
	// Getting a new temporary file name.
	If Not ExchangeMessageTransportDataProcessor.ExecuteActionsBeforeProcessMessage() Then
		
		WriteEventLogDataExchange(ExchangeMessageTransportDataProcessor.ErrorMessageStringEL, ExchangeSettingsStructure, True);
		
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error_MessageTransport;
		
	EndIf;
	
EndProcedure

Procedure ExecuteExchangeMessageTransportSending(ExchangeSettingsStructure)
	
	// Getting the initialized message transport data processor.
	ExchangeMessageTransportDataProcessor = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor;
	
	// Sending the exchange message from the temporary directory.
	If Not ExchangeMessageTransportDataProcessor.ConnectionIsSet()
		Or Not ExchangeMessageTransportDataProcessor.SendMessage() Then
		
		WriteEventLogDataExchange(ExchangeMessageTransportDataProcessor.ErrorMessageStringEL, ExchangeSettingsStructure, True);
		
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error_MessageTransport;
		
	EndIf;
	
EndProcedure

Procedure ExecuteExchangeMessageTransportReceiving(ExchangeSettingsStructure, UseAlias = True, ErrorsStack = Undefined)
	
	If ErrorsStack = Undefined Then
		ErrorsStack = New Array;
	EndIf;
	
	// Getting the initialized message transport data processor.
	ExchangeMessageTransportDataProcessor = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor;
	
	// Getting exchange message to a temporary directory.
	If Not ExchangeMessageTransportDataProcessor.ConnectionIsSet()
		Or Not ExchangeMessageTransportDataProcessor.GetMessage() Then
		
		ErrorsStack.Add(ExchangeMessageTransportDataProcessor.ErrorMessageStringEL);
		
		If Not UseAlias Then
			// There will be no more attempts to search the file. Registering all accumulated errors.
			For Each CurrentError In ErrorsStack Do
				WriteEventLogDataExchange(CurrentError, ExchangeSettingsStructure, True);
			EndDo;
		EndIf;
		
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error_MessageTransport;
		
	EndIf;
	
	If UseAlias
		AND ExchangeSettingsStructure.ExchangeExecutionResult <> Undefined Then
		// Probably the file can be received if you apply the virtual code (alias) of the node.
		
		Transliteration = Undefined;
		If ExchangeSettingsStructure.ExchangeTransportKind = Enums.ExchangeMessagesTransportTypes.FILE Then
			ExchangeSettingsStructure.TransportSettings.Property("FILETransliterateExchangeMessageFileNames", Transliteration);
		ElsIf ExchangeSettingsStructure.ExchangeTransportKind = Enums.ExchangeMessagesTransportTypes.EMAIL Then
			ExchangeSettingsStructure.TransportSettings.Property("EMAILTransliterateExchangeMessageFileNames", Transliteration);
		ElsIf ExchangeSettingsStructure.ExchangeTransportKind = Enums.ExchangeMessagesTransportTypes.FTP Then
			ExchangeSettingsStructure.TransportSettings.Property("FTPTransliterateExchangeMessageFileNames", Transliteration);
		EndIf;
		Transliteration = ?(Transliteration = Undefined, False, Transliteration);
		
		FileNameTemplatePrevious = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.MessageFileNamePattern;
		ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.MessageFileNamePattern = MessageFileNamePattern(
				ExchangeSettingsStructure.CurrentExchangePlanNode,
				ExchangeSettingsStructure.InfobaseNode,
				False,
				Transliteration, 
				True);
		If FileNameTemplatePrevious <> ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.MessageFileNamePattern Then
			// Retrying the transport with a new template.
			ExchangeSettingsStructure.ExchangeExecutionResult = Undefined;
			ExecuteExchangeMessageTransportReceiving(ExchangeSettingsStructure, False, ErrorsStack);
		Else
			// There will be no more attempts to search the file. Registering all accumulated errors.
			For Each CurrentError In ErrorsStack Do
				WriteEventLogDataExchange(CurrentError, ExchangeSettingsStructure, True);
			EndDo;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure ExecuteExchangeMessageTransportAfterProcessing(ExchangeSettingsStructure)
	
	// Getting the initialized message transport data processor.
	ExchangeMessageTransportDataProcessor = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor;
	
	// Performing actions after sending the message.
	ExchangeMessageTransportDataProcessor.ExecuteActionsAfterProcessMessage();
	
EndProcedure

// Gets proxy server settings.
//
Function ProxyServerSettings(SecureConnection)
	
	Proxy = Undefined;
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownloadClientServer = Common.CommonModule("GetFilesFromInternetClientServer");
		Protocol = ?(SecureConnection = Undefined, "ftp", "ftps");
		Proxy = ModuleNetworkDownloadClientServer.GetProxy(Protocol);
	EndIf;
	
	Return Proxy;
	
EndFunction
#EndRegion

#Region FileTransferService

// The function downloads the file from the file transfer service by the passed ID.
//
// Parameters:
//  FileID       - UUID - ID ŃŠ° the file being received.
//  SaaSAccessParameters - Structure: ServiceAddress, Username, UserPassword.
//  PartSize              - Number - part size in kilobytes. If the passed value is 0, the file is 
//                             not split into parts.
// Returns:
//  String - received file path.
//
Function GetFileFromStorageInService(Val FileID, Val InfobaseNode, Val PartSize = 1024, Val AuthenticationParameters = Undefined) Export
	
	// Function return value.
	ResultFileName = "";
	
	Proxy = WSProxyForInfobaseNode(InfobaseNode, , AuthenticationParameters);
	
	SessionID = Undefined;
	PartCount    = Undefined;
	
	Proxy.PrepareGetFile(FileID, PartSize, SessionID, PartCount);
	
	FileNames = New Array;
	
	BuildDirectory = GetTempFileName();
	CreateDirectory(BuildDirectory);
	
	FileNameTemplate = "data.zip.[n]";
	
	// Logging exchange events.
	ExchangeSettingsStructure = New Structure("EventLogMessageKey");
	ExchangeSettingsStructure.EventLogMessageKey = EventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
	
	Comment = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'ŠŠ°ŃŠ°Š»Š¾ ŠæŠ¾Š»ŃŃŠµŠ½ŠøŃ ŃŠ¾Š¾Š±ŃŠµŠ½ŠøŃ Š¾Š±Š¼ŠµŠ½Š° ŠøŠ· ŠŠ½ŃŠµŃŠ½ŠµŃŠ° (ŠŗŠ¾Š»ŠøŃŠµŃŃŠ²Š¾ ŃŠ°ŃŃŠµŠ¹ ŃŠ°Š¹Š»Š° %1).'; en = 'Start receiving the exchange message from the Internet (file part number is %1).'; pl = 'PoczÄtek odbierania wiadomoÅci wymiany internetowej (iloÅÄ czÄÅci pliku: %1).';es_ES = 'Inicio de la recepciĆ³n del mensaje de intercambio de Internet (nĆŗmero de las partes del archivo es %1).';es_CO = 'Inicio de la recepciĆ³n del mensaje de intercambio de Internet (nĆŗmero de las partes del archivo es %1).';tr = 'Ä°nternet deÄiÅim mesajÄ±nÄ±n alÄ±nmaya baÅlamasÄ± (dosya parĆ§alarÄ±nÄ±n sayÄ±sÄ±%1).';it = 'Avviare la ricezione del messaggio di scambio da internet (numero parte file %1).';de = 'Start des Internet Austausch Nachrichtenempfangs (Anzahl der Dateiteile ist %1).'"),
		Format(PartCount, "NZ=0; NG=0"));
	WriteEventLogDataExchange(Comment, ExchangeSettingsStructure);
	
	For PartNumber = 1 To PartCount Do
		PartData = Undefined;
		Try
			Proxy.GetFilePart(SessionID, PartNumber, PartData);
		Except
			Proxy.ReleaseFile(SessionID);
			Raise;
		EndTry;
		
		FileName = StrReplace(FileNameTemplate, "[n]", Format(PartNumber, "NG=0"));
		FileNamePart = CommonClientServer.GetFullFileName(BuildDirectory, FileName);
		
		PartData.Write(FileNamePart);
		FileNames.Add(FileNamePart);
	EndDo;
	PartData = Undefined;
	
	Proxy.ReleaseFile(SessionID);
	
	ArchiveName = CommonClientServer.GetFullFileName(BuildDirectory, "data.zip");
	
	MergeFiles(FileNames, ArchiveName);
	
	Dearchiver = New ZipFileReader(ArchiveName);
	If Dearchiver.Items.Count() = 0 Then
		Try
			DeleteFiles(BuildDirectory);
		Except
			WriteLogEvent(TempFileDeletionEventLogMessageText(),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;
		Raise(NStr("ru = 'Š¤Š°Š¹Š» Š°ŃŃŠøŠ²Š° Š½Šµ ŃŠ¾Š“ŠµŃŠ¶ŠøŃ Š“Š°Š½Š½ŃŃ.'; en = 'The archive file does not contain data.'; pl = 'Plik archiwum nie zawiera danych.';es_ES = 'Documento del archivo no contiene datos.';es_CO = 'Documento del archivo no contiene datos.';tr = 'ArÅiv dosyasÄ± veri iĆ§ermemektedir.';it = 'Il file archivio non contiene dati.';de = 'Die Archivdatei enthĆ¤lt keine Daten.'"));
	EndIf;
	
	// Logging exchange events.
	ArchiveFile = New File(ArchiveName);
	
	Comment = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'ŠŠŗŠ¾Š½ŃŠ°Š½ŠøŠµ ŠæŠ¾Š»ŃŃŠµŠ½ŠøŃ ŃŠ¾Š¾Š±ŃŠµŠ½ŠøŃ Š¾Š±Š¼ŠµŠ½Š° ŠøŠ· ŠŠ½ŃŠµŃŠ½ŠµŃŠ° (ŃŠ°Š·Š¼ŠµŃ ŃŠ¶Š°ŃŠ¾Š³Š¾ ŃŠ¾Š¾Š±ŃŠµŠ½ŠøŃ Š¾Š±Š¼ŠµŠ½Š° %1 ŠŠ±).'; en = 'Finish receiving the exchange message from the Internet (compressed message size is %1 MB).'; pl = 'ZakoÅczenie odbioru wiadomoÅci wymiany z Internetu (rozmiar skompresowanej wiadomoÅci wymiany:%1 MB).';es_ES = 'Fin de la recepciĆ³n del mensaje de intercambio de Internet (tamaĆ±o de un mensaje de intercambio comprimido es %1 MB).';es_CO = 'Fin de la recepciĆ³n del mensaje de intercambio de Internet (tamaĆ±o de un mensaje de intercambio comprimido es %1 MB).';tr = 'Ä°nternetten alÄ±nan deÄiÅim mesajÄ±nÄ±n sonu (sÄ±kÄ±ÅtÄ±rÄ±lmÄ±Å bir deÄiÅim mesajÄ±nÄ±n boyutu %1MB''dir).';it = 'Concludere la ricezione del messaggio di scambio da internet (dimensione messaggio compresso %1 MB).';de = 'Ende der Austauschnachricht, die aus dem Internet empfangen wird (die GrĆ¶Će einer komprimierten Austauschnachricht ist %1 MB).'"),
		Format(Round(ArchiveFile.Size() / 1024 / 1024, 3), "NZ=0; NG=0"));
	WriteEventLogDataExchange(Comment, ExchangeSettingsStructure);
	
	FileName = CommonClientServer.GetFullFileName(BuildDirectory, Dearchiver.Items[0].Name);
	
	Dearchiver.Extract(Dearchiver.Items[0], BuildDirectory);
	Dearchiver.Close();
	
	File = New File(FileName);
	
	TemporaryDirectory = GetTempFileName();
	CreateDirectory(TemporaryDirectory);
	
	ResultFileName = CommonClientServer.GetFullFileName(TemporaryDirectory, File.Name);
	
	MoveFile(FileName, ResultFileName);
	
	Try
		DeleteFiles(BuildDirectory);
	Except
		WriteLogEvent(TempFileDeletionEventLogMessageText(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
		
	Return ResultFileName;
EndFunction

// Passes the specified file to the file transfer service.
//
// Parameters:
//  FileName                 - String - path to the file being passed.
//  SaaSAccessParameters - Structure: ServiceAddress, Username, UserPassword.
//  PartSize              - Number - part size in kilobytes. If the passed value is 0, the file is 
//                             not split into parts.
// Returns:
//  UUID  - a file ID in the file transfer service.
//
Function PutFileInStorageInService(Val FileName, Val InfobaseNode, Val PartSize = 1024, Val AuthenticationParameters = Undefined)
	
	// Function return value.
	FileID = Undefined;
	
	Proxy = WSProxyForInfobaseNode(InfobaseNode,, AuthenticationParameters);
	
	FileDirectory = GetTempFileName();
	CreateDirectory(FileDirectory);
	
	// Archiving the file.
	SharedFileName = CommonClientServer.GetFullFileName(FileDirectory, "data.zip");
	Archiver = New ZipFileWriter(SharedFileName,,,, ZIPCompressionLevel.Maximum);
	Archiver.Add(FileName);
	Archiver.Write();
	
	// Splitting file into parts.
	SessionID = New UUID;
	
	PartCount = 1;
	If ValueIsFilled(PartSize) Then
		FileNames = SplitFile(SharedFileName, PartSize * 1024);
		PartCount = FileNames.Count();
		For PartNumber = 1 To PartCount Do
			FileNamePart = FileNames[PartNumber - 1];
			FileData = New BinaryData(FileNamePart);
			Proxy.PutFilePart(SessionID, PartNumber, FileData);
		EndDo;
	Else
		FileData = New BinaryData(SharedFileName);
		Proxy.PutFilePart(SessionID, 1, FileData);
	EndIf;
	
	Try
		DeleteFiles(FileDirectory);
	Except
		WriteLogEvent(TempFileDeletionEventLogMessageText(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Proxy.SaveFileFromParts(SessionID, PartCount, FileID);
	
	Return FileID;
	
EndFunction

// Getting file by its ID.
//
// Parameters:
//	FileID - UUID - an ID of the file being received.
//
// Returns:
//  FileName āĀ String ā a file name.
//
Function GetFileFromStorage(Val FileID) Export
	
	FileName = "";
	
	If Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable() Then
		
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnReceiveFileFromStorage(FileID, FileName);
		
	Else
		
		OnReceiveFileFromStorage(FileID, FileName);
		
	EndIf;
	
	Return CommonClientServer.GetFullFileName(TempFilesStorageDirectory(), FileName);
	
EndFunction

// Saving file.
//
// Parameters:
//  FileName               - String - a file name.
//  FileID     - UUID - a file ID. If the ID is specified, it is used on saving the file. Otherwise, 
//                           a new value is generated.
//
// Returns:
//  UUID - a file ID.
//
Function PutFileInStorage(Val FileName, Val FileID = Undefined) Export
	
	FileID = ?(FileID = Undefined, New UUID, FileID);
	
	File = New File(FileName);
	
	RecordStructure = New Structure;
	RecordStructure.Insert("MessageID", String(FileID));
	RecordStructure.Insert("MessageFileName", File.Name);
	RecordStructure.Insert("MessageStoredDate", CurrentUniversalDate());
	
	If Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable() Then
		
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnPutFileToStorage(RecordStructure);
	Else
		
		OnPutFileToStorage(RecordStructure);
		
	EndIf;
	
	Return FileID;
	
EndFunction

// Gets a file from the storage by the file ID.
// If a file with the specified ID is not found, an exception is thrown.
// If the file is found, its name is returned, and the information about the file is deleted from the storage.
//
// Parameters:
//	FileID  - UUID - ID of the file being received.
//	FileName            - String - a name of a file from the storage.
//
Procedure OnReceiveFileFromStorage(Val FileID, FileName)
	
	QueryText =
	"SELECT
	|	DataExchangeMessages.MessageFileName AS FileName
	|FROM
	|	InformationRegister.DataExchangeMessages AS DataExchangeMessages
	|WHERE
	|	DataExchangeMessages.MessageID = &MessageID";
	
	Query = New Query;
	Query.SetParameter("MessageID", String(FileID));
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Details = NStr("ru = 'Š¤Š°Š¹Š» Ń ŠøŠ“ŠµŠ½ŃŠøŃŠøŠŗŠ°ŃŠ¾ŃŠ¾Š¼ %1 Š½Šµ Š¾Š±Š½Š°ŃŃŠ¶ŠµŠ½.'; en = 'The file with the %1 ID is not found.'; pl = 'Nie znaleziono pliku z identyfikatorem %1.';es_ES = 'Un archivo con el identificador %1 no encontrado.';es_CO = 'Un archivo con el identificador %1 no encontrado.';tr = '%1 kimlikli dosya bulunamadÄ±.';it = 'File con ID %1 non trovato.';de = 'Eine Datei mit ID %1 wurde nicht gefunden.'");
		Raise StringFunctionsClientServer.SubstituteParametersToString(Details, String(FileID));
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	FileName = Selection.FileName;
	
	// Deleting information about message file from the storage.
	RecordStructure = New Structure;
	RecordStructure.Insert("MessageID", String(FileID));
	InformationRegisters.DataExchangeMessages.DeleteRecord(RecordStructure);
	
EndProcedure

// Stores a file to a storage.
//
Procedure OnPutFileToStorage(Val RecordStructure)
	
	InformationRegisters.DataExchangeMessages.AddRecord(RecordStructure);
	
EndProcedure

#EndRegion

#Region InitialDataExportChangesRegistration

// Registers changes for initial data export considering export start date and the list of companies.
// The procedure is universal and can be used for registering data changes by export start date and 
// the list of companies for object data types and register record sets.
// If the list of companies is not specified (Companies = Undefined), changes are registered only by 
// export start date.
// The procedure registers data of all metadata objects included in the exchange plan.
// The procedure registers data unconditionally in the following cases:  - the UseAutoRecord flag of 
// the metadata object is set.  - the UseAutoRecord flag is not set and registration rules are not 
// specified.
// If registration rules are specified for the metadata object, changes are registered based on 
// export start date and the list of companies.
// Document changes can be registered based on export start date and the list of companies.
// Business process changes and task changes can be registered based on export start date.
// Register record set changes can be registered based on export start date and the list of companies.
// The procedure can be used as a prototype for developing procedures of changes registration for 
// initial data export.
//
// Parameters:
//
//  Recipient - ExchangePlanRef - an exchange plan node whose changes are to be registered.
//               
//  ExportStartDate - Date - changes made since this date and time are to be registered.
//                Changes are registered for the data located after this date on the time scale.
//               
//  Companies - Array, Undefined - a list of companies data changes are to be registered for.
//                If this parameter is not specified, companies are not taken into account on 
//               changes registration.
//
Procedure RegisterDataByExportStartDateAndCompanies(Val Recipient, ExportStartDate,
	Companies = Undefined,
	Data = Undefined) Export
	
	FilterByCompanies = (Companies <> Undefined);
	FilterByExportStartDate = ValueIsFilled(ExportStartDate);
	
	If Not FilterByCompanies AND Not FilterByExportStartDate Then
		
		If TypeOf(Data) = Type("Array") Then
			
			For Each MetadataObject In Data Do
				
				ExchangePlans.RecordChanges(Recipient, MetadataObject);
				
			EndDo;
			
		Else
			
			ExchangePlans.RecordChanges(Recipient, Data);
			
		EndIf;
		
		Return;
	EndIf;
	
	FilterByExportStartDateAndCompanies = FilterByExportStartDate AND FilterByCompanies;
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(Recipient);
	
	ExchangePlanComposition = Metadata.ExchangePlans[ExchangePlanName].Content;
	
	UseFilterByMetadata = (TypeOf(Data) = Type("Array"));
	
	For Each ExchangePlanCompositionItem In ExchangePlanComposition Do
		
		If UseFilterByMetadata
			AND Data.Find(ExchangePlanCompositionItem.Metadata) = Undefined Then
			
			Continue;
			
		EndIf;
		
		FullObjectName = ExchangePlanCompositionItem.Metadata.FullName();
		
		If ExchangePlanCompositionItem.AutoRecord = AutoChangeRecord.Deny
			AND DataExchangeCached.ObjectRegistrationRulesExist(ExchangePlanName, FullObjectName) Then
			
			If Common.IsDocument(ExchangePlanCompositionItem.Metadata) Then // Documents
				
				If FilterByExportStartDateAndCompanies
					// Registering by date and companies.
					AND ExchangePlanCompositionItem.Metadata.Attributes.Find("Organization") <> Undefined Then
					
					Selection = DocumentsSelectionByExportStartDateAndCompanies(FullObjectName, ExportStartDate, Companies);
					
					While Selection.Next() Do
						
						ExchangePlans.RecordChanges(Recipient, Selection.Ref);
						
					EndDo;
					
					Continue;
					
				Else // Registering by date.
					
					Selection = ObjectsSelectionByExportStartDate(FullObjectName, ExportStartDate);
					
					While Selection.Next() Do
						
						ExchangePlans.RecordChanges(Recipient, Selection.Ref);
						
					EndDo;
					
					Continue;
					
				EndIf;
				
			ElsIf Common.IsBusinessProcess(ExchangePlanCompositionItem.Metadata)
				OR Common.IsTask(ExchangePlanCompositionItem.Metadata) Then // Business processes and Tasks.
				
				// Registering by date.
				Selection = ObjectsSelectionByExportStartDate(FullObjectName, ExportStartDate);
				
				While Selection.Next() Do
					
					ExchangePlans.RecordChanges(Recipient, Selection.Ref);
					
				EndDo;
				
				Continue;
				
			ElsIf Common.IsRegister(ExchangePlanCompositionItem.Metadata) Then // Registers
				
				// Information registers (independent).
				If Common.IsInformationRegister(ExchangePlanCompositionItem.Metadata)
					AND ExchangePlanCompositionItem.Metadata.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
					
					MainFilter = MainInformationRegisterFilter(ExchangePlanCompositionItem.Metadata);
					
					FilterByPeriod     = (MainFilter.Find("Period") <> Undefined);
					FilterByCompany = (MainFilter.Find("Organization") <> Undefined);
					
					// Registering by date and companies.
					If FilterByExportStartDateAndCompanies AND FilterByPeriod AND FilterByCompany Then
						
						Selection = MainInformationRegisterFilterValuesSelectionByExportStartDateAndCompanies(MainFilter, FullObjectName, ExportStartDate, Companies);
						
					ElsIf FilterByExportStartDate AND FilterByPeriod Then // Registering by date.
						
						Selection = MainInformationRegisterFilterValuesSelectionByExportStartDate(MainFilter, FullObjectName, ExportStartDate);
						
					ElsIf FilterByCompanies AND FilterByCompany Then // Registering by companies.
						
						Selection = MainInformationRegisterFilterValuesSelectionByCompanies(MainFilter, FullObjectName, Companies);
						
					Else
						
						Selection = Undefined;
						
					EndIf;
					
					If Selection <> Undefined Then
						
						RecordSet = Common.ObjectManagerByFullName(FullObjectName).CreateRecordSet();
						
						While Selection.Next() Do
							
							For Each DimensionName In MainFilter Do
								
								RecordSet.Filter[DimensionName].Value = Selection[DimensionName];
								RecordSet.Filter[DimensionName].Use = True;
								
							EndDo;
							
							ExchangePlans.RecordChanges(Recipient, RecordSet);
							
						EndDo;
						
						Continue;
						
					EndIf;
					
				Else // Registers (other)
					HasPeriodInRegister = Common.IsAccountingRegister(ExchangePlanCompositionItem.Metadata)
							OR Common.IsAccumulationRegister(ExchangePlanCompositionItem.Metadata)
							OR (Common.IsInformationRegister(ExchangePlanCompositionItem.Metadata)
								AND ExchangePlanCompositionItem.Metadata.InformationRegisterPeriodicity 
									<> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical);
					If FilterByExportStartDateAndCompanies
						AND HasPeriodInRegister
						// Registering by date and companies.
						AND ExchangePlanCompositionItem.Metadata.Dimensions.Find("Organization") <> Undefined Then
						
						Selection = RecordSetsRecordersSelectionByExportStartDateAndCompanies(FullObjectName, ExportStartDate, Companies);
						
						RecordSet = Common.ObjectManagerByFullName(FullObjectName).CreateRecordSet();
						
						While Selection.Next() Do
							
							RecordSet.Filter.Recorder.Value = Selection.Recorder;
							RecordSet.Filter.Recorder.Use = True;
							
							ExchangePlans.RecordChanges(Recipient, RecordSet);
							
						EndDo;
						
						Continue;
						
					// Registering by date.
					ElsIf HasPeriodInRegister Then
						
						Selection = RecordSetsRecordersSelectionByExportStartDate(FullObjectName, ExportStartDate);
						
						RecordSet = Common.ObjectManagerByFullName(FullObjectName).CreateRecordSet();
						
						While Selection.Next() Do
							
							RecordSet.Filter.Recorder.Value = Selection.Recorder;
							RecordSet.Filter.Recorder.Use = True;
							
							ExchangePlans.RecordChanges(Recipient, RecordSet);
							
						EndDo;
						
						Continue;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		ExchangePlans.RecordChanges(Recipient, ExchangePlanCompositionItem.Metadata);
		
	EndDo;
	
EndProcedure

Function DocumentsSelectionByExportStartDateAndCompanies(FullObjectName, ExportStartDate, Companies)
	
	QueryText =
	"SELECT
	|	Table.Ref AS Ref
	|FROM
	|	[FullObjectName] AS Table
	|WHERE
	|	Table.Organization IN(&Companies)
	|	AND Table.Date >= &ExportStartDate";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", ExportStartDate);
	Query.SetParameter("Companies", Companies);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

Function ObjectsSelectionByExportStartDate(FullObjectName, ExportStartDate)
	
	QueryText =
	"SELECT
	|	Table.Ref AS Ref
	|FROM
	|	[FullObjectName] AS Table
	|WHERE
	|	Table.Date >= &ExportStartDate";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", ExportStartDate);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

Function RecordSetsRecordersSelectionByExportStartDateAndCompanies(FullObjectName, ExportStartDate, Companies)
	
	QueryText =
	"SELECT DISTINCT
	|	RegisterTable.Recorder AS Recorder
	|FROM
	|	[FullObjectName] AS RegisterTable
	|WHERE
	|	RegisterTable.Organization IN(&Companies)
	|	AND RegisterTable.Period >= &ExportStartDate";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", ExportStartDate);
	Query.SetParameter("Companies", Companies);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

Function RecordSetsRecordersSelectionByExportStartDate(FullObjectName, ExportStartDate)
	
	QueryText =
	"SELECT DISTINCT
	|	RegisterTable.Recorder AS Recorder
	|FROM
	|	[FullObjectName] AS RegisterTable
	|WHERE
	|	RegisterTable.Period >= &ExportStartDate";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", ExportStartDate);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

Function MainInformationRegisterFilterValuesSelectionByExportStartDateAndCompanies(MainFilter,
	FullObjectName,
	ExportStartDate,
	Companies)
	
	QueryText =
	"SELECT DISTINCT
	|	[Dimensions]
	|FROM
	|	[FullObjectName] AS RegisterTable
	|WHERE
	|	RegisterTable.Organization IN(&Companies)
	|	AND RegisterTable.Period >= &ExportStartDate";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	QueryText = StrReplace(QueryText, "[Dimensions]", StrConcat(MainFilter, ","));
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", ExportStartDate);
	Query.SetParameter("Companies", Companies);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

Function MainInformationRegisterFilterValuesSelectionByExportStartDate(MainFilter, FullObjectName, ExportStartDate)
	
	QueryText =
	"SELECT DISTINCT
	|	[Dimensions]
	|FROM
	|	[FullObjectName] AS RegisterTable
	|WHERE
	|	RegisterTable.Period >= &ExportStartDate";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	QueryText = StrReplace(QueryText, "[Dimensions]", StrConcat(MainFilter, ","));
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", ExportStartDate);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

Function MainInformationRegisterFilterValuesSelectionByCompanies(MainFilter, FullObjectName, Companies)
	
	QueryText =
	"SELECT DISTINCT
	|	[Dimensions]
	|FROM
	|	[FullObjectName] AS RegisterTable
	|WHERE
	|	RegisterTable.Organization IN(&Companies)";
	
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	QueryText = StrReplace(QueryText, "[Dimensions]", StrConcat(MainFilter, ","));
	
	Query = New Query;
	Query.SetParameter("Companies", Companies);
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
EndFunction

Function MainInformationRegisterFilter(MetadataObject)
	
	Result = New Array;
	
	If MetadataObject.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical
		AND MetadataObject.MainFilterOnPeriod Then
		
		Result.Add("Period");
		
	EndIf;
	
	For Each Dimension In MetadataObject.Dimensions Do
		
		If Dimension.MainFilter Then
			
			Result.Add(Dimension.Name);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

#EndRegion

#Region WrappersToOperateWithExchangePlanManagerApplicationInterface

Function NodeFilterStructure(Val ExchangePlanName, Val CorrespondentVersion, SettingID = "") Export
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	SettingOptionDetails = DataExchangeCached.SettingOptionDetails(ExchangePlanName, 
								SettingID, CorrespondentVersion);
	
	Result = Undefined;
	If ValueIsFilled(SettingOptionDetails.Filters) Then
		Result = SettingOptionDetails.Filters;
	EndIf;
	
	If Result = Undefined Then
		Result = New Structure;
	EndIf;
	
	Return Result;
EndFunction

Function NodeDefaultValues(Val ExchangePlanName, Val CorrespondentVersion, FormName = "", SettingID = "") Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	ExchangePlanSettings = DataExchangeCached.ExchangePlanSettings(ExchangePlanName, CorrespondentVersion);
	SettingOptionDetails = DataExchangeCached.SettingOptionDetails(ExchangePlanName, 
								SettingID, CorrespondentVersion);
	FormName = SettingOptionDetails.DefaultValueFormName;
	Result = Undefined;
	If ValueIsFilled(SettingOptionDetails.DefaultValues) Then
		Result = SettingOptionDetails.DefaultValues;
	EndIf;
	
	If Result = Undefined Then
		Result = New Structure;
	EndIf;
	
	Return Result;
	
EndFunction

Function DataTransferRestrictionsDetails(Val ExchangePlanName, Val Setting, Val CorrespondentVersion, 
										SettingID = "") Export
	If NOT HasExchangePlanManagerAlgorithm("DataTransferRestrictionsDetails", ExchangePlanName) Then
		Return "";
	ElsIf IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	Return ExchangePlans[ExchangePlanName].DataTransferRestrictionsDetails(Setting, CorrespondentVersion, SettingID);
	
EndFunction

Function DefaultValueDetails(Val ExchangePlanName, Val Setting, Val CorrespondentVersion, 
									SettingID = "") Export
	If NOT HasExchangePlanManagerAlgorithm("DefaultValueDetails",ExchangePlanName) Then
		Return "";
	ElsIf IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	Return ExchangePlans[ExchangePlanName].DefaultValueDetails(Setting, CorrespondentVersion, SettingID);
	
EndFunction

Function CommonNodeData(Val ExchangePlanName, Val CorrespondentVersion, Val SettingID) Export
	
	If IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	SettingOptionDetails = DataExchangeCached.SettingOptionDetails(ExchangePlanName, 
								SettingID, CorrespondentVersion);
	Result = SettingOptionDetails.CommonNodeData;
	
	Return StrReplace(Result, " ", "");
	
EndFunction

Procedure OnConnectToCorrespondent(Val ExchangePlanName, Val CorrespondentVersion) Export
	If NOT HasExchangePlanManagerAlgorithm("OnConnectToCorrespondent", ExchangePlanName) Then
		Return;
	ElsIf IsBlankString(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;
	
	ExchangePlans[ExchangePlanName].OnConnectToCorrespondent(CorrespondentVersion);
	
EndProcedure

// Fills settings for the exchange plan which are then used by the data exchange subsystem.
// Parameters:
//   ExchangePlanName              - String - an exchange plan name.
//   CorrespondentVersion        - String - a correspondent configuration version.
//   CorrespondentName           - String - a correspondent configuration name.
//   CorrespondentInSaaS - Boolean or Undefined - shows that correspondent is in SaaS.
// Returns:
//   Structure - see comment toĀ the DefaultExchangePlanSettings function.
Function ExchangePlanSettings(ExchangePlanName, CorrespondentVersion, CorrespondentName, CorrespondentInSaaS) Export
	ExchangePlanSettings = DefaultExchangePlanSettings(ExchangePlanName);
	SetPrivilegedMode(True);
	ExchangePlans[ExchangePlanName].OnGetSettings(ExchangePlanSettings);
	HasOptionsReceivingHandler = ExchangePlanSettings.Algorithms.OnGetExchangeSettingsOptions;
	// Option initialization is required.
	If HasOptionsReceivingHandler Then
		FilterParameters = ContextParametersOfSettingsOptionsReceipt(CorrespondentName, CorrespondentVersion, CorrespondentInSaaS);
		ExchangePlans[ExchangePlanName].OnGetExchangeSettingsOptions(ExchangePlanSettings.ExchangeSettingsOptions, FilterParameters);
	Else
		// Options are not used ā an internalĀ option is to be added.
		SetupOption = ExchangePlanSettings.ExchangeSettingsOptions.Add();
		SetupOption.SettingID = "";
		SetupOption.CorrespondentInSaaS = Common.DataSeparationEnabled() 
			AND ExchangePlanSettings.ExchangePlanUsedInSaaS;
		SetupOption.CorrespondentInLocalMode = True;
	EndIf;
	SetPrivilegedMode(False);

	Return ExchangePlanSettings;
EndFunction

// Intended for preparing the structure and passing it to setting options get handler.
// Parameters:
//  CorrespondentName - String - a correspondent configuration name.
//  CorrespondentVersion - String - a correspondent configuration version.
//  CorrespondentInSaaS - Boolean or Undefined - shows that correspondent is in SaaS.
// Returns: Structure.
Function ContextParametersOfSettingsOptionsReceipt(CorrespondentName, CorrespondentVersion, CorrespondentInSaaS)
	Return New Structure("CorrespondentName, CorrespondentVersion, CorrespondentInSaaS",
				CorrespondentName, CorrespondentVersion, CorrespondentInSaaS);
EndFunction

// Fills in the settings related to the exchange setup option. Later these settings are used by the data exchange subsystem.
// Parameters:
//   ExchangePlanName        - String -  an exchange plan name.
//   SetupID - String - ID of data exchange setup option.
//   CorrespondentVersion   - String - a correspondent configuration version.
//   CorrespondentName      - String - a correspondent configuration name.
// Returns:
//   Structure - forĀ more information, see comment toĀ the ExchangeSettingOptionDetailsByDefault function.
Function SettingOptionDetails(ExchangePlanName, SettingID, 
								CorrespondentVersion, CorrespondentName) Export
	SettingOptionDetails = ExchangeSettingOptionDetailsByDefault(ExchangePlanName);
	HasOptionDetailsHandler = HasExchangePlanManagerAlgorithm("OnGetSettingOptionDetails", ExchangePlanName);
	If HasOptionDetailsHandler Then
		OptionParameters = ContextParametersOfSettingOptionDetailsReceipt(CorrespondentName, CorrespondentVersion);
		ExchangePlans[ExchangePlanName].OnGetSettingOptionDetails(
							SettingOptionDetails, SettingID, OptionParameters);
	EndIf;
	Return SettingOptionDetails;
EndFunction

// Is intended for preparing the structure and passing to theĀ handler of option details receipt.
// Parameters:
//  CorrespondentName - String - a correspondent configuration name.
//  CorrespondentVersion - String - a correspondent configuration version.
// Returns: Structure.
Function ContextParametersOfSettingOptionDetailsReceipt(CorrespondentName, CorrespondentVersion)
	Return New Structure("CorrespondentVersion, CorrespondentName",
							CorrespondentVersion,CorrespondentName);
EndFunction

// Returns the flag showing whetherĀ the specified procedure or function is available in the exchange plan manager module.
// Calculated by exchange plan settings, the Algorithms property (see the DefaultExchangePlanSettings comment).
// Parameters:
//  AlgorithmName - String - a name of procedure / function.
//  ExchangePlanName - String - an exchange plan name.
// Returns:
//   Boolean.
//
Function HasExchangePlanManagerAlgorithm(AlgorithmName, ExchangePlanName) Export
	
	ExchangePlanSettings = DataExchangeCached.ExchangePlanSettings(ExchangePlanName);
	
	AlgorithmFound = Undefined;
	ExchangePlanSettings.Algorithms.Property(AlgorithmName, AlgorithmFound);
	
	Return (AlgorithmFound = True);
	
EndFunction
#EndRegion

#Region DataSynchronizationPasswordsOperations

// Returns the data synchronization password for the specified node.
// If the password is not set, the function returns Undefined.
//
// Returns:
//  String, Undefined - data synchronization password value.
//
Function DataSynchronizationPassword(Val InfobaseNode) Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.DataSynchronizationPasswords.Get(InfobaseNode);
EndFunction

// Returns the flag that shows whether the data synchronization password is set by a user.
//
Function DataSynchronizationPasswordSpecified(Val InfobaseNode) Export
	
	Return DataSynchronizationPassword(InfobaseNode) <> Undefined;
	
EndFunction

// Sets the data synchronization password for the specified node.
// Saves the password to a session parameter.
//
Procedure SetDataSynchronizationPassword(Val InfobaseNode, Val Password)
	
	SetPrivilegedMode(True);
	
	DataSynchronizationPasswords = New Map;
	
	For Each Item In SessionParameters.DataSynchronizationPasswords Do
		
		DataSynchronizationPasswords.Insert(Item.Key, Item.Value);
		
	EndDo;
	
	DataSynchronizationPasswords.Insert(InfobaseNode, Password);
	
	SessionParameters.DataSynchronizationPasswords = New FixedMap(DataSynchronizationPasswords);
	
EndProcedure

// Resets the data synchronization password for the specified node.
//
Procedure ResetDataSynchronizationPassword(Val InfobaseNode)
	
	SetDataSynchronizationPassword(InfobaseNode, Undefined);
	
EndProcedure

#EndRegion

#Region SharedDataControl

// Checks whether it is possible to write separated data item. Raises exception if the data item cannot be written.
//
Procedure ExecuteSharedDataOnWriteCheck(Val Data) Export
	
	If Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable()
		AND Not IsSeparatedObject(Data) Then
		
		ExceptionText = NStr("ru = 'ŠŠµŠ“Š¾ŃŃŠ°ŃŠ¾ŃŠ½Š¾ ŠæŃŠ°Š² Š“Š»Ń Š²ŃŠæŠ¾Š»Š½ŠµŠ½ŠøŃ Š“ŠµŠ¹ŃŃŠ²ŠøŃ.'; en = 'Insufficient rights to perform the action.'; pl = 'Nie wystarczajÄce uprawnienia do wykonania czynnoÅci.';es_ES = 'Insuficientes derechos para realizar la acciĆ³n.';es_CO = 'Insuficientes derechos para realizar la acciĆ³n.';tr = 'Eylemi gerĆ§ekleÅtirmek iĆ§in yetersiz haklar.';it = 'Diritti insufficienti per eseguire l''azione.';de = 'Unzureichende Rechte zur DurchfĆ¼hrung der Aktion.'", CommonClientServer.DefaultLanguageCode());
		
		WriteLogEvent(
			ExceptionText,
			EventLogLevel.Error,
			Data.Metadata());
		
		Raise ExceptionText;
	EndIf;
	
EndProcedure

Function IsSeparatedObject(Val Object)
	
	FullName = Object.Metadata().FullName();
	
	If Common.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		IsSeparatedMetadataObject = ModuleSaaS.IsSeparatedMetadataObject(FullName);
	Else
		IsSeparatedMetadataObject = False;
	EndIf;
	
	Return IsSeparatedMetadataObject;
	
EndFunction

#EndRegion

#Region DataExchangeDashboardOperations

// Returns the structure with the last exchange data for the specified infobase node.
//
// Parameters:
//  No.
// 
// Returns:
//  DataExchangesStates - Structure - a structure with the last exchange data for the specified infobase node.
//
Function ExchangeNodeDataExchangeStates(Val InfobaseNode) Export
	
	SetPrivilegedMode(True);
	
	// Function return value.
	DataExchangesStates = New Structure;
	DataExchangesStates.Insert("InfobaseNode");
	DataExchangesStates.Insert("DataImportResult", "Undefined");
	DataExchangesStates.Insert("DataExportResult", "Undefined");
	
	QueryText = "
	|// {QUERY #0}
	|////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|	WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
	|	THEN ""Success""
	|	
	|	WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
	|	THEN ""CompletedWithWarnings""
	|	
	|	WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Warning_ExchangeMessageAlreadyAccepted)
	|	THEN ""Warning_ExchangeMessageAlreadyAccepted""
	|	
	|	WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Error_MessageTransport)
	|	THEN ""Error_MessageTransport""
	|	
	|	ELSE ""Error""
	|	
	|	END AS ExchangeExecutionResult
	|FROM
	|	InformationRegister.[DataExchangesStates] AS DataExchangesStates
	|WHERE
	|	  DataExchangesStates.InfobaseNode = &InfobaseNode
	|	AND DataExchangesStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
	|;
	|// {QUERY #1}
	|////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|	WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
	|	THEN ""Success""
	|	
	|	WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
	|	THEN ""CompletedWithWarnings""
	|	
	|	WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Warning_ExchangeMessageAlreadyAccepted)
	|	THEN ""Warning_ExchangeMessageAlreadyAccepted""
	|	
	|	WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Error_MessageTransport)
	|	THEN ""Error_MessageTransport""
	|	
	|	ELSE ""Error""
	|	END AS ExchangeExecutionResult
	|	
	|FROM
	|	InformationRegister.[DataExchangesStates] AS DataExchangesStates
	|WHERE
	|	  DataExchangesStates.InfobaseNode = &InfobaseNode
	|	AND DataExchangesStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataExport)
	|;
	|";
	
	If Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable() Then
		QueryText = StrReplace(QueryText, "[DataExchangesStates]", "DataAreaDataExchangeStates");
	Else
		QueryText = StrReplace(QueryText, "[DataExchangesStates]", "DataExchangesStates");
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	
	QueryResultsArray = Query.ExecuteBatch();
	
	DataImportResultSelection = QueryResultsArray[0].Select();
	DataExportResultSelection = QueryResultsArray[1].Select();
	
	If DataImportResultSelection.Next() Then
		
		DataExchangesStates.DataImportResult = DataImportResultSelection.ExchangeExecutionResult;
		
	EndIf;
	
	If DataExportResultSelection.Next() Then
		
		DataExchangesStates.DataExportResult = DataExportResultSelection.ExchangeExecutionResult;
		
	EndIf;
	
	DataExchangesStates.InfobaseNode = InfobaseNode;
	
	Return DataExchangesStates;
EndFunction

// Returns the structure with the last exchange data for the specified infobase node and actions on exchange.
//
// Parameters:
//  No.
// 
// Returns:
//  DataExchangesStates - Structure - a structure with the last exchange data for the specified infobase node.
//
Function DataExchangesStates(Val InfobaseNode, ActionOnExchange) Export
	
	// Function return value.
	DataExchangesStates = New Structure;
	DataExchangesStates.Insert("StartDate",    Date('00010101'));
	DataExchangesStates.Insert("EndDate", Date('00010101'));
	
	QueryText = "
	|SELECT
	|	StartDate,
	|	EndDate
	|FROM
	|	InformationRegister.[DataExchangesStates] AS DataExchangesStates
	|WHERE
	|	  DataExchangesStates.InfobaseNode = &InfobaseNode
	|	AND DataExchangesStates.ActionOnExchange      = &ActionOnExchange
	|";
	
	If Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable() Then
		QueryText = StrReplace(QueryText, "[DataExchangesStates]", "DataAreaDataExchangeStates");
	Else
		QueryText = StrReplace(QueryText, "[DataExchangesStates]", "DataExchangesStates");
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.SetParameter("ActionOnExchange",      ActionOnExchange);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		
		FillPropertyValues(DataExchangesStates, Selection);
		
	EndIf;
	
	Return DataExchangesStates;
	
EndFunction

#EndRegion

#Region InitializeSession

// Retrieves an array ofĀ all exchange plans that take part in the data exchange.
// The return array contains all exchange plans that have exchange nodes except the predefined one.
//
// Parameters:
//  No.
// 
// Returns:
//  ExchangePlanArray - Array - an array of strings (names) of all exchange plans that take part in the data exchange.
//
Function GetExchangePlansInUse() Export
	
	// returns
	ExchangePlanArray = New Array;
	
	For Each ExchangePlanName In DataExchangeCached.SSLExchangePlans() Do
		
		If Not ExchangePlanContainsNoNodes(ExchangePlanName) Then
			
			ExchangePlanArray.Add(ExchangePlanName);
			
		EndIf;
		
	EndDo;
	
	Return ExchangePlanArray;
	
EndFunction

// Receives the object registration rules table from the infobase.
//
// Parameters:
//  No.
// 
// Returns:
//  ObjectsRegistrationRulesĀ - ValueTable - a table ofĀ common object registration rules for ORM.
// 
Function GetObjectsRegistrationRules() Export
	
	// Function return value.
	ObjectsRegistrationRules = ObjectsRegistrationRulesTableInitialization();
	
	QueryText = "
	|SELECT
	|	DataExchangeRules.RulesAreRead AS RulesAreRead
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	  DataExchangeRules.RulesKind = VALUE(Enum.DataExchangeRulesTypes.ObjectsRegistrationRules)
	|	AND DataExchangeRules.RulesAreImported
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		RulesAreRead = Selection.RulesAreRead.Get();
		If RulesAreRead = Undefined Then
			Continue;
		EndIf;
		
		FillPropertiesValuesForORRValuesTable(ObjectsRegistrationRules, RulesAreRead);
		
	EndDo;
	
	Return ObjectsRegistrationRules;
	
EndFunction

// Receives the object selective registration rule table from the infobase.
//
// Parameters:
//  No.
// 
// Returns:
//  SelectiveObjectsRegistrationRules - ValueTable - a table of general rules of selective object registration for
//                                                           ORM.
// 
Function GetSelectiveObjectsRegistrationRules() Export
	
	// Function return value.
	SelectiveObjectsRegistrationRules = SelectiveObjectsRegistrationRulesTableInitialization();
	
	QueryText = "
	|SELECT
	|	DataExchangeRules.RulesAreRead AS RulesAreRead
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	  DataExchangeRules.RulesKind = VALUE(Enum.DataExchangeRulesTypes.ObjectConversionRules)
	|	AND DataExchangeRules.UseSelectiveObjectRegistrationFilter
	|	AND DataExchangeRules.RulesAreImported
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		ExchangeRuleStructure = Selection.RulesAreRead.Get();
		
		FillPropertyValuesForValueTable(SelectiveObjectsRegistrationRules, ExchangeRuleStructure["SelectiveObjectsRegistrationRules"]);
		
	EndDo;
	
	Return SelectiveObjectsRegistrationRules;
	
EndFunction

Function ObjectsRegistrationRulesTableInitialization() Export
	
	// Function return value.
	Rules = New ValueTable;
	
	Columns = Rules.Columns;
	
	Columns.Add("MetadataObjectName", New TypeDescription("String"));
	Columns.Add("ExchangePlanName",      New TypeDescription("String"));
	
	Columns.Add("FlagAttributeName", New TypeDescription("String"));
	
	Columns.Add("QueryText",    New TypeDescription("String"));
	Columns.Add("ObjectProperties", New TypeDescription("Structure"));
	
	Columns.Add("ObjectPropertiesString", New TypeDescription("String"));
	
	// Flag that shows whether rules are empty.
	Columns.Add("RuleByObjectPropertiesEmpty", New TypeDescription("Boolean"));
	
	// event handlers
	Columns.Add("BeforeProcess",            New TypeDescription("String"));
	Columns.Add("OnProcess",               New TypeDescription("String"));
	Columns.Add("OnProcessAdditional", New TypeDescription("String"));
	Columns.Add("AfterProcess",             New TypeDescription("String"));
	
	Columns.Add("HasBeforeProcessHandler",            New TypeDescription("Boolean"));
	Columns.Add("HasOnProcessHandler",               New TypeDescription("Boolean"));
	Columns.Add("HasOnProcessHandlerAdditional", New TypeDescription("Boolean"));
	Columns.Add("HasAfterProcessHandler",             New TypeDescription("Boolean"));
	
	Columns.Add("FilterByObjectProperties", New TypeDescription("ValueTree"));
	
	// This field is used for temporary storing data from the object or reference.
	Columns.Add("FilterByProperties", New TypeDescription("ValueTree"));
	
	// Adding the index
	Rules.Indexes.Add("ExchangePlanName, MetadataObjectName");
	
	Return Rules;
	
EndFunction

Function SelectiveObjectsRegistrationRulesTableInitialization() Export
	
	// Function return value.
	Rules = New ValueTable;
	
	Columns = Rules.Columns;
	
	Columns.Add("Order",                        New TypeDescription("Number"));
	Columns.Add("ObjectName",                     New TypeDescription("String"));
	Columns.Add("ExchangePlanName",                 New TypeDescription("String"));
	Columns.Add("TabularSectionName",              New TypeDescription("String"));
	Columns.Add("RegistrationAttributes",           New TypeDescription("String"));
	Columns.Add("RegistrationAttributesStructure", New TypeDescription("Structure"));
	
	// Adding the index
	Rules.Indexes.Add("ExchangePlanName, ObjectName");
	
	Return Rules;
	
EndFunction

Function ExchangePlanContainsNoNodes(Val ExchangePlanName)
	
	Query = New Query(
	"SELECT TOP 1
	|	TRUE
	|FROM
	|	#ExchangePlanTableName AS ExchangePlan
	|WHERE
	|	NOT ExchangePlan.ThisNode");
	
	Query.Text = StrReplace(Query.Text, "#ExchangePlanTableName", "ExchangePlan." + ExchangePlanName);
	
	Return Query.Execute().IsEmpty();
	
EndFunction

Procedure FillPropertiesValuesForORRValuesTable(DestinationTable, SourceTable)
	
	For Each SourceRow In SourceTable Do
		
		FillPropertyValues(DestinationTable.Add(), SourceRow);
		
	EndDo;
	
EndProcedure

Procedure FillPropertyValuesForValueTable(DestinationTable, SourceTable)
	
	For Each SourceRow In SourceTable Do
		
		FillPropertyValues(DestinationTable.Add(), SourceRow);
		
	EndDo;
	
EndProcedure

Function DataSynchronizationRuleDetails(Val InfobaseNode) Export
	
	SetPrivilegedMode(True);
	
	CorrespondentVersion = CorrespondentVersion(InfobaseNode);
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
	
	Setting = FilterSettingsValuesOnNode(InfobaseNode, CorrespondentVersion);
	
	DataSynchronizationRuleDetails = DataTransferRestrictionsDetails(
		ExchangePlanName, Setting, CorrespondentVersion,SavedExchangePlanNodeSettingOption(InfobaseNode));
	
	SetPrivilegedMode(False);
	
	Return DataSynchronizationRuleDetails;
	
EndFunction

Function FilterSettingsValuesOnNode(Val InfobaseNode, Val CorrespondentVersion)
	
	Result = New Structure;
	
	InfobaseNodeObject = InfobaseNode.GetObject();
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
	
	NodeFilterStructure = NodeFilterStructure(ExchangePlanName,
		CorrespondentVersion, SavedExchangePlanNodeSettingOption(InfobaseNode));
	
	For Each Setting In NodeFilterStructure Do
		
		If TypeOf(Setting.Value) = Type("Structure") Then
			
			TabularSection = New Structure;
			
			For Each Column In Setting.Value Do
				
				TabularSection.Insert(Column.Key, InfobaseNodeObject[Setting.Key].UnloadColumn(Column.Key));
				
			EndDo;
			
			Result.Insert(Setting.Key, TabularSection);
			
		Else
			
			Result.Insert(Setting.Key, InfobaseNodeObject[Setting.Key]);
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

Procedure SetDataExchangeMessageImportModeBeforeStart(Val Property, Val EnableMode) Export
	
	// You have to set the privileged mode before the procedure call.
	
	If IsSubordinateDIBNode() Then
		
		NewStructure = New Structure(SessionParameters.DataExchangeMessageImportModeBeforeStart);
		If EnableMode Then
			If NOT NewStructure.Property(Property) Then
				NewStructure.Insert(Property);
			EndIf;
		Else
			If NewStructure.Property(Property) Then
				NewStructure.Delete(Property);
			EndIf;
		EndIf;
		
		SessionParameters.DataExchangeMessageImportModeBeforeStart =
			New FixedStructure(NewStructure);
	Else
		
		SessionParameters.DataExchangeMessageImportModeBeforeStart = New FixedStructure;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ExchangeSettingsStructureInitialization

// Initializes the data exchange subsystem to execute the exchange process.
//
// Parameters:
// 
// Returns:
//  ExchangeSettingsStructure - Structure - a structure with all necessary data and objects to execute exchange.
//
Function ExchangeSettingsForInfobaseNode(
	InfobaseNode,
	ActionOnExchange,
	ExchangeMessagesTransportKind,
	UseTransportSettings = True) Export
	
	// Function return value.
	ExchangeSettingsStructure = BaseExchangeSettingsStructure();
	
	ExchangeSettingsStructure.InfobaseNode = InfobaseNode;
	ExchangeSettingsStructure.ActionOnExchange      = ActionOnExchange;
	ExchangeSettingsStructure.ExchangeTransportKind    = ExchangeMessagesTransportKind;
	ExchangeSettingsStructure.IsDIBExchange           = DataExchangeCached.IsDistributedInfobaseNode(InfobaseNode);
	
	InitExchangeSettingsStructureForInfobaseNode(ExchangeSettingsStructure, UseTransportSettings);
	
	SetDebugModeSettingsForStructure(ExchangeSettingsStructure);
	
	// Validating settings structure values for the exchange. Adding error messages to the event log.
	CheckExchangeStructure(ExchangeSettingsStructure, UseTransportSettings);
	
	// Canceling if settings contain errors.
	If ExchangeSettingsStructure.Cancel Then
		Return ExchangeSettingsStructure;
	EndIf;
	
	If UseTransportSettings Then
		
		// Initializing the exchange message transport data processor.
		InitExchangeMessageTransportDataProcessor(ExchangeSettingsStructure);
		
	EndIf;
	
	// Initializing the exchange data processor.
	If ExchangeSettingsStructure.IsDIBExchange Then
		
		InitDataExchangeDataProcessor(ExchangeSettingsStructure);
		
	ElsIf ExchangeSettingsStructure.ExchangeByObjectConversionRules Then
		
		InitDataExchangeDataProcessorForConversionRules(ExchangeSettingsStructure);
		
	EndIf;
	
	Return ExchangeSettingsStructure;
EndFunction

Function ExchangeSettingsForExternalConnection(InfobaseNode, ActionOnExchange, TransactionItemsCount)
	
	// Function return value.
	ExchangeSettingsStructure = BaseExchangeSettingsStructure();
	
	ExchangeSettingsStructure.InfobaseNode = InfobaseNode;
	ExchangeSettingsStructure.ActionOnExchange      = ActionOnExchange;
	ExchangeSettingsStructure.IsDIBExchange           = DataExchangeCached.IsDistributedInfobaseNode(InfobaseNode);
	
	PropertyStructure = Common.ObjectAttributesValues(ExchangeSettingsStructure.InfobaseNode, "Code, Description");
	
	ExchangeSettingsStructure.InfobaseNodeCode = CorrespondentNodeIDForExchange(ExchangeSettingsStructure.InfobaseNode);
	ExchangeSettingsStructure.InfobaseNodeDescription = PropertyStructure.Description;
	
	ExchangeSettingsStructure.TransportSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettings(ExchangeSettingsStructure.InfobaseNode);
	
	If TransactionItemsCount = Undefined Then
		TransactionItemsCount = ItemsCountInTransactionOfActionBeingExecuted(ActionOnExchange);
	EndIf;
	
	ExchangeSettingsStructure.TransactionItemsCount = TransactionItemsCount;
	
	// CALCULATED VALUES
	ExchangeSettingsStructure.DoDataImport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataImport);
	ExchangeSettingsStructure.DoDataExport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataExport);
	
	ExchangeSettingsStructure.ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangeSettingsStructure.InfobaseNode);
	
	ExchangeSettingsStructure.CurrentExchangePlanNode = DataExchangeCached.GetThisExchangePlanNode(ExchangeSettingsStructure.ExchangePlanName);
	ExchangeSettingsStructure.CurrentExchangePlanNodeCode = NodeIDForExchange(ExchangeSettingsStructure.InfobaseNode);
	
	// Getting the message key for the event log.
	ExchangeSettingsStructure.EventLogMessageKey = EventLogMessageKey(ExchangeSettingsStructure.InfobaseNode, ExchangeSettingsStructure.ActionOnExchange);
	
	ExchangeSettingsStructure.ExchangeTransportKind = Enums.ExchangeMessagesTransportTypes.COM;
	
	SetDebugModeSettingsForStructure(ExchangeSettingsStructure);
	
	// Validating settings structure values for the exchange. Adding error messages to the event log.
	CheckExchangeStructure(ExchangeSettingsStructure);
	
	// Canceling if settings contain errors.
	If ExchangeSettingsStructure.Cancel Then
		Return ExchangeSettingsStructure;
	EndIf;
	
	// Initializing the exchange data processor.
	InitDataExchangeDataProcessorForConversionRules(ExchangeSettingsStructure);
	
	Return ExchangeSettingsStructure;
EndFunction

// Initializes the data exchange subsystem to execute the exchange process.
//
// Parameters:
// 
// Returns:
//  ExchangeSettingsStructure - Structure - a structure with all necessary data and objects to execute exchange.
//
Function DataExchangeSettings(ExchangeExecutionSettings, RowNumber) Export
	
	// Function return value.
	ExchangeSettingsStructure = BaseExchangeSettingsStructure();
	
	InitExchangeSettingsStructure(ExchangeSettingsStructure, ExchangeExecutionSettings, RowNumber);
	
	If ExchangeSettingsStructure.Cancel Then
		Return ExchangeSettingsStructure;
	EndIf;
	
	SetDebugModeSettingsForStructure(ExchangeSettingsStructure);
	
	// Validating settings structure values for the exchange. Adding error messages to the event log.
	CheckExchangeStructure(ExchangeSettingsStructure);
	
	// Canceling if settings contain errors.
	If ExchangeSettingsStructure.Cancel Then
		Return ExchangeSettingsStructure;
	EndIf;
	
	// Initializing the exchange message transport data processor.
	InitExchangeMessageTransportDataProcessor(ExchangeSettingsStructure);
	
	// Initializing the exchange data processor.
	If ExchangeSettingsStructure.IsDIBExchange Then
		
		InitDataExchangeDataProcessor(ExchangeSettingsStructure);
		
	ElsIf ExchangeSettingsStructure.ExchangeByObjectConversionRules Then
		
		InitDataExchangeDataProcessorForConversionRules(ExchangeSettingsStructure);
		
	EndIf;
	
	Return ExchangeSettingsStructure;
EndFunction

// Gets the transport settings structure for data exchange.
//
Function ExchangeTransportSettings(InfobaseNode, ExchangeMessagesTransportKind) Export
	
	// Function return value.
	ExchangeSettingsStructure = BaseExchangeSettingsStructure();
	
	ExchangeSettingsStructure.InfobaseNode = InfobaseNode;
	ExchangeSettingsStructure.ActionOnExchange      = Enums.ActionsOnExchange.DataImport;
	ExchangeSettingsStructure.ExchangeTransportKind    = ExchangeMessagesTransportKind;
	
	InitExchangeSettingsStructureForInfobaseNode(ExchangeSettingsStructure, True);
	
	// Validating settings structure values for the exchange. Adding error messages to the event log.
	CheckExchangeStructure(ExchangeSettingsStructure);
	
	// Canceling if settings contain errors.
	If ExchangeSettingsStructure.Cancel Then
		Return ExchangeSettingsStructure;
	EndIf;
	
	// Initializing the exchange message transport data processor.
	InitExchangeMessageTransportDataProcessor(ExchangeSettingsStructure);
	
	Return ExchangeSettingsStructure;
EndFunction

Function ExchangeSettingsStructureForInteractiveImportSession(Val InfobaseNode, Val ExchangeMessageFileName) Export
	
	Return DataExchangeCached.ExchangeSettingsStructureForInteractiveImportSession(InfobaseNode, ExchangeMessageFileName);
	
EndFunction

Procedure InitExchangeSettingsStructure(ExchangeSettingsStructure, ExchangeExecutionSettings, RowNumber)
	
	QueryText = "
	|SELECT
	|	ExchangeExecutionSettingsExchangeSettings.InfobaseNode         AS InfobaseNode,
	|	ExchangeExecutionSettingsExchangeSettings.InfobaseNode.Code     AS InfobaseNodeCode,
	|	ExchangeExecutionSettingsExchangeSettings.ExchangeTransportKind            AS ExchangeTransportKind,
	|	ExchangeExecutionSettingsExchangeSettings.CurrentAction            AS ActionOnExchange,
	|	ExchangeExecutionSettingsExchangeSettings.Ref                         AS ExchangeExecutionSettings,
	|	ExchangeExecutionSettingsExchangeSettings.Ref.Description            AS ExchangeExecutionSettingDescription,
	|	CASE
	|		WHEN ExchangeExecutionSettingsExchangeSettings.CurrentAction = VALUE(Enum.ActionsOnExchange.DataImport) THEN TRUE
	|		ELSE FALSE
	|	END                                                                   AS DoDataImport,
	|	CASE
	|		WHEN ExchangeExecutionSettingsExchangeSettings.CurrentAction = VALUE(Enum.ActionsOnExchange.DataExport) THEN TRUE
	|		ELSE FALSE
	|	END                                                                   AS DoDataExport
	|FROM
	|	Catalog.DataExchangeScenarios.ExchangeSettings AS ExchangeExecutionSettingsExchangeSettings
	|WHERE
	|	  ExchangeExecutionSettingsExchangeSettings.Ref      = &ExchangeExecutionSettings
	|	AND ExchangeExecutionSettingsExchangeSettings.LineNumber = &LineNumber
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ExchangeExecutionSettings", ExchangeExecutionSettings);
	Query.SetParameter("LineNumber",               RowNumber);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	// Filling structure property value.
	FillPropertyValues(ExchangeSettingsStructure, Selection);
	
	ExchangeSettingsStructure.IsDIBExchange = DataExchangeCached.IsDistributedInfobaseNode(ExchangeSettingsStructure.InfobaseNode);
	
	ExchangeSettingsStructure.EventLogMessageKey = NStr("ru = 'ŠŠ±Š¼ŠµŠ½ Š“Š°Š½Š½ŃŠ¼Šø'; en = 'Data exchange'; pl = 'Wymiana danych';es_ES = 'Intercambio de datos';es_CO = 'Intercambio de datos';tr = 'Veri deÄiÅimi';it = 'Scambio dati';de = 'Datenaustausch'");
	
	// Checking whether basic exchange settings structure fields are filled.
	CheckMainExchangeSettingsStructureFields(ExchangeSettingsStructure);
	
	If ExchangeSettingsStructure.Cancel Then
		Return;
	EndIf;
	
	//
	ExchangeSettingsStructure.ExchangePlanName = ExchangeSettingsStructure.InfobaseNode.Metadata().Name;
	ExchangeSettingsStructure.ExchangeByObjectConversionRules = DataExchangeCached.IsUniversalDataExchangeNode(ExchangeSettingsStructure.InfobaseNode);
	
	ExchangeSettingsStructure.CurrentExchangePlanNode    = ExchangePlans[ExchangeSettingsStructure.ExchangePlanName].ThisNode();
	ExchangeSettingsStructure.CurrentExchangePlanNodeCode = ExchangeSettingsStructure.CurrentExchangePlanNode.Code;
	
	ExchangeSettingsStructure.DataExchangeMessageTransportDataProcessorName = DataExchangeMessageTransportDataProcessorName(ExchangeSettingsStructure.ExchangeTransportKind);
	
	// Getting the message key for the event log.
	ExchangeSettingsStructure.EventLogMessageKey = EventLogMessageKey(ExchangeSettingsStructure.InfobaseNode, ExchangeSettingsStructure.ActionOnExchange);
	
	If DataExchangeCached.IsMessagesExchangeNode(ExchangeSettingsStructure.InfobaseNode) Then
		ModuleMessagesExchangeTransportSettings = InformationRegisters["MessageExchangeTransportSettings"];
		ExchangeSettingsStructure.TransportSettings = ModuleMessagesExchangeTransportSettings.TransportSettingsWS(ExchangeSettingsStructure.InfobaseNode);
	Else
		ExchangeSettingsStructure.TransportSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettings(ExchangeSettingsStructure.InfobaseNode, ExchangeSettingsStructure.ExchangeTransportKind);
	EndIf;
	
	ExchangeSettingsStructure.TransactionItemsCount = ItemsCountInTransactionOfActionBeingExecuted(ExchangeSettingsStructure.ActionOnExchange);
	
EndProcedure

Procedure InitExchangeSettingsStructureForInfobaseNode(
		ExchangeSettingsStructure,
		UseTransportSettings)
	
	PropertyStructure = Common.ObjectAttributesValues(ExchangeSettingsStructure.InfobaseNode, "Code, Description");
	
	ExchangeSettingsStructure.InfobaseNodeCode = CorrespondentNodeIDForExchange(ExchangeSettingsStructure.InfobaseNode);
	ExchangeSettingsStructure.InfobaseNodeDescription = PropertyStructure.Description;
	
	// Getting exchange transport settings.
	If DataExchangeCached.IsMessagesExchangeNode(ExchangeSettingsStructure.InfobaseNode) Then
		ModuleMessagesExchangeTransportSettings = InformationRegisters["MessageExchangeTransportSettings"];
		ExchangeSettingsStructure.TransportSettings = ModuleMessagesExchangeTransportSettings.TransportSettingsWS(
			ExchangeSettingsStructure.InfobaseNode);
	Else
		ExchangeSettingsStructure.TransportSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettings(ExchangeSettingsStructure.InfobaseNode);
	EndIf;
	
	If ExchangeSettingsStructure.TransportSettings <> Undefined Then
		
		If UseTransportSettings Then
			
			// Using the default value if the transport kind is not specified.
			If ExchangeSettingsStructure.ExchangeTransportKind = Undefined Then
				ExchangeSettingsStructure.ExchangeTransportKind = ExchangeSettingsStructure.TransportSettings.DefaultExchangeMessagesTransportKind;
			EndIf;
			
			// Using the FILE transport if the transport kind is not specified.
			If Not ValueIsFilled(ExchangeSettingsStructure.ExchangeTransportKind) Then
				
				ExchangeSettingsStructure.ExchangeTransportKind = Enums.ExchangeMessagesTransportTypes.FILE;
				
			EndIf;
			
			ExchangeSettingsStructure.DataExchangeMessageTransportDataProcessorName = DataExchangeMessageTransportDataProcessorName(ExchangeSettingsStructure.ExchangeTransportKind);
			
		EndIf;
		
		ExchangeSettingsStructure.TransactionItemsCount = ItemsCountInTransactionOfActionBeingExecuted(ExchangeSettingsStructure.ActionOnExchange);
		
		If ExchangeSettingsStructure.TransportSettings.Property("WSUseHighVolumeDataTransfer") Then
			ExchangeSettingsStructure.UseLargeDataTransfer = ExchangeSettingsStructure.TransportSettings.WSUseHighVolumeDataTransfer;
		EndIf;
		
	EndIf;
	
	// DEFAULT VALUE
	ExchangeSettingsStructure.ExchangeExecutionSettings             = Undefined;
	ExchangeSettingsStructure.ExchangeExecutionSettingDescription = "";
	
	// CALCULATED VALUES
	ExchangeSettingsStructure.DoDataImport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataImport);
	ExchangeSettingsStructure.DoDataExport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataExport);
	
	ExchangeSettingsStructure.ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangeSettingsStructure.InfobaseNode);
	ExchangeSettingsStructure.ExchangeByObjectConversionRules = DataExchangeCached.IsUniversalDataExchangeNode(ExchangeSettingsStructure.InfobaseNode);
	
	ExchangeSettingsStructure.CurrentExchangePlanNode    = ExchangePlans[ExchangeSettingsStructure.ExchangePlanName].ThisNode();
	ExchangeSettingsStructure.CurrentExchangePlanNodeCode = NodeIDForExchange(ExchangeSettingsStructure.InfobaseNode);
	
	// Getting the message key for the event log.
	ExchangeSettingsStructure.EventLogMessageKey = EventLogMessageKey(ExchangeSettingsStructure.InfobaseNode, ExchangeSettingsStructure.ActionOnExchange);
	
EndProcedure

Function BaseExchangeSettingsStructure()
	
	ExchangeSettingsStructure = New Structure;
	
	// Structure of settings by query fields.
	
	ExchangeSettingsStructure.Insert("StartDate");
	ExchangeSettingsStructure.Insert("EndDate");
	
	ExchangeSettingsStructure.Insert("LineNumber");
	ExchangeSettingsStructure.Insert("ExchangeExecutionSettings");
	ExchangeSettingsStructure.Insert("ExchangeExecutionSettingDescription");
	ExchangeSettingsStructure.Insert("InfobaseNode");
	ExchangeSettingsStructure.Insert("InfobaseNodeCode", "");
	ExchangeSettingsStructure.Insert("InfobaseNodeDescription", "");
	ExchangeSettingsStructure.Insert("ExchangeTransportKind");
	ExchangeSettingsStructure.Insert("ActionOnExchange");
	ExchangeSettingsStructure.Insert("TransactionItemsCount", 1); // each item requires a single transaction.
	ExchangeSettingsStructure.Insert("DoDataImport", False);
	ExchangeSettingsStructure.Insert("DoDataExport", False);
	ExchangeSettingsStructure.Insert("UseLargeDataTransfer", False);
	
	// Additional settings structure.
	ExchangeSettingsStructure.Insert("Cancel", False);
	ExchangeSettingsStructure.Insert("IsDIBExchange", False);
	
	ExchangeSettingsStructure.Insert("DataExchangeDataProcessor");
	ExchangeSettingsStructure.Insert("ExchangeMessageTransportDataProcessor");
	
	ExchangeSettingsStructure.Insert("ExchangePlanName");
	ExchangeSettingsStructure.Insert("CurrentExchangePlanNode");
	ExchangeSettingsStructure.Insert("CurrentExchangePlanNodeCode");
	
	ExchangeSettingsStructure.Insert("ExchangeByObjectConversionRules", False);
	
	ExchangeSettingsStructure.Insert("DataExchangeMessageTransportDataProcessorName");
	
	ExchangeSettingsStructure.Insert("EventLogMessageKey");
	
	ExchangeSettingsStructure.Insert("TransportSettings");
	
	ExchangeSettingsStructure.Insert("ObjectConversionRules");
	ExchangeSettingsStructure.Insert("RulesAreImported", False);
	
	ExchangeSettingsStructure.Insert("ExportHandlersDebug", False);
	ExchangeSettingsStructure.Insert("ImportHandlersDebug", False);
	ExchangeSettingsStructure.Insert("ExportDebugExternalDataProcessorFileName", "");
	ExchangeSettingsStructure.Insert("ImportDebugExternalDataProcessorFileName", "");
	ExchangeSettingsStructure.Insert("DataExchangeLoggingMode", False);
	ExchangeSettingsStructure.Insert("ExchangeProtocolFileName", "");
	ExchangeSettingsStructure.Insert("ContinueOnError", False);
	
	// Structure for passing arbitrary additional parameters.
	ExchangeSettingsStructure.Insert("AdditionalParameters", New Structure);
	
	// Structure for adding event log entries.
	ExchangeSettingsStructure.Insert("ExchangeExecutionResult");
	ExchangeSettingsStructure.Insert("ActionOnExchange");
	ExchangeSettingsStructure.Insert("ProcessedObjectsCount", 0);
	ExchangeSettingsStructure.Insert("MessageOnExchange",           "");
	ExchangeSettingsStructure.Insert("ErrorMessageString",      "");
	
	Return ExchangeSettingsStructure;
EndFunction

Procedure CheckMainExchangeSettingsStructureFields(ExchangeSettingsStructure)
	
	If NOT ValueIsFilled(ExchangeSettingsStructure.InfobaseNode) Then
		
		// The infobase node must be specified.
		ErrorMessageString = NStr(
		"ru = 'ŠŠµ Š·Š°Š“Š°Š½ ŃŠ·ŠµŠ» ŠøŠ½ŃŠ¾ŃŠ¼Š°ŃŠøŠ¾Š½Š½Š¾Š¹ Š±Š°Š·Ń Ń ŠŗŠ¾ŃŠ¾ŃŃŠ¼ Š½ŃŠ¶Š½Š¾ ŠæŃŠ¾ŠøŠ·Š²Š¾Š“ŠøŃŃ Š¾Š±Š¼ŠµŠ½ ŠøŠ½ŃŠ¾ŃŠ¼Š°ŃŠøŠµŠ¹. ŠŠ±Š¼ŠµŠ½ Š¾ŃŠ¼ŠµŠ½ŠµŠ½.'; en = 'Infobase node with which information shall be exchanged is not specified. Exchange is canceled.'; pl = 'Nie okreÅlono wÄzÅa bazy informacyjnej do wymiany informacji. Wymiana zostaÅa anulowana.';es_ES = 'Nodo de la infobase con el cual la informaciĆ³n tiene que intercambiarse, no estĆ” especificado. Intercambio se ha cancelado.';es_CO = 'Nodo de la infobase con el cual la informaciĆ³n tiene que intercambiarse, no estĆ” especificado. Intercambio se ha cancelado.';tr = 'Bilgilerin deÄiÅtirileceÄi veritabanÄ± Ć¼nitesi belirtilmemiÅ. DeÄiÅim iptal edildi.';it = 'Il nodo base di informazioni con cui si desidera scambiare informazioni non ĆØ specificato. Scambio annullato';de = 'Infobase-Knoten, mit denen Informationen ausgetauscht werden sollen, sind nicht spezifiziert. Austausch wird abgebrochen.'",
			CommonClientServer.DefaultLanguageCode());
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf NOT ValueIsFilled(ExchangeSettingsStructure.ExchangeTransportKind) Then
		
		ErrorMessageString = NStr("ru = 'ŠŠµ Š·Š°Š“Š°Š½ Š²ŠøŠ“ ŃŃŠ°Š½ŃŠæŠ¾ŃŃŠ° Š¾Š±Š¼ŠµŠ½Š°. ŠŠ±Š¼ŠµŠ½ Š¾ŃŠ¼ŠµŠ½ŠµŠ½.'; en = 'Exchange transport kind is not specified. Exchange is canceled.'; pl = 'Nie okreÅlono rodzaju transportu wymiany. Wymiana zostaÅa anulowana.';es_ES = 'Tipo de transporte de intercambio no estĆ” especificado. Intercambio estĆ” cancelado.';es_CO = 'Tipo de transporte de intercambio no estĆ” especificado. Intercambio estĆ” cancelado.';tr = 'DeÄiÅim taÅÄ±ma tĆ¼rĆ¼ belirtilmemiÅ. DeÄiÅim iptal edildi.';it = 'Nessun tipo di scambio dati ĆØ specificato. Scambio annullato';de = 'Austausch-Transportart ist nicht angegeben. Austausch wird abgebrochen.'",
			CommonClientServer.DefaultLanguageCode());
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf NOT ValueIsFilled(ExchangeSettingsStructure.ActionOnExchange) Then
		
		ErrorMessageString = NStr("ru = 'ŠŠµ ŃŠŗŠ°Š·Š°Š½Š¾ Š²ŃŠæŠ¾Š»Š½ŃŠµŠ¼Š¾Šµ Š“ŠµŠ¹ŃŃŠ²ŠøŠµ (Š²ŃŠ³ŃŃŠ·ŠŗŠ° / Š·Š°Š³ŃŃŠ·ŠŗŠ°). ŠŠ±Š¼ŠµŠ½ Š¾ŃŠ¼ŠµŠ½ŠµŠ½.'; en = 'Executed action (export/ import) is not specified. Exchange is canceled.'; pl = 'Nie okreÅlono wykonywanego dziaÅania (eksport/import). Wymiana zostaÅa anulowana.';es_ES = 'AcciĆ³n ejecutada (exportaciĆ³n/importaciĆ³n) no estĆ” especificada. Intercambio se ha cancelado.';es_CO = 'AcciĆ³n ejecutada (exportaciĆ³n/importaciĆ³n) no estĆ” especificada. Intercambio se ha cancelado.';tr = 'YĆ¼rĆ¼tĆ¼len eylem (dÄ±Åa aktarma / iĆ§e aktarma) belirtilmemiÅ. DeÄiÅim iptal edildi.';it = 'L''azione da eseguire (upload / download) non ĆØ specificata. Scambio annullato';de = 'AusgefĆ¼hrte Aktion (Export / Import) ist nicht angegeben. Austausch wird abgebrochen.'",
			CommonClientServer.DefaultLanguageCode());
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	EndIf;
	
EndProcedure

Procedure CheckExchangeStructure(ExchangeSettingsStructure, UseTransportSettings = True)
	
	If NOT ValueIsFilled(ExchangeSettingsStructure.InfobaseNode) Then
		
		// The infobase node must be specified.
		ErrorMessageString = NStr(
		"ru = 'ŠŠµ Š·Š°Š“Š°Š½ ŃŠ·ŠµŠ» ŠøŠ½ŃŠ¾ŃŠ¼Š°ŃŠøŠ¾Š½Š½Š¾Š¹ Š±Š°Š·Ń Ń ŠŗŠ¾ŃŠ¾ŃŃŠ¼ Š½ŃŠ¶Š½Š¾ ŠæŃŠ¾ŠøŠ·Š²Š¾Š“ŠøŃŃ Š¾Š±Š¼ŠµŠ½ ŠøŠ½ŃŠ¾ŃŠ¼Š°ŃŠøŠµŠ¹. ŠŠ±Š¼ŠµŠ½ Š¾ŃŠ¼ŠµŠ½ŠµŠ½.'; en = 'Infobase node with which information shall be exchanged is not specified. Exchange is canceled.'; pl = 'Nie okreÅlono wÄzÅa bazy informacyjnej do wymiany informacji. Wymiana zostaÅa anulowana.';es_ES = 'Nodo de la infobase con el cual la informaciĆ³n tiene que intercambiarse, no estĆ” especificado. Intercambio se ha cancelado.';es_CO = 'Nodo de la infobase con el cual la informaciĆ³n tiene que intercambiarse, no estĆ” especificado. Intercambio se ha cancelado.';tr = 'Bilgilerin deÄiÅtirileceÄi veritabanÄ± Ć¼nitesi belirtilmemiÅ. DeÄiÅim iptal edildi.';it = 'Il nodo base di informazioni con cui si desidera scambiare informazioni non ĆØ specificato. Scambio annullato';de = 'Infobase-Knoten, mit denen Informationen ausgetauscht werden sollen, sind nicht spezifiziert. Austausch wird abgebrochen.'",
			CommonClientServer.DefaultLanguageCode());
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf UseTransportSettings AND NOT ValueIsFilled(ExchangeSettingsStructure.ExchangeTransportKind) Then
		
		ErrorMessageString = NStr("ru = 'ŠŠµ Š·Š°Š“Š°Š½ Š²ŠøŠ“ ŃŃŠ°Š½ŃŠæŠ¾ŃŃŠ° Š¾Š±Š¼ŠµŠ½Š°. ŠŠ±Š¼ŠµŠ½ Š¾ŃŠ¼ŠµŠ½ŠµŠ½.'; en = 'Exchange transport kind is not specified. Exchange is canceled.'; pl = 'Nie okreÅlono rodzaju transportu wymiany. Wymiana zostaÅa anulowana.';es_ES = 'Tipo de transporte de intercambio no estĆ” especificado. Intercambio estĆ” cancelado.';es_CO = 'Tipo de transporte de intercambio no estĆ” especificado. Intercambio estĆ” cancelado.';tr = 'DeÄiÅim taÅÄ±ma tĆ¼rĆ¼ belirtilmemiÅ. DeÄiÅim iptal edildi.';it = 'Nessun tipo di scambio dati ĆØ specificato. Scambio annullato';de = 'Austausch-Transportart ist nicht angegeben. Austausch wird abgebrochen.'",
			CommonClientServer.DefaultLanguageCode());
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf NOT ValueIsFilled(ExchangeSettingsStructure.ActionOnExchange) Then
		
		ErrorMessageString = NStr("ru = 'ŠŠµ ŃŠŗŠ°Š·Š°Š½Š¾ Š²ŃŠæŠ¾Š»Š½ŃŠµŠ¼Š¾Šµ Š“ŠµŠ¹ŃŃŠ²ŠøŠµ (Š²ŃŠ³ŃŃŠ·ŠŗŠ° / Š·Š°Š³ŃŃŠ·ŠŗŠ°). ŠŠ±Š¼ŠµŠ½ Š¾ŃŠ¼ŠµŠ½ŠµŠ½.'; en = 'Executed action (export/ import) is not specified. Exchange is canceled.'; pl = 'Nie okreÅlono wykonywanego dziaÅania (eksport/import). Wymiana zostaÅa anulowana.';es_ES = 'AcciĆ³n ejecutada (exportaciĆ³n/importaciĆ³n) no estĆ” especificada. Intercambio se ha cancelado.';es_CO = 'AcciĆ³n ejecutada (exportaciĆ³n/importaciĆ³n) no estĆ” especificada. Intercambio se ha cancelado.';tr = 'YĆ¼rĆ¼tĆ¼len eylem (dÄ±Åa aktarma / iĆ§e aktarma) belirtilmemiÅ. DeÄiÅim iptal edildi.';it = 'L''azione da eseguire (upload / download) non ĆØ specificata. Scambio annullato';de = 'AusgefĆ¼hrte Aktion (Export / Import) ist nicht angegeben. Austausch wird abgebrochen.'",
			CommonClientServer.DefaultLanguageCode());
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf ExchangeSettingsStructure.InfobaseNode.DeletionMark Then
		
		// The infobase node cannot be marked for deletion.
		ErrorMessageString = NStr("ru = 'Š£Š·ŠµŠ» ŠøŠ½ŃŠ¾ŃŠ¼Š°ŃŠøŠ¾Š½Š½Š¾Š¹ Š±Š°Š·Ń ŠæŠ¾Š¼ŠµŃŠµŠ½ Š½Š° ŃŠ“Š°Š»ŠµŠ½ŠøŠµ. ŠŠ±Š¼ŠµŠ½ Š¾ŃŠ¼ŠµŠ½ŠµŠ½.'; en = 'Infobase node is marked for deletion. Exchange is canceled.'; pl = 'WÄzeÅ bazy informacyjnej jest oznaczony do usuniÄcia. Wymiana zostaÅa anulowana.';es_ES = 'Nodo de la infobase estĆ” marcado para borrar. Intercambio estĆ” cancelado.';es_CO = 'Nodo de la infobase estĆ” marcado para borrar. Intercambio estĆ” cancelado.';tr = 'Infobase dĆ¼ÄĆ¼mĆ¼ silinmek Ć¼zere iÅaretlendi. DeÄiÅim iptal edildi.';it = 'Il nodo dell''Infobase ĆØ contrassegnato per la cancellazione. Scambio annullato.';de = 'Der Infobase-Knoten ist zum LĆ¶schen markiert. Austausch wird abgebrochen.'",
			CommonClientServer.DefaultLanguageCode());
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
	
	ElsIf ExchangeSettingsStructure.InfobaseNode = ExchangeSettingsStructure.CurrentExchangePlanNode Then
		
		// The exchange with the current infobase node cannot be provided.
		ErrorMessageString = NStr(
		"ru = 'ŠŠµŠ»ŃŠ·Ń Š¾ŃŠ³Š°Š½ŠøŠ·Š¾Š²Š°ŃŃ Š¾Š±Š¼ŠµŠ½ Š“Š°Š½Š½ŃŠ¼Šø Ń ŃŠµŠŗŃŃŠøŠ¼ ŃŠ·Š»Š¾Š¼ ŠøŠ½ŃŠ¾ŃŠ¼Š°ŃŠøŠ¾Š½Š½Š¾Š¹ Š±Š°Š·Ń. ŠŠ±Š¼ŠµŠ½ Š¾ŃŠ¼ŠµŠ½ŠµŠ½.'; en = 'Cannot organize data exchange with the current infobase node. Exchange canceled.'; pl = 'Nie moÅ¼na poprawnie poÅÄczyÄ siÄ z bieÅ¼Äcym wÄzÅem bazy informacyjnej. Wymiana zostaÅa anulowana.';es_ES = 'No se puede comunicarse de forma apropiada con el nodo de la infobase actual. El intercambio se ha cancelado.';es_CO = 'No se puede comunicarse de forma apropiada con el nodo de la infobase actual. El intercambio se ha cancelado.';tr = 'Mevcut veritabanÄ± Ć¼nitesi ile dĆ¼zgĆ¼n bir Åekilde iletiÅim kurulamÄ±yor. DeÄiÅim iptal edildi.';it = 'Impossibile organizzare lo scambio dati con il nodo di infobase corrente. Scambio annullato.';de = 'Kommunikation mit dem aktuellen Infobase-Knoten nicht mĆ¶glich. Der Austausch wurde storniert.'",
			CommonClientServer.DefaultLanguageCode());
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
	
	ElsIf IsBlankString(ExchangeSettingsStructure.InfobaseNodeCode)
		  OR IsBlankString(ExchangeSettingsStructure.CurrentExchangePlanNodeCode) Then
		
		// The infobase codes must be specified.
		ErrorMessageString = NStr("ru = 'ŠŠ“ŠøŠ½ ŠøŠ· ŃŠ·Š»Š¾Š² Š¾Š±Š¼ŠµŠ½Š° ŠøŠ¼ŠµŠµŃ ŠæŃŃŃŠ¾Š¹ ŠŗŠ¾Š“. ŠŠ±Š¼ŠµŠ½ Š¾ŃŠ¼ŠµŠ½ŠµŠ½.'; en = 'One of exchange nodes has an empty code. Exchange is canceled.'; pl = 'Jeden z wÄzÅĆ³w wymiany ma pusty kod. Wymiana zostaÅa anulowana.';es_ES = 'Uno de los nodos de intercambio tiene un cĆ³digo vacĆ­o. Intercambio estĆ” cancelado.';es_CO = 'Uno de los nodos de intercambio tiene un cĆ³digo vacĆ­o. Intercambio estĆ” cancelado.';tr = 'DeÄiÅim Ć¼nitelerinden birinin boÅ bir kodu mevcut. DeÄiÅim iptal edildi.';it = 'Uno dei nodi di scambio ha un codice vuoto. Scambio annullato';de = 'Einer der Exchange-Knoten hat einen leeren Code. Austausch wird abgebrochen.'",
			CommonClientServer.DefaultLanguageCode());
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
	ElsIf ExchangeSettingsStructure.ExportHandlersDebug Then
		
		ExportDataProcessorFile = New File(ExchangeSettingsStructure.ExportDebugExternalDataProcessorFileName);
		
		If Not ExportDataProcessorFile.Exist() Then
			
			ErrorMessageString = NStr("ru = 'Š¤Š°Š¹Š» Š²Š½ŠµŃŠ½ŠµŠ¹ Š¾Š±ŃŠ°Š±Š¾ŃŠŗŠø Š“Š»Ń Š¾ŃŠ»Š°Š“ŠŗŠø Š²ŃŠ³ŃŃŠ·ŠŗŠø Š½Šµ ŃŃŃŠµŃŃŠ²ŃŠµŃ. ŠŠ±Š¼ŠµŠ½ Š¾ŃŠ¼ŠµŠ½ŠµŠ½.'; en = 'External data processor file for export debugging does not exist. Exchange is canceled.'; pl = 'ZewnÄtrzny plik opracowania do debugowania eksportu nie istnieje. Wymiana zostaÅa anulowana.';es_ES = 'Archivo del procesador de datos externo para la depuraciĆ³n de la exportaciĆ³n no existe. Intercambio estĆ” cancelado.';es_CO = 'Archivo del procesador de datos externo para la depuraciĆ³n de la exportaciĆ³n no existe. Intercambio estĆ” cancelado.';tr = 'DÄ±Åa aktarma hata ayÄ±klamasÄ± iĆ§in harici veri iÅlemci dosyasÄ± mevcut deÄil. DeÄiÅim iptal edildi.';it = 'Il file esterno dell''elaboratore dati per il debug dell''esportazione non esiste. Scambio annullato';de = 'Externe Datenprozessordatei fĆ¼r Export-Debugging ist nicht vorhanden. Austausch wird abgebrochen.'",
				CommonClientServer.DefaultLanguageCode());
			WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
			
			SetExchangeInitEnd(ExchangeSettingsStructure);
			
		EndIf;
		
	ElsIf ExchangeSettingsStructure.ImportHandlersDebug Then
		
		ImportDataProcessorFile = New File(ExchangeSettingsStructure.ImportDebugExternalDataProcessorFileName);
		
		If Not ImportDataProcessorFile.Exist() Then
			
			ErrorMessageString = NStr("ru = 'Š¤Š°Š¹Š» Š²Š½ŠµŃŠ½ŠµŠ¹ Š¾Š±ŃŠ°Š±Š¾ŃŠŗŠø Š“Š»Ń Š¾ŃŠ»Š°Š“ŠŗŠø Š·Š°Š³ŃŃŠ·ŠŗŠø Š½Šµ ŃŃŃŠµŃŃŠ²ŃŠµŃ. ŠŠ±Š¼ŠµŠ½ Š¾ŃŠ¼ŠµŠ½ŠµŠ½.'; en = 'External data processor file for import debugging does not exist. Exchange is canceled.'; pl = 'ZewnÄtrzny plik opracowania do debugowania importu nie istnieje. Wymiana zostaÅa anulowana.';es_ES = 'Archivo del procesador de datos externo para la depuraciĆ³n de la importaciĆ³n no existe. Intercambio estĆ” cancelado.';es_CO = 'Archivo del procesador de datos externo para la depuraciĆ³n de la importaciĆ³n no existe. Intercambio estĆ” cancelado.';tr = 'Ä°Ć§e aktarmadaki hata ayÄ±klamasÄ± iĆ§in harici veri iÅlemci dosyasÄ± mevcut deÄil. DeÄiÅim iptal edildi.';it = 'Il file esterno dell''elaboratore dati per il debug dell''importazione non esiste. Scambio annullato';de = 'Externe Datenprozessordatei fĆ¼r Import-Debugging ist nicht vorhanden. Austausch wird abgebrochen.'",
				CommonClientServer.DefaultLanguageCode());
			WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
			
			SetExchangeInitEnd(ExchangeSettingsStructure);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure InitDataExchangeDataProcessor(ExchangeSettingsStructure)
	
	// Canceling initialization if settings contain errors.
	If ExchangeSettingsStructure.Cancel Then
		Return;
	EndIf;
	
	// create
	DataExchangeDataProcessor = DataProcessors.DistributedInfobasesObjectsConversion.Create();
	
	// Initializing properties
	DataExchangeDataProcessor.InfobaseNode          = ExchangeSettingsStructure.InfobaseNode;
	DataExchangeDataProcessor.TransactionItemsCount  = ExchangeSettingsStructure.TransactionItemsCount;
	DataExchangeDataProcessor.EventLogMessageKey = ExchangeSettingsStructure.EventLogMessageKey;
	
	ExchangeSettingsStructure.Insert("DataExchangeDataProcessor", DataExchangeDataProcessor);
	
EndProcedure

Procedure InitDataExchangeDataProcessorForConversionRules(ExchangeSettingsStructure)
	
	Var DataExchangeDataProcessor;
	
	// Canceling initialization if settings contain errors.
	If ExchangeSettingsStructure.Cancel Then
		Return;
	EndIf;
	
	If ExchangeSettingsStructure.DoDataExport Then
		
		DataExchangeDataProcessor = DataExchangeDataProcessorForExport(ExchangeSettingsStructure);
		
	ElsIf ExchangeSettingsStructure.DoDataImport Then
		
		DataExchangeDataProcessor = DataExchangeDataProcessorForImport(ExchangeSettingsStructure);
		
	EndIf;
	
	ExchangeSettingsStructure.Insert("DataExchangeDataProcessor", DataExchangeDataProcessor);
	
EndProcedure

Procedure InitExchangeMessageTransportDataProcessor(ExchangeSettingsStructure)
	
	// Creating the transport data processor.
	ExchangeMessageTransportDataProcessor = DataProcessors[ExchangeSettingsStructure.DataExchangeMessageTransportDataProcessorName].Create();
	
	IsOutgoingMessage = ExchangeSettingsStructure.DoDataExport;
	
	Transliteration = Undefined;
	SettingsGlossary = New Map;
	SettingsGlossary.Insert(Enums.ExchangeMessagesTransportTypes.FILE,  "FILETransliterateExchangeMessageFileNames");
	SettingsGlossary.Insert(Enums.ExchangeMessagesTransportTypes.EMAIL, "EMAILTransliterateExchangeMessageFileNames");
	SettingsGlossary.Insert(Enums.ExchangeMessagesTransportTypes.FTP,   "FTPTransliterateExchangeMessageFileNames");
	
	PropertyNameTransliteration = SettingsGlossary.Get(ExchangeSettingsStructure.ExchangeTransportKind);
	If ValueIsFilled(PropertyNameTransliteration) Then
		ExchangeSettingsStructure.TransportSettings.Property(PropertyNameTransliteration, Transliteration);
	EndIf;
	
	Transliteration = ?(Transliteration = Undefined, False, Transliteration);
	
	// Filling common attributes (same for all transport data processors).
	ExchangeMessageTransportDataProcessor.MessageFileNamePattern = MessageFileNamePattern(
		ExchangeSettingsStructure.CurrentExchangePlanNode,
		ExchangeSettingsStructure.InfobaseNode,
		IsOutgoingMessage,
		Transliteration);
	
	// Filling transport settings (various for each transport data processor).
	FillPropertyValues(ExchangeMessageTransportDataProcessor, ExchangeSettingsStructure.TransportSettings);
	
	// Initialing transport
	ExchangeMessageTransportDataProcessor.Initializing();
	
	ExchangeSettingsStructure.Insert("ExchangeMessageTransportDataProcessor", ExchangeMessageTransportDataProcessor);
	
EndProcedure

Function DataExchangeDataProcessorForExport(ExchangeSettingsStructure)
	
	DataProcessorManager = ?(IsXDTOExchangePlan(ExchangeSettingsStructure.InfobaseNode),
		DataProcessors.ConvertXTDOObjects,
		DataProcessors.InfobaseObjectConversion);
	
	DataExchangeDataProcessor = DataProcessorManager.Create();
	
	DataExchangeDataProcessor.ExchangeMode = "DataExported";
	
	// If the data processor supports the conversion rule mechanism, the following actions can be executed.
	If DataExchangeDataProcessor.Metadata().Attributes.Find("ExchangeRuleFileName") <> Undefined Then
		SetDataExportExchangeRules(DataExchangeDataProcessor, ExchangeSettingsStructure);
		DataExchangeDataProcessor.DoNotExportObjectsByRefs = True;
		DataExchangeDataProcessor.ExchangeRuleFileName        = "1";
	EndIf;
	
	// If the data processor supports the background exchange, the following actions can be executed.
	If DataExchangeDataProcessor.Metadata().Attributes.Find("BackgroundExchangeNode") <> Undefined Then
		DataExchangeDataProcessor.BackgroundExchangeNode = Undefined;
	EndIf;
		
	DataExchangeDataProcessor.NodeForExchange = ExchangeSettingsStructure.InfobaseNode;
	
	SetCommonParametersForDataExchangeProcessing(DataExchangeDataProcessor, ExchangeSettingsStructure);
	
	Return DataExchangeDataProcessor;
	
EndFunction

Function DataExchangeDataProcessorForImport(ExchangeSettingsStructure)
	
	DataProcessorManager = ?(IsXDTOExchangePlan(ExchangeSettingsStructure.InfobaseNode),
		DataProcessors.ConvertXTDOObjects,
		DataProcessors.InfobaseObjectConversion);
	
	DataExchangeDataProcessor = DataProcessorManager.Create();
	
	DataExchangeDataProcessor.ExchangeMode = "Load";
	DataExchangeDataProcessor.ExchangeNodeDataImport = ExchangeSettingsStructure.InfobaseNode;
	
	If DataExchangeDataProcessor.Metadata().Attributes.Find("ExchangeRuleFileName") <> Undefined Then
		SetDataImportExchangeRules(DataExchangeDataProcessor, ExchangeSettingsStructure);
	EndIf;
	
	SetCommonParametersForDataExchangeProcessing(DataExchangeDataProcessor, ExchangeSettingsStructure);
	
	Return DataExchangeDataProcessor
	
EndFunction

Procedure SetCommonParametersForDataExchangeProcessing(DataExchangeDataProcessor, ExchangeSettingsStructure, ExchangeWithSSL20 = False)
	
	DataExchangeDataProcessor.AppendDataToExchangeLog = False;
	DataExchangeDataProcessor.ExportAllowedObjectsOnly      = False;
	
	DataExchangeDataProcessor.UseTransactions         = ExchangeSettingsStructure.TransactionItemsCount <> 1;
	DataExchangeDataProcessor.ObjectCountPerTransaction = ExchangeSettingsStructure.TransactionItemsCount;
	
	DataExchangeDataProcessor.EventLogMessageKey = ExchangeSettingsStructure.EventLogMessageKey;
	
	If Not ExchangeWithSSL20 Then
		
		SetDebugModeSettingsForDataProcessor(DataExchangeDataProcessor, ExchangeSettingsStructure);
		
	EndIf;
	
EndProcedure

Procedure SetDataExportExchangeRules(DataExchangeXMLDataProcessor, ExchangeSettingsStructure)
	
	ObjectConversionRules = InformationRegisters.DataExchangeRules.ParsedRulesOfObjectConversion(ExchangeSettingsStructure.ExchangePlanName);
	
	If ObjectConversionRules = Undefined Then
		
		// Exchange rules must be specified.
		NString = NStr("ru = 'ŠŠµ Š·Š°Š“Š°Š½Ń ŠæŃŠ°Š²ŠøŠ»Š° ŠŗŠ¾Š½Š²ŠµŃŃŠ°ŃŠøŠø Š“Š»Ń ŠæŠ»Š°Š½Š° Š¾Š±Š¼ŠµŠ½Š° %1. ŠŃŠ³ŃŃŠ·ŠŗŠ° Š“Š°Š½Š½ŃŃ Š¾ŃŠ¼ŠµŠ½ŠµŠ½Š°.'; en = 'Conversion rules are not specified for exchange plan %1. Data export is canceled.'; pl = 'Nie okreÅlono reguÅ konwersji dla planu wymiany %1. Eksport danych zostaÅ anulowany.';es_ES = 'Reglas de conversiĆ³n no estĆ”n especificadas para el plan de intercambio %1. ExportaciĆ³n de datos estĆ” cancelada.';es_CO = 'Reglas de conversiĆ³n no estĆ”n especificadas para el plan de intercambio %1. ExportaciĆ³n de datos estĆ” cancelada.';tr = 'DeÄiÅim planÄ± iĆ§in dĆ¶nĆ¼ÅtĆ¼rme kurallarÄ± belirtilmemiÅ. %1Veri dÄ±Åa aktarma iptal edildi.';it = 'Non sono specificate regole di conversione per il piano di scambio %1. l''esportazione dei dati ĆØ stata annullata.';de = 'Konvertierungsregeln sind fĆ¼r den Austauschplan nicht angegeben %1. Der Datenexport ist abgebrochen.'",
			CommonClientServer.DefaultLanguageCode());
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersToString(NString, ExchangeSettingsStructure.ExchangePlanName);
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
		Return;
	EndIf;
	
	DataExchangeXMLDataProcessor.SavedSettings = ObjectConversionRules;
	
	Try
		DataExchangeXMLDataProcessor.RestoreRulesFromInternalFormat();
	Except
		WriteEventLogDataExchange(BriefErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		Return;
	EndTry;
	
EndProcedure

Procedure SetDataImportExchangeRules(DataExchangeXMLDataProcessor, ExchangeSettingsStructure)
	
	ObjectConversionRules = InformationRegisters.DataExchangeRules.ParsedRulesOfObjectConversion(ExchangeSettingsStructure.ExchangePlanName, True);
	
	If ObjectConversionRules = Undefined Then
		
		// Exchange rules must be specified.
		NString = NStr("ru = 'ŠŠµ Š·Š°Š“Š°Š½Ń ŠæŃŠ°Š²ŠøŠ»Š° ŠŗŠ¾Š½Š²ŠµŃŃŠ°ŃŠøŠø Š“Š»Ń ŠæŠ»Š°Š½Š° Š¾Š±Š¼ŠµŠ½Š° %1. ŠŠ°Š³ŃŃŠ·ŠŗŠ° Š“Š°Š½Š½ŃŃ Š¾ŃŠ¼ŠµŠ½ŠµŠ½Š°.'; en = 'Conversion rules are not specified for exchange plan %1. Data import is canceled.'; pl = 'Nie okreÅlono reguÅ konwersji dla planu wymiany %1. Import danych zostaÅ anulowany.';es_ES = 'Reglas de conversiĆ³n no estĆ”n especificadas para el plan de intercambio %1. ImportaciĆ³n de datos estĆ” cancelada.';es_CO = 'Reglas de conversiĆ³n no estĆ”n especificadas para el plan de intercambio %1. ImportaciĆ³n de datos estĆ” cancelada.';tr = 'DeÄiÅim planÄ± iĆ§in dĆ¶nĆ¼ÅtĆ¼rme kurallarÄ± belirtilmemiÅ. %1Veri iĆ§e aktarma iptal edildi.';it = 'Non sono specificate regole di conversione per il piano di scambio %1. L''importazione dei dati ĆØ stata annullata.';de = 'Konvertierungsregeln sind fĆ¼r den Austauschplan nicht angegeben %1. Der Datenimport ist abgebrochen.'",
			CommonClientServer.DefaultLanguageCode());
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersToString(NString, ExchangeSettingsStructure.ExchangePlanName);
		WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		
		Return;
	EndIf;
	
	DataExchangeXMLDataProcessor.SavedSettings = ObjectConversionRules;
	
	Try
		DataExchangeXMLDataProcessor.RestoreRulesFromInternalFormat();
	Except
		WriteEventLogDataExchange(BriefErrorDescription(ErrorInfo()), ExchangeSettingsStructure, True);
		SetExchangeInitEnd(ExchangeSettingsStructure);
		Return;
	EndTry;
	
EndProcedure

// Reads debugging settings from the infobase and sets them for the exchange structure.
//
Procedure SetDebugModeSettingsForStructure(ExchangeSettingsStructure, IsExternalConnection = False)
	
	QueryText = "SELECT
	|	CASE
	|		WHEN &PerformDataExport
	|			THEN DataExchangeRules.ExportDebugMode
	|		ELSE FALSE
	|	END AS ExportHandlersDebug,
	|	CASE
	|		WHEN &PerformDataExport
	|			THEN DataExchangeRules.ExportDebuggingDataProcessorFileName
	|		ELSE """"
	|	END AS ExportDebugExternalDataProcessorFileName,
	|	CASE
	|		WHEN &PerformDataImport
	|			THEN DataExchangeRules.ImportDebugMode
	|		ELSE FALSE
	|	END AS ImportHandlersDebug,
	|	CASE
	|		WHEN &PerformDataImport
	|			THEN DataExchangeRules.ImportDebuggingDataProcessorFileName
	|		ELSE """"
	|	END AS ImportDebugExternalDataProcessorFileName,
	|	DataExchangeRules.DataExchangeLoggingMode AS DataExchangeLoggingMode,
	|	DataExchangeRules.ExchangeProtocolFileName AS ExchangeProtocolFileName,
	|	DataExchangeRules.DoNotStopOnError AS ContinueOnError
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RulesKind = VALUE(Enum.DataExchangeRulesTypes.ObjectConversionRules)
	|	AND DataExchangeRules.DebugMode";
	
	Query = New Query;
	Query.Text = QueryText;
	
	DoDataExport = False;
	If Not ExchangeSettingsStructure.Property("DoDataExport", DoDataExport) Then
		DoDataExport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataExport);
	EndIf;
	
	DoDataImport = False;
	If Not ExchangeSettingsStructure.Property("DoDataImport", DoDataImport) Then
		DoDataImport = (ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataImport);
	EndIf;
	
	Query.SetParameter("ExchangePlanName", ExchangeSettingsStructure.ExchangePlanName);
	Query.SetParameter("PerformDataExport", DoDataExport);
	Query.SetParameter("PerformDataImport", DoDataImport);
	
	Result = Query.Execute();
	
	ProtocolFileName = "";
	If IsExternalConnection AND ExchangeSettingsStructure.Property("ExchangeProtocolFileName", ProtocolFileName)
		AND Not IsBlankString(ProtocolFileName) Then
		
		ExchangeSettingsStructure.ExchangeProtocolFileName = AddLiteralToFileName(ProtocolFileName, "ExternalConnection")
	
	EndIf;
	
	If Not Result.IsEmpty() AND Not Common.DataSeparationEnabled() Then
		
		SettingsTable = Result.Unload();
		TableRow = SettingsTable[0];
		
		FillPropertyValues(ExchangeSettingsStructure, TableRow);
		
	EndIf;
	
EndProcedure

// Reads debugging settings from the infobase and sets them for the structure of exchange settings.
//
Procedure SetDebugModeSettingsForDataProcessor(DataExchangeDataProcessor, ExchangeSettingsStructure)
	
	If ExchangeSettingsStructure.Property("ExportDebugExternalDataProcessorFileName")
		AND DataExchangeDataProcessor.Metadata().Attributes.Find("ExportDebugExternalDataProcessorFileName") <> Undefined Then
		
		DataExchangeDataProcessor.ExportHandlersDebug = ExchangeSettingsStructure.ExportHandlersDebug;
		DataExchangeDataProcessor.ImportHandlersDebug = ExchangeSettingsStructure.ImportHandlersDebug;
		DataExchangeDataProcessor.ExportDebugExternalDataProcessorFileName = ExchangeSettingsStructure.ExportDebugExternalDataProcessorFileName;
		DataExchangeDataProcessor.ImportDebugExternalDataProcessorFileName = ExchangeSettingsStructure.ImportDebugExternalDataProcessorFileName;
		DataExchangeDataProcessor.DataExchangeLoggingMode = ExchangeSettingsStructure.DataExchangeLoggingMode;
		DataExchangeDataProcessor.ExchangeProtocolFileName = ExchangeSettingsStructure.ExchangeProtocolFileName;
		DataExchangeDataProcessor.ContinueOnError = ExchangeSettingsStructure.ContinueOnError;
		
		If ExchangeSettingsStructure.DataExchangeLoggingMode Then
			
			If ExchangeSettingsStructure.ExchangeProtocolFileName = "" Then
				DataExchangeDataProcessor.OutputInfoMessagesInMessageWindow = True;
				DataExchangeDataProcessor.OutputInfoMessagesToProtocol = False;
			Else
				DataExchangeDataProcessor.OutputInfoMessagesInMessageWindow = False;
				DataExchangeDataProcessor.OutputInfoMessagesToProtocol = True;
				DataExchangeDataProcessor.ExchangeProtocolFileName = ExchangeSettingsStructure.ExchangeProtocolFileName;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Sets up export settings for the data processor.
//
Procedure SetExportDebugSettingsForExchangeRules(DataExchangeDataProcessor, ExchangePlanName, DebugMode) Export
	
	QueryText = "SELECT
	|	DataExchangeRules.ExportDebugMode AS ExportHandlersDebug,
	|	DataExchangeRules.ExportDebuggingDataProcessorFileName AS ExportDebugExternalDataProcessorFileName
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RulesKind = VALUE(Enum.DataExchangeRulesTypes.ObjectConversionRules)
	|	AND &DebugMode = TRUE";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	Query.SetParameter("DebugMode", DebugMode);
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Or Common.DataSeparationEnabled() Then
		
		DataExchangeDataProcessor.ExportHandlersDebug = False;
		DataExchangeDataProcessor.ExportDebugExternalDataProcessorFileName = "";
		
	Else
		
		SettingsTable = Result.Unload();
		DebuggingSettings = SettingsTable[0];
		
		FillPropertyValues(DataExchangeDataProcessor, DebuggingSettings);
		
	EndIf;
	
EndProcedure

Procedure SetExchangeInitEnd(ExchangeSettingsStructure)
	
	ExchangeSettingsStructure.Cancel = True;
	ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
	
EndProcedure

Function MessageFileNamePattern(CurrentExchangePlanNode, InfobaseNode, IsOutgoingMessage, Transliteration = False, UseVirtualNodeCodeOnGet = False) Export
	
	If IsOutgoingMessage Then
		SenderCode = NodeIDForExchange(InfobaseNode);
		RecipientCode  = CorrespondentNodeIDForExchange(InfobaseNode);
	Else
		SenderCode = CorrespondentNodeIDForExchange(InfobaseNode);
		RecipientCode  = NodeIDForExchange(InfobaseNode);
	EndIf;
	
	If IsOutgoingMessage Or UseVirtualNodeCodeOnGet Then
		// Exchange with a correspondent which is unfamiliar with a new predefined node code - upon 
		// generating an exchange message file name, the register code is used instead of a predefined node code.
		PredefinedNodeAlias = PredefinedNodeAlias(InfobaseNode);
		If ValueIsFilled(PredefinedNodeAlias) Then
			If IsOutgoingMessage Then
				SenderCode = PredefinedNodeAlias;
			Else
				RecipientCode = PredefinedNodeAlias;
			EndIf;
		EndIf;
	EndIf;
	
	// Considering the transliteration setting for the exchange plan node.
	If Transliteration Then
		SenderCode = StringFunctionsClientServer.LatinString(SenderCode);
		RecipientCode = StringFunctionsClientServer.LatinString(RecipientCode);
	EndIf;
	
	Return ExchangeMessageFileName(SenderCode, RecipientCode, IsOutgoingMessage);
	
EndFunction

Function PredefinedNodeAlias(CorrespondentNode) Export
	
	If Not IsXDTOExchangePlan(CorrespondentNode) Then
		Return "";
	EndIf;
	
	Query = New Query(
	"SELECT
	|	PredefinedNodesAliases.NodeCode AS NodeCode
	|FROM
	|	InformationRegister.PredefinedNodesAliases AS PredefinedNodesAliases
	|WHERE
	|	PredefinedNodesAliases.Correspondent = &InfobaseNode");
	Query.SetParameter("InfobaseNode", CorrespondentNode);
	
	PredefinedNodeAlias = "";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		PredefinedNodeAlias = TrimAll(Selection.NodeCode);
	EndIf;
	
	Return PredefinedNodeAlias;
	
EndFunction

Procedure CheckNodesCodes(DataAnalysisResultToExport, InfobaseNode) Export
	If NOT IsXDTOExchangePlan(InfobaseNode) Then
		Return;
	EndIf;

	IBNodeCode = Common.ObjectAttributeValue(InfobaseNode,"Code");
	If ValueIsFilled(DataAnalysisResultToExport.NewFrom) Then
		CorrespondentNodeRecoded = (IBNodeCode = DataAnalysisResultToExport.NewFrom);
		If NOT CorrespondentNodeRecoded
			AND DataExchangeXDTOServer.VersionWithDataExchangeIDSupported(InfobaseNode) Then
			ExchangeNodeObject = InfobaseNode.GetObject();
			ExchangeNodeObject.Code = DataAnalysisResultToExport.NewFrom;
			ExchangeNodeObject.DataExchange.Load = True;
			ExchangeNodeObject.Write();
			CorrespondentNodeRecoded = True;
		EndIf;
	Else
		CorrespondentNodeRecoded = True;
	EndIf;
	If CorrespondentNodeRecoded Then
		PredefinedNodeAlias = PredefinedNodeAlias(InfobaseNode);
		If ValueIsFilled(PredefinedNodeAlias)
			AND DataAnalysisResultToExport.CorrespondentSupportsDataExchangeID Then
			// This might be a good time to delete the record. Checking the To section.
			ExchangePlanName = InfobaseNode.Metadata().Name;
			PredefinedNodeCode = CodeOfPredefinedExchangePlanNode(ExchangePlanName);
			If TrimAll(PredefinedNodeCode) = DataAnalysisResultToExport.To Then
				DeleteRecordSetFromInformationRegister(New Structure("Correspondent", InfobaseNode),
					"PredefinedNodesAliases");
			EndIf;
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region DataExchangeIssuesDashboardOperations

Function DataExchangeIssueCount(ExchangeNodes = Undefined)
	
	Return InformationRegisters.DataExchangeResults.IssuesCount(ExchangeNodes, Undefined);
	
EndFunction

Function VersioningIssuesCount(ExchangeNodes = Undefined, Val QueryOptions = Undefined) Export
	
	If QueryOptions = Undefined Then
		QueryOptions = QueryParametersVersioningIssuesCount();
	EndIf;
	
	VersioningUsed = DataExchangeCached.VersioningUsed(, True);
	
	If VersioningUsed Then
		ModuleObjectVersioning = Common.CommonModule("ObjectsVersioning");
		Return ModuleObjectVersioning.ConflictOrRejectedItemCount(
			ExchangeNodes,
			QueryOptions.IsConflictCount,
			QueryOptions.IncludingIgnored,
			QueryOptions.Period,
			QueryOptions.SearchString);
	EndIf;
		
	Return 0;
	
EndFunction

Function QueryParametersVersioningIssuesCount() Export
	
	Result = New Structure;
	
	Result.Insert("IsConflictCount",      Undefined);
	Result.Insert("IncludingIgnored", False);
	Result.Insert("Period",                     Undefined);
	Result.Insert("SearchString",               "");
	
	Return Result;
	
EndFunction

// Registers errors upon deferred document posting in the exchange issue monitor.
//
// Parameters:
//	Object - DocumentObject - errors occurred during deferred posting of this document.
//	ExchangeNode - ExchangePlanRef - an infobase node the document is received from.Ā 
//	ErrorMessage - String - a message text for the event log.
//    It is recommended to pass the result of BriefErrorDescription(ErrorInfo()) in this parameter.
//    Message text to display in the monitor is compiled from system user messages that are 
//    generated but are not displayed to a user yet. Therefore, we recommend you to delete cached 
//    messages before calling this method.
//	RecordIssuesInExchangeResults - Boolean - issues must be registered.
//
// Example:
// Procedure PostDocumentOnImport(Document, ExchangeNode)
// Document.DataExchange.Import = True.
// Document.Write();
// Document.DataExchange.Import = False.
// Cancel = False;
//
// Try
// 	Document.Write(DocumentWriteMode.Posting);
// Except
// 	ErrorMessage = BriefErrorPresentation(ErrorInformation());
// 	Cancel = True;
// EndTry;
//
// If Cancel Then
// 	DataExchangeServer.RecordDocumentPostingError(Document, ExchangeNOde, ErrorMessage);
// EndIf
//
// EndProcedure;
//
Procedure RecordDocumentPostingError(
		Object,
		ExchangeNode,
		ExceptionText,
		RecordIssuesInExchangeResults = True) Export
	
	UserMessages = GetUserMessages(True);
	MessageText = ExceptionText;
	For Each Message In UserMessages Do
		If StrFind(Message.Text, TimeConsumingOperations.ProgressMessage()) > 0 Then
			Continue;
		EndIf;
		MessageText = MessageText + ?(IsBlankString(MessageText), "", Chars.LF) + Message.Text;
	EndDo;
	
	ErrorReason = MessageText;
	If Not IsBlankString(TrimAll(MessageText)) Then
		
		ErrorReason = " " + NStr("ru = 'ŠŠ¾ ŠæŃŠøŃŠøŠ½Šµ %1.'; en = 'The error occurred due to %1.'; pl = 'Z powodu %1.';es_ES = 'A causa de %1.';es_CO = 'A causa de %1.';tr = '%1 nedeniyle.';it = 'L''errore si ĆØ registrato a causa di %1.';de = 'Aus dem Grund %1.'");
		ErrorReason = StringFunctionsClientServer.SubstituteParametersToString(ErrorReason, MessageText);
		
	EndIf;
	
	MessageString = NStr("ru = 'ŠŠµ ŃŠ“Š°Š»Š¾ŃŃ ŠæŃŠ¾Š²ŠµŃŃŠø Š“Š¾ŠŗŃŠ¼ŠµŠ½Ń %1, ŠæŠ¾Š»ŃŃŠµŠ½Š½ŃŠ¹ ŠøŠ· Š“ŃŃŠ³Š¾Š¹ ŠøŠ½ŃŠ¾ŃŠ¼Š°ŃŠøŠ¾Š½Š½Š¾Š¹ Š±Š°Š·Ń.%2
		|ŠŠ¾Š·Š¼Š¾Š¶Š½Š¾ Š½Šµ Š·Š°ŠæŠ¾Š»Š½ŠµŠ½Ń Š²ŃŠµ ŃŠµŠŗŠ²ŠøŠ·ŠøŃŃ, Š¾Š±ŃŠ·Š°ŃŠµŠ»ŃŠ½ŃŠµ Šŗ Š·Š°ŠæŠ¾Š»Š½ŠµŠ½ŠøŃ.'; 
		|en = 'Cannot post document %1 received from another infobase. %2
		|Maybe not all required attributes are filled in.'; 
		|pl = 'Nie udaÅo siÄ zaksiÄgowaÄ dokument %1, otrzymany z innej bazy informacyjnej.%2
		|MoÅ¼liwie, Å¼e nie sÄ wypeÅnione wszystkie atrybuty, obowiÄzkowe do wypeÅnienia.';
		|es_ES = 'No se ha podido validar el documento %1 recibido de otra base de informaciĆ³n.%2
		|Es posible que no todos los requisitos estĆ©n rellenados que son obligatorios para rellenar.';
		|es_CO = 'No se ha podido validar el documento %1 recibido de otra base de informaciĆ³n.%2
		|Es posible que no todos los requisitos estĆ©n rellenados que son obligatorios para rellenar.';
		|tr = 'BaÅka bir veritabanÄ±ndan %1 alÄ±nan belge gĆ¶nderilemedi. %2
		|TĆ¼m gerekli Ć¶zellikler doldurulmamÄ±Å olabilir.';
		|it = 'Impossibile pubblicare il documento %1 ricevuto da un altro infobase. %2
		|Potrebbero non essere stati compilati tutti gli attributi richiesti.';
		|de = 'Das Dokument %1, das von einer anderen Infobase empfangen wurde, konnte nicht gebucht werden.%2
		|Wahrscheinlich sind nicht alle Details ausgefĆ¼llt, die ausgefĆ¼llt werden mĆ¼ssen.'",
		CommonClientServer.DefaultLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, String(Object), ErrorReason);
	
	WriteLogEvent(EventLogMessageTextDataExchange(), EventLogLevel.Warning,,, MessageString);
	
	If RecordIssuesInExchangeResults Then
		InformationRegisters.DataExchangeResults.RecordDocumentCheckError(Object.Ref, ExchangeNode,
			MessageText, Enums.DataExchangeIssuesTypes.UnpostedDocument);
	EndIf;
	
EndProcedure

// Registers errors upon deferred object writing in the exchange issue monitor.
//
// Parameters:
//	Object - Object of reference type - errors occurred during deferred writing of this object.
//	ExchangeNode - ExchangePlanRef - an infobase node the object is received from.Ā 
//	ErrorMessage - String - a message text for the event log.
//    It is recommended to pass the result of BriefErrorDescription(ErrorInfo()) in this parameter.
//    Message text to display in the monitor is compiled from system user messages that are 
//    generated but are not displayed to a user yet. Therefore, we recommend you to delete cached 
//    messages before calling this method.
//
// Example:
// Procedure WriteObjectOnImport(Object, ExchangeNode)
// Object.DataExchange.Import = True.
// Object.Write();
// Object.DataExchange.Import = False.
// Cancel = False;
//
// Try
// 	Object.Write();
// Except
// 	ErrorMessage = BriefErrorPresentation(ErrorInformation());
// 	Cancel = True;
// EndTry;
//
// If Cancel Then
// 	DataExchangeServer.RecordObjectWriteError(Object, ExchangeNode, ErrorMessage);
// EndIf
//
// EndProcedure;
//
Procedure RecordObjectWriteError(Object, ExchangeNode, ExceptionText) Export
	
	UserMessages = GetUserMessages(True);
	MessageText = ExceptionText;
	For Each Message In UserMessages Do
		If StrFind(Message.Text, TimeConsumingOperations.ProgressMessage()) > 0 Then
			Continue;
		EndIf;
		MessageText = MessageText + ?(IsBlankString(MessageText), "", Chars.LF) + Message.Text;
	EndDo;
	
	ErrorReason = MessageText;
	If Not IsBlankString(TrimAll(MessageText)) Then
		
		ErrorReason = " " + NStr("ru = 'ŠŠ¾ ŠæŃŠøŃŠøŠ½Šµ %1.'; en = 'The error occurred due to %1.'; pl = 'Z powodu %1.';es_ES = 'A causa de %1.';es_CO = 'A causa de %1.';tr = '%1 nedeniyle.';it = 'L''errore si ĆØ registrato a causa di %1.';de = 'Aus dem Grund %1.'");
		ErrorReason = StringFunctionsClientServer.SubstituteParametersToString(ErrorReason, MessageText);
		
	EndIf;
	
	MessageString = NStr("ru = 'ŠŠµ ŃŠ“Š°Š»Š¾ŃŃ Š·Š°ŠæŠøŃŠ°ŃŃ Š¾Š±ŃŠµŠŗŃ %1, ŠæŠ¾Š»ŃŃŠµŠ½Š½ŃŠ¹ ŠøŠ· Š“ŃŃŠ³Š¾Š¹ ŠøŠ½ŃŠ¾ŃŠ¼Š°ŃŠøŠ¾Š½Š½Š¾Š¹ Š±Š°Š·Ń.%2
		|ŠŠ¾Š·Š¼Š¾Š¶Š½Š¾ Š½Šµ Š·Š°ŠæŠ¾Š»Š½ŠµŠ½Ń Š²ŃŠµ ŃŠµŠŗŠ²ŠøŠ·ŠøŃŃ, Š¾Š±ŃŠ·Š°ŃŠµŠ»ŃŠ½ŃŠµ Šŗ Š·Š°ŠæŠ¾Š»Š½ŠµŠ½ŠøŃ.'; 
		|en = 'Cannot write object %1 received from another infobase. %2
		|Maybe not all required attributes are filled in.'; 
		|pl = 'Nie udaÅo siÄ zapisaÄ obiekt %1, otrzymany z innej bazy informacyjnej.%2
		|MoÅ¼liwie, Å¼e nie sÄ wypeÅnione wszystkie atrybuty, obowiÄzkowe do wypeÅnienia.';
		|es_ES = 'No se ha podido guardar el objeto %1 recibido de otra base de informaciĆ³n.%2
		|Es posible que no todos los requisitos estĆ©n rellenados que son obligatorios para rellenar.';
		|es_CO = 'No se ha podido guardar el objeto %1 recibido de otra base de informaciĆ³n.%2
		|Es posible que no todos los requisitos estĆ©n rellenados que son obligatorios para rellenar.';
		|tr = 'BaÅka bir Infobase''den alÄ±nan %1 nesnesi yazÄ±lamadÄ±. %2
		|TĆ¼m gerekli Ć¶zellikler doldurulmamÄ±Å olabilir.';
		|it = 'Impossibile scrivere l''oggetto %1 ricevuto da un''altra infobase. %2
		|Probabilmente non tutti gli attributi richiesti sono compilati.';
		|de = 'Objekt %1 aus einer anderen Infobase konnte nicht geschrieben werden.%2
		|Wahrscheinlich sind nicht alle Details ausgefĆ¼llt, die ausgefĆ¼llt werden mĆ¼ssen.'",
		CommonClientServer.DefaultLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, String(Object), ErrorReason);
	
	WriteLogEvent(EventLogMessageTextDataExchange(), EventLogLevel.Warning,,, MessageString);
	
	InformationRegisters.DataExchangeResults.RecordDocumentCheckError(Object.Ref, ExchangeNode,
		MessageText, Enums.DataExchangeIssuesTypes.BlankAttributes);
	
EndProcedure

#EndRegion

#Region ProgressBar

// Calculating the number ofĀ infobase objects to be exported upon initial image creation.
//
// Parameters:
// Recipient - an exchange plan object.
//
// Returns number.
Function CalculateObjectsCountInDatabase(Recipient)
	
	ExchangePlanName = Recipient.Metadata().Name;
	ObjectCounter = 0;
	ExchangePlanComposition = Metadata.ExchangePlans[ExchangePlanName].Content;
	
	// 1. Reference objects.
	RefObjectsStructure = New Structure;
	RefObjectsStructure.Insert("Catalog", Metadata.Catalogs);
	RefObjectsStructure.Insert("Document", Metadata.Documents);
	RefObjectsStructure.Insert("ChartOfCharacteristicTypes", Metadata.ChartsOfCharacteristicTypes);
	RefObjectsStructure.Insert("ChartOfCalculationTypes", Metadata.ChartsOfCalculationTypes);
	RefObjectsStructure.Insert("ChartOfAccounts", Metadata.ChartsOfAccounts);
	RefObjectsStructure.Insert("BusinessProcess", Metadata.BusinessProcesses);
	RefObjectsStructure.Insert("Task", Metadata.Tasks);
	RefObjectsStructure.Insert("ChartOfAccounts", Metadata.ChartsOfAccounts);

	QueryText = "SELECT 
	|Count(Ref) AS ObjectCount
	|FROM ";
	For Each RefObject In RefObjectsStructure Do
		For Each MetadataObject In RefObject.Value Do
			If ExchangePlanComposition.Find(MetadataObject) = Undefined Then
				Continue;
			EndIf;
			FullObjectName = RefObject.Key +"."+MetadataObject.Name;
			Query = New Query;
			Query.Text = QueryText + FullObjectName;
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				ObjectCounter = ObjectCounter + Selection.ObjectCount;
			EndIf;
		EndDo;
	EndDo;
	
	// 2. Constants
	For Each MetadataObject In Metadata.Constants Do
		If ExchangePlanComposition.Find(MetadataObject) = Undefined Then
			Continue;
		EndIf;
		ObjectCounter = ObjectCounter + 1;
	EndDo;

	// 3. Information registers.
	QueryText = "SELECT 
	|Count(*) AS ObjectCount
	|FROM ";
	QueryTextWithRecorder = "SELECT 
	|Count(DISTINCT Recorder) AS ObjectCount
	|FROM ";
	For Each MetadataObject In Metadata.InformationRegisters Do
		If ExchangePlanComposition.Find(MetadataObject) = Undefined Then
			Continue;
		EndIf;
		FullObjectName = "InformationRegister."+MetadataObject.Name;
		Query = New Query;
		If MetadataObject.InformationRegisterPeriodicity = Metadata.ObjectProperties.InformationRegisterPeriodicity.RecorderPosition Then
			Query.Text = QueryTextWithRecorder + FullObjectName;
		Else
			Query.Text = QueryText + FullObjectName;
		EndIf;
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			ObjectCounter = ObjectCounter + Selection.ObjectCount;
		EndIf;
	EndDo;
	
	// 4. Registers (subordinate to a recorder) and sequences.
	RegistersStructure = New Structure;
	RegistersStructure.Insert("AccumulationRegister", Metadata.AccumulationRegisters);
	RegistersStructure.Insert("CalculationRegister", Metadata.CalculationRegisters);
	RegistersStructure.Insert("AccountingRegister", Metadata.AccountingRegisters);
	RegistersStructure.Insert("Sequence", Metadata.Sequences);

	QueryText = QueryTextWithRecorder;
	For Each Register In RegistersStructure Do
		For Each MetadataObject In Register.Value Do
			If ExchangePlanComposition.Find(MetadataObject) = Undefined Then
				Continue;
			EndIf;
			FullObjectName = Register.Key +"."+MetadataObject.Name;
			Query = New Query;
			Query.Text = QueryText + FullObjectName;
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				ObjectCounter = ObjectCounter + Selection.ObjectCount;
			EndIf;
		EndDo;
	EndDo;

	Return ObjectCounter;
	
EndFunction

// Calculating the number of objects registered in the exchange plan.
//
// Parameters:
// Recipient - an exchange plan object.
//
// Returns number.
Function CalculateRegisteredObjectsCount(Recipient) Export
	
	ChangesSelection = ExchangePlans.SelectChanges(Recipient.Ref, Recipient.SentNo + 1);
	ObjectsToExportCount = 0;
	While ChangesSelection.Next() Do
		ObjectsToExportCount = ObjectsToExportCount + 1;
	EndDo;
	Return ObjectsToExportCount;
	
EndFunction

#EndRegion

#Region Common

Function AdditionalExchangePlanPropertiesAsString(Val PropertiesAsString)
	
	Result = "";
	
	Template = "ExchangePlans.[PropertyAsString] AS [PropertyAsString]";
	
	ArrayProperties = StrSplit(PropertiesAsString, ",", False);
	
	For Each PropertyAsString In ArrayProperties Do
		
		PropertyAsStringInQuery = StrReplace(Template, "[PropertyAsString]", PropertyAsString);
		
		Result = Result + PropertyAsStringInQuery + ", ";
		
	EndDo;
	
	Return Result;
EndFunction

Function ExchangePlanFilterByDataSeparationFlag(ExchangePlansArray)
	
	Result = New Array;
	
	If Common.DataSeparationEnabled() Then
		
		If Common.SeparatedDataUsageAvailable() Then
			
			For Each ExchangePlanName In ExchangePlansArray Do
				
				If Common.SubsystemExists("StandardSubsystems.SaaS") Then
					ModuleSaaS = Common.CommonModule("SaaS");
					IsSeparatedMetadataObject = ModuleSaaS.IsSeparatedMetadataObject("ExchangePlan." + ExchangePlanName);
				Else
					IsSeparatedMetadataObject = False;
				EndIf;
				
				If IsSeparatedMetadataObject Then
					
					Result.Add(ExchangePlanName);
					
				EndIf;
				
			EndDo;
			
		Else
			
			For Each ExchangePlanName In ExchangePlansArray Do
				
				If Common.SubsystemExists("StandardSubsystems.SaaS") Then
					ModuleSaaS = Common.CommonModule("SaaS");
					IsSeparatedMetadataObject = ModuleSaaS.IsSeparatedMetadataObject("ExchangePlan." + ExchangePlanName);
				Else
					IsSeparatedMetadataObject = False;
				EndIf;
				
				If Not IsSeparatedMetadataObject Then
					
					Result.Add(ExchangePlanName);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	Else
		
		For Each ExchangePlanName In ExchangePlansArray Do
			
			Result.Add(ExchangePlanName);
			
		EndDo;
		
	EndIf;
	
	Return Result;
EndFunction

Function ExchangePlanFilterByStandaloneModeFlag(ExchangePlansArray)
	
	Result = New Array;
	
	For Each ExchangePlanName In ExchangePlansArray Do
		
		If ExchangePlanName <> DataExchangeCached.StandaloneModeExchangePlan() Then
			
			Result.Add(ExchangePlanName);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// Deletes obsolete records from the information register.
// The record is considered obsolete if the exchange plan that includes the record was renamed or 
// deleted.
//
// Parameters:
//  No.
// 
Procedure DeleteObsoleteRecordsFromDataExchangeRuleRegister()
	
	Query = New Query(
	"SELECT DISTINCT
	|	DataExchangeRules.ExchangePlanName AS ExchangePlanName
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	NOT DataExchangeRules.ExchangePlanName IN (&SSLExchangePlans)");
	Query.SetParameter("SSLExchangePlans", DataExchangeCached.SSLExchangePlans());
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
			
		RecordSet = CreateInformationRegisterRecordSet(New Structure("ExchangePlanName", Selection.ExchangePlanName),
			"DataExchangeRules");
		RecordSet.Write();
		
	EndDo;
	
EndProcedure

Procedure GetExchangePlansForMonitor(TempTablesManager, ExchangePlansArray, Val ExchangePlanAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	// The logic for the query generation is in a separate function.
	QueryOptions = ExchangePlansForMonitorQueryParameters();
	QueryOptions.ExchangePlansArray                 = ExchangePlansArray;
	QueryOptions.ExchangePlanAdditionalProperties = ExchangePlanAdditionalProperties;
	QueryOptions.ResultToTemporaryTable       = True;
	Query.Text = ExchangePlansForMonitorQueryText(QueryOptions);
	Query.Execute();
	
EndProcedure

// Function for declaring the parameter structure of the ExchangePlansForMonitorQueryText function.
//
// Parameters:
//   No.
//
// Returns:
//   Structure.
//
Function ExchangePlansForMonitorQueryParameters()
	
	QueryOptions = New Structure;
	QueryOptions.Insert("ExchangePlansArray",                 New Array);
	QueryOptions.Insert("ExchangePlanAdditionalProperties", "");
	QueryOptions.Insert("ResultToTemporaryTable",       False);
	
	Return QueryOptions;
	
EndFunction

// Returns the query text to get the data of the exchange plane nodes.
//
// Parameters:
//   QueryOptions - Structure - a parameter structure (see the ExchangePlansForMonitorQueryParameters function):
//     * ExchangePlansArray - Array - names of SSL exchange plans. All SSL exchange plans by default.
//     * ExchangePlanAdditionalProperties - String - properties of nodes with values being received.
//                                                    default value: empty string.
//     * ResultToTemporaryTable       - Boolean - if True, the query describes storing the result to 
//                                                    the ConfigurationExchangePlansĀ temporary table.
//                                                    The default value is False.
//   ExcludeStandaloneModeExchangePlans - Boolean - if True, standalone mode exchange plans are 
//                                                    excluded from a query text.
//
// Returns:
//   String - a query resulting text.
//
Function ExchangePlansForMonitorQueryText(QueryOptions = Undefined, ExcludeStandaloneModeExchangePlans = True) Export
	
	If QueryOptions = Undefined Then
		QueryOptions = ExchangePlansForMonitorQueryParameters();
	EndIf;
	
	ExchangePlansArray                 = QueryOptions.ExchangePlansArray;
	ExchangePlanAdditionalProperties = QueryOptions.ExchangePlanAdditionalProperties;
	ResultToTemporaryTable       = QueryOptions.ResultToTemporaryTable;
	
	If Not ValueIsFilled(ExchangePlansArray) Then
		ExchangePlansArray = DataExchangeCached.SSLExchangePlans();
	EndIf;
	
	MethodExchangePlans = ExchangePlanFilterByDataSeparationFlag(ExchangePlansArray);
	
	If DataExchangeCached.StandaloneModeSupported()
		AND ExcludeStandaloneModeExchangePlans Then
		
		// Using separate monitor for the exchange plan of the standalone mode.
		MethodExchangePlans = ExchangePlanFilterByStandaloneModeFlag(MethodExchangePlans);
		
	EndIf;
	
	AdditionalExchangePlanPropertiesAsString = ?(IsBlankString(ExchangePlanAdditionalProperties), "", ExchangePlanAdditionalProperties + ", ");
	
	QueryTemplate = "
	|
	|UNION ALL
	|
	|//////////////////////////////////////////////////////// {[ExchangePlanName]}
	|SELECT
	|
	|	[ExchangePlanAdditionalProperties]
	|
	|	Ref                      AS InfobaseNode,
	|	Description                AS Description,
	|	""[ExchangePlanNameSynonym]"" AS ExchangePlanName
	|FROM
	|	ExchangePlan.[ExchangePlanName]
	|WHERE
	|	     NOT ThisNode
	|	AND NOT DeletionMark
	|";
	
	QueryText = "";
	
	If MethodExchangePlans.Count() > 0 Then
		
		For Each ExchangePlanName In MethodExchangePlans Do
			
			ExchangePlanQueryText = StrReplace(QueryTemplate,              "[ExchangePlanName]",        ExchangePlanName);
			ExchangePlanQueryText = StrReplace(ExchangePlanQueryText, "[ExchangePlanNameSynonym]", Metadata.ExchangePlans[ExchangePlanName].Synonym);
			ExchangePlanQueryText = StrReplace(ExchangePlanQueryText, "[ExchangePlanAdditionalProperties]", AdditionalExchangePlanPropertiesAsString);
			
			// Deleting the literal that is used to perform table union for the first table.
			If IsBlankString(QueryText) Then
				
				ExchangePlanQueryText = StrReplace(ExchangePlanQueryText, "UNION ALL", "");
				
			EndIf;
			
			QueryText = QueryText + ExchangePlanQueryText;
			
		EndDo;
		
	Else
		
		AdditionalPropertiesWithoutDataSourceAsString = "";
		
		If Not IsBlankString(ExchangePlanAdditionalProperties) Then
			
			AdditionalProperties = StrSplit(ExchangePlanAdditionalProperties, ",");
			
			AdditionalPropertiesWithoutDataSource = New Array;
			
			For Each Property In AdditionalProperties Do
				
				AdditionalPropertiesWithoutDataSource.Add(StrReplace("Undefined AS [Property]", "[Property]", Property));
				
			EndDo;
			
			AdditionalPropertiesWithoutDataSourceAsString = StrConcat(AdditionalPropertiesWithoutDataSource, ",") + ", ";
			
		EndIf;
		
		QueryText = "
		|SELECT
		|
		|	[AdditionalPropertiesWithoutDataSourceAsString]
		|
		|	Undefined AS InfobaseNode,
		|	Undefined AS Description,
		|	Undefined AS ExchangePlanName
		|";
		
		QueryText = StrReplace(QueryText, "[AdditionalPropertiesWithoutDataSourceAsString]", AdditionalPropertiesWithoutDataSourceAsString);
		
	EndIf;
	
	QueryTextResult = "
	|//////////////////////////////////////////////////////// {ConfigurationExchangePlans}
	|SELECT
	|
	|	[ExchangePlanAdditionalProperties]
	|
	|	InfobaseNode,
	|	Description,
	|	ExchangePlanName
	| [PutInTemporaryTable]
	|FROM
	|	(
	|	[QueryText]
	|	) AS NestedQuery
	|;
	|";
	
	
	QueryTextResult = StrReplace(QueryTextResult, "[PutInTemporaryTable]",
		?(ResultToTemporaryTable, "INTO ConfigurationExchangePlans", ""));
	QueryTextResult = StrReplace(QueryTextResult, "[QueryText]", QueryText);
	QueryTextResult = StrReplace(QueryTextResult, "[ExchangePlanAdditionalProperties]", AdditionalExchangePlanPropertiesAsString);
	
	Return QueryTextResult;
	
EndFunction

Procedure GetDataExchangeStates(TempTablesManager)
	
	Query = New Query;
	
	If Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable() Then
		QueryTextResult =
		"SELECT
		|	DataExchangesStates.InfobaseNode AS InfobaseNode,
		|	DataExchangesStates.EndDate AS StartDate,
		|	DataExchangesStates.EndDate AS EndDate,
		|	CASE
		|		WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Warning_ExchangeMessageAlreadyAccepted)
		|				OR DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
		|			THEN 2
		|		WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
		|			THEN CASE
		|					WHEN ISNULL(IssuesCount.Count, 0) > 0
		|						THEN 2
		|					ELSE 0
		|				END
		|		ELSE 1
		|	END AS ExchangeExecutionResult
		|INTO DataExchangeStatesImport
		|FROM
		|	InformationRegister.DataAreaDataExchangeStates AS DataExchangesStates
		|		LEFT JOIN IssuesCount AS IssuesCount
		|		ON DataExchangesStates.InfobaseNode = IssuesCount.InfobaseNode
		|WHERE
		|	DataExchangesStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DataExchangesStates.InfobaseNode AS InfobaseNode,
		|	DataExchangesStates.EndDate AS StartDate,
		|	DataExchangesStates.EndDate AS EndDate,
		|	CASE
		|		WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
		|			THEN 0
		|		WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
		|			THEN 2
		|		ELSE 1
		|	END AS ExchangeExecutionResult
		|INTO DataExchangeStatesExport
		|FROM
		|	InformationRegister.DataAreaDataExchangeStates AS DataExchangesStates
		|WHERE
		|	DataExchangesStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataExport)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SuccessfulDataExchangesStates.InfobaseNode AS InfobaseNode,
		|	SuccessfulDataExchangesStates.EndDate AS EndDate
		|INTO SuccessfulDataExchangeStatesImport
		|FROM
		|	InformationRegister.DataAreasSuccessfulDataExchangeStates AS SuccessfulDataExchangesStates
		|WHERE
		|	SuccessfulDataExchangesStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SuccessfulDataExchangesStates.InfobaseNode AS InfobaseNode,
		|	SuccessfulDataExchangesStates.EndDate AS EndDate
		|INTO SuccessfulDataExchangeStatesExport
		|FROM
		|	InformationRegister.DataAreasSuccessfulDataExchangeStates AS SuccessfulDataExchangesStates
		|WHERE
		|	SuccessfulDataExchangesStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataExport)
		|;";
	Else
		QueryTextResult =
		"SELECT
		|	DataExchangesStates.InfobaseNode AS InfobaseNode,
		|	DataExchangesStates.EndDate AS StartDate,
		|	DataExchangesStates.EndDate AS EndDate,
		|	CASE
		|		WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Warning_ExchangeMessageAlreadyAccepted)
		|				OR DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
		|			THEN 2
		|		WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
		|			THEN CASE
		|					WHEN ISNULL(IssuesCount.Count, 0) > 0
		|						THEN 2
		|					ELSE 0
		|				END
		|		ELSE 1
		|	END AS ExchangeExecutionResult
		|INTO DataExchangeStatesImport
		|FROM
		|	InformationRegister.DataExchangesStates AS DataExchangesStates
		|		LEFT JOIN IssuesCount AS IssuesCount
		|		ON DataExchangesStates.InfobaseNode = IssuesCount.InfobaseNode
		|WHERE
		|	DataExchangesStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DataExchangesStates.InfobaseNode AS InfobaseNode,
		|	DataExchangesStates.EndDate AS StartDate,
		|	DataExchangesStates.EndDate AS EndDate,
		|	CASE
		|		WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
		|			THEN 0
		|		WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
		|			THEN 2
		|		ELSE 1
		|	END AS ExchangeExecutionResult
		|INTO DataExchangeStatesExport
		|FROM
		|	InformationRegister.DataExchangesStates AS DataExchangesStates
		|WHERE
		|	DataExchangesStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataExport)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SuccessfulDataExchangesStates.InfobaseNode AS InfobaseNode,
		|	SuccessfulDataExchangesStates.EndDate AS EndDate
		|INTO SuccessfulDataExchangeStatesImport
		|FROM
		|	InformationRegister.SuccessfulDataExchangesStates AS SuccessfulDataExchangesStates
		|WHERE
		|	SuccessfulDataExchangesStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SuccessfulDataExchangesStates.InfobaseNode AS InfobaseNode,
		|	SuccessfulDataExchangesStates.EndDate AS EndDate
		|INTO SuccessfulDataExchangeStatesExport
		|FROM
		|	InformationRegister.SuccessfulDataExchangesStates AS SuccessfulDataExchangesStates
		|WHERE
		|	SuccessfulDataExchangesStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataExport)
		|;";
	EndIf;
	
	Query.Text = QueryTextResult;
	Query.TempTablesManager = TempTablesManager;
	Query.Execute();
	
EndProcedure

Procedure GetExchangeResultsForMonitor(TempTablesManager)
	
	Query = New Query;
	
	If Common.SeparatedDataUsageAvailable() Then
		
		QueryTextResult = "
		|SELECT
		|	DataExchangeResults.InfobaseNode AS InfobaseNode,
		|	COUNT(DISTINCT DataExchangeResults.ObjectWithIssue) AS Count
		|INTO IssuesCount
		|FROM
		|	InformationRegister.DataExchangeResults AS DataExchangeResults
		|WHERE
		|	DataExchangeResults.Skipped = FALSE
		|
		|GROUP BY
		|	DataExchangeResults.InfobaseNode";
		
	Else
		
		QueryTextResult = "
		|SELECT
		|	Undefined AS InfobaseNode,
		|	Undefined AS Count
		|INTO IssuesCount";
		
	EndIf;
	
	Query.Text = QueryTextResult;
	Query.TempTablesManager = TempTablesManager;
	Query.Execute();
	
EndProcedure

Procedure GetMessagesToMapData(TempTablesManager)
	
	Query = New Query;
	
	If Common.SeparatedDataUsageAvailable() Then
		
		If Common.DataSeparationEnabled() Then
			QueryTextResult =
			"SELECT
			|	CommonInfobasesNodesSettings.InfobaseNode AS InfobaseNode,
			|	CASE
			|		WHEN COUNT(CommonInfobasesNodesSettings.MessageForDataMapping) > 0
			|			THEN TRUE
			|		ELSE FALSE
			|	END AS EmailReceivedForDataMapping,
			|	MAX(DataExchangeMessages.MessageStoredDate) AS LastMessageStoragePlacementDate
			|INTO MessagesForDataMapping
			|FROM
			|	InformationRegister.CommonInfobasesNodesSettings AS CommonInfobasesNodesSettings
			|		INNER JOIN InformationRegister.DataAreaDataExchangeMessages AS DataExchangeMessages
			|		ON (DataExchangeMessages.MessageID = CommonInfobasesNodesSettings.MessageForDataMapping)
			|
			|GROUP BY
			|	CommonInfobasesNodesSettings.InfobaseNode";
		Else
			QueryTextResult =
			"SELECT
			|	CommonInfobasesNodesSettings.InfobaseNode AS InfobaseNode,
			|	CASE
			|		WHEN COUNT(CommonInfobasesNodesSettings.MessageForDataMapping) > 0
			|			THEN TRUE
			|		ELSE FALSE
			|	END AS EmailReceivedForDataMapping,
			|	MAX(DataExchangeMessages.MessageStoredDate) AS LastMessageStoragePlacementDate
			|INTO MessagesForDataMapping
			|FROM
			|	InformationRegister.CommonInfobasesNodesSettings AS CommonInfobasesNodesSettings
			|		INNER JOIN InformationRegister.DataExchangeMessages AS DataExchangeMessages
			|		ON (DataExchangeMessages.MessageID = CommonInfobasesNodesSettings.MessageForDataMapping)
			|
			|GROUP BY
			|	CommonInfobasesNodesSettings.InfobaseNode";
		EndIf;
		
	Else
		
		QueryTextResult =
		"SELECT
		|	NULL AS InfobaseNode,
		|	NULL AS EmailReceivedForDataMapping,
		|	NULL AS LastMessageStoragePlacementDate
		|INTO MessagesForDataMapping";
		
	EndIf;
	
	Query.Text = QueryTextResult;
	Query.TempTablesManager = TempTablesManager;
	Query.Execute();
	
EndProcedure

Procedure GetCommonInfobaseNodesSettings(TempTablesManager)
	
	Query = New Query;
	
	If Common.SeparatedDataUsageAvailable() Then
		
		QueryTextResult =
		"SELECT
		|	CommonInfobasesNodesSettings.InfobaseNode AS InfobaseNode,
		|	ISNULL(CommonInfobasesNodesSettings.CorrespondentVersion, """") AS CorrespondentVersion,
		|	ISNULL(CommonInfobasesNodesSettings.CorrespondentPrefix, """") AS CorrespondentPrefix,
		|	ISNULL(CommonInfobasesNodesSettings.SetupCompleted, FALSE) AS SetupCompleted
		|INTO CommonInfobasesNodesSettings
		|FROM
		|	InformationRegister.CommonInfobasesNodesSettings AS CommonInfobasesNodesSettings";
		
	Else
		
		QueryTextResult =
		"SELECT
		|	NULL AS InfobaseNode,
		|	"""" AS CorrespondentVersion,
		|	"""" AS CorrespondentPrefix,
		|	FALSE AS SetupCompleted
		|INTO CommonInfobasesNodesSettings";
		
	EndIf;
	
	Query.Text = QueryTextResult;
	Query.TempTablesManager = TempTablesManager;
	Query.Execute();
	
EndProcedure

Function ExchangePlansWithRulesFromFile()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataExchangeRules.ExchangePlanName
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RulesSource = &RulesSource";
	
	Query.SetParameter("RulesSource", Enums.DataExchangeRulesSources.File);
	Result = Query.Execute().Unload();
	
	Return Result.Count();
	
EndFunction

Procedure CheckExchangeManagementRights() Export
	
	If Not HasRightsToAdministerExchanges() Then
		
		Raise NStr("ru = 'ŠŠµŠ“Š¾ŃŃŠ°ŃŠ¾ŃŠ½Š¾ ŠæŃŠ°Š² Š“Š»Ń Š°Š“Š¼ŠøŠ½ŠøŃŃŃŠøŃŠ¾Š²Š°Š½ŠøŃ ŃŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŠø Š“Š°Š½Š½ŃŃ.'; en = 'Insufficient rights to administer the data synchronization.'; pl = 'NiewystarczajÄce uprawnienia do administrowania synchronizacjÄ danych.';es_ES = 'Insuficientes derecho para administrar la sincronizaciĆ³n de datos.';es_CO = 'Insuficientes derecho para administrar la sincronizaciĆ³n de datos.';tr = 'Veri senkronizasyonunu yĆ¶netmek iĆ§in yetersiz haklar.';it = 'Diritti insufficienti per gestire la sincronizzazione dati.';de = 'Unzureichende Rechte zum Verwalten der Datensynchronisierung.'");
		
	EndIf;
	
EndProcedure

Procedure CheckExternalConnectionAvailable()
	
	If Common.IsLinuxServer() Then
		
		Raise NStr("ru = 'Š”ŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŃ Š“Š°Š½Š½ŃŃ ŃŠµŃŠµŠ· ŠæŃŃŠ¼Š¾Šµ ŠæŠ¾Š“ŠŗŠ»ŃŃŠµŠ½ŠøŠµ Š½Š° ŃŠµŃŠ²ŠµŃŠµ ŠæŠ¾Š“ ŃŠæŃŠ°Š²Š»ŠµŠ½ŠøŠµŠ¼ ŠŠ” Linux Š½ŠµŠ“Š¾ŃŃŃŠæŠ½Š¾.
			|ŠŠ»Ń ŃŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŠø Š“Š°Š½Š½ŃŃ ŃŠµŃŠµŠ· ŠæŃŃŠ¼Š¾Šµ ŠæŠ¾Š“ŠŗŠ»ŃŃŠµŠ½ŠøŠµ ŃŃŠµŠ±ŃŠµŃŃŃ ŠøŃŠæŠ¾Š»ŃŠ·Š¾Š²Š°ŃŃ ŠŠ” Windows.'; 
			|en = 'Data synchronization via direct connection on server under OS Linux is not available.
			|Use OS Windows to synchronize data via direct connection.'; 
			|pl = 'Synchronizacja danych przez bezpoÅrednie poÅÄczenie na serwerze zarzÄdzanym przez system operacyjny Linux nie jest dostÄpna.
			|Musisz uÅ¼yÄ systemu operacyjnego Windows do synchronizacji danych przez poÅÄczenie bezpoÅrednie.';
			|es_ES = 'SincronizaciĆ³n de datos a travĆ©s de la conexiĆ³n directa en el servidor gestionado por OS Linux no estĆ” disponible.
			|Usted tiene que utilizar OS Windows para sincronizar los datos a travĆ©s de la conexiĆ³n directa.';
			|es_CO = 'SincronizaciĆ³n de datos a travĆ©s de la conexiĆ³n directa en el servidor gestionado por OS Linux no estĆ” disponible.
			|Usted tiene que utilizar OS Windows para sincronizar los datos a travĆ©s de la conexiĆ³n directa.';
			|tr = 'Linux OS tarafÄ±ndan yĆ¶netilen sunucudaki doÄrudan baÄlantÄ± Ć¼zerinden veri senkronizasyonu mevcut deÄildir. 
			|DoÄrudan baÄlantÄ± yoluyla veri senkronizasyonu iĆ§in Windows iÅletim sistemini kullanmanÄ±z gerekir.';
			|it = 'La sincronizzazione dati tramite connessione diretta o server su sistema operativo Linux non ĆØ disponibile. 
			|Utilizzare il sistema operativo Windows per sincronizzare i dati tramite connessione diretta.';
			|de = 'Die Datensynchronisierung Ć¼ber die direkte Verbindung auf einem Server, der von einem Linux-Betriebssystem verwaltet wird, ist nicht verfĆ¼gbar.
			|Sie mĆ¼ssen ein Windows-Betriebssystem fĆ¼r die Datensynchronisierung Ć¼ber die direkte Verbindung verwenden.'");
			
	EndIf;
	
EndProcedure

// Returns the flag that shows whether a user has rights to perform the data synchronization.
// A user can perform data synchronization if it has either full access or rights of the "Data 
// synchronization with other applications" supplied profile.
//
//  Parameters:
// User (optional) - InfoBaseUser, Undefined.
// This user is used to define whether the data synchronization is available.
// If this parameter is not set, the current infobase user is used to calculate the function result.
//
Function DataSynchronizationPermitted(Val User = Undefined) Export
	
	If User = Undefined Then
		User = InfoBaseUsers.CurrentUser();
	EndIf;
	
	If User.Roles.Contains(Metadata.Roles.FullRights) Then
		Return True;
	EndIf;
	
	ProfileRoles = StrSplit(DataSynchronizationAccessProfileWithOtherApplicationsRoles(), ",");
	For Each Role In ProfileRoles Do
		
		If Not User.Roles.Contains(Metadata.Roles.Find(TrimAll(Role))) Then
			Return False;
		EndIf;
		
	EndDo;
	
	Return True;
EndFunction

// Fills in a value list with available transport types for the exchange plan node.
//
Procedure FillChoiceListWithAvailableTransportTypes(InfobaseNode, FormItem, Filter = Undefined) Export
	
	FilterSet = (Filter <> Undefined);
	
	UsedTransports = DataExchangeCached.UsedExchangeMessagesTransports(InfobaseNode);
	
	FormItem.ChoiceList.Clear();
	
	For Each Item In UsedTransports Do
		
		If FilterSet Then
			
			If Filter.Find(Item) <> Undefined Then
				
				FormItem.ChoiceList.Add(Item, String(Item));
				
			EndIf;
			
		Else
			
			FormItem.ChoiceList.Add(Item, String(Item));
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Registeres that the exchange was carried out and records information in the protocol.
//
// Parameters:
//  ExchangeSettingsStructure - Structure - a structure with all necessary data and objects to execute exchange.
// 
Procedure AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure) Export
	
	// The Undefined state in the end of the exchange indicates that the exchange has been performed successfully.
	If ExchangeSettingsStructure.ExchangeExecutionResult = Undefined Then
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Completed;
	EndIf;
	
	// Generating the final message to be written.
	If ExchangeSettingsStructure.IsDIBExchange Then
		MessageString = NStr("ru = '%1, %2'; en = '%1, %2'; pl = '%1, %2';es_ES = '%1, %2';es_CO = '%1, %2';tr = '%1, %2';it = '%1, %2';de = '%1, %2'", CommonClientServer.DefaultLanguageCode());
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString,
							ExchangeSettingsStructure.ExchangeExecutionResult,
							ExchangeSettingsStructure.ActionOnExchange);
	Else
		MessageString = NStr("ru = '%1, %2; ŠŠ±ŃŠµŠŗŃŠ¾Š² Š¾Š±ŃŠ°Š±Š¾ŃŠ°Š½Š¾: %3'; en = '%1, %2; %3 objects processed.'; pl = '%1, %2; Przetworzone obiekty: %3';es_ES = '%1, %2; Objetos procesados: %3';es_CO = '%1, %2; Objetos procesados: %3';tr = '%1, %2;Ä°ÅlenmiÅ nesneler:%3';it = '%1,%2; %3 oggetti vengono elaborati.';de = 'Verarbeitete Objekte: %1, %2, %3.'", CommonClientServer.DefaultLanguageCode());
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString,
							ExchangeSettingsStructure.ExchangeExecutionResult,
							ExchangeSettingsStructure.ActionOnExchange,
							ExchangeSettingsStructure.ProcessedObjectsCount);
	EndIf;
	
	ExchangeSettingsStructure.EndDate = CurrentSessionDate();
	
	SetPrivilegedMode(True);
	
	// Writing the exchange state to the information register.
	AddExchangeFinishMessageToInformationRegister(ExchangeSettingsStructure);
	
	// The data exchange has been completed successfully.
	If ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) Then
		
		AddSuccessfulDataExchangeMessageToInformationRegister(ExchangeSettingsStructure);
		
		InformationRegisters.CommonInfobasesNodesSettings.ClearDataSendingFlag(ExchangeSettingsStructure.InfobaseNode);
		
	EndIf;
	
	WriteEventLogDataExchange(MessageString, ExchangeSettingsStructure);
	
EndProcedure

// Records the data exchange state in the DataExchangesStates information register.
//
// Parameters:
//  ExchangeSettingsStructure - Structure - a structure with all necessary data and objects to execute exchange.
// 
Procedure AddExchangeFinishMessageToInformationRegister(ExchangeSettingsStructure)
	
	// Generating a structure for the new information register record.
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode",    ExchangeSettingsStructure.InfobaseNode);
	RecordStructure.Insert("ActionOnExchange",         ExchangeSettingsStructure.ActionOnExchange);
	
	RecordStructure.Insert("ExchangeExecutionResult", ExchangeSettingsStructure.ExchangeExecutionResult);
	RecordStructure.Insert("StartDate",                ExchangeSettingsStructure.StartDate);
	RecordStructure.Insert("EndDate",             ExchangeSettingsStructure.EndDate);
	
	InformationRegisters.DataExchangesStates.AddRecord(RecordStructure);
	
EndProcedure

Procedure AddSuccessfulDataExchangeMessageToInformationRegister(ExchangeSettingsStructure)
	
	// Generating a structure for the new information register record.
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", ExchangeSettingsStructure.InfobaseNode);
	RecordStructure.Insert("ActionOnExchange",      ExchangeSettingsStructure.ActionOnExchange);
	RecordStructure.Insert("EndDate",          ExchangeSettingsStructure.EndDate);
	
	InformationRegisters.SuccessfulDataExchangesStates.AddRecord(RecordStructure);
	
EndProcedure

Procedure WriteLogEventDataExchangeStart(ExchangeSettingsStructure) Export
	
	MessageString = NStr("ru = 'ŠŠ°ŃŠ°Š»Š¾ ŠæŃŠ¾ŃŠµŃŃŠ° Š¾Š±Š¼ŠµŠ½Š° Š“Š°Š½Š½ŃŠ¼Šø Š“Š»Ń ŃŠ·Š»Š° %1'; en = 'Data exchange process started for %1 node'; pl = 'PoczÄtek procesu wymiany danych dla wÄzÅa %1';es_ES = 'Inicio de proceso de intercambio de datos para el nodo %1';es_CO = 'Inicio de proceso de intercambio de datos para el nodo %1';tr = '%1Ćnite iĆ§in veri deÄiÅimi sĆ¼reci baÅlatÄ±lÄ±yor';it = 'Il processo di scambio dati iniziato per il nodo %1';de = 'Datenaustausch beginnt fĆ¼r Knoten %1'", CommonClientServer.DefaultLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, ExchangeSettingsStructure.InfobaseNodeDescription);
	WriteEventLogDataExchange(MessageString, ExchangeSettingsStructure);
	
EndProcedure

// Creates a record in the event log about a data exchange event or an exchange message transport.
//
Procedure WriteEventLogDataExchange(Comment, ExchangeSettingsStructure, IsError = False)
	
	Level = ?(IsError, EventLogLevel.Error, EventLogLevel.Information);
	
	If ExchangeSettingsStructure.Property("InfobaseNode") Then
		
		WriteLogEvent(ExchangeSettingsStructure.EventLogMessageKey, 
			Level,
			ExchangeSettingsStructure.InfobaseNode.Metadata(),
			ExchangeSettingsStructure.InfobaseNode,
			Comment);
			
	Else
		WriteLogEvent(ExchangeSettingsStructure.EventLogMessageKey, Level,,, Comment);
	EndIf;
	
EndProcedure

Procedure WriteDataReceiveEvent(Val InfobaseNode, Val Comment, Val IsError = False)
	
	Level = ?(IsError, EventLogLevel.Error, EventLogLevel.Information);
	
	EventLogMessageKey = EventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport);
	
	WriteLogEvent(EventLogMessageKey, Level,,, Comment);
	
EndProcedure

Procedure NodeSettingsFormOnCreateAtServerHandler(Form, FormAttributeName)
	
	FormAttributes = FormAttributeNames(Form);
	
	For Each FilterSetting In Form[FormAttributeName] Do
		
		varKey = FilterSetting.Key;
		
		If FormAttributes.Find(varKey) = Undefined Then
			Continue;
		EndIf;
		
		If TypeOf(Form[varKey]) = Type("FormDataCollection") Then
			
			Table = New ValueTable;
			
			TabularSectionStructure = Form.Parameters[FormAttributeName][varKey];
			
			For Each Item In TabularSectionStructure Do
				
				While Table.Count() < Item.Value.Count() Do
					Table.Add();
				EndDo;
				
				Table.Columns.Add(Item.Key);
				
				Table.LoadColumn(Item.Value, Item.Key);
				
			EndDo;
			
			Form[varKey].Load(Table);
			
		Else
			
			Form[varKey] = Form.Parameters[FormAttributeName][varKey];
			
		EndIf;
		
		Form[FormAttributeName][varKey] = Form.Parameters[FormAttributeName][varKey];
		
	EndDo;
	
EndProcedure

Function FormAttributeNames(Form)
	
	// Function return value.
	Result = New Array;
	
	For Each FormAttribute In Form.GetAttributes() Do
		
		Result.Add(FormAttribute.Name);
		
	EndDo;
	
	Return Result;
EndFunction

// Unpacks the ZIP archive file to the specified directory and extracts all archive files.
//
// Parameters:
//  FullArchiveFileName  - String - an archive file name being extracted.
//  FileUnpackPath  - String - a path by which the files are extracted.
//  ArchivePassword          - String - a password for unpacking the archive. Default value: empty string.
// 
// Returns:
//  Result - Boolean - True if it is successful. Otherwise, False.
//
Function UnpackZipFile(Val ArchiveFileFullName, Val FileUnpackPath, Val ArchivePassword = "") Export
	
	// Function return value.
	Result = True;
	
	Try
		
		Archiver = New ZipFileReader(ArchiveFileFullName, ArchivePassword);
		
	Except
		Archiver = Undefined;
		ReportError(BriefErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	Try
		
		Archiver.ExtractAll(FileUnpackPath, ZIPRestoreFilePathsMode.DontRestore);
		
	Except
		
		MessageString = NStr("ru = 'ŠŃŠøŠ±ŠŗŠ° ŠæŃŠø ŃŠ°ŃŠæŠ°ŠŗŠ¾Š²ŠŗŠµ ŃŠ°Š¹Š»Š¾Š² Š°ŃŃŠøŠ²Š°: %1 Š² ŠŗŠ°ŃŠ°Š»Š¾Š³: %2'; en = 'Error unpacking the %1 archive files to the %2  directory.'; pl = 'Podczas rozpakowywania plikĆ³w archiwum %1 do katalogu: %2 wystÄpiÅ bÅÄd';es_ES = 'Ha ocurrido un error al desembalar los documentos del archivo %1 para el directorio: %2';es_CO = 'Ha ocurrido un error al desembalar los documentos del archivo %1 para el directorio: %2';tr = 'ArÅiv dosyalarÄ±nÄ± %1 aĆ§arken bir hata oluÅtu:%2';it = 'Errore di estrazione dei file dell''archivio %1 nella directory %2.';de = 'Beim Entpacken der Archivdateien %1 in das Verzeichnis %2 ist ein Fehler aufgetreten.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, ArchiveFileFullName, FileUnpackPath);
		CommonClientServer.MessageToUser(MessageString);
		
		Result = False;
	EndTry;
	
	Archiver.Close();
	Archiver = Undefined;
	
	Return Result;
	
EndFunction

// Packs the specified directory into a ZIP file.
//
// Parameters:
//  FullArchiveFileName  - String - a name of an archive file being packed.
//  FilePackingMask    - String - a name of a file to archive or mask.
//			It is prohibited that you name files and directories using characters that can be converted to 
//			UNICODE characters and back incorrectly.
//			It is recommended that you use only roman characters to name files and folders.
//  ArchivePassword          - String - a password for the archive. Default value: empty string.
// 
// Returns:
//  Result - Boolean - True if it is successful. Otherwise, False.
//
Function PackIntoZipFile(Val ArchiveFileFullName, Val FilesPackingMask, Val ArchivePassword = "") Export
	
	// Function return value.
	Result = True;
	
	Try
		
		Archiver = New ZipFileWriter(ArchiveFileFullName, ArchivePassword);
		
	Except
		Archiver = Undefined;
		ReportError(BriefErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	Try
		
		Archiver.Add(FilesPackingMask, ZIPStorePathMode.DontStorePath);
		Archiver.Write();
		
	Except
		
		MessageString = NStr("ru = 'ŠŃŠøŠ±ŠŗŠ° ŠæŃŠø Š·Š°ŠæŠ°ŠŗŠ¾Š²ŠŗŠµ ŃŠ°Š¹Š»Š¾Š² Š°ŃŃŠøŠ²Š°: %1 ŠøŠ· ŠŗŠ°ŃŠ°Š»Š¾Š³: %2'; en = 'Error packing the %1 archive files from the %2 directory.'; pl = 'Podczas pakowania plikĆ³w archiwum: %1 z katalogu: %2 wystÄpiÅ bÅÄd';es_ES = 'Ha ocurrido un error al desembalar los documentos del archivo %1 desde el directorio: %2';es_CO = 'Ha ocurrido un error al desembalar los documentos del archivo %1 desde el directorio: %2';tr = 'ArÅiv dosyalarÄ±nÄ± %1 dizinden paketlerken bir hata oluÅtu: %2';it = 'Errore di archiviazione dei file di archivio %1 dalla directory %2.';de = 'Beim Packen von Archivdateien %1 aus dem Verzeichnis: %2 ist ein Fehler aufgetreten.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, ArchiveFileFullName, FilesPackingMask);
		CommonClientServer.MessageToUser(MessageString);
		
		Result = False;
	EndTry;
	
	Archiver = Undefined;
	
	Return Result;
	
EndFunction

// Returns the number of records in the infobase table.
//
// Parameters:
//  TableName - String - a full name of the infobase table. For example: "Catalog.Counterparties.Orders".
// 
// Returns:
//  Number - a number of records in the infobase table.
//
Function RecordCountInInfobaseTable(Val TableName) Export
	
	QueryText = "
	|SELECT
	|	Count(*) AS Count
	|FROM
	|	#TableName
	|";
	
	QueryText = StrReplace(QueryText, "#TableName", TableName);
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection["Count"];
	
EndFunction

// Returns the number of records in the temporary infobase table.
//
// Parameters:
//  TableName - String - a name of the table. For example: "TemporaryTable1".
//  TempTablesManager - a temporary table manager containing a reference to the TableName temporary table.
// 
// Returns:
//  Number - a number of records in the infobase table.
//
Function TempInfobaseTableRecordCount(Val TableName, TempTablesManager) Export
	
	QueryText = "
	|SELECT
	|	Count(*) AS Count
	|FROM
	|	#TableName
	|";
	
	QueryText = StrReplace(QueryText, "#TableName", TableName);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection["Count"];
	
EndFunction

// Returns the event log message key.
//
Function EventLogMessageKey(InfobaseNode, ActionOnExchange) Export
	
	ExchangePlanName     = DataExchangeCached.GetExchangePlanName(InfobaseNode);
	
	MessageKey = NStr("ru = 'ŠŠ±Š¼ŠµŠ½ Š“Š°Š½Š½ŃŠ¼Šø.[ExchangePlanName].[ActionOnExchange]'; en = 'Data exchange.[ExchangePlanName].[ActionOnExchange]'; pl = 'Wymiana danych.[ExchangePlanName].[ActionOnExchange]';es_ES = 'Intercambio de datos.[ExchangePlanName].[ActionOnExchange]';es_CO = 'Intercambio de datos.[ExchangePlanName].[ActionOnExchange]';tr = 'Veri alÄ±ÅveriÅi [ExchangePlanName].[ActionOnExchange]';it = 'Scambio dati.[ExchangePlanName].[ActionOnExchange]';de = 'Datenaustausch.[ExchangePlanName].[ActionOnExchange]'",
		CommonClientServer.DefaultLanguageCode());
	
	MessageKey = StrReplace(MessageKey, "[ExchangePlanName]",    ExchangePlanName);
	MessageKey = StrReplace(MessageKey, "[ActionOnExchange]", ActionOnExchange);
	
	Return MessageKey;
	
EndFunction

// Returns a flag indicating whether the attribute is a standard attribute.
//
Function IsStandardAttribute(StandardAttributes, AttributeName) Export
	
	For Each Attribute In StandardAttributes Do
		
		If Attribute.Name = AttributeName Then
			
			Return True;
			
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

// Returns the flag of successful data exchange completion.
//
Function ExchangeExecutionResultCompleted(ExchangeExecutionResult)
	
	Return ExchangeExecutionResult = Undefined
		OR ExchangeExecutionResult = Enums.ExchangeExecutionResults.Completed
		OR ExchangeExecutionResult = Enums.ExchangeExecutionResults.CompletedWithWarnings;
	
EndFunction

// Generating the data table key.
// The table key is used for importing data selectively from the exchange message.
//
Function DataTableKey(Val SourceType, Val DestinationType, Val IsObjectDeletion) Export
	
	Return SourceType + "#" + DestinationType + "#" + String(IsObjectDeletion);
	
EndFunction

Function MustExecuteHandler(Object, Ref, PropertyName)
	
	NumberAfterProcessing = Object[PropertyName];
	
	NumberBeforeProcessing = Common.ObjectAttributeValue(Ref, PropertyName);
	
	NumberBeforeProcessing = ?(NumberBeforeProcessing = Undefined, 0, NumberBeforeProcessing);
	
	Return NumberBeforeProcessing <> NumberAfterProcessing;
	
EndFunction

Function FillExternalConnectionParameters(TransportSettings)
	
	ConnectionParameters = CommonClientServer.ParametersStructureForExternalConnection();
	
	ConnectionParameters.InfobaseOperatingMode             = TransportSettings.COMInfobaseOperatingMode;
	ConnectionParameters.InfobaseDirectory                   = TransportSettings.COMInfobaseDirectory;
	ConnectionParameters.NameOf1CEnterpriseServer                     = TransportSettings.COM1CEnterpriseServerName;
	ConnectionParameters.NameOfInfobaseOn1CEnterpriseServer = TransportSettings.COM1CEnterpriseServerSideInfobaseName;
	ConnectionParameters.OperatingSystemAuthentication           = TransportSettings.COMOperatingSystemAuthentication;
	ConnectionParameters.UserName                             = TransportSettings.COMUsername;
	ConnectionParameters.UserPassword = TransportSettings.COMUserPassword;
	
	Return ConnectionParameters;
EndFunction

Function AddLiteralToFileName(Val FullFileName, Val Literal)
	
	If IsBlankString(FullFileName) Then
		Return "";
	EndIf;
	
	FileNameWithoutExtension = Mid(FullFileName, 1, StrLen(FullFileName) - 4);
	
	Extension = Right(FullFileName, 3);
	
	Result = "[FileNameWithoutExtension]_[Literal].[Extension]";
	
	Result = StrReplace(Result, "[FileNameWithoutExtension]", FileNameWithoutExtension);
	Result = StrReplace(Result, "[Literal]",               Literal);
	Result = StrReplace(Result, "[Extension]",            Extension);
	
	Return Result;
EndFunction

Function ExchangePlanNodeCodeString(Value) Export
	
	If TypeOf(Value) = Type("String") Then
		
		Return TrimAll(Value);
		
	ElsIf TypeOf(Value) = Type("Number") Then
		
		Return Format(Value, "ND=7; NLZ=; NG=0");
		
	EndIf;
	
	Return Value;
EndFunction

Function PredefinedExchangePlanNodeDescription(ExchangePlanName) Export
	
	SetPrivilegedMode(True);
	
	Return Common.ObjectAttributeValue(DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName), "Description");
EndFunction

Procedure OnSSLDataExportHandler(StandardProcessing,
											Val Recipient,
											Val MessageFileName,
											MessageData,
											Val TransactionItemsCount,
											Val LogEventName,
											SentObjectsCount)
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.MessageExchange") Then
		ModuleMessageExchangeInternal = Common.CommonModule("MessageExchangeInternal");
		ModuleMessageExchangeInternal.OnDataExport(
			StandardProcessing,
			Recipient,
			MessageFileName,
			MessageData,
			TransactionItemsCount,
			LogEventName,
			SentObjectsCount);
	EndIf;
	
EndProcedure

Procedure OnDataExportHandler(StandardProcessing,
											Val Recipient,
											Val MessageFileName,
											MessageData,
											Val TransactionItemsCount,
											Val LogEventName,
											SentObjectsCount)
	
	DataExchangeOverridable.OnDataExport(StandardProcessing,
											Recipient,
											MessageFileName,
											MessageData,
											TransactionItemsCount,
											LogEventName,
											SentObjectsCount);
	
EndProcedure

Procedure OnSSLDataImportHandler(StandardProcessing,
											Val Sender,
											Val MessageFileName,
											MessageData,
											Val TransactionItemsCount,
											Val LogEventName,
											ReceivedObjectsCount)
	
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.MessageExchange") Then
		ModuleMessageExchangeInternal = Common.CommonModule("MessageExchangeInternal");
		ModuleMessageExchangeInternal.OnDataImport(
			StandardProcessing,
			Sender,
			MessageFileName,
			MessageData,
			TransactionItemsCount,
			LogEventName,
			ReceivedObjectsCount);
	EndIf;
	
EndProcedure

Procedure OnDataImportHandler(StandardProcessing,
											Val Sender,
											Val MessageFileName,
											MessageData,
											Val TransactionItemsCount,
											Val LogEventName,
											ReceivedObjectsCount)
	
	DataExchangeOverridable.OnDataImport(StandardProcessing,
											Sender,
											MessageFileName,
											MessageData,
											TransactionItemsCount,
											LogEventName,
											ReceivedObjectsCount);
	
EndProcedure

Procedure RecordExchangeCompletionWithError(Val InfobaseNode, 
												Val ActionOnExchange, 
												Val StartDate, 
												Val ErrorMessageString) Export
	
	If TypeOf(ActionOnExchange) = Type("String") Then
		
		ActionOnExchange = Enums.ActionsOnExchange[ActionOnExchange];
		
	EndIf;
	
	ExchangeSettingsStructure = New Structure;
	ExchangeSettingsStructure.Insert("InfobaseNode", InfobaseNode);
	ExchangeSettingsStructure.Insert("ExchangeExecutionResult", Enums.ExchangeExecutionResults.Error);
	ExchangeSettingsStructure.Insert("ActionOnExchange", ActionOnExchange);
	ExchangeSettingsStructure.Insert("ProcessedObjectsCount", 0);
	ExchangeSettingsStructure.Insert("EventLogMessageKey", EventLogMessageKey(InfobaseNode, ActionOnExchange));
	ExchangeSettingsStructure.Insert("StartDate", StartDate);
	ExchangeSettingsStructure.Insert("EndDate", CurrentSessionDate());
	ExchangeSettingsStructure.Insert("IsDIBExchange", DataExchangeCached.IsDistributedInfobaseNode(InfobaseNode));
	
	WriteEventLogDataExchange(ErrorMessageString, ExchangeSettingsStructure, True);
	
	AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
	
EndProcedure

// Checks whether the specified attributes are on the form.
// If at least one attribute is absent, the exception is raised.
//
Procedure CheckMandatoryFormAttributes(Form, Val Attributes)
	
	AbsentAttributes = New Array;
	
	FormAttributes = FormAttributeNames(Form);
	
	For Each Attribute In StrSplit(Attributes, ",") Do
		
		Attribute = TrimAll(Attribute);
		
		If FormAttributes.Find(Attribute) = Undefined Then
			
			AbsentAttributes.Add(Attribute);
			
		EndIf;
		
	EndDo;
	
	If AbsentAttributes.Count() > 0 Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'ŠŃŃŃŃŃŃŠ²ŃŃŃ Š¾Š±ŃŠ·Š°ŃŠµŠ»ŃŠ½ŃŠµ ŃŠµŠŗŠ²ŠøŠ·ŠøŃŃ ŃŠ¾ŃŠ¼Ń Š½Š°ŃŃŃŠ¾Š¹ŠŗŠø ŃŠ·Š»Š°: %1'; en = 'Mandatory attributes of the node setup form are absent: %1'; pl = 'Brak wymaganych atrybutĆ³w formularza konfiguracji wÄzÅa: %1';es_ES = 'Atributos no requeridos del formulario de la configuraciĆ³n del nodo: %1';es_CO = 'Atributos no requeridos del formulario de la configuraciĆ³n del nodo: %1';tr = 'Ćnite yapÄ±landÄ±rma formunun gerekli Ć¶zellikleri yok:%1';it = 'Gli attributi obbligatori della configurazione del modulo del nodo sono assenti: %1';de = 'Keine erforderlichen Attribute des Knotenkonfigurationsformulars: %1'"),
			StrConcat(AbsentAttributes, ","));
	EndIf;
	
EndProcedure

Procedure ExternalConnectionUpdateDataExchangeSettings(Val ExchangePlanName, Val NodeCode, Val NodeDefaultValues) Export
	
	SetPrivilegedMode(True);
	
	InfobaseNode = ExchangePlans[ExchangePlanName].FindByCode(NodeCode);
	
	If Not ValueIsFilled(InfobaseNode) Then
		Message = NStr("ru = 'ŠŠµ Š½Š°Š¹Š“ŠµŠ½ ŃŠ·ŠµŠ» ŠæŠ»Š°Š½Š° Š¾Š±Š¼ŠµŠ½Š°; ŠøŠ¼Ń ŠæŠ»Š°Š½Š° Š¾Š±Š¼ŠµŠ½Š° %1; ŠŗŠ¾Š“ ŃŠ·Š»Š° %2'; en = 'Exchange plan node not found. Node name: %1, node code: %2.'; pl = 'Nie znaleziono wÄzÅa planu wymiany; nazwa planu wymiany %1; kod wÄzÅa %2';es_ES = 'Nodo del plan de intercambio no encontrado; nombre del plan de intercambio %1; cĆ³digo del nodo %2';es_CO = 'Nodo del plan de intercambio no encontrado; nombre del plan de intercambio %1; cĆ³digo del nodo %2';tr = 'DeÄiÅim plan Ć¼nitesi bulunamadÄ±; deÄiÅim planÄ± adÄ±%1; Ć¼nite kodu %2';it = 'Nodo del piano di scambio non trovato. Nome nodo: %1, codice nodo: %2.';de = 'Der Austauschplan-Knoten wurde nicht gefunden. Name des Austauschplans %1; Knotencode %2'");
		Message = StringFunctionsClientServer.SubstituteParametersToString(Message, ExchangePlanName, NodeCode);
		Raise Message;
	EndIf;
	
	DataExchangeCreationWizard = ModuleDataExchangeCreationWizard().Create();
	DataExchangeCreationWizard.InfobaseNode = InfobaseNode;
	DataExchangeCreationWizard.ExternalConnectionUpdateDataExchangeSettings(GetFilterSettingsValues(NodeDefaultValues));
	
EndProcedure

Function GetFilterSettingsValues(ExternalConnectionSettingsStructure) Export
	
	Result = New Structure;
	
	// object types
	For Each FilterSetting In ExternalConnectionSettingsStructure Do
		
		If TypeOf(FilterSetting.Value) = Type("Structure") Then
			
			ResultNested = New Structure;
			
			For Each Item In FilterSetting.Value Do
				
				If StrFind(Item.Key, "_Key") > 0 Then
					
					varKey = StrReplace(Item.Key, "_Key", "");
					
					Array = New Array;
					
					For Each ArrayElement In Item.Value Do
						
						If Not IsBlankString(ArrayElement) Then
							
							Value = ValueFromStringInternal(ArrayElement);
							
							Array.Add(Value);
							
						EndIf;
						
					EndDo;
					
					ResultNested.Insert(varKey, Array);
					
				EndIf;
				
			EndDo;
			
			Result.Insert(FilterSetting.Key, ResultNested);
			
		Else
			
			If StrFind(FilterSetting.Key, "_Key") > 0 Then
				
				varKey = StrReplace(FilterSetting.Key, "_Key", "");
				
				Try
					If IsBlankString(FilterSetting.Value) Then
						Value = Undefined;
					Else
						Value = ValueFromStringInternal(FilterSetting.Value);
					EndIf;
				Except
					Value = Undefined;
				EndTry;
				
				Result.Insert(varKey, Value);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Primitive types
	For Each FilterSetting In ExternalConnectionSettingsStructure Do
		
		If TypeOf(FilterSetting.Value) = Type("Structure") Then
			
			ResultNested = Result[FilterSetting.Key];
			
			If ResultNested = Undefined Then
				
				ResultNested = New Structure;
				
			EndIf;
			
			For Each Item In FilterSetting.Value Do
				
				If StrFind(Item.Key, "_Key") <> 0 Then
					
					Continue;
					
				ElsIf FilterSetting.Value.Property(Item.Key + "_Key") Then
					
					Continue;
					
				EndIf;
				
				Array = New Array;
				
				For Each ArrayElement In Item.Value Do
					
					Array.Add(ArrayElement);
					
				EndDo;
				
				ResultNested.Insert(Item.Key, Array);
				
			EndDo;
			
		Else
			
			If StrFind(FilterSetting.Key, "_Key") <> 0 Then
				
				Continue;
				
			ElsIf ExternalConnectionSettingsStructure.Property(FilterSetting.Key + "_Key") Then
				
				Continue;
				
			EndIf;
			
			// Shielding the enumeration
			If TypeOf(FilterSetting.Value) = Type("String")
				AND (     StrFind(FilterSetting.Value, "Enum.") <> 0
					OR StrFind(FilterSetting.Value, "Enumeration.") <> 0) Then
				
				Result.Insert(FilterSetting.Key, PredefinedValue(FilterSetting.Value));
				
			Else
				
				Result.Insert(FilterSetting.Key, FilterSetting.Value);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function DataForThisInfobaseNodeTabularSections(Val ExchangePlanName, CorrespondentVersion = "", SettingID = "") Export
	
	Result = New Structure;
	
	NodeCommonTables = DataExchangeCached.ExchangePlanTabularSections(ExchangePlanName, CorrespondentVersion, SettingID)["AllTablesOfThisInfobase"];
	
	For Each TabularSectionName In NodeCommonTables Do
		
		TabularSectionData = New ValueTable;
		TabularSectionData.Columns.Add("Presentation",                 New TypeDescription("String"));
		TabularSectionData.Columns.Add("RefUUID", New TypeDescription("String"));
		
		QueryText =
		"SELECT TOP 1000
		|	Table.Ref AS Ref,
		|	Table.Presentation AS Presentation
		|FROM
		|	[TableName] AS Table
		|
		|WHERE
		|	NOT Table.DeletionMark
		|
		|ORDER BY
		|	Table.Presentation";
		
		TableName = TableNameFromExchangePlanTabularSectionFirstAttribute(ExchangePlanName, TabularSectionName);
		
		QueryText = StrReplace(QueryText, "[TableName]", TableName);
		
		Query = New Query;
		Query.Text = QueryText;
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			
			TableRow = TabularSectionData.Add();
			TableRow.Presentation = Selection.Presentation;
			TableRow.RefUUID = String(Selection.Ref.UUID());
			
		EndDo;
		
		Result.Insert(TabularSectionName, TabularSectionData);
		
	EndDo;
	
	Return Result;
	
EndFunction

Function TableNameFromExchangePlanTabularSectionFirstAttribute(Val ExchangePlanName, Val TabularSectionName)
	
	TabularSection = Metadata.ExchangePlans[ExchangePlanName].TabularSections[TabularSectionName];
	
	For Each Attribute In TabularSection.Attributes Do
		
		Type = Attribute.Type.Types()[0];
		
		If Common.IsReference(Type) Then
			
			Return Metadata.FindByType(Type).FullName();
			
		EndIf;
		
	EndDo;
	
	Return "";
EndFunction

Function ExchangePlanCatalogs(Val ExchangePlanName)
	
	If TypeOf(ExchangePlanName) <> Type("String") Then
		
		ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangePlanName);
		
	EndIf;
	
	Result = New Array;
	
	ExchangePlanComposition = Metadata.ExchangePlans[ExchangePlanName].Content;
	
	For Each Item In ExchangePlanComposition Do
		
		If Common.IsCatalog(Item.Metadata)
			OR Common.IsChartOfCharacteristicTypes(Item.Metadata) Then
			
			Result.Add(Item.Metadata);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function AllExchangePlanDataExceptCatalogs(Val ExchangePlanName)
	
	If TypeOf(ExchangePlanName) <> Type("String") Then
		
		ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangePlanName);
		
	EndIf;
	
	Result = New Array;
	
	ExchangePlanComposition = Metadata.ExchangePlans[ExchangePlanName].Content;
	
	For Each Item In ExchangePlanComposition Do
		
		If Not (Common.IsCatalog(Item.Metadata)
			OR Common.IsChartOfCharacteristicTypes(Item.Metadata)) Then
			
			Result.Add(Item.Metadata);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function AccountingParametersSettingsAreSet(Val ExchangePlanName, Val Correspondent, ErrorMessage)
	
	If TypeOf(Correspondent) = Type("String") Then
		
		If IsBlankString(Correspondent) Then
			Return False;
		EndIf;
		
		CorrespondentCode = Correspondent;
		
		Correspondent = ExchangePlans[ExchangePlanName].FindByCode(Correspondent);
		
		If Not ValueIsFilled(Correspondent) Then
			Message = NStr("ru = 'ŠŠµ Š½Š°Š¹Š“ŠµŠ½ ŃŠ·ŠµŠ» ŠæŠ»Š°Š½Š° Š¾Š±Š¼ŠµŠ½Š°; ŠøŠ¼Ń ŠæŠ»Š°Š½Š° Š¾Š±Š¼ŠµŠ½Š° %1; ŠŗŠ¾Š“ ŃŠ·Š»Š° %2'; en = 'Exchange plan node not found. Node name: %1, node code: %2.'; pl = 'Nie znaleziono wÄzÅa planu wymiany; nazwa planu wymiany %1; kod wÄzÅa %2';es_ES = 'Nodo del plan de intercambio no encontrado; nombre del plan de intercambio %1; cĆ³digo del nodo %2';es_CO = 'Nodo del plan de intercambio no encontrado; nombre del plan de intercambio %1; cĆ³digo del nodo %2';tr = 'DeÄiÅim plan Ć¼nitesi bulunamadÄ±; deÄiÅim planÄ± adÄ±%1; Ć¼nite kodu %2';it = 'Nodo del piano di scambio non trovato. Nome nodo: %1, codice nodo: %2.';de = 'Der Austauschplan-Knoten wurde nicht gefunden. Name des Austauschplans %1; Knotencode %2'");
			Message = StringFunctionsClientServer.SubstituteParametersToString(Message, ExchangePlanName, CorrespondentCode);
			Raise Message;
		EndIf;
		
	EndIf;
	
	Cancel = False;
	If HasExchangePlanManagerAlgorithm("AccountingSettingsCheckHandler", ExchangePlanName) Then
		SetPrivilegedMode(True);
		ExchangePlans[ExchangePlanName].AccountingSettingsCheckHandler(Cancel, Correspondent, ErrorMessage);
	EndIf;
	
	Return Not Cancel;
EndFunction

Function GetInfobaseParameters(Val ExchangePlanName, Val NodeCode, ErrorMessage) Export
	
	Return ValueToStringInternal(InfobaseParameters(ExchangePlanName, NodeCode, ErrorMessage));
	
EndFunction

Function GetInfobaseParameters_2_0_1_6(Val ExchangePlanName, Val NodeCode, ErrorMessage) Export
	
	Return Common.ValueToXMLString(InfobaseParameters(ExchangePlanName, NodeCode, ErrorMessage));
	
EndFunction

Function MetadataObjectProperties(Val FullTableName) Export
	
	Result = New Structure("Synonym, Hierarchical");
	
	MetadataObject = Metadata.FindByFullName(FullTableName);
	
	FillPropertyValues(Result, MetadataObject);
	
	Return Result;
EndFunction

Function GetTableObjects(Val FullTableName) Export
	SetPrivilegedMode(True);
	
	MetadataObject = Metadata.FindByFullName(FullTableName);
	
	If Common.IsCatalog(MetadataObject) Then
		
		If MetadataObject.Hierarchical Then
			If MetadataObject.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems Then
				Return HierarchicalCatalogItemsHierarchyFoldersAndItems(FullTableName);
			EndIf;
			
			Return HierarchicalCatalogItemsHierarchyItems(FullTableName);
		EndIf;
		
		Return NonhierarchicalCatalogItems(FullTableName);
		
	ElsIf Common.IsChartOfCharacteristicTypes(MetadataObject) Then
		
		If MetadataObject.Hierarchical Then
			Return HierarchicalCatalogItemsHierarchyFoldersAndItems(FullTableName);
		EndIf;
		
		Return NonhierarchicalCatalogItems(FullTableName);
		
	EndIf;
	
	Return Undefined;
EndFunction

Function HierarchicalCatalogItemsHierarchyFoldersAndItems(Val FullTableName)
	
	Query = New Query("
		|SELECT TOP 2000
		|	Ref,
		|	Presentation,
		|	CASE
		|		WHEN    IsFolder AND NOT DeletionMark THEN 0
		|		WHEN    IsFolder AND    DeletionMark THEN 1
		|		WHEN NOT IsFolder AND NOT DeletionMark THEN 2
		|		WHEN NOT IsFolder AND    DeletionMark THEN 3
		|	END AS PictureIndex
		|FROM
		|	" + FullTableName + "
		|ORDER BY
		|	IsFolder HIERARCHY,
		|	Description
		|");
		
	Return QueryResultToXMLTree(Query);
EndFunction

Function HierarchicalCatalogItemsHierarchyItems(Val FullTableName)
	
	Query = New Query("
		|SELECT TOP 2000
		|	Ref,
		|	Presentation,
		|	CASE
		|		WHEN DeletionMark THEN 3
		|		ELSE 2
		|	END AS PictureIndex
		|FROM
		|	" + FullTableName + "
		|ORDER BY
		|	Description HIERARCHY
		|");
		
	Return QueryResultToXMLTree(Query);
EndFunction

Function NonhierarchicalCatalogItems(Val FullTableName)
	
	Query = New Query("
		|SELECT TOP 2000
		|	Ref,
		|	Presentation,
		|	CASE
		|		WHEN DeletionMark THEN 3
		|		ELSE 2
		|	END AS PictureIndex
		|FROM
		|	" + FullTableName + " 
		|ORDER BY
		|	Description
		|");
		
	Return QueryResultToXMLTree(Query);
EndFunction

Function QueryResultToXMLTree(Val Query)
	Result = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	
	Result.Columns.Add("ID", New TypeDescription("String"));
	FillRefIDInTree(Result.Rows);
	Result.Columns.Delete("Ref");
	
	Return Common.ValueToXMLString(Result);
EndFunction

Procedure FillRefIDInTree(TreeRows)
	
	For Each Row In TreeRows Do
		Row.ID = ValueToStringInternal(Row.Ref);
		FillRefIDInTree(Row.Rows);
	EndDo;
	
EndProcedure

Function CorrespondentData(Val FullTableName) Export
	
	Result = New Structure("MetadataObjectProperties, CorrespondentInfobaseTable");
	
	Result.MetadataObjectProperties = MetadataObjectProperties(FullTableName);
	Result.CorrespondentInfobaseTable = GetTableObjects(FullTableName);
	
	Return Result;
EndFunction

Function InfobaseParameters(Val ExchangePlanName, Val NodeCode, ErrorMessage) Export
	
	Result = New Structure;
	
	Result.Insert("ExchangePlanExists",                      False);
	Result.Insert("InfobasePrefix",                 "");
	Result.Insert("DefaultInfobasePrefix",      "");
	Result.Insert("InfobaseDescription",            "");
	Result.Insert("DefaultInfobaseDescription", "");
	Result.Insert("AccountingParametersSettingsAreSpecified",            False);
	Result.Insert("ThisNodeCode",                              "");
	// SSL version 2.1.5.1 or later.
	Result.Insert("ConfigurationVersion",                        Metadata.Version);
	// SSL version 2.4.2(?) or later.
	Result.Insert("NodeExists",                            False);
	// SSL version 3.0.1.1 or later.
	Result.Insert("DataExchangeSettingsFormatVersion",        ModuleDataExchangeCreationWizard().DataExchangeSettingsFormatVersion());
	Result.Insert("UsePrefixesForExchangeSettings",    True);
	Result.Insert("ExchangeFormat",                              "");
	Result.Insert("ExchangePlanName",                            ExchangePlanName);
	Result.Insert("ExchangeFormatVersions",                       New Array);
	Result.Insert("SupportedObjectsInFormat",              Undefined);
	
	Result.Insert("DataSynchronizationSetupCompleted",     False);
	Result.Insert("EmailReceivedForDataMapping",   False);
	Result.Insert("DataMappingSupported",         True);
	
	SetPrivilegedMode(True);
	
	Result.ExchangePlanExists = (Metadata.ExchangePlans.Find(ExchangePlanName) <> Undefined);
	
	If Not Result.ExchangePlanExists Then
		// Exchange format can be passed as an exchange plan name.
		For Each ExchangePlan In DataExchangeCached.SSLExchangePlans() Do
			If Not DataExchangeCached.IsXDTOExchangePlan(ExchangePlan) Then
				Continue;
			EndIf;
			
			ExchangeFormat = ExchangePlanSettingValue(ExchangePlan, "ExchangeFormat");
			If ExchangePlanName = ExchangeFormat Then
				Result.ExchangePlanExists = True;
				Result.ExchangePlanName = ExchangePlan;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	If Not Result.ExchangePlanExists Then
		Return Result;
	EndIf;
	
	ThisNode = ExchangePlans[Result.ExchangePlanName].ThisNode();
	
	ThisNodeProperties = Common.ObjectAttributesValues(ThisNode, "Code, Description");
	
	InfobasePrefix = Undefined;
	DataExchangeOverridable.OnDetermineDefaultInfobasePrefix(InfobasePrefix);
	
	CorrespondentNode = Undefined;
	If ValueIsFilled(NodeCode) Then
		CorrespondentNode = ExchangePlanNodeByCode(Result.ExchangePlanName, NodeCode);
	EndIf;
	
	Result.InfobasePrefix            = GetFunctionalOption("InfobasePrefix");
	Result.DefaultInfobasePrefix = InfobasePrefix;
	Result.InfobaseDescription       = ThisNodeProperties.Description;
	Result.NodeExists                       = ValueIsFilled(CorrespondentNode);
	Result.AccountingParametersSettingsAreSpecified       = Result.NodeExists
		AND AccountingParametersSettingsAreSet(Result.ExchangePlanName, NodeCode, ErrorMessage);
	Result.ThisNodeCode                         = ThisNodeProperties.Code;
	Result.ConfigurationVersion                   = Metadata.Version;
	
	Result.DefaultInfobaseDescription = ?(Common.DataSeparationEnabled(),
		Metadata.Synonym, DataExchangeCached.ThisInfobaseName());
		
	If DataExchangeCached.IsXDTOExchangePlan(Result.ExchangePlanName) Then
		Result.UsePrefixesForExchangeSettings = 
			Not DataExchangeXDTOServer.VersionWithDataExchangeIDSupported(ThisNode);
			
		ExchangePlanProperties = ExchangePlanSettingValue(Result.ExchangePlanName, "ExchangeFormatVersions, ExchangeFormat");
		
		Result.ExchangeFormat        = ExchangePlanProperties.ExchangeFormat;
		Result.ExchangeFormatVersions = Common.UnloadColumn(ExchangePlanProperties.ExchangeFormatVersions, "Key", True);
		
		Result.Insert("SupportedObjectsInFormat",
			DataExchangeXDTOServer.SupportedObjectsInFormat(Result.ExchangePlanName, "SendReceive", CorrespondentNode));
	EndIf;
		
	If Result.NodeExists Then
		Result.DataSynchronizationSetupCompleted   = SynchronizationSetupCompleted(CorrespondentNode);
		Result.EmailReceivedForDataMapping = MessageWithDataForMappingReceived(CorrespondentNode);
		Result.DataMappingSupported = ExchangePlanSettingValue(Result.ExchangePlanName,
			"DataMappingSupported", SavedExchangePlanNodeSettingOption(CorrespondentNode));
	EndIf;
			
	Return Result;
	
EndFunction

Function StatisticsInformation(StatisticsInformation, Val EnableObjectDeletion = False) Export
	
	ArrayFilter = StatisticsInformation.UnloadColumn("DestinationTableName");
	
	FilterString = StrConcat(ArrayFilter, ",");
	
	Filter = New Structure("FullName", FilterString);
	
	// Getting configuration metadata object tree.
	StatisticsInformationTree = DataExchangeCached.ConfigurationMetadata(Filter).Copy();
	
	// Adding columns
	StatisticsInformationTree.Columns.Add("Key");
	StatisticsInformationTree.Columns.Add("ObjectCountInSource");
	StatisticsInformationTree.Columns.Add("ObjectCountInDestination");
	StatisticsInformationTree.Columns.Add("UnmappedObjectCount");
	StatisticsInformationTree.Columns.Add("MappedObjectPercentage");
	StatisticsInformationTree.Columns.Add("PictureIndex");
	StatisticsInformationTree.Columns.Add("UsePreview");
	StatisticsInformationTree.Columns.Add("DestinationTableName");
	StatisticsInformationTree.Columns.Add("ObjectTypeString");
	StatisticsInformationTree.Columns.Add("TableFields");
	StatisticsInformationTree.Columns.Add("SearchFields");
	StatisticsInformationTree.Columns.Add("SourceTypeString");
	StatisticsInformationTree.Columns.Add("DestinationTypeString");
	StatisticsInformationTree.Columns.Add("IsObjectDeletion");
	StatisticsInformationTree.Columns.Add("DataImportedSuccessfully");
	
	
	// Indexes for searching in the statistics.
	Indexes = StatisticsInformation.Indexes;
	If Indexes.Count() = 0 Then
		If EnableObjectDeletion Then
			Indexes.Add("IsObjectDeletion");
			Indexes.Add("OneToMany, IsObjectDeletion");
			Indexes.Add("IsClassifier, IsObjectDeletion");
		Else
			Indexes.Add("OneToMany");
			Indexes.Add("IsClassifier");
		EndIf;
	EndIf;
	
	ProcessedRows = New Map;
	
	// Normal strings
	Filter = New Structure("OneToMany", False);
	If Not EnableObjectDeletion Then
		Filter.Insert("IsObjectDeletion", False);
	EndIf;
		
	For Each TableRow In StatisticsInformation.FindRows(Filter) Do
		TreeRow = StatisticsInformationTree.Rows.Find(TableRow.DestinationTableName, "FullName", True);
		FillPropertyValues(TreeRow, TableRow);
		
		TreeRow.Synonym = DataSynonymOfStatisticsTreeRow(TreeRow, TableRow.SourceTypeString);
		
		ProcessedRows[TableRow] = True;
	EndDo;
	
	// Adding rows of OneToMany type.
	Filter = New Structure("OneToMany", True);
	If Not EnableObjectDeletion Then
		Filter.Insert("IsObjectDeletion", False);
	EndIf;
	FillStatisticsTreeOneToMany(StatisticsInformationTree, StatisticsInformation, Filter, ProcessedRows);
	
	// Adding classifier rows.
	Filter = New Structure("IsClassifier", True);
	If Not EnableObjectDeletion Then
		Filter.Insert("IsObjectDeletion", False);
	EndIf;
	FillStatisticsTreeOneToMany(StatisticsInformationTree, StatisticsInformation, Filter, ProcessedRows);
	
	// Adding rows for object deletion.
	If EnableObjectDeletion Then
		Filter = New Structure("IsObjectDeletion", True);
		FillStatisticsTreeOneToMany(StatisticsInformationTree, StatisticsInformation, Filter, ProcessedRows);
	EndIf;
	
	// Clearing empty rows
	StatisticsRows = StatisticsInformationTree.Rows;
	GroupPosition = StatisticsRows.Count() - 1;
	While GroupPosition >=0 Do
		Folder = StatisticsRows[GroupPosition];
		
		Items = Folder.Rows;
		Position = Items.Count() - 1;
		While Position >=0 Do
			Item = Items[Position];
			
			If Item.ObjectCountInDestination = Undefined 
				AND Item.ObjectCountInSource = Undefined
				AND Item.Rows.Count() = 0 Then
				Items.Delete(Item);
			EndIf;
			
			Position = Position - 1;
		EndDo;
		
		If Items.Count() = 0 Then
			StatisticsRows.Delete(Folder);
		EndIf;
		GroupPosition = GroupPosition - 1;
	EndDo;
	
	Return StatisticsInformationTree;
EndFunction

Procedure FillStatisticsTreeOneToMany(StatisticsInformationTree, StatisticsInformation, Filter, AlreadyProcessedRows)
	
	RowsToProcess = StatisticsInformation.FindRows(Filter);
	
	// Ignoring processed source rows.
	Position = RowsToProcess.UBound();
	While Position >= 0 Do
		Candidate = RowsToProcess[Position];
		
		If AlreadyProcessedRows[Candidate] <> Undefined Then
			RowsToProcess.Delete(Position);
		Else
			AlreadyProcessedRows[Candidate] = True;
		EndIf;
		
		Position = Position - 1;
	EndDo;
		
	If RowsToProcess.Count() = 0 Then
		Return;
	EndIf;
	
	StatisticsOneToMany = StatisticsInformation.Copy(RowsToProcess);
	StatisticsOneToMany.Indexes.Add("DestinationTableName");
	
	StatisticsOneToManyTemporary = StatisticsOneToMany.Copy(RowsToProcess, "DestinationTableName");
	
	StatisticsOneToManyTemporary.GroupBy("DestinationTableName");
	
	For Each TableRow In StatisticsOneToManyTemporary Do
		Rows       = StatisticsOneToMany.FindRows(New Structure("DestinationTableName", TableRow.DestinationTableName));
		TreeRow = StatisticsInformationTree.Rows.Find(TableRow.DestinationTableName, "FullName", True);
		
		For Each Row In Rows Do
			NewTreeRow = TreeRow.Rows.Add();
			FillPropertyValues(NewTreeRow, TreeRow);
			FillPropertyValues(NewTreeRow, Row);
			
			If Row.IsObjectDeletion Then
				NewTreeRow.Picture = PictureLib.MarkToDelete;
			Else
				NewTreeRow.Synonym = DataSynonymOfStatisticsTreeRow(NewTreeRow, Row.SourceTypeString) ;
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

Function DeleteClassNameFromObjectName(Val Result)
	
	Result = StrReplace(Result, "DocumentRef.", "");
	Result = StrReplace(Result, "CatalogRef.", "");
	Result = StrReplace(Result, "ChartOfCharacteristicTypesRef.", "");
	Result = StrReplace(Result, "ChartOfAccountsRef.", "");
	Result = StrReplace(Result, "ChartOfCalculationTypesRef.", "");
	Result = StrReplace(Result, "BusinessProcessRef.", "");
	Result = StrReplace(Result, "TaskRef.", "");
	
	Return Result;
EndFunction

Procedure CheckLoadedFromFileExchangeRulesAvailability(LoadedFromFileExchangeRules, RegistrationRulesImportedFromFile)
	
	QueryText = "SELECT DISTINCT
	|	DataExchangeRules.ExchangePlanName AS ExchangePlanName,
	|	DataExchangeRules.RulesKind AS RulesKind
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RulesSource = VALUE(Enum.DataExchangeRulesSources.File)
	|	AND DataExchangeRules.RulesAreImported";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		ExchangePlansArray = New Array;
		
		Selection = Result.Select();
		
		While Selection.Next() Do
			
			If Selection.RulesKind = Enums.DataExchangeRulesTypes.ObjectConversionRules Then
				
				LoadedFromFileExchangeRules.Add(Selection.ExchangePlanName);
				
			ElsIf Selection.RulesKind = Enums.DataExchangeRulesTypes.ObjectsRegistrationRules Then
				
				RegistrationRulesImportedFromFile.Add(Selection.ExchangePlanName);
				
			EndIf;
			
			If ExchangePlansArray.Find(Selection.ExchangePlanName) = Undefined Then
				
				ExchangePlansArray.Add(Selection.ExchangePlanName);
				
			EndIf;
			
		EndDo;
		
		MessageString = NStr("ru = 'ŠŠ»Ń ŠæŠ»Š°Š½Š¾Š² Š¾Š±Š¼ŠµŠ½Š° %1 ŠøŃŠæŠ¾Š»ŃŠ·ŃŃŃŃŃ ŠæŃŠ°Š²ŠøŠ»Š° Š¾Š±Š¼ŠµŠ½Š°, Š·Š°Š³ŃŃŠ¶ŠµŠ½Š½ŃŠµ ŠøŠ· ŃŠ°Š¹Š»Š°.
				|Š­ŃŠø ŠæŃŠ°Š²ŠøŠ»Š° Š¼Š¾Š³ŃŃ Š±ŃŃŃ Š½ŠµŃŠ¾Š²Š¼ŠµŃŃŠøŠ¼Ń Ń Š½Š¾Š²Š¾Š¹ Š²ŠµŃŃŠøŠµŠ¹ ŠæŃŠ¾Š³ŃŠ°Š¼Š¼Ń.
				|ŠŠ»Ń ŠæŃŠµŠ“ŃŠæŃŠµŠ¶Š“ŠµŠ½ŠøŃ Š²Š¾Š·Š¼Š¾Š¶Š½Š¾Š³Š¾ Š²Š¾Š·Š½ŠøŠŗŠ½Š¾Š²ŠµŠ½ŠøŃ Š¾ŃŠøŠ±Š¾Šŗ ŠæŃŠø ŃŠ°Š±Š¾ŃŠµ Ń ŠæŃŠ¾Š³ŃŠ°Š¼Š¼Š¾Š¹ ŃŠµŠŗŠ¾Š¼ŠµŠ½Š“ŃŠµŃŃŃ Š°ŠŗŃŃŠ°Š»ŠøŠ·ŠøŃŠ¾Š²Š°ŃŃ ŠæŃŠ°Š²ŠøŠ»Š° Š¾Š±Š¼ŠµŠ½Š° ŠøŠ· ŃŠ°Š¹Š»Š°.'; 
				|en = 'The exchange rules imported from file are used for exchange plans %1.
				|These rules can be incompatible with the new application version.
				|To prevent any possible errors when working with the application, it is recommended that you update the exchange rules from file.'; 
				|pl = 'Do %1 planĆ³w wymiany, stosowane sÄ reguÅy wymiany importowane z pliku.
				|ReguÅy te mogÄ byÄ niezgodne z nowÄ wersjÄ aplikacji.
				|Aby zapobiec moÅ¼liwym bÅÄdom podczas pracy z aplikacjÄ, zaleca siÄ aktualizacjÄ reguÅ wymiany z pliku.';
				|es_ES = 'Para %1 los planes de intercambio, las reglas de intercambio importadas desde el archivo se utilizan.
				|Estas reglas pueden ser incompatibles con la versiĆ³n nueva de la aplicaciĆ³n.
				|Para prevenir el acontecimiento de un posible error durante el trabajo con la aplicaciĆ³n, se recomienda actualizar las reglas de intercambio desde el archivo.';
				|es_CO = 'Para %1 los planes de intercambio, las reglas de intercambio importadas desde el archivo se utilizan.
				|Estas reglas pueden ser incompatibles con la versiĆ³n nueva de la aplicaciĆ³n.
				|Para prevenir el acontecimiento de un posible error durante el trabajo con la aplicaciĆ³n, se recomienda actualizar las reglas de intercambio desde el archivo.';
				|tr = 'DeÄiÅim planlarÄ± %1 iĆ§in dosyadan aktarÄ±lan deÄiÅim kurallarÄ± kullanÄ±lÄ±r. 
				|Bu kurallar yeni uygulama sĆ¼rĆ¼mĆ¼ ile uyumsuz olabilir. 
				|Uygulama ile Ć§alÄ±ÅÄ±rken olasÄ± hata oluÅumunu Ć¶nlemek iĆ§in, deÄiÅim kurallarÄ±nÄ± dosyadan gerĆ§ekleÅtirmeniz Ć¶nerilir.';
				|it = 'Le regole di scambio importate da file sono utilizzate per i piani di scambio %1.
				|Queste regolo possono essere incompatibili con la nuova versione dell''applicazione.
				|Per prevenire qualsiasi possibile errore durante il lavoro con l''applicazione, si consiglia di aggiornare le regole di scambio dal file.';
				|de = 'FĆ¼r %1 AustauschplĆ¤ne werden die aus einer Datei importierten Austauschregeln verwendet.
				|Diese Regeln kĆ¶nnen mit der neuen Anwendungsversion nicht kompatibel sein.
				|Um mĆ¶gliche Fehler beim Arbeiten mit der Anwendung zu vermeiden, empfiehlt es sich, die Austauschregeln aus der Datei zu aktualisieren.'",
				CommonClientServer.DefaultLanguageCode());
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, StrConcat(ExchangePlansArray, ","));
		
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Error,,, MessageString);
		
	EndIf;
	
EndProcedure

// Verifies the transport processor connection by the specified settings.
//
Procedure CheckExchangeMessageTransportDataProcessorAttachment(Cancel,
		SettingsStructure, TransportKind, ErrorMessage = "", NewPassword = Undefined) Export
	
	SetPrivilegedMode(True);
	
	// Creating data processor instance.
	DataProcessorObject = DataProcessors[DataExchangeMessageTransportDataProcessorName(TransportKind)].Create();
	
	// Initializing data processor properties with the passed settings parameters.
	FillPropertyValues(DataProcessorObject, SettingsStructure);
	
	// Privileged mode has already been set.
	If SettingsStructure.Property("Correspondent") Then
		If NewPassword = Undefined Then
			Passwords = Common.ReadDataFromSecureStorage(SettingsStructure.Correspondent,
				"COMUserPassword, FTPConnectionPassword, WSPassword, ArchivePasswordExchangeMessages", True);
		Else
			Passwords = New Structure;
			Passwords.Insert("COMUserPassword", NewPassword);
			Passwords.Insert("FTPConnectionPassword", NewPassword);
			Passwords.Insert("WSPassword", NewPassword);
			Passwords.Insert("ArchivePasswordExchangeMessages", NewPassword);
		EndIf;
		FillPropertyValues(DataProcessorObject, Passwords);
	EndIf;
	
	// Initializing the exchange transport.
	DataProcessorObject.Initializing();
	
	// Checking the connection.
	If Not DataProcessorObject.ConnectionIsSet() Then
		
		Cancel = True;
		
		ErrorMessage = DataProcessorObject.ErrorMessageString
			+ Chars.LF + NStr("ru = 'Š¢ŠµŃŠ½ŠøŃŠµŃŠŗŃŃ ŠøŠ½ŃŠ¾ŃŠ¼Š°ŃŠøŃ Š¾Š± Š¾ŃŠøŠ±ŠŗŠµ ŃŠ¼. Š² Š¶ŃŃŠ½Š°Š»Šµ ŃŠµŠ³ŠøŃŃŃŠ°ŃŠøŠø.'; en = 'See technical error details in the event log.'; pl = 'Informacje techniczne o bÅÄdzie znajdziesz w dzienniku wydarzeÅ.';es_ES = 'Ver la informaciĆ³n tĆ©cnica sobre el error en el registro de eventos.';es_CO = 'Ver la informaciĆ³n tĆ©cnica sobre el error en el registro de eventos.';tr = 'Olay gĆ¼nlĆ¼ÄĆ¼ndeki hata hakkÄ±ndaki teknik bilgilere bakÄ±n.';it = 'Visualizzare i dettagli dell''errore tecnico nel registro degli eventi.';de = 'Siehe technische Informationen zum Fehler im Ereignisprotokoll.'");
		
		WriteLogEvent(NStr("ru = 'Š¢ŃŠ°Š½ŃŠæŠ¾ŃŃ ŃŠ¾Š¾Š±ŃŠµŠ½ŠøŠ¹ Š¾Š±Š¼ŠµŠ½Š°'; en = 'Exchange message transport.'; pl = 'Transport wiadomoÅci wymiany';es_ES = 'Transporte de mensajes de intercambio';es_CO = 'Transporte de mensajes de intercambio';tr = 'DeÄiÅim ileti aktarÄ±mÄ±';it = 'Trasporto messaggi di scambio';de = 'Austausch-Nachrichtentransport'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, , , DataProcessorObject.ErrorMessageStringEL);
		
	EndIf;
	
EndProcedure

// Main function that is used to perform the data exchange over the external connection.
//
// Parameters:
//  SettingsStructure - a structure of COM exchange transport settings.
//
// Returns:
//  Structure - 
//    * Connection - COMObject, Undefined - if the connection is established, returns a COM object 
//                                    reference. Otherwise, returns Undefined.
//    * BriefErrorDescription       - String - a brief error description.
//    * DetailedErrorDescription     - String - a detailed error description.
//    * ErrorAttachingAddIn - Boolean - a COM connection error flag.
//
Function EstablishExternalConnectionWithInfobase(SettingsStructure) Export
	
	Result = CommonClientServer.EstablishExternalConnectionWithInfobase(
		FillExternalConnectionParameters(SettingsStructure));
	
	ExternalConnection = Result.Connection;
	If ExternalConnection = Undefined Then
		// Connection establish error.
		Return Result;
	EndIf;
	
	// Checking whether it is possible to operate with the external infobase.
	
	Try
		NoFullAccess = Not ExternalConnection.DataExchangeExternalConnection.RoleAvailableFullAccess();
	Except
		NoFullAccess = True;
	EndTry;
	
	If NoFullAccess Then
		Result.DetailedErrorDescription = NStr("ru = 'ŠŠ¾Š»ŃŠ·Š¾Š²Š°ŃŠµŠ»Ń, ŃŠŗŠ°Š·Š°Š½Š½Š¾Š¼Ń Š“Š»Ń ŠæŠ¾Š“ŠŗŠ»ŃŃŠµŠ½ŠøŃ Šŗ Š“ŃŃŠ³Š¾Š¹ ŠæŃŠ¾Š³ŃŠ°Š¼Š¼Šµ, Š“Š¾Š»Š¶Š½Ń Š±ŃŃŃ Š½Š°Š·Š½Š°ŃŠµŠ½Ń ŃŠ¾Š»Šø ""ŠŠ“Š¼ŠøŠ½ŠøŃŃŃŠ°ŃŠ¾Ń ŃŠøŃŃŠµŠ¼Ń"" Šø ""ŠŠ¾Š»Š½ŃŠµ ŠæŃŠ°Š²Š°""'; en = 'The ""System administrator"" and ""Full access"" roles must be assigned to the user that is used to establish connection to the other application.'; pl = 'UÅ¼ytkownikowi, wskazanemu do poÅÄczenia z innÄ aplikacjÄ powinny zostaÄ przypisane role ""Administrator systemu"" i ""PeÅne uprawnienia""';es_ES = 'Usuario especificado para la conexiĆ³n a otra aplicaciĆ³n tiene que tener los roles asignados de ""Administrador del sistema"" y ""Plenos derechos""';es_CO = 'Usuario especificado para la conexiĆ³n a otra aplicaciĆ³n tiene que tener los roles asignados de ""Administrador del sistema"" y ""Plenos derechos""';tr = 'BaÅka bir uygulamaya baÄlantÄ± iĆ§in belirtilen kullanÄ±cÄ± ""Sistem yĆ¶neticisi"" ve ""Tam haklar"" rollerine atanmÄ±Å olmalÄ±dÄ±r.';it = 'I ruoli ""Amministratore di sistema"" e ""Accesso pieno"" devono essere assegnati all''utente utilizzato per stabilire una connessione all''altra applicazione.';de = 'Benutzer, der fĆ¼r die Verbindung mit einer anderen Anwendung angegeben wurde, sollte die Rollen ""Systemadministrator"" und ""Volle Rechte"" zugewiesen bekommen haben'");
		Result.BriefErrorDescription   = Result.DetailedErrorDescription;
		Result.Connection = Undefined;
	Else
		Try 
			InvalidState = ExternalConnection.InfobaseUpdate.InfobaseUpdateRequired();
		Except
			InvalidState = False
		EndTry;
		
		If InvalidState Then
			Result.DetailedErrorDescription = NStr("ru = 'ŠŃŃŠ³Š°Ń ŠæŃŠ¾Š³ŃŠ°Š¼Š¼Š° Š½Š°ŃŠ¾Š“ŠøŃŃŃ Š² ŃŠ¾ŃŃŠ¾ŃŠ½ŠøŠø Š¾Š±Š½Š¾Š²Š»ŠµŠ½ŠøŃ.'; en = 'Other application is updating now.'; pl = 'Trwa aktualizacja innej aplikacji.';es_ES = 'Otra aplicaciĆ³n se estĆ” actualizando.';es_CO = 'Otra aplicaciĆ³n se estĆ” actualizando.';tr = 'BaÅka bir uygulama gĆ¼ncelleniyor.';it = 'L''altra applicazione sta effettuando l''aggiornamento.';de = 'Eine andere Anwendung wird aktualisiert.'");
			Result.BriefErrorDescription   = Result.DetailedErrorDescription;
			Result.Connection = Undefined;
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

Function TransportSettingsByExternalConnectionParameters(Parameters)
	
	// Converting external connection parameters to transport parameters.
	TransportSettings = New Structure;
	
	TransportSettings.Insert("COMUserPassword",
		CommonClientServer.StructureProperty(Parameters, "UserPassword"));
	TransportSettings.Insert("COMUsername",
		CommonClientServer.StructureProperty(Parameters, "UserName"));
	TransportSettings.Insert("COMOperatingSystemAuthentication",
		CommonClientServer.StructureProperty(Parameters, "OperatingSystemAuthentication"));
	TransportSettings.Insert("COM1CEnterpriseServerSideInfobaseName",
		CommonClientServer.StructureProperty(Parameters, "NameOfInfobaseOn1CEnterpriseServer"));
	TransportSettings.Insert("COM1CEnterpriseServerName",
		CommonClientServer.StructureProperty(Parameters, "NameOf1CEnterpriseServer"));
	TransportSettings.Insert("COMInfobaseDirectory",
		CommonClientServer.StructureProperty(Parameters, "InfobaseDirectory"));
	TransportSettings.Insert("COMInfobaseOperatingMode",
		CommonClientServer.StructureProperty(Parameters, "InfobaseOperatingMode"));
	
	Return TransportSettings;
	
EndFunction

Function WSProxyForInfobaseNode(InfobaseNode,
		ErrorMessageString = "", AuthenticationParameters = Undefined, EarliestVersion = "")
	
	If DataExchangeCached.IsMessagesExchangeNode(InfobaseNode) Then
		ModuleMessagesExchangeTransportSettings = InformationRegisters["MessageExchangeTransportSettings"];
		SettingsStructure = ModuleMessagesExchangeTransportSettings.TransportSettingsWS(InfobaseNode, AuthenticationParameters);
	Else
		SettingsStructure = InformationRegisters.DataExchangeTransportSettings.TransportSettingsWS(InfobaseNode, AuthenticationParameters);
	EndIf;
	
	Try
		CorrespondentVersions = DataExchangeCached.CorrespondentVersions(SettingsStructure);
	Except
		ErrorMessageString = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(EventLogEventEstablishWebServiceConnection(),
			EventLogLevel.Error,,, ErrorMessageString);
		Return Undefined;
	EndTry;
	
	CorrespondentVersion_2_0_1_6 = (CorrespondentVersions.Find("2.0.1.6") <> Undefined);
	CorrespondentVersion_2_1_1_7 = (CorrespondentVersions.Find("2.1.1.7") <> Undefined);
	CorrespondentVersion_3_0_1_1 = (CorrespondentVersions.Find("3.0.1.1") <> Undefined);
	
	If Not IsBlankString(EarliestVersion) Then
		If EarliestVersion = "3.0.1.1"
			AND Not CorrespondentVersion_3_0_1_1 Then
			ErrorMessageString = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'ŠŠ¾ŃŃŠµŃŠæŠ¾Š½Š“ŠµŠ½Ń Š½Šµ ŠæŠ¾Š“Š“ŠµŃŠ¶ŠøŠ²Š°ŠµŃ ŃŃŠµŠ±ŃŠµŠ¼ŃŃ Š²ŠµŃŃŠøŃ %1 ŠøŠ½ŃŠµŃŃŠµŠ¹ŃŠ° ""DataExchange"".'; en = 'The correspondent does not support DataExchange interface version %1.'; pl = 'Korespondent nie obsÅuguje potrzebnÄ wersjÄ %1 interfejsu ""DataExchange"".';es_ES = 'Correspondiente no soporta la versiĆ³n requerida %1 de la interfaz ""DataExchange"".';es_CO = 'Correspondiente no soporta la versiĆ³n requerida %1 de la interfaz ""DataExchange"".';tr = 'Muhabir, ""DataExchange"" arabirimin %1gerekli sĆ¼rĆ¼mĆ¼nĆ¼ desteklemiyor.';it = 'Il corrispondente non supporta la versione di interfaccia DataExchange %1.';de = 'Der Korrespondent unterstĆ¼tzt nicht die erforderliche Version %1 der Schnittstelle ""DatenAustausch"".'"),
				EarliestVersion);
			Return Undefined;
		EndIf;
	EndIf;
	
	If CorrespondentVersion_3_0_1_1 Then
		
		WSProxy = GetWSProxy_3_0_1_1(SettingsStructure, ErrorMessageString);
		
	ElsIf CorrespondentVersion_2_1_1_7 Then
		
		WSProxy = GetWSProxy_2_1_1_7(SettingsStructure, ErrorMessageString);
		
	ElsIf CorrespondentVersion_2_0_1_6 Then
		
		WSProxy = GetWSProxy_2_0_1_6(SettingsStructure, ErrorMessageString);
		
	Else
		
		WSProxy = GetWSProxy(SettingsStructure, ErrorMessageString);
		
	EndIf;
	
	Return WSProxy;
EndFunction

Procedure DeleteInsignificantCharactersInConnectionSettings(Settings)
	
	For Each Setting In Settings Do
		
		If TypeOf(Setting.Value) = Type("String") Then
			
			Settings.Insert(Setting.Key, TrimAll(Setting.Value));
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function CorrespondentConnectionEstablished(Val Correspondent, Val SettingsStructure, UserMessage = "") Export
	
	EventLogEvent = NStr("ru = 'ŠŠ±Š¼ŠµŠ½ Š“Š°Š½Š½ŃŠ¼Šø.ŠŃŠ¾Š²ŠµŃŠŗŠ° ŠæŠ¾Š“ŠŗŠ»ŃŃŠµŠ½ŠøŃ'; en = 'Data exchange.Connection test'; pl = 'Wymiana danych. Sprawdzanie poÅÄczenia';es_ES = 'Intercambio de datos.RevisiĆ³n de conexiĆ³n';es_CO = 'Intercambio de datos.RevisiĆ³n de conexiĆ³n';tr = 'Veri deÄiÅimi. BaÄlantÄ± kontrolĆ¼';it = 'Scambio dati. Test di connessione';de = 'Data exchange.Connection check'", CommonClientServer.DefaultLanguageCode());
	
	Try
		CorrespondentVersions = DataExchangeCached.CorrespondentVersions(SettingsStructure);
	Except
		ResetDataSynchronizationPassword(Correspondent);
		WriteLogEvent(EventLogEvent,
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		UserMessage = FirstErrorBriefPresentation(ErrorInfo());
		Return False;
	EndTry;
	
	CorrespondentVersion_2_0_1_6 = (CorrespondentVersions.Find("2.0.1.6") <> Undefined);
	CorrespondentVersion_2_1_1_7 = (CorrespondentVersions.Find("2.1.1.7") <> Undefined);
	CorrespondentVersion_3_0_1_1 = (CorrespondentVersions.Find("3.0.1.1") <> Undefined);
	
	If CorrespondentVersion_2_1_1_7
		Or CorrespondentVersion_3_0_1_1 Then
		
		WSProxy = Undefined;
		
		If CorrespondentVersion_3_0_1_1 Then
			WSProxy = GetWSProxy_3_0_1_1(SettingsStructure, , UserMessage, 5);
		ElsIf CorrespondentVersion_2_1_1_7 Then
			WSProxy = GetWSProxy_2_1_1_7(SettingsStructure, , UserMessage, 5);
		EndIf;
		
		If WSProxy = Undefined Then
			ResetDataSynchronizationPassword(Correspondent);
			Return False;
		EndIf;
		
		Try
			
			CorrespondentCode = NodeIDForExchange(Correspondent);
			ExchangePlanName    = DataExchangeCached.GetExchangePlanName(Correspondent);
			
			HasConnection = WSProxy.TestConnection(
				ExchangePlanName,
				CorrespondentCode,
				UserMessage);
				
			If Not HasConnection
				AND IsXDTOExchangePlan(Correspondent) Then
				
				Alias = PredefinedNodeAlias(Correspondent);
				
				If ValueIsFilled(Alias) Then
					CorrespondentCode = Alias;
					
					HasConnection = WSProxy.TestConnection(
						ExchangePlanName,
						CorrespondentCode,
						UserMessage);
				EndIf;
			EndIf;
			
			If Not HasConnection
				AND IsXDTOExchangePlan(Correspondent) Then
				
				SetupOption = "";
				If Common.HasObjectAttribute("SettingsMode", Correspondent.Metadata()) Then
					SetupOption = Common.ObjectAttributeValue(Correspondent, "SettingsMode");
				EndIf;
				
				If ValueIsFilled(SetupOption) Then
					For Each PreviousExchangePlanName In DataExchangeCached.SSLExchangePlans() Do
						If PreviousExchangePlanName = ExchangePlanName Then
							Continue;
						EndIf;
						If DataExchangeCached.IsDistributedInfobaseExchangePlan(PreviousExchangePlanName) Then
							Continue;
						EndIf;
						
						PreviousExchangePlanSettings = ExchangePlanSettingValue(PreviousExchangePlanName,
							"ExchangePlanNameToMigrateToNewExchange,ExchangeSettingsOptions");
						
						If PreviousExchangePlanSettings.ExchangePlanNameToMigrateToNewExchange = ExchangePlanName Then
							SettingsOption = PreviousExchangePlanSettings.ExchangeSettingsOptions.Find(SetupOption, "SettingID");
							If Not SettingsOption = Undefined Then
								
								XDTOCorrespondentParameters = WSProxy.GetIBParameters(
									PreviousExchangePlanName,
									CorrespondentCode,
									UserMessage);
									
								CorrespondentParameters = XDTOSerializer.ReadXDTO(XDTOCorrespondentParameters);
								
								HasConnection = CorrespondentParameters.ExchangePlanExists AND CorrespondentParameters.NodeExists;
								
								If HasConnection Then
									Break;
								EndIf;
								
							EndIf;
						EndIf;
					EndDo;
				EndIf;
					
			EndIf;
			
			If HasConnection Then
				SetDataSynchronizationPassword(Correspondent, SettingsStructure.WSPassword);
			EndIf;
			
			Return HasConnection;
		Except
			ResetDataSynchronizationPassword(Correspondent);
			WriteLogEvent(EventLogEvent,
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			UserMessage = FirstErrorBriefPresentation(ErrorInfo());
			Return False;
		EndTry;
		
	ElsIf CorrespondentVersion_2_0_1_6 Then
		
		WSProxy = GetWSProxy_2_0_1_6(SettingsStructure,, UserMessage);
		
	Else
		
		WSProxy = GetWSProxy(SettingsStructure,, UserMessage);
		
	EndIf;
	
	HasConnection = (WSProxy <> Undefined);
	
	If HasConnection Then
		SetDataSynchronizationPassword(Correspondent, SettingsStructure.WSPassword);
	Else
		ResetDataSynchronizationPassword(Correspondent);
	EndIf;
	
	Return HasConnection;
EndFunction

// Displays the error message and sets the Cancellation flag to True.
//
// Parameters:
//  MessageText - string, message text.
//  Cancel          - Boolean - a cancellation flag (optional).
//
Procedure ReportError(MessageText, Cancel = False) Export
	
	Cancel = True;
	
	CommonClientServer.MessageToUser(MessageText);
	
EndProcedure

// Gets the table of selective object registration from session parameters.
//
// Parameters:
// No.
// 
// Returns:
// Value table - a table of registration attributes for all metadata objects.
//
Function GetSelectiveObjectsRegistrationRulesSP() Export
	
	Return DataExchangeCached.GetSelectiveObjectsRegistrationRulesSP();
	
EndFunction

// Adds one record to the information register by the passed structure values.
//
// Parameters:
//  RecordStructure - Structure - a structure whose values will be used for creating and filling in 
//                                the record set.
//  RegisterName     - String - a name of information register to be supplied with a record.
// 
Procedure AddRecordToInformationRegister(RecordStructure, Val RegisterName, Import = False) Export
	
	RecordSet = CreateInformationRegisterRecordSet(RecordStructure, RegisterName);
	
	// Adding the single record to the new record set.
	NewRecord = RecordSet.Add();
	
	// Filling record property values from the passed structure.
	FillPropertyValues(NewRecord, RecordStructure);
	
	RecordSet.DataExchange.Load = Import;
	
	// Writing the record set
	RecordSet.Write();
	
EndProcedure

// Updates a record in the information register by the passed structure values.
//
// Parameters:
//  RecordStructure - Structure - a structure whose values will be used to create a record manager and update the record.
//  RegisterName     - String - a name of information register supplied with a record to be updated.
// 
Procedure UpdateInformationRegisterRecord(RecordStructure, Val RegisterName) Export
	
	RegisterMetadata = Metadata.InformationRegisters[RegisterName];
	
	// Creating a register record manager.
	RecordManager = InformationRegisters[RegisterName].CreateRecordManager();
	
	// Setting register dimension filters.
	For Each Dimension In RegisterMetadata.Dimensions Do
		
		// If dimension filter value is specified in a structure, the filter is set.
		If RecordStructure.Property(Dimension.Name) Then
			
			RecordManager[Dimension.Name] = RecordStructure[Dimension.Name];
			
		EndIf;
		
	EndDo;
	
	// Reading the record from the infobase.
	RecordManager.Read();
	
	// Filling record property values from the passed structure.
	FillPropertyValues(RecordManager, RecordStructure);
	
	// Writing the record manager
	RecordManager.Write();
	
EndProcedure

// Deletes a record set for the passed structure values from the register.
//
// Parameters:
//  RecordStructure - Structure - a structure whose values are used to delete a record set.
//  RegisterName     - String - a name of information register supplied with the record set to be deleted.
// 
Procedure DeleteRecordSetFromInformationRegister(RecordStructure, RegisterName, Import = False) Export
	
	RecordSet = CreateInformationRegisterRecordSet(RecordStructure, RegisterName);
	
	RecordSet.DataExchange.Load = Import;
	
	// Writing the record set
	RecordSet.Write();
	
EndProcedure

// Imports data exchange rules (ORR or OCR) into the infobase.
// 
Procedure ImportDataExchangeRules(Cancel,
										Val ExchangePlanName,
										Val RulesKind,
										Val RulesTemplateName,
										Val CorrespondentRuleTemplateName = "")
	
	RecordStructure = New Structure;
	RecordStructure.Insert("ExchangePlanName",  ExchangePlanName);
	RecordStructure.Insert("RulesKind",       RulesKind);
	If Not IsBlankString(CorrespondentRuleTemplateName) Then
		RecordStructure.Insert("CorrespondentRuleTemplateName", CorrespondentRuleTemplateName);
	EndIf;
	RecordStructure.Insert("RulesTemplateName", RulesTemplateName);
	RecordStructure.Insert("RulesSource",  Enums.DataExchangeRulesSources.ConfigurationTemplate);
	RecordStructure.Insert("UseSelectiveObjectRegistrationFilter", True);
	
	// Creating a register record set.
	RecordSet = CreateInformationRegisterRecordSet(RecordStructure, "DataExchangeRules");
	
	// Adding the single record to the new record set.
	NewRecord = RecordSet.Add();
	
	// Filling record properties with values from the structure.
	FillPropertyValues(NewRecord, RecordStructure);
	
	// Importing data exchange rules into the infobase.
	InformationRegisters.DataExchangeRules.ImportRules(Cancel, RecordSet[0]);
	
	If Not Cancel Then
		RecordSet.Write();
	EndIf;
	
EndProcedure

Procedure UpdateStandardDataExchangeRuleVersion(LoadedFromFileExchangeRules, RegistrationRulesImportedFromFile)
	
	Cancel = False;
	QueryText = "";
	
	For Each ExchangePlanName In DataExchangeCached.SSLExchangePlans() Do
		
		If Not IsBlankString(QueryText) Then
			QueryText = QueryText + Chars.LF + "UNION ALL" + Chars.LF;
		EndIf;
		
		QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersToString("SELECT
			|	COUNT (%1.Ref) AS Count,
			|	""%1"" AS ExchangePlanName
			|FROM
			|	ExchangePlan.%1 AS %1", ExchangePlanName);
			
	EndDo;
	If IsBlankString(QueryText) Then
		Return;
	EndIf;
	Query = New Query(QueryText);
	Result = Query.Execute().Unload();
	
	RulesUpdateExecuted = False;
	For Each ExchangePlanRecord In Result Do
		
		If ExchangePlanRecord.Count <= 1 
			AND Not Common.DataSeparationEnabled() Then // ThisNode only
			Continue;
		EndIf;
		
		ExchangePlanName = ExchangePlanRecord.ExchangePlanName;
		
		If LoadedFromFileExchangeRules.Find(ExchangePlanName) = Undefined
			AND DataExchangeCached.HasExchangePlanTemplate(ExchangePlanName, "ExchangeRules")
			AND DataExchangeCached.HasExchangePlanTemplate(ExchangePlanName, "CorrespondentExchangeRules") Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'ŠŃŠæŠ¾Š»Š½ŃŠµŃŃŃ Š¾Š±Š½Š¾Š²Š»ŠµŠ½ŠøŠµ ŠæŃŠ°Š²ŠøŠ» ŠŗŠ¾Š½Š²ŠµŃŃŠ°ŃŠøŠø Š“Š°Š½Š½ŃŃ Š“Š»Ń ŠæŠ»Š°Š½Š° Š¾Š±Š¼ŠµŠ½Š° %1'; en = 'Updating data conversion rules for the %1 exchange plan.'; pl = 'Aktualizacja reguÅ konwersji danych dla planu wymiany %1';es_ES = 'Actualizando las reglas de conversiĆ³n de datos para el plan de intercambio %1';es_CO = 'Actualizando las reglas de conversiĆ³n de datos para el plan de intercambio %1';tr = 'DeÄiÅim planÄ± iĆ§in veri dĆ¶nĆ¼ÅtĆ¼rme kurallarÄ±nÄ±n gĆ¼ncellenmesi%1';it = 'Aggiornamento regole di conversione dati per il piano di scambio %1.';de = 'Aktualisieren der Datenkonvertierungsregeln fĆ¼r den Austauschplan %1'"), ExchangePlanName);
			WriteLogEvent(EventLogMessageTextDataExchange(),
				EventLogLevel.Information,,, MessageText);
			
			ImportDataExchangeRules(Cancel, ExchangePlanName, Enums.DataExchangeRulesTypes.ObjectConversionRules,
				"ExchangeRules", "CorrespondentExchangeRules");
				
			RulesUpdateExecuted = True;
			
		EndIf;
		
		If RegistrationRulesImportedFromFile.Find(ExchangePlanName) = Undefined
			AND DataExchangeCached.HasExchangePlanTemplate(ExchangePlanName, "RecordRules") Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'ŠŃŠæŠ¾Š»Š½ŃŠµŃŃŃ Š¾Š±Š½Š¾Š²Š»ŠµŠ½ŠøŠµ ŠæŃŠ°Š²ŠøŠ» ŃŠµŠ³ŠøŃŃŃŠ°ŃŠøŠø Š“Š°Š½Š½ŃŃ Š“Š»Ń ŠæŠ»Š°Š½Š° Š¾Š±Š¼ŠµŠ½Š° %1'; en = 'Updating data registration rules for the %1 exchange plan.'; pl = 'Aktualizacja reguÅ rejestracji danych dla planu wymiany %1';es_ES = 'Actualizando las reglas de registro de datos para el plan de intercambio %1';es_CO = 'Actualizando las reglas de registro de datos para el plan de intercambio %1';tr = 'DeÄiÅim planÄ± iĆ§in veri kayÄ±t kurallarÄ±nÄ±n gĆ¼ncellenmesi%1';it = 'Aggiornamento regole di registrazione dati per il piano di scambio %1.';de = 'Aktualisierung der Datenregistrierungsregeln fĆ¼r den Austauschplan %1'"), ExchangePlanName);
			WriteLogEvent(EventLogMessageTextDataExchange(),
				EventLogLevel.Information,,, MessageText);
				
			ImportDataExchangeRules(Cancel, ExchangePlanName, Enums.DataExchangeRulesTypes.ObjectsRegistrationRules, "RecordRules");
			
			RulesUpdateExecuted = True;
			
		EndIf;
		
	EndDo;
	
	If Cancel Then
		Raise NStr("ru = 'ŠŃŠø Š¾Š±Š½Š¾Š²Š»ŠµŠ½ŠøŠø ŠæŃŠ°Š²ŠøŠ» Š¾Š±Š¼ŠµŠ½Š° Š“Š°Š½Š½ŃŠ¼Šø Š²Š¾Š·Š½ŠøŠŗŠ»Šø Š¾ŃŠøŠ±ŠŗŠø (ŃŠ¼. ŠŃŃŠ½Š°Š» ŃŠµŠ³ŠøŃŃŃŠ°ŃŠøŠø).'; en = 'Errors occurred during updating of data exchange rules (see the event log)'; pl = 'WystÄpiÅy bÅÄdy podczas aktualizacji reguÅ wymiany danych (zob. dziennik wydarzeÅ).';es_ES = 'Errores ocurridos durante la actualizaciĆ³n de las reglas del intercambio de datos (ver el registro de eventos).';es_CO = 'Errores ocurridos durante la actualizaciĆ³n de las reglas del intercambio de datos (ver el registro de eventos).';tr = 'Veri deÄiÅimi kurallarÄ±nÄ±n gĆ¼ncellenmesi sÄ±rasÄ±nda hatalar oluÅtu (olay gĆ¼nlĆ¼ÄĆ¼ne bakÄ±n).';it = 'Si sono verificati degli errore durante l''aggiornamento delle regole di scambio dati (visualizzare il registro degli eventi)';de = 'Bei der Aktualisierung der Datenaustauschregeln sind Fehler aufgetreten (siehe Ereignisprotokoll).'");
	EndIf;
	
	If RulesUpdateExecuted Then
		DataExchangeServerCall.ResetObjectsRegistrationMechanismCache();
	EndIf;
	
EndProcedure

// Creates an information register record set by the passed structure values. Adds a single record to the set.
//
// Parameters:
//  RecordStructure - Structure - a structure whose values will be used for creating and filling in 
//                                the record set.
//  RegisterName     - String - an information register name.
// 
Function CreateInformationRegisterRecordSet(RecordStructure, RegisterName)
	
	RegisterMetadata = Metadata.InformationRegisters[RegisterName];
	
	// Creating register record set.
	RecordSet = InformationRegisters[RegisterName].CreateRecordSet();
	
	// Setting register dimension filters.
	For Each Dimension In RegisterMetadata.Dimensions Do
		
		// If dimension filter value is specified in a structure, the filter is set.
		If RecordStructure.Property(Dimension.Name) Then
			
			RecordSet.Filter[Dimension.Name].Set(RecordStructure[Dimension.Name]);
			
		EndIf;
		
	EndDo;
	
	Return RecordSet;
EndFunction

// Receives a picture index to display it in the object mapping statistics table.
//
Function StatisticsTablePictureIndex(Val UnmappedObjectCount, Val DataImportedSuccessfully) Export
	
	Return ?(UnmappedObjectCount = 0, ?(DataImportedSuccessfully = True, 2, 0), 1);
	
EndFunction

// Checks whether the exchange message size exceed the maximum allowed size.
//
//  Returns:
//   True if the file size exceeds the maximum allowed size. Otherwise, False.
//
Function ExchangeMessageSizeExceedsAllowed(Val FileName, Val MaxMessageSize) Export
	
	// Function return value.
	Result = False;
	
	File = New File(FileName);
	
	If File.Exist() AND File.IsFile() Then
		
		If MaxMessageSize <> 0 Then
			
			PackageSize = Round(File.Size() / 1024, 0, RoundMode.Round15as20);
			
			If PackageSize > MaxMessageSize Then
				
				MessageString = NStr("ru = 'Š Š°Š·Š¼ŠµŃ ŠøŃŃŠ¾Š“ŃŃŠµŠ³Š¾ ŠæŠ°ŠŗŠµŃŠ° ŃŠ¾ŃŃŠ°Š²ŠøŠ» %1 ŠŠ±Š°Š¹Ń, ŃŃŠ¾ ŠæŃŠµŠ²ŃŃŠ°ŠµŃ Š“Š¾ŠæŃŃŃŠøŠ¼Š¾Šµ Š¾Š³ŃŠ°Š½ŠøŃŠµŠ½ŠøŠµ %2 ŠŠ±Š°Š¹Ń.'; en = 'The outgoing package size is %1 Kb. It exceeds the allowed limit (%2 Kb).'; pl = 'Rozmiar wychodzÄcego zestawu wyniĆ³sÅ %1 Kb, co przekracza dopuszczalne ograniczenie (%2 Kb).';es_ES = 'TamaĆ±o del paquete saliente es %1 KB, y excede el lĆ­mite permitido de %2 KB.';es_CO = 'TamaĆ±o del paquete saliente es %1 KB, y excede el lĆ­mite permitido de %2 KB.';tr = 'Giden paket boyutu %1KB''dir ve izin verilen %2KB sÄ±nÄ±rÄ±nÄ± aÅÄ±yor.';it = 'La dimensione del pacchetto in uscita ĆØ di %1 Kb. Supera il limite consentito (%2 Kb).';de = 'Die GrĆ¶Će des ausgehenden Pakets ist %1 KB und Ć¼berschreitet das zulĆ¤ssige %2 KB-Limit.'");
				MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, String(PackageSize), String(MaxMessageSize));
				ReportError(MessageString, Result);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function InitialDataExportFlagIsSet(InfobaseNode) Export
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.CommonInfobasesNodesSettings.InitialDataExportFlagIsSet(InfobaseNode);
	
EndFunction

Procedure RegisterOnlyCatalogsForInitialExport(Val InfobaseNode) Export
	
	RegisterDataForInitialExport(InfobaseNode, ExchangePlanCatalogs(InfobaseNode));
	
EndProcedure

Procedure RegisterCatalogsOnlyForInitialBackgroundExport(ProcedureParameters, StorageAddress) Export
	
	RegisterOnlyCatalogsForInitialExport(ProcedureParameters["InfobaseNode"]);
	
EndProcedure

Procedure RegisterAllDataExceptCatalogsForInitialExport(Val InfobaseNode) Export
	
	RegisterDataForInitialExport(InfobaseNode, AllExchangePlanDataExceptCatalogs(InfobaseNode));
	
EndProcedure

Procedure RegisterAllDataExceptCatalogsForInitialBackgroundExport(ProcedureParameters, StorageAddress) Export
	
	RegisterAllDataExceptCatalogsForInitialExport(ProcedureParameters["InfobaseNode"]);
	
EndProcedure

Procedure RegisterDataForInitialExport(InfobaseNode, Data = Undefined) Export
	
	SetPrivilegedMode(True);
	
	// Updating cached object registration values.
	DataExchangeServerCall.CheckObjectsRegistrationMechanismCache();
	
	StandardProcessing = True;
	
	DataExchangeOverridable.InitialDataExportChangesRegistration(InfobaseNode, StandardProcessing, Data);
	
	If StandardProcessing Then
		
		If TypeOf(Data) = Type("Array") Then
			
			For Each MetadataObject In Data Do
				
				ExchangePlans.RecordChanges(InfobaseNode, MetadataObject);
				
			EndDo;
			
		Else
			
			ExchangePlans.RecordChanges(InfobaseNode, Data);
			
		EndIf;
		
	EndIf;
	
	If DataExchangeCached.ExchangePlanContainsObject(DataExchangeCached.GetExchangePlanName(InfobaseNode),
		Metadata.InformationRegisters.InfobaseObjectsMaps.FullName()) Then
		
		ExchangePlans.DeleteChangeRecords(InfobaseNode, Metadata.InformationRegisters.InfobaseObjectsMaps);
		
	EndIf;
	
	If Not DataExchangeCached.IsDistributedInfobaseNode(InfobaseNode) Then
		
		// Setting the initial data export flag for the node.
		InformationRegisters.CommonInfobasesNodesSettings.SetInitialDataExportFlag(InfobaseNode);
		
	EndIf;
	
EndProcedure

// Imports the exchange message that contains configuration changes before infobase update.
// 
//
Procedure ImportMessageBeforeInfobaseUpdate()
	
	If DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
			"SkipImportDataExchangeMessageBeforeStart") Then
		Return;
	EndIf;
	
	If GetFunctionalOption("UseDataSynchronization") Then
		
		InfobaseNode = MasterNode();
		
		If InfobaseNode <> Undefined Then
			
			SetPrivilegedMode(True);
			SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", True);
			SetPrivilegedMode(False);
			
			Try
				// Updating object registration rules before importing data.
				UpdateDataExchangeRules();
				
				TransportKind = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(InfobaseNode);
				
				Cancel = False;
				
				ExchangeParameters = ExchangeParameters();
				ExchangeParameters.ExchangeMessagesTransportKind = TransportKind;
				ExchangeParameters.ExecuteImport = True;
				ExchangeParameters.ExecuteExport = False;
				ExecuteDataExchangeForInfobaseNode(InfobaseNode, ExchangeParameters, Cancel);
				
				// Repeat mode must be enabled in the following cases.
				// Case 1. A new configuration version is received and therefore infobase update is required.
				// If Cancel = True, the procedure execution must be stopped, otherwise data duplicates can be created,
				// - If Cancel = False, an error might occur during the infobase update and you might need to reimport the message.
				// Case 2. Received configuration version is equal to the current infobase configuration version and no updating required.
				// If Cancel = True, an error might occur during the infobase startup, possible cause is that 
				//   predefined items are not imported.
				// - If Cancel = False, it is possible to continue import because export can be performed later. If 
				//   export cannot be succeeded, it is possible to receive a new message to import.
				
				If Cancel OR InfobaseUpdate.InfobaseUpdateRequired() Then
					EnableDataExchangeMessageImportRecurrenceBeforeStart();
				EndIf;
				
				If Cancel Then
					Raise NStr("ru = 'ŠŠ¾Š»ŃŃŠµŠ½ŠøŠµ Š“Š°Š½Š½ŃŃ ŠøŠ· Š³Š»Š°Š²Š½Š¾Š³Š¾ ŃŠ·Š»Š° Š·Š°Š²ŠµŃŃŠøŠ»Š¾ŃŃ Ń Š¾ŃŠøŠ±ŠŗŠ°Š¼Šø.'; en = 'Errors occurred when getting data from the master node.'; pl = 'OdbiĆ³r danych z gÅĆ³wnego wÄzÅa zostaÅ zakoÅczony z bÅÄdami.';es_ES = 'RecepciĆ³n de los datos del nodo principal se ha finalizado con errores.';es_CO = 'RecepciĆ³n de los datos del nodo principal se ha finalizado con errores.';tr = 'Ana Ć¼niteden veri alÄ±mÄ± hatalarla tamamlandÄ±.';it = 'Si sono verificati degli errori durante la ricezione dei dati dal nodo principale.';de = 'Der Empfang von Daten vom Hauptknoten wird mit Fehlern abgeschlossen.'");
				EndIf;
			Except
				SetPrivilegedMode(True);
				SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", False);
				SetPrivilegedMode(False);
				Raise;
			EndTry;
			SetPrivilegedMode(True);
			SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", False);
			SetPrivilegedMode(False);
		EndIf;
		
	EndIf;
	
EndProcedure

// Sets to False the import repeat flag. It is called if errors occurred during message import or infobase updating.
Procedure DisableDataExchangeMessageImportRepeatBeforeStart() Export
	
	SetPrivilegedMode(True);
	
	If Constants.RetryDataExchangeMessageImportBeforeStart.Get() Then
		Constants.RetryDataExchangeMessageImportBeforeStart.Set(False);
	EndIf;
	
EndProcedure

// Performs import and export of an exchange message that contains configuration changes but 
// configuration update is not required.
// 
//
Procedure ExecuteSynchronizationWhenInfobaseUpdateAbsent(
		OnClientStart, Restart)
	
	If Not LoadDataExchangeMessage() Then
		// If the message import is canceled and the metadata configuration version is not increased, you 
		// have to disable the import repetition.
		DisableDataExchangeMessageImportRepeatBeforeStart();
		Return;
	EndIf;
		
	If ConfigurationChanged() Then
		// Configuration changes are imported but are not applied
		// Exchange message cannot be imported
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		ImportMessageBeforeInfobaseUpdate();
		CommitTransaction();
	Except
		If ConfigurationChanged() Then
			If NOT DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
				"MessageReceivedFromCache") Then
				// Updating configuration from version where cached exchange messages are not used.
				//  Perhaps, imported message contains configuration changes.
				//  Cannot determine whether the return to the database configuration was made.
				//  You have to commit the transaction and continue the start without exchange message export.
				// 
				CommitTransaction();
				Return;
			Else
				// Configuration changes are received. It means that return to database configuration was performed.
				// 
				// The data import must be cancelled.
				RollbackTransaction();
				SetPrivilegedMode(True);
				Constants.LoadDataExchangeMessage.Set(False);
				ClearDataExchangeMessageFromMasterNode();
				SetPrivilegedMode(False);
				WriteDataReceiveEvent(MasterNode(),
					NStr("ru = 'ŠŠ±Š½Š°ŃŃŠ¶ŠµŠ½ Š²Š¾Š·Š²ŃŠ°Ń Šŗ ŠŗŠ¾Š½ŃŠøŠ³ŃŃŠ°ŃŠøŠø Š±Š°Š·Ń Š“Š°Š½Š½ŃŃ.
					           |Š”ŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŃ Š¾ŃŠ¼ŠµŠ½ŠµŠ½Š°.'; 
					           |en = 'Rollback to data base configuration is detected.
					           |Synchronization canceled.'; 
					           |pl = 'Wykryto powrĆ³t do konfiguracji bazy danych.
					           | Synchronizacja zostaÅa anulowana.';
					           |es_ES = 'Vuelta a la configuraciĆ³n de la base de datos encontrada.
					           |SincronizaciĆ³n se ha cancelado.';
					           |es_CO = 'Vuelta a la configuraciĆ³n de la base de datos encontrada.
					           |SincronizaciĆ³n se ha cancelado.';
					           |tr = 'Veri tabanÄ± konfigĆ¼rasyonuna geri dĆ¶nĆ¼Å bulundu. 
					           |Senkronizasyon iptal edildi.';
					           |it = 'Rilevato rollback della configurazione del database.
					           |Sincronizzazione annullata.';
					           |de = 'ZurĆ¼ck zur Datenbankkonfiguration gefunden.
					           |Die Synchronisierung wird abgebrochen.'"));
				Return;
			EndIf;
		EndIf;
		// If the return to the database configuration is executed, but Designer is not closed.
		//  It means that the message is not imported.
		// After you switch to the repeat mode, you can clickĀ 
		// "Do not synchronize and continue", and after that return to the database configuration will be 
		// completed.
		CommitTransaction();
		EnableDataExchangeMessageImportRecurrenceBeforeStart();
		If OnClientStart Then
			Restart = True;
			Return;
		EndIf;
		Raise;
	EndTry;
	
	ExportMessageAfterInfobaseUpdate();
	
EndProcedure

Function TempFilesStorageDirectory()
	
	Return DataExchangeCached.TempFilesStorageDirectory();
	
EndFunction

Function UniqueExchangeMessageFileName(Extension = "xml") Export
	
	Result = "Message{GUID}." + Extension;
	
	Result = StrReplace(Result, "GUID", String(New UUID));
	
	Return Result;
EndFunction

Function IsSubordinateDIBNode() Export
	
	Return MasterNode() <> Undefined;
	
EndFunction

// Returns the current infobase master node if the distributed infobase is created based on the 
// exchange plan that is supported in the SSL data exchange subsystem.
//
// Returns:
//  ExchangePlanRef.<Exchange plan name>, Undefined - this method returns Undefined in the following 
//   cases: - the current infobase is not a DIB node, - the master node is not defined (this 
//   infobase is the master node), - distributed infobase is created based on an exchange plan that 
//   is not supported in the SSL data exchange subsystem.
//   
//
Function MasterNode() Export
	
	Result = ExchangePlans.MasterNode();
	
	If Result <> Undefined Then
		
		If Not DataExchangeCached.IsSSLDataExchangeNode(Result) Then
			
			Result = Undefined;
			
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

// Returns an array of version numbers supported by correspondent API for the DataExchange subsystem.
// 
// Parameters:
// ExternalConnection - a COM connection object that is used for working with the correspondent.
//
// Returns:
// Array of version numbers that are supported by correspondent API.
//
Function InterfaceVersionsThroughExternalConnection(ExternalConnection) Export
	
	Return Common.GetInterfaceVersionsViaExternalConnection(ExternalConnection, "DataExchange");
	
EndFunction

Function FirstErrorBriefPresentation(ErrorInformation)
	
	If ErrorInformation.Cause <> Undefined Then
		
		Return FirstErrorBriefPresentation(ErrorInformation.Cause);
		
	EndIf;
	
	Return BriefErrorDescription(ErrorInformation);
EndFunction

// Creates a temporary directory for exchange messages.
// Writes the directory name to the register for further deletion.
//
Function CreateTempExchangeMessageDirectory(CatalogID = Undefined) Export
	
	Result = CommonClientServer.GetFullFileName(DataExchangeCached.TempFilesStorageDirectory(), TempExchangeMessageCatalogName());
	
	CreateDirectory(Result);
	
	If Not Common.FileInfobase() Then
		
		SetPrivilegedMode(True);
		
		CatalogID = PutFileInStorage(Result);
		
	EndIf;
	
	Return Result;
EndFunction

Function DataExchangeOption(Val Correspondent) Export
	
	Result = "Synchronization";
	
	If DataExchangeCached.IsDistributedInfobaseNode(Correspondent) Then
		Return Result;
	EndIf;
	
	AttributesNames = Common.AttributeNamesByType(Correspondent, Type("EnumRef.ExchangeObjectExportModes"));
	
	AttributeValues = Common.ObjectAttributesValues(Correspondent, AttributesNames);
	
	For Each Attribute In AttributeValues Do
			
		If Attribute.Value = Enums.ExchangeObjectExportModes.ManualExport
			Or Attribute.Value = Enums.ExchangeObjectExportModes.DoNotExport Then
			
			Result = "ReceiveAndSend";
			Break;
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

Procedure ImportObjectContext(Val Context, Val Object) Export
	
	For Each Attribute In Object.Metadata().Attributes Do
		
		If Context.Property(Attribute.Name) Then
			
			Object[Attribute.Name] = Context[Attribute.Name];
			
		EndIf;
		
	EndDo;
	
	For Each TabularSection In Object.Metadata().TabularSections Do
		
		If Context.Property(TabularSection.Name) Then
			
			Object[TabularSection.Name].Load(Context[TabularSection.Name]);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function GetObjectContext(Val Object) Export
	
	Result = New Structure;
	
	For Each Attribute In Object.Metadata().Attributes Do
		
		Result.Insert(Attribute.Name, Object[Attribute.Name]);
		
	EndDo;
	
	For Each TabularSection In Object.Metadata().TabularSections Do
		
		Result.Insert(TabularSection.Name, Object[TabularSection.Name].Unload());
		
	EndDo;
	
	Return Result;
EndFunction

Procedure ExpandValueTree(Table, Tree)
	
	For Each TreeRow In Tree Do
		
		FillPropertyValues(Table.Add(), TreeRow);
		
		If TreeRow.Rows.Count() > 0 Then
			
			ExpandValueTree(Table, TreeRow.Rows);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function DifferenceDaysCount(Val Date1, Val Date2)
	
	Return Int((BegOfDay(Date2) - BegOfDay(Date1)) / 86400);
	
EndFunction

Procedure FillValueTable(Destination, Val Source) Export
	Destination.Clear();
	
	If TypeOf(Source)=Type("ValueTable") Then
		SourceColumns = Source.Columns;
	Else
		TempTable = Source.Unload(New Array);
		SourceColumns = TempTable.Columns;
	EndIf;
	
	If TypeOf(Destination)=Type("ValueTable") Then
		DestinationColumns = Destination.Columns;
		DestinationColumns.Clear();
		For Each Column In SourceColumns Do
			FillPropertyValues(DestinationColumns.Add(), Column);
		EndDo;
	EndIf;
	
	For Each Row In Source Do
		FillPropertyValues(Destination.Add(), Row);
	EndDo;
EndProcedure

Function TableIntoStrucrureArray(Val ValueTable)
	Result = New Array;
	
	ColumnNames = "";
	For Each Column In ValueTable.Columns Do
		ColumnNames = ColumnNames + "," + Column.Name;
	EndDo;
	ColumnNames = Mid(ColumnNames, 2);
	
	For Each Row In ValueTable Do
		StringStructure = New Structure(ColumnNames);
		FillPropertyValues(StringStructure, Row);
		Result.Add(StringStructure);
	EndDo;
	
	Return Result;
EndFunction

// Checking the corespondent versions for differences in the rules of the current and another program.
//
Function DifferentCorrespondentVersions(ExchangePlanName, EventLogMessageKey, VersionInCurrentApplication,
	VersionInOtherApplication, MessageText, ExternalConnectionParameters = Undefined) Export
	
	VersionInCurrentApplication = ?(ValueIsFilled(VersionInCurrentApplication), VersionInCurrentApplication, CorrespondentVersionInRules(ExchangePlanName));
	
	If ValueIsFilled(VersionInCurrentApplication) AND ValueIsFilled(VersionInOtherApplication)
		AND ExchangePlanSettingValue(ExchangePlanName, "WarnAboutExchangeRuleVersionMismatch") Then
		
		VersionInCurrentApplicationWithoutAssemblyNumber = CommonClientServer.ConfigurationVersionWithoutBuildNumber(VersionInCurrentApplication);
		VersionInOtherApplicationWithoutAssemblyNumber = CommonClientServer.ConfigurationVersionWithoutBuildNumber(VersionInOtherApplication);
		
		If VersionInCurrentApplicationWithoutAssemblyNumber <> VersionInOtherApplicationWithoutAssemblyNumber Then
			
			IsExternalConnection = (MessageText = "ExternalConnection");
			
			ExchangePlanSynonym = Metadata.ExchangePlans[ExchangePlanName].Synonym;
			
			MessageTemplate = NStr("ru = 'Š”ŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŃ Š“Š°Š½Š½ŃŃ Š¼Š¾Š¶ŠµŃ Š±ŃŃŃ Š²ŃŠæŠ¾Š»Š½ŠµŠ½Š° Š½ŠµŠŗŠ¾ŃŃŠµŠŗŃŠ½Š¾, Ń.Šŗ. Š²ŠµŃŃŠøŃ ŠæŃŠ¾Š³ŃŠ°Š¼Š¼Ń ""%1"" (%2) Š² ŠæŃŠ°Š²ŠøŠ»Š°Ń ŠŗŠ¾Š½Š²ŠµŃŃŠ°ŃŠøŠø ŃŃŠ¾Š¹ ŠæŃŠ¾Š³ŃŠ°Š¼Š¼Ń Š¾ŃŠ»ŠøŃŠ°ŠµŃŃŃ Š¾Ń Š²ŠµŃŃŠøŠø %3 Š² ŠæŃŠ°Š²ŠøŠ»Š°Ń ŠŗŠ¾Š½Š²ŠµŃŃŠ°ŃŠøŠø Š² Š“ŃŃŠ³Š¾Š¹ ŠæŃŠ¾Š³ŃŠ°Š¼Š¼Šµ. Š£Š±ŠµŠ“ŠøŃŠµŃŃ, ŃŃŠ¾ Š·Š°Š³ŃŃŠ¶ŠµŠ½Ń Š°ŠŗŃŃŠ°Š»ŃŠ½ŃŠµ ŠæŃŠ°Š²ŠøŠ»Š°, ŠæŠ¾Š“ŃŠ¾Š“ŃŃŠøŠµ Š“Š»Ń ŠøŃŠæŠ¾Š»ŃŠ·ŃŠµŠ¼ŃŃ Š²ŠµŃŃŠøŠ¹ Š¾Š±ŠµŠøŃ ŠæŃŠ¾Š³ŃŠ°Š¼Š¼.'; en = 'Data may be synced incorrectly because version of application ""%1"" (%2) is different from the version %3 specified in conversion rules of another application. Make sure that you imported the rules relevant for both applications.'; pl = 'Dane mogÄ byÄ nieprawidÅowo synchronizowane, poniewaÅ¼ wersja aplikacji ""%1"" (%2) rĆ³Å¼ni siÄ od %3 wersji okreÅlonej w reguÅach konwersji innej aplikacji. Upewnij siÄ, Å¼e zaimportowaÅeÅ reguÅy odpowiednie dla obu aplikacji.';es_ES = 'Datos pueden estar sincronizados de forma incorrecta, porque la versiĆ³n de la aplicaciĆ³n ""%1"" (%2) es diferente de la versiĆ³n %3 especificada en las reglas de conversiĆ³n de otra aplicaciĆ³n. Asegurarse de que usted haya importado las reglas relevantes para ambas aplicaciones.';es_CO = 'Datos pueden estar sincronizados de forma incorrecta, porque la versiĆ³n de la aplicaciĆ³n ""%1"" (%2) es diferente de la versiĆ³n %3 especificada en las reglas de conversiĆ³n de otra aplicaciĆ³n. Asegurarse de que usted haya importado las reglas relevantes para ambas aplicaciones.';tr = 'Veriler, ""%1"" (%2) uygulamasÄ±nÄ±n sĆ¼rĆ¼mĆ¼, baÅka bir uygulamanÄ±n dĆ¶nĆ¼ÅtĆ¼rme kurallarÄ±nda %3 belirtilen sĆ¼rĆ¼mden farklÄ± olduÄu iĆ§in yanlÄ±Å senkronize edilebilir. Her iki uygulama ile ilgili kurallarÄ± iĆ§e aktardÄ±ÄÄ±nÄ±zdan emin olun.';it = 'La sincronizzazione dei dati puĆ² essere eseguita in modo errato, perchĆ© la versione del programma ""%1"" (%2) nelle regole per la conversione di questo programma differisce dalla versione di %3 nelle regole di conversione in un altro programma.';de = 'Daten kĆ¶nnen falsch synchronisiert werden, da sich die Version der Anwendung ""%1"" (%2) von der Version%3, die in den Konvertierungsregeln einer anderen Anwendung angegebenen ist, unterscheidet. Stellen Sie sicher, dass Sie die fĆ¼r beide Anwendungen relevanten Regeln importiert haben.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, ExchangePlanSynonym, VersionInCurrentApplicationWithoutAssemblyNumber, VersionInOtherApplicationWithoutAssemblyNumber);
			
			WriteLogEvent(EventLogMessageKey, EventLogLevel.Warning,,, MessageText);
			
			If ExternalConnectionParameters <> Undefined
				AND CommonClientServer.CompareVersions("2.2.3.18", ExternalConnectionParameters.SSLVersionByExternalConnection) <= 0
				AND ExternalConnectionParameters.ExternalConnection.DataExchangeExternalConnection.WarnAboutExchangeRuleVersionMismatch(ExchangePlanName) Then
				
				ExchangePlanSynonymInOtherApplication = ExternalConnectionParameters.InfobaseNode.Metadata().Synonym;
				ExternalConnectionMessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate,
					ExchangePlanSynonymInOtherApplication, VersionInOtherApplicationWithoutAssemblyNumber, VersionInCurrentApplicationWithoutAssemblyNumber);
				
				ExternalConnectionParameters.ExternalConnection.EventLogRecord(ExternalConnectionParameters.EventLogMessageKey,
					ExternalConnectionParameters.ExternalConnection.EventLogLevel.Warning,,, ExternalConnectionMessageText);
				
			EndIf;
			
			If SessionParameters.VersionMismatchErrorOnGetData.CheckVersionDifference Then
				
				CheckStructure = New Structure(SessionParameters.VersionMismatchErrorOnGetData);
				CheckStructure.HasError = True;
				CheckStructure.ErrorText = MessageText;
				CheckStructure.CheckVersionDifference = False;
				SessionParameters.VersionMismatchErrorOnGetData = New FixedStructure(CheckStructure);
				Return True;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return False;
	
EndFunction

Function InitializeVersionDifferenceCheckParameters(CheckVersionDifference) Export
	
	SetPrivilegedMode(True);
	
	CheckStructure = New Structure(SessionParameters.VersionMismatchErrorOnGetData);
	CheckStructure.CheckVersionDifference = CheckVersionDifference;
	CheckStructure.HasError = False;
	SessionParameters.VersionMismatchErrorOnGetData = New FixedStructure(CheckStructure);
	
	Return SessionParameters.VersionMismatchErrorOnGetData;
	
EndFunction

Function VersionMismatchErrorOnGetData() Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.VersionMismatchErrorOnGetData;
	
EndFunction

Function CorrespondentVersionInRules(ExchangePlanName)
	
	Query = New Query;
	Query.Text = "SELECT
	|	DataExchangeRules.CorrespondentRulesAreRead,
	|	DataExchangeRules.RulesKind
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RulesAreImported = TRUE
	|	AND DataExchangeRules.RulesKind = VALUE(Enum.DataExchangeRulesTypes.ObjectConversionRules)";
	
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		Selection.Next();
		
		RulesStructure = Selection.CorrespondentRulesAreRead.Get().Conversion;
		CorrespondentVersion = Undefined;
		RulesStructure.Property("SourceConfigurationVersion", CorrespondentVersion);
		
		Return CorrespondentVersion;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

// Returns True if update is required for the subordinate DIB node infobase configuration.
//  Always False for the master node.
// 
// Copy of the Common.SubordinateDIBNodeConfigurationUpdateRequired function.
// 
Function UpdateInstallationRequired() Export
	
	Return IsSubordinateDIBNode() AND ConfigurationChanged();
	
EndFunction

// Returns an extended object presentation.
//
Function ObjectPresentation(ParameterObject) Export
	
	If ParameterObject = Undefined Then
		Return "";
	EndIf;
	ObjectMetadata = ?(TypeOf(ParameterObject) = Type("String"), Metadata.FindByFullName(ParameterObject), ParameterObject);
	
	// There can be no presentation attributes, iterating through structure.
	Presentation = New Structure("ExtendedObjectPresentation, ObjectPresentation");
	FillPropertyValues(Presentation, ObjectMetadata);
	If Not IsBlankString(Presentation.ExtendedObjectPresentation) Then
		Return Presentation.ExtendedObjectPresentation;
	ElsIf Not IsBlankString(Presentation.ObjectPresentation) Then
		Return Presentation.ObjectPresentation;
	EndIf;
	
	Return ObjectMetadata.Presentation();
EndFunction

// Returns an extended object list presentation.
//
Function ObjectListPresentation(ParameterObject) Export
	
	If ParameterObject = Undefined Then
		Return "";
	EndIf;
	ObjectMetadata = ?(TypeOf(ParameterObject) = Type("String"), Metadata.FindByFullName(ParameterObject), ParameterObject);
	
	// There can be no presentation attributes, iterating through structure.
	Presentation = New Structure("ExtendedListPresentation, ListPresentation");
	FillPropertyValues(Presentation, ObjectMetadata);
	If Not IsBlankString(Presentation.ExtendedListPresentation) Then
		Return Presentation.ExtendedListPresentation;
	ElsIf Not IsBlankString(Presentation.ListPresentation) Then
		Return Presentation.ListPresentation;
	EndIf;
	
	Return ObjectMetadata.Presentation();
EndFunction

// Returns the flag showing whether export is available for the specified reference on the node.
//
//  Parameters:
//      ExchangeNode - ExchangePlanRef - an exchange plan node to check whether the data export is available.
//      Ref                  - Arbitrary     - an object to be checked.
//      AdditionalProperties - Structure         - additional properties passed in the object.
//
// Returns:
//  Boolean - an enabled flag
//
Function RefExportAllowed(ExchangeNode, Ref, AdditionalProperties = Undefined) Export
	
	If Ref.IsEmpty() Then
		Return False;
	EndIf;
	
	RegistrationObject = Ref.GetObject();
	If RegistrationObject = Undefined Then
		// Object is deleted. It is always possible.
		Return True;
	EndIf;
	
	If AdditionalProperties <> Undefined Then
		AttributesStructure = New Structure("AdditionalProperties");
		FillPropertyValues(AttributesStructure, RegistrationObject);
		AdditionalObjectProperties = AttributesStructure.AdditionalProperties;
		
		If TypeOf(AdditionalObjectProperties) = Type("Structure") Then
			For Each KeyValue In AdditionalProperties Do
				AdditionalObjectProperties.Insert(KeyValue.Key, KeyValue.Value);
			EndDo;
		EndIf;
	EndIf;
	
	// Checking whether the data export is available.
	Sending = DataItemSend.Auto;
	DataExchangeEvents.OnSendDataToRecipient(RegistrationObject, Sending, , ExchangeNode);
	Return Sending = DataItemSend.Auto;
EndFunction

// Returns the flag showing whether manual export is available for the specified reference on the node.
//
//  Parameters:
//      ExchangeNode - ExchangePlanRef - an exchange plan node to check whether the data export is available.
//      Ref                  - Arbitrary     - an object to be checked.
//
// Returns:
//  Boolean - an enabled flag
//
Function RefExportFromInteractiveAdditionAllowed(ExchangeNode, Ref) Export
	
	// In the case of a call from the data composition schema, when the add-on to importing mechanism is 
	// running, the safe mode is enabled, which must be disabled when executing this function.
	SetSafeModeDisabled(True);
	
	AdditionalProperties = New Structure("InteractiveExportAddition", True);
	Return RefExportAllowed(ExchangeNode, Ref, AdditionalProperties);
	
EndFunction

// Wrappers for background procedures of changing export interactively.
//
Procedure InteractiveExportModification_GenerateUserTableDocument(Parameters, ResultAddress) Export
	
	ReportObject        = InteractiveExportModification_ObjectBySettings(Parameters.DataProcessorStructure);
	ExecutionResult = ReportObject.GenerateUserSpreadsheetDocument(Parameters.FullMetadataName, Parameters.Presentation, Parameters.SimplifiedMode);
	PutToTempStorage(ExecutionResult, ResultAddress);
	
EndProcedure

Procedure InteractiveExportModification_GenerateValueTree(Parameters, ResultAddress) Export
	
	ReportObject = InteractiveExportModification_ObjectBySettings(Parameters.DataProcessorStructure);
	Result = ReportObject.GenerateValueTree();
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

Function InteractiveExportModification_ObjectBySettings(Val Settings)
	
	ReportObject = DataProcessors.InteractiveExportModification.Create();
	
	FillPropertyValues(ReportObject, Settings, , "AllDocumentsFilterComposer");
	
	// Setting up the composer fractionally.
	Data = ReportObject.CommonFilterSettingsComposer();
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(New DataCompositionAvailableSettingsSource(Data.CompositionSchema));
	Composer.LoadSettings(Data.Settings);
	
	ReportObject.AllDocumentsFilterComposer = Composer;
	
	FilterItems = ReportObject.AllDocumentsFilterComposer.Settings.Filter.Items;
	FilterItems.Clear();
	ReportObject.AddDataCompositionFilterValues(
		FilterItems, Settings.AllDocumentsFilterComposerSettings.Filter.Items);
	
	Return ReportObject;
EndFunction

// Returns the role list of the profile of the "Data synchronization with other applications" access groups.
// 
Function DataSynchronizationAccessProfileWithOtherApplicationsRoles()
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		Return "DataSynchronizationInProgress, RemoteAccessCore, ReadObjectVersionInfo";
	Else
		Return "DataSynchronizationInProgress, RemoteAccessCore";
	EndIf;
	
EndFunction

// Gets the secure connection parameter.
//
Function SecureConnection(Path) Export
	
	Return ?(Lower(Left(Path, 4)) = "ftps", New OpenSSLSecureConnection, Undefined);
	
EndFunction

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoListSynchronizationWarnings(ToDoList)
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If Not AccessRight("View", Metadata.InformationRegisters.DataExchangeResults)
		Or ModuleToDoListServer.UserTaskDisabled("WarningsOnSynchronization") Then
		Return;
	EndIf;
	
	SSLExchangePlans = DataExchangeCached.SSLExchangePlans();
	If SSLExchangePlans.Count() > 0 Then
		DashboardTable = DataExchangeMonitorTable(SSLExchangePlans);
		
		UnresolvedIssuesCount = UnresolvedIssuesCount(
			DashboardTable.UnloadColumn("InfobaseNode"));
	Else
		UnresolvedIssuesCount = 0;
	EndIf;
	
	// This procedure is only called when To-do list subsystem is available. Therefore, the subsystem 
	// availability check is redundant.
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.CommonForms.DataSynchronization.FullName());
	
	For Each Section In Sections Do
		
		NotificationAtSynchronizationID = "WarningsOnSynchronization" + StrReplace(Section.FullName(), ".", "");
		UserTask = ToDoList.Add();
		UserTask.ID  = NotificationAtSynchronizationID;
		UserTask.HasUserTasks       = UnresolvedIssuesCount > 0;
		UserTask.Presentation  = NStr("ru = 'ŠŃŠµŠ“ŃŠæŃŠµŠ¶Š“ŠµŠ½ŠøŃ ŠæŃŠø ŃŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŠø'; en = 'Synchronization warnings'; pl = 'OstrzeÅ¼enia synchronizacji';es_ES = 'Avisos de sincronizaciĆ³n';es_CO = 'Avisos de sincronizaciĆ³n';tr = 'Senkronizasyon uyarÄ±larÄ±';it = 'Avvisi sulle sincronizzazioni';de = 'Synchronisierungswarnungen'");
		UserTask.Count     = UnresolvedIssuesCount;
		UserTask.Form          = "InformationRegister.DataExchangeResults.Form.Form";
		UserTask.Owner       = Section;
		
	EndDo;
	
EndProcedure

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoListUpdateRequired(ToDoList)
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If Not AccessRight("Administration", Metadata)
		Or ModuleToDoListServer.UserTaskDisabled("UpdateRequiredDataExchange") Then
		Return;
	EndIf;
	
	UpdateInstallationRequired = UpdateInstallationRequired();
	
	// This procedure is only called when To-do list subsystem is available. Therefore, the subsystem 
	// availability check is redundant.
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.CommonForms.DataSynchronization.FullName());
	
	For Each Section In Sections Do
		
		IDUpdateRequired = "UpdateRequiredDataExchange" + StrReplace(Section.FullName(), ".", "");
		UserTask = ToDoList.Add();
		UserTask.ID  = IDUpdateRequired;
		UserTask.HasUserTasks       = UpdateInstallationRequired;
		UserTask.Important         = True;
		UserTask.Presentation  = NStr("ru = 'ŠŠ±Š½Š¾Š²ŠøŃŃ Š²ŠµŃŃŠøŃ ŠæŃŠ¾Š³ŃŠ°Š¼Š¼Ń'; en = 'Update application version'; pl = 'Aktualizacja wersji programu';es_ES = 'Actualizar la versiĆ³n de la aplicaciĆ³n';es_CO = 'Actualizar la versiĆ³n de la aplicaciĆ³n';tr = 'Uygulama sĆ¼rĆ¼mĆ¼nĆ¼ gĆ¼ncelle';it = 'Aggiornare la versione del programma';de = 'Aktualisieren Sie die Anwendungsversion'");
		If Common.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
			ModuleSoftwareUpdate = Common.CommonModule("ConfigurationUpdate");
			FormParameters = New Structure("Exit, ConfigurationUpdateReceived", False, False);
			UserTask.Form      = ModuleSoftwareUpdate.InstallUpdatesFormName();
			UserTask.FormParameters = FormParameters;
		Else
			UserTask.Form      = "CommonForm.AdditionalDetails";
			UserTask.FormParameters = New Structure("Title,TemplateName",
				NStr("ru = 'Š£ŃŃŠ°Š½Š¾Š²ŠŗŠ° Š¾Š±Š½Š¾Š²Š»ŠµŠ½ŠøŃ'; en = 'Update setup'; pl = 'Zainstaluj aktualizacjÄ';es_ES = 'Instalar la actualizaciĆ³n';es_CO = 'Instalar la actualizaciĆ³n';tr = 'GĆ¼ncellemeyi yĆ¼kle';it = 'Aggiornamento impostazioni';de = 'Installiere Update'"), "ManualUpdateInstruction");
		EndIf;
		UserTask.Owner       = Section;
		
	EndDo;
	
EndProcedure

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoListValidateCompatibilityWithCurrentVersion(ToDoList)
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If Not AccessRight("Edit", Metadata.InformationRegisters.DataExchangeRules)
		Or ModuleToDoListServer.UserTaskDisabled("ExchangeRules") Then
		Return;
	EndIf;
	
	// If in the command interface there is no section, which the information register belongs to, the user task is not added.
	Sections = ModuleToDoListServer.SectionsForObject("InformationRegister.DataExchangeRules");
	If Sections.Count() = 0 Then 
		Return;
	EndIf;
	
	OutputUserTask = True;
	VersionChecked = CommonSettingsStorage.Load("ToDoList", "ExchangePlans");
	If VersionChecked <> Undefined Then
		ArrayVersion  = StrSplit(Metadata.Version, ".");
		CurrentVersion = ArrayVersion[0] + ArrayVersion[1] + ArrayVersion[2];
		If VersionChecked = CurrentVersion Then
			OutputUserTask = False; // Additional reports and data processors were checked on the current version.
		EndIf;
	EndIf;
	
	ExchangePlansWithRulesFromFile = ExchangePlansWithRulesFromFile();
	
	For Each Section In Sections Do
		SectionID = "CheckCompatibilityWithCurrentVersion" + StrReplace(Section.FullName(), ".", "");
		
		// Adding a to-do.
		UserTask = ToDoList.Add();
		UserTask.ID = "ExchangeRules";
		UserTask.HasUserTasks      = OutputUserTask AND ExchangePlansWithRulesFromFile > 0;
		UserTask.Presentation = NStr("ru = 'ŠŃŠ°Š²ŠøŠ»Š° Š¾Š±Š¼ŠµŠ½Š°'; en = 'Exchange rules'; pl = 'ReguÅy wymiany';es_ES = 'Reglas de intercambio';es_CO = 'Reglas de intercambio';tr = 'DeÄiÅim kurallarÄ±';it = 'Regole di scambio';de = 'Austausch-Regeln'");
		UserTask.Count    = ExchangePlansWithRulesFromFile;
		UserTask.Form         = "InformationRegister.DataExchangeRules.Form.DataSynchronizationCheck";
		UserTask.Owner      = SectionID;
		
		// Checking whether the to-do group exists. If a group is missing, add it.
		UserTaskGroup = ToDoList.Find(SectionID, "ID");
		If UserTaskGroup = Undefined Then
			UserTaskGroup = ToDoList.Add();
			UserTaskGroup.ID = SectionID;
			UserTaskGroup.HasUserTasks      = UserTask.HasUserTasks;
			UserTaskGroup.Presentation = NStr("ru = 'ŠŃŠ¾Š²ŠµŃŠøŃŃ ŃŠ¾Š²Š¼ŠµŃŃŠøŠ¼Š¾ŃŃŃ'; en = 'Check compatibility'; pl = 'Kontrola zgodnoÅci';es_ES = 'Revisar la compatibilidad';es_CO = 'Revisar la compatibilidad';tr = 'UygunluÄu kontrol et';it = 'Verificare la compatibilitĆ ';de = 'ĆberprĆ¼fen Sie die KompatibilitĆ¤t'");
			If UserTask.HasUserTasks Then
				UserTaskGroup.Count = UserTask.Count;
			EndIf;
			UserTaskGroup.Owner = Section;
		Else
			If Not UserTaskGroup.HasUserTasks Then
				UserTaskGroup.HasUserTasks = UserTask.HasUserTasks;
			EndIf;
			
			If UserTask.HasUserTasks Then
				UserTaskGroup.Count = UserTaskGroup.Count + UserTask.Count;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Function DataSynonymOfStatisticsTreeRow(TreeRow, SourceTypeString) 
	
	Synonym = TreeRow.Synonym;
	
	Filter = New Structure("FullName, Synonym", TreeRow.FullName, Synonym);
	Existing = TreeRow.Owner().Rows.FindRows(Filter, True);
	Count   = Existing.Count();
	If Count = 0 Or (Count = 1 AND Existing[0] = TreeRow) Then
		// There has been no such descirption in this tree.
		Return Synonym;
	EndIf;
	
	Synonym = "[DestinationTableSynonym] ([SourceTableName])"; // Do not localize.
	Synonym = StrReplace(Synonym, "[DestinationTableSynonym]", TreeRow.Synonym);
	
	Return StrReplace(Synonym, "[SourceTableName]", DeleteClassNameFromObjectName(SourceTypeString));
EndFunction

Function GetDocumentHasRegisterRecords(DocumentRef)
	QueryText = "";	
	// To exclude failure of documents to post by more than 256 tables.
	table_counter = 0;
	
	DocumentMetadata = DocumentRef.Metadata();
	
	If DocumentMetadata.RegisterRecords.Count() = 0 Then
		Return New ValueTable;
	EndIf;
	
	For Each RegisterRecord In DocumentMetadata.RegisterRecords Do
		// Receiving the names of the registers, for which there is at least one record, in the request.
		// Example:
		// SELECT First 1 "AccumulationRegister.ProductsStock"
		// FROM AccumulationRegisterProductsStock
		// WHERE Recorder = &Recorder.
		
		// Adjust register name to String(200), see below.
		QueryText = QueryText + "
		|" + ?(QueryText = "", "", "UNION ALL ") + "
		|SELECT TOP 1 CAST(""" + RegisterRecord.FullName() 
		+  """ AS String(200)) AS Name FROM " + RegisterRecord.FullName() 
		+ " WHERE Recorder = &Recorder";
		
		// If the request includes more than 256 tables, split it into twoĀ parts (exclude posting by 512 
		// registers).
		table_counter = table_counter + 1;
		If table_counter = 256 Then
			Break;
		EndIf;
		
	EndDo;
	
	Query = New Query(QueryText);
	Query.SetParameter("Recorder", DocumentRef);
	// On export, for the Name column set type by the longest string from the query. On the second pass 
	// of the table the new name might not fit so adjust it to string(200).
	// 
	QueryTable = Query.Execute().Unload();
	
	// If the tables number is not more than 256, return the table.
	If table_counter = DocumentMetadata.RegisterRecords.Count() Then
		Return QueryTable;			
	EndIf;
	
	// If the tables number is more than 256, make an additional request and supplement the table with rows.
	
	QueryText = "";
	For Each RegisterRecord In DocumentMetadata.RegisterRecords Do
		
		If table_counter > 0 Then
			table_counter = table_counter - 1;
			Continue;
		EndIf;
		
		QueryText = QueryText + "
		|" + ?(QueryText = "", "", "UNION ALL ") + "
		|SELECT TOP 1 """ + RegisterRecord.FullName() +  """ AS Name FROM " 
		+ RegisterRecord.FullName() + " WHERE Recorder = &Recorder";	
		
		
	EndDo;
	Query.Text = QueryText;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		TableRow = QueryTable.Add();
		FillPropertyValues(TableRow, Selection);
	EndDo;
	
	Return QueryTable;
	
EndFunction

// Determines default settings for the exchange plan. Later, they can be changed in the exchange 
// plan manager module in the OnReceiveSettings() procedure.
// 
// Returns:
//   Structure - contains the following fields:
//      * ExchangeSettingsOptions                         - ValueTable - possible exchange plan settings.
//                                                                  Is used for creating preset 
//                                                                  templates with filled exchange plan settings
//      * GroupTypeForSettingsOptions - FormGroupType - a group type option for displaying in the 
//                                                                  tree of creation commands for settings option exchange.
//      * SourceConfigurationName                       - String - a source configuration name 
//                                                                  displayed to user.
//      * TargetConfigurationName - Structure - a list of IDs of correspondent configurations 
//                                                                  exchange with which is possible via this exchange plan.
//      * ExchangeFormatOptions - Map - a map of supportedĀ format versions and references to common 
//                                                                  modules with exchange implemented using format.
//                                                                  It is used for exchange via the universal format only.
//      * ExchangeFormat                                   - String - the XDTO namespace  of a 
//                                                                  package, which contains the universal formatĀ without format version specified.
//                                                                  It is used for exchange via the universal format only.
//      * ExchangePlanUsedInSaaS           - Boolean - a flag showing whether the exchange plan is 
//                                                                  used to organize exchange in SaaS.
//      * IsXDTOExchangePlan - Boolean - a flag showing whether this is a plan of exchange via the 
//                                                                  universal format.
//      * WarnAboutExchangeRuleVersionMismatch - Boolean - a flag showing whether it is required to 
//                                                                  check version difference in the conversion rules.
//                                                                  The checking is performed on 
//                                                                  rule set importing , on data sending, and on data receiving.
//      * ExchangePlanNameToMigrateToNewExchange          - String - if for an exchange plan the 
//                                                                  property is set, this kind of 
//                                                                  exchange is not available in the settings management workplaces.
//                                                                  Existing exchanges of this type 
//                                                                  will be still visible in the configured exchange list.
//                                                                  Getting an exchange messageĀ in a 
//                                                                  new formatĀ will initiate migration to a new exchange kind.
//      * ExchangePlanPurpose                          - String - an exchange plan assignment option.
//      * Algorithms                                      - Structure - a list of export procedures 
//                                                                  and functions declared in the 
//                                                                  exchange plan manager module and used by the data exchange subsystem.
//
Function DefaultExchangePlanSettings(ExchangePlanName)
	
	ExchangePlanPurpose = "SynchronizationWithAnotherApplication";
	If DataExchangeCached.IsDistributedInfobaseExchangePlan(ExchangePlanName) Then
		ExchangePlanPurpose = "DIB";
	EndIf;
	
	ExchangeSettingsOptions = New ValueTable;
	ExchangeSettingsOptions.Columns.Add("SettingID",        New TypeDescription("String"));
	ExchangeSettingsOptions.Columns.Add("CorrespondentInSaaS",   New TypeDescription("Boolean"));
	ExchangeSettingsOptions.Columns.Add("CorrespondentInLocalMode", New TypeDescription("Boolean"));
	
	Algorithms = New Structure;
	Algorithms.Insert("OnGetExchangeSettingsOptions",          False);
	Algorithms.Insert("OnGetSettingOptionDetails",        False);
	
	Algorithms.Insert("DataTransferRestrictionsDetails",            False);
	Algorithms.Insert("DefaultValueDetails",                  False);
	
	Algorithms.Insert("InteractiveExportFilterPresentation",     False);
	Algorithms.Insert("SetUpInteractiveExport",               False);
	Algorithms.Insert("SetUpInteractiveExportSaaS", False);
	
	Algorithms.Insert("DataTransferLimitsCheckHandler",  False);
	Algorithms.Insert("DefaultValuesCheckHandler",        False);
	Algorithms.Insert("AccountingSettingsCheckHandler",            False);
	
	Algorithms.Insert("OnConnectToCorrespondent",                False);
	Algorithms.Insert("OnGetSenderData",                False);
	Algorithms.Insert("OnSendSenderData",                 False);
	
	Algorithms.Insert("OnSaveDataSynchronizationSettings",     False);
	
	Algorithms.Insert("OnDefineSupportedFormatObjects",  False);
	Algorithms.Insert("OnDefineFormatObjectsSupportedByCorrespondent", False);
	
	Parameters = New Structure;
	Parameters.Insert("ExchangeSettingsOptions",                         ExchangeSettingsOptions);
	Parameters.Insert("SourceConfigurationName",                       "");
	Parameters.Insert("DestinationConfigurationName",                       New Structure);
	Parameters.Insert("ExchangeFormatVersions",                            New Map);
	Parameters.Insert("ExchangeFormat",                                   "");
	Parameters.Insert("ExchangePlanUsedInSaaS",           False);
	Parameters.Insert("IsXDTOExchangePlan",                              False);
	Parameters.Insert("ExchangePlanNameToMigrateToNewExchange",          "");
	Parameters.Insert("WarnAboutExchangeRuleVersionMismatch", True);
	Parameters.Insert("ExchangePlanPurpose",                          ExchangePlanPurpose);
	Parameters.Insert("Algorithms",                                      Algorithms);
	
	Return Parameters;
	
EndFunction

// Gets the configuration metadata tree with the specified filter by metadata objects.
//
// Parameters:
//   Filter - Structure - contains filter item values.
//						If this parameter is specified, the metadata tree will be retrieved according to the filter value:
//						Key - String - a metadata item property name;
//						Value - Array - an array of filter values.
//
// Example of initializing the Filter variable:
//
// Array = New Array;
// Array.Add("Constant.UseDataSynchronization");
// Array.Add("Catalog.Currencies");
// Array.Add("Catalog.Companies");
// Filter = New Structure;
// Filter.Insert("FullName", Array);
// 
// Returns:
//   ValuesTree - a configuration metadata tree.
//
Function ConfigurationMetadataTree(Filter = Undefined) Export
	
	UseFilter = (Filter <> Undefined);
	
	MetadataObjectsCollections = New ValueTable;
	MetadataObjectsCollections.Columns.Add("Name");
	MetadataObjectsCollections.Columns.Add("Synonym");
	MetadataObjectsCollections.Columns.Add("Picture");
	MetadataObjectsCollections.Columns.Add("ObjectPicture");
	
	NewMetadataObjectCollectionRow("Constants",               NStr("ru = 'ŠŠ¾Š½ŃŃŠ°Š½ŃŃ'; en = 'Constants'; pl = 'StaÅe';es_ES = 'Constantes';es_CO = 'Constantes';tr = 'Sabitler';it = 'Costanti';de = 'Konstanten'"),                 PictureLib.Constant,              PictureLib.Constant,                    MetadataObjectsCollections);
	NewMetadataObjectCollectionRow("Catalogs",             NStr("ru = 'Š”ŠæŃŠ°Š²Š¾ŃŠ½ŠøŠŗŠø'; en = 'Catalogs'; pl = 'Katalogi';es_ES = 'CatĆ”logos';es_CO = 'CatĆ”logos';tr = 'Ana kayÄ±tlar';it = 'Anagrafiche';de = 'Kataloge'"),               PictureLib.Catalog,             PictureLib.Catalog,                   MetadataObjectsCollections);
	NewMetadataObjectCollectionRow("Documents",               NStr("ru = 'ŠŠ¾ŠŗŃŠ¼ŠµŠ½ŃŃ'; en = 'Documents'; pl = 'Dokumenty';es_ES = 'Documentos';es_CO = 'Documentos';tr = 'Belgeler';it = 'Documenti';de = 'Dokumente'"),                 PictureLib.Document,               PictureLib.DocumentObject,               MetadataObjectsCollections);
	NewMetadataObjectCollectionRow("ChartsOfCharacteristicTypes", NStr("ru = 'ŠŠ»Š°Š½Ń Š²ŠøŠ“Š¾Š² ŃŠ°ŃŠ°ŠŗŃŠµŃŠøŃŃŠøŠŗ'; en = 'Charts of characteristic types'; pl = 'Plany rodzajĆ³w charakterystyk';es_ES = 'Diagramas de los tipos de caracterĆ­sticas';es_CO = 'Diagramas de los tipos de caracterĆ­sticas';tr = 'Ćzellik tĆ¼rĆ¼ listeleri';it = 'Grafici di tipi caratteristiche';de = 'Diagramme von charakteristischen Typen'"), PictureLib.ChartOfCharacteristicTypes, PictureLib.ChartOfCharacteristicTypesObject, MetadataObjectsCollections);
	NewMetadataObjectCollectionRow("ChartsOfAccounts",             NStr("ru = 'ŠŠ»Š°Š½Ń ŃŃŠµŃŠ¾Š²'; en = 'Charts of accounts'; pl = 'Plany kont';es_ES = 'Diagramas de las cuentas';es_CO = 'Diagramas de las cuentas';tr = 'Hesap planlarÄ±';it = 'Piani dei conti';de = 'KontenplĆ¤ne'"),              PictureLib.ChartOfAccounts,             PictureLib.ChartOfAccountsObject,             MetadataObjectsCollections);
	NewMetadataObjectCollectionRow("ChartsOfCalculationTypes",       NStr("ru = 'ŠŠ»Š°Š½Ń Š²ŠøŠ“Š¾Š² ŃŠ°ŃŃŠµŃŠ°'; en = 'Charts of calculation types'; pl = 'Plany typĆ³w obliczeÅ';es_ES = 'Diagramas de los tipos de cĆ”lculos';es_CO = 'Diagramas de los tipos de cĆ”lculos';tr = 'Hesaplama tĆ¼rleri Ć§izelgeleri';it = 'Grafici di tipi di calcolo';de = 'Diagramme der Berechnungstypen'"),       PictureLib.ChartOfCalculationTypes,       PictureLib.ChartOfCalculationTypesObject,       MetadataObjectsCollections);
	NewMetadataObjectCollectionRow("InformationRegisters",        NStr("ru = 'Š ŠµŠ³ŠøŃŃŃŃ ŃŠ²ŠµŠ“ŠµŠ½ŠøŠ¹'; en = 'Information registers'; pl = 'Rejestry informacji';es_ES = 'Registros de informaciĆ³n';es_CO = 'Registros de informaciĆ³n';tr = 'Bilgi kayÄ±tlarÄ±';it = 'Registri informazioni';de = 'Informationen registriert'"),         PictureLib.InformationRegister,        PictureLib.InformationRegister,              MetadataObjectsCollections);
	NewMetadataObjectCollectionRow("AccumulationRegisters",      NStr("ru = 'Š ŠµŠ³ŠøŃŃŃŃ Š½Š°ŠŗŠ¾ŠæŠ»ŠµŠ½ŠøŃ'; en = 'Accumulation registers'; pl = 'Rejestry akumulacji';es_ES = 'Registros de acumulaciĆ³n';es_CO = 'Registros de acumulaciĆ³n';tr = 'Birikim kayÄ±tlarÄ±';it = 'Registri di accumulo';de = 'Akkumulationsregister'"),       PictureLib.AccumulationRegister,      PictureLib.AccumulationRegister,            MetadataObjectsCollections);
	NewMetadataObjectCollectionRow("AccountingRegisters",     NStr("ru = 'Š ŠµŠ³ŠøŃŃŃŃ Š±ŃŃŠ³Š°Š»ŃŠµŃŠøŠø'; en = 'Accounting registers'; pl = 'Rejestry ksiÄgowe';es_ES = 'Registros de contabilidad';es_CO = 'Registros de contabilidad';tr = 'Muhasebe kayÄ±tlarÄ±';it = 'Registri contabili';de = 'Buchhaltungsregister'"),      PictureLib.AccountingRegister,     PictureLib.AccountingRegister,           MetadataObjectsCollections);
	NewMetadataObjectCollectionRow("CalculationRegisters",         NStr("ru = 'Š ŠµŠ³ŠøŃŃŃŃ ŃŠ°ŃŃŠµŃŠ°'; en = 'Calculation registers'; pl = 'Rejestry obliczeÅ';es_ES = 'Registros de cĆ”lculos';es_CO = 'Registros de cĆ”lculos';tr = 'Hesaplama kayÄ±tlarÄ±';it = 'Registri di calcolo';de = 'Berechnungsregister'"),          PictureLib.CalculationRegister,         PictureLib.CalculationRegister,               MetadataObjectsCollections);
	NewMetadataObjectCollectionRow("BusinessProcesses",          NStr("ru = 'ŠŠøŠ·Š½ŠµŃ-ŠæŃŠ¾ŃŠµŃŃŃ'; en = 'Business processes'; pl = 'Procesy biznesowe';es_ES = 'Procesos de negocio';es_CO = 'Procesos de negocio';tr = 'Ä°Å sĆ¼reĆ§leri';it = 'Processi di business';de = 'GeschĆ¤ftsprozesse'"),           PictureLib.BusinessProcess,          PictureLib.BusinessProcessObject,          MetadataObjectsCollections);
	NewMetadataObjectCollectionRow("Tasks",                  NStr("ru = 'ŠŠ°Š“Š°Ń'; en = 'Tasks'; pl = 'Zadania';es_ES = 'Tareas';es_CO = 'Tareas';tr = 'GĆ¶revler';it = 'Compiti';de = 'Aufgaben'"),                    PictureLib.Task,                 PictureLib.TaskObject,                 MetadataObjectsCollections);
	
	// Function return value.
	MetadataTree = New ValueTree;
	MetadataTree.Columns.Add("Name");
	MetadataTree.Columns.Add("FullName");
	MetadataTree.Columns.Add("Synonym");
	MetadataTree.Columns.Add("Picture");
	
	For Each CollectionRow In MetadataObjectsCollections Do
		
		TreeRow = MetadataTree.Rows.Add();
		FillPropertyValues(TreeRow, CollectionRow);
		For Each MetadataObject In Metadata[CollectionRow.Name] Do
			
			If UseFilter Then
				
				ObjectPassedFilter = True;
				For Each FilterItem In Filter Do
					
					Value = ?(Upper(FilterItem.Key) = Upper("FullName"), MetadataObject.FullName(), MetadataObject[FilterItem.Key]);
					If FilterItem.Value.Find(Value) = Undefined Then
						ObjectPassedFilter = False;
						Break;
					EndIf;
					
				EndDo;
				
				If Not ObjectPassedFilter Then
					Continue;
				EndIf;
				
			EndIf;
			
			MOTreeRow = TreeRow.Rows.Add();
			MOTreeRow.Name       = MetadataObject.Name;
			MOTreeRow.FullName = MetadataObject.FullName();
			MOTreeRow.Synonym   = MetadataObject.Synonym;
			MOTreeRow.Picture  = CollectionRow.ObjectPicture;
			
		EndDo;
		
	EndDo;
	
	// Deleting rows that have no subordinate items.
	If UseFilter Then
		
		// Using reverse value tree iteration order.
		CollectionItemCount = MetadataTree.Rows.Count();
		
		For ReverseIndex = 1 To CollectionItemCount Do
			
			CurrentIndex = CollectionItemCount - ReverseIndex;
			TreeRow = MetadataTree.Rows[CurrentIndex];
			If TreeRow.Rows.Count() = 0 Then
				MetadataTree.Rows.Delete(CurrentIndex);
			EndIf;
			
		EndDo;
	
	EndIf;
	
	Return MetadataTree;
	
EndFunction

Procedure NewMetadataObjectCollectionRow(Name, Synonym, Picture, ObjectPicture, Tab)
	
	NewRow = Tab.Add();
	NewRow.Name               = Name;
	NewRow.Synonym           = Synonym;
	NewRow.Picture          = Picture;
	NewRow.ObjectPicture   = ObjectPicture;
	
EndProcedure

// Determines default settings for the exchange setting option that can later be overridden in the 
// exchange plan manager module in the OnReceiveSettingOptionsDetails() procedure.
// Parameters:
//   ExchangePlanName - String - contains an exchange plan name.
// 
// Returns:
//   Structure - contains the following fields:
//      * Filters                                                - Structure - filters on the 
//                                                                         exchange plan node to be filled with default values.
//      * DefaultValues                                   - Structure - default values on the exchange plan node.
//      * CorrespondentFilters                                  - Structure - filters on the 
//                                                                          exchange plan node to be filled with default values for the correspondent base.
//      * DefaultValues                                   - Structure - default values on the exchange plan node.
//      * CorrespondentDefaultValues                     - Structure - default values on the node for the correspondent base.
//      * CommonNodesData                                      - String - Returns comma-separated 
//                                                                         names of attributes and 
//                                                                         exchange plan tabular sections that are common for both data exchange participants.
//      * FilterFormName                                       - String - A name of node filter setup form to use.
//      * DefaultValueFormName                           - String - A default name of filter setup 
//                                                                         form to use.
//      * CorrespondentFilterFormName                         - String - A name of filter setup form 
//                                                                         of correspondent Infobase node  to use.
//      * DefaultValueFormNameCorrespondent             - String - a name of default values form to 
//                                                                         use on infobase correspondent node.
//      * FormNameCommonNodeData                              - String - a name of node configuration form to use.
//      * SettingsFileNameForDestination                          - String - a default file name for 
//                                                                         saving synchronization settings.
//      * UseDataExchangeCreationWizard             - Boolean - a flag showing whether the wizard 
//                                                                         will be used to create new exchange plan nodes.
//      * InitialImageCreatingFormName                      - String - a name ofĀ initial image 
//                                                                         creation form to use in distributed infobase.
//      * AdditionalDataForCorrespondentInfobase                 - Structure - additional data to be 
//                                                                         used for data exchange 
//                                                                         setup at the correspondent infobase. Can be used in handler
//                                                                        OnCreateAtServer in the 
//                                                                        setupĀ form of the CorrespondentInfobaseDefaultValueSetupForm exchange plan node
//      * HintsForSettingUpAccountingParameters                  - String - Hints on sequence of 
//                                                                         user actions to setup 
//                                                                         accounting parameters in the current infobase.
//      * HintsToSetupAccountingCorrespondentParameters    - String - Hints on sequence of user 
//                                                                         actions to setup accounting parameters in the correspondent infobase.
//      * RuleSetFilePathOnUserSite      - String - the path to the archive of the rule set file on 
//                                                                         the user site, in the configuration section.
//      * RuleSetFilePathInTemplateDirectory            - String - Ā a relative path to the rule set 
//                                                                         file in the 1C:Enterprise template directory.
//      * NewDataExchangeCreationCommandTitle        - String - command presentation displayed to 
//                                                                         user on creating a new 
//                                                                         data exchange setting.
//      * ExchangeCreateWizardTitle                      - String - presentation of data exchange 
//                                                                         creation wizard title 
//                                                                         displayed to user.
//      * CorrespondentConfigurationDescription                - String - presentation of the 
//                                                                         correspondent configuration name displayed to user.
//      * ExchangePlanNodeTitle                              - String - the exchange plan node 
//                                                                         presentation displayed to user.
//      * DisplayFiltersSettingOnNode                      - Boolean - a flag showing whether node 
//                                                                         filter settings are shown in the exchange creation wizard.
//      * DisplayDefaultValuesOnNode                   - Boolean - a flag showing whether default 
//                                                                         values are shown in the exchange creation wizard.
//      * DisplayFiltersSettingOnCorrespondentInfobaseNode    - Boolean - a flag showing whether 
//                                                                         filter settings of the correspondent infobase node are shown in the exchange creation wizard.
//      * DisplayDefaultValuesOnCorrespondentBaseNode - Boolean - shows whether default values of 
//                                                                         the correspondent base are shown in the exchange creation wizard
//      * UsedExchangeMessageTransports                 - Array - a list of used message transports.
//                                                                         If it is not filled in, 
//                                                                         all possible transport kinds will be available.
//      * ExchangeBriefInfo                             - String - Data exchange brief info 
//                                                                         displayed on the first 
//                                                                         page of the exchange creation wizard.
//      * DetailedExchangeInformation                           - String - a web page URL or a full 
//                                                                         path to the form within 
//                                                                         the configuration as a string to display in the exchange creation wizard.
//
Function ExchangeSettingOptionDetailsByDefault(ExchangePlanName)
	
	OptionDetails = New Structure;
	
	ExchangePlanMetadata = Metadata.ExchangePlans[ExchangePlanName];
	WizardFormTitle = NStr("ru = 'Š”ŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŃ Š“Š°Š½Š½ŃŃ Ń %1 (Š½Š°ŃŃŃŠ¾Š¹ŠŗŠ°)'; en = 'Data synchronization with %1 (setup)'; pl = 'Synchronizacja danych z %1 (ustawienie)';es_ES = 'SincronizaciĆ³n de datos con %1 (setup)';es_CO = 'SincronizaciĆ³n de datos con %1 (setup)';tr = '%1 ile veri senkronizasyonu (setup)';it = 'Sincronizzazione dati con %1 (configurazione)';de = 'Datensynchronisation mit %1 (Setup)'");
	WizardFormTitle = StringFunctionsClientServer.SubstituteParametersToString(WizardFormTitle, ExchangePlanMetadata.Synonym);
	
	OptionDetails.Insert("SettingsFileNameForDestination",                          "");
	OptionDetails.Insert("UseDataExchangeCreationWizard",             True);
	OptionDetails.Insert("DataMappingSupported",                     True);
	
	OptionDetails.Insert("DataSyncSettingsWizardFormName",         "");
	OptionDetails.Insert("InitialImageCreationFormName",                      "");
	
	OptionDetails.Insert("PathToRulesSetFileOnUserSite",      "");
	OptionDetails.Insert("PathToRulesSetFileInTemplateDirectory",            "");
	OptionDetails.Insert("NewDataExchangeCreationCommandTitle",        ExchangePlanMetadata.Synonym);
	OptionDetails.Insert("CorrespondentConfigurationName",                         "");
	OptionDetails.Insert("CorrespondentConfigurationDescription",                "");
	OptionDetails.Insert("UsedExchangeMessagesTransports",                 New Array);
	OptionDetails.Insert("ExchangeBriefInfo",                             "");
	OptionDetails.Insert("ExchangeDetailedInformation",                           "");
	OptionDetails.Insert("CommonNodeData",                                      "");
	
	OptionDetails.Insert("ExchangeCreateWizardTitle",                      WizardFormTitle);
	OptionDetails.Insert("ExchangePlanNodeTitle",                              ExchangePlanMetadata.Synonym);
	
	OptionDetails.Insert("AccountingSettingsSetupNote",                  "");
	
	OptionDetails.Insert("Filters",                                                New Structure);
	OptionDetails.Insert("DefaultValues",                                   New Structure);

	Return OptionDetails;
	
EndFunction

Function CodeOfPredefinedExchangePlanNode(ExchangePlanName) Export
	
	SetPrivilegedMode(True);
	
	ThisNode = DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName);
	
	Return TrimAll(Common.ObjectAttributeValue(ThisNode, "Code"));
	
EndFunction

// Returns an array of all nodes of the specified exchange plan but the predefined node.
//
// Parameters:
//  ExchangePlanName - String - an exchange plan name as it is specified in Designer.
// 
// Returns:
//  NodesArray - Array - an array of all nodes of the specified exchange plan but the predefined node.
//
Function ExchangePlanNodes(ExchangePlanName) Export
	
	Query = New Query(
	"SELECT
	|	ExchangePlan.Ref AS Ref
	|FROM
	|	#ExchangePlanTableName AS ExchangePlan
	|WHERE
	|	NOT ExchangePlan.ThisNode");
	
	Query.Text = StrReplace(Query.Text, "#ExchangePlanTableName", "ExchangePlan." + ExchangePlanName);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

#EndRegion

#Region ExchangeMessageFromMainNodeConstantOperations

// Reads infobase information on a data exchange message.
//
// Return value - Structure - information about the location of the exchange message file (current format).
//                       - BinaryData - an exchange messageĀ in the infobase (obsolete format).
//
Function DataExchangeMessageFromMasterNode()
	
	Return Constants.DataExchangeMessageFromMasterNode.Get().Get();
	
EndFunction

// Writes an exchange message file from the master node to the hard drive.
// Saves the path to the written message to the DataExchangeMessageFromMasterNode constant.
//
// Parameters:
//	ExchangeMessage - BinaryData - read exchange message.
//	MasterNode - ExchangePlanRef - a node used to receive the message.
//
Procedure SetDataExchangeMessageFromMasterNode(ExchangeMessage, MasterNode) Export
	
	PathToFile = "[Directory][Path].xml";
	PathToFile = StrReplace(PathToFile, "[Directory]", TempFilesStorageDirectory());
	PathToFile = StrReplace(PathToFile, "[Path]", New UUID);
	
	ExchangeMessage.Write(PathToFile);
	
	MessageStructure = New Structure;
	MessageStructure.Insert("PathToFile", PathToFile);
	
	Constants.DataExchangeMessageFromMasterNode.Set(New ValueStorage(MessageStructure));
	
	WriteDataReceiveEvent(MasterNode, NStr("ru = 'Š”Š¾Š¾Š±ŃŠµŠ½ŠøŠµ Š¾Š±Š¼ŠµŠ½Š° Š·Š°ŠæŠøŃŠ°Š½Š¾ Š² ŠŗŃŃ.'; en = 'Exchange message is cached.'; pl = 'WiadomoÅÄ wymiany zostaÅa zapisana w pamiÄci podrÄcznej.';es_ES = 'El mensaje de intercambio se ha grabado en el cachĆ©.';es_CO = 'El mensaje de intercambio se ha grabado en el cachĆ©.';tr = 'DeÄiÅim mesajÄ± Ć¶nbelleÄe yazÄ±ldÄ±.';it = 'Messaggio di scambio memorizzato nella cache.';de = 'Die Austauschnachricht wurde in den Cache geschrieben.'"));
	
EndProcedure

// Deletes the exchange message file from the hard drive and clears the DataExchangeMessageFromMasterNode constant.
//
Procedure ClearDataExchangeMessageFromMasterNode() Export
	
	ExchangeMessage = DataExchangeMessageFromMasterNode();
	
	If TypeOf(ExchangeMessage) = Type("Structure") Then
		
		DeleteFiles(ExchangeMessage.PathToFile);
		
	EndIf;
	
	Constants.DataExchangeMessageFromMasterNode.Set(New ValueStorage(Undefined));
	
	WriteDataReceiveEvent(MasterNode(), NStr("ru = 'Š”Š¾Š¾Š±ŃŠµŠ½ŠøŠµ Š¾Š±Š¼ŠµŠ½Š° ŃŠ“Š°Š»ŠµŠ½Š¾ ŠøŠ· ŠŗŃŃŠ°.'; en = 'The exchange message was deleted from cache.'; pl = 'WiadomoÅÄ wymiany zostaÅa usuniÄta z pamiÄci podrÄcznej.';es_ES = 'El mensaje de intercambio se ha borrado del cachĆ©.';es_CO = 'El mensaje de intercambio se ha borrado del cachĆ©.';tr = 'DeÄiÅim mesajÄ± Ć¶nbellekten silindi.';it = 'Il messaggio di scambio ĆØ stato rimosso dalla cache.';de = 'Die Austauschnachricht wurde aus dem Cache gelĆ¶scht.'"));
	
EndProcedure

#EndRegion

#Region SecurityProfiles

Procedure CreateRequestsToUseExternalResources(PermissionRequests)
	
	If Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	Constants.DataExchangeMessageDirectoryForLinux.CreateValueManager().OnFillPermissionsToAccessExternalResources(PermissionRequests);
	Constants.DataExchangeMessageDirectoryForWindows.CreateValueManager().OnFillPermissionsToAccessExternalResources(PermissionRequests);
	
	InformationRegisters.DataExchangeTransportSettings.OnFillPermissionsToAccessExternalResources(PermissionRequests);
	InformationRegisters.DataExchangeRules.OnFillPermissionsToAccessExternalResources(PermissionRequests);
	
EndProcedure

Procedure ExternalResourcesDataExchangeMessageDirectoryQuery(PermissionRequests, Object) Export
	
	ConstantValue = Object.Value;
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	If Not IsBlankString(ConstantValue) Then
		
		Permissions = New Array();
		Permissions.Add(ModuleSafeModeManager.PermissionToUseFileSystemDirectory(
			ConstantValue, True, True));
		
		PermissionRequests.Add(
			ModuleSafeModeManager.RequestToUseExternalResources(Permissions,
				Common.MetadataObjectID(Object.Metadata())));
		
	EndIf;
	
EndProcedure

// Returns the template of a security profile name for external module.
// The function should return the same value every time it is called.
//
// Parameters:
//  ExternalModule - AnyRef, a reference to an external module.
//
// Return value - String - template of a security profile name containing characters
//  "%1". These characters are replaced with a unique ID later.
//
Function SecurityProfileNamePattern(Val ExternalModule) Export
	
	Template = "Exchange_[ExchangePlanName]_%1"; // Do not localize.
	Return StrReplace(Template, "[ExchangePlanName]", ExternalModule.Name);
	
EndFunction

// Returns an external module icon.
//
//  ExternalModule - AnyRef, a reference to an external module.
//
// Return value - an icon.
//
Function ExternalModuleIcon(Val ExternalModule) Export
	
	Return PictureLib.DataSynchronization;
	
EndFunction

Function ExternalModuleContainerDictionary() Export
	
	Result = New Structure();
	
	Result.Insert("NominativeCase", NStr("ru = 'ŠŠ°ŃŃŃŠ¾Š¹ŠŗŠ° ŃŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŃ Š“Š°Š½Š½ŃŃ'; en = 'Data synchronization settings.'; pl = 'Ustawienia synchronizacji danych.';es_ES = 'Configurar la sincronizaciĆ³n de datos';es_CO = 'Configurar la sincronizaciĆ³n de datos';tr = 'Veri senkronizasyonunu yapÄ±landÄ±r';it = 'Impostazioni di sincronizzazione dei dati';de = 'Konfigurieren Sie die Datensynchronisierung'"));
	Result.Insert("Genitive", NStr("ru = 'ŠŠ°ŃŃŃŠ¾Š¹ŠŗŠø ŃŠøŠ½ŃŃŠ¾Š½ŠøŠ·Š°ŃŠøŠø Š“Š°Š½Š½ŃŃ'; en = 'Data synchronization settings'; pl = 'Ustawienia synchronizacji danych';es_ES = 'Configuraciones de la sincronizaciĆ³n de datos';es_CO = 'Configuraciones de la sincronizaciĆ³n de datos';tr = 'Veri senkronizasyonu ayarlarÄ±';it = 'Impostazioni di sincronizzazione dei dati';de = 'Datensynchronisierungseinstellungen'"));
	
	Return Result;
	
EndFunction

Function ExternalModuleContainers() Export
	
	Result = New Array();
	DataExchangeOverridable.GetExchangePlans(Result);
	Return Result;
	
EndFunction

#EndRegion

#Region InteractiveExportModification

// Initializes export addition for the step-by-step exchange wizard.
//
// Parameters:
//     InfobaseNode - ExchangePlanRef - a reference to the node to be configured.
//     FromStorageAddress    - String, UUID - an address for saving data between server calls.
//     HasNodeScenario       - Boolean - a flag showing whetherĀ additional setup is required.
//
// Returns:
//     Structure - data for further export additionĀ operations.
//
Function InteractiveExportModification(Val InfobaseNode, Val FromStorageAddress, Val HasNodeScenario=Undefined) Export
	
	SetPrivilegedMode(True);
	
	Result = New Structure;
	Result.Insert("InfobaseNode", InfobaseNode);
	Result.Insert("ExportOption", 0);
	
	Result.Insert("AllDocumentsFilterPeriod", New StandardPeriod);
	Result.AllDocumentsFilterPeriod.Variant = StandardPeriodVariant.LastMonth;
	
	AdditionDataProcessor = DataProcessors.InteractiveExportModification.Create();
	AdditionDataProcessor.InfobaseNode = InfobaseNode;
	AdditionDataProcessor.ExportOption        = 0;
	
	// Specifying composer options.
	Data = AdditionDataProcessor.CommonFilterSettingsComposer(FromStorageAddress);
	Result.Insert("AllDocumentsComposerAddress", PutToTempStorage(Data, FromStorageAddress));
	
	Result.Insert("AdditionalRegistration", New ValueTable);
	Columns = Result.AdditionalRegistration.Columns;
	
	StringType = New TypeDescription("String");
	Columns.Add("FullMetadataName", StringType);
	Columns.Add("Filter",         New TypeDescription("DataCompositionFilter"));
	Columns.Add("Period",        New TypeDescription("StandardPeriod"));
	Columns.Add("SelectPeriod",  New TypeDescription("Boolean"));
	Columns.Add("Presentation", StringType);
	Columns.Add("FilterString",  StringType);
	Columns.Add("Count",    StringType);

	Result.Insert("AdditionScenarioParameters", New Structure);
	AdditionScenarioParameters = Result.AdditionScenarioParameters;
	
	AdditionScenarioParameters.Insert("OptionDoNotAdd", New Structure("Use, Order, Title", True, 1));
	AdditionScenarioParameters.OptionDoNotAdd.Insert("Explanation", 
		NStr("ru='ŠŃŠ“ŃŃ Š¾ŃŠæŃŠ°Š²Š»ŠµŠ½Ń ŃŠ¾Š»ŃŠŗŠ¾ Š“Š°Š½Š½ŃŠµ ŃŠ¾Š³Š»Š°ŃŠ½Š¾ Š¾Š±ŃŠøŠ¼ Š½Š°ŃŃŃŠ¾Š¹ŠŗŠ°Š¼.'; en = 'Data will be sent according to the general settings.'; pl = 'BÄdÄ wysyÅane tylko dane zgodnie z ogĆ³lnymi ustawieniami.';es_ES = 'Solo los datos segĆŗn las configuraciones generales se enviarĆ”n.';es_CO = 'Solo los datos segĆŗn las configuraciones generales se enviarĆ”n.';tr = 'Sadece genel ayarlara gĆ¶re veri gĆ¶nderilecektir.';it = 'I dati saranno inviati in base alle impostazioni generali.';de = 'Es werden nur Daten gemĆ¤Ć den allgemeinen Einstellungen gesendet.'")); 
	
	AdditionScenarioParameters.Insert("AllDocumentsOption", New Structure("Use, Order, Title", True, 2));
	AdditionScenarioParameters.AllDocumentsOption.Insert("Explanation",
		NStr("ru='ŠŠ¾ŠæŠ¾Š»Š½ŠøŃŠµŠ»ŃŠ½Š¾ Š±ŃŠ“ŃŃ Š¾ŃŠæŃŠ°Š²Š»ŠµŠ½Ń Š²ŃŠµ Š“Š¾ŠŗŃŠ¼ŠµŠ½ŃŃ Š·Š° ŠæŠµŃŠøŠ¾Š“, ŃŠ“Š¾Š²Š»ŠµŃŠ²Š¾ŃŃŃŃŠøŠµ ŃŃŠ»Š¾Š²ŠøŃŠ¼ Š¾ŃŠ±Š¾ŃŠ°.'; en = 'All documents of the period that match the filter options, are sent.'; pl = 'Wszystkie dokumenty za okres, speÅniajÄce warunki filtrowania bÄdÄ wysyÅane dodatkowo.';es_ES = 'Todos los documentos del perĆ­odo, que cumplen las condiciones del filtro, se enviarĆ”n adicionalmente.';es_CO = 'Todos los documentos del perĆ­odo, que cumplen las condiciones del filtro, se enviarĆ”n adicionalmente.';tr = 'Filtre koÅullarÄ±nÄ± karÅÄ±layan tĆ¼m dĆ¶nem belgeleri ek olarak gĆ¶nderilecektir.';it = 'Tutti i documenti del periodo che corrisponde alle opzioni di filtro sono stati inviati.';de = 'Alle Periodendokumente, die die Filterbedingungen erfĆ¼llen, werden zusĆ¤tzlich gesendet.'")); 
	
	AdditionScenarioParameters.Insert("ArbitraryFilterOption", New Structure("Use, Order, Title", True, 3));
	AdditionScenarioParameters.ArbitraryFilterOption.Insert("Explanation",
		NStr("ru='ŠŠ¾ŠæŠ¾Š»Š½ŠøŃŠµŠ»ŃŠ½Š¾ Š±ŃŠ“ŃŃ Š¾ŃŠæŃŠ°Š²Š»ŠµŠ½Ń Š“Š°Š½Š½ŃŠµ ŃŠ¾Š³Š»Š°ŃŠ½Š¾ Š¾ŃŠ±Š¾ŃŃ.'; en = 'Additional data is sent according to the filter settings.'; pl = 'Dane bÄdÄ wysyÅane dodatkowo zgodnie z filtrem.';es_ES = 'Datos se enviarĆ”n adicionalmente segĆŗn el filtro.';es_CO = 'Datos se enviarĆ”n adicionalmente segĆŗn el filtro.';tr = 'Ek olarak filtreye gĆ¶re veri gĆ¶nderilecektir.';it = 'I dati aggiuntivi saranno inviati in base alle impostazioni di filtro.';de = 'Daten werden zusĆ¤tzlich gemĆ¤Ć dem Filter gesendet.'")); 
	
	AdditionScenarioParameters.Insert("AdditionalOption", New Structure("Use, Order, Title", False,   4));
	AdditionScenarioParameters.AdditionalOption.Insert("Explanation",
		NStr("ru='ŠŃŠ“ŃŃ Š¾ŃŠæŃŠ°Š²Š»ŠµŠ½Ń Š“Š¾ŠæŠ¾Š»Š½ŠøŃŠµŠ»ŃŠ½ŃŠµ Š“Š°Š½Š½ŃŠµ ŠæŠ¾ Š½Š°ŃŃŃŠ¾Š¹ŠŗŠ°Š¼.'; en = 'Additional settings data will be sent.'; pl = 'Dane dodatkowe o ustawieniach zostanÄ wysÅane.';es_ES = 'Datos adiciones sobre las configuraciones se enviarĆ”n.';es_CO = 'Datos adiciones sobre las configuraciones se enviarĆ”n.';tr = 'Ayarlar ile ilgili ek veriler gĆ¶nderilecektir.';it = 'I dati di impostazioni aggiuntive saranno inviati.';de = 'ZusĆ¤tzliche Daten zu den Einstellungen werden gesendet.'")); 
	
	AdditionalOption = AdditionScenarioParameters.AdditionalOption;
	AdditionalOption.Insert("Title", "");
	AdditionalOption.Insert("UseFilterPeriod", False);
	AdditionalOption.Insert("FilterPeriod");
	AdditionalOption.Insert("Filter", Result.AdditionalRegistration.Copy());
	AdditionalOption.Insert("FilterFormName");
	AdditionalOption.Insert("FormCommandTitle");
	
	MetaNode = InfobaseNode.Metadata();
	
	If HasNodeScenario=Undefined Then
		// Additional setup is not required.
		HasNodeScenario = False;
	EndIf;
	
	If HasNodeScenario Then
		If HasExchangePlanManagerAlgorithm("SetUpInteractiveExport",MetaNode.Name) Then
			ModuleNodeManager = ExchangePlans[MetaNode.Name];
			ModuleNodeManager.SetUpInteractiveExport(InfobaseNode, Result.AdditionScenarioParameters);
		EndIf;
	EndIf;
	
	Result.Insert("FromStorageAddress", FromStorageAddress);
	
	SetPrivilegedMode(False);
	
	Return Result;
EndFunction

// Clearing filter for all documents.
//
// Parameters:
//     ExportAddition -Structure, FormAttributesCollection - export parameters details.
//
Procedure InteractiveExportModificationGeneralFilterClearing(ExportAddition) Export
	
	If IsBlankString(ExportAddition.AllDocumentsComposerAddress) Then
		ExportAddition.AllDocumentsFilterComposer.Settings.Filter.Items.Clear();
	Else
		Data = GetFromTempStorage(ExportAddition.AllDocumentsComposerAddress);
		Data.Settings.Filter.Items.Clear();
		ExportAddition.AllDocumentsComposerAddress = PutToTempStorage(Data, ExportAddition.FromStorageAddress);
		
		Composer = New DataCompositionSettingsComposer;
		Composer.Initialize(New DataCompositionAvailableSettingsSource(Data.CompositionSchema));
		Composer.LoadSettings(Data.Settings);
		ExportAddition.AllDocumentsFilterComposer = Composer;
	EndIf;
	
EndProcedure

// Clears the detailed filter.
//
// Parameters:
//     ExportAddition -Structure, FormAttributesCollection - export parameters details.
//
Procedure InteractiveExportModificationDetailsClearing(ExportAddition) Export
	ExportAddition.AdditionalRegistration.Clear();
EndProcedure

// Defines general filter details. If the filter is not filled, returning the empty string.
//
// Parameters:
//     ExportAddition -Structure, FormAttributesCollection - export parameters details.
//
// Returns:
//     String - filter description.
//
Function InteractiveExportModificationGeneralFilterAdditionDescription(Val ExportAddition) Export
	
	ComposerData = GetFromTempStorage(ExportAddition.AllDocumentsComposerAddress);
	
	Source = New DataCompositionAvailableSettingsSource(ComposerData.CompositionSchema);
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(Source);
	Composer.LoadSettings(ComposerData.Settings);
	
	Return ExportAdditionFilterPresentation(Undefined, Composer, "");
EndFunction

// Define the description of the detailed filter. If the filter is not filled, returning the empty string.
//
// Parameters:
//     ExportAddition -Structure, FormAttributesCollection - export parameters details.
//
// Returns:
//     String - filter description.
//
Function InteractiveExportModificationDetailedFilterDetails(Val ExportAddition) Export
	Return DetailedExportAdditionPresentation(ExportAddition.AdditionalRegistration, "");
EndFunction

// Analyzes the filter settings history saved by the user for the node.
//
// Parameters:
//     ExportAddition -Structure, FormAttributesCollection - export parameters details.
//
// Returns:
//     List of values where presentation is a setting name and value is setting data.
//
Function InteractiveExportModificationSettingsHistory(Val ExportAddition) Export
	AdditionDataProcessor = DataProcessors.InteractiveExportModification.Create();
	
	OptionFilter = InteractiveExportModificationVariantFilter(ExportAddition);
	
	Return AdditionDataProcessor.ReadSettingsListPresentations(ExportAddition.InfobaseNode, OptionFilter);
EndFunction

// Restores settings in the ExportAddition attributes by the name of the saved setting.
//
// Parameters:
//     ExportAddition -Structure, FormAttributesCollection - export parameters details.
//     SettingPresentation - String                            - a name of a setting to restore.
//
// Returns:
//     Boolean - True - restored, False - the setting is not found.
//
Function InteractiveExportModificationRestoreSettings(ExportAddition, Val SettingPresentation) Export
	
	AdditionDataProcessor = DataProcessors.InteractiveExportModification.Create();
	FillPropertyValues(AdditionDataProcessor, ExportAddition);
	
	OptionFilter = InteractiveExportModificationVariantFilter(ExportAddition);
	
	// Restoring object state.
	Result = AdditionDataProcessor.RestoreCurrentAttributesFromSettings(SettingPresentation, OptionFilter, ExportAddition.FromStorageAddress);
	
	If Result Then
		FillPropertyValues(ExportAddition, AdditionDataProcessor, "ExportOption, AllDocumentsFilterPeriod, AllDocumentsFilterComposer");
		
		// Updating composer address anyway.
		Data = AdditionDataProcessor.CommonFilterSettingsComposer();
		Data.Settings = ExportAddition.AllDocumentsFilterComposer.Settings;
		ExportAddition.AllDocumentsComposerAddress = PutToTempStorage(Data, ExportAddition.FromStorageAddress);
		
		FillValueTable(ExportAddition.AdditionalRegistration, AdditionDataProcessor.AdditionalRegistration);
		
		// Updating node scenario settings only if they are defined in the read message Otherwise leave the current one.
		If AdditionDataProcessor.AdditionalNodeScenarioRegistration.Count() > 0 Then
			FillPropertyValues(ExportAddition, AdditionDataProcessor, "NodeScenarioFilterPeriod, NodeScenarioFilterPresentation");
			FillValueTable(ExportAddition.AdditionalNodeScenarioRegistration, AdditionDataProcessor.AdditionalNodeScenarioRegistration);
			// Normalizing period settings.
			InteractiveExportModificationSetNodeScenarioPeriod(ExportAddition);
		EndIf;
		
		// The current presentation of saved settings.
		ExportAddition.CurrentSettingsItemPresentation = SettingPresentation;
	EndIf;

	Return Result;
EndFunction

// Saves settings with the specified name, according to the ExportAddition values.
//
// Parameters:
//     ExportAddition -Structure, FormAttributesCollection - export parameters details.
//     SettingPresentation - String                            - a name of the setting to save.
//
Procedure InteractiveExportModificationSaveSettings(ExportAddition, Val SettingPresentation) Export
	
	AdditionDataProcessor = DataProcessors.InteractiveExportModification.Create();
	FillPropertyValues(AdditionDataProcessor, ExportAddition, ,
		"AdditionalRegistration, AdditionalNodeScenarioRegistration");
	
	FillValueTable(AdditionDataProcessor.AdditionalRegistration,             ExportAddition.AdditionalRegistration);
	FillValueTable(AdditionDataProcessor.AdditionalNodeScenarioRegistration, ExportAddition.AdditionalNodeScenarioRegistration);
	
	// Specifying settings composer options again.
	Data = AdditionDataProcessor.CommonFilterSettingsComposer();
	
	If IsBlankString(ExportAddition.AllDocumentsComposerAddress) Then
		SettingsSource = ExportAddition.AllDocumentsFilterComposer.Settings;
	Else
		ComposerStructure = GetFromTempStorage(ExportAddition.AllDocumentsComposerAddress);
		SettingsSource = ComposerStructure.Settings;
	EndIf;
		
	AdditionDataProcessor.AllDocumentsFilterComposer = New DataCompositionSettingsComposer;
	AdditionDataProcessor.AllDocumentsFilterComposer.Initialize( New DataCompositionAvailableSettingsSource(Data.CompositionSchema) );
	AdditionDataProcessor.AllDocumentsFilterComposer.LoadSettings(SettingsSource);
	
	// Saving
	AdditionDataProcessor.SaveCurrentValuesInSettings(SettingPresentation);
	
	// Current presentation of saved settings.
	ExportAddition.CurrentSettingsItemPresentation = SettingPresentation;
	
EndProcedure

// Fills in the form attribute according to settings structure data.
//
// Parameters:
//     Form - ClientApplicationForm - an attribute setup form.
//     ExportAdditionSettings - Structure - initial settings.
//     AdditionAttributeName      - String           - a name of the form attribute for creation and filling in.
//
Procedure InteractiveExportModificationAttributeBySettings(Form, Val ExportAdditionSettings, Val AdditionAttributeName="ExportAddition") Export
	
	SetPrivilegedMode(True);
	
	AdditionScenarioParameters = ExportAdditionSettings.AdditionScenarioParameters;
	
	// Processing the attributes
	AdditionAttribute = Undefined;
	For Each Attribute In Form.GetAttributes() Do
		If Attribute.Name=AdditionAttributeName Then
			AdditionAttribute = Attribute;
			Break;
		EndIf;
	EndDo;
	
	// Checking and adding the attribute.
	ItemsToAdd = New Array;
	If AdditionAttribute=Undefined Then
		AdditionAttribute = New FormAttribute(AdditionAttributeName, 
			New TypeDescription("DataProcessorObject.InteractiveExportModification"));
			
		ItemsToAdd.Add(AdditionAttribute);
		Form.ChangeAttributes(ItemsToAdd);
	EndIf;
	
	// Checking and adding columns of the general additional registration.
	TableAttributePath = AdditionAttribute.Name + ".AdditionalRegistration";
	If Form.GetAttributes(TableAttributePath).Count()=0 Then
		ItemsToAdd.Clear();
		Columns = ExportAdditionSettings.AdditionalRegistration.Columns;
		For Each Column In Columns Do
			ItemsToAdd.Add(New FormAttribute(Column.Name, Column.ValueType, TableAttributePath));
		EndDo;
		Form.ChangeAttributes(ItemsToAdd);
	EndIf;
	
	// Checking and adding additional registration columns of the node scenario.
	TableAttributePath = AdditionAttribute.Name + ".AdditionalNodeScenarioRegistration";
	If Form.GetAttributes(TableAttributePath).Count()=0 Then
		ItemsToAdd.Clear();
		Columns = AdditionScenarioParameters.AdditionalOption.Filter.Columns;
		For Each Column In Columns Do
			ItemsToAdd.Add(New FormAttribute(Column.Name, Column.ValueType, TableAttributePath));
		EndDo;
		Form.ChangeAttributes(ItemsToAdd);
	EndIf;
	
	// Adding data
	AttributeValue = Form[AdditionAttributeName];
	
	// Processing value tables.
	ValueToFormData(AdditionScenarioParameters.AdditionalOption.Filter,
		AttributeValue.AdditionalNodeScenarioRegistration);
	
	AdditionScenarioParameters.AdditionalOption.Filter =TableIntoStrucrureArray(
		AdditionScenarioParameters.AdditionalOption.Filter);
	
	AttributeValue.AdditionScenarioParameters = AdditionScenarioParameters;
	
	AttributeValue.InfobaseNode = ExportAdditionSettings.InfobaseNode;

	AttributeValue.ExportOption                 = ExportAdditionSettings.ExportOption;
	AttributeValue.AllDocumentsFilterPeriod      = ExportAdditionSettings.AllDocumentsFilterPeriod;
	
	Data = GetFromTempStorage(ExportAdditionSettings.AllDocumentsComposerAddress);
	DeleteFromTempStorage(ExportAdditionSettings.AllDocumentsComposerAddress);
	AttributeValue.AllDocumentsComposerAddress = PutToTempStorage(Data, Form.UUID);
	
	AttributeValue.NodeScenarioFilterPeriod = AdditionScenarioParameters.AdditionalOption.FilterPeriod;
	
	If AdditionScenarioParameters.AdditionalOption.Use Then
		AttributeValue.NodeScenarioFilterPresentation = ExportAdditionPresentationByNodeScenario(AttributeValue);
	EndIf;
	
	SetPrivilegedMode(False);
	
EndProcedure

// Returns export by settings details.
//
// Parameters:
//     ExportAddition -Structure, FormDataCollection - export parameters details.
//
// Returns:
//     String - presentation.
// 
Function ExportAdditionPresentationByNodeScenario(Val ExportAddition)
	MetaNode = ExportAddition.InfobaseNode.Metadata();
	If NOT HasExchangePlanManagerAlgorithm("InteractiveExportFilterPresentation",MetaNode.Name) Then
		Return "";
	EndIf;
	ModuleManager = ExchangePlans[MetaNode.Name];
	
	Parameters = New Structure;
	Parameters.Insert("UseFilterPeriod", ExportAddition.AdditionScenarioParameters.AdditionalOption.UseFilterPeriod);
	Parameters.Insert("FilterPeriod",             ExportAddition.NodeScenarioFilterPeriod);
	Parameters.Insert("Filter",                    ExportAddition.AdditionalNodeScenarioRegistration);
	
	Return ModuleManager.InteractiveExportFilterPresentation(ExportAddition.InfobaseNode, Parameters);
EndFunction

// Returns period and filter details as string.
//
//  Parameters:
//      Period:                a period to describeĀ filter.
//      Filter:                 a data composition filter to describe.
//      EmptyFilterDetails: the function returns this value if an empty filter is passed.
//
//  Returns:
//      String - description of period and filter.
//
Function ExportAdditionFilterPresentation(Val Period, Val Filter, Val EmptyFilterDetails=Undefined) Export
	
	OurFilter = ?(TypeOf(Filter)=Type("DataCompositionSettingsComposer"), Filter.Settings.Filter, Filter);
	
	PeriodAsString = ?(ValueIsFilled(Period), String(Period), "");
	FilterString  = String(OurFilter);
	
	If IsBlankString(FilterString) Then
		If EmptyFilterDetails=Undefined Then
			FilterString = NStr("ru='ŠŃŠµ Š¾Š±ŃŠµŠŗŃŃ'; en = 'All objects'; pl = 'Wszystkie obiekty';es_ES = 'Todos objetos';es_CO = 'Todos objetos';tr = 'TĆ¼m nesneler';it = 'Tutti gli oggetti';de = 'Alle Objekte'");
		Else
			FilterString = EmptyFilterDetails;
		EndIf;
	EndIf;
	
	If Not IsBlankString(PeriodAsString) Then
		FilterString =  PeriodAsString + ", " + FilterString;
	EndIf;
	
	Return FilterString;
EndFunction

// Returns details of the detailed filter by the AdditionalRegistration attribute.
//
//  Parameters:
//      AdditionalRegistration - ValueTable, Array - strings or structures that describe the filter.
//      EmptyFilterDetails     - String                  - the function returns this value if an empty filter is passed.
//
Function DetailedExportAdditionPresentation(Val AdditionalRegistration, Val EmptyFilterDetails=Undefined) Export
	
	Text = "";
	For Each Row In AdditionalRegistration Do
		Text = Text + Chars.LF + Row.Presentation + ": " + ExportAdditionFilterPresentation(Row.Period, Row.Filter);
	EndDo;
	
	If Not IsBlankString(Text) Then
		Return TrimAll(Text);
		
	ElsIf EmptyFilterDetails=Undefined Then
		Return NStr("ru='ŠŠ¾ŠæŠ¾Š»Š½ŠøŃŠµŠ»ŃŠ½ŃŠµ Š“Š°Š½Š½ŃŠµ Š½Šµ Š²ŃŠ±ŃŠ°Š½Ń'; en = 'Additional data is not selected'; pl = 'Dane dodatkowe nie zostaÅy wybrane';es_ES = 'Datos adicionales no seleccionados';es_CO = 'Datos adicionales no seleccionados';tr = 'Ek veri seĆ§ilmedi';it = 'Dati aggiuntivi non sono selezionate';de = 'ZusĆ¤tzliche Daten sind nicht ausgewĆ¤hlt'");
		
	EndIf;
	
	Return EmptyFilterDetails;
EndFunction

// The "All documents" metadata object internal group ID.
//
Function ExportAdditionAllDocumentsID() Export
	// The ID must not be identical to the full metadata name.
	Return "AllDocuments";
EndFunction

// The "All catalogs" metadata object internal group ID.
//
Function ExportAdditionAllCatalogsID() Export
	// The ID must not be identical to the full metadata name.
	Return "AllCatalogs";
EndFunction

// Name to save and restore settings upon interactive export addition.
//
Function ExportAdditionSettingsAutoSavingName() Export
	Return NStr("ru = 'ŠŠ¾ŃŠ»ŠµŠ“Š½ŃŃ Š¾ŃŠæŃŠ°Š²ŠŗŠ° (ŃŠ¾ŃŃŠ°Š½ŃŠµŃŃŃ Š°Š²ŃŠ¾Š¼Š°ŃŠøŃŠµŃŠŗŠø)'; en = 'Last data sending (auto-saved)'; pl = 'Ostatnio wysÅane (zapisane automatycznie)';es_ES = 'Ćltimo enviado (guardado automĆ”ticamente)';es_CO = 'Ćltimo enviado (guardado automĆ”ticamente)';tr = 'Son veri gĆ¶nderimi (otomatik kaydedildi)';it = 'Ultima data di invio (salvataggio automatico)';de = 'Zuletzt gesendet (automatisch gespeichert)'");
EndFunction

// Carries out additional registration of objects by settings.
//
// Parameters:
//     ExportAddition -Structure, FormDataCollection - export parameters details.
//
Procedure InteractiveExportModificationRegisterAdditionalData(Val ExportAddition) Export
	
	If ExportAddition.ExportOption <= 0 Then
		Return;
	EndIf;
	
	ReportObject = DataProcessors.InteractiveExportModification.Create();
	FillPropertyValues(ReportObject, ExportAddition,,"AdditionalRegistration, AdditionalNodeScenarioRegistration");
		
	If ReportObject.ExportOption=1 Then
		// Period with filter, additional option is empty.
		
	ElsIf ExportAddition.ExportOption=2 Then
		// Detailed settings
		ReportObject.AllDocumentsFilterComposer = Undefined;
		ReportObject.AllDocumentsFilterPeriod      = Undefined;
		
		FillValueTable(ReportObject.AdditionalRegistration, ExportAddition.AdditionalRegistration);
		
	ElsIf ExportAddition.ExportOption=3 Then
		// According to the node scenario imitating detailed option.
		ReportObject.ExportOption = 2;
		
		ReportObject.AllDocumentsFilterComposer = Undefined;
		ReportObject.AllDocumentsFilterPeriod      = Undefined;
		
		FillValueTable(ReportObject.AdditionalRegistration, ExportAddition.AdditionalNodeScenarioRegistration);
	EndIf;
	
	ReportObject.RecordAdditionalChanges();
EndProcedure

// Sets the general period for all filter sections.
//
// Parameters:
//     ExportAddition -Structure, FormDataCollection - export parameters details.
//
Procedure InteractiveExportModificationSetNodeScenarioPeriod(ExportAddition) Export
	For Each Row In ExportAddition.AdditionalNodeScenarioRegistration Do
		Row.Period = ExportAddition.NodeScenarioFilterPeriod;
	EndDo;
	
	// Updating the presentation
	ExportAddition.NodeScenarioFilterPresentation = ExportAdditionPresentationByNodeScenario(ExportAddition);
EndProcedure

// Returns used filter options by settings data.
//
// Parameters:
//     ExportAddition -Structure, FormDataCollection - export parameters details.
//
// Returns:
//     Array contains the following numbers of used options:
//               0 - without filter, 1 - all document filter, 2 - detailed, 3 - node scenario.
//
Function InteractiveExportModificationVariantFilter(Val ExportAddition) Export
	
	Result = New Array;
	
	DataTest = New Structure("AdditionScenarioParameters");
	FillPropertyValues(DataTest, ExportAddition);
	AdditionScenarioParameters = DataTest.AdditionScenarioParameters;
	If TypeOf(AdditionScenarioParameters)<>Type("Structure") Then
		// If there is no settings specified, using all options as the default settings
		Return Undefined;
	EndIf;
	
	If AdditionScenarioParameters.Property("OptionDoNotAdd") 
		AND AdditionScenarioParameters.OptionDoNotAdd.Use Then
		Result.Add(0);
	EndIf;
	
	If AdditionScenarioParameters.Property("AllDocumentsOption")
		AND AdditionScenarioParameters.AllDocumentsOption.Use Then
		Result.Add(1);
	EndIf;
	
	If AdditionScenarioParameters.Property("ArbitraryFilterOption")
		AND AdditionScenarioParameters.ArbitraryFilterOption.Use Then
		Result.Add(2);
	EndIf;
	
	If AdditionScenarioParameters.Property("AdditionalOption")
		AND AdditionScenarioParameters.AdditionalOption.Use Then
		Result.Add(3);
	EndIf;
	
	If Result.Count()=4 Then
		// All options are selected, deleting filter.
		Return Undefined;
	EndIf;

	Return Result;
EndFunction

#EndRegion

#EndRegion