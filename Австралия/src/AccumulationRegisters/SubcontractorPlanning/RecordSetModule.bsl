#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler BeforeWrite record set.
//
Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load
		Or Not AdditionalProperties.Property("ForPosting")
		Or Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Setting the exclusive lock of current registrar record set.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.SubcontractorPlanning.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsSubcontractorPlanningChange") Or
		StructureTemporaryTables.Property("RegisterRecordsSubcontractorPlanningChange") And Not StructureTemporaryTables.RegisterRecordsSubcontractorPlanningChange Then
		
		// If the temporary table "RegisterRecordsSubcontractorPlanningChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsSubcontractorPlanningBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	SubcontractorPlanning.LineNumber AS LineNumber,
		|	SubcontractorPlanning.Company AS Company,
		|	SubcontractorPlanning.WorkInProgress AS WorkInProgress,
		|	SubcontractorPlanning.Products AS Products,
		|	SubcontractorPlanning.Characteristic AS Characteristic,
		|	CASE
		|		WHEN SubcontractorPlanning.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN SubcontractorPlanning.Quantity
		|		ELSE -SubcontractorPlanning.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsSubcontractorPlanningBeforeWrite
		|FROM
		|	AccumulationRegister.SubcontractorPlanning AS SubcontractorPlanning
		|WHERE
		|	SubcontractorPlanning.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsSubcontractorPlanningChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsSubcontractorPlanningBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsSubcontractorPlanningChange.LineNumber AS LineNumber,
		|	RegisterRecordsSubcontractorPlanningChange.Company AS Company,
		|	RegisterRecordsSubcontractorPlanningChange.WorkInProgress AS WorkInProgress,
		|	RegisterRecordsSubcontractorPlanningChange.Products AS Products,
		|	RegisterRecordsSubcontractorPlanningChange.Characteristic AS Characteristic,
		|	RegisterRecordsSubcontractorPlanningChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsSubcontractorPlanningBeforeWrite
		|FROM
		|	RegisterRecordsSubcontractorPlanningChange AS RegisterRecordsSubcontractorPlanningChange
		|
		|UNION ALL
		|
		|SELECT
		|	SubcontractorPlanning.LineNumber,
		|	SubcontractorPlanning.Company,
		|	SubcontractorPlanning.WorkInProgress,
		|	SubcontractorPlanning.Products,
		|	SubcontractorPlanning.Characteristic,
		|	CASE
		|		WHEN SubcontractorPlanning.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN SubcontractorPlanning.Quantity
		|		ELSE -SubcontractorPlanning.Quantity
		|	END
		|FROM
		|	AccumulationRegister.SubcontractorPlanning AS SubcontractorPlanning
		|WHERE
		|	SubcontractorPlanning.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsSubcontractorPlanningChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsSubcontractorPlanningChange") Then
		
		Query = New Query("DROP RegisterRecordsSubcontractorPlanningChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsSubcontractorPlanningChange");
	
	EndIf;
	
EndProcedure

// Procedure - event handler OnWrite record set.
//
Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load
		Or Not AdditionalProperties.Property("ForPosting")
		Or Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then	
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// New set change is calculated relatively current with accounting
	// accumulated changes and placed into temporary table "RegisterRecordsSubcontractorPlanningChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsSubcontractorPlanningChange.LineNumber) AS LineNumber,
	|	RegisterRecordsSubcontractorPlanningChange.Company AS Company,
	|	RegisterRecordsSubcontractorPlanningChange.WorkInProgress AS WorkInProgress,
	|	RegisterRecordsSubcontractorPlanningChange.Products AS Products,
	|	RegisterRecordsSubcontractorPlanningChange.Characteristic AS Characteristic,
	|	SUM(RegisterRecordsSubcontractorPlanningChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsSubcontractorPlanningChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsSubcontractorPlanningChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsSubcontractorPlanningChange
	|FROM
	|	(SELECT
	|		RegisterRecordsSubcontractorPlanningBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsSubcontractorPlanningBeforeWrite.Company AS Company,
	|		RegisterRecordsSubcontractorPlanningBeforeWrite.WorkInProgress AS WorkInProgress,
	|		RegisterRecordsSubcontractorPlanningBeforeWrite.Products AS Products,
	|		RegisterRecordsSubcontractorPlanningBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsSubcontractorPlanningBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsSubcontractorPlanningBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsSubcontractorPlanningBeforeWrite AS RegisterRecordsSubcontractorPlanningBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsSubcontractorPlanningOnWrite.LineNumber,
	|		RegisterRecordsSubcontractorPlanningOnWrite.Company,
	|		RegisterRecordsSubcontractorPlanningOnWrite.WorkInProgress,
	|		RegisterRecordsSubcontractorPlanningOnWrite.Products,
	|		RegisterRecordsSubcontractorPlanningOnWrite.Characteristic,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsSubcontractorPlanningOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsSubcontractorPlanningOnWrite.Quantity
	|			ELSE RegisterRecordsSubcontractorPlanningOnWrite.Quantity
	|		END,
	|		RegisterRecordsSubcontractorPlanningOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.SubcontractorPlanning AS RegisterRecordsSubcontractorPlanningOnWrite
	|	WHERE
	|		RegisterRecordsSubcontractorPlanningOnWrite.Recorder = &Recorder) AS RegisterRecordsSubcontractorPlanningChange
	|
	|GROUP BY
	|	RegisterRecordsSubcontractorPlanningChange.Company,
	|	RegisterRecordsSubcontractorPlanningChange.WorkInProgress,
	|	RegisterRecordsSubcontractorPlanningChange.Products,
	|	RegisterRecordsSubcontractorPlanningChange.Characteristic
	|
	|HAVING
	|	SUM(RegisterRecordsSubcontractorPlanningChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	WorkInProgress,
	|	Products,
	|	Characteristic");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsSubcontractorPlanningChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsSubcontractorPlanningChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsSubcontractorPlanningBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsSubcontractorPlanningBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf