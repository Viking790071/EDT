#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInventory(DocumentRefCosting, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.CostObject AS CostObject
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.StructuralUnit,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.CostObject";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Inventory");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving inventory balances by cost.
	Query.Text = 	
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.PresentationCurrency AS PresentationCurrency,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.InventoryAccountType AS InventoryAccountType,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.Ownership AS Ownership,
	|	InventoryBalances.CostObject AS CostObject,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.PresentationCurrency AS PresentationCurrency,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.InventoryAccountType AS InventoryAccountType,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.Ownership AS Ownership,
	|		InventoryBalances.CostObject AS CostObject,
	|		InventoryBalances.QuantityBalance AS QuantityBalance,
	|		InventoryBalances.AmountBalance AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject) IN
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.PresentationCurrency,
	|						TableInventory.StructuralUnit,
	|						TableInventory.InventoryAccountType,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.Ownership,
	|						TableInventory.CostObject
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.PresentationCurrency,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.InventoryAccountType,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		DocumentRegisterRecordsInventory.Ownership,
	|		DocumentRegisterRecordsInventory.CostObject,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.PresentationCurrency,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.InventoryAccountType,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.Ownership,
	|	InventoryBalances.CostObject";
	
	Query.SetParameter("Ref", DocumentRefCosting);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add(
		"Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject");
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("PresentationCurrency", RowTableInventory.PresentationCurrency);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("InventoryAccountType", RowTableInventory.InventoryAccountType);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		StructureForSearch.Insert("Ownership", RowTableInventory.Ownership);
		StructureForSearch.Insert("CostObject", RowTableInventory.CostObject);
		
		QuantityRequiredAvailableBalance = RowTableInventory.Quantity;
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredAvailableBalance / QuantityBalance , 2, 1);

				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredAvailableBalance;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;

			ElsIf QuantityBalance = QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;

			Else
				AmountToBeWrittenOff = 0;	
			EndIf;
			
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
			TableRowExpense.SalesOrder = Undefined;
			TableRowExpense.ProductionExpenses = True;
			
			// Receipt
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
					
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.InventoryAccountType = RowTableInventory.CorrInventoryAccountType;
				TableRowReceipt.Products = RowTableInventory.ProductsCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
				TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
					
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.CorrInventoryAccountType = RowTableInventory.InventoryAccountType;
				TableRowReceipt.ProductsCorr = RowTableInventory.Products;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
				TableRowReceipt.CustomerCorrOrder = Undefined;
				TableRowReceipt.RecordKindAccountingJournalEntries = AccountingRecordType.Debit;
					
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
				
				// Generate postings.
				If UseDefaultTypeOfAccounting And Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
					FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryInventory");
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryDemand(DocumentRefCosting, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	TableInventoryDemand.Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableInventoryDemand.SalesOrder AS SalesOrder,
	|	TableInventoryDemand.Products AS Products,
	|	TableInventoryDemand.Characteristic AS Characteristic
	|FROM
	|	TemporaryTableInventory AS TableInventoryDemand";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.InventoryDemand");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
     	
	// Receive balance.
	Query.Text = 	
	"SELECT
	|	InventoryDemandBalances.Company AS Company,
	|	InventoryDemandBalances.SalesOrder AS SalesOrder,
	|	InventoryDemandBalances.Products AS Products,
	|	InventoryDemandBalances.Characteristic AS Characteristic,
	|	SUM(InventoryDemandBalances.Quantity) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryDemandBalances.Company AS Company,
	|		InventoryDemandBalances.SalesOrder AS SalesOrder,
	|		InventoryDemandBalances.Products AS Products,
	|		InventoryDemandBalances.Characteristic AS Characteristic,
	|		SUM(InventoryDemandBalances.QuantityBalance) AS Quantity
	|	FROM
	|		AccumulationRegister.InventoryDemand.Balance(
	|				&ControlTime,
	|				(Company, MovementType, SalesOrder, Products, Characteristic) In
	|					(SELECT
	|						TemporaryTableInventory.Company AS Company,
	|						VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|						TemporaryTableInventory.SalesOrder AS SalesOrder,
	|						TemporaryTableInventory.Products AS Products,
	|						TemporaryTableInventory.Characteristic AS Characteristic
	|					FROM
	|						TemporaryTableInventory AS TemporaryTableInventory)) AS InventoryDemandBalances
	|	
	|	GROUP BY
	|		InventoryDemandBalances.Company,
	|		InventoryDemandBalances.SalesOrder,
	|		InventoryDemandBalances.Products,
	|		InventoryDemandBalances.Characteristic
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventoryDemand.Company,
	|		DocumentRegisterRecordsInventoryDemand.SalesOrder,
	|		DocumentRegisterRecordsInventoryDemand.Products,
	|		DocumentRegisterRecordsInventoryDemand.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryDemand.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.InventoryDemand AS DocumentRegisterRecordsInventoryDemand
	|	WHERE
	|		DocumentRegisterRecordsInventoryDemand.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventoryDemand.Period <= &ControlPeriod) AS InventoryDemandBalances
	|
	|GROUP BY
	|	InventoryDemandBalances.Company,
	|	InventoryDemandBalances.SalesOrder,
	|	InventoryDemandBalances.Products,
	|	InventoryDemandBalances.Characteristic";
	
	Query.SetParameter("Ref", DocumentRefCosting);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);

	QueryResult = Query.Execute();
	
	TableInventoryDemandBalance = QueryResult.Unload();
	TableInventoryDemandBalance.Indexes.Add("Company,SalesOrder,Products,Characteristic");

	TemporaryTableInventoryDemand = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand.CopyColumns();
	
	For Each RowTablesForInventory In StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", 		RowTablesForInventory.Company);
		StructureForSearch.Insert("SalesOrder", 	RowTablesForInventory.SalesOrder);
		StructureForSearch.Insert("Products", 	RowTablesForInventory.Products);
		StructureForSearch.Insert("Characteristic", 	RowTablesForInventory.Characteristic);
		
		BalanceRowsArray = TableInventoryDemandBalance.FindRows(StructureForSearch);
		If BalanceRowsArray.Count() > 0 Then
			
			If RowTablesForInventory.Quantity > BalanceRowsArray[0].QuantityBalance Then
				RowTablesForInventory.Quantity = BalanceRowsArray[0].QuantityBalance;
			EndIf;	
			
			TableRowExpense = TemporaryTableInventoryDemand.Add();
			FillPropertyValues(TableRowExpense, RowTablesForInventory);
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand = TemporaryTableInventoryDemand;
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationByInventory(DocumentRefCosting, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	Inventory.LineNumber AS LineNumber,
	|	Inventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	Inventory.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN Inventory.Ref.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Inventory.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END  AS GLAccount,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS InventoryAccountType,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN InventoryDistribution.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END  AS CorrGLAccount,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS CorrInventoryAccountType,
	|	Inventory.Products AS Products,
	|	InventoryDistribution.Products AS ProductsCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN Inventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryDistribution.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|			THEN Inventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	&OwnInventory AS Ownership,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryDistribution.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS BatchCorr,
	|	Inventory.Specification AS Specification,
	|	InventoryDistribution.Specification AS SpecificationCorr,
	|	Inventory.SalesOrder AS SalesOrder,
	|	InventoryDistribution.SalesOrder AS CustomerCorrOrder,
	|	CASE
	|		WHEN VALUETYPE(Inventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN InventoryDistribution.Quantity
	|		ELSE InventoryDistribution.Quantity * Inventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN InventoryDistribution.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END  AS AccountDr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Inventory.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END  AS AccountCr,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	CAST(&InventoryDistribution AS STRING(100)) AS ContentOfAccountingRecord,
	|	CAST(&InventoryDistribution AS STRING(100)) AS Content
	|INTO TemporaryTableInventory
	|FROM
	|	Document.CostAllocation.Inventory AS Inventory
	|		LEFT JOIN Document.CostAllocation.InventoryDistribution AS InventoryDistribution
	|		ON Inventory.Ref = InventoryDistribution.Ref
	|			AND Inventory.ConnectionKey = InventoryDistribution.ConnectionKey
	|WHERE
	|	Inventory.Ref = &Ref
	|	AND InventoryDistribution.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnit AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableInventory.Products AS Products,
	|	TableInventory.ProductsCorr AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.SpecificationCorr AS SpecificationCorr,
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END AS SalesOrder,
	|	CASE
	|		WHEN TableInventory.CustomerCorrOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.CustomerCorrOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.CustomerCorrOrder
	|	END AS CustomerCorrOrder,
	|	TableInventory.AccountDr AS AccountDr,
	|	TableInventory.AccountCr AS AccountCr,
	|	TableInventory.CostObject AS CostObject,
	|	TableInventory.ContentOfAccountingRecord AS Content,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	0 AS Amount
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.CorrInventoryAccountType,
	|	TableInventory.Products,
	|	TableInventory.ProductsCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.BatchCorr,
	|	TableInventory.Specification,
	|	TableInventory.SpecificationCorr,
	|	TableInventory.SalesOrder,
	|	TableInventory.CustomerCorrOrder,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.AccountDr,
	|	TableInventory.AccountCr,
	|	TableInventory.CostObject,
	|	TableInventory.StructuralUnit,
	|	TableInventory.ContentOfAccountingRecord
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.StructuralUnit,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.Period AS Period,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END AS Order,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.Batch.DeleteStatus = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.Period,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.SalesOrder,
	|	TableInventory.Products,
	|	TableInventory.Characteristic
	|
	|ORDER BY
	|	LineNumber";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",				DocumentRefCosting);
	Query.SetParameter("ControlTime",			StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",		StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseCharacteristics",		StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins",			StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("InventoryDistribution",		NStr("en = 'Direct costs allocation'; ru = 'Распределение запасов';pl = 'Bezpośredni podział kosztów własnych';es_ES = 'Asignación de los costes directos';es_CO = 'Asignación de los costes directos';tr = 'Doğrudan maliyetler tahsisi';it = 'Allocazione costi diretti';de = 'Zuordnung der direkten Kosten'", MainLanguageCode));
	Query.SetParameter("OwnInventory",			Catalogs.InventoryOwnership.OwnInventory());
	Query.SetParameter("UseDefaultTypeOfAccounting",	StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	ResultsArray = Query.ExecuteBatch();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInventory", ResultsArray[1].Unload());
	
	// Generate table for inventory accounting.
	GenerateTableInventoryInventory(DocumentRefCosting, StructureAdditionalProperties);
	
	// Generate table for warehouses.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[2].Unload());
	
	// Determine a table of consumed raw material accepted for processing for which you will have to report in the future.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockReceivedFromThirdParties", ResultsArray[3].Unload());
	
	// Determine table for movement by the needs of dependent demand positions.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", ResultsArray[4].Unload());
	GenerateTableInventoryDemand(DocumentRefCosting, StructureAdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRefCosting, StructureAdditionalProperties);
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefCosting, StructureAdditionalProperties) Export

	Query = New Query;
	Query.Text = 
	"SELECT
	|	Costs.LineNumber AS LineNumber,
	|	Costs.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	Costs.Ref.StructuralUnit AS StructuralUnit,
	|	Costs.Ref.StructuralUnit AS StructuralUnitCorr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Costs.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS InventoryAccountType,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAllocation.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS CorrInventoryAccountType,
	|	CostAllocation.Products AS ProductsCorr,
	|	UNDEFINED AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN CostAllocation.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS CharacteristicCorr,
	|	UNDEFINED AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN CostAllocation.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS BatchCorr,
	|	UNDEFINED AS Batch,
	|	&OwnInventory AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	CostAllocation.Specification AS SpecificationCorr,
	|	UNDEFINED AS Specification,
	|	CASE
	|		WHEN Costs.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR Costs.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE Costs.SalesOrder
	|	END AS SalesOrder,
	|	CASE
	|		WHEN CostAllocation.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR CostAllocation.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE CostAllocation.SalesOrder
	|	END AS CustomerCorrOrder,
	|	CostAllocation.Amount AS Amount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindAccountingJournalEntries,
	|	FALSE AS ProductionExpenses,
	|	TRUE AS FixedCost,
	|	0 AS Quantity,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAllocation.Products.ExpensesGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountDr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Costs.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountCr,
	|	CAST(&DistributionExpenses AS STRING(100)) AS Content,
	|	CAST(&DistributionExpenses AS STRING(100)) AS ContentOfAccountingRecord
	|FROM
	|	Document.CostAllocation.Costs AS Costs
	|		LEFT JOIN Document.CostAllocation.CostAllocation AS CostAllocation
	|		ON Costs.Ref = CostAllocation.Ref
	|			AND Costs.ConnectionKey = CostAllocation.ConnectionKey
	|WHERE
	|	Costs.Ref = &Ref
	|	AND CostAllocation.Ref = &Ref";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");

	Query.SetParameter("Ref",				DocumentRefCosting);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",		StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseCharacteristics",		StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("DistributionExpenses",		NStr("en = 'Overhead costs allocation'; ru = 'Распределение затрат';pl = 'Podział kosztów ogólnych';es_ES = 'Asignación de los costes generales';es_CO = 'Asignación de los costes generales';tr = 'Gider maliyetlerin tahsisi';it = 'Allocazioni costi indiretti';de = 'Gemeinkosten Zuteilung'", MainLanguageCode));
	Query.SetParameter("OwnInventory",			Catalogs.InventoryOwnership.OwnInventory());
	Query.SetParameter("UseDefaultTypeOfAccounting",	UseDefaultTypeOfAccounting);
	
	// Generate transactions table structure.
	DriveServer.GenerateTransactionsTable(DocumentRefCosting, StructureAdditionalProperties);
	
	TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
	TableInventory = Query.Execute().Unload();
	
	For n = 0 To TableInventory.Count() - 1 Do
		
		// Expense.
		RowTableSuppliesExpense = TableInventory[n];
		RowTableSuppliesExpense.ProductionExpenses = True;
		
		// Receipt.
		RowTableInventoryIncrease = TableInventory.Add();
		FillPropertyValues(RowTableInventoryIncrease, RowTableSuppliesExpense);

		RowTableInventoryIncrease.RecordType = AccumulationRecordType.Receipt;

		RowTableInventoryIncrease.Company = RowTableSuppliesExpense.Company; 
		
		RowTableInventoryIncrease.StructuralUnit = RowTableSuppliesExpense.StructuralUnitCorr;
		RowTableInventoryIncrease.GLAccount = RowTableSuppliesExpense.CorrGLAccount;
		RowTableInventoryIncrease.InventoryAccountType = RowTableSuppliesExpense.CorrInventoryAccountType;
		RowTableInventoryIncrease.Products = RowTableSuppliesExpense.ProductsCorr; 
		RowTableInventoryIncrease.Characteristic = RowTableSuppliesExpense.CharacteristicCorr;
		RowTableInventoryIncrease.Batch = RowTableSuppliesExpense.BatchCorr;
		RowTableInventoryIncrease.Specification = RowTableSuppliesExpense.SpecificationCorr;
		RowTableInventoryIncrease.SalesOrder = RowTableSuppliesExpense.CustomerCorrOrder;

		RowTableInventoryIncrease.StructuralUnitCorr = RowTableSuppliesExpense.StructuralUnit;
		RowTableInventoryIncrease.CorrGLAccount = RowTableSuppliesExpense.GLAccount;
		RowTableInventoryIncrease.CorrInventoryAccountType = RowTableSuppliesExpense.InventoryAccountType;
		RowTableInventoryIncrease.SpecificationCorr = RowTableSuppliesExpense.Specification;
		RowTableInventoryIncrease.CustomerCorrOrder = RowTableSuppliesExpense.SalesOrder;

		RowTableInventoryIncrease.RecordKindAccountingJournalEntries = AccountingRecordType.Debit;
		RowTableInventoryIncrease.ProductionExpenses = False;
		
		// Generate postings.
		If UseDefaultTypeOfAccounting And RowTableSuppliesExpense.Amount > 0 Then
			RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
			FillPropertyValues(RowTableAccountingJournalEntries, RowTableSuppliesExpense);
		EndIf;
		
	EndDo;
	
	TableAccountingJournalEntries = DriveServer.AddOfflineAccountingJournalEntriesRecords(TableAccountingJournalEntries, DocumentRefCosting);
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", TableInventory);
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", TableAccountingJournalEntries);
	
	DataInitializationByInventory(DocumentRefCosting, StructureAdditionalProperties);
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefCosting, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefCosting, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefCosting, StructureAdditionalProperties);
		
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRefCosting, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefCosting, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If "RegisterRecordsInventoryChange" temporary tables contain records, it is required to control costs writeoff.	
	If StructureTemporaryTables.RegisterRecordsInventoryChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.PresentationCurrency) AS PresentationCurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.InventoryAccountType) AS InventoryAccountTypePresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Ownership) AS OwnershipPresentation,
		|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
		|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
		|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|		LEFT JOIN AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject) IN
		|					(SELECT
		|						RegisterRecordsInventoryChange.Company AS Company,
		|						RegisterRecordsInventoryChange.PresentationCurrency AS PresentationCurrency,
		|						RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryChange.InventoryAccountType AS InventoryAccountType,
		|						RegisterRecordsInventoryChange.Products AS Products,
		|						RegisterRecordsInventoryChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryChange.Batch AS Batch,
		|						RegisterRecordsInventoryChange.Ownership AS Ownership,
		|						RegisterRecordsInventoryChange.CostObject AS CostObject
		|					FROM
		|						RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange)) AS InventoryBalances
		|		ON RegisterRecordsInventoryChange.Company = InventoryBalances.Company
		|			AND RegisterRecordsInventoryChange.PresentationCurrency = InventoryBalances.PresentationCurrency
		|			AND RegisterRecordsInventoryChange.StructuralUnit = InventoryBalances.StructuralUnit
		|			AND RegisterRecordsInventoryChange.InventoryAccountType = InventoryBalances.InventoryAccountType
		|			AND RegisterRecordsInventoryChange.Products = InventoryBalances.Products
		|			AND RegisterRecordsInventoryChange.Characteristic = InventoryBalances.Characteristic
		|			AND RegisterRecordsInventoryChange.Batch = InventoryBalances.Batch
		|			AND RegisterRecordsInventoryChange.Ownership = InventoryBalances.Ownership
		|			AND RegisterRecordsInventoryChange.CostObject = InventoryBalances.CostObject
		|WHERE
		|	ISNULL(InventoryBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		Result = Query.Execute();
		
		// Negative balance of inventory.
		If NOT Result.IsEmpty() Then
			DocumentObjectCosting = DocumentRefCosting.GetObject();
			QueryResultSelection = Result.Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectCosting, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Costs" Then
		IncomeAndExpenseStructure.Insert("ExpenseItem", StructureData.ExpenseItem);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "Costs" Then
		Result.Insert("GLExpenseAccount", "ExpenseItem");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export
	
	GLAccountsForFilling = New Structure;
	If StructureData.TabName <> "Costs" Then
		GLAccountsForFilling.Insert("ConsumptionGLAccount", StructureData.ConsumptionGLAccount);
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region AccountingTemplates

Function EntryTypes() Export 
	
	EntryTypes = New Array;
	
	Return EntryTypes;
	
EndFunction

Function AccountingFields() Export 
	
	AccountingFields = New Map;
	Return AccountingFields;
	
EndFunction

#EndRegion

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