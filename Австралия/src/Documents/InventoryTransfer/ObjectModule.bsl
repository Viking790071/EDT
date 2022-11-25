#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Procedure fills the Inventory tabular section by balances at warehouse.
//
Procedure FillInventoryByInventoryBalances() Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	InventoryInWarehousesOfBalance.Company AS Company,
	|	InventoryInWarehousesOfBalance.Products AS Products,
	|	InventoryInWarehousesOfBalance.Products.MeasurementUnit AS MeasurementUnit,
	|	InventoryInWarehousesOfBalance.Characteristic AS Characteristic,
	|	InventoryInWarehousesOfBalance.Batch AS Batch,
	|	InventoryInWarehousesOfBalance.StructuralUnit AS StructuralUnit,
	|	InventoryInWarehousesOfBalance.Cell AS Cell,
	|	SUM(InventoryInWarehousesOfBalance.QuantityBalance) AS Quantity
	|FROM
	|	(SELECT
	|		InventoryInWarehouses.Company AS Company,
	|		InventoryInWarehouses.Products AS Products,
	|		InventoryInWarehouses.Characteristic AS Characteristic,
	|		InventoryInWarehouses.Batch AS Batch,
	|		InventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|		InventoryInWarehouses.Cell AS Cell,
	|		InventoryInWarehouses.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.InventoryInWarehouses.Balance(
	|				,
	|				Company = &Company
	|					AND StructuralUnit = &StructuralUnit
	|					AND Cell = &Cell) AS InventoryInWarehouses
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventoryInWarehouses.Company,
	|		DocumentRegisterRecordsInventoryInWarehouses.Products,
	|		DocumentRegisterRecordsInventoryInWarehouses.Characteristic,
	|		DocumentRegisterRecordsInventoryInWarehouses.Batch,
	|		DocumentRegisterRecordsInventoryInWarehouses.StructuralUnit,
	|		DocumentRegisterRecordsInventoryInWarehouses.Cell,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryInWarehouses.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryInWarehouses.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryInWarehouses.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.InventoryInWarehouses AS DocumentRegisterRecordsInventoryInWarehouses
	|	WHERE
	|		DocumentRegisterRecordsInventoryInWarehouses.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventoryInWarehouses.Period <= &Period
	|		AND DocumentRegisterRecordsInventoryInWarehouses.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryInWarehousesOfBalance
	|WHERE
	|	InventoryInWarehousesOfBalance.QuantityBalance > 0
	|
	|GROUP BY
	|	InventoryInWarehousesOfBalance.Company,
	|	InventoryInWarehousesOfBalance.Products,
	|	InventoryInWarehousesOfBalance.Characteristic,
	|	InventoryInWarehousesOfBalance.Batch,
	|	InventoryInWarehousesOfBalance.StructuralUnit,
	|	InventoryInWarehousesOfBalance.Cell,
	|	InventoryInWarehousesOfBalance.Products.MeasurementUnit";
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnit);
	Query.SetParameter("Cell", Cell);
	
	Inventory.Load(Query.Execute().Unload());
	
EndProcedure

Procedure FillByTransferOrder(FillingData) Export
	
	If TypeOf(FillingData) = Type("Structure") And FillingData.Property("ArrayOfOrders") Then
		OrdersArray = FillingData.ArrayOfOrders;
	Else
		OrdersArray = New Array;
		OrdersArray.Add(FillingData);
		SalesOrder = FillingData;
		BasisDocument = FillingData;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	TransferOrder.Ref AS BasisRef,
	|	TransferOrder.Posted AS BasisPosted,
	|	TransferOrder.Closed AS Closed,
	|	TransferOrder.OrderState AS OrderState,
	|	TransferOrder.Company AS Company,
	|	TransferOrder.StructuralUnit AS StructuralUnit,
	|	TransferOrder.StructuralUnitPayee AS StructuralUnitPayee,
	|	CASE
	|		WHEN TransferOrder.OperationKind = VALUE(Enum.OperationTypesTransferOrder.WriteOffToExpenses)
	|			THEN VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|		ELSE VALUE(Enum.OperationTypesInventoryTransfer.Transfer)
	|	END AS OperationKind
	|INTO TT_TransferOrder
	|FROM
	|	Document.TransferOrder AS TransferOrder
	|WHERE
	|	TransferOrder.Ref IN(&OrdersArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_TransferOrder.BasisRef AS BasisRef,
	|	TT_TransferOrder.BasisPosted AS BasisPosted,
	|	TT_TransferOrder.Closed AS Closed,
	|	TT_TransferOrder.OrderState AS OrderState,
	|	TT_TransferOrder.Company AS Company,
	|	TT_TransferOrder.StructuralUnit AS StructuralUnit,
	|	TT_TransferOrder.StructuralUnitPayee AS StructuralUnitPayee,
	|	TT_TransferOrder.OperationKind AS OperationKind
	|FROM
	|	TT_TransferOrder AS TT_TransferOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	TransferOrders.TransferOrder AS TransferOrder
	|FROM
	|	TT_TransferOrder AS TT_TransferOrder
	|		INNER JOIN AccumulationRegister.TransferOrders AS TransferOrders
	|		ON TT_TransferOrder.BasisRef = TransferOrders.TransferOrder";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	
	QueryResults = Query.ExecuteBatch();
	
	Selection = QueryResults[1].Select();
	While Selection.Next() Do
		VerifiedAttributesValues = New Structure("OrderState, Closed, Posted",
			Selection.OrderState,
			Selection.Closed,
			Selection.BasisPosted);
		Documents.TransferOrder.CheckAbilityOfEnteringByTransferOrder(Selection.BasisRef, VerifiedAttributesValues);
	EndDo;
	
	FillPropertyValues(ThisObject, Selection);
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	DocumentData.Insert("StructuralUnitPayee", StructuralUnitPayee);
	
	Documents.InventoryTransfer.FillByTransfersOrders(DocumentData, New Structure("OrdersArray", OrdersArray), Inventory);
	
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
	ElsIf Not ValueIsFilled(SalesOrder) And OrdersTable.Count() > 0 Then
		SalesOrder = OrdersTable[0].SalesOrder;
	ElsIf OrdersArray.Count() = 1 Then
		SalesOrder = OrdersArray[0];
	EndIf;
	
	If Inventory.Count() = 0 Then
		If OrdersArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 has already been transferred.'; ru = 'Уже перемещено: %1.';pl = '%1 już zostały przekazane.';es_ES = '%1 ha sido transferido ya.';es_CO = '%1 ha sido transferido ya.';tr = '%1 zaten transfer edildi.';it = '%1 è già stato trasferito.';de = '%1 wurde bereits transferiert.'"),
				SalesOrder);
		Else
			MessageText = NStr("en = 'The selected orders have already been transferred.'; ru = 'Выбранные заказы уже перемещены.';pl = 'Wybrane zlecenia zostały już przeniesione.';es_ES = 'Las órdenes seleccionadas han sido transferidas ya.';es_CO = 'Las órdenes seleccionadas han sido transferidas ya.';tr = 'Seçilen siparişler zaten transfer edildi.';it = 'L''ordine selezionato è già stato trasferito.';de = 'Die selektierten Aufträge wurden bereits transferiert.'");
		EndIf;
		CommonClientServer.MessageToUser(MessageText, Ref);
	EndIf;
	
EndProcedure

// Procedure fills out the Quantity column according to reserves to be ordered.
//
Procedure FillColumnReserveByReserves() Export
	
	If Inventory.Count() Then
		
		Inventory.LoadColumn(New Array(Inventory.Count()), "Reserve");
		
		TempTablesManager = New TempTablesManager;
		
		Query = New Query;
		Query.TempTablesManager = TempTablesManager;
		Query.Text =
		"SELECT
		|	InventoryTransferInventory.Products AS Products,
		|	InventoryTransferInventory.Characteristic AS Characteristic,
		|	InventoryTransferInventory.Batch AS Batch,
		|	CASE
		|		WHEN &OrderInHeader
		|			THEN &Order
		|		ELSE CASE
		|				WHEN InventoryTransferInventory.SalesOrder REFS Document.SalesOrder
		|							AND InventoryTransferInventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
		|						OR InventoryTransferInventory.SalesOrder REFS Document.TransferOrder
		|							AND InventoryTransferInventory.SalesOrder <> VALUE(Document.TransferOrder.EmptyRef)
		|					THEN InventoryTransferInventory.SalesOrder
		|				ELSE UNDEFINED
		|			END
		|	END AS SalesOrder
		|INTO InventoryTransferInventory
		|FROM
		|	&TableInventory AS InventoryTransferInventory
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TableInventory.Products AS Products,
		|	TableInventory.Characteristic AS Characteristic,
		|	CASE
		|		WHEN &UseBatches
		|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
		|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
		|			THEN TableInventory.Batch
		|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
		|	END AS Batch,
		|	TableInventory.SalesOrder AS SalesOrder
		|INTO TemporaryTableInventory
		|FROM
		|	InventoryTransferInventory AS TableInventory
		|		INNER JOIN Catalog.Products AS CatalogProducts
		|		ON TableInventory.Products = CatalogProducts.Ref
		|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
		|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
		|			AND (CatalogProducts.UseBatches)
		|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
		|		ON (BatchTrackingPolicy.StructuralUnit = &StructuralUnit)
		|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
		|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
		|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)";
		
		OrderInHeader = SalesOrderPosition = Enums.AttributeStationing.InHeader;
		Query.SetParameter("TableInventory", Inventory.Unload());
		Query.SetParameter("OrderInHeader", OrderInHeader);
		Query.SetParameter("Order", ?(ValueIsFilled(SalesOrder), SalesOrder, Undefined));
		Query.SetParameter("UseBatches", Constants.UseBatches.Get());
		Query.SetParameter("StructuralUnit", StructuralUnit);
		
		Query.Execute();
		
		Query.Text =
		"SELECT ALLOWED
		|	ReservedProductsBalances.Company AS Company,
		|	ReservedProductsBalances.StructuralUnit AS StructuralUnit,
		|	ReservedProductsBalances.SalesOrder AS SalesOrder,
		|	ReservedProductsBalances.Products AS Products,
		|	ReservedProductsBalances.Characteristic AS Characteristic,
		|	ReservedProductsBalances.Batch AS Batch,
		|	SUM(ReservedProductsBalances.QuantityBalance) AS QuantityBalance
		|FROM
		|	(SELECT
		|		ReservedProductsBalances.Company AS Company,
		|		ReservedProductsBalances.StructuralUnit AS StructuralUnit,
		|		ReservedProductsBalances.SalesOrder AS SalesOrder,
		|		ReservedProductsBalances.Products AS Products,
		|		ReservedProductsBalances.Characteristic AS Characteristic,
		|		ReservedProductsBalances.Batch AS Batch,
		|		ReservedProductsBalances.QuantityBalance AS QuantityBalance
		|	FROM
		|		AccumulationRegister.ReservedProducts.Balance(
		|				,
		|				(Company, StructuralUnit, Products, Characteristic, Batch, SalesOrder) In
		|					(SELECT
		|						&Company,
		|						&StructuralUnit,
		|						TableInventory.Products,
		|						TableInventory.Characteristic,
		|						TableInventory.Batch,
		|						TableInventory.SalesOrder
		|					FROM
		|						TemporaryTableInventory AS TableInventory
		|					WHERE
		|						TableInventory.SalesOrder <> UNDEFINED)) AS ReservedProductsBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecordsReservedProducts.Company,
		|		DocumentRegisterRecordsReservedProducts.StructuralUnit,
		|		DocumentRegisterRecordsReservedProducts.SalesOrder,
		|		DocumentRegisterRecordsReservedProducts.Products,
		|		DocumentRegisterRecordsReservedProducts.Characteristic,
		|		DocumentRegisterRecordsReservedProducts.Batch,
		|		CASE
		|			WHEN DocumentRegisterRecordsReservedProducts.RecordType = VALUE(AccumulationRecordType.Expense)
		|				THEN DocumentRegisterRecordsReservedProducts.Quantity
		|			ELSE -DocumentRegisterRecordsReservedProducts.Quantity
		|		END
		|	FROM
		|		AccumulationRegister.ReservedProducts AS DocumentRegisterRecordsReservedProducts
		|	WHERE
		|		DocumentRegisterRecordsReservedProducts.Recorder = &Ref
		|		AND DocumentRegisterRecordsReservedProducts.Period <= &Period
		|		AND DocumentRegisterRecordsReservedProducts.RecordType = VALUE(AccumulationRecordType.Expense)
		|		AND DocumentRegisterRecordsReservedProducts.SalesOrder <> UNDEFINED) AS ReservedProductsBalances
		|
		|GROUP BY
		|	ReservedProductsBalances.Company,
		|	ReservedProductsBalances.StructuralUnit,
		|	ReservedProductsBalances.SalesOrder,
		|	ReservedProductsBalances.Products,
		|	ReservedProductsBalances.Characteristic,
		|	ReservedProductsBalances.Batch";
		
		Query.SetParameter("Period", Date);
		Query.SetParameter("Ref", Ref);
		Query.SetParameter("Company", DriveServer.GetCompany(Company));
		Query.SetParameter("StructuralUnit", StructuralUnit);
		
		QueryResult = Query.Execute();
		Selection = QueryResult.Select();
		While Selection.Next() Do
			
			StructureForSearch = New Structure;
			If Not OrderInHeader Then
				StructureForSearch.Insert("SalesOrder", Selection.SalesOrder);
			EndIf;
			StructureForSearch.Insert("Products", Selection.Products);
			StructureForSearch.Insert("Characteristic", Selection.Characteristic);
			If BatchesServer.FEFOTrackingMethod(Selection.Products, StructuralUnit) Then
				StructureForSearch.Insert("Batch", Selection.Batch);
			EndIf;
			
			TotalBalance = Selection.QuantityBalance;
			ArrayOfRowsInventory = Inventory.FindRows(StructureForSearch);
			For Each StringInventory In ArrayOfRowsInventory Do
				
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
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	If SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		
		For Each TabularSectionRow In Inventory Do
			
			TabularSectionRow.SalesOrder = SalesOrder;
			
		EndDo;
		
	EndIf;	
	
	If Not Constants.UseSeveralLinesOfBusiness.Get() Then
		
		For Each Row In Inventory Do
			If Row.ExpenseItem.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses
				And (OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses
					Or OperationKind = Enums.OperationTypesInventoryTransfer.TransferToOperation) Then
				
				Row.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
				
			EndIf;
		EndDo;
		
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	If OperationKind = Enums.OperationTypesInventoryTransfer.Transfer Then
		
		InventoryOwnershipServer.FillOwnershipTable(ThisObject, WriteMode, Cancel);
		
	Else
		
		InventoryOwnershipServer.FillMainTableColumn(ThisObject, WriteMode, Cancel);
		
	EndIf;
	
EndProcedure

// IN the event handler of the FillingProcessor document
// - filling the document according to reconciliation of products at the place of storage.
//
Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.GoodsReceipt") Then	
		
		FillByGoodsReceipt(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.IntraWarehouseTransfer") Then
		
		Query = New Query( 
		"SELECT ALLOWED
		|	IntraWarehouseTransfer.Ref AS BasisDocument,
		|	VALUE(Enum.OperationTypesInventoryTransfer.Transfer) AS OperationKind,
		|	IntraWarehouseTransfer.Company AS Company,
		|	IntraWarehouseTransfer.StructuralUnit AS StructuralUnit,
		|	IntraWarehouseTransfer.Cell AS Cell,
		|	CASE
		|		WHEN IntraWarehouseTransfer.StructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR IntraWarehouseTransfer.StructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN IntraWarehouseTransfer.StructuralUnit.TransferRecipient
		|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
		|	END AS StructuralUnitPayee,
		|	CASE
		|		WHEN IntraWarehouseTransfer.StructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR IntraWarehouseTransfer.StructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN IntraWarehouseTransfer.StructuralUnit.TransferRecipientCell
		|		ELSE VALUE(Catalog.Cells.EmptyRef)
		|	END AS CellPayee,
		|	IntraWarehouseTransfer.Inventory.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		Batch AS Batch,
		|		MeasurementUnit AS MeasurementUnit,
		|		Quantity AS Quantity
		|	)
		|FROM
		|	Document.IntraWarehouseTransfer AS IntraWarehouseTransfer
		|WHERE
		|	IntraWarehouseTransfer.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			Inventory.Load(QueryResultSelection.Inventory.Unload());
			
		EndIf;
		
	// begin Drive.FullVersion
	ElsIf TypeOf(FillingData) = Type("DocumentRef.Production")
		And FillingData.OperationKind = Enums.OperationTypesProduction.Assembly Then
		
		Query = New Query(
		"SELECT ALLOWED
		|	Production.Ref AS BasisDocument,
		|	VALUE(Enum.OperationTypesInventoryTransfer.Transfer) AS OperationKind,
		|	Production.Company AS Company,
		|	Production.SalesOrder AS SalesOrder,
		|	Production.ProductsStructuralUnit AS StructuralUnit,
		|	Production.ProductsCell AS Cell,
		|	CASE
		|		WHEN Production.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR Production.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN Production.ProductsStructuralUnit.TransferRecipient
		|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
		|	END AS StructuralUnitPayee,
		|	CASE
		|		WHEN Production.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR Production.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN Production.ProductsStructuralUnit.TransferRecipientCell
		|		ELSE VALUE(Catalog.Cells.EmptyRef)
		|	END AS CellPayee,
		|	Production.Products.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		Batch AS Batch,
		|		Ref.SalesOrder AS SalesOrder,
		|		MeasurementUnit AS MeasurementUnit,
		|		Quantity AS Quantity,
		|		CASE
		|			WHEN Production.Products.Ref.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
		|				THEN 0
		|			ELSE Production.Products.Quantity
		|		END AS Reserve,
		|		SerialNumbers AS SerialNumbers,
		|		ConnectionKey AS ConnectionKey
		|	) AS Products,
		|	Production.SerialNumbersProducts.(
		|		SerialNumber AS SerialNumber,
		|		ConnectionKey AS ConnectionKey
		|	) AS SerialNumbersProducts
		|FROM
		|	Document.Production AS Production
		|WHERE
		|	Production.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionProducts = QueryResultSelection.Products.Select();
			While SelectionProducts.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionProducts);
			EndDo;
			
			SelectionSerialNumbers = QueryResultSelection.SerialNumbersProducts.Select();
			While SelectionSerialNumbers.Next() Do
				NewRow = SerialNumbers.Add();
				FillPropertyValues(NewRow, SelectionSerialNumbers);
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.Production")
		And FillingData.OperationKind = Enums.OperationTypesProduction.Disassembly Then
		
		Query = New Query(
		"SELECT ALLOWED
		|	Production.Ref AS BasisDocument,
		|	VALUE(Enum.OperationTypesInventoryTransfer.Transfer) AS OperationKind,
		|	Production.Company AS Company,
		|	Production.SalesOrder AS SalesOrder,
		|	Production.ProductsStructuralUnit AS StructuralUnit,
		|	Production.ProductsCell AS Cell,
		|	CASE
		|		WHEN Production.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR Production.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN Production.ProductsStructuralUnit.TransferRecipient
		|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
		|	END AS StructuralUnitPayee,
		|	CASE
		|		WHEN Production.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR Production.ProductsStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN Production.ProductsStructuralUnit.TransferRecipientCell
		|		ELSE VALUE(Catalog.Cells.EmptyRef)
		|	END AS CellPayee,
		|	Production.Inventory.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		Batch AS Batch,
		|		Quantity AS Quantity,
		|		CASE
		|			WHEN Production.Inventory.Ref.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
		|				THEN 0
		|			ELSE Production.Inventory.Quantity
		|		END AS Reserve,
		|		MeasurementUnit AS MeasurementUnit,
		|		Ref.SalesOrder AS SalesOrder,
		|		SerialNumbers AS SerialNumbers,
		|		ConnectionKey AS ConnectionKey
		|	) AS Inventory,
		|	Production.SerialNumbers.(
		|		SerialNumber AS SerialNumber,
		|		ConnectionKey AS ConnectionKey
		|	) AS SerialNumbers
		|FROM
		|	Document.Production AS Production
		|WHERE
		|	Production.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionInventory = QueryResultSelection.Inventory.Select();
			While SelectionInventory.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionInventory);
			EndDo;
			
			SelectionSerialNumbers = QueryResultSelection.SerialNumbers.Select();
			While SelectionSerialNumbers.Next() Do
				NewRow = SerialNumbers.Add();
				FillPropertyValues(NewRow, SelectionSerialNumbers);
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.Manufacturing") 
		And (FillingData.OperationKind = Enums.OperationTypesProduction.Assembly 
		Or FillingData.OperationKind = Enums.OperationTypesProduction.ConvertFromWIP) Then
		
		FillByManufacturing(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.Manufacturing")
		And FillingData.OperationKind = Enums.OperationTypesProduction.Disassembly Then
		
		Query = New Query(
		"SELECT ALLOWED
		|	Production.Ref AS BasisDocument,
		|	VALUE(Enum.OperationTypesInventoryTransfer.Transfer) AS OperationKind,
		|	Production.Company AS Company,
		|	Production.SalesOrder AS SalesOrder,
		|	Production.ProductsStructuralUnit AS StructuralUnit,
		|	Production.ProductsCell AS Cell,
		|	ProductsStructuralUnitData.TransferRecipient AS StructuralUnitPayee,
		|	ProductsStructuralUnitData.TransferRecipientCell AS CellPayee,
		|	Production.Inventory.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		Batch AS Batch,
		|		Quantity AS Quantity,
		|		Quantity AS Reserve,
		|		MeasurementUnit AS MeasurementUnit,
		|		SerialNumbers AS SerialNumbers,
		|		ConnectionKey AS ConnectionKey
		|	) AS Inventory,
		|	Production.SerialNumbers.(
		|		SerialNumber AS SerialNumber,
		|		ConnectionKey AS ConnectionKey
		|	) AS SerialNumbers
		|FROM
		|	Document.Manufacturing AS Production
		|		LEFT JOIN Catalog.BusinessUnits AS ProductsStructuralUnitData
		|		ON Production.ProductsStructuralUnit = ProductsStructuralUnitData.Ref
		|WHERE
		|	Production.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionInventory = QueryResultSelection.Inventory.Select();
			While SelectionInventory.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionInventory);
				NewRow.SalesOrder = SalesOrder;
				If Not ValueIsFilled(SalesOrder) Then
					NewRow.Reserve = 0;
				EndIf;
			EndDo;
			
			SelectionSerialNumbers = QueryResultSelection.SerialNumbers.Select();
			While SelectionSerialNumbers.Next() Do
				NewRow = SerialNumbers.Add();
				FillPropertyValues(NewRow, SelectionSerialNumbers);
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder")
		And FillingData.OperationKind = Enums.OperationTypesProductionOrder.Assembly Then
		
		Query = New Query( 
		"SELECT ALLOWED
		|	ProductionOrder.Ref AS BasisDocument,
		|	ProductionOrder.StructuralUnit AS StructuralUnitPayee,
		|	ProductionOrder.Company AS Company,
		|	VALUE(Enum.OperationTypesInventoryTransfer.Transfer) AS OperationKind,
		|	ProductionOrder.Ref AS SalesOrder,
		|	CASE
		|		WHEN StructuralUnitSource.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR StructuralUnitSource.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN StructuralUnitSource.TransferSource
		|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
		|	END AS StructuralUnit,
		|	CASE
		|		WHEN ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN ProductionOrder.StructuralUnit.TransferSourceCell
		|		ELSE VALUE(Catalog.Cells.EmptyRef)
		|	END AS Cell,
		|	ProductionOrder.Inventory.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		MeasurementUnit AS MeasurementUnit,
		|		Quantity AS Quantity,
		|		Reserve AS Reserve,
		|		Ref AS SalesOrder
		|	) AS Inventory
		|FROM
		|	Document.ProductionOrder AS ProductionOrder
		|		LEFT JOIN Catalog.BusinessUnits AS StructuralUnitSource
		|		ON ProductionOrder.StructuralUnit = StructuralUnitSource.Ref
		|WHERE
		|	ProductionOrder.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionInventory = QueryResultSelection.Inventory.Select();
			While SelectionInventory.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionInventory);
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder") 
		And FillingData.OperationKind = Enums.OperationTypesProductionOrder.Disassembly Then
		
		Query = New Query(
		"SELECT ALLOWED
		|	ProductionOrder.Ref AS BasisDocument,
		|	ProductionOrder.StructuralUnit AS StructuralUnitPayee,
		|	ProductionOrder.Company AS Company,
		|	VALUE(Enum.OperationTypesInventoryTransfer.Transfer) AS OperationKind,
		|	ProductionOrder.Ref AS SalesOrder,
		|	CASE
		|		WHEN StructuralUnitSource.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR StructuralUnitSource.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN StructuralUnitSource.TransferSource
		|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
		|	END AS StructuralUnit,
		|	CASE
		|		WHEN ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN ProductionOrder.StructuralUnit.TransferSourceCell
		|		ELSE VALUE(Catalog.Cells.EmptyRef)
		|	END AS Cell,
		|	ProductionOrder.Products.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		MeasurementUnit AS MeasurementUnit,
		|		Quantity AS Quantity,
		|		Reserve AS Reserve,
		|		Ref AS SalesOrder
		|	)
		|FROM
		|	Document.ProductionOrder AS ProductionOrder
		|		LEFT JOIN Catalog.BusinessUnits AS StructuralUnitSource
		|		ON ProductionOrder.StructuralUnit = StructuralUnitSource.Ref
		|WHERE
		|	ProductionOrder.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionProducts = QueryResultSelection.Products.Select();
			While SelectionProducts.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionProducts);
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder")
		And FillingData.OperationKind = Enums.OperationTypesProductionOrder.Production Then
		
		FillByProductionOrderProduction(FillingData);
	
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ManufacturingOperation") Then
		
		FillByWIP(FillingData);
		
	// end Drive.FullVersion
	
	ElsIf TypeOf(FillingData) = Type("DocumentRef.KitOrder")
		And FillingData.OperationKind = Enums.OperationTypesKitOrder.Assembly Then
		
		Query = New Query( 
		"SELECT ALLOWED
		|	KitOrder.Ref AS BasisDocument,
		|	KitOrder.StructuralUnit AS StructuralUnitPayee,
		|	KitOrder.Company AS Company,
		|	VALUE(Enum.OperationTypesInventoryTransfer.Transfer) AS OperationKind,
		|	KitOrder.SalesOrder AS SalesOrder,
		|	CASE
		|		WHEN StructuralUnitSource.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR StructuralUnitSource.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN StructuralUnitSource.TransferSource
		|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
		|	END AS StructuralUnit,
		|	CASE
		|		WHEN KitOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR KitOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN KitOrder.StructuralUnit.TransferSourceCell
		|		ELSE VALUE(Catalog.Cells.EmptyRef)
		|	END AS Cell,
		|	KitOrder.Inventory.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		MeasurementUnit AS MeasurementUnit,
		|		Quantity AS Quantity,
		|		Ref.SalesOrder AS SalesOrder
		|	) AS Inventory
		|FROM
		|	Document.KitOrder AS KitOrder
		|		LEFT JOIN Catalog.BusinessUnits AS StructuralUnitSource
		|		ON KitOrder.StructuralUnit = StructuralUnitSource.Ref
		|WHERE
		|	KitOrder.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionInventory = QueryResultSelection.Inventory.Select();
			While SelectionInventory.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionInventory);
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.KitOrder") 
		And FillingData.OperationKind = Enums.OperationTypesKitOrder.Disassembly Then
		
		Query = New Query(
		"SELECT ALLOWED
		|	KitOrder.Ref AS BasisDocument,
		|	KitOrder.StructuralUnit AS StructuralUnitPayee,
		|	KitOrder.Company AS Company,
		|	VALUE(Enum.OperationTypesInventoryTransfer.Transfer) AS OperationKind,
		|	KitOrder.Ref.SalesOrder AS SalesOrder,
		|	CASE
		|		WHEN StructuralUnitSource.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR StructuralUnitSource.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN StructuralUnitSource.TransferSource
		|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
		|	END AS StructuralUnit,
		|	CASE
		|		WHEN KitOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR KitOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN KitOrder.StructuralUnit.TransferSourceCell
		|		ELSE VALUE(Catalog.Cells.EmptyRef)
		|	END AS Cell,
		|	KitOrder.Products.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		MeasurementUnit AS MeasurementUnit,
		|		Quantity AS Quantity,
		|		Ref.SalesOrder AS SalesOrder
		|	) AS Products
		|FROM
		|	Document.KitOrder AS KitOrder
		|		LEFT JOIN Catalog.BusinessUnits AS StructuralUnitSource
		|		ON KitOrder.StructuralUnit = StructuralUnitSource.Ref
		|WHERE
		|	KitOrder.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionProducts = QueryResultSelection.Products.Select();
			While SelectionProducts.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionProducts);
			EndDo;
			
		EndIf;
	
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SupplierInvoice") Then	
		
		FillByPurchaseInvoice(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.WorkOrder") Then
		
		FillByWorkOrder(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.TransferOrder")
		Or TypeOf(FillingData) = Type("Structure") And FillingData.Property("ArrayOfOrders") Then

		
		FillByTransferOrder(FillingData);
		
	EndIf;
	
	IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInDocument(ThisObject, FillingData);
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
	If Constants.UseInventoryReservation.Get() Then
		FillColumnReserveByReserves();
	EndIf;
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Check existence of retail prices.
	CheckExistenceOfRetailPrice(Cancel);
	
	If Inventory.Count() = 0 Then
		Return;
	EndIf;
	
	If OperationKind = Enums.OperationTypesInventoryTransfer.TransferToOperation Then
		CheckedAttributes.Add("Inventory.BusinessUnit");
	EndIf;
	
	If OperationKind <> Enums.OperationTypesInventoryTransfer.WriteOffToExpenses Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Inventory.ExpenseItem");
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InTabularSection Then
		
		For Each StringInventory In Inventory Do
			
			If Not ValueIsFilled(StringInventory.SalesOrder) And StringInventory.Reserve > 0 Then
				
				DriveServer.ShowMessageAboutError(ThisObject, 
				"The row contains reserve quantity, but order is not specified.",
				"Inventory",
				StringInventory.LineNumber,
				"Reserve",
				Cancel);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		
		For Each StringInventory In Inventory Do
			
			If Not ValueIsFilled(SalesOrder)
				And (TypeOf(BasisDocument) <> Type("DocumentRef.WorkOrder"))
				And StringInventory.Reserve > 0 Then
				
				DriveServer.ShowMessageAboutError(ThisObject, 
				"The row contains reserve quantity, but order is not specified.",
				"Inventory",
				StringInventory.LineNumber,
				"Reserve",
				Cancel);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If Constants.UseInventoryReservation.Get() 
		And (OperationKind = Enums.OperationTypesInventoryTransfer.Transfer
		Or OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses) Then
		
		For Each StringInventory In Inventory Do
			
			If StringInventory.Reserve > StringInventory.Quantity Then
				
				MessageText = NStr("en = 'In row #%Number% of the ""Inventory"" tabular section, the quantity of items transferred to reserve exceeds the total inventory quantity.'; ru = 'В строке №%Number% табл. части ""Запасы"" количество передаваемых в резерв позиций превышает общее количество запасов.';pl = 'Ilość pozycji wskazanych do rezerwacji w wierszu nr %Number% sekcji ""Zapasy"" przekracza łączną ilość zapasów.';es_ES = 'En la fila #%Number% de la sección tabular ""Inventario"", la cantidad de artículos transferidos a la reserva excede la cantidad total del inventario.';es_CO = 'En la fila #%Number% de la sección tabular ""Inventario"", la cantidad de artículos transferidos a la reserva excede la cantidad total del inventario.';tr = '""Stok"" tablo bölümünün no.%Number% satırında, rezerve aktarılan öğe miktarı toplam stok miktarını geçiyor.';it = 'Nella riga №. %Number% della sezione tabellare ""Scorte"", la quantità di articoli trasferiti alla riserva supera la quantità totale di scorte.';de = 'In der Zeile Nr %Number% des Tabellenabschnitts ""Bestand"" übersteigt die Menge der in die Reserve eingestellten Artikel die gesamte Bestandsmenge.'");
				MessageText = StrReplace(MessageText, "%Number%", StringInventory.LineNumber);
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Inventory",
					StringInventory.LineNumber,
					"Reserve",
					Cancel
				);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	
	// begin Drive.FullVersion
	If Not TypeOf(SalesOrder) = Type("DocumentRef.SubcontractorOrderReceived") Then 
		BatchesServer.CheckFilling(ThisObject, Cancel);
	EndIf;
	// end Drive.FullVersion
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	// Initialization of document data
	Documents.InventoryTransfer.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectTransferOrders(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectReservedProducts(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPOSSummary(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectWorkOrders(AdditionalProperties, RegisterRecords, Cancel);
	
	// SerialNumbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.InventoryTransfer.RunControl(Ref, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);

	// Control
	Documents.InventoryTransfer.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

Procedure OnCopy(CopiedObject)
	
	If SerialNumbers.Count() Then
		
		For Each InventoryLine In Inventory Do
			InventoryLine.SerialNumbers = "";
		EndDo;
		
		SerialNumbers.Clear();
		
	EndIf;
	
	InventoryOwnership.Clear();
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, AdditionalProperties.WriteMode, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

#EndRegion

#Region Private 

// Procedure checks the existence of retail price.
//
Procedure CheckExistenceOfRetailPrice(Cancel)
	
	If StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		Or StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
	 
		Query = New Query;
		Query.SetParameter("Date", Date);
		Query.SetParameter("DocumentTable", Inventory);
		Query.SetParameter("RetailPriceKind", StructuralUnitPayee.RetailPriceKind);
		Query.SetParameter("ListProducts", Inventory.UnloadColumn("Products"));
		Query.SetParameter("ListCharacteristic", Inventory.UnloadColumn("Characteristic"));
		
		Query.Text =
		"SELECT
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.Products AS Products,
		|	DocumentTable.Characteristic AS Characteristic,
		|	DocumentTable.Batch AS Batch
		|INTO InventoryTransferInventory
		|FROM
		|	&DocumentTable AS DocumentTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	InventoryTransferInventory.LineNumber AS LineNumber,
		|	PRESENTATION(InventoryTransferInventory.Products) AS ProductsPresentation,
		|	PRESENTATION(InventoryTransferInventory.Characteristic) AS CharacteristicPresentation,
		|	PRESENTATION(InventoryTransferInventory.Batch) AS BatchPresentation
		|FROM
		|	InventoryTransferInventory AS InventoryTransferInventory
		|		LEFT JOIN InformationRegister.Prices.SliceLast(
		|				&Date,
		|				PriceKind = &RetailPriceKind
		|					AND Products IN (&ListProducts)
		|					AND Characteristic IN (&ListCharacteristic)) AS PricesSliceLast
		|		ON InventoryTransferInventory.Products = PricesSliceLast.Products
		|			AND InventoryTransferInventory.Characteristic = PricesSliceLast.Characteristic
		|WHERE
		|	ISNULL(PricesSliceLast.Price, 0) = 0";
		
		SelectionOfQueryResult = Query.Execute().Select();
		
		While SelectionOfQueryResult.Next() Do
			
			MessageText = StrTemplate(NStr("en = 'Specify the retail price using ""Pricing"" document for %1 in line %2.'; ru = 'Укажите розничную цену с помощью документа ""Ценообразование"" для %1 в строке %2.';pl = 'Wybierz cenę detaliczną, używając dokumentu ""Ustalanie cen dla %1 w wierszu %2.';es_ES = 'Especifique el precio minorista final utilizando el documento ""Fijación de precios %1 para la línea %2.';es_CO = 'Especifique el precio minorista final utilizando el documento ""Fijación de precios %1 para la línea %2.';tr = '%2 satırındaki %1 için ""Fiyatlandırma"" belgesini kullanarak perakende fiyatını belirtin.';it = 'Specificare il prezzo al dettaglio usando il documento ""Definizione prezzo"" per la %1 nella linea %2.';de = 'Geben Sie den Verkaufspreis über den Beleg ""Preisgestaltung"" für %1 in Zeile %2 an.'"),  
								DriveServer.PresentationOfProducts(SelectionOfQueryResult.ProductsPresentation, 
															SelectionOfQueryResult.CharacteristicPresentation, 
															SelectionOfQueryResult.BatchPresentation), 
								String(SelectionOfQueryResult.LineNumber));
								
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Inventory",
				SelectionOfQueryResult.LineNumber,
				"Products",
				Cancel
			);
			
		EndDo;
	 
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByGoodsReceipt(FillingData)
	
	Query = New Query();
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT ALLOWED
	|	&Ref AS BasisDocument,
	|	GoodsReceipt.Company AS Company,
	|	GoodsReceipt.DocumentCurrency AS CashCurrency,
	|	GoodsReceipt.Counterparty AS Counterparty,
	|	GoodsReceipt.Contract AS Contract,
	|	GoodsReceipt.DocumentAmount AS DocumentAmount,
	|	GoodsReceipt.StructuralUnit AS StructuralUnit,
	|	GoodsReceipt.Cell AS Cell,
	|	GoodsReceipt.Order AS SalesOrder
	|INTO GoodsReceiptHeader
	|FROM
	|	Document.GoodsReceipt AS GoodsReceipt
	|WHERE
	|	GoodsReceipt.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsReceiptHeader.BasisDocument AS BasisDocument,
	|	GoodsReceiptHeader.Company AS Company,
	|	GoodsReceiptHeader.CashCurrency AS CashCurrency,
	|	GoodsReceiptHeader.Counterparty AS Counterparty,
	|	GoodsReceiptHeader.Contract AS Contract,
	|	GoodsReceiptHeader.DocumentAmount AS DocumentAmount,
	|	GoodsReceiptHeader.StructuralUnit AS StructuralUnit,
	|	GoodsReceiptHeader.Cell AS Cell,
	|	GoodsReceiptHeader.SalesOrder AS SalesOrder
	|FROM
	|	GoodsReceiptHeader AS GoodsReceiptHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsReceiptProducts.LineNumber AS LineNumber,
	|	GoodsReceiptProducts.Products AS Products,
	|	GoodsReceiptProducts.Characteristic AS Characteristic,
	|	GoodsReceiptProducts.Batch AS Batch,
	|	GoodsReceiptProducts.Quantity AS Quantity,
	|	GoodsReceiptProducts.MeasurementUnit AS MeasurementUnit,
	|	GoodsReceiptProducts.Order AS SalesOrder,
	|	GoodsReceiptProducts.SerialNumbers AS SerialNumbers,
	|	GoodsReceiptProducts.ConnectionKey AS ConnectionKey,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsReceiptProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsReceiptProducts.InventoryReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryReceivedGLAccount,
	|	GoodsReceiptProducts.Amount AS Amount
	|FROM
	|	GoodsReceiptHeader AS GoodsReceiptHeader
	|		INNER JOIN Document.GoodsReceipt.Products AS GoodsReceiptProducts
	|		ON GoodsReceiptHeader.BasisDocument = GoodsReceiptProducts.Ref";
	
	ResultArray = Query.ExecuteBatch();
	
	If ResultArray[1].IsEmpty() Then
		Return;
	EndIf;
	
	SelectionHeader = ResultArray[1].Select();
	SelectionHeader.Next();
	FillPropertyValues(ThisObject, SelectionHeader);
	
	Inventory.Load(ResultArray[2].Unload());
	
	WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(ThisObject, FillingData, "Products");
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByPurchaseInvoice(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentSessionDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT ALLOWED
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.DocumentCurrency AS CashCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.Cell AS Cell,
	|	DocumentTable.Inventory.(
	|		Ref AS Ref,
	|		LineNumber AS LineNumber,
	|		Products AS Products,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		MeasurementUnit AS MeasurementUnit,
	|		Quantity AS Quantity,
	|		Price AS Price,
	|		Amount AS Amount,
	|		VATRate AS VATRate,
	|		VATAmount AS VATAmount,
	|		Inventory.Order AS Order,
	|		Total AS Total,
	|		AmountExpense AS AmountExpense,
	|		Content AS Content,
	|		SerialNumbers AS SerialNumbers,
	|		ConnectionKey AS ConnectionKey
	|	) AS Inventory
	|FROM
	|	Document.SupplierInvoice AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	FillPropertyValues(ThisObject, Selection);
	
	Inventory.Load(Selection.Inventory.Unload());
	
	WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(ThisObject, FillingData);
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//
Procedure FillByWorkOrder(FillingData)
	
	Query = New Query(
	"SELECT ALLOWED
	|	WorkOrder.Ref AS BasisDocument,
	|	VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses) AS OperationKind,
	|	WorkOrder.Company AS Company,
	|	WorkOrder.Ref AS SalesOrder,
	|	WorkOrder.InventoryWarehouse AS StructuralUnit,
	|	WorkOrder.SalesStructuralUnit AS StructuralUnitPayee,
	|	WorkOrder.SerialNumbersMaterials.(
	|		Ref AS Ref,
	|		LineNumber AS LineNumber,
	|		SerialNumber AS SerialNumber,
	|		ConnectionKey AS ConnectionKey
	|	) AS SerialNumbersMaterials
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|		INNER JOIN InformationRegister.AccountingPolicy.SliceLast AS AccountingPolicySliceLast
	|		ON WorkOrder.Company = AccountingPolicySliceLast.Company
	|WHERE
	|	WorkOrder.Ref = &BasisDocument
	|	AND NOT AccountingPolicySliceLast.PostExpensesByWorkOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	WorkOrderMaterials.LineNumber AS LineNumber,
	|	WorkOrderMaterials.ConnectionKey AS ConnectionKey,
	|	WorkOrderMaterials.Products AS Products,
	|	WorkOrderMaterials.Characteristic AS Characteristic,
	|	WorkOrderMaterials.Batch AS Batch,
	|	WorkOrderMaterials.Quantity AS Quantity,
	|	WorkOrderMaterials.Reserve AS Reserve,
	|	WorkOrderMaterials.ReserveShipment AS ReserveShipment,
	|	WorkOrderMaterials.MeasurementUnit AS MeasurementUnit,
	|	WorkOrderMaterials.SerialNumbers AS SerialNumbers,
	|	WorkOrderMaterials.ConnectionKeySerialNumbers AS ConnectionKeySerialNumbers,
	|	WorkOrderWorks.Products AS Work,
	|	WorkOrderWorks.Characteristic AS WorkCharacteristic
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|		INNER JOIN InformationRegister.AccountingPolicy.SliceLast AS AccountingPolicySliceLast
	|		ON WorkOrder.Company = AccountingPolicySliceLast.Company
	|		LEFT JOIN Document.WorkOrder.Materials AS WorkOrderMaterials
	|		ON WorkOrder.Ref = WorkOrderMaterials.Ref
	|		LEFT JOIN Document.WorkOrder.Works AS WorkOrderWorks
	|		ON (WorkOrderMaterials.Ref = WorkOrderWorks.Ref)
	|			AND (WorkOrderMaterials.ConnectionKey = WorkOrderWorks.ConnectionKey)
	|WHERE
	|	WorkOrder.Ref = &BasisDocument
	|	AND NOT AccountingPolicySliceLast.PostExpensesByWorkOrder");
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Inventory.Clear();
	
	QueryResult = Query.ExecuteBatch();
	If Not QueryResult[0].IsEmpty() Then
		
		QueryResultSelection = QueryResult[0].Select();
		QueryResultSelection.Next();
		
		FillPropertyValues(ThisObject, QueryResultSelection);
		
		SelectionMaterials = QueryResult[1].Select();
		While SelectionMaterials.Next() Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, SelectionMaterials);
		EndDo;
		
		SelectionSerialNumbersMaterials = QueryResultSelection.SerialNumbersMaterials.Select();
		While SelectionSerialNumbersMaterials.Next() Do
			NewRow = SerialNumbers.Add();
			FillPropertyValues(NewRow, SelectionSerialNumbersMaterials);
		EndDo;
		
	EndIf;
	
EndProcedure

// begin Drive.FullVersion

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Document ManufacturingOperation - Data on filling the document.
//
Procedure FillByWIP(FillingData)
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	|	ManufacturingOperation.Company AS Company,
	|	ManufacturingOperation.Ref AS SalesOrder,
	|	ManufacturingOperation.InventoryStructuralUnit AS StructuralUnitPayee,
	|	ManufacturingOperation.CellInventory AS CellPayee,
	|	ManufacturingOperation.Ref AS BasisDocument,
	|	ManufacturingOperation.Posted AS BasisPosted
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|WHERE
	|	ManufacturingOperation.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ManufacturingOperationInventory.Products AS Products,
	|	ManufacturingOperationInventory.Characteristic AS Characteristic,
	|	ManufacturingOperationInventory.Batch AS Batch,
	|	ManufacturingOperationInventory.Quantity AS Quantity,
	|	ManufacturingOperationInventory.Reserve AS Reserve,
	|	ManufacturingOperationInventory.MeasurementUnit AS MeasurementUnit
	|FROM
	|	Document.ManufacturingOperation.Inventory AS ManufacturingOperationInventory
	|		INNER JOIN Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|		ON ManufacturingOperationInventory.Ref = ManufacturingOperationActivities.Ref
	|			AND ManufacturingOperationInventory.ActivityConnectionKey = ManufacturingOperationActivities.ConnectionKey
	|			AND (ManufacturingOperationActivities.StartDate = DATETIME(1, 1, 1))
	|WHERE
	|	ManufacturingOperationInventory.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	QueryResult = Query.ExecuteBatch();
	If Not QueryResult[0].IsEmpty() Then
		
		QueryResultSelection = QueryResult[0].Select();
		QueryResultSelection.Next();
		
		VerifiedAttributesValues = New Structure;
		VerifiedAttributesValues.Insert("Posted", QueryResultSelection.BasisPosted);
		Documents.ManufacturingOperation.CheckAbilityOfEnteringByWorkInProgress(FillingData, VerifiedAttributesValues);
		
		FillPropertyValues(ThisObject, QueryResultSelection);
		
	EndIf;
	
	Inventory.Clear();
	If FillingData.Inventory.Count() = 0 Then
		
		MessageToUser = NStr("en = 'Cannot perform the action. The Work-in-progress does not include any components.'; ru = 'Не удалось выполнить действие. Документ ""Незавершенное производство"" не содержит компоненты.';pl = 'Nie można wykonać działania. Praca w toku nie zawiera żadnych komponentów.';es_ES = 'No se puede realizar la acción. El trabajo en progreso no incluye ningún componente.';es_CO = 'No se puede realizar la acción. El trabajo en progreso no incluye ningún componente.';tr = 'İşlem gerçekleştirilemiyor. İşlem bitişi hiç malzeme içermiyor.';it = 'Impossibile eseguire l''azione. Il Lavoro in corso non include alcuna componente.';de = 'Fehler beim Erfüllen der Aktion. Die Arbeit in Bearbeitung enthält keine Komponenten.'");
		Raise MessageToUser;
		
	ElsIf Not QueryResult[1].IsEmpty() Then
		
		QueryResultSelection = QueryResult[1].Select();
		While QueryResultSelection.Next() Do
			NewLine = Inventory.Add();
			FillPropertyValues(NewLine, QueryResultSelection);
		EndDo;
		
	Else
		
		MessageToUser = NStr("en = 'Cannot perform the action. In the Work-in-progress, all operations have start dates. 
			|This means that all components are consumed in these operations. Such components are not available for other orders or transfers.'; 
			|ru = 'Не удалось выполнить действие. В документе ""Незавершенное производство"" все операции имеют даты начала. 
			|Это означает, что в этих операциях используются все компоненты. Такие компоненты недоступны для других заказов и перемещений.';
			|pl = 'Nie można wykonać działania. W Pracy w toku, wszystkie operacje mają daty początkowe. 
			|Znaczy to, że wszystkie komponenty są spożywane w tych operacjach. Takie komponenty nie są dostępne dla innych zamówień lub przeniesień.';
			|es_ES = 'No se puede realizar la acción. En el trabajo en progreso, todas las operaciones tienen fecha de inicio. 
			|Esto significa que todos los componentes se consumen en estas operaciones. Estos componentes no están disponibles para otras órdenes o transferencias.';
			|es_CO = 'No se puede realizar la acción. En el trabajo en progreso, todas las operaciones tienen fecha de inicio. 
			|Esto significa que todos los componentes se consumen en estas operaciones. Estos componentes no están disponibles para otras órdenes o transferencias.';
			|tr = 'İşlem gerçekleştirilemiyor. İşlem bitişindeki tüm malzemelerin başlangıç tarihi bulunuyor. 
			|Başka bir deyişle, tüm malzemeler bu işlemlerde kullanılıyor. Bu malzemeler diğer siparişler veya transferler için kullanılamaz.';
			|it = 'Impossibile eseguire l''azione. Nel Lavoro in corso tutte le operazioni hanno data di inizio. 
			|Ciò significa che tutte le componenti sono utilizzate in tali operazioni. Tali componenti non sono disponibili per altri ordini o trasferimenti.';
			|de = 'Fehler beim Erfüllen der Aktion. In der Arbeit in Bearbeitung haben alle Operationen Startdaten. 
			|Dies bedeutet dass alle Komponenten in diesen Operationen verbraucht werden. Diese Komponenten sind für andere Aufträge oder Transfer nicht verfügbar.'");
		Raise MessageToUser;
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Document ProductionOrder - Data on filling the document.
//
Procedure FillByProductionOrderProduction(FillingData)
	
	Query = New Query(
	"SELECT ALLOWED
	|	ProductionOrder.Ref AS BasisDocument,
	|	ProductionOrder.Company AS Company,
	|	ProductionOrder.Posted AS BasisPosted,
	|	ProductionOrder.Closed AS Closed,
	|	ProductionOrder.OrderState AS OrderState
	|INTO TT_ProdOrder
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|WHERE
	|	ProductionOrder.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProdOrder.BasisDocument AS BasisDocument,
	|	TT_ProdOrder.Company AS Company,
	|	TT_ProdOrder.BasisPosted AS BasisPosted,
	|	TT_ProdOrder.Closed AS Closed,
	|	TT_ProdOrder.OrderState AS OrderState
	|FROM
	|	TT_ProdOrder AS TT_ProdOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ManufacturingOperation.InventoryStructuralUnit AS StructuralUnitPayee,
	|	ManufacturingOperation.CellInventory AS CellPayee
	|FROM
	|	TT_ProdOrder AS TT_ProdOrder
	|		INNER JOIN Document.ManufacturingOperation AS ManufacturingOperation
	|		ON TT_ProdOrder.BasisDocument = ManufacturingOperation.BasisDocument
	|			AND (ManufacturingOperation.Posted)
	|
	|GROUP BY
	|	ManufacturingOperation.InventoryStructuralUnit,
	|	ManufacturingOperation.CellInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ManufacturingOperationInventory.Products AS Products,
	|	ManufacturingOperationInventory.Characteristic AS Characteristic,
	|	ManufacturingOperationInventory.Batch AS Batch,
	|	ManufacturingOperationInventory.Quantity AS Quantity,
	|	ManufacturingOperationInventory.MeasurementUnit AS MeasurementUnit
	|FROM
	|	TT_ProdOrder AS TT_ProdOrder
	|		INNER JOIN Document.ManufacturingOperation AS ManufacturingOperation
	|		ON TT_ProdOrder.BasisDocument = ManufacturingOperation.BasisDocument
	|			AND (ManufacturingOperation.Posted)
	|		INNER JOIN Document.ManufacturingOperation.Inventory AS ManufacturingOperationInventory
	|		ON (ManufacturingOperation.Ref = ManufacturingOperationInventory.Ref)
	|		INNER JOIN Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|		ON (ManufacturingOperationInventory.Ref = ManufacturingOperationActivities.Ref)
	|			AND (ManufacturingOperationInventory.ActivityConnectionKey = ManufacturingOperationActivities.ConnectionKey)
	|			AND (ManufacturingOperationActivities.StartDate = DATETIME(1, 1, 1))");
	
	Query.SetParameter("BasisDocument", FillingData);
	
	QueryResult = Query.ExecuteBatch();
	If Not QueryResult[1].IsEmpty() Then
		
		QueryResultSelection = QueryResult[1].Select();
		QueryResultSelection.Next();
		
		VerifiedAttributesValues = New Structure;
		VerifiedAttributesValues.Insert("OrderState", 	QueryResultSelection.OrderState);
		VerifiedAttributesValues.Insert("Closed", 		QueryResultSelection.Closed);
		VerifiedAttributesValues.Insert("Posted", 		QueryResultSelection.BasisPosted);
		Documents.ProductionOrder.VerifyEnteringAbilityByProductionOrder(QueryResultSelection.BasisDocument, VerifiedAttributesValues);
		
		FillPropertyValues(ThisObject, QueryResultSelection);
		
	EndIf;
	
	If Not QueryResult[2].IsEmpty() Then
		
		QueryResultSelection = QueryResult[2].Select();
		If QueryResultSelection.Count() = 1 Then
			QueryResultSelection.Next();		
			FillPropertyValues(ThisObject, QueryResultSelection);
		EndIf;
		
	Else
		
		MessageToUser = NStr("en = 'Cannot perform the action. The Production order does not have a linked Work-in-progress yet. 
			|This means there are no components available for transfer yet. From the Production order, generate Work-in-progress and specify components. Then try again.'; 
			|ru = 'Не удалось выполнить действие. Заказ на производство еще не связан с документом ""Незавершенное производство"". 
			|Это означает, что пока нет доступных для перемещения компонентов. На основании заказа на производство создайте документ ""Незавершенное производство"" и укажите компоненты. Затем повторите попытку.';
			|pl = 'Nie można wykonać działania. Zlecenie produkcyjne nie ma jeszcze powiązanych prac w toku. 
			|Znaczy to, że nie ma jeszcze komponentów dostępnych do przeniesienia. Ze Zlecenia produkcyjnego, wygeneruj Pracę w toku i wybierz komponenty. Następnie spróbuj ponownie.';
			|es_ES = 'No se puede realizar la acción. La orden de producción aún no tiene un enlace de Trabajo en progreso. 
			|Esto significa que todavía no hay componentes disponibles para la transferencia. Desde la orden de producción, genere un Trabajo en progreso y especifique los componentes. A continuación, inténtelo de nuevo.';
			|es_CO = 'No se puede realizar la acción. La orden de producción aún no tiene un enlace de Trabajo en progreso. 
			|Esto significa que todavía no hay componentes disponibles para la transferencia. Desde la orden de producción, genere un Trabajo en progreso y especifique los componentes. A continuación, inténtelo de nuevo.';
			|tr = 'İşlem gerçekleştirilemiyor. Üretim emri için henüz bağlantılı bir İşlem bitişi yok. 
			|Başka bir deyişle, henüz transfer için kullanılabilecek malzeme yok. Üretim emrinden İşlem bitişi oluşturun, malzeme belirtin ve tekrar deneyin.';
			|it = 'Impossibile eseguire l''azione. L''Ordine di produzione non ha ancora un Lavoro in corso collegato. 
			|Ciò significa che non ci sono ancora componenti disponibili per il trasferimento. Dall''Ordine di produzione generare il Lavoro in corso e specificare le componenti, poi riprovare.';
			|de = 'Fehler beim Erfüllen der Aktion. Der Produktionsauftrag hat noch keine verbundene Arbeit in Bearbeitung. 
			|Dies bedeutet dass es noch keine für Transfer verfügbaren Komponenten gibt. Generieren Sie eine Arbeit in Bearbeitung aus dem Produktionsauftrag und geben die Komponenten ein. Dann versuchen Sie erneut.'");
		Raise MessageToUser;
		
	EndIf;
	
	Inventory.Clear();
	If Not QueryResult[3].IsEmpty() Then
		
		QueryResultSelection = QueryResult[3].Select();
		While QueryResultSelection.Next() Do
			NewLine = Inventory.Add();
			FillPropertyValues(NewLine, QueryResultSelection);
		EndDo;
		
	Else
		
		MessageToUser = NStr("en = 'Cannot perform the action. In the Work-in-progress, all operations have start dates. 
			|This means that all components are consumed in these operations. Such components are not available for other orders or transfers.'; 
			|ru = 'Не удается выполнить действие. В документе ""Незавершенное производство"" все операции имеют даты начала. 
			|Это означает, что в этих операциях используются все компоненты. Такие компоненты недоступны для других заказов и перемещений.';
			|pl = 'Nie można wykonać działania. W Pracy w toku, wszystkie operacje mają daty początkowe. 
			|Znaczy to, że wszystkie komponenty są spożywane w tych operacjach. Takie komponenty nie są dostępne dla innych zamówień lub przeniesień.';
			|es_ES = 'No se puede realizar la acción. En el trabajo en progreso, todas las operaciones tienen fecha de inicio. 
			|Esto significa que todos los componentes se consumen en estas operaciones. Estos componentes no están disponibles para otras órdenes o transferencias.';
			|es_CO = 'No se puede realizar la acción. En el trabajo en progreso, todas las operaciones tienen fecha de inicio. 
			|Esto significa que todos los componentes se consumen en estas operaciones. Estos componentes no están disponibles para otras órdenes o transferencias.';
			|tr = 'İşlem gerçekleştirilemiyor. İşlem bitişindeki tüm malzemelerin başlangıç tarihi bulunuyor. 
			|Başka bir deyişle, tüm malzemeler bu işlemlerde kullanılıyor. Bu malzemeler diğer siparişler veya transferler için kullanılamaz.';
			|it = 'Impossibile eseguire l''azione. Nel Lavoro in corso tutte le operazioni hanno data di inizio. 
			|Ciò significa che tutte le componenti sono utilizzate in tali operazioni. Tali componenti non sono disponibili per altri ordini o trasferimenti.';
			|de = 'Fehler beim Erfüllen der Aktion. In der Arbeit in Bearbeitung haben alle Operationen Startdaten. 
			|Dies bedeutet dass alle Komponenten in diesen Operationen verbraucht werden. Diese Komponenten sind für andere Aufträge oder Transfer nicht verfügbar.'");
		Raise MessageToUser;
		
	EndIf;
	
EndProcedure

Procedure FillByManufacturing(FillingData)
	
	Query = New Query(
	"SELECT ALLOWED
	|	Production.Ref AS BasisDocument,
	|	VALUE(Enum.OperationTypesInventoryTransfer.Transfer) AS OperationKind,
	|	Production.Company AS Company,
	|	Production.SalesOrder AS SalesOrder,
	|	Production.ProductsStructuralUnit AS StructuralUnit,
	|	Production.ProductsCell AS Cell,
	|	ProductsStructuralUnitData.TransferRecipient AS StructuralUnitPayee,
	|	ProductsStructuralUnitData.TransferRecipientCell AS CellPayee
	|INTO TT_DocumentHeaderd
	|FROM
	|	Document.Manufacturing AS Production
	|		LEFT JOIN Catalog.BusinessUnits AS ProductsStructuralUnitData
	|		ON Production.ProductsStructuralUnit = ProductsStructuralUnitData.Ref
	|WHERE
	|	Production.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_DocumentHeaderd.BasisDocument AS BasisDocument,
	|	TT_DocumentHeaderd.OperationKind AS OperationKind,
	|	TT_DocumentHeaderd.Company AS Company,
	|	TT_DocumentHeaderd.SalesOrder AS SalesOrder,
	|	TT_DocumentHeaderd.StructuralUnit AS StructuralUnit,
	|	TT_DocumentHeaderd.Cell AS Cell,
	|	TT_DocumentHeaderd.StructuralUnitPayee AS StructuralUnitPayee,
	|	TT_DocumentHeaderd.CellPayee AS CellPayee
	|FROM
	|	TT_DocumentHeaderd AS TT_DocumentHeaderd
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ManufacturingProducts.Products AS Products,
	|	ManufacturingProducts.Characteristic AS Characteristic,
	|	ManufacturingProducts.Batch AS Batch,
	|	ManufacturingProducts.MeasurementUnit AS MeasurementUnit,
	|	ManufacturingProducts.Quantity AS Quantity,
	|	ManufacturingProducts.SerialNumbers AS SerialNumbers,
	|	ManufacturingProducts.ConnectionKey AS ConnectionKey
	|FROM
	|	TT_DocumentHeaderd AS TT_DocumentHeaderd
	|		INNER JOIN Document.Manufacturing.Products AS ManufacturingProducts
	|		ON TT_DocumentHeaderd.BasisDocument = ManufacturingProducts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ManufacturingReservation.Products AS Products,
	|	ManufacturingReservation.Characteristic AS Characteristic,
	|	ManufacturingReservation.Batch AS Batch,
	|	ManufacturingReservation.Quantity AS Quantity,
	|	ManufacturingReservation.SalesOrder AS SalesOrder
	|FROM
	|	TT_DocumentHeaderd AS TT_DocumentHeaderd
	|		INNER JOIN Document.Manufacturing.Reservation AS ManufacturingReservation
	|		ON TT_DocumentHeaderd.BasisDocument = ManufacturingReservation.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SerialNumbersProducts.SerialNumber AS SerialNumber,
	|	SerialNumbersProducts.ConnectionKey AS ConnectionKey
	|FROM
	|	TT_DocumentHeaderd AS TT_DocumentHeaderd
	|		INNER JOIN Document.Manufacturing.SerialNumbersProducts AS SerialNumbersProducts
	|		ON TT_DocumentHeaderd.BasisDocument = SerialNumbersProducts.Ref");
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Inventory.Clear();
	SerialNumbers.Clear();
	
	ResultsArray = Query.ExecuteBatch();
	QueryResult = ResultsArray[1];
	
	If Not QueryResult.IsEmpty() Then
		
		QueryResultSelection = QueryResult.Select();
		QueryResultSelection.Next();
		
		FillPropertyValues(ThisObject, QueryResultSelection);
		
		ManufacturingProducts		= ResultsArray[2].Unload();
		ManufacturingReservation	= ResultsArray[3].Unload();
		SerialNumbersProducts		= ResultsArray[4].Unload();
		
		SearchFilter = New Structure(
			"Products,
			|Characteristic,
			|Batch");
		
		SearchConnectionKey = New Structure(
			"ConnectionKey");
		
		EmptyOrder = Documents.SalesOrder.EmptyRef();
		ConnectionKey = 1;
		
		For Each RowProducts In ManufacturingProducts Do
			
			FillPropertyValues(SearchFilter, RowProducts);
			FillPropertyValues(SearchConnectionKey, RowProducts);
			
			SerialNumberRows = SerialNumbersProducts.FindRows(SearchConnectionKey);
			
			BalancesRows = ManufacturingReservation.FindRows(SearchFilter);
			
			Coefficients = New Array;
			QuantityNeeded = RowProducts.Quantity;
			
			For Each BalancesRow In BalancesRows Do
				Coefficients.Add(BalancesRow.Quantity);
			EndDo;
		
			ResultQuantity = CommonClientServer.DistributeAmountInProportionToCoefficients(QuantityNeeded, Coefficients, 3);
			RowsCount = BalancesRows.Count();
			
			For Index = 0 To RowsCount-1 Do

				If ResultQuantity[Index] = 0 Then 
					Continue;
				EndIf;
				
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, RowProducts);
				
				NewRow.SalesOrder = BalancesRows[Index].SalesOrder;
				NewRow.Quantity = ResultQuantity[Index];
				
				If Not ValueIsFilled(NewRow.SalesOrder) Then
					NewRow.Reserve = 0;
				Else
					NewRow.Reserve = NewRow.Quantity;
				EndIf;
				
				If ValueIsFilled(NewRow.SerialNumbers) Then
					
					IndexSerialNumber = 0;
					CountSerialNumberRows = SerialNumberRows.Count();
					
					NewRow.ConnectionKey = ConnectionKey;
					NewRow.SerialNumbers = "";
						
					For IndexSerialNumber = 1 To NewRow.Quantity Do
						
						SerialNumber = SerialNumberRows[CountSerialNumberRows - IndexSerialNumber]; 
						
						NewRowSerialNumber = SerialNumbers.Add();
						NewRowSerialNumber.SerialNumber = SerialNumber.SerialNumber;
						NewRowSerialNumber.ConnectionKey = ConnectionKey;
						
						SerialNumberRows.Delete(CountSerialNumberRows - IndexSerialNumber);
						
					EndDo;
					
					WorkWithSerialNumbersClientServer.UpdateStringPresentationOfSerialNumbersOfLine(NewRow, ThisObject, "ConnectionKey");
					
					ConnectionKey = ConnectionKey + 1;
				EndIf;

			EndDo;
			
			If RowsCount = 0 Then
				
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, RowProducts);
				NewRow.SalesOrder = EmptyOrder;
				NewRow.Quantity = QuantityNeeded;
				
			EndIf;
			
		EndDo;
		
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
	EndIf;

EndProcedure

// end Drive.FullVersion

#EndRegion

#EndIf
