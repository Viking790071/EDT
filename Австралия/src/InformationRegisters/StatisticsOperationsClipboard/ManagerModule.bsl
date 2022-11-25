#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

Procedure WriteBusinessStatisticsOperation(OperationName, Value, Comment = Undefined, Separator = ".") Export
	
	SetSafeModeDisabled(True);
    SetPrivilegedMode(True);
	
	DeletionIDPeriod = MonitoringCenterInternal.GetMonitoringCenterParameters("AggregationPeriodMinor");

	If Common.SubsystemExists("SaaSTechnology.Core") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		If ModuleSaaS.SessionSeparatorUsage() Then
			DataArea = Format(ModuleSaaS.SessionSeparatorValue(), "NZ=0; NG=0");
		Else
			DataArea = Format(0, "NZ=0; NG=0");
		EndIf;
	Else
		DataArea = Format(0, "NZ=0; NG=0");
	EndIf;
	
	CurDate = CurrentUniversalDateInMilliseconds();
		
	If Separator <> "." Then
		OperationName = StrReplace(OperationName, ".", "☼");
		OperationName = StrReplace(OperationName, Separator, ".");
	EndIf;
	
	OperationRef = MonitoringCenterCached.GetStatisticsOperationRef(OperationName);
	CommentRef = InformationRegisters.StatisticsComments.GetRef(Comment, OperationRef);
	DataAreaRef = InformationRegisters.StatisticsAreas.GetRef(DataArea);
	
	RecordManager = CreateRecordManager();
	RecordManager.RecordDate1 = CurDate;
	RecordManager.DeletionID = Int(Int(CurDate/1000)/DeletionIDPeriod)*DeletionIDPeriod;
	RecordManager.RecordID = New UUID();
	RecordManager.StatisticsOperation = OperationRef;
	RecordManager.StatisticsComment = CommentRef;
	RecordManager.StatisticsArea = DataAreaRef;
	RecordManager.Value = Value;
	
	RecordManager.Write(False);
	
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
    
EndProcedure

Procedure WriteBusinessStatisticsOperations(Operations) Export
	
	SetSafeModeDisabled(True);
    SetPrivilegedMode(True);
    
    DeletionIDPeriod = MonitoringCenterInternal.GetMonitoringCenterParameters("AggregationPeriodMinor");
    
    CurDate = CurrentUniversalDateInMilliseconds();
    DeletionID = Int(Int(CurDate/1000)/DeletionIDPeriod)*DeletionIDPeriod; 
    CommentRef = CommonClientServer.BlankUUID();
	DataAreaRef = InformationRegisters.StatisticsAreas.GetRef("0");
    
    RecordSet = CreateRecordSet();
    MaxRecordCount = 1000;
    
    For Each Operation In Operations Do
        
        NewRecord1 = RecordSet.Add();
        NewRecord1.RecordDate1 = CurDate;
        NewRecord1.DeletionID = DeletionID;
        NewRecord1.RecordID = New UUID();
        NewRecord1.StatisticsOperation = MonitoringCenterCached.GetStatisticsOperationRef(Operation.StatisticsOperation);
        NewRecord1.StatisticsComment = CommentRef;
        NewRecord1.StatisticsArea = DataAreaRef;
        NewRecord1.Value = Operation.Value;
        
        If RecordSet.Count() >= MaxRecordCount Then
            RecordSet.Write(False);
            RecordSet.Clear();
        EndIf;
                
    EndDo;
    
    If RecordSet.Count() > 0 Then
        RecordSet.Write(False);
        RecordSet.Clear();
	EndIf;                     
	
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
            
EndProcedure

Function GetAggregatedOperationsRecords(RecordDate1, AggregationPeriod, DeletionPeriod) Export
	Query = New Query;
	Query.Text = "
	|SELECT
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&AggregationPeriod - 0.5 AS NUMBER(15,0)) * &AggregationPeriod)/1000  - 63555667200
	|	) AS Period,
	|	StatisticsOperationsClipboard.StatisticsOperation AS StatisticsOperation,
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&DeletionPeriod - 0.5 AS NUMBER(15,0)) * &DeletionPeriod)/1000  - 63555667200
	|	) AS DeletionID,
	|   SUM(1) AS ValuesCount, 
	|	SUM(StatisticsOperationsClipboard.Value) AS ValueSum,
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&AggregationPeriod - 0.5 AS NUMBER(15,0)) * &AggregationPeriod)/1000  - 63555667200 + &AggregationPeriod/1000 - 1
	|	) AS PeriodEnd1
	|FROM
	|	InformationRegister.StatisticsOperationsClipboard AS StatisticsOperationsClipboard
	|WHERE
	|	StatisticsOperationsClipboard.RecordDate1 < &RecordDate1
	|GROUP BY
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&AggregationPeriod - 0.5 AS NUMBER(15,0)) * &AggregationPeriod)/1000  - 63555667200
	|	),
	|	StatisticsOperationsClipboard.StatisticsOperation,
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&DeletionPeriod - 0.5 AS NUMBER(15,0)) * &DeletionPeriod)/1000  - 63555667200
	|	),
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&AggregationPeriod - 0.5 AS NUMBER(15,0)) * &AggregationPeriod)/1000  - 63555667200 + &AggregationPeriod/1000 - 1
	|	)
	|ORDER BY
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&AggregationPeriod - 0.5 AS NUMBER(15,0)) * &AggregationPeriod)/1000  - 63555667200
	|	)
	|";
	
	Query.SetParameter("RecordDate1", (RecordDate1 - Date(1, 1, 1)) * 1000);
	Query.SetParameter("AggregationPeriod", AggregationPeriod * 1000);
	Query.SetParameter("DeletionPeriod", DeletionPeriod * 1000);
	
	QueryResult = Query.Execute();
	
	Return QueryResult;	
EndFunction

Function GetAggregatedRecordsComment(RecordDate1, AggregationPeriod, DeletionPeriod) Export
	Query = New Query;
	Query.Text = "
	|SELECT
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&AggregationPeriod - 0.5 AS NUMBER(15,0)) * &AggregationPeriod)/1000  - 63555667200
	|	) AS Period,
	|	StatisticsOperationsClipboard.StatisticsOperation AS StatisticsOperation,
	|	StatisticsOperationsClipboard.StatisticsComment AS StatisticsComment,
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&DeletionPeriod - 0.5 AS NUMBER(15,0)) * &DeletionPeriod)/1000  - 63555667200
	|	) AS DeletionID,
	|   SUM(1) AS ValuesCount,
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&AggregationPeriod - 0.5 AS NUMBER(15,0)) * &AggregationPeriod)/1000  - 63555667200 + &AggregationPeriod/1000 - 1
	|	) AS PeriodEnd1
	|FROM
	|	InformationRegister.StatisticsOperationsClipboard AS StatisticsOperationsClipboard
	|WHERE
	|	StatisticsOperationsClipboard.RecordDate1 < &RecordDate1
	|GROUP BY
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&AggregationPeriod - 0.5 AS NUMBER(15,0)) * &AggregationPeriod)/1000  - 63555667200
	|	),
	|	StatisticsOperationsClipboard.StatisticsOperation,
	|	StatisticsOperationsClipboard.StatisticsComment,
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&DeletionPeriod - 0.5 AS NUMBER(15,0)) * &DeletionPeriod)/1000  - 63555667200
	|	),
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&AggregationPeriod - 0.5 AS NUMBER(15,0)) * &AggregationPeriod)/1000  - 63555667200 + &AggregationPeriod/1000 - 1
	|	)
	|ORDER BY
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&AggregationPeriod - 0.5 AS NUMBER(15,0)) * &AggregationPeriod)/1000  - 63555667200
	|	)
	|";
	
	Query.SetParameter("RecordDate1", (RecordDate1 - Date(1, 1, 1)) * 1000);
	Query.SetParameter("AggregationPeriod", AggregationPeriod * 1000);
	Query.SetParameter("DeletionPeriod", DeletionPeriod * 1000);
	
	QueryResult = Query.Execute();
	
	Return QueryResult;	
EndFunction

Function GetAggregatedRecordsStatisticsAreas(RecordDate1, AggregationPeriod, DeletionPeriod) Export
	DeletionPeriod = 3600;
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&AggregationPeriod - 0.5 AS NUMBER(15,0)) * &AggregationPeriod)/1000  - 63555667200
	|	) AS Period,
	|	StatisticsOperationsClipboard.StatisticsOperation AS StatisticsOperation,
	|	StatisticsOperationsClipboard.StatisticsArea AS StatisticsArea,
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&DeletionPeriod - 0.5 AS NUMBER(15,0)) * &DeletionPeriod)/1000  - 63555667200
	|	) AS DeletionID,
	|   SUM(1) AS ValuesCount,
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&AggregationPeriod - 0.5 AS NUMBER(15,0)) * &AggregationPeriod)/1000  - 63555667200 + &AggregationPeriod/1000 - 1
	|	) AS PeriodEnd1
	|FROM
	|	InformationRegister.StatisticsOperationsClipboard AS StatisticsOperationsClipboard
	|WHERE
	|	StatisticsOperationsClipboard.RecordDate1 < &RecordDate1
	|GROUP BY
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&AggregationPeriod - 0.5 AS NUMBER(15,0)) * &AggregationPeriod)/1000  - 63555667200
	|	),
	|	StatisticsOperationsClipboard.StatisticsOperation,
	|	StatisticsOperationsClipboard.StatisticsArea,
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&DeletionPeriod - 0.5 AS NUMBER(15,0)) * &DeletionPeriod)/1000  - 63555667200
	|	),
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&AggregationPeriod - 0.5 AS NUMBER(15,0)) * &AggregationPeriod)/1000  - 63555667200 + &AggregationPeriod/1000 - 1
	|	)
	|ORDER BY
	|	DATEADD(
	|		DATETIME(2015,1,1),
	|		SECOND,
	|		(CAST(StatisticsOperationsClipboard.RecordDate1/&AggregationPeriod - 0.5 AS NUMBER(15,0)) * &AggregationPeriod)/1000  - 63555667200
	|	)
	|";
	
	Query.SetParameter("RecordDate1", (RecordDate1 - Date(1, 1, 1)) * 1000);
	Query.SetParameter("AggregationPeriod", AggregationPeriod * 1000);
	Query.SetParameter("DeletionPeriod", DeletionPeriod * 1000);
	
	QueryResult = Query.Execute();
	
	Return QueryResult;	
EndFunction

Procedure DeleteRecords(RecordDate1) Export
	Query = New Query;
	Query.Text = "
	|SELECT DISTINCT
	|	StatisticsOperationsClipboard.DeletionID AS DeletionID
	|FROM
	|	InformationRegister.StatisticsOperationsClipboard AS StatisticsOperationsClipboard
	|WHERE
	|	StatisticsOperationsClipboard.RecordDate1 < &RecordDate1
	|ORDER BY
	|	StatisticsOperationsClipboard.DeletionID
	|";
	
	Query.SetParameter("RecordDate1", (RecordDate1 - Date(1, 1, 1)) * 1000);
	
	QueryResult = Query.Execute();
	
	RecordSet = CreateRecordSet();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		RecordSet.Filter.DeletionID.Set(Selection.DeletionID);
		RecordSet.Write(True);
	EndDo;
EndProcedure

#EndRegion

#EndIf