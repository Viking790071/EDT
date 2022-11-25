#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.DebitNote") Then
		
		AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(FillingData.Date, FillingData.Company);
		If Not AccountingPolicy.UseGoodsReturnToSupplier Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Company %1 doesn''t use goods issue for posting inventory entries at %2 (specify this option in accounting policy)'; ru = 'Организация %1 не использует отпуск товаров для проведения движений по запасам на %2 (укажите данную опцию в учетной политике)';pl = 'Firma %1 nie stosuje wydania zewnętrznego do zatwierdzenia wpisów o zapasach na %2 (wybierz tę opcję w polityce rachunkowości)';es_ES = 'Empresa %1 no utiliza la salida de mercancías para el envío de las entradas de inventario en %2 (especificar esta opción en la política de contabilidad)';es_CO = 'Empresa %1 no utiliza la salida de mercancías para el envío de las entradas de inventario en %2 (especificar esta opción en la política de contabilidad)';tr = '%1 iş yeri, %2 bölümünde stok girişlerini kaydetmek için ambar çıkışı kullanmıyor (muhasebe politikasında bu seçeneği belirtin)';it = 'L''azienda %1 non utilizza la spedizione merce per la pubblicazione degli inserimenti delle scorte in %2 (indicare questa opzione nella politica contabile)';de = 'Die Firma %1 verwendet keinen Warenausgang für Buchung des Bestands bei %2 (diese Option in der Bilanzierungsrichtlinie angeben)'"),
				FillingData.Company,
				Format(FillingData.Date, "DLF=D"))
			
		EndIf;
			
	EndIf;
	
	FillingStrategy = New Map;
	FillingStrategy[Type("Structure")]								= "FillByStructure";
	FillingStrategy[Type("DocumentRef.SalesOrder")]					= "FillBySalesOrder";
	FillingStrategy[Type("DocumentRef.PurchaseOrder")]				= "FillByPurchaseOrder";
	FillingStrategy[Type("DocumentRef.GoodsReceipt")]				= "FillByGoodsReceipt";
	FillingStrategy[Type("DocumentRef.SalesInvoice")]				= "FillBySalesInvoice";
	FillingStrategy[Type("DocumentRef.DebitNote")]					= "FillByDebitNote";
	FillingStrategy[Type("DocumentRef.SubcontractorOrderIssued")]	= "FillBySubcontractorOrderIssued";
	// begin Drive.FullVersion
	FillingStrategy[Type("DocumentRef.Production")]					= "FillByProduction";
	FillingStrategy[Type("DocumentRef.Manufacturing")]				= "FillByManufacturing";
	FillingStrategy[Type("DocumentRef.SubcontractorOrderReceived")]	= "FillBySubcontractorOrderReceived";
	// end Drive.FullVersion
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy, "Order");
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If OperationType = Enums.OperationTypesGoodsIssue.IntraCommunityTransfer Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Products.InitialQuantity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Products.Amount");
		
	ElsIf OperationType = Enums.OperationTypesGoodsIssue.PurchaseReturn Then
		
		If PurchaseOrderPosition = Enums.AttributeStationing.InHeader Then
			CheckedAttributes.Add("Contract");
		Else 
			CheckedAttributes.Add("Products.Contract");
		EndIf;
	Else
		
		If SalesOrderPosition = Enums.AttributeStationing.InHeader Then 
			CheckedAttributes.Add("Contract");
		Else 
			CheckedAttributes.Add("Products.Contract");
		EndIf;
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Products.InitialQuantity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Products.Amount");
		
	EndIf;
	
	If OperationType = Enums.OperationTypesGoodsIssue.TransferToSubcontractingCustomer Then
		CheckedAttributes.Add("Order");
	EndIf;
	
	// Income and expense items
	If OperationType = Enums.OperationTypesGoodsIssue.PurchaseReturn Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Products.RevenueItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Products.COGSItem");
		
	ElsIf OperationType = Enums.OperationTypesGoodsIssue.SaleToCustomer Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Products.PurchaseReturnItem");
		
		AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
		RevenueItemIsEmpty = False;
		RevenueItemToDelete = False;
		COGSItemIsEmpty = False;
		COGSItemToDelete = False;
		For Each Row In Products Do
			If Not ValueIsFilled(Row.SalesInvoice) Then
				RevenueItemToDelete = True;
			ElsIf Not ValueIsFilled(Row.RevenueItem) Then
				RevenueItemIsEmpty = True;
			EndIf;
			If Not ValueIsFilled(Row.SalesInvoice)
					And Not AccountingPolicy.ContinentalMethod Then
				COGSItemToDelete = True;
			ElsIf Not ValueIsFilled(Row.COGSItem) Then
				COGSItemIsEmpty = True;
			EndIf;
		EndDo;
		
		If Not RevenueItemIsEmpty And RevenueItemToDelete Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Products.RevenueItem");
		EndIf;
		If Not COGSItemIsEmpty And COGSItemToDelete Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Products.COGSItem");
		EndIf;
		
	Else
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Products.RevenueItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Products.COGSItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Products.PurchaseReturnItem");
		
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	// Bundles
	BundlesServer.CheckTableFilling(ThisObject, "Products", Cancel);
	// End Bundles
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Products, SerialNumbers, StructuralUnit, ThisObject);
	
	BatchesServer.CheckFilling(ThisObject, Cancel);
	If OperationType = Enums.OperationTypesGoodsIssue.SaleToCustomer Then
		CheckExpiredBatches(Cancel);
	EndIf;
	
		// Drop shipping
	If OperationType = Enums.OperationTypesGoodsIssue.DropShipping Then
		
		MessageTextEmptyOrder = NStr(
			"en = 'Order is required when Operation is Drop shipping.'; ru = 'При операции «Дропшиппинг» поле «Заказ» обязательно для заполнения.';pl = 'Zamówienie jest wymagane przy Operacji Dropshipping.';es_ES = 'El pedido es necesario cuando la Operación es Envío directo.';es_CO = 'El pedido es necesario cuando la Operación es Envío directo.';tr = 'İşlem ""Stoksuz satış"" olduğunda sipariş gereklidir.';it = 'È richiesto l''Ordine quando l''Operazione è Dropshipping.';de = 'Bei der Operation Streckengeschäft ist ein Auftrag nötig.'");
		MessageText = NStr(
			"en = 'The specified order does not include products for drop shipping. 
			|Specify an order including products with the ""Drop shipping"" checkbox selected.'; 
			|ru = 'В указанный заказ не входит номенклатура для дропшиппинга. 
			|Укажите заказ, включающий номенклатуру, с установленным флажком «Дропшиппинг».';
			|pl = 'Wybrane zamówienie nie zawiera produktów do dropshippingu. 
			|Wybierz zamówienie zawierające produkty z zaznaczonym polem wyboru „Dropshipping”.';
			|es_ES = 'El pedido especificado no incluye productos para el envío directo.
			|Especifique un pedido que incluya productos con la casilla de verificación ""Envío directo"" seleccionada.';
			|es_CO = 'El pedido especificado no incluye productos para el envío directo.
			|Especifique un pedido que incluya productos con la casilla de verificación ""Envío directo"" seleccionada.';
			|tr = 'Belirtilen sipariş stoksuz satış ürünü içermiyor. 
			|""Stoksuz satış"" onay kutusu seçili ürünler içeren bir sipariş belirtin.';
			|it = 'L''ordine specificato non include articoli per dropshipping.
			|Specificare un ordine che includa articoli con la casella di controllo ""Dropshipping"" selezionata.';
			|de = 'Der angegebene Auftrag enthält keine Produkte für Streckengeschäft. 
			|Geben Sie einen Auftrag mit Produkten mit dem aktivierten Kontrollkästchen ""Streckengeschäft"" ein.'");
		
		If SalesOrderPosition = Enums.AttributeStationing.InHeader Then
			If Not ValueIsFilled(Order) Then
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageTextEmptyOrder,
					Undefined,
					Undefined,
					"Order",
					Cancel);
			Else
				IsSalesOrderDS = Documents.SalesOrder.GetPropertyIsDropShippingOfSalesOrder(Order);
				If Not IsSalesOrderDS Then
					DriveServer.ShowMessageAboutError(
						ThisObject,
						MessageText,
						Undefined,
						Undefined,
						"Order",
						Cancel);
				EndIf;
			EndIf;
		Else 
			For Each ItemProducts In Products Do
				If Not ValueIsFilled(ItemProducts.Order) Then
					DriveServer.ShowMessageAboutError(
						ThisObject,
						MessageTextEmptyOrder,
						"Products",
						ItemProducts.LineNumber,
						Undefined,
						Cancel);
				Else
					IsSalesOrderDS = Documents.SalesOrder.GetPropertyIsDropShippingOfSalesOrder(ItemProducts.Order);
					If Not IsSalesOrderDS Then
						DriveServer.ShowMessageAboutError(
							ThisObject,
							MessageText,
							"Products",
							ItemProducts.LineNumber,
							Undefined,
							Cancel);
					EndIf;
				EndIf;
			EndDo;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If OperationType <> Enums.OperationTypesGoodsIssue.PurchaseReturn
		And SalesOrderPosition = Enums.AttributeStationing.InHeader
		Or OperationType = Enums.OperationTypesGoodsIssue.PurchaseReturn
		And PurchaseOrderPosition = Enums.AttributeStationing.InHeader Then
		
		For Each TabularSectionRow In Products Do
			TabularSectionRow.Order = Order;
			TabularSectionRow.Contract = Contract;
		EndDo;
	Else
		Order = Undefined;
		Contract = Undefined;
	EndIf;
	
	If Order = Undefined Then
		
		EmptyOrder = Documents.PurchaseOrder.EmptyRef();
		If OperationType = Enums.OperationTypesGoodsIssue.SaleToCustomer Then
			EmptyOrder = Documents.SalesOrder.EmptyRef();
		ElsIf OperationType = Enums.OperationTypesGoodsIssue.TransferToSubcontractor Then
			EmptyOrder = Documents.SubcontractorOrderIssued.EmptyRef();
		EndIf;
		
		For Each TabularSectionRow In Products Do
			If TabularSectionRow.Order = Undefined Then
				TabularSectionRow.Order = EmptyOrder;
			EndIf;
		EndDo;
		
	EndIf;
	
	If NOT ValueIsFilled(DeliveryOption) OR DeliveryOption = Enums.DeliveryOptions.SelfPickup Then
		ClearDeliveryAttributes();
	ElsIf DeliveryOption <> Enums.DeliveryOptions.LogisticsCompany Then
		ClearDeliveryAttributes("LogisticsCompany");
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	If OperationType <> Enums.OperationTypesGoodsIssue.PurchaseReturn Then
		FillSalesRep();
	EndIf;
	
	If OperationType = Enums.OperationTypesGoodsIssue.SaleToCustomer Then
		
		InventoryOwnershipServer.FillOwnershipTable(ThisObject, WriteMode, Cancel);
		
	Else
		
		InventoryOwnershipServer.FillMainTableColumn(ThisObject, WriteMode, Cancel);
		
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	DriveServer.CheckAvailabilityOfGoodsReturn(ThisObject, Cancel);
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	Documents.GoodsIssue.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectReservedProducts(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSalesOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsShippedNotInvoiced(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsInvoicedNotShipped(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectStockTransferredToThirdParties(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPurchaseOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSubcontractComponents(AdditionalProperties, RegisterRecords, Cancel);
	// begin Drive.FullVersion
	DriveServer.ReflectCustomerOwnedInventory(AdditionalProperties, RegisterRecords, Cancel);
	// end Drive.FullVersion

	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Serial numbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
	// Goods in transit
	If WorkWithVATServerCall.MultipleVATNumbersAreUsed() Then
		DriveServer.ReflectGoodsInTransit(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;

	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.GoodsIssue.RunControl(Ref, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	If Not Cancel Then
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.GoodsIssue.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	If Not Cancel Then
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
	EndIf;
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	Author = Users.CurrentUser();
	
	If SerialNumbers.Count() Then
		
		For Each ProductsLine In Products Do
			ProductsLine.SerialNumbers = "";
		EndDo;
		
		SerialNumbers.Clear();
		
	EndIf;
	
	ProductsOwnership.Clear();
	
	AllowExpiredBatches = False;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Write, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
	// begin Drive.FullVersion
	If Not Cancel 
		And Not AdditionalProperties.Posted
		And AdditionalProperties.WriteMode = DocumentWriteMode.Posting Then
		CheckReturnToSubcontractingCustomer(Cancel);
	EndIf;
	// end Drive.FullVersion
	
EndProcedure

#EndRegion

#Region DocumentFillingProcedures

Procedure FillBySalesOrder(FillingData) Export
	
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfSalesOrders") Then
		OrdersArray = FillingData.ArrayOfSalesOrders;
		FillPropertyValues(ThisObject, FillingData);
	Else
		OrdersArray = New Array;
		OrdersArray.Add(FillingData);
		Order = FillingData;
	EndIf;
	
	IsDropShipping = False;
	If TypeOf(FillingData) = Type("Structure") And FillingData.Property("DropShipping") 
		And FillingData.DropShipping Then
		IsDropShipping = True;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SalesOrder.Ref AS BasisRef,
	|	SalesOrder.Posted AS BasisPosted,
	|	SalesOrder.Closed AS Closed,
	|	SalesOrder.OrderState AS OrderState,
	|	SalesOrder.Company AS Company,
	|	SalesOrder.CompanyVATNumber AS CompanyVATNumber,
	|	SalesOrder.StructuralUnitReserve AS StructuralUnit,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.Contract AS Contract,
	|	SalesOrder.ShippingAddress AS ShippingAddress,
	|	SalesOrder.ContactPerson AS ContactPerson,
	|	SalesOrder.Incoterms AS Incoterms,
	|	SalesOrder.DeliveryTimeFrom AS DeliveryTimeFrom,
	|	SalesOrder.DeliveryTimeTo AS DeliveryTimeTo,
	|	SalesOrder.GoodsMarking AS GoodsMarking,
	|	SalesOrder.LogisticsCompany AS LogisticsCompany,
	|	SalesOrder.DeliveryOption AS DeliveryOption
	|INTO TT_SalesOrders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref IN(&OrdersArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesOrders.BasisRef AS BasisRef,
	|	TT_SalesOrders.BasisPosted AS BasisPosted,
	|	TT_SalesOrders.Closed AS Closed,
	|	TT_SalesOrders.OrderState AS OrderState,
	|	TT_SalesOrders.Company AS Company,
	|	TT_SalesOrders.CompanyVATNumber AS CompanyVATNumber,
	|	TT_SalesOrders.StructuralUnit AS StructuralUnit,
	|	TT_SalesOrders.Counterparty AS Counterparty,
	|	TT_SalesOrders.Contract AS Contract,
	|	TT_SalesOrders.ShippingAddress AS ShippingAddress,
	|	TT_SalesOrders.ContactPerson AS ContactPerson,
	|	TT_SalesOrders.Incoterms AS Incoterms,
	|	TT_SalesOrders.DeliveryTimeFrom AS DeliveryTimeFrom,
	|	TT_SalesOrders.DeliveryTimeTo AS DeliveryTimeTo,
	|	TT_SalesOrders.GoodsMarking AS GoodsMarking,
	|	TT_SalesOrders.LogisticsCompany AS LogisticsCompany,
	|	TT_SalesOrders.DeliveryOption AS DeliveryOption
	|FROM
	|	TT_SalesOrders AS TT_SalesOrders
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	GoodsInvoicedNotShipped.SalesInvoice AS SalesInvoice
	|FROM
	|	TT_SalesOrders AS TT_SalesOrders
	|		INNER JOIN AccumulationRegister.GoodsInvoicedNotShipped AS GoodsInvoicedNotShipped
	|		ON TT_SalesOrders.BasisRef = GoodsInvoicedNotShipped.SalesOrder";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	QueryResults = Query.ExecuteBatch();
	
	Selection = QueryResults[1].Select();
	While Selection.Next() Do
		VerifiedAttributesValues = New Structure("OrderState, Closed, Posted",
			Selection.OrderState,
			Selection.Closed,
			Selection.BasisPosted);
		Documents.SalesOrder.CheckAbilityOfEnteringBySalesOrder(Selection.BasisRef, VerifiedAttributesValues);
	EndDo;
	
	FillPropertyValues(ThisObject, Selection);
	
	If IsDropShipping Then
		OperationType = Enums.OperationTypesGoodsIssue.DropShipping;
	EndIf;
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	
	If TypeOf(FillingData) = Type("Structure")
		And FillingData.Property("PackingSlip") Then
		DocumentData.Insert("PackingSlip", FillingData.PackingSlip);
		
		If Not Common.ObjectAttributeValue(FillingData.PackingSlip, "Posted") Then
			Raise NStr("en = 'Cannot generate documents from unposted documents. Post this document first. Then try again.'; ru = 'Создание документов на основании непроведенных документов запрещено. Проведите документ и повторите попытку.';pl = 'Nie można wygenerować dokumentów z niezatwierdzonych dokumentów. Najpierw zatwierdź ten dokument. Zatem spróbuj ponownie.';es_ES = 'No se han podido generar documentos desde los documentos no enviados. En primer lugar, envíe este documento. Inténtelo de nuevo.';es_CO = 'No se han podido generar documentos desde los documentos no enviados. En primer lugar, envíe este documento. Inténtelo de nuevo.';tr = 'Kaydedilmemiş belgelerden belge oluşturulamaz. Önce bu belgeyi kaydedip tekrar deneyin.';it = 'Impossibile creare i documenti dai documenti non pubblicati. Pubblicare prima questo documento, poi riprovare.';de = 'Fehler beim Generieren von Dokumenten aus nicht gebuchten Dokumenten. Buchen Sie dieses Dokument zuerst. Dann versuchen Sie erneut.'");	
		EndIf;
	EndIf;
	
	If TypeOf(FillingData) = Type("Structure") And FillingData.Property("OrderedProductsTable") Then
		FilterData = New Structure("OrdersArray, OrderedProductsTable", OrdersArray, FillingData.OrderedProductsTable);
		Documents.GoodsIssue.FillBySalesOrdersWithOrderedProducts(DocumentData, FilterData, Products);
	Else
		Documents.GoodsIssue.FillBySalesOrders(DocumentData, New Structure("OrdersArray", OrdersArray), Products, SerialNumbers, IsDropShipping);
	EndIf;
	
	// Bundles
	BundlesServer.FillAddedBundles(ThisObject, OrdersArray, , , "Products");
	// End Bundles
	
	InvoicesArray = QueryResults[2].Unload().UnloadColumn("SalesInvoice");
	If InvoicesArray.Count() Then
		
		InvoicedProducts = Products.UnloadColumns();
		Documents.GoodsIssue.FillBySalesInvoices(DocumentData, New Structure("InvoicesArray", InvoicesArray), InvoicedProducts);
		
		For Each InvoicedProductsRow In InvoicedProducts Do
			If Not OrdersArray.Find(InvoicedProductsRow.Order) = Undefined Then
				FillPropertyValues(Products.Add(), InvoicedProductsRow);
			EndIf;
		EndDo;
		
	EndIf;
	
	DiscountsAreCalculated = False;
	
	OrdersTable = Products.Unload(, "Order, Contract");
	OrdersTable.GroupBy("Order, Contract");
	If OrdersTable.Count() > 1 Then
		SalesOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(SalesOrderPosition) Then
			SalesOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InTabularSection Then
		Order = Undefined;
		Contract = Undefined;
	ElsIf Not ValueIsFilled(Order) AND OrdersTable.Count() > 0 Then
		Order = OrdersTable[0].Order;
		Contract = OrdersTable[0].Contract;
	EndIf;
	
	If TypeOf(FillingData) = Type("Structure")
		And FillingData.Property("PackingSlip")
		And (OrdersArray.Count() = 0 Or Not ValueIsFilled(Order)) Then
		Raise NStr("en = 'Cannot generate ""Goods issue"" from this Package slip. Package contents are inapplicable.
				|Ensure that they include only the items from Sales orders specified on the Main tab. Then try again.'; 
				|ru = 'Не удалось создать отпуск товаров на основании данного упаковочного листа. Содержимое упаковки недопустимо.
				|Убедитесь, что она включает только товары из заказов покупателей, указанных на вкладке ""Основные данные"", и повторите попытку.';
				|pl = 'Nie można wygenerować ""Wydanie zewnętrzne"" z tego Listu przewozowego. Zawartość opakowania nie ma zastosowania.
				|Upewnij się, że zawierają one tylko elementy z Zamówień sprzedaży, określonych na karcie Podstawowe. Zatem spróbuj ponownie.';
				|es_ES = 'No se puede generar la ""Salida de mercancías"" desde este Albarán de entrega. El contenido del albarán es inaplicable.
				|Asegúrese de que incluye sólo los artículos de los órdenes de venta especificadas en la pestaña Principal. Inténtelo de nuevo.';
				|es_CO = 'No se puede generar la ""Salida de mercancías"" desde este Albarán de entrega. El contenido del albarán es inaplicable.
				|Asegúrese de que incluye sólo los artículos de los órdenes de venta especificadas en la pestaña Principal. Inténtelo de nuevo.';
				|tr = 'Bu Sevk irsaliyesinden ""Ambar çıkışı"" oluşturulamıyor. Ambalaj içeriği uygulanamıyor.
				|Sadece Ana sekmede belirtilen Satış siparişlerindeki öğelerin içerildiğinden emin olup tekrar deneyin.';
				|it = 'Impossibile creare ""Spedizione merce/DDT"" da questa Bolla di accompagnamento. Il contenuto non è applicabile.
				|Assicurarsi che includa solo gli elementi dagli Ordini cliente nella scheda Principale, poi riprovare.';
				|de = 'Fehler beim Generieren von ""Warenausgang"" aus diesem Beipackzettel. Der Beipackinhalt ist nicht anwendbar.
				|Überprüfen Sie ob dieser nur die Artikel aus den Kundenaufträgen angegeben auf der Haupregisterkarte enthalten. Dann versuchen Sie erneut.'");
	EndIf;
	
	If Products.Count() = 0 Then
		If IsDropShipping Then
			MessageText = NStr(
				"en = 'Cannot generate ""Goods issue: Drop shipping"" from this Sales order. 
				|You can generate such Goods issues only 
				|from Sales orders including products with the Drop shipping checkbox selected.'; 
				|ru = 'Не удалось создать ""Отпуск товаров: Дропшиппинг"" на основании данного заказа покупателя. 
				|Вы можете создать такой отпуск товаров только 
				|на основании заказов покупателей, включающих товары, для которых установлен флажок ""Дропшиппинг"".';
				|pl = 'Nie można wygenerować ""Wydanie zewnętrzne: Dropshipping"" z tego Zamówienia sprzedaży. 
				|Można wygenerować takie wydana zewnętrzne tylko 
				|z Zamówień sprzedaży, które zawierają produkty z zaznaczonym polem wyboru Dropshipping.';
				|es_ES = 'No se puede generar la ""Salida de mercancías: Envío directo"" desde esta orden de venta. 
				|Sólo se pueden generar estas salidas de mercancías 
				|desde las órdenes de venta que incluyan productos con la casilla de verificación e Envío directo seleccionada.';
				|es_CO = 'No se puede generar la ""Salida de mercancías: Envío directo"" desde esta orden de venta. 
				|Sólo se pueden generar estas salidas de mercancías 
				|desde las órdenes de venta que incluyan productos con la casilla de verificación e Envío directo seleccionada.';
				|tr = 'Bu Satış siparişinden ""Ambar çıkışı: Stoksuz satış"" oluşturulamıyor. 
				|Bu tür Ambar çıkışları sadece, Stoksuz satış onay kutusu 
				|seçili ürünler içeren Satış siparişlerinden oluşturulabilir.';
				|it = 'Impossibile generare ""Spedizione merce/DDT: Dropshipping"" da questo Ordine cliente.
				| è possibile generare queste spedizioni merci solo 
				|da Ordini cliente che includano articoli con la casella di controllo Dropshipping selezionata.';
				|de = 'Fehler beim Generieren von ""Warenausgang: Streckengeschäft"" aus diesem Kundenauftrag. 
				|Sie können so einen Warenausgang nur aus 
				| Kundenaufträgen orders mit Produkten mit dem aktivierten Kontrollkästchen Streckengeschäft generieren.'");
		Else
			If OrdersArray.Count() = 1 Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 has already been shipped.'; ru = 'Уже отгружено: %1';pl = '%1 został już wysłany.';es_ES = '%1 ha sido enviado ya.';es_CO = '%1 ha sido enviado ya.';tr = '%1 zaten gönderildi.';it = '%1 è stato già spedito.';de = '%1 wurde bereits versandt.'"),
				Order);
			Else
				MessageText = NStr("en = 'The selected orders have already been shipped.'; ru = 'Выбранные заказы уже отгружены';pl = 'Wybrane zamówienia zostały już wysłane.';es_ES = 'Las órdenes seleccionadas han sido envidas ya.';es_CO = 'Las órdenes seleccionadas han sido envidas ya.';tr = 'Seçilen siparişler zaten gönderildi.';it = 'Gli ordini selezionati sono già stati spediti.';de = 'Die ausgewählten Bestellungen wurden bereits versandt.'");
			EndIf;
		EndIf;
		Raise MessageText;
	EndIf;
	
EndProcedure

Procedure FillBySalesInvoice(FillingData) Export
	
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfSalesInvoices") Then
		InvoicesArray = FillingData.ArrayOfSalesInvoices;
	Else
		InvoicesArray = New Array;
		InvoicesArray.Add(FillingData);
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	SalesInvoice.Ref AS BasisRef,
	|	SalesInvoice.Posted AS BasisPosted,
	|	SalesInvoice.Company AS Company,
	|	SalesInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	SalesInvoice.StructuralUnit AS StructuralUnit,
	|	SalesInvoice.Counterparty AS Counterparty,
	|	SalesInvoice.Contract AS Contract,
	|	SalesInvoice.ShippingAddress AS ShippingAddress,
	|	SalesInvoice.ContactPerson AS ContactPerson,
	|	SalesInvoice.Incoterms AS Incoterms,
	|	SalesInvoice.DeliveryTimeFrom AS DeliveryTimeFrom,
	|	SalesInvoice.DeliveryTimeTo AS DeliveryTimeTo,
	|	SalesInvoice.GoodsMarking AS GoodsMarking,
	|	SalesInvoice.LogisticsCompany AS LogisticsCompany,
	|	SalesInvoice.DeliveryOption AS DeliveryOption,
	|	SalesInvoice.Cell AS Cell
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref IN(&InvoicesArray)";
	
	Query.SetParameter("InvoicesArray", InvoicesArray);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	FillPropertyValues(ThisObject, Selection);
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	
	Documents.GoodsIssue.FillBySalesInvoices(DocumentData, New Structure("InvoicesArray", InvoicesArray), Products);
	
	DiscountsAreCalculated = False;
	
	// Bundles
	BundlesServer.FillAddedBundles(ThisObject, InvoicesArray, , , "Products");
	// End Bundles
	
	OrdersTable = Products.Unload(, "Order, Contract");
	OrdersTable.GroupBy("Order, Contract");
	If OrdersTable.Count() > 1 Then
		SalesOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(SalesOrderPosition) Then
			SalesOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InTabularSection Then
		Order = Undefined;
		Contract = Undefined;
	ElsIf Not ValueIsFilled(Order) AND OrdersTable.Count() > 0 Then
		Order = OrdersTable[0].Order;
		Contract = OrdersTable[0].Contract;
	EndIf;
	
	If Products.Count() = 0 Then
		If InvoicesArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 has already been shipped.'; ru = 'Уже отгружено: %1';pl = '%1 został już wysłany.';es_ES = '%1 ha sido enviado ya.';es_CO = '%1 ha sido enviado ya.';tr = '%1 zaten gönderildi.';it = '%1 è stato già spedito.';de = '%1 wurde bereits versandt.'"),
				InvoicesArray[0]);
		Else
			MessageText = NStr("en = 'The selected invoices have already been shipped.'; ru = 'Товар по выбранным инвойсам уже отгружен.';pl = 'Wybrane faktury zostały już wysłane.';es_ES = 'Las facturas seleccionadas han sido envidas ya.';es_CO = 'Las facturas seleccionadas han sido envidas ya.';tr = 'Seçilen faturalar zaten gönderildi.';it = 'Le fatture selezionate sono già state spedite.';de = 'Die ausgewählten Rechnungen wurden bereits versandt.'");
		EndIf;
		Raise MessageText;
	EndIf;
	
	IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInDocument(ThisObject, InvoicesArray);
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, InvoicesArray);
	EndIf;
	
EndProcedure

Procedure FillByPurchaseOrder(FillingData) Export
	
	If DriveReUse.AttributeInHeader("SalesOrderPositionInShipmentDocuments") Then
		Order = FillingData.Ref;
	Else
		Order = Undefined;
	EndIf;
	
	// Header filling.
	AttributeValues = Common.ObjectAttributesValues(FillingData,
			New Structure("Company, OperationKind, StructuralUnitReserve, Counterparty, Contract, OrderState, Closed, Posted"));
			
	AttributeValues.Insert("GoodsIssue");
	Documents.PurchaseOrder.CheckEnteringAbilityOnTheBasisOfVendorOrder(FillingData, AttributeValues);
	
	FillPropertyValues(ThisObject, AttributeValues, "Company, Counterparty, Contract");
	
	// Tabular section filling.
	Products.Clear();
	If FillingData.OperationKind = Enums.OperationTypesPurchaseOrder.OrderForProcessing Then
		OperationType	= Enums.OperationTypesGoodsIssue.TransferToAThirdParty;
		StructuralUnit	= AttributeValues.StructuralUnitReserve;
		FillByPurchaseOrderForProcessing(FillingData);
	EndIf;
	
EndProcedure

Procedure FillByPurchaseOrderForProcessing(FillingData)
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	MIN(OrdersBalance.LineNumber) AS LineNumber,
	|	CASE
	|		WHEN OrdersBalance.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ProductsTypeInventory,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	OrdersBalance.MeasurementUnit AS MeasurementUnit,
	|	OrdersBalance.Order AS Order,
	|	SUM(OrdersBalance.Quantity) AS Quantity
	|FROM
	|	(SELECT
	|		PurchaseOrderMaterials.LineNumber AS LineNumber,
	|		PurchaseOrderMaterials.Products AS Products,
	|		PurchaseOrderMaterials.Characteristic AS Characteristic,
	|		PurchaseOrderMaterials.MeasurementUnit AS MeasurementUnit,
	|		PurchaseOrderMaterials.Ref AS Order,
	|		PurchaseOrderMaterials.Quantity AS Quantity
	|	FROM
	|		Document.PurchaseOrder.Materials AS PurchaseOrderMaterials
	|	WHERE
	|		PurchaseOrderMaterials.Ref = &BasisDocument
	|		AND PurchaseOrderMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		SupplierInvoiceInventory.LineNumber,
	|		SupplierInvoiceInventory.Products,
	|		SupplierInvoiceInventory.Characteristic,
	|		SupplierInvoiceInventory.MeasurementUnit,
	|		SupplierInvoiceInventory.Order,
	|		SupplierInvoiceInventory.Quantity
	|	FROM
	|		Document.GoodsReceipt.Products AS SupplierInvoiceInventory
	|	WHERE
	|		SupplierInvoiceInventory.Ref.Posted
	|		AND SupplierInvoiceInventory.Ref.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
	|		AND SupplierInvoiceInventory.Order = &BasisDocument
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		SalesInvoiceInventory.LineNumber,
	|		SalesInvoiceInventory.Products,
	|		SalesInvoiceInventory.Characteristic,
	|		SalesInvoiceInventory.MeasurementUnit,
	|		SalesInvoiceInventory.Order,
	|		-SalesInvoiceInventory.Quantity
	|	FROM
	|		Document.GoodsIssue.Products AS SalesInvoiceInventory
	|	WHERE
	|		SalesInvoiceInventory.Ref.Posted
	|		AND SalesInvoiceInventory.Ref.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
	|		AND SalesInvoiceInventory.Order = &BasisDocument
	|		AND NOT SalesInvoiceInventory.Ref = &Ref) AS OrdersBalance
	|
	|GROUP BY
	|	CASE
	|		WHEN OrdersBalance.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic,
	|	OrdersBalance.MeasurementUnit,
	|	OrdersBalance.Order
	|
	|HAVING
	|	SUM(OrdersBalance.Quantity) > 0";
	
	Query.SetParameter("BasisDocument",	FillingData);
	Query.SetParameter("Ref",			Ref);
	
	QueryResult = Query.Execute();
	Products.Load(QueryResult.Unload());
	
EndProcedure

Procedure FillBySupplierInvoice(FillingData) Export
	
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfSupplierInvoices") Then
		InvoicesArray = FillingData.ArrayOfSupplierInvoices;
	Else
		InvoicesArray = New Array;
		InvoicesArray.Add(FillingData);
	EndIf;
	
	IsDropShipping = False;
	If GetFunctionalOption("UseDropShipping") And FillingData.Property("OperationType") 
		And FillingData.OperationType = Enums.OperationTypesGoodsIssue.DropShipping Then
		StructureDropShippingData = Documents.SupplierInvoice.GetDropShippingData(InvoicesArray[0]);
		IsDropShipping = True;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SupplierInvoice.Ref AS BasisRef,
	|	SupplierInvoice.Posted AS BasisPosted,
	|	SupplierInvoice.Company AS Company,
	|	SupplierInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	SupplierInvoice.StructuralUnit AS StructuralUnit,
	|	SupplierInvoice.Cell AS Cell
	|INTO TT_Invoices
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Ref IN(&InvoicesArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Invoices.BasisRef AS BasisRef,
	|	TT_Invoices.BasisPosted AS BasisPosted,
	|	TT_Invoices.Company AS Company,
	|	TT_Invoices.CompanyVATNumber AS CompanyVATNumber,
	|	TT_Invoices.StructuralUnit AS StructuralUnit,
	|	TT_Invoices.Cell AS Cell
	|FROM
	|	TT_Invoices AS TT_Invoices
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TT_Invoices.StructuralUnit AS StructuralUnit
	|FROM
	|	TT_Invoices AS TT_Invoices";
	
	Query.SetParameter("InvoicesArray", InvoicesArray);
	
	QueryResults = Query.ExecuteBatch();
	
	Selection = QueryResults[1].Select();
	Selection.Next();
	FillPropertyValues(ThisObject, Selection);
	
	If IsDropShipping Then
		FillPropertyValues(ThisObject, StructureDropShippingData);
	EndIf;
	
	StructuralUnitSelection = QueryResults[2].Select();
	
	If StructuralUnitSelection.Count() > 1 OR Not ValueIsFilled(StructuralUnit) Then
		
		SettingValue = DriveReUse.GetValueOfSetting("MainWarehouse");
		If Not ValueIsFilled(SettingValue) Then
			StructuralUnit = Catalogs.BusinessUnits.MainWarehouse;
		EndIf;
	
	EndIf;

	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	
	Documents.GoodsIssue.FillBySupplierInvoices(ThisObject, DocumentData, New Structure("InvoicesArray", InvoicesArray), Products, SerialNumbers);
	
	IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInDocument(ThisObject, InvoicesArray);
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, InvoicesArray);
	EndIf;
	
EndProcedure

Procedure FillReturnBySupplierInvoice(FillingData) Export
	
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfSupplierInvoices") Then
		InvoicesArray = FillingData.ArrayOfSupplierInvoices;
	Else
		InvoicesArray = New Array;
		InvoicesArray.Add(FillingData);
		Order = FillingData;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	SupplierInvoice.Ref AS BasisRef,
	|	SupplierInvoice.Posted AS BasisPosted,
	|	SupplierInvoice.Company AS Company,
	|	SupplierInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	SupplierInvoice.StructuralUnit AS StructuralUnit,
	|	SupplierInvoice.Counterparty AS Counterparty,
	|	SupplierInvoice.Contract AS Contract,
	|	SupplierInvoice.VATTaxation AS VATTaxation,
	|	VALUE(Enum.OperationTypesGoodsIssue.PurchaseReturn) AS OperationType,
	|	SupplierInvoice.DocumentCurrency AS DocumentCurrency,
	|	SupplierInvoice.ExchangeRate AS ExchangeRate,
	|	SupplierInvoice.Multiplicity AS Multiplicity,
	|	SupplierInvoice.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	SupplierInvoice.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	SupplierInvoice.Cell AS Cell
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Ref IN(&InvoicesArray)";
	
	Query.SetParameter("InvoicesArray", InvoicesArray);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	FillPropertyValues(ThisObject, Selection);
	
	If Not ValueIsFilled(StructuralUnit) Then
		SettingValue = DriveReUse.GetValueOfSetting("MainWarehouse");
		If Not ValueIsFilled(SettingValue) Then
			StructuralUnit = Catalogs.BusinessUnits.MainWarehouse;
		EndIf;
	EndIf;
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	
	Documents.GoodsIssue.FillReturnBySupplierInvoices(DocumentData, New Structure("InvoicesArray", InvoicesArray), Products);
	
	OrdersTable = Products.Unload(, "Order, Contract");
	OrdersTable.GroupBy("Order, Contract");
	If OrdersTable.Count() > 1 Then
		PurchaseOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		PurchaseOrderPosition = DriveReUse.GetValueOfSetting("PurchaseOrderPositionInReceiptDocuments");
		If Not ValueIsFilled(PurchaseOrderPosition) Then
			PurchaseOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	EndIf;
	
	If PurchaseOrderPosition = Enums.AttributeStationing.InTabularSection Then
		Order = Undefined;
		Contract = Undefined;
	ElsIf Not ValueIsFilled(Order) AND OrdersTable.Count() > 0 Then
		Order = OrdersTable[0].Order;
		Contract = OrdersTable[0].Contract;
	EndIf;
	
	If Products.Count() = 0 Then
		If InvoicesArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The goods in %1 have already been returned.'; ru = 'Товары в %1 уже возвращены.';pl = 'Towary w %1 już zostali zwrócone.';es_ES = 'Los productos %1 han sido devueltos ya.';es_CO = 'Los productos %1 han sido devueltos ya.';tr = '%1 bölümündeki mallar zaten iade edildi.';it = 'Le merci in %1 sono già state restituite.';de = 'Die Ware in %1 wurde bereits zurückgeschickt.'"),
				InvoicesArray[0]);
		Else
			MessageText = NStr("en = 'The goods in the selected invoices have already been returned.'; ru = 'Товары по выбранным инвойсам уже возвращены.';pl = 'Towary w wybranych fakturach już zostali zwrócone.';es_ES = 'Las mercancías de las facturas seleccionadas han sido devueltos ya.';es_CO = 'Los productos de las facturas seleccionadas han sido devueltos ya.';tr = 'Seçilen faturalardaki mallar zaten iade edildi.';it = 'Le merci nelle fatture selezionate sono già state restituite.';de = 'Die Ware in den ausgewählten Rechnungen wurde bereits zurückgeschickt.'");
		EndIf;
		Raise MessageText;
	EndIf;
	
EndProcedure

Procedure FillByGoodsReceipt(FillingData) Export
	
	IsDropShipping	= (FillingData.OperationType = Enums.OperationTypesGoodsReceipt.DropShipping);
	
	StructureDataDropShipping = Documents.GoodsReceipt.GetStructureDataForDropShipping(FillingData);
	
	BasisDocument	= FillingData;
	Company			= FillingData.Company;
	CompanyVATNumber= FillingData.CompanyVATNumber;
	
	If IsDropShipping Then
		Counterparty	= StructureDataDropShipping.Counterparty;
		Contract		= StructureDataDropShipping.Contract;
	Else
		Counterparty	= FillingData.Counterparty;
		Contract		= FillingData.Contract;
	EndIf;
	
	StructuralUnit	= FillingData.StructuralUnit;
	Cell			= FillingData.Cell;
	VATTaxation		= FillingData.VATTaxation;
	
	If FillingData.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer Then
		OperationType = Enums.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer;
		Order = FillingData.Order;
	ElsIf IsDropShipping Then
		OperationType = Enums.OperationTypesGoodsIssue.DropShipping;
		Order = StructureDataDropShipping.RefSalesOrder;
	Else
		OperationType = Enums.OperationTypesGoodsIssue.ReturnToAThirdParty;
	EndIf;
	
	StructureData = New Structure;
	ObjectParameters = New Structure;
	ObjectParameters.Insert("Company", Company);
	ObjectParameters.Insert("StructuralUnit", StructuralUnit);
	StructureData.Insert("ObjectParameters", ObjectParameters);
	
	Products.Clear();
	For Each TabularSectionRow In FillingData.Products Do
		
		NewRow = Products.Add();
		FillPropertyValues(NewRow, TabularSectionRow);
		
		NewRow.Order = Undefined;
		
	EndDo;

	IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInDocument(ThisObject, FillingData);
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
	WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(ThisObject, FillingData, "Products");

EndProcedure

Procedure FillByDebitNote(FillingData) Export
	
	// Document basis and document setting.
	DebitNotesArray = New Array;
	Contract = Undefined;
	
	If TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("ArrayOfDebitNotes") Then
		
		For Each ArrayItem In FillingData.ArrayOfDebitNotes Do
			Contract = ArrayItem.Contract;
			DebitNotesArray.Add(ArrayItem.Ref);
		EndDo;
		
		DebitNote = DebitNotesArray[0];
		
	Else
		DebitNotesArray.Add(FillingData.Ref);
		DebitNote = FillingData;
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	DebitNote.Ref AS BasisRef,
	|	DebitNote.Posted AS BasisPosted,
	|	DebitNote.Company AS Company,
	|	DebitNote.CompanyVATNumber AS CompanyVATNumber,
	|	DebitNote.StructuralUnit AS StructuralUnit,
	|	DebitNote.Cell AS Cell,
	|	DebitNote.Contract AS Contract,
	|	DebitNote.Counterparty AS Counterparty,
	|	DebitNote.OperationKind AS OperationKind,
	|	DebitNote.VATTaxation AS VATTaxation,
	|	DebitNote.DocumentCurrency AS DocumentCurrency,
	|	DebitNote.ExchangeRate AS ExchangeRate,
	|	DebitNote.Multiplicity AS Multiplicity,
	|	DebitNote.AmountIncludesVAT AS AmountIncludesVAT
	|INTO DebitNoteHeader
	|FROM
	|	Document.DebitNote AS DebitNote
	|WHERE
	|	DebitNote.Ref IN(&DebitNotesArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	DebitNoteHeader.BasisRef AS BasisRef,
	|	DebitNoteHeader.BasisPosted AS BasisPosted,
	|	DebitNoteHeader.Company AS Company,
	|	DebitNoteHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DebitNoteHeader.StructuralUnit AS StructuralUnit,
	|	DebitNoteHeader.Cell AS Cell,
	|	DebitNoteHeader.Counterparty AS Counterparty,
	|	DebitNoteHeader.Contract AS Contract,
	|	DebitNoteHeader.OperationKind AS OperationKind,
	|	DebitNoteProducts.VATRate AS VATRate,
	|	DebitNoteProducts.VATAmount AS VATAmount,
	|	DebitNoteHeader.DocumentCurrency AS DocumentCurrency,
	|	DebitNoteHeader.ExchangeRate AS ExchangeRate,
	|	DebitNoteHeader.Multiplicity AS Multiplicity,
	|	DebitNoteHeader.VATTaxation AS VATTaxation,
	|	DebitNoteHeader.AmountIncludesVAT AS AmountIncludesVAT
	|INTO DebitNotesFiltred
	|FROM
	|	DebitNoteHeader AS DebitNoteHeader
	|		LEFT JOIN Document.DebitNote.Inventory AS DebitNoteProducts
	|		ON DebitNoteHeader.BasisRef = DebitNoteProducts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DebitNotesFiltred.BasisRef AS BasisRef,
	|	DebitNotesFiltred.BasisPosted AS BasisPosted,
	|	DebitNotesFiltred.Company AS Company,
	|	DebitNotesFiltred.CompanyVATNumber AS CompanyVATNumber,
	|	DebitNotesFiltred.StructuralUnit AS StructuralUnit,
	|	DebitNotesFiltred.Cell AS Cell,
	|	DebitNotesFiltred.Counterparty AS Counterparty,
	|	DebitNotesFiltred.Contract AS Contract,
	|	DebitNotesFiltred.DocumentCurrency AS DocumentCurrency,
	|	DebitNotesFiltred.VATTaxation AS VATTaxation,
	|	DebitNotesFiltred.AmountIncludesVAT AS AmountIncludesVAT,
	|	DebitNotesFiltred.ExchangeRate AS ExchangeRate,
	|	DebitNotesFiltred.Multiplicity AS Multiplicity,
	|	CC_Rates.Rate AS ContractCurrencyExchangeRate,
	|	CC_Rates.Repetition AS ContractCurrencyMultiplicity,
	|	DebitNotesFiltred.OperationKind AS OperationKind,
	|	DebitNotesFiltred.VATRate AS VATRate,
	|	DebitNotesFiltred.VATAmount AS VATAmount
	|FROM
	|	DebitNotesFiltred AS DebitNotesFiltred
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DebitNotesFiltred.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS CC_Rates
	|		ON (Contracts.SettlementsCurrency = CC_Rates.Currency)
	|			AND DebitNotesFiltred.Company = CC_Rates.Company";
	
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("DebitNotesArray", DebitNotesArray);
	Query.SetParameter("Contract", Contract);
	
	ResultTable = Query.Execute().Unload();
	For Each TableRow In ResultTable Do
		Documents.GoodsIssue.CheckAbilityOfEnteringByGoodsIssue(ThisObject, TableRow.BasisRef, TableRow.BasisPosted, TableRow.OperationKind);
	EndDo;
	
	If ResultTable.Count() > 0 Then
		TableRow = ResultTable[0];
	EndIf;
	
	OperationType = Enums.OperationTypesGoodsIssue.PurchaseReturn;
	FillPropertyValues(ThisObject, TableRow);
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Date", CurrentSessionDate());
	DocumentData.Insert("DocumentCurrency", DocumentCurrency);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("AmountIncludesVAT", AmountIncludesVAT);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	    
	FilterData = New Structure("DebitNotesArray, Contract", DebitNotesArray, Contract);
	
	Documents.GoodsIssue.FillByDebitNotes(DocumentData, FilterData, Products);
	
	OrdersTable = Products.Unload(, "Order, Contract");
	OrdersTable.GroupBy("Order, Contract");
	If OrdersTable.Count() > 1 Then
		PurchaseOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		PurchaseOrderPosition = DriveReUse.GetValueOfSetting("PurchaseOrderPositionInReceiptDocuments");
		If Not ValueIsFilled(PurchaseOrderPosition) Then
			PurchaseOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	EndIf;
	
	If PurchaseOrderPosition = Enums.AttributeStationing.InTabularSection Then
		Order = Undefined;
		Contract = Undefined;
	ElsIf Not ValueIsFilled(Order) AND OrdersTable.Count() > 0 Then
		Order = OrdersTable[0].Order;
		Contract = OrdersTable[0].Contract;
	EndIf;
	
	If Products.Count() = 0 Then
		If DebitNotesArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 has already been issued.'; ru = 'Уже выдано: %1.';pl = '%1 został już wydany.';es_ES = '%1 ya se ha emitido.';es_CO = '%1 ya se ha emitido.';tr = '%1 zaten çıkarıldı.';it = '%1 è già stato emesso.';de = ' %1 wurde bereits ausgestellt.'"),
				DebitNote);
		Else
			MessageText = NStr("en = 'The selected debit notes have already been issued.'; ru = 'Выбранные дебетовые авизо уже выданы.';pl = 'Wybrane noty debetowe już zostały wydane.';es_ES = 'Ya se han emitido las notas de cargo seleccionadas.';es_CO = 'Ya se han emitido las notas de cargo seleccionadas.';tr = 'Seçilen borç dekontları zaten düzenlendi. ';it = 'Le note di debito selezionate sono già state emesse.';de = 'Die ausgewählten Lastschriften sind bereits ausgestellt.'");
		EndIf;
		CommonClientServer.MessageToUser(MessageText, Ref);
	EndIf;
	
EndProcedure

Procedure FillByStructure(FillingData) Export
	
	If FillingData.Property("ArrayOfSalesOrders") Then
		FillBySalesOrder(FillingData);
	EndIf;
	
	If FillingData.Property("ArrayOfSalesInvoices") Then
		FillBySalesInvoice(FillingData);
	EndIf;
	
	If FillingData.Property("ArrayOfSupplierInvoices")
		And (FillingData.OperationType = Enums.OperationTypesGoodsIssue.SaleToCustomer
		Or FillingData.OperationType = Enums.OperationTypesGoodsIssue.DropShipping) Then
		FillBySupplierInvoice(FillingData);
	ElsIf FillingData.Property("ArrayOfSupplierInvoices")
		And FillingData.OperationType = Enums.OperationTypesGoodsIssue.PurchaseReturn Then
		FillReturnBySupplierInvoice(FillingData);
	EndIf;
	
	If FillingData.Property("ArrayOfDebitNotes") Then
		FillByDebitNote(FillingData);
	EndIf;
	
	// begin Drive.FullVersion
	If FillingData.Property("OperationType") And FillingData.Property("SubcontractorOrderReceived") Then
		
		If FillingData.OperationType = Enums.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer Then
			FillBySubcontractorOrderReceivedReturn(FillingData.SubcontractorOrderReceived);
		ElsIf FillingData.OperationType = Enums.OperationTypesGoodsIssue.TransferToSubcontractingCustomer Then
			FillBySubcontractorOrderReceivedTransfer(FillingData.SubcontractorOrderReceived);
		EndIf;
		
	EndIf;
	// end Drive.FullVersion 
	
EndProcedure

Procedure FillBySubcontractorOrderIssued(FillingData) Export
	
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfSubcontractorOrders") Then
		OrdersArray = FillingData.ArrayOfSubcontractorOrders;
	Else
		OrdersArray = New Array;
		OrdersArray.Add(FillingData);
		Order = FillingData;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SubcontractorOrderIssued.Ref AS Order,
	|	SubcontractorOrderIssued.Company AS Company,
	|	SubcontractorOrderIssued.CompanyVATNumber AS CompanyVATNumber,
	|	SubcontractorOrderIssued.StructuralUnit AS StructuralUnit,
	|	SubcontractorOrderIssued.Counterparty AS Counterparty,
	|	SubcontractorOrderIssued.Contract AS Contract,
	|	VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractor) AS OperationType
	|FROM
	|	Document.SubcontractorOrderIssued AS SubcontractorOrderIssued
	|WHERE
	|	SubcontractorOrderIssued.Ref IN (&OrdersArray)";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	FillPropertyValues(ThisObject, Selection);
	
	Documents.GoodsIssue.FillBySubcontractorOrders(
		New Structure("Ref", Ref),
		New Structure("OrdersArray", OrdersArray),
		Products);
	
	If Products.Count() = 0 Then
		If OrdersArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Goods issues have already been posted for all components specified in the %1'; ru = 'Отпуск товаров уже был проведен для всех компонентов, указанных в %1';pl = 'Wydania zewnętrzne już zostały pomyślnie zatwierdzone dla wszystkich komponentów określonych w %1';es_ES = 'Ya se han contabilizado las salidas de mercancías de todos los componentes especificados en el %1';es_CO = 'Ya se han contabilizado las salidas de mercancías de todos los componentes especificados en el %1';tr = '%1''de belirtilen tüm malzemeler için ambar çıkışları zaten kaydedildi';it = 'I documenti di trasporto sono già stati pubblicati per tutte le componenti specificate in %1';de = 'Warenausgang wurde bereits für alle in %1 angegebenen Komponenten gebucht'"),
				OrdersArray[0]);
		Else
			MessageText = NStr("en = 'Goods issues have already been posted for all components specified in the selected Subcontractor orders.'; ru = 'Отпуск товаров уже был проведен для всех компонентов, указанных в выбранных заказах на переработку.';pl = 'Wydania zewnętrzne już zostały pomyślnie zatwierdzone dla wszystkich komponentów określonych w wybranych Zamówieniach podwykonawcy.';es_ES = 'Ya se han contabilizado las salidas de mercancías de todos los componentes especificados en las órdenes del subcontratista seleccionado.';es_CO = 'Ya se han contabilizado las salidas de mercancías de todos los componentes especificados en las órdenes del subcontratista seleccionado.';tr = 'Seçilen alt yüklenici siparişlerinde belirtilen tüm malzemeler için ambar çıkışları zaten kaydedildi.';it = 'I documenti di trasporto sono già stati pubblicati per tutte le componenti specificate negli Ordini di subfornitura selezionati.';de = 'Warenausgang wurde bereits für alle in den ausgewählten Subunternehmeraufträgen angegebenen Komponenten gebucht.'");
		EndIf;
		CommonClientServer.MessageToUser(MessageText, Ref);
	EndIf;
	
	IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInDocument(ThisObject, OrdersArray);
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, OrdersArray);
	EndIf;
	
EndProcedure

// begin Drive.FullVersion
Procedure FillByProduction(FillingData) Export
	
	Query = New Query();
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT ALLOWED
	|	&Ref AS BasisDocument,
	|	Production.Company AS Company,
	|	Production.ProductsStructuralUnit AS StructuralUnit,
	|	Production.Cell AS Cell,
	|	Production.SalesOrder AS Order
	|INTO ProductionHeader
	|FROM
	|	Document.Production AS Production
	|WHERE
	|	Production.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionHeader.BasisDocument AS BasisDocument,
	|	ProductionHeader.Company AS Company,
	|	ProductionHeader.StructuralUnit AS StructuralUnit,
	|	ProductionHeader.Cell AS Cell,
	|	ProductionHeader.Order AS Order
	|FROM
	|	ProductionHeader AS ProductionHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ProductionProducts.LineNumber AS LineNumber,
	|	ProductionProducts.Products AS Products,
	|	ProductionProducts.Characteristic AS Characteristic,
	|	ProductionProducts.Batch AS Batch,
	|	ProductionProducts.Quantity AS Quantity,
	|	ProductionProducts.MeasurementUnit AS MeasurementUnit,
	|	ProductionProducts.SerialNumbers AS SerialNumbers,
	|	ProductionProducts.ConnectionKey AS ConnectionKey,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryReceivedGLAccount
	|FROM
	|	ProductionHeader AS ProductionHeader
	|		INNER JOIN Document.Production.Products AS ProductionProducts
	|		ON ProductionHeader.BasisDocument = ProductionProducts.Ref";
	
	If FillingData.OperationKind = Enums.OperationTypesProduction.Disassembly Then
		Query.Text = StrReplace(Query.Text, "Production.Products", "Production.Inventory");
	EndIf;

	ResultArray = Query.ExecuteBatch();
	
	If ResultArray[1].IsEmpty() Then
		Return;
	EndIf;
	
	SelectionHeader = ResultArray[1].Select();
	SelectionHeader.Next();
	FillPropertyValues(ThisObject, SelectionHeader);
	
	Products.Load(ResultArray[2].Unload());
	
	WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(
		ThisObject, FillingData, "Products", "SerialNumbersProducts");
		
	IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInDocument(ThisObject, FillingData);
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
EndProcedure

Procedure FillByManufacturing(FillingData) Export
	
	Query = New Query();
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT ALLOWED
	|	&Ref AS BasisDocument,
	|	Production.Company AS Company,
	|	Production.ProductsStructuralUnit AS StructuralUnit,
	|	Production.Cell AS Cell,
	|	SubcontractorOrderReceived.Ref AS Order,
	|	CASE
	|		WHEN VALUETYPE(Production.SalesOrder) = TYPE(Document.SubcontractorOrderReceived)
	|			THEN VALUE(Enum.OperationTypesGoodsIssue.TransferToSubcontractingCustomer)
	|		ELSE VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|	END AS OperationType,
	|	ISNULL(SubcontractorOrderReceived.Counterparty, VALUE(Catalog.Counterparties.EmptyRef)) AS Counterparty,
	|	ISNULL(SubcontractorOrderReceived.Contract, VALUE(Catalog.CounterpartyContracts.EmptyRef)) AS Contract
	|INTO ProductionHeader
	|FROM
	|	Document.Manufacturing AS Production
	|		LEFT JOIN Document.SubcontractorOrderReceived AS SubcontractorOrderReceived
	|		ON Production.SalesOrder = SubcontractorOrderReceived.Ref
	|WHERE
	|	Production.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionHeader.BasisDocument AS BasisDocument,
	|	ProductionHeader.Company AS Company,
	|	ProductionHeader.StructuralUnit AS StructuralUnit,
	|	ProductionHeader.Cell AS Cell,
	|	ProductionHeader.Order AS Order,
	|	ProductionHeader.OperationType AS OperationType,
	|	ProductionHeader.Counterparty AS Counterparty,
	|	ProductionHeader.Contract AS Contract
	|FROM
	|	ProductionHeader AS ProductionHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ProductionProducts.LineNumber AS LineNumber,
	|	ProductionProducts.Products AS Products,
	|	ProductionProducts.Characteristic AS Characteristic,
	|	ProductionProducts.Batch AS Batch,
	|	ProductionProducts.Quantity AS Quantity,
	|	ProductionProducts.MeasurementUnit AS MeasurementUnit,
	|	ProductionProducts.SerialNumbers AS SerialNumbers,
	|	ProductionProducts.ConnectionKey AS ConnectionKey,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryReceivedGLAccount
	|FROM
	|	ProductionHeader AS ProductionHeader
	|		INNER JOIN Document.Manufacturing.Products AS ProductionProducts
	|		ON ProductionHeader.BasisDocument = ProductionProducts.Ref";
	
	ResultArray = Query.ExecuteBatch();
	
	If ResultArray[1].IsEmpty() Then
		Return;
	EndIf;
	
	SelectionHeader = ResultArray[1].Select();
	SelectionHeader.Next();
	FillPropertyValues(ThisObject, SelectionHeader);
	
	Products.Load(ResultArray[2].Unload());
	
	WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(
		ThisObject, FillingData, "Products", "SerialNumbersProducts");
		
	IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInDocument(ThisObject, FillingData);
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
EndProcedure

Procedure FillBySubcontractorOrderReceived(FillingData) Export
	
	If OperationType = Enums.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer Then
		FillBySubcontractorOrderReceivedReturn(FillingData);
	ElsIf OperationType = Enums.OperationTypesGoodsIssue.TransferToSubcontractingCustomer Then
		FillBySubcontractorOrderReceivedTransfer(FillingData)
	EndIf;
	
EndProcedure

Procedure FillBySubcontractorOrderReceivedReturn(FillingData)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SubcontractComponentsBalance.SubcontractorOrder AS SubcontractorOrder,
	|	SubcontractorOrderReceived.Company AS Company,
	|	SubcontractorOrderReceived.Counterparty AS Counterparty,
	|	SubcontractorOrderReceived.Contract AS Contract,
	|	SubcontractComponentsBalance.Products AS Products,
	|	SubcontractComponentsBalance.Characteristic AS Characteristic,
	|	SubcontractComponentsBalance.QuantityBalance AS Quantity
	|INTO TT_SubcontractComponentsBalances
	|FROM
	|	Document.SubcontractorOrderReceived AS SubcontractorOrderReceived
	|		INNER JOIN AccumulationRegister.SubcontractComponents.Balance AS SubcontractComponentsBalance
	|		ON SubcontractorOrderReceived.Ref = SubcontractComponentsBalance.SubcontractorOrder
	|			AND (SubcontractorOrderReceived.Ref = &Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractComponents.SubcontractorOrder AS SubcontractorOrder,
	|	SubcontractComponents.Company AS Company,
	|	SubcontractComponents.Products AS Products,
	|	SubcontractComponents.Characteristic AS Characteristic,
	|	ISNULL(InventoryOwnership.Ref, VALUE(Catalog.InventoryOwnership.EmptyRef)) AS Ownership,
	|	SubcontractComponents.Quantity AS Quantity
	|INTO TT_CustomerProvidedInventory
	|FROM
	|	TT_SubcontractComponentsBalances AS SubcontractComponents
	|		LEFT JOIN Catalog.InventoryOwnership AS InventoryOwnership
	|		ON SubcontractComponents.Counterparty = InventoryOwnership.Counterparty
	|			AND SubcontractComponents.Contract = InventoryOwnership.Contract
	|			AND (InventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_CustomerProvidedInventory.Products AS Products,
	|	TT_CustomerProvidedInventory.Characteristic AS Characteristic,
	|	TT_CustomerProvidedInventory.Products.MeasurementUnit AS MeasurementUnit,
	|	TT_CustomerProvidedInventory.Ownership AS Ownership,
	|	CASE
	|		WHEN TT_CustomerProvidedInventory.Quantity > ISNULL(InventoryInWarehousesBalance.QuantityBalance, 0)
	|			THEN ISNULL(InventoryInWarehousesBalance.QuantityBalance, 0)
	|		ELSE TT_CustomerProvidedInventory.Quantity
	|	END AS Quantity
	|FROM
	|	TT_CustomerProvidedInventory AS TT_CustomerProvidedInventory
	|		LEFT JOIN AccumulationRegister.InventoryInWarehouses.Balance AS InventoryInWarehousesBalance
	|		ON TT_CustomerProvidedInventory.Company = InventoryInWarehousesBalance.Company
	|			AND TT_CustomerProvidedInventory.Products = InventoryInWarehousesBalance.Products
	|			AND TT_CustomerProvidedInventory.Characteristic = InventoryInWarehousesBalance.Characteristic
	|			AND (InventoryInWarehousesBalance.Batch = VALUE(Catalog.ProductsBatches.EmptyRef))
	|			AND TT_CustomerProvidedInventory.Ownership = InventoryInWarehousesBalance.Ownership
	|WHERE
	|	CASE
	|			WHEN TT_CustomerProvidedInventory.Quantity > ISNULL(InventoryInWarehousesBalance.QuantityBalance, 0)
	|				THEN ISNULL(InventoryInWarehousesBalance.QuantityBalance, 0)
	|			ELSE TT_CustomerProvidedInventory.Quantity
	|		END <> 0";
	
	Query.SetParameter("Ref", FillingData);
	
	FillPropertyValues(ThisObject, FillingData, , DriveServer.GetStandardAttributesNames(ThisObject) + ",Comment");
	
	OperationType = Enums.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer;
	BasisDocument = FillingData;
	Order = FillingData;
	
	Products.Load(Query.Execute().Unload());
	
	IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInDocument(ThisObject, FillingData);
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
EndProcedure

Procedure FillBySubcontractorOrderReceivedTransfer(FillingData)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SubcontractorOrderReceived.Counterparty AS Counterparty,
	|	SubcontractorOrderReceived.Contract AS Contract,
	|	CustomerOwnedInventoryBalance.Products AS Products,
	|	CustomerOwnedInventoryBalance.Characteristic AS Characteristic,
	|	CustomerOwnedInventoryBalance.Products.MeasurementUnit AS MeasurementUnit,
	|	CustomerOwnedInventoryBalance.QuantityToIssueBalance AS Quantity
	|INTO TT_CustomerOwnedInventory
	|FROM
	|	AccumulationRegister.CustomerOwnedInventory.Balance(, SubcontractorOrder = &Ref) AS CustomerOwnedInventoryBalance
	|		INNER JOIN Document.SubcontractorOrderReceived AS SubcontractorOrderReceived
	|		ON CustomerOwnedInventoryBalance.SubcontractorOrder = SubcontractorOrderReceived.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_CustomerOwnedInventory.Products AS Products,
	|	TT_CustomerOwnedInventory.Characteristic AS Characteristic,
	|	TT_CustomerOwnedInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(InventoryOwnership.Ref, VALUE(Catalog.InventoryOwnership.EmptyRef)) AS Ownership,
	|	TT_CustomerOwnedInventory.Quantity AS Quantity
	|FROM
	|	TT_CustomerOwnedInventory AS TT_CustomerOwnedInventory
	|		LEFT JOIN Catalog.InventoryOwnership AS InventoryOwnership
	|		ON TT_CustomerOwnedInventory.Counterparty = InventoryOwnership.Counterparty
	|			AND TT_CustomerOwnedInventory.Contract = InventoryOwnership.Contract
	|			AND (InventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory))";
	
	Query.SetParameter("Ref", FillingData);
	
	FillPropertyValues(ThisObject, FillingData, , DriveServer.GetStandardAttributesNames(ThisObject) + ",Comment");
	
	OperationType = Enums.OperationTypesGoodsIssue.TransferToSubcontractingCustomer;
	BasisDocument = FillingData;
	Order = FillingData;
	
	Products.Load(Query.Execute().Unload());
	
	IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInDocument(ThisObject, FillingData);
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
EndProcedure
// end Drive.FullVersion

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure CheckExpiredBatches(Cancel)
	
	If Not GetFunctionalOption("UseBatches") Or AllowExpiredBatches Then
		Return;
	EndIf;
	
	BatchesTable = Products.Unload(, "LineNumber, Products, Batch");
	
	BatchesTable.Columns.Add("DeliveryDate", New TypeDescription("Date"));
	For Each BatchesRow In BatchesTable Do
		BatchesRow.DeliveryDate = Date;
	EndDo;
	
	Parameters = New Structure;
	Parameters.Insert("BatchesTable", BatchesTable);
	Parameters.Insert("DocObject", ThisObject);
	Parameters.Insert("TableName", "Products");
	
	BatchesServer.CheckExpiredBatches(Parameters, Cancel);
	
EndProcedure

Procedure ClearDeliveryAttributes(FieldsToClear = "")
	
	ClearStructure = New Structure;
	ClearStructure.Insert("ShippingAddress",	Undefined);
	ClearStructure.Insert("ContactPerson",		Undefined);
	ClearStructure.Insert("Incoterms",			Undefined);
	ClearStructure.Insert("DeliveryTimeFrom",	Undefined);
	ClearStructure.Insert("DeliveryTimeTo",		Undefined);
	ClearStructure.Insert("GoodsMarking",		Undefined);
	ClearStructure.Insert("LogisticsCompany",	Undefined);
	
	If IsBlankString(FieldsToClear) Then
		FillPropertyValues(ThisObject, ClearStructure);
	Else
		FillPropertyValues(ThisObject, ClearStructure, FieldsToClear);
	EndIf;
	
EndProcedure

Procedure FillSalesRep()
	
	SalesRep = Undefined;
	If ValueIsFilled(ShippingAddress) Then
		SalesRep = Common.ObjectAttributeValue(ShippingAddress, "SalesRep");
	EndIf;
	If Not ValueIsFilled(SalesRep) Then
		SalesRep = Common.ObjectAttributeValue(Counterparty, "SalesRep");
	EndIf;
	
	For Each CurrentRow In Products Do
		If ValueIsFilled(CurrentRow.SalesInvoice)
			And ValueIsFilled(CurrentRow.SalesRep) Then
			Continue;
		ElsIf ValueIsFilled(CurrentRow.Order)
			And CurrentRow.Order <> Order Then
			CurrentRow.SalesRep = Common.ObjectAttributeValue(CurrentRow.Order, "SalesRep");
		Else
			CurrentRow.SalesRep = SalesRep;
		EndIf;
	EndDo;
	
EndProcedure

// begin Drive.FullVersion

Procedure CheckReturnToSubcontractingCustomer(Cancel)
	
	If OperationType = Enums.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer
		And ValueIsFilled(Order) 
		And TypeOf(Order) = Type("DocumentRef.SubcontractorOrderReceived") Then
		
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED TOP 1
		|	TRUE AS VrtField
		|FROM
		|	Document.ProductionOrder AS ProductionOrder
		|		INNER JOIN Document.ManufacturingOperation AS ManufacturingOperation
		|		ON ProductionOrder.Ref = ManufacturingOperation.BasisDocument
		|		INNER JOIN Document.ManufacturingOperation.Inventory AS ManufacturingOperationInventory
		|		ON (ManufacturingOperation.Ref = ManufacturingOperationInventory.Ref)
		|WHERE
		|	ProductionOrder.SalesOrder = &Order
		|	AND ProductionOrder.Posted
		|	AND ManufacturingOperation.Posted";
		
		Query.SetParameter("Order", Order);
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			
			MessageText = NStr("en = 'The Goods issue with the ""Return to subcontracting customer"" operation
								|cannot be posted. There are Work-in-progress documents.'; 
								|ru = 'Не удается провести отпуск товаров с операцией
								| ""Возврат давальцу"". Есть документы ""Незавершенное производство"".';
								|pl = 'Wydanie zewnętrzne z operacją ""Zwrot do nabywcy usług podwykonawstwa""
								|nie może być zatwierdzone. Istnieją dokumenty ze statusem Praca w toku.';
								|es_ES = 'La Salida de mercancías con la operación ""Devolución al cliente subcontratado"" 
								|no se puede enviar. Hay documentos de Trabajo en progreso.';
								|es_CO = 'La Salida de productos con la operación ""Devolución al cliente subcontratado"" 
								|no se puede enviar. Hay documentos de Trabajo en progreso.';
								|tr = '""Alt yüklenici müşteriye iade"" işlemli Ambar çıkışı kaydedilemiyor.
								|İşlem bitişi belgeleri var.';
								|it = 'La spedizione merce con operazione ""Restituire al cliente in subfornitura""
								|non può essere pubblicata. Ci sono documenti di Lavori in corso.';
								|de = 'Fehler beim Buchen des Warenausgangs mit der Operation ""Zurück zu Kunde mit Subunternehmerbestellung""
								|. Es gibt Dokumente Arbeit in Bearbeitung.'");
			
			CommonClientServer.MessageToUser(MessageText, , , , Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// end Drive.FullVersion

#EndRegion

#EndIf