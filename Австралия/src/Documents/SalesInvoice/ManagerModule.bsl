#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure FillBySalesOrders(DocumentData, FilterData, Inventory, SerialNumbers = Undefined) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	PackingSlip.Ref AS Ref,
	|	PackingSlip.PointInTime AS PointInTime
	|INTO PackingSlip
	|FROM
	|	Document.PackingSlip AS PackingSlip
	|WHERE
	|	PackingSlip.Ref = &PackingSlip
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PackingSlipInventory.Ref AS Ref,
	|	PackingSlipInventory.SalesOrder AS SalesOrder,
	|	MIN(PackingSlipInventory.LineNumber) AS LineNumber,
	|	PackingSlipInventory.Products AS Products,
	|	PackingSlipInventory.Characteristic AS Characteristic,
	|	PackingSlipInventory.Batch AS Batch,
	|	PackingSlipInventory.SerialNumbers AS SerialNumbers,
	|	PackingSlipInventory.MeasurementUnit AS MeasurementUnit,
	|	SUM(PackingSlipInventory.Quantity) AS Quantity,
	|	PackingSlip.PointInTime AS PointInTime,
	|	PackingSlipInventory.ConnectionKey AS ConnectionKey
	|INTO PackingSlipInventory
	|FROM
	|	PackingSlip AS PackingSlip
	|		INNER JOIN Document.PackingSlip.Inventory AS PackingSlipInventory
	|		ON PackingSlip.Ref = PackingSlipInventory.Ref
	|			AND (&PackingSlipConditions)
	|
	|GROUP BY
	|	PackingSlipInventory.Products,
	|	PackingSlipInventory.SerialNumbers,
	|	PackingSlipInventory.Ref,
	|	PackingSlipInventory.Batch,
	|	PackingSlipInventory.SalesOrder,
	|	PackingSlipInventory.MeasurementUnit,
	|	PackingSlipInventory.Characteristic,
	|	PackingSlip.PointInTime,
	|	PackingSlipInventory.ConnectionKey
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.SalesRep AS SalesRep
	|INTO TT_SalesOrders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	&SalesOrdersConditions
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	PackingSlipInventory.SalesOrder,
	|	VALUE(Catalog.Employees.EmptyRef)
	|FROM
	|	PackingSlipInventory AS PackingSlipInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesInvoiceInventory.Order AS Order,
	|	SalesInvoiceInventory.Products AS Products,
	|	SalesInvoiceInventory.Characteristic AS Characteristic,
	|	SalesInvoiceInventory.Batch AS Batch,
	|	SUM(SalesInvoiceInventory.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyInvoiced
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON SalesInvoiceInventory.Order = TT_SalesOrders.Ref
	|		INNER JOIN Document.SalesInvoice AS SalesInvoiceDocument
	|		ON SalesInvoiceInventory.Ref = SalesInvoiceDocument.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SalesInvoiceInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesInvoiceInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	SalesInvoiceDocument.Posted
	|	AND SalesInvoiceInventory.Ref <> &Ref
	|
	|GROUP BY
	|	SalesInvoiceInventory.Batch,
	|	SalesInvoiceInventory.Order,
	|	SalesInvoiceInventory.Products,
	|	SalesInvoiceInventory.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OrdersBalance.SalesOrder AS SalesOrder,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|INTO TT_OrdersBalances
	|FROM
	|	(SELECT
	|		OrdersBalance.SalesOrder AS SalesOrder,
	|		OrdersBalance.Products AS Products,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.SalesOrders.Balance(
	|				,
	|				SalesOrder IN
	|					(SELECT
	|						TT_SalesOrders.Ref
	|					FROM
	|						TT_SalesOrders)) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsSalesOrders.SalesOrder,
	|		DocumentRegisterRecordsSalesOrders.Products,
	|		DocumentRegisterRecordsSalesOrders.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsSalesOrders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsSalesOrders.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsSalesOrders.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.SalesOrders AS DocumentRegisterRecordsSalesOrders
	|	WHERE
	|		DocumentRegisterRecordsSalesOrders.Recorder = &Ref) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.SalesOrder,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ProductsTypeInventory,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.Batch AS Batch,
	|	SalesOrderInventory.Quantity AS Quantity,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	SalesOrderInventory.Price AS Price,
	|	SalesOrderInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SalesOrderInventory.Amount AS Amount,
	|	SalesOrderInventory.VATRate AS VATRate,
	|	SalesOrderInventory.VATAmount AS VATAmount,
	|	SalesOrderInventory.Total AS Total,
	|	SalesOrderInventory.Ref AS Order,
	|	SalesOrderInventory.Content AS Content,
	|	SalesOrderInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	SalesOrderInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	SalesOrderInventory.SerialNumbers AS SerialNumbers,
	|	SalesOrderInventory.Ref.PointInTime AS PointInTime,
	|	SalesOrderInventory.Specification AS Specification,
	|	SalesOrderInventory.BundleProduct AS BundleProduct,
	|	SalesOrderInventory.BundleCharacteristic AS BundleCharacteristic,
	|	SalesOrderInventory.CostShare AS CostShare,
	|	TT_SalesOrders.SalesRep AS SalesRep,
	|	VALUE(Document.PackingSlip.EmptyRef) AS PackingSlip,
	|	ProductsCatalog.UseSerialNumbers AS UseSerialNumbers,
	|	SalesOrderInventory.ConnectionKey AS ConnectionKey,
	|	SalesOrderInventory.Taxable AS Taxable,
	|	SalesOrderInventory.Project AS Project,
	|	SalesOrderInventory.DropShipping AS DropShipping
	|INTO TT_Inventory
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON SalesOrderInventory.Ref = TT_SalesOrders.Ref
	|			AND (&PackingSlip = VALUE(Document.PackingSlip.EmptyRef))
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SalesOrderInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesOrderInventory.MeasurementUnit = UOM.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	PackingSlipInventory.LineNumber,
	|	PackingSlipInventory.Products,
	|	PackingSlipInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem),
	|	PackingSlipInventory.Characteristic,
	|	PackingSlipInventory.Batch,
	|	PackingSlipInventory.Quantity,
	|	PackingSlipInventory.MeasurementUnit,
	|	ISNULL(UOM.Factor, 1),
	|	ISNULL(SalesOrderInventory.Price, 0),
	|	ISNULL(SalesOrderInventory.DiscountMarkupPercent, 0),
	|	CASE
	|		WHEN ISNULL(SalesOrderInventory.Quantity, 0) = 0
	|			THEN 0
	|		ELSE (CAST(ISNULL(SalesOrderInventory.Amount, 0) / SalesOrderInventory.Quantity AS NUMBER(15, 2))) * PackingSlipInventory.Quantity
	|	END,
	|	ISNULL(SalesOrderInventory.VATRate, VALUE(Catalog.VATRates.EmptyRef)),
	|	CASE
	|		WHEN ISNULL(SalesOrderInventory.Quantity, 0) = 0
	|			THEN 0
	|		ELSE (CAST(ISNULL(SalesOrderInventory.VATAmount, 0) / SalesOrderInventory.Quantity AS NUMBER(15, 2))) * PackingSlipInventory.Quantity
	|	END,
	|	CASE
	|		WHEN ISNULL(SalesOrderInventory.Quantity, 0) = 0
	|			THEN 0
	|		ELSE (CAST(ISNULL(SalesOrderInventory.Total, 0) / SalesOrderInventory.Quantity AS NUMBER(15, 2))) * PackingSlipInventory.Quantity
	|	END,
	|	PackingSlipInventory.SalesOrder,
	|	ISNULL(SalesOrderInventory.Content, """"),
	|	ISNULL(SalesOrderInventory.AutomaticDiscountsPercent, 0),
	|	CASE
	|		WHEN ISNULL(SalesOrderInventory.Quantity, 0) = 0
	|			THEN 0
	|		ELSE (CAST(ISNULL(SalesOrderInventory.AutomaticDiscountAmount, 0) / SalesOrderInventory.Quantity AS NUMBER(15, 2))) * PackingSlipInventory.Quantity
	|	END,
	|	PackingSlipInventory.SerialNumbers,
	|	PackingSlipInventory.PointInTime,
	|	ISNULL(SalesOrderInventory.Specification, VALUE(Catalog.Products.EmptyRef)),
	|	ISNULL(SalesOrderInventory.BundleProduct, VALUE(Catalog.Products.EmptyRef)),
	|	ISNULL(SalesOrderInventory.BundleCharacteristic, VALUE(Catalog.ProductsCharacteristics.EmptyRef)),
	|	CASE
	|		WHEN ISNULL(SalesOrderInventory.Quantity, 0) = 0
	|			THEN 0
	|		ELSE (CAST(ISNULL(SalesOrderInventory.CostShare, 0) / SalesOrderInventory.Quantity AS NUMBER(15, 2))) * PackingSlipInventory.Quantity
	|	END,
	|	VALUE(Catalog.Employees.EmptyRef),
	|	PackingSlipInventory.Ref,
	|	ProductsCatalog.UseSerialNumbers,
	|	PackingSlipInventory.ConnectionKey,
	|	ISNULL(SalesOrderInventory.Taxable, FALSE),
	|	SalesOrderInventory.Project,
	|	SalesOrderInventory.DropShipping
	|FROM
	|	PackingSlipInventory AS PackingSlipInventory
	|		LEFT JOIN Document.SalesOrder.Inventory AS SalesOrderInventory
	|		ON PackingSlipInventory.SalesOrder = SalesOrderInventory.Ref
	|			AND PackingSlipInventory.Products = SalesOrderInventory.Products
	|			AND PackingSlipInventory.Characteristic = SalesOrderInventory.Characteristic
	|			AND PackingSlipInventory.Batch = SalesOrderInventory.Batch
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON PackingSlipInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON PackingSlipInventory.MeasurementUnit = UOM.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	TT_Inventory.Order AS Order,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor AS BaseQuantity,
	|	SUM(TT_InventoryCumulative.Quantity * TT_InventoryCumulative.Factor) AS BaseQuantityCumulative,
	|	TT_Inventory.Project AS Project,
	|	TT_Inventory.DropShipping AS DropShipping
	|INTO TT_InventoryCumulative
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_Inventory AS TT_InventoryCumulative
	|		ON TT_Inventory.Products = TT_InventoryCumulative.Products
	|			AND TT_Inventory.Characteristic = TT_InventoryCumulative.Characteristic
	|			AND TT_Inventory.Batch = TT_InventoryCumulative.Batch
	|			AND TT_Inventory.Order = TT_InventoryCumulative.Order
	|			AND TT_Inventory.LineNumber >= TT_InventoryCumulative.LineNumber
	|			AND TT_Inventory.Project = TT_InventoryCumulative.Project
	|			AND TT_Inventory.DropShipping = TT_InventoryCumulative.DropShipping
	|
	|GROUP BY
	|	TT_Inventory.LineNumber,
	|	TT_Inventory.Products,
	|	TT_Inventory.Characteristic,
	|	TT_Inventory.Batch,
	|	TT_Inventory.Order,
	|	TT_Inventory.Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor,
	|	TT_Inventory.Project,
	|	TT_Inventory.DropShipping
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryCumulative.LineNumber AS LineNumber,
	|	TT_InventoryCumulative.Products AS Products,
	|	TT_InventoryCumulative.Characteristic AS Characteristic,
	|	TT_InventoryCumulative.Batch AS Batch,
	|	TT_InventoryCumulative.Order AS Order,
	|	TT_InventoryCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_AlreadyInvoiced.BaseQuantity > TT_InventoryCumulative.BaseQuantityCumulative - TT_InventoryCumulative.BaseQuantity
	|			THEN TT_InventoryCumulative.BaseQuantityCumulative - TT_AlreadyInvoiced.BaseQuantity
	|		ELSE TT_InventoryCumulative.BaseQuantity
	|	END AS BaseQuantity,
	|	TT_InventoryCumulative.Project AS Project,
	|	TT_InventoryCumulative.DropShipping AS DropShipping
	|INTO TT_InventoryNotYetInvoiced
	|FROM
	|	TT_InventoryCumulative AS TT_InventoryCumulative
	|		LEFT JOIN TT_AlreadyInvoiced AS TT_AlreadyInvoiced
	|		ON TT_InventoryCumulative.Products = TT_AlreadyInvoiced.Products
	|			AND TT_InventoryCumulative.Characteristic = TT_AlreadyInvoiced.Characteristic
	|			AND TT_InventoryCumulative.Batch = TT_AlreadyInvoiced.Batch
	|			AND TT_InventoryCumulative.Order = TT_AlreadyInvoiced.Order
	|WHERE
	|	ISNULL(TT_AlreadyInvoiced.BaseQuantity, 0) < TT_InventoryCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryNotYetInvoiced.LineNumber AS LineNumber,
	|	TT_InventoryNotYetInvoiced.Products AS Products,
	|	TT_InventoryNotYetInvoiced.Characteristic AS Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch AS Batch,
	|	TT_InventoryNotYetInvoiced.Order AS Order,
	|	TT_InventoryNotYetInvoiced.Factor AS Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity AS BaseQuantity,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.BaseQuantity) AS BaseQuantityCumulative,
	|	TT_InventoryNotYetInvoiced.Project AS Project,
	|	TT_InventoryNotYetInvoiced.DropShipping AS DropShipping
	|INTO TT_InventoryNotYetInvoicedCumulative
	|FROM
	|	TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoiced
	|		INNER JOIN TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoicedCumulative
	|		ON TT_InventoryNotYetInvoiced.Products = TT_InventoryNotYetInvoicedCumulative.Products
	|			AND TT_InventoryNotYetInvoiced.Characteristic = TT_InventoryNotYetInvoicedCumulative.Characteristic
	|			AND TT_InventoryNotYetInvoiced.Batch = TT_InventoryNotYetInvoicedCumulative.Batch
	|			AND TT_InventoryNotYetInvoiced.Order = TT_InventoryNotYetInvoicedCumulative.Order
	|			AND TT_InventoryNotYetInvoiced.LineNumber >= TT_InventoryNotYetInvoicedCumulative.LineNumber
	|			AND TT_InventoryNotYetInvoiced.Project = TT_InventoryNotYetInvoicedCumulative.Project
	|			AND TT_InventoryNotYetInvoiced.DropShipping = TT_InventoryNotYetInvoicedCumulative.DropShipping
	|
	|GROUP BY
	|	TT_InventoryNotYetInvoiced.LineNumber,
	|	TT_InventoryNotYetInvoiced.Products,
	|	TT_InventoryNotYetInvoiced.Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch,
	|	TT_InventoryNotYetInvoiced.Order,
	|	TT_InventoryNotYetInvoiced.Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity,
	|	TT_InventoryNotYetInvoiced.Project,
	|	TT_InventoryNotYetInvoiced.DropShipping
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryNotYetInvoicedCumulative.LineNumber AS LineNumber,
	|	TT_InventoryNotYetInvoicedCumulative.Products AS Products,
	|	TT_InventoryNotYetInvoicedCumulative.Characteristic AS Characteristic,
	|	TT_InventoryNotYetInvoicedCumulative.Batch AS Batch,
	|	TT_InventoryNotYetInvoicedCumulative.Order AS Order,
	|	TT_InventoryNotYetInvoicedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|			THEN TT_OrdersBalances.QuantityBalance - (TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity)
	|	END AS BaseQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.Project AS Project,
	|	TT_InventoryNotYetInvoicedCumulative.DropShipping AS DropShipping
	|INTO TT_InventoryToBeInvoiced
	|FROM
	|	TT_InventoryNotYetInvoicedCumulative AS TT_InventoryNotYetInvoicedCumulative
	|		INNER JOIN TT_OrdersBalances AS TT_OrdersBalances
	|		ON TT_InventoryNotYetInvoicedCumulative.Products = TT_OrdersBalances.Products
	|			AND TT_InventoryNotYetInvoicedCumulative.Characteristic = TT_OrdersBalances.Characteristic
	|			AND TT_InventoryNotYetInvoicedCumulative.Order = TT_OrdersBalances.SalesOrder
	|			AND (&PackingSlip = VALUE(Document.PackingSlip.EmptyRef))
	|WHERE
	|	TT_OrdersBalances.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|
	|UNION ALL
	|
	|SELECT
	|	TT_InventoryNotYetInvoicedCumulative.LineNumber,
	|	TT_InventoryNotYetInvoicedCumulative.Products,
	|	TT_InventoryNotYetInvoicedCumulative.Characteristic,
	|	TT_InventoryNotYetInvoicedCumulative.Batch,
	|	TT_InventoryNotYetInvoicedCumulative.Order,
	|	TT_InventoryNotYetInvoicedCumulative.Factor,
	|	TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative,
	|	NULL,
	|	TT_InventoryNotYetInvoicedCumulative.DropShipping
	|FROM
	|	TT_InventoryNotYetInvoicedCumulative AS TT_InventoryNotYetInvoicedCumulative
	|WHERE
	|	&PackingSlip <> VALUE(Document.PackingSlip.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.ProductsTypeInventory AS ProductsTypeInventory,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Quantity
	|		ELSE CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))
	|	END AS Quantity,
	|	TT_Inventory.MeasurementUnit AS MeasurementUnit,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Price AS Price,
	|	TT_Inventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Amount
	|		ELSE (CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price * (1 - (CAST(TT_Inventory.DiscountMarkupPercent / 100 AS NUMBER(15, 2))))
	|	END AS Amount,
	|	TT_Inventory.VATRate AS VATRate,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.VATAmount
	|		WHEN &AmountIncludesVAT
	|			THEN (CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price * (1 - (CAST(TT_Inventory.DiscountMarkupPercent / 100 AS NUMBER(15, 2)))) * (CAST(TT_Inventory.VATRate.Rate / (100 + TT_Inventory.VATRate.Rate) AS NUMBER(15, 2)))
	|		ELSE (CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price * (1 - (CAST(TT_Inventory.DiscountMarkupPercent / 100 AS NUMBER(15, 2)))) * (CAST(TT_Inventory.VATRate.Rate / 100 AS NUMBER(15, 2)))
	|	END AS VATAmount,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Total
	|		WHEN &AmountIncludesVAT
	|			THEN (CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price * (1 - (CAST(TT_Inventory.DiscountMarkupPercent / 100 AS NUMBER(15, 2))))
	|		ELSE (CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price * (1 - (CAST(TT_Inventory.DiscountMarkupPercent / 100 AS NUMBER(15, 2)))) * (100 + TT_Inventory.VATRate.Rate) / 100
	|	END AS Total,
	|	TT_Inventory.Order AS Order,
	|	ISNULL(TT_Inventory.SalesRep, VALUE(Catalog.Employees.EmptyRef)) AS SalesRep,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssue,
	|	TT_Inventory.Content AS Content,
	|	TT_Inventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	TT_Inventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	TT_Inventory.SerialNumbers AS SerialNumbers,
	|	TT_Inventory.PointInTime AS PointInTime,
	|	TT_Inventory.Specification AS Specification,
	|	TT_Inventory.BundleProduct AS BundleProduct,
	|	TT_Inventory.BundleCharacteristic AS BundleCharacteristic,
	|	TT_Inventory.CostShare AS CostShare,
	|	TT_Inventory.ConnectionKey AS ConnectionKey,
	|	TT_Inventory.PackingSlip AS PackingSlip,
	|	TT_Inventory.UseSerialNumbers AS UseSerialNumbers,
	|	TT_Inventory.Taxable AS Taxable,
	|	TT_Inventory.Project AS Project,
	|	TT_Inventory.DropShipping AS DropShipping,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) AS RevenueItem,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) AS COGSItem
	|INTO TT_InventoryToFillReserve
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_InventoryToBeInvoiced AS TT_InventoryToBeInvoiced
	|		ON TT_Inventory.LineNumber = TT_InventoryToBeInvoiced.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryToBeInvoiced.Order";
	
	If Constants.UseInventoryReservation.Get() And ValueIsFilled(DocumentData.StructuralUnit) Then
		Query.Text = Query.Text + GetFillReserveColumnQueryText();
	Else
		Query.Text = StrReplace(Query.Text, "INTO TT_InventoryToFillReserve", "");
	EndIf;
	
	Query.Text = Query.Text + "
	|ORDER BY
	|	TT_Inventory.PointInTime,
	|	TT_Inventory.LineNumber";
	
	If FilterData.Property("OrdersArray") Then
		FilterString = "SalesOrder.Ref IN(&OrdersArray)";
		PackingSlipFilterString = "PackingSlipInventory.SalesOrder IN (&OrdersArray)";
		Query.SetParameter("OrdersArray", FilterData.OrdersArray);
	Else
		FilterString = "";
		NotFirstItem = False;
		PackingSlipFilterString = "TRUE";
		
		For Each FilterItem In FilterData Do
			If NotFirstItem Then
				FilterString = FilterString + "
				|	AND ";
			Else
				NotFirstItem = True;
			EndIf;
			FilterString = FilterString + "SalesOrder." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
		EndDo;
	EndIf;
	Query.Text = StrReplace(Query.Text, "&SalesOrdersConditions", FilterString);
	Query.Text = StrReplace(Query.Text, "&PackingSlipConditions", PackingSlipFilterString);
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(DocumentData.Company));
	Query.SetParameter("StructuralUnit", DocumentData.StructuralUnit);
	Query.SetParameter("AmountIncludesVAT", DocumentData.AmountIncludesVAT);
	
	If DocumentData.Property("PackingSlip")
		And ValueIsFilled(DocumentData.PackingSlip) Then
		Query.SetParameter("PackingSlip", DocumentData.PackingSlip);
		Query.Text = DriveServer.GetSerialNumbersQuery(Query.Text, DocumentData.PackingSlip, "PackingSlip");
	Else
		Query.SetParameter("PackingSlip", Documents.PackingSlip.EmptyRef());
		Query.Text = DriveServer.GetSerialNumbersQuery(Query.Text, Documents.SalesOrder.EmptyRef(), "TT_SalesOrders");
	EndIf;
	
	ResultsArray = Query.ExecuteBatch();	
	Selection = ResultsArray[ResultsArray.UBound()-1].Select();
	
	SerialNumberTable = ResultsArray[ResultsArray.UBound()].Unload();
	
	While Selection.Next() Do
		
		ProductsRow = Inventory.Add();
		FillPropertyValues(ProductsRow, Selection, , "ConnectionKey");
		
		If SerialNumberTable.Count() > 0 
			And Selection.UseSerialNumbers Then
			
			SearchStructure = New Structure;
			SearchStructure.Insert("Ref", Selection.PackingSlip);
			SearchStructure.Insert("ConnectionKey", Selection.ConnectionKey);
			
			FillPropertyValues(SearchStructure, Selection);
			
			RowsSerialNumbers = SerialNumberTable.FindRows(SearchStructure);
			
			For Each RowSerialNumber In RowsSerialNumbers Do
				
				WorkWithSerialNumbersClientServer.FillConnectionKey(Inventory, ProductsRow, "ConnectionKey");
				NewRow = SerialNumbers.Add();
				NewRow.ConnectionKey = ProductsRow.ConnectionKey;
				NewRow.SerialNumber = RowSerialNumber.SerialNumber;

			EndDo;
	
			ProductsRow.SerialNumbers = WorkWithSerialNumbers.StringSerialNumbers(SerialNumbers, ProductsRow.ConnectionKey);

		EndIf;

	EndDo;
	
EndProcedure

Procedure FillBySalesOrdersWithOrderedProducts(DocumentData, FilterData, Inventory) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	OrderedProducts.Products AS Products,
	|	OrderedProducts.Characteristic AS Characteristic,
	|	OrderedProducts.Quantity AS Quantity,
	|	OrderedProducts.SalesOrder AS SalesOrder
	|INTO TempOrderedProducts
	|FROM
	|	&OrderedProducts AS OrderedProducts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.SalesRep AS SalesRep,
	|	SalesOrder.PointInTime AS PointInTime
	|INTO TT_SalesOrders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref IN(&OrdersArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesInvoiceInventory.Order AS Order,
	|	SalesInvoiceInventory.Products AS Products,
	|	SalesInvoiceInventory.Characteristic AS Characteristic,
	|	SalesInvoiceInventory.Batch AS Batch,
	|	SUM(SalesInvoiceInventory.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyInvoiced
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON SalesInvoiceInventory.Order = TT_SalesOrders.Ref
	|		INNER JOIN Document.SalesInvoice AS SalesInvoiceDocument
	|		ON SalesInvoiceInventory.Ref = SalesInvoiceDocument.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SalesInvoiceInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesInvoiceInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	SalesInvoiceDocument.Posted
	|	AND SalesInvoiceInventory.Ref <> &Ref
	|
	|GROUP BY
	|	SalesInvoiceInventory.Batch,
	|	SalesInvoiceInventory.Order,
	|	SalesInvoiceInventory.Products,
	|	SalesInvoiceInventory.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	SalesOrderInventory.Products AS Products,
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ProductsTypeInventory,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.Batch AS Batch,
	|	SalesOrderInventory.Quantity AS Quantity,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	SalesOrderInventory.Price AS Price,
	|	SalesOrderInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SalesOrderInventory.Amount AS Amount,
	|	SalesOrderInventory.VATRate AS VATRate,
	|	SalesOrderInventory.VATAmount AS VATAmount,
	|	SalesOrderInventory.Total AS Total,
	|	SalesOrderInventory.Ref AS Order,
	|	SalesOrderInventory.Content AS Content,
	|	SalesOrderInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	SalesOrderInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	SalesOrderInventory.SerialNumbers AS SerialNumbers,
	|	TT_SalesOrders.PointInTime AS PointInTime,
	|	SalesOrderInventory.Specification AS Specification,
	|	SalesOrderInventory.BundleProduct AS BundleProduct,
	|	SalesOrderInventory.BundleCharacteristic AS BundleCharacteristic,
	|	SalesOrderInventory.CostShare AS CostShare,
	|	TT_SalesOrders.SalesRep AS SalesRep,
	|	ProductsCatalog.UseSerialNumbers AS UseSerialNumbers,
	|	SalesOrderInventory.ConnectionKey AS ConnectionKey,
	|	SalesOrderInventory.Taxable AS Taxable,
	|	SalesOrderInventory.Project AS Project,
	|	SalesOrderInventory.DropShipping AS DropShipping
	|INTO TT_Inventory
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON SalesOrderInventory.Ref = TT_SalesOrders.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SalesOrderInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesOrderInventory.MeasurementUnit = UOM.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	TT_Inventory.Order AS Order,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor AS BaseQuantity,
	|	SUM(TT_InventoryCumulative.Quantity * TT_InventoryCumulative.Factor) AS BaseQuantityCumulative,
	|	TT_Inventory.Project AS Project,
	|	TT_Inventory.DropShipping AS DropShipping
	|INTO TT_InventoryCumulative
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_Inventory AS TT_InventoryCumulative
	|		ON TT_Inventory.Products = TT_InventoryCumulative.Products
	|			AND TT_Inventory.Characteristic = TT_InventoryCumulative.Characteristic
	|			AND TT_Inventory.Batch = TT_InventoryCumulative.Batch
	|			AND TT_Inventory.Order = TT_InventoryCumulative.Order
	|			AND TT_Inventory.LineNumber >= TT_InventoryCumulative.LineNumber
	|			AND TT_Inventory.Project = TT_InventoryCumulative.Project
	|			AND TT_Inventory.DropShipping = TT_InventoryCumulative.DropShipping
	|
	|GROUP BY
	|	TT_Inventory.LineNumber,
	|	TT_Inventory.Products,
	|	TT_Inventory.Characteristic,
	|	TT_Inventory.Batch,
	|	TT_Inventory.Order,
	|	TT_Inventory.Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor,
	|	TT_Inventory.Project,
	|	TT_Inventory.DropShipping
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryCumulative.LineNumber AS LineNumber,
	|	TT_InventoryCumulative.Products AS Products,
	|	TT_InventoryCumulative.Characteristic AS Characteristic,
	|	TT_InventoryCumulative.Batch AS Batch,
	|	TT_InventoryCumulative.Order AS Order,
	|	TT_InventoryCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_AlreadyInvoiced.BaseQuantity > TT_InventoryCumulative.BaseQuantityCumulative - TT_InventoryCumulative.BaseQuantity
	|			THEN TT_InventoryCumulative.BaseQuantityCumulative - TT_AlreadyInvoiced.BaseQuantity
	|		ELSE TT_InventoryCumulative.BaseQuantity
	|	END AS BaseQuantity,
	|	TT_InventoryCumulative.Project AS Project,
	|	TT_InventoryCumulative.DropShipping AS DropShipping
	|INTO TT_InventoryNotYetInvoiced
	|FROM
	|	TT_InventoryCumulative AS TT_InventoryCumulative
	|		LEFT JOIN TT_AlreadyInvoiced AS TT_AlreadyInvoiced
	|		ON TT_InventoryCumulative.Products = TT_AlreadyInvoiced.Products
	|			AND TT_InventoryCumulative.Characteristic = TT_AlreadyInvoiced.Characteristic
	|			AND TT_InventoryCumulative.Batch = TT_AlreadyInvoiced.Batch
	|			AND TT_InventoryCumulative.Order = TT_AlreadyInvoiced.Order
	|WHERE
	|	ISNULL(TT_AlreadyInvoiced.BaseQuantity, 0) < TT_InventoryCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryNotYetInvoiced.LineNumber AS LineNumber,
	|	TT_InventoryNotYetInvoiced.Products AS Products,
	|	TT_InventoryNotYetInvoiced.Characteristic AS Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch AS Batch,
	|	TT_InventoryNotYetInvoiced.Order AS Order,
	|	TT_InventoryNotYetInvoiced.Factor AS Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity AS BaseQuantity,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.BaseQuantity) AS BaseQuantityCumulative,
	|	TT_InventoryNotYetInvoiced.Project AS Project,
	|	TT_InventoryNotYetInvoiced.DropShipping AS DropShipping
	|INTO TT_InventoryNotYetInvoicedCumulative
	|FROM
	|	TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoiced
	|		INNER JOIN TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoicedCumulative
	|		ON TT_InventoryNotYetInvoiced.Products = TT_InventoryNotYetInvoicedCumulative.Products
	|			AND TT_InventoryNotYetInvoiced.Characteristic = TT_InventoryNotYetInvoicedCumulative.Characteristic
	|			AND TT_InventoryNotYetInvoiced.Batch = TT_InventoryNotYetInvoicedCumulative.Batch
	|			AND TT_InventoryNotYetInvoiced.Order = TT_InventoryNotYetInvoicedCumulative.Order
	|			AND TT_InventoryNotYetInvoiced.LineNumber >= TT_InventoryNotYetInvoicedCumulative.LineNumber
	|			AND TT_InventoryNotYetInvoiced.Project = TT_InventoryNotYetInvoicedCumulative.Project
	|			AND TT_InventoryNotYetInvoiced.DropShipping = TT_InventoryNotYetInvoicedCumulative.DropShipping
	|
	|GROUP BY
	|	TT_InventoryNotYetInvoiced.LineNumber,
	|	TT_InventoryNotYetInvoiced.Products,
	|	TT_InventoryNotYetInvoiced.Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch,
	|	TT_InventoryNotYetInvoiced.Order,
	|	TT_InventoryNotYetInvoiced.Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity,
	|	TT_InventoryNotYetInvoiced.Project,
	|	TT_InventoryNotYetInvoiced.DropShipping
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryNotYetInvoicedCumulative.LineNumber AS LineNumber,
	|	TT_InventoryNotYetInvoicedCumulative.Products AS Products,
	|	TT_InventoryNotYetInvoicedCumulative.Characteristic AS Characteristic,
	|	TT_InventoryNotYetInvoicedCumulative.Batch AS Batch,
	|	TT_InventoryNotYetInvoicedCumulative.Order AS Order,
	|	TT_InventoryNotYetInvoicedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TempOrderedProducts.Quantity > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|		WHEN TempOrderedProducts.Quantity > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|			THEN TempOrderedProducts.Quantity - (TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity)
	|	END AS BaseQuantity
	|INTO TT_InventoryToBeInvoiced
	|FROM
	|	TT_InventoryNotYetInvoicedCumulative AS TT_InventoryNotYetInvoicedCumulative
	|		INNER JOIN TempOrderedProducts AS TempOrderedProducts
	|		ON TT_InventoryNotYetInvoicedCumulative.Products = TempOrderedProducts.Products
	|			AND TT_InventoryNotYetInvoicedCumulative.Characteristic = TempOrderedProducts.Characteristic
	|			AND TT_InventoryNotYetInvoicedCumulative.Order = TempOrderedProducts.SalesOrder
	|WHERE
	|	TempOrderedProducts.Quantity > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.ProductsTypeInventory AS ProductsTypeInventory,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Quantity
	|		ELSE CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))
	|	END AS Quantity,
	|	TT_Inventory.MeasurementUnit AS MeasurementUnit,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Price AS Price,
	|	TT_Inventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Amount
	|		ELSE (CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price * (1 - (CAST(TT_Inventory.DiscountMarkupPercent / 100 AS NUMBER(15, 2))))
	|	END AS Amount,
	|	TT_Inventory.VATRate AS VATRate,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.VATAmount
	|		WHEN &AmountIncludesVAT
	|			THEN (CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price * (1 - (CAST(TT_Inventory.DiscountMarkupPercent / 100 AS NUMBER(15, 2)))) * (CAST(TT_Inventory.VATRate.Rate / (100 + TT_Inventory.VATRate.Rate) AS NUMBER(15, 2)))
	|		ELSE (CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price * (1 - (CAST(TT_Inventory.DiscountMarkupPercent / 100 AS NUMBER(15, 2)))) * (CAST(TT_Inventory.VATRate.Rate / 100 AS NUMBER(15, 2)))
	|	END AS VATAmount,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Total
	|		WHEN &AmountIncludesVAT
	|			THEN (CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price * (1 - (CAST(TT_Inventory.DiscountMarkupPercent / 100 AS NUMBER(15, 2))))
	|		ELSE (CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price * (1 - (CAST(TT_Inventory.DiscountMarkupPercent / 100 AS NUMBER(15, 2)))) * (100 + TT_Inventory.VATRate.Rate) / 100
	|	END AS Total,
	|	TT_Inventory.Order AS Order,
	|	TT_Inventory.SalesRep AS SalesRep,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssue,
	|	VALUE(Document.PackingSlip.EmptyRef) AS PackingSlip,
	|	TT_Inventory.Content AS Content,
	|	TT_Inventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	TT_Inventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	TT_Inventory.SerialNumbers AS SerialNumbers,
	|	TT_Inventory.PointInTime AS PointInTime,
	|	TT_Inventory.Specification AS Specification,
	|	TT_Inventory.BundleProduct AS BundleProduct,
	|	TT_Inventory.BundleCharacteristic AS BundleCharacteristic,
	|	TT_Inventory.CostShare AS CostShare,
	|	TT_Inventory.ConnectionKey AS ConnectionKey,
	|	TT_Inventory.UseSerialNumbers AS UseSerialNumbers,
	|	TT_Inventory.Taxable AS Taxable,
	|	TT_Inventory.Project AS Project,
	|	TT_Inventory.DropShipping AS DropShipping,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) AS RevenueItem,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) AS COGSItem
	|INTO TT_InventoryToFillReserve
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_InventoryToBeInvoiced AS TT_InventoryToBeInvoiced
	|		ON TT_Inventory.LineNumber = TT_InventoryToBeInvoiced.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryToBeInvoiced.Order";
	
	If Constants.UseInventoryReservation.Get() And ValueIsFilled(DocumentData.StructuralUnit) Then
		Query.Text = Query.Text + GetFillReserveColumnQueryText();
	Else
		Query.Text = StrReplace(Query.Text, "INTO TT_InventoryToFillReserve", "");
	EndIf;
	
	Query.Text = Query.Text + "
	|ORDER BY
	|	TT_Inventory.PointInTime,
	|	TT_Inventory.LineNumber";
	
	Query.SetParameter("OrdersArray", FilterData.OrdersArray);
	Query.SetParameter("OrderedProducts", FilterData.OrderedProductsTable);
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(DocumentData.Company));
	Query.SetParameter("StructuralUnit", DocumentData.StructuralUnit);
	Query.SetParameter("AmountIncludesVAT", DocumentData.AmountIncludesVAT);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		InventoryRow = Inventory.Add();
		FillPropertyValues(InventoryRow, Selection);
		
	EndDo;
	
EndProcedure

Procedure FillByWorkOrdersInventory(DocumentData, FilterData, Inventory) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	WorkOrder.Ref AS Ref,
	|	WorkOrder.SalesRep AS SalesRep
	|INTO TT_SalesOrders
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|WHERE
	|	&SalesOrdersConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesInvoiceInventory.Order AS Order,
	|	SalesInvoiceInventory.Products AS Products,
	|	SalesInvoiceInventory.Characteristic AS Characteristic,
	|	SalesInvoiceInventory.Batch AS Batch,
	|	SUM(SalesInvoiceInventory.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyInvoiced
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON SalesInvoiceInventory.Order = TT_SalesOrders.Ref
	|		INNER JOIN Document.SalesInvoice AS SalesInvoiceDocument
	|		ON SalesInvoiceInventory.Ref = SalesInvoiceDocument.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SalesInvoiceInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesInvoiceInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	SalesInvoiceDocument.Posted
	|	AND SalesInvoiceInventory.Ref <> &Ref
	|
	|GROUP BY
	|	SalesInvoiceInventory.Batch,
	|	SalesInvoiceInventory.Order,
	|	SalesInvoiceInventory.Products,
	|	SalesInvoiceInventory.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OrdersBalance.SalesOrder AS SalesOrder,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|INTO TT_OrdersBalances
	|FROM
	|	(SELECT
	|		WorkOrdersBalance.WorkOrder AS SalesOrder,
	|		WorkOrdersBalance.Products AS Products,
	|		WorkOrdersBalance.Characteristic AS Characteristic,
	|		WorkOrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.WorkOrders.Balance(
	|				,
	|				WorkOrder IN
	|					(SELECT
	|						TT_SalesOrders.Ref
	|					FROM
	|						TT_SalesOrders)) AS WorkOrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		WorkOrders.WorkOrder,
	|		WorkOrders.Products,
	|		WorkOrders.Characteristic,
	|		CASE
	|			WHEN WorkOrders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(WorkOrders.Quantity, 0)
	|			ELSE -ISNULL(WorkOrders.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.WorkOrders AS WorkOrders
	|	WHERE
	|		WorkOrders.Recorder = &Ref) AS OrdersBalance
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON OrdersBalance.Products = ProductsCatalog.Ref
	|
	|GROUP BY
	|	OrdersBalance.SalesOrder,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	WorkOrderInventory.LineNumber AS LineNumber,
	|	WorkOrderInventory.Products AS Products,
	|	WorkOrderInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ProductsTypeInventory,
	|	WorkOrderInventory.Characteristic AS Characteristic,
	|	WorkOrderInventory.Batch AS Batch,
	|	WorkOrderInventory.Quantity AS Quantity,
	|	WorkOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	WorkOrderInventory.Price AS Price,
	|	WorkOrderInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	WorkOrderInventory.Amount AS Amount,
	|	WorkOrderInventory.VATRate AS VATRate,
	|	WorkOrderInventory.VATAmount AS VATAmount,
	|	WorkOrderInventory.Total AS Total,
	|	WorkOrderInventory.Ref AS Order,
	|	WorkOrderInventory.Content AS Content,
	|	WorkOrderInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	WorkOrderInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	WorkOrderInventory.Ref.PointInTime AS PointInTime,
	|	TT_SalesOrders.SalesRep AS SalesRep,
	|	WorkOrderInventory.BundleProduct AS BundleProduct,
	|	WorkOrderInventory.BundleCharacteristic AS BundleCharacteristic,
	|	WorkOrderInventory.CostShare AS CostShare,
	|	WorkOrderInventory.Taxable AS Taxable,
	|	WorkOrderInventory.Project AS Project
	|INTO TT_Inventory
	|FROM
	|	Document.WorkOrder.Inventory AS WorkOrderInventory
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON WorkOrderInventory.Ref = TT_SalesOrders.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON WorkOrderInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON WorkOrderInventory.MeasurementUnit = UOM.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	TT_Inventory.Order AS Order,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor AS BaseQuantity,
	|	SUM(TT_InventoryCumulative.Quantity * TT_InventoryCumulative.Factor) AS BaseQuantityCumulative,
	|	TT_Inventory.Project AS Project
	|INTO TT_InventoryCumulative
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_Inventory AS TT_InventoryCumulative
	|		ON TT_Inventory.Products = TT_InventoryCumulative.Products
	|			AND TT_Inventory.Characteristic = TT_InventoryCumulative.Characteristic
	|			AND TT_Inventory.Batch = TT_InventoryCumulative.Batch
	|			AND TT_Inventory.Order = TT_InventoryCumulative.Order
	|			AND TT_Inventory.LineNumber >= TT_InventoryCumulative.LineNumber
	|			AND TT_Inventory.Project = TT_InventoryCumulative.Project
	|
	|GROUP BY
	|	TT_Inventory.LineNumber,
	|	TT_Inventory.Products,
	|	TT_Inventory.Characteristic,
	|	TT_Inventory.Batch,
	|	TT_Inventory.Order,
	|	TT_Inventory.Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor,
	|	TT_Inventory.Project
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryCumulative.LineNumber AS LineNumber,
	|	TT_InventoryCumulative.Products AS Products,
	|	TT_InventoryCumulative.Characteristic AS Characteristic,
	|	TT_InventoryCumulative.Batch AS Batch,
	|	TT_InventoryCumulative.Order AS Order,
	|	TT_InventoryCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_AlreadyInvoiced.BaseQuantity > TT_InventoryCumulative.BaseQuantityCumulative - TT_InventoryCumulative.BaseQuantity
	|			THEN TT_InventoryCumulative.BaseQuantityCumulative - TT_AlreadyInvoiced.BaseQuantity
	|		ELSE TT_InventoryCumulative.BaseQuantity
	|	END AS BaseQuantity,
	|	TT_InventoryCumulative.Project AS Project
	|INTO TT_InventoryNotYetInvoiced
	|FROM
	|	TT_InventoryCumulative AS TT_InventoryCumulative
	|		LEFT JOIN TT_AlreadyInvoiced AS TT_AlreadyInvoiced
	|		ON TT_InventoryCumulative.Products = TT_AlreadyInvoiced.Products
	|			AND TT_InventoryCumulative.Characteristic = TT_AlreadyInvoiced.Characteristic
	|			AND TT_InventoryCumulative.Batch = TT_AlreadyInvoiced.Batch
	|			AND TT_InventoryCumulative.Order = TT_AlreadyInvoiced.Order
	|WHERE
	|	ISNULL(TT_AlreadyInvoiced.BaseQuantity, 0) < TT_InventoryCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryNotYetInvoiced.LineNumber AS LineNumber,
	|	TT_InventoryNotYetInvoiced.Products AS Products,
	|	TT_InventoryNotYetInvoiced.Characteristic AS Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch AS Batch,
	|	TT_InventoryNotYetInvoiced.Order AS Order,
	|	TT_InventoryNotYetInvoiced.Factor AS Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity AS BaseQuantity,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.BaseQuantity) AS BaseQuantityCumulative,
	|	TT_InventoryNotYetInvoiced.Project AS Project
	|INTO TT_InventoryNotYetInvoicedCumulative
	|FROM
	|	TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoiced
	|		INNER JOIN TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoicedCumulative
	|		ON TT_InventoryNotYetInvoiced.Products = TT_InventoryNotYetInvoicedCumulative.Products
	|			AND TT_InventoryNotYetInvoiced.Characteristic = TT_InventoryNotYetInvoicedCumulative.Characteristic
	|			AND TT_InventoryNotYetInvoiced.Batch = TT_InventoryNotYetInvoicedCumulative.Batch
	|			AND TT_InventoryNotYetInvoiced.Order = TT_InventoryNotYetInvoicedCumulative.Order
	|			AND TT_InventoryNotYetInvoiced.LineNumber >= TT_InventoryNotYetInvoicedCumulative.LineNumber
	|			AND TT_InventoryNotYetInvoiced.Project = TT_InventoryNotYetInvoicedCumulative.Project
	|
	|GROUP BY
	|	TT_InventoryNotYetInvoiced.LineNumber,
	|	TT_InventoryNotYetInvoiced.Products,
	|	TT_InventoryNotYetInvoiced.Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch,
	|	TT_InventoryNotYetInvoiced.Order,
	|	TT_InventoryNotYetInvoiced.Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity,
	|	TT_InventoryNotYetInvoiced.Project
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryNotYetInvoicedCumulative.LineNumber AS LineNumber,
	|	TT_InventoryNotYetInvoicedCumulative.Products AS Products,
	|	TT_InventoryNotYetInvoicedCumulative.Characteristic AS Characteristic,
	|	TT_InventoryNotYetInvoicedCumulative.Batch AS Batch,
	|	TT_InventoryNotYetInvoicedCumulative.Order AS Order,
	|	TT_InventoryNotYetInvoicedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|			THEN TT_OrdersBalances.QuantityBalance - (TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity)
	|	END AS BaseQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.Project AS Project
	|INTO TT_InventoryToBeInvoiced
	|FROM
	|	TT_InventoryNotYetInvoicedCumulative AS TT_InventoryNotYetInvoicedCumulative
	|		INNER JOIN TT_OrdersBalances AS TT_OrdersBalances
	|		ON TT_InventoryNotYetInvoicedCumulative.Products = TT_OrdersBalances.Products
	|			AND TT_InventoryNotYetInvoicedCumulative.Characteristic = TT_OrdersBalances.Characteristic
	|			AND TT_InventoryNotYetInvoicedCumulative.Order = TT_OrdersBalances.SalesOrder
	|WHERE
	|	TT_OrdersBalances.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.ProductsTypeInventory AS ProductsTypeInventory,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Quantity
	|		ELSE CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))
	|	END AS Quantity,
	|	TT_Inventory.MeasurementUnit AS MeasurementUnit,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Price AS Price,
	|	TT_Inventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Amount
	|		ELSE CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))
	|	END AS Amount,
	|	TT_Inventory.VATRate AS VATRate,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.VATAmount
	|		WHEN &AmountIncludesVAT
	|			THEN CAST((CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))) * TT_Inventory.VATRate.Rate / (100 + TT_Inventory.VATRate.Rate) AS NUMBER(15, 2))
	|		ELSE CAST((CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))) * TT_Inventory.VATRate.Rate / 100 AS NUMBER(15, 2))
	|	END AS VATAmount,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Total
	|		WHEN &AmountIncludesVAT
	|			THEN CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))
	|		ELSE CAST((CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))) * (100 + TT_Inventory.VATRate.Rate) / 100 AS NUMBER(15, 2))
	|	END AS Total,
	|	TT_Inventory.Order AS Order,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssue,
	|	TT_Inventory.Content AS Content,
	|	TT_Inventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	TT_Inventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	TT_Inventory.PointInTime AS PointInTime,
	|	TT_Inventory.SalesRep AS SalesRep,
	|	TT_Inventory.BundleProduct AS BundleProduct,
	|	TT_Inventory.BundleCharacteristic AS BundleCharacteristic,
	|	TT_Inventory.CostShare AS CostShare,
	|	TT_Inventory.Taxable AS Taxable,
	|	TT_Inventory.Project AS Project
	|INTO TT_InventoryToFillReserve
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_InventoryToBeInvoiced AS TT_InventoryToBeInvoiced
	|		ON TT_Inventory.LineNumber = TT_InventoryToBeInvoiced.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryToBeInvoiced.Order";
	
	
	If Constants.UseInventoryReservation.Get() And ValueIsFilled(DocumentData.StructuralUnit) Then
		Query.Text = Query.Text + GetFillWorkOrderReserveColumnQueryText();
	Else
		Query.Text = StrReplace(Query.Text, "INTO TT_InventoryToFillReserve", "");
	EndIf;
	
	Query.Text = Query.Text + "
	|ORDER BY
	|	TT_Inventory.PointInTime,
	|	TT_Inventory.LineNumber";
	
	If FilterData.Property("OrdersArray") Then
		FilterString = "WorkOrder.Ref IN(&OrdersArray)";
		Query.SetParameter("OrdersArray", FilterData.OrdersArray);
		
	Else
		FilterString = "";
		NotFirstItem = False;
		For Each FilterItem In FilterData Do
			If NotFirstItem Then
				FilterString = FilterString + "
				|	AND ";
			Else
				NotFirstItem = True;
			EndIf;
			FilterString = FilterString + "WorkOrder." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
		EndDo;
	EndIf;
	Query.Text = StrReplace(Query.Text, "&SalesOrdersConditions", FilterString);
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(DocumentData.Company));
	Query.SetParameter("StructuralUnit", DocumentData.StructuralUnit);
	Query.SetParameter("AmountIncludesVAT", DocumentData.AmountIncludesVAT);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		NewLine = Inventory.Add();
		FillPropertyValues(NewLine, SelectionDetailRecords);
	EndDo;
	
EndProcedure

Procedure FillByWorkOrdersWorks(DocumentData, FilterData, Inventory) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	WorkOrder.Ref AS Ref,
	|	WorkOrder.SalesRep AS SalesRep
	|INTO TT_SalesOrders
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|WHERE
	|	&SalesOrdersConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesInvoiceInventory.Order AS Order,
	|	SalesInvoiceInventory.Products AS Products,
	|	SalesInvoiceInventory.Characteristic AS Characteristic,
	|	SalesInvoiceInventory.Batch AS Batch,
	|	SUM(SalesInvoiceInventory.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyInvoiced
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON SalesInvoiceInventory.Order = TT_SalesOrders.Ref
	|		INNER JOIN Document.SalesInvoice AS SalesInvoiceDocument
	|		ON SalesInvoiceInventory.Ref = SalesInvoiceDocument.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SalesInvoiceInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesInvoiceInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	SalesInvoiceDocument.Posted
	|	AND SalesInvoiceInventory.Ref <> &Ref
	|
	|GROUP BY
	|	SalesInvoiceInventory.Batch,
	|	SalesInvoiceInventory.Order,
	|	SalesInvoiceInventory.Products,
	|	SalesInvoiceInventory.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OrdersBalance.SalesOrder AS SalesOrder,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|INTO TT_OrdersBalances
	|FROM
	|	(SELECT
	|		WorkOrdersBalance.WorkOrder AS SalesOrder,
	|		WorkOrdersBalance.Products AS Products,
	|		WorkOrdersBalance.Characteristic AS Characteristic,
	|		WorkOrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.WorkOrders.Balance(
	|				,
	|				WorkOrder IN
	|					(SELECT
	|						TT_SalesOrders.Ref
	|					FROM
	|						TT_SalesOrders)) AS WorkOrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		WorkOrders.WorkOrder,
	|		WorkOrders.Products,
	|		WorkOrders.Characteristic,
	|		CASE
	|			WHEN WorkOrders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(WorkOrders.Quantity, 0)
	|			ELSE -ISNULL(WorkOrders.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.WorkOrders AS WorkOrders
	|	WHERE
	|		WorkOrders.Recorder = &Ref) AS OrdersBalance
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON OrdersBalance.Products = ProductsCatalog.Ref
	|
	|GROUP BY
	|	OrdersBalance.SalesOrder,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	WorkOrderWorks.LineNumber AS LineNumber,
	|	WorkOrderWorks.Products AS Products,
	|	WorkOrderWorks.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ProductsTypeInventory,
	|	WorkOrderWorks.Characteristic AS Characteristic,
	|	WorkOrderWorks.Quantity AS Quantity,
	|	1 AS Factor,
	|	WorkOrderWorks.Price AS Price,
	|	WorkOrderWorks.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	WorkOrderWorks.Amount AS Amount,
	|	WorkOrderWorks.VATRate AS VATRate,
	|	WorkOrderWorks.VATAmount AS VATAmount,
	|	WorkOrderWorks.Total AS Total,
	|	WorkOrderWorks.Ref AS Order,
	|	WorkOrderWorks.Content AS Content,
	|	WorkOrderWorks.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	WorkOrderWorks.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	WorkOrderWorks.Ref.PointInTime AS PointInTime,
	|	ProductsCatalog.MeasurementUnit AS MeasurementUnit,
	|	TT_SalesOrders.SalesRep AS SalesRep,
	|	WorkOrderWorks.Taxable AS Taxable,
	|	WorkOrderWorks.Project AS Project
	|INTO TT_Inventory
	|FROM
	|	Document.WorkOrder.Works AS WorkOrderWorks
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON WorkOrderWorks.Ref = TT_SalesOrders.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON WorkOrderWorks.Products = ProductsCatalog.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Order AS Order,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor AS BaseQuantity,
	|	SUM(TT_InventoryCumulative.Quantity * TT_InventoryCumulative.Factor) AS BaseQuantityCumulative,
	|	TT_Inventory.Project AS Project
	|INTO TT_InventoryCumulative
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_Inventory AS TT_InventoryCumulative
	|		ON TT_Inventory.Products = TT_InventoryCumulative.Products
	|			AND TT_Inventory.Characteristic = TT_InventoryCumulative.Characteristic
	|			AND TT_Inventory.Order = TT_InventoryCumulative.Order
	|			AND TT_Inventory.LineNumber >= TT_InventoryCumulative.LineNumber
	|			AND TT_Inventory.Project = TT_InventoryCumulative.Project
	|
	|GROUP BY
	|	TT_Inventory.LineNumber,
	|	TT_Inventory.Products,
	|	TT_Inventory.Characteristic,
	|	TT_Inventory.Order,
	|	TT_Inventory.Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor,
	|	TT_Inventory.Project
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryCumulative.LineNumber AS LineNumber,
	|	TT_InventoryCumulative.Products AS Products,
	|	TT_InventoryCumulative.Characteristic AS Characteristic,
	|	TT_InventoryCumulative.Order AS Order,
	|	TT_InventoryCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_AlreadyInvoiced.BaseQuantity > TT_InventoryCumulative.BaseQuantityCumulative - TT_InventoryCumulative.BaseQuantity
	|			THEN TT_InventoryCumulative.BaseQuantityCumulative - TT_AlreadyInvoiced.BaseQuantity
	|		ELSE TT_InventoryCumulative.BaseQuantity
	|	END AS BaseQuantity,
	|	TT_InventoryCumulative.Project AS Project
	|INTO TT_InventoryNotYetInvoiced
	|FROM
	|	TT_InventoryCumulative AS TT_InventoryCumulative
	|		LEFT JOIN TT_AlreadyInvoiced AS TT_AlreadyInvoiced
	|		ON TT_InventoryCumulative.Products = TT_AlreadyInvoiced.Products
	|			AND TT_InventoryCumulative.Characteristic = TT_AlreadyInvoiced.Characteristic
	|			AND TT_InventoryCumulative.Order = TT_AlreadyInvoiced.Order
	|WHERE
	|	ISNULL(TT_AlreadyInvoiced.BaseQuantity, 0) < TT_InventoryCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryNotYetInvoiced.LineNumber AS LineNumber,
	|	TT_InventoryNotYetInvoiced.Products AS Products,
	|	TT_InventoryNotYetInvoiced.Characteristic AS Characteristic,
	|	TT_InventoryNotYetInvoiced.Order AS Order,
	|	TT_InventoryNotYetInvoiced.Factor AS Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity AS BaseQuantity,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.BaseQuantity) AS BaseQuantityCumulative,
	|	TT_InventoryNotYetInvoiced.Project AS Project
	|INTO TT_InventoryNotYetInvoicedCumulative
	|FROM
	|	TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoiced
	|		INNER JOIN TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoicedCumulative
	|		ON TT_InventoryNotYetInvoiced.Products = TT_InventoryNotYetInvoicedCumulative.Products
	|			AND TT_InventoryNotYetInvoiced.Characteristic = TT_InventoryNotYetInvoicedCumulative.Characteristic
	|			AND TT_InventoryNotYetInvoiced.Order = TT_InventoryNotYetInvoicedCumulative.Order
	|			AND TT_InventoryNotYetInvoiced.LineNumber >= TT_InventoryNotYetInvoicedCumulative.LineNumber
	|			AND TT_InventoryNotYetInvoiced.Project = TT_InventoryNotYetInvoicedCumulative.Project
	|
	|GROUP BY
	|	TT_InventoryNotYetInvoiced.LineNumber,
	|	TT_InventoryNotYetInvoiced.Products,
	|	TT_InventoryNotYetInvoiced.Characteristic,
	|	TT_InventoryNotYetInvoiced.Order,
	|	TT_InventoryNotYetInvoiced.Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity,
	|	TT_InventoryNotYetInvoiced.Project
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryNotYetInvoicedCumulative.LineNumber AS LineNumber,
	|	TT_InventoryNotYetInvoicedCumulative.Products AS Products,
	|	TT_InventoryNotYetInvoicedCumulative.Characteristic AS Characteristic,
	|	TT_InventoryNotYetInvoicedCumulative.Order AS Order,
	|	TT_InventoryNotYetInvoicedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|			THEN TT_OrdersBalances.QuantityBalance - (TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity)
	|	END AS BaseQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.Project AS Project
	|INTO TT_InventoryToBeInvoiced
	|FROM
	|	TT_InventoryNotYetInvoicedCumulative AS TT_InventoryNotYetInvoicedCumulative
	|		INNER JOIN TT_OrdersBalances AS TT_OrdersBalances
	|		ON TT_InventoryNotYetInvoicedCumulative.Products = TT_OrdersBalances.Products
	|			AND TT_InventoryNotYetInvoicedCumulative.Characteristic = TT_OrdersBalances.Characteristic
	|			AND TT_InventoryNotYetInvoicedCumulative.Order = TT_OrdersBalances.SalesOrder
	|WHERE
	|	TT_OrdersBalances.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.ProductsTypeInventory AS ProductsTypeInventory,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Quantity
	|		ELSE CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))
	|	END AS Quantity,
	|	TT_Inventory.MeasurementUnit AS MeasurementUnit,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Price AS Price,
	|	TT_Inventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Amount
	|		ELSE CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))
	|	END AS Amount,
	|	TT_Inventory.VATRate AS VATRate,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.VATAmount
	|		WHEN &AmountIncludesVAT
	|			THEN CAST((CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))) * TT_Inventory.VATRate.Rate / (100 + TT_Inventory.VATRate.Rate) AS NUMBER(15, 2))
	|		ELSE CAST((CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))) * TT_Inventory.VATRate.Rate / 100 AS NUMBER(15, 2))
	|	END AS VATAmount,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Total
	|		WHEN &AmountIncludesVAT
	|			THEN CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))
	|		ELSE CAST((CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))) * (100 + TT_Inventory.VATRate.Rate) / 100 AS NUMBER(15, 2))
	|	END AS Total,
	|	TT_Inventory.Order AS Order,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssue,
	|	TT_Inventory.Content AS Content,
	|	TT_Inventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	TT_Inventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	VALUE(Catalog.SerialNumbers.EmptyRef) AS SerialNumbers,
	|	TT_Inventory.PointInTime AS PointInTime,
	|	TT_Inventory.SalesRep AS SalesRep,
	|	TT_Inventory.Taxable AS Taxable,
	|	TT_Inventory.Project AS Project
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_InventoryToBeInvoiced AS TT_InventoryToBeInvoiced
	|		ON TT_Inventory.LineNumber = TT_InventoryToBeInvoiced.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryToBeInvoiced.Order
	|
	|ORDER BY
	|	PointInTime,
	|	LineNumber";
	
	If FilterData.Property("OrdersArray") Then
		FilterString = "WorkOrder.Ref IN(&OrdersArray)";
		Query.SetParameter("OrdersArray", FilterData.OrdersArray);
		
	Else
		FilterString = "";
		NotFirstItem = False;
		For Each FilterItem In FilterData Do
			If NotFirstItem Then
				FilterString = FilterString + "
				|	AND ";
			Else
				NotFirstItem = True;
			EndIf;
			FilterString = FilterString + "WorkOrder." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
		EndDo;
	EndIf;
	Query.Text = StrReplace(Query.Text, "&SalesOrdersConditions", FilterString);
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(DocumentData.Company));
	Query.SetParameter("StructuralUnit", DocumentData.StructuralUnit);
	Query.SetParameter("AmountIncludesVAT", DocumentData.AmountIncludesVAT);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		NewLine = Inventory.Add();
		FillPropertyValues(NewLine, SelectionDetailRecords);
	EndDo;
	
EndProcedure

Procedure FillByGoodsIssues(DocumentData, FilterData, Inventory) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	GoodsIssue.Ref AS Ref,
	|	GoodsIssue.PointInTime AS PointInTime,
	|	CASE
	|		WHEN GoodsIssue.OperationType = VALUE(Enum.OperationTypesGoodsIssue.DropShipping)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS DropShipping
	|INTO TT_GoodsIssues
	|FROM
	|	Document.GoodsIssue AS GoodsIssue
	|WHERE
	|	&GoodsIssuesConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesInvoiceInventory.Order AS Order,
	|	SalesInvoiceInventory.GoodsIssue AS GoodsIssue,
	|	SalesInvoiceInventory.Products AS Products,
	|	SalesInvoiceInventory.Characteristic AS Characteristic,
	|	SalesInvoiceInventory.Batch AS Batch,
	|	SUM(SalesInvoiceInventory.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyInvoiced
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		INNER JOIN TT_GoodsIssues AS TT_GoodsIssues
	|		ON SalesInvoiceInventory.GoodsIssue = TT_GoodsIssues.Ref
	|		INNER JOIN Document.SalesInvoice AS SalesInvoiceDocument
	|		ON SalesInvoiceInventory.Ref = SalesInvoiceDocument.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SalesInvoiceInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesInvoiceInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	SalesInvoiceDocument.Posted
	|	AND SalesInvoiceInventory.Ref <> &Ref
	|
	|GROUP BY
	|	SalesInvoiceInventory.Batch,
	|	SalesInvoiceInventory.Order,
	|	SalesInvoiceInventory.Products,
	|	SalesInvoiceInventory.Characteristic,
	|	SalesInvoiceInventory.GoodsIssue
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsIssueBalance.SalesOrder AS SalesOrder,
	|	GoodsIssueBalance.GoodsIssue AS GoodsIssue,
	|	GoodsIssueBalance.Products AS Products,
	|	GoodsIssueBalance.Characteristic AS Characteristic,
	|	SUM(GoodsIssueBalance.QuantityBalance) AS QuantityBalance
	|INTO TT_GoodsIssueBalance
	|FROM
	|	(SELECT
	|		GoodsIssueBalance.SalesOrder AS SalesOrder,
	|		GoodsIssueBalance.GoodsIssue AS GoodsIssue,
	|		GoodsIssueBalance.Products AS Products,
	|		GoodsIssueBalance.Characteristic AS Characteristic,
	|		GoodsIssueBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.GoodsShippedNotInvoiced.Balance(
	|				,
	|				GoodsIssue IN
	|					(SELECT
	|						TT_GoodsIssues.Ref
	|					FROM
	|						TT_GoodsIssues)) AS GoodsIssueBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsGoodsIssue.SalesOrder,
	|		DocumentRegisterRecordsGoodsIssue.GoodsIssue,
	|		DocumentRegisterRecordsGoodsIssue.Products,
	|		DocumentRegisterRecordsGoodsIssue.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsGoodsIssue.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsGoodsIssue.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsGoodsIssue.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.GoodsShippedNotInvoiced AS DocumentRegisterRecordsGoodsIssue
	|	WHERE
	|		DocumentRegisterRecordsGoodsIssue.Recorder = &Ref) AS GoodsIssueBalance
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON GoodsIssueBalance.Products = ProductsCatalog.Ref
	|
	|GROUP BY
	|	GoodsIssueBalance.SalesOrder,
	|	GoodsIssueBalance.GoodsIssue,
	|	GoodsIssueBalance.Products,
	|	GoodsIssueBalance.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsIssueProducts.LineNumber AS LineNumber,
	|	GoodsIssueProducts.Products AS Products,
	|	GoodsIssueProducts.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ProductsTypeInventory,
	|	GoodsIssueProducts.Characteristic AS Characteristic,
	|	GoodsIssueProducts.Batch AS Batch,
	|	GoodsIssueProducts.Quantity AS Quantity,
	|	GoodsIssueProducts.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	GoodsIssueProducts.Ref AS GoodsIssue,
	|	GoodsIssueProducts.Order AS Order,
	|	GoodsIssueProducts.Contract AS Contract,
	|	GoodsIssueProducts.SerialNumbers AS SerialNumbers,
	|	TT_GoodsIssues.PointInTime AS PointInTime,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsIssueProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsIssueProducts.GoodsShippedNotInvoicedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GoodsShippedNotInvoicedGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsIssueProducts.UnearnedRevenueGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS UnearnedRevenueGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsIssueProducts.RevenueGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS RevenueGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsIssueProducts.COGSGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS COGSGLAccount,
	|	GoodsIssueProducts.BundleProduct AS BundleProduct,
	|	GoodsIssueProducts.BundleCharacteristic AS BundleCharacteristic,
	|	GoodsIssueProducts.Project AS Project,
	|	TT_GoodsIssues.DropShipping AS DropShipping
	|INTO TT_Inventory
	|FROM
	|	Document.GoodsIssue.Products AS GoodsIssueProducts
	|		INNER JOIN TT_GoodsIssues AS TT_GoodsIssues
	|		ON GoodsIssueProducts.Ref = TT_GoodsIssues.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON GoodsIssueProducts.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON GoodsIssueProducts.MeasurementUnit = UOM.Ref
	|WHERE
	|	(GoodsIssueProducts.Contract = &Contract
	|			OR &Contract = UNDEFINED)
	|	AND GoodsIssueProducts.SalesInvoice = VALUE(Document.SalesInvoice.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	TT_Inventory.Order AS Order,
	|	TT_Inventory.GoodsIssue AS GoodsIssue,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor AS BaseQuantity,
	|	SUM(TT_InventoryCumulative.Quantity * TT_InventoryCumulative.Factor) AS BaseQuantityCumulative,
	|	TT_Inventory.Project AS Project
	|INTO TT_InventoryCumulative
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_Inventory AS TT_InventoryCumulative
	|		ON TT_Inventory.Products = TT_InventoryCumulative.Products
	|			AND TT_Inventory.Characteristic = TT_InventoryCumulative.Characteristic
	|			AND TT_Inventory.Batch = TT_InventoryCumulative.Batch
	|			AND TT_Inventory.Order = TT_InventoryCumulative.Order
	|			AND TT_Inventory.GoodsIssue = TT_InventoryCumulative.GoodsIssue
	|			AND TT_Inventory.LineNumber >= TT_InventoryCumulative.LineNumber
	|			AND TT_Inventory.Project = TT_InventoryCumulative.Project
	|
	|GROUP BY
	|	TT_Inventory.LineNumber,
	|	TT_Inventory.Products,
	|	TT_Inventory.Characteristic,
	|	TT_Inventory.Batch,
	|	TT_Inventory.Order,
	|	TT_Inventory.GoodsIssue,
	|	TT_Inventory.Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor,
	|	TT_Inventory.Project
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryCumulative.LineNumber AS LineNumber,
	|	TT_InventoryCumulative.Products AS Products,
	|	TT_InventoryCumulative.Characteristic AS Characteristic,
	|	TT_InventoryCumulative.Batch AS Batch,
	|	TT_InventoryCumulative.Order AS Order,
	|	TT_InventoryCumulative.GoodsIssue AS GoodsIssue,
	|	TT_InventoryCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_AlreadyInvoiced.BaseQuantity > TT_InventoryCumulative.BaseQuantityCumulative - TT_InventoryCumulative.BaseQuantity
	|			THEN TT_InventoryCumulative.BaseQuantityCumulative - TT_AlreadyInvoiced.BaseQuantity
	|		ELSE TT_InventoryCumulative.BaseQuantity
	|	END AS BaseQuantity,
	|	TT_InventoryCumulative.Project AS Project
	|INTO TT_InventoryNotYetInvoiced
	|FROM
	|	TT_InventoryCumulative AS TT_InventoryCumulative
	|		LEFT JOIN TT_AlreadyInvoiced AS TT_AlreadyInvoiced
	|		ON TT_InventoryCumulative.Products = TT_AlreadyInvoiced.Products
	|			AND TT_InventoryCumulative.Characteristic = TT_AlreadyInvoiced.Characteristic
	|			AND TT_InventoryCumulative.Batch = TT_AlreadyInvoiced.Batch
	|			AND TT_InventoryCumulative.Order = TT_AlreadyInvoiced.Order
	|			AND TT_InventoryCumulative.GoodsIssue = TT_AlreadyInvoiced.GoodsIssue
	|WHERE
	|	ISNULL(TT_AlreadyInvoiced.BaseQuantity, 0) < TT_InventoryCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryNotYetInvoiced.LineNumber AS LineNumber,
	|	TT_InventoryNotYetInvoiced.Products AS Products,
	|	TT_InventoryNotYetInvoiced.Characteristic AS Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch AS Batch,
	|	TT_InventoryNotYetInvoiced.Order AS Order,
	|	TT_InventoryNotYetInvoiced.GoodsIssue AS GoodsIssue,
	|	TT_InventoryNotYetInvoiced.Factor AS Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity AS BaseQuantity,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.BaseQuantity) AS BaseQuantityCumulative,
	|	TT_InventoryNotYetInvoiced.Project AS Project
	|INTO TT_InventoryNotYetInvoicedCumulative
	|FROM
	|	TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoiced
	|		INNER JOIN TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoicedCumulative
	|		ON TT_InventoryNotYetInvoiced.Products = TT_InventoryNotYetInvoicedCumulative.Products
	|			AND TT_InventoryNotYetInvoiced.Characteristic = TT_InventoryNotYetInvoicedCumulative.Characteristic
	|			AND TT_InventoryNotYetInvoiced.Batch = TT_InventoryNotYetInvoicedCumulative.Batch
	|			AND TT_InventoryNotYetInvoiced.Order = TT_InventoryNotYetInvoicedCumulative.Order
	|			AND TT_InventoryNotYetInvoiced.GoodsIssue = TT_InventoryNotYetInvoicedCumulative.GoodsIssue
	|			AND TT_InventoryNotYetInvoiced.LineNumber >= TT_InventoryNotYetInvoicedCumulative.LineNumber
	|			AND TT_InventoryNotYetInvoiced.Project = TT_InventoryNotYetInvoicedCumulative.Project
	|
	|GROUP BY
	|	TT_InventoryNotYetInvoiced.LineNumber,
	|	TT_InventoryNotYetInvoiced.Products,
	|	TT_InventoryNotYetInvoiced.Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch,
	|	TT_InventoryNotYetInvoiced.Order,
	|	TT_InventoryNotYetInvoiced.GoodsIssue,
	|	TT_InventoryNotYetInvoiced.Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity,
	|	TT_InventoryNotYetInvoiced.Project
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryNotYetInvoicedCumulative.LineNumber AS LineNumber,
	|	TT_InventoryNotYetInvoicedCumulative.Products AS Products,
	|	TT_InventoryNotYetInvoicedCumulative.Characteristic AS Characteristic,
	|	TT_InventoryNotYetInvoicedCumulative.Batch AS Batch,
	|	TT_InventoryNotYetInvoicedCumulative.Order AS Order,
	|	TT_InventoryNotYetInvoicedCumulative.GoodsIssue AS GoodsIssue,
	|	TT_InventoryNotYetInvoicedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_GoodsIssueBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|		WHEN TT_GoodsIssueBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|			THEN TT_GoodsIssueBalance.QuantityBalance - (TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity)
	|	END AS BaseQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.Project AS Project
	|INTO TT_InventoryToBeInvoiced
	|FROM
	|	TT_InventoryNotYetInvoicedCumulative AS TT_InventoryNotYetInvoicedCumulative
	|		INNER JOIN TT_GoodsIssueBalance AS TT_GoodsIssueBalance
	|		ON TT_InventoryNotYetInvoicedCumulative.Products = TT_GoodsIssueBalance.Products
	|			AND TT_InventoryNotYetInvoicedCumulative.Characteristic = TT_GoodsIssueBalance.Characteristic
	|			AND TT_InventoryNotYetInvoicedCumulative.Order = TT_GoodsIssueBalance.SalesOrder
	|			AND TT_InventoryNotYetInvoicedCumulative.GoodsIssue = TT_GoodsIssueBalance.GoodsIssue
	|WHERE
	|	TT_GoodsIssueBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.ProductsTypeInventory AS ProductsTypeInventory,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Quantity
	|		ELSE CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))
	|	END AS Quantity,
	|	TT_Inventory.MeasurementUnit AS MeasurementUnit,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Order AS Order,
	|	TT_Inventory.Contract AS Contract,
	|	TT_Inventory.GoodsIssue AS GoodsIssue,
	|	TT_Inventory.SerialNumbers AS SerialNumbers,
	|	TT_Inventory.PointInTime AS PointInTime,
	|	SalesOrderInventory.Price AS Price,
	|	ISNULL(SalesOrderInventory.DiscountMarkupPercent, 0) AS DiscountMarkupPercent,
	|	CASE
	|		WHEN AccountingPolicySliceLast.RegisteredForVAT
	|			THEN ISNULL(SalesOrderInventory.VATRate, CatProducts.VATRate)
	|		ELSE VALUE(Catalog.VATRates.Exempt)
	|	END AS VATRate,
	|	ISNULL(SalesOrderInventory.AutomaticDiscountsPercent, 0) AS AutomaticDiscountsPercent,
	|	ISNULL(TT_Inventory.Quantity * SalesOrderInventory.AutomaticDiscountAmount / SalesOrderInventory.Quantity, 0) AS AutomaticDiscountAmount,
	|	ISNULL(SalesOrderInventory.Quantity, 0) AS QuantityOrd,
	|	TT_Inventory.InventoryGLAccount AS InventoryGLAccount,
	|	TT_Inventory.GoodsShippedNotInvoicedGLAccount AS GoodsShippedNotInvoicedGLAccount,
	|	TT_Inventory.UnearnedRevenueGLAccount AS UnearnedRevenueGLAccount,
	|	TT_Inventory.RevenueGLAccount AS RevenueGLAccount,
	|	TT_Inventory.COGSGLAccount AS COGSGLAccount,
	|	SalesOrderInventory.Specification AS Specification,
	|	SalesOrderInventory.BundleProduct AS BundleProduct,
	|	SalesOrderInventory.BundleCharacteristic AS BundleCharacteristic,
	|	SalesOrderInventory.CostShare AS CostShare,
	|	TT_Inventory.Project AS Project,
	|	TT_Inventory.DropShipping AS DropShipping
	|INTO TT_WithOrders
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_InventoryToBeInvoiced AS TT_InventoryToBeInvoiced
	|		ON TT_Inventory.LineNumber = TT_InventoryToBeInvoiced.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryToBeInvoiced.Order
	|			AND TT_Inventory.GoodsIssue = TT_InventoryToBeInvoiced.GoodsIssue
	|		LEFT JOIN Document.SalesOrder.Inventory AS SalesOrderInventory
	|		ON TT_Inventory.Order = SalesOrderInventory.Ref
	|			AND TT_Inventory.Products = SalesOrderInventory.Products
	|			AND TT_Inventory.Characteristic = SalesOrderInventory.Characteristic
	|			AND TT_Inventory.MeasurementUnit = SalesOrderInventory.MeasurementUnit
	|			AND TT_Inventory.BundleProduct = SalesOrderInventory.BundleProduct
	|			AND TT_Inventory.BundleCharacteristic = SalesOrderInventory.BundleCharacteristic
	|		LEFT JOIN Catalog.Products AS CatProducts
	|		ON TT_Inventory.Products = CatProducts.Ref
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(, Company = &Company) AS AccountingPolicySliceLast
	|		ON (TRUE)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_WithOrders.LineNumber AS LineNumber,
	|	TT_WithOrders.Products AS Products,
	|	TT_WithOrders.ProductsTypeInventory AS ProductsTypeInventory,
	|	TT_WithOrders.Characteristic AS Characteristic,
	|	TT_WithOrders.Batch AS Batch,
	|	TT_WithOrders.Quantity AS Quantity,
	|	TT_WithOrders.MeasurementUnit AS MeasurementUnit,
	|	TT_WithOrders.Factor AS Factor,
	|	TT_WithOrders.Order AS Order,
	|	SalesOrder.SalesRep AS SalesRep,
	|	TT_WithOrders.Contract AS Contract,
	|	TT_WithOrders.GoodsIssue AS GoodsIssue,
	|	TT_WithOrders.PointInTime AS PointInTime,
	|	MAX(ISNULL(ISNULL(TT_WithOrders.Price, PricesSliceLast.Price), 0)) AS Price,
	|	MAX(TT_WithOrders.DiscountMarkupPercent) AS DiscountMarkupPercent,
	|	TT_WithOrders.VATRate AS VATRate,
	|	MAX(TT_WithOrders.AutomaticDiscountsPercent) AS AutomaticDiscountsPercent,
	|	MAX(TT_WithOrders.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
	|	MAX(TT_WithOrders.QuantityOrd) AS QuantityOrd,
	|	TT_WithOrders.InventoryGLAccount AS InventoryGLAccount,
	|	TT_WithOrders.GoodsShippedNotInvoicedGLAccount AS GoodsShippedNotInvoicedGLAccount,
	|	TT_WithOrders.UnearnedRevenueGLAccount AS UnearnedRevenueGLAccount,
	|	TT_WithOrders.RevenueGLAccount AS RevenueGLAccount,
	|	TT_WithOrders.COGSGLAccount AS COGSGLAccount,
	|	TT_WithOrders.Specification AS Specification,
	|	TT_WithOrders.BundleProduct AS BundleProduct,
	|	TT_WithOrders.BundleCharacteristic AS BundleCharacteristic,
	|	TT_WithOrders.CostShare AS CostShare,
	|	TT_WithOrders.Project AS Project,
	|	TT_WithOrders.DropShipping AS DropShipping
	|FROM
	|	TT_WithOrders AS TT_WithOrders
	|		LEFT JOIN InformationRegister.Prices.SliceLast AS PricesSliceLast
	|		ON TT_WithOrders.Products = PricesSliceLast.Products
	|			AND TT_WithOrders.Characteristic = PricesSliceLast.Characteristic
	|			AND TT_WithOrders.MeasurementUnit = PricesSliceLast.MeasurementUnit
	|			AND TT_WithOrders.Contract.PriceKind = PricesSliceLast.PriceKind
	|		LEFT JOIN Document.SalesOrder AS SalesOrder
	|		ON TT_WithOrders.Order = SalesOrder.Ref
	|
	|GROUP BY
	|	TT_WithOrders.MeasurementUnit,
	|	TT_WithOrders.Products,
	|	TT_WithOrders.ProductsTypeInventory,
	|	TT_WithOrders.Order,
	|	SalesOrder.SalesRep,
	|	TT_WithOrders.Batch,
	|	TT_WithOrders.Characteristic,
	|	TT_WithOrders.Contract,
	|	TT_WithOrders.GoodsIssue,
	|	TT_WithOrders.PointInTime,
	|	TT_WithOrders.VATRate,
	|	TT_WithOrders.LineNumber,
	|	TT_WithOrders.Quantity,
	|	TT_WithOrders.Factor,
	|	TT_WithOrders.InventoryGLAccount,
	|	TT_WithOrders.GoodsShippedNotInvoicedGLAccount,
	|	TT_WithOrders.UnearnedRevenueGLAccount,
	|	TT_WithOrders.RevenueGLAccount,
	|	TT_WithOrders.COGSGLAccount,
	|	TT_WithOrders.Specification,
	|	TT_WithOrders.BundleProduct,
	|	TT_WithOrders.BundleCharacteristic,
	|	TT_WithOrders.CostShare,
	|	TT_WithOrders.Project,
	|	TT_WithOrders.DropShipping";
	
	Contract = Undefined;
	
	FilterData.Property("Contract", Contract);
	Query.SetParameter("Contract", Contract);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	If FilterData.Property("GoodsIssuesArray") Then
		FilterString = "GoodsIssue.Ref IN(&GoodsIssuesArray)";
		Query.SetParameter("GoodsIssuesArray", FilterData.GoodsIssuesArray);
	Else
		
		FilterString = "";
		NotFirstItem = False;
		
		For Each FilterItem In FilterData Do
			
			If NotFirstItem Then
				FilterString = FilterString + "
				|	AND ";
			Else
				NotFirstItem = True;
			EndIf;
			
			FilterString = FilterString + "GoodsIssue." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
			
		EndDo;
		
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&GoodsIssuesConditions", FilterString);
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(DocumentData.Company));
	
	StructureData = New Structure;
	StructureData.Insert("ObjectParameters", DocumentData);
	
	Inventory.Clear();
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	While Selection.Next() Do
		
		TabularSectionRow = Inventory.Add();
		
		FillPropertyValues(TabularSectionRow, Selection);
		
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
		
		If TabularSectionRow.DiscountMarkupPercent = 100 Then
			
			TabularSectionRow.Amount = 0;
			
		ElsIf Not TabularSectionRow.DiscountMarkupPercent = 0
			And Not TabularSectionRow.Quantity = 0 Then
			
			TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
			
		EndIf;
		
		VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
		TabularSectionRow.VATAmount = ?(DocumentData.AmountIncludesVAT, 
										TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
										TabularSectionRow.Amount * VATRate / 100);

		TabularSectionRow.Total = TabularSectionRow.Amount + ?(DocumentData.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
		
	EndDo;
		
EndProcedure

Procedure FillBySupplierInvoices(DocumentData, FilterData, Inventory, SerialNumbers) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SupplierInvoice.Ref AS Ref,
	|	CASE
	|		WHEN SupplierInvoice.OperationKind = VALUE(Enum.OperationTypesSupplierInvoice.DropShipping)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS DropShipping
	|INTO TT_SupplierInvoices
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	&SupplierInvoicesConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SupplierInvoiceProducts.Products AS Products,
	|	SupplierInvoiceProducts.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ProductsTypeInventory,
	|	SupplierInvoiceProducts.Characteristic AS Characteristic,
	|	SupplierInvoiceProducts.Batch AS Batch,
	|	SupplierInvoiceProducts.Quantity AS Quantity,
	|	SupplierInvoiceProducts.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	SupplierInvoiceProducts.SerialNumbers AS SerialNumbers,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoiceProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	SupplierInvoiceProducts.VATRate AS VATRate,
	|	SupplierInvoiceProducts.ReverseChargeVATRate AS ReverseChargeVATRate,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoiceProducts.GoodsReceivedNotInvoicedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GoodsReceivedNotInvoicedGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoiceProducts.GoodsInvoicedNotDeliveredGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GoodsInvoicedNotDeliveredGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoiceProducts.VATInputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATInputGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoiceProducts.VATOutputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATOutputGLAccount,
	|	CASE
	|		WHEN ProductsCatalog.UseSerialNumbers
	|			THEN SupplierInvoiceProducts.ConnectionKey
	|		ELSE UNDEFINED
	|	END AS ConnectionKey,
	|	CASE
	|		WHEN ProductsCatalog.UseSerialNumbers
	|			THEN SupplierInvoiceProducts.Ref
	|		ELSE UNDEFINED
	|	END AS Ref,
	|	ProductsCatalog.UseSerialNumbers AS UseSerialNumbers,
	|	SupplierInvoiceProducts.Project AS Project,
	|	TT_SupplierInvoices.DropShipping AS DropShipping
	|INTO TT_Inventory
	|FROM
	|	Document.SupplierInvoice.Inventory AS SupplierInvoiceProducts
	|		INNER JOIN TT_SupplierInvoices AS TT_SupplierInvoices
	|		ON SupplierInvoiceProducts.Ref = TT_SupplierInvoices.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SupplierInvoiceProducts.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SupplierInvoiceProducts.MeasurementUnit = UOM.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.ProductsTypeInventory AS ProductsTypeInventory,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	SUM(TT_Inventory.Quantity) AS Quantity,
	|	TT_Inventory.MeasurementUnit AS MeasurementUnit,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.SerialNumbers AS SerialNumbers,
	|	TT_Inventory.VATRate AS VATRate,
	|	TT_Inventory.InventoryGLAccount AS InventoryGLAccount,
	|	TT_Inventory.GoodsReceivedNotInvoicedGLAccount AS GoodsReceivedNotInvoicedGLAccount,
	|	TT_Inventory.GoodsInvoicedNotDeliveredGLAccount AS GoodsInvoicedNotDeliveredGLAccount,
	|	TT_Inventory.VATInputGLAccount AS VATInputGLAccount,
	|	TT_Inventory.VATOutputGLAccount AS VATOutputGLAccount,
	|	TT_Inventory.ConnectionKey AS ConnectionKey,
	|	TT_Inventory.Ref AS Ref,
	|	TT_Inventory.UseSerialNumbers AS UseSerialNumbers,
	|	TT_Inventory.Project AS Project,
	|	VALUE(Catalog.PriceTypes.Wholesale) AS PriceKind,
	|	TT_Inventory.DropShipping AS DropShipping
	|FROM
	|	TT_Inventory AS TT_Inventory
	|
	|GROUP BY
	|	TT_Inventory.Products,
	|	TT_Inventory.ProductsTypeInventory,
	|	TT_Inventory.GoodsReceivedNotInvoicedGLAccount,
	|	TT_Inventory.SerialNumbers,
	|	TT_Inventory.GoodsInvoicedNotDeliveredGLAccount,
	|	TT_Inventory.MeasurementUnit,
	|	TT_Inventory.Batch,
	|	TT_Inventory.Ref,
	|	TT_Inventory.VATRate,
	|	TT_Inventory.VATInputGLAccount,
	|	TT_Inventory.InventoryGLAccount,
	|	TT_Inventory.UseSerialNumbers,
	|	TT_Inventory.VATOutputGLAccount,
	|	TT_Inventory.Characteristic,
	|	TT_Inventory.Factor,
	|	TT_Inventory.ConnectionKey,
	|	TT_Inventory.Project,
	|	TT_Inventory.DropShipping
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SupplierInvoiceSerialNumbers.Ref AS Ref,
	|	SupplierInvoiceSerialNumbers.SerialNumber AS SerialNumber,
	|	SupplierInvoiceSerialNumbers.ConnectionKey AS ConnectionKey
	|FROM
	|	TT_SupplierInvoices AS TT_SupplierInvoices
	|		INNER JOIN Document.SupplierInvoice.SerialNumbers AS SupplierInvoiceSerialNumbers
	|		ON TT_SupplierInvoices.Ref = SupplierInvoiceSerialNumbers.Ref";
		
	If FilterData.Property("InvoicesArray") Then
		FilterString = "SupplierInvoice.Ref IN(&InvoicesArray)";
		Query.SetParameter("InvoicesArray", FilterData.InvoicesArray);
	Else
		
		FilterString = "";
		NotFirstItem = False;
		
		For Each FilterItem In FilterData Do
			
			If NotFirstItem Then
				FilterString = FilterString + "
				|	AND ";
			Else
				NotFirstItem = True;
			EndIf;
			
			FilterString = FilterString + "SupplierInvoice." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
			
		EndDo;
		
	EndIf;
	
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text = StrReplace(Query.Text, "&SupplierInvoicesConditions", FilterString);
	
	StructureData = New Structure;
	StructureData.Insert("ObjectParameters", DocumentData);
	
	Inventory.Clear();
	
	QueryResults = Query.ExecuteBatch();

	
	Selection = QueryResults[2].Select();
	SerialNumberTable = QueryResults[3].Unload();

	While Selection.Next() Do
		
		NewRow = Inventory.Add();
		
		FillPropertyValues(NewRow, Selection);
		
		NewRow.ProductsTypeInventory = (NewRow.Products.ProductsType = Enums.ProductsTypes.InventoryItem);
		
		DataStructure = New Structure("Products, Characteristic, Factor, DocumentCurrency, Company, PriceKind,
			|AmountIncludesVAT, VATRate");
		
		FillPropertyValues(DataStructure, DocumentData);
		DataStructure.Insert("ProcessingDate", DocumentData.Date);
		FillPropertyValues(DataStructure, Selection);
				
		NewRow.Price = DriveServer.GetProductsPriceByPriceKind(DataStructure);
		NewRow.Amount = NewRow.Price * NewRow.Quantity;
		
		// SerialNumbers
		
		If Selection.UseSerialNumbers Then
			
			StructureOfTheSearch = New Structure ("Ref, ConnectionKey");
			FillPropertyValues(StructureOfTheSearch, Selection);
			
			RowsSerialNumbers = SerialNumberTable.FindRows(StructureOfTheSearch);
			
			For Each SerialNumber In RowsSerialNumbers Do
				
				WorkWithSerialNumbersClientServer.FillConnectionKey(Inventory, NewRow, "ConnectionKey");
				NewRowSerialNumber = SerialNumbers.Add();
				NewRowSerialNumber.ConnectionKey = NewRow.ConnectionKey;
				NewRowSerialNumber.SerialNumber = SerialNumber.SerialNumber;

			EndDo;
	
			NewRow.SerialNumbers = WorkWithSerialNumbers.StringSerialNumbers(SerialNumbers, NewRow.ConnectionKey);

		EndIf;

	EndDo;
	
	If DocumentData.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		For Each TabularSectionRow In Inventory Do
			
			If ValueIsFilled(TabularSectionRow.Products.VATRate) Then
				TabularSectionRow.VATRate = TabularSectionRow.Products.VATRate;
			Else
				TabularSectionRow.VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(DocumentData.Date, DocumentData.Company);
			EndIf;	
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(DocumentData.AmountIncludesVAT, 
			TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
			TabularSectionRow.Amount * VATRate / 100);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(DocumentData.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
	Else
		
		If DocumentData.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then	
			DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;	
		
		For Each TabularSectionRow In Inventory Do
			
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure FillColumnReserveByReserves(DocumentData, Inventory) Export

	Query = New Query;
	Query.Text =
	"SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	CAST(TableInventory.Products AS Catalog.Products) AS Products,
	|	TableInventory.ProductsTypeInventory AS ProductsTypeInventory,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Quantity AS Quantity,
	|	0 AS Reserve,
	|	TableInventory.MeasurementUnit AS MeasurementUnit,
	|	TableInventory.Price AS Price,
	|	TableInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	TableInventory.Amount AS Amount,
	|	TableInventory.VATRate AS VATRate,
	|	TableInventory.VATAmount AS VATAmount,
	|	TableInventory.Total AS Total,
	|	CASE
	|		WHEN &OrderInHeader
	|			THEN &Order
	|		WHEN TableInventory.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableInventory.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableInventory.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	TableInventory.Content AS Content,
	|	TableInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	TableInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	TableInventory.ConnectionKey AS ConnectionKey,
	|	TableInventory.SerialNumbers AS SerialNumbers,
	|	TableInventory.BundleProduct AS BundleProduct,
	|	TableInventory.BundleCharacteristic AS BundleCharacteristic,
	|	TableInventory.CostShare AS CostShare,
	|	TableInventory.Specification AS Specification,
	|	VALUE(Document.PackingSlip.EmptyRef) AS PackingSlip,
	|	TableInventory.SalesRep AS SalesRep,
	|	TableInventory.Taxable AS Taxable,
	|	TableInventory.Project AS Project,
	|	TableInventory.DropShipping AS DropShipping,
	|	TableInventory.RevenueItem AS RevenueItem,
	|	TableInventory.COGSItem AS COGSItem
	|INTO TT_TableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_TableInventory.LineNumber AS LineNumber,
	|	TT_TableInventory.Products AS Products,
	|	TT_TableInventory.ProductsTypeInventory AS ProductsTypeInventory,
	|	TT_TableInventory.Characteristic AS Characteristic,
	|	TT_TableInventory.Batch AS Batch,
	|	TT_TableInventory.Quantity AS Quantity,
	|	TT_TableInventory.Reserve AS Reserve,
	|	TT_TableInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	TT_TableInventory.Price AS Price,
	|	TT_TableInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	TT_TableInventory.Amount AS Amount,
	|	TT_TableInventory.VATRate AS VATRate,
	|	TT_TableInventory.VATAmount AS VATAmount,
	|	TT_TableInventory.Total AS Total,
	|	TT_TableInventory.Order AS Order,
	|	TT_TableInventory.Content AS Content,
	|	TT_TableInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	TT_TableInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	TT_TableInventory.ConnectionKey AS ConnectionKey,
	|	TT_TableInventory.SerialNumbers AS SerialNumbers,
	|	TT_TableInventory.BundleProduct AS BundleProduct,
	|	TT_TableInventory.BundleCharacteristic AS BundleCharacteristic,
	|	TT_TableInventory.CostShare AS CostShare,
	|	TT_TableInventory.Specification AS Specification,
	|	TT_TableInventory.PackingSlip AS PackingSlip,
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	TT_TableInventory.SalesRep AS SalesRep,
	|	TT_TableInventory.Taxable AS Taxable,
	|	TT_TableInventory.Project AS Project,
	|	TT_TableInventory.DropShipping AS DropShipping,
	|	TT_TableInventory.RevenueItem AS RevenueItem,
	|	TT_TableInventory.COGSItem AS COGSItem
	|INTO TT_InventoryToFillReserve
	|FROM
	|	TT_TableInventory AS TT_TableInventory
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON TT_TableInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON TT_TableInventory.MeasurementUnit = UOM.Ref";
	
	Query.Text = Query.Text + GetFillReserveColumnQueryText();
	
	If DocumentData.Property("SalesOrderPosition") Then
		OrderInHeader = DocumentData.SalesOrderPosition = Enums.AttributeStationing.InHeader;
	Else
		OrderInHeader = False;
	EndIf;
	Query.SetParameter("TableInventory", Inventory.Unload());
	Query.SetParameter("OrderInHeader", OrderInHeader);
	Query.SetParameter("Order", ?(DocumentData.Property("Order") And ValueIsFilled(DocumentData.Order), DocumentData.Order, Undefined));
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(DocumentData.Company));
	Query.SetParameter("StructuralUnit", DocumentData.StructuralUnit);
	
	Inventory.Load(Query.Execute().Unload());
	
EndProcedure

Function GetFillReserveColumnQueryText()
	
	Return DriveClientServer.GetQueryDelimeter() +
	"SELECT ALLOWED
	|	ReservedProductsBalances.Products AS Products,
	|	ReservedProductsBalances.Characteristic AS Characteristic,
	|	ReservedProductsBalances.Batch AS Batch,
	|	ReservedProductsBalances.SalesOrder AS Order,
	|	SUM(ReservedProductsBalances.QuantityBalance) AS QuantityBalance
	|INTO TT_ReservedProductsBalances
	|FROM
	|	(SELECT
	|		ReservedProductsBalances.SalesOrder AS SalesOrder,
	|		ReservedProductsBalances.Products AS Products,
	|		ReservedProductsBalances.Characteristic AS Characteristic,
	|		ReservedProductsBalances.Batch AS Batch,
	|		ReservedProductsBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.ReservedProducts.Balance(
	|				,
	|				Company = &Company
	|					AND StructuralUnit = &StructuralUnit
	|					AND SalesOrder <> UNDEFINED
	|					AND (Products, Characteristic, Batch, SalesOrder) IN
	|						(SELECT
	|							TT_InventoryToFillReserve.Products,
	|							TT_InventoryToFillReserve.Characteristic,
	|							TT_InventoryToFillReserve.Batch,
	|							TT_InventoryToFillReserve.Order
	|						FROM
	|							TT_InventoryToFillReserve AS TT_InventoryToFillReserve)) AS ReservedProductsBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsReservedProducts.SalesOrder,
	|		DocumentRegisterRecordsReservedProducts.Products,
	|		DocumentRegisterRecordsReservedProducts.Characteristic,
	|		DocumentRegisterRecordsReservedProducts.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsReservedProducts.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRegisterRecordsReservedProducts.Quantity
	|			ELSE -DocumentRegisterRecordsReservedProducts.Quantity
	|		END
	|	FROM
	|		AccumulationRegister.ReservedProducts AS DocumentRegisterRecordsReservedProducts
	|	WHERE
	|		DocumentRegisterRecordsReservedProducts.Recorder = &Ref
	|		AND DocumentRegisterRecordsReservedProducts.SalesOrder <> UNDEFINED) AS ReservedProductsBalances
	|
	|GROUP BY
	|	ReservedProductsBalances.SalesOrder,
	|	ReservedProductsBalances.Products,
	|	ReservedProductsBalances.Characteristic,
	|	ReservedProductsBalances.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryToFillReserve.LineNumber AS LineNumber,
	|	TT_InventoryToFillReserve.Products AS Products,
	|	TT_InventoryToFillReserve.Characteristic AS Characteristic,
	|	TT_InventoryToFillReserve.Batch AS Batch,
	|	TT_InventoryToFillReserve.Order AS Order,
	|	TT_InventoryToFillReserve.Factor AS Factor,
	|	TT_InventoryToFillReserve.Quantity * TT_InventoryToFillReserve.Factor AS BaseQuantity,
	|	SUM(TT_InventoryToFillReserveCumulative.Quantity * TT_InventoryToFillReserveCumulative.Factor) AS BaseQuantityCumulative
	|INTO TT_InventoryToFillReserveCumulative
	|FROM
	|	TT_InventoryToFillReserve AS TT_InventoryToFillReserve
	|		INNER JOIN TT_InventoryToFillReserve AS TT_InventoryToFillReserveCumulative
	|		ON TT_InventoryToFillReserve.Products = TT_InventoryToFillReserveCumulative.Products
	|			AND TT_InventoryToFillReserve.Characteristic = TT_InventoryToFillReserveCumulative.Characteristic
	|			AND TT_InventoryToFillReserve.Batch = TT_InventoryToFillReserveCumulative.Batch
	|			AND TT_InventoryToFillReserve.Order = TT_InventoryToFillReserveCumulative.Order
	|			AND TT_InventoryToFillReserve.LineNumber >= TT_InventoryToFillReserveCumulative.LineNumber
	|
	|GROUP BY
	|	TT_InventoryToFillReserve.LineNumber,
	|	TT_InventoryToFillReserve.Characteristic,
	|	TT_InventoryToFillReserve.Batch,
	|	TT_InventoryToFillReserve.Order,
	|	TT_InventoryToFillReserve.Products,
	|	TT_InventoryToFillReserve.Factor,
	|	TT_InventoryToFillReserve.Quantity * TT_InventoryToFillReserve.Factor
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryToFillReserveCumulative.LineNumber AS LineNumber,
	|	TT_InventoryToFillReserveCumulative.Order AS Order,
	|	TT_InventoryToFillReserveCumulative.Factor AS Factor,
	|	TT_InventoryToFillReserveCumulative.BaseQuantity AS BaseQuantity,
	|	CASE
	|		WHEN TT_ReservedProductsBalances.QuantityBalance > TT_InventoryToFillReserveCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryToFillReserveCumulative.BaseQuantity
	|		WHEN TT_ReservedProductsBalances.QuantityBalance > TT_InventoryToFillReserveCumulative.BaseQuantityCumulative - TT_InventoryToFillReserveCumulative.BaseQuantity
	|			THEN TT_ReservedProductsBalances.QuantityBalance - (TT_InventoryToFillReserveCumulative.BaseQuantityCumulative - TT_InventoryToFillReserveCumulative.BaseQuantity)
	|		ELSE 0
	|	END AS BaseReserve
	|INTO TT_InventoryReserve
	|FROM
	|	TT_InventoryToFillReserveCumulative AS TT_InventoryToFillReserveCumulative
	|		LEFT JOIN TT_ReservedProductsBalances AS TT_ReservedProductsBalances
	|		ON TT_InventoryToFillReserveCumulative.Products = TT_ReservedProductsBalances.Products
	|			AND TT_InventoryToFillReserveCumulative.Characteristic = TT_ReservedProductsBalances.Characteristic
	|			AND TT_InventoryToFillReserveCumulative.Batch = TT_ReservedProductsBalances.Batch
	|			AND TT_InventoryToFillReserveCumulative.Order = TT_ReservedProductsBalances.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.ProductsTypeInventory AS ProductsTypeInventory,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	TT_Inventory.Quantity AS Quantity,
	|	CASE
	|		WHEN TT_InventoryReserve.BaseReserve = TT_InventoryReserve.BaseQuantity
	|			THEN TT_Inventory.Quantity
	|		ELSE TT_InventoryReserve.BaseReserve / TT_InventoryReserve.Factor
	|	END AS Reserve,
	|	TT_Inventory.MeasurementUnit AS MeasurementUnit,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Price AS Price,
	|	TT_Inventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	TT_Inventory.Amount AS Amount,
	|	TT_Inventory.VATRate AS VATRate,
	|	TT_Inventory.VATAmount AS VATAmount,
	|	TT_Inventory.Total AS Total,
	|	TT_Inventory.Order AS Order,
	|	ISNULL(TT_Inventory.SalesRep, VALUE(Catalog.Employees.EmptyRef)) AS SalesRep,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssue,
	|	TT_Inventory.Content AS Content,
	|	TT_Inventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	TT_Inventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	TT_Inventory.SerialNumbers AS SerialNumbers,
	|	TT_Inventory.Specification AS Specification,
	|	TT_Inventory.BundleProduct AS BundleProduct,
	|	TT_Inventory.BundleCharacteristic AS BundleCharacteristic,
	|	TT_Inventory.CostShare AS CostShare,
	|	TT_Inventory.ConnectionKey AS ConnectionKey,
	|	TT_Inventory.PackingSlip AS PackingSlip,
	|	TT_Inventory.UseSerialNumbers AS UseSerialNumbers,
	|	TT_Inventory.Taxable AS Taxable,
	|	TT_Inventory.Project AS Project,
	|	TT_Inventory.DropShipping AS DropShipping,
	|	TT_Inventory.RevenueItem AS RevenueItem,
	|	TT_Inventory.COGSItem AS COGSItem
	|FROM
	|	TT_InventoryToFillReserve AS TT_Inventory
	|		LEFT JOIN TT_InventoryReserve AS TT_InventoryReserve
	|		ON TT_Inventory.LineNumber = TT_InventoryReserve.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryReserve.Order";
	
EndFunction

Function GetFillWorkOrderReserveColumnQueryText()
	
	Return DriveClientServer.GetQueryDelimeter() +
	"SELECT ALLOWED
	|	ReservedProductsBalances.Products AS Products,
	|	ReservedProductsBalances.Characteristic AS Characteristic,
	|	ReservedProductsBalances.Batch AS Batch,
	|	ReservedProductsBalances.SalesOrder AS Order,
	|	SUM(ReservedProductsBalances.QuantityBalance) AS QuantityBalance
	|INTO TT_ReservedProductsBalances
	|FROM
	|	(SELECT
	|		ReservedProductsBalances.SalesOrder AS SalesOrder,
	|		ReservedProductsBalances.Products AS Products,
	|		ReservedProductsBalances.Characteristic AS Characteristic,
	|		ReservedProductsBalances.Batch AS Batch,
	|		ReservedProductsBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.ReservedProducts.Balance(
	|				,
	|				Company = &Company
	|					AND StructuralUnit = &StructuralUnit
	|					AND SalesOrder <> UNDEFINED
	|					AND (Products, Characteristic, Batch, SalesOrder) IN
	|						(SELECT
	|							TT_InventoryToFillReserve.Products,
	|							TT_InventoryToFillReserve.Characteristic,
	|							TT_InventoryToFillReserve.Batch,
	|							TT_InventoryToFillReserve.Order
	|						FROM
	|							TT_InventoryToFillReserve AS TT_InventoryToFillReserve)) AS ReservedProductsBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsReservedProducts.SalesOrder,
	|		DocumentRegisterRecordsReservedProducts.Products,
	|		DocumentRegisterRecordsReservedProducts.Characteristic,
	|		DocumentRegisterRecordsReservedProducts.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsReservedProducts.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRegisterRecordsReservedProducts.Quantity
	|			ELSE -DocumentRegisterRecordsReservedProducts.Quantity
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsReservedProducts
	|	WHERE
	|		DocumentRegisterRecordsReservedProducts.Recorder = &Ref
	|		AND DocumentRegisterRecordsReservedProducts.SalesOrder <> UNDEFINED) AS ReservedProductsBalances
	|
	|GROUP BY
	|	ReservedProductsBalances.SalesOrder,
	|	ReservedProductsBalances.Products,
	|	ReservedProductsBalances.Characteristic,
	|	ReservedProductsBalances.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryToFillReserve.LineNumber AS LineNumber,
	|	TT_InventoryToFillReserve.Products AS Products,
	|	TT_InventoryToFillReserve.Characteristic AS Characteristic,
	|	TT_InventoryToFillReserve.Batch AS Batch,
	|	TT_InventoryToFillReserve.Order AS Order,
	|	TT_InventoryToFillReserve.Factor AS Factor,
	|	TT_InventoryToFillReserve.Quantity * TT_InventoryToFillReserve.Factor AS BaseQuantity,
	|	SUM(TT_InventoryToFillReserveCumulative.Quantity * TT_InventoryToFillReserveCumulative.Factor) AS BaseQuantityCumulative
	|INTO TT_InventoryToFillReserveCumulative
	|FROM
	|	TT_InventoryToFillReserve AS TT_InventoryToFillReserve
	|		INNER JOIN TT_InventoryToFillReserve AS TT_InventoryToFillReserveCumulative
	|		ON TT_InventoryToFillReserve.Products = TT_InventoryToFillReserveCumulative.Products
	|			AND TT_InventoryToFillReserve.Characteristic = TT_InventoryToFillReserveCumulative.Characteristic
	|			AND TT_InventoryToFillReserve.Batch = TT_InventoryToFillReserveCumulative.Batch
	|			AND TT_InventoryToFillReserve.Order = TT_InventoryToFillReserveCumulative.Order
	|			AND TT_InventoryToFillReserve.LineNumber >= TT_InventoryToFillReserveCumulative.LineNumber
	|
	|GROUP BY
	|	TT_InventoryToFillReserve.LineNumber,
	|	TT_InventoryToFillReserve.Characteristic,
	|	TT_InventoryToFillReserve.Batch,
	|	TT_InventoryToFillReserve.Order,
	|	TT_InventoryToFillReserve.Products,
	|	TT_InventoryToFillReserve.Factor,
	|	TT_InventoryToFillReserve.Quantity * TT_InventoryToFillReserve.Factor
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryToFillReserveCumulative.LineNumber AS LineNumber,
	|	TT_InventoryToFillReserveCumulative.Order AS Order,
	|	TT_InventoryToFillReserveCumulative.Factor AS Factor,
	|	TT_InventoryToFillReserveCumulative.BaseQuantity AS BaseQuantity,
	|	CASE
	|		WHEN TT_ReservedProductsBalances.QuantityBalance > TT_InventoryToFillReserveCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryToFillReserveCumulative.BaseQuantity
	|		WHEN TT_ReservedProductsBalances.QuantityBalance > TT_InventoryToFillReserveCumulative.BaseQuantityCumulative - TT_InventoryToFillReserveCumulative.BaseQuantity
	|			THEN TT_ReservedProductsBalances.QuantityBalance - (TT_InventoryToFillReserveCumulative.BaseQuantityCumulative - TT_InventoryToFillReserveCumulative.BaseQuantity)
	|		ELSE 0
	|	END AS BaseReserve
	|INTO TT_InventoryReserve
	|FROM
	|	TT_InventoryToFillReserveCumulative AS TT_InventoryToFillReserveCumulative
	|		LEFT JOIN TT_ReservedProductsBalances AS TT_ReservedProductsBalances
	|		ON TT_InventoryToFillReserveCumulative.Products = TT_ReservedProductsBalances.Products
	|			AND TT_InventoryToFillReserveCumulative.Characteristic = TT_ReservedProductsBalances.Characteristic
	|			AND TT_InventoryToFillReserveCumulative.Batch = TT_ReservedProductsBalances.Batch
	|			AND TT_InventoryToFillReserveCumulative.Order = TT_ReservedProductsBalances.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.ProductsTypeInventory AS ProductsTypeInventory,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	TT_Inventory.Quantity AS Quantity,
	|	CASE
	|		WHEN TT_InventoryReserve.BaseReserve = TT_InventoryReserve.BaseQuantity
	|			THEN TT_Inventory.Quantity
	|		ELSE TT_InventoryReserve.BaseReserve / TT_InventoryReserve.Factor
	|	END AS Reserve,
	|	TT_Inventory.MeasurementUnit AS MeasurementUnit,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Price AS Price,
	|	TT_Inventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	TT_Inventory.Amount AS Amount,
	|	TT_Inventory.VATRate AS VATRate,
	|	TT_Inventory.VATAmount AS VATAmount,
	|	TT_Inventory.Total AS Total,
	|	TT_Inventory.Order AS Order,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssue,
	|	TT_Inventory.Content AS Content,
	|	TT_Inventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	TT_Inventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	TT_Inventory.SalesRep AS SalesRep,
	|	TT_Inventory.BundleProduct AS BundleProduct,
	|	TT_Inventory.BundleCharacteristic AS BundleCharacteristic,
	|	TT_Inventory.CostShare AS CostShare,
	|	TT_Inventory.Taxable AS Taxable,
	|	TT_Inventory.Project AS Project
	|FROM
	|	TT_InventoryToFillReserve AS TT_Inventory
	|		LEFT JOIN TT_InventoryReserve AS TT_InventoryReserve
	|		ON TT_Inventory.LineNumber = TT_InventoryReserve.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryReserve.Order
	|		INNER JOIN Document.WorkOrder AS WorkOrder
	|		ON TT_Inventory.Order = WorkOrder.Ref";

EndFunction

// Exists or not Early payment discount on specified date
// Parameters:
//  DocumentRefSalesInvoice - DocumentRef.SalesInvoice - the Sales invoice on which we check the EPD
//  CheckDate - date - the date of EPD check
// Returns:
//  Boolean - TRUE if EPD exists
//
Function CheckExistsEPD(DocumentRefSalesInvoice, CheckDate) Export
	
	Result = False;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	TRUE AS ExistsEPD
	|FROM
	|	Document.SalesInvoice.EarlyPaymentDiscounts AS SalesInvoiceEarlyPaymentDiscounts
	|WHERE
	|	SalesInvoiceEarlyPaymentDiscounts.Ref = &Ref
	|	AND ENDOFPERIOD(SalesInvoiceEarlyPaymentDiscounts.DueDate, DAY) >= &DueDate";
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	Query.SetParameter("DueDate", CheckDate);
	
	QuerySelection = Query.Execute().Select();
	If QuerySelection.Next() Then
		Result = QuerySelection.ExistsEPD;
	EndIf;
	
	Return Result;
	
EndFunction

// Gets an array of invoices that have an EPD on the specified date
// Parameters:
//  SalesInvoiceArray - Array - documents (DocumentRef.SalesInvoice)
//  CheckDate - date - the date of EPD check
// Returns:
//  Array - documents (DocumentRef.SalesIncoice) that have an EPD
//
Function GetSalesInvoiceArrayWithEPD(SalesInvoiceArray, Val CheckDate) Export
	
	Result = New Array;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED DISTINCT
	|	SalesInvoiceEarlyPaymentDiscounts.Ref AS SalesInvoce
	|FROM
	|	Document.SalesInvoice.EarlyPaymentDiscounts AS SalesInvoiceEarlyPaymentDiscounts
	|WHERE
	|	SalesInvoiceEarlyPaymentDiscounts.Ref IN(&SalesInvoices)
	|	AND ENDOFPERIOD(SalesInvoiceEarlyPaymentDiscounts.DueDate, DAY) >= &DueDate";
	
	Query.SetParameter("SalesInvoices", SalesInvoiceArray);
	Query.SetParameter("DueDate", CheckDate);
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		Result = QueryResult.Unload().UnloadColumn("SalesInvoce");
	EndIf;
	
	Return Result;
	
EndFunction

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	ObjectParameters = StructureData.ObjectParameters;
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Inventory" Then
		
		If StructureData.ProductsTypeInventory
			And Not ObjectParameters.OperationKind = Enums.OperationTypesSalesInvoice.AdvanceInvoice
			Or ValueIsFilled(StructureData.GoodsIssue) Then
			IncomeAndExpenseStructure.Insert("COGSItem", StructureData.COGSItem);
		EndIf;
		
		If Not ObjectParameters.OperationKind = Enums.OperationTypesSalesInvoice.AdvanceInvoice
			Or ValueIsFilled(StructureData.GoodsIssue) Or Not StructureData.ProductsTypeInventory Then
			IncomeAndExpenseStructure.Insert("RevenueItem", StructureData.RevenueItem);
		EndIf;
		
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "Inventory" Then
		Result.Insert("RevenueGLAccount", "RevenueItem");
		Result.Insert("COGSGLAccount", "COGSItem");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export
	
	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	If StructureData.Property("CounterpartyGLAccounts") Then
		
		If StructureData.TabName = "Header" Then
			
			GLAccountsForFilling.Insert("AccountsReceivableGLAccount", ObjectParameters.AccountsReceivableGLAccount);
			GLAccountsForFilling.Insert("AdvancesReceivedGLAccount", ObjectParameters.AdvancesReceivedGLAccount);
			
			If ObjectParameters.ThirdPartyPayment Then
				GLAccountsForFilling.Insert("ThirdPartyPayerGLAccount", ObjectParameters.ThirdPartyPayerGLAccount);
			EndIf;
			
		ElsIf StructureData.TabName = "AmountAllocation" Then
			
			GLAccountsForFilling.Insert("AccountsReceivableGLAccount", StructureData.AccountsReceivableGLAccount);
			GLAccountsForFilling.Insert("AdvancesReceivedGLAccount", StructureData.AdvancesReceivedGLAccount);
			
		EndIf;
		
	ElsIf StructureData.Property("ProductGLAccounts") Then
		
		If StructureData.ProductsTypeInventory
			And Not ObjectParameters.OperationKind = Enums.OperationTypesSalesInvoice.AdvanceInvoice
			And Not ValueIsFilled(StructureData.GoodsIssue) Then
			
			GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
			GLAccountsForFilling.Insert("InventoryReceivedGLAccount", StructureData.InventoryReceivedGLAccount);
			
		EndIf;
		
		If ValueIsFilled(StructureData.GoodsIssue) Then
			GLAccountsForFilling.Insert("GoodsShippedNotInvoicedGLAccount", StructureData.GoodsShippedNotInvoicedGLAccount);
		EndIf;
		
		If ObjectParameters.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
			GLAccountsForFilling.Insert("VATOutputGLAccount", StructureData.VATOutputGLAccount);
		EndIf;
		
		If StructureData.ProductsTypeInventory
			And ObjectParameters.OperationKind = Enums.OperationTypesSalesInvoice.AdvanceInvoice
			And Not ValueIsFilled(StructureData.GoodsIssue) Then
			GLAccountsForFilling.Insert("UnearnedRevenueGLAccount", StructureData.UnearnedRevenueGLAccount);
		EndIf;
		
		If Not ObjectParameters.OperationKind = Enums.OperationTypesSalesInvoice.AdvanceInvoice
			Or ValueIsFilled(StructureData.GoodsIssue) 
			Or Not StructureData.ProductsTypeInventory Then
			GLAccountsForFilling.Insert("RevenueGLAccount", StructureData.RevenueGLAccount);
		EndIf;
		
		If StructureData.ProductsTypeInventory
			And Not ObjectParameters.OperationKind = Enums.OperationTypesSalesInvoice.AdvanceInvoice
			Or ValueIsFilled(StructureData.GoodsIssue) Then
			GLAccountsForFilling.Insert("COGSGLAccount", StructureData.COGSGLAccount);
		EndIf;
		
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region InventoryOwnership

Function InventoryOwnershipParameters(DocObject) Export
	
	Parameters = New Structure;
	
	AmountFields = New Array;
	AmountFields.Add("Amount");
	AmountFields.Add("VATAmount");
	AmountFields.Add("Total");
	AmountFields.Add("SalesTaxAmount");
	AmountFields.Add("Reserve");
	Parameters.Insert("AmountFields", AmountFields);
	
	HeaderFields = New Structure;
	HeaderFields.Insert("Company", "Company");
	HeaderFields.Insert("StructuralUnit", "StructuralUnit");
	HeaderFields.Insert("Cell", "Cell");
	Parameters.Insert("HeaderFields", HeaderFields);
	
	Parameters.Insert("CheckGoodsIssue", True);
	
	// for consistency check between Inventory and Inventory ownership fields
	NotUsedFields = New Array;
	NotUsedFields.Add("ProductsTypeInventory");
	NotUsedFields.Add("DiscountMarkupPercent");
	NotUsedFields.Add("Content");
	NotUsedFields.Add("AutomaticDiscountsPercent");
	NotUsedFields.Add("AutomaticDiscountAmount");
	NotUsedFields.Add("ConnectionKey");
	NotUsedFields.Add("SerialNumbers");
	NotUsedFields.Add("ActualQuantity");
	NotUsedFields.Add("InvoicedQuantity");
	Parameters.Insert("NotUsedFields", NotUsedFields);
	
	Return Parameters;
	
EndFunction

#EndRegion

#Region Batches

Function BatchCheckFillingParameters(DocObject) Export
	
	Parameters = New Structure;
	
	Warehouses = New Array;
	
	WarehouseData = New Structure;
	WarehouseData.Insert("Warehouse", DocObject.StructuralUnit);
	WarehouseData.Insert("TrackingArea", "Outbound_SalesToCustomer");
	
	Warehouses.Add(WarehouseData);
	
	Parameters.Insert("Warehouses", Warehouses);
	
	Return Parameters;
	
EndFunction

#EndRegion

Function DocumentVATRate(DocumentRef) Export
	
	Return DriveServer.DocumentVATRate(DocumentRef);
	
EndFunction

#Region PrintInterface

Procedure AddPrintCommands(PrintCommands) Export
	
	ClosingInvoiceVisibilityCondition = New Structure;
	ClosingInvoiceVisibilityCondition.Insert("Attribute", "OperationKind");
	ClosingInvoiceVisibilityCondition.Insert("Value", Enums.OperationTypesSalesInvoice.ClosingInvoice);
	ClosingInvoiceVisibilityCondition.Insert("ComparisonType", ComparisonType.Equal);
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "ClosingInvoiceNoAnnex";
	PrintCommand.Presentation				= NStr("en = 'Closing invoice'; ru = 'Заключительный инвойс';pl = 'Faktura końcowa';es_ES = 'Factura de cierre';es_CO = 'Factura de cierre';tr = 'Kapanış faturası';it = 'Fattura di saldo';de = 'Abschlussrechnung'");
	PrintCommand.CheckPostingBeforePrint	= True;
	PrintCommand.Order						= 1;
	PrintCommand.FunctionalOptions			= "IssueClosingInvoices";
	PrintCommand.VisibilityConditions.Add(ClosingInvoiceVisibilityCondition);
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "ClosingInvoice";
	PrintCommand.Presentation				= NStr("en = 'Closing invoice (detailed)'; ru = 'Заключительный инвойс (описание)';pl = 'Faktura końcowa (szczegółowa)';es_ES = 'Factura de cierre (detallado)';es_CO = 'Factura de cierre (detallado)';tr = 'Kapanış faturası (ayrıntılı)';it = 'Fattura di chiusura (dettagliata)';de = 'Abschlussrechnung (detailliert)'");
	PrintCommand.CheckPostingBeforePrint	= True;
	PrintCommand.Order						= 2;
	PrintCommand.FunctionalOptions			= "IssueClosingInvoices";
	PrintCommand.VisibilityConditions.Add(ClosingInvoiceVisibilityCondition);
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "SalesInvoice";
	PrintCommand.Presentation				= NStr("en = 'Invoice'; ru = 'Инвойс';pl = 'Faktura';es_ES = 'Factura';es_CO = 'Factura';tr = 'Fatura';it = 'Fattura';de = 'Rechnung'");
	PrintCommand.CheckPostingBeforePrint	= True;
	PrintCommand.Order						= 3;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "DeliveryNote";
	PrintCommand.Presentation				= NStr("en = 'Delivery note'; ru = 'Уведомление о доставке';pl = 'Dowód dostawy';es_ES = 'Nota de entrega';es_CO = 'Nota de entrega';tr = 'Sevk irsaliyesi';it = 'Documento di Trasporto';de = 'Lieferschein'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 4;
	
	If GetFunctionalOption("UseVAT") Then
		PrintCommand = PrintCommands.Add();
		PrintCommand.ID							= "TaxInvoice";
		PrintCommand.Presentation				= NStr("en = 'Tax invoice'; ru = 'Налоговый инвойс';pl = 'Faktura VAT';es_ES = 'Factura de impuestos';es_CO = 'Factura fiscal';tr = 'Vergi faturası';it = 'Fattura fiscale';de = 'Steuerrechnung'");
		PrintCommand.CheckPostingBeforePrint	= True;
		PrintCommand.Order						= 5;
	EndIf;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "Requisition";
	PrintCommand.Presentation				= NStr("en = 'Requisition'; ru = 'Требование';pl = 'Zapotrzebowanie';es_ES = 'Solicitud';es_CO = 'Solicitud';tr = 'Talep formu';it = 'Requisizione';de = 'Anforderung'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 6;
	
	If AccessRight("View", Metadata.DataProcessors.PrintLabelsAndTags) Then
		
		PrintCommand = PrintCommands.Add();
		PrintCommand.Handler 				 = "DriveClient.PrintLabelsAndPriceTagsFromDocuments";
		PrintCommand.ID 					 = "LabelsPrintingFromSalesInvoice";
		PrintCommand.Presentation			 = NStr("en = 'Labels'; ru = 'Этикетки';pl = 'Etykiety';es_ES = 'Etiquetas';es_CO = 'Etiquetas';tr = 'Marka etiketleri';it = 'Etichette';de = 'Etiketten'");
		PrintCommand.FormsList				 = "DocumentForm,ListForm,DocumentsListForm";
		PrintCommand.CheckPostingBeforePrint = False;
		PrintCommand.Order = 7;
		
		PrintCommand = PrintCommands.Add();
		PrintCommand.Handler				 = "DriveClient.PrintLabelsAndPriceTagsFromDocuments";
		PrintCommand.ID						 = "PriceTagsPrintingFromSalesInvoice";
		PrintCommand.Presentation			 = NStr("en = 'Price tags'; ru = 'Ценники';pl = 'Cenniki';es_ES = 'Etiquetas de precio';es_CO = 'Etiquetas de precio';tr = 'Fiyat etiketleri';it = 'Cartellini di prezzo';de = 'Preisschilder'");
		PrintCommand.FormsList				 = "DocumentForm,ListForm,DocumentsListForm";
		PrintCommand.CheckPostingBeforePrint = False;
		PrintCommand.Order = 8;
		
	EndIf;
	
	If GetFunctionalOption("UseSubcontractingManufacturing") Then
		PrintCommand = PrintCommands.Add();
		PrintCommand.ID							= "SubcontractorReport";
		PrintCommand.Presentation				= NStr("en = 'Subcontractor report'; ru = 'Отчет переработчика';pl = 'Raport podwykonawcy';es_ES = 'Informe del subcontratista';es_CO = 'Informe del subcontratista';tr = 'Alt yüklenici raporu';it = 'Report subfornitore';de = 'Subunternehmerbericht'");
		PrintCommand.CheckPostingBeforePrint	= False;
		PrintCommand.Order						= 9;
	EndIf;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "WarrantyCardPerSerialNumber";
	PrintCommand.Presentation				= NStr("en = 'Warranty card (per serial number)'; ru = 'Гарантийный талон (по серийным номерам)';pl = 'Karta gwarancyjna (dla numeru seryjnego)';es_ES = 'Tarjeta de garantía (por número de serie)';es_CO = 'Tarjeta de garantía (por número de serie)';tr = 'Garanti belgesi (seri numarasına göre)';it = 'Certificato di garanzia (per numero di serie)';de = 'Garantiekarte (nach Seriennummer)'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 10;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "WarrantyCardConsolidated";
	PrintCommand.Presentation				= NStr("en = 'Warranty card (consolidated)'; ru = 'Гарантийный талон (общий)';pl = 'Karta gwarancyjna (skonsolidowana)';es_ES = 'Tarjeta de garantía (consolidada)';es_CO = 'Tarjeta de garantía (consolidada)';tr = 'Garanti kartı (konsolide)';it = 'Certificato di garanzia (consolidato)';de = 'Garantiekarte (konsolidiert)'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 11;
	
EndProcedure

Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "SalesInvoice") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"SalesInvoice",
			Nstr("en = 'Sales invoice'; ru = 'Инвойс покупателю';pl = 'Faktura sprzedaży';es_ES = 'Factura de ventas';es_CO = 'Factura de ventas';tr = 'Satış faturası';it = 'Fattura di vendita';de = 'Verkaufsrechnung'"),
			PrintForm(ObjectsArray,
			PrintObjects, "SalesInvoice", PrintParameters.Result));
			
	EndIf;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "ClosingInvoice") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
			"ClosingInvoice",
			Nstr("en = 'Closing invoice'; ru = 'Заключительный инвойс';pl = 'Faktura końcowa';es_ES = 'Factura de cierre';es_CO = 'Factura de cierre';tr = 'Kapanış faturası';it = 'Fattura di saldo';de = 'Abschlussrechnung'"),
			PrintForm(ObjectsArray,
				PrintObjects, "ClosingInvoice", PrintParameters.Result));
			
	EndIf;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "ClosingInvoiceNoAnnex") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
			"ClosingInvoiceNoAnnex",
			Nstr("en = 'Closing invoice (no annex)'; ru = 'Заключительный инвойс (без приложения)';pl = 'Faktura końcowa (bez aneksu)';es_ES = 'Factura de cierre (no adjunta)';es_CO = 'Factura de cierre (no adjunta)';tr = 'Kapanış faturası (eksiz)';it = 'Fattura di chiusura (nessun allegato)';de = 'Abschlussrechnung (keine Anlage)'"),
			PrintForm(ObjectsArray,
				PrintObjects, "ClosingInvoiceNoAnnex", PrintParameters.Result));
			
	EndIf;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "DeliveryNote") Then
		
		SpreadsheetDocument = DataProcessors.PrintDeliveryNote.PrintForm(ObjectsArray, PrintObjects, "DeliveryNote", PrintParameters.Result);
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"DeliveryNote",
			Nstr("en = 'Delivery note'; ru = 'Уведомление о доставке';pl = 'Dowód dostawy';es_ES = 'Nota de entrega';es_CO = 'Nota de entrega';tr = 'Sevk irsaliyesi';it = 'Documento di Trasporto';de = 'Lieferschein'"),
			SpreadsheetDocument);
	EndIf;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "TaxInvoice") Then
		If ObjectsArray.Count() > 0 Then
			
			SpreadsheetDocument = DataProcessors.PrintTaxInvoice.PrintForm(ObjectsArray, PrintObjects, "TaxInvoice", PrintParameters.Result);
			
			PrintManagement.OutputSpreadsheetDocumentToCollection(
				PrintFormsCollection,
				"TaxInvoice",
				NStr("en = 'Tax invoice'; ru = 'Налоговый инвойс';pl = 'Faktura VAT';es_ES = 'Factura de impuestos';es_CO = 'Factura fiscal';tr = 'Vergi faturası';it = 'Fattura fiscale';de = 'Steuerrechnung'"), 
				SpreadsheetDocument);
				
		EndIf;
	EndIf;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "Requisition") Then
		
		SpreadsheetDocument = DataProcessors.PrintRequisition.PrintForm(ObjectsArray, PrintObjects, "Requisition", PrintParameters.Result);
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"Requisition",
			NStr("en = 'Requisition'; ru = 'Требование';pl = 'Zapotrzebowanie';es_ES = 'Solicitud';es_CO = 'Solicitud';tr = 'Talep formu';it = 'Requisizione';de = 'Anforderung'"),
			SpreadsheetDocument);
			
	EndIf;
		
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "WarrantyCardPerSerialNumber") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"WarrantyCardPerSerialNumber",
			NStr("en = 'Warranty card (per serial number)'; ru = 'Гарантийный талон (по серийным номерам)';pl = 'Karta gwarancyjna (dla numeru seryjnego)';es_ES = 'Tarjeta de garantía (por número de serie)';es_CO = 'Tarjeta de garantía (por número de serie)';tr = 'Garanti belgesi (seri numarasına göre)';it = 'Certificato di garanzia (per numero di serie)';de = 'Garantiekarte (nach Seriennummer)'"),
			WorkWithProductsServer.PrintWarrantyCard(ObjectsArray, PrintObjects, "PerSerialNumber", PrintParameters.Result));
		
	EndIf;	
															
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "WarrantyCardConsolidated") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"WarrantyCardConsolidated",
			NStr("en = 'Warranty card (consolidated)'; ru = 'Гарантийный талон (общий)';pl = 'Karta gwarancyjna (skonsolidowana)';es_ES = 'Tarjeta de garantía (consolidada)';es_CO = 'Tarjeta de garantía (consolidada)';tr = 'Garanti kartı (konsolide)';it = 'Certificato di garanzia (consolidato)';de = 'Garantiekarte (konsolidiert)'"),
			WorkWithProductsServer.PrintWarrantyCard(ObjectsArray, PrintObjects, "Consolidated", PrintParameters.Result));
		
	EndIf;															
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "SubcontractorReport") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"SubcontractorReport",
			Nstr("en = 'Subcontractor report'; ru = 'Отчет переработчика';pl = 'Raport podwykonawcy';es_ES = 'Informe del subcontratista';es_CO = 'Informe del subcontratista';tr = 'Alt yüklenici raporu';it = 'Report subfornitore';de = 'Subunternehmer bericht'"),
			PrintForm(ObjectsArray,
			PrintObjects, "SubcontractorReport", PrintParameters.Result));
			
	EndIf;

	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

#EndRegion

Procedure ListOnGetDataAtServer(ItemName, Settings, Rows) Export
	
	RowsKeys = Rows.GetKeys();
	
	If Not Rows[RowsKeys[0]].Data.Property("SalesRep") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	SalesInvoiceInventory.Ref AS Ref,
	|	SalesInvoiceInventory.SalesRep.Presentation AS SalesRep
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|WHERE
	|	SalesInvoiceInventory.Ref IN(&Refs)
	|TOTALS BY
	|	Ref";
	
	Query.SetParameter("Refs", RowsKeys);
	
	QueryResult = Query.Execute();
	
	SelectionRef = QueryResult.Select(QueryResultIteration.ByGroups);
	
	While SelectionRef.Next() Do
		
		LineOfList = Rows[SelectionRef.Ref];
	
		SelectionDetailRecords = SelectionRef.Select();
		
		IsFirstRecord = True;
		
		While SelectionDetailRecords.Next() Do
			LineOfList.Data["SalesRep"] = LineOfList.Data["SalesRep"] + ?(IsFirstRecord, "", ", ") 
				+ TrimAll(SelectionDetailRecords.SalesRep);
			IsFirstRecord = False;
		EndDo;
		
	EndDo;
	
EndProcedure

Function EntryTypes() Export 
	
	EntryTypes = New Array;
	
	EntryTypes.Add(Enums.EntryTypes.AccountsReceivableRevenue);
	EntryTypes.Add(Enums.EntryTypes.AccountsReceivableUnearnedRevenue);
	EntryTypes.Add(Enums.EntryTypes.AdvancesFromCustomerAccountsReceivable);
	EntryTypes.Add(Enums.EntryTypes.SettlementsWithCustomerForeignExchangeGain);
	EntryTypes.Add(Enums.EntryTypes.ForeignExchangeLossSettlementsWithCustomer);
	EntryTypes.Add(Enums.EntryTypes.VATOutputVATFromAdvancesReceived);
	EntryTypes.Add(Enums.EntryTypes.ThirdPartyPayerAccountsReceivable);
	EntryTypes.Add(Enums.EntryTypes.AccountsReceivableAccountsReceivableOffset);
	EntryTypes.Add(Enums.EntryTypes.AccountsReceivableAdvancesFromCustomer);
	EntryTypes.Add(Enums.EntryTypes.COGSInventory);
	EntryTypes.Add(Enums.EntryTypes.COGSGoodsShippedNotInvoiced);
	EntryTypes.Add(Enums.EntryTypes.AccountsReceivableSalesTax);
	
	Return EntryTypes;
	
EndFunction

Function AccountingFields() Export 
	
	AccountingFields = New Map;
	
	AccountingFields.Insert("AccountsReceivableRevenue"					, GetEntriesStructureAccountsReceivableRevenue());
	AccountingFields.Insert("AccountsReceivableUnearnedRevenue"			, GetEntriesStructureAccountsReceivableUnearnedRevenue());
	AccountingFields.Insert("AdvancesFromCustomerAccountsReceivable"	, GetEntriesStructureAdvancesFromCustomerAccountsReceivable());
	AccountingFields.Insert("SettlementsWithCustomerForeignExchangeGain", GetEntriesStructureSettlementsWithCustomerForeignExchangeGain());
	AccountingFields.Insert("ForeignExchangeLossSettlementsWithCustomer", GetEntriesStructureForeignExchangeLossSettlementsWithCustomer());
	AccountingFields.Insert("VATOutputVATFromAdvancesReceived"			, GetEntriesStructureVATOutputVATFromAdvancesReceived());
	AccountingFields.Insert("ThirdPartyPayerAccountsReceivable"			, GetEntriesStructureThirdPartyPayerAccountsReceivable());
	AccountingFields.Insert("AccountsReceivableAccountsReceivableOffset", GetEntriesStructureAccountsReceivableAccountsReceivableOffset());
	AccountingFields.Insert("AccountsReceivableAdvancesFromCustomer"	, GetEntriesStructureAccountsReceivableAdvancesFromCustomer());
	AccountingFields.Insert("COGSInventory"								, GetEntriesStructureCOGSInventory());
	AccountingFields.Insert("COGSGoodsShippedNotInvoiced"				, GetEntriesStructureCOGSGoodsShippedNotInvoiced());
	AccountingFields.Insert("AccountsReceivableSalesTax"				, GetEntriesStructureAccountsReceivableSalesTax());
	
	Return AccountingFields;
	
EndFunction

#EndRegion

#Region EventHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	User = Users.CurrentUser();
	
	If TypeOf(User) = Type("CatalogRef.ExternalUsers") Then
		If FormType = "ListForm" Then
			StandardProcessing = False;
			SelectedForm = "ListFormForExternalUsers";
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Internal

#Region AutomaticDiscounts

// Generates a table of values that contains the data for posting by the register AutomaticDiscountsApplied.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	If DocumentRefSalesInvoice.DiscountsMarkups.Count() = 0 Or Not GetFunctionalOption("UseAutomaticDiscounts") Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAutomaticDiscountsApplied", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableAutoDiscountsMarkups.Period AS Period,
	|	TemporaryTableAutoDiscountsMarkups.DiscountMarkup AS AutomaticDiscount,
	|	TemporaryTableAutoDiscountsMarkups.Amount AS DiscountAmount,
	|	TableAutomaticDiscountsApplied.Products AS Products,
	|	TableAutomaticDiscountsApplied.Characteristic AS Characteristic,
	|	TableAutomaticDiscountsApplied.Document AS DocumentDiscounts,
	|	TableAutomaticDiscountsApplied.Counterparty AS RecipientDiscounts,
	|	TableAutomaticDiscountsApplied.PresentationCurrency AS PresentationCurrency
	|FROM
	|	TemporaryTableInventory AS TableAutomaticDiscountsApplied
	|		INNER JOIN TemporaryTableAutoDiscountsMarkups AS TemporaryTableAutoDiscountsMarkups
	|		ON TableAutomaticDiscountsApplied.ConnectionKey = TemporaryTableAutoDiscountsMarkups.ConnectionKey
	|WHERE
	|	NOT TableAutomaticDiscountsApplied.ZeroInvoice";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAutomaticDiscountsApplied", QueryResult.Unload());
	
EndProcedure

#EndRegion

#EndRegion

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.Counterparty AS Counterparty,
	|	TableInventory.DocumentCurrency AS Currency,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	FALSE AS Return,
	|	TableInventory.Document AS Document,
	|	TableInventory.Document AS SourceDocument,
	|	CASE
	|		WHEN TableInventory.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.Order
	|	END AS CorrSalesOrder,
	|	TableInventory.DepartmentSales AS Department,
	|	TableInventory.Responsible AS Responsible,
	|	TableInventory.DepartmentSales AS DepartmentSales,
	|	TableInventory.BusinessLineSales AS BusinessLine,
	|	TableInventory.GLAccountCost AS GLAccountCost,
	|	TableInventory.CorrOrganization AS CorrOrganization,
	|	ISNULL(TableInventory.StructuralUnit, VALUE(Catalog.Counterparties.EmptyRef)) AS StructuralUnit,
	|	ISNULL(TableInventory.StructuralUnitCorr, VALUE(Catalog.BusinessUnits.EmptyRef)) AS StructuralUnitCorr,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) AS IncomeAndExpenseItem,
	|	TableInventory.COGSItem AS CorrIncomeAndExpenseItem,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.ProductsCorr AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.Ownership AS OwnershipCorr,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.CostObject AS CostObject,
	|	TableInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	CASE
	|		WHEN TableInventory.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.Order
	|	END AS SalesOrder,
	|	TableInventory.SalesRep AS SalesRep,
	|	UNDEFINED AS CustomerCorrOrder,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	TableInventory.VATRate AS VATRate,
	|	SUM(TableInventory.VATAmount) AS VATAmount,
	|	SUM(TableInventory.Amount) AS Amount,
	|	0 AS Cost,
	|	FALSE AS FixedCost,
	|	TableInventory.GLAccountCost AS AccountDr,
	|	TableInventory.GLAccount AS AccountCr,
	|	CAST(&InventoryWriteOff AS STRING(100)) AS Content,
	|	CAST(&InventoryWriteOff AS STRING(100)) AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord,
	|	TableInventory.ContinentalMethod AS ContinentalMethod,
	|	TableInventory.GoodsIssue AS GoodsIssue
	|INTO SourceInventory
	|FROM
	|	TemporaryTableInventoryOwnership AS TableInventory
	|		LEFT JOIN Document.SalesOrder AS SalesOrderRef
	|		ON TableInventory.Order = SalesOrderRef.Ref,
	|	Constant.UseInventoryReservation AS UseInventoryReservation
	|WHERE
	|	TableInventory.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND (NOT TableInventory.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|			OR NOT TableInventory.AdvanceInvoicing)
	|	AND NOT TableInventory.ZeroInvoice
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.Counterparty,
	|	TableInventory.DocumentCurrency,
	|	TableInventory.Document,
	|	TableInventory.Order,
	|	TableInventory.SalesRep,
	|	TableInventory.DepartmentSales,
	|	TableInventory.Responsible,
	|	TableInventory.BusinessLineSales,
	|	TableInventory.GLAccountCost,
	|	TableInventory.CorrOrganization,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.RevenueItem,
	|	TableInventory.COGSItem,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.CostObject,
	|	TableInventory.CorrInventoryAccountType,
	|	TableInventory.ProductsCorr,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.BatchCorr,
	|	TableInventory.VATRate,
	|	TableInventory.ContinentalMethod,
	|	TableInventory.GoodsIssue,
	|	CASE
	|		WHEN TableInventory.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.Order
	|	END,
	|	ISNULL(TableInventory.StructuralUnit, VALUE(Catalog.Counterparties.EmptyRef)),
	|	TableInventory.Document,
	|	TableInventory.DepartmentSales,
	|	TableInventory.Ownership,
	|	TableInventory.GLAccountCost,
	|	TableInventory.GLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	TableInventory.Period AS Period,
	|	TableInventory.RecordType AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.Counterparty AS Counterparty,
	|	TableInventory.Currency AS Currency,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.Return AS Return,
	|	TableInventory.Document AS Document,
	|	TableInventory.SourceDocument AS SourceDocument,
	|	TableInventory.CorrSalesOrder AS CorrSalesOrder,
	|	TableInventory.Department AS Department,
	|	TableInventory.Responsible AS Responsible,
	|	TableInventory.DepartmentSales AS DepartmentSales,
	|	TableInventory.BusinessLine AS BusinessLine,
	|	TableInventory.GLAccountCost AS GLAccountCost,
	|	TableInventory.CorrOrganization AS CorrOrganization,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	TableInventory.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	TableInventory.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.ProductsCorr AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.Ownership AS OwnershipCorr,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.CostObject AS CostObject,
	|	TableInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.CustomerCorrOrder AS CustomerCorrOrder,
	|	TableInventory.Quantity AS Quantity,
	|	TableInventory.VATRate AS VATRate,
	|	0 AS VATAmount,
	|	0 AS Amount,
	|	0 AS Cost,
	|	TableInventory.FixedCost AS FixedCost,
	|	TableInventory.AccountDr AS AccountDr,
	|	TableInventory.AccountCr AS AccountCr,
	|	TableInventory.Content AS Content,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	TableInventory.OfflineRecord AS OfflineRecord,
	|	TableInventory.SalesRep AS SalesRep
	|FROM
	|	SourceInventory AS TableInventory
	|WHERE
	|	NOT &FillAmount
	|	AND (NOT TableInventory.ContinentalMethod
	|			OR TableInventory.ContinentalMethod
	|				AND TableInventory.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef))
	|	AND (NOT TableInventory.ContinentalMethod
	|			OR TableInventory.ContinentalMethod
	|				AND TableInventory.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT
	|	TableInventory.LineNumber,
	|	TableInventory.Period,
	|	TableInventory.RecordType,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.Counterparty,
	|	TableInventory.Currency,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.Return,
	|	TableInventory.Document,
	|	TableInventory.SourceDocument,
	|	TableInventory.CorrSalesOrder,
	|	TableInventory.Department,
	|	TableInventory.Responsible,
	|	TableInventory.DepartmentSales,
	|	TableInventory.BusinessLine,
	|	TableInventory.GLAccountCost,
	|	TableInventory.CorrOrganization,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.IncomeAndExpenseItem,
	|	TableInventory.CorrIncomeAndExpenseItem,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.Products,
	|	TableInventory.ProductsCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.BatchCorr,
	|	TableInventory.Ownership,
	|	TableInventory.OwnershipCorr,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.CostObject,
	|	TableInventory.CorrInventoryAccountType,
	|	TableInventory.SalesOrder,
	|	TableInventory.CustomerCorrOrder,
	|	TableInventory.Quantity,
	|	TableInventory.VATRate,
	|	TableInventory.VATAmount,
	|	TableInventory.Amount,
	|	TableInventory.Cost,
	|	TableInventory.FixedCost,
	|	TableInventory.AccountDr,
	|	TableInventory.AccountCr,
	|	TableInventory.Content,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.OfflineRecord,
	|	TableInventory.SalesRep
	|FROM
	|	SourceInventory AS TableInventory
	|WHERE
	|	&FillAmount
	|	AND (NOT TableInventory.ContinentalMethod
	|			OR TableInventory.ContinentalMethod
	|				AND TableInventory.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.Counterparty,
	|	OfflineRecords.Currency,
	|	UNDEFINED,
	|	OfflineRecords.Return,
	|	UNDEFINED,
	|	OfflineRecords.SourceDocument,
	|	OfflineRecords.CorrSalesOrder,
	|	OfflineRecords.Department,
	|	OfflineRecords.Responsible,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.StructuralUnitCorr,
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.CorrIncomeAndExpenseItem,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.CorrGLAccount,
	|	OfflineRecords.Products,
	|	OfflineRecords.ProductsCorr,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.CharacteristicCorr,
	|	OfflineRecords.Batch,
	|	OfflineRecords.BatchCorr,
	|	OfflineRecords.Ownership,
	|	OfflineRecords.OwnershipCorr,
	|	OfflineRecords.InventoryAccountType,
	|	OfflineRecords.CostObject,
	|	OfflineRecords.CorrInventoryAccountType,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.CustomerCorrOrder,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.VATRate,
	|	UNDEFINED,
	|	OfflineRecords.Amount,
	|	UNDEFINED,
	|	OfflineRecords.FixedCost,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord,
	|	OfflineRecords.SalesRep
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	FillAmount = StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
	
	Query.SetParameter("InventoryIncrease", NStr("en = 'Inventory increase'; ru = 'Оприходование запасов';pl = 'Zwiększenie zapasów';es_ES = 'Aumento de inventario';es_CO = 'Aumento de inventario';tr = 'Stok artırma';it = 'Aumento scorte';de = 'Bestandserhöhung'", MainLanguageCode));
	Query.SetParameter("InventoryWriteOff", NStr("en = 'Inventory write-off'; ru = 'Списание запасов';pl = 'Rozchód zapasów';es_ES = 'Amortización del inventario';es_CO = 'Amortización del inventario';tr = 'Stok azaltma';it = 'Cancellazione di scorte';de = 'Bestandsabschreibung'", MainLanguageCode));
	Query.SetParameter("FillAmount", FillAmount);
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
	If FillAmount Then
		GenerateTableInventorySale(DocumentRefSalesInvoice, StructureAdditionalProperties);
	EndIf;
	
EndProcedure

Procedure GenerateTableReservedProducts(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT DISTINCT
	|	ReservedProducts.Company AS Company,
	|	ReservedProducts.StructuralUnit AS StructuralUnit,
	|	ReservedProducts.Products AS Products,
	|	ReservedProducts.Characteristic AS Characteristic,
	|	ReservedProducts.Batch AS Batch,
	|	ReservedProducts.Order AS SalesOrder
	|INTO ReservedProducts
	|FROM
	|	TemporaryTableInventoryOwnership AS ReservedProducts
	|WHERE
	|	ReservedProducts.Order <> UNDEFINED
	|	AND ReservedProducts.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND ReservedProducts.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|	AND ReservedProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND (NOT ReservedProducts.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|			OR NOT ReservedProducts.AdvanceInvoicing)
	|	AND NOT ReservedProducts.ZeroInvoice AND NOT ReservedProducts.DropShipping
	
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReservedProducts.Company AS Company,
	|	ReservedProducts.StructuralUnit AS StructuralUnit,
	|	ReservedProducts.Products AS Products,
	|	ReservedProducts.Characteristic AS Characteristic,
	|	ReservedProducts.Batch AS Batch,
	|	ReservedProducts.SalesOrder AS SalesOrder
	|FROM
	|	ReservedProducts AS ReservedProducts";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.ReservedProducts");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	Query.Text =
	"SELECT
	|	Balance.Company AS Company,
	|	Balance.StructuralUnit AS StructuralUnit,
	|	Balance.Products AS Products,
	|	Balance.Characteristic AS Characteristic,
	|	Balance.Batch AS Batch,
	|	Balance.SalesOrder AS SalesOrder,
	|	SUM(Balance.Quantity) AS Quantity
	|INTO ReservedProductsBalance
	|FROM
	|	(SELECT
	|		Balance.Company AS Company,
	|		Balance.StructuralUnit AS StructuralUnit,
	|		Balance.Products AS Products,
	|		Balance.Characteristic AS Characteristic,
	|		Balance.Batch AS Batch,
	|		Balance.SalesOrder AS SalesOrder,
	|		Balance.QuantityBalance AS Quantity
	|	FROM
	|		AccumulationRegister.ReservedProducts.Balance(
	|				&AtData,
	|				(Company, StructuralUnit, Products, Characteristic, Batch, SalesOrder) IN
	|					(SELECT
	|						ReservedProducts.Company AS Company,
	|						ReservedProducts.StructuralUnit AS StructuralUnit,
	|						ReservedProducts.Products AS Products,
	|						ReservedProducts.Characteristic AS Characteristic,
	|						ReservedProducts.Batch AS Batch,
	|						ReservedProducts.SalesOrder AS SalesOrder
	|					FROM
	|						ReservedProducts AS ReservedProducts)) AS Balance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsReservedProducts.Company,
	|		DocumentRegisterRecordsReservedProducts.StructuralUnit,
	|		DocumentRegisterRecordsReservedProducts.Products,
	|		DocumentRegisterRecordsReservedProducts.Characteristic,
	|		DocumentRegisterRecordsReservedProducts.Batch,
	|		DocumentRegisterRecordsReservedProducts.SalesOrder,
	|		CASE
	|			WHEN DocumentRegisterRecordsReservedProducts.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRegisterRecordsReservedProducts.Quantity
	|			ELSE -DocumentRegisterRecordsReservedProducts.Quantity
	|		END
	|	FROM
	|		AccumulationRegister.ReservedProducts AS DocumentRegisterRecordsReservedProducts
	|	WHERE
	|		DocumentRegisterRecordsReservedProducts.Recorder = &Ref
	|		AND DocumentRegisterRecordsReservedProducts.Period <= &ControlPeriod) AS Balance
	|
	|GROUP BY
	|	Balance.StructuralUnit,
	|	Balance.Company,
	|	Balance.Batch,
	|	Balance.Characteristic,
	|	Balance.Products,
	|	Balance.SalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Order AS Order,
	|	SUM(TableInventory.Reserve) AS Reserve
	|INTO TemporaryTableInventoryGrouped
	|FROM
	|	TemporaryTableInventoryOwnership AS TableInventory
	|WHERE
	|	TableInventory.Reserve > 0
	|	AND (NOT TableInventory.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|			OR NOT TableInventory.AdvanceInvoicing)
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Order AS SalesOrder,
	|	CASE
	|		WHEN Balance.Quantity > TableInventory.Reserve
	|			THEN TableInventory.Reserve
	|		ELSE Balance.Quantity
	|	END AS Quantity
	|INTO AvailableReserve
	|FROM
	|	TemporaryTableInventoryGrouped AS TableInventory
	|		INNER JOIN ReservedProductsBalance AS Balance
	|		ON TableInventory.Company = Balance.Company
	|			AND TableInventory.StructuralUnit = Balance.StructuralUnit
	|			AND TableInventory.Products = Balance.Products
	|			AND TableInventory.Characteristic = Balance.Characteristic
	|			AND TableInventory.Batch = Balance.Batch
	|			AND TableInventory.Order = Balance.SalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	Reserve.Period AS Period,
	|	Reserve.Company AS Company,
	|	Reserve.StructuralUnit AS StructuralUnit,
	|	Reserve.GLAccount AS GLAccount,
	|	Reserve.Products AS Products,
	|	Reserve.Characteristic AS Characteristic,
	|	Reserve.Batch AS Batch,
	|	Reserve.SalesOrder AS SalesOrder,
	|	Reserve.Quantity AS Quantity
	|FROM
	|	AvailableReserve AS Reserve
	|WHERE
	|	Reserve.Quantity > 0";
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	Query.SetParameter("AtData", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventorySale(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text =
	"SELECT DISTINCT
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.CostObject AS CostObject
	|FROM
	|	TemporaryTableInventoryOwnership AS TableInventory";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Inventory");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving inventory balances by cost.
	Query.Text =
	"SELECT
	|	GoodsIssueProducts.Products AS Products,
	|	GoodsIssueProducts.Characteristic AS Characteristic,
	|	GoodsIssueProducts.Batch AS Batch,
	|	SourceInventory.Ownership AS Ownership,
	|	SUM(GoodsIssueProducts.Quantity) AS Quantity,
	|	SUM(GoodsIssueProducts.Amount) AS Amount,
	|	GoodsIssueProducts.VATRate AS VATRate,
	|	GoodsIssueProducts.SalesRep AS SalesRep,
	|	SourceInventory.Document AS Document,
	|	SourceInventory.GoodsIssue AS GoodsIssue,
	|	SourceInventory.SalesOrder AS SalesOrder,
	|	GoodsIssueDoc.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsIssueProducts.InventoryGLAccount 
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	SourceInventory.Period AS Period
	|INTO GoodsIssueTable
	|FROM
	|	SourceInventory AS SourceInventory
	|		LEFT JOIN Document.GoodsIssue.Products AS GoodsIssueProducts
	|		ON SourceInventory.Products = GoodsIssueProducts.Products
	|			AND SourceInventory.Characteristic = GoodsIssueProducts.Characteristic
	|			AND SourceInventory.Batch = GoodsIssueProducts.Batch
	|			AND SourceInventory.GoodsIssue = GoodsIssueProducts.Ref
	|		LEFT JOIN Document.GoodsIssue AS GoodsIssueDoc
	|		ON SourceInventory.GoodsIssue = GoodsIssueDoc.Ref
	|
	|GROUP BY
	|	SourceInventory.Ownership,
	|	GoodsIssueProducts.SalesRep,
	|	SourceInventory.GoodsIssue,
	|	SourceInventory.Document,
	|	SourceInventory.SalesOrder,
	|	GoodsIssueDoc.StructuralUnit,
	|	GoodsIssueProducts.Products,
	|	GoodsIssueProducts.Batch,
	|	GoodsIssueProducts.Characteristic,
	|	GoodsIssueProducts.VATRate,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsIssueProducts.InventoryGLAccount 
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	SourceInventory.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Inventory.Recorder AS Recorder,
	|	Inventory.Active AS Active,
	|	Inventory.RecordType AS RecordType,
	|	Inventory.Company AS Company,
	|	Inventory.PresentationCurrency AS PresentationCurrency,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.Ownership AS Ownership,
	|	Inventory.InventoryAccountType AS InventoryAccountType,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.CostObject AS CostObject,
	|	Inventory.Quantity AS Quantity,
	|	Inventory.Amount AS Amount,
	|	Inventory.Department AS Department,
	|	Inventory.Responsible AS Responsible,
	|	Inventory.VATRate AS VATRate,
	|	Inventory.OfflineRecord AS OfflineRecord,
	|	Inventory.SalesRep AS SalesRep,
	|	Inventory.Counterparty AS Counterparty,
	|	Inventory.Currency AS Currency,
	|	GoodsIssueTable.SalesOrder AS SalesOrder,
	|	GoodsIssueTable.Document AS Document,
	|	GoodsIssueTable.GoodsIssue AS GoodsIssue,
	|	GoodsIssueTable.Period AS Period
	|INTO GoodsIssueCOGS
	|FROM
	|	GoodsIssueTable AS GoodsIssueTable
	|		INNER JOIN AccumulationRegister.Inventory AS Inventory
	|		ON GoodsIssueTable.GoodsIssue = Inventory.Recorder
	|			AND GoodsIssueTable.Products = Inventory.Products
	|			AND GoodsIssueTable.Characteristic = Inventory.Characteristic
	|			AND GoodsIssueTable.Batch = Inventory.Batch
	|			AND GoodsIssueTable.Ownership = Inventory.Ownership
	|			AND GoodsIssueTable.StructuralUnit = Inventory.StructuralUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Ref AS Ref
	|INTO Recorders
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	TemporaryTableInventory.GoodsIssue
	|FROM
	|	SourceInventory AS TemporaryTableInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.PresentationCurrency AS PresentationCurrency,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.Ownership AS Ownership,
	|	InventoryBalances.CostObject AS CostObject,
	|	InventoryBalances.InventoryAccountType AS InventoryAccountType,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.PresentationCurrency AS PresentationCurrency,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.Ownership AS Ownership,
	|		InventoryBalances.CostObject AS CostObject,
	|		InventoryBalances.InventoryAccountType AS InventoryAccountType,
	|		InventoryBalances.QuantityBalance AS QuantityBalance,
	|		InventoryBalances.AmountBalance AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, PresentationCurrency, StructuralUnit, Products, Characteristic, Batch, Ownership, CostObject, InventoryAccountType) IN
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.PresentationCurrency,
	|						CASE
	|							WHEN TableInventory.DropShipping
	|								THEN VALUE(Catalog.BusinessUnits.DropShipping)
	|							ELSE TableInventory.StructuralUnit
	|						END,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.Ownership,
	|						TableInventory.CostObject,
	|						TableInventory.InventoryAccountType
	|					FROM
	|						TemporaryTableInventoryOwnership AS TableInventory)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.PresentationCurrency,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		DocumentRegisterRecordsInventory.Ownership,
	|		DocumentRegisterRecordsInventory.CostObject,
	|		DocumentRegisterRecordsInventory.InventoryAccountType,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder IN
	|				(SELECT
	|					Recorders.Ref AS Ref
	|				FROM
	|					Recorders AS Recorders)
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InventoryBalances.Company,
	|		InventoryBalances.PresentationCurrency,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.Ownership,
	|		InventoryBalances.CostObject,
	|		InventoryBalances.InventoryAccountType,
	|		InventoryBalances.QuantityBalance,
	|		InventoryBalances.AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, PresentationCurrency, StructuralUnit, Products, Characteristic, Batch, Ownership, CostObject, InventoryAccountType) IN
	|					(SELECT
	|						GoodsIssueCOGS.Company,
	|						GoodsIssueCOGS.PresentationCurrency,
	|						GoodsIssueCOGS.StructuralUnit,
	|						GoodsIssueCOGS.Products,
	|						GoodsIssueCOGS.Characteristic,
	|						GoodsIssueCOGS.Batch,
	|						GoodsIssueCOGS.Ownership,
	|						GoodsIssueCOGS.CostObject,
	|						GoodsIssueCOGS.InventoryAccountType
	|					FROM
	|						GoodsIssueCOGS AS GoodsIssueCOGS)) AS InventoryBalances) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.PresentationCurrency,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.Ownership,
	|	InventoryBalances.CostObject,
	|	InventoryBalances.InventoryAccountType";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add(
		"Company, PresentationCurrency, StructuralUnit, Products, Characteristic, Batch, Ownership, CostObject");
	
	TemporaryTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();
	TableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory;
	
	Query.Text =
	"SELECT
	|	GoodsIssueCOGS.Period AS Period,
	|	GoodsIssueCOGS.Recorder AS Recorder,
	|	GoodsIssueCOGS.Active AS Active,
	|	GoodsIssueCOGS.RecordType AS RecordType,
	|	GoodsIssueCOGS.Company AS Company,
	|	GoodsIssueCOGS.PresentationCurrency AS PresentationCurrency,
	|	GoodsIssueCOGS.Products AS Products,
	|	GoodsIssueCOGS.Characteristic AS Characteristic,
	|	GoodsIssueCOGS.Batch AS Batch,
	|	GoodsIssueCOGS.Ownership AS Ownership,
	|	GoodsIssueCOGS.GLAccount AS GLAccount,
	|	GoodsIssueCOGS.StructuralUnit AS StructuralUnit,
	|	GoodsIssueCOGS.CostObject AS CostObject,
	|	GoodsIssueCOGS.Quantity AS Quantity,
	|	GoodsIssueCOGS.Amount AS Amount,
	|	GoodsIssueCOGS.Department AS Department,
	|	GoodsIssueCOGS.Responsible AS Responsible,
	|	GoodsIssueCOGS.VATRate AS VATRate,
	|	GoodsIssueCOGS.OfflineRecord AS OfflineRecord,
	|	GoodsIssueCOGS.SalesRep AS SalesRep,
	|	GoodsIssueCOGS.Counterparty AS Counterparty,
	|	GoodsIssueCOGS.Currency AS Currency,
	|	GoodsIssueCOGS.SalesOrder AS SalesOrder,
	|	GoodsIssueCOGS.Document AS Document,
	|	GoodsIssueCOGS.GoodsIssue AS SourceDocument
	|FROM
	|	GoodsIssueCOGS AS GoodsIssueCOGS";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		GoodsIssueRow = TableInventory.Add();
		FillPropertyValues(GoodsIssueRow, Selection);
	EndDo;
	
	For n = 0 To TableInventory.Count() - 1 Do
		
		RowTableInventory = TableInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("PresentationCurrency", RowTableInventory.PresentationCurrency);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		StructureForSearch.Insert("Ownership", RowTableInventory.Ownership);
		StructureForSearch.Insert("CostObject", RowTableInventory.CostObject);
		
		QuantityRequiredAvailableBalance = ?(ValueIsFilled(RowTableInventory.Quantity), RowTableInventory.Quantity, 0);
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 And QuantityBalance > QuantityRequiredAvailableBalance Then
				
				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredAvailableBalance / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredAvailableBalance;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = QuantityRequiredAvailableBalance Then
				
				AmountToBeWrittenOff = AmountBalance;
				
				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			// GOGS made by Goods issue 
			If TypeOf(RowTableInventory.SourceDocument) <> Type("DocumentRef.GoodsIssue") Then
			
				// Expense. Inventory.
				TableRowExpense = TemporaryTableInventory.Add();
				FillPropertyValues(TableRowExpense, RowTableInventory);
				
				TableRowExpense.Amount = AmountToBeWrittenOff;
				TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
				
				// Generate postings.
				If UseDefaultTypeOfAccounting And Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
					FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
					RowTableAccountingJournalEntries.Amount = AmountToBeWrittenOff;
				EndIf;
				
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					
					// Move income and expenses.
					RowIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
					FillPropertyValues(RowIncomeAndExpenses, RowTableInventory);
					
					RowIncomeAndExpenses.StructuralUnit = RowTableInventory.DepartmentSales;
					RowIncomeAndExpenses.GLAccount = RowTableInventory.GLAccountCost;
				RowIncomeAndExpenses.IncomeAndExpenseItem = RowTableInventory.CorrIncomeAndExpenseItem;
				
					RowIncomeAndExpenses.AmountIncome = 0;
					RowIncomeAndExpenses.AmountExpense = AmountToBeWrittenOff;
					
					RowIncomeAndExpenses.ContentOfAccountingRecord = NStr("en = 'Cost of goods sold'; ru = 'Отражение расходов';pl = 'Koszt własny towarów sprzedanych';es_ES = 'Coste de mercancías vendidas';es_CO = 'Coste de mercancías vendidas';tr = 'Satılan malların maliyeti';it = 'Costo dei beni venduti';de = 'Wareneinsatz'", MainLanguageCode);
					
				EndIf;
				
			EndIf;
			
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				// Move the cost of sales.
				SaleString = StructureAdditionalProperties.TableForRegisterRecords.TableSales.Add();
				FillPropertyValues(SaleString, RowTableInventory);
				SaleString.Quantity = 0;
				SaleString.Amount = 0;
				SaleString.VATAmount = 0;
				SaleString.AmountCur = 0;
				SaleString.VATAmountCur = 0;
				SaleString.Cost = AmountToBeWrittenOff;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
// Cash flow projection table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("NetDates", PaymentTermsServer.NetPaymentDates());
	
	Query.Text =
	"SELECT
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Date AS Date,
	|	SalesInvoice.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesInvoice.PaymentMethod AS PaymentMethod,
	|	SalesInvoice.Contract AS Contract,
	|	SalesInvoice.PettyCash AS PettyCash,
	|	SalesInvoice.ThirdPartyPayment AS ThirdPartyPayment,
	|	SalesInvoice.BankAccount AS BankAccount,
	|	SalesInvoice.ExchangeRate AS ExchangeRate,
	|	SalesInvoice.Multiplicity AS Multiplicity,
	|	SalesInvoice.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	SalesInvoice.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	SalesInvoice.CashAssetType AS CashAssetType
	|INTO Document
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref = &Ref
	|	AND SalesInvoice.SetPaymentTerms
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.PaymentDate AS Period,
	|	Document.PaymentMethod AS PaymentMethod,
	|	Document.Ref AS Quote,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	Document.PettyCash AS PettyCash,
	|	Document.BankAccount AS BankAccount,
	|	Document.Ref AS Ref,
	|	Document.ExchangeRate AS ExchangeRate,
	|	Document.Multiplicity AS Multiplicity,
	|	Document.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	Document.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	CASE
	|		WHEN Document.AmountIncludesVAT
	|			THEN DocumentTable.PaymentAmount
	|		ELSE DocumentTable.PaymentAmount + DocumentTable.PaymentVATAmount
	|	END AS PaymentAmount,
	|	Document.CashAssetType AS CashAssetType
	|INTO PaymentCalendar
	|FROM
	|	Document AS Document
	|		INNER JOIN Document.SalesInvoice.PaymentCalendar AS DocumentTable
	|		ON Document.Ref = DocumentTable.Ref
	|			AND DocumentTable.PaymentBaselineDate IN (&NetDates)
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON Document.Contract = CounterpartyContracts.Ref
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|WHERE
	|	NOT Document.ThirdPartyPayment
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentCalendar.Period AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	PaymentCalendar.PaymentMethod AS PaymentMethod,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	PaymentCalendar.Quote AS Quote,
	|	VALUE(Catalog.CashFlowItems.PaymentFromCustomers) AS Item,
	|	CASE
	|		WHEN PaymentCalendar.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN PaymentCalendar.PettyCash
	|		WHEN PaymentCalendar.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN PaymentCalendar.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	PaymentCalendar.SettlementsCurrency AS Currency,
	|	CAST(PaymentCalendar.PaymentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN PaymentCalendar.ExchangeRate * PaymentCalendar.ContractCurrencyMultiplicity / (PaymentCalendar.ContractCurrencyExchangeRate * PaymentCalendar.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN 1 / (PaymentCalendar.ExchangeRate * PaymentCalendar.ContractCurrencyMultiplicity / (PaymentCalendar.ContractCurrencyExchangeRate * PaymentCalendar.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount
	|FROM
	|	PaymentCalendar AS PaymentCalendar";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableSales(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Period AS Period,
	|	TableSales.Company AS Company,
	|	TableSales.PresentationCurrency AS PresentationCurrency,
	|	TableSales.Counterparty AS Counterparty,
	|	TableSales.DocumentCurrency AS Currency,
	|	TableSales.Products AS Products,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Batch AS Batch,
	|	TableSales.Ownership AS Ownership,
	|	CASE
	|		WHEN TableSales.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableSales.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableSales.Order
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	TableSales.Document AS Document,
	|	TableSales.VATRate AS VATRate,
	|	TableSales.DepartmentSales AS Department,
	|	TableSales.Responsible AS Responsible,
	|	SUM(TableSales.Quantity) AS Quantity,
	|	SUM(TableSales.VATAmount) AS VATAmount,
	|	SUM(TableSales.Amount - TableSales.VATAmount) AS Amount,
	|	SUM(TableSales.VATAmountDocCur) AS VATAmountCur,
	|	SUM(TableSales.AmountDocCur - TableSales.VATAmountDocCur) AS AmountCur,
	|	SUM(TableSales.SalesTaxAmount) AS SalesTaxAmount,
	|	SUM(TableSales.SalesTaxAmountDocCur) AS SalesTaxAmountCur,
	|	0 AS Cost,
	|	FALSE AS OfflineRecord,
	|	TableSales.SalesRep AS SalesRep,
	|	TableSales.BundleProduct AS BundleProduct,
	|	TableSales.BundleCharacteristic AS BundleCharacteristic,
	|	TableSales.DeliveryStartDate AS DeliveryStartDate,
	|	TableSales.DeliveryEndDate AS DeliveryEndDate,
	|	FALSE AS ZeroInvoice
	|FROM
	|	TemporaryTableInventoryOwnership AS TableSales
	|		LEFT JOIN Document.SalesOrder AS SalesOrder
	|		ON TableSales.Order = SalesOrder.Ref
	|WHERE
	|	(NOT TableSales.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|			OR NOT TableSales.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|			OR NOT TableSales.AdvanceInvoicing)
	|
	|GROUP BY
	|	TableSales.Period,
	|	TableSales.Company,
	|	TableSales.PresentationCurrency,
	|	TableSales.Counterparty,
	|	TableSales.DocumentCurrency,
	|	TableSales.Products,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	TableSales.Ownership,
	|	CASE
	|		WHEN TableSales.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableSales.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableSales.Order
	|		ELSE UNDEFINED
	|	END,
	|	TableSales.Document,
	|	TableSales.VATRate,
	|	TableSales.DepartmentSales,
	|	TableSales.Responsible,
	|	TableSales.SalesRep,
	|	TableSales.BundleProduct,
	|	TableSales.BundleCharacteristic,
	|	TableSales.DeliveryStartDate,
	|	TableSales.DeliveryEndDate,
	|	TableSales.ZeroInvoice
	|
	|UNION ALL
	|
	|SELECT
	|	TableSales.Period,
	|	TableSales.Company,
	|	TableSales.PresentationCurrency,
	|	TableSales.Counterparty,
	|	TableSales.Currency,
	|	TableSales.Products,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	TableSales.Ownership,
	|	TableSales.SalesOrder,
	|	TableSales.Document,
	|	TableSales.VATRate,
	|	TableSales.Department,
	|	TableSales.Responsible,
	|	TableSales.Quantity,
	|	TableSales.VATAmount,
	|	TableSales.Amount,
	|	TableSales.VATAmountCur,
	|	TableSales.AmountCur,
	|	TableSales.SalesTaxAmount,
	|	TableSales.SalesTaxAmountCur,
	|	TableSales.Cost,
	|	TableSales.OfflineRecord,
	|	TableSales.SalesRep,
	|	TableSales.BundleProduct,
	|	TableSales.BundleCharacteristic,
	|	TableSales.DeliveryStartDate,
	|	TableSales.DeliveryEndDate,
	|	TableSales.ZeroInvoice
	|FROM
	|	AccumulationRegister.Sales AS TableSales
	|WHERE
	|	TableSales.Recorder = &Ref
	|	AND TableSales.OfflineRecord
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	Header.Date,
	|	Header.Company,
	|	Header.PresentationCurrency,
	|	Header.Counterparty,
	|	Header.DocumentCurrency,
	|	ISNULL(TemporaryTableInventory.Products, UNDEFINED),
	|	UNDEFINED,
	|	UNDEFINED,
	|	&OwnInventory,
	|	UNDEFINED,
	|	Header.Ref,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	0,
	|	0,
	|	0,
	|	0,
	|	0,
	|	0,
	|	0,
	|	FALSE,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	ISNULL(TemporaryTableInventory.DeliveryStartDate, UNDEFINED),
	|	ISNULL(TemporaryTableInventory.DeliveryEndDate, UNDEFINED),
	|	TRUE
	|FROM
	|	SalesInvoiceTable AS Header
	|		LEFT JOIN TemporaryTableInventory AS TemporaryTableInventory
	|		ON Header.Ref = TemporaryTableInventory.Document
	|WHERE
	|	Header.ZeroInvoice";
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	Query.SetParameter("OwnInventory", Catalogs.InventoryOwnership.OwnInventory());
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableProductRelease(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableProductRelease.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProductRelease.Period AS Period,
	|	TableProductRelease.Company AS Company,
	|	TableProductRelease.DepartmentSales AS StructuralUnit,
	|	TableProductRelease.Products AS Products,
	|	TableProductRelease.Characteristic AS Characteristic,
	|	TableProductRelease.Ownership AS Ownership,
	|	CASE
	|		WHEN TableProductRelease.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableProductRelease.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableProductRelease.Order
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	SUM(TableProductRelease.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventoryOwnership AS TableProductRelease
	|WHERE
	|	TableProductRelease.ProductsType = VALUE(Enum.ProductsTypes.Service)
	|	AND NOT TableProductRelease.ZeroInvoice
	|	AND NOT TableProductRelease.DropShipping
	|
	|GROUP BY
	|	TableProductRelease.Period,
	|	TableProductRelease.Company,
	|	TableProductRelease.DepartmentSales,
	|	TableProductRelease.Products,
	|	TableProductRelease.Characteristic,
	|	TableProductRelease.Ownership,
	|	CASE
	|		WHEN TableProductRelease.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableProductRelease.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableProductRelease.Order
	|		ELSE UNDEFINED
	|	END";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductRelease", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventoryInWarehouses.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventoryInWarehouses.Period AS Period,
	|	TableInventoryInWarehouses.Company AS Company,
	|	TableInventoryInWarehouses.Products AS Products,
	|	TableInventoryInWarehouses.Characteristic AS Characteristic,
	|	TableInventoryInWarehouses.Batch AS Batch,
	|	TableInventoryInWarehouses.Ownership AS Ownership,
	|	TableInventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|	TableInventoryInWarehouses.Cell AS Cell,
	|	SUM(TableInventoryInWarehouses.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventoryOwnership AS TableInventoryInWarehouses
	|WHERE
	|	TableInventoryInWarehouses.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND NOT TableInventoryInWarehouses.AdvanceInvoicing
	|	AND TableInventoryInWarehouses.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|	AND NOT TableInventoryInWarehouses.ZeroInvoice
	|	AND NOT TableInventoryInWarehouses.DropShipping
	|
	|GROUP BY
	|	TableInventoryInWarehouses.Period,
	|	TableInventoryInWarehouses.Company,
	|	TableInventoryInWarehouses.Products,
	|	TableInventoryInWarehouses.Characteristic,
	|	TableInventoryInWarehouses.Batch,
	|	TableInventoryInWarehouses.Ownership,
	|	TableInventoryInWarehouses.StructuralUnit,
	|	TableInventoryInWarehouses.Cell";
		
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesOrders(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableSalesOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableSalesOrders.Period AS Period,
	|	TableSalesOrders.Company AS Company,
	|	TableSalesOrders.Products AS Products,
	|	TableSalesOrders.Characteristic AS Characteristic,
	|	TableSalesOrders.Order AS SalesOrder,
	|	SUM(TableSalesOrders.Quantity) AS Quantity,
	|	SUM(CASE
	|			WHEN TableSalesOrders.DropShipping
	|				THEN TableSalesOrders.Quantity
	|			ELSE 0
	|		END) AS DropShippingQuantity
	|FROM
	|	TemporaryTableInventoryOwnership AS TableSalesOrders
	|WHERE
	|	VALUETYPE(TableSalesOrders.Order) = TYPE(Document.SalesOrder)
	|	AND TableSalesOrders.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND TableSalesOrders.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|	AND NOT TableSalesOrders.ZeroInvoice
	|
	|GROUP BY
	|	TableSalesOrders.Period,
	|	TableSalesOrders.Company,
	|	TableSalesOrders.Products,
	|	TableSalesOrders.Characteristic,
	|	TableSalesOrders.Order";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSalesOrders", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableWorkOrders(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableSalesOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableSalesOrders.Period AS Period,
	|	TableSalesOrders.Company AS Company,
	|	TableSalesOrders.Products AS Products,
	|	TableSalesOrders.Characteristic AS Characteristic,
	|	TableSalesOrders.Order AS WorkOrder,
	|	SUM(TableSalesOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventoryOwnership AS TableSalesOrders
	|WHERE
	|	VALUETYPE(TableSalesOrders.Order) = TYPE(Document.WorkOrder)
	|	AND TableSalesOrders.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|	AND TableSalesOrders.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|	AND NOT TableSalesOrders.ZeroInvoice
	|
	|GROUP BY
	|	TableSalesOrders.Period,
	|	TableSalesOrders.Company,
	|	TableSalesOrders.Products,
	|	TableSalesOrders.Characteristic,
	|	TableSalesOrders.Order";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableWorkOrders", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableIncomeAndExpenses.LineNumber AS LineNumber,
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.PresentationCurrency AS PresentationCurrency,
	|	TableIncomeAndExpenses.DepartmentSales AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLineSales AS BusinessLine,
	|	CASE
	|		WHEN TableIncomeAndExpenses.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableIncomeAndExpenses.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableIncomeAndExpenses.Order
	|	END AS SalesOrder,
	|	TableIncomeAndExpenses.RevenueItem AS IncomeAndExpenseItem,
	|	TableIncomeAndExpenses.AccountStatementSales AS GLAccount,
	|	CAST(&Income AS STRING(100)) AS ContentOfAccountingRecord,
	|	SUM(TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) AS AmountIncome,
	|	0 AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventoryOwnership AS TableIncomeAndExpenses
	|WHERE
	|	TableIncomeAndExpenses.Amount <> 0
	|	AND (NOT TableIncomeAndExpenses.AdvanceInvoicing
	|			OR NOT TableIncomeAndExpenses.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|			OR NOT TableIncomeAndExpenses.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|	AND NOT TableIncomeAndExpenses.ZeroInvoice
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Period,
	|	TableIncomeAndExpenses.LineNumber,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.PresentationCurrency,
	|	TableIncomeAndExpenses.DepartmentSales,
	|	TableIncomeAndExpenses.BusinessLineSales,
	|	TableIncomeAndExpenses.Order,
	|	TableIncomeAndExpenses.RevenueItem,
	|	TableIncomeAndExpenses.AccountStatementSales
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	UNDEFINED,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &FXIncomeItem
	|		ELSE &FXExpenseItem
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	FALSE
	|FROM
	|	(SELECT
	|		TableExchangeRateDifferencesAccountsReceivable.Date AS Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company AS Company,
	|		TableExchangeRateDifferencesAccountsReceivable.PresentationCurrency AS PresentationCurrency,
	|		SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.PresentationCurrency AS PresentationCurrency,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.PresentationCurrency,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableExchangeRateDifferencesAccountsReceivable
	|	
	|	GROUP BY
	|		TableExchangeRateDifferencesAccountsReceivable.Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company,
	|		TableExchangeRateDifferencesAccountsReceivable.PresentationCurrency
	|	
	|	HAVING
	|		(SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) <= -0.005)) AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("FXIncomeItem",									Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem",									Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	Query.SetParameter("Income",										NStr("en = 'Revenue'; ru = 'Выручка от продажи';pl = 'Przychód';es_ES = 'Ingreso';es_CO = 'Ingreso';tr = 'Gelir';it = 'Ricavo';de = 'Erlös'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("Ref",											DocumentRefSalesInvoice);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCustomerAccounts(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	ExpectedPayments = NStr("en = 'Expected payment'; ru = 'Ожидаемый платеж';pl = 'Oczekiwana płatność';es_ES = 'Pago esperado';es_CO = 'Pago esperado';tr = 'Beklenen ödeme';it = 'Pagamento previsto';de = 'Erwartete Zahlung'", DefaultLanguageCode);
	AdvanceCredit = NStr("en = 'Advance payment clearing'; ru = 'Зачет аванса';pl = 'Rozliczanie zaliczki';es_ES = 'Amortización de pagos anticipados';es_CO = 'Amortización de pagos anticipados';tr = 'Avans ödeme mahsuplaştırılması';it = 'Annullamento del pagamento anticipato';de = 'Verrechnung der Vorauszahlung'", DefaultLanguageCode);
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfCustomerLiability", NStr("en = 'Accounts receivable recognition'; ru = 'Возникновение обязательств покупателя';pl = 'Należności przyjęcte do ewidencji';es_ES = 'Reconocimientos de las cuentas a cobrar';es_CO = 'Reconocimientos de las cuentas a cobrar';tr = 'Alacak hesapların onaylanması';it = 'Riconoscimento dei crediti';de = 'Offene Posten Debitoren Aufnahme'", DefaultLanguageCode));
	Query.SetParameter("AppearenceOfCustomerAdvance", NStr("en = 'Advance payment recognition'; ru = 'Принятие авансового платежа к учету';pl = 'Przyjęcie do ewidencji zaliczki';es_ES = 'Reconocimiento de pago adelantado';es_CO = 'Reconocimiento de pago adelantado';tr = 'Avans ödemenin mali tablolara alınması';it = 'Riconoscimento pagamento anticipo';de = 'Aufnahme von Vorauszahlungen'", DefaultLanguageCode));
	Query.SetParameter("AppearenceOfCustomerAdvanceAllocated", NStr("en = 'Advance payment allocation'; ru = 'Распределение авансового платежа';pl = 'Alokacja zaliczki';es_ES = 'Asignación de pago adelantado';es_CO = 'Asignación de pago adelantado';tr = 'Avans ödeme tahsisi';it = 'Allocazione pagamento anticipo';de = 'Zuordnung von Vorauszahlungen'", DefaultLanguageCode));
	Query.SetParameter("ThirdPartyPayerLiability", 
		NStr("en = 'Accounts receivable recognition by a third-party payer'; ru = 'Принятие к учету дебиторской задолженности по стороннему плательщику';pl = 'Przyjęcie do ewidencji należności przez płatnika strony trzeciej';es_ES = 'Reconocimiento de cuentas por cobrar por un tercero pagador';es_CO = 'Reconocimiento de cuentas por cobrar por un tercero pagador';tr = 'Üçüncü taraf ödeyen tarafından alacak hesapların onaylanması';it = 'Riconoscimento dei crediti contabili da parte un terzo pagante';de = 'Aufnahme von Offene Posten Debitoren vom Drittzahler'", DefaultLanguageCode));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", DefaultLanguageCode));
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.SetParameter("AdvanceCredit", AdvanceCredit);
	Query.SetParameter("ExpectedPayments", ExpectedPayments);
	
	// Generate temporary table by accounts payable.
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.GLAccountCustomerSettlements AS GLAccount,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	CASE
	|		WHEN SUM(DocumentTable.Amount + DocumentTable.SalesTaxAmount) >= 0
	|			THEN VALUE(Enum.SettlementsTypes.Debt)
	|		ELSE VALUE(Enum.SettlementsTypes.Advance)
	|	END AS SettlementsType,
	|	SUM(DocumentTable.Amount + DocumentTable.SalesTaxAmount) AS Amount,
	|	SUM(DocumentTable.AmountCur + DocumentTable.SalesTaxAmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount + DocumentTable.SalesTaxAmount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur + DocumentTable.SalesTaxAmountCur) AS AmountCurForBalance,
	|	CASE
	|		WHEN DocumentTable.SetPaymentTerms
	|				OR SUM(DocumentTable.Amount + DocumentTable.SalesTaxAmount) < 0
	|			THEN 0
	|		ELSE SUM(DocumentTable.Amount + DocumentTable.SalesTaxAmount)
	|	END AS AmountForPayment,
	|	CASE
	|		WHEN DocumentTable.SetPaymentTerms
	|				OR SUM(DocumentTable.Amount + DocumentTable.SalesTaxAmount) < 0
	|			THEN 0
	|		ELSE SUM(DocumentTable.AmountCur + DocumentTable.SalesTaxAmountCur)
	|	END AS AmountForPaymentCur,
	|	CASE
	|		WHEN SUM(DocumentTable.Amount + DocumentTable.SalesTaxAmount) >= 0
	|			THEN CAST(&AppearenceOfCustomerLiability AS STRING(100))
	|		ELSE CAST(&AppearenceOfCustomerAdvance AS STRING(100))
	|	END AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTableInventoryOwnership AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SetPaymentTerms,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountCustomerSettlements
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	DocumentTable.Contract,
	|	DocumentTable.Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	VALUE(Enum.SettlementsTypes.Debt),
	|	0,
	|	0,
	|	0,
	|	0,
	|	0,
	|	0,
	|	CAST(&AppearenceOfCustomerLiability AS STRING(100))
	|FROM
	|	TemporaryTableInventoryOwnership AS DocumentTable
	|WHERE
	|	DocumentTable.ZeroInvoice
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	VALUE(AccumulationRecordType.Receipt),
	|	Header.Date,
	|	Header.Company,
	|	Header.PresentationCurrency,
	|	Header.Counterparty,
	|	UNDEFINED,
	|	Header.Contract,
	|	Header.Ref,
	|	UNDEFINED,
	|	Header.DocumentCurrency,
	|	VALUE(Enum.SettlementsTypes.Debt),
	|	0,
	|	0,
	|	0,
	|	0,
	|	0,
	|	0,
	|	CAST(&AppearenceOfCustomerLiability AS STRING(100))
	|FROM
	|	SalesInvoiceTable AS Header
	|		LEFT JOIN TemporaryTableInventoryOwnership AS TemporaryTableInventory
	|		ON Header.Ref = TemporaryTableInventory.Document
	|WHERE
	|	Header.ZeroInvoice
	|	AND TemporaryTableInventory.Products IS NULL
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	DocumentTable.Contract,
	|	DocumentTable.Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	VALUE(Enum.SettlementsTypes.Debt),
	|	SUM(DocumentTable.Amount + DocumentTable.SalesTaxAmount),
	|	SUM(DocumentTable.AmountCur + DocumentTable.SalesTaxAmountCur),
	|	SUM(DocumentTable.Amount + DocumentTable.SalesTaxAmount),
	|	SUM(DocumentTable.AmountCur + DocumentTable.SalesTaxAmountCur),
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.Amount + DocumentTable.SalesTaxAmount
	|		END),
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.AmountCur + DocumentTable.SalesTaxAmountCur
	|		END),
	|	CAST(&AppearenceOfCustomerLiability AS STRING(100))
	|FROM
	|	TemporaryTableInventoryOwnership AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.ThirdPartyPayment
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountCustomerSettlements
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Payer,
	|	DocumentTable.ThirdPartyPayerGLAccount,
	|	DocumentTable.PayerContract,
	|	DocumentTable.Document,
	|	UNDEFINED,
	|	DocumentTable.PayerSettlementsCurrency,
	|	VALUE(Enum.SettlementsTypes.Debt),
	|	SUM(DocumentTable.Amount + DocumentTable.SalesTaxAmount),
	|	SUM(DocumentTable.AmountCur + DocumentTable.SalesTaxAmountCur),
	|	SUM(DocumentTable.Amount + DocumentTable.SalesTaxAmount),
	|	SUM(DocumentTable.AmountCur + DocumentTable.SalesTaxAmountCur),
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.Amount + DocumentTable.SalesTaxAmount
	|		END),
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.AmountCur + DocumentTable.SalesTaxAmountCur
	|		END),
	|	CAST(&ThirdPartyPayerLiability AS STRING(100))
	|FROM
	|	TemporaryTableInventoryOwnership AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.ThirdPartyPayment
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Payer,
	|	DocumentTable.PayerContract,
	|	DocumentTable.Document,
	|	DocumentTable.PayerSettlementsCurrency,
	|	DocumentTable.ThirdPartyPayerGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.CustomerAdvancesGLAccount,
	|	DocumentTable.Contract,
	|	DocumentTable.Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlementsType,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS STRING(100))
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsType,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.CustomerAdvancesGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	DocumentTable.Contract,
	|	DocumentTable.DocumentWhere,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	-SUM(DocumentTable.Amount),
	|	-SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS STRING(100))
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.DocumentWhere,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.AccountsReceivableGLAccount,
	|	DocumentTable.Contract,
	|	DocumentTable.Ref,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	VALUE(Enum.SettlementsTypes.Advance),
	|	DocumentTable.Amount,
	|	DocumentTable.Amount,
	|	DocumentTable.Amount,
	|	DocumentTable.Amount,
	|	0,
	|	0,
	|	CAST(&AppearenceOfCustomerAdvanceAllocated AS STRING(100))
	|FROM
	|	TemporaryTableAmountAllocation AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.AllocationGLAccount,
	|	DocumentTable.Contract,
	|	DocumentTable.Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	VALUE(Enum.SettlementsTypes.Debt),
	|	DocumentTable.Amount,
	|	DocumentTable.Amount,
	|	DocumentTable.Amount,
	|	DocumentTable.Amount,
	|	DocumentTable.Amount,
	|	DocumentTable.Amount,
	|	CAST(&AppearenceOfCustomerAdvanceAllocated AS STRING(100))
	|FROM
	|	TemporaryTableAmountAllocation AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	Calendar.Period,
	|	Calendar.Company,
	|	Calendar.PresentationCurrency,
	|	Calendar.Counterparty,
	|	Calendar.GLAccountCustomerSettlements,
	|	Calendar.Contract,
	|	Calendar.DocumentWhere,
	|	CASE
	|		WHEN Calendar.DoOperationsByOrders
	|				AND Calendar.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND Calendar.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN Calendar.Order
	|		ELSE UNDEFINED
	|	END,
	|	Calendar.SettlementsCurrency,
	|	Calendar.SettlemensTypeWhere,
	|	0,
	|	0,
	|	0,
	|	0,
	|	Calendar.Amount,
	|	Calendar.AmountCur,
	|	CAST(&ExpectedPayments AS STRING(100))
	|FROM
	|	TemporaryTablePaymentCalendar AS Calendar
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	Counterparty,
	|	Contract,
	|	Currency,
	|	Document,
	|	Order,
	|	SettlementsType,
	|	GLAccount,
	|	Currency";
	
	Query.Execute();
	
	// Setting the exclusive lock for the controlled balances of accounts receivable.
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsReceivable.Company AS Company,
	|	TemporaryTableAccountsReceivable.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableAccountsReceivable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsReceivable.Contract AS Contract,
	|	TemporaryTableAccountsReceivable.Document AS Document,
	|	TemporaryTableAccountsReceivable.Order AS Order,
	|	TemporaryTableAccountsReceivable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsReceivable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsReceivable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextCurrencyExchangeRateAccountsReceivable(Query.TempTablesManager, True, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	TableAccountsReceivable = PaymentTermsServer.RecalculateAmountForExpectedPayments(
		StructureAdditionalProperties, 
		ResultsArray[QueryNumber].Unload(), 
		ExpectedPayments);
	
	If StructureAdditionalProperties.ForPosting.IsZeroInvoice Then
		
		DriveServer.SetZeroInvoiceInTable(TableAccountsReceivable);
		
	EndIf;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsReceivable", TableAccountsReceivable);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableThirdPartyPayments(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableThirdPartyPayments.Period AS Period,
	|	TableThirdPartyPayments.Company AS Company,
	|	TableThirdPartyPayments.Payer AS Payer,
	|	TableThirdPartyPayments.PayerContract AS PayerContract,
	|	TableThirdPartyPayments.Counterparty AS Counterparty,
	|	TableThirdPartyPayments.Contract AS Contract,
	|	TableThirdPartyPayments.Document AS Document,
	|	SUM(TableThirdPartyPayments.AmountCur + TableThirdPartyPayments.SalesTaxAmountCur) AS Amount
	|FROM
	|	TemporaryTableInventoryOwnership AS TableThirdPartyPayments
	|WHERE
	|	TableThirdPartyPayments.Amount <> 0
	|	AND TableThirdPartyPayments.ThirdPartyPayment
	|	AND NOT TableThirdPartyPayments.ZeroInvoice
	|
	|GROUP BY
	|	TableThirdPartyPayments.Period,
	|	TableThirdPartyPayments.Company,
	|	TableThirdPartyPayments.PresentationCurrency,
	|	TableThirdPartyPayments.Payer,
	|	TableThirdPartyPayments.PayerContract,
	|	TableThirdPartyPayments.Counterparty,
	|	TableThirdPartyPayments.Contract,
	|	TableThirdPartyPayments.Document";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableThirdPartyPayments", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	&Ref AS Document,
	|	DocumentTable.BusinessLineSales AS BusinessLine,
	|	DocumentTable.Amount - DocumentTable.VATAmount AS AmountIncome
	|FROM
	|	TemporaryTableInventoryOwnership AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Amount <> 0
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.Company AS Company,
	|	SUM(DocumentTable.Amount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|GROUP BY
	|	DocumentTable.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Item AS Item
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|ORDER BY
	|	LineNumber";
	
	ResultsArray = Query.ExecuteBatch();
	
	TableInventoryIncomeAndExpensesRetained = ResultsArray[0].Unload();
	SelectionOfQueryResult = ResultsArray[1].Select();
	
	TablePrepaymentIncomeAndExpensesRetained = TableInventoryIncomeAndExpensesRetained.Copy();
	TablePrepaymentIncomeAndExpensesRetained.Clear();
	
	If SelectionOfQueryResult.Next() Then
		AmountToBeWrittenOff = SelectionOfQueryResult.AmountToBeWrittenOff;
		For Each StringInventoryIncomeAndExpensesRetained In TableInventoryIncomeAndExpensesRetained Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountIncome <= AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				AmountToBeWrittenOff = AmountToBeWrittenOff - StringInventoryIncomeAndExpensesRetained.AmountIncome;
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountIncome > AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				StringPrepaymentIncomeAndExpensesRetained.AmountIncome = AmountToBeWrittenOff;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndIf;
	
	For Each StringPrepaymentIncomeAndExpensesRetained In TablePrepaymentIncomeAndExpensesRetained Do
		StringInventoryIncomeAndExpensesRetained = TableInventoryIncomeAndExpensesRetained.Add();
		FillPropertyValues(StringInventoryIncomeAndExpensesRetained, StringPrepaymentIncomeAndExpensesRetained);
		StringInventoryIncomeAndExpensesRetained.RecordType = AccumulationRecordType.Expense;
	EndDo;
	
	SelectionOfQueryResult = ResultsArray[2].Select();
	
	If SelectionOfQueryResult.Next() Then
		Item = SelectionOfQueryResult.Item;
	Else
		Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	EndIf;
	
	Query.Text =
	"SELECT
	|	Table.LineNumber AS LineNumber,
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Document AS Document,
	|	&Item AS Item,
	|	Table.BusinessLine AS BusinessLine,
	|	Table.AmountIncome AS AmountIncome
	|INTO TemporaryTablePrepaidIncomeAndExpensesRetained
	|FROM
	|	&Table AS Table";
	Query.SetParameter("Table", TablePrepaymentIncomeAndExpensesRetained);
	Query.SetParameter("Item", Item);
	
	Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", TableInventoryIncomeAndExpensesRetained);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableUnallocatedExpenses(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.Amount AS AmountIncome
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableUnallocatedExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.DocumentDate AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS BusinessLine,
	|	DocumentTable.Item AS Item,
	|	-DocumentTable.Amount AS AmountIncome
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Period,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.BusinessLine,
	|	Table.Item,
	|	Table.AmountIncome
	|FROM
	|	TemporaryTablePrepaidIncomeAndExpensesRetained AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableAccountingJournalEntries.Period AS Period,
	|	TableAccountingJournalEntries.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements AS AccountDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	TableAccountingJournalEntries.AccountStatementSales AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount AS Amount,
	|	&IncomeReflection AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventoryOwnership AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.Amount <> 0
	|	AND NOT TableAccountingJournalEntries.ZeroInvoice
	|	AND (NOT TableAccountingJournalEntries.AdvanceInvoicing
	|			OR NOT TableAccountingJournalEntries.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|			OR NOT TableAccountingJournalEntries.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.AccountStatementDeferredSales,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount,
	|	&DeferredIncomeReflection,
	|	FALSE
	|FROM
	|	TemporaryTableInventoryOwnership AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.Amount <> 0
	|	AND TableAccountingJournalEntries.AdvanceInvoicing
	|	AND TableAccountingJournalEntries.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|	AND TableAccountingJournalEntries.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND NOT TableAccountingJournalEntries.ZeroInvoice
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.CustomerAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.CustomerAdvancesGLAccountForeignCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.CustomerAdvancesGLAccountForeignCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlementsCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlementsCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	&SetOffAdvancePayment,
	|	FALSE
	|FROM
	|	(SELECT
	|		DocumentTable.Period AS Period,
	|		DocumentTable.Company AS Company,
	|		DocumentTable.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|		DocumentTable.CustomerAdvancesGLAccountForeignCurrency AS CustomerAdvancesGLAccountForeignCurrency,
	|		DocumentTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|		DocumentTable.GLAccountCustomerSettlementsCurrency AS GLAccountCustomerSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|		SUM(DocumentTable.AmountCur) AS AmountCur,
	|		SUM(DocumentTable.Amount) AS Amount
	|	FROM
	|		(SELECT
	|			DocumentTable.Period AS Period,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|			DocumentTable.CustomerAdvancesGLAccount.Currency AS CustomerAdvancesGLAccountForeignCurrency,
	|			DocumentTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|			DocumentTable.GLAccountCustomerSettlements.Currency AS GLAccountCustomerSettlementsCurrency,
	|			DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|			DocumentTable.AmountCur AS AmountCur,
	|			DocumentTable.Amount AS Amount
	|		FROM
	|			TemporaryTablePrepayment AS DocumentTable
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.Counterparty.CustomerAdvancesGLAccount,
	|			DocumentTable.Counterparty.CustomerAdvancesGLAccount.Currency,
	|			DocumentTable.Counterparty.GLAccountCustomerSettlements,
	|			DocumentTable.Counterparty.GLAccountCustomerSettlements.Currency,
	|			DocumentTable.Currency,
	|			0,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Company,
	|		DocumentTable.CustomerAdvancesGLAccount,
	|		DocumentTable.CustomerAdvancesGLAccountForeignCurrency,
	|		DocumentTable.GLAccountCustomerSettlements,
	|		DocumentTable.GLAccountCustomerSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency
	|	
	|	HAVING
	|		(SUM(DocumentTable.Amount) >= 0.005
	|			OR SUM(DocumentTable.Amount) <= -0.005
	|			OR SUM(DocumentTable.AmountCur) >= 0.005
	|			OR SUM(DocumentTable.AmountCur) <= -0.005)) AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	TableAccountingJournalEntries.Date,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN TableAccountingJournalEntries.GLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|				AND TableAccountingJournalEntries.GLAccountForeignCurrency
	|			THEN TableAccountingJournalEntries.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE TableAccountingJournalEntries.GLAccount
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences < 0
	|				AND TableAccountingJournalEntries.GLAccountForeignCurrency
	|			THEN TableAccountingJournalEntries.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN TableAccountingJournalEntries.AmountOfExchangeDifferences
	|		ELSE -TableAccountingJournalEntries.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	(SELECT
	|		TableExchangeRateDifferencesAccountsReceivable.Date AS Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company AS Company,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccount AS GLAccount,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccountForeignCurrency AS GLAccountForeignCurrency,
	|		TableExchangeRateDifferencesAccountsReceivable.Currency AS Currency,
	|		SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.GLAccount AS GLAccount,
	|			DocumentTable.GLAccount.Currency AS GLAccountForeignCurrency,
	|			DocumentTable.Currency AS Currency,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.GLAccount,
	|			DocumentTable.GLAccount.Currency,
	|			DocumentTable.Currency,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableExchangeRateDifferencesAccountsReceivable
	|	
	|	GROUP BY
	|		TableExchangeRateDifferencesAccountsReceivable.Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccount,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccountForeignCurrency,
	|		TableExchangeRateDifferencesAccountsReceivable.Currency
	|	
	|	HAVING
	|		(SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) <= -0.005)) AS TableAccountingJournalEntries
	|
	|UNION ALL
	|
	|SELECT
	|	7,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	SUM(CASE
	|			WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|				THEN TableAccountingJournalEntries.VATAmountCur
	|			ELSE 0
	|		END),
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	UNDEFINED,
	|	0,
	|	SUM(TableAccountingJournalEntries.VATAmount),
	|	&VAT,
	|	FALSE
	|FROM
	|	TemporaryTableInventoryOwnership AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.VATAmount <> 0
	|	AND NOT TableAccountingJournalEntries.ZeroInvoice
	|
	|GROUP BY
	|	TableAccountingJournalEntries.Company,
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements,
	|	TableAccountingJournalEntries.VATAmount,
	|	TableAccountingJournalEntries.Period,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	TableAccountingJournalEntries.VATOutputGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	9,
	|	PrepaymentVAT.Period,
	|	PrepaymentVAT.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&VATOutput,
	|	UNDEFINED,
	|	0,
	|	&VATAdvancesFromCustomers,
	|	UNDEFINED,
	|	0,
	|	SUM(PrepaymentVAT.VATAmount),
	|	&ContentVATRevenue,
	|	FALSE
	|FROM
	|	TemporaryTablePrepaymentVAT AS PrepaymentVAT
	|WHERE
	|	&PostVATEntriesBySourceDocuments
	|
	|GROUP BY
	|	PrepaymentVAT.Period,
	|	PrepaymentVAT.Company
	|
	|UNION ALL
	|
	|SELECT
	|	10,
	|	TemporarySalesTax.Period,
	|	TemporarySalesTax.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TemporarySalesTax.AccountsReceivableGLAccount,
	|	CASE
	|		WHEN TemporarySalesTax.AccountsReceivableGLAccount.Currency
	|			THEN TemporarySalesTax.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporarySalesTax.AccountsReceivableGLAccount.Currency
	|			THEN TemporarySalesTax.AmountCur
	|		ELSE 0
	|	END,
	|	TemporarySalesTax.TaxGLAccount,
	|	UNDEFINED,
	|	0,
	|	TemporarySalesTax.Amount,
	|	&SalesTaxAccrued,
	|	FALSE
	|FROM
	|	TemporarySalesTax AS TemporarySalesTax
	|
	|UNION ALL
	|
	|SELECT
	|	11,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.ThirdPartyPayerGLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.ThirdPartyPayerGLAccount.Currency
	|			THEN TableAccountingJournalEntries.PayerSettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.ThirdPartyPayerGLAccount.Currency
	|			THEN TableAccountingJournalEntries.AmountCur + TableAccountingJournalEntries.SalesTaxAmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.PayerSettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.AmountCur + TableAccountingJournalEntries.SalesTaxAmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.Amount + TableAccountingJournalEntries.SalesTaxAmount,
	|	&ThirdPartyPayerLiability,
	|	FALSE
	|FROM
	|	TemporaryTableInventoryOwnership AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.Amount <> 0
	|	AND TableAccountingJournalEntries.ThirdPartyPayment
	|	AND NOT TableAccountingJournalEntries.ZeroInvoice
	|
	|UNION ALL
	|
	|SELECT
	|	12 AS Ordering,
	|	TableAccountingJournalEntries.Period AS Period,
	|	TableAccountingJournalEntries.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableAccountingJournalEntries.AccountsReceivableGLAccount AS AccountDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AccountsReceivableGLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AccountsReceivableGLAccount.Currency
	|			THEN TableAccountingJournalEntries.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	TableAccountingJournalEntries.AllocationGLAccount AS AccountCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AllocationGLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AllocationGLAccount.Currency
	|			THEN TableAccountingJournalEntries.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	TableAccountingJournalEntries.Amount AS Amount,
	|	&AdvanceAllocation AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableAmountAllocation AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.Amount <> 0
	|
	|UNION ALL
	|
	|SELECT
	|	13,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PlanningPeriod,
	|	OfflineRecords.AccountDr,
	|	OfflineRecords.CurrencyDr,
	|	OfflineRecords.AmountCurDr,
	|	OfflineRecords.AccountCr,
	|	OfflineRecords.CurrencyCr,
	|	OfflineRecords.AmountCurCr,
	|	OfflineRecords.Amount,
	|	OfflineRecords.Content,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|
	|ORDER BY
	|	Ordering";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("SetOffAdvancePayment",							NStr("en = 'Advance payment clearing'; ru = 'Зачет аванса';pl = 'Rozliczanie zaliczki';es_ES = 'Amortización de pagos anticipados';es_CO = 'Amortización de pagos anticipados';tr = 'Avans ödeme mahsuplaştırılması';it = 'Annullamento del pagamento anticipato';de = 'Verrechnung der Vorauszahlung'", MainLanguageCode));
	Query.SetParameter("PrepaymentReversal",							NStr("en = 'Advance payment reversal'; ru = 'Сторнирование аванса';pl = 'Anulowanie zaliczki';es_ES = 'Inversión del pago anticipado';es_CO = 'Inversión del pago anticipado';tr = 'Avans ödeme iptali';it = 'Restituzione del pagamento anticipato';de = 'Stornierung der Vorauszahlung'", MainLanguageCode));
	Query.SetParameter("ReversingSupplies",								NStr("en = 'Purchase reversal'; ru = 'Сторнирование поставки';pl = 'Anulowanie zakupu';es_ES = 'Inversión de la compra';es_CO = 'Inversión de la compra';tr = 'Satın almanın geri dönmesi';it = 'Inversione di acquisto';de = 'Kaufstornierung'", MainLanguageCode));
	Query.SetParameter("IncomeReflection",								NStr("en = 'Revenue'; ru = 'Выручка от продажи';pl = 'Przychód';es_ES = 'Ingreso';es_CO = 'Ingreso';tr = 'Gelir';it = 'Ricavo';de = 'Erlös'", MainLanguageCode));
	Query.SetParameter("DeferredIncomeReflection",						NStr("en = 'Deferred revenue'; ru = 'Отложенная выручка';pl = 'Odroczony przychód';es_ES = 'Ingresos aplazados';es_CO = 'Ingresos aplazados';tr = 'Ertelenmiş ciro';it = 'Ricavi differiti';de = 'Umsatzabgrenzungsposten'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency",							StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("VAT",											NStr("en = 'VAT'; ru = 'НДС';pl = 'Kwota VAT';es_ES = 'IVA';es_CO = 'IVA';tr = 'KDV';it = 'IVA';de = 'USt.'", MainLanguageCode));
	Query.SetParameter("ContentVATRevenue",								NStr("en = 'Deduction of VAT charged on advance payment'; ru = 'Удержание НДС с аванса';pl = 'Odliczenie podatku VAT naliczonego z góry';es_ES = 'Deducción del IVA cobrado del pago anticipado';es_CO = 'Deducción del IVA cobrado del pago anticipado';tr = 'Avans ödemenin KDV kesintisi';it = 'Deduzione IVA caricata sul pagamento anticipato';de = 'Abzug der USt. auf Vorauszahlung belastet'", MainLanguageCode));
	Query.SetParameter("SalesTaxAccrued",								NStr("en = 'Sales tax accrued'; ru = 'Начисленный налог с продаж';pl = 'Naliczony podatek od sprzedaży';es_ES = 'Impuesto sobre ventas devengado';es_CO = 'Impuesto sobre ventas devengado';tr = 'Tahakkuk eden satış vergisi';it = 'Imposta di vendita maturata';de = 'Angefallene Umsatzsteuer'", MainLanguageCode));
	Query.SetParameter("VATAdvancesFromCustomers",						Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATAdvancesFromCustomers"));
	Query.SetParameter("VATOutput",										Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput"));
	Query.SetParameter("Date",											StructureAdditionalProperties.ForPosting.Date);
	Query.SetParameter("Company",										StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PostVATEntriesBySourceDocuments",				StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments);
	Query.SetParameter("PostVATEntriesBySourceDocuments",				StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments);
	Query.SetParameter("Ref",											DocumentRefSalesInvoice);
	Query.SetParameter("ThirdPartyPayerLiability",						NStr("en = 'Accounts receivable recognition by a third-party payer'; ru = 'Принятие к учету дебиторской задолженности по стороннему плательщику';pl = 'Przyjęcie do ewidencji należności przez płatnika strony trzeciej';es_ES = 'Reconocimiento de cuentas por cobrar por un tercero pagador';es_CO = 'Reconocimiento de cuentas por cobrar por un tercero pagador';tr = 'Üçüncü taraf ödeyen tarafından alacak hesapların onaylanması';it = 'Riconoscimento dei crediti contabili da parte un terzo pagante';de = 'Aufnahme von Offene Posten Debitoren von Drittzahler'", MainLanguageCode));
	Query.SetParameter("AdvanceAllocation",								NStr("en = 'Amount allocation'; ru = 'Распределение суммы';pl = 'Opis transakcji';es_ES = 'Asignación del importe';es_CO = 'Asignación del importe';tr = 'Tutar paylaştırma';it = 'Allocazione importo';de = 'Verteilung'", MainLanguageCode));
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure

Procedure GenerateTableGoodsShippedNotInvoiced(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableProducts.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProducts.Period AS Period,
	|	TableProducts.GoodsIssue AS GoodsIssue,
	|	TableProducts.Company AS Company,
	|	TableProducts.PresentationCurrency AS PresentationCurrency,
	|	TableProducts.Counterparty AS Counterparty,
	|	TableProducts.Contract AS Contract,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.Ownership AS Ownership,
	|	TableProducts.Order AS SalesOrder,
	|	SUM(TableProducts.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventoryOwnership AS TableProducts
	|WHERE
	|	TableProducts.GoodsIssue <> VALUE(Document.GoodsIssue.EmptyRef)
	|	AND TableProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND NOT TableProducts.ZeroInvoice
	|
	|GROUP BY
	|	TableProducts.Period,
	|	TableProducts.Company,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.Counterparty,
	|	TableProducts.Contract,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.Ownership,
	|	TableProducts.Order,
	|	TableProducts.GoodsIssue";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsShippedNotInvoiced", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableGoodsInvoicedNotShipped(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableProducts.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProducts.Period AS Period,
	|	TableProducts.Document AS SalesInvoice,
	|	TableProducts.Company AS Company,
	|	TableProducts.PresentationCurrency AS PresentationCurrency,
	|	TableProducts.Counterparty AS Counterparty,
	|	TableProducts.Contract AS Contract,
	|	TableProducts.Order AS SalesOrder,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.VATRate AS VATRate,
	|	TableProducts.DepartmentSales AS Department,
	|	TableProducts.Responsible AS Responsible,
	|	SUM(TableProducts.Quantity) AS Quantity,
	|	SUM(TableProducts.Amount - TableProducts.VATAmount) AS Amount,
	|	SUM(TableProducts.VATAmount) AS VATAmount,
	|	SUM(TableProducts.AmountDocCur - TableProducts.VATAmountDocCur) AS AmountCur,
	|	SUM(TableProducts.VATAmountDocCur) AS VATAmountCur
	|FROM
	|	TemporaryTableInventoryOwnership AS TableProducts
	|WHERE
	|	TableProducts.AdvanceInvoicing
	|	AND TableProducts.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|	AND TableProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND NOT TableProducts.ZeroInvoice
	|
	|GROUP BY
	|	TableProducts.Company,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.Counterparty,
	|	TableProducts.Contract,
	|	TableProducts.Period,
	|	TableProducts.Document,
	|	TableProducts.Order,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.VATRate,
	|	TableProducts.DepartmentSales,
	|	TableProducts.Responsible";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsInvoicedNotShipped", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Amount AS Amount
	|INTO TemporaryTableInventoryRecordsNotGrouped
	|FROM
	|	&TableInventory AS TableInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableInventoryRecordsNotGrouped.LineNumber AS LineNumber,
	|	TemporaryTableInventoryRecordsNotGrouped.Products AS Products,
	|	TemporaryTableInventoryRecordsNotGrouped.Characteristic AS Characteristic,
	|	TemporaryTableInventoryRecordsNotGrouped.Batch AS Batch,
	|	TemporaryTableInventoryRecordsNotGrouped.Amount AS Amount
	|INTO TemporaryTableInventoryRecords
	|FROM
	|	TemporaryTableInventoryRecordsNotGrouped AS TemporaryTableInventoryRecordsNotGrouped
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Field,
	|	VALUE(Enum.EntryTypes.AccountsReceivableRevenue) AS EntryType,
	|	TemporaryTableInventoryOwnership.LineNumber AS LineNumber,
	|	TemporaryTableInventoryOwnership.Period AS Period,
	|	TemporaryTableInventoryOwnership.Company AS Company,
	|	TemporaryTableInventoryOwnership.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableInventoryOwnership.CompanyVATNumber AS VATID,
	|	TemporaryTableInventoryOwnership.VATTaxation AS TaxCategory,
	|	TemporaryTableInventoryOwnership.VATRate AS TaxRate,
	|	TemporaryTableInventoryOwnership.RevenueItem AS IncomeAndExpenseItem,
	|	UNDEFINED AS Department,
	|	TemporaryTableInventoryOwnership.Products AS Product,
	|	UNDEFINED AS Variant,
	|	UNDEFINED AS Batch,
	|	UNDEFINED AS Warehouse,
	|	UNDEFINED AS Ownership,
	|	"""" AS Project,
	|	TemporaryTableInventoryOwnership.Order AS Order,
	|	TemporaryTableInventoryOwnership.Counterparty AS Counterparty,
	|	TemporaryTableInventoryOwnership.Contract AS Contract,
	|	SalesInvoiceHeader.SettlementsCurrency AS SettlementCurrency,
	|	UNDEFINED AS AdvanceDocument,
	|	TemporaryTableInventoryOwnership.Quantity AS Quantity,
	|	TemporaryTableInventoryOwnership.Amount - TemporaryTableInventoryOwnership.VATAmount AS Amount,
	|	TemporaryTableInventoryOwnership.AmountCur - TemporaryTableInventoryOwnership.VATAmountCur AS SettlementsAmount,
	|	TemporaryTableInventoryOwnership.VATAmount AS Tax,
	|	TemporaryTableInventoryOwnership.VATAmountCur AS SettlementsTax,
	|	SalesInvoiceHeader.BasisDocument.Date AS SourceDocumentDate,
	|	SalesInvoiceHeader.DeliveryStartDate AS DeliveryPeriodStart,
	|	SalesInvoiceHeader.DeliveryEndDate AS DeliveryPeriodEnd,
	|	SalesInvoiceHeader.Ref AS Recorder,
	|	UNDEFINED AS SalesTax,
	|	UNDEFINED AS TaxAgency
	|FROM
	|	TemporaryTableInventoryOwnership AS TemporaryTableInventoryOwnership
	|		INNER JOIN SalesInvoiceHeader AS SalesInvoiceHeader
	|		ON TemporaryTableInventoryOwnership.Document = SalesInvoiceHeader.Ref
	|WHERE
	|	(NOT SalesInvoiceHeader.AdvanceInvoicing
	|			OR TemporaryTableInventoryOwnership.ProductsType <> VALUE(Enum.ProductsTypes.InventoryItem))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	VALUE(Enum.EntryTypes.AccountsReceivableUnearnedRevenue),
	|	TemporaryTableInventoryOwnership.LineNumber,
	|	TemporaryTableInventoryOwnership.Period,
	|	TemporaryTableInventoryOwnership.Company,
	|	TemporaryTableInventoryOwnership.PresentationCurrency,
	|	TemporaryTableInventoryOwnership.CompanyVATNumber,
	|	TemporaryTableInventoryOwnership.VATTaxation,
	|	TemporaryTableInventoryOwnership.VATRate,
	|	TemporaryTableInventoryOwnership.RevenueItem,
	|	UNDEFINED,
	|	TemporaryTableInventoryOwnership.Products,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TemporaryTableInventoryOwnership.Order,
	|	TemporaryTableInventoryOwnership.Counterparty,
	|	TemporaryTableInventoryOwnership.Contract,
	|	SalesInvoiceHeader.SettlementsCurrency,
	|	UNDEFINED,
	|	TemporaryTableInventoryOwnership.Quantity,
	|	TemporaryTableInventoryOwnership.Amount - TemporaryTableInventoryOwnership.VATAmount,
	|	TemporaryTableInventoryOwnership.AmountCur - TemporaryTableInventoryOwnership.VATAmountCur,
	|	TemporaryTableInventoryOwnership.VATAmount,
	|	TemporaryTableInventoryOwnership.VATAmountCur,
	|	SalesInvoiceHeader.BasisDocument.Date,
	|	SalesInvoiceHeader.DeliveryStartDate,
	|	SalesInvoiceHeader.DeliveryEndDate,
	|	SalesInvoiceHeader.Ref,
	|	UNDEFINED,
	|	UNDEFINED
	|FROM
	|	TemporaryTableInventoryOwnership AS TemporaryTableInventoryOwnership
	|		INNER JOIN SalesInvoiceHeader AS SalesInvoiceHeader
	|		ON TemporaryTableInventoryOwnership.Document = SalesInvoiceHeader.Ref
	|WHERE
	|	SalesInvoiceHeader.AdvanceInvoicing
	|	AND TemporaryTableInventoryOwnership.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND TemporaryTableInventoryOwnership.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	VALUE(Enum.EntryTypes.AdvancesFromCustomerAccountsReceivable),
	|	TemporaryTablePrepayment.LineNumber,
	|	TemporaryTablePrepayment.Period,
	|	TemporaryTablePrepayment.Company,
	|	TemporaryTablePrepayment.PresentationCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TemporaryTablePrepayment.Order,
	|	TemporaryTablePrepayment.Counterparty,
	|	TemporaryTablePrepayment.Contract,
	|	SalesInvoiceHeader.SettlementsCurrency,
	|	UNDEFINED,
	|	TemporaryTablePrepayment.Document,
	|	TemporaryTablePrepayment.Amount,
	|	TemporaryTablePrepayment.AmountCur,
	|	UNDEFINED,
	|	UNDEFINED,
	|	SalesInvoiceHeader.BasisDocument.Date,
	|	SalesInvoiceHeader.DeliveryStartDate,
	|	SalesInvoiceHeader.DeliveryEndDate,
	|	SalesInvoiceHeader.Ref,
	|	UNDEFINED,
	|	UNDEFINED
	|FROM
	|	TemporaryTablePrepayment AS TemporaryTablePrepayment
	|		INNER JOIN SalesInvoiceHeader AS SalesInvoiceHeader
	|		ON TemporaryTablePrepayment.DocumentWhere = SalesInvoiceHeader.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	VALUE(Enum.EntryTypes.SettlementsWithCustomerForeignExchangeGain),
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable.LineNumber,
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable.Date,
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable.Company,
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable.PresentationCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	&DefaultEXIncome,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	SalesInvoiceHeader.Order,
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable.Counterparty,
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable.Contract,
	|	SalesInvoiceHeader.SettlementsCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	SalesInvoiceHeader.BasisDocument.Date,
	|	SalesInvoiceHeader.DeliveryStartDate,
	|	SalesInvoiceHeader.DeliveryEndDate,
	|	SalesInvoiceHeader.Ref,
	|	UNDEFINED,
	|	UNDEFINED
	|FROM
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable AS TemporaryTableExchangeRateDifferencesAccountsReceivable
	|		INNER JOIN SalesInvoiceHeader AS SalesInvoiceHeader
	|			INNER JOIN Constant.ForeignExchangeAccounting AS ForeignExchangeAccounting
	|			ON (ForeignExchangeAccounting.Value = TRUE)
	|			INNER JOIN Constant.ForeignCurrencyRevaluationPeriodicity AS ForeignCurrencyRevaluationPeriodicity
	|			ON (ForeignCurrencyRevaluationPeriodicity.Value = VALUE(Enum.ForeignCurrencyRevaluationPeriodicity.DuringOpertionExecution))
	|		ON TemporaryTableExchangeRateDifferencesAccountsReceivable.Document = SalesInvoiceHeader.Ref
	|WHERE
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences > 0
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	VALUE(Enum.EntryTypes.ForeignExchangeLossSettlementsWithCustomer),
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable.LineNumber,
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable.Date,
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable.Company,
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable.PresentationCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	&DefaultEXExpense,
	|	SalesInvoiceHeader.Department,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	SalesInvoiceHeader.Order,
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable.Counterparty,
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable.Contract,
	|	SalesInvoiceHeader.SettlementsCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	-TemporaryTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	SalesInvoiceHeader.BasisDocument.Date,
	|	SalesInvoiceHeader.DeliveryStartDate,
	|	SalesInvoiceHeader.DeliveryEndDate,
	|	SalesInvoiceHeader.Ref,
	|	UNDEFINED,
	|	UNDEFINED
	|FROM
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable AS TemporaryTableExchangeRateDifferencesAccountsReceivable
	|		INNER JOIN SalesInvoiceHeader AS SalesInvoiceHeader
	|			INNER JOIN Constant.ForeignExchangeAccounting AS ForeignExchangeAccounting
	|			ON (ForeignExchangeAccounting.Value = TRUE)
	|			INNER JOIN Constant.ForeignCurrencyRevaluationPeriodicity AS ForeignCurrencyRevaluationPeriodicity
	|			ON (ForeignCurrencyRevaluationPeriodicity.Value = VALUE(Enum.ForeignCurrencyRevaluationPeriodicity.DuringOpertionExecution))
	|		ON TemporaryTableExchangeRateDifferencesAccountsReceivable.Document = SalesInvoiceHeader.Ref
	|WHERE
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences < 0
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	VALUE(Enum.EntryTypes.VATOutputVATFromAdvancesReceived),
	|	UNDEFINED,
	|	TemporaryTablePrepaymentVAT.Period,
	|	TemporaryTablePrepaymentVAT.Company,
	|	TemporaryTablePrepaymentVAT.PresentationCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	SalesInvoiceHeader.Order,
	|	SalesInvoiceHeader.Counterparty,
	|	SalesInvoiceHeader.Contract,
	|	SalesInvoiceHeader.SettlementsCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TemporaryTablePrepaymentVAT.VATAmount,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	SalesInvoiceHeader.BasisDocument.Date,
	|	UNDEFINED,
	|	UNDEFINED,
	|	SalesInvoiceHeader.Ref,
	|	UNDEFINED,
	|	UNDEFINED
	|FROM
	|	TemporaryTablePrepaymentVAT AS TemporaryTablePrepaymentVAT
	|		INNER JOIN SalesInvoiceHeader AS SalesInvoiceHeader
	|		ON TemporaryTablePrepaymentVAT.Ref = SalesInvoiceHeader.Ref
	|WHERE
	|	SalesInvoiceHeader.RegisteredForVAT
	|	AND SalesInvoiceHeader.PostVATEntriesBySourceDocuments
	|
	|UNION ALL
	|
	|SELECT
	|	7,
	|	VALUE(Enum.EntryTypes.ThirdPartyPayerAccountsReceivable),
	|	TemporaryTableInventoryOwnership.LineNumber,
	|	TemporaryTableInventoryOwnership.Period,
	|	TemporaryTableInventoryOwnership.Company,
	|	TemporaryTableInventoryOwnership.PresentationCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TemporaryTableInventoryOwnership.Order,
	|	TemporaryTableInventoryOwnership.Counterparty,
	|	TemporaryTableInventoryOwnership.Contract,
	|	SalesInvoiceHeader.SettlementsCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TemporaryTableInventoryOwnership.Amount - TemporaryTableInventoryOwnership.VATAmount,
	|	TemporaryTableInventoryOwnership.AmountCur + TemporaryTableInventoryOwnership.SalesTaxAmountCur,
	|	UNDEFINED,
	|	UNDEFINED,
	|	SalesInvoiceHeader.BasisDocument.Date,
	|	SalesInvoiceHeader.DeliveryStartDate,
	|	SalesInvoiceHeader.DeliveryEndDate,
	|	SalesInvoiceHeader.Ref,
	|	UNDEFINED,
	|	UNDEFINED
	|FROM
	|	TemporaryTableInventoryOwnership AS TemporaryTableInventoryOwnership
	|		INNER JOIN SalesInvoiceHeader AS SalesInvoiceHeader
	|		ON TemporaryTableInventoryOwnership.Document = SalesInvoiceHeader.Ref
	|WHERE
	|	SalesInvoiceHeader.ThirdPartyPayment
	|
	|UNION ALL
	|
	|SELECT
	|	8,
	|	VALUE(Enum.EntryTypes.AccountsReceivableAdvancesFromCustomer),
	|	UNDEFINED,
	|	TemporaryTableAmountAllocation.Period,
	|	TemporaryTableAmountAllocation.Company,
	|	TemporaryTableAmountAllocation.PresentationCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TemporaryTableAmountAllocation.Order,
	|	TemporaryTableAmountAllocation.Counterparty,
	|	TemporaryTableAmountAllocation.Contract,
	|	SalesInvoiceHeader.SettlementsCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TemporaryTableAmountAllocation.Amount,
	|	TemporaryTableAmountAllocation.Amount,
	|	UNDEFINED,
	|	UNDEFINED,
	|	SalesInvoiceHeader.BasisDocument.Date,
	|	SalesInvoiceHeader.DeliveryStartDate,
	|	SalesInvoiceHeader.DeliveryEndDate,
	|	SalesInvoiceHeader.Ref,
	|	UNDEFINED,
	|	UNDEFINED
	|FROM
	|	TemporaryTableAmountAllocation AS TemporaryTableAmountAllocation
	|		INNER JOIN SalesInvoiceHeader AS SalesInvoiceHeader
	|		ON TemporaryTableAmountAllocation.Ref = SalesInvoiceHeader.Ref
	|WHERE
	|	SalesInvoiceHeader.OperationKind = VALUE(Enum.OperationTypesSalesInvoice.ClosingInvoice)
	|	AND TemporaryTableAmountAllocation.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	9,
	|	VALUE(Enum.EntryTypes.AccountsReceivableAccountsReceivableOffset),
	|	UNDEFINED,
	|	TemporaryTableAmountAllocation.Period,
	|	TemporaryTableAmountAllocation.Company,
	|	TemporaryTableAmountAllocation.PresentationCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TemporaryTableAmountAllocation.Order,
	|	TemporaryTableAmountAllocation.Counterparty,
	|	TemporaryTableAmountAllocation.Contract,
	|	SalesInvoiceHeader.SettlementsCurrency,
	|	TemporaryTableAmountAllocation.Document,
	|	UNDEFINED,
	|	TemporaryTableAmountAllocation.Amount,
	|	TemporaryTableAmountAllocation.Amount,
	|	UNDEFINED,
	|	UNDEFINED,
	|	SalesInvoiceHeader.BasisDocument.Date,
	|	SalesInvoiceHeader.DeliveryStartDate,
	|	SalesInvoiceHeader.DeliveryEndDate,
	|	SalesInvoiceHeader.Ref,
	|	UNDEFINED,
	|	UNDEFINED
	|FROM
	|	TemporaryTableAmountAllocation AS TemporaryTableAmountAllocation
	|		INNER JOIN SalesInvoiceHeader AS SalesInvoiceHeader
	|		ON TemporaryTableAmountAllocation.Ref = SalesInvoiceHeader.Ref
	|WHERE
	|	SalesInvoiceHeader.OperationKind = VALUE(Enum.OperationTypesSalesInvoice.ClosingInvoice)
	|	AND NOT TemporaryTableAmountAllocation.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	10,
	|	VALUE(Enum.EntryTypes.COGSInventory),
	|	TemporaryTableInventoryOwnership.LineNumber,
	|	TemporaryTableInventoryOwnership.Period,
	|	TemporaryTableInventoryOwnership.Company,
	|	TemporaryTableInventoryOwnership.PresentationCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TemporaryTableInventoryOwnership.COGSItem,
	|	UNDEFINED,
	|	TemporaryTableInventoryOwnership.Products,
	|	TemporaryTableInventoryOwnership.Characteristic,
	|	TemporaryTableInventoryOwnership.Batch,
	|	TemporaryTableInventoryOwnership.StructuralUnit,
	|	TemporaryTableInventoryOwnership.Ownership,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TemporaryTableInventoryOwnership.Quantity,
	|	TemporaryTableInventoryRecords.Amount,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	SalesInvoiceHeader.BasisDocument.Date,
	|	SalesInvoiceHeader.DeliveryStartDate,
	|	SalesInvoiceHeader.DeliveryEndDate,
	|	SalesInvoiceHeader.Ref,
	|	UNDEFINED,
	|	UNDEFINED
	|FROM
	|	TemporaryTableInventoryOwnership AS TemporaryTableInventoryOwnership
	|		INNER JOIN SalesInvoiceHeader AS SalesInvoiceHeader
	|		ON TemporaryTableInventoryOwnership.Document = SalesInvoiceHeader.Ref
	|		LEFT JOIN TemporaryTableInventoryRecords AS TemporaryTableInventoryRecords
	|		ON TemporaryTableInventoryOwnership.LineNumber = TemporaryTableInventoryRecords.LineNumber
	|			AND TemporaryTableInventoryOwnership.Products = TemporaryTableInventoryRecords.Products
	|			AND TemporaryTableInventoryOwnership.Characteristic = TemporaryTableInventoryRecords.Characteristic
	|			AND TemporaryTableInventoryOwnership.Batch = TemporaryTableInventoryRecords.Batch
	|WHERE
	|	SalesInvoiceHeader.OperationKind = VALUE(Enum.OperationTypesSalesInvoice.Invoice)
	|	AND TemporaryTableInventoryOwnership.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND TemporaryTableInventoryOwnership.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|	AND SalesInvoiceHeader.InventoryValuationMethod = VALUE(Enum.InventoryValuationMethods.WeightedAverage)
	|
	|UNION ALL
	|
	|SELECT
	|	11,
	|	VALUE(Enum.EntryTypes.COGSGoodsShippedNotInvoiced),
	|	TemporaryTableInventoryOwnership.LineNumber,
	|	TemporaryTableInventoryOwnership.Period,
	|	TemporaryTableInventoryOwnership.Company,
	|	TemporaryTableInventoryOwnership.PresentationCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TemporaryTableInventoryOwnership.COGSItem,
	|	UNDEFINED,
	|	TemporaryTableInventoryOwnership.Products,
	|	TemporaryTableInventoryOwnership.Characteristic,
	|	TemporaryTableInventoryOwnership.Batch,
	|	TemporaryTableInventoryOwnership.StructuralUnit,
	|	TemporaryTableInventoryOwnership.Ownership,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TemporaryTableInventoryOwnership.Quantity,
	|	TemporaryTableInventoryRecords.Amount,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	SalesInvoiceHeader.BasisDocument.Date,
	|	SalesInvoiceHeader.DeliveryStartDate,
	|	SalesInvoiceHeader.DeliveryEndDate,
	|	SalesInvoiceHeader.Ref,
	|	UNDEFINED,
	|	UNDEFINED
	|FROM
	|	TemporaryTableInventoryOwnership AS TemporaryTableInventoryOwnership
	|		INNER JOIN SalesInvoiceHeader AS SalesInvoiceHeader
	|		ON TemporaryTableInventoryOwnership.Document = SalesInvoiceHeader.Ref
	|		LEFT JOIN TemporaryTableInventoryRecords AS TemporaryTableInventoryRecords
	|		ON TemporaryTableInventoryOwnership.LineNumber = TemporaryTableInventoryRecords.LineNumber
	|			AND TemporaryTableInventoryOwnership.Products = TemporaryTableInventoryRecords.Products
	|			AND TemporaryTableInventoryOwnership.Characteristic = TemporaryTableInventoryRecords.Characteristic
	|			AND TemporaryTableInventoryOwnership.Batch = TemporaryTableInventoryRecords.Batch
	|WHERE
	|	SalesInvoiceHeader.OperationKind = VALUE(Enum.OperationTypesSalesInvoice.Invoice)
	|	AND TemporaryTableInventoryOwnership.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND TemporaryTableInventoryOwnership.GoodsIssue <> VALUE(Document.GoodsIssue.EmptyRef)
	|	AND SalesInvoiceHeader.InventoryValuationMethod = VALUE(Enum.InventoryValuationMethods.WeightedAverage)
	|	AND SalesInvoiceHeader.StockTransactionsMethodology = VALUE(Enum.StockTransactionsMethodology.AngloSaxon)
	|
	|UNION ALL
	|
	|SELECT
	|	12,
	|	VALUE(Enum.EntryTypes.AccountsReceivableSalesTax),
	|	TemporaryTableInventoryOwnership.LineNumber,
	|	TemporaryTableInventoryOwnership.Period,
	|	TemporaryTableInventoryOwnership.Company,
	|	TemporaryTableInventoryOwnership.PresentationCurrency,
	|	TemporaryTableInventoryOwnership.CompanyVATNumber,
	|	TemporaryTableInventoryOwnership.VATTaxation,
	|	TemporaryTableInventoryOwnership.VATRate,
	|	"""",
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	"""",
	|	TemporaryTableInventoryOwnership.Order,
	|	TemporaryTableInventoryOwnership.Counterparty,
	|	TemporaryTableInventoryOwnership.Contract,
	|	SalesInvoiceHeader.SettlementsCurrency,
	|	UNDEFINED,
	|	0,
	|	SalesTaxInvoiceTable.Amount,
	|	SalesTaxInvoiceTable.AmountCur,
	|	0,
	|	0,
	|	SalesInvoiceHeader.BasisDocument.Date,
	|	SalesInvoiceHeader.DeliveryStartDate,
	|	SalesInvoiceHeader.DeliveryEndDate,
	|	SalesInvoiceHeader.Ref,
	|	SalesTaxInvoiceTable.SalesTaxRate,
	|	SalesTaxInvoiceTable.TaxKind
	|FROM
	|	TemporaryTableInventoryOwnership AS TemporaryTableInventoryOwnership
	|		INNER JOIN SalesInvoiceHeader AS SalesInvoiceHeader
	|		ON TemporaryTableInventoryOwnership.Document = SalesInvoiceHeader.Ref
	|		INNER JOIN SalesTaxInvoiceTable AS SalesTaxInvoiceTable
	|		ON TemporaryTableInventoryOwnership.Document = SalesTaxInvoiceTable.Ref
	|WHERE
	|	(NOT SalesInvoiceHeader.AdvanceInvoicing
	|			OR TemporaryTableInventoryOwnership.ProductsType <> VALUE(Enum.ProductsTypes.InventoryItem))";
	
	Query.SetParameter("TableInventory"	 , StructureAdditionalProperties.TableForRegisterRecords.TableInventory);
	Query.SetParameter("DefaultEXIncome" , Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("DefaultEXExpense", Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	
	QueryResult = Query.Execute();
	
	TableResult = QueryResult.Unload();
	
	TypedTableResult = New ValueTable;
	DriveServer.ValueTableCreateTypedColumnsByRegister(TypedTableResult, "AccountingEntriesData");
	
	For Each Row In TableResult Do
		NewRow = TypedTableResult.Add();
		FillPropertyValues(NewRow, Row);
	EndDo;
	
	TypedTableResult.FillValues(True, "Active");
	DriveServer.ValueTableEnumerateRows(TypedTableResult, "RowNumber", 1);
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", TypedTableResult);
	
EndProcedure

#Region DiscountCards

// Generates values table creating data for posting by the SalesWithCardBasedDiscounts register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesByDiscountCard(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	If DocumentRefSalesInvoice.DiscountCard.IsEmpty() Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSalesWithCardBasedDiscounts", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Period AS Period,
	|	TableSales.Document.DiscountCard AS DiscountCard,
	|	TableSales.Document.DiscountCard.CardOwner AS CardOwner,
	|	TableSales.PresentationCurrency AS PresentationCurrency,
	|	SUM(TableSales.Amount) AS Amount
	|FROM
	|	TemporaryTableInventoryOwnership AS TableSales
	|WHERE
	|	NOT TableSales.ZeroInvoice
	|
	|GROUP BY
	|	TableSales.Period,
	|	TableSales.Document.DiscountCard,
	|	TableSales.Document.DiscountCard.CardOwner,
	|	TableSales.PresentationCurrency";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSalesWithCardBasedDiscounts", QueryResult.Unload());
	
EndProcedure

#EndRegion

Procedure GenerateTableVATOutput(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	If WorkWithVAT.GetUseTaxInvoiceForPostingVAT(DocumentRefSalesInvoice.Date, DocumentRefSalesInvoice.Company) Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", New ValueTable);
		Return;
		
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	TableVATOutput.Document AS ShipmentDocument,
	|	TableVATOutput.Period AS Period,
	|	TableVATOutput.Company AS Company,
	|	TableVATOutput.CompanyVATNumber AS CompanyVATNumber,
	|	TableVATOutput.PresentationCurrency AS PresentationCurrency,
	|	TableVATOutput.Counterparty AS Customer,
	|	TableVATOutput.VATRate AS VATRate,
	|	TableVATOutput.VATOutputGLAccount AS GLAccount,
	|	CASE
	|		WHEN TableVATOutput.VATTaxation = VALUE(Enum.VATTaxationTypes.ForExport)
	|				OR TableVATOutput.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN VALUE(Enum.VATOperationTypes.Export)
	|		ELSE VALUE(Enum.VATOperationTypes.Sales)
	|	END AS OperationType,
	|	TableVATOutput.ProductsType AS ProductType,
	|	SUM(TableVATOutput.VATAmount) AS VATAmount,
	|	SUM(TableVATOutput.Amount - TableVATOutput.VATAmount) AS AmountExcludesVAT
	|FROM
	|	TemporaryTableInventoryOwnership AS TableVATOutput
	|WHERE
	|	NOT TableVATOutput.ZeroInvoice
	|
	|GROUP BY
	|	TableVATOutput.VATRate,
	|	TableVATOutput.VATOutputGLAccount,
	|	TableVATOutput.VATTaxation,
	|	TableVATOutput.ProductsType,
	|	TableVATOutput.Document,
	|	TableVATOutput.Period,
	|	TableVATOutput.Company,
	|	TableVATOutput.CompanyVATNumber,
	|	TableVATOutput.PresentationCurrency,
	|	TableVATOutput.Counterparty,
	|	TableVATOutput.DocumentCurrency,
	|	TableVATOutput.Multiplicity,
	|	TableVATOutput.ExchangeRate
	|
	|UNION ALL
	|
	|SELECT
	|	Prepayment.ShipmentDocument,
	|	Prepayment.Period,
	|	Prepayment.Company,
	|	Prepayment.CompanyVATNumber,
	|	Prepayment.PresentationCurrency,
	|	Prepayment.Customer,
	|	Prepayment.VATRate,
	|	&VATOutput,
	|	VALUE(Enum.VATOperationTypes.AdvanceCleared),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	-Prepayment.VATAmount,
	|	-Prepayment.AmountExcludesVAT
	|FROM
	|	TemporaryTablePrepaymentVAT AS Prepayment";
	
	Query.SetParameter("VATOutput", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput"));
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", Query.Execute().Unload());
	
EndProcedure

Procedure GenerateTableTaxPayable(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	UseSalesTax = SalesTaxServer.GetUseSalesTax(StructureAdditionalProperties.ForPosting.Date,
		StructureAdditionalProperties.ForPosting.Company);
	
	If Not UseSalesTax Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxPayable", New ValueTable);
		Return;
		
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("SalesTaxAccrued", NStr("en = 'Sales tax accrued'; ru = 'Начисленный налог с продаж';pl = 'Naliczony podatek od sprzedaży';es_ES = 'Impuesto sobre ventas devengado';es_CO = 'Impuesto sobre ventas devengado';tr = 'Tahakkuk eden satış vergisi';it = 'Imposta di vendita maturata';de = 'Angefallene Umsatzsteuer'", CommonClientServer.DefaultLanguageCode()));
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TemporarySalesTax.Period AS Period,
	|	TemporarySalesTax.Company AS Company,
	|	TemporarySalesTax.PresentationCurrency AS PresentationCurrency,
	|	TemporarySalesTax.TaxKind AS TaxKind,
	|	TemporarySalesTax.CompanyVATNumber AS CompanyVATNumber,
	|	TemporarySalesTax.Amount AS Amount,
	|	&SalesTaxAccrued AS ContentOfAccountingRecord
	|FROM
	|	TemporarySalesTax AS TemporarySalesTax";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxPayable", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefSalesInvoice, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	Header.Ref AS Ref,
	|	Header.Date AS Date,
	|	&Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	Header.Counterparty AS Counterparty,
	|	Header.Contract AS Contract,
	|	Header.Order AS Order,
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.ExchangeRate AS ExchangeRate,
	|	Header.Multiplicity AS Multiplicity,
	|	Header.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	Header.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Header.AccountsReceivableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountsReceivableGLAccount,
	|	Header.ThirdPartyPayment AS ThirdPartyPayment,
	|	Header.Payer AS Payer,
	|	Header.PayerContract AS PayerContract,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Header.ThirdPartyPayerGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ThirdPartyPayerGLAccount,
	|	Header.Cell AS Cell,
	|	Header.BasisDocument AS BasisDocument,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.VATTaxation AS VATTaxation,
	|	Header.StructuralUnit AS StructuralUnit,
	|	Header.SetPaymentTerms AS SetPaymentTerms,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Header.AdvancesReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AdvancesReceivedGLAccount,
	|	CASE
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesSalesInvoice.AdvanceInvoice)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AdvanceInvoicing,
	|	Header.Responsible AS Responsible,
	|	Header.Department AS Department,
	|	Header.IncludeVATInPrice AS IncludeVATInPrice,
	|	CASE
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesSalesInvoice.ZeroInvoice)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ZeroInvoice,
	|	Header.DocumentAmount AS DocumentAmount,
	|	Header.OperationKind = VALUE(Enum.OperationTypesSalesInvoice.ClosingInvoice) AS ClosingInvoice,
	|	Header.DeliveryStartDate AS DeliveryStartDate,
	|	Header.DeliveryEndDate AS DeliveryEndDate,
	|	Header.OperationKind AS OperationKind,
	|	AccountingPolicySliceLast.RegisteredForVAT AS RegisteredForVAT,
	|	AccountingPolicySliceLast.PostVATEntriesBySourceDocuments AS PostVATEntriesBySourceDocuments,
	|	AccountingPolicySliceLast.InventoryValuationMethod AS InventoryValuationMethod,
	|	AccountingPolicySliceLast.StockTransactionsMethodology AS StockTransactionsMethodology,
	|	Header.Contract.SettlementsCurrency AS SettlementsCurrency
	|INTO SalesInvoiceHeader
	|FROM
	|	Document.SalesInvoice AS Header
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&PointInTime, Company = &Company) AS AccountingPolicySliceLast
	|		ON Header.Company = AccountingPolicySliceLast.Company
	|WHERE
	|	Header.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoiceHeader.Ref AS Ref,
	|	SalesInvoiceHeader.Date AS Date,
	|	SalesInvoiceHeader.Company AS Company,
	|	SalesInvoiceHeader.CompanyVATNumber AS CompanyVATNumber,
	|	SalesInvoiceHeader.PresentationCurrency AS PresentationCurrency,
	|	SalesInvoiceHeader.Counterparty AS Counterparty,
	|	SalesInvoiceHeader.Contract AS Contract,
	|	SalesInvoiceHeader.Order AS Order,
	|	SalesInvoiceHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesInvoiceHeader.ExchangeRate AS ExchangeRate,
	|	SalesInvoiceHeader.Multiplicity AS Multiplicity,
	|	SalesInvoiceHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	SalesInvoiceHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	SalesInvoiceHeader.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
	|	SalesInvoiceHeader.ThirdPartyPayment AS ThirdPartyPayment,
	|	SalesInvoiceHeader.Payer AS Payer,
	|	SalesInvoiceHeader.PayerContract AS PayerContract,
	|	SalesInvoiceHeader.ThirdPartyPayerGLAccount AS ThirdPartyPayerGLAccount,
	|	SalesInvoiceHeader.Cell AS Cell,
	|	SalesInvoiceHeader.BasisDocument AS BasisDocument,
	|	SalesInvoiceHeader.DocumentCurrency AS DocumentCurrency,
	|	SalesInvoiceHeader.VATTaxation AS VATTaxation,
	|	SalesInvoiceHeader.StructuralUnit AS StructuralUnit,
	|	SalesInvoiceHeader.SetPaymentTerms AS SetPaymentTerms,
	|	SalesInvoiceHeader.AdvancesReceivedGLAccount AS AdvancesReceivedGLAccount,
	|	SalesInvoiceHeader.AdvanceInvoicing AS AdvanceInvoicing,
	|	SalesInvoiceHeader.Responsible AS Responsible,
	|	SalesInvoiceHeader.Department AS Department,
	|	SalesInvoiceHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	ISNULL(Payers.DoOperationsByContracts, FALSE) AS PayerDoOperationsByContracts,
	|	ISNULL(PayerContracts.SettlementsCurrency, VALUE(Catalog.CounterpartyContracts.EmptyRef)) AS PayerSettlementsCurrency,
	|	ISNULL(CounterpartyContracts.SettlementsCurrency, VALUE(Catalog.CounterpartyContracts.EmptyRef)) AS SettlementsCurrency,
	|	ISNULL(Counterparties.DoOperationsByContracts, FALSE) AS DoOperationsByContracts,
	|	ISNULL(Counterparties.DoOperationsByOrders, FALSE) AS DoOperationsByOrders,
	|	SalesInvoiceHeader.ZeroInvoice AS ZeroInvoice,
	|	SalesInvoiceHeader.DocumentAmount AS DocumentAmount,
	|	SalesInvoiceHeader.ClosingInvoice AS ClosingInvoice,
	|	SalesInvoiceHeader.DeliveryStartDate AS DeliveryStartDate,
	|	SalesInvoiceHeader.DeliveryEndDate AS DeliveryEndDate
	|INTO SalesInvoiceTable
	|FROM
	|	SalesInvoiceHeader AS SalesInvoiceHeader
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON SalesInvoiceHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.Counterparties AS Payers
	|		ON SalesInvoiceHeader.Payer = Payers.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON SalesInvoiceHeader.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS PayerContracts
	|		ON SalesInvoiceHeader.PayerContract = PayerContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	SalesInvoiceInventory.Ref AS Document,
	|	SalesInvoiceTable.Date AS Period,
	|	SalesInvoiceTable.Counterparty AS Counterparty,
	|	SalesInvoiceTable.Contract AS Contract,
	|	CASE
	|		WHEN SalesInvoiceInventory.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|				AND NOT SalesInvoiceInventory.DropShipping
	|			THEN SalesInvoiceTable.StructuralUnit
	|		WHEN SalesInvoiceInventory.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|				AND SalesInvoiceInventory.DropShipping
	|			THEN VALUE(Catalog.BusinessUnits.DropShipping)
	|		ELSE SalesInvoiceTable.Counterparty
	|	END AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN SalesInvoiceTable.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	SalesInvoiceTable.AdvanceInvoicing AS AdvanceInvoicing,
	|	SalesInvoiceInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SalesInvoiceInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN SalesInvoiceInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SalesInvoiceInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	SalesInvoiceInventory.Order AS Order,
	|	SalesInvoiceInventory.Reserve AS Reserve,
	|	SalesInvoiceInventory.GoodsIssue AS GoodsIssue,
	|	SalesInvoiceInventory.ConnectionKey AS ConnectionKey,
	|	CASE
	|		WHEN &IssueClosingInvoices
	|			THEN SalesInvoiceInventory.DeliveryStartDate
	|		ELSE DATETIME(1, 1, 1)
	|	END AS DeliveryStartDate,
	|	CASE
	|		WHEN &IssueClosingInvoices
	|			THEN SalesInvoiceInventory.DeliveryEndDate
	|		ELSE DATETIME(1, 1, 1)
	|	END AS DeliveryEndDate,
	|	SalesInvoiceTable.ZeroInvoice AS ZeroInvoice,
	|	CatalogProducts.ProductsType AS ProductsType
	|INTO TemporaryTableInventory
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		INNER JOIN SalesInvoiceTable AS SalesInvoiceTable
	|		ON SalesInvoiceInventory.Ref = SalesInvoiceTable.Ref
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON SalesInvoiceInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON (SalesInvoiceTable.StructuralUnit = BatchTrackingPolicy.StructuralUnit)
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS CorrOrganization,
	|	SalesInvoiceInventory.Ref AS Document,
	|	SalesInvoiceTable.Date AS Period,
	|	SalesInvoiceTable.CompanyVATNumber AS CompanyVATNumber,
	|	SalesInvoiceTable.VATTaxation AS VATTaxation,
	|	SalesInvoiceTable.Responsible AS Responsible,
	|	SalesInvoiceTable.BasisDocument AS BasisDocument,
	|	SalesInvoiceTable.Counterparty AS Counterparty,
	|	SalesInvoiceTable.Contract AS Contract,
	|	SalesInvoiceTable.DoOperationsByContracts AS DoOperationsByContracts,
	|	SalesInvoiceTable.DoOperationsByOrders AS DoOperationsByOrders,
	|	SalesInvoiceTable.AccountsReceivableGLAccount AS GLAccountCustomerSettlements,
	|	SalesInvoiceTable.ThirdPartyPayment AS ThirdPartyPayment,
	|	SalesInvoiceTable.Payer AS Payer,
	|	SalesInvoiceTable.PayerContract AS PayerContract,
	|	SalesInvoiceTable.ThirdPartyPayerGLAccount AS ThirdPartyPayerGLAccount,
	|	SalesInvoiceTable.PayerSettlementsCurrency AS PayerSettlementsCurrency,
	|	SalesInvoiceTable.Department AS DepartmentSales,
	|	CASE
	|		WHEN SalesInvoiceInventory.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|				AND NOT SalesInvoiceInventory.DropShipping
	|			THEN SalesInvoiceTable.StructuralUnit
	|		WHEN SalesInvoiceInventory.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|				AND SalesInvoiceInventory.DropShipping
	|			THEN VALUE(Catalog.BusinessUnits.DropShipping)
	|		ELSE SalesInvoiceTable.Counterparty
	|	END AS StructuralUnit,
	|	UNDEFINED AS StructuralUnitCorr,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN SalesInvoiceTable.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	SalesInvoiceTable.SetPaymentTerms AS SetPaymentTerms,
	|	SalesInvoiceTable.AdvanceInvoicing AS AdvanceInvoicing,
	|	SalesInvoiceTable.DocumentCurrency AS DocumentCurrency,
	|	SalesInvoiceTable.ExchangeRate AS ExchangeRate,
	|	SalesInvoiceTable.Multiplicity AS Multiplicity,
	|	SalesInvoiceTable.SettlementsCurrency AS SettlementsCurrency,
	|	SalesInvoiceInventory.LineNumber AS LineNumber,
	|	CatalogProducts.BusinessLine AS BusinessLineSales,
	|	CatalogProducts.ProductsType AS ProductsType,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SalesInvoiceInventory.RevenueGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountStatementSales,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SalesInvoiceInventory.UnearnedRevenueGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountStatementDeferredSales,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SalesInvoiceInventory.COGSGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountCost,
	|	SalesInvoiceInventory.RevenueItem AS RevenueItem,
	|	SalesInvoiceInventory.COGSItem AS COGSItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN SalesInvoiceInventory.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|							AND ISNULL(CatalogInventoryOwnership.OwnershipType, VALUE(Enum.InventoryOwnershipTypes.EmptyRef)) = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|						THEN SalesInvoiceInventory.InventoryReceivedGLAccount
	|					WHEN SalesInvoiceInventory.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|						THEN SalesInvoiceInventory.InventoryGLAccount
	|					ELSE SalesInvoiceInventory.GoodsShippedNotInvoicedGLAccount
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SalesInvoiceInventory.COGSGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	SalesInvoiceInventory.Products AS Products,
	|	UNDEFINED AS ProductsCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SalesInvoiceInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	UNDEFINED AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SalesInvoiceInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	SalesInvoiceInventory.Ownership AS Ownership,
	|	UNDEFINED AS OwnershipCorr,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	CASE
	|		WHEN SalesInvoiceInventory.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.ThirdPartyInventory)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS InventoryAccountType,
	|	CASE
	|		WHEN SalesInvoiceInventory.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.ThirdPartyInventory)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS CorrInventoryAccountType,
	|	SalesInvoiceInventory.SerialNumber AS SerialNumber,
	|	UNDEFINED AS BatchCorr,
	|	SalesInvoiceInventory.Order AS Order,
	|	SalesInvoiceInventory.GoodsIssue AS GoodsIssue,
	|	UNDEFINED AS CorrOrder,
	|	SalesInvoiceInventory.Quantity AS Quantity,
	|	CASE
	|		WHEN VALUETYPE(SalesInvoiceInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SalesInvoiceInventory.Reserve
	|		ELSE SalesInvoiceInventory.Reserve * SalesInvoiceInventory.MeasurementUnit.Factor
	|	END AS Reserve,
	|	SalesInvoiceInventory.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN SalesInvoiceTable.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN SalesInvoiceInventory.VATAmount * SalesInvoiceTable.Multiplicity / SalesInvoiceTable.ExchangeRate
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SalesInvoiceInventory.VATAmount * SalesInvoiceTable.ExchangeRate / SalesInvoiceTable.Multiplicity
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN SalesInvoiceInventory.Total * SalesInvoiceTable.Multiplicity / SalesInvoiceTable.ExchangeRate
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SalesInvoiceInventory.Total * SalesInvoiceTable.ExchangeRate / SalesInvoiceTable.Multiplicity
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN SalesInvoiceTable.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN SalesInvoiceInventory.VATAmount * SalesInvoiceTable.ContractCurrencyExchangeRate * SalesInvoiceTable.Multiplicity / (SalesInvoiceTable.ExchangeRate * SalesInvoiceTable.ContractCurrencyMultiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SalesInvoiceInventory.VATAmount * SalesInvoiceTable.ExchangeRate * SalesInvoiceTable.ContractCurrencyMultiplicity / (SalesInvoiceTable.ContractCurrencyExchangeRate * SalesInvoiceTable.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN SalesInvoiceInventory.Total * SalesInvoiceTable.ContractCurrencyExchangeRate * SalesInvoiceTable.Multiplicity / (SalesInvoiceTable.ExchangeRate * SalesInvoiceTable.ContractCurrencyMultiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SalesInvoiceInventory.Total * SalesInvoiceTable.ExchangeRate * SalesInvoiceTable.ContractCurrencyMultiplicity / (SalesInvoiceTable.ContractCurrencyExchangeRate * SalesInvoiceTable.Multiplicity)
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	CASE
	|		WHEN SalesInvoiceTable.IncludeVATInPrice
	|			THEN 0
	|		ELSE SalesInvoiceInventory.VATAmount
	|	END AS VATAmountDocCur,
	|	SalesInvoiceInventory.Total AS AmountDocCur,
	|	CAST(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN SalesInvoiceInventory.SalesTaxAmount * SalesInvoiceTable.Multiplicity / SalesInvoiceTable.ExchangeRate
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SalesInvoiceInventory.SalesTaxAmount * SalesInvoiceTable.ExchangeRate / SalesInvoiceTable.Multiplicity
	|		END AS NUMBER(15, 2)) AS SalesTaxAmount,
	|	CAST(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN SalesInvoiceInventory.SalesTaxAmount * SalesInvoiceTable.ContractCurrencyExchangeRate * SalesInvoiceTable.Multiplicity / (SalesInvoiceTable.ExchangeRate * SalesInvoiceTable.ContractCurrencyMultiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SalesInvoiceInventory.SalesTaxAmount * SalesInvoiceTable.ExchangeRate * SalesInvoiceTable.ContractCurrencyMultiplicity / (SalesInvoiceTable.ContractCurrencyExchangeRate * SalesInvoiceTable.Multiplicity)
	|		END AS NUMBER(15, 2)) AS SalesTaxAmountCur,
	|	SalesInvoiceInventory.SalesTaxAmount AS SalesTaxAmountDocCur,
	|	SalesInvoiceInventory.SalesRep AS SalesRep,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SalesInvoiceInventory.VATOutputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATOutputGLAccount,
	|	SalesInvoiceInventory.BundleProduct AS BundleProduct,
	|	SalesInvoiceInventory.BundleCharacteristic AS BundleCharacteristic,
	|	SalesInvoiceInventory.CostShare AS CostShare,
	|	&ContinentalMethod AS ContinentalMethod,
	|	CASE
	|		WHEN &IssueClosingInvoices
	|			THEN SalesInvoiceInventory.DeliveryStartDate
	|		ELSE DATETIME(1, 1, 1)
	|	END AS DeliveryStartDate,
	|	CASE
	|		WHEN &IssueClosingInvoices
	|			THEN SalesInvoiceInventory.DeliveryEndDate
	|		ELSE DATETIME(1, 1, 1)
	|	END AS DeliveryEndDate,
	|	SalesInvoiceTable.ZeroInvoice AS ZeroInvoice,
	|	SalesInvoiceInventory.DropShipping AS DropShipping
	|INTO TemporaryTableInventoryOwnership
	|FROM
	|	Document.SalesInvoice.InventoryOwnership AS SalesInvoiceInventory
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON SalesInvoiceInventory.Products = CatalogProducts.Ref
	|		INNER JOIN SalesInvoiceTable AS SalesInvoiceTable
	|		ON SalesInvoiceInventory.Ref = SalesInvoiceTable.Ref
	|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON SalesInvoiceInventory.Ownership = CatalogInventoryOwnership.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	SalesInvoiceTable.Date AS Period,
	|	&Company AS Company,
	|	SalesInvoiceTable.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	SalesInvoiceTable.Counterparty AS Counterparty,
	|	SalesInvoiceTable.DoOperationsByContracts AS DoOperationsByContracts,
	|	SalesInvoiceTable.DoOperationsByOrders AS DoOperationsByOrders,
	|	SalesInvoiceTable.AccountsReceivableGLAccount AS GLAccountCustomerSettlements,
	|	SalesInvoiceTable.AdvancesReceivedGLAccount AS CustomerAdvancesGLAccount,
	|	SalesInvoiceTable.Contract AS Contract,
	|	SalesInvoiceTable.SettlementsCurrency AS SettlementsCurrency,
	|	DocumentTable.Order AS Order,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLineSales,
	|	VALUE(Enum.SettlementsTypes.Advance) AS SettlementsType,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	&Ref AS DocumentWhere,
	|	SalesInvoiceTable.BasisDocument AS BasisDocument,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE CASE
	|				WHEN DocumentTable.Document REFS Document.PaymentExpense
	|					THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Item
	|				WHEN DocumentTable.Document REFS Document.CashReceipt
	|					THEN CAST(DocumentTable.Document AS Document.CashReceipt).Item
	|				WHEN DocumentTable.Document REFS Document.CashVoucher
	|					THEN CAST(DocumentTable.Document AS Document.CashVoucher).Item
	|				WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|					THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Item
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|			END
	|	END AS Item,
	|	CASE
	|		WHEN DocumentTable.Document REFS Document.PaymentExpense
	|			THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Date
	|		WHEN DocumentTable.Document REFS Document.CashReceipt
	|			THEN CAST(DocumentTable.Document AS Document.CashReceipt).Date
	|		WHEN DocumentTable.Document REFS Document.CashVoucher
	|			THEN CAST(DocumentTable.Document AS Document.CashVoucher).Date
	|		WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|			THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Date
	|		WHEN DocumentTable.Document REFS Document.ArApAdjustments
	|			THEN CAST(DocumentTable.Document AS Document.ArApAdjustments).Date
	|		WHEN DocumentTable.Document REFS Document.OnlineReceipt
	|			THEN CAST(DocumentTable.Document AS Document.OnlineReceipt).Date
	|	END AS DocumentDate,
	|	SUM(DocumentTable.PaymentAmount) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur,
	|	SalesInvoiceTable.SetPaymentTerms AS SetPaymentTerms
	|INTO TemporaryTablePrepayment
	|FROM
	|	Document.SalesInvoice.Prepayment AS DocumentTable
	|		INNER JOIN SalesInvoiceTable AS SalesInvoiceTable
	|		ON DocumentTable.Ref = SalesInvoiceTable.Ref
	|WHERE
	|	NOT SalesInvoiceTable.ThirdPartyPayment
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.Document,
	|	SalesInvoiceTable.Date,
	|	SalesInvoiceTable.Counterparty,
	|	SalesInvoiceTable.Contract,
	|	DocumentTable.Order,
	|	SalesInvoiceTable.SettlementsCurrency,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE CASE
	|				WHEN DocumentTable.Document REFS Document.PaymentExpense
	|					THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Item
	|				WHEN DocumentTable.Document REFS Document.CashReceipt
	|					THEN CAST(DocumentTable.Document AS Document.CashReceipt).Item
	|				WHEN DocumentTable.Document REFS Document.CashVoucher
	|					THEN CAST(DocumentTable.Document AS Document.CashVoucher).Item
	|				WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|					THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Item
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|			END
	|	END,
	|	CASE
	|		WHEN DocumentTable.Document REFS Document.PaymentExpense
	|			THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Date
	|		WHEN DocumentTable.Document REFS Document.CashReceipt
	|			THEN CAST(DocumentTable.Document AS Document.CashReceipt).Date
	|		WHEN DocumentTable.Document REFS Document.CashVoucher
	|			THEN CAST(DocumentTable.Document AS Document.CashVoucher).Date
	|		WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|			THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Date
	|		WHEN DocumentTable.Document REFS Document.ArApAdjustments
	|			THEN CAST(DocumentTable.Document AS Document.ArApAdjustments).Date
	|	END,
	|	SalesInvoiceTable.BasisDocument,
	|	SalesInvoiceTable.DoOperationsByContracts,
	|	SalesInvoiceTable.DoOperationsByOrders,
	|	SalesInvoiceTable.SetPaymentTerms,
	|	SalesInvoiceTable.AccountsReceivableGLAccount,
	|	SalesInvoiceTable.AdvancesReceivedGLAccount,
	|	SalesInvoiceTable.CompanyVATNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Ref AS Ref,
	|	SalesInvoiceTable.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	SalesInvoiceTable.Counterparty AS Counterparty,
	|	SalesInvoiceTable.Contract AS Contract,
	|	SalesInvoiceTable.DoOperationsByOrders AS DoOperationsByOrders,
	|	DocumentTable.Order AS Order,
	|	SalesInvoiceTable.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
	|	SalesInvoiceTable.SettlementsCurrency AS SettlementsCurrency,
	|	DocumentTable.AdvanceFlag AS AdvanceFlag,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN DocumentTable.AdvancesReceivedGLAccount
	|					ELSE DocumentTable.AccountsReceivableGLAccount
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AllocationGLAccount,
	|	SUM(DocumentTable.OffsetAmount) AS Amount
	|INTO TemporaryTableAmountAllocation
	|FROM
	|	SalesInvoiceTable AS SalesInvoiceTable
	|		INNER JOIN Document.SalesInvoice.AmountAllocation AS DocumentTable
	|		ON SalesInvoiceTable.Ref = DocumentTable.Ref
	|WHERE
	|	SalesInvoiceTable.ClosingInvoice
	|	AND SalesInvoiceTable.DocumentAmount < 0
	|
	|GROUP BY
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Document,
	|	SalesInvoiceTable.Date,
	|	SalesInvoiceTable.Counterparty,
	|	SalesInvoiceTable.Contract,
	|	DocumentTable.Order,
	|	SalesInvoiceTable.SettlementsCurrency,
	|	SalesInvoiceTable.DoOperationsByOrders,
	|	SalesInvoiceTable.AccountsReceivableGLAccount,
	|	SalesInvoiceTable.AdvancesReceivedGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN DocumentTable.AdvancesReceivedGLAccount
	|					ELSE DocumentTable.AccountsReceivableGLAccount
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoiceDiscountsMarkups.ConnectionKey AS ConnectionKey,
	|	SalesInvoiceDiscountsMarkups.DiscountMarkup AS DiscountMarkup,
	|	CAST(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN SalesInvoiceDiscountsMarkups.Amount * SalesInvoiceTable.Multiplicity / SalesInvoiceTable.ExchangeRate
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SalesInvoiceDiscountsMarkups.Amount * SalesInvoiceTable.ExchangeRate / SalesInvoiceTable.Multiplicity
	|		END AS NUMBER(15, 2)) AS Amount,
	|	SalesInvoiceTable.Date AS Period,
	|	SalesInvoiceTable.StructuralUnit AS StructuralUnit
	|INTO TemporaryTableAutoDiscountsMarkups
	|FROM
	|	Document.SalesInvoice.DiscountsMarkups AS SalesInvoiceDiscountsMarkups
	|		INNER JOIN SalesInvoiceTable AS SalesInvoiceTable
	|		ON SalesInvoiceDiscountsMarkups.Ref = SalesInvoiceTable.Ref
	|WHERE
	|	SalesInvoiceDiscountsMarkups.Amount <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoiceSerialNumbers.ConnectionKey AS ConnectionKey,
	|	SalesInvoiceSerialNumbers.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.SalesInvoice.SerialNumbers AS SalesInvoiceSerialNumbers
	|WHERE
	|	SalesInvoiceSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.PresentationCurrency AS PresentationCurrency,
	|	Header.Date AS Period,
	|	Header.Counterparty AS Customer,
	|	PrepaymentVAT.Document AS ShipmentDocument,
	|	PrepaymentVAT.VATRate AS VATRate,
	|	SUM(PrepaymentVAT.VATAmount) AS VATAmount,
	|	SUM(PrepaymentVAT.AmountExcludesVAT) AS AmountExcludesVAT
	|INTO TemporaryTablePrepaymentVAT
	|FROM
	|	SalesInvoiceTable AS Header
	|		INNER JOIN Document.SalesInvoice.PrepaymentVAT AS PrepaymentVAT
	|		ON Header.Ref = PrepaymentVAT.Ref
	|WHERE
	|	NOT PrepaymentVAT.VATRate.NotTaxable
	|	AND NOT Header.ThirdPartyPayment
	|
	|GROUP BY
	|	Header.Ref,
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	Header.PresentationCurrency,
	|	Header.Date,
	|	Header.Counterparty,
	|	PrepaymentVAT.Document,
	|	PrepaymentVAT.VATRate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableInventory.DoOperationsByOrders AS DoOperationsByOrders,
	|	TemporaryTableInventory.Order AS Order,
	|	SUM(TemporaryTableInventory.AmountDocCur) AS Total
	|INTO TemporaryTableOrdersTotal
	|FROM
	|	TemporaryTableInventoryOwnership AS TemporaryTableInventory
	|
	|GROUP BY
	|	TemporaryTableInventory.DoOperationsByOrders,
	|	TemporaryTableInventory.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableOrdersTotal.DoOperationsByOrders AS DoOperationsByOrders,
	|	SUM(TemporaryTableOrdersTotal.Total) AS Total
	|INTO TemporaryTableTotal
	|FROM
	|	TemporaryTableOrdersTotal AS TemporaryTableOrdersTotal
	|
	|GROUP BY
	|	TemporaryTableOrdersTotal.DoOperationsByOrders
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendar.LineNumber AS LineNumber,
	|	Calendar.PaymentDate AS Period,
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.PresentationCurrency AS PresentationCurrency,
	|	Header.Counterparty AS Counterparty,
	|	Header.DoOperationsByContracts AS DoOperationsByContracts,
	|	Header.DoOperationsByOrders AS DoOperationsByOrders,
	|	Header.AccountsReceivableGLAccount AS GLAccountCustomerSettlements,
	|	Header.Contract AS Contract,
	|	Header.SettlementsCurrency AS SettlementsCurrency,
	|	&Ref AS DocumentWhere,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	ISNULL(TemporaryTableOrdersTotal.Order, VALUE(Document.SalesOrder.EmptyRef)) AS Order,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN CAST(Calendar.PaymentAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN Header.Multiplicity / Header.ExchangeRate
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN Header.ExchangeRate / Header.Multiplicity
	|					END AS NUMBER(15, 2))
	|		ELSE CAST((Calendar.PaymentAmount + Calendar.PaymentVATAmount) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN Header.Multiplicity / Header.ExchangeRate
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN Header.ExchangeRate / Header.Multiplicity
	|				END AS NUMBER(15, 2))
	|	END * ISNULL(TemporaryTableOrdersTotal.Total, 1) / ISNULL(TemporaryTableTotal.Total, 1) AS Amount,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN CAST(Calendar.PaymentAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN Header.ContractCurrencyExchangeRate * Header.Multiplicity / (Header.ExchangeRate * Header.ContractCurrencyMultiplicity)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity)
	|					END AS NUMBER(15, 2))
	|		ELSE CAST((Calendar.PaymentAmount + Calendar.PaymentVATAmount) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN Header.ContractCurrencyExchangeRate * Header.Multiplicity / (Header.ExchangeRate * Header.ContractCurrencyMultiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity)
	|				END AS NUMBER(15, 2))
	|	END * ISNULL(TemporaryTableOrdersTotal.Total, 1) / ISNULL(TemporaryTableTotal.Total, 1) AS AmountCur
	|INTO TemporaryTablePaymentCalendarWithoutGroup
	|FROM
	|	SalesInvoiceTable AS Header
	|		INNER JOIN Document.SalesInvoice.PaymentCalendar AS Calendar
	|		ON Header.Ref = Calendar.Ref
	|		LEFT JOIN TemporaryTableOrdersTotal AS TemporaryTableOrdersTotal
	|		ON (TemporaryTableOrdersTotal.DoOperationsByOrders)
	|		LEFT JOIN TemporaryTableTotal AS TemporaryTableTotal
	|		ON (TemporaryTableTotal.DoOperationsByOrders)
	|WHERE
	|	NOT Header.ThirdPartyPayment
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(Calendar.LineNumber) AS LineNumber,
	|	Calendar.Period AS Period,
	|	Calendar.Company AS Company,
	|	Calendar.CompanyVATNumber AS CompanyVATNumber,
	|	Calendar.PresentationCurrency AS PresentationCurrency,
	|	Calendar.Counterparty AS Counterparty,
	|	Calendar.DoOperationsByContracts AS DoOperationsByContracts,
	|	Calendar.DoOperationsByOrders AS DoOperationsByOrders,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Calendar.GLAccountCustomerSettlements
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountCustomerSettlements,
	|	Calendar.Contract AS Contract,
	|	Calendar.SettlementsCurrency AS SettlementsCurrency,
	|	Calendar.DocumentWhere AS DocumentWhere,
	|	Calendar.SettlemensTypeWhere AS SettlemensTypeWhere,
	|	Calendar.Order AS Order,
	|	SUM(Calendar.Amount) AS Amount,
	|	SUM(Calendar.AmountCur) AS AmountCur
	|INTO TemporaryTablePaymentCalendar
	|FROM
	|	TemporaryTablePaymentCalendarWithoutGroup AS Calendar
	|
	|GROUP BY
	|	Calendar.Period,
	|	Calendar.Company,
	|	Calendar.CompanyVATNumber,
	|	Calendar.PresentationCurrency,
	|	Calendar.Counterparty,
	|	Calendar.DoOperationsByContracts,
	|	Calendar.DoOperationsByOrders,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Calendar.GLAccountCustomerSettlements
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	Calendar.Contract,
	|	Calendar.SettlementsCurrency,
	|	Calendar.DocumentWhere,
	|	Calendar.SettlemensTypeWhere,
	|	Calendar.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoiceTable.Date AS Period,
	|	SalesInvoiceTable.Company AS Company,
	|	SalesInvoiceTable.CompanyVATNumber AS CompanyVATNumber,
	|	SalesInvoiceTable.Counterparty AS Counterparty,
	|	SalesInvoiceConsumerMaterials.Products AS Products,
	|	SalesInvoiceConsumerMaterials.Characteristic AS Characteristic,
	|	SalesInvoiceConsumerMaterials.Batch AS Batch,
	|	SalesInvoiceConsumerMaterials.Quantity AS Quantity
	|INTO TemporaryTableMaterials
	|FROM
	|	SalesInvoiceTable AS SalesInvoiceTable
	|		INNER JOIN Document.SalesInvoice.ConsumerMaterials AS SalesInvoiceConsumerMaterials
	|		ON SalesInvoiceTable.Ref = SalesInvoiceConsumerMaterials.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoice.Date AS Period,
	|	SalesInvoice.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
	|	SalesInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	SalesInvoice.Contract AS Contract,
	|	SalesInvoice.SettlementsCurrency AS SettlementsCurrency,
	|	SalesTaxRates.Agency AS TaxKind,
	|	CAST(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN SalesTax.Amount * SalesInvoice.Multiplicity / SalesInvoice.ExchangeRate
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SalesTax.Amount * SalesInvoice.ExchangeRate / SalesInvoice.Multiplicity
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN SalesTax.Amount * SalesInvoice.ContractCurrencyExchangeRate * SalesInvoice.Multiplicity / (SalesInvoice.ExchangeRate * SalesInvoice.ContractCurrencyMultiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SalesTax.Amount * SalesInvoice.ExchangeRate * SalesInvoice.ContractCurrencyMultiplicity / (SalesInvoice.ContractCurrencyExchangeRate * SalesInvoice.Multiplicity)
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	SalesTax.Ref AS Ref,
	|	SalesTax.SalesTaxRate AS SalesTaxRate
	|INTO SalesTaxInvoiceTable
	|FROM
	|	Document.SalesInvoice.SalesTax AS SalesTax
	|		INNER JOIN SalesInvoiceTable AS SalesInvoice
	|		ON SalesTax.Ref = SalesInvoice.Ref
	|		INNER JOIN Catalog.SalesTaxRates AS SalesTaxRates
	|		ON SalesTax.SalesTaxRate = SalesTaxRates.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesTaxInvoiceTable.Period AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	SalesTaxInvoiceTable.CompanyVATNumber AS CompanyVATNumber,
	|	SUM(SalesTaxInvoiceTable.Amount) AS Amount,
	|	SUM(SalesTaxInvoiceTable.AmountCur) AS AmountCur,
	|	SalesTaxInvoiceTable.TaxKind AS TaxKind,
	|	SalesTaxInvoiceTable.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TaxTypes.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS TaxGLAccount,
	|	SalesTaxInvoiceTable.SettlementsCurrency AS SettlementsCurrency
	|INTO TemporarySalesTax
	|FROM
	|	SalesTaxInvoiceTable AS SalesTaxInvoiceTable
	|		LEFT JOIN Catalog.TaxTypes AS TaxTypes
	|		ON SalesTaxInvoiceTable.TaxKind = TaxTypes.Ref
	|
	|GROUP BY
	|	SalesTaxInvoiceTable.Period,
	|	SalesTaxInvoiceTable.CompanyVATNumber,
	|	SalesTaxInvoiceTable.TaxKind,
	|	SalesTaxInvoiceTable.AccountsReceivableGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TaxTypes.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	SalesTaxInvoiceTable.SettlementsCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTablePaymentCalendarWithoutGroup";
	
	StructureAdditionalProperties.ForPosting.Insert("IsZeroInvoice", GetIsZeroInvoice(DocumentRefSalesInvoice));
	
	Query.SetParameter("Ref",							DocumentRefSalesInvoice);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics",			StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",					StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins",				StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("UseSerialNumbers",				StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("ContinentalMethod",				StructureAdditionalProperties.AccountingPolicy.ContinentalMethod);
	Query.SetParameter("IssueClosingInvoices",			GetFunctionalOption("IssueClosingInvoices"));
	Query.SetParameter("PresentationCurrency",			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting",	StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	GenerateTableSales(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableProductRelease(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableInventoryInWarehouses(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableSalesOrders(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableWorkOrders(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableGoodsShippedNotInvoiced(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableGoodsInvoicedNotShipped(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableCustomerAccounts(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableThirdPartyPayments(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableGoodsConsumedToDeclare(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableReservedProducts(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	// DiscountCards
	GenerateTableSalesByDiscountCard(DocumentRefSalesInvoice, StructureAdditionalProperties);
	// AutomaticDiscounts
	GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	GenerateTableInventory(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	GenerateTableIncomeAndExpensesRetained(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefSalesInvoice, StructureAdditionalProperties);
	EndIf;
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	//VAT
	GenerateTableVATOutput(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	// Sales tax
	GenerateTableTaxPayable(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	GenerateTableAccountingEntriesData(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	FinancialAccounting.FillExtraDimensions(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefSalesInvoice, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefSalesInvoice, StructureAdditionalProperties);
		
	EndIf;

EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefSalesInvoice, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If StructureTemporaryTables.RegisterRecordsInventoryChange
		Or StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		Or StructureTemporaryTables.RegisterRecordsSalesOrdersChange 
		Or StructureTemporaryTables.RegisterRecordsAccountsReceivableChange
		Or StructureTemporaryTables.RegisterRecordsGoodsShippedNotInvoicedChange
		Or StructureTemporaryTables.RegisterRecordsGoodsInvoicedNotShippedChange
		Or StructureTemporaryTables.RegisterRecordsWorkOrdersChange
		Or StructureTemporaryTables.RegisterRecordsReservedProductsChange
		Or StructureTemporaryTables.RegisterRecordsSerialNumbersChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryInWarehousesChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryInWarehousesChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Products AS ProductsPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Batch AS BatchPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Ownership AS OwnershipPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Cell AS PresentationCell,
		|	InventoryInWarehousesOfBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	InventoryInWarehousesOfBalance.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryInWarehousesChange.QuantityChange, 0) + ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS BalanceInventoryInWarehouses,
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS QuantityBalanceInventoryInWarehouses
		|FROM
		|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
		|		INNER JOIN AccumulationRegister.InventoryInWarehouses.Balance(&ControlTime, ) AS InventoryInWarehousesOfBalance
		|		ON RegisterRecordsInventoryInWarehousesChange.Company = InventoryInWarehousesOfBalance.Company
		|			AND RegisterRecordsInventoryInWarehousesChange.StructuralUnit = InventoryInWarehousesOfBalance.StructuralUnit
		|			AND RegisterRecordsInventoryInWarehousesChange.Products = InventoryInWarehousesOfBalance.Products
		|			AND RegisterRecordsInventoryInWarehousesChange.Characteristic = InventoryInWarehousesOfBalance.Characteristic
		|			AND RegisterRecordsInventoryInWarehousesChange.Batch = InventoryInWarehousesOfBalance.Batch
		|			AND RegisterRecordsInventoryInWarehousesChange.Ownership = InventoryInWarehousesOfBalance.Ownership
		|			AND RegisterRecordsInventoryInWarehousesChange.Cell = InventoryInWarehousesOfBalance.Cell
		|			AND (ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryChange.PresentationCurrency AS PresentationCurrencyPresentation,
		|	RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsInventoryChange.InventoryAccountType AS InventoryAccountTypePresentation,
		|	RegisterRecordsInventoryChange.Products AS ProductsPresentation,
		|	RegisterRecordsInventoryChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsInventoryChange.Batch AS BatchPresentation,
		|	RegisterRecordsInventoryChange.Ownership AS OwnershipPresentation,
		|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	InventoryBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
		|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
		|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|		INNER JOIN AccumulationRegister.Inventory.Balance(&ControlTime, ) AS InventoryBalances
		|		ON RegisterRecordsInventoryChange.Company = InventoryBalances.Company
		|			AND RegisterRecordsInventoryChange.PresentationCurrency = InventoryBalances.PresentationCurrency
		|			AND RegisterRecordsInventoryChange.StructuralUnit = InventoryBalances.StructuralUnit
		|			AND RegisterRecordsInventoryChange.InventoryAccountType = InventoryBalances.InventoryAccountType
		|			AND RegisterRecordsInventoryChange.Products = InventoryBalances.Products
		|			AND RegisterRecordsInventoryChange.Characteristic = InventoryBalances.Characteristic
		|			AND RegisterRecordsInventoryChange.Batch = InventoryBalances.Batch
		|			AND RegisterRecordsInventoryChange.Ownership = InventoryBalances.Ownership
		|			AND RegisterRecordsInventoryChange.CostObject = InventoryBalances.CostObject
		|			AND (ISNULL(InventoryBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSalesOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsSalesOrdersChange.Company AS CompanyPresentation,
		|	RegisterRecordsSalesOrdersChange.SalesOrder AS OrderPresentation,
		|	RegisterRecordsSalesOrdersChange.Products AS ProductsPresentation,
		|	RegisterRecordsSalesOrdersChange.Characteristic AS CharacteristicPresentation,
		|	SalesOrdersBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsSalesOrdersChange.QuantityChange, 0) + ISNULL(SalesOrdersBalances.QuantityBalance, 0) AS BalanceSalesOrders,
		|	ISNULL(SalesOrdersBalances.QuantityBalance, 0) AS QuantityBalanceSalesOrders
		|FROM
		|	RegisterRecordsSalesOrdersChange AS RegisterRecordsSalesOrdersChange
		|		INNER JOIN AccumulationRegister.SalesOrders.Balance(&ControlTime, ) AS SalesOrdersBalances
		|		ON RegisterRecordsSalesOrdersChange.Company = SalesOrdersBalances.Company
		|			AND RegisterRecordsSalesOrdersChange.SalesOrder = SalesOrdersBalances.SalesOrder
		|			AND RegisterRecordsSalesOrdersChange.Products = SalesOrdersBalances.Products
		|			AND RegisterRecordsSalesOrdersChange.Characteristic = SalesOrdersBalances.Characteristic
		|			AND (ISNULL(SalesOrdersBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsAccountsReceivableChange.LineNumber AS LineNumber,
		|	RegisterRecordsAccountsReceivableChange.Company AS CompanyPresentation,
		|	RegisterRecordsAccountsReceivableChange.PresentationCurrency AS PresentationCurrencyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Contract AS ContractPresentation,
		|	RegisterRecordsAccountsReceivableChange.Contract.SettlementsCurrency AS CurrencyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Document AS DocumentPresentation,
		|	RegisterRecordsAccountsReceivableChange.Order AS OrderPresentation,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS CalculationsTypesPresentation,
		|	FALSE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsAccountsReceivableChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountChange AS AmountChange,
		|	RegisterRecordsAccountsReceivableChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite - ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AdvanceAmountsReceived,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountOfOutstandingDebt,
		|	ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange
		|		INNER JOIN AccumulationRegister.AccountsReceivable.Balance(&ControlTime, ) AS AccountsReceivableBalances
		|		ON RegisterRecordsAccountsReceivableChange.Company = AccountsReceivableBalances.Company
		|			AND RegisterRecordsAccountsReceivableChange.PresentationCurrency = AccountsReceivableBalances.PresentationCurrency
		|			AND RegisterRecordsAccountsReceivableChange.Counterparty = AccountsReceivableBalances.Counterparty
		|			AND RegisterRecordsAccountsReceivableChange.Contract = AccountsReceivableBalances.Contract
		|			AND RegisterRecordsAccountsReceivableChange.Document = AccountsReceivableBalances.Document
		|			AND RegisterRecordsAccountsReceivableChange.Order = AccountsReceivableBalances.Order
		|			AND RegisterRecordsAccountsReceivableChange.SettlementsType = AccountsReceivableBalances.SettlementsType
		|			AND (CASE
		|				WHEN RegisterRecordsAccountsReceivableChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|					THEN ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) > 0
		|				ELSE ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) < 0
		|			END)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsWorkOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsWorkOrdersChange.Company AS CompanyPresentation,
		|	RegisterRecordsWorkOrdersChange.WorkOrder AS OrderPresentation,
		|	RegisterRecordsWorkOrdersChange.Products AS ProductsPresentation,
		|	RegisterRecordsWorkOrdersChange.Characteristic AS CharacteristicPresentation,
		|	WorkOrdersBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsWorkOrdersChange.QuantityChange, 0) + ISNULL(WorkOrdersBalances.QuantityBalance, 0) AS BalanceWorkOrders,
		|	ISNULL(WorkOrdersBalances.QuantityBalance, 0) AS QuantityBalanceWorkOrders
		|FROM
		|	RegisterRecordsWorkOrdersChange AS RegisterRecordsWorkOrdersChange
		|		INNER JOIN AccumulationRegister.WorkOrders.Balance(&ControlTime, ) AS WorkOrdersBalances
		|		ON RegisterRecordsWorkOrdersChange.Company = WorkOrdersBalances.Company
		|			AND RegisterRecordsWorkOrdersChange.WorkOrder = WorkOrdersBalances.WorkOrder
		|			AND RegisterRecordsWorkOrdersChange.Products = WorkOrdersBalances.Products
		|			AND RegisterRecordsWorkOrdersChange.Characteristic = WorkOrdersBalances.Characteristic
		|			AND (ISNULL(WorkOrdersBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSerialNumbersChange.LineNumber AS LineNumber,
		|	RegisterRecordsSerialNumbersChange.SerialNumber AS SerialNumberPresentation,
		|	RegisterRecordsSerialNumbersChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsSerialNumbersChange.Products AS ProductsPresentation,
		|	RegisterRecordsSerialNumbersChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsSerialNumbersChange.Batch AS BatchPresentation,
		|	RegisterRecordsSerialNumbersChange.Ownership AS OwnershipPresentation,
		|	RegisterRecordsSerialNumbersChange.Cell AS PresentationCell,
		|	SerialNumbersBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	SerialNumbersBalance.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsSerialNumbersChange.QuantityChange, 0) + ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceSerialNumbers,
		|	ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceQuantitySerialNumbers
		|FROM
		|	RegisterRecordsSerialNumbersChange AS RegisterRecordsSerialNumbersChange
		|		INNER JOIN AccumulationRegister.SerialNumbers.Balance(&ControlTime, ) AS SerialNumbersBalance
		|		ON RegisterRecordsSerialNumbersChange.StructuralUnit = SerialNumbersBalance.StructuralUnit
		|			AND RegisterRecordsSerialNumbersChange.Products = SerialNumbersBalance.Products
		|			AND RegisterRecordsSerialNumbersChange.Characteristic = SerialNumbersBalance.Characteristic
		|			AND RegisterRecordsSerialNumbersChange.Batch = SerialNumbersBalance.Batch
		|			AND RegisterRecordsSerialNumbersChange.Ownership = SerialNumbersBalance.Ownership
		|			AND RegisterRecordsSerialNumbersChange.SerialNumber = SerialNumbersBalance.SerialNumber
		|			AND RegisterRecordsSerialNumbersChange.Cell = SerialNumbersBalance.Cell
		|			AND (ISNULL(SerialNumbersBalance.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.ReservedProducts.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.GoodsShippedNotInvoiced.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.GoodsInvoicedNotShipped.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.Inventory.ReturnQuantityControlQueryText(False);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		Query.SetParameter("Ref", DocumentRefSalesInvoice);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			Or Not ResultsArray[1].IsEmpty()
			Or Not ResultsArray[2].IsEmpty()
			Or Not ResultsArray[3].IsEmpty()
			Or Not ResultsArray[4].IsEmpty()
			Or Not ResultsArray[5].IsEmpty()
			Or Not ResultsArray[6].IsEmpty()
			Or Not ResultsArray[7].IsEmpty()
			Or Not ResultsArray[8].IsEmpty()
			Or Not ResultsArray[12].IsEmpty() Then
			DocumentObjectSalesInvoice = DocumentRefSalesInvoice.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		// Negative balance of inventory.
		ElsIf Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		// Negative balance of need for reserved products.
		ElsIf Not ResultsArray[6].IsEmpty() Then
			QueryResultSelection = ResultsArray[6].Select();
			DriveServer.ShowMessageAboutPostingToReservedProductsRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		Else
			// Negative balance of inventory with reserves.
			DriveServer.CheckAvailableStockBalance(DocumentObjectSalesInvoice, AdditionalProperties, Cancel);
		EndIf;
		
		// Negative balance on sales order.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToSalesOrdersRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on work order.
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			DriveServer.ShowMessageAboutPostingToWorkOrdersRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If NOT ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on goods issued not yet invoiced
		If Not ResultsArray[7].IsEmpty() Then
			QueryResultSelection = ResultsArray[7].Select();
			DriveServer.ShowMessageAboutPostingToGoodsShippedNotInvoicedRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on goods invoiced not shipped
		If Not ResultsArray[8].IsEmpty() Then
			QueryResultSelection = ResultsArray[8].Select();
			DriveServer.ShowMessageAboutPostingToGoodsInvoicedNotShippedRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of return quantity in inventory
		If Not ResultsArray[12].IsEmpty() And ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[12].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterRefundsErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region LibrariesHandlers

#Region PrintInterface

Function PrintClosingInvoice(ObjectsArray, PrintObjects, TemplateName, PrintParams,
	PrintAnnex, PrintAnnexParams = Undefined)
	
	DisplayPrintOption = (PrintParams <> Undefined);
	
	If DisplayPrintOption Then
		PrintParams.LineTotal = True;
		PrintParams.NetAmount = True;
		PrintParams.VAT = True;
		PrintParams.Discount = False;
	EndIf;
	
	StructureFlags			= DriveServer.GetStructureFlags(DisplayPrintOption, PrintParams);
	StructureSecondFlags	= DriveServer.GetStructureSecondFlags(DisplayPrintOption, PrintParams);
	CounterShift			= DriveServer.GetCounterShift(StructureFlags);
	
	If PrintAnnexParams = Undefined Then
		PrintAnnexParams = New Structure("AnnexPrintMode", False);
	EndIf;
	
	Query = New Query;
	
	If PrintAnnexParams.AnnexPrintMode Then
		
		SpreadsheetDocument = PrintAnnexParams.SpreadsheetDocument;
		Query.TempTablesManager = PrintAnnexParams.TempTablesManager;
		
		#Region PrintClosingInvoiceAnnexQueryText
		
		Query.Text = 
		"SELECT
		|	Tabular.Ref AS Ref,
		|	Tabular.DocumentNumber AS DocumentNumber,
		|	Tabular.DocumentDate AS DocumentDate,
		|	Tabular.Company AS Company,
		|	Tabular.CompanyVATNumber AS CompanyVATNumber,
		|	Tabular.Counterparty AS Counterparty,
		|	Tabular.Contract AS Contract,
		|	Tabular.ShippingAddress AS ShippingAddress,
		|	Tabular.CounterpartyContactPerson AS CounterpartyContactPerson,
		|	Tabular.AmountIncludesVAT AS AmountIncludesVAT,
		|	Tabular.DocumentCurrency AS DocumentCurrency,
		|	Tabular.Comment AS Comment,
		|	Tabular.LineNumber AS LineNumber,
		|	Tabular.SKU AS SKU,
		|	Tabular.ProductDescription AS ProductDescription,
		|	Tabular.ContentUsed AS ContentUsed,
		|	Tabular.UseSerialNumbers AS UseSerialNumbers,
		|	Tabular.Quantity AS Quantity,
		|	Tabular.Price AS Price,
		|	Tabular.VATRate AS VATRate,
		|	Tabular.Amount AS Amount,
		|	Tabular.VATAmount AS VATAmount,
		|	Tabular.Total AS Total,
		|	Tabular.PureAmount AS PureAmount,
		|	Tabular.PureVATAmount AS PureVATAmount,
		|	Tabular.PureTotal AS PureTotal,
		|	Tabular.Products AS Products,
		|	Tabular.CharacteristicDescription AS CharacteristicDescription,
		|	Tabular.BatchDescription AS BatchDescription,
		|	Tabular.ConnectionKey AS ConnectionKey,
		|	Tabular.Characteristic AS Characteristic,
		|	Tabular.MeasurementUnit AS MeasurementUnit,
		|	Tabular.Batch AS Batch,
		|	Tabular.UOM AS UOM,
		|	Tabular.StructuralUnit AS StructuralUnit,
		|	Tabular.DeliveryOption AS DeliveryOption,
		|	Tabular.ProvideEPD AS ProvideEPD,
		|	Tabular.BundleProduct AS BundleProduct,
		|	Tabular.BundleCharacteristic AS BundleCharacteristic,
		|	Tabular.IsRegisterDeliveryDate AS IsRegisterDeliveryDate,
		|	Tabular.DeliveryDatePosition AS DeliveryDatePosition,
		|	Tabular.DeliveryDatePeriod AS DeliveryDatePeriod,
		|	Tabular.DeliveryStartDate AS DeliveryStartDate,
		|	Tabular.DeliveryEndDate AS DeliveryEndDate,
		|	Tabular.CompanyLogoFile AS CompanyLogoFile
		|FROM
		|	Tabular AS Tabular
		|WHERE
		|	Tabular.Ref = &Ref
		|	AND Tabular.Products = &Products
		|	AND Tabular.VATRate = &VATRate
		|
		|ORDER BY
		|	Tabular.DocumentNumber,
		|	LineNumber
		|TOTALS
		|	MAX(DocumentNumber),
		|	MAX(DocumentDate),
		|	MAX(Company),
		|	MAX(CompanyVATNumber),
		|	MAX(Counterparty),
		|	MAX(Contract),
		|	MAX(ShippingAddress),
		|	MAX(CounterpartyContactPerson),
		|	MAX(AmountIncludesVAT),
		|	MAX(DocumentCurrency),
		|	MAX(Comment),
		|	COUNT(LineNumber),
		|	SUM(Quantity),
		|	SUM(Amount),
		|	SUM(VATAmount),
		|	SUM(Total),
		|	MAX(StructuralUnit),
		|	MAX(DeliveryOption),
		|	MAX(ProvideEPD),
		|	MAX(IsRegisterDeliveryDate),
		|	MAX(DeliveryDatePosition),
		|	MAX(DeliveryDatePeriod),
		|	MAX(DeliveryStartDate),
		|	MAX(DeliveryEndDate),
		|	MAX(CompanyLogoFile)
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
		|	FALSE
		|TOTALS BY
		|	Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Tabular.Ref AS Ref,
		|	CASE
		|		WHEN Tabular.ReverseCharge
		|				AND Tabular.VATRate = VALUE(Catalog.VATRates.ZeroRate)
		|			THEN &ReverseChargeAppliesRate
		|		ELSE Tabular.VATRate
		|	END AS VATRate,
		|	SUM(Tabular.PureAmount) AS Amount,
		|	SUM(Tabular.PureVATAmount) AS VATAmount,
		|	SUM(Tabular.PureTotal) AS Total
		|FROM
		|	Tabular AS Tabular
		|WHERE
		|	Tabular.Ref = &Ref
		|	AND Tabular.Products = &Products
		|	AND Tabular.VATRate = &VATRate
		|
		|GROUP BY
		|	Tabular.Ref,
		|	CASE
		|		WHEN Tabular.ReverseCharge
		|				AND Tabular.VATRate = VALUE(Catalog.VATRates.ZeroRate)
		|			THEN &ReverseChargeAppliesRate
		|		ELSE Tabular.VATRate
		|	END
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
		|			AND FilteredInventory.Price = Tabular.Price
		|			AND FilteredInventory.VATRate = Tabular.VATRate
		|			AND (NOT Tabular.ContentUsed)
		|			AND FilteredInventory.Ref = Tabular.Ref
		|			AND FilteredInventory.Characteristic = Tabular.Characteristic
		|			AND FilteredInventory.MeasurementUnit = Tabular.MeasurementUnit
		|			AND FilteredInventory.Batch = Tabular.Batch
		|		INNER JOIN Document.SalesInvoice.SerialNumbers AS SalesInvoiceSerialNumbers
		|			LEFT JOIN Catalog.SerialNumbers AS SerialNumbers
		|			ON SalesInvoiceSerialNumbers.SerialNumber = SerialNumbers.Ref
		|		ON (SalesInvoiceSerialNumbers.ConnectionKey = FilteredInventory.ConnectionKey)
		|			AND FilteredInventory.Ref = SalesInvoiceSerialNumbers.Ref
		|WHERE
		|	FilteredInventory.Ref = &Ref
		|	AND FilteredInventory.Products = &Products
		|	AND FilteredInventory.VATRate = &VATRate
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SalesInvoiceEarlyPaymentDiscounts.Period AS Period,
		|	SalesInvoiceEarlyPaymentDiscounts.Discount AS Discount,
		|	SalesInvoiceEarlyPaymentDiscounts.DiscountAmount AS DiscountAmount,
		|	SalesInvoiceEarlyPaymentDiscounts.DueDate AS DueDate,
		|	SalesInvoiceEarlyPaymentDiscounts.Ref AS Ref
		|FROM
		|	Document.SalesInvoice.EarlyPaymentDiscounts AS SalesInvoiceEarlyPaymentDiscounts
		|		INNER JOIN Tabular AS Tabular
		|		ON SalesInvoiceEarlyPaymentDiscounts.Ref = Tabular.Ref
		|WHERE
		|	FALSE
		|TOTALS BY
		|	Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	IssuedInvoices.Ref AS Ref,
		|	IssuedInvoices.Invoice AS Invoice,
		|	IssuedInvoices.Date AS Date,
		|	IssuedInvoices.Number AS Number,
		|	SUM(IssuedInvoices.Amount) AS Amount,
		|	IssuedInvoices.VATRate AS VATRate,
		|	SUM(IssuedInvoices.VATAmount) AS VATAmount,
		|	SUM(IssuedInvoices.Total) AS Total
		|FROM
		|	IssuedInvoices AS IssuedInvoices
		|WHERE
		|	IssuedInvoices.Ref = &Ref
		|	AND IssuedInvoices.Products = &Products
		|	AND IssuedInvoices.VATRate = &VATRate
		|
		|GROUP BY
		|	IssuedInvoices.VATRate,
		|	IssuedInvoices.Ref,
		|	IssuedInvoices.Number,
		|	IssuedInvoices.Invoice,
		|	IssuedInvoices.Date
		|
		|ORDER BY
		|	Date
		|TOTALS
		|	MAX(Date),
		|	MAX(Number),
		|	SUM(Amount),
		|	SUM(VATAmount),
		|	SUM(Total)
		|BY
		|	Ref,
		|	Invoice
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	IssuedInvoices.Ref AS Ref,
		|	IssuedInvoices.Invoice AS Invoice,
		|	DATETIME(1, 1, 1) AS Date,
		|	0 AS Amount
		|FROM
		|	IssuedInvoices AS IssuedInvoices
		|WHERE
		|	FALSE";
		
		#EndRegion
		
		Query.SetParameter("Ref", PrintAnnexParams.Ref);
		Query.SetParameter("Products", PrintAnnexParams.Products);
		Query.SetParameter("VATRate", PrintAnnexParams.VATRate);
		
	Else
		
		SpreadsheetDocument = New SpreadsheetDocument;
		SpreadsheetDocument.PrintParametersKey = "PrintParameters_ClosingInvoice";
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_ClosingInvoice";
		
		Query.TempTablesManager = New TempTablesManager;
		
		#Region PrintClosingInvoiceQueryText
		
		Query.Text = 
		"SELECT ALLOWED
		|	SalesInvoice.Ref AS Ref,
		|	SalesInvoice.Number AS Number,
		|	SalesInvoice.Date AS Date,
		|	SalesInvoice.Company AS Company,
		|	SalesInvoice.CompanyVATNumber AS CompanyVATNumber,
		|	SalesInvoice.Counterparty AS Counterparty,
		|	SalesInvoice.Contract AS Contract,
		|	SalesInvoice.ShippingAddress AS ShippingAddress,
		|	SalesInvoice.ContactPerson AS ContactPerson,
		|	SalesInvoice.AmountIncludesVAT AS AmountIncludesVAT,
		|	SalesInvoice.DocumentCurrency AS DocumentCurrency,
		|	CAST(SalesInvoice.Comment AS STRING(1024)) AS Comment,
		|	SalesInvoice.Order AS Order,
		|	SalesInvoice.SalesOrderPosition AS SalesOrderPosition,
		|	SalesInvoice.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT) AS ReverseCharge,
		|	SalesInvoice.StructuralUnit AS StructuralUnit,
		|	SalesInvoice.DeliveryOption AS DeliveryOption,
		|	SalesInvoice.ProvideEPD AS ProvideEPD,
		|	SalesInvoice.DeliveryStartDate AS DeliveryStartDate,
		|	SalesInvoice.DeliveryEndDate AS DeliveryEndDate,
		|	SalesInvoice.DeliveryDatePeriod AS DeliveryDatePeriod,
		|	VALUE(Enum.AttributeStationing.InHeader) AS DeliveryDatePosition,
		|	TRUE AS IsRegisterDeliveryDate
		|INTO SalesInvoices
		|FROM
		|	Document.SalesInvoice AS SalesInvoice
		|WHERE
		|	SalesInvoice.Ref IN(&ObjectsArray)
		|	AND SalesInvoice.OperationKind = VALUE(Enum.OperationTypesSalesInvoice.ClosingInvoice)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SalesInvoice.Ref AS Ref,
		|	SalesInvoice.Number AS DocumentNumber,
		|	SalesInvoice.Date AS DocumentDate,
		|	SalesInvoice.Company AS Company,
		|	SalesInvoice.CompanyVATNumber AS CompanyVATNumber,
		|	SalesInvoice.Counterparty AS Counterparty,
		|	SalesInvoice.Contract AS Contract,
		|	SalesInvoice.ShippingAddress AS ShippingAddress,
		|	CASE
		|		WHEN SalesInvoice.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
		|			THEN SalesInvoice.ContactPerson
		|		WHEN CounterpartyContracts.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
		|			THEN CounterpartyContracts.ContactPerson
		|		ELSE Counterparties.ContactPerson
		|	END AS CounterpartyContactPerson,
		|	SalesInvoice.AmountIncludesVAT AS AmountIncludesVAT,
		|	SalesInvoice.DocumentCurrency AS DocumentCurrency,
		|	ISNULL(SalesOrder.Number, """") AS SalesOrderNumber,
		|	ISNULL(SalesOrder.Date, DATETIME(1, 1, 1)) AS SalesOrderDate,
		|	SalesInvoice.Comment AS Comment,
		|	SalesInvoice.ReverseCharge AS ReverseCharge,
		|	SalesInvoice.StructuralUnit AS StructuralUnit,
		|	SalesInvoice.DeliveryOption AS DeliveryOption,
		|	SalesInvoice.ProvideEPD AS ProvideEPD,
		|	SalesInvoice.IsRegisterDeliveryDate AS IsRegisterDeliveryDate,
		|	SalesInvoice.DeliveryDatePosition AS DeliveryDatePosition,
		|	SalesInvoice.DeliveryDatePeriod AS DeliveryDatePeriod,
		|	SalesInvoice.DeliveryStartDate AS DeliveryStartDate,
		|	SalesInvoice.DeliveryEndDate AS DeliveryEndDate
		|INTO Header
		|FROM
		|	SalesInvoices AS SalesInvoice
		|		LEFT JOIN Catalog.Counterparties AS Counterparties
		|		ON SalesInvoice.Counterparty = Counterparties.Ref
		|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
		|		ON SalesInvoice.Contract = CounterpartyContracts.Ref
		|		LEFT JOIN Document.SalesOrder AS SalesOrder
		|		ON SalesInvoice.Order = SalesOrder.Ref
		|			AND (SalesInvoice.SalesOrderPosition = VALUE(Enum.AttributeStationing.InHeader))
		|
		|GROUP BY
		|	SalesInvoice.Number,
		|	SalesInvoice.Date,
		|	SalesInvoice.Counterparty,
		|	SalesInvoice.Company,
		|	SalesInvoice.CompanyVATNumber,
		|	SalesInvoice.Ref,
		|	SalesInvoice.Comment,
		|	ISNULL(SalesOrder.Date, DATETIME(1, 1, 1)),
		|	ISNULL(SalesOrder.Number, """"),
		|	SalesInvoice.DocumentCurrency,
		|	SalesInvoice.AmountIncludesVAT,
		|	SalesInvoice.ShippingAddress,
		|	CASE
		|		WHEN SalesInvoice.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
		|			THEN SalesInvoice.ContactPerson
		|		WHEN CounterpartyContracts.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
		|			THEN CounterpartyContracts.ContactPerson
		|		ELSE Counterparties.ContactPerson
		|	END,
		|	SalesInvoice.ReverseCharge,
		|	SalesInvoice.Contract,
		|	SalesInvoice.StructuralUnit,
		|	SalesInvoice.DeliveryOption,
		|	SalesInvoice.ProvideEPD,
		|	SalesInvoice.IsRegisterDeliveryDate,
		|	SalesInvoice.DeliveryDatePosition,
		|	SalesInvoice.DeliveryDatePeriod,
		|	SalesInvoice.DeliveryStartDate,
		|	SalesInvoice.DeliveryEndDate
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SalesInvoiceInventory.Ref AS Ref,
		|	SalesInvoiceInventory.LineNumber AS LineNumber,
		|	SalesInvoiceInventory.Products AS Products,
		|	SalesInvoiceInventory.Characteristic AS Characteristic,
		|	SalesInvoiceInventory.Batch AS Batch,
		|	SalesInvoiceInventory.ActualQuantity AS Quantity,
		|	SalesInvoiceInventory.Reserve AS Reserve,
		|	SalesInvoiceInventory.MeasurementUnit AS MeasurementUnit,
		|	SalesInvoiceInventory.Price AS Price,
		|	SalesInvoiceInventory.Total - SalesInvoiceInventory.VATAmount AS Amount,
		|	SalesInvoiceInventory.VATRate AS VATRate,
		|	SalesInvoiceInventory.VATAmount AS VATAmount,
		|	SalesInvoiceInventory.Total AS Total,
		|	SalesInvoiceInventory.Order AS Order,
		|	SalesInvoiceInventory.Content AS Content,
		|	SalesInvoiceInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
		|	SalesInvoiceInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
		|	SalesInvoiceInventory.ConnectionKey AS ConnectionKey,
		|	SalesInvoiceInventory.BundleProduct AS BundleProduct,
		|	SalesInvoiceInventory.BundleCharacteristic AS BundleCharacteristic,
		|	SalesInvoiceInventory.DeliveryStartDate AS DeliveryStartDate,
		|	SalesInvoiceInventory.DeliveryEndDate AS DeliveryEndDate,
		|	ISNULL(VATRates.Rate, 0) AS NumberVATRate,
		|	Companies.LogoFile AS CompanyLogoFile
		|INTO FilteredInventory
		|FROM
		|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
		|		INNER JOIN SalesInvoices AS SalesInvoices
		|			LEFT JOIN Catalog.Companies AS Companies
		|			ON SalesInvoices.Company = Companies.Ref
		|		ON SalesInvoiceInventory.Ref = SalesInvoices.Ref
		|		LEFT JOIN Catalog.VATRates AS VATRates
		|		ON SalesInvoiceInventory.VATRate = VATRates.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	Header.Ref AS Ref,
		|	Header.DocumentNumber AS DocumentNumber,
		|	Header.DocumentDate AS DocumentDate,
		|	Header.Company AS Company,
		|	Header.CompanyVATNumber AS CompanyVATNumber,
		|	FilteredInventory.CompanyLogoFile AS CompanyLogoFile,
		|	Header.Counterparty AS Counterparty,
		|	Header.Contract AS Contract,
		|	Header.ShippingAddress AS ShippingAddress,
		|	Header.CounterpartyContactPerson AS CounterpartyContactPerson,
		|	Header.AmountIncludesVAT AS AmountIncludesVAT,
		|	Header.DocumentCurrency AS DocumentCurrency,
		|	Header.Comment AS Comment,
		|	Header.ReverseCharge AS ReverseCharge,
		|	MIN(FilteredInventory.LineNumber) AS LineNumber,
		|	CatalogProducts.SKU AS SKU,
		|	CASE
		|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
		|			THEN CAST(FilteredInventory.Content AS STRING(1024))
		|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
		|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
		|		ELSE CatalogProducts.Description
		|	END AS ProductDescription,
		|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """" AS ContentUsed,
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
		|	ISNULL(CatalogProducts.UseSerialNumbers, FALSE) AS UseSerialNumbers,
		|	MIN(FilteredInventory.ConnectionKey) AS ConnectionKey,
		|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
		|	SUM(FilteredInventory.Quantity) AS Quantity,
		|	FilteredInventory.Price AS Price,
		|	SUM(FilteredInventory.Amount) AS PureAmount,
		|	SUM(CASE
		|			WHEN Header.AmountIncludesVAT
		|				THEN CAST(FilteredInventory.Quantity * FilteredInventory.Price / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
		|			ELSE CAST(FilteredInventory.Quantity * FilteredInventory.Price AS NUMBER(15, 2))
		|		END) AS Amount,
		|	FilteredInventory.VATRate AS VATRate,
		|	SUM(FilteredInventory.VATAmount) AS PureVATAmount,
		|	SUM(CASE
		|			WHEN Header.AmountIncludesVAT
		|				THEN CAST(FilteredInventory.Quantity * FilteredInventory.Price * FilteredInventory.NumberVATRate / (100 + FilteredInventory.NumberVATRate) AS NUMBER(15, 2))
		|			ELSE CAST(FilteredInventory.Quantity * FilteredInventory.Price * FilteredInventory.NumberVATRate / 100 AS NUMBER(15, 2))
		|		END) AS VATAmount,
		|	SUM(FilteredInventory.Total) AS PureTotal,
		|	SUM(CASE
		|			WHEN Header.AmountIncludesVAT
		|				THEN CAST(FilteredInventory.Quantity * FilteredInventory.Price AS NUMBER(15, 2))
		|			ELSE CAST(FilteredInventory.Quantity * FilteredInventory.Price * (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
		|		END) AS Total,
		|	ISNULL(SalesOrder.Number, Header.SalesOrderNumber) AS SalesOrderNumber,
		|	ISNULL(SalesOrder.Date, Header.SalesOrderDate) AS SalesOrderDate,
		|	FilteredInventory.Products AS Products,
		|	FilteredInventory.Characteristic AS Characteristic,
		|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
		|	FilteredInventory.Batch AS Batch,
		|	Header.StructuralUnit AS StructuralUnit,
		|	Header.DeliveryOption AS DeliveryOption,
		|	Header.ProvideEPD AS ProvideEPD,
		|	FilteredInventory.BundleProduct AS BundleProduct,
		|	FilteredInventory.BundleCharacteristic AS BundleCharacteristic,
		|	Header.IsRegisterDeliveryDate AS IsRegisterDeliveryDate,
		|	Header.DeliveryDatePosition AS DeliveryDatePosition,
		|	Header.DeliveryDatePeriod AS DeliveryDatePeriod,
		|	CASE
		|		WHEN Header.DeliveryDatePosition = VALUE(Enum.AttributeStationing.InHeader)
		|			THEN Header.DeliveryStartDate
		|		ELSE FilteredInventory.DeliveryStartDate
		|	END AS DeliveryStartDate,
		|	CASE
		|		WHEN Header.DeliveryDatePosition = VALUE(Enum.AttributeStationing.InHeader)
		|			THEN Header.DeliveryEndDate
		|		ELSE FilteredInventory.DeliveryEndDate
		|	END AS DeliveryEndDate
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
		|		LEFT JOIN Document.SalesOrder AS SalesOrder
		|		ON (FilteredInventory.Order = SalesOrder.Ref)
		|			AND (Header.SalesOrderNumber = """")
		|
		|GROUP BY
		|	Header.DocumentNumber,
		|	Header.DocumentDate,
		|	Header.Company,
		|	Header.CompanyVATNumber,
		|	Header.Ref,
		|	Header.Counterparty,
		|	Header.Contract,
		|	Header.ShippingAddress,
		|	Header.CounterpartyContactPerson,
		|	Header.AmountIncludesVAT,
		|	Header.DocumentCurrency,
		|	Header.Comment,
		|	Header.ReverseCharge,
		|	CatalogProducts.SKU,
		|	CASE
		|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
		|			THEN CAST(FilteredInventory.Content AS STRING(1024))
		|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
		|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
		|		ELSE CatalogProducts.Description
		|	END,
		|	ISNULL(SalesOrder.Date, Header.SalesOrderDate),
		|	CASE
		|		WHEN CatalogProducts.UseCharacteristics
		|			THEN CatalogCharacteristics.Description
		|		ELSE """"
		|	END,
		|	ISNULL(SalesOrder.Number, Header.SalesOrderNumber),
		|	ISNULL(CatalogProducts.UseSerialNumbers, FALSE),
		|	FilteredInventory.VATRate,
		|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
		|	FilteredInventory.Products,
		|	CASE
		|		WHEN CatalogProducts.UseBatches
		|			THEN CatalogBatches.Description
		|		ELSE """"
		|	END,
		|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """",
		|	FilteredInventory.Price,
		|	FilteredInventory.Characteristic,
		|	FilteredInventory.MeasurementUnit,
		|	FilteredInventory.Batch,
		|	Header.StructuralUnit,
		|	Header.DeliveryOption,
		|	Header.ProvideEPD,
		|	FilteredInventory.BundleProduct,
		|	FilteredInventory.BundleCharacteristic,
		|	Header.IsRegisterDeliveryDate,
		|	Header.DeliveryDatePosition,
		|	Header.DeliveryDatePeriod,
		|	CASE
		|		WHEN Header.DeliveryDatePosition = VALUE(Enum.AttributeStationing.InHeader)
		|			THEN Header.DeliveryStartDate
		|		ELSE FilteredInventory.DeliveryStartDate
		|	END,
		|	CASE
		|		WHEN Header.DeliveryDatePosition = VALUE(Enum.AttributeStationing.InHeader)
		|			THEN Header.DeliveryEndDate
		|		ELSE FilteredInventory.DeliveryEndDate
		|	END,
		|	FilteredInventory.CompanyLogoFile
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SalesInvoices.Ref AS Ref,
		|	SalesInvoices.Date AS RefDate,
		|	InvoiceData.Ref AS Invoice,
		|	InvoiceData.Date AS Date,
		|	InvoiceData.Number AS Number,
		|	TableIssuedInvoices.Products AS Products,
		|	SUM(TableIssuedInvoices.Total - TableIssuedInvoices.VATAmount) AS Amount,
		|	TableIssuedInvoices.VATRate AS VATRate,
		|	SUM(TableIssuedInvoices.VATAmount) AS VATAmount,
		|	SUM(TableIssuedInvoices.Total) AS Total
		|INTO IssuedInvoices
		|FROM
		|	SalesInvoices AS SalesInvoices
		|		INNER JOIN Document.SalesInvoice.IssuedInvoices AS TableIssuedInvoices
		|		ON SalesInvoices.Ref = TableIssuedInvoices.Ref
		|		INNER JOIN Document.SalesInvoice AS InvoiceData
		|		ON (TableIssuedInvoices.Invoice = InvoiceData.Ref)
		|
		|GROUP BY
		|	TableIssuedInvoices.VATRate,
		|	TableIssuedInvoices.Products,
		|	InvoiceData.Ref,
		|	SalesInvoices.Ref,
		|	SalesInvoices.Date,
		|	InvoiceData.Date,
		|	InvoiceData.Number
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	IssuedInvoices.Ref AS Ref,
		|	IssuedInvoices.RefDate AS RefDate,
		|	IssuedInvoices.Invoice AS Invoice
		|INTO IssuedInvoicesForPayments
		|FROM
		|	IssuedInvoices AS IssuedInvoices
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Tabular.Ref AS Ref,
		|	Tabular.DocumentNumber AS DocumentNumber,
		|	Tabular.DocumentDate AS DocumentDate,
		|	Tabular.Company AS Company,
		|	Tabular.CompanyVATNumber AS CompanyVATNumber,
		|	Tabular.Counterparty AS Counterparty,
		|	Tabular.Contract AS Contract,
		|	Tabular.ShippingAddress AS ShippingAddress,
		|	Tabular.CounterpartyContactPerson AS CounterpartyContactPerson,
		|	Tabular.AmountIncludesVAT AS AmountIncludesVAT,
		|	Tabular.DocumentCurrency AS DocumentCurrency,
		|	Tabular.Comment AS Comment,
		|	Tabular.LineNumber AS LineNumber,
		|	Tabular.SKU AS SKU,
		|	Tabular.ProductDescription AS ProductDescription,
		|	Tabular.ContentUsed AS ContentUsed,
		|	Tabular.UseSerialNumbers AS UseSerialNumbers,
		|	Tabular.Quantity AS Quantity,
		|	Tabular.Price AS Price,
		|	Tabular.VATRate AS VATRate,
		|	Tabular.Amount AS Amount,
		|	Tabular.VATAmount AS VATAmount,
		|	Tabular.Total AS Total,
		|	Tabular.PureAmount AS PureAmount,
		|	Tabular.PureVATAmount AS PureVATAmount,
		|	Tabular.PureTotal AS PureTotal,
		|	Tabular.Products AS Products,
		|	Tabular.CharacteristicDescription AS CharacteristicDescription,
		|	Tabular.BatchDescription AS BatchDescription,
		|	Tabular.ConnectionKey AS ConnectionKey,
		|	Tabular.Characteristic AS Characteristic,
		|	Tabular.MeasurementUnit AS MeasurementUnit,
		|	Tabular.Batch AS Batch,
		|	Tabular.UOM AS UOM,
		|	Tabular.StructuralUnit AS StructuralUnit,
		|	Tabular.DeliveryOption AS DeliveryOption,
		|	Tabular.ProvideEPD AS ProvideEPD,
		|	Tabular.BundleProduct AS BundleProduct,
		|	Tabular.BundleCharacteristic AS BundleCharacteristic,
		|	Tabular.IsRegisterDeliveryDate AS IsRegisterDeliveryDate,
		|	Tabular.DeliveryDatePosition AS DeliveryDatePosition,
		|	Tabular.DeliveryDatePeriod AS DeliveryDatePeriod,
		|	Tabular.DeliveryStartDate AS DeliveryStartDate,
		|	Tabular.DeliveryEndDate AS DeliveryEndDate,
		|	Tabular.CompanyLogoFile AS CompanyLogoFile
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
		|	MAX(CompanyVATNumber),
		|	MAX(Counterparty),
		|	MAX(Contract),
		|	MAX(ShippingAddress),
		|	MAX(CounterpartyContactPerson),
		|	MAX(AmountIncludesVAT),
		|	MAX(DocumentCurrency),
		|	MAX(Comment),
		|	COUNT(LineNumber),
		|	SUM(Quantity),
		|	SUM(Amount),
		|	SUM(VATAmount),
		|	SUM(Total),
		|	MAX(StructuralUnit),
		|	MAX(DeliveryOption),
		|	MAX(ProvideEPD),
		|	MAX(IsRegisterDeliveryDate),
		|	MAX(DeliveryDatePosition),
		|	MAX(DeliveryDatePeriod),
		|	MAX(DeliveryStartDate),
		|	MAX(DeliveryEndDate),
		|	MAX(CompanyLogoFile)
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
		|SELECT
		|	Tabular.Ref AS Ref,
		|	CASE
		|		WHEN Tabular.ReverseCharge
		|				AND Tabular.VATRate = VALUE(Catalog.VATRates.ZeroRate)
		|			THEN &ReverseChargeAppliesRate
		|		ELSE Tabular.VATRate
		|	END AS VATRate,
		|	SUM(Tabular.PureAmount) AS Amount,
		|	SUM(Tabular.PureVATAmount) AS VATAmount,
		|	SUM(Tabular.PureTotal) AS Total
		|FROM
		|	Tabular AS Tabular
		|
		|GROUP BY
		|	Tabular.Ref,
		|	CASE
		|		WHEN Tabular.ReverseCharge
		|				AND Tabular.VATRate = VALUE(Catalog.VATRates.ZeroRate)
		|			THEN &ReverseChargeAppliesRate
		|		ELSE Tabular.VATRate
		|	END
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
		|			AND FilteredInventory.Price = Tabular.Price
		|			AND FilteredInventory.VATRate = Tabular.VATRate
		|			AND (NOT Tabular.ContentUsed)
		|			AND FilteredInventory.Ref = Tabular.Ref
		|			AND FilteredInventory.Characteristic = Tabular.Characteristic
		|			AND FilteredInventory.MeasurementUnit = Tabular.MeasurementUnit
		|			AND FilteredInventory.Batch = Tabular.Batch
		|		INNER JOIN Document.SalesInvoice.SerialNumbers AS SalesInvoiceSerialNumbers
		|			LEFT JOIN Catalog.SerialNumbers AS SerialNumbers
		|			ON SalesInvoiceSerialNumbers.SerialNumber = SerialNumbers.Ref
		|		ON (SalesInvoiceSerialNumbers.ConnectionKey = FilteredInventory.ConnectionKey)
		|			AND FilteredInventory.Ref = SalesInvoiceSerialNumbers.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	MAX(SalesInvoiceEarlyPaymentDiscounts.Period) AS Period,
		|	MAX(SalesInvoiceEarlyPaymentDiscounts.Discount) AS Discount,
		|	MAX(SalesInvoiceEarlyPaymentDiscounts.DiscountAmount) AS DiscountAmount,
		|	SalesInvoiceEarlyPaymentDiscounts.DueDate AS DueDate,
		|	SalesInvoiceEarlyPaymentDiscounts.Ref AS Ref
		|FROM
		|	Document.SalesInvoice.EarlyPaymentDiscounts AS SalesInvoiceEarlyPaymentDiscounts
		|		INNER JOIN Tabular AS Tabular
		|		ON SalesInvoiceEarlyPaymentDiscounts.Ref = Tabular.Ref
		|
		|GROUP BY
		|	SalesInvoiceEarlyPaymentDiscounts.DueDate,
		|	SalesInvoiceEarlyPaymentDiscounts.Ref
		|
		|ORDER BY
		|	DueDate
		|TOTALS BY
		|	Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	IssuedInvoices.Ref AS Ref,
		|	IssuedInvoices.Invoice AS Invoice,
		|	IssuedInvoices.Date AS Date,
		|	IssuedInvoices.Number AS Number,
		|	SUM(IssuedInvoices.Amount) AS Amount,
		|	IssuedInvoices.VATRate AS VATRate,
		|	SUM(IssuedInvoices.VATAmount) AS VATAmount,
		|	SUM(IssuedInvoices.Total) AS Total
		|FROM
		|	IssuedInvoices AS IssuedInvoices
		|
		|GROUP BY
		|	IssuedInvoices.VATRate,
		|	IssuedInvoices.Ref,
		|	IssuedInvoices.Number,
		|	IssuedInvoices.Invoice,
		|	IssuedInvoices.Date
		|
		|ORDER BY
		|	Date
		|TOTALS
		|	MAX(Date),
		|	MAX(Number),
		|	SUM(Amount),
		|	SUM(VATAmount),
		|	SUM(Total)
		|BY
		|	Ref,
		|	Invoice
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	IssuedInvoicesForPayments.Ref AS Ref,
		|	IssuedInvoicesForPayments.Invoice AS Invoice,
		|	AccountsReceivable.Period AS Date,
		|	SUM(AccountsReceivable.Amount) AS Amount
		|FROM
		|	IssuedInvoicesForPayments AS IssuedInvoicesForPayments
		|		INNER JOIN AccumulationRegister.AccountsReceivable AS AccountsReceivable
		|		ON IssuedInvoicesForPayments.Invoice = AccountsReceivable.Document
		|WHERE
		|	AccountsReceivable.RecordType = VALUE(AccumulationRecordType.Expense)
		|	AND AccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|	AND (AccountsReceivable.Period < IssuedInvoicesForPayments.RefDate
		|			OR AccountsReceivable.Period = IssuedInvoicesForPayments.RefDate
		|				AND AccountsReceivable.Recorder < IssuedInvoicesForPayments.Ref)
		|
		|GROUP BY
		|	AccountsReceivable.Period,
		|	IssuedInvoicesForPayments.Ref,
		|	IssuedInvoicesForPayments.Invoice
		|
		|ORDER BY
		|	Date";
		
		#EndRegion
		
		Query.SetParameter("ObjectsArray", ObjectsArray);
		
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
	
	Query.SetParameter("ReverseChargeAppliesRate", NStr("en = 'Reverse charge applies'; ru = 'Применяется реверсивный НДС';pl = 'Dotyczy odwrotnego obciążenia';es_ES = 'Inversión impositiva aplica';es_CO = 'Inversión impositiva aplica';tr = 'Karşı ödemeli ücret uygulanır';it = 'Si applica l''inversione contabile';de = 'Steuerschuldumkehr angewendet'", LanguageCode));
	
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	
	ResultArrayOffset = 6 * Number(Not PrintAnnexParams.AnnexPrintMode);
	
	Header						= ResultArray[ResultArrayOffset].Select(QueryResultIteration.ByGroups);
	SalesOrdersNumbersHeaderSel	= ResultArray[ResultArrayOffset + 1].Select(QueryResultIteration.ByGroups);
	TaxesHeaderSel				= ResultArray[ResultArrayOffset + 2].Select(QueryResultIteration.ByGroups);
	SerialNumbersSel			= ResultArray[ResultArrayOffset + 3].Select();
	EarlyPaymentDiscountSel		= ResultArray[ResultArrayOffset + 4].Select(QueryResultIteration.ByGroups);
	IssuedInvoicesRefSel		= ResultArray[ResultArrayOffset + 5].Select(QueryResultIteration.ByGroups);
	InvoicesPaymentsSel			= ResultArray[ResultArrayOffset + 6].Select();
	
	// Bundles 
	TableColumns = ResultArray[ResultArrayOffset].Columns;
	// End Bundles
	
	Template = PrintManagement.PrintFormTemplate("Document.SalesInvoice.PF_MXL_ClosingInvoice", LanguageCode);
	
	While Header.Next() Do
		
		If Not FirstDocument And Not PrintAnnexParams.AnnexPrintMode Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		If Not PrintAnnexParams.AnnexPrintMode Then
			FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		EndIf;
		
		#Region PrintClosingInvoiceTitleArea
		
		If PrintAnnexParams.AnnexPrintMode Then
			
			TitleArea = Template.GetArea("AnnexTitle");
			TitleArea.Parameters.DocumentNumber = Header.DocumentNumber;
			TitleArea.Parameters.DocumentDate = Format(Header.DocumentDate, "DLF=D");
			
			If PrintAnnexParams.FirstBlock Then
				SpreadsheetDocument.Put(TitleArea);
			EndIf;
			
		Else
			
			StringNameLineArea = "Title";
			TitleArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
			TitleArea.Parameters.Fill(Header);
			
			If DisplayPrintOption Then 
				TitleArea.Parameters.OriginalDuplicate = ?(PrintParams.OriginalCopy,
					NStr("en = 'ORIGINAL'; ru = 'ОРИГИНАЛ';pl = 'ORYGINAŁ';es_ES = 'ORIGINAL';es_CO = 'ORIGINAL';tr = 'ORİJİNAL';it = 'ORIGINALE';de = 'ORIGINAL'", LanguageCode),
					NStr("en = 'COPY'; ru = 'КОПИЯ';pl = 'KOPIA';es_ES = 'COPIA';es_CO = 'COPIA';tr = 'KOPYA';it = 'COPIA';de = 'KOPIE'", LanguageCode));
			EndIf;
				
			IsPictureLogo = False;
			If ValueIsFilled(Header.CompanyLogoFile) Then
				
				PictureData = AttachedFiles.GetBinaryFileData(Header.CompanyLogoFile);
				If ValueIsFilled(PictureData) Then
					
					TitleArea.Drawings.Logo.Picture = New Picture(PictureData);
					
					IsPictureLogo = True;
					
				EndIf;
				
			Else
				
				TitleArea.Drawings.Delete(TitleArea.Drawings.Logo);
				
			EndIf;
			
			SpreadsheetDocument.Put(TitleArea);
			
			DriveServer.AddPartAdditionalToAreaWithShift(
				Template,
				SpreadsheetDocument,
				CounterShift,
				StringNameLineArea,
				"PartAdditional" + StringNameLineArea);
			
			If IsPictureLogo Then
				DriveServer.MakeShiftPictureWithShift(SpreadsheetDocument.Drawings.Logo, CounterShift - 1);
			EndIf;
			
		EndIf;
		
		#EndRegion
		
		#Region PrintClosingInvoiceCompanyInfoArea
		
		If Not PrintAnnexParams.AnnexPrintMode Then
			
			StringNameLineArea = "CompanyInfo";
			CompanyInfoArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
			
			InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
				Header.Company, Header.DocumentDate, , , Header.CompanyVATNumber, LanguageCode);
			CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
			BarcodesInPrintForms.AddBarcodeToTableDocument(CompanyInfoArea, Header.Ref);
			
			SpreadsheetDocument.Put(CompanyInfoArea);
			
			DriveServer.AddPartAdditionalToAreaWithShift(
				Template,
				SpreadsheetDocument,
				CounterShift,
				StringNameLineArea,
				"PartAdditional" + StringNameLineArea);
			
			IsPictureBarcode = GetFunctionalOption("UseBarcodesInPrintForms");
			If IsPictureBarcode Then
				DriveServer.MakeShiftPictureWithShift(SpreadsheetDocument.Drawings.DocumentBarcode, CounterShift - 1);
			EndIf;
			
		EndIf;
		
		#EndRegion
		
		#Region PrintClosingInvoiceCounterpartyInfoArea
		
		If Not PrintAnnexParams.AnnexPrintMode Then
			
			StringNameLineArea = "CounterpartyInfo";
			CounterpartyInfoArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
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
			TitleParameters.Insert("TitleShipDate", NStr("en = 'Shipment date'; ru = 'Дата отгрузки';pl = 'Data wysyłki';es_ES = 'Fecha de envío';es_CO = 'Fecha de envío';tr = 'Sevkiyat tarihi';it = 'Data di spedizione';de = 'Versanddatum'", LanguageCode));
			
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
							" %1 ", NStr("en = 'dated'; ru = 'от';pl = 'z dn.';es_ES = 'fechado';es_CO = 'fechado';tr = 'tarih';it = 'con data';de = 'datiert'", LanguageCode))
						+ Format(SalesOrdersNumbersSel.Date, "DLF=D"));
					
				EndDo;
				
				CounterpartyInfoArea.Parameters.SalesOrders = StringFunctionsClientServer.StringFromSubstringArray(SalesOrdersNumbersArray, ", ");
				
			EndIf;
			
			SpreadsheetDocument.Put(CounterpartyInfoArea);
			
			DriveServer.AddPartAdditionalToAreaWithShift(
				Template,
				SpreadsheetDocument,
				CounterShift,
				StringNameLineArea,
				"PartAdditional" + StringNameLineArea);
			
		EndIf;
		
		#EndRegion
		
		#Region PrintEPDArea
		
		If Not PrintAnnexParams.AnnexPrintMode Then
			
			EarlyPaymentDiscountSel.Reset();
			If EarlyPaymentDiscountSel.FindNext(New Structure("Ref", Header.Ref)) Then
				
				StringNameLineArea = "EPDSection";
				EPDArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
				
				EPDArray = New Array;
				
				EPDSel = EarlyPaymentDiscountSel.Select();
				While EPDSel.Next() Do
					
					EPDArray.Add(StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'A discount of %1% of the full price applies if payment is made within %2 days of the invoice date. Discounted total %3 %4.'; ru = 'Скидка в размере %1% от полной цены применяется в случае, когда платеж производится не позднее %2 дней от даты инвойса. Общая сумма скидки %3 %4.';pl = 'Rabat %1% od pełnej ceny obowiązuje, jeśli płatność nastąpi w ciągu %2 dni daty wystawienia faktury. Łączna kwota rabatu%3 %4.';es_ES = 'El descuento del %1% de precio completo se aplica si el pago se ha hecho en %2 días de la fecha de la factura. Descuento total %3 %4.';es_CO = 'El descuento del %1% de precio completo se aplica si el pago se ha hecho en %2 días de la fecha de la factura. Descuento total %3 %4.';tr = 'Fatura tarihinden itibaren %2 gün içinde ödeme yapılırsa, tam fiyat üzerinden %1% indirim uygulanır. İndirimli toplam %3 %4.';it = 'Uno sconto di %1% del prezzo pieno viene applicato se il pagamento è fatto entro %2 giorni dalla data di fatturazione. Totale scontato %3 %4.';de = 'Bei Zahlung innerhalb von %2 Tagen ab Rechnungsdatum gilt ein Rabatt von %1% auf den vollen Preis. Diskontierte Summe %3 %4.'",
							LanguageCode),
						EPDSel.Discount,
						EPDSel.Period,
						Format(Header.Total - EPDSel.DiscountAmount,"NFD=2"),
						Header.DocumentCurrency));
					
				EndDo;
				
				If Header.ProvideEPD = Enums.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment
					OR Header.ProvideEPD = Enums.VariantsOfProvidingEPD.PaymentDocument Then
					
					EPDArray.Add(NStr("en = 'No credit note will be issued.'; ru = 'Кредитовое авизо не будет создано.';pl = 'Nie zostanie wystawiona nota kredytowa.';es_ES = 'La nota de créditos será enviada.';es_CO = 'La nota de créditos será enviada.';tr = 'Alacak dekontu düzenlenmeyecek.';it = 'Nessuna nota di credito verrà emessa.';de = 'Eine Gutschrift erfolgt nicht.'", LanguageCode));
					
					If Header.ProvideEPD = Enums.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment Then
						EPDArray.Add(NStr("en = 'On payment you may only recover the VAT actually paid.'; ru = 'При оплате вы можете восстановить только реально выплаченный НДС.';pl = 'Przy płatności można odzyskać jedynie podatek VAT faktycznie zapłacony.';es_ES = 'Al efectuar el pago, sólo podrá recuperar el IVA actualmente pagado.';es_CO = 'Al efectuar el pago, sólo podrá recuperar el IVA actualmente pagado.';tr = 'Ödeme sırasında yalnızca gerçekten ödenen KDV''yi iade alabilirsiniz.';it = 'Sul pagamento è possibile solamente recuperare l''IVA effettivamente pagata.';de = 'Bei Zahlung können Sie nur die tatsächlich bezahlte USt. zurückfordern.'", LanguageCode));
					EndIf;
					
				EndIf;
				
				EPDArea.Parameters.EPD = StringFunctionsClientServer.StringFromSubstringArray(EPDArray, " ");
				
				SpreadsheetDocument.Put(EPDArea);
				
				DriveServer.AddPartAdditionalToAreaWithShift(
					Template,
					SpreadsheetDocument,
					CounterShift,
					StringNameLineArea,
					"PartAdditional" + StringNameLineArea);
				
			EndIf;
			
		EndIf;
		
		#EndRegion
		
		#Region PrintClosingInvoiceTotalsAndTaxesAreaPrefill
		
		TotalsAndTaxesAreasArray = New Array;
		
		TotalsArea = New SpreadsheetDocument;
		
		// Start
		LineTotalAreaStart = Template.GetArea("LineTotal|PartStartLine");
		TotalsArea.Put(LineTotalAreaStart);
		
		// Price
		LineTotalAreaPrice = Template.GetArea("LineTotal|PartPriceLine");
		TotalsArea.Join(LineTotalAreaPrice);
		
		// Discount 
		If StructureFlags.IsDiscount Then
			LineTotalAreaDiscount = Template.GetArea("LineTotal|PartDiscountLine");
			TotalsArea.Join(LineTotalAreaDiscount);
		EndIf;
		
		// Net amount
		If StructureFlags.IsNetAmount Then
			LineTotalAreaNetAmount = Template.GetArea("LineTotal|PartNetAmountLine");
			LineTotalAreaNetAmount.Parameters.Fill(Header);
			TotalsArea.Join(LineTotalAreaNetAmount);
		EndIf;
		
		// Tax
		If StructureSecondFlags.IsTax Then
			LineTotalAreaVAT = Template.GetArea("LineTotal|PartVATLine");
			LineTotalAreaVAT.Parameters.Fill(Header);
			TotalsArea.Join(LineTotalAreaVAT);
		EndIf;
		
		// Total
		If StructureFlags.IsLineTotal Then
			LineTotalAreaTotal = Template.GetArea("LineTotal|PartTotalLine");
			LineTotalAreaTotal.Parameters.Fill(Header);
			TotalsArea.Join(LineTotalAreaTotal);
		EndIf;
		
		TotalsAndTaxesAreasArray.Add(TotalsArea);
		
		If PrintAnnexParams.AnnexPrintMode Then
			InvoicesOverlappingAreaName = "|InvoicesAreaForAnnex";
		Else
			InvoicesOverlappingAreaName = "";
		EndIf;
		
		// Invoices header
		If PrintAnnexParams.AnnexPrintMode Then
			InvoicesHeaderArea = Template.GetArea("InvoicesHeader|InvoicesAreaForAnnex");
		Else
			InvoicesHeaderArea = Template.GetArea("InvoicesHeader");
		EndIf;
		TotalsAndTaxesAreasArray.Add(InvoicesHeaderArea);
		
		TotalPaymentAmount = 0;
		
		IssuedInvoicesRefSel.Reset();
		If IssuedInvoicesRefSel.FindNext(New Structure("Ref", Header.Ref)) Then
			
			IssuedInvoicesInvoiceSel = IssuedInvoicesRefSel.Select(QueryResultIteration.ByGroups);
			While IssuedInvoicesInvoiceSel.Next() Do
				
				If PrintAnnexParams.AnnexPrintMode Then
					InvoicesLineArea = Template.GetArea("InvoicesLine|InvoicesAreaForAnnex");
				Else
					InvoicesLineArea = Template.GetArea("InvoicesLine");
				EndIf;
				InvoicesLineArea.Parameters.InvoiceDate = IssuedInvoicesInvoiceSel.Date;
				InvoicesLineArea.Parameters.InvoiceNumber = IssuedInvoicesInvoiceSel.Number;
				
				IsFirst = True;
				IssuedInvoicesSel = IssuedInvoicesInvoiceSel.Select();
				While IssuedInvoicesSel.Next() Do
					DriveServer.AddValueLineToParameter(InvoicesLineArea.Parameters.Amount,
						IssuedInvoicesSel.Amount, IsFirst, "NFD=2; NZ=-");
					DriveServer.AddValueLineToParameter(InvoicesLineArea.Parameters.VATRate,
						IssuedInvoicesSel.VATRate, IsFirst);
					DriveServer.AddValueLineToParameter(InvoicesLineArea.Parameters.VATAmount,
						IssuedInvoicesSel.VATAmount, IsFirst, "NFD=2; NZ=-");
					DriveServer.AddValueLineToParameter(InvoicesLineArea.Parameters.Total,
						IssuedInvoicesSel.Total, IsFirst, "NFD=2; NZ=-");
					IsFirst = False;
				EndDo;
				
				IsFirst = True;
				InvoicesPaymentsSel.Reset();
				SearchStructure = New Structure("Ref, Invoice", Header.Ref, IssuedInvoicesInvoiceSel.Invoice);
				While InvoicesPaymentsSel.FindNext(SearchStructure) Do
					DriveServer.AddValueLineToParameter(InvoicesLineArea.Parameters.PaymentDate,
						InvoicesPaymentsSel.Date, IsFirst, "DLF=D");
					DriveServer.AddValueLineToParameter(InvoicesLineArea.Parameters.PaymentAmount,
						InvoicesPaymentsSel.Amount, IsFirst, "NFD=2; NZ=-");
					IsFirst = False;
					TotalPaymentAmount = TotalPaymentAmount + InvoicesPaymentsSel.Amount;
				EndDo;
				
				TotalsAndTaxesAreasArray.Add(InvoicesLineArea);
				
			EndDo;
			
			InvoicesTotalsArea = New SpreadsheetDocument;
			If PrintAnnexParams.AnnexPrintMode Then
				InvoicesTotalsAreaStart = Template.GetArea("InvoicesTotals|InvoicesAreaForAnnex");
			Else
				InvoicesTotalsAreaStart = Template.GetArea("InvoicesTotals|PartStartInvoicesTotals");
			EndIf;
			InvoicesTotalsAreaStart.Parameters.TotalTitle = NStr("en = 'TOTAL'; ru = 'ИТОГО';pl = 'RAZEM';es_ES = 'TOTAL';es_CO = 'TOTAL';tr = 'TOPLAM';it = 'TOTALE';de = 'INSGESAMT'");
			InvoicesTotalsAreaStart.Parameters.DocumentCurrency = Header.DocumentCurrency;
			InvoicesTotalsAreaStart.Parameters.Amount = Format(IssuedInvoicesRefSel.Amount, "NFD=2; NZ=-");
			InvoicesTotalsAreaStart.Parameters.VATAmount = Format(IssuedInvoicesRefSel.VATAmount, "NFD=2; NZ=-");
			InvoicesTotalsAreaStart.Parameters.Total = Format(IssuedInvoicesRefSel.Total, "NFD=2; NZ=-");
			If Not PrintAnnexParams.AnnexPrintMode Then
				InvoicesTotalsAreaStart.Parameters.PaymentAmount = Format(TotalPaymentAmount, "NFD=2; NZ=-");
			EndIf;
			InvoicesTotalsArea.Put(InvoicesTotalsAreaStart);
			If Not PrintAnnexParams.AnnexPrintMode Then
				DriveServer.AddPartAdditionalToAreaWithShift(Template,
					InvoicesTotalsArea, CounterShift + 2, "InvoicesTotals", "PartAdditionalInvoicesTotals");
			EndIf;
			
			TotalsAndTaxesAreasArray.Add(InvoicesTotalsArea);
			
		EndIf;
		
		// "Taxes" are actually closing invoice itself's data
		TaxesHeaderSel.Reset();
		If TaxesHeaderSel.FindNext(New Structure("Ref", Header.Ref)) Then
			
			IsFirst = True;
			TaxesSel = TaxesHeaderSel.Select();
			While TaxesSel.Next() Do
				
				TaxSectionLineArea = Template.GetArea("InvoicesLine");
				If IsFirst Then
					TaxSectionLineArea.Parameters.InvoiceDate = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'CLOSING INVOICE (%1)'; ru = 'ЗАКЛЮЧИТЕЛЬНЫЙ ИНВОЙС (%1)';pl = 'FAKTURA KOŃCOWA (%1)';es_ES = 'FACTURA DE CIERRE (%1)';es_CO = 'FACTURA DE CIERRE (%1)';tr = 'KAPANIŞ FATURASI (%1)';it = 'FATTURA DI CHIUSURA (%1)';de = 'ABSCHLUSSRECHNUNG (%1)'"), Header.DocumentCurrency);
					FirstRowTitleArea = TaxSectionLineArea.Area(1, 2, 1, 3);
					FirstRowTitleArea.Font = New Font(FirstRowTitleArea.Font, , , True);
					FirstRowTitleArea.Merge();
				EndIf;
				TaxSectionLineArea.Parameters.Amount = Format(TaxesSel.Amount, "NFD=2; NZ=-");
				TaxSectionLineArea.Parameters.VATRate = TaxesSel.VATRate;
				TaxSectionLineArea.Parameters.VATAmount = Format(TaxesSel.VATAmount, "NFD=2; NZ=-");
				TaxSectionLineArea.Parameters.Total = Format(TaxesSel.Total, "NFD=2; NZ=-");
				TotalsAndTaxesAreasArray.Add(TaxSectionLineArea);
				IsFirst = False;
				
			EndDo;
			
			If Not PrintAnnexParams.AnnexPrintMode Then
				
				InvoicesTotalsArea = New SpreadsheetDocument;
				InvoicesTotalsAreaStart = Template.GetArea("InvoicesTotals|PartStartInvoicesTotals");
				InvoicesTotalsAreaStart.Parameters.TotalTitle = NStr("en = 'TOTAL'; ru = 'ИТОГО';pl = 'RAZEM';es_ES = 'TOTAL';es_CO = 'TOTAL';tr = 'TOPLAM';it = 'TOTALE';de = 'INSGESAMT'");
				InvoicesTotalsAreaStart.Parameters.DocumentCurrency = Header.DocumentCurrency;
				InvoicesTotalsAreaStart.Parameters.Amount = Format(TaxesHeaderSel.Amount, "NFD=2; NZ=-");
				InvoicesTotalsAreaStart.Parameters.VATAmount = Format(TaxesHeaderSel.VATAmount, "NFD=2; NZ=-");
				InvoicesTotalsAreaStart.Parameters.Total = Format(TaxesHeaderSel.Total, "NFD=2; NZ=-");
				InvoicesTotalsArea.Put(InvoicesTotalsAreaStart);
				DriveServer.AddPartAdditionalToAreaWithShift(Template,
					InvoicesTotalsArea, CounterShift + 2, "InvoicesTotals", "PartAdditionalInvoicesTotals");
				
				TotalsAndTaxesAreasArray.Add(InvoicesTotalsArea);
				
			EndIf;
			
		EndIf;
		
		// Remaining balance and Footer
		If Not PrintAnnexParams.AnnexPrintMode Then
			
			InvoicesTotalsArea = New SpreadsheetDocument;
			InvoicesTotalsAreaStart = Template.GetArea("InvoicesTotals|PartStartInvoicesTotals");
			InvoicesTotalsAreaStart.Parameters.TotalTitle = NStr("en = 'REMAINING BALANCE'; ru = 'ОСТАТОК';pl = 'POZOSTAŁE SALDO';es_ES = 'SALDO RESTANTE';es_CO = 'SALDO RESTANTE';tr = 'KALAN BAKİYE';it = 'SALDO RIMANENTE';de = 'RESTBETRAG'");
			InvoicesTotalsAreaStart.Parameters.DocumentCurrency = Header.DocumentCurrency;
			InvoicesTotalsAreaStart.Parameters.PaymentAmount = Format(Header.Total - TotalPaymentAmount, "NFD=2; NZ=-");
			InvoicesTotalsAreaStart.Area(1, 2, 1, 7).Merge();
			InvoicesTotalsArea.Put(InvoicesTotalsAreaStart);
			DriveServer.AddPartAdditionalToAreaWithShift(Template,
				InvoicesTotalsArea, CounterShift + 2, "InvoicesTotals", "PartAdditionalInvoicesTotals");
			
			TotalsAndTaxesAreasArray.Add(InvoicesTotalsArea);
			
			InvoicesFooterArea = Template.GetArea("InvoicesFooter");
			
			If Header.IsRegisterDeliveryDate 
				And Header.DeliveryDatePosition = Enums.AttributeStationing.InHeader Then
				If Header.DeliveryDatePeriod = Enums.DeliveryDatePeriod.Date Then
					InvoicesFooterArea.Parameters.LabelDeliveryDate	= NStr("en = 'Delivery date'; ru = 'Дата доставки';pl = 'Data dostawy';es_ES = 'Fecha de entrega';es_CO = 'Fecha de entrega';tr = 'Teslimat tarihi';it = 'Data di consegna';de = 'Lieferdatum'", LanguageCode);
					InvoicesFooterArea.Parameters.DeliveryDate		= Format(Header.DeliveryStartDate, "DLF=D");
				Else
					InvoicesFooterArea.Parameters.LabelDeliveryDate	= NStr("en = 'Delivery period'; ru = 'Срок доставки';pl = 'Okres dostawy';es_ES = 'Período de entrega';es_CO = 'Período de entrega';tr = 'Teslimat dönemi';it = 'Periodo di consegna';de = 'Lieferzeitraum'", LanguageCode);
					InvoicesFooterArea.Parameters.DeliveryDate		= StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = '%1 - %2'; ru = '%1 - %2';pl = '%1 - %2';es_ES = '%1 - %2';es_CO = '%1 - %2';tr = '%1 - %2';it = '%1 - %2';de = '%1 - %2'", LanguageCode),
						Format(Header.DeliveryStartDate, "DLF=D"),
						Format(Header.DeliveryEndDate, "DLF=D"));
				EndIf;
			Else 
				InvoicesFooterArea.Parameters.LabelDeliveryDate	= "";
				InvoicesFooterArea.Parameters.DeliveryDate		= "";
			EndIf;
			
			InvoicesFooterArea.Parameters.PaymentTerms = PaymentTermsServer.TitleStagesOfPayment(Header.Ref);
			If ValueIsFilled(InvoicesFooterArea.Parameters.PaymentTerms) Then
				InvoicesFooterArea.Parameters.PaymentTermsTitle = PaymentTermsServer.PaymentTermsPrintTitle();
			EndIf;
			
			TotalsAndTaxesAreasArray.Add(InvoicesFooterArea);
			
		EndIf;
		
		#EndRegion
		
		#Region PrintClosingInvoiceLinesArea
		
		CounterBundle = DriveServer.GetCounterBundle();
		
		If PrintAnnexParams.AnnexPrintMode Then
			
			AnnexProductTitleArea = Template.GetArea("AnnexProductTitle|PartStartAnnexProductTitle");
			AnnexProductTitleArea.Parameters.Product = PrintAnnexParams.Products;
			SpreadsheetDocument.Put(AnnexProductTitleArea);
			DriveServer.AddPartAdditionalToAreaWithShift(Template,
				SpreadsheetDocument, CounterShift, "AnnexProductTitle", "PartAdditionalAnnexProductTitle");
			
		EndIf;
		
		// Start
		
		LineHeaderAreaStart	 = Template.GetArea("LineHeader|PartStartLine");
		LineSectionAreaStart = Template.GetArea("LineSection|PartStartLine");
		
		If DisplayPrintOption 
			And PrintParams.CodesPosition <> Enums.CodesPositionInPrintForms.SeparateColumn Then
			
			LineHeaderAreaStart.Parameters.LabelSKU = NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'", LanguageCode);
			LineHeaderAreaStart.Parameters.LabelDescription = "";
			LineHeaderAreaStart.Area(1, 2, 1, 4).Merge();
			
		Else
			
			LineHeaderAreaStart.Parameters.LabelSKU = NStr("en = 'Item #'; ru = 'Артикул';pl = 'Pozycja nr';es_ES = 'Artículo #';es_CO = 'Artículo #';tr = 'Madde #';it = 'Articolo #';de = 'Artikel Nr.'", LanguageCode);
			LineHeaderAreaStart.Parameters.LabelDescription = NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'", LanguageCode);
			
		EndIf;
		
		If Header.IsRegisterDeliveryDate 
			And Header.DeliveryDatePosition = Enums.AttributeStationing.InTabularSection Then
			
			If Header.DeliveryDatePeriod = Enums.DeliveryDatePeriod.Date Then
				LineHeaderAreaStart.Parameters.LabelDeliveryDate	= NStr("en = 'Delivery date'; ru = 'Дата доставки';pl = 'Data dostawy';es_ES = 'Fecha de entrega';es_CO = 'Fecha de entrega';tr = 'Teslimat tarihi';it = 'Data di consegna';de = 'Lieferdatum'", LanguageCode);
			Else
				LineHeaderAreaStart.Parameters.LabelDeliveryDate	= NStr("en = 'Delivery period'; ru = 'Срок доставки';pl = 'Okres dostawy';es_ES = 'Período de entrega';es_CO = 'Período de entrega';tr = 'Teslimat dönemi';it = 'Periodo di consegna';de = 'Lieferzeitraum'", LanguageCode);
			EndIf;
			
		Else
			
			LineHeaderAreaStart.Parameters.LabelDeliveryDate	= "";
			
		EndIf;
		
		SpreadsheetDocument.Put(LineHeaderAreaStart);
		
		// Price
		LineHeaderAreaPrice = Template.GetArea("LineHeader|PartPriceLine");
		LineSectionAreaPrice = Template.GetArea("LineSection|PartPriceLine");
			
		SpreadsheetDocument.Join(LineHeaderAreaPrice);
		
		// Discount 
		If StructureFlags.IsDiscount Then
			
			LineHeaderAreaDiscount = Template.GetArea("LineHeader|PartDiscountLine");
			LineSectionAreaDiscount = Template.GetArea("LineSection|PartDiscountLine");
			
			SpreadsheetDocument.Join(LineHeaderAreaDiscount);
			
		EndIf;
		
		// Net amount
		If StructureFlags.IsNetAmount Then
			
			LineHeaderAreaNetAmount = Template.GetArea("LineHeader|PartNetAmountLine");
			LineSectionAreaNetAmount = Template.GetArea("LineSection|PartNetAmountLine");
			
			SpreadsheetDocument.Join(LineHeaderAreaNetAmount);
			
		EndIf;
		
		// Tax
		
		If StructureSecondFlags.IsTax Then
			
			LineHeaderAreaVAT		= Template.GetArea("LineHeader|PartVATLine");
			LineSectionAreaVAT		= Template.GetArea("LineSection|PartVATLine");
			
			SpreadsheetDocument.Join(LineHeaderAreaVAT);
			
		EndIf;
		
		// Total
		
		If StructureFlags.IsLineTotal Then
			
			LineHeaderAreaTotal		= Template.GetArea("LineHeader|PartTotalLine");
			LineSectionAreaTotal	= Template.GetArea("LineSection|PartTotalLine");
			
			SpreadsheetDocument.Join(LineHeaderAreaTotal);
			
		EndIf;
		
		SeeNextPageArea	= DriveServer.GetAreaDocumentFooters(Template, "SeeNextPage", CounterShift);
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= DriveServer.GetAreaDocumentFooters(Template, "PageNumber", CounterShift);
		
		If PrintAnnexParams.AnnexPrintMode Then
			PageNumber = PrintAnnexParams.PageNumber;
		Else
			PageNumber = 0;
		EndIf;
		
		AreasToBeChecked = New Array;
		
		// Bundles
		TableInventoty = BundlesServer.AssemblyTableByBundles(Header.Ref, Header, TableColumns);
		EmptyColor = LineSectionAreaStart.CurrentArea.TextColor;
		// End Bundles
		
		PricePrecision = PrecisionAppearancetServer.CompanyPrecision(Header.Company);
		
		For Each TabSelection In TableInventoty Do
			
			LineSectionAreaStart	= Template.GetArea("LineSection|PartStartLine");
			
			LineSectionAreaStart.Parameters.Fill(TabSelection);
			
			// Delivery date
			If Header.IsRegisterDeliveryDate 
				And Header.DeliveryDatePosition = Enums.AttributeStationing.InTabularSection Then
				
				If Header.DeliveryDatePeriod = Enums.DeliveryDatePeriod.Date Then
					LineSectionAreaStart.Parameters.DeliveryDate	= Format(TabSelection.DeliveryStartDate, "DLF=D");
				Else
					LineSectionAreaStart.Parameters.DeliveryDate	= StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = '%1 - %2'; ru = '%1 - %2';pl = '%1 - %2';es_ES = '%1 - %2';es_CO = '%1 - %2';tr = '%1 - %2';it = '%1 - %2';de = '%1 - %2'", LanguageCode),
						Format(Header.DeliveryStartDate, "DLF=D"),
						Format(Header.DeliveryEndDate, "DLF=D"));
				EndIf;
				
			Else 
				
				LineSectionAreaStart.Parameters.DeliveryDate	= "";
				
			EndIf;
			// End Delivery date
			
			LineSectionAreaPrice.Parameters.Fill(TabSelection);
			LineSectionAreaPrice.Parameters.Price = Format(TabSelection.Price,
				"NFD= " + PricePrecision);
			
			If StructureFlags.IsDiscount Then
				
				If Not TabSelection.DiscountPercent = Undefined Then
					LineSectionAreaDiscount.Parameters.SignPercent = "%";
				Else
					LineSectionAreaDiscount.Parameters.SignPercent = "";
				EndIf;
				
				LineSectionAreaDiscount.Parameters.Fill(TabSelection);
				
			EndIf;
			
			If StructureFlags.IsNetAmount Then
				LineSectionAreaNetAmount.Parameters.Fill(TabSelection);
			EndIf;
			
			If StructureSecondFlags.IsTax Then
				LineSectionAreaVAT.Parameters.Fill(TabSelection);
			EndIf;
			
			If StructureFlags.IsLineTotal Then
				LineSectionAreaTotal.Parameters.Fill(TabSelection);
			EndIf;
			
			DriveClientServer.ComplimentProductDescription(LineSectionAreaStart.Parameters.ProductDescription, TabSelection, SerialNumbersSel);
			// Display selected codes if functional option is turned on.
			If DisplayPrintOption Then
				CodesPresentation = PrintManagementServerCallDrive.GetCodesPresentation(PrintParams, TabSelection.Products);
				If PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.SeparateColumn Then
					LineSectionAreaStart.Parameters.SKU = CodesPresentation;
				ElsIf PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.ProductColumn Then
					LineSectionAreaStart.Parameters.ProductDescription = 
						LineSectionAreaStart.Parameters.ProductDescription + Chars.CR + CodesPresentation;
				EndIf;
				If PrintParams.CodesPosition <> Enums.CodesPositionInPrintForms.SeparateColumn Then
					LineSectionAreaStart.Parameters.SKU = LineSectionAreaStart.Parameters.ProductDescription;
					LineSectionAreaStart.Parameters.ProductDescription = "";
					LineSectionAreaStart.Area(1, 2, 1, 4).Merge();
				EndIf;
			EndIf;
			
			// Bundles
			
			BundleColor =  BundlesServer.GetBundleComponentsColor(TabSelection, EmptyColor);
			
			LineSectionAreaStart.Area(1,1,1,CounterBundle).TextColor = BundleColor;
			LineSectionAreaPrice.CurrentArea.TextColor = BundleColor;
			If StructureFlags.IsDiscount Then
				LineSectionAreaDiscount.CurrentArea.TextColor = BundleColor;
			EndIf;
			If StructureSecondFlags.IsTax Then
				LineSectionAreaVAT.Area(1,1,1,2).TextColor = BundleColor;
			EndIf;
			If StructureFlags.IsNetAmount Then
				LineSectionAreaNetAmount.CurrentArea.TextColor = BundleColor;
			EndIf;
			If StructureFlags.IsLineTotal Then
				LineSectionAreaTotal.CurrentArea.TextColor = BundleColor;
			EndIf;
			
			// End Bundles
			
			AreasToBeChecked.Clear();
			AreasToBeChecked.Add(LineSectionAreaStart);
			If TableInventoty.IndexOf(TabSelection) = TableInventoty.Count() - 1 Then
				For Each Area In TotalsAndTaxesAreasArray Do
					AreasToBeChecked.Add(Area);
				EndDo;
			EndIf;
			AreasToBeChecked.Add(PageNumberArea);
			
			If Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
			
				SpreadsheetDocument.Put(LineSectionAreaStart);
				SpreadsheetDocument.Join(LineSectionAreaPrice);
				If StructureFlags.IsDiscount Then
					SpreadsheetDocument.Join(LineSectionAreaDiscount);
				EndIf;
				If StructureFlags.IsNetAmount Then
					SpreadsheetDocument.Join(LineSectionAreaNetAmount);
				EndIf;
				If StructureSecondFlags.IsTax Then
					SpreadsheetDocument.Join(LineSectionAreaVAT);
				EndIf;
				If StructureFlags.IsLineTotal Then
					SpreadsheetDocument.Join(LineSectionAreaTotal);
				EndIf;
				
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
				
				// Header
				
				SpreadsheetDocument.Put(LineHeaderAreaStart);
				If StructureFlags.IsDiscount Then
					SpreadsheetDocument.Join(LineHeaderAreaDiscount);
				EndIf;
				If StructureSecondFlags.IsTax Then
					SpreadsheetDocument.Join(LineHeaderAreaVAT);
				EndIf;
				If StructureFlags.IsNetAmount Then
					SpreadsheetDocument.Join(LineHeaderAreaNetAmount);
				EndIf;
				If StructureFlags.IsLineTotal Then
					SpreadsheetDocument.Join(LineHeaderAreaTotal);
				EndIf;
				
				// Section
				
				SpreadsheetDocument.Put(LineSectionAreaStart);
				SpreadsheetDocument.Join(LineSectionAreaPrice);
				If StructureFlags.IsDiscount Then
					SpreadsheetDocument.Join(LineSectionAreaDiscount);
				EndIf;
				If StructureFlags.IsNetAmount Then
					SpreadsheetDocument.Join(LineSectionAreaNetAmount);
				EndIf;
				If StructureSecondFlags.IsTax Then
					SpreadsheetDocument.Join(LineSectionAreaVAT);
				EndIf;
				If StructureFlags.IsLineTotal Then
					SpreadsheetDocument.Join(LineSectionAreaTotal);
				EndIf;
				
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		#Region PrintClosingInvoiceTotalsAndTaxesArea
		
		For Each Area In TotalsAndTaxesAreasArray Do
			
			SpreadsheetDocument.Put(Area);
			
		EndDo;
		
		#Region PrintAdditionalAttributes
		If DisplayPrintOption And PrintParams.AdditionalAttributes
			And PrintManagementServerCallDrive.HasAdditionalAttributes(Header.Ref)
			And Not PrintAnnexParams.AnnexPrintMode Then
			
			SpreadsheetDocument.Put(EmptyLineArea);
			
			StringNameLineArea = "AdditionalAttributesStaticHeader";
				
			AddAttribHeader = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
			SpreadsheetDocument.Put(AddAttribHeader);
			
			DriveServer.AddPartAdditionalToAreaWithShift(
				Template,
				SpreadsheetDocument,
				CounterShift,
				StringNameLineArea,
				"PartAdditional" + StringNameLineArea);
			
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
		
		If Not PrintAnnexParams.AnnexPrintMode Or PrintAnnexParams.LastBlock Then
			
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
			
		EndIf;
		
		#EndRegion
		
		#Region PrintClosingInvoicePrintAnnexCall
		
		If Not PrintAnnexParams.AnnexPrintMode And PrintAnnex Then
			
			SpreadsheetDocument.PutHorizontalPageBreak();
			
			PrintAnnexParams.AnnexPrintMode = True;
			PrintAnnexParams.Insert("SpreadsheetDocument", SpreadsheetDocument);
			PrintAnnexParams.Insert("TempTablesManager", Query.TempTablesManager);
			PrintAnnexParams.Insert("Ref", Header.Ref);
			PrintAnnexParams.Insert("PageNumber", 0);
			PrintAnnexParams.Insert("FirstBlock");
			PrintAnnexParams.Insert("LastBlock");
			
			Query.Text = 
			"SELECT DISTINCT
			|	Tabular.Products AS Products,
			|	Tabular.VATRate AS VATRate
			|FROM
			|	Tabular AS Tabular
			|WHERE
			|	Tabular.Ref = &Ref";
			Query.SetParameter("Ref", Header.Ref);
			
			AnnexBlocksSel = Query.Execute().Select();
			BlocksCounter = 0;
			BlocksCount = AnnexBlocksSel.Count();
			
			While AnnexBlocksSel.Next() Do
				
				BlocksCounter = BlocksCounter + 1;
				PrintAnnexParams.FirstBlock = (BlocksCounter = 1);
				PrintAnnexParams.LastBlock = (BlocksCounter = BlocksCount);
				
				PrintAnnexParams.Insert("Products", AnnexBlocksSel.Products);
				PrintAnnexParams.Insert("VATRate", AnnexBlocksSel.VATRate);
				
				PrintClosingInvoice(ObjectsArray, PrintObjects, TemplateName, PrintParams, PrintAnnex, PrintAnnexParams);
				
			EndDo;
			
			PrintAnnexParams.AnnexPrintMode = False;
			
		EndIf;
		
		#EndRegion
		
		If Not PrintAnnexParams.AnnexPrintMode Then
			PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		EndIf;
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

Function PrintSalesInvoice(ObjectsArray, PrintObjects, TemplateName, PrintParams)
	
	DisplayPrintOption = (PrintParams <> Undefined);
	
	StructureFlags			= DriveServer.GetStructureFlags(DisplayPrintOption, PrintParams);
	StructureSecondFlags	= DriveServer.GetStructureSecondFlags(DisplayPrintOption, PrintParams);
	CounterShift			= DriveServer.GetCounterShift(StructureFlags);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_SalesInvoice";
	
	Query = New Query();
	
	#Region PrintSalesInvoiceQueryText
	
	Query.Text = 
	"SELECT ALLOWED
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Number AS Number,
	|	SalesInvoice.Date AS Date,
	|	SalesInvoice.Company AS Company,
	|	SalesInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	SalesInvoice.Counterparty AS Counterparty,
	|	SalesInvoice.Contract AS Contract,
	|	SalesInvoice.ShippingAddress AS ShippingAddress,
	|	SalesInvoice.ContactPerson AS ContactPerson,
	|	SalesInvoice.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesInvoice.DocumentCurrency AS DocumentCurrency,
	|	CAST(SalesInvoice.Comment AS STRING(1024)) AS Comment,
	|	SalesInvoice.Order AS Order,
	|	SalesInvoice.SalesOrderPosition AS SalesOrderPosition,
	|	SalesInvoice.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT) AS ReverseCharge,
	|	SalesInvoice.StructuralUnit AS StructuralUnit,
	|	SalesInvoice.DeliveryOption AS DeliveryOption,
	|	SalesInvoice.ProvideEPD AS ProvideEPD,
	|	SalesInvoice.DeliveryStartDate AS DeliveryStartDate,
	|	SalesInvoice.DeliveryEndDate AS DeliveryEndDate,
	|	SalesInvoice.DeliveryDatePeriod AS DeliveryDatePeriod,
	|	SalesInvoice.DeliveryDatePosition AS DeliveryDatePosition,
	|	SalesInvoice.IsRegisterDeliveryDate AS IsRegisterDeliveryDate,
	|	CASE
	|		WHEN SalesInvoice.OperationKind = VALUE(Enum.OperationTypesSalesInvoice.ZeroInvoice)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ZeroInvoice
	|INTO SalesInvoices
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
	|	SalesInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	SalesInvoice.Counterparty AS Counterparty,
	|	SalesInvoice.Contract AS Contract,
	|	SalesInvoice.ShippingAddress AS ShippingAddress,
	|	CASE
	|		WHEN SalesInvoice.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN SalesInvoice.ContactPerson
	|		WHEN CounterpartyContracts.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN CounterpartyContracts.ContactPerson
	|		ELSE Counterparties.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	SalesInvoice.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesInvoice.DocumentCurrency AS DocumentCurrency,
	|	ISNULL(SalesOrder.Number, """") AS SalesOrderNumber,
	|	ISNULL(SalesOrder.Date, DATETIME(1, 1, 1)) AS SalesOrderDate,
	|	SalesInvoice.Comment AS Comment,
	|	SalesInvoice.ReverseCharge AS ReverseCharge,
	|	SUM(ISNULL(SalesInvoicePrepayment.AmountDocCur, 0)) AS Paid,
	|	SalesInvoice.StructuralUnit AS StructuralUnit,
	|	SalesInvoice.DeliveryOption AS DeliveryOption,
	|	SalesInvoice.ProvideEPD AS ProvideEPD,
	|	SalesInvoice.IsRegisterDeliveryDate AS IsRegisterDeliveryDate,
	|	SalesInvoice.DeliveryDatePosition AS DeliveryDatePosition,
	|	SalesInvoice.DeliveryDatePeriod AS DeliveryDatePeriod,
	|	SalesInvoice.DeliveryStartDate AS DeliveryStartDate,
	|	SalesInvoice.DeliveryEndDate AS DeliveryEndDate,
	|	SalesInvoice.ZeroInvoice AS ZeroInvoice
	|INTO Header
	|FROM
	|	SalesInvoices AS SalesInvoice
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON SalesInvoice.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON SalesInvoice.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN Document.SalesOrder AS SalesOrder
	|		ON SalesInvoice.Order = SalesOrder.Ref
	|			AND (SalesInvoice.SalesOrderPosition = VALUE(Enum.AttributeStationing.InHeader))
	|		LEFT JOIN Document.SalesInvoice.Prepayment AS SalesInvoicePrepayment
	|		ON SalesInvoice.Ref = SalesInvoicePrepayment.Ref
	|
	|GROUP BY
	|	SalesInvoice.Number,
	|	SalesInvoice.Date,
	|	SalesInvoice.Counterparty,
	|	SalesInvoice.Company,
	|	SalesInvoice.CompanyVATNumber,
	|	SalesInvoice.Ref,
	|	SalesInvoice.Comment,
	|	ISNULL(SalesOrder.Date, DATETIME(1, 1, 1)),
	|	ISNULL(SalesOrder.Number, """"),
	|	SalesInvoice.DocumentCurrency,
	|	SalesInvoice.AmountIncludesVAT,
	|	SalesInvoice.ShippingAddress,
	|	CASE
	|		WHEN SalesInvoice.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN SalesInvoice.ContactPerson
	|		WHEN CounterpartyContracts.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN CounterpartyContracts.ContactPerson
	|		ELSE Counterparties.ContactPerson
	|	END,
	|	SalesInvoice.ReverseCharge,
	|	SalesInvoice.Contract,
	|	SalesInvoice.StructuralUnit,
	|	SalesInvoice.DeliveryOption,
	|	SalesInvoice.ProvideEPD,
	|	SalesInvoice.IsRegisterDeliveryDate,
	|	SalesInvoice.DeliveryDatePosition,
	|	SalesInvoice.DeliveryDatePeriod,
	|	SalesInvoice.DeliveryStartDate,
	|	SalesInvoice.DeliveryEndDate,
	|	SalesInvoice.ZeroInvoice
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
	|	SalesInvoiceInventory.Reserve AS Reserve,
	|	SalesInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN SalesInvoiceInventory.Quantity = 0
	|			THEN 0
	|		ELSE CASE
	|				WHEN SalesInvoiceInventory.DiscountMarkupPercent > 0
	|						OR SalesInvoiceInventory.AutomaticDiscountAmount > 0
	|					THEN (SalesInvoiceInventory.Price * SalesInvoiceInventory.Quantity - SalesInvoiceInventory.AutomaticDiscountAmount - SalesInvoiceInventory.Price * SalesInvoiceInventory.Quantity * SalesInvoiceInventory.DiscountMarkupPercent / 100) / SalesInvoiceInventory.Quantity
	|				ELSE SalesInvoiceInventory.Price
	|			END
	|	END AS Price,
	|	SalesInvoiceInventory.Price AS PurePrice,
	|	SalesInvoiceInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SalesInvoiceInventory.Total - SalesInvoiceInventory.VATAmount AS Amount,
	|	SalesInvoiceInventory.VATRate AS VATRate,
	|	SalesInvoiceInventory.VATAmount AS VATAmount,
	|	SalesInvoiceInventory.Total AS Total,
	|	SalesInvoiceInventory.Order AS Order,
	|	SalesInvoiceInventory.Content AS Content,
	|	SalesInvoiceInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	SalesInvoiceInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	SalesInvoiceInventory.ConnectionKey AS ConnectionKey,
	|	SalesInvoiceInventory.BundleProduct AS BundleProduct,
	|	SalesInvoiceInventory.BundleCharacteristic AS BundleCharacteristic,
	|	SalesInvoiceInventory.DeliveryStartDate AS DeliveryStartDate,
	|	SalesInvoiceInventory.DeliveryEndDate AS DeliveryEndDate,
	|	CASE
	|		WHEN SalesInvoiceInventory.DiscountMarkupPercent + SalesInvoiceInventory.AutomaticDiscountsPercent > 100
	|			THEN 100
	|		ELSE SalesInvoiceInventory.DiscountMarkupPercent + SalesInvoiceInventory.AutomaticDiscountsPercent
	|	END AS DiscountPercent,
	|	SalesInvoiceInventory.Amount AS PureAmount,
	|	ISNULL(VATRates.Rate, 0) AS NumberVATRate,
	|	CAST(SalesInvoiceInventory.Quantity * SalesInvoiceInventory.Price - SalesInvoiceInventory.Amount AS NUMBER(15, 2)) AS DiscountAmount,
	|	Companies.LogoFile AS CompanyLogoFile
	|INTO FilteredInventory
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		LEFT JOIN SalesInvoices AS SalesInvoices
	|			LEFT JOIN Catalog.Companies AS Companies
	|			ON SalesInvoices.Company = Companies.Ref
	|		ON SalesInvoiceInventory.Ref = SalesInvoices.Ref
	|		LEFT JOIN Catalog.VATRates AS VATRates
	|		ON SalesInvoiceInventory.VATRate = VATRates.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	FilteredInventory.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Counterparty AS Counterparty,
	|	Header.Contract AS Contract,
	|	Header.ShippingAddress AS ShippingAddress,
	|	Header.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.Comment AS Comment,
	|	Header.ReverseCharge AS ReverseCharge,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	(CAST(ISNULL(FilteredInventory.Content, """") AS STRING(1024))) <> """" AS ContentUsed,
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
	|	ISNULL(CatalogProducts.UseSerialNumbers, FALSE) AS UseSerialNumbers,
	|	MIN(FilteredInventory.ConnectionKey) AS ConnectionKey,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(ISNULL(FilteredInventory.Quantity, 0)) AS Quantity,
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN ISNULL(FilteredInventory.PurePrice, 0)
	|		ELSE ISNULL(FilteredInventory.Price, 0)
	|	END AS Price,
	|	FilteredInventory.DiscountMarkupPercent AS DiscountRate,
	|	SUM(FilteredInventory.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
	|	SUM(ISNULL(FilteredInventory.Amount, 0)) AS Amount,
	|	SUM(CAST(FilteredInventory.PurePrice * CASE
	|				WHEN CatalogProducts.IsFreightService
	|					THEN FilteredInventory.Quantity
	|				ELSE 0
	|			END * CASE
	|				WHEN Header.AmountIncludesVAT
	|					THEN 1 / (1 + FilteredInventory.NumberVATRate / 100)
	|				ELSE 1
	|			END AS NUMBER(15, 2))) AS Freight,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	SUM(ISNULL(FilteredInventory.Total, 0)) AS Total,
	|	SUM(CASE
	|			WHEN &IsDiscount
	|				THEN CASE
	|						WHEN Header.AmountIncludesVAT
	|							THEN CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|						ELSE CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice AS NUMBER(15, 2))
	|					END
	|			ELSE CASE
	|					WHEN Header.AmountIncludesVAT
	|						THEN CAST((FilteredInventory.Quantity * FilteredInventory.PurePrice - FilteredInventory.DiscountAmount) / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|					ELSE CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice - FilteredInventory.DiscountAmount AS NUMBER(15, 2))
	|				END
	|		END * CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN 0
	|			ELSE 1
	|		END) AS Subtotal,
	|	ISNULL(SalesOrder.Number, Header.SalesOrderNumber) AS SalesOrderNumber,
	|	ISNULL(SalesOrder.Date, Header.SalesOrderDate) AS SalesOrderDate,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	MAX(Header.Paid) AS Paid,
	|	Header.StructuralUnit AS StructuralUnit,
	|	Header.DeliveryOption AS DeliveryOption,
	|	CatalogProducts.IsFreightService AS IsFreightService,
	|	Header.ProvideEPD AS ProvideEPD,
	|	FilteredInventory.BundleProduct AS BundleProduct,
	|	FilteredInventory.BundleCharacteristic AS BundleCharacteristic,
	|	Header.IsRegisterDeliveryDate AS IsRegisterDeliveryDate,
	|	Header.DeliveryDatePosition AS DeliveryDatePosition,
	|	Header.DeliveryDatePeriod AS DeliveryDatePeriod,
	|	CASE
	|		WHEN Header.DeliveryDatePosition = VALUE(Enum.AttributeStationing.InHeader)
	|			THEN Header.DeliveryStartDate
	|		ELSE FilteredInventory.DeliveryStartDate
	|	END AS DeliveryStartDate,
	|	CASE
	|		WHEN Header.DeliveryDatePosition = VALUE(Enum.AttributeStationing.InHeader)
	|			THEN Header.DeliveryEndDate
	|		ELSE FilteredInventory.DeliveryEndDate
	|	END AS DeliveryEndDate,
	|	FilteredInventory.DiscountPercent AS DiscountPercent,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST(FilteredInventory.DiscountAmount / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|			ELSE FilteredInventory.DiscountAmount
	|		END) AS DiscountAmount,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST(FilteredInventory.PureAmount / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|			ELSE FilteredInventory.PureAmount
	|		END) AS NetAmount,
	|	FilteredInventory.PurePrice AS PurePrice
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		LEFT JOIN FilteredInventory AS FilteredInventory
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
	|		LEFT JOIN Document.SalesOrder AS SalesOrder
	|		ON (FilteredInventory.Order = SalesOrder.Ref)
	|			AND (Header.SalesOrderNumber = """")
	|WHERE
	|	(Header.ZeroInvoice
	|			OR FilteredInventory.Products IS NOT NULL )
	|
	|GROUP BY
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	Header.Ref,
	|	Header.Counterparty,
	|	Header.Contract,
	|	Header.ShippingAddress,
	|	Header.CounterpartyContactPerson,
	|	Header.AmountIncludesVAT,
	|	Header.DocumentCurrency,
	|	Header.Comment,
	|	Header.ReverseCharge,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	ISNULL(SalesOrder.Date, Header.SalesOrderDate),
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	ISNULL(SalesOrder.Number, Header.SalesOrderNumber),
	|	ISNULL(CatalogProducts.UseSerialNumbers, FALSE),
	|	FilteredInventory.VATRate,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	(CAST(ISNULL(FilteredInventory.Content, """") AS STRING(1024))) <> """",
	|	FilteredInventory.Price,
	|	FilteredInventory.DiscountMarkupPercent,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	Header.StructuralUnit,
	|	Header.DeliveryOption,
	|	CatalogProducts.IsFreightService,
	|	Header.ProvideEPD,
	|	FilteredInventory.BundleProduct,
	|	FilteredInventory.BundleCharacteristic,
	|	Header.IsRegisterDeliveryDate,
	|	Header.DeliveryDatePosition,
	|	Header.DeliveryDatePeriod,
	|	CASE
	|		WHEN Header.DeliveryDatePosition = VALUE(Enum.AttributeStationing.InHeader)
	|			THEN Header.DeliveryStartDate
	|		ELSE FilteredInventory.DeliveryStartDate
	|	END,
	|	CASE
	|		WHEN Header.DeliveryDatePosition = VALUE(Enum.AttributeStationing.InHeader)
	|			THEN Header.DeliveryEndDate
	|		ELSE FilteredInventory.DeliveryEndDate
	|	END,
	|	FilteredInventory.DiscountPercent,
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN ISNULL(FilteredInventory.PurePrice, 0)
	|		ELSE ISNULL(FilteredInventory.Price, 0)
	|	END,
	|	FilteredInventory.PurePrice,
	|	FilteredInventory.CompanyLogoFile
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	FilteredInventory.Ref AS Ref,
	|	SUM(FilteredInventory.Total) AS TotalForCount
	|INTO TotalTable
	|FROM
	|	FilteredInventory AS FilteredInventory
	|
	|GROUP BY
	|	FilteredInventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyVATNumber AS CompanyVATNumber,
	|	Tabular.Counterparty AS Counterparty,
	|	Tabular.Contract AS Contract,
	|	Tabular.ShippingAddress AS ShippingAddress,
	|	Tabular.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Tabular.AmountIncludesVAT AS AmountIncludesVAT,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Price AS Price,
	|	Tabular.Amount AS Amount,
	|	Tabular.Freight AS FreightTotal,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	Tabular.DiscountAmount AS DiscountAmount,
	|	CASE
	|		WHEN Tabular.AutomaticDiscountAmount = 0
	|			THEN Tabular.DiscountRate
	|		WHEN Tabular.Subtotal = 0
	|			THEN 0
	|		ELSE CAST((Tabular.Subtotal - Tabular.Amount) / Tabular.Subtotal * 100 AS NUMBER(15, 2))
	|	END AS DiscountRate,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	Tabular.Paid AS Paid,
	|	TotalTable.TotalForCount - Tabular.Paid AS TotalDue,
	|	Tabular.StructuralUnit AS StructuralUnit,
	|	Tabular.DeliveryOption AS DeliveryOption,
	|	Tabular.ProvideEPD AS ProvideEPD,
	|	Tabular.BundleProduct AS BundleProduct,
	|	Tabular.BundleCharacteristic AS BundleCharacteristic,
	|	Tabular.IsRegisterDeliveryDate AS IsRegisterDeliveryDate,
	|	Tabular.DeliveryDatePosition AS DeliveryDatePosition,
	|	Tabular.DeliveryDatePeriod AS DeliveryDatePeriod,
	|	Tabular.DeliveryStartDate AS DeliveryStartDate,
	|	Tabular.DeliveryEndDate AS DeliveryEndDate,
	|	Tabular.DiscountPercent AS DiscountPercent,
	|	Tabular.NetAmount AS NetAmount,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile
	|FROM
	|	Tabular AS Tabular
	|		LEFT JOIN TotalTable AS TotalTable
	|		ON Tabular.Ref = TotalTable.Ref
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyVATNumber),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(ShippingAddress),
	|	MAX(CounterpartyContactPerson),
	|	MAX(AmountIncludesVAT),
	|	MAX(DocumentCurrency),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(FreightTotal),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	SUM(DiscountAmount),
	|	MAX(Paid),
	|	MAX(TotalDue),
	|	MAX(StructuralUnit),
	|	MAX(DeliveryOption),
	|	MAX(ProvideEPD),
	|	MAX(IsRegisterDeliveryDate),
	|	MAX(DeliveryDatePosition),
	|	MAX(DeliveryDatePeriod),
	|	MAX(DeliveryStartDate),
	|	MAX(DeliveryEndDate),
	|	MAX(CompanyLogoFile)
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
	|SELECT
	|	Tabular.Ref AS Ref,
	|	CASE
	|		WHEN Tabular.ReverseCharge
	|				AND Tabular.VATRate = VALUE(Catalog.VATRates.ZeroRate)
	|			THEN &ReverseChargeAppliesRate
	|		ELSE Tabular.VATRate
	|	END AS VATRate,
	|	SUM(Tabular.Amount) AS Amount,
	|	SUM(Tabular.VATAmount) AS VATAmount
	|FROM
	|	Tabular AS Tabular
	|
	|GROUP BY
	|	Tabular.Ref,
	|	CASE
	|		WHEN Tabular.ReverseCharge
	|				AND Tabular.VATRate = VALUE(Catalog.VATRates.ZeroRate)
	|			THEN &ReverseChargeAppliesRate
	|		ELSE Tabular.VATRate
	|	END
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
	|			AND FilteredInventory.DiscountMarkupPercent = Tabular.DiscountRate
	|			AND FilteredInventory.PurePrice = Tabular.PurePrice
	|			AND FilteredInventory.VATRate = Tabular.VATRate
	|			AND (NOT Tabular.ContentUsed)
	|			AND FilteredInventory.Ref = Tabular.Ref
	|			AND FilteredInventory.Characteristic = Tabular.Characteristic
	|			AND FilteredInventory.MeasurementUnit = Tabular.MeasurementUnit
	|			AND FilteredInventory.Batch = Tabular.Batch
	|		INNER JOIN Document.SalesInvoice.SerialNumbers AS SalesInvoiceSerialNumbers
	|			LEFT JOIN Catalog.SerialNumbers AS SerialNumbers
	|			ON SalesInvoiceSerialNumbers.SerialNumber = SerialNumbers.Ref
	|		ON (SalesInvoiceSerialNumbers.ConnectionKey = FilteredInventory.ConnectionKey)
	|			AND FilteredInventory.Ref = SalesInvoiceSerialNumbers.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(Tabular.LineNumber) AS LineNumber,
	|	Tabular.Ref AS Ref,
	|	SUM(Tabular.Quantity) AS Quantity
	|FROM
	|	Tabular AS Tabular
	|WHERE
	|	NOT Tabular.IsFreightService
	|
	|GROUP BY
	|	Tabular.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	MAX(SalesInvoiceEarlyPaymentDiscounts.Period) AS Period,
	|	MAX(SalesInvoiceEarlyPaymentDiscounts.Discount) AS Discount,
	|	MAX(SalesInvoiceEarlyPaymentDiscounts.DiscountAmount) AS DiscountAmount,
	|	SalesInvoiceEarlyPaymentDiscounts.DueDate AS DueDate,
	|	SalesInvoiceEarlyPaymentDiscounts.Ref AS Ref
	|FROM
	|	Document.SalesInvoice.EarlyPaymentDiscounts AS SalesInvoiceEarlyPaymentDiscounts
	|		INNER JOIN Tabular AS Tabular
	|		ON SalesInvoiceEarlyPaymentDiscounts.Ref = Tabular.Ref
	|
	|GROUP BY
	|	SalesInvoiceEarlyPaymentDiscounts.DueDate,
	|	SalesInvoiceEarlyPaymentDiscounts.Ref
	|
	|ORDER BY
	|	DueDate
	|TOTALS BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesInvoices.Ref AS Ref,
	|	ISNULL(AccountingPolicySliceLast.InvoiceTotalDue, VALUE(Enum.UseOfOptionalPrintSections.Use)) AS InvoiceTotalDue,
	|	ISNULL(AccountingPolicySliceLast.AccountBalance, VALUE(Enum.UseOfOptionalPrintSections.DoNotUse)) AS AccountBalance,
	|	ISNULL(AccountingPolicySliceLast.Overdue, VALUE(Enum.UseOfOptionalPrintSections.DoNotUse)) AS Overdue
	|FROM
	|	SalesInvoices AS SalesInvoices
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(
	|				,
	|				Company IN
	|					(SELECT
	|						SalesInvoices.Company AS Company
	|					FROM
	|						SalesInvoices AS SalesInvoices)) AS AccountingPolicySliceLast
	|		ON SalesInvoices.Company = AccountingPolicySliceLast.Company";
	
	#EndRegion
	
	AccBalanceQuery = New Query();
	AccBalanceQuery.Parameters.Insert("Period");
	AccBalanceQuery.Parameters.Insert("Company");
	AccBalanceQuery.Parameters.Insert("Counterparty");
	
	#Region AccBalanceQueryText
	
	AccBalanceQuery.Text =
	"SELECT ALLOWED
	|	AccountsReceivableBalance.Document.DocumentCurrency AS DocumentCurrency,
	|	SUM(AccountsReceivableBalance.AmountCurBalance) AS AccountBalance
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			&Period,
	|			Company = &Company
	|				AND Counterparty = &Counterparty) AS AccountsReceivableBalance
	|
	|GROUP BY
	|	AccountsReceivableBalance.Document.DocumentCurrency";
	
	#EndRegion 	
	
	OverdueQuery = New Query();
	OverdueQuery.Parameters.Insert("Period");
	OverdueQuery.Parameters.Insert("Company");
	OverdueQuery.Parameters.Insert("Counterparty");
	OverdueQuery.Parameters.Insert("Contract");
	OverdueQuery.Parameters.Insert("DocumentDate");
	
	#Region OverdueQueryText 
	
	OverdueQuery.Text =	
	"SELECT ALLOWED
	|	CAST(AccountsReceivableBalance.Document AS Document.SalesInvoice) AS Document,
	|	BEGINOFPERIOD(AccountsReceivableBalance.Document.Date, DAY) AS DocumentDate,
	|	CAST(AccountsReceivableBalance.Document AS Document.SalesInvoice).DocumentCurrency AS DocumentCurrency,
	|	AccountsReceivableBalance.AmountCurBalance AS AmountCurBalance
	|INTO AccountingPayableBalance
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			&Period,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND Contract = &Contract
	|				AND Document REFS Document.SalesInvoice) AS AccountsReceivableBalance
	|
	|INDEX BY
	|	Document,
	|	DocumentDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountingPayableBalance.Document AS Document,
	|	AccountingPayableBalance.DocumentCurrency AS DocumentCurrency,
	|	AccountingPayableBalance.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN AccountingPayableBalance.Document.SetPaymentTerms
	|			THEN ISNULL(SalesInvoicePaymentCalendar.PaymentAmount, 0) + ISNULL(SalesInvoicePaymentCalendar.PaymentVATAmount, 0)
	|		ELSE AccountingPayableBalance.AmountCurBalance
	|	END AS PaymentTotal
	|INTO PaymentCalendar
	|FROM
	|	AccountingPayableBalance AS AccountingPayableBalance
	|		LEFT JOIN Document.SalesInvoice.PaymentCalendar AS SalesInvoicePaymentCalendar
	|		ON AccountingPayableBalance.Document = SalesInvoicePaymentCalendar.Ref
	|			AND &DocumentDate <= SalesInvoicePaymentCalendar.PaymentDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentCalendar.Document AS Document,
	|	PaymentCalendar.DocumentCurrency AS DocumentCurrency,
	|	MAX(PaymentCalendar.AmountCurBalance) - SUM(PaymentCalendar.PaymentTotal) AS Overdue
	|INTO DocumentsOverdue
	|FROM
	|	PaymentCalendar AS PaymentCalendar
	|
	|GROUP BY
	|	PaymentCalendar.Document,
	|	PaymentCalendar.DocumentCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentsOverdue.DocumentCurrency AS DocumentCurrency,
	|	SUM(DocumentsOverdue.Overdue) AS Overdue
	|FROM
	|	DocumentsOverdue AS DocumentsOverdue
	|
	|GROUP BY
	|	DocumentsOverdue.DocumentCurrency";
	
	#EndRegion  
	
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
	
	Query.SetParameter("ObjectsArray", ObjectsArray);
	Query.SetParameter("ReverseChargeAppliesRate", NStr("en = 'Reverse charge applies'; ru = 'Применяется реверсивный НДС';pl = 'Dotyczy odwrotnego obciążenia';es_ES = 'Inversión impositiva aplica';es_CO = 'Inversión impositiva aplica';tr = 'Karşı ödemeli ücret uygulanır';it = 'Applicare l''inversione di caricamento';de = 'Steuerschuldumkehr angewendet'", LanguageCode));
	Query.SetParameter("IsPriceBeforeDiscount", StructureSecondFlags.IsPriceBeforeDiscount);
	Query.SetParameter("IsDiscount", StructureFlags.IsDiscount);
	
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	
	Header						= ResultArray[5].Select(QueryResultIteration.ByGroupsWithHierarchy);
	SalesOrdersNumbersHeaderSel	= ResultArray[6].Select(QueryResultIteration.ByGroupsWithHierarchy);
	TaxesHeaderSel				= ResultArray[7].Select(QueryResultIteration.ByGroupsWithHierarchy);
	SerialNumbersSel			= ResultArray[8].Select();
	TotalLineNumber				= ResultArray[9].Unload();
	EarlyPaymentDiscountSel		= ResultArray[10].Select(QueryResultIteration.ByGroupsWithHierarchy);
	AccountingPolicyPrintForms	= ResultArray[11].Unload();
	
	// Bundles 
	TableColumns = ResultArray[5].Columns;
	// End Bundles
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_SalesInvoice";
		
		Template = PrintManagement.PrintFormTemplate("Document.SalesInvoice.PF_MXL_SalesInvoice", LanguageCode);
		
		#Region PrintSalesInvoiceTitleArea
		
		StringNameLineArea = "Title";
		TitleArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
		TitleArea.Parameters.Fill(Header);
		
		If DisplayPrintOption Then 
			TitleArea.Parameters.OriginalDuplicate = ?(PrintParams.OriginalCopy,
				NStr("en = 'ORIGINAL'; ru = 'ОРИГИНАЛ';pl = 'ORYGINAŁ';es_ES = 'ORIGINAL';es_CO = 'ORIGINAL';tr = 'ORİJİNAL';it = 'ORIGINALE';de = 'ORIGINAL'", LanguageCode),
				NStr("en = 'COPY'; ru = 'КОПИЯ';pl = 'KOPIA';es_ES = 'COPIA';es_CO = 'COPIA';tr = 'KOPYALA';it = 'COPIA';de = 'KOPIE'", LanguageCode));
		EndIf;
			
		IsPictureLogo = False;
		If ValueIsFilled(Header.CompanyLogoFile) Then
			
			PictureData = AttachedFiles.GetBinaryFileData(Header.CompanyLogoFile);
			If ValueIsFilled(PictureData) Then
				
				TitleArea.Drawings.Logo.Picture = New Picture(PictureData);
				
				IsPictureLogo = True;
				
			EndIf;
			
		Else
			
			TitleArea.Drawings.Delete(TitleArea.Drawings.Logo);
			
		EndIf;
		
		SpreadsheetDocument.Put(TitleArea);
		
		DriveServer.AddPartAdditionalToAreaWithShift(
			Template,
			SpreadsheetDocument,
			CounterShift,
			StringNameLineArea,
			"PartAdditional" + StringNameLineArea);
		
		If IsPictureLogo Then
			DriveServer.MakeShiftPictureWithShift(SpreadsheetDocument.Drawings.Logo, CounterShift - 1);
		EndIf;
		
		#EndRegion
		
		#Region PrintSalesInvoiceCompanyInfoArea
		
		StringNameLineArea = "CompanyInfo";
		CompanyInfoArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Company, Header.DocumentDate, , , Header.CompanyVATNumber, LanguageCode);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		BarcodesInPrintForms.AddBarcodeToTableDocument(CompanyInfoArea, Header.Ref);
		
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		DriveServer.AddPartAdditionalToAreaWithShift(
			Template,
			SpreadsheetDocument,
			CounterShift,
			StringNameLineArea,
			"PartAdditional" + StringNameLineArea);
		
		IsPictureBarcode = GetFunctionalOption("UseBarcodesInPrintForms");	
		If IsPictureBarcode Then
			DriveServer.MakeShiftPictureWithShift(SpreadsheetDocument.Drawings.DocumentBarcode, CounterShift - 1);
		EndIf;
		
		#EndRegion
		
		#Region PrintSalesInvoiceCounterpartyInfoArea
		
		StringNameLineArea = "CounterpartyInfo";
		CounterpartyInfoArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
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
		
		If Header.IsRegisterDeliveryDate 
			And Header.DeliveryDatePosition = Enums.AttributeStationing.InHeader Then
			
			If Header.DeliveryDatePeriod = Enums.DeliveryDatePeriod.Date Then
				CounterpartyInfoArea.Parameters.LabelDeliveryDate	= NStr("en = 'Delivery date'; ru = 'Дата доставки';pl = 'Data dostawy';es_ES = 'Fecha de entrega';es_CO = 'Fecha de entrega';tr = 'Teslimat tarihi';it = 'Data di consegna';de = 'Lieferdatum'", LanguageCode);
				CounterpartyInfoArea.Parameters.DeliveryDate		= Format(Header.DeliveryStartDate, "DLF=D");
			Else
				CounterpartyInfoArea.Parameters.LabelDeliveryDate	= NStr("en = 'Delivery period'; ru = 'Срок доставки';pl = 'Okres dostawy';es_ES = 'Período de entrega';es_CO = 'Período de entrega';tr = 'Teslimat dönemi';it = 'Periodo di consegna';de = 'Lieferzeitraum'", LanguageCode);
				CounterpartyInfoArea.Parameters.DeliveryDate		= StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '%1 - %2'; ru = '%1 - %2';pl = '%1 - %2';es_ES = '%1 - %2';es_CO = '%1 - %2';tr = '%1 - %2';it = '%1 - %2';de = '%1 - %2'", LanguageCode),
					Format(Header.DeliveryStartDate, "DLF=D"),
					Format(Header.DeliveryEndDate, "DLF=D"));
			EndIf;
			
		Else 
			
			CounterpartyInfoArea.Parameters.LabelDeliveryDate	= "";
			CounterpartyInfoArea.Parameters.DeliveryDate		= "";
			
		EndIf;
		
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
		
		CounterpartyInfoArea.Parameters.PaymentTerms = PaymentTermsServer.TitleStagesOfPayment(Header.Ref);
		If ValueIsFilled(CounterpartyInfoArea.Parameters.PaymentTerms) Then
			CounterpartyInfoArea.Parameters.PaymentTermsTitle = PaymentTermsServer.PaymentTermsPrintTitle();
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
		
		DriveServer.AddPartAdditionalToAreaWithShift(
			Template,
			SpreadsheetDocument,
			CounterShift,
			StringNameLineArea,
			"PartAdditional" + StringNameLineArea);
		
		#EndRegion
		
		#Region PrintEPDArea
		
		EarlyPaymentDiscountSel.Reset();
		If EarlyPaymentDiscountSel.FindNext(New Structure("Ref", Header.Ref)) Then
			
			StringNameLineArea = "EPDSection";
			EPDArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
			
			EPDArray = New Array;
			
			EPDSel = EarlyPaymentDiscountSel.Select();
			While EPDSel.Next() Do
				
				EPDArray.Add(StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'A discount of %1% of the full price applies if payment is made within %2 days of the invoice date. Discounted total %3 %4.'; ru = 'Скидка в размере %1% от полной цены применяется в случае, когда платеж производится не позднее %2 дней от даты инвойса. Общая сумма скидки %3 %4.';pl = 'Rabat %1% od pełnej ceny obowiązuje, jeśli płatność nastąpi w ciągu %2 dni od daty wystawienia faktury. Rabat łącznie %3 %4.';es_ES = 'El descuento del %1% de precio completo se aplica si el pago se ha hecho en %2 días de la fecha de la factura. Descuento total %3 %4.';es_CO = 'El descuento del %1% de precio completo se aplica si el pago se ha hecho en %2 días de la fecha de la factura. Descuento total %3 %4.';tr = 'Fatura tarihinden itibaren %2 gün içinde ödeme yapılırsa, tam fiyat üzerinden %1% indirimi uygulanır. İndirimli toplamı %3 %4.';it = 'Uno sconto di %1% del prezzo pieno viene applicato se il pagamento è fatto entro %2 giorni dalla data di fatturazione. Totale scontato %3 %4.';de = 'Bei Zahlung innerhalb von %2 Tagen ab Rechnungsdatum gilt ein Rabatt von %1%  auf den vollen Preis. Diskontierte Summe %3 %4.'",
						LanguageCode),
					EPDSel.Discount,
					EPDSel.Period,
					Format(Header.Total - EPDSel.DiscountAmount,"NFD=2"),
					Header.DocumentCurrency));
				
			EndDo;
			
			If Header.ProvideEPD = Enums.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment
				OR Header.ProvideEPD = Enums.VariantsOfProvidingEPD.PaymentDocument Then
				
				EPDArray.Add(NStr("en = 'No credit note will be issued.'; ru = 'Кредитовое авизо не будет создано.';pl = 'Nie zostanie wystawiona nota kredytowa.';es_ES = 'La nota de créditos será enviada.';es_CO = 'La nota de créditos será enviada.';tr = 'Alacak dekontu düzenlenmeyecek.';it = 'Nessuna nota di credito verrà emessa.';de = 'Eine Gutschrift erfolgt nicht.'", LanguageCode));
				
				If Header.ProvideEPD = Enums.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment Then
					EPDArray.Add(NStr("en = 'On payment you may only recover the VAT actually paid.'; ru = 'При оплате вы можете восстановить только реально выплаченный НДС.';pl = 'Przy płatności można odzyskać jedynie podatek VAT faktycznie zapłacony.';es_ES = 'Al efectuar el pago, sólo podrá recuperar el IVA actualmente pagado.';es_CO = 'Al efectuar el pago, sólo podrá recuperar el IVA actualmente pagado.';tr = 'Ödeme sırasında yalnızca gerçekten ödenen KDV''yi iade alabilirsiniz.';it = 'Sul pagamento potete solo recuperare la IVA pagata effettivamente.';de = 'Bei Zahlung können Sie nur die tatsächlich bezahlte USt. zurückfordern.'", LanguageCode));
				EndIf;
				
			EndIf;
			
			EPDArea.Parameters.EPD = StringFunctionsClientServer.StringFromSubstringArray(EPDArray, " ");
			
			SpreadsheetDocument.Put(EPDArea);
			
			DriveServer.AddPartAdditionalToAreaWithShift(
				Template,
				SpreadsheetDocument,
				CounterShift,
				StringNameLineArea,
				"PartAdditional" + StringNameLineArea);
			
		EndIf;
		
		#EndRegion
		
		#Region PrintSalesInvoiceCommentArea
		
		StringNameLineArea = "Comment";
		CommentArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
		CommentArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(CommentArea);
		
		DriveServer.AddPartAdditionalToAreaWithShift(
			Template,
			SpreadsheetDocument,
			CounterShift,
			StringNameLineArea,
			"PartAdditional" + StringNameLineArea);
		
		#EndRegion
		
		#Region PrintSalesInvoiceTotalsAndTaxesAreaPrefill
		
		TotalsAndTaxesAreasArray = New Array;
		TotalsArea			= New SpreadsheetDocument;
		
		StringNameLineTotalArea = ?(StructureFlags.IsDiscount, "LineTotal", "LineTotalWithoutDiscount");
		
		StringNameTotalAreaStart		= ?(StructureFlags.IsDiscount, "PartStartLineTotal", "PartStartLineTotalWithoutDiscount");
		StringNameTotalAreaAdditional	= ?(StructureFlags.IsDiscount, "PartAdditional", "PartAdditionalWithoutDiscount");
		StringNameTotalAreaEnd			= ?(StructureFlags.IsDiscount, "PartEndLineTotal", "PartEndLineTotalWithoutDiscount");
		
		LineTotalArea = Template.GetArea(StringNameLineTotalArea + "|" + StringNameTotalAreaStart);
		LineTotalArea.Parameters.Fill(Header);
		
		SearchStructure = New Structure("Ref", Header.Ref);
		
		SearchArray = TotalLineNumber.FindRows(SearchStructure);
		If SearchArray.Count() > 0 Then
			LineTotalArea.Parameters.Quantity	= SearchArray[0].Quantity;
			LineTotalArea.Parameters.LineNumber	= SearchArray[0].LineNumber;
		Else
			LineTotalArea.Parameters.Quantity	= 0;
			LineTotalArea.Parameters.LineNumber	= 0;
		EndIf;
		
		TotalsArea.Put(LineTotalArea);
			
		DriveServer.AddPartAdditionalToAreaWithShift(
			Template,
			TotalsArea,
			CounterShift + 1,
			StringNameLineTotalArea,
			"PartAdditional" + StringNameLineTotalArea);
			
		LineTotalEndArea = Template.GetArea(StringNameLineTotalArea + "|" + StringNameTotalAreaEnd);
		LineTotalEndArea.Parameters.Fill(Header);
		
		TotalsArea.Join(LineTotalEndArea);
		
		TotalsAndTaxesAreasArray.Add(TotalsArea);
		
		BottomBorderArea = DriveServer.GetAreaDocumentFooters(Template, "BottomBorder", CounterShift);
		
		PutBottomBorder = True;
		
		AccountingPolicySetting = AccountingPolicyPrintForms.FindRows(SearchStructure)[0];
		UseSection = Enums.UseOfOptionalPrintSections.Use;
		
		If AccountingPolicySetting.InvoiceTotalDue = UseSection Then
			
			If PutBottomBorder Then
				TotalsAndTaxesAreasArray.Add(BottomBorderArea);
				PutBottomBorder = False;
			EndIf;
			
			SpreadsheetDocumentLineTotalDue = New SpreadsheetDocument;
			
			StringNameLineArea = "LineTotalDue";
			LineTotalDueArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea); 
			SpreadsheetDocumentLineTotalDue.Put(LineTotalDueArea);
			
			DriveServer.AddPartAdditionalToAreaWithShift(
				Template,
				SpreadsheetDocumentLineTotalDue,
				CounterShift + 1,
				StringNameLineArea,
				"PartAdditional" + StringNameLineArea);
				
			LineTotalDueEndArea = Template.GetArea(StringNameLineArea + "|PartEnd" + StringNameLineArea);
			LineTotalDueEndArea.Parameters.Fill(Header);
			SpreadsheetDocumentLineTotalDue.Join(LineTotalDueEndArea);
			
			TotalsAndTaxesAreasArray.Add(SpreadsheetDocumentLineTotalDue);
			
		EndIf;
		
		If AccountingPolicySetting.AccountBalance = UseSection Then
			
			If PutBottomBorder Then
				TotalsAndTaxesAreasArray.Add(BottomBorderArea);
				PutBottomBorder = False;
			EndIf;
			
			FillPropertyValues(AccBalanceQuery.Parameters, Header);
			AccBalanceQuery.SetParameter("Period", 
				New Boundary(New PointInTime(Header.DocumentDate, Header.Ref), BoundaryType.Including));
				
			AccBalanceSel = AccBalanceQuery.Execute().Select();
			While AccBalanceSel.Next() Do
				
				If AccBalanceSel.AccountBalance >= 0 Then
					
					SpreadsheetDocumentLineAccountBalance = New SpreadsheetDocument;
					
					StringNameLineArea = "LineAccountBalance";
					LineAccountBalanceArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea); 
					SpreadsheetDocumentLineTotalDue.Put(LineAccountBalanceArea);
					
					DriveServer.AddPartAdditionalToAreaWithShift(
						Template,
						SpreadsheetDocumentLineAccountBalance,
						CounterShift + 1,
						StringNameLineTotalArea,
						"PartAdditional" + StringNameLineTotalArea);
					
					LineAccountBalanceEndArea = Template.GetArea(StringNameLineArea + "|PartEnd" + StringNameLineArea);
					LineAccountBalanceEndArea.Parameters.Fill(AccBalanceSel);
					SpreadsheetDocumentLineAccountBalance.Join(LineAccountBalanceEndArea);
					
					TotalsAndTaxesAreasArray.Add(SpreadsheetDocumentLineAccountBalance);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
		If AccountingPolicySetting.Overdue = UseSection Then
			
			FillPropertyValues(OverdueQuery.Parameters, Header);
			OverdueQuery.SetParameter("Period", 
				New Boundary(New PointInTime(Header.DocumentDate, Header.Ref), BoundaryType.Including));
			Overdues = OverdueQuery.Execute().Unload();
			
			If Overdues.Count() And Overdues[0].Overdue >= 0 Then 
				
				SpreadsheetDocumentLineOverdue = New SpreadsheetDocument;
				
				StringNameLineArea = "LineOverdue";
				LineOverdueArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea); 
				SpreadsheetDocumentLineOverdue.Put(LineOverdueArea);
				
				DriveServer.AddPartAdditionalToAreaWithShift(
					Template,
					SpreadsheetDocumentLineOverdue,
					CounterShift + 1,
					StringNameLineTotalArea,
					"PartAdditional" + StringNameLineTotalArea);
				
				LineOverdueEndArea = Template.GetArea(StringNameLineArea + "|PartEnd" + StringNameLineArea);
				LineOverdueEndArea.Parameters.Fill(Overdues[0]);
				SpreadsheetDocumentLineAccountBalance.Join(LineOverdueEndArea);
					
				If PutBottomBorder Then
					TotalsAndTaxesAreasArray.Add(BottomBorderArea);
				EndIf;
				
				TotalsAndTaxesAreasArray.Add(SpreadsheetDocumentLineAccountBalance);
				
			EndIf;
			
		EndIf;
		
		TaxesHeaderSel.Reset();
		If TaxesHeaderSel.FindNext(New Structure("Ref", Header.Ref)) Then
			
			TaxSectionHeaderArea = Template.GetArea("TaxSectionHeader");
			TotalsAndTaxesAreasArray.Add(TaxSectionHeaderArea);
			
			TaxesSel = TaxesHeaderSel.Select();
			While TaxesSel.Next() Do
				
				TaxSectionLineArea = Template.GetArea("TaxSectionLine");
				TaxSectionLineArea.Parameters.Fill(TaxesSel);
				TotalsAndTaxesAreasArray.Add(TaxSectionLineArea);
				
			EndDo;
			
		EndIf;
		
		#EndRegion
		
		#Region PrintSalesInvoiceLinesArea
		
		CounterBundle = DriveServer.GetCounterBundle();
		
		If DisplayPrintOption 
			And PrintParams.CodesPosition <> Enums.CodesPositionInPrintForms.SeparateColumn Then
			
			StringNameLineHeader	= "LineHeaderWithoutCode";
			StringNameLineSection	= "LineSectionWithoutCode";
			
			StringPostfix 			= "LineWithoutCode";
			
		Else
			
			StringNameLineHeader	= "LineHeader";
			StringNameLineSection	= "LineSection";
			
			StringPostfix 			= "Line";
			
		EndIf;
		
		StringNameStartPart		= "PartStart"+StringPostfix;
		StringNamePrice			= ?(StructureSecondFlags.IsPriceBeforeDiscount, "PartPriceBefore", "PartPrice")+StringPostfix;
		StringNameVATPart		= "PartVAT"+StringPostfix;
		StringNameDiscount		= "PartDiscount"+StringPostfix;
		StringNameNetAmount		= "PartNetAmount"+StringPostfix;
		StringNameTotalPart		= "PartTotal"+StringPostfix;
		
		// Start
		
		LineHeaderAreaStart		= Template.GetArea(StringNameLineHeader + "|" + StringNameStartPart);
		LineSectionAreaStart	= Template.GetArea(StringNameLineSection + "|" + StringNameStartPart);
		
		If Header.IsRegisterDeliveryDate 
			And Header.DeliveryDatePosition = Enums.AttributeStationing.InTabularSection Then
			
			If Header.DeliveryDatePeriod = Enums.DeliveryDatePeriod.Date Then
				LineHeaderAreaStart.Parameters.LabelDeliveryDate	= NStr("en = 'Delivery date'; ru = 'Дата доставки';pl = 'Data dostawy';es_ES = 'Fecha de entrega';es_CO = 'Fecha de entrega';tr = 'Teslimat tarihi';it = 'Data di consegna';de = 'Lieferdatum'", LanguageCode);
			Else
				LineHeaderAreaStart.Parameters.LabelDeliveryDate	= NStr("en = 'Delivery period'; ru = 'Срок доставки';pl = 'Okres dostawy';es_ES = 'Período de entrega';es_CO = 'Período de entrega';tr = 'Teslimat dönemi';it = 'Periodo di consegna';de = 'Lieferzeitraum'", LanguageCode);
			EndIf;
			
		Else
			
			LineHeaderAreaStart.Parameters.LabelDeliveryDate	= "";
			
		EndIf;
		
		SpreadsheetDocument.Put(LineHeaderAreaStart);
		
		// Price
		
		LineHeaderAreaPrice = Template.GetArea(StringNameLineHeader + "|" + StringNamePrice);
		LineSectionAreaPrice = Template.GetArea(StringNameLineSection + "|" + StringNamePrice);
			
		SpreadsheetDocument.Join(LineHeaderAreaPrice);
		
		// Discount 
		
		If StructureFlags.IsDiscount Then
			
			LineHeaderAreaDiscount = Template.GetArea(StringNameLineHeader + "|" + StringNameDiscount);
			LineSectionAreaDiscount = Template.GetArea(StringNameLineSection + "|" + StringNameDiscount);
			
			SpreadsheetDocument.Join(LineHeaderAreaDiscount);
			
		EndIf;
		
		// Tax
		
		If StructureSecondFlags.IsTax Then
			
			LineHeaderAreaVAT		= Template.GetArea(StringNameLineHeader + "|" + StringNameVATPart);
			LineSectionAreaVAT		= Template.GetArea(StringNameLineSection + "|" + StringNameVATPart);
			
			SpreadsheetDocument.Join(LineHeaderAreaVAT);
			
		EndIf;
		
		// Net amount
		
		If StructureFlags.IsNetAmount Then
			
			LineHeaderAreaNetAmount = Template.GetArea(StringNameLineHeader + "|" + StringNameNetAmount);
			LineSectionAreaNetAmount = Template.GetArea(StringNameLineSection + "|" + StringNameNetAmount);
			
			SpreadsheetDocument.Join(LineHeaderAreaNetAmount);
			
		EndIf;
		
		// Total
		
		If StructureFlags.IsLineTotal Then
			
			LineHeaderAreaTotal		= Template.GetArea(StringNameLineHeader + "|" + StringNameTotalPart);
			LineSectionAreaTotal	= Template.GetArea(StringNameLineSection + "|" + StringNameTotalPart);
			
			SpreadsheetDocument.Join(LineHeaderAreaTotal);
			
		EndIf;
		
		SeeNextPageArea	= DriveServer.GetAreaDocumentFooters(Template, "SeeNextPage", CounterShift);
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= DriveServer.GetAreaDocumentFooters(Template, "PageNumber", CounterShift);
		
		PageNumber = 0;
		
		AreasToBeChecked = New Array;
		
		// Bundles
		TableInventoty = BundlesServer.AssemblyTableByBundles(Header.Ref, Header, TableColumns, LineTotalArea);
		EmptyColor = LineSectionAreaStart.CurrentArea.TextColor;
		// End Bundles
		
		PricePrecision = PrecisionAppearancetServer.CompanyPrecision(Header.Company);
		
		For Each TabSelection In TableInventoty Do
			
			If TypeOf(TabSelection.FreightTotal) = Type("Number")
				And TabSelection.FreightTotal <> 0 Then
				Continue;
			EndIf;
			
			LineSectionAreaStart.Parameters.Fill(TabSelection);
			
			// Delivery date
			If Header.IsRegisterDeliveryDate 
				And Header.DeliveryDatePosition = Enums.AttributeStationing.InTabularSection Then
				
				If Header.DeliveryDatePeriod = Enums.DeliveryDatePeriod.Date Then
					LineSectionAreaStart.Parameters.DeliveryDate	= Format(TabSelection.DeliveryStartDate, "DLF=D");
				Else
					LineSectionAreaStart.Parameters.DeliveryDate	= StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = '%1 - %2'; ru = '%1 - %2';pl = '%1 - %2';es_ES = '%1 - %2';es_CO = '%1 - %2';tr = '%1 - %2';it = '%1 - %2';de = '%1 - %2'", LanguageCode),
						Format(Header.DeliveryStartDate, "DLF=D"),
						Format(Header.DeliveryEndDate, "DLF=D"));
				EndIf;
				
			Else 
				
				LineSectionAreaStart.Parameters.DeliveryDate	= "";
				
			EndIf;
			// End Delivery date
			
			LineSectionAreaPrice.Parameters.Fill(TabSelection);
			LineSectionAreaPrice.Parameters.Price = Format(TabSelection.Price, "NFD= " + PricePrecision);
			
			If StructureFlags.IsDiscount Then
				
				If Not TabSelection.DiscountPercent = Undefined Then
					LineSectionAreaDiscount.Parameters.SignPercent = "%";
				Else
					LineSectionAreaDiscount.Parameters.SignPercent = "";
				EndIf;
				
				LineSectionAreaDiscount.Parameters.Fill(TabSelection);
				
			EndIf;
			
			If StructureSecondFlags.IsTax Then
				LineSectionAreaVAT.Parameters.Fill(TabSelection);
			EndIf;
			
			If StructureFlags.IsNetAmount Then
				LineSectionAreaNetAmount.Parameters.Fill(TabSelection);
			EndIf;
			
			If StructureFlags.IsLineTotal Then
				LineSectionAreaTotal.Parameters.Fill(TabSelection);
			EndIf;
			
			DriveClientServer.ComplimentProductDescription(LineSectionAreaStart.Parameters.ProductDescription, TabSelection, SerialNumbersSel);
			// Display selected codes if functional option is turned on.
			If DisplayPrintOption Then
				CodesPresentation = PrintManagementServerCallDrive.GetCodesPresentation(PrintParams, TabSelection.Products);
				If PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.SeparateColumn Then
					LineSectionAreaStart.Parameters.SKU = CodesPresentation;
				ElsIf PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.ProductColumn Then
					LineSectionAreaStart.Parameters.ProductDescription = 
						LineSectionAreaStart.Parameters.ProductDescription + Chars.CR + CodesPresentation;
				EndIf;
			EndIf;
			
			// Bundles
			
			BundleColor =  BundlesServer.GetBundleComponentsColor(TabSelection, EmptyColor);
			
			LineSectionAreaStart.Area(1,1,1,CounterBundle).TextColor = BundleColor;
			LineSectionAreaPrice.CurrentArea.TextColor = BundleColor;
			If StructureFlags.IsDiscount Then
				LineSectionAreaDiscount.CurrentArea.TextColor = BundleColor;
			EndIf;
			If StructureSecondFlags.IsTax Then
				LineSectionAreaVAT.Area(1,1,1,2).TextColor = BundleColor;
			EndIf;
			If StructureFlags.IsNetAmount Then
				LineSectionAreaNetAmount.CurrentArea.TextColor = BundleColor;
			EndIf;
			If StructureFlags.IsLineTotal Then
				LineSectionAreaTotal.CurrentArea.TextColor = BundleColor;
			EndIf;
			
			// End Bundles
			
			AreasToBeChecked.Clear();
			AreasToBeChecked.Add(LineSectionAreaStart);
			If TableInventoty.IndexOf(TabSelection) = TableInventoty.Count() - 1 Then
				For Each Area In TotalsAndTaxesAreasArray Do
					AreasToBeChecked.Add(Area);
				EndDo;
			EndIf;
			AreasToBeChecked.Add(PageNumberArea);
			
			If Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
			
				SpreadsheetDocument.Put(LineSectionAreaStart);
				SpreadsheetDocument.Join(LineSectionAreaPrice);
				If StructureFlags.IsDiscount Then
					SpreadsheetDocument.Join(LineSectionAreaDiscount);
				EndIf;
				If StructureSecondFlags.IsTax Then
					SpreadsheetDocument.Join(LineSectionAreaVAT);
				EndIf;
				If StructureFlags.IsNetAmount Then
					SpreadsheetDocument.Join(LineSectionAreaNetAmount);
				EndIf;
				If StructureFlags.IsLineTotal Then
					SpreadsheetDocument.Join(LineSectionAreaTotal);
				EndIf;
				
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
				#Region PrintTitleArea
				
				SpreadsheetDocument.Put(TitleArea);
				StringNameLineArea = "Title";
				DriveServer.AddPartAdditionalToAreaWithShift(
					Template,
					SpreadsheetDocument,
					CounterShift,
					StringNameLineArea,
					"PartAdditional" + StringNameLineArea); 
					
				If IsPictureLogo Then
					DriveServer.MakeShiftPictureWithShift(SpreadsheetDocument.Drawings.Logo, CounterShift - 1);
				EndIf;
				
				#EndRegion
				
				// Header
				
				SpreadsheetDocument.Put(LineHeaderAreaStart);
				SpreadsheetDocument.Join(LineHeaderAreaPrice);
				If StructureFlags.IsDiscount Then
					SpreadsheetDocument.Join(LineHeaderAreaDiscount);
				EndIf;
				If StructureSecondFlags.IsTax Then
					SpreadsheetDocument.Join(LineHeaderAreaVAT);
				EndIf;
				If StructureFlags.IsNetAmount Then
					SpreadsheetDocument.Join(LineHeaderAreaNetAmount);
				EndIf;
				If StructureFlags.IsLineTotal Then
					SpreadsheetDocument.Join(LineHeaderAreaTotal);
				EndIf;
				
				// Section
				
				SpreadsheetDocument.Put(LineSectionAreaStart);
				SpreadsheetDocument.Join(LineSectionAreaPrice);
				If StructureFlags.IsDiscount Then
					SpreadsheetDocument.Join(LineSectionAreaDiscount);
				EndIf;
				If StructureSecondFlags.IsTax Then
					SpreadsheetDocument.Join(LineSectionAreaVAT);
				EndIf;
				If StructureFlags.IsNetAmount Then
					SpreadsheetDocument.Join(LineSectionAreaNetAmount);
				EndIf;
				If StructureFlags.IsLineTotal Then
					SpreadsheetDocument.Join(LineSectionAreaTotal);
				EndIf;
				
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		#Region PrintSalesInvoiceTotalsAndTaxesArea
		
		For Each Area In TotalsAndTaxesAreasArray Do
			
			SpreadsheetDocument.Put(Area);
			
		EndDo;
		
		#Region PrintAdditionalAttributes
		If DisplayPrintOption And PrintParams.AdditionalAttributes And PrintManagementServerCallDrive.HasAdditionalAttributes(Header.Ref) Then
			
			SpreadsheetDocument.Put(EmptyLineArea);
			
			StringNameLineArea = "AdditionalAttributesStaticHeader";
				
			AddAttribHeader = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
			SpreadsheetDocument.Put(AddAttribHeader);
			
			DriveServer.AddPartAdditionalToAreaWithShift(
				Template,
				SpreadsheetDocument,
				CounterShift,
				StringNameLineArea,
				"PartAdditional" + StringNameLineArea);
			
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

Function PrintSubcontractorReport(ObjectsArray, PrintObjects, TemplateName, PrintParams)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_SubcontractorReport";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	#Region PrintSubcontractorReportQueryText
	
	Query.Text = 
	"SELECT ALLOWED
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Date AS DocumentDate,
	|	SalesInvoice.Number AS DocumentNumber,
	|	SalesInvoice.Company AS Company,
	|	SalesInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	SalesInvoice.Counterparty AS Counterparty,
	|	CASE
	|		WHEN SalesInvoice.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN SalesInvoice.ContactPerson
	|		WHEN CounterpartyContracts.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN CounterpartyContracts.ContactPerson
	|		ELSE Counterparties.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	SalesInvoice.DeliveryOption AS DeliveryOption,
	|	SalesInvoice.StructuralUnit AS StructuralUnit,
	|	SalesInvoice.ShippingAddress AS ShippingAddress,
	|	SalesInvoice.Inventory.(
	|		MAX(Products.SKU) AS SKU,
	|		MAX(CASE
	|				WHEN (CAST(SalesInvoice.Inventory.Content AS STRING(1024))) <> """"
	|					THEN CAST(SalesInvoice.Inventory.Content AS STRING(1024))
	|				WHEN (CAST(SalesInvoice.Inventory.Products.DescriptionFull AS STRING(1024))) <> """"
	|					THEN CAST(SalesInvoice.Inventory.Products.DescriptionFull AS STRING(1024))
	|				ELSE SalesInvoice.Inventory.Products.Description
	|			END) AS ProductDescription,
	|		SUM(Quantity) AS Quantity,
	|		MAX(MeasurementUnit) AS UOM,
	|		Products AS Products,
	|		MAX(LineNumber) AS LineNumber
	|	) AS Inventory,
	|	SalesInvoice.ConsumerMaterials.(
	|		MAX(Products.SKU) AS SKU,
	|		MAX(CASE
	|				WHEN (CAST(SalesInvoice.ConsumerMaterials.Products.DescriptionFull AS STRING(1024))) <> """"
	|					THEN CAST(SalesInvoice.ConsumerMaterials.Products.DescriptionFull AS STRING(1024))
	|				ELSE SalesInvoice.ConsumerMaterials.Products.Description
	|			END) AS ProductDescription,
	|		SUM(Quantity) AS Quantity,
	|		MAX(MeasurementUnit) AS UOM,
	|		Products AS Products,
	|		MAX(LineNumber) AS LineNumber
	|	) AS ConsumerMaterials
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON SalesInvoice.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON SalesInvoice.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON SalesInvoice.Contract = CounterpartyContracts.Ref
	|WHERE
	|	SalesInvoice.Ref IN(&ObjectsArray)
	|	AND SalesInvoice.Inventory.ProductsTypeInventory = TRUE
	|
	|GROUP BY
	|	SalesInvoice.ConsumerMaterials.(Products),
	|	SalesInvoice.Inventory.(Products)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	Main.Ref AS Ref,
	|	ISNULL(Inventory.SalesOrderNumber, Main.SalesOrderNumber) AS Number,
	|	ISNULL(Inventory.SalesOrderDate, Main.SalesOrderDate) AS Date
	|FROM
	|	(SELECT
	|		SalesInvoice.Ref AS Ref,
	|		ISNULL(SalesOrder.Number, """") AS SalesOrderNumber,
	|		ISNULL(SalesOrder.Date, DATETIME(1, 1, 1)) AS SalesOrderDate
	|	FROM
	|		Document.SalesInvoice AS SalesInvoice
	|			LEFT JOIN Document.SalesOrder AS SalesOrder
	|			ON SalesInvoice.Order = SalesOrder.Ref
	|				AND (SalesInvoice.SalesOrderPosition = VALUE(Enum.AttributeStationing.InHeader))
	|	WHERE
	|		SalesInvoice.Ref IN(&ObjectsArray)) AS Main
	|		LEFT JOIN (SELECT
	|			SalesInvoiceInventory.Ref AS Ref,
	|			SalesOrder.Date AS SalesOrderDate,
	|			SalesOrder.Number AS SalesOrderNumber
	|		FROM
	|			Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|				LEFT JOIN Document.SalesOrder AS SalesOrder
	|				ON SalesInvoiceInventory.Order = SalesOrder.Ref
	|		WHERE
	|			SalesInvoiceInventory.Ref IN(&ObjectsArray)) AS Inventory
	|		ON Main.Ref = Inventory.Ref
	|TOTALS BY
	|	Ref";
	
	#EndRegion
	
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
	
	Header						= ResultArray[0].Select();
	SalesOrdersNumbersHeaderSel	= ResultArray[1].Select(QueryResultIteration.ByGroupsWithHierarchy);
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_SubcontractorReport";
		
		Template = PrintManagement.PrintFormTemplate("Document.SalesInvoice.PF_MXL_SubcontractorReport", LanguageCode);
		
		#Region PrintSubcontractorReportTitleArea
		
		TitleArea = Template.GetArea("Title");
		TitleArea.Parameters.Fill(Header);
		
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
		
		#Region PrintSubcontractorReportCompanyInfoArea
		
		CompanyInfoArea = Template.GetArea("CompanyInfo");
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Company, Header.DocumentDate, , , Header.CompanyVATNumber, LanguageCode);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		BarcodesInPrintForms.AddBarcodeToTableDocument(CompanyInfoArea, Header.Ref);
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		#EndRegion
		
		#Region PrintSubcontractorReportCounterpartyInfoArea
		
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
		TitleParameters.Insert("TitleShipDate", NStr("en = 'Shipment date'; ru = 'Дата отгрузки';pl = 'Data wysyłki';es_ES = 'Fecha de envío';es_CO = 'Fecha de envío';tr = 'Sevkiyat tarihi';it = 'Data di spedizione';de = 'Versanddatum'", LanguageCode));
		
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
		
		CounterpartyInfoArea.Parameters.PaymentTerms = PaymentTermsServer.TitleStagesOfPayment(Header.Ref);
		If ValueIsFilled(CounterpartyInfoArea.Parameters.PaymentTerms) Then
			CounterpartyInfoArea.Parameters.PaymentTermsTitle = PaymentTermsServer.PaymentTermsPrintTitle();
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
		
		#Region PrintSubcontractorReportInventoryArea
		
		InventoryHeaderArea = Template.GetArea("InventoryHeader");
		SpreadsheetDocument.Put(InventoryHeaderArea);
		InventorySectionArea = Template.GetArea("InventorySection");
		Inventory = Header.Inventory.Unload();
		Inventory.Sort("LineNumber Asc");
		For Each Row In Inventory Do
			InventorySectionArea.Parameters.Fill(Row);
			SpreadsheetDocument.Put(InventorySectionArea);
		EndDo;
		
		LineTotalArea = Template.GetArea("LineTotal");
		LineTotalArea.Parameters.LineNumber	= Inventory.Count();
		LineTotalArea.Parameters.Quantity	= Inventory.Total("Quantity");
		SpreadsheetDocument.Put(LineTotalArea);
		
		#EndRegion
		
		#Region PrintSubcontractorReportMaterialsArea
		
		MaterialsHeaderArea = Template.GetArea("MaterialsHeader");
		SpreadsheetDocument.Put(MaterialsHeaderArea);
		MaterialsSectionArea = Template.GetArea("MaterialsSection");
		Materials = Header.ConsumerMaterials.Unload();
		Materials.Sort("LineNumber Asc");
		For Each Row In Materials Do
			MaterialsSectionArea.Parameters.Fill(Row);
			SpreadsheetDocument.Put(MaterialsSectionArea);
		EndDo;
		
		LineTotalArea = Template.GetArea("LineTotal");
		LineTotalArea.Parameters.LineNumber	= Materials.Count();
		LineTotalArea.Parameters.Quantity	= Materials.Total("Quantity");
		SpreadsheetDocument.Put(LineTotalArea);
		
		#EndRegion
	
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	If TemplateName = "SalesInvoice" Then
		
		Return PrintSalesInvoice(ObjectsArray, PrintObjects, TemplateName, PrintParams)
		
	EndIf;
	
	If TemplateName = "ClosingInvoice" Then
		
		Return PrintClosingInvoice(ObjectsArray, PrintObjects, TemplateName, PrintParams, True);
		
	EndIf;
	
	If TemplateName = "ClosingInvoiceNoAnnex" Then
		
		Return PrintClosingInvoice(ObjectsArray, PrintObjects, TemplateName, PrintParams, False);
		
	EndIf;
	
	If TemplateName = "SubcontractorReport" Then
		
		Return PrintSubcontractorReport(ObjectsArray, PrintObjects, TemplateName, PrintParams)
		
	EndIf;
	
EndFunction

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#Region MessageTemplates

// StandardSubsystems.MessageTemplates

// It is called when preparing message templates and allows you to override a list of attributes and attachments.
//
// Parameters:
//  Attributes - ValueTree - a list of template attributes.
//    * Name            - String - a unique name of a common attribute.
//    * Presentation  - String - a common attribute presentation.
//    * Type            - Type - an attribute type. It is a string by default.
//    * Format         - String - a value output format for numbers, dates, strings, and boolean values.
//  Attachments - ValueTable - print forms and attachments, where:
//    * Name           - String - a unique attachment name.
//    * Presentation - String - an option presentation.
//    * FileType      - String - an attachment type that matches the file extension: pdf, png, jpg, mxl, and so on.
//  AdditionalParameters - Structure - additional information on the message template.
//
Procedure OnPrepareMessageTemplate(Attributes, Attachments, AdditionalParameters) Export
	
EndProcedure

// It is called upon creating messages from template to fill in values of attributes and attachments.
//
// Parameters:
//  Message - Structure - a structure with the following keys:
//    * AttributesValues - Map - a list of attributes used in the template.
//      ** Key     - String - an attribute name in the template.
//      ** Value - String - a filling value in the template.
//    * CommonAttributesValues - Map - a list of common attributes used in the template.
//      ** Key     - String - an attribute name in the template.
//      ** Value - String - a filling value in the template.
//    * Attachments - Map - attribute values
//      ** Key     - String - an attachment name in the template.
//      ** Value - BinaryData, String - binary data or an address in a temporary storage of the attachment.
//    * AdditionalParameters - Structure - additional message parameters.
//  MessageSubject - AnyRef - a reference to an object that is a data source.
//  AdditionalParameters - Structure - additional information on the message template.
//
Procedure OnCreateMessage(Message, MessageSubject, AdditionalParameters) Export
	
EndProcedure

// Fills in a list of text message recipients when sending a message generated from template.
//
// Parameters:
//   SMSMessageRecipients - ValueTable - a list of text message recipients.
//     * PhoneNumber - String - a phone number to send a text message to.
//     * Presentation - String - a text message recipient presentation.
//     * Contact       - Arbitrary - a contact that owns the phone number.
//  MessageSubject - AnyRef - a reference to an object that is a data source.
//                   - Structure  - a structure describing template parameters:
//    * Subject               - AnyRef - a reference to an object that is a data source.
//    * ArbitraryParameters - Map - a filled list of arbitrary parameters.
//
Procedure OnFillRecipientsPhonesInMessage(SMSMessageRecipients, MessageSubject) Export
	
EndProcedure

// Fills in a list of email recipients upon sending a message generated from a template.
//
// Parameters:
//   MailRecipients - ValueTable - a list of mail recipients.
//     * Address           - String - a recipient email address.
//     * Presentation   - String - an email recipient presentation.
//     * Contact         - Arbitrary - a contact that owns the email address.
//  MessageSubject - AnyRef - a reference to an object that is a data source.
//                   - Structure  - a structure describing template parameters:
//    * Subject               - AnyRef - a reference to an object that is a data source.
//    * ArbitraryParameters - Map - a filled list of arbitrary parameters.
//
Procedure OnFillRecipientsEmailsInMessage(EmailRecipients, MessageSubject) Export
	
EndProcedure

// End StandardSubsystems.MessageTemplates

#EndRegion

// StandardSubsystems.Interactions

// Get counterparty and contact persons.
//
// Parameters:
//  Subject  - DocumentRef.GoodsIssue - the document whose contacts you need to get.
//
// Returns:
//   Array   - array of contacts.
// 
Function GetContacts(Subject) Export
	
	If Not ValueIsFilled(Subject) Then
		Return New Array;
	EndIf;
	
	Return DriveContactInformationServer.GetContactsRefs(Subject);
	
EndFunction

// End StandardSubsystems.Interactions

#EndRegion

#Region WorkWithSerialNumbers

// Generates a table of values that contains the data for the SerialNumbersInWarranty information register.
// Tables of values saves into the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRef, StructureAdditionalProperties)
	
	If DocumentRef.SerialNumbers.Count()=0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		Query.Text =
		"SELECT
		|	TableSerialNumbers.Period AS Period,
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	VALUE(Enum.SerialNumbersOperations.Expense) AS Operation,
		|	TableSerialNumbers.Period AS EventDate,
		|	TableSerialNumbers.SerialNumber AS SerialNumber,
		|	TableSerialNumbers.Company AS Company,
		|	TableSerialNumbers.Products AS Products,
		|	TableSerialNumbers.Characteristic AS Characteristic,
		|	TableSerialNumbers.Batch AS Batch,
		|	TableSerialNumbers.Ownership AS Ownership,
		|	TableSerialNumbers.StructuralUnit AS StructuralUnit,
		|	TableSerialNumbers.Cell AS Cell,
		|	1 AS Quantity
		|FROM
		|	TemporaryTableInventoryOwnership AS TableSerialNumbers
		|WHERE
		|	NOT TableSerialNumbers.SerialNumber = VALUE(Catalog.SerialNumbers.EmptyRef)
		|	AND NOT TableSerialNumbers.AdvanceInvoicing
		|	AND TableSerialNumbers.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)";
	Else
		Query.Text =
		"SELECT
		|	TableSerialNumbers.Period AS Period,
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	VALUE(Enum.SerialNumbersOperations.Expense) AS Operation,
		|	TableSerialNumbers.Period AS EventDate,
		|	SerialNumbers.SerialNumber AS SerialNumber,
		|	TableSerialNumbers.Company AS Company,
		|	TableSerialNumbers.Products AS Products,
		|	TableSerialNumbers.Characteristic AS Characteristic,
		|	TableSerialNumbers.Batch AS Batch,
		|	TableSerialNumbers.StructuralUnit AS StructuralUnit,
		|	TableSerialNumbers.Cell AS Cell,
		|	1 AS Quantity
		|FROM
		|	TemporaryTableInventory AS TableSerialNumbers
		|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
		|		ON TableSerialNumbers.ConnectionKey = SerialNumbers.ConnectionKey
		|			AND (NOT TableSerialNumbers.AdvanceInvoicing)
		|			AND (TableSerialNumbers.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef))
		|WHERE
		|	NOT TableSerialNumbers.ZeroInvoice";
	EndIf;
	
	QueryResult = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", QueryResult);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
	EndIf; 
	
EndProcedure

#EndRegion

Procedure GenerateTableGoodsConsumedToDeclare(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTableMaterials.Period AS Period,
	|	TemporaryTableMaterials.Company AS Company,
	|	TemporaryTableMaterials.Products AS Products,
	|	TemporaryTableMaterials.Characteristic AS Characteristic,
	|	TemporaryTableMaterials.Batch AS Batch,
	|	TemporaryTableMaterials.Counterparty AS Counterparty,
	|	TemporaryTableMaterials.Quantity AS Quantity
	|FROM
	|	TemporaryTableMaterials AS TemporaryTableMaterials";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsConsumedToDeclare", QueryResult.Unload());
	
EndProcedure

#Region Private

Function GetIsZeroInvoice(DocumentRef)
	
	Result = False;
	
	If Common.ObjectAttributeValue(DocumentRef, "OperationKind") = Enums.OperationTypesSalesInvoice.ZeroInvoice Then
	
		Result = True;
	
	EndIf;
	
	Return Result;
	
EndFunction

#Region EntriesStructure

Function GetEntriesStructureMainAdditionalDetails(EntryTypeFields, TaxIncludes = True)
	
	MainDetails = New Structure;
	MainDetails.Insert("Company"				, NStr("en = 'Company'; ru = 'Организация';pl = 'Firma';es_ES = 'Empresa';es_CO = 'Empresa';tr = 'İş yeri';it = 'Azienda';de = 'Firma'"));
	MainDetails.Insert("PresentationCurrency"	, NStr("en = 'Presentation currency'; ru = 'Валюта представления отчетности';pl = 'Waluta prezentacji';es_ES = 'Moneda de presentación';es_CO = 'Moneda de presentación';tr = 'Finansal tablo para birimi';it = 'Valuta di presentazione';de = 'Währung für die Berichtserstattung'"));
	
	If TaxIncludes Then
		MainDetails.Insert("VATID"				, NStr("en = 'VAT ID'; ru = 'Номер плательщика НДС';pl = 'Numer VAT';es_ES = 'Identificador de IVA';es_CO = 'Identificador de IVA';tr = 'KDV kodu';it = 'P.IVA';de = 'USt.- IdNr.'"));
	EndIf;
	
	EntryTypeFields.Insert("MainDetails", MainDetails);
	
	AdditionalDetails = New Structure;
	AdditionalDetails.Insert("Period"				, NStr("en = 'Document date'; ru = 'Дата документа';pl = 'Data dokumentu';es_ES = 'Fecha del documento';es_CO = 'Fecha del documento';tr = 'Belge tarihi';it = 'Data del documento';de = 'Belegdatum'"));
	AdditionalDetails.Insert("DeliveryPeriodStart"	, NStr("en = 'Delivery period start'; ru = 'Начало срока доставки';pl = 'Początek okresu dostawy';es_ES = 'Inicio del período de entrega';es_CO = 'Inicio del período de entrega';tr = 'Teslimat dönemi başlangıcı';it = 'Avvio periodo di consegna';de = 'Beginn des Lieferzeitraums'"));
	AdditionalDetails.Insert("DeliveryPeriodEnd"	, NStr("en = 'Delivery period end'; ru = 'Конец срока доставки';pl = 'Koniec okresu dostawy';es_ES = 'Fin del período de entrega';es_CO = 'Fin del período de entrega';tr = 'Teslimat dönemi sonu';it = 'Fine periodo di consegna';de = 'Ende des Lieferzeitraums'"));
	
	If TaxIncludes Then
		AdditionalDetails.Insert("TaxCategory"	, NStr("en = 'Tax category'; ru = 'Налогообложение';pl = 'Rodzaj opodatkowania VAT';es_ES = 'Categoría de impuestos';es_CO = 'Categoría de impuestos';tr = 'Vergi kategorisi';it = 'Categoria di imposta';de = 'Steuerkategorie'"));
		AdditionalDetails.Insert("TaxRate"		, NStr("en = 'Tax rate'; ru = 'Налоговая ставка';pl = 'Stawka VAT';es_ES = 'Tipo de impuesto';es_CO = 'Tipo de impuesto';tr = 'Vergi oranı';it = 'Aliquota fiscale';de = 'Steuersatz'"));
	EndIf;
	
	EntryTypeFields.Insert("AdditionalDetails", AdditionalDetails);
	
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureAccountsReceivableRevenue()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("Counterparty"		, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	DebitDetails.Insert("Contract"			, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	DebitDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	DebitDetails.Insert("SettlementCurrency", NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	DebitDetails.Insert("Recorder"			, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	CreditDetails.Insert("IncomeAndExpenseItem"	, NStr("en = 'Income item'; ru = 'Статья доходов';pl = 'Pozycja dochodów';es_ES = 'Artículo de ingresos';es_CO = 'Artículo de ingresos';tr = 'Gelir kalemi';it = 'Voce di entrata';de = 'Position von Einnahme'"));
	CreditDetails.Insert("Product"				, NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"));
	CreditDetails.Insert("Project"				, NStr("en = 'Project'; ru = 'Проект';pl = 'Projekt';es_ES = 'Proyecto';es_CO = 'Proyecto';tr = 'Proje';it = 'Progetto';de = 'Projekt'"));
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("Quantity"			, NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'"));
	Amounts.Insert("SettlementsAmount"	, NStr("en = 'Amount (Settlement currency)'; ru = 'Сумма (Валюта расчетов)';pl = 'Wartość (Waluta rozliczeniowa)';es_ES = 'Importe (Moneda de liquidación)';es_CO = 'Importe (Moneda de liquidación)';tr = 'Tutar (Uzlaşma para birimi)';it = 'Importo (Valuta di regolamento)';de = 'Betrag (Abrechnungswährung)'"));
	Amounts.Insert("Amount"				, NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	Amounts.Insert("SettlementsTax"		, NStr("en = 'Tax (Settlement currency)'; ru = 'Налог (Валюта расчетов)';pl = 'VAT (Waluta rozliczeniowa)';es_ES = 'Impuesto (Moneda de liquidación)';es_CO = 'Impuesto (Moneda de liquidación)';tr = 'Vergi (Uzlaşma para birimi)';it = 'Tassa (Valuta di regolamento)';de = 'Steuer (Abrechnungswährung)'"));
	Amounts.Insert("Tax"				, NStr("en = 'Tax (Presentation currency)'; ru = 'Налог (Валюта представления отчетности)';pl = 'VAT (Waluta prezentacji)';es_ES = 'Impuesto (Moneda de presentación)';es_CO = 'Impuesto (Moneda de presentación)';tr = 'Vergi (Finansal tablo para birimi)';it = 'Tassa (Valuta di presentazione)';de = 'Steuer (Währung für die Berichtserstattung)'"));
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureAccountsReceivableUnearnedRevenue()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("Counterparty"		, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	DebitDetails.Insert("Contract"			, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	DebitDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	DebitDetails.Insert("SettlementCurrency", NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	DebitDetails.Insert("Recorder"			, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	CreditDetails.Insert("IncomeAndExpenseItem"	, NStr("en = 'Income item'; ru = 'Статья доходов';pl = 'Pozycja dochodów';es_ES = 'Artículo de ingresos';es_CO = 'Artículo de ingresos';tr = 'Gelir kalemi';it = 'Voce di entrata';de = 'Position von Einnahme'"));
	CreditDetails.Insert("Product"				, NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"));
	CreditDetails.Insert("Project"				, NStr("en = 'Project'; ru = 'Проект';pl = 'Projekt';es_ES = 'Proyecto';es_CO = 'Proyecto';tr = 'Proje';it = 'Progetto';de = 'Projekt'"));
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("Quantity"			, NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'"));
	Amounts.Insert("SettlementsAmount"	, NStr("en = 'Amount (Settlement currency)'; ru = 'Сумма (Валюта расчетов)';pl = 'Wartość (Waluta rozliczeniowa)';es_ES = 'Importe (Moneda de liquidación)';es_CO = 'Importe (Moneda de liquidación)';tr = 'Tutar (Uzlaşma para birimi)';it = 'Importo (Valuta di regolamento)';de = 'Betrag (Abrechnungswährung)'"));
	Amounts.Insert("Amount"				, NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	Amounts.Insert("SettlementsTax"		, NStr("en = 'Tax (Settlement currency)'; ru = 'Налог (Валюта расчетов)';pl = 'VAT (Waluta rozliczeniowa)';es_ES = 'Impuesto (Moneda de liquidación)';es_CO = 'Impuesto (Moneda de liquidación)';tr = 'Vergi (Uzlaşma para birimi)';it = 'Tassa (Valuta di regolamento)';de = 'Steuer (Abrechnungswährung)'"));
	Amounts.Insert("Tax"				, NStr("en = 'Tax (Presentation currency)'; ru = 'Налог (Валюта представления отчетности)';pl = 'VAT (Waluta prezentacji)';es_ES = 'Impuesto (Moneda de presentación)';es_CO = 'Impuesto (Moneda de presentación)';tr = 'Vergi (Finansal tablo para birimi)';it = 'Tassa (Valuta di presentazione)';de = 'Steuer (Währung für die Berichtserstattung)'"));
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureAdvancesFromCustomerAccountsReceivable()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields, False);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("Counterparty"		, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	DebitDetails.Insert("Contract"			, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	DebitDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	DebitDetails.Insert("SettlementCurrency", NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	DebitDetails.Insert("AdvanceDocument"	, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	CreditDetails.Insert("Counterparty"			, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	CreditDetails.Insert("Contract"				, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	CreditDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	CreditDetails.Insert("SettlementCurrency"	, NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	CreditDetails.Insert("Recorder"				, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("SettlementsAmount"	, NStr("en = 'Amount (Settlement currency)'; ru = 'Сумма (Валюта расчетов)';pl = 'Wartość (Waluta rozliczeniowa)';es_ES = 'Importe (Moneda de liquidación)';es_CO = 'Importe (Moneda de liquidación)';tr = 'Tutar (Uzlaşma para birimi)';it = 'Importo (Valuta di regolamento)';de = 'Betrag (Abrechnungswährung)'"));
	Amounts.Insert("Amount"				, NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureSettlementsWithCustomerForeignExchangeGain()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields, False);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("Counterparty"		, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	DebitDetails.Insert("Contract"			, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	DebitDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	DebitDetails.Insert("SettlementCurrency", NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	DebitDetails.Insert("Recorder"			, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	CreditDetails.Insert("IncomeAndExpenseItem"	, NStr("en = 'Income item'; ru = 'Статья доходов';pl = 'Pozycja dochodów';es_ES = 'Artículo de ingresos';es_CO = 'Artículo de ingresos';tr = 'Gelir kalemi';it = 'Voce di entrata';de = 'Position von Einnahme'"));
	CreditDetails.Insert("Department"			, NStr("en = 'Department'; ru = 'Подразделение';pl = 'Dział';es_ES = 'Departamento';es_CO = 'Departamento';tr = 'Bölüm';it = 'Reparto';de = 'Abteilung'"));
	CreditDetails.Insert("Project"				, NStr("en = 'Project'; ru = 'Проект';pl = 'Projekt';es_ES = 'Proyecto';es_CO = 'Proyecto';tr = 'Proje';it = 'Progetto';de = 'Projekt'"));
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("Amount", NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureForeignExchangeLossSettlementsWithCustomer()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields, False);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("IncomeAndExpenseItem"	, NStr("en = 'Expense item'; ru = 'Статья расходов';pl = 'Pozycja rozchodów';es_ES = 'Artículo de gastos';es_CO = 'Artículo de gastos';tr = 'Gider kalemi';it = 'Voce di uscita';de = 'Position von Ausgaben'"));
	DebitDetails.Insert("Department"			, NStr("en = 'Department'; ru = 'Подразделение';pl = 'Dział';es_ES = 'Departamento';es_CO = 'Departamento';tr = 'Bölüm';it = 'Reparto';de = 'Abteilung'"));
	DebitDetails.Insert("Project"				, NStr("en = 'Project'; ru = 'Проект';pl = 'Projekt';es_ES = 'Proyecto';es_CO = 'Proyecto';tr = 'Proje';it = 'Progetto';de = 'Projekt'"));
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	CreditDetails.Insert("Counterparty"			, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	CreditDetails.Insert("Contract"				, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	CreditDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	CreditDetails.Insert("SettlementCurrency"	, NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	CreditDetails.Insert("Recorder"				, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("Amount", NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureVATOutputVATFromAdvancesReceived()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields, False);
	
	DebitDetails = New Structure;
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	CreditDetails.Insert("Counterparty"			, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	CreditDetails.Insert("Contract"				, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	CreditDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	CreditDetails.Insert("SettlementCurrency"	, NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	CreditDetails.Insert("Recorder"				, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("Amount", NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureThirdPartyPayerAccountsReceivable()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields, False);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("Counterparty"		, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	DebitDetails.Insert("Contract"			, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	DebitDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	DebitDetails.Insert("SettlementCurrency", NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	DebitDetails.Insert("Recorder"			, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	CreditDetails.Insert("Counterparty"			, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	CreditDetails.Insert("Contract"				, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	CreditDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	CreditDetails.Insert("SettlementCurrency"	, NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	CreditDetails.Insert("Recorder"				, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("SettlementsAmount"	, NStr("en = 'Amount (Settlement currency)'; ru = 'Сумма (Валюта расчетов)';pl = 'Wartość (Waluta rozliczeniowa)';es_ES = 'Importe (Moneda de liquidación)';es_CO = 'Importe (Moneda de liquidación)';tr = 'Tutar (Uzlaşma para birimi)';it = 'Importo (Valuta di regolamento)';de = 'Betrag (Abrechnungswährung)'"));
	Amounts.Insert("Amount"				, NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureAccountsReceivableAccountsReceivableOffset()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields, False);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("Counterparty"		, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	DebitDetails.Insert("Contract"			, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	DebitDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	DebitDetails.Insert("SettlementCurrency", NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	DebitDetails.Insert("Recorder"			, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	
	CreditDetails = New Structure;
	CreditDetails.Insert("Counterparty"			, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	CreditDetails.Insert("Contract"				, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	CreditDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	CreditDetails.Insert("SettlementCurrency"	, NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	CreditDetails.Insert("AdvanceDocument"		, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	
	Amounts = New Structure;
	Amounts.Insert("SettlementsAmount"	, NStr("en = 'Amount (Settlement currency)'; ru = 'Сумма (Валюта расчетов)';pl = 'Wartość (Waluta rozliczeniowa)';es_ES = 'Importe (Moneda de liquidación)';es_CO = 'Importe (Moneda de liquidación)';tr = 'Tutar (Uzlaşma para birimi)';it = 'Importo (Valuta di regolamento)';de = 'Betrag (Abrechnungswährung)'"));
	Amounts.Insert("Amount"				, NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	
	EntryTypeFields.Insert("CreditDetails"	, CreditDetails);
	EntryTypeFields.Insert("DebitDetails"	, DebitDetails);
	EntryTypeFields.Insert("Amounts"		, Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureAccountsReceivableAdvancesFromCustomer()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields, False);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("Counterparty"		, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	DebitDetails.Insert("Contract"			, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	DebitDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	DebitDetails.Insert("SettlementCurrency", NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	DebitDetails.Insert("Recorder"			, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	CreditDetails.Insert("Counterparty"			, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	CreditDetails.Insert("Contract"				, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	CreditDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	CreditDetails.Insert("SettlementCurrency"	, NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	CreditDetails.Insert("Recorder"				, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("SettlementsAmount"	, NStr("en = 'Amount (Settlement currency)'; ru = 'Сумма (Валюта расчетов)';pl = 'Wartość (Waluta rozliczeniowa)';es_ES = 'Importe (Moneda de liquidación)';es_CO = 'Importe (Moneda de liquidación)';tr = 'Tutar (Uzlaşma para birimi)';it = 'Importo (Valuta di regolamento)';de = 'Betrag (Abrechnungswährung)'"));
	Amounts.Insert("Amount"				, NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureCOGSInventory()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields, False);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("IncomeAndExpenseItem"	, NStr("en = 'Expense item'; ru = 'Статья расходов';pl = 'Pozycja rozchodów';es_ES = 'Artículo de gastos';es_CO = 'Artículo de gastos';tr = 'Gider kalemi';it = 'Voce di uscita';de = 'Position von Ausgaben'"));
	DebitDetails.Insert("Project"				, NStr("en = 'Project'; ru = 'Проект';pl = 'Projekt';es_ES = 'Proyecto';es_CO = 'Proyecto';tr = 'Proje';it = 'Progetto';de = 'Projekt'"));
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	CreditDetails.Insert("Product"	, NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"));
	CreditDetails.Insert("Variant"	, NStr("en = 'Variant'; ru = 'Вариант';pl = 'Wariant';es_ES = 'Variante';es_CO = 'Variante';tr = 'Varyant';it = 'Variante';de = 'Variante'"));
	CreditDetails.Insert("Batch"	, NStr("en = 'Batch'; ru = 'Партия';pl = 'Partia';es_ES = 'Lote';es_CO = 'Lote';tr = 'Parti';it = 'Lotto';de = 'Charge'"));
	CreditDetails.Insert("Warehouse", NStr("en = 'Warehouse'; ru = 'Склад';pl = 'Magazyn';es_ES = 'Almacén';es_CO = 'Almacén';tr = 'Ambar';it = 'Magazzino';de = 'Lager'"));
	CreditDetails.Insert("Ownership", NStr("en = 'Ownership'; ru = 'Владение';pl = 'Własność';es_ES = 'Propiedad';es_CO = 'Propiedad';tr = 'Sahiplik';it = 'Proprietà';de = 'Eigentumsverhältnisse'"));
	CreditDetails.Insert("Project"	, NStr("en = 'Project'; ru = 'Проект';pl = 'Projekt';es_ES = 'Proyecto';es_CO = 'Proyecto';tr = 'Proje';it = 'Progetto';de = 'Projekt'"));
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("Quantity"	, NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'"));
	Amounts.Insert("Amount"		, NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureCOGSGoodsShippedNotInvoiced()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields, False);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("IncomeAndExpenseItem"	, NStr("en = 'Expense item'; ru = 'Статья расходов';pl = 'Pozycja rozchodów';es_ES = 'Artículo de gastos';es_CO = 'Artículo de gastos';tr = 'Gider kalemi';it = 'Voce di uscita';de = 'Position von Ausgaben'"));
	DebitDetails.Insert("Project"				, NStr("en = 'Project'; ru = 'Проект';pl = 'Projekt';es_ES = 'Proyecto';es_CO = 'Proyecto';tr = 'Proje';it = 'Progetto';de = 'Projekt'"));
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	CreditDetails.Insert("Product"	, NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"));
	CreditDetails.Insert("Variant"	, NStr("en = 'Variant'; ru = 'Вариант';pl = 'Wariant';es_ES = 'Variante';es_CO = 'Variante';tr = 'Varyant';it = 'Variante';de = 'Variante'"));
	CreditDetails.Insert("Batch"	, NStr("en = 'Batch'; ru = 'Партия';pl = 'Partia';es_ES = 'Lote';es_CO = 'Lote';tr = 'Parti';it = 'Lotto';de = 'Charge'"));
	CreditDetails.Insert("Warehouse", NStr("en = 'Warehouse'; ru = 'Склад';pl = 'Magazyn';es_ES = 'Almacén';es_CO = 'Almacén';tr = 'Ambar';it = 'Magazzino';de = 'Lager'"));
	CreditDetails.Insert("Ownership", NStr("en = 'Ownership'; ru = 'Владение';pl = 'Własność';es_ES = 'Propiedad';es_CO = 'Propiedad';tr = 'Sahiplik';it = 'Proprietà';de = 'Eigentumsverhältnisse'"));
	CreditDetails.Insert("Project"	, NStr("en = 'Project'; ru = 'Проект';pl = 'Projekt';es_ES = 'Proyecto';es_CO = 'Proyecto';tr = 'Proje';it = 'Progetto';de = 'Projekt'"));
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("Quantity"	, NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'"));
	Amounts.Insert("Amount"		, NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureAccountsReceivableSalesTax()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields, False);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("Counterparty"		, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	DebitDetails.Insert("Contract"			, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	DebitDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	DebitDetails.Insert("SettlementCurrency", NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	DebitDetails.Insert("Recorder"			, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	CreditDetails.Insert("TaxAgency", NStr("en = 'Tax agency'; ru = 'Налоговый орган';pl = 'Urząd podatkowy';es_ES = 'Agencia tributaria';es_CO = 'Agencia tributaria';tr = 'Vergi idaresi';it = 'Agenzia fiscale';de = 'Steueramt'"));
	CreditDetails.Insert("SalesTax"	, NStr("en = 'Sales tax rate'; ru = 'Ставка налога с продаж';pl = 'Stawka podatku od sprzedaży';es_ES = 'Tasa de impuesto sobre ventas';es_CO = 'Tasa de impuesto sobre ventas';tr = 'Satış vergisi oranı';it = 'Aliquota imposta sulle vendite';de = 'Umsatzsteuersatz'"));
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("SettlementsAmount"	, NStr("en = 'Amount (Settlement currency)'; ru = 'Сумма (Валюта расчетов)';pl = 'Wartość (Waluta rozliczeniowa)';es_ES = 'Importe (Moneda de liquidación)';es_CO = 'Importe (Moneda de liquidación)';tr = 'Tutar (Uzlaşma para birimi)';it = 'Importo (Valuta di regolamento)';de = 'Betrag (Abrechnungswährung)'"));
	Amounts.Insert("Amount"				, NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

#EndRegion

#EndRegion


#EndIf