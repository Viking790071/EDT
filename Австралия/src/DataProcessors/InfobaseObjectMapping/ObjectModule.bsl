#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var MappingTableField;
Var ObjectMappingStatisticsField;
Var MappingDigestField;
Var UnlimitedLengthStringTypeField;

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// Maps objects from the current infobase to objects from the source Infobase.
//  Generates a mapping table to be displayed to the user.
//  Detects the following types of object mapping:
// - objects mapped using references
// - objects mapped using InfobaseObjectsMaps information register data.
// - objects mapped using unapproved mapping - mapping items that are not written to the infobase (current changes)
// - unmapped source objects.
// - unmapped destination objects (of the current infobase).
//
// Parameters:
//     Cancel - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
// 
Procedure MapObjects(Cancel) Export
	
	SetPrivilegedMode(True);
	
	// Executing infobase object mapping.
	ExecuteInfobaseObjectMapping(Cancel);
	
EndProcedure

// Maps objects automatically using the mapping fields specified by the user (search fields).
//  Compares mapping fields using strict equality.
//  Generates a table of automatic mapping to be displayed to the user.
//
// Parameters:
//     Cancel - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
//     MappingFieldList - ValueList - a value list with fields that will be used to map objects.
//                                                 
// 
Procedure ExecuteAutomaticObjectMapping(Cancel, MappingFieldsList) Export
	
	SetPrivilegedMode(True);
	
	ExecuteAutomaticInfobaseObjectMapping(Cancel, MappingFieldsList);
	
EndProcedure

// Maps objects automatically using the default search fields.
// The list of mapping fields is equal to the list of used fields.
//
// Parameters:
//      Cancel - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
// 
Procedure ExecuteDefaultAutomaticMapping(Cancel) Export
	
	SetPrivilegedMode(True);
	
	// With default automatic mapping, the list of mapping fields is equal to the list of used fields.
	// 
	MappingFieldsList = UsedFieldsList.Copy();
	
	ExecuteDefaultAutomaticInfobaseObjectMapping(Cancel, MappingFieldsList);
	
	// Applying the automatic mapping result.
	ApplyUnapprovedRecordsTable(Cancel);
	
EndProcedure

// Writes unapproved mapping references (current changes) into the Infobase.
// Records are stored in the InfobaseObjectMaps information register.
//
// Parameters:
//      Cancel - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
// 
Procedure ApplyUnapprovedRecordsTable(Cancel) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	
	Try
		
		For Each TableRow In UnapprovedMappingTable Do
			
			If DataExchangeServer.IsXDTOExchangePlan(InfobaseNode) Then
				
				If String(TableRow.SourceUUID.UUID()) = TableRow.DestinationUID
					OR Not ValueIsFilled(TableRow.DestinationUID) Then
					Continue;
				EndIf;
				
				RecordStructure = New Structure("Ref, ID");
				
				RecordStructure.Insert("InfobaseNode", InfobaseNode);
				RecordStructure.Insert("Ref", TableRow.SourceUUID);
				RecordStructure.Insert("ID", TableRow.DestinationUID);
				
				InformationRegisters.SynchronizedObjectPublicIDs.AddRecord(RecordStructure);
				
			Else
				
				RecordStructure = New Structure("SourceUUID, DestinationUID, SourceType, DestinationType");
				
				RecordStructure.Insert("InfobaseNode", InfobaseNode);
				
				FillPropertyValues(RecordStructure, TableRow);
				
				InformationRegisters.InfobaseObjectsMaps.AddRecord(RecordStructure);
				
			EndIf;
			
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("ru = 'Обмен данными'; en = 'Data exchange'; pl = 'Wymiana danych';es_ES = 'Intercambio de datos';es_CO = 'Intercambio de datos';tr = 'Veri değişimi';it = 'Scambio dati';de = 'Datenaustausch'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Cancel = True;
		Return;
	EndTry;
	
	UnapprovedMappingTable.Clear();
	
EndProcedure

// Retrieves object mapping statistic data.
// The MappingDigest() property is initialized.
//
// Parameters:
//      Cancel - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
// 
Procedure GetObjectMappingDigestInfo(Cancel) Export
	
	SetPrivilegedMode(True);
	
	SourceTable = SourceInfobaseData(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Specifying a blank array of user fields because there is no need to select fields.
	UserFields = New Array;
	
	TempTablesManager = New TempTablesManager;
	
	// Getting object mapping tables (mapped, unmapped).
	ObjectsMappingData(SourceTable, UserFields, TempTablesManager);
	
	// Getting object mapping digest data.
	GetMappingDigest(TempTablesManager);
	
	TempTablesManager.Close();
	
EndProcedure

// Imports data from an exchange message file to an infobase of the specified object types only.
//
// Parameters:
//      Cancel - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
//      TablesToImport - Array - an array of types to be imported from the exchange message; array item -
//                                    String.
// 
Procedure ExecuteDataImportForInfobase(Cancel, TablesToImport) Export
	
	SetPrivilegedMode(True);
	
	DataImportedSuccessfully = False;
	
	ExchangeSettingsStructure = DataExchangeServer.ExchangeSettingsStructureForInteractiveImportSession(InfobaseNode, ExchangeMessageFileName);
	
	If ExchangeSettingsStructure.Cancel Then
		Return;
	EndIf;
	
	DataExchangeDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
	
	DataExchangeDataProcessor.ExecuteDataImportForInfobase(TablesToImport);
	
	// Deleting tables imported to the infobase from the data processor cache, because they are obsolete.
	For Each Item In TablesToImport Do
		DataExchangeDataProcessor.DataTablesExchangeMessages().Delete(Item);
	EndDo;
	
	If DataExchangeDataProcessor.ErrorFlag() Then
		NString = NStr("ru = 'При загрузке сообщения обмена возникли ошибки: %1'; en = 'Error importing the exchange message: %1'; pl = 'Podczas importu wiadomości wymiany wystąpiły błędy: %1';es_ES = 'Errores ocurridos al importar el mensaje de intercambio: %1';es_CO = 'Errores ocurridos al importar el mensaje de intercambio: %1';tr = 'Değişim mesajları alınırken hatalar oluştu: %1';it = 'Errore durante l''importazione del messaggio di scambio: %1';de = 'Beim Importieren der Austauschnachricht sind Fehler aufgetreten: %1'");
		NString = StringFunctionsClientServer.SubstituteParametersToString(NString, DataExchangeDataProcessor.ErrorMessageString());
		CommonClientServer.MessageToUser(NString,,,, Cancel);
		Return;
	EndIf;
	
	DataImportedSuccessfully = Not DataExchangeDataProcessor.ErrorFlag();
	
EndProcedure

// Data processor constructor.
//
Procedure Designer() Export
	
	// Filling table field list. Fields from this list can be mapped and displayed (search fields).
	TableFieldsList.LoadValues(StrSplit(DestinationTableFields, ",", False));
	
	SearchFieldArray = StrSplit(DestinationTableSearchFields, ",", False);
	
	// Selecting search fields if they are not specified.
	If SearchFieldArray.Count() = 0 Then
		
		// for catalogs
		AddSearchField(SearchFieldArray, "Description");
		AddSearchField(SearchFieldArray, "Code");
		AddSearchField(SearchFieldArray, "Owner");
		AddSearchField(SearchFieldArray, "Parent");
		
		// For documents and business processes
		AddSearchField(SearchFieldArray, "Date");
		AddSearchField(SearchFieldArray, "Number");
		
		// Popular search fields
		AddSearchField(SearchFieldArray, "Organization");
		AddSearchField(SearchFieldArray, "TIN");
		AddSearchField(SearchFieldArray, "CRTR");
		
		If SearchFieldArray.Count() = 0 Then
			
			If TableFieldsList.Count() > 0 Then
				
				SearchFieldArray.Add(TableFieldsList[0].Value);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Deleting fields with indexes exceeding the specified limit from the search array.
	CheckMappingFieldCountInArray(SearchFieldArray);
	
	// Selecting search fields in TableFieldList
	For Each Item In TableFieldsList Do
		
		If SearchFieldArray.Find(Item.Value) <> Undefined Then
			
			Item.Check = True;
			
		EndIf;
		
	EndDo;
	
	FillListWithAdditionalParameters(TableFieldsList);
	
	// Filling UsedFieldList with selected items of TableFieldList
	FillListWithSelectedItems(TableFieldsList, UsedFieldsList);
	
	// Generating the sorting table.
	FillSortTable(UsedFieldsList);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

// object mapping table.
//
// Returns:
//      ValueTable - an object mapping table.
//
Function MappingTable() Export
	
	If TypeOf(MappingTableField) <> Type("ValueTable") Then
		
		MappingTableField = New ValueTable;
		
	EndIf;
	
	Return MappingTableField;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties - mapping digest.

// Retrieves the number of objects of the current data type in the exchange message file.
//
// Returns:
//     Number - a number of objects of the current data type in the exchange message file.
//
Function ObjectCountInSource() Export
	
	Return MappingDigest().ObjectCountInSource;
	
EndFunction

// number of objects of the current data type in this infobase.
//
// Returns:
//     Number - a number of objects of the current data type in this infobase.
//
Function ObjectCountInDestination() Export
	
	Return MappingDigest().ObjectCountInDestination;
	
EndFunction

// number of objects that are mapped for the current data type.
//
// Returns:
//     Number - a number of objects that are mapped for the current data type.
//
Function MappedObjectCount() Export
	
	Return MappingDigest().MappedObjectCount;
	
EndFunction

// number of objects that are not mapped for the current data type.
//
// Returns:
//     Number - a number of objects that are not mapped for the current data type.
//
Function UnmappedObjectCount() Export
	
	Return MappingDigest().UnmappedObjectCount;
	
EndFunction

// Retrieves object mapping percentage for the current data type.
//
// Returns:
//     Number - object mapping percentage for the current data type.
//
Function MappedObjectPercentage() Export
	
	Return MappingDigest().MappedObjectPercentage;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for retrieving local properties.

Function MappingDigest()
	
	If TypeOf(MappingDigestField) <> Type("Structure") Then
		
		// Initializing object mapping digest structure.
		MappingDigestField = New Structure;
		MappingDigestField.Insert("ObjectCountInSource",       0);
		MappingDigestField.Insert("ObjectCountInDestination",       0);
		MappingDigestField.Insert("MappedObjectCount",   0);
		MappingDigestField.Insert("UnmappedObjectCount", 0);
		MappingDigestField.Insert("MappedObjectPercentage",       0);
		
	EndIf;
	
	Return MappingDigestField;
	
EndFunction

Function ObjectMappingStatistics()
	
	If TypeOf(ObjectMappingStatisticsField) <> Type("Structure") Then
		
		// Initializing statistic data structure.
		ObjectMappingStatisticsField = New Structure;
		ObjectMappingStatisticsField.Insert("MappedByRegisterSourceObjectCount",    0);
		ObjectMappingStatisticsField.Insert("CountOfMappedByRegisterDestinationObjects",    0);
		ObjectMappingStatisticsField.Insert("MappedByUnapprovedRelationsObjectCount", 0);
		
	EndIf;
	
	Return ObjectMappingStatisticsField;
	
EndFunction

Function UnlimitedLengthStringType()
	
	If TypeOf(UnlimitedLengthStringTypeField) <> Type("TypeDescription") Then
		
		UnlimitedLengthStringTypeField = New TypeDescription("String",, New StringQualifiers(0));
		
	EndIf;
	
	Return UnlimitedLengthStringTypeField;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Receiving mapping table.

Procedure ExecuteInfobaseObjectMapping(Cancel)
	
	SourceTable = SourceInfobaseData(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Getting an array of fields that were selected by the user.
	UserFields = UsedFieldsList.UnloadValues();
	
	// The IsFolder field is always present for hierarchical catalogs.
	If UserFields.Find("IsFolder") = Undefined Then
		AddSearchField(UserFields, "IsFolder");
	EndIf;
	
	TempTablesManager = New TempTablesManager;
	
	// Getting object mapping tables (mapped, unmapped).
	ObjectsMappingData(SourceTable, UserFields, TempTablesManager);
	
	// Getting object mapping digest data.
	GetMappingDigest(TempTablesManager);
	
	// Generating mapping table.
	MappingTableField = ObjectMappingResult(SourceTable, UserFields, TempTablesManager);
	
	TempTablesManager.Close();
	
	// Sorting the table
	ExecuteTableSortingAtServer();
	
	// Adding the SerialNumber field and filling it.
	AddNumberFieldToMappingTable();
	
EndProcedure

Procedure ExecuteAutomaticInfobaseObjectMapping(Cancel, MappingFieldsList)
	
	SourceTable = SourceInfobaseData(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	// User fields are filled according to the following algorithm:
	// - adding fields selected by user to be displayed; - adding all other table fields.
	// 
	// Field order is important as it has influence on displaying automatic mapping result in the table.
	UserFields = New Array;
	
	For Each Item In UsedFieldsList Do
		
		UserFields.Add(Item.Value);
		
	EndDo;
	
	For Each Item In TableFieldsList Do
		
		If UserFields.Find(Item.Value) = Undefined Then
			
			UserFields.Add(Item.Value);
			
		EndIf;
		
	EndDo;
	
	// The mapping field list is filled according to the order of elements in the UserFields array.
	MappingFieldListNew = New ValueList;
	
	For Each Item In UserFields Do
		
		ListItem = MappingFieldsList.FindByValue(Item);
		
		MappingFieldListNew.Add(Item, ListItem.Presentation, ListItem.Check);
		
	EndDo;
	
	TempTablesManager = New TempTablesManager;
	
	// Getting object mapping tables (mapped, unmapped).
	ObjectsMappingData(SourceTable, UserFields, TempTablesManager);
	
	// Getting the table of automatic mapping.
	AutimaticMappingData(SourceTable, MappingFieldListNew, UserFields, TempTablesManager);
	
	// Loading the table of automatically mapped objects into the form attribute.
	AutomaticallyMappedObjectsTable.Load(AutomaticallyMappedObjectsTableGet(TempTablesManager, UserFields));
	
	TempTablesManager.Close();
	
EndProcedure

Procedure ExecuteDefaultAutomaticInfobaseObjectMapping(Cancel, MappingFieldsList)
	
	SourceTable = SourceInfobaseData(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Getting an array of fields that were selected by the user.
	UserFields = UsedFieldsList.UnloadValues();
	
	TempTablesManager = New TempTablesManager;
	
	// Getting object mapping tables (mapped, unmapped).
	ObjectsMappingData(SourceTable, UserFields, TempTablesManager);
	
	// Getting the table of automatic mapping.
	AutimaticMappingData(SourceTable, MappingFieldsList, UserFields, TempTablesManager);
	
	// Loading updated unapproved mapping table into the object attribute
	UnapprovedMappingTable.Load(MergeUnapprovedMappingTableAndAutomaticMappingTable(TempTablesManager));
	
	TempTablesManager.Close();
	
EndProcedure

Procedure ObjectsMappingData(SourceTable, UserFields, TempTablesManager)
	
	// receiving tables:
	//
	// SourceTable
	// UnapprovedMappingTable
	// InfobaseObjectsMapsRegisterTable.
	//
	// MappedSourceObjectsTableByRegister
	// MappedDestinationObjectsTableByRegister
	// MappedObjectsTableByUnapprovedMapping
	//
	// MappedObjectsTable
	//
	// UnmappedSourceObjectsTable
	// UnmappedDestinationObjectsTable
	//
	//
	
	QueryText = "
	|//////////////////////////////////////////////////////////////////////////////// {SourceTable}
	|SELECT
	|	
	|	#CUSTOM_FIELDS_SourceTable#
	|	
	|	SourceTableParameter.Ref                  AS Ref,
	|	SourceTableParameter.UUID AS UUID,
	|	&SourceType                                    AS ObjectType
	|INTO SourceTable
	|FROM
	|	&SourceTableParameter AS SourceTableParameter
	|WHERE
	|	SourceTableParameter.UUID <> """"
	|INDEX BY
	|	Ref,
	|	UUID
	|;
	|";
	
	If DataExchangeServer.IsXDTOExchangePlan(InfobaseNode) Then
		QueryText = QueryText + "
			|//////////////////////////////////////////////////////////////////////////////// {InfobaseObjectsMappingsRegisterTable}
			|SELECT
			|	Ref        AS SourceUUID,
			|	ID AS DestinationUID,
			|	""#SourceType#"" AS DestinationType,
			|	""#DestinationType#"" AS SourceType
			|INTO InfobaseObjectsMapsRegisterTable
			|FROM
			|	InformationRegister.SynchronizedObjectPublicIDs AS InfobaseObjectsMaps
			|WHERE
			|	  InfobaseObjectsMaps.InfobaseNode = &InfobaseNode
			|	AND InfobaseObjectsMaps.Ref REFS #DestinationTable#
			|
			|INDEX BY
			|	DestinationUID
			|;
			|";
	Else
		QueryText = QueryText + "
			|//////////////////////////////////////////////////////////////////////////////// {InfobaseObjectsMappingsRegisterTable}
			|SELECT
			|	SourceUUID,
			|	DestinationUID,
			|	DestinationType,
			|	SourceType
			|INTO InfobaseObjectsMapsRegisterTable
			|FROM
			|	InformationRegister.InfobaseObjectsMaps AS InfobaseObjectsMaps
			|WHERE
			|	  InfobaseObjectsMaps.InfobaseNode = &InfobaseNode
			|	AND InfobaseObjectsMaps.DestinationType = &SourceType
			|	AND InfobaseObjectsMaps.SourceType = &DestinationType
			|INDEX BY
			|	DestinationUID,
			|	DestinationType,
			|	SourceType
			|;
			|";
	EndIf;
	
	QueryText = QueryText + "
		|//////////////////////////////////////////////////////////////////////////////// {UnapprovedMappingTable}
		|SELECT
		|	
		|	SourceUUID,
		|	DestinationUID,
		|	DestinationType,
		|	SourceType
		|	
		|INTO UnapprovedMappingTable
		|FROM
		|	&UnapprovedMappingTable AS UnapprovedMappingTable
		|INDEX BY
		|	DestinationUID,
		|	DestinationType
		|;
		|";
		
	If DataExchangeServer.IsXDTOExchangePlan(InfobaseNode) Then
		QueryText = QueryText + "
			|//////////////////////////////////////////////////////////////////////////////// {MappedSourceObjectsTableByRegister}
			|SELECT
			|	
			|	#CUSTOM_FIELDS_MappingTable#
			|	
			|	#ORDER_FIELD_Destination#
			|	
			|	Ref,
			|	0 AS MappingStatus,               // mapped objects (0)
			|	0 AS MappingStatusAdditional, // mapped objects (0)
			|	
			|	ThisIsSourceGroup,
			|	ThisIsDestinationGroup,
			|	
			|	// {MAPPING REGISTER DATA}
			|	SourceUUID,
			|	DestinationUID,
			|	SourceType,
			|	DestinationType
			|INTO MappedSourceObjectsTableByRegister
			|FROM
			|	(SELECT
			|	
			|		#CUSTOM_FIELDS_MappedSourceObjectsTableByRegister_NestedQuery#
			|		
			|		ISNULL(InfobaseObjectsMaps.SourceUUID, DestinationTable.Ref) AS Ref,
			|		
			|		#SourceTableIsFolder#                      AS ThisIsSourceGroup,
			|		#InfobaseObjectsMapsIsFolder# AS ThisIsDestinationGroup,
			|	
			|		// {MAPPING REGISTER DATA}
			|		ISNULL(InfobaseObjectsMaps.SourceUUID, DestinationTable.Ref)                  AS DestinationUID,
			|		ISNULL(InfobaseObjectsMaps.DestinationUID, SourceTable.UUID) AS SourceUUID,
			|		ISNULL(InfobaseObjectsMaps.DestinationType, ""#SourceType#"")                                           AS SourceType,
			|		ISNULL(InfobaseObjectsMaps.SourceType, ""#DestinationType#"")                                           AS DestinationType
			|	FROM
			|		SourceTable AS SourceTable
			|	LEFT JOIN
			|		InfobaseObjectsMapsRegisterTable AS InfobaseObjectsMaps
			|	ON
			|		  InfobaseObjectsMaps.DestinationUID = SourceTable.UUID
			|		AND InfobaseObjectsMaps.SourceUUID REFS #DestinationTable#
			|	LEFT JOIN
			|		#DestinationTable# AS DestinationTable
			|	ON
			|		  SourceTable.Ref = DestinationTable.Ref
			|	WHERE
			|		NOT InfobaseObjectsMaps.SourceUUID IS NULL
			|		OR NOT DestinationTable.Ref IS NULL
			|	) AS NestedQuery
			|;
			|
			|//////////////////////////////////////////////////////////////////////////////// {MappedDestinationObjectsTableByRegister}
			|SELECT
			|	
			|	#CUSTOM_FIELDS_MappingTable#
			|	
			|	#ORDER_FIELD_Destination#
			|	
			|	Ref,
			|	0 AS MappingStatus,               // mapped objects (0)
			|	0 AS MappingStatusAdditional, // mapped objects (0)
			|	
			|	ThisIsSourceGroup,
			|	ThisIsDestinationGroup,
			|	
			|	// {MAPPING REGISTER DATA}
			|	SourceUUID,
			|	DestinationUID,
			|	SourceType,
			|	DestinationType
			|INTO MappedDestinationObjectsTableByRegister
			|FROM
			|	(SELECT
			|	
			|		#CUSTOM_FIELDS_MappedDestinationObjectsTableByRegister_NestedQuery#
			|		
			|		DestinationTable.Ref AS Ref,
			|	
			|		#DestinationTableIsFolder# AS ThisIsSourceGroup,
			|		#DestinationTableIsFolder# AS ThisIsDestinationGroup,
			|	
			|		// {MAPPING REGISTER DATA}
			|		InfobaseObjectsMaps.SourceUUID AS DestinationUID,
			|		InfobaseObjectsMaps.DestinationUID AS SourceUUID,
			|		InfobaseObjectsMaps.DestinationType                     AS SourceType,
			|		InfobaseObjectsMaps.SourceType                     AS DestinationType
			|	FROM
			|		#DestinationTable# AS DestinationTable
			|	LEFT JOIN
			|		InfobaseObjectsMapsRegisterTable AS InfobaseObjectsMaps
			|	ON
			|		  InfobaseObjectsMaps.SourceUUID = DestinationTable.Ref
			|	LEFT JOIN
			|		MappedSourceObjectsTableByRegister AS MappedSourceObjectsTableByRegister
			|	ON
			|		MappedSourceObjectsTableByRegister.Ref = DestinationTable.Ref
			|	
			|	WHERE
			|		NOT InfobaseObjectsMaps.SourceUUID IS NULL
			|		AND MappedSourceObjectsTableByRegister.Ref IS NULL
			|	) AS NestedQuery
			|;
			|
			|//////////////////////////////////////////////////////////////////////////////// {MappedObjectsTableByUnapprovedMapping}
			|SELECT
			|	
			|	#CUSTOM_FIELDS_MappingTable#
			|	
			|	#ORDER_FIELD_Destination#
			|	
			|	Ref,
			|	3 AS MappingStatus,               // unapproved mappings (3)
			|	0 AS MappingStatusAdditional, // mapped objects (0)
			|	
			|	ThisIsSourceGroup,
			|	ThisIsDestinationGroup,
			|	
			|	// {MAPPING REGISTER DATA}
			|	SourceUUID,
			|	DestinationUID,
			|	SourceType,
			|	DestinationType
			|INTO MappedObjectsTableByUnapprovedMapping
			|FROM
			|	(SELECT
			|	
			|		#CUSTOM_FIELDS_MappedObjectsTableByUnapprovedMapping_NestedQuery#
			|		
			|		UnapprovedMappingTable.SourceUUID AS Ref,
			|	
			|		#SourceTableIsFolder#            AS ThisIsSourceGroup,
			|		#UnapprovedMappingTableIsFolder# AS ThisIsDestinationGroup,
			|	
			|		// {MAPPING REGISTER DATA}
			|		UnapprovedMappingTable.SourceUUID AS DestinationUID,
			|		UnapprovedMappingTable.DestinationUID AS SourceUUID,
			|		UnapprovedMappingTable.DestinationType AS SourceType,
			|		UnapprovedMappingTable.SourceType AS DestinationType
			|	FROM
			|		SourceTable AS SourceTable
			|	LEFT JOIN
			|		UnapprovedMappingTable AS UnapprovedMappingTable
			|	ON
			|		  UnapprovedMappingTable.DestinationUID = SourceTable.UUID
			|		AND UnapprovedMappingTable.SourceUUID REFS #DestinationTable#
			|		
			|	WHERE
			|		NOT UnapprovedMappingTable.SourceUUID IS NULL
			|	) AS NestedQuery
			|;
			|";
	Else
		QueryText = QueryText + "
			|//////////////////////////////////////////////////////////////////////////////// {MappedSourceObjectsTableByRegister}
			|SELECT
			|	
			|	#CUSTOM_FIELDS_MappingTable#
			|	
			|	#ORDER_FIELD_Destination#
			|	
			|	Ref,
			|	0 AS MappingStatus,               // mapped objects (0)
			|	0 AS MappingStatusAdditional, // mapped objects (0)
			|	
			|	ThisIsSourceGroup,
			|	ThisIsDestinationGroup,
			|	
			|	// {MAPPING REGISTER DATA}
			|	SourceUUID,
			|	DestinationUID,
			|	SourceType,
			|	DestinationType
			|INTO MappedSourceObjectsTableByRegister
			|FROM
			|	(SELECT
			|	
			|		#CUSTOM_FIELDS_MappedSourceObjectsTableByRegister_NestedQuery#
			|		
			|		InfobaseObjectsMaps.SourceUUID AS Ref,
			|		
			|		#SourceTableIsFolder#                      AS ThisIsSourceGroup,
			|		#InfobaseObjectsMapsIsFolder# AS ThisIsDestinationGroup,
			|	
			|		// {MAPPING REGISTER DATA}
			|		InfobaseObjectsMaps.SourceUUID AS DestinationUID,
			|		InfobaseObjectsMaps.DestinationUID AS SourceUUID,
			|		InfobaseObjectsMaps.DestinationType                     AS SourceType,
			|		InfobaseObjectsMaps.SourceType                     AS DestinationType
			|	FROM
			|		SourceTable AS SourceTable
			|	LEFT JOIN
			|		InfobaseObjectsMapsRegisterTable AS InfobaseObjectsMaps
			|	ON
			|		  InfobaseObjectsMaps.DestinationUID = SourceTable.UUID
			|		AND InfobaseObjectsMaps.DestinationType                     = SourceTable.ObjectType
			|	WHERE
			|		NOT InfobaseObjectsMaps.SourceUUID IS NULL
			|	) AS NestedQuery
			|;
			|//////////////////////////////////////////////////////////////////////////////// {MappedDestinationObjectsTableByRegister}
			|SELECT
			|	
			|	#CUSTOM_FIELDS_MappingTable#
			|	
			|	#ORDER_FIELD_Destination#
			|	
			|	Ref,
			|	0 AS MappingStatus,               // mapped objects (0)
			|	0 AS MappingStatusAdditional, // mapped objects (0)
			|	
			|	ThisIsSourceGroup,
			|	ThisIsDestinationGroup,
			|	
			|	// {MAPPING REGISTER DATA}
			|	SourceUUID,
			|	DestinationUID,
			|	SourceType,
			|	DestinationType
			|INTO MappedDestinationObjectsTableByRegister
			|FROM
			|	(SELECT
			|	
			|		#CUSTOM_FIELDS_MappedDestinationObjectsTableByRegister_NestedQuery#
			|		
			|		DestinationTable.Ref AS Ref,
			|	
			|		#DestinationTableIsFolder# AS ThisIsSourceGroup,
			|		#DestinationTableIsFolder# AS ThisIsDestinationGroup,
			|	
			|		// {MAPPING REGISTER DATA}
			|		InfobaseObjectsMaps.SourceUUID AS DestinationUID,
			|		InfobaseObjectsMaps.DestinationUID AS SourceUUID,
			|		InfobaseObjectsMaps.DestinationType                     AS SourceType,
			|		InfobaseObjectsMaps.SourceType                     AS DestinationType
			|	FROM
			|		#DestinationTable# AS DestinationTable
			|	LEFT JOIN
			|		InfobaseObjectsMapsRegisterTable AS InfobaseObjectsMaps
			|	ON
			|		  InfobaseObjectsMaps.SourceUUID = DestinationTable.Ref
			|		AND InfobaseObjectsMaps.SourceType                     = &DestinationType
			|	LEFT JOIN
			|		MappedSourceObjectsTableByRegister AS MappedSourceObjectsTableByRegister
			|	ON
			|		MappedSourceObjectsTableByRegister.Ref = DestinationTable.Ref
			|	
			|	WHERE
			|		NOT InfobaseObjectsMaps.SourceUUID IS NULL
			|		AND MappedSourceObjectsTableByRegister.Ref IS NULL
			|	) AS NestedQuery
			|;
			|
			|//////////////////////////////////////////////////////////////////////////////// {MappedObjectsTableByUnapprovedMapping}
			|SELECT
			|	
			|	#CUSTOM_FIELDS_MappingTable#
			|	
			|	#ORDER_FIELD_Destination#
			|	
			|	Ref,
			|	3 AS MappingStatus,               // unapproved mappings (3)
			|	0 AS MappingStatusAdditional, // mapped objects (0)
			|	
			|	ThisIsSourceGroup,
			|	ThisIsDestinationGroup,
			|	
			|	// {MAPPING REGISTER DATA}
			|	SourceUUID,
			|	DestinationUID,
			|	SourceType,
			|	DestinationType
			|INTO MappedObjectsTableByUnapprovedMapping
			|FROM
			|	(SELECT
			|	
			|		#CUSTOM_FIELDS_MappedObjectsTableByUnapprovedMapping_NestedQuery#
			|		
			|		UnapprovedMappingTable.SourceUUID AS Ref,
			|	
			|		#SourceTableIsFolder#            AS ThisIsSourceGroup,
			|		#UnapprovedMappingTableIsFolder# AS ThisIsDestinationGroup,
			|	
			|		// {MAPPING REGISTER DATA}
			|		UnapprovedMappingTable.SourceUUID AS DestinationUID,
			|		UnapprovedMappingTable.DestinationUID AS SourceUUID,
			|		UnapprovedMappingTable.DestinationType AS SourceType,
			|		UnapprovedMappingTable.SourceType AS DestinationType
			|	FROM
			|		SourceTable AS SourceTable
			|	LEFT JOIN
			|		UnapprovedMappingTable AS UnapprovedMappingTable
			|	ON
			|		  UnapprovedMappingTable.DestinationUID = SourceTable.UUID
			|		AND UnapprovedMappingTable.DestinationType                     = SourceTable.ObjectType
			|		
			|	WHERE
			|		NOT UnapprovedMappingTable.SourceUUID IS NULL
			|	) AS NestedQuery
			|;
			|";
	EndIf;
	
	QueryText = QueryText + "
		|//////////////////////////////////////////////////////////////////////////////// {MappedObjectsTable}
		|SELECT
		|	
		|	#CUSTOM_FIELDS_MappingTable#
		|	
		|	#ORDER_FIELDS#
		|	
		|	Ref,
		|	MappingStatus,
		|	MappingStatusAdditional,
		|	
		|	// {PICTURE INDEX}
		|	CASE WHEN ThisIsSourceGroup IS NULL
		|	THEN 0
		|	ELSE
		|		CASE WHEN ThisIsSourceGroup = TRUE
		|		THEN 1
		|		ELSE 2
		|		END
		|	END AS SourcePictureIndex,
		|	
		|	CASE WHEN ThisIsDestinationGroup IS NULL
		|	THEN 0
		|	ELSE
		|		CASE WHEN ThisIsDestinationGroup = TRUE
		|		THEN 1
		|		ELSE 2
		|		END
		|	END AS DestinationPictureIndex,
		|	
		|	// {MAPPING REGISTER DATA}
		|	SourceUUID,
		|	DestinationUID,
		|	SourceType,
		|	DestinationType
		|INTO MappedObjectsTable
		|FROM
		|	(
		|	SELECT
		|	
		|		#CUSTOM_FIELDS_MappingTable#
		|	
		|		#ORDER_FIELDS#
		|	
		|		Ref,
		|		MappingStatus,
		|		MappingStatusAdditional,
		|	
		|		ThisIsSourceGroup,
		|		ThisIsDestinationGroup,
		|	
		|		// {MAPPING REGISTER DATA}
		|		SourceUUID,
		|		DestinationUID,
		|		SourceType,
		|		DestinationType
		|	FROM
		|		MappedSourceObjectsTableByRegister
		|	
		|	UNION ALL
		|	
		|	SELECT
		|	
		|		#CUSTOM_FIELDS_MappingTable#
		|	
		|		#ORDER_FIELDS#
		|	
		|		Ref,
		|		MappingStatus,
		|		MappingStatusAdditional,
		|	
		|		ThisIsSourceGroup,
		|		ThisIsDestinationGroup,
		|	
		|		// {MAPPING REGISTER DATA}
		|		SourceUUID,
		|		DestinationUID,
		|		SourceType,
		|		DestinationType
		|	FROM
		|		MappedDestinationObjectsTableByRegister
		|	
		|	UNION ALL
		|	
		|	SELECT
		|	
		|		#CUSTOM_FIELDS_MappingTable#
		|	
		|		#ORDER_FIELDS#
		|	
		|		Ref,
		|		MappingStatus,
		|		MappingStatusAdditional,
		|	
		|		ThisIsSourceGroup,
		|		ThisIsDestinationGroup,
		|	
		|		// {MAPPING REGISTER DATA}
		|		SourceUUID,
		|		DestinationUID,
		|		SourceType,
		|		DestinationType
		|	FROM
		|		MappedObjectsTableByUnapprovedMapping
		|	
		|	) AS NestedQuery
		|	
		|INDEX BY
		|	Ref
		|;
		|
		|//////////////////////////////////////////////////////////////////////////////// {UnmappedSourceObjectsTable}
		|SELECT
		|	
		|	Ref,
		|	
		|	#CUSTOM_FIELDS_MappingTable#
		|	
		|	#ORDER_FIELD_Source#
		|	
		|	-1 AS MappingStatus,               // unmapped source objects (-1)
		|	 1 AS MappingStatusAdditional, // unmapped objects (1)
		|	
		|	// {PICTURE INDEX}
		|	CASE WHEN ThisIsSourceGroup IS NULL
		|	THEN 0
		|	ELSE
		|		CASE WHEN ThisIsSourceGroup = TRUE
		|		THEN 1
		|		ELSE 2
		|		END
		|	END AS SourcePictureIndex,
		|	
		|	CASE WHEN ThisIsDestinationGroup IS NULL
		|	THEN 0
		|	ELSE
		|		CASE WHEN ThisIsDestinationGroup = TRUE
		|		THEN 1
		|		ELSE 2
		|		END
		|	END AS DestinationPictureIndex,
		|	
		|	// {MAPPING REGISTER DATA}
		|	SourceUUID,
		|	DestinationUID,
		|	SourceType,
		|	DestinationType
		|INTO UnmappedSourceObjectsTable
		|FROM
		|	(SELECT
		|		Count(*),
		|		ThisIsSourceGroup,
		|		ThisIsDestinationGroup,
		|		Ref,
		|		#CUSTOM_FIELDS_MappingTable#
		|		DestinationUID,
		|		SourceUUID,
		|		SourceType,
		|		DestinationType
		|	FROM
		|		(SELECT
		|	
		|			#SourceTableIsFolder# AS ThisIsSourceGroup,
		|			NULL                        AS ThisIsDestinationGroup,
		|		
		|			SourceTable.Ref AS Ref,
		|		
		|			#CUSTOM_FIELDS_UnmappedSourceObjectsTable_NestedQuery#
		|		
		|			// {MAPPING REGISTER DATA}
		|			NULL                                     AS DestinationUID,
		|			SourceTable.UUID AS SourceUUID,
		|			&SourceType                            AS SourceType,
		|			&DestinationType                            AS DestinationType
		|		FROM
		|			SourceTable AS SourceTable
		|		LEFT JOIN
		|			MappedObjectsTable AS MappedObjectsTable
		|		ON
		|			SourceTable.Ref = MappedObjectsTable.Ref
		|		WHERE
		|			MappedObjectsTable.SourceUUID IS NULL
		|
		|		UNION ALL
		|
		|		SELECT
		|			#SourceTableIsFolder#,
		|			NULL,
		|		
		|			SourceTable.Ref,
		|		
		|			#CUSTOM_FIELDS_UnmappedSourceObjectsTable_NestedQuery1#
		|		
		|			// {MAPPING REGISTER DATA}
		|			NULL,
		|			SourceTable.UUID,
		|			&SourceType,
		|			&DestinationType
		|		FROM
		|			SourceTable AS SourceTable
		|		LEFT JOIN
		|			MappedObjectsTable AS MappedObjectsTable
		|		ON
		|			SourceTable.UUID = MappedObjectsTable.SourceUUID
		|		WHERE
		|			MappedObjectsTable.Ref IS NULL
		|		) AS NestedQueryPreliminary
		|	GROUP BY
		|		ThisIsSourceGroup,
		|		ThisIsDestinationGroup,
		|		Ref,
		|		#CUSTOM_FIELDS_MappingTable#
		|		DestinationUID,
		|		SourceUUID,
		|		SourceType,
		|		DestinationType
		|	HAVING Count(*) > 1) AS NestedQuery
		|;
		|
		|//////////////////////////////////////////////////////////////////////////////// {UnmappedDestinationObjectsTable}
		|SELECT
		|	
		|	Ref,
		|	
		|	#CUSTOM_FIELDS_MappingTable#
		|	
		|	#ORDER_FIELD_Destination#
		|	
		|	1 AS MappingStatus,               // unmapped destination objects (1)
		|	1 AS MappingStatusAdditional, // unmapped objects (1)
		|	
		|	// {PICTURE INDEX}
		|	CASE WHEN ThisIsSourceGroup IS NULL
		|	THEN 0
		|	ELSE
		|		CASE WHEN ThisIsSourceGroup = TRUE
		|		THEN 1
		|		ELSE 2
		|		END
		|	END AS SourcePictureIndex,
		|	
		|	CASE WHEN ThisIsDestinationGroup IS NULL
		|	THEN 0
		|	ELSE
		|		CASE WHEN ThisIsDestinationGroup = TRUE
		|		THEN 1
		|		ELSE 2
		|		END
		|	END AS DestinationPictureIndex,
		|	
		|	// {MAPPING REGISTER DATA}
		|	SourceUUID,
		|	DestinationUID,
		|	SourceType,
		|	DestinationType
		|INTO UnmappedDestinationObjectsTable
		|FROM
		|	(SELECT
		|	
		|		DestinationTable.Ref AS Ref,
		|	
		|		#CUSTOM_FIELDS_UnmappedDestinationObjectsTable_NestedQuery#
		|		
		|		NULL                        AS ThisIsSourceGroup,
		|		#DestinationTableIsFolder# AS ThisIsDestinationGroup,
		|		
		|		// {MAPPING REGISTER DATA}
		|		DestinationTable.Ref       AS DestinationUID,
		|		Undefined                  AS SourceUUID,
		|		Undefined                  AS SourceType,
		|		&DestinationType                 AS DestinationType
		|	FROM
		|		#DestinationTable# AS DestinationTable
		|	LEFT JOIN
		|		MappedObjectsTable AS MappedObjectsTable
		|	ON
		|		DestinationTable.Ref = MappedObjectsTable.Ref
		|	WHERE
		|		MappedObjectsTable.DestinationUID IS NULL
		|	) AS NestedQuery
		|;
		|
		|";
	
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_SourceTable#", GetUserFields(UserFields, "SourceTableParameter.# AS #,"));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_MappingTable#", GetUserFields(UserFields, "SourceFieldNN, DestinationFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_MappedObjectsTableByRef_NestedQuery#", GetUserFields(UserFields, "DestinationTable.# AS DestinationFieldNN, SourceTable.# AS SourceFieldNN,"));
	
	If DataExchangeServer.IsXDTOExchangePlan(InfobaseNode) Then
		QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_MappedSourceObjectsTableByRegister_NestedQuery#", GetUserFields(UserFields, "CAST(ISNULL(InfobaseObjectsMaps.SourceUUID, DestinationTable.Ref) AS [DestinationTableName]).# AS DestinationFieldNN, SourceTable.# AS SourceFieldNN,"));
	Else
		QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_MappedSourceObjectsTableByRegister_NestedQuery#", GetUserFields(UserFields, "CAST(InfobaseObjectsMaps.SourceUUID AS [DestinationTableName]).# AS DestinationFieldNN, SourceTable.# AS SourceFieldNN,"));
	EndIf;
	
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_MappedDestinationObjectsTableByRegister_NestedQuery#", GetUserFields(UserFields, "DestinationTable.# AS DestinationFieldNN, NULL AS SourceFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_MappedObjectsTableByUnapprovedMapping_NestedQuery#", GetUserFields(UserFields, "CAST(UnapprovedMappingTable.SourceUUID AS [DestinationTableName]).# AS DestinationFieldNN, SourceTable.# AS SourceFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_UnmappedSourceObjectsTable_NestedQuery#", GetUserFields(UserFields, "SourceTable.# AS SourceFieldNN, NULL AS DestinationFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_UnmappedSourceObjectsTable_NestedQuery1#", GetUserFields(UserFields, "SourceTable.#, NULL,"));

	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_UnmappedDestinationObjectsTable_NestedQuery#", GetUserFields(UserFields, "NULL AS SourceFieldNN, DestinationTable.Ref.# AS DestinationFieldNN,"));
	
	QueryText = StrReplace(QueryText, "#ORDER_FIELD_Source#", GetUserFields(UserFields, "SourceFieldNN AS OrderFieldNN,"));
	QueryText = StrReplace(QueryText, "#ORDER_FIELD_Destination#", GetUserFields(UserFields, "DestinationFieldNN AS OrderFieldNN,"));
	
	QueryText = StrReplace(QueryText, "#ORDER_FIELDS#", GetUserFields(UserFields, "OrderFieldNN,"));
	QueryText = StrReplace(QueryText, "#DestinationTable#", DestinationTableName);
	
	If UserFields.Find("IsFolder") <> Undefined Then
		
		QueryText = StrReplace(QueryText, "#SourceTableIsFolder#",            "SourceTable.IsFolder");
		QueryText = StrReplace(QueryText, "#DestinationTableIsFolder#",            "DestinationTable.IsFolder");
		QueryText = StrReplace(QueryText, "#UnapprovedMappingTableIsFolder#", "CAST(UnapprovedMappingTable.SourceUUID AS [DestinationTableName]).IsFolder");
		QueryText = StrReplace(QueryText, "#InfobaseObjectsMapsIsFolder#", "CAST(InfobaseObjectsMaps.SourceUUID AS [DestinationTableName]).IsFolder");
		
	Else
		
		QueryText = StrReplace(QueryText, "#SourceTableIsFolder#",            "NULL");
		QueryText = StrReplace(QueryText, "#DestinationTableIsFolder#",            "NULL");
		QueryText = StrReplace(QueryText, "#UnapprovedMappingTableIsFolder#", "NULL");
		QueryText = StrReplace(QueryText, "#InfobaseObjectsMapsIsFolder#", "NULL");
		
	EndIf;
	
	QueryText = StrReplace(QueryText, "[DestinationTableName]", DestinationTableName);
	
	Query = New Query;
	
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Query.SetParameter("SourceTableParameter",    SourceTable);
	Query.SetParameter("UnapprovedMappingTable", UnapprovedMappingTable.Unload());
	Query.SetParameter("SourceType",                SourceTypeString);
	Query.SetParameter("DestinationType",                DestinationTypeString);
	Query.SetParameter("InfobaseNode",      InfobaseNode);
	
	Query.Execute();

EndProcedure

Procedure AutimaticMappingData(SourceTable, MappingFieldsList, UserFields, TempTablesManager)
	
	MarkedListItemArray = CommonClientServer.MarkedItems(MappingFieldsList);
	
	If MarkedListItemArray.Count() = 0 Then
		
		AutimaticMappingDataByGUID(UserFields, TempTablesManager);
		
	Else
		
		AutimaticMappingDataByGUIDPlusBySearchFields(SourceTable, MappingFieldsList, UserFields, TempTablesManager);
		
	EndIf;
	
EndProcedure

Procedure AutimaticMappingDataByGUID(UserFields, TempTablesManager)
	
	// receiving tables:
	//
	// AutomaticallyMappedObjectsTable
	
	QueryText = "
	|//////////////////////////////////////////////////////////////////////////////// {AutomaticallyMappedObjectsTable}
	|SELECT
	|	
	|	Ref,
	|	
	|	#CUSTOM_FIELDS_MappingTable#
	|	
	|	DestinationPictureIndex,
	|	SourcePictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	DestinationUID,
	|	SourceType,
	|	DestinationType
	|INTO AutomaticallyMappedObjectsTable
	|FROM
	|	(SELECT
	|		
	|		UnmappedDestinationObjectsTable.Ref AS Ref,
	|		
	|		UnmappedDestinationObjectsTable.DestinationPictureIndex,
	|		UnmappedSourceObjectsTable.SourcePictureIndex,
	|		
	|		#CUSTOM_FIELDS_AutomaticallyMappedObjectsTableByGUID_NestedQuery#
	|		
	|		// {MAPPING REGISTER DATA}
	|		UnmappedSourceObjectsTable.SourceUUID AS SourceUUID,
	|		UnmappedSourceObjectsTable.SourceType                     AS SourceType,
	|		UnmappedDestinationObjectsTable.DestinationUID AS DestinationUID,
	|		UnmappedDestinationObjectsTable.DestinationType                     AS DestinationType
	|	FROM
	|		UnmappedDestinationObjectsTable AS UnmappedDestinationObjectsTable
	|	LEFT JOIN
	|		UnmappedSourceObjectsTable AS UnmappedSourceObjectsTable
	|	ON
	|		UnmappedDestinationObjectsTable.Ref = UnmappedSourceObjectsTable.Ref
	|	
	|	WHERE
	|		NOT UnmappedSourceObjectsTable.Ref IS NULL
	|	
	|	) AS NestedQuery
	|;
	|";
	
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_MappingTable#", GetUserFields(UserFields, "SourceFieldNN, DestinationFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_AutomaticallyMappedObjectsTableByGUID_NestedQuery#", GetUserFields(UserFields, "UnmappedSourceObjectsTable.SourceFieldNN AS SourceFieldNN, UnmappedDestinationObjectsTable.DestinationFieldNN AS DestinationFieldNN,"));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Execute();
	
EndProcedure

Procedure AutimaticMappingDataByGUIDPlusBySearchFields(SourceTable, MappingFieldsList, UserFields, TempTablesManager)
	
	// receiving tables:
	//
	// AutomaticallyMappedObjectsTableFull
	// UnmappedDestinationObjectsTableByFields
	// UnmappedSourceObjectsTableByFields
	// IncorrectlyMappedSourceObjectsTable
	// IncorrectlyMappedDestinationObjectsTable
	//
	// AutomaticallyMappedObjectsTableByGUID
	// AutomaticallyMappedObjectsTableByFields
	// AutomaticallyMappedObjectsTable
	
	// Tables are retrieved by the following algorithm
	//
	// UnmappedDestinationObjectsTableByFields = UnmappedDestinationObjectsTable - AutomaticallyMappedObjectsTableByGUID
	// UnmappedSourceObjectsTableByFields = UnmappedSourceObjectsTable - AutomaticallyMappedObjectsTableByGUID
	//
	// AutomaticallyMappedObjectsTable = AutomaticallyMappedObjectsTableByFields + AutomaticallyMappedObjectsTableByGUID
	
	QueryText = "
	|//////////////////////////////////////////////////////////////////////////////// {AutomaticallyMappedObjectsTableByGUID}
	|SELECT
	|	
	|	Ref,
	|	
	|	#CUSTOM_FIELDS_MappingTable#
	|	
	|	DestinationPictureIndex,
	|	SourcePictureIndex,
	|		
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	DestinationUID,
	|	SourceType,
	|	DestinationType
	|INTO AutomaticallyMappedObjectsTableByGUID
	|FROM
	|	(SELECT
	|		
	|		UnmappedDestinationObjectsTable.Ref AS Ref,
	|		
	|		#CUSTOM_FIELDS_AutomaticallyMappedObjectsTableByGUID_NestedQuery#
	|		
	|		UnmappedDestinationObjectsTable.DestinationPictureIndex,
	|		UnmappedSourceObjectsTable.SourcePictureIndex,
	|		
	|		// {MAPPING REGISTER DATA}
	|		UnmappedSourceObjectsTable.SourceUUID AS SourceUUID,
	|		UnmappedSourceObjectsTable.SourceType                     AS SourceType,
	|		UnmappedDestinationObjectsTable.DestinationUID AS DestinationUID,
	|		UnmappedDestinationObjectsTable.DestinationType                     AS DestinationType
	|	FROM
	|		UnmappedDestinationObjectsTable AS UnmappedDestinationObjectsTable
	|	LEFT JOIN
	|		UnmappedSourceObjectsTable AS UnmappedSourceObjectsTable
	|	ON
	|		UnmappedDestinationObjectsTable.Ref = UnmappedSourceObjectsTable.Ref
	|	
	|	WHERE
	|		NOT UnmappedSourceObjectsTable.Ref IS NULL
	|	
	|	) AS NestedQuery
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {UnmappedDestinationObjectsTableByFields}
	|SELECT
	|	
	|	#CUSTOM_FIELDS_UnmappedObjectsTable#
	|	
	|	UnmappedObjectsTable.DestinationPictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	UnmappedObjectsTable.SourceUUID,
	|	UnmappedObjectsTable.DestinationUID,
	|	UnmappedObjectsTable.SourceType,
	|	UnmappedObjectsTable.DestinationType
	|INTO UnmappedDestinationObjectsTableByFields
	|FROM
	|	UnmappedDestinationObjectsTable AS UnmappedObjectsTable
	|	LEFT JOIN
	|		AutomaticallyMappedObjectsTableByGUID AS AutomaticallyMappedObjectsTableByGUID
	|	ON
	|		UnmappedObjectsTable.Ref = AutomaticallyMappedObjectsTableByGUID.Ref
	|WHERE
	|	AutomaticallyMappedObjectsTableByGUID.Ref IS NULL
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {UnmappedSourceObjectsTableByFields}
	|SELECT
	|	
	|	#CUSTOM_FIELDS_UnmappedObjectsTable#
	|	
	|	UnmappedObjectsTable.SourcePictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	UnmappedObjectsTable.SourceUUID,
	|	UnmappedObjectsTable.DestinationUID,
	|	UnmappedObjectsTable.SourceType,
	|	UnmappedObjectsTable.DestinationType
	|INTO UnmappedSourceObjectsTableByFields
	|FROM
	|	UnmappedSourceObjectsTable AS UnmappedObjectsTable
	|	LEFT JOIN
	|		AutomaticallyMappedObjectsTableByGUID AS AutomaticallyMappedObjectsTableByGUID
	|	ON
	|		UnmappedObjectsTable.Ref = AutomaticallyMappedObjectsTableByGUID.Ref
	|WHERE
	|	AutomaticallyMappedObjectsTableByGUID.Ref IS NULL
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {AutomaticallyMappedObjectsTableFull} // Contains duplicate records (records present both in the source and in the destination).
	|SELECT
	|	
	|	#CUSTOM_FIELDS_MappingTable#
	|	
	|	DestinationPictureIndex,
	|	SourcePictureIndex,
	|		
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	DestinationUID,
	|	SourceType,
	|	DestinationType
	|INTO AutomaticallyMappedObjectsTableFull
	|FROM
	|	(SELECT
	|		
	|		#CUSTOM_FIELDS_AutomaticallyMappedObjectsTableFull_NestedQuery#
	|		
	|		UnmappedDestinationObjectsTableByFields.DestinationPictureIndex,
	|		UnmappedSourceObjectsTableByFields.SourcePictureIndex,
	|		
	|		// {MAPPING REGISTER DATA}
	|		UnmappedSourceObjectsTableByFields.SourceUUID AS SourceUUID,
	|		UnmappedSourceObjectsTableByFields.SourceType                     AS SourceType,
	|		UnmappedDestinationObjectsTableByFields.DestinationUID AS DestinationUID,
	|		UnmappedDestinationObjectsTableByFields.DestinationType                     AS DestinationType
	|	FROM
	|		UnmappedDestinationObjectsTableByFields AS UnmappedDestinationObjectsTableByFields
	|	LEFT JOIN
	|		UnmappedSourceObjectsTableByFields AS UnmappedSourceObjectsTableByFields
	|	ON
	|		#MAPPING_BY_FIELDS_CONDITION#
	|	
	|	WHERE
	|		NOT UnmappedSourceObjectsTableByFields.SourceUUID IS NULL
	|	
	|	) AS NestedQuery
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {IncorrectlyMappedSourceObjectsTable}
	|SELECT
	|	
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID
	|	
	|INTO IncorrectlyMappedSourceObjectsTable
	|FROM
	|	(SELECT
	|	
	|		// {MAPPING REGISTER DATA}
	|		SourceUUID
	|	FROM
	|		AutomaticallyMappedObjectsTableFull
	|	GROUP BY
	|		SourceUUID
	|	HAVING
	|		SUM(1) > 1
	|	
	|	) AS NestedQuery
	|;
	|
	|
	|//////////////////////////////////////////////////////////////////////////////// {IncorrectlyMappedDestinationObjectsTable}
	|SELECT
	|	
	|	// {MAPPING REGISTER DATA}
	|	DestinationUID
	|	
	|INTO WrongMappedDestinationObjectsTable
	|FROM
	|	(SELECT
	|	
	|		// {MAPPING REGISTER DATA}
	|		DestinationUID
	|	FROM
	|		AutomaticallyMappedObjectsTableFull
	|	GROUP BY
	|		DestinationUID
	|	HAVING
	|		SUM(1) > 1
	|	
	|	) AS NestedQuery
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {AutomaticallyMappedObjectsTableByFields}
	|SELECT
	|	
	|	#CUSTOM_FIELDS_MappingTable#
	|	
	|	DestinationPictureIndex,
	|	SourcePictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	DestinationUID,
	|	SourceType,
	|	DestinationType
	|INTO AutomaticallyMappedObjectsTableByFields
	|FROM
	|	(SELECT
	|	
	|		#CUSTOM_FIELDS_MappingTable#
	|	
	|		AutomaticallyMappedObjectsTableFull.DestinationPictureIndex,
	|		AutomaticallyMappedObjectsTableFull.SourcePictureIndex,
	|	
	|		// {MAPPING REGISTER DATA}
	|		AutomaticallyMappedObjectsTableFull.SourceUUID,
	|		AutomaticallyMappedObjectsTableFull.DestinationUID,
	|		AutomaticallyMappedObjectsTableFull.SourceType,
	|		AutomaticallyMappedObjectsTableFull.DestinationType
	|	FROM
	|		AutomaticallyMappedObjectsTableFull AS AutomaticallyMappedObjectsTableFull
	|	
	|	LEFT JOIN
	|		IncorrectlyMappedSourceObjectsTable AS IncorrectlyMappedSourceObjectsTable
	|	ON
	|		AutomaticallyMappedObjectsTableFull.SourceUUID = IncorrectlyMappedSourceObjectsTable.SourceUUID
	|	
	|	LEFT JOIN
	|		WrongMappedDestinationObjectsTable AS WrongMappedDestinationObjectsTable
	|	ON
	|		AutomaticallyMappedObjectsTableFull.DestinationUID = WrongMappedDestinationObjectsTable.DestinationUID
	|	
	|	WHERE
	|		  IncorrectlyMappedSourceObjectsTable.SourceUUID IS NULL
	|		AND WrongMappedDestinationObjectsTable.DestinationUID IS NULL
	|	
	|	) AS NestedQuery
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {AutomaticallyMappedObjectsTable}
	|SELECT
	|	
	|	#CUSTOM_FIELDS_MappingTable#
	|	
	|	DestinationPictureIndex,
	|	SourcePictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	DestinationUID,
	|	SourceType,
	|	DestinationType
	|INTO AutomaticallyMappedObjectsTable
	|FROM
	|	(
	|	SELECT
	|
	|		#CUSTOM_FIELDS_MappingTable#
	|		
	|		DestinationPictureIndex,
	|		SourcePictureIndex,
	|		
	|		// {MAPPING REGISTER DATA}
	|		SourceUUID,
	|		DestinationUID,
	|		SourceType,
	|		DestinationType
	|	FROM
	|		AutomaticallyMappedObjectsTableByFields
	|
	|	UNION ALL
	|
	|	SELECT
	|
	|		#CUSTOM_FIELDS_MappingTable#
	|		
	|		DestinationPictureIndex,
	|		SourcePictureIndex,
	|		
	|		// {MAPPING REGISTER DATA}
	|		SourceUUID,
	|		DestinationUID,
	|		SourceType,
	|		DestinationType
	|	FROM
	|		AutomaticallyMappedObjectsTableByGUID
	|
	|	) AS NestedQuery
	|;
	|";
	
	QueryText = StrReplace(QueryText, "#MAPPING_BY_FIELDS_CONDITION#", GetMappingByFieldsCondition(MappingFieldsList));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_MappingTable#", GetUserFields(UserFields, "SourceFieldNN, DestinationFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_UnmappedObjectsTable#", GetUserFields(UserFields, "UnmappedObjectsTable.SourceFieldNN AS SourceFieldNN, UnmappedObjectsTable.DestinationFieldNN AS DestinationFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_AutomaticallyMappedObjectsTableFull_NestedQuery#", GetUserFields(UserFields, "UnmappedSourceObjectsTableByFields.SourceFieldNN AS SourceFieldNN, UnmappedDestinationObjectsTableByFields.DestinationFieldNN AS DestinationFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_AutomaticallyMappedObjectsTableByGUID_NestedQuery#", GetUserFields(UserFields, "UnmappedSourceObjectsTable.SourceFieldNN AS SourceFieldNN, UnmappedDestinationObjectsTable.DestinationFieldNN AS DestinationFieldNN,"));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Execute();
	
EndProcedure

Procedure ExecuteTableSortingAtServer()
	
	SortFields = GetSortingFieldsAtServer();
	
	If Not IsBlankString(SortFields) Then
		
		MappingTable().Sort(SortFields);
		
	EndIf;
	
EndProcedure

Procedure GetMappingDigest(TempTablesManager)
	
	// Getting information on the number of mapped objects.
	GetMappedObjectCount(TempTablesManager);
	
	MappingDigest().ObjectCountInSource = DataExchangeServer.TempInfobaseTableRecordCount("SourceTable", TempTablesManager);
	MappingDigest().ObjectCountInDestination = DataExchangeServer.RecordCountInInfobaseTable(DestinationTableName);
	
	MappedSourceObjectCount =   ObjectMappingStatistics().MappedByRegisterSourceObjectCount
												+ ObjectMappingStatistics().MappedByUnapprovedRelationsObjectCount;
	//
	MappedDestinationObjectsCount =   ObjectMappingStatistics().MappedByRegisterSourceObjectCount
												+ ObjectMappingStatistics().CountOfMappedByRegisterDestinationObjects
												+ ObjectMappingStatistics().MappedByUnapprovedRelationsObjectCount;
	
	UnmappedSourceObjectCount = Max(0, MappingDigest().ObjectCountInSource - MappedSourceObjectCount);
	UnmappedDestinationObjectsCount = Max(0, MappingDigest().ObjectCountInDestination - MappedDestinationObjectsCount);
	
	SourceObjectMappingPercent = ?(MappingDigest().ObjectCountInSource = 0, 0, 100 - Int(100 * UnmappedSourceObjectCount / MappingDigest().ObjectCountInSource));
	DestinationObjectsMappingPercent = ?(MappingDigest().ObjectCountInDestination = 0, 0, 100 - Int(100 * UnmappedDestinationObjectsCount / MappingDigest().ObjectCountInDestination));
	
	MappingDigest().MappedObjectPercentage = Max(SourceObjectMappingPercent, DestinationObjectsMappingPercent);
	
	MappingDigest().UnmappedObjectCount = Min(UnmappedSourceObjectCount, UnmappedDestinationObjectsCount);
	
	MappingDigest().MappedObjectCount = MappedDestinationObjectsCount;
	
EndProcedure

Procedure GetMappedObjectCount(TempTablesManager)
	
	// Getting the number of mapped objects.
	QueryText = "
	|SELECT
	|	Count(*) AS Count
	|FROM
	|	MappedSourceObjectsTableByRegister
	|;
	|/////////////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|	Count(*) AS Count
	|FROM
	|	MappedDestinationObjectsTableByRegister
	|;
	|/////////////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|	Count(*) AS Count
	|FROM
	|	MappedObjectsTableByUnapprovedMapping
	|;
	|/////////////////////////////////////////////////////////////////////////////
	|";
	
	Query = New Query;
	Query.Text                   = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	ResultsArray = Query.ExecuteBatch();
	
	ObjectMappingStatistics().MappedByRegisterSourceObjectCount    = ResultsArray[0].Unload()[0]["Count"];
	ObjectMappingStatistics().CountOfMappedByRegisterDestinationObjects    = ResultsArray[1].Unload()[0]["Count"];
	ObjectMappingStatistics().MappedByUnapprovedRelationsObjectCount = ResultsArray[2].Unload()[0]["Count"];
	
EndProcedure

Procedure AddNumberFieldToMappingTable()
	
	MappingTable().Columns.Add("SerialNumber", New TypeDescription("Number"));
	
	For Each TableRow In MappingTable() Do
		
		TableRow.SerialNumber = MappingTable().IndexOf(TableRow);
		
	EndDo;
	
EndProcedure

Function MergeUnapprovedMappingTableAndAutomaticMappingTable(TempTablesManager)
	
	QueryText = "
	|SELECT
	|
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	DestinationUID,
	|	SourceType,
	|	DestinationType
	|FROM
	|	(
	|	SELECT
	|
	|		// {MAPPING REGISTER DATA}
	|		SourceUUID,
	|		DestinationUID,
	|		SourceType,
	|		DestinationType
	|	FROM 
	|		UnapprovedMappingTable
	|
	|	UNION
	|
	|	SELECT
	|
	|		// {MAPPING REGISTER DATA}
	|		DestinationUID AS SourceUUID,
	|		SourceUUID AS DestinationUID,
	|		DestinationType                     AS SourceType,
	|		SourceType                     AS DestinationType
	|	FROM 
	|		AutomaticallyMappedObjectsTable
	|
	|	) AS NestedQuery
	|
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload();
	
EndFunction

Function AutomaticallyMappedObjectsTableGet(TempTablesManager, UserFields)
	
	QueryText = "
	|SELECT
	|	
	|	#CUSTOM_FIELDS_MappingTable#
	|	
	|	TRUE AS Check,
	|	
	|	DestinationPictureIndex,
	|	SourcePictureIndex,
	|	
	|	// {MAPPING REGISTER DATA}
	|	DestinationUID AS SourceUUID,
	|	SourceUUID AS DestinationUID,
	|	DestinationType                     AS SourceType,
	|	SourceType                     AS DestinationType
	|FROM
	|	AutomaticallyMappedObjectsTable
	|";
	
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_MappingTable#", GetUserFields(UserFields, "SourceFieldNN, DestinationFieldNN,"));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload();
	
EndFunction

Function ObjectMappingResult(SourceTable, UserFields, TempTablesManager)
	
	QueryText = "
	|////////////////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|
	|	#CUSTOM_FIELDS_MappingTable#
	|
	|	#ORDER_FIELDS#
	|
	|	MappingStatus,
	|	MappingStatusAdditional,
	|
	|	SourcePictureIndex AS PictureIndex,
	|
	|	DestinationPictureIndex,
	|	SourcePictureIndex,
	|
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	DestinationUID,
	|	SourceType,
	|	DestinationType
	|FROM
	|	UnmappedSourceObjectsTable
	|
	|UNION ALL
	|
	|SELECT
	|
	|	#CUSTOM_FIELDS_MappingTable#
	|
	|	#ORDER_FIELDS#
	|
	|	MappingStatus,
	|	MappingStatusAdditional,
	|
	|	DestinationPictureIndex AS PictureIndex,
	|
	|	DestinationPictureIndex,
	|	SourcePictureIndex,
	|
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	DestinationUID,
	|	SourceType,
	|	DestinationType
	|FROM
	|	UnmappedDestinationObjectsTable
	|
	|UNION ALL
	|
	|SELECT
	|
	|	#CUSTOM_FIELDS_MappingTable#
	|
	|	#ORDER_FIELDS#
	|
	|	MappingStatus,
	|	MappingStatusAdditional,
	|
	|	DestinationPictureIndex AS PictureIndex,
	|
	|	DestinationPictureIndex,
	|	SourcePictureIndex,
	|
	|	// {MAPPING REGISTER DATA}
	|	SourceUUID,
	|	DestinationUID,
	|	SourceType,
	|	DestinationType
	|FROM
	|	MappedObjectsTable
	|";
	
	QueryText = StrReplace(QueryText, "#CUSTOM_FIELDS_MappingTable#", GetUserFields(UserFields, "SourceFieldNN, DestinationFieldNN,"));
	QueryText = StrReplace(QueryText, "#ORDER_FIELDS#", GetUserFields(UserFields, "OrderFieldNN,"));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload();
	
EndFunction

Function SourceInfobaseData(Cancel)
	
	// Function return value.
	DataTable = Undefined;
	
	ExchangeSettingsStructure = DataExchangeServer.ExchangeSettingsStructureForInteractiveImportSession(InfobaseNode, ExchangeMessageFileName);
	
	If ExchangeSettingsStructure.Cancel Then
		Return Undefined;
	EndIf;
	
	DataExchangeDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
	
	DataTableKey = DataExchangeServer.DataTableKey(SourceTypeString, DestinationTypeString, IsObjectDeletion);
	
	// Perhaps the data table is already imported and is placed in the DataExchangeDataProcessor data processor cache
	DataTable = DataExchangeDataProcessor.DataTablesExchangeMessages().Get(DataTableKey);
	
	// Importing the data table if it is not imported earlier
	If DataTable = Undefined Then
		
		TablesToImport = New Array;
		TablesToImport.Add(DataTableKey);
		
		// IMPORTING DATA IN THE MAPPING MODE (importing data into the value table.
		DataExchangeDataProcessor.ExecuteDataImportIntoValueTable(TablesToImport);
		
		If DataExchangeDataProcessor.ErrorFlag() Then
			
			NString = NStr("ru = 'При загрузке сообщения обмена возникли ошибки: %1'; en = 'Error importing the exchange message: %1'; pl = 'Podczas importu wiadomości wymiany wystąpiły błędy: %1';es_ES = 'Errores ocurridos al importar el mensaje de intercambio: %1';es_CO = 'Errores ocurridos al importar el mensaje de intercambio: %1';tr = 'Değişim mesajları alınırken hatalar oluştu: %1';it = 'Errore durante l''importazione del messaggio di scambio: %1';de = 'Beim Importieren der Austauschnachricht sind Fehler aufgetreten: %1'");
			NString = StringFunctionsClientServer.SubstituteParametersToString(NString, DataExchangeDataProcessor.ErrorMessageString());
			CommonClientServer.MessageToUser(NString,,,, Cancel);
			Return Undefined;
		EndIf;
		
		DataTable = DataExchangeDataProcessor.DataTablesExchangeMessages().Get(DataTableKey);
		
	EndIf;
	
	If DataTable = Undefined Then
		
		Cancel = True;
		
	EndIf;
	
	Return DataTable;
EndFunction

Function GetUserFields(UserFields, FieldPattern)
	
	// Function return value.
	Result = "";
	
	For Each Field In UserFields Do
		
		FieldNumber = UserFields.Find(Field) + 1;
		
		CurrentField = StrReplace(FieldPattern, "#", Field);
		
		CurrentField = StrReplace(CurrentField, "NN", String(FieldNumber));
		
		Result = Result + Chars.LF + CurrentField;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function GetSortingFieldsAtServer()
	
	// Function return value.
	SortFields = "";
	
	FieldPattern = "OrderFieldNN #SortDirection"; // Do not localize.
	
	For Each TableRow In SortTable Do
		
		If TableRow.Use Then
			
			Separator = ?(IsBlankString(SortFields), "", ", ");
			
			SortDirectionStr = ?(TableRow.SortDirection, "Asc", "Desc");
			
			ListItem = UsedFieldsList.FindByValue(TableRow.FieldName);
			
			FieldIndex = UsedFieldsList.IndexOf(ListItem) + 1;
			
			FieldName = StrReplace(FieldPattern, "NN", String(FieldIndex));
			FieldName = StrReplace(FieldName, "#SortDirection", SortDirectionStr);
			
			SortFields = SortFields + Separator + FieldName;
			
		EndIf;
		
	EndDo;
	
	Return SortFields;
	
EndFunction

Function GetMappingByFieldsCondition(MappingFieldsList)
	
	// Function return value.
	Result = "";
	
	For Each Item In MappingFieldsList Do
		
		If Item.Check Then
			
			If StrFind(Item.Presentation, DataExchangeServer.UnlimitedLengthString()) > 0 Then
				
				FieldPattern = "SUBSTRING(UnmappedDestinationObjectsTableByFields.DestinationFieldNN, 0, 1024) = SUBSTRING(UnmappedSourceObjectsTableByFields.SourceFieldNN, 0, 1024)";
				
			Else
				
				FieldPattern = "UnmappedDestinationObjectsTableByFields.DestinationFieldNN = UnmappedSourceObjectsTableByFields.SourceFieldNN";
				
			EndIf;
			
			FieldNumber = MappingFieldsList.IndexOf(Item) + 1;
			
			CurrentField = StrReplace(FieldPattern, "NN", String(FieldNumber));
			
			OperationLiteral = ?(IsBlankString(Result), "", "AND");
			
			Result = Result + Chars.LF + OperationLiteral + " " + CurrentField;
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Internal auxiliary procedures and functions.

Procedure FillListWithSelectedItems(SourceList, DestinationList)
	
	DestinationList.Clear();
	
	For Each Item In SourceList Do
		
		If Item.Check Then
			
			DestinationList.Add(Item.Value, Item.Presentation, True);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure FillSortTable(SourceValueList)
	
	SortTable.Clear();
	
	For Each Item In SourceValueList Do
		
		IsFirstField = SourceValueList.IndexOf(Item) = 0;
		
		TableRow = SortTable.Add();
		
		TableRow.FieldName               = Item.Value;
		TableRow.Use         = IsFirstField; // Default sorting by the first field.
		TableRow.SortDirection = True; // ascending
		
	EndDo;
	
EndProcedure

Procedure FillListWithAdditionalParameters(TableFieldsList)
	
	MetadataObject = Metadata.FindByType(Type(SourceTableObjectTypeName));
	
	FieldListToDelete = New Array;
	ValueStorageType = New TypeDescription("ValueStorage");
	
	For each Item In TableFieldsList Do
		
		Attribute = MetadataObject.Attributes.Find(Item.Value);
		
		If  Attribute = Undefined
			AND DataExchangeServer.IsStandardAttribute(MetadataObject.StandardAttributes, Item.Value) Then
			
			Attribute = MetadataObject.StandardAttributes[Item.Value];
			
		EndIf;
		
		If Attribute = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Для объекта метаданных ""%1"" не определен реквизит с именем ""%2""'; en = 'Attribute with the ""%2"" name is not defined for the ""%1"" metadata object'; pl = 'Atrybut o nazwie ""%2"" nie jest zdefiniowany dla ""%1"" obiektu metadanych';es_ES = 'Atributo con el nombre ""%2"" no está definido para el objeto de metadatos ""%1""';es_CO = 'Atributo con el nombre ""%2"" no está definido para el objeto de metadatos ""%1""';tr = '""%1"" metaveri nesnesi için ""%2"" adlı öznitelik tanımlı değil';it = 'Attributo con il nome ""%2"" non è definito per l''oggetto metadati ""%1""';de = 'Attribut mit dem Namen ""%2"" ist nicht für das Metadatenobjekt ""%1"" definiert'"),
				MetadataObject.FullName(),
				String(Item.Value));
		EndIf;
			
		If Attribute.Type = ValueStorageType Then
			
			FieldListToDelete.Add(Item);
			Continue;
			
		EndIf;
		
		Presentation = "";
		
		If IsUnlimitedLengthString(Attribute) Then
			
			Presentation = StringFunctionsClientServer.SubstituteParametersToString("%1 %2",
				?(IsBlankString(Attribute.Synonym), Attribute.Name, TrimAll(Attribute.Synonym)),
				DataExchangeServer.UnlimitedLengthString());
		Else
			
			Presentation = TrimAll(Attribute.Synonym);
			
		EndIf;
		
		If IsBlankString(Presentation) Then
			
			Presentation = Attribute.Name;
			
		EndIf;
		
		Item.Presentation = Presentation;
		
	EndDo;
	
	For Each ItemToRemove In FieldListToDelete Do
		
		TableFieldsList.Delete(ItemToRemove);
		
	EndDo;
	
EndProcedure

Procedure CheckMappingFieldCountInArray(Array)
	
	If Array.Count() > DataExchangeServer.MaxCountOfObjectsMappingFields() Then
		
		Array.Delete(Array.UBound());
		
		CheckMappingFieldCountInArray(Array);
		
	EndIf;
	
EndProcedure

Procedure AddSearchField(Array, Value)
	
	Item = TableFieldsList.FindByValue(Value);
	
	If Item <> Undefined Then
		
		Array.Add(Item.Value);
		
	EndIf;
	
EndProcedure

Function IsUnlimitedLengthString(Attribute)
	
	Return Attribute.Type = UnlimitedLengthStringType();
	
EndFunction

#EndRegion

#EndIf
