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
	|	SubcontractorOrdersReceived.LineNumber AS LineNumber,
	|	SubcontractorOrdersReceived.Company AS Company,
	|	SubcontractorOrdersReceived.SubcontractorOrder AS SubcontractorOrder,
	|	SubcontractorOrdersReceived.Products AS Products,
	|	SubcontractorOrdersReceived.Characteristic AS Characteristic,
	|	SubcontractorOrdersReceived.Quantity AS QuantityBeforeWrite,
	|	SubcontractorOrdersReceived.Quantity AS QuantityChange,
	|	SubcontractorOrdersReceived.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsSubcontractorOrdersReceivedChange
	|FROM
	|	AccumulationRegister.SubcontractorOrdersReceived AS SubcontractorOrdersReceived";
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsSubcontractorOrdersReceivedChange", False);
	
EndProcedure

Function BalancesControlQueryText() Export
	
	Return
	"SELECT ALLOWED
	|	RegisterRecordsSubcontractorOrdersReceivedChange.LineNumber AS LineNumber,
	|	RegisterRecordsSubcontractorOrdersReceivedChange.Company AS Company,
	|	RegisterRecordsSubcontractorOrdersReceivedChange.SubcontractorOrder AS SubcontractorOrder,
	|	RegisterRecordsSubcontractorOrdersReceivedChange.Products AS Products,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	RegisterRecordsSubcontractorOrdersReceivedChange.Characteristic AS Characteristic,
	|	RegisterRecordsSubcontractorOrdersReceivedChange.QuantityChange + ISNULL(SubcontractorOrdersReceivedBalances.QuantityBalance, 0) AS QuantityBalanceBeforeChange,
	|	ISNULL(SubcontractorOrdersReceivedBalances.QuantityBalance, 0) AS QuantityBalance
	|FROM
	|	RegisterRecordsSubcontractorOrdersReceivedChange AS RegisterRecordsSubcontractorOrdersReceivedChange
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON RegisterRecordsSubcontractorOrdersReceivedChange.Products = CatalogProducts.Ref
	|		LEFT JOIN AccumulationRegister.SubcontractorOrdersIssued.Balance(&ControlTime, ) AS SubcontractorOrdersReceivedBalances
	|		ON RegisterRecordsSubcontractorOrdersReceivedChange.Company = SubcontractorOrdersReceivedBalances.Company
	|			AND RegisterRecordsSubcontractorOrdersReceivedChange.SubcontractorOrder = SubcontractorOrdersReceivedBalances.SubcontractorOrder
	|			AND RegisterRecordsSubcontractorOrdersReceivedChange.Products = SubcontractorOrdersReceivedBalances.Products
	|			AND RegisterRecordsSubcontractorOrdersReceivedChange.Characteristic = SubcontractorOrdersReceivedBalances.Characteristic
	|WHERE
	|	ISNULL(SubcontractorOrdersReceivedBalances.QuantityBalance, 0) < 0
	|
	|ORDER BY
	|	LineNumber";
	
EndFunction

#EndRegion

#EndIf