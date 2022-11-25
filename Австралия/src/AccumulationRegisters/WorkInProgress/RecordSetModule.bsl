#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

// Procedure - event handler BeforeWrite record set.
//
Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR Not AdditionalProperties.Property("ForPosting")
		OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Setting the exclusive lock of current registrar record set.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.WorkInProgress.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsWorkInProgressChange")
		OR StructureTemporaryTables.Property("RegisterRecordsWorkInProgressChange")
			AND Not StructureTemporaryTables.RegisterRecordsWorkInProgressChange Then
		
		// If the temporary table "RegisterRecordsWorkInProgressChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsWorkInProgressBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	WorkInProgress.LineNumber AS LineNumber,
		|	WorkInProgress.Company AS Company,
		|	WorkInProgress.PresentationCurrency AS PresentationCurrency,
		|	WorkInProgress.StructuralUnit AS StructuralUnit,
		|	WorkInProgress.CostObject AS CostObject,
		|	WorkInProgress.Products AS Products,
		|	WorkInProgress.Characteristic AS Characteristic,
		|	CASE
		|		WHEN WorkInProgress.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN WorkInProgress.Quantity
		|		ELSE -WorkInProgress.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsWorkInProgressBeforeWrite
		|FROM
		|	AccumulationRegister.WorkInProgress AS WorkInProgress
		|WHERE
		|	WorkInProgress.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsWorkInProgressChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsWorkInProgressBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsWorkInProgressChange.LineNumber AS LineNumber,
		|	RegisterRecordsWorkInProgressChange.Company AS Company,
		|	RegisterRecordsWorkInProgressChange.PresentationCurrency AS PresentationCurrency,
		|	RegisterRecordsWorkInProgressChange.StructuralUnit AS StructuralUnit,
		|	RegisterRecordsWorkInProgressChange.CostObject AS CostObject,
		|	RegisterRecordsWorkInProgressChange.Products AS Products,
		|	RegisterRecordsWorkInProgressChange.Characteristic AS Characteristic,
		|	RegisterRecordsWorkInProgressChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsWorkInProgressBeforeWrite
		|FROM
		|	RegisterRecordsWorkInProgressChange AS RegisterRecordsWorkInProgressChange
		|
		|UNION ALL
		|
		|SELECT
		|	WorkInProgress.LineNumber,
		|	WorkInProgress.Company,
		|	WorkInProgress.PresentationCurrency,
		|	WorkInProgress.StructuralUnit,
		|	WorkInProgress.CostObject,
		|	WorkInProgress.Products,
		|	WorkInProgress.Characteristic,
		|	CASE
		|		WHEN WorkInProgress.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN WorkInProgress.Quantity
		|		ELSE -WorkInProgress.Quantity
		|	END
		|FROM
		|	AccumulationRegister.WorkInProgress AS WorkInProgress
		|WHERE
		|	WorkInProgress.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsWorkInProgressChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsWorkInProgressChange") Then
		
		Query = New Query("DROP RegisterRecordsWorkInProgressChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsWorkInProgressChange");
	
	EndIf;
	
EndProcedure

// Procedure - event handler OnWrite record set.
//
Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR Not AdditionalProperties.Property("ForPosting")
		OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// New set change is calculated relatively current with accounting
	// accumulated changes and placed into temporary table "RegisterRecordsWorkInProgressChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsWorkInProgressChange.LineNumber) AS LineNumber,
	|	RegisterRecordsWorkInProgressChange.Company AS Company,
	|	RegisterRecordsWorkInProgressChange.PresentationCurrency AS PresentationCurrency,
	|	RegisterRecordsWorkInProgressChange.StructuralUnit AS StructuralUnit,
	|	RegisterRecordsWorkInProgressChange.CostObject AS CostObject,
	|	RegisterRecordsWorkInProgressChange.Products AS Products,
	|	RegisterRecordsWorkInProgressChange.Characteristic AS Characteristic,
	|	SUM(RegisterRecordsWorkInProgressChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsWorkInProgressChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsWorkInProgressChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsWorkInProgressChange
	|FROM
	|	(SELECT
	|		RegisterRecordsWorkInProgressBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsWorkInProgressBeforeWrite.Company AS Company,
	|		RegisterRecordsWorkInProgressBeforeWrite.PresentationCurrency AS PresentationCurrency,
	|		RegisterRecordsWorkInProgressBeforeWrite.StructuralUnit AS StructuralUnit,
	|		RegisterRecordsWorkInProgressBeforeWrite.CostObject AS CostObject,
	|		RegisterRecordsWorkInProgressBeforeWrite.Products AS Products,
	|		RegisterRecordsWorkInProgressBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsWorkInProgressBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsWorkInProgressBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsWorkInProgressBeforeWrite AS RegisterRecordsWorkInProgressBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsWorkInProgressOnWrite.LineNumber,
	|		RegisterRecordsWorkInProgressOnWrite.Company,
	|		RegisterRecordsWorkInProgressOnWrite.PresentationCurrency,
	|		RegisterRecordsWorkInProgressOnWrite.StructuralUnit,
	|		RegisterRecordsWorkInProgressOnWrite.CostObject,
	|		RegisterRecordsWorkInProgressOnWrite.Products,
	|		RegisterRecordsWorkInProgressOnWrite.Characteristic,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsWorkInProgressOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsWorkInProgressOnWrite.Quantity
	|			ELSE RegisterRecordsWorkInProgressOnWrite.Quantity
	|		END,
	|		RegisterRecordsWorkInProgressOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.WorkInProgress AS RegisterRecordsWorkInProgressOnWrite
	|	WHERE
	|		RegisterRecordsWorkInProgressOnWrite.Recorder = &Recorder) AS RegisterRecordsWorkInProgressChange
	|
	|GROUP BY
	|	RegisterRecordsWorkInProgressChange.Company,
	|	RegisterRecordsWorkInProgressChange.PresentationCurrency,
	|	RegisterRecordsWorkInProgressChange.StructuralUnit,
	|	RegisterRecordsWorkInProgressChange.CostObject,
	|	RegisterRecordsWorkInProgressChange.Products,
	|	RegisterRecordsWorkInProgressChange.Characteristic
	|
	|HAVING
	|	SUM(RegisterRecordsWorkInProgressChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	StructuralUnit,
	|	CostObject,
	|	Products,
	|	Characteristic");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsWorkInProgressChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsWorkInProgressChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsWorkInProgressBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsWorkInProgressBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf