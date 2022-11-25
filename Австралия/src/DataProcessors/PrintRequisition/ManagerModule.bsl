#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region PrintInterface

Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined) Export
	
	If TemplateName = "Requisition" Then
		
		Return PrintRequisition(ObjectsArray, PrintObjects, TemplateName, PrintParams);
		
	EndIf;
	
EndFunction

#EndRegion

#EndRegion

#Region Private

#Region Print

Function GetSalesInvoiceQuery()
	
	Return
	"SELECT ALLOWED
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Number AS Number,
	|	SalesInvoice.Date AS Date,
	|	SalesInvoice.Company AS Company,
	|	SalesInvoice.Counterparty AS FieldTo,
	|	SalesInvoice.Contract AS Contract,
	|	CAST(SalesInvoice.Comment AS STRING(1024)) AS Comment,
	|	SalesInvoice.Order AS Order,
	|	SalesInvoice.SalesOrderPosition AS SalesOrderPosition,
	|	SalesInvoice.StructuralUnit AS FieldFrom
	|INTO SalesInvoice
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Number AS DocumentNumber,
	|	SalesInvoice.Date AS DocumentDate,
	|	SalesInvoice.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	SalesInvoice.Contract AS Contract,
	|	SalesInvoice.Comment AS Comment,
	|	SalesInvoice.FieldFrom AS FieldFrom,
	|	SalesInvoice.FieldTo AS FieldTo
	|INTO Header
	|FROM
	|	SalesInvoice AS SalesInvoice
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON SalesInvoice.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesInvoiceInventory.Ref AS Ref,
	|	SalesInvoiceInventory.LineNumber AS LineNumber,
	|	SalesInvoiceInventory.Products AS Products,
	|	SalesInvoiceInventory.Characteristic AS Characteristic,
	|	SalesInvoiceInventory.Batch AS Batch,
	|	SalesInvoiceInventory.Quantity AS Quantity,
	|	SalesInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	SalesInvoiceInventory.Order AS Order,
	|	SalesInvoiceInventory.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		ON Header.Ref = SalesInvoiceInventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Contract AS Contract,
	|	Header.Comment AS Comment,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END AS BatchDescription,
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	MIN(FilteredInventory.ConnectionKey) AS ConnectionKey,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity) AS Quantity,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.FieldFrom AS FieldFrom,
	|	Header.FieldTo AS FieldTo
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (FilteredInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (FilteredInventory.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogBatches
	|		ON (FilteredInventory.Batch = CatalogBatches.Ref)
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOMClassifier.Ref)
	|
	|GROUP BY
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.Ref,
	|	Header.CompanyLogoFile,
	|	Header.Contract,
	|	Header.Comment,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	Header.FieldFrom,
	|	Header.FieldTo
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Contract AS Contract,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	FALSE AS ContentUsed,
	|	Tabular.FieldFrom AS FieldFrom,
	|	Tabular.FieldTo AS FieldTo
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Contract),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	MAX(FieldFrom),
	|	MAX(FieldTo)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	Tabular AS Tabular
	|		INNER JOIN Document.SalesInvoice.SerialNumbers AS SalesInvoiceSerialNumbers
	|		ON Tabular.Ref = SalesInvoiceSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = SalesInvoiceSerialNumbers.ConnectionKey
	|		INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON SalesInvoiceSerialNumbers.SerialNumber = SerialNumbers.Ref";

EndFunction

Function GetInventoryTransferQuery()
	
	Return
	"SELECT ALLOWED
	|	InventoryTransfer.Ref AS Ref,
	|	InventoryTransfer.Number AS Number,
	|	InventoryTransfer.Date AS Date,
	|	InventoryTransfer.Company AS Company,
	|	InventoryTransfer.StructuralUnit AS FieldFrom,
	|	InventoryTransfer.StructuralUnitPayee AS Contract,
	|	CAST(InventoryTransfer.Comment AS STRING(1024)) AS Comment,
	|	InventoryTransfer.SalesOrderPosition AS SalesOrderPosition,
	|	InventoryTransfer.StructuralUnitPayee AS FieldTo
	|INTO InventoryTransfer
	|FROM
	|	Document.InventoryTransfer AS InventoryTransfer
	|WHERE
	|	InventoryTransfer.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	InventoryTransfer.Ref AS Ref,
	|	InventoryTransfer.Number AS DocumentNumber,
	|	InventoryTransfer.Date AS DocumentDate,
	|	InventoryTransfer.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	InventoryTransfer.Contract AS Contract,
	|	InventoryTransfer.Comment AS Comment,
	|	InventoryTransfer.FieldTo AS FieldTo,
	|	InventoryTransfer.FieldFrom AS FieldFrom
	|INTO Header
	|FROM
	|	InventoryTransfer AS InventoryTransfer
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON InventoryTransfer.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	InventoryTransferInventory.Ref AS Ref,
	|	InventoryTransferInventory.LineNumber AS LineNumber,
	|	InventoryTransferInventory.Products AS Products,
	|	InventoryTransferInventory.Characteristic AS Characteristic,
	|	InventoryTransferInventory.Batch AS Batch,
	|	InventoryTransferInventory.Quantity AS Quantity,
	|	InventoryTransferInventory.MeasurementUnit AS MeasurementUnit,
	|	InventoryTransferInventory.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.InventoryTransfer.Inventory AS InventoryTransferInventory
	|		ON Header.Ref = InventoryTransferInventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Contract AS Contract,
	|	Header.Comment AS Comment,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END AS BatchDescription,
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	MIN(FilteredInventory.ConnectionKey) AS ConnectionKey,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity) AS Quantity,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.FieldTo AS FieldTo,
	|	Header.FieldFrom AS FieldFrom
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (FilteredInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (FilteredInventory.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogBatches
	|		ON (FilteredInventory.Batch = CatalogBatches.Ref)
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOMClassifier.Ref)
	|
	|GROUP BY
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.Ref,
	|	Header.CompanyLogoFile,
	|	Header.Contract,
	|	Header.Comment,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	Header.FieldTo,
	|	Header.FieldFrom
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Contract AS Contract,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	FALSE AS ContentUsed,
	|	Tabular.FieldTo AS FieldTo,
	|	Tabular.FieldFrom AS FieldFrom
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Contract),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	MAX(FieldTo),
	|	MAX(FieldFrom)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	Tabular AS Tabular
	|		INNER JOIN Document.InventoryTransfer.SerialNumbers AS InventoryTransferSerialNumbers
	|		ON Tabular.Ref = InventoryTransferSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = InventoryTransferSerialNumbers.ConnectionKey
	|		INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON (InventoryTransferSerialNumbers.SerialNumber = SerialNumbers.Ref)";

EndFunction

Function GetDebitNoteQuery()
	
	Return
	"SELECT ALLOWED
	|	DebitNote.Ref AS Ref,
	|	DebitNote.Number AS Number,
	|	DebitNote.Date AS Date,
	|	DebitNote.Company AS Company,
	|	CAST(DebitNote.Comment AS STRING(1024)) AS Comment,
	|	DebitNote.StructuralUnit AS FieldFrom,
	|	DebitNote.Counterparty AS FieldTo
	|INTO DebitNote
	|FROM
	|	Document.DebitNote AS DebitNote
	|WHERE
	|	DebitNote.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DebitNote.Ref AS Ref,
	|	DebitNote.Number AS DocumentNumber,
	|	DebitNote.Date AS DocumentDate,
	|	DebitNote.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	DebitNote.Comment AS Comment,
	|	DebitNote.FieldFrom AS FieldFrom,
	|	DebitNote.FieldTo AS FieldTo
	|INTO Header
	|FROM
	|	DebitNote AS DebitNote
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON DebitNote.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DebitNoteInventory.Ref AS Ref,
	|	DebitNoteInventory.LineNumber AS LineNumber,
	|	DebitNoteInventory.Products AS Products,
	|	DebitNoteInventory.Characteristic AS Characteristic,
	|	DebitNoteInventory.Batch AS Batch,
	|	DebitNoteInventory.Quantity AS Quantity,
	|	DebitNoteInventory.MeasurementUnit AS MeasurementUnit,
	|	DebitNoteInventory.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	DebitNote AS DebitNote
	|		INNER JOIN Document.DebitNote.Inventory AS DebitNoteInventory
	|		ON DebitNote.Ref = DebitNoteInventory.Ref
	|WHERE
	|	DebitNoteInventory.Quantity > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Comment AS Comment,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END AS BatchDescription,
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	MIN(FilteredInventory.ConnectionKey) AS ConnectionKey,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity) AS Quantity,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.FieldFrom AS FieldFrom,
	|	Header.FieldTo AS FieldTo
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (FilteredInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (FilteredInventory.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogBatches
	|		ON (FilteredInventory.Batch = CatalogBatches.Ref)
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOMClassifier.Ref)
	|
	|GROUP BY
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.Ref,
	|	Header.CompanyLogoFile,
	|	Header.Comment,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	Header.FieldFrom,
	|	Header.FieldTo
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	FALSE AS ContentUsed,
	|	Tabular.FieldFrom AS FieldFrom,
	|	Tabular.FieldTo AS FieldTo
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	MAX(FieldFrom),
	|	MAX(FieldTo)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	Tabular AS Tabular
	|		INNER JOIN Document.DebitNote.SerialNumbers AS DebitNoteSerialNumbers
	|		ON Tabular.Ref = DebitNoteSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = DebitNoteSerialNumbers.ConnectionKey
	|		INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON (DebitNoteSerialNumbers.SerialNumber = SerialNumbers.Ref)";

EndFunction

Function GetGoodsIssueQuery()
	
	Return
	"SELECT ALLOWED
	|	GoodsIssue.Ref AS Ref,
	|	GoodsIssue.Number AS Number,
	|	GoodsIssue.Date AS Date,
	|	GoodsIssue.Company AS Company,
	|	CAST(GoodsIssue.Comment AS STRING(1024)) AS Comment,
	|	GoodsIssue.StructuralUnit AS FieldFrom,
	|	GoodsIssue.Counterparty AS FieldTo
	|INTO GoodsIssue
	|FROM
	|	Document.GoodsIssue AS GoodsIssue
	|WHERE
	|	GoodsIssue.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsIssue.Ref AS Ref,
	|	GoodsIssue.Number AS DocumentNumber,
	|	GoodsIssue.Date AS DocumentDate,
	|	GoodsIssue.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	GoodsIssue.Comment AS Comment,
	|	GoodsIssue.FieldFrom AS FieldFrom,
	|	GoodsIssue.FieldTo AS FieldTo
	|INTO Header
	|FROM
	|	GoodsIssue AS GoodsIssue
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON GoodsIssue.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsIssueProducts.Ref AS Ref,
	|	GoodsIssueProducts.LineNumber AS LineNumber,
	|	GoodsIssueProducts.Products AS Products,
	|	GoodsIssueProducts.Characteristic AS Characteristic,
	|	GoodsIssueProducts.Batch AS Batch,
	|	GoodsIssueProducts.Quantity AS Quantity,
	|	GoodsIssueProducts.MeasurementUnit AS MeasurementUnit,
	|	GoodsIssueProducts.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	GoodsIssue AS GoodsIssue
	|		INNER JOIN Document.GoodsIssue.Products AS GoodsIssueProducts
	|		ON GoodsIssue.Ref = GoodsIssueProducts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Comment AS Comment,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END AS BatchDescription,
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	MIN(FilteredInventory.ConnectionKey) AS ConnectionKey,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity) AS Quantity,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.FieldFrom AS FieldFrom,
	|	Header.FieldTo AS FieldTo
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (FilteredInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (FilteredInventory.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogBatches
	|		ON (FilteredInventory.Batch = CatalogBatches.Ref)
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOMClassifier.Ref)
	|
	|GROUP BY
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.Ref,
	|	Header.CompanyLogoFile,
	|	Header.Comment,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	Header.FieldFrom,
	|	Header.FieldTo
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	FALSE AS ContentUsed,
	|	Tabular.FieldFrom AS FieldFrom,
	|	Tabular.FieldTo AS FieldTo
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	MAX(FieldFrom),
	|	MAX(FieldTo)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	Tabular AS Tabular
	|		INNER JOIN Document.GoodsIssue.SerialNumbers AS GoodsIssueSerialNumbers
	|		ON Tabular.Ref = GoodsIssueSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = GoodsIssueSerialNumbers.ConnectionKey
	|		INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON (GoodsIssueSerialNumbers.SerialNumber = SerialNumbers.Ref)";

EndFunction

Function GetWorkOrderQuery()
	
	Return
	"SELECT ALLOWED
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Number AS Number,
	|	SalesOrder.Date AS Date,
	|	SalesOrder.Company AS Company,
	|	CAST(SalesOrder.Comment AS STRING(1024)) AS Comment,
	|	SalesOrder.StructuralUnitReserve AS FieldFrom,
	|	SalesOrder.Counterparty AS FieldTo
	|INTO WorkOrder
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	WorkOrder.Ref AS Ref,
	|	WorkOrder.Number AS DocumentNumber,
	|	WorkOrder.Date AS DocumentDate,
	|	WorkOrder.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	WorkOrder.Comment AS Comment,
	|	WorkOrder.FieldFrom AS FieldFrom,
	|	WorkOrder.FieldTo AS FieldTo
	|INTO Header
	|FROM
	|	WorkOrder AS WorkOrder
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON WorkOrder.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrderMaterials.Ref AS Ref,
	|	SalesOrderMaterials.LineNumber AS LineNumber,
	|	SalesOrderMaterials.Products AS Products,
	|	SalesOrderMaterials.Characteristic AS Characteristic,
	|	SalesOrderMaterials.Batch AS Batch,
	|	SalesOrderMaterials.Quantity AS Quantity,
	|	SalesOrderMaterials.MeasurementUnit AS MeasurementUnit,
	|	SalesOrderMaterials.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	WorkOrder AS WorkOrder
	|		INNER JOIN Document.SalesOrder.Materials AS SalesOrderMaterials
	|		ON WorkOrder.Ref = SalesOrderMaterials.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	SalesOrderInventory.Ref,
	|	SalesOrderInventory.LineNumber,
	|	SalesOrderInventory.Products,
	|	SalesOrderInventory.Characteristic,
	|	SalesOrderInventory.Batch,
	|	SalesOrderInventory.Quantity,
	|	SalesOrderInventory.MeasurementUnit,
	|	SalesOrderInventory.ConnectionKey
	|FROM
	|	WorkOrder AS WorkOrder
	|		INNER JOIN Document.SalesOrder.Inventory AS SalesOrderInventory
	|		ON WorkOrder.Ref = SalesOrderInventory.Ref
	|WHERE
	|	SalesOrderInventory.ProductsTypeInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Comment AS Comment,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END AS BatchDescription,
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	MIN(FilteredInventory.ConnectionKey) AS ConnectionKey,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity) AS Quantity,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.FieldFrom AS FieldFrom,
	|	Header.FieldTo AS FieldTo
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (FilteredInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (FilteredInventory.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogBatches
	|		ON (FilteredInventory.Batch = CatalogBatches.Ref)
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOMClassifier.Ref)
	|
	|GROUP BY
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.Ref,
	|	Header.CompanyLogoFile,
	|	Header.Comment,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	Header.FieldFrom,
	|	Header.FieldTo
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	FALSE AS ContentUsed,
	|	Tabular.FieldFrom AS FieldFrom,
	|	Tabular.FieldTo AS FieldTo
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	MAX(FieldFrom),
	|	MAX(FieldTo)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	Tabular AS Tabular
	|		INNER JOIN Document.SalesOrder.SerialNumbers AS SalesOrderSerialNumbers
	|			INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|			ON SalesOrderSerialNumbers.SerialNumber = SerialNumbers.Ref
	|		ON Tabular.Ref = SalesOrderSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = SalesOrderSerialNumbers.ConnectionKey
	|
	|UNION ALL
	|
	|SELECT
	|	Tabular.ConnectionKey,
	|	Tabular.Ref,
	|	SerialNumbers.Description
	|FROM
	|	Tabular AS Tabular
	|		INNER JOIN Document.SalesOrder.SerialNumbersMaterials AS SalesOrderSerialNumbersMaterials
	|		ON Tabular.Ref = SalesOrderSerialNumbersMaterials.Ref
	|			AND Tabular.ConnectionKey = SalesOrderSerialNumbersMaterials.ConnectionKey
	|		INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON (SalesOrderSerialNumbersMaterials.SerialNumber = SerialNumbers.Ref)";

EndFunction

Function GetInventoryWriteOffQuery()
	
	Return
	"SELECT ALLOWED
	|	InventoryWriteOff.Ref AS Ref,
	|	InventoryWriteOff.Number AS Number,
	|	InventoryWriteOff.Date AS Date,
	|	InventoryWriteOff.Company AS Company,
	|	CAST(InventoryWriteOff.Comment AS STRING(1024)) AS Comment,
	|	InventoryWriteOff.Correspondence AS FieldTo,
	|	InventoryWriteOff.StructuralUnit AS FieldFrom
	|INTO InventoryWriteOff
	|FROM
	|	Document.InventoryWriteOff AS InventoryWriteOff
	|WHERE
	|	InventoryWriteOff.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	InventoryWriteOff.Ref AS Ref,
	|	InventoryWriteOff.Number AS DocumentNumber,
	|	InventoryWriteOff.Date AS DocumentDate,
	|	InventoryWriteOff.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	InventoryWriteOff.Comment AS Comment,
	|	InventoryWriteOff.FieldTo AS FieldTo,
	|	InventoryWriteOff.FieldFrom AS FieldFrom
	|INTO Header
	|FROM
	|	InventoryWriteOff AS InventoryWriteOff
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON InventoryWriteOff.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	InventoryWriteOffInventory.Ref AS Ref,
	|	InventoryWriteOffInventory.LineNumber AS LineNumber,
	|	InventoryWriteOffInventory.Products AS Products,
	|	InventoryWriteOffInventory.Characteristic AS Characteristic,
	|	InventoryWriteOffInventory.Batch AS Batch,
	|	InventoryWriteOffInventory.Quantity AS Quantity,
	|	InventoryWriteOffInventory.MeasurementUnit AS MeasurementUnit,
	|	InventoryWriteOffInventory.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	InventoryWriteOff AS InventoryWriteOff
	|		INNER JOIN Document.InventoryWriteOff.Inventory AS InventoryWriteOffInventory
	|		ON InventoryWriteOff.Ref = InventoryWriteOffInventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Comment AS Comment,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END AS BatchDescription,
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	MIN(FilteredInventory.ConnectionKey) AS ConnectionKey,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity) AS Quantity,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.FieldTo AS FieldTo,
	|	Header.FieldFrom AS FieldFrom
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (FilteredInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (FilteredInventory.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogBatches
	|		ON (FilteredInventory.Batch = CatalogBatches.Ref)
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOMClassifier.Ref)
	|
	|GROUP BY
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.Ref,
	|	Header.CompanyLogoFile,
	|	Header.Comment,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	Header.FieldTo,
	|	Header.FieldFrom
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	FALSE AS ContentUsed,
	|	Tabular.FieldTo AS FieldTo,
	|	Tabular.FieldFrom AS FieldFrom
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	MAX(FieldTo),
	|	MAX(FieldFrom)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	Tabular AS Tabular
	|		INNER JOIN Document.InventoryWriteOff.SerialNumbers AS InventoryWriteOffSerialNumbers
	|		ON Tabular.Ref = InventoryWriteOffSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = InventoryWriteOffSerialNumbers.ConnectionKey
	|		INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON (InventoryWriteOffSerialNumbers.SerialNumber = SerialNumbers.Ref)";

EndFunction

Function PrintRequisition(ObjectsArray, PrintObjects, TemplateName, PrintParams)
	
    DisplayPrintOption = (PrintParams <> Undefined);
    
    SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_Requisition";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	IsInventoryWriteOff = False;
	
	If TypeOf(ObjectsArray[0]) = Type("DocumentRef.GoodsIssue") Then
		Query.Text = GetGoodsIssueQuery();
	ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.SalesInvoice") Then
		Query.Text = GetSalesInvoiceQuery();
	ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.InventoryTransfer") Then
		Query.Text = GetInventoryTransferQuery();
	ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.DebitNote") Then
		Query.Text = GetDebitNoteQuery();
	ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.InventoryWriteOff") Then
		Query.Text = GetInventoryWriteOffQuery();
		IsInventoryWriteOff = True;
	ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.SalesOrder") Then
		Query.Text = GetWorkOrderQuery();
	EndIf;
	
	// MultilingualSupport
	
	If PrintParams = Undefined Then
		LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
	Else
		LanguageCode = PrintParams.LanguageCode;
	EndIf;
	
	If LanguageCode <> CurrentLanguage().LanguageCode Then 
		SessionParameters.LanguageCodeForOutput = LanguageCode;
	EndIf;
	
	DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
	
	// End MultilingualSupport
	
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	
	Header = ResultArray[4].Select(QueryResultIteration.ByGroupsWithHierarchy);
	
	SerialNumbersSel = ResultArray[5].Select();
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_Requisition";
		
		Template = PrintManagement.PrintFormTemplate("DataProcessor.PrintRequisition.PF_MXL_Requisition", LanguageCode);
		
		#Region PrintDeliveryNoteTitleArea
		
		TitleArea = Template.GetArea("Title");
		TitleArea.Parameters.Fill(Header);
		
		DocumentMetadata = Header.Ref.Metadata();
		DocumentType = DocumentMetadata.ExtendedObjectPresentation;
		If IsBlankString(DocumentType) Then
			DocumentType = DocumentMetadata.ObjectPresentation;
		EndIf;
		If IsBlankString(DocumentType) Then
			DocumentType = DocumentMetadata.Presentation();
		EndIf;
		TitleArea.Parameters.DocumentType = DocumentType;
		
		If ValueIsFilled(Header.CompanyLogoFile) Then
			
			PictureData = AttachedFiles.GetBinaryFileData(Header.CompanyLogoFile);
			If ValueIsFilled(PictureData) Then
				TitleArea.Drawings.Logo.Picture = New Picture(PictureData);
			EndIf;
			
		Else
			TitleArea.Drawings.Delete(TitleArea.Drawings.Logo);
		EndIf;
		
		SpreadsheetDocument.Put(TitleArea);
		
		#EndRegion
		
		#Region PrintDeliveryNoteCompanyInfoArea
		
		CompanyInfoArea = Template.GetArea("CompanyInfo");
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Company,
			Header.DocumentDate,
			,
			,
			,
			LanguageCode);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		BarcodesInPrintForms.AddBarcodeToTableDocument(CompanyInfoArea, Header.Ref);
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		#EndRegion
		
		#Region PrintDeliveryNoteFromToInfoArea
		
		FromToInfoArea = Template.GetArea("FromTo");
		FromToInfoArea.Parameters.FullDescrFrom = GetFullDescription(Header.FieldFrom, Header.DocumentDate);
		If IsInventoryWriteOff Then
			FromToInfoArea.Parameters.FullDescrTo = Header.FieldTo;
		Else
			FromToInfoArea.Parameters.FullDescrTo = GetFullDescription(Header.FieldTo, Header.DocumentDate);
		EndIf;
		SpreadsheetDocument.Put(FromToInfoArea);
		
		#EndRegion
		
		#Region PrintDeliveryNoteCommentArea
		
		CommentArea = Template.GetArea("Comment");
		CommentArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(CommentArea);
		
		#EndRegion
		
		#Region PrintDeliveryNoteLinesArea
        If DisplayPrintOption And PrintParams.CodesPosition <> Enums.CodesPositionInPrintForms.SeparateColumn Then
    		LineHeaderArea = Template.GetArea("LineHeaderWithoutCode");
    		LineSectionArea	= Template.GetArea("LineSectionWithoutCode");
        Else    
    		LineHeaderArea = Template.GetArea("LineHeader");
    		LineSectionArea	= Template.GetArea("LineSection");
        EndIf;
        
        SpreadsheetDocument.Put(LineHeaderArea);
		
		SeeNextPageArea	= Template.GetArea("SeeNextPage");
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= Template.GetArea("PageNumber");
		
		PageNumber = 0;
		
		TabSelection = Header.Select();
		While TabSelection.Next() Do
			
			LineSectionArea.Parameters.Fill(TabSelection);
			
			DriveClientServer.ComplimentProductDescription(LineSectionArea.Parameters.ProductDescription, TabSelection, SerialNumbersSel);
            
            // Display selected codes if functional option is turned on.
            If DisplayPrintOption Then
                CodesPresentation = PrintManagementServerCallDrive.GetCodesPresentation(PrintParams, TabSelection.Products);
                If PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.SeparateColumn Then
                    LineSectionArea.Parameters.SKU = CodesPresentation;
                ElsIf PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.ProductColumn Then
                    LineSectionArea.Parameters.ProductDescription = LineSectionArea.Parameters.ProductDescription + Chars.CR + CodesPresentation;                    
                EndIf;
            EndIf;    
            
			AreasToBeChecked = New Array;
			AreasToBeChecked.Add(LineSectionArea);
			AreasToBeChecked.Add(PageNumberArea);
			
			If Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
				SpreadsheetDocument.Put(LineSectionArea);
			Else
				
				SpreadsheetDocument.Put(SeeNextPageArea);
				
				AreasToBeChecked.Clear();
				AreasToBeChecked.Add(EmptyLineArea);
				AreasToBeChecked.Add(PageNumberArea);
				
				For i = 1 To 50 Do
					
					If Not Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
						Or i = 50 Then
						
						PageNumber = PageNumber + 1;
						PageNumberArea.Parameters.PageNumber = PageNumber;
						SpreadsheetDocument.Put(PageNumberArea);
						Break;
						
					Else
						SpreadsheetDocument.Put(EmptyLineArea);
					EndIf;
					
				EndDo;
				
				SpreadsheetDocument.PutHorizontalPageBreak();
				SpreadsheetDocument.Put(TitleArea);
				SpreadsheetDocument.Put(LineHeaderArea);
				SpreadsheetDocument.Put(LineSectionArea);
				
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		#Region PrintDeliveryNoteTotalsArea
		
		LineTotalArea = Template.GetArea("LineTotal");
		LineTotalArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(LineTotalArea);
        
        #Region PrintAdditionalAttributes
        If DisplayPrintOption And PrintParams.AdditionalAttributes And PrintManagementServerCallDrive.HasAdditionalAttributes(Header.Ref) Then
            
            SpreadsheetDocument.Put(EmptyLineArea);
            
            AddAttribHeader = Template.GetArea("AdditionalAttributesStaticHeader");
            SpreadsheetDocument.Put(AddAttribHeader);
            
            SpreadsheetDocument.Put(EmptyLineArea);
            
            AddAttribHeader = Template.GetArea("AdditionalAttributesHeader");
            SpreadsheetDocument.Put(AddAttribHeader);
            
            AddAttribRow = Template.GetArea("AdditionalAttributesRow");
            
            For each Attr In Header.Ref.AdditionalAttributes Do
                AddAttribRow.Parameters.AddAttributeName = Attr.Property.Title;
                AddAttribRow.Parameters.AddAttributeValue = Attr.Value;
                SpreadsheetDocument.Put(AddAttribRow);                
            EndDo;                
        EndIf;    
        #EndRegion
        
        
		AreasToBeChecked.Clear();
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
		
		For i = 1 To 50 Do
			
			If Not Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
				Or i = 50 Then
				
				PageNumber = PageNumber + 1;
				PageNumberArea.Parameters.PageNumber = PageNumber;
				SpreadsheetDocument.Put(PageNumberArea);
				Break;
				
			Else
				SpreadsheetDocument.Put(EmptyLineArea);
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

Function GetFullDescription(Field, DocumentDate)
	Return DriveServer.InfoAboutLegalEntityIndividual(Field, DocumentDate).FullDescr;
EndFunction

#EndRegion

#EndRegion

#EndIf