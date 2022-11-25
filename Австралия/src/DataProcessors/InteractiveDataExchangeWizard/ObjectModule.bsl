#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// Gets object mapping statistics for the Statistics table rows.
//
// Parameters:
//      Cancel        - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
//      RowIndexes - Array - indexes of Statistics table rows. Data is imported to these rows.
//                              
//                              If the parameter is not specified, statictics data is retrieved for all table rows.
// 
Procedure GetObjectMappingByRowStats(Cancel, RowIndexes = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If RowIndexes = Undefined Then
		
		RowIndexes = New Array;
		
		For Each TableRow In StatisticsInformation Do
			
			RowIndexes.Add(StatisticsInformation.IndexOf(TableRow));
			
		EndDo;
		
	EndIf;
	
	// Importing data from the exchange message into the cache for several tables at the same time
	ExecuteDataImportFromExchangeMessagesIntoCache(Cancel, RowIndexes);
	
	If Cancel Then
		Return;
	EndIf;
	
	InfobaseObjectMapping = DataProcessors.InfobaseObjectMapping.Create();
	
	// Getting mapping digest data separately for each table.
	For Each RowIndex In RowIndexes Do
		
		TableRow = StatisticsInformation[RowIndex];
		
		If Not TableRow.SynchronizeByID Then
			Continue;
		EndIf;
		
		// Initializing data processor properties.
		InfobaseObjectMapping.DestinationTableName            = TableRow.DestinationTableName;
		InfobaseObjectMapping.SourceTableObjectTypeName = TableRow.ObjectTypeString;
		InfobaseObjectMapping.InfobaseNode         = InfobaseNode;
		InfobaseObjectMapping.ExchangeMessageFileName        = ExchangeMessageFileName;
		
		InfobaseObjectMapping.SourceTypeString = TableRow.SourceTypeString;
		InfobaseObjectMapping.DestinationTypeString = TableRow.DestinationTypeString;
		
		// constructor
		InfobaseObjectMapping.Designer();
		
		// Getting mapping digest data.
		InfobaseObjectMapping.GetObjectMappingDigestInfo(Cancel);
		
		// Mapping summary.
		TableRow.ObjectCountInSource       = InfobaseObjectMapping.ObjectCountInSource();
		TableRow.ObjectCountInDestination       = InfobaseObjectMapping.ObjectCountInDestination();
		TableRow.MappedObjectCount   = InfobaseObjectMapping.MappedObjectCount();
		TableRow.UnmappedObjectCount = InfobaseObjectMapping.UnmappedObjectCount();
		TableRow.MappedObjectPercentage       = InfobaseObjectMapping.MappedObjectPercentage();
		TableRow.PictureIndex                     = DataExchangeServer.StatisticsTablePictureIndex(TableRow.UnmappedObjectCount, TableRow.DataImportedSuccessfully);
		TableRow.IsMasterData                             = IsMasterDataTypeName(TableRow.DestinationTypeString);

	EndDo;
	
EndProcedure

// Maps infobase objects automatically with default values and gets statistics of objects mapping 
//  after mappong them automatically.
//  
//
// Parameters:
//      Cancel        - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
//      RowIndexes - Array - indexes of Statistics table rows. Data is mapped automatically for 
//                              these rows.
//                              
//                              If the parameter is not specified, statictics data is retrieved for all table rows.
// 
Procedure ExecuteDefaultAutomaticMappingAndGetMappingStatistics(Cancel, RowIndexes = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If RowIndexes = Undefined Then
		
		RowIndexes = New Array;
		
		For Each TableRow In StatisticsInformation Do
			
			RowIndexes.Add(StatisticsInformation.IndexOf(TableRow));
			
		EndDo;
		
	EndIf;
	
	// Importing data from the exchange message into the cache for several tables at the same time
	ExecuteDataImportFromExchangeMessagesIntoCache(Cancel, RowIndexes);
	
	If Cancel Then
		Return;
	EndIf;
	
	InfobaseObjectMapping = DataProcessors.InfobaseObjectMapping.Create();
	
	// Performing automatic mapping. Getting mapping digest data.
	// 
	For Each RowIndex In RowIndexes Do
		
		TableRow = StatisticsInformation[RowIndex];
		
		If Not TableRow.SynchronizeByID Then
			Continue;
		EndIf;
		
		// Initializing data processor properties.
		InfobaseObjectMapping.DestinationTableName            = TableRow.DestinationTableName;
		InfobaseObjectMapping.SourceTableObjectTypeName = TableRow.ObjectTypeString;
		InfobaseObjectMapping.DestinationTableFields           = TableRow.TableFields;
		InfobaseObjectMapping.DestinationTableSearchFields     = TableRow.SearchFields;
		InfobaseObjectMapping.InfobaseNode         = InfobaseNode;
		InfobaseObjectMapping.ExchangeMessageFileName        = ExchangeMessageFileName;
		
		InfobaseObjectMapping.SourceTypeString = TableRow.SourceTypeString;
		InfobaseObjectMapping.DestinationTypeString = TableRow.DestinationTypeString;
		
		// constructor
		InfobaseObjectMapping.Designer();
		
		// Performing default automatic object mapping.
		InfobaseObjectMapping.ExecuteDefaultAutomaticMapping(Cancel);
		
		// Getting mapping digest data.
		InfobaseObjectMapping.GetObjectMappingDigestInfo(Cancel);
		
		// Mapping summary.
		TableRow.ObjectCountInSource       = InfobaseObjectMapping.ObjectCountInSource();
		TableRow.ObjectCountInDestination       = InfobaseObjectMapping.ObjectCountInDestination();
		TableRow.MappedObjectCount   = InfobaseObjectMapping.MappedObjectCount();
		TableRow.UnmappedObjectCount = InfobaseObjectMapping.UnmappedObjectCount();
		TableRow.MappedObjectPercentage       = InfobaseObjectMapping.MappedObjectPercentage();
		TableRow.PictureIndex                     = DataExchangeServer.StatisticsTablePictureIndex(TableRow.UnmappedObjectCount, TableRow.DataImportedSuccessfully);
		TableRow.IsMasterData                             = IsMasterDataTypeName(TableRow.DestinationTypeString);
	EndDo;
	
EndProcedure

// Imports data into the infobase for Statistics table rows.
//  If all exchange message data is imported, the incoming exchange message number is stored in the 
//  exchange node.
//  It implies that all data is imported to the infobase.
//  The repeat import of this message will be canceled.
//
// Parameters:
//       Cancel        - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
//       RowsIndexes - Array - indexes of Statistics table rows. Data is imported to these rows.
//                               
//                               If the parameter is not specified, statictics data is retrieved for all table rows.
// 
Procedure RunDataImport(Cancel, RowIndexes = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If RowIndexes = Undefined Then
		
		RowIndexes = New Array;
		
		For Each TableRow In StatisticsInformation Do
			
			RowIndexes.Add(StatisticsInformation.IndexOf(TableRow));
			
		EndDo;
		
	EndIf;
	
	TablesToImport = New Array;
	
	For Each RowIndex In RowIndexes Do
		
		TableRow = StatisticsInformation[RowIndex];
		
		DataTableKey = DataExchangeServer.DataTableKey(TableRow.SourceTypeString, TableRow.DestinationTypeString, TableRow.IsObjectDeletion);
		
		TablesToImport.Add(DataTableKey);
		
	EndDo;
	
	// Initializing data processor properties.
	InfobaseObjectMapping = DataProcessors.InfobaseObjectMapping.Create();
	InfobaseObjectMapping.ExchangeMessageFileName = ExchangeMessageFileName;
	InfobaseObjectMapping.InfobaseNode  = InfobaseNode;
	
	// importing file
	InfobaseObjectMapping.ExecuteDataImportForInfobase(Cancel, TablesToImport);
	
	DataImportedSuccessfully = Not Cancel;
	
	For Each RowIndex In RowIndexes Do
		
		TableRow = StatisticsInformation[RowIndex];
		
		TableRow.DataImportedSuccessfully = DataImportedSuccessfully;
		TableRow.PictureIndex = DataExchangeServer.StatisticsTablePictureIndex(TableRow.UnmappedObjectCount, TableRow.DataImportedSuccessfully);
	
	EndDo;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

// Imports data (tables) to the cache from the exchange message.
// Only tables not imported before are imported.
// The DataExchangeDataProcessor variable contains (caches) the tables imported before.
//
// Parameters:
//       Cancel        - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
//       RowsIndexes - Array - indexes of Statistics table rows. Data is imported to these rows.
//                               
//                               If the parameter is not specified, statictics data is retrieved for all table rows.
// 
Procedure ExecuteDataImportFromExchangeMessagesIntoCache(Cancel, RowIndexes)
	
	ExchangeSettingsStructure = DataExchangeServer.ExchangeSettingsStructureForInteractiveImportSession(InfobaseNode, ExchangeMessageFileName);
	
	If ExchangeSettingsStructure.Cancel Then
		Return;
	EndIf;
	ExchangeSettingsStructure.StartDate = CurrentSessionDate();
	DataExchangeDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
	
	// Getting the array of tables to be batchly imported into the platform cache
	TablesToImport = New Array;
	
	For Each RowIndex In RowIndexes Do
		
		TableRow = StatisticsInformation[RowIndex];
		
		If Not TableRow.SynchronizeByID Then
			Continue;
		EndIf;
		
		DataTableKey = DataExchangeServer.DataTableKey(TableRow.SourceTypeString, TableRow.DestinationTypeString, TableRow.IsObjectDeletion);
		
		// Perhaps the data table is already imported and is placed in the DataExchangeDataProcessor data processor cache
		DataTable = DataExchangeDataProcessor.DataTablesExchangeMessages().Get(DataTableKey);
		
		If DataTable = Undefined Then
			
			TablesToImport.Add(DataTableKey);
			
		EndIf;
		
	EndDo;
	
	// Importing tables into the cache batchly
	If TablesToImport.Count() > 0 Then
		
		DataExchangeDataProcessor.ExecuteDataImportIntoValueTable(TablesToImport);
		
		If DataExchangeDataProcessor.ErrorFlag() Then
			Cancel = True;
			NString = NStr("ru = 'При загрузке сообщения обмена возникли ошибки: %1'; en = 'Error importing the exchange message: %1'; pl = 'Podczas importu wiadomości wymiany wystąpiły błędy: %1';es_ES = 'Errores ocurridos al importar el mensaje de intercambio: %1';es_CO = 'Errores ocurridos al importar el mensaje de intercambio: %1';tr = 'Değişim mesajları alınırken hatalar oluştu: %1';it = 'Errore durante l''importazione del messaggio di scambio: %1';de = 'Beim Importieren der Austauschnachricht sind Fehler aufgetreten: %1'");
			NString = StringFunctionsClientServer.SubstituteParametersToString(NString, DataExchangeDataProcessor.ErrorMessageString());
			DataExchangeServer.RecordExchangeCompletionWithError(ExchangeSettingsStructure.InfobaseNode,
												ExchangeSettingsStructure.ActionOnExchange, 
												ExchangeSettingsStructure.StartDate,
												NString);
			Return;
		EndIf;
		
	EndIf;
	
EndProcedure

Function IsMasterDataTypeName(DestinationTypeString)
	If Documents.AllRefsType().ContainsType(Type(DestinationTypeString)) Then
		Return False;
	EndIf;
	Return True;
EndFunction
////////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

// Data of the Statistics tabular section.
//
// Returns:
//  ValueTable - data of the StatisticsInformation tabular section.
//
Function StatisticsTable() Export
	
	Return StatisticsInformation.Unload();
	
EndFunction

#EndRegion

#EndIf