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
	LockItem = Block.Add("AccumulationRegister.ProductionAccomplishment.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsProductionAccomplishmentChange")
		OR StructureTemporaryTables.Property("RegisterRecordsProductionAccomplishmentChange")
			AND Not StructureTemporaryTables.RegisterRecordsProductionAccomplishmentChange Then
		
		// If the temporary table "RegisterRecordsProductionAccomplishmentChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsProductionAccomplishmentBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	ProductionAccomplishment.RecordType AS RecordType,
		|	ProductionAccomplishment.LineNumber AS LineNumber,
		|	ProductionAccomplishment.WorkInProgress AS WorkInProgress,
		|	ProductionAccomplishment.Operation AS Operation,
		|	ProductionAccomplishment.ConnectionKey AS ConnectionKey,
		|	CASE
		|		WHEN ProductionAccomplishment.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN ProductionAccomplishment.Quantity
		|		ELSE -ProductionAccomplishment.Quantity
		|	END AS QuantityBeforeWrite,
		|	CASE
		|		WHEN ProductionAccomplishment.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN ProductionAccomplishment.QuantityProduced
		|		ELSE -ProductionAccomplishment.QuantityProduced
		|	END AS QuantityProducedBeforeWrite
		|INTO RegisterRecordsProductionAccomplishmentBeforeWrite
		|FROM
		|	AccumulationRegister.ProductionAccomplishment AS ProductionAccomplishment
		|WHERE
		|	ProductionAccomplishment.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsProductionAccomplishmentChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsProductionAccomplishmentBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsProductionAccomplishmentChange.RecordType AS RecordType,
		|	RegisterRecordsProductionAccomplishmentChange.LineNumber AS LineNumber,
		|	RegisterRecordsProductionAccomplishmentChange.WorkInProgress AS WorkInProgress,
		|	RegisterRecordsProductionAccomplishmentChange.Operation AS Operation,
		|	RegisterRecordsProductionAccomplishmentChange.ConnectionKey AS ConnectionKey,
		|	RegisterRecordsProductionAccomplishmentChange.QuantityBeforeWrite AS QuantityBeforeWrite,
		|	RegisterRecordsProductionAccomplishmentChange.QuantityProducedBeforeWrite AS QuantityProducedBeforeWrite
		|INTO RegisterRecordsProductionAccomplishmentBeforeWrite
		|FROM
		|	RegisterRecordsProductionAccomplishmentChange AS RegisterRecordsProductionAccomplishmentChange
		|
		|UNION ALL
		|
		|SELECT
		|	ProductionAccomplishment.RecordType,
		|	ProductionAccomplishment.LineNumber,
		|	ProductionAccomplishment.WorkInProgress,
		|	ProductionAccomplishment.Operation,
		|	ProductionAccomplishment.ConnectionKey,
		|	CASE
		|		WHEN ProductionAccomplishment.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN ProductionAccomplishment.Quantity
		|		ELSE -ProductionAccomplishment.Quantity
		|	END,
		|	CASE
		|		WHEN ProductionAccomplishment.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN ProductionAccomplishment.QuantityProduced
		|		ELSE -ProductionAccomplishment.QuantityProduced
		|	END
		|FROM
		|	AccumulationRegister.ProductionAccomplishment AS ProductionAccomplishment
		|WHERE
		|	ProductionAccomplishment.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsProductionAccomplishmentChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsProductionAccomplishmentChange") Then
		
		Query = New Query("DROP RegisterRecordsProductionAccomplishmentChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsProductionAccomplishmentChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsProductionAccomplishmentChange".
	
	Query = New Query(
	"SELECT
	|	RegisterRecordsProductionAccomplishmentChange.RecordType AS RecordType,
	|	MIN(RegisterRecordsProductionAccomplishmentChange.LineNumber) AS LineNumber,
	|	RegisterRecordsProductionAccomplishmentChange.WorkInProgress AS WorkInProgress,
	|	RegisterRecordsProductionAccomplishmentChange.Operation AS Operation,
	|	RegisterRecordsProductionAccomplishmentChange.ConnectionKey AS ConnectionKey,
	|	SUM(RegisterRecordsProductionAccomplishmentChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsProductionAccomplishmentChange.QuantityProducedChange) AS QuantityProducedChange
	|INTO RegisterRecordsProductionAccomplishmentChange
	|FROM
	|	(SELECT
	|		RegisterRecordsProductionAccomplishmentBeforeWrite.RecordType AS RecordType,
	|		RegisterRecordsProductionAccomplishmentBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsProductionAccomplishmentBeforeWrite.WorkInProgress AS WorkInProgress,
	|		RegisterRecordsProductionAccomplishmentBeforeWrite.Operation AS Operation,
	|		RegisterRecordsProductionAccomplishmentBeforeWrite.ConnectionKey AS ConnectionKey,
	|		RegisterRecordsProductionAccomplishmentBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		RegisterRecordsProductionAccomplishmentBeforeWrite.QuantityProducedBeforeWrite AS QuantityProducedChange
	|	FROM
	|		RegisterRecordsProductionAccomplishmentBeforeWrite AS RegisterRecordsProductionAccomplishmentBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsProductionAccomplishmentOnWrite.RecordType,
	|		RegisterRecordsProductionAccomplishmentOnWrite.LineNumber,
	|		RegisterRecordsProductionAccomplishmentOnWrite.WorkInProgress,
	|		RegisterRecordsProductionAccomplishmentOnWrite.Operation,
	|		RegisterRecordsProductionAccomplishmentOnWrite.ConnectionKey,
	|		CASE
	|			WHEN RegisterRecordsProductionAccomplishmentOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsProductionAccomplishmentOnWrite.Quantity
	|			ELSE RegisterRecordsProductionAccomplishmentOnWrite.Quantity
	|		END,
	|		CASE
	|			WHEN RegisterRecordsProductionAccomplishmentOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsProductionAccomplishmentOnWrite.QuantityProduced
	|			ELSE RegisterRecordsProductionAccomplishmentOnWrite.QuantityProduced
	|		END
	|	FROM
	|		AccumulationRegister.ProductionAccomplishment AS RegisterRecordsProductionAccomplishmentOnWrite
	|	WHERE
	|		RegisterRecordsProductionAccomplishmentOnWrite.Recorder = &Recorder) AS RegisterRecordsProductionAccomplishmentChange
	|
	|GROUP BY
	|	RegisterRecordsProductionAccomplishmentChange.RecordType,
	|	RegisterRecordsProductionAccomplishmentChange.WorkInProgress,
	|	RegisterRecordsProductionAccomplishmentChange.Operation,
	|	RegisterRecordsProductionAccomplishmentChange.ConnectionKey
	|
	|HAVING
	|	(SUM(RegisterRecordsProductionAccomplishmentChange.QuantityChange) <> 0
	|		OR SUM(RegisterRecordsProductionAccomplishmentChange.QuantityProducedChange) <> 0)");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsProductionAccomplishmentChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsProductionAccomplishmentChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsProductionAccomplishmentBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsProductionAccomplishmentBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf