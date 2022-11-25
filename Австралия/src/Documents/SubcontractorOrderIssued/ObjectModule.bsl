#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var CancelOpen Export; //cancellation of opening when filling out a document

#EndRegion

#Region EventHandlers

Procedure OnCopy(CopiedObject)
	
	OrderState = GetSubcontractorOrderState();
	Closed = False;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	FillingStrategy = New Map;
	
	// begin Drive.FullVersion
	FillingStrategy[Type("DocumentRef.ProductionOrder")] = "FillByProductionOrder";
	
	FillingStrategy[Type("DocumentRef.ManufacturingOperation")] = "FillByManufacturingOperation";
	
	FillingStrategy[Type("DocumentRef.SubcontractorOrderIssued")] = "FillBySubcontractorOrderIssued";
	// end Drive.FullVersion
	FillingStrategy[Type("DocumentRef.SalesOrder")] = "FillBySalesOrder";
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy, "OrderState");
	
	// begin Drive.FullVersion
	If TypeOf(BasisDocument) = Type("DocumentRef.ManufacturingOperation") Then
		If BasisDocument = SalesOrder Then
			SalesOrder = Undefined;
		EndIf;
	EndIf;
	// end Drive.FullVersion
	
	FillByDefault();
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Closed And OrderState = DriveReUse.GetOrderStatus("SubcontractorOrderIssuedStatuses", "Completed") Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 is completed. Editing is restricted.'; ru = '%1 выполнен. Редактирование запрещено.';pl = '%1 jest zakończony. Edycja jest ograniczona.';es_ES = '%1 ha sido completado. La edición está restringida.';es_CO = '%1 ha sido completado. La edición está restringida.';tr = '%1 tamamlandı. Düzenleme kısıtlı.';it = '%1 è stato completato. La modifica è limitata.';de = '%1 ist abgeschlossen. Bearbeitung ist eingeschränkt.'"), Ref);
		CommonClientServer.MessageToUser(MessageText, , , , Cancel);
		Return;
	EndIf;
	
	DocumentAmount = Products.Total("Total");
	DocumentTax = Products.Total("VATAmount");
	DocumentSubtotal = DocumentAmount - DocumentTax;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.SubcontractorOrderIssued.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectInventoryFlowCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSubcontractorOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSubcontractComponents(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	// begin Drive.FullVersion
	DriveServer.ReflectSubcontractorPlanning(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectWorkInProgressStatement(AdditionalProperties, RegisterRecords, Cancel);
	// end Drive.FullVersion
	DriveServer.ReflectBackorders(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.SubcontractorOrderIssued.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
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
	Documents.SubcontractorOrderIssued.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	If Not Constants.UseSubcontractorOrderIssuedStatuses.Get() Then
		
		If Not ValueIsFilled(OrderState) Then
			MessageText = NStr("en = 'With the current settings, the order status fields are required.'; ru = 'При текущих настройках необходимо заполнить поля статуса заказа.';pl = 'Z bieżącymi ustawieniami, pola statusu zamówienia są wymagane.';es_ES = 'Con la configuración actual, los campos de estado de la orden son obligatorios.';es_CO = 'Con la configuración actual, los campos de estado de la orden son obligatorios.';tr = 'Mevcut ayarlarda sipariş durumu alanları gerekli.';it = 'Con le impostazioni correnti sono richiesti i campi di stato dell''ordine.';de = 'Bei den aktuellen Einstellungen sind die Auftrag-Statusfelder erforderlich.'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "OrderState", Cancel);
		EndIf;
		
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
EndProcedure

#EndRegion

#Region Internal

// begin Drive.FullVersion
Procedure FillByProductionOrder(DocumentRefProductionOrder) Export
	
	Documents.ProductionOrder.VerifyEnteringAbilityByProductionOrder(
		DocumentRefProductionOrder,
		Common.ObjectAttributesValues(DocumentRefProductionOrder, "Posted, Closed, OrderState"));
	
	BasisAttributes = Common.ObjectAttributesValues(DocumentRefProductionOrder, "OperationKind, UseProductionPlanning");
	
	If BasisAttributes.OperationKind = Enums.OperationTypesProductionOrder.Production
		Or BasisAttributes.OperationKind = Enums.OperationTypesProductionOrder.Disassembly Then
		
		ErrorText = NStr("en = 'Generation from orders with ""Production"" or ""Disassembly"" process type is not available.'; ru = 'Создание на основании заказов с типами процессов ""Производство"" или ""Разборка"" недоступно.';pl = 'Wygenerowanie z zamówień z typem procesu ""Produkcja"" lub ""Demontaż"" nie jest dostępne.';es_ES = 'La generación a partir de pedidos con tipo de proceso ""Producción"" o ""Desmontaje"" no está disponible.';es_CO = 'La generación a partir de pedidos con tipo de proceso ""Producción"" o ""Desmontaje"" no está disponible.';tr = '""Üretim"" veya ""Demontaj"" süreç türüne sahip emirlerden/siparişlerden oluşturma yapılamaz.';it = 'Non è disponibile la generazione da ordini con tipo processo ""Produzione"" o ""Smontaggio"".';de = 'Generieren aus Aufträgen mit dem Prozesstyp ""Produktion"" oder ""Demontage"" ist unmöglich.'");
		Raise ErrorText;
		
	EndIf;
	
	Query = New Query(
	"SELECT
	|	ProductionOrder.Ref AS Ref,
	|	ProductionOrder.Company AS Company,
	|	ProductionOrder.Finish AS ReceiptDate,
	|	ProductionOrder.Ref AS BasisDocument,
	|	CASE
	|			WHEN UseInventoryReservation.Value
	|				THEN UNDEFINED
	|			ELSE ProductionOrder.Ref
	|		END AS SalesOrder
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
	|	TT_ProductionOrdersTable.ReceiptDate AS ReceiptDate,
	|	TT_ProductionOrdersTable.SalesOrder AS SalesOrder
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
	|	ProductionOrderInventory.Characteristic AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(ProductionOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE ISNULL(UOM.Factor, 1)
	|	END AS Factor,
	|	ProductionOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	ProductionOrderInventory.Quantity AS Quantity
	|FROM
	|	TT_ProductionOrdersTable AS TT_ProductionOrdersTable
	|		INNER JOIN Document.ProductionOrder.Inventory AS ProductionOrderInventory
	|		ON TT_ProductionOrdersTable.Ref = ProductionOrderInventory.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (ProductionOrderInventory.MeasurementUnit = UOM.Ref)");
	
	Query.SetParameter("BasisDocument", DocumentRefProductionOrder);
	Query.SetParameter("Ref", Ref);
	
	QueryResult = Query.ExecuteBatch();
	
	DefaultVATRate = CurrentDefaultVATRate();
	
	Selection = QueryResult[1].Select();
	Selection.Next();
	FillPropertyValues(ThisObject, Selection);
	
	BalanceTable = QueryResult[2].Unload();
	BalanceTable.Indexes.Add("Products,Characteristic");
	
	Products.Clear();
	
	Selection = QueryResult[3].Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		
		BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
		If BalanceRowsArray.Count() = 0 Then
			Continue;
		EndIf;
		
		NewRow = Products.Add();
		FillPropertyValues(NewRow, Selection);
		
		If VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			ProductVATRate = Common.ObjectAttributeValue(NewRow.Products, "VATRate");
			If ValueIsFilled(ProductVATRate) Then
				NewRow.VATRate = ProductVATRate;
			Else
				NewRow.VATRate = DefaultVATRate;
			EndIf;
		Else
			NewRow.VATRate = DefaultVATRate;
		EndIf;
		
		If Not ValueIsFilled(NewRow.ProductsType) Then
			NewRow.ProductsType = Common.ObjectAttributeValue(NewRow.Products, "ProductsType");
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
	
	If Products.Count() = 0 Then
		
		MessageToUser = NStr("en = 'Cannot perform the action. In the Production order, all components are consumed or ordered.'; ru = 'Не удалось выполнить действие. В заказе на производство все компоненты уже использованы или заказаны.';pl = 'Nie można wykonać działania. W Zleceniu produkcyjnym, wszystkie komponenty są zużyte lub zamówione.';es_ES = 'No se puede realizar la acción. En la Orden de producción, todos los componentes se consumen o se ordenan.';es_CO = 'No se puede realizar la acción. En la Orden de producción, todos los componentes se consumen o se ordenan.';tr = 'İşlem gerçekleştirilemiyor. Üretim emrinde, tüm malzemeler tüketildi veya sipariş edildi.';it = 'Non è possibile eseguire l''azione. Nell''ordine di produzione, tutti i componenti sono consumati o ordinati.';de = 'Fehler beim Ausführen der Aktion. Im Produktionsauftrag sind alle Komponenten verbraucht oder bestellt.'");
		Raise MessageToUser;
		
	EndIf;
	
	FillTabularSectionBySpecification();
	FillTabularSectionBySpecification(True);
	
EndProcedure

Procedure FillByManufacturingOperation(DocumentRefWIP) Export

	AttributeValues = Common.ObjectAttributesValues(DocumentRefWIP, "Posted, Status, ReleaseRequired, ProductionMethod");
	AttributeValues.Insert("ForSubcontractorOrderIssued", True);
	Documents.ManufacturingOperation.CheckAbilityOfEnteringByWorkInProgress(DocumentRefWIP, AttributeValues);
	
	// Header filling.
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	Query.Text =
	"SELECT ALLOWED
	|	ManufacturingOperation.Ref AS BasisDocument,
	|	ManufacturingOperation.Company AS Company,
	|	ManufacturingOperation.Products AS Products,
	|	ManufacturingOperation.Characteristic AS Characteristic,
	|	ManufacturingOperation.Quantity AS Quantity,
	|	ManufacturingOperation.MeasurementUnit AS MeasurementUnit,
	|	ManufacturingOperation.Specification AS Specification,
	|	ProductsAll.Subcontractor AS Counterparty,
	|	ISNULL(ProductionOrder.Start, DATETIME(1, 1, 1)) AS ReceiptDate
	|INTO TT_ManufacturingOperation
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|		INNER JOIN Catalog.Products AS ProductsAll
	|		ON ManufacturingOperation.Products = ProductsAll.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON (ProductsAll.Vendor = Counterparties.Ref)
	|		LEFT JOIN Document.ProductionOrder AS ProductionOrder
	|		ON ManufacturingOperation.BasisDocument = ProductionOrder.Ref
	|WHERE
	|	ManufacturingOperation.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ManufacturingOperation.BasisDocument AS BasisDocument,
	|	TT_ManufacturingOperation.Counterparty AS Counterparty,
	|	TT_ManufacturingOperation.Company AS Company,
	|	TT_ManufacturingOperation.Products AS Products,
	|	TT_ManufacturingOperation.Characteristic AS Characteristic,
	|	TT_ManufacturingOperation.Quantity AS Quantity,
	|	TT_ManufacturingOperation.MeasurementUnit AS MeasurementUnit,
	|	TT_ManufacturingOperation.Specification AS Specification,
	|	TT_ManufacturingOperation.ReceiptDate AS ReceiptDate
	|FROM
	|	TT_ManufacturingOperation AS TT_ManufacturingOperation";
	
	Query.SetParameter("BasisDocument", DocumentRefWIP);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	FillPropertyValues(ThisObject, Selection);
	OrderReceived = BasisSubcontractorOrderIssued(DocumentRefWIP);
	SalesOrder = Documents.ManufacturingOperation.ParentWIP(DocumentRefWIP);
	
	ParentProductionMethod = Common.ObjectAttributeValue(SalesOrder, "ProductionMethod");
	If ParentProductionMethod = Enums.ProductionMethods.Subcontracting Or ValueIsFilled(OrderReceived) Then
		SalesOrder = Undefined;
	EndIf;
	
	// Filling out tabular section.
	Query.SetParameter("BasisDocument", Selection.BasisDocument);
	Query.SetParameter("Ref", 			Ref);

	Query.Text =
	"SELECT ALLOWED
	|	SubcontractorPlanningBalance.WorkInProgress AS WorkInProgress,
	|	SubcontractorPlanningBalance.Products AS Products,
	|	SubcontractorPlanningBalance.Characteristic AS Characteristic,
	|	SubcontractorPlanningBalance.QuantityBalance AS QuantityBalance
	|INTO TT_SubcontractorBalance
	|FROM
	|	AccumulationRegister.SubcontractorPlanning.Balance(
	|			,
	|			(WorkInProgress, Products, Characteristic) IN
	|				(SELECT
	|					ManufacturingOperation.BasisDocument AS WorkInProgress,
	|					ManufacturingOperation.Products AS Products,
	|					ManufacturingOperation.Characteristic AS Characteristic
	|				FROM
	|					TT_ManufacturingOperation AS ManufacturingOperation)) AS SubcontractorPlanningBalance
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentRegisterRecordsSubcontractorPlanning.WorkInProgress,
	|	DocumentRegisterRecordsSubcontractorPlanning.Products,
	|	DocumentRegisterRecordsSubcontractorPlanning.Characteristic,
	|	CASE
	|		WHEN DocumentRegisterRecordsSubcontractorPlanning.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN ISNULL(DocumentRegisterRecordsSubcontractorPlanning.Quantity, 0)
	|		ELSE -ISNULL(DocumentRegisterRecordsSubcontractorPlanning.Quantity, 0)
	|	END
	|FROM
	|	AccumulationRegister.SubcontractorPlanning AS DocumentRegisterRecordsSubcontractorPlanning
	|WHERE
	|	DocumentRegisterRecordsSubcontractorPlanning.Recorder = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorPlanningBalance.WorkInProgress AS WorkInProgress,
	|	SubcontractorPlanningBalance.Products AS Products,
	|	SubcontractorPlanningBalance.Characteristic AS Characteristic,
	|	SUM(SubcontractorPlanningBalance.QuantityBalance) AS QuantityBalance
	|INTO TT_SubcontractorBalanceGrouped
	|FROM
	|	TT_SubcontractorBalance AS SubcontractorPlanningBalance
	|
	|GROUP BY
	|	SubcontractorPlanningBalance.WorkInProgress,
	|	SubcontractorPlanningBalance.Products,
	|	SubcontractorPlanningBalance.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorPlanningBalance.WorkInProgress AS WorkInProgress,
	|	SubcontractorPlanningBalance.Products AS Products,
	|	SubcontractorPlanningBalance.Characteristic AS Characteristic,
	|	SubcontractorPlanningBalance.QuantityBalance AS Quantity,
	|	ProductsAll.VATRate AS VATRate,
	|	ProductsAll.ProductsType AS ProductsType
	|FROM
	|	TT_SubcontractorBalanceGrouped AS SubcontractorPlanningBalance
	|		INNER JOIN Catalog.Products AS ProductsAll
	|		ON SubcontractorPlanningBalance.Products = ProductsAll.Ref
	|WHERE
	|	SubcontractorPlanningBalance.QuantityBalance > 0";

	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[2].Unload();
	BalanceTable.Indexes.Add("WorkInProgress, Products, Characteristic");
	
	Products.Clear();
	Inventory.Clear();
	
	DefaultVATRate = CurrentDefaultVATRate();

	If BalanceTable.Count() > 0 Then
		
		TableProducts = ResultsArray[2].Unload();
		For Each SelectionProducts In TableProducts Do
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("WorkInProgress",		Selection.BasisDocument);
			StructureForSearch.Insert("Products", 			SelectionProducts.Products);
			StructureForSearch.Insert("Characteristic", 	SelectionProducts.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			NewRow = Products.Add();
			FillPropertyValues(NewRow, Selection);
			FillPropertyValues(NewRow, SelectionProducts);
			
			If VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
				ProductVATRate = SelectionProducts.VATRate;
				If ValueIsFilled(ProductVATRate) Then
					NewRow.VATRate = ProductVATRate;
				Else
					NewRow.VATRate = DefaultVATRate;
				EndIf;
			Else
				NewRow.VATRate = DefaultVATRate;
			EndIf;
			
			If BalanceRowsArray[0].Quantity <= 0 Then
				BalanceTable.Delete(BalanceRowsArray[0]);
			EndIf;
			
		EndDo;
	Else
		ErrorText = NStr("en = 'Cannot generate ""Subcontractor order issued"". Such orders have already been generated for the product quantity specified in this Work-in-progress.'; ru = 'Не удалось создать выданный заказ на переработку. Заказы на количество номенклатуры, указанное в документе ""Незавершенное производство"", уже созданы.';pl = 'Nie można wygenerować ""Wydane zamówienie wykonawcy"". Takie zamówienia są już wygenerowane dla ilości produktu, określonej w tej Pracy w toku.';es_ES = 'No se ha podido generar una ""Orden emitida del subcontratista"". Dichas órdenes ya se han generado para la cantidad de producto especificada en este Trabajo en progreso.';es_CO = 'No se ha podido generar una ""Orden emitida del subcontratista"". Dichas órdenes ya se han generado para la cantidad de producto especificada en este Trabajo en progreso.';tr = '""Düzenlenen alt yüklenici siparişi"" oluşturulamıyor. Bu İşlem bitişinde belirtilen ürün miktarı için siparişler zaten oluşturuldu.';it = 'Impossibile generare ""Ordine di subfornitura emesso"". Questi ordini sono già stati generati per la quantità di produzione indicata in questo Lavoro in corso.';de = 'Fehler beim Generieren von ""Subunternehmeraufträgen ausgestellt"". Solche Aufträge wurden bereit für die Produktmenge, angegeben in dieser Arbeit in Bearbeitung, generiert.'");
		
		Raise ErrorText;
		
	EndIf;
	
	// Fill out according to specification.
	If Products.Count() > 0 Then
		If Inventory.Count() = 0 Then
			FillTabularSectionBySpecification();
			FillTabularSectionBySpecification(True);
		EndIf;
	EndIf;
	
EndProcedure
// end Drive.FullVersion

Procedure FillBySubcontractorOrderIssued(DocumentRefSOI) Export

	AttributeValues = Common.ObjectAttributesValues(DocumentRefSOI, "Posted");
	Documents.SubcontractorOrderIssued.CheckEnterBasedOnSubcontractorOrder(AttributeValues);
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	SubcontractorOrder.Ref AS Ref,
	|	SubcontractorOrder.StructuralUnit AS StructuralUnit,
	|	SubcontractorOrder.Company AS Company,
	|	SubcontractorOrder.ReceiptDate AS ReceiptDate,
	|	SubcontractorOrder.CompanyVATNumber AS CompanyVATNumber
	|INTO SubcontractorOrderHeader
	|FROM
	|	Document.SubcontractorOrderIssued AS SubcontractorOrder
	|WHERE
	|	SubcontractorOrder.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrdersHeader.Ref AS BasisDocument,
	|	SalesOrdersHeader.StructuralUnit AS StructuralUnit,
	|	SalesOrdersHeader.Company AS Company,
	|	SalesOrdersHeader.ReceiptDate AS ReceiptDate,
	|	SalesOrdersHeader.CompanyVATNumber AS CompanyVATNumber
	|FROM
	|	SubcontractorOrderHeader AS SalesOrdersHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorOrderIssued.Ref AS Ref
	|INTO OrderChildren
	|FROM
	|	SubcontractorOrderHeader AS SubcontractorOrderHeader
	|		INNER JOIN Document.SubcontractorOrderIssued AS SubcontractorOrderIssued
	|		ON SubcontractorOrderHeader.Ref = SubcontractorOrderIssued.BasisDocument
	|WHERE
	|	SubcontractorOrderIssued.Posted
	|
	|UNION ALL
	|
	|SELECT
	|	ProductionOrder.Ref
	|FROM
	|	SubcontractorOrderHeader AS SubcontractorOrderHeader
	|		INNER JOIN Document.ProductionOrder AS ProductionOrder
	|		ON SubcontractorOrderHeader.Ref = ProductionOrder.BasisDocument
	|WHERE
	|	ProductionOrder.Posted
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	OrdersBalance.QuantityBalance AS QuantityBalance
	|INTO OrdersBalancePre
	|FROM
	|	AccumulationRegister.SubcontractComponents.Balance(, SubcontractorOrder = &BasisDocument) AS OrdersBalance
	|
	|UNION ALL
	|
	|SELECT
	|	SubcontractorOrdersIssued.Products,
	|	SubcontractorOrdersIssued.Characteristic,
	|	-SubcontractorOrdersIssued.Quantity
	|FROM
	|	OrderChildren AS SubcontractorOrderChildren
	|		INNER JOIN AccumulationRegister.SubcontractorOrdersIssued AS SubcontractorOrdersIssued
	|		ON SubcontractorOrderChildren.Ref = SubcontractorOrdersIssued.SubcontractorOrder
	|WHERE
	|	SubcontractorOrdersIssued.RecordType = VALUE(AccumulationRecordType.Receipt)
	|
	|UNION ALL
	|
	|SELECT
	|	ProductionOrders.Products,
	|	ProductionOrders.Characteristic,
	|	-ProductionOrders.Quantity
	|FROM
	|	OrderChildren AS ProductionOrderChildren
	|		INNER JOIN AccumulationRegister.ProductionOrders AS ProductionOrders
	|		ON ProductionOrderChildren.Ref = ProductionOrders.ProductionOrder
	|WHERE
	|	ProductionOrders.RecordType = VALUE(AccumulationRecordType.Receipt)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|INTO OrdersBalance
	|FROM
	|	OrdersBalancePre AS OrdersBalance
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
	|	MIN(SubcontractorOrderInventory.LineNumber) AS LineNumber,
	|	SubcontractorOrderInventory.Products AS Products,
	|	SubcontractorOrderInventory.Characteristic AS Characteristic,
	|	ISNULL(UOMCatalog.Factor, 1) AS Factor,
	|	SubcontractorOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	ProductsCatalog.ProductsType AS ProductsType,
	|	ProductsCatalog.VATRate AS VATRate,
	|	ProductsCatalog.Subcontractor AS Subcontractor,
	|	ProductsCatalog.ReplenishmentMethod AS ReplenishmentMethod,
	|	SUM(SubcontractorOrderInventory.Quantity) AS Quantity,
	|	OrdersBalance.QuantityBalance AS QuantityBalance
	|INTO TableProductionPre
	|FROM
	|	SubcontractorOrderHeader AS SubcontractorOrderHeader
	|		INNER JOIN Document.SubcontractorOrderIssued.Inventory AS SubcontractorOrderInventory
	|		ON SubcontractorOrderHeader.Ref = SubcontractorOrderInventory.Ref
	|		LEFT JOIN Catalog.Products AS ProductsCatalog
	|		ON (SubcontractorOrderInventory.Products = ProductsCatalog.Ref)
	|		INNER JOIN OrdersBalance AS OrdersBalance
	|		ON (SubcontractorOrderInventory.Products = OrdersBalance.Products)
	|			AND (SubcontractorOrderInventory.Characteristic = OrdersBalance.Characteristic)
	|		LEFT JOIN Catalog.UOM AS UOMCatalog
	|		ON (SubcontractorOrderInventory.MeasurementUnit = UOMCatalog.Ref)
	|WHERE
	|	ProductsCatalog.ReplenishmentMethod IN(&ReplenishmentMethod)
	|
	|GROUP BY
	|	SubcontractorOrderInventory.Products,
	|	SubcontractorOrderInventory.Characteristic,
	|	SubcontractorOrderInventory.MeasurementUnit,
	|	ISNULL(UOMCatalog.Factor, 1),
	|	ProductsCatalog.ProductsType,
	|	ProductsCatalog.VATRate,
	|	ProductsCatalog.Subcontractor,
	|	ProductsCatalog.ReplenishmentMethod,
	|	OrdersBalance.QuantityBalance
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProductionPre.LineNumber AS LineNumber,
	|	TableProductionPre.Products AS Products,
	|	TableProductionPre.Characteristic AS Characteristic,
	|	TableProductionPre.Factor AS Factor,
	|	TableProductionPre.MeasurementUnit AS MeasurementUnit,
	|	TableProductionPre.ProductsType AS ProductsType,
	|	TableProductionPre.ReplenishmentMethod AS ReplenishmentMethod,
	|	TableProductionPre.VATRate AS VATRate,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS Specification,
	|	CASE
	|		WHEN TableProductionPre.QuantityBalance - TableProductionPre.Quantity * TableProductionPre.Factor < 0
	|			THEN TableProductionPre.QuantityBalance / TableProductionPre.Factor
	|		ELSE TableProductionPre.Quantity
	|	END AS Quantity
	|FROM
	|	TableProductionPre AS TableProductionPre
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TableProductionPre.Subcontractor AS Subcontractor
	|FROM
	|	TableProductionPre AS TableProductionPre";
	
	Query.SetParameter("BasisDocument", DocumentRefSOI);
	
	ArrayMethods = New Array;
	ArrayMethods.Add(Enums.InventoryReplenishmentMethods.Assembly);
	ArrayMethods.Add(Enums.InventoryReplenishmentMethods.Production);
	ArrayMethods.Add(Enums.InventoryReplenishmentMethods.Processing);
	
	Query.SetParameter("ReplenishmentMethod", ArrayMethods);
	
	QueryResult = Query.ExecuteBatch();
	
	If QueryResult[6].IsEmpty() Then
		Raise NStr("en = 'Cannot generate  a ""Subcontractor order issued"". Orders have already been created for the quantity of components specified in this Subcontractor order issued.'; ru = 'Не удалось создать выданный заказ на переработку. Заказы на количество компонентов, указанное в выданном заказе на переработку, уже созданы.';pl = 'Nie można wygenerować ""Wydane zamówienie wykonawcy"". Zamówienia są już utworzone dla ilości komponentów, określonej w tym Wydanym zamówieniu wykonawcy.';es_ES = 'No se ha podido generar una ""Orden emitida del subcontratista"". Ya se han creado órdenes para la cantidad de componentes especificados en esta Orden emitida del subcontratista.';es_CO = 'No se ha podido generar una ""Orden emitida del subcontratista"". Ya se han creado órdenes para la cantidad de componentes especificados en esta Orden emitida del subcontratista.';tr = '""Düzenlenen alt yüklenici siparişi"" oluşturulamıyor. Bu Düzenlenen alt yüklenici siparişinde belirtilen malzeme miktarı için zaten siparişler oluşturuldu.';it = 'Impossibile generare un ""Ordine di subfornitura emesso"". Gli ordini sono già stati creati per la quantità di componenti indicata in questo Ordine di subfornitura emesso.';de = 'Fehler beim Generieren eines ""Subunternehmerauftrags ausgestellt"". Aufträge sind bereits für die Menge von Komponenten, angegeben in diesem Subunternehmerauftrag ausgestellt, erstellt.'");
	EndIf;
	
	Selection = QueryResult[1].Select();
	Selection.Next();
	FillPropertyValues(ThisObject, Selection);
	
	Selection = QueryResult[7].Select();
	
	If Selection.Count() = 1 Then
		Selection.Next();
		Counterparty = Selection.Subcontractor;
	EndIf;
	
	TableDataProducts = QueryResult[6].Unload();
	
	For Each Row In TableDataProducts Do
		Row.Specification = Documents.SubcontractorOrderIssued.GetAvailableBOM(
			Row, Date, Row, Row.Characteristic);
	EndDo;
	
	Products.Load(TableDataProducts);
	Inventory.Clear();
	
	FillTabularSectionBySpecificationForTheSalesOrder();
	
EndProcedure

Procedure FillBySalesOrder(DocumentRefSalesOrder) Export
	
	AttributeValues = Common.ObjectAttributesValues(DocumentRefSalesOrder, "OrderState, Posted");
	Documents.SalesOrder.CheckAbilityOfEnteringBySalesOrder(DocumentRefSalesOrder, AttributeValues);
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.StructuralUnitReserve AS StructuralUnitReserve,
	|	SalesOrder.Company AS Company,
	|	SalesOrder.ShipmentDate AS ShipmentDate,
	|	SalesOrder.CompanyVATNumber AS CompanyVATNumber
	|INTO SalesOrdersHeader
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrderInventory.Ref AS Ref,
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	SalesOrderInventory.Products AS Products1,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.Specification AS Specification,
	|	SalesOrderInventory.VATRate AS VATRate,
	|	SalesOrderInventory.Quantity AS Quantity,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit
	|INTO SalesOrderInventory
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SalesOrderInventory.Products = ProductsCatalog.Ref
	|			AND ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|WHERE
	|	SalesOrderInventory.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrdersHeader.Ref AS BasisDocument,
	|	SalesOrdersHeader.Ref AS SalesOrder,
	|	SalesOrdersHeader.StructuralUnitReserve AS StructuralUnit,
	|	SalesOrdersHeader.Company AS Company,
	|	SalesOrdersHeader.ShipmentDate AS ReceiptDate,
	|	SalesOrdersHeader.CompanyVATNumber AS CompanyVATNumber
	|FROM
	|	SalesOrdersHeader AS SalesOrdersHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	OrdersBalance.QuantityBalance AS QuantityBalance
	|INTO OrdersBalancePre
	|FROM
	|	AccumulationRegister.SalesOrders.Balance(, SalesOrder = &BasisDocument) AS OrdersBalance
	|
	|UNION ALL
	|
	|SELECT
	|	ReservedProductsBalances.Products,
	|	ReservedProductsBalances.Characteristic,
	|	-ReservedProductsBalances.QuantityBalance
	|FROM
	|	AccumulationRegister.ReservedProducts.Balance(, SalesOrder = &BasisDocument) AS ReservedProductsBalances
	|
	|UNION ALL
	|
	|SELECT
	|	PlacementBalances.Products,
	|	PlacementBalances.Characteristic,
	|	-PlacementBalances.QuantityBalance
	|FROM
	|	AccumulationRegister.Backorders.Balance(, SalesOrder = &BasisDocument) AS PlacementBalances
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
	|WHERE
	|	DocumentRegisterRecordsBackorders.Recorder = &Ref
	|	AND DocumentRegisterRecordsBackorders.SalesOrder = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|INTO OrdersBalance
	|FROM
	|	OrdersBalancePre AS OrdersBalance
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
	|	MIN(SalesOrderInventory.LineNumber) AS LineNumber,
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	ISNULL(UOMCatalog.Factor, 1) AS Factor,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN &UseProduction = TRUE
	|			THEN SalesOrderInventory.Specification
	|		ELSE VALUE(Catalog.BillsOfMaterials.EmptyRef)
	|	END AS Specification,
	|	ProductsCatalog.ProductsType AS ProductsType,
	|	SalesOrderInventory.VATRate AS VATRate,
	|	SUM(SalesOrderInventory.Quantity) AS Quantity,
	|	OrdersBalance.QuantityBalance AS QuantityBalance,
	|	ProductsCatalog.Subcontractor AS Subcontractor
	|INTO TableProductionPre
	|FROM
	|	SalesOrdersHeader AS SalesOrdersHeader
	|		INNER JOIN SalesOrderInventory AS SalesOrderInventory
	|		ON SalesOrdersHeader.Ref = SalesOrderInventory.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials AS BillsOfMaterials
	|		ON (SalesOrderInventory.Specification = BillsOfMaterials.Ref)
	|		LEFT JOIN Catalog.Products AS ProductsCatalog
	|		ON (SalesOrderInventory.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOMCatalog
	|		ON (SalesOrderInventory.MeasurementUnit = UOMCatalog.Ref)
	|		INNER JOIN OrdersBalance AS OrdersBalance
	|		ON (SalesOrderInventory.Products = OrdersBalance.Products)
	|			AND (SalesOrderInventory.Characteristic = OrdersBalance.Characteristic)
	|WHERE
	|	(NOT BillsOfMaterials.Ref IS NULL
	|			OR ProductsCatalog.ReplenishmentMethod IN (&ArrayMethods))
	|
	|GROUP BY
	|	SalesOrderInventory.Products,
	|	SalesOrderInventory.Characteristic,
	|	SalesOrderInventory.MeasurementUnit,
	|	ISNULL(UOMCatalog.Factor, 1),
	|	SalesOrderInventory.Specification,
	|	ProductsCatalog.ProductsType,
	|	SalesOrderInventory.VATRate,
	|	OrdersBalance.QuantityBalance,
	|	ProductsCatalog.Subcontractor
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProductionPre.LineNumber AS LineNumber,
	|	TableProductionPre.Products AS Products,
	|	TableProductionPre.Characteristic AS Characteristic,
	|	TableProductionPre.Factor AS Factor,
	|	TableProductionPre.MeasurementUnit AS MeasurementUnit,
	|	TableProductionPre.Specification AS Specification,
	|	TableProductionPre.ProductsType AS ProductsType,
	|	TableProductionPre.VATRate AS VATRate,
	|	SUM(CASE
	|			WHEN TableProductionPre.QuantityBalance - TableProductionPre.Quantity * TableProductionPre.Factor < 0
	|				THEN TableProductionPre.QuantityBalance / TableProductionPre.Factor
	|			ELSE TableProductionPre.Quantity
	|		END) AS Quantity
	|FROM
	|	TableProductionPre AS TableProductionPre
	|
	|GROUP BY
	|	TableProductionPre.Products,
	|	TableProductionPre.Characteristic,
	|	TableProductionPre.VATRate,
	|	TableProductionPre.ProductsType,
	|	TableProductionPre.Specification,
	|	TableProductionPre.MeasurementUnit,
	|	TableProductionPre.Factor,
	|	TableProductionPre.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TableProductionPre.Subcontractor AS Subcontractor
	|FROM
	|	TableProductionPre AS TableProductionPre
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TRUE
	|FROM
	|	SalesOrderInventory AS SubcontractorOrderInventory
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SubcontractorOrderInventory.Products = ProductsCatalog.Ref
	|WHERE
	|	ProductsCatalog.ReplenishmentMethod IN (&ArrayMethods)";
	
	ArrayMethods = New Array;
	ArrayMethods.Add(Enums.InventoryReplenishmentMethods.Processing);
	ArrayMethods.Add(Enums.InventoryReplenishmentMethods.Production);
	ArrayMethods.Add(Enums.InventoryReplenishmentMethods.Assembly);
	
	Query.SetParameter("BasisDocument", DocumentRefSalesOrder);
	Query.SetParameter("UseProduction", Constants.UseProductionSubsystem.Get());
	Query.SetParameter("ArrayMethods", ArrayMethods);
	Query.SetParameter("Ref", Ref);
	
	QueryResult = Query.ExecuteBatch();
	
	If QueryResult[8].IsEmpty()Then

		Raise NStr(
			"en = 'Cannot generate a ""Subcontractor order issued"" from this Sales order.
			|You can generate such an order only from a Sales order with products
			|whose replenishment method is Subcontracting, Assembly, or Production.'; 
			|ru = 'Не удалось сформировать выданный заказ на переработку на основании этого заказа покупателя.
			|Вы можете сформировать такой заказ только на основании заказа покупателя,
			|включающего номенклатуру со способом пополнения ""Переработка"", Сборка"" или ""Производство"".';
			|pl = 'Nie można wygenerować ""Wydane zamówienie wykonawcy"" z tego Zamówienia sprzedaży.
			|Można wygenerować takie zamówienie tylko z Zamówienia sprzedaży z produktami,
			|których sposób uzupełniania to Podwykonawstwo, Montaż lub Produkcja.';
			|es_ES = 'No se ha podido generar una ""Orden emitida del subcontratista"" de esta Orden de ventas.
			|Sólo se puede generar una orden de este tipo a partir de una Orden de ventas con productos
			|cuyo método de reposición del inventario sea Subcontratación, Montaje o Producción.';
			|es_CO = 'No se ha podido generar una ""Orden emitida del subcontratista"" de esta Orden de ventas.
			|Sólo se puede generar una orden de este tipo a partir de una Orden de ventas con productos
			|cuyo método de reposición del inventario sea Subcontratación, Montaje o Producción.';
			|tr = 'Bu Satış siparişinden ""Düzenlenen alt yüklenici siparişi"" oluşturulamıyor.
			|Bu tür bir sipariş sadece stok yenileme yöntemi Taşeronluk, Montaj veya Üretim
			|olan ürünlere sahip bir Satış siparişinden oluşturulabilir.';
			|it = 'Impossibile generare un ""Ordine di subfornitura emesso"" da questo Ordine cliente.
			|È possibile generare questo ordine solo da un Ordine cliente con articoli
			|il cui metodo di rifornimento è Subfornitura, Assemblaggio o produzione.';
			|de = 'Fehler beim Generieren eines ""Subunternehmerauftrags ausgestellt"" aus diesem Kundenauftrag.
			|Sie können solchen Auftrag nur aus einem Kundenauftrag mit Produkten mit 
			|Auffüllungsmethode Subunternehmerbestellung, Montage oder Produktion generieren.'");
	EndIf;

	If QueryResult[6].IsEmpty() Then
		Raise NStr("en = 'Cannot generate a ""Subcontractor order issued"". Orders have already been created for the quantity of products specified in this Sales order.'; ru = 'Не удалось создать выданный заказ на переработку. Заказы на количество номенклатуры, указанное в заказе покупателя, уже созданы.';pl = 'Nie można wygenerować ""Wydane zamówienie wykonawcy"". Zamówienia są już utworzone dla ilości produktów, określonej w tym Zamówieniu sprzedaży.';es_ES = 'No se ha podido generar una ""Orden emitida del subcontratista"". Ya se han creado órdenes para la cantidad de productos especificados en esta Orden de ventas.';es_CO = 'No se ha podido generar una ""Orden emitida del subcontratista"". Ya se han creado órdenes para la cantidad de productos especificados en esta Orden de ventas.';tr = '""Düzenlenen alt yüklenici siparişi"" oluşturulamıyor. Bu Satış siparişinde belirtilen ürün miktarı için siparişler zaten oluşturuldu.';it = 'Impossibile generare un ""Ordine di subfornitura emesso"". Gli ordini sono già stati creati per la quantità di articoli indicata in questo Ordine cliente.';de = 'Fehler beim Generieren eines ""Subunternehmerauftrags ausgestellt"". Aufträge sind bereits für die Menge von Produkten, angegeben in diesem Kundenauftrag, erstellt.'");
	EndIf;

	Selection = QueryResult[2].Select();
	Selection.Next();
	FillPropertyValues(ThisObject, Selection);
	
	Selection = QueryResult[7].Select();
	
	If Selection.Count() = 1 Then
		Selection.Next();
		Counterparty = Selection.Subcontractor;
	EndIf;
	
	Products.Load(QueryResult[6].Unload());
	
	Inventory.Clear();

	If Products.Count() > 0 Then
		FillTabularSectionBySpecificationForTheSalesOrder();
	EndIf;

EndProcedure

// Procedure fills tabular section according to specification.
//
Procedure FillTabularSectionBySpecification(IsByProducts = False) Export
	
	If IsByProducts Then
		
		FillByProductsWithBOM();
		
	Else
		
		FillInventoryWithBOM();
		
	EndIf;
	
EndProcedure

Procedure FillInventoryWithBOMTakingRelatedBOMs() Export
	
	TableComponents = Catalogs.BillsOfMaterials.GetBOMComponentsIncludingNestedLevels(Products.Unload());
	
	Inventory.Load(TableComponents);
	
EndProcedure

#EndRegion

#Region Private

Procedure FillByDefault()
	
	If Not ValueIsFilled(OrderState) Then
		OrderState = GetSubcontractorOrderState();
	EndIf;
	
	If Not ValueIsFilled(ReceiptDate) Then
		ReceiptDate = CurrentSessionDate();
	EndIf;
	
EndProcedure

Function GetSubcontractorOrderState()
	
	If Constants.UseSubcontractorOrderIssuedStatuses.Get() Then
		User = Users.CurrentUser();
		SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewSubcontractorOrderIssued");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.SubcontractorOrderIssuedStatuses.Open;
		EndIf;
	Else
		OrderState = Constants.SubcontractorOrderIssuedInProgressStatus.Get();
	EndIf;
	
	Return OrderState;
	
EndFunction

Procedure FillInventoryWithBOM()
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProduction.LineNumber AS LineNumber,
	|	TableProduction.Quantity AS Quantity,
	|	TableProduction.RoundedQuantity AS RoundedQuantity,
	|	TableProduction.MeasurementUnit AS MeasurementUnit,
	|	TableProduction.Specification AS Specification
	|INTO TemporaryTableProduction
	|FROM
	|	&TableProduction AS TableProduction
	|WHERE
	|	TableProduction.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)";
	
	TableProduction = Products.Unload();
	
	TableProduction.Columns.Add("RoundedQuantity", New TypeDescription("Number", New NumberQualifiers(10, 0)));
	
	For Each ProductLine In TableProduction Do
		
		ProductLine.RoundedQuantity = ProductLine.Quantity;
		
		If ValueIsFilled(ProductLine.Specification) Then
			
			BOM_Quantity = Common.ObjectAttributeValue(ProductLine.Specification, "Quantity");
			
			If BOM_Quantity > 1 And ProductLine.Quantity % BOM_Quantity > 0 Then
				
				ProductLine.RoundedQuantity = (Int(ProductLine.Quantity / BOM_Quantity) + 1) * BOM_Quantity;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Query.SetParameter("TableProduction", TableProduction);
	Query.SetParameter("UseCharacteristics", Constants.UseCharacteristics.Get());
	
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	MIN(TableProduction.LineNumber) AS ProductionLineNumber,
	|	MIN(TableMaterials.LineNumber) AS StructureLineNumber,
	|	TableMaterials.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(CASE
	|			WHEN TableMaterials.CalculationMethod = VALUE(Enum.BOMContentCalculationMethod.Proportional)
	|				THEN TableMaterials.Quantity / BillOfMaterials.Quantity * ISNULL(ProductUOM.Factor, 1) * TableProduction.Quantity
	|			ELSE TableMaterials.Quantity / BillOfMaterials.Quantity * ISNULL(ProductUOM.Factor, 1) * TableProduction.RoundedQuantity
	|		END) AS Quantity,
	|	TableMaterials.MeasurementUnit AS MeasurementUnit
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		LEFT JOIN Catalog.BillsOfMaterials AS BillOfMaterials
	|		ON TableProduction.Specification = BillOfMaterials.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TableProduction.Specification = TableMaterials.Ref
	|		LEFT JOIN Catalog.UOM AS ProductUOM
	|		ON TableProduction.MeasurementUnit = ProductUOM.Ref
	|WHERE
	|	TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND TableMaterials.ContentRowType <> VALUE(Enum.BOMLineType.Node)
	|
	|GROUP BY
	|	TableMaterials.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	TableMaterials.MeasurementUnit
	|
	|ORDER BY
	|	ProductionLineNumber,
	|	StructureLineNumber";
	
	QueryResult = Query.Execute();
	Inventory.Load(QueryResult.Unload());
	
EndProcedure

Procedure FillByProductsWithBOM()
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProduction.LineNumber AS LineNumber,
	|	TableProduction.Quantity AS Quantity,
	|	TableProduction.MeasurementUnit AS MeasurementUnit,
	|	TableProduction.Specification AS Specification
	|INTO TemporaryTableProduction
	|FROM
	|	&TableProduction AS TableProduction
	|WHERE
	|	TableProduction.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)";
	
	ByProducts.Clear();
	TableProduction = Products.Unload();
	
	Query.SetParameter("TableProduction", TableProduction);
	Query.SetParameter("UseCharacteristics", Constants.UseCharacteristics.Get());
	
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	TableProduction.LineNumber AS ProductionLineNumber,
	|	TableByProducts.LineNumber AS StructureLineNumber,
	|	TableByProducts.Product AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableByProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	TableByProducts.Quantity / BillOfMaterials.Quantity * ISNULL(ProductUOM.Factor, 1) * TableProduction.Quantity AS Quantity,
	|	TableByProducts.MeasurementUnit AS MeasurementUnit
	|INTO TemporaryTableByProducts
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		LEFT JOIN Catalog.BillsOfMaterials AS BillOfMaterials
	|		ON TableProduction.Specification = BillOfMaterials.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.ByProducts AS TableByProducts
	|		ON TableProduction.Specification = TableByProducts.Ref
	|		LEFT JOIN Catalog.UOM AS ProductUOM
	|		ON TableProduction.MeasurementUnit = ProductUOM.Ref
	|WHERE
	|	TableByProducts.Product.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TemporaryTableByProducts.ProductionLineNumber) AS ProductionLineNumber,
	|	MIN(TemporaryTableByProducts.StructureLineNumber) AS StructureLineNumber,
	|	TemporaryTableByProducts.Products AS Products,
	|	TemporaryTableByProducts.Characteristic AS Characteristic,
	|	TemporaryTableByProducts.MeasurementUnit AS MeasurementUnit,
	|	SUM(TemporaryTableByProducts.Quantity) AS Quantity
	|FROM
	|	TemporaryTableByProducts AS TemporaryTableByProducts
	|
	|GROUP BY
	|	TemporaryTableByProducts.MeasurementUnit,
	|	TemporaryTableByProducts.Characteristic,
	|	TemporaryTableByProducts.Products
	|
	|ORDER BY
	|	ProductionLineNumber,
	|	StructureLineNumber";
	
	// DocumentCurrency
	ByProductPriceCurrency = DocumentCurrency;
	If Not ValueIsFilled(ByProductPriceCurrency) Then
		If ValueIsFilled(Contract) Then
			ByProductPriceCurrency = Common.ObjectAttributeValue(Contract, "SettlementsCurrency");
		Else
			ByProductPriceCurrency = DriveReUse.GetFunctionalCurrency();
		EndIf;
	EndIf;
	
	StructureData = New Structure();
	StructureData.Insert("Company", 			Company);
	StructureData.Insert("ProcessingDate",		?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	StructureData.Insert("DocumentCurrency",	ByProductPriceCurrency);
	StructureData.Insert("PriceKind",			InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company).AccountingPrice);
	StructureData.Insert("Products",			Undefined);
	StructureData.Insert("Characteristic",		Undefined);
	StructureData.Insert("Factor",				1);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		NewRow = ByProducts.Add();
		FillPropertyValues(NewRow, Selection);
		
		StructureData.Products = Selection.Products;
		StructureData.Characteristic = Selection.Characteristic;
		
		NewRow.CostValue = DriveServer.GetProductsPriceByPriceKind(StructureData);
		NewRow.Total = NewRow.CostValue * NewRow.Quantity;
		
	EndDo;
	
	ByProducts.GroupBy("Products, Characteristic, MeasurementUnit, CostValue", "Quantity, Total");
	
EndProcedure

Procedure FillTabularSectionBySpecificationForTheSalesOrder() Export

	Query = New Query;
	Query.Text =
	"SELECT
	|	TableProduction.LineNumber AS LineNumber,
	|	TableProduction.Products AS Products,
	|	TableProduction.Quantity AS Quantity,
	|	TableProduction.Specification AS Specification,
	|	TableProduction.MeasurementUnit AS MeasurementUnit
	|INTO TT_Level0Pre
	|FROM
	|	&TableProduction AS TableProduction
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.LineNumber AS LineNumber,
	|	TableProduction.Products AS Products,
	|	TableProduction.Quantity AS Quantity,
	|	TableProduction.Specification AS Specification,
	|	TableProduction.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN ProductsCatalog.Subcontractor = VALUE(Catalog.Counterparties.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductsCatalog.Subcontractor
	|	END AS SubcontractorParent,
	|	ProductsCatalog.ReplenishmentMethod AS ReplenishmentMethodParent
	|INTO TT_Level0
	|FROM
	|	TT_Level0Pre AS TableProduction
	|		LEFT JOIN Catalog.Products AS ProductsCatalog
	|		ON TableProduction.Products = ProductsCatalog.Ref
	|WHERE
	|	ProductsCatalog.ReplenishmentMethod = &Subcontracting
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Level0.LineNumber AS LineNumber,
	|	TableMaterials.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(TableMaterials.Quantity / TableMaterials.Ref.Quantity * CASE
	|			WHEN TableMaterials.CalculationMethod = VALUE(Enum.BOMContentCalculationMethod.Proportional)
	|				THEN ISNULL(UOM.Factor, 1) * TT_Level0.Quantity
	|			ELSE CASE
	|					WHEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level0.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) = ISNULL(UOM.Factor, 1) * TT_Level0.Quantity / TableMaterials.Ref.Quantity
	|						THEN ISNULL(UOM.Factor, 1) * TT_Level0.Quantity
	|					WHEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level0.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) > ISNULL(UOM.Factor, 1) * TT_Level0.Quantity / TableMaterials.Ref.Quantity
	|						THEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level0.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) * TableMaterials.Ref.Quantity
	|					ELSE ((CAST(ISNULL(UOM.Factor, 1) * TT_Level0.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) + 1) * TableMaterials.Ref.Quantity
	|				END
	|		END) AS Quantity,
	|	TableMaterials.Specification AS Specification,
	|	TableMaterials.MeasurementUnit AS MeasurementUnit,
	|	TT_Level0.SubcontractorParent AS SubcontractorParent,
	|	TT_Level0.ReplenishmentMethodParent AS ReplenishmentMethodParent,
	|	ProductsCatalog.Subcontractor AS SubcontractorChild,
	|	ProductsCatalog.ReplenishmentMethod AS ReplenishmentMethodChild
	|INTO TT_Level1
	|FROM
	|	TT_Level0 AS TT_Level0
	|		INNER JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TT_Level0.Specification = TableMaterials.Ref
	|			AND (TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON TT_Level0.MeasurementUnit = UOM.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (TableMaterials.Products = ProductsCatalog.Ref)
	|
	|GROUP BY
	|	TT_Level0.LineNumber,
	|	TableMaterials.Specification,
	|	TableMaterials.Products,
	|	TableMaterials.Characteristic,
	|	TableMaterials.MeasurementUnit,
	|	TT_Level0.SubcontractorParent,
	|	TT_Level0.ReplenishmentMethodParent,
	|	ProductsCatalog.Subcontractor,
	|	ProductsCatalog.ReplenishmentMethod
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Level1.LineNumber AS LineNumber,
	|	TableMaterials.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(TableMaterials.Quantity / TableMaterials.Ref.Quantity * CASE
	|			WHEN TableMaterials.CalculationMethod = VALUE(Enum.BOMContentCalculationMethod.Proportional)
	|				THEN ISNULL(UOM.Factor, 1) * TT_Level1.Quantity
	|			ELSE CASE
	|					WHEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level1.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) = ISNULL(UOM.Factor, 1) * TT_Level1.Quantity / TableMaterials.Ref.Quantity
	|						THEN ISNULL(UOM.Factor, 1) * TT_Level1.Quantity
	|					WHEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level1.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) > ISNULL(UOM.Factor, 1) * TT_Level1.Quantity / TableMaterials.Ref.Quantity
	|						THEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level1.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) * TableMaterials.Ref.Quantity
	|					ELSE ((CAST(ISNULL(UOM.Factor, 1) * TT_Level1.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) + 1) * TableMaterials.Ref.Quantity
	|				END
	|		END) AS Quantity,
	|	TableMaterials.Specification AS Specification,
	|	TableMaterials.MeasurementUnit AS MeasurementUnit,
	|	TT_Level1.SubcontractorParent AS SubcontractorParent,
	|	TT_Level1.ReplenishmentMethodParent AS ReplenishmentMethodParent,
	|	ProductsCatalog.Subcontractor AS SubcontractorChild,
	|	ProductsCatalog.ReplenishmentMethod AS ReplenishmentMethodChild
	|INTO TT_Level2
	|FROM
	|	TT_Level1 AS TT_Level1
	|		INNER JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TT_Level1.Specification = TableMaterials.Ref
	|			AND (TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|			AND (TT_Level1.SubcontractorParent = TT_Level1.SubcontractorChild)
	|			AND (TT_Level1.ReplenishmentMethodParent = TT_Level1.ReplenishmentMethodChild)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON TT_Level1.MeasurementUnit = UOM.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (TableMaterials.Products = ProductsCatalog.Ref)
	|
	|GROUP BY
	|	TT_Level1.LineNumber,
	|	TableMaterials.Specification,
	|	TableMaterials.Products,
	|	TableMaterials.Characteristic,
	|	TableMaterials.MeasurementUnit,
	|	TT_Level1.SubcontractorParent,
	|	TT_Level1.ReplenishmentMethodParent,
	|	ProductsCatalog.Subcontractor,
	|	ProductsCatalog.ReplenishmentMethod
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Level2.LineNumber AS LineNumber,
	|	TableMaterials.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(TableMaterials.Quantity / TableMaterials.Ref.Quantity * CASE
	|			WHEN TableMaterials.CalculationMethod = VALUE(Enum.BOMContentCalculationMethod.Proportional)
	|				THEN ISNULL(UOM.Factor, 1) * TT_Level2.Quantity
	|			ELSE CASE
	|					WHEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level2.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) = ISNULL(UOM.Factor, 1) * TT_Level2.Quantity / TableMaterials.Ref.Quantity
	|						THEN ISNULL(UOM.Factor, 1) * TT_Level2.Quantity
	|					WHEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level2.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) > ISNULL(UOM.Factor, 1) * TT_Level2.Quantity / TableMaterials.Ref.Quantity
	|						THEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level2.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) * TableMaterials.Ref.Quantity
	|					ELSE ((CAST(ISNULL(UOM.Factor, 1) * TT_Level2.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) + 1) * TableMaterials.Ref.Quantity
	|				END
	|		END) AS Quantity,
	|	TableMaterials.Specification AS Specification,
	|	TableMaterials.MeasurementUnit AS MeasurementUnit,
	|	TT_Level2.SubcontractorParent AS SubcontractorParent,
	|	TT_Level2.ReplenishmentMethodParent AS ReplenishmentMethodParent,
	|	ProductsCatalog.Subcontractor AS SubcontractorChild,
	|	ProductsCatalog.ReplenishmentMethod AS ReplenishmentMethodChild
	|INTO TT_Level3
	|FROM
	|	TT_Level2 AS TT_Level2
	|		INNER JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TT_Level2.Specification = TableMaterials.Ref
	|			AND (TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|			AND (TT_Level2.SubcontractorParent = TT_Level2.SubcontractorChild)
	|			AND (TT_Level2.ReplenishmentMethodParent = TT_Level2.ReplenishmentMethodChild)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON TT_Level2.MeasurementUnit = UOM.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (TableMaterials.Products = ProductsCatalog.Ref)
	|
	|GROUP BY
	|	TT_Level2.LineNumber,
	|	TableMaterials.Products,
	|	TableMaterials.Characteristic,
	|	TableMaterials.Specification,
	|	TableMaterials.MeasurementUnit,
	|	TT_Level2.SubcontractorParent,
	|	TT_Level2.ReplenishmentMethodParent,
	|	ProductsCatalog.Subcontractor,
	|	ProductsCatalog.ReplenishmentMethod
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Level3.LineNumber AS LineNumber,
	|	TableMaterials.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(TableMaterials.Quantity / TableMaterials.Ref.Quantity * CASE
	|			WHEN TableMaterials.CalculationMethod = VALUE(Enum.BOMContentCalculationMethod.Proportional)
	|				THEN ISNULL(UOM.Factor, 1) * TT_Level3.Quantity
	|			ELSE CASE
	|					WHEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level3.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) = ISNULL(UOM.Factor, 1) * TT_Level3.Quantity / TableMaterials.Ref.Quantity
	|						THEN ISNULL(UOM.Factor, 1) * TT_Level3.Quantity
	|					WHEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level3.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) > ISNULL(UOM.Factor, 1) * TT_Level3.Quantity / TableMaterials.Ref.Quantity
	|						THEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level3.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) * TableMaterials.Ref.Quantity
	|					ELSE ((CAST(ISNULL(UOM.Factor, 1) * TT_Level3.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) + 1) * TableMaterials.Ref.Quantity
	|				END
	|		END) AS Quantity,
	|	TableMaterials.MeasurementUnit AS MeasurementUnit,
	|	TT_Level3.SubcontractorParent AS SubcontractorParent,
	|	TT_Level3.ReplenishmentMethodParent AS ReplenishmentMethodParent,
	|	ProductsCatalog.Subcontractor AS SubcontractorChild,
	|	ProductsCatalog.ReplenishmentMethod AS ReplenishmentMethodChild
	|INTO TT_Level4
	|FROM
	|	TT_Level3 AS TT_Level3
	|		INNER JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TT_Level3.Specification = TableMaterials.Ref
	|			AND (TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|			AND (TT_Level3.SubcontractorParent = TT_Level3.SubcontractorChild)
	|			AND (TT_Level3.ReplenishmentMethodParent = TT_Level3.ReplenishmentMethodChild)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON TT_Level3.MeasurementUnit = UOM.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (TableMaterials.Products = ProductsCatalog.Ref)
	|
	|GROUP BY
	|	TT_Level3.LineNumber,
	|	TableMaterials.Products,
	|	TableMaterials.Characteristic,
	|	TableMaterials.MeasurementUnit,
	|	TT_Level3.SubcontractorParent,
	|	TT_Level3.ReplenishmentMethodParent,
	|	ProductsCatalog.Subcontractor,
	|	ProductsCatalog.ReplenishmentMethod
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Level1.LineNumber AS LineNumber,
	|	TT_Level1.Products AS Products,
	|	TT_Level1.Characteristic AS Characteristic,
	|	TT_Level1.Quantity AS Quantity,
	|	TT_Level1.MeasurementUnit AS MeasurementUnit
	|INTO TT_Components
	|FROM
	|	TT_Level1 AS TT_Level1
	|WHERE
	|	NOT(TT_Level1.SubcontractorParent = TT_Level1.SubcontractorChild
	|				AND TT_Level1.ReplenishmentMethodParent = TT_Level1.ReplenishmentMethodChild
	|				AND TT_Level1.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT
	|	TT_Level2.LineNumber,
	|	TT_Level2.Products,
	|	TT_Level2.Characteristic,
	|	TT_Level2.Quantity,
	|	TT_Level2.MeasurementUnit
	|FROM
	|	TT_Level2 AS TT_Level2
	|WHERE
	|	NOT(TT_Level2.SubcontractorParent = TT_Level2.SubcontractorChild
	|				AND TT_Level2.ReplenishmentMethodParent = TT_Level2.ReplenishmentMethodChild
	|				AND TT_Level2.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT
	|	TT_Level3.LineNumber,
	|	TT_Level3.Products,
	|	TT_Level3.Characteristic,
	|	TT_Level3.Quantity,
	|	TT_Level3.MeasurementUnit
	|FROM
	|	TT_Level3 AS TT_Level3
	|WHERE
	|	NOT(TT_Level3.SubcontractorParent = TT_Level3.SubcontractorChild
	|				AND TT_Level3.ReplenishmentMethodParent = TT_Level3.ReplenishmentMethodChild
	|				AND TT_Level3.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT
	|	TT_Level4.LineNumber,
	|	TT_Level4.Products,
	|	TT_Level4.Characteristic,
	|	TT_Level4.Quantity,
	|	TT_Level4.MeasurementUnit
	|FROM
	|	TT_Level4 AS TT_Level4
	|WHERE
	|	NOT(TT_Level4.SubcontractorParent = TT_Level4.SubcontractorChild
	|				AND TT_Level4.ReplenishmentMethodParent = TT_Level4.ReplenishmentMethodChild)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TT_Components.LineNumber) AS LineNumber,
	|	TT_Components.Products AS Products,
	|	TT_Components.Characteristic AS Characteristic,
	|	SUM(TT_Components.Quantity) AS Quantity,
	|	TT_Components.MeasurementUnit AS MeasurementUnit
	|FROM
	|	TT_Components AS TT_Components
	|
	|GROUP BY
	|	TT_Components.Products,
	|	TT_Components.Characteristic,
	|	TT_Components.MeasurementUnit
	|
	|ORDER BY
	|	LineNumber,
	|	Products,
	|	Characteristic";
	
	Query.SetParameter("TableProduction", Products.Unload());
	Query.SetParameter("UseCharacteristics", Constants.UseCharacteristics.Get());
	Query.SetParameter("Subcontracting", Enums.InventoryReplenishmentMethods.Processing);

	Inventory.Load(Query.Execute().Unload());

EndProcedure

// begin Drive.FullVersion
Function CurrentDefaultVATRate()
	
	DocumentDate = ?(ValueIsFilled(Date), Date, CurrentSessionDate());
	VATTaxation = DriveServer.CounterpartyVATTaxation(Counterparty, DriveServer.VATTaxation(Company, DocumentDate));
	
	If VATTaxation <> Enums.VATTaxationTypes.SubjectToVAT Then
		
		If VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;
		
	Else
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(DocumentDate, Company);
	EndIf;
	
	Return DefaultVATRate;
	
EndFunction

Function BasisSubcontractorOrderIssued(DocRef)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ManufacturingOperation.BasisDocument AS BasisDocument
	|INTO ManufacturingOperation
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|WHERE
	|	ManufacturingOperation.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorOrderReceived.Ref AS Ref
	|FROM
	|	ManufacturingOperation AS ManufacturingOperation
	|		LEFT JOIN Document.ProductionOrder AS ProductionOrder
	|		ON ManufacturingOperation.BasisDocument = ProductionOrder.Ref
	|		INNER JOIN Document.SubcontractorOrderReceived AS SubcontractorOrderReceived
	|		ON (ProductionOrder.BasisDocument = SubcontractorOrderReceived.Ref)";
			
	Query.Parameters.Insert("Ref", DocRef);
	QueryResult = Query.Execute();
	SelectionDetailRecords = QueryResult.Select();
	
	SubcontractorOrderIssued = Documents.SubcontractorOrderIssued.EmptyRef();
	
	While SelectionDetailRecords.Next() Do
		SubcontractorOrderIssued = SelectionDetailRecords.Ref;
	EndDo;
	
	Return SubcontractorOrderIssued;
EndFunction
// end Drive.FullVersion

#EndRegion

#EndIf