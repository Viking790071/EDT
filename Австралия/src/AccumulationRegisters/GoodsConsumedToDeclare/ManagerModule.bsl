#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure creates an empty temporary table of records change.
//
Procedure CreateEmptyTemporaryTableChange(AdditionalProperties) Export
	
	If Not AdditionalProperties.Property("ForPosting")
	 OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query(
	"SELECT TOP 0
	|	GoodsConsumedToDeclare.LineNumber AS LineNumber,
	|	GoodsConsumedToDeclare.Company AS Company,
	|	GoodsConsumedToDeclare.Products AS Products,
	|	GoodsConsumedToDeclare.Characteristic AS Characteristic,
	|	GoodsConsumedToDeclare.Batch AS Batch,
	|	GoodsConsumedToDeclare.Counterparty AS Counterparty,
	|	GoodsConsumedToDeclare.Quantity AS QuantityBeforeWrite,
	|	GoodsConsumedToDeclare.Quantity AS QuantityChange,
	|	GoodsConsumedToDeclare.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsGoodsConsumedToDeclareChange
	|FROM
	|	AccumulationRegister.GoodsConsumedToDeclare AS GoodsConsumedToDeclare");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsGoodsConsumedToDeclareChange", False);
	
EndProcedure

#EndRegion

#EndIf