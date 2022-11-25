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
	|	WorkInProgressStatement.LineNumber AS LineNumber,
	|	WorkInProgressStatement.Company AS Company,
	|	WorkInProgressStatement.ProductionOrder AS ProductionOrder,
	|	WorkInProgressStatement.Products AS Products,
	|	WorkInProgressStatement.Characteristic AS Characteristic,
	|	WorkInProgressStatement.Specification AS Specification,
	|	WorkInProgressStatement.Quantity AS QuantityBeforeWrite,
	|	WorkInProgressStatement.Quantity AS QuantityChange,
	|	WorkInProgressStatement.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsWorkInProgressStatementChange
	|FROM
	|	AccumulationRegister.WorkInProgressStatement AS WorkInProgressStatement");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsWorkInProgressStatementChange", False);
	
EndProcedure

Function BalancesControlQueryText() Export
	
	Return
	"SELECT
	|	RegisterRecordsWorkInProgressStatementChange.LineNumber AS LineNumber,
	|	RegisterRecordsWorkInProgressStatementChange.Company AS Company,
	|	RegisterRecordsWorkInProgressStatementChange.ProductionOrder AS ProductionOrder,
	|	RegisterRecordsWorkInProgressStatementChange.Products AS Products,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	RegisterRecordsWorkInProgressStatementChange.Characteristic AS Characteristic,
	|	RegisterRecordsWorkInProgressStatementChange.Specification AS Specification,
	|	RegisterRecordsWorkInProgressStatementChange.QuantityChange + ISNULL(WorkInProgressStatementBalances.QuantityBalance, 0) AS QuantityBalanceBeforeChange,
	|	ISNULL(WorkInProgressStatementBalances.QuantityBalance, 0) AS QuantityBalance
	|FROM
	|	RegisterRecordsWorkInProgressStatementChange AS RegisterRecordsWorkInProgressStatementChange
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON RegisterRecordsWorkInProgressStatementChange.Products = CatalogProducts.Ref
	|		LEFT JOIN AccumulationRegister.WorkInProgressStatement.Balance(&ControlTime, ) AS WorkInProgressStatementBalances
	|		ON RegisterRecordsWorkInProgressStatementChange.Company = WorkInProgressStatementBalances.Company
	|			AND RegisterRecordsWorkInProgressStatementChange.ProductionOrder = WorkInProgressStatementBalances.ProductionOrder
	|			AND RegisterRecordsWorkInProgressStatementChange.Products = WorkInProgressStatementBalances.Products
	|			AND RegisterRecordsWorkInProgressStatementChange.Characteristic = WorkInProgressStatementBalances.Characteristic
	|			AND RegisterRecordsWorkInProgressStatementChange.Specification = WorkInProgressStatementBalances.Specification
	|WHERE
	|	ISNULL(WorkInProgressStatementBalances.QuantityBalance, 0) < 0
	|
	|ORDER BY
	|	LineNumber";
	
EndFunction

#EndRegion

#EndIf