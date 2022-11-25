#Region Public

Procedure ExecuteExchange(Parameters, ResultAddress = "") Export
	
	Error = False;
	ExchangeNode = Parameters.ExchangeNode;
	
	ExchangeParameters = New Structure;
	ExchangeParameters.Insert("ExchangeNode",		Parameters.ExchangeNode);
	ExchangeParameters.Insert("ExchangeStartMode",	Parameters.ExchangeStartMode);
	ExchangeParameters.Insert("CreationDate",		CurrentSessionDate());
	
	InformationTable = InformationRegisters.StatesOfExchangeWithProManage.CreateRecordSet().Unload();
	InformationTable.Columns.Add("Description", New TypeDescription("String"));
			
	GetDataFromWebService(ExchangeParameters, InformationTable, Error);
		
	ExecuteActionsOnExchangeCompletion(ExchangeParameters, InformationTable, Error);
	
EndProcedure

Procedure JobExchangeWithProManage(ExchangeNodeCode) Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.ExchangeWithProManage);
	
	ExchangeNode = ExchangePlans.ProManage.FindByCode(ExchangeNodeCode);
	
	If Not ValueIsFilled(ExchangeNode) Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The exchange node with code ""%1"" is not found.'; ru = 'Узел обмена с кодом ""%1"" не найден.';pl = 'Nie znaleziono węzła wymiany z kodem ""%1"".';es_ES = 'No se encuentra el nodo de intercambio con código ""%1"".';es_CO = 'No se encuentra el nodo de intercambio con código ""%1"".';tr = '""%1"" kodlu değişim düğümü bulunamadı.';it = 'Il nodo di scambio con codice ""%1"" non è stato trovato.';de = 'Der Exchange-Knoten mit dem Code ""%1"" ist nicht gefunden.'"),
			ExchangeNodeCode);	
		
		WriteLogEvent(NStr("en = 'Data exchange with ProManage'; ru = 'Обмен данными с ProManage';pl = 'Wymiana danych z ProManage';es_ES = 'Intercambio de datos con ProManage';es_CO = 'Intercambio de datos con ProManage';tr = 'ProManage ile veri değişimi';it = 'Scambio dati con ProManage';de = 'Datenaustausch mit ProManage'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			ExchangeNode.Metadata(),
			ExchangeNode,
			MessageText);
		
		Return;
		
	EndIf;
	
	If ExchangeNode.DeletionMark Then
		
		WriteLogEvent(NStr("en = 'Data exchange with ProManage'; ru = 'Обмен данными с ProManage';pl = 'Wymiana danych z ProManage';es_ES = 'Intercambio de datos con ProManage';es_CO = 'Intercambio de datos con ProManage';tr = 'ProManage ile veri değişimi';it = 'Scambio dati con ProManage';de = 'Datenaustausch mit ProManage'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Information,
			ExchangeNode.Metadata(),
			ExchangeNode,
			NStr("en = 'The data exchange settings are marked for deletion. Data exchange is canceled.'; ru = 'Настройки обмена данными помечены на удаление. Обмен данными отменен.';pl = 'Ustawienia wymiany danych są zaznaczone do usunięcia. Wymiana danych jest anulowana.';es_ES = 'La configuración de intercambio de datos está marcada para su eliminación. Se cancela el intercambio de datos.';es_CO = 'La configuración de intercambio de datos está marcada para su eliminación. Se cancela el intercambio de datos.';tr = 'Veri değişimi ayarları silinmek üzere işaretlendi. Veri değişimi iptal edildi.';it = 'Le impostazioni di scambio dati sono contrassegnate per l''eliminazione. Lo scambio dati è annullato.';de = 'Die Einstellungen des Datenaustauschs sind zum Löschen markiert. Datenaustausch ist abgebrochen.'"));
		
		Return;
		
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("ExchangeNode", ExchangeNode);
	Parameters.Insert("ExchangeStartMode", NStr("en = 'Background data exchange'; ru = 'Фоновый обмен данными';pl = 'Wymiana danych w tle';es_ES = 'Intercambio de datos de fondo';es_CO = 'Intercambio de datos de fondo';tr = 'Arka plan veri değişimi';it = 'Scambio dati in background';de = 'Hintergrunddatenaustausch'"));
	
	ExecuteExchange(Parameters);
	
EndProcedure

Procedure FinishOperationsProManage(WIP) Export
	
	ParameterIsRefTypeValue = Common.RefTypeValue(WIP);
	
	If ParameterIsRefTypeValue Then
		WIPObject = WIP.GetObject();
	Else
		WIPObject = WIP;
	EndIf;
	
	ProManageTable = GetProManageData(WIPObject.Ref);
	
	If ProManageTable.Count() > 0 Then
	
		LastActivitiesRow = WIPObject.Activities.Get(WIPObject.Activities.Count() - 1);
		LastProManageRow = ProManageTable.Get(ProManageTable.Count() - 1);
		
		If LastActivitiesRow.Quantity = LastProManageRow.QuantitySucceeded Then
			
			For Each ActivityRow In WIPObject.Activities Do
				
				ProManageFilteredTable = ProManageTable.Copy(New Structure("Activity", ActivityRow.Activity));
				
				If ProManageFilteredTable.Count() = 1 Then
					
					For Each ProManageRow In ProManageFilteredTable Do 
						ActivityRow.StartDate = ProManageRow.StartDate;
						ActivityRow.FinishDate = ProManageRow.FinishDate;
						ActivityRow.Done = True;
					EndDo;
					
				ElsIf ProManageFilteredTable.Count() > 1 Then
					
					FoundActivityRows = WIPObject.Activities.FindRows(New Structure("Activity", ActivityRow.Activity));
					
					If FoundActivityRows.Count() = ProManageFilteredTable.Count() Then
						
						Index = FoundActivityRows.Find(ActivityRow);
						ProManageRow = ProManageFilteredTable.Get(Index);
						
						ActivityRow.StartDate = ProManageRow.StartDate;
						ActivityRow.FinishDate = ProManageRow.FinishDate;
						ActivityRow.Done = True;
						
					Else
						
						ProManageFilteredTable.Sort("StartDate");
						ActivityRow.StartDate = ProManageFilteredTable[0].StartDate;
						ProManageFilteredTable.Sort("FinishDate Desc");
						ActivityRow.FinishDate = ProManageFilteredTable[0].FinishDate;
						ActivityRow.Done = True;
						
					EndIf;
					
				EndIf;
			EndDo;
			
			WIPObject.Status = Enums.ManufacturingOperationStatuses.Completed;
			
			If ParameterIsRefTypeValue Then
				WIPObject.Write(DocumentWriteMode.Posting);
			EndIf;
			
		Else
			
			MessageText = NStr("en = 'The quantity of operations completed in ProManage does not match the quantity of completed operations in document %1. In this document, manually complete the following operations: %2.'; ru = 'Количество завершенных операций в ProManage не соответствует количеству завершенных операций в документе %1. В этом документе вручную завершите следующие операции: %2.';pl = 'Ilość operacji wykonanych w ProManage nie odpowiada ilości wykonanych operacji w dokumencie %1. W tym dokumencie, ręcznie zakończ następujące operacje: %2.';es_ES = 'La cantidad de operaciones finalizadas en ProManage no coincide con la cantidad de operaciones finalizadas en el documento %1. En este documento, finalice manualmente las siguientes operaciones: %2.';es_CO = 'La cantidad de operaciones finalizadas en ProManage no coincide con la cantidad de operaciones finalizadas en el documento %1. En este documento, finalice manualmente las siguientes operaciones: %2.';tr = 'ProManage''da tamamlanan işlemlerin miktarı %1 belgesinde tamamlanan işlemlerin miktarıyla eşleşmiyor. Bu belgede şu işlemleri manuel olarak tamamlayın: %2.';it = 'La quantità di operazioni completate in ProManage non corrisponde alla quantità di operazioni completate nel documento %1. In questo documento completare manualmente le seguenti operazioni: %2.';de = 'Die Anzahl von Operationen abgeschlossen in ProManage stimmt mit der Anzahl der abgeschlossenen Operationen im Dokument %1 nicht überein. In diesem Dokument schließen Sie die folgenden Operationen manuell ab: %2.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				MessageText,
				?(ParameterIsRefTypeValue, WIP, WIPObject.Ref),
				LastActivitiesRow.Activity);
				
			CommonClientServer.MessageToUser(MessageText);
			
			If ParameterIsRefTypeValue Then
				WIPObject.Write();
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Function GetProManageData(WIP) Export

	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProManageData.Activity AS Activity,
	|	ProManageData.StartDate AS StartDate,
	|	ProManageData.FinishDate AS FinishDate,
	|	ProManageData.Quantity AS Quantity,
	|	ProManageData.QuantitySucceeded AS QuantitySucceeded,
	|	ProManageData.QuantityFailed AS QuantityFailed
	|FROM
	|	InformationRegister.ProManageData AS ProManageData
	|WHERE
	|	ProManageData.ManufacturingOperation = &WIP";
	
	Query.SetParameter("WIP", WIP);
	
	Return Query.Execute().Unload();

EndFunction

Function ProManageNode() Export 
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	ProManage.Ref AS Ref
	|FROM
	|	ExchangePlan.Promanage AS ProManage
	|WHERE
	|	NOT ProManage.ThisNode
	|	AND NOT ProManage.DeletionMark";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		ExchangeNode = Selection.Ref;
	EndIf;

	Return ExchangeNode;
	
EndFunction

Procedure DataExchangePromanageBeforeWriteDocument(Source, Cancel, WriteMode, PostingMode) Export
	
	If Not CommonCached.DataSeparationEnabled()
		And NeedForRegistration(Source) Then
		DataExchangeEvents.ObjectsRegistrationMechanismBeforeWriteDocument("ProManage", Source, Cancel, WriteMode, PostingMode);
	EndIf;
	
EndProcedure

Procedure DataExchangePromanageBeforeDelete(Source, Cancel) Export
	
	If Not CommonCached.DataSeparationEnabled() Then
		DataExchangeEvents.ObjectsRegistrationMechanismBeforeDelete("ProManage", Source, Cancel);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function GetDataFromWebService(ExchangeParameters, InformationTable, Error) 
	
	ExchangeNode = ExchangeParameters.ExchangeNode;
	
	InformationTableCommonRow = InformationTable.Add();
	InformationTableCommonRow.ExchangeSetting =		ExchangeNode;
	InformationTableCommonRow.ActionOnExchange =	Enums.ActionsOnExchange.DataImport;
	InformationTableCommonRow.Description =			String(CurrentSessionDate()) + " " + NStr("en = 'Sync with ProManage started.'; ru = 'Синхронизация с ProManage начата.';pl = 'Synchronizacja z ProManage została rozpoczęta.';es_ES = 'Se ha iniciado la sincronización con ProManage.';es_CO = 'Se ha iniciado la sincronización con ProManage.';tr = 'ProManage ile senkronizasyon başladı.';it = 'Sincronizzazione con ProManage avviata.';de = 'Synchronisieren mit ProManage gestartet.'");
	
	Try
		
		ManufacturingOperationArray = New Array;
		
		HTTPConnection = New HTTPConnection(Common.ObjectAttributeValue(ExchangeNode, "WebService"));
		
		Headers = New Map;
		Headers.Insert("Content-type", "application/json");	
		
		StartDate = DateOfLastExchange(ExchangeNode);
		HTTPRequest = New HTTPRequest("/GetProductList?pStartDate=" + Format(StartDate, "DLF=DT") + "&pEndDate=" + Format(ExchangeParameters.CreationDate, "DLF=DT"),
		Headers);
		
		Result = HTTPConnection.Get(HTTPRequest);
		ResponseBody = Result.GetBodyAsString(TextEncoding.UTF8);
		
		JSONReader = New JSONReader;
		JSONReader.SetString(ResponseBody);
		
		ResponseArray = ReadJSON(JSONReader);
		
		For Each ResponseStrucutre In ResponseArray Do
			
			If ResponseStrucutre.Property("ORDERNO")
				And ResponseStrucutre.ORDERNO = Undefined Then
				Continue;
			EndIf;
			
			If ResponseStrucutre.Property("ORDEROPID")
				And ResponseStrucutre.ORDEROPID = Undefined Then
				Continue;
			EndIf;
			
			Record = InformationRegisters.ProManageData.CreateRecordManager();
			ManufacturingOperation = Documents.ManufacturingOperation.FindByNumber(ResponseStrucutre.ORDERNO, CurrentDate());
			
			UUID = New UUID(ResponseStrucutre.ORDEROPID);
			Activity = Catalogs.ManufacturingActivities.GetRef(UUID);
			Record.Read();
			
			Record.ManufacturingOperation = ManufacturingOperation;
			Record.Activity = Activity;
			
			StartDate = ReadJSONDate(StrReplace(ResponseStrucutre.STARTDATE, "+0300", ""), JSONDateFormat.Microsoft);
			FinishDate = ReadJSONDate(StrReplace(ResponseStrucutre.ENDDATE, "+0300", ""), JSONDateFormat.Microsoft);
			
			Record.StartDate =			?(Record.StartDate = Date(1,1,1), StartDate, Min(Record.StartDate, StartDate));
			Record.FinishDate =			Max(Record.FinishDate, FinishDate);
			Record.Quantity	=			Record.Quantity + ResponseStrucutre.PRODQUANTITY;
			Record.QuantitySucceeded =	Record.QuantitySucceeded + ResponseStrucutre.PRODQUANTITY;
			Record.QuantityFailed =		Record.QuantityFailed + ResponseStrucutre.SCRAPAMOUNT;
			
			Record.Write();
			
			ManufacturingOperationArray.Add(ManufacturingOperation);
			
		EndDo;
		
		UniqueArray = New Array;
		Common.FillArrayWithUniqueValues(UniqueArray, ManufacturingOperationArray);
		
		For Each ManufacturingOperation In UniqueArray DO
			FinishOperationsProManage(ManufacturingOperation);
		EndDo;
		
	Except
		
		Error = True;
		
	EndTry;
	
	CommitCompletionOfSync(InformationTableCommonRow, Error);
	
EndFunction

Procedure ExecuteActionsOnExchangeCompletion(Parameters, InformationTable, Error = False)
	
	InformationTable.FillValues(Parameters.ExchangeNode, "ExchangeSetting");
	
	For Each InformationTableRow In InformationTable Do
		
		LogEvent = GetEventLogMessageKey(Parameters.ExchangeNode,
			InformationTableRow.ActionOnExchange);
		
		If InformationTableRow.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Completed Then
			LogLevel = EventLogLevel.Information;
		Else
			LogLevel = EventLogLevel.Error;
		EndIf;
		
		If Error Then
			LogLevel = EventLogLevel.Error;
		EndIf;
		
		WriteLogEvent(LogEvent,
			LogLevel,
			Parameters.ExchangeNode.Metadata(),
			Parameters.ExchangeNode,
			Parameters.ExchangeStartMode + Chars.LF + InformationTableRow.Description);
			
	EndDo;

	UploadRows = InformationTable.FindRows(New Structure("ActionOnExchange",
		Enums.ActionsOnExchange.DataExport));
	
	If UploadRows.Count() = 2 Then
		
		If UploadRows[1].ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error Then
			UploadRows[0].ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
		EndIf;
		
		InformationTable.Delete(UploadRows[1]);
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	For Each InformationTableRow In InformationTable Do
		
		StatusRecord = InformationRegisters.StatesOfExchangeWithProManage.CreateRecordManager();
		FillPropertyValues(StatusRecord, InformationTableRow);
		
		StatusRecord.StartDate = Parameters.CreationDate;
		StatusRecord.EndDate = CurrentSessionDate();
		StatusRecord.Write();
		
	EndDo;
		
EndProcedure

Function GetEventLogMessageKey(ExchangePlanNode, ActionsOnExchange)
	
	ExchangePlanName     = ExchangePlanNode.Metadata().Name;
	
	MessageKey = NStr("en = 'Data exchange ""%1"". Details: %2.'; ru = 'Обмен данными ""%1"". Подробнее: %2.';pl = 'Wymiana danych ""%1"". Szczegóły: %2.';es_ES = 'Intercambio de datos ""%1"". Detalles: %2.';es_CO = 'Intercambio de datos ""%1"". Detalles: %2.';tr = 'Veri değişimi ""%1"". Ayrıntılar: %2.';it = 'Scambio dati ""%1"". Dettagli: %2.';de = 'Datenaustausch""%1"". Details: %2.'",
		CommonClientServer.DefaultLanguageCode());
	MessageKey = StringFunctionsClientServer.SubstituteParametersToString(MessageKey,
		 ExchangePlanName,
		 ActionsOnExchange);		 
	
	Return MessageKey;
	
EndFunction

Function DateOfLastExchange(ExchangeNode) 
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	StatesOfExchangeWithProManage.StartDate AS StartDate
	|FROM
	|	InformationRegister.StatesOfExchangeWithProManage AS StatesOfExchangeWithProManage
	|WHERE
	|	StatesOfExchangeWithProManage.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
	|	AND StatesOfExchangeWithProManage.ExchangeSetting = &ExchangeSetting
	|	AND StatesOfExchangeWithProManage.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
	|
	|ORDER BY
	|	StatesOfExchangeWithProManage.EndDate DESC";
	
	Query.SetParameter("ExchangeSetting", ExchangeNode);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		DateOfLastExchange = Selection.StartDate;
	Else
		DateOfLastExchange = BegOfYear(CurrentDate());
	EndIf;

	Return DateOfLastExchange;
	
EndFunction

Procedure CommitCompletionOfSync(InformationTableCommonRow, Error)
	
	If Error Then
		InformationTableCommonRow.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
		CompletionText = InformationTableCommonRow.Description;
	Else
		InformationTableCommonRow.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Completed;
		CompletionText = NStr("en = 'Sync with ProManage completed.'; ru = 'Синхронизация с ProManage завершена.';pl = 'Synchronizacja z ProManage została zakończona.';es_ES = 'Se ha finalizado la sincronización con ProManage.';es_CO = 'Se ha finalizado la sincronización con ProManage.';tr = 'ProManage ile senkronizasyon tamamlandı.';it = 'Sincronizzazione con ProManage completata.';de = 'Synchronisieren mit ProManage abgeschlossen.'");
	EndIf;
	
	EndDate = CurrentSessionDate();
	
	InformationTableCommonRow.Description = InformationTableCommonRow.Description + Chars.LF
		+ EndDate + " " + CompletionText;
		
	InformationTableCommonRow.EndDate = EndDate;
	
EndProcedure

Function NeedForRegistration(Source)

	For Each Row In Source.Activities Do
		
		If Row.Activity.WorkCenterTypes.Count() Then
			Return True;
		EndIf;
		
	EndDo;
		
	Return False;

EndFunction

#EndRegion