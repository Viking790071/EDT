#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

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
	LockItem = Block.Add("AccumulationRegister.KitOrders.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsKitOrdersChange")
		Or StructureTemporaryTables.Property("RegisterRecordsKitOrdersChange")
		And Not StructureTemporaryTables.RegisterRecordsKitOrdersChange Then
		
		// If the temporary table "RegisterRecordsKitOrdersChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsKitOrdersBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	KitOrders.LineNumber AS LineNumber,
		|	KitOrders.Company AS Company,
		|	KitOrders.KitOrder AS KitOrder,
		|	KitOrders.Products AS Products,
		|	KitOrders.Characteristic AS Characteristic,
		|	CASE
		|		WHEN KitOrders.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN KitOrders.Quantity
		|		ELSE -KitOrders.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsKitOrdersBeforeWrite
		|FROM
		|	AccumulationRegister.KitOrders AS KitOrders
		|WHERE
		|	KitOrders.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsKitOrdersChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsKitOrdersBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsKitOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsKitOrdersChange.Company AS Company,
		|	RegisterRecordsKitOrdersChange.KitOrder AS KitOrder,
		|	RegisterRecordsKitOrdersChange.Products AS Products,
		|	RegisterRecordsKitOrdersChange.Characteristic AS Characteristic,
		|	RegisterRecordsKitOrdersChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsKitOrdersBeforeWrite
		|FROM
		|	RegisterRecordsKitOrdersChange AS RegisterRecordsKitOrdersChange
		|
		|UNION ALL
		|
		|SELECT
		|	KitOrders.LineNumber,
		|	KitOrders.Company,
		|	KitOrders.KitOrder,
		|	KitOrders.Products,
		|	KitOrders.Characteristic,
		|	CASE
		|		WHEN KitOrders.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN KitOrders.Quantity
		|		ELSE -KitOrders.Quantity
		|	END
		|FROM
		|	AccumulationRegister.KitOrders AS KitOrders
		|WHERE
		|	KitOrders.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsKitOrdersChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsKitOrdersChange") Then
		
		Query = New Query("DROP RegisterRecordsKitOrdersChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsKitOrdersChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsKitOrdersChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsKitOrdersChange.LineNumber) AS LineNumber,
	|	RegisterRecordsKitOrdersChange.Company AS Company,
	|	RegisterRecordsKitOrdersChange.KitOrder AS KitOrder,
	|	RegisterRecordsKitOrdersChange.Products AS Products,
	|	RegisterRecordsKitOrdersChange.Characteristic AS Characteristic,
	|	SUM(RegisterRecordsKitOrdersChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsKitOrdersChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsKitOrdersChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsKitOrdersChange
	|FROM
	|	(SELECT
	|		RegisterRecordsKitOrdersBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsKitOrdersBeforeWrite.Company AS Company,
	|		RegisterRecordsKitOrdersBeforeWrite.KitOrder AS KitOrder,
	|		RegisterRecordsKitOrdersBeforeWrite.Products AS Products,
	|		RegisterRecordsKitOrdersBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsKitOrdersBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsKitOrdersBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsKitOrdersBeforeWrite AS RegisterRecordsKitOrdersBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsKitOrdersOnWrite.LineNumber,
	|		RegisterRecordsKitOrdersOnWrite.Company,
	|		RegisterRecordsKitOrdersOnWrite.KitOrder,
	|		RegisterRecordsKitOrdersOnWrite.Products,
	|		RegisterRecordsKitOrdersOnWrite.Characteristic,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsKitOrdersOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsKitOrdersOnWrite.Quantity
	|			ELSE RegisterRecordsKitOrdersOnWrite.Quantity
	|		END,
	|		RegisterRecordsKitOrdersOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.KitOrders AS RegisterRecordsKitOrdersOnWrite
	|	WHERE
	|		RegisterRecordsKitOrdersOnWrite.Recorder = &Recorder) AS RegisterRecordsKitOrdersChange
	|
	|GROUP BY
	|	RegisterRecordsKitOrdersChange.Company,
	|	RegisterRecordsKitOrdersChange.KitOrder,
	|	RegisterRecordsKitOrdersChange.Products,
	|	RegisterRecordsKitOrdersChange.Characteristic
	|
	|HAVING
	|	SUM(RegisterRecordsKitOrdersChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	KitOrder,
	|	Products,
	|	Characteristic");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsKitOrdersChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsKitOrdersChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsKitOrdersBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsKitOrdersBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf