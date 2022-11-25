#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

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
	|	GoodsReceivedNotInvoiced.LineNumber AS LineNumber,
	|	GoodsReceivedNotInvoiced.Company AS Company,
	|	GoodsReceivedNotInvoiced.PresentationCurrency AS PresentationCurrency,
	|	GoodsReceivedNotInvoiced.GoodsReceipt AS GoodsReceipt,
	|	GoodsReceivedNotInvoiced.Counterparty AS Counterparty,
	|	GoodsReceivedNotInvoiced.Contract AS Contract,
	|	GoodsReceivedNotInvoiced.Products AS Products,
	|	GoodsReceivedNotInvoiced.Characteristic AS Characteristic,
	|	GoodsReceivedNotInvoiced.Batch AS Batch,
	|	GoodsReceivedNotInvoiced.PurchaseOrder AS PurchaseOrder,
	|	GoodsReceivedNotInvoiced.SalesOrder AS SalesOrder,
	|	GoodsReceivedNotInvoiced.Quantity AS QuantityBeforeWrite,
	|	GoodsReceivedNotInvoiced.Quantity AS QuantityChange,
	|	GoodsReceivedNotInvoiced.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsGoodsReceivedNotInvoicedChange
	|FROM
	|	AccumulationRegister.GoodsReceivedNotInvoiced AS GoodsReceivedNotInvoiced");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsGoodsReceivedNotInvoicedChange", False);
	
EndProcedure

Function BalancesControlQueryText() Export
	
	Return
	"SELECT ALLOWED
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.LineNumber AS LineNumber,
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.GoodsReceipt AS GoodsReceiptPresentation,
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.Company AS CompanyPresentation,
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.PresentationCurrency AS PresentationCurrency,
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.Products AS ProductsPresentation,
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.Characteristic AS CharacteristicPresentation,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnitPresentation,
	|	ISNULL(RegisterRecordsGoodsReceivedNotInvoicedChange.QuantityChange, 0) + ISNULL(GoodsReceivedNotInvoicedBalances.QuantityBalance, 0) AS BalanceGoodsReceivedNotInvoiced,
	|	ISNULL(GoodsReceivedNotInvoicedBalances.QuantityBalance, 0) AS QuantityBalanceGoodsReceivedNotInvoiced
	|FROM
	|	RegisterRecordsGoodsReceivedNotInvoicedChange AS RegisterRecordsGoodsReceivedNotInvoicedChange
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON RegisterRecordsGoodsReceivedNotInvoicedChange.Products = CatalogProducts.Ref
	|		INNER JOIN AccumulationRegister.GoodsReceivedNotInvoiced.Balance(&ControlTime, ) AS GoodsReceivedNotInvoicedBalances
	|		ON RegisterRecordsGoodsReceivedNotInvoicedChange.GoodsReceipt = GoodsReceivedNotInvoicedBalances.GoodsReceipt
	|			AND RegisterRecordsGoodsReceivedNotInvoicedChange.Company = GoodsReceivedNotInvoicedBalances.Company
	|			AND RegisterRecordsGoodsReceivedNotInvoicedChange.PresentationCurrency = GoodsReceivedNotInvoicedBalances.PresentationCurrency
	|			AND RegisterRecordsGoodsReceivedNotInvoicedChange.Counterparty = GoodsReceivedNotInvoicedBalances.Counterparty
	|			AND RegisterRecordsGoodsReceivedNotInvoicedChange.Contract = GoodsReceivedNotInvoicedBalances.Contract
	|			AND RegisterRecordsGoodsReceivedNotInvoicedChange.PurchaseOrder = GoodsReceivedNotInvoicedBalances.PurchaseOrder
	|			AND RegisterRecordsGoodsReceivedNotInvoicedChange.Products = GoodsReceivedNotInvoicedBalances.Products
	|			AND RegisterRecordsGoodsReceivedNotInvoicedChange.Characteristic = GoodsReceivedNotInvoicedBalances.Characteristic
	|			AND RegisterRecordsGoodsReceivedNotInvoicedChange.Batch = GoodsReceivedNotInvoicedBalances.Batch
	|			AND RegisterRecordsGoodsReceivedNotInvoicedChange.SalesOrder = GoodsReceivedNotInvoicedBalances.SalesOrder
	|			AND (ISNULL(GoodsReceivedNotInvoicedBalances.QuantityBalance, 0) < 0)
	|
	|ORDER BY
	|	LineNumber";
	
EndFunction

#EndRegion

#EndIf