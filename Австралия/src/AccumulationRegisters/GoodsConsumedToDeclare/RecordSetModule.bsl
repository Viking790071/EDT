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
	LockItem = Block.Add("AccumulationRegister.GoodsConsumedToDeclare.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsGoodsConsumedToDeclareChange")
		OR StructureTemporaryTables.Property("RegisterRecordsGoodsConsumedToDeclareChange") AND Not StructureTemporaryTables.RegisterRecordsGoodsConsumedToDeclareChange Then
		
		// If the temporary table "RegisterRecordsGoodsConsumedToDeclare" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsGoodsConsumedToDeclareBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	GoodsConsumedToDeclare.LineNumber AS LineNumber,
		|	GoodsConsumedToDeclare.Company AS Company,
		|	GoodsConsumedToDeclare.Products AS Products,
		|	GoodsConsumedToDeclare.Characteristic AS Characteristic,
		|	GoodsConsumedToDeclare.Batch AS Batch,
		|	GoodsConsumedToDeclare.Counterparty AS Counterparty,
		|	CASE
		|		WHEN GoodsConsumedToDeclare.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN GoodsConsumedToDeclare.Quantity
		|		ELSE -GoodsConsumedToDeclare.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsGoodsConsumedToDeclareBeforeWrite
		|FROM
		|	AccumulationRegister.GoodsConsumedToDeclare AS GoodsConsumedToDeclare
		|WHERE
		|	GoodsConsumedToDeclare.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsGoodsConsumedToDeclareChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsInventoryBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsGoodsConsumedToDeclareChange.LineNumber AS LineNumber,
		|	RegisterRecordsGoodsConsumedToDeclareChange.Company AS Company,
		|	RegisterRecordsGoodsConsumedToDeclareChange.Products AS Products,
		|	RegisterRecordsGoodsConsumedToDeclareChange.Characteristic AS Characteristic,
		|	RegisterRecordsGoodsConsumedToDeclareChange.Batch AS Batch,
		|	RegisterRecordsGoodsConsumedToDeclareChange.Counterparty AS Counterparty,
		|	RegisterRecordsGoodsConsumedToDeclareChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsGoodsConsumedToDeclareBeforeWrite
		|FROM
		|	RegisterRecordsGoodsConsumedToDeclareChange AS RegisterRecordsGoodsConsumedToDeclareChange
		|
		|UNION ALL
		|
		|SELECT
		|	GoodsConsumedToDeclare.LineNumber,
		|	GoodsConsumedToDeclare.Company,
		|	GoodsConsumedToDeclare.Products,
		|	GoodsConsumedToDeclare.Characteristic,
		|	GoodsConsumedToDeclare.Batch,
		|	GoodsConsumedToDeclare.Counterparty,
		|	CASE
		|		WHEN GoodsConsumedToDeclare.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN GoodsConsumedToDeclare.Quantity
		|		ELSE -GoodsConsumedToDeclare.Quantity
		|	END
		|FROM
		|	AccumulationRegister.GoodsConsumedToDeclare AS GoodsConsumedToDeclare
		|WHERE
		|	GoodsConsumedToDeclare.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsGoodsConsumedToDeclareChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsGoodsConsumedToDeclareChange") Then
		
		Query = New Query("DROP RegisterRecordsGoodsConsumedToDeclareChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsGoodsConsumedToDeclareChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsGoodsConsumedToDeclareChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsGoodsConsumedToDeclareChange.LineNumber) AS LineNumber,
	|	RegisterRecordsGoodsConsumedToDeclareChange.Company AS Company,
	|	RegisterRecordsGoodsConsumedToDeclareChange.Products AS Products,
	|	RegisterRecordsGoodsConsumedToDeclareChange.Characteristic AS Characteristic,
	|	RegisterRecordsGoodsConsumedToDeclareChange.Batch AS Batch,
	|	RegisterRecordsGoodsConsumedToDeclareChange.Counterparty AS Counterparty,
	|	SUM(RegisterRecordsGoodsConsumedToDeclareChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsGoodsConsumedToDeclareChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsGoodsConsumedToDeclareChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsGoodsConsumedToDeclareChange
	|FROM
	|	(SELECT
	|		RegisterRecordsGoodsConsumedToDeclareBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsGoodsConsumedToDeclareBeforeWrite.Company AS Company,
	|		RegisterRecordsGoodsConsumedToDeclareBeforeWrite.Products AS Products,
	|		RegisterRecordsGoodsConsumedToDeclareBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsGoodsConsumedToDeclareBeforeWrite.Batch AS Batch,
	|		RegisterRecordsGoodsConsumedToDeclareBeforeWrite.Counterparty AS Counterparty,
	|		RegisterRecordsGoodsConsumedToDeclareBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsGoodsConsumedToDeclareBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsGoodsConsumedToDeclareBeforeWrite AS RegisterRecordsGoodsConsumedToDeclareBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsGoodsConsumedToDeclareOnWrite.LineNumber,
	|		RegisterRecordsGoodsConsumedToDeclareOnWrite.Company,
	|		RegisterRecordsGoodsConsumedToDeclareOnWrite.Products,
	|		RegisterRecordsGoodsConsumedToDeclareOnWrite.Characteristic,
	|		RegisterRecordsGoodsConsumedToDeclareOnWrite.Batch,
	|		RegisterRecordsGoodsConsumedToDeclareOnWrite.Counterparty,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsGoodsConsumedToDeclareOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsGoodsConsumedToDeclareOnWrite.Quantity
	|			ELSE RegisterRecordsGoodsConsumedToDeclareOnWrite.Quantity
	|		END,
	|		RegisterRecordsGoodsConsumedToDeclareOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.GoodsConsumedToDeclare AS RegisterRecordsGoodsConsumedToDeclareOnWrite
	|	WHERE
	|		RegisterRecordsGoodsConsumedToDeclareOnWrite.Recorder = &Recorder) AS RegisterRecordsGoodsConsumedToDeclareChange
	|
	|GROUP BY
	|	RegisterRecordsGoodsConsumedToDeclareChange.Company,
	|	RegisterRecordsGoodsConsumedToDeclareChange.Products,
	|	RegisterRecordsGoodsConsumedToDeclareChange.Characteristic,
	|	RegisterRecordsGoodsConsumedToDeclareChange.Batch,
	|	RegisterRecordsGoodsConsumedToDeclareChange.Counterparty
	|
	|HAVING
	|	SUM(RegisterRecordsGoodsConsumedToDeclareChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	RegisterRecordsGoodsConsumedToDeclareChange.Counterparty");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsGoodsConsumedToDeclareChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsGoodsConsumedToDeclareChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsInventoryBeforeWrite" temprorary table is deleted
	Query = New Query("DROP RegisterRecordsGoodsConsumedToDeclareBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf