#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region Public

Procedure FillByGoodsReceipts(DocumentData, FilterData, Inventory) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	GoodsReceipt.Ref AS Ref,
	|	GoodsReceipt.PointInTime AS PointInTime
	|INTO TT_GoodsReceipts
	|FROM
	|	Document.GoodsReceipt AS GoodsReceipt
	|WHERE
	|	&GoodsReceiptsConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CreditNoteInventory.Order AS Order,
	|	CreditNoteInventory.GoodsReceipt AS GoodsReceipt,
	|	CreditNoteInventory.Products AS Products,
	|	CreditNoteInventory.Characteristic AS Characteristic,
	|	CreditNoteInventory.Batch AS Batch,
	|	SUM(CreditNoteInventory.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyInvoiced
	|FROM
	|	Document.CreditNote.Inventory AS CreditNoteInventory
	|		INNER JOIN TT_GoodsReceipts AS TT_GoodsReceipts
	|		ON CreditNoteInventory.GoodsReceipt = TT_GoodsReceipts.Ref
	|		INNER JOIN Document.DebitNote AS CreditNote
	|		ON CreditNoteInventory.Ref = CreditNote.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON CreditNoteInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON CreditNoteInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	CreditNote.Posted
	|	AND CreditNoteInventory.Ref <> &Ref
	|
	|GROUP BY
	|	CreditNoteInventory.Batch,
	|	CreditNoteInventory.Order,
	|	CreditNoteInventory.Products,
	|	CreditNoteInventory.Characteristic,
	|	CreditNoteInventory.GoodsReceipt
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsReceiptBalance.SalesOrder AS SalesOrder,
	|	GoodsReceiptBalance.GoodsReceipt AS GoodsReceipt,
	|	GoodsReceiptBalance.Products AS Products,
	|	GoodsReceiptBalance.Characteristic AS Characteristic,
	|	SUM(GoodsReceiptBalance.QuantityBalance) AS QuantityBalance,
	|	GoodsReceiptBalance.SalesDocument AS SalesDocument
	|INTO TT_GoodsReceiptBalance
	|FROM
	|	(SELECT
	|		Inventory.CorrSalesOrder AS SalesOrder,
	|		Inventory.Products AS Products,
	|		Inventory.Characteristic AS Characteristic,
	|		Inventory.Recorder AS GoodsReceipt,
	|		Inventory.Quantity AS QuantityBalance,
	|		Inventory.SourceDocument AS SalesDocument
	|	FROM
	|		AccumulationRegister.Inventory AS Inventory
	|	WHERE
	|		Inventory.Recorder IN
	|				(SELECT
	|					TT_GoodsReceipts.Ref AS Ref
	|				FROM
	|					TT_GoodsReceipts AS TT_GoodsReceipts)
	|		AND Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CreditNoteInventory.Order,
	|		CreditNoteInventory.Products,
	|		CreditNoteInventory.Characteristic,
	|		CreditNoteInventory.GoodsReceipt,
	|		-CreditNoteInventory.Quantity,
	|		CreditNoteInventory.SalesDocument
	|	FROM
	|		Document.CreditNote.Inventory AS CreditNoteInventory
	|	WHERE
	|		CreditNoteInventory.Ref <> &Ref
	|		AND CreditNoteInventory.Ref.Posted
	|		AND CreditNoteInventory.GoodsReceipt IN
	|				(SELECT
	|					TT_GoodsReceipts.Ref AS Ref
	|				FROM
	|					TT_GoodsReceipts AS TT_GoodsReceipts)) AS GoodsReceiptBalance
	|
	|GROUP BY
	|	GoodsReceiptBalance.SalesOrder,
	|	GoodsReceiptBalance.GoodsReceipt,
	|	GoodsReceiptBalance.Products,
	|	GoodsReceiptBalance.Characteristic,
	|	GoodsReceiptBalance.SalesDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsReceiptProducts.LineNumber AS LineNumber,
	|	GoodsReceiptProducts.Products AS Products,
	|	GoodsReceiptProducts.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ProductsTypeInventory,
	|	GoodsReceiptProducts.Characteristic AS Characteristic,
	|	GoodsReceiptProducts.Batch AS Batch,
	|	GoodsReceiptProducts.Quantity AS Quantity,
	|	GoodsReceiptProducts.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	GoodsReceiptProducts.Ref AS GoodsReceipt,
	|	GoodsReceiptProducts.Order AS Order,
	|	GoodsReceiptProducts.Contract AS Contract,
	|	GoodsReceiptProducts.SerialNumbers AS SerialNumbers,
	|	TT_GoodsReceipts.PointInTime AS PointInTime,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsReceiptProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsReceiptProducts.COGSGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS COGSGLAccount,
	|	GoodsReceiptProducts.Price AS Price,
	|	GoodsReceiptProducts.VATRate AS VATRate,
	|	GoodsReceiptProducts.InitialAmount AS InitialAmount,
	|	GoodsReceiptProducts.InitialQuantity AS InitialQuantity,
	|	GoodsReceiptProducts.SalesDocument AS SalesDocument,
	|	GoodsReceiptProducts.Amount AS Amount,
	|	GoodsReceiptProducts.VATAmount AS VATAmount,
	|	GoodsReceiptProducts.Total AS Total,
	|	GoodsReceiptProducts.CostOfGoodsSold AS CostOfGoodsSold,
	|	GoodsReceiptProducts.Project AS Project
	|INTO TT_Inventory
	|FROM
	|	Document.GoodsReceipt.Products AS GoodsReceiptProducts
	|		INNER JOIN TT_GoodsReceipts AS TT_GoodsReceipts
	|		ON GoodsReceiptProducts.Ref = TT_GoodsReceipts.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON GoodsReceiptProducts.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON GoodsReceiptProducts.MeasurementUnit = UOM.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	TT_Inventory.Order AS Order,
	|	TT_Inventory.GoodsReceipt AS GoodsReceipt,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor AS BaseQuantity,
	|	SUM(TT_InventoryCumulative.Quantity * TT_InventoryCumulative.Factor) AS BaseQuantityCumulative,
	|	TT_InventoryCumulative.Price AS Price,
	|	TT_InventoryCumulative.VATRate AS VATRate,
	|	SUM(TT_Inventory.InitialAmount) AS InitialAmount,
	|	SUM(TT_Inventory.InitialQuantity) AS InitialQuantity,
	|	TT_Inventory.SalesDocument AS SalesDocument,
	|	SUM(TT_InventoryCumulative.Amount) AS Amount,
	|	SUM(TT_InventoryCumulative.VATAmount) AS VATAmount,
	|	SUM(TT_InventoryCumulative.Total) AS Total,
	|	SUM(TT_InventoryCumulative.CostOfGoodsSold) AS CostOfGoodsSold,
	|	TT_Inventory.Project AS Project
	|INTO TT_InventoryCumulative
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_Inventory AS TT_InventoryCumulative
	|		ON TT_Inventory.Products = TT_InventoryCumulative.Products
	|			AND TT_Inventory.Characteristic = TT_InventoryCumulative.Characteristic
	|			AND TT_Inventory.Batch = TT_InventoryCumulative.Batch
	|			AND TT_Inventory.SalesDocument = TT_InventoryCumulative.SalesDocument
	|			AND TT_Inventory.Order = TT_InventoryCumulative.Order
	|			AND TT_Inventory.GoodsReceipt = TT_InventoryCumulative.GoodsReceipt
	|			AND TT_Inventory.LineNumber = TT_InventoryCumulative.LineNumber
	|			AND TT_Inventory.Project = TT_InventoryCumulative.Project
	|
	|GROUP BY
	|	TT_Inventory.LineNumber,
	|	TT_Inventory.Products,
	|	TT_Inventory.Characteristic,
	|	TT_Inventory.Batch,
	|	TT_Inventory.Order,
	|	TT_Inventory.GoodsReceipt,
	|	TT_Inventory.Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor,
	|	TT_InventoryCumulative.Price,
	|	TT_InventoryCumulative.VATRate,
	|	TT_Inventory.SalesDocument,
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
	|	TT_InventoryCumulative.GoodsReceipt AS GoodsReceipt,
	|	TT_InventoryCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_AlreadyInvoiced.BaseQuantity > TT_InventoryCumulative.BaseQuantityCumulative - TT_InventoryCumulative.BaseQuantity
	|			THEN TT_InventoryCumulative.BaseQuantityCumulative - TT_AlreadyInvoiced.BaseQuantity
	|		ELSE TT_InventoryCumulative.BaseQuantity
	|	END AS BaseQuantity,
	|	TT_InventoryCumulative.Price AS Price,
	|	TT_InventoryCumulative.VATRate AS VATRate,
	|	TT_InventoryCumulative.InitialAmount AS InitialAmount,
	|	TT_InventoryCumulative.InitialQuantity AS InitialQuantity,
	|	TT_InventoryCumulative.SalesDocument AS SalesDocument,
	|	TT_InventoryCumulative.Amount AS Amount,
	|	TT_InventoryCumulative.VATAmount AS VATAmount,
	|	TT_InventoryCumulative.Total AS Total,
	|	TT_InventoryCumulative.CostOfGoodsSold AS CostOfGoodsSold,
	|	TT_InventoryCumulative.Project AS Project
	|INTO TT_InventoryNotYetInvoiced
	|FROM
	|	TT_InventoryCumulative AS TT_InventoryCumulative
	|		LEFT JOIN TT_AlreadyInvoiced AS TT_AlreadyInvoiced
	|		ON TT_InventoryCumulative.Products = TT_AlreadyInvoiced.Products
	|			AND TT_InventoryCumulative.Characteristic = TT_AlreadyInvoiced.Characteristic
	|			AND TT_InventoryCumulative.Batch = TT_AlreadyInvoiced.Batch
	|			AND TT_InventoryCumulative.Order = TT_AlreadyInvoiced.Order
	|			AND TT_InventoryCumulative.GoodsReceipt = TT_AlreadyInvoiced.GoodsReceipt
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
	|	TT_InventoryNotYetInvoiced.GoodsReceipt AS GoodsReceipt,
	|	TT_InventoryNotYetInvoiced.Factor AS Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity AS BaseQuantity,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.BaseQuantity) AS BaseQuantityCumulative,
	|	TT_InventoryNotYetInvoicedCumulative.Price AS Price,
	|	TT_InventoryNotYetInvoicedCumulative.VATRate AS VATRate,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.InitialAmount) AS InitialAmount,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.InitialQuantity) AS InitialQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.SalesDocument AS SalesDocument,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.Amount) AS Amount,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.VATAmount) AS VATAmount,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.Total) AS Total,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.CostOfGoodsSold) AS CostOfGoodsSold,
	|	TT_InventoryNotYetInvoiced.Project AS Project
	|INTO TT_InventoryNotYetInvoicedCumulative
	|FROM
	|	TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoiced
	|		INNER JOIN TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoicedCumulative
	|		ON TT_InventoryNotYetInvoiced.Products = TT_InventoryNotYetInvoicedCumulative.Products
	|			AND TT_InventoryNotYetInvoiced.Characteristic = TT_InventoryNotYetInvoicedCumulative.Characteristic
	|			AND TT_InventoryNotYetInvoiced.Batch = TT_InventoryNotYetInvoicedCumulative.Batch
	|			AND TT_InventoryNotYetInvoiced.SalesDocument = TT_InventoryNotYetInvoicedCumulative.SalesDocument
	|			AND TT_InventoryNotYetInvoiced.Order = TT_InventoryNotYetInvoicedCumulative.Order
	|			AND TT_InventoryNotYetInvoiced.GoodsReceipt = TT_InventoryNotYetInvoicedCumulative.GoodsReceipt
	|			AND TT_InventoryNotYetInvoiced.LineNumber = TT_InventoryNotYetInvoicedCumulative.LineNumber
	|			AND TT_InventoryNotYetInvoiced.Project = TT_InventoryNotYetInvoicedCumulative.Project
	|
	|GROUP BY
	|	TT_InventoryNotYetInvoiced.LineNumber,
	|	TT_InventoryNotYetInvoiced.Products,
	|	TT_InventoryNotYetInvoiced.Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch,
	|	TT_InventoryNotYetInvoiced.Order,
	|	TT_InventoryNotYetInvoiced.GoodsReceipt,
	|	TT_InventoryNotYetInvoiced.Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.Price,
	|	TT_InventoryNotYetInvoicedCumulative.VATRate,
	|	TT_InventoryNotYetInvoicedCumulative.SalesDocument,
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
	|	TT_InventoryNotYetInvoicedCumulative.GoodsReceipt AS GoodsReceipt,
	|	TT_InventoryNotYetInvoicedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_GoodsReceiptBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|		WHEN TT_GoodsReceiptBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|			THEN TT_GoodsReceiptBalance.QuantityBalance - (TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity)
	|	END AS BaseQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.Price AS Price,
	|	TT_InventoryNotYetInvoicedCumulative.VATRate AS VATRate,
	|	TT_InventoryNotYetInvoicedCumulative.InitialAmount AS InitialAmount,
	|	TT_InventoryNotYetInvoicedCumulative.InitialQuantity AS InitialQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.SalesDocument AS SalesDocument,
	|	TT_InventoryNotYetInvoicedCumulative.Amount AS Amount,
	|	TT_InventoryNotYetInvoicedCumulative.VATAmount AS VATAmount,
	|	TT_InventoryNotYetInvoicedCumulative.Total AS Total,
	|	TT_InventoryNotYetInvoicedCumulative.CostOfGoodsSold AS CostOfGoodsSold,
	|	TT_InventoryNotYetInvoicedCumulative.Project AS Project
	|INTO TT_InventoryToBeInvoiced
	|FROM
	|	TT_InventoryNotYetInvoicedCumulative AS TT_InventoryNotYetInvoicedCumulative
	|		INNER JOIN TT_GoodsReceiptBalance AS TT_GoodsReceiptBalance
	|		ON TT_InventoryNotYetInvoicedCumulative.Products = TT_GoodsReceiptBalance.Products
	|			AND TT_InventoryNotYetInvoicedCumulative.Characteristic = TT_GoodsReceiptBalance.Characteristic
	|			AND TT_InventoryNotYetInvoicedCumulative.Order = TT_GoodsReceiptBalance.SalesOrder
	|			AND TT_InventoryNotYetInvoicedCumulative.GoodsReceipt = TT_GoodsReceiptBalance.GoodsReceipt
	|			AND TT_InventoryNotYetInvoicedCumulative.SalesDocument = TT_GoodsReceiptBalance.SalesDocument
	|WHERE
	|	TT_GoodsReceiptBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
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
	|	TT_Inventory.GoodsReceipt AS GoodsReceipt,
	|	TT_Inventory.SerialNumbers AS SerialNumbers,
	|	TT_Inventory.PointInTime AS PointInTime,
	|	TT_InventoryToBeInvoiced.Price AS Price,
	|	CASE
	|		WHEN AccountingPolicySliceLast.RegisteredForVAT
	|			THEN ISNULL(TT_InventoryToBeInvoiced.VATRate, CatProducts.VATRate)
	|		ELSE VALUE(Catalog.VATRates.Exempt)
	|	END AS VATRate,
	|	TT_Inventory.InventoryGLAccount AS InventoryGLAccount,
	|	TT_Inventory.COGSGLAccount AS COGSGLAccount,
	|	TT_InventoryToBeInvoiced.Price AS InitialPrice,
	|	TT_InventoryToBeInvoiced.InitialAmount AS InitialAmount,
	|	TT_InventoryToBeInvoiced.InitialQuantity AS InitialQuantity,
	|	TT_InventoryToBeInvoiced.SalesDocument AS SalesDocument,
	|	TT_InventoryToBeInvoiced.Amount AS Amount,
	|	TT_InventoryToBeInvoiced.VATAmount AS VATAmount,
	|	TT_InventoryToBeInvoiced.Total AS Total,
	|	TT_InventoryToBeInvoiced.CostOfGoodsSold AS CostOfGoodsSold,
	|	TRUE AS Shipped,
	|	TT_Inventory.Project AS Project
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_InventoryToBeInvoiced AS TT_InventoryToBeInvoiced
	|		ON TT_Inventory.LineNumber = TT_InventoryToBeInvoiced.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryToBeInvoiced.Order
	|			AND TT_Inventory.GoodsReceipt = TT_InventoryToBeInvoiced.GoodsReceipt
	|		LEFT JOIN Catalog.Products AS CatProducts
	|		ON TT_Inventory.Products = CatProducts.Ref
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(, Company = &Company) AS AccountingPolicySliceLast
	|		ON (TRUE)";
	
	Contract = Undefined;
	
	FilterData.Property("Contract", Contract);
	Query.SetParameter("Contract", Contract);
	
	If FilterData.Property("ArrayOfGoodsReceipts") Then
		FilterString = "GoodsReceipt.Ref IN(&ArrayOfGoodsReceipts)";
		Query.SetParameter("ArrayOfGoodsReceipts", FilterData.ArrayOfGoodsReceipts);
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
			
			FilterString = FilterString + "GoodsReceipt." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
			
		EndDo;
		
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&GoodsReceiptsConditions", FilterString);
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(DocumentData.Company));
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	StructureData = New Structure;
	StructureData.Insert("ObjectParameters", DocumentData);
	
	Inventory.Clear();
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	While Selection.Next() Do
		
		TabularSectionRow = Inventory.Add();
		FillPropertyValues(TabularSectionRow, Selection);
		
		TabularSectionRow.Total = TabularSectionRow.Amount + ?(DocumentData.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
		
	EndDo;
		
EndProcedure

Procedure FillBySalesInvoices(DocumentData, FilterData, Inventory, SerialNumbers) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.PointInTime AS PointInTime
	|INTO TT_SalesInvoices
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	&SalesInvoicesConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Sales.Document AS Document,
	|	Sales.SalesOrder AS Order,
	|	Sales.Products AS Products,
	|	Sales.Characteristic AS Characteristic,
	|	Sales.Quantity AS BaseQuantity
	|INTO TT_AlreadyReturned
	|FROM
	|	AccumulationRegister.Sales AS Sales
	|WHERE
	|	Sales.Quantity < 0
	|	AND Sales.Document IN
	|			(SELECT
	|				TT_SalesInvoices.Ref AS Ref
	|			FROM
	|				TT_SalesInvoices AS TT_SalesInvoices)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ShippedBalance.Company AS Company,
	|	ShippedBalance.Counterparty AS Counterparty,
	|	ShippedBalance.Products AS Products,
	|	ShippedBalance.Characteristic AS Characteristic,
	|	CASE
	|		WHEN ShippedBalance.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR ShippedBalance.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ShippedBalance.SalesOrder
	|	END AS SalesOrder,
	|	ShippedBalance.Document AS SalesInvoice,
	|	ShippedBalance.VATRate AS VATRate,
	|	ShippedBalance.Currency AS Currency,
	|	SUM(ShippedBalance.QuantityTurnover) AS QuantityBalance,
	|	TRUE AS Shipped,
	|	SUM(ShippedBalance.CostTurnover) AS Cost
	|INTO TT_SalesInvoiceBalance
	|FROM
	|	AccumulationRegister.Sales.Turnovers(
	|			,
	|			,
	|			Recorder,
	|			Document IN
	|				(SELECT
	|					TT_SalesInvoices.Ref AS Ref
	|				FROM
	|					TT_SalesInvoices AS TT_SalesInvoices)) AS ShippedBalance
	|WHERE
	|	ShippedBalance.Recorder <> &Ref
	|
	|GROUP BY
	|	ShippedBalance.Characteristic,
	|	ShippedBalance.Products,
	|	ShippedBalance.Document,
	|	ShippedBalance.Company,
	|	CASE
	|		WHEN ShippedBalance.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR ShippedBalance.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ShippedBalance.SalesOrder
	|	END,
	|	ShippedBalance.Counterparty,
	|	ShippedBalance.VATRate,
	|	ShippedBalance.Currency
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsInvoicedNotShippedTurnovers.Company,
	|	GoodsInvoicedNotShippedTurnovers.Counterparty,
	|	GoodsInvoicedNotShippedTurnovers.Products,
	|	GoodsInvoicedNotShippedTurnovers.Characteristic,
	|	CASE
	|		WHEN GoodsInvoicedNotShippedTurnovers.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE GoodsInvoicedNotShippedTurnovers.SalesOrder
	|	END,
	|	GoodsInvoicedNotShippedTurnovers.SalesInvoice,
	|	GoodsInvoicedNotShippedTurnovers.VATRate,
	|	SalesInvoiceDoc.DocumentCurrency,
	|	SUM(GoodsInvoicedNotShippedTurnovers.QuantityTurnover),
	|	FALSE,
	|	0
	|FROM
	|	AccumulationRegister.GoodsInvoicedNotShipped.Turnovers(
	|			,
	|			,
	|			Recorder,
	|			SalesInvoice IN
	|				(SELECT
	|					TT_SalesInvoices.Ref AS Ref
	|				FROM
	|					TT_SalesInvoices AS TT_SalesInvoices)) AS GoodsInvoicedNotShippedTurnovers
	|		LEFT JOIN Document.SalesInvoice AS SalesInvoiceDoc
	|		ON GoodsInvoicedNotShippedTurnovers.SalesInvoice = SalesInvoiceDoc.Ref
	|WHERE
	|	GoodsInvoicedNotShippedTurnovers.Recorder <> &Ref
	|
	|GROUP BY
	|	GoodsInvoicedNotShippedTurnovers.Products,
	|	GoodsInvoicedNotShippedTurnovers.Characteristic,
	|	GoodsInvoicedNotShippedTurnovers.SalesInvoice,
	|	GoodsInvoicedNotShippedTurnovers.Counterparty,
	|	GoodsInvoicedNotShippedTurnovers.Company,
	|	CASE
	|		WHEN GoodsInvoicedNotShippedTurnovers.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE GoodsInvoicedNotShippedTurnovers.SalesOrder
	|	END,
	|	GoodsInvoicedNotShippedTurnovers.VATRate,
	|	SalesInvoiceDoc.DocumentCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesInvoiceInventory.LineNumber AS LineNumber,
	|	SalesInvoiceInventory.Products AS Products,
	|	SalesInvoiceInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ProductsTypeInventory,
	|	SalesInvoiceInventory.Characteristic AS Characteristic,
	|	SalesInvoiceInventory.Batch AS Batch,
	|	SalesInvoiceInventory.Quantity AS Quantity,
	|	SalesInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	SalesInvoiceInventory.Ref AS SalesInvoice,
	|	CASE
	|		WHEN SalesInvoiceInventory.Order = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE SalesInvoiceInventory.Order
	|	END AS Order,
	|	TT_SalesInvoices.PointInTime AS PointInTime,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SalesInvoiceInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SalesInvoiceInventory.VATOutputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATOutputGLAccount,
	|	SalesInvoiceInventory.Price AS Price,
	|	SalesInvoiceInventory.VATRate AS VATRate,
	|	SalesInvoiceInventory.Amount AS InitialAmount,
	|	SalesInvoiceInventory.Quantity AS InitialQuantity,
	|	SalesInvoiceInventory.Amount AS Amount,
	|	SalesInvoiceInventory.VATAmount AS InitialVATAmount,
	|	SalesInvoiceInventory.Total AS Total,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SalesInvoiceInventory.UnearnedRevenueGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS UnearnedRevenueGLAccount,
	|	SalesInvoiceInventory.Taxable AS Taxable,
	|	SalesInvoiceInventory.Project AS Project,
	|	SalesInvoiceInventory.DropShipping AS DropShipping
	|INTO TT_Inventory
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		INNER JOIN TT_SalesInvoices AS TT_SalesInvoices
	|		ON SalesInvoiceInventory.Ref = TT_SalesInvoices.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesInvoiceInventory.MeasurementUnit = UOM.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	TT_Inventory.Order AS Order,
	|	TT_Inventory.SalesInvoice AS SalesInvoice,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor AS BaseQuantity,
	|	SUM(TT_InventoryCumulative.Quantity * TT_InventoryCumulative.Factor) AS BaseQuantityCumulative,
	|	TT_InventoryCumulative.Price AS Price,
	|	TT_InventoryCumulative.VATRate AS VATRate,
	|	SUM(TT_InventoryCumulative.InitialAmount) AS InitialAmount,
	|	SUM(TT_InventoryCumulative.InitialQuantity) AS InitialQuantity,
	|	SUM(TT_InventoryCumulative.Amount) AS Amount,
	|	SUM(TT_InventoryCumulative.InitialVATAmount) AS InitialVATAmount,
	|	SUM(TT_InventoryCumulative.Total) AS Total,
	|	TT_Inventory.Project AS Project
	|INTO TT_InventoryCumulative
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_Inventory AS TT_InventoryCumulative
	|		ON TT_Inventory.Products = TT_InventoryCumulative.Products
	|			AND TT_Inventory.Characteristic = TT_InventoryCumulative.Characteristic
	|			AND TT_Inventory.Batch = TT_InventoryCumulative.Batch
	|			AND TT_Inventory.Order = TT_InventoryCumulative.Order
	|			AND TT_Inventory.SalesInvoice = TT_InventoryCumulative.SalesInvoice
	|			AND TT_Inventory.LineNumber = TT_InventoryCumulative.LineNumber
	|			AND TT_Inventory.Price = TT_InventoryCumulative.Price
	|			AND TT_Inventory.Project = TT_InventoryCumulative.Project
	|
	|GROUP BY
	|	TT_Inventory.LineNumber,
	|	TT_Inventory.Products,
	|	TT_Inventory.Characteristic,
	|	TT_Inventory.Batch,
	|	TT_Inventory.Order,
	|	TT_Inventory.SalesInvoice,
	|	TT_Inventory.Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor,
	|	TT_InventoryCumulative.Price,
	|	TT_InventoryCumulative.VATRate,
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
	|	TT_InventoryCumulative.SalesInvoice AS SalesInvoice,
	|	TT_InventoryCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_AlreadyReturned.BaseQuantity > TT_InventoryCumulative.BaseQuantityCumulative - TT_InventoryCumulative.BaseQuantity
	|			THEN TT_InventoryCumulative.BaseQuantityCumulative - TT_AlreadyReturned.BaseQuantity
	|		ELSE TT_InventoryCumulative.BaseQuantity
	|	END AS BaseQuantity,
	|	TT_InventoryCumulative.Price AS Price,
	|	TT_InventoryCumulative.VATRate AS VATRate,
	|	TT_InventoryCumulative.InitialQuantity AS InitialQuantity,
	|	TT_InventoryCumulative.InitialAmount AS InitialAmount,
	|	TT_InventoryCumulative.Amount AS Amount,
	|	TT_InventoryCumulative.InitialVATAmount AS InitialVATAmount,
	|	TT_InventoryCumulative.Total AS Total,
	|	TT_InventoryCumulative.Project AS Project
	|INTO TT_InventoryNotYetInvoiced
	|FROM
	|	TT_InventoryCumulative AS TT_InventoryCumulative
	|		LEFT JOIN TT_AlreadyReturned AS TT_AlreadyReturned
	|		ON TT_InventoryCumulative.Products = TT_AlreadyReturned.Products
	|			AND TT_InventoryCumulative.Characteristic = TT_AlreadyReturned.Characteristic
	|			AND TT_InventoryCumulative.Order = TT_AlreadyReturned.Order
	|WHERE
	|	ISNULL(TT_AlreadyReturned.BaseQuantity, 0) < TT_InventoryCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryNotYetInvoiced.LineNumber AS LineNumber,
	|	TT_InventoryNotYetInvoiced.Products AS Products,
	|	TT_InventoryNotYetInvoiced.Characteristic AS Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch AS Batch,
	|	TT_InventoryNotYetInvoiced.Order AS Order,
	|	TT_InventoryNotYetInvoiced.SalesInvoice AS SalesInvoice,
	|	TT_InventoryNotYetInvoiced.Factor AS Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity AS BaseQuantity,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.BaseQuantity) AS BaseQuantityCumulative,
	|	TT_InventoryNotYetInvoicedCumulative.Price AS Price,
	|	TT_InventoryNotYetInvoicedCumulative.VATRate AS VATRate,
	|	TT_InventoryNotYetInvoicedCumulative.InitialQuantity AS InitialQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.InitialAmount AS InitialAmount,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.Amount) AS Amount,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.InitialVATAmount) AS InitialVATAmount,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.Total) AS Total,
	|	TT_InventoryNotYetInvoicedCumulative.Project AS Project
	|INTO TT_InventoryNotYetInvoicedCumulative
	|FROM
	|	TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoiced
	|		INNER JOIN TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoicedCumulative
	|		ON TT_InventoryNotYetInvoiced.Products = TT_InventoryNotYetInvoicedCumulative.Products
	|			AND TT_InventoryNotYetInvoiced.Characteristic = TT_InventoryNotYetInvoicedCumulative.Characteristic
	|			AND TT_InventoryNotYetInvoiced.Batch = TT_InventoryNotYetInvoicedCumulative.Batch
	|			AND TT_InventoryNotYetInvoiced.Order = TT_InventoryNotYetInvoicedCumulative.Order
	|			AND TT_InventoryNotYetInvoiced.SalesInvoice = TT_InventoryNotYetInvoicedCumulative.SalesInvoice
	|			AND TT_InventoryNotYetInvoiced.LineNumber = TT_InventoryNotYetInvoicedCumulative.LineNumber
	|			AND TT_InventoryNotYetInvoiced.Price = TT_InventoryNotYetInvoicedCumulative.Price
	|			AND TT_InventoryNotYetInvoiced.Project = TT_InventoryNotYetInvoicedCumulative.Project
	|
	|GROUP BY
	|	TT_InventoryNotYetInvoiced.LineNumber,
	|	TT_InventoryNotYetInvoiced.Products,
	|	TT_InventoryNotYetInvoiced.Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch,
	|	TT_InventoryNotYetInvoiced.Order,
	|	TT_InventoryNotYetInvoiced.SalesInvoice,
	|	TT_InventoryNotYetInvoiced.Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.Price,
	|	TT_InventoryNotYetInvoicedCumulative.VATRate,
	|	TT_InventoryNotYetInvoicedCumulative.InitialQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.InitialAmount,
	|	TT_InventoryNotYetInvoicedCumulative.Project
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryNotYetInvoicedCumulative.LineNumber AS LineNumber,
	|	TT_InventoryNotYetInvoicedCumulative.Products AS Products,
	|	TT_InventoryNotYetInvoicedCumulative.Characteristic AS Characteristic,
	|	TT_InventoryNotYetInvoicedCumulative.Batch AS Batch,
	|	TT_InventoryNotYetInvoicedCumulative.Order AS Order,
	|	TT_InventoryNotYetInvoicedCumulative.SalesInvoice AS SalesInvoice,
	|	TT_InventoryNotYetInvoicedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_SalesInvoiceBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|		WHEN TT_SalesInvoiceBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|			THEN TT_SalesInvoiceBalance.QuantityBalance - (TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity)
	|	END AS BaseQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.Price AS Price,
	|	TT_InventoryNotYetInvoicedCumulative.VATRate AS VATRate,
	|	TT_InventoryNotYetInvoicedCumulative.InitialQuantity AS InitialQuantity,
	|	CASE
	|		WHEN TT_InventoryNotYetInvoicedCumulative.InitialQuantity = 0
	|			THEN 0
	|		ELSE TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative * TT_InventoryNotYetInvoicedCumulative.InitialAmount / (TT_InventoryNotYetInvoicedCumulative.InitialQuantity * TT_InventoryNotYetInvoicedCumulative.Factor)
	|	END AS InitialAmount,
	|	TT_InventoryNotYetInvoicedCumulative.Amount AS Amount,
	|	TT_InventoryNotYetInvoicedCumulative.InitialVATAmount AS InitialVATAmount,
	|	TT_InventoryNotYetInvoicedCumulative.Total AS Total,
	|	TT_SalesInvoiceBalance.Shipped AS Shipped,
	|	CASE
	|		WHEN TT_SalesInvoiceBalance.QuantityBalance = 0
	|			THEN 0
	|		ELSE CASE
	|				WHEN TT_SalesInvoiceBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative
	|					THEN TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|				WHEN TT_SalesInvoiceBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|					THEN TT_SalesInvoiceBalance.QuantityBalance - (TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity)
	|			END * TT_SalesInvoiceBalance.Cost / TT_SalesInvoiceBalance.QuantityBalance
	|	END AS Cost,
	|	TT_InventoryNotYetInvoicedCumulative.Project AS Project
	|INTO TT_InventoryToBeInvoiced
	|FROM
	|	TT_InventoryNotYetInvoicedCumulative AS TT_InventoryNotYetInvoicedCumulative
	|		INNER JOIN TT_SalesInvoiceBalance AS TT_SalesInvoiceBalance
	|		ON TT_InventoryNotYetInvoicedCumulative.Products = TT_SalesInvoiceBalance.Products
	|			AND TT_InventoryNotYetInvoicedCumulative.Characteristic = TT_SalesInvoiceBalance.Characteristic
	|			AND TT_InventoryNotYetInvoicedCumulative.Order = TT_SalesInvoiceBalance.SalesOrder
	|			AND TT_InventoryNotYetInvoicedCumulative.SalesInvoice = TT_SalesInvoiceBalance.SalesInvoice
	|			AND (TT_SalesInvoiceBalance.Shipped)
	|WHERE
	|	TT_SalesInvoiceBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|
	|UNION ALL
	|
	|SELECT
	|	TT_InventoryNotYetInvoicedCumulative.LineNumber,
	|	TT_InventoryNotYetInvoicedCumulative.Products,
	|	TT_InventoryNotYetInvoicedCumulative.Characteristic,
	|	TT_InventoryNotYetInvoicedCumulative.Batch,
	|	TT_InventoryNotYetInvoicedCumulative.Order,
	|	TT_InventoryNotYetInvoicedCumulative.SalesInvoice,
	|	TT_InventoryNotYetInvoicedCumulative.Factor,
	|	CASE
	|		WHEN TT_SalesInvoiceBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|		WHEN TT_SalesInvoiceBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|			THEN TT_SalesInvoiceBalance.QuantityBalance - (TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity)
	|	END,
	|	TT_InventoryNotYetInvoicedCumulative.Price,
	|	TT_InventoryNotYetInvoicedCumulative.VATRate,
	|	TT_InventoryNotYetInvoicedCumulative.InitialQuantity,
	|	CASE
	|		WHEN TT_InventoryNotYetInvoicedCumulative.InitialQuantity = 0
	|			THEN 0
	|		ELSE TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative * TT_InventoryNotYetInvoicedCumulative.InitialAmount / TT_InventoryNotYetInvoicedCumulative.InitialQuantity
	|	END,
	|	TT_InventoryNotYetInvoicedCumulative.Amount,
	|	TT_InventoryNotYetInvoicedCumulative.InitialVATAmount,
	|	TT_InventoryNotYetInvoicedCumulative.Total,
	|	TT_SalesInvoiceBalance.Shipped,
	|	TT_SalesInvoiceBalance.Cost,
	|	TT_InventoryNotYetInvoicedCumulative.Project
	|FROM
	|	TT_InventoryNotYetInvoicedCumulative AS TT_InventoryNotYetInvoicedCumulative
	|		INNER JOIN TT_SalesInvoiceBalance AS TT_SalesInvoiceBalance
	|		ON TT_InventoryNotYetInvoicedCumulative.Products = TT_SalesInvoiceBalance.Products
	|			AND TT_InventoryNotYetInvoicedCumulative.Characteristic = TT_SalesInvoiceBalance.Characteristic
	|			AND TT_InventoryNotYetInvoicedCumulative.Order = TT_SalesInvoiceBalance.SalesOrder
	|			AND TT_InventoryNotYetInvoicedCumulative.SalesInvoice = TT_SalesInvoiceBalance.SalesInvoice
	|			AND (NOT TT_SalesInvoiceBalance.Shipped)
	|WHERE
	|	TT_SalesInvoiceBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
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
	|	TT_Inventory.SalesInvoice AS SalesDocument,
	|	TT_Inventory.PointInTime AS PointInTime,
	|	TT_InventoryToBeInvoiced.Price AS Price,
	|	CASE
	|		WHEN AccountingPolicySliceLast.RegisteredForVAT
	|			THEN ISNULL(TT_InventoryToBeInvoiced.VATRate, CatProducts.VATRate)
	|		ELSE VALUE(Catalog.VATRates.Exempt)
	|	END AS VATRate,
	|	TT_Inventory.InventoryGLAccount AS InventoryGLAccount,
	|	TT_Inventory.VATOutputGLAccount AS VATOutputGLAccount,
	|	TT_InventoryToBeInvoiced.Price AS InitialPrice,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Quantity
	|		ELSE CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))
	|	END AS InitialQuantity,
	|	TT_InventoryToBeInvoiced.InitialAmount AS InitialAmount,
	|	CASE
	|		WHEN TT_InventoryToBeInvoiced.InitialQuantity = 0
	|			THEN 0
	|		ELSE TT_InventoryToBeInvoiced.InitialAmount / TT_InventoryToBeInvoiced.InitialQuantity * TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor
	|	END AS Amount,
	|	CASE
	|		WHEN TT_InventoryToBeInvoiced.InitialQuantity = 0
	|			THEN 0
	|		ELSE TT_InventoryToBeInvoiced.InitialVATAmount / TT_InventoryToBeInvoiced.InitialQuantity * TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor
	|	END AS VATAmount,
	|	TT_InventoryToBeInvoiced.Total AS Total,
	|	TT_InventoryToBeInvoiced.Shipped AS Shipped,
	|	TT_InventoryToBeInvoiced.Cost AS CostOfGoodsSold,
	|	TT_Inventory.UnearnedRevenueGLAccount AS UnearnedRevenueGLAccount,
	|	TT_Inventory.Taxable AS Taxable,
	|	TT_InventoryToBeInvoiced.Project AS Project,
	|	TT_Inventory.DropShipping AS DropShipping
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_InventoryToBeInvoiced AS TT_InventoryToBeInvoiced
	|		ON TT_Inventory.LineNumber = TT_InventoryToBeInvoiced.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryToBeInvoiced.Order
	|			AND TT_Inventory.SalesInvoice = TT_InventoryToBeInvoiced.SalesInvoice
	|		LEFT JOIN Catalog.Products AS CatProducts
	|		ON TT_Inventory.Products = CatProducts.Ref
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(, Company = &Company) AS AccountingPolicySliceLast
	|		ON (TRUE)";
	
	
	Contract = Undefined;
	
	FilterData.Property("Contract", Contract);
	Query.SetParameter("Contract", Contract);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	If FilterData.Property("ArrayOfSalesInvoices") Then
		FilterString = "SalesInvoice.Ref IN(&ArrayOfSalesInvoices)";
		Query.SetParameter("ArrayOfSalesInvoices", FilterData.ArrayOfSalesInvoices);
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
			
			FilterString = FilterString + "SalesInvoice." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
			
		EndDo;
		
	EndIf;
	
	Company = DriveServer.GetCompany(DocumentData.Company);
	
	Query.Text = StrReplace(Query.Text, "&SalesInvoicesConditions", FilterString);
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", Company);
	
	Inventory.Clear();
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentData.Date, Company);
	
	While Selection.Next() Do
		
		TabularSectionRow = Inventory.Add();
		FillPropertyValues(TabularSectionRow, Selection);
		
		TabularSectionRow.Total = TabularSectionRow.Amount + ?(DocumentData.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
		If Not AccountingPolicy.UseGoodsReturnFromCustomer Then
			TabularSectionRow.ConnectionKey = TabularSectionRow.LineNumber;
			WorkWithSerialNumbers.SetActualSerialNumbersInTabularSection(DocumentData, TabularSectionRow, SerialNumbers);
		EndIf;
	EndDo;
	
EndProcedure

Function DocumentVATRate(DocumentRef) Export
	
	Return Common.ObjectAttributeValue(DocumentRef, "VATRate");
	
EndFunction

#EndRegion

#Region TableGeneration

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSales(DocumentRefCreditNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Period AS Period,
	|	TableSales.Recorder AS Recorder,
	|	TableSales.Products AS Products,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Batch AS Batch,
	|	TableSales.Ownership AS Ownership,
	|	CASE
	|		WHEN TableSales.SalesDocument <> VALUE(Document.SalesInvoice.EmptyRef)
	|			THEN TableSales.SalesDocument
	|		WHEN VALUETYPE(TableSales.BasisDocument) = TYPE(Document.SalesSlip)
	|			THEN TableSales.ShiftClosure
	|		ELSE TableSales.BasisDocument
	|	END AS Document,
	|	TableSales.Company AS Company,
	|	TableSales.PresentationCurrency AS PresentationCurrency,
	|	TableSales.Counterparty AS Counterparty,
	|	TableSales.DocumentCurrency AS Currency,
	|	CASE
	|		WHEN TableSales.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableSales.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableSales.Order
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	TableSales.SalesRep AS SalesRep,
	|	TableSales.Department AS Department,
	|	-TableSales.ReturnQuantity AS Quantity,
	|	-(TableSales.Amount - TableSales.SalesTaxAmount) AS Amount,
	|	TableSales.VATRate AS VATRate,
	|	-TableSales.VATAmount AS VATAmount,
	|	-(TableSales.AmountDocCur - TableSales.SalesTaxAmountDocCur) AS AmountCur,
	|	-TableSales.VATAmountDocCur AS VATAmountCur,
	|	-TableSales.SalesTaxAmount AS SalesTaxAmount,
	|	-TableSales.SalesTaxAmountDocCur AS SalesTaxAmountCur,
	|	CASE
	|		WHEN VALUETYPE(TableSales.BasisDocument) = TYPE(Document.SalesSlip)
	|			THEN 0
	|		WHEN &FillAmount
	|			THEN -TableSales.CostOfGoodsSold
	|	END AS Cost,
	|	TableSales.Responsible AS Responsible,
	|	FALSE AS OfflineRecord,
	|	TableSales.BundleProduct AS BundleProduct,
	|	TableSales.BundleCharacteristic AS BundleCharacteristic
	|FROM
	|	TemporaryTableInventory AS TableSales
	|WHERE
	|	TableSales.Shipped
	|
	|UNION ALL
	|
	|SELECT
	|	TableSales.Period,
	|	TableSales.Recorder,
	|	TableSales.Products,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	TableSales.Ownership,
	|	TableSales.ShiftClosure,
	|	TableSales.Company,
	|	TableSales.PresentationCurrency,
	|	TableSales.Counterparty,
	|	TableSales.DocumentCurrency,
	|	CASE
	|		WHEN TableSales.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableSales.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableSales.Order
	|		ELSE UNDEFINED
	|	END,
	|	TableSales.SalesRep,
	|	TableSales.Department,
	|	0,
	|	0,
	|	TableSales.VATRate,
	|	0,
	|	0,
	|	0,
	|	0,
	|	0,
	|	-TableSales.CostOfGoodsSold,
	|	TableSales.Responsible,
	|	FALSE,
	|	TableSales.BundleProduct,
	|	TableSales.BundleCharacteristic
	|FROM
	|	TemporaryTableInventory AS TableSales
	|WHERE
	|	VALUETYPE(TableSales.BasisDocument) = TYPE(Document.SalesSlip)
	|	AND TableSales.CostOfGoodsSold <> 0
	|	AND &FillAmount
	|	AND TableSales.Shipped
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Recorder,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.Ownership,
	|	OfflineRecords.Document,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.Counterparty,
	|	OfflineRecords.Currency,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.SalesRep,
	|	OfflineRecords.Department,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.Amount,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.VATAmount,
	|	OfflineRecords.AmountCur,
	|	OfflineRecords.VATAmountCur,
	|	OfflineRecords.SalesTaxAmount,
	|	OfflineRecords.SalesTaxAmountCur,
	|	OfflineRecords.Cost,
	|	OfflineRecords.Responsible,
	|	OfflineRecords.OfflineRecord,
	|	OfflineRecords.BundleProduct,
	|	OfflineRecords.BundleCharacteristic
	|FROM
	|	AccumulationRegister.Sales AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	Query.SetParameter("Ref", DocumentRefCreditNote);
	FillAmount = (StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage);
	Query.SetParameter("FillAmount", FillAmount);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsReceivable(DocumentRefCreditNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref",					DocumentRefCreditNote);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", CommonClientServer.DefaultLanguageCode()));
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
													
	Query.Text =
	"SELECT
	|	TableAccountsReceivable.Period AS Date,
	|	TableAccountsReceivable.LineNumber AS LineNumber,
	|	TableAccountsReceivable.Recorder AS Recorder,
	|	TableAccountsReceivable.Company AS Company,
	|	TableAccountsReceivable.PresentationCurrency AS PresentationCurrency,
	|	CASE
	|		WHEN TableAccountsReceivable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	TableAccountsReceivable.SettlementsCurrency AS Currency,
	|	TableAccountsReceivable.Counterparty AS Counterparty,
	|	TableAccountsReceivable.Contract AS Contract,
	|	TableAccountsReceivable.Document AS Document,
	|	CASE
	|		WHEN TableAccountsReceivable.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableAccountsReceivable.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableAccountsReceivable.Order
	|	END AS Order,
	|	TableAccountsReceivable.GLAccountCustomerSettlements AS GLAccount,
	|	TableAccountsReceivable.AmountCur + TableAccountsReceivable.VATAmountCur AS PaymentAmount,
	|	TableAccountsReceivable.Amount + TableAccountsReceivable.VATAmount AS Amount,
	|	TableAccountsReceivable.AmountCur + TableAccountsReceivable.VATAmountCur AS AmountCur,
	|	TableAccountsReceivable.Amount + TableAccountsReceivable.VATAmount AS AmountForPayment,
	|	TableAccountsReceivable.AmountCur + TableAccountsReceivable.VATAmountCur AS AmountForPaymentCur,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableAccountsReceivable.OperationKind AS ContentOfAccountingRecord,
	|	-(TableAccountsReceivable.Amount + TableAccountsReceivable.VATAmount) AS AmountForBalance,
	|	-(TableAccountsReceivable.AmountCur + TableAccountsReceivable.VATAmountCur) AS AmountCurForBalance
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTableAmountAllocation AS TableAccountsReceivable";
	
	QueryResult = Query.Execute();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextCurrencyExchangeRateAccountsReceivable(Query.TempTablesManager, False, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsReceivable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefCreditNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	TableIncomeAndExpenses.Date AS Period,
	|	TableIncomeAndExpenses.Ref AS Recorder,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.PresentationCurrency AS PresentationCurrency,
	|	TableIncomeAndExpenses.Department AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLine AS BusinessLine,
	|	TemporaryTableInventory.Order AS SalesOrder,
	|	TemporaryTableInventory.SalesReturnItem AS IncomeAndExpenseItem,
	|	TemporaryTableInventory.GLAccount AS GLAccount,
	|	-(TemporaryTableInventory.Amount - TemporaryTableInventory.SalesTaxAmount) AS AmountIncome,
	|	0 AS AmountExpense,
	|	TableIncomeAndExpenses.OperationKind AS ContentOfAccountingRecord
	|INTO TableIncomeAndExpenses
	|FROM
	|	TemporaryTableHeader AS TableIncomeAndExpenses
	|		INNER JOIN TemporaryTableInventory AS TemporaryTableInventory
	|		ON TableIncomeAndExpenses.Ref = TemporaryTableInventory.Recorder
	|WHERE
	|	TableIncomeAndExpenses.OperationKind = VALUE(Enum.OperationTypesCreditNote.SalesReturn)
	|	AND TemporaryTableInventory.Shipped
	|
	|UNION ALL
	|
	|SELECT
	|	TableIncomeAndExpenses.Date,
	|	TableIncomeAndExpenses.Ref,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.PresentationCurrency,
	|	TableIncomeAndExpenses.Department,
	|	TableIncomeAndExpenses.BusinessLine,
	|	TableIncomeAndExpenses.Order,
	|	TableIncomeAndExpenses.ExpenseItem,
	|	TableIncomeAndExpenses.GLAccount,
	|	0,
	|	SUM(TableIncomeAndExpenses.Amount),
	|	TableIncomeAndExpenses.OperationKind
	|FROM
	|	TemporaryTableDocAmountAllocation AS TableIncomeAndExpenses
	|WHERE
	|	TableIncomeAndExpenses.OperationKind <> VALUE(Enum.OperationTypesCreditNote.SalesReturn)
	|	AND TableIncomeAndExpenses.RegisterExpense
	|	AND TableIncomeAndExpenses.ExpenseItem.IncomeAndExpenseType <> VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Department,
	|	TableIncomeAndExpenses.Date,
	|	TableIncomeAndExpenses.Order,
	|	TableIncomeAndExpenses.Ref,
	|	TableIncomeAndExpenses.PresentationCurrency,
	|	TableIncomeAndExpenses.ExpenseItem,
	|	TableIncomeAndExpenses.GLAccount,
	|	TableIncomeAndExpenses.OperationKind,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.BusinessLine
	|
	|UNION ALL
	|
	|SELECT
	|	Cost.Period,
	|	Cost.Recorder,
	|	Cost.Company,
	|	Cost.PresentationCurrency,
	|	Cost.Department,
	|	Cost.BusinessLine,
	|	Cost.Order,
	|	Cost.COGSItem,
	|	Cost.GLAccountCostOfSales,
	|	0,
	|	-Cost.CostOfGoodsSold,
	|	NULL
	|FROM
	|	TemporaryTableInventory AS Cost
	|WHERE
	|	Cost.CostOfGoodsSold > 0
	|	AND Cost.Shipped
	|	AND &FillAmount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.Date AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Currency AS Currency,
	|	DocumentTable.GLAccount AS GLAccount,
	|	DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|INTO TableExchangeRateDifferencesAccountsReceivable
	|FROM
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|WHERE
	|	DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Currency,
	|	DocumentTable.GLAccount,
	|	DocumentTable.AmountOfExchangeDifferences
	|FROM
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|WHERE
	|	DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableExchangeRateDifferencesAccountsReceivable.Date AS Date,
	|	TableExchangeRateDifferencesAccountsReceivable.Company AS Company,
	|	TableExchangeRateDifferencesAccountsReceivable.PresentationCurrency AS PresentationCurrency,
	|	TableExchangeRateDifferencesAccountsReceivable.Currency AS Currency,
	|	TableExchangeRateDifferencesAccountsReceivable.GLAccount AS GLAccount,
	|	&Ref AS Ref,
	|	SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences,
	|	ISNULL(PrimaryChartOfAccounts.Currency, FALSE) AS GLAccountCurrency
	|INTO GroupedTableExchangeRateDifferencesAccountsReceivable
	|FROM
	|	TableExchangeRateDifferencesAccountsReceivable AS TableExchangeRateDifferencesAccountsReceivable
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON TableExchangeRateDifferencesAccountsReceivable.GLAccount = PrimaryChartOfAccounts.Ref
	|
	|GROUP BY
	|	TableExchangeRateDifferencesAccountsReceivable.Date,
	|	TableExchangeRateDifferencesAccountsReceivable.Company,
	|	TableExchangeRateDifferencesAccountsReceivable.Currency,
	|	TableExchangeRateDifferencesAccountsReceivable.GLAccount,
	|	ISNULL(PrimaryChartOfAccounts.Currency, FALSE),
	|	TableExchangeRateDifferencesAccountsReceivable.PresentationCurrency
	|
	|HAVING
	|	(SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) >= 0.005
	|		OR SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) <= -0.005)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Recorder AS Recorder,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.PresentationCurrency AS PresentationCurrency,
	|	TableIncomeAndExpenses.StructuralUnit AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLine AS BusinessLine,
	|	CASE
	|		WHEN TableIncomeAndExpenses.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableIncomeAndExpenses.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableIncomeAndExpenses.SalesOrder
	|	END AS SalesOrder,
	|	TableIncomeAndExpenses.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	TableIncomeAndExpenses.GLAccount AS GLAccount,
	|	SUM(TableIncomeAndExpenses.AmountIncome) AS AmountIncome,
	|	SUM(TableIncomeAndExpenses.AmountExpense) AS AmountExpense,
	|	TableIncomeAndExpenses.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|FROM
	|	TableIncomeAndExpenses AS TableIncomeAndExpenses
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.StructuralUnit,
	|	TableIncomeAndExpenses.Recorder,
	|	TableIncomeAndExpenses.SalesOrder,
	|	TableIncomeAndExpenses.IncomeAndExpenseItem,
	|	TableIncomeAndExpenses.GLAccount,
	|	TableIncomeAndExpenses.ContentOfAccountingRecord,
	|	TableIncomeAndExpenses.BusinessLine,
	|	TableIncomeAndExpenses.Period,
	|	TableIncomeAndExpenses.PresentationCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	GroupedTableExchangeRateDifferencesAccountsReceivable.Date,
	|	GroupedTableExchangeRateDifferencesAccountsReceivable.Ref,
	|	GroupedTableExchangeRateDifferencesAccountsReceivable.Company,
	|	GroupedTableExchangeRateDifferencesAccountsReceivable.PresentationCurrency,
	|	TableDocument.Department,
	|	TableDocument.BusinessLine,
	|	CASE
	|		WHEN TableDocument.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableDocument.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableDocument.Order
	|	END,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences > 0
	|			THEN &FXIncomeItem
	|		ELSE &FXExpenseItem
	|	END,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences > 0
	|			THEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	GroupedTableExchangeRateDifferencesAccountsReceivable AS GroupedTableExchangeRateDifferencesAccountsReceivable
	|		INNER JOIN TemporaryTableHeader AS TableDocument
	|		ON (TableDocument.Ref = GroupedTableExchangeRateDifferencesAccountsReceivable.Ref)
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Recorder,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TableIncomeAndExpenses
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TableExchangeRateDifferencesAccountsReceivable";
	
	FillAmount = (StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage);
	
	Query.SetParameter("Ref", DocumentRefCreditNote);
	Query.SetParameter("FillAmount", FillAmount);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	Query.SetParameter("FXIncomeItem", Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem", Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.SetParameter("ExchangeDifference", 
		NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", CommonClientServer.DefaultLanguageCode()));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefCreditNote, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Ref", 							DocumentRefCreditNote);
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'",
															CommonClientServer.DefaultLanguageCode()));
	FillAmount = (StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage);
	Query.SetParameter("FillAmount", FillAmount);
	
	If DocumentRefCreditNote.OperationKind = Enums.OperationTypesCreditNote.SalesReturn Then
		
		Query.Text =
		"SELECT
		|	TableAccountingJournalEntries.Date AS Period,
		|	TableAccountingJournalEntries.Ref AS Recorder,
		|	TableAccountingJournalEntries.Company AS Company,
		|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
		|	CASE
		|		WHEN NOT TableAccountingJournalEntries.Shipped
		|			THEN TableAccountingJournalEntries.UnearnedRevenueGLAccount
		|		ELSE TableAccountingJournalEntries.GLAccount
		|	END AS AccountDr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.Shipped
		|					AND TableAccountingJournalEntries.GLAccountCurrency
		|				OR NOT TableAccountingJournalEntries.Shipped
		|					AND TableAccountingJournalEntries.UnearnedRevenueGLAccountCurrency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END AS CurrencyDr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.Shipped
		|					AND TableAccountingJournalEntries.GLAccountCurrency
		|				OR NOT TableAccountingJournalEntries.Shipped
		|					AND TableAccountingJournalEntries.UnearnedRevenueGLAccountCurrency
		|			THEN TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.SalesTaxAmountCur
		|		ELSE 0
		|	END AS AmountCurDr,
		|	TableAccountingJournalEntries.GLAccountCustomerSettlements AS AccountCr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlementsCurrency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END AS CurrencyCr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlementsCurrency
		|			THEN TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.SalesTaxAmountCur
		|		ELSE 0
		|	END AS AmountCurCr,
		|	TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.SalesTaxAmount AS Amount,
		|	TableAccountingJournalEntries.OperationKind AS Content,
		|	FALSE AS OfflineRecord
		|INTO UngroupedTable
		|FROM
		|	BasicAmountAllocation AS TableAccountingJournalEntries
		|
		|UNION ALL
		|
		|SELECT
		|	TableAccountingJournalEntries.Date,
		|	TableAccountingJournalEntries.Ref,
		|	TableAccountingJournalEntries.Company,
		|	VALUE(Catalog.PlanningPeriods.Actual),
		|	TableAccountingJournalEntries.VATOutputGLAccount,
		|	UNDEFINED,
		|	0,
		|	TableAccountingJournalEntries.GLAccountCustomerSettlements,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlementsCurrency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlementsCurrency
		|			THEN TableAccountingJournalEntries.VATAmountCur
		|		ELSE 0
		|	END,
		|	TableAccountingJournalEntries.VATAmount,
		|	TableAccountingJournalEntries.OperationKind,
		|	FALSE
		|FROM
		|	BasicAmountAllocation AS TableAccountingJournalEntries
		|WHERE
		|	TableAccountingJournalEntries.VATTaxation <> VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
		|	AND TableAccountingJournalEntries.VATAmount <> 0
		|
		|UNION ALL
		|
		|SELECT
		|	TableAccountingJournalEntries.Period,
		|	TableAccountingJournalEntries.Ref,
		|	TableAccountingJournalEntries.Company,
		|	VALUE(Catalog.PlanningPeriods.Actual),
		|	TableAccountingJournalEntries.SalesTaxGLAccount,
		|	UNDEFINED,
		|	0,
		|	TableAccountingJournalEntries.GLAccountCustomerSettlements,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlementsCurrency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END,
		|	SUM(CASE
		|			WHEN TableAccountingJournalEntries.GLAccountCustomerSettlementsCurrency
		|				THEN TableAccountingJournalEntries.AmountCur
		|			ELSE 0
		|		END),
		|	SUM(TableAccountingJournalEntries.Amount),
		|	TableAccountingJournalEntries.OperationKind,
		|	FALSE
		|FROM
		|	TemporarySalesTaxAmount AS TableAccountingJournalEntries
		|WHERE
		|	TableAccountingJournalEntries.Amount <> 0
		|
		|GROUP BY
		|	TableAccountingJournalEntries.Period,
		|	TableAccountingJournalEntries.Ref,
		|	TableAccountingJournalEntries.Company,
		|	TableAccountingJournalEntries.GLAccountCustomerSettlements,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlementsCurrency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END,
		|	TableAccountingJournalEntries.SalesTaxGLAccount,
		|	TableAccountingJournalEntries.OperationKind";
		
	Else
		
		Query.Text =
		"SELECT
		|	TableAccountingJournalEntries.Period AS Period,
		|	TableAccountingJournalEntries.Recorder AS Recorder,
		|	TableAccountingJournalEntries.Company AS Company,
		|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
		|	TableAccountingJournalEntries.GLAccount AS AccountDr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountCurrency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END AS CurrencyDr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountCurrency
		|			THEN TableAccountingJournalEntries.AmountCur
		|		ELSE 0
		|	END AS AmountCurDr,
		|	TableAccountingJournalEntries.GLAccountCustomerSettlements AS AccountCr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlementsCurrency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END AS CurrencyCr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlementsCurrency
		|			THEN TableAccountingJournalEntries.AmountCur
		|		ELSE 0
		|	END AS AmountCurCr,
		|	TableAccountingJournalEntries.Amount AS Amount,
		|	TableAccountingJournalEntries.OperationKind AS Content,
		|	FALSE AS OfflineRecord
		|INTO UngroupedTable
		|FROM
		|	TemporaryTableAmountAllocation AS TableAccountingJournalEntries
		|
		|UNION ALL
		|
		|SELECT
		|	TableAccountingJournalEntries.Period,
		|	TableAccountingJournalEntries.Recorder,
		|	TableAccountingJournalEntries.Company,
		|	VALUE(Catalog.PlanningPeriods.Actual),
		|	TableAccountingJournalEntries.VATOutputGLAccount,
		|	UNDEFINED,
		|	0,
		|	TableAccountingJournalEntries.GLAccountCustomerSettlements,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlementsCurrency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlementsCurrency
		|			THEN TableAccountingJournalEntries.VATAmountCur
		|		ELSE 0
		|	END,
		|	TableAccountingJournalEntries.VATAmount,
		|	TableAccountingJournalEntries.OperationKind,
		|	FALSE
		|FROM
		|	TemporaryTableAmountAllocation AS TableAccountingJournalEntries
		|WHERE
		|	TableAccountingJournalEntries.VATTaxation <> VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
		|	AND TableAccountingJournalEntries.VATAmount <> 0";
		
	EndIf;
	
	Query.Text = Query.Text + DriveClientServer.GetQueryUnion() +
	"SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Recorder,
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
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UngroupedTable.Period AS Period,
	|	UngroupedTable.Recorder AS Recorder,
	|	UngroupedTable.Company AS Company,
	|	UngroupedTable.PlanningPeriod AS PlanningPeriod,
	|	UngroupedTable.AccountDr AS AccountDr,
	|	UngroupedTable.CurrencyDr AS CurrencyDr,
	|	SUM(UngroupedTable.AmountCurDr) AS AmountCurDr,
	|	UngroupedTable.AccountCr AS AccountCr,
	|	UngroupedTable.CurrencyCr AS CurrencyCr,
	|	SUM(UngroupedTable.AmountCurCr) AS AmountCurCr,
	|	SUM(UngroupedTable.Amount) AS Amount,
	|	UngroupedTable.Content AS Content,
	|	UngroupedTable.OfflineRecord AS OfflineRecord
	|FROM
	|	UngroupedTable AS UngroupedTable
	|
	|GROUP BY
	|	UngroupedTable.CurrencyDr,
	|	UngroupedTable.PlanningPeriod,
	|	UngroupedTable.AccountDr,
	|	UngroupedTable.OfflineRecord,
	|	UngroupedTable.AccountCr,
	|	UngroupedTable.CurrencyCr,
	|	UngroupedTable.Period,
	|	UngroupedTable.Recorder,
	|	UngroupedTable.Company,
	|	UngroupedTable.Content";
	
	If DocumentRefCreditNote.OperationKind = Enums.OperationTypesCreditNote.SalesReturn 
		AND Not StructureAdditionalProperties.AccountingPolicy.UseGoodsReturnFromCustomer Then
		
		Query.Text = Query.Text + DriveClientServer.GetQueryUnion() +
		"SELECT
		|	TableAccountingJournalEntries.Period AS Period,
		|	TableAccountingJournalEntries.Recorder AS Recorder,
		|	TableAccountingJournalEntries.Company AS Company,
		|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
		|	TableAccountingJournalEntries.InventoryGLAccount AS AccountDr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.InventoryGLAccount.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END AS CurrencyDr,
		|	SUM(CASE
		|			WHEN TableAccountingJournalEntries.InventoryGLAccount.Currency
		|				THEN TableAccountingJournalEntries.AmountCur
		|			ELSE 0
		|		END) AS AmountCurDr,
		|	TableAccountingJournalEntries.GLAccountCostOfSales AS AccountCr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountCostOfSales.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END AS CurrencyCr,
		|	SUM(CASE
		|			WHEN TableAccountingJournalEntries.GLAccountCostOfSales.Currency
		|				THEN TableAccountingJournalEntries.AmountCur
		|			ELSE 0
		|		END) AS AmountCurCr,
		|	SUM(TableAccountingJournalEntries.CostOfGoodsSold) AS Amount,
		|	TableAccountingJournalEntries.OperationKind AS Content,
		|	FALSE AS OfflineRecord
		|FROM
		|	TemporaryTableInventory AS TableAccountingJournalEntries
		|WHERE
		|	TableAccountingJournalEntries.ThisIsInventoryItem
		|	AND TableAccountingJournalEntries.CostOfGoodsSold <> 0
		|	AND &FillAmount
		|
		|GROUP BY
		|	TableAccountingJournalEntries.GLAccountCostOfSales,
		|	TableAccountingJournalEntries.Recorder,
		|	TableAccountingJournalEntries.Company,
		|	TableAccountingJournalEntries.Period,
		|	CASE
		|		WHEN TableAccountingJournalEntries.InventoryGLAccount.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountCostOfSales.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END,
		|	TableAccountingJournalEntries.InventoryGLAccount,
		|	TableAccountingJournalEntries.OperationKind";
	EndIf;
	
	Query.Text = Query.Text + DriveClientServer.GetQueryUnion() + 
	"SELECT
	|	GroupedTableExchangeRateDifferencesAccountsReceivable.Date AS Period,
	|	GroupedTableExchangeRateDifferencesAccountsReceivable.Ref AS Recorder,
	|	GroupedTableExchangeRateDifferencesAccountsReceivable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences > 0
	|			THEN GroupedTableExchangeRateDifferencesAccountsReceivable.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS AccountDr,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences > 0
	|				AND GroupedTableExchangeRateDifferencesAccountsReceivable.GLAccountCurrency
	|			THEN GroupedTableExchangeRateDifferencesAccountsReceivable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE GroupedTableExchangeRateDifferencesAccountsReceivable.GLAccount
	|	END AS AccountCr,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences < 0
	|				AND GroupedTableExchangeRateDifferencesAccountsReceivable.GLAccountCurrency
	|			THEN GroupedTableExchangeRateDifferencesAccountsReceivable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences > 0
	|			THEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences
	|		ELSE -GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences
	|	END AS Amount,
	|	&ExchangeDifference AS ExchangeDifference,
	|	FALSE AS OfflineRecord
	|FROM
	|	GroupedTableExchangeRateDifferencesAccountsReceivable AS GroupedTableExchangeRateDifferencesAccountsReceivable";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefCreditNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventoryInWarehouses.Period AS Period,
	|	TableInventoryInWarehouses.Recorder AS Recorder,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventoryInWarehouses.Company AS Company,
	|	TableInventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|	TableInventoryInWarehouses.Products AS Products,
	|	TableInventoryInWarehouses.Characteristic AS Characteristic,
	|	TableInventoryInWarehouses.Batch AS Batch,
	|	TableInventoryInWarehouses.Ownership AS Ownership,
	|	TableInventoryInWarehouses.Cell AS Cell,
	|	TableInventoryInWarehouses.ReturnQuantity AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventoryInWarehouses
	|WHERE
	|	TableInventoryInWarehouses.ThisIsInventoryItem
	|	AND TableInventoryInWarehouses.Shipped
	|	AND NOT TableInventoryInWarehouses.DropShipping";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefCreditNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Period AS Period,
	|	TableInventory.Recorder AS Recorder,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.Counterparty AS Counterparty,
	|	TableInventory.DocumentCurrency AS Currency,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.CostObject AS CostObject,
	|	TableInventory.InventoryGLAccount AS GLAccount,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.InventoryAccountType AS CorrInventoryAccountType,
	|	TableInventory.GLAccountCostOfSales AS CorrGLAccount,
	|	TableInventory.ReturnQuantity AS Quantity,
	|	CASE
	|		WHEN NOT &FillAmount
	|			THEN 0
	|		ELSE TableInventory.CostOfGoodsSold
	|	END AS Amount,
	|	TableInventory.OperationKind AS ContentOfAccountingRecord,
	|	TableInventory.SalesRep AS SalesRep,
	|	CASE
	|		WHEN TableInventory.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.Order
	|	END AS SalesOrder,
	|	CASE
	|		WHEN TableInventory.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.Order
	|	END AS CorrSalesOrder,
	|	CASE
	|		WHEN TableInventory.SalesDocument <> VALUE(Document.SalesInvoice.EmptyRef)
	|			THEN TableInventory.SalesDocument
	|		WHEN VALUETYPE(TableInventory.BasisDocument) = TYPE(Document.SalesSlip)
	|			THEN TableInventory.ShiftClosure
	|		ELSE TableInventory.BasisDocument
	|	END AS SourceDocument,
	|	TableInventory.Department AS Department,
	|	TableInventory.Responsible AS Responsible,
	|	TableInventory.VATRate AS VATRate,
	|	TRUE AS Return,
	|	FALSE AS OfflineRecord,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN TableInventory.CostOfGoodsSold > 0
	|				AND &FillAmount
	|			THEN TableInventory.COGSItem
	|		ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|	END AS CorrIncomeAndExpenseItem
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.OperationKind = VALUE(Enum.OperationTypesCreditNote.SalesReturn)
	|	AND TableInventory.ThisIsInventoryItem
	|	AND TableInventory.Shipped
	|
	|UNION ALL
	|
	|SELECT
	|	TableIncomeAndExpenses.Date,
	|	TableIncomeAndExpenses.Ref,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.PresentationCurrency,
	|	TableIncomeAndExpenses.Counterparty,
	|	TableIncomeAndExpenses.DocumentCurrency,
	|	TableIncomeAndExpenses.StructuralUnit,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	&OwnInventory,
	|	VALUE(Catalog.CostObjects.EmptyRef),
	|	TableIncomeAndExpenses.GLAccount,
	|	VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads),
	|	VALUE(Enum.InventoryAccountTypes.EmptyRef),
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef),
	|	0,
	|	SUM(TableIncomeAndExpenses.Amount),
	|	&OtherExpenses,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableIncomeAndExpenses.Department,
	|	TableIncomeAndExpenses.Responsible,
	|	TableIncomeAndExpenses.VATRate,
	|	FALSE,
	|	FALSE,
	|	TableIncomeAndExpenses.ExpenseItem,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|FROM
	|	TemporaryTableDocAmountAllocation AS TableIncomeAndExpenses
	|WHERE
	|	TableIncomeAndExpenses.OperationKind = VALUE(Enum.OperationTypesCreditNote.Adjustments)
	|	AND TableIncomeAndExpenses.RegisterExpense
	|	AND TableIncomeAndExpenses.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Date,
	|	TableIncomeAndExpenses.Ref,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.PresentationCurrency,
	|	TableIncomeAndExpenses.Counterparty,
	|	TableIncomeAndExpenses.DocumentCurrency,
	|	TableIncomeAndExpenses.StructuralUnit,
	|	TableIncomeAndExpenses.GLAccount,
	|	TableIncomeAndExpenses.Department,
	|	TableIncomeAndExpenses.Responsible,
	|	TableIncomeAndExpenses.VATRate,
	|	TableIncomeAndExpenses.ExpenseItem
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Recorder,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.Counterparty,
	|	OfflineRecords.Currency,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.Ownership,
	|	OfflineRecords.CostObject,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.InventoryAccountType,
	|	OfflineRecords.CorrInventoryAccountType,
	|	OfflineRecords.CorrGLAccount,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.Amount,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.SalesRep,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.CorrSalesOrder,
	|	OfflineRecords.SourceDocument,
	|	OfflineRecords.Department,
	|	OfflineRecords.Responsible,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.Return,
	|	OfflineRecords.OfflineRecord,
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	FillAmount = 
		(StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage);
		
	Query.SetParameter("FillAmount", FillAmount);
	Query.SetParameter("Ref", DocumentRefCreditNote);
	Query.SetParameter("OwnInventory", Catalogs.InventoryOwnership.OwnInventory());
	Query.SetParameter("OtherExpenses", NStr("en = 'Expenses incurred'; ru = 'Отражение затрат';pl = 'Poniesione rozchody';es_ES = 'Gastos incurridos';es_CO = 'Gastos incurridos';tr = 'Tahakkuk eden giderler';it = 'Spese sostenute';de = 'Anfallende Ausgaben'", CommonClientServer.DefaultLanguageCode()));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRefCreditNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSerialNumbersBalance.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableSerialNumbersBalance.Period AS EventDate,
	|	TableSerialNumbersBalance.Company AS Company,
	|	VALUE(Enum.SerialNumbersOperations.Receipt) AS Operation,
	|	TableSerialNumbersBalance.StructuralUnit AS StructuralUnit,
	|	TableSerialNumbersBalance.Products AS Products,
	|	TableSerialNumbersBalance.Characteristic AS Characteristic,
	|	TableSerialNumbersBalance.Batch AS Batch,
	|	TableSerialNumbersBalance.Ownership AS Ownership,
	|	TableSerialNumbersBalance.Cell AS Cell,
	|	CreditNoteSerialNumbers.SerialNumber AS SerialNumber,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableSerialNumbersBalance
	|		INNER JOIN Document.CreditNote.SerialNumbers AS CreditNoteSerialNumbers
	|		ON TableSerialNumbersBalance.Recorder = CreditNoteSerialNumbers.Ref
	|			AND TableSerialNumbersBalance.ConnectionKey = CreditNoteSerialNumbers.ConnectionKey
	|WHERE
	|	TableSerialNumbersBalance.ThisIsInventoryItem
	|	AND TableSerialNumbersBalance.Quantity > 0
	|
	|GROUP BY
	|	TableSerialNumbersBalance.StructuralUnit,
	|	TableSerialNumbersBalance.OperationKind,
	|	TableSerialNumbersBalance.Period,
	|	TableSerialNumbersBalance.Company,
	|	TableSerialNumbersBalance.Products,
	|	TableSerialNumbersBalance.Characteristic,
	|	TableSerialNumbersBalance.Batch,
	|	TableSerialNumbersBalance.Ownership,
	|	TableSerialNumbersBalance.Cell,
	|	CreditNoteSerialNumbers.SerialNumber,
	|	TableSerialNumbersBalance.Period";
	
	Query.SetParameter("UseSerialNumbers", GetFunctionalOption("UseSerialNumbers"));
	
	QueryResult = Query.Execute();
	
	ResultTable = QueryResult.Unload();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", ResultTable);
	
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", ResultTable);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
	EndIf; 
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Function GenerateTableVATOutput(Query, DocumentRefCreditNote, StructureAdditionalProperties)
	
	If DocumentRefCreditNote.OperationKind = Enums.OperationTypesCreditNote.SalesReturn Then
		Query.Text = 
		"SELECT
		|	CreditNoteInventory.Period AS Period,
		|	CreditNoteInventory.Recorder AS Recorder,
		|	CreditNoteInventory.Company AS Company,
		|	CreditNoteInventory.CompanyVATNumber AS CompanyVATNumber,
		|	CreditNoteInventory.PresentationCurrency AS PresentationCurrency,
		|	CreditNoteInventory.Counterparty AS Customer,
		|	CASE
		|		WHEN CreditNoteInventory.SalesDocument <> VALUE(Document.SalesInvoice.EmptyRef)
		|			THEN CreditNoteInventory.SalesDocument
		|		WHEN VALUETYPE(CreditNoteInventory.BasisDocument) = TYPE(Document.SalesSlip)
		|			THEN CreditNoteInventory.ShiftClosure
		|		ELSE CreditNoteInventory.BasisDocument
		|	END AS ShipmentDocument,
		|	CreditNoteInventory.VATRate AS VATRate,
		|	CreditNoteInventory.VATOutputGLAccount AS GLAccount,
		|	CASE
		|		WHEN CreditNoteInventory.VATTaxation = VALUE(Enum.VATTaxationTypes.ForExport)
		|				OR CreditNoteInventory.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
		|			THEN VALUE(Enum.VATOperationTypes.Export)
		|		ELSE VALUE(Enum.VATOperationTypes.SalesReturn)
		|	END AS OperationType,
		|	CatalogProducts.ProductsType AS ProductType,
		|	-SUM(CreditNoteInventory.Amount) AS AmountExcludesVAT,
		|	-SUM(CreditNoteInventory.VATAmount) AS VATAmount
		|FROM
		|	TemporaryTableInventory AS CreditNoteInventory
		|		LEFT JOIN Catalog.Products AS CatalogProducts
		|		ON CreditNoteInventory.Products = CatalogProducts.Ref
		|WHERE
		|	CreditNoteInventory.Recorder = &Ref
		|
		|GROUP BY
		|	CreditNoteInventory.VATRate,
		|	CreditNoteInventory.VATOutputGLAccount,
		|	CreditNoteInventory.VATTaxation,
		|	CatalogProducts.ProductsType,
		|	CreditNoteInventory.Period,
		|	CreditNoteInventory.Company,
		|	CreditNoteInventory.CompanyVATNumber,
		|	CreditNoteInventory.PresentationCurrency,
		|	CreditNoteInventory.Counterparty,
		|	CASE
		|		WHEN CreditNoteInventory.SalesDocument <> VALUE(Document.SalesInvoice.EmptyRef)
		|			THEN CreditNoteInventory.SalesDocument
		|		WHEN VALUETYPE(CreditNoteInventory.BasisDocument) = TYPE(Document.SalesSlip)
		|			THEN CreditNoteInventory.ShiftClosure
		|		ELSE CreditNoteInventory.BasisDocument
		|	END,
		|	CreditNoteInventory.Recorder,
		|	CASE
		|		WHEN CreditNoteInventory.VATTaxation = VALUE(Enum.VATTaxationTypes.ForExport)
		|				OR CreditNoteInventory.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
		|			THEN VALUE(Enum.VATOperationTypes.Export)
		|		ELSE VALUE(Enum.VATOperationTypes.SalesReturn)
		|	END";
	Else
		Query.Text = 
		"SELECT
		|	CreditNoteAmountAllocation.Period AS Period,
		|	CreditNoteAmountAllocation.Recorder AS Recorder,
		|	CreditNoteAmountAllocation.Company AS Company,
		|	CreditNoteAmountAllocation.CompanyVATNumber AS CompanyVATNumber,
		|	CreditNoteAmountAllocation.PresentationCurrency AS PresentationCurrency,
		|	CreditNoteAmountAllocation.Counterparty AS Customer,
		|	CreditNoteAmountAllocation.Recorder AS ShipmentDocument,
		|	CreditNoteAmountAllocation.VATRate AS VATRate,
		|	CreditNoteAmountAllocation.VATOutputGLAccount AS GLAccount,
		|	CreditNoteAmountAllocation.OperationType AS OperationType,
		|	CreditNoteAmountAllocation.OperationKind AS OperationKind,
		|	VALUE(Enum.ProductsTypes.EmptyRef) AS ProductType,
		|	-SUM(CreditNoteAmountAllocation.Amount) AS AmountExcludesVAT,
		|	-SUM(CreditNoteAmountAllocation.VATAmount) AS VATAmount
		|FROM
		|	TemporaryTableAmountAllocation AS CreditNoteAmountAllocation
		|WHERE
		|	CreditNoteAmountAllocation.Recorder = &Ref
		|
		|GROUP BY
		|	CreditNoteAmountAllocation.OperationType,
		|	CreditNoteAmountAllocation.VATRate,
		|	CreditNoteAmountAllocation.VATOutputGLAccount,
		|	CreditNoteAmountAllocation.Period,
		|	CreditNoteAmountAllocation.OperationKind,
		|	CreditNoteAmountAllocation.Counterparty,
		|	CreditNoteAmountAllocation.Company,
		|	CreditNoteAmountAllocation.CompanyVATNumber,
		|	CreditNoteAmountAllocation.PresentationCurrency,
		|	CreditNoteAmountAllocation.Recorder";
		
	EndIf;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", Query.Execute().Unload());
	
EndFunction

Function GenerateTableGoodsInvoicedNotShipped(DocumentRefCreditNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProducts.Period AS Period,
	|	TableProducts.SalesDocument AS SalesInvoice,
	|	TableProducts.Company AS Company,
	|	TableProducts.PresentationCurrency AS PresentationCurrency,
	|	TableProducts.Counterparty AS Counterparty,
	|	TableProducts.Contract AS Contract,
	|	TableProducts.Order AS SalesOrder,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.VATRate AS VATRate,
	|	TableProducts.Department AS Department,
	|	TableProducts.Responsible AS Responsible,
	|	SUM(TableProducts.ReturnQuantity) AS Quantity,
	|	SUM(TableProducts.Amount) AS Amount,
	|	SUM(TableProducts.VATAmount) AS VATAmount,
	|	SUM(TableProducts.AmountCur) AS AmountCur,
	|	SUM(TableProducts.VATAmountCur) AS VATAmountCur
	|FROM
	|	TemporaryTableInventory AS TableProducts
	|WHERE
	|	NOT TableProducts.Shipped
	|
	|GROUP BY
	|	TableProducts.Company,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.Counterparty,
	|	TableProducts.Contract,
	|	TableProducts.Period,
	|	TableProducts.SalesDocument,
	|	TableProducts.Order,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.VATRate,
	|	TableProducts.Department,
	|	TableProducts.Responsible";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsInvoicedNotShipped", QueryResult.Unload());
	
EndFunction

Procedure GenerateTableTaxPayable(DocumentRefCreditNote, StructureAdditionalProperties)
	
	If Not SalesTaxServer.GetUseSalesTax(DocumentRefCreditNote.Date, DocumentRefCreditNote.Company) Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxPayable", New ValueTable);
		Return;
		
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("SalesTaxAccrued", NStr("en = 'Sales tax accrued'; ru = 'Начисленный налог с продаж';pl = 'Naliczony podatek od sprzedaży';es_ES = 'Impuesto sobre ventas devengado';es_CO = 'Impuesto sobre ventas devengado';tr = 'Tahakkuk eden satış vergisi';it = 'Imposta di vendita maturata';de = 'Angefallene Umsatzsteuer'", CommonClientServer.DefaultLanguageCode()));
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporarySalesTaxAmount.Period AS Period,
	|	TemporarySalesTaxAmount.Company AS Company,
	|	TemporarySalesTaxAmount.PresentationCurrency AS PresentationCurrency,
	|	TemporarySalesTaxAmount.TaxKind AS TaxKind,
	|	TemporarySalesTaxAmount.CompanyVATNumber AS CompanyVATNumber,
	|	TemporarySalesTaxAmount.Amount AS Amount,
	|	&SalesTaxAccrued AS ContentOfAccountingRecord
	|FROM
	|	TemporarySalesTaxAmount AS TemporarySalesTaxAmount";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxPayable", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefCreditNote, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	CreditNote.Date AS Date,
	|	CreditNote.Ref AS Ref,
	|	CreditNote.CompanyVATNumber AS CompanyVATNumber,
	|	CreditNote.Contract AS Contract,
	|	CreditNote.ExchangeRate AS ExchangeRate,
	|	CreditNote.Multiplicity AS Multiplicity,
	|	CreditNote.VATAmount AS VATAmount,
	|	CreditNote.RegisterExpense AS RegisterExpense,
	|	CreditNote.ExpenseItem AS ExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CreditNote.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CreditNote.OperationKind AS OperationKind,
	|	CreditNote.DocumentCurrency AS DocumentCurrency,
	|	CreditNote.VATTaxation AS VATTaxation,
	|	CreditNote.AdjustedAmount AS DocumentAmount,
	|	CreditNote.BasisDocument AS BasisDocument,
	|	CreditNote.Counterparty AS Counterparty,
	|	CreditNote.Department AS Department,
	|	CreditNote.Cell AS Cell,
	|	CreditNote.StructuralUnit AS StructuralUnit,
	|	CreditNote.Responsible AS Responsible,
	|	CreditNote.AmountIncludesVAT AS AmountIncludesVAT,
	|	CreditNote.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	CreditNote.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	CASE
	|		WHEN CreditNote.AmountIncludesVAT
	|				OR CreditNote.OperationKind = VALUE(Enum.OperationTypesCreditNote.SalesReturn)
	|			THEN CreditNote.AdjustedAmount - CreditNote.VATAmount
	|		ELSE CreditNote.AdjustedAmount
	|	END AS Subtotal,
	|	CreditNote.BasisDocumentInTabularSection AS BasisDocumentInTabularSection
	|INTO TemporaryTableDocument
	|FROM
	|	Document.CreditNote AS CreditNote
	|WHERE
	|	CreditNote.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableDocument.Date AS Date,
	|	TemporaryTableDocument.Ref AS Ref,
	|	TemporaryTableDocument.AmountIncludesVAT AS AmountIncludesVAT,
	|	TemporaryTableDocument.Cell AS Cell,
	|	TemporaryTableDocument.StructuralUnit AS StructuralUnit,
	|	TemporaryTableDocument.Responsible AS Responsible,
	|	TemporaryTableDocument.Contract AS Contract,
	|	TemporaryTableDocument.ExchangeRate AS ExchangeRate,
	|	TemporaryTableDocument.Multiplicity AS Multiplicity,
	|	TemporaryTableDocument.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	TemporaryTableDocument.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	TemporaryTableDocument.Counterparty AS Counterparty,
	|	&Company AS Company,
	|	TemporaryTableDocument.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	CAST(TemporaryTableDocument.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryTableDocument.ExchangeRate / TemporaryTableDocument.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN TemporaryTableDocument.Multiplicity / TemporaryTableDocument.ExchangeRate
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	TemporaryTableDocument.RegisterExpense AS RegisterExpense,
	|	TemporaryTableDocument.ExpenseItem AS ExpenseItem,
	|	TemporaryTableDocument.GLAccount AS GLAccount,
	|	TemporaryTableDocument.OperationKind AS OperationKind,
	|	TemporaryTableDocument.Contract.BusinessLine AS BusinessLine,
	|	TemporaryTableDocument.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	CAST(TemporaryTableDocument.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryTableDocument.ExchangeRate * TemporaryTableDocument.ContractCurrencyMultiplicity / (TemporaryTableDocument.ContractCurrencyExchangeRate * TemporaryTableDocument.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (TemporaryTableDocument.ExchangeRate * TemporaryTableDocument.ContractCurrencyMultiplicity / (TemporaryTableDocument.ContractCurrencyExchangeRate * TemporaryTableDocument.Multiplicity))
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(TemporaryTableDocument.Subtotal * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryTableDocument.ExchangeRate / TemporaryTableDocument.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN TemporaryTableDocument.Multiplicity / TemporaryTableDocument.ExchangeRate
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(TemporaryTableDocument.Subtotal * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryTableDocument.ExchangeRate * TemporaryTableDocument.ContractCurrencyMultiplicity / (TemporaryTableDocument.ContractCurrencyExchangeRate * TemporaryTableDocument.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (TemporaryTableDocument.ExchangeRate * TemporaryTableDocument.ContractCurrencyMultiplicity / (TemporaryTableDocument.ContractCurrencyExchangeRate * TemporaryTableDocument.Multiplicity))
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	TemporaryTableDocument.Department AS Department,
	|	TemporaryTableDocument.VATTaxation AS VATTaxation,
	|	TemporaryTableDocument.DocumentCurrency AS DocumentCurrency,
	|	TemporaryTableDocument.BasisDocument AS BasisDocument,
	|	SalesInvoice.Ref AS SalesInvoice,
	|	CASE
	|		WHEN TemporaryTableDocument.BasisDocument REFS Document.RMARequest
	|			THEN ISNULL(SalesInvoice.Order, UNDEFINED)
	|		ELSE UNDEFINED
	|	END AS Order,
	|	CASE
	|		WHEN VALUETYPE(TemporaryTableDocument.BasisDocument) = TYPE(Document.SalesSlip)
	|			THEN SalesSlip.CashCRSession
	|		ELSE VALUE(Document.ShiftClosure.EmptyRef)
	|	END AS ShiftClosure,
	|	ISNULL(SalesSlip.Archival, FALSE) AS Archival,
	|	TemporaryTableDocument.BasisDocumentInTabularSection AS BasisDocumentInTabularSection
	|INTO TemporaryTableHeader
	|FROM
	|	TemporaryTableDocument AS TemporaryTableDocument
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON TemporaryTableDocument.Counterparty = Counterparties.Ref
	|		LEFT JOIN Document.SalesSlip AS SalesSlip
	|		ON TemporaryTableDocument.BasisDocument = SalesSlip.Ref
	|		LEFT JOIN Document.RMARequest AS RMARequest
	|		ON TemporaryTableDocument.BasisDocument = RMARequest.Ref
	|		LEFT JOIN Document.SalesInvoice AS SalesInvoice
	|		ON (RMARequest.Invoice = SalesInvoice.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoice.Ref AS SalesInvoice,
	|	SalesInvoice.Ref AS BasisDocument
	|INTO TemporaryTableSalesInvoice
	|FROM
	|	TemporaryTableDocument AS TemporaryTableDocument
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON TemporaryTableDocument.BasisDocument = SalesInvoice.Ref
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	GoodsReceiptProducts.SalesDocument,
	|	GoodsReceiptProducts.Ref
	|FROM
	|	TemporaryTableDocument AS TemporaryTableDocument
	|		INNER JOIN Document.GoodsReceipt.Products AS GoodsReceiptProducts
	|		ON TemporaryTableDocument.BasisDocument = GoodsReceiptProducts.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	SalesInvoice.Ref,
	|	RMARequest.Ref
	|FROM
	|	TemporaryTableDocument AS TemporaryTableDocument
	|		INNER JOIN Document.RMARequest AS RMARequest
	|		ON TemporaryTableDocument.BasisDocument = RMARequest.Ref
	|		LEFT JOIN Document.SalesInvoice AS SalesInvoice
	|		ON (RMARequest.Invoice = SalesInvoice.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CreditNoteInventory.Ref AS Ref,
	|	CreditNoteInventory.Batch AS Batch,
	|	CreditNoteInventory.Ownership AS Ownership,
	|	CreditNoteInventory.Characteristic AS Characteristic,
	|	CreditNoteInventory.CostOfGoodsSold AS CostOfGoodsSold,
	|	CreditNoteInventory.MeasurementUnit AS MeasurementUnit,
	|	CreditNoteInventory.InitialQuantity AS Quantity,
	|	CreditNoteInventory.InitialPrice AS Price,
	|	CreditNoteInventory.Products AS Products,
	|	CreditNoteInventory.Quantity AS ReturnQuantity,
	|	CreditNoteInventory.VATAmount AS VATAmount,
	|	CreditNoteInventory.VATRate AS VATRate,
	|	CreditNoteInventory.ConnectionKey AS ConnectionKey,
	|	CreditNoteInventory.LineNumber AS LineNumber,
	|	CreditNoteInventory.SalesReturnItem AS SalesReturnItem,
	|	CreditNoteInventory.COGSItem AS COGSItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CreditNoteInventory.SalesReturnGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CreditNoteInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CreditNoteInventory.VATOutputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATOutputGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CreditNoteInventory.COGSGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS COGSGLAccount,
	|	CASE
	|		WHEN TemporaryTableHeader.AmountIncludesVAT
	|			THEN CreditNoteInventory.Amount - CreditNoteInventory.VATAmount
	|		ELSE CreditNoteInventory.Amount
	|	END AS Amount,
	|	CASE
	|		WHEN TemporaryTableHeader.Order = UNDEFINED
	|			THEN CreditNoteInventory.Order
	|	END AS Order,
	|	CreditNoteInventory.SalesRep AS SalesRep,
	|	CreditNoteInventory.GoodsReceipt AS GoodsReceipt,
	|	CreditNoteInventory.BundleProduct AS BundleProduct,
	|	CreditNoteInventory.BundleCharacteristic AS BundleCharacteristic,
	|	TemporaryTableHeader.Cell AS Cell,
	|	CASE
	|		WHEN CreditNoteInventory.DropShipping
	|			THEN VALUE(Catalog.BusinessUnits.DropShipping)
	|		ELSE TemporaryTableHeader.StructuralUnit
	|	END AS StructuralUnit,
	|	TemporaryTableHeader.Responsible AS Responsible,
	|	TemporaryTableHeader.Date AS Date,
	|	TemporaryTableHeader.Contract AS Contract,
	|	TemporaryTableHeader.OperationKind AS OperationKind,
	|	TemporaryTableHeader.DocumentCurrency AS DocumentCurrency,
	|	TemporaryTableHeader.ExchangeRate AS ExchangeRate,
	|	TemporaryTableHeader.Multiplicity AS Multiplicity,
	|	TemporaryTableHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	TemporaryTableHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	TemporaryTableHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	TemporaryTableHeader.VATTaxation AS VATTaxation,
	|	TemporaryTableHeader.Department AS Department,
	|	TemporaryTableHeader.BasisDocument AS BasisDocument,
	|	TemporaryTableHeader.Counterparty AS Counterparty,
	|	TemporaryTableHeader.ShiftClosure AS ShiftClosure,
	|	CASE
	|		WHEN TemporaryTableHeader.BasisDocumentInTabularSection
	|			THEN CreditNoteInventory.SalesDocument
	|		ELSE ISNULL(TemporaryTableSalesInvoice.SalesInvoice, VALUE(Document.SalesInvoice.EmptyRef))
	|	END AS SalesDocument,
	|	TemporaryTableHeader.Archival AS Archival,
	|	TemporaryTableHeader.BusinessLine AS BusinessLine,
	|	TemporaryTableHeader.SettlementsCurrency AS SettlementsCurrency,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CreditNoteInventory.UnearnedRevenueGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS UnearnedRevenueGLAccount,
	|	CreditNoteInventory.Shipped AS Shipped,
	|	CreditNoteInventory.Taxable AS Taxable,
	|	CreditNoteInventory.SalesTaxAmount AS SalesTaxAmount,
	|	CreditNoteInventory.DropShipping AS DropShipping
	|INTO TemporaryTableDocInventory
	|FROM
	|	TemporaryTableHeader AS TemporaryTableHeader
	|		INNER JOIN Document.CreditNote.Inventory AS CreditNoteInventory
	|		ON TemporaryTableHeader.Ref = CreditNoteInventory.Ref
	|		LEFT JOIN TemporaryTableSalesInvoice AS TemporaryTableSalesInvoice
	|		ON TemporaryTableHeader.BasisDocument = TemporaryTableSalesInvoice.BasisDocument
	|WHERE
	|	CreditNoteInventory.Amount <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableDocInventory.Ref AS Recorder,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN TemporaryTableDocInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	TemporaryTableDocInventory.Ownership AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TemporaryTableDocInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN NOT &UseGoodsReturnFromCustomer
	|				OR TemporaryTableDocInventory.Products.ProductsType <> VALUE(Enum.ProductsTypes.InventoryItem)
	|			THEN TemporaryTableDocInventory.CostOfGoodsSold
	|		ELSE 0
	|	END AS CostOfGoodsSold,
	|	TemporaryTableDocInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN VALUETYPE(TemporaryTableDocInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN TemporaryTableDocInventory.Quantity
	|		ELSE TemporaryTableDocInventory.Quantity * TemporaryTableDocInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	TemporaryTableDocInventory.Products AS Products,
	|	CASE
	|		WHEN VALUETYPE(TemporaryTableDocInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN TemporaryTableDocInventory.ReturnQuantity
	|		ELSE TemporaryTableDocInventory.ReturnQuantity * TemporaryTableDocInventory.MeasurementUnit.Factor
	|	END AS ReturnQuantity,
	|	TemporaryTableDocInventory.Date AS Period,
	|	TemporaryTableDocInventory.Counterparty AS Counterparty,
	|	TemporaryTableDocInventory.DocumentCurrency AS DocumentCurrency,
	|	TemporaryTableDocInventory.Department AS Department,
	|	TemporaryTableDocInventory.BasisDocument AS BasisDocument,
	|	TemporaryTableDocInventory.Responsible AS Responsible,
	|	TemporaryTableDocInventory.VATRate AS VATRate,
	|	TemporaryTableDocInventory.VATAmount AS VATAmount,
	|	&Company AS Company,
	|	TemporaryTableDocInventory.Ref.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableDocInventory.Amount + TemporaryTableDocInventory.SalesTaxAmount AS Amount,
	|	TemporaryTableDocInventory.BusinessLine AS BusinessLine,
	|	TemporaryTableDocInventory.LineNumber AS LineNumber,
	|	TemporaryTableDocInventory.SalesReturnItem AS SalesReturnItem,
	|	TemporaryTableDocInventory.COGSItem AS COGSItem,
	|	TemporaryTableDocInventory.GLAccount AS GLAccount,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS InventoryAccountType,
	|	TemporaryTableDocInventory.Order AS Order,
	|	TemporaryTableDocInventory.SalesRep AS SalesRep,
	|	TemporaryTableDocInventory.OperationKind AS OperationKind,
	|	TemporaryTableDocInventory.StructuralUnit AS StructuralUnit,
	|	TemporaryTableDocInventory.Cell AS Cell,
	|	TemporaryTableDocInventory.ConnectionKey AS ConnectionKey,
	|	TemporaryTableDocInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ThisIsInventoryItem,
	|	TemporaryTableDocInventory.InventoryGLAccount AS InventoryGLAccount,
	|	TemporaryTableDocInventory.COGSGLAccount AS GLAccountCostOfSales,
	|	TemporaryTableDocInventory.ShiftClosure AS ShiftClosure,
	|	TemporaryTableDocInventory.SalesDocument AS SalesDocument,
	|	TemporaryTableDocInventory.Archival AS Archival,
	|	TemporaryTableDocInventory.VATOutputGLAccount AS VATOutputGLAccount,
	|	TemporaryTableDocInventory.VATTaxation AS VATTaxation,
	|	TemporaryTableDocInventory.SettlementsCurrency AS SettlementsCurrency,
	|	TemporaryTableDocInventory.ExchangeRate AS ExchangeRate,
	|	TemporaryTableDocInventory.Multiplicity AS Multiplicity,
	|	TemporaryTableDocInventory.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	TemporaryTableDocInventory.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	CASE
	|		WHEN TemporaryTableDocInventory.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS RetailTransferEarningAccounting,
	|	TemporaryTableDocInventory.GoodsReceipt AS GoodsReceipt,
	|	TemporaryTableDocInventory.Contract AS Contract,
	|	TemporaryTableDocInventory.BundleProduct AS BundleProduct,
	|	TemporaryTableDocInventory.BundleCharacteristic AS BundleCharacteristic,
	|	TemporaryTableDocInventory.UnearnedRevenueGLAccount AS UnearnedRevenueGLAccount,
	|	TemporaryTableDocInventory.Shipped AS Shipped,
	|	TemporaryTableDocInventory.Taxable AS Taxable,
	|	TemporaryTableDocInventory.SalesTaxAmount AS SalesTaxAmount,
	|	TemporaryTableDocInventory.DropShipping AS DropShipping
	|INTO TemporaryTableInventoryPrev
	|FROM
	|	TemporaryTableDocInventory AS TemporaryTableDocInventory
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON TemporaryTableDocInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON TemporaryTableDocInventory.StructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CreditNoteAmountAllocation.Ref AS Ref,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableHeader.CompanyVATNumber AS CompanyVATNumber,
	|	CreditNoteAmountAllocation.Contract AS Contract,
	|	CreditNoteAmountAllocation.AdvanceFlag AS AdvanceFlag,
	|	CreditNoteAmountAllocation.Document AS Document,
	|	CreditNoteAmountAllocation.OffsetAmount - CreditNoteAmountAllocation.VATAmount AS Amount,
	|	CreditNoteAmountAllocation.Order AS Order,
	|	TemporaryTableHeader.Date AS Date,
	|	TemporaryTableHeader.ExchangeRate AS ExchangeRate,
	|	TemporaryTableHeader.Multiplicity AS Multiplicity,
	|	TemporaryTableHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	TemporaryTableHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	TemporaryTableHeader.Counterparty AS Counterparty,
	|	TemporaryTableHeader.OperationKind AS OperationKind,
	|	TemporaryTableHeader.VATTaxation AS VATTaxation,
	|	TemporaryTableHeader.StructuralUnit AS StructuralUnit,
	|	TemporaryTableHeader.Department AS Department,
	|	TemporaryTableHeader.Responsible AS Responsible,
	|	TemporaryTableHeader.BusinessLine AS BusinessLine,
	|	TemporaryTableHeader.DocumentCurrency AS DocumentCurrency,
	|	CreditNoteAmountAllocation.VATRate AS VATRate,
	|	CreditNoteAmountAllocation.VATAmount AS VATAmount,
	|	TemporaryTableHeader.RegisterExpense AS RegisterExpense,
	|	TemporaryTableHeader.ExpenseItem AS ExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CreditNoteAmountAllocation.AdvancesReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CustomerAdvancesGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN CreditNoteAmountAllocation.AdvanceFlag
	|						THEN CreditNoteAmountAllocation.AdvancesReceivedGLAccount
	|					ELSE CreditNoteAmountAllocation.AccountsReceivableGLAccount
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountCustomerSettlements,
	|	CASE
	|		WHEN CreditNoteAmountAllocation.AdvanceFlag
	|			THEN AdvancesReceived.Currency
	|		ELSE AccountsReceivable.Currency
	|	END AS GLAccountCustomerSettlementsCurrency,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CreditNoteAmountAllocation.VATOutputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATOutputGLAccount,
	|	CreditNoteAmountAllocation.LineNumber AS LineNumber,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TemporaryTableHeader.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	PrimaryChartOfAccounts.Currency AS GLAccountCurrency,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	CASE
	|		WHEN TemporaryTableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ForExport)
	|				OR TemporaryTableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN VALUE(Enum.VATOperationTypes.Export)
	|		WHEN TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCreditNote.Adjustments)
	|			THEN VALUE(Enum.VATOperationTypes.OtherAdjustments)
	|		WHEN TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCreditNote.DiscountAllowed)
	|			THEN VALUE(Enum.VATOperationTypes.DiscountAllowed)
	|	END AS OperationType
	|INTO TemporaryTableDocAmountAllocation
	|FROM
	|	TemporaryTableHeader AS TemporaryTableHeader
	|		INNER JOIN Document.CreditNote.AmountAllocation AS CreditNoteAmountAllocation
	|		ON TemporaryTableHeader.Ref = CreditNoteAmountAllocation.Ref
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS AccountsReceivable
	|		ON (CreditNoteAmountAllocation.AccountsReceivableGLAccount = AccountsReceivable.Ref)
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON TemporaryTableHeader.GLAccount = PrimaryChartOfAccounts.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON (CreditNoteAmountAllocation.Contract = CounterpartyContracts.Ref)
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS AdvancesReceived
	|		ON (CreditNoteAmountAllocation.AdvancesReceivedGLAccount = AdvancesReceived.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AmountAllocation.LineNumber AS LineNumber,
	|	ISNULL(SUM(AmountAllocationForInterval.Amount), 0) + 0.01 AS AllocationFrom,
	|	ISNULL(SUM(AmountAllocationForInterval.Amount), 0) + AmountAllocation.Amount AS AllocationTo
	|INTO AmountAllocationTable
	|FROM
	|	TemporaryTableDocAmountAllocation AS AmountAllocation
	|		LEFT JOIN TemporaryTableDocAmountAllocation AS AmountAllocationForInterval
	|		ON AmountAllocation.LineNumber > AmountAllocationForInterval.LineNumber
	|
	|GROUP BY
	|	AmountAllocation.LineNumber,
	|	AmountAllocation.Amount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryAllocation.LineNumber AS LineNumber,
	|	ISNULL(SUM(InventoryForInterval.Amount), 0) + 0.01 AS AllocationFrom,
	|	ISNULL(SUM(InventoryForInterval.Amount), 0) + InventoryAllocation.Amount AS AllocationTo
	|INTO InventoryAllocationTable
	|FROM
	|	TemporaryTableInventoryPrev AS InventoryAllocation
	|		LEFT JOIN TemporaryTableInventoryPrev AS InventoryForInterval
	|		ON InventoryAllocation.LineNumber > InventoryForInterval.LineNumber
	|
	|GROUP BY
	|	InventoryAllocation.LineNumber,
	|	InventoryAllocation.Amount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AmountAllocation.LineNumber AS LineNumber,
	|	InventoryAllocation.LineNumber AS InventoryLineNumber,
	|	CASE
	|		WHEN InventoryAllocation.AllocationTo < AmountAllocation.AllocationTo
	|			THEN InventoryAllocation.AllocationTo
	|		ELSE AmountAllocation.AllocationTo
	|	END - CASE
	|		WHEN InventoryAllocation.AllocationFrom > AmountAllocation.AllocationFrom
	|			THEN InventoryAllocation.AllocationFrom
	|		ELSE AmountAllocation.AllocationFrom
	|	END + 0.01 AS Amount
	|INTO AmountAllocationInventoryTable
	|FROM
	|	AmountAllocationTable AS AmountAllocation
	|		INNER JOIN InventoryAllocationTable AS InventoryAllocation
	|		ON AmountAllocation.AllocationFrom <= InventoryAllocation.AllocationTo
	|			AND AmountAllocation.AllocationTo >= InventoryAllocation.AllocationFrom
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AmountAllocationInventoryTable.LineNumber AS LineNumber,
	|	AmountAllocationInventoryTable.InventoryLineNumber AS InventoryLineNumber,
	|	TemporaryTableInventoryPrev.Amount AS InitialAmount,
	|	TemporaryTableInventoryPrev.VATAmount AS InitialVATAmount,
	|	TemporaryTableInventoryPrev.SalesTaxAmount AS InitialSalesTaxAmount,
	|	AmountAllocationInventoryTable.Amount AS Amount,
	|	CAST(TemporaryTableInventoryPrev.VATAmount * (AmountAllocationInventoryTable.Amount / TemporaryTableInventoryPrev.Amount) AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(TemporaryTableInventoryPrev.SalesTaxAmount * (AmountAllocationInventoryTable.Amount / TemporaryTableInventoryPrev.Amount) AS NUMBER(15, 2)) AS SalesTaxAmount
	|INTO AmountAllocationInventoryWithVAT
	|FROM
	|	AmountAllocationInventoryTable AS AmountAllocationInventoryTable
	|		INNER JOIN TemporaryTableInventoryPrev AS TemporaryTableInventoryPrev
	|		ON AmountAllocationInventoryTable.InventoryLineNumber = TemporaryTableInventoryPrev.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AmountAllocationInventoryWithVAT.InventoryLineNumber AS InventoryLineNumber,
	|	MIN(AmountAllocationInventoryWithVAT.InitialVATAmount) AS InitialVATAmount,
	|	SUM(AmountAllocationInventoryWithVAT.VATAmount) AS VATAmount,
	|	MIN(AmountAllocationInventoryWithVAT.InitialSalesTaxAmount) AS InitialSalesTaxAmount,
	|	SUM(AmountAllocationInventoryWithVAT.SalesTaxAmount) AS SalesTaxAmount
	|INTO AmountAllocationInventoryVATComparison
	|FROM
	|	AmountAllocationInventoryWithVAT AS AmountAllocationInventoryWithVAT
	|
	|GROUP BY
	|	AmountAllocationInventoryWithVAT.InventoryLineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AmountAllocationInventoryVATComparison.InitialVATAmount - AmountAllocationInventoryVATComparison.VATAmount AS DiffVATAmount,
	|	AmountAllocationInventoryVATComparison.InventoryLineNumber AS InventoryLineNumber
	|INTO VATAmountDifference
	|FROM
	|	AmountAllocationInventoryVATComparison AS AmountAllocationInventoryVATComparison
	|WHERE
	|	AmountAllocationInventoryVATComparison.InitialVATAmount <> AmountAllocationInventoryVATComparison.VATAmount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AmountAllocationSalesTaxComparison.InitialSalesTaxAmount - AmountAllocationSalesTaxComparison.SalesTaxAmount AS DiffSalesTaxAmount,
	|	AmountAllocationSalesTaxComparison.InventoryLineNumber AS InventoryLineNumber
	|INTO SalesTaxAmountDiff
	|FROM
	|	AmountAllocationInventoryVATComparison AS AmountAllocationSalesTaxComparison
	|WHERE
	|	AmountAllocationSalesTaxComparison.InitialSalesTaxAmount <> AmountAllocationSalesTaxComparison.SalesTaxAmount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AmountAllocationInventoryTable.InventoryLineNumber AS InventoryLineNumber,
	|	MAX(AmountAllocationInventoryTable.Amount) AS Amount
	|INTO AmountMax
	|FROM
	|	AmountAllocationInventoryTable AS AmountAllocationInventoryTable
	|
	|GROUP BY
	|	AmountAllocationInventoryTable.InventoryLineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AmountAllocationInventoryTable.InventoryLineNumber AS InventoryLineNumber,
	|	MAX(AmountAllocationInventoryTable.LineNumber) AS LineNumber
	|INTO LineNumberMax
	|FROM
	|	AmountAllocationInventoryTable AS AmountAllocationInventoryTable
	|		INNER JOIN AmountMax AS AmountMax
	|		ON AmountAllocationInventoryTable.InventoryLineNumber = AmountMax.InventoryLineNumber
	|			AND AmountAllocationInventoryTable.Amount = AmountMax.Amount
	|
	|GROUP BY
	|	AmountAllocationInventoryTable.InventoryLineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	LineNumberMax.InventoryLineNumber AS InventoryLineNumber,
	|	LineNumberMax.LineNumber AS LineNumber,
	|	VATAmountDifference.DiffVATAmount AS DiffVATAmount
	|INTO LineAmountDifferenceLineNumber
	|FROM
	|	VATAmountDifference AS VATAmountDifference
	|		INNER JOIN LineNumberMax AS LineNumberMax
	|		ON VATAmountDifference.InventoryLineNumber = LineNumberMax.InventoryLineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	LineNumberMax.InventoryLineNumber AS InventoryLineNumber,
	|	LineNumberMax.LineNumber AS LineNumber,
	|	SalesTaxAmountDiff.DiffSalesTaxAmount AS DiffSalesTaxAmount
	|INTO SalesTaxAmountDiffLineNumber
	|FROM
	|	SalesTaxAmountDiff AS SalesTaxAmountDiff
	|		INNER JOIN LineNumberMax AS LineNumberMax
	|		ON SalesTaxAmountDiff.InventoryLineNumber = LineNumberMax.InventoryLineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AmountAllocationInventoryWithVAT.LineNumber AS LineNumber,
	|	AmountAllocationInventoryWithVAT.InventoryLineNumber AS InventoryLineNumber,
	|	AmountAllocationInventoryWithVAT.Amount AS Amount,
	|	AmountAllocationInventoryWithVAT.VATAmount + ISNULL(LineAmountDifferenceLineNumber.DiffVATAmount, 0) AS VATAmount,
	|	AmountAllocationInventoryWithVAT.SalesTaxAmount + ISNULL(SalesTaxAmountDiffLineNumber.DiffSalesTaxAmount, 0) AS SalesTaxAmount
	|INTO AmountAllocationWithVAT
	|FROM
	|	AmountAllocationInventoryWithVAT AS AmountAllocationInventoryWithVAT
	|		LEFT JOIN LineAmountDifferenceLineNumber AS LineAmountDifferenceLineNumber
	|		ON AmountAllocationInventoryWithVAT.LineNumber = LineAmountDifferenceLineNumber.LineNumber
	|			AND AmountAllocationInventoryWithVAT.InventoryLineNumber = LineAmountDifferenceLineNumber.InventoryLineNumber
	|		LEFT JOIN SalesTaxAmountDiffLineNumber AS SalesTaxAmountDiffLineNumber
	|		ON AmountAllocationInventoryWithVAT.LineNumber = SalesTaxAmountDiffLineNumber.LineNumber
	|			AND AmountAllocationInventoryWithVAT.InventoryLineNumber = SalesTaxAmountDiffLineNumber.InventoryLineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AmountAllocationWithVAT.LineNumber AS LineNumber,
	|	AmountAllocationWithVAT.InventoryLineNumber AS InventoryLineNumber,
	|	AmountAllocationWithVAT.Amount AS AmountDocCur,
	|	AmountAllocationWithVAT.VATAmount AS VATAmountDocCur,
	|	AmountAllocationWithVAT.SalesTaxAmount AS SalesTaxAmountDocCur,
	|	CAST(AmountAllocationWithVAT.Amount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryTableInventoryPrev.ExchangeRate * TemporaryTableInventoryPrev.ContractCurrencyMultiplicity / (TemporaryTableInventoryPrev.ContractCurrencyExchangeRate * TemporaryTableInventoryPrev.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (TemporaryTableInventoryPrev.ExchangeRate * TemporaryTableInventoryPrev.ContractCurrencyMultiplicity / (TemporaryTableInventoryPrev.ContractCurrencyExchangeRate * TemporaryTableInventoryPrev.Multiplicity))
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	CAST(AmountAllocationWithVAT.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryTableInventoryPrev.ExchangeRate * TemporaryTableInventoryPrev.ContractCurrencyMultiplicity / (TemporaryTableInventoryPrev.ContractCurrencyExchangeRate * TemporaryTableInventoryPrev.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (TemporaryTableInventoryPrev.ExchangeRate * TemporaryTableInventoryPrev.ContractCurrencyMultiplicity / (TemporaryTableInventoryPrev.ContractCurrencyExchangeRate * TemporaryTableInventoryPrev.Multiplicity))
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(AmountAllocationWithVAT.Amount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryTableInventoryPrev.ExchangeRate / TemporaryTableInventoryPrev.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN TemporaryTableInventoryPrev.Multiplicity / TemporaryTableInventoryPrev.ExchangeRate
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(AmountAllocationWithVAT.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryTableInventoryPrev.ExchangeRate / TemporaryTableInventoryPrev.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN TemporaryTableInventoryPrev.Multiplicity / TemporaryTableInventoryPrev.ExchangeRate
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(AmountAllocationWithVAT.SalesTaxAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryTableInventoryPrev.ExchangeRate * TemporaryTableInventoryPrev.ContractCurrencyMultiplicity / (TemporaryTableInventoryPrev.ContractCurrencyExchangeRate * TemporaryTableInventoryPrev.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (TemporaryTableInventoryPrev.ExchangeRate * TemporaryTableInventoryPrev.ContractCurrencyMultiplicity / (TemporaryTableInventoryPrev.ContractCurrencyExchangeRate * TemporaryTableInventoryPrev.Multiplicity))
	|		END AS NUMBER(15, 2)) AS SalesTaxAmountCur,
	|	CAST(AmountAllocationWithVAT.SalesTaxAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryTableInventoryPrev.ExchangeRate / TemporaryTableInventoryPrev.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN TemporaryTableInventoryPrev.Multiplicity / TemporaryTableInventoryPrev.ExchangeRate
	|		END AS NUMBER(15, 2)) AS SalesTaxAmount,
	|	TemporaryTableDocAmountAllocation.AdvanceFlag AS AdvanceFlag,
	|	TemporaryTableDocAmountAllocation.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	TemporaryTableDocAmountAllocation.SettlementsCurrency AS SettlementsCurrency,
	|	TemporaryTableDocAmountAllocation.OperationKind AS OperationKind,
	|	TemporaryTableInventoryPrev.VATOutputGLAccount AS VATOutputGLAccount,
	|	TemporaryTableInventoryPrev.GLAccount AS GLAccount,
	|	TemporaryTableDocAmountAllocation.VATTaxation AS VATTaxation,
	|	TemporaryTableDocAmountAllocation.Company AS Company,
	|	TemporaryTableDocAmountAllocation.CompanyVATNumber AS CompanyVATNumber,
	|	TemporaryTableDocAmountAllocation.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableDocAmountAllocation.Ref AS Ref,
	|	TemporaryTableDocAmountAllocation.Date AS Date,
	|	TemporaryTableDocAmountAllocation.GLAccountCurrency AS GLAccountCurrency,
	|	TemporaryTableDocAmountAllocation.GLAccountCustomerSettlementsCurrency AS GLAccountCustomerSettlementsCurrency,
	|	TemporaryTableInventoryPrev.UnearnedRevenueGLAccount AS UnearnedRevenueGLAccount,
	|	UnearnedRevenue.Currency AS UnearnedRevenueGLAccountCurrency,
	|	TemporaryTableInventoryPrev.Shipped AS Shipped,
	|	TemporaryTableInventoryPrev.Taxable AS Taxable
	|INTO BasicAmountAllocation
	|FROM
	|	AmountAllocationWithVAT AS AmountAllocationWithVAT
	|		INNER JOIN TemporaryTableInventoryPrev AS TemporaryTableInventoryPrev
	|			LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS UnearnedRevenue
	|			ON TemporaryTableInventoryPrev.UnearnedRevenueGLAccount = UnearnedRevenue.Ref
	|		ON AmountAllocationWithVAT.InventoryLineNumber = TemporaryTableInventoryPrev.LineNumber
	|		INNER JOIN TemporaryTableDocAmountAllocation AS TemporaryTableDocAmountAllocation
	|		ON AmountAllocationWithVAT.LineNumber = TemporaryTableDocAmountAllocation.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasicAmountAllocation.InventoryLineNumber AS InventoryLineNumber,
	|	SUM(BasicAmountAllocation.AmountDocCur) AS AmountDocCur,
	|	SUM(BasicAmountAllocation.VATAmountDocCur) AS VATAmountDocCur,
	|	SUM(BasicAmountAllocation.AmountCur) AS AmountCur,
	|	SUM(BasicAmountAllocation.VATAmountCur) AS VATAmountCur,
	|	SUM(BasicAmountAllocation.Amount) AS Amount,
	|	SUM(BasicAmountAllocation.VATAmount) AS VATAmount,
	|	SUM(BasicAmountAllocation.SalesTaxAmountDocCur) AS SalesTaxAmountDocCur,
	|	SUM(BasicAmountAllocation.SalesTaxAmount) AS SalesTaxAmount,
	|	SUM(BasicAmountAllocation.SalesTaxAmountCur) AS SalesTaxAmountCur
	|INTO BasicAmountAllocationInventory
	|FROM
	|	BasicAmountAllocation AS BasicAmountAllocation
	|
	|GROUP BY
	|	BasicAmountAllocation.InventoryLineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasicAmountAllocation.LineNumber AS LineNumber,
	|	SUM(BasicAmountAllocation.AmountCur) AS AmountCur,
	|	SUM(BasicAmountAllocation.VATAmountCur) AS VATAmountCur,
	|	SUM(BasicAmountAllocation.Amount) AS Amount,
	|	SUM(BasicAmountAllocation.VATAmount) AS VATAmount,
	|	SUM(BasicAmountAllocation.SalesTaxAmount) AS SalesTaxAmount,
	|	SUM(BasicAmountAllocation.SalesTaxAmountCur) AS SalesTaxAmountCur
	|INTO BasicAmountAllocationCustomer
	|FROM
	|	BasicAmountAllocation AS BasicAmountAllocation
	|
	|GROUP BY
	|	BasicAmountAllocation.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableDocAmountAllocation.Date AS Period,
	|	TemporaryTableDocAmountAllocation.Ref AS Recorder,
	|	&Company AS Company,
	|	TemporaryTableDocAmountAllocation.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableDocAmountAllocation.Counterparty AS Counterparty,
	|	TemporaryTableDocAmountAllocation.Contract AS Contract,
	|	CASE
	|		WHEN TemporaryTableDocAmountAllocation.AdvanceFlag
	|			THEN TemporaryTableDocAmountAllocation.Ref
	|		ELSE TemporaryTableDocAmountAllocation.Document
	|	END AS Document,
	|	TemporaryTableDocAmountAllocation.Order AS Order,
	|	TemporaryTableDocAmountAllocation.AdvanceFlag AS AdvanceFlag,
	|	TemporaryTableDocAmountAllocation.OperationKind AS OperationKind,
	|	TemporaryTableDocAmountAllocation.LineNumber AS LineNumber,
	|	CASE
	|		WHEN TemporaryTableDocAmountAllocation.AdvanceFlag
	|			THEN TemporaryTableDocAmountAllocation.CustomerAdvancesGLAccount
	|		ELSE TemporaryTableDocAmountAllocation.GLAccountCustomerSettlements
	|	END AS GLAccountCustomerSettlements,
	|	TemporaryTableDocAmountAllocation.VATRate AS VATRate,
	|	TemporaryTableDocAmountAllocation.VATTaxation AS VATTaxation,
	|	TemporaryTableDocAmountAllocation.GLAccount AS GLAccount,
	|	TemporaryTableDocAmountAllocation.GLAccountCurrency AS GLAccountCurrency,
	|	TemporaryTableDocAmountAllocation.SettlementsCurrency AS SettlementsCurrency,
	|	TemporaryTableDocAmountAllocation.OperationType AS OperationType,
	|	TemporaryTableDocAmountAllocation.VATOutputGLAccount AS VATOutputGLAccount,
	|	BasicAmountAllocationCustomer.AmountCur AS AmountCur,
	|	BasicAmountAllocationCustomer.VATAmountCur AS VATAmountCur,
	|	BasicAmountAllocationCustomer.Amount AS Amount,
	|	BasicAmountAllocationCustomer.VATAmount AS VATAmount,
	|	BasicAmountAllocationCustomer.SalesTaxAmount AS SalesTaxAmount,
	|	BasicAmountAllocationCustomer.SalesTaxAmountCur AS SalesTaxAmountCur,
	|	TemporaryTableDocAmountAllocation.GLAccountCustomerSettlementsCurrency AS GLAccountCustomerSettlementsCurrency
	|INTO TemporaryTableAmountAllocation
	|FROM
	|	TemporaryTableDocAmountAllocation AS TemporaryTableDocAmountAllocation
	|		INNER JOIN BasicAmountAllocationCustomer AS BasicAmountAllocationCustomer
	|		ON TemporaryTableDocAmountAllocation.LineNumber = BasicAmountAllocationCustomer.LineNumber
	|WHERE
	|	TemporaryTableDocAmountAllocation.OperationKind = VALUE(Enum.OperationTypesCreditNote.SalesReturn)
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTableDocAmountAllocation.Date,
	|	TemporaryTableDocAmountAllocation.Ref,
	|	&Company,
	|	TemporaryTableDocAmountAllocation.CompanyVATNumber,
	|	&PresentationCurrency,
	|	TemporaryTableDocAmountAllocation.Counterparty,
	|	TemporaryTableDocAmountAllocation.Contract,
	|	TemporaryTableDocAmountAllocation.Document,
	|	TemporaryTableDocAmountAllocation.Order,
	|	TemporaryTableDocAmountAllocation.AdvanceFlag,
	|	TemporaryTableDocAmountAllocation.OperationKind,
	|	TemporaryTableDocAmountAllocation.LineNumber,
	|	CASE
	|		WHEN TemporaryTableDocAmountAllocation.AdvanceFlag
	|			THEN TemporaryTableDocAmountAllocation.CustomerAdvancesGLAccount
	|		ELSE TemporaryTableDocAmountAllocation.GLAccountCustomerSettlements
	|	END,
	|	TemporaryTableDocAmountAllocation.VATRate,
	|	TemporaryTableDocAmountAllocation.VATTaxation,
	|	TemporaryTableDocAmountAllocation.GLAccount,
	|	TemporaryTableDocAmountAllocation.GLAccountCurrency,
	|	TemporaryTableDocAmountAllocation.SettlementsCurrency,
	|	TemporaryTableDocAmountAllocation.OperationType,
	|	TemporaryTableDocAmountAllocation.VATOutputGLAccount,
	|	CAST(TemporaryTableDocAmountAllocation.Amount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryTableDocAmountAllocation.ExchangeRate * TemporaryTableDocAmountAllocation.ContractCurrencyMultiplicity / (TemporaryTableDocAmountAllocation.ContractCurrencyExchangeRate * TemporaryTableDocAmountAllocation.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (TemporaryTableDocAmountAllocation.ExchangeRate * TemporaryTableDocAmountAllocation.ContractCurrencyMultiplicity / (TemporaryTableDocAmountAllocation.ContractCurrencyExchangeRate * TemporaryTableDocAmountAllocation.Multiplicity))
	|		END AS NUMBER(15, 2)),
	|	CAST(TemporaryTableDocAmountAllocation.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryTableDocAmountAllocation.ExchangeRate * TemporaryTableDocAmountAllocation.ContractCurrencyMultiplicity / (TemporaryTableDocAmountAllocation.ContractCurrencyExchangeRate * TemporaryTableDocAmountAllocation.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (TemporaryTableDocAmountAllocation.ExchangeRate * TemporaryTableDocAmountAllocation.ContractCurrencyMultiplicity / (TemporaryTableDocAmountAllocation.ContractCurrencyExchangeRate * TemporaryTableDocAmountAllocation.Multiplicity))
	|		END AS NUMBER(15, 2)),
	|	CAST(TemporaryTableDocAmountAllocation.Amount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryTableDocAmountAllocation.ExchangeRate / TemporaryTableDocAmountAllocation.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN TemporaryTableDocAmountAllocation.Multiplicity / TemporaryTableDocAmountAllocation.ExchangeRate
	|		END AS NUMBER(15, 2)),
	|	CAST(TemporaryTableDocAmountAllocation.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryTableDocAmountAllocation.ExchangeRate / TemporaryTableDocAmountAllocation.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN TemporaryTableDocAmountAllocation.Multiplicity / TemporaryTableDocAmountAllocation.ExchangeRate
	|		END AS NUMBER(15, 2)),
	|	0,
	|	0,
	|	TemporaryTableDocAmountAllocation.GLAccountCustomerSettlementsCurrency
	|FROM
	|	TemporaryTableDocAmountAllocation AS TemporaryTableDocAmountAllocation
	|WHERE
	|	TemporaryTableDocAmountAllocation.OperationKind <> VALUE(Enum.OperationTypesCreditNote.SalesReturn)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableInventoryPrev.Period AS Period,
	|	TemporaryTableInventoryPrev.Recorder AS Recorder,
	|	TemporaryTableInventoryPrev.Company AS Company,
	|	TemporaryTableInventoryPrev.CompanyVATNumber AS CompanyVATNumber,
	|	TemporaryTableInventoryPrev.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableInventoryPrev.OperationKind AS OperationKind,
	|	TemporaryTableInventoryPrev.StructuralUnit AS StructuralUnit,
	|	TemporaryTableInventoryPrev.BusinessLine AS BusinessLine,
	|	TemporaryTableInventoryPrev.Department AS Department,
	|	TemporaryTableInventoryPrev.Counterparty AS Counterparty,
	|	TemporaryTableInventoryPrev.Contract AS Contract,
	|	TemporaryTableInventoryPrev.DocumentCurrency AS DocumentCurrency,
	|	TemporaryTableInventoryPrev.SettlementsCurrency AS SettlementsCurrency,
	|	TemporaryTableInventoryPrev.Products AS Products,
	|	TemporaryTableInventoryPrev.Characteristic AS Characteristic,
	|	TemporaryTableInventoryPrev.Batch AS Batch,
	|	TemporaryTableInventoryPrev.Ownership AS Ownership,
	|	TemporaryTableInventoryPrev.CostObject AS CostObject,
	|	TemporaryTableInventoryPrev.MeasurementUnit AS MeasurementUnit,
	|	TemporaryTableInventoryPrev.BasisDocument AS BasisDocument,
	|	TemporaryTableInventoryPrev.Responsible AS Responsible,
	|	TemporaryTableInventoryPrev.VATRate AS VATRate,
	|	TemporaryTableInventoryPrev.SalesReturnItem AS SalesReturnItem,
	|	TemporaryTableInventoryPrev.COGSItem AS COGSItem,
	|	TemporaryTableInventoryPrev.GLAccount AS GLAccount,
	|	TemporaryTableInventoryPrev.InventoryAccountType AS InventoryAccountType,
	|	TemporaryTableInventoryPrev.Order AS Order,
	|	TemporaryTableInventoryPrev.SalesRep AS SalesRep,
	|	TemporaryTableInventoryPrev.Cell AS Cell,
	|	TemporaryTableInventoryPrev.ConnectionKey AS ConnectionKey,
	|	TemporaryTableInventoryPrev.ThisIsInventoryItem AS ThisIsInventoryItem,
	|	TemporaryTableInventoryPrev.InventoryGLAccount AS InventoryGLAccount,
	|	TemporaryTableInventoryPrev.GLAccountCostOfSales AS GLAccountCostOfSales,
	|	TemporaryTableInventoryPrev.ShiftClosure AS ShiftClosure,
	|	TemporaryTableInventoryPrev.SalesDocument AS SalesDocument,
	|	TemporaryTableInventoryPrev.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	TemporaryTableInventoryPrev.Archival AS Archival,
	|	TemporaryTableInventoryPrev.GoodsReceipt AS GoodsReceipt,
	|	TemporaryTableInventoryPrev.VATOutputGLAccount AS VATOutputGLAccount,
	|	TemporaryTableInventoryPrev.VATTaxation AS VATTaxation,
	|	TemporaryTableInventoryPrev.BundleProduct AS BundleProduct,
	|	TemporaryTableInventoryPrev.BundleCharacteristic AS BundleCharacteristic,
	|	SUM(TemporaryTableInventoryPrev.CostOfGoodsSold) AS CostOfGoodsSold,
	|	SUM(TemporaryTableInventoryPrev.Quantity) AS Quantity,
	|	SUM(TemporaryTableInventoryPrev.ReturnQuantity) AS ReturnQuantity,
	|	SUM(BasicAmountAllocationInventory.AmountDocCur) AS AmountDocCur,
	|	SUM(BasicAmountAllocationInventory.VATAmountDocCur) AS VATAmountDocCur,
	|	SUM(BasicAmountAllocationInventory.AmountCur) AS AmountCur,
	|	SUM(BasicAmountAllocationInventory.VATAmountCur) AS VATAmountCur,
	|	SUM(BasicAmountAllocationInventory.Amount) AS Amount,
	|	SUM(BasicAmountAllocationInventory.VATAmount) AS VATAmount,
	|	SUM(BasicAmountAllocationInventory.SalesTaxAmountDocCur) AS SalesTaxAmountDocCur,
	|	SUM(BasicAmountAllocationInventory.SalesTaxAmountCur) AS SalesTaxAmountCur,
	|	SUM(BasicAmountAllocationInventory.SalesTaxAmount) AS SalesTaxAmount,
	|	TemporaryTableInventoryPrev.Shipped AS Shipped,
	|	TemporaryTableInventoryPrev.DropShipping AS DropShipping
	|INTO TemporaryTableInventory
	|FROM
	|	TemporaryTableInventoryPrev AS TemporaryTableInventoryPrev
	|		INNER JOIN BasicAmountAllocationInventory AS BasicAmountAllocationInventory
	|		ON TemporaryTableInventoryPrev.LineNumber = BasicAmountAllocationInventory.InventoryLineNumber
	|
	|GROUP BY
	|	TemporaryTableInventoryPrev.ThisIsInventoryItem,
	|	TemporaryTableInventoryPrev.SalesDocument,
	|	TemporaryTableInventoryPrev.Responsible,
	|	TemporaryTableInventoryPrev.VATOutputGLAccount,
	|	TemporaryTableInventoryPrev.ShiftClosure,
	|	TemporaryTableInventoryPrev.SalesReturnItem,
	|	TemporaryTableInventoryPrev.COGSItem,
	|	TemporaryTableInventoryPrev.GLAccount,
	|	TemporaryTableInventoryPrev.InventoryAccountType,
	|	TemporaryTableInventoryPrev.Cell,
	|	TemporaryTableInventoryPrev.VATRate,
	|	TemporaryTableInventoryPrev.Order,
	|	TemporaryTableInventoryPrev.SalesRep,
	|	TemporaryTableInventoryPrev.BasisDocument,
	|	TemporaryTableInventoryPrev.GLAccountCostOfSales,
	|	TemporaryTableInventoryPrev.BusinessLine,
	|	TemporaryTableInventoryPrev.Archival,
	|	TemporaryTableInventoryPrev.Company,
	|	TemporaryTableInventoryPrev.CompanyVATNumber,
	|	TemporaryTableInventoryPrev.InventoryGLAccount,
	|	TemporaryTableInventoryPrev.OperationKind,
	|	TemporaryTableInventoryPrev.StructuralUnit,
	|	TemporaryTableInventoryPrev.Recorder,
	|	TemporaryTableInventoryPrev.MeasurementUnit,
	|	TemporaryTableInventoryPrev.Products,
	|	TemporaryTableInventoryPrev.Characteristic,
	|	TemporaryTableInventoryPrev.Batch,
	|	TemporaryTableInventoryPrev.Ownership,
	|	TemporaryTableInventoryPrev.CostObject,
	|	TemporaryTableInventoryPrev.Department,
	|	TemporaryTableInventoryPrev.Period,
	|	TemporaryTableInventoryPrev.ConnectionKey,
	|	TemporaryTableInventoryPrev.Counterparty,
	|	TemporaryTableInventoryPrev.DocumentCurrency,
	|	TemporaryTableInventoryPrev.SettlementsCurrency,
	|	TemporaryTableInventoryPrev.VATTaxation,
	|	TemporaryTableInventoryPrev.RetailTransferEarningAccounting,
	|	TemporaryTableInventoryPrev.GoodsReceipt,
	|	TemporaryTableInventoryPrev.Contract,
	|	TemporaryTableInventoryPrev.BundleProduct,
	|	TemporaryTableInventoryPrev.BundleCharacteristic,
	|	TemporaryTableInventoryPrev.Shipped,
	|	TemporaryTableInventoryPrev.PresentationCurrency,
	|	TemporaryTableInventoryPrev.DropShipping
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesTax.Ref AS Ref,
	|	SalesTax.SalesTaxRate AS SalesTaxRate,
	|	SalesTax.Amount AS Amount
	|INTO DocumentSalesTax
	|FROM
	|	Document.CreditNote.SalesTax AS SalesTax
	|		INNER JOIN TemporaryTableDocument AS TemporaryTableDocument
	|		ON SalesTax.Ref = TemporaryTableDocument.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentSalesTax.Ref AS Ref,
	|	SalesTaxRates.Agency AS TaxKind,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TaxTypes.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS SalesTaxGLAccount,
	|	SUM(DocumentSalesTax.Amount) AS Amount
	|INTO TemporaryTableSalesTax
	|FROM
	|	DocumentSalesTax AS DocumentSalesTax
	|		INNER JOIN Catalog.SalesTaxRates AS SalesTaxRates
	|			LEFT JOIN Catalog.TaxTypes AS TaxTypes
	|			ON SalesTaxRates.Agency = TaxTypes.Ref
	|		ON DocumentSalesTax.SalesTaxRate = SalesTaxRates.Ref
	|
	|GROUP BY
	|	DocumentSalesTax.Ref,
	|	SalesTaxRates.Agency,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TaxTypes.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasicAmountAllocation.Ref AS Ref,
	|	BasicAmountAllocation.Date AS Date,
	|	BasicAmountAllocation.Company AS Company,
	|	BasicAmountAllocation.PresentationCurrency AS PresentationCurrency,
	|	BasicAmountAllocation.CompanyVATNumber AS CompanyVATNumber,
	|	BasicAmountAllocation.OperationKind AS OperationKind,
	|	BasicAmountAllocation.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	BasicAmountAllocation.GLAccountCustomerSettlementsCurrency AS GLAccountCustomerSettlementsCurrency,
	|	BasicAmountAllocation.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(BasicAmountAllocation.AmountDocCur) AS Amount
	|INTO BasicAmountAllocationSalesTax
	|FROM
	|	BasicAmountAllocation AS BasicAmountAllocation
	|WHERE
	|	BasicAmountAllocation.Taxable
	|
	|GROUP BY
	|	BasicAmountAllocation.Ref,
	|	BasicAmountAllocation.Date,
	|	BasicAmountAllocation.Company,
	|	BasicAmountAllocation.PresentationCurrency,
	|	BasicAmountAllocation.CompanyVATNumber,
	|	BasicAmountAllocation.OperationKind,
	|	BasicAmountAllocation.GLAccountCustomerSettlements,
	|	BasicAmountAllocation.GLAccountCustomerSettlementsCurrency,
	|	BasicAmountAllocation.SettlementsCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasicAmountAllocationSalesTax.Ref AS Ref,
	|	SUM(BasicAmountAllocationSalesTax.Amount) AS Amount
	|INTO BasicAmountAllocationSalesTaxTotal
	|FROM
	|	BasicAmountAllocationSalesTax AS BasicAmountAllocationSalesTax
	|
	|GROUP BY
	|	BasicAmountAllocationSalesTax.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasicAmountAllocationSalesTax.Ref AS Ref,
	|	BasicAmountAllocationSalesTax.Date AS Period,
	|	BasicAmountAllocationSalesTax.Company AS Company,
	|	BasicAmountAllocationSalesTax.PresentationCurrency AS PresentationCurrency,
	|	BasicAmountAllocationSalesTax.CompanyVATNumber AS CompanyVATNumber,
	|	BasicAmountAllocationSalesTax.OperationKind AS OperationKind,
	|	BasicAmountAllocationSalesTax.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	BasicAmountAllocationSalesTax.GLAccountCustomerSettlementsCurrency AS GLAccountCustomerSettlementsCurrency,
	|	BasicAmountAllocationSalesTax.SettlementsCurrency AS SettlementsCurrency,
	|	TemporaryTableSalesTax.TaxKind AS TaxKind,
	|	TemporaryTableSalesTax.SalesTaxGLAccount AS SalesTaxGLAccount,
	|	SUM(CAST(TemporaryTableSalesTax.Amount * (BasicAmountAllocationSalesTax.Amount / BasicAmountAllocationSalesTaxTotal.Amount) AS NUMBER(15, 2))) AS Amount
	|INTO SalesTaxTable
	|FROM
	|	TemporaryTableSalesTax AS TemporaryTableSalesTax
	|		INNER JOIN BasicAmountAllocationSalesTax AS BasicAmountAllocationSalesTax
	|		ON TemporaryTableSalesTax.Ref = BasicAmountAllocationSalesTax.Ref
	|		INNER JOIN BasicAmountAllocationSalesTaxTotal AS BasicAmountAllocationSalesTaxTotal
	|		ON TemporaryTableSalesTax.Ref = BasicAmountAllocationSalesTaxTotal.Ref
	|WHERE
	|	BasicAmountAllocationSalesTax.OperationKind = VALUE(Enum.OperationTypesCreditNote.SalesReturn)
	|
	|GROUP BY
	|	BasicAmountAllocationSalesTax.Ref,
	|	TemporaryTableSalesTax.SalesTaxGLAccount,
	|	BasicAmountAllocationSalesTax.GLAccountCustomerSettlementsCurrency,
	|	BasicAmountAllocationSalesTax.Company,
	|	BasicAmountAllocationSalesTax.PresentationCurrency,
	|	BasicAmountAllocationSalesTax.CompanyVATNumber,
	|	BasicAmountAllocationSalesTax.OperationKind,
	|	TemporaryTableSalesTax.TaxKind,
	|	BasicAmountAllocationSalesTax.Date,
	|	BasicAmountAllocationSalesTax.SettlementsCurrency,
	|	BasicAmountAllocationSalesTax.GLAccountCustomerSettlements
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesTaxTable.Ref AS Ref,
	|	SUM(SalesTaxTable.Amount) AS Amount
	|INTO SalesTaxAmountTotalAfter
	|FROM
	|	SalesTaxTable AS SalesTaxTable
	|
	|GROUP BY
	|	SalesTaxTable.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableSalesTax.Ref AS Ref,
	|	SUM(TemporaryTableSalesTax.Amount) AS Amount
	|INTO SalesTaxAmountTotalBefore
	|FROM
	|	TemporaryTableSalesTax AS TemporaryTableSalesTax
	|
	|GROUP BY
	|	TemporaryTableSalesTax.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesTaxTableDiff.Ref AS Ref,
	|	SalesTaxTableDiff.Period AS Period,
	|	SalesTaxTableDiff.Company AS Company,
	|	SalesTaxTableDiff.PresentationCurrency AS PresentationCurrency,
	|	SalesTaxTableDiff.CompanyVATNumber AS CompanyVATNumber,
	|	SalesTaxTableDiff.OperationKind AS OperationKind,
	|	SalesTaxTableDiff.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	SalesTaxTableDiff.GLAccountCustomerSettlementsCurrency AS GLAccountCustomerSettlementsCurrency,
	|	SalesTaxTableDiff.SettlementsCurrency AS SettlementsCurrency,
	|	SalesTaxTableDiff.TaxKind AS TaxKind,
	|	SalesTaxTableDiff.SalesTaxGLAccount AS SalesTaxGLAccount,
	|	SUM(SalesTaxTableDiff.Amount) AS Amount
	|INTO SalesTaxTableWithDifference
	|FROM
	|	(SELECT
	|		SalesTaxTable.Ref AS Ref,
	|		SalesTaxTable.Period AS Period,
	|		SalesTaxTable.Company AS Company,
	|		SalesTaxTable.PresentationCurrency AS PresentationCurrency,
	|		SalesTaxTable.CompanyVATNumber AS CompanyVATNumber,
	|		SalesTaxTable.OperationKind AS OperationKind,
	|		SalesTaxTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|		SalesTaxTable.GLAccountCustomerSettlementsCurrency AS GLAccountCustomerSettlementsCurrency,
	|		SalesTaxTable.SettlementsCurrency AS SettlementsCurrency,
	|		SalesTaxTable.TaxKind AS TaxKind,
	|		SalesTaxTable.SalesTaxGLAccount AS SalesTaxGLAccount,
	|		SalesTaxTable.Amount AS Amount
	|	FROM
	|		SalesTaxTable AS SalesTaxTable
	|	
	|	UNION ALL
	|	
	|	SELECT TOP 1
	|		SalesTaxTable.Ref,
	|		SalesTaxTable.Period,
	|		SalesTaxTable.Company,
	|		SalesTaxTable.PresentationCurrency,
	|		SalesTaxTable.CompanyVATNumber,
	|		SalesTaxTable.OperationKind,
	|		SalesTaxTable.GLAccountCustomerSettlements,
	|		SalesTaxTable.GLAccountCustomerSettlementsCurrency,
	|		SalesTaxTable.SettlementsCurrency,
	|		SalesTaxTable.TaxKind,
	|		SalesTaxTable.SalesTaxGLAccount,
	|		SalesTaxAmountTotalBefore.Amount - SalesTaxAmountTotalAfter.Amount
	|	FROM
	|		SalesTaxTable AS SalesTaxTable
	|			INNER JOIN SalesTaxAmountTotalAfter AS SalesTaxAmountTotalAfter
	|			ON SalesTaxTable.Ref = SalesTaxAmountTotalAfter.Ref
	|			INNER JOIN SalesTaxAmountTotalBefore AS SalesTaxAmountTotalBefore
	|			ON SalesTaxTable.Ref = SalesTaxAmountTotalBefore.Ref) AS SalesTaxTableDiff
	|
	|GROUP BY
	|	SalesTaxTableDiff.Company,
	|	SalesTaxTableDiff.PresentationCurrency,
	|	SalesTaxTableDiff.CompanyVATNumber,
	|	SalesTaxTableDiff.Ref,
	|	SalesTaxTableDiff.Period,
	|	SalesTaxTableDiff.OperationKind,
	|	SalesTaxTableDiff.GLAccountCustomerSettlementsCurrency,
	|	SalesTaxTableDiff.SettlementsCurrency,
	|	SalesTaxTableDiff.TaxKind,
	|	SalesTaxTableDiff.SalesTaxGLAccount,
	|	SalesTaxTableDiff.GLAccountCustomerSettlements
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesTaxTable.Ref AS Ref,
	|	SalesTaxTable.Period AS Period,
	|	SalesTaxTable.Company AS Company,
	|	SalesTaxTable.PresentationCurrency AS PresentationCurrency,
	|	SalesTaxTable.CompanyVATNumber AS CompanyVATNumber,
	|	SalesTaxTable.OperationKind AS OperationKind,
	|	SalesTaxTable.TaxKind AS TaxKind,
	|	SalesTaxTable.SalesTaxGLAccount AS SalesTaxGLAccount,
	|	SalesTaxTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	SalesTaxTable.GLAccountCustomerSettlementsCurrency AS GLAccountCustomerSettlementsCurrency,
	|	SalesTaxTable.SettlementsCurrency AS SettlementsCurrency,
	|	CAST(SalesTaxTable.Amount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryTableDocument.ExchangeRate / TemporaryTableDocument.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN TemporaryTableDocument.Multiplicity / TemporaryTableDocument.ExchangeRate
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(SalesTaxTable.Amount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryTableDocument.ExchangeRate * TemporaryTableDocument.ContractCurrencyMultiplicity / (TemporaryTableDocument.ContractCurrencyExchangeRate * TemporaryTableDocument.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (TemporaryTableDocument.ExchangeRate * TemporaryTableDocument.ContractCurrencyMultiplicity / (TemporaryTableDocument.ContractCurrencyExchangeRate * TemporaryTableDocument.Multiplicity))
	|		END AS NUMBER(15, 2)) AS AmountCur
	|INTO TemporarySalesTaxAmount
	|FROM
	|	SalesTaxTableWithDifference AS SalesTaxTable
	|		INNER JOIN TemporaryTableDocument AS TemporaryTableDocument
	|		ON SalesTaxTable.Ref = TemporaryTableDocument.Ref";
	
	Query.SetParameter("Ref",                          DocumentRefCreditNote);
	Query.SetParameter("Company",                      StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics",           StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",                   StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseGoodsReturnFromCustomer",   StructureAdditionalProperties.AccountingPolicy.UseGoodsReturnFromCustomer);
	Query.SetParameter("PresentationCurrency",         StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod",           StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefCreditNote, StructureAdditionalProperties);
	
	GenerateTableSales(DocumentRefCreditNote, StructureAdditionalProperties);
	GenerateTableAccountsReceivable(DocumentRefCreditNote, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefCreditNote, StructureAdditionalProperties);
	GenerateTableGoodsInvoicedNotShipped(DocumentRefCreditNote, StructureAdditionalProperties);
	
	GenerateTableInventoryInWarehouses(DocumentRefCreditNote, StructureAdditionalProperties);
	GenerateTableInventory(DocumentRefCreditNote, StructureAdditionalProperties);
	GenerateTableSerialNumbers(DocumentRefCreditNote, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.AccountingModuleSettings
		= Enums.AccountingModuleSettingsTypes.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefCreditNote, StructureAdditionalProperties);
	EndIf;
	
	GenerateTableAccountingEntriesData(DocumentRefCreditNote, StructureAdditionalProperties);
	
	If GetFunctionalOption("UseVAT")
		And Not WorkWithVAT.GetUseTaxInvoiceForPostingVAT(DocumentRefCreditNote.Date, DocumentRefCreditNote.Company) 
		And DocumentRefCreditNote.VATTaxation <> Enums.VATTaxationTypes.NotSubjectToVAT Then
		
		GenerateTableVATOutput(Query, DocumentRefCreditNote, StructureAdditionalProperties);
	
	EndIf;
	
	// Sales tax
	GenerateTableTaxPayable(DocumentRefCreditNote, StructureAdditionalProperties);
	
	FinancialAccounting.FillExtraDimensions(DocumentRefCreditNote, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.AccountingModuleSettings
		= Enums.AccountingModuleSettingsTypes.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefCreditNote, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefCreditNote, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefCreditNote, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If StructureTemporaryTables.RegisterRecordsInventoryChange
		OR StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		OR StructureTemporaryTables.RegisterRecordsAccountsReceivableChange
		Or StructureTemporaryTables.RegisterRecordsInventoryWithSourceDocumentChange
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
		Query.Text = Query.Text + AccumulationRegisters.Inventory.ReturnQuantityControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		Query.SetParameter("Ref", DocumentRefCreditNote);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty()
			Or Not ResultsArray[3].IsEmpty()
			Or Not ResultsArray[9].IsEmpty() Then
			DocumentObjectCreditNote = DocumentRefCreditNote.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectCreditNote, QueryResultSelection, Cancel);
		// Negative balance of inventory.
		ElsIf Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectCreditNote, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocumentObjectCreditNote, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectCreditNote, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of return quantity in inventory
		If Not ResultsArray[9].IsEmpty() And ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[9].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterRefundsErrors(DocumentObjectCreditNote, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region IncomeAndExpenseItems

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Inventory" Then
		IncomeAndExpenseStructure.Insert("COGSItem", StructureData.COGSItem);
		IncomeAndExpenseStructure.Insert("SalesReturnItem", StructureData.SalesReturnItem);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "Header" Then
		Result.Insert("GLAccount", "ExpenseItem");
	ElsIf StructureData.TabName = "Inventory" Then
		Result.Insert("SalesReturnGLAccount", "SalesReturnItem");
		Result.Insert("COGSGLAccount", "COGSItem");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	If StructureData.Property("ProductGLAccounts") Then
		
		If StructureData.Shipped Then
			GLAccountsForFilling = New Structure("InventoryGLAccount, VATOutputGLAccount, UnearnedRevenueGLAccount, SalesReturnGLAccount");
		Else
			GLAccountsForFilling = New Structure("InventoryGLAccount, VATOutputGLAccount, COGSGLAccount, SalesReturnGLAccount");
		EndIf;
		FillPropertyValues(GLAccountsForFilling, StructureData); 
		
	ElsIf StructureData.Property("CounterpartyGLAccounts") Then
		
		If StructureData.TabName = "Header"
			And ObjectParameters.OperationKind = Enums.OperationTypesCreditNote.DiscountAllowed Then
			
			GLAccountsForFilling.Insert("DiscountAllowedGLAccount", ObjectParameters.GLAccount);
			
		ElsIf StructureData.TabName = "Header"
			And ObjectParameters.OperationKind = Enums.OperationTypesCreditNote.Adjustments Then
			
			GLAccountsForFilling.Insert("AccountsReceivableGLAccount", ObjectParameters.GLAccount);
			
		ElsIf StructureData.TabName = "AmountAllocation" Then
			
			GLAccountsForFilling.Insert("AccountsReceivableGLAccount", StructureData.AccountsReceivableGLAccount);
			GLAccountsForFilling.Insert("AdvancesReceivedGLAccount", StructureData.AdvancesReceivedGLAccount);
			
			If ObjectParameters.OperationKind <> Enums.OperationTypesCreditNote.SalesReturn Then
				GLAccountsForFilling.Insert("VATOutputGLAccount", StructureData.VATOutputGLAccount);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region InventoryOwnership

Function InventoryOwnershipParameters(DocObject) Export
	
	Parameters = New Structure;
	
	Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);
	
	Return Parameters;
	
EndFunction

#EndRegion

#Region Batches

Function BatchCheckFillingParameters(DocObject) Export
	
	Parameters = New Structure;
	
	If DocObject.OperationKind = Enums.OperationTypesCreditNote.SalesReturn Then
		
		Warehouses = New Array;
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.StructuralUnit);
		WarehouseData.Insert("TrackingArea", "Inbound_SalesReturn");
		
		Warehouses.Add(WarehouseData);
		
		Parameters.Insert("Warehouses", Warehouses);
		
	EndIf;
	
	Return Parameters;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "CreditNote") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(
            PrintFormsCollection, 
            "CreditNote", 
            NStr("en = 'Credit note'; ru = 'Кредитовое авизо';pl = 'Nota kredytowa';es_ES = 'Nota de crédito';es_CO = 'Nota de haber';tr = 'Alacak dekontu';it = 'Nota di credito';de = 'Gutschrift'"), 
            PrintForm(ObjectsArray, PrintObjects, "CreditNote", PrintParameters.Result));
	EndIf;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "TaxInvoice") Then
		If ObjectsArray.Count() > 0 Then
			PrintManagement.OutputSpreadsheetDocumentToCollection(
				PrintFormsCollection, 
				"TaxInvoice",
				NStr("en = 'Tax invoice'; ru = 'Налоговый инвойс';pl = 'Faktura VAT';es_ES = 'Factura de impuestos';es_CO = 'Factura fiscal';tr = 'Vergi faturası';it = 'Fattura fiscale';de = 'Steuerrechnung'"),
				DataProcessors.PrintTaxInvoice.PrintForm(ObjectsArray, PrintObjects, "TaxInvoice", PrintParameters.Result));
		EndIf;
	ElsIf PrintManagement.TemplatePrintRequired(PrintFormsCollection, "GoodsReceivedNote") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"GoodsReceivedNote",
															NStr("en = 'Goods received note'; ru = 'Уведомление о доставке товаров';pl = 'Przyjęcie zewnętrzne';es_ES = 'Nota de recepción de productos';es_CO = 'Nota de recepción de productos';tr = 'Teslim alındı belgesi';it = 'Nota di ricezione merci';de = 'Lieferantenlieferschein'"),
															DataProcessors.PrintGoodsReceivedNote.PrintForm(ObjectsArray, PrintObjects, "GoodsReceivedNote", PrintParameters.Result));
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "CreditNote";
	PrintCommand.Presentation				= NStr("en = 'Credit note'; ru = 'Кредитовое авизо';pl = 'Nota kredytowa';es_ES = 'Nota de crédito';es_CO = 'Nota de haber';tr = 'Alacak dekontu';it = 'Nota di credito';de = 'Gutschrift'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "GoodsReceivedNote";
	PrintCommand.Presentation				= NStr("en = 'Goods received note'; ru = 'Уведомление о доставке товаров';pl = 'Przyjęcie zewnętrzne';es_ES = 'Nota de recepción de productos';es_CO = 'Nota de recepción de productos';tr = 'Teslim alındı belgesi';it = 'Nota di ricezione merci';de = 'Lieferantenlieferschein'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 2;

	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "TaxInvoice";
	PrintCommand.Presentation				= NStr("en = 'Tax invoice'; ru = 'Налоговый инвойс';pl = 'Faktura VAT';es_ES = 'Factura de impuestos';es_CO = 'Factura fiscal';tr = 'Vergi faturası';it = 'Fattura fiscale';de = 'Steuerrechnung'");
	PrintCommand.CheckPostingBeforePrint	= True;
	PrintCommand.FunctionalOptions			= "UseVAT";
	PrintCommand.Order						= 3;
	
EndProcedure

Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	If TemplateName = "CreditNote" Then
		Return PrintCreditNote(ObjectsArray, PrintObjects, TemplateName, PrintParams);
	EndIf;
	
EndFunction

Function PrintCreditNote(ObjectsArray, PrintObjects, TemplateName, PrintParams)
    
	DisplayPrintOption = (PrintParams <> Undefined);;
    
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_CreditNote";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	#Region PrintCreditNoteQueryText
	
	Query.Text = 
	"SELECT ALLOWED
	|	CreditNote.Ref AS Ref,
	|	CreditNote.Number AS Number,
	|	CreditNote.Date AS Date,
	|	CreditNote.Company AS Company,
	|	CreditNote.CompanyVATNumber AS CompanyVATNumber,
	|	CreditNote.Counterparty AS Counterparty,
	|	CreditNote.Contract AS Contract,
	|	CreditNote.AmountIncludesVAT AS AmountIncludesVAT,
	|	CreditNote.DocumentCurrency AS DocumentCurrency,
	|	CreditNote.BasisDocument AS BasisDocument,
	|	CreditNote.OperationKind AS OperationKind,
	|	CreditNote.ReasonForCorrection AS ReasonForCorrection,
	|	CreditNote.AdjustedAmount AS DocumentAmount,
	|	CreditNote.VATRate AS VATRate,
	|	CreditNote.VATAmount AS VATAmount
	|INTO CreditNotes
	|FROM
	|	Document.CreditNote AS CreditNote
	|WHERE
	|	CreditNote.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CreditNoteInventory.Ref AS Ref,
	|	CreditNoteInventory.LineNumber AS LineNumber,
	|	CreditNoteInventory.Amount AS Amount,
	|	CreditNoteInventory.Batch AS Batch,
	|	CreditNoteInventory.Characteristic AS Characteristic,
	|	CreditNoteInventory.ConnectionKey AS ConnectionKey,
	|	CreditNoteInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	CreditNoteInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN CreditNoteInventory.Price = 0
	|			THEN CASE
	|					WHEN CreditNoteInventory.Quantity = 0
	|						THEN 0
	|					ELSE CreditNoteInventory.Amount / CreditNoteInventory.Quantity
	|				END
	|		ELSE CreditNoteInventory.Price
	|	END AS Price,
	|	CreditNoteInventory.Products AS Products,
	|	CreditNoteInventory.Quantity AS Quantity,
	|	CreditNoteInventory.Total AS Total,
	|	CreditNoteInventory.VATAmount AS VATAmount,
	|	CreditNoteInventory.VATRate AS VATRate,
	|	CreditNoteInventory.SalesDocument AS SalesDocument,
	|	CreditNoteInventory.BundleProduct AS BundleProduct,
	|	CreditNoteInventory.BundleCharacteristic AS BundleCharacteristic
	|INTO FilteredInventory
	|FROM
	|	Document.CreditNote.Inventory AS CreditNoteInventory
	|WHERE
	|	CreditNoteInventory.Ref IN(&ObjectsArray)
	|	AND (CreditNoteInventory.Quantity <> 0
	|			OR CreditNoteInventory.Amount <> 0)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CreditNote.Ref AS Ref,
	|	CreditNote.Number AS DocumentNumber,
	|	CreditNote.Date AS DocumentDate,
	|	CreditNote.Company AS Company,
	|	CreditNote.CompanyVATNumber AS CompanyVATNumber,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	CreditNote.Counterparty AS Counterparty,
	|	CreditNote.Contract AS Contract,
	|	CASE
	|		WHEN CounterpartyContracts.ContactPerson = VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN Counterparties.ContactPerson
	|		ELSE CounterpartyContracts.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	CreditNote.AmountIncludesVAT AS AmountIncludesVAT,
	|	CreditNote.DocumentCurrency AS DocumentCurrency,
	|	CreditNote.OperationKind AS OperationKind,
	|	CreditNote.ReasonForCorrection AS ReasonForCorrection,
	|	CreditNote.DocumentAmount AS DocumentAmount,
	|	CreditNote.BasisDocument AS BasisDocument,
	|	CreditNote.VATRate AS VATRate,
	|	CreditNote.VATAmount AS VATAmount
	|INTO Header
	|FROM
	|	CreditNotes AS CreditNote
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON CreditNote.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON CreditNote.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON CreditNote.Contract = CounterpartyContracts.Ref
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
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
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
	|	FilteredInventory.Price AS Price,
	|	FilteredInventory.DiscountMarkupPercent AS DiscountRate,
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	SUM(FilteredInventory.Total) AS Total,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN FilteredInventory.Amount - FilteredInventory.VATAmount
	|			ELSE FilteredInventory.Amount
	|		END) AS Subtotal,
	|	CatalogProducts.Description AS ProductDescription,
	|	FALSE AS ContentUsed,
	|	CASE
	|		WHEN Header.BasisDocument REFS Document.RMARequest
	|			THEN Header.BasisDocument.Invoice
	|		ELSE FilteredInventory.SalesDocument
	|	END AS Invoice,
	|	Header.OperationKind AS OperationKind,
	|	CAST(Header.ReasonForCorrection AS STRING(1000)) AS ReasonForCorrection,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Batch AS Batch,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.BundleProduct AS BundleProduct,
	|	FilteredInventory.BundleCharacteristic AS BundleCharacteristic
	|INTO Inventory
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
	|	Header.DocumentCurrency,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	CatalogProducts.UseSerialNumbers,
	|	FilteredInventory.VATRate,
	|	Header.DocumentNumber,
	|	Header.OperationKind,
	|	Header.CompanyLogoFile,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.SKU,
	|	Header.CounterpartyContactPerson,
	|	CatalogProducts.Description,
	|	Header.Ref,
	|	Header.Contract,
	|	Header.AmountIncludesVAT,
	|	Header.Counterparty,
	|	CASE
	|		WHEN Header.BasisDocument REFS Document.RMARequest
	|			THEN Header.BasisDocument.Invoice
	|		ELSE FilteredInventory.SalesDocument
	|	END,
	|	Header.DocumentDate,
	|	CAST(Header.ReasonForCorrection AS STRING(1000)),
	|	FilteredInventory.Products,
	|	FilteredInventory.Batch,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.DiscountMarkupPercent,
	|	FilteredInventory.Price,
	|	FilteredInventory.BundleProduct,
	|	FilteredInventory.BundleCharacteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Header.ReasonForCorrection AS ReasonForCorrection,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Header.DocumentAmount - Header.VATAmount
	|		ELSE Header.DocumentAmount
	|	END AS Amount,
	|	Header.VATRate AS VATRate,
	|	Header.Ref AS Ref,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.Counterparty AS Counterparty,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Header.DocumentAmount
	|		ELSE Header.DocumentAmount + Header.VATAmount
	|	END AS Total,
	|	1 AS LineNumber,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.VATAmount AS VATAmount,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Header.DocumentAmount - Header.VATAmount
	|		ELSE Header.DocumentAmount
	|	END AS SubTotal,
	|	ISNULL(CreditNoteCreditedTransactions.Document, UNDEFINED) AS Document
	|FROM
	|	Header AS Header
	|		LEFT JOIN Document.CreditNote.CreditedTransactions AS CreditNoteCreditedTransactions
	|		ON Header.Ref = CreditNoteCreditedTransactions.Ref
	|WHERE
	|	Header.OperationKind <> VALUE(Enum.OperationTypesCreditNote.SalesReturn)
	|TOTALS
	|	MAX(ReasonForCorrection),
	|	MAX(Amount),
	|	MAX(VATRate),
	|	MAX(CompanyLogoFile),
	|	MAX(DocumentDate),
	|	MAX(DocumentNumber),
	|	MAX(Company),
	|	MAX(CompanyVATNumber),
	|	MAX(Counterparty),
	|	MAX(Total),
	|	MAX(LineNumber),
	|	MAX(DocumentCurrency),
	|	MAX(VATAmount),
	|	MAX(SubTotal)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Inventory.Ref AS Ref,
	|	Inventory.DocumentNumber AS DocumentNumber,
	|	Inventory.DocumentDate AS DocumentDate,
	|	Inventory.Company AS Company,
	|	Inventory.CompanyVATNumber AS CompanyVATNumber,
	|	Inventory.CompanyLogoFile AS CompanyLogoFile,
	|	Inventory.Counterparty AS Counterparty,
	|	Inventory.Contract AS Contract,
	|	Inventory.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Inventory.AmountIncludesVAT AS AmountIncludesVAT,
	|	Inventory.DocumentCurrency AS DocumentCurrency,
	|	Inventory.LineNumber AS LineNumber,
	|	Inventory.SKU AS SKU,
	|	Inventory.UseSerialNumbers AS UseSerialNumbers,
	|	Inventory.Quantity AS Quantity,
	|	CASE
	|		WHEN Inventory.AmountIncludesVAT
	|				AND NOT Inventory.Quantity = 0
	|			THEN Inventory.Amount / Inventory.Quantity
	|		ELSE Inventory.Price
	|	END AS Price,
	|	Inventory.Amount AS Amount,
	|	Inventory.VATRate AS VATRate,
	|	Inventory.VATAmount AS VATAmount,
	|	Inventory.Total AS Total,
	|	Inventory.Subtotal AS Subtotal,
	|	Inventory.ProductDescription AS ProductDescription,
	|	Inventory.ContentUsed AS ContentUsed,
	|	Inventory.Invoice AS Invoice,
	|	Inventory.OperationKind AS OperationKind,
	|	CAST(Inventory.ReasonForCorrection AS STRING(1000)) AS ReasonForCorrection,
	|	Inventory.Products AS Products,
	|	Inventory.Batch AS Batch,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.CharacteristicDescription AS CharacteristicDescription,
	|	Inventory.BatchDescription AS BatchDescription,
	|	Inventory.ConnectionKey AS ConnectionKey,
	|	Inventory.UOM AS UOM,
	|	Inventory.BundleProduct AS BundleProduct,
	|	Inventory.BundleCharacteristic AS BundleCharacteristic
	|FROM
	|	Inventory AS Inventory
	|
	|ORDER BY
	|	Inventory.DocumentNumber,
	|	Inventory.LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyVATNumber),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(CounterpartyContactPerson),
	|	MAX(AmountIncludesVAT),
	|	MAX(DocumentCurrency),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	MAX(Invoice),
	|	MAX(OperationKind)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Inventory.Ref AS Ref,
	|	Inventory.VATRate AS VATRate,
	|	SUM(Inventory.Subtotal) AS Amount,
	|	SUM(Inventory.VATAmount) AS VATAmount
	|FROM
	|	Inventory AS Inventory
	|
	|GROUP BY
	|	Inventory.Ref,
	|	Inventory.VATRate
	|TOTALS BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Inventory.ConnectionKey AS ConnectionKey,
	|	Inventory.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	FilteredInventory AS FilteredInventory
	|		INNER JOIN Inventory AS Inventory
	|		ON FilteredInventory.Products = Inventory.Products
	|			AND FilteredInventory.DiscountMarkupPercent = Inventory.DiscountRate
	|			AND FilteredInventory.Price = Inventory.Price
	|			AND FilteredInventory.VATRate = Inventory.VATRate
	|			AND (NOT Inventory.ContentUsed)
	|			AND FilteredInventory.Ref = Inventory.Ref
	|			AND FilteredInventory.Characteristic = Inventory.Characteristic
	|			AND FilteredInventory.Batch = Inventory.Batch
	|			AND FilteredInventory.MeasurementUnit = Inventory.MeasurementUnit
	|		INNER JOIN Document.CreditNote.SerialNumbers AS CreditNoteSerialNumbers
	|			LEFT JOIN Catalog.SerialNumbers AS SerialNumbers
	|			ON CreditNoteSerialNumbers.SerialNumber = SerialNumbers.Ref
	|		ON (CreditNoteSerialNumbers.ConnectionKey = FilteredInventory.ConnectionKey)
	|			AND FilteredInventory.Ref = CreditNoteSerialNumbers.Ref";
	
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
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_CreditNote";
	Template = PrintManagement.PrintFormTemplate("Document.CreditNote.PF_MXL_CreditNote", LanguageCode);
	
	Header				= ResultArray[4].Select(QueryResultIteration.ByGroupsWithHierarchy);
	Inventory			= ResultArray[5].Select(QueryResultIteration.ByGroupsWithHierarchy);
	TaxesHeaderSel		= ResultArray[6].Select(QueryResultIteration.ByGroupsWithHierarchy);
	SerialNumbersSel	= ResultArray[7].Select(QueryResultIteration.ByGroupsWithHierarchy);
	
	// Bundles
	TableColumns = ResultArray[5].Columns;
	// End Bundles
	
	While Header.Next() Do

		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		TitleArea = GetArea("Title", Template, Header, LanguageCode);
		SpreadsheetDocument.Put(TitleArea);
		
		If DisplayPrintOption Then 
			TitleArea.Parameters.OriginalDuplicate = ?(PrintParams.OriginalCopy,
				NStr("en = 'ORIGINAL'; ru = 'ОРИГИНАЛ';pl = 'ORYGINAŁ';es_ES = 'ORIGINAL';es_CO = 'ORIGINAL';tr = 'ORİJİNAL';it = 'ORIGINALE';de = 'ORIGINAL'", LanguageCode),
				NStr("en = 'COPY'; ru = 'КОПИЯ';pl = 'KOPIA';es_ES = 'COPIA';es_CO = 'COPIA';tr = 'KOPYALA';it = 'COPIA';de = 'KOPIE'", LanguageCode));
		EndIf;
		
		CompanyInfoArea = GetArea("CompanyInfo", Template, Header, LanguageCode);
		BarcodesInPrintForms.AddBarcodeToTableDocument(CompanyInfoArea, Header.Ref);
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		Transactions = "";
		
		TabSelection = Header.Select();
		While TabSelection.Next() Do
			Transactions = TrimAll(Transactions) + ?(IsBlankString(Transactions), "", "; ");
			Transactions = Transactions + String(TabSelection.Document);
		EndDo;
		
		CounterpartyInfoArea = GetArea("CounterpartyInfo", Template, Header, LanguageCode);
		CounterpartyInfoArea.Parameters.Invoice = Transactions;
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
		CommentArea = GetArea("Comment", Template, Header, LanguageCode);
		SpreadsheetDocument.Put(CommentArea);
		
		#Region PrintCreditNoteLinesArea
		
		LineHeaderArea = Template.GetArea("LineHeaderDiscAllowed");
		SpreadsheetDocument.Put(LineHeaderArea);
		
		LineSectionArea	= Template.GetArea("LineSectionDiscAllowed");
		LineSectionArea.Parameters.Fill(Header);
		
		LineSectionArea.Parameters.ReasonForCorrection = Common.ObjectAttributeValue(Header.Ref, "ReasonForCorrection");
		SpreadsheetDocument.Put(LineSectionArea);
		
		#EndRegion
		
		#Region PrintCreditNoteTotalsArea
		
		LineTotalArea = Template.GetArea("LineTotal");
		LineTotalArea.Parameters.Fill(Header);
		LineTotalArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(LineTotalArea);
		
		PageNumber = 1;
		
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= Template.GetArea("PageNumber");
		
		AreasToBeChecked = New Array;
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
		
		For i = 1 To 50 Do
			
			If Not Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
				Or i = 50 Then
				
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
	
	While Inventory.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		TitleArea = GetArea("Title", Template, Inventory, LanguageCode);
		
		If DisplayPrintOption Then 
			TitleArea.Parameters.OriginalDuplicate = ?(PrintParams.OriginalCopy,
				NStr("en = 'ORIGINAL'; ru = 'ОРИГИНАЛ';pl = 'ORYGINAŁ';es_ES = 'ORIGINAL';es_CO = 'ORIGINAL';tr = 'ORİJİNAL';it = 'ORIGINALE';de = 'ORIGINAL'", LanguageCode),
				NStr("en = 'COPY'; ru = 'КОПИЯ';pl = 'KOPIA';es_ES = 'COPIA';es_CO = 'COPIA';tr = 'KOPYALA';it = 'COPIA';de = 'KOPIE'", LanguageCode));
		EndIf;
		
		SpreadsheetDocument.Put(TitleArea);
		
		CompanyInfoArea = GetArea("CompanyInfo", Template, Inventory, LanguageCode);
		BarcodesInPrintForms.AddBarcodeToTableDocument(CompanyInfoArea, Inventory.Ref);
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		CounterpartyInfoArea = GetArea("CounterpartyInfo", Template, Inventory, LanguageCode);
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
		#Region PrintCreditNoteReasonForCorrectionArea
		
		ReasonForCorrectionArea = Template.GetArea("ReasonForCorrection");
		ReasonForCorrectionArea.Parameters.ReasonForCorrection = Common.ObjectAttributeValue(
			Inventory.Ref,
			"ReasonForCorrection");
			
		SpreadsheetDocument.Put(ReasonForCorrectionArea);
		
		#EndRegion
		
		CommentArea = GetArea("Comment", Template, Inventory, LanguageCode);
		SpreadsheetDocument.Put(CommentArea);
		
		#Region PrintCreditNoteTotalsAndTaxesAreaPrefill
		
		TotalsAndTaxesAreasArray = New Array;
		
		LineTotalArea = Template.GetArea("LineTotal");
		LineTotalArea.Parameters.Fill(Inventory);
		
		TotalsAndTaxesAreasArray.Add(LineTotalArea);
		
		TaxesHeaderSel.Reset();
		If TaxesHeaderSel.FindNext(New Structure("Ref", Inventory.Ref)) Then
			
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
		
		#Region PrintCreditNoteLinesArea
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
		
		AreasToBeChecked = New Array;
		
		// Bundles
		TableInventoty = BundlesServer.AssemblyTableByBundles(Inventory.Ref, Inventory, TableColumns, LineTotalArea);
		EmptyColor = LineSectionArea.CurrentArea.TextColor;
		// End Bundles
		
		PricePrecision = PrecisionAppearancetServer.CompanyPrecision(Inventory.Company);
		
		For Each TabSelection In TableInventoty Do
			
			LineSectionArea.Parameters.Fill(TabSelection);
			LineSectionArea.Parameters.Price = Format(TabSelection.Price,
				"NFD= " + PricePrecision);
			
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
			
			AreasToBeChecked.Clear();
			AreasToBeChecked.Add(LineSectionArea);
			For Each Area In TotalsAndTaxesAreasArray Do
				AreasToBeChecked.Add(Area);
			EndDo;
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
		
		#Region PrintCreditNoteTotalsAndTaxesArea
		
		For Each Area In TotalsAndTaxesAreasArray Do
			SpreadsheetDocument.Put(Area);
		EndDo;
		
		AreasToBeChecked.Clear();
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
		
		#Region PrintAdditionalAttributes
		If DisplayPrintOption And PrintParams.AdditionalAttributes And PrintManagementServerCallDrive.HasAdditionalAttributes(Inventory.Ref) Then
			
			SpreadsheetDocument.Put(EmptyLineArea);
			
			AddAttribHeader = Template.GetArea("AdditionalAttributesStaticHeader");
			SpreadsheetDocument.Put(AddAttribHeader);
			
			SpreadsheetDocument.Put(EmptyLineArea);
			
			AddAttribHeader = Template.GetArea("AdditionalAttributesHeader");
			SpreadsheetDocument.Put(AddAttribHeader);
			
			AddAttribRow = Template.GetArea("AdditionalAttributesRow");
			
			For Each Attr In Inventory.Ref.AdditionalAttributes Do
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
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Inventory.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

Function GetArea(AreaName, Template, Selection, LanguageCode)
	
	Area = Template.GetArea(AreaName);
	
	If AreaName = "Title" Then
		
		Area.Parameters.Fill(Selection);
		If ValueIsFilled(Selection.CompanyLogoFile) Then
			PictureData = AttachedFiles.GetBinaryFileData(Selection.CompanyLogoFile);
			
			If ValueIsFilled(PictureData) Then
				Area.Drawings.Logo.Picture = New Picture(PictureData);
			EndIf;
		Else
			Area.Drawings.Delete(Area.Drawings.Logo);
		EndIf;
		
	ElsIf AreaName = "CompanyInfo" Then
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
			Selection.Company, Selection.DocumentDate, , , Selection.CompanyVATNumber, LanguageCode);
		Area.Parameters.Fill(InfoAboutCompany);
		
	ElsIf AreaName = "CounterpartyInfo" Then
		
		Area.Parameters.Fill(Selection);
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(
			Selection.Counterparty,
			Selection.DocumentDate,
			,
			,
			,
			LanguageCode);
		Area.Parameters.Fill(InfoAboutCounterparty);
		
	ElsIf AreaName = "Comment" Then
		
		Area.Parameters.Fill(Selection);
		
	EndIf;
		
	Return Area;
	
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

#Region InfobaseUpdate

Procedure RefillVATOutputRecords() Export
	
	Query = New Query;
	Query.Text = "SELECT DISTINCT
	|	VATOutput.Recorder AS Ref
	|FROM
	|	AccumulationRegister.VATOutput AS VATOutput
	|		INNER JOIN Document.CreditNote AS CreditNote
	|		ON VATOutput.Recorder = CreditNote.Ref
	|WHERE
	|	VATOutput.GLAccount = &VATOutputParam";
	
	Query.SetParameter("VATOutputParam", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput"));
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DocObject = Selection.Ref.GetObject();
		
		BeginTransaction();
		
		Try
			
			DriveServer.InitializeAdditionalPropertiesForPosting(DocObject.Ref, DocObject.AdditionalProperties);
			InitializeDocumentData(DocObject.Ref, DocObject.AdditionalProperties);
			
			TableVATOutput = DocObject.AdditionalProperties.TableForRegisterRecords.TableVATOutput;
			
			DocObject.RegisterRecords.VATOutput.Write = True;
			DocObject.RegisterRecords.VATOutput.Load(TableVATOutput);
			InfobaseUpdate.WriteRecordSet(DocObject.RegisterRecords.VATOutput, True);
			
			DocObject.AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'"),
				DocObject.Ref,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				DocObject.Ref.Metadata(),
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure NotTaxableVATOutputRecords() Export
	
	If Not GetFunctionalOption("UseVAT") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	CreditNoteAmountAllocation.Ref AS Ref
	|FROM
	|	Document.CreditNote.AmountAllocation AS CreditNoteAmountAllocation
	|		INNER JOIN Document.CreditNote AS CreditNote
	|		ON CreditNoteAmountAllocation.Ref = CreditNote.Ref
	|		INNER JOIN Catalog.VATRates AS VATRates
	|		ON CreditNoteAmountAllocation.VATRate = VATRates.Ref
	|		LEFT JOIN AccumulationRegister.VATOutput AS VATOutput
	|		ON CreditNoteAmountAllocation.Ref = VATOutput.Recorder
	|			AND CreditNoteAmountAllocation.VATRate = VATOutput.VATRate
	|WHERE
	|	VATRates.NotTaxable
	|	AND CreditNote.VATTaxation <> VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
	|	AND VATOutput.Recorder IS NULL";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		DocObject = Selection.Ref.GetObject();
		
		If WorkWithVAT.GetUseTaxInvoiceForPostingVAT(DocObject.Date, DocObject.Company) Then
			Continue;
		EndIf;
		
		BeginTransaction();
		
		Try
			
			DriveServer.InitializeAdditionalPropertiesForPosting(DocObject.Ref, DocObject.AdditionalProperties);
			Documents.CreditNote.InitializeDocumentData(DocObject.Ref, DocObject.AdditionalProperties);
			
			DriveServer.ReflectVATOutput(DocObject.AdditionalProperties, DocObject.RegisterRecords, False);
			
			DocObject.AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
			
			InfobaseUpdate.WriteRecordSet(DocObject.RegisterRecords.VATOutput, True);
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'"),
				DocObject.Ref,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Documents.CreditNote,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region AccountingTemplates

Function EntryTypes() Export 
	
	EntryTypes = New Array;
	
	Return EntryTypes;
	
EndFunction

Function AccountingFields() Export 
	
	AccountingFields = New Map;
	
	Return AccountingFields;
	
EndFunction
#EndRegion

#EndIf