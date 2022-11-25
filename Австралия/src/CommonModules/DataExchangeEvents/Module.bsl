#Region Public

// The handler procedure for "BeforeWrite" event of documents for the mechanism of registering objects on nodes.
//
// Parameters:
//  ExchangePlanName - String - a name of exchange plan where objects are registered.
//  Source - DocumentObject - an event source.
//  Cancel - Boolean - a flag of cancelling the handler.
//  WriteMode - DocumentWriteMode - see the Syntax Assistant for DocumentWriteMode.
//  PostingMode - DocumentPostingMode - see the Syntax Assistant for DocumentPostingMode.
// 
Procedure ObjectsRegistrationMechanismBeforeWriteDocument(ExchangePlanName, Source, Cancel, WriteMode, PostingMode) Export
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		
		Module = Common.CommonModule("PersonalDataProtection");
		If Module.SkipObjectRegistration(ExchangePlanName, Source) Then
			Return;
		EndIf;
		
	EndIf;
	
	AdditionalParameters = New Structure("WriteMode", WriteMode);
	RegisterObjectChange(ExchangePlanName, Source, Cancel, AdditionalParameters);
	
EndProcedure

// The handler procedure for "BeforeWrite" event of reference data types (except for documents) for 
// the mechanism of registering objects on nodes.
//
// Parameters:
//  ExchangePlanName - String - a name of exchange plan where objects are registered.
//  Source - CatalogObject, ChartOfCharacteristicTypesObject - an event source, except the DocumentObject type.
//  Cancel - Boolean - a flag of cancelling the handler.
// 
Procedure ObjectsRegistrationMechanismBeforeWrite(ExchangePlanName, Source, Cancel) Export
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		
		Module = Common.CommonModule("PersonalDataProtection");
		If Module.SkipObjectRegistration(ExchangePlanName, Source) Then
			Return;
		EndIf;
		
	EndIf;
	
	RegisterObjectChange(ExchangePlanName, Source, Cancel);
	
EndProcedure

// The handler procedure for "BeforeWrite" event of registers for the mechanism of registering objects on nodes.
//
// Parameters:
//  ExchangePlanName - String - a name of exchange plan where objects are registered.
//  Source - RegisterRecordSet - an event source.
//  Cancel - Boolean - a flag of cancelling the handler.
//  Replacing      - Boolean - a flag showing whether the existing record set is replaced.
// 
Procedure ObjectsRegistrationMechanismBeforeWriteRegister(ExchangePlanName, Source, Cancel, Overwrite) Export
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		
		Module = Common.CommonModule("PersonalDataProtection");
		If Module.SkipObjectRegistration(ExchangePlanName, Source) Then
			Return;
		EndIf;
		
	EndIf;
	
	AdditionalParameters = New Structure("IsRegister,Overwrite", True, Overwrite);
	RegisterObjectChange(ExchangePlanName, Source, Cancel, AdditionalParameters);
	
EndProcedure

// The handler procedure for "BeforeWrite" event of constant for the mechanism of registering objects on nodes.
//
// Parameters:
//  ExchangePlanName - String - a name of exchange plan where objects are registered.
//  Source - ConstantValueManager - an event source.
//  Cancel - Boolean - a flag of cancelling the handler.
// 
Procedure ObjectsRegistrationMechanismBeforeWriteConstant(ExchangePlanName, Source, Cancel) Export
	
	AdditionalParameters = New Structure("IsConstant", True);
	RegisterObjectChange(ExchangePlanName, Source, Cancel, AdditionalParameters);
	
EndProcedure

// The handler procedure for "BeforeDelete" event of reference data types for the mechanism of registering objects on nodes.
//
// Parameters:
//  ExchangePlanName - String - a name of exchange plan where objects are registered.
//  Source       - CatalogObject, DocumentObject, ChartOfCharacteristicTypesObject - an event source.
//  Cancel - Boolean - a flag of cancelling the handler.
// 
Procedure ObjectsRegistrationMechanismBeforeDelete(ExchangePlanName, Source, Cancel) Export
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		
		Module = Common.CommonModule("PersonalDataProtection");
		If Module.SkipObjectRegistration(ExchangePlanName, Source) Then
			Return;
		EndIf;
		
	EndIf;
	
	AdditionalParameters = New Structure("IsObjectDeletion", True);
	RegisterObjectChange(ExchangePlanName, Source, Cancel, AdditionalParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions to use in handlers of registration rule events.

// The procedure complements the list of recipient nodes of the object with the values passed.
//
// Parameters:
//  Object - CatalogObject, DocumentObject, and so on - an object for which the registration rule must be executed.
//  Nodes - Array - nodes of the exchange plan to be added to the list of nodes receiving the object.
//
Procedure SupplementRecipients(Object, Nodes) Export
	
	For Each Item In Nodes Do
		
		Try
			Object.DataExchange.Recipients.Add(Item);
		Except
			ExchangePlanName = Item.Metadata().Name;
			MetadataObject = Object.Metadata();
			MessageString = NStr("ru = 'Для состава плана обмена [ExchangePlanName] не указана регистрация объекта [FullName]'; en = 'The [FullName] object registration is not specified for the [ExchangePlanName] exchange plan content'; pl = 'Dla składu planu wymiany [FullName] nie jest wskazana rejestracja obiektu [ExchangePlanName]';es_ES = 'Para el contenido del plan de cambio [FullName]no se ha indicado el registro del objeto [ExchangePlanName]';es_CO = 'Para el contenido del plan de cambio [FullName]no se ha indicado el registro del objeto [ExchangePlanName]';tr = 'Alışveriş planı içeriği [ExchangePlanName] için nesne [FullName] kaydı belirtilmemiş';it = 'La registrazione dell''oggetto [FullName] non è indicata per il contenuto del piano di scambio [ExchangePlanName]';de = 'Für die Zusammensetzung des Austauschplans [FullName] ist die Registrierung des Objekts [ExchangePlanName] nicht angegeben'");
			MessageString = StrReplace(MessageString, "[ExchangePlanName]", ExchangePlanName);
			MessageString = StrReplace(MessageString, "[FullName]",      MetadataObject.FullName());
			Raise MessageString;
		EndTry;
		
	EndDo;
	
EndProcedure

// Procedure subtracts passed values from the list of nodes receiving the object.
//
// Parameters:
//  Object - CatalogObject, DocumentObject, and so on - an object for which the registration rule must be executed.
//  Nodes - Array - nodes of the exchange plan to be subtracted from the list of nodes receiving the object.
// 
Procedure ReduceRecipients(Object, Nodes) Export
	
	Recipients = ReduceArray(Object.DataExchange.Recipients, Nodes);
	
	// Clearing the recipient list and filling it over again.
	Object.DataExchange.Recipients.Clear();
	
	// Adding nodes for the object registration.
	SupplementRecipients(Object, Recipients);
	
EndProcedure

// Generates an array of recipient nodes for the object of the specified exchange plan and registers 
// an object in these nodes.
//
// Parameters:
//  Object         - Arbitrary - CatalogObject, DocumentObject, and so on - an object to be 
//                   registered in nodes.
//  ExchangePlanName - String - an exchange plan name as it is specified in Designer.
//  Sender - ExchangePlanRef - an exchange plan node from which the exchange message is received.
//                    Objects are not registered in this node if it is set.
// 
Procedure ExecuteRegistrationRulesForObject(Object, ExchangePlanName, Sender = Undefined) Export
	
	Recipients = GetRecipients(Object, ExchangePlanName);
	
	CommonClientServer.DeleteValueFromArray(Recipients, Sender);
	
	If Recipients.Count() > 0 Then
		
		ExchangePlans.RecordChanges(Recipients, Object);
		
	EndIf;
	
EndProcedure

// Subtracts one array of elements from another. Returns the result of subtraction.
//
// Parameters:
//	Array - Array - a source array.
//	SubtractionArray - Array - an array subtracted from the source array.
//
// Returns:
//  Array - a subtraction result.
//
Function ReduceArray(Array, SubtractionArray) Export
	
	Return CommonClientServer.ArraysDifference(Array, SubtractionArray);
	
EndFunction

// The function returns a list of all nodes of the specified exchange plan except for the predefined node.
//
// Parameters:
//  ExchangePlanName - String - a name of the exchange plan as it is set in Designer for which the 
//                            list of nodes is being retrieved.
//
// Returns:
//   Array - a list of all nodes of the specified exchange plan.
//
Function AllExchangePlanNodes(ExchangePlanName) Export
	
	#If ExternalConnection OR ThickClientOrdinaryApplication Then
		
		Return DataExchangeServerCall.AllExchangePlanNodes(ExchangePlanName);
		
	#Else
		
		SetPrivilegedMode(True);
		Return DataExchangeServer.ExchangePlanNodes(ExchangePlanName);
		
	#EndIf
	
EndFunction

// Function generates an array of recipient nodes for the object of the specified exchange plan.
//
// Parameters:
//  Object         - Arbitrary - CatalogObject, DocumentObject, and so on - an object whose 
//                   recipient node list will be returned.
//  ExchangePlanName - String - an exchange plan name as it is specified in Designer.
// 
// Returns:
//  NodeArrayResult - Array - an array of recipient nodes for the object.
//
Function GetRecipients(Object, ExchangePlanName) Export
	
	NodeArrayResult = New Array;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("MetadataObject", Object.Metadata());
	AdditionalParameters.Insert("IsRegister", Common.IsRegister(AdditionalParameters.MetadataObject));
	ExecuteObjectsRegistrationRulesForExchangePlan(NodeArrayResult, Object, ExchangePlanName, AdditionalParameters);
	
	Return NodeArrayResult;
	
EndFunction

// Determines whether automatic registration of a metadata object in exchange plan is allowed.
//
// Parameters:
//   MetadataObject - MetadataObject - an object whose automatic registration flag will be checked.
//   ExchangePlanName - String - an exchange plan name as it is set in Designer. The name of the 
//                          exchange plan that contains the metadata object.
//
// Returns:
//   Boolean - a flag showing whether automatic registration is available in the exchange plan.
//           * True if metadata object automatic registration is allowed in the exchange plan.
//           * False if metadata object auto registration is denied in the exchange plan or the 
//                      exchange plan does not include the metadata object.
//
Function AutoRegistrationAllowed(MetadataObject, ExchangePlanName) Export
	
	Return DataExchangeCached.AutoRegistrationAllowed(ExchangePlanName, MetadataObject.FullName());
	
EndFunction

// Checks whether data item import is restricted.
//  Preliminary setup of the DataForPeriodClosingCheck procedure
// from the PeriodClosingDatesOverridable module is required.
//
// Parameters:
//  Data     - Arbitrary - CatalogObject.<Name>,
//                        DocumentObject.<Name>,
//                        ChartOfCharacteristicsTypesObject.<Name>,
//                        ChartOfAccountsObject.<Name>,
//                        ChartOfCalculationTypesObject.<Name>,
//                        BusinessProcessObject.<Name>,
//                        TaskObject.<Name>,
//                        ExchangePlanObject.<Name>,
//                        ObjectDeletion - a data object.
//                        InformationRegisterRecordSet.<Name>,
//                        AccumulationRegisterRecordSet.<Name>,
//                        AccountingRegisterRecordSet.<Name>,
//                        CalculationRegisterRecordSet.<Name> - record set.
//
//  ExchangePlanNode     - ExchangePlansObject - a node to be checked.
//                        
//
// Returns:
//  Boolean - if True, data import is restricted.
//
Function ImportRestricted(Data, Val ExchangePlanNode) Export
	
	If Data.AdditionalProperties.Property("DataImportRestrictionFound") Then
		Return True;
	EndIf;
	
	GetItem = DataItemReceive.Auto;
	CheckImportRestrictionByDate(Data, GetItem, ExchangePlanNode);
	
	Return GetItem = DataItemReceive.Ignore;
	
EndFunction

#EndRegion

#Region Internal

// The procedure is designed to determine the kind of sending the exported data item.
// The procedure is called from the following exchange plan handlers: OnSendDataToMaster() and OnSendDataToSlave().
//
// Parameters:
//  DataItem, ItemSend - see the parameter description in the Syntax Assistant for methods 
//                                    OnSendDataToMaster() and OnSendDataToSlave().
//
Procedure OnSendDataToRecipient(DataItem,
										ItemSend,
										Val InitialImageCreation = False,
										Val Recipient = Undefined,
										Val Analysis = True) Export
	
	If Recipient = Undefined Then
		
		//
		
	ElsIf ItemSend = DataItemSend.Delete
		OR ItemSend = DataItemSend.Ignore Then
		
		// No overriding for standard processing.
		
	ElsIf DataExchangeCached.IsSSLDataExchangeNode(Recipient.Ref) Then
		
		OnSendData(DataItem, ItemSend, Recipient.Ref, InitialImageCreation, Analysis);
		
	EndIf;
	
	If Analysis Then
		Return;
	EndIf;
	
	// Recording exported predefined data (only for DIB.
	If Not InitialImageCreation
		AND ItemSend <> DataItemSend.Ignore
		AND DataExchangeCached.IsDistributedInfobaseNode(Recipient.Ref)
		AND TypeOf(DataItem) <> Type("ObjectDeletion") Then
		
		MetadataObject = DataItem.Metadata();
		
		If Common.IsCatalog(MetadataObject)
			OR Common.IsChartOfCharacteristicTypes(MetadataObject)
			OR Common.IsChartOfAccounts(MetadataObject)
			OR Common.IsChartOfCalculationTypes(MetadataObject) Then
			
			If DataItem.Predefined Then
				
				DataExchangeServerCall.SupplementPriorityExchangeData(DataItem.Ref);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Handler for the event of the same name that occurs during data exchange in a distributed infobase.
// 
//
// Parameters:
// see the OnReceiveDataFromMaster() event handler details in the syntax assistant.
// 
Procedure OnReceiveDataFromMasterInBeginning(DataItem, GetItem, SendBack, Sender) Export
	
	If DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
			"ImportApplicationParameters") Then
		
		// If application parameters are imported, all data must be ignored
		GetItem = DataItemReceive.Ignore;
		
	Else
		
		If TypeOf(DataItem) = Type("ConstantValueManager.DataForDeferredUpdate") Then
			GetItem = DataItemReceive.Ignore;
			DataExchangeServer.ProcessDataToUpdateInSubordinateNode(DataItem);
		EndIf;
		
	EndIf;
	
EndProcedure

// Detects import restriction and period-end closing conflicts.
// The procedure is called from the OnReceiveDataFromMaster exchange plan handler.
//
// Parameters:
// see the OnReceiveDataFromMaster() event handler details in the syntax assistant.
// 
Procedure OnReceiveDataFromMasterInEnd(DataItem, GetItem, Val Sender) Export
	
	// Checking whether the data import is restricted (by restriction date).
	CheckImportRestrictionByDate(DataItem, GetItem, Sender);
	
	If GetItem = DataItemReceive.Ignore Then
		Return;
	EndIf;
	
	// Checking for data modification conflict.
	CheckDataModificationConflict(DataItem, GetItem, Sender, True);
	
EndProcedure

// Detects import restriction and period-end closing conflicts.
// The procedure is called from the OnReceiveDataFromSlave exchange plan handler.
//
// Parameters:
// see the OnReceiveDataFromSlave() event handler details in the Syntax Assistant.
// 
Procedure OnReceiveDataFromSlaveInEnd(DataItem, GetItem, Val Sender) Export
	
	// Checking whether the data import is restricted (by restriction date).
	CheckImportRestrictionByDate(DataItem, GetItem, Sender);
	
	If GetItem = DataItemReceive.Ignore Then
		Return;
	EndIf;
	
	// Checking for data modification conflict.
	CheckDataModificationConflict(DataItem, GetItem, Sender, False);
	
EndProcedure

// Registers a change for a single data item to send it to the destination node address.
// A data item can be registered if it matches object registration rule filters that are set in the 
// destination node properties.
// Data items that are imported when needed are registered unconditionally.
// ObjectDeletion is registered unconditionally.
//
// Parameters:
//     Sender - ExchangePlanRef - an exchange plan node for which data changes registration is 
//                                              executed.
//     Data     - <Data>, ObjectDeletion - an object that represents data stored in the infobase, 
//                  such as a document, a catalog item, an account from the chart of accounts, a 
//                                              constant record manager, a register record set, and so on.
//     CheckExportPermission - Boolean - an optional flag. If it is set to False, an additional 
//                                              check for the compliance to the common node settings 
//                                              is not performed during the registration.
//
Procedure RecordDataChanges(Val Recipient, Val Data, Val CheckExportPermission=True) Export
	
	If TypeOf(Data) = Type("ObjectDeletion") Then
		// Registering object deletion unconditionally.
		ExchangePlans.RecordChanges(Recipient, Data);
		
	Else
		ObjectExportMode = DataExchangeCached.ObjectExportMode(Data.Metadata().FullName(), Recipient);
		
		If ObjectExportMode = Enums.ExchangeObjectExportModes.ExportIfNecessary Then
			
			If Common.RefTypeValue(Data) Then
				IsNewObject = Data.IsEmpty();
			Else
				IsNewObject = Data.IsNew(); 
			EndIf;
			
			If IsNewObject Then
				Raise NStr("ru = 'Регистрация незаписанных объектов, выгружаемых по ссылке, не поддерживается.'; en = 'Objects that are not written and are exported by reference cannot be registered.'; pl = 'Rejestracja niezapisanych obiektów, które można eksportować przez link, nie jest obsługiwana.';es_ES = 'Registro de los objetos no grabados que pueden exportarse por referencia, no se admite.';es_CO = 'Registro de los objetos no grabados que pueden exportarse por referencia, no se admite.';tr = 'Referans ile dışa aktarılabilecek yazılmayan nesnelerin kaydı desteklenmez.';it = 'Oggetti non scritti e esportati per riferimento non possono essere registrati.';de = 'Die Registrierung von nicht geschriebenen Objekten, die per Referenz exportiert werden können, wird nicht unterstützt.'");
			EndIf;
			
			BeginTransaction();
			Try
				// Registering data for the destination node.
				ExchangePlans.RecordChanges(Recipient, Data);
				
				// If an object is exported by its reference, adding information about this object to the allowed objects filter.
				// This ensures that the data items pass the filter, so that they can be exported to the exchange message.
				If DataExchangeServer.IsXDTOExchangePlan(Recipient) Then
					DataExchangeXDTOServer.AddObjectToAllowedObjectsFilter(Data.Ref, Recipient);
				Else
					InformationRegisters.InfobaseObjectsMaps.AddObjectToAllowedObjectsFilter(Data.Ref, Recipient);
				EndIf;
				
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
			
		ElsIf Not CheckExportPermission Then
			// Registering data unconditionally
			ExchangePlans.RecordChanges(Recipient, Data);
			
		ElsIf ObjectExportAllowed(Recipient, Data) Then
			// Registering the object if it matches common restrictions.
			ExchangePlans.RecordChanges(Recipient, Data);
			
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

#Region EventSubscriptionHandler

Procedure RegisterDataMigrationRestrictionFiltersChanges(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Source.IsNew() Then
		Return;
	ElsIf Source.AdditionalProperties.Property("GettingExchangeMessage") Then
		Return; // Writing the node when receiving the exchange message (universal data exchange).
	ElsIf Not DataExchangeCached.IsSSLDataExchangeNode(Source.Ref) Then
		Return;
	ElsIf Source.ThisNode Then
		Return;
	EndIf;
	
	SourceRef = Common.ObjectAttributesValues(Source.Ref, "SentNo, ReceivedNo");
	
	If SourceRef.SentNo <> Source.SentNo Then
		Return; // Writing the node when sending the exchange message.
	ElsIf SourceRef.ReceivedNo <> Source.ReceivedNo Then
		Return; // Writing the node when receiving the exchange message.
	EndIf;
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(Source.Ref);
	
	// Gets attributes of reference type that are presumably used as filers of registration rules filters.
	ReferenceTypeAttributeTable = ReferenceTypeObjectAttributes(Source, ExchangePlanName);
	
	// Checking whether the node was modified by attributes.
	ObjectIsModified = ObjectModifiedByAttributes(Source, ReferenceTypeAttributeTable);
	
	If ObjectIsModified Then
		
		Source.AdditionalProperties.Insert("NodeAttributesTable", ReferenceTypeAttributeTable);
		
	EndIf;
	
EndProcedure

Procedure CheckDataMigrationRestrictionFilterChangesOnWrite(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Not DataExchangeCached.IsSSLDataExchangeNode(Source.Ref) Then
		Return;
	EndIf;
	
	RegisteredForExportObjects = Undefined;
	If Source.AdditionalProperties.Property("RegisteredForExportObjects", RegisteredForExportObjects) Then
		
		DataExchangeServerCall.UpdateObjectsRegistrationMechanismCache();
		
		For Each Object In RegisteredForExportObjects Do
			
			If Not ObjectExportAllowed(Source.Ref, Object) Then
				
				ExchangePlans.DeleteChangeRecords(Source.Ref, Object);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	ReferenceTypeAttributeTable = Undefined;
	If Source.AdditionalProperties.Property("NodeAttributesTable", ReferenceTypeAttributeTable) Then
		
		// Registering selected objects of reference type on the current node using no object registration rules.
		RecordReferenceTypeObjectChangesByNodeProperties(Source, ReferenceTypeAttributeTable);
		
		// Updating cached values of the mechanism.
		DataExchangeServerCall.ResetObjectsRegistrationMechanismCache();
		
	EndIf;
	
EndProcedure

Procedure EnableExchangePlanUsage(Source, Cancel) Export
	
	// There is no DataExchange.Load property value verification, because the code below implements the 
	// logic that must be executed, including when this property is set to True (on the side of the code 
	// that records to this exchange plan).
	
	If Source.IsNew() AND DataExchangeCached.IsSeparatedSSLDataExchangeNode(Source.Ref) Then
		
		// The open session cache became obsolete for the object registration mechanism.
		DataExchangeServerCall.ResetObjectsRegistrationMechanismCache();
		
	EndIf;
	
EndProcedure

Procedure DisableExchangePlanUsage(Source, Cancel) Export
	
	// There is no DataExchange.Load property value verification because the code below implements the 
	// logic that must be executed, including when this property is set to True (on the side of the code 
	// that attempts to delete this exchange plan node).
	
	If DataExchangeCached.IsSeparatedSSLDataExchangeNode(Source.Ref) Then
		
		// The open session cache became obsolete for the object registration mechanism.
		DataExchangeServerCall.ResetObjectsRegistrationMechanismCache();
		
	EndIf;
	
EndProcedure

Procedure CheckDataExchangeSettingsEditability(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Not DataExchangeCached.IsSSLDataExchangeNode(Source.Ref) Then
		Return;
	EndIf;
	
	If  Not Source.AdditionalProperties.Property("GettingExchangeMessage")
		AND Not Source.IsNew()
		AND Not Source.ThisNode
		AND DataDifferent(Source, Source.Ref.GetObject(),, "SentNo, ReceivedNo, DeletionMark, Code, Description")
		AND DataExchangeServerCall.ChangesRegistered(Source.Ref) Then
		
		SaveAvailableForExportObjects(Source);
		
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		SessionWithoutSeparators = ModuleSaaS.SessionWithoutSeparators();
	Else
		SessionWithoutSeparators = True;
	EndIf;
	
	// Code and description of a node cannot be changed in SaaS.
	If Common.DataSeparationEnabled()
		AND NOT SessionWithoutSeparators
		AND Not Source.IsNew()
		AND DataDifferent(Source, Source.Ref.GetObject(), "Code, Description") Then
		
		Raise NStr("ru = 'Изменение наименования и кода синхронизации данных недопустимо.'; en = 'The synchronization description and code cannot be changed.'; pl = 'Zmiana nazwy i kodu synchronizacji danych jest niedopuszczalna.';es_ES = 'No se admite cambiar el nombre y el código de sincronización de datos.';es_CO = 'No se admite cambiar el nombre y el código de sincronización de datos.';tr = 'Veri eşleştirmenin adı ve kodu değiştirilemez.';it = 'Descrizione e codice di sincronizzazione non possono essere modificati.';de = 'Das Ändern von Name und Code der Datensynchronisation ist nicht erlaubt.'");
		
	EndIf;
	
EndProcedure

Procedure DisableDataAutomaticSynchronizationOnWrite(Source, Cancel, Overwrite) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("CloudTechnology.SaaS.DataExchangeSaaS") Then
		ModuleStandaloneMode = Common.CommonModule("StandaloneMode");
		ModuleStandaloneMode.DisableAutoDataSyncronizationWithWebApplication(Source);
	EndIf;
	
EndProcedure

Procedure SaveAvailableForExportObjects(ObjectNode)
	
	SetPrivilegedMode(True);
	
	RegisteredData = New Array;
	ExchangePlanComposition = ObjectNode.Metadata().Content;
	
	Query = New Query;
	QueryText =
	"SELECT *
	|FROM
	|	[Table].Changes AS ChangesTable
	|WHERE
	|	ChangesTable.Node = &Node";
	Query.SetParameter("Node", ObjectNode.Ref);
	
	For Each CompositionItem In ExchangePlanComposition Do
		
		If CompositionItem.AutoRecord = AutoChangeRecord.Allow Then
			Continue;
		EndIf;
		
		ItemMetadata = CompositionItem.Metadata;
		FullMetadataObjectName = ItemMetadata.FullName();
		
		Query.Text = StrReplace(QueryText, "[Table]", FullMetadataObjectName);
		
		Result = Query.Execute();
		
		If Not Result.IsEmpty() Then
			
			RegisteredDataOfSingleType = Result.Unload();
			
			If Common.IsRefTypeObject(ItemMetadata) Then
				
				For Each Row In RegisteredDataOfSingleType Do
					
					If Common.RefExists(Row.Ref) Then
						
						LinkObject = Row.Ref.GetObject();
						
						If ObjectExportAllowed(ObjectNode.Ref, LinkObject) Then
							RegisteredData.Add(LinkObject);
						EndIf;
						
					EndIf;
					
				EndDo;
				
			ElsIf Common.IsConstant(ItemMetadata) Then
				
				ConstantValueManager = Constants[ItemMetadata.Name].CreateValueManager();
				If ObjectExportAllowed(ObjectNode.Ref, ConstantValueManager) Then
					RegisteredData.Add(ConstantValueManager);
				EndIf;
				
			Else // Processing a register or a sequence.
				
				For Each Row In RegisteredDataOfSingleType Do
					
					RecordSet = Common.ObjectManagerByFullName(FullMetadataObjectName).CreateRecordSet();
					
					For Each FilterItem In RecordSet.Filter Do
						
						If RegisteredDataOfSingleType.Columns.Find(FilterItem.Name) <> Undefined Then
							
							RecordSet.Filter[FilterItem.Name].Set(Row[FilterItem.Name]);
							
						EndIf;
						
					EndDo;
					
					RecordSet.Read();
					
					If ObjectExportAllowed(ObjectNode.Ref, RecordSet) Then
						RegisteredData.Add(RecordSet);
					EndIf;
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	ObjectNode.AdditionalProperties.Insert("RegisteredForExportObjects", RegisteredData);
	
EndProcedure

Function ObjectExportAllowed(ExchangeNode, Object)
	
	If Common.RefTypeValue(Object) Then
		Return DataExchangeServer.RefExportAllowed(ExchangeNode, Object);
	EndIf;
	
	Sending = DataItemSend.Auto;
	OnSendDataToRecipient(Object, Sending, , ExchangeNode);
	Return Sending = DataItemSend.Auto;
EndFunction

Procedure CancelSendNodeDataInDistributedInfobase(Source, DataItem, Ignore) Export
	
	If Not DataExchangeCached.IsSSLDataExchangeNode(Source.Ref) Then
		Return;
	EndIf;
	
	If Not DataItem.ThisNode Then
		If Common.DataSeparationEnabled() Then
			// Upon sending node data in separated mode, reset separators.
			// Otherwise, when importing into a shared SWP, an attempt will be made to write the node to the 
			// uninitialized data area with the specified separator value, which will result in error of the absence of a node in it with the “ThisNode” flag.
			ModuleSaaS = Common.CommonModule("SaaS");
			If ModuleSaaS.IsSeparatedMetadataObject(Source.Metadata().FullName(),
				ModuleSaaS.MainDataSeparator()) Then
				DataItem[ModuleSaaS.MainDataSeparator()] = 0;
			EndIf;
			If ModuleSaaS.IsSeparatedMetadataObject(Source.Metadata().FullName(),
				ModuleSaaS.AuxiliaryDataSeparator()) Then
				DataItem[ModuleSaaS.AuxiliaryDataSeparator()] = 0;
			EndIf;
		EndIf;
		
		Return;
	EndIf;
	
	Ignore = True;
	
EndProcedure

Procedure RegisterCommonNodesDataChanges(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Source.IsNew() Then
		Return;
	ElsIf Source.AdditionalProperties.Property("GettingExchangeMessage") Then
		Return; // Writing the node when receiving the exchange message (universal data exchange).
	ElsIf Not DataExchangeCached.IsSeparatedSSLDataExchangeNode(Source.Ref) Then
		Return;
	ElsIf Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	CommonNodeData = DataExchangeCached.CommonNodeData(Source.Ref);
	
	If IsBlankString(CommonNodeData) Then
		Return;
	EndIf;
	
	If Source.ThisNode Then
		Return;
	EndIf;
	
	If DataDifferent(Source, Source.Ref.GetObject(), CommonNodeData) Then
		
		InformationRegisters.CommonNodeDataChanges.RecordChanges(Source.Ref);
		
	EndIf;
	
EndProcedure

Procedure ClearRefsToInfobaseNode(Source, Cancel) Export
	
	// There is no DataExchange.Load property value verification because the code below implements the 
	// logic that must be executed, including when this property is set to True (on the side of the code 
	// that attempts to delete this exchange plan node).
	
	If Not DataExchangeCached.IsSSLDataExchangeNode(Source.Ref) Then
		Return;
	EndIf;
	
	InformationRegisters.DataExchangeResults.ClearRefsToInfobaseNode(Source.Ref);
	
	Catalogs.DataExchangeScenarios.ClearRefsToInfobaseNode(Source.Ref);
	
EndProcedure

#EndRegion

#Region ObjectsRegistrationMechanism

// Determines the list of exchange plan destination nodes where the object must be registered for 
// future exporting.
//
// First, using the mechanism of selective object registration (SOR), the procedure determines the 
// exchange plans where the object must be registered.
// Then, using the object registration mechanism (ORR, registration rules), the procedure determines 
// nodes of each exchange plan for which the object must be registered.
//
// Parameters:
//  ExchangePlanName - String - a name of exchange plan where objects are registered.
//  Object - Arbitrary - data to change: an object, a record set, a constant, or object deletion information.
//  Cancel - Boolean- a flag showing whether an error occurred during the object registration for nodes:
//    If errors occur during the object registration, this flag is set to True.
//  AdditionalParameters - Structure - additional information on data to change:
//    * IsRegister - Boolean - True means that the register is being processed.
//        Optional, the default value is False.
//    * IsObjectDeletion - Boolean - True means that the object deletion is being processed.
//        Optional, the default value is False.
//    * IsConstant - Boolean - True means that the constant is being processed.
//        Optional, the default value is False.
//    * WriteMode - see the Syntax Assistant for DocumentWriteMode - a document write mode (for documents only).
//        Optional, the default value is Undefined.
//    * Replacing - Boolean - a register write mode (for registers only).
//        Optional, the default value is Undefined.
//
Procedure RegisterObjectChange(ExchangePlanName, Object, Cancel, AdditionalParameters = Undefined)
	
	// There is no DataExchange.Load property value verification because the code below implements the 
	// logic of registering changes for an exchange plan node that must be executed, including when this 
	// property is set to True (on the side of the code that attempts to change/delete data).
	
	OptionalParameters = New Structure;
	OptionalParameters.Insert("IsRegister", False);
	OptionalParameters.Insert("IsObjectDeletion", False);
	OptionalParameters.Insert("IsConstant", False);
	OptionalParameters.Insert("WriteMode", Undefined);
	OptionalParameters.Insert("Overwrite", Undefined);
	
	If AdditionalParameters <> Undefined Then
		FillPropertyValues(OptionalParameters, AdditionalParameters);
	EndIf;
	
	IsRegister = OptionalParameters.IsRegister;
	IsObjectDeletion = OptionalParameters.IsObjectDeletion;
	IsConstant = OptionalParameters.IsConstant;
	WriteMode = OptionalParameters.WriteMode;
	Overwrite = OptionalParameters.Overwrite;
	
	Try
		
		SetPrivilegedMode(True);
		
		// Updating cached object registration values.
		DataExchangeServerCall.CheckObjectsRegistrationMechanismCache();
		
		If Object.AdditionalProperties.Property("RegisterAtExchangePlanNodesOnUpdateIB") Then
			// The RegisterAtExchangePlanNodesOnUpdateIB parameter shows whether infobase data update is in progress.
			DisableRegistration = True;
			If Object.AdditionalProperties.RegisterAtExchangePlanNodesOnUpdateIB = Undefined Then
				// Decision on whether it is necessary to register data for exchange is made automatically based on 
				// related information.
				If Not (IsRegister Or IsObjectDeletion Or IsConstant) AND Object.IsNew() Then
					// New reference objects must always be registered prior to exchange.
					DisableRegistration = False;
				ElsIf ValueIsFilled(SessionParameters.UpdateHandlerParameters) Then
					ExchangePlanPurpose = DataExchangeCached.ExchangePlanPurpose(ExchangePlanName);
					If ExchangePlanPurpose = "DIBWithFilter" Then
						// Registration can be enabled only when parallel update is used.
						// If this functionality is used, registration is available if the handler is executed in the subordinate DIB node.
						UpdateHandlerParameters = SessionParameters.UpdateHandlerParameters;
						If UpdateHandlerParameters.DeferredHandlerExecutionMode = "Parallel" Then
							DisableRegistration = UpdateHandlerParameters.RunAlsoInSubordinateDIBNodeWithFilters;
						EndIf;
					ElsIf ExchangePlanPurpose = "DIB" Then
						DisableRegistration = Not SessionParameters.UpdateHandlerParameters.ExecuteInMasterNodeOnly;
					EndIf;
				EndIf;
			ElsIf Object.AdditionalProperties.RegisterAtExchangePlanNodesOnUpdateIB Then
				// The developer decided that this data must be registered for exchange.
				DisableRegistration = False;
			EndIf;
			
			If DisableRegistration Then
				Return;
			EndIf;
		ElsIf Object.AdditionalProperties.Property("DisableObjectChangeRecordMechanism") Then
			// Object registration is forcibly disabled.
			Return;
		EndIf;
		
		MetadataObject = Object.Metadata();
		
		If Common.DataSeparationEnabled() Then
			
			If Not SeparatedExchangePlan(ExchangePlanName) Then
				Raise NStr("ru = 'Регистрация изменений для неразделенных планов обмена не поддерживается.'; en = 'Change registration for shared exchange plans is not supported.'; pl = 'Rejestracja zmian w niepodzielnych planach wymiany nie jest obsługiwana.';es_ES = 'Registro de cambios para los planes de intercambio indivisos no se admite.';es_CO = 'Registro de cambios para los planes de intercambio indivisos no se admite.';tr = 'Bölünmemiş değişim planları için değişiklik kaydı desteklenmemektedir.';it = 'La registrazione delle modifiche per i piani di scambio condivisi non è supportata.';de = 'Die Änderung der Registrierung für ungeteilte Austauschpläne wird nicht unterstützt.'");
			EndIf;
			
			If Not DataExchangeCached.ExchangePlanUsedInSaaS(ExchangePlanName) Then
				Return;
			EndIf;
			
			If Common.SubsystemExists("StandardSubsystems.SaaS") Then
				ModuleSaaS = Common.CommonModule("SaaS");
				IsSeparatedData = ModuleSaaS.IsSeparatedMetadataObject(
					MetadataObject.FullName(), ModuleSaaS.MainDataSeparator());
			Else
				IsSeparatedData = False;
			EndIf;
			
			If Common.SeparatedDataUsageAvailable() Then
				
				If Common.SubsystemExists("StandardSubsystems.SaaS") Then
					ModuleSaaS = Common.CommonModule("SaaS");
					IsTogetherSeparatedData = ModuleSaaS.IsSeparatedMetadataObject(
						MetadataObject.FullName(), ModuleSaaS.AuxiliaryDataSeparator());
				Else
					IsTogetherSeparatedData = False;
				EndIf;
				
				If Not IsSeparatedData AND Not IsTogetherSeparatedData Then
					Raise NStr("ru = 'Регистрация изменений неразделенных данных в разделенном режиме.'; en = 'Registering changes of shared data in separated mode.'; pl = 'Rejestracja zmian danych, udostępnianych w trybie podziału.';es_ES = 'Registro de cambios de los datos compartidos en el modo de división.';es_CO = 'Registro de cambios de los datos compartidos en el modo de división.';tr = 'Bölünmüş modda paylaşılan verilerin kayıtlarını değiştirir.';it = 'Registrazione delle modifiche dei dati non condivisi in modalità condivisa.';de = 'Änderungen der Registrierung getrennter Daten im Split-Modus.'");
				EndIf;
				
			Else
				
				If IsSeparatedData Then
					Raise NStr("ru = 'Регистрация изменений разделенных данных в неразделенном режиме.'; en = 'Registering changes of separated data in the shared mode.'; pl = 'Rejestracja zmian rozdzielonych danych w trybie podziału.';es_ES = 'Registro de cambios de los datos separados en el modo de división.';es_CO = 'Registro de cambios de los datos separados en el modo de división.';tr = 'Bölünmüş modda ayrılmış verilerin kaydını değiştir.';it = 'Registrazione modifiche di dati separati in modalità condivisa.';de = 'Änderung der Registrierung getrennter Daten im Split-Modus.'");
				EndIf;
					
				// Registering shared data changes for all nodes of separated exchange plans in the shared mode.
				// 
				// The registration rule mechanism is not supported in the current mode.
				RegisterChangesForAllSeparatedExchangePlanNodes(ExchangePlanName, Object);
				Return;
				
			EndIf;
			
		EndIf;
		
		// Checking whether the object must be registered in the sender node.
		If Object.AdditionalProperties.Property("RecordObjectChangeAtSenderNode") Then
			Object.DataExchange.Sender = Undefined;
		EndIf;
		
		If Not DataExchangeServerCall.DataExchangeEnabled(ExchangePlanName, Object.DataExchange.Sender) Then
			Return;
		EndIf;
		
		// Skipping SOR if the object has been deleted physically.
		RecordObjectChangeToExport = IsRegister Or IsObjectDeletion Or IsConstant;
		
		ObjectIsModified = Object.AdditionalProperties.Property("DeferredWriting")
			Or Object.AdditionalProperties.Property("DeferredPosting")
			Or ObjectModifiedForExchangePlan(
				Object, MetadataObject, ExchangePlanName, WriteMode, RecordObjectChangeToExport);
		
		If Not ObjectIsModified Then
			
			If DataExchangeCached.AutoRegistrationAllowed(ExchangePlanName, MetadataObject.FullName()) Then
				
				// Deleting all nodes where the object was registered automatically from the recipient list if the 
				// object was not modified and it is registered automatically.
				ReduceRecipients(Object, AllExchangePlanNodes(ExchangePlanName));
				
			EndIf;
			
			// Skipping the registration in the node if the object has not been modified relative to the current 
			// exchange plan.
			Return;
			
		EndIf;
		
		If Not DataExchangeCached.AutoRegistrationAllowed(ExchangePlanName, MetadataObject.FullName()) Then
			
			NodeArrayResult = New Array;
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("MetadataObject", MetadataObject);
			AdditionalParameters.Insert("IsRegister", IsRegister);
			AdditionalParameters.Insert("IsObjectDeletion", IsObjectDeletion);
			AdditionalParameters.Insert("Overwrite", Overwrite);
			AdditionalParameters.Insert("WriteMode", WriteMode);
			
			CheckRef = ?(IsRegister OR IsConstant, False, Not Object.IsNew() AND Not IsObjectDeletion);
			AdditionalParameters.Insert("CheckRef", CheckRef);
			
			ExecuteObjectsRegistrationRulesForExchangePlan(NodeArrayResult, Object, ExchangePlanName, AdditionalParameters);
			
			If Common.SubsystemExists("CloudTechnology.SaaS.DataExchangeSaaS") Then
				ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
				ModuleDataExchangeSaaS.AfterGetRecipients(Object, NodeArrayResult, ExchangePlanName);
			EndIf;
			
			SupplementRecipients(Object, NodeArrayResult);
			
		EndIf;
		
	Except
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось зарегистрировать изменения на узлах плана обмена %1 по причине: %2'; en = 'Cannot register changes on the %1 exchange plan nodes due to: %2'; pl = 'Nie udało się zarejestrować zmiany na węzłach planu wymiany %1 z powodu: %2';es_ES = 'No se ha podido registrar el cambio en los nodos del plan de cambio %1 a causa de: %2';es_CO = 'No se ha podido registrar el cambio en los nodos del plan de cambio %1 a causa de: %2';tr = 'Alışverişi planı ünitelerinde %1aşağıdaki nedenle değişiklik kaydedilemedi: %2';it = 'Impossibile registrare le modifiche dei nodi di piano di scambio %1 a causa di: %2';de = 'Die Änderungen an den Austauschplanknoten %1 konnten aus diesem Grund nicht registriert werden: %2'"),
			ExchangePlanName,
			DetailErrorDescription(ErrorInfo()));
		
		WriteLogEvent(NStr("ru = 'Обмен данными.Правила регистрации объектов'; en = 'Data exchange.Object registration rules'; pl = 'Wymiana danych.Reguły rejestracji obiektu';es_ES = 'Intercambio de datos. Reglas del registro de objetos';es_CO = 'Intercambio de datos. Reglas del registro de objetos';tr = 'Veri değişimi. Nesnelerin kayıt kuralları';it = 'Scambio Dati.Regole di registrazione oggetto';de = 'Datenaustausch. Regeln für die Registrierung von Objekten'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, Metadata.ExchangePlans[ExchangePlanName], , ErrorDescription);
		
		Raise ErrorDescription;
	EndTry;
	
EndProcedure

Procedure RegisterChangesForAllSeparatedExchangePlanNodes(ExchangePlanName, Object)
	
	QueryText =
		"SELECT
		|	ExchangePlan.Ref AS Recipient
		|FROM
		|	ExchangePlan.[ExchangePlanName] AS ExchangePlan
		|WHERE
		|	ExchangePlan.RegisterChanges
		|	AND NOT ExchangePlan.DeletionMark";

	Query = New Query;
	Query.Text = StrReplace(QueryText, "[ExchangePlanName]", ExchangePlanName);
	Recipients = Query.Execute().Unload().UnloadColumn("Recipient");

	For Each Recipient In Recipients Do
		Object.DataExchange.Recipients.Add(Recipient);
	EndDo;
	
EndProcedure

#EndRegion

#Region SelectiveObjectRegistrationMechanism

Function ObjectModifiedForExchangePlan(Source, MetadataObject, ExchangePlanName, WriteMode, RecordObjectChangeToExport)
	
	Try
		ObjectIsModified = ObjectModifiedForExchangePlanTryExcept(Source, MetadataObject, ExchangePlanName, WriteMode, RecordObjectChangeToExport);
	Except
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Ошибка определения модифицированности объекта: %1'; en = 'Error determining whether the object has been modified: %1'; pl = 'Błąd podczas określenia modyfikacji obiektu: %1';es_ES = 'Ha ocurrido un error al determinar la modificación del objeto: %1';es_CO = 'Ha ocurrido un error al determinar la modificación del objeto: %1';tr = 'Nesnenin değiştirilmesini belirlerken bir hata oluştu: %1';it = 'Errore nel determinare se l''oggetto è stato modificato: %1';de = 'Beim Ermitteln der Modifikation eines Objekts ist ein Fehler aufgetreten: %1'"),
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return ObjectIsModified;
EndFunction

Function ObjectModifiedForExchangePlanTryExcept(Source, MetadataObject, ExchangePlanName, WriteMode, RecordObjectChangeToExport)
	
	If RecordObjectChangeToExport Or Source.IsNew() Or Source.DataExchange.Load Then
		// Changes of the following objects are always registered:
		// - register record sets;
		// - objects that were physically deleted;
		// - new objects,
		// - for objects written by data exchange.
		Return True;
		
	ElsIf WriteMode <> Undefined AND DocumentPostingChanged(Source, WriteMode) Then
		// If the Posted flag has been changed, the document is considered modified.
		Return True;
		
	EndIf;
	
	ObjectName = MetadataObject.FullName();
	
	RegistrationAttributesTable = DataExchangeCached.ObjectAttributesToRegister(ObjectName, ExchangePlanName);
	
	If RegistrationAttributesTable.Count() = 0 Then
		// If no SOR rules are set, considering that there is no SOR filter and the object is always modified.
		// The object is always modified.
		Return True;
	EndIf;
	
	For Each RegistrationAttributesTableRow In RegistrationAttributesTable Do
		
		HasObjectVersionChanges = GetObjectVersionChanges(Source, RegistrationAttributesTableRow);
		
		If HasObjectVersionChanges Then
			Return True;
		EndIf;
		
	EndDo;
	
	// The object has not been changed relative to registration details, the registration is not required. Registration on nodes is not required.
	Return False;
EndFunction

Function ObjectModifiedByAttributes(Source, ReferenceTypeAttributeTable)
	
	For Each TableRow In ReferenceTypeAttributeTable Do
		
		HasObjectVersionChanges = GetObjectVersionChanges(Source, TableRow);
		
		If HasObjectVersionChanges Then
			
			Return True;
			
		EndIf;
		
	EndDo;
	
	Return False;
EndFunction

Function GetObjectVersionChanges(Object, RegistrationAttributesTableRow)
	
	If IsBlankString(RegistrationAttributesTableRow.TabularSectionName) Then // object header attributes
		
		RegistrationAttributesTableObjectVersionBeforeChanges = HeaderRegistrationAttributesBeforeChange(Object, RegistrationAttributesTableRow);
		
		RegistrationAttributesTableObjectVersionAfterChange = HeaderRegistrationAttributesAfterChange(Object, RegistrationAttributesTableRow);
		
	Else // object tabular section attributes
		
		// Check that it is an object tabular section but not a register table.
		If Object.Metadata().TabularSections.Find(RegistrationAttributesTableRow.TabularSectionName) = Undefined Then
			Return False;
		EndIf;
		
		RegistrationAttributesTableObjectVersionBeforeChanges = TabularSectionRegistrationAttributesBeforeChange(Object, RegistrationAttributesTableRow);
		
		RegistrationAttributesTableObjectVersionAfterChange = TabularSectionRegistrationAttributesAfterChange(Object, RegistrationAttributesTableRow);
		
	EndIf;
	
	Return Not RegistrationAttributesTablesSame(RegistrationAttributesTableObjectVersionBeforeChanges, RegistrationAttributesTableObjectVersionAfterChange, RegistrationAttributesTableRow);
	
EndFunction

Function HeaderRegistrationAttributesBeforeChange(Object, RegistrationAttributesTableRow)
	
	QueryText = "
	|SELECT " + RegistrationAttributesTableRow.RegistrationAttributes 
	  + " FROM " + RegistrationAttributesTableRow.ObjectName + " AS CurrentObject
	|WHERE
	|   CurrentObject.Ref = &Ref
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Object.Ref);
	
	Return Query.Execute().Unload();
	
EndFunction

Function TabularSectionRegistrationAttributesBeforeChange(Object, RegistrationAttributesTableRow)
	
	QueryText = "
	|SELECT "+ RegistrationAttributesTableRow.RegistrationAttributes
	+ " FROM " + RegistrationAttributesTableRow.ObjectName 
	+ "." + RegistrationAttributesTableRow.TabularSectionName + " AS CurrentObjectTabularSectionName
	|WHERE
	|   CurrentObjectTabularSectionName.Ref = &Ref
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Object.Ref);
	
	Return Query.Execute().Unload();
	
EndFunction

Function HeaderRegistrationAttributesAfterChange(Object, RegistrationAttributesTableRow)
	
	RegistrationAttributesStructure = RegistrationAttributesTableRow.RegistrationAttributesStructure;
	
	RegistrationAttributesTable = New ValueTable;
	
	For Each RegistrationAttribute In RegistrationAttributesStructure Do
		
		RegistrationAttributesTable.Columns.Add(RegistrationAttribute.Key);
		
	EndDo;
	
	TableRow = RegistrationAttributesTable.Add();
	
	For Each RegistrationAttribute In RegistrationAttributesStructure Do
		
		TableRow[RegistrationAttribute.Key] = Object[RegistrationAttribute.Key];
		
	EndDo;
	
	Return RegistrationAttributesTable;
EndFunction

Function TabularSectionRegistrationAttributesAfterChange(Object, RegistrationAttributesTableRow)
	
	RegistrationAttributesTable = Object[RegistrationAttributesTableRow.TabularSectionName].Unload(, RegistrationAttributesTableRow.RegistrationAttributes);
	
	Return RegistrationAttributesTable;
	
EndFunction

Function RegistrationAttributesTablesSame(Table1, Table2, RegistrationAttributesTableRow)
	
	AddColumnWithValueToTable(Table1, +1);
	AddColumnWithValueToTable(Table2, -1);
	
	ResultTable = Table1.Copy();
	
	CommonClientServer.SupplementTable(Table2, ResultTable);
	
	ResultTable.GroupBy(RegistrationAttributesTableRow.RegistrationAttributes, "ChangeRecordAttributeTableIterator");
	
	SameRowCount = ResultTable.FindRows(New Structure ("ChangeRecordAttributeTableIterator", 0)).Count();
	
	TableRowCount = ResultTable.Count();
	
	Return SameRowCount = TableRowCount;
	
EndFunction

Function DocumentPostingChanged(Source, WriteMode)
	
	Return (Source.Posted AND WriteMode = DocumentWriteMode.UndoPosting)
	 OR (NOT Source.Posted AND WriteMode = DocumentWriteMode.Posting);
	
EndFunction

Procedure AddColumnWithValueToTable(Table, IteratorValue)
	
	Table.Columns.Add("ChangeRecordAttributeTableIterator");
	
	Table.FillValues(IteratorValue, "ChangeRecordAttributeTableIterator");
	
EndProcedure

#EndRegion

#Region ObjectsRegistrationRules

// A wrapper procedure that executes the code for the main procedure in an attempt mode (see
//  ExecuteObjectsRegistrationRulesForExchangePlanAttemptException).
//
// Parameters:
//  NodeArrayResult - Array - an array of recipient nodes of the ExchangePlanName exchange plan that 
//   must be registered.
//  Object - Arbitrary - data to change: an object, a record set, a constant, or object deletion information.
//  ExchangePlanName - String - a name of exchange plan where objects are registered.
//  AdditionalParameters - Structure - additional information on data to change:
//    * MetadataObject - MetadataObject - a metadata object that matches the data being changed. IsRequired.
//    * IsRegister - Boolean - True means that the register is being processed.
//        Optional, the default value is False.
//    * IsObjectDeletion - Boolean - True means that the object deletion is being processed.
//        Optional, the default value is False.
//    * WriteMode - see the Syntax Assistant for DocumentWriteMode - a document write mode (for documents only).
//        Optional, the default value is Undefined.
//    * Replacing - Boolean - a register write mode (for registers only).
//        Optional, the default value is Undefined.
//    * CheckRef - Boolean - a flag showing whether it is necessary to consider a data version before this data change.
//        Optional, the default value is False.
//    * DataExported - Boolean - a parameter defines the registration rule execution context.
//        True - a registration rule is executed in the object export context.
//        False - a registration rule is executed in the context before writing the object.
//        Optional, the default value is False.
//
Procedure ExecuteObjectsRegistrationRulesForExchangePlan(NodeArrayResult, Object, ExchangePlanName, AdditionalParameters)

	MetadataObject = AdditionalParameters.MetadataObject;
	OptionalParameters = New Structure;
	OptionalParameters.Insert("IsRegister", False);
	OptionalParameters.Insert("IsObjectDeletion", False);
	OptionalParameters.Insert("WriteMode", Undefined);
	OptionalParameters.Insert("Overwrite", False);
	OptionalParameters.Insert("CheckRef", False);
	OptionalParameters.Insert("DataExported", False);
	FillPropertyValues(OptionalParameters, AdditionalParameters);
	
	AdditionalParameters = OptionalParameters;
	
	AdditionalParameters.Insert("MetadataObject", MetadataObject);
	
	Try
		ExecuteObjectsRegistrationRulesForExchangePlanAttemptException(NodeArrayResult, Object, ExchangePlanName, AdditionalParameters);
	Except
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Ошибка выполнения правил регистрации объектов для плана обмена %1.
			|Описание ошибки:
			|%2'; 
			|en = 'An error occurred when executing the object registration rules for exchange plan %1.
			|Error details:
			|%2'; 
			|pl = 'Błąd wykonania reguł rejestracji obiektów dla planu wymiany %1.
			|Opis błędu:
			|%2';
			|es_ES = 'Error al ejecutar las reglas de registro de objetos para el plan de cambio %1.
			|Descripción de error:
			|%2';
			|es_CO = 'Error al ejecutar las reglas de registro de objetos para el plan de cambio %1.
			|Descripción de error:
			|%2';
			|tr = 'Alışveriş planı için nesne kaydı yürütülürken%1 bir hata oluştu. 
			|Hata 
			|tanımlaması:%2';
			|it = 'Si è verificato un errore durante l''esecuzione delle regole di registrazione dell''oggetto per il piano di scambio %1.
			|Dettagli errore:
			|%2';
			|de = 'Fehler bei der Ausführung von Objektregistrierungsregeln für den Austauschplan %1.
			|Fehlerdetails:
			|%2'"),
			ExchangePlanName,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

// Determines the list of exchange plan destination nodes where the object must be registered for 
// future exporting.
//
// Parameters:
//  NodeArrayResult - Array - an array of recipient nodes of the ExchangePlanName exchange plan that 
//   must be registered.
//  Object - Arbitrary - data to change: an object, a record set, a constant, or object deletion information.
//  ExchangePlanName - String - a name of exchange plan where objects are registered.
//  AdditionalParameters - Structure - additional information on data to change:
//    * MetadataObject - MetadataObject - a metadata object that matches the data being changed. IsRequired.
//    * IsRegister - Boolean - True means that the register is being processed. IsRequired.
//    * IsObjectDeletion - Boolean - True means that the object deletion is being processed. IsRequired.
//    * WriteMode - see the Syntax Assistant for DocumentWriteMode - a document write mode (for documents only).
//                    IsRequired.
//    * Replacing - Boolean - a register write mode (for registers only). IsRequired.
//    * CheckRef - Boolean - a flag showing whether it is necessary to consider a data version before this data change.
//                                 IsRequired.
//    * DataExported - Boolean - a parameter defines the registration rule execution context.
//        True - a registration rule is executed in the object export context.
//        False - a registration rule is executed in the context before writing the object. IsRequired.
//
Procedure ExecuteObjectsRegistrationRulesForExchangePlanAttemptException(NodeArrayResult, Object, ExchangePlanName, AdditionalParameters)
	
	MetadataObject = AdditionalParameters.MetadataObject;
	IsRegister = AdditionalParameters.IsRegister;
	IsObjectDeletion = AdditionalParameters.IsObjectDeletion;
	WriteMode = AdditionalParameters.WriteMode;
	Overwrite = AdditionalParameters.Overwrite;
	CheckRef = AdditionalParameters.CheckRef;
	DataExported = AdditionalParameters.DataExported;
	
	ObjectRegistrationRules = New Array;
	
	SecurityProfileName = DataExchangeCached.SecurityProfileName(ExchangePlanName);
	If SecurityProfileName <> Undefined Then
		SetSafeMode(SecurityProfileName);
	EndIf;
	
	Rules = ObjectRegistrationRules(ExchangePlanName, MetadataObject.FullName());
	
	For Each Rule In Rules Do
		
		ObjectRegistrationRules.Add(RegistrationRuleAsStructure(Rule, Rules.Columns));
		
	EndDo;
	
	If ObjectRegistrationRules.Count() = 0 Then // Registration rules are not set.
		
		// If ORR are not specified and automatic registration is disabled, then registering the object in 
		// all exchange plan nodes except the predefined one.
		Recipients = AllExchangePlanNodes(ExchangePlanName);
		
		CommonClientServer.SupplementArray(NodeArrayResult, Recipients, True);
		
	Else // Executing registration rules sequentially.
		
		If IsRegister Then // for the register
			
			For Each ORR In ObjectRegistrationRules Do
				
				// DETERMINING THE RECIPIENTS WHOSE EXPORT MODE IS "BY CONDITION"
				
				GetRecipientsByConditionForRecordSet(NodeArrayResult, ORR, Object, MetadataObject, ExchangePlanName, Overwrite, DataExported);
				
				If ValueIsFilled(ORR.FlagAttributeName) Then
					
					// DETERMINING THE RECIPIENTS WHOSE EXPORT MODE IS "ALWAYS"
					
					#If ExternalConnection OR ThickClientOrdinaryApplication Then
						
						Recipients = DataExchangeServerCall.NodesForRegistrationByExportAlwaysCondition(ExchangePlanName, ORR.FlagAttributeName);
						
					#Else
						
						SetPrivilegedMode(True);
						Recipients = NodesForRegistrationByExportAlwaysCondition(ExchangePlanName, ORR.FlagAttributeName);
						SetPrivilegedMode(False);
						
					#EndIf
					
					CommonClientServer.SupplementArray(NodeArrayResult, Recipients, True);
					
					// DETERMINING THE RECIPIENTS WHOSE EXPORT MODE IS "IF NECESSARY"
					// There is no point in the "If necessary" registration execution for record sets.
					
				EndIf;
				
			EndDo;
			
		Else // for the reference type
			
			For Each ORR In ObjectRegistrationRules Do
				
				// DETERMINING THE RECIPIENTS WHOSE EXPORT MODE IS "BY CONDITION"
				
				GetRecipientsByCondition(NodeArrayResult, ORR, Object, ExchangePlanName, AdditionalParameters);
				
				If ValueIsFilled(ORR.FlagAttributeName) Then
					
					// DETERMINING THE RECIPIENTS WHOSE EXPORT MODE IS "ALWAYS"
					
					#If ExternalConnection OR ThickClientOrdinaryApplication Then
						
						Recipients = DataExchangeServerCall.NodesForRegistrationByExportAlwaysCondition(ExchangePlanName, ORR.FlagAttributeName);
						
					#Else
						
						SetPrivilegedMode(True);
						Recipients = NodesForRegistrationByExportAlwaysCondition(ExchangePlanName, ORR.FlagAttributeName);
						SetPrivilegedMode(False);
						
					#EndIf
					
					CommonClientServer.SupplementArray(NodeArrayResult, Recipients, True);
					
					// DETERMINING THE RECIPIENTS WHOSE EXPORT MODE IS "IF NECESSARY"
					
					If Not Object.IsNew() Then
						
						#If ExternalConnection OR ThickClientOrdinaryApplication Then
							
							Recipients = DataExchangeServerCall.NodesForRegistrationByExportIfNecessaryCondition(Object.Ref, ExchangePlanName, ORR.FlagAttributeName);
							
						#Else
							
							SetPrivilegedMode(True);
							Recipients = NodesForRegistrationByExportIfNecessaryCondition(Object.Ref, ExchangePlanName, ORR.FlagAttributeName);
							SetPrivilegedMode(False);
							
						#EndIf
						
						CommonClientServer.SupplementArray(NodeArrayResult, Recipients, True);
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Receives an array of exchange plan nodes with the "Export always" flag value set to True.
//
// Parameters:
//  ExchangePlanName    - String - a name of the exchange plan as a metadata object used to determine nodes.
//  FlagAttributeName - String - a name of the exchange plan attribute used to set a node selection filter.
//
// Returns:
//  Array - an array of exchange plan nodes with "Always export" flag value set to True.
//
Function NodesForRegistrationByExportAlwaysCondition(Val ExchangePlanName, Val FlagAttributeName) Export
	
	QueryText = "
	|SELECT
	|	ExchangePlanHeader.Ref AS Node
	|FROM
	|	ExchangePlan.[ExchangePlanName] AS ExchangePlanHeader
	|WHERE
	|	  NOT ExchangePlanHeader.ThisNode
	|	AND ExchangePlanHeader.[FlagAttributeName] = VALUE(Enum.ExchangeObjectExportModes.ExportAlways)
	|	AND NOT ExchangePlanHeader.DeletionMark
	|";
	
	QueryText = StrReplace(QueryText, "[ExchangePlanName]",    ExchangePlanName);
	QueryText = StrReplace(QueryText, "[FlagAttributeName]", FlagAttributeName);
	
	Query = New Query;
	Query.Text = QueryText;
	
	Return Query.Execute().Unload().UnloadColumn("Node");
EndFunction

// Receives an array of exchange plan nodes with "Export when needed" flag value set to True.
//
// Parameters:
//  Reference - a reference to the infobase object for which it is required to get the array of nodes the object was exported to earlier.
//  ExchangePlanName    - String - a name of the exchange plan as a metadata object used to determine nodes.
//  FlagAttributeName - String - a name of the exchange plan attribute used to set a node selection filter.
//
// Returns:
//  Array - an array of exchange plan nodes with "Export when needed" flag value set to True.
//
Function NodesForRegistrationByExportIfNecessaryCondition(Ref, Val ExchangePlanName, Val FlagAttributeName) Export
	
	NodesArray = New Array;
	
	If DataExchangeServer.IsXDTOExchangePlan(ExchangePlanName) Then
		NodesArray = DataExchangeXDTOServer.NodesArrayToRegisterExportIfNecessary(
			Ref, ExchangePlanName, FlagAttributeName);
	Else
		
		QueryText = "
		|SELECT DISTINCT
		|	ExchangePlanHeader.Ref AS Node
		|FROM
		|	ExchangePlan.[ExchangePlanName] AS ExchangePlanHeader
		|LEFT JOIN
		|	InformationRegister.InfobaseObjectsMaps AS InfobaseObjectsMaps
		|ON
		|	ExchangePlanHeader.Ref = InfobaseObjectsMaps.InfobaseNode
		|	AND InfobaseObjectsMaps.SourceUUID = &Object
		|WHERE
		|	     NOT ExchangePlanHeader.ThisNode
		|	AND    ExchangePlanHeader.[FlagAttributeName] = VALUE(Enum.ExchangeObjectExportModes.ExportIfNecessary)
		|	AND NOT ExchangePlanHeader.DeletionMark
		|	AND    InfobaseObjectsMaps.SourceUUID = &Object
		|";
		
		QueryText = StrReplace(QueryText, "[ExchangePlanName]",    ExchangePlanName);
		QueryText = StrReplace(QueryText, "[FlagAttributeName]", FlagAttributeName);
		
		Query = New Query;
		Query.Text = QueryText;
		Query.SetParameter("Object",   Ref);
		
		NodesArray = Query.Execute().Unload().UnloadColumn("Node");
		
	EndIf;
	
	Return NodesArray;
	
EndFunction

Procedure ExecuteObjectRegistrationRuleForRecordSet(NodeArrayResult,
															ORR,
															Object,
															MetadataObject,
															ExchangePlanName,
															Overwrite,
															DataExported)
	
	// Getting the array of recipient nodes by the current record set.
	GetRecipientArrayByRecordSet(NodeArrayResult, Object, ORR, MetadataObject, ExchangePlanName, False, DataExported);
	
	If Overwrite AND Not DataExported Then
		
		PreviousRecordSet = RecordSet(Object);
		
		// Getting the array of recipient nodes by the old record set.
		GetRecipientArrayByRecordSet(NodeArrayResult, PreviousRecordSet, ORR, MetadataObject, ExchangePlanName, True, False);
		
	EndIf;
	
EndProcedure

// Determines the list of nodes receiving the ExchangePlanName exchange plan where the object must 
// be registered according to ORR (a universal part) for future export.
//
// Parameters:
//  NodeArrayResult - Array - an array of recipient nodes of the ExchangePlanName exchange plan that 
//   must be registered.
//  ORR - ValueTableRow - contains info on registration rules for the object the procedure is executed for.
//  Object - Arbitrary - data to change: an object, a record set, a constant, or object deletion information.
//  ExchangePlanName - String - a name of exchange plan where objects are registered.
//  AdditionalParameters - Structure - additional information on data to change:
//    * IsObjectDeletion - Boolean - True means that the object deletion is being processed. IsRequired.
//    * WriteMode - see the Syntax Assistant for DocumentWriteMode - a document write mode (for documents only).
//                    IsRequired.
//    * CheckRef - Boolean - a flag showing whether it is necessary to consider a data version before this data change.
//                                 IsRequired.
//    * DataExported - Boolean - a parameter defines the registration rule execution context.
//        True - a registration rule is executed in the object export context.
//        False - a registration rule is executed in the context before writing the object. IsRequired.
//
Procedure ExecuteObjectRegistrationRuleForReferenceType(NodeArrayResult,
															ORR,
															Object,
															ExchangePlanName,
															AdditionalParameters)
	
	IsObjectDeletion = AdditionalParameters.IsObjectDeletion;
	WriteMode = AdditionalParameters.WriteMode;
	CheckRef = AdditionalParameters.CheckRef;
	DataExported = AdditionalParameters.DataExported;
	
	// ORROP - registration rules by the object properties.
	// ORREPP - registration rules by the exchange plan properties.
	// ORR = ORROP <And> ORREPP
	
	// ORRO
	If  Not ORR.RuleByObjectPropertiesEmpty
		AND Not ObjectPassedRegistrationRulesFilterByProperties(ORR, Object, CheckRef, WriteMode) Then
		
		Return;
		
	EndIf;
	
	// ORRP
	// Defining nodes for registering the object.
	GetNodeArrayForObject(NodeArrayResult, Object, ExchangePlanName, ORR, IsObjectDeletion, CheckRef, DataExported);
	
EndProcedure

// Determines the list of nodes receiving the ExchangePlanName exchange plan where the object must 
// be registered according to ORR for future export.
//
// Parameters:
//  NodeArrayResult - Array - an array of recipient nodes of the ExchangePlanName exchange plan that 
//   must be registered.
//  ORR - ValueTableRow - contains info on registration rules for the object the procedure is executed for.
//  Object - Arbitrary - data to change: an object, a record set, a constant, or object deletion information.
//  ExchangePlanName - String - a name of exchange plan where objects are registered.
//  AdditionalParameters - Structure - additional information on data to change:
//    * MetadataObject - MetadataObject - a metadata object that matches the data being changed. IsRequired.
//    * IsObjectDeletion - Boolean - True means that the object deletion is being processed. IsRequired.
//    * WriteMode - see the Syntax Assistant for DocumentWriteMode - a document write mode (for documents only).
//                    IsRequired.
//    * CheckRef - Boolean - a flag showing whether it is necessary to consider a data version before this data change.
//                                 IsRequired.
//    * DataExported - Boolean - a parameter defines the registration rule execution context.
//        True - a registration rule is executed in the object export context.
//        False - a registration rule is executed in the context before writing the object. IsRequired.
//
Procedure GetRecipientsByCondition(NodeArrayResult, ORR, Object, ExchangePlanName, AdditionalParameters)
	
	MetadataObject = AdditionalParameters.MetadataObject;
	DataExported = AdditionalParameters.DataExported;
	
	// {Handler: Before processing} Start.
	Cancel = False;
	
	ExecuteORRHandlerBeforeProcessing(ORR, Cancel, Object, MetadataObject, DataExported);
	
	If Cancel Then
		Return;
	EndIf;
	// {Handler: Before processing} End.
	
	Recipients = New Array;
	
	ExecuteObjectRegistrationRuleForReferenceType(Recipients, ORR, Object, ExchangePlanName, AdditionalParameters);
	
	// {Handler: After processing} Start.
	Cancel = False;
	
	ExecuteORRHandlerAfterProcessing(ORR, Cancel, Object, MetadataObject, Recipients, DataExported);
	
	If Cancel Then
		Return;
	EndIf;
	// {Handler: After processing} End.
	
	CommonClientServer.SupplementArray(NodeArrayResult, Recipients, True);
	
EndProcedure

Procedure GetRecipientsByConditionForRecordSet(NodeArrayResult,
														ORR,
														Object,
														MetadataObject,
														ExchangePlanName,
														Overwrite,
														DataExported)
	
	// {Handler: Before processing} Start.
	Cancel = False;
	
	ExecuteORRHandlerBeforeProcessing(ORR, Cancel, Object, MetadataObject, DataExported);
	
	If Cancel Then
		Return;
	EndIf;
	// {Handler: Before processing} End.
	
	Recipients = New Array;
	
	ExecuteObjectRegistrationRuleForRecordSet(Recipients, ORR, Object, MetadataObject, ExchangePlanName, Overwrite, DataExported);
	
	// {Handler: After processing} Start.
	Cancel = False;
	
	ExecuteORRHandlerAfterProcessing(ORR, Cancel, Object, MetadataObject, Recipients, DataExported);
	
	If Cancel Then
		Return;
	EndIf;
	// {Handler: After processing} End.
	
	CommonClientServer.SupplementArray(NodeArrayResult, Recipients, True);
	
EndProcedure

Procedure GetNodeArrayForObject(NodeArrayResult,
										Source,
										ExchangePlanName,
										ORR,
										IsObjectDeletion,
										CheckRef,
										DataExported)
	
	// Getting property value structure for the object.
	ObjectValuesProperties = PropertiesValuesForObject(Source, ORR);
	
	// Defining an array of nodes for the object registration.
	NodesArray = GetNodeArrayByPropertyValues(ObjectValuesProperties, ORR, ExchangePlanName, Source, DataExported);
	
	// Adding nodes for the registration.
	CommonClientServer.SupplementArray(NodeArrayResult, NodesArray, True);
	
	If CheckRef Then
		
		// Getting the property value structure for the reference.
		#If ExternalConnection OR ThickClientOrdinaryApplication Then
			
			RefPropertyValues = DataExchangeServerCall.PropertiesValuesForRef(Source.Ref, ORR.ObjectProperties, ORR.ObjectPropertiesString, ORR.MetadataObjectName);
			
		#Else
			
			SetPrivilegedMode(True);
			RefPropertyValues = PropertiesValuesForRef(Source.Ref, ORR.ObjectProperties, ORR.ObjectPropertiesString, ORR.MetadataObjectName);
			SetPrivilegedMode(False);
			
		#EndIf
		
		// Defining an array of nodes for registering the reference.
		NodesArray = GetNodeArrayByPropertyValuesAdditional(RefPropertyValues, ORR, ExchangePlanName, Source);
		
		// Adding nodes for the registration.
		CommonClientServer.SupplementArray(NodeArrayResult, NodesArray, True);
		
	EndIf;
	
EndProcedure

Procedure GetRecipientArrayByRecordSet(NodeArrayResult,
													RecordSet,
													ORR,
													MetadataObject,
													ExchangePlanName,
													IsObjectVersionBeforeChanges,
													DataExported)
	
	// Getting the value of the recorder from the filter for the record set.
	Recorder = Undefined;
	
	FilterItem = RecordSet.Filter.Find("Recorder");
	
	HasRecorder = FilterItem <> Undefined;
	
	If HasRecorder Then
		
		Recorder = FilterItem.Value;
		
	EndIf;
	
	For Each SetRow In RecordSet Do
		
		ORR_SetRows = CopyStructure(ORR);
		
		If HasRecorder AND SetRow["Recorder"] = Undefined Then
			
			If Recorder <> Undefined Then
				
				SetRow["Recorder"] = Recorder;
				
			EndIf;
			
		EndIf;
		
		// ORRO
		If Not ObjectPassedRegistrationRulesFilterByProperties(ORR_SetRows, SetRow, False) Then
			
			Continue;
			
		EndIf;
		
		// ORRP
		
		// Getting property value structure for the object.
		ObjectValuesProperties = PropertiesValuesForObject(SetRow, ORR_SetRows);
		
		If IsObjectVersionBeforeChanges Then
			
			// Defining an array of nodes for the object registration.
			NodesArray = GetNodeArrayByPropertyValuesAdditional(ObjectValuesProperties,
				ORR_SetRows, ExchangePlanName, SetRow, RecordSet.AdditionalProperties);
			
		Else
			
			// Defining an array of nodes for the object registration.
			NodesArray = GetNodeArrayByPropertyValues(ObjectValuesProperties, ORR_SetRows,
				ExchangePlanName, SetRow, DataExported, RecordSet.AdditionalProperties);
			
		EndIf;
		
		// Adding nodes for the registration.
		CommonClientServer.SupplementArray(NodeArrayResult, NodesArray, True);
		
	EndDo;
	
EndProcedure

// Returns the structure that stores object property values. The property values are obtained using a query to the infobase.
// StructureKey - a property name. Value - an object property value.
//
// Parameters:
//  Reference - a reference to the infobase object whose property values are being retrieved.
//
// Returns:
//  Structure - a structure with object properties values.
//
Function PropertiesValuesForRef(Ref, ObjectProperties, Val ObjectPropertiesString, Val MetadataObjectName) Export
	
	PropertiesValues = CopyStructure(ObjectProperties);
	
	If PropertiesValues.Count() = 0 Then
		
		Return PropertiesValues; // Returning an empty structure.
		
	EndIf;
	
	QueryText = "
	|SELECT
	|	[ObjectPropertiesString]
	|FROM
	|	[MetadataObjectName] AS Table
	|WHERE
	|	Table.Ref = &Ref
	|";
	
	QueryText = StrReplace(QueryText, "[ObjectPropertiesString]", ObjectPropertiesString);
	QueryText = StrReplace(QueryText, "[MetadataObjectName]",    MetadataObjectName);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Ref);
	
	Try
		
		Selection = Query.Execute().Select();
		
	Except
		MessageString = NStr("ru = 'Ошибка при получении свойств ссылки. Ошибка выполнения запроса: [ErrorDescription]'; en = 'An error occurred when receiving reference properties. Query execution error: [ErrorDescription]'; pl = 'Błąd podczas pobierania właściwości linku. Błąd wykonania zapytania: [ErrorDescription]';es_ES = 'Error al recibir las propiedades de enlace. Error de realizar la solicitud: [ErrorDescription]';es_CO = 'Error al recibir las propiedades de enlace. Error de realizar la solicitud: [ErrorDescription]';tr = 'Referans özellikleri alınırken bir hata oluştu. Sorgu yürütme başarısız oldu: [ErrorDescription]';it = 'Si è verificato un errore durante la ricezione delle proprietà di riferimento. Errore di esecuzione query: [ErrorDescription]';de = 'Fehler beim Erhalten von Link-Eigenschaften. Fehler bei der Ausführung der Anforderung: [ErrorDescription]'");
		MessageString = StrReplace(MessageString, "[ErrorDescription]", DetailErrorDescription(ErrorInfo()));
		Raise MessageString;
	EndTry;
	
	If Selection.Next() Then
		
		For Each Item In PropertiesValues Do
			
			PropertiesValues[Item.Key] = Selection[Item.Key];
			
		EndDo;
		
	EndIf;
	
	Return PropertiesValues;
EndFunction

Function GetNodeArrayByPropertyValues(PropertiesValues, ORR, Val ExchangePlanName, Object, Val DataExported, AdditionalProperties = Undefined)
	
	UseCache = True;
	QueryText = ORR.QueryText;
	
	// {Handler: On processing} Start.
	Cancel = False;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("QueryText", QueryText);
	AdditionalParameters.Insert("QueryOptions", PropertiesValues);
	AdditionalParameters.Insert("UseCache", UseCache);
	AdditionalParameters.Insert("DataExported", DataExported);
	AdditionalParameters.Insert("AdditionalProperties", AdditionalProperties);
	
	ExecuteORRHandlerOnProcessing(Cancel, ORR, Object, AdditionalParameters);
	
	QueryText = AdditionalParameters.QueryText;
	PropertiesValues = AdditionalParameters.QueryOptions;
	UseCache = AdditionalParameters.UseCache;
	
	If Cancel Then
		Return New Array;
	EndIf;
	// {Handler: On processing} End.
	
	If UseCache Then
		
		Return DataExchangeCached.NodesArrayByPropertiesValues(PropertiesValues, QueryText, ExchangePlanName, ORR.FlagAttributeName, DataExported);
		
	Else
		
		#If ExternalConnection OR ThickClientOrdinaryApplication Then
			
			Return DataExchangeServerCall.NodesArrayByPropertiesValues(PropertiesValues, QueryText, ExchangePlanName, ORR.FlagAttributeName, DataExported);
			
		#Else
			
			SetPrivilegedMode(True);
			Return NodesArrayByPropertiesValues(PropertiesValues, QueryText, ExchangePlanName, ORR.FlagAttributeName, DataExported);
			
		#EndIf
		
	EndIf;
	
EndFunction

Function GetNodeArrayByPropertyValuesAdditional(PropertiesValues, ORR, Val ExchangePlanName, Object, AdditionalProperties = Undefined)
	
	UseCache = True;
	QueryText = ORR.QueryText;
	
	// {Handler: On processing (additional)} Start.
	Cancel = False;
	
	ExecuteORRHandlerOnProcessingAdditional(Cancel, ORR, Object, QueryText, PropertiesValues, UseCache, AdditionalProperties);
	
	If Cancel Then
		Return New Array;
	EndIf;
	// {Handler: On processing (additional)} End.
	
	If UseCache Then
		
		Return DataExchangeCached.NodesArrayByPropertiesValues(PropertiesValues, QueryText, ExchangePlanName, ORR.FlagAttributeName);
		
	Else
		
		#If ExternalConnection OR ThickClientOrdinaryApplication Then
			
			Return DataExchangeServerCall.NodesArrayByPropertiesValues(PropertiesValues, QueryText, ExchangePlanName, ORR.FlagAttributeName);
			
		#Else
			
			SetPrivilegedMode(True);
			Return NodesArrayByPropertiesValues(PropertiesValues, QueryText, ExchangePlanName, ORR.FlagAttributeName);
			
		#EndIf
		
	EndIf;
	
EndFunction

// Returns an array of exchange plan nodes under the specified request parameters and request text for the exchange plan table.
//
//
Function NodesArrayByPropertiesValues(PropertiesValues, Val QueryText, Val ExchangePlanName, Val FlagAttributeName, Val DataExported = False) Export
	
	// Function return value.
	NodeArrayResult = New Array;
	
	// Preparing a query for getting exchange plan nodes.
	Query = New Query;
	
	QueryText = StrReplace(QueryText, "[MandatoryConditions]",
				"AND    ExchangePlanMainTable.Ref <> &" + ExchangePlanName + "ThisNode
				|AND NOT ExchangePlanMainTable.DeletionMark
				|[FilterCriterionByFlagAttribute]
				|");
	//
	If IsBlankString(FlagAttributeName) Then
		
		QueryText = StrReplace(QueryText, "[FilterCriterionByFlagAttribute]", "");
		
	Else
		
		If DataExported Then
			QueryText = StrReplace(QueryText, "[FilterCriterionByFlagAttribute]",
				"AND  (ExchangePlanMainTable.[FlagAttributeName] = VALUE(Enum.ExchangeObjectExportModes.ExportByCondition)
				|OR ExchangePlanMainTable.[FlagAttributeName] = VALUE(Enum.ExchangeObjectExportModes.ManualExport)
				|OR ExchangePlanMainTable.[FlagAttributeName] = VALUE(Enum.ExchangeObjectExportModes.EmptyRef))");
		Else
			QueryText = StrReplace(QueryText, "[FilterCriterionByFlagAttribute]",
				"AND  (ExchangePlanMainTable.[FlagAttributeName] = VALUE(Enum.ExchangeObjectExportModes.ExportByCondition)
				|OR ExchangePlanMainTable.[FlagAttributeName] = VALUE(Enum.ExchangeObjectExportModes.EmptyRef))");
		EndIf;
		
		QueryText = StrReplace(QueryText, "[FlagAttributeName]", FlagAttributeName);
		
	EndIf;
	
	// query text
	Query.Text = QueryText;
	
	Query.SetParameter(ExchangePlanName + "ThisNode", DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName));
	
	// Filling query parameters with object properties.
	For Each Item In PropertiesValues Do
		
		Query.SetParameter("ObjectProperty_" + Item.Key, Item.Value);
		
	EndDo;
	
	Try
		
		NodeArrayResult = Query.Execute().Unload().UnloadColumn("Ref");
		
	Except
		MessageString = NStr("ru = 'Ошибка при получении списка узлов получателей. Ошибка выполнения запроса: [ErrorDescription]'; en = 'An error occurred when receiving the list of destination nodes. Query execution error: [ErrorDescription]'; pl = 'Błąd podczas pobierania listy węzłów odbiorców. Błąd wykonania zapytania: [ErrorDescription]';es_ES = 'Error al recibir la lista de nodos de usuarios. Error de realizar la solicitud: [ErrorDescription]';es_CO = 'Error al recibir la lista de nodos de usuarios. Error de realizar la solicitud: [ErrorDescription]';tr = 'Hedef ünitelerin listesi alınırken bir hata oluştu. Sorgu yürütülemedi:[ErrorDescription]';it = 'Si è verificato un errore durante la ricezione dell''elenco dei nodi di destinazione. Errore di esecuzione query: [ErrorDescription]';de = 'Fehler beim Abrufen der Liste der Empfängerknoten. Fehler bei der Ausführung der Anforderung: [ErrorDescription]'");
		MessageString = StrReplace(MessageString, "[ErrorDescription]", DetailErrorDescription(ErrorInfo()));
		Raise MessageString;
	EndTry;
	
	Return NodeArrayResult;
EndFunction

Function PropertiesValuesForObject(Object, ORR)
	
	PropertiesValues = New Structure;
	
	For Each Item In ORR.ObjectProperties Do
		
		PropertiesValues.Insert(Item.Key, ObjectPropertyValue(Object, Item.Value));
		
	EndDo;
	
	Return PropertiesValues;
	
EndFunction

Function ObjectPropertyValue(Object, ObjectPropertyRow)
	
	Value = Object;
	
	SubstringsArray = StrSplit(ObjectPropertyRow, ".");
	
	// Getting the value considering the possibility of property dereferencing.
	For Each PropertyName In SubstringsArray Do
		
		Value = Value[PropertyName];
		
	EndDo;
	
	Return Value;
	
EndFunction

Function ExchangePlanObjectsRegistrationRules(Val ExchangePlanName) Export
	
	Return DataExchangeCached.ExchangePlanObjectsRegistrationRules(ExchangePlanName);
	
EndFunction

Function ObjectRegistrationRules(Val ExchangePlanName, Val FullObjectName) Export
	
	Return DataExchangeCached.ObjectRegistrationRules(ExchangePlanName, FullObjectName);
	
EndFunction

Function RegistrationRuleAsStructure(Rule, Columns)
	
	Result = New Structure;
	
	For Each Column In Columns Do
		
		varKey = Column.Name;
		Value = Rule[varKey];
		
		If TypeOf(Value) = Type("ValueTable") Then
			
			Result.Insert(varKey, Value.Copy());
			
		ElsIf TypeOf(Value) = Type("ValueTree") Then
			
			Result.Insert(varKey, Value.Copy());
			
		ElsIf TypeOf(Value) = Type("Structure") Then
			
			Result.Insert(varKey, CopyStructure(Value));
			
		Else
			
			Result.Insert(varKey, Value);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function SeparatedExchangePlan(Val ExchangePlanName)
	
	If Common.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		IsSeparatedData = ModuleSaaS.IsSeparatedMetadataObject(
			"ExchangePlan." + ExchangePlanName, ModuleSaaS.MainDataSeparator());
	Else
		IsSeparatedData = False;
	EndIf;
	
	Return IsSeparatedData;
	
EndFunction

// Creates a record set for the register.
//
// Parameters:
//	Register MetadataObject - to get a record set.
//
// Returns:
//	RecordSet. If a record set cannot be created for the metadata object, an exception is raised.
//	
//
Function RecordSetByType(MetadataObject)
	
	If Common.IsInformationRegister(MetadataObject) Then
		
		Result = InformationRegisters[MetadataObject.Name].CreateRecordSet();
		
	ElsIf Common.IsAccumulationRegister(MetadataObject) Then
		
		Result = AccumulationRegisters[MetadataObject.Name].CreateRecordSet();
		
	ElsIf Common.IsAccountingRegister(MetadataObject) Then
		
		Result = AccountingRegisters[MetadataObject.Name].CreateRecordSet();
		
	ElsIf Common.IsCalculationRegister(MetadataObject) Then
		
		Result = CalculationRegisters[MetadataObject.Name].CreateRecordSet();
		
	ElsIf Common.IsSequence(MetadataObject) Then
		
		Result = Sequences[MetadataObject.Name].CreateRecordSet();
		
	ElsIf Common.IsCalculationRegister(MetadataObject.Parent())
		AND Metadata.CalculationRegisters[MetadataObject.Parent().Name].Recalculations.Contains(MetadataObject) Then
		
		Result = CalculationRegisters[MetadataObject.Parent().Name].Recalculations[MetadataObject.Name].CreateRecordSet();
		
	Else
		
		MessageString = NStr("ru = 'Для объекта метаданных %1 не предусмотрено набора записей.'; en = 'A record set is not available for the %1 metadata object.'; pl = 'Zestaw wpisów dla obiektu metadanych %1 nie jest dostępny.';es_ES = 'El conjunto de registros no se ha proporcionado para el objeto de metadatos %1.';es_CO = 'El conjunto de registros no se ha proporcionado para el objeto de metadatos %1.';tr = 'Meta veri nesnesi için kayıt kümesi sağlanmadı %1.';it = 'Non è disponibile un set di registrazioni per l''oggetto di metadati %1.';de = 'Der Datensatz ist nicht für das Metadatenobjekt verfügbar %1.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, MetadataObject.FullName());
		Raise MessageString;
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region RegistrationRulesByObjectsProperties

Procedure FillPropertyValuesFromObject(ValuesTree, Object)
	
	For Each TreeRow In ValuesTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			FillPropertyValuesFromObject(TreeRow, Object);
			
		Else
			
			TreeRow.PropertyValue = ObjectPropertyValue(Object, TreeRow.ObjectProperty);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure CreateValidFilterByProperties(Object, DestinationValueTree, SourceValueTree)
	
	For Each SourceTreeRow In SourceValueTree.Rows Do
		
		If SourceTreeRow.IsFolder Then
			
			DestinationTreeRow = DestinationValueTree.Rows.Add();
			
			FillPropertyValues(DestinationTreeRow, SourceTreeRow);
			
			CreateValidFilterByProperties(Object, DestinationTreeRow, SourceTreeRow);
			
		Else
			
			If ObjectHasProperties(Object, SourceTreeRow.ObjectProperty) Then
				
				DestinationTreeRow = DestinationValueTree.Rows.Add();
				
				FillPropertyValues(DestinationTreeRow, SourceTreeRow);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Retrieving constant values that are calculated using custom expressions.
// The values are calculated in privileged mode
//
Procedure GetConstantAlgorithmValues(ORR, ValuesTree)
	
	For Each TreeRow In ValuesTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			GetConstantAlgorithmValues(ORR, TreeRow);
			
		Else
			
			If TreeRow.FilterItemKind = DataExchangeServer.FilterItemPropertyValueAlgorithm() Then
				
				Value = Undefined;
				
				Try
					
					#If ExternalConnection OR ThickClientOrdinaryApplication Then
						
						DataExchangeServerCall.ExecuteHandlerInPrivilegedMode(Value, TreeRow.ConstantValue);
						
					#Else
						
						SetPrivilegedMode(True);
						Execute(TreeRow.ConstantValue);
						SetPrivilegedMode(False);
						
					#EndIf
					
				Except
					
					MessageString = NStr("ru = 'Ошибка алгоритма вычисления значения константы:
												|План обмена: [ExchangePlanName]
												|Объект метаданных: [MetadataObjectName]
												|Описание ошибки: [Details]
												|Алгоритм:
												|// {Начало алгоритма}
												|[ConstantValue]
												|// {Окончание алгоритма}'; 
												|en = 'An error occurred while calculating constant value:
												|Exchange plan: [ExchangePlanName]
												|Metadata object: [MetadataObjectName]
												|Error description: [Details] 
												|Algorithm:
												|// {Algorithm beginning} 
												|[ConstantValue]
												|// {Algorithm end}'; 
												|pl = 'Błąd algorytmu obliczenia wartości konstanty:
												|Exchange plan: [ExchangePlanName]
												|Metadata object: [MetadataObjectName]
												|Error description: [Details] 
												|Algorithm:
												|// {Algorithm beginning} 
												|[ConstantValue]
												|// {Algorithm end}';
												|es_ES = 'Error del algoritmo de cálculo del valor del constante:
												|Plan de cambio: [ExchangePlanName]
												|Objeto de metadatos: [MetadataObjectName]
												|Descripción de error: [Details]
												|Algoritmo:
												|// {Inicio del algoritmo}
												|[ConstantValue]
												|// {Final del algoritmo}';
												|es_CO = 'Error del algoritmo de cálculo del valor del constante:
												|Plan de cambio: [ExchangePlanName]
												|Objeto de metadatos: [MetadataObjectName]
												|Descripción de error: [Details]
												|Algoritmo:
												|// {Inicio del algoritmo}
												|[ConstantValue]
												|// {Final del algoritmo}';
												|tr = 'Sabit değer 
												|hesaplanırken bir hata oluştu: 
												|Değişim planı: [ExchangePlanName]
												| Meta veri nesnesi: [MetadataObjectName] 
												|Hata kodu: [Details]
												| Algoritma: // 
												|{Algoritma başlangıcı} [ConstantValue] // {Algoritma sonu}
												|';
												|it = 'Si è verificato un errore durante il calcolo del valore della costante:
												|Piano di scambio:[ExchangePlanName]
												|Oggetto di metadati: [MetadataObjectName]
												|Descrizione errore: [Details]
												|Algoritmo:
												|// {Algorithm beginning} 
												|[ConstantValue]
												|// {Algorithm end}';
												|de = 'Bei der Berechnung des konstanten Wertes ist ein Fehler aufgetreten:
												|Austauschplan: [ExchangePlanName]
												|Metadaten-Objekt: [MetadataObjectName]
												|Fehlerbeschreibung: [Details] 
												|Algorithmus:
												|// (Algorithmusanfang)
												|[ConstantValue]
												|// (Algorithmusende)'");
					MessageString = StrReplace(MessageString, "[ExchangePlanName]",      ORR.ExchangePlanName);
					MessageString = StrReplace(MessageString, "[MetadataObjectName]", ORR.MetadataObjectName);
					MessageString = StrReplace(MessageString, "[Details]",            ErrorInfo().Description);
					MessageString = StrReplace(MessageString, "[ConstantValue]",   String(TreeRow.ConstantValue));
					
					Raise MessageString;
					
				EndTry;
				
				TreeRow.ConstantValue = Value;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function ObjectHasProperties(Object, Val ObjectPropertyRow)
	
	Value = Object;
	
	SubstringsArray = StrSplit(ObjectPropertyRow, ".");
	
	// Getting the value considering the possibility of property dereferencing.
	For Each PropertyName In SubstringsArray Do
		
		Try
			Value = Value[PropertyName];
		Except
			Return False;
		EndTry;
		
	EndDo;
	
	Return True;
EndFunction

// Executing ORROP for reference and object.
// The result is considered by the OR condition.
// If the object passed the ORROP filter by the reference values, then the ORROP for the object 
// values is not executed.
//
Function ObjectPassedRegistrationRulesFilterByProperties(ORR, Object, CheckRef, WriteMode = Undefined)
	
	PostedPropertyInitialValue = Undefined;
	
	GetConstantAlgorithmValues(ORR, ORR.FilterByObjectProperties);
	
	If WriteMode <> Undefined Then
		
		PostedPropertyInitialValue = Object.Posted;
		
		If WriteMode = DocumentWriteMode.UndoPosting Then
			
			Object.Posted = False;
			
		ElsIf WriteMode = DocumentWriteMode.Posting Then
			
			Object.Posted = True;
			
		EndIf;
		
	EndIf;
	
	// ORROP by the object property value.
	If ObjectPassesORROFilter(ORR, Object) Then
		
		If PostedPropertyInitialValue <> Undefined Then
			
			Object.Posted = PostedPropertyInitialValue;
			
		EndIf;
		
		Return True;
		
	EndIf;
	
	If PostedPropertyInitialValue <> Undefined Then
		
		Object.Posted = PostedPropertyInitialValue;
		
	EndIf;
	
	If CheckRef Then
		
		// ORROP by the reference property value.
		If ObjectPassesORROFilter(ORR, Object.Ref) Then
			
			Return True;
			
		EndIf;
		
	EndIf;
	
	Return False;
	
EndFunction

Function ObjectPassesORROFilter(ORR, Object)
	
	ORR.FilterByProperties = DataProcessors.ObjectsRegistrationRulesImport.FilterByObjectPropertiesTableInitialization();
	
	CreateValidFilterByProperties(Object, ORR.FilterByProperties, ORR.FilterByObjectProperties);
	
	FillPropertyValuesFromObject(ORR.FilterByProperties, Object);
	
	Return ConditionIsTrueForValueTreeBranch(ORR.FilterByProperties);
	
EndFunction

// By default, filter items of the root group are compared with the AND condition
// Therefore, the IsAndOperator parameter is set to True by default.
//
Function ConditionIsTrueForValueTreeBranch(ValuesTree, Val IsAndOperator = True)
	
	// initialization
	If IsAndOperator Then // AND
		Result = True;
	Else // OR
		Result = False;
	EndIf;
	
	For Each TreeRow In ValuesTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			ItemResult = ConditionIsTrueForValueTreeBranch(TreeRow, TreeRow.IsAndOperator);
		Else
			
			ItemResult = IsConditionTrueForItem(TreeRow, IsAndOperator);
		EndIf;
		
		If IsAndOperator Then // AND
			
			Result = Result AND ItemResult;
			
			If Not Result Then
				Return False;
			EndIf;
			
		Else // OR
			
			Result = Result OR ItemResult;
			
			If Result Then
				Return True;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function IsConditionTrueForItem(TreeRow, IsAndOperator)
	
	Var ComparisonType;
	
	ComparisonType = TreeRow.ComparisonType;
	
	Try
		
		If      ComparisonType = "Equal"          Then Return TreeRow.PropertyValue =  TreeRow.ConstantValue;
		ElsIf ComparisonType = "NotEqual"        Then Return TreeRow.PropertyValue <> TreeRow.ConstantValue;
		ElsIf ComparisonType = "Greater"         Then Return TreeRow.PropertyValue >  TreeRow.ConstantValue;
		ElsIf ComparisonType = "GreaterOrEqual" Then Return TreeRow.PropertyValue >= TreeRow.ConstantValue;
		ElsIf ComparisonType = "Less"         Then Return TreeRow.PropertyValue <  TreeRow.ConstantValue;
		ElsIf ComparisonType = "LessOrEqual" Then Return TreeRow.PropertyValue <= TreeRow.ConstantValue;
		EndIf;
		
	Except
		
		Return False;
		
	EndTry;
	
	Return False;
	
EndFunction

#EndRegion

#Region ObjectsRegistrationRulesEvents

Procedure ExecuteORRHandlerBeforeProcessing(ORR, Cancel, Object, MetadataObject, Val DataExported)
	
	If ORR.HasBeforeProcessHandler Then
		
		Try
			Execute(ORR.BeforeProcess);
		Except
			MessageString = NStr("ru = 'Ошибка при выполнении обработчика: ""[HandlerName]"";
				|План обмена: [ExchangePlanName];
				|Объект метаданных: [MetadataObjectName]
				|Описание ошибки: [Details]'; 
				|en = 'An error occurred when executing handler: ""[HandlerName]"";
				|Exchange plan: [ExchangePlanName];
				|Metadata object: [MetadataObjectName]
				|Error details: [Details]'; 
				|pl = 'Wystąpił błąd podczas wykonywania procedury obsługi: ""[HandlerName]"";
				|Plan wymiany: [ExchangePlanName];
				|obiekt metadanych: [MetadataObjectName]
				|Szczegóły błędu: [Details]';
				|es_ES = 'Ha ocurrido un error al ejecutar el manipulador: ""[HandlerName]"";
				|Plan de intercambio: [ExchangePlanName];
				|Objeto de metadatos:[MetadataObjectName]
				|Descripción del error: [Details]';
				|es_CO = 'Ha ocurrido un error al ejecutar el manipulador: ""[HandlerName]"";
				|Plan de intercambio: [ExchangePlanName];
				|Objeto de metadatos:[MetadataObjectName]
				|Descripción del error: [Details]';
				|tr = 'İşleyici çalıştırılırken bir hata oluştu: ""[HandlerName]""; 
				|Değişim planı: [ExchangePlanName]; 
				|Meta veri nesnesi: [MetadataObjectName] 
				| Hata açıklaması: [Details]';
				|it = 'Si è verificato un errore durante l''esecuzione del gestore: ""[HandlerName]"";
				|Piano di scambio: [ExchangePlanName];
				|Oggetto di Metadati: [MetadataObjectName]
				|Dettagli errore: [Details]';
				|de = 'Beim Ausführen des Handlers ist ein Fehler aufgetreten: ""[HandlerName]"";
				|Austauschplan: [ExchangePlanName];
				|Metadaten-Objekt: [MetadataObjectName]
				|Fehlerdetails: [Details]'");
			MessageString = StrReplace(MessageString, "[HandlerName]",      NStr("ru = 'Перед обработкой'; en = 'Before processing'; pl = 'Przed przetwarzaniem';es_ES = 'Antes del procesamiento';es_CO = 'Antes del procesamiento';tr = 'İşlenmeden önce';it = 'Prima della trasformazione';de = 'Vor der Verarbeitung'"));
			MessageString = StrReplace(MessageString, "[ExchangePlanName]",      ORR.ExchangePlanName);
			MessageString = StrReplace(MessageString, "[MetadataObjectName]", ORR.MetadataObjectName);
			MessageString = StrReplace(MessageString, "[Details]",            DetailErrorDescription(ErrorInfo()));
			Raise MessageString;
		EndTry;
		
	EndIf;
	
EndProcedure

Procedure ExecuteORRHandlerOnProcessing(Cancel, ORR, Object, AdditionalParameters)
	
	QueryText = AdditionalParameters.QueryText;
	QueryOptions = AdditionalParameters.QueryOptions;
	UseCache = AdditionalParameters.UseCache;
	DataExported = AdditionalParameters.DataExported;
	AdditionalProperties = AdditionalParameters.AdditionalProperties;
	
	If ORR.HasOnProcessHandler Then
		
		Try
			Execute(ORR.OnProcess);
		Except
			MessageString = NStr("ru = 'Ошибка при выполнении обработчика: ""[HandlerName]""; План обмена: [ExchangePlanName]; Объект метаданных: [MetadataObjectName]
				|Описание ошибки: [Details]'; 
				|en = 'An error occurred when executing handler: ""[HandlerName]""; Exchange plan: [ExchangePlanName]; Metadata object: [MetadataObjectName]
				|Error details: [Details]'; 
				|pl = 'Wystąpił błąd podczas wykonywania procedury obsługi""[HandlerName]""; Plan wymiany: [ExchangePlanName]; Obiekt metadanych:[MetadataObjectName]
				|Szczegóły błędu: [Details]';
				|es_ES = 'Ha ocurrido un error al ejecutar el manipulador: ""[HandlerName]"";Plan de intercambio: [ExchangePlanName]; Objeto de metadatos:[MetadataObjectName]
				|Descripción del error: [Details]';
				|es_CO = 'Ha ocurrido un error al ejecutar el manipulador: ""[HandlerName]"";Plan de intercambio: [ExchangePlanName]; Objeto de metadatos:[MetadataObjectName]
				|Descripción del error: [Details]';
				|tr = 'İşleyici çalıştırılırken bir hata oluştu: ""[HandlerName]""; Değişim planı: [ExchangePlanName]; Meta veri nesnesi: [MetadataObjectName] 
				| Hata açıklaması: [Details]';
				|it = 'Si è verificato un errore durante l''esecuzione del gestore: ""[HandlerName]""; Piano di scambio: [ExchangePlanName]; Oggetto di metadati: [MetadataObjectName]
				|Dettagli errore: [Details]';
				|de = 'Beim Ausführen des Handlers ist ein Fehler aufgetreten: ""[HandlerName]"";Austauschplan: [ExchangePlanName];Metadaten-Objekt: [MetadataObjectName]
				|Fehlerdetails: [Details]'");
			MessageString = StrReplace(MessageString, "[HandlerName]",      NStr("ru = 'При обработке'; en = 'On processing'; pl = 'Podczas przetwarzania';es_ES = 'Durante el procesamiento';es_CO = 'Durante el procesamiento';tr = 'İşlerken';it = 'In elaborazione';de = 'Bei der Verarbeitung'"));
			MessageString = StrReplace(MessageString, "[ExchangePlanName]",      ORR.ExchangePlanName);
			MessageString = StrReplace(MessageString, "[MetadataObjectName]", ORR.MetadataObjectName);
			MessageString = StrReplace(MessageString, "[Details]",            DetailErrorDescription(ErrorInfo()));
			Raise MessageString;
		EndTry;
		
	EndIf;
	
	AdditionalParameters.QueryText = QueryText;
	AdditionalParameters.QueryOptions = QueryOptions;
	AdditionalParameters.UseCache = UseCache;
	
EndProcedure

Procedure ExecuteORRHandlerOnProcessingAdditional(Cancel, ORR, Object, QueryText, QueryOptions, UseCache, AdditionalProperties = Undefined)
	
	If ORR.HasOnProcessHandlerAdditional Then
		
		Try
			Execute(ORR.OnProcessAdditional);
		Except
			MessageString = NStr("ru = 'Ошибка при выполнении обработчика: ""[HandlerName]""; План обмена: [ExchangePlanName]; Объект метаданных: [MetadataObjectName]
				|Описание ошибки: [Details]'; 
				|en = 'An error occurred when executing handler: ""[HandlerName]""; Exchange plan: [ExchangePlanName]; Metadata object: [MetadataObjectName]
				|Error details: [Details]'; 
				|pl = 'Wystąpił błąd podczas wykonywania procedury obsługi""[HandlerName]""; Plan wymiany: [ExchangePlanName]; Obiekt metadanych:[MetadataObjectName]
				|Szczegóły błędu: [Details]';
				|es_ES = 'Ha ocurrido un error al ejecutar el manipulador: ""[HandlerName]"";Plan de intercambio: [ExchangePlanName]; Objeto de metadatos:[MetadataObjectName]
				|Descripción del error: [Details]';
				|es_CO = 'Ha ocurrido un error al ejecutar el manipulador: ""[HandlerName]"";Plan de intercambio: [ExchangePlanName]; Objeto de metadatos:[MetadataObjectName]
				|Descripción del error: [Details]';
				|tr = 'İşleyici çalıştırılırken bir hata oluştu: ""[HandlerName]""; Değişim planı: [ExchangePlanName]; Meta veri nesnesi: [MetadataObjectName] 
				| Hata açıklaması: [Details]';
				|it = 'Si è verificato un errore durante l''esecuzione del gestore: ""[HandlerName]""; Piano di scambio: [ExchangePlanName]; Oggetto di metadati: [MetadataObjectName]
				|Dettagli errore: [Details]';
				|de = 'Beim Ausführen des Handlers ist ein Fehler aufgetreten: ""[HandlerName]"";Austauschplan: [ExchangePlanName];Metadaten-Objekt: [MetadataObjectName]
				|Fehlerdetails: [Details]'");
			MessageString = StrReplace(MessageString, "[HandlerName]",      NStr("ru = 'При обработке (дополнительный)'; en = 'On processing (additional)'; pl = 'Podczas przetwarzania (opcjonalnie)';es_ES = 'Durante el procesamiento (opcional)';es_CO = 'Durante el procesamiento (opcional)';tr = 'İşlerken (opsiyonel)';it = 'In elaborazione (aggiuntivo)';de = 'Bei der Verarbeitung (optional)'"));
			MessageString = StrReplace(MessageString, "[ExchangePlanName]",      ORR.ExchangePlanName);
			MessageString = StrReplace(MessageString, "[MetadataObjectName]", ORR.MetadataObjectName);
			MessageString = StrReplace(MessageString, "[Details]",            DetailErrorDescription(ErrorInfo()));
			Raise MessageString;
		EndTry;
		
	EndIf;
	
EndProcedure

Procedure ExecuteORRHandlerAfterProcessing(ORR, Cancel, Object, MetadataObject, Recipients, Val DataExported)
	
	If ORR.HasAfterProcessHandler Then
		
		Try
			Execute(ORR.AfterProcess);
		Except
			MessageString = NStr("ru = 'Ошибка при выполнении обработчика: ""[HandlerName]""; План обмена: [ExchangePlanName]; Объект метаданных: [MetadataObjectName]
				|Описание ошибки: [Details]'; 
				|en = 'An error occurred when executing handler: ""[HandlerName]""; Exchange plan: [ExchangePlanName]; Metadata object: [MetadataObjectName]
				|Error details: [Details]'; 
				|pl = 'Wystąpił błąd podczas wykonywania procedury obsługi""[HandlerName]""; Plan wymiany: [ExchangePlanName]; Obiekt metadanych:[MetadataObjectName]
				|Szczegóły błędu: [Details]';
				|es_ES = 'Ha ocurrido un error al ejecutar el manipulador: ""[HandlerName]"";Plan de intercambio: [ExchangePlanName]; Objeto de metadatos:[MetadataObjectName]
				|Descripción del error: [Details]';
				|es_CO = 'Ha ocurrido un error al ejecutar el manipulador: ""[HandlerName]"";Plan de intercambio: [ExchangePlanName]; Objeto de metadatos:[MetadataObjectName]
				|Descripción del error: [Details]';
				|tr = 'İşleyici çalıştırılırken bir hata oluştu: ""[HandlerName]""; Değişim planı: [ExchangePlanName]; Meta veri nesnesi: [MetadataObjectName] 
				| Hata açıklaması: [Details]';
				|it = 'Si è verificato un errore durante l''esecuzione del gestore: ""[HandlerName]""; Piano di scambio: [ExchangePlanName]; Oggetto di metadati: [MetadataObjectName]
				|Dettagli errore: [Details]';
				|de = 'Beim Ausführen des Handlers ist ein Fehler aufgetreten: ""[HandlerName]"";Austauschplan: [ExchangePlanName];Metadaten-Objekt: [MetadataObjectName]
				|Fehlerdetails: [Details]'");
			MessageString = StrReplace(MessageString, "[HandlerName]",      NStr("ru = 'После обработки'; en = 'After processing'; pl = 'Po przetworzeniu';es_ES = 'Después del procesamiento';es_CO = 'Después del procesamiento';tr = 'Işlendikten sonra';it = 'Dopo l''elaborazione';de = 'Nach der Verarbeitung'"));
			MessageString = StrReplace(MessageString, "[ExchangePlanName]",      ORR.ExchangePlanName);
			MessageString = StrReplace(MessageString, "[MetadataObjectName]", ORR.MetadataObjectName);
			MessageString = StrReplace(MessageString, "[Details]",            DetailErrorDescription(ErrorInfo()));
			Raise MessageString;
		EndTry;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region AuxiliaryProceduresAndFunctions

Procedure OnSendData(DataItem, ItemSend, Val Recipient, Val InitialImageCreation, Val Analysis)
	
	If TypeOf(DataItem) = Type("ObjectDeletion") Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtection = Common.CommonModule("PersonalDataProtection");
		ModulePersonalDataProtection.OnSendData(DataItem, ItemSend, Recipient, InitialImageCreation);
	EndIf;
	
	// Checking whether registration mechanism cached data is up-to-date.
	DataExchangeServerCall.CheckObjectsRegistrationMechanismCache();
	
	ObjectExportMode = DataExchangeCached.ObjectExportMode(DataItem.Metadata().FullName(), Recipient);
	
	If ObjectExportMode = Enums.ExchangeObjectExportModes.ExportAlways Then
		
		// Exporting data item
		
	ElsIf ObjectExportMode = Enums.ExchangeObjectExportModes.ExportByCondition
		OR ObjectExportMode = Enums.ExchangeObjectExportModes.ExportIfNecessary Then
		
		If Not DataMatchRegistrationRuleFilter(DataItem, Recipient) Then
			
			If InitialImageCreation Then
				
				ItemSend = DataItemSend.Ignore;
				
			Else
				
				ItemSend = DataItemSend.Delete;
				
			EndIf;
			
		EndIf;
		
	ElsIf ObjectExportMode = Enums.ExchangeObjectExportModes.ManualExport Then
		
		If DataMatchRegistrationRuleFilter(DataItem, Recipient) Then
			
			If Not Analysis Then
				
				// Deleting change registrations for data that is exported manually.
				ExchangePlans.DeleteChangeRecords(Recipient, DataItem);
				
			EndIf;
			
		Else
			
			ItemSend = DataItemSend.Ignore;
			
		EndIf;
			
	ElsIf ObjectExportMode = Enums.ExchangeObjectExportModes.DoNotExport Then
		
		ItemSend = DataItemSend.Ignore;
		
	EndIf;
	
	If ItemSend = DataItemSend.Ignore
		AND Not (DataExchangeCached.IsDistributedInfobaseNode(Recipient) AND InitialImageCreation)
		AND Not Analysis Then
		// If object export is denied, it is necessary to delete change registration.
		ExchangePlans.DeleteChangeRecords(Recipient, DataItem);
	EndIf;
	
EndProcedure

Function DataMatchRegistrationRuleFilter(DataItem, Val Recipient)
	
	Result = True;
	
	ExchangePlanName = Recipient.Metadata().Name;
	
	MetadataObject = DataItem.Metadata();
	
	If    Common.IsCatalog(MetadataObject)
		OR Common.IsDocument(MetadataObject)
		OR Common.IsChartOfCharacteristicTypes(MetadataObject)
		OR Common.IsChartOfAccounts(MetadataObject)
		OR Common.IsChartOfCalculationTypes(MetadataObject)
		OR Common.IsBusinessProcess(MetadataObject)
		OR Common.IsTask(MetadataObject) Then
		
		// Defining an array of nodes for the object registration.
		NodesArrayForObjectRegistration = New Array;
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("MetadataObject", MetadataObject);
		AdditionalParameters.Insert("DataExported", True);
		ExecuteObjectsRegistrationRulesForExchangePlan(NodesArrayForObjectRegistration,
														DataItem,
														ExchangePlanName,
														AdditionalParameters);
		//
		
		// Sending object deletion if the current node is absent from the array.
		If NodesArrayForObjectRegistration.Find(Recipient) = Undefined Then
			
			Result = False;
			
		EndIf;
		
	ElsIf Common.IsRegister(MetadataObject) Then
		
		ExcludeProperties = ?(Common.IsAccumulationRegister(MetadataObject), "RecordType", "");
		
		DataToCheck = RecordSetByType(MetadataObject);
		
		For Each SourceFilterItem In DataItem.Filter Do
			
			DestinationFilterItem = DataToCheck.Filter.Find(SourceFilterItem.Name);
			
			FillPropertyValues(DestinationFilterItem, SourceFilterItem);
			
		EndDo;
		
		DataToCheck.Add();
		
		ReverseIndex = DataItem.Count() - 1;
		
		While ReverseIndex >= 0 Do
			
			FillPropertyValues(DataToCheck[0], DataItem[ReverseIndex],, ExcludeProperties);
			
			// Defining an array of nodes for the object registration.
			NodesArrayForObjectRegistration = New Array;
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("MetadataObject", MetadataObject);
			AdditionalParameters.Insert("IsRegister", True);
			AdditionalParameters.Insert("DataExported", True);
			ExecuteObjectsRegistrationRulesForExchangePlan(NodesArrayForObjectRegistration,
															DataToCheck,
															ExchangePlanName,
															AdditionalParameters);
			
			// Deleting the row from the set if the current node is absent from the array.
			If NodesArrayForObjectRegistration.Find(Recipient) = Undefined Then
				
				DataItem.Delete(ReverseIndex);
				
			EndIf;
			
			ReverseIndex = ReverseIndex - 1;
			
		EndDo;
		
		If DataItem.Count() = 0 Then
			
			Result = False;
			
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

// Fills values of attributes and tabular sections of infobase objects of the same type.
//
// Parameters:
//  Source - infobase object (CatalogObject, DocumentObject, ChartOfCharacteristicTypesObject, and 
//   so on) that is the data source.
//
//  Receiver (required) - an infobase object (CatalogObject, DocumentObject,
//  ChartOfCharacteristicTypesObject and so on) that will be filled with source data.
//
//  PropertiesList - String - a list of object properties and sections separated by commas.
//                           If the parameter is specified, object properties will be filled 
//                           according to the specified properties and the parameter.
//                           ExcludeProperties will be ignored.
//
//  ExcludeProperties - String -  a list of object properties and sections separated by commas.
//                           If this parameter is passed, all properties and tabular sections will 
//                           be filled, except the specified properties.
//
Procedure FillObjectPropertyValues(Destination, Source, Val PropertiesList = Undefined, Val ExcludeProperties = Undefined) Export
	
	If PropertiesList <> Undefined Then
		
		PropertiesList = StrReplace(PropertiesList, " ", "");
		
		PropertiesList = StrSplit(PropertiesList, ",");
		
		MetadataObject = Destination.Metadata();
		
		TabularSections = ObjectTabularSections(MetadataObject);
		
		HeaderPropertyList = New Array;
		UsedTabularSections = New Array;
		
		For Each Property In PropertiesList Do
			
			If TabularSections.Find(Property) <> Undefined Then
				
				UsedTabularSections.Add(Property);
				
			Else
				
				HeaderPropertyList.Add(Property);
				
			EndIf;
			
		EndDo;
		
		HeaderPropertyList = StrConcat(HeaderPropertyList, ",");
		
		FillPropertyValues(Destination, Source, HeaderPropertyList);
		
		For Each TabularSection In UsedTabularSections Do
			
			Destination[TabularSection].Load(Source[TabularSection].Unload());
			
		EndDo;
		
	ElsIf ExcludeProperties <> Undefined Then
		
		FillPropertyValues(Destination, Source,, ExcludeProperties);
		
		MetadataObject = Destination.Metadata();
		
		TabularSections = ObjectTabularSections(MetadataObject);
		
		For Each TabularSection In TabularSections Do
			
			If StrFind(ExcludeProperties, TabularSection) <> 0 Then
				Continue;
			EndIf;
			
			Destination[TabularSection].Load(Source[TabularSection].Unload());
			
		EndDo;
		
	Else
		
		FillPropertyValues(Destination, Source);
		
		MetadataObject = Destination.Metadata();
		
		TabularSections = ObjectTabularSections(MetadataObject);
		
		For Each TabularSection In TabularSections Do
			
			Destination[TabularSection].Load(Source[TabularSection].Unload());
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure RecordReferenceTypeObjectChangesByNodeProperties(Object, ReferenceTypeAttributeTable)
	
	InfobaseNode = Object.Ref;
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
	
	For Each TableRow In ReferenceTypeAttributeTable Do
		
		If IsBlankString(TableRow.TabularSectionName) Then // header attributes
			
			For Each Item In TableRow.RegistrationAttributesStructure Do
				
				Ref = Object[Item.Key];
				
				If Not Ref.IsEmpty()
					AND ExchangePlanCompositionContainsType(ExchangePlanName, TypeOf(Ref)) Then
					
					ExchangePlans.RecordChanges(InfobaseNode, Ref);
					
				EndIf;
				
			EndDo;
			
		Else // Tabular section attributes
			
			TabularSection = Object[TableRow.TabularSectionName];
			
			For Each TabularSectionRow In TabularSection Do
				
				For Each Item In TableRow.RegistrationAttributesStructure Do
					
					Ref = TabularSectionRow[Item.Key];
					
					If Not Ref.IsEmpty()
						AND ExchangePlanCompositionContainsType(ExchangePlanName, TypeOf(Ref)) Then
						
						ExchangePlans.RecordChanges(InfobaseNode, Ref);
						
					EndIf;
					
				EndDo;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function ReferenceTypeObjectAttributes(Object, ExchangePlanName)
	
	// Initializing the table.
	Result = DataExchangeServer.SelectiveObjectsRegistrationRulesTableInitialization();
	
	MetadataObject = Object.Metadata();
	MetadataObjectFullName = MetadataObject.FullName();
	
	// Getting header attributes
	Attributes = ReferenceTypeAttributes(MetadataObject.Attributes, ExchangePlanName);
	
	If Attributes.Count() > 0 Then
		
		TableRow = Result.Add();
		TableRow.ObjectName                     = MetadataObjectFullName;
		TableRow.TabularSectionName              = "";
		TableRow.RegistrationAttributes           = StructureKeysToString(Attributes);
		TableRow.RegistrationAttributesStructure = CopyStructure(Attributes);
		
	EndIf;
	
	// Getting tabular section attributes.
	For Each TabularSection In MetadataObject.TabularSections Do
		
		Attributes = ReferenceTypeAttributes(TabularSection.Attributes, ExchangePlanName);
		
		If Attributes.Count() > 0 Then
			
			TableRow = Result.Add();
			TableRow.ObjectName                     = MetadataObjectFullName;
			TableRow.TabularSectionName              = TabularSection.Name;
			TableRow.RegistrationAttributes           = StructureKeysToString(Attributes);
			TableRow.RegistrationAttributesStructure = CopyStructure(Attributes);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function ReferenceTypeAttributes(Attributes, ExchangePlanName)
	
	// Function return value.
	Result = New Structure;
	
	For Each Attribute In Attributes Do
		
		TypesArray = Attribute.Type.Types();
		
		IsReference = False;
		
		For Each Type In TypesArray Do
			
			If  Common.IsReference(Type)
				AND ExchangePlanCompositionContainsType(ExchangePlanName, Type) Then
				
				IsReference = True;
				
				Break;
				
			EndIf;
			
		EndDo;
		
		If IsReference Then
			
			Result.Insert(Attribute.Name);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function ExchangePlanCompositionContainsType(ExchangePlanName, Type)
	
	Return Metadata.ExchangePlans[ExchangePlanName].Content.Contains(Metadata.FindByType(Type));
	
EndFunction

// Creates a new instance of the Structure object. Fills the object with data of the specified structure.
//
// Parameters:
//  SourceStructure - Structure - structure to be copied.
//
// Returns:
//  Structure - copy of the passed structure.
//
Function CopyStructure(SourceStructure) Export
	
	ResultingStructure = New Structure;
	
	For Each Item In SourceStructure Do
		
		If TypeOf(Item.Value) = Type("ValueTable") Then
			
			ResultingStructure.Insert(Item.Key, Item.Value.Copy());
			
		ElsIf TypeOf(Item.Value) = Type("ValueTree") Then
			
			ResultingStructure.Insert(Item.Key, Item.Value.Copy());
			
		ElsIf TypeOf(Item.Value) = Type("Structure") Then
			
			ResultingStructure.Insert(Item.Key, CopyStructure(Item.Value));
			
		ElsIf TypeOf(Item.Value) = Type("ValueList") Then
			
			ResultingStructure.Insert(Item.Key, Item.Value.Copy());
			
		Else
			
			ResultingStructure.Insert(Item.Key, Item.Value);
			
		EndIf;
		
	EndDo;
	
	Return ResultingStructure;
EndFunction

// Gets a string that contains character-separated structure keys.
//
// Parameters:
//	Structure - Structure - a structure that contains keys to convert into a string.
//	Separator - String - the delimiter character.
//
// Returns:
//	String - the string that contains delimiter-separated structure keys.
//
Function StructureKeysToString(Structure, Separator = ",") Export
	
	Result = "";
	
	For Each Item In Structure Do
		
		SeparatorChar = ?(IsBlankString(Result), "", Separator);
		
		Result = Result + SeparatorChar + Item.Key;
		
	EndDo;
	
	Return Result;
EndFunction

// Compares two versions of objects of the same type.
//
// Parameters:
//  Data1 - CatalogObject,
//            DocumentObject,
//            ChartOfCharacteristicTypesObject,
//            ChartOfCalculationTypesObject,
//            ChartOfAccountsObject,
//            ExchangePlanObject,
//            BusinessProcessObject,
//            TaskObject - First version of data to be compared.
//  Data2 - CatalogObject,
//            DocumentObject,
//            ChartOfCharacteristicTypesObject,
//            ChartOfCalculationTypesObject,
//            ChartOfAccountsObject,
//            ExchangePlanObject,
//            BusinessProcessObject,
//            TaskObject - Second version of data to be compared.
//  PropertiesList - String - a list of object properties and sections separated by commas.
//                           If the parameter is specified, object properties will be filled 
//                           according to the specified properties and the parameter.
//                           ExcludeProperties will be ignored.
//  ExcludeProperties - String -  a list of object properties and sections separated by commas.
//                           If this parameter is passed, all properties and tabular sections will 
//                           be filled, except the specified properties.
//
// Returns:
//  True if data versions have differences. Otherwise, False.
//
Function DataDifferent(Data1, Data2, PropertiesList = Undefined, ExcludeProperties = Undefined) Export
	
	If TypeOf(Data1) <> TypeOf(Data2) Then
		Return True;
	EndIf;
	
	MetadataObject = Data1.Metadata();
	
	If Common.IsCatalog(MetadataObject) Then
		
		If Data1.IsFolder Then
			Object1 = Catalogs[MetadataObject.Name].CreateFolder();
		Else
			Object1 = Catalogs[MetadataObject.Name].CreateItem();
		EndIf;
		
		If Data2.IsFolder Then
			Object2 = Catalogs[MetadataObject.Name].CreateFolder();
		Else
			Object2 = Catalogs[MetadataObject.Name].CreateItem();
		EndIf;
		
	ElsIf Common.IsDocument(MetadataObject) Then
		
		Object1 = Documents[MetadataObject.Name].CreateDocument();
		Object2 = Documents[MetadataObject.Name].CreateDocument();
		
	ElsIf Common.IsChartOfCharacteristicTypes(MetadataObject) Then
		
		If Data1.IsFolder Then
			Object1 = ChartsOfCharacteristicTypes[MetadataObject.Name].CreateFolder();
		Else
			Object1 = ChartsOfCharacteristicTypes[MetadataObject.Name].CreateItem();
		EndIf;
		
		If Data2.IsFolder Then
			Object2 = ChartsOfCharacteristicTypes[MetadataObject.Name].CreateFolder();
		Else
			Object2 = ChartsOfCharacteristicTypes[MetadataObject.Name].CreateItem();
		EndIf;
		
	ElsIf Common.IsChartOfCalculationTypes(MetadataObject) Then
		
		Object1 = ChartsOfCalculationTypes[MetadataObject.Name].CreateCalculationType();
		Object2 = ChartsOfCalculationTypes[MetadataObject.Name].CreateCalculationType();
		
	ElsIf Common.IsChartOfAccounts(MetadataObject) Then
		
		Object1 = ChartsOfAccounts[MetadataObject.Name].CreateAccount();
		Object2 = ChartsOfAccounts[MetadataObject.Name].CreateAccount();
		
	ElsIf Common.IsExchangePlan(MetadataObject) Then
		
		Object1 = ExchangePlans[MetadataObject.Name].CreateNode();
		Object2 = ExchangePlans[MetadataObject.Name].CreateNode();
		
	ElsIf Common.IsBusinessProcess(MetadataObject) Then
		
		Object1 = BusinessProcesses[MetadataObject.Name].CreateBusinessProcess();
		Object2 = BusinessProcesses[MetadataObject.Name].CreateBusinessProcess();
		
	ElsIf Common.IsTask(MetadataObject) Then
		
		Object1 = Tasks[MetadataObject.Name].CreateTask();
		Object2 = Tasks[MetadataObject.Name].CreateTask();
		
	Else
		
		Raise NStr("ru = 'Задано недопустимое значение параметра [1] метода Common.PropertyValuesChanged.'; en = 'The value of the [1] parameter for the Common.PropertyValuesChanged method is not valid.PropertyValuesChanged.'; pl = 'Wartość [1] parametru dla metody Common.PropertyValuesChanged nie jest poprawna.PropertyValuesChanged.';es_ES = 'Valor inválido del parámetro [1] del método Common.PropertyValuesChanged está establecido.';es_CO = 'Valor inválido del parámetro [1] del método Common.PropertyValuesChanged está establecido.';tr = 'Common.PropertyValuesChanged yöntemi için [1] parametresinin değeri geçerli değil.';it = 'Il valore del parametro [1] per il metodo Common.PropertyValuesChanged non è valido.PropertyValuesChanged.';de = 'Der Wert des Parameters [1] für die Methode Common.PropertyValuesChanged ist nicht gültig.PropertyValuesChanged.'");
		
	EndIf;
	
	FillObjectPropertyValues(Object1, Data1, PropertiesList, ExcludeProperties);
	FillObjectPropertyValues(Object2, Data2, PropertiesList, ExcludeProperties);
	
	Return InfobaseDataString(Object1) <> InfobaseDataString(Object2);
	
EndFunction

Function InfobaseDataString(Data)
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	
	WriteXML(XMLWriter, Data, XMLTypeAssignment.Explicit);
	
	Return XMLWriter.Close();
	
EndFunction

// Returns an array of object tabular sections.
//
Function ObjectTabularSections(MetadataObject) Export
	
	Result = New Array;
	
	For Each TabularSection In MetadataObject.TabularSections Do
		
		Result.Add(TabularSection.Name);
		
	EndDo;
	
	Return Result;
EndFunction

//

Procedure SetNodeFilterValues(ExchangePlanNode, Settings) Export
	
	ExchangePlanName = ExchangePlanNode.Metadata().Name;
	
	SetValueOnNode(ExchangePlanNode, Settings);
	
EndProcedure

Procedure SetNodeDefaultValues(ExchangePlanNode, Settings) Export
	
	ExchangePlanName = ExchangePlanNode.Metadata().Name;
	
	SetValueOnNode(ExchangePlanNode, Settings);
	
EndProcedure

Procedure SetValueOnNode(ExchangePlanNode, Settings)
	
	ExchangePlanName = ExchangePlanNode.Metadata().Name;
	
	For Each Item In Settings Do
		
		varKey = Item.Key;
		Value = Item.Value;
		
		If ExchangePlanNode.Metadata().Attributes.Find(varKey) = Undefined
			AND ExchangePlanNode.Metadata().TabularSections.Find(varKey) = Undefined Then
			Continue;
		EndIf;
		
		If TypeOf(Value) = Type("Array") Then
			
			AttributeData = ReferenceTypeFromFirstAttributeOfExchangePlanTabularSection(ExchangePlanName, varKey);
			
			If AttributeData = Undefined Then
				Continue;
			EndIf;
			
			NodeTable = ExchangePlanNode[varKey];
			
			NodeTable.Clear();
			
			For Each TableRow In Value Do
				
				If TableRow.Use Then
					
					ObjectManager = Common.ObjectManagerByRef(AttributeData.Type.AdjustValue());
					
					AttributeValue = ObjectManager.GetRef(New UUID(TableRow.RefUUID));
					
					NodeTable.Add()[AttributeData.Name] = AttributeValue;
					
				EndIf;
				
			EndDo;
			
		ElsIf TypeOf(Value) = Type("Structure") Then
			
			FillExchangePlanNodeTable(ExchangePlanNode, Value, varKey);
			
		Else // Primitive types
			
			ExchangePlanNode[varKey] = Value;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure FillExchangePlanNodeTable(Node, TabularSectionStructure, TableName)
	
	NodeTable = Node[TableName];
	
	NodeTable.Clear();
	
	For Each Item In TabularSectionStructure Do
		
		While NodeTable.Count() < Item.Value.Count() Do
			NodeTable.Add();
		EndDo;
		
		NodeTable.LoadColumn(Item.Value, Item.Key);
		
	EndDo;
	
EndProcedure

Function ReferenceTypeFromFirstAttributeOfExchangePlanTabularSection(Val ExchangePlanName, Val TabularSectionName)
	
	TabularSection = Metadata.ExchangePlans[ExchangePlanName].TabularSections[TabularSectionName];
	
	For Each Attribute In TabularSection.Attributes Do
		
		Type = Attribute.Type.Types()[0];
		
		If Common.IsReference(Type) Then
			
			Return New Structure("Name, Type", Attribute.Name, Attribute.Type);
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
EndFunction

Procedure CheckDocumentIssueResolvedPosting(Source, Cancel, PostingMode) Export
	
	// There is no DataExchange.Import property value verification, because the code below implements 
	// the logic that must be executed, including when this property is set to True (on the side of the 
	// code that attempts to write the document and on document import).
	
	InformationRegisters.DataExchangeResults.RecordIssueResolved(Source, Enums.DataExchangeIssuesTypes.UnpostedDocument);
	
EndProcedure

Procedure CheckObjectIssueResolvedOnWrite(Source, Cancel) Export
	
	// There is no DataExchange.Import property value verification, because the code below implements 
	// the logic that must be executed, including when this property is set to True (on the side of the 
	// code that attempts to write the object and on object import).
	
	InformationRegisters.DataExchangeResults.RecordIssueResolved(Source, Enums.DataExchangeIssuesTypes.BlankAttributes);
	
EndProcedure

// Gets the current record set value in the infobase.
// 
// Parameters:
//	Data - a register record set.
// 
// Returns:
//	RecordSet containing the current value in the infobase.
// 
Function RecordSet(Val Data)
	
	MetadataObject = Data.Metadata();
	
	RecordSet = RecordSetByType(MetadataObject);
	
	For Each FilterValue In Data.Filter Do
		
		If FilterValue.Use = False Then
			Continue;
		EndIf;
		
		FIlterRow = RecordSet.Filter.Find(FilterValue.Name);
		FIlterRow.Value = FilterValue.Value;
		FIlterRow.Use = True;
		
	EndDo;
	
	RecordSet.Read();
	
	Return RecordSet;
	
EndFunction

#EndRegion

#Region DataChangeCollisionsOnExchangeOperations

// Checks whether there are import conflicts and displays information on whether there is an 
// exchange conflict.
Procedure CheckDataModificationConflict(DataItem, GetItem, Val Sender, Val IsDataReceiveFromMasterNode)
	
	If TypeOf(DataItem) = Type("ObjectDeletion") Then
		
		Return;
		
	ElsIf DataItem.AdditionalProperties.Property("DataExchange") AND DataItem.AdditionalProperties.DataExchange.DataAnalysis Then
		
		Return;
		
	EndIf;
	
	Sender = Sender.Ref;
	ObjectMetadata = DataItem.Metadata();
	IsReferenceType = Common.IsRefTypeObject(ObjectMetadata);
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(Sender);
	If Not DataExchangeCached.IsDistributedInfobaseExchangePlan(ExchangePlanName)
		AND Not DataExchangeCached.ExchangePlanContainsObject(ExchangePlanName, ObjectMetadata.FullName()) Then
		Return;
	EndIf;
	
	HasConflict = ExchangePlans.IsChangeRecorded(Sender, DataItem);
	
	// Executing an additional check on the object change if the object is not changed before the 
	// conflict and after the conflict, then we consider that there is no conflict.
	// 
	If HasConflict Then
		
		If IsReferenceType AND Not DataItem.Ref.IsEmpty() Then
			
			ObjectInInfobase = DataItem.Ref.GetObject();
			RefExists = (ObjectInInfobase <> Undefined);
			
		Else
			RefExists = False;
			ObjectInInfobase = Undefined;
		EndIf;
		
		ObjectRowBeforeChange    = ObjectDataAsStringBeforeChange(DataItem, ObjectMetadata, IsReferenceType, RefExists, ObjectInInfobase);
		ObjectRowAfterChange = ObjectDataAsStringAfterChange(DataItem, ObjectMetadata);
		
		// If these values are equal, there is no conflict.
		If ObjectRowBeforeChange = ObjectRowAfterChange Then
			
			HasConflict = False;
			
		EndIf;
		
	EndIf;
	
	If HasConflict Then
		
		DataExchangeOverridable.OnDataChangeConflict(DataItem, GetItem, Sender, IsDataReceiveFromMasterNode);
		
		If GetItem = DataItemReceive.Auto Then
			GetItem = ?(IsDataReceiveFromMasterNode, DataItemReceive.Accept, DataItemReceive.Ignore);
		EndIf;
		
		WriteObject = (GetItem = DataItemReceive.Accept);
		
		RecordWarningAboutConflictInEventLog(DataItem, ObjectMetadata, WriteObject, IsReferenceType);
		
		If Not IsReferenceType Then
			Return;
		EndIf;
			
		If DataExchangeCached.VersioningUsed(Sender) Then
			If RefExists Then
				
				If WriteObject Then
					Comment = NStr("ru = 'Предыдущая версия (автоматическое разрешение конфликта).'; en = 'The previous version (automatic conflict resolving).'; pl = 'Poprzednia wersja (automatyczne rozwiązywanie konfliktów).';es_ES = 'Versión previa (resolución automática del conflicto).';es_CO = 'Versión previa (resolución automática del conflicto).';tr = 'Önceki versiyon (otomatik çakışma çözümü).';it = 'La versione precedente (Risoluzione conflitti automatica).';de = 'Vorherige Version (automatische Konfliktlösung).'");
				Else
					Comment = NStr("ru = 'Текущая версия (автоматическое разрешение конфликта).'; en = 'The current version (automatic conflict resolving).'; pl = 'Bieżąca wersja (automatyczne rozwiązywanie konfliktów).';es_ES = 'Versión actual (resolución automática del conflicto).';es_CO = 'Versión actual (resolución automática del conflicto).';tr = 'Geçerli sürüm (otomatik çakışma çözümü).';it = 'La versione corrente (risoluzione conflitti automatica).';de = 'Aktuelle Version (automatische Konfliktlösung).'");
				EndIf;
				
				ObjectVersionInfo = New Structure("Comment, ObjectVersionType", Comment, "NotAcceptedCollisionData");
				OnCreateObjectVersion(ObjectInInfobase, ObjectVersionInfo, RefExists, Sender);
				
			EndIf;
			
			If WriteObject Then
				ObjectVersionInfo = New Structure;
				ObjectVersionInfo.Insert("VersionAuthor", Sender);
				ObjectVersionInfo.Insert("ObjectVersionType", "ConflictDataAccepted");
				ObjectVersionInfo.Insert("Comment", NStr("ru = 'Текущая версия (автоматическое разрешение конфликта).'; en = 'The current version (automatic conflict resolving).'; pl = 'Bieżąca wersja (automatyczne rozwiązywanie konfliktów).';es_ES = 'Versión actual (resolución automática del conflicto).';es_CO = 'Versión actual (resolución automática del conflicto).';tr = 'Geçerli sürüm (otomatik çakışma çözümü).';it = 'La versione corrente (risoluzione conflitti automatica).';de = 'Aktuelle Version (automatische Konfliktlösung).'"));
			Else
				ObjectVersionInfo = New Structure;
				ObjectVersionInfo.Insert("VersionAuthor", Sender);
				ObjectVersionInfo.Insert("ObjectVersionType", "NotAcceptedCollisionData");
				ObjectVersionInfo.Insert("Comment", NStr("ru = 'Отклоненная версия (автоматическое разрешение конфликта).'; en = 'The rejected version (automatic conflict resolving).'; pl = 'Odrzucona wersja (automatyczne rozwiązywanie konfliktów).';es_ES = 'Versión denegada (resolución automática del conflicto).';es_CO = 'Versión denegada (resolución automática del conflicto).';tr = 'Reddedilen sürüm (otomatik çakışma çözümü).';it = 'La versione rifiutata (risoluzione automatica di conflitto).';de = 'Abgelehnte Version (automatische Konfliktlösung).'"));
			EndIf;
			OnCreateObjectVersion(DataItem, ObjectVersionInfo, RefExists, Sender);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Checks whether the import restriction by date is enabled.
//
// Parameters:
//	DataElement	  - CatalogObject, DocumentObject, InformationRegisterRecordSet and other data.
//						Data that is read from the exchange message but is not yet written to the infobase.
//	GetItem - GetDataItem.
//	Sender		 - ExchangePlansObject.
//
Procedure CheckImportRestrictionByDate(DataItem, GetItem, Val Sender)
	
	If Sender.Metadata().DistributedInfoBase Then
		Return;
	EndIf;
	
	If Common.IsConstant(DataItem.Metadata()) Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDates = Common.CommonModule("PeriodClosingDates");
		
		Cancel = False;
		ErrorDescription = "";
		
		ModulePeriodClosingDates.CheckDataImportRestrictionDates(DataItem,
			Sender.Ref, Cancel, ErrorDescription);
		
		If Cancel Then
			RegisterDataImportRestrictionByDate(DataItem, Sender, ErrorDescription);
			GetItem = DataItemReceive.Ignore;
		EndIf;
		
	EndIf;
	
	DataItem.AdditionalProperties.Insert("SkipPeriodClosingCheck");
	
EndProcedure

// Records an event log message about the data import prohibition by date.
//  If the passed object has reference type and the ObjectVersioning subsystem is available, this 
// object is registered in the same way as in the exchange issue monitor.
// To check whether import prohibition by date is enabled, see common module procedure 
// PeriodClosingDates.CheckDataImportRestrictionDates.
//
// Parameters:
//	Object - a reference type object whose restriction is registered.
//	ExchangeNode - ExchangePlanRef - an infobase node the object is received from. 
//	ErrorMessage - String - detailed description of reason for import cancellation.
//
Procedure RegisterDataImportRestrictionByDate(DataItem, Sender, ErrorMessage)
	
	WriteLogEvent(DataExchangeServer.EventLogMessageTextDataExchange(),
		EventLogLevel.Warning, , DataItem, ErrorMessage);
	
	If DataExchangeCached.VersioningUsed(Sender.Ref) AND Common.IsRefTypeObject(DataItem.Metadata()) Then
		
		ObjectRef = DataItem.Ref;
		RefExists = Common.RefExists(ObjectRef);
		
		If RefExists Then
			
			ObjectInInfobase = ObjectRef.GetObject();
			
			Comment = NStr("ru = 'Версия создана при синхронизации данных.'; en = 'The object version is created during the data synchronization.'; pl = 'Wersja została utworzona podczas synchronizacji danych.';es_ES = 'Versión se ha creado durante la sincronización de datos.';es_CO = 'Versión se ha creado durante la sincronización de datos.';tr = 'Sürüm, veri senkronizasyonu sırasında oluşturuldu.';it = 'La versione dell''oggetto è creata durante la sincronizzazione dati.';de = 'Die Version wurde während der Datensynchronisierung erstellt.'");
			ObjectVersionInfo = New Structure("Comment", Comment);
			
			OnCreateObjectVersion(ObjectInInfobase, ObjectVersionInfo, RefExists, Sender);
			
			ErrorMessageString = ErrorMessage;
			ObjectVersionType = "RejectedDueToPeriodEndClosingDateObjectExistsInInfobase";
			
		Else
			
			ErrorMessageString = NStr("ru = '%1 запрещено загружать в запрещенный период.%2%2%3'; en = 'Importing %1 in the specified period is restricted.%2%2%3'; pl = '%1 nie można importować do zabronionego okresu.%2%2%3';es_ES = '%1 no puede importarse al período prohibido.%2%2%3';es_CO = '%1 no puede importarse al período prohibido.%2%2%3';tr = '%1 yasaklanmış dönemde içe aktarılamaz. %2%2%3';it = 'L''importazione di %1 nel periodo indicato non è permessa.%2%2%3';de = '%1 kann nicht in den verbotenen Zeitraum importiert werden. %2%2%3'");
			ErrorMessageString = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageString, String(DataItem), Chars.LF, ErrorMessage);
			ObjectVersionType = "RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase";
			
		EndIf;
		
		RejectedDueToPeriodEndClosingDate = New Map;
		If Not Sender.AdditionalProperties.Property("RejectedDueToPeriodEndClosingDate") Then
			Sender.AdditionalProperties.Insert("RejectedDueToPeriodEndClosingDate", RejectedDueToPeriodEndClosingDate);
		Else
			RejectedDueToPeriodEndClosingDate = Sender.AdditionalProperties.RejectedDueToPeriodEndClosingDate;
		EndIf;
		RejectedDueToPeriodEndClosingDate.Insert(ObjectRef, ObjectVersionType);
		
		ObjectVersionInfo = New Structure;
		ObjectVersionInfo.Insert("VersionAuthor", Common.ObjectManagerByRef(Sender.Ref).FindByCode(Sender.Code));
		ObjectVersionInfo.Insert("ObjectVersionType", ObjectVersionType);
		ObjectVersionInfo.Insert("Comment", ErrorMessageString);
		
		OnCreateObjectVersion(DataItem, ObjectVersionInfo, RefExists, Sender);
		
	EndIf;
	
EndProcedure

Procedure RecordWarningAboutConflictInEventLog(Object, ObjectMetadata, WriteObject, IsReferenceType)
	
	If WriteObject Then
		
		EventLogWarningText = NStr("ru = 'Возник конфликт изменений объектов.
		|Объект этой информационной базы был заменен версией объекта из второй информационной базы.'; 
		|en = 'An object change conflict occurred.
		|The object from this infobase is replaced with the object version from the second infobase.'; 
		|pl = 'Wystąpił konflikt zmian obiektów.
		| Obiekt tej bazy informacyjnej został zastąpiony przez drugą wersję obiektu bazy informacyjnej.';
		|es_ES = 'Conflicto de cambios de objeto ha aparecido.
		|Este objeto de la infobase se ha reemplazado por la versión del objeto de la segunda infobase.';
		|es_CO = 'Conflicto de cambios de objeto ha aparecido.
		|Este objeto de la infobase se ha reemplazado por la versión del objeto de la segunda infobase.';
		|tr = 'Nesne değişiklikleri çakışması ortaya çıktı. 
		|Bu veritabanı nesnesi, ikinci veritabanı nesnesinin sürümü ile değiştirildi.';
		|it = 'Si è verificato un conflitto di modifica a un oggetto.
		|L''oggetto da questa infobase è sostituito con la versione dell''oggetto dalla seconda infobase.';
		|de = 'Der Objektänderungskonflikt ist aufgetreten.
		|Dieses Infobase-Objekt wurde durch die zweite Infobase-Objektversion ersetzt.'");
		
	Else
		
		EventLogWarningText = NStr("ru = 'Возник конфликт изменений объектов.
		|Объект из второй информационной базы не принят. Объект этой информационной базы не изменен.'; 
		|en = 'An object change conflict occurred.
		|The object from the second infobase is not accepted. The object from this infobase is not changed.'; 
		|pl = 'Wystąpił konflikt zmian obiektu.
		|Obiekt z drugiej bazy informacyjnej nie jest akceptowany. Ten obiekt bazy informacyjnej nie został zmodyfikowany.';
		|es_ES = 'Conflicto de cambios de objeto ha aparecido.
		|El objeto de la segunda infobase no se ha aceptado. Este objeto de la infobase no se ha modificado.';
		|es_CO = 'Conflicto de cambios de objeto ha aparecido.
		|El objeto de la segunda infobase no se ha aceptado. Este objeto de la infobase no se ha modificado.';
		|tr = 'Nesne değişiklikleri çakışması ortaya çıktı. 
		|İkinci veritabanındaki nesne kabul edilmedi. Bu veritabanı nesnesi değiştirilmedi.';
		|it = 'Si è verificato un conflitto di modifica dell''oggetto.
		|L''oggetto dalla seconda infobase non è accettato. L''oggetto da questa infobase non è modificato.';
		|de = 'Der Objektänderungskonflikt ist aufgetreten.
		|Objekt aus der zweiten Infobase wird nicht akzeptiert. Dieses Infobase-Objekt wurde nicht geändert.'");
		
	EndIf;
	
	Data = ?(IsReferenceType, Object.Ref, Undefined);
		
	WriteLogEvent(DataExchangeServer.EventLogMessageTextDataExchange(),
		EventLogLevel.Warning, ObjectMetadata, Data, EventLogWarningText);
	
EndProcedure

Function ObjectDataAsStringBeforeChange(Object, ObjectMetadata, IsReferenceType, RefExists, ObjectInInfobase)
	
	// Function return value.
	ObjectString = "";
	
	If IsReferenceType Then
		
		If RefExists Then
			
			// Getting object presentation by the reference from the infobase.
			ObjectString = Common.ValueToXMLString(ObjectInInfobase);
			
		Else
			
			ObjectString = NStr("ru = 'Объект удален'; en = 'Object is deleted'; pl = 'Obiekt został usunięty';es_ES = 'Objeto se ha eliminado';es_CO = 'Objeto se ha eliminado';tr = 'Nesne kaldırıldı';it = 'Oggetto eliminato';de = 'Das Objekt wurde entfernt'");
			
		EndIf;
		
	ElsIf Common.IsConstant(ObjectMetadata) Then
		
		// Getting constant value from the infobase.
		ObjectString = XMLString(Constants[ObjectMetadata.Name].Get());
		
	Else // Record set
		
		PreviousRecordSet = RecordSet(Object);
		ObjectString = Common.ValueToXMLString(PreviousRecordSet);
		
	EndIf;
	
	Return ObjectString;
	
EndFunction

Function ObjectDataAsStringAfterChange(Object, ObjectMetadata)
	
	// Function return value.
	ObjectString = "";
	
	If Common.IsConstant(ObjectMetadata) Then
		
		ObjectString = XMLString(Object.Value);
		
	Else
		
		ObjectString = Common.ValueToXMLString(Object);
		
	EndIf;
	
	Return ObjectString;
	
EndFunction

// Creates an object version and writes it to the infobase.
//
// Parameters:
//  Object - an infobase object to be written.
//  RefExists - Boolean - flag specifying whether the referenced object exists in the infobase.
//  ObjectVersionDetails - Structure - object version information:
//    * VersionAuthor - User or Exchange plan node - version source.
//        Optional, the default value is Undefined.
//    * ObjectVersionType - String - a type of version to create.
//        Optional, the default value is ChangedByUser.
//    * Comment - String - Comment to version to create.
//        Optional, the default value is "".
//
Procedure OnCreateObjectVersion(Object, ObjectVersionInfo, RefExists, Sender)
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		
		NewObjectVersionInfo = New Structure;
		NewObjectVersionInfo.Insert("VersionAuthor", Undefined);
		NewObjectVersionInfo.Insert("ObjectVersionType", "ChangedByUser");
		NewObjectVersionInfo.Insert("Comment", "");
		FillPropertyValues(NewObjectVersionInfo, ObjectVersionInfo);
		
		ModuleObjectVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectVersioning.CreateObjectVersionByDataExchange(Object, NewObjectVersionInfo, RefExists, Sender);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
