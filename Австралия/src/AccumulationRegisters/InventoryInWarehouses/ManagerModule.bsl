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
	
	Query = New Query();
	
	If StructureTemporaryTables.Property("RegisterRecordsInventoryInWarehousesChange") Then
		Query.Text = "DROP RegisterRecordsInventoryInWarehousesChange";
	EndIf;
	
	DriveClientServer.AddDelimeter(Query.Text);
	
	Query.Text = Query.Text + 
	"SELECT TOP 0
	|	InventoryInWarehouses.LineNumber AS LineNumber,
	|	InventoryInWarehouses.Company AS Company,
	|	InventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|	InventoryInWarehouses.Products AS Products,
	|	InventoryInWarehouses.Characteristic AS Characteristic,
	|	InventoryInWarehouses.Batch AS Batch,
	|	InventoryInWarehouses.Ownership AS Ownership,
	|	InventoryInWarehouses.Cell AS Cell,
	|	InventoryInWarehouses.Quantity AS QuantityBeforeWrite,
	|	InventoryInWarehouses.Quantity AS QuantityChange,
	|	InventoryInWarehouses.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsInventoryInWarehousesChange
	|FROM
	|	AccumulationRegister.InventoryInWarehouses AS InventoryInWarehouses";
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsInventoryInWarehousesChange", False);
	
EndProcedure

#EndRegion

#EndIf