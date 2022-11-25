#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure CloseOrders() Export
	
	SetPrivilegedMode(True);
	
	CompleteSalesOrders();
	CompletePurchaseOrders();
	CompleteWorkOrders();
	CompleteSubcontractorOrders();
	
	// begin Drive.FullVersion
	CompleteSubcontractorOrdersReceived();
	CompleteProductionOrders();
	// end Drive.FullVersion
	CompleteKitOrders();
	
EndProcedure

Procedure FillOrders(Parameters) Export
	
	If Parameters.Property("PurposeUseKey") Then
		ShowSalesOrders = (Parameters.PurposeUseKey = "SalesOrders");
		ShowPurchaseOrders = (Parameters.PurposeUseKey = "PurchaseOrders");
		ShowProductionOrders = (Parameters.PurposeUseKey = "ProductionOrders");
		ShowWorkOrders = (Parameters.PurposeUseKey = "WorkOrders");
		ShowSubcontractorOrdersReceived = (Parameters.PurposeUseKey = "SubcontractorOrdersReceived");
		// Because we can close Kit orders in Production and Warehouse subsystems
		ShowKitOrders = (Parameters.PurposeUseKey = "ProductionOrders"
			Or Parameters.PurposeUseKey = "KitOrders");
	EndIf;
	
	SalesOrders.Clear();
	PurchaseOrders.Clear();
	ProductionOrders.Clear();
	WorkOrders.Clear();
	SubcontractorOrdersIssued.Clear();
	SubcontractorOrdersReceived.Clear();
	KitOrders.Clear();
	
	SalesOrdersArray = Undefined;
	SalesOrdersArray = Undefined;
	ProductionOrdersArray = Undefined;
	WorkOrdersArray = Undefined;
	SubcontractorOrdersArray = Undefined;
	SubcontractorOrdersReceivedArray = Undefined;
	KitOrdersArray = Undefined;
	
	If Parameters.Property("SalesOrders", SalesOrdersArray) Then
		For Each Order In SalesOrdersArray Do
			If Not Order.Closed Then
				TableRow = SalesOrders.Add();
				TableRow.Order = Order;
				TableRow.Mark = True;
			EndIf;
		EndDo;
	ElsIf Parameters.Property("PurchaseOrders", SalesOrdersArray) Then
		For Each Order In SalesOrdersArray Do
			If Not Order.Closed Then
				TableRow = PurchaseOrders.Add();
				TableRow.Order = Order;
				TableRow.Mark = True;
			EndIf;
		EndDo;
	// begin Drive.FullVersion
	ElsIf Parameters.Property("ProductionOrders", ProductionOrdersArray) Then
		For Each Order In ProductionOrdersArray Do
			If Not Order.Closed Then
				TableRow = ProductionOrders.Add();
				TableRow.Order = Order;
				TableRow.Mark = True;
			EndIf;
		EndDo;
	ElsIf Parameters.Property("SubcontractorOrdersReceived", SubcontractorOrdersReceivedArray) Then
		For Each Order In SubcontractorOrdersReceivedArray Do
			If Not Order.Closed Then
				TableRow = SubcontractorOrdersReceived.Add();
				TableRow.Order = Order;
				TableRow.Mark = True;
			EndIf;
		EndDo;
	// end Drive.FullVersion
	ElsIf Parameters.Property("WorkOrders", WorkOrdersArray) Then
		For Each Order In WorkOrdersArray Do
			If Not Order.Closed Then
				TableRow = WorkOrders.Add();
				TableRow.Order = Order;
				TableRow.Mark = True;
			EndIf;
		EndDo;
	ElsIf Parameters.Property("SubcontractorOrdersIssued", SubcontractorOrdersArray) Then
		For Each Order In SubcontractorOrdersArray Do
			If Not Order.Closed Then
				TableRow = SubcontractorOrdersIssued.Add();
				TableRow.Order = Order;
				TableRow.Mark = True;
			EndIf;
		EndDo;
	ElsIf Parameters.Property("KitOrders", KitOrdersArray) Then
		For Each Order In KitOrdersArray Do
			If Not Order.Closed Then
				TableRow = KitOrders.Add();
				TableRow.Order = Order;
				TableRow.Mark = True;
			EndIf;
		EndDo;
	Else
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED
		|	SalesOrder.Ref AS Order,
		|	SalesOrder.OrderState AS Status
		|INTO SalesOrders
		|FROM
		|	Document.SalesOrder AS SalesOrder
		|WHERE
		|	SalesOrder.Posted
		|	AND NOT SalesOrder.Closed
		|	AND &ShowSalesOrders
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	PurchaseOrder.Ref AS Order,
		|	PurchaseOrder.OrderState AS Status
		|INTO PurchaseOrders
		|FROM
		|	Document.PurchaseOrder AS PurchaseOrder
		|WHERE
		|	PurchaseOrder.Posted
		|	AND NOT PurchaseOrder.Closed
		|	AND &ShowPurchaseOrders
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	WorkOrder.Ref AS Order,
		|	WorkOrder.OrderState AS Status
		|INTO WorkOrders
		|FROM
		|	Document.WorkOrder AS WorkOrder
		|WHERE
		|	WorkOrder.Posted
		|	AND NOT WorkOrder.Closed
		|	AND &ShowWorkOrders
		|;
		|
		|SELECT
		|	SalesOrders.Order AS Order,
		|	SalesOrders.Status AS Status
		|FROM
		|	SalesOrders AS SalesOrders
		|		INNER JOIN Catalog.SalesOrderStatuses AS SalesOrderStatuses
		|		ON SalesOrders.Status = SalesOrderStatuses.Ref
		|			AND (SalesOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	PurchaseOrders.Order AS Order,
		|	PurchaseOrders.Status AS Status
		|FROM
		|	PurchaseOrders AS PurchaseOrders
		|		INNER JOIN Catalog.PurchaseOrderStatuses AS PurchaseOrderStatuses
		|		ON PurchaseOrders.Status = PurchaseOrderStatuses.Ref
		|			AND (PurchaseOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorkOrders.Order AS Order,
		|	WorkOrders.Status AS Status
		|FROM
		|	WorkOrders AS WorkOrders
		|		INNER JOIN Catalog.WorkOrderStatuses AS WorkOrderStatuses
		|		ON WorkOrders.Status = WorkOrderStatuses.Ref
		|			AND (WorkOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess))
		|;
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SubcontractorOrderIssued.Ref AS Order,
		|	SubcontractorOrderIssued.OrderState AS Status
		|INTO SubcontractorOrdersIssued
		|FROM
		|	Document.SubcontractorOrderIssued AS SubcontractorOrderIssued
		|WHERE
		|	SubcontractorOrderIssued.Posted
		|	AND NOT SubcontractorOrderIssued.Closed
		|	AND &ShowSubcontractorOrders
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SubcontractorOrdersIssued.Order AS Order,
		|	SubcontractorOrdersIssued.Status AS Status
		|FROM
		|	SubcontractorOrdersIssued AS SubcontractorOrdersIssued
		|		INNER JOIN Catalog.SubcontractorOrderIssuedStatuses AS SubcontractorOrderIssuedStatuses
		|		ON SubcontractorOrdersIssued.Status = SubcontractorOrderIssuedStatuses.Ref
		|			AND (SubcontractorOrderIssuedStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	KitOrder.Ref AS Order,
		|	KitOrder.OrderState AS Status
		|INTO KitOrders
		|FROM
		|	Document.KitOrder AS KitOrder
		|WHERE
		|	KitOrder.Posted
		|	AND NOT KitOrder.Closed
		|	AND &ShowKitOrders
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	KitOrders.Order AS Order,
		|	KitOrders.Status AS Status
		|FROM
		|	KitOrders AS KitOrders
		|		INNER JOIN Catalog.KitOrderStatuses AS KitOrderStatuses
		|		ON KitOrders.Status = KitOrderStatuses.Ref
		|			AND (KitOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess))
		// begin Drive.FullVersion
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SubcontractorOrderReceived.Ref AS Order,
		|	SubcontractorOrderReceived.OrderState AS Status
		|INTO SubcontractorOrdersReceived
		|FROM
		|	Document.SubcontractorOrderReceived AS SubcontractorOrderReceived
		|WHERE
		|	SubcontractorOrderReceived.Posted
		|	AND NOT SubcontractorOrderReceived.Closed
		|	AND &ShowSubcontractorOrdersReceived
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SubcontractorOrdersReceived.Order AS Order,
		|	SubcontractorOrdersReceived.Status AS Status
		|FROM
		|	SubcontractorOrdersReceived AS SubcontractorOrdersReceived
		|		INNER JOIN Catalog.SubcontractorOrderReceivedStatuses AS SubcontractorOrderReceivedStatuses
		|		ON SubcontractorOrdersReceived.Status = SubcontractorOrderReceivedStatuses.Ref
		|			AND (SubcontractorOrderReceivedStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess))
		|
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	ProductionOrder.Ref AS Order,
		|	ProductionOrder.OrderState AS Status
		|INTO ProductionOrders
		|FROM
		|	Document.ProductionOrder AS ProductionOrder
		|WHERE
		|	ProductionOrder.Posted
		|	AND NOT ProductionOrder.Closed
		|	AND &ShowProductionOrders
		|
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ProductionOrders.Order AS Order,
		|	ProductionOrders.Status AS Status
		|FROM
		|	ProductionOrders AS ProductionOrders
		|		INNER JOIN Catalog.ProductionOrderStatuses AS ProductionOrderStatuses
		|		ON ProductionOrders.Status = ProductionOrderStatuses.Ref
		|			AND (ProductionOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess))
		// end Drive.FullVersion
		|";
		
		Query.SetParameter("ShowSalesOrders", ShowSalesOrders);
		Query.SetParameter("ShowPurchaseOrders", ShowPurchaseOrders);
		// begin Drive.FullVersion
		Query.SetParameter("ShowProductionOrders", ShowProductionOrders);
		// end Drive.FullVersion
		Query.SetParameter("ShowWorkOrders", ShowProductionOrders);
		Query.SetParameter("ShowSubcontractorOrders", ShowPurchaseOrders);
		Query.SetParameter("ShowSubcontractorOrdersReceived", ShowSalesOrders);
		Query.SetParameter("ShowKitOrders", ShowKitOrders);
		
		ResultArray = Query.ExecuteBatch();
		
		SalesOrders.Load(ResultArray[3].Unload());
		PurchaseOrders.Load(ResultArray[4].Unload());
		WorkOrders.Load(ResultArray[5].Unload());
		SubcontractorOrdersIssued.Load(ResultArray[7].Unload());
		KitOrders.Load(ResultArray[9].Unload());
		// begin Drive.FullVersion
		SubcontractorOrdersReceived.Load(ResultArray[11].Unload());
		ProductionOrders.Load(ResultArray[13].Unload());
		// end Drive.FullVersion
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Internal

Procedure CheckDocumentInventoryReservation() Export
	
	If SalesOrders.Count() = 0 Then
		Return;
	EndIf;
	
	MarkedSalesOrders	= SalesOrders.Unload(New Structure("Mark", True));
	OrdersArray			= MarkedSalesOrders.UnloadColumn("Order");
	
	Query = New Query;
	Query.SetParameter("Orders", OrdersArray);
	Query.Text =
	"SELECT ALLOWED
	|	InventoryReservation.Date AS ReservationDate,
	|	InventoryReservation.Number AS ReservationNumber,
	|	DocumentSalesOrder.Date AS SalesOrderDate,
	|	DocumentSalesOrder.Number AS SalesOrderNumber
	|FROM
	|	Document.InventoryReservation AS InventoryReservation
	|		INNER JOIN Document.SalesOrder AS DocumentSalesOrder
	|		ON InventoryReservation.SalesOrder = DocumentSalesOrder.Ref
	|WHERE
	|	DocumentSalesOrder.Ref IN(&Orders)
	|	AND InventoryReservation.Posted";
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		While Selection.Next() Do
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'There is Inventory reservation #%1, %2 based on Sales order #%3, %4.'; ru = 'Существует резервирование запасов %1, %2 на основании заказа покупателя %3, %4.';pl = 'Istnieje Rezerwacja zapasów nr %1, %2 na podstawie Zamówienia sprzedaży nr %3, %4.';es_ES = 'Hay Reserva de inventario #%1, %2 basada en la Orden de venta #%3, %4.';es_CO = 'Hay Reserva de inventario #%1, %2 basada en la Orden de venta #%3, %4.';tr = '%3 sayılı %4 Satış siparişi bazlı %1 sayılı %2 Stok rezervasyonu var.';it = 'Vi è riserva di scorte #%1, %2 basata sull''Ordine cliente #%3, %4.';de = 'Es gibt die Bestandsreservierung Nr. %1, %2 auf der Grundlage der Kundenauftragsnummer %3, %4.'"),
				ObjectPrefixationClientServer.GetNumberForPrinting(Selection.ReservationNumber, True, True),
				Format(Selection.ReservationDate, "DLF=D"),
				ObjectPrefixationClientServer.GetNumberForPrinting(Selection.SalesOrderNumber, True, True),
				Format(Selection.SalesOrderDate, "DLF=D"));
				
			CommonClientServer.MessageToUser(MessageText);
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion 

#Region Private

Procedure CompleteSalesOrders()
	
	If SalesOrders.Count() = 0 Then
		Return;
	EndIf;
	
	CompletedStatus = DriveReUse.GetStatusCompletedSalesOrders();
	
	For Each Row In SalesOrders Do
		If Row.Mark Then 
			ReverseInvoicesAndOrdersPayment(Row.Order);
			ReverseReservedProducts(Row.Order);
			ReverseInventoryFlowCalendar(Row.Order);
			ReverseSalesOrders(Row.Order);
			ReverseOrderFulfillmentSchedule(Row.Order);
			ReversePaymentCalendar(Row.Order);
			ReverseBackordersBySalesOrders(Row.Order);
			
			OrderObject = Row.Order.GetObject();
			OrderObject.OrderState = CompletedStatus;
			OrderObject.Closed = True;
			OrderObject.DataExchange.Load = True;
			OrderObject.Write();
			
			ReflectTasksForCostsCalculation(OrderObject);
			Row.Completed = True;
		EndIf;
	EndDo;
	
EndProcedure

Procedure CompleteWorkOrders()
	
	If WorkOrders.Count() = 0 Then
		Return;
	EndIf;
	
	CompletedStatus = DriveReUse.GetStatusCompletedWorkOrders();
	
	For Each Row In WorkOrders Do
		If Row.Mark Then
			ReverseReservedProducts(Row.Order);
			ReverseInventoryFlowCalendar(Row.Order);
			ReverseWorkOrders(Row.Order);
			ReversePaymentCalendar(Row.Order);
			
			OrderObject = Row.Order.GetObject();
			OrderObject.OrderState = CompletedStatus;
			OrderObject.Closed = True;
			OrderObject.DataExchange.Load = True;
			OrderObject.Write();
			
			ReflectTasksForCostsCalculation(OrderObject);
			Row.Completed = True;
		EndIf;
	EndDo;
	
EndProcedure

Procedure CompletePurchaseOrders()
	
	If PurchaseOrders.Count() = 0 Then
		Return;
	EndIf;
	
	CompletedStatus = DriveReUse.GetOrderStatus("PurchaseOrderStatuses", "Completed");
	
	For Each Row In PurchaseOrders Do
		If Row.Mark Then 
			ReverseInvoicesAndOrdersPayment(Row.Order);
			ReverseInventoryFlowCalendar(Row.Order);
			ReversePurchaseOrders(Row.Order);
			ReverseOrderFulfillmentSchedule(Row.Order);
			ReversePaymentCalendar(Row.Order);
			
			OrderObject = Row.Order.GetObject();
			OrderObject.OrderState = CompletedStatus;
			OrderObject.Closed = True;
			OrderObject.DataExchange.Load = True;
			OrderObject.Write();
			
			ReflectTasksForCostsCalculation(OrderObject);
			Row.Completed = True;
		EndIf;
	EndDo;
	
EndProcedure

// begin Drive.FullVersion
Procedure CompleteProductionOrders()
	
	If ProductionOrders.Count() = 0 Then
		Return;
	EndIf;
	
	CompletedStatus = DriveReUse.GetOrderStatus("ProductionOrderStatuses", "Completed");
	
	For Each Row In ProductionOrders Do
		If Row.Mark Then 
			ReverseBackorders(Row.Order);
			ReverseInventoryFlowCalendar(Row.Order);
			ReverseInventoryDemand(Row.Order);
			ReverseProductionOrders(Row.Order);
			
			OrderObject = Row.Order.GetObject();
			OrderObject.OrderState = CompletedStatus;
			OrderObject.Closed = True;
			OrderObject.DataExchange.Load = True;
			OrderObject.Write();
			
			DriveServer.ReflectTasksForUpdatingStatuses(OrderObject.Ref);
			ReflectTasksForCostsCalculation(OrderObject);
			Row.Completed = True;
		EndIf;
	EndDo;
	
EndProcedure

Procedure CompleteSubcontractorOrdersReceived()
	
	If SubcontractorOrdersReceived.Count() = 0 Then
		Return;
	EndIf;
	
	CompletedStatus = DriveReUse.GetOrderStatus("SubcontractorOrderReceivedStatuses", "Completed");
	
	For Each Row In SubcontractorOrdersReceived Do
		
		If Row.Mark Then
			
			ReverseInventoryDemand(Row.Order);
			ReverseInventoryFlowCalendar(Row.Order);
			ReversePaymentCalendar(Row.Order);
			ReverseProductRelease(Row.Order);
			ReverseSubcontractorOrdersReceived(Row.Order);
			
			OrderObject = Row.Order.GetObject();
			OrderObject.OrderState = CompletedStatus;
			OrderObject.Closed = True;
			OrderObject.DataExchange.Load = True;
			OrderObject.Write();
			
			ReflectTasksForCostsCalculation(OrderObject);
			Row.Completed = True;
			
		EndIf;
		
	EndDo;
	
EndProcedure
// end Drive.FullVersion

Procedure CompleteKitOrders()
	
	If KitOrders.Count() = 0 Then
		Return;
	EndIf;
	
	CompletedStatus = DriveReUse.GetOrderStatus("KitOrderStatuses", "Completed");
	
	For Each Row In KitOrders Do
		If Row.Mark Then
			ReverseBackorders(Row.Order);
			ReverseInventoryFlowCalendar(Row.Order);
			ReverseInventoryDemandForKitOrder(Row.Order);
			ReverseKitOrders(Row.Order);
			
			OrderObject = Row.Order.GetObject();
			OrderObject.OrderState = CompletedStatus;
			OrderObject.Closed = True;
			OrderObject.DataExchange.Load = True;
			OrderObject.Write();
			
			ReflectTasksForCostsCalculation(OrderObject);
			Row.Completed = True;
		EndIf;
	EndDo;
	
EndProcedure

Procedure CompleteSubcontractorOrders()
	
	If SubcontractorOrdersIssued.Count() = 0 Then
		Return;
	EndIf;
	
	CompletedStatus = DriveReUse.GetOrderStatus("SubcontractorOrderIssuedStatuses", "Completed");
	
	For Each Row In SubcontractorOrdersIssued Do
		
		If Row.Mark Then
			
			ReverseInvoicesAndOrdersPayment(Row.Order);
			ReverseInventoryFlowCalendar(Row.Order);
			ReverseInventoryDemandForSubcontractorOrders(Row.Order);
			ReverseSubcontractorOrders(Row.Order);
			ReverseOrderFulfillmentSchedule(Row.Order);
			ReversePaymentCalendar(Row.Order);
			
			OrderObject = Row.Order.GetObject();
			OrderObject.OrderState = CompletedStatus;
			OrderObject.Closed = True;
			OrderObject.DataExchange.Load = True;
			OrderObject.Write();
			
			ReflectTasksForCostsCalculation(OrderObject);
			Row.Completed = True;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ReverseInvoicesAndOrdersPayment(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	AccountsReceivableTurnovers.Order AS Order,
	|	AccountsReceivableTurnovers.Company AS Company,
	|	AccountsReceivableTurnovers.AmountCurReceipt AS Amount
	|INTO TableInvoicesAndOrdersPayment
	|FROM
	|	AccumulationRegister.AccountsReceivable.Turnovers(, , , Order = &Order) AS AccountsReceivableTurnovers
	|
	|UNION ALL
	|
	|SELECT
	|	AccountsPayableTurnovers.Order,
	|	AccountsPayableTurnovers.Company,
	|	AccountsPayableTurnovers.AmountCurReceipt
	|FROM
	|	AccumulationRegister.AccountsPayable.Turnovers(, , , Order = &Order) AS AccountsPayableTurnovers
	|
	|UNION ALL
	|
	|SELECT
	|	InvoicesAndOrdersPaymentTurnovers.Quote,
	|	InvoicesAndOrdersPaymentTurnovers.Company,
	|	-InvoicesAndOrdersPaymentTurnovers.AmountTurnover
	|FROM
	|	AccumulationRegister.InvoicesAndOrdersPayment.Turnovers(, , , Quote = &Order) AS InvoicesAndOrdersPaymentTurnovers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&CurrentDate AS Period,
	|	TableInvoicesAndOrdersPayment.Order AS Quote,
	|	TableInvoicesAndOrdersPayment.Company AS Company,
	|	SUM(TableInvoicesAndOrdersPayment.Amount) AS Amount
	|FROM
	|	TableInvoicesAndOrdersPayment AS TableInvoicesAndOrdersPayment
	|
	|GROUP BY
	|	TableInvoicesAndOrdersPayment.Order,
	|	TableInvoicesAndOrdersPayment.Company
	|
	|HAVING
	|	SUM(TableInvoicesAndOrdersPayment.Amount) <> 0";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.InvoicesAndOrdersPayment.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);	
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Procedure ReverseReservedProducts(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	&CurrentDate AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ReservedProductsBalance.Company AS Company,
	|	ReservedProductsBalance.StructuralUnit AS StructuralUnit,
	|	ReservedProductsBalance.Products AS Products,
	|	ReservedProductsBalance.Characteristic AS Characteristic,
	|	ReservedProductsBalance.Batch AS Batch,
	|	ReservedProductsBalance.SalesOrder AS SalesOrder,
	|	-ReservedProductsBalance.QuantityBalance AS Quantity
	|FROM
	|	AccumulationRegister.ReservedProducts.Balance(, SalesOrder = &Order) AS ReservedProductsBalance";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.ReservedProducts.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Procedure ReverseInventoryFlowCalendar(Order)
	
	RecordSet = AccumulationRegisters.InventoryFlowCalendar.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);	
	RecordSet.Write();
	
EndProcedure

Procedure ReverseSalesOrders(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	&CurrentDate AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	SalesOrdersBalance.Company AS Company,
	|	SalesOrdersBalance.Products AS Products,
	|	SalesOrdersBalance.Characteristic AS Characteristic,
	|	SalesOrdersBalance.SalesOrder AS SalesOrder,
	|	-SalesOrdersBalance.QuantityBalance AS Quantity,
	|	SalesOrdersBalance.Products AS ProductsCorr
	|FROM
	|	AccumulationRegister.SalesOrders.Balance(, SalesOrder = &Order) AS SalesOrdersBalance";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.SalesOrders.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);	
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Procedure ReverseWorkOrders(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	&CurrentDate AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	WorkOrdersBalance.Company AS Company,
	|	WorkOrdersBalance.Products AS Products,
	|	WorkOrdersBalance.Characteristic AS Characteristic,
	|	-WorkOrdersBalance.QuantityBalance AS Quantity,
	|	WorkOrdersBalance.Products AS ProductsCorr,
	|	WorkOrdersBalance.WorkOrder AS WorkOrder
	|FROM
	|	AccumulationRegister.WorkOrders.Balance(, WorkOrder = &Order) AS WorkOrdersBalance";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.WorkOrders.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Procedure ReversePurchaseOrders(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	&CurrentDate AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	PurchaseOrdersBalance.Company AS Company,
	|	PurchaseOrdersBalance.Products AS Products,
	|	PurchaseOrdersBalance.Characteristic AS Characteristic,
	|	PurchaseOrdersBalance.PurchaseOrder AS PurchaseOrder,
	|	-PurchaseOrdersBalance.QuantityBalance AS Quantity,
	|	PurchaseOrdersBalance.Products AS ProductsCorr
	|FROM
	|	AccumulationRegister.PurchaseOrders.Balance(, PurchaseOrder = &Order) AS PurchaseOrdersBalance";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.PurchaseOrders.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);	
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Procedure ReverseSubcontractorOrders(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	&CurrentDate AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	SubcontractorOrdersBalance.Company AS Company,
	|	SubcontractorOrdersBalance.Products AS Products,
	|	SubcontractorOrdersBalance.Characteristic AS Characteristic,
	|	SubcontractorOrdersBalance.SubcontractorOrder AS SubcontractorOrder,
	|	-SubcontractorOrdersBalance.QuantityBalance AS Quantity,
	|	SubcontractorOrdersBalance.Products AS ProductsCorr,
	|	SubcontractorOrdersBalance.FinishedProductType AS FinishedProductType
	|FROM
	|	AccumulationRegister.SubcontractorOrdersIssued.Balance(, SubcontractorOrder = &Order) AS SubcontractorOrdersBalance";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.SubcontractorOrdersIssued.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Procedure ReverseInventoryDemandForSubcontractorOrders(Order)
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SubcontractorOrder.Ref AS Ref
	|INTO Registers
	|FROM
	|	Document.SubcontractorOrderIssued AS SubcontractorOrder
	|WHERE
	|	SubcontractorOrder.Ref = &Order
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsIssue.Ref
	|FROM
	|	Document.GoodsIssue AS GoodsIssue
	|WHERE
	|	GoodsIssue.Posted
	|	AND GoodsIssue.Order = &Order
	|	AND GoodsIssue.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractor)
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsReceipt.Ref
	|FROM
	|	Document.GoodsReceipt AS GoodsReceipt
	|WHERE
	|	GoodsReceipt.Posted
	|	AND GoodsReceipt.Order = &Order
	|	AND GoodsReceipt.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromSubcontractor)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	&CurrentDate AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	InventoryDemandTurnovers.Company AS Company,
	|	InventoryDemandTurnovers.Products AS Products,
	|	InventoryDemandTurnovers.Characteristic AS Characteristic,
	|	InventoryDemandTurnovers.MovementType AS MovementType,
	|	InventoryDemandTurnovers.SalesOrder AS SalesOrder,
	|	InventoryDemandTurnovers.ProductionDocument AS ProductionDocument,
	|	-SUM(InventoryDemandTurnovers.QuantityTurnover) AS Quantity
	|FROM
	|	AccumulationRegister.InventoryDemand.Turnovers(, , Recorder, ) AS InventoryDemandTurnovers
	|		INNER JOIN Registers AS Registers
	|		ON InventoryDemandTurnovers.Recorder = Registers.Ref
	|
	|GROUP BY
	|	InventoryDemandTurnovers.Products,
	|	InventoryDemandTurnovers.MovementType,
	|	InventoryDemandTurnovers.Characteristic,
	|	InventoryDemandTurnovers.SalesOrder,
	|	InventoryDemandTurnovers.Company,
	|	InventoryDemandTurnovers.ProductionDocument
	|
	|HAVING
	|	SUM(InventoryDemandTurnovers.QuantityTurnover) <> 0";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.InventoryDemand.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Procedure ReverseBackordersBySalesOrders(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	&CurrentDate AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	BackordersBalance.Company AS Company,
	|	BackordersBalance.SalesOrder AS SalesOrder,
	|	BackordersBalance.Products AS Products,
	|	BackordersBalance.Characteristic AS Characteristic,
	|	BackordersBalance.SupplySource AS SupplySource,
	|	-BackordersBalance.QuantityBalance AS Quantity
	|FROM
	|	AccumulationRegister.Backorders.Balance(, SalesOrder = &Order) AS BackordersBalance";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.Backorders.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
	EndDo;
	RecordSet.Write();
	
EndProcedure

// begin Drive.FullVersion

Procedure ReverseProductRelease(Order)
	
	RecordSet = AccumulationRegisters.ProductRelease.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);
	RecordSet.Write();
	
EndProcedure

Procedure ReverseInventoryDemand(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	ProductionOrder.Ref AS Ref
	|INTO Registers
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|WHERE
	|	ProductionOrder.Ref = &Order
	|
	|UNION ALL
	|
	|SELECT
	|	Production.Ref
	|FROM
	|	Document.Production AS Production
	|WHERE
	|	Production.Posted
	|	AND Production.BasisDocument = &Order
	|
	|UNION ALL
	|
	|SELECT
	|	Production.Ref
	|FROM
	|	Document.Manufacturing AS Production
	|WHERE
	|	Production.Posted
	|	AND Production.BasisDocument = &Order
	|
	|UNION ALL
	|
	|SELECT
	|	SubcontractorOrdersReceived.Ref
	|FROM
	|	Document.SubcontractorOrderReceived AS SubcontractorOrdersReceived
	|WHERE
	|	SubcontractorOrdersReceived.Posted
	|	AND SubcontractorOrdersReceived.Ref = &Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	&CurrentDate AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	InventoryDemandTurnovers.Company AS Company,
	|	InventoryDemandTurnovers.Products AS Products,
	|	InventoryDemandTurnovers.Characteristic AS Characteristic,
	|	InventoryDemandTurnovers.MovementType AS MovementType,
	|	InventoryDemandTurnovers.SalesOrder AS SalesOrder,
	|	InventoryDemandTurnovers.ProductionDocument AS ProductionDocument,
	|	-SUM(InventoryDemandTurnovers.QuantityTurnover) AS Quantity
	|FROM
	|	AccumulationRegister.InventoryDemand.Turnovers(, , Recorder, ) AS InventoryDemandTurnovers
	|		INNER JOIN Registers AS Registers
	|		ON InventoryDemandTurnovers.Recorder = Registers.Ref
	|
	|GROUP BY
	|	InventoryDemandTurnovers.Products,
	|	InventoryDemandTurnovers.MovementType,
	|	InventoryDemandTurnovers.Characteristic,
	|	InventoryDemandTurnovers.SalesOrder,
	|	InventoryDemandTurnovers.Company,
	|	InventoryDemandTurnovers.ProductionDocument
	|
	|HAVING
	|	SUM(InventoryDemandTurnovers.QuantityTurnover) <> 0";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.InventoryDemand.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);	
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Procedure ReverseProductionOrders(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	&CurrentDate AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ProductionOrdersBalance.Company AS Company,
	|	ProductionOrdersBalance.Products AS Products,
	|	ProductionOrdersBalance.Characteristic AS Characteristic,
	|	ProductionOrdersBalance.ProductionOrder AS ProductionOrder,
	|	-ProductionOrdersBalance.QuantityBalance AS Quantity,
	|	ProductionOrdersBalance.Products AS ProductsCorr
	|FROM
	|	AccumulationRegister.ProductionOrders.Balance(, ProductionOrder = &Order) AS ProductionOrdersBalance";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.ProductionOrders.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);	
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Procedure ReverseSubcontractorOrdersReceived(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	&CurrentDate AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	SubcontractorOrdersBalance.Company AS Company,
	|	SubcontractorOrdersBalance.Counterparty AS Counterparty,
	|	SubcontractorOrdersBalance.SubcontractorOrder AS SubcontractorOrder,
	|	SubcontractorOrdersBalance.Products AS Products,
	|	SubcontractorOrdersBalance.Characteristic AS Characteristic,
	|	-SubcontractorOrdersBalance.QuantityBalance AS Quantity
	|FROM
	|	AccumulationRegister.SubcontractorOrdersReceived.Balance(, SubcontractorOrder = &Order) AS SubcontractorOrdersBalance";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.SubcontractorOrdersReceived.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

// end Drive.FullVersion

Procedure ReverseBackorders(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	&CurrentDate AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	BackordersBalance.Company AS Company,
	|	BackordersBalance.SalesOrder AS SalesOrder,
	|	BackordersBalance.Products AS Products,
	|	BackordersBalance.Characteristic AS Characteristic,
	|	BackordersBalance.SupplySource AS SupplySource,
	|	-BackordersBalance.QuantityBalance AS Quantity
	|FROM
	|	AccumulationRegister.Backorders.Balance(, SupplySource = &Order) AS BackordersBalance";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.Backorders.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);	
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Procedure ReverseInventoryDemandForKitOrder(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	KitOrder.Ref AS Ref
	|INTO Registers
	|FROM
	|	Document.KitOrder AS KitOrder
	|WHERE
	|	KitOrder.Ref = &Order
	|
	|UNION ALL
	|
	|SELECT
	|	Production.Ref
	|FROM
	|	Document.Production AS Production
	|WHERE
	|	Production.Posted
	|	AND Production.BasisDocument = &Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	&CurrentDate AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	InventoryDemandTurnovers.Company AS Company,
	|	InventoryDemandTurnovers.Products AS Products,
	|	InventoryDemandTurnovers.Characteristic AS Characteristic,
	|	InventoryDemandTurnovers.MovementType AS MovementType,
	|	InventoryDemandTurnovers.SalesOrder AS SalesOrder,
	|	InventoryDemandTurnovers.ProductionDocument AS ProductionDocument,
	|	-SUM(InventoryDemandTurnovers.QuantityTurnover) AS Quantity
	|FROM
	|	AccumulationRegister.InventoryDemand.Turnovers(, , Recorder, ) AS InventoryDemandTurnovers
	|		INNER JOIN Registers AS Registers
	|		ON InventoryDemandTurnovers.Recorder = Registers.Ref
	|
	|GROUP BY
	|	InventoryDemandTurnovers.Products,
	|	InventoryDemandTurnovers.MovementType,
	|	InventoryDemandTurnovers.Characteristic,
	|	InventoryDemandTurnovers.SalesOrder,
	|	InventoryDemandTurnovers.Company,
	|	InventoryDemandTurnovers.ProductionDocument
	|
	|HAVING
	|	SUM(InventoryDemandTurnovers.QuantityTurnover) <> 0";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.InventoryDemand.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Procedure ReverseKitOrders(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	&CurrentDate AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	KitOrdersBalance.Company AS Company,
	|	KitOrdersBalance.KitOrder AS KitOrder,
	|	KitOrdersBalance.Products AS Products,
	|	KitOrdersBalance.Characteristic AS Characteristic,
	|	-KitOrdersBalance.QuantityBalance AS Quantity,
	|	KitOrdersBalance.Products AS ProductsCorr
	|FROM
	|	AccumulationRegister.KitOrders.Balance(, KitOrder = &Order) AS KitOrdersBalance";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.KitOrders.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Procedure ReverseOrderFulfillmentSchedule(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	OrderFulfillmentSchedule.Order AS Order
	|FROM
	|	InformationRegister.OrderFulfillmentSchedule AS OrderFulfillmentSchedule
	|WHERE
	|	OrderFulfillmentSchedule.Order = &Order";
	
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = InformationRegisters.OrderFulfillmentSchedule.CreateRecordSet();
	RecordSet.Filter.Order.Set(Order);	
	RecordSet.Write();
	
EndProcedure

Procedure ReversePaymentCalendar(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	PaymentCalendar.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.PaymentCalendar AS PaymentCalendar
	|WHERE
	|	PaymentCalendar.Recorder = &Order";
	
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.PaymentCalendar.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);	
	RecordSet.Write();
	
EndProcedure

Procedure ReflectTasksForCostsCalculation(Order)
	
	InformationRegisters.TasksForCostsCalculation.CreateRegisterRecord(
		BegOfMonth(CurrentSessionDate()),
		Order.Company,
		Order.Ref);
	
EndProcedure

#EndRegion

#Else

Raise NStr("en = 'Invalid object call on the client.'; ru = 'Недопустимый вызов объекта на клиенте.';pl = 'Niepoprawne wywołanie obiektu w kliencie.';es_ES = 'Invalidar la llamada de objeto al cliente.';es_CO = 'Invalidar la llamada de objeto al cliente.';tr = 'İstemcide geçersiz nesne çağrısı.';it = 'Chiamata oggetto non valida per il client.';de = 'Ungültiger Objektabruf beim Kunden.'");

#EndIf