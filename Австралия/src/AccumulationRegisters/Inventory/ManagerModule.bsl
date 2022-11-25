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
	|	Inventory.LineNumber AS LineNumber,
	|	Inventory.Company AS Company,
	|	Inventory.PresentationCurrency AS PresentationCurrency,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.CostObject AS CostObject,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.InventoryAccountType AS InventoryAccountType,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.Ownership AS Ownership,
	|	Inventory.Quantity AS QuantityBeforeWrite,
	|	Inventory.Quantity AS QuantityChange,
	|	Inventory.Quantity AS QuantityOnWrite,
	|	Inventory.Amount AS SumBeforeWrite,
	|	Inventory.Amount AS AmountChange,
	|	Inventory.Amount AS AmountOnWrite
	|INTO RegisterRecordsInventoryChange
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 0
	|	Inventory.LineNumber AS LineNumber,
	|	Inventory.Company AS Company,
	|	Inventory.PresentationCurrency AS PresentationCurrency,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.Ownership AS Ownership,
	|	Inventory.SourceDocument AS SourceDocument,
	|	Inventory.Quantity AS QuantityBeforeWrite,
	|	Inventory.Quantity AS QuantityChange,
	|	Inventory.Quantity AS QuantityOnWrite,
	|	Inventory.Amount AS SumBeforeWrite,
	|	Inventory.Amount AS AmountChange,
	|	Inventory.Amount AS AmountOnWrite
	|INTO RegisterRecordsInventoryWithSourceDocumentChange
	|FROM
	|	AccumulationRegister.Inventory AS Inventory");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsInventoryChange", False);
	StructureTemporaryTables.Insert("RegisterRecordsInventoryWithSourceDocumentChange", False);
	
EndProcedure

Function ReturnQuantityControlQueryText(ReturnDocument = True) Export
	
	If ReturnDocument Then
		QueryText =
		"SELECT
		|	Inventory.Company AS Company,
		|	Inventory.PresentationCurrency AS PresentationCurrency,
		|	Inventory.Products AS Products,
		|	Inventory.Characteristic AS Characteristic,
		|	Inventory.Batch AS Batch,
		|	Inventory.Ownership AS Ownership,
		|	Inventory.InventoryAccountType AS InventoryAccountType,
		|	Inventory.StructuralUnit AS StructuralUnit,
		|	Inventory.SourceDocument AS SourceDocument,
		|	Inventory.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	Inventory.Products.MeasurementUnit AS MeasurementUnit,
		|	SUM(Inventory.Quantity) AS Quantity
		|INTO TT_InventorySourceDocument
		|FROM
		|	AccumulationRegister.Inventory AS Inventory
		|WHERE
		|	Inventory.Return
		|	AND Inventory.Recorder = &Ref
		|	AND (Inventory.SourceDocument REFS Document.SupplierInvoice
		|			OR Inventory.SourceDocument REFS Document.SalesInvoice)
		|
		|GROUP BY
		|	Inventory.Company,
		|	Inventory.PresentationCurrency,
		|	Inventory.Products,
		|	Inventory.Characteristic,
		|	Inventory.Batch,
		|	Inventory.Ownership,
		|	Inventory.InventoryAccountType,
		|	Inventory.StructuralUnit,
		|	Inventory.SourceDocument,
		|	Inventory.StructuralUnit.StructuralUnitType,
		|	Inventory.Products.MeasurementUnit
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Inventory.Company AS Company,
		|	Inventory.PresentationCurrency AS PresentationCurrency,
		|	Inventory.Products AS Products,
		|	Inventory.Characteristic AS Characteristic,
		|	Inventory.Batch AS Batch,
		|	Inventory.Ownership AS Ownership,
		|	Inventory.InventoryAccountType AS InventoryAccountType,
		|	Inventory.StructuralUnit AS StructuralUnit,
		|	Inventory.SourceDocument AS SourceDocument,
		|	Inventory.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	Inventory.Products.MeasurementUnit AS MeasurementUnit,
		|	SUM(Inventory.Quantity) AS Quantity,
		|	SUM(ISNULL(InventorySourceDocument.Quantity, 0)) AS BalanceQuantity
		|INTO TT_DataPre
		|FROM
		|	TT_InventorySourceDocument AS Inventory
		|		LEFT JOIN AccumulationRegister.Inventory AS InventorySourceDocument
		|		ON Inventory.Company = InventorySourceDocument.Company
		|			AND Inventory.PresentationCurrency = InventorySourceDocument.PresentationCurrency
		|			AND Inventory.Products = InventorySourceDocument.Products
		|			AND Inventory.Characteristic = InventorySourceDocument.Characteristic
		|			AND Inventory.Batch = InventorySourceDocument.Batch
		|			AND Inventory.Ownership = InventorySourceDocument.Ownership
		|			AND Inventory.InventoryAccountType = InventorySourceDocument.InventoryAccountType
		|			AND Inventory.StructuralUnit = InventorySourceDocument.StructuralUnit
		|			AND Inventory.SourceDocument = InventorySourceDocument.SourceDocument
		|			AND (InventorySourceDocument.Return)
		|			AND (InventorySourceDocument.Recorder <> &Ref)
		|
		|GROUP BY
		|	Inventory.Company,
		|	Inventory.PresentationCurrency,
		|	Inventory.Products,
		|	Inventory.Characteristic,
		|	Inventory.Batch,
		|	Inventory.Ownership,
		|	Inventory.InventoryAccountType,
		|	Inventory.StructuralUnit,
		|	Inventory.SourceDocument,
		|	Inventory.StructuralUnit.StructuralUnitType,
		|	Inventory.Products.MeasurementUnit
		|
		|UNION ALL
		|
		|SELECT
		|	Inventory.Company,
		|	Inventory.PresentationCurrency,
		|	Inventory.Products,
		|	Inventory.Characteristic,
		|	Inventory.Batch,
		|	Inventory.Ownership,
		|	Inventory.InventoryAccountType,
		|	Inventory.StructuralUnit,
		|	Inventory.SourceDocument,
		|	Inventory.StructuralUnit.StructuralUnitType,
		|	Inventory.Products.MeasurementUnit,
		|	SUM(Inventory.Quantity),
		|	SUM(ISNULL(InventorySourceDocument.Quantity, 0))
		|FROM
		|	TT_InventorySourceDocument AS Inventory
		|		LEFT JOIN AccumulationRegister.Inventory AS InventorySourceDocument
		|		ON Inventory.Company = InventorySourceDocument.Company
		|			AND Inventory.PresentationCurrency = InventorySourceDocument.PresentationCurrency
		|			AND Inventory.Products = InventorySourceDocument.Products
		|			AND Inventory.Characteristic = InventorySourceDocument.Characteristic
		|			AND Inventory.Batch = InventorySourceDocument.Batch
		|			AND Inventory.Ownership = InventorySourceDocument.Ownership
		|			AND Inventory.InventoryAccountType = InventorySourceDocument.InventoryAccountType
		|			AND Inventory.StructuralUnit <> InventorySourceDocument.StructuralUnit
		|			AND (InventorySourceDocument.StructuralUnit = VALUE(Catalog.BusinessUnits.DropShipping))
		|			AND Inventory.SourceDocument = InventorySourceDocument.SourceDocument
		|			AND (InventorySourceDocument.Return)
		|			AND (InventorySourceDocument.Recorder <> &Ref)
		|
		|GROUP BY
		|	Inventory.Company,
		|	Inventory.PresentationCurrency,
		|	Inventory.Products,
		|	Inventory.Characteristic,
		|	Inventory.Batch,
		|	Inventory.Ownership,
		|	Inventory.InventoryAccountType,
		|	Inventory.StructuralUnit,
		|	Inventory.SourceDocument,
		|	Inventory.StructuralUnit.StructuralUnitType,
		|	Inventory.Products.MeasurementUnit
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_DataPre.Company AS Company,
		|	TT_DataPre.PresentationCurrency AS PresentationCurrency,
		|	TT_DataPre.Products AS Products,
		|	TT_DataPre.Characteristic AS Characteristic,
		|	TT_DataPre.Batch AS Batch,
		|	TT_DataPre.Ownership AS Ownership,
		|	TT_DataPre.InventoryAccountType AS InventoryAccountType,
		|	TT_DataPre.StructuralUnit AS StructuralUnit,
		|	TT_DataPre.SourceDocument AS SourceDocument,
		|	TT_DataPre.StructuralUnitType AS StructuralUnitType,
		|	TT_DataPre.MeasurementUnit AS MeasurementUnit,
		|	TT_DataPre.Quantity AS Quantity,
		|	SUM(TT_DataPre.BalanceQuantity) AS BalanceQuantity
		|INTO TT_Data
		|FROM
		|	TT_DataPre AS TT_DataPre
		|
		|GROUP BY
		|	TT_DataPre.Company,
		|	TT_DataPre.PresentationCurrency,
		|	TT_DataPre.Products,
		|	TT_DataPre.Characteristic,
		|	TT_DataPre.Batch,
		|	TT_DataPre.Ownership,
		|	TT_DataPre.InventoryAccountType,
		|	TT_DataPre.StructuralUnit,
		|	TT_DataPre.SourceDocument,
		|	TT_DataPre.StructuralUnitType,
		|	TT_DataPre.MeasurementUnit,
		|	TT_DataPre.Quantity
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TT_Data.SourceDocument AS SourceDocument
		|INTO ExistSourceInventory
		|FROM
		|	TT_Data AS TT_Data
		|		INNER JOIN AccumulationRegister.Inventory AS Inventory
		|		ON TT_Data.SourceDocument = Inventory.Recorder
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_Data.Company AS Company,
		|	TT_Data.PresentationCurrency AS PresentationCurrency,
		|	TT_Data.Products AS ProductsPresentation,
		|	TT_Data.Characteristic AS CharacteristicPresentation,
		|	TT_Data.Batch AS BatchPresentation,
		|	TT_Data.Ownership AS Ownership,
		|	TT_Data.InventoryAccountType AS InventoryAccountType,
		|	TT_Data.StructuralUnit AS StructuralUnitPresentation,
		|	TT_Data.SourceDocument AS SourceDocument,
		|	TT_Data.StructuralUnitType AS StructuralUnitType,
		|	TT_Data.MeasurementUnit AS MeasurementUnitPresentation,
		|	TT_Data.Quantity AS Quantity,
		|	TT_Data.BalanceQuantity AS BalanceQuantity,
		|	SUM(ISNULL(Inventory.Quantity, 0)) AS BalanceInventory
		|INTO TT_BalanceInventoryPre
		|FROM
		|	TT_Data AS TT_Data
		|		INNER JOIN ExistSourceInventory AS ExistSourceInventory
		|		ON TT_Data.SourceDocument = ExistSourceInventory.SourceDocument
		|		LEFT JOIN AccumulationRegister.Inventory AS Inventory
		|		ON TT_Data.Company = Inventory.Company
		|			AND TT_Data.PresentationCurrency = Inventory.PresentationCurrency
		|			AND TT_Data.Products = Inventory.Products
		|			AND TT_Data.Characteristic = Inventory.Characteristic
		|			AND TT_Data.Batch = Inventory.Batch
		|			AND TT_Data.Ownership = Inventory.Ownership
		|			AND TT_Data.InventoryAccountType = Inventory.InventoryAccountType
		|			AND TT_Data.StructuralUnit = Inventory.StructuralUnit
		|			AND TT_Data.SourceDocument = Inventory.Recorder
		|
		|GROUP BY
		|	TT_Data.Company,
		|	TT_Data.PresentationCurrency,
		|	TT_Data.Products,
		|	TT_Data.Characteristic,
		|	TT_Data.Batch,
		|	TT_Data.Ownership,
		|	TT_Data.InventoryAccountType,
		|	TT_Data.StructuralUnit,
		|	TT_Data.SourceDocument,
		|	TT_Data.StructuralUnitType,
		|	TT_Data.MeasurementUnit,
		|	TT_Data.Quantity,
		|	TT_Data.BalanceQuantity
		|
		|UNION ALL
		|
		|SELECT
		|	TT_Data.Company,
		|	TT_Data.PresentationCurrency,
		|	TT_Data.Products,
		|	TT_Data.Characteristic,
		|	TT_Data.Batch,
		|	TT_Data.Ownership,
		|	TT_Data.InventoryAccountType,
		|	TT_Data.StructuralUnit,
		|	TT_Data.SourceDocument,
		|	TT_Data.StructuralUnitType,
		|	TT_Data.MeasurementUnit,
		|	TT_Data.Quantity,
		|	TT_Data.BalanceQuantity,
		|	SUM(ISNULL(Inventory.Quantity, 0))
		|FROM
		|	TT_Data AS TT_Data
		|		INNER JOIN ExistSourceInventory AS ExistSourceInventory
		|		ON TT_Data.SourceDocument = ExistSourceInventory.SourceDocument
		|		LEFT JOIN AccumulationRegister.Inventory AS Inventory
		|		ON TT_Data.Company = Inventory.Company
		|			AND TT_Data.PresentationCurrency = Inventory.PresentationCurrency
		|			AND TT_Data.Products = Inventory.Products
		|			AND TT_Data.Characteristic = Inventory.Characteristic
		|			AND TT_Data.Batch = Inventory.Batch
		|			AND TT_Data.Ownership = Inventory.Ownership
		|			AND TT_Data.InventoryAccountType = Inventory.InventoryAccountType
		|			AND TT_Data.StructuralUnit <> Inventory.StructuralUnit
		|			AND (Inventory.StructuralUnit = VALUE(Catalog.BusinessUnits.DropShipping))
		|			AND TT_Data.SourceDocument = Inventory.Recorder
		|
		|GROUP BY
		|	TT_Data.Company,
		|	TT_Data.PresentationCurrency,
		|	TT_Data.Products,
		|	TT_Data.Characteristic,
		|	TT_Data.Batch,
		|	TT_Data.Ownership,
		|	TT_Data.InventoryAccountType,
		|	TT_Data.StructuralUnit,
		|	TT_Data.SourceDocument,
		|	TT_Data.StructuralUnitType,
		|	TT_Data.MeasurementUnit,
		|	TT_Data.Quantity,
		|	TT_Data.BalanceQuantity
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_BalanceInventoryPre.Company AS Company,
		|	TT_BalanceInventoryPre.PresentationCurrency AS PresentationCurrency,
		|	TT_BalanceInventoryPre.ProductsPresentation AS ProductsPresentation,
		|	TT_BalanceInventoryPre.CharacteristicPresentation AS CharacteristicPresentation,
		|	TT_BalanceInventoryPre.BatchPresentation AS BatchPresentation,
		|	TT_BalanceInventoryPre.Ownership AS Ownership,
		|	TT_BalanceInventoryPre.InventoryAccountType AS InventoryAccountType,
		|	TT_BalanceInventoryPre.StructuralUnitPresentation AS StructuralUnitPresentation,
		|	TT_BalanceInventoryPre.SourceDocument AS SourceDocument,
		|	TT_BalanceInventoryPre.StructuralUnitType AS StructuralUnitType,
		|	TT_BalanceInventoryPre.MeasurementUnitPresentation AS MeasurementUnitPresentation,
		|	SUM(TT_BalanceInventoryPre.BalanceInventory) - TT_BalanceInventoryPre.Quantity - TT_BalanceInventoryPre.BalanceQuantity AS QuantityBalanceInventory,
		|	SUM(TT_BalanceInventoryPre.BalanceInventory) - TT_BalanceInventoryPre.BalanceQuantity AS BalanceInventory
		|FROM
		|	TT_BalanceInventoryPre AS TT_BalanceInventoryPre
		|
		|GROUP BY
		|	TT_BalanceInventoryPre.Company,
		|	TT_BalanceInventoryPre.PresentationCurrency,
		|	TT_BalanceInventoryPre.ProductsPresentation,
		|	TT_BalanceInventoryPre.CharacteristicPresentation,
		|	TT_BalanceInventoryPre.BatchPresentation,
		|	TT_BalanceInventoryPre.Ownership,
		|	TT_BalanceInventoryPre.InventoryAccountType,
		|	TT_BalanceInventoryPre.StructuralUnitPresentation,
		|	TT_BalanceInventoryPre.SourceDocument,
		|	TT_BalanceInventoryPre.StructuralUnitType,
		|	TT_BalanceInventoryPre.MeasurementUnitPresentation,
		|	TT_BalanceInventoryPre.Quantity,
		|	TT_BalanceInventoryPre.BalanceQuantity
		|
		|HAVING
		|	SUM(TT_BalanceInventoryPre.BalanceInventory) - TT_BalanceInventoryPre.Quantity - TT_BalanceInventoryPre.BalanceQuantity < 0";
	Else
		QueryText =
		"SELECT
		|	Inventory.Company AS Company,
		|	Inventory.PresentationCurrency AS PresentationCurrency,
		|	Inventory.Products AS Products,
		|	Inventory.Characteristic AS Characteristic,
		|	Inventory.Batch AS Batch,
		|	Inventory.Ownership AS Ownership,
		|	Inventory.InventoryAccountType AS InventoryAccountType,
		|	Inventory.StructuralUnit AS StructuralUnit,
		|	Inventory.SourceDocument AS SourceDocument,
		|	Inventory.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	Inventory.Products.MeasurementUnit AS MeasurementUnit,
		|	SUM(Inventory.Quantity) AS BalanceQuantity
		|INTO TT_Data
		|FROM
		|	AccumulationRegister.Inventory AS Inventory
		|WHERE
		|	Inventory.Return
		|	AND Inventory.SourceDocument = &Ref
		|
		|GROUP BY
		|	Inventory.Company,
		|	Inventory.PresentationCurrency,
		|	Inventory.Products,
		|	Inventory.Characteristic,
		|	Inventory.Batch,
		|	Inventory.Ownership,
		|	Inventory.InventoryAccountType,
		|	Inventory.StructuralUnit,
		|	Inventory.SourceDocument,
		|	Inventory.StructuralUnit.StructuralUnitType,
		|	Inventory.Products.MeasurementUnit
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TT_Data.SourceDocument AS SourceDocument
		|INTO ExistSourceInventory
		|FROM
		|	TT_Data AS TT_Data
		|		INNER JOIN AccumulationRegister.Inventory AS Inventory
		|		ON TT_Data.SourceDocument = Inventory.Recorder
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_Data.Company AS Company,
		|	TT_Data.PresentationCurrency AS PresentationCurrency,
		|	TT_Data.Products AS ProductsPresentation,
		|	TT_Data.Characteristic AS CharacteristicPresentation,
		|	TT_Data.Batch AS BatchPresentation,
		|	TT_Data.Ownership AS Ownership,
		|	TT_Data.InventoryAccountType AS InventoryAccountType,
		|	TT_Data.StructuralUnit AS StructuralUnitPresentation,
		|	TT_Data.SourceDocument AS SourceDocument,
		|	TT_Data.StructuralUnitType AS StructuralUnitType,
		|	TT_Data.MeasurementUnit AS MeasurementUnitPresentation,
		|	TT_Data.BalanceQuantity AS BalanceQuantity,
		|	SUM(ISNULL(Inventory.Quantity, 0)) AS QuantityBalanceInventory
		|INTO TT_BalanceInventoryPre
		|FROM
		|	TT_Data AS TT_Data
		|		INNER JOIN ExistSourceInventory AS ExistSourceInventory
		|		ON TT_Data.SourceDocument = ExistSourceInventory.SourceDocument
		|		LEFT JOIN AccumulationRegister.Inventory AS Inventory
		|		ON TT_Data.Company = Inventory.Company
		|			AND TT_Data.PresentationCurrency = Inventory.PresentationCurrency
		|			AND TT_Data.Products = Inventory.Products
		|			AND TT_Data.Characteristic = Inventory.Characteristic
		|			AND TT_Data.Batch = Inventory.Batch
		|			AND TT_Data.Ownership = Inventory.Ownership
		|			AND TT_Data.InventoryAccountType = Inventory.InventoryAccountType
		|			AND TT_Data.StructuralUnit = Inventory.StructuralUnit
		|			AND TT_Data.SourceDocument = Inventory.Recorder
		|
		|GROUP BY
		|	TT_Data.Company,
		|	TT_Data.PresentationCurrency,
		|	TT_Data.Products,
		|	TT_Data.Characteristic,
		|	TT_Data.Batch,
		|	TT_Data.Ownership,
		|	TT_Data.InventoryAccountType,
		|	TT_Data.StructuralUnit,
		|	TT_Data.SourceDocument,
		|	TT_Data.StructuralUnitType,
		|	TT_Data.MeasurementUnit,
		|	TT_Data.BalanceQuantity
		|
		|UNION ALL
		|
		|SELECT
		|	TT_Data.Company,
		|	TT_Data.PresentationCurrency,
		|	TT_Data.Products,
		|	TT_Data.Characteristic,
		|	TT_Data.Batch,
		|	TT_Data.Ownership,
		|	TT_Data.InventoryAccountType,
		|	TT_Data.StructuralUnit,
		|	TT_Data.SourceDocument,
		|	TT_Data.StructuralUnitType,
		|	TT_Data.MeasurementUnit,
		|	TT_Data.BalanceQuantity,
		|	SUM(ISNULL(Inventory.Quantity, 0))
		|FROM
		|	TT_Data AS TT_Data
		|		INNER JOIN ExistSourceInventory AS ExistSourceInventory
		|		ON TT_Data.SourceDocument = ExistSourceInventory.SourceDocument
		|		LEFT JOIN AccumulationRegister.Inventory AS Inventory
		|		ON TT_Data.Company = Inventory.Company
		|			AND TT_Data.PresentationCurrency = Inventory.PresentationCurrency
		|			AND TT_Data.Products = Inventory.Products
		|			AND TT_Data.Characteristic = Inventory.Characteristic
		|			AND TT_Data.Batch = Inventory.Batch
		|			AND TT_Data.Ownership = Inventory.Ownership
		|			AND TT_Data.InventoryAccountType = Inventory.InventoryAccountType
		|			AND TT_Data.StructuralUnit <> Inventory.StructuralUnit
		|			AND (Inventory.StructuralUnit = VALUE(Catalog.BusinessUnits.DropShipping))
		|			AND TT_Data.SourceDocument = Inventory.Recorder
		|
		|GROUP BY
		|	TT_Data.Company,
		|	TT_Data.PresentationCurrency,
		|	TT_Data.Products,
		|	TT_Data.Characteristic,
		|	TT_Data.Batch,
		|	TT_Data.Ownership,
		|	TT_Data.InventoryAccountType,
		|	TT_Data.StructuralUnit,
		|	TT_Data.SourceDocument,
		|	TT_Data.StructuralUnitType,
		|	TT_Data.MeasurementUnit,
		|	TT_Data.BalanceQuantity
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_BalanceInventoryPre.Company AS Company,
		|	TT_BalanceInventoryPre.PresentationCurrency AS PresentationCurrency,
		|	TT_BalanceInventoryPre.ProductsPresentation AS ProductsPresentation,
		|	TT_BalanceInventoryPre.CharacteristicPresentation AS CharacteristicPresentation,
		|	TT_BalanceInventoryPre.BatchPresentation AS BatchPresentation,
		|	TT_BalanceInventoryPre.Ownership AS Ownership,
		|	TT_BalanceInventoryPre.InventoryAccountType AS InventoryAccountType,
		|	TT_BalanceInventoryPre.StructuralUnitPresentation AS StructuralUnitPresentation,
		|	TT_BalanceInventoryPre.SourceDocument AS SourceDocument,
		|	TT_BalanceInventoryPre.StructuralUnitType AS StructuralUnitType,
		|	TT_BalanceInventoryPre.MeasurementUnitPresentation AS MeasurementUnitPresentation,
		|	SUM(TT_BalanceInventoryPre.QuantityBalanceInventory) - TT_BalanceInventoryPre.BalanceQuantity AS QuantityBalanceInventory,
		|	0 AS BalanceInventory
		|FROM
		|	TT_BalanceInventoryPre AS TT_BalanceInventoryPre
		|
		|GROUP BY
		|	TT_BalanceInventoryPre.Company,
		|	TT_BalanceInventoryPre.PresentationCurrency,
		|	TT_BalanceInventoryPre.ProductsPresentation,
		|	TT_BalanceInventoryPre.CharacteristicPresentation,
		|	TT_BalanceInventoryPre.BatchPresentation,
		|	TT_BalanceInventoryPre.Ownership,
		|	TT_BalanceInventoryPre.InventoryAccountType,
		|	TT_BalanceInventoryPre.StructuralUnitPresentation,
		|	TT_BalanceInventoryPre.SourceDocument,
		|	TT_BalanceInventoryPre.StructuralUnitType,
		|	TT_BalanceInventoryPre.MeasurementUnitPresentation,
		|	TT_BalanceInventoryPre.BalanceQuantity
		|
		|HAVING
		|	SUM(TT_BalanceInventoryPre.QuantityBalanceInventory) - TT_BalanceInventoryPre.BalanceQuantity < 0";
	EndIf;
	
	Return QueryText;
	
EndFunction

#EndRegion

#Region Internal

#Region InfobaseUpdate

Procedure FillCurrencyInIntraTransferRecords() Export
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	Inventory.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|		INNER JOIN Document.GoodsIssue AS GoodsIssue
	|		ON Inventory.Recorder = GoodsIssue.Ref
	|			AND (GoodsIssue.OperationType = VALUE(Enum.OperationTypesGoodsIssue.IntraCommunityTransfer))
	|			AND (Inventory.Currency = VALUE(Catalog.Currencies.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	Inventory.Recorder
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|		INNER JOIN Document.GoodsReceipt AS GoodsReceipt
	|		ON Inventory.Recorder = GoodsReceipt.Ref
	|			AND (GoodsReceipt.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer))
	|			AND (Inventory.Currency = VALUE(Catalog.Currencies.EmptyRef))";
	
	Selection = Query.Execute().Select();
	
	Query.Text =
	"SELECT
	|	Inventory.Period AS Period,
	|	Inventory.Recorder AS Recorder,
	|	Inventory.LineNumber AS LineNumber,
	|	Inventory.Active AS Active,
	|	Inventory.RecordType AS RecordType,
	|	Inventory.Company AS Company,
	|	Inventory.PresentationCurrency AS PresentationCurrency,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.Ownership AS Ownership,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.CostObject AS CostObject,
	|	Inventory.InventoryAccountType AS InventoryAccountType,
	|	Inventory.Quantity AS Quantity,
	|	Inventory.Amount AS Amount,
	|	Inventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	Inventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	Inventory.ProductsCorr AS ProductsCorr,
	|	Inventory.CharacteristicCorr AS CharacteristicCorr,
	|	Inventory.BatchCorr AS BatchCorr,
	|	Inventory.OwnershipCorr AS OwnershipCorr,
	|	Inventory.CustomerCorrOrder AS CustomerCorrOrder,
	|	Inventory.Specification AS Specification,
	|	Inventory.SpecificationCorr AS SpecificationCorr,
	|	Inventory.CorrSalesOrder AS CorrSalesOrder,
	|	Inventory.SourceDocument AS SourceDocument,
	|	Inventory.Department AS Department,
	|	Inventory.Responsible AS Responsible,
	|	Inventory.VATRate AS VATRate,
	|	Inventory.FixedCost AS FixedCost,
	|	Inventory.ProductionExpenses AS ProductionExpenses,
	|	Inventory.Return AS Return,
	|	Inventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	Inventory.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	Inventory.OfflineRecord AS OfflineRecord,
	|	Inventory.SalesRep AS SalesRep,
	|	Inventory.Counterparty AS Counterparty,
	|	CASE
	|		WHEN Inventory.Currency = VALUE(Catalog.Currencies.EmptyRef)
	|			THEN Inventory.PresentationCurrency
	|		ELSE Inventory.Currency
	|	END AS Currency,
	|	Inventory.SalesOrder AS SalesOrder,
	|	Inventory.CostObjectCorr AS CostObjectCorr,
	|	Inventory.DeleteCostObject AS DeleteCostObject,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.CorrGLAccount AS CorrGLAccount,
	|	Inventory.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	Inventory.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Recorder = &Recorder";
	
	While Selection.Next() Do
		
		Query.SetParameter("Recorder", Selection.Recorder);
		
		RecordSet = AccumulationRegisters.Inventory.CreateRecordSet();
		RecordSet.Filter.Recorder.Set(Selection.Recorder);
		RecordSet.Load(Query.Execute().Unload());
		
		Try
			
			InfobaseUpdate.WriteRecordSet(RecordSet);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Error while saving record set %1: %2.'; ru = 'Ошибка при записи набора записей %1: %2.';pl = 'Błąd podczas zapisywania zestawu wpisów %1: %2.';es_ES = 'Error al guardar el conjunto de registros %1: %2.';es_CO = 'Error al guardar el conjunto de registros %1: %2.';tr = '%1 kayıt kümesi kaydedilirken hata oluştu: %2.';it = 'Si è verificato un errore durante il salvataggio dell''insieme di registrazioni %1: %2.';de = 'Fehler beim Speichern von Satz von Einträgen %1: %2.'", DefaultLanguageCode),
				Selection.Recorder,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.AccumulationRegisters.AccountsPayable,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure FillEmptyAttributesInRecords() Export
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	GoodsIssue.Ref AS Ref,
	|	""GoodsIssue"" AS DocumentName
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|		INNER JOIN Document.GoodsIssue AS GoodsIssue
	|		ON Inventory.Recorder = GoodsIssue.Ref
	|			AND (Inventory.Counterparty = VALUE(Catalog.Counterparties.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	GoodsReceipt.Ref,
	|	""GoodsReceipt""
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|		INNER JOIN Document.GoodsReceipt AS GoodsReceipt
	|		ON Inventory.Recorder = GoodsReceipt.Ref
	|			AND (Inventory.Counterparty = VALUE(Catalog.Counterparties.EmptyRef))";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DocumentObject = Selection.Ref.GetObject();
		If DocumentObject = Undefined Then
			Continue;
		EndIf;
		
		AdditionalProperties = DocumentObject.AdditionalProperties;
		RegisterRecords = DocumentObject.RegisterRecords;
		
		BeginTransaction();
		
		DriveServer.InitializeAdditionalPropertiesForPosting(Selection.Ref, AdditionalProperties);
		Documents[Selection.DocumentName].InitializeDocumentData(Selection.Ref, AdditionalProperties);
		DriveServer.ReflectInventory(AdditionalProperties, DocumentObject.RegisterRecords, False);
		
		Try
			
			InfobaseUpdate.WriteRecordSet(RegisterRecords.Inventory);
			AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Error while saving record set %1: %2.'; ru = 'Ошибка при записи набора записей %1: %2.';pl = 'Błąd podczas zapisywania zestawu wpisów %1: %2.';es_ES = 'Error al guardar el conjunto de registros %1: %2';es_CO = 'Error al guardar el conjunto de registros %1: %2';tr = '%1 kayıt kümesi kaydedilirken hata oluştu: %2.';it = 'Si è verificato un errore durante il salvataggio dell''insieme di registrazioni %1: %2.';de = 'Fehler beim Speichern von Satz von Einträgen %1: %2.'", DefaultLanguageCode),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.AccumulationRegisters.Inventory,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure FillCorrInventoryAccountType() Export 
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	GoodsReceipt.Ref AS Recorder
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|		INNER JOIN Document.GoodsReceipt AS GoodsReceipt
	|		ON Inventory.Recorder = GoodsReceipt.Ref
	|			AND (GoodsReceipt.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty))
	|			AND (Inventory.CorrInventoryAccountType = VALUE(Enum.InventoryAccountTypes.EmptyRef))";
	
	Selection = Query.Execute().Select();
	
	Query.Text =
	"SELECT
	|	Inventory.Period AS Period,
	|	Inventory.Recorder AS Recorder,
	|	Inventory.LineNumber AS LineNumber,
	|	Inventory.Active AS Active,
	|	Inventory.RecordType AS RecordType,
	|	Inventory.Company AS Company,
	|	Inventory.PresentationCurrency AS PresentationCurrency,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.Ownership AS Ownership,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.CostObject AS CostObject,
	|	Inventory.InventoryAccountType AS InventoryAccountType,
	|	Inventory.Quantity AS Quantity,
	|	Inventory.Amount AS Amount,
	|	Inventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS CorrInventoryAccountType,
	|	Inventory.ProductsCorr AS ProductsCorr,
	|	Inventory.CharacteristicCorr AS CharacteristicCorr,
	|	Inventory.BatchCorr AS BatchCorr,
	|	Inventory.OwnershipCorr AS OwnershipCorr,
	|	Inventory.CustomerCorrOrder AS CustomerCorrOrder,
	|	Inventory.Specification AS Specification,
	|	Inventory.SpecificationCorr AS SpecificationCorr,
	|	Inventory.CorrSalesOrder AS CorrSalesOrder,
	|	Inventory.SourceDocument AS SourceDocument,
	|	Inventory.Department AS Department,
	|	Inventory.Responsible AS Responsible,
	|	Inventory.VATRate AS VATRate,
	|	Inventory.FixedCost AS FixedCost,
	|	Inventory.ProductionExpenses AS ProductionExpenses,
	|	Inventory.Return AS Return,
	|	Inventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	Inventory.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	Inventory.OfflineRecord AS OfflineRecord,
	|	Inventory.SalesRep AS SalesRep,
	|	Inventory.Counterparty AS Counterparty,
	|	Inventory.Currency AS Currency,
	|	Inventory.SalesOrder AS SalesOrder,
	|	Inventory.CostObjectCorr AS CostObjectCorr,
	|	Inventory.DeleteCostObject AS DeleteCostObject,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.CorrGLAccount AS CorrGLAccount,
	|	Inventory.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	Inventory.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Recorder = &Recorder";
	
	While Selection.Next() Do
		
		Query.SetParameter("Recorder", Selection.Recorder);
		
		RecordSetInventory = AccumulationRegisters.Inventory.CreateRecordSet();
		RecordSetInventory.Filter.Recorder.Set(Selection.Recorder);
		RecordSetInventory.Load(Query.Execute().Unload());
		
		Try
			
			InfobaseUpdate.WriteRecordSet(RecordSetInventory);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot post document ""%1"". Details: %2'; ru = 'Не удалось провести документ ""%1"". Подробнее: %2';pl = 'Nie można zatwierdzić dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al enviar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al enviar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi kaydedilemiyor. Ayrıntılar: %2';it = 'Impossibile pubblicare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Buchen des Dokuments ""%1"". Details%2'", DefaultLanguageCode),
				Selection.Recorder,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				NStr("en = 'InfobaseUpdate'; ru = 'InfobaseUpdate';pl = 'InfobaseUpdate';es_ES = 'InfobaseUpdate';es_CO = 'InfobaseUpdate';tr = 'InfobaseUpdate';it = 'InfobaseUpdate';de = 'InfobaseUpdate'", DefaultLanguageCode),
				EventLogLevel.Error,
				,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

// begin Drive.FullVersion

Procedure ClearBatchesInWIPRecords() Export
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	InventoryRecords.Recorder AS Recorder
	|INTO TT_Recorders
	|FROM
	|	AccumulationRegister.Inventory AS InventoryRecords
	|WHERE
	|	(InventoryRecords.Recorder REFS Document.Manufacturing
	|			OR InventoryRecords.Recorder REFS Document.ManufacturingOperation)
	|	AND InventoryRecords.InventoryAccountType = VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads)
	|	AND InventoryRecords.Batch <> VALUE(Catalog.ProductsBatches.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Inventory.Period AS Period,
	|	Inventory.Recorder AS Recorder,
	|	Inventory.LineNumber AS LineNumber,
	|	Inventory.Active AS Active,
	|	Inventory.RecordType AS RecordType,
	|	Inventory.Company AS Company,
	|	Inventory.PresentationCurrency AS PresentationCurrency,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	CASE
	|		WHEN Inventory.InventoryAccountType = VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads)
	|			THEN VALUE(Catalog.ProductsBatches.EmptyRef)
	|		ELSE Inventory.Batch
	|	END AS Batch,
	|	Inventory.Ownership AS Ownership,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.CostObject AS CostObject,
	|	Inventory.InventoryAccountType AS InventoryAccountType,
	|	Inventory.Quantity AS Quantity,
	|	Inventory.Amount AS Amount,
	|	Inventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	Inventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	Inventory.ProductsCorr AS ProductsCorr,
	|	Inventory.CharacteristicCorr AS CharacteristicCorr,
	|	Inventory.BatchCorr AS BatchCorr,
	|	Inventory.OwnershipCorr AS OwnershipCorr,
	|	Inventory.CustomerCorrOrder AS CustomerCorrOrder,
	|	Inventory.Specification AS Specification,
	|	Inventory.SpecificationCorr AS SpecificationCorr,
	|	Inventory.CorrSalesOrder AS CorrSalesOrder,
	|	Inventory.SourceDocument AS SourceDocument,
	|	Inventory.Department AS Department,
	|	Inventory.Responsible AS Responsible,
	|	Inventory.VATRate AS VATRate,
	|	Inventory.FixedCost AS FixedCost,
	|	Inventory.ProductionExpenses AS ProductionExpenses,
	|	Inventory.Return AS Return,
	|	Inventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	Inventory.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	Inventory.OfflineRecord AS OfflineRecord,
	|	Inventory.SalesRep AS SalesRep,
	|	Inventory.Counterparty AS Counterparty,
	|	Inventory.Currency AS Currency,
	|	Inventory.SalesOrder AS SalesOrder,
	|	Inventory.CostObjectCorr AS CostObjectCorr,
	|	Inventory.DeleteCostObject AS DeleteCostObject,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.CorrGLAccount AS CorrGLAccount,
	|	Inventory.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	Inventory.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem
	|FROM
	|	TT_Recorders AS TT_Recorders
	|		INNER JOIN AccumulationRegister.Inventory AS Inventory
	|		ON TT_Recorders.Recorder = Inventory.Recorder
	|TOTALS BY
	|	Recorder";
	
	SelectionRecorders = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While SelectionRecorders.Next() Do
		
		RecordSetInventory = AccumulationRegisters.Inventory.CreateRecordSet();
		RecordSetInventory.Filter.Recorder.Set(SelectionRecorders.Recorder);
		
		Selection = SelectionRecorders.Select();
		While Selection.Next() Do
			FillPropertyValues(RecordSetInventory.Add(), Selection);
		EndDo;
		
		Try
			
			InfobaseUpdate.WriteRecordSet(RecordSetInventory);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot post document ""%1"". Details: %2'; ru = 'Не удалось провести документ ""%1"". Подробнее: %2';pl = 'Nie można zatwierdzić dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al enviar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al enviar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi kaydedilemiyor. Ayrıntılar: %2';it = 'Impossibile pubblicare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Buchen des Dokuments ""%1"". Detai%2'", CommonClientServer.DefaultLanguageCode()),
				Selection.Recorder,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				NStr("en = 'InfobaseUpdate'; ru = 'InfobaseUpdate';pl = 'InfobaseUpdate';es_ES = 'InfobaseUpdate';es_CO = 'InfobaseUpdate';tr = 'InfobaseUpdate';it = 'InfobaseUpdate';de = 'InfobaseUpdate'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

// end Drive.FullVersion

Procedure FillSourceDocumentInSIRRecords() Export
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	InventoryRecords.Recorder AS Recorder,
	|	SubcontractorInvoiceReceived.BasisDocument AS BasisDocument
	|INTO TT_Recorders
	|FROM
	|	AccumulationRegister.Inventory AS InventoryRecords
	|		INNER JOIN Document.SubcontractorInvoiceReceived AS SubcontractorInvoiceReceived
	|		ON InventoryRecords.Recorder = SubcontractorInvoiceReceived.Ref
	|			AND (InventoryRecords.RecordType = VALUE(AccumulationRecordType.Expense))
	|			AND (InventoryRecords.SourceDocument = UNDEFINED)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Inventory.Period AS Period,
	|	Inventory.Recorder AS Recorder,
	|	Inventory.LineNumber AS LineNumber,
	|	Inventory.Active AS Active,
	|	Inventory.RecordType AS RecordType,
	|	Inventory.Company AS Company,
	|	Inventory.PresentationCurrency AS PresentationCurrency,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.InventoryAccountType AS Batch,
	|	Inventory.Ownership AS Ownership,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.CostObject AS CostObject,
	|	Inventory.InventoryAccountType AS InventoryAccountType,
	|	Inventory.Quantity AS Quantity,
	|	Inventory.Amount AS Amount,
	|	Inventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	Inventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	Inventory.ProductsCorr AS ProductsCorr,
	|	Inventory.CharacteristicCorr AS CharacteristicCorr,
	|	Inventory.BatchCorr AS BatchCorr,
	|	Inventory.OwnershipCorr AS OwnershipCorr,
	|	Inventory.CustomerCorrOrder AS CustomerCorrOrder,
	|	Inventory.Specification AS Specification,
	|	Inventory.SpecificationCorr AS SpecificationCorr,
	|	Inventory.CorrSalesOrder AS CorrSalesOrder,
	|	CASE
	|		WHEN Inventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN TT_Recorders.BasisDocument
	|		ELSE Inventory.SourceDocument
	|	END AS SourceDocument,
	|	Inventory.Department AS Department,
	|	Inventory.Responsible AS Responsible,
	|	Inventory.VATRate AS VATRate,
	|	Inventory.FixedCost AS FixedCost,
	|	Inventory.ProductionExpenses AS ProductionExpenses,
	|	Inventory.Return AS Return,
	|	Inventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	Inventory.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	Inventory.OfflineRecord AS OfflineRecord,
	|	Inventory.SalesRep AS SalesRep,
	|	Inventory.Counterparty AS Counterparty,
	|	Inventory.Currency AS Currency,
	|	Inventory.SalesOrder AS SalesOrder,
	|	Inventory.CostObjectCorr AS CostObjectCorr,
	|	Inventory.DeleteCostObject AS DeleteCostObject,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.CorrGLAccount AS CorrGLAccount,
	|	Inventory.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	Inventory.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem
	|FROM
	|	TT_Recorders AS TT_Recorders
	|		INNER JOIN AccumulationRegister.Inventory AS Inventory
	|		ON TT_Recorders.Recorder = Inventory.Recorder
	|TOTALS BY
	|	Recorder";
	
	SelectionRecorders = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While SelectionRecorders.Next() Do
		
		RecordSetInventory = AccumulationRegisters.Inventory.CreateRecordSet();
		RecordSetInventory.Filter.Recorder.Set(SelectionRecorders.Recorder);
		
		Selection = SelectionRecorders.Select();
		While Selection.Next() Do
			FillPropertyValues(RecordSetInventory.Add(), Selection);
		EndDo;
		
		Try
			
			InfobaseUpdate.WriteRecordSet(RecordSetInventory);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot post document ""%1"". Details: %2'; ru = 'Не удалось провести документ ""%1"". Подробнее: %2';pl = 'Nie można zatwierdzić dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al enviar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al enviar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi kaydedilemiyor. Ayrıntılar: %2';it = 'Impossibile pubblicare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Buchen des Dokuments ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
				Selection.Recorder,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf