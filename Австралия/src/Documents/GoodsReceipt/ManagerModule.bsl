#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

Procedure FillByCreditNotes(DocumentData, FilterData, Products, SerialNumbers) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	CreditNote.Ref AS Ref,
	|	CreditNote.PointInTime AS PointInTime,
	|	CreditNote.BasisDocument AS BasisDocument,
	|	CreditNote.Contract AS Contract
	|INTO TT_CreditNotes
	|FROM
	|	Document.CreditNote AS CreditNote
	|WHERE
	|	&CreditNotesConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsReceiptProducts.Order AS Order,
	|	GoodsReceiptProducts.SalesDocument AS SalesDocument,
	|	GoodsReceiptProducts.CreditNote AS CreditNote,
	|	GoodsReceiptProducts.Products AS Products,
	|	GoodsReceiptProducts.Characteristic AS Characteristic,
	|	GoodsReceiptProducts.Batch AS Batch,
	|	SUM(GoodsReceiptProducts.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyIssued
	|FROM
	|	Document.GoodsReceipt.Products AS GoodsReceiptProducts
	|		INNER JOIN TT_CreditNotes AS TT_CreditNotes
	|		ON GoodsReceiptProducts.CreditNote = TT_CreditNotes.Ref
	|		INNER JOIN Document.GoodsReceipt AS GoodsReceipt
	|		ON GoodsReceiptProducts.Ref = GoodsReceipt.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON GoodsReceiptProducts.MeasurementUnit = UOM.Ref
	|WHERE
	|	GoodsReceipt.Posted
	|	AND GoodsReceiptProducts.Ref <> &Ref
	|
	|GROUP BY
	|	GoodsReceiptProducts.Batch,
	|	GoodsReceiptProducts.Order,
	|	GoodsReceiptProducts.SalesDocument,
	|	GoodsReceiptProducts.Products,
	|	GoodsReceiptProducts.Characteristic,
	|	GoodsReceiptProducts.CreditNote
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CreditNoteBalance.SalesOrder AS SalesOrder,
	|	CreditNoteBalance.SalesDocument AS SalesDocument,
	|	CreditNoteBalance.CreditNote AS CreditNote,
	|	CreditNoteBalance.Products AS Products,
	|	CreditNoteBalance.Characteristic AS Characteristic,
	|	CreditNoteBalance.Batch AS Batch,
	|	SUM(CreditNoteBalance.Quantity) AS QuantityBalance
	|INTO TT_CreditNoteBalance
	|FROM
	|	(SELECT
	|		Sales.SalesOrder AS SalesOrder,
	|		Sales.Document AS SalesDocument,
	|		Sales.Recorder AS CreditNote,
	|		Sales.Products AS Products,
	|		Sales.Characteristic AS Characteristic,
	|		Sales.Batch AS Batch,
	|		-Sales.Quantity AS Quantity
	|	FROM
	|		AccumulationRegister.Sales AS Sales
	|	WHERE
	|		Sales.Recorder IN
	|				(SELECT
	|					TT_CreditNotes.Ref AS Ref
	|				FROM
	|					TT_CreditNotes AS TT_CreditNotes)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		GoodsReceiptProducts.Order,
	|		GoodsReceiptProducts.SalesDocument,
	|		GoodsReceiptProducts.CreditNote,
	|		GoodsReceiptProducts.Products,
	|		GoodsReceiptProducts.Characteristic,
	|		GoodsReceiptProducts.Batch,
	|		-GoodsReceiptProducts.Quantity
	|	FROM
	|		Document.GoodsReceipt.Products AS GoodsReceiptProducts
	|	WHERE
	|		GoodsReceiptProducts.Ref.Posted
	|		AND GoodsReceiptProducts.CreditNote IN
	|				(SELECT
	|					TT_CreditNotes.Ref AS Ref
	|				FROM
	|					TT_CreditNotes AS TT_CreditNotes)) AS CreditNoteBalance
	|
	|GROUP BY
	|	CreditNoteBalance.SalesOrder,
	|	CreditNoteBalance.SalesDocument,
	|	CreditNoteBalance.CreditNote,
	|	CreditNoteBalance.Products,
	|	CreditNoteBalance.Characteristic,
	|	CreditNoteBalance.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CreditNoteInventory.LineNumber AS LineNumber,
	|	CreditNoteInventory.Products AS Products,
	|	CreditNoteInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ProductsTypeInventory,
	|	CreditNoteInventory.Characteristic AS Characteristic,
	|	CreditNoteInventory.Batch AS Batch,
	|	CreditNoteInventory.Quantity AS Quantity,
	|	CreditNoteInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	CreditNoteInventory.Ref AS CreditNote,
	|	CASE
	|		WHEN CreditNoteInventory.Order = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE CreditNoteInventory.Order
	|	END AS Order,
	|	TT_CreditNotes.PointInTime AS PointInTime,
	|	TT_CreditNotes.Contract AS Contract,
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
	|	CreditNoteInventory.Price AS Price,
	|	CreditNoteInventory.VATRate AS VATRate,
	|	CreditNoteInventory.InitialAmount AS InitialAmount,
	|	CreditNoteInventory.InitialQuantity AS InitialQuantity,
	|	CASE
	|		WHEN TT_CreditNotes.BasisDocument = UNDEFINED
	|			THEN CreditNoteInventory.SalesDocument
	|		ELSE TT_CreditNotes.BasisDocument
	|	END AS SalesDocument,
	|	CreditNoteInventory.Amount AS Amount,
	|	CreditNoteInventory.VATAmount AS VATAmount,
	|	CreditNoteInventory.Total AS Total,
	|	CreditNoteInventory.CostOfGoodsSold AS CostOfGoodsSold,
	|	CreditNoteInventory.Project AS Project
	|INTO TT_Inventory
	|FROM
	|	Document.CreditNote.Inventory AS CreditNoteInventory
	|		INNER JOIN TT_CreditNotes AS TT_CreditNotes
	|		ON CreditNoteInventory.Ref = TT_CreditNotes.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON CreditNoteInventory.MeasurementUnit = UOM.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	TT_Inventory.Order AS Order,
	|	TT_Inventory.CreditNote AS CreditNote,
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
	|			AND TT_Inventory.Order = TT_InventoryCumulative.Order
	|			AND TT_Inventory.SalesDocument = TT_InventoryCumulative.SalesDocument
	|			AND TT_Inventory.CreditNote = TT_InventoryCumulative.CreditNote
	|			AND TT_Inventory.LineNumber >= TT_InventoryCumulative.LineNumber
	|			AND TT_Inventory.Project = TT_InventoryCumulative.Project
	|
	|GROUP BY
	|	TT_Inventory.LineNumber,
	|	TT_Inventory.Products,
	|	TT_Inventory.Characteristic,
	|	TT_Inventory.Batch,
	|	TT_Inventory.Order,
	|	TT_Inventory.CreditNote,
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
	|	TT_InventoryCumulative.CreditNote AS CreditNote,
	|	TT_InventoryCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_AlreadyIssued.BaseQuantity > TT_InventoryCumulative.BaseQuantityCumulative - TT_InventoryCumulative.BaseQuantity
	|			THEN TT_InventoryCumulative.BaseQuantityCumulative - TT_AlreadyIssued.BaseQuantity
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
	|		LEFT JOIN TT_AlreadyIssued AS TT_AlreadyIssued
	|		ON TT_InventoryCumulative.Products = TT_AlreadyIssued.Products
	|			AND TT_InventoryCumulative.Characteristic = TT_AlreadyIssued.Characteristic
	|			AND TT_InventoryCumulative.Batch = TT_AlreadyIssued.Batch
	|			AND TT_InventoryCumulative.Order = TT_AlreadyIssued.Order
	|			AND TT_InventoryCumulative.SalesDocument = TT_AlreadyIssued.SalesDocument
	|			AND TT_InventoryCumulative.CreditNote = TT_AlreadyIssued.CreditNote
	|WHERE
	|	ISNULL(TT_AlreadyIssued.BaseQuantity, 0) < TT_InventoryCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryNotYetInvoiced.LineNumber AS LineNumber,
	|	TT_InventoryNotYetInvoiced.Products AS Products,
	|	TT_InventoryNotYetInvoiced.Characteristic AS Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch AS Batch,
	|	TT_InventoryNotYetInvoiced.Order AS Order,
	|	TT_InventoryNotYetInvoiced.CreditNote AS CreditNote,
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
	|	TT_InventoryNotYetInvoicedCumulative.Project AS Project
	|INTO TT_InventoryNotYetInvoicedCumulative
	|FROM
	|	TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoiced
	|		INNER JOIN TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoicedCumulative
	|		ON TT_InventoryNotYetInvoiced.Products = TT_InventoryNotYetInvoicedCumulative.Products
	|			AND TT_InventoryNotYetInvoiced.Characteristic = TT_InventoryNotYetInvoicedCumulative.Characteristic
	|			AND TT_InventoryNotYetInvoiced.Batch = TT_InventoryNotYetInvoicedCumulative.Batch
	|			AND TT_InventoryNotYetInvoiced.Order = TT_InventoryNotYetInvoicedCumulative.Order
	|			AND TT_InventoryNotYetInvoiced.SalesDocument = TT_InventoryNotYetInvoicedCumulative.SalesDocument
	|			AND TT_InventoryNotYetInvoiced.CreditNote = TT_InventoryNotYetInvoicedCumulative.CreditNote
	|			AND TT_InventoryNotYetInvoiced.LineNumber >= TT_InventoryNotYetInvoicedCumulative.LineNumber
	|			AND TT_InventoryNotYetInvoiced.Project = TT_InventoryNotYetInvoicedCumulative.Project
	|
	|GROUP BY
	|	TT_InventoryNotYetInvoiced.LineNumber,
	|	TT_InventoryNotYetInvoiced.Products,
	|	TT_InventoryNotYetInvoiced.Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch,
	|	TT_InventoryNotYetInvoiced.Order,
	|	TT_InventoryNotYetInvoiced.CreditNote,
	|	TT_InventoryNotYetInvoiced.Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.Price,
	|	TT_InventoryNotYetInvoicedCumulative.VATRate,
	|	TT_InventoryNotYetInvoicedCumulative.SalesDocument,
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
	|	TT_InventoryNotYetInvoicedCumulative.CreditNote AS CreditNote,
	|	TT_InventoryNotYetInvoicedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_CreditNoteBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|		WHEN TT_CreditNoteBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|			THEN TT_CreditNoteBalance.QuantityBalance - (TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity)
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
	|		INNER JOIN TT_CreditNoteBalance AS TT_CreditNoteBalance
	|		ON TT_InventoryNotYetInvoicedCumulative.Products = TT_CreditNoteBalance.Products
	|			AND TT_InventoryNotYetInvoicedCumulative.Characteristic = TT_CreditNoteBalance.Characteristic
	|			AND TT_InventoryNotYetInvoicedCumulative.Batch = TT_CreditNoteBalance.Batch
	|			AND TT_InventoryNotYetInvoicedCumulative.Order = TT_CreditNoteBalance.SalesOrder
	|			AND TT_InventoryNotYetInvoicedCumulative.SalesDocument = TT_CreditNoteBalance.SalesDocument
	|			AND TT_InventoryNotYetInvoicedCumulative.CreditNote = TT_CreditNoteBalance.CreditNote
	|WHERE
	|	TT_CreditNoteBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
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
	|	TT_Inventory.CreditNote AS CreditNote,
	|	TT_Inventory.PointInTime AS PointInTime,
	|	TT_Inventory.Contract AS Contract,
	|	TT_InventoryToBeInvoiced.Price AS Price,
	|	CASE
	|		WHEN AccountingPolicySliceLast.RegisteredForVAT
	|			THEN ISNULL(TT_InventoryToBeInvoiced.VATRate, CatProducts.VATRate)
	|		ELSE VALUE(Catalog.VATRates.Exempt)
	|	END AS VATRate,
	|	TT_Inventory.InventoryGLAccount AS InventoryGLAccount,
	|	TT_Inventory.VATOutputGLAccount AS VATOutputGLAccount,
	|	TT_InventoryToBeInvoiced.Price AS InitialPrice,
	|	TT_InventoryToBeInvoiced.InitialAmount AS InitialAmount,
	|	TT_InventoryToBeInvoiced.InitialQuantity AS InitialQuantity,
	|	TT_InventoryToBeInvoiced.SalesDocument AS SalesDocument,
	|	TT_InventoryToBeInvoiced.Amount AS Amount,
	|	TT_InventoryToBeInvoiced.VATAmount AS VATAmount,
	|	TT_InventoryToBeInvoiced.Total AS Total,
	|	TT_InventoryToBeInvoiced.CostOfGoodsSold AS CostOfGoodsSold,
	|	TT_InventoryToBeInvoiced.Project AS Project
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_InventoryToBeInvoiced AS TT_InventoryToBeInvoiced
	|		ON TT_Inventory.LineNumber = TT_InventoryToBeInvoiced.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryToBeInvoiced.Order
	|			AND TT_Inventory.CreditNote = TT_InventoryToBeInvoiced.CreditNote
	|		LEFT JOIN Catalog.Products AS CatProducts
	|		ON TT_Inventory.Products = CatProducts.Ref
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(, Company = &Company) AS AccountingPolicySliceLast
	|		ON (TRUE)
	|WHERE
	|	TT_Inventory.ProductsTypeInventory";
	
	If FilterData.Property("ArrayOfCreditNotes") Then
		FilterString = "CreditNote.Ref IN(&ArrayOfCreditNotes)";
		Query.SetParameter("ArrayOfCreditNotes", FilterData.ArrayOfCreditNotes);
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
			
			FilterString = FilterString + "CreditNote." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
			
		EndDo;
		
	EndIf;
	Company = DriveServer.GetCompany(DocumentData.Company);
	Query.Text = StrReplace(Query.Text, "&CreditNotesConditions", FilterString);
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", Company);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	StructureData = New Structure;
	StructureData.Insert("ObjectParameters", DocumentData);
	
	Products.Clear();
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentData.Date, Company);
	
	While Selection.Next() Do
		
		TabularSectionRow = Products.Add();
		FillPropertyValues(TabularSectionRow, Selection);
		
		TabularSectionRow.Total = TabularSectionRow.Amount + ?(DocumentData.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
		
		If AccountingPolicy.UseGoodsReturnFromCustomer Then
			TabularSectionRow.ConnectionKey = TabularSectionRow.LineNumber;
			WorkWithSerialNumbers.SetActualSerialNumbersInTabularSection(DocumentData, TabularSectionRow, SerialNumbers);
		EndIf;	
	EndDo;
		
EndProcedure

Procedure FillByPurchaseOrders(DocumentData, FilterData, Products) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	PurchaseOrder.Ref AS Ref,
	|	PurchaseOrder.Contract AS Contract,
	|	PurchaseOrder.PointInTime AS PointInTime
	|INTO TT_PurchaseOrders
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	(PurchaseOrder.ApprovalStatus = VALUE(Enum.ApprovalStatuses.EmptyRef)
	|			OR PurchaseOrder.ApprovalStatus = VALUE(Enum.ApprovalStatuses.Approved))
	|	AND &PurchaseOrdersConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsReceiptProducts.Order AS Order,
	|	GoodsReceiptProducts.Products AS Products,
	|	GoodsReceiptProducts.Characteristic AS Characteristic,
	|	GoodsReceiptProducts.Batch AS Batch,
	|	SUM(GoodsReceiptProducts.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyInvoiced
	|FROM
	|	TT_PurchaseOrders AS TT_PurchaseOrders
	|		INNER JOIN Document.GoodsReceipt.Products AS GoodsReceiptProducts
	|		ON (GoodsReceiptProducts.Order = TT_PurchaseOrders.Ref)
	|		INNER JOIN Document.GoodsReceipt AS GoodsReceiptDocument
	|		ON (GoodsReceiptProducts.Ref = GoodsReceiptDocument.Ref)
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (GoodsReceiptProducts.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (GoodsReceiptProducts.MeasurementUnit = UOM.Ref)
	|WHERE
	|	GoodsReceiptDocument.Posted
	|	AND GoodsReceiptProducts.Ref <> &Ref
	|	AND ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	GoodsReceiptProducts.Batch,
	|	GoodsReceiptProducts.Order,
	|	GoodsReceiptProducts.Products,
	|	GoodsReceiptProducts.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OrdersBalance.PurchaseOrder AS PurchaseOrder,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|INTO TT_OrdersBalances
	|FROM
	|	(SELECT
	|		OrdersBalance.PurchaseOrder AS PurchaseOrder,
	|		OrdersBalance.Products AS Products,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.PurchaseOrders.Balance(
	|				,
	|				PurchaseOrder IN
	|					(SELECT
	|						TT_PurchaseOrders.Ref
	|					FROM
	|						TT_PurchaseOrders)) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsPurchaseOrders.PurchaseOrder,
	|		DocumentRegisterRecordsPurchaseOrders.Products,
	|		DocumentRegisterRecordsPurchaseOrders.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsPurchaseOrders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsPurchaseOrders.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsPurchaseOrders.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.PurchaseOrders AS DocumentRegisterRecordsPurchaseOrders
	|	WHERE
	|		DocumentRegisterRecordsPurchaseOrders.Recorder = &Ref) AS OrdersBalance
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON OrdersBalance.Products = ProductsCatalog.Ref
	|WHERE
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	OrdersBalance.PurchaseOrder,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	PurchaseOrderInventory.CrossReference AS CrossReference,
	|	PurchaseOrderInventory.Products AS Products,
	|	PurchaseOrderInventory.Characteristic AS Characteristic,
	|	PurchaseOrderInventory.Batch AS Batch,
	|	PurchaseOrderInventory.Quantity AS Quantity,
	|	PurchaseOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	CASE
	|		WHEN &FillAmounts
	|			THEN PurchaseOrderInventory.Price
	|		ELSE 0
	|	END AS Price,
	|	CASE
	|		WHEN &FillAmounts
	|			THEN PurchaseOrderInventory.Amount
	|		ELSE 0
	|	END AS Amount,
	|	PurchaseOrderInventory.VATRate AS VATRate,
	|	CASE
	|		WHEN &FillAmounts
	|			THEN PurchaseOrderInventory.VATAmount
	|		ELSE 0
	|	END AS VATAmount,
	|	CASE
	|		WHEN &FillAmounts
	|			THEN PurchaseOrderInventory.Total
	|		ELSE 0
	|	END AS Total,
	|	PurchaseOrderInventory.Ref AS Order,
	|	PurchaseOrderInventory.Content AS Content,
	|	TT_PurchaseOrders.PointInTime AS PointInTime,
	|	TT_PurchaseOrders.Contract AS Contract,
	|	CASE
	|		WHEN &FillAmounts
	|			THEN PurchaseOrderInventory.DiscountPercent
	|		ELSE 0
	|	END AS DiscountPercent,
	|	CASE
	|		WHEN &FillAmounts
	|			THEN PurchaseOrderInventory.DiscountAmount
	|		ELSE 0
	|	END AS DiscountAmount
	|INTO TT_Products
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|		INNER JOIN TT_PurchaseOrders AS TT_PurchaseOrders
	|		ON PurchaseOrderInventory.Ref = TT_PurchaseOrders.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON PurchaseOrderInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON PurchaseOrderInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	TT_Products.Batch AS Batch,
	|	TT_Products.Order AS Order,
	|	TT_Products.Factor AS Factor,
	|	TT_Products.Quantity * TT_Products.Factor AS BaseQuantity,
	|	SUM(TT_ProductsCumulative.Quantity * TT_ProductsCumulative.Factor) AS BaseQuantityCumulative
	|INTO TT_ProductsCumulative
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_Products AS TT_ProductsCumulative
	|		ON TT_Products.Products = TT_ProductsCumulative.Products
	|			AND TT_Products.Characteristic = TT_ProductsCumulative.Characteristic
	|			AND TT_Products.Batch = TT_ProductsCumulative.Batch
	|			AND TT_Products.Order = TT_ProductsCumulative.Order
	|			AND TT_Products.LineNumber >= TT_ProductsCumulative.LineNumber
	|
	|GROUP BY
	|	TT_Products.LineNumber,
	|	TT_Products.Products,
	|	TT_Products.Characteristic,
	|	TT_Products.Batch,
	|	TT_Products.Order,
	|	TT_Products.Factor,
	|	TT_Products.Quantity * TT_Products.Factor
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsCumulative.LineNumber AS LineNumber,
	|	TT_ProductsCumulative.Products AS Products,
	|	TT_ProductsCumulative.Characteristic AS Characteristic,
	|	TT_ProductsCumulative.Batch AS Batch,
	|	TT_ProductsCumulative.Order AS Order,
	|	TT_ProductsCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_AlreadyInvoiced.BaseQuantity > TT_ProductsCumulative.BaseQuantityCumulative - TT_ProductsCumulative.BaseQuantity
	|			THEN TT_ProductsCumulative.BaseQuantityCumulative - TT_AlreadyInvoiced.BaseQuantity
	|		ELSE TT_ProductsCumulative.BaseQuantity
	|	END AS BaseQuantity
	|INTO TT_ProductsNotYetInvoiced
	|FROM
	|	TT_ProductsCumulative AS TT_ProductsCumulative
	|		LEFT JOIN TT_AlreadyInvoiced AS TT_AlreadyInvoiced
	|		ON TT_ProductsCumulative.Products = TT_AlreadyInvoiced.Products
	|			AND TT_ProductsCumulative.Characteristic = TT_AlreadyInvoiced.Characteristic
	|			AND TT_ProductsCumulative.Batch = TT_AlreadyInvoiced.Batch
	|			AND TT_ProductsCumulative.Order = TT_AlreadyInvoiced.Order
	|WHERE
	|	ISNULL(TT_AlreadyInvoiced.BaseQuantity, 0) < TT_ProductsCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsNotYetInvoiced.LineNumber AS LineNumber,
	|	TT_ProductsNotYetInvoiced.Products AS Products,
	|	TT_ProductsNotYetInvoiced.Characteristic AS Characteristic,
	|	TT_ProductsNotYetInvoiced.Batch AS Batch,
	|	TT_ProductsNotYetInvoiced.Order AS Order,
	|	TT_ProductsNotYetInvoiced.Factor AS Factor,
	|	TT_ProductsNotYetInvoiced.BaseQuantity AS BaseQuantity,
	|	SUM(TT_ProductsNotYetInvoicedCumulative.BaseQuantity) AS BaseQuantityCumulative
	|INTO TT_ProductsNotYetInvoicedCumulative
	|FROM
	|	TT_ProductsNotYetInvoiced AS TT_ProductsNotYetInvoiced
	|		INNER JOIN TT_ProductsNotYetInvoiced AS TT_ProductsNotYetInvoicedCumulative
	|		ON TT_ProductsNotYetInvoiced.Products = TT_ProductsNotYetInvoicedCumulative.Products
	|			AND TT_ProductsNotYetInvoiced.Characteristic = TT_ProductsNotYetInvoicedCumulative.Characteristic
	|			AND TT_ProductsNotYetInvoiced.Batch = TT_ProductsNotYetInvoicedCumulative.Batch
	|			AND TT_ProductsNotYetInvoiced.Order = TT_ProductsNotYetInvoicedCumulative.Order
	|			AND TT_ProductsNotYetInvoiced.LineNumber >= TT_ProductsNotYetInvoicedCumulative.LineNumber
	|
	|GROUP BY
	|	TT_ProductsNotYetInvoiced.LineNumber,
	|	TT_ProductsNotYetInvoiced.Products,
	|	TT_ProductsNotYetInvoiced.Characteristic,
	|	TT_ProductsNotYetInvoiced.Batch,
	|	TT_ProductsNotYetInvoiced.Order,
	|	TT_ProductsNotYetInvoiced.Factor,
	|	TT_ProductsNotYetInvoiced.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsNotYetInvoicedCumulative.LineNumber AS LineNumber,
	|	TT_ProductsNotYetInvoicedCumulative.Products AS Products,
	|	TT_ProductsNotYetInvoicedCumulative.Characteristic AS Characteristic,
	|	TT_ProductsNotYetInvoicedCumulative.Order AS Order,
	|	TT_ProductsNotYetInvoicedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_ProductsNotYetInvoicedCumulative.BaseQuantityCumulative
	|			THEN TT_ProductsNotYetInvoicedCumulative.BaseQuantity
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_ProductsNotYetInvoicedCumulative.BaseQuantityCumulative - TT_ProductsNotYetInvoicedCumulative.BaseQuantity
	|			THEN TT_OrdersBalances.QuantityBalance - (TT_ProductsNotYetInvoicedCumulative.BaseQuantityCumulative - TT_ProductsNotYetInvoicedCumulative.BaseQuantity)
	|	END AS BaseQuantity
	|INTO TT_ProductsToBeInvoiced
	|FROM
	|	TT_ProductsNotYetInvoicedCumulative AS TT_ProductsNotYetInvoicedCumulative
	|		INNER JOIN TT_OrdersBalances AS TT_OrdersBalances
	|		ON TT_ProductsNotYetInvoicedCumulative.Products = TT_OrdersBalances.Products
	|			AND TT_ProductsNotYetInvoicedCumulative.Characteristic = TT_OrdersBalances.Characteristic
	|			AND TT_ProductsNotYetInvoicedCumulative.Order = TT_OrdersBalances.PurchaseOrder
	|WHERE
	|	TT_OrdersBalances.QuantityBalance > TT_ProductsNotYetInvoicedCumulative.BaseQuantityCumulative - TT_ProductsNotYetInvoicedCumulative.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
	|	TT_Products.CrossReference AS CrossReference,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	TT_Products.Batch AS Batch,
	|	CASE
	|		WHEN (CAST(TT_Products.Quantity * TT_Products.Factor AS NUMBER(15, 3))) = TT_ProductsToBeInvoiced.BaseQuantity
	|			THEN TT_Products.Quantity
	|		ELSE CAST(TT_ProductsToBeInvoiced.BaseQuantity / TT_Products.Factor AS NUMBER(15, 3))
	|	END AS Quantity,
	|	(CAST(TT_Products.Quantity * TT_Products.Factor AS NUMBER(15, 3))) <> TT_ProductsToBeInvoiced.BaseQuantity AS RecalcAmounts,
	|	TT_Products.MeasurementUnit AS MeasurementUnit,
	|	TT_Products.Factor AS Factor,
	|	TT_Products.Price AS Price,
	|	TT_Products.Amount AS Amount,
	|	TT_Products.VATRate AS VATRate,
	|	TT_Products.VATAmount AS VATAmount,
	|	TT_Products.Total AS Total,
	|	TT_Products.Order AS Order,
	|	TT_Products.Order AS BasisDocument,
	|	TT_Products.PointInTime AS PointInTime,
	|	TT_Products.Contract AS Contract,
	|	TT_Products.DiscountPercent AS DiscountPercent,
	|	TT_Products.DiscountAmount AS DiscountAmount,
	|	ISNULL(VATRates.Rate, 0) AS VATRateRate
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_ProductsToBeInvoiced AS TT_ProductsToBeInvoiced
	|		ON TT_Products.LineNumber = TT_ProductsToBeInvoiced.LineNumber
	|			AND TT_Products.Order = TT_ProductsToBeInvoiced.Order
	|		LEFT JOIN Catalog.VATRates AS VATRates
	|		ON TT_Products.VATRate = VATRates.Ref
	|
	|ORDER BY
	|	PointInTime,
	|	LineNumber";
	
	If FilterData.Property("OrdersArray") Then
		FilterString = "PurchaseOrder.Ref IN(&OrdersArray)";
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
			
			FilterString = FilterString + "PurchaseOrder." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
			
		EndDo;
		
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&PurchaseOrdersConditions", FilterString);
	
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(DocumentData.Company));
	Query.SetParameter("StructuralUnit", DocumentData.StructuralUnit);
	
	If FilterData.Property("OrdersArray") Then
		ThereIsAdvanceInvoiceByOrders = Documents.SupplierInvoice.ThereIsAdvanceInvoiceByOrders(FilterData.OrdersArray);
	Else
		ThereIsAdvanceInvoiceByOrders = False;
	EndIf;
	
	IsAmountFillingOperation = DocumentData.OperationType = Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier
		Or DocumentData.OperationType = Enums.OperationTypesGoodsReceipt.DropShipping;
		
	FillAmounts = DocumentData.ContinentalMethod And IsAmountFillingOperation
		Or ThereIsAdvanceInvoiceByOrders;
	Query.SetParameter("FillAmounts", FillAmounts);
	
	ProductsTable = Query.Execute().Unload();
	
	If FillAmounts Then
		
		For Each Row In ProductsTable Do
			
			If Row.RecalcAmounts Then
				
				Row.Amount = Round(Row.Quantity * Row.Price, 2);
				Row.DiscountAmount = Round(Row.DiscountPercent * Row.Amount / 100, 2);
				Row.Amount = Row.Amount - Row.DiscountAmount;
				
				If DocumentData.AmountIncludesVAT Then
					Row.VATAmount = Row.Amount - Round(Row.Amount / ((Row.VATRateRate + 100) / 100), 2);
					Row.Total = Row.Amount;
				Else
					Row.VATAmount = Round(Row.Amount * Row.VATRateRate / 100, 2);
					Row.Total = Row.Amount + Row.VATAmount;
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	Products.Load(ProductsTable);
	
EndProcedure

Procedure FillBySalesInvoices(DocumentData, FilterData, Products, SerialNumbers) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Contract AS Contract,
	|	SalesInvoice.PointInTime AS PointInTime,
	|	SalesInvoice.AmountIncludesVAT AS AmountIncludesVAT
	|INTO TT_SalesInvoices
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	&SalesInvoicesConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsReceiptProducts.SalesDocument AS SalesDocument,
	|	GoodsReceiptProducts.Order AS Order,
	|	GoodsReceiptProducts.Products AS Products,
	|	GoodsReceiptProducts.Characteristic AS Characteristic,
	|	GoodsReceiptProducts.Batch AS Batch,
	|	SUM(GoodsReceiptProducts.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyReceived
	|FROM
	|	TT_SalesInvoices AS TT_SalesInvoices
	|		INNER JOIN Document.GoodsReceipt.Products AS GoodsReceiptProducts
	|		ON TT_SalesInvoices.Ref = GoodsReceiptProducts.SalesDocument
	|		INNER JOIN Document.GoodsReceipt AS GoodsReceiptDocument
	|		ON (GoodsReceiptProducts.Ref = GoodsReceiptDocument.Ref)
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (GoodsReceiptProducts.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (GoodsReceiptProducts.MeasurementUnit = UOM.Ref)
	|WHERE
	|	GoodsReceiptDocument.Posted
	|	AND GoodsReceiptProducts.Ref <> &Ref
	|	AND ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	GoodsReceiptProducts.SalesDocument,
	|	GoodsReceiptProducts.Order,
	|	GoodsReceiptProducts.Products,
	|	GoodsReceiptProducts.Characteristic,
	|	GoodsReceiptProducts.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesInvoiceInventory.LineNumber AS LineNumber,
	|	SalesInvoiceInventory.Products AS Products,
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
	|	TT_SalesInvoices.AmountIncludesVAT AS AmountIncludesVAT,
	|	TT_SalesInvoices.Contract AS Contract,
	|	SalesInvoiceInventory.SalesRep AS SalesRep,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SalesInvoiceInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SalesInvoiceInventory.COGSGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS COGSGLAccount,
	|	SalesInvoiceInventory.Amount AS InitialAmount,
	|	SalesInvoiceInventory.Price AS Price,
	|	SalesInvoiceInventory.Quantity AS InitialQuantity,
	|	SalesInvoiceInventory.VATAmount AS InitialVATAmount,
	|	SalesInvoiceInventory.VATRate AS VATRate,
	|	SalesInvoiceInventory.Project AS Project
	|INTO TT_Products
	|FROM
	|	TT_SalesInvoices AS TT_SalesInvoices
	|		INNER JOIN Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		ON TT_SalesInvoices.Ref = SalesInvoiceInventory.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (SalesInvoiceInventory.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SalesInvoiceInventory.MeasurementUnit = UOM.Ref)
	|WHERE
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	TT_Products.Batch AS Batch,
	|	TT_Products.SalesInvoice AS SalesInvoice,
	|	TT_Products.Order AS Order,
	|	TT_Products.Factor AS Factor,
	|	TT_Products.Quantity * TT_Products.Factor AS BaseQuantity,
	|	SUM(TT_ProductsCumulative.Quantity * TT_ProductsCumulative.Factor) AS BaseQuantityCumulative,
	|	TT_ProductsCumulative.InitialAmount AS InitialAmount,
	|	TT_ProductsCumulative.Price AS Price,
	|	TT_ProductsCumulative.InitialQuantity AS InitialQuantity,
	|	TT_ProductsCumulative.InitialVATAmount AS InitialVATAmount,
	|	TT_ProductsCumulative.VATRate AS VATRate,
	|	TT_Products.Project AS Project
	|INTO TT_ProductsCumulative
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_Products AS TT_ProductsCumulative
	|		ON TT_Products.Products = TT_ProductsCumulative.Products
	|			AND TT_Products.Characteristic = TT_ProductsCumulative.Characteristic
	|			AND TT_Products.Batch = TT_ProductsCumulative.Batch
	|			AND TT_Products.SalesInvoice = TT_ProductsCumulative.SalesInvoice
	|			AND TT_Products.Order = TT_ProductsCumulative.Order
	|			AND TT_Products.LineNumber >= TT_ProductsCumulative.LineNumber
	|			AND TT_Products.Project = TT_ProductsCumulative.Project
	|
	|GROUP BY
	|	TT_Products.LineNumber,
	|	TT_Products.Products,
	|	TT_Products.Characteristic,
	|	TT_Products.Batch,
	|	TT_Products.SalesInvoice,
	|	TT_Products.Order,
	|	TT_Products.Factor,
	|	TT_Products.Quantity * TT_Products.Factor,
	|	TT_ProductsCumulative.Price,
	|	TT_ProductsCumulative.InitialQuantity,
	|	TT_ProductsCumulative.InitialAmount,
	|	TT_ProductsCumulative.InitialVATAmount,
	|	TT_ProductsCumulative.VATRate,
	|	TT_Products.Project
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsCumulative.LineNumber AS LineNumber,
	|	TT_ProductsCumulative.Products AS Products,
	|	TT_ProductsCumulative.Characteristic AS Characteristic,
	|	TT_ProductsCumulative.Batch AS Batch,
	|	TT_ProductsCumulative.SalesInvoice AS SalesInvoice,
	|	TT_ProductsCumulative.Order AS Order,
	|	TT_ProductsCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_AlreadyReceived.BaseQuantity > TT_ProductsCumulative.BaseQuantityCumulative - TT_ProductsCumulative.BaseQuantity
	|			THEN TT_ProductsCumulative.BaseQuantityCumulative - TT_AlreadyReceived.BaseQuantity
	|		ELSE TT_ProductsCumulative.BaseQuantity
	|	END AS BaseQuantity,
	|	TT_ProductsCumulative.InitialAmount AS InitialAmount,
	|	TT_ProductsCumulative.Price AS Price,
	|	TT_ProductsCumulative.InitialQuantity AS InitialQuantity,
	|	TT_ProductsCumulative.InitialVATAmount AS InitialVATAmount,
	|	TT_ProductsCumulative.VATRate AS VATRate,
	|	TT_ProductsCumulative.Project AS Project
	|INTO TT_ProductsNotYetReceived
	|FROM
	|	TT_ProductsCumulative AS TT_ProductsCumulative
	|		LEFT JOIN TT_AlreadyReceived AS TT_AlreadyReceived
	|		ON TT_ProductsCumulative.Products = TT_AlreadyReceived.Products
	|			AND TT_ProductsCumulative.Characteristic = TT_AlreadyReceived.Characteristic
	|			AND TT_ProductsCumulative.Batch = TT_AlreadyReceived.Batch
	|			AND TT_ProductsCumulative.SalesInvoice = TT_AlreadyReceived.SalesDocument
	|			AND TT_ProductsCumulative.Order = TT_AlreadyReceived.Order
	|WHERE
	|	ISNULL(TT_AlreadyReceived.BaseQuantity, 0) < TT_ProductsCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	TT_Products.Batch AS Batch,
	|	CASE
	|		WHEN (CAST(TT_Products.Quantity * TT_Products.Factor AS NUMBER(15, 3))) = TT_ProductsNotYetReceived.BaseQuantity
	|			THEN TT_Products.Quantity
	|		ELSE CAST(TT_ProductsNotYetReceived.BaseQuantity / TT_Products.Factor AS NUMBER(15, 3))
	|	END AS Quantity,
	|	TT_Products.MeasurementUnit AS MeasurementUnit,
	|	TT_Products.Factor AS Factor,
	|	TT_Products.SalesInvoice AS SalesInvoice,
	|	TT_Products.Order AS Order,
	|	TT_Products.PointInTime AS PointInTime,
	|	TT_Products.AmountIncludesVAT AS AmountIncludesVAT,
	|	TT_Products.Contract AS Contract,
	|	TT_Products.SalesRep AS SalesRep,
	|	TT_Products.InventoryGLAccount AS InventoryGLAccount,
	|	TT_Products.COGSGLAccount AS COGSGLAccount,
	|	TT_ProductsNotYetReceived.InitialAmount AS InitialAmount,
	|	TT_ProductsNotYetReceived.Price AS Price,
	|	TT_ProductsNotYetReceived.InitialQuantity AS InitialQuantity,
	|	CASE
	|		WHEN TT_ProductsNotYetReceived.InitialQuantity = 0
	|			THEN 0
	|		ELSE TT_ProductsNotYetReceived.InitialVATAmount / TT_ProductsNotYetReceived.InitialQuantity * TT_ProductsNotYetReceived.BaseQuantity
	|	END AS VATAmount,
	|	TT_ProductsNotYetReceived.VATRate AS VATRate,
	|	CASE
	|		WHEN TT_ProductsNotYetReceived.InitialQuantity = 0
	|			THEN 0
	|		ELSE TT_ProductsNotYetReceived.InitialAmount / TT_ProductsNotYetReceived.InitialQuantity * TT_ProductsNotYetReceived.BaseQuantity
	|	END AS Amount,
	|	TT_Products.Project AS Project
	|INTO TT_ProductsWithoutCOGS
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_ProductsNotYetReceived AS TT_ProductsNotYetReceived
	|		ON TT_Products.LineNumber = TT_ProductsNotYetReceived.LineNumber
	|			AND TT_Products.SalesInvoice = TT_ProductsNotYetReceived.SalesInvoice
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_ProductsWithoutCOGS.LineNumber AS LineNumber,
	|	TT_ProductsWithoutCOGS.Products AS Products,
	|	TT_ProductsWithoutCOGS.Characteristic AS Characteristic,
	|	TT_ProductsWithoutCOGS.Batch AS Batch,
	|	TT_ProductsWithoutCOGS.Quantity AS Quantity,
	|	TT_ProductsWithoutCOGS.MeasurementUnit AS MeasurementUnit,
	|	TT_ProductsWithoutCOGS.Factor AS Factor,
	|	TT_ProductsWithoutCOGS.SalesInvoice AS SalesDocument,
	|	TT_ProductsWithoutCOGS.Order AS Order,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssue,
	|	TT_ProductsWithoutCOGS.PointInTime AS PointInTime,
	|	TT_ProductsWithoutCOGS.Contract AS Contract,
	|	TT_ProductsWithoutCOGS.SalesRep AS SalesRep,
	|	TT_ProductsWithoutCOGS.InventoryGLAccount AS InventoryGLAccount,
	|	TT_ProductsWithoutCOGS.COGSGLAccount AS COGSGLAccount,
	|	TT_ProductsWithoutCOGS.InitialAmount AS InitialAmount,
	|	TT_ProductsWithoutCOGS.Price AS Price,
	|	TT_ProductsWithoutCOGS.InitialQuantity AS InitialQuantity,
	|	TT_ProductsWithoutCOGS.VATAmount AS VATAmount,
	|	TT_ProductsWithoutCOGS.VATRate AS VATRate,
	|	TT_ProductsWithoutCOGS.Amount AS Amount,
	|	CASE
	|		WHEN TT_ProductsWithoutCOGS.InitialQuantity = 0
	|			THEN 0
	|		WHEN TT_ProductsWithoutCOGS.AmountIncludesVAT
	|			THEN TT_ProductsWithoutCOGS.Amount
	|		ELSE TT_ProductsWithoutCOGS.Amount + TT_ProductsWithoutCOGS.VATAmount
	|	END AS Total,
	|	SalesTurnovers.CostTurnover / SalesTurnovers.QuantityTurnover * TT_ProductsWithoutCOGS.Quantity AS CostOfGoodsSold,
	|	TT_ProductsWithoutCOGS.Project AS Project
	|FROM
	|	TT_ProductsWithoutCOGS AS TT_ProductsWithoutCOGS
	|		LEFT JOIN AccumulationRegister.Sales.Turnovers(, , Recorder, ) AS SalesTurnovers
	|		ON TT_ProductsWithoutCOGS.SalesInvoice = SalesTurnovers.Recorder
	|			AND TT_ProductsWithoutCOGS.Products = SalesTurnovers.Products
	|			AND TT_ProductsWithoutCOGS.Characteristic = SalesTurnovers.Characteristic
	|			AND (TT_ProductsWithoutCOGS.Batch = SalesTurnovers.Batch
	|				OR SalesTurnovers.Batch = VALUE(Catalog.ProductsBatches.EmptyRef))
	|
	|ORDER BY
	|	PointInTime,
	|	LineNumber";
	
	If FilterData.Property("SalesInvoicesArray") Then
		FilterString = "SalesInvoice.Ref IN(&SalesInvoicesArray)";
		Query.SetParameter("SalesInvoicesArray", FilterData.SalesInvoicesArray);
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
	
	Query.Text = StrReplace(Query.Text, "&SalesInvoicesConditions", FilterString);
	
	Company = DriveServer.GetCompany(DocumentData.Company);
	
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", Company);
	Query.SetParameter("StructuralUnit", DocumentData.StructuralUnit);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	StructureData = New Structure;
	StructureData.Insert("ObjectParameters", DocumentData);
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentData.Date, Company);
	
	ResultTable = Query.Execute().Unload();
	For Each ResultTableRow In ResultTable Do
		NewRow = Products.Add();
		FillPropertyValues(NewRow, ResultTableRow);
		
		If AccountingPolicy.UseGoodsReturnFromCustomer Then
			NewRow.ConnectionKey = NewRow.LineNumber;
			WorkWithSerialNumbers.SetActualSerialNumbersInTabularSection(DocumentData, NewRow ,SerialNumbers);
		EndIf;
		
	EndDo;
		
EndProcedure

Procedure FillBySupplierInvoices(DocumentData, FilterData, Products, DefaultFill = True) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SupplierInvoice.Ref AS Ref,
	|	SupplierInvoice.Contract AS Contract,
	|	SupplierInvoice.PointInTime AS PointInTime,
	|	SupplierInvoice.OperationKind AS OperationKind
	|INTO TT_SupplierInvoices
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	&SupplierInvoicesConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsReceiptProducts.SupplierInvoice AS SupplierInvoice,
	|	GoodsReceiptProducts.Order AS Order,
	|	GoodsReceiptProducts.Products AS Products,
	|	GoodsReceiptProducts.Characteristic AS Characteristic,
	|	GoodsReceiptProducts.Batch AS Batch,
	|	SUM(GoodsReceiptProducts.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyReceived
	|FROM
	|	TT_SupplierInvoices AS TT_SupplierInvoices
	|		INNER JOIN Document.GoodsReceipt.Products AS GoodsReceiptProducts
	|		ON TT_SupplierInvoices.Ref = GoodsReceiptProducts.SupplierInvoice
	|		INNER JOIN Document.GoodsReceipt AS GoodsReceiptDocument
	|		ON (GoodsReceiptProducts.Ref = GoodsReceiptDocument.Ref)
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (GoodsReceiptProducts.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (GoodsReceiptProducts.MeasurementUnit = UOM.Ref)
	|WHERE
	|	GoodsReceiptDocument.Posted
	|	AND GoodsReceiptProducts.Ref <> &Ref
	|	AND ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	GoodsReceiptProducts.Batch,
	|	GoodsReceiptProducts.SupplierInvoice,
	|	GoodsReceiptProducts.Order,
	|	GoodsReceiptProducts.Products,
	|	GoodsReceiptProducts.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	InvoicedBalance.SupplierInvoice AS SupplierInvoice,
	|	InvoicedBalance.PurchaseOrder AS Order,
	|	InvoicedBalance.Products AS Products,
	|	InvoicedBalance.Characteristic AS Characteristic,
	|	SUM(InvoicedBalance.QuantityBalance) AS QuantityBalance
	|INTO TT_InvoicedBalances
	|FROM
	|	(SELECT
	|		InvoicedBalance.SupplierInvoice AS SupplierInvoice,
	|		InvoicedBalance.PurchaseOrder AS PurchaseOrder,
	|		InvoicedBalance.Products AS Products,
	|		InvoicedBalance.Characteristic AS Characteristic,
	|		InvoicedBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.GoodsInvoicedNotReceived.Balance(
	|				,
	|				SupplierInvoice IN
	|					(SELECT
	|						TT_SupplierInvoices.Ref
	|					FROM
	|						TT_SupplierInvoices)) AS InvoicedBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecords.SupplierInvoice,
	|		DocumentRegisterRecords.PurchaseOrder,
	|		DocumentRegisterRecords.Products,
	|		DocumentRegisterRecords.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecords.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecords.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.GoodsInvoicedNotReceived AS DocumentRegisterRecords
	|	WHERE
	|		DocumentRegisterRecords.Recorder = &Ref) AS InvoicedBalance
	|
	|GROUP BY
	|	InvoicedBalance.SupplierInvoice,
	|	InvoicedBalance.PurchaseOrder,
	|	InvoicedBalance.Products,
	|	InvoicedBalance.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SupplierInvoiceInventory.LineNumber AS LineNumber,
	|	SupplierInvoiceInventory.CrossReference AS CrossReference,
	|	SupplierInvoiceInventory.Products AS Products,
	|	SupplierInvoiceInventory.Characteristic AS Characteristic,
	|	SupplierInvoiceInventory.Batch AS Batch,
	|	SupplierInvoiceInventory.Quantity AS Quantity,
	|	SupplierInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	SupplierInvoiceInventory.Ref AS SupplierInvoice,
	|	SupplierInvoiceInventory.Order AS Order,
	|	SupplierInvoiceInventory.Content AS Content,
	|	TT_SupplierInvoices.PointInTime AS PointInTime,
	|	TT_SupplierInvoices.Contract AS Contract,
	|	CASE
	|		WHEN &FillAmounts
	|			THEN SupplierInvoiceInventory.Price
	|		ELSE 0
	|	END AS Price,
	|	CASE
	|		WHEN &FillAmounts
	|			THEN SupplierInvoiceInventory.Amount
	|		ELSE 0
	|	END AS Amount,
	|	SupplierInvoiceInventory.VATRate AS VATRate,
	|	CASE
	|		WHEN &FillAmounts
	|			THEN SupplierInvoiceInventory.VATAmount
	|		ELSE 0
	|	END AS VATAmount,
	|	CASE
	|		WHEN &FillAmounts
	|			THEN SupplierInvoiceInventory.Total
	|		ELSE 0
	|	END AS Total,
	|	CASE
	|		WHEN &FillAmounts
	|			THEN SupplierInvoiceInventory.DiscountPercent
	|		ELSE 0
	|	END AS DiscountPercent,
	|	CASE
	|		WHEN &FillAmounts
	|			THEN SupplierInvoiceInventory.DiscountAmount
	|		ELSE 0
	|	END AS DiscountAmount
	|INTO TT_Products
	|FROM
	|	TT_SupplierInvoices AS TT_SupplierInvoices
	|		INNER JOIN Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		ON TT_SupplierInvoices.Ref = SupplierInvoiceInventory.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (SupplierInvoiceInventory.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SupplierInvoiceInventory.MeasurementUnit = UOM.Ref)
	|WHERE
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND SupplierInvoiceInventory.GoodsReceipt = VALUE(Document.GoodsReceipt.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	TT_Products.Batch AS Batch,
	|	TT_Products.SupplierInvoice AS SupplierInvoice,
	|	TT_Products.Order AS Order,
	|	TT_Products.Factor AS Factor,
	|	TT_Products.Quantity * TT_Products.Factor AS BaseQuantity,
	|	SUM(TT_ProductsCumulative.Quantity * TT_ProductsCumulative.Factor) AS BaseQuantityCumulative
	|INTO TT_ProductsCumulative
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_Products AS TT_ProductsCumulative
	|		ON TT_Products.Products = TT_ProductsCumulative.Products
	|			AND TT_Products.Characteristic = TT_ProductsCumulative.Characteristic
	|			AND TT_Products.Batch = TT_ProductsCumulative.Batch
	|			AND TT_Products.SupplierInvoice = TT_ProductsCumulative.SupplierInvoice
	|			AND TT_Products.Order = TT_ProductsCumulative.Order
	|			AND TT_Products.LineNumber >= TT_ProductsCumulative.LineNumber
	|
	|GROUP BY
	|	TT_Products.LineNumber,
	|	TT_Products.Products,
	|	TT_Products.Characteristic,
	|	TT_Products.Batch,
	|	TT_Products.SupplierInvoice,
	|	TT_Products.Order,
	|	TT_Products.Factor,
	|	TT_Products.Quantity * TT_Products.Factor
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsCumulative.LineNumber AS LineNumber,
	|	TT_ProductsCumulative.Products AS Products,
	|	TT_ProductsCumulative.Characteristic AS Characteristic,
	|	TT_ProductsCumulative.Batch AS Batch,
	|	TT_ProductsCumulative.SupplierInvoice AS SupplierInvoice,
	|	TT_ProductsCumulative.Order AS Order,
	|	TT_ProductsCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_AlreadyReceived.BaseQuantity > TT_ProductsCumulative.BaseQuantityCumulative - TT_ProductsCumulative.BaseQuantity
	|			THEN TT_ProductsCumulative.BaseQuantityCumulative - TT_AlreadyReceived.BaseQuantity
	|		ELSE TT_ProductsCumulative.BaseQuantity
	|	END AS BaseQuantity
	|INTO TT_ProductsNotYetReceived
	|FROM
	|	TT_ProductsCumulative AS TT_ProductsCumulative
	|		LEFT JOIN TT_AlreadyReceived AS TT_AlreadyReceived
	|		ON TT_ProductsCumulative.Products = TT_AlreadyReceived.Products
	|			AND TT_ProductsCumulative.Characteristic = TT_AlreadyReceived.Characteristic
	|			AND TT_ProductsCumulative.Batch = TT_AlreadyReceived.Batch
	|			AND TT_ProductsCumulative.SupplierInvoice = TT_AlreadyReceived.SupplierInvoice
	|			AND TT_ProductsCumulative.Order = TT_AlreadyReceived.Order
	|WHERE
	|	ISNULL(TT_AlreadyReceived.BaseQuantity, 0) < TT_ProductsCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsNotYetReceived.LineNumber AS LineNumber,
	|	TT_ProductsNotYetReceived.Products AS Products,
	|	TT_ProductsNotYetReceived.Characteristic AS Characteristic,
	|	TT_ProductsNotYetReceived.Batch AS Batch,
	|	TT_ProductsNotYetReceived.SupplierInvoice AS SupplierInvoice,
	|	TT_ProductsNotYetReceived.Order AS Order,
	|	TT_ProductsNotYetReceived.Factor AS Factor,
	|	TT_ProductsNotYetReceived.BaseQuantity AS BaseQuantity,
	|	SUM(TT_ProductsNotYetReceivedCumulative.BaseQuantity) AS BaseQuantityCumulative
	|INTO TT_ProductsNotYetReceivedCumulative
	|FROM
	|	TT_ProductsNotYetReceived AS TT_ProductsNotYetReceived
	|		INNER JOIN TT_ProductsNotYetReceived AS TT_ProductsNotYetReceivedCumulative
	|		ON TT_ProductsNotYetReceived.Products = TT_ProductsNotYetReceivedCumulative.Products
	|			AND TT_ProductsNotYetReceived.Characteristic = TT_ProductsNotYetReceivedCumulative.Characteristic
	|			AND TT_ProductsNotYetReceived.Batch = TT_ProductsNotYetReceivedCumulative.Batch
	|			AND TT_ProductsNotYetReceived.SupplierInvoice = TT_ProductsNotYetReceivedCumulative.SupplierInvoice
	|			AND TT_ProductsNotYetReceived.Order = TT_ProductsNotYetReceivedCumulative.Order
	|			AND TT_ProductsNotYetReceived.LineNumber >= TT_ProductsNotYetReceivedCumulative.LineNumber
	|
	|GROUP BY
	|	TT_ProductsNotYetReceived.LineNumber,
	|	TT_ProductsNotYetReceived.Products,
	|	TT_ProductsNotYetReceived.Characteristic,
	|	TT_ProductsNotYetReceived.Batch,
	|	TT_ProductsNotYetReceived.SupplierInvoice,
	|	TT_ProductsNotYetReceived.Order,
	|	TT_ProductsNotYetReceived.Factor,
	|	TT_ProductsNotYetReceived.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsNotYetReceivedCumulative.LineNumber AS LineNumber,
	|	TT_ProductsNotYetReceivedCumulative.Products AS Products,
	|	TT_ProductsNotYetReceivedCumulative.Characteristic AS Characteristic,
	|	TT_ProductsNotYetReceivedCumulative.Batch AS Batch,
	|	TT_ProductsNotYetReceivedCumulative.SupplierInvoice AS SupplierInvoice,
	|	TT_ProductsNotYetReceivedCumulative.Order AS Order,
	|	TT_ProductsNotYetReceivedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_InvoicedBalances.QuantityBalance > TT_ProductsNotYetReceivedCumulative.BaseQuantityCumulative
	|			THEN TT_ProductsNotYetReceivedCumulative.BaseQuantity
	|		WHEN TT_InvoicedBalances.QuantityBalance > TT_ProductsNotYetReceivedCumulative.BaseQuantityCumulative - TT_ProductsNotYetReceivedCumulative.BaseQuantity
	|			THEN TT_InvoicedBalances.QuantityBalance - (TT_ProductsNotYetReceivedCumulative.BaseQuantityCumulative - TT_ProductsNotYetReceivedCumulative.BaseQuantity)
	|	END AS BaseQuantity
	|INTO TT_ProductsToBeReceived
	|FROM
	|	TT_ProductsNotYetReceivedCumulative AS TT_ProductsNotYetReceivedCumulative
	|		INNER JOIN TT_InvoicedBalances AS TT_InvoicedBalances
	|		ON TT_ProductsNotYetReceivedCumulative.Products = TT_InvoicedBalances.Products
	|			AND TT_ProductsNotYetReceivedCumulative.Characteristic = TT_InvoicedBalances.Characteristic
	|			AND TT_ProductsNotYetReceivedCumulative.SupplierInvoice = TT_InvoicedBalances.SupplierInvoice
	|			AND TT_ProductsNotYetReceivedCumulative.Order = TT_InvoicedBalances.Order
	|WHERE
	|	TT_InvoicedBalances.QuantityBalance > TT_ProductsNotYetReceivedCumulative.BaseQuantityCumulative - TT_ProductsNotYetReceivedCumulative.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
	|	TT_Products.CrossReference AS CrossReference,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	TT_Products.Batch AS Batch,
	|	CASE
	|		WHEN (CAST(TT_Products.Quantity * TT_Products.Factor AS NUMBER(15, 3))) = TT_ProductsToBeReceived.BaseQuantity
	|			THEN TT_Products.Quantity
	|		ELSE CAST(TT_ProductsToBeReceived.BaseQuantity / TT_Products.Factor AS NUMBER(15, 3))
	|	END AS Quantity,
	|	TT_Products.MeasurementUnit AS MeasurementUnit,
	|	TT_Products.Factor AS Factor,
	|	TT_Products.SupplierInvoice AS SupplierInvoice,
	|	TT_Products.Order AS Order,
	|	TT_Products.PointInTime AS PointInTime,
	|	TT_Products.Contract AS Contract,
	|	TT_Products.Price AS Price,
	|	TT_Products.Amount AS Amount,
	|	TT_Products.VATRate AS VATRate,
	|	TT_Products.VATAmount AS VATAmount,
	|	TT_Products.Total AS Total,
	|	TT_Products.DiscountPercent AS DiscountPercent,
	|	TT_Products.DiscountAmount AS DiscountAmount
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_ProductsToBeReceived AS TT_ProductsToBeReceived
	|		ON TT_Products.LineNumber = TT_ProductsToBeReceived.LineNumber
	|			AND TT_Products.SupplierInvoice = TT_ProductsToBeReceived.SupplierInvoice
	|
	|ORDER BY
	|	PointInTime,
	|	LineNumber";
	
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
	
	Query.Text = StrReplace(Query.Text, "&SupplierInvoicesConditions", FilterString);
	
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(DocumentData.Company));
	Query.SetParameter("StructuralUnit", DocumentData.StructuralUnit);
	
	If FilterData.Property("InvoicesArray") Then
		ThereIsAdvanceInvoice = ThereIsAdvanceInvoice(FilterData.InvoicesArray);
	Else
		ThereIsAdvanceInvoice = False;
	EndIf;
	
	FillAmounts = (DocumentData.ContinentalMethod
		And DocumentData.OperationType = Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier)
		Or ThereIsAdvanceInvoice;
	Query.SetParameter("FillAmounts", FillAmounts);
	
	ResultTable = Query.Execute().Unload();
	For Each ResultTableRow In ResultTable Do
		ProductsRow = Products.Add();
		FillPropertyValues(ProductsRow, ResultTableRow);
		If Not DefaultFill Then
			ProductsRow.SalesInvoice = ResultTableRow.SupplierInvoice;
		EndIf;
	EndDo;
	
EndProcedure

Procedure FillBySubcontractorOrdersReturn(DocumentData, FilterData, Products) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SubcontractorOrderIssued.Ref AS Ref,
	|	SubcontractorOrderIssued.Contract AS Contract,
	|	SubcontractorOrderIssued.PointInTime AS PointInTime
	|INTO TT_SubcontractorOrders
	|FROM
	|	Document.SubcontractorOrderIssued AS SubcontractorOrderIssued
	|WHERE
	|	&SubcontractorOrderIssuedConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsReceipt.Order AS Order,
	|	GoodsReceipt.Ref AS Ref
	|INTO TT_GoodsReceiptDocument
	|FROM
	|	TT_SubcontractorOrders AS TT_SubcontractorOrders
	|		INNER JOIN Document.GoodsReceipt AS GoodsReceipt
	|		ON TT_SubcontractorOrders.Ref = GoodsReceipt.Order
	|WHERE
	|	GoodsReceipt.Posted
	|	AND GoodsReceipt.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromSubcontractor)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_GoodsReceiptDocument.Order AS Order,
	|	GoodsReceiptProducts.Products AS Products,
	|	GoodsReceiptProducts.Characteristic AS Characteristic,
	|	GoodsReceiptProducts.Batch AS Batch,
	|	SUM(GoodsReceiptProducts.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyInvoiced
	|FROM
	|	TT_GoodsReceiptDocument AS TT_GoodsReceiptDocument
	|		INNER JOIN Document.GoodsReceipt.Products AS GoodsReceiptProducts
	|		ON TT_GoodsReceiptDocument.Ref = GoodsReceiptProducts.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (GoodsReceiptProducts.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (GoodsReceiptProducts.MeasurementUnit = UOM.Ref)
	|WHERE
	|	GoodsReceiptProducts.Ref <> &Ref
	|	AND ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	GoodsReceiptProducts.Batch,
	|	TT_GoodsReceiptDocument.Order,
	|	GoodsReceiptProducts.Products,
	|	GoodsReceiptProducts.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TransferredInventoryBalance.Order AS Order,
	|	TransferredInventoryBalance.Products AS Products,
	|	TransferredInventoryBalance.Characteristic AS Characteristic,
	|	SUM(TransferredInventoryBalance.QuantityBalance) AS QuantityBalance
	|INTO TT_OrdersBalances
	|FROM
	|	(SELECT
	|		TransferredInventoryBalance.Order AS Order,
	|		TransferredInventoryBalance.Products AS Products,
	|		TransferredInventoryBalance.Characteristic AS Characteristic,
	|		TransferredInventoryBalance.Batch AS Batch,
	|		TransferredInventoryBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.StockTransferredToThirdParties.Balance(
	|				,
	|				Order IN
	|					(SELECT
	|						TT_SubcontractorOrders.Ref
	|					FROM
	|						TT_SubcontractorOrders)) AS TransferredInventoryBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsTransferredInventory.Order,
	|		DocumentRegisterRecordsTransferredInventory.Products,
	|		DocumentRegisterRecordsTransferredInventory.Characteristic,
	|		DocumentRegisterRecordsTransferredInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsTransferredInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsTransferredInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsTransferredInventory.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.StockTransferredToThirdParties AS DocumentRegisterRecordsTransferredInventory
	|	WHERE
	|		DocumentRegisterRecordsTransferredInventory.Recorder = &Ref) AS TransferredInventoryBalance
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON TransferredInventoryBalance.Products = ProductsCatalog.Ref
	|WHERE
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	TransferredInventoryBalance.Order,
	|	TransferredInventoryBalance.Products,
	|	TransferredInventoryBalance.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorOrderInventory.LineNumber AS LineNumber,
	|	SubcontractorOrderInventory.Products AS Products,
	|	SubcontractorOrderInventory.Characteristic AS Characteristic,
	|	SubcontractorOrderInventory.Quantity AS Quantity,
	|	SubcontractorOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	SubcontractorOrderInventory.Ref AS Order,
	|	TT_SubcontractorOrders.PointInTime AS PointInTime,
	|	TT_SubcontractorOrders.Contract AS Contract
	|INTO TT_Products
	|FROM
	|	TT_SubcontractorOrders AS TT_SubcontractorOrders
	|		INNER JOIN Document.SubcontractorOrderIssued.Inventory AS SubcontractorOrderInventory
	|		ON TT_SubcontractorOrders.Ref = SubcontractorOrderInventory.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (SubcontractorOrderInventory.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SubcontractorOrderInventory.MeasurementUnit = UOM.Ref)
	|WHERE
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	TT_Products.Order AS Order,
	|	TT_Products.Factor AS Factor,
	|	TT_Products.Quantity * TT_Products.Factor AS BaseQuantity,
	|	SUM(TT_ProductsCumulative.Quantity * TT_ProductsCumulative.Factor) AS BaseQuantityCumulative
	|INTO TT_ProductsCumulative
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_Products AS TT_ProductsCumulative
	|		ON TT_Products.Products = TT_ProductsCumulative.Products
	|			AND TT_Products.Characteristic = TT_ProductsCumulative.Characteristic
	|			AND TT_Products.Order = TT_ProductsCumulative.Order
	|			AND TT_Products.LineNumber >= TT_ProductsCumulative.LineNumber
	|
	|GROUP BY
	|	TT_Products.LineNumber,
	|	TT_Products.Products,
	|	TT_Products.Characteristic,
	|	TT_Products.Order,
	|	TT_Products.Factor,
	|	TT_Products.Quantity * TT_Products.Factor
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsCumulative.LineNumber AS LineNumber,
	|	TT_ProductsCumulative.Products AS Products,
	|	TT_ProductsCumulative.Characteristic AS Characteristic,
	|	TT_ProductsCumulative.Order AS Order,
	|	TT_ProductsCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_AlreadyInvoiced.BaseQuantity > TT_ProductsCumulative.BaseQuantityCumulative - TT_ProductsCumulative.BaseQuantity
	|			THEN TT_ProductsCumulative.BaseQuantityCumulative - TT_AlreadyInvoiced.BaseQuantity
	|		ELSE TT_ProductsCumulative.BaseQuantity
	|	END AS BaseQuantity
	|INTO TT_ProductsNotYetInvoiced
	|FROM
	|	TT_ProductsCumulative AS TT_ProductsCumulative
	|		LEFT JOIN TT_AlreadyInvoiced AS TT_AlreadyInvoiced
	|		ON TT_ProductsCumulative.Products = TT_AlreadyInvoiced.Products
	|			AND TT_ProductsCumulative.Characteristic = TT_AlreadyInvoiced.Characteristic
	|			AND TT_ProductsCumulative.Order = TT_AlreadyInvoiced.Order
	|WHERE
	|	ISNULL(TT_AlreadyInvoiced.BaseQuantity, 0) < TT_ProductsCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsNotYetInvoiced.LineNumber AS LineNumber,
	|	TT_ProductsNotYetInvoiced.Products AS Products,
	|	TT_ProductsNotYetInvoiced.Characteristic AS Characteristic,
	|	TT_ProductsNotYetInvoiced.Order AS Order,
	|	TT_ProductsNotYetInvoiced.Factor AS Factor,
	|	TT_ProductsNotYetInvoiced.BaseQuantity AS BaseQuantity,
	|	SUM(TT_ProductsNotYetInvoicedCumulative.BaseQuantity) AS BaseQuantityCumulative
	|INTO TT_ProductsNotYetInvoicedCumulative
	|FROM
	|	TT_ProductsNotYetInvoiced AS TT_ProductsNotYetInvoiced
	|		INNER JOIN TT_ProductsNotYetInvoiced AS TT_ProductsNotYetInvoicedCumulative
	|		ON TT_ProductsNotYetInvoiced.Products = TT_ProductsNotYetInvoicedCumulative.Products
	|			AND TT_ProductsNotYetInvoiced.Characteristic = TT_ProductsNotYetInvoicedCumulative.Characteristic
	|			AND TT_ProductsNotYetInvoiced.Order = TT_ProductsNotYetInvoicedCumulative.Order
	|			AND TT_ProductsNotYetInvoiced.LineNumber >= TT_ProductsNotYetInvoicedCumulative.LineNumber
	|
	|GROUP BY
	|	TT_ProductsNotYetInvoiced.LineNumber,
	|	TT_ProductsNotYetInvoiced.Products,
	|	TT_ProductsNotYetInvoiced.Characteristic,
	|	TT_ProductsNotYetInvoiced.Order,
	|	TT_ProductsNotYetInvoiced.Factor,
	|	TT_ProductsNotYetInvoiced.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsNotYetInvoicedCumulative.LineNumber AS LineNumber,
	|	TT_ProductsNotYetInvoicedCumulative.Products AS Products,
	|	TT_ProductsNotYetInvoicedCumulative.Characteristic AS Characteristic,
	|	TT_ProductsNotYetInvoicedCumulative.Order AS Order,
	|	CASE
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_ProductsNotYetInvoicedCumulative.BaseQuantityCumulative
	|			THEN TT_ProductsNotYetInvoicedCumulative.BaseQuantity
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_ProductsNotYetInvoicedCumulative.BaseQuantityCumulative - TT_ProductsNotYetInvoicedCumulative.BaseQuantity
	|			THEN TT_OrdersBalances.QuantityBalance - (TT_ProductsNotYetInvoicedCumulative.BaseQuantityCumulative - TT_ProductsNotYetInvoicedCumulative.BaseQuantity)
	|	END AS BaseQuantity
	|INTO TT_ProductsToBeInvoiced
	|FROM
	|	TT_ProductsNotYetInvoicedCumulative AS TT_ProductsNotYetInvoicedCumulative
	|		INNER JOIN TT_OrdersBalances AS TT_OrdersBalances
	|		ON TT_ProductsNotYetInvoicedCumulative.Products = TT_OrdersBalances.Products
	|			AND TT_ProductsNotYetInvoicedCumulative.Characteristic = TT_OrdersBalances.Characteristic
	|			AND TT_ProductsNotYetInvoicedCumulative.Order = TT_OrdersBalances.Order
	|WHERE
	|	TT_OrdersBalances.QuantityBalance > TT_ProductsNotYetInvoicedCumulative.BaseQuantityCumulative - TT_ProductsNotYetInvoicedCumulative.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	CASE
	|		WHEN (CAST(TT_Products.Quantity * TT_Products.Factor AS NUMBER(15, 3))) = TT_ProductsToBeInvoiced.BaseQuantity
	|			THEN TT_Products.Quantity
	|		ELSE CAST(TT_ProductsToBeInvoiced.BaseQuantity / TT_Products.Factor AS NUMBER(15, 3))
	|	END AS Quantity,
	|	TT_Products.MeasurementUnit AS MeasurementUnit,
	|	TT_Products.Order AS Order,
	|	TT_Products.Contract AS Contract
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_ProductsToBeInvoiced AS TT_ProductsToBeInvoiced
	|		ON TT_Products.LineNumber = TT_ProductsToBeInvoiced.LineNumber
	|			AND TT_Products.Order = TT_ProductsToBeInvoiced.Order
	|
	|ORDER BY
	|	TT_Products.PointInTime,
	|	LineNumber";
	
	If FilterData.Property("OrdersArray") Then
		FilterString = "SubcontractorOrderIssued.Ref IN(&OrdersArray)";
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
			
			FilterString = FilterString + "SubcontractorOrderIssued." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
			
		EndDo;
		
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&SubcontractorOrderIssuedConditions", FilterString);
	
	Query.SetParameter("Ref", DocumentData.Ref);
	
	Products.Load(Query.Execute().Unload());
	
EndProcedure

Procedure FillBySubcontractorOrders(DocumentData, FilterData, Products) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SubcontractorOrder.Ref AS Ref
	|INTO TT_SubcontractorOrders
	|FROM
	|	Document.SubcontractorOrderIssued AS SubcontractorOrder
	|WHERE
	|	&SubcontractorOrderReceivedConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OrdersBalance.SubcontractorOrder AS SubcontractorOrder,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		OrdersBalance.SubcontractorOrder AS SubcontractorOrder,
	|		OrdersBalance.Products AS Products,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.SubcontractorOrdersIssued.Balance(
	|				,
	|				SubcontractorOrder IN
	|						(SELECT
	|							TT_SubcontractorOrders.Ref
	|						FROM
	|							TT_SubcontractorOrders)
	|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsSubcontractorOrdersIssued.SubcontractorOrder,
	|		DocumentRegisterRecordsSubcontractorOrdersIssued.Products,
	|		DocumentRegisterRecordsSubcontractorOrdersIssued.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsSubcontractorOrdersIssued.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRegisterRecordsSubcontractorOrdersIssued.Quantity
	|			ELSE -DocumentRegisterRecordsSubcontractorOrdersIssued.Quantity
	|		END
	|	FROM
	|		AccumulationRegister.SubcontractorOrdersIssued AS DocumentRegisterRecordsSubcontractorOrdersIssued
	|	WHERE
	|		DocumentRegisterRecordsSubcontractorOrdersIssued.Recorder = &Ref) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.SubcontractorOrder,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	MIN(SubcontractorOrderProducts.LineNumber) AS LineNumber,
	|	SubcontractorOrderProducts.Products AS Products,
	|	SubcontractorOrderProducts.Characteristic AS Characteristic,
	|	SubcontractorOrderProducts.Factor AS Factor,
	|	SUM(SubcontractorOrderProducts.Quantity) AS Quantity,
	|	SubcontractorOrderProducts.MeasurementUnit AS MeasurementUnit,
	|	SubcontractorOrderProducts.BasisOrder AS BasisOrder
	|FROM
	|	(SELECT
	|		SubcontractorOrderProducts.LineNumber AS LineNumber,
	|		SubcontractorOrderProducts.Products AS Products,
	|		SubcontractorOrderProducts.Characteristic AS Characteristic,
	|		ISNULL(UOM.Factor, 1) AS Factor,
	|		SubcontractorOrderProducts.Quantity AS Quantity,
	|		SubcontractorOrderProducts.MeasurementUnit AS MeasurementUnit,
	|		SubcontractorOrderProducts.Ref AS BasisOrder
	|	FROM
	|		TT_SubcontractorOrders AS TT_SubcontractorOrders
	|			INNER JOIN Document.SubcontractorOrderIssued.Products AS SubcontractorOrderProducts
	|			ON TT_SubcontractorOrders.Ref = SubcontractorOrderProducts.Ref
	|			LEFT JOIN Catalog.UOM AS UOM
	|			ON (SubcontractorOrderProducts.MeasurementUnit = UOM.Ref)
	|	WHERE
	|		SubcontractorOrderProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		SubcontractorOrderByProducts.LineNumber,
	|		SubcontractorOrderByProducts.Products,
	|		SubcontractorOrderByProducts.Characteristic,
	|		ISNULL(UOM.Factor, 1),
	|		SubcontractorOrderByProducts.Quantity,
	|		SubcontractorOrderByProducts.MeasurementUnit,
	|		SubcontractorOrderByProducts.Ref
	|	FROM
	|		TT_SubcontractorOrders AS TT_SubcontractorOrders
	|			INNER JOIN Document.SubcontractorOrderIssued.ByProducts AS SubcontractorOrderByProducts
	|			ON TT_SubcontractorOrders.Ref = SubcontractorOrderByProducts.Ref
	|			INNER JOIN Catalog.Products AS ProductsCatalog
	|			ON (SubcontractorOrderByProducts.Products = ProductsCatalog.Ref)
	|			LEFT JOIN Catalog.UOM AS UOM
	|			ON (SubcontractorOrderByProducts.MeasurementUnit = UOM.Ref)
	|	WHERE
	|		ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS SubcontractorOrderProducts
	|
	|GROUP BY
	|	SubcontractorOrderProducts.Products,
	|	SubcontractorOrderProducts.Characteristic,
	|	SubcontractorOrderProducts.BasisOrder,
	|	SubcontractorOrderProducts.MeasurementUnit,
	|	SubcontractorOrderProducts.Factor
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("Ref", DocumentData.Ref);
	
	If FilterData.Property("OrdersArray") Then
		FilterString = "SubcontractorOrder.Ref IN(&OrdersArray)";
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
			FilterString = FilterString + "SubcontractorOrder." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
		EndDo;
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&SubcontractorOrderReceivedConditions", FilterString);
	
	ResultsArray = Query.ExecuteBatch();
	
	BalanceTable = ResultsArray[1].Unload();
	BalanceTable.Indexes.Add("SubcontractorOrder,Products,Characteristic");
	
	Products.Clear();
	
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[2].Select();
		While Selection.Next() Do
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("SubcontractorOrder",	Selection.BasisOrder);
			StructureForSearch.Insert("Products",			Selection.Products);
			StructureForSearch.Insert("Characteristic",		Selection.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			NewRow = Products.Add();
			
			FillPropertyValues(NewRow, Selection);
			
			QuantityToWriteOff = Selection.Quantity * Selection.Factor;
			BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
			
			If BalanceRowsArray[0].QuantityBalance < 0 Then
				NewRow.Quantity = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / Selection.Factor;
			EndIf;
			
			If BalanceRowsArray[0].QuantityBalance <= 0 Then
				BalanceTable.Delete(BalanceRowsArray[0]);
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// begin Drive.FullVersion
Procedure FillBySubcontractorOrdersReceived(DocumentData, FilterData, Products) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SubcontractorOrderReceived.Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Receipt) AS MovementType,
	|	SubcontractorOrderReceived.Ref AS Ref
	|INTO TT_SubcontractorOrders
	|FROM
	|	Document.SubcontractorOrderReceived AS SubcontractorOrderReceived
	|WHERE
	|	&SubcontractorOrderReceivedConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	InventoryDemandBalance.SalesOrder AS SubcontractorOrder,
	|	InventoryDemandBalance.Products AS Products,
	|	InventoryDemandBalance.Products.ProductsType AS ProductsType,
	|	InventoryDemandBalance.Characteristic AS Characteristic,
	|	InventoryDemandBalance.QuantityBalance AS QuantityBalance
	|INTO TT_InventoryDemandBalance
	|FROM
	|	AccumulationRegister.InventoryDemand.Balance(
	|			,
	|			(Company, MovementType, SalesOrder) IN
	|				(SELECT
	|					TT_SubcontractorOrders.Company,
	|					TT_SubcontractorOrders.MovementType,
	|					TT_SubcontractorOrders.Ref
	|				FROM
	|					TT_SubcontractorOrders)) AS InventoryDemandBalance
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentRegisterRecordsInventoryDemand.SalesOrder,
	|	DocumentRegisterRecordsInventoryDemand.Products,
	|	DocumentRegisterRecordsInventoryDemand.Products.ProductsType,
	|	DocumentRegisterRecordsInventoryDemand.Characteristic,
	|	DocumentRegisterRecordsInventoryDemand.Quantity
	|FROM
	|	AccumulationRegister.InventoryDemand AS DocumentRegisterRecordsInventoryDemand
	|WHERE
	|	DocumentRegisterRecordsInventoryDemand.Recorder = &Ref
	|
	|INDEX BY
	|	ProductsType,
	|	SubcontractorOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryDemandBalance.SubcontractorOrder AS SubcontractorOrder,
	|	TT_InventoryDemandBalance.Products AS Products,
	|	TT_InventoryDemandBalance.Characteristic AS Characteristic,
	|	SUM(TT_InventoryDemandBalance.QuantityBalance) AS QuantityBalance
	|FROM
	|	TT_InventoryDemandBalance AS TT_InventoryDemandBalance
	|WHERE
	|	TT_InventoryDemandBalance.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	TT_InventoryDemandBalance.SubcontractorOrder,
	|	TT_InventoryDemandBalance.Products,
	|	TT_InventoryDemandBalance.Characteristic
	|
	|HAVING
	|	SUM(TT_InventoryDemandBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SubcontractorOrderReceivedInventory.LineNumber AS LineNumber,
	|	SubcontractorOrderReceivedInventory.Products AS Products,
	|	SubcontractorOrderReceivedInventory.Characteristic AS Characteristic,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	SubcontractorOrderReceivedInventory.Quantity AS Quantity,
	|	SubcontractorOrderReceivedInventory.MeasurementUnit AS MeasurementUnit,
	|	SubcontractorOrderReceivedInventory.Ref AS BasisDocument
	|INTO TT_SubcontractorOrderInventory
	|FROM
	|	TT_InventoryDemandBalance AS TT_InventoryDemandBalance
	|		INNER JOIN Document.SubcontractorOrderReceived.Inventory AS SubcontractorOrderReceivedInventory
	|		ON TT_InventoryDemandBalance.SubcontractorOrder = SubcontractorOrderReceivedInventory.Ref
	|			AND (TT_InventoryDemandBalance.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SubcontractorOrderReceivedInventory.MeasurementUnit = UOM.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TT_SubcontractorOrderInventory.LineNumber) AS LineNumber,
	|	TT_SubcontractorOrderInventory.Products AS Products,
	|	TT_SubcontractorOrderInventory.Characteristic AS Characteristic,
	|	TT_SubcontractorOrderInventory.Factor AS Factor,
	|	SUM(TT_SubcontractorOrderInventory.Quantity) AS Quantity,
	|	TT_SubcontractorOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	TT_SubcontractorOrderInventory.BasisDocument AS BasisDocument,
	|	VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory) AS Ownership
	|FROM
	|	TT_SubcontractorOrderInventory AS TT_SubcontractorOrderInventory
	|
	|GROUP BY
	|	TT_SubcontractorOrderInventory.Products,
	|	TT_SubcontractorOrderInventory.Characteristic,
	|	TT_SubcontractorOrderInventory.BasisDocument,
	|	TT_SubcontractorOrderInventory.MeasurementUnit,
	|	TT_SubcontractorOrderInventory.Factor
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("Ref", DocumentData.Ref);
	
	If FilterData.Property("OrdersArray") Then
		FilterString = "SubcontractorOrderReceived.Ref IN(&OrdersArray)";
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
			FilterString = FilterString + "SubcontractorOrderReceived." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
		EndDo;
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&SubcontractorOrderReceivedConditions", FilterString);
	
	ResultsArray = Query.ExecuteBatch();
	
	BalanceTable = ResultsArray[2].Unload();
	BalanceTable.Indexes.Add("SubcontractorOrder,Products,Characteristic");
	
	Products.Clear();
	
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[4].Select();
		While Selection.Next() Do
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("SubcontractorOrder",	Selection.BasisDocument);
			StructureForSearch.Insert("Products",			Selection.Products);
			StructureForSearch.Insert("Characteristic",		Selection.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			NewRow = Products.Add();
			
			FillPropertyValues(NewRow, Selection);
			
			QuantityToWriteOff = Selection.Quantity * Selection.Factor;
			BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
			
			If BalanceRowsArray[0].QuantityBalance < 0 Then
				NewRow.Quantity = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / Selection.Factor;
			EndIf;
			
			If BalanceRowsArray[0].QuantityBalance <= 0 Then
				BalanceTable.Delete(BalanceRowsArray[0]);
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure
// end Drive.FullVersion 

Procedure InitializeDocumentData(DocumentRefGoodsReceipt, StructureAdditionalProperties) Export
	
	StructureAdditionalProperties.Insert("DefaultLanguageCode", Metadata.DefaultLanguage.LanguageCode);
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	Header.Ref AS Ref,
	|	Header.Date AS Date,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	Header.Counterparty AS Counterparty,
	|	Header.Responsible AS Responsible,
	|	Header.Department AS Department,
	|	CASE
	|		WHEN Header.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.DropShipping)
	|			THEN VALUE(Catalog.BusinessUnits.DropShipping)
	|		ELSE Header.StructuralUnit
	|	END AS StructuralUnit,
	|	Header.Cell AS Cell,
	|	Header.Contract AS Contract,
	|	Header.Order AS Order,
	|	Header.OperationType AS OperationType,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.ExchangeRate AS ExchangeRate,
	|	Header.Multiplicity AS Multiplicity,
	|	Header.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	Header.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	Header.IncludeVATInPrice AS IncludeVATInPrice,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.VATTaxation AS VATTaxation,
	|	Header.Contract.SettlementsCurrency AS SettlementsCurrency 
	|INTO GoodsReceiptHeader
	|FROM
	|	Document.GoodsReceipt AS Header
	|WHERE
	|	Header.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsReceiptProducts.LineNumber AS LineNumber,
	|	GoodsReceiptProducts.Ref AS Document,
	|	GoodsReceiptHeader.Responsible AS Responsible,
	|	GoodsReceiptHeader.Counterparty AS Counterparty,
	|	CASE
	|		WHEN GoodsReceiptHeader.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|			THEN GoodsReceiptHeader.Contract
	|		ELSE GoodsReceiptProducts.Contract
	|	END AS Contract,
	|	GoodsReceiptHeader.Date AS Period,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer)
	|			THEN ISNULL(VATinvoiceForICT.BasisDocument, VALUE(Document.GoodsIssue.EmptyRef))
	|		ELSE UNDEFINED
	|	END AS VATinvoiceBasisDocument,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	GoodsReceiptHeader.StructuralUnit AS StructuralUnit,
	|	GoodsReceiptHeader.Department AS Department,
	|	GoodsReceiptHeader.Cell AS Cell,
	|	GoodsReceiptProducts.VATRate AS VATRate,
	|	GoodsReceiptProducts.SalesReturnItem AS SalesReturnItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromAThirdParty)
	|							OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer)
	|						THEN GoodsReceiptProducts.InventoryReceivedGLAccount
	|					ELSE GoodsReceiptProducts.InventoryGLAccount
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromAThirdParty)
	|			THEN VALUE(Enum.InventoryAccountTypes.ThirdPartyInventory)
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer)
	|				OR &IsOrderReceived
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedComponents)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS InventoryAccountType,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsReceiptProducts.GoodsInTransitGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GoodsInTransitGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsReceiptProducts.GoodsReceivedNotInvoicedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GoodsReceivedNotInvoicedGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsReceiptProducts.GoodsInvoicedNotDeliveredGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GoodsInvoicedNotDeliveredGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsReceiptProducts.COGSGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS COGSGLAccount,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer)
	|			THEN VALUE(Enum.InventoryAccountTypes.GoodsInTransit)
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromSubcontractor)
	|			THEN VALUE(Enum.InventoryAccountTypes.ComponentsForSubcontractor)
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.SalesReturn)
	|				OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
	|			THEN VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|		ELSE VALUE(Enum.InventoryAccountTypes.EmptyRef)
	|	END AS CorrInventoryAccountType,
	|	GoodsReceiptProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN GoodsReceiptProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN GoodsReceiptProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	GoodsReceiptProducts.Ownership AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractor)
	|				OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromSubcontractor)
	|				OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer)
	|			THEN GoodsReceiptHeader.Order
	|		WHEN GoodsReceiptHeader.Order <> UNDEFINED
	|				AND GoodsReceiptHeader.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND GoodsReceiptHeader.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND GoodsReceiptHeader.Order <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	// begin Drive.FullVersion
	|				AND GoodsReceiptHeader.Order <> VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	// end Drive.FullVersion
	|			THEN GoodsReceiptHeader.Order
	|		WHEN GoodsReceiptProducts.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN GoodsReceiptProducts.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	GoodsReceiptProducts.SupplierInvoice AS SupplierInvoice,
	|	CAST(GoodsReceiptProducts.Price * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN GoodsReceiptHeader.ExchangeRate / GoodsReceiptHeader.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN GoodsReceiptHeader.Multiplicity / GoodsReceiptHeader.ExchangeRate
	|			ELSE 1
	|		END AS NUMBER(15, 2)) AS Price,
	|	CASE
	|		WHEN VALUETYPE(GoodsReceiptProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN GoodsReceiptProducts.Quantity
	|		ELSE GoodsReceiptProducts.Quantity * GoodsReceiptProducts.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CAST(CASE
	|			WHEN &ContinentalMethod
	|						AND (GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.PurchaseFromSupplier)
	|							OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.DropShipping))
	|					OR GoodsReceiptProducts.SupplierInvoice <> VALUE(Document.SupplierInvoice.EmptyRef)
	|					OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.SalesReturn)
	|					OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer)
	|				THEN (GoodsReceiptProducts.Total - GoodsReceiptProducts.VATAmount) * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN GoodsReceiptHeader.ExchangeRate / GoodsReceiptHeader.Multiplicity
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN GoodsReceiptHeader.Multiplicity / GoodsReceiptHeader.ExchangeRate
	|					END
	|			ELSE 0
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN &ContinentalMethod
	|						AND (GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.PurchaseFromSupplier)
	|							OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.DropShipping))
	|					OR GoodsReceiptProducts.SupplierInvoice <> VALUE(Document.SupplierInvoice.EmptyRef)
	|					OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.SalesReturn)
	|					OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer)
	|				THEN GoodsReceiptProducts.VATAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN GoodsReceiptHeader.ExchangeRate / GoodsReceiptHeader.Multiplicity
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN GoodsReceiptHeader.Multiplicity / GoodsReceiptHeader.ExchangeRate
	|					END
	|			ELSE 0
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	GoodsReceiptProducts.ConnectionKey AS ConnectionKey,
	|	GoodsReceiptHeader.OperationType AS OperationType,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
	|				OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromSubcontractor)
	|			THEN &Company
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer)
	|			THEN &Company
	|		ELSE UNDEFINED
	|	END AS CorrOrganization,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
	|				OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromSubcontractor)
	|			THEN &PresentationCurrency
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer)
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CorrPresentationCurrency,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
	|				OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromSubcontractor)
	|			THEN GoodsReceiptHeader.Counterparty
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer)
	|			THEN VALUE(Catalog.BusinessUnits.GoodsInTransit)
	|		ELSE UNDEFINED
	|	END AS StructuralUnitCorr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer)
	|						THEN GoodsReceiptProducts.GoodsInTransitGLAccount
	|					WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
	|							OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromSubcontractor)
	|						THEN GoodsReceiptProducts.InventoryTransferredGLAccount
	|					WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.SalesReturn)
	|						THEN GoodsReceiptProducts.COGSGLAccount
	|					ELSE UNDEFINED
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	UNDEFINED AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.SalesReturn)
	|			THEN GoodsReceiptProducts.SalesReturnItem
	|		ELSE UNDEFINED
	|	END AS CorrIncomeAndExpenseItem,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
	|				OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromSubcontractor)
	|			THEN GoodsReceiptProducts.Products
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer)
	|			THEN GoodsReceiptProducts.Products
	|		ELSE UNDEFINED
	|	END AS ProductsCorr,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
	|				OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer)
	|				OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromSubcontractor)
	|			THEN CASE
	|					WHEN &UseCharacteristics
	|						THEN GoodsReceiptProducts.Characteristic
	|					ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|				END
	|		ELSE UNDEFINED
	|	END AS CharacteristicCorr,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
	|				OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer)
	|				OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromSubcontractor)
	|			THEN CASE
	|					WHEN &UseBatches
	|						THEN GoodsReceiptProducts.Batch
	|					ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|				END
	|		ELSE UNDEFINED
	|	END AS BatchCorr,
	|	GoodsReceiptProducts.Ownership AS OwnershipCorr,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
	|			THEN CASE
	|					WHEN GoodsReceiptHeader.Order REFS Document.SalesOrder
	|							AND GoodsReceiptHeader.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|						THEN GoodsReceiptHeader.Order
	|					WHEN GoodsReceiptHeader.Order REFS Document.PurchaseOrder
	|							AND GoodsReceiptHeader.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|						THEN GoodsReceiptHeader.Order
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END AS CorrOrder,
	|	&ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	&ContinentalMethod AS ContinentalMethod,
	|	GoodsReceiptProducts.SalesDocument AS SalesDocument,
	|	GoodsReceiptHeader.DocumentCurrency AS DocumentCurrency,
	|	GoodsReceiptProducts.CostOfGoodsSold AS CostOfGoodsSold,
	|	GoodsReceiptProducts.SalesRep AS SalesRep,
	|	ISNULL(SalesInvoiceDocument.StructuralUnit, VALUE(Catalog.BusinessUnits.EmptyRef)) AS SalesInvoiceStructuralUnit,
	|	ISNULL(ProductsCatalog.BusinessLine, VALUE(Catalog.LinesOfBusiness.MainLine)) AS BusinessLine,
	|	CAST(CASE
	|			WHEN GoodsReceiptHeader.IncludeVATInPrice
	|				THEN 0
	|			ELSE GoodsReceiptProducts.VATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN GoodsReceiptHeader.ContractCurrencyExchangeRate * GoodsReceiptHeader.Multiplicity / (GoodsReceiptHeader.ExchangeRate * GoodsReceiptHeader.ContractCurrencyMultiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN GoodsReceiptHeader.ExchangeRate * GoodsReceiptHeader.ContractCurrencyMultiplicity / (GoodsReceiptHeader.ContractCurrencyExchangeRate * GoodsReceiptHeader.Multiplicity)
	|					ELSE 0
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(GoodsReceiptProducts.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN GoodsReceiptHeader.ContractCurrencyExchangeRate * GoodsReceiptHeader.Multiplicity / (GoodsReceiptHeader.ExchangeRate * GoodsReceiptHeader.ContractCurrencyMultiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN GoodsReceiptHeader.ExchangeRate * GoodsReceiptHeader.ContractCurrencyMultiplicity / (GoodsReceiptHeader.ContractCurrencyExchangeRate * GoodsReceiptHeader.Multiplicity)
	|			ELSE 0
	|		END AS NUMBER(15, 2)) AS AmountCur
	|INTO TemporaryTableProducts
	|FROM
	|	GoodsReceiptHeader AS GoodsReceiptHeader
	|		INNER JOIN Document.GoodsReceipt.Products AS GoodsReceiptProducts
	|			LEFT JOIN Document.SalesInvoice AS SalesInvoiceDocument
	|			ON GoodsReceiptProducts.SalesDocument = SalesInvoiceDocument.Ref
	|			LEFT JOIN Catalog.Products AS ProductsCatalog
	|			ON GoodsReceiptProducts.Products = ProductsCatalog.Ref
	|			LEFT JOIN Document.VATInvoiceForICT AS VATinvoiceForICT
	|			ON GoodsReceiptProducts.BasisDocument = VATinvoiceForICT.Ref
	|		ON GoodsReceiptHeader.Ref = GoodsReceiptProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (ProductsCatalog.ProductsCategory = ProductsCategories.Ref)
	|			AND (ProductsCatalog.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON GoodsReceiptHeader.StructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsReceiptReservation.LineNumber AS LineNumber,
	|	GoodsReceiptHeader.Date AS Period,
	|	&Company AS Company,
	|	GoodsReceiptReservation.SalesOrder AS SalesOrder,
	|	GoodsReceiptReservation.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN GoodsReceiptReservation.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractor)
	|				OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromSubcontractor)
	|				OR GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer)
	|			THEN GoodsReceiptHeader.Order
	|		WHEN GoodsReceiptHeader.Order <> UNDEFINED
	|				AND GoodsReceiptHeader.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND GoodsReceiptHeader.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND GoodsReceiptHeader.Order <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	// begin Drive.FullVersion
	|				AND GoodsReceiptHeader.Order <> VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	// end Drive.FullVersion
	|			THEN GoodsReceiptHeader.Order
	|		WHEN GoodsReceiptReservation.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN GoodsReceiptReservation.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	GoodsReceiptHeader.OperationType AS OperationType,
	|	GoodsReceiptReservation.Quantity AS Quantity
	|INTO TemporaryTableReservation
	|FROM
	|	GoodsReceiptHeader AS GoodsReceiptHeader
	|		INNER JOIN Document.GoodsReceipt.Reservation AS GoodsReceiptReservation
	|		ON GoodsReceiptHeader.Ref = GoodsReceiptReservation.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsReceiptSerialNumbers.ConnectionKey AS ConnectionKey,
	|	GoodsReceiptSerialNumbers.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.GoodsReceipt.SerialNumbers AS GoodsReceiptSerialNumbers
	|WHERE
	|	GoodsReceiptSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers";
	
	Query.SetParameter("Ref",					DocumentRefGoodsReceipt);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseSerialNumbers",		StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("ContinentalMethod",		StructureAdditionalProperties.AccountingPolicy.ContinentalMethod);
	Query.SetParameter("PresentationCurrency",	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	
	If (DocumentRefGoodsReceipt.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractor
		Or DocumentRefGoodsReceipt.OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromSubcontractor)
		And TypeOf(DocumentRefGoodsReceipt.Order) = Type("DocumentRef.SubcontractorOrderIssued")
		And ValueIsFilled(DocumentRefGoodsReceipt.Order.OrderReceived) Then
		Query.SetParameter("IsOrderReceived", 		True);
	Else
		Query.SetParameter("IsOrderReceived", 		False);
	EndIf;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	Query.SetParameter("ContentOfAccountingRecord", NStr("en = 'Inventory earlier invoiced is received'; ru = 'Получены ранее отраженные ТМЦ';pl = 'Zapasy wcześniej zafakturowane są otrzymane';es_ES = 'El inventario anteriormente facturado se ha recibido';es_CO = 'El inventario anteriormente facturado se ha recibido';tr = 'Daha önce faturalandırılmış stok alındı';it = 'Scorte fatturate in precedenza sono state ricevute';de = 'Bestand, der früher in Rechnung gestellt wurde, ist eingegangen'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.ExecuteBatch();
	
	DocumentAttributes = Common.ObjectAttributesValues(DocumentRefGoodsReceipt, "OperationType");
	StructureAdditionalProperties.Insert("DocumentAttributes", DocumentAttributes);
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts",
		DriveServer.EmptyReservedProductsTable());
	
	GenerateTableInventoryDemand(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	GenerateTableInventoryInWarehouses(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	GenerateTablePurchases(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	GenerateTablePurchaseOrders(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	GenerateTableSalesOrders(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	GenerateTableStockReceivedFromThirdParties(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	GenerateTableStockTransferredToThirdParties(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	GenerateTableBackorders(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	
	GenerateTableInventory(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	GenerateTableGoodsInvoicedNotReceived(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	OperationType = StructureAdditionalProperties.DocumentAttributes.OperationType;
	If OperationType = Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier
		Or OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractor Then
		GenerateTableReservedProducts(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	ElsIf OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromAThirdParty
		Or OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromSubcontractor Then
		GenerateTableInventoryReturn(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	EndIf;

	GenerateTableSales(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	
	GenerateTableInventoryComplete(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	
	GenerateTableGoodsReceivedNotInvoiced(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	GenerateTableInventoryCostLayer(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	GenerateTableSubcontractorOrdersIssued(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	// begin Drive.FullVersion
	GenerateTableSubcontractComponents(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	// end Drive.FullVersion
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	EndIf;
	
	GenerateTableAccountingEntriesData(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	
	// Goods in transit
	If WorkWithVATServerCall.MultipleVATNumbersAreUsed() Then
		GenerateTableGoodsInTransit(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	EndIf;
	
	TableForRegisterRecords = StructureAdditionalProperties.TableForRegisterRecords;
	If Not TableForRegisterRecords.Property("TableGoodsInvoicedNotReceived") Then
		TableForRegisterRecords.Insert("TableGoodsInvoicedNotReceived", New ValueTable);
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefGoodsReceipt, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefGoodsReceipt, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

Procedure CheckAbilityOfEnteringByGoodsReceipt(Object, FillingData, Posted, OperationType) Export
	
	If TypeOf(Object) = Type("DocumentObject.SupplierInvoice") 
		And Not (OperationType = Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier
		Or OperationType = Enums.OperationTypesGoodsReceipt.DropShipping) Then
		
		If GetFunctionalOption("UseDropShipping") Then
			ErrorText = NStr("en = 'Cannot generate a Supplier invoice from %1. 
							|Select a Goods receipt whose Operation is ""Purchase from supplier"" or ""Drop shipping"".'; 
							|ru = 'Не удалось создать инвойс поставщика на основании %1. 
							|Выберите поступление товаров с операцией «Покупка» или «Дропшиппинг».';
							|pl = 'Nie można wygenerować Faktury zakupu z %1. 
							|Wybierz Przyjęcie zewnętrzne z operacją ""Zakup od dostawcy"" lub ""Dropshipping"".';
							|es_ES = 'No se puede generar una factura de proveedor desde %1.
							|Seleccione un recibo de Mercancías cuya Operación sea ""Comprar del proveedor"" o ""Envío directo"".';
							|es_CO = 'No se puede generar una factura de proveedor desde %1.
							|Seleccione un recibo de Mercancías cuya Operación sea ""Comprar del proveedor"" o ""Envío directo"".';
							|tr = '%1 bazlı Satın alma faturası oluşturulamıyor. 
							|İşlemi ""Tedarikçiden satın alma"" veya ""Stoksuz satış"" olan bir Ambar girişi seçin.';
							|it = 'Impossibile generare una Fattura del fornitore da %1. 
							|Selezionare una Ricezione merce la cui operazione è ""Acquisto da fornitore"" o ""Dropshipping"".';
							|de = 'Fehler beim Generieren einer Lieferantenrechnung aus %1. 
							| Wählen Sie einen Wareneingang mit der Operation ""Kauf beim Lieferanten"" oder ""Streckengeschäft"" aus.'");
		Else
			ErrorText = NStr("en = 'Cannot generate a Supplier invoice from %1. 
							|Select a Goods receipt whose Operation is ""Purchase from supplier"".'; 
							|ru = 'Не удалось создать инвойс поставщика на основании %1. 
							|Выберите поступление товаров с операцией «Покупка».';
							|pl = 'Nie można wygenerować faktury zakupu z %1. 
							|Wybierz Przyjęcie zewnętrzne z operacją ""Zakup od dostawcy"".';
							|es_ES = 'No se puede generar una factura de proveedor desde %1.
							|Seleccione un recibo de Mercancías cuya Operación sea ""Comprar del proveedor"".';
							|es_CO = 'No se puede generar una factura de proveedor desde %1.
							|Seleccione un recibo de Mercancías cuya Operación sea ""Comprar del proveedor"".';
							|tr = '%1 bazlı Satın alma faturası oluşturulamıyor. 
							|İşlemi ""Tedarikçiden satın alma"" olan bir Ambar girişi seçin.';
							|it = 'Impossibile generare una Fattura del fornitore da %1. 
							|Selezionare una Ricezione merce la cui operazione è ""Acquisto da fornitore"".';
							|de = 'Fehler beim Generieren einer Lieferantenrechnung aus %1. 
							| Wählen Sie einen Wareneingang mit der Operation ""Kauf beim Lieferanten"" aus.'");
		EndIf;
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
				ErrorText,
				FillingData);
		
	ElsIf TypeOf(Object) = Type("DocumentObject.CreditNote") AND OperationType <> Enums.OperationTypesGoodsReceipt.SalesReturn Then
		
		ErrorText = NStr("en = 'Cannot generate a Credit note from %1. 
						|Select a Goods receipt whose Operation is ""Sales return"".'; 
						|ru = 'Не удалось создать кредитовое авизо на основании %1. 
						|Выберите поступление товаров с операцией «Возврат от покупателя».';
						|pl = 'Nie można wygenerować Noty kredytowej z %1. 
						|Wybierz Przyjęcie zewnętrzne z operacją ""Zwrot sprzedaży"".';
						|es_ES = 'No se puede generar una nota de crédito de %1. 
						|Seleccione un recibo de mercancías cuya operación sea ""Devolución de ventas"".';
						|es_CO = 'No se puede generar una nota de crédito de %1. 
						|Seleccione un recibo de mercancías cuya operación sea ""Devolución de ventas"".';
						|tr = '%1 bazlı Alacak dekontu oluşturulamıyor. 
						|İşlemi ""Satış iadesi"" olan bir Ambar girişi seçin.';
						|it = 'Impossibile generare una Nota di credito da %1. 
						|Selezionare una Ricezione merce la cui operazione è ""Restituzione vendite"".';
						|de = 'Fehler beim Generieren einer Gutschrift aus %1. 
						| Wählen Sie einen Wareneingang mit der Operation ""Rückgabe"" aus.'");
		Raise StringFunctionsClientServer.SubstituteParametersToString(
				ErrorText,
				FillingData);
		
	EndIf;
	
	If Posted <> Undefined AND Not Posted Then
		ErrorText = NStr("en = '%1 is not posted. Cannot use it as a base document. Please, post it first.'; ru = 'Документ %1 не проведен. Ввод на основании непроведенного документа запрещен.';pl = '%1 dokument nie został zatwierdzony. Nie można użyć go jako dokumentu źródłowego. Najpierw zatwierdź go.';es_ES = '%1 no se ha enviado. No se puede utilizarlo como un documento de base. Por favor, enviarlo primero.';es_CO = '%1 no se ha enviado. No se puede utilizarlo como un documento de base. Por favor, enviarlo primero.';tr = '%1 kaydedilmediğinden temel belge olarak kullanılamıyor. Lütfen, önce kaydedin.';it = '%1 non pubblicato. Non è possibile utilizzarlo come documento di base. Si prega di pubblicarlo prima di tutto.';de = '%1 wird nicht gebucht. Kann nicht als Basisdokument verwendet werden. Zuerst bitte buchen.'");
		Raise StringFunctionsClientServer.SubstituteParametersToString(
				ErrorText,
				FillingData);
	EndIf;
	
EndProcedure

Procedure RunControl(DocumentRefGoodsReceipt, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If StructureTemporaryTables.RegisterRecordsInventoryChange
		Or StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		Or StructureTemporaryTables.RegisterRecordsBackordersChange
		Or StructureTemporaryTables.RegisterRecordsPurchaseOrdersChange
		Or StructureTemporaryTables.RegisterRecordsGoodsInvoicedNotReceivedChange
		Or StructureTemporaryTables.RegisterRecordsGoodsReceivedNotInvoicedChange
		Or StructureTemporaryTables.RegisterRecordsSubcontractorOrdersIssuedChange
		Or StructureTemporaryTables.RegisterRecordsReservedProductsChange
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
		|			AND (ISNULL(InventoryBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsPurchaseOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsPurchaseOrdersChange.Company AS CompanyPresentation,
		|	RegisterRecordsPurchaseOrdersChange.PurchaseOrder AS PurchaseOrderPresentation,
		|	RegisterRecordsPurchaseOrdersChange.Products AS ProductsPresentation,
		|	RegisterRecordsPurchaseOrdersChange.Characteristic AS CharacteristicPresentation,
		|	PurchaseOrdersBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsPurchaseOrdersChange.QuantityChange, 0) + ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) AS BalancePurchaseOrders,
		|	ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) AS QuantityBalancePurchaseOrders
		|FROM
		|	RegisterRecordsPurchaseOrdersChange AS RegisterRecordsPurchaseOrdersChange
		|		INNER JOIN AccumulationRegister.PurchaseOrders.Balance(&ControlTime, ) AS PurchaseOrdersBalances
		|		ON RegisterRecordsPurchaseOrdersChange.Company = PurchaseOrdersBalances.Company
		|			AND RegisterRecordsPurchaseOrdersChange.PurchaseOrder = PurchaseOrdersBalances.PurchaseOrder
		|			AND RegisterRecordsPurchaseOrdersChange.Products = PurchaseOrdersBalances.Products
		|			AND RegisterRecordsPurchaseOrdersChange.Characteristic = PurchaseOrdersBalances.Characteristic
		|			AND (ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsBackordersChange.LineNumber AS LineNumber,
		|	RegisterRecordsBackordersChange.Company AS CompanyPresentation,
		|	RegisterRecordsBackordersChange.SalesOrder AS SalesOrderPresentation,
		|	RegisterRecordsBackordersChange.Products AS ProductsPresentation,
		|	RegisterRecordsBackordersChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsBackordersChange.SupplySource AS SupplySourcePresentation,
		|	BackordersBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsBackordersChange.QuantityChange, 0) + ISNULL(BackordersBalances.QuantityBalance, 0) AS BalanceBackorders,
		|	ISNULL(BackordersBalances.QuantityBalance, 0) AS QuantityBalanceBackorders
		|FROM
		|	RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange
		|		INNER JOIN AccumulationRegister.Backorders.Balance(&ControlTime, ) AS BackordersBalances
		|		ON RegisterRecordsBackordersChange.Company = BackordersBalances.Company
		|			AND RegisterRecordsBackordersChange.SalesOrder = BackordersBalances.SalesOrder
		|			AND RegisterRecordsBackordersChange.Products = BackordersBalances.Products
		|			AND RegisterRecordsBackordersChange.Characteristic = BackordersBalances.Characteristic
		|			AND RegisterRecordsBackordersChange.SupplySource = BackordersBalances.SupplySource
		|			AND (ISNULL(BackordersBalances.QuantityBalance, 0) < 0)
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
		Query.Text = Query.Text + AccumulationRegisters.GoodsReceivedNotInvoiced.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.GoodsInvoicedNotReceived.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.ReservedProducts.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.SubcontractorOrdersIssued.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.Inventory.ReturnQuantityControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		Query.SetParameter("Ref", DocumentRefGoodsReceipt);
		
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
			Or Not ResultsArray[14].IsEmpty()
			Then
			DocumentObjectGoodsReceipt = DocumentRefGoodsReceipt.GetObject();
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectGoodsReceipt, QueryResultSelection, Cancel);
		// Negative balance of inventory.
		ElsIf Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectGoodsReceipt, QueryResultSelection, Cancel);
		// Negative balance of need for reserved products.
		ElsIf Not ResultsArray[7].IsEmpty() Then
			QueryResultSelection = ResultsArray[7].Select();
			DriveServer.ShowMessageAboutPostingToReservedProductsRegisterErrors(DocumentObjectGoodsReceipt, QueryResultSelection, Cancel);
		Else
			DriveServer.CheckAvailableStockBalance(DocumentObjectGoodsReceipt, AdditionalProperties, Cancel);
		EndIf;
		
		// Negative balance on purchase order.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToPurchaseOrdersRegisterErrors(DocumentObjectGoodsReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToBackordersRegisterErrors(DocumentObjectGoodsReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectGoodsReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on goods received not yet invoiced
		If Not ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			DriveServer.ShowMessageAboutPostingToGoodsReceivedNotInvoicedRegisterErrors(DocumentObjectGoodsReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[6].IsEmpty() Then
			QueryResultSelection = ResultsArray[6].Select();
			DriveServer.ShowMessageAboutPostingToGoodsInvoicedNotReceivedRegisterErrors(DocumentObjectGoodsReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[8].IsEmpty() Then
			QueryResultSelection = ResultsArray[8].Select();
			DriveServer.ShowMessageAboutPostingToSubcontractorOrdersIssuedRegisterErrors(DocumentObjectGoodsReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of return quantity in inventory
		If Not ResultsArray[14].IsEmpty() And ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[14].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterRefundsErrors(DocumentObjectGoodsReceipt, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

Function ThereIsAdvanceInvoice(InvoicesArray) Export
	
	If Not ValueIsFilled(InvoicesArray) Then
		Return False;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SupplierInvoice.Ref AS Ref
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Posted
	|	AND SupplierInvoice.Ref IN(&InvoicesArray)
	|	AND SupplierInvoice.OperationKind = VALUE(Enum.OperationTypesSupplierInvoice.AdvanceInvoice)";
	
	Query.SetParameter("InvoicesArray", InvoicesArray);
	QueryResult = Query.Execute();
	
	Return Not QueryResult.IsEmpty();
	
EndFunction

Function GetStructureDataForDropShipping(DocumentRefGoodsReceipt) Export
	
	StructureData = New Structure("Counterparty, Contract, RefSalesOrder");
	
	RefOrder = Common.ObjectAttributeValue(DocumentRefGoodsReceipt, "Order");
	
	If ValueIsFilled(RefOrder)
		And TypeOf(RefOrder) = Type("DocumentRef.PurchaseOrder") Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	DocSalesOrder.Counterparty AS Counterparty,
		|	DocSalesOrder.Contract AS Contract,
		|	DocSalesOrder.Ref AS RefSalesOrder
		|FROM
		|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
		|		INNER JOIN Document.SalesOrder AS DocSalesOrder
		|		ON PurchaseOrderInventory.SalesOrder = DocSalesOrder.Ref
		|WHERE
		|	PurchaseOrderInventory.Ref = &RefOrder";
		
		Query.SetParameter("RefOrder", RefOrder);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		While SelectionDetailRecords.Next() Do
			FillPropertyValues(StructureData, SelectionDetailRecords);
		EndDo;
		
	EndIf;
	
	Return StructureData;
	
EndFunction

#EndRegion

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure("SalesReturnItem", StructureData.SalesReturnItem);
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "Products" Then
		Result.Insert("COGSGLAccount", "SalesReturnItem");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	If ObjectParameters.OperationType = Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier
		Or ObjectParameters.OperationType = Enums.OperationTypesGoodsReceipt.DropShipping Then
		
		GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
		
		If ValueIsFilled(StructureData.SupplierInvoice) Then
			GLAccountsForFilling.Insert("GoodsInvoicedNotDeliveredGLAccount",	StructureData.GoodsInvoicedNotDeliveredGLAccount);
		Else
			GLAccountsForFilling.Insert("GoodsReceivedNotInvoicedGLAccount",	StructureData.GoodsReceivedNotInvoicedGLAccount);
		EndIf;
		
	ElsIf ObjectParameters.OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromAThirdParty Then
		GLAccountsForFilling.Insert("InventoryGLAccount",				StructureData.InventoryGLAccount);
		GLAccountsForFilling.Insert("InventoryTransferredGLAccount",	StructureData.InventoryTransferredGLAccount);
	ElsIf ObjectParameters.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty Then
		GLAccountsForFilling.Insert("InventoryReceivedGLAccount", StructureData.InventoryReceivedGLAccount);
	ElsIf ObjectParameters.OperationType = Enums.OperationTypesGoodsReceipt.SalesReturn Then
		GLAccountsForFilling.Insert("InventoryGLAccount",	StructureData.InventoryGLAccount);
		GLAccountsForFilling.Insert("COGSGLAccount",		StructureData.COGSGLAccount);
	ElsIf ObjectParameters.OperationType = Enums.OperationTypesGoodsReceipt.IntraCommunityTransfer Then
		GLAccountsForFilling.Insert("GoodsInTransitGLAccount", StructureData.GoodsInTransitGLAccount);
		GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
	ElsIf ObjectParameters.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractor
		Or ObjectParameters.OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromSubcontractor Then
		GLAccountsForFilling.Insert("InventoryGLAccount",				StructureData.InventoryGLAccount);
		GLAccountsForFilling.Insert("InventoryTransferredGLAccount",	StructureData.InventoryTransferredGLAccount);
	// begin Drive.FullVersion
	ElsIf ObjectParameters.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer Then
		GLAccountsForFilling.Insert("InventoryReceivedGLAccount",	StructureData.InventoryReceivedGLAccount);
	// end Drive.FullVersion
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region InventoryOwnership

Function InventoryOwnershipParameters(DocObject) Export
	
	Parameters = New Structure;
	
	Parameters.Insert("TableName", "Products");
	If DocObject.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty Then
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.CounterpartysInventory);
		Parameters.Insert("Counterparty", DocObject.Counterparty);
		Parameters.Insert("Contract", DocObject.Contract);
		// begin Drive.FullVersion
	ElsIf DocObject.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer Then
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.CustomerProvidedInventory);
		Parameters.Insert("Counterparty", DocObject.Counterparty);
		Parameters.Insert("Contract", DocObject.Contract);
		// end Drive.FullVersion
		
	ElsIf (DocObject.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractor
		Or DocObject.OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromSubcontractor)
		And TypeOf(DocObject.Order) = Type("DocumentRef.SubcontractorOrderIssued")
		And ValueIsFilled(DocObject.Order.OrderReceived) Then 
		
		OrderReceived = DocObject.Order.OrderReceived;
		
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.CustomerProvidedInventory);
		Parameters.Insert("Counterparty", OrderReceived.Counterparty);
		Parameters.Insert("Contract", OrderReceived.Contract);
		
	Else
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);
	EndIf;
	
	Return Parameters;
	
EndFunction

#EndRegion

#Region Batches

Function BatchCheckFillingParameters(DocObject) Export
	
	Parameters = New Structure;
	
	Parameters.Insert("TableName", "Products");
	
	Warehouses = New Array;
	
	If DocObject.OperationType = Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier
		Or DocObject.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty
		Or DocObject.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractor Then
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.StructuralUnit);
		WarehouseData.Insert("TrackingArea", "Inbound_FromSupplier");
		
		Warehouses.Add(WarehouseData);
		
	ElsIf DocObject.OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromAThirdParty
		Or DocObject.OperationType = Enums.OperationTypesGoodsReceipt.SalesReturn Then
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.StructuralUnit);
		WarehouseData.Insert("TrackingArea", "Inbound_SalesReturn");
		
		Warehouses.Add(WarehouseData);
		
	ElsIf DocObject.OperationType = Enums.OperationTypesGoodsReceipt.IntraCommunityTransfer
		Or DocObject.OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromSubcontractor Then
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.StructuralUnit);
		WarehouseData.Insert("TrackingArea", "Inbound_Transfer");
		
		Warehouses.Add(WarehouseData);
		
	EndIf;
	
	Parameters.Insert("Warehouses", Warehouses);
	
	Return Parameters;
	
EndFunction

#EndRegion

#Region TableGeneration

Procedure GenerateTablePurchases(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TablePurchases.Period AS Period,
	|	TablePurchases.Company AS Company,
	|	TablePurchases.PresentationCurrency AS PresentationCurrency,
	|	TablePurchases.Counterparty AS Counterparty,
	|	TablePurchases.DocumentCurrency AS Currency,
	|	TablePurchases.Products AS Products,
	|	TablePurchases.Characteristic AS Characteristic,
	|	TablePurchases.Batch AS Batch,
	|	TablePurchases.Ownership AS Ownership,
	|	TablePurchases.Order AS PurchaseOrder,
	|	TablePurchases.SupplierInvoice AS Document,
	|	TablePurchases.VATRate AS VATRate,
	|	SUM(TablePurchases.Quantity) AS Quantity,
	|	SUM(TablePurchases.VATAmount) AS VATAmount,
	|	SUM(TablePurchases.Amount) AS Amount,
	|	SUM(TablePurchases.VATAmountCur) AS VATAmountCur,
	|	SUM(TablePurchases.AmountCur) AS AmountCur,
	|	FALSE AS ZeroInvoice
	|FROM
	|	TemporaryTableProducts AS TablePurchases
	|WHERE
	|	&ThereIsAdvanceInvoiceByOrders
	|	AND TablePurchases.SupplierInvoice <> VALUE(Document.SupplierInvoice.EmptyRef)
	|
	|GROUP BY
	|	TablePurchases.Period,
	|	TablePurchases.Company,
	|	TablePurchases.PresentationCurrency,
	|	TablePurchases.Counterparty,
	|	TablePurchases.DocumentCurrency,
	|	TablePurchases.Products,
	|	TablePurchases.Characteristic,
	|	TablePurchases.Batch,
	|	TablePurchases.Ownership,
	|	TablePurchases.Order,
	|	TablePurchases.SupplierInvoice,
	|	TablePurchases.VATRate";
	
	OrdersArray = DocumentRef.Products.UnloadColumn("Order");
	ThereIsAdvanceInvoiceByOrders = Documents.SupplierInvoice.ThereIsAdvanceInvoiceByOrders(OrdersArray);
	Query.SetParameter("ThereIsAdvanceInvoiceByOrders", ThereIsAdvanceInvoiceByOrders);
	
	QueryResult = Query.Execute();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchases", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTablePurchaseOrders(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TablePurchaseOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TablePurchaseOrders.Period AS Period,
	|	TablePurchaseOrders.Company AS Company,
	|	TablePurchaseOrders.Products AS Products,
	|	TablePurchaseOrders.Characteristic AS Characteristic,
	|	TablePurchaseOrders.Order AS PurchaseOrder,
	|	SUM(TablePurchaseOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProducts AS TablePurchaseOrders
	|WHERE
	|	TablePurchaseOrders.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|	AND TablePurchaseOrders.Order REFS Document.PurchaseOrder
	|	AND TablePurchaseOrders.SupplierInvoice = VALUE(Document.SupplierInvoice.EmptyRef)
	|
	|GROUP BY
	|	TablePurchaseOrders.Period,
	|	TablePurchaseOrders.Company,
	|	TablePurchaseOrders.Products,
	|	TablePurchaseOrders.Characteristic,
	|	TablePurchaseOrders.Order";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchaseOrders", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableInventory(DocumentRef, StructureAdditionalProperties)
	
	TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	If TempTablesManager.Tables.Find("TempBackorders") = Undefined Then
		GenerateTableBackorders(DocumentRef, StructureAdditionalProperties);
	EndIf;
	
	WeightedAverage = (StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage);
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProducts.LineNumber AS LineNumber,
	|	TableProducts.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProducts.Company AS Company,
	|	TableProducts.PresentationCurrency AS PresentationCurrency,
	|	TableProducts.Department AS Department,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.SalesReturn) AS Return,
	|	TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractor) AS ReceiptFromSubcontractor,
	|	TableProducts.Document AS Document,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.SalesReturn)
	|			THEN TableProducts.SalesDocument
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer)
	|			THEN TableProducts.Document
	|		ELSE UNDEFINED
	|	END AS SourceDocument,
	|	TableProducts.VATinvoiceBasisDocument AS VATinvoiceBasisDocument,
	|	TableProducts.Order AS CorrSalesOrder,
	|	ISNULL(TableProducts.StructuralUnit, VALUE(Catalog.Counterparties.EmptyRef)) AS StructuralUnit,
	|	TableProducts.GLAccount AS GLAccount,
	|	TableProducts.InventoryAccountType AS InventoryAccountType,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.Ownership AS Ownership,
	|	TableProducts.CostObject AS CostObject,
	|	TableProducts.Price AS Price,
	|	TableProducts.Quantity AS Quantity,
	|	TableProducts.Order AS SupplySource,
	|	TRUE AS FixedCost,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.SalesReturn)
	|			THEN TableProducts.CostOfGoodsSold
	|		ELSE TableProducts.Amount
	|	END AS Amount,
	|	TableProducts.VATRate AS VATRate,
	|	TableProducts.ProductsCorr AS ProductsCorr,
	|	TableProducts.CharacteristicCorr AS CharacteristicCorr,
	|	TableProducts.BatchCorr AS BatchCorr,
	|	TableProducts.OwnershipCorr AS OwnershipCorr,
	|	CASE
	|		WHEN TableProducts.CorrOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableProducts.CorrOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableProducts.CorrOrder
	|	END AS CorrOrder,
	|	TableProducts.CorrOrganization AS CorrOrganization,
	|	TableProducts.CorrPresentationCurrency AS CorrPresentationCurrency,
	|	TableProducts.StructuralUnitCorr AS StructuralUnitCorr,
	|	TableProducts.CorrGLAccount AS CorrGLAccount,
	|	TableProducts.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer)
	|			THEN VALUE(Catalog.Counterparties.EmptyRef)
	|		ELSE TableProducts.Counterparty
	|	END AS Counterparty,
	|	TableProducts.Contract AS Contract,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer)
	|			THEN TableProducts.PresentationCurrency
	|		ELSE TableProducts.DocumentCurrency
	|	END AS Currency,
	|	TableProducts.SupplierInvoice AS SupplierInvoice,
	|	TRUE AS NotInvoiced,
	|	TableProducts.GLAccount AS AccountDr,
	|	TableProducts.CorrGLAccount AS AccountCr,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer)
	|			THEN &UndefinedItem
	|		ELSE TableProducts.IncomeAndExpenseItem
	|	END AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer)
	|			THEN &UndefinedItem
	|		ELSE TableProducts.CorrIncomeAndExpenseItem
	|	END AS CorrIncomeAndExpenseItem,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.SalesReturn)
	|			THEN &GoodsReturn
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer)
	|			THEN &GoodsInTransit
	|	END AS Content,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.SalesReturn)
	|			THEN &GoodsReturn
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer)
	|			THEN &GoodsInTransit
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromSubcontractor)
	|			THEN &ReturnFromSubcontractor
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractor)
	|			THEN &ReceiptFromSubcontractor
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer)
	|			THEN &ReceiptFromSubcontractingCustomer
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer)
	|			THEN &DropShipping
	|	END AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|INTO TemporaryTableProductsNotGrouped
	|FROM
	|	TemporaryTableProducts AS TableProducts
	|WHERE
	|	TableProducts.SupplierInvoice = VALUE(Document.SupplierInvoice.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	TableProducts.LineNumber,
	|	TableProducts.Period,
	|	VALUE(AccumulationRecordType.Expense),
	|	TableProducts.Company,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.Department,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	FALSE,
	|	FALSE,
	|	TableProducts.Document,
	|	TableProducts.VATinvoiceBasisDocument,
	|	TableProducts.VATinvoiceBasisDocument,
	|	UNDEFINED,
	|	VALUE(Catalog.BusinessUnits.GoodsInTransit),
	|	TableProducts.CorrGLAccount,
	|	TableProducts.CorrInventoryAccountType,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.Ownership,
	|	TableProducts.CostObject,
	|	TableProducts.Price,
	|	TableProducts.Quantity,
	|	TableProducts.Order,
	|	FALSE,
	|	TableProducts.Amount,
	|	TableProducts.VATRate,
	|	TableProducts.ProductsCorr,
	|	TableProducts.CharacteristicCorr,
	|	TableProducts.BatchCorr,
	|	TableProducts.OwnershipCorr,
	|	UNDEFINED,
	|	TableProducts.CorrOrganization,
	|	TableProducts.CorrPresentationCurrency,
	|	TableProducts.StructuralUnit,
	|	TableProducts.GLAccount,
	|	TableProducts.InventoryAccountType,
	|	VALUE(Catalog.Counterparties.EmptyRef),
	|	TableProducts.Contract,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.SupplierInvoice,
	|	TRUE,
	|	TableProducts.CorrGLAccount,
	|	TableProducts.GLAccount,
	|	&UndefinedItem,
	|	&UndefinedItem,
	|	CAST(&GoodsInTransit AS STRING(100)),
	|	CAST(&GoodsInTransit AS STRING(100)),
	|	FALSE
	|FROM
	|	TemporaryTableProducts AS TableProducts
	|WHERE
	|	TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer)
	|	AND NOT &WeightedAverage
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.Department,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	OfflineRecords.Return,
	|	&IsReceiptFromSubcontractor,
	|	UNDEFINED,
	|	OfflineRecords.SourceDocument,
	|	UNDEFINED,
	|	OfflineRecords.CorrSalesOrder,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.InventoryAccountType,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.Ownership,
	|	OfflineRecords.CostObject,
	|	0,
	|	OfflineRecords.Quantity,
	|	UNDEFINED,
	|	OfflineRecords.FixedCost,
	|	OfflineRecords.Amount,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.ProductsCorr,
	|	OfflineRecords.CharacteristicCorr,
	|	OfflineRecords.BatchCorr,
	|	OfflineRecords.OwnershipCorr,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.StructuralUnitCorr,
	|	OfflineRecords.CorrGLAccount,
	|	OfflineRecords.CorrInventoryAccountType,
	|	OfflineRecords.Counterparty,
	|	UNDEFINED,
	|	OfflineRecords.Currency,
	|	UNDEFINED,
	|	TRUE,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.CorrIncomeAndExpenseItem,
	|	UNDEFINED,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableProducts.LineNumber) AS LineNumber,
	|	TableProducts.Period AS Period,
	|	TableProducts.RecordType AS RecordType,
	|	TableProducts.Company AS Company,
	|	TableProducts.PresentationCurrency AS PresentationCurrency,
	|	TableProducts.Department AS Department,
	|	TableProducts.PlanningPeriod AS PlanningPeriod,
	|	TableProducts.Return AS Return,
	|	TableProducts.ReceiptFromSubcontractor AS ReceiptFromSubcontractor,
	|	TableProducts.Document AS Document,
	|	TableProducts.SourceDocument AS SourceDocument,
	|	TableProducts.VATinvoiceBasisDocument AS VATinvoiceBasisDocument,
	|	TableProducts.CorrSalesOrder AS CorrSalesOrder,
	|	TableProducts.StructuralUnit AS StructuralUnit,
	|	TableProducts.GLAccount AS GLAccount,
	|	TableProducts.InventoryAccountType AS InventoryAccountType,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.Ownership AS Ownership,
	|	TableProducts.CostObject AS CostObject,
	|	TableProducts.Price AS Price,
	|	SUM(TableProducts.Quantity) AS Quantity,
	|	TableProducts.SupplySource AS SupplySource,
	|	TableProducts.FixedCost AS FixedCost,
	|	SUM(TableProducts.Amount) AS Amount,
	|	TableProducts.VATRate AS VATRate,
	|	TableProducts.ProductsCorr AS ProductsCorr,
	|	TableProducts.CharacteristicCorr AS CharacteristicCorr,
	|	TableProducts.BatchCorr AS BatchCorr,
	|	TableProducts.OwnershipCorr AS OwnershipCorr,
	|	TableProducts.CorrOrder AS CorrOrder,
	|	TableProducts.CorrOrganization AS CorrOrganization,
	|	TableProducts.CorrPresentationCurrency AS CorrPresentationCurrency,
	|	TableProducts.StructuralUnitCorr AS StructuralUnitCorr,
	|	TableProducts.CorrGLAccount AS CorrGLAccount,
	|	TableProducts.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableProducts.Counterparty AS Counterparty,
	|	TableProducts.Contract AS Contract,
	|	TableProducts.Currency AS Currency,
	|	TableProducts.SupplierInvoice AS SupplierInvoice,
	|	TableProducts.NotInvoiced AS NotInvoiced,
	|	TableProducts.AccountDr AS AccountDr,
	|	TableProducts.AccountCr AS AccountCr,
	|	TableProducts.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	TableProducts.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	TableProducts.Content AS Content,
	|	TableProducts.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	TableProducts.OfflineRecord AS OfflineRecord
	|FROM
	|	TemporaryTableProductsNotGrouped AS TableProducts
	|
	|GROUP BY
	|	TableProducts.Department,
	|	TableProducts.Period,
	|	TableProducts.Company,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.Return,
	|	TableProducts.SourceDocument,
	|	TableProducts.VATinvoiceBasisDocument,
	|	TableProducts.CorrSalesOrder,
	|	TableProducts.Document,
	|	TableProducts.StructuralUnit,
	|	TableProducts.RecordType,
	|	TableProducts.PlanningPeriod,
	|	TableProducts.CorrOrganization,
	|	TableProducts.CorrPresentationCurrency,
	|	TableProducts.Contract,
	|	TableProducts.Batch,
	|	TableProducts.Ownership,
	|	TableProducts.CostObject,
	|	TableProducts.Price,
	|	TableProducts.FixedCost,
	|	TableProducts.BatchCorr,
	|	TableProducts.OwnershipCorr,
	|	TableProducts.StructuralUnitCorr,
	|	TableProducts.SupplierInvoice,
	|	TableProducts.SupplySource,
	|	TableProducts.NotInvoiced,
	|	TableProducts.AccountDr,
	|	TableProducts.AccountCr,
	|	TableProducts.VATRate,
	|	TableProducts.Products,
	|	TableProducts.CorrGLAccount,
	|	TableProducts.GLAccount,
	|	TableProducts.CorrInventoryAccountType,
	|	TableProducts.InventoryAccountType,
	|	TableProducts.CharacteristicCorr,
	|	TableProducts.CorrOrder,
	|	TableProducts.Counterparty,
	|	TableProducts.Currency,
	|	TableProducts.Content,
	|	TableProducts.ContentOfAccountingRecord,
	|	TableProducts.ProductsCorr,
	|	TableProducts.Characteristic,
	|	TableProducts.IncomeAndExpenseItem,
	|	TableProducts.CorrIncomeAndExpenseItem,
	|	TableProducts.OfflineRecord,
	|	TableProducts.ReceiptFromSubcontractor";
	
	Query.SetParameter(
		"GoodsReturn",
		NStr("en = 'Goods return'; ru = 'Возврат товара';pl = 'Zwrot towarów';es_ES = 'Devolución de productos';es_CO = 'Devolución de productos';tr = 'Mal iadesi';it = 'Restituzione merci';de = 'Warenrücksendung'",
		StructureAdditionalProperties.DefaultLanguageCode));
			
	Query.SetParameter(
		"GoodsInTransit",
		NStr("en = 'Goods in transit'; ru = 'Товары в пути';pl = 'Towary w tranzycie';es_ES = 'Mercancías en tránsito';es_CO = 'Mercancías en tránsito';tr = 'Transit mallar';it = 'Merci in transito';de = 'Waren in Transit'",
		StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ReceiptFromSubcontractor",
		NStr("en = 'Receipt from a subcontractor'; ru = 'Поступление от переработчика';pl = 'Przyjęcie od podwykonawcy';es_ES = 'Recepción del subcontratista';es_CO = 'Recepción del subcontratista';tr = 'Alt yüklenici fişi';it = 'Ricevuto da un subfornitore';de = 'Eingang von einem Subunternehmer'",
		StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ReturnFromSubcontractor",
		NStr("en = 'Return from a subcontractor'; ru = 'Возврат от переработчика';pl = 'Zwrot od podwykonawcy';es_ES = 'Devolución del subcontratista';es_CO = 'Devolución del subcontratista';tr = 'Alt yüklenici iadesi';it = 'Restituito da un subfornitore';de = 'Rückgabe von einem Subunternehmer'",
		StructureAdditionalProperties.DefaultLanguageCode));
		
	Query.SetParameter("ReceiptFromSubcontractingCustomer",
		NStr("en = 'Receipt from a subcontracting customer'; ru = 'Поступление от давальца';pl = 'Przyjęcie od nabywcy usług podwykonawstwa';es_ES = 'Recibo de un cliente subcontratado';es_CO = 'Recibo de un cliente subcontratado';tr = 'Alt yüklenici müşteriden giriş';it = 'Ricevuta da parte di un cliente in subfornitura';de = 'Rechnung von einem Kunde mit Subunternehmerbestellung'",
		StructureAdditionalProperties.DefaultLanguageCode));
		
	Query.SetParameter("DropShipping",
		NStr("en = 'Drop shipping'; ru = 'Дропшиппинг';pl = 'Dropshipping';es_ES = 'Envío directo';es_CO = 'Envío directo';tr = 'Stoksuz satış';it = 'Dropshipping';de = 'Streckengeschäft'",
		StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("UndefinedItem", Catalogs.IncomeAndExpenseItems.Undefined);
	Query.SetParameter("IsReceiptFromSubcontractor", DocumentRef.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractor);
	Query.SetParameter("WeightedAverage", WeightedAverage);
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Columns.Add("SalesOrder",
		New TypeDescription("DocumentRef.SalesOrder, DocumentRef.WorkOrder"));
	
	If WeightedAverage And DocumentRef.OperationType = Enums.OperationTypesGoodsReceipt.IntraCommunityTransfer Then
		GenerateTableInventoryICT(DocumentRef, StructureAdditionalProperties);
	EndIf;
	
EndProcedure

Procedure GenerateTableInventoryICT(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text =
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.BusinessUnits.GoodsInTransit) AS StructuralUnit,
	|	TableInventory.CorrInventoryAccountType AS InventoryAccountType,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.CostObject AS CostObject
	|FROM
	|	TemporaryTableProducts AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.CorrInventoryAccountType,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.CostObject";
	
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
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.PresentationCurrency AS PresentationCurrency,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.InventoryAccountType AS InventoryAccountType,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.Ownership AS Ownership,
	|	InventoryBalances.CostObject AS CostObject,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.PresentationCurrency AS PresentationCurrency,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.InventoryAccountType AS InventoryAccountType,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.Ownership AS Ownership,
	|		InventoryBalances.CostObject AS CostObject,
	|		InventoryBalances.QuantityBalance AS QuantityBalance,
	|		InventoryBalances.AmountBalance AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject) IN
	|					(SELECT
	|						TableInventory.Company AS Company,
	|						TableInventory.PresentationCurrency AS PresentationCurrency,
	|						VALUE(Catalog.BusinessUnits.GoodsInTransit) AS StructuralUnit,
	|						TableInventory.CorrInventoryAccountType AS InventoryAccountType,
	|						TableInventory.Products AS Products,
	|						TableInventory.Characteristic AS Characteristic,
	|						TableInventory.Batch AS Batch,
	|						TableInventory.Ownership AS Ownership,
	|						TableInventory.CostObject AS CostObject
	|					FROM
	|						TemporaryTableProducts AS TableInventory)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.PresentationCurrency,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.InventoryAccountType,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		DocumentRegisterRecordsInventory.Ownership,
	|		DocumentRegisterRecordsInventory.CostObject,
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
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.PresentationCurrency,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.InventoryAccountType,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.Ownership,
	|	InventoryBalances.CostObject";
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add(
		"Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject");
	
	TemporaryTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;
	OtherExpenses = Catalogs.DefaultIncomeAndExpenseItems.GetItem("OtherExpenses");
	
	TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company",		  	  RowTableInventory.Company);
		StructureForSearch.Insert("PresentationCurrency", RowTableInventory.PresentationCurrency);
		StructureForSearch.Insert("StructuralUnit",	      Catalogs.BusinessUnits.GoodsInTransit);
		StructureForSearch.Insert("InventoryAccountType", RowTableInventory.CorrInventoryAccountType);
		StructureForSearch.Insert("Products",		      RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic",       RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch",			      RowTableInventory.Batch);
		StructureForSearch.Insert("Ownership",			  RowTableInventory.Ownership);
		StructureForSearch.Insert("CostObject",			  RowTableInventory.CostObject);
		
		QuantityRequiredAvailableBalance = ?(ValueIsFilled(RowTableInventory.Quantity), RowTableInventory.Quantity, 0);
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredAvailableBalance Then
				
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
			
			// Receipt. Inventory.
			TableRowReceipt = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventory);
			
			TableRowReceipt.Amount = AmountToBeWrittenOff;
			TableRowReceipt.Quantity = QuantityRequiredAvailableBalance;
			TableRowReceipt.SalesOrder = Undefined;
			TableRowReceipt.IncomeAndExpenseItem = OtherExpenses;
			
			// Generate postings.
			If UseDefaultTypeOfAccounting And Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
				RowTableAccountingJournalEntries.Amount = AmountToBeWrittenOff;
			EndIf;
			
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory,,"StructuralUnit, StructuralUnitCorr");
			
			TableRowExpense.RecordType = AccumulationRecordType.Expense;
			
			TableRowExpense.Company = RowTableInventory.CorrOrganization;
			TableRowExpense.PresentationCurrency = RowTableInventory.CorrPresentationCurrency;
			TableRowExpense.StructuralUnit = RowTableInventory.StructuralUnitCorr;
			TableRowExpense.GLAccount = RowTableInventory.CorrGLAccount;
			TableRowExpense.InventoryAccountType = RowTableInventory.CorrInventoryAccountType;
			TableRowExpense.Products = RowTableInventory.ProductsCorr;
			TableRowExpense.Characteristic = RowTableInventory.CharacteristicCorr;
			TableRowExpense.Batch = RowTableInventory.BatchCorr;
			TableRowExpense.Ownership = RowTableInventory.OwnershipCorr;
			
			TableRowExpense.CorrOrganization = RowTableInventory.Company;
			TableRowExpense.CorrPresentationCurrency = RowTableInventory.PresentationCurrency;
			TableRowExpense.StructuralUnitCorr = RowTableInventory.StructuralUnit;
			TableRowExpense.CorrGLAccount = RowTableInventory.GLAccount;
			TableRowExpense.CorrInventoryAccountType = RowTableInventory.InventoryAccountType;
			TableRowExpense.ProductsCorr = RowTableInventory.Products;
			TableRowExpense.CharacteristicCorr = RowTableInventory.Characteristic;
			TableRowExpense.BatchCorr = RowTableInventory.Batch;
			TableRowExpense.OwnershipCorr = RowTableInventory.Ownership;
			TableRowExpense.CorrIncomeAndExpenseItem = OtherExpenses;
			
			TableRowExpense.SourceDocument = RowTableInventory.VATinvoiceBasisDocument;
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
			
			TableRowExpense.ContentOfAccountingRecord = NStr("en = 'Goods in transit'; ru = 'Товары в пути';pl = 'Towary w tranzycie';es_ES = 'Mercancías en tránsito';es_CO = 'Mercancías en tránsito';tr = 'Transit mallar';it = 'Merci in transito';de = 'Waren in Transit'", MainLanguageCode);
			
			TableRowExpense.GLAccount = RowTableInventory.CorrGLAccount;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
EndProcedure

Procedure GenerateTableReservedProducts(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	TableBackorders = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.CopyColumns();
	TableReservedProducts = DriveServer.EmptyReservedProductsTable();
	
	If StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.Total("Quantity") <> 0 Then
		
		For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
			
			RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("SupplySource",	RowTableInventory.SupplySource);
			StructureForSearch.Insert("Products",		RowTableInventory.Products);
			StructureForSearch.Insert("Characteristic",	RowTableInventory.Characteristic);
			
			PlacedOrdersTable = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.FindRows(StructureForSearch);
			
			RowTableInventoryQuantity = RowTableInventory.Quantity;
			
			If PlacedOrdersTable.Count() > 0 Then
				
				For Each PlacedOrdersRow In PlacedOrdersTable Do
					
					If PlacedOrdersRow.Quantity <=0 Then
						Continue;
					EndIf;
					
					// Placement
					NewRowTableBackorders = TableBackorders.Add();
					FillPropertyValues(NewRowTableBackorders, PlacedOrdersRow);
					
					// Reserve
					NewRowReservedTable = TableReservedProducts.Add();
					FillPropertyValues(NewRowReservedTable, RowTableInventory);
					NewRowReservedTable.SalesOrder = ?(ValueIsFilled(PlacedOrdersRow.SalesOrder), PlacedOrdersRow.SalesOrder, Undefined);
					
					NewRowTableBackorders.Quantity = Min(RowTableInventoryQuantity, PlacedOrdersRow.Quantity);
					NewRowReservedTable.Quantity = Min(RowTableInventoryQuantity, PlacedOrdersRow.Quantity);
					
					PlacedOrdersRow.Quantity = PlacedOrdersRow.Quantity - NewRowTableBackorders.Quantity;
					RowTableInventoryQuantity = RowTableInventoryQuantity - NewRowTableBackorders.Quantity;
					
					If RowTableInventoryQuantity <= 0 Then
						Break;
					EndIf;
					
				EndDo;
			EndIf;
			
		EndDo;
		
	EndIf;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts", TableReservedProducts);
	StructureAdditionalProperties.TableForRegisterRecords.TableBackorders = TableBackorders;
	TableBackorders = Undefined;
	
EndProcedure

Procedure GenerateTableInventoryReturn(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text =
	"SELECT
	|	TableInventory.CorrOrganization AS Company,
	|	TableInventory.CorrPresentationCurrency AS PresentationCurrency,
	|	TableInventory.StructuralUnitCorr AS StructuralUnit,
	|	TableInventory.CorrInventoryAccountType AS InventoryAccountType,
	|	TableInventory.ProductsCorr AS Products,
	|	TableInventory.CharacteristicCorr AS Characteristic,
	|	TableInventory.BatchCorr AS Batch,
	|	TableInventory.OwnershipCorr AS Ownership,
	|	TableInventory.CostObject AS CostObject
	|FROM
	|	TemporaryTableProducts AS TableInventory
	|
	|GROUP BY
	|	TableInventory.CorrOrganization,
	|	TableInventory.CorrPresentationCurrency,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.CorrInventoryAccountType,
	|	TableInventory.ProductsCorr,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.BatchCorr,
	|	TableInventory.OwnershipCorr,
	|	TableInventory.CostObject";
	
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
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.PresentationCurrency AS PresentationCurrency,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.InventoryAccountType AS InventoryAccountType,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.Ownership AS Ownership,
	|	InventoryBalances.CostObject AS CostObject,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.PresentationCurrency AS PresentationCurrency,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.InventoryAccountType AS InventoryAccountType,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.Ownership AS Ownership,
	|		InventoryBalances.CostObject AS CostObject,
	|		InventoryBalances.QuantityBalance AS QuantityBalance,
	|		InventoryBalances.AmountBalance AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject) IN
	|					(SELECT
	|						TableInventory.CorrOrganization,
	|						TableInventory.CorrPresentationCurrency,
	|						TableInventory.StructuralUnitCorr,
	|						TableInventory.CorrInventoryAccountType,
	|						TableInventory.ProductsCorr,
	|						TableInventory.CharacteristicCorr,
	|						TableInventory.BatchCorr,
	|						TableInventory.OwnershipCorr,
	|						TableInventory.CostObject
	|					FROM
	|						TemporaryTableProducts AS TableInventory)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.PresentationCurrency,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.InventoryAccountType,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		DocumentRegisterRecordsInventory.Ownership,
	|		DocumentRegisterRecordsInventory.CostObject,
	|		ISNULL(DocumentRegisterRecordsInventory.Quantity, 0),
	|		ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.PresentationCurrency,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.InventoryAccountType,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.Ownership,
	|	InventoryBalances.CostObject";
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add(
		"Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject");
	
	TableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();
	
	UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company",				RowTableInventory.Company);
		StructureForSearch.Insert("PresentationCurrency",	RowTableInventory.PresentationCurrency);
		StructureForSearch.Insert("StructuralUnit",			RowTableInventory.StructuralUnitCorr);
		StructureForSearch.Insert("InventoryAccountType",	RowTableInventory.CorrInventoryAccountType);
		StructureForSearch.Insert("Products",				RowTableInventory.ProductsCorr);
		StructureForSearch.Insert("Characteristic",			RowTableInventory.CharacteristicCorr);
		StructureForSearch.Insert("Batch",					RowTableInventory.BatchCorr);
		StructureForSearch.Insert("Ownership",				RowTableInventory.OwnershipCorr);
		StructureForSearch.Insert("CostObject",				RowTableInventory.CostObject);
		
		QuantityWanted = RowTableInventory.Quantity;
		
		If QuantityWanted > 0 Then
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityWanted Then
			
				AmountToBeWrittenOff = Round(AmountBalance * QuantityWanted / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityWanted;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = QuantityWanted Then
				
				AmountToBeWrittenOff = AmountBalance;
				
				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			// Expense.
			TableRowReceipt = TableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventory);
			
			TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
			TableRowReceipt.Amount = AmountToBeWrittenOff;
			TableRowReceipt.Quantity = QuantityWanted;
			
			TableRowReceipt.SalesOrder = Undefined;
			
			TableRowReceipt.Return = True;
			
			// Generate postings.
			If UseDefaultTypeOfAccounting And Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
				RowTableAccountingJournalEntries.AccountDr = RowTableInventory.GLAccount;
				RowTableAccountingJournalEntries.CurrencyDr = Undefined;
				RowTableAccountingJournalEntries.AmountCurDr = 0;
				RowTableAccountingJournalEntries.AccountCr = RowTableInventory.CorrGLAccount;
				RowTableAccountingJournalEntries.CurrencyCr = Undefined;
				RowTableAccountingJournalEntries.AmountCurCr = 0;
				RowTableAccountingJournalEntries.Amount = AmountToBeWrittenOff;
				RowTableAccountingJournalEntries.Content = RowTableInventory.ContentOfAccountingRecord;
				
			EndIf;
			
			TableRowExpense = TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory,,"StructuralUnit, StructuralUnitCorr");
			
			TableRowExpense.RecordType = AccumulationRecordType.Expense;
			TableRowExpense.Company = RowTableInventory.CorrOrganization;
			TableRowExpense.PresentationCurrency = RowTableInventory.CorrPresentationCurrency;
			TableRowExpense.StructuralUnit = RowTableInventory.StructuralUnitCorr;
			TableRowExpense.GLAccount = RowTableInventory.CorrGLAccount;
			TableRowExpense.InventoryAccountType = RowTableInventory.CorrInventoryAccountType;
			TableRowExpense.Products = RowTableInventory.ProductsCorr;
			TableRowExpense.Characteristic = RowTableInventory.CharacteristicCorr;
			TableRowExpense.Batch = RowTableInventory.BatchCorr;
			TableRowExpense.Ownership = RowTableInventory.OwnershipCorr;
			TableRowExpense.SalesOrder = RowTableInventory.CorrOrder;
			
			TableRowExpense.CorrOrganization = RowTableInventory.Company;
			TableRowExpense.CorrPresentationCurrency = RowTableInventory.PresentationCurrency;
			TableRowExpense.StructuralUnitCorr = RowTableInventory.StructuralUnit;
			TableRowExpense.CorrGLAccount = RowTableInventory.GLAccount;
			TableRowExpense.CorrInventoryAccountType = RowTableInventory.InventoryAccountType;
			TableRowExpense.ProductsCorr = RowTableInventory.Products;
			TableRowExpense.CharacteristicCorr = RowTableInventory.Characteristic;
			TableRowExpense.BatchCorr = RowTableInventory.Batch;
			TableRowExpense.OwnershipCorr = RowTableInventory.Ownership;
			TableRowExpense.CorrOrder = Undefined;
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityWanted;
			
			TableRowExpense.GLAccount = RowTableInventory.CorrGLAccount;
			TableRowExpense.InventoryAccountType = RowTableInventory.CorrInventoryAccountType;
			
			TableRowExpense.Return = True;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TableInventory;
	
EndProcedure

Procedure GenerateTableInventoryCostLayer(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	Inventory.RecordType AS RecordType,
	|	Inventory.Period AS Period,
	|	Inventory.Company AS Company,
	|	Inventory.PresentationCurrency AS PresentationCurrency,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.Ownership AS Ownership,
	|	Inventory.SalesOrder AS SalesOrder,
	|	CASE
	|		WHEN Inventory.ReceiptFromSubcontractor
	|			THEN Inventory.SupplySource
	|		ELSE CASE
	|				WHEN Inventory.NotInvoiced
	|					THEN Inventory.Document
	|				ELSE Inventory.SupplierInvoice
	|			END
	|	END AS CostLayer,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.InventoryAccountType AS InventoryAccountType,
	|	Inventory.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	SUM(Inventory.Quantity) AS Quantity,
	|	SUM(Inventory.Amount) AS Amount,
	|	Inventory.VATRate AS VATRate,
	|	TRUE AS SourceRecord
	|FROM
	|	TableInventoryComplete AS Inventory
	|WHERE
	|	(Inventory.ContinentalMethod
	|			OR NOT Inventory.NotInvoiced
	|			OR Inventory.ReceiptFromSubcontractor)
	|	AND Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND &UseFIFO
	|	AND NOT &IntraCommunityTransfer
	|
	|GROUP BY
	|	Inventory.RecordType,
	|	Inventory.Period,
	|	Inventory.Company,
	|	Inventory.PresentationCurrency,
	|	Inventory.Products,
	|	Inventory.Characteristic,
	|	Inventory.Batch,
	|	Inventory.Ownership,
	|	Inventory.SalesOrder,
	|	CASE
	|		WHEN Inventory.ReceiptFromSubcontractor
	|			THEN Inventory.SupplySource
	|		ELSE CASE
	|				WHEN Inventory.NotInvoiced
	|					THEN Inventory.Document
	|				ELSE Inventory.SupplierInvoice
	|			END
	|	END,
	|	Inventory.Price,
	|	Inventory.VATRate,
	|	Inventory.StructuralUnit,
	|	Inventory.GLAccount,
	|	Inventory.InventoryAccountType,
	|	Inventory.IncomeAndExpenseItem";
	
	Query.SetParameter("UseFIFO", StructureAdditionalProperties.AccountingPolicy.UseFIFO);
	Query.SetParameter("IntraCommunityTransfer", 
		StructureAdditionalProperties.DocumentAttributes.OperationType = Enums.OperationTypesGoodsReceipt.IntraCommunityTransfer);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCostLayer", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableInventoryInWarehouses(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventoryInWarehouses.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
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
	|	TemporaryTableProducts AS TableInventoryInWarehouses
	|WHERE
	|	TableInventoryInWarehouses.OperationType <> VALUE(Enum.OperationTypesGoodsReceipt.DropShipping)
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

Procedure GenerateTableSerialNumbers(DocumentRef, StructureAdditionalProperties)
	
	If DocumentRef.SerialNumbers.Count()=0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	VALUE(Enum.SerialNumbersOperations.Receipt) AS Operation,
	|	TemporaryTableInventory.Period AS EventDate,
	|	SerialNumbers.SerialNumber AS SerialNumber,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.Products AS Products,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	TemporaryTableInventory.Batch AS Batch,
	|	TemporaryTableInventory.Ownership AS Ownership,
	|	TemporaryTableInventory.StructuralUnit AS StructuralUnit,
	|	TemporaryTableInventory.Cell AS Cell,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableProducts AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
	|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey";
	
	QueryResult = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", QueryResult);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
	EndIf;
	
EndProcedure

Procedure GenerateTableInventoryComplete(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Period AS Period,
	|	TableInventory.RecordType AS RecordType,
	|	TableInventory.Document AS Document,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.Counterparty AS Counterparty,
	|	TableInventory.Contract AS Contract,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.SupplySource AS SupplySource,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	TableInventory.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	TableInventory.VATRate AS VATRate,
	|	TableInventory.SupplierInvoice AS SupplierInvoice,
	|	TableInventory.NotInvoiced AS NotInvoiced,
	|	TableInventory.ReceiptFromSubcontractor,
	|	&ContinentalMethod AS ContinentalMethod,
	|	TableInventory.Quantity AS Quantity,
	|	TableInventory.Price AS Price,
	|	TableInventory.Amount AS Amount
	|INTO TableInventoryComplete
	|FROM
	|	&TableInventory AS TableInventory";
	
	Query.SetParameter("TableInventory", StructureAdditionalProperties.TableForRegisterRecords.TableInventory);
	Query.SetParameter("ContinentalMethod", StructureAdditionalProperties.AccountingPolicy.ContinentalMethod);
	Query.Execute();
	
EndProcedure

Procedure GenerateTableGoodsReceivedNotInvoiced(DocumentRef, StructureAdditionalProperties)
	
	If StructureAdditionalProperties.DocumentAttributes.OperationType <> Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier
		And StructureAdditionalProperties.DocumentAttributes.OperationType <> Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractor
		And StructureAdditionalProperties.DocumentAttributes.OperationType <> Enums.OperationTypesGoodsReceipt.DropShipping Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsReceivedNotInvoiced", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Document AS GoodsReceipt,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.Counterparty AS Counterparty,
	|	TableInventory.Contract AS Contract,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	CASE
	|		WHEN TableInventory.ContinentalMethod
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		ELSE TableInventory.SalesOrder
	|	END AS SalesOrder,
	|	CASE
	|		WHEN TableInventory.SupplySource = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SupplySource
	|	END AS PurchaseOrder,
	|	TableInventory.Quantity AS Quantity,
	|	TableInventory.Amount AS Amount
	|FROM
	|	TableInventoryComplete AS TableInventory
	|WHERE
	|	TableInventory.NotInvoiced
	|	AND TableInventory.RecordType = VALUE(AccumulationRecordType.Receipt)";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsReceivedNotInvoiced", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableGoodsInvoicedNotReceived(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
#Region GenerateTableGoodsInvoicedNotReceivedQueryText
	
	Query.Text =
	"SELECT
	|	TableProducts.SupplierInvoice AS SupplierInvoice,
	|	TableProducts.Company AS Company,
	|	TableProducts.PresentationCurrency AS PresentationCurrency,
	|	TableProducts.Counterparty AS Counterparty,
	|	TableProducts.Contract AS Contract,
	|	TableProducts.Order AS PurchaseOrder,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.Ownership AS Ownership,
	|	TableProducts.InventoryAccountType AS InventoryAccountType,
	|	SUM(TableProducts.Quantity) AS Quantity,
	|	TableProducts.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableProducts.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	TableProducts.ContentOfAccountingRecord AS Content,
	|	TableProducts.StructuralUnit AS StructuralUnit,
	|	VALUE(Document.SalesOrder.EmptyRef) AS SalesOrder,
	|	TableProducts.Order AS SupplySource,
	|	&Ref AS Document,
	|	FALSE AS Return,
	|	FALSE AS NotInvoiced,
	|	TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractor) AS ReceiptFromSubcontractor,
	|	TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.PurchaseFromSupplier) AS FixedCost,
	|	TableProducts.GLAccount AS GLAccount,
	|	TableProducts.GLAccount AS AccountDr,
	|	TableProducts.GoodsInvoicedNotDeliveredGLAccount AS AccountCr
	|FROM
	|	TemporaryTableProducts AS TableProducts
	|WHERE
	|	TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.PurchaseFromSupplier)
	|	AND NOT TableProducts.SupplierInvoice = VALUE(Document.SupplierInvoice.EmptyRef)
	|	AND TableProducts.Quantity > 0
	|
	|GROUP BY
	|	TableProducts.SupplierInvoice,
	|	TableProducts.Company,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.Counterparty,
	|	TableProducts.Contract,
	|	TableProducts.Order,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.Ownership,
	|	TableProducts.InventoryAccountType,
	|	TableProducts.Period,
	|	TableProducts.ContentOfAccountingRecord,
	|	TableProducts.StructuralUnit,
	|	TableProducts.GLAccount,
	|	TableProducts.GoodsInvoicedNotDeliveredGLAccount,
	|	TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractor),
	|	TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.PurchaseFromSupplier),
	|	TableProducts.ContentOfAccountingRecord,
	|	TableProducts.Order,
	|	TableProducts.GLAccount";
	
#EndRegion
	
	Query.SetParameter("Ref", DocumentRef);
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	TableProducts = QueryResult.Unload();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.GoodsInvoicedNotReceived");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	StructureForSearch = New Structure;
	
	MetaRegisterDimensions = Metadata.AccumulationRegisters.GoodsInvoicedNotReceived.Dimensions;
	For Each ColumnQueryResult In QueryResult.Columns Do
		If MetaRegisterDimensions.Find(ColumnQueryResult.Name) <> Undefined
			And ValueIsFilled(ColumnQueryResult.ValueType) Then
			LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
			StructureForSearch.Insert(ColumnQueryResult.Name);
		EndIf;
	EndDo;
	Block.Lock();
	
#Region GenerateTableGoodsInvoicedNotReceivedBalancesQueryText
	
	Query.Text =
	"SELECT
	|	UNDEFINED AS Period,
	|	UNDEFINED AS RecordType,
	|	Balances.SupplierInvoice AS SupplierInvoice,
	|	Balances.Company AS Company,
	|	Balances.PresentationCurrency AS PresentationCurrency,
	|	Balances.Counterparty AS Counterparty,
	|	Balances.Contract AS Contract,
	|	Balances.PurchaseOrder AS PurchaseOrder,
	|	Balances.Products AS Products,
	|	Balances.Characteristic AS Characteristic,
	|	Balances.Batch AS Batch,
	|	VALUE(Catalog.InventoryOwnership.EmptyRef) AS Ownership,
	|	Balances.VATRate AS VATRate,
	|	SUM(Balances.Quantity) AS Quantity,
	|	SUM(Balances.Amount) AS Amount,
	|	SUM(Balances.VATAmount) AS VATAmount
	|FROM
	|	(SELECT
	|		Balances.SupplierInvoice AS SupplierInvoice,
	|		Balances.Company AS Company,
	|		Balances.PresentationCurrency AS PresentationCurrency,
	|		Balances.Counterparty AS Counterparty,
	|		Balances.Contract AS Contract,
	|		Balances.PurchaseOrder AS PurchaseOrder,
	|		Balances.Products AS Products,
	|		Balances.Characteristic AS Characteristic,
	|		Balances.Batch AS Batch,
	|		Balances.VATRate AS VATRate,
	|		Balances.QuantityBalance AS Quantity,
	|		Balances.AmountBalance AS Amount,
	|		Balances.VATAmountBalance AS VATAmount
	|	FROM
	|		AccumulationRegister.GoodsInvoicedNotReceived.Balance(
	|				&ControlTime,
	|				(SupplierInvoice, Company, PresentationCurrency, Counterparty, Contract, PurchaseOrder, Products, Characteristic, Batch) IN
	|					(SELECT
	|						TableProducts.SupplierInvoice AS SupplierInvoice,
	|						TableProducts.Company AS Company,
	|						TableProducts.PresentationCurrency AS PresentationCurrency,
	|						TableProducts.Counterparty AS Counterparty,
	|						TableProducts.Contract AS Contract,
	|						TableProducts.Order AS PurchaseOrder,
	|						TableProducts.Products AS Products,
	|						TableProducts.Characteristic AS Characteristic,
	|						TableProducts.Batch AS Batch
	|					FROM
	|						TemporaryTableProducts AS TableProducts)) AS Balances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRecords.SupplierInvoice,
	|		DocumentRecords.Company,
	|		DocumentRecords.PresentationCurrency,
	|		DocumentRecords.Counterparty,
	|		DocumentRecords.Contract,
	|		DocumentRecords.PurchaseOrder,
	|		DocumentRecords.Products,
	|		DocumentRecords.Characteristic,
	|		DocumentRecords.Batch,
	|		DocumentRecords.VATRate,
	|		CASE
	|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRecords.Quantity
	|			ELSE -DocumentRecords.Quantity
	|		END,
	|		CASE
	|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRecords.Amount
	|			ELSE -DocumentRecords.Amount
	|		END,
	|		CASE
	|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRecords.VATAmount
	|			ELSE -DocumentRecords.VATAmount
	|		END
	|	FROM
	|		AccumulationRegister.GoodsInvoicedNotReceived AS DocumentRecords
	|	WHERE
	|		DocumentRecords.Recorder = &Ref
	|		AND DocumentRecords.Period <= &ControlPeriod) AS Balances
	|
	|GROUP BY
	|	Balances.SupplierInvoice,
	|	Balances.Company,
	|	Balances.Counterparty,
	|	Balances.Contract,
	|	Balances.PurchaseOrder,
	|	Balances.Products,
	|	Balances.Characteristic,
	|	Balances.Batch,
	|	Balances.VATRate,
	|	Balances.PresentationCurrency";
	
#EndRegion
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableBalances = QueryResult.Unload();
	TableBalances.Indexes.Add("SupplierInvoice, Company, PresentationCurrency, Counterparty, Contract, PurchaseOrder, Products, Characteristic, Batch");
	
	TemporaryTableProducts = TableBalances.CopyColumns();
	
	TablesForRegisterRecords = StructureAdditionalProperties.TableForRegisterRecords;
	
	TableAccountingJournalEntries = TablesForRegisterRecords.TableAccountingJournalEntries;
	TableInventory = TablesForRegisterRecords.TableInventory;
	
	UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;
	
	For Each TableProductsRow In TableProducts Do
		
		FillPropertyValues(StructureForSearch, TableProductsRow);
		
		BalanceRowsArray = TableBalances.FindRows(StructureForSearch);
		
		QuantityToBeWrittenOff = TableProductsRow.Quantity;
		
		For Each TableBalancesRow In BalanceRowsArray Do
			
			If TableBalancesRow.Quantity > 0 Then
				
				NewRow = TemporaryTableProducts.Add();
				FillPropertyValues(NewRow, TableBalancesRow, , "Quantity, Amount, VATAmount");
				FillPropertyValues(NewRow, TableProductsRow, "Period, RecordType, Ownership");
				
				NewRow.Quantity = Min(TableBalancesRow.Quantity, QuantityToBeWrittenOff);
				
				If NewRow.Quantity < TableBalancesRow.Quantity Then
					
					NewRow.Amount = Round(TableBalancesRow.Amount * NewRow.Quantity / TableBalancesRow.Quantity, 2, 1);
					NewRow.VATAmount = Round(TableBalancesRow.VATAmount * NewRow.Quantity / TableBalancesRow.Quantity, 2, 1);
					QuantityToBeWrittenOff = 0;
					TableBalancesRow.Quantity = TableBalancesRow.Quantity - NewRow.Quantity;
					TableBalancesRow.Amount = TableBalancesRow.Amount - NewRow.Amount;
					TableBalancesRow.VATAmount = TableBalancesRow.VATAmount - NewRow.VATAmount;
					
				Else
					
					NewRow.Amount = TableBalancesRow.Amount;
					NewRow.VATAmount = TableBalancesRow.VATAmount;
					QuantityToBeWrittenOff = QuantityToBeWrittenOff - NewRow.Quantity;
					TableBalancesRow.Quantity = 0;
					TableBalancesRow.Amount = 0;
					TableBalancesRow.VATAmount = 0;
					
				EndIf;
				
				If UseDefaultTypeOfAccounting Then
					
					TableAccountingRow = TableAccountingJournalEntries.Add();
					FillPropertyValues(TableAccountingRow, TableProductsRow);
					TableAccountingRow.Amount = NewRow.Amount;
				EndIf;
				
				TableInventoryRow = TableInventory.Add();
				FillPropertyValues(TableInventoryRow, TableProductsRow);
				TableInventoryRow.RecordType = AccumulationRecordType.Receipt;
				TableInventoryRow.VATRate = NewRow.VATRate;
				TableInventoryRow.Quantity = NewRow.Quantity;
				TableInventoryRow.Amount = NewRow.Amount;
				
			EndIf;
			
			If QuantityToBeWrittenOff = 0 Then
				Break;
			EndIf;
			
		EndDo;
		
		If QuantityToBeWrittenOff > 0 Then
			
			NewRow = TemporaryTableProducts.Add();
			FillPropertyValues(NewRow, TableProductsRow, , "Quantity");
			NewRow.Quantity = QuantityToBeWrittenOff;
			
		EndIf;
		
	EndDo;
	
	TablesForRegisterRecords.Insert("TableGoodsInvoicedNotReceived", TemporaryTableProducts);
	
EndProcedure

Procedure GenerateTableStockReceivedFromThirdParties(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableStockReceivedFromThirdParties.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableStockReceivedFromThirdParties.Period AS Period,
	|	TableStockReceivedFromThirdParties.Company AS Company,
	|	TableStockReceivedFromThirdParties.Products AS Products,
	|	TableStockReceivedFromThirdParties.Characteristic AS Characteristic,
	|	TableStockReceivedFromThirdParties.Batch AS Batch,
	|	TableStockReceivedFromThirdParties.Counterparty AS Counterparty,
	|	CASE
	|		WHEN TableStockReceivedFromThirdParties.Order REFS Document.PurchaseOrder
	|				AND TableStockReceivedFromThirdParties.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TableStockReceivedFromThirdParties.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	TableStockReceivedFromThirdParties.GLAccount AS GLAccount,
	|	TableStockReceivedFromThirdParties.InventoryAccountType AS InventoryAccountType,
	|	SUM(TableStockReceivedFromThirdParties.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProducts AS TableStockReceivedFromThirdParties
	|WHERE
	|	TableStockReceivedFromThirdParties.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromAThirdParty)
	|
	|GROUP BY
	|	TableStockReceivedFromThirdParties.Period,
	|	TableStockReceivedFromThirdParties.Company,
	|	TableStockReceivedFromThirdParties.Products,
	|	TableStockReceivedFromThirdParties.Characteristic,
	|	TableStockReceivedFromThirdParties.Batch,
	|	TableStockReceivedFromThirdParties.Counterparty,
	|	TableStockReceivedFromThirdParties.Order,
	|	TableStockReceivedFromThirdParties.GLAccount,
	|	TableStockReceivedFromThirdParties.InventoryAccountType";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockReceivedFromThirdParties", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableStockTransferredToThirdParties(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableStockTransferredToThirdParties.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableStockTransferredToThirdParties.Period AS Period,
	|	TableStockTransferredToThirdParties.Company AS Company,
	|	TableStockTransferredToThirdParties.Products AS Products,
	|	TableStockTransferredToThirdParties.Characteristic AS Characteristic,
	|	TableStockTransferredToThirdParties.Batch AS Batch,
	|	TableStockTransferredToThirdParties.Counterparty AS Counterparty,
	|	CASE
	|		WHEN TableStockTransferredToThirdParties.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TableStockTransferredToThirdParties.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	SUM(TableStockTransferredToThirdParties.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProducts AS TableStockTransferredToThirdParties
	|WHERE
	|	TableStockTransferredToThirdParties.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
	|
	|GROUP BY
	|	TableStockTransferredToThirdParties.Period,
	|	TableStockTransferredToThirdParties.Company,
	|	TableStockTransferredToThirdParties.Products,
	|	TableStockTransferredToThirdParties.Characteristic,
	|	TableStockTransferredToThirdParties.Batch,
	|	TableStockTransferredToThirdParties.Counterparty,
	|	TableStockTransferredToThirdParties.Order
	|
	|UNION ALL
	|
	|SELECT
	|	MIN(TableStockTransferredToThirdParties.LineNumber),
	|	VALUE(AccumulationRecordType.Expense),
	|	TableStockTransferredToThirdParties.Period,
	|	TableStockTransferredToThirdParties.Company,
	|	TableStockTransferredToThirdParties.Products,
	|	TableStockTransferredToThirdParties.Characteristic,
	|	TableStockTransferredToThirdParties.Batch,
	|	TableStockTransferredToThirdParties.Counterparty,
	|	TableStockTransferredToThirdParties.Order,
	|	SUM(TableStockTransferredToThirdParties.Quantity)
	|FROM
	|	TemporaryTableProducts AS TableStockTransferredToThirdParties
	|WHERE
	|	TableStockTransferredToThirdParties.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromSubcontractor)
	|	AND TableStockTransferredToThirdParties.Order REFS Document.SubcontractorOrderIssued
	|	AND TableStockTransferredToThirdParties.Order <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|
	|GROUP BY
	|	TableStockTransferredToThirdParties.Period,
	|	TableStockTransferredToThirdParties.Company,
	|	TableStockTransferredToThirdParties.Products,
	|	TableStockTransferredToThirdParties.Characteristic,
	|	TableStockTransferredToThirdParties.Batch,
	|	TableStockTransferredToThirdParties.Counterparty,
	|	TableStockTransferredToThirdParties.Order";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockTransferredToThirdParties", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableSalesOrders(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableSalesOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableSalesOrders.Period AS Period,
	|	TableSalesOrders.Company AS Company,
	|	TableSalesOrders.Products AS Products,
	|	TableSalesOrders.Characteristic AS Characteristic,
	|	TableSalesOrders.Order AS SalesOrder,
	|	SUM(TableSalesOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProducts AS TableSalesOrders
	|WHERE
	|	TableSalesOrders.Order REFS Document.SalesOrder
	|	AND TableSalesOrders.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND TableSalesOrders.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
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

Procedure GenerateTableInventoryDemand(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	VALUE(Enum.InventoryMovementTypes.Receipt) AS MovementType,
	|	TableInventory.Company AS Company,
	|	CASE
	|		WHEN TableInventory.Order REFS Document.SalesOrder
	|			THEN TableInventory.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS SalesOrder,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProducts AS TableInventory
	|WHERE
	|	TableInventory.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromAThirdParty)
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.Order,
	|	TableInventory.Products,
	|	TableInventory.Characteristic
	|
	|UNION ALL
	|
	|SELECT
	|	MIN(TableInventory.LineNumber),
	|	TableInventory.Period,
	|	VALUE(AccumulationRecordType.Receipt),
	|	VALUE(Enum.InventoryMovementTypes.Shipment),
	|	TableInventory.Company,
	|	VALUE(Document.SalesOrder.EmptyRef),
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	SUM(TableInventory.Quantity)
	|FROM
	|	TemporaryTableProducts AS TableInventory
	|WHERE
	|	TableInventory.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromSubcontractor)
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.Order,
	|	TableInventory.Products,
	|	TableInventory.Characteristic
	// begin Drive.FullVersion
	|
	|UNION ALL
	|
	|SELECT
	|	MIN(TableInventory.LineNumber),
	|	TableInventory.Period,
	|	VALUE(AccumulationRecordType.Expense),
	|	VALUE(Enum.InventoryMovementTypes.Receipt),
	|	TableInventory.Company,
	|	CASE
	|		WHEN TableInventory.Order REFS Document.SubcontractorOrderReceived
	|			THEN TableInventory.Order
	|		ELSE VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	|	END,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	SUM(TableInventory.Quantity)
	|FROM
	|	TemporaryTableProducts AS TableInventory
	|WHERE
	|	TableInventory.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer)
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.Order,
	|	TableInventory.Products,
	|	TableInventory.Characteristic
	// end Drive.FullVersion
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", QueryResult.Unload());
	
	OperationType = StructureAdditionalProperties.DocumentAttributes.OperationType;
	If OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty Then
		
		Query = New Query;
		Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
		Query.Text =
		"SELECT
		|	TableInventoryDemand.Company AS Company,
		|	VALUE(Enum.InventoryMovementTypes.Receipt) AS MovementType,
		|	CASE
		|		WHEN TableInventoryDemand.Order REFS Document.SalesOrder
		|			THEN TableInventoryDemand.Order
		|		ELSE VALUE(Document.SalesOrder.EmptyRef)
		|	END AS SalesOrder,
		|	TableInventoryDemand.Products AS Products,
		|	TableInventoryDemand.Characteristic AS Characteristic
		|FROM
		|	TemporaryTableProducts AS TableInventoryDemand
		|WHERE
		|	TableInventoryDemand.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromAThirdParty)";
		
		QueryResult = Query.Execute();
		
		Block = New DataLock;
		LockItem = Block.Add("AccumulationRegister.InventoryDemand");
		LockItem.Mode = DataLockMode.Exclusive;
		LockItem.DataSource = QueryResult;
		
		For Each ColumnQueryResult In QueryResult.Columns Do
			LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
		EndDo;
		Block.Lock();
		
		// Receive balance.
		Query.Text =
		"SELECT
		|	InventoryDemandBalances.Company AS Company,
		|	InventoryDemandBalances.SalesOrder AS SalesOrder,
		|	InventoryDemandBalances.Products AS Products,
		|	InventoryDemandBalances.Characteristic AS Characteristic,
		|	SUM(InventoryDemandBalances.Quantity) AS QuantityBalance
		|FROM
		|	(SELECT
		|		InventoryDemandBalances.Company AS Company,
		|		InventoryDemandBalances.SalesOrder AS SalesOrder,
		|		InventoryDemandBalances.Products AS Products,
		|		InventoryDemandBalances.Characteristic AS Characteristic,
		|		SUM(InventoryDemandBalances.QuantityBalance) AS Quantity
		|	FROM
		|		AccumulationRegister.InventoryDemand.Balance(
		|				&ControlTime,
		|				(Company, MovementType, SalesOrder, Products, Characteristic) IN
		|					(SELECT
		|						TemporaryTableInventory.Company AS Company,
		|						VALUE(Enum.InventoryMovementTypes.Receipt) AS MovementType,
		|						CASE
		|							WHEN TemporaryTableInventory.Order REFS Document.SalesOrder
		|								THEN TemporaryTableInventory.Order
		|							ELSE VALUE(Document.SalesOrder.EmptyRef)
		|						END AS SalesOrder,
		|						TemporaryTableInventory.Products AS Products,
		|						TemporaryTableInventory.Characteristic AS Characteristic
		|					FROM
		|						TemporaryTableProducts AS TemporaryTableInventory
		|					WHERE
		|						TemporaryTableInventory.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromAThirdParty))) AS InventoryDemandBalances
		|	
		|	GROUP BY
		|		InventoryDemandBalances.Company,
		|		InventoryDemandBalances.SalesOrder,
		|		InventoryDemandBalances.Products,
		|		InventoryDemandBalances.Characteristic
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecordsInventoryDemand.Company,
		|		DocumentRegisterRecordsInventoryDemand.SalesOrder,
		|		DocumentRegisterRecordsInventoryDemand.Products,
		|		DocumentRegisterRecordsInventoryDemand.Characteristic,
		|		CASE
		|			WHEN DocumentRegisterRecordsInventoryDemand.RecordType = VALUE(AccumulationRecordType.Expense)
		|				THEN ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
		|			ELSE -ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
		|		END
		|	FROM
		|		AccumulationRegister.InventoryDemand AS DocumentRegisterRecordsInventoryDemand
		|	WHERE
		|		DocumentRegisterRecordsInventoryDemand.Recorder = &Ref
		|		AND DocumentRegisterRecordsInventoryDemand.Period <= &ControlPeriod) AS InventoryDemandBalances
		|
		|GROUP BY
		|	InventoryDemandBalances.Company,
		|	InventoryDemandBalances.SalesOrder,
		|	InventoryDemandBalances.Products,
		|	InventoryDemandBalances.Characteristic";
		
		Query.SetParameter("Ref", DocumentRef);
		Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
		Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
		
		QueryResult = Query.Execute();
		
		TableInventoryDemandBalance = QueryResult.Unload();
		TableInventoryDemandBalance.Indexes.Add("Company,SalesOrder,Products,Characteristic");
		
		TemporaryTableInventoryDemand = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand.CopyColumns();
		
		For Each RowTablesForInventory In StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand Do
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("Company",		RowTablesForInventory.Company);
			StructureForSearch.Insert("SalesOrder",		RowTablesForInventory.SalesOrder);
			StructureForSearch.Insert("Products",		RowTablesForInventory.Products);
			StructureForSearch.Insert("Characteristic",	RowTablesForInventory.Characteristic);
			
			BalanceRowsArray = TableInventoryDemandBalance.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() > 0 Then
				
				If RowTablesForInventory.Quantity > BalanceRowsArray[0].QuantityBalance Then
					RowTablesForInventory.Quantity = BalanceRowsArray[0].QuantityBalance;
				EndIf;
				
				TableRowExpense = TemporaryTableInventoryDemand.Add();
				FillPropertyValues(TableRowExpense, RowTablesForInventory);
				
			EndIf;
			
		EndDo;
		
		StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand = TemporaryTableInventoryDemand;
		
	EndIf;
	
EndProcedure

Procedure GenerateTableBackorders(DocumentRef, StructureAdditionalProperties)
	
	TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	If TempTablesManager.Tables.Find("TempBackorders") <> Undefined Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	Inventory.Period AS Period,
	|	Inventory.Company AS Company,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Order AS SupplySource,
	|	Inventory.SalesOrder AS SalesOrder,
	|	SUM(Inventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableReservation AS Inventory
	|WHERE
	|	NOT Inventory.Order IN (UNDEFINED, VALUE(Document.PurchaseOrder.EmptyRef), VALUE(Document.SubcontractorOrderIssued.EmptyRef), VALUE(Document.SalesOrder.EmptyRef), VALUE(Document.PurchaseOrder.EmptyRef))
	|	AND NOT Inventory.SalesOrder IN (UNDEFINED, VALUE(Document.SalesOrder.EmptyRef), VALUE(Document.WorkOrder.EmptyRef))
	|	AND NOT Inventory.OperationType IN (VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromSubcontractor), VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer), VALUE(Enum.OperationTypesGoodsReceipt.DropShipping))
	|
	|GROUP BY
	|	Inventory.Period,
	|	Inventory.Company,
	|	Inventory.Products,
	|	Inventory.Order,
	|	Inventory.SalesOrder,
	|	Inventory.Characteristic";
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableAccountingJournalEntries.Period AS Period,
	|	TableAccountingJournalEntries.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableAccountingJournalEntries.GLAccount AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	TableAccountingJournalEntries.GoodsReceivedNotInvoicedGLAccount AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	TableAccountingJournalEntries.Amount AS Amount,
	|	&InventoryIncrease AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableProducts AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.ContinentalMethod
	|	AND TableAccountingJournalEntries.SupplierInvoice = VALUE(Document.SupplierInvoice.EmptyRef)
	|	AND (TableAccountingJournalEntries.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.PurchaseFromSupplier)
	|			OR TableAccountingJournalEntries.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.DropShipping))
	|
	|UNION ALL
	|
	|SELECT
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccount,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.COGSGLAccount,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.CostOfGoodsSold,
	|	&GoodsReturn,
	|	FALSE
	|FROM
	|	TemporaryTableProducts AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.SalesReturn)";
	
	Query.SetParameter("InventoryIncrease",
		NStr("en = 'Inventory receipt'; ru = 'Прием запасов';pl = 'Przyjęcie zapasów';es_ES = 'Recibo del inventario';es_CO = 'Recibo del inventario';tr = 'Stok fişi';it = 'Scorte ricevute';de = 'Bestandszugang'",
			StructureAdditionalProperties.DefaultLanguageCode));
	Query.SetParameter("GoodsReturn",
		NStr("en = 'Goods return'; ru = 'Возврат товара';pl = 'Zwrot towarów';es_ES = 'Devolución de productos';es_CO = 'Devolución de productos';tr = 'Mal iadesi';it = 'Restituzione merci';de = 'Warenrücksendung'",
			StructureAdditionalProperties.DefaultLanguageCode));
			
	TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;		
			
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
		FillPropertyValues(RowTableAccountingJournalEntries, Selection);
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries = TableAccountingJournalEntries;
	
EndProcedure

Procedure GenerateTableSales(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Period AS Period,
	|	TableSales.Document AS Recorder,
	|	TableSales.Products AS Products,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Batch AS Batch,
	|	TableSales.Ownership AS Ownership,
	|	TableSales.SalesDocument AS Document,
	|	TableSales.Company AS Company,
	|	TableSales.PresentationCurrency AS PresentationCurrency,
	|	TableSales.Counterparty AS Counterparty,
	|	TableSales.DocumentCurrency AS Currency,
	|	CASE
	|		WHEN VALUETYPE(TableSales.Order) = TYPE(Document.SalesOrder)
	|			THEN TableSales.Order
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	TableSales.Department AS Department,
	|	TableSales.VATRate AS VATRate,
	|	0 AS Amount,
	|	0 AS VATAmount,
	|	0 AS AmountCur,
	|	0 AS VATAmountCur,
	|	-TableSales.CostOfGoodsSold AS Cost,
	|	TableSales.Responsible AS Responsible,
	|	TableSales.SalesRep AS SalesRep,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableProducts AS TableSales
	|WHERE
	|	TableSales.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.SalesReturn)
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
	|	OfflineRecords.Department,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.Amount,
	|	OfflineRecords.VATAmount,
	|	OfflineRecords.AmountCur,
	|	OfflineRecords.VATAmountCur,
	|	OfflineRecords.Cost,
	|	OfflineRecords.Responsible,
	|	OfflineRecords.SalesRep,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Sales AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	Query.SetParameter("Ref", DocumentRef);
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableIncomeAndExpenses(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Document AS Recorder,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.PresentationCurrency AS PresentationCurrency,
	|	TableIncomeAndExpenses.SalesInvoiceStructuralUnit AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLine AS BusinessLine,
	|	TableIncomeAndExpenses.SalesReturnItem AS IncomeAndExpenseItem,
	|	TableIncomeAndExpenses.COGSGLAccount AS GLAccount,
	|	TableIncomeAndExpenses.Order AS SalesOrder,
	|	0 AS AmountIncome,
	|	SUM(-TableIncomeAndExpenses.CostOfGoodsSold) AS AmountExpense,
	|	&Content AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableProducts AS TableIncomeAndExpenses
	|WHERE
	|	TableIncomeAndExpenses.CostOfGoodsSold <> 0
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Document,
	|	TableIncomeAndExpenses.Period,
	|	TableIncomeAndExpenses.Order,
	|	TableIncomeAndExpenses.BusinessLine,
	|	TableIncomeAndExpenses.SalesInvoiceStructuralUnit,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.PresentationCurrency,
	|	TableIncomeAndExpenses.SalesReturnItem,
	|	TableIncomeAndExpenses.COGSGLAccount
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
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	Query.SetParameter("Content", NStr("en = 'Goods return'; ru = 'Возврат товара';pl = 'Zwrot towarów';es_ES = 'Devolución de productos';es_CO = 'Devolución de productos';tr = 'Mal iadesi';it = 'Restituzione merci';de = 'Warenrücksendung'", CommonClientServer.DefaultLanguageCode()));
	Query.SetParameter("Ref", DocumentRef);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableGoodsInTransit(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableProducts.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProducts.Period AS Period,
	|	TableProducts.VATinvoiceBasisDocument AS GoodsIssue,
	|	TableProducts.Company AS Company,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	SUM(TableProducts.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProducts AS TableProducts
	|WHERE
	|	TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer)
	|
	|GROUP BY
	|	TableProducts.Period,
	|	TableProducts.VATinvoiceBasisDocument,
	|	TableProducts.Company,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch";
	
	Query.SetParameter("Ref", DocumentRef);
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsInTransit", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableSubcontractorOrdersIssued(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT DISTINCT
	|	SubcontractorOrderProducts.Ref AS Order,
	|	SubcontractorOrderProducts.Products AS Products,
	|	SubcontractorOrderProducts.Characteristic AS Characteristic,
	|	VALUE(Enum.FinishedProductTypes.FinishedProduct) AS FinishedProductType
	|INTO SubcontractorOrderProducts
	|FROM
	|	Document.SubcontractorOrderIssued.Products AS SubcontractorOrderProducts
	|		INNER JOIN TemporaryTableProducts AS TemporaryTableProducts
	|		ON SubcontractorOrderProducts.Ref = TemporaryTableProducts.Order
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	SubcontractorOrderByProducts.Ref,
	|	SubcontractorOrderByProducts.Products,
	|	SubcontractorOrderByProducts.Characteristic,
	|	VALUE(Enum.FinishedProductTypes.ByProduct)
	|FROM
	|	Document.SubcontractorOrderIssued.ByProducts AS SubcontractorOrderByProducts
	|		INNER JOIN TemporaryTableProducts AS TemporaryTableProducts
	|		ON SubcontractorOrderByProducts.Ref = TemporaryTableProducts.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TemporaryTableProducts.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTableProducts.Company AS Company,
	|	TemporaryTableProducts.Period AS Period,
	|	TemporaryTableProducts.Products AS Products,
	|	TemporaryTableProducts.Characteristic AS Characteristic,
	|	SUM(TemporaryTableProducts.Quantity) AS Quantity,
	|	TemporaryTableProducts.Order AS SubcontractorOrder,
	|	VALUE(Enum.FinishedProductTypes.FinishedProduct) AS FinishedProductType
	|FROM
	|	TemporaryTableProducts AS TemporaryTableProducts
	|WHERE
	|	(TemporaryTableProducts.Order, TemporaryTableProducts.Products, TemporaryTableProducts.Characteristic) IN
	|			(SELECT
	|				SubcontractorOrderProducts.Order,
	|				SubcontractorOrderProducts.Products,
	|				SubcontractorOrderProducts.Characteristic
	|			FROM
	|				SubcontractorOrderProducts AS SubcontractorOrderProducts
	|			WHERE
	|				SubcontractorOrderProducts.FinishedProductType = VALUE(Enum.FinishedProductTypes.FinishedProduct))
	|	AND TemporaryTableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractor)
	|
	|GROUP BY
	|	TemporaryTableProducts.Period,
	|	TemporaryTableProducts.Products,
	|	TemporaryTableProducts.Characteristic,
	|	TemporaryTableProducts.Order,
	|	TemporaryTableProducts.Company
	|
	|UNION ALL
	|
	|SELECT
	|	MIN(TemporaryTableProducts.LineNumber),
	|	VALUE(AccumulationRecordType.Expense),
	|	TemporaryTableProducts.Company,
	|	TemporaryTableProducts.Period,
	|	TemporaryTableProducts.Products,
	|	TemporaryTableProducts.Characteristic,
	|	SUM(TemporaryTableProducts.Quantity),
	|	TemporaryTableProducts.Order,
	|	VALUE(Enum.FinishedProductTypes.ByProduct)
	|FROM
	|	TemporaryTableProducts AS TemporaryTableProducts
	|WHERE
	|	(TemporaryTableProducts.Order, TemporaryTableProducts.Products, TemporaryTableProducts.Characteristic) IN
	|			(SELECT
	|				SubcontractorOrderProducts.Order,
	|				SubcontractorOrderProducts.Products,
	|				SubcontractorOrderProducts.Characteristic
	|			FROM
	|				SubcontractorOrderProducts AS SubcontractorOrderProducts
	|			WHERE
	|				SubcontractorOrderProducts.FinishedProductType = VALUE(Enum.FinishedProductTypes.ByProduct))
	|	AND TemporaryTableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractor)
	|
	|GROUP BY
	|	TemporaryTableProducts.Period,
	|	TemporaryTableProducts.Products,
	|	TemporaryTableProducts.Characteristic,
	|	TemporaryTableProducts.Order,
	|	TemporaryTableProducts.Company";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSubcontractorOrdersIssued", QueryResult.Unload());
	
EndProcedure

// begin Drive.FullVersion
Procedure GenerateTableSubcontractComponents(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TemporaryTableProducts.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TemporaryTableProducts.Period AS Period,
	|	TemporaryTableProducts.Order AS SubcontractorOrder,
	|	TemporaryTableProducts.Products AS Products,
	|	TemporaryTableProducts.Characteristic AS Characteristic,
	|	SUM(TemporaryTableProducts.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProducts AS TemporaryTableProducts
	|WHERE
	|	TemporaryTableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer)
	|	AND TemporaryTableProducts.Order REFS Document.SubcontractorOrderReceived
	|	AND TemporaryTableProducts.Order <> VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	|
	|GROUP BY
	|	TemporaryTableProducts.Period,
	|	TemporaryTableProducts.Order,
	|	TemporaryTableProducts.Products,
	|	TemporaryTableProducts.Characteristic";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSubcontractComponents", QueryResult.Unload());
	
EndProcedure
// end Drive.FullVersion

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	Var Errors;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "GoodsReceivedNote") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"GoodsReceivedNote",
			NStr("en = 'Goods received note'; ru = 'Уведомление о доставке товаров';pl = 'Przyjęcie zewnętrzne';es_ES = 'Nota de recepción de productos';es_CO = 'Nota de recepción de productos';tr = 'Teslim alındı belgesi';it = 'Nota di ricezione merci';de = 'Lieferantenlieferschein'"),
			DataProcessors.PrintGoodsReceivedNote.PrintForm(ObjectsArray, PrintObjects, "GoodsReceivedNote", PrintParameters.Result));
	EndIf;

	If Errors <> Undefined Then
		CommonClientServer.ReportErrorsToUser(Errors);
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "GoodsReceivedNote";
	PrintCommand.Presentation				= NStr("en = 'Goods received note'; ru = 'Уведомление о доставке товаров';pl = 'Przyjęcie zewnętrzne';es_ES = 'Nota de recepción de productos';es_CO = 'Nota de recepción de productos';tr = 'Teslim alındı belgesi';it = 'Nota di ricezione merci';de = 'Lieferantenlieferschein'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	AttachableCommands.AddCommandVisibilityCondition(PrintCommand, 
		"OperationType",
		Enums.OperationTypesGoodsReceipt.DropShipping,
		DataCompositionComparisonType.NotEqual);
	
	If AccessRight("View", Metadata.DataProcessors.PrintLabelsAndTags) Then
		
		PrintCommand = PrintCommands.Add();
		PrintCommand.Handler = "DriveClient.PrintLabelsAndPriceTagsFromDocuments";
		PrintCommand.ID = "LabelsPrintingFromSupplierInvoice";
		PrintCommand.Presentation = NStr("en = 'Labels'; ru = 'Этикетки';pl = 'Etykiety';es_ES = 'Etiquetas';es_CO = 'Etiquetas';tr = 'Etiketler';it = 'Etichette';de = 'Etiketten'");
		PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
		PrintCommand.CheckPostingBeforePrint = False;
		PrintCommand.Order = 2;
		
		PrintCommand = PrintCommands.Add();
		PrintCommand.Handler = "DriveClient.PrintLabelsAndPriceTagsFromDocuments";
		PrintCommand.ID = "PriceTagsPrintingFromSupplierInvoice";
		PrintCommand.Presentation = NStr("en = 'Price tags'; ru = 'Ценники';pl = 'Cenniki';es_ES = 'Etiquetas de precio';es_CO = 'Etiquetas de precio';tr = 'Fiyat etiketleri';it = 'Cartellini di prezzo';de = 'Preisschilder'");
		PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
		PrintCommand.CheckPostingBeforePrint = False;
		PrintCommand.Order = 3;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

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