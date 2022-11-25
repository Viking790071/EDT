#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler BeforeWrite record set.
//
Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR Not AdditionalProperties.Property("ForPosting")
		OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
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
		OR Not AdditionalProperties.Property("ForPosting")
		OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
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
	Query.SetParameter("OrdersArray", OrdersTable.UnloadColumn("TransferOrder"));
	Query.Text =
	"SELECT
	|	TransferOrderBalances.Company AS Company,
	|	TransferOrderBalances.TransferOrder AS TransferOrder,
	|	TransferOrderBalances.Products AS Products,
	|	TransferOrderBalances.Characteristic AS Characteristic,
	|	TransferOrderBalances.QuantityBalance AS QuantityBalance
	|INTO TU_Balance
	|FROM
	|	AccumulationRegister.TransferOrders.Balance(, TransferOrder IN (&OrdersArray)) AS TransferOrderBalances
	|
	|INDEX BY
	|	Company,
	|	TransferOrder,
	|	Products,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN Table.ShipmentDate = DATETIME(1, 1, 1)
	|			THEN BEGINOFPERIOD(Table.Period, Day)
	|		ELSE BEGINOFPERIOD(Table.ShipmentDate, Day)
	|	END AS Period,
	|	Table.Company AS Company,
	|	Table.TransferOrder AS TransferOrder,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	SUM(Table.Quantity) AS QuantityPlan
	|INTO TU_RegisterRecordPlan
	|FROM
	|	AccumulationRegister.TransferOrders AS Table
	|WHERE
	|	Table.TransferOrder IN(&OrdersArray)
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Table.Quantity > 0
	|	AND Table.Active
	|
	|GROUP BY
	|	CASE
	|		WHEN Table.ShipmentDate = DATETIME(1, 1, 1)
	|			THEN BEGINOFPERIOD(Table.Period, Day)
	|		ELSE BEGINOFPERIOD(Table.ShipmentDate, Day)
	|	END,
	|	Table.Company,
	|	Table.TransferOrder,
	|	Table.Products,
	|	Table.Characteristic
	|
	|INDEX BY
	|	Company,
	|	TransferOrder,
	|	Products,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TU_Table.Period AS Period,
	|	TU_Table.Company AS Company,
	|	TU_Table.TransferOrder AS TransferOrder,
	|	TU_Table.Products AS Products,
	|	TU_Table.Characteristic AS Characteristic,
	|	TU_Table.QuantityPlan AS QuantityPlan,
	|	ISNULL(TU_Balance.QuantityBalance, 0) AS QuantityBalance
	|FROM
	|	TU_RegisterRecordPlan AS TU_Table
	|		LEFT JOIN TU_Balance AS TU_Balance
	|		ON TU_Table.Company = TU_Balance.Company
	|			AND TU_Table.TransferOrder = TU_Balance.TransferOrder
	|			AND TU_Table.Products = TU_Balance.Products
	|			AND TU_Table.Characteristic = TU_Balance.Characteristic
	|
	|ORDER BY
	|	TransferOrder,
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
		CurTransferOrder = Selection.TransferOrder;
		
		RecordSet.Filter.Order.Set(CurTransferOrder);
		
		// Delete the closed order from the table.
		OrdersTable.Delete(OrdersTable.Find(CurTransferOrder, "TransferOrder"));
		
		// Cycle by single order strings.
		TotalPlan = 0;
		TotalBalance = 0;
		StructureRecordSet = New Structure;
		While ThereAreRecordsInSelection AND Selection.TransferOrder = CurTransferOrder Do
			
			TotalPlan = TotalPlan + Selection.QuantityPlan;
			
			If CurProducts <> Selection.Products
				OR CurCharacteristic <> Selection.Characteristic
				OR CurCompany <> Selection.Company Then
				
				CurProducts = Selection.Products;
				CurCharacteristic = Selection.Characteristic;
				CurCompany = Selection.Company;
				
				TotalQuantityBalance = 0;
				If Selection.QuantityBalance > 0 Then
					TotalQuantityBalance = Selection.QuantityBalance;
				EndIf;
				
				TotalBalance = TotalBalance + Selection.QuantityBalance;
				
			EndIf;
			
			CurQuantity = min(Selection.QuantityPlan, TotalQuantityBalance);
			If CurQuantity > 0 AND ?(ValueIsFilled(CurPeriod), CurPeriod > Selection.Period, True) Then
				
				StructureRecordSet.Insert("Period", Selection.Period);
				StructureRecordSet.Insert("TransferOrder", Selection.TransferOrder);
				
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
			Record.Order = StructureRecordSet.TransferOrder;
			Record.Completed = TotalPlan - TotalBalance;
		EndIf;
		
		RecordSet.Write(True);
		RecordSet.Clear();
		
	EndDo;
	
	// The register records should be cleared for unfinished orders.
	If OrdersTable.Count() > 0 Then
		For Each TabRow In OrdersTable Do
			
			RecordSet.Filter.Order.Set(TabRow.TransferOrder);
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
	|	TableTransferOrders.TransferOrder AS TransferOrder
	|FROM
	|	AccumulationRegister.TransferOrders AS TableTransferOrders
	|WHERE
	|	TableTransferOrders.Recorder = &Recorder";
	
	OrdersTable = Query.Execute().Unload();
	TableOfNewOrders = Unload(, "TransferOrder");
	TableOfNewOrders.GroupBy("TransferOrder");
	For Each Record In TableOfNewOrders Do
		
		If OrdersTable.Find(Record.TransferOrder, "TransferOrder") = Undefined Then
			OrdersTable.Add().TransferOrder = Record.TransferOrder;
		EndIf;
		
	EndDo;
	
	AdditionalProperties.Insert("OrdersTable", OrdersTable);
	
EndProcedure

// Procedure locks data for schedule calculation.
//
Procedure InstallLocksOnDataForCalculatingSchedule()
	
	Block = New DataLock;
	
	// Locking the register for balance calculation by orders.
	LockItem = Block.Add("AccumulationRegister.TransferOrders");
	LockItem.Mode = DataLockMode.Shared;
	LockItem.DataSource = AdditionalProperties.OrdersTable;
	LockItem.UseFromDataSource("TransferOrder", "TransferOrder");
	
	// Locking the record set.
	LockItem = Block.Add("InformationRegister.OrderFulfillmentSchedule");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = AdditionalProperties.OrdersTable;
	LockItem.UseFromDataSource("Order", "TransferOrder");
	
	Block.Lock();
	
EndProcedure

// Procedure forms the table of initial records of the register.
//
Procedure GenerateSourceRecordsTable(Cancel, Replacing)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Setting the exclusive lock of the current set of records of the registrar.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.TransferOrders.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsTransferOrdersChange")
		OR StructureTemporaryTables.Property("RegisterRecordsTransferOrdersChange")
		AND Not StructureTemporaryTables.RegisterRecordsTransferOrdersChange Then
		
		// If the "RegisterRecordsTransferOrdersChange" temporary table does not exist and
		// does not contain records on change of the set, it means that the set is written for the first time, and the set was
		// controlled for balances. Current state of the set is placed into the "RegisterRecordsTransferOrdersBeforeWrite"
		// temporary table to get the change of a new set with respect to the current set when writing.
		
		Query = New Query(
		"SELECT
		|	TransferOrders.LineNumber AS LineNumber,
		|	TransferOrders.Company AS Company,
		|	TransferOrders.TransferOrder AS TransferOrder,
		|	TransferOrders.Products AS Products,
		|	TransferOrders.Characteristic AS Characteristic,
		|	CASE
		|		WHEN TransferOrders.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN TransferOrders.Quantity
		|		ELSE -TransferOrders.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsTransferOrdersBeforeWrite
		|FROM
		|	AccumulationRegister.TransferOrders AS TransferOrders
		|WHERE
		|	TransferOrders.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the "RegisterRecordsTransferOrdersChange" temporary table exists and
		// contains records about the set change, it means the set is written not for the first time and the set was not
		// controlled for balances. Current state of the set and current state of changes are placed into the
		// "RegisterRecordsTransferOrdersBeforeWrite" temporary table to get the change of a new set with respect to the initial
		// set when writing.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsTransferOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsTransferOrdersChange.Company AS Company,
		|	RegisterRecordsTransferOrdersChange.TransferOrder AS TransferOrder,
		|	RegisterRecordsTransferOrdersChange.Products AS Products,
		|	RegisterRecordsTransferOrdersChange.Characteristic AS Characteristic,
		|	RegisterRecordsTransferOrdersChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsTransferOrdersBeforeWrite
		|FROM
		|	RegisterRecordsTransferOrdersChange AS RegisterRecordsTransferOrdersChange
		|
		|UNION ALL
		|
		|SELECT
		|	TransferOrders.LineNumber,
		|	TransferOrders.Company,
		|	TransferOrders.TransferOrder,
		|	TransferOrders.Products,
		|	TransferOrders.Characteristic,
		|	CASE
		|		WHEN TransferOrders.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN TransferOrders.Quantity
		|		ELSE -TransferOrders.Quantity
		|	END
		|FROM
		|	AccumulationRegister.TransferOrders AS TransferOrders
		|WHERE
		|	TransferOrders.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table "RegisterRecordsTransferOrdersChange" is deleted
	// Information related to its existence is deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsTransferOrdersChange") Then
		
		Query = New Query("DROP RegisterRecordsTransferOrdersChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsTransferOrdersChange");
		
	EndIf;
	
EndProcedure

// Procedure forms the table of change records of the register.
//
Procedure GenerateRecordsChangeTable(Cancel, Replacing)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Change of a new set is calculated with respect to current one, taking into account the accumulated changes,
	// and the set is placed into the "RegisterRecordsTransferOrdersChange" temporary table.
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsTransferOrdersChange.LineNumber) AS LineNumber,
	|	RegisterRecordsTransferOrdersChange.Company AS Company,
	|	RegisterRecordsTransferOrdersChange.TransferOrder AS TransferOrder,
	|	RegisterRecordsTransferOrdersChange.Products AS Products,
	|	RegisterRecordsTransferOrdersChange.Characteristic AS Characteristic,
	|	SUM(RegisterRecordsTransferOrdersChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsTransferOrdersChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsTransferOrdersChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsTransferOrdersChange
	|FROM
	|	(SELECT
	|		RegisterRecordsTransferOrdersBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsTransferOrdersBeforeWrite.Company AS Company,
	|		RegisterRecordsTransferOrdersBeforeWrite.TransferOrder AS TransferOrder,
	|		RegisterRecordsTransferOrdersBeforeWrite.Products AS Products,
	|		RegisterRecordsTransferOrdersBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsTransferOrdersBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsTransferOrdersBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsTransferOrdersBeforeWrite AS RegisterRecordsTransferOrdersBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsTransferOrdersOnWrite.LineNumber,
	|		RegisterRecordsTransferOrdersOnWrite.Company,
	|		RegisterRecordsTransferOrdersOnWrite.TransferOrder,
	|		RegisterRecordsTransferOrdersOnWrite.Products,
	|		RegisterRecordsTransferOrdersOnWrite.Characteristic,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsTransferOrdersOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsTransferOrdersOnWrite.Quantity
	|			ELSE RegisterRecordsTransferOrdersOnWrite.Quantity
	|		END,
	|		RegisterRecordsTransferOrdersOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.TransferOrders AS RegisterRecordsTransferOrdersOnWrite
	|	WHERE
	|		RegisterRecordsTransferOrdersOnWrite.Recorder = &Recorder) AS RegisterRecordsTransferOrdersChange
	|
	|GROUP BY
	|	RegisterRecordsTransferOrdersChange.Company,
	|	RegisterRecordsTransferOrdersChange.TransferOrder,
	|	RegisterRecordsTransferOrdersChange.Products,
	|	RegisterRecordsTransferOrdersChange.Characteristic
	|
	|HAVING
	|	SUM(RegisterRecordsTransferOrdersChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	TransferOrder,
	|	Products,
	|	Characteristic");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsTransferOrdersChange".
	// The information on its existence and change records availability in it is added.
	StructureTemporaryTables.Insert("RegisterRecordsTransferOrdersChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsTransferOrdersBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsTransferOrdersBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf