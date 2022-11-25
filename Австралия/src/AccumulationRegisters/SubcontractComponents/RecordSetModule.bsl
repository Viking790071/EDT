#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load
		Or Not AdditionalProperties.Property("ForPosting")
		Or Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.SubcontractComponents.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsSubcontractComponentsChange")
		Or StructureTemporaryTables.Property("RegisterRecordsSubcontractComponentsChange")
		And Not StructureTemporaryTables.RegisterRecordsSubcontractComponentsChange Then
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	SubcontractComponents.LineNumber AS LineNumber,
		|	SubcontractComponents.SubcontractorOrder AS SubcontractorOrder,
		|	SubcontractComponents.Products AS Products,
		|	SubcontractComponents.Characteristic AS Characteristic,
		|	CASE
		|		WHEN SubcontractComponents.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN SubcontractComponents.Quantity
		|		ELSE -SubcontractComponents.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsSubcontractComponentsBeforeWrite
		|FROM
		|	AccumulationRegister.SubcontractComponents AS SubcontractComponents
		|WHERE
		|	SubcontractComponents.Recorder = &Recorder
		|	AND &Replacing";
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	RegisterRecordsSubcontractComponentsChange.LineNumber AS LineNumber,
		|	RegisterRecordsSubcontractComponentsChange.SubcontractorOrder AS SubcontractorOrder,
		|	RegisterRecordsSubcontractComponentsChange.Products AS Products,
		|	RegisterRecordsSubcontractComponentsChange.Characteristic AS Characteristic,
		|	RegisterRecordsSubcontractComponentsChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsSubcontractComponentsBeforeWrite
		|FROM
		|	RegisterRecordsSubcontractComponentsChange AS RegisterRecordsSubcontractComponentsChange
		|
		|UNION ALL
		|
		|SELECT
		|	SubcontractComponents.LineNumber,
		|	SubcontractComponents.SubcontractorOrder,
		|	SubcontractComponents.Products,
		|	SubcontractComponents.Characteristic,
		|	CASE
		|		WHEN SubcontractComponents.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN SubcontractComponents.Quantity
		|		ELSE -SubcontractComponents.Quantity
		|	END
		|FROM
		|	AccumulationRegister.SubcontractComponents AS SubcontractComponents
		|WHERE
		|	SubcontractComponents.Recorder = &Recorder
		|	AND &Replacing";
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	If StructureTemporaryTables.Property("RegisterRecordsSubcontractComponentsChange") Then
		
		Query = New Query("DROP RegisterRecordsSubcontractComponentsChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
		StructureTemporaryTables.Delete("RegisterRecordsSubcontractComponentsChange");
		
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load
		Or Not AdditionalProperties.Property("ForPosting")
		Or Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	MIN(RegisterRecordsSubcontractComponentsChange.LineNumber) AS LineNumber,
	|	RegisterRecordsSubcontractComponentsChange.SubcontractorOrder AS SubcontractorOrder,
	|	RegisterRecordsSubcontractComponentsChange.Products AS Products,
	|	RegisterRecordsSubcontractComponentsChange.Characteristic AS Characteristic,
	|	SUM(RegisterRecordsSubcontractComponentsChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsSubcontractComponentsChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsSubcontractComponentsChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsSubcontractComponentsChange
	|FROM
	|	(SELECT
	|		RegisterRecordsSubcontractComponentsBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsSubcontractComponentsBeforeWrite.SubcontractorOrder AS SubcontractorOrder,
	|		RegisterRecordsSubcontractComponentsBeforeWrite.Products AS Products,
	|		RegisterRecordsSubcontractComponentsBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsSubcontractComponentsBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsSubcontractComponentsBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsSubcontractComponentsBeforeWrite AS RegisterRecordsSubcontractComponentsBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsSubcontractComponentsOnWrite.LineNumber,
	|		RegisterRecordsSubcontractComponentsOnWrite.SubcontractorOrder,
	|		RegisterRecordsSubcontractComponentsOnWrite.Products,
	|		RegisterRecordsSubcontractComponentsOnWrite.Characteristic,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsSubcontractComponentsOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsSubcontractComponentsOnWrite.Quantity
	|			ELSE RegisterRecordsSubcontractComponentsOnWrite.Quantity
	|		END,
	|		RegisterRecordsSubcontractComponentsOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.SubcontractComponents AS RegisterRecordsSubcontractComponentsOnWrite
	|	WHERE
	|		RegisterRecordsSubcontractComponentsOnWrite.Recorder = &Recorder) AS RegisterRecordsSubcontractComponentsChange
	|
	|GROUP BY
	|	RegisterRecordsSubcontractComponentsChange.SubcontractorOrder,
	|	RegisterRecordsSubcontractComponentsChange.Products,
	|	RegisterRecordsSubcontractComponentsChange.Characteristic
	|
	|HAVING
	|	SUM(RegisterRecordsSubcontractComponentsChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Products,
	|	Characteristic,
	|	SubcontractorOrder";
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	StructureTemporaryTables.Insert("RegisterRecordsSubcontractComponentsChange", QueryResultSelection.Count > 0);
	
	Query = New Query("DROP RegisterRecordsSubcontractComponentsBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf