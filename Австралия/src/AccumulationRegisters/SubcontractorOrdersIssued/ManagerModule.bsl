#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Procedure creates an empty temporary table of records change.
//
Procedure CreateEmptyTemporaryTableChange(AdditionalProperties) Export
	
	If Not AdditionalProperties.Property("ForPosting")
		Or Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 0
	|	SubcontractorOrdersIssued.LineNumber AS LineNumber,
	|	SubcontractorOrdersIssued.Company AS Company,
	|	SubcontractorOrdersIssued.SubcontractorOrder AS SubcontractorOrder,
	|	SubcontractorOrdersIssued.Products AS Products,
	|	SubcontractorOrdersIssued.Characteristic AS Characteristic,
	|	SubcontractorOrdersIssued.FinishedProductType AS FinishedProductType,
	|	SubcontractorOrdersIssued.Quantity AS QuantityBeforeWrite,
	|	SubcontractorOrdersIssued.Quantity AS QuantityChange,
	|	SubcontractorOrdersIssued.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsSubcontractorOrdersIssuedChange
	|FROM
	|	AccumulationRegister.SubcontractorOrdersIssued AS SubcontractorOrdersIssued";
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsSubcontractorOrdersIssuedChange", False);
	
EndProcedure

Function BalancesControlQueryText() Export
	
	Return
	"SELECT ALLOWED
	|	RegisterRecordsSubcontractorOrdersIssuedChange.LineNumber AS LineNumber,
	|	RegisterRecordsSubcontractorOrdersIssuedChange.Company AS Company,
	|	RegisterRecordsSubcontractorOrdersIssuedChange.SubcontractorOrder AS SubcontractorOrder,
	|	RegisterRecordsSubcontractorOrdersIssuedChange.Products AS Products,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	RegisterRecordsSubcontractorOrdersIssuedChange.Characteristic AS Characteristic,
	|	RegisterRecordsSubcontractorOrdersIssuedChange.FinishedProductType AS FinishedProductType,
	|	RegisterRecordsSubcontractorOrdersIssuedChange.QuantityChange + ISNULL(SubcontractorOrdersIssuedBalances.QuantityBalance, 0) AS QuantityBalanceBeforeChange,
	|	ISNULL(SubcontractorOrdersIssuedBalances.QuantityBalance, 0) AS QuantityBalance
	|FROM
	|	RegisterRecordsSubcontractorOrdersIssuedChange AS RegisterRecordsSubcontractorOrdersIssuedChange
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON RegisterRecordsSubcontractorOrdersIssuedChange.Products = CatalogProducts.Ref
	|		LEFT JOIN AccumulationRegister.SubcontractorOrdersIssued.Balance(&ControlTime, ) AS SubcontractorOrdersIssuedBalances
	|		ON RegisterRecordsSubcontractorOrdersIssuedChange.Company = SubcontractorOrdersIssuedBalances.Company
	|			AND RegisterRecordsSubcontractorOrdersIssuedChange.SubcontractorOrder = SubcontractorOrdersIssuedBalances.SubcontractorOrder
	|			AND RegisterRecordsSubcontractorOrdersIssuedChange.Products = SubcontractorOrdersIssuedBalances.Products
	|			AND RegisterRecordsSubcontractorOrdersIssuedChange.Characteristic = SubcontractorOrdersIssuedBalances.Characteristic
	|			AND RegisterRecordsSubcontractorOrdersIssuedChange.FinishedProductType = SubcontractorOrdersIssuedBalances.FinishedProductType
	|WHERE
	|	ISNULL(SubcontractorOrdersIssuedBalances.QuantityBalance, 0) < 0
	|
	|ORDER BY
	|	LineNumber";
	
EndFunction

#EndRegion

#EndIf