#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR Not AdditionalProperties.Property("ForPosting")
		OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Setting the exclusive lock of current registrar record set.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.GoodsInvoicedNotReceived.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsGoodsInvoicedNotReceivedChange")
		OR StructureTemporaryTables.Property("RegisterRecordsGoodsInvoicedNotReceivedChange")
			AND Not StructureTemporaryTables.RegisterRecordsGoodsInvoicedNotReceivedChange Then
		
		// If the temporary table "RegisterRecordsGoodsInvoicedNotReceivedChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	GoodsInvoicedNotReceived.LineNumber AS LineNumber,
		|	GoodsInvoicedNotReceived.Company AS Company,
		|	GoodsInvoicedNotReceived.PresentationCurrency AS PresentationCurrency,
		|	GoodsInvoicedNotReceived.SupplierInvoice AS SupplierInvoice,
		|	GoodsInvoicedNotReceived.Counterparty AS Counterparty,
		|	GoodsInvoicedNotReceived.Contract AS Contract,
		|	GoodsInvoicedNotReceived.PurchaseOrder AS PurchaseOrder,
		|	GoodsInvoicedNotReceived.Products AS Products,
		|	GoodsInvoicedNotReceived.Characteristic AS Characteristic,
		|	GoodsInvoicedNotReceived.Batch AS Batch,
		|	GoodsInvoicedNotReceived.VATRate AS VATRate,
		|	CASE
		|		WHEN GoodsInvoicedNotReceived.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN GoodsInvoicedNotReceived.Quantity
		|		ELSE -GoodsInvoicedNotReceived.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite
		|FROM
		|	AccumulationRegister.GoodsInvoicedNotReceived AS GoodsInvoicedNotReceived
		|WHERE
		|	GoodsInvoicedNotReceived.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsGoodsInvoicedNotReceivedChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsGoodsInvoicedNotReceivedChange.LineNumber AS LineNumber,
		|	RegisterRecordsGoodsInvoicedNotReceivedChange.Company AS Company,
		|	RegisterRecordsGoodsInvoicedNotReceivedChange.PresentationCurrency AS PresentationCurrency,
		|	RegisterRecordsGoodsInvoicedNotReceivedChange.SupplierInvoice AS SupplierInvoice,
		|	RegisterRecordsGoodsInvoicedNotReceivedChange.Counterparty AS Counterparty,
		|	RegisterRecordsGoodsInvoicedNotReceivedChange.Contract AS Contract,
		|	RegisterRecordsGoodsInvoicedNotReceivedChange.PurchaseOrder AS PurchaseOrder,
		|	RegisterRecordsGoodsInvoicedNotReceivedChange.Products AS Products,
		|	RegisterRecordsGoodsInvoicedNotReceivedChange.Characteristic AS Characteristic,
		|	RegisterRecordsGoodsInvoicedNotReceivedChange.Batch AS Batch,
		|	RegisterRecordsGoodsInvoicedNotReceivedChange.VATRate AS VATRate,
		|	RegisterRecordsGoodsInvoicedNotReceivedChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite
		|FROM
		|	RegisterRecordsGoodsInvoicedNotReceivedChange AS RegisterRecordsGoodsInvoicedNotReceivedChange
		|
		|UNION ALL
		|
		|SELECT
		|	GoodsInvoicedNotReceived.LineNumber,
		|	GoodsInvoicedNotReceived.Company,
		|	GoodsInvoicedNotReceived.PresentationCurrency,
		|	GoodsInvoicedNotReceived.SupplierInvoice,
		|	GoodsInvoicedNotReceived.Counterparty,
		|	GoodsInvoicedNotReceived.Contract,
		|	GoodsInvoicedNotReceived.PurchaseOrder,
		|	GoodsInvoicedNotReceived.Products,
		|	GoodsInvoicedNotReceived.Characteristic,
		|	GoodsInvoicedNotReceived.Batch,
		|	GoodsInvoicedNotReceived.VATRate,
		|	CASE
		|		WHEN GoodsInvoicedNotReceived.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN GoodsInvoicedNotReceived.Quantity
		|		ELSE -GoodsInvoicedNotReceived.Quantity
		|	END
		|FROM
		|	AccumulationRegister.GoodsInvoicedNotReceived AS GoodsInvoicedNotReceived
		|WHERE
		|	GoodsInvoicedNotReceived.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsGoodsInvoicedNotReceivedChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsGoodsInvoicedNotReceivedChange") Then
		
		Query = New Query("DROP RegisterRecordsGoodsInvoicedNotReceivedChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsGoodsInvoicedNotReceivedChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsGoodsInvoicedNotReceivedChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsGoodsInvoicedNotReceivedChange.LineNumber) AS LineNumber,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.Company AS Company,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.PresentationCurrency AS PresentationCurrency,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.SupplierInvoice AS SupplierInvoice,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.Counterparty AS Counterparty,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.Contract AS Contract,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.PurchaseOrder AS PurchaseOrder,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.Products AS Products,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.Characteristic AS Characteristic,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.Batch AS Batch,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.VATRate AS VATRate,
	|	SUM(RegisterRecordsGoodsInvoicedNotReceivedChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsGoodsInvoicedNotReceivedChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsGoodsInvoicedNotReceivedChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsGoodsInvoicedNotReceivedChange
	|FROM
	|	(SELECT
	|		RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite.Company AS Company,
	|		RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite.PresentationCurrency AS PresentationCurrency,
	|		RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite.SupplierInvoice AS SupplierInvoice,
	|		RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite.Counterparty AS Counterparty,
	|		RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite.Contract AS Contract,
	|		RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite.PurchaseOrder AS PurchaseOrder,
	|		RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite.Products AS Products,
	|		RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite.Batch AS Batch,
	|		RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite.VATRate AS VATRate,
	|		RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite AS RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsGoodsInvoicedNotReceivedOnWrite.LineNumber,
	|		RegisterRecordsGoodsInvoicedNotReceivedOnWrite.Company,
	|		RegisterRecordsGoodsInvoicedNotReceivedOnWrite.PresentationCurrency,
	|		RegisterRecordsGoodsInvoicedNotReceivedOnWrite.SupplierInvoice,
	|		RegisterRecordsGoodsInvoicedNotReceivedOnWrite.Counterparty,
	|		RegisterRecordsGoodsInvoicedNotReceivedOnWrite.Contract,
	|		RegisterRecordsGoodsInvoicedNotReceivedOnWrite.PurchaseOrder,
	|		RegisterRecordsGoodsInvoicedNotReceivedOnWrite.Products,
	|		RegisterRecordsGoodsInvoicedNotReceivedOnWrite.Characteristic,
	|		RegisterRecordsGoodsInvoicedNotReceivedOnWrite.Batch,
	|		RegisterRecordsGoodsInvoicedNotReceivedOnWrite.VATRate,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsGoodsInvoicedNotReceivedOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsGoodsInvoicedNotReceivedOnWrite.Quantity
	|			ELSE RegisterRecordsGoodsInvoicedNotReceivedOnWrite.Quantity
	|		END,
	|		RegisterRecordsGoodsInvoicedNotReceivedOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.GoodsInvoicedNotReceived AS RegisterRecordsGoodsInvoicedNotReceivedOnWrite
	|	WHERE
	|		RegisterRecordsGoodsInvoicedNotReceivedOnWrite.Recorder = &Recorder) AS RegisterRecordsGoodsInvoicedNotReceivedChange
	|
	|GROUP BY
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.Company,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.PresentationCurrency,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.SupplierInvoice,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.Counterparty,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.Contract,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.PurchaseOrder,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.Products,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.Characteristic,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.Batch,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.VATRate
	|
	|HAVING
	|	SUM(RegisterRecordsGoodsInvoicedNotReceivedChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	SupplierInvoice,
	|	Counterparty,
	|	Contract,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	VATRate,
	|	PurchaseOrder");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsGoodsInvoicedNotReceivedChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsGoodsInvoicedNotReceivedChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsGoodsInvoicedNotReceivedBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf