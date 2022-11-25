#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Procedure UpdateSettings(InfobaseNode, SettingKind, SettingValue) Export
	
	UpdateRecord(InfobaseNode, "Settings", SettingKind, SettingValue);
	
EndProcedure

Procedure UpdateCorrespondentSettings(InfobaseNode, SettingKind, SettingValue) Export
	
	UpdateRecord(InfobaseNode, "CorrespondentSettings", SettingKind, SettingValue);
	
EndProcedure

Function SettingValue(InfobaseNode, SettingKind) Export
	
	Result = Undefined;
	
	ReadRecord(InfobaseNode, "Settings", SettingKind, Result);
	
	Return Result;
	
EndFunction

Function CorrespondentSettingValue(InfobaseNode, SettingKind) Export
	
	Result = Undefined;
	
	ReadRecord(InfobaseNode, "CorrespondentSettings", SettingKind, Result);
	
	Return Result;
	
EndFunction

#EndRegion
	
#Region Private

Procedure UpdateRecord(InfobaseNode, DimensionName, SettingKind, SettingValue)
	
	Manager = CreateRecordManager();
	Manager.InfobaseNode = InfobaseNode;
	
	Manager.Read();
	
	NewSettings = New Structure;
	
	If Manager.Selected() Then
		CurrentSettings = Manager[DimensionName].Get();
		
		If TypeOf(CurrentSettings) = Type("ValueTable") Then
			
			NewSettings.Insert("SupportedObjects", CurrentSettings);
			
		ElsIf TypeOf(CurrentSettings) = Type("Structure") Then
			
			For Each SettingItem In CurrentSettings Do
				
				NewSettings.Insert(SettingItem.Key, SettingItem.Value);
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	NewSettings.Insert(SettingKind, SettingValue);
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", InfobaseNode);
	RecordStructure.Insert(DimensionName, New ValueStorage(NewSettings, New Deflation(9)));
	
	DataExchangeServer.UpdateInformationRegisterRecord(RecordStructure, "XDTODataExchangeSettings");
	
EndProcedure

Procedure ReadRecord(InfobaseNode, DimensionName, SettingKind, Result)
	
	Manager = CreateRecordManager();
	Manager.InfobaseNode = InfobaseNode;
	
	Manager.Read();
	
	SettingStructure = New Structure;
	
	If Manager.Selected() Then
		CurrentSettings = Manager[DimensionName].Get();
		
		If TypeOf(CurrentSettings) = Type("ValueTable") Then
			
			SettingStructure.Insert("SupportedObjects", CurrentSettings);
			
		ElsIf TypeOf(CurrentSettings) = Type("Structure") Then
			
			For Each SettingItem In CurrentSettings Do
				
				SettingStructure.Insert(SettingItem.Key, SettingItem.Value);
				
			EndDo;
			
		EndIf;
	EndIf;
	
	SettingStructure.Property(SettingKind, Result);
	
EndProcedure

#Region InfobaseUpdate

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	AdditionalParameters = InfobaseUpdate.AdditionalProcessingMarkParameters();
	AdditionalParameters.IsIndependentInformationRegister = True;
	AdditionalParameters.FullRegisterName             = "InformationRegister.XDTODataExchangeSettings";
	
	XTDOExchangePlans = New Array;
	For Each ExchangePlan In DataExchangeCached.SSLExchangePlans() Do
		If Not DataExchangeCached.IsXDTOExchangePlan(ExchangePlan) Then
			Continue;
		EndIf;
		XTDOExchangePlans.Add(ExchangePlan);
	EndDo;
	
	If XTDOExchangePlans.Count() = 0 Then
		Return;
	EndIf;
	
	QueryOptions = New Structure;
	QueryOptions.Insert("ExchangePlansArray",                 XTDOExchangePlans);
	QueryOptions.Insert("ExchangePlanAdditionalProperties", "");
	QueryOptions.Insert("ResultToTemporaryTable",       True);
	
	TempTablesManager = New TempTablesManager;
	
	ExchangeNodesQuery = New Query(DataExchangeServer.ExchangePlansForMonitorQueryText(QueryOptions, False));
	ExchangeNodesQuery.TempTablesManager = TempTablesManager;
	ExchangeNodesQuery.Execute();
	
	Query = New Query(
	"SELECT
	|	ConfigurationExchangePlans.InfobaseNode AS InfobaseNode
	|FROM
	|	ConfigurationExchangePlans AS ConfigurationExchangePlans
	|		LEFT JOIN InformationRegister.XDTODataExchangeSettings AS XDTODataExchangeSettings
	|		ON (XDTODataExchangeSettings.InfobaseNode = ConfigurationExchangePlans.InfobaseNode)
	|WHERE
	|	(XDTODataExchangeSettings.InfobaseNode IS NULL
	|			OR XDTODataExchangeSettings.CorrespondentExchangePlanName = """")");
	
	Query.TempTablesManager = TempTablesManager;
	
	Result = Query.Execute().Unload();
	
	InfobaseUpdate.MarkForProcessing(Parameters, Result, AdditionalParameters);
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	ProcessingCompleted = True;
	
	RegisterMetadata    = Metadata.InformationRegisters.XDTODataExchangeSettings;
	FullRegisterName     = RegisterMetadata.FullName();
	RegisterPresentation = RegisterMetadata.Presentation();
	FilterPresentation   = NStr("ru = 'InfobaseNode = %1'; en = 'InfobaseNode = %1'; pl = 'InfobaseNode = %1';es_ES = 'InfobaseNode = ""%1""';es_CO = 'InfobaseNode = ""%1""';tr = 'InfobaseNode = %1';it = 'InfobaseNode = %1';de = 'InformationsBasisKnoten = ""%1""'");
	
	AdditionalProcessingDataSelectionParameters = InfobaseUpdate.AdditionalProcessingDataSelectionParameters();
	
	Selection = InfobaseUpdate.SelectStandaloneInformationRegisterDimensionsToProcess(
		Parameters.PositionInQueue, FullRegisterName, AdditionalProcessingDataSelectionParameters);
	
	Processed = 0;
	RecordsWithIssuesCount = 0;
	
	While Selection.Next() Do
		
		Try
			
			RefreshDataExchangeSettingsOfCorrespondentXDTO(Selection.InfobaseNode);
			Processed = Processed + 1;
			
		Except
			
			RecordsWithIssuesCount = RecordsWithIssuesCount + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось обработать набор записей регистра ""%1"" с отбором %2 по причине:
				|%3'; 
				|en = 'Cannot process set of ""%1"" register records with filter %2 due to: 
				|%3'; 
				|pl = 'Nie udało się przetworzyć zestawu zapisów rejestru ""%1"" z selekcją %2 z powodu: 
				|%3';
				|es_ES = 'No se ha podido procesar un conjunto de registros del registro ""%1"" con la selección %2 a causa de:
				|%3';
				|es_CO = 'No se ha podido procesar un conjunto de registros del registro ""%1"" con la selección %2 a causa de:
				|%3';
				|tr = 'Aşağıdaki nedenle kaydedicinin kayıt kümesi ""%1"" %2 seçimle işlenemedi: 
				|%3';
				|it = 'Non è possibile processare l''insieme di ""%1"" registrazioni con il filtro %2 a causa di: 
				|%3';
				|de = 'Aufzeichnungssatz ""%1"" konnte mit Auswahl %2 nicht verarbeitet werden, weil:
				|%3'"), RegisterPresentation, FilterPresentation, DetailErrorDescription(ErrorInfo()));
				
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				RegisterMetadata, , MessageText);
			
		EndTry;
		
	EndDo;
	
	If Not InfobaseUpdate.DataProcessingCompleted(Parameters.PositionInQueue, FullRegisterName) Then
		ProcessingCompleted = False;
	EndIf;
	
	If Processed = 0 AND RecordsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Процедуре InformationRegisters.XDTODataExchangeSettings.ProcessDataForMigrationToNewVersion не удалось обработать некоторые записи узлов обмена (пропущены): %1'; en = 'The InformationRegisters.XDTODataExchangeSettings.ProcessDataForMigrationToNewVersion procedure cannot process some exchange node records (skipped): %1'; pl = 'Procedurze InformationRegisters.XDTODataExchangeSettings.ProcessDataForMigrationToNewVersion nie udało się opracować niektóre elementy zapisu węzłów wymiany (pominięte): %1';es_ES = 'El procedimiento InformationRegisters.XDTODataExchangeSettings.ProcessDataForMigrationToNewVersion no ha podido procesar unos registros de los nodos de cambio (saltados): %1';es_CO = 'El procedimiento InformationRegisters.XDTODataExchangeSettings.ProcessDataForMigrationToNewVersion no ha podido procesar unos registros de los nodos de cambio (saltados): %1';tr = 'InformationRegisters.XDTODataExchangeSettings.ProcessDataForMigrationToNewVersion prosedürü bazı değişim düğümü kayıtlarını işleyemiyor (atlandı): %1';it = 'La procedura InformationRegisters.XDTODataExchangeSettings.ProcessDataForMigrationToNewVersion procedure non è in grado di elaborare alcuni record dei nodi di scambio (ignorati): %1';de = 'Das Verfahren InformationRegisters.XDTODataExchangeSettings.ProcessDataForMigrationToNewVersion kann einige Datensätze von Exchange-Knoten nicht verarbeiten (übersprungen): %1'"), 
			RecordsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			, ,
			StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Процедура InformationRegisters.XDTODataExchangeSettings.ProcessDataForMigrationToNewVersion обработала очередную порцию записей: %1'; en = 'The InformationRegisters.XDTODataExchangeSettings.ProcessDataForMigrationToNewVersion procedure processed records: %1'; pl = 'Procedura InformationRegisters.XDTODataExchangeSettings.ProcessDataForMigrationToNewVersion opracowała kolejną porcję zapisów: %1';es_ES = 'El procedimiento InformationRegisters.XDTODataExchangeSettings.ProcessDataForMigrationToNewVersion ha procesado los registros: %1';es_CO = 'El procedimiento InformationRegisters.XDTODataExchangeSettings.ProcessDataForMigrationToNewVersion ha procesado los registros: %1';tr = 'InformationRegisters.XDTODataExchangeSettings.ProcessDataForMigrationToNewVersion prosedürü kayıtları işledi: %1';it = 'La procedura InformationRegisters.XDTODataExchangeSettings.ProcessDataForMigrationToNewVersion ha elaborato i record: %1';de = 'Die InformationRegisters.XDTODataExchangeSettings.ProcessDataForMigrationToNewVersion Verfahren verarbeitete Datensätze: %1'"),
			Processed));
	EndIf;
	
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

Procedure RefreshDataExchangeSettingsOfCorrespondentXDTO(InfobaseNode) Export
	
	BeginTransaction();
	Try
		
		Lock = New DataLock;
		
		LockItem = Lock.Add("InformationRegister.XDTODataExchangeSettings");
		LockItem.SetValue("InfobaseNode", InfobaseNode);
		
		Lock.Lock();
		
		RecordSet = CreateRecordSet();
		RecordSet.Filter.InfobaseNode.Set(InfobaseNode);
		
		RecordSet.Read();
		
		If RecordSet.Count() > 0 Then
			CurrentRecord = RecordSet[0];
		Else
			CurrentRecord = RecordSet.Add();
			CurrentRecord.InfobaseNode = InfobaseNode;
		EndIf;
		
		CurrentRecord.CorrespondentExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
		
		InfobaseUpdate.WriteRecordSet(RecordSet);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf