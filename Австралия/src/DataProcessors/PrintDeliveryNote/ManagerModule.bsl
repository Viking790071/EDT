#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region Print

Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined) Export
	
	If TemplateName = "DeliveryNote" Then
		
		Return PrintDeliveryNote(ObjectsArray, PrintObjects, TemplateName, PrintParams);
		
	EndIf;
	
EndFunction

#EndRegion

#EndRegion

#Region Private

#Region Print

Function GetGoodsIssueQuery()
	
	Return
	"SELECT ALLOWED
	|	GoodsIssue.Ref AS Ref,
	|	GoodsIssue.Number AS Number,
	|	GoodsIssue.Date AS Date,
	|	GoodsIssue.Company AS Company,
	|	GoodsIssue.CompanyVATNumber AS CompanyVATNumber,
	|	GoodsIssue.Counterparty AS Counterparty,
	|	GoodsIssue.Contract AS Contract,
	|	CAST(GoodsIssue.Comment AS STRING(1024)) AS Comment,
	|	GoodsIssue.Order AS Order,
	|	GoodsIssue.SalesOrderPosition AS SalesOrderPosition,
	|	GoodsIssue.ContactPerson AS ContactPerson,
	|	GoodsIssue.ShippingAddress AS ShippingAddress,
	|	GoodsIssue.DeliveryOption AS DeliveryOption,
	|	GoodsIssue.StructuralUnit AS StructuralUnit
	|INTO GoodsIssues
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
	|	GoodsIssue.CompanyVATNumber AS CompanyVATNumber,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	GoodsIssue.Counterparty AS Counterparty,
	|	GoodsIssue.Contract AS Contract,
	|	CASE
	|		WHEN GoodsIssue.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN GoodsIssue.ContactPerson
	|		WHEN CounterpartyContracts.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN CounterpartyContracts.ContactPerson
	|		ELSE Counterparties.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	SalesOrder.Ref AS SalesOrder,
	|	ISNULL(SalesOrder.Number, """") AS SalesOrderNumber,
	|	ISNULL(SalesOrder.Date, DATETIME(1, 1, 1)) AS SalesOrderDate,
	|	GoodsIssue.Comment AS Comment,
	|	GoodsIssue.ShippingAddress AS ShippingAddress,
	|	GoodsIssue.DeliveryOption AS DeliveryOption,
	|	GoodsIssue.StructuralUnit AS StructuralUnit
	|INTO Header
	|FROM
	|	GoodsIssues AS GoodsIssue
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON GoodsIssue.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON GoodsIssue.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON GoodsIssue.Contract = CounterpartyContracts.Ref
	|			AND (GoodsIssue.SalesOrderPosition = VALUE(Enum.AttributeStationing.InHeader))
	|		LEFT JOIN Document.SalesOrder AS SalesOrder
	|		ON GoodsIssue.Order = SalesOrder.Ref
	|			AND (GoodsIssue.SalesOrderPosition = VALUE(Enum.AttributeStationing.InHeader))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsIssueInventory.Ref AS Ref,
	|	GoodsIssueInventory.LineNumber AS LineNumber,
	|	GoodsIssueInventory.Products AS Products,
	|	GoodsIssueInventory.Characteristic AS Characteristic,
	|	GoodsIssueInventory.Batch AS Batch,
	|	GoodsIssueInventory.Quantity AS Quantity,
	|	GoodsIssueInventory.MeasurementUnit AS MeasurementUnit,
	|	GoodsIssueInventory.Order AS Order,
	|	GoodsIssueInventory.ConnectionKey AS ConnectionKey,
	|	GoodsIssueInventory.Contract AS Contract,
	|	GoodsIssueInventory.BundleProduct AS BundleProduct,
	|	GoodsIssueInventory.BundleCharacteristic AS BundleCharacteristic
	|INTO FilteredInventory
	|FROM
	|	Document.GoodsIssue.Products AS GoodsIssueInventory
	|WHERE
	|	GoodsIssueInventory.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Counterparty AS Counterparty,
	|	ISNULL(CounterpartyContracts.Ref, Header.Contract) AS Contract,
	|	Header.CounterpartyContactPerson AS CounterpartyContactPerson,
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
	|	ISNULL(SalesOrders.Ref, Header.SalesOrder) AS SalesOrder,
	|	ISNULL(SalesOrders.Number, Header.SalesOrderNumber) AS SalesOrderNumber,
	|	ISNULL(SalesOrders.Date, Header.SalesOrderDate) AS SalesOrderDate,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.ShippingAddress AS ShippingAddress,
	|	Header.DeliveryOption AS DeliveryOption,
	|	Header.StructuralUnit AS StructuralUnit,
	|	FilteredInventory.BundleProduct AS BundleProduct,
	|	FilteredInventory.BundleCharacteristic AS BundleCharacteristic
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
	|		LEFT JOIN Document.SalesOrder AS SalesOrders
	|		ON (FilteredInventory.Order = SalesOrders.Ref)
	|			AND (Header.SalesOrderNumber = """")
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON (FilteredInventory.Contract = CounterpartyContracts.Ref)
	|
	|GROUP BY
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	Header.Ref,
	|	Header.Counterparty,
	|	Header.CompanyLogoFile,
	|	ISNULL(SalesOrders.Ref, Header.SalesOrder),
	|	ISNULL(CounterpartyContracts.Ref, Header.Contract),
	|	Header.CounterpartyContactPerson,
	|	Header.Comment,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	ISNULL(SalesOrders.Date, Header.SalesOrderDate),
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	ISNULL(SalesOrders.Number, Header.SalesOrderNumber),
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
	|	Header.ShippingAddress,
	|	Header.DeliveryOption,
	|	Header.StructuralUnit,
	|	FilteredInventory.BundleProduct,
	|	FilteredInventory.BundleCharacteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyVATNumber AS CompanyVATNumber,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Counterparty AS Counterparty,
	|	Tabular.Contract AS Contract,
	|	Tabular.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	SalesOrdersTurnovers.QuantityReceipt AS QuantityOrdered,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	FALSE AS ContentUsed,
	|	Tabular.ShippingAddress AS ShippingAddress,
	|	Tabular.DeliveryOption AS DeliveryOption,
	|	Tabular.StructuralUnit AS StructuralUnit,
	|	Tabular.BundleProduct AS BundleProduct,
	|	Tabular.BundleCharacteristic AS BundleCharacteristic
	|FROM
	|	Tabular AS Tabular
	|		LEFT JOIN AccumulationRegister.SalesOrders.Turnovers(
	|				,
	|				,
	|				,
	|				(SalesOrder, Products, Characteristic) IN
	|					(SELECT
	|						Tabular.SalesOrder,
	|						Tabular.Products,
	|						Tabular.Characteristic
	|					FROM
	|						Tabular)) AS SalesOrdersTurnovers
	|		ON Tabular.SalesOrder = SalesOrdersTurnovers.SalesOrder
	|			AND Tabular.Products = SalesOrdersTurnovers.Products
	|			AND Tabular.Characteristic = SalesOrdersTurnovers.Characteristic
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyVATNumber),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(CounterpartyContactPerson),
	|	MAX(Comment),
	|	MAX(LineNumber),
	|	SUM(Quantity),
	|	SUM(QuantityOrdered),
	|	MAX(ShippingAddress),
	|	MAX(DeliveryOption),
	|	MAX(StructuralUnit)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Tabular.Ref AS Ref,
	|	Tabular.SalesOrderNumber AS Number,
	|	Tabular.SalesOrderDate AS Date
	|FROM
	|	Tabular AS Tabular
	|WHERE
	|	Tabular.SalesOrderNumber <> """"
	|
	|ORDER BY
	|	Tabular.SalesOrderNumber
	|TOTALS BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	FilteredInventory AS FilteredInventory
	|		INNER JOIN Tabular AS Tabular
	|		ON FilteredInventory.Products = Tabular.Products
	|			AND FilteredInventory.Ref = Tabular.Ref
	|			AND FilteredInventory.Characteristic = Tabular.Characteristic
	|			AND FilteredInventory.MeasurementUnit = Tabular.MeasurementUnit
	|			AND FilteredInventory.Batch = Tabular.Batch
	|		INNER JOIN Document.GoodsIssue.SerialNumbers AS GoodsIssueSerialNumbers
	|			LEFT JOIN Catalog.SerialNumbers AS SerialNumbers
	|			ON GoodsIssueSerialNumbers.SerialNumber = SerialNumbers.Ref
	|		ON FilteredInventory.Ref = GoodsIssueSerialNumbers.Ref
	|			AND FilteredInventory.ConnectionKey = GoodsIssueSerialNumbers.ConnectionKey";

EndFunction

Function GetSalesInvoiceQuery()
	
	Return
	"SELECT ALLOWED
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Number AS Number,
	|	SalesInvoice.Date AS Date,
	|	SalesInvoice.Company AS Company,
	|	SalesInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	SalesInvoice.Counterparty AS Counterparty,
	|	SalesInvoice.Contract AS Contract,
	|	CAST(SalesInvoice.Comment AS STRING(1024)) AS Comment,
	|	SalesInvoice.Order AS Order,
	|	SalesInvoice.SalesOrderPosition AS SalesOrderPosition,
	|	SalesInvoice.ContactPerson AS ContactPerson,
	|	SalesInvoice.ShippingAddress AS ShippingAddress,
	|	SalesInvoice.DeliveryOption AS DeliveryOption,
	|	SalesInvoice.StructuralUnit AS StructuralUnit
	|INTO SalesInvoice
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref IN(&ObjectsArray)
	|	AND NOT SalesInvoice.OperationKind = VALUE(Enum.OperationTypesSalesInvoice.AdvanceInvoice)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Number AS DocumentNumber,
	|	SalesInvoice.Date AS DocumentDate,
	|	SalesInvoice.Company AS Company,
	|	SalesInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	SalesInvoice.Counterparty AS Counterparty,
	|	SalesInvoice.Contract AS Contract,
	|	CASE
	|		WHEN SalesInvoice.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN SalesInvoice.ContactPerson
	|		WHEN CounterpartyContracts.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN CounterpartyContracts.ContactPerson
	|		ELSE Counterparties.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	SalesOrder.Ref AS SalesOrder,
	|	ISNULL(SalesOrder.Number, """") AS SalesOrderNumber,
	|	ISNULL(SalesOrder.Date, DATETIME(1, 1, 1)) AS SalesOrderDate,
	|	SalesInvoice.Comment AS Comment,
	|	SalesInvoice.ShippingAddress AS ShippingAddress,
	|	SalesInvoice.DeliveryOption AS DeliveryOption,
	|	SalesInvoice.StructuralUnit AS StructuralUnit
	|INTO Header
	|FROM
	|	SalesInvoice AS SalesInvoice
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON SalesInvoice.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON SalesInvoice.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON SalesInvoice.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN Document.SalesOrder AS SalesOrder
	|		ON SalesInvoice.Order = SalesOrder.Ref
	|			AND (SalesInvoice.SalesOrderPosition = VALUE(Enum.AttributeStationing.InHeader))
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
	|	SalesInvoiceInventory.ConnectionKey AS ConnectionKey,
	|	SalesInvoiceInventory.BundleProduct AS BundleProduct,
	|	SalesInvoiceInventory.BundleCharacteristic AS BundleCharacteristic
	|INTO FilteredInventory
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|WHERE
	|	SalesInvoiceInventory.Ref IN(&ObjectsArray)
	|	AND SalesInvoiceInventory.ProductsTypeInventory
	|	AND SalesInvoiceInventory.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Counterparty AS Counterparty,
	|	Header.Contract AS Contract,
	|	Header.CounterpartyContactPerson AS CounterpartyContactPerson,
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
	|	ISNULL(SalesOrders.Ref, Header.SalesOrder) AS SalesOrder,
	|	ISNULL(SalesOrders.Number, Header.SalesOrderNumber) AS SalesOrderNumber,
	|	ISNULL(SalesOrders.Date, Header.SalesOrderDate) AS SalesOrderDate,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.ShippingAddress AS ShippingAddress,
	|	Header.DeliveryOption AS DeliveryOption,
	|	Header.StructuralUnit AS StructuralUnit,
	|	FilteredInventory.BundleProduct AS BundleProduct,
	|	FilteredInventory.BundleCharacteristic AS BundleCharacteristic
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
	|		LEFT JOIN Document.SalesOrder AS SalesOrders
	|		ON (FilteredInventory.Order = SalesOrders.Ref)
	|			AND (Header.SalesOrderNumber = """")
	|
	|GROUP BY
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	Header.Ref,
	|	Header.Counterparty,
	|	Header.CompanyLogoFile,
	|	Header.Contract,
	|	Header.CounterpartyContactPerson,
	|	Header.Comment,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	ISNULL(SalesOrders.Ref, Header.SalesOrder),
	|	ISNULL(SalesOrders.Date, Header.SalesOrderDate),
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	ISNULL(SalesOrders.Number, Header.SalesOrderNumber),
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
	|	Header.ShippingAddress,
	|	Header.DeliveryOption,
	|	Header.StructuralUnit,
	|	FilteredInventory.BundleProduct,
	|	FilteredInventory.BundleCharacteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyVATNumber AS CompanyVATNumber,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Counterparty AS Counterparty,
	|	Tabular.Contract AS Contract,
	|	Tabular.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	SalesOrdersTurnovers.QuantityReceipt AS QuantityOrdered,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	FALSE AS ContentUsed,
	|	Tabular.ShippingAddress AS ShippingAddress,
	|	Tabular.DeliveryOption AS DeliveryOption,
	|	Tabular.StructuralUnit AS StructuralUnit,
	|	Tabular.BundleProduct AS BundleProduct,
	|	Tabular.BundleCharacteristic AS BundleCharacteristic
	|FROM
	|	Tabular AS Tabular
	|		LEFT JOIN AccumulationRegister.SalesOrders.Turnovers(
	|				,
	|				,
	|				,
	|				(SalesOrder, Products, Characteristic) IN
	|					(SELECT
	|						Tabular.SalesOrder,
	|						Tabular.Products,
	|						Tabular.Characteristic
	|					FROM
	|						Tabular)) AS SalesOrdersTurnovers
	|		ON Tabular.SalesOrder = SalesOrdersTurnovers.SalesOrder
	|			AND Tabular.Products = SalesOrdersTurnovers.Products
	|			AND Tabular.Characteristic = SalesOrdersTurnovers.Characteristic
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyVATNumber),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(CounterpartyContactPerson),
	|	MAX(Comment),
	|	MAX(LineNumber),
	|	SUM(Quantity),
	|	SUM(QuantityOrdered),
	|	MAX(ShippingAddress),
	|	MAX(DeliveryOption),
	|	MAX(StructuralUnit)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Tabular.Ref AS Ref,
	|	Tabular.SalesOrderNumber AS Number,
	|	Tabular.SalesOrderDate AS Date
	|FROM
	|	Tabular AS Tabular
	|WHERE
	|	Tabular.SalesOrderNumber <> """"
	|
	|ORDER BY
	|	Tabular.SalesOrderNumber
	|TOTALS BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	FilteredInventory AS FilteredInventory
	|		INNER JOIN Tabular AS Tabular
	|		ON FilteredInventory.Products = Tabular.Products
	|			AND FilteredInventory.Ref = Tabular.Ref
	|			AND FilteredInventory.Characteristic = Tabular.Characteristic
	|			AND FilteredInventory.MeasurementUnit = Tabular.MeasurementUnit
	|			AND FilteredInventory.Batch = Tabular.Batch
	|		INNER JOIN Document.SalesInvoice.SerialNumbers AS GoodsIssueSerialNumbers
	|			LEFT JOIN Catalog.SerialNumbers AS SerialNumbers
	|			ON GoodsIssueSerialNumbers.SerialNumber = SerialNumbers.Ref
	|		ON FilteredInventory.Ref = GoodsIssueSerialNumbers.Ref
	|			AND FilteredInventory.ConnectionKey = GoodsIssueSerialNumbers.ConnectionKey";

EndFunction

Function PrintDeliveryNote(ObjectsArray, PrintObjects, TemplateName, PrintParams)
    
    DisplayPrintOption = (PrintParams <> Undefined);
    
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_DeliveryNote";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);

	Query.Text = ?(TypeOf(ObjectsArray[0]) = Type("DocumentRef.GoodsIssue"), GetGoodsIssueQuery(), GetSalesInvoiceQuery());

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
	
	Header						= ResultArray[4].Select(QueryResultIteration.ByGroupsWithHierarchy);
	SalesOrdersNumbersHeaderSel	= ResultArray[5].Select(QueryResultIteration.ByGroupsWithHierarchy);
	SerialNumbersSel			= ResultArray[6].Select();
	
	// Bundles
	TableColumns = ResultArray[4].Columns;
	// End Bundles
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_DeliveryNote";
		
		Template = PrintManagement.PrintFormTemplate("DataProcessor.PrintDeliveryNote.PF_MXL_DeliveryNote", LanguageCode);
		
		#Region PrintDeliveryNoteTitleArea
		
		TitleArea = Template.GetArea("Title");
		TitleArea.Parameters.Fill(Header);
        
        If DisplayPrintOption Then 
            TitleArea.Parameters.OriginalDuplicate = ?(PrintParams.OriginalCopy,
				NStr("en = 'ORIGINAL'; ru = 'ОРИГИНАЛ';pl = 'ORYGINAŁ';es_ES = 'ORIGINAL';es_CO = 'ORIGINAL';tr = 'ORİJİNAL';it = 'ORIGINALE';de = 'ORIGINAL'", LanguageCode),
				NStr("en = 'COPY'; ru = 'КОПИЯ';pl = 'KOPIA';es_ES = 'COPIA';es_CO = 'COPIA';tr = 'KOPYA';it = 'COPIA';de = 'KOPIE'", LanguageCode));
		EndIf;
        
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
			Header.Company, Header.DocumentDate, , , Header.CompanyVATNumber, LanguageCode);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		BarcodesInPrintForms.AddBarcodeToTableDocument(CompanyInfoArea, Header.Ref);
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		#EndRegion
		
		#Region PrintDeliveryNoteCounterpartyInfoArea
		
		CounterpartyInfoArea = Template.GetArea("CounterpartyInfo");
		CounterpartyInfoArea.Parameters.Fill(Header);
		
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Counterparty,
			Header.DocumentDate,
			,
			,
			,
			LanguageCode);
		CounterpartyInfoArea.Parameters.Fill(InfoAboutCounterparty);
		
		TitleParameters = New Structure;
		TitleParameters.Insert("TitleShipTo", NStr("en = 'Ship to'; ru = 'Грузополучатель';pl = 'Dostawa do';es_ES = 'Enviar a';es_CO = 'Enviar a';tr = 'Sevk et';it = 'Spedire a';de = 'Versand an'", LanguageCode));
		TitleParameters.Insert("TitleShipDate", NStr("en = 'Ship date'; ru = 'Дата доставки';pl = 'Data wysyłki';es_ES = 'Fecha de envío';es_CO = 'Fecha de envío';tr = 'Gönderme tarihi';it = 'Data di spedizione';de = 'Versanddatum'", LanguageCode));
		
		If Header.DeliveryOption = Enums.DeliveryOptions.SelfPickup Then
			
			InfoAboutPickupLocation	= DriveServer.InfoAboutLegalEntityIndividual(
				Header.StructuralUnit,
				Header.DocumentDate,
				,
				,
				,
				LanguageCode);
			ResponsibleEmployee		= InfoAboutPickupLocation.ResponsibleEmployee;
			
			If NOT IsBlankString(InfoAboutPickupLocation.FullDescr) Then
				CounterpartyInfoArea.Parameters.FullDescrShipTo = InfoAboutPickupLocation.FullDescr;
			EndIf;
			
			If NOT IsBlankString(InfoAboutPickupLocation.DeliveryAddress) Then
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutPickupLocation.DeliveryAddress;
			EndIf;
			
			If ValueIsFilled(ResponsibleEmployee) Then
				CounterpartyInfoArea.Parameters.CounterpartyContactPerson = ResponsibleEmployee.Description;
			EndIf;
			
			If NOT IsBlankString(InfoAboutPickupLocation.PhoneNumbers) Then
				CounterpartyInfoArea.Parameters.PhoneNumbers = InfoAboutPickupLocation.PhoneNumbers;
			EndIf;
			
			TitleParameters.TitleShipTo		= NStr("en = 'Pickup location'; ru = 'Место самовывоза';pl = 'Miejsce odbioru osobistego';es_ES = 'Ubicación de recogida';es_CO = 'Ubicación de recogida';tr = 'Toplama yeri';it = 'Punto di presa';de = 'Abholort'", LanguageCode);
			TitleParameters.TitleShipDate	= NStr("en = 'Pickup date'; ru = 'Дата самовывоза';pl = 'Data odbioru osobistego';es_ES = 'Fecha de recogida';es_CO = 'Fecha de recogida';tr = 'Toplama tarihi';it = 'Data di presa';de = 'Abholdatum'", LanguageCode);
			
		Else
			
			InfoAboutShippingAddress	= DriveServer.InfoAboutShippingAddress(Header.ShippingAddress);
			InfoAboutContactPerson		= DriveServer.InfoAboutContactPerson(Header.CounterpartyContactPerson);
		
			If NOT IsBlankString(InfoAboutShippingAddress.DeliveryAddress) Then
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutShippingAddress.DeliveryAddress;
			EndIf;
			
			If NOT IsBlankString(InfoAboutContactPerson.PhoneNumbers) Then
				CounterpartyInfoArea.Parameters.PhoneNumbers = InfoAboutContactPerson.PhoneNumbers;
			EndIf;
			
		EndIf;
		
		CounterpartyInfoArea.Parameters.Fill(TitleParameters);
		
		If IsBlankString(CounterpartyInfoArea.Parameters.DeliveryAddress) Then
			
			If Not IsBlankString(InfoAboutCounterparty.ActualAddress) Then
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutCounterparty.ActualAddress;
			Else
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutCounterparty.LegalAddress;
			EndIf;
			
		EndIf;
		
		SalesOrdersNumbersHeaderSel.Reset();
		If SalesOrdersNumbersHeaderSel.FindNext(New Structure("Ref", Header.Ref)) Then
			
			SalesOrdersNumbersArray = New Array;
			
			SalesOrdersNumbersSel = SalesOrdersNumbersHeaderSel.Select();
			While SalesOrdersNumbersSel.Next() Do
				
				SalesOrdersNumbersArray.Add(
					SalesOrdersNumbersSel.Number
					+ StringFunctionsClientServer.SubstituteParametersToString(
						" %1 ", NStr("en = 'dated'; ru = 'от';pl = 'z dn.';es_ES = 'fechado';es_CO = 'fechado';tr = 'tarihli';it = 'con data';de = 'datiert'", LanguageCode))
					+ Format(SalesOrdersNumbersSel.Date, "DLF=D"));
				
			EndDo;
			
			CounterpartyInfoArea.Parameters.SalesOrders = StringFunctionsClientServer.StringFromSubstringArray(SalesOrdersNumbersArray, ", ");
			
		EndIf;
		
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
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
		
		LineTotalArea = Template.GetArea("LineTotal");
		LineTotalArea.Parameters.Fill(Header);
		
		// Bundles
		TableInventoty = BundlesServer.AssemblyTableByBundles(Header.Ref, Header, TableColumns, LineTotalArea);
		EmptyColor = LineSectionArea.CurrentArea.TextColor;
		// End Bundles
		
		For Each TabSelection In TableInventoty Do
			
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
            
			// Bundles  
            If DisplayPrintOption And PrintParams.CodesPosition <> Enums.CodesPositionInPrintForms.SeparateColumn Then
                LineSectionArea.Areas.LineSectionWithoutCode.TextColor = BundlesServer.GetBundleComponentsColor(TabSelection, EmptyColor);
            Else
                LineSectionArea.Areas.LineSection.TextColor = BundlesServer.GetBundleComponentsColor(TabSelection, EmptyColor);
            EndIf;    
			// End Bundles
            
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
		SpreadsheetDocument.Put(LineTotalArea);
		
		AreasToBeChecked.Clear();
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
        
        #Region PrintAdditionalAttributes
		If DisplayPrintOption And PrintParams.AdditionalAttributes
			And PrintManagementServerCallDrive.HasAdditionalAttributes(Header.Ref) Then
            
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

#EndRegion

#EndRegion

#EndIf
