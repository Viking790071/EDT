#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

// Procedure - event handler BeforeWrite record set.
//
Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load
		Or Not AdditionalProperties.Property("ForPosting")
		Or Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	GenerateSourceRecordsTable(Cancel, Replacing);
	
	GenerateTableOfOrders();
	InstallLocksOnDataForCalculatingSchedule();
	
EndProcedure

// Procedure - event handler OnWrite record set.
//
Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load
		Or Not AdditionalProperties.Property("ForPosting")
		Or Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	GenerateRecordsChangeTable(Cancel, Replacing);
	
	CalculateOrdersFulfilmentSchedule();
	
EndProcedure

#EndRegion

#Region Private

// Procedure calculates and writes the schedule of order execution.
// Shipping date is specified in "Period". Upon the actual shipment by order,
// the schedule is closed according to FIFO.
//
Procedure CalculateOrdersFulfilmentSchedule()
	
	OrdersTable = AdditionalProperties.OrdersTable;
	
	Query = New Query;
	Query.SetParameter("OrdersArray", OrdersTable.UnloadColumn("SubcontractorOrder"));
	Query.Text =
	"SELECT
	|	SubcontractorOrdersBalances.Company AS Company,
	|	SubcontractorOrdersBalances.SubcontractorOrder AS SubcontractorOrder,
	|	SubcontractorOrdersBalances.Products AS Products,
	|	SubcontractorOrdersBalances.Characteristic AS Characteristic,
	|	SubcontractorOrdersBalances.QuantityBalance AS QuantityBalance
	|INTO TU_Balance
	|FROM
	|	AccumulationRegister.SubcontractorOrdersIssued.Balance(, SubcontractorOrder IN (&OrdersArray)) AS SubcontractorOrdersBalances
	|
	|INDEX BY
	|	Company,
	|	SubcontractorOrder,
	|	Products,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BEGINOFPERIOD(Table.ReceiptDate, DAY) AS Period,
	|	Table.Company AS Company,
	|	Table.SubcontractorOrder AS SubcontractorOrder,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	SUM(Table.Quantity) AS QuantityPlan
	|INTO TU_RegisterRecordPlan
	|FROM
	|	AccumulationRegister.SubcontractorOrdersIssued AS Table
	|WHERE
	|	Table.SubcontractorOrder IN(&OrdersArray)
	|	AND Table.ReceiptDate <> DATETIME(1, 1, 1)
	|	AND Table.Quantity > 0
	|	AND Table.Active
	|
	|GROUP BY
	|	BEGINOFPERIOD(Table.ReceiptDate, DAY),
	|	Table.Company,
	|	Table.SubcontractorOrder,
	|	Table.Products,
	|	Table.Characteristic
	|
	|INDEX BY
	|	Company,
	|	SubcontractorOrder,
	|	Products,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TU_Table.Period AS Period,
	|	TU_Table.Company AS Company,
	|	TU_Table.SubcontractorOrder AS SubcontractorOrder,
	|	TU_Table.Products AS Products,
	|	TU_Table.Characteristic AS Characteristic,
	|	TU_Table.QuantityPlan AS QuantityPlan,
	|	ISNULL(TU_Balance.QuantityBalance, 0) AS QuantityBalance
	|FROM
	|	TU_RegisterRecordPlan AS TU_Table
	|		LEFT JOIN TU_Balance AS TU_Balance
	|		ON TU_Table.Company = TU_Balance.Company
	|			AND TU_Table.SubcontractorOrder = TU_Balance.SubcontractorOrder
	|			AND TU_Table.Products = TU_Balance.Products
	|			AND TU_Table.Characteristic = TU_Balance.Characteristic
	|
	|ORDER BY
	|	SubcontractorOrder,
	|	Products,
	|	Characteristic,
	|	Period DESC";
	
	RecordSet = InformationRegisters.OrderFulfillmentSchedule.CreateRecordSet();
	Selection = Query.Execute().Select();
	ThereAreRecordsInSelection = Selection.Next();
	
	While ThereAreRecordsInSelection Do
		
		CurPeriod = Undefined;
		CurCompany = Undefined;
		CurProducts = Undefined;
		CurCharacteristic = Undefined;
		CurOrder = Selection.SubcontractorOrder;
		
		RecordSet.Filter.Order.Set(CurOrder);
		
		// Delete the closed order from the table.
		OrdersTable.Delete(OrdersTable.Find(CurOrder, "SubcontractorOrder"));
		
		// Cycle by single order strings.
		TotalPlan = 0;
		TotalBalance = 0;
		StructureRecordSet = New Structure;
		While ThereAreRecordsInSelection And Selection.SubcontractorOrder = CurOrder Do
			
			TotalPlan = TotalPlan + Selection.QuantityPlan;
			
			If CurProducts <> Selection.Products
				Or CurCharacteristic <> Selection.Characteristic
				Or CurCompany <> Selection.Company Then
				
				CurProducts = Selection.Products;
				CurCharacteristic = Selection.Characteristic;
				CurCompany = Selection.Company;
				
				TotalQuantityBalance = 0;
				If Selection.QuantityBalance > 0 Then
					TotalQuantityBalance = Selection.QuantityBalance;
				EndIf;
				
				TotalBalance = TotalBalance + Selection.QuantityBalance;
				
			EndIf;
			
			CurQuantity = Min(Selection.QuantityPlan, TotalQuantityBalance);
			If CurQuantity > 0 And ?(ValueIsFilled(CurPeriod), CurPeriod > Selection.Period, True) Then
				
				StructureRecordSet.Insert("Period", Selection.Period);
				StructureRecordSet.Insert("SubcontractorOrder", Selection.SubcontractorOrder);
				
				CurPeriod = Selection.Period;
				
			EndIf;
			
			TotalQuantityBalance = TotalQuantityBalance - CurQuantity;
			
			// Go to the next record in the selection.
			ThereAreRecordsInSelection = Selection.Next();
			
		EndDo;
		
		// Writing and clearing the set.
		If StructureRecordSet.Count() > 0 Then
			Record = RecordSet.Add();
			Record.Period = StructureRecordSet.Period;
			Record.Order = StructureRecordSet.SubcontractorOrder;
			Record.Completed = TotalPlan - TotalBalance;
		EndIf;
		
		RecordSet.Write(True);
		RecordSet.Clear();
		
	EndDo;
	
	// The register records should be cleared for unfinished orders.
	If OrdersTable.Count() > 0 Then
		For Each TabRow In OrdersTable Do
			
			RecordSet.Filter.Order.Set(TabRow.SubcontractorOrder);
			RecordSet.Write(True);
			RecordSet.Clear();
			
		EndDo;
	EndIf;
	
EndProcedure

// Procedure forms the table of orders that were
// previously in the register records and which will be written now.
//
Procedure GenerateTableOfOrders()
	
	Query = New Query;
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.Text =
	"SELECT DISTINCT
	|	TableSubcontractorOrdersIssued.SubcontractorOrder AS SubcontractorOrder
	|FROM
	|	AccumulationRegister.SubcontractorOrdersIssued AS TableSubcontractorOrdersIssued
	|WHERE
	|	TableSubcontractorOrdersIssued.Recorder = &Recorder";
	
	OrdersTable = Query.Execute().Unload();
	TableOfNewOrders = Unload(, "SubcontractorOrder");
	TableOfNewOrders.GroupBy("SubcontractorOrder");
	For Each Record In TableOfNewOrders Do
		
		If OrdersTable.Find(Record.SubcontractorOrder, "SubcontractorOrder") = Undefined Then
			OrdersTable.Add().SubcontractorOrder = Record.SubcontractorOrder;
		EndIf;
		
	EndDo;
	
	AdditionalProperties.Insert("OrdersTable", OrdersTable);
	
EndProcedure

// Procedure locks data for schedule calculation.
//
Procedure InstallLocksOnDataForCalculatingSchedule()
	
	Block = New DataLock;
	
	// Locking the register for balance calculation by orders.
	LockItem = Block.Add("AccumulationRegister.SubcontractorOrdersIssued");
	LockItem.Mode = DataLockMode.Shared;
	LockItem.DataSource = AdditionalProperties.OrdersTable;
	LockItem.UseFromDataSource("SubcontractorOrder", "SubcontractorOrder");
	
	// Locking the record set.
	LockItem = Block.Add("InformationRegister.OrderFulfillmentSchedule");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = AdditionalProperties.OrdersTable;
	LockItem.UseFromDataSource("Order", "SubcontractorOrder");
	
	Block.Lock();
	
EndProcedure

// Procedure forms the table of initial records of the register.
//
Procedure GenerateSourceRecordsTable(Cancel, Replacing)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Setting the exclusive lock of the current set of records of the registrar.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.SubcontractorOrdersIssued.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsSubcontractorOrdersIssuedChange")
		Or StructureTemporaryTables.Property("RegisterRecordsSubcontractorOrdersIssuedChange")
		And Not StructureTemporaryTables.RegisterRecordsSubcontractorOrdersIssuedChange Then
		
		// If the "RegisterRecordsSubcontractorOrdersIssuedChange" temporary table does not exist and
		// does not contain records on change of the set, it means that the set is written for the first time, and the set was
		// controlled for balances. Current state of the set is placed into the "RegisterRecordsSubcontractorOrdersBeforeWrite"
		// temporary table to get the change of a new set with respect to the current set when writing.
		
		Query = New Query(
		"SELECT
		|	SubcontractorOrdersIssued.LineNumber AS LineNumber,
		|	SubcontractorOrdersIssued.Company AS Company,
		|	SubcontractorOrdersIssued.SubcontractorOrder AS SubcontractorOrder,
		|	SubcontractorOrdersIssued.Products AS Products,
		|	SubcontractorOrdersIssued.Characteristic AS Characteristic,
		|	SubcontractorOrdersIssued.FinishedProductType AS FinishedProductType,
		|	CASE
		|		WHEN SubcontractorOrdersIssued.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN SubcontractorOrdersIssued.Quantity
		|		ELSE -SubcontractorOrdersIssued.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsSubcontractorOrdersBeforeWrite
		|FROM
		|	AccumulationRegister.SubcontractorOrdersIssued AS SubcontractorOrdersIssued
		|WHERE
		|	SubcontractorOrdersIssued.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the "RegisterRecordsSubcontractorOrdersIssuedChange" temporary table exists and
		// contains records about the set change, it means the set is written not for the first time and the set was not
		// controlled for balances. Current state of the set and current state of changes are placed into the
		// "RegisterRecordsSubcontractorOrdersBeforeWrite" temporary table to get the change of a new set with respect to the initial
		// set when writing.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsSubcontractorOrdersIssuedChange.LineNumber AS LineNumber,
		|	RegisterRecordsSubcontractorOrdersIssuedChange.Company AS Company,
		|	RegisterRecordsSubcontractorOrdersIssuedChange.SubcontractorOrder AS SubcontractorOrder,
		|	RegisterRecordsSubcontractorOrdersIssuedChange.Products AS Products,
		|	RegisterRecordsSubcontractorOrdersIssuedChange.Characteristic AS Characteristic,
		|	RegisterRecordsSubcontractorOrdersIssuedChange.FinishedProductType AS FinishedProductType,
		|	RegisterRecordsSubcontractorOrdersIssuedChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsSubcontractorOrdersBeforeWrite
		|FROM
		|	RegisterRecordsSubcontractorOrdersIssuedChange AS RegisterRecordsSubcontractorOrdersIssuedChange
		|
		|UNION ALL
		|
		|SELECT
		|	SubcontractorOrdersIssued.LineNumber,
		|	SubcontractorOrdersIssued.Company,
		|	SubcontractorOrdersIssued.SubcontractorOrder,
		|	SubcontractorOrdersIssued.Products,
		|	SubcontractorOrdersIssued.Characteristic,
		|	SubcontractorOrdersIssued.FinishedProductType,
		|	CASE
		|		WHEN SubcontractorOrdersIssued.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN SubcontractorOrdersIssued.Quantity
		|		ELSE -SubcontractorOrdersIssued.Quantity
		|	END
		|FROM
		|	AccumulationRegister.SubcontractorOrdersIssued AS SubcontractorOrdersIssued
		|WHERE
		|	SubcontractorOrdersIssued.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table "RegisterRecordsSubcontractorOrdersIssuedChange" is deleted
	// Information related to its existence is deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsSubcontractorOrdersIssuedChange") Then
		
		Query = New Query("DROP RegisterRecordsSubcontractorOrdersIssuedChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsSubcontractorOrdersIssuedChange");
		
	EndIf;
	
EndProcedure

// Procedure forms the table of change records of the register.
//
Procedure GenerateRecordsChangeTable(Cancel, Replacing)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Change of a new set is calculated with respect to current one, taking into account the accumulated changes,
	// and the set is placed into the "RegisterRecordsSalesOrdersChange" temporary table.
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsSubcontractorOrdersIssuedChange.LineNumber) AS LineNumber,
	|	RegisterRecordsSubcontractorOrdersIssuedChange.Company AS Company,
	|	RegisterRecordsSubcontractorOrdersIssuedChange.SubcontractorOrder AS SubcontractorOrder,
	|	RegisterRecordsSubcontractorOrdersIssuedChange.Products AS Products,
	|	RegisterRecordsSubcontractorOrdersIssuedChange.Characteristic AS Characteristic,
	|	RegisterRecordsSubcontractorOrdersIssuedChange.FinishedProductType AS FinishedProductType,
	|	SUM(RegisterRecordsSubcontractorOrdersIssuedChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsSubcontractorOrdersIssuedChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsSubcontractorOrdersIssuedChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsSubcontractorOrdersIssuedChange
	|FROM
	|	(SELECT
	|		RegisterRecordsSubcontractorOrdersBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsSubcontractorOrdersBeforeWrite.Company AS Company,
	|		RegisterRecordsSubcontractorOrdersBeforeWrite.SubcontractorOrder AS SubcontractorOrder,
	|		RegisterRecordsSubcontractorOrdersBeforeWrite.Products AS Products,
	|		RegisterRecordsSubcontractorOrdersBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsSubcontractorOrdersBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsSubcontractorOrdersBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite,
	|		RegisterRecordsSubcontractorOrdersBeforeWrite.FinishedProductType AS FinishedProductType
	|	FROM
	|		RegisterRecordsSubcontractorOrdersBeforeWrite AS RegisterRecordsSubcontractorOrdersBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsSubcontractorOrdersOnWrite.LineNumber,
	|		RegisterRecordsSubcontractorOrdersOnWrite.Company,
	|		RegisterRecordsSubcontractorOrdersOnWrite.SubcontractorOrder,
	|		RegisterRecordsSubcontractorOrdersOnWrite.Products,
	|		RegisterRecordsSubcontractorOrdersOnWrite.Characteristic,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsSubcontractorOrdersOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsSubcontractorOrdersOnWrite.Quantity
	|			ELSE RegisterRecordsSubcontractorOrdersOnWrite.Quantity
	|		END,
	|		RegisterRecordsSubcontractorOrdersOnWrite.Quantity,
	|		RegisterRecordsSubcontractorOrdersOnWrite.FinishedProductType
	|	FROM
	|		AccumulationRegister.SubcontractorOrdersIssued AS RegisterRecordsSubcontractorOrdersOnWrite
	|	WHERE
	|		RegisterRecordsSubcontractorOrdersOnWrite.Recorder = &Recorder) AS RegisterRecordsSubcontractorOrdersIssuedChange
	|
	|GROUP BY
	|	RegisterRecordsSubcontractorOrdersIssuedChange.Company,
	|	RegisterRecordsSubcontractorOrdersIssuedChange.SubcontractorOrder,
	|	RegisterRecordsSubcontractorOrdersIssuedChange.Products,
	|	RegisterRecordsSubcontractorOrdersIssuedChange.Characteristic,
	|	RegisterRecordsSubcontractorOrdersIssuedChange.FinishedProductType
	|
	|HAVING
	|	SUM(RegisterRecordsSubcontractorOrdersIssuedChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	SubcontractorOrder,
	|	Products,
	|	Characteristic");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsSubcontractorOrdersIssuedChange".
	// The information on its existence and change records availability in it is added.
	StructureTemporaryTables.Insert("RegisterRecordsSubcontractorOrdersIssuedChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsSubcontractorOrdersBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsSubcontractorOrdersBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf