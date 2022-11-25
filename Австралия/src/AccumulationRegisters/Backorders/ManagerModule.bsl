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
	|	Backorders.LineNumber AS LineNumber,
	|	Backorders.Company AS Company,
	|	Backorders.SalesOrder AS SalesOrder,
	|	Backorders.Products AS Products,
	|	Backorders.Characteristic AS Characteristic,
	|	Backorders.SupplySource AS SupplySource,
	|	Backorders.Quantity AS QuantityBeforeWrite,
	|	Backorders.Quantity AS QuantityChange,
	|	Backorders.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsBackordersChange
	|FROM
	|	AccumulationRegister.Backorders AS Backorders");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsBackordersChange", False);
	
EndProcedure

Function BalancesControlQueryText() Export

	Return 
	"SELECT
	|	RegisterRecordsBackordersChange.LineNumber AS LineNumber,
	|	REFPRESENTATION(RegisterRecordsBackordersChange.Company) AS CompanyPresentation,
	|	REFPRESENTATION(RegisterRecordsBackordersChange.SalesOrder) AS SalesOrderPresentation,
	|	REFPRESENTATION(RegisterRecordsBackordersChange.Products) AS ProductsPresentation,
	|	REFPRESENTATION(RegisterRecordsBackordersChange.Characteristic) AS CharacteristicPresentation,
	|	REFPRESENTATION(RegisterRecordsBackordersChange.SupplySource) AS SupplySourcePresentation,
	|	REFPRESENTATION(BackordersBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
	|	ISNULL(RegisterRecordsBackordersChange.QuantityChange, 0) + ISNULL(BackordersBalances.QuantityBalance, 0) AS BalanceBackorders,
	|	ISNULL(BackordersBalances.QuantityBalance, 0) AS QuantityBalanceBackorders
	|FROM
	|	RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange
	|		LEFT JOIN AccumulationRegister.Backorders.Balance(
	|				&ControlTime,
	|				(Company, SalesOrder, Products, Characteristic, SupplySource) In
	|					(SELECT
	|						RegisterRecordsBackordersChange.Company AS Company,
	|						RegisterRecordsBackordersChange.SalesOrder AS SalesOrder,
	|						RegisterRecordsBackordersChange.Products AS Products,
	|						RegisterRecordsBackordersChange.Characteristic AS Characteristic,
	|						RegisterRecordsBackordersChange.SupplySource AS SupplySource
	|					FROM
	|						RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange)) AS BackordersBalances
	|		ON RegisterRecordsBackordersChange.Company = BackordersBalances.Company
	|			AND RegisterRecordsBackordersChange.SalesOrder = BackordersBalances.SalesOrder
	|			AND RegisterRecordsBackordersChange.Products = BackordersBalances.Products
	|			AND RegisterRecordsBackordersChange.Characteristic = BackordersBalances.Characteristic
	|			AND RegisterRecordsBackordersChange.SupplySource = BackordersBalances.SupplySource
	|WHERE
	|	ISNULL(BackordersBalances.QuantityBalance, 0) < 0
	|
	|ORDER BY
	|	LineNumber";

EndFunction

#EndRegion

#EndIf