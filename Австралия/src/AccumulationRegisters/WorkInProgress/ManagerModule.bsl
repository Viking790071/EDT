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
	|	WorkInProgress.LineNumber AS LineNumber,
	|	WorkInProgress.Company AS Company,
	|	WorkInProgress.PresentationCurrency AS PresentationCurrency,
	|	WorkInProgress.StructuralUnit AS StructuralUnit,
	|	WorkInProgress.CostObject AS CostObject,
	|	WorkInProgress.Products AS Products,
	|	WorkInProgress.Characteristic AS Characteristic,
	|	WorkInProgress.Quantity AS QuantityBeforeWrite,
	|	WorkInProgress.Quantity AS QuantityChange,
	|	WorkInProgress.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsWorkInProgressChange
	|FROM
	|	AccumulationRegister.WorkInProgress AS WorkInProgress");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsWorkInProgressChange", False);
	
EndProcedure

Function BalancesControlQueryText() Export
	
	Return
	"SELECT
	|	RegisterRecordsWorkInProgressChange.LineNumber AS LineNumber,
	|	RegisterRecordsWorkInProgressChange.Company AS Company,
	|	RegisterRecordsWorkInProgressChange.PresentationCurrency AS PresentationCurrency,
	|	RegisterRecordsWorkInProgressChange.StructuralUnit AS StructuralUnit,
	|	RegisterRecordsWorkInProgressChange.CostObject AS CostObject,
	|	RegisterRecordsWorkInProgressChange.Products AS Products,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	RegisterRecordsWorkInProgressChange.Characteristic AS Characteristic,
	|	RegisterRecordsWorkInProgressChange.QuantityChange + ISNULL(WorkInProgressBalances.QuantityBalance, 0) AS QuantityBalanceBeforeChange,
	|	ISNULL(WorkInProgressBalances.QuantityBalance, 0) AS QuantityBalance
	|FROM
	|	RegisterRecordsWorkInProgressChange AS RegisterRecordsWorkInProgressChange
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON RegisterRecordsWorkInProgressChange.Products = CatalogProducts.Ref
	|		LEFT JOIN AccumulationRegister.WorkInProgress.Balance(&ControlTime, ) AS WorkInProgressBalances
	|		ON RegisterRecordsWorkInProgressChange.Company = WorkInProgressBalances.Company
	|			AND RegisterRecordsWorkInProgressChange.PresentationCurrency = WorkInProgressBalances.PresentationCurrency
	|			AND RegisterRecordsWorkInProgressChange.StructuralUnit = WorkInProgressBalances.StructuralUnit
	|			AND RegisterRecordsWorkInProgressChange.CostObject = WorkInProgressBalances.CostObject
	|			AND RegisterRecordsWorkInProgressChange.Products = WorkInProgressBalances.Products
	|			AND RegisterRecordsWorkInProgressChange.Characteristic = WorkInProgressBalances.Characteristic
	|WHERE
	|	ISNULL(WorkInProgressBalances.QuantityBalance, 0) < 0
	|
	|ORDER BY
	|	LineNumber";
	
EndFunction

#EndRegion

#EndIf