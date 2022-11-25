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
	|	KitOrders.LineNumber AS LineNumber,
	|	KitOrders.Company AS Company,
	|	KitOrders.KitOrder AS KitOrder,
	|	KitOrders.Products AS Products,
	|	KitOrders.Characteristic AS Characteristic,
	|	KitOrders.Quantity AS QuantityBeforeWrite,
	|	KitOrders.Quantity AS QuantityChange,
	|	KitOrders.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsKitOrdersChange
	|FROM
	|	AccumulationRegister.KitOrders AS KitOrders");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsKitOrdersChange", False);
	
EndProcedure

#EndRegion

#EndIf