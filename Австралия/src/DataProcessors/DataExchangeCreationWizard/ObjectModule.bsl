#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var ErrorMessageStringField; // String - a variable contains a string with error message.

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// Performs the following actions on data exchange creation:
// - creates or updates nodes of the current exchange plan
// - loads data conversion rules from the template of the current exchange plan (if infobase is not a DIB)
// - loads data registration rules from the template of the current exchange plan
// - loads exchange message transport settings
// - sets the infobase prefix constant value (if it is not set)
// - registers all data on the current exchange plan node according to object registration rules.
//
// Parameters:
//  Cancel - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
// 
Procedure ExecuteActionsToSetNewDataExchange(Cancel,
	NodeFilterStructure,
	NodeDefaultValues,
	RecordDataForExport = True,
	UseTransportSettings = True)
	
	ThisNodeCode = ?(UsePrefixesForExchangeSettings,
					GetThisBaseNodeCode(SourceInfobasePrefix),
					GetThisBaseNodeCode(SourceInfobaseID));
	If WizardRunOption = "ContinueDataExchangeSetup" Then
		NewNodeCode = SecondInfobaseNewNodeCode;
	ElsIf UsePrefixesForExchangeSettings Then
		NewNodeCode = DataExchangeServer.ExchangePlanNodeCodeString(DestinationInfobasePrefix);
	Else
		NewNodeCode = DestinationInfobaseID;
	EndIf;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		// Creating/updating the exchange plan node.
		CreateUpdateExchangePlanNodes(NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode);
		
		If UseTransportSettings Then
			
			// Loading message transport settings.
			UpdateExchangeMessageTransportSettings();
			
		EndIf;
		
		// Updating the infobase prefix constant value.
		If UsePrefixesForExchangeSettings
			AND Not SourceInfobasePrefixIsSet Then
			
			UpdateInfobasePrefixConstantValue();
			
		EndIf;
		
		If IsDistributedInfobaseSetup
			AND WizardRunOption = "ContinueDataExchangeSetup" Then
			
			Constants.SubordinateDIBNodeSetupCompleted.Set(True);
			Constants.UseDataSynchronization.Set(True);
			Constants.DoNotUseSeparationByDataAreas.Set(True);
			
			// Importing rules because exchange rules are not migrated to DIB.
			DataExchangeServer.UpdateDataExchangeRules();
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		InformAboutError(ErrorInfo(), Cancel);
		Return;
	EndTry;
	
	// Updating cached values of the object registration mechanism.
	DataExchangeServerCall.CheckObjectsRegistrationMechanismCache();
	
	Try
		
		If RecordDataForExport
			AND Not IsDistributedInfobaseSetup Then
			
			// Registering changes for an exchange plan node.
			RecordChangesForExchange(Cancel);
			
		EndIf;
		
	Except
		InformAboutError(ErrorInfo(), Cancel);
		Return;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// This function is intended for operations through an external connection.

// Sets up a new data exchange over an external connection.
//
Procedure ExternalConnectionSetUpNewDataExchange(Cancel, 
									CorrespondentInfobaseNodeFilterSetup, 
									CorrespondentInfobaseNodeDefaultValues, 
									InfobasePrefixSet, 
									InfobasePrefix) Export
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	NodeFilterStructure    = GetFilterSettingsValues(ValueFromStringInternal(CorrespondentInfobaseNodeFilterSetup));
	NodeDefaultValues = GetFilterSettingsValues(ValueFromStringInternal(CorrespondentInfobaseNodeDefaultValues));
	
	ErrorMessageStringField = Undefined;
	WizardRunOption = "ContinueDataExchangeSetup";
	
	ThisNodeCode = GetThisBaseNodeCode(SourceInfobasePrefix);
	NewNodeCode = SecondInfobaseNewNodeCode;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Creating a node
		CreateUpdateExchangePlanNodes(NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode);
		
		// Loading message transport settings.
		UpdateCOMExchangeMessageTransportSettings();
		
		// Updating the infobase prefix constant value.
		If Not InfobasePrefixSet Then
			
			ValueBeforeUpdate = GetFunctionalOption("InfobasePrefix");
			
			If ValueBeforeUpdate <> InfobasePrefix Then
				
				DataExchangeServer.SetInfobasePrefix(TrimAll(InfobasePrefix));
				
			EndIf;
			
		EndIf;
		
		If Cancel Then
			Raise(NStr("ru = 'При создании настройки синхронизации данных возникли ошибки.'; en = 'Error creating data synchronization settings.'; pl = 'Podczas tworzenia ustawień synchronizacji danych wystąpiły błędy.';es_ES = 'Al crear la configuración de la sincronización de datos, han ocurrido errores.';es_CO = 'Al crear la configuración de la sincronización de datos, han ocurrido errores.';tr = 'Veri eşleme ayarları oluştuğunda hatalar oluştu.';it = 'Errori durante la creazione delle impostazioni di sincronizzazione dati.';de = 'Beim Erstellen der Datensynchronisierungseinstellung sind Fehler aufgetreten.'"));
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		InformAboutError(ErrorInfo(), Cancel);
	EndTry;
	
EndProcedure

// Sets up a new data exchange over an external connection.
//
Procedure ExternalConnectionSetUpNewDataExchange_2_0_1_6(Cancel, 
									CorrespondentInfobaseNodeFilterSetup, 
									CorrespondentInfobaseNodeDefaultValues, 
									InfobasePrefixSet, 
									InfobasePrefix) Export
	
	NodeFilterStructure    = GetFilterSettingsValues(Common.ValueFromXMLString(CorrespondentInfobaseNodeFilterSetup));
	NodeDefaultValues = GetFilterSettingsValues(Common.ValueFromXMLString(CorrespondentInfobaseNodeDefaultValues));
	
	ErrorMessageStringField = Undefined;
	WizardRunOption = "ContinueDataExchangeSetup";
	
	ThisNodeCode = GetThisBaseNodeCode(SourceInfobasePrefix);
	NewNodeCode = SecondInfobaseNewNodeCode;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		DataExchangeServer.CheckDataExchangeUsage();
		
		// Creating a node
		CreateUpdateExchangePlanNodes(NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode);
		
		// Loading message transport settings.
		UpdateCOMExchangeMessageTransportSettings();
		
		// Updating the infobase prefix constant value.
		If Not InfobasePrefixSet Then
			
			ValueBeforeUpdate = GetFunctionalOption("InfobasePrefix");
			
			If ValueBeforeUpdate <> InfobasePrefix Then
				
				DataExchangeServer.SetInfobasePrefix(TrimAll(InfobasePrefix));
				
			EndIf;
			
		EndIf;
		
		If Cancel Then
			Raise(NStr("ru = 'При создании настройки синхронизации данных возникли ошибки.'; en = 'Error creating data synchronization settings.'; pl = 'Podczas tworzenia ustawień synchronizacji danych wystąpiły błędy.';es_ES = 'Al crear la configuración de la sincronización de datos, han ocurrido errores.';es_CO = 'Al crear la configuración de la sincronización de datos, han ocurrido errores.';tr = 'Veri eşleme ayarları oluştuğunda hatalar oluştu.';it = 'Errori durante la creazione delle impostazioni di sincronizzazione dati.';de = 'Beim Erstellen der Datensynchronisierungseinstellung sind Fehler aufgetreten.'"));
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		InformAboutError(ErrorInfo(), Cancel);
	EndTry;
	
EndProcedure

// Registers changes for an exchange plan node.
//
Procedure ExternalConnectionRecordChangesForExchange() Export
	
	// Registering changes for an exchange plan node.
	RecordChangesForExchange(False);
	
EndProcedure

// Reads settings of data exchange wizard from an XML string.
//
Procedure ExternalConnectionImportWizardParameters(Cancel, XMLString) Export
	
	ImportWizardParameters(Cancel, XMLString);
	
EndProcedure

// Updates data exchange node settings over an external connection and sets default values.
//
Procedure ExternalConnectionUpdateDataExchangeSettings(NodeDefaultValues) Export
	
	BeginTransaction();
	Try
		
		// Updating settings for the node.
		InfobaseNodeObject = InfobaseNode.GetObject();
		
		// Setting default values.
		DataExchangeEvents.SetNodeDefaultValues(InfobaseNodeObject, NodeDefaultValues);
		
		InfobaseNodeObject.AdditionalProperties.Insert("GettingExchangeMessage");
		InfobaseNodeObject.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Sets up a new data exchange over a web service.
// See the detailed description in the SetUpNewDataExchange procedure.
//
Procedure SetUpNewDataExchangeWebService(Cancel, NodeFilterStructure, NodeDefaultValues) Export
	
	NodeFilterStructure    = GetFilterSettingsValues(NodeFilterStructure);
	NodeDefaultValues = GetFilterSettingsValues(NodeDefaultValues);
	If UsePrefixesForExchangeSettings Then
		SourceInfobasePrefixIsSet = ValueIsFilled(GetFunctionalOption("InfobasePrefix"));
	EndIf;

	// {Handler: OnGetSenderData} Start
	If DataExchangeServer.HasExchangePlanManagerAlgorithm("OnGetSenderData",ExchangePlanName) Then
		Try
			ExchangePlans[ExchangePlanName].OnGetSenderData(NodeFilterStructure, False);
		Except
			InformAboutError(ErrorInfo(), Cancel);
			Return;
		EndTry;
	EndIf;
	// {Handler: OnGetSenderData} End
	
	ExecuteActionsToSetNewDataExchange(Cancel,
													NodeFilterStructure,
													NodeDefaultValues,
													False,
													False);
	
	If Cancel Then
		DeleteDataExchangeSettings();
	EndIf;
	
EndProcedure

Procedure DeleteDataExchangeSettings()
	
	SetPrivilegedMode(True);
	ExchangePlanManager = ExchangePlans[ExchangePlanName];
	NodeToDelete = ExchangePlanManager.FindByCode(SecondInfobaseNewNodeCode);
	If Not NodeToDelete.IsEmpty() Then
		NodeToDeleteObject = NodeToDelete.GetObject();
		NodeToDeleteObject.Delete();
	EndIf;
	
EndProcedure

// Exports wizard parameters to the temporary storage to continue exchange setup in the second base.
//
// Parameters:
//  Cancel - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
//  TempStorageAddress - String - on succesful export xml file with settings a temporary storage 
//                                      address is written in this variable. The data file is 
//                                      available on server and client at the address.
// 
Procedure ExportWizardParametersToTempStorage(Cancel, TempStorageAddress) Export
	
	SetPrivilegedMode(True);
	
	// Getting the temporary file name in the local file system on the server.
	TempFileName = GetTempFileName("xml");
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	Try
		ModuleSetupWizard.ConnectionSettingsInXML(ThisObject, TempFileName);
	Except
		InformAboutError(ErrorInfo(), Cancel);
		DeleteTempFile(TempFileName);
		Return;
	EndTry;
	
	TempStorageAddress = PutToTempStorage(New BinaryData(TempFileName));
	
	DeleteTempFile(TempFileName);
	
EndProcedure

// Initializes exchange node settings.
//
Procedure Initializing(Node) Export
	
	InfobaseNode = Node;
	InfobaseNodeParameters = Common.ObjectAttributesValues(Node, "Code, Description");
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
	
	ThisInfobaseDescription = Common.ObjectAttributeValue(ExchangePlans[ExchangePlanName].ThisNode(), "Description");
	SecondInfobaseDescription = InfobaseNodeParameters.Description;
	
	DestinationInfobasePrefix = InfobaseNodeParameters.Code;
	
	TransportSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettings(Node);
	
	FillPropertyValues(ThisObject, TransportSettings);
	
	ExchangeMessagesTransportKind = TransportSettings.DefaultExchangeMessagesTransportKind;
	
	UseTransportParametersCOM = False;
	UseTransportParametersEMAIL = False;
	UseTransportParametersFILE = False;
	UseTransportParametersFTP = False;
	
	If ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FILE Then
		
		UseTransportParametersFILE = True;
		
	ElsIf ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FTP Then
		
		UseTransportParametersFTP = True;
		
	ElsIf ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.EMAIL Then
		
		UseTransportParametersEMAIL = True;
		
	ElsIf ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.COM Then
		
		UseTransportParametersCOM = True;
		
	EndIf;
	
	UsePrefixesForExchangeSettings = Not (DataExchangeServer.IsXDTOExchangePlan(ExchangePlanName)
		AND DataExchangeXDTOServer.VersionWithDataExchangeIDSupported(ExchangePlans[ExchangePlanName].EmptyRef()));
		
	If UsePrefixesForExchangeSettings Then
		If Common.DataSeparationEnabled() Then
			SourceInfobasePrefix = DataExchangeServer.CodeOfPredefinedExchangePlanNode(ExchangePlanName);
		Else
			SourceInfobasePrefix = GetFunctionalOption("InfobasePrefix");
		EndIf;
		SourceInfobasePrefixIsSet = ValueIsFilled(SourceInfobasePrefix);
	Else
		PredefinedNodeCode = DataExchangeServer.CodeOfPredefinedExchangePlanNode(ExchangePlanName);
		SourceInfobaseID = PredefinedNodeCode;
		DestinationInfobasePrefixSpecified = False;
		SourceInfobasePrefixIsSet = True;
	EndIf;
	
	If Not SourceInfobasePrefixIsSet
		AND UsePrefixesForExchangeSettings Then
		DataExchangeOverridable.OnDetermineDefaultInfobasePrefix(SourceInfobasePrefix);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

// Returns the data exchange error message string.
//
// Returns:
//  String - a data exchange error message string.
//
Function ErrorMessageString() Export
	
	If TypeOf(ErrorMessageStringField) <> Type("String") Then
		
		ErrorMessageStringField = "";
		
	EndIf;
	
	Return ErrorMessageStringField;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Internal auxiliary procedures and functions.

Procedure CreateUpdateExchangePlanNodes(NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode)
	
	ExchangePlanManager = ExchangePlans[ExchangePlanName];
	
	// UPDATING THIS NODE, IF NECESSARY
	
	// Getting references to this exchange plan node.
	ThisNode = ExchangePlanManager.ThisNode();
	
	ThisNodeCodeInDatabase = Common.ObjectAttributeValue(ThisNode, "Code");
	IsDIBExchangePlan  = DataExchangeCached.IsDistributedInfobaseExchangePlan(ExchangePlanName);
	
	If IsBlankString(Common.ObjectAttributeValue(ThisNode, "Code"))
		Or (IsDIBExchangePlan AND ThisNodeCodeInDatabase <> ThisNodeCode)
		Or (UsePrefixesForExchangeSettings AND ThisNodeCodeInDatabase <> ThisNodeCode) Then
		ThisNodeObject = ThisNode.GetObject();
		ThisNodeObject.Code = ThisNodeCode;
		ThisNodeObject.Description = ThisInfobaseDescription;
		ThisNodeObject.AdditionalProperties.Insert("GettingExchangeMessage");
		ThisNodeObject.Write();
		
	EndIf;
	
	// GETTING THE NODE FOR EXCHANGE
	CreateNewNode = False;
	If IsDistributedInfobaseSetup
		AND WizardRunOption = "ContinueDataExchangeSetup" Then
		
		MasterNode = DataExchangeServer.MasterNode();
		
		If MasterNode = Undefined Then
			
			Raise NStr("ru = 'Главный узел для текущей информационной базы не определен.
							|Возможно, информационная база не является подчиненным узлом в РИБ.'; 
							|en = 'Master node is not determined for the current infobase.
							|The infobase might not be a DIB subnode.'; 
							|pl = 'Główny węzeł bieżącej bazy informacyjnej nie został określony.
							|Być może baza informacyjna nie jest podrzędnym węzłem w RIB.';
							|es_ES = 'El nodo principal para la infobase actual no está determinado.
							|Probablemente, la infobase no es un nodo subordinado en el RIB.';
							|es_CO = 'El nodo principal para la infobase actual no está determinado.
							|Probablemente, la infobase no es un nodo subordinado en el RIB.';
							|tr = 'Geçerli veritabanı için ana ünite tanımlanmamıştır.
							| Veritabanı RİB''deki alt ünitesi olmayabilir.';
							|it = 'Il nodo principale non è determinato per l''infobase corrente.
							|L''infobase potrebbe non essere un nodo DIB subordinato.';
							|de = 'Der Hauptknoten für die aktuelle Infobase ist nicht festgelegt.
							|Vielleicht ist die Infobase kein untergeordneter Knoten im RIB.'");
		EndIf;
		
		NewNode = MasterNode.GetObject();
		
	Else
		
		// CREATING/UPDATING THE NODE
		NewNode = ExchangePlanManager.FindByCode(NewNodeCode);
		CreateNewNode = NewNode.IsEmpty();
		If CreateNewNode Then
			NewNode = ExchangePlanManager.CreateNode();
			NewNode.Code = NewNodeCode;
		Else
			Raise NStr("ru = 'Значение префикса первой информационной базы не уникально.
				|В системе уже существует синхронизация данных для информационной базы (программы) с указанным префиксом.'; 
				|en = 'Prefix value of the first infobase is not unique.
				|Data synchronization for infobase (application) with the specified prefix is already configured in the system.'; 
				|pl = 'Wartość przedrostka pierwszej bazy informacyjnej nie jest unikalna. 
				|W systemie istnieje już synchronizacja danych dla bazy informacyjnej (programu) z podanym prefiksem.';
				|es_ES = 'El valor del prefijo en la primera base de información no es único.
				|En el sistema ya existe sincronización de datos para la base de información (del programa) con el prefijo indicado.';
				|es_CO = 'El valor del prefijo en la primera base de información no es único.
				|En el sistema ya existe sincronización de datos para la base de información (del programa) con el prefijo indicado.';
				|tr = 'Ilk veri tabanın öneki değeri benzersiz değil. 
				| Sistemde belirtilen öneke sahip veri tabanı (program) için veri eşleşmesi zaten mevcut.';
				|it = 'Il valore prefisso del primo infobase non è univoco.
				|La sincronizzazione dati per l''infobase (applicazione) con il prefisso specificato è già configurata nel sistema.';
				|de = 'Der Wert des Präfixes der ersten Informationsbasis ist nicht eindeutig.
				|Das System hat bereits eine Datensynchronisation für die Informationsbasis (Programm) mit dem angegebenen Präfix.'");
		EndIf;
		
		NewNode.Description = SecondInfobaseDescription;
		
		If Common.HasObjectAttribute("SettingsMode", Metadata.ExchangePlans[ExchangePlanName]) Then
			NewNode.SettingsMode = ExchangeSettingsOption;
		EndIf;
		
	EndIf;
	
	// Setting filter values for the new node.
	DataExchangeEvents.SetNodeFilterValues(NewNode, NodeFilterStructure);
	
	// Setting default values for the new node.
	DataExchangeEvents.SetNodeDefaultValues(NewNode, NodeDefaultValues);
	
	// Resetting message counters.
	NewNode.SentNo = 0;
	NewNode.ReceivedNo     = 0;
	
	If Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable()
		AND DataExchangeServer.IsSeparatedSSLExchangePlan(ExchangePlanName) Then
		
		NewNode.RegisterChanges = True;
		
	EndIf;
	
	If ValueIsFilled(NewRef) Then
		NewNode.SetNewObjectRef(NewRef);
	EndIf;
	
	NewNode.DataExchange.Load = True;
	NewNode.Write();
	
	If DataExchangeCached.IsXDTOExchangePlan(ExchangePlanName) Then
		
		DatabaseObjectsTable = DataExchangeXDTOServer.SupportedObjectsInFormat(ExchangePlanName,
			"SendReceive", NewNode.Ref);
		CorrespondentObjectsTable = DatabaseObjectsTable.CopyColumns();
		
		For Each InfobaseObjectsString In DatabaseObjectsTable Do
			CorrespondentObjectsString = CorrespondentObjectsTable.Add();
			FillPropertyValues(CorrespondentObjectsString, InfobaseObjectsString, "Version, Object");
			CorrespondentObjectsString.Sending  = InfobaseObjectsString.Get;
			CorrespondentObjectsString.Get = InfobaseObjectsString.Sending;
		EndDo;
		
		XDTOSettingManager = Common.CommonModule("InformationRegisters.XDTODataExchangeSettings");
		XDTOSettingManager.UpdateSettings(
			NewNode.Ref, "SupportedObjects", DatabaseObjectsTable);
		XDTOSettingManager.UpdateCorrespondentSettings(
			NewNode.Ref, "SupportedObjects", CorrespondentObjectsTable);
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode",       NewNode.Ref);
		RecordStructure.Insert("CorrespondentExchangePlanName", CorrespondentExchangePlanName);
		
		DataExchangeServer.UpdateInformationRegisterRecord(RecordStructure, "XDTODataExchangeSettings");
	EndIf;
	
	// Node common data.
	InformationRegisters.CommonInfobasesNodesSettings.UpdatePrefixes(
		NewNode.Ref,
		?(UsePrefixesForExchangeSettings, SourceInfobasePrefix, ""),
		DestinationInfobasePrefix);
		
	If Not DataExchangeServer.SynchronizationSetupCompleted(NewNode.Ref) Then
		DataExchangeServer.CompleteDataSynchronizationSetup(NewNode.Ref);
	EndIf;
	
	InfobaseNode = NewNode.Ref;
	
	If CreateNewNode
		AND Not Common.DataSeparationEnabled() Then
		DataExchangeServer.UpdateDataExchangeRules();
	EndIf;
	If ThisNodeCode <> ThisNodeCodeInDatabase 
		AND (UsePrefixesForExchangeSettings
			Or UsePrefixesForCorrespondentExchangeSettings) Then
		// Node in the correspondent base needs recoding.
		StructureTemporaryCode = New Structure("Correspondent, NodeCode", InfobaseNode, ThisNodeCode);
		DataExchangeServer.AddRecordToInformationRegister(StructureTemporaryCode, "PredefinedNodesAliases");
	EndIf;

EndProcedure

Procedure UpdateExchangeMessageTransportSettings()
	
	RecordStructure = New Structure;
	RecordStructure.Insert("Correspondent",                           InfobaseNode);
	RecordStructure.Insert("DefaultExchangeMessagesTransportKind", ExchangeMessagesTransportKind);
	
	RecordStructure.Insert("WSUseHighVolumeDataTransfer", True);
	
	SupplementStructureWithAttributeValue(RecordStructure, "EMAILMaxMessageSize");
	SupplementStructureWithAttributeValue(RecordStructure, "EMAILCompressOutgoingMessageFile");
	SupplementStructureWithAttributeValue(RecordStructure, "EMAILUserAccount");
	SupplementStructureWithAttributeValue(RecordStructure, "EMAILTransliterateExchangeMessageFileNames");
	SupplementStructureWithAttributeValue(RecordStructure, "FILEInformationExchangeDirectory");
	SupplementStructureWithAttributeValue(RecordStructure, "FILECompressOutgoingMessageFile");
	SupplementStructureWithAttributeValue(RecordStructure, "FILETransliterateExchangeMessageFileNames");
	SupplementStructureWithAttributeValue(RecordStructure, "FTPCompressOutgoingMessageFile");
	SupplementStructureWithAttributeValue(RecordStructure, "FTPConnectionMaxMessageSize");
	SupplementStructureWithAttributeValue(RecordStructure, "FTPConnectionPassword");
	SupplementStructureWithAttributeValue(RecordStructure, "FTPConnectionPassiveConnection");
	SupplementStructureWithAttributeValue(RecordStructure, "FTPConnectionUser");
	SupplementStructureWithAttributeValue(RecordStructure, "FTPConnectionPort");
	SupplementStructureWithAttributeValue(RecordStructure, "FTPConnectionPath");
	SupplementStructureWithAttributeValue(RecordStructure, "FTPTransliterateExchangeMessageFileNames");
	SupplementStructureWithAttributeValue(RecordStructure, "WSWebServiceURL");
	SupplementStructureWithAttributeValue(RecordStructure, "WSUsername");
	SupplementStructureWithAttributeValue(RecordStructure, "WSPassword");
	SupplementStructureWithAttributeValue(RecordStructure, "WSRememberPassword");
	SupplementStructureWithAttributeValue(RecordStructure, "ArchivePasswordExchangeMessages");
	
	// Adding information register record
	InformationRegisters.DataExchangeTransportSettings.AddRecord(RecordStructure);
	
EndProcedure

Procedure UpdateCOMExchangeMessageTransportSettings()
	
	RecordStructure = New Structure;
	RecordStructure.Insert("Correspondent",                           InfobaseNode);
	RecordStructure.Insert("DefaultExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.COM);
	
	SupplementStructureWithAttributeValue(RecordStructure, "COMOperatingSystemAuthentication");
	SupplementStructureWithAttributeValue(RecordStructure, "COMInfobaseOperatingMode");
	SupplementStructureWithAttributeValue(RecordStructure, "COM1CEnterpriseServerSideInfobaseName");
	SupplementStructureWithAttributeValue(RecordStructure, "COMUsername");
	SupplementStructureWithAttributeValue(RecordStructure, "COM1CEnterpriseServerName");
	SupplementStructureWithAttributeValue(RecordStructure, "COMInfobaseDirectory");
	SupplementStructureWithAttributeValue(RecordStructure, "COMUserPassword");
	
	// Adding information register record
	InformationRegisters.DataExchangeTransportSettings.AddRecord(RecordStructure);
	
EndProcedure

Procedure SupplementStructureWithAttributeValue(RecordStructure, AttributeName)
	
	RecordStructure.Insert(AttributeName, ThisObject[AttributeName]);
	
EndProcedure

Procedure UpdateInfobasePrefixConstantValue()
	ValueBeforeUpdate = GetFunctionalOption("InfobasePrefix");
	
	If IsBlankString(ValueBeforeUpdate)
		AND ValueBeforeUpdate <> SourceInfobasePrefix Then
		
		DataExchangeServer.SetInfobasePrefix(TrimAll(SourceInfobasePrefix));
		
	EndIf;
	
EndProcedure

Procedure RecordChangesForExchange(Cancel)
	
	Try
		DataExchangeServer.RegisterDataForInitialExport(InfobaseNode);
	Except
		InformAboutError(ErrorInfo(), Cancel);
		Return;
	EndTry;
	
EndProcedure

Function GetThisBaseNodeCode(Val InfobasePrefixSpecifiedByUser)
	
	If WizardRunOption = "ContinueDataExchangeSetup" Then
		
		If ValueIsFilled(PredefinedNodeCode) Then
			Return PredefinedNodeCode;
		Else
			Return TrimAll(InfobasePrefixSpecifiedByUser);
		EndIf;
		
	EndIf;
	If UsePrefixesForExchangeSettings Then
		If ValueIsFilled(SourceInfobasePrefix) Then
			Result = SourceInfobasePrefix;
		Else
			If IsBlankString(Result) Then
				Result = InfobasePrefixSpecifiedByUser;
			
				If IsBlankString(Result) Then
					
					Return "000";
					
				EndIf;
			EndIf;
		EndIf;
		Return DataExchangeServer.ExchangePlanNodeCodeString(Result);
	Else
		If ValueIsFilled(SourceInfobaseID) Then 
			Return SourceInfobaseID;
		Else
			Return "";
		EndIf;
	EndIf;
EndFunction

// Reads settings of data exchange wizard from an XML string.
//
Procedure ImportWizardParameters(Cancel, XMLString) Export
	
	// Checking whether it is possible to use the exchange plan in SaaS.
	If Common.DataSeparationEnabled()
		AND Not DataExchangeCached.ExchangePlanUsedInSaaS(ExchangePlanName) Then
		ErrorMessageStringField = NStr("ru = 'Синхронизация данных с этой программой в режиме сервиса не предусмотрена.'; en = 'Data synchronization with this application is not available in the service mode.'; pl = 'Synchronizacja danych z tym programem w trybie serwisu nie jest przewidziana.';es_ES = 'La sincronización de datos con este programa en el modo de servicio no está prevista.';es_CO = 'La sincronización de datos con este programa en el modo de servicio no está prevista.';tr = 'Servis modunda verilerin bu programla eşleşmesi öngörülmemiştir.';it = 'La sincronizzazione dati con questa applicazione non è disponibile in modalità di servizio.';de = 'Die Datensynchronisation mit diesem Programm ist im Servicemodus nicht vorgesehen.'");
		DataExchangeServer.ReportError(ErrorMessageString(), Cancel);
		Return;
	EndIf;
	
	If IsBlankString(WizardRunOption) Then
		WizardRunOption = "ContinueDataExchangeSetup";
	EndIf;
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	Try
		ModuleSetupWizard.FillConnectionSettingsFromXMLString(ThisObject, XMLString);
	Except
		InformAboutError(ErrorInfo(), Cancel);
	EndTry;
	
EndProcedure

Procedure DeleteTempFile(TempFileName)
	
	If Not IsBlankString(TempFileName) Then
		
		DeleteFiles(TempFileName);
		
	EndIf;
	
EndProcedure

Procedure InformAboutError(ErrorInformation, Cancel)
	
	ErrorMessageStringField = DetailErrorDescription(ErrorInformation);
	
	DataExchangeServer.ReportError(BriefErrorDescription(ErrorInformation), Cancel);
	
	WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogMessageText(), EventLogLevel.Error,,, ErrorMessageString());
	
EndProcedure

Function GetFilterSettingsValues(ExternalConnectionSettingsStructure)
	
	Return DataExchangeServer.GetFilterSettingsValues(ExternalConnectionSettingsStructure);
	
EndFunction

#EndRegion

#EndIf