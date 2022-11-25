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
	LockItem = Block.Add("AccumulationRegister.CustomerOwnedInventory.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsCustomerOwnedInventoryChange")
		OR StructureTemporaryTables.Property("RegisterRecordsCustomerOwnedInventoryChange")
			AND Not StructureTemporaryTables.RegisterRecordsCustomerOwnedInventoryChange Then
		
		// If the temporary table "RegisterRecordsCustomerOwnedInventoryChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsCustomerOwnedInventoryChangeBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	CustomerOwnedInventory.LineNumber AS LineNumber,
		|	CustomerOwnedInventory.Company AS Company,
		|	CustomerOwnedInventory.Counterparty AS Counterparty,
		|	CustomerOwnedInventory.SubcontractorOrder AS SubcontractorOrder,
		|	CustomerOwnedInventory.Products AS Products,
		|	CustomerOwnedInventory.Characteristic AS Characteristic,
		|	CustomerOwnedInventory.ProductionOrder AS ProductionOrder,
		|	CASE
		|		WHEN CustomerOwnedInventory.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN CustomerOwnedInventory.QuantityToIssue
		|		ELSE -CustomerOwnedInventory.QuantityToIssue
		|	END AS QuantityToIssueBeforeWrite,
		|	CASE
		|		WHEN CustomerOwnedInventory.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN CustomerOwnedInventory.QuantityToInvoice
		|		ELSE -CustomerOwnedInventory.QuantityToInvoice
		|	END AS QuantityToInvoiceBeforeWrite
		|INTO RegisterRecordsCustomerOwnedInventoryBeforeWrite
		|FROM
		|	AccumulationRegister.CustomerOwnedInventory AS CustomerOwnedInventory
		|WHERE
		|	CustomerOwnedInventory.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsCustomerOwnedInventoryChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsCustomerOwnedInventoryBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsCustomerOwnedInventoryChange.LineNumber AS LineNumber,
		|	RegisterRecordsCustomerOwnedInventoryChange.Company AS Company,
		|	RegisterRecordsCustomerOwnedInventoryChange.Counterparty AS Counterparty,
		|	RegisterRecordsCustomerOwnedInventoryChange.SubcontractorOrder AS SubcontractorOrder,
		|	RegisterRecordsCustomerOwnedInventoryChange.Products AS Products,
		|	RegisterRecordsCustomerOwnedInventoryChange.Characteristic AS Characteristic,
		|	RegisterRecordsCustomerOwnedInventoryChange.ProductionOrder AS ProductionOrder,
		|	RegisterRecordsCustomerOwnedInventoryChange.QuantityToIssueBeforeWrite AS QuantityToIssueBeforeWrite,
		|	RegisterRecordsCustomerOwnedInventoryChange.QuantityToInvoiceBeforeWrite AS QuantityToInvoiceBeforeWrite
		|INTO RegisterRecordsCustomerOwnedInventoryBeforeWrite
		|FROM
		|	RegisterRecordsCustomerOwnedInventoryChange AS RegisterRecordsCustomerOwnedInventoryChange
		|
		|UNION ALL
		|
		|SELECT
		|	CustomerOwnedInventory.LineNumber,
		|	CustomerOwnedInventory.Company,
		|	CustomerOwnedInventory.Counterparty,
		|	CustomerOwnedInventory.SubcontractorOrder,
		|	CustomerOwnedInventory.Products,
		|	CustomerOwnedInventory.Characteristic,
		|	CustomerOwnedInventory.ProductionOrder,
		|	CASE
		|		WHEN CustomerOwnedInventory.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN CustomerOwnedInventory.QuantityToIssue
		|		ELSE -CustomerOwnedInventory.QuantityToIssue
		|	END,
		|	CASE
		|		WHEN CustomerOwnedInventory.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN CustomerOwnedInventory.QuantityToInvoice
		|		ELSE -CustomerOwnedInventory.QuantityToInvoice
		|	END
		|FROM
		|	AccumulationRegister.CustomerOwnedInventory AS CustomerOwnedInventory
		|WHERE
		|	CustomerOwnedInventory.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsCustomerOwnedInventoryChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsCustomerOwnedInventoryChange") Then
		
		Query = New Query("DROP RegisterRecordsCustomerOwnedInventoryChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsCustomerOwnedInventoryChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsCustomerOwnedInventoryChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsCustomerOwnedInventoryChange.LineNumber) AS LineNumber,
	|	RegisterRecordsCustomerOwnedInventoryChange.Company AS Company,
	|	RegisterRecordsCustomerOwnedInventoryChange.Counterparty AS Counterparty,
	|	RegisterRecordsCustomerOwnedInventoryChange.SubcontractorOrder AS SubcontractorOrder,
	|	RegisterRecordsCustomerOwnedInventoryChange.Products AS Products,
	|	RegisterRecordsCustomerOwnedInventoryChange.Characteristic AS Characteristic,
	|	RegisterRecordsCustomerOwnedInventoryChange.ProductionOrder AS ProductionOrder,
	|	SUM(RegisterRecordsCustomerOwnedInventoryChange.QuantityToIssueBeforeWrite) AS QuantityToIssueBeforeWrite,
	|	SUM(RegisterRecordsCustomerOwnedInventoryChange.QuantityToIssueChange) AS QuantityToIssueChange,
	|	SUM(RegisterRecordsCustomerOwnedInventoryChange.QuantityToIssueOnWrite) AS QuantityToIssueOnWrite,
	|	SUM(RegisterRecordsCustomerOwnedInventoryChange.QuantityToInvoiceBeforeWrite) AS QuantityToInvoiceBeforeWrite,
	|	SUM(RegisterRecordsCustomerOwnedInventoryChange.QuantityToInvoiceChange) AS QuantityToInvoiceChange,
	|	SUM(RegisterRecordsCustomerOwnedInventoryChange.QuantityToInvoiceOnWrite) AS QuantityToInvoiceOnWrite
	|INTO RegisterRecordsCustomerOwnedInventoryChange
	|FROM
	|	(SELECT
	|		RegisterRecordsCustomerOwnedInventoryBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsCustomerOwnedInventoryBeforeWrite.Company AS Company,
	|		RegisterRecordsCustomerOwnedInventoryBeforeWrite.Counterparty AS Counterparty,
	|		RegisterRecordsCustomerOwnedInventoryBeforeWrite.SubcontractorOrder AS SubcontractorOrder,
	|		RegisterRecordsCustomerOwnedInventoryBeforeWrite.Products AS Products,
	|		RegisterRecordsCustomerOwnedInventoryBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsCustomerOwnedInventoryBeforeWrite.ProductionOrder AS ProductionOrder,
	|		RegisterRecordsCustomerOwnedInventoryBeforeWrite.QuantityToIssueBeforeWrite AS QuantityToIssueBeforeWrite,
	|		RegisterRecordsCustomerOwnedInventoryBeforeWrite.QuantityToIssueBeforeWrite AS QuantityToIssueChange,
	|		0 AS QuantityToIssueOnWrite,
	|		RegisterRecordsCustomerOwnedInventoryBeforeWrite.QuantityToInvoiceBeforeWrite AS QuantityToInvoiceBeforeWrite,
	|		RegisterRecordsCustomerOwnedInventoryBeforeWrite.QuantityToInvoiceBeforeWrite AS QuantityToInvoiceChange,
	|		0 AS QuantityToInvoiceOnWrite
	|	FROM
	|		RegisterRecordsCustomerOwnedInventoryBeforeWrite AS RegisterRecordsCustomerOwnedInventoryBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsCustomerOwnedInventoryOnWrite.LineNumber,
	|		RegisterRecordsCustomerOwnedInventoryOnWrite.Company,
	|		RegisterRecordsCustomerOwnedInventoryOnWrite.Counterparty,
	|		RegisterRecordsCustomerOwnedInventoryOnWrite.SubcontractorOrder,
	|		RegisterRecordsCustomerOwnedInventoryOnWrite.Products,
	|		RegisterRecordsCustomerOwnedInventoryOnWrite.Characteristic,
	|		RegisterRecordsCustomerOwnedInventoryOnWrite.ProductionOrder,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsCustomerOwnedInventoryOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsCustomerOwnedInventoryOnWrite.QuantityToIssue
	|			ELSE RegisterRecordsCustomerOwnedInventoryOnWrite.QuantityToIssue
	|		END,
	|		RegisterRecordsCustomerOwnedInventoryOnWrite.QuantityToIssue,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsCustomerOwnedInventoryOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsCustomerOwnedInventoryOnWrite.QuantityToInvoice
	|			ELSE RegisterRecordsCustomerOwnedInventoryOnWrite.QuantityToInvoice
	|		END,
	|		RegisterRecordsCustomerOwnedInventoryOnWrite.QuantityToInvoice
	|	FROM
	|		AccumulationRegister.CustomerOwnedInventory AS RegisterRecordsCustomerOwnedInventoryOnWrite
	|	WHERE
	|		RegisterRecordsCustomerOwnedInventoryOnWrite.Recorder = &Recorder) AS RegisterRecordsCustomerOwnedInventoryChange
	|
	|GROUP BY
	|	RegisterRecordsCustomerOwnedInventoryChange.Company,
	|	RegisterRecordsCustomerOwnedInventoryChange.Counterparty,
	|	RegisterRecordsCustomerOwnedInventoryChange.SubcontractorOrder,
	|	RegisterRecordsCustomerOwnedInventoryChange.Products,
	|	RegisterRecordsCustomerOwnedInventoryChange.Characteristic,
	|	RegisterRecordsCustomerOwnedInventoryChange.ProductionOrder
	|
	|HAVING
	|	(SUM(RegisterRecordsCustomerOwnedInventoryChange.QuantityToIssueChange) <> 0
	|		OR SUM(RegisterRecordsCustomerOwnedInventoryChange.QuantityToInvoiceChange) <> 0)
	|
	|INDEX BY
	|	Company,
	|	Counterparty,
	|	SubcontractorOrder,
	|	Products,
	|	Characteristic,
	|	ProductionOrder");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsCustomerOwnedInventoryChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsCustomerOwnedInventoryChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsCustomerOwnedInventoryBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsCustomerOwnedInventoryBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf