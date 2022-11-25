#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnCopy(CopiedObject)
	
	OrderState		= GetPurchaseOrderstate();
	Closed			= False;
	Event			= Documents.Event.EmptyRef();
	ApprovalStatus	= Enums.ApprovalStatuses.EmptyRef();
	ApprovalDate	= Date(1,1,1);
	Approver		= Catalogs.Users.EmptyRef();
	
	IncomingDocumentNumber	= "";
	IncomingDocumentDate	= "";
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	FillingStrategy = New Map;
	FillingStrategy[Type("DocumentRef.SalesOrder")]			= "FillBySalesOrder";
	// begin Drive.FullVersion
	FillingStrategy[Type("DocumentRef.ProductionOrder")]			= "FillByProductionOrder";
	FillingStrategy[Type("DocumentRef.ManufacturingOperation")]		= "FillByWIP";
	FillingStrategy[Type("DocumentRef.SubcontractorOrderIssued")]	= "FillBySubcontractorOrderIssued";
	// end Drive.FullVersion
	FillingStrategy[Type("DocumentRef.KitOrder")]			= "FillByKitOrder";
	FillingStrategy[Type("DocumentRef.SupplierQuote")]		= "FillByRFQResponse";
	FillingStrategy[Type("DocumentRef.WorkOrder")]			= "FillByWorkOrder";
	FillingStrategy[Type("DocumentRef.RequisitionOrder")]	= "FillByRequisitionOrder";
	FillingStrategy[Type("Structure")]						= "FillByStructure";
	
	ExcludingProperties = "OrderState";
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy, ExcludingProperties);
	
	FillByDefault();
	
	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then
		
		PaymentTermsServer.FillPaymentCalendarFromContract(ThisObject);
		
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Closed And OrderState = DriveReUse.GetOrderStatus("PurchaseOrderStatuses", "Completed") Then 
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'You cannot make changes to a completed %1.'; ru = 'Нельзя вносить изменения в завершенный %1.';pl = 'Nie możesz wprowadzać zmian w zakończeniu %1.';es_ES = 'No se puede modificar %1 cerrada.';es_CO = 'No se puede modificar %1 cerrada.';tr = 'Tamamlanmış bir %1 üzerinde değişiklik yapılamaz.';it = 'Non potete fare modifiche a un %1 completato.';de = 'Sie können keine Änderungen an einem abgeschlossenen %1 vornehmen.'"), Ref);
		CommonClientServer.MessageToUser(MessageText,,,,Cancel);
		Return;
	EndIf;
	
	If ReceiptDatePosition = Enums.AttributeStationing.InHeader Then
		For Each TabularSectionRow In Inventory Do
			If TabularSectionRow.ReceiptDate <> ReceiptDate Then
				TabularSectionRow.ReceiptDate = ReceiptDate;
			EndIf;
		EndDo;
	EndIf;
	
	If ReceiptDatePosition = Enums.AttributeStationing.InTabularSection Then
		If Inventory.Count() > 0 Then
			ReceiptDate = Inventory[0].ReceiptDate;
		EndIf;
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		
		For Each TabularSectionRow In Inventory Do
			TabularSectionRow.SalesOrder = SalesOrder;
		EndDo;
	Else
		SalesOrder = Undefined;
	EndIf;

	If ValueIsFilled(Counterparty)
		AND Not Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(Contract) Then
			Contract = Counterparty.ContractByDefault;
	EndIf;
	
	Totals = DriveServer.CalculateSubtotalPurchases(Inventory.Unload(), AmountIncludesVAT);
	FillPropertyValues(ThisObject, Totals);
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.PurchaseOrder.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Limit Exceed Control
	DriveServer.CheckLimitsExceed(ThisObject, False, Cancel);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectInventoryFlowCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPurchaseOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectBackorders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectReservedProducts(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUsingPaymentTermsInDocuments(Ref, Cancel);
	DriveServer.ReflectOrdersByFulfillmentMethod(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);

	// Control
	Documents.PurchaseOrder.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	InformationRegisters.PurchaseOrdersStatuses.ReflectOrderStates(Ref);
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	Closed = False;
	
	// Initialization of additional properties to undo document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.PurchaseOrder.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	If Materials.Total("Reserve") > 0 Then
		
		For Each StringMaterials In Materials Do
		
			If StringMaterials.Reserve > 0 AND Not ValueIsFilled(StructuralUnitReserve) Then
				
				MessageText = NStr("en = 'The reserve warehouse is required.'; ru = 'Не заполнен склад резерва.';pl = 'Należy wypełnić pole magazyn rezerwy.';es_ES = 'Se requiere un almacén de reserva.';es_CO = 'Se requiere un almacén de reserva.';tr = 'Yedek ambar gerekiyor.';it = 'È richiesto il deposito di riserva.';de = 'Das Reservelager ist erforderlich.'");
				DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "StructuralUnitReserve", Cancel);
				
			EndIf;
		
		EndDo;
	
	EndIf;
	
	If Constants.UseInventoryReservation.Get()
		AND OperationKind = Enums.OperationTypesPurchaseOrder.OrderForProcessing Then
		
		For Each StringMaterials In Materials Do
			
			If StringMaterials.Reserve > StringMaterials.Quantity Then
				
				MessageText = NStr("en = 'In row #%Number% of the ""Materials for processing"" tabular section quantity of the write-off items from reserve exceeds the total material quantity.'; ru = 'В строке №%Number% табл. части ""Материалы в переработку"" количество позиций к списанию из резерва превышает общее количество материалов.';pl = 'W wierszu nr %Number% sekcji tabelarycznej ""Materiały do przetwarzania"" liczba elementów spisanych z zapasów przekracza łączną ilość materiałów.';es_ES = 'En la fila #%Number% de la sección tabular ""Materiales para procesamiento"" la cantidad de los artículos de amortización de la reserva excede la cantidad total de materiales.';es_CO = 'En la fila #%Number% de la sección tabular ""Materiales para procesamiento"" la cantidad de los artículos de amortización de la reserva excede la cantidad total de materiales.';tr = '""İşlenecek malzemeler"" tablo bölümünün no.%Number% satırında rezervden silme öğesi miktarı toplam malzeme miktarını geçer.';it = 'Nella riga №. %Number% del quantitativo sezione ""Materiali per l''elaborazione"" tabulare degli elementi cancellati (write-off) dalla riserva supera la quantità totale del materiale.';de = 'In der Zeile Nr %Number% des Tabellenabschnitts ""Materialien zur Bearbeitung"" übersteigt die Menge der Abschreibungspositionen aus der Reserve die Gesamtmaterialmenge.'");
				MessageText = StrReplace(MessageText, "%Number%", StringMaterials.LineNumber);
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Materials",
					StringMaterials.LineNumber,
					"Reserve",
					Cancel
				);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If Not Constants.UsePurchaseOrderStatuses.Get() Then
		
		If Not ValueIsFilled(OrderState) Then
			MessageText = NStr("en = '""Lifecycle status"" is required.'; ru = 'Требуется указать статус документа.';pl = 'Wymagany jest ""Status dokumentu"".';es_ES = 'Se requiere ""Estado de ciclo de vida"".';es_CO = 'Se requiere ""Estado de ciclo de vida"".';tr = '""Yaşam döngüsü durumu"" gerekli.';it = '""Stato del ciclo di vita"" richiesto.';de = '„Status von Lebenszyklus“ ist erforderlich.'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "OrderState", Cancel);
		EndIf;
		
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	If ReceiptDatePosition = Enums.AttributeStationing.InTabularSection Then
		CheckedAttributes.Delete(CheckedAttributes.Find("ReceiptDate"));
	Else
		CheckedAttributes.Delete(CheckedAttributes.Find("Inventory.ReceiptDate"));
	EndIf;
	
	//Cash flow projection
	Amount = Inventory.Total("Amount");
	VATAmount = Inventory.Total("VATAmount");
	
	PaymentTermsServer.CheckRequiredAttributes(ThisObject, CheckedAttributes, Cancel);
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);
	
	// Drop shipping
	If OperationKind = Enums.OperationTypesPurchaseOrder.OrderForDropShipping Then
		
		MessageText = NStr("en = 'Cannot drop-ship services. If you want to purchase a service,
							|add the service to a Purchase order with the ""Purchase order"" operation.'; 
							|ru = 'Нельзя использовать дропшиппинг для приобретения услуг. Чтобы приобрести услугу,
							|добавьте ее в заказ поставщику с операцией ""Заказ поставщику"".';
							|pl = 'Usługi dropshipping są niedostępne. Jeśli chcesz kupić usługę,
							|dodaj usługę do Zamówienia zakupu z operacją ""Zamówienie zakupu"".';
							|es_ES = 'No se pueden realizar servicios con envío directo. Si quiere comprar un servicio, 
							|añada el servicio a una orden de compra con la operación ""Orden de compra"".';
							|es_CO = 'No se pueden realizar servicios con envío directo. Si quiere comprar un servicio, 
							|añada el servicio a una orden de compra con la operación ""Orden de compra"".';
							|tr = 'Stoksuz satış hizmetlere uygulanamaz. Hizmet satın alırsanız
							|hizmeti ""Satın alma siparişi"" işlemli bir Satın alma siparişine ekleyin.';
							|it = 'Impossibile effettuare dropshipping dei servizi. Per acquistare un servizio,
							|aggiungere il servizio a un Ordine di acquisto con l''operazione ""Ordine di acquisto"".';
							|de = 'Fehler bei Streckengeschäft-Dienstleistungen. Wenn Sie eine Dienstleistung bestellen möchten,
							|fügen Sie die Dienstleistung zu einer Bestellung an Lieferanten mit der Operation ""Bestellung an Lieferanten"" hinzu.'");
		
		For Each ItemInventory In Inventory Do
			
			ProductsType = Common.ObjectAttributeValue(ItemInventory.Products, "ProductsType");
			
			If ProductsType = Enums.ProductsTypes.Service Then
				
				DriveServer.ShowMessageAboutError(ThisObject,
					MessageText,
					"Inventory",
					ItemInventory.LineNumber,
					"Products",
					Cancel);
				
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region DocumentFillingProcedures

Procedure FillBySalesOrder(FillingData) Export
	
	OrdersArray = New Array;
	IsDropShipping = False;
	
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfSalesOrders") Then
		OrdersArray = FillingData.ArrayOfSalesOrders;
	Else
		OrdersArray.Add(FillingData.Ref);
	EndIf;
	
	If TypeOf(FillingData) = Type("Structure")
		And FillingData.Property("DropShipping")
		And FillingData.DropShipping Then
		
		IsDropShipping = True;
		
	EndIf;
		
	#Region QuerySalesOrder
		
	If IsDropShipping Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED
		|	SalesOrder.Ref AS Ref,
		|	SalesOrder.Company AS Company,
		|	SalesOrder.CompanyVATNumber AS CompanyVATNumber,
		|	SalesOrder.OperationKind AS OperationKind,
		|	SalesOrder.Start AS Start,
		|	SalesOrder.ShipmentDate AS ShipmentDate,
		|	SalesOrder.OrderState AS OrderState,
		|	SalesOrder.Posted AS Posted,
		|	SalesOrder.Number AS Number,
		|	SalesOrder.ContactPerson AS ContactPerson,
		|	SalesOrder.DeliveryTimeFrom AS DeliveryTimeFrom,
		|	SalesOrder.DeliveryTimeTo AS DeliveryTimeTo,
		|	SalesOrder.Incoterms AS Incoterms,
		|	SalesOrder.ShippingAddress AS ShippingAddress
		|INTO SalesOrderTable
		|FROM
		|	Document.SalesOrder AS SalesOrder
		|WHERE
		|	SalesOrder.Ref IN(&OrdersArray)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SalesOrder.Ref AS Ref,
		|	SalesOrder.Company AS Company,
		|	SalesOrder.CompanyVATNumber AS CompanyVATNumber,
		|	SalesOrder.OperationKind AS OperationKind,
		|	SalesOrder.Start AS Start,
		|	SalesOrder.ShipmentDate AS ShipmentDate,
		|	SalesOrder.OrderState AS OrderState,
		|	SalesOrder.Posted AS Posted,
		|	SalesOrder.Number AS Number,
		|	SalesOrder.ContactPerson AS ContactPerson,
		|	SalesOrder.DeliveryTimeFrom AS DeliveryTimeFrom,
		|	SalesOrder.DeliveryTimeTo AS DeliveryTimeTo,
		|	SalesOrder.Incoterms AS Incoterms,
		|	SalesOrder.ShippingAddress AS ShippingAddress
		|FROM
		|	SalesOrderTable AS SalesOrder
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	OrdersBalance.SalesOrder AS SalesOrder,
		|	OrdersBalance.Products AS Products,
		|	OrdersBalance.Characteristic AS Characteristic,
		|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
		|FROM
		|	(SELECT
		|		OrdersBalance.Products AS Products,
		|		OrdersBalance.Characteristic AS Characteristic,
		|		OrdersBalance.DropShippingQuantityBalance AS QuantityBalance,
		|		OrdersBalance.SalesOrder AS SalesOrder
		|	FROM
		|		AccumulationRegister.SalesOrders.Balance(
		|				,
		|				SalesOrder IN
		|						(SELECT
		|							SalesOrderTable.Ref
		|						FROM
		|							SalesOrderTable AS SalesOrderTable)
		|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS OrdersBalance) AS OrdersBalance
		|
		|GROUP BY
		|	OrdersBalance.Products,
		|	OrdersBalance.Characteristic,
		|	OrdersBalance.SalesOrder
		|
		|HAVING
		|	SUM(OrdersBalance.QuantityBalance) > 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SalesOrderInventory.LineNumber AS LineNumber,
		|	SalesOrderInventory.Products AS Products,
		|	SalesOrderInventory.Characteristic AS Characteristic,
		|	SalesOrderInventory.Batch AS Batch,
		|	CASE
		|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
		|			THEN 1
		|		ELSE ISNULL(UOM.Factor, 1)
		|	END AS Factor,
		|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
		|	SalesOrderInventory.ShipmentDate AS InventoryIncreaseDate,
		|	SalesOrderInventory.VATRate AS VATRate,
		|	SalesOrderInventory.Quantity AS Quantity,
		|	SalesOrderInventory.Project AS Project,
		|	SalesOrderInventory.Ref AS SalesOrder
		|FROM
		|	SalesOrderTable AS SalesOrderTable
		|		INNER JOIN Document.SalesOrder.Inventory AS SalesOrderInventory
		|		ON SalesOrderTable.Ref = SalesOrderInventory.Ref
		|		LEFT JOIN Catalog.Products AS CatalogProducts
		|		ON (SalesOrderInventory.Products = CatalogProducts.Ref)
		|		LEFT JOIN Catalog.UOM AS UOM
		|		ON (SalesOrderInventory.MeasurementUnit = UOM.Ref)
		|WHERE
		|	CatalogProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
		|	AND CatalogProducts.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Purchase)
		|	AND SalesOrderInventory.Specification = VALUE(Catalog.BillsOfMaterials.EmptyRef)
		|	AND SalesOrderInventory.DropShipping
		|
		|ORDER BY
		|	LineNumber";
		
	Else 
		
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED
		|	SalesOrder.Ref AS Ref,
		|	SalesOrder.Company AS Company,
		|	SalesOrder.CompanyVATNumber AS CompanyVATNumber,
		|	SalesOrder.OperationKind AS OperationKind,
		|	SalesOrder.Start AS Start,
		|	SalesOrder.ShipmentDate AS ShipmentDate,
		|	SalesOrder.OrderState AS OrderState,
		|	SalesOrder.Posted AS Posted,
		|	SalesOrder.Number AS Number
		|INTO SalesOrderTable
		|FROM
		|	Document.SalesOrder AS SalesOrder
		|WHERE
		|	SalesOrder.Ref IN(&OrdersArray)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SalesOrder.Ref AS Ref,
		|	SalesOrder.Company AS Company,
		|	SalesOrder.CompanyVATNumber AS CompanyVATNumber,
		|	SalesOrder.OperationKind AS OperationKind,
		|	SalesOrder.Start AS Start,
		|	SalesOrder.ShipmentDate AS ShipmentDate,
		|	SalesOrder.OrderState AS OrderState,
		|	SalesOrder.Posted AS Posted,
		|	SalesOrder.Number AS Number
		|FROM
		|	SalesOrderTable AS SalesOrder
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	OrdersBalance.SalesOrder AS SalesOrder,
		|	OrdersBalance.Products AS Products,
		|	OrdersBalance.Characteristic AS Characteristic,
		|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
		|FROM
		|	(SELECT
		|		OrdersBalance.Products AS Products,
		|		OrdersBalance.Characteristic AS Characteristic,
		|		OrdersBalance.QuantityBalance - OrdersBalance.DropShippingQuantityBalance AS QuantityBalance,
		|		OrdersBalance.SalesOrder AS SalesOrder
		|	FROM
		|		AccumulationRegister.SalesOrders.Balance(
		|				,
		|				SalesOrder IN
		|						(SELECT
		|							SalesOrderTable.Ref
		|						FROM
		|							SalesOrderTable AS SalesOrderTable)
		|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS OrdersBalance
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		ReservedProductsBalances.Products,
		|		ReservedProductsBalances.Characteristic,
		|		-ReservedProductsBalances.QuantityBalance,
		|		ReservedProductsBalances.SalesOrder
		|	FROM
		|		AccumulationRegister.ReservedProducts.Balance(
		|				,
		|				SalesOrder IN
		|						(SELECT
		|							SalesOrderTable.Ref
		|						FROM
		|							SalesOrderTable AS SalesOrderTable)
		|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS ReservedProductsBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		PlacementBalances.Products,
		|		PlacementBalances.Characteristic,
		|		-PlacementBalances.QuantityBalance,
		|		PlacementBalances.SalesOrder
		|	FROM
		|		AccumulationRegister.Backorders.Balance(
		|				,
		|				SalesOrder IN
		|						(SELECT
		|							SalesOrderTable.Ref
		|						FROM
		|							SalesOrderTable AS SalesOrderTable)
		|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS PlacementBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecordsBackorders.Products,
		|		DocumentRegisterRecordsBackorders.Characteristic,
		|		CASE
		|			WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Expense)
		|				THEN -DocumentRegisterRecordsBackorders.Quantity
		|			ELSE DocumentRegisterRecordsBackorders.Quantity
		|		END,
		|		DocumentRegisterRecordsBackorders.SalesOrder
		|	FROM
		|		AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
		|			INNER JOIN SalesOrderTable AS SalesOrderTable
		|			ON DocumentRegisterRecordsBackorders.SalesOrder = SalesOrderTable.Ref
		|	WHERE
		|		DocumentRegisterRecordsBackorders.Recorder = &Ref
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		GoodsInvoicedNotShippedBalance.Products,
		|		GoodsInvoicedNotShippedBalance.Characteristic,
		|		GoodsInvoicedNotShippedBalance.QuantityBalance,
		|		GoodsInvoicedNotShippedBalance.SalesOrder
		|	FROM
		|		AccumulationRegister.GoodsInvoicedNotShipped.Balance(
		|				,
		|				SalesOrder IN
		|						(SELECT
		|							SalesOrderTable.Ref
		|						FROM
		|							SalesOrderTable AS SalesOrderTable)
		|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS GoodsInvoicedNotShippedBalance) AS OrdersBalance
		|
		|GROUP BY
		|	OrdersBalance.Products,
		|	OrdersBalance.Characteristic,
		|	OrdersBalance.SalesOrder
		|
		|HAVING
		|	SUM(OrdersBalance.QuantityBalance) > 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	MIN(SalesOrderInventory.LineNumber) AS LineNumber,
		|	SalesOrderInventory.Products AS Products,
		|	SalesOrderInventory.Characteristic AS Characteristic,
		|	SalesOrderInventory.Batch AS Batch,
		|	CASE
		|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
		|			THEN 1
		|		ELSE ISNULL(UOM.Factor, 1)
		|	END AS Factor,
		|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
		|	SalesOrderInventory.ShipmentDate AS InventoryIncreaseDate,
		|	SalesOrderInventory.VATRate AS VATRate,
		|	SUM(SalesOrderInventory.Quantity) AS Quantity,
		|	SalesOrderInventory.Project AS Project,
		|	SalesOrderInventory.Ref AS SalesOrder
		|FROM
		|	SalesOrderTable AS SalesOrderTable
		|		INNER JOIN Document.SalesOrder.Inventory AS SalesOrderInventory
		|		ON SalesOrderTable.Ref = SalesOrderInventory.Ref
		|		LEFT JOIN Catalog.Products AS CatalogProducts
		|		ON (SalesOrderInventory.Products = CatalogProducts.Ref)
		|		LEFT JOIN Catalog.UOM AS UOM
		|		ON (SalesOrderInventory.MeasurementUnit = UOM.Ref)
		|WHERE
		|	CatalogProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
		|	AND CatalogProducts.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Purchase)
		|	AND SalesOrderInventory.Specification = VALUE(Catalog.BillsOfMaterials.EmptyRef)
		|	AND NOT SalesOrderInventory.DropShipping
		|
		|GROUP BY
		|	SalesOrderInventory.Products,
		|	SalesOrderInventory.Characteristic,
		|	SalesOrderInventory.Batch,
		|	SalesOrderInventory.MeasurementUnit,
		|	SalesOrderInventory.VATRate,
		|	CASE
		|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
		|			THEN 1
		|		ELSE ISNULL(UOM.Factor, 1)
		|	END,
		|	SalesOrderInventory.ShipmentDate,
		|	SalesOrderInventory.Ref,
		|	SalesOrderInventory.Project
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED TOP 1
		|	SalesOrderInventory.DropShipping AS DropShipping
		|FROM
		|	Constant.UseDropShipping AS UseDropShipping,
		|	Document.SalesOrder.Inventory AS SalesOrderInventory
		|WHERE
		|	UseDropShipping.Value
		|	AND SalesOrderInventory.Ref IN(&OrdersArray)
		|	AND SalesOrderInventory.DropShipping";
		
	EndIf;
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	
	#EndRegion 
	
	OrdersTable = ResultsArray[1].Unload();
	
	If OrdersTable.Count() > 0 Then
		
		For Each RowOrder In OrdersTable Do
			
			AttributeValues = New Structure("Company, Ref, OperationKind, Start, ShipmentDate, OrderState, Posted");
			FillPropertyValues(AttributeValues, RowOrder);
			
			Documents.SalesOrder.CheckAbilityOfEnteringBySalesOrder(RowOrder.Ref, AttributeValues);
			
		EndDo;
		
		Company			= RowOrder.Company;
		CompanyVATNumber= RowOrder.CompanyVATNumber;
		ReceiptDate		= RowOrder.ShipmentDate;
		
		If IsDropShipping Then
			FillPropertyValues(ThisObject, RowOrder, "ContactPerson, DeliveryTimeFrom, DeliveryTimeTo, Incoterms, ShippingAddress");
			OperationKind = Enums.OperationTypesPurchaseOrder.OrderForDropShipping;
		EndIf;
		
	EndIf;
	
	BalanceTable = ResultsArray[2].Unload();
	BalanceTable.Indexes.Add("Products,Characteristic");
	
	Inventory.Clear();
	
	Selection = ResultsArray[3].Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("SalesOrder", Selection.SalesOrder);
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		
		BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
		If BalanceRowsArray.Count() = 0 Then
			Continue;
		EndIf;
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, Selection);
		
		QuantityToWriteOff = Selection.Quantity * Selection.Factor;
		BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
		If BalanceRowsArray[0].QuantityBalance < 0 Then
			
			NewRow.Quantity = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / Selection.Factor;
			
		EndIf;
		
		NewRow.ReceiptDate = Selection.InventoryIncreaseDate;
		If ReceiptDate <> NewRow.ReceiptDate Then
			ReceiptDatePositionAtHeader = False;
		EndIf;
		
		If BalanceRowsArray[0].QuantityBalance <= 0 Then
			BalanceTable.Delete(BalanceRowsArray[0]);
		EndIf;
		
	EndDo;
	
	If Inventory.Count() = 0 Then
		
		If IsDropShipping Then
			
			ErrorText = NStr(
				"en = 'Cannot generate ""Purchase order: Drop shipping"" from this Sales order. 
				|You can generate such Purchase orders only 
				|from Sales orders with products that meet all of the following conditions:
				|
				|● The Drop shipping checkbox is selected.
				|● Replenishment method is Purchase.
				|● The Default bill of materials is not specified.'; 
				|ru = 'Не удалось создать ""Заказ поставщику: Дропшиппинг"" на основании данного заказа покупателя. 
				|Вы можете создавать такие заказы поставщику только 
				|на основании заказов покупателей, включающих номенклатуру, отвечающую следующим условиям: 
				|
				|● Установлен флажок ""Дропшиппинг"".
				|● Способ пополнения — Покупка.
				|● Спецификация по умолчанию не указана.';
				|pl = 'Nie można wygenerować ""Zamówienie zakupu: Dropshipping"" z Zamówienia sprzedaży. 
				|Można wygenerować takie Zamówienia zakupu tylko 
				|z Zamówień sprzedaży z produktami, które spełniają wszystkie poniższe warunki:
				|
				|● Pole wyboru Dropshipping jest zaznaczone.
				|● Jako metoda jest ustawiony Zakup.
				|● Nie wybrano domyślnej specyfikacji materiałowej.';
				|es_ES = 'No se puede generar una ""Orden de compra: Envío directo"" desde esta orden de ventas. 
				|Sólo se pueden generar estas Órdenes de Compra
				|desde las Órdenes de Venta con productos que cumplan todas las condiciones siguientes:
				|
				|● La casilla de verificación de Envío directo está seleccionada.
				|● El método de reposición del inventario es la Compra
				|● La lista de materiales por defecto no está especificada.';
				|es_CO = 'No se puede generar una ""Orden de compra: Envío directo"" desde esta orden de ventas. 
				|Sólo se pueden generar estas Órdenes de Compra
				|desde las Órdenes de Venta con productos que cumplan todas las condiciones siguientes:
				|
				|● La casilla de verificación de Envío directo está seleccionada.
				|● El método de reposición del inventario es la Compra
				|● La lista de materiales por defecto no está especificada.';
				|tr = 'Bu Satış siparişinden ""Satın alma siparişi: Stoksuz satış"" oluşturulamıyor. 
				|Bu tür satın alma siparişleri sadece ürünleri şu koşulların tümünü karşılayan 
				|Satış siparişlerinden oluşturulabilir:
				|
				|●Stoksuz satış onay kutusu seçili.
				|●Stok yenileme yöntemi Satın alma.
				|●Varsayılan ürün reçetesi belirtilmemiş.';
				|it = 'Impossibile creare ""Ordine di acquisto: Dropshipping"" da questo Ordine cliente. 
				|È possibile generare questi Ordini di acquisto solo 
				|dagli Ordini cliente con articoli che rispettino tutte le seguenti condizioni:
				|
				|● La casella di controllo Dropshipping è selezionata.
				|● Il metodo di rifornimento è Acquisto.
				|● La Distinta base predefinita non è indicata.';
				|de = 'Fehler beim Generieren von ""Bestellung an Lieferanten: Streckengeschäft"" aus diesem Kundenauftrag. 
				|Sie klnnen so eine Bestellung an Lieferanten nur 
				| aus Kundenaufträgen mit Produkten generieren, die den folgenden Forderungen entsprechen:
				|
				|● Das Kontrollkästchen Streckengeschäft ist aktiviert.
				|● Auffüllungsmethode ist Einkauf.
				|● Die Standardstückliste ist nicht angegeben.'");
			
		Else
		
			If ResultsArray[4].IsEmpty() Then
				CountOrdersBalance = ResultsArray[2].Select().Count();
				If CountOrdersBalance = 0 Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Cannot generate a purchase order. Sales order #%1 is fully dispatched.'; ru = 'Невозможно создать заказ поставщику. Заказ покупателя №%1 полностью отгружен.';pl = 'Nie można wygenerować zamówienia zakupu. Zamówienie sprzedaży #%1 jest w pełni zrealizowane.';es_ES = 'No se puede generar una orden de compra. La orden de ventas#%1 se ha enviado completamente.';es_CO = 'No se puede generar una orden de compra. La orden de ventas#%1 se ha enviado completamente.';tr = 'Satın alma siparişi oluşturulamıyor. #%1 satış siparişi tamamen sevk edildi.';it = 'Impossibile generare un ordine di acquisto. L''ordine cliente #%1 è pienamente consegnato.';de = 'Die Bestellung an Lieferanten kann nicht generiert werden. Der Kundenauftrag Nr. %1 ist völlig versendet.'"),
						RowOrder.Number);
				Else
					ErrorText = NStr(
						"en = 'Cannot generate a Purchase order from this Sales order. 
						|You can generate Purchase orders only 
						|from Sales orders with products that meet all of the following conditions:
						|
						|● Replenishment method is Purchase.
						|● Default bill of materials is not specified.'; 
						|ru = 'Не удалось создать заказ поставщику на основании данного заказа покупателя. 
						|Вы можете создавать заказы поставщику только 
						|на основании заказов покупателей, включающих номенклатуру, отвечающую следующим условиям: 
						|
						|● Способ пополнения — Покупка.
						|● Спецификация по умолчанию не указана.';
						|pl = 'Nie można wygenerować ""Zamówienie zakupu"" z Zamówienia sprzedaży. 
						|Można wygenerować Zamówienia zakupu tylko 
						|z Zamówień sprzedaży z produktami, które spełniają wszystkie poniższe warunki:
						|
						|● Jako metoda jest ustawiony Zakup.
						|● Nie wybrano domyślnej specyfikacji materiałowej.';
						|es_ES = 'No se puede generar una orden de compra desde esta orden de ventas. 
						|Sólo se pueden generar órdenes de compra 
						|desde las Órdenes de venta con productos que cumplan todas las condiciones siguientes:
						|
						|● El método de reposición del inventario es la Compra.
						|● La lista de materiales por defecto no está especificada.';
						|es_CO = 'No se puede generar una orden de compra desde esta orden de ventas. 
						|Sólo se pueden generar órdenes de compra 
						|desde las Órdenes de venta con productos que cumplan todas las condiciones siguientes:
						|
						|● El método de reposición del inventario es la Compra.
						|● La lista de materiales por defecto no está especificada.';
						|tr = 'Bu Satış siparişinden Satın alma siparişi oluşturulamıyor. 
						|Satın alma siparişleri sadece ürünleri şu koşulların tümünü karşılayan 
						|Satış siparişlerinden oluşturulabilir:
						|
						|● Stok yenileme yöntemi Satın alma.
						|● Varsayılan ürün reçetesi belirtilmemiş.';
						|it = 'Impossibile creare un Ordine di acquisto da questo Ordine cliente. 
						|È possibile generare questi Ordini di acquisto solo 
						|dagli Ordini cliente con articoli che rispettino tutte le seguenti condizioni:
						|
						|● Il metodo di rifornimento è Acquisto.
						|● La Distinta base predefinita non è indicata.';
						|de = 'Fehler beim Generieren einer Bestellung an Lieferanten aus diesem Kundenauftrag. 
						|Sie können Bestellungen an Lieferanten nur 
						| aus Kundenaufträgen mit Produkten generieren, die den folgenden Forderungen entsprechen:
						|
						|● Auffüllungsmethode ist Einkauf.
						|● Die Standardstückliste ist nicht angegeben.'");
				EndIf;
			Else
				ErrorText = NStr(
					"en = 'Cannot generate a Purchase order. 
					|The Sales order includes products marked for drop shipping. 
					|For this Sales order, generate ""Purchase order: Drop shipping""'; 
					|ru = 'Не удается создать заказ поставщику. 
					|Заказ покупателя содержит номенклатуру, помеченную для дропшиппинга. 
					|Для этого заказа покупателя создайте «Заказ поставщику: Дропшиппинг»';
					|pl = 'Nie można wygenerować Zamówienia zakupu. 
					|Zamówienie sprzedaży zawiera produkty, zaznaczone do dropshippingu. 
					|Dla tego Zamówienia sprzedaży, wygeneruj ""Zamówienie zakupu: Dropshipping""';
					|es_ES = 'No se puede generar una orden de compra. 
					|La orden de ventas incluye productos marcados para el envío directo. 
					|Para esta orden de ventas, genere ""Orden de compra: Envío directo""';
					|es_CO = 'No se puede generar una orden de compra. 
					|La orden de ventas incluye productos marcados para el envío directo. 
					|Para esta orden de ventas, genere ""Orden de compra: Envío directo""';
					|tr = 'Satın alma siparişi oluşturulamıyor. 
					|Bu satış siparişi, stoksuz satış için işaretlenmiş ürünler içeriyor. 
					|Bu Satış siparişi için ""Satın alma siparişi: Stoksuz satış"" oluşturun';
					|it = 'Impossibile generare un Ordine di acquisto. 
					|L''Ordine cliente include articoli contrassegnati per dropshipping. 
					|Per questo Ordine cliente generare ""Ordine di acquisto: Dropshipping""';
					|de = 'Fehler beim Generieren einer Bestellung an Lieferanten. 
					|Der Kundenauftrag enthält für Streckengeschäft markierte Produkte. 
					|Für diesen Kundenauftrag generieren Sie ""Bestellung an Lieferanten: Streckengeschäft""'");
			EndIf;
		EndIf;
		
		Raise ErrorText;
		
	EndIf;
	
	OrdersTable = Inventory.Unload(, "SalesOrder");
	OrdersTable.GroupBy("SalesOrder");
	
	If OrdersTable.Count() > 1 Then
		SalesOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(SalesOrderPosition) Then
			SalesOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InTabularSection Then
		SalesOrder = Undefined;
		BasisDocument = Undefined;
	ElsIf OrdersTable.Count() > 0 Then
		
		If Not ValueIsFilled(SalesOrder) Then
			SalesOrder = OrdersTable[0].SalesOrder;
		EndIf;
		
		If Not ValueIsFilled(BasisDocument) Then
			BasisDocument = SalesOrder;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure FillByWorkOrder(FillingData) Export
	
	OrdersArray = New Array;
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfWorkOrders") Then
		OrdersArray = FillingData.ArrayOfWorkOrders;
	Else
		OrdersArray.Add(FillingData.Ref);
	EndIf;
	
	// Tabular section filling.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	WorkOrder.Ref AS Ref,
	|	WorkOrder.Company AS Company,
	|	WorkOrder.CompanyVATNumber AS CompanyVATNumber,
	|	WorkOrder.Start AS Start,
	|	WorkOrder.OrderState AS OrderState,
	|	WorkOrder.Posted AS Posted
	|INTO WorkOrderTable
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|WHERE
	|	WorkOrder.Ref IN(&OrdersArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrder.Ref AS Ref,
	|	WorkOrder.Company AS Company,
	|	WorkOrder.CompanyVATNumber AS CompanyVATNumber,
	|	WorkOrder.Start AS Start,
	|	WorkOrder.OrderState AS OrderState,
	|	WorkOrder.Posted AS Posted
	|FROM
	|	WorkOrderTable AS WorkOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	OrdersBalance.QuantityBalance AS QuantityBalance
	|INTO OrdersBalance
	|FROM
	|	AccumulationRegister.WorkOrders.Balance(
	|			,
	|			WorkOrder IN
	|					(SELECT
	|						WorkOrderTable.Ref
	|					FROM
	|						WorkOrderTable AS WorkOrderTable)
	|				AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS OrdersBalance
	|
	|UNION ALL
	|
	|SELECT
	|	ReservedProductsBalances.Products,
	|	ReservedProductsBalances.Characteristic,
	|	-ReservedProductsBalances.QuantityBalance
	|FROM
	|	AccumulationRegister.ReservedProducts.Balance(
	|			,
	|			SalesOrder IN
	|					(SELECT
	|						WorkOrderTable.Ref
	|					FROM
	|						WorkOrderTable AS WorkOrderTable)
	|				AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS ReservedProductsBalances
	|
	|UNION ALL
	|
	|SELECT
	|	PlacementBalances.Products,
	|	PlacementBalances.Characteristic,
	|	-PlacementBalances.QuantityBalance
	|FROM
	|	AccumulationRegister.Backorders.Balance(
	|			,
	|			SalesOrder IN
	|					(SELECT
	|						WorkOrderTable.Ref
	|					FROM
	|						WorkOrderTable AS WorkOrderTable)
	|				AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS PlacementBalances
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentRegisterRecordsBackorders.Products,
	|	DocumentRegisterRecordsBackorders.Characteristic,
	|	CASE
	|		WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN -ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|		ELSE ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|	END
	|FROM
	|	AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
	|		INNER JOIN WorkOrderTable AS WorkOrderTable
	|		ON DocumentRegisterRecordsBackorders.SalesOrder = WorkOrderTable.Ref
	|WHERE
	|	DocumentRegisterRecordsBackorders.Recorder = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|INTO OrdersBalanceGrouped
	|FROM
	|	OrdersBalance AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OrdersBalanceGrouped.Products AS Products,
	|	OrdersBalanceGrouped.Characteristic AS Characteristic,
	|	OrdersBalanceGrouped.QuantityBalance AS QuantityBalance
	|FROM
	|	OrdersBalanceGrouped AS OrdersBalanceGrouped
	|WHERE
	|	OrdersBalanceGrouped.QuantityBalance > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	WorkOrderInventory.LineNumber AS LineNumber,
	|	WorkOrderInventory.Products AS Products,
	|	WorkOrderInventory.Characteristic AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(WorkOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE CatalogUOM.Factor
	|	END AS Factor,
	|	WorkOrderInventory.Batch AS Batch,
	|	WorkOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	WorkOrderInventory.VATRate AS VATRate,
	|	WorkOrderInventory.Quantity AS Quantity,
	|	WorkOrderInventory.Ref AS SalesOrder
	|INTO WorkOrderProducts
	|FROM
	|	Document.WorkOrder.Inventory AS WorkOrderInventory
	|		INNER JOIN WorkOrderTable AS WorkOrderTable
	|		ON WorkOrderInventory.Ref = WorkOrderTable.Ref
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON WorkOrderInventory.Products = CatalogProducts.Ref
	|			AND (CatalogProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON WorkOrderInventory.MeasurementUnit = CatalogUOM.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	WorkOrderMaterials.LineNumber,
	|	WorkOrderMaterials.Products,
	|	WorkOrderMaterials.Characteristic,
	|	CASE
	|		WHEN VALUETYPE(WorkOrderMaterials.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE CatalogUOM.Factor
	|	END,
	|	WorkOrderMaterials.Batch AS Batch,
	|	WorkOrderMaterials.MeasurementUnit,
	|	CatalogProducts.VATRate,
	|	WorkOrderMaterials.Quantity,
	|	WorkOrderMaterials.Ref
	|FROM
	|	Document.WorkOrder.Materials AS WorkOrderMaterials
	|		INNER JOIN WorkOrderTable AS WorkOrderTable
	|		ON WorkOrderMaterials.Ref = WorkOrderTable.Ref
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON WorkOrderMaterials.Products = CatalogProducts.Ref
	|			AND (CatalogProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON WorkOrderMaterials.MeasurementUnit = CatalogUOM.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(WorkOrderProducts.LineNumber) AS LineNumber,
	|	WorkOrderProducts.Products AS Products,
	|	WorkOrderProducts.Characteristic AS Characteristic,
	|	WorkOrderProducts.Factor AS Factor,
	|	WorkOrderProducts.Batch AS Batch,
	|	WorkOrderProducts.MeasurementUnit AS MeasurementUnit,
	|	WorkOrderProducts.VATRate AS VATRate,
	|	SUM(WorkOrderProducts.Quantity) AS Quantity,
	|	WorkOrderProducts.SalesOrder AS SalesOrder
	|FROM
	|	WorkOrderProducts AS WorkOrderProducts
	|
	|GROUP BY
	|	WorkOrderProducts.Products,
	|	WorkOrderProducts.Characteristic,
	|	WorkOrderProducts.MeasurementUnit,
	|	WorkOrderProducts.VATRate,
	|	WorkOrderProducts.Factor,
	|	WorkOrderProducts.Batch,
	|	WorkOrderProducts.SalesOrder
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	
	OrdersTable = ResultsArray[1].Unload();
	
	If OrdersTable.Count() > 0 Then
		
		For Each RowOrder In OrdersTable Do
			
			AttributeValues = New Structure("Company, Ref, Start, OrderState, Posted");
			FillPropertyValues(AttributeValues, RowOrder);
			
			Documents.WorkOrder.CheckAbilityOfEnteringByWorkOrder(RowOrder.Ref, AttributeValues);
			
		EndDo;
		
		Company			= RowOrder.Company;
		CompanyVATNumber= RowOrder.CompanyVATNumber;
		ReceiptDate		= DriveServer.ColumnMin(OrdersTable, "Start");
		
	EndIf;
	
	BalanceTable = ResultsArray[4].Unload();
	BalanceTable.Indexes.Add("Products,Characteristic");
	
	Inventory.Clear();
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[6].Select();
		While Selection.Next() Do
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("Products", Selection.Products);
			StructureForSearch.Insert("Characteristic", Selection.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			NewRow = Inventory.Add();
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
	
	OrdersTable = Inventory.Unload(, "SalesOrder");
	OrdersTable.GroupBy("SalesOrder");
	
	If OrdersTable.Count() > 1 Then
		SalesOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(SalesOrderPosition) Then
			SalesOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InTabularSection Then
		SalesOrder = Undefined;
		BasisDocument = Undefined;
	ElsIf OrdersTable.Count() > 0 Then
		
		If Not ValueIsFilled(SalesOrder) Then
			SalesOrder = OrdersTable[0].SalesOrder;
		EndIf;
		
		If Not ValueIsFilled(BasisDocument) Then
			BasisDocument = SalesOrder;
		EndIf;
		
	EndIf;
	
EndProcedure

// begin Drive.FullVersion

Procedure FillByProductionOrder(DocumentRefProductionOrder) Export
	
	BasisOperationKind = Common.ObjectAttributeValue(DocumentRefProductionOrder, "OperationKind");
	
	If BasisOperationKind <> Enums.OperationTypesProductionOrder.Assembly
		And BasisOperationKind <> Enums.OperationTypesProductionOrder.Disassembly Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	ProductionOrder.Ref AS Ref,
	|	ProductionOrder.Company AS Company,
	|	ProductionOrder.Start AS ReceiptDate,
	|	ProductionOrder.Posted AS BasisPosted,
	|	ProductionOrder.Closed AS BasisClosed,
	|	ProductionOrder.OrderState AS BasisOrderState,
	|	ProductionOrder.Ref AS BasisDocument,
	|	CASE
	|		WHEN UseInventoryReservation.Value
	|			THEN UNDEFINED
	|		ELSE ProductionOrder.Ref
	|	END AS SalesOrder
	|INTO TT_ProductionOrdersTable
	|FROM
	|	Document.ProductionOrder AS ProductionOrder,
	|	Constant.UseInventoryReservation AS UseInventoryReservation
	|WHERE
	|	ProductionOrder.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductionOrdersTable.Ref AS Ref,
	|	TT_ProductionOrdersTable.Company AS Company,
	|	TT_ProductionOrdersTable.BasisDocument AS BasisDocument,
	|	TT_ProductionOrdersTable.SalesOrder AS SalesOrder,
	|	TT_ProductionOrdersTable.ReceiptDate AS ReceiptDate,
	|	TT_ProductionOrdersTable.BasisPosted AS BasisPosted,
	|	TT_ProductionOrdersTable.BasisClosed AS BasisClosed,
	|	TT_ProductionOrdersTable.BasisOrderState AS BasisOrderState
	|FROM
	|	TT_ProductionOrdersTable AS TT_ProductionOrdersTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		OrdersBalance.Products AS Products,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.ProductionComponents.Balance(
	|				,
	|				ProductionDocument IN
	|					(SELECT
	|						TT_ProductionOrdersTable.Ref AS Ref
	|					FROM
	|						TT_ProductionOrdersTable AS TT_ProductionOrdersTable)) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		ReservedProductsBalances.Products,
	|		ReservedProductsBalances.Characteristic,
	|		-ReservedProductsBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.ReservedProducts.Balance(
	|				,
	|				SalesOrder IN
	|					(SELECT
	|						TT_ProductionOrdersTable.Ref AS Ref
	|					FROM
	|						TT_ProductionOrdersTable AS TT_ProductionOrdersTable)) AS ReservedProductsBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		PlacementBalances.Products,
	|		PlacementBalances.Characteristic,
	|		-PlacementBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.Backorders.Balance(
	|				,
	|				SalesOrder IN
	|					(SELECT
	|						TT_ProductionOrdersTable.Ref AS Ref
	|					FROM
	|						TT_ProductionOrdersTable AS TT_ProductionOrdersTable)) AS PlacementBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsBackorders.Products,
	|		DocumentRegisterRecordsBackorders.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN -DocumentRegisterRecordsBackorders.Quantity
	|			ELSE DocumentRegisterRecordsBackorders.Quantity
	|		END
	|	FROM
	|		AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
	|	WHERE
	|		DocumentRegisterRecordsBackorders.Recorder = &Ref
	|		AND DocumentRegisterRecordsBackorders.SalesOrder IN
	|				(SELECT
	|					TT_ProductionOrdersTable.Ref AS Ref
	|				FROM
	|					TT_ProductionOrdersTable AS TT_ProductionOrdersTable)) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ProductionOrderInventory.Products AS Products,
	|	ProductionOrderInventory.Products.VATRate AS VATRate,
	|	ProductionOrderInventory.Characteristic AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(ProductionOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE ISNULL(UOM.Factor, 1)
	|	END AS Factor,
	|	ProductionOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	ProductionOrderInventory.Quantity AS Quantity,
	|	TT_ProductionOrdersTable.SalesOrder AS SalesOrder,
	|	TT_ProductionOrdersTable.ReceiptDate AS ReceiptDate
	|FROM
	|	TT_ProductionOrdersTable AS TT_ProductionOrdersTable
	|		INNER JOIN Document.ProductionOrder.Inventory AS ProductionOrderInventory
	|		ON TT_ProductionOrdersTable.Ref = ProductionOrderInventory.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (ProductionOrderInventory.MeasurementUnit = UOM.Ref)");
	
	If BasisOperationKind = Enums.OperationTypesProductionOrder.Disassembly Then
		Query.Text = StrReplace(
		Query.Text,
		"ProductionOrder.Inventory",
		"ProductionOrder.Products");
	EndIf;
	
	Query.SetParameter("BasisDocument", DocumentRefProductionOrder);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	
	OrdersTable = ResultsArray[1].Unload();
	
	If OrdersTable.Count() > 0 Then
		
		For Each RowOrder In OrdersTable Do
			
			AttributeValues = New Structure("Closed, OrderState, Posted");
			AttributeValues.Closed = RowOrder.BasisClosed;
			AttributeValues.OrderState = RowOrder.BasisOrderState;
			AttributeValues.Posted = RowOrder.BasisPosted;
			
			Documents.ProductionOrder.VerifyEnteringAbilityByProductionOrder(RowOrder.Ref, AttributeValues);
			
		EndDo;
		
		FillPropertyValues(ThisObject, RowOrder);
		
	EndIf;
	
	DateToDefaultVATRate = ?(ValueIsFilled(Date), Date, CurrentSessionDate());
	VATTaxation = DriveServer.VATTaxation(Company, DateToDefaultVATRate);
	
	VATRate = Undefined;
	VATRateFromProducts = False;
	If VATTaxation <> Enums.VATTaxationTypes.SubjectToVAT Then
		If VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			VATRate = Catalogs.VATRates.Exempt;
		Else
			VATRate = Catalogs.VATRates.ZeroRate;
		EndIf;
	Else
		VATRateFromProducts = True;
		VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(DateToDefaultVATRate, Company);
	EndIf;
	
	BalanceTable = ResultsArray[2].Unload();
	BalanceTable.Indexes.Add("Products,Characteristic");
	
	Inventory.Clear();
	
	Selection = ResultsArray[3].Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		
		BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
		If BalanceRowsArray.Count() = 0 Then
			Continue;
		EndIf;
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, Selection);
		
		If VATRateFromProducts Then
			If Not ValueIsFilled(Selection.VATRate) Then
				NewRow.VATRate = VATRate;
			EndIf;
		Else
			NewRow.VATRate = VATRate;
		EndIf;
		
		QuantityToWriteOff = Selection.Quantity * Selection.Factor;
		BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
		If BalanceRowsArray[0].QuantityBalance < 0 Then
			
			NewRow.Quantity = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / Selection.Factor;
			
		EndIf;
		
		If BalanceRowsArray[0].QuantityBalance <= 0 Then
			BalanceTable.Delete(BalanceRowsArray[0]);
		EndIf;
		
	EndDo;
	
	If Inventory.Count() = 0 Then
		
		MessageToUser = NStr("en = 'Cannot perform the action. In the Production order, all components are consumed or ordered.'; ru = 'Не удалось выполнить действие. В заказе на производство все компоненты уже использованы или заказаны.';pl = 'Nie można wykonać działania. W Zleceniu produkcyjnym, wszystkie komponenty są zużyte lub zamówione.';es_ES = 'No se puede realizar la acción. En la Orden de producción, todos los componentes se consumen o se ordenan.';es_CO = 'No se puede realizar la acción. En la Orden de producción, todos los componentes se consumen o se ordenan.';tr = 'İşlem gerçekleştirilemiyor. Üretim emrinde, tüm malzemeler tüketildi veya sipariş edildi.';it = 'Non è possibile eseguire l''azione. Nell''ordine di produzione, tutti i componenti sono consumati o ordinati.';de = 'Fehler beim Ausführen der Aktion. Im Produktionsauftrag sind alle Komponenten verbraucht oder bestellt.'");
		Raise MessageToUser;
		
	EndIf;
	
EndProcedure

Procedure FillByWIP(DocumentRefWIP) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ManufacturingOperation.Ref AS Ref,
	|	ManufacturingOperation.Company AS Company,
	|	ManufacturingOperation.InventoryStructuralUnit AS Warehouse,
	|	ManufacturingOperation.Ref AS BasisDocument,
	|	ManufacturingOperation.Posted AS BasisPosted,
	|	ManufacturingOperation.Status AS BasisStatus,
	|	CASE
	|		WHEN UseInventoryReservation.Value
	|			THEN UNDEFINED
	|		ELSE ManufacturingOperation.Ref
	|	END AS SalesOrder,
	|	ProductionOrder.Start AS ReceiptDate
	|INTO TT_BasisDocumentHeader
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|		LEFT JOIN Document.ProductionOrder AS ProductionOrder
	|		ON ManufacturingOperation.BasisDocument = ProductionOrder.Ref,
	|	Constant.UseInventoryReservation AS UseInventoryReservation
	|WHERE
	|	ManufacturingOperation.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_BasisDocumentHeader.Company AS Company,
	|	TT_BasisDocumentHeader.Warehouse AS Warehouse,
	|	TT_BasisDocumentHeader.BasisPosted AS BasisPosted,
	|	TT_BasisDocumentHeader.BasisStatus AS BasisStatus,
	|	VALUE(Enum.OperationTypesPurchaseOrder.OrderForPurchase) AS OperationKind,
	|	TT_BasisDocumentHeader.SalesOrder AS SalesOrder,
	|	TT_BasisDocumentHeader.ReceiptDate AS ReceiptDate
	|FROM
	|	TT_BasisDocumentHeader AS TT_BasisDocumentHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		OrdersBalance.Products AS Products,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.ProductionComponents.Balance(
	|				,
	|				ProductionDocument IN
	|					(SELECT
	|						TT_BasisDocumentHeader.Ref AS Ref
	|					FROM
	|						TT_BasisDocumentHeader AS TT_BasisDocumentHeader)) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		ReservedProductsBalances.Products,
	|		ReservedProductsBalances.Characteristic,
	|		-ReservedProductsBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.ReservedProducts.Balance(
	|				,
	|				SalesOrder IN
	|					(SELECT
	|						TT_BasisDocumentHeader.Ref AS Ref
	|					FROM
	|						TT_BasisDocumentHeader AS TT_BasisDocumentHeader)) AS ReservedProductsBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		PlacementBalances.Products,
	|		PlacementBalances.Characteristic,
	|		-PlacementBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.Backorders.Balance(
	|				,
	|				SalesOrder IN
	|					(SELECT
	|						TT_BasisDocumentHeader.Ref AS Ref
	|					FROM
	|						TT_BasisDocumentHeader AS TT_BasisDocumentHeader)) AS PlacementBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsBackorders.Products,
	|		DocumentRegisterRecordsBackorders.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN -DocumentRegisterRecordsBackorders.Quantity
	|			ELSE DocumentRegisterRecordsBackorders.Quantity
	|		END
	|	FROM
	|		AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
	|	WHERE
	|		DocumentRegisterRecordsBackorders.Recorder = &Ref
	|		AND DocumentRegisterRecordsBackorders.SalesOrder IN
	|				(SELECT
	|					TT_BasisDocumentHeader.Ref AS Ref
	|				FROM
	|					TT_BasisDocumentHeader AS TT_BasisDocumentHeader)) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_BasisDocumentHeader.Ref AS Ref,
	|	ManufacturingOperationInventory.Products AS Products,
	|	ManufacturingOperationInventory.Products.VATRate AS VATRate,
	|	ManufacturingOperationInventory.Characteristic AS Characteristic,
	|	ManufacturingOperationInventory.Batch AS Batch,
	|	ManufacturingOperationInventory.Quantity AS Quantity,
	|	ManufacturingOperationInventory.MeasurementUnit AS MeasurementUnit,
	|	ManufacturingOperationInventory.ActivityConnectionKey AS ActivityConnectionKey,
	|	CASE
	|		WHEN VALUETYPE(ManufacturingOperationInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE ISNULL(UOM.Factor, 1)
	|	END AS Factor,
	|	TT_BasisDocumentHeader.SalesOrder AS SalesOrder,
	|	TT_BasisDocumentHeader.ReceiptDate AS ReceiptDate
	|FROM
	|	TT_BasisDocumentHeader AS TT_BasisDocumentHeader
	|		INNER JOIN Document.ManufacturingOperation.Inventory AS ManufacturingOperationInventory
	|			LEFT JOIN Catalog.UOM AS UOM
	|			ON ManufacturingOperationInventory.MeasurementUnit = UOM.Ref
	|		ON TT_BasisDocumentHeader.Ref = ManufacturingOperationInventory.Ref";
	
	Query.SetParameter("BasisDocument", DocumentRefWIP);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	
	OrdersTable = ResultsArray[1].Unload();
	
	If OrdersTable.Count() > 0 Then
		
		For Each RowOrder In OrdersTable Do
			
			VerifiedAttributesValues = New Structure;
			VerifiedAttributesValues.Insert("Posted", RowOrder.BasisPosted);
			VerifiedAttributesValues.Insert("ForOrderGeneration", True);
			VerifiedAttributesValues.Insert("Status", RowOrder.BasisStatus);
			Documents.ManufacturingOperation.CheckAbilityOfEnteringByWorkInProgress(DocumentRefWIP, VerifiedAttributesValues);
			
		EndDo;
		
		FillPropertyValues(ThisObject, RowOrder);
		
	EndIf;
	
	DateToDefaultVATRate = ?(ValueIsFilled(Date), Date, CurrentSessionDate());
	VATTaxation = DriveServer.VATTaxation(Company, DateToDefaultVATRate);
	
	VATRate = Undefined;
	VATRateFromProducts = False;
	If VATTaxation <> Enums.VATTaxationTypes.SubjectToVAT Then
		If VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			VATRate = Catalogs.VATRates.Exempt;
		Else
			VATRate = Catalogs.VATRates.ZeroRate;
		EndIf;
	Else
		VATRateFromProducts = True;
		VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(DateToDefaultVATRate, Company);
	EndIf;
	
	BalanceTable = ResultsArray[2].Unload();
	BalanceTable.Indexes.Add("Products,Characteristic");
	
	Inventory.Clear();
	
	Selection = ResultsArray[3].Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		
		BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
		If BalanceRowsArray.Count() = 0 Then
			Continue;
		EndIf;
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, Selection);
		
		If VATRateFromProducts Then
			If Not ValueIsFilled(Selection.VATRate) Then
				NewRow.VATRate = VATRate;
			EndIf;
		Else
			NewRow.VATRate = VATRate;
		EndIf;
		
		QuantityToWriteOff = Selection.Quantity * Selection.Factor;
		BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
		If BalanceRowsArray[0].QuantityBalance < 0 Then
			
			NewRow.Quantity = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / Selection.Factor;
			
		EndIf;
		
		If BalanceRowsArray[0].QuantityBalance <= 0 Then
			BalanceTable.Delete(BalanceRowsArray[0]);
		EndIf;
		
	EndDo;
	
	If Inventory.Count() = 0 Then
		
		MessageToUser = NStr("en = 'Cannot perform the action. In the Work-in-progress, all components are consumed or ordered.'; ru = 'Не удалось выполнить действие. В документе ""Незавершенное производство"" все компоненты уже использованы или заказаны.';pl = 'Nie można wykonać działania. W Pracy w toku, wszystkie komponenty są zużyte lub zamówione.';es_ES = 'No se puede realizar la acción. En el Trabajo en progreso, todos los componentes se consumen o se ordenan.';es_CO = 'No se puede realizar la acción. En el Trabajo en progreso, todos los componentes se consumen o se ordenan.';tr = 'İşlem gerçekleştirilemiyor. İşlem bitişinde, tüm malzemeler tüketildi veya sipariş edildi.';it = 'Non è possibile eseguire l''azione. Nel lavori in corso, tutti i componenti sono consumati o ordinati.';de = 'Fehler beim Ausführen der Aktion. In der Arbeit in Bearbeitung sind alle Komponenten verbraucht oder bestellt.'");
		Raise MessageToUser;
		
	EndIf;
	
EndProcedure

Procedure FillBySubcontractorOrderIssued(FillingData) Export
	
	AttributeValues = Common.ObjectAttributesValues(FillingData, "Posted, OrderState, Closed");
	Documents.SubcontractorOrderIssued.CheckEnterBasedOnSubcontractorOrder(AttributeValues);
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	|	SubcontractorOrderIssued.Company AS Company,
	|	SubcontractorOrderIssued.CompanyVATNumber AS CompanyVATNumber,
	|	SubcontractorOrderIssued.VATTaxation AS VATTaxation,
	|	SubcontractorOrderIssued.StructuralUnit AS Warehouse,
	|	SubcontractorOrderIssued.ReceiptDate AS ReceiptDate
	|FROM
	|	Document.SubcontractorOrderIssued AS SubcontractorOrderIssued
	|WHERE
	|	SubcontractorOrderIssued.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SubcontractorOrderIssuedInventory.Products AS Products,
	|	SubcontractorOrderIssuedInventory.Characteristic AS Characteristic,
	|	SubcontractorOrderIssuedInventory.Quantity AS Quantity,
	|	SubcontractorOrderIssuedInventory.MeasurementUnit AS MeasurementUnit,
	|	CatalogProducts.VATRate AS VATRate
	|FROM
	|	Document.SubcontractorOrderIssued.Inventory AS SubcontractorOrderIssuedInventory
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON SubcontractorOrderIssuedInventory.Products = CatalogProducts.Ref
	|WHERE
	|	SubcontractorOrderIssuedInventory.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	QueryResult = Query.ExecuteBatch();
	
	SelectionHeader = QueryResult[0].Select();
	SelectionHeader.Next();
	FillPropertyValues(ThisObject, SelectionHeader);
	
	DateToDefaultVATRate = CurrentSessionDate();
	
	SelectionInventory = QueryResult[1].Select();
	While SelectionInventory.Next() Do
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, SelectionInventory);
		
		If Not VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			
			If VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
				VATRate = Catalogs.VATRates.Exempt;
			Else
				VATRate = Catalogs.VATRates.ZeroRate;
			EndIf;
			
		ElsIf ValueIsFilled(NewRow.Products) And ValueIsFilled(SelectionInventory.VATRate) Then
			VATRate = SelectionInventory.VATRate;
		Else
			VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(DateToDefaultVATRate, Company);
		EndIf;
		
		NewRow.VATRate = VATRate;
		
	EndDo;
	
EndProcedure

// end Drive.FullVersion

Procedure FillByKitOrder(DocumentRefKitOrder) Export
	
	BasisOperationKind = Common.ObjectAttributeValue(DocumentRefKitOrder, "OperationKind");
	
	If BasisOperationKind <> Enums.OperationTypesKitOrder.Assembly
		And BasisOperationKind <> Enums.OperationTypesKitOrder.Disassembly Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED
	|	KitOrder.Ref AS Order,
	|	KitOrder.Company AS Company,
	|	KitOrder.BasisDocument AS BasisDocument,
	|	KitOrder.Start AS ReceiptDate,
	|	KitOrder.Inventory.(
	|		Ref.Start AS ReceiptDate,
	|		Products AS Products,
	|		Characteristic AS Characteristic,
	|		MeasurementUnit AS MeasurementUnit,
	|		Quantity AS Quantity,
	|		Products.VATRate AS VATRate,
	|		CASE
	|			WHEN UseInventoryReservation.Value
	|				THEN VALUE(Document.SalesOrder.EmptyRef)
	|			ELSE KitOrder.BasisDocument
	|		END AS SalesOrder
	|	) AS Inventory
	|FROM
	|	Document.KitOrder AS KitOrder,
	|	Constant.UseInventoryReservation AS UseInventoryReservation
	|WHERE
	|	KitOrder.Ref = &BasisDocument");
	
	If BasisOperationKind = Enums.OperationTypesKitOrder.Disassembly Then
		Query.Text = StrReplace(
		Query.Text,
		"KitOrder.Inventory.(",
		"KitOrder.Products.(");
	EndIf;
	
	Query.SetParameter("BasisDocument", DocumentRefKitOrder);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	FillPropertyValues(ThisObject, QueryResultSelection);
	
	DateToDefaultVATRate = ?(ValueIsFilled(Date), Date, CurrentSessionDate());
	VATTaxation = DriveServer.VATTaxation(Company, DateToDefaultVATRate);
	
	VATRate = Undefined;
	VATRateFromProducts = False;
	If VATTaxation <> Enums.VATTaxationTypes.SubjectToVAT Then
		If VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			VATRate = Catalogs.VATRates.Exempt;
		Else
			VATRate = Catalogs.VATRates.ZeroRate;
		EndIf;
	Else
		VATRateFromProducts = True;
		VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(DateToDefaultVATRate, Company);
	EndIf;
	
	Inventory.Load(QueryResultSelection.Inventory.Unload());
	
	RowsToDel = New Array;
	
	For Each RowInventory In Inventory Do
		
		If VATRateFromProducts Then
			If Not ValueIsFilled(RowInventory.VATRate) Then
				RowInventory.VATRate = VATRate;
			EndIf;
		Else
			RowInventory.VATRate = VATRate;
		EndIf;
		
		If Common.ObjectAttributeValue(RowInventory.Products, "ReplenishmentMethod") <> Enums.InventoryReplenishmentMethods.Purchase Then
			RowsToDel.Add(RowInventory);
		EndIf;
		
	EndDo;
	
	For Each RowToDel In RowsToDel Do
		Inventory.Delete(RowToDel);
	EndDo;
	
EndProcedure

Procedure FillByRFQResponse(DocumentRefRFQResponse) Export
	
	Query = New Query(
	"SELECT ALLOWED
	|	SupplierQuote.Ref AS RFQResponse,
	|	SupplierQuote.Company AS Company,
	|	SupplierQuote.CompanyVATNumber AS CompanyVATNumber,
	|	SupplierQuote.Counterparty AS Counterparty,
	|	SupplierQuote.Contract AS Contract,
	|	SupplierQuote.PaymentMethod AS PaymentMethod,
	|	SupplierQuote.CashAssetType AS CashAssetType,
	|	SupplierQuote.BankAccount AS BankAccount,
	|	SupplierQuote.DocumentCurrency AS DocumentCurrency,
	|	SupplierQuote.VATTaxation AS VATTaxation,
	|	SupplierQuote.AmountIncludesVAT AS AmountIncludesVAT,
	|	SupplierQuote.SupplierPriceTypes AS SupplierPriceTypes,
	|	SupplierQuote.PettyCash AS PettyCash,
	|	SupplierQuote.DocumentAmount AS DocumentAmount,
	|	SupplierQuote.Event AS Event,
	|	SupplierQuote.SetPaymentTerms AS SetPaymentTerms,
	|	SupplierQuote.Responsible AS Responsible,
	|	SupplierQuote.Department AS StructuralUnit,
	|	DC_ExchangeRates.Rate AS ExchangeRate,
	|	DC_ExchangeRates.Repetition AS Multiplicity,
	|	CC_ExchangeRates.Rate AS ContractCurrencyExchangeRate,
	|	CC_ExchangeRates.Repetition AS ContractCurrencyMultiplicity,
	|	SupplierQuote.Inventory.(
	|		Ref AS Ref,
	|		LineNumber AS LineNumber,
	|		Products AS Products,
	|		Characteristic AS Characteristic,
	|		Quantity AS Quantity,
	|		MeasurementUnit AS MeasurementUnit,
	|		Price AS Price,
	|		Amount AS Amount,
	|		VATRate AS VATRate,
	|		VATAmount AS VATAmount,
	|		Total AS Total,
	|		Content AS Content,
	|		DiscountPercent AS DiscountPercent,
	|		DiscountAmount AS DiscountAmount
	|	) AS Inventory,
	|	SupplierQuote.DiscountType AS DiscountType
	|FROM
	|	Document.SupplierQuote AS SupplierQuote
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON SupplierQuote.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DC_ExchangeRates
	|		ON SupplierQuote.DocumentCurrency = DC_ExchangeRates.Currency
	|			AND SupplierQuote.Company = DC_ExchangeRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS CC_ExchangeRates
	|		ON (Contracts.SettlementsCurrency = CC_ExchangeRates.Currency)
	|			AND SupplierQuote.Company = CC_ExchangeRates.Company
	|WHERE
	|	SupplierQuote.Ref = &BasisDocument");
	
	Query.SetParameter("BasisDocument", DocumentRefRFQResponse);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	FillPropertyValues(ThisObject, QueryResultSelection);
	
	Inventory.Load(QueryResultSelection.Inventory.Unload());
	
	PaymentTermsServer.FillPaymentCalendarFromDocument(ThisObject, DocumentRefRFQResponse);
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(ThisObject);
	
	DocumentAmount = Inventory.Total("Total");
	DocumentTax = Inventory.Total("VATAmount");
	DocumentSubtotal = DocumentAmount - DocumentTax + Inventory.Total("DiscountAmount");
	
EndProcedure

Procedure FillColumnReserveByBalances() Export
	
	Materials.LoadColumn(New Array(Materials.Count()), "Reserve");
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory";
	
	Query.SetParameter("TableInventory", Materials.Unload());
	Query.Execute();
	
	Query.Text =
	"SELECT ALLOWED
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, Products, Characteristic, Batch, Ownership) IN
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						&OwnInventory
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		ReservedProductsBalances.Company,
	|		ReservedProductsBalances.StructuralUnit,
	|		ReservedProductsBalances.Products,
	|		ReservedProductsBalances.Characteristic,
	|		ReservedProductsBalances.Batch,
	|		-ReservedProductsBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.ReservedProducts.Balance(
	|				,
	|				(Company, StructuralUnit, Products, Characteristic, Batch) IN
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS ReservedProductsBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsReservedProducts.Company,
	|		DocumentRegisterRecordsReservedProducts.StructuralUnit,
	|		DocumentRegisterRecordsReservedProducts.Products,
	|		DocumentRegisterRecordsReservedProducts.Characteristic,
	|		DocumentRegisterRecordsReservedProducts.Batch,
	|		DocumentRegisterRecordsReservedProducts.Quantity
	|	FROM
	|		AccumulationRegister.ReservedProducts AS DocumentRegisterRecordsReservedProducts
	|	WHERE
	|		DocumentRegisterRecordsReservedProducts.Recorder = &Ref
	|		AND DocumentRegisterRecordsReservedProducts.Period <= &Period) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	Query.SetParameter("OwnInventory", Catalogs.InventoryOwnership.OwnInventory());
	
	TableOfPeriods = New ValueTable();
	TableOfPeriods.Columns.Add("ShipmentDate");
	TableOfPeriods.Columns.Add("StringInventory");
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		
		ArrayOfRowsInventory = Materials.FindRows(StructureForSearch);
		For Each StringInventory In ArrayOfRowsInventory Do
			NewRow = TableOfPeriods.Add();
			NewRow.ShipmentDate = StringInventory.ShipmentDate;
			NewRow.StringInventory = StringInventory;
		EndDo;
		
		TotalBalance = Selection.QuantityBalance;
		TableOfPeriods.Sort("ShipmentDate");
		For Each TableOfPeriodsRow In TableOfPeriods Do
			StringInventory = TableOfPeriodsRow.StringInventory;
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				StringInventory.Reserve = TotalBalance;
				TotalBalance = 0;
			Else
				StringInventory.Reserve = StringInventory.Quantity;
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
			EndIf;
		EndDo;
		
		TableOfPeriods.Clear();
		
	EndDo;

	
EndProcedure

Procedure FillByDefault()
	
	If Not ValueIsFilled(OrderState) Then
		OrderState = GetPurchaseOrderstate();
	EndIf;
	
	If Not ValueIsFilled(ReceiptDate) Then
		ReceiptDate = CurrentSessionDate();
	EndIf;
	
EndProcedure

Procedure FillTabularSectionBySpecification(NodesBillsOfMaterialStack, NodesTable = Undefined) Export
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	TableInventory.Quantity AS Quantity,
	|	TableInventory.Factor AS Factor,
	|	TableInventory.Specification AS Specification
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	TableInventory.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)";
	
	If NodesTable = Undefined Then
		Materials.Clear();
		TableInventory = Inventory.Unload();
		Array = New Array();
		Array.Add(Type("Number"));
		TypeDescriptionC = New TypeDescription(Array, , ,New NumberQualifiers(10,3));
		TableInventory.Columns.Add("Factor", TypeDescriptionC);
		For Each StringProducts In TableInventory Do
			If ValueIsFilled(StringProducts.MeasurementUnit)
				AND TypeOf(StringProducts.MeasurementUnit) = Type("CatalogRef.UOM") Then
				StringProducts.Factor = Common.ObjectAttributeValue(StringProducts.MeasurementUnit, "Factor");
			Else
				StringProducts.Factor = 1;
			EndIf;
		EndDo;
		NodesTable = TableInventory.CopyColumns("LineNumber,Quantity,Factor,Specification");
		Query.SetParameter("TableInventory", TableInventory);
	Else
		Query.SetParameter("TableInventory", NodesTable);
	EndIf;
	
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS ProductionLineNumber,
	|	TableInventory.Specification AS ProductionSpecification,
	|	MIN(TableMaterials.LineNumber) AS StructureLineNumber,
	|	TableMaterials.ContentRowType AS ContentRowType,
	|	TableMaterials.Products AS Products,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(TableMaterials.Quantity / TableMaterials.Ref.Quantity * TableInventory.Factor * TableInventory.Quantity) AS Quantity,
	|	TableMaterials.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN TableMaterials.ContentRowType = VALUE(Enum.BOMLineType.Node)
	|				AND VALUETYPE(TableMaterials.MeasurementUnit) = TYPE(Catalog.UOM)
	|				AND TableMaterials.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN TableMaterials.MeasurementUnit.Factor
	|		ELSE 1
	|	END AS Factor,
	|	TableMaterials.CostPercentage AS CostPercentage,
	|	TableMaterials.Specification AS Specification
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON (TableMaterials.ContentRowType = VALUE(Enum.BOMLineType.Material))
	|			AND TableInventory.Specification = TableMaterials.Ref,
	|	Constant.UseCharacteristics AS UseCharacteristics
	|WHERE
	|	TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	TableInventory.Specification,
	|	TableMaterials.ContentRowType,
	|	TableMaterials.Products,
	|	TableMaterials.MeasurementUnit,
	|	CASE
	|		WHEN TableMaterials.ContentRowType = VALUE(Enum.BOMLineType.Node)
	|				AND VALUETYPE(TableMaterials.MeasurementUnit) = TYPE(Catalog.UOM)
	|				AND TableMaterials.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN TableMaterials.MeasurementUnit.Factor
	|		ELSE 1
	|	END,
	|	TableMaterials.CostPercentage,
	|	TableMaterials.Specification,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END
	|
	|ORDER BY
	|	ProductionLineNumber,
	|	StructureLineNumber";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Selection.ContentRowType = Enums.BOMLineType.Node Then
			NodesTable.Clear();
			If Not NodesBillsOfMaterialStack.Find(Selection.Specification) = Undefined Then
				MessageText = NStr("en = 'During filling in of the Specification materials
					|tabular section a recursive item occurrence was found %1 in BOM %2
					|The operation failed.'; 
					|ru = 'Во время заполнения табличной части Материалы
					|обнаружены рекурсивные ссылки в %1 спецификации %2
					|Операция не выполнена.';
					|pl = 'Podczas wypełniania sekcji tabelarycznej
					|Materiały specyfikacji znaleziono pozycję rekurencyjną %1 w Specyfikacji materiałowej %2
					|Operacja nie powiodła się.';
					|es_ES = 'Al rellenar los materiales de especificación 
					|en la sección tabular se ha encontrado la ocurrencia del artículo recursivo %1 en BOM %2
					|Operación fallada.';
					|es_CO = 'Al rellenar los materiales de especificación 
					|en la sección tabular se ha encontrado la ocurrencia del artículo recursivo %1 en BOM %2
					|Operación fallada.';
					|tr = 'Şartname malzemeleri
					|sekmeli bölümünün doldurulması sırasında %1 ürün reçetesinde %2 tekrarlayan bir öğe bulundu
					|Operasyon başarısız oldu.';
					|it = 'Durante il riempimento della sezione tabellare 
					|Materiali della specifica è stata rilevata un''occorrenza ricorsiva %1nella Distinta base%2
					|Operazione fallita.';
					|de = 'Beim Ausfüllen des Tabellenabschnitts
					|Spezifikationsmaterialien wurde in der Stückliste ein rekursives Auftreten von Positionen gefunden %1. %2
					|Die Operation ist fehlgeschlagen.'");
				Raise StringFunctionsClientServer.SubstituteParametersToString(MessageText, Selection.Products, Selection.ProductionSpecification);
			EndIf;
			NodesBillsOfMaterialStack.Add(Selection.Specification);
			NewRow = NodesTable.Add();
			FillPropertyValues(NewRow, Selection);
			FillTabularSectionBySpecification(NodesBillsOfMaterialStack, NodesTable);
		Else
			NewRow = Materials.Add();
			FillPropertyValues(NewRow, Selection);
		EndIf;
	EndDo;
	
	NodesBillsOfMaterialStack.Clear();
	Materials.GroupBy("Products, Characteristic, MeasurementUnit", "Quantity, Reserve");
	
EndProcedure

Procedure FillByStructure(FillingData) Export
	
	If FillingData.Property("ArrayOfSalesOrders") Then
		FillBySalesOrder(FillingData);
	EndIf;
	
	If FillingData.Property("ArrayOfWorkOrders") Then
		FillByWorkOrder(FillingData);
	EndIf;
	
EndProcedure

Procedure FillByRequisitionOrder(DocumentRefRequisitionOrder) Export
	
	Query = New Query(
	"SELECT ALLOWED
	|	RequisitionOrder.Ref AS Order,
	|	RequisitionOrder.Company AS Company,
	|	RequisitionOrder.Inventory.(
	|		Products AS Products,
	|		Characteristic AS Characteristic,
	|		MeasurementUnit AS MeasurementUnit,
	|		Quantity AS Quantity,
	|		Products.VATRate AS VATRate
	|	) AS Inventory,
	|	RequisitionOrder.Warehouse AS Warehouse,
	|	RequisitionOrder.ReceiptDate AS ReceiptDate,
	|	RequisitionOrder.Responsible AS Responsible
	|FROM
	|	Document.RequisitionOrder AS RequisitionOrder
	|WHERE
	|	RequisitionOrder.Ref = &BasisDocument");
	
	Query.SetParameter("BasisDocument", DocumentRefRequisitionOrder);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	FillPropertyValues(ThisObject, QueryResultSelection);
	
	DateToDefaultVATRate = ?(ValueIsFilled(Date), Date, CurrentSessionDate());
	
	VATTaxation = DriveServer.VATTaxation(Company, DateToDefaultVATRate);
	
	VATRate = Undefined;
	VATRateFromProducts = False;
	If VATTaxation <> Enums.VATTaxationTypes.SubjectToVAT Then
		If VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			VATRate = Catalogs.VATRates.Exempt;
		Else
			VATRate = Catalogs.VATRates.ZeroRate;
		EndIf;
	Else
		VATRateFromProducts = True;
		VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(DateToDefaultVATRate, Company);
	EndIf;
	
	Inventory.Load(QueryResultSelection.Inventory.Unload());
	
	For Each RowInventory In Inventory Do
		If VATRateFromProducts Then
			If Not ValueIsFilled(RowInventory.VATRate) Then
				RowInventory.VATRate = VATRate;
			EndIf;
		Else
			RowInventory.VATRate = VATRate;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function GetPurchaseOrderstate()
	
	If Constants.UsePurchaseOrderStatuses.Get() Then
		User = Users.CurrentUser();
		SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewPurchaseOrder");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.PurchaseOrderStatuses.Open;
		EndIf;
	Else
		OrderState = Constants.PurchaseOrdersInProgressStatus.Get();
	EndIf;
	
	Return OrderState;
	
EndFunction

#EndRegion

#EndIf