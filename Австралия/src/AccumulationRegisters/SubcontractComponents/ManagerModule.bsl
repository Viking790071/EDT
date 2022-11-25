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
	|	SubcontractComponents.LineNumber AS LineNumber,
	|	SubcontractComponents.Products AS Products,
	|	SubcontractComponents.Characteristic AS Characteristic,
	|	SubcontractComponents.SubcontractorOrder AS SubcontractorOrder,
	|	SubcontractComponents.Quantity AS QuantityBeforeWrite,
	|	SubcontractComponents.Quantity AS QuantityChange,
	|	SubcontractComponents.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsSubcontractComponentsChange
	|FROM
	|	AccumulationRegister.SubcontractComponents AS SubcontractComponents");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsSubcontractComponentsChange", False);
	
EndProcedure

Function BalancesControlQueryText() Export
	
	Return
	"SELECT ALLOWED
	|	RegisterRecordsSubcontractComponentsChange.LineNumber AS LineNumber,
	|	RegisterRecordsSubcontractComponentsChange.SubcontractorOrder AS SubcontractorOrder,
	|	RegisterRecordsSubcontractComponentsChange.Products AS Products,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	RegisterRecordsSubcontractComponentsChange.Characteristic AS Characteristic,
	|	RegisterRecordsSubcontractComponentsChange.QuantityChange + ISNULL(SubcontractComponentsBalances.QuantityBalance, 0) AS QuantityBalanceBeforeChange,
	|	ISNULL(SubcontractComponentsBalances.QuantityBalance, 0) AS QuantityBalance
	|FROM
	|	RegisterRecordsSubcontractComponentsChange AS RegisterRecordsSubcontractComponentsChange
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON RegisterRecordsSubcontractComponentsChange.Products = CatalogProducts.Ref
	|		LEFT JOIN AccumulationRegister.SubcontractComponents.Balance(&ControlTime, ) AS SubcontractComponentsBalances
	|		ON RegisterRecordsSubcontractComponentsChange.SubcontractorOrder = SubcontractComponentsBalances.SubcontractorOrder
	|			AND RegisterRecordsSubcontractComponentsChange.Products = SubcontractComponentsBalances.Products
	|			AND RegisterRecordsSubcontractComponentsChange.Characteristic = SubcontractComponentsBalances.Characteristic
	|WHERE
	|	ISNULL(SubcontractComponentsBalances.QuantityBalance, 0) < 0
	|
	|ORDER BY
	|	LineNumber";
	
EndFunction

#EndRegion

#EndIf