#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Procedure CreateEmptyTemporaryTableChange(AdditionalProperties) Export
	
	If Not AdditionalProperties.Property("ForPosting")
		Or Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query(
	"SELECT TOP 0
	|	CustomerOwnedInventory.LineNumber AS LineNumber,
	|	CustomerOwnedInventory.Company AS Company,
	|	CustomerOwnedInventory.Counterparty AS Counterparty,
	|	CustomerOwnedInventory.SubcontractorOrder AS SubcontractorOrder,
	|	CustomerOwnedInventory.Products AS Products,
	|	CustomerOwnedInventory.Characteristic AS Characteristic,
	|	CustomerOwnedInventory.ProductionOrder AS ProductionOrder,
	|	CustomerOwnedInventory.QuantityToIssue AS QuantityToIssueBeforeWrite,
	|	CustomerOwnedInventory.QuantityToIssue AS QuantityToIssueChange,
	|	CustomerOwnedInventory.QuantityToIssue AS QuantityToIssueOnWrite,
	|	CustomerOwnedInventory.QuantityToInvoice AS QuantityToInvoiceBeforeWrite,
	|	CustomerOwnedInventory.QuantityToInvoice AS QuantityToInvoiceChange,
	|	CustomerOwnedInventory.QuantityToInvoice AS QuantityToInvoiceOnWrite
	|INTO RegisterRecordsCustomerOwnedInventoryChange
	|FROM
	|	AccumulationRegister.CustomerOwnedInventory AS CustomerOwnedInventory");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsCustomerOwnedInventoryChange", False);
	
EndProcedure

Function BalancesControlQueryText() Export
	
	Return
	"SELECT ALLOWED
	|	RegisterRecordsCustomerOwnedInventoryChange.LineNumber AS LineNumber,
	|	RegisterRecordsCustomerOwnedInventoryChange.Company AS Company,
	|	RegisterRecordsCustomerOwnedInventoryChange.Counterparty AS Counterparty,
	|	RegisterRecordsCustomerOwnedInventoryChange.SubcontractorOrder AS SubcontractorOrder,
	|	RegisterRecordsCustomerOwnedInventoryChange.Products AS Products,
	|	RegisterRecordsCustomerOwnedInventoryChange.Characteristic AS Characteristic,
	|	RegisterRecordsCustomerOwnedInventoryChange.ProductionOrder AS ProductionOrder,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	RegisterRecordsCustomerOwnedInventoryChange.QuantityToIssueChange + ISNULL(CustomerOwnedInventoryBalances.QuantityToIssueBalance, 0) AS QuantityToIssueBalanceBeforeChange,
	|	ISNULL(CustomerOwnedInventoryBalances.QuantityToIssueBalance, 0) AS QuantityToIssueBalance,
	|	RegisterRecordsCustomerOwnedInventoryChange.QuantityToInvoiceChange + ISNULL(CustomerOwnedInventoryBalances.QuantityToInvoiceBalance, 0) AS QuantityToInvoiceBalanceBeforeChange,
	|	ISNULL(CustomerOwnedInventoryBalances.QuantityToInvoiceBalance, 0) AS QuantityToInvoiceBalance
	|FROM
	|	RegisterRecordsCustomerOwnedInventoryChange AS RegisterRecordsCustomerOwnedInventoryChange
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON RegisterRecordsCustomerOwnedInventoryChange.Products = CatalogProducts.Ref
	|		LEFT JOIN AccumulationRegister.CustomerOwnedInventory.Balance(&ControlTime, ) AS CustomerOwnedInventoryBalances
	|		ON RegisterRecordsCustomerOwnedInventoryChange.Company = CustomerOwnedInventoryBalances.Company
	|			AND RegisterRecordsCustomerOwnedInventoryChange.Counterparty = CustomerOwnedInventoryBalances.Counterparty
	|			AND RegisterRecordsCustomerOwnedInventoryChange.SubcontractorOrder = CustomerOwnedInventoryBalances.SubcontractorOrder
	|			AND RegisterRecordsCustomerOwnedInventoryChange.Products = CustomerOwnedInventoryBalances.Products
	|			AND RegisterRecordsCustomerOwnedInventoryChange.Characteristic = CustomerOwnedInventoryBalances.Characteristic
	|			AND RegisterRecordsCustomerOwnedInventoryChange.ProductionOrder = CustomerOwnedInventoryBalances.ProductionOrder
	|WHERE
	|	(ISNULL(CustomerOwnedInventoryBalances.QuantityToIssueBalance, 0) < 0
	|			OR ISNULL(CustomerOwnedInventoryBalances.QuantityToInvoiceBalance, 0) < 0)
	|
	|ORDER BY
	|	LineNumber";
	
EndFunction

#EndRegion

#EndIf