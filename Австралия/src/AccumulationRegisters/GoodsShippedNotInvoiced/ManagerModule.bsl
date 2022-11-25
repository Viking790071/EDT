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
	|	GoodsShippedNotInvoiced.LineNumber AS LineNumber,
	|	GoodsShippedNotInvoiced.Company AS Company,
	|	GoodsShippedNotInvoiced.GoodsIssue AS GoodsIssue,
	|	GoodsShippedNotInvoiced.Counterparty AS Counterparty,
	|	GoodsShippedNotInvoiced.Contract AS Contract,
	|	GoodsShippedNotInvoiced.Products AS Products,
	|	GoodsShippedNotInvoiced.Characteristic AS Characteristic,
	|	GoodsShippedNotInvoiced.Batch AS Batch,
	|	GoodsShippedNotInvoiced.Ownership AS Ownership,
	|	GoodsShippedNotInvoiced.SalesOrder AS SalesOrder,
	|	GoodsShippedNotInvoiced.Quantity AS QuantityBeforeWrite,
	|	GoodsShippedNotInvoiced.Quantity AS QuantityChange,
	|	GoodsShippedNotInvoiced.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsGoodsShippedNotInvoicedChange
	|FROM
	|	AccumulationRegister.GoodsShippedNotInvoiced AS GoodsShippedNotInvoiced");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsGoodsShippedNotInvoicedChange", False);
	
EndProcedure

Function BalancesControlQueryText() Export
	
	Return
	"SELECT
	|	RegisterRecordsGoodsShippedNotInvoicedChange.LineNumber AS LineNumber,
	|	RegisterRecordsGoodsShippedNotInvoicedChange.Company AS CompanyPresentation,
	|	RegisterRecordsGoodsShippedNotInvoicedChange.GoodsIssue AS GoodsIssuePresentation,
	|	RegisterRecordsGoodsShippedNotInvoicedChange.Products AS ProductsPresentation,
	|	RegisterRecordsGoodsShippedNotInvoicedChange.Characteristic AS CharacteristicPresentation,
	|	GoodsShippedNotInvoicedBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
	|	ISNULL(RegisterRecordsGoodsShippedNotInvoicedChange.QuantityChange, 0) + ISNULL(GoodsShippedNotInvoicedBalances.QuantityBalance, 0) AS BalanceGoodsShippedNotInvoiced,
	|	ISNULL(GoodsShippedNotInvoicedBalances.QuantityBalance, 0) AS QuantityBalanceGoodsShippedNotInvoiced
	|FROM
	|	RegisterRecordsGoodsShippedNotInvoicedChange AS RegisterRecordsGoodsShippedNotInvoicedChange
	|		INNER JOIN AccumulationRegister.GoodsShippedNotInvoiced.Balance(&ControlTime, ) AS GoodsShippedNotInvoicedBalances
	|		ON RegisterRecordsGoodsShippedNotInvoicedChange.Company = GoodsShippedNotInvoicedBalances.Company
	|			AND RegisterRecordsGoodsShippedNotInvoicedChange.GoodsIssue = GoodsShippedNotInvoicedBalances.GoodsIssue
	|			AND RegisterRecordsGoodsShippedNotInvoicedChange.Counterparty = GoodsShippedNotInvoicedBalances.Counterparty
	|			AND RegisterRecordsGoodsShippedNotInvoicedChange.Contract = GoodsShippedNotInvoicedBalances.Contract
	|			AND RegisterRecordsGoodsShippedNotInvoicedChange.SalesOrder = GoodsShippedNotInvoicedBalances.SalesOrder
	|			AND RegisterRecordsGoodsShippedNotInvoicedChange.Products = GoodsShippedNotInvoicedBalances.Products
	|			AND RegisterRecordsGoodsShippedNotInvoicedChange.Characteristic = GoodsShippedNotInvoicedBalances.Characteristic
	|			AND RegisterRecordsGoodsShippedNotInvoicedChange.Batch = GoodsShippedNotInvoicedBalances.Batch
	|			AND RegisterRecordsGoodsShippedNotInvoicedChange.Ownership = GoodsShippedNotInvoicedBalances.Ownership
	|			AND (ISNULL(GoodsShippedNotInvoicedBalances.QuantityBalance, 0) < 0)
	|
	|ORDER BY
	|	LineNumber";
	
EndFunction

#EndRegion

#EndIf