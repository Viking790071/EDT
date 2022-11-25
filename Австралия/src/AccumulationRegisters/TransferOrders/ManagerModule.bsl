#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public 

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
	|	TransferOrders.LineNumber AS LineNumber,
	|	TransferOrders.Company AS Company,
	|	TransferOrders.TransferOrder AS TransferOrder,
	|	TransferOrders.Products AS Products,
	|	TransferOrders.Characteristic AS Characteristic,
	|	TransferOrders.Quantity AS QuantityBeforeWrite,
	|	TransferOrders.Quantity AS QuantityChange,
	|	TransferOrders.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsTransferOrdersChange
	|FROM
	|	AccumulationRegister.TransferOrders AS TransferOrders");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsTransferOrdersChange", False);
	
EndProcedure

#EndRegion

#EndIf