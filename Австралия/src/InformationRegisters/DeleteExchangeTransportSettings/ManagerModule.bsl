#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

#Region InfobaseUpdate

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	AdditionalParameters = InfobaseUpdate.AdditionalProcessingMarkParameters();
	AdditionalParameters.IsIndependentInformationRegister = True;
	AdditionalParameters.FullRegisterName             = "InformationRegister.DeleteExchangeTransportSettings";
	
	QueryOptions = New Structure;
	QueryOptions.Insert("ExchangePlansArray",                 New Array);
	QueryOptions.Insert("ExchangePlanAdditionalProperties", "");
	QueryOptions.Insert("ResultToTemporaryTable",       True);
	
	TempTablesManager = New TempTablesManager;
	
	ExchangeNodesQuery = New Query(DataExchangeServer.ExchangePlansForMonitorQueryText(QueryOptions, False));
	ExchangeNodesQuery.TempTablesManager = TempTablesManager;
	ExchangeNodesQuery.Execute();
	
	Query = New Query(
	"SELECT
	|	TransportSettings.InfobaseNode AS InfobaseNode
	|FROM
	|	ConfigurationExchangePlans AS ConfigurationExchangePlans
	|		INNER JOIN InformationRegister.DeleteExchangeTransportSettings AS TransportSettings
	|		ON (TransportSettings.InfobaseNode = ConfigurationExchangePlans.InfobaseNode)");
	
	Query.TempTablesManager = TempTablesManager;
	
	Result = Query.Execute().Unload();
	
	InfobaseUpdate.MarkForProcessing(Parameters, Result, AdditionalParameters);
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	ProcessingCompleted = True;
	
	RegisterMetadata    = Metadata.InformationRegisters.DeleteExchangeTransportSettings;
	FullRegisterName     = RegisterMetadata.FullName();
	RegisterPresentation = RegisterMetadata.Presentation();
	
	AdditionalProcessingDataSelectionParameters = InfobaseUpdate.AdditionalProcessingDataSelectionParameters();
	
	Selection = InfobaseUpdate.SelectStandaloneInformationRegisterDimensionsToProcess(
		Parameters.PositionInQueue, FullRegisterName, AdditionalProcessingDataSelectionParameters);
	
	Processed = 0;
	RecordsWithIssuesCount = 0;
	
	While Selection.Next() Do
		
		Try
			
			TransferSettingsOfCorrespondentDataExchangeTransport(Selection.InfobaseNode);
			Processed = Processed + 1;
			
		Except
			
			RecordsWithIssuesCount = RecordsWithIssuesCount + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '???? ?????????????? ???????????????????? ?????????? ?????????????? ???????????????? ""%1"" ?? ?????????????? ""InfobaseNode= %2"" ???? ??????????????:
				|%3'; 
				|en = 'Cannot process set of ""%1"" register records with filter ""InfobaseNode = %2"" due to: 
				|%3'; 
				|pl = 'Nie uda??o si?? przetworzy?? zestawu rejestr??w ""%1"" z wyborem ""InfobaseNode = %2"" z powodu: 
				|%3';
				|es_ES = 'No se ha podido procesar el conjunto de registros del registro ""%1"" con selecci??n ""InfobaseNode = %2"" a causa de:
				|%3';
				|es_CO = 'No se ha podido procesar el conjunto de registros del registro ""%1"" con selecci??n ""InfobaseNode = %2"" a causa de:
				|%3';
				|tr = 'A??a????daki nedenle kaydedicinin kay??t k??mesi ""%1"" ""InfobaseNode"" = %2"" se??imle i??lenemedi: 
				|%3';
				|it = 'Impossibile elaborare l''insieme di registrazioni ""%1"" con la selezione ""InfobaseNode = %2"" a causa di: 
				|%3';
				|de = 'Der Satz von ""%1"" Registereintr??gen mit dem Filter ""InfobaseNode = %2"" kann nicht verarbeitet werden aufgrund von:
				|%3'"), RegisterPresentation, Selection.InfobaseNode, DetailErrorDescription(ErrorInfo()));
				
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				RegisterMetadata, , MessageText);
			
		EndTry;
		
	EndDo;
	
	If Not InfobaseUpdate.DataProcessingCompleted(Parameters.PositionInQueue, FullRegisterName) Then
		ProcessingCompleted = False;
	EndIf;
	
	If Processed = 0 AND RecordsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '?????????????????? InformationRegisters.DeleteExchangeTransportSettings.ProcessDataForMigrationToNewVersion ???? ?????????????? ???????????????????? ?????????????????? ???????????? ?????????? ???????????? (??????????????????): %1'; en = 'The InformationRegisters.DeleteExchangeTransportSettings.ProcessDataForMigrationToNewVersion procedure cannot process some exchange node records (skipped): %1'; pl = 'Procedurze InformationRegisters.DeleteExchangeTransportSettings.ProcessDataForMigrationToNewVersion nie uda??o si?? opracowa?? niekt??re elementy zapisu w??z????w wymiany (pomini??te): %1';es_ES = 'El procedimiento InformationRegisters.DeleteExchangeTransportSettings.ProcessDataForMigrationToNewVersion no ha podido procesar unos registros del nodo de cambio (saltados): %1';es_CO = 'El procedimiento InformationRegisters.DeleteExchangeTransportSettings.ProcessDataForMigrationToNewVersion no ha podido procesar unos registros del nodo de cambio (saltados): %1';tr = 'InformationRegisters.DeleteExchangeTransportSettings.ProcessDataForMigrationToNewVersion prosed??r?? veri al????veri??i ??nitesinin baz?? kay??tlar??n?? i??leyemedi (atlat??ld??): %1';it = 'La procedura InformationRegisters.DeleteExchangeTransportSettings.ProcessDataForMigrationToNewVersion non ?? in grado di elaborare alcuni record del nodo di scambio (ignorati): %1';de = 'Das Verfahren InformationRegisters.DeleteExchangeTransportSettings.ProcessDataForMigrationToNewVersion kann einige Datens??tze von Exchange-Knoten nicht verarbeiten (??bersprungen): %1'"), 
			RecordsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			, ,
			StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '?????????????????? InformationRegisters.DeleteExchangeTransportSettings.ProcessDataForMigrationToNewVersion ???????????????????? ?????????????????? ???????????? ??????????????: %1'; en = 'The InformationRegisters.DeleteExchangeTransportSettings.ProcessDataForMigrationToNewVersion procedure processed records: %1'; pl = 'Procedura InformationRegisters.DeleteExchangeTransportSettings.ProcessDataForMigrationToNewVersion opracowa??a kolejn?? porcj?? zapis??w: %1';es_ES = 'El procedimiento InformationRegisters.DeleteExchangeTransportSettings.ProcessDataForMigrationToNewVersion ha procesado una porci??n de registro: %1';es_CO = 'El procedimiento InformationRegisters.DeleteExchangeTransportSettings.ProcessDataForMigrationToNewVersion ha procesado una porci??n de registro: %1';tr = 'InformationRegisters.DeleteExchangeTransportSettings.ProcessDataForMigrationToNewVersion prosed??r?? kay??tlar?? i??ilendi: %1';it = 'La procedura InformationRegisters.DeleteExchangeTransportSettings.ProcessDataForMigrationToNewVersion ha elaborato i record: %1';de = 'Die verarbeiteten Datens??tze des InformationRegisters.DeleteExchangeTransportSettings.ProcessDataForMigrationToNewVersion Verfahrens: %1'"),
			Processed));
	EndIf;
	
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

Procedure TransferSettingsOfCorrespondentDataExchangeTransport(InfobaseNode) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(InfobaseNode) Then
		RecordSet = CreateRecordSet();
		RecordSet.Filter.InfobaseNode.Set(InfobaseNode);
		
		InfobaseUpdate.MarkProcessingCompletion(RecordSet);
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		
		LockItem = Lock.Add("InformationRegister.DeleteExchangeTransportSettings");
		LockItem.SetValue("InfobaseNode", InfobaseNode);
		
		LockItem = Lock.Add("InformationRegister.DataExchangeTransportSettings");
		LockItem.SetValue("Correspondent", InfobaseNode);
		
		Lock.Lock();
		
		RecordSetOld = CreateRecordSet();
		RecordSetOld.Filter.InfobaseNode.Set(InfobaseNode);
		
		RecordSetOld.Read();
		
		If RecordSetOld.Count() = 0 Then
			InfobaseUpdate.MarkProcessingCompletion(RecordSetOld);
		Else
			RecordSetNew = InformationRegisters.DataExchangeTransportSettings.CreateRecordSet();
			RecordSetNew.Filter.Correspondent.Set(InfobaseNode);
			
			RecordNew = RecordSetNew.Add();
			FillPropertyValues(RecordNew, RecordSetOld[0]);
			RecordNew.Correspondent = InfobaseNode;
			
			InfobaseUpdate.WriteRecordSet(RecordSetNew);
			
			RecordSetOld.Clear();
			InfobaseUpdate.WriteRecordSet(RecordSetOld);
		EndIf;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf