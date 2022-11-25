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
	|	GoodsInvoicedNotReceived.LineNumber AS LineNumber,
	|	GoodsInvoicedNotReceived.Company AS Company,
	|	GoodsInvoicedNotReceived.PresentationCurrency AS PresentationCurrency,
	|	GoodsInvoicedNotReceived.SupplierInvoice AS SupplierInvoice,
	|	GoodsInvoicedNotReceived.Counterparty AS Counterparty,
	|	GoodsInvoicedNotReceived.Contract AS Contract,
	|	GoodsInvoicedNotReceived.Products AS Products,
	|	GoodsInvoicedNotReceived.Characteristic AS Characteristic,
	|	GoodsInvoicedNotReceived.Batch AS Batch,
	|	GoodsInvoicedNotReceived.VATRate AS VATRate,
	|	GoodsInvoicedNotReceived.PurchaseOrder AS PurchaseOrder,
	|	GoodsInvoicedNotReceived.Quantity AS QuantityBeforeWrite,
	|	GoodsInvoicedNotReceived.Quantity AS QuantityChange,
	|	GoodsInvoicedNotReceived.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsGoodsInvoicedNotReceivedChange
	|FROM
	|	AccumulationRegister.GoodsInvoicedNotReceived AS GoodsInvoicedNotReceived");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsGoodsInvoicedNotReceivedChange", False);
	
EndProcedure

Function BalancesControlQueryText() Export
	
	Return
	"SELECT ALLOWED
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.LineNumber AS LineNumber,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.SupplierInvoice AS SupplierInvoice,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.Company AS Company,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.PresentationCurrency AS PresentationCurrency,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.Counterparty AS Counterparty,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.Contract AS Contract,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.PurchaseOrder AS PurchaseOrder,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.Products AS Products,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.Characteristic AS Characteristic,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.Batch AS Batch,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.VATRate AS VATRate,
	|	RegisterRecordsGoodsInvoicedNotReceivedChange.QuantityChange + ISNULL(GoodsInvoicedNotReceivedBalances.QuantityBalance, 0) AS QuantityBalanceBeforeChange,
	|	ISNULL(GoodsInvoicedNotReceivedBalances.QuantityBalance, 0) AS QuantityBalance
	|FROM
	|	RegisterRecordsGoodsInvoicedNotReceivedChange AS RegisterRecordsGoodsInvoicedNotReceivedChange
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON RegisterRecordsGoodsInvoicedNotReceivedChange.Products = CatalogProducts.Ref
	|		LEFT JOIN AccumulationRegister.GoodsInvoicedNotReceived.Balance(&ControlTime, ) AS GoodsInvoicedNotReceivedBalances
	|		ON RegisterRecordsGoodsInvoicedNotReceivedChange.SupplierInvoice = GoodsInvoicedNotReceivedBalances.SupplierInvoice
	|			AND RegisterRecordsGoodsInvoicedNotReceivedChange.Company = GoodsInvoicedNotReceivedBalances.Company
	|			AND RegisterRecordsGoodsInvoicedNotReceivedChange.PresentationCurrency = GoodsInvoicedNotReceivedBalances.PresentationCurrency
	|			AND RegisterRecordsGoodsInvoicedNotReceivedChange.Counterparty = GoodsInvoicedNotReceivedBalances.Counterparty
	|			AND RegisterRecordsGoodsInvoicedNotReceivedChange.Contract = GoodsInvoicedNotReceivedBalances.Contract
	|			AND RegisterRecordsGoodsInvoicedNotReceivedChange.PurchaseOrder = GoodsInvoicedNotReceivedBalances.PurchaseOrder
	|			AND RegisterRecordsGoodsInvoicedNotReceivedChange.Products = GoodsInvoicedNotReceivedBalances.Products
	|			AND RegisterRecordsGoodsInvoicedNotReceivedChange.Characteristic = GoodsInvoicedNotReceivedBalances.Characteristic
	|			AND RegisterRecordsGoodsInvoicedNotReceivedChange.Batch = GoodsInvoicedNotReceivedBalances.Batch
	|			AND RegisterRecordsGoodsInvoicedNotReceivedChange.VATRate = GoodsInvoicedNotReceivedBalances.VATRate
	|WHERE
	|	ISNULL(GoodsInvoicedNotReceivedBalances.QuantityBalance, 0) < 0
	|
	|ORDER BY
	|	LineNumber";
	
EndFunction

#EndRegion

#EndIf