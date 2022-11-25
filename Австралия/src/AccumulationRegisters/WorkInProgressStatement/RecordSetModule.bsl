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
	LockItem = Block.Add("AccumulationRegister.WorkInProgressStatement.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsWorkInProgressStatementChange")
		OR StructureTemporaryTables.Property("RegisterRecordsWorkInProgressStatementChange")
			AND Not StructureTemporaryTables.RegisterRecordsWorkInProgressStatementChange Then
		
		// If the temporary table "RegisterRecordsWorkInProgressStatementChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsWorkInProgressStatementBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	WorkInProgressStatement.LineNumber AS LineNumber,
		|	WorkInProgressStatement.Company AS Company,
		|	WorkInProgressStatement.ProductionOrder AS ProductionOrder,
		|	WorkInProgressStatement.Products AS Products,
		|	WorkInProgressStatement.Characteristic AS Characteristic,
		|	WorkInProgressStatement.Specification AS Specification,
		|	CASE
		|		WHEN WorkInProgressStatement.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN WorkInProgressStatement.Quantity
		|		ELSE -WorkInProgressStatement.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsWorkInProgressStatementBeforeWrite
		|FROM
		|	AccumulationRegister.WorkInProgressStatement AS WorkInProgressStatement
		|WHERE
		|	WorkInProgressStatement.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsWorkInProgressStatementChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsWorkInProgressStatementBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsWorkInProgressStatementChange.LineNumber AS LineNumber,
		|	RegisterRecordsWorkInProgressStatementChange.Company AS Company,
		|	RegisterRecordsWorkInProgressStatementChange.ProductionOrder AS ProductionOrder,
		|	RegisterRecordsWorkInProgressStatementChange.Products AS Products,
		|	RegisterRecordsWorkInProgressStatementChange.Characteristic AS Characteristic,
		|	RegisterRecordsWorkInProgressStatementChange.Specification AS Specification,
		|	RegisterRecordsWorkInProgressStatementChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsWorkInProgressStatementBeforeWrite
		|FROM
		|	RegisterRecordsWorkInProgressStatementChange AS RegisterRecordsWorkInProgressStatementChange
		|
		|UNION ALL
		|
		|SELECT
		|	WorkInProgressStatement.LineNumber,
		|	WorkInProgressStatement.Company,
		|	WorkInProgressStatement.ProductionOrder,
		|	WorkInProgressStatement.Products,
		|	WorkInProgressStatement.Characteristic,
		|	WorkInProgressStatement.Specification,
		|	CASE
		|		WHEN WorkInProgressStatement.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN WorkInProgressStatement.Quantity
		|		ELSE -WorkInProgressStatement.Quantity
		|	END
		|FROM
		|	AccumulationRegister.WorkInProgressStatement AS WorkInProgressStatement
		|WHERE
		|	WorkInProgressStatement.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsWorkInProgressStatementChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsWorkInProgressStatementChange") Then
		
		Query = New Query("DROP RegisterRecordsWorkInProgressStatementChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsWorkInProgressStatementChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsWorkInProgressStatementChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsWorkInProgressStatementChange.LineNumber) AS LineNumber,
	|	RegisterRecordsWorkInProgressStatementChange.Company AS Company,
	|	RegisterRecordsWorkInProgressStatementChange.ProductionOrder AS ProductionOrder,
	|	RegisterRecordsWorkInProgressStatementChange.Products AS Products,
	|	RegisterRecordsWorkInProgressStatementChange.Characteristic AS Characteristic,
	|	RegisterRecordsWorkInProgressStatementChange.Specification AS Specification,
	|	SUM(RegisterRecordsWorkInProgressStatementChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsWorkInProgressStatementChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsWorkInProgressStatementChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsWorkInProgressStatementChange
	|FROM
	|	(SELECT
	|		RegisterRecordsWorkInProgressStatementBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsWorkInProgressStatementBeforeWrite.Company AS Company,
	|		RegisterRecordsWorkInProgressStatementBeforeWrite.ProductionOrder AS ProductionOrder,
	|		RegisterRecordsWorkInProgressStatementBeforeWrite.Products AS Products,
	|		RegisterRecordsWorkInProgressStatementBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsWorkInProgressStatementBeforeWrite.Specification AS Specification,
	|		RegisterRecordsWorkInProgressStatementBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsWorkInProgressStatementBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsWorkInProgressStatementBeforeWrite AS RegisterRecordsWorkInProgressStatementBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsWorkInProgressStatementOnWrite.LineNumber,
	|		RegisterRecordsWorkInProgressStatementOnWrite.Company,
	|		RegisterRecordsWorkInProgressStatementOnWrite.ProductionOrder,
	|		RegisterRecordsWorkInProgressStatementOnWrite.Products,
	|		RegisterRecordsWorkInProgressStatementOnWrite.Characteristic,
	|		RegisterRecordsWorkInProgressStatementOnWrite.Specification,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsWorkInProgressStatementOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsWorkInProgressStatementOnWrite.Quantity
	|			ELSE RegisterRecordsWorkInProgressStatementOnWrite.Quantity
	|		END,
	|		RegisterRecordsWorkInProgressStatementOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.WorkInProgressStatement AS RegisterRecordsWorkInProgressStatementOnWrite
	|	WHERE
	|		RegisterRecordsWorkInProgressStatementOnWrite.Recorder = &Recorder) AS RegisterRecordsWorkInProgressStatementChange
	|
	|GROUP BY
	|	RegisterRecordsWorkInProgressStatementChange.Company,
	|	RegisterRecordsWorkInProgressStatementChange.ProductionOrder,
	|	RegisterRecordsWorkInProgressStatementChange.Products,
	|	RegisterRecordsWorkInProgressStatementChange.Characteristic,
	|	RegisterRecordsWorkInProgressStatementChange.Specification
	|
	|HAVING
	|	SUM(RegisterRecordsWorkInProgressStatementChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	ProductionOrder,
	|	Products,
	|	Characteristic,
	|	Specification");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsWorkInProgressStatementChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsWorkInProgressStatementChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsWorkInProgressStatementBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsWorkInProgressStatementBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf