#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
Procedure InitializeDocumentData(DocumentRefPurchaseOrder, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	PurchaseOrder.Ref AS Ref,
	|	PurchaseOrder.Closed AS Closed,
	|	PurchaseOrder.OrderState AS OrderState,
	|	PurchaseOrder.OperationKind AS OperationKind,
	|	PurchaseOrder.Date AS Date,
	|	PurchaseOrder.StructuralUnitReserve AS StructuralUnitReserve,
	|	PurchaseOrder.Counterparty AS Counterparty,
	|	PurchaseOrder.ShippingAddress AS ShippingAddress
	|INTO PurchaseOrderTable
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	PurchaseOrder.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderTable.Ref AS Ref,
	|	PurchaseOrderTable.Closed AS Closed,
	|	PurchaseOrderTable.OperationKind AS OperationKind,
	|	PurchaseOrderTable.Date AS Date,
	|	PurchaseOrderTable.StructuralUnitReserve AS StructuralUnitReserve,
	|	PurchaseOrderTable.Counterparty AS Counterparty,
	|	PurchaseOrderTable.ShippingAddress AS ShippingAddress
	|INTO PurchaseOrderHeader
	|FROM
	|	PurchaseOrderTable AS PurchaseOrderTable
	|		INNER JOIN Catalog.PurchaseOrderStatuses AS PurchaseOrderStatuses
	|		ON PurchaseOrderTable.OrderState = PurchaseOrderStatuses.Ref
	|WHERE
	|	(PurchaseOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND PurchaseOrderTable.Closed = FALSE
	|			OR PurchaseOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	PurchaseOrderInventory.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	PurchaseOrderInventory.Ref AS PurchaseOrder,
	|	PurchaseOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PurchaseOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN PurchaseOrderInventory.Quantity
	|		ELSE PurchaseOrderInventory.Quantity * PurchaseOrderInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	PurchaseOrderInventory.ReceiptDate AS ReceiptDate
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|		INNER JOIN PurchaseOrderHeader AS PurchaseOrderHeader
	|		ON PurchaseOrderInventory.Ref = PurchaseOrderHeader.Ref
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderMaterials.LineNumber AS LineNumber,
	|	PurchaseOrderMaterials.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	VALUE(Document.SalesOrder.EmptyRef) AS SalesOrder,
	|	PurchaseOrderMaterials.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PurchaseOrderMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrderMaterials.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN PurchaseOrderMaterials.Quantity
	|		ELSE PurchaseOrderMaterials.Quantity * PurchaseOrderMaterials.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.PurchaseOrder.Materials AS PurchaseOrderMaterials
	|		INNER JOIN PurchaseOrderHeader AS PurchaseOrderHeader
	|		ON PurchaseOrderMaterials.Ref = PurchaseOrderHeader.Ref
	|WHERE
	|	PurchaseOrderHeader.OperationKind = VALUE(Enum.OperationTypesPurchaseOrder.OrderForProcessing)
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	PurchaseOrderInventory.ReceiptDate AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Receipt) AS MovementType,
	|	PurchaseOrderInventory.Ref AS Order,
	|	PurchaseOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PurchaseOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN PurchaseOrderInventory.Quantity
	|		ELSE PurchaseOrderInventory.Quantity * PurchaseOrderInventory.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|		INNER JOIN PurchaseOrderHeader AS PurchaseOrderHeader
	|		ON PurchaseOrderInventory.Ref = PurchaseOrderHeader.Ref
	|WHERE
	|	NOT PurchaseOrderHeader.OperationKind = VALUE(Enum.OperationTypesPurchaseOrder.OrderForDropShipping)
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	PurchaseOrderInventory.LineNumber,
	|	PurchaseOrderInventory.ShipmentDate,
	|	&Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment),
	|	UNDEFINED,
	|	PurchaseOrderInventory.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PurchaseOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN PurchaseOrderInventory.Quantity
	|		ELSE PurchaseOrderInventory.Quantity * PurchaseOrderInventory.MeasurementUnit.Factor
	|	END
	|FROM
	|	Document.PurchaseOrder.Materials AS PurchaseOrderInventory
	|		INNER JOIN PurchaseOrderHeader AS PurchaseOrderHeader
	|		ON PurchaseOrderInventory.Ref = PurchaseOrderHeader.Ref
	|WHERE
	|	PurchaseOrderHeader.OperationKind = VALUE(Enum.OperationTypesPurchaseOrder.OrderForProcessing)
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	PurchaseOrderHeader.Date AS Period,
	|	&Company AS Company,
	|	PurchaseOrderInventory.SalesOrder AS SalesOrder,
	|	PurchaseOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PurchaseOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	PurchaseOrderInventory.Ref AS SupplySource,
	|	PurchaseOrderInventory.Quantity * ISNULL(UOM.Factor, 1) AS Quantity,
	|	CASE
	|		WHEN NOT DocumentSalesOrder.Ref IS NULL
	|			THEN DocumentSalesOrder.Closed
	|		WHEN NOT DocumentWorkOrder.Ref IS NULL
	|			THEN DocumentWorkOrder.Closed
	// begin Drive.FullVersion
	|		WHEN NOT DocumentProductionOrder.Ref IS NULL
	|			THEN DocumentProductionOrder.Closed
	// end Drive.FullVersion
	|		ELSE FALSE
	|	END AS SalesOrderClosed
	|INTO TemporaryTableBackorders
	|FROM
	|	PurchaseOrderHeader AS PurchaseOrderHeader
	|		INNER JOIN Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|		ON PurchaseOrderHeader.Ref = PurchaseOrderInventory.Ref
	|		LEFT JOIN Document.SalesOrder AS DocumentSalesOrder
	|		ON (PurchaseOrderInventory.SalesOrder = DocumentSalesOrder.Ref)
	|		LEFT JOIN Document.WorkOrder AS DocumentWorkOrder
	|		ON (PurchaseOrderInventory.SalesOrder = DocumentWorkOrder.Ref)
	// begin Drive.FullVersion
	|		LEFT JOIN Document.ProductionOrder AS DocumentProductionOrder
	|		ON (PurchaseOrderInventory.SalesOrder = DocumentProductionOrder.Ref)
	|		LEFT JOIN Document.ManufacturingOperation AS DocumentManufacturingOperation
	|		ON (PurchaseOrderInventory.SalesOrder = DocumentManufacturingOperation.Ref)
	// end Drive.FullVersion
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (PurchaseOrderInventory.MeasurementUnit = UOM.Ref),
	|	Constants AS Constants
	|WHERE
	|	Constants.UseInventoryReservation
	|	AND (NOT DocumentSalesOrder.Ref IS NULL
	|			OR NOT DocumentWorkOrder.Ref IS NULL
	// begin Drive.FullVersion
	|			OR NOT DocumentProductionOrder.Ref IS NULL
	|			OR NOT DocumentManufacturingOperation.Ref IS NULL
	// end Drive.FullVersion
	|		)
	|	AND NOT PurchaseOrderHeader.OperationKind = VALUE(Enum.OperationTypesPurchaseOrder.OrderForDropShipping)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderMaterials.LineNumber AS LineNumber,
	|	PurchaseOrderHeader.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	PurchaseOrderHeader.StructuralUnitReserve AS StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN PurchaseOrderMaterials.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	PurchaseOrderMaterials.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PurchaseOrderMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	CASE
	|		WHEN Constants.UseInventoryReservation
	|			THEN PurchaseOrderHeader.Ref
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrderMaterials.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN PurchaseOrderMaterials.Reserve
	|		ELSE PurchaseOrderMaterials.Reserve * PurchaseOrderMaterials.MeasurementUnit.Factor
	|	END AS Quantity
	|INTO TemporaryTableInventory
	|FROM
	|	Document.PurchaseOrder.Materials AS PurchaseOrderMaterials
	|		INNER JOIN PurchaseOrderHeader AS PurchaseOrderHeader
	|		ON PurchaseOrderMaterials.Ref = PurchaseOrderHeader.Ref,
	|	Constants AS Constants
	|WHERE
	|	PurchaseOrderMaterials.Reserve > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderHeader.Date AS Period,
	|	&Company AS Company,
	|	PurchaseOrderInventory.SalesOrder AS SalesOrder,
	|	PurchaseOrderInventory.Ref AS PurchaseOrder,
	|	PurchaseOrderHeader.Counterparty AS Supplier,
	|	DocumentSalesOrder.Counterparty AS Customer,
	|	PurchaseOrderHeader.OperationKind AS FulfillmentMethod,
	|	PurchaseOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PurchaseOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	PurchaseOrderInventory.Quantity * ISNULL(UOM.Factor, 1) AS Quantity,
	|	PurchaseOrderHeader.ShippingAddress AS ShippingAddress
	|INTO TemporaryTableOrdersByFulfillmentMethod
	|FROM
	|	PurchaseOrderHeader AS PurchaseOrderHeader
	|		INNER JOIN Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|		ON PurchaseOrderHeader.Ref = PurchaseOrderInventory.Ref
	|		INNER JOIN Document.SalesOrder AS DocumentSalesOrder
	|		ON (PurchaseOrderInventory.SalesOrder = DocumentSalesOrder.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (PurchaseOrderInventory.MeasurementUnit = UOM.Ref),
	|	Constant.UseDropShipping AS UseDropShipping
	|WHERE
	|	UseDropShipping.Value";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefPurchaseOrder);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",  StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchaseOrders", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryFlowCalendar", ResultsArray[4].Unload());
	
	GenerateTableBackorders(DocumentRefPurchaseOrder, StructureAdditionalProperties);
	GenerateTableReservedProducts(DocumentRefPurchaseOrder, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefPurchaseOrder, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRefPurchaseOrder, StructureAdditionalProperties);
	GenerateTableOrdersByFulfillmentMethod(DocumentRefPurchaseOrder, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefPurchaseOrder, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsPurchaseOrdersChange", "RegisterRecordsInventoryChange",
	// "RegisterRecordsInventoryDemandChange" contain records, control purchse order.
	
	If StructureTemporaryTables.RegisterRecordsPurchaseOrdersChange
		OR StructureTemporaryTables.RegisterRecordsReservedProductsChange
		OR StructureTemporaryTables.RegisterRecordsInventoryDemandChange Then
		
		Query = New Query(
		"SELECT
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
		|	LineNumber");
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.ReservedProducts.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty() Then
			DocumentObjectPurchaseOrder = DocumentRefPurchaseOrder.GetObject()
		EndIf;
		
		// Negative balance on the order to the vendor.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToPurchaseOrdersRegisterErrors(DocumentObjectPurchaseOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of need for inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryDemandRegisterErrors(DocumentObjectPurchaseOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of need for reserved products.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToReservedProductsRegisterErrors(DocumentObjectPurchaseOrder, QueryResultSelection, Cancel);
		EndIf;
		
		DriveServer.CheckAvailableStockBalance(DocumentObjectPurchaseOrder, AdditionalProperties, Cancel);
		
		DriveServer.CheckSalesOrdersMinusBackordersBalance(DocumentObjectPurchaseOrder, AdditionalProperties, Cancel);
		
		DriveServer.CheckOrderedMinusBackorderedBalance(DocumentRefPurchaseOrder, AdditionalProperties, Cancel);
		
	EndIf;
	
EndProcedure

// Checks the possibility of input on the basis.
//
Procedure CheckEnteringAbilityOnTheBasisOfVendorOrder(FillingData, AttributeValues) Export
	
	If AttributeValues.Property("Posted") Then
		If Not AttributeValues.Posted Then
			Raise NStr("en = 'Cannot generate documents from unposted documents.
						|Post this document first. Then try again.'; 
						|ru = 'Создание документов на основании непроведенных документов запрещено.
						|Проведите документ и повторите попытку.';
						|pl = 'Nie można wygenerować dokumentów z niezatwierdzonych dokumentów.
						|Najpierw zatwierdź ten dokument. Zatem spróbuj ponownie.';
						|es_ES = 'No se han podido generar documentos desde los documentos no enviados.
						|En primer lugar, envíe este documento. Inténtelo de nuevo.';
						|es_CO = 'No se han podido generar documentos desde los documentos no enviados.
						|En primer lugar, envíe este documento. Inténtelo de nuevo.';
						|tr = 'Kaydedilmemiş belgelerden belge oluşturulamaz.
						|Önce bu belgeyi kaydedip tekrar deneyin.';
						|it = 'Impossibile creare i documenti dai documenti non pubblicati. 
						|Pubblicare prima questo documento, poi riprovare.';
						|de = 'Fehler beim Generieren von Dokumenten aus nicht gebuchten Dokumenten.
						|Buchen Sie dieses Dokument zuerst. Dann versuchen Sie erneut.'");
		EndIf;
	EndIf;
	
	If AttributeValues.Property("Closed") Then
		If AttributeValues.Closed Then
			Raise NStr("en = 'Please select an order that is not completed.'; ru = 'Ввод на основании закрытого заказа запрещен.';pl = 'Wybierz zamówienie, które nie zostało zakończone.';es_ES = 'Por favor, seleccione un orden que no esté finalizado.';es_CO = 'Por favor, seleccione un orden que no esté finalizado.';tr = 'Lütfen, tamamlanmamış bir sipariş seçin.';it = 'Si prega di selezionare un ordine che non è stato completato.';de = 'Bitte wählen Sie eine Bestellung aus, die noch nicht abgeschlossen ist.'");
		EndIf;
	EndIf;
	
	If AttributeValues.Property("OrderState") Then
		If AttributeValues.OrderState.OrderStatus = Enums.OrderStatuses.Open Then
			Raise NStr("en = 'Generation from orders with ""Open"" status is not available.'; ru = 'Ввод на основании заказа в статусе ""Открыт"" запрещен.';pl = 'Generowanie zamówień ze statusem ""Otwarty"" nie jest dostępne.';es_ES = 'Generación de los órdenes con el estado ""Abierto"" no se encuentra disponible.';es_CO = 'Generación de los órdenes con el estado ""Abierto"" no se encuentra disponible.';tr = 'Durumu ""Açık"" olan siparişlerden üretim yapılamaz.';it = 'La generazione degli ordini con stato ""Aperto"" non è disponibile';de = 'Die Generierung aus Aufträgen mit dem Status ""Offen"" ist nicht verfügbar.'");
		EndIf;
	EndIf;
	
	If AttributeValues.Property("GoodsIssue")
		AND AttributeValues.Property("OperationKind")
		AND AttributeValues.OperationKind <> Enums.OperationTypesPurchaseOrder.OrderForProcessing Then
			
			ErrorText = NStr("en = 'Cannot use %1 as a base document for Goods Issue. Please select a purchase order with ""Subcontractor order"" operation.'; ru = '%1 не может быть основанием для отпуска товаров. Выберите заказ поставщику с видом операции ""Заказ на переработку"".';pl = 'Nie można użyć %1 jako dokumentu źródłowego do wydania zewnętrznego. Wybierz zamówienie z operacją ""Zamówienie podwykonawcy"".';es_ES = 'No se puede usar %1 como el documento típico para la Salida de mercancías. Por favor seleccione una orden de compra con operación ""Orden de subcontratista"".';es_CO = 'No se puede usar %1 como el documento típico para la Expedición de Productos. Por favor seleccione una orden de compra con operación ""Orden de subcontratista"".';tr = '%1, Ambar çıkışı için temel belge olarak kullanılamaz. Lütfen ""alt yüklenici siparişi"" işlemi ile bir satın alma siparişi seçin.';it = 'Non è possibile usare %1 come documento di base per la Spedizione merce. Si prega di selezionare un ordine di acquisto con operazione ""Ordine di subfornitura"".';de = 'Kann nicht %1 als Basisdokument für den Warenausgang verwendet werden. Bitte wählen Sie eine Bestellung an Lieferanten mit der Operation ""Subunternehmerbestellung"" aus.'");
			Raise StringFunctionsClientServer.SubstituteParametersToString(
					ErrorText,
					FillingData);
	EndIf;
				
	CheckMustBeApproved(FillingData);
	
EndProcedure

Procedure CheckMustBeApproved(PurchaseOrder) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	PurchaseOrder.Ref AS Ref,
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	PurchaseOrder.DocumentAmount AS DocumentAmount,
	|	PurchaseOrder.Contract AS Contract,
	|	UsePurchaseOrderApproval.Value AS Value,
	|	PurchaseOrder.Company AS Company,
	|	PurchaseOrder.Date AS Date,
	|	PurchaseOrder.ApprovalStatus AS ApprovalStatus,
	|	PurchaseOrder.ExchangeRate AS ExchangeRate,
	|	PurchaseOrder.Multiplicity AS Multiplicity
	|INTO PurchaseOrders
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|		LEFT JOIN Constant.UsePurchaseOrderApproval AS UsePurchaseOrderApproval
	|		ON (TRUE)
	|WHERE
	|	PurchaseOrder.Ref = &PurchaseOrder
	|	AND UsePurchaseOrderApproval.Value
	|	AND PurchaseOrder.ApprovalStatus <> VALUE(Enum.ApprovalStatuses.Approved)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrders.Ref AS Ref,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	CounterpartyContracts.ApprovePurchaseOrders AS ApprovePurchaseOrders,
	|	CASE
	|		WHEN PurchaseOrdersApprovalType.Value = VALUE(Enum.PurchaseOrdersApprovalTypes.ApproveGreaterAmount)
	|			THEN LimitWithoutPurchaseOrderApproval.Value
	|		ELSE CounterpartyContracts.LimitWithoutApproval
	|	END AS LimitWithoutApproval,
	|	PurchaseOrders.DocumentCurrency AS DocumentCurrency,
	|	PurchaseOrders.DocumentAmount AS DocumentAmount,
	|	Companies.ExchangeRateMethod AS ExchangeRateMethod,
	|	PurchaseOrders.Company AS Company,
	|	PurchaseOrders.Date AS Date,
	|	PurchaseOrders.ApprovalStatus AS ApprovalStatus,
	|	PurchaseOrders.ExchangeRate AS ExchangeRate,
	|	PurchaseOrders.Multiplicity AS Multiplicity
	|FROM
	|	PurchaseOrders AS PurchaseOrders
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON PurchaseOrders.Contract = CounterpartyContracts.Ref
	|		INNER JOIN Catalog.Companies AS Companies
	|		ON PurchaseOrders.Company = Companies.Ref
	|		LEFT JOIN Constant.PurchaseOrdersApprovalType AS PurchaseOrdersApprovalType
	|		ON (TRUE)
	|		LEFT JOIN Constant.LimitWithoutPurchaseOrderApproval AS LimitWithoutPurchaseOrderApproval
	|		ON (TRUE)";
	
	Query.SetParameter("PurchaseOrder", PurchaseOrder);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		
		If Selection.DocumentCurrency <> Selection.SettlementsCurrency Then
			
			DocumentCurrencyStructure = New Structure;
			DocumentCurrencyStructure.Insert("Currency", Selection.DocumentCurrency);
			DocumentCurrencyStructure.Insert("Rate", Selection.ExchangeRate);
			DocumentCurrencyStructure.Insert("Repetition", Selection.Multiplicity);
			
			LimitWithoutApproval = CurrenciesExchangeRatesClientServer.ConvertAtRate(
				Selection.LimitWithoutApproval,
			    Selection.ExchangeRateMethod,
				CurrencyRateOperations.GetCurrencyRate(Selection.Date, Selection.SettlementsCurrency, Selection.Company),
				DocumentCurrencyStructure);
			
		Else
			LimitWithoutApproval = Selection.LimitWithoutApproval;
		EndIf;
		
		If Selection.DocumentAmount > LimitWithoutApproval 
			And Selection.ApprovalStatus <> Enums.ApprovalStatuses.Approved Then
			
			ErrorText = NStr("en = 'Cannot use not approved %1. Please get purchase order approval and try again.'; ru = 'Не удалось применить не утвержденный %1. Получите утверждение заказа поставщику и повторите попытку.';pl = 'Nie można użyć niezatwierdzonego %1. Uzyskaj zatwierdzenie zamówienia i spróbuj ponownie.';es_ES = 'No se puede utilizar sin aprobación%1. Por favor, obtenga la aprobación de la orden de compra e inténtelo de nuevo.';es_CO = 'No se puede utilizar sin aprobación%1. Por favor, obtenga la aprobación de la orden de compra e inténtelo de nuevo.';tr = 'Onaylanmamış %1 kullanılamıyor. Lütfen, satın alma siparişi onayı alıp tekrar deneyin.';it = 'Impossibile utilizzare %1 non approvato. Ottenere approvazione dell''ordine di acquisto e riprovare.';de = 'Kann nicht genehmigte %1 nicht verwenden. Bitte holen Sie die Genehmigung der Bestellung an Lieferanten ein und versuchen erneut.'");
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				ErrorText,
				PurchaseOrder);
		EndIf;
		
	EndDo;
		
EndProcedure

Function GetDocumentsWithAprrovalStatus() Export
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	PurchaseOrder.Ref AS Ref
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	PurchaseOrder.ApprovalStatus <> VALUE(Enum.ApprovalStatuses.EmptyRef)
	|	AND NOT PurchaseOrder.DeletionMark";
	
	QueryResult = Query.Execute();
	Return Not QueryResult.IsEmpty();
	
EndFunction

Function GetPurchaseOrderStringStatuses() Export
	
	StatusesStructure = DriveServer.GetOrderStringStatuses();
	
	Return StatusesStructure;
	
EndFunction

Procedure ChangePurchaseOrderApprovalStatus(PurchaseOrder, BusinessProcess) Export
	
	If ValueIsFilled(PurchaseOrder)
		And TypeOf(PurchaseOrder) = Type("DocumentRef.PurchaseOrder") Then

		SetPrivilegedMode(True);
		
		OrderObject = PurchaseOrder.GetObject();
		
		If BusinessProcess.ApprovalResult = Enums.ApprovalResults.Approved Then
			NewApprovalStatus = Enums.ApprovalStatuses.Approved;
			OrderObject.Approver = BusinessProcess.Approver;
			OrderObject.ApprovalDate = BusinessProcess.ApprovalDate;
		ElsIf BusinessProcess.ApprovalResult = Enums.ApprovalResults.NotApproved Then
			NewApprovalStatus = Enums.ApprovalStatuses.Rejected;
			OrderObject.Approver = Catalogs.Users.EmptyRef();
			OrderObject.ApprovalDate = Date(1,1,1);
		Else
			NewApprovalStatus = Enums.ApprovalStatuses.SentForApproval;
		EndIf;
		
		If NewApprovalStatus <> OrderObject.ApprovalStatus Then

			OrderObject.ApprovalStatus = NewApprovalStatus;				
			
			Try 
				OrderObject.Write();
			Except
				
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
								NStr("en = 'Cannot write %1. %2'; ru = 'Не удалось записать %1. %2';pl = 'Nie można zapisać %1. %2';es_ES = 'No se puede guardar %1.%2';es_CO = 'No se puede guardar %1.%2';tr = '%1 yazılamıyor. %2';it = 'Impossibile scrivere %1. %2';de = 'Kann nicht schreiben %1. %2'"),
								PurchaseOrder,
								BriefErrorDescription(ErrorInfo()));
				Raise ErrorText;
				
			EndTry;
			
		EndIf;
		
		SetPrivilegedMode(False);
		
	EndIf;
	
EndProcedure

#EndRegion 

#Region Internal

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	GLAccountsForFilling = New Structure;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	Return New Structure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Return New Structure;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// The procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined, AdditionalParameters = Undefined)
	
	If TemplateName = "PurchaseOrder" Then
		
		IsDropShipping = (AdditionalParameters.Property("DropShipping") And AdditionalParameters.DropShipping);
		
		Return PrintPurchaseOrder(ObjectsArray, PrintObjects, TemplateName, PrintParams, IsDropShipping);
		
	ElsIf TemplateName = "PurchaseOrderInTermsOfSupplier" Then
		
		Return PrintPurchaseOrder(ObjectsArray, PrintObjects, TemplateName, PrintParams);
		
	EndIf;
	
EndFunction

// The procedure of document printing.
Function PrintPurchaseOrder(ObjectsArray, PrintObjects, TemplateName, PrintParams, IsDropShipping = False)
	
	DisplayPrintOption = (PrintParams <> Undefined);
	
	StructureFlags			= DriveServer.GetStructureFlags(DisplayPrintOption, PrintParams);
	StructureSecondFlags	= DriveServer.GetStructureSecondFlags(DisplayPrintOption, PrintParams);
	CounterShift			= DriveServer.GetCounterShift(StructureFlags);
		
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_PurchaseOrder";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	Query.SetParameter("IsDiscount", StructureFlags.IsDiscount);
	Query.SetParameter("IsPriceBeforeDiscount", StructureSecondFlags.IsPriceBeforeDiscount);
	
	#Region PrintPurchaseOrderQueryText
	
	If TemplateName = "PurchaseOrder" 
		And Not IsDropShipping Then
		
		Query.Text = QueryText();
		
	ElsIf TemplateName = "PurchaseOrder" 
		And IsDropShipping Then
		
		Query.Text = QueryTextDropShipping();
		
	ElsIf TemplateName = "PurchaseOrderInTermsOfSupplier" Then
		
		Query.Text = QueryTextInTermsOfSupplier();
		
	EndIf;
	
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
	
	ResultArray = Query.Execute();
	
	FirstDocument = True;
	
	Header = ResultArray.Select(QueryResultIteration.ByGroupsWithHierarchy);
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Template = PrintManagement.PrintFormTemplate("Document.PurchaseOrder.PF_MXL_PurchaseOrderTemplate", LanguageCode);
		
		#Region PrintPurchaseOrderTitleArea
		
		StringNameLineArea = "Title";
		TitleArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
		TitleArea.Parameters.Fill(Header);
		
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Counterparty,
			Header.DocumentDate,
			,
			,
			,
			LanguageCode);
			
		TitleArea.Parameters.FullDescr = InfoAboutCounterparty.FullDescr;
		
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
		
		#Region PrintOrderConfirmationCompanyInfoArea
		
		StringNameLineArea = "CompanyInfo";
		CompanyInfoArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Company, Header.DocumentDate, , , Header.CompanyVATNumber, LanguageCode);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		BarcodesInPrintForms.AddBarcodeToTableDocument(CompanyInfoArea, Header.Ref);
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		IsPictureBarcode = GetFunctionalOption("UseBarcodesInPrintForms");
		If IsPictureBarcode Then
			DriveServer.MakeShiftPictureWithShift(SpreadsheetDocument.Drawings.DocumentBarcode, CounterShift - 1);
		EndIf;
		
		DriveServer.AddPartAdditionalToAreaWithShift(
			Template,
			SpreadsheetDocument,
			CounterShift,
			StringNameLineArea,
			"PartAdditional" + StringNameLineArea);
		
		#EndRegion
		
		#Region PrintPurchaseOrderWarehouseInfoArea
		
		StringNameLineArea = "WarehouseInfo";
		WarehouseInfoArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
		
		WarehouseInfoArea.Parameters.Fill(InfoAboutCompany);
		
		If IsDropShipping Then
			
			InfoAboutShippingAddress	= DriveServer.InfoAboutShippingAddress(Header.ShippingAddress);
			InfoAboutContactPerson		= DriveServer.InfoAboutContactPerson(Header.ContactPerson);
			
			InfoAboutCustomer = New Structure;
			If IsBlankString(InfoAboutShippingAddress.DeliveryAddress) 
				And ValueIsFilled(Header.ShippingAddress)
				And TypeOf(Header.ShippingAddress) = Type("CatalogRef.Counterparties") Then
				
				InfoAboutCustomer = DriveServer.InfoAboutLegalEntityIndividual(
					Header.ShippingAddress,
					Header.DocumentDate,
					,
					,
					,
					LanguageCode);
					
			EndIf;
			
			If ValueIsFilled(Header.ContactPerson) Then
				
				CounterpartyContactPerson	= Common.ObjectAttributesValues(Header.ContactPerson, 
												"Owner, Owner.Description, Owner.DescriptionFull");
					
				If ValueIsFilled(CounterpartyContactPerson.OwnerDescriptionFull) Then
					WarehouseInfoArea.Parameters.WarehouseDescr = CounterpartyContactPerson.OwnerDescriptionFull;
				Else
					WarehouseInfoArea.Parameters.WarehouseDescr = CounterpartyContactPerson.OwnerDescription;
				EndIf;
				
			EndIf;
			
			If Not IsBlankString(InfoAboutShippingAddress.DeliveryAddress) Then
				WarehouseInfoArea.Parameters.WarehouseAddress = InfoAboutShippingAddress.DeliveryAddress;
			ElsIf InfoAboutCustomer.Property("DeliveryAddress") And Not IsBlankString(InfoAboutCustomer.DeliveryAddress) Then
				WarehouseInfoArea.Parameters.WarehouseAddress = InfoAboutCustomer.DeliveryAddress;
			EndIf;
			
			If Not IsBlankString(InfoAboutContactPerson.PhoneNumbers) Then
				WarehouseInfoArea.Parameters.ContactPhoneNumbers = InfoAboutContactPerson.PhoneNumbers;
			EndIf;
			
			WarehouseInfoArea.Parameters.WarehouseContactPerson = Header.ContactPerson;
			
		Else
			
			InfoAboutWarehouse = DriveServer.InfoAboutLegalEntityIndividual(
				Header.Warehouse,
				Header.DocumentDate,
				,
				,
				,
				LanguageCode);
			WarehouseInfoArea.Parameters.WarehouseDescr = InfoAboutWarehouse.FullDescr;
			WarehouseInfoArea.Parameters.WarehouseAddress = InfoAboutWarehouse.DeliveryAddress;
			WarehouseInfoArea.Parameters.WarehousePhoneNumbers = InfoAboutWarehouse.PhoneNumbers;
			
			InfoAboutContactPerson = DriveServer.InfoAboutLegalEntityIndividual(InfoAboutWarehouse.ResponsibleEmployee, Header.DocumentDate);
			WarehouseInfoArea.Parameters.WarehouseContactPerson = InfoAboutContactPerson.FullDescr;
			WarehouseInfoArea.Parameters.ContactPhoneNumbers = InfoAboutContactPerson.PhoneNumbers;
			
			If IsBlankString(WarehouseInfoArea.Parameters.WarehouseAddress) Then
				If Not IsBlankString(InfoAboutCompany.ActualAddress) Then
					WarehouseInfoArea.Parameters.WarehouseAddress = InfoAboutCompany.ActualAddress;
				Else
					WarehouseInfoArea.Parameters.WarehouseAddress = InfoAboutCompany.LegalAddress;
				EndIf;
			EndIf;
			
		EndIf;
		
		WarehouseInfoArea.Parameters.PaymentTerms = PaymentTermsServer.TitleStagesOfPayment(Header.Ref);
		If ValueIsFilled(WarehouseInfoArea.Parameters.PaymentTerms) Then
			WarehouseInfoArea.Parameters.PaymentTermsTitle = PaymentTermsServer.PaymentTermsPrintTitle();
		EndIf;
		
		SpreadsheetDocument.Put(WarehouseInfoArea);
		
		DriveServer.AddPartAdditionalToAreaWithShift(
			Template,
			SpreadsheetDocument,
			CounterShift,
			StringNameLineArea,
			"PartAdditional" + StringNameLineArea);
		
		#EndRegion
		
		#Region PrintOrderConfirmationCommentArea
		
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
		
		#Region PrintOrderConfirmationTotalsAreaPrefill
		
		TotalsAreasArray = New Array;
		
		StringNameLineTotalArea = ?(StructureFlags.IsDiscount, "LineTotal", "LineTotalWithoutDiscount");
		
		StringNameTotalAreaStart		= ?(StructureFlags.IsDiscount, "PartStartLineTotal", "PartStartLineTotalWithoutDiscount");
		StringNameTotalAreaAdditional	= ?(StructureFlags.IsDiscount, "PartAdditional", "PartAdditionalWithoutDiscount");
		StringNameTotalAreaEnd			= ?(StructureFlags.IsDiscount, "PartEndLineTotal", "PartEndLineTotalWithoutDiscount");
		
		LineTotalArea = Template.GetArea(StringNameLineTotalArea + "|" + StringNameTotalAreaStart);
		LineTotalArea.Parameters.Fill(Header);
		
		TotalsArea = New SpreadsheetDocument;
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
		
		TotalsAreasArray.Add(TotalsArea);
		
		#EndRegion
		
		#Region PrintOrderConfirmationLinesArea
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
		
		TabSelection = Header.Select();
		PricePrecision = PrecisionAppearancetServer.CompanyPrecision(Header.Company);
		
		While TabSelection.Next() Do
			
			If TypeOf(TabSelection.FreightTotal) = Type("Number")
				And TabSelection.FreightTotal <> 0 Then
				
				AreasToBeChecked = New Array;
				Continue;
				
			EndIf;
			
			LineSectionAreaStart.Parameters.Fill(TabSelection);
			LineSectionAreaPrice.Parameters.Fill(TabSelection);
			LineSectionAreaPrice.Parameters.Price = Format(TabSelection.Price,
				"NFD= " + PricePrecision);
			
			If StructureFlags.IsDiscount Then
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
			
			AreasToBeChecked = New Array;
			AreasToBeChecked.Add(LineSectionAreaStart);
			For Each Area In TotalsAreasArray Do
				AreasToBeChecked.Add(Area);
			EndDo;
			AreasToBeChecked.Add(PageNumberArea);
			
			If Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
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
				
				#Region PrintPurchaseOrderTitleArea
				
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
		
		#Region PrintOrderConfirmationTotalsArea
		
		For Each Area In TotalsAreasArray Do
			
			SpreadsheetDocument.Put(Area);
			
		EndDo;
		
		AreasToBeChecked.Clear();
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
		
		#Region PrintAdditionalAttributes
		If DisplayPrintOption And PrintParams.AdditionalAttributes
			And PrintManagementServerCallDrive.HasAdditionalAttributes(Header.Ref) Then
			
			SpreadsheetDocument.Put(EmptyLineArea);
			
			AddAttribHeader = Template.GetArea("AdditionalAttributesStaticHeader|PartAdditionalAttributes");
			SpreadsheetDocument.Put(AddAttribHeader);
			
			AddPartAdditionalToArea(
				Template, 
				SpreadsheetDocument, 
				StructureFlags, 
				"AdditionalAttributesStaticHeader", 
				"PartAdditionalAttributesEmptyColumn");
			
			SpreadsheetDocument.Put(EmptyLineArea);
			
			AddAttribHeader = Template.GetArea("AdditionalAttributesHeader|PartAdditionalAttributes");
			SpreadsheetDocument.Put(AddAttribHeader);
			
			AddAttribRow = Template.GetArea("AdditionalAttributesRow|PartAdditionalAttributes");
			
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

// The procedure of document printing.
Function QueryTextInTermsOfSupplier()
	
	QueryText = 
	"SELECT ALLOWED
	|	PurchaseOrder.Ref AS Ref,
	|	PurchaseOrder.Number AS Number,
	|	PurchaseOrder.Date AS Date,
	|	PurchaseOrder.Company AS Company,
	|	PurchaseOrder.CompanyVATNumber AS CompanyVATNumber,
	|	PurchaseOrder.Counterparty AS Counterparty,
	|	PurchaseOrder.Contract AS Contract,
	|	PurchaseOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	CAST(PurchaseOrder.Comment AS STRING(1024)) AS Comment,
	|	PurchaseOrder.Warehouse AS Warehouse
	|INTO PurchaseOrders
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	PurchaseOrder.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PurchaseOrder.Ref AS Ref,
	|	PurchaseOrder.Number AS DocumentNumber,
	|	PurchaseOrder.Date AS DocumentDate,
	|	PurchaseOrder.Company AS Company,
	|	PurchaseOrder.CompanyVATNumber AS CompanyVATNumber,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	PurchaseOrder.Counterparty AS Counterparty,
	|	PurchaseOrder.Contract AS Contract,
	|	CASE
	|		WHEN CounterpartyContracts.ContactPerson = VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN Counterparties.ContactPerson
	|		ELSE CounterpartyContracts.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	PurchaseOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	PurchaseOrder.Comment AS Comment,
	|	PurchaseOrder.Warehouse AS Warehouse
	|INTO Header
	|FROM
	|	PurchaseOrders AS PurchaseOrder
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON PurchaseOrder.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON PurchaseOrder.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON PurchaseOrder.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PurchaseOrderInventory.Ref AS Ref,
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	PurchaseOrderInventory.Products AS Products,
	|	PurchaseOrderInventory.Characteristic AS Characteristic,
	|	PurchaseOrderInventory.Quantity AS Quantity,
	|	PurchaseOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN PurchaseOrderInventory.Quantity = 0
	|			THEN 0
	|		ELSE CASE
	|				WHEN PurchaseOrderInventory.DiscountPercent > 0
	|					THEN (PurchaseOrderInventory.Price * PurchaseOrderInventory.Quantity - PurchaseOrderInventory.DiscountAmount) / PurchaseOrderInventory.Quantity
	|				ELSE PurchaseOrderInventory.Price
	|			END
	|	END AS Price,
	|	PurchaseOrderInventory.Price AS PurePrice,
	|	PurchaseOrderInventory.Amount AS Amount,
	|	PurchaseOrderInventory.VATRate AS VATRate,
	|	PurchaseOrderInventory.VATAmount AS VATAmount,
	|	PurchaseOrderInventory.Total AS Total,
	|	PurchaseOrderInventory.Content AS Content,
	|	PurchaseOrderInventory.ReceiptDate AS ReceiptDate,
	|	PurchaseOrderInventory.DiscountPercent AS DiscountPercent,
	|	PurchaseOrderInventory.DiscountAmount AS DiscountAmount,
	|	VATRates.Rate AS NumberVATRate
	|INTO FilteredInventory
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|		LEFT JOIN Catalog.VATRates AS VATRates
	|		ON PurchaseOrderInventory.VATRate = VATRates.Ref
	|WHERE
	|	PurchaseOrderInventory.Ref IN(&ObjectsArray)
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
	|	ISNULL(SuppliersProducts.SKU, CatalogProducts.SKU) AS SKU,
	|	CASE
	|		WHEN SuppliersProducts.Description IS NULL
	|			THEN CASE
	|					WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|						THEN CAST(FilteredInventory.Content AS STRING(1024))
	|					WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|						THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|					ELSE CatalogProducts.Description
	|				END
	|		ELSE SuppliersProducts.Description
	|	END AS ProductDescription,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """" AS ContentUsed,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity) AS Quantity,
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN FilteredInventory.PurePrice
	|		ELSE FilteredInventory.Price
	|	END AS Price,
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST((FilteredInventory.Amount + FilteredInventory.DiscountAmount) / (1 + FilteredInventory.VATRate.Rate / 100) AS NUMBER(15, 2))
	|			ELSE CAST(FilteredInventory.Amount + FilteredInventory.DiscountAmount AS NUMBER(15, 2))
	|		END * CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN 1
	|			ELSE 0
	|		END) AS Freight,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	SUM(FilteredInventory.Total) AS Total,
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
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	Header.Warehouse AS Warehouse,
	|	FilteredInventory.ReceiptDate AS ReceiptDate,
	|	FilteredInventory.DiscountPercent AS DiscountPercent,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST(FilteredInventory.DiscountAmount / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|			ELSE FilteredInventory.DiscountAmount
	|		END) AS DiscountAmount,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST((FilteredInventory.PurePrice * FilteredInventory.Quantity - FilteredInventory.DiscountAmount) / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|			ELSE FilteredInventory.PurePrice * FilteredInventory.Quantity - FilteredInventory.DiscountAmount
	|		END) AS NetAmount
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (FilteredInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (FilteredInventory.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOMClassifier.Ref)
	|		LEFT JOIN Catalog.SuppliersProducts AS SuppliersProducts
	|		ON Header.Counterparty = SuppliersProducts.Owner
	|			AND (FilteredInventory.Products = SuppliersProducts.Products)
	|			AND (FilteredInventory.Characteristic = SuppliersProducts.Characteristic)
	|
	|GROUP BY
	|	FilteredInventory.VATRate,
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	Header.Counterparty,
	|	Header.Contract,
	|	Header.CounterpartyContactPerson,
	|	Header.AmountIncludesVAT,
	|	Header.Comment,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """",
	|	Header.CompanyLogoFile,
	|	Header.DocumentNumber,
	|	Header.DocumentCurrency,
	|	Header.Ref,
	|	Header.DocumentDate,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	Header.Warehouse,
	|	FilteredInventory.ReceiptDate,
	|	CASE
	|		WHEN SuppliersProducts.Description IS NULL
	|			THEN CASE
	|					WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|						THEN CAST(FilteredInventory.Content AS STRING(1024))
	|					WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|						THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|					ELSE CatalogProducts.Description
	|				END
	|		ELSE SuppliersProducts.Description
	|	END,
	|	ISNULL(SuppliersProducts.SKU, CatalogProducts.SKU),
	|	FilteredInventory.DiscountPercent,
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN FilteredInventory.PurePrice
	|		ELSE FilteredInventory.Price
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyVATNumber AS CompanyVATNumber,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Counterparty AS Counterparty,
	|	Tabular.Contract AS Contract,
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
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	Tabular.DiscountAmount AS DiscountAmount,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.UOM AS UOM,
	|	Tabular.Warehouse AS Warehouse,
	|	Tabular.ReceiptDate AS ReceiptDate,
	|	Tabular.Products AS Products,
	|	Tabular.Freight AS FreightTotal,
	|	Tabular.DiscountPercent AS DiscountPercent,
	|	Tabular.NetAmount AS NetAmount
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	DocumentNumber,
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
	|	MAX(AmountIncludesVAT),
	|	MAX(DocumentCurrency),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	SUM(DiscountAmount),
	|	MAX(Warehouse),
	|	SUM(FreightTotal),
	|	SUM(NetAmount)
	|BY
	|	Ref";
	
	Return QueryText;
	
EndFunction

// The procedure of document printing.
Function QueryText()
	
	QueryText = 
	"SELECT ALLOWED
	|	PurchaseOrder.Ref AS Ref,
	|	PurchaseOrder.Number AS Number,
	|	PurchaseOrder.Date AS Date,
	|	PurchaseOrder.Company AS Company,
	|	PurchaseOrder.CompanyVATNumber AS CompanyVATNumber,
	|	PurchaseOrder.Counterparty AS Counterparty,
	|	PurchaseOrder.Contract AS Contract,
	|	PurchaseOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	CAST(PurchaseOrder.Comment AS STRING(1024)) AS Comment,
	|	PurchaseOrder.Warehouse AS Warehouse
	|INTO PurchaseOrders
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	PurchaseOrder.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PurchaseOrder.Ref AS Ref,
	|	PurchaseOrder.Number AS DocumentNumber,
	|	PurchaseOrder.Date AS DocumentDate,
	|	PurchaseOrder.Company AS Company,
	|	PurchaseOrder.CompanyVATNumber AS CompanyVATNumber,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	PurchaseOrder.Counterparty AS Counterparty,
	|	PurchaseOrder.Contract AS Contract,
	|	CASE
	|		WHEN CounterpartyContracts.ContactPerson = VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN Counterparties.ContactPerson
	|		ELSE CounterpartyContracts.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	PurchaseOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	PurchaseOrder.Comment AS Comment,
	|	PurchaseOrder.Warehouse AS Warehouse
	|INTO Header
	|FROM
	|	PurchaseOrders AS PurchaseOrder
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON PurchaseOrder.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON PurchaseOrder.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON PurchaseOrder.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PurchaseOrderInventory.Ref AS Ref,
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	PurchaseOrderInventory.Products AS Products,
	|	PurchaseOrderInventory.Characteristic AS Characteristic,
	|	PurchaseOrderInventory.Quantity AS Quantity,
	|	PurchaseOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN PurchaseOrderInventory.Quantity = 0
	|			THEN 0
	|		ELSE CASE
	|				WHEN PurchaseOrderInventory.DiscountPercent > 0
	|					THEN (PurchaseOrderInventory.Price * PurchaseOrderInventory.Quantity - PurchaseOrderInventory.DiscountAmount) / PurchaseOrderInventory.Quantity
	|				ELSE PurchaseOrderInventory.Price
	|			END
	|	END AS Price,
	|	PurchaseOrderInventory.Price AS PurePrice,
	|	PurchaseOrderInventory.Amount AS Amount,
	|	PurchaseOrderInventory.VATRate AS VATRate,
	|	PurchaseOrderInventory.VATAmount AS VATAmount,
	|	PurchaseOrderInventory.Total AS Total,
	|	PurchaseOrderInventory.Content AS Content,
	|	PurchaseOrderInventory.ReceiptDate AS ReceiptDate,
	|	PurchaseOrderInventory.DiscountPercent AS DiscountPercent,
	|	PurchaseOrderInventory.DiscountAmount AS DiscountAmount,
	|	VATRates.Rate AS NumberVATRate
	|INTO FilteredInventory
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|		LEFT JOIN Catalog.VATRates AS VATRates
	|		ON PurchaseOrderInventory.VATRate = VATRates.Ref
	|WHERE
	|	PurchaseOrderInventory.Ref IN(&ObjectsArray)
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
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity * CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN 0
	|			ELSE 1
	|		END) AS Quantity,
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN FilteredInventory.PurePrice
	|		ELSE FilteredInventory.Price
	|	END AS Price,
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST((FilteredInventory.Amount + FilteredInventory.DiscountAmount) / (1 + FilteredInventory.VATRate.Rate / 100) AS NUMBER(15, 2))
	|			ELSE CAST(FilteredInventory.Amount + FilteredInventory.DiscountAmount AS NUMBER(15, 2))
	|		END * CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN 1
	|			ELSE 0
	|		END) AS Freight,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	SUM(FilteredInventory.Total) AS Total,
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
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	Header.Warehouse AS Warehouse,
	|	FilteredInventory.ReceiptDate AS ReceiptDate,
	|	FilteredInventory.DiscountPercent AS DiscountPercent,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST(FilteredInventory.DiscountAmount / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|			ELSE FilteredInventory.DiscountAmount
	|		END) AS DiscountAmount,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST((FilteredInventory.PurePrice * FilteredInventory.Quantity - FilteredInventory.DiscountAmount) / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|			ELSE FilteredInventory.PurePrice * FilteredInventory.Quantity - FilteredInventory.DiscountAmount
	|		END) AS NetAmount
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (FilteredInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (FilteredInventory.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOMClassifier.Ref)
	|
	|GROUP BY
	|	FilteredInventory.VATRate,
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	Header.Counterparty,
	|	Header.Contract,
	|	CatalogProducts.SKU,
	|	Header.CounterpartyContactPerson,
	|	Header.AmountIncludesVAT,
	|	Header.Comment,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """",
	|	Header.CompanyLogoFile,
	|	Header.DocumentNumber,
	|	Header.DocumentCurrency,
	|	Header.Ref,
	|	Header.DocumentDate,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	Header.Warehouse,
	|	FilteredInventory.ReceiptDate,
	|	FilteredInventory.DiscountPercent,
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN FilteredInventory.PurePrice
	|		ELSE FilteredInventory.Price
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyVATNumber AS CompanyVATNumber,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Counterparty AS Counterparty,
	|	Tabular.Contract AS Contract,
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
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	Tabular.DiscountAmount AS DiscountAmount,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.UOM AS UOM,
	|	Tabular.Warehouse AS Warehouse,
	|	Tabular.ReceiptDate AS ReceiptDate,
	|	Tabular.Products AS Products,
	|	Tabular.Freight AS FreightTotal,
	|	Tabular.DiscountPercent AS DiscountPercent,
	|	Tabular.NetAmount AS NetAmount
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	DocumentNumber,
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
	|	MAX(AmountIncludesVAT),
	|	MAX(DocumentCurrency),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	SUM(DiscountAmount),
	|	MAX(Warehouse),
	|	SUM(FreightTotal),
	|	SUM(NetAmount)
	|BY
	|	Ref";
	
	Return QueryText;
	
EndFunction

// The procedure of document printing.
Function QueryTextDropShipping()
	
	QueryText = 
	"SELECT ALLOWED
	|	PurchaseOrder.Ref AS Ref,
	|	PurchaseOrder.Number AS Number,
	|	PurchaseOrder.Date AS Date,
	|	PurchaseOrder.Company AS Company,
	|	PurchaseOrder.CompanyVATNumber AS CompanyVATNumber,
	|	PurchaseOrder.Counterparty AS Counterparty,
	|	PurchaseOrder.Contract AS Contract,
	|	PurchaseOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	CAST(PurchaseOrder.Comment AS STRING(1024)) AS Comment,
	|	PurchaseOrder.Warehouse AS Warehouse,
	|	PurchaseOrder.ContactPerson AS ContactPerson,
	|	PurchaseOrder.ShippingAddress AS ShippingAddress
	|INTO PurchaseOrders
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	PurchaseOrder.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PurchaseOrder.Ref AS Ref,
	|	PurchaseOrder.Number AS DocumentNumber,
	|	PurchaseOrder.Date AS DocumentDate,
	|	PurchaseOrder.Company AS Company,
	|	PurchaseOrder.CompanyVATNumber AS CompanyVATNumber,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	PurchaseOrder.Counterparty AS Counterparty,
	|	PurchaseOrder.Contract AS Contract,
	|	PurchaseOrder.ContactPerson AS ContactPerson,
	|	PurchaseOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	PurchaseOrder.Comment AS Comment,
	|	PurchaseOrder.Warehouse AS Warehouse,
	|	PurchaseOrder.ShippingAddress AS ShippingAddress
	|INTO Header
	|FROM
	|	PurchaseOrders AS PurchaseOrder
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON PurchaseOrder.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON PurchaseOrder.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON PurchaseOrder.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PurchaseOrderInventory.Ref AS Ref,
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	PurchaseOrderInventory.Products AS Products,
	|	PurchaseOrderInventory.Characteristic AS Characteristic,
	|	PurchaseOrderInventory.Quantity AS Quantity,
	|	PurchaseOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN PurchaseOrderInventory.Quantity = 0
	|			THEN 0
	|		ELSE PurchaseOrderInventory.Amount / PurchaseOrderInventory.Quantity
	|	END AS Price,
	|	PurchaseOrderInventory.Price AS PurePrice,
	|	PurchaseOrderInventory.Amount AS Amount,
	|	PurchaseOrderInventory.VATRate AS VATRate,
	|	PurchaseOrderInventory.VATAmount AS VATAmount,
	|	PurchaseOrderInventory.Total AS Total,
	|	PurchaseOrderInventory.Content AS Content,
	|	PurchaseOrderInventory.ReceiptDate AS ReceiptDate,
	|	PurchaseOrderInventory.DiscountPercent AS DiscountPercent,
	|	PurchaseOrderInventory.DiscountAmount AS DiscountAmount,
	|	VATRates.Rate AS NumberVATRate
	|INTO FilteredInventory
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|		LEFT JOIN Catalog.VATRates AS VATRates
	|		ON PurchaseOrderInventory.VATRate = VATRates.Ref
	|WHERE
	|	PurchaseOrderInventory.Ref IN(&ObjectsArray)
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
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.Comment AS Comment,
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
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity * CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN 0
	|			ELSE 1
	|		END) AS Quantity,
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN FilteredInventory.PurePrice
	|		ELSE FilteredInventory.Price
	|	END AS Price,
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST((FilteredInventory.Amount + FilteredInventory.DiscountAmount) / (1 + FilteredInventory.VATRate.Rate / 100) AS NUMBER(15, 2))
	|			ELSE CAST(FilteredInventory.Amount + FilteredInventory.DiscountAmount AS NUMBER(15, 2))
	|		END * CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN 1
	|			ELSE 0
	|		END) AS Freight,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	SUM(FilteredInventory.Total) AS Total,
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
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	Header.Warehouse AS Warehouse,
	|	FilteredInventory.ReceiptDate AS ReceiptDate,
	|	FilteredInventory.DiscountPercent AS DiscountPercent,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST(FilteredInventory.DiscountAmount / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|			ELSE FilteredInventory.DiscountAmount
	|		END) AS DiscountAmount,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST((FilteredInventory.PurePrice * FilteredInventory.Quantity - FilteredInventory.DiscountAmount) / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|			ELSE FilteredInventory.PurePrice * FilteredInventory.Quantity - FilteredInventory.DiscountAmount
	|		END) AS NetAmount,
	|	Header.ShippingAddress AS ShippingAddress,
	|	Header.ContactPerson AS ContactPerson
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (FilteredInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (FilteredInventory.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOMClassifier.Ref)
	|
	|GROUP BY
	|	FilteredInventory.VATRate,
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	Header.Counterparty,
	|	Header.Contract,
	|	CatalogProducts.SKU,
	|	Header.AmountIncludesVAT,
	|	Header.Comment,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """",
	|	Header.CompanyLogoFile,
	|	Header.DocumentNumber,
	|	Header.DocumentCurrency,
	|	Header.Ref,
	|	Header.DocumentDate,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	Header.Warehouse,
	|	FilteredInventory.ReceiptDate,
	|	FilteredInventory.DiscountPercent,
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN FilteredInventory.PurePrice
	|		ELSE FilteredInventory.Price
	|	END,
	|	Header.ShippingAddress,
	|	Header.ContactPerson
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyVATNumber AS CompanyVATNumber,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Counterparty AS Counterparty,
	|	Tabular.Contract AS Contract,
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
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	Tabular.DiscountAmount AS DiscountAmount,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.UOM AS UOM,
	|	Tabular.Warehouse AS Warehouse,
	|	Tabular.ReceiptDate AS ReceiptDate,
	|	Tabular.Products AS Products,
	|	Tabular.Freight AS FreightTotal,
	|	Tabular.DiscountPercent AS DiscountPercent,
	|	Tabular.NetAmount AS NetAmount,
	|	Tabular.ShippingAddress AS ShippingAddress,
	|	Tabular.ContactPerson AS ContactPerson
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyVATNumber),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(AmountIncludesVAT),
	|	MAX(DocumentCurrency),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	SUM(DiscountAmount),
	|	MAX(Warehouse),
	|	SUM(FreightTotal),
	|	SUM(NetAmount),
	|	MAX(ShippingAddress),
	|	MAX(ContactPerson)
	|BY
	|	Ref";
	
	Return QueryText;
	
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
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "PurchaseOrderTemplate") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"PurchaseOrderTemplate", 
			NStr("en = 'Purchase order'; ru = 'Заказ поставщику';pl = 'Zamówienie zakupu';es_ES = 'Orden de compra';es_CO = 'Orden de compra';tr = 'Satın alma siparişi';it = 'Ordine di acquisto';de = 'Bestellung an Lieferanten'"),
			PrintForm(ObjectsArray, PrintObjects, "PurchaseOrder", PrintParameters.Result, PrintParameters));
		
	ElsIf PrintManagement.TemplatePrintRequired(PrintFormsCollection, "PurchaseOrderInTermsOfSupplier") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"PurchaseOrderInTermsOfSupplier",
			NStr("en = 'Purchase order with supplier''s product names'; ru = 'Заказ поставщику с номенклатурой поставщика';pl = 'Zamówienie zakupu z nazwami produktów dostawcy';es_ES = 'Orden de compra con los nombres de producto del proveedor';es_CO = 'Orden de compra con los nombres de producto del proveedor';tr = 'Tedarikçinin ürün adlarını içeren Satın alma siparişi';it = 'Ordine di acquisto con nomi degli articoli del fornitore';de = 'Bestellung an Lieferanten mit Produktnamen des Lieferanten'"),
			PrintForm(ObjectsArray, PrintObjects, "PurchaseOrderInTermsOfSupplier", PrintParameters.Result));
		
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
	
	PrintCommand							= PrintCommands.Add();
	PrintCommand.ID							= "PurchaseOrderTemplate";
	PrintCommand.Presentation				= NStr("en = 'Purchase order'; ru = 'Заказ поставщику';pl = 'Zamówienie zakupu';es_ES = 'Orden de compra';es_CO = 'Orden de compra';tr = 'Satın alma siparişi';it = 'Ordine di acquisto';de = 'Bestellung an Lieferanten'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
	PrintCommand.AdditionalParameters.Insert("DropShipping",	False);
	AttachableCommands.AddCommandVisibilityCondition(PrintCommand, 
		"OperationKind",
		Enums.OperationTypesPurchaseOrder.OrderForDropShipping,
		DataCompositionComparisonType.NotEqual);
	
	PrintCommand							= PrintCommands.Add();
	PrintCommand.ID							= "PurchaseOrderInTermsOfSupplier";
	PrintCommand.Presentation				= NStr("en = 'Purchase order with supplier''s product names'; ru = 'Заказ поставщику с номенклатурой поставщика';pl = 'Zamówienie zakupu z nazwami produktów dostawcy';es_ES = 'Orden de compra con los nombres de producto del proveedor';es_CO = 'Orden de compra con los nombres de producto del proveedor';tr = 'Tedarikçinin ürün adlarını içeren Satın alma siparişi';it = 'Ordine di acquisto con nomi degli articoli del fornitore';de = 'Bestellung an Lieferanten mit Produktnamen des Lieferanten'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 2;
	PrintCommand.FunctionalOptions			= "UseProductCrossReferences";
	AttachableCommands.AddCommandVisibilityCondition(PrintCommand, 
		"OperationKind",
		Enums.OperationTypesPurchaseOrder.OrderForDropShipping,
		DataCompositionComparisonType.NotEqual);
		
	PrintCommand							= PrintCommands.Add();
	PrintCommand.ID							= "PurchaseOrderTemplate";
	PrintCommand.Presentation				= NStr("en = 'Purchase order: Drop shipping'; ru = 'Заказ поставщику: Дропшиппинг';pl = 'Zamówienie zakupu: Dropshipping';es_ES = 'Orden de compra: Envío directo';es_CO = 'Orden de compra: Envío directo';tr = 'Satın alma siparişi: Stoksuz satış';it = 'Ordine di acquisto: Dropshipping';de = 'Bestellung an Lieferanten: Streckengeschäft'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 3;
	
	PrintCommand.AdditionalParameters.Insert("DropShipping",	True);
	AttachableCommands.AddCommandVisibilityCondition(PrintCommand, 
		"OperationKind",
		Enums.OperationTypesPurchaseOrder.OrderForDropShipping,
		DataCompositionComparisonType.Equal);
		
EndProcedure

// Add one column PartAdditional to the area to match width of tabular section.
//
Procedure AddPartAdditionalToArea(Template, JoiningArea, StructureFlags, NameLine, NamePart = "PartAdditional")
	
	For Each ItemFlag In StructureFlags Do
		
		If ItemFlag.Value Then
			
			PartAdditional = Template.GetArea(NameLine + "|" + NamePart);
			JoiningArea.Join(PartAdditional);
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#Region ToDoList

// StandardSubsystems.ToDoList

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	
	If Not AccessRight("Edit", Metadata.Documents.PurchaseOrder) Then
		Return;
	EndIf;
	
	ResponsibleStructure = DriveServer.ResponsibleStructure();
	DocumentsCount = DocumentsCount(ResponsibleStructure.List);
	DocumentsID = "PurchaseOrder";
	
	// Purchase orders
	ToDo				= ToDoList.Add();
	ToDo.ID				= DocumentsID;
	ToDo.HasUserTasks	= (DocumentsCount.AllSupplierOrders > 0);
	ToDo.Presentation	= NStr("en = 'Purchase orders'; ru = 'Заказы поставщикам';pl = 'Zamówienia zakupu';es_ES = 'Órdenes de compra';es_CO = 'Órdenes de compra';tr = 'Satın alma siparişleri';it = 'Ordini di acquisto';de = 'Bestellungen an Lieferanten'");
	ToDo.Owner			= Metadata.Subsystems.Purchases;
	
	// Fulfillment is expired
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("PastPerformance");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "SupplierOrdersExecutionExpired";
	ToDo.HasUserTasks	= (DocumentsCount.SupplierOrdersExecutionExpired > 0);
	ToDo.Important		= True;
	ToDo.Presentation	= NStr("en = 'Fulfillment is expired'; ru = 'Срок исполнения заказа истек';pl = 'Wykonanie wygasło';es_ES = 'Se ha vencido el plazo de cumplimiento';es_CO = 'Se ha vencido el plazo de cumplimiento';tr = 'Yerine getirme süresi doldu';it = 'L''adempimento è in ritardo';de = 'Ausfüllung ist abgelaufen'");
	ToDo.Count			= DocumentsCount.SupplierOrdersExecutionExpired;
	ToDo.Form			= "Document.PurchaseOrder.ListForm";
	ToDo.FormParameters	= OpenParameters;
	ToDo.Owner			= DocumentsID;
	
	// Payment is overdue
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("OverduePayment");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "SupplierOrdersPaymentExpired";
	ToDo.HasUserTasks	= (DocumentsCount.SupplierOrdersPaymentExpired > 0);
	ToDo.Important		= True;
	ToDo.Presentation	= NStr("en = 'Payment is overdue'; ru = 'Оплата просрочена';pl = 'Płatność jest zaległa';es_ES = 'Pago vencido';es_CO = 'Pago vencido';tr = 'Ödemenin vadesi geçmiş';it = 'Pagamento in ritardo';de = 'Die Zahlung ist überfällig'");
	ToDo.Count			= DocumentsCount.SupplierOrdersPaymentExpired;
	ToDo.Form			= "Document.PurchaseOrder.ListForm";
	ToDo.FormParameters	= OpenParameters;
	ToDo.Owner			= DocumentsID;
	
	// For today
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("ForToday");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "SupplierOrdersForToday";
	ToDo.HasUserTasks	= (DocumentsCount.SupplierOrdersForToday > 0);
	ToDo.Presentation	= NStr("en = 'For today'; ru = 'На сегодня';pl = 'Na dzisiaj';es_ES = 'Para hoy';es_CO = 'Para hoy';tr = 'Bugün itibarıyla';it = 'Odierni';de = 'Für Heute'");
	ToDo.Count			= DocumentsCount.SupplierOrdersForToday;
	ToDo.Form			= "Document.PurchaseOrder.ListForm";
	ToDo.FormParameters	= OpenParameters;
	ToDo.Owner			= DocumentsID;
	
	// In progress
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("InProcess");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "SupplierOrdersInWork";
	ToDo.HasUserTasks	= (DocumentsCount.SupplierOrdersInWork > 0);
	ToDo.Presentation	= NStr("en = 'In progress'; ru = 'В работе';pl = 'W toku';es_ES = 'En progreso';es_CO = 'En progreso';tr = 'İşlemde';it = 'In lavorazione';de = 'In Bearbeitung'");
	ToDo.Count			= DocumentsCount.SupplierOrdersInWork;
	ToDo.Form			= "Document.PurchaseOrder.ListForm";
	ToDo.FormParameters	= OpenParameters;
	ToDo.Owner			= DocumentsID;
	
EndProcedure

// End StandardSubsystems.ToDoList

#EndRegion

#EndRegion

#Region InfobaseUpdate

// Filling a Sales order position in the tabular section
//
Procedure FillSalesOrderPosition() Export
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query = New Query;
	Query.Text = "SELECT
	|	PurchaseOrder.Ref AS Ref
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	PurchaseOrder.Posted
	|	AND PurchaseOrder.SalesOrderPosition = VALUE(Enum.AttributeStationing.EmptyRef)";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		Try
			PurchaseOrderObject = Selection.Ref.GetObject();
			PurchaseOrderObject.SalesOrderPosition = Enums.AttributeStationing.InTabularSection;
			
			InfobaseUpdate.WriteObject(PurchaseOrderObject);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'", DefaultLanguageCode),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Documents.PurchaseOrder,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion 

#EndRegion

#Region Private

#Region TableGeneration

// Cash flow projection table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRefPurchaseOrder, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", 					DocumentRefPurchaseOrder);
	Query.SetParameter("PointInTime", 			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", 				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",  StructureAdditionalProperties.ForPosting.PresentationCurrency);	
	Query.SetParameter("ExchangeRateMethod", 	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("AdvanceDates",			PaymentTermsServer.PaymentInAdvanceDates());
	
	Query.Text =
	"SELECT
	|	PurchaseOrder.Ref AS Ref,
	|	PurchaseOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	PurchaseOrder.ReceiptDate AS ReceiptDate,
	|	PurchaseOrder.PaymentMethod AS PaymentMethod,
	|	PurchaseOrder.Contract AS Contract,
	|	PurchaseOrder.PettyCash AS PettyCash,
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	PurchaseOrder.BankAccount AS BankAccount,
	|	PurchaseOrder.Closed AS Closed,
	|	PurchaseOrder.OrderState AS OrderState,
	|	PurchaseOrder.ExchangeRate AS ExchangeRate,
	|	PurchaseOrder.Multiplicity AS Multiplicity,
	|	PurchaseOrder.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	PurchaseOrder.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	PurchaseOrder.CashAssetType AS CashAssetType
	|INTO Document
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	PurchaseOrder.Ref = &Ref
	|	AND PurchaseOrder.SetPaymentTerms
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderPaymentCalendar.PaymentDate AS Period,
	|	Document.PaymentMethod AS PaymentMethod,
	|	Document.Ref AS Quote,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	Document.PettyCash AS PettyCash,
	|	Document.DocumentCurrency AS DocumentCurrency,
	|	Document.BankAccount AS BankAccount,
	|	Document.Ref AS Ref,
	|	Document.ExchangeRate AS ExchangeRate,
	|	Document.Multiplicity AS Multiplicity,
	|	Document.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	Document.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	CASE
	|		WHEN Document.AmountIncludesVAT
	|			THEN PurchaseOrderPaymentCalendar.PaymentAmount
	|		ELSE PurchaseOrderPaymentCalendar.PaymentAmount + PurchaseOrderPaymentCalendar.PaymentVATAmount
	|	END AS PaymentAmount,
	|	Document.CashAssetType AS CashAssetType
	|INTO PaymentCalendar
	|FROM
	|	Document AS Document
	|		INNER JOIN Catalog.PurchaseOrderStatuses AS PurchaseOrderStatuses
	|		ON Document.OrderState = PurchaseOrderStatuses.Ref
	|			AND (NOT PurchaseOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Open))
	|			AND (NOT(PurchaseOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND Document.Closed))
	|		INNER JOIN Document.PurchaseOrder.PaymentCalendar AS PurchaseOrderPaymentCalendar
	|		ON Document.Ref = PurchaseOrderPaymentCalendar.Ref
	|			AND (PurchaseOrderPaymentCalendar.PaymentBaselineDate IN (&AdvanceDates))
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON Document.Contract = CounterpartyContracts.Ref
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentCalendar.Period AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	PaymentCalendar.PaymentMethod AS PaymentMethod,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	PaymentCalendar.Ref AS Quote,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	CASE
	|		WHEN PaymentCalendar.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN PaymentCalendar.PettyCash
	|		WHEN PaymentCalendar.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN PaymentCalendar.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	PaymentCalendar.SettlementsCurrency AS Currency,
	|	CAST(-PaymentCalendar.PaymentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN PaymentCalendar.ExchangeRate * PaymentCalendar.ContractCurrencyMultiplicity / (PaymentCalendar.ContractCurrencyExchangeRate * PaymentCalendar.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (PaymentCalendar.ExchangeRate * PaymentCalendar.ContractCurrencyMultiplicity / (PaymentCalendar.ContractCurrencyExchangeRate * PaymentCalendar.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount
	|FROM
	|	PaymentCalendar AS PaymentCalendar";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

// Generating procedure for the table of invoices for payment.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTableInvoicesAndOrdersPayment(DocumentRefPurchaseOrder, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefPurchaseOrder);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);	
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref AS Quote,
	|	CAST(DocumentTable.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DocumentTable.ExchangeRate * DocumentTable.ContractCurrencyMultiplicity / (DocumentTable.ContractCurrencyExchangeRate * DocumentTable.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DocumentTable.ExchangeRate * DocumentTable.ContractCurrencyMultiplicity / (DocumentTable.ContractCurrencyExchangeRate * DocumentTable.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	DocumentTable.Counterparty AS Counterparty
	|INTO PurchaseOrderTable
	|FROM
	|	Document.PurchaseOrder AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND NOT DocumentTable.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|	AND NOT(DocumentTable.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND DocumentTable.Ref.Closed)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderTable.Period AS Period,
	|	PurchaseOrderTable.Company AS Company,
	|	PurchaseOrderTable.Quote AS Quote,
	|	PurchaseOrderTable.Amount AS Amount
	|FROM
	|	PurchaseOrderTable AS PurchaseOrderTable
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON PurchaseOrderTable.Counterparty = Counterparties.Ref
	|WHERE
	|	Counterparties.DoOperationsByOrders";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInvoicesAndOrdersPayment", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableReservedProducts(DocumentRefPurchaseOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	Table.LineNumber AS LineNumber,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.GLAccount AS GLAccount,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.Batch AS Batch,
	|	Table.SalesOrder AS SalesOrder,
	|	Table.Quantity AS Quantity
	|FROM
	|	TemporaryTableInventory AS Table
	|WHERE
	|	Table.SalesOrder <> UNDEFINED";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableBackorders(DocumentRefPurchaseOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	TableBackorders.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableBackorders.Period AS Period,
	|	TableBackorders.Company AS Company,
	|	TableBackorders.SalesOrder AS SalesOrder,
	|	TableBackorders.Products AS Products,
	|	TableBackorders.Characteristic AS Characteristic,
	|	TableBackorders.SupplySource AS SupplySource,
	|	SUM(TableBackorders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableBackorders AS TableBackorders
	|WHERE
	|	NOT TableBackorders.SalesOrderClosed
	|
	|GROUP BY
	|	TableBackorders.Company,
	|	TableBackorders.SalesOrder,
	|	TableBackorders.Products,
	|	TableBackorders.Characteristic,
	|	TableBackorders.SupplySource,
	|	TableBackorders.LineNumber,
	|	TableBackorders.Period";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders", QueryResult.Unload());
	
	Query.Text = 
	"SELECT
	|	TableBackorders.Company AS Company,
	|	TableBackorders.SalesOrder AS SalesOrder,
	|	TableBackorders.Products AS Products,
	|	TableBackorders.Characteristic AS Characteristic,
	|	TableBackorders.SupplySource AS SupplySource
	|FROM
	|	TemporaryTableBackorders AS TableBackorders
	|WHERE
	|	TableBackorders.SalesOrderClosed";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Backorders");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	Query.Text =
	"SELECT
	|	BackordersBalances.Company AS Company,
	|	BackordersBalances.Products AS Products,
	|	BackordersBalances.Characteristic AS Characteristic,
	|	BackordersBalances.SalesOrder AS SalesOrder,
	|	BackordersBalances.SupplySource AS SupplySource,
	|	SUM(BackordersBalances.QuantityBalance) AS Quantity
	|INTO TemporaryBackordersBalances
	|FROM
	|	(SELECT
	|		BackordersBalances.Company AS Company,
	|		BackordersBalances.Products AS Products,
	|		BackordersBalances.Characteristic AS Characteristic,
	|		BackordersBalances.SalesOrder AS SalesOrder,
	|		BackordersBalances.SupplySource AS SupplySource,
	|		BackordersBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Backorders.Balance(
	|				,
	|				(Company, SalesOrder, Products, Characteristic, SupplySource) IN
	|					(SELECT
	|						TableBackorders.Company AS Company,
	|						TableBackorders.SalesOrder AS SalesOrder,
	|						TableBackorders.Products AS Products,
	|						TableBackorders.Characteristic AS Characteristic,
	|						TableBackorders.SupplySource AS SupplySource
	|					FROM
	|						TemporaryTableBackorders AS TableBackorders
	|					WHERE
	|						TableBackorders.SalesOrderClosed)) AS BackordersBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsBackorders.Company,
	|		DocumentRegisterRecordsBackorders.Products,
	|		DocumentRegisterRecordsBackorders.Characteristic,
	|		DocumentRegisterRecordsBackorders.SalesOrder,
	|		DocumentRegisterRecordsBackorders.SupplySource,
	|		CASE
	|			WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -DocumentRegisterRecordsBackorders.Quantity
	|			ELSE DocumentRegisterRecordsBackorders.Quantity
	|		END
	|	FROM
	|		AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
	|	WHERE
	|		DocumentRegisterRecordsBackorders.Recorder = &Ref
	|		AND DocumentRegisterRecordsBackorders.Period <= &ControlPeriod) AS BackordersBalances
	|
	|GROUP BY
	|	BackordersBalances.Company,
	|	BackordersBalances.Products,
	|	BackordersBalances.Characteristic,
	|	BackordersBalances.SalesOrder,
	|	BackordersBalances.SupplySource
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableBackorders.Period AS Period,
	|	TableBackorders.Company AS Company,
	|	TableBackorders.SalesOrder AS SalesOrder,
	|	TableBackorders.Products AS Products,
	|	TableBackorders.Characteristic AS Characteristic,
	|	TableBackorders.SupplySource AS SupplySource
	|INTO TemporaryBackorders
	|FROM
	|	TemporaryTableBackorders AS TableBackorders
	|WHERE
	|	TableBackorders.SalesOrderClosed
	|
	|GROUP BY
	|	TableBackorders.Company,
	|	TableBackorders.SalesOrder,
	|	TableBackorders.Products,
	|	TableBackorders.Characteristic,
	|	TableBackorders.SupplySource,
	|	TableBackorders.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TemporaryBackorders.Period AS Period,
	|	TemporaryBackorders.Company AS Company,
	|	TemporaryBackorders.SalesOrder AS SalesOrder,
	|	TemporaryBackorders.Products AS Products,
	|	TemporaryBackorders.Characteristic AS Characteristic,
	|	TemporaryBackorders.SupplySource AS SupplySource,
	|	-BackordersBalances.Quantity AS Quantity
	|FROM
	|	TemporaryBackorders AS TemporaryBackorders
	|		LEFT JOIN TemporaryBackordersBalances AS BackordersBalances
	|		ON TemporaryBackorders.Company = BackordersBalances.Company
	|			AND TemporaryBackorders.Products = BackordersBalances.Products
	|			AND TemporaryBackorders.Characteristic = BackordersBalances.Characteristic
	|			AND TemporaryBackorders.SupplySource = BackordersBalances.SupplySource
	|			AND TemporaryBackorders.SalesOrder = BackordersBalances.SalesOrder
	|WHERE
	|	BackordersBalances.SalesOrder IS NOT NULL 
	|	AND ISNULL(BackordersBalances.Quantity, 0) <> 0";
	
	Query.SetParameter("Ref", DocumentRefPurchaseOrder);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		While Selection.Next() Do
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure GenerateTableOrdersByFulfillmentMethod(DocumentRefPurchaseOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	TableOrdersByFulfillmentMethod.Period AS Period,
	|	TableOrdersByFulfillmentMethod.Company AS Company,
	|	TableOrdersByFulfillmentMethod.PurchaseOrder AS PurchaseOrder,
	|	TableOrdersByFulfillmentMethod.SalesOrder AS SalesOrder,
	|	TableOrdersByFulfillmentMethod.Supplier AS Supplier,
	|	TableOrdersByFulfillmentMethod.Customer AS Customer,
	|	TableOrdersByFulfillmentMethod.ShippingAddress AS ShippingAddress,
	|	TableOrdersByFulfillmentMethod.Products AS Products,
	|	TableOrdersByFulfillmentMethod.Characteristic AS Characteristic,
	|	TableOrdersByFulfillmentMethod.FulfillmentMethod AS FulfillmentMethod,
	|	SUM(TableOrdersByFulfillmentMethod.Quantity) AS Quantity
	|FROM
	|	TemporaryTableOrdersByFulfillmentMethod AS TableOrdersByFulfillmentMethod
	|
	|GROUP BY
	|	TableOrdersByFulfillmentMethod.Company,
	|	TableOrdersByFulfillmentMethod.SalesOrder,
	|	TableOrdersByFulfillmentMethod.Products,
	|	TableOrdersByFulfillmentMethod.Characteristic,
	|	TableOrdersByFulfillmentMethod.PurchaseOrder,
	|	TableOrdersByFulfillmentMethod.Period,
	|	TableOrdersByFulfillmentMethod.FulfillmentMethod,
	|	TableOrdersByFulfillmentMethod.Customer,
	|	TableOrdersByFulfillmentMethod.Supplier,
	|	TableOrdersByFulfillmentMethod.ShippingAddress";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableOrdersByFulfillmentMethod", QueryResult.Unload());
	
	
EndProcedure

#EndRegion 

#Region ToDoList

Function DocumentsCount(EmployeesList)
	
	Result = New Structure;
	Result.Insert("SupplierOrdersExecutionExpired",	0);
	Result.Insert("SupplierOrdersPaymentExpired",	0);
	Result.Insert("SupplierOrdersForToday",			0);
	Result.Insert("SupplierOrdersInWork",			0);
	Result.Insert("AllSupplierOrders",				0);

	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	COUNT(DISTINCT CASE
	|			WHEN PurchaseOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND NOT RunSchedule.Order IS NULL
	|					AND RunSchedule.Period < &StartOfDayIfCurrentDateTimeSession
	|				THEN DocPurchaseOrder.Ref
	|		END) AS SupplierOrdersExecutionExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN DocPurchaseOrder.SetPaymentTerms
	|					AND PurchaseOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND NOT PaymentSchedule.Quote IS NULL
	|					AND PaymentSchedule.Period < &StartOfDayIfCurrentDateTimeSession
	|				THEN DocPurchaseOrder.Ref
	|		END) AS SupplierOrdersPaymentExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN PurchaseOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND NOT RunSchedule.Order IS NULL
	|					AND RunSchedule.Period = &StartOfDayIfCurrentDateTimeSession
	|				THEN DocPurchaseOrder.Ref
	|			WHEN DocPurchaseOrder.SetPaymentTerms
	|					AND PurchaseOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND NOT PaymentSchedule.Quote IS NULL
	|					AND PaymentSchedule.Period = &StartOfDayIfCurrentDateTimeSession
	|				THEN DocPurchaseOrder.Ref
	|		END) AS SupplierOrdersForToday,
	|	COUNT(DISTINCT CASE
	|			WHEN PurchaseOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				THEN DocPurchaseOrder.Ref
	|		END) AS SupplierOrdersInWork,
	|	COUNT(DISTINCT DocPurchaseOrder.Ref) AS AllSupplierOrders
	|FROM
	|	Document.PurchaseOrder AS DocPurchaseOrder
	|		LEFT JOIN InformationRegister.OrderFulfillmentSchedule AS RunSchedule
	|		ON DocPurchaseOrder.Ref = RunSchedule.Order
	|			AND (RunSchedule.Period <= &StartOfDayIfCurrentDateTimeSession)
	|		{LEFT JOIN InformationRegister.OrdersPaymentSchedule AS PaymentSchedule
	|		ON DocPurchaseOrder.Ref = PaymentSchedule.Quote
	|			AND (PaymentSchedule.Period <= &StartOfDayIfCurrentDateTimeSession)}
	|		INNER JOIN Catalog.PurchaseOrderStatuses AS PurchaseOrderStatuses
	|		ON DocPurchaseOrder.OrderState = PurchaseOrderStatuses.Ref
	|WHERE
	|	DocPurchaseOrder.Posted
	|	AND NOT DocPurchaseOrder.Closed
	|	AND DocPurchaseOrder.Responsible IN(&EmployeesList)";
	
	Query.SetParameter("EmployeesList",							EmployeesList);
	Query.SetParameter("StartOfDayIfCurrentDateTimeSession",	BegOfDay(CurrentSessionDate()));
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		FillPropertyValues(Result, SelectionDetailRecords);
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndRegion

#EndIf
