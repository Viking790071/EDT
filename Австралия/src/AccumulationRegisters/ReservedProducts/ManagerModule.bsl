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
	|	ReservedProducts.LineNumber AS LineNumber,
	|	ReservedProducts.Company AS Company,
	|	ReservedProducts.StructuralUnit AS StructuralUnit,
	|	ReservedProducts.Products AS Products,
	|	ReservedProducts.Characteristic AS Characteristic,
	|	ReservedProducts.Batch AS Batch,
	|	ReservedProducts.SalesOrder AS SalesOrder,
	|	ReservedProducts.Quantity AS QuantityBeforeWrite,
	|	ReservedProducts.Quantity AS QuantityChange,
	|	ReservedProducts.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsReservedProductsChange
	|FROM
	|	AccumulationRegister.ReservedProducts AS ReservedProducts");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsReservedProductsChange", False);
	
EndProcedure

Function BalancesControlQueryText() Export
	
	Return
	"SELECT ALLOWED
	|	RegisterRecordsReservedProductsChange.LineNumber AS LineNumber,
	|	RegisterRecordsReservedProductsChange.Company AS CompanyPresentation,
	|	RegisterRecordsReservedProductsChange.StructuralUnit AS StructuralUnitPresentation,
	|	RegisterRecordsReservedProductsChange.Products AS ProductsPresentation,
	|	RegisterRecordsReservedProductsChange.Characteristic AS CharacteristicPresentation,
	|	RegisterRecordsReservedProductsChange.Batch AS BatchPresentation,
	|	RegisterRecordsReservedProductsChange.SalesOrder AS SalesOrderPresentation,
	|	RegisterRecordsReservedProductsChange.StructuralUnit.StructuralUnitType AS StructuralUnitType,
	|	RegisterRecordsReservedProductsChange.Products.MeasurementUnit AS MeasurementUnitPresentation,
	|	ISNULL(RegisterRecordsReservedProductsChange.QuantityChange, 0) + ISNULL(ReservedProductsBalances.QuantityBalance, 0) AS BalanceInventory,
	|	ISNULL(ReservedProductsBalances.QuantityBalance, 0) AS QuantityBalanceInventory
	|FROM
	|	RegisterRecordsReservedProductsChange AS RegisterRecordsReservedProductsChange
	|		INNER JOIN AccumulationRegister.ReservedProducts.Balance(&ControlTime, ) AS ReservedProductsBalances
	|		ON RegisterRecordsReservedProductsChange.Company = ReservedProductsBalances.Company
	|			AND RegisterRecordsReservedProductsChange.StructuralUnit = ReservedProductsBalances.StructuralUnit
	|			AND RegisterRecordsReservedProductsChange.Products = ReservedProductsBalances.Products
	|			AND RegisterRecordsReservedProductsChange.Characteristic = ReservedProductsBalances.Characteristic
	|			AND RegisterRecordsReservedProductsChange.Batch = ReservedProductsBalances.Batch
	|			AND RegisterRecordsReservedProductsChange.SalesOrder = ReservedProductsBalances.SalesOrder
	|			AND (ISNULL(ReservedProductsBalances.QuantityBalance, 0) < 0)
	|
	|ORDER BY
	|	LineNumber";
	
EndFunction

#EndRegion

#EndIf