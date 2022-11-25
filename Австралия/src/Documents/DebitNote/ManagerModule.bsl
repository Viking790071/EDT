#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure CheckAbilityOfEnteringByGoodsIssue(FillingData, Posted, OperationType, IsSalesInvoice) Export
	
	If IsSalesInvoice AND OperationType <> Enums.OperationTypesGoodsIssue.SaleToCustomer Then
		ErrorText = NStr("en = 'Cannot use %1 as a base document for Sales invoice. Please select Goods issue with ""Sale to customer"" operation.'; ru = '%1 не может быть основанием для инвойса покупателю. Выберите отпуск товаров с операцией ""Продажа покупателю"".';pl = 'Nie można użyć %1 jako dokumentu źródłowego do faktury sprzedaży. Wybierz wydanie zewnętrzne w operacji ""Sprzedaż do klienta"".';es_ES = 'No se puede usar %1 como el documento típico para la factura emitida. Por favor seleccione una expedición de productos con operación ""Venta al cliente"".';es_CO = 'No se puede usar %1 como el documento típico para la factura emitida. Por favor seleccione una expedición de productos con operación ""Venta al cliente"".';tr = 'Satış faturası için %1 temel belge olarak kullanılamaz. Lütfen ""Müşteriye satış"" işlemi ile ilgili bir Ambar çıkışı seçin.';it = 'Non è possibile usare %1 come documento di base per la Fattura di vendita. Si prega di selezionare una Spedizione merce con operazione ""Vendita al cliente"".';de = 'Kann nicht %1 als Basisdokument für eine Verkaufsrechnung verwenden. Bitte wählen Sie einen Warenausgang mit der Operation ""Verkauf an Kunden"" aus.'");
		Raise StringFunctionsClientServer.SubstituteParametersToString(
				ErrorText,
				FillingData);
	EndIf;

	If Posted <> Undefined AND Not Posted Then
		ErrorText = NStr("en = '%1 is not posted. Cannot use it as a base document. Please post it first.'; ru = 'Документ %1 не проведен и не может служить основанием. Сначала проведите документ.';pl = '%1 dokument nie został zatwierdzony. Nie można użyć go jako dokumentu źródłowego. Najpierw zatwierdź go.';es_ES = '%1 no se ha enviado. No se puede utilizarlo como un documento de base. Por favor, enviarlo primero.';es_CO = '%1 no se ha enviado. No se puede utilizarlo como un documento de base. Por favor, enviarlo primero.';tr = '%1 gönderilmedi. Temel belge olarak kullanamıyor. Lütfen ilk onu gönderin.';it = '%1 non pubblicato. Non è possibile utilizzarlo come documento di base. Si prega di pubblicarlo prima di tutto.';de = '%1 wird nicht gebucht. Kann nicht als Basisdokument verwendet werden. Zuerst bitte buchen.'");
		Raise StringFunctionsClientServer.SubstituteParametersToString(
				ErrorText,
				FillingData);
	EndIf;
	
EndProcedure

Procedure FillByGoodsIssues(DocumentData, FilterData, Inventory) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	GoodsIssue.Ref AS Ref,
	|	GoodsIssue.PointInTime AS PointInTime
	|INTO TT_GoodsIssues
	|FROM
	|	Document.GoodsIssue AS GoodsIssue
	|WHERE
	|	&GoodsIssuesConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DebitNoteInventory.Order AS Order,
	|	DebitNoteInventory.GoodsIssue AS GoodsIssue,
	|	DebitNoteInventory.Products AS Products,
	|	DebitNoteInventory.Characteristic AS Characteristic,
	|	DebitNoteInventory.Batch AS Batch,
	|	SUM(DebitNoteInventory.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyInvoiced
	|FROM
	|	Document.DebitNote.Inventory AS DebitNoteInventory
	|		INNER JOIN TT_GoodsIssues AS TT_GoodsIssues
	|		ON DebitNoteInventory.GoodsIssue = TT_GoodsIssues.Ref
	|		INNER JOIN Document.DebitNote AS DebitNote
	|		ON DebitNoteInventory.Ref = DebitNote.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON DebitNoteInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON DebitNoteInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	DebitNote.Posted
	|	AND DebitNoteInventory.Ref <> &Ref
	|
	|GROUP BY
	|	DebitNoteInventory.Batch,
	|	DebitNoteInventory.Order,
	|	DebitNoteInventory.Products,
	|	DebitNoteInventory.Characteristic,
	|	DebitNoteInventory.GoodsIssue
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsIssueBalance.GoodsIssue AS GoodsIssue,
	|	GoodsIssueBalance.Products AS Products,
	|	GoodsIssueBalance.Characteristic AS Characteristic,
	|	SUM(GoodsIssueBalance.QuantityBalance) AS QuantityBalance,
	|	GoodsIssueBalance.Order AS Order,
	|	GoodsIssueBalance.SupplierInvoice AS SupplierInvoice
	|INTO TT_GoodsIssueBalance
	|FROM
	|	(SELECT
	|		Inventory.Products AS Products,
	|		Inventory.Characteristic AS Characteristic,
	|		Inventory.Recorder AS GoodsIssue,
	|		Inventory.Quantity AS QuantityBalance,
	|		VALUE(Document.PurchaseOrder.EmptyRef) AS Order,
	|		Inventory.SourceDocument AS SupplierInvoice
	|	FROM
	|		AccumulationRegister.Inventory AS Inventory
	|	WHERE
	|		Inventory.Recorder IN
	|				(SELECT
	|					TT_GoodsIssues.Ref AS Ref
	|				FROM
	|					TT_GoodsIssues AS TT_GoodsIssues)
	|		AND Inventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DebitNoteInventory.Products,
	|		DebitNoteInventory.Characteristic,
	|		DebitNoteInventory.GoodsIssue,
	|		-DebitNoteInventory.Quantity,
	|		DebitNoteInventory.Order,
	|		DebitNoteInventory.SupplierInvoice
	|	FROM
	|		Document.DebitNote.Inventory AS DebitNoteInventory
	|	WHERE
	|		DebitNoteInventory.Ref <> &Ref
	|		AND DebitNoteInventory.Ref.Posted
	|		AND DebitNoteInventory.GoodsIssue IN
	|				(SELECT
	|					TT_GoodsIssues.Ref AS Ref
	|				FROM
	|					TT_GoodsIssues AS TT_GoodsIssues)) AS GoodsIssueBalance
	|
	|GROUP BY
	|	GoodsIssueBalance.GoodsIssue,
	|	GoodsIssueBalance.Products,
	|	GoodsIssueBalance.Characteristic,
	|	GoodsIssueBalance.Order,
	|	GoodsIssueBalance.SupplierInvoice
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
	|	GoodsIssueProducts.SerialNumbers AS SerialNumbers,
	|	GoodsIssueProducts.Contract AS Contract,
	|	TT_GoodsIssues.PointInTime AS PointInTime,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsIssueProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END  AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsIssueProducts.GoodsShippedNotInvoicedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END  AS GoodsShippedNotInvoicedGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsIssueProducts.UnearnedRevenueGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END  AS UnearnedRevenueGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsIssueProducts.RevenueGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END  AS RevenueGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsIssueProducts.COGSGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END  AS COGSGLAccount,
	|	GoodsIssueProducts.Price AS Price,
	|	GoodsIssueProducts.VATRate AS VATRate,
	|	GoodsIssueProducts.InitialAmount AS InitialAmount,
	|	GoodsIssueProducts.InitialQuantity AS InitialQuantity,
	|	GoodsIssueProducts.SupplierInvoice AS SupplierInvoice,
	|	GoodsIssueProducts.Amount AS Amount,
	|	GoodsIssueProducts.VATAmount AS VATAmount,
	|	GoodsIssueProducts.Total AS Total,
	|	GoodsIssueProducts.Project AS Project
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
	|			AND TT_Inventory.SupplierInvoice = TT_InventoryCumulative.SupplierInvoice
	|			AND TT_Inventory.Order = TT_InventoryCumulative.Order
	|			AND TT_Inventory.GoodsIssue = TT_InventoryCumulative.GoodsIssue
	|			AND TT_Inventory.LineNumber = TT_InventoryCumulative.LineNumber
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
	|	TT_InventoryCumulative.GoodsIssue AS GoodsIssue,
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
	|	TT_InventoryCumulative.SupplierInvoice AS SupplierInvoice,
	|	TT_InventoryCumulative.Amount AS Amount,
	|	TT_InventoryCumulative.VATAmount AS VATAmount,
	|	TT_InventoryCumulative.Total AS Total,
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
	|	TT_InventoryNotYetInvoicedCumulative.Price AS Price,
	|	TT_InventoryNotYetInvoicedCumulative.VATRate AS VATRate,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.InitialAmount) AS InitialAmount,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.InitialQuantity) AS InitialQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.SupplierInvoice AS SupplierInvoice,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.Amount) AS Amount,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.VATAmount) AS VATAmount,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.Total) AS Total,
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
	|			AND TT_InventoryNotYetInvoiced.LineNumber = TT_InventoryNotYetInvoicedCumulative.LineNumber
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
	|	TT_InventoryNotYetInvoicedCumulative.Price,
	|	TT_InventoryNotYetInvoicedCumulative.VATRate,
	|	TT_InventoryNotYetInvoicedCumulative.SupplierInvoice,
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
	|		INNER JOIN TT_GoodsIssueBalance AS TT_GoodsIssueBalance
	|		ON TT_InventoryNotYetInvoicedCumulative.Products = TT_GoodsIssueBalance.Products
	|			AND TT_InventoryNotYetInvoicedCumulative.Characteristic = TT_GoodsIssueBalance.Characteristic
	|			AND TT_InventoryNotYetInvoicedCumulative.GoodsIssue = TT_GoodsIssueBalance.GoodsIssue
	|			AND TT_InventoryNotYetInvoicedCumulative.SupplierInvoice = TT_GoodsIssueBalance.SupplierInvoice
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
	|	TT_InventoryToBeInvoiced.Price AS Price,
	|	CASE
	|		WHEN AccountingPolicySliceLast.RegisteredForVAT
	|			THEN ISNULL(TT_InventoryToBeInvoiced.VATRate, CatProducts.VATRate)
	|		ELSE VALUE(Catalog.VATRates.Exempt)
	|	END AS VATRate,
	|	TT_Inventory.InventoryGLAccount AS InventoryGLAccount,
	|	TT_Inventory.GoodsShippedNotInvoicedGLAccount AS GoodsShippedNotInvoicedGLAccount,
	|	TT_Inventory.UnearnedRevenueGLAccount AS UnearnedRevenueGLAccount,
	|	TT_Inventory.RevenueGLAccount AS RevenueGLAccount,
	|	TT_Inventory.COGSGLAccount AS COGSGLAccount,
	|	TT_InventoryToBeInvoiced.Price AS InitialPrice,
	|	TT_InventoryToBeInvoiced.InitialAmount AS InitialAmount,
	|	TT_InventoryToBeInvoiced.InitialQuantity AS InitialQuantity,
	|	TT_InventoryToBeInvoiced.SupplierInvoice AS SupplierInvoice,
	|	TT_InventoryToBeInvoiced.Amount AS Amount,
	|	TT_InventoryToBeInvoiced.VATAmount AS VATAmount,
	|	TT_InventoryToBeInvoiced.Total AS Total,
	|	TT_Inventory.Project AS Project
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_InventoryToBeInvoiced AS TT_InventoryToBeInvoiced
	|		ON TT_Inventory.LineNumber = TT_InventoryToBeInvoiced.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryToBeInvoiced.Order
	|			AND TT_Inventory.GoodsIssue = TT_InventoryToBeInvoiced.GoodsIssue
	|		LEFT JOIN Catalog.Products AS CatProducts
	|		ON TT_Inventory.Products = CatProducts.Ref
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(, Company = &Company) AS AccountingPolicySliceLast
	|		ON (TRUE)";
	
	Contract = Undefined;
	
	FilterData.Property("Contract", Contract);
	Query.SetParameter("Contract", Contract);
	
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

Procedure FillBySupplierInvoices(DocumentData, FilterData, Inventory) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SupplierInvoice.Ref AS Ref,
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
	|	Purchases.Document AS Document,
	|	CASE
	|		WHEN Purchases.PurchaseOrder = UNDEFINED
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE Purchases.PurchaseOrder
	|	END AS Order,
	|	Purchases.Products AS Products,
	|	Purchases.Characteristic AS Characteristic,
	|	Purchases.Batch AS Batch,
	|	Purchases.Quantity AS BaseQuantity
	|INTO TT_AlreadyReturned
	|FROM
	|	AccumulationRegister.Purchases AS Purchases
	|WHERE
	|	Purchases.Quantity < 0
	|	AND Purchases.Document IN
	|			(SELECT
	|				TT_SupplierInvoices.Ref AS Ref
	|			FROM
	|				TT_SupplierInvoices AS TT_SupplierInvoices)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SupplierInvoiceBalance.Company AS Company,
	|	SupplierInvoiceBalance.Counterparty AS Counterparty,
	|	SupplierInvoiceBalance.Products AS Products,
	|	SupplierInvoiceBalance.Characteristic AS Characteristic,
	|	CASE
	|		WHEN SupplierInvoiceBalance.PurchaseOrder = UNDEFINED
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE SupplierInvoiceBalance.PurchaseOrder
	|	END AS SalesOrder,
	|	SupplierInvoiceBalance.Document AS SupplierInvoice,
	|	SupplierInvoiceBalance.VATRate AS VATRate,
	|	SupplierInvoiceBalance.Currency AS Currency,
	|	SUM(SupplierInvoiceBalance.QuantityTurnover) AS QuantityBalance
	|INTO TTSupplierInvoiceBalancePre
	|FROM
	|	AccumulationRegister.Purchases.Turnovers(
	|			,
	|			,
	|			Recorder,
	|			Document IN
	|				(SELECT
	|					TT_SupplierInvoices.Ref AS Ref
	|				FROM
	|					TT_SupplierInvoices AS TT_SupplierInvoices)) AS SupplierInvoiceBalance
	|WHERE
	|	SupplierInvoiceBalance.Recorder <> &Ref
	|
	|GROUP BY
	|	SupplierInvoiceBalance.Company,
	|	SupplierInvoiceBalance.Counterparty,
	|	SupplierInvoiceBalance.Products,
	|	SupplierInvoiceBalance.Characteristic,
	|	SupplierInvoiceBalance.Document,
	|	SupplierInvoiceBalance.VATRate,
	|	SupplierInvoiceBalance.Currency,
	|	CASE
	|		WHEN SupplierInvoiceBalance.PurchaseOrder = UNDEFINED
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE SupplierInvoiceBalance.PurchaseOrder
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsInvoicedNotReceivedTurnovers.Company,
	|	GoodsInvoicedNotReceivedTurnovers.Counterparty,
	|	GoodsInvoicedNotReceivedTurnovers.Products,
	|	GoodsInvoicedNotReceivedTurnovers.Characteristic,
	|	CASE
	|		WHEN GoodsInvoicedNotReceivedTurnovers.PurchaseOrder = UNDEFINED
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE GoodsInvoicedNotReceivedTurnovers.PurchaseOrder
	|	END,
	|	GoodsInvoicedNotReceivedTurnovers.SupplierInvoice,
	|	GoodsInvoicedNotReceivedTurnovers.VATRate,
	|	SupplierInvoiceDoc.DocumentCurrency,
	|	SUM(GoodsInvoicedNotReceivedTurnovers.QuantityTurnover)
	|FROM
	|	AccumulationRegister.GoodsInvoicedNotReceived.Turnovers(
	|			,
	|			,
	|			Recorder,
	|			SupplierInvoice IN
	|				(SELECT
	|					TT_SupplierInvoices.Ref AS Ref
	|				FROM
	|					TT_SupplierInvoices AS TT_SupplierInvoices)) AS GoodsInvoicedNotReceivedTurnovers
	|		LEFT JOIN Document.SupplierInvoice AS SupplierInvoiceDoc
	|		ON GoodsInvoicedNotReceivedTurnovers.SupplierInvoice = SupplierInvoiceDoc.Ref
	|WHERE
	|	GoodsInvoicedNotReceivedTurnovers.Recorder <> &Ref
	|
	|GROUP BY
	|	GoodsInvoicedNotReceivedTurnovers.Company,
	|	GoodsInvoicedNotReceivedTurnovers.Products,
	|	GoodsInvoicedNotReceivedTurnovers.Characteristic,
	|	CASE
	|		WHEN GoodsInvoicedNotReceivedTurnovers.PurchaseOrder = UNDEFINED
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE GoodsInvoicedNotReceivedTurnovers.PurchaseOrder
	|	END,
	|	GoodsInvoicedNotReceivedTurnovers.Counterparty,
	|	GoodsInvoicedNotReceivedTurnovers.SupplierInvoice,
	|	SupplierInvoiceDoc.DocumentCurrency,
	|	GoodsInvoicedNotReceivedTurnovers.VATRate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TTSupplierInvoiceBalance.Company AS Company,
	|	TTSupplierInvoiceBalance.Counterparty AS Counterparty,
	|	TTSupplierInvoiceBalance.Products AS Products,
	|	TTSupplierInvoiceBalance.Characteristic AS Characteristic,
	|	TTSupplierInvoiceBalance.SalesOrder AS SalesOrder,
	|	TTSupplierInvoiceBalance.SupplierInvoice AS SupplierInvoice,
	|	TTSupplierInvoiceBalance.VATRate AS VATRate,
	|	TTSupplierInvoiceBalance.Currency AS Currency,
	|	SUM(TTSupplierInvoiceBalance.QuantityBalance) AS QuantityBalance
	|INTO TT_SupplierInvoiceBalance
	|FROM
	|	TTSupplierInvoiceBalancePre AS TTSupplierInvoiceBalance
	|
	|GROUP BY
	|	TTSupplierInvoiceBalance.Company,
	|	TTSupplierInvoiceBalance.Currency,
	|	TTSupplierInvoiceBalance.SupplierInvoice,
	|	TTSupplierInvoiceBalance.VATRate,
	|	TTSupplierInvoiceBalance.Counterparty,
	|	TTSupplierInvoiceBalance.Products,
	|	TTSupplierInvoiceBalance.Characteristic,
	|	TTSupplierInvoiceBalance.SalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SupplierInvoiceInventory.LineNumber AS LineNumber,
	|	SupplierInvoiceInventory.Products AS Products,
	|	SupplierInvoiceInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ProductsTypeInventory,
	|	SupplierInvoiceInventory.Characteristic AS Characteristic,
	|	SupplierInvoiceInventory.Batch AS Batch,
	|	SupplierInvoiceInventory.Quantity AS Quantity,
	|	SupplierInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	SupplierInvoiceInventory.Ref AS SupplierInvoice,
	|	SupplierInvoiceInventory.Order AS Order,
	|	TT_SupplierInvoices.PointInTime AS PointInTime,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoiceInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoiceInventory.VATInputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATInputGLAccount,
	|	SupplierInvoiceInventory.Price AS Price,
	|	SupplierInvoiceInventory.VATRate AS VATRate,
	|	SupplierInvoiceInventory.Amount AS InitialAmount,
	|	SupplierInvoiceInventory.Quantity AS InitialQuantity,
	|	SupplierInvoiceInventory.Amount AS Amount,
	|	SupplierInvoiceInventory.VATAmount AS InitialVATAmount,
	|	SupplierInvoiceInventory.Total AS Total
	|INTO TT_Inventory
	|FROM
	|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		INNER JOIN TT_SupplierInvoices AS TT_SupplierInvoices
	|		ON SupplierInvoiceInventory.Ref = TT_SupplierInvoices.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SupplierInvoiceInventory.MeasurementUnit = UOM.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	TT_Inventory.Order AS Order,
	|	TT_Inventory.SupplierInvoice AS SupplierInvoice,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor AS BaseQuantity,
	|	SUM(TT_InventoryCumulative.Quantity * TT_InventoryCumulative.Factor) AS BaseQuantityCumulative,
	|	TT_InventoryCumulative.Price AS Price,
	|	TT_InventoryCumulative.VATRate AS VATRate,
	|	SUM(TT_InventoryCumulative.InitialAmount) AS InitialAmount,
	|	SUM(TT_InventoryCumulative.InitialQuantity) AS InitialQuantity,
	|	SUM(TT_InventoryCumulative.Amount) AS Amount,
	|	SUM(TT_InventoryCumulative.InitialVATAmount) AS InitialVATAmount,
	|	SUM(TT_InventoryCumulative.Total) AS Total
	|INTO TT_InventoryCumulative
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_Inventory AS TT_InventoryCumulative
	|		ON TT_Inventory.Products = TT_InventoryCumulative.Products
	|			AND TT_Inventory.Characteristic = TT_InventoryCumulative.Characteristic
	|			AND TT_Inventory.Batch = TT_InventoryCumulative.Batch
	|			AND TT_Inventory.Order = TT_InventoryCumulative.Order
	|			AND TT_Inventory.SupplierInvoice = TT_InventoryCumulative.SupplierInvoice
	|			AND TT_Inventory.LineNumber = TT_InventoryCumulative.LineNumber
	|
	|GROUP BY
	|	TT_Inventory.LineNumber,
	|	TT_Inventory.Products,
	|	TT_Inventory.Characteristic,
	|	TT_Inventory.Batch,
	|	TT_Inventory.Order,
	|	TT_Inventory.SupplierInvoice,
	|	TT_Inventory.Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor,
	|	TT_InventoryCumulative.Price,
	|	TT_InventoryCumulative.VATRate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryCumulative.LineNumber AS LineNumber,
	|	TT_InventoryCumulative.Products AS Products,
	|	TT_InventoryCumulative.Characteristic AS Characteristic,
	|	TT_InventoryCumulative.Batch AS Batch,
	|	TT_InventoryCumulative.Order AS Order,
	|	TT_InventoryCumulative.SupplierInvoice AS SupplierInvoice,
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
	|	TT_InventoryCumulative.Total AS Total
	|INTO TT_InventoryNotYetInvoiced
	|FROM
	|	TT_InventoryCumulative AS TT_InventoryCumulative
	|		LEFT JOIN TT_AlreadyReturned AS TT_AlreadyReturned
	|		ON TT_InventoryCumulative.Products = TT_AlreadyReturned.Products
	|			AND TT_InventoryCumulative.Characteristic = TT_AlreadyReturned.Characteristic
	|			AND TT_InventoryCumulative.Batch = TT_AlreadyReturned.Batch
	|			AND TT_InventoryCumulative.Order = TT_AlreadyReturned.Order
	|			AND TT_InventoryCumulative.SupplierInvoice = TT_AlreadyReturned.Document
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
	|	TT_InventoryNotYetInvoiced.SupplierInvoice AS SupplierInvoice,
	|	TT_InventoryNotYetInvoiced.Factor AS Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity AS BaseQuantity,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.BaseQuantity) AS BaseQuantityCumulative,
	|	TT_InventoryNotYetInvoicedCumulative.Price AS Price,
	|	TT_InventoryNotYetInvoicedCumulative.VATRate AS VATRate,
	|	TT_InventoryNotYetInvoicedCumulative.InitialQuantity AS InitialQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.InitialAmount AS InitialAmount,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.Amount) AS Amount,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.InitialVATAmount) AS InitialVATAmount,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.Total) AS Total
	|INTO TT_InventoryNotYetInvoicedCumulative
	|FROM
	|	TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoiced
	|		INNER JOIN TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoicedCumulative
	|		ON TT_InventoryNotYetInvoiced.Products = TT_InventoryNotYetInvoicedCumulative.Products
	|			AND TT_InventoryNotYetInvoiced.Characteristic = TT_InventoryNotYetInvoicedCumulative.Characteristic
	|			AND TT_InventoryNotYetInvoiced.Batch = TT_InventoryNotYetInvoicedCumulative.Batch
	|			AND TT_InventoryNotYetInvoiced.Order = TT_InventoryNotYetInvoicedCumulative.Order
	|			AND TT_InventoryNotYetInvoiced.SupplierInvoice = TT_InventoryNotYetInvoicedCumulative.SupplierInvoice
	|			AND TT_InventoryNotYetInvoiced.LineNumber = TT_InventoryNotYetInvoicedCumulative.LineNumber
	|
	|GROUP BY
	|	TT_InventoryNotYetInvoiced.LineNumber,
	|	TT_InventoryNotYetInvoiced.Products,
	|	TT_InventoryNotYetInvoiced.Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch,
	|	TT_InventoryNotYetInvoiced.Order,
	|	TT_InventoryNotYetInvoiced.SupplierInvoice,
	|	TT_InventoryNotYetInvoiced.Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.Price,
	|	TT_InventoryNotYetInvoicedCumulative.VATRate,
	|	TT_InventoryNotYetInvoicedCumulative.InitialQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.InitialAmount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryNotYetInvoicedCumulative.LineNumber AS LineNumber,
	|	TT_InventoryNotYetInvoicedCumulative.Products AS Products,
	|	TT_InventoryNotYetInvoicedCumulative.Characteristic AS Characteristic,
	|	TT_InventoryNotYetInvoicedCumulative.Batch AS Batch,
	|	TT_InventoryNotYetInvoicedCumulative.Order AS Order,
	|	TT_InventoryNotYetInvoicedCumulative.SupplierInvoice AS SupplierInvoice,
	|	TT_InventoryNotYetInvoicedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_SupplierInvoiceBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|		WHEN TT_SupplierInvoiceBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|			THEN TT_SupplierInvoiceBalance.QuantityBalance - (TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity)
	|	END AS BaseQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.Price AS Price,
	|	TT_InventoryNotYetInvoicedCumulative.VATRate AS VATRate,
	|	TT_InventoryNotYetInvoicedCumulative.InitialQuantity AS InitialQuantity,
	|	TT_InventoryNotYetInvoicedCumulative.InitialAmount AS InitialAmount,
	|	TT_InventoryNotYetInvoicedCumulative.Amount AS Amount,
	|	TT_InventoryNotYetInvoicedCumulative.InitialVATAmount AS InitialVATAmount,
	|	TT_InventoryNotYetInvoicedCumulative.Total AS Total
	|INTO TT_InventoryToBeInvoiced
	|FROM
	|	TT_InventoryNotYetInvoicedCumulative AS TT_InventoryNotYetInvoicedCumulative
	|		INNER JOIN TT_SupplierInvoiceBalance AS TT_SupplierInvoiceBalance
	|		ON TT_InventoryNotYetInvoicedCumulative.Products = TT_SupplierInvoiceBalance.Products
	|			AND TT_InventoryNotYetInvoicedCumulative.Characteristic = TT_SupplierInvoiceBalance.Characteristic
	|			AND TT_InventoryNotYetInvoicedCumulative.Order = TT_SupplierInvoiceBalance.SalesOrder
	|			AND TT_InventoryNotYetInvoicedCumulative.SupplierInvoice = TT_SupplierInvoiceBalance.SupplierInvoice
	|WHERE
	|	TT_SupplierInvoiceBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
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
	|	TT_Inventory.SupplierInvoice AS SupplierInvoice,
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
	|	TT_InventoryToBeInvoiced.InitialQuantity AS InitialQuantity,
	|	TT_InventoryToBeInvoiced.InitialAmount AS InitialAmount,
	|	CASE
	|		WHEN TT_InventoryToBeInvoiced.InitialQuantity = 0
	|			THEN 0
	|		ELSE TT_InventoryToBeInvoiced.InitialAmount / TT_InventoryToBeInvoiced.InitialQuantity * TT_InventoryToBeInvoiced.BaseQuantity
	|	END AS Amount,
	|	CASE
	|		WHEN TT_InventoryToBeInvoiced.InitialQuantity = 0
	|			THEN 0
	|		ELSE TT_InventoryToBeInvoiced.InitialVATAmount / TT_InventoryToBeInvoiced.InitialQuantity * TT_InventoryToBeInvoiced.BaseQuantity
	|	END AS VATAmount,
	|	TT_InventoryToBeInvoiced.Total AS Total
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_InventoryToBeInvoiced AS TT_InventoryToBeInvoiced
	|		ON TT_Inventory.LineNumber = TT_InventoryToBeInvoiced.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryToBeInvoiced.Order
	|			AND TT_Inventory.SupplierInvoice = TT_InventoryToBeInvoiced.SupplierInvoice
	|		LEFT JOIN Catalog.Products AS CatProducts
	|		ON TT_Inventory.Products = CatProducts.Ref
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(, Company = &Company) AS AccountingPolicySliceLast
	|		ON (TRUE)";
	
	Contract = Undefined;
	
	FilterData.Property("Contract", Contract);
	Query.SetParameter("Contract", Contract);
	
	If FilterData.Property("SupplierInvoicesArray") Then
		FilterString = "SupplierInvoice.Ref IN(&SupplierInvoicesArray)";
		Query.SetParameter("SupplierInvoicesArray", FilterData.SupplierInvoicesArray);
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

Function DocumentVATRate(DocumentRef) Export
	
	Return Common.ObjectAttributeValue(DocumentRef, "VATRate");
	
EndFunction

Procedure CheckAbilityOfEnteringByCreditNote(FillingData, Posted, OperationType, Company) Export
	
	If Posted <> Undefined And Not Posted Then
		ErrorText = NStr("en = 'Cannot perfom the action. First, post the base document ""%1"". Then try again.'; ru = 'Не удалось выполнить действие. Проведите документ-основание ""%1"" и повторите попытку.';pl = 'Nie można wykonać czynności. Najpierw zatwierdź dokument źródłowy ""%1"". Następnie spróbuj ponownie.';es_ES = 'No se puede realizar la acción. Primero, contabilice el documento base ""%1"". Inténtelo de nuevo.';es_CO = 'No se puede realizar la acción. Primero, contabilice el documento base ""%1"". Inténtelo de nuevo.';tr = 'İşlem gerçekleştirilemiyor. ""%1"" temel belgesini kaydedip tekrar deneyin.';it = 'Impossibile eseguire l''azione. Innanzitutto pubblicare il documento di base ""%1"", poi riprovare.';de = 'Ausführen der Aktion fehlgeschlagen. Zuerst buchen Sie das Basisdokument ""%1"". Dann versuchen Sie erneut.'");
		Raise StringFunctionsClientServer.SubstituteParametersToString(
				ErrorText,
				FillingData);
	EndIf;
	
	If OperationType <> Enums.OperationTypesCreditNote.SalesReturn Then
		ErrorText = NStr("en = 'Cannot perform the action. The base document ""%1"" is not applicable. Select a Credit note where Operation is Sales return.'; ru = 'Не удалось выполнить действие. Невозможно применить документ-основание ""%1"". Выберите кредитовое авизо с операцией ""Возврат товаров (услуг)"".';pl = 'Nie można wykonać czynności. Dokument źródłowy ""%1"" nie ma zastosowania. Wybierz Notę kredytową, której Operacja jest Zwrot sprzedaży.';es_ES = 'No se puede realizar la acción. El documento base ""%1"" no es aplicable. Seleccione una Nota de crédito en la que la operación sea Devolución de ventas.';es_CO = 'No se puede realizar la acción. El documento base ""%1"" no es aplicable. Seleccione una Nota de crédito en la que la operación sea Devolución de ventas.';tr = 'İşlem gerçekleştirilemiyor. ""%1"" temel belgesi kullanılamıyor. İşlemi Satış iadesi olan bir Alacak dekontu seçin.';it = 'Impossibile eseguire l''azione. Il documento di base ""%1"" non è applicabile. Selezionare una nota di Credito dove l''Operazione è Reso vendita.';de = 'Ausführen der Aktion fehlgeschlagen. Das Basisdokument ""%1"" ist nicht verwendbar. Wählen Sie eine Gutschrift mit Operation Verkaufsrückgabe aus.'");
		Raise StringFunctionsClientServer.SubstituteParametersToString(
				ErrorText,
				FillingData);
	EndIf;
	
	DropShippingRows = FillingData.Inventory.FindRows(New Structure("DropShipping", True));
	If DropShippingRows.Count() = 0 Then
		ErrorText = NStr("en = 'Cannot perform the action. The base document ""%1"" is not applicable. Select a Credit note with drop shipping products.'; ru = 'Не удалось выполнить действие. Невозможно применить документ-основание ""%1"". Выберите кредитовое авизо с товарами для дропшиппинга.';pl = 'Nie można wykonać czynności. Dokument źródłowy ""%1"" nie ma zastosowania. Wybierz Notę kredytową z produktami dropshipping.';es_ES = 'No se puede realizar la acción. El documento base ""%1"" no es aplicable. Seleccione una Nota de crédito con productos de envío directo.';es_CO = 'No se puede realizar la acción. El documento base ""%1"" no es aplicable. Seleccione una Nota de crédito con productos de envío directo.';tr = 'İşlem gerçekleştirilemiyor. ""%1"" temel belgesi kullanılamıyor. Stoksuz satış ürünleri olan bir Alacak dekontu seçin.';it = 'Impossibile eseguire l''azione. Il documento di base ""%1"" non è applicabile. Selezionare una nota di Credito con articoli dropshipping.';de = 'Ausführen der Aktion fehlgeschlagen. Das Basisdokument ""%1"" ist nicht verwendbar. Wählen Sie eine Gutschrift mit Produkte von Streckengeschäft aus.'");
		Raise StringFunctionsClientServer.SubstituteParametersToString(
				ErrorText,
				FillingData);
				
	Else
		Params = New Structure("Company, IsError", Company, True);
		DriveServer.DropShippingReturnIsSupported(Params);
	EndIf;
	
EndProcedure

Function EverythingFromCreditNoteIsAlreadyReturned(FillingData, DebitNoteRef) Export
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	|	DebitNote.Ref AS Ref
	|INTO TT_Documents
	|FROM
	|	Document.DebitNote AS DebitNote
	|WHERE
	|	DebitNote.BasisDocument = &FillingData
	|	AND DebitNote.Posted
	|	AND DebitNote.Ref <> &DebitNoteRef
	|
	|UNION ALL
	|
	|SELECT
	|	&FillingData
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CreditNoteInventory.Products AS Products,
	|	CreditNoteInventory.Quantity AS Quantity,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN CreditNoteInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN CreditNoteInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch
	|INTO TT_Products
	|FROM
	|	Document.CreditNote.Inventory AS CreditNoteInventory
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON (CreditNoteInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON BatchTrackingPolicy.StructuralUnit = VALUE(Catalog.BusinessUnits.DropShipping)
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|WHERE
	|	CreditNoteInventory.Ref = &FillingData
	|	AND CreditNoteInventory.DropShipping
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SUM(InventoryTurnovers.QuantityTurnover) AS QuantityTurnover
	|FROM
	|	AccumulationRegister.Inventory.Turnovers(
	|			,
	|			,
	|			Recorder,
	|			StructuralUnit = VALUE(Catalog.BusinessUnits.DropShipping)
	|				AND (Products, Characteristic, Batch) IN
	|					(SELECT
	|						TT_Products.Products,
	|						TT_Products.Characteristic,
	|						TT_Products.Batch
	|					FROM
	|						TT_Products AS TT_Products)) AS InventoryTurnovers
	|WHERE
	|	InventoryTurnovers.Recorder IN
	|			(SELECT
	|				TT_Documents.Ref
	|			FROM
	|				TT_Documents AS TT_Documents)
	|HAVING SUM(InventoryTurnovers.QuantityTurnover) <= 0";
	
	Query.SetParameter("FillingData", FillingData);
	Query.SetParameter("DebitNoteRef", DebitNoteRef);
	Query.SetParameter("UseCharacteristics", Constants.UseCharacteristics.Get());
	Query.SetParameter("UseBatches", Constants.UseBatches.Get());
	
	Selection = Query.Execute().Select();
	Return Selection.Next();
	
EndFunction

Function DropShippingSupplierInvoicesToReturn(FillingData, FilterData = Undefined, CurrentSupplierInvoices = Undefined) Export
	
	Result = New Structure;
	Result.Insert("CounterpartiesMap", New Map);
	Result.Insert("SupplierInvoicesMap", New Map);
	Result.Insert("HaveSalesOrders", True);
	Result.Insert("HaveSupplierInvoices", True);
	
	If CurrentSupplierInvoices = Undefined Then
		CurrentSupplierInvoices = New Array;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	|	SalesInvoice.Order AS SalesOrder
	|INTO TT_SalesOrders
	|FROM
	|	Document.CreditNote AS CreditNote
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON CreditNote.BasisDocument = SalesInvoice.Ref
	|WHERE
	|	CreditNote.Ref = &FillingData
	|	AND NOT CreditNote.BasisDocumentInTabularSection
	|	AND SalesInvoice.Order REFS Document.SalesOrder
	|	AND SalesInvoice.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	SalesInvoice.Order
	|FROM
	|	Document.CreditNote.Inventory AS CreditNoteInventory
	|		INNER JOIN Document.CreditNote AS CreditNote
	|		ON CreditNoteInventory.Ref = CreditNote.Ref
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON CreditNoteInventory.SalesDocument = SalesInvoice.Ref
	|WHERE
	|	CreditNoteInventory.Ref = &FillingData
	|	AND CreditNote.BasisDocumentInTabularSection
	|	AND SalesInvoice.Order REFS Document.SalesOrder
	|	AND SalesInvoice.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|
	|GROUP BY
	|	SalesInvoice.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	OrdersByFulfillmentMethodTurnovers.PurchaseOrder AS PurchaseOrder
	|INTO TT_PurchuaseOrders
	|FROM
	|	AccumulationRegister.OrdersByFulfillmentMethod.Turnovers(
	|			,
	|			,
	|			,
	|			SalesOrder IN
	|					(SELECT
	|						TT_SalesOrders.SalesOrder
	|					FROM
	|						TT_SalesOrders AS TT_SalesOrders)
	|				AND PurchaseOrder.OperationKind = VALUE(Enum.OperationTypesPurchaseOrder.OrderForDropShipping)) AS OrdersByFulfillmentMethodTurnovers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CAST(PurchasesTurnovers.Document AS Document.SupplierInvoice) AS SupplierInvoice,
	|	PurchasesTurnovers.Products AS Products,
	|	PurchasesTurnovers.Characteristic AS Characteristic,
	|	PurchasesTurnovers.Batch AS Batch
	|INTO TT_NotReturnedYet
	|FROM
	|	AccumulationRegister.Purchases.Turnovers(
	|			,
	|			,
	|			,
	|			PurchaseOrder IN
	|					(SELECT
	|						TT_PurchuaseOrders.PurchaseOrder AS PurchaseOrder
	|					FROM
	|						TT_PurchuaseOrders AS TT_PurchuaseOrders)
	|				AND Document REFS Document.SupplierInvoice
	|				AND Document <> VALUE(Document.SupplierInvoice.EmptyRef)) AS PurchasesTurnovers
	|WHERE
	|	PurchasesTurnovers.QuantityTurnover > 0
	|
	|UNION ALL
	|
	|SELECT
	|	CAST(PurchasesTurnovers.Document AS Document.SupplierInvoice),
	|	PurchasesTurnovers.Products,
	|	PurchasesTurnovers.Characteristic,
	|	PurchasesTurnovers.Batch
	|FROM
	|	AccumulationRegister.Purchases.Turnovers(
	|			,
	|			,
	|			,
	|			PurchaseOrder IN
	|					(SELECT
	|						TT_PurchuaseOrders.PurchaseOrder AS PurchaseOrder
	|					FROM
	|						TT_PurchuaseOrders AS TT_PurchuaseOrders)
	|				AND Document REFS Document.SupplierInvoice
	|				AND Document <> VALUE(Document.SupplierInvoice.EmptyRef)
	|				AND Document IN (&CurrentSupplierInvoices)) AS PurchasesTurnovers
	|WHERE
	|	PurchasesTurnovers.QuantityTurnover = 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	TT_SalesOrders.SalesOrder AS SalesOrder
	|FROM
	|	TT_SalesOrders AS TT_SalesOrders
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	CAST(PurchasesTurnovers.Document AS Document.SupplierInvoice) AS SupplierInvoice
	|FROM
	|	AccumulationRegister.Purchases.Turnovers(
	|			,
	|			,
	|			,
	|			PurchaseOrder IN
	|					(SELECT
	|						TT_PurchuaseOrders.PurchaseOrder AS PurchaseOrder
	|					FROM
	|						TT_PurchuaseOrders AS TT_PurchuaseOrders)
	|				AND Document REFS Document.SupplierInvoice
	|				AND Document <> VALUE(Document.SupplierInvoice.EmptyRef)) AS PurchasesTurnovers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DocSupplierInvoice.Counterparty AS Counterparty,
	|	DocSupplierInvoice.Contract AS Contract,
	|	TT_NotReturnedYet.SupplierInvoice AS SupplierInvoice
	|FROM
	|	TT_NotReturnedYet AS TT_NotReturnedYet
	|		INNER JOIN Document.SupplierInvoice AS DocSupplierInvoice
	|		ON TT_NotReturnedYet.SupplierInvoice = DocSupplierInvoice.Ref
	|WHERE
	|	&SupplierInvoicesConditions
	|
	|GROUP BY
	|	DocSupplierInvoice.Contract,
	|	DocSupplierInvoice.Counterparty,
	|	TT_NotReturnedYet.SupplierInvoice,
	|	DocSupplierInvoice.PointInTime";
	
	Query.SetParameter("FillingData", FillingData);
	Query.SetParameter("CurrentSupplierInvoices", CurrentSupplierInvoices);
	
	If FilterData <> Undefined Then
		FilterString = "";
		FirstItem = True;
		
		For Each FilterItem In FilterData Do
			
			If Not FirstItem Then
				FilterString = FilterString + "
				|	AND ";
			Else
				FirstItem = False;
			EndIf;
			
			FilterString = FilterString +
				StringFunctionsClientServer.SubstituteParametersToString("DocSupplierInvoice.%1 = &%1", FilterItem.Key);
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
			
		EndDo;
	Else
		FilterString = "TRUE";
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&SupplierInvoicesConditions", FilterString);
	
	QueryResult = Query.ExecuteBatch();
	CountOfResults = QueryResult.Count();
	
	// There aren't Sales orders
	If QueryResult[CountOfResults-3].IsEmpty() Then
		Result.HaveSalesOrders = False;
		Return Result;
	EndIf;
	
	// There aren't Supplier invoices
	If QueryResult[CountOfResults-2].IsEmpty() Then
		Result.HaveSupplierInvoices = False;
		Return Result;
	EndIf;
	
	TableWithDocuments = QueryResult[CountOfResults-1].Unload();
	
	Counterparties = TableWithDocuments.Copy(, "Counterparty, Contract");
	Counterparties.GroupBy("Counterparty, Contract");
	
	SupplierInvoicesMap = New Map;
	CounterpartiesMap = New Map;
	
	For Each CounterpartyRow In Counterparties Do
		CounterpartiesMap.Insert(CounterpartyRow.Contract, CounterpartyRow.Counterparty);
		SupplierInvoices = New Array;
		
		Rows = TableWithDocuments.FindRows(New Structure("Counterparty, Contract", CounterpartyRow.Counterparty, CounterpartyRow.Contract));
		For Each Row In Rows Do
			SupplierInvoices.Add(Row.SupplierInvoice);
		EndDo;
		
		SupplierInvoicesMap.Insert(CounterpartyRow.Contract, SupplierInvoices);
	EndDo;
	
	Result.CounterpartiesMap = CounterpartiesMap;
	Result.SupplierInvoicesMap = SupplierInvoicesMap;
	
	Return Result;
	
EndFunction

#EndRegion

#Region TableGeneration

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePurchases(DocumentRefDebitNote, StructureAdditionalProperties)
	
    Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TablePurchases.Period AS Period,
	|	TablePurchases.Recorder AS Recorder,
	|	TablePurchases.Products AS Products,
	|	TablePurchases.Characteristic AS Characteristic,
	|	TablePurchases.Batch AS Batch,
	|	TablePurchases.Ownership AS Ownership,
	|	TablePurchases.BasisDocument AS Document,
	|	TablePurchases.Company AS Company,
	|	TablePurchases.PresentationCurrency AS PresentationCurrency,
	|	TablePurchases.Counterparty AS Counterparty,
	|	TablePurchases.DocumentCurrency AS Currency,
	|	CASE
	|		WHEN TablePurchases.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TablePurchases.Order
	|	END AS PurchaseOrder,
	|	TablePurchases.Department AS Department,
	|	-TablePurchases.ReturnQuantity AS Quantity,
	|	-TablePurchases.Amount AS Amount,
	|	TablePurchases.VATRate AS VATRate,
	|	-TablePurchases.VATAmount AS VATAmount,
	|	-TablePurchases.AmountDocCur AS AmountCur,
	|	-TablePurchases.VATAmountDocCur AS VATAmountCur,
	|	TablePurchases.Responsible AS Responsible
	|FROM
	|	TemporaryTableInventory AS TablePurchases";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchases", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefDebitNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Ref",					DocumentRefDebitNote);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", CommonClientServer.DefaultLanguageCode()));
	Query.SetParameter("ExchangeRateMethod", 	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting",GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT
	|	TableAccountsPayable.Period AS Date,
	|	TableAccountsPayable.LineNumber AS LineNumber,
	|	TableAccountsPayable.Recorder AS Recorder,
	|	TableAccountsPayable.Company AS Company,
	|	TableAccountsPayable.PresentationCurrency AS PresentationCurrency,
	|	CASE
	|		WHEN TableAccountsPayable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	TableAccountsPayable.Counterparty AS Counterparty,
	|	TableAccountsPayable.Contract AS Contract,
	|	TableAccountsPayable.SettlementsCurrency AS Currency,
	|	TableAccountsPayable.Document AS Document,
	|	TableAccountsPayable.Order AS Order,
	|	CASE
	|		WHEN TableAccountsPayable.AdvanceFlag
	|			THEN TableAccountsPayable.VendorAdvancesGLAccount
	|		ELSE TableAccountsPayable.GLAccountVendorSettlements
	|	END AS GLAccount,
	|	TableAccountsPayable.AmountCur + TableAccountsPayable.VATAmountCur AS PaymentAmount,
	|	TableAccountsPayable.Amount + TableAccountsPayable.VATAmount AS Amount,
	|	TableAccountsPayable.AmountCur + TableAccountsPayable.VATAmountCur AS AmountCur,
	|	-(TableAccountsPayable.Amount + TableAccountsPayable.VATAmount) AS AmountForBalance,
	|	-(TableAccountsPayable.AmountCur + TableAccountsPayable.VATAmountCur) AS AmountCurForBalance,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableAccountsPayable.OperationKind AS ContentOfAccountingRecord,
	|	TableAccountsPayable.Amount + TableAccountsPayable.VATAmount AS AmountForPayment,
	|	TableAccountsPayable.AmountCur + TableAccountsPayable.VATAmountCur AS AmountForPaymentCur
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTableAmountAllocation AS TableAccountsPayable";
	
	QueryResult = Query.Execute();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesAccountsPayable(Query.TempTablesManager, False, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefDebitNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Recorder AS Recorder,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.PresentationCurrency AS PresentationCurrency,
	|	TableIncomeAndExpenses.Department AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLine AS BusinessLine,
	|	TableIncomeAndExpenses.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	TableIncomeAndExpenses.GLAccount AS GLAccount,
	|	TableIncomeAndExpenses.Amount AS AmountIncome,
	|	0 AS AmountExpense,
	|	TableIncomeAndExpenses.OperationKind AS ContentOfAccountingRecord
	|INTO TableIncomeAndExpenses
	|FROM
	|	TemporaryTableInventory AS TableIncomeAndExpenses
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTableHeader.Period,
	|	TemporaryTableHeader.Recorder,
	|	TemporaryTableHeader.Company,
	|	TemporaryTableHeader.PresentationCurrency,
	|	TemporaryTableHeader.Department,
	|	TemporaryTableHeader.BusinessLine,
	|	TemporaryTableHeader.IncomeItem,
	|	TemporaryTableHeader.GLAccount,
	|	TemporaryTableHeader.Amount,
	|	0,
	|	TemporaryTableHeader.OperationKind
	|FROM
	|	TemporaryTableHeader AS TemporaryTableHeader
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON TemporaryTableHeader.GLAccount = PrimaryChartOfAccounts.Ref
	|			AND (PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				OR PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue))
	|WHERE
	|	(TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesDebitNote.Adjustments)
	|			OR TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesDebitNote.DiscountReceived))
	|	AND (&UseDefaultTypeOfAccounting
	|				AND NOT PrimaryChartOfAccounts.Ref IS NULL
	|			OR NOT &UseDefaultTypeOfAccounting
	|				AND TemporaryTableHeader.RegisterIncome)
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
	|INTO TableExchangeRateDifferencesAccountsPayable
	|FROM
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
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
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|WHERE
	|	DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableExchangeRateDifferencesAccountsPayable.Date AS Date,
	|	TableExchangeRateDifferencesAccountsPayable.Company AS Company,
	|	TableExchangeRateDifferencesAccountsPayable.PresentationCurrency AS PresentationCurrency,
	|	TableExchangeRateDifferencesAccountsPayable.Currency AS Currency,
	|	TableExchangeRateDifferencesAccountsPayable.GLAccount AS GLAccount,
	|	&Ref AS Ref,
	|	SUM(TableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences,
	|	ISNULL(PrimaryChartOfAccounts.Currency, FALSE) AS GLAccountCurrency
	|INTO GroupedTableExchangeRateDifferencesAccountsPayable
	|FROM
	|	TableExchangeRateDifferencesAccountsPayable AS TableExchangeRateDifferencesAccountsPayable
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON TableExchangeRateDifferencesAccountsPayable.GLAccount = PrimaryChartOfAccounts.Ref
	|
	|GROUP BY
	|	TableExchangeRateDifferencesAccountsPayable.Date,
	|	TableExchangeRateDifferencesAccountsPayable.Company,
	|	TableExchangeRateDifferencesAccountsPayable.Currency,
	|	TableExchangeRateDifferencesAccountsPayable.GLAccount,
	|	ISNULL(PrimaryChartOfAccounts.Currency, FALSE),
	|	TableExchangeRateDifferencesAccountsPayable.PresentationCurrency
	|
	|HAVING
	|	(SUM(TableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) >= 0.005
	|		OR SUM(TableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) <= -0.005)
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
	|	UNDEFINED AS SalesOrder,
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
	|	TableIncomeAndExpenses.PresentationCurrency,
	|	TableIncomeAndExpenses.StructuralUnit,
	|	TableIncomeAndExpenses.Recorder,
	|	TableIncomeAndExpenses.IncomeAndExpenseItem,
	|	TableIncomeAndExpenses.GLAccount,
	|	TableIncomeAndExpenses.ContentOfAccountingRecord,
	|	TableIncomeAndExpenses.BusinessLine,
	|	TableIncomeAndExpenses.Period
	|
	|UNION ALL
	|
	|SELECT
	|	GroupedTableExchangeRateDifferencesAccountsPayable.Date,
	|	GroupedTableExchangeRateDifferencesAccountsPayable.Ref,
	|	GroupedTableExchangeRateDifferencesAccountsPayable.Company,
	|	GroupedTableExchangeRateDifferencesAccountsPayable.PresentationCurrency,
	|	TableDocument.Department,
	|	TableDocument.BusinessLine,
	|	UNDEFINED,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences > 0
	|			THEN &FXIncomeItem
	|		ELSE &FXExpenseItem
	|	END,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences > 0
	|			THEN &NegativeExchangeDifferenceAccountOfAccounting
	|		ELSE &PositiveExchangeDifferenceGLAccount
	|	END,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences
	|	END,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences > 0
	|			THEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	GroupedTableExchangeRateDifferencesAccountsPayable AS GroupedTableExchangeRateDifferencesAccountsPayable
	|		INNER JOIN TemporaryTableHeader AS TableDocument
	|		ON (TableDocument.Recorder = GroupedTableExchangeRateDifferencesAccountsPayable.Ref)
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
	|DROP TableExchangeRateDifferencesAccountsPayable";
	
	Query.SetParameter("Ref", DocumentRefDebitNote);
	Query.SetParameter("PositiveExchangeDifferenceGLAccount", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", CommonClientServer.DefaultLanguageCode()));
	Query.SetParameter("FXIncomeItem", Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem", Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	Query.SetParameter("Content", NStr("en = 'Goods return'; ru = 'Возврат товара';pl = 'Zwrot towarów';es_ES = 'Devolución de productos';es_CO = 'Devolución de productos';tr = 'Mal iadesi';it = 'Restituzione merci';de = 'Warenrücksendung'", CommonClientServer.DefaultLanguageCode()));
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefDebitNote, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'",
															CommonClientServer.DefaultLanguageCode()));
	Query.SetParameter("Ref",							DocumentRefDebitNote);
	
	If DocumentRefDebitNote.OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn
		Or DocumentRefDebitNote.OperationKind = Enums.OperationTypesDebitNote.DropShipping Then
		
		Query.Text =
		"SELECT
		|	TableAccountingJournalEntries.Date AS Period,
		|	TableAccountingJournalEntries.Ref AS Recorder,
		|	TableAccountingJournalEntries.Company AS Company,
		|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
		|	CASE
		|		WHEN TableAccountingJournalEntries.AdvanceFlag
		|			THEN TableAccountingJournalEntries.VendorAdvancesGLAccount
		|		ELSE TableAccountingJournalEntries.GLAccountVendorSettlements
		|	END AS AccountDr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END AS CurrencyDr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
		|			THEN TableAccountingJournalEntries.AmountCur
		|		ELSE 0
		|	END AS AmountCurDr,
		|	TableAccountingJournalEntries.GLAccount AS AccountCr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccount.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END AS CurrencyCr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccount.Currency
		|			THEN TableAccountingJournalEntries.AmountCur
		|		ELSE 0
		|	END AS AmountCurCr,
		|	TableAccountingJournalEntries.Amount AS Amount,
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
		|	CASE
		|		WHEN TableAccountingJournalEntries.AdvanceFlag
		|			THEN TableAccountingJournalEntries.VendorAdvancesGLAccount
		|		ELSE TableAccountingJournalEntries.GLAccountVendorSettlements
		|	END,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
		|			THEN TableAccountingJournalEntries.VATAmountCur
		|		ELSE 0
		|	END,
		|	TableAccountingJournalEntries.VATInputGLAccount,
		|	UNDEFINED,
		|	0,
		|	TableAccountingJournalEntries.VATAmount,
		|	TableAccountingJournalEntries.OperationKind,
		|	FALSE
		|FROM
		|	BasicAmountAllocation AS TableAccountingJournalEntries
		|WHERE
		|	TableAccountingJournalEntries.VATTaxation <> VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
		|	AND TableAccountingJournalEntries.VATAmount <> 0";
		
	Else
		
		Query.Text =
		"SELECT
		|	TableAccountingJournalEntries.Period AS Period,
		|	TableAccountingJournalEntries.Recorder AS Recorder,
		|	TableAccountingJournalEntries.Company AS Company,
		|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
		|	CASE
		|		WHEN TableAccountingJournalEntries.AdvanceFlag
		|			THEN TableAccountingJournalEntries.VendorAdvancesGLAccount
		|		ELSE TableAccountingJournalEntries.GLAccountVendorSettlements
		|	END AS AccountDr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END AS CurrencyDr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
		|			THEN TableAccountingJournalEntries.AmountCur
		|		ELSE 0
		|	END AS AmountCurDr,
		|	TableAccountingJournalEntries.GLAccount AS AccountCr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccount.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END AS CurrencyCr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccount.Currency
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
		|	CASE
		|		WHEN TableAccountingJournalEntries.AdvanceFlag
		|			THEN TableAccountingJournalEntries.VendorAdvancesGLAccount
		|		ELSE TableAccountingJournalEntries.GLAccountVendorSettlements
		|	END,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
		|			THEN TableAccountingJournalEntries.VATAmountCur
		|		ELSE 0
		|	END,
		|	TableAccountingJournalEntries.VATInputGLAccount,
		|	UNDEFINED,
		|	0,
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
	|	UngroupedTable.Recorder,
	|	UngroupedTable.Company,
	|	UngroupedTable.AccountDr,
	|	UngroupedTable.CurrencyCr,
	|	UngroupedTable.OfflineRecord,
	|	UngroupedTable.Content,
	|	UngroupedTable.CurrencyDr,
	|	UngroupedTable.AccountCr,
	|	UngroupedTable.Period,
	|	UngroupedTable.PlanningPeriod";
	
	If (DocumentRefDebitNote.OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn
			Or DocumentRefDebitNote.OperationKind = Enums.OperationTypesDebitNote.DropShipping)
		AND Not StructureAdditionalProperties.AccountingPolicy.UseGoodsReturnToSupplier Then
		
		Query.Text = Query.Text + DriveClientServer.GetQueryUnion() + 
		"SELECT
		|	TableAccountingJournalEntries.Period AS Period,
		|	TableAccountingJournalEntries.Recorder AS Recorder,
		|	TableAccountingJournalEntries.Company AS Company,
		|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
		|	TableAccountingJournalEntries.GLAccount AS AccountDr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccount.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END AS CurrencyDr,
		|	SUM(CASE
		|			WHEN TableAccountingJournalEntries.GLAccount.Currency
		|				THEN TableAccountingJournalEntries.AmountCur
		|			ELSE 0
		|		END) AS AmountCurDr,
		|	TableAccountingJournalEntries.InventoryGLAccount AS AccountCr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.InventoryGLAccount.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END AS CurrencyCr,
		|	SUM(CASE
		|			WHEN TableAccountingJournalEntries.InventoryGLAccount.Currency
		|				THEN TableAccountingJournalEntries.AmountCur
		|			ELSE 0
		|		END) AS AmountCurCr,
		|	SUM(TableAccountingJournalEntries.Amount) AS Amount,
		|	TableAccountingJournalEntries.OperationKind AS Content,
		|	FALSE
		|FROM
		|	TemporaryTableInventory AS TableAccountingJournalEntries
		|WHERE
		|	TableAccountingJournalEntries.ThisIsInventoryItem
		|
		|GROUP BY
		|	TableAccountingJournalEntries.GLAccount,
		|	TableAccountingJournalEntries.Recorder,
		|	TableAccountingJournalEntries.Company,
		|	TableAccountingJournalEntries.Period,
		|	CASE
		|		WHEN TableAccountingJournalEntries.InventoryGLAccount.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccount.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END,
		|	TableAccountingJournalEntries.InventoryGLAccount,
		|	TableAccountingJournalEntries.OperationKind";
		
	EndIf;
	
	//Exchange rate differences	
	Query.Text = Query.Text + DriveClientServer.GetQueryUnion() + 
	"SELECT
	|	GroupedTableExchangeRateDifferencesAccountsPayable.Date AS Period,
	|	GroupedTableExchangeRateDifferencesAccountsPayable.Ref AS Recorder,
	|	GroupedTableExchangeRateDifferencesAccountsPayable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeLoss
	|		ELSE GroupedTableExchangeRateDifferencesAccountsPayable.GLAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences < 0
	|				AND GroupedTableExchangeRateDifferencesAccountsPayable.GLAccountCurrency
	|			THEN GroupedTableExchangeRateDifferencesAccountsPayable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences > 0
	|			THEN GroupedTableExchangeRateDifferencesAccountsPayable.GLAccount
	|		ELSE &ForeignCurrencyExchangeGain
	|	END AS AccountCr,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences > 0
	|				AND GroupedTableExchangeRateDifferencesAccountsPayable.GLAccountCurrency
	|			THEN GroupedTableExchangeRateDifferencesAccountsPayable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences > 0
	|			THEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences
	|		ELSE -GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences
	|	END AS Amount,
	|	&ExchangeDifference AS ExchangeDifference,
	|	FALSE AS OfflineRecord
	|FROM
	|	GroupedTableExchangeRateDifferencesAccountsPayable AS GroupedTableExchangeRateDifferencesAccountsPayable";

	QueryResult = Query.Execute();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefDebitNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventoryInWarehouses.Period AS Period,
	|	TableInventoryInWarehouses.Recorder AS Recorder,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
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
	|	AND TableInventoryInWarehouses.OperationKind <> VALUE(Enum.OperationTypesDebitNote.DropShipping)";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefDebitNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	FillAmount = StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
	Query.SetParameter("FillAmount", FillAmount);
	
	Query.Text =
	"SELECT
	|	TableInventory.Period AS Period,
	|	TableInventory.Recorder AS Recorder,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.BusinessLine AS BusinessLine,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	TableInventory.CostObject AS CostObject,
	|	TableInventory.InventoryGLAccount AS GLAccount,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|				OR TableInventory.OperationKind = VALUE(Enum.OperationTypesDebitNote.DropShipping)
	|			THEN TableInventory.InventoryAccountType
	|		ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|	END AS InventoryAccountType,
	|	TableInventory.InventoryAccountType AS CorrInventoryAccountType,
	|	TableInventory.GLAccount AS CorrGLAccount,
	|	TableInventory.ReturnQuantity AS Quantity,
	|	CASE
	|		WHEN NOT &FillAmount
	|			THEN 0
	|		ELSE TableInventory.Amount
	|	END AS Amount,
	|	TableInventory.OperationKind AS ContentOfAccountingRecord,
	|	TableInventory.Department AS Department,
	|	TableInventory.Responsible AS Responsible,
	|	TableInventory.VATRate AS VATRate,
	|	TRUE AS Return,
	|	TableInventory.GLAccount AS AccountDr,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableInventory.BasisDocument AS SourceDocument,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.ThisIsInventoryItem
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Recorder,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.StructuralUnit,
	|	UNDEFINED,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.Ownership,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef),
	|	OfflineRecords.CostObject,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.InventoryAccountType,
	|	OfflineRecords.CorrInventoryAccountType,
	|	OfflineRecords.CorrGLAccount,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.Amount,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.Department,
	|	OfflineRecords.Responsible,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.Return,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.SourceDocument,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	Query.SetParameter("Ref", DocumentRefDebitNote);
	
	Result = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", Result.Unload());
	
	If FillAmount Then
		FillAmountInInventoryTable(DocumentRefDebitNote, StructureAdditionalProperties);
	EndIf;
	
EndProcedure

Procedure GenerateTableGoodsInvoicedNotReceived(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	TemporaryTableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTableInventory.SupplierInvoice AS SupplierInvoice,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableInventory.Counterparty AS Counterparty,
	|	TemporaryTableInventory.Contract AS Contract,
	|	TemporaryTableInventory.Order AS PurchaseOrder,
	|	TemporaryTableInventory.Products AS Products,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	TemporaryTableInventory.Batch AS Batch,
	|	TemporaryTableInventory.VATRate AS VATRate,
	|	SUM(TemporaryTableInventory.ReturnQuantity) AS Quantity,
	|	SUM(TemporaryTableInventory.Amount) AS Amount,
	|	SUM(TemporaryTableInventory.VATAmount) AS VATAmount
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		INNER JOIN Document.SupplierInvoice AS DocSupplierInvoice
	|		ON TemporaryTableInventory.SupplierInvoice = DocSupplierInvoice.Ref
	|			AND (DocSupplierInvoice.OperationKind = VALUE(Enum.OperationTypesSupplierInvoice.AdvanceInvoice))
	|WHERE
	|	(TemporaryTableInventory.OperationKind = VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|			OR TemporaryTableInventory.OperationKind = VALUE(Enum.OperationTypesDebitNote.DropShipping))
	|	AND TemporaryTableInventory.ReturnQuantity > 0
	|
	|GROUP BY
	|	TemporaryTableInventory.Period,
	|	TemporaryTableInventory.SupplierInvoice,
	|	TemporaryTableInventory.Company,
	|	TemporaryTableInventory.Counterparty,
	|	TemporaryTableInventory.Contract,
	|	TemporaryTableInventory.Order,
	|	TemporaryTableInventory.Products,
	|	TemporaryTableInventory.Characteristic,
	|	TemporaryTableInventory.Batch,
	|	TemporaryTableInventory.VATRate,
	|	TemporaryTableInventory.PresentationCurrency";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsInvoicedNotReceived", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

Procedure FillAmountInInventoryTable(DocumentRefDebitNote, StructureAdditionalProperties)
	
	PostingParemeters = StructureAdditionalProperties.ForPosting;
	
	Query = New Query;
	Query.TempTablesManager = PostingParemeters.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text =
	"SELECT DISTINCT
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.CostObject AS CostObject
	|FROM
	|	TemporaryTableInventory AS TableInventory";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Inventory");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	Query.Text =
	"SELECT ALLOWED
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.PresentationCurrency AS PresentationCurrency,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.InventoryAccountType AS InventoryAccountType,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.Ownership AS Ownership,
	|	InventoryBalances.CostObject AS CostObject,
	|	InventoryBalances.QuantityBalance AS QuantityBalance,
	|	InventoryBalances.AmountBalance AS AmountBalance
	|INTO InventoryBalances
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			&ControlTime,
	|			(Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject) IN
	|				(SELECT
	|					TableInventory.Company,
	|					TableInventory.PresentationCurrency,
	|					TableInventory.StructuralUnit,
	|					TableInventory.InventoryAccountType,
	|					TableInventory.Products,
	|					TableInventory.Characteristic,
	|					TableInventory.Batch,
	|					TableInventory.Ownership,
	|					TableInventory.CostObject
	|				FROM
	|					TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentRegisterRecordsInventory.Company,
	|	DocumentRegisterRecordsInventory.PresentationCurrency,
	|	DocumentRegisterRecordsInventory.StructuralUnit,
	|	DocumentRegisterRecordsInventory.InventoryAccountType,
	|	DocumentRegisterRecordsInventory.Products,
	|	DocumentRegisterRecordsInventory.Characteristic,
	|	DocumentRegisterRecordsInventory.Batch,
	|	DocumentRegisterRecordsInventory.Ownership,
	|	DocumentRegisterRecordsInventory.CostObject,
	|	CASE
	|		WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|	END,
	|	CASE
	|		WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|		ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|	END
	|FROM
	|	AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|WHERE
	|	DocumentRegisterRecordsInventory.Recorder = &Ref
	|	AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
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
	|	InventoryBalances AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Batch,
	|	InventoryBalances.Ownership,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Products,
	|	InventoryBalances.Company,
	|	InventoryBalances.PresentationCurrency,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.InventoryAccountType,
	|	InventoryBalances.CostObject";
	
	Query.SetParameter("Ref",			DocumentRefDebitNote);
	Query.SetParameter("ControlTime",	New Boundary(PostingParemeters.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",	PostingParemeters.PointInTime.Date);
	
	Result = Query.Execute();
	
	// Receiving inventory balances by cost.
	TableInventoryBalances = Result.Unload();
	TableInventoryBalances.Indexes.Add(
		"Company, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject");
	
	UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("PresentationCurrency", RowTableInventory.PresentationCurrency);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("InventoryAccountType", RowTableInventory.InventoryAccountType);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		StructureForSearch.Insert("Ownership", RowTableInventory.Ownership);
		StructureForSearch.Insert("CostObject", RowTableInventory.CostObject);
		
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
			
			RowTableInventory.Amount = AmountToBeWrittenOff;
			RowTableInventory.Quantity = QuantityWanted;
			
		EndIf;
		
		// Generate income and expenses register records.
		If Round(RowTableInventory.Amount, 2, 1) <> 0 Then
			RowTableIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
			FillPropertyValues(RowTableIncomeAndExpenses, RowTableInventory);
			RowTableIncomeAndExpenses.GLAccount = RowTableInventory.AccountDr;
			RowTableIncomeAndExpenses.AmountExpense = RowTableInventory.Amount;
			
		EndIf;
		
		// Generate postings.
		If UseDefaultTypeOfAccounting And Round(RowTableInventory.Amount, 2, 1) <> 0 Then
			RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
			FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
			RowTableAccountingJournalEntries.AccountCr = RowTableInventory.GLAccount;
			RowTableAccountingJournalEntries.Content = RowTableInventory.ContentOfAccountingRecord;
		EndIf;
		
	EndDo;

EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRefDebitNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
    "SELECT
    |	TableSerialNumbersBalance.Period AS Period,
    |	VALUE(AccumulationRecordType.Expense) AS RecordType,
    |	TableSerialNumbersBalance.Period AS EventDate,
    |	TableSerialNumbersBalance.Company AS Company,
    |	VALUE(Enum.SerialNumbersOperations.Expense) AS Operation,
    |	TableSerialNumbersBalance.StructuralUnit AS StructuralUnit,
    |	TableSerialNumbersBalance.Products AS Products,
    |	TableSerialNumbersBalance.Characteristic AS Characteristic,
    |	TableSerialNumbersBalance.Batch AS Batch,
	|	TableSerialNumbersBalance.Ownership AS Ownership,
    |	TableSerialNumbersBalance.Cell AS Cell,
    |	DebitNoteSerialNumbers.SerialNumber AS SerialNumber,
    |	1 AS Quantity
    |FROM
    |	TemporaryTableInventory AS TableSerialNumbersBalance
    |		INNER JOIN Document.DebitNote.SerialNumbers AS DebitNoteSerialNumbers
    |		ON TableSerialNumbersBalance.Recorder = DebitNoteSerialNumbers.Ref
    |			AND TableSerialNumbersBalance.ConnectionKey = DebitNoteSerialNumbers.ConnectionKey
    |WHERE
    |	DebitNoteSerialNumbers.Ref = &Ref
    |	AND &UseSerialNumbers
    |	AND TableSerialNumbersBalance.ThisIsInventoryItem
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
    |	DebitNoteSerialNumbers.SerialNumber,
    |	TableSerialNumbersBalance.Period";
	
	Query.SetParameter("Ref", 				DocumentRefDebitNote);
	Query.SetParameter("UseSerialNumbers",	GetFunctionalOption("UseSerialNumbers"));
	
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
Function GenerateTableVATInput(Query, DocumentRefDebitNote, StructureAdditionalProperties)
	
	If DocumentRefDebitNote.OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn
		Or DocumentRefDebitNote.OperationKind = Enums.OperationTypesDebitNote.DropShipping Then
		Query.Text = 
		"SELECT
		|	DebitNoteHeader.Date AS Period,
		|	DebitNoteHeader.Ref AS Recorder,
		|	&Company AS Company,
		|	CAST(&Company AS Catalog.Companies).VATNumber AS CompanyVATNumber,
		|	&PresentationCurrency AS PresentationCurrency,
		|	DebitNoteHeader.Counterparty AS Supplier,
		|	DebitNoteInventory.VATRate AS VATRate,
		|	DebitNoteInventory.BasisDocument AS ShipmentDocument,
		|	VALUE(Enum.VATOperationTypes.PurchasesReturn) AS OperationType,
		|	CatalogProducts.ProductsType AS ProductType,
		|	DebitNoteInventory.VATInputGLAccount AS GLAccount,
		|	-SUM(DebitNoteInventory.Amount) AS AmountExcludesVAT,
		|	-SUM(DebitNoteInventory.VATAmount) AS VATAmount
		|FROM
		|	TemporaryTableDocument AS DebitNoteHeader
		|		INNER JOIN TemporaryTableInventory AS DebitNoteInventory
		|		ON DebitNoteHeader.Ref = DebitNoteInventory.Recorder
		|		LEFT JOIN Catalog.Products AS CatalogProducts
		|		ON (DebitNoteInventory.Products = CatalogProducts.Ref)
		|WHERE
		|	NOT DebitNoteInventory.VATRate.NotTaxable
		|
		|GROUP BY
		|	DebitNoteInventory.VATRate,
		|	DebitNoteInventory.VATInputGLAccount,
		|	CatalogProducts.ProductsType,
		|	DebitNoteHeader.Ref,
		|	DebitNoteHeader.Date,
		|	DebitNoteHeader.Counterparty,
		|	DebitNoteInventory.BasisDocument";
	Else
		Query.Text = 
		"SELECT
		|	DebitNoteHeader.Date AS Period,
		|	DebitNoteHeader.Ref AS Recorder,
		|	&Company AS Company,
		|	CAST(&Company AS Catalog.Companies).VATNumber AS CompanyVATNumber,
		|	&PresentationCurrency AS PresentationCurrency,
		|	DebitNoteHeader.Counterparty AS Supplier,
		|	DebitNoteHeader.Ref AS ShipmentDocument,
		|	-SUM(DebitNoteAmountAllocation.Amount) AS AmountExcludesVAT,
		|	DebitNoteAmountAllocation.VATRate AS VATRate,
		|	CASE
		|		WHEN DebitNoteAmountAllocation.OperationKind = VALUE(Enum.OperationTypesDebitNote.Adjustments)
		|			THEN VALUE(Enum.VATOperationTypes.OtherAdjustments)
		|		WHEN DebitNoteAmountAllocation.OperationKind = VALUE(Enum.OperationTypesDebitNote.DiscountReceived)
		|			THEN VALUE(Enum.VATOperationTypes.DiscountReceived)
		|	END AS OperationType,
		|	VALUE(Enum.ProductsTypes.EmptyRef) AS ProductType,
		|	DebitNoteAmountAllocation.VATInputGLAccount AS GLAccount,
		|	-SUM(DebitNoteAmountAllocation.VATAmount) AS VATAmount
		|FROM
		|	TemporaryTableDocument AS DebitNoteHeader
		|		INNER JOIN TemporaryTableAmountAllocation AS DebitNoteAmountAllocation
		|		ON DebitNoteHeader.Ref = DebitNoteAmountAllocation.Recorder
		|WHERE
		|	NOT DebitNoteAmountAllocation.VATRate.NotTaxable
		|
		|GROUP BY
		|	DebitNoteAmountAllocation.VATRate,
		|	DebitNoteAmountAllocation.VATInputGLAccount,
		|	DebitNoteAmountAllocation.OperationKind,
		|	DebitNoteHeader.Date,
		|	DebitNoteHeader.Ref,
		|	DebitNoteHeader.Counterparty,
		|	DebitNoteHeader.Ref";
		
		Query.SetParameter("VATOutput", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput"));
		
	EndIf;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", Query.Execute().Unload());
	
EndFunction

Function GenerateTableVATIncurred(Query, DocumentRefDebitNote, StructureAdditionalProperties)
	
	If DocumentRefDebitNote.OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn
		Or DocumentRefDebitNote.OperationKind = Enums.OperationTypesDebitNote.DropShipping Then
		Query.Text = 
		"SELECT
		|	DebitNoteHeader.Date AS Period,
		|	DebitNoteHeader.Ref AS Recorder,
		|	&Company AS Company,
		|	CAST(&Company AS Catalog.Companies).VATNumber AS CompanyVATNumber,
		|	&PresentationCurrency AS PresentationCurrency,
		|	DebitNoteHeader.Counterparty AS Supplier,
		|	DebitNoteHeader.Ref AS ShipmentDocument,
		|	DebitNoteInventory.VATRate AS VATRate,
		|	DebitNoteInventory.VATInputGLAccount AS GLAccount,
		|	-SUM(DebitNoteInventory.Amount) AS AmountExcludesVAT,
		|	-SUM(DebitNoteInventory.VATAmount) AS VATAmount
		|FROM
		|	TemporaryTableDocument AS DebitNoteHeader
		|		INNER JOIN TemporaryTableInventory AS DebitNoteInventory
		|		ON DebitNoteHeader.Ref = DebitNoteInventory.Recorder
		|WHERE
		|	NOT DebitNoteInventory.VATRate.NotTaxable
		|
		|GROUP BY
		|	DebitNoteInventory.VATRate,
		|	DebitNoteInventory.VATInputGLAccount,
		|	DebitNoteHeader.Ref,
		|	DebitNoteHeader.Date,
		|	DebitNoteHeader.Counterparty,
		|	DebitNoteHeader.Ref";
	Else
		Query.Text = 
		"SELECT
		|	DebitNoteHeader.Date AS Period,
		|	DebitNoteHeader.Ref AS Recorder,
		|	&Company AS Company,
		|	CAST(&Company AS Catalog.Companies).VATNumber AS CompanyVATNumber,
		|	&PresentationCurrency AS PresentationCurrency,
		|	DebitNoteHeader.Counterparty AS Supplier,
		|	DebitNoteHeader.Ref AS ShipmentDocument,
		|	DebitNoteAmountAllocation.VATRate AS VATRate,
		|	&VATOutput AS GLAccount,
		|	-SUM(DebitNoteAmountAllocation.Amount) AS AmountExcludesVAT,
		|	-SUM(DebitNoteAmountAllocation.VATAmount) AS VATAmount
		|FROM
		|	TemporaryTableDocument AS DebitNoteHeader
		|		INNER JOIN TemporaryTableAmountAllocation AS DebitNoteAmountAllocation
		|		ON DebitNoteHeader.Ref = DebitNoteAmountAllocation.Recorder
		|WHERE
		|	NOT DebitNoteAmountAllocation.VATRate.NotTaxable
		|
		|GROUP BY
		|	DebitNoteAmountAllocation.VATRate,
		|	DebitNoteHeader.Date,
		|	DebitNoteHeader.Counterparty,
		|	DebitNoteHeader.Ref,
		|	DebitNoteHeader.Ref";
		
		Query.SetParameter("VATOutput", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput"));
		
	EndIf;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATIncurred", Query.Execute().Unload());
	
EndFunction

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefDebitNote, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	DebitNote.Date AS Date,
	|	DebitNote.Ref AS Ref,
	|	DebitNote.Counterparty AS Counterparty,
	|	DebitNote.Contract AS Contract,
	|	DebitNote.ExchangeRate AS ExchangeRate,
	|	DebitNote.Multiplicity AS Multiplicity,
	|	DebitNote.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DebitNote.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	DebitNote.VATAmount AS VATAmount,
	|	DebitNote.IncomeItem AS IncomeItem,
	|	DebitNote.RegisterIncome AS RegisterIncome,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DebitNote.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	DebitNote.OperationKind AS OperationKind,
	|	DebitNote.DocumentCurrency AS DocumentCurrency,
	|	DebitNote.VATTaxation AS VATTaxation,
	|	DebitNote.AdjustedAmount AS DocumentAmount,
	|	DebitNote.Department AS Department,
	|	DebitNote.Responsible AS Responsible,
	|	DebitNote.Cell AS Cell,
	|	DebitNote.AmountIncludesVAT AS AmountIncludesVAT,
	|	DebitNote.StructuralUnit AS StructuralUnit,
	|	DebitNote.BasisDocument AS BasisDocument,
	|	CASE
	|		WHEN DebitNote.AmountIncludesVAT
	|				OR DebitNote.OperationKind = VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|				OR DebitNote.OperationKind = VALUE(Enum.OperationTypesDebitNote.DropShipping)
	|			THEN DebitNote.AdjustedAmount - DebitNote.VATAmount
	|		ELSE DebitNote.AdjustedAmount
	|	END AS Subtotal,
	|	DebitNote.BasisDocumentInTabularSection AS BasisDocumentInTabularSection
	|INTO TemporaryTableDocument
	|FROM
	|	Document.DebitNote AS DebitNote
	|WHERE
	|	DebitNote.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableDocument.Date AS Period,
	|	TemporaryTableDocument.Ref AS Recorder,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableDocument.Counterparty AS Counterparty,
	|	TemporaryTableDocument.Contract AS Contract,
	|	CAST(TemporaryTableDocument.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryTableDocument.ExchangeRate / TemporaryTableDocument.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN TemporaryTableDocument.Multiplicity / TemporaryTableDocument.ExchangeRate
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	TemporaryTableDocument.IncomeItem AS IncomeItem,
	|	TemporaryTableDocument.RegisterIncome AS RegisterIncome,
	|	TemporaryTableDocument.GLAccount AS GLAccount,
	|	TemporaryTableDocument.OperationKind AS OperationKind,
	|	CounterpartyContracts.BusinessLine AS BusinessLine,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
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
	|	TemporaryTableDocument.VATTaxation AS VATTaxation,
	|	TemporaryTableDocument.Department AS Department,
	|	TemporaryTableDocument.Responsible AS Responsible,
	|	&UseGoodsReturnToSupplier AS UseGoodsReturnToSupplier,
	|	TemporaryTableDocument.DocumentCurrency AS DocumentCurrency,
	|	TemporaryTableDocument.Cell AS Cell,
	|	TemporaryTableDocument.AmountIncludesVAT AS AmountIncludesVAT,
	|	CASE
	|		WHEN TemporaryTableDocument.OperationKind = VALUE(Enum.OperationTypesDebitNote.DropShipping)
	|			THEN VALUE(Catalog.BusinessUnits.DropShipping)
	|		ELSE TemporaryTableDocument.StructuralUnit
	|	END AS StructuralUnit,
	|	TemporaryTableDocument.BasisDocument AS BasisDocument,
	|	TemporaryTableDocument.ExchangeRate AS ExchangeRate,
	|	TemporaryTableDocument.Multiplicity AS Multiplicity,
	|	TemporaryTableDocument.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	TemporaryTableDocument.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	TemporaryTableDocument.BasisDocumentInTabularSection AS BasisDocumentInTabularSection
	|INTO TemporaryTableHeader
	|FROM
	|	TemporaryTableDocument AS TemporaryTableDocument
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON TemporaryTableDocument.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SupplierInvoice.Ref AS SupplierInvoice,
	|	SupplierInvoice.Ref AS Basis
	|INTO TemporaryTableBasis
	|FROM
	|	TemporaryTableDocument AS TemporaryTableDocument
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON TemporaryTableDocument.BasisDocument = SupplierInvoice.Ref
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	GoodsIssueProducts.SupplierInvoice,
	|	GoodsIssueProducts.Ref
	|FROM
	|	TemporaryTableDocument AS TemporaryTableDocument
	|		INNER JOIN Document.GoodsIssue.Products AS GoodsIssueProducts
	|		ON TemporaryTableDocument.BasisDocument = GoodsIssueProducts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DebitNoteInventory.Ref AS Ref,
	|	DebitNoteInventory.Batch AS Batch,
	|	DebitNoteInventory.Ownership AS Ownership,
	|	DebitNoteInventory.Characteristic AS Characteristic,
	|	DebitNoteInventory.MeasurementUnit AS MeasurementUnit,
	|	DebitNoteInventory.InitialQuantity AS Quantity,
	|	DebitNoteInventory.InitialPrice AS Price,
	|	DebitNoteInventory.Products AS Products,
	|	DebitNoteInventory.Quantity AS ReturnQuantity,
	|	DebitNoteInventory.VATAmount AS VATAmount,
	|	DebitNoteInventory.VATRate AS VATRate,
	|	DebitNoteInventory.LineNumber AS LineNumber,
	|	DebitNoteInventory.PurchaseReturnItem AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DebitNoteInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DebitNoteInventory.PurchaseReturnGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DebitNoteInventory.VATInputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATInputGLAccount,
	|	DebitNoteInventory.ConnectionKey AS ConnectionKey,
	|	CASE
	|		WHEN TemporaryTableHeader.AmountIncludesVAT
	|			THEN DebitNoteInventory.Amount - DebitNoteInventory.VATAmount
	|		ELSE DebitNoteInventory.Amount
	|	END AS Amount,
	|	DebitNoteInventory.Order AS Order,
	|	TemporaryTableHeader.Period AS Date,
	|	TemporaryTableHeader.Counterparty AS Counterparty,
	|	TemporaryTableHeader.Contract AS Contract,
	|	TemporaryTableHeader.ExchangeRate AS ExchangeRate,
	|	TemporaryTableHeader.Multiplicity AS Multiplicity,
	|	TemporaryTableHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	TemporaryTableHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	TemporaryTableHeader.SettlementsCurrency AS SettlementsCurrency,
	|	TemporaryTableHeader.OperationKind AS OperationKind,
	|	TemporaryTableHeader.DocumentCurrency AS DocumentCurrency,
	|	TemporaryTableHeader.Department AS Department,
	|	TemporaryTableHeader.Responsible AS Responsible,
	|	TemporaryTableHeader.Cell AS Cell,
	|	TemporaryTableHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	TemporaryTableHeader.StructuralUnit AS StructuralUnit,
	|	TemporaryTableHeader.BasisDocument AS BasisDocument,
	|	DebitNoteInventory.SupplierInvoice AS SupplierInvoice,
	|	DebitNoteInventory.GoodsIssue AS GoodsIssue,
	|	TemporaryTableHeader.BasisDocumentInTabularSection AS BasisDocumentInTabularSection
	|INTO TemporaryTableDocInventory
	|FROM
	|	TemporaryTableHeader AS TemporaryTableHeader
	|		INNER JOIN Document.DebitNote.Inventory AS DebitNoteInventory
	|		ON TemporaryTableHeader.Recorder = DebitNoteInventory.Ref
	|WHERE
	|	DebitNoteInventory.Amount <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableDocInventory.Ref AS Recorder,
	|	CASE
	|		WHEN &UseBatches
	|			AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|				OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
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
	|	TemporaryTableDocInventory.Department AS Department,
	|	TemporaryTableDocInventory.Counterparty AS Counterparty,
	|	TemporaryTableDocInventory.Contract AS Contract,
	|	TemporaryTableDocInventory.DocumentCurrency AS DocumentCurrency,
	|	CASE
	|		WHEN TemporaryTableDocInventory.BasisDocumentInTabularSection
	|				OR TemporaryTableDocInventory.OperationKind = VALUE(Enum.OperationTypesDebitNote.DropShipping)
	|			THEN TemporaryTableDocInventory.SupplierInvoice
	|		ELSE TemporaryTableBasis.SupplierInvoice
	|	END AS BasisDocument,
	|	TemporaryTableDocInventory.Responsible AS Responsible,
	|	TemporaryTableDocInventory.VATRate AS VATRate,
	|	TemporaryTableDocInventory.LineNumber AS LineNumber,
	|	TemporaryTableDocInventory.VATAmount AS VATAmount,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableDocInventory.Amount AS Amount,
	|	TemporaryTableDocInventory.Order AS Order,
	|	TemporaryTableDocInventory.AmountIncludesVAT AS AmountIncludesVAT,
	|	TemporaryTableDocInventory.StructuralUnit AS StructuralUnit,
	|	TemporaryTableDocInventory.Cell AS Cell,
	|	CatalogProducts.BusinessLine AS BusinessLine,
	|	TemporaryTableDocInventory.SettlementsCurrency AS SettlementsCurrency,
	|	TemporaryTableDocInventory.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	TemporaryTableDocInventory.InventoryGLAccount AS InventoryGLAccount,
	|	TemporaryTableDocInventory.OperationKind AS OperationKind,
	|	TemporaryTableDocInventory.ConnectionKey AS ConnectionKey,
	|	TemporaryTableDocInventory.GLAccount AS GLAccount,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS InventoryAccountType,
	|	TemporaryTableDocInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ThisIsInventoryItem,
	|	&UseGoodsReturnToSupplier AS UseGoodsReturnToSupplier,
	|	TemporaryTableDocInventory.VATInputGLAccount AS VATInputGLAccount,
	|	TemporaryTableDocInventory.ExchangeRate AS ExchangeRate,
	|	TemporaryTableDocInventory.Multiplicity AS Multiplicity,
	|	TemporaryTableDocInventory.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	TemporaryTableDocInventory.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity
	|INTO TemporaryTableInventoryPrev
	|FROM
	|	TemporaryTableDocInventory AS TemporaryTableDocInventory
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON TemporaryTableDocInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN TemporaryTableBasis AS TemporaryTableBasis
	|		ON TemporaryTableDocInventory.BasisDocument = TemporaryTableBasis.Basis
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
	|	DebitNoteAmountAllocation.Ref AS Ref,
	|	&Company AS Company,
	|	DebitNoteAmountAllocation.Contract AS Contract,
	|	DebitNoteAmountAllocation.AdvanceFlag AS AdvanceFlag,
	|	CASE
	|		WHEN DebitNoteAmountAllocation.AdvanceFlag
	|			THEN DebitNoteAmountAllocation.Ref
	|		ELSE DebitNoteAmountAllocation.Document
	|	END AS Document,
	|	DebitNoteAmountAllocation.OffsetAmount - DebitNoteAmountAllocation.VATAmount AS Amount,
	|	CASE
	|		WHEN DebitNoteAmountAllocation.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DebitNoteAmountAllocation.Order
	|	END AS Order,
	|	TemporaryTableHeader.Period AS Date,
	|	TemporaryTableHeader.Counterparty AS Counterparty,
	|	TemporaryTableHeader.ExchangeRate AS ExchangeRate,
	|	TemporaryTableHeader.Multiplicity AS Multiplicity,
	|	TemporaryTableHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	TemporaryTableHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	TemporaryTableHeader.OperationKind AS OperationKind,
	|	TemporaryTableHeader.DocumentCurrency AS DocumentCurrency,
	|	DebitNoteAmountAllocation.VATRate AS VATRate,
	|	DebitNoteAmountAllocation.VATAmount AS VATAmount,
	|	DebitNoteAmountAllocation.LineNumber AS LineNumber,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DebitNoteAmountAllocation.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountVendorSettlements,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DebitNoteAmountAllocation.AdvancesPaidGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VendorAdvancesGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DebitNoteAmountAllocation.VATInputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATInputGLAccount,
	|	TemporaryTableHeader.GLAccount AS GLAccount,
	|	AccountsPayable.Currency AS GLAccountVendorSettlementsCurrency,
	|	PrimaryChartOfAccounts.Currency AS GLAccountCurrency,
	|	TemporaryTableHeader.SettlementsCurrency AS SettlementsCurrency,
	|	TemporaryTableHeader.VATTaxation AS VATTaxation
	|INTO TemporaryTableDocAmountAllocation
	|FROM
	|	TemporaryTableHeader AS TemporaryTableHeader
	|		INNER JOIN Document.DebitNote.AmountAllocation AS DebitNoteAmountAllocation
	|		ON TemporaryTableHeader.Recorder = DebitNoteAmountAllocation.Ref
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS AccountsPayable
	|		ON (DebitNoteAmountAllocation.AccountsPayableGLAccount = AccountsPayable.Ref)
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON TemporaryTableHeader.GLAccount = PrimaryChartOfAccounts.Ref
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
	|	AmountAllocationInventoryTable.Amount AS Amount,
	|	CAST(TemporaryTableInventoryPrev.VATAmount * (AmountAllocationInventoryTable.Amount / TemporaryTableInventoryPrev.Amount) AS NUMBER(15, 2)) AS VATAmount
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
	|	SUM(AmountAllocationInventoryWithVAT.VATAmount) AS VATAmount
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
	|	AmountAllocationInventoryWithVAT.LineNumber AS LineNumber,
	|	AmountAllocationInventoryWithVAT.InventoryLineNumber AS InventoryLineNumber,
	|	AmountAllocationInventoryWithVAT.Amount AS Amount,
	|	AmountAllocationInventoryWithVAT.VATAmount + ISNULL(LineAmountDifferenceLineNumber.DiffVATAmount, 0) AS VATAmount
	|INTO AmountAllocationWithVAT
	|FROM
	|	AmountAllocationInventoryWithVAT AS AmountAllocationInventoryWithVAT
	|		LEFT JOIN LineAmountDifferenceLineNumber AS LineAmountDifferenceLineNumber
	|		ON AmountAllocationInventoryWithVAT.LineNumber = LineAmountDifferenceLineNumber.LineNumber
	|			AND AmountAllocationInventoryWithVAT.InventoryLineNumber = LineAmountDifferenceLineNumber.InventoryLineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AmountAllocationWithVAT.LineNumber AS LineNumber,
	|	AmountAllocationWithVAT.InventoryLineNumber AS InventoryLineNumber,
	|	AmountAllocationWithVAT.Amount AS AmountDocCur,
	|	AmountAllocationWithVAT.VATAmount AS VATAmountDocCur,
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
	|	TemporaryTableDocAmountAllocation.AdvanceFlag AS AdvanceFlag,
	|	TemporaryTableDocAmountAllocation.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|	TemporaryTableDocAmountAllocation.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	TemporaryTableDocAmountAllocation.SettlementsCurrency AS SettlementsCurrency,
	|	TemporaryTableDocAmountAllocation.OperationKind AS OperationKind,
	|	TemporaryTableInventoryPrev.VATInputGLAccount AS VATInputGLAccount,
	|	TemporaryTableInventoryPrev.GLAccount AS GLAccount,
	|	TemporaryTableDocAmountAllocation.VATTaxation AS VATTaxation,
	|	TemporaryTableDocAmountAllocation.Company AS Company,
	|	TemporaryTableDocAmountAllocation.Ref AS Ref,
	|	TemporaryTableDocAmountAllocation.Date AS Date
	|INTO BasicAmountAllocation
	|FROM
	|	AmountAllocationWithVAT AS AmountAllocationWithVAT
	|		INNER JOIN TemporaryTableInventoryPrev AS TemporaryTableInventoryPrev
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
	|	SUM(BasicAmountAllocation.VATAmount) AS VATAmount
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
	|	SUM(BasicAmountAllocation.VATAmount) AS VATAmount
	|INTO BasicAmountAllocationVendor
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
	|	&PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableDocAmountAllocation.Counterparty AS Counterparty,
	|	TemporaryTableDocAmountAllocation.Contract AS Contract,
	|	TemporaryTableDocAmountAllocation.Document AS Document,
	|	TemporaryTableDocAmountAllocation.Order AS Order,
	|	TemporaryTableDocAmountAllocation.AdvanceFlag AS AdvanceFlag,
	|	TemporaryTableDocAmountAllocation.OperationKind AS OperationKind,
	|	TemporaryTableDocAmountAllocation.LineNumber AS LineNumber,
	|	TemporaryTableDocAmountAllocation.DocumentCurrency AS Currency,
	|	TemporaryTableDocAmountAllocation.VATRate AS VATRate,
	|	TemporaryTableDocAmountAllocation.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	TemporaryTableDocAmountAllocation.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|	TemporaryTableDocAmountAllocation.GLAccount AS GLAccount,
	|	TemporaryTableDocAmountAllocation.GLAccountVendorSettlementsCurrency AS GLAccountVendorSettlementsCurrency,
	|	TemporaryTableDocAmountAllocation.GLAccountCurrency AS GLAccountCurrency,
	|	TemporaryTableDocAmountAllocation.SettlementsCurrency AS SettlementsCurrency,
	|	TemporaryTableDocAmountAllocation.VATTaxation AS VATTaxation,
	|	TemporaryTableDocAmountAllocation.VATInputGLAccount AS VATInputGLAccount,
	|	BasicAmountAllocationVendor.AmountCur AS AmountCur,
	|	BasicAmountAllocationVendor.VATAmountCur AS VATAmountCur,
	|	BasicAmountAllocationVendor.Amount AS Amount,
	|	BasicAmountAllocationVendor.VATAmount AS VATAmount
	|INTO TemporaryTableAmountAllocation
	|FROM
	|	TemporaryTableDocAmountAllocation AS TemporaryTableDocAmountAllocation
	|		INNER JOIN BasicAmountAllocationVendor AS BasicAmountAllocationVendor
	|		ON TemporaryTableDocAmountAllocation.LineNumber = BasicAmountAllocationVendor.LineNumber
	|WHERE
	|	(TemporaryTableDocAmountAllocation.OperationKind = VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|		OR TemporaryTableDocAmountAllocation.OperationKind = VALUE(Enum.OperationTypesDebitNote.DropShipping))
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTableDocAmountAllocation.Date,
	|	TemporaryTableDocAmountAllocation.Ref,
	|	&Company,
	|	&PresentationCurrency,
	|	TemporaryTableDocAmountAllocation.Counterparty,
	|	TemporaryTableDocAmountAllocation.Contract,
	|	TemporaryTableDocAmountAllocation.Document,
	|	TemporaryTableDocAmountAllocation.Order,
	|	TemporaryTableDocAmountAllocation.AdvanceFlag,
	|	TemporaryTableDocAmountAllocation.OperationKind,
	|	TemporaryTableDocAmountAllocation.LineNumber,
	|	TemporaryTableDocAmountAllocation.DocumentCurrency,
	|	TemporaryTableDocAmountAllocation.VATRate,
	|	TemporaryTableDocAmountAllocation.GLAccountVendorSettlements,
	|	TemporaryTableDocAmountAllocation.VendorAdvancesGLAccount,
	|	TemporaryTableDocAmountAllocation.GLAccount,
	|	TemporaryTableDocAmountAllocation.GLAccountVendorSettlementsCurrency,
	|	TemporaryTableDocAmountAllocation.GLAccountCurrency,
	|	TemporaryTableDocAmountAllocation.SettlementsCurrency,
	|	TemporaryTableDocAmountAllocation.VATTaxation,
	|	TemporaryTableDocAmountAllocation.VATInputGLAccount,
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
	|		END AS NUMBER(15, 2))
	|FROM
	|	TemporaryTableDocAmountAllocation AS TemporaryTableDocAmountAllocation
	|WHERE
	|	TemporaryTableDocAmountAllocation.OperationKind <> VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|	AND TemporaryTableDocAmountAllocation.OperationKind <> VALUE(Enum.OperationTypesDebitNote.DropShipping)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableInventoryPrev.Recorder AS Recorder,
	|	TemporaryTableInventoryPrev.Batch AS Batch,
	|	TemporaryTableInventoryPrev.Ownership AS Ownership,
	|	TemporaryTableInventoryPrev.CostObject AS CostObject,
	|	TemporaryTableInventoryPrev.Characteristic AS Characteristic,
	|	TemporaryTableInventoryPrev.Products AS Products,
	|	TemporaryTableInventoryPrev.Period AS Period,
	|	TemporaryTableInventoryPrev.Department AS Department,
	|	TemporaryTableInventoryPrev.Counterparty AS Counterparty,
	|	TemporaryTableInventoryPrev.Contract AS Contract,
	|	TemporaryTableInventoryPrev.DocumentCurrency AS DocumentCurrency,
	|	TemporaryTableInventoryPrev.BasisDocument AS BasisDocument,
	|	TemporaryTableInventoryPrev.BasisDocument AS SupplierInvoice,
	|	TemporaryTableInventoryPrev.Responsible AS Responsible,
	|	TemporaryTableInventoryPrev.VATRate AS VATRate,
	|	TemporaryTableInventoryPrev.Company AS Company,
	|	TemporaryTableInventoryPrev.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableInventoryPrev.Order AS Order,
	|	TemporaryTableInventoryPrev.AmountIncludesVAT AS AmountIncludesVAT,
	|	TemporaryTableInventoryPrev.StructuralUnit AS StructuralUnit,
	|	TemporaryTableInventoryPrev.Cell AS Cell,
	|	TemporaryTableInventoryPrev.BusinessLine AS BusinessLine,
	|	TemporaryTableInventoryPrev.SettlementsCurrency AS SettlementsCurrency,
	|	TemporaryTableInventoryPrev.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	TemporaryTableInventoryPrev.InventoryGLAccount AS InventoryGLAccount,
	|	TemporaryTableInventoryPrev.OperationKind AS OperationKind,
	|	TemporaryTableInventoryPrev.ConnectionKey AS ConnectionKey,
	|	TemporaryTableInventoryPrev.GLAccount AS GLAccount,
	|	TemporaryTableInventoryPrev.InventoryAccountType AS InventoryAccountType,
	|	TemporaryTableInventoryPrev.VATInputGLAccount AS VATInputGLAccount,
	|	TemporaryTableInventoryPrev.ThisIsInventoryItem AS ThisIsInventoryItem,
	|	TemporaryTableInventoryPrev.UseGoodsReturnToSupplier AS UseGoodsReturnToSupplier,
	|	SUM(TemporaryTableInventoryPrev.Quantity) AS Quantity,
	|	SUM(TemporaryTableInventoryPrev.ReturnQuantity) AS ReturnQuantity,
	|	SUM(BasicAmountAllocationInventory.AmountDocCur) AS AmountDocCur,
	|	SUM(BasicAmountAllocationInventory.VATAmountDocCur) AS VATAmountDocCur,
	|	SUM(BasicAmountAllocationInventory.AmountCur) AS AmountCur,
	|	SUM(BasicAmountAllocationInventory.VATAmountCur) AS VATAmountCur,
	|	SUM(BasicAmountAllocationInventory.Amount) AS Amount,
	|	SUM(BasicAmountAllocationInventory.VATAmount) AS VATAmount
	|INTO TemporaryTableInventory
	|FROM
	|	TemporaryTableInventoryPrev AS TemporaryTableInventoryPrev
	|		INNER JOIN BasicAmountAllocationInventory AS BasicAmountAllocationInventory
	|		ON TemporaryTableInventoryPrev.LineNumber = BasicAmountAllocationInventory.InventoryLineNumber
	|
	|GROUP BY
	|	TemporaryTableInventoryPrev.Recorder,
	|	TemporaryTableInventoryPrev.Company,
	|	TemporaryTableInventoryPrev.PresentationCurrency,
	|	TemporaryTableInventoryPrev.Batch,
	|	TemporaryTableInventoryPrev.Ownership,
	|	TemporaryTableInventoryPrev.CostObject,
	|	TemporaryTableInventoryPrev.Characteristic,
	|	TemporaryTableInventoryPrev.Products,
	|	TemporaryTableInventoryPrev.BasisDocument,
	|	TemporaryTableInventoryPrev.Responsible,
	|	TemporaryTableInventoryPrev.Period,
	|	TemporaryTableInventoryPrev.VATRate,
	|	TemporaryTableInventoryPrev.Department,
	|	TemporaryTableInventoryPrev.Counterparty,
	|	TemporaryTableInventoryPrev.Contract,
	|	TemporaryTableInventoryPrev.DocumentCurrency,
	|	TemporaryTableInventoryPrev.BusinessLine,
	|	TemporaryTableInventoryPrev.IncomeAndExpenseItem,
	|	TemporaryTableInventoryPrev.InventoryGLAccount,
	|	TemporaryTableInventoryPrev.OperationKind,
	|	TemporaryTableInventoryPrev.VATInputGLAccount,
	|	TemporaryTableInventoryPrev.GLAccount,
	|	TemporaryTableInventoryPrev.InventoryAccountType,
	|	TemporaryTableInventoryPrev.AmountIncludesVAT,
	|	TemporaryTableInventoryPrev.Cell,
	|	TemporaryTableInventoryPrev.ThisIsInventoryItem,
	|	TemporaryTableInventoryPrev.UseGoodsReturnToSupplier,
	|	TemporaryTableInventoryPrev.Order,
	|	TemporaryTableInventoryPrev.SettlementsCurrency,
	|	TemporaryTableInventoryPrev.StructuralUnit,
	|	TemporaryTableInventoryPrev.ConnectionKey";
	
	Query.SetParameter("Ref",						DocumentRefDebitNote);
	Query.SetParameter("Company",					StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",		StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseCharacteristics",		StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",				StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseGoodsReturnToSupplier",	StructureAdditionalProperties.AccountingPolicy.UseGoodsReturnToSupplier);
	Query.SetParameter("PresentationCurrency",		StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod",		StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	ResultsArray = Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefDebitNote, StructureAdditionalProperties);
	
	GenerateTablePurchases(DocumentRefDebitNote, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefDebitNote, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefDebitNote, StructureAdditionalProperties);
	GenerateTableGoodsInvoicedNotReceived(DocumentRefDebitNote, StructureAdditionalProperties);
	
	If DocumentRefDebitNote.OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn
			Or DocumentRefDebitNote.OperationKind = Enums.OperationTypesDebitNote.DropShipping Then
		If NOT StructureAdditionalProperties.AccountingPolicy.UseGoodsReturnToSupplier Then
			GenerateTableInventoryInWarehouses(DocumentRefDebitNote, StructureAdditionalProperties);
			GenerateTableInventory(DocumentRefDebitNote, StructureAdditionalProperties);
			GenerateTableSerialNumbers(DocumentRefDebitNote, StructureAdditionalProperties);	
		EndIf;
	EndIf;
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefDebitNote, StructureAdditionalProperties);
	EndIf;
	
	GenerateTableAccountingEntriesData(DocumentRefDebitNote, StructureAdditionalProperties);
	
	If GetFunctionalOption("UseVAT")
		AND DocumentRefDebitNote.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		If WorkWithVAT.GetUseTaxInvoiceForPostingVAT(DocumentRefDebitNote.Date, DocumentRefDebitNote.Company) Then
			
			GenerateTableVATIncurred(Query, DocumentRefDebitNote, StructureAdditionalProperties);
			
		Else
			
			GenerateTableVATInput(Query, DocumentRefDebitNote, StructureAdditionalProperties);
			
		EndIf;
		
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRefDebitNote, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefDebitNote, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefDebitNote, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefDebitNote, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsInventoryChange", "MovementsInventoryInWarehousesChange"
	// contain records, it is required to control goods implementation.
		
	If StructureTemporaryTables.RegisterRecordsInventoryChange
		OR StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		OR StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange
		OR StructureTemporaryTables.RegisterRecordsVATIncurredChange
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
		|	RegisterRecordsSuppliersSettlementsChange.LineNumber AS LineNumber,
		|	RegisterRecordsSuppliersSettlementsChange.Company AS CompanyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.PresentationCurrency AS PresentationCurrencyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Contract AS ContractPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Contract.SettlementsCurrency AS CurrencyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Document AS DocumentPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Order AS OrderPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS CalculationsTypesPresentation,
		|	FALSE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsSuppliersSettlementsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountChange AS AmountChange,
		|	RegisterRecordsSuppliersSettlementsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite - ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AdvanceAmountsPaid,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange + ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountOfOutstandingDebt,
		|	ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange
		|		INNER JOIN AccumulationRegister.AccountsPayable.Balance(&ControlTime, ) AS AccountsPayableBalances
		|		ON RegisterRecordsSuppliersSettlementsChange.Company = AccountsPayableBalances.Company
		|			AND RegisterRecordsSuppliersSettlementsChange.PresentationCurrency = AccountsPayableBalances.PresentationCurrency
		|			AND RegisterRecordsSuppliersSettlementsChange.Counterparty = AccountsPayableBalances.Counterparty
		|			AND RegisterRecordsSuppliersSettlementsChange.Contract = AccountsPayableBalances.Contract
		|			AND RegisterRecordsSuppliersSettlementsChange.Document = AccountsPayableBalances.Document
		|			AND RegisterRecordsSuppliersSettlementsChange.Order = AccountsPayableBalances.Order
		|			AND RegisterRecordsSuppliersSettlementsChange.SettlementsType = AccountsPayableBalances.SettlementsType
		|			AND (CASE
		|				WHEN RegisterRecordsSuppliersSettlementsChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|					THEN ISNULL(AccountsPayableBalances.AmountCurBalance, 0) > 0
		|				ELSE ISNULL(AccountsPayableBalances.AmountCurBalance, 0) < 0
		|			END)
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
		Query.Text = Query.Text + AccumulationRegisters.VATIncurred.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.Inventory.ReturnQuantityControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		Query.SetParameter("Ref", DocumentRefDebitNote);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			Or Not ResultsArray[1].IsEmpty()
			Or Not ResultsArray[2].IsEmpty()
			Or Not ResultsArray[3].IsEmpty()
			Or Not ResultsArray[5].IsEmpty()
			Or Not ResultsArray[11].IsEmpty() Then
			DocumentObjectDebitNote = DocumentRefDebitNote.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectDebitNote, QueryResultSelection, Cancel);
		// Negative balance of inventory.
		ElsIf Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectDebitNote, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectDebitNote, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectDebitNote, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			DriveServer.ShowMessageAboutPostingToVATIncurredRegisterErrors(DocumentObjectDebitNote, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of return quantity in inventory
		If Not ResultsArray[11].IsEmpty() And ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[11].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterRefundsErrors(DocumentObjectDebitNote, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Inventory" Then
		IncomeAndExpenseStructure.Insert("PurchaseReturnItem", StructureData.PurchaseReturnItem);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "Header" Then
		Result.Insert("GLAccount", "IncomeItem");
	ElsIf StructureData.TabName = "Inventory" Then
		Result.Insert("PurchaseReturnGLAccount", "PurchaseReturnItem");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	If StructureData.Property("ProductGLAccounts") Then
		GLAccountsForFilling = New Structure("InventoryGLAccount, VATInputGLAccount, PurchaseReturnGLAccount");
		FillPropertyValues(GLAccountsForFilling, StructureData);
		
	ElsIf StructureData.Property("CounterpartyGLAccounts") Then
		
		If StructureData.TabName = "Header"
			And ObjectParameters.OperationKind = Enums.OperationTypesDebitNote.DiscountReceived Then
			
			GLAccountsForFilling.Insert("DiscountReceivedGLAccount", ObjectParameters.GLAccount);
			
		ElsIf StructureData.TabName = "AmountAllocation" Then
			
			GLAccountsForFilling.Insert("AccountsPayableGLAccount", StructureData.AccountsPayableGLAccount);
			GLAccountsForFilling.Insert("AdvancesPaidGLAccount", StructureData.AdvancesPaidGLAccount);
			
			If ObjectParameters.OperationKind <> Enums.OperationTypesDebitNote.PurchaseReturn
				And ObjectParameters.OperationKind <> Enums.OperationTypesDebitNote.DropShipping Then
				GLAccountsForFilling.Insert("VATInputGLAccount", StructureData.VATInputGLAccount);
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
	
	If DocObject.OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn Then
		
		Warehouses = New Array;
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.StructuralUnit);
		WarehouseData.Insert("TrackingArea", "Outbound_PurchaseReturn");
		
		Warehouses.Add(WarehouseData);
		
		Parameters.Insert("Warehouses", Warehouses);
		
	EndIf;
	
	Return Parameters;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	If TemplateName = "DebitNote" Then
		Return PrintDebitNote(ObjectsArray, PrintObjects, TemplateName, PrintParams)
	EndIf;
	
EndFunction

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
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "DebitNote") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(
            PrintFormsCollection, 
            "DebitNote", 
            NStr("en = 'Debit note'; ru = 'Дебетовое авизо';pl = 'Nota debetowa';es_ES = 'Nota de débito';es_CO = 'Nota de débito';tr = 'Borç dekontu';it = 'Nota di debito';de = 'Lastschrift'"), 
            PrintForm(ObjectsArray, PrintObjects, "DebitNote", PrintParameters.Result));
	EndIf;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "Requisition") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"Requisition",
			NStr("en = 'Requisition'; ru = 'Требование';pl = 'Zapotrzebowanie';es_ES = 'Solicitud';es_CO = 'Solicitud';tr = 'Talep formu';it = 'Requisizione';de = 'Anforderung'"),
			DataProcessors.PrintRequisition.PrintForm(ObjectsArray, PrintObjects, "Requisition", PrintParameters.Result));
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
	PrintCommand.ID							= "DebitNote";
	PrintCommand.Presentation				= NStr("en = 'Debit note'; ru = 'Дебетовое авизо';pl = 'Nota debetowa';es_ES = 'Nota de débito';es_CO = 'Nota de débito';tr = 'Borç dekontu';it = 'Nota di debito';de = 'Lastschrift'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "Requisition";
	PrintCommand.Presentation				= NStr("en = 'Requisition'; ru = 'Требование';pl = 'Zapotrzebowanie';es_ES = 'Solicitud';es_CO = 'Solicitud';tr = 'Talep formu';it = 'Requisizione';de = 'Anforderung'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 2;
	
EndProcedure

Function PrintDebitNote(ObjectsArray, PrintObjects, TemplateName, PrintParams)
	
	DisplayPrintOption = (PrintParams <> Undefined);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_DebitNote";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	#Region PrintDebitNoteQueryText
	
	Query.Text = 
	"SELECT ALLOWED
	|	DebitNote.Ref AS Ref,
	|	DebitNote.Number AS Number,
	|	DebitNote.Date AS Date,
	|	DebitNote.Company AS Company,
	|	DebitNote.CompanyVATNumber AS CompanyVATNumber,
	|	DebitNote.Counterparty AS Counterparty,
	|	DebitNote.Contract AS Contract,
	|	DebitNote.AmountIncludesVAT AS AmountIncludesVAT,
	|	DebitNote.DocumentCurrency AS DocumentCurrency,
	|	CAST(DebitNote.Comment AS STRING(1024)) AS Comment,
	|	DebitNote.BasisDocument AS BasisDocument,
	|	DebitNote.OperationKind AS OperationKind,
	|	DebitNote.AdjustedAmount AS DocumentAmount,
	|	DebitNote.VATRate AS VATRate,
	|	DebitNote.VATAmount AS VATAmount
	|INTO DebitNotes
	|FROM
	|	Document.DebitNote AS DebitNote
	|WHERE
	|	DebitNote.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DebitNoteInventory.Ref AS Ref,
	|	DebitNoteInventory.LineNumber AS LineNumber,
	|	DebitNoteInventory.Amount AS Amount,
	|	DebitNoteInventory.Batch AS Batch,
	|	DebitNoteInventory.Characteristic AS Characteristic,
	|	DebitNoteInventory.ConnectionKey AS ConnectionKey,
	|	DebitNoteInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN DebitNoteInventory.Price = 0
	|			THEN CASE
	|					WHEN DebitNoteInventory.Quantity = 0
	|						THEN 0
	|					ELSE DebitNoteInventory.Amount / DebitNoteInventory.Quantity
	|				END
	|		ELSE DebitNoteInventory.Price
	|	END AS Price,
	|	DebitNoteInventory.Products AS Products,
	|	DebitNoteInventory.Quantity AS Quantity,
	|	DebitNoteInventory.Total AS Total,
	|	DebitNoteInventory.VATAmount AS VATAmount,
	|	DebitNoteInventory.VATRate AS VATRate,
	|	DebitNoteInventory.SupplierInvoice AS SupplierInvoice
	|INTO FilteredInventory
	|FROM
	|	Document.DebitNote.Inventory AS DebitNoteInventory
	|WHERE
	|	DebitNoteInventory.Ref IN(&ObjectsArray)
	|	AND (DebitNoteInventory.Quantity <> 0
	|			OR DebitNoteInventory.Amount <> 0)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DebitNote.Ref AS Ref,
	|	DebitNote.Number AS DocumentNumber,
	|	DebitNote.Date AS DocumentDate,
	|	DebitNote.Company AS Company,
	|	DebitNote.CompanyVATNumber AS CompanyVATNumber,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	DebitNote.Counterparty AS Counterparty,
	|	DebitNote.Contract AS Contract,
	|	CASE
	|		WHEN CounterpartyContracts.ContactPerson = VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN Counterparties.ContactPerson
	|		ELSE CounterpartyContracts.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	CASE
	|		WHEN DebitNote.BasisDocument <> UNDEFINED
	|			THEN DebitNote.BasisDocument
	|	END AS Invoice,
	|	DebitNote.AmountIncludesVAT AS AmountIncludesVAT,
	|	DebitNote.DocumentCurrency AS DocumentCurrency,
	|	DebitNote.Comment AS Comment,
	|	DebitNote.OperationKind AS OperationKind,
	|	DebitNote.DocumentAmount AS DocumentAmount,
	|	DebitNote.VATRate AS VATRate,
	|	DebitNote.VATAmount AS VATAmount
	|INTO Header
	|FROM
	|	DebitNotes AS DebitNote
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON DebitNote.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DebitNote.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON DebitNote.Contract = CounterpartyContracts.Ref
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
	|	Header.Comment AS Comment,
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
	|	FilteredInventory.SupplierInvoice AS Invoice,
	|	Header.OperationKind AS OperationKind,
	|	FilteredInventory.Batch AS Batch,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	SupplierInvoiceDoc.IncomingDocumentNumber AS IncomingNumber,
	|	SupplierInvoiceDoc.IncomingDocumentDate AS IncomingDate
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
	|		LEFT JOIN Document.SupplierInvoice AS SupplierInvoiceDoc
	|		ON Header.Invoice = SupplierInvoiceDoc.Ref
	|
	|GROUP BY
	|	CatalogProducts.Description,
	|	Header.OperationKind,
	|	FilteredInventory.Batch,
	|	Header.DocumentNumber,
	|	CatalogProducts.UseSerialNumbers,
	|	Header.Ref,
	|	Header.CounterpartyContactPerson,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	FilteredInventory.MeasurementUnit,
	|	Header.Counterparty,
	|	Header.DocumentCurrency,
	|	FilteredInventory.VATRate,
	|	Header.Comment,
	|	Header.DocumentDate,
	|	Header.Contract,
	|	Header.CompanyLogoFile,
	|	CatalogProducts.SKU,
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	Header.AmountIncludesVAT,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Price,
	|	SupplierInvoiceDoc.IncomingDocumentNumber,
	|	SupplierInvoiceDoc.IncomingDocumentDate,
	|	FilteredInventory.SupplierInvoice
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
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
	|	Header.Comment AS Comment,
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
	|	DebitNoteDebitedTransactions.Document AS Document,
	|	Header.DocumentNumber AS IncomingNumber,
	|	Header.DocumentDate AS IncomingDate
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.DebitNote.DebitedTransactions AS DebitNoteDebitedTransactions
	|		ON Header.Ref = DebitNoteDebitedTransactions.Ref
	|			AND (DebitNoteDebitedTransactions.Document REFS Document.DebitNote
	|				OR DebitNoteDebitedTransactions.Document REFS Document.ExpenseReport)
	|WHERE
	|	Header.OperationKind <> VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|	AND Header.OperationKind <> VALUE(Enum.OperationTypesDebitNote.DropShipping)
	|
	|UNION ALL
	|
	|SELECT
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Header.DocumentAmount - Header.VATAmount
	|		ELSE Header.DocumentAmount
	|	END,
	|	Header.VATRate,
	|	Header.Ref,
	|	Header.CompanyLogoFile,
	|	Header.DocumentDate,
	|	Header.DocumentNumber,
	|	Header.Comment,
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	Header.Counterparty,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Header.DocumentAmount
	|		ELSE Header.DocumentAmount + Header.VATAmount
	|	END,
	|	1,
	|	Header.DocumentCurrency,
	|	Header.VATAmount,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Header.DocumentAmount - Header.VATAmount
	|		ELSE Header.DocumentAmount
	|	END,
	|	DebitNoteDebitedTransactions.Document,
	|	AdditionalExpenses.IncomingDocumentNumber,
	|	AdditionalExpenses.IncomingDocumentDate
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.DebitNote.DebitedTransactions AS DebitNoteDebitedTransactions
	|			INNER JOIN Document.AdditionalExpenses AS AdditionalExpenses
	|			ON DebitNoteDebitedTransactions.Document = AdditionalExpenses.Ref
	|		ON Header.Ref = DebitNoteDebitedTransactions.Ref
	|			AND (DebitNoteDebitedTransactions.Document REFS Document.AdditionalExpenses)
	|WHERE
	|	Header.OperationKind <> VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|	AND Header.OperationKind <> VALUE(Enum.OperationTypesDebitNote.DropShipping)
	|
	|UNION ALL
	|
	|SELECT
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Header.DocumentAmount - Header.VATAmount
	|		ELSE Header.DocumentAmount
	|	END,
	|	Header.VATRate,
	|	Header.Ref,
	|	Header.CompanyLogoFile,
	|	Header.DocumentDate,
	|	Header.DocumentNumber,
	|	Header.Comment,
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	Header.Counterparty,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Header.DocumentAmount
	|		ELSE Header.DocumentAmount + Header.VATAmount
	|	END,
	|	1,
	|	Header.DocumentCurrency,
	|	Header.VATAmount,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Header.DocumentAmount - Header.VATAmount
	|		ELSE Header.DocumentAmount
	|	END,
	|	DebitNoteDebitedTransactions.Document,
	|	SupplierInvoice.IncomingDocumentNumber,
	|	SupplierInvoice.IncomingDocumentDate
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.DebitNote.DebitedTransactions AS DebitNoteDebitedTransactions
	|			INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|			ON DebitNoteDebitedTransactions.Document = SupplierInvoice.Ref
	|		ON Header.Ref = DebitNoteDebitedTransactions.Ref
	|			AND (DebitNoteDebitedTransactions.Document REFS Document.SupplierInvoice)
	|WHERE
	|	Header.OperationKind <> VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|	AND Header.OperationKind <> VALUE(Enum.OperationTypesDebitNote.DropShipping)
	|TOTALS
	|	MAX(Amount),
	|	MAX(VATRate),
	|	MAX(CompanyLogoFile),
	|	MAX(DocumentDate),
	|	MAX(DocumentNumber),
	|	MAX(Comment),
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
	|	Inventory.Comment AS Comment,
	|	Inventory.LineNumber AS LineNumber,
	|	Inventory.SKU AS SKU,
	|	Inventory.UseSerialNumbers AS UseSerialNumbers,
	|	Inventory.UOM AS UOM,
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
	|	Inventory.Subtotal - Inventory.Amount AS DiscountAmount,
	|	Inventory.ProductDescription AS ProductDescription,
	|	Inventory.ContentUsed AS ContentUsed,
	|	Inventory.Invoice AS Invoice,
	|	Inventory.OperationKind AS OperationKind,
	|	Inventory.ConnectionKey AS ConnectionKey,
	|	Inventory.Batch AS Batch,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.MeasurementUnit AS MeasurementUnit,
	|	Inventory.CharacteristicDescription AS CharacteristicDescription,
	|	Inventory.BatchDescription AS BatchDescription,
	|	Inventory.IncomingNumber AS IncomingNumber,
	|	Inventory.IncomingDate AS IncomingDate,
	|	Inventory.Products AS Products
	|FROM
	|	Inventory AS Inventory
	|
	|ORDER BY
	|	Inventory.DocumentNumber
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
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	SUM(DiscountAmount),
	|	MAX(Invoice),
	|	MAX(OperationKind),
	|	MAX(IncomingNumber),
	|	MAX(IncomingDate)
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
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_DebitNote";
	Template = PrintManagement.PrintFormTemplate("Document.DebitNote.PF_MXL_DebitNote", LanguageCode);
	
	Header				= ResultArray[4].Select(QueryResultIteration.ByGroupsWithHierarchy);
	Inventory			= ResultArray[5].Select(QueryResultIteration.ByGroupsWithHierarchy);
	TaxesHeaderSel		= ResultArray[6].Select(QueryResultIteration.ByGroupsWithHierarchy);
	SerialNumbersSel	= ResultArray[7].Select(QueryResultIteration.ByGroupsWithHierarchy);
	
	While Header.Next() Do

		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		TitleArea = GetArea("Title", Template, Header, LanguageCode);
		If DisplayPrintOption Then 
			TitleArea.Parameters.OriginalDuplicate = ?(PrintParams.OriginalCopy,
				NStr("en = 'ORIGINAL'; ru = 'ОРИГИНАЛ';pl = 'ORYGINAŁ';es_ES = 'ORIGINAL';es_CO = 'ORIGINAL';tr = 'ORİJİNAL';it = 'ORIGINALE';de = 'ORIGINAL'", LanguageCode),
				NStr("en = 'COPY'; ru = 'КОПИЯ';pl = 'KOPIA';es_ES = 'COPIA';es_CO = 'COPIA';tr = 'KOPYALA';it = 'COPIA';de = 'KOPIE'", LanguageCode));
		EndIf;
		
		SpreadsheetDocument.Put(TitleArea);
		
		CompanyInfoArea = GetArea("CompanyInfo", Template, Header, LanguageCode);
		BarcodesInPrintForms.AddBarcodeToTableDocument(CompanyInfoArea, Header.Ref);
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		Transactions = "";
		
		TabSelection = Header.Select();
		While TabSelection.Next() Do
			If ValueIsFilled(TabSelection.IncomingNumber) Then
				Transactions = TrimAll(Transactions) + ?(IsBlankString(Transactions), "", "; ");
				Presentation = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '%1 dated %2'; ru = '%1 от %2';pl = '%1 z dn. %2';es_ES = '%1 fechado %2';es_CO = '%1 fechado %2';tr = '%1 tarihli %2';it = '%1 con data %2';de = '%1 datiert auf den %2'", LanguageCode),
					ObjectPrefixationClientServer.GetNumberForPrinting(TabSelection.IncomingNumber, True, True),
					Format(TabSelection.IncomingDate, "DLF=D"));
				Transactions = Transactions + Presentation;
			EndIf;
		EndDo;
		
		CounterpartyInfoArea = GetArea("CounterpartyInfo", Template, Header, LanguageCode);
		CounterpartyInfoArea.Parameters.Invoice = Transactions;
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
		CommentArea = GetArea("Comment", Template, Header, LanguageCode);
		SpreadsheetDocument.Put(CommentArea);
		
		#Region PrintDebitNoteLinesArea
		
		LineHeaderArea = Template.GetArea("LineHeaderDiscAllowed");
		SpreadsheetDocument.Put(LineHeaderArea);
		
		LineSectionArea	= Template.GetArea("LineSectionDiscAllowed");
		LineSectionArea.Parameters.Fill(Header);
		LineSectionArea.Parameters.ReasonForCorrection = Common.ObjectAttributeValue(Header.Ref, "ReasonForCorrection");
		SpreadsheetDocument.Put(LineSectionArea);
		
		#EndRegion
		
		#Region PrintDebitNoteTotalsArea
		
		LineTotalArea = Template.GetArea("LineTotal");
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
				NStr("en = 'ORIGINAL'; ru = 'ОРИГИНАЛ';pl = 'ORYGINAŁ';es_ES = 'ORIGINAL';es_CO = 'ORIGINAL';tr = 'ORİJİNAL';it = 'ORIGINALE';de = 'ORIGINAL'"),
				NStr("en = 'COPY'; ru = 'КОПИЯ';pl = 'KOPIA';es_ES = 'COPIA';es_CO = 'COPIA';tr = 'KOPYALA';it = 'COPIA';de = 'KOPIE'"));
		EndIf;
		
		SpreadsheetDocument.Put(TitleArea);
		
		CompanyInfoArea = GetArea("CompanyInfo", Template, Inventory, LanguageCode);
		BarcodesInPrintForms.AddBarcodeToTableDocument(CompanyInfoArea, Inventory.Ref);
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		CounterpartyInfoArea = GetArea("CounterpartyInfo", Template, Inventory, LanguageCode);
		If ValueIsFilled(Inventory.IncomingNumber) Then
			Invoice = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 dated %2'; ru = '%1 от %2';pl = '%1 z dn. %2';es_ES = '%1 fechado %2';es_CO = '%1 fechado %2';tr = '%1 tarihli %2';it = '%1 con data %2';de = '%1 datiert auf den %2'"),
				ObjectPrefixationClientServer.GetNumberForPrinting(Inventory.IncomingNumber, True, True),
				Format(Inventory.IncomingDate, "DLF=D"));
		EndIf;
		CounterpartyInfoArea.Parameters.Invoice = Invoice;
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
		#Region PrintDebitNoteReasonForCorrectionArea
		
		ReasonForCorrectionArea = Template.GetArea("ReasonForCorrection");
		ReasonForCorrectionArea.Parameters.ReasonForCorrection = Common.ObjectAttributeValue(
			Inventory.Ref,
			"ReasonForCorrection");
		
		SpreadsheetDocument.Put(ReasonForCorrectionArea);
		
		#EndRegion
		
		CommentArea = GetArea("Comment", Template, Inventory, LanguageCode);
		SpreadsheetDocument.Put(CommentArea);
		
		#Region PrintDebitNoteTotalsAndTaxesAreaPrefill
		
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
		
		#Region PrintDebitNoteLinesArea
		
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
		
		TabSelection = Inventory.Select();
		
		PricePrecision = PrecisionAppearancetServer.CompanyPrecision(Inventory.Company);
		
		While TabSelection.Next() Do
			
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
			
			AreasToBeChecked = New Array;
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
		
		#Region PrintDebitNoteTotalsAndTaxesArea
		
		For Each Area In TotalsAndTaxesAreasArray Do
			SpreadsheetDocument.Put(Area);
		EndDo;
		
		#Region PrintAdditionalAttributes
		
		If DisplayPrintOption 
			And PrintParams.AdditionalAttributes
			And PrintManagementServerCallDrive.HasAdditionalAttributes(Inventory.Ref) Then
			
			SpreadsheetDocument.Put(EmptyLineArea);
			
			AddAttribHeader = Template.GetArea("AdditionalAttributesStaticHeader");
			SpreadsheetDocument.Put(AddAttribHeader);
			
			SpreadsheetDocument.Put(EmptyLineArea);
			
			AddAttribHeader = Template.GetArea("AdditionalAttributesHeader");
			SpreadsheetDocument.Put(AddAttribHeader);
			
			AddAttribRow = Template.GetArea("AdditionalAttributesRow");
			
			For each Attr In Inventory.Ref.AdditionalAttributes Do
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

#EndRegion

#Region InfobaseUpdate

Procedure RefillGoodsInvoicedNotReceivedRecords() Export
	
	Query = New Query;
	Query.Text = "SELECT
	|	GoodsInvoicedNotReceived.Recorder AS Ref
	|FROM
	|	AccumulationRegister.GoodsInvoicedNotReceived AS GoodsInvoicedNotReceived
	|WHERE
	|	GoodsInvoicedNotReceived.Recorder REFS Document.DebitNote";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DocObject = Selection.Ref.GetObject();
		
		BeginTransaction();
		
		Try
			
			DriveServer.InitializeAdditionalPropertiesForPosting(DocObject.Ref, DocObject.AdditionalProperties);
			InitializeDocumentData(DocObject.Ref, DocObject.AdditionalProperties);
			
			TableGoodsInvoicedNotReceived = DocObject.AdditionalProperties.TableForRegisterRecords.TableGoodsInvoicedNotReceived;
			
			DocObject.RegisterRecords.GoodsInvoicedNotReceived.Write = True;
			DocObject.RegisterRecords.GoodsInvoicedNotReceived.Load(TableGoodsInvoicedNotReceived);
			InfobaseUpdate.WriteRecordSet(DocObject.RegisterRecords.GoodsInvoicedNotReceived, True);
			
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

Procedure SetRegisterIncome() Export
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DebitNote.Ref AS Ref
	|FROM
	|	Document.DebitNote AS DebitNote
	|WHERE
	|	DebitNote.IncomeItem <> VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|	AND NOT DebitNote.RegisterIncome
	|	AND NOT DebitNote.DeletionMark
	|	AND (DebitNote.OperationKind = VALUE(Enum.OperationTypesDebitNote.Adjustments)
	|			OR DebitNote.OperationKind = VALUE(Enum.OperationTypesDebitNote.DiscountReceived))";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DocObject = Selection.Ref.GetObject();
		DocObject.RegisterIncome = True;
		
		Try
			
			InfobaseUpdate.WriteObject(DocObject, , , DocumentWriteMode.Write);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot post document ""%1"". Details: %2'; ru = 'Не удалось провести документ ""%1"". Подробнее: %2';pl = 'Nie można zatwierdzić dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al enviar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al enviar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi kaydedilemiyor. Ayrıntılar: %2';it = 'Impossibile pubblicare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Buchen des Dokuments ""%1"". Details: %2'", DefaultLanguageCode),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				DocObject.Metadata(),
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure PostIncomeAndExpensesRegister() Export
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	IncomeAndExpenses.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses
	|		INNER JOIN Document.DebitNote AS DebitNote
	|		ON IncomeAndExpenses.Recorder = DebitNote.Ref
	|WHERE
	|	IncomeAndExpenses.IncomeAndExpenseItem = VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|	AND (DebitNote.OperationKind = VALUE(Enum.OperationTypesDebitNote.Adjustments)
	|			OR DebitNote.OperationKind = VALUE(Enum.OperationTypesDebitNote.DiscountReceived))";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DocObject = Selection.Recorder.GetObject();
		
		BeginTransaction();
		
		Try
			
			AdditionalProperties = DocObject.AdditionalProperties;
			RegisterRecords = DocObject.RegisterRecords;
			
			DriveServer.InitializeAdditionalPropertiesForPosting(Selection.Recorder, AdditionalProperties);
			
			Documents.DebitNote.InitializeDocumentData(Selection.Recorder, AdditionalProperties);
			
			DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, False);
			
			InfobaseUpdate.WriteRecordSet(RegisterRecords.IncomeAndExpenses);
			
			AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Error while saving record set %1: %2.'; ru = 'Ошибка при записи набора записей %1: %2.';pl = 'Błąd podczas zapisywania zestawu wpisów %1: %2.';es_ES = 'Error al guardar el conjunto de registros %1:%2';es_CO = 'Error al guardar el conjunto de registros %1:%2';tr = '%1 kayıt kümesi kaydedilirken hata oluştu: %2.';it = 'Si è verificato un errore durante il salvataggio dell''insieme di registrazioni %1: %2.';de = 'Fehler beim Speichern von Satz von Einträgen %1: %2.'", DefaultLanguageCode),
				Selection.Recorder,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.AccumulationRegisters.IncomeAndExpenses,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure RefillVATItputRecords() Export
	
	Query = New Query;
	Query.Text = "SELECT DISTINCT
	|	VATInput.Recorder AS Ref
	|FROM
	|	AccumulationRegister.VATInput AS VATInput
	|		INNER JOIN Document.DebitNote AS DebitNote
	|		ON VATInput.Recorder = DebitNote.Ref
	|WHERE
	|	VATInput.GLAccount = &VATOutput";
	
	Query.SetParameter("VATOutput", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput"));
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DocObject = Selection.Ref.GetObject();
		
		BeginTransaction();
		
		Try
			
			DriveServer.InitializeAdditionalPropertiesForPosting(DocObject.Ref, DocObject.AdditionalProperties);
			
			AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(DocObject.Ref, DocObject.AdditionalProperties, False);
			If DocObject.AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
			
				MessageText = NStr("en = 'Cannot post document ""%1"". 
					|The applicable Accounting transaction template is required.
					|Details: %2'; 
					|ru = 'Не удалось провести документ ""%1"". 
					|Требуется соответствующий шаблон бухгалтерских операций.
					|Подробнее: %2';
					|pl = 'Nie można zatwierdzić dokumentu ""%1"". 
					|Wymagany jest odpowiedni szablon transakcji księgowej.
					|Szczegóły: %2';
					|es_ES = 'No se ha podido contabilizar el documento ""%1"". 
					|Se requiere la plantilla de transacción contable aplicable. 
					|Detalles: %2';
					|es_CO = 'No se ha podido contabilizar el documento ""%1"". 
					|Se requiere la plantilla de transacción contable aplicable. 
					|Detalles: %2';
					|tr = '""%1"" belgesi kaydedilemiyor.
					|Uygulanabilir Muhasebe işlemi şablonu gerekli.
					|Ayrıntılar: %2';
					|it = 'Impossibile pubblicare il documento ""%1"". 
					|È richiesto il modello di transazione contabile applicabile.
					|Dettagli: %2';
					|de = 'Fehler beim Buchen des Dokuments ""%1"". 
					|Die verwendbare Buchhaltungstransaktionsvorlage ist erforderlich. 
					|Details: %2'", CommonClientServer.DefaultLanguageCode());
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					MessageText,
					DocObject.Ref,
					BriefErrorDescription(ErrorInfo()));
				
				WriteLogEvent(
					InfobaseUpdate.EventLogEvent(),
					EventLogLevel.Error,
					DocObject.Ref.Metadata(),
					,
					ErrorDescription);
					
				Continue;
				
			EndIf;
		
			InitializeDocumentData(DocObject.Ref, DocObject.AdditionalProperties);
			
			TableVATInput = DocObject.AdditionalProperties.TableForRegisterRecords.TableVATInput;
			
			DocObject.RegisterRecords.VATInput.Write = True;
			DocObject.RegisterRecords.VATInput.Load(TableVATInput);
			InfobaseUpdate.WriteRecordSet(DocObject.RegisterRecords.VATInput, True);
			
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