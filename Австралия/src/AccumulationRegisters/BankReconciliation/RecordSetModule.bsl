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
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Setting the exclusive lock of current registrar record set.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.BankReconciliation.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsBankReconciliationChange")
		Or Not StructureTemporaryTables.RegisterRecordsBankReconciliationChange Then
		
		// If the temporary table "RegisterRecordsBankReconciliationChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsBankReconciliationBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	BankReconciliation.LineNumber AS LineNumber,
		|	BankReconciliation.BankAccount AS BankAccount,
		|	BankReconciliation.Transaction AS Transaction,
		|	BankReconciliation.TransactionType AS TransactionType,
		|	CASE
		|		WHEN BankReconciliation.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN BankReconciliation.Amount
		|		ELSE -BankReconciliation.Amount
		|	END AS AmountBeforeWrite
		|INTO RegisterRecordsBankReconciliationBeforeWrite
		|FROM
		|	AccumulationRegister.BankReconciliation AS BankReconciliation
		|WHERE
		|	BankReconciliation.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsBankReconciliationChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsBankReconciliationBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsBankReconciliationChange.LineNumber AS LineNumber,
		|	RegisterRecordsBankReconciliationChange.BankAccount AS BankAccount,
		|	RegisterRecordsBankReconciliationChange.Transaction AS Transaction,
		|	RegisterRecordsBankReconciliationChange.TransactionType AS TransactionType,
		|	RegisterRecordsBankReconciliationChange.AmountBeforeWrite AS AmountBeforeWrite
		|INTO RegisterRecordsBankReconciliationBeforeWrite
		|FROM
		|	RegisterRecordsBankReconciliationChange AS RegisterRecordsBankReconciliationChange
		|
		|UNION ALL
		|
		|SELECT
		|	BankReconciliation.LineNumber,
		|	BankReconciliation.BankAccount,
		|	BankReconciliation.Transaction,
		|	BankReconciliation.TransactionType,
		|	CASE
		|		WHEN BankReconciliation.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN BankReconciliation.Amount
		|		ELSE -BankReconciliation.Amount
		|	END
		|FROM
		|	AccumulationRegister.BankReconciliation AS BankReconciliation
		|WHERE
		|	BankReconciliation.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsBankReconciliationChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsBankReconciliationChange") Then
		
		Query = New Query("DROP RegisterRecordsBankReconciliationChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsBankReconciliationChange");
	
	EndIf;
	
EndProcedure

// Procedure - event handler OnWrite record set.
//
Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load
		Or Not AdditionalProperties.Property("ForPosting")
		Or Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// New set change is calculated relatively current with accounting
	// accumulated changes and placed into temporary table "RegisterRecordsBankReconciliationChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsBankReconciliationChange.LineNumber) AS LineNumber,
	|	RegisterRecordsBankReconciliationChange.BankAccount AS BankAccount,
	|	RegisterRecordsBankReconciliationChange.Transaction AS Transaction,
	|	RegisterRecordsBankReconciliationChange.TransactionType AS TransactionType,
	|	SUM(RegisterRecordsBankReconciliationChange.AmountBeforeWrite) AS AmountBeforeWrite,
	|	SUM(RegisterRecordsBankReconciliationChange.AmountChange) AS AmountChange,
	|	SUM(RegisterRecordsBankReconciliationChange.AmountOnWrite) AS AmountOnWrite
	|INTO RegisterRecordsBankReconciliationChange
	|FROM
	|	(SELECT
	|		RegisterRecordsBankReconciliationBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsBankReconciliationBeforeWrite.BankAccount AS BankAccount,
	|		RegisterRecordsBankReconciliationBeforeWrite.Transaction AS Transaction,
	|		RegisterRecordsBankReconciliationBeforeWrite.TransactionType AS TransactionType,
	|		RegisterRecordsBankReconciliationBeforeWrite.AmountBeforeWrite AS AmountBeforeWrite,
	|		RegisterRecordsBankReconciliationBeforeWrite.AmountBeforeWrite AS AmountChange,
	|		0 AS AmountOnWrite
	|	FROM
	|		RegisterRecordsBankReconciliationBeforeWrite AS RegisterRecordsBankReconciliationBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsBankReconciliationOnWrite.LineNumber,
	|		RegisterRecordsBankReconciliationOnWrite.BankAccount,
	|		RegisterRecordsBankReconciliationOnWrite.Transaction,
	|		RegisterRecordsBankReconciliationOnWrite.TransactionType,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsBankReconciliationOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsBankReconciliationOnWrite.Amount
	|			ELSE RegisterRecordsBankReconciliationOnWrite.Amount
	|		END,
	|		RegisterRecordsBankReconciliationOnWrite.Amount
	|	FROM
	|		AccumulationRegister.BankReconciliation AS RegisterRecordsBankReconciliationOnWrite
	|	WHERE
	|		RegisterRecordsBankReconciliationOnWrite.Recorder = &Recorder) AS RegisterRecordsBankReconciliationChange
	|
	|GROUP BY
	|	RegisterRecordsBankReconciliationChange.BankAccount,
	|	RegisterRecordsBankReconciliationChange.Transaction,
	|	RegisterRecordsBankReconciliationChange.TransactionType
	|
	|HAVING
	|	SUM(RegisterRecordsBankReconciliationChange.AmountChange) <> 0
	|
	|INDEX BY
	|	BankAccount,
	|	Transaction,
	|	TransactionType");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsBankReconciliationChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsBankReconciliationChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsBankReconciliationBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsBankReconciliationBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf