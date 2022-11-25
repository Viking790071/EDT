#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

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
	LockItem = Block.Add("AccumulationRegister.Inventory.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	Query = New Query();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsInventoryChange")
		OR (StructureTemporaryTables.Property("RegisterRecordsInventoryChange")
			AND Not StructureTemporaryTables.RegisterRecordsInventoryChange) Then
		
		// If the temporary table "RegisterRecordsInventoryChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsInventoryBeforeWrite" to get at record new set change rather current.
		
		Query.Text = 
		"SELECT
		|	Inventory.LineNumber AS LineNumber,
		|	Inventory.Company AS Company,
		|	Inventory.PresentationCurrency AS PresentationCurrency,
		|	Inventory.StructuralUnit AS StructuralUnit,
		|	Inventory.CostObject AS CostObject,
		|	Inventory.GLAccount AS GLAccount,
		|	Inventory.InventoryAccountType AS InventoryAccountType,
		|	Inventory.Products AS Products,
		|	Inventory.Characteristic AS Characteristic,
		|	Inventory.Batch AS Batch,
		|	Inventory.Ownership AS Ownership,
		|	CASE
		|		WHEN Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN Inventory.Quantity
		|		ELSE -Inventory.Quantity
		|	END AS QuantityBeforeWrite,
		|	CASE
		|		WHEN Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN Inventory.Amount
		|		ELSE -Inventory.Amount
		|	END AS SumBeforeWrite
		|INTO RegisterRecordsInventoryBeforeWrite
		|FROM
		|	AccumulationRegister.Inventory AS Inventory
		|WHERE
		|	Inventory.Recorder = &Recorder
		|	AND &Replacing";
		
	Else
		
		// If the temporary table "RegisterRecordsInventoryChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsInventoryBeforeWrite" to get at record new set change rather initial.
		
		Query.Text = 
		"SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryChange.Company AS Company,
		|	RegisterRecordsInventoryChange.PresentationCurrency AS PresentationCurrency,
		|	RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnit,
		|	RegisterRecordsInventoryChange.CostObject AS CostObject,
		|	RegisterRecordsInventoryChange.GLAccount AS GLAccount,
		|	RegisterRecordsInventoryChange.InventoryAccountType AS InventoryAccountType,
		|	RegisterRecordsInventoryChange.Products AS Products,
		|	RegisterRecordsInventoryChange.Characteristic AS Characteristic,
		|	RegisterRecordsInventoryChange.Batch AS Batch,
		|	RegisterRecordsInventoryChange.Ownership AS Ownership,
		|	RegisterRecordsInventoryChange.QuantityBeforeWrite AS QuantityBeforeWrite,
		|	RegisterRecordsInventoryChange.SumBeforeWrite AS SumBeforeWrite
		|INTO RegisterRecordsInventoryBeforeWrite
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|
		|UNION ALL
		|
		|SELECT
		|	Inventory.LineNumber,
		|	Inventory.Company,
		|	Inventory.PresentationCurrency,
		|	Inventory.StructuralUnit,
		|	Inventory.CostObject,
		|	Inventory.GLAccount,
		|	Inventory.InventoryAccountType,
		|	Inventory.Products,
		|	Inventory.Characteristic,
		|	Inventory.Batch,
		|	Inventory.Ownership,
		|	CASE
		|		WHEN Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN Inventory.Quantity
		|		ELSE -Inventory.Quantity
		|	END,
		|	CASE
		|		WHEN Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN Inventory.Amount
		|		ELSE -Inventory.Amount
		|	END
		|FROM
		|	AccumulationRegister.Inventory AS Inventory
		|WHERE
		|	Inventory.Recorder = &Recorder
		|	AND &Replacing";
		
	EndIf;
	
	DriveClientServer.AddDelimeter(Query.Text);
	
	If Not StructureTemporaryTables.Property("RegisterRecordsInventoryWithSourceDocumentChange")
		Or (StructureTemporaryTables.Property("RegisterRecordsInventoryWithSourceDocumentChange")
		And Not StructureTemporaryTables.RegisterRecordsInventoryWithSourceDocumentChange) Then
		
		Query.Text = Query.Text +
		"SELECT
		|	Inventory.LineNumber AS LineNumber,
		|	Inventory.Company AS Company,
		|	Inventory.PresentationCurrency AS PresentationCurrency,
		|	Inventory.StructuralUnit AS StructuralUnit,
		|	Inventory.CostObject AS CostObject,
		|	Inventory.GLAccount AS GLAccount,
		|	Inventory.Products AS Products,
		|	Inventory.Characteristic AS Characteristic,
		|	Inventory.Batch AS Batch,
		|	Inventory.Ownership AS Ownership,
		|	Inventory.SourceDocument AS SourceDocument,
		|	CASE
		|		WHEN Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN Inventory.Quantity
		|		ELSE -Inventory.Quantity
		|	END AS QuantityBeforeWrite,
		|	CASE
		|		WHEN Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN Inventory.Amount
		|		ELSE -Inventory.Amount
		|	END AS SumBeforeWrite
		|INTO RegisterRecordsInventoryWithSourceDocumentBeforeWrite
		|FROM
		|	AccumulationRegister.Inventory AS Inventory
		|WHERE
		|	Inventory.Recorder = &Recorder
		|	AND &Replacing";

	Else
		
		Query.Text = Query.Text +
		"SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryChange.Company AS Company,
		|	RegisterRecordsInventoryChange.PresentationCurrency AS PresentationCurrency,
		|	RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnit,
		|	RegisterRecordsInventoryChange.CostObject AS CostObject,
		|	RegisterRecordsInventoryChange.GLAccount AS GLAccount,
		|	RegisterRecordsInventoryChange.Products AS Products,
		|	RegisterRecordsInventoryChange.Characteristic AS Characteristic,
		|	RegisterRecordsInventoryChange.Batch AS Batch,
		|	RegisterRecordsInventoryChange.Ownership AS Ownership,
		|	RegisterRecordsInventoryChange.SourceDocument AS SourceDocument,
		|	RegisterRecordsInventoryChange.QuantityBeforeWrite AS QuantityBeforeWrite,
		|	RegisterRecordsInventoryChange.SumBeforeWrite AS SumBeforeWrite
		|INTO RegisterRecordsInventoryWithSourceDocumentBeforeWrite
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|
		|UNION ALL
		|
		|SELECT
		|	Inventory.LineNumber,
		|	Inventory.Company,
		|	Inventory.PresentationCurrency,
		|	Inventory.StructuralUnit,
		|	Inventory.CostObject,
		|	Inventory.GLAccount,
		|	Inventory.Products,
		|	Inventory.Characteristic,
		|	Inventory.Batch,
		|	Inventory.Ownership,
		|	Inventory.SourceDocument,
		|	CASE
		|		WHEN Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN Inventory.Quantity
		|		ELSE -Inventory.Quantity
		|	END,
		|	CASE
		|		WHEN Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN Inventory.Amount
		|		ELSE -Inventory.Amount
		|	END
		|FROM
		|	AccumulationRegister.Inventory AS Inventory
		|WHERE
		|	Inventory.Recorder = &Recorder
		|	AND &Replacing";
		
	EndIf;
		
	DriveClientServer.AddDelimeter(Query.Text);
	
	Query.Text = Query.Text +
	"SELECT
	|	Inventory.Period AS Period,
	|	Inventory.Recorder AS Recorder,
	|	Inventory.RecordType AS RecordType,
	|	Inventory.Company AS Company,
	|	Inventory.PresentationCurrency AS PresentationCurrency,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.InventoryAccountType AS InventoryAccountType,
	|	Inventory.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	Inventory.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	Inventory.CorrGLAccount AS CorrGLAccount,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.Ownership AS Ownership,
	|	Inventory.Quantity AS Quantity,
	|	Inventory.Amount AS Amount
	|INTO InventoryBeforeWrite
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Recorder = &Recorder
	|	AND &FIFOIsUsed";
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.SetParameter("Replacing", Replacing);
	Query.SetParameter("FIFOIsUsed", Constants.UseFIFO.Get());
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
	// Temporary table
	// "RegisterRecordsInventoryChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsInventoryChange") Then
		Query = New Query("DROP RegisterRecordsInventoryChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsInventoryChange");
	EndIf;
	
	If StructureTemporaryTables.Property("RegisterRecordsInventoryWithSourceDocumentChange") Then
		Query = New Query("DROP RegisterRecordsInventoryWithSourceDocumentChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsInventoryWithSourceDocumentChange");
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
	// accumulated changes and placed into temporary table "RegisterRecordsInventoryChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsInventoryChange.LineNumber) AS LineNumber,
	|	RegisterRecordsInventoryChange.Company AS Company,
	|	RegisterRecordsInventoryChange.PresentationCurrency AS PresentationCurrency,
	|	RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnit,
	|	RegisterRecordsInventoryChange.CostObject AS CostObject,
	|	RegisterRecordsInventoryChange.GLAccount AS GLAccount,
	|	RegisterRecordsInventoryChange.InventoryAccountType AS InventoryAccountType,
	|	RegisterRecordsInventoryChange.Products AS Products,
	|	RegisterRecordsInventoryChange.Characteristic AS Characteristic,
	|	RegisterRecordsInventoryChange.Batch AS Batch,
	|	RegisterRecordsInventoryChange.Ownership AS Ownership,
	|	SUM(RegisterRecordsInventoryChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsInventoryChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsInventoryChange.QuantityOnWrite) AS QuantityOnWrite,
	|	SUM(RegisterRecordsInventoryChange.SumBeforeWrite) AS SumBeforeWrite,
	|	SUM(RegisterRecordsInventoryChange.AmountChange) AS AmountChange,
	|	SUM(RegisterRecordsInventoryChange.AmountOnWrite) AS AmountOnWrite
	|INTO RegisterRecordsInventoryChange
	|FROM
	|	(SELECT
	|		RegisterRecordsInventoryBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsInventoryBeforeWrite.Company AS Company,
	|		RegisterRecordsInventoryBeforeWrite.PresentationCurrency AS PresentationCurrency,
	|		RegisterRecordsInventoryBeforeWrite.StructuralUnit AS StructuralUnit,
	|		RegisterRecordsInventoryBeforeWrite.CostObject AS CostObject,
	|		RegisterRecordsInventoryBeforeWrite.GLAccount AS GLAccount,
	|		RegisterRecordsInventoryBeforeWrite.InventoryAccountType AS InventoryAccountType,
	|		RegisterRecordsInventoryBeforeWrite.Products AS Products,
	|		RegisterRecordsInventoryBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsInventoryBeforeWrite.Batch AS Batch,
	|		RegisterRecordsInventoryBeforeWrite.Ownership AS Ownership,
	|		RegisterRecordsInventoryBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsInventoryBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite,
	|		RegisterRecordsInventoryBeforeWrite.SumBeforeWrite AS SumBeforeWrite,
	|		RegisterRecordsInventoryBeforeWrite.SumBeforeWrite AS AmountChange,
	|		0 AS AmountOnWrite
	|	FROM
	|		RegisterRecordsInventoryBeforeWrite AS RegisterRecordsInventoryBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsInventoryOnWrite.LineNumber,
	|		RegisterRecordsInventoryOnWrite.Company,
	|		RegisterRecordsInventoryOnWrite.PresentationCurrency,
	|		RegisterRecordsInventoryOnWrite.StructuralUnit,
	|		RegisterRecordsInventoryOnWrite.CostObject,
	|		RegisterRecordsInventoryOnWrite.GLAccount,
	|		RegisterRecordsInventoryOnWrite.InventoryAccountType,
	|		RegisterRecordsInventoryOnWrite.Products,
	|		RegisterRecordsInventoryOnWrite.Characteristic,
	|		RegisterRecordsInventoryOnWrite.Batch,
	|		RegisterRecordsInventoryOnWrite.Ownership,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsInventoryOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsInventoryOnWrite.Quantity
	|			ELSE RegisterRecordsInventoryOnWrite.Quantity
	|		END,
	|		RegisterRecordsInventoryOnWrite.Quantity,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsInventoryOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsInventoryOnWrite.Amount
	|			ELSE RegisterRecordsInventoryOnWrite.Amount
	|		END,
	|		RegisterRecordsInventoryOnWrite.Amount
	|	FROM
	|		AccumulationRegister.Inventory AS RegisterRecordsInventoryOnWrite
	|	WHERE
	|		RegisterRecordsInventoryOnWrite.Recorder = &Recorder) AS RegisterRecordsInventoryChange
	|
	|GROUP BY
	|	RegisterRecordsInventoryChange.Company,
	|	RegisterRecordsInventoryChange.PresentationCurrency,
	|	RegisterRecordsInventoryChange.StructuralUnit,
	|	RegisterRecordsInventoryChange.CostObject,
	|	RegisterRecordsInventoryChange.GLAccount,
	|	RegisterRecordsInventoryChange.InventoryAccountType,
	|	RegisterRecordsInventoryChange.Products,
	|	RegisterRecordsInventoryChange.Characteristic,
	|	RegisterRecordsInventoryChange.Batch,
	|	RegisterRecordsInventoryChange.Ownership
	|
	|HAVING
	|	(SUM(RegisterRecordsInventoryChange.QuantityChange) <> 0
	|		OR SUM(RegisterRecordsInventoryChange.AmountChange) <> 0)
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	StructuralUnit,
	|	CostObject,
	|	GLAccount,
	|	InventoryAccountType,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	Ownership
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	BEGINOFPERIOD(Table.Period, MONTH) AS Month,
	|	Table.Company AS Company,
	|	Table.Recorder AS Document
	|INTO InventoryTasks
	|FROM
	|	(SELECT
	|		BeforeWrite.Period AS Period,
	|		BeforeWrite.Recorder AS Recorder,
	|		BeforeWrite.RecordType AS RecordType,
	|		BeforeWrite.Company AS Company,
	|		BeforeWrite.PresentationCurrency AS PresentationCurrency,
	|		BeforeWrite.StructuralUnit AS StructuralUnit,
	|		BeforeWrite.GLAccount AS GLAccount,
	|		BeforeWrite.InventoryAccountType AS InventoryAccountType,
	|		BeforeWrite.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|		BeforeWrite.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|		BeforeWrite.CorrGLAccount AS CorrGLAccount,
	|		BeforeWrite.Products AS Products,
	|		BeforeWrite.Characteristic AS Characteristic,
	|		BeforeWrite.Batch AS Batch,
	|		BeforeWrite.Ownership AS Ownership,
	|		BeforeWrite.Quantity AS Quantity,
	|		BeforeWrite.Amount AS Amount
	|	FROM
	|		InventoryBeforeWrite AS BeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AfterWrite.Period,
	|		AfterWrite.Recorder,
	|		AfterWrite.RecordType,
	|		AfterWrite.Company,
	|		AfterWrite.PresentationCurrency,
	|		AfterWrite.StructuralUnit,
	|		AfterWrite.GLAccount,
	|		AfterWrite.InventoryAccountType,
	|		AfterWrite.IncomeAndExpenseItem,
	|		AfterWrite.CorrIncomeAndExpenseItem,
	|		AfterWrite.CorrGLAccount,
	|		AfterWrite.Products,
	|		AfterWrite.Characteristic,
	|		AfterWrite.Batch,
	|		AfterWrite.Ownership,
	|		-AfterWrite.Quantity,
	|		-AfterWrite.Amount
	|	FROM
	|		AccumulationRegister.Inventory AS AfterWrite
	|	WHERE
	|		AfterWrite.Recorder = &Recorder
	|		AND &FIFOIsUsed) AS Table
	|
	|GROUP BY
	|	BEGINOFPERIOD(Table.Period, MONTH),
	|	Table.Recorder,
	|	Table.Period,
	|	Table.RecordType,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.StructuralUnit,
	|	Table.GLAccount,
	|	Table.InventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem,
	|	Table.CorrGLAccount,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.Batch,
	|	Table.Ownership
	|
	|HAVING
	|	(SUM(Table.Quantity) <> 0
	|		OR SUM(Table.Amount) <> 0)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RegisterRecordsInventoryChange.Company AS Company,
	|	RegisterRecordsInventoryChange.PresentationCurrency AS PresentationCurrency,
	|	RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnit,
	|	RegisterRecordsInventoryChange.GLAccount AS GLAccount,
	|	RegisterRecordsInventoryChange.Products AS Products,
	|	RegisterRecordsInventoryChange.Characteristic AS Characteristic,
	|	RegisterRecordsInventoryChange.Batch AS Batch,
	|	RegisterRecordsInventoryChange.Ownership AS Ownership,
	|	RegisterRecordsInventoryChange.SourceDocument AS SourceDocument,
	|	SUM(RegisterRecordsInventoryChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsInventoryChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsInventoryChange.QuantityOnWrite) AS QuantityOnWrite,
	|	SUM(RegisterRecordsInventoryChange.SumBeforeWrite) AS SumBeforeWrite,
	|	SUM(RegisterRecordsInventoryChange.AmountChange) AS AmountChange,
	|	SUM(RegisterRecordsInventoryChange.AmountOnWrite) AS AmountOnWrite
	|INTO RegisterRecordsInventoryWithSourceDocumentChange
	|FROM
	|	(SELECT
	|		RegisterRecordsInventoryBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsInventoryBeforeWrite.Company AS Company,
	|		RegisterRecordsInventoryBeforeWrite.PresentationCurrency AS PresentationCurrency,
	|		RegisterRecordsInventoryBeforeWrite.StructuralUnit AS StructuralUnit,
	|		RegisterRecordsInventoryBeforeWrite.GLAccount AS GLAccount,
	|		RegisterRecordsInventoryBeforeWrite.Products AS Products,
	|		RegisterRecordsInventoryBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsInventoryBeforeWrite.Batch AS Batch,
	|		RegisterRecordsInventoryBeforeWrite.Ownership AS Ownership,
	|		RegisterRecordsInventoryBeforeWrite.SourceDocument AS SourceDocument,
	|		RegisterRecordsInventoryBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsInventoryBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite,
	|		RegisterRecordsInventoryBeforeWrite.SumBeforeWrite AS SumBeforeWrite,
	|		RegisterRecordsInventoryBeforeWrite.SumBeforeWrite AS AmountChange,
	|		0 AS AmountOnWrite
	|	FROM
	|		RegisterRecordsInventoryWithSourceDocumentBeforeWrite AS RegisterRecordsInventoryBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsInventoryOnWrite.LineNumber,
	|		RegisterRecordsInventoryOnWrite.Company,
	|		RegisterRecordsInventoryOnWrite.PresentationCurrency,
	|		RegisterRecordsInventoryOnWrite.StructuralUnit,
	|		RegisterRecordsInventoryOnWrite.GLAccount,
	|		RegisterRecordsInventoryOnWrite.Products,
	|		RegisterRecordsInventoryOnWrite.Characteristic,
	|		RegisterRecordsInventoryOnWrite.Batch,
	|		RegisterRecordsInventoryOnWrite.Ownership,
	|		RegisterRecordsInventoryOnWrite.SourceDocument,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsInventoryOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsInventoryOnWrite.Quantity
	|			ELSE RegisterRecordsInventoryOnWrite.Quantity
	|		END,
	|		RegisterRecordsInventoryOnWrite.Quantity,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsInventoryOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsInventoryOnWrite.Amount
	|			ELSE RegisterRecordsInventoryOnWrite.Amount
	|		END,
	|		RegisterRecordsInventoryOnWrite.Amount
	|	FROM
	|		AccumulationRegister.Inventory AS RegisterRecordsInventoryOnWrite
	|	WHERE
	|		RegisterRecordsInventoryOnWrite.Recorder = &Recorder) AS RegisterRecordsInventoryChange
	|
	|GROUP BY
	|	RegisterRecordsInventoryChange.Company,
	|	RegisterRecordsInventoryChange.PresentationCurrency,
	|	RegisterRecordsInventoryChange.StructuralUnit,
	|	RegisterRecordsInventoryChange.GLAccount,
	|	RegisterRecordsInventoryChange.Products,
	|	RegisterRecordsInventoryChange.Characteristic,
	|	RegisterRecordsInventoryChange.Batch,
	|	RegisterRecordsInventoryChange.Ownership,
	|	RegisterRecordsInventoryChange.SourceDocument
	|
	|HAVING
	|	(SUM(RegisterRecordsInventoryChange.QuantityChange) <> 0
	|		OR SUM(RegisterRecordsInventoryChange.AmountChange) <> 0)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP RegisterRecordsInventoryWithSourceDocumentBeforeWrite
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP InventoryBeforeWrite
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP RegisterRecordsInventoryBeforeWrite");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.SetParameter("FIFOIsUsed", Constants.UseFIFO.Get());
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.ExecuteBatch();
	
	QueryResultSelection = QueryResult[0].Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsInventoryChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsInventoryChange", QueryResultSelection.Count > 0);
	
	QueryResultSelection = QueryResult[2].Select();
	QueryResultSelection.Next();
	
	StructureTemporaryTables.Insert("RegisterRecordsInventoryWithSourceDocumentChange", QueryResultSelection.Count > 0);
	
EndProcedure

#EndRegion

#EndIf