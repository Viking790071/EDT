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
	|	ManufacturingProcessSupply.LineNumber AS LineNumber,
	|	ManufacturingProcessSupply.Reference AS Reference,
	|	ManufacturingProcessSupply.Products AS Products,
	|	ManufacturingProcessSupply.Characteristic AS Characteristic,
	|	ManufacturingProcessSupply.Specification AS Specification,
	|	ManufacturingProcessSupply.Required AS Required,
	|	ManufacturingProcessSupply.TransferredToProduction AS TransferredToProduction,
	|	ManufacturingProcessSupply.Scheduled AS Scheduled,
	|	ManufacturingProcessSupply.Produced AS Produced
	|INTO RegisterManufacturingProcessSupplyChange
	|FROM
	|	AccumulationRegister.ManufacturingProcessSupply AS ManufacturingProcessSupply");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsManufacturingProcessSupplyChange", False);
	
EndProcedure

#EndRegion

#EndIf