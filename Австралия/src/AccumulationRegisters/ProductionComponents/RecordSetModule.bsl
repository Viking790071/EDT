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
	LockItem = Block.Add("AccumulationRegister.ProductionComponents.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsProductionComponentsChange")
		Or StructureTemporaryTables.Property("RegisterRecordsProductionComponentsChange")
		And Not StructureTemporaryTables.RegisterRecordsProductionComponentsChange Then
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	ProductionComponents.LineNumber AS LineNumber,
		|	ProductionComponents.ProductionDocument AS ProductionDocument,
		|	ProductionComponents.Products AS Products,
		|	ProductionComponents.Characteristic AS Characteristic,
		|	CASE
		|		WHEN ProductionComponents.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN ProductionComponents.Quantity
		|		ELSE -ProductionComponents.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsProductionComponentsBeforeWrite
		|FROM
		|	AccumulationRegister.ProductionComponents AS ProductionComponents
		|WHERE
		|	ProductionComponents.Recorder = &Recorder
		|	AND &Replacing";
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	RegisterRecordsProductionComponentsChange.LineNumber AS LineNumber,
		|	RegisterRecordsProductionComponentsChange.ProductionDocument AS ProductionDocument,
		|	RegisterRecordsProductionComponentsChange.Products AS Products,
		|	RegisterRecordsProductionComponentsChange.Characteristic AS Characteristic,
		|	RegisterRecordsProductionComponentsChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsProductionComponentsBeforeWrite
		|FROM
		|	RegisterRecordsProductionComponentsChange AS RegisterRecordsProductionComponentsChange
		|
		|UNION ALL
		|
		|SELECT
		|	ProductionComponents.LineNumber,
		|	ProductionComponents.ProductionDocument,
		|	ProductionComponents.Products,
		|	ProductionComponents.Characteristic,
		|	CASE
		|		WHEN ProductionComponents.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN ProductionComponents.Quantity
		|		ELSE -ProductionComponents.Quantity
		|	END
		|FROM
		|	AccumulationRegister.ProductionComponents AS ProductionComponents
		|WHERE
		|	ProductionComponents.Recorder = &Recorder
		|	AND &Replacing";
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	If StructureTemporaryTables.Property("RegisterRecordsProductionComponentsChange") Then
		
		Query = New Query("DROP RegisterRecordsProductionComponentsChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
		StructureTemporaryTables.Delete("RegisterRecordsProductionComponentsChange");
		
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
	|	MIN(RegisterRecordsProductionComponentsChange.LineNumber) AS LineNumber,
	|	RegisterRecordsProductionComponentsChange.ProductionDocument AS ProductionDocument,
	|	RegisterRecordsProductionComponentsChange.Products AS Products,
	|	RegisterRecordsProductionComponentsChange.Characteristic AS Characteristic,
	|	SUM(RegisterRecordsProductionComponentsChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsProductionComponentsChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsProductionComponentsChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsProductionComponentsChange
	|FROM
	|	(SELECT
	|		RegisterRecordsProductionComponentsBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsProductionComponentsBeforeWrite.ProductionDocument AS ProductionDocument,
	|		RegisterRecordsProductionComponentsBeforeWrite.Products AS Products,
	|		RegisterRecordsProductionComponentsBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsProductionComponentsBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsProductionComponentsBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsProductionComponentsBeforeWrite AS RegisterRecordsProductionComponentsBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsProductionComponentsOnWrite.LineNumber,
	|		RegisterRecordsProductionComponentsOnWrite.ProductionDocument,
	|		RegisterRecordsProductionComponentsOnWrite.Products,
	|		RegisterRecordsProductionComponentsOnWrite.Characteristic,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsProductionComponentsOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsProductionComponentsOnWrite.Quantity
	|			ELSE RegisterRecordsProductionComponentsOnWrite.Quantity
	|		END,
	|		RegisterRecordsProductionComponentsOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.ProductionComponents AS RegisterRecordsProductionComponentsOnWrite
	|	WHERE
	|		RegisterRecordsProductionComponentsOnWrite.Recorder = &Recorder) AS RegisterRecordsProductionComponentsChange
	|
	|GROUP BY
	|	RegisterRecordsProductionComponentsChange.ProductionDocument,
	|	RegisterRecordsProductionComponentsChange.Products,
	|	RegisterRecordsProductionComponentsChange.Characteristic
	|
	|HAVING
	|	SUM(RegisterRecordsProductionComponentsChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Products,
	|	Characteristic,
	|	ProductionDocument";
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	StructureTemporaryTables.Insert("RegisterRecordsProductionComponentsChange", QueryResultSelection.Count > 0);
	
	Query = New Query("DROP RegisterRecordsProductionComponentsBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf