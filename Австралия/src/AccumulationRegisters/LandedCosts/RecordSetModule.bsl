#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

// Procedure - event handler BeforeWrite record set.
//
Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR Not AdditionalProperties.Property("ForPosting")
		OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Setting the exclusive lock of current registrar record set.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.LandedCosts.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	Query = New Query("
	|SELECT
	|	LandedCosts.Period AS Period,
	|	LandedCosts.Recorder AS Recorder,
	|	LandedCosts.RecordType AS RecordType,
	|	LandedCosts.Company AS Company,
	|	LandedCosts.PresentationCurrency AS PresentationCurrency,
	|	LandedCosts.Products AS Products,
	|	LandedCosts.CostLayer AS CostLayer,
	|	LandedCosts.Characteristic AS Characteristic,
	|	LandedCosts.Batch AS Batch,
	|	LandedCosts.Ownership AS Ownership,
	|	LandedCosts.StructuralUnit AS StructuralUnit,
	|	LandedCosts.GLAccount AS GLAccount,
	|	LandedCosts.InventoryAccountType AS InventoryAccountType,
	|	LandedCosts.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	LandedCosts.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	LandedCosts.Amount AS Amount
	|INTO LandedCostsBeforeWrite
	|FROM
	|	AccumulationRegister.LandedCosts AS LandedCosts
	|WHERE
	|	LandedCosts.Recorder = &Recorder
	|	AND &FIFOIsUsed");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.SetParameter("Replacing", Replacing);
	Query.SetParameter("FIFOIsUsed", Constants.UseFIFO.Get());
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

// Procedure - event handler OnWrite record set.
//
Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR Not AdditionalProperties.Property("ForPosting")
		OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// New set change is calculated relatively current with accounting
	// accumulated changes and placed into temporary table "RegisterRecordsInventoryChange".
	
	Query = New Query(
	"SELECT DISTINCT
	|	BEGINOFPERIOD(Table.Period, MONTH) AS Month,
	|	Table.Company AS Company,
	|	Table.Recorder AS Document
	|INTO LandedCostsTasks
	|FROM
	|	(SELECT
	|		BeforeWrite.Period AS Period,
	|		BeforeWrite.Recorder AS Recorder,
	|		BeforeWrite.RecordType AS RecordType,
	|		BeforeWrite.Company AS Company,
	|		BeforeWrite.PresentationCurrency AS PresentationCurrency,
	|		BeforeWrite.Products AS Products,
	|		BeforeWrite.CostLayer AS CostLayer,
	|		BeforeWrite.Characteristic AS Characteristic,
	|		BeforeWrite.Batch AS Batch,
	|		BeforeWrite.Ownership AS Ownership,
	|		BeforeWrite.StructuralUnit AS StructuralUnit,
	|		BeforeWrite.GLAccount AS GLAccount,
	|		BeforeWrite.InventoryAccountType AS InventoryAccountType,
	|		BeforeWrite.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|		BeforeWrite.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|		BeforeWrite.Amount AS Amount
	|	FROM
	|		LandedCostsBeforeWrite AS BeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AfterWrite.Period,
	|		AfterWrite.Recorder,
	|		AfterWrite.RecordType,
	|		AfterWrite.Company,
	|		AfterWrite.PresentationCurrency,
	|		AfterWrite.Products,
	|		AfterWrite.CostLayer,
	|		AfterWrite.Characteristic,
	|		AfterWrite.Batch,
	|		AfterWrite.Ownership,
	|		AfterWrite.StructuralUnit,
	|		AfterWrite.GLAccount,
	|		AfterWrite.InventoryAccountType,
	|		AfterWrite.IncomeAndExpenseItem,
	|		AfterWrite.CorrIncomeAndExpenseItem,
	|		- AfterWrite.Amount
	|	FROM
	|		AccumulationRegister.LandedCosts AS AfterWrite
	|	WHERE
	|		AfterWrite.Recorder = &Recorder
	|		AND &FIFOIsUsed) AS Table
	|
	|GROUP BY
	|	BEGINOFPERIOD(Table.Period, MONTH),
	|	Table.Period,
	|	Table.Recorder,
	|	Table.RecordType,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.CostLayer,
	|	Table.Characteristic,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.GLAccount,
	|	Table.InventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|
	|HAVING
	|	SUM(Table.Amount) <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP LandedCostsBeforeWrite
	|");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.SetParameter("FIFOIsUsed", Constants.UseFIFO.Get());
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.ExecuteBatch();
	
EndProcedure

#EndRegion

#EndIf