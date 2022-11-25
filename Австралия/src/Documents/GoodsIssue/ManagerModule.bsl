#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region InventoryOwnership

Function InventoryOwnershipParameters(DocObject) Export
	
	Parameters = New Structure;
	
	Parameters.Insert("TableName", "Products");
	
	If DocObject.OperationType = Enums.OperationTypesGoodsIssue.ReturnToAThirdParty Then
		
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.CounterpartysInventory);
		Parameters.Insert("Counterparty", DocObject.Counterparty);
		Parameters.Insert("Contract", DocObject.Contract);
	
	ElsIf DocObject.OperationType = Enums.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer Then
		
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.CustomerProvidedInventory);
		Parameters.Insert("Counterparty", DocObject.Counterparty);
		Parameters.Insert("Contract", DocObject.Contract);
		
	ElsIf DocObject.OperationType = Enums.OperationTypesGoodsIssue.SaleToCustomer Then
		
		Parameters.Insert("OwnershipTableName", "ProductsOwnership");
		
		AmountFields = New Array;
		AmountFields.Add("Amount");
		AmountFields.Add("VATAmount");
		AmountFields.Add("Total");
		Parameters.Insert("AmountFields", AmountFields);
		
		HeaderFields = New Structure;
		HeaderFields.Insert("Company", "Company");
		HeaderFields.Insert("StructuralUnit", "StructuralUnit");
		HeaderFields.Insert("Cell", "Cell");
		Parameters.Insert("HeaderFields", HeaderFields);
		
		// for consistency check between Inventory and Inventory ownership fields
		NotUsedFields = New Array;
		NotUsedFields.Add("ConnectionKey");
		NotUsedFields.Add("SerialNumbers");
		Parameters.Insert("NotUsedFields", NotUsedFields);
		
	ElsIf DocObject.OperationType = Enums.OperationTypesGoodsIssue.TransferToSubcontractingCustomer Then
		
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.CustomerOwnedInventory);
		Parameters.Insert("Counterparty", DocObject.Counterparty);
		Parameters.Insert("Contract", DocObject.Contract);
		
	ElsIf DocObject.OperationType = Enums.OperationTypesGoodsIssue.TransferToSubcontractor
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
	
	If DocObject.OperationType = Enums.OperationTypesGoodsIssue.SaleToCustomer
		Or DocObject.OperationType = Enums.OperationTypesGoodsIssue.DropShipping
		Or DocObject.OperationType = Enums.OperationTypesGoodsIssue.TransferToAThirdParty Then
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.StructuralUnit);
		WarehouseData.Insert("TrackingArea", "Outbound_SalesToCustomer");
		
		Warehouses.Add(WarehouseData);
		
	ElsIf DocObject.OperationType = Enums.OperationTypesGoodsIssue.ReturnToAThirdParty
		Or DocObject.OperationType = Enums.OperationTypesGoodsIssue.PurchaseReturn Then
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.StructuralUnit);
		WarehouseData.Insert("TrackingArea", "Outbound_PurchaseReturn");
		
		Warehouses.Add(WarehouseData);
		
	ElsIf DocObject.OperationType = Enums.OperationTypesGoodsIssue.IntraCommunityTransfer
		Or DocObject.OperationType = Enums.OperationTypesGoodsIssue.TransferToSubcontractor Then
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.StructuralUnit);
		WarehouseData.Insert("TrackingArea", "Outbound_Transfer");
		
		Warehouses.Add(WarehouseData);
		
	EndIf;
	
	Parameters.Insert("Warehouses", Warehouses);
	
	Return Parameters;
	
EndFunction

#EndRegion

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

#Region ProgramInterface

Procedure FillByDebitNotes(DocumentData, FilterData, Products) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	DebitNote.Ref AS Ref,
	|	DebitNote.PointInTime AS PointInTime,
	|	DebitNote.Contract AS Contract
	|INTO TT_DebitNotes
	|FROM
	|	Document.DebitNote AS DebitNote
	|WHERE
	|	&DebitNotesConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CASE
	|		WHEN GoodsIssueProducts.Order = VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|				OR GoodsIssueProducts.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR GoodsIssueProducts.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE GoodsIssueProducts.Order
	|	END AS Order,
	|	GoodsIssueProducts.DebitNote AS DebitNote,
	|	GoodsIssueProducts.Products AS Products,
	|	GoodsIssueProducts.Characteristic AS Characteristic,
	|	GoodsIssueProducts.Batch AS Batch,
	|	SUM(GoodsIssueProducts.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyIssued
	|FROM
	|	Document.GoodsIssue.Products AS GoodsIssueProducts
	|		INNER JOIN TT_DebitNotes AS TT_DebitNotes
	|		ON GoodsIssueProducts.DebitNote = TT_DebitNotes.Ref
	|		INNER JOIN Document.GoodsIssue AS GoodsIssue
	|		ON GoodsIssueProducts.Ref = GoodsIssue.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON GoodsIssueProducts.MeasurementUnit = UOM.Ref
	|WHERE
	|	GoodsIssue.Posted
	|	AND GoodsIssueProducts.Ref <> &Ref
	|
	|GROUP BY
	|	GoodsIssueProducts.Batch,
	|	GoodsIssueProducts.Order,
	|	GoodsIssueProducts.Products,
	|	GoodsIssueProducts.Characteristic,
	|	GoodsIssueProducts.DebitNote
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DebitNoteBalance.PurchaseOrder AS PurchaseOrder,
	|	DebitNoteBalance.DebitNote AS DebitNote,
	|	DebitNoteBalance.Products AS Products,
	|	DebitNoteBalance.Characteristic AS Characteristic,
	|	DebitNoteBalance.Batch AS Batch,
	|	SUM(DebitNoteBalance.Quantity) AS QuantityBalance
	|INTO TT_DebitNoteBalance
	|FROM
	|	(SELECT
	|		Purchases.PurchaseOrder AS PurchaseOrder,
	|		Purchases.Recorder AS DebitNote,
	|		Purchases.Products AS Products,
	|		Purchases.Characteristic AS Characteristic,
	|		Purchases.Batch AS Batch,
	|		-Purchases.Quantity AS Quantity
	|	FROM
	|		AccumulationRegister.Purchases AS Purchases
	|	WHERE
	|		Purchases.Recorder IN
	|				(SELECT
	|					TT_DebitNotes.Ref AS Ref
	|				FROM
	|					TT_DebitNotes AS TT_DebitNotes)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CASE
	|			WHEN GoodsIssueProducts.Order = VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|					OR GoodsIssueProducts.Order = VALUE(Document.SalesOrder.EmptyRef)
	|					OR GoodsIssueProducts.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|				THEN UNDEFINED
	|			ELSE GoodsIssueProducts.Order
	|		END,
	|		GoodsIssueProducts.DebitNote,
	|		GoodsIssueProducts.Products,
	|		GoodsIssueProducts.Characteristic,
	|		GoodsIssueProducts.Batch,
	|		-GoodsIssueProducts.Quantity
	|	FROM
	|		Document.GoodsIssue.Products AS GoodsIssueProducts
	|	WHERE
	|		GoodsIssueProducts.Ref.Posted
	|		AND GoodsIssueProducts.DebitNote IN
	|				(SELECT
	|					TT_DebitNotes.Ref AS Ref
	|				FROM
	|					TT_DebitNotes AS TT_DebitNotes)) AS DebitNoteBalance
	|
	|GROUP BY
	|	DebitNoteBalance.PurchaseOrder,
	|	DebitNoteBalance.DebitNote,
	|	DebitNoteBalance.Products,
	|	DebitNoteBalance.Characteristic,
	|	DebitNoteBalance.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DebitNoteInventory.LineNumber AS LineNumber,
	|	DebitNoteInventory.Products AS Products,
	|	DebitNoteInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ProductsTypeInventory,
	|	DebitNoteInventory.Characteristic AS Characteristic,
	|	DebitNoteInventory.Batch AS Batch,
	|	DebitNoteInventory.Quantity AS Quantity,
	|	DebitNoteInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	DebitNoteInventory.Ref AS DebitNote,
	|	CASE
	|		WHEN DebitNoteInventory.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DebitNoteInventory.Order
	|	END AS Order,
	|	TT_DebitNotes.PointInTime AS PointInTime,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DebitNoteInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DebitNoteInventory.VATInputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATInputGLAccount,
	|	DebitNoteInventory.Price AS Price,
	|	DebitNoteInventory.VATRate AS VATRate,
	|	DebitNoteInventory.InitialAmount AS InitialAmount,
	|	DebitNoteInventory.InitialQuantity AS InitialQuantity,
	|	DebitNoteInventory.SupplierInvoice AS SupplierInvoice,
	|	DebitNoteInventory.Amount AS Amount,
	|	DebitNoteInventory.VATAmount AS VATAmount,
	|	DebitNoteInventory.Total AS Total,
	|	TT_DebitNotes.Contract AS Contract,
	|	DebitNoteInventory.Project AS Project
	|INTO TT_Inventory
	|FROM
	|	Document.DebitNote.Inventory AS DebitNoteInventory
	|		INNER JOIN TT_DebitNotes AS TT_DebitNotes
	|		ON DebitNoteInventory.Ref = TT_DebitNotes.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON DebitNoteInventory.MeasurementUnit = UOM.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	TT_Inventory.Order AS Order,
	|	TT_Inventory.DebitNote AS DebitNote,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor AS BaseQuantity,
	|	SUM(TT_InventoryCumulative.Quantity * TT_InventoryCumulative.Factor) AS BaseQuantityCumulative,
	|	TT_InventoryCumulative.Price AS Price,
	|	TT_InventoryCumulative.VATRate AS VATRate,
	|	SUM(TT_Inventory.InitialAmount) AS InitialAmount,
	|	SUM(TT_Inventory.InitialQuantity) AS InitialQuantity,
	|	TT_Inventory.SupplierInvoice AS SupplierInvoice,
	|	SUM(TT_InventoryCumulative.Amount) AS Amount,
	|	SUM(TT_InventoryCumulative.VATAmount) AS VATAmount,
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
	|			AND TT_Inventory.DebitNote = TT_InventoryCumulative.DebitNote
	|			AND TT_Inventory.LineNumber >= TT_InventoryCumulative.LineNumber
	|			AND TT_Inventory.Project = TT_InventoryCumulative.Project
	|
	|GROUP BY
	|	TT_Inventory.LineNumber,
	|	TT_Inventory.Products,
	|	TT_Inventory.Characteristic,
	|	TT_Inventory.Batch,
	|	TT_Inventory.Order,
	|	TT_Inventory.DebitNote,
	|	TT_Inventory.Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor,
	|	TT_InventoryCumulative.Price,
	|	TT_InventoryCumulative.VATRate,
	|	TT_Inventory.SupplierInvoice,
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
	|	TT_InventoryCumulative.DebitNote AS DebitNote,
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
	|	TT_InventoryCumulative.SupplierInvoice AS SupplierInvoice,
	|	TT_InventoryCumulative.Amount AS Amount,
	|	TT_InventoryCumulative.VATAmount AS VATAmount,
	|	TT_InventoryCumulative.Total AS Total,
	|	TT_InventoryCumulative.Project AS Project
	|INTO TT_InventoryNotYetInvoiced
	|FROM
	|	TT_InventoryCumulative AS TT_InventoryCumulative
	|		LEFT JOIN TT_AlreadyIssued AS TT_AlreadyIssued
	|		ON TT_InventoryCumulative.Products = TT_AlreadyIssued.Products
	|			AND TT_InventoryCumulative.Characteristic = TT_AlreadyIssued.Characteristic
	|			AND TT_InventoryCumulative.Batch = TT_AlreadyIssued.Batch
	|			AND TT_InventoryCumulative.Order = TT_AlreadyIssued.Order
	|			AND TT_InventoryCumulative.DebitNote = TT_AlreadyIssued.DebitNote
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
	|	TT_InventoryNotYetInvoiced.DebitNote AS DebitNote,
	|	TT_InventoryNotYetInvoiced.Factor AS Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity AS BaseQuantity,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.BaseQuantity) AS BaseQuantityCumulative,
	|	TT_InventoryNotYetInvoicedCumulative.Price AS Price,
	|	TT_InventoryNotYetInvoicedCumulative.VATRate AS VATRate,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.InitialAmount) AS InitialAmount,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.InitialQuantity) AS InitialQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.SupplierInvoice AS SupplierInvoice,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.Amount) AS Amount,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.VATAmount) AS VATAmount,
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
	|			AND TT_InventoryNotYetInvoiced.DebitNote = TT_InventoryNotYetInvoicedCumulative.DebitNote
	|			AND TT_InventoryNotYetInvoiced.LineNumber >= TT_InventoryNotYetInvoicedCumulative.LineNumber
	|			AND TT_InventoryNotYetInvoiced.Project = TT_InventoryNotYetInvoicedCumulative.Project
	|
	|GROUP BY
	|	TT_InventoryNotYetInvoiced.LineNumber,
	|	TT_InventoryNotYetInvoiced.Products,
	|	TT_InventoryNotYetInvoiced.Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch,
	|	TT_InventoryNotYetInvoiced.Order,
	|	TT_InventoryNotYetInvoiced.DebitNote,
	|	TT_InventoryNotYetInvoiced.Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.Price,
	|	TT_InventoryNotYetInvoicedCumulative.VATRate,
	|	TT_InventoryNotYetInvoicedCumulative.SupplierInvoice,
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
	|	TT_InventoryNotYetInvoicedCumulative.DebitNote AS DebitNote,
	|	TT_InventoryNotYetInvoicedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_DebitNoteBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|		WHEN TT_DebitNoteBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|			THEN TT_DebitNoteBalance.QuantityBalance - (TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity)
	|	END AS BaseQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.Price AS Price,
	|	TT_InventoryNotYetInvoicedCumulative.VATRate AS VATRate,
	|	TT_InventoryNotYetInvoicedCumulative.InitialAmount AS InitialAmount,
	|	TT_InventoryNotYetInvoicedCumulative.InitialQuantity AS InitialQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.SupplierInvoice AS SupplierInvoice,
	|	TT_InventoryNotYetInvoicedCumulative.Amount AS Amount,
	|	TT_InventoryNotYetInvoicedCumulative.VATAmount AS VATAmount,
	|	TT_InventoryNotYetInvoicedCumulative.Total AS Total,
	|	TT_InventoryNotYetInvoicedCumulative.Project AS Project
	|INTO TT_InventoryToBeInvoiced
	|FROM
	|	TT_InventoryNotYetInvoicedCumulative AS TT_InventoryNotYetInvoicedCumulative
	|		INNER JOIN TT_DebitNoteBalance AS TT_DebitNoteBalance
	|		ON TT_InventoryNotYetInvoicedCumulative.Products = TT_DebitNoteBalance.Products
	|			AND TT_InventoryNotYetInvoicedCumulative.Characteristic = TT_DebitNoteBalance.Characteristic
	|			AND TT_InventoryNotYetInvoicedCumulative.Batch = TT_DebitNoteBalance.Batch
	|			AND TT_InventoryNotYetInvoicedCumulative.Order = TT_DebitNoteBalance.PurchaseOrder
	|			AND TT_InventoryNotYetInvoicedCumulative.DebitNote = TT_DebitNoteBalance.DebitNote
	|WHERE
	|	TT_DebitNoteBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
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
	|	TT_Inventory.DebitNote AS DebitNote,
	|	TT_Inventory.PointInTime AS PointInTime,
	|	TT_InventoryToBeInvoiced.Price AS Price,
	|	CASE
	|		WHEN AccountingPolicySliceLast.RegisteredForVAT
	|			THEN ISNULL(TT_InventoryToBeInvoiced.VATRate, CatProducts.VATRate)
	|		ELSE VALUE(Catalog.VATRates.Exempt)
	|	END AS VATRate,
	|	TT_Inventory.InventoryGLAccount AS InventoryGLAccount,
	|	TT_Inventory.VATInputGLAccount AS VATInputGLAccount,
	|	TT_InventoryToBeInvoiced.Price AS InitialPrice,
	|	TT_InventoryToBeInvoiced.InitialAmount AS InitialAmount,
	|	TT_InventoryToBeInvoiced.InitialQuantity AS InitialQuantity,
	|	TT_InventoryToBeInvoiced.SupplierInvoice AS SupplierInvoice,
	|	TT_InventoryToBeInvoiced.Amount AS Amount,
	|	TT_InventoryToBeInvoiced.VATAmount AS VATAmount,
	|	TT_InventoryToBeInvoiced.Total AS Total,
	|	TT_Inventory.Contract AS Contract,
	|	TT_InventoryToBeInvoiced.Project AS Project
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_InventoryToBeInvoiced AS TT_InventoryToBeInvoiced
	|		ON TT_Inventory.LineNumber = TT_InventoryToBeInvoiced.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryToBeInvoiced.Order
	|			AND TT_Inventory.DebitNote = TT_InventoryToBeInvoiced.DebitNote
	|		LEFT JOIN Catalog.Products AS CatProducts
	|		ON TT_Inventory.Products = CatProducts.Ref
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(, Company = &Company) AS AccountingPolicySliceLast
	|		ON (TRUE)
	|WHERE
	|	TT_Inventory.ProductsTypeInventory";
	
	Contract = Undefined;
	
	FilterData.Property("Contract", Contract);
	Query.SetParameter("Contract", Contract);
	
	If FilterData.Property("DebitNotesArray") Then
		FilterString = "DebitNote.Ref IN(&DebitNotesArray)";
		Query.SetParameter("DebitNotesArray", FilterData.DebitNotesArray);
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
			
			FilterString = FilterString + "DebitNote." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
			
		EndDo;
		
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&DebitNotesConditions", FilterString);
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(DocumentData.Company));
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	StructureData = New Structure;
	StructureData.Insert("ObjectParameters", DocumentData);
	
	Products.Clear();
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	While Selection.Next() Do
		
		TabularSectionRow = Products.Add();
		FillPropertyValues(TabularSectionRow, Selection);
		
		TabularSectionRow.Total = TabularSectionRow.Amount + ?(DocumentData.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
		
	EndDo;
		
EndProcedure

Procedure FillBySalesInvoices(DocumentData, FilterData, Products) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Contract AS Contract,
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
	|	GoodsIssueProducts.SalesInvoice AS SalesInvoice,
	|	GoodsIssueProducts.Order AS Order,
	|	GoodsIssueProducts.Products AS Products,
	|	GoodsIssueProducts.Characteristic AS Characteristic,
	|	GoodsIssueProducts.Batch AS Batch,
	|	SUM(GoodsIssueProducts.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyShipped
	|FROM
	|	TT_SalesInvoices AS TT_SalesInvoices
	|		INNER JOIN Document.GoodsIssue.Products AS GoodsIssueProducts
	|		ON TT_SalesInvoices.Ref = GoodsIssueProducts.SalesInvoice
	|		INNER JOIN Document.GoodsIssue AS GoodsIssueDocument
	|		ON (GoodsIssueProducts.Ref = GoodsIssueDocument.Ref)
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (GoodsIssueProducts.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (GoodsIssueProducts.MeasurementUnit = UOM.Ref)
	|WHERE
	|	GoodsIssueDocument.Posted
	|	AND GoodsIssueProducts.Ref <> &Ref
	|	AND ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	GoodsIssueProducts.SalesInvoice,
	|	GoodsIssueProducts.Order,
	|	GoodsIssueProducts.Products,
	|	GoodsIssueProducts.Characteristic,
	|	GoodsIssueProducts.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	InvoicedBalance.SalesInvoice AS SalesInvoice,
	|	InvoicedBalance.Order AS Order,
	|	InvoicedBalance.Products AS Products,
	|	InvoicedBalance.Characteristic AS Characteristic,
	|	SUM(InvoicedBalance.QuantityBalance) AS QuantityBalance
	|INTO TT_InvoicedBalances
	|FROM
	|	(SELECT
	|		InvoicedBalance.SalesInvoice AS SalesInvoice,
	|		InvoicedBalance.SalesOrder AS Order,
	|		InvoicedBalance.Products AS Products,
	|		InvoicedBalance.Characteristic AS Characteristic,
	|		InvoicedBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.GoodsInvoicedNotShipped.Balance(
	|				,
	|				SalesInvoice IN
	|					(SELECT
	|						TT_SalesInvoices.Ref
	|					FROM
	|						TT_SalesInvoices)) AS InvoicedBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecords.SalesInvoice,
	|		DocumentRegisterRecords.SalesOrder,
	|		DocumentRegisterRecords.Products,
	|		DocumentRegisterRecords.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecords.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecords.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.GoodsInvoicedNotShipped AS DocumentRegisterRecords
	|	WHERE
	|		DocumentRegisterRecords.Recorder = &Ref) AS InvoicedBalance
	|
	|GROUP BY
	|	InvoicedBalance.SalesInvoice,
	|	InvoicedBalance.Order,
	|	InvoicedBalance.Products,
	|	InvoicedBalance.Characteristic
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
	|		WHEN SalesInvoiceInventory.Order = UNDEFINED
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		ELSE SalesInvoiceInventory.Order
	|	END AS Order,
	|	TT_SalesInvoices.PointInTime AS PointInTime,
	|	TT_SalesInvoices.Contract AS Contract,
	|	SalesInvoiceInventory.SalesRep AS SalesRep,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SalesInvoiceInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SalesInvoiceInventory.GoodsShippedNotInvoicedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GoodsShippedNotInvoicedGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SalesInvoiceInventory.UnearnedRevenueGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS UnearnedRevenueGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SalesInvoiceInventory.RevenueGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS RevenueGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SalesInvoiceInventory.COGSGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS COGSGLAccount,
	|	SalesInvoiceInventory.BundleProduct AS BundleProduct,
	|	SalesInvoiceInventory.BundleCharacteristic AS BundleCharacteristic,
	|	SalesInvoiceInventory.CostShare AS CostShare,
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
	|	AND SalesInvoiceInventory.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
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
	|	TT_ProductsCumulative.Project AS Project,
	|	CASE
	|		WHEN TT_AlreadyShipped.BaseQuantity > TT_ProductsCumulative.BaseQuantityCumulative - TT_ProductsCumulative.BaseQuantity
	|			THEN TT_ProductsCumulative.BaseQuantityCumulative - TT_AlreadyShipped.BaseQuantity
	|		ELSE TT_ProductsCumulative.BaseQuantity
	|	END AS BaseQuantity
	|INTO TT_ProductsNotYetShipped
	|FROM
	|	TT_ProductsCumulative AS TT_ProductsCumulative
	|		LEFT JOIN TT_AlreadyShipped AS TT_AlreadyShipped
	|		ON TT_ProductsCumulative.Products = TT_AlreadyShipped.Products
	|			AND TT_ProductsCumulative.Characteristic = TT_AlreadyShipped.Characteristic
	|			AND TT_ProductsCumulative.Batch = TT_AlreadyShipped.Batch
	|			AND TT_ProductsCumulative.SalesInvoice = TT_AlreadyShipped.SalesInvoice
	|			AND TT_ProductsCumulative.Order = TT_AlreadyShipped.Order
	|WHERE
	|	ISNULL(TT_AlreadyShipped.BaseQuantity, 0) < TT_ProductsCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsNotYetShipped.LineNumber AS LineNumber,
	|	TT_ProductsNotYetShipped.Products AS Products,
	|	TT_ProductsNotYetShipped.Characteristic AS Characteristic,
	|	TT_ProductsNotYetShipped.Batch AS Batch,
	|	TT_ProductsNotYetShipped.SalesInvoice AS SalesInvoice,
	|	TT_ProductsNotYetShipped.Order AS Order,
	|	TT_ProductsNotYetShipped.Factor AS Factor,
	|	TT_ProductsNotYetShipped.Project AS Project,
	|	TT_ProductsNotYetShipped.BaseQuantity AS BaseQuantity,
	|	SUM(TT_ProductsNotYetShippedCumulative.BaseQuantity) AS BaseQuantityCumulative
	|INTO TT_ProductsNotYetShippedCumulative
	|FROM
	|	TT_ProductsNotYetShipped AS TT_ProductsNotYetShipped
	|		INNER JOIN TT_ProductsNotYetShipped AS TT_ProductsNotYetShippedCumulative
	|		ON TT_ProductsNotYetShipped.Products = TT_ProductsNotYetShippedCumulative.Products
	|			AND TT_ProductsNotYetShipped.Characteristic = TT_ProductsNotYetShippedCumulative.Characteristic
	|			AND TT_ProductsNotYetShipped.Batch = TT_ProductsNotYetShippedCumulative.Batch
	|			AND TT_ProductsNotYetShipped.SalesInvoice = TT_ProductsNotYetShippedCumulative.SalesInvoice
	|			AND TT_ProductsNotYetShipped.Order = TT_ProductsNotYetShippedCumulative.Order
	|			AND TT_ProductsNotYetShipped.LineNumber >= TT_ProductsNotYetShippedCumulative.LineNumber
	|			AND TT_ProductsNotYetShipped.Project = TT_ProductsNotYetShippedCumulative.Project
	|
	|GROUP BY
	|	TT_ProductsNotYetShipped.LineNumber,
	|	TT_ProductsNotYetShipped.Products,
	|	TT_ProductsNotYetShipped.Characteristic,
	|	TT_ProductsNotYetShipped.Batch,
	|	TT_ProductsNotYetShipped.SalesInvoice,
	|	TT_ProductsNotYetShipped.Order,
	|	TT_ProductsNotYetShipped.Factor,
	|	TT_ProductsNotYetShipped.BaseQuantity,
	|	TT_ProductsNotYetShipped.Project
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsNotYetShippedCumulative.LineNumber AS LineNumber,
	|	TT_ProductsNotYetShippedCumulative.Products AS Products,
	|	TT_ProductsNotYetShippedCumulative.Characteristic AS Characteristic,
	|	TT_ProductsNotYetShippedCumulative.Batch AS Batch,
	|	TT_ProductsNotYetShippedCumulative.SalesInvoice AS SalesInvoice,
	|	TT_ProductsNotYetShippedCumulative.Order AS Order,
	|	TT_ProductsNotYetShippedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_InvoicedBalances.QuantityBalance > TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative
	|			THEN TT_ProductsNotYetShippedCumulative.BaseQuantity
	|		WHEN TT_InvoicedBalances.QuantityBalance > TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative - TT_ProductsNotYetShippedCumulative.BaseQuantity
	|			THEN TT_InvoicedBalances.QuantityBalance - (TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative - TT_ProductsNotYetShippedCumulative.BaseQuantity)
	|	END AS BaseQuantity,
	|	TT_ProductsNotYetShippedCumulative.Project AS Project
	|INTO TT_ProductsToBeShipped
	|FROM
	|	TT_ProductsNotYetShippedCumulative AS TT_ProductsNotYetShippedCumulative
	|		INNER JOIN TT_InvoicedBalances AS TT_InvoicedBalances
	|		ON TT_ProductsNotYetShippedCumulative.Products = TT_InvoicedBalances.Products
	|			AND TT_ProductsNotYetShippedCumulative.Characteristic = TT_InvoicedBalances.Characteristic
	|			AND TT_ProductsNotYetShippedCumulative.SalesInvoice = TT_InvoicedBalances.SalesInvoice
	|			AND TT_ProductsNotYetShippedCumulative.Order = TT_InvoicedBalances.Order
	|WHERE
	|	TT_InvoicedBalances.QuantityBalance > TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative - TT_ProductsNotYetShippedCumulative.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	TT_Products.Batch AS Batch,
	|	CASE
	|		WHEN (CAST(TT_Products.Quantity * TT_Products.Factor AS NUMBER(15, 3))) = TT_ProductsToBeShipped.BaseQuantity
	|			THEN TT_Products.Quantity
	|		ELSE CAST(TT_ProductsToBeShipped.BaseQuantity / TT_Products.Factor AS NUMBER(15, 3))
	|	END AS Quantity,
	|	TT_Products.MeasurementUnit AS MeasurementUnit,
	|	TT_Products.Factor AS Factor,
	|	TT_Products.SalesInvoice AS SalesInvoice,
	|	TT_Products.Order AS Order,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssue,
	|	TT_Products.PointInTime AS PointInTime,
	|	TT_Products.Contract AS Contract,
	|	TT_Products.SalesRep AS SalesRep,
	|	TT_Products.InventoryGLAccount AS InventoryGLAccount,
	|	TT_Products.GoodsShippedNotInvoicedGLAccount AS GoodsShippedNotInvoicedGLAccount,
	|	TT_Products.UnearnedRevenueGLAccount AS UnearnedRevenueGLAccount,
	|	TT_Products.RevenueGLAccount AS RevenueGLAccount,
	|	TT_Products.COGSGLAccount AS COGSGLAccount,
	|	TT_Products.BundleProduct AS BundleProduct,
	|	TT_Products.BundleCharacteristic AS BundleCharacteristic,
	|	TT_Products.CostShare AS CostShare,
	|	TT_Products.Project AS Project
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_ProductsToBeShipped AS TT_ProductsToBeShipped
	|		ON TT_Products.LineNumber = TT_ProductsToBeShipped.LineNumber
	|			AND TT_Products.SalesInvoice = TT_ProductsToBeShipped.SalesInvoice
	|
	|ORDER BY
	|	PointInTime,
	|	LineNumber";
	
	If FilterData.Property("InvoicesArray") Then
		FilterString = "SalesInvoice.Ref IN(&InvoicesArray)";
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
			
			FilterString = FilterString + "SalesInvoice." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
			
		EndDo;
		
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&SalesInvoicesConditions", FilterString);
	
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(DocumentData.Company));
	Query.SetParameter("StructuralUnit", DocumentData.StructuralUnit);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	StructureData = New Structure;
	StructureData.Insert("ObjectParameters", DocumentData);
	
	ResultTable = Query.Execute().Unload();
	For Each ResultTableRow In ResultTable Do
		NewRow = Products.Add();
		FillPropertyValues(NewRow, ResultTableRow);
	EndDo;
		
EndProcedure

Procedure FillBySalesOrders(DocumentData, FilterData, Products, SerialNumbers = Undefined, IsDropShipping = False) Export
	
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
	|	VALUE(Catalog.CounterpartyContracts.EmptyRef) AS Contract,
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
	|	SalesOrder.Contract AS Contract,
	|	SalesOrder.PointInTime AS PointInTime
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
	|	PackingSlipInventory.Contract,
	|	PackingSlipInventory.PointInTime
	|FROM
	|	PackingSlipInventory AS PackingSlipInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsIssueProducts.Order AS Order,
	|	GoodsIssueProducts.Products AS Products,
	|	GoodsIssueProducts.Characteristic AS Characteristic,
	|	GoodsIssueProducts.Batch AS Batch,
	|	SUM(GoodsIssueProducts.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyShipped
	|FROM
	|	Document.GoodsIssue.Products AS GoodsIssueProducts
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON GoodsIssueProducts.Order = TT_SalesOrders.Ref
	|		INNER JOIN Document.GoodsIssue AS GoodsIssueDocument
	|		ON GoodsIssueProducts.Ref = GoodsIssueDocument.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON GoodsIssueProducts.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON GoodsIssueProducts.MeasurementUnit = UOM.Ref
	|WHERE
	|	GoodsIssueDocument.Posted
	|	AND GoodsIssueProducts.Ref <> &Ref
	|	AND ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	GoodsIssueProducts.Batch,
	|	GoodsIssueProducts.Order,
	|	GoodsIssueProducts.Products,
	|	GoodsIssueProducts.Characteristic
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
	|		OrdersBalance.QuantityBalance - OrdersBalance.DropShippingQuantityBalance AS QuantityBalance
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
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON OrdersBalance.Products = ProductsCatalog.Ref
	|WHERE
	|	ProductsCatalog.ProductsType IN (VALUE(Enum.ProductsTypes.InventoryItem), VALUE(Enum.ProductsTypes.Service))
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
	|	TT_SalesOrders.Contract AS Contract,
	|	SalesOrderInventory.BundleProduct AS BundleProduct,
	|	SalesOrderInventory.BundleCharacteristic AS BundleCharacteristic,
	|	SalesOrderInventory.CostShare AS CostShare,
	|	ProductsCatalog.UseSerialNumbers AS UseSerialNumbers,
	|	SalesOrderInventory.ConnectionKey AS ConnectionKey,
	|	VALUE(Document.PackingSlip.EmptyRef) AS PackingSlip,
	|	SalesOrderInventory.Project AS Project
	|INTO TT_Products
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON SalesOrderInventory.Ref = TT_SalesOrders.Ref
	|			AND (&PackingSlip = VALUE(Document.PackingSlip.EmptyRef))
	|			AND &DropShippingCondition
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SalesOrderInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesOrderInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|UNION ALL
	|
	|SELECT
	|	PackingSlipInventory.LineNumber,
	|	PackingSlipInventory.Products,
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
	|	PackingSlipInventory.Contract,
	|	ISNULL(SalesOrderInventory.BundleProduct, VALUE(Catalog.Products.EmptyRef)),
	|	ISNULL(SalesOrderInventory.BundleCharacteristic, VALUE(Catalog.ProductsCharacteristics.EmptyRef)),
	|	CASE
	|		WHEN ISNULL(SalesOrderInventory.Quantity, 0) = 0
	|			THEN 0
	|		ELSE (CAST(ISNULL(SalesOrderInventory.CostShare, 0) / SalesOrderInventory.Quantity AS NUMBER(15, 2))) * PackingSlipInventory.Quantity
	|	END,
	|	ProductsCatalog.UseSerialNumbers,
	|	PackingSlipInventory.ConnectionKey,
	|	PackingSlipInventory.Ref,
	|	SalesOrderInventory.Project
	|FROM
	|	PackingSlipInventory AS PackingSlipInventory
	|		LEFT JOIN Document.SalesOrder.Inventory AS SalesOrderInventory
	|		ON PackingSlipInventory.SalesOrder = SalesOrderInventory.Ref
	|			AND PackingSlipInventory.Products = SalesOrderInventory.Products
	|			AND PackingSlipInventory.Characteristic = SalesOrderInventory.Characteristic
	|			AND PackingSlipInventory.Batch = SalesOrderInventory.Batch
	|		LEFT JOIN Catalog.Products AS ProductsCatalog
	|		ON PackingSlipInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON PackingSlipInventory.MeasurementUnit = UOM.Ref
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
	|	SUM(TT_ProductsCumulative.Quantity * TT_ProductsCumulative.Factor) AS BaseQuantityCumulative,
	|	TT_Products.Project AS Project
	|INTO TT_ProductsCumulative
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_Products AS TT_ProductsCumulative
	|		ON TT_Products.Products = TT_ProductsCumulative.Products
	|			AND TT_Products.Characteristic = TT_ProductsCumulative.Characteristic
	|			AND TT_Products.Batch = TT_ProductsCumulative.Batch
	|			AND TT_Products.Order = TT_ProductsCumulative.Order
	|			AND TT_Products.LineNumber >= TT_ProductsCumulative.LineNumber
	|			AND TT_Products.Project = TT_ProductsCumulative.Project
	|
	|GROUP BY
	|	TT_Products.LineNumber,
	|	TT_Products.Products,
	|	TT_Products.Characteristic,
	|	TT_Products.Batch,
	|	TT_Products.Order,
	|	TT_Products.Factor,
	|	TT_Products.Quantity * TT_Products.Factor,
	|	TT_Products.Project
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
	|		WHEN TT_AlreadyShipped.BaseQuantity > TT_ProductsCumulative.BaseQuantityCumulative - TT_ProductsCumulative.BaseQuantity
	|			THEN TT_ProductsCumulative.BaseQuantityCumulative - TT_AlreadyShipped.BaseQuantity
	|		ELSE TT_ProductsCumulative.BaseQuantity
	|	END AS BaseQuantity,
	|	TT_ProductsCumulative.Project AS Project
	|INTO TT_ProductsNotYetShipped
	|FROM
	|	TT_ProductsCumulative AS TT_ProductsCumulative
	|		LEFT JOIN TT_AlreadyShipped AS TT_AlreadyShipped
	|		ON TT_ProductsCumulative.Products = TT_AlreadyShipped.Products
	|			AND TT_ProductsCumulative.Characteristic = TT_AlreadyShipped.Characteristic
	|			AND TT_ProductsCumulative.Batch = TT_AlreadyShipped.Batch
	|			AND TT_ProductsCumulative.Order = TT_AlreadyShipped.Order
	|WHERE
	|	ISNULL(TT_AlreadyShipped.BaseQuantity, 0) < TT_ProductsCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsNotYetShipped.LineNumber AS LineNumber,
	|	TT_ProductsNotYetShipped.Products AS Products,
	|	TT_ProductsNotYetShipped.Characteristic AS Characteristic,
	|	TT_ProductsNotYetShipped.Batch AS Batch,
	|	TT_ProductsNotYetShipped.Order AS Order,
	|	TT_ProductsNotYetShipped.Factor AS Factor,
	|	TT_ProductsNotYetShipped.BaseQuantity AS BaseQuantity,
	|	SUM(TT_ProductsNotYetShippedCumulative.BaseQuantity) AS BaseQuantityCumulative,
	|	TT_ProductsNotYetShipped.Project AS Project
	|INTO TT_ProductsNotYetShippedCumulative
	|FROM
	|	TT_ProductsNotYetShipped AS TT_ProductsNotYetShipped
	|		INNER JOIN TT_ProductsNotYetShipped AS TT_ProductsNotYetShippedCumulative
	|		ON TT_ProductsNotYetShipped.Products = TT_ProductsNotYetShippedCumulative.Products
	|			AND TT_ProductsNotYetShipped.Characteristic = TT_ProductsNotYetShippedCumulative.Characteristic
	|			AND TT_ProductsNotYetShipped.Batch = TT_ProductsNotYetShippedCumulative.Batch
	|			AND TT_ProductsNotYetShipped.Order = TT_ProductsNotYetShippedCumulative.Order
	|			AND TT_ProductsNotYetShipped.LineNumber >= TT_ProductsNotYetShippedCumulative.LineNumber
	|			AND TT_ProductsNotYetShipped.Project = TT_ProductsNotYetShippedCumulative.Project
	|
	|GROUP BY
	|	TT_ProductsNotYetShipped.LineNumber,
	|	TT_ProductsNotYetShipped.Products,
	|	TT_ProductsNotYetShipped.Characteristic,
	|	TT_ProductsNotYetShipped.Batch,
	|	TT_ProductsNotYetShipped.Order,
	|	TT_ProductsNotYetShipped.Factor,
	|	TT_ProductsNotYetShipped.BaseQuantity,
	|	TT_ProductsNotYetShipped.Project
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsNotYetShippedCumulative.LineNumber AS LineNumber,
	|	TT_ProductsNotYetShippedCumulative.Products AS Products,
	|	TT_ProductsNotYetShippedCumulative.Characteristic AS Characteristic,
	|	TT_ProductsNotYetShippedCumulative.Batch AS Batch,
	|	TT_ProductsNotYetShippedCumulative.Order AS Order,
	|	TT_ProductsNotYetShippedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative
	|			THEN TT_ProductsNotYetShippedCumulative.BaseQuantity
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative - TT_ProductsNotYetShippedCumulative.BaseQuantity
	|			THEN TT_OrdersBalances.QuantityBalance - (TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative - TT_ProductsNotYetShippedCumulative.BaseQuantity)
	|	END AS BaseQuantity,
	|	TT_ProductsNotYetShippedCumulative.Project AS Project
	|INTO TT_ProductsToBeShipped
	|FROM
	|	TT_ProductsNotYetShippedCumulative AS TT_ProductsNotYetShippedCumulative
	|		INNER JOIN TT_OrdersBalances AS TT_OrdersBalances
	|		ON TT_ProductsNotYetShippedCumulative.Products = TT_OrdersBalances.Products
	|			AND TT_ProductsNotYetShippedCumulative.Characteristic = TT_OrdersBalances.Characteristic
	|			AND TT_ProductsNotYetShippedCumulative.Order = TT_OrdersBalances.SalesOrder
	|			AND (&PackingSlip = VALUE(Document.PackingSlip.EmptyRef))
	|WHERE
	|	TT_OrdersBalances.QuantityBalance > TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative - TT_ProductsNotYetShippedCumulative.BaseQuantity
	|
	|UNION ALL
	|
	|SELECT
	|	TT_ProductsNotYetShippedCumulative.LineNumber,
	|	TT_ProductsNotYetShippedCumulative.Products,
	|	TT_ProductsNotYetShippedCumulative.Characteristic,
	|	TT_ProductsNotYetShippedCumulative.Batch,
	|	TT_ProductsNotYetShippedCumulative.Order,
	|	TT_ProductsNotYetShippedCumulative.Factor,
	|	TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative,
	|	NULL
	|FROM
	|	TT_ProductsNotYetShippedCumulative AS TT_ProductsNotYetShippedCumulative
	|WHERE
	|	&PackingSlip <> VALUE(Document.PackingSlip.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	TT_Products.Batch AS Batch,
	|	CASE
	|		WHEN (CAST(TT_Products.Quantity * TT_Products.Factor AS NUMBER(15, 3))) = TT_ProductsToBeShipped.BaseQuantity
	|			THEN TT_Products.Quantity
	|		ELSE CAST(TT_ProductsToBeShipped.BaseQuantity / TT_Products.Factor AS NUMBER(15, 3))
	|	END AS Quantity,
	|	TT_Products.MeasurementUnit AS MeasurementUnit,
	|	TT_Products.Factor AS Factor,
	|	TT_Products.Order AS Order,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssue,
	|	TT_Products.SerialNumbers AS SerialNumbers,
	|	TT_Products.PointInTime AS PointInTime,
	|	TT_Products.Contract AS Contract,
	|	TT_Products.BundleProduct AS BundleProduct,
	|	TT_Products.BundleCharacteristic AS BundleCharacteristic,
	|	TT_Products.CostShare AS CostShare,
	|	TT_Products.UseSerialNumbers AS UseSerialNumbers,
	|	TT_Products.ConnectionKey AS ConnectionKey,
	|	TT_Products.PackingSlip AS PackingSlip,
	|	TT_Products.Project AS Project
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_ProductsToBeShipped AS TT_ProductsToBeShipped
	|		ON TT_Products.LineNumber = TT_ProductsToBeShipped.LineNumber
	|			AND TT_Products.Order = TT_ProductsToBeShipped.Order
	|
	|ORDER BY
	|	PointInTime,
	|	LineNumber";
	
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
	
	If DocumentData.Property("PackingSlip")
		And ValueIsFilled(DocumentData.PackingSlip) Then
		Query.SetParameter("PackingSlip", DocumentData.PackingSlip);
		Query.Text = DriveServer.GetSerialNumbersQuery(Query.Text, DocumentData.PackingSlip, "PackingSlip");
	Else
		Query.SetParameter("PackingSlip", Documents.PackingSlip.EmptyRef());
		Query.Text = DriveServer.GetSerialNumbersQuery(Query.Text, Documents.SalesOrder.EmptyRef(), "TT_SalesOrders");
	EndIf;
	
	If IsDropShipping Then
		Query.Text = StrReplace(Query.Text, 
			"OrdersBalance.QuantityBalance - OrdersBalance.DropShippingQuantityBalance",
			"OrdersBalance.DropShippingQuantityBalance");
		Query.Text = StrReplace(Query.Text, "&DropShippingCondition", "SalesOrderInventory.DropShipping");
	Else 
		Query.Text = StrReplace(Query.Text, "&DropShippingCondition", "NOT SalesOrderInventory.DropShipping");
	EndIf; 
	
	ResultsArray = Query.ExecuteBatch();	
	Selection = ResultsArray[ResultsArray.UBound()-1].Select();
	SerialNumberTable = ResultsArray[ResultsArray.UBound()].Unload();
	
	While Selection.Next() Do
		
		ProductsRow = Products.Add();
		FillPropertyValues(ProductsRow, Selection, , "ConnectionKey");
		
		If SerialNumberTable.Count() > 0 
			And Selection.UseSerialNumbers Then
			
			SearchStructure = New Structure;
			SearchStructure.Insert("Ref", Selection.PackingSlip);
			SearchStructure.Insert("ConnectionKey", Selection.ConnectionKey);
			
			FillPropertyValues(SearchStructure, Selection);
			
			RowsSerialNumbers = SerialNumberTable.FindRows(SearchStructure);
			
			For Each RowSerialNumber In RowsSerialNumbers Do
				
				WorkWithSerialNumbersClientServer.FillConnectionKey(Products, ProductsRow, "ConnectionKey");
				NewRow = SerialNumbers.Add();
				NewRow.ConnectionKey = ProductsRow.ConnectionKey;
				NewRow.SerialNumber = RowSerialNumber.SerialNumber;

			EndDo;
	
			ProductsRow.SerialNumbers = WorkWithSerialNumbers.StringSerialNumbers(SerialNumbers, ProductsRow.ConnectionKey);

		EndIf;

	EndDo;
	
EndProcedure

Procedure FillBySubcontractorOrders(DocumentData, FilterData, Products) Export
	
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
	|	GoodsIssue.Order AS Order,
	|	GoodsIssue.Ref AS Ref
	|INTO TT_GoodsIssueDocument
	|FROM
	|	TT_SubcontractorOrders AS TT_SubcontractorOrders
	|		INNER JOIN Document.GoodsIssue AS GoodsIssue
	|		ON TT_SubcontractorOrders.Ref = GoodsIssue.Order
	|WHERE
	|	GoodsIssue.Posted
	|	AND GoodsIssue.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractor)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_GoodsIssueDocument.Order AS Order,
	|	GoodsIssueProducts.Products AS Products,
	|	GoodsIssueProducts.Characteristic AS Characteristic,
	|	GoodsIssueProducts.Batch AS Batch,
	|	SUM(GoodsIssueProducts.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyInvoiced
	|FROM
	|	TT_GoodsIssueDocument AS TT_GoodsIssueDocument
	|		INNER JOIN Document.GoodsIssue.Products AS GoodsIssueProducts
	|		ON TT_GoodsIssueDocument.Ref = GoodsIssueProducts.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (GoodsIssueProducts.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (GoodsIssueProducts.MeasurementUnit = UOM.Ref)
	|WHERE
	|	GoodsIssueProducts.Ref <> &Ref
	|	AND ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	GoodsIssueProducts.Batch,
	|	TT_GoodsIssueDocument.Order,
	|	GoodsIssueProducts.Products,
	|	GoodsIssueProducts.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SubcontractComponentsBalance.SubcontractorOrder AS SubcontractorOrder,
	|	SubcontractComponentsBalance.Products AS Products,
	|	SubcontractComponentsBalance.Characteristic AS Characteristic,
	|	SUM(SubcontractComponentsBalance.QuantityBalance) AS QuantityBalance
	|INTO TT_OrdersBalances
	|FROM
	|	(SELECT
	|		SubcontractComponentsBalance.SubcontractorOrder AS SubcontractorOrder,
	|		SubcontractComponentsBalance.Products AS Products,
	|		SubcontractComponentsBalance.Characteristic AS Characteristic,
	|		SubcontractComponentsBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.SubcontractComponents.Balance(
	|				,
	|				SubcontractorOrder IN
	|					(SELECT
	|						TT_SubcontractorOrders.Ref
	|					FROM
	|						TT_SubcontractorOrders)) AS SubcontractComponentsBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsSubcontractComponents.SubcontractorOrder,
	|		DocumentRegisterRecordsSubcontractComponents.Products,
	|		DocumentRegisterRecordsSubcontractComponents.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsSubcontractComponents.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsSubcontractComponents.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsSubcontractComponents.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.SubcontractComponents AS DocumentRegisterRecordsSubcontractComponents
	|	WHERE
	|		DocumentRegisterRecordsSubcontractComponents.Recorder = &Ref) AS SubcontractComponentsBalance
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SubcontractComponentsBalance.Products = ProductsCatalog.Ref
	|WHERE
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	SubcontractComponentsBalance.SubcontractorOrder,
	|	SubcontractComponentsBalance.Products,
	|	SubcontractComponentsBalance.Characteristic
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
	|			AND TT_ProductsNotYetInvoicedCumulative.Order = TT_OrdersBalances.SubcontractorOrder
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

Procedure FillBySalesOrdersWithOrderedProducts(DocumentData, FilterData, Products) Export
	
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
	|	SalesOrder.Contract AS Contract,
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
	|	GoodsIssueProducts.Order AS Order,
	|	GoodsIssueProducts.Products AS Products,
	|	GoodsIssueProducts.Characteristic AS Characteristic,
	|	GoodsIssueProducts.Batch AS Batch,
	|	SUM(GoodsIssueProducts.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyShipped
	|FROM
	|	Document.GoodsIssue.Products AS GoodsIssueProducts
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON GoodsIssueProducts.Order = TT_SalesOrders.Ref
	|		INNER JOIN Document.GoodsIssue AS GoodsIssueDocument
	|		ON GoodsIssueProducts.Ref = GoodsIssueDocument.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON GoodsIssueProducts.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON GoodsIssueProducts.MeasurementUnit = UOM.Ref
	|WHERE
	|	GoodsIssueDocument.Posted
	|	AND GoodsIssueProducts.Ref <> &Ref
	|	AND ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	GoodsIssueProducts.Batch,
	|	GoodsIssueProducts.Order,
	|	GoodsIssueProducts.Products,
	|	GoodsIssueProducts.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	SalesOrderInventory.Products AS Products,
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
	|	TT_SalesOrders.Contract AS Contract,
	|	SalesOrderInventory.BundleProduct AS BundleProduct,
	|	SalesOrderInventory.BundleCharacteristic AS BundleCharacteristic,
	|	SalesOrderInventory.CostShare AS CostShare,
	|	ProductsCatalog.UseSerialNumbers AS UseSerialNumbers,
	|	SalesOrderInventory.ConnectionKey AS ConnectionKey,
	|	SalesOrderInventory.Project AS Project
	|INTO TT_Products
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON SalesOrderInventory.Ref = TT_SalesOrders.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SalesOrderInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesOrderInventory.MeasurementUnit = UOM.Ref
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
	|	SUM(TT_ProductsCumulative.Quantity * TT_ProductsCumulative.Factor) AS BaseQuantityCumulative,
	|	TT_Products.Project AS Project
	|INTO TT_ProductsCumulative
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_Products AS TT_ProductsCumulative
	|		ON TT_Products.Products = TT_ProductsCumulative.Products
	|			AND TT_Products.Characteristic = TT_ProductsCumulative.Characteristic
	|			AND TT_Products.Batch = TT_ProductsCumulative.Batch
	|			AND TT_Products.Order = TT_ProductsCumulative.Order
	|			AND TT_Products.LineNumber >= TT_ProductsCumulative.LineNumber
	|			AND TT_Products.Project = TT_ProductsCumulative.Project
	|
	|GROUP BY
	|	TT_Products.LineNumber,
	|	TT_Products.Products,
	|	TT_Products.Characteristic,
	|	TT_Products.Batch,
	|	TT_Products.Order,
	|	TT_Products.Factor,
	|	TT_Products.Quantity * TT_Products.Factor,
	|	TT_Products.Project
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
	|		WHEN TT_AlreadyShipped.BaseQuantity > TT_ProductsCumulative.BaseQuantityCumulative - TT_ProductsCumulative.BaseQuantity
	|			THEN TT_ProductsCumulative.BaseQuantityCumulative - TT_AlreadyShipped.BaseQuantity
	|		ELSE TT_ProductsCumulative.BaseQuantity
	|	END AS BaseQuantity,
	|	TT_ProductsCumulative.Project AS Project
	|INTO TT_ProductsNotYetShipped
	|FROM
	|	TT_ProductsCumulative AS TT_ProductsCumulative
	|		LEFT JOIN TT_AlreadyShipped AS TT_AlreadyShipped
	|		ON TT_ProductsCumulative.Products = TT_AlreadyShipped.Products
	|			AND TT_ProductsCumulative.Characteristic = TT_AlreadyShipped.Characteristic
	|			AND TT_ProductsCumulative.Batch = TT_AlreadyShipped.Batch
	|			AND TT_ProductsCumulative.Order = TT_AlreadyShipped.Order
	|WHERE
	|	ISNULL(TT_AlreadyShipped.BaseQuantity, 0) < TT_ProductsCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsNotYetShipped.LineNumber AS LineNumber,
	|	TT_ProductsNotYetShipped.Products AS Products,
	|	TT_ProductsNotYetShipped.Characteristic AS Characteristic,
	|	TT_ProductsNotYetShipped.Batch AS Batch,
	|	TT_ProductsNotYetShipped.Order AS Order,
	|	TT_ProductsNotYetShipped.Factor AS Factor,
	|	TT_ProductsNotYetShipped.BaseQuantity AS BaseQuantity,
	|	SUM(TT_ProductsNotYetShippedCumulative.BaseQuantity) AS BaseQuantityCumulative,
	|	TT_ProductsNotYetShipped.Project AS Project
	|INTO TT_ProductsNotYetShippedCumulative
	|FROM
	|	TT_ProductsNotYetShipped AS TT_ProductsNotYetShipped
	|		INNER JOIN TT_ProductsNotYetShipped AS TT_ProductsNotYetShippedCumulative
	|		ON TT_ProductsNotYetShipped.Products = TT_ProductsNotYetShippedCumulative.Products
	|			AND TT_ProductsNotYetShipped.Characteristic = TT_ProductsNotYetShippedCumulative.Characteristic
	|			AND TT_ProductsNotYetShipped.Batch = TT_ProductsNotYetShippedCumulative.Batch
	|			AND TT_ProductsNotYetShipped.Order = TT_ProductsNotYetShippedCumulative.Order
	|			AND TT_ProductsNotYetShipped.LineNumber >= TT_ProductsNotYetShippedCumulative.LineNumber
	|			AND TT_ProductsNotYetShipped.Project = TT_ProductsNotYetShippedCumulative.Project
	|
	|GROUP BY
	|	TT_ProductsNotYetShipped.LineNumber,
	|	TT_ProductsNotYetShipped.Products,
	|	TT_ProductsNotYetShipped.Characteristic,
	|	TT_ProductsNotYetShipped.Batch,
	|	TT_ProductsNotYetShipped.Order,
	|	TT_ProductsNotYetShipped.Factor,
	|	TT_ProductsNotYetShipped.BaseQuantity,
	|	TT_ProductsNotYetShipped.Project
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsNotYetShippedCumulative.LineNumber AS LineNumber,
	|	TT_ProductsNotYetShippedCumulative.Products AS Products,
	|	TT_ProductsNotYetShippedCumulative.Characteristic AS Characteristic,
	|	TT_ProductsNotYetShippedCumulative.Batch AS Batch,
	|	TT_ProductsNotYetShippedCumulative.Order AS Order,
	|	TT_ProductsNotYetShippedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TempOrderedProducts.Quantity > TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative
	|			THEN TT_ProductsNotYetShippedCumulative.BaseQuantity
	|		WHEN TempOrderedProducts.Quantity > TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative - TT_ProductsNotYetShippedCumulative.BaseQuantity
	|			THEN TempOrderedProducts.Quantity - (TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative - TT_ProductsNotYetShippedCumulative.BaseQuantity)
	|	END AS BaseQuantity
	|INTO TT_ProductsToBeShipped
	|FROM
	|	TT_ProductsNotYetShippedCumulative AS TT_ProductsNotYetShippedCumulative
	|		INNER JOIN TempOrderedProducts AS TempOrderedProducts
	|		ON TT_ProductsNotYetShippedCumulative.Products = TempOrderedProducts.Products
	|			AND TT_ProductsNotYetShippedCumulative.Characteristic = TempOrderedProducts.Characteristic
	|			AND TT_ProductsNotYetShippedCumulative.Order = TempOrderedProducts.SalesOrder
	|WHERE
	|	TempOrderedProducts.Quantity > TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative - TT_ProductsNotYetShippedCumulative.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	TT_Products.Batch AS Batch,
	|	CASE
	|		WHEN (CAST(TT_Products.Quantity * TT_Products.Factor AS NUMBER(15, 3))) = TT_ProductsToBeShipped.BaseQuantity
	|			THEN TT_Products.Quantity
	|		ELSE CAST(TT_ProductsToBeShipped.BaseQuantity / TT_Products.Factor AS NUMBER(15, 3))
	|	END AS Quantity,
	|	TT_Products.MeasurementUnit AS MeasurementUnit,
	|	TT_Products.Factor AS Factor,
	|	TT_Products.Order AS Order,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssue,
	|	VALUE(Document.PackingSlip.EmptyRef) AS PackingSlip,
	|	TT_Products.SerialNumbers AS SerialNumbers,
	|	TT_Products.PointInTime AS PointInTime,
	|	TT_Products.Contract AS Contract,
	|	TT_Products.BundleProduct AS BundleProduct,
	|	TT_Products.BundleCharacteristic AS BundleCharacteristic,
	|	TT_Products.CostShare AS CostShare,
	|	TT_Products.UseSerialNumbers AS UseSerialNumbers,
	|	TT_Products.ConnectionKey AS ConnectionKey,
	|	TT_Products.Project AS Project
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_ProductsToBeShipped AS TT_ProductsToBeShipped
	|		ON TT_Products.LineNumber = TT_ProductsToBeShipped.LineNumber
	|			AND TT_Products.Order = TT_ProductsToBeShipped.Order
	|
	|ORDER BY
	|	PointInTime,
	|	LineNumber";
	
	Query.SetParameter("OrdersArray", FilterData.OrdersArray);
	Query.SetParameter("OrderedProducts", FilterData.OrderedProductsTable);
	Query.SetParameter("Ref", DocumentData.Ref);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		ProductsRow = Products.Add();
		FillPropertyValues(ProductsRow, Selection);
		
	EndDo;
	
EndProcedure

Procedure FillReturnBySupplierInvoices(DocumentData, FilterData, Products, DefaultFill = True) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SupplierInvoice.Ref AS Ref,
	|	SupplierInvoice.Contract AS Contract,
	|	SupplierInvoice.PointInTime AS PointInTime
	|INTO TT_SupplierInvoices
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	&SupplierInvoicesConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsIssueProducts.Products AS Products,
	|	GoodsIssueProducts.Characteristic AS Characteristic,
	|	GoodsIssueProducts.Batch AS Batch,
	|	SUM(GoodsIssueProducts.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity,
	|	GoodsIssueProducts.Order AS Order,
	|	GoodsIssueProducts.SupplierInvoice AS SupplierInvoice
	|INTO TT_AlreadyReturned
	|FROM
	|	TT_SupplierInvoices AS TT_SupplierInvoices
	|		INNER JOIN Document.GoodsIssue.Products AS GoodsIssueProducts
	|		ON TT_SupplierInvoices.Ref = GoodsIssueProducts.SupplierInvoice
	|		INNER JOIN Document.GoodsIssue AS GoodsIssueDocument
	|		ON (GoodsIssueProducts.Ref = GoodsIssueDocument.Ref)
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (GoodsIssueProducts.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (GoodsIssueProducts.MeasurementUnit = UOM.Ref)
	|WHERE
	|	GoodsIssueDocument.Posted
	|	AND GoodsIssueProducts.Ref <> &Ref
	|	AND ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	GoodsIssueProducts.Batch,
	|	GoodsIssueProducts.SupplierInvoice,
	|	GoodsIssueProducts.Order,
	|	GoodsIssueProducts.Products,
	|	GoodsIssueProducts.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SupplierInvoiceInventory.LineNumber AS LineNumber,
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
	|	SupplierInvoiceInventory.Amount AS InitialAmount,
	|	SupplierInvoiceInventory.Price AS Price,
	|	SupplierInvoiceInventory.Quantity AS InitialQuantity,
	|	SupplierInvoiceInventory.VATAmount AS InitialVATAmount,
	|	SupplierInvoiceInventory.VATRate AS VATRate,
	|	SupplierInvoiceInventory.Project AS Project
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
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	InvoicedBalance.SupplierInvoice AS SupplierInvoice,
	|	InvoicedBalance.Products AS Products,
	|	InvoicedBalance.Characteristic AS Characteristic,
	|	SUM(InvoicedBalance.Quantity) AS QuantityBalance
	|INTO TT_InvoicedBalances
	|FROM
	|	(SELECT
	|		TT_Products.Products AS Products,
	|		TT_Products.Characteristic AS Characteristic,
	|		TT_Products.Quantity AS Quantity,
	|		TT_Products.SupplierInvoice AS SupplierInvoice
	|	FROM
	|		TT_Products AS TT_Products
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Inventory.Products,
	|		Inventory.Characteristic,
	|		-Inventory.Quantity,
	|		Inventory.SourceDocument
	|	FROM
	|		AccumulationRegister.Inventory AS Inventory
	|	WHERE
	|		Inventory.SourceDocument IN(&InvoicesArray)
	|		AND Inventory.Return) AS InvoicedBalance
	|
	|GROUP BY
	|	InvoicedBalance.SupplierInvoice,
	|	InvoicedBalance.Products,
	|	InvoicedBalance.Characteristic
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
	|	SUM(TT_ProductsCumulative.Quantity * TT_ProductsCumulative.Factor) AS BaseQuantityCumulative,
	|	TT_Products.Price AS Price,
	|	SUM(TT_ProductsCumulative.InitialQuantity) AS InitialQuantity,
	|	SUM(TT_ProductsCumulative.InitialAmount) AS InitialAmount,
	|	SUM(TT_ProductsCumulative.InitialVATAmount) AS InitialVATAmount,
	|	TT_Products.VATRate AS VATRate,
	|	TT_Products.Project AS Project
	|INTO TT_ProductsCumulative
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_Products AS TT_ProductsCumulative
	|		ON TT_Products.Products = TT_ProductsCumulative.Products
	|			AND TT_Products.Characteristic = TT_ProductsCumulative.Characteristic
	|			AND TT_Products.Batch = TT_ProductsCumulative.Batch
	|			AND TT_Products.SupplierInvoice = TT_ProductsCumulative.SupplierInvoice
	|			AND TT_Products.Order = TT_ProductsCumulative.Order
	|			AND TT_Products.Price = TT_ProductsCumulative.Price
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
	|	TT_Products.Quantity * TT_Products.Factor,
	|	TT_Products.Price,
	|	TT_Products.VATRate,
	|	TT_Products.Project
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
	|		WHEN TT_AlreadyReturned.BaseQuantity > TT_ProductsCumulative.BaseQuantityCumulative - TT_ProductsCumulative.BaseQuantity
	|			THEN TT_ProductsCumulative.BaseQuantityCumulative - TT_AlreadyReturned.BaseQuantity
	|		ELSE TT_ProductsCumulative.BaseQuantity
	|	END AS BaseQuantity,
	|	TT_ProductsCumulative.Price AS Price,
	|	TT_ProductsCumulative.InitialQuantity AS InitialQuantity,
	|	TT_ProductsCumulative.InitialAmount AS InitialAmount,
	|	TT_ProductsCumulative.InitialVATAmount AS InitialVATAmount,
	|	TT_ProductsCumulative.VATRate AS VATRate,
	|	TT_ProductsCumulative.Project AS Project
	|INTO TT_ProductsNotYetReceived
	|FROM
	|	TT_ProductsCumulative AS TT_ProductsCumulative
	|		LEFT JOIN TT_AlreadyReturned AS TT_AlreadyReturned
	|		ON TT_ProductsCumulative.Products = TT_AlreadyReturned.Products
	|			AND TT_ProductsCumulative.Characteristic = TT_AlreadyReturned.Characteristic
	|			AND TT_ProductsCumulative.Batch = TT_AlreadyReturned.Batch
	|			AND TT_ProductsCumulative.SupplierInvoice = TT_AlreadyReturned.SupplierInvoice
	|			AND TT_ProductsCumulative.Order = TT_AlreadyReturned.Order
	|WHERE
	|	ISNULL(TT_AlreadyReturned.BaseQuantity, 0) < TT_ProductsCumulative.BaseQuantityCumulative
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
	|	SUM(TT_ProductsNotYetReceivedCumulative.BaseQuantity) AS BaseQuantityCumulative,
	|	TT_ProductsNotYetReceived.Price AS Price,
	|	SUM(TT_ProductsNotYetReceivedCumulative.InitialQuantity) AS InitialQuantity,
	|	SUM(TT_ProductsNotYetReceivedCumulative.InitialAmount) AS InitialAmount,
	|	SUM(TT_ProductsNotYetReceivedCumulative.InitialVATAmount) AS InitialVATAmount,
	|	TT_ProductsNotYetReceived.VATRate AS VATRate
	|INTO TT_ProductsNotYetReceivedCumulative
	|FROM
	|	TT_ProductsNotYetReceived AS TT_ProductsNotYetReceived
	|		INNER JOIN TT_ProductsNotYetReceived AS TT_ProductsNotYetReceivedCumulative
	|		ON TT_ProductsNotYetReceived.Products = TT_ProductsNotYetReceivedCumulative.Products
	|			AND TT_ProductsNotYetReceived.Characteristic = TT_ProductsNotYetReceivedCumulative.Characteristic
	|			AND TT_ProductsNotYetReceived.Batch = TT_ProductsNotYetReceivedCumulative.Batch
	|			AND TT_ProductsNotYetReceived.SupplierInvoice = TT_ProductsNotYetReceivedCumulative.SupplierInvoice
	|			AND TT_ProductsNotYetReceived.Order = TT_ProductsNotYetReceivedCumulative.Order
	|			AND TT_ProductsNotYetReceived.Price = TT_ProductsNotYetReceivedCumulative.Price
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
	|	TT_ProductsNotYetReceived.BaseQuantity,
	|	TT_ProductsNotYetReceived.Price,
	|	TT_ProductsNotYetReceived.VATRate
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
	|	END AS BaseQuantity,
	|	TT_ProductsNotYetReceivedCumulative.Price AS Price,
	|	TT_ProductsNotYetReceivedCumulative.InitialQuantity AS InitialQuantity,
	|	TT_ProductsNotYetReceivedCumulative.InitialAmount AS InitialAmount,
	|	TT_ProductsNotYetReceivedCumulative.InitialVATAmount AS InitialVATAmount,
	|	TT_ProductsNotYetReceivedCumulative.VATRate AS VATRate
	|INTO TT_ProductsToBeReceived
	|FROM
	|	TT_ProductsNotYetReceivedCumulative AS TT_ProductsNotYetReceivedCumulative
	|		INNER JOIN TT_InvoicedBalances AS TT_InvoicedBalances
	|		ON TT_ProductsNotYetReceivedCumulative.Products = TT_InvoicedBalances.Products
	|			AND TT_ProductsNotYetReceivedCumulative.Characteristic = TT_InvoicedBalances.Characteristic
	|			AND TT_ProductsNotYetReceivedCumulative.SupplierInvoice = TT_InvoicedBalances.SupplierInvoice
	|WHERE
	|	TT_InvoicedBalances.QuantityBalance > TT_ProductsNotYetReceivedCumulative.BaseQuantityCumulative - TT_ProductsNotYetReceivedCumulative.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
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
	|	TT_ProductsToBeReceived.Price AS Price,
	|	TT_ProductsToBeReceived.InitialQuantity AS InitialQuantity,
	|	TT_ProductsToBeReceived.InitialAmount AS InitialAmount,
	|	CASE
	|		WHEN TT_ProductsToBeReceived.InitialQuantity = 0
	|			THEN 0
	|		ELSE TT_ProductsToBeReceived.InitialAmount / TT_ProductsToBeReceived.InitialQuantity * TT_ProductsToBeReceived.BaseQuantity
	|	END AS Amount,
	|	CASE
	|		WHEN TT_ProductsToBeReceived.InitialQuantity = 0
	|			THEN 0
	|		ELSE TT_ProductsToBeReceived.InitialVATAmount / TT_ProductsToBeReceived.InitialQuantity * TT_ProductsToBeReceived.BaseQuantity
	|	END AS VATAmount,
	|	TT_ProductsToBeReceived.VATRate AS VATRate,
	|	TT_Products.Project AS Project
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
	
	ResultTable = Query.Execute().Unload();
	For Each ResultTableRow In ResultTable Do
		ProductsRow = Products.Add();
		FillPropertyValues(ProductsRow, ResultTableRow);
		If Not DefaultFill Then
			ProductsRow.SalesInvoice = ResultTableRow.SupplierInvoice;
		EndIf;
	EndDo;
	
EndProcedure

Procedure FillBySupplierInvoices(DocumentObject, DocumentData, FilterData, Products, SerialNumbers) Export
	
	Products.Clear();
	SerialNumbers.Clear();
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SupplierInvoice.Ref AS Ref
	|INTO TT_SupplierInvoices
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	&SupplierInvoicesConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SupplierInvoiceInventory.Products AS Products,
	|	SupplierInvoiceInventory.Characteristic AS Characteristic,
	|	SupplierInvoiceInventory.Batch AS Batch,
	|	SupplierInvoiceInventory.Quantity AS Quantity,
	|	SupplierInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoiceInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	SupplierInvoiceInventory.ConnectionKey AS ConnectionKey,
	|	SupplierInvoiceInventory.Ref AS Ref,
	|	ProductsCatalog.UseSerialNumbers AS UseSerialNumbers
	|INTO TT_Products
	|FROM
	|	TT_SupplierInvoices AS TT_SupplierInvoices
	|		INNER JOIN Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		ON TT_SupplierInvoices.Ref = SupplierInvoiceInventory.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (SupplierInvoiceInventory.Products = ProductsCatalog.Ref)
	|WHERE
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	TT_Products.Batch AS Batch,
	|	SUM(TT_Products.Quantity) AS Quantity,
	|	TT_Products.MeasurementUnit AS MeasurementUnit,
	|	TT_Products.InventoryGLAccount AS InventoryGLAccount,
	|	CASE
	|		WHEN TT_Products.UseSerialNumbers
	|			THEN TT_Products.ConnectionKey
	|		ELSE 0
	|	END AS ConnectionKey,
	|	CASE
	|		WHEN TT_Products.UseSerialNumbers
	|			THEN TT_Products.Ref
	|		ELSE UNDEFINED
	|	END AS Ref,
	|	TT_Products.UseSerialNumbers AS UseSerialNumbers
	|FROM
	|	TT_Products AS TT_Products
	|
	|GROUP BY
	|	TT_Products.Batch,
	|	TT_Products.MeasurementUnit,
	|	TT_Products.UseSerialNumbers,
	|	TT_Products.Characteristic,
	|	TT_Products.Products,
	|	TT_Products.InventoryGLAccount,
	|	CASE
	|		WHEN TT_Products.UseSerialNumbers
	|			THEN TT_Products.Ref
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TT_Products.UseSerialNumbers
	|			THEN TT_Products.ConnectionKey
	|		ELSE 0
	|	END
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
	
	Query.Text = StrReplace(Query.Text, "&SupplierInvoicesConditions", FilterString);
	
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	QueryResults = Query.ExecuteBatch();

	Selection = QueryResults[2].Select();
	
	SerialNumberTable = QueryResults[3].Unload();
	
	While Selection.Next() Do
		
		ProductsRow = Products.Add();
		FillPropertyValues(ProductsRow, Selection, , "ConnectionKey");
		
		If Selection.UseSerialNumbers Then
			
			StructureOfTheSearch = New Structure ("Ref, ConnectionKey");
			FillPropertyValues(StructureOfTheSearch, Selection);
			
			RowsSerialNumbers = SerialNumberTable.FindRows(StructureOfTheSearch);
			
			For Each RowSerialNumber In RowsSerialNumbers Do
				
				WorkWithSerialNumbersClientServer.FillConnectionKey(Products, ProductsRow, "ConnectionKey");
				NewRow = SerialNumbers.Add();
				NewRow.ConnectionKey = ProductsRow.ConnectionKey;
				NewRow.SerialNumber = RowSerialNumber.SerialNumber;
				
			EndDo;
			
			ProductsRow.SerialNumbers = WorkWithSerialNumbers.StringSerialNumbers(SerialNumbers, ProductsRow.ConnectionKey);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure InitializeDocumentData(DocumentRefGoodsIssue, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	ExchangeRatesSliceLast.Currency AS Currency,
	|	ExchangeRatesSliceLast.Rate AS ExchangeRate,
	|	ExchangeRatesSliceLast.Repetition AS Multiplicity
	|INTO TemporaryTableExchangeRatesSliceLatest
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(
	|			&PointInTime,
	|			Currency IN (&PresentationCurrency, &DocumentCurrency)
	|				AND Company = &Company) AS ExchangeRatesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.Date AS Date,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	Header.Counterparty AS Counterparty,
	|	Header.Responsible AS Responsible,
	|	Header.Department AS Department,
	|	CASE
	|		WHEN Header.OperationType = VALUE(Enum.OperationTypesGoodsIssue.DropShipping)
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
	|	Header.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity
	|INTO GoodsIssueHeader
	|FROM
	|	Document.GoodsIssue AS Header
	|WHERE
	|	Header.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsIssueProducts.LineNumber AS LineNumber,
	|	GoodsIssueProducts.Ref AS Document,
	|	GoodsIssueHeader.Responsible AS Responsible,
	|	GoodsIssueHeader.Counterparty AS Counterparty,
	|	CASE
	|		WHEN GoodsIssueHeader.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|			THEN GoodsIssueHeader.Contract
	|		ELSE GoodsIssueProducts.Contract
	|	END AS Contract,
	|	GoodsIssueHeader.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	CatalogLinesOfBusiness.Ref AS BusinessLineSales,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN GoodsIssueProducts.SalesInvoice = VALUE(Document.SalesInvoice.EmptyRef)
	|				AND NOT &ContinentalMethod
	|			THEN GoodsIssueProducts.GoodsShippedNotInvoicedGLAccount
	|		ELSE GoodsIssueProducts.COGSGLAccount
	|	END AS GLAccountCost,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsIssueProducts.RevenueGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountStatementSales,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsIssueProducts.UnearnedRevenueGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountStatementDeferredSales,
	|	GoodsIssueHeader.StructuralUnit AS StructuralUnit,
	|	GoodsIssueHeader.Department AS Department,
	|	GoodsIssueHeader.Cell AS Cell,
	|	CASE
	|		WHEN &ContinentalMethod
	|				AND GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.PurchaseReturn)
	|			THEN GoodsIssueProducts.VATRate
	|		ELSE GoodsIssueProducts.Products.VATRate
	|	END AS VATRate,
	|	GoodsIssueHeader.DocumentCurrency AS DocumentCurrency,
	|	GoodsIssueHeader.ExchangeRate AS ExchangeRate,
	|	GoodsIssueHeader.Multiplicity AS Multiplicity,
	|	GoodsIssueHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	GoodsIssueHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	GoodsIssueProducts.RevenueItem AS RevenueItem,
	|	GoodsIssueProducts.COGSItem AS COGSItem,
	|	GoodsIssueProducts.PurchaseReturnItem AS PurchaseReturnItem,
	|	CASE
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToAThirdParty)
	|			THEN VALUE(Enum.InventoryAccountTypes.ThirdPartyInventory)
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractingCustomer)
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedFinishedProducts)
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer)
	|				OR &IsOrderReceived
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedComponents)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS InventoryAccountType,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToAThirdParty)
	|				OR GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer)
	|			THEN GoodsIssueProducts.InventoryReceivedGLAccount
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractingCustomer)
	|			THEN GoodsIssueProducts.ConsumptionGLAccount
	|		ELSE GoodsIssueProducts.InventoryGLAccount
	|	END AS GLAccount,
	|	GoodsIssueProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN GoodsIssueProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN GoodsIssueProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractor)
	|			THEN GoodsIssueHeader.Order
	|		WHEN GoodsIssueHeader.Order <> UNDEFINED
	|				AND GoodsIssueHeader.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN GoodsIssueHeader.Order
	|		WHEN GoodsIssueProducts.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN GoodsIssueProducts.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	GoodsIssueProducts.SalesInvoice AS SalesInvoice,
	|	CASE
	|		WHEN VALUETYPE(GoodsIssueProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN GoodsIssueProducts.Quantity
	|		ELSE GoodsIssueProducts.Quantity * GoodsIssueProducts.MeasurementUnit.Factor
	|	END AS Quantity,
	|	GoodsIssueProducts.ConnectionKey AS ConnectionKey,
	|	GoodsIssueHeader.OperationType AS OperationType,
	|	CASE
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
	|				OR GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractor)
	|			THEN &Company
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.IntraCommunityTransfer)
	|			THEN &Company
	|		ELSE UNDEFINED
	|	END AS CorrOrganization,
	|	CASE
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
	|				OR GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractor)
	|			THEN &PresentationCurrency
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.IntraCommunityTransfer)
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CorrPresentationCurrency,
	|	CASE
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
	|				OR GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractor)
	|			THEN GoodsIssueHeader.Counterparty
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.IntraCommunityTransfer)
	|			THEN VALUE(Catalog.BusinessUnits.GoodsInTransit)
	|		ELSE UNDEFINED
	|	END AS StructuralUnitCorr,
	|	CASE
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToAThirdParty)
	|			THEN VALUE(Enum.InventoryAccountTypes.ThirdPartyInventory)
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.IntraCommunityTransfer)
	|			THEN VALUE(Enum.InventoryAccountTypes.GoodsInTransit)
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractor)
	|			THEN VALUE(Enum.InventoryAccountTypes.ComponentsForSubcontractor)
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractingCustomer)
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedFinishedProducts)
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer)
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedComponents)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS CorrInventoryAccountType,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.IntraCommunityTransfer)
	|			THEN GoodsIssueProducts.GoodsInTransitGLAccount
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.PurchaseReturn)
	|			THEN GoodsIssueProducts.PurchaseReturnGLAccount
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
	|			THEN GoodsIssueProducts.InventoryTransferredGLAccount
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractor)
	|			THEN GoodsIssueProducts.InventoryTransferredGLAccount
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToAThirdParty)
	|			THEN UNDEFINED
	|		WHEN GoodsIssueProducts.SalesInvoice = VALUE(Document.SalesInvoice.EmptyRef)
	|				AND NOT &ContinentalMethod
	|			THEN GoodsIssueProducts.GoodsShippedNotInvoicedGLAccount
	|		ELSE GoodsIssueProducts.COGSGLAccount
	|	END AS CorrGLAccount,
	|	CASE
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.DropShipping)
	|			THEN CASE
	|					WHEN NOT(GoodsIssueProducts.SalesInvoice = VALUE(Document.SalesInvoice.EmptyRef)
	|								AND NOT &ContinentalMethod)
	|						THEN GoodsIssueProducts.COGSItem
	|					WHEN GoodsIssueProducts.SalesInvoice <> VALUE(Document.SalesInvoice.EmptyRef)
	|						THEN GoodsIssueProducts.RevenueItem
	|					ELSE UNDEFINED
	|				END
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.PurchaseReturn)
	|			THEN GoodsIssueProducts.PurchaseReturnItem
	|		ELSE UNDEFINED
	|	END AS CorrIncomeAndExpenseItem,
	|	CASE
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractor)
	|			THEN GoodsIssueHeader.Order
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
	|			THEN CASE
	|					WHEN GoodsIssueHeader.Order REFS Document.SalesOrder
	|							AND GoodsIssueHeader.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|						THEN GoodsIssueHeader.Order
	|					WHEN GoodsIssueHeader.Order REFS Document.PurchaseOrder
	|							AND GoodsIssueHeader.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|						THEN GoodsIssueHeader.Order
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END AS CorrOrder,
	|	FALSE AS ProductsOnCommission,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsIssueHeader.Counterparty.GLAccountVendorSettlements
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountVendorSettlements,
	|	GoodsIssueProducts.SalesRep AS SalesRep,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsIssueProducts.InventoryTransferredGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryTransferredGLAccount,
	|	GoodsIssueProducts.SupplierInvoice AS SupplierInvoice,
	|	GoodsIssueProducts.Amount AS Amount,
	|	GoodsIssueProducts.Ownership AS Ownership
	|INTO TemporaryTableProductsPrev
	|FROM
	|	GoodsIssueHeader AS GoodsIssueHeader
	|		INNER JOIN Document.GoodsIssue.Products AS GoodsIssueProducts
	|		ON GoodsIssueHeader.Ref = GoodsIssueProducts.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (GoodsIssueProducts.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.LinesOfBusiness AS CatalogLinesOfBusiness
	|		ON (CatalogProducts.BusinessLine = CatalogLinesOfBusiness.Ref)
	|		LEFT JOIN Catalog.InventoryOwnership AS InventoryOwnership
	|		ON (GoodsIssueProducts.Ownership = InventoryOwnership.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON GoodsIssueHeader.StructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|WHERE
	|	NOT GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableProductsPrev.LineNumber AS LineNumber,
	|	TemporaryTableProductsPrev.Document AS Document,
	|	TemporaryTableProductsPrev.Responsible AS Responsible,
	|	TemporaryTableProductsPrev.Counterparty AS Counterparty,
	|	TemporaryTableProductsPrev.Contract AS Contract,
	|	TemporaryTableProductsPrev.Period AS Period,
	|	TemporaryTableProductsPrev.Company AS Company,
	|	TemporaryTableProductsPrev.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableProductsPrev.BusinessLineSales AS BusinessLineSales,
	|	TemporaryTableProductsPrev.GLAccountCost AS GLAccountCost,
	|	TemporaryTableProductsPrev.AccountStatementSales AS AccountStatementSales,
	|	TemporaryTableProductsPrev.AccountStatementDeferredSales AS AccountStatementDeferredSales,
	|	TemporaryTableProductsPrev.StructuralUnit AS StructuralUnit,
	|	TemporaryTableProductsPrev.Department AS Department,
	|	TemporaryTableProductsPrev.Cell AS Cell,
	|	TemporaryTableProductsPrev.VATRate AS VATRate,
	|	TemporaryTableProductsPrev.DocumentCurrency AS DocumentCurrency,
	|	TemporaryTableProductsPrev.ExchangeRate AS ExchangeRate,
	|	TemporaryTableProductsPrev.Multiplicity AS Multiplicity,
	|	TemporaryTableProductsPrev.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	TemporaryTableProductsPrev.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	TemporaryTableProductsPrev.RevenueItem AS RevenueItem,
	|	TemporaryTableProductsPrev.COGSItem AS COGSItem,
	|	TemporaryTableProductsPrev.PurchaseReturnItem AS PurchaseReturnItem,
	|	TemporaryTableProductsPrev.InventoryAccountType AS InventoryAccountType,
	|	TemporaryTableProductsPrev.GLAccount AS GLAccount,
	|	TemporaryTableProductsPrev.Products AS Products,
	|	TemporaryTableProductsPrev.Characteristic AS Characteristic,
	|	TemporaryTableProductsPrev.Batch AS Batch,
	|	TemporaryTableProductsPrev.Order AS Order,
	|	TemporaryTableProductsPrev.SalesInvoice AS SalesInvoice,
	|	TemporaryTableProductsPrev.Quantity AS Quantity,
	|	TemporaryTableProductsPrev.ConnectionKey AS ConnectionKey,
	|	TemporaryTableProductsPrev.OperationType AS OperationType,
	|	TemporaryTableProductsPrev.CorrOrganization AS CorrOrganization,
	|	TemporaryTableProductsPrev.CorrPresentationCurrency AS CorrPresentationCurrency,
	|	TemporaryTableProductsPrev.StructuralUnitCorr AS StructuralUnitCorr,
	|	TemporaryTableProductsPrev.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TemporaryTableProductsPrev.CorrGLAccount AS CorrGLAccount,
	|	TemporaryTableProductsPrev.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	TemporaryTableProductsPrev.CorrOrder AS CorrOrder,
	|	TemporaryTableProductsPrev.ProductsOnCommission AS ProductsOnCommission,
	|	TemporaryTableProductsPrev.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	TemporaryTableProductsPrev.SalesRep AS SalesRep,
	|	TemporaryTableProductsPrev.InventoryTransferredGLAccount AS InventoryTransferredGLAccount,
	|	ISNULL(CounterpartyContracts.SettlementsCurrency, VALUE(Catalog.Currencies.EmptyRef)) AS Currency,
	|	&ContinentalMethod AS ContinentalMethod,
	|	TemporaryTableProductsPrev.SupplierInvoice AS SupplierInvoice,
	|	CAST(TemporaryTableProductsPrev.Amount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(TemporaryTableProductsPrev.Amount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryTableProductsPrev.ExchangeRate * TemporaryTableProductsPrev.ContractCurrencyMultiplicity / (TemporaryTableProductsPrev.ContractCurrencyExchangeRate * TemporaryTableProductsPrev.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (TemporaryTableProductsPrev.ExchangeRate * TemporaryTableProductsPrev.ContractCurrencyMultiplicity / (TemporaryTableProductsPrev.ContractCurrencyExchangeRate * TemporaryTableProductsPrev.Multiplicity))
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	TemporaryTableProductsPrev.Ownership AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject
	|INTO TemporaryTableProducts
	|FROM
	|	TemporaryTableProductsPrev AS TemporaryTableProductsPrev
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON TemporaryTableProductsPrev.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &DocumentCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsIssueProductsOwnership.LineNumber AS LineNumber,
	|	GoodsIssueProductsOwnership.Ref AS Document,
	|	GoodsIssueHeader.Responsible AS Responsible,
	|	GoodsIssueHeader.Counterparty AS Counterparty,
	|	CASE
	|		WHEN GoodsIssueHeader.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|			THEN GoodsIssueHeader.Contract
	|		ELSE GoodsIssueProductsOwnership.Contract
	|	END AS Contract,
	|	GoodsIssueHeader.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	CatalogLinesOfBusiness.Ref AS BusinessLineSales,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN GoodsIssueProductsOwnership.SalesInvoice = VALUE(Document.SalesInvoice.EmptyRef)
	|				AND NOT &ContinentalMethod
	|			THEN GoodsIssueProductsOwnership.GoodsShippedNotInvoicedGLAccount
	|		ELSE GoodsIssueProductsOwnership.COGSGLAccount
	|	END AS GLAccountCost,
	|	GoodsIssueProductsOwnership.RevenueGLAccount AS AccountStatementSales,
	|	GoodsIssueProductsOwnership.UnearnedRevenueGLAccount AS AccountStatementDeferredSales,
	|	GoodsIssueHeader.StructuralUnit AS StructuralUnit,
	|	GoodsIssueHeader.Department AS Department,
	|	GoodsIssueHeader.Cell AS Cell,
	|	GoodsIssueProductsOwnership.Products.VATRate AS VATRate,
	|	GoodsIssueHeader.DocumentCurrency AS DocumentCurrency,
	|	GoodsIssueHeader.ExchangeRate AS ExchangeRate,
	|	GoodsIssueHeader.Multiplicity AS Multiplicity,
	|	GoodsIssueHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	GoodsIssueHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	GoodsIssueProductsOwnership.RevenueItem AS RevenueItem,
	|	GoodsIssueProductsOwnership.COGSItem AS COGSItem,
	|	GoodsIssueProductsOwnership.PurchaseReturnItem AS PurchaseReturnItem,
	|	CASE
	|		WHEN InventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.ThirdPartyInventory)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS InventoryAccountType,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN InventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN GoodsIssueProductsOwnership.InventoryReceivedGLAccount
	|		ELSE GoodsIssueProductsOwnership.InventoryGLAccount
	|	END AS GLAccount,
	|	GoodsIssueProductsOwnership.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN GoodsIssueProductsOwnership.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN GoodsIssueProductsOwnership.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN GoodsIssueHeader.Order <> UNDEFINED
	|				AND GoodsIssueHeader.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN GoodsIssueHeader.Order
	|		WHEN GoodsIssueProductsOwnership.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN GoodsIssueProductsOwnership.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	GoodsIssueProductsOwnership.SalesInvoice AS SalesInvoice,
	|	GoodsIssueProductsOwnership.Quantity AS Quantity,
	|	GoodsIssueHeader.OperationType AS OperationType,
	|	UNDEFINED AS CorrOrganization,
	|	UNDEFINED AS CorrPresentationCurrency,
	|	UNDEFINED AS StructuralUnitCorr,
	|	CASE
	|		WHEN InventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.ThirdPartyInventory)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS CorrInventoryAccountType,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN GoodsIssueProductsOwnership.SalesInvoice = VALUE(Document.SalesInvoice.EmptyRef)
	|				AND NOT &ContinentalMethod
	|			THEN GoodsIssueProductsOwnership.GoodsShippedNotInvoicedGLAccount
	|		ELSE GoodsIssueProductsOwnership.COGSGLAccount
	|	END AS CorrGLAccount,
	|	CASE
	|		WHEN NOT(GoodsIssueProductsOwnership.SalesInvoice = VALUE(Document.SalesInvoice.EmptyRef)
	|					AND NOT &ContinentalMethod)
	|			THEN GoodsIssueProductsOwnership.COGSItem
	|		WHEN GoodsIssueProductsOwnership.SalesInvoice <> VALUE(Document.SalesInvoice.EmptyRef)
	|			THEN GoodsIssueProductsOwnership.RevenueItem
	|		ELSE UNDEFINED
	|	END AS CorrIncomeAndExpenseItem,
	|	UNDEFINED AS CorrOrder,
	|	CASE
	|		WHEN InventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ProductsOnCommission,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsIssueHeader.Counterparty.GLAccountVendorSettlements
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountVendorSettlements,
	|	GoodsIssueProductsOwnership.SalesRep AS SalesRep,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsIssueProductsOwnership.InventoryTransferredGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryTransferredGLAccount,
	|	GoodsIssueProductsOwnership.SupplierInvoice AS SupplierInvoice,
	|	GoodsIssueProductsOwnership.Amount AS Amount,
	|	GoodsIssueProductsOwnership.Ownership AS Ownership,
	|	GoodsIssueProductsOwnership.SerialNumber AS SerialNumber
	|INTO TemporaryTableProductsOwnershipPrev
	|FROM
	|	GoodsIssueHeader AS GoodsIssueHeader
	|		INNER JOIN Document.GoodsIssue.ProductsOwnership AS GoodsIssueProductsOwnership
	|		ON GoodsIssueHeader.Ref = GoodsIssueProductsOwnership.Ref
	|		LEFT JOIN Catalog.InventoryOwnership AS InventoryOwnership
	|		ON (GoodsIssueProductsOwnership.Ownership = InventoryOwnership.Ref)
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (GoodsIssueProductsOwnership.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.LinesOfBusiness AS CatalogLinesOfBusiness
	|		ON (CatalogProducts.BusinessLine = CatalogLinesOfBusiness.Ref)
	|WHERE
	|	GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableProductsOwnershipPrev.LineNumber AS LineNumber,
	|	TemporaryTableProductsOwnershipPrev.Document AS Document,
	|	TemporaryTableProductsOwnershipPrev.Responsible AS Responsible,
	|	TemporaryTableProductsOwnershipPrev.Counterparty AS Counterparty,
	|	TemporaryTableProductsOwnershipPrev.Contract AS Contract,
	|	TemporaryTableProductsOwnershipPrev.Period AS Period,
	|	TemporaryTableProductsOwnershipPrev.Company AS Company,
	|	TemporaryTableProductsOwnershipPrev.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableProductsOwnershipPrev.BusinessLineSales AS BusinessLineSales,
	|	TemporaryTableProductsOwnershipPrev.GLAccountCost AS GLAccountCost,
	|	TemporaryTableProductsOwnershipPrev.AccountStatementSales AS AccountStatementSales,
	|	TemporaryTableProductsOwnershipPrev.AccountStatementDeferredSales AS AccountStatementDeferredSales,
	|	TemporaryTableProductsOwnershipPrev.StructuralUnit AS StructuralUnit,
	|	TemporaryTableProductsOwnershipPrev.Department AS Department,
	|	TemporaryTableProductsOwnershipPrev.Cell AS Cell,
	|	TemporaryTableProductsOwnershipPrev.VATRate AS VATRate,
	|	TemporaryTableProductsOwnershipPrev.DocumentCurrency AS DocumentCurrency,
	|	TemporaryTableProductsOwnershipPrev.ExchangeRate AS ExchangeRate,
	|	TemporaryTableProductsOwnershipPrev.Multiplicity AS Multiplicity,
	|	TemporaryTableProductsOwnershipPrev.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	TemporaryTableProductsOwnershipPrev.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	TemporaryTableProductsOwnershipPrev.RevenueItem AS RevenueItem,
	|	TemporaryTableProductsOwnershipPrev.COGSItem AS COGSItem,
	|	TemporaryTableProductsOwnershipPrev.PurchaseReturnItem AS PurchaseReturnItem,
	|	TemporaryTableProductsOwnershipPrev.InventoryAccountType AS InventoryAccountType,
	|	TemporaryTableProductsOwnershipPrev.GLAccount AS GLAccount,
	|	TemporaryTableProductsOwnershipPrev.Products AS Products,
	|	TemporaryTableProductsOwnershipPrev.Characteristic AS Characteristic,
	|	TemporaryTableProductsOwnershipPrev.Batch AS Batch,
	|	TemporaryTableProductsOwnershipPrev.Order AS Order,
	|	TemporaryTableProductsOwnershipPrev.SalesInvoice AS SalesInvoice,
	|	TemporaryTableProductsOwnershipPrev.Quantity AS Quantity,
	|	TemporaryTableProductsOwnershipPrev.OperationType AS OperationType,
	|	TemporaryTableProductsOwnershipPrev.CorrOrganization AS CorrOrganization,
	|	TemporaryTableProductsOwnershipPrev.CorrPresentationCurrency AS CorrPresentationCurrency,
	|	TemporaryTableProductsOwnershipPrev.StructuralUnitCorr AS StructuralUnitCorr,
	|	TemporaryTableProductsOwnershipPrev.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TemporaryTableProductsOwnershipPrev.CorrGLAccount AS CorrGLAccount,
	|	TemporaryTableProductsOwnershipPrev.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	TemporaryTableProductsOwnershipPrev.CorrOrder AS CorrOrder,
	|	TemporaryTableProductsOwnershipPrev.ProductsOnCommission AS ProductsOnCommission,
	|	TemporaryTableProductsOwnershipPrev.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	TemporaryTableProductsOwnershipPrev.SalesRep AS SalesRep,
	|	TemporaryTableProductsOwnershipPrev.InventoryTransferredGLAccount AS InventoryTransferredGLAccount,
	|	ISNULL(CounterpartyContracts.SettlementsCurrency, VALUE(Catalog.Currencies.EmptyRef)) AS Currency,
	|	&ContinentalMethod AS ContinentalMethod,
	|	TemporaryTableProductsOwnershipPrev.SupplierInvoice AS SupplierInvoice,
	|	CAST(TemporaryTableProductsOwnershipPrev.Amount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(TemporaryTableProductsOwnershipPrev.Amount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryTableProductsOwnershipPrev.ExchangeRate * TemporaryTableProductsOwnershipPrev.ContractCurrencyMultiplicity / (TemporaryTableProductsOwnershipPrev.ContractCurrencyExchangeRate * TemporaryTableProductsOwnershipPrev.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (TemporaryTableProductsOwnershipPrev.ExchangeRate * TemporaryTableProductsOwnershipPrev.ContractCurrencyMultiplicity / (TemporaryTableProductsOwnershipPrev.ContractCurrencyExchangeRate * TemporaryTableProductsOwnershipPrev.Multiplicity))
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	TemporaryTableProductsOwnershipPrev.Ownership AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	TemporaryTableProductsOwnershipPrev.SerialNumber AS SerialNumber
	|INTO TemporaryTableProductsOwnership
	|FROM
	|	TemporaryTableProductsOwnershipPrev AS TemporaryTableProductsOwnershipPrev
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON TemporaryTableProductsOwnershipPrev.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &DocumentCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTableProductsPrev.LineNumber,
	|	TemporaryTableProductsPrev.Document,
	|	TemporaryTableProductsPrev.Responsible,
	|	TemporaryTableProductsPrev.Counterparty,
	|	TemporaryTableProductsPrev.Contract,
	|	TemporaryTableProductsPrev.Period,
	|	TemporaryTableProductsPrev.Company,
	|	TemporaryTableProductsPrev.PresentationCurrency,
	|	TemporaryTableProductsPrev.BusinessLineSales,
	|	TemporaryTableProductsPrev.GLAccountCost,
	|	TemporaryTableProductsPrev.AccountStatementSales,
	|	TemporaryTableProductsPrev.AccountStatementDeferredSales,
	|	TemporaryTableProductsPrev.StructuralUnit,
	|	TemporaryTableProductsPrev.Department,
	|	TemporaryTableProductsPrev.Cell,
	|	TemporaryTableProductsPrev.VATRate,
	|	TemporaryTableProductsPrev.DocumentCurrency,
	|	TemporaryTableProductsPrev.ExchangeRate,
	|	TemporaryTableProductsPrev.Multiplicity,
	|	TemporaryTableProductsPrev.ContractCurrencyExchangeRate,
	|	TemporaryTableProductsPrev.ContractCurrencyMultiplicity,
	|	TemporaryTableProductsPrev.RevenueItem,
	|	TemporaryTableProductsPrev.COGSItem,
	|	TemporaryTableProductsPrev.PurchaseReturnItem,
	|	TemporaryTableProductsPrev.InventoryAccountType,
	|	TemporaryTableProductsPrev.GLAccount,
	|	TemporaryTableProductsPrev.Products,
	|	TemporaryTableProductsPrev.Characteristic,
	|	TemporaryTableProductsPrev.Batch,
	|	TemporaryTableProductsPrev.Order,
	|	TemporaryTableProductsPrev.SalesInvoice,
	|	TemporaryTableProductsPrev.Quantity,
	|	TemporaryTableProductsPrev.OperationType,
	|	TemporaryTableProductsPrev.CorrOrganization,
	|	TemporaryTableProductsPrev.CorrPresentationCurrency,
	|	TemporaryTableProductsPrev.StructuralUnitCorr,
	|	TemporaryTableProductsPrev.CorrInventoryAccountType,
	|	TemporaryTableProductsPrev.CorrGLAccount,
	|	TemporaryTableProductsPrev.CorrIncomeAndExpenseItem,
	|	TemporaryTableProductsPrev.CorrOrder,
	|	TemporaryTableProductsPrev.ProductsOnCommission,
	|	TemporaryTableProductsPrev.GLAccountVendorSettlements,
	|	TemporaryTableProductsPrev.SalesRep,
	|	TemporaryTableProductsPrev.InventoryTransferredGLAccount,
	|	ISNULL(CounterpartyContracts.SettlementsCurrency, VALUE(Catalog.Currencies.EmptyRef)),
	|	&ContinentalMethod,
	|	TemporaryTableProductsPrev.SupplierInvoice,
	|	CAST(TemporaryTableProductsPrev.Amount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)),
	|	CAST(TemporaryTableProductsPrev.Amount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryTableProductsPrev.ExchangeRate * TemporaryTableProductsPrev.ContractCurrencyMultiplicity / (TemporaryTableProductsPrev.ContractCurrencyExchangeRate * TemporaryTableProductsPrev.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (TemporaryTableProductsPrev.ExchangeRate * TemporaryTableProductsPrev.ContractCurrencyMultiplicity / (TemporaryTableProductsPrev.ContractCurrencyExchangeRate * TemporaryTableProductsPrev.Multiplicity))
	|		END AS NUMBER(15, 2)),
	|	TemporaryTableProductsPrev.Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef),
	|	NULL
	|FROM
	|	TemporaryTableProductsPrev AS TemporaryTableProductsPrev
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON TemporaryTableProductsPrev.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &DocumentCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsIssueSerialNumbers.ConnectionKey AS ConnectionKey,
	|	GoodsIssueSerialNumbers.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.GoodsIssue.SerialNumbers AS GoodsIssueSerialNumbers
	|WHERE
	|	GoodsIssueSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers";
	
	StructureForPosting = StructureAdditionalProperties.ForPosting;
	
	Query.SetParameter("Ref",					DocumentRefGoodsIssue);
	Query.SetParameter("Company",				StructureForPosting.Company);
	Query.SetParameter("PointInTime",			New Boundary(StructureForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseSerialNumbers",		StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("ContinentalMethod",		StructureAdditionalProperties.AccountingPolicy.ContinentalMethod);
	Query.SetParameter("PresentationCurrency",	StructureForPosting.PresentationCurrency);
	Query.SetParameter("DocumentCurrency",		DocumentRefGoodsIssue.DocumentCurrency);
	Query.SetParameter("ExchangeRateMethod",	StructureForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	If DocumentRefGoodsIssue.OperationType = Enums.OperationTypesGoodsIssue.TransferToSubcontractor
		And TypeOf(DocumentRefGoodsIssue.Order) = Type("DocumentRef.SubcontractorOrderIssued")
		And ValueIsFilled(DocumentRefGoodsIssue.Order.OrderReceived) Then
		Query.SetParameter("IsOrderReceived", 		True);
	Else
		Query.SetParameter("IsOrderReceived", 		False);
	EndIf;
	
	ResultsArray = Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefGoodsIssue, StructureAdditionalProperties);
	
	IncomeAndExpensesRecordSet = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", IncomeAndExpensesRecordSet.Unload());
	
	SalesRecordSet = AccumulationRegisters.Sales.CreateRecordSet();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", SalesRecordSet.Unload());
	
	GenerateTableInventoryInWarehouses(DocumentRefGoodsIssue, StructureAdditionalProperties);
	GenerateTableSalesOrders(DocumentRefGoodsIssue, StructureAdditionalProperties);
	GenerateTableGoodsShippedNotInvoiced(DocumentRefGoodsIssue, StructureAdditionalProperties);
	GenerateTableStockReceivedFromThirdParties(DocumentRefGoodsIssue, StructureAdditionalProperties);
	GenerateTableStockTransferredToThirdParties(DocumentRefGoodsIssue, StructureAdditionalProperties);
	GenerateTablePurchaseOrders(DocumentRefGoodsIssue, StructureAdditionalProperties);
	GenerateTableInventoryDemand(DocumentRefGoodsIssue, StructureAdditionalProperties);
	GenerateTableSubcontractComponents(DocumentRefGoodsIssue, StructureAdditionalProperties);
	
	GenerateTableInventory(DocumentRefGoodsIssue, StructureAdditionalProperties);
	GenerateTableReservedProducts(DocumentRefGoodsIssue, StructureAdditionalProperties);
	
	GenerateTableGoodsInvoicedNotShipped(DocumentRefGoodsIssue, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefGoodsIssue, StructureAdditionalProperties);
	If StructureAdditionalProperties.AccountingPolicy.AccountingModuleSettings
		= Enums.AccountingModuleSettingsTypes.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefGoodsIssue, StructureAdditionalProperties);
	EndIf;
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefGoodsIssue, StructureAdditionalProperties);
	
	// begin Drive.FullVersion
	// Customer-owned inventory
	GenerateTableCustomerOwnedInventory(DocumentRefGoodsIssue, StructureAdditionalProperties);
	// end Drive.FullVersion
	
	// Goods in transit
	If WorkWithVATServerCall.MultipleVATNumbersAreUsed() Then
		GenerateTableGoodsInTransit(DocumentRefGoodsIssue, StructureAdditionalProperties);
	EndIf;
	
	GenerateTableAccountingEntriesData(DocumentRefGoodsIssue, StructureAdditionalProperties);

	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		
		StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries = 
			DriveServer.AddOfflineAccountingJournalEntriesRecords(
				StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries,
				DocumentRefGoodsIssue);
	EndIf;
		
	FinancialAccounting.FillExtraDimensions(DocumentRefGoodsIssue, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefGoodsIssue, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefGoodsIssue, StructureAdditionalProperties);
		
	EndIf;

EndProcedure

Procedure CheckAbilityOfEnteringByGoodsIssue(Object, FillingData, Posted, OperationType) Export
	
	If TypeOf(Object) = Type("DocumentObject.SalesInvoice")  
		And Not (OperationType = Enums.OperationTypesGoodsIssue.SaleToCustomer Or OperationType = Enums.OperationTypesGoodsIssue.DropShipping)Then
		If GetFunctionalOption("UseDropShipping") Then
			ErrorText = NStr("en = 'Cannot generate a Sales invoice from %1. 
							|Select a Goods issue whose Operation is ""Sale to customer"" or ""Drop shipping"".'; 
							|ru = 'Не удалось создать инвойс покупателю на основании %1. 
							|Выберите отпуск товаров с операцией «Продажа покупателю» или «Дропшиппинг».';
							|pl = 'Nie udało się wygenerować Faktury sprzedaży z%1. 
							|Wybierz Wydanie zewnętrzne z operacją ""Sprzedaż nabywcy"" lub ""Dropshipping"".';
							|es_ES = 'No se puede generar una factura de venta de %1.
							|Seleccione una salida de Mercancías cuya Operación es ""Venta al cliente"" o ""Envío directo"".';
							|es_CO = 'No se puede generar una factura de venta de %1.
							|Seleccione una salida de Mercancías cuya Operación es ""Venta al cliente"" o ""Envío directo"".';
							|tr = '%1 bazlı Satış faturası oluşturulamıyor. 
							|İşlemi ""Müşteriye satış"" veya ""Stoksuz satış"" olan bir Ambar çıkışı seçin.';
							|it = 'Impossibile generare una Fattura di vendita da %1.
							|Selezionare una Spedizione merce/DDT la cui Operazione è ""Vendita al cliente"" o ""Dropshipping"".';
							|de = 'Fehler beim Generieren einer Verkaufsrechnung aus %1. 
							| Wählen Sie einen Warenausgang mit der Operation ""Verkauf an Kunden"" oder ""Streckengeschäft"" aus.'");
		Else 
			ErrorText = NStr("en = 'Cannot generate a Sales invoice from %1. 
							|Select a Goods issue whose Operation is ""Sale to customer"".'; 
							|ru = 'Не удалось создать инвойс покупателю на основании %1. 
							|Выберите отпуск товаров с операцией «Продажа покупателю».';
							|pl = 'Nie można wygenerować Faktury sprzedaży z%1. 
							|Wybierz Wydanie zewnętrzne z operacją ""Sprzedaż nabywcy"".';
							|es_ES = 'No se puede generar una factura de venta de %1.
							|Seleccione una salida de Mercancías cuya Operación es ""Venta al cliente"".';
							|es_CO = 'No se puede generar una factura de venta de %1.
							|Seleccione una salida de Mercancías cuya Operación es ""Venta al cliente"".';
							|tr = '%1 bazlı Satış faturası oluşturulamıyor. 
							|İşlemi ""Müşteriye satış"" olan bir Ambar çıkışı seçin.';
							|it = 'Impossibile generare una Fattura di vendita da %1.
							|Selezionare una Spedizione merce/DDT la cui Operazione è ""Vendita al cliente"".';
							|de = 'Fehler beim Generieren einer Verkaufsrechnung aus %1. 
							| Wählen Sie einen Warenausgang mit der Operation ""Verkauf an Kunden"" aus.'");
		EndIf;
		Raise StringFunctionsClientServer.SubstituteParametersToString(
				ErrorText,
				FillingData);
				
	ElsIf TypeOf(Object) = Type("DocumentObject.DebitNote") AND OperationType <> Enums.OperationTypesGoodsIssue.PurchaseReturn Then
		ErrorText = NStr("en = 'Cannot use %1 as a base document for Debit note. Please select a goods issue with ""Purchase return"" operation.'; ru = '%1 не может быть основанием для дебетового авизо. Выберите отпуск товаров с видом операции ""Возврат закупки"".';pl = 'Nie można użyć %1 jako dokumentu źródłowego dla Noty debetowej. Wybierz wydanie zewnętrzne za pomocą operacji ""Zwrot zakupu"".';es_ES = 'No se puede usar %1 como documento de base para la nota de cargo. Seleccione una expedición de los productos con la operación ""Devolución de compra"".';es_CO = 'No se puede usar %1 como documento de base para la nota de cargo. Seleccione una expedición de los productos con la operación ""Devolución de compra"".';tr = 'Borç dekontu için temel belge olarak %1 kullanılamaz. Lütfen ""Satın alma iade"" işlemli bir Ambar çıkışı seçin.';it = 'Impossibile utilizzare %1 come documento di base per la Nota di debito. Selezionare una spedizione merce con operazione ""Reso acquisto"".';de = 'Kann nicht %1 als Basisdokument für die Lastschrift verwendet werden. Bitte wählen Sie einen Warenausgang mit der Operation ""Kaufretoure"" aus.'");
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

Procedure RunControl(DocumentRefGoodsIssue, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsInventoryChange", "MovementsInventoryInWarehousesChange",
	// "MovementsInventoryPassedChange", "RegisterRecordsStockReceivedFromThirdPartiesChange",
	// "RegisterRecordsBackordersChange", "RegisterRecordsInventoryDemandChange",
	// "RegisterRecordsSubcontractComponentsChange" contain records, it is
	// required to control goods implementation.
	
	If StructureTemporaryTables.RegisterRecordsInventoryChange
		Or StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		Or StructureTemporaryTables.RegisterRecordsSalesOrdersChange
		Or StructureTemporaryTables.RegisterRecordsGoodsShippedNotInvoicedChange
		Or StructureTemporaryTables.RegisterRecordsGoodsInvoicedNotShippedChange
		Or StructureTemporaryTables.RegisterRecordsStockTransferredToThirdPartiesChange 
		Or StructureTemporaryTables.RegisterRecordsStockReceivedFromThirdPartiesChange 
		Or StructureTemporaryTables.RegisterRecordsPurchaseOrdersChange
		Or StructureTemporaryTables.RegisterRecordsInventoryDemandChange
		Or StructureTemporaryTables.RegisterRecordsReservedProductsChange
		Or StructureTemporaryTables.RegisterRecordsInventoryWithSourceDocumentChange
		// begin Drive.FullVersion
		Or StructureTemporaryTables.RegisterRecordsSubcontractComponentsChange
		Or StructureTemporaryTables.RegisterRecordsCustomerOwnedInventoryChange
		// end Drive.FullVersion
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
		|	RegisterRecordsStockTransferredToThirdPartiesChange.LineNumber AS LineNumber,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Company AS CompanyPresentation,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Products AS ProductsPresentation,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Batch AS BatchPresentation,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Order AS OrderPresentation,
		|	StockTransferredToThirdPartiesBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsStockTransferredToThirdPartiesChange.QuantityChange, 0) + ISNULL(StockTransferredToThirdPartiesBalances.QuantityBalance, 0) AS BalanceStockTransferredToThirdParties,
		|	ISNULL(StockTransferredToThirdPartiesBalances.QuantityBalance, 0) AS QuantityBalanceStockTransferredToThirdParties
		|FROM
		|	RegisterRecordsStockTransferredToThirdPartiesChange AS RegisterRecordsStockTransferredToThirdPartiesChange
		|		INNER JOIN AccumulationRegister.StockTransferredToThirdParties.Balance(&ControlTime, ) AS StockTransferredToThirdPartiesBalances
		|		ON RegisterRecordsStockTransferredToThirdPartiesChange.Company = StockTransferredToThirdPartiesBalances.Company
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Products = StockTransferredToThirdPartiesBalances.Products
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Characteristic = StockTransferredToThirdPartiesBalances.Characteristic
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Batch = StockTransferredToThirdPartiesBalances.Batch
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Counterparty = StockTransferredToThirdPartiesBalances.Counterparty
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Order = StockTransferredToThirdPartiesBalances.Order
		|			AND (ISNULL(StockTransferredToThirdPartiesBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.LineNumber AS LineNumber,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Company AS CompanyPresentation,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Products AS ProductsPresentation,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Batch AS BatchPresentation,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Order AS OrderPresentation,
		|	StockReceivedFromThirdPartiesBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsStockReceivedFromThirdPartiesChange.QuantityChange, 0) + ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) AS BalanceStockReceivedFromThirdParties,
		|	ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) AS QuantityBalanceStockReceivedFromThirdParties
		|FROM
		|	RegisterRecordsStockReceivedFromThirdPartiesChange AS RegisterRecordsStockReceivedFromThirdPartiesChange
		|		INNER JOIN AccumulationRegister.StockReceivedFromThirdParties.Balance(&ControlTime, ) AS StockReceivedFromThirdPartiesBalances
		|		ON RegisterRecordsStockReceivedFromThirdPartiesChange.Company = StockReceivedFromThirdPartiesBalances.Company
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Products = StockReceivedFromThirdPartiesBalances.Products
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic = StockReceivedFromThirdPartiesBalances.Characteristic
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Batch = StockReceivedFromThirdPartiesBalances.Batch
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Counterparty = StockReceivedFromThirdPartiesBalances.Counterparty
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Order = StockReceivedFromThirdPartiesBalances.Order
		|			AND (ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsPurchaseOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsPurchaseOrdersChange.Company AS CompanyPresentation,
		|	RegisterRecordsPurchaseOrdersChange.PurchaseOrder AS OrderPresentation,
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
		|	RegisterRecordsInventoryDemandChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryDemandChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryDemandChange.MovementType AS MovementTypePresentation,
		|	RegisterRecordsInventoryDemandChange.SalesOrder AS SalesOrderPresentation,
		|	RegisterRecordsInventoryDemandChange.Products AS ProductsPresentation,
		|	RegisterRecordsInventoryDemandChange.Characteristic AS CharacteristicPresentation,
		|	InventoryDemandBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryDemandChange.QuantityChange, 0) + ISNULL(InventoryDemandBalances.QuantityBalance, 0) AS BalanceInventoryDemand,
		|	ISNULL(InventoryDemandBalances.QuantityBalance, 0) AS QuantityBalanceInventoryDemand
		|FROM
		|	RegisterRecordsInventoryDemandChange AS RegisterRecordsInventoryDemandChange
		|		INNER JOIN AccumulationRegister.InventoryDemand.Balance(&ControlTime, ) AS InventoryDemandBalances
		|		ON RegisterRecordsInventoryDemandChange.Company = InventoryDemandBalances.Company
		|			AND RegisterRecordsInventoryDemandChange.MovementType = InventoryDemandBalances.MovementType
		|			AND RegisterRecordsInventoryDemandChange.SalesOrder = InventoryDemandBalances.SalesOrder
		|			AND RegisterRecordsInventoryDemandChange.Products = InventoryDemandBalances.Products
		|			AND RegisterRecordsInventoryDemandChange.Characteristic = InventoryDemandBalances.Characteristic
		|			AND (ISNULL(InventoryDemandBalances.QuantityBalance, 0) < 0)
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
		Query.Text = Query.Text + AccumulationRegisters.Inventory.ReturnQuantityControlQueryText();
		
		// begin Drive.FullVersion
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.SubcontractComponents.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.CustomerOwnedInventory.BalancesControlQueryText();
		// end Drive.FullVersion
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		Query.SetParameter("Ref", DocumentRefGoodsIssue);
		
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
			Or Not ResultsArray[9].IsEmpty()
			Or Not ResultsArray[10].IsEmpty()
			Or Not ResultsArray[16].IsEmpty()
			// begin Drive.FullVersion
			Or Not ResultsArray[17].IsEmpty()
			Or Not ResultsArray[18].IsEmpty()
			// end Drive.FullVersion
		Then
			DocumentObjectGoodsIssue = DocumentRefGoodsIssue.GetObject();
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		// Negative balance of inventory.
		ElsIf Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		// Negative balance of need for reserved products.
		ElsIf Not ResultsArray[8].IsEmpty() Then
			QueryResultSelection = ResultsArray[8].Select();
			DriveServer.ShowMessageAboutPostingToReservedProductsRegisterErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		Else
			// Negative balance of inventory with reserves.
			DriveServer.CheckAvailableStockBalance(DocumentObjectGoodsIssue, AdditionalProperties, Cancel);
		EndIf;
		
		// Negative balance on sales order.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToSalesOrdersRegisterErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of transferred inventory.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToStockTransferredToThirdPartiesRegisterErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory received.
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ShowMessageAboutPostingToStockReceivedFromThirdPartiesRegisterErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on the order to the vendor.
		If Not ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			DriveServer.ShowMessageAboutPostingToPurchaseOrdersRegisterErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of need for inventory.
		If Not ResultsArray[6].IsEmpty() Then
			QueryResultSelection = ResultsArray[6].Select();
			DriveServer.ShowMessageAboutPostingToInventoryDemandRegisterErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If Not ResultsArray[7].IsEmpty() Then
			QueryResultSelection = ResultsArray[7].Select();
			DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on goods issued not yet invoiced
		If Not ResultsArray[9].IsEmpty() Then
			QueryResultSelection = ResultsArray[9].Select();
			DriveServer.ShowMessageAboutPostingToGoodsShippedNotInvoicedRegisterErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of goods invoiced not shipped
		If Not ResultsArray[10].IsEmpty() Then
			QueryResultSelection = ResultsArray[10].Select();
			DriveServer.ShowMessageAboutPostingToGoodsInvoicedNotShippedRegisterErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of return quantity in inventory
		If Not ResultsArray[16].IsEmpty() And ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[16].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterRefundsErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		EndIf;
		
		// begin Drive.FullVersion
		
		// Negative balance of subcontract components
		If Not ResultsArray[17].IsEmpty() Then
			QueryResultSelection = ResultsArray[17].Select();
			DriveServer.ShowMessageAboutPostingToSubcontractComponentsRegisterErrors(
				DocumentObjectGoodsIssue,
				QueryResultSelection,
				Cancel);
			EndIf;
			
		// Negative balance of customer-owned inventory
		If Not ResultsArray[18].IsEmpty() Then
			QueryResultSelection = ResultsArray[18].Select();
			DriveServer.ShowMessageAboutPostingToCustomerOwnedInventoryRegisterErrors(
				DocumentObjectGoodsIssue,
				QueryResultSelection,
				Cancel,
				AdditionalProperties.WriteMode);
		EndIf;
			
		// end Drive.FullVersion
		
	EndIf;
	
EndProcedure

#EndRegion

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	ObjectParameters = StructureData.ObjectParameters;
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(ObjectParameters.Date, ObjectParameters.Company);
	
	IncomeAndExpenseStructure = New Structure;
	
	If ObjectParameters.OperationType = Enums.OperationTypesGoodsIssue.SaleToCustomer
		Or ObjectParameters.OperationType = Enums.OperationTypesGoodsIssue.DropShipping Then
		
		If ValueIsFilled(StructureData.SalesInvoice) Then
			IncomeAndExpenseStructure.Insert("COGSItem", StructureData.COGSItem);
			IncomeAndExpenseStructure.Insert("RevenueItem", StructureData.RevenueItem);
		ElsIf AccountingPolicy.ContinentalMethod Then
			IncomeAndExpenseStructure.Insert("COGSItem", StructureData.COGSItem);
		EndIf;
		
	ElsIf ObjectParameters.OperationType = Enums.OperationTypesGoodsIssue.PurchaseReturn Then
		
		IncomeAndExpenseStructure.Insert("PurchaseReturnItem", StructureData.PurchaseReturnItem);
		
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "Products" Then
		Result.Insert("RevenueGLAccount", "RevenueItem");
		Result.Insert("COGSGLAccount", "COGSItem");
		Result.Insert("PurchaseReturnGLAccount", "PurchaseReturnItem");
	EndIf;

	Return Result;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	ObjectParameters = StructureData.ObjectParameters;
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(ObjectParameters.Date, ObjectParameters.Company);
	GLAccountsForFilling = New Structure;
	
	If ObjectParameters.OperationType = Enums.OperationTypesGoodsIssue.TransferToSubcontractingCustomer Then
		
		Return GLAccountsForFilling;
		
	ElsIf ObjectParameters.OperationType = Enums.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer Then
		
		GLAccountsForFilling.Insert("InventoryReceivedGLAccount", StructureData.InventoryReceivedGLAccount);
		GLAccountsForFilling.Insert("InventoryTransferredGLAccount", StructureData.InventoryTransferredGLAccount);
		
	Else
		GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
	EndIf;
	
	If ObjectParameters.OperationType = Enums.OperationTypesGoodsIssue.SaleToCustomer 
		Or ObjectParameters.OperationType = Enums.OperationTypesGoodsIssue.DropShipping Then
		GLAccountsForFilling.Insert("InventoryReceivedGLAccount", StructureData.InventoryReceivedGLAccount);
		If Not ValueIsFilled(StructureData.SalesInvoice)
			And AccountingPolicy.ContinentalMethod Then
			GLAccountsForFilling.Insert("COGSGLAccount", StructureData.COGSGLAccount);
		ElsIf Not ValueIsFilled(StructureData.SalesInvoice)
			And Not AccountingPolicy.ContinentalMethod Then
			GLAccountsForFilling.Insert("GoodsShippedNotInvoicedGLAccount", StructureData.GoodsShippedNotInvoicedGLAccount);
		Else
			GLAccountsForFilling.Insert("UnearnedRevenueGLAccount",	StructureData.UnearnedRevenueGLAccount);
			GLAccountsForFilling.Insert("RevenueGLAccount",			StructureData.RevenueGLAccount);
			GLAccountsForFilling.Insert("COGSGLAccount",			StructureData.COGSGLAccount);
		EndIf;
	ElsIf ObjectParameters.OperationType = Enums.OperationTypesGoodsIssue.TransferToAThirdParty Then
		GLAccountsForFilling.Insert("InventoryTransferredGLAccount", StructureData.InventoryTransferredGLAccount);
	ElsIf ObjectParameters.OperationType = Enums.OperationTypesGoodsIssue.ReturnToAThirdParty Then
		GLAccountsForFilling.Insert("InventoryReceivedGLAccount", StructureData.InventoryReceivedGLAccount);
	ElsIf ObjectParameters.OperationType = Enums.OperationTypesGoodsIssue.PurchaseReturn Then
		GLAccountsForFilling.Insert("PurchaseReturnGLAccount", StructureData.PurchaseReturnGLAccount);
	ElsIf ObjectParameters.OperationType = Enums.OperationTypesGoodsIssue.IntraCommunityTransfer Then
		GLAccountsForFilling.Insert("GoodsInTransitGLAccount", StructureData.GoodsInTransitGLAccount);
	ElsIf ObjectParameters.OperationType = Enums.OperationTypesGoodsIssue.TransferToSubcontractor Then
		GLAccountsForFilling.Insert("InventoryTransferredGLAccount", StructureData.InventoryTransferredGLAccount);
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region TableGeneration

Procedure GenerateTableSalesOrders(DocumentRef, StructureAdditionalProperties)
	
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
	|			WHEN TableSalesOrders.OperationType = VALUE(Enum.OperationTypesGoodsIssue.DropShipping)
	|				THEN TableSalesOrders.Quantity
	|			ELSE 0
	|		END) AS DropShippingQuantity
	|FROM
	|	TemporaryTableProductsOwnership AS TableSalesOrders
	|WHERE
	|	TableSalesOrders.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND TableSalesOrders.Order REFS Document.SalesOrder
	|	AND TableSalesOrders.SalesInvoice = VALUE(Document.SalesInvoice.EmptyRef)
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

Procedure GenerateTableInventory(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProducts.LineNumber AS LineNumber,
	|	TableProducts.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProducts.Company AS Company,
	|	TableProducts.PresentationCurrency AS PresentationCurrency,
	|	TableProducts.Counterparty AS Counterparty,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.IntraCommunityTransfer)
	|			THEN TableProducts.PresentationCurrency
	|		ELSE TableProducts.Currency
	|	END AS Currency,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToAThirdParty)
	|				OR TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.PurchaseReturn)
	|				OR TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS Return,
	|	TableProducts.Document AS Document,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.PurchaseReturn)
	|			THEN TableProducts.SupplierInvoice
	|		ELSE TableProducts.Document
	|	END AS SourceDocument,
	|	CASE
	|		WHEN (TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|				OR TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.DropShipping))
	|				AND TableProducts.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableProducts.Order <> VALUE(Document.WorkOrder.EmptyRef)
	// begin Drive.FullVersion
	|				AND TableProducts.Order <> VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	// end Drive.FullVersion
	|			THEN TableProducts.Order
	|		ELSE UNDEFINED
	|	END AS CorrSalesOrder,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|				OR TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractingCustomer)
	|				OR TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.DropShipping)
	|			THEN TableProducts.Department
	|		ELSE UNDEFINED
	|	END AS Department,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|				OR TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.DropShipping)
	|			THEN TableProducts.Responsible
	|		ELSE UNDEFINED
	|	END AS Responsible,
	|	TableProducts.GLAccountCost AS GLAccountCost,
	|	ISNULL(TableProducts.StructuralUnit, VALUE(Catalog.Counterparties.EmptyRef)) AS StructuralUnit,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|				OR TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.DropShipping)
	|			THEN TableProducts.Counterparty
	|		ELSE TableProducts.StructuralUnitCorr
	|	END AS StructuralUnitCorr,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|				OR TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.DropShipping)
	|			THEN TableProducts.Company
	|		ELSE TableProducts.CorrOrganization
	|	END AS CorrOrganization,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|				OR TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.DropShipping)
	|			THEN TableProducts.PresentationCurrency
	|		ELSE TableProducts.CorrPresentationCurrency
	|	END AS CorrPresentationCurrency,
	|	TableProducts.CorrGLAccount AS CorrGLAccount,
	|	TableProducts.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableProducts.Products AS ProductsCorr,
	|	TableProducts.Characteristic AS CharacteristicCorr,
	|	TableProducts.Batch AS BatchCorr,
	|	TableProducts.Ownership AS OwnershipCorr,
	|	CASE
	|		WHEN NOT &FillAmount
	|				OR TableProducts.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableProducts.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		WHEN TableProducts.Order REFS Document.SalesOrder
	|				AND TableProducts.OperationType <> VALUE(Enum.OperationTypesGoodsIssue.ReturnToAThirdParty)
	|			THEN TableProducts.Order
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	CASE
	|		WHEN TableProducts.CorrOrder REFS Document.SalesOrder
	|				AND TableProducts.CorrOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableProducts.CorrOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableProducts.CorrOrder
	|		ELSE UNDEFINED
	|	END AS CustomerCorrOrder,
	|	TableProducts.GLAccount AS GLAccount,
	|	TableProducts.InventoryAccountType AS InventoryAccountType,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.IntraCommunityTransfer)
	|			THEN &UndefinedItem
	|		WHEN (TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|				OR TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.DropShipping))
	|					AND TableProducts.SalesInvoice = VALUE(Document.SalesInvoice.EmptyRef)
	|					AND NOT &FillAmount
	|					AND NOT TableProducts.ContinentalMethod
	|			THEN &UndefinedItem
	|		ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) 
	|	END AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.IntraCommunityTransfer)
	|			THEN &UndefinedItem
	|		WHEN (TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|				OR TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.DropShipping))
	|					AND TableProducts.SalesInvoice = VALUE(Document.SalesInvoice.EmptyRef)
	|					AND NOT &FillAmount
	|					AND NOT TableProducts.ContinentalMethod
	|			THEN &UndefinedItem
	|		ELSE TableProducts.CorrIncomeAndExpenseItem
	|	END AS CorrIncomeAndExpenseItem,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.Quantity AS Quantity,
	|	0 AS Cost,
	|	TableProducts.Amount AS Amount,
	|	TableProducts.VATRate AS VATRate,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToAThirdParty)
	|				OR TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS FixedCost,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|				OR TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.DropShipping)
	|			THEN TableProducts.GLAccountCost
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.IntraCommunityTransfer)
	|			THEN TableProducts.CorrGLAccount
	|		ELSE TableProducts.InventoryTransferredGLAccount
	|	END AS AccountDr,
	|	TableProducts.GLAccount AS AccountCr,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.IntraCommunityTransfer)
	|			THEN &GoodsInTransit
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractor)
	|			THEN CAST(&TransferedToSubcontractor AS STRING(100))
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer)
	|			THEN CAST(&ReturnToSubcontractingCustomer AS STRING(100))
	|		ELSE CAST(&InventoryWriteOff AS STRING(100))
	|	END AS Content,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.IntraCommunityTransfer)
	|			THEN &GoodsInTransit
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractor)
	|			THEN CAST(&TransferedToSubcontractor AS STRING(100))
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer)
	|			THEN CAST(&ReturnToSubcontractingCustomer AS STRING(100))
	|		ELSE CAST(&InventoryWriteOff AS STRING(100))
	|	END AS ContentOfAccountingRecord,
	|	TableProducts.SalesInvoice AS SalesInvoice,
	|	FALSE AS OfflineRecord,
	|	TableProducts.SalesRep AS SalesRep,
	|	TableProducts.Ownership AS Ownership,
	|	TableProducts.CostObject AS CostObject
	|FROM
	|	TemporaryTableProductsOwnership AS TableProducts
	|WHERE
	|	TableProducts.OperationType <> VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractingCustomer)
	|
	|UNION ALL
	|
	|SELECT
	|	TableProducts.LineNumber,
	|	TableProducts.Period,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableProducts.Company,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.Counterparty,
	|	TableProducts.Currency,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	FALSE,
	|	TableProducts.Document,
	|	TableProducts.Document,
	|	CASE
	|		WHEN TableProducts.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableProducts.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableProducts.Order
	|	END,
	|	TableProducts.Department,
	|	TableProducts.Responsible,
	|	TableProducts.GLAccountCost,
	|	TableProducts.Counterparty,
	|	UNDEFINED,
	|	TableProducts.Company,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.GLAccount,
	|	TableProducts.InventoryAccountType,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.Ownership,
	|	CASE
	|		WHEN TableProducts.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableProducts.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableProducts.Order
	|	END,
	|	UNDEFINED,
	|	TableProducts.CorrGLAccount,
	|	TableProducts.CorrInventoryAccountType,
	|	&UndefinedItem,
	|	&UndefinedItem,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.Quantity,
	|	0,
	|	0,
	|	TableProducts.VATRate,
	|	FALSE,
	|	TableProducts.GLAccountCost,
	|	TableProducts.GLAccount,
	|	CAST(&InventoryWriteOff AS STRING(100)),
	|	CAST(&InventoryWriteOff AS STRING(100)),
	|	TableProducts.SalesInvoice,
	|	FALSE,
	|	TableProducts.SalesRep,
	|	TableProducts.Ownership,
	|	TableProducts.CostObject
	|FROM
	|	TemporaryTableProductsOwnership AS TableProducts
	|WHERE
	|	(TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|			OR TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.DropShipping))
	|	AND TableProducts.SalesInvoice = VALUE(Document.SalesInvoice.EmptyRef)
	|	AND NOT &FillAmount
	|	AND NOT TableProducts.ContinentalMethod
	|
	|UNION ALL
	|
	|SELECT
	|	TableProducts.LineNumber,
	|	TableProducts.Period,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableProducts.Company,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.Counterparty,
	|	TableProducts.Currency,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	FALSE,
	|	TableProducts.Document,
	|	TableProducts.Document,
	|	CASE
	|		WHEN TableProducts.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableProducts.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableProducts.Order
	|	END,
	|	TableProducts.Department,
	|	TableProducts.Responsible,
	|	TableProducts.GLAccountCost,
	|	TableProducts.Counterparty,
	|	TableProducts.StructuralUnit,
	|	TableProducts.Company,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.GLAccount,
	|	TableProducts.InventoryAccountType,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.Ownership,
	|	CASE
	|		WHEN TableProducts.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableProducts.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableProducts.Order
	|	END,
	|	UNDEFINED,
	|	TableProducts.CorrGLAccount,
	|	TableProducts.CorrInventoryAccountType,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef),
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef),
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.Quantity,
	|	0,
	|	0,
	|	TableProducts.VATRate,
	|	FALSE,
	|	TableProducts.GLAccountCost,
	|	TableProducts.GLAccount,
	|	CAST(&InventoryWriteOff AS STRING(100)),
	|	CAST(&InventoryWriteOff AS STRING(100)),
	|	TableProducts.SalesInvoice,
	|	FALSE,
	|	TableProducts.SalesRep,
	|	TableProducts.Ownership,
	|	TableProducts.CostObject
	|FROM
	|	TemporaryTableProductsOwnership AS TableProducts
	|WHERE
	|	TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
	|	AND NOT &FillAmount
	|
	|UNION ALL
	|
	|SELECT
	|	TableProducts.LineNumber,
	|	TableProducts.Period,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableProducts.Company,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.Counterparty,
	|	TableProducts.Currency,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	FALSE,
	|	TableProducts.Document,
	|	TableProducts.Document,
	|	CASE
	|		WHEN TableProducts.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableProducts.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableProducts.Order
	|	END,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableProducts.GLAccountCost,
	|	TableProducts.Counterparty,
	|	TableProducts.StructuralUnit,
	|	TableProducts.Company,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.GLAccount,
	|	TableProducts.InventoryAccountType,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.Ownership,
	|	CASE
	|		WHEN TableProducts.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableProducts.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableProducts.Order
	|	END,
	|	UNDEFINED,
	|	TableProducts.CorrGLAccount,
	|	TableProducts.CorrInventoryAccountType,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef),
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef),
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.Quantity,
	|	0,
	|	0,
	|	TableProducts.VATRate,
	|	FALSE,
	|	TableProducts.GLAccountCost,
	|	TableProducts.GLAccount,
	|	CAST(&TransferedToSubcontractor AS STRING(100)),
	|	CAST(&TransferedToSubcontractor AS STRING(100)),
	|	TableProducts.SalesInvoice,
	|	FALSE,
	|	TableProducts.SalesRep,
	|	TableProducts.Ownership,
	|	TableProducts.CostObject
	|FROM
	|	TemporaryTableProductsOwnership AS TableProducts
	|WHERE
	|	TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractor)
	|	AND NOT &FillAmount
	|
	|UNION ALL
	|
	|SELECT
	|	TableProducts.LineNumber,
	|	TableProducts.Period,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableProducts.Company,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.Company,
	|	TableProducts.PresentationCurrency,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	FALSE,
	|	TableProducts.Document,
	|	TableProducts.Document,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableProducts.GLAccountCost,
	|	VALUE(Catalog.BusinessUnits.GoodsInTransit),
	|	TableProducts.StructuralUnit,
	|	TableProducts.Company,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.GLAccount,
	|	TableProducts.InventoryAccountType,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.Ownership,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableProducts.CorrGLAccount,
	|	TableProducts.CorrInventoryAccountType,
	|	&UndefinedItem,
	|	&UndefinedItem,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.Quantity,
	|	0,
	|	0,
	|	TableProducts.VATRate,
	|	FALSE,
	|	TableProducts.CorrGLAccount,
	|	TableProducts.GLAccount,
	|	CAST(&GoodsInTransit AS STRING(100)),
	|	CAST(&GoodsInTransit AS STRING(100)),
	|	TableProducts.SalesInvoice,
	|	FALSE,
	|	TableProducts.SalesRep,
	|	TableProducts.Ownership,
	|	TableProducts.CostObject
	|FROM
	|	TemporaryTableProductsOwnership AS TableProducts
	|WHERE
	|	TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.IntraCommunityTransfer)
	|	AND NOT &FillAmount
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
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.StructuralUnitCorr,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.CorrGLAccount,
	|	OfflineRecords.CorrInventoryAccountType,
	|	OfflineRecords.ProductsCorr,
	|	OfflineRecords.CharacteristicCorr,
	|	OfflineRecords.BatchCorr,
	|	OfflineRecords.OwnershipCorr,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.CustomerCorrOrder,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.InventoryAccountType,
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.CorrIncomeAndExpenseItem,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.Quantity,
	|	0,
	|	OfflineRecords.Amount,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.FixedCost,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	UNDEFINED,
	|	OfflineRecords.OfflineRecord,
	|	OfflineRecords.SalesRep,
	|	OfflineRecords.Ownership,
	|	OfflineRecords.CostObject
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	FillAmount = StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
	
	Query.SetParameter(
		"InventoryWriteOff", 
		NStr("en = 'Inventory shipped'; ru = 'Доставленные товары';pl = 'Dostarczone zapasy';es_ES = 'Inventario enviado';es_CO = 'Inventario enviado';tr = 'Sevk edilen stok';it = 'Scorte spedite';de = 'Bestand ausgeliefert'", 
		CommonClientServer.DefaultLanguageCode()));
		
	Query.SetParameter(
		"GoodsInTransit",
		NStr("en = 'Goods in transit'; ru = 'Товары в пути';pl = 'Towary w tranzycie';es_ES = 'Mercancías en tránsito';es_CO = 'Mercancías en tránsito';tr = 'Transit mallar';it = 'Merci in transito';de = 'Waren in Transit'",
		CommonClientServer.DefaultLanguageCode()));
	
	Query.SetParameter("TransferedToSubcontractor",
		NStr("en = 'Transfered to subcontractor'; ru = 'Передано переработчику';pl = 'Przeniesiono do podwykonawcy';es_ES = 'Transferido al subcontratista';es_CO = 'Transferido al subcontratista';tr = 'Alt yükleniciye taşındı';it = 'Trasferito al subfornitore';de = 'Auf Subunternehmer übertragen'", CommonClientServer.DefaultLanguageCode()));
		
	Query.SetParameter("ReturnToSubcontractingCustomer",
		NStr("en = 'Return to subcontracting customer'; ru = 'Возврат давальцу';pl = 'Zwrot do nabywcy usług podwykonawstwa';es_ES = 'Devolución al cliente subcontratado';es_CO = 'Devolución al cliente subcontratado';tr = 'Alt yüklenici müşteriye iade';it = 'Restituire al cliente in subfornitura';de = 'Zurück zu Kunde mit Subunternehmerbestellung'", CommonClientServer.DefaultLanguageCode()));
		
	Query.SetParameter("UndefinedItem", Catalogs.IncomeAndExpenseItems.Undefined);
	Query.SetParameter("FillAmount", FillAmount);
	Query.SetParameter("Ref", DocumentRef);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
	If FillAmount And DocumentRef.OperationType <> Enums.OperationTypesGoodsIssue.PurchaseReturn Then
		GenerateTableInventorySale(DocumentRef, StructureAdditionalProperties);
	EndIf;
	
EndProcedure

Procedure GenerateTableInventorySale(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text =
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership
	|FROM
	|	TemporaryTableProductsOwnership AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.StructuralUnit,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership";
	
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
	|						TableInventory.StructuralUnit AS StructuralUnit,
	|						TableInventory.InventoryAccountType AS InventoryAccountType,
	|						TableInventory.Products AS Products,
	|						TableInventory.Characteristic AS Characteristic,
	|						TableInventory.Batch AS Batch,
	|						TableInventory.Ownership AS Ownership,
	|						TableInventory.CostObject AS CostObject
	|					FROM
	|						TemporaryTableProductsOwnership AS TableInventory)) AS InventoryBalances
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
	
	TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company",		  	  RowTableInventory.Company);
		StructureForSearch.Insert("PresentationCurrency", RowTableInventory.PresentationCurrency);
		StructureForSearch.Insert("StructuralUnit",	      RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("InventoryAccountType", RowTableInventory.InventoryAccountType);
		StructureForSearch.Insert("Products",		      RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic",       RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch",			      RowTableInventory.Batch);
		StructureForSearch.Insert("Ownership",		      RowTableInventory.Ownership);
		StructureForSearch.Insert("CostObject",		      RowTableInventory.CostObject);
		
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
			
			// Expense. Inventory.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
			TableRowExpense.SalesOrder = Undefined;
			
			If Round(AmountToBeWrittenOff, 2, 1) <> 0
				And (DocumentRef.OperationType = Enums.OperationTypesGoodsIssue.SaleToCustomer
				Or DocumentRef.OperationType = Enums.OperationTypesGoodsIssue.DropShipping)
				And RowTableInventory.SalesInvoice = Documents.SalesInvoice.EmptyRef()
				And StructureAdditionalProperties.AccountingPolicy.ContinentalMethod Then
				
				// Move income and expenses.
				RowIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
				FillPropertyValues(RowIncomeAndExpenses, RowTableInventory);
				
				RowIncomeAndExpenses.Recorder = RowTableInventory.Document;
				RowIncomeAndExpenses.Active = True;
				RowIncomeAndExpenses.GLAccount = RowTableInventory.GLAccountCost;
				RowIncomeAndExpenses.IncomeAndExpenseItem = RowTableInventory.CorrIncomeAndExpenseItem;
				
				RowIncomeAndExpenses.AmountIncome = 0;
				RowIncomeAndExpenses.AmountExpense = AmountToBeWrittenOff;
				RowIncomeAndExpenses.ContentOfAccountingRecord = NStr("en = 'Cost of goods sold'; ru = 'Себестоимость';pl = 'Koszt własny towarów sprzedanych';es_ES = 'Coste de mercancías vendidas';es_CO = 'Coste de mercancías vendidas';tr = 'Satılan malların maliyeti';it = 'Costo dei beni venduti';de = 'Wareneinsatz'", MainLanguageCode);
				
			EndIf;
			
			// Generate postings.
			If UseDefaultTypeOfAccounting And Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
				RowTableAccountingJournalEntries.Amount = AmountToBeWrittenOff;
			EndIf;
			
			If (DocumentRef.OperationType = Enums.OperationTypesGoodsIssue.SaleToCustomer
					Or DocumentRef.OperationType = Enums.OperationTypesGoodsIssue.DropShipping)
					And Not ValueIsFilled(RowTableInventory.SalesInvoice)
					And Not StructureAdditionalProperties.AccountingPolicy.ContinentalMethod 
				Or DocumentRef.OperationType = Enums.OperationTypesGoodsIssue.TransferToAThirdParty 
				Or DocumentRef.OperationType = Enums.OperationTypesGoodsIssue.IntraCommunityTransfer
				Or DocumentRef.OperationType = Enums.OperationTypesGoodsIssue.TransferToSubcontractor Then
				
				TableRowReceipt = TemporaryTableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory,,"StructuralUnit, StructuralUnitCorr");
				
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
				
				TableRowReceipt.Company = RowTableInventory.CorrOrganization;
				TableRowReceipt.PresentationCurrency = RowTableInventory.CorrPresentationCurrency;
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.InventoryAccountType = RowTableInventory.CorrInventoryAccountType;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.Products = RowTableInventory.ProductsCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.Ownership = RowTableInventory.OwnershipCorr;
				
				TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
				
				TableRowReceipt.CorrOrganization = RowTableInventory.Company;
				TableRowReceipt.CorrPresentationCurrency = RowTableInventory.PresentationCurrency;
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrInventoryAccountType = RowTableInventory.InventoryAccountType;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsCorr = RowTableInventory.Products;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.OwnershipCorr = RowTableInventory.Ownership;
				
				TableRowReceipt.CustomerCorrOrder = Undefined;
				
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = QuantityRequiredAvailableBalance;
				
				If DocumentRef.OperationType = Enums.OperationTypesGoodsIssue.IntraCommunityTransfer Then
					TableRowReceipt.ContentOfAccountingRecord = NStr("en = 'Goods in transit'; ru = 'Товары в пути';pl = 'Towary w tranzycie';es_ES = 'Mercancías en tránsito';es_CO = 'Mercancías en tránsito';tr = 'Transit mallar';it = 'Merci in transito';de = 'Waren in Transit'", MainLanguageCode);
				ElsIf DocumentRef.OperationType = Enums.OperationTypesGoodsIssue.TransferToSubcontractor Then
					TableRowReceipt.ContentOfAccountingRecord = NStr("en = 'Transfered to subcontractor'; ru = 'Передано переработчику';pl = 'Przeniesiono do podwykonawcy';es_ES = 'Transferido al subcontratista';es_CO = 'Transferido al subcontratista';tr = 'Alt yükleniciye taşındı';it = 'Trasferito al subfornitore';de = 'Auf Subunternehmer übertragen'", MainLanguageCode);
				Else
					TableRowReceipt.ContentOfAccountingRecord = NStr("en = 'Inventory transfer'; ru = 'Перемещение запасов';pl = 'Przesunięcie międzymagazynowe';es_ES = 'Traslado del inventario';es_CO = 'Transferencia de inventario';tr = 'Stok transferi';it = 'Movimenti di scorte';de = 'Bestandsumlagerung'", MainLanguageCode);
				EndIf;
				
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
EndProcedure

Procedure GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	TemporaryTableProducts.Period AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TemporaryTableProducts.Company AS Company,
	|	TemporaryTableProducts.GLAccount AS AccountCr,
	|	TemporaryTableProducts.CorrGLAccount AS AccountDr,
	|	TemporaryTableProducts.Currency AS Currency,
	|	TemporaryTableProducts.OperationType AS Content,
	|	TemporaryTableProducts.Amount AS Amount
	|FROM
	|	TemporaryTableProductsOwnership AS TemporaryTableProducts
	|WHERE
	|	TemporaryTableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.PurchaseReturn)";
	
	TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
		FillPropertyValues(RowTableAccountingJournalEntries, Selection);
	EndDo;
	
EndProcedure

Procedure GenerateTableInventoryInWarehouses(DocumentRef, StructureAdditionalProperties)
	
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
	|	TemporaryTableProductsOwnership AS TableInventoryInWarehouses
	|WHERE
	|	NOT TableInventoryInWarehouses.OperationType = VALUE(Enum.OperationTypesGoodsIssue.DropShipping)
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
	
	If DocumentRef.SerialNumbers.Count() = 0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	VALUE(Enum.SerialNumbersOperations.Expense) AS Operation,
	|	TemporaryTableInventory.Period AS EventDate,
	|	SerialNumbers.SerialNumber AS SerialNumber,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.Products AS Products,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	TemporaryTableInventory.Batch AS Batch,
	|	TemporaryTableInventory.StructuralUnit AS StructuralUnit,
	|	TemporaryTableInventory.Cell AS Cell,
	|	TemporaryTableInventory.Ownership AS Ownership,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableProducts AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
	|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey
	|WHERE
	|	NOT TemporaryTableInventory.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTableProductsOwnership.Period,
	|	VALUE(AccumulationRecordType.Expense),
	|	VALUE(Enum.SerialNumbersOperations.Expense),
	|	TemporaryTableProductsOwnership.Period,
	|	TemporaryTableProductsOwnership.SerialNumber,
	|	TemporaryTableProductsOwnership.Company,
	|	TemporaryTableProductsOwnership.Products,
	|	TemporaryTableProductsOwnership.Characteristic,
	|	TemporaryTableProductsOwnership.Batch,
	|	TemporaryTableProductsOwnership.StructuralUnit,
	|	TemporaryTableProductsOwnership.Cell,
	|	TemporaryTableProductsOwnership.Ownership,
	|	1
	|FROM
	|	TemporaryTableProductsOwnership AS TemporaryTableProductsOwnership
	|WHERE
	|	TemporaryTableProductsOwnership.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|	AND NOT TemporaryTableProductsOwnership.SerialNumber = VALUE(Catalog.SerialNumbers.EmptyRef)";
	
	QueryResult = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", QueryResult);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
	EndIf;
	
EndProcedure

Procedure GenerateTableGoodsShippedNotInvoiced(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableProducts.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProducts.Period AS Period,
	|	&Ref AS GoodsIssue,
	|	TableProducts.Company AS Company,
	|	TableProducts.Counterparty AS Counterparty,
	|	TableProducts.Contract AS Contract,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.Ownership AS Ownership,
	|	TableProducts.Order AS SalesOrder,
	|	SUM(TableProducts.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProductsOwnership AS TableProducts
	|WHERE
	|	(TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|			OR TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.DropShipping))
	|	AND TableProducts.SalesInvoice = VALUE(Document.SalesInvoice.EmptyRef)
	|
	|GROUP BY
	|	TableProducts.Period,
	|	TableProducts.Company,
	|	TableProducts.Counterparty,
	|	TableProducts.Contract,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.Ownership,
	|	TableProducts.Order";
	
	Query.SetParameter("Ref", DocumentRef);
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsShippedNotInvoiced", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableGoodsInvoicedNotShipped(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
#Region GenerateTableGoodsInvoicedNotShippedQueryText
	
	Query.Text =
	"SELECT
	|	TableProducts.SalesInvoice AS SalesInvoice,
	|	TableProducts.Company AS Company,
	|	TableProducts.PresentationCurrency AS PresentationCurrency,
	|	TableProducts.Counterparty AS Counterparty,
	|	TableProducts.Contract AS Contract,
	|	TableProducts.Order AS SalesOrder,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.Ownership AS Ownership,
	|	SUM(TableProducts.Quantity) AS Quantity,
	|	TableProducts.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProducts.BusinessLineSales AS BusinessLine,
	|	TableProducts.RevenueItem AS RevenueItem,
	|	TableProducts.COGSItem AS COGSItem,
	|	TableProducts.AccountStatementSales AS GLAccountSales,
	|	TableProducts.GLAccountCost AS GLAccountCost,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableProducts.AccountStatementSales AS AccountCr,
	|	TableProducts.AccountStatementDeferredSales AS AccountDr,
	|	TableProducts.SalesRep AS SalesRep
	|FROM
	|	TemporaryTableProductsOwnership AS TableProducts
	|WHERE
	|	(TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|			OR TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.DropShipping))
	|	AND TableProducts.SalesInvoice <> VALUE(Document.SalesInvoice.EmptyRef)
	|	AND TableProducts.Quantity > 0
	|
	|GROUP BY
	|	TableProducts.SalesInvoice,
	|	TableProducts.Company,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.Counterparty,
	|	TableProducts.Contract,
	|	TableProducts.Order,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.Ownership,
	|	TableProducts.Period,
	|	TableProducts.BusinessLineSales,
	|	TableProducts.RevenueItem,
	|	TableProducts.COGSItem,
	|	TableProducts.AccountStatementSales,
	|	TableProducts.GLAccountCost,
	|	TableProducts.AccountStatementDeferredSales,
	|	TableProducts.SalesRep,
	|	TableProducts.AccountStatementSales";
	
#EndRegion

	Query.SetParameter("Ref", DocumentRef);
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsInvoicedNotShipped", New ValueTable);
		Return;
	EndIf;
	
	TableInventory = QueryResult.Unload();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.GoodsInvoicedNotShipped");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	StructureForSearch = New Structure;
	
	MetaRegisterDimensions = Metadata.AccumulationRegisters.GoodsInvoicedNotShipped.Dimensions;
	For Each ColumnQueryResult In QueryResult.Columns Do
		If MetaRegisterDimensions.Find(ColumnQueryResult.Name) <> Undefined
			And ValueIsFilled(ColumnQueryResult.ValueType) Then
			LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
			StructureForSearch.Insert(ColumnQueryResult.Name);
		EndIf;
	EndDo;
	Block.Lock();
	
#Region GenerateTableGoodsInvoicedNotShippedBalancesQueryText
	
	Query.Text =
	"SELECT
	|	UNDEFINED AS Period,
	|	UNDEFINED AS RecordType,
	|	Balances.SalesInvoice AS SalesInvoice,
	|	Balances.Company AS Company,
	|	Balances.PresentationCurrency AS PresentationCurrency,
	|	Balances.Counterparty AS Counterparty,
	|	Balances.Contract AS Contract,
	|	Balances.SalesOrder AS SalesOrder,
	|	Balances.Products AS Products,
	|	Balances.Characteristic AS Characteristic,
	|	Balances.Batch AS Batch,
	|	VALUE(Catalog.InventoryOwnership.EmptyRef) AS Ownership,
	|	Balances.VATRate AS VATRate,
	|	Balances.Department AS Department,
	|	Balances.Responsible AS Responsible,
	|	SUM(Balances.Quantity) AS Quantity,
	|	SUM(Balances.Amount) AS Amount,
	|	SUM(Balances.VATAmount) AS VATAmount,
	|	SUM(Balances.AmountCur) AS AmountCur,
	|	SUM(Balances.VATAmountCur) AS VATAmountCur,
	|	ISNULL(DocumentSalesInvoice.DocumentCurrency, VALUE(Catalog.Currencies.EmptyRef)) AS Currency
	|FROM
	|	(SELECT
	|		Balances.SalesInvoice AS SalesInvoice,
	|		Balances.Company AS Company,
	|		Balances.PresentationCurrency AS PresentationCurrency,
	|		Balances.Counterparty AS Counterparty,
	|		Balances.Contract AS Contract,
	|		Balances.SalesOrder AS SalesOrder,
	|		Balances.Products AS Products,
	|		Balances.Characteristic AS Characteristic,
	|		Balances.Batch AS Batch,
	|		Balances.VATRate AS VATRate,
	|		Balances.Department AS Department,
	|		Balances.Responsible AS Responsible,
	|		Balances.QuantityBalance AS Quantity,
	|		Balances.AmountBalance AS Amount,
	|		Balances.VATAmountBalance AS VATAmount,
	|		Balances.AmountCurBalance AS AmountCur,
	|		Balances.VATAmountCurBalance AS VATAmountCur
	|	FROM
	|		AccumulationRegister.GoodsInvoicedNotShipped.Balance(
	|				&ControlTime,
	|				(SalesInvoice, Company, PresentationCurrency, Counterparty, Contract, SalesOrder, Products, Characteristic, Batch) IN
	|					(SELECT
	|						TableProducts.SalesInvoice AS SalesInvoice,
	|						TableProducts.Company AS Company,
	|						TableProducts.PresentationCurrency AS PresentationCurrency,
	|						TableProducts.Counterparty AS Counterparty,
	|						TableProducts.Contract AS Contract,
	|						TableProducts.Order AS SalesOrder,
	|						TableProducts.Products AS Products,
	|						TableProducts.Characteristic AS Characteristic,
	|						TableProducts.Batch AS Batch
	|					FROM
	|						TemporaryTableProductsOwnership AS TableProducts)) AS Balances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRecords.SalesInvoice,
	|		DocumentRecords.Company,
	|		DocumentRecords.PresentationCurrency,
	|		DocumentRecords.Counterparty,
	|		DocumentRecords.Contract,
	|		DocumentRecords.SalesOrder,
	|		DocumentRecords.Products,
	|		DocumentRecords.Characteristic,
	|		DocumentRecords.Batch,
	|		DocumentRecords.VATRate,
	|		DocumentRecords.Department,
	|		DocumentRecords.Responsible,
	|		DocumentRecords.Quantity,
	|		DocumentRecords.Amount,
	|		DocumentRecords.VATAmount,
	|		DocumentRecords.AmountCur,
	|		DocumentRecords.VATAmountCur
	|	FROM
	|		AccumulationRegister.GoodsInvoicedNotShipped AS DocumentRecords
	|	WHERE
	|		DocumentRecords.Recorder = &Ref
	|		AND DocumentRecords.Period <= &ControlPeriod) AS Balances
	|		LEFT JOIN Document.SalesInvoice AS DocumentSalesInvoice
	|		ON Balances.SalesInvoice = DocumentSalesInvoice.Ref
	|
	|GROUP BY
	|	Balances.SalesInvoice,
	|	Balances.Company,
	|	Balances.PresentationCurrency,
	|	Balances.Counterparty,
	|	Balances.Contract,
	|	Balances.SalesOrder,
	|	Balances.Products,
	|	Balances.Characteristic,
	|	Balances.Batch,
	|	Balances.VATRate,
	|	Balances.Department,
	|	Balances.Responsible,
	|	ISNULL(DocumentSalesInvoice.DocumentCurrency, VALUE(Catalog.Currencies.EmptyRef))";
	
#EndRegion
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableBalances = QueryResult.Unload();
	TableBalances.Indexes.Add("SalesInvoice, Company, PresentationCurrency, Counterparty, Contract, SalesOrder, Products, Characteristic, Batch");
	
	TemporaryTableInventory = TableBalances.CopyColumns();
	
	TablesForRegisterRecords = StructureAdditionalProperties.TableForRegisterRecords;
	
	TableAccountingJournalEntries = TablesForRegisterRecords.TableAccountingJournalEntries;
	TableIncomeAndExpenses = TablesForRegisterRecords.TableIncomeAndExpenses;
	TableSales = TablesForRegisterRecords.TableSales;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	ContentTextIncome = NStr("en = 'Revenue'; ru = 'Отражение доходов';pl = 'Przychód';es_ES = 'Ingreso';es_CO = 'Ingreso';tr = 'Gelir';it = 'Ricavo';de = 'Erlös'", MainLanguageCode);
	ContentTextGost = NStr("en = 'Cost of goods sold'; ru = 'Себестоимость';pl = 'Koszt własny towarów sprzedanych';es_ES = 'Coste de mercancías vendidas';es_CO = 'Coste de mercancías vendidas';tr = 'Satılan malların maliyeti';it = 'Costo dei beni venduti';de = 'Wareneinsatz'", MainLanguageCode);
	
	UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;
	
	TableInventoryBalances = TablesForRegisterRecords.TableInventory.Copy();
	StructureForSearchInventoryBalances = New Structure("Company, PresentationCurrency, Products, Characteristic, Batch, Ownership");
	
	For Each TableInventoryRow In TableInventory Do
		
		FillPropertyValues(StructureForSearch, TableInventoryRow);
		
		BalanceRowsArray = TableBalances.FindRows(StructureForSearch);
		
		QuantityToBeWrittenOff = TableInventoryRow.Quantity;
		
		For Each TableBalancesRow In BalanceRowsArray Do
			
			If TableBalancesRow.Quantity > 0 Then
				
				NewRow = TemporaryTableInventory.Add();
				FillPropertyValues(NewRow, TableBalancesRow, , "Quantity, Amount, VATAmount, AmountCur, VATAmountCur");
				FillPropertyValues(NewRow, TableInventoryRow, "Period, RecordType, Ownership");
				
				NewRow.Quantity = Min(TableBalancesRow.Quantity, QuantityToBeWrittenOff);
				
				If NewRow.Quantity < TableBalancesRow.Quantity Then
					
					NewRow.Amount = Round(TableBalancesRow.Amount * NewRow.Quantity / TableBalancesRow.Quantity, 2, 1);
					NewRow.VATAmount = Round(TableBalancesRow.VATAmount * NewRow.Quantity / TableBalancesRow.Quantity, 2, 1);
					NewRow.AmountCur = Round(TableBalancesRow.AmountCur * NewRow.Quantity / TableBalancesRow.Quantity, 2, 1);
					NewRow.VATAmountCur = Round(TableBalancesRow.VATAmountCur * NewRow.Quantity / TableBalancesRow.Quantity, 2, 1);
					QuantityToBeWrittenOff = 0;
					TableBalancesRow.Quantity = TableBalancesRow.Quantity - NewRow.Quantity;
					TableBalancesRow.Amount = TableBalancesRow.Amount - NewRow.Amount;
					TableBalancesRow.VATAmount = TableBalancesRow.VATAmount - NewRow.VATAmount;
					TableBalancesRow.AmountCur = TableBalancesRow.AmountCur - NewRow.AmountCur;
					TableBalancesRow.VATAmountCur = TableBalancesRow.VATAmountCur - NewRow.VATAmountCur;
					
				Else
					
					NewRow.Amount = TableBalancesRow.Amount;
					NewRow.VATAmount = TableBalancesRow.VATAmount;
					NewRow.AmountCur = TableBalancesRow.AmountCur;
					NewRow.VATAmountCur = TableBalancesRow.VATAmountCur;
					QuantityToBeWrittenOff = QuantityToBeWrittenOff - NewRow.Quantity;
					TableBalancesRow.Quantity = 0;
					TableBalancesRow.Amount = 0;
					TableBalancesRow.VATAmount = 0;
					TableBalancesRow.AmountCur = 0;
					TableBalancesRow.VATAmountCur = 0;
					
				EndIf;
				
				CostAmount = 0;
				CostQuantity = NewRow.Quantity;
				
				FillPropertyValues(StructureForSearchInventoryBalances, NewRow);
				InventoryBalancesRows = TableInventoryBalances.FindRows(StructureForSearchInventoryBalances);
				For Each InventoryBalancesRow In InventoryBalancesRows Do
					
					If InventoryBalancesRow.Quantity > 0 Then
						CurrentCostQuantity = Min(CostQuantity, InventoryBalancesRow.Quantity);
						If CurrentCostQuantity < InventoryBalancesRow.Quantity Then
							CostAmount = CostAmount + Round(InventoryBalancesRow.Amount * CurrentCostQuantity / InventoryBalancesRow.Quantity, 2, 1);
							CostQuantity = 0;
							InventoryBalancesRow.Quantity = InventoryBalancesRow.Quantity - CurrentCostQuantity;
							InventoryBalancesRow.Amount = InventoryBalancesRow.Amount - CostAmount;
						Else
							CostAmount = CostAmount + InventoryBalancesRow.Amount;
							CostQuantity = CostQuantity - CurrentCostQuantity;
							InventoryBalancesRow.Quantity = 0;
							InventoryBalancesRow.Amount = 0;
						EndIf;
					EndIf;
					If CostQuantity = 0 Then
						Break;
					EndIf;
					
				EndDo;
				
				IncomeAndExpensesRow = TableIncomeAndExpenses.Add();
				FillPropertyValues(IncomeAndExpensesRow, TableInventoryRow);
				IncomeAndExpensesRow.Active = True;
				IncomeAndExpensesRow.StructuralUnit = NewRow.Department;
				IncomeAndExpensesRow.SalesOrder = ?(ValueIsFilled(TableInventoryRow.SalesOrder), TableInventoryRow.SalesOrder, Undefined);
				IncomeAndExpensesRow.IncomeAndExpenseItem = TableInventoryRow.RevenueItem;
				IncomeAndExpensesRow.GLAccount = TableInventoryRow.GLAccountSales;
				IncomeAndExpensesRow.AmountIncome = NewRow.Amount;
				IncomeAndExpensesRow.ContentOfAccountingRecord = ContentTextIncome;
				
				SalesRow = TableSales.Add();
				FillPropertyValues(SalesRow, NewRow);
				SalesRow.Active = True;
				SalesRow.Document = NewRow.SalesInvoice;
				SalesRow.SalesRep = TableInventoryRow.SalesRep;
				
				If UseDefaultTypeOfAccounting Then
					
					TableAccountingRow = TableAccountingJournalEntries.Add();
					FillPropertyValues(TableAccountingRow, TableInventoryRow);
					TableAccountingRow.Amount = NewRow.Amount;
					TableAccountingRow.Content = ContentTextIncome;
					
				EndIf;
				
				If CostAmount <> 0 Then
					
					IncomeAndExpensesRow = TableIncomeAndExpenses.Add();
					FillPropertyValues(IncomeAndExpensesRow, TableInventoryRow);
					IncomeAndExpensesRow.Active = True;
					IncomeAndExpensesRow.StructuralUnit = NewRow.Department;
					IncomeAndExpensesRow.SalesOrder = ?(ValueIsFilled(TableInventoryRow.SalesOrder), TableInventoryRow.SalesOrder, Undefined);
					IncomeAndExpensesRow.IncomeAndExpenseItem = TableInventoryRow.COGSItem;
					IncomeAndExpensesRow.GLAccount = TableInventoryRow.GLAccountCost;
					IncomeAndExpensesRow.AmountExpense = CostAmount;
					IncomeAndExpensesRow.ContentOfAccountingRecord = ContentTextGost;
					
					SalesRow = TableSales.Add();
					FillPropertyValues(SalesRow, NewRow);
					SalesRow.SalesRep = TableInventoryRow.SalesRep;
					SalesRow.Active = True;
					SalesRow.Document = NewRow.SalesInvoice;
					SalesRow.Quantity = 0;
					SalesRow.Amount = 0;
					SalesRow.VATAmount = 0;
					SalesRow.AmountCur = 0;
					SalesRow.VATAmountCur = 0;
					SalesRow.Cost = CostAmount;
					
				EndIf;
				
			EndIf;
			
			If QuantityToBeWrittenOff = 0 Then
				Break;
			EndIf;
			
		EndDo;
		
		If QuantityToBeWrittenOff > 0 Then
			
			NewRow = TemporaryTableInventory.Add();
			FillPropertyValues(NewRow, TableInventoryRow, , "Quantity");
			NewRow.Quantity = QuantityToBeWrittenOff;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsInvoicedNotShipped", TemporaryTableInventory);
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", TableIncomeAndExpenses);
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", TableSales);
	
EndProcedure

Procedure GenerateTableStockReceivedFromThirdParties(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	MIN(TableStockReceivedFromThirdParties.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
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
	|	SUM(TableStockReceivedFromThirdParties.Quantity) AS Quantity,
	|	CAST(&InventoryReception AS STRING(100)) AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableProductsOwnership AS TableStockReceivedFromThirdParties
	|WHERE
	|	TableStockReceivedFromThirdParties.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToAThirdParty)
	|
	|GROUP BY
	|	TableStockReceivedFromThirdParties.Period,
	|	TableStockReceivedFromThirdParties.Company,
	|	TableStockReceivedFromThirdParties.Products,
	|	TableStockReceivedFromThirdParties.Characteristic,
	|	TableStockReceivedFromThirdParties.Batch,
	|	TableStockReceivedFromThirdParties.Counterparty,
	|	TableStockReceivedFromThirdParties.Order,
	|	TableStockReceivedFromThirdParties.GLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	MIN(TableStockReceivedFromThirdParties.LineNumber),
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableStockReceivedFromThirdParties.Period,
	|	TableStockReceivedFromThirdParties.Company,
	|	TableStockReceivedFromThirdParties.Products,
	|	TableStockReceivedFromThirdParties.Characteristic,
	|	TableStockReceivedFromThirdParties.Batch,
	|	UNDEFINED,
	|	TableStockReceivedFromThirdParties.Order,
	|	TableStockReceivedFromThirdParties.GLAccountVendorSettlements,
	|	SUM(TableStockReceivedFromThirdParties.Quantity),
	|	CAST(&InventoryIncreaseProductsOnCommission AS STRING(100))
	|FROM
	|	TemporaryTableProductsOwnership AS TableStockReceivedFromThirdParties
	|WHERE
	|	TableStockReceivedFromThirdParties.ProductsOnCommission
	|
	|GROUP BY
	|	TableStockReceivedFromThirdParties.Period,
	|	TableStockReceivedFromThirdParties.Company,
	|	TableStockReceivedFromThirdParties.Products,
	|	TableStockReceivedFromThirdParties.Characteristic,
	|	TableStockReceivedFromThirdParties.Batch,
	|	TableStockReceivedFromThirdParties.Counterparty,
	|	TableStockReceivedFromThirdParties.Order,
	|	TableStockReceivedFromThirdParties.GLAccountVendorSettlements,
	|	TableStockReceivedFromThirdParties.GLAccount";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("InventoryReception", "");
	Query.SetParameter("InventoryIncreaseProductsOnCommission", NStr("en = 'Inventory increase'; ru = 'Оприходование запасов';pl = 'Zwiększenie zapasów';es_ES = 'Aumento de inventario';es_CO = 'Aumento de inventario';tr = 'Stok artırma';it = 'Aumento scorte';de = 'Bestandserhöhung'", MainLanguageCode));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockReceivedFromThirdParties", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableStockTransferredToThirdParties(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableStockTransferredToThirdParties.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableStockTransferredToThirdParties.Period AS Period,
	|	TableStockTransferredToThirdParties.Company AS Company,
	|	TableStockTransferredToThirdParties.Products AS Products,
	|	TableStockTransferredToThirdParties.Characteristic AS Characteristic,
	|	TableStockTransferredToThirdParties.Batch AS Batch,
	|	TableStockTransferredToThirdParties.Counterparty AS Counterparty,
	|	CASE
	|		WHEN TableStockTransferredToThirdParties.Order REFS Document.SalesOrder
	|				AND TableStockTransferredToThirdParties.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN TableStockTransferredToThirdParties.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	SUM(TableStockTransferredToThirdParties.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProductsOwnership AS TableStockTransferredToThirdParties
	|WHERE
	|	TableStockTransferredToThirdParties.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
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
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableStockTransferredToThirdParties.Period,
	|	TableStockTransferredToThirdParties.Company,
	|	TableStockTransferredToThirdParties.Products,
	|	TableStockTransferredToThirdParties.Characteristic,
	|	TableStockTransferredToThirdParties.Batch,
	|	TableStockTransferredToThirdParties.Counterparty,
	|	CASE
	|		WHEN TableStockTransferredToThirdParties.Order REFS Document.SubcontractorOrderIssued
	|				AND TableStockTransferredToThirdParties.Order <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|			THEN TableStockTransferredToThirdParties.Order
	|		ELSE UNDEFINED
	|	END,
	|	SUM(TableStockTransferredToThirdParties.Quantity)
	|FROM
	|	TemporaryTableProducts AS TableStockTransferredToThirdParties
	|WHERE
	|	TableStockTransferredToThirdParties.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractor)
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
	|	-SUM(TablePurchaseOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProductsOwnership AS TablePurchaseOrders
	|WHERE
	|	TablePurchaseOrders.Order REFS Document.PurchaseOrder
	|	AND TablePurchaseOrders.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|	AND TablePurchaseOrders.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToAThirdParty)
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

Procedure GenerateTableInventoryDemand(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =

	"SELECT
	|	BillsOfMaterialsContent.Products AS Products,
	|	BillsOfMaterialsContent.Characteristic AS Characteristic,
	|	FALSE
	// begin Drive.FullVersion
	|		OR SubcontractorOrder.BasisDocument REFS Document.ManufacturingOperation
	|			AND SubcontractorOrder.BasisDocument <> VALUE(Document.ManufacturingOperation.EmptyRef)
	// end Drive.FullVersion
	|	AS IsBasedOnWIP,
	|	MAX(BillsOfMaterialsContent.ManufacturedInProcess) AS ManufacturedInProcess
	|INTO BOM
	|FROM
	|	GoodsIssueHeader AS GoodsIssueHeader
	|		INNER JOIN Document.SubcontractorOrderIssued AS SubcontractorOrder
	|		ON SubcontractorOrder.Ref = GoodsIssueHeader.Order
	|		INNER JOIN Document.SubcontractorOrderIssued.Products AS SubcontractorOrderProducts
	|		ON SubcontractorOrderProducts.Ref = GoodsIssueHeader.Order
	|		LEFT JOIN Catalog.BillsOfMaterials AS BillsOfMaterials
	|		ON SubcontractorOrderProducts.Specification = BillsOfMaterials.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON (BillsOfMaterialsContent.Ref = BillsOfMaterials.Ref)
	|WHERE
	|	GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractor)
	|
	|GROUP BY
	|	BillsOfMaterialsContent.Products,
	|	BillsOfMaterialsContent.Characteristic,
	|	FALSE
	// begin Drive.FullVersion
	|		OR SubcontractorOrder.BasisDocument REFS Document.ManufacturingOperation
	|			AND SubcontractorOrder.BasisDocument <> VALUE(Document.ManufacturingOperation.EmptyRef)
	// end Drive.FullVersion
	|;
	|
	|SELECT
	|	TableInventoryDemand.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventoryDemand.Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableInventoryDemand.Products AS Products,
	|	TableInventoryDemand.Characteristic AS Characteristic,
	|	VALUE(Document.SalesOrder.EmptyRef) AS SalesOrder,
	|	UNDEFINED AS ProductionDocument,
	|	SUM(TableInventoryDemand.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProductsOwnership AS TableInventoryDemand
	|WHERE
	|	TableInventoryDemand.Order REFS Document.PurchaseOrder
	|	AND TableInventoryDemand.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|	AND TableInventoryDemand.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
	|
	|GROUP BY
	|	TableInventoryDemand.Period,
	|	TableInventoryDemand.Company,
	|	TableInventoryDemand.Products,
	|	TableInventoryDemand.Characteristic
	|
	|UNION ALL
	|
	|SELECT
	|	TableInventoryDemand.Period,
	|	VALUE(AccumulationRecordType.Expense),
	|	TableInventoryDemand.Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment),
	|	TableInventoryDemand.Products,
	|	TableInventoryDemand.Characteristic,
	|	VALUE(Document.SalesOrder.EmptyRef),
	|	TableInventoryDemand.Order,
	|	SUM(TableInventoryDemand.Quantity)
	|FROM
	|	TemporaryTableProducts AS TableInventoryDemand
	|		LEFT JOIN BOM AS BOM
	|		ON (TableInventoryDemand.Products = BOM.Products)
	|			AND (TableInventoryDemand.Characteristic = BOM.Characteristic)
	|	
	|WHERE
	|	TableInventoryDemand.Order REFS Document.SubcontractorOrderIssued
	|	AND TableInventoryDemand.Order <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|	AND TableInventoryDemand.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractor)
	|	AND (NOT BOM.IsBasedOnWIP
	|			OR ISNULL(BOM.ManufacturedInProcess, FALSE) = FALSE)
	|
	|GROUP BY
	|	TableInventoryDemand.Period,
	|	TableInventoryDemand.Company,
	|	TableInventoryDemand.Products,
	|	TableInventoryDemand.Characteristic,
	|	TableInventoryDemand.Order
	// begin Drive.FullVersion
	|
	|UNION ALL
	|
	|SELECT
	|	TableInventoryDemand.Period,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableInventoryDemand.Company,
	|	VALUE(Enum.InventoryMovementTypes.Receipt),
	|	TableInventoryDemand.Products,
	|	TableInventoryDemand.Characteristic,
	|	TableInventoryDemand.Order,
	|	UNDEFINED,
	|	SUM(TableInventoryDemand.Quantity)
	|FROM
	|	TemporaryTableProducts AS TableInventoryDemand
	|WHERE
	|	TableInventoryDemand.Order REFS Document.SubcontractorOrderReceived
	|	AND TableInventoryDemand.Order <> VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	|	AND TableInventoryDemand.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer)
	|
	|GROUP BY
	|	TableInventoryDemand.Period,
	|	TableInventoryDemand.Company,
	|	TableInventoryDemand.Products,
	|	TableInventoryDemand.Characteristic,
	|	TableInventoryDemand.Order
	// end Drive.FullVersion
	|";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", QueryResult.Unload());
	
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
	|	TableIncomeAndExpenses.StructuralUnit AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLineSales AS BusinessLine,
	|	TableIncomeAndExpenses.PurchaseReturnItem AS IncomeAndExpenseItem,
	|	TableIncomeAndExpenses.CorrGLAccount AS GLAccount,
	|	TableIncomeAndExpenses.Order AS SalesOrder,
	|	0 AS AmountIncome,
	|	SUM(TableIncomeAndExpenses.Amount) AS AmountExpense,
	|	&Content AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord,
	|	TRUE AS Active
	|FROM
	|	TemporaryTableProductsOwnership AS TableIncomeAndExpenses
	|WHERE
	|	TableIncomeAndExpenses.OperationType = VALUE(Enum.OperationTypesGoodsIssue.PurchaseReturn)
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Document,
	|	TableIncomeAndExpenses.Period,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.StructuralUnit,
	|	TableIncomeAndExpenses.Order,
	|	TableIncomeAndExpenses.BusinessLineSales,
	|	TableIncomeAndExpenses.PurchaseReturnItem,
	|	TableIncomeAndExpenses.CorrGLAccount,
	|	TableIncomeAndExpenses.PresentationCurrency
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
	|	OfflineRecords.OfflineRecord,
	|	OfflineRecords.Active
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	Query.SetParameter("Content", NStr("en = 'Goods return'; ru = 'Возврат товара';pl = 'Zwrot towarów';es_ES = 'Devolución de productos';es_CO = 'Devolución de productos';tr = 'Mal iadesi';it = 'Restituzione merci';de = 'Warenrücksendung'", CommonClientServer.DefaultLanguageCode()));
	Query.SetParameter("Ref", DocumentRef);
	
	TableIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses;
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		RowTableIncomeAndExpensesEntries = TableIncomeAndExpenses.Add();
		FillPropertyValues(RowTableIncomeAndExpensesEntries, Selection);
	EndDo;
	
EndProcedure

Procedure GenerateTableReservedProducts(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	SUM(TableInventory.Quantity) AS Quantity
	|INTO ReservedProducts
	|FROM
	|	(SELECT
	|		TableInventory.Period AS Period,
	|		TableInventory.Company AS Company,
	|		TableInventory.GLAccount AS GLAccount,
	|		TableInventory.StructuralUnit AS StructuralUnit,
	|		TableInventory.Products AS Products,
	|		TableInventory.Characteristic AS Characteristic,
	|		TableInventory.Batch AS Batch,
	|		TableInventory.Order AS SalesOrder,
	|		TableInventory.Quantity AS Quantity
	|	FROM
	|		TemporaryTableProductsOwnership AS TableInventory
	|	WHERE
	|		TableInventory.Order REFS Document.SalesOrder
	|		AND TableInventory.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|		AND TableInventory.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableInventory.Period,
	|		TableInventory.Company,
	|		TableInventory.GLAccount,
	|		TableInventory.StructuralUnit,
	|		TableInventory.Products,
	|		TableInventory.Characteristic,
	|		TableInventory.Batch,
	|		TableInventory.Order,
	|		TableInventory.Quantity
	|	FROM
	|		TemporaryTableProductsOwnership AS TableInventory
	|	WHERE
	|		TableInventory.Order REFS Document.PurchaseOrder
	|		AND TableInventory.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|		AND TableInventory.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)) AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.GLAccount,
	|	TableInventory.SalesOrder,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.Products
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.SalesOrder AS SalesOrder
	|FROM
	|	ReservedProducts AS TableInventory";
	
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
	|				&ControlTime,
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
	|	TableInventory.SalesOrder AS SalesOrder,
	|	CASE
	|		WHEN Balance.Quantity > TableInventory.Quantity
	|			THEN TableInventory.Quantity
	|		ELSE Balance.Quantity
	|	END AS Quantity
	|INTO AvailableReserve
	|FROM
	|	ReservedProducts AS TableInventory
	|		INNER JOIN ReservedProductsBalance AS Balance
	|		ON TableInventory.Company = Balance.Company
	|			AND TableInventory.StructuralUnit = Balance.StructuralUnit
	|			AND TableInventory.Products = Balance.Products
	|			AND TableInventory.Characteristic = Balance.Characteristic
	|			AND TableInventory.Batch = Balance.Batch
	|			AND TableInventory.SalesOrder = Balance.SalesOrder
	|WHERE
	|	TableInventory.Quantity > 0
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
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableGoodsInTransit(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableProducts.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProducts.Period AS Period,
	|	&Ref AS GoodsIssue,
	|	TableProducts.Company AS Company,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	SUM(TableProducts.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProductsOwnership AS TableProducts
	|WHERE
	|	TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.IntraCommunityTransfer)
	|
	|GROUP BY
	|	TableProducts.Period,
	|	TableProducts.Company,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch";
	
	Query.SetParameter("Ref", DocumentRef);
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsInTransit", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableSubcontractComponents(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TemporaryTableProducts.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTableProducts.Period AS Period,
	|	TemporaryTableProducts.Products AS Products,
	|	TemporaryTableProducts.Characteristic AS Characteristic,
	|	SUM(TemporaryTableProducts.Quantity) AS Quantity,
	|	TemporaryTableProducts.Order AS SubcontractorOrder
	|FROM
	|	TemporaryTableProducts AS TemporaryTableProducts
	|WHERE
	|	TemporaryTableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractor)
	|	AND TemporaryTableProducts.Order REFS Document.SubcontractorOrderIssued
	|	AND TemporaryTableProducts.Order <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|
	|GROUP BY
	|	TemporaryTableProducts.Period,
	|	TemporaryTableProducts.Products,
	|	TemporaryTableProducts.Characteristic,
	|	TemporaryTableProducts.Order
	// begin Drive.FullVersion
	|
	|UNION ALL
	|
	|SELECT
	|	MIN(TemporaryTableProducts.LineNumber),
	|	VALUE(AccumulationRecordType.Expense),
	|	TemporaryTableProducts.Period,
	|	TemporaryTableProducts.Products,
	|	TemporaryTableProducts.Characteristic,
	|	SUM(TemporaryTableProducts.Quantity),
	|	TemporaryTableProducts.Order
	|FROM
	|	TemporaryTableProducts AS TemporaryTableProducts
	|WHERE
	|	TemporaryTableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer)
	|	AND TemporaryTableProducts.Order REFS Document.SubcontractorOrderReceived
	|	AND TemporaryTableProducts.Order <> VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	|
	|GROUP BY
	|	TemporaryTableProducts.Period,
	|	TemporaryTableProducts.Products,
	|	TemporaryTableProducts.Characteristic,
	|	TemporaryTableProducts.Order
	// end Drive.FullVersion
	|";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSubcontractComponents", QueryResult.Unload());
	
EndProcedure

// begin Drive.FullVersion
Procedure GenerateTableCustomerOwnedInventory(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled cutomer-owned inventory balances.
	Query.Text =
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.Counterparty AS Counterparty,
	|	TableInventory.Order AS SubcontractorOrder,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic
	|FROM
	|	TemporaryTableProducts AS TableInventory
	|WHERE
	|	TableInventory.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractingCustomer)
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.Counterparty,
	|	TableInventory.Order,
	|	TableInventory.Products,
	|	TableInventory.Characteristic";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.CustomerOwnedInventory");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving cutomer-owned inventory balances.
	Query.Text =
	"SELECT
	|	TemporaryTableProducts.Period AS Period,
	|	TemporaryTableProducts.Company AS Company,
	|	TemporaryTableProducts.Counterparty AS Counterparty,
	|	TemporaryTableProducts.Order AS SubcontractorOrder,
	|	TemporaryTableProducts.Products AS Products,
	|	TemporaryTableProducts.Characteristic AS Characteristic,
	|	SUM(TemporaryTableProducts.Quantity) AS QuantityToIssue,
	|	0 AS QuantityToInvoice
	|INTO TT_TemporaryTableProducts
	|FROM
	|	TemporaryTableProducts AS TemporaryTableProducts
	|WHERE
	|	TemporaryTableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractingCustomer)
	|	AND TemporaryTableProducts.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
	|
	|GROUP BY
	|	TemporaryTableProducts.Company,
	|	TemporaryTableProducts.Period,
	|	TemporaryTableProducts.Counterparty,
	|	TemporaryTableProducts.Order,
	|	TemporaryTableProducts.Products,
	|	TemporaryTableProducts.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CustomerOwnedInventoryBalance.Company AS Company,
	|	CustomerOwnedInventoryBalance.Counterparty AS Counterparty,
	|	CustomerOwnedInventoryBalance.SubcontractorOrder AS SubcontractorOrder,
	|	CustomerOwnedInventoryBalance.Products AS Products,
	|	CustomerOwnedInventoryBalance.Characteristic AS Characteristic,
	|	CustomerOwnedInventoryBalance.ProductionOrder AS ProductionOrder,
	|	CustomerOwnedInventoryBalance.QuantityToIssueBalance AS QuantityToIssueBalance,
	|	0 AS QuantityToInvoiceBalance
	|INTO TT_CustomerOwnedInventoryBalance
	|FROM
	|	AccumulationRegister.CustomerOwnedInventory.Balance(
	|			,
	|			(Company, Counterparty, SubcontractorOrder, Products, Characteristic) IN
	|				(SELECT
	|					TT_TemporaryTableProducts.Company AS Company,
	|					TT_TemporaryTableProducts.Counterparty AS Counterparty,
	|					TT_TemporaryTableProducts.SubcontractorOrder AS SubcontractorOrder,
	|					TT_TemporaryTableProducts.Products AS Products,
	|					TT_TemporaryTableProducts.Characteristic AS Characteristic
	|				FROM
	|					TT_TemporaryTableProducts AS TT_TemporaryTableProducts)) AS CustomerOwnedInventoryBalance
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentRegisterRecordsCustomerOwnedInventory.Company,
	|	DocumentRegisterRecordsCustomerOwnedInventory.Counterparty,
	|	DocumentRegisterRecordsCustomerOwnedInventory.SubcontractorOrder,
	|	DocumentRegisterRecordsCustomerOwnedInventory.Products,
	|	DocumentRegisterRecordsCustomerOwnedInventory.Characteristic,
	|	DocumentRegisterRecordsCustomerOwnedInventory.ProductionOrder,
	|	CASE
	|		WHEN DocumentRegisterRecordsCustomerOwnedInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN ISNULL(DocumentRegisterRecordsCustomerOwnedInventory.QuantityToIssue, 0)
	|		ELSE -ISNULL(DocumentRegisterRecordsCustomerOwnedInventory.QuantityToIssue, 0)
	|	END,
	|	0
	|FROM
	|	AccumulationRegister.CustomerOwnedInventory AS DocumentRegisterRecordsCustomerOwnedInventory
	|WHERE
	|	DocumentRegisterRecordsCustomerOwnedInventory.Recorder = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(TT_TemporaryTableProducts.Period) AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	MAX(TT_TemporaryTableProducts.Company) AS Company,
	|	MAX(TT_TemporaryTableProducts.Counterparty) AS Counterparty,
	|	MAX(TT_TemporaryTableProducts.SubcontractorOrder) AS SubcontractorOrder,
	|	TT_TemporaryTableProducts.Products AS Products,
	|	MAX(TT_TemporaryTableProducts.Characteristic) AS Characteristic,
	|	MAX(TT_TemporaryTableProducts.QuantityToIssue) AS QuantityToIssue,
	|	MAX(TT_TemporaryTableProducts.QuantityToInvoice) AS QuantityToInvoice,
	|	ISNULL(TT_CustomerOwnedInventoryBalance.ProductionOrder, VALUE(Document.ProductionOrder.EmptyRef)) AS ProductionOrder,
	|	SUM(ISNULL(TT_CustomerOwnedInventoryBalance.QuantityToIssueBalance, 0)) AS QuantityToIssueBalance,
	|	SUM(ISNULL(TT_CustomerOwnedInventoryBalance.QuantityToInvoiceBalance, 0)) AS QuantityToInvoiceBalance,
	|	ISNULL(TT_CustomerOwnedInventoryBalance.ProductionOrder.Date, DATETIME(3999, 12, 31)) AS ProductionOrderDate
	|FROM
	|	TT_TemporaryTableProducts AS TT_TemporaryTableProducts
	|		LEFT JOIN TT_CustomerOwnedInventoryBalance AS TT_CustomerOwnedInventoryBalance
	|		ON TT_TemporaryTableProducts.Company = TT_CustomerOwnedInventoryBalance.Company
	|			AND TT_TemporaryTableProducts.Counterparty = TT_CustomerOwnedInventoryBalance.Counterparty
	|			AND TT_TemporaryTableProducts.SubcontractorOrder = TT_CustomerOwnedInventoryBalance.SubcontractorOrder
	|			AND TT_TemporaryTableProducts.Products = TT_CustomerOwnedInventoryBalance.Products
	|			AND TT_TemporaryTableProducts.Characteristic = TT_CustomerOwnedInventoryBalance.Characteristic
	|
	|GROUP BY
	|	TT_TemporaryTableProducts.Products,
	|	ISNULL(TT_CustomerOwnedInventoryBalance.ProductionOrder, VALUE(Document.ProductionOrder.EmptyRef)),
	|	ISNULL(TT_CustomerOwnedInventoryBalance.ProductionOrder.Date, DATETIME(3999, 12, 31))
	|
	|ORDER BY
	|	Products,
	|	ProductionOrderDate
	|TOTALS BY
	|	Products
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 0
	|	CustomerOwnedInventory.Period AS Period,
	|	CustomerOwnedInventory.RecordType AS RecordType,
	|	CustomerOwnedInventory.Company AS Company,
	|	CustomerOwnedInventory.Counterparty AS Counterparty,
	|	CustomerOwnedInventory.SubcontractorOrder AS SubcontractorOrder,
	|	CustomerOwnedInventory.Products AS Products,
	|	CustomerOwnedInventory.Characteristic AS Characteristic,
	|	CustomerOwnedInventory.ProductionOrder AS ProductionOrder,
	|	CustomerOwnedInventory.QuantityToIssue AS QuantityToIssue,
	|	CustomerOwnedInventory.QuantityToInvoice AS QuantityToInvoice
	|FROM
	|	AccumulationRegister.CustomerOwnedInventory AS CustomerOwnedInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TT_TemporaryTableProducts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TT_CustomerOwnedInventoryBalance";
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.ExecuteBatch();
	SelectionProducts = QueryResult[2].Select(QueryResultIteration.ByGroups);
	
	TableCustomerOwnedInventory = QueryResult[3].Unload();
	While SelectionProducts.Next() Do
		
		TotalQuantityToIssue = SelectionProducts.QuantityToIssue;
		
		Selection = SelectionProducts.Select();
		While Selection.Next() Do
			
			If Selection.QuantityToIssueBalance = 0 Then
				Break;
			EndIf;
			
			NewRow = TableCustomerOwnedInventory.Add();
			FillPropertyValues(NewRow, Selection, , "QuantityToIssue");
			
			If Selection.QuantityToIssueBalance >= TotalQuantityToIssue Then
				
				NewRow.QuantityToIssue = TotalQuantityToIssue;
				TotalQuantityToIssue = 0;
				
				Break;
				
			Else
				
				NewRow.QuantityToIssue = Selection.QuantityToIssueBalance;
				TotalQuantityToIssue = TotalQuantityToIssue - Selection.QuantityToIssueBalance;
				
			EndIf;
			
		EndDo;
		
		If TotalQuantityToIssue > 0 Then
			
			NewRow = TableCustomerOwnedInventory.Add();
			FillPropertyValues(NewRow, SelectionProducts, , "QuantityToIssue");
			
			NewRow.RecordType = AccumulationRecordType.Expense;
			NewRow.QuantityToIssue = TotalQuantityToIssue;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCustomerOwnedInventory", TableCustomerOwnedInventory);
	
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
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "DeliveryNote") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"DeliveryNote",
			NStr("en = 'Delivery note'; ru = 'Уведомление о доставке';pl = 'Dowód dostawy';es_ES = 'Nota de entrega';es_CO = 'Nota de entrega';tr = 'Sevk irsaliyesi';it = 'Documento di Trasporto';de = 'Lieferschein'"),
			DataProcessors.PrintDeliveryNote.PrintForm(ObjectsArray, PrintObjects, "DeliveryNote", PrintParameters.Result));
			
	ElsIf PrintManagement.TemplatePrintRequired(PrintFormsCollection, "Requisition") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"Requisition",
			NStr("en = 'Requisition'; ru = 'Требование';pl = 'Zapotrzebowanie';es_ES = 'Solicitud';es_CO = 'Solicitud';tr = 'Talep formu';it = 'Requisizione';de = 'Anforderung'"),
			DataProcessors.PrintRequisition.PrintForm(ObjectsArray, PrintObjects, "Requisition", PrintParameters.Result));
			
	ElsIf PrintManagement.TemplatePrintRequired(PrintFormsCollection, "WarrantyCardPerSerialNumber") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"WarrantyCardPerSerialNumber",
			NStr("en = 'Warranty card (per serial number)'; ru = 'Гарантийный талон (по серийным номерам)';pl = 'Karta gwarancyjna (dla numeru seryjnego)';es_ES = 'Tarjeta de garantía (por número de serie)';es_CO = 'Tarjeta de garantía (por número de serie)';tr = 'Garanti belgesi (seri numarasına göre)';it = 'Certificato di garanzia (per numero di serie)';de = 'Garantiekarte (nach Seriennummer)'"),
			WorkWithProductsServer.PrintWarrantyCard(ObjectsArray, PrintObjects, "PerSerialNumber"));
															
	ElsIf PrintManagement.TemplatePrintRequired(PrintFormsCollection, "WarrantyCardConsolidated") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"WarrantyCardConsolidated",
			NStr("en = 'Warranty card (consolidated)'; ru = 'Гарантийный талон (общий)';pl = 'Karta gwarancyjna (skonsolidowana)';es_ES = 'Tarjeta de garantía (consolidada)';es_CO = 'Tarjeta de garantía (consolidada)';tr = 'Garanti kartı (konsolide)';it = 'Certificato di garanzia (consolidato)';de = 'Garantiekarte (konsolidiert)'"),
			WorkWithProductsServer.PrintWarrantyCard(ObjectsArray, PrintObjects, "Consolidated"));
	EndIf;
	
	If Errors <> Undefined Then
		CommonClientServer.ReportErrorsToUser(Errors);
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "DeliveryNote";
	PrintCommand.Presentation				= NStr("en = 'Delivery note'; ru = 'Уведомление о доставке';pl = 'Dowód dostawy';es_ES = 'Nota de entrega';es_CO = 'Nota de entrega';tr = 'Sevk irsaliyesi';it = 'Documento di Trasporto';de = 'Lieferschein'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	AttachableCommands.AddCommandVisibilityCondition(PrintCommand, 
		"OperationType",
		Enums.OperationTypesGoodsIssue.DropShipping,
		DataCompositionComparisonType.NotEqual);
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "Requisition";
	PrintCommand.Presentation				= NStr("en = 'Requisition'; ru = 'Требование';pl = 'Zapotrzebowanie';es_ES = 'Solicitud';es_CO = 'Solicitud';tr = 'Talep formu';it = 'Requisizione';de = 'Anforderung'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 2;
	AttachableCommands.AddCommandVisibilityCondition(PrintCommand, 
		"OperationType",
		Enums.OperationTypesGoodsIssue.DropShipping,
		DataCompositionComparisonType.NotEqual);
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "WarrantyCardPerSerialNumber";
	PrintCommand.Presentation				= NStr("en = 'Warranty card (per serial number)'; ru = 'Гарантийный талон (по серийным номерам)';pl = 'Karta gwarancyjna (dla numeru seryjnego)';es_ES = 'Tarjeta de garantía (por número de serie)';es_CO = 'Tarjeta de garantía (por número de serie)';tr = 'Garanti belgesi (seri numarasına göre)';it = 'Certificato di garanzia (per numero di serie)';de = 'Garantiekarte (nach Seriennummer)'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 3;
	AttachableCommands.AddCommandVisibilityCondition(PrintCommand, 
		"OperationType",
		Enums.OperationTypesGoodsIssue.DropShipping,
		DataCompositionComparisonType.NotEqual);
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "WarrantyCardConsolidated";
	PrintCommand.Presentation				= NStr("en = 'Warranty card (consolidated)'; ru = 'Гарантийный талон (общий)';pl = 'Karta gwarancyjna (skonsolidowana)';es_ES = 'Tarjeta de garantía (consolidada)';es_CO = 'Tarjeta de garantía (consolidada)';tr = 'Garanti kartı (konsolide)';it = 'Certificato di garanzia (consolidato)';de = 'Garantiekarte (konsolidiert)'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 4;
	AttachableCommands.AddCommandVisibilityCondition(PrintCommand, 
		"OperationType",
		Enums.OperationTypesGoodsIssue.DropShipping,
		DataCompositionComparisonType.NotEqual);
	
EndProcedure

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