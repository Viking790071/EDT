#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Procedure creates an empty temporary table of records change.
//
Procedure CreateEmptyTemporaryTableChange(AdditionalProperties) Export
	
	If Not AdditionalProperties.Property("ForPosting")
		Or Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query(
	"SELECT TOP 0
	|	ProductionAccomplishment.RecordType AS RecordType,
	|	ProductionAccomplishment.LineNumber AS LineNumber,
	|	ProductionAccomplishment.WorkInProgress AS WorkInProgress,
	|	ProductionAccomplishment.Operation AS Operation,
	|	ProductionAccomplishment.ConnectionKey AS ConnectionKey,
	|	ProductionAccomplishment.Quantity AS QuantityBeforeWrite,
	|	ProductionAccomplishment.Quantity AS QuantityChange,
	|	ProductionAccomplishment.Quantity AS QuantityOnWrite,
	|	ProductionAccomplishment.QuantityProduced AS QuantityProducedBeforeWrite,
	|	ProductionAccomplishment.QuantityProduced AS QuantityProducedChange,
	|	ProductionAccomplishment.QuantityProduced AS QuantityProducedOnWrite
	|INTO RegisterRecordsProductionAccomplishmentChange
	|FROM
	|	AccumulationRegister.ProductionAccomplishment AS ProductionAccomplishment");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsWorkInProgressChange", False);
	
EndProcedure

#EndRegion

#EndIf