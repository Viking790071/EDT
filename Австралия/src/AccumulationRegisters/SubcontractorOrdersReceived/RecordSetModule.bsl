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
	|	SubcontractorOrdersReceivedBalances.Company AS Company,
	|	SubcontractorOrdersReceivedBalances.SubcontractorOrder AS SubcontractorOrder,
	|	SubcontractorOrdersReceivedBalances.Products AS Products,
	|	SubcontractorOrdersReceivedBalances.Characteristic AS Characteristic,
	|	SubcontractorOrdersReceivedBalances.QuantityBalance AS QuantityBalance
	|INTO TU_Balance
	|FROM
	|	AccumulationRegister.SubcontractorOrdersReceived.Balance(, SubcontractorOrder IN (&OrdersArray)) AS SubcontractorOrdersReceivedBalances
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
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.SubcontractorOrder AS SubcontractorOrder,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	SUM(Table.Quantity) AS QuantityPlan
	|INTO TU_RegisterRecordPlan
	|FROM
	|	AccumulationRegister.SubcontractorOrdersReceived AS Table
	|WHERE
	|	Table.SubcontractorOrder IN(&OrdersArray)
	|	AND Table.Quantity > 0
	|	AND Table.Active
	|
	|GROUP BY
	|	Table.Period,
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
	|	TableSubcontractorOrdersReceived.SubcontractorOrder AS SubcontractorOrder
	|FROM
	|	AccumulationRegister.SubcontractorOrdersReceived AS TableSubcontractorOrdersReceived
	|WHERE
	|	TableSubcontractorOrdersReceived.Recorder = &Recorder";
	
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
	LockItem = Block.Add("AccumulationRegister.SubcontractorOrdersReceived");
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
	LockItem = Block.Add("AccumulationRegister.SubcontractorOrdersReceived.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsSubcontractorOrdersReceivedChange")
		Or StructureTemporaryTables.Property("RegisterRecordsSubcontractorOrdersReceivedChange")
		And Not StructureTemporaryTables.RegisterRecordsSubcontractorOrdersReceivedChange Then
		
		// If the "RegisterRecordsSubcontractorOrdersReceivedChange" temporary table does not exist and
		// does not contain records on change of the set, it means that the set is written for the first time, and the set was
		// controlled for balances. Current state of the set is placed into the "RegisterRecordsSubcontractorOrdersReceivedBeforeWrite"
		// temporary table to get the change of a new set with respect to the current set when writing.
		
		Query = New Query(
		"SELECT
		|	SubcontractorOrdersReceived.LineNumber AS LineNumber,
		|	SubcontractorOrdersReceived.Company AS Company,
		|	SubcontractorOrdersReceived.Counterparty AS Counterparty,
		|	SubcontractorOrdersReceived.SubcontractorOrder AS SubcontractorOrder,
		|	SubcontractorOrdersReceived.Products AS Products,
		|	SubcontractorOrdersReceived.Characteristic AS Characteristic,
		|	CASE
		|		WHEN SubcontractorOrdersReceived.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN SubcontractorOrdersReceived.Quantity
		|		ELSE -SubcontractorOrdersReceived.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsSubcontractorOrdersReceivedBeforeWrite
		|FROM
		|	AccumulationRegister.SubcontractorOrdersReceived AS SubcontractorOrdersReceived
		|WHERE
		|	SubcontractorOrdersReceived.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the "RegisterRecordsSubcontractorOrdersReceivedChange" temporary table exists and
		// contains records about the set change, it means the set is written not for the first time and the set was not
		// controlled for balances. Current state of the set and current state of changes are placed into the
		// "RegisterRecordsSubcontractorOrdersReceivedBeforeWrite" temporary table to get the change of a new set with respect to the initial
		// set when writing.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsSubcontractorOrdersReceivedChange.LineNumber AS LineNumber,
		|	RegisterRecordsSubcontractorOrdersReceivedChange.Company AS Company,
		|	RegisterRecordsSubcontractorOrdersReceivedChange.Counterparty AS Counterparty,
		|	RegisterRecordsSubcontractorOrdersReceivedChange.SubcontractorOrder AS SubcontractorOrder,
		|	RegisterRecordsSubcontractorOrdersReceivedChange.Products AS Products,
		|	RegisterRecordsSubcontractorOrdersReceivedChange.Characteristic AS Characteristic,
		|	RegisterRecordsSubcontractorOrdersReceivedChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsSubcontractorOrdersReceivedChange
		|FROM
		|	RegisterRecordsSubcontractorOrdersReceivedChange AS RegisterRecordsSubcontractorOrdersReceivedChange
		|
		|UNION ALL
		|
		|SELECT
		|	SubcontractorOrdersReceived.LineNumber,
		|	SubcontractorOrdersReceived.Company,
		|	SubcontractorOrdersReceived.Counterparty,
		|	SubcontractorOrdersReceived.SubcontractorOrder,
		|	SubcontractorOrdersReceived.Products,
		|	SubcontractorOrdersReceived.Characteristic,
		|	CASE
		|		WHEN SubcontractorOrdersReceived.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN SubcontractorOrdersReceived.Quantity
		|		ELSE -SubcontractorOrdersReceived.Quantity
		|	END
		|FROM
		|	AccumulationRegister.SubcontractorOrdersReceived AS SubcontractorOrdersReceived
		|WHERE
		|	SubcontractorOrdersReceived.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table "RegisterRecordsSubcontractorOrdersReceivedChange" is deleted
	// Information related to its existence is deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsSubcontractorOrdersReceivedChange") Then
		
		Query = New Query("DROP RegisterRecordsSubcontractorOrdersReceivedChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsSubcontractorOrdersReceivedChange");
		
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
	|	MIN(RegisterRecordsSubcontractorOrdersReceivedChange.LineNumber) AS LineNumber,
	|	RegisterRecordsSubcontractorOrdersReceivedChange.Company AS Company,
	|	RegisterRecordsSubcontractorOrdersReceivedChange.Counterparty AS Counterparty,
	|	RegisterRecordsSubcontractorOrdersReceivedChange.SubcontractorOrder AS SubcontractorOrder,
	|	RegisterRecordsSubcontractorOrdersReceivedChange.Products AS Products,
	|	RegisterRecordsSubcontractorOrdersReceivedChange.Characteristic AS Characteristic,
	|	SUM(RegisterRecordsSubcontractorOrdersReceivedChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsSubcontractorOrdersReceivedChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsSubcontractorOrdersReceivedChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsSubcontractorOrdersReceivedChange
	|FROM
	|	(SELECT
	|		RegisterRecordsSubcontractorOrdersReceivedBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsSubcontractorOrdersReceivedBeforeWrite.Company AS Company,
	|		RegisterRecordsSubcontractorOrdersReceivedBeforeWrite.Counterparty AS Counterparty,
	|		RegisterRecordsSubcontractorOrdersReceivedBeforeWrite.SubcontractorOrder AS SubcontractorOrder,
	|		RegisterRecordsSubcontractorOrdersReceivedBeforeWrite.Products AS Products,
	|		RegisterRecordsSubcontractorOrdersReceivedBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsSubcontractorOrdersReceivedBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsSubcontractorOrdersReceivedBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsSubcontractorOrdersReceivedBeforeWrite AS RegisterRecordsSubcontractorOrdersReceivedBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsSubcontractorOrdersReceivedOnWrite.LineNumber,
	|		RegisterRecordsSubcontractorOrdersReceivedOnWrite.Company,
	|		RegisterRecordsSubcontractorOrdersReceivedOnWrite.Counterparty AS Counterparty,
	|		RegisterRecordsSubcontractorOrdersReceivedOnWrite.SubcontractorOrder,
	|		RegisterRecordsSubcontractorOrdersReceivedOnWrite.Products,
	|		RegisterRecordsSubcontractorOrdersReceivedOnWrite.Characteristic,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsSubcontractorOrdersReceivedOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsSubcontractorOrdersReceivedOnWrite.Quantity
	|			ELSE RegisterRecordsSubcontractorOrdersReceivedOnWrite.Quantity
	|		END,
	|		RegisterRecordsSubcontractorOrdersReceivedOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.SubcontractorOrdersReceived AS RegisterRecordsSubcontractorOrdersReceivedOnWrite
	|	WHERE
	|		RegisterRecordsSubcontractorOrdersReceivedOnWrite.Recorder = &Recorder) AS RegisterRecordsSubcontractorOrdersReceivedChange
	|
	|GROUP BY
	|	RegisterRecordsSubcontractorOrdersReceivedChange.Company,
	|	RegisterRecordsSubcontractorOrdersReceivedChange.Counterparty,
	|	RegisterRecordsSubcontractorOrdersReceivedChange.SubcontractorOrder,
	|	RegisterRecordsSubcontractorOrdersReceivedChange.Products,
	|	RegisterRecordsSubcontractorOrdersReceivedChange.Characteristic
	|
	|HAVING
	|	SUM(RegisterRecordsSubcontractorOrdersReceivedChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	Counterparty,
	|	SubcontractorOrder,
	|	Products,
	|	Characteristic");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsSubcontractorOrdersReceivedChange".
	// The information on its existence and change records availability in it is added.
	StructureTemporaryTables.Insert("RegisterRecordsSubcontractorOrdersReceivedChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsSubcontractorOrdersReceivedBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsSubcontractorOrdersReceivedBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf