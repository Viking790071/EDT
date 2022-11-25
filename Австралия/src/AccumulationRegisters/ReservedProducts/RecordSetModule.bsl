#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR Not AdditionalProperties.Property("ForPosting")
		OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Setting the exclusive lock of current registrar record set.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.ReservedProducts.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	Query = New Query();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsReservedProductsChange")
		OR (StructureTemporaryTables.Property("RegisterRecordsReservedProductsChange")
			AND Not StructureTemporaryTables.RegisterRecordsReservedProductsChange) Then
		
		// If the temporary table "RegisterRecordsReservedProductsChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsReservedProductsBeforeWrite" to get at record new set change rather current.
		
		Query.Text = 
		"SELECT
		|	Reserve.LineNumber AS LineNumber,
		|	Reserve.Company AS Company,
		|	Reserve.StructuralUnit AS StructuralUnit,
		|	Reserve.Products AS Products,
		|	Reserve.Characteristic AS Characteristic,
		|	Reserve.Batch AS Batch,
		|	Reserve.SalesOrder AS SalesOrder,
		|	CASE
		|		WHEN Reserve.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN Reserve.Quantity
		|		ELSE -Reserve.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsReservedProductsBeforeWrite
		|FROM
		|	AccumulationRegister.ReservedProducts AS Reserve
		|WHERE
		|	Reserve.Recorder = &Recorder
		|	AND &Replacing";
		
	Else
		
		// If the temporary table "RegisterRecordsReservedProductsChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsReservedProductsBeforeWrite" to get at record new set change rather initial.
		
		Query.Text = 
		"SELECT
		|	RegisterRecordsReservedProductsChange.LineNumber AS LineNumber,
		|	RegisterRecordsReservedProductsChange.Company AS Company,
		|	RegisterRecordsReservedProductsChange.StructuralUnit AS StructuralUnit,
		|	RegisterRecordsReservedProductsChange.Products AS Products,
		|	RegisterRecordsReservedProductsChange.Characteristic AS Characteristic,
		|	RegisterRecordsReservedProductsChange.Batch AS Batch,
		|	RegisterRecordsReservedProductsChange.SalesOrder AS SalesOrder,
		|	RegisterRecordsReservedProductsChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsReservedProductsBeforeWrite
		|FROM
		|	RegisterRecordsReservedProductsChange AS RegisterRecordsReservedProductsChange
		|
		|UNION ALL
		|
		|SELECT
		|	ReservedProducts.LineNumber,
		|	ReservedProducts.Company,
		|	ReservedProducts.StructuralUnit,
		|	ReservedProducts.Products,
		|	ReservedProducts.Characteristic,
		|	ReservedProducts.Batch,
		|	ReservedProducts.SalesOrder,
		|	CASE
		|		WHEN ReservedProducts.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN ReservedProducts.Quantity
		|		ELSE -ReservedProducts.Quantity
		|	END
		|FROM
		|	AccumulationRegister.ReservedProducts AS ReservedProducts
		|WHERE
		|	ReservedProducts.Recorder = &Recorder
		|	AND &Replacing";
		
	EndIf;
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.SetParameter("Replacing", Replacing);
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
	// Temporary table
	// "RegisterRecordsReservedProductsChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsReservedProductsChange") Then
		Query = New Query("DROP RegisterRecordsReservedProductsChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsReservedProductsChange");
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR Not AdditionalProperties.Property("ForPosting")
		OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// New set change is calculated relatively current with accounting
	// accumulated changes and placed into temporary table "RegisterRecordsReservedProductsChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsReservedProductsChange.LineNumber) AS LineNumber,
	|	RegisterRecordsReservedProductsChange.Company AS Company,
	|	RegisterRecordsReservedProductsChange.StructuralUnit AS StructuralUnit,
	|	RegisterRecordsReservedProductsChange.Products AS Products,
	|	RegisterRecordsReservedProductsChange.Characteristic AS Characteristic,
	|	RegisterRecordsReservedProductsChange.Batch AS Batch,
	|	RegisterRecordsReservedProductsChange.SalesOrder AS SalesOrder,
	|	SUM(RegisterRecordsReservedProductsChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsReservedProductsChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsReservedProductsChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsReservedProductsChange
	|FROM
	|	(SELECT
	|		RegisterRecordsReservedProductsBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsReservedProductsBeforeWrite.Company AS Company,
	|		RegisterRecordsReservedProductsBeforeWrite.StructuralUnit AS StructuralUnit,
	|		RegisterRecordsReservedProductsBeforeWrite.Products AS Products,
	|		RegisterRecordsReservedProductsBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsReservedProductsBeforeWrite.Batch AS Batch,
	|		RegisterRecordsReservedProductsBeforeWrite.SalesOrder AS SalesOrder,
	|		RegisterRecordsReservedProductsBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsReservedProductsBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsReservedProductsBeforeWrite AS RegisterRecordsReservedProductsBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsReservedProductsOnWrite.LineNumber,
	|		RegisterRecordsReservedProductsOnWrite.Company,
	|		RegisterRecordsReservedProductsOnWrite.StructuralUnit,
	|		RegisterRecordsReservedProductsOnWrite.Products,
	|		RegisterRecordsReservedProductsOnWrite.Characteristic,
	|		RegisterRecordsReservedProductsOnWrite.Batch,
	|		RegisterRecordsReservedProductsOnWrite.SalesOrder,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsReservedProductsOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsReservedProductsOnWrite.Quantity
	|			ELSE RegisterRecordsReservedProductsOnWrite.Quantity
	|		END,
	|		RegisterRecordsReservedProductsOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.ReservedProducts AS RegisterRecordsReservedProductsOnWrite
	|	WHERE
	|		RegisterRecordsReservedProductsOnWrite.Recorder = &Recorder) AS RegisterRecordsReservedProductsChange
	|
	|GROUP BY
	|	RegisterRecordsReservedProductsChange.Company,
	|	RegisterRecordsReservedProductsChange.StructuralUnit,
	|	RegisterRecordsReservedProductsChange.Products,
	|	RegisterRecordsReservedProductsChange.Characteristic,
	|	RegisterRecordsReservedProductsChange.Batch,
	|	RegisterRecordsReservedProductsChange.SalesOrder
	|
	|HAVING
	|	SUM(RegisterRecordsReservedProductsChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	SalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP RegisterRecordsReservedProductsBeforeWrite");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.ExecuteBatch();
	
	QueryResultSelection = QueryResult[0].Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsReservedProductsChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsReservedProductsChange", QueryResultSelection.Count > 0);
	
EndProcedure

#EndRegion

#EndIf