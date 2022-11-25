#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure FillReservesInfoByRules(FillingParameters) Export
	
	ExistingReserves = FillingParameters.ExistingReserves;
	WithoutReserves = FillingParameters.WithoutReserves;
	
	RowsToDel = New Array;
	
	For Each InventoryTableRow In Inventory Do
		
		InventoryTableRow.NewReservePlace = Undefined;
		
		If ValueIsFilled(InventoryTableRow.OriginalReservePlace) Then
			
			If Not ExistingReserves Then
				RowsToDel.Add(InventoryTableRow);
			EndIf;
			
		ElsIf Not WithoutReserves Then
			
			RowsToDel.Add(InventoryTableRow);
			
		EndIf;
		
	EndDo;
	
	For Each RowToDel In RowsToDel Do
		Inventory.Delete(RowToDel);
	EndDo;
	
EndProcedure

Procedure AllocateNewLocation() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	&Company AS Company,
	|	&StructuralUnit AS StructuralUnit,
	|	InventoryReservationInventory.Products AS Products,
	|	InventoryReservationInventory.Characteristic AS Characteristic,
	|	InventoryReservationInventory.Batch AS Batch
	|INTO TT_Inventory
	|FROM
	|	&TableInventory AS InventoryReservationInventory
	|WHERE
	|	(InventoryReservationInventory.OriginalReservePlace = UNDEFINED
	|			OR InventoryReservationInventory.OriginalReservePlace = VALUE(Document.PurchaseOrder.EmptyRef)
	|			OR InventoryReservationInventory.OriginalReservePlace = VALUE(Catalog.BusinessUnits.EmptyRef)
	|			OR InventoryReservationInventory.OriginalReservePlace = VALUE(Document.TransferOrder.EmptyRef)
	|			OR InventoryReservationInventory.OriginalReservePlace = VALUE(Document.SalesOrder.EmptyRef)
	|			OR InventoryReservationInventory.OriginalReservePlace = VALUE(Document.ProductionOrder.EmptyRef)
	|			OR InventoryReservationInventory.OriginalReservePlace = VALUE(Document.ManufacturingOperation.EmptyRef))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrdersBalance.Company AS Company,
	|	PurchaseOrdersBalance.Products AS Products,
	|	PurchaseOrdersBalance.Characteristic AS Characteristic,
	|	PurchaseOrdersBalance.PurchaseOrder AS PurchaseOrder,
	|	PurchaseOrdersBalance.QuantityBalance AS QuantityBalance
	|INTO TT_PurchaseOrdersBalance
	|FROM
	|	AccumulationRegister.PurchaseOrders.Balance(
	|			,
	|			(Company, Products, Characteristic) IN
	|				(SELECT
	|					TT_Inventory.Company,
	|					TT_Inventory.Products,
	|					TT_Inventory.Characteristic
	|				FROM
	|					TT_Inventory AS TT_Inventory)) AS PurchaseOrdersBalance
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	KitOrdersBalance.Company AS Company,
	|	KitOrdersBalance.Products AS Products,
	|	KitOrdersBalance.Characteristic AS Characteristic,
	|	KitOrdersBalance.KitOrder AS KitOrder,
	|	KitOrdersBalance.QuantityBalance AS QuantityBalance
	|INTO TT_KitOrdersBalance
	|FROM
	|	AccumulationRegister.KitOrders.Balance(
	|			,
	|			(Company, Products, Characteristic) IN
	|				(SELECT
	|					TT_Inventory.Company,
	|					TT_Inventory.Products,
	|					TT_Inventory.Characteristic
	|				FROM
	|					TT_Inventory AS TT_Inventory)) AS KitOrdersBalance
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorOrdersIssuedBalance.Company AS Company,
	|	SubcontractorOrdersIssuedBalance.Products AS Products,
	|	SubcontractorOrdersIssuedBalance.Characteristic AS Characteristic,
	|	SubcontractorOrdersIssuedBalance.SubcontractorOrder AS SubcontractorOrder,
	|	SubcontractorOrdersIssuedBalance.QuantityBalance AS QuantityBalance
	|INTO TT_SubcontractorOrdersIssuedBalance
	|FROM
	|	AccumulationRegister.SubcontractorOrdersIssued.Balance(
	|			,
	|			(Company, Products, Characteristic) IN
	|				(SELECT
	|					TT_Inventory.Company,
	|					TT_Inventory.Products,
	|					TT_Inventory.Characteristic
	|				FROM
	|					TT_Inventory AS TT_Inventory)) AS SubcontractorOrdersIssuedBalance
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Priority,
	|	InventoryInWarehousesBalance.Products AS Products,
	|	InventoryInWarehousesBalance.Characteristic AS Characteristic,
	|	InventoryInWarehousesBalance.Batch AS Batch,
	|	InventoryInWarehousesBalance.StructuralUnit AS StructuralUnit,
	|	InventoryInWarehousesBalance.QuantityBalance AS Quantity
	|INTO TT_Balance
	|FROM
	|	AccumulationRegister.InventoryInWarehouses.Balance(
	|			,
	|			(Company, Products, Characteristic, Batch, StructuralUnit) IN
	|				(SELECT
	|					TT_Inventory.Company,
	|					TT_Inventory.Products,
	|					TT_Inventory.Characteristic,
	|					TT_Inventory.Batch,
	|					TT_Inventory.StructuralUnit
	|				FROM
	|					TT_Inventory AS TT_Inventory)) AS InventoryInWarehousesBalance
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	ReservedProducts.Products,
	|	ReservedProducts.Characteristic,
	|	ReservedProducts.Batch,
	|	ReservedProducts.StructuralUnit,
	|	-ReservedProducts.QuantityBalance
	|FROM
	|	AccumulationRegister.ReservedProducts.Balance(
	|			,
	|			(Company, Products, Characteristic, Batch, StructuralUnit) IN
	|				(SELECT
	|					TT_Inventory.Company AS Company,
	|					TT_Inventory.Products AS Products,
	|					TT_Inventory.Characteristic AS Characteristic,
	|					TT_Inventory.Batch AS Batch,
	|					TT_Inventory.StructuralUnit
	|				FROM
	|					TT_Inventory AS TT_Inventory)) AS ReservedProducts
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	InventoryInWarehouses.Products,
	|	InventoryInWarehouses.Characteristic,
	|	InventoryInWarehouses.Batch,
	|	InventoryInWarehouses.StructuralUnit,
	|	CASE
	|		WHEN InventoryInWarehouses.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN ISNULL(InventoryInWarehouses.Quantity, 0)
	|		ELSE -ISNULL(InventoryInWarehouses.Quantity, 0)
	|	END
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN AccumulationRegister.InventoryInWarehouses AS InventoryInWarehouses
	|		ON TT_Inventory.Company = InventoryInWarehouses.Company
	|			AND TT_Inventory.StructuralUnit = InventoryInWarehouses.StructuralUnit
	|			AND TT_Inventory.Products = InventoryInWarehouses.Products
	|			AND TT_Inventory.Characteristic = InventoryInWarehouses.Characteristic
	|			AND TT_Inventory.Batch = InventoryInWarehouses.Batch
	|WHERE
	|	InventoryInWarehouses.Recorder = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	InventoryInWarehousesBalance.Products,
	|	InventoryInWarehousesBalance.Characteristic,
	|	InventoryInWarehousesBalance.Batch,
	|	InventoryInWarehousesBalance.StructuralUnit,
	|	InventoryInWarehousesBalance.QuantityBalance
	|FROM
	|	AccumulationRegister.InventoryInWarehouses.Balance(
	|			,
	|			(Company, Products, Characteristic, Batch) IN
	|					(SELECT
	|						TT_Inventory.Company,
	|						TT_Inventory.Products,
	|						TT_Inventory.Characteristic,
	|						TT_Inventory.Batch
	|					FROM
	|						TT_Inventory AS TT_Inventory)
	|				AND StructuralUnit <> &StructuralUnit) AS InventoryInWarehousesBalance
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	InventoryInWarehouses.Products,
	|	InventoryInWarehouses.Characteristic,
	|	InventoryInWarehouses.Batch,
	|	InventoryInWarehouses.StructuralUnit,
	|	CASE
	|		WHEN InventoryInWarehouses.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN ISNULL(InventoryInWarehouses.Quantity, 0)
	|		ELSE -ISNULL(InventoryInWarehouses.Quantity, 0)
	|	END
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN AccumulationRegister.InventoryInWarehouses AS InventoryInWarehouses
	|		ON TT_Inventory.Company = InventoryInWarehouses.Company
	|			AND TT_Inventory.StructuralUnit <> InventoryInWarehouses.StructuralUnit
	|			AND TT_Inventory.Products = InventoryInWarehouses.Products
	|			AND TT_Inventory.Characteristic = InventoryInWarehouses.Characteristic
	|			AND TT_Inventory.Batch = InventoryInWarehouses.Batch
	|WHERE
	|	InventoryInWarehouses.Recorder = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	ReservedProducts.Products,
	|	ReservedProducts.Characteristic,
	|	ReservedProducts.Batch,
	|	ReservedProducts.StructuralUnit,
	|	-ReservedProducts.QuantityBalance
	|FROM
	|	AccumulationRegister.ReservedProducts.Balance(
	|			,
	|			(Company, Products, Characteristic, Batch) IN
	|					(SELECT
	|						TT_Inventory.Company AS Company,
	|						TT_Inventory.Products AS Products,
	|						TT_Inventory.Characteristic AS Characteristic,
	|						TT_Inventory.Batch AS Batch
	|					FROM
	|						TT_Inventory AS TT_Inventory)
	|				AND StructuralUnit <> &StructuralUnit) AS ReservedProducts
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	TT_PurchaseOrdersBalance.Products,
	|	TT_PurchaseOrdersBalance.Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef),
	|	TT_PurchaseOrdersBalance.PurchaseOrder,
	|	TT_PurchaseOrdersBalance.QuantityBalance
	|FROM
	|	TT_PurchaseOrdersBalance AS TT_PurchaseOrdersBalance
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	BackordersBalance.Products,
	|	BackordersBalance.Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef),
	|	BackordersBalance.SupplySource,
	|	-BackordersBalance.QuantityBalance
	|FROM
	|	AccumulationRegister.Backorders.Balance(
	|			,
	|			(Company, Products, Characteristic, SupplySource) IN
	|				(SELECT
	|					TT_PurchaseOrdersBalance.Company,
	|					TT_PurchaseOrdersBalance.Products,
	|					TT_PurchaseOrdersBalance.Characteristic,
	|					TT_PurchaseOrdersBalance.PurchaseOrder
	|				FROM
	|					TT_PurchaseOrdersBalance AS TT_PurchaseOrdersBalance)) AS BackordersBalance
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	Backorders.Products,
	|	Backorders.Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef),
	|	Backorders.SupplySource,
	|	CASE
	|		WHEN Backorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN ISNULL(Backorders.Quantity, 0)
	|		ELSE -ISNULL(Backorders.Quantity, 0)
	|	END
	|FROM
	|	TT_PurchaseOrdersBalance AS TT_PurchaseOrdersBalance
	|		INNER JOIN AccumulationRegister.Backorders AS Backorders
	|		ON TT_PurchaseOrdersBalance.Company = Backorders.Company
	|			AND TT_PurchaseOrdersBalance.Products = Backorders.Products
	|			AND TT_PurchaseOrdersBalance.Characteristic = Backorders.Characteristic
	|			AND TT_PurchaseOrdersBalance.PurchaseOrder = Backorders.SupplySource
	|WHERE
	|	Backorders.Recorder = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	TT_KitOrdersBalance.Products,
	|	TT_KitOrdersBalance.Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef),
	|	TT_KitOrdersBalance.KitOrder,
	|	TT_KitOrdersBalance.QuantityBalance
	|FROM
	|	TT_KitOrdersBalance AS TT_KitOrdersBalance
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	BackordersBalance.Products,
	|	BackordersBalance.Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef),
	|	BackordersBalance.SupplySource,
	|	-BackordersBalance.QuantityBalance
	|FROM
	|	AccumulationRegister.Backorders.Balance(
	|			,
	|			(Company, Products, Characteristic, SupplySource) IN
	|				(SELECT
	|					TT_KitOrdersBalance.Company,
	|					TT_KitOrdersBalance.Products,
	|					TT_KitOrdersBalance.Characteristic,
	|					TT_KitOrdersBalance.KitOrder
	|				FROM
	|					TT_KitOrdersBalance AS TT_KitOrdersBalance)) AS BackordersBalance
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	Backorders.Products,
	|	Backorders.Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef),
	|	Backorders.SupplySource,
	|	CASE
	|		WHEN Backorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN ISNULL(Backorders.Quantity, 0)
	|		ELSE -ISNULL(Backorders.Quantity, 0)
	|	END
	|FROM
	|	TT_KitOrdersBalance AS TT_KitOrdersBalance
	|		INNER JOIN AccumulationRegister.Backorders AS Backorders
	|		ON TT_KitOrdersBalance.Company = Backorders.Company
	|			AND TT_KitOrdersBalance.Products = Backorders.Products
	|			AND TT_KitOrdersBalance.Characteristic = Backorders.Characteristic
	|			AND TT_KitOrdersBalance.KitOrder = Backorders.SupplySource
	|WHERE
	|	Backorders.Recorder = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	TT_SubcontractorOrdersIssuedBalance.Products,
	|	TT_SubcontractorOrdersIssuedBalance.Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef),
	|	TT_SubcontractorOrdersIssuedBalance.SubcontractorOrder,
	|	TT_SubcontractorOrdersIssuedBalance.QuantityBalance
	|FROM
	|	TT_SubcontractorOrdersIssuedBalance AS TT_SubcontractorOrdersIssuedBalance
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	BackordersBalance.Products,
	|	BackordersBalance.Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef),
	|	BackordersBalance.SupplySource,
	|	-BackordersBalance.QuantityBalance
	|FROM
	|	AccumulationRegister.Backorders.Balance(
	|			,
	|			(Company, Products, Characteristic, SupplySource) IN
	|				(SELECT
	|					TT_SubcontractorOrdersIssuedBalance.Company,
	|					TT_SubcontractorOrdersIssuedBalance.Products,
	|					TT_SubcontractorOrdersIssuedBalance.Characteristic,
	|					TT_SubcontractorOrdersIssuedBalance.SubcontractorOrder
	|				FROM
	|					TT_SubcontractorOrdersIssuedBalance AS TT_SubcontractorOrdersIssuedBalance)) AS BackordersBalance
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	Backorders.Products,
	|	Backorders.Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef),
	|	Backorders.SupplySource,
	|	CASE
	|		WHEN Backorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN ISNULL(Backorders.Quantity, 0)
	|		ELSE -ISNULL(Backorders.Quantity, 0)
	|	END
	|FROM
	|	TT_SubcontractorOrdersIssuedBalance AS TT_SubcontractorOrdersIssuedBalance
	|		INNER JOIN AccumulationRegister.Backorders AS Backorders
	|		ON TT_SubcontractorOrdersIssuedBalance.Company = Backorders.Company
	|			AND TT_SubcontractorOrdersIssuedBalance.Products = Backorders.Products
	|			AND TT_SubcontractorOrdersIssuedBalance.Characteristic = Backorders.Characteristic
	|			AND TT_SubcontractorOrdersIssuedBalance.SubcontractorOrder = Backorders.SupplySource
	|WHERE
	|	Backorders.Recorder = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Balances.Priority AS Priority,
	|	TT_Balances.Products AS Products,
	|	TT_Balances.Characteristic AS Characteristic,
	|	TT_Balances.Batch AS Batch,
	|	TT_Balances.StructuralUnit AS StructuralUnit,
	|	SUM(TT_Balances.Quantity) AS Quantity
	|FROM
	|	TT_Balance AS TT_Balances
	|
	|GROUP BY
	|	TT_Balances.Products,
	|	TT_Balances.Characteristic,
	|	TT_Balances.Batch,
	|	TT_Balances.StructuralUnit,
	|	TT_Balances.Priority
	|
	|HAVING
	|	SUM(TT_Balances.Quantity) > 0
	|
	|ORDER BY
	|	TT_Balances.Priority";
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("TableInventory", Inventory.Unload(, "Products, Characteristic, Batch, OriginalReservePlace"));
	Query.SetParameter("StructuralUnit", SalesOrderStructuralUnit());
	
	QueryResult = Query.Execute();
	
	AllocateInventoryNewLocation(QueryResult.Unload());
	
EndProcedure

#EndRegion

#Region EventHandlers

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.SalesOrder") Then
		
		FillBySalesOrder(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.WorkOrder") Then
		
		FillByWorkOrder(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.TransferOrder") Then
		
		FillByTransferOrder(FillingData);
		
	// begin Drive.FullVersion
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ManufacturingOperation") Then
		
		FillByWIP(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder") Then
		
		FillByProductionOrder(FillingData);
	// end Drive.FullVersion
	
	EndIf;
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		If TypeOf(FillingData) = Type("Structure") 
			And FillingData.Property("Basis") Then
			GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData.Basis);
		Else
			GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
		EndIf;
	EndIf;
	
EndProcedure

// IN handler of document event FillCheckProcessing,
// checked attributes are being copied and reset
// to exclude a standard platform fill check and subsequent check by embedded language tools.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)

	For Each InventoryTableRow In Inventory Do
		
		If Not ValueIsFilled(InventoryTableRow.OriginalReservePlace)
			AND Not ValueIsFilled(InventoryTableRow.NewReservePlace) Then
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				NStr("en = 'Initial place of reserve is not specified.'; ru = 'Первоначальное место резервирования не указано.';pl = 'Nie określono początkowego miejsca rezerwy.';es_ES = 'No se especifica el lugar inicial de reserva.';es_CO = 'No se especifica el lugar inicial de reserva.';tr = 'Rezervin ilk yeri belirtilmedi.';it = 'Il luogo iniziale della riserva non è specificato.';de = 'Ursprünglicher Ort der Reserve ist nicht angegeben.'"),
				"Inventory",
				InventoryTableRow.LineNumber,
				"OriginalReservePlace",
				Cancel);
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				NStr("en = 'New place of reserve is not specified.'; ru = 'Новое место резервирования не указано.';pl = 'Nie określono nowego miejsca rezerwy.';es_ES = 'No se especifica el nuevo lugar de reserva.';es_CO = 'No se especifica el nuevo lugar de reserva.';tr = 'Rezervin yeni yeri belirtilmedi.';it = 'Il nuovo luogo di riserva non è specificato.';de = 'Neuer Ort der Reserve ist nicht angegeben.'"),
				"Inventory",
				InventoryTableRow.LineNumber,
				"NewReservePlace",
				Cancel);
			
		EndIf;
		
	EndDo;	
	
EndProcedure

// The event handler PostingProcessor of a document includes:
// - deletion of document register records,
// - header structure of required attribute document is formed,
// - temporary table is formed by tabular section Products,
// - product receipt in storage places,
// - free balances receipt of products in storage places,
// - product cost receipt in storage places,
// - document posting creation.
//
Procedure Posting(Cancel, PostingMode)
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.InventoryReservation.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectBackorders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectReservedProducts(AdditionalProperties, RegisterRecords, Cancel);

	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);

	// Control
	Documents.InventoryReservation.RunControl(Ref, AdditionalProperties, Cancel);

	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.InventoryReservation.RunControl(Ref, AdditionalProperties, Cancel, True);

EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

#EndRegion

#Region Private

Procedure FillBySalesOrder(FillingData)
	
	// Header filling.
	SalesOrder = FillingData;
	AttributeValues = Common.ObjectAttributesValues(FillingData, New Structure("Company, OrderState, Closed, Posted"));
	
	Documents.SalesOrder.CheckAbilityOfEnteringBySalesOrder(FillingData, AttributeValues);
	Company = AttributeValues.Company;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text = BalanceTableQueryText() +
	"SELECT ALLOWED
	|	SalesOrder.OperationKind AS OperationKind,
	|	SalesOrder.Inventory.(
	|		Products AS Products,
	|		Products.ProductsType AS ProductsType,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		MeasurementUnit AS MeasurementUnit,
	|		Quantity AS Quantity,
	|		CASE
	|			WHEN VALUETYPE(SalesOrder.Inventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE SalesOrder.Inventory.MeasurementUnit.Factor
	|		END AS Factor
	|	),
	|	SalesOrder.Materials.(
	|		Products AS Products,
	|		Products.ProductsType AS ProductsType,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		MeasurementUnit AS MeasurementUnit,
	|		Quantity AS Quantity,
	|		CASE
	|			WHEN VALUETYPE(SalesOrder.Materials.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE SalesOrder.Materials.MeasurementUnit.Factor
	|		END AS Factor
	|	)
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("Products,Characteristic");
	
	Inventory.Clear();
	Selection = ResultsArray[1].Select();
	Selection.Next();
	
	FillInventoryByDocument(Selection.Inventory.Unload(), BalanceTable);
	
EndProcedure

Procedure FillByWorkOrder(FillingData)
	
	// Header filling.
	SalesOrder = FillingData;
	AttributeValues = Common.ObjectAttributesValues(FillingData, New Structure("Company, OrderState, Closed, Posted"));
	
	Documents.WorkOrder.CheckAbilityOfEnteringByWorkOrder(FillingData, AttributeValues);
	Company = AttributeValues.Company;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text = BalanceTableQueryText() +
	"SELECT ALLOWED
	|	WorkOrder.Inventory.(
	|		Products AS Products,
	|		Products.ProductsType AS ProductsType,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		MeasurementUnit AS MeasurementUnit,
	|		Quantity AS Quantity,
	|		CASE
	|			WHEN VALUETYPE(WorkOrder.Inventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE WorkOrder.Inventory.MeasurementUnit.Factor
	|		END AS Factor
	|	) AS Inventory,
	|	WorkOrder.Materials.(
	|		Products AS Products,
	|		Products.ProductsType AS ProductsType,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		MeasurementUnit AS MeasurementUnit,
	|		Quantity AS Quantity,
	|		CASE
	|			WHEN VALUETYPE(WorkOrder.Materials.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE WorkOrder.Materials.MeasurementUnit.Factor
	|		END AS Factor
	|	) AS Materials
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|WHERE
	|	WorkOrder.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("Products,Characteristic");
	
	Inventory.Clear();
	Selection = ResultsArray[1].Select();
	Selection.Next();
	
	FillInventoryByDocument(Selection.Inventory.Unload(), BalanceTable);
	FillInventoryByDocument(Selection.Materials.Unload(), BalanceTable);
	
EndProcedure

Procedure FillByTransferOrder(FillingData)
	
	// Header filling.
	SalesOrder = FillingData;
	AttributeValues = Common.ObjectAttributesValues(FillingData, New Structure("Company, OperationKind, OrderState, Closed, Posted"));
	
	Documents.TransferOrder.CheckAbilityOfEnteringByTransferOrder(FillingData, AttributeValues);
	Company = AttributeValues.Company;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text = BalanceTableQueryText() +
	"SELECT ALLOWED
	|	TransferOrderInventory.Products AS Products,
	|	TransferOrderInventory.Products.ProductsType AS ProductsType,
	|	TransferOrderInventory.Characteristic AS Characteristic,
	|	TransferOrderInventory.Batch AS Batch,
	|	TransferOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN VALUETYPE(TransferOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE TransferOrderInventory.MeasurementUnit.Factor
	|	END AS Factor,
	|	TransferOrderInventory.Quantity AS Quantity,
	|	TransferOrder.StructuralUnitReserve AS NewReservePlace
	|FROM
	|	Document.TransferOrder.Inventory AS TransferOrderInventory
	|		INNER JOIN Document.TransferOrder AS TransferOrder
	|		ON TransferOrderInventory.Ref = TransferOrder.Ref
	|WHERE
	|	TransferOrder.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("Products,Characteristic");
	
	Inventory.Clear();
	
	InventoryTable = ResultsArray[1].Unload();
	
	FillInventoryByDocument(InventoryTable, BalanceTable);
	
EndProcedure

// begin Drive.FullVersion
Procedure FillByProductionOrder(FillingData)
	
	// Header filling.
	SalesOrder = FillingData;
	AttributeValues = Common.ObjectAttributesValues(FillingData, New Structure("Company, OrderState, Closed, Posted"));
	
	Documents.ProductionOrder.VerifyEnteringAbilityByProductionOrder(FillingData, AttributeValues);
	Company = AttributeValues.Company;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text = BalanceTableQueryText() +
	"SELECT ALLOWED
	|	ProductionOrder.OperationKind AS OperationKind,
	|	ProductionOrder.Inventory.(
	|		Products AS Products,
	|		Products.ProductsType AS ProductsType,
	|		Characteristic AS Characteristic,
	|		MeasurementUnit AS MeasurementUnit,
	|		Quantity AS Quantity,
	|		CASE
	|			WHEN VALUETYPE(ProductionOrder.Inventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE ProductionOrder.Inventory.MeasurementUnit.Factor
	|		END AS Factor
	|	),
	|	ProductionOrder.Products.(
	|		Products AS Products,
	|		Products.ProductsType AS ProductsType,
	|		Characteristic AS Characteristic,
	|		MeasurementUnit AS MeasurementUnit,
	|		Quantity AS Quantity,
	|		CASE
	|			WHEN VALUETYPE(ProductionOrder.Products.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE ProductionOrder.Products.MeasurementUnit.Factor
	|		END AS Factor
	|	)
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|WHERE
	|	ProductionOrder.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("Products, Characteristic");
	
	Inventory.Clear();
	Selection = ResultsArray[1].Select();
	Selection.Next();
	
	TabularSectionName = ?(Selection.OperationKind = Enums.OperationTypesProductionOrder.Assembly, "Inventory", "Products");
	
	FillInventoryByDocument(Selection[TabularSectionName].Unload(), BalanceTable);
	
EndProcedure

Procedure FillByWIP(FillingData)
	
	// Header filling.
	SalesOrder = FillingData;
	AttributeValues = Common.ObjectAttributesValues(FillingData, New Structure("Company, Posted"));
	
	Documents.ManufacturingOperation.CheckAbilityOfEnteringByWorkInProgress(FillingData, AttributeValues);
	Company = AttributeValues.Company;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text = BalanceTableQueryText() +
	"SELECT ALLOWED
	|	ManufacturingOperationInventory.Products AS Products,
	|	ManufacturingOperationInventory.Products.ProductsType AS ProductsType,
	|	ManufacturingOperationInventory.Characteristic AS Characteristic,
	|	ManufacturingOperationInventory.Batch AS Batch,
	|	ManufacturingOperationInventory.MeasurementUnit AS MeasurementUnit,
	|	ManufacturingOperationInventory.Quantity AS Quantity,
	|	CASE
	|		WHEN VALUETYPE(ManufacturingOperationInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE ManufacturingOperationInventory.MeasurementUnit.Factor
	|	END AS Factor
	|FROM
	|	Document.ManufacturingOperation.Inventory AS ManufacturingOperationInventory
	|WHERE
	|	ManufacturingOperationInventory.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("Products,Characteristic");
	
	Inventory.Clear();
	
	FillInventoryByDocument(ResultsArray[1].Unload(), BalanceTable);
	
EndProcedure
// end Drive.FullVersion

Procedure FillInventoryByDocument(DocTable, BalanceTable)
	
	For Each TSRow In DocTable Do
		
		If TSRow.ProductsType <> Enums.ProductsTypes.InventoryItem Then
			Continue;
		EndIf;
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", TSRow.Products);
		StructureForSearch.Insert("Characteristic", TSRow.Characteristic);
		
		BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
		If BalanceRowsArray.Count() Then
			
			QuantityToWriteOff = TSRow.Quantity * TSRow.Factor;
			For Each RowBalances In BalanceRowsArray Do
				
				If RowBalances.Quantity > QuantityToWriteOff Then
					
					NewRow = Inventory.Add();
					FillPropertyValues(NewRow, RowBalances);
					NewRow.Quantity = QuantityToWriteOff / TSRow.Factor;
					NewRow.MeasurementUnit = TSRow.MeasurementUnit;
					NewRow.NewReservePlace = NewRow.OriginalReservePlace;
					
					RowBalances.Quantity = RowBalances.Quantity - QuantityToWriteOff;
					QuantityToWriteOff = 0;
					
				Else
					
					NewRow = Inventory.Add();
					FillPropertyValues(NewRow, RowBalances);
					NewRow.Quantity = RowBalances.Quantity / TSRow.Factor;
					NewRow.MeasurementUnit = TSRow.MeasurementUnit;
					NewRow.NewReservePlace = NewRow.OriginalReservePlace;
					
					QuantityToWriteOff = QuantityToWriteOff - RowBalances.Quantity;
					
					BalanceTable.Delete(RowBalances);
					
				EndIf;
				
			EndDo;
			
			If QuantityToWriteOff > 0 Then
				
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, TSRow);
				NewRow.Quantity = QuantityToWriteOff / TSRow.Factor
				
			EndIf;
			
		Else
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, TSRow);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function BalanceTableQueryText()
	
	QueryText = "SELECT ALLOWED
	|	OrdersBalance.OriginalPlace AS OriginalReservePlace,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	OrdersBalance.Batch AS Batch,
	|	OrdersBalance.MeasurementUnit AS MeasurementUnit,
	|	SUM(OrdersBalance.QuantityBalance) AS Quantity
	|FROM
	|	(SELECT
	|		ReservedProductsBalances.StructuralUnit AS OriginalPlace,
	|		ReservedProductsBalances.Products AS Products,
	|		ReservedProductsBalances.Characteristic AS Characteristic,
	|		ReservedProductsBalances.Batch AS Batch,
	|		ReservedProductsBalances.Products.MeasurementUnit AS MeasurementUnit,
	|		ReservedProductsBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.ReservedProducts.Balance(
	|				,
	|				SalesOrder = &BasisDocument
	|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS ReservedProductsBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		PlacementBalances.SupplySource,
	|		PlacementBalances.Products,
	|		PlacementBalances.Characteristic,
	|		VALUE(Catalog.ProductsBatches.EmptyRef),
	|		PlacementBalances.Products.MeasurementUnit,
	|		PlacementBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.Backorders.Balance(
	|				,
	|				SalesOrder = &BasisDocument
	|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS PlacementBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsReservedProducts.StructuralUnit,
	|		DocumentRegisterRecordsReservedProducts.Products,
	|		DocumentRegisterRecordsReservedProducts.Characteristic,
	|		DocumentRegisterRecordsReservedProducts.Batch,
	|		DocumentRegisterRecordsReservedProducts.Products.MeasurementUnit,
	|		CASE
	|			WHEN DocumentRegisterRecordsReservedProducts.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsReservedProducts.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsReservedProducts.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.ReservedProducts AS DocumentRegisterRecordsReservedProducts
	|	WHERE
	|		DocumentRegisterRecordsReservedProducts.Recorder = &Ref
	|		AND DocumentRegisterRecordsReservedProducts.SalesOrder = &BasisDocument
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsBackorders.SupplySource,
	|		DocumentRegisterRecordsBackorders.Products,
	|		DocumentRegisterRecordsBackorders.Characteristic,
	|		VALUE(Catalog.ProductsBatches.EmptyRef),
	|		DocumentRegisterRecordsBackorders.Products.MeasurementUnit,
	|		CASE
	|			WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
	|	WHERE
	|		DocumentRegisterRecordsBackorders.Recorder = &Ref
	|		AND DocumentRegisterRecordsBackorders.SalesOrder = &BasisDocument) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.OriginalPlace,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic,
	|	OrdersBalance.Batch,
	|	OrdersBalance.MeasurementUnit
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0";
	
	DriveClientServer.AddDelimeter(QueryText);
	
	Return QueryText;
	
EndFunction

Function SalesOrderStructuralUnit()
	
	AttributeName = "StructuralUnitReserve";
	BaseDocType = TypeOf(SalesOrder);
	
	If BaseDocType = Type("DocumentRef.TransferOrder") Then
		AttributeName = "StructuralUnit";
	// begin Drive.FullVersion
	ElsIf BaseDocType = Type("DocumentRef.ManufacturingOperation") Then
		AttributeName = "InventoryStructuralUnit";
	// end Drive.FullVersion
	EndIf;
	
	Return Common.ObjectAttributeValue(SalesOrder, AttributeName);
	
EndFunction

Procedure AllocateInventoryNewLocation(BalanceTable)
	
	InventoryTable = Inventory.Unload();
	Inventory.Clear();
	
	For Each TSRow In InventoryTable Do
		
		// 1. If "Original location" is filled - no search
		If ValueIsFilled(TSRow.OriginalReservePlace) Then
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, TSRow);
			Continue;
		EndIf;
		
		Factor = 1;
		If TypeOf(TSRow.MeasurementUnit) = Type("CatalogRef.UOM") Then
			Factor = Common.ObjectAttributeValue(TSRow.MeasurementUnit, "Factor");
		EndIf;
		
		QuantityToWriteOff = TSRow.Quantity * Factor;
		If QuantityToWriteOff > 0 Then
			
			// 2. Search for balances by product, characteristic and batch
			StructureForSearch = New Structure;
			StructureForSearch.Insert("Products", TSRow.Products);
			StructureForSearch.Insert("Characteristic", TSRow.Characteristic);
			StructureForSearch.Insert("Batch", TSRow.Batch);
			AllocateInventoreRowByBalances(TSRow, BalanceTable,StructureForSearch, QuantityToWriteOff, Factor);
			
			If QuantityToWriteOff > 0 Then
				
				// 3. Search for balances by product and characteristic
				StructureForSearch = New Structure;
				StructureForSearch.Insert("Products", TSRow.Products);
				StructureForSearch.Insert("Characteristic", TSRow.Characteristic);
				StructureForSearch.Insert("Batch", Catalogs.ProductsBatches.EmptyRef());
				AllocateInventoreRowByBalances(TSRow, BalanceTable,StructureForSearch, QuantityToWriteOff, Factor);
				
				// 4. Nothing was found - "New location" is empty
				If QuantityToWriteOff > 0 Then
					
					NewRow = Inventory.Add();
					FillPropertyValues(NewRow, TSRow);
					NewRow.NewReservePlace = Undefined;
					NewRow.Quantity = QuantityToWriteOff / Factor;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure AllocateInventoreRowByBalances(TSRow, BalanceTable, StructureForSearch, QuantityToWriteOff, Factor)
	
	BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
	If BalanceRowsArray.Count() And QuantityToWriteOff > 0 Then
		
		For Each RowBalances In BalanceRowsArray Do
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, TSRow);
			NewRow.Batch = RowBalances.Batch;
			NewRow.NewReservePlace = RowBalances.StructuralUnit;
			
			If RowBalances.Quantity > QuantityToWriteOff Then
				
				NewRow.Quantity = QuantityToWriteOff / Factor;
				RowBalances.Quantity = RowBalances.Quantity - QuantityToWriteOff;
				QuantityToWriteOff = 0;
				
			Else
				
				NewRow.Quantity = RowBalances.Quantity / Factor;
				QuantityToWriteOff = QuantityToWriteOff - RowBalances.Quantity;
				BalanceTable.Delete(RowBalances);
				
			EndIf;
			
			If QuantityToWriteOff <= 0 Then
				Break;
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
