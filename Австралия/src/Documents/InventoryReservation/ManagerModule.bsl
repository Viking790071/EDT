#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableBackorders(DocumentRefInventoryReservation, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	ConditionForBackorders = "
	|(VALUETYPE(TableInventory.StructuralUnit) = TYPE(Document.SalesOrder)
	|	AND TableInventory.StructuralUnit <> VALUE(Document.SalesOrder.EmptyRef))
	|OR (VALUETYPE(TableInventory.StructuralUnit) = TYPE(Document.TransferOrder)
	|	AND TableInventory.StructuralUnit <> VALUE(Document.TransferOrder.EmptyRef))
	// begin Drive.FullVersion
	|OR (VALUETYPE(TableInventory.StructuralUnit) = TYPE(Document.ProductionOrder)
	|	AND TableInventory.StructuralUnit <> VALUE(Document.ProductionOrder.EmptyRef))
	// end Drive.FullVersion
	|OR (VALUETYPE(TableInventory.StructuralUnit) = TYPE(Document.SubcontractorOrderIssued)
	|	AND TableInventory.StructuralUnit <> VALUE(Document.SubcontractorOrderIssued.EmptyRef))
	|OR (VALUETYPE(TableInventory.StructuralUnit) = TYPE(Document.PurchaseOrder)
	|	AND TableInventory.StructuralUnit <> VALUE(Document.PurchaseOrder.EmptyRef))
	|OR (VALUETYPE(TableInventory.StructuralUnit) = TYPE(Document.KitOrder)
	|	AND TableInventory.StructuralUnit <> VALUE(Document.KitOrder.EmptyRef))";
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.StructuralUnit AS SupplySource
	|FROM
	|	TemporaryTableInventorySource AS TableInventory
	|WHERE
	|	&ConditionForBackorders
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.SalesOrder,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.StructuralUnit";
	
	Query.Text = StrReplace(Query.Text, "&ConditionForBackorders" ,ConditionForBackorders);
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Backorders");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving inventory balances by cost.
	Query.Text = 
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.StructuralUnit AS SupplySource,
	|	CASE
	|		WHEN TableInventory.Quantity > ISNULL(BackordersBalances.QuantityBalance, 0)
	|			THEN ISNULL(BackordersBalances.QuantityBalance, 0)
	|		WHEN TableInventory.Quantity <= ISNULL(BackordersBalances.QuantityBalance, 0)
	|			THEN TableInventory.Quantity
	|	END AS Quantity
	|FROM
	|	TemporaryTableInventorySource AS TableInventory
	|		LEFT JOIN (SELECT
	|			BackordersBalances.Company AS Company,
	|			BackordersBalances.SalesOrder AS SalesOrder,
	|			BackordersBalances.Products AS Products,
	|			BackordersBalances.Characteristic AS Characteristic,
	|			BackordersBalances.SupplySource AS SupplySource,
	|			SUM(BackordersBalances.QuantityBalance) AS QuantityBalance
	|		FROM
	|			(SELECT
	|				BackordersBalances.Company AS Company,
	|				BackordersBalances.SalesOrder AS SalesOrder,
	|				BackordersBalances.Products AS Products,
	|				BackordersBalances.Characteristic AS Characteristic,
	|				BackordersBalances.SupplySource AS SupplySource,
	|				SUM(BackordersBalances.QuantityBalance) AS QuantityBalance
	|			FROM
	|				AccumulationRegister.Backorders.Balance(
	|						&ControlTime,
	|						(Company, SalesOrder, Products, Characteristic, SupplySource) IN
	|							(SELECT
	|								TableInventory.Company AS Company,
	|								TableInventory.SalesOrder AS SalesOrder,
	|								TableInventory.Products AS Products,
	|								TableInventory.Characteristic AS Characteristic,
	|								TableInventory.StructuralUnit AS SupplySource
	|							FROM
	|								TemporaryTableInventorySource AS TableInventory
	|							WHERE
	|								&ConditionForBackorders)) AS BackordersBalances
	|			
	|			GROUP BY
	|				BackordersBalances.Company,
	|				BackordersBalances.SalesOrder,
	|				BackordersBalances.Products,
	|				BackordersBalances.Characteristic,
	|				BackordersBalances.SupplySource
	|			
	|			UNION ALL
	|			
	|			SELECT
	|				DocumentRegisterRecordsBackorders.Company,
	|				DocumentRegisterRecordsBackorders.SalesOrder,
	|				DocumentRegisterRecordsBackorders.Products,
	|				DocumentRegisterRecordsBackorders.Characteristic,
	|				DocumentRegisterRecordsBackorders.SupplySource,
	|				CASE
	|					WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|						THEN ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|					ELSE -ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|				END
	|			FROM
	|				AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
	|			WHERE
	|				DocumentRegisterRecordsBackorders.Recorder = &Ref
	|				AND DocumentRegisterRecordsBackorders.Period <= &ControlPeriod
	|				AND DocumentRegisterRecordsBackorders.SalesOrder <> UNDEFINED) AS BackordersBalances
	|		
	|		GROUP BY
	|			BackordersBalances.Company,
	|			BackordersBalances.SalesOrder,
	|			BackordersBalances.Products,
	|			BackordersBalances.Characteristic,
	|			BackordersBalances.SupplySource) AS BackordersBalances
	|		ON TableInventory.Company = BackordersBalances.Company
	|			AND TableInventory.Products = BackordersBalances.Products
	|			AND TableInventory.Characteristic = BackordersBalances.Characteristic
	|			AND TableInventory.StructuralUnit = BackordersBalances.SupplySource
	|WHERE
	|	&ConditionForBackorders
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.CustomerCorrOrder,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.StructuralUnit,
	|	SUM(TableInventory.Quantity)
	|FROM
	|	TemporaryTableInventoryRecipient AS TableInventory
	|WHERE
	|	&ConditionForBackorders
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.CustomerCorrOrder,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.StructuralUnit";
	
	Query.Text = StrReplace(Query.Text, "&ConditionForBackorders" ,ConditionForBackorders);
	
	Query.SetParameter("Ref", DocumentRefInventoryReservation);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableReservedProductsSource(DocumentRefInventoryReservation, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.SalesOrder AS SalesOrder
	|INTO TemporaryTableInventory
	|FROM
	|	TemporaryTableInventorySource AS TableInventory
	|WHERE
	|	VALUETYPE(TableInventory.StructuralUnit) = TYPE(Catalog.BusinessUnits)
	|	AND TableInventory.StructuralUnit <> VALUE(Catalog.BusinessUnits.EmptyRef)
	|	AND TableInventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND TableInventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|	AND TableInventory.SalesOrder <> VALUE(Document.TransferOrder.EmptyRef)
	|	AND TableInventory.SalesOrder <> UNDEFINED
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.StructuralUnit AS StructuralUnit,
	|	TemporaryTableInventory.Products AS Products,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	TemporaryTableInventory.Batch AS Batch,
	|	TemporaryTableInventory.SalesOrder AS SalesOrder
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|
	|GROUP BY
	|	TemporaryTableInventory.Characteristic,
	|	TemporaryTableInventory.Batch,
	|	TemporaryTableInventory.SalesOrder,
	|	TemporaryTableInventory.Products,
	|	TemporaryTableInventory.StructuralUnit,
	|	TemporaryTableInventory.Company";
	
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
	|	ReservedProductsBalances.Company AS Company,
	|	ReservedProductsBalances.StructuralUnit AS StructuralUnit,
	|	ReservedProductsBalances.Products AS Products,
	|	ReservedProductsBalances.Characteristic AS Characteristic,
	|	ReservedProductsBalances.Batch AS Batch,
	|	ReservedProductsBalances.SalesOrder AS SalesOrder,
	|	SUM(ReservedProductsBalances.Quantity) AS Quantity
	|INTO ReservedBalance
	|FROM
	|	(SELECT
	|		ReservedProductsBalances.Company AS Company,
	|		ReservedProductsBalances.StructuralUnit AS StructuralUnit,
	|		ReservedProductsBalances.Products AS Products,
	|		ReservedProductsBalances.Characteristic AS Characteristic,
	|		ReservedProductsBalances.Batch AS Batch,
	|		ReservedProductsBalances.SalesOrder AS SalesOrder,
	|		SUM(ReservedProductsBalances.QuantityBalance) AS Quantity
	|	FROM
	|		AccumulationRegister.ReservedProducts.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, Products, Characteristic, Batch, SalesOrder) IN
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS ReservedProductsBalances
	|	
	|	GROUP BY
	|		ReservedProductsBalances.Company,
	|		ReservedProductsBalances.StructuralUnit,
	|		ReservedProductsBalances.Products,
	|		ReservedProductsBalances.Characteristic,
	|		ReservedProductsBalances.Batch,
	|		ReservedProductsBalances.SalesOrder
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
	|		DocumentRegisterRecordsReservedProducts.Quantity
	|	FROM
	|		AccumulationRegister.ReservedProducts AS DocumentRegisterRecordsReservedProducts
	|	WHERE
	|		DocumentRegisterRecordsReservedProducts.Recorder = &Ref
	|		AND DocumentRegisterRecordsReservedProducts.Period <= &ControlPeriod
	|		AND DocumentRegisterRecordsReservedProducts.RecordType = VALUE(AccumulationRecordType.Expense)) AS ReservedProductsBalances
	|
	|GROUP BY
	|	ReservedProductsBalances.Company,
	|	ReservedProductsBalances.StructuralUnit,
	|	ReservedProductsBalances.Products,
	|	ReservedProductsBalances.Characteristic,
	|	ReservedProductsBalances.Batch,
	|	ReservedProductsBalances.SalesOrder
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
	|	SUM(TableInventory.Quantity) AS Quantity
	|INTO TemporaryTableInventoryGrouped
	|FROM
	|	TemporaryTableInventorySource AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder
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
	|	TemporaryTableInventoryGrouped AS TableInventory
	|		INNER JOIN ReservedBalance AS Balance
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
	
	Query.SetParameter("Ref", DocumentRefInventoryReservation);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableReservedProductsRecipient(DocumentRefInventoryReservation, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.CustomerCorrOrder AS SalesOrder,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventoryRecipient AS TableInventory
	|WHERE
	|	VALUETYPE(TableInventory.StructuralUnit) = TYPE(Catalog.BusinessUnits)
	|	AND TableInventory.StructuralUnit <> VALUE(Catalog.BusinessUnits.EmptyRef)
	|	AND TableInventory.CustomerCorrOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND TableInventory.CustomerCorrOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|	AND TableInventory.CustomerCorrOrder <> VALUE(Document.TransferOrder.EmptyRef)
	|	AND TableInventory.CustomerCorrOrder <> UNDEFINED
	|
	|GROUP BY
	|	TableInventory.CustomerCorrOrder,
	|	TableInventory.Products,
	|	TableInventory.Batch,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Company,
	|	TableInventory.Period,
	|	TableInventory.Characteristic";
	
	QueryResult = Query.Execute();
	
	ReservedProductsRecipient = QueryResult.Unload();
	
	If StructureAdditionalProperties.TableForRegisterRecords.TableReservedProducts.Count() > 0 Then
		
		For each RowReservedProducts In ReservedProductsRecipient Do
			
			NewRowReservedProducts = StructureAdditionalProperties.TableForRegisterRecords.TableReservedProducts.Add();
			FillPropertyValues(NewRowReservedProducts, RowReservedProducts);
			
		EndDo;
		
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts", ReservedProductsRecipient);
	EndIf;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefInventoryReservation, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	InventoryReservationInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	InventoryReservationInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	InventoryReservationInventory.OriginalReservePlace AS StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN InventoryReservationInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	InventoryReservationInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryReservationInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryReservationInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	InventoryReservationInventory.Ref.SalesOrder AS SalesOrder,
	|	UNDEFINED AS CustomerCorrOrder,
	|	CASE
	|		WHEN VALUETYPE(InventoryReservationInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN InventoryReservationInventory.Quantity
	|		ELSE InventoryReservationInventory.Quantity * InventoryReservationInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindAccountingJournalEntries,
	|	&InventoryReservation AS ContentOfAccountingRecord
	|INTO TemporaryTableInventorySource
	|FROM
	|	Document.InventoryReservation.Inventory AS InventoryReservationInventory
	|WHERE
	|	InventoryReservationInventory.Ref = &Ref
	|	AND InventoryReservationInventory.OriginalReservePlace <> InventoryReservationInventory.NewReservePlace
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryReservationInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	InventoryReservationInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	InventoryReservationInventory.NewReservePlace AS StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN InventoryReservationInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	InventoryReservationInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryReservationInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryReservationInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	VALUE(Document.SalesOrder.EmptyRef) AS SalesOrder,
	|	InventoryReservationInventory.Ref.SalesOrder AS CustomerCorrOrder,
	|	CASE
	|		WHEN VALUETYPE(InventoryReservationInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN InventoryReservationInventory.Quantity
	|		ELSE InventoryReservationInventory.Quantity * InventoryReservationInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindAccountingJournalEntries,
	|	&InventoryReservation AS ContentOfAccountingRecord
	|INTO TemporaryTableInventoryRecipient
	|FROM
	|	Document.InventoryReservation.Inventory AS InventoryReservationInventory
	|WHERE
	|	InventoryReservationInventory.Ref = &Ref
	|	AND InventoryReservationInventory.OriginalReservePlace <> InventoryReservationInventory.NewReservePlace
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS SupplySource,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CustomerCorrOrder AS SalesOrder,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventoryRecipient AS TableInventory
	|WHERE
	|	VALUETYPE(TableInventory.StructuralUnit) = TYPE(Document.SalesOrder)
	|	AND TableInventory.StructuralUnit <> VALUE(Document.SalesOrder.EmptyRef)
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.CustomerCorrOrder";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefInventoryReservation);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",  StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("InventoryReservation", NStr("en = 'Inventory reservation'; ru = 'Резервирование запасов';pl = 'Rezerwacja zapasów';es_ES = 'Reserva del inventario';es_CO = 'Reserva del inventario';tr = 'Stok rezervasyonu';it = 'Riserva delle scorte';de = 'Bestandsreservierung'", MainLanguageCode));
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Reservation.
	GenerateTableReservedProductsSource(DocumentRefInventoryReservation, StructureAdditionalProperties);
	GenerateTableReservedProductsRecipient(DocumentRefInventoryReservation, StructureAdditionalProperties);
	
	// Placement of the orders.
	GenerateTableBackorders(DocumentRefInventoryReservation, StructureAdditionalProperties);
	
	// Complete the table of orders placement.
	ResultsSelection = ResultsArray[2].Select();
	While ResultsSelection.Next() Do
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.Add();
		FillPropertyValues(TableRowReceipt, ResultsSelection);
	EndDo;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefInventoryReservation, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the temporary tables
	// "RegisterRecordsBackordersChange", "RegisterRecordsReservedProductsChange" contain records, it is required to execute the
	// inventory control.
	
	If StructureTemporaryTables.RegisterRecordsBackordersChange
		OR StructureTemporaryTables.RegisterRecordsReservedProductsChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsBackordersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.SalesOrder) AS SalesOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.SupplySource) AS SupplySourcePresentation,
		|	REFPRESENTATION(BackordersBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsBackordersChange.QuantityChange, 0) + ISNULL(BackordersBalances.QuantityBalance, 0) AS BalanceBackorders,
		|	ISNULL(BackordersBalances.QuantityBalance, 0) AS QuantityBalanceBackorders
		|FROM
		|	RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange
		|		LEFT JOIN AccumulationRegister.Backorders.Balance(
		|				&ControlTime,
		|				(Company, SalesOrder, Products, Characteristic, SupplySource) In
		|					(SELECT
		|						RegisterRecordsBackordersChange.Company AS Company,
		|						RegisterRecordsBackordersChange.SalesOrder AS SalesOrder,
		|						RegisterRecordsBackordersChange.Products AS Products,
		|						RegisterRecordsBackordersChange.Characteristic AS Characteristic,
		|						RegisterRecordsBackordersChange.SupplySource AS SupplySource
		|					FROM
		|						RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange)) AS BackordersBalances
		|		ON RegisterRecordsBackordersChange.Company = BackordersBalances.Company
		|			AND RegisterRecordsBackordersChange.SalesOrder = BackordersBalances.SalesOrder
		|			AND RegisterRecordsBackordersChange.Products = BackordersBalances.Products
		|			AND RegisterRecordsBackordersChange.Characteristic = BackordersBalances.Characteristic
		|			AND RegisterRecordsBackordersChange.SupplySource = BackordersBalances.SupplySource
		|WHERE
		|	ISNULL(BackordersBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");

		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.ReservedProducts.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty() Then
			DocumentObjectInventoryReservation = DocumentRefInventoryReservation.GetObject()
		EndIf;
		
		// Negative balance on inventory placement.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToBackordersRegisterErrors(DocumentObjectInventoryReservation, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of need for reserved products.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToReservedProductsRegisterErrors(DocumentObjectInventoryReservation, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory with reserves.
		DriveServer.CheckAvailableStockBalance(DocumentObjectInventoryReservation, AdditionalProperties, Cancel);
		
		DriveServer.CheckOrderedMinusBackorderedBalance(DocumentRefInventoryReservation, AdditionalProperties, Cancel);
		
	EndIf;
	
EndProcedure

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	GLAccountsForFilling = New Structure;
	GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
	
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

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#EndIf