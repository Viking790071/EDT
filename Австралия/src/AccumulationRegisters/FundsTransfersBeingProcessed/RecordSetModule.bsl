#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load
		Or Not AdditionalProperties.Property("ForPosting")
		Or Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Setting the exclusive lock of current registrar record set.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.FundsTransfersBeingProcessed.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsFundsTransfersBeingProcessedChange")
		Or StructureTemporaryTables.Property("RegisterRecordsFundsTransfersBeingProcessedChange")
			And Not StructureTemporaryTables.RegisterRecordsFundsTransfersBeingProcessedChange Then
		
		// If the temporary table "RegisterRecordsFundsTransfersBeingProcessedChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsFundsTransfersBeingProcessedBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	FundsTransfersBeingProcessed.LineNumber AS LineNumber,
		|	FundsTransfersBeingProcessed.Company AS Company,
		|	FundsTransfersBeingProcessed.PresentationCurrency AS PresentationCurrency,
		|	FundsTransfersBeingProcessed.PaymentProcessor AS PaymentProcessor,
		|	FundsTransfersBeingProcessed.PaymentProcessorContract AS PaymentProcessorContract,
		|	FundsTransfersBeingProcessed.POSTerminal AS POSTerminal,
		|	FundsTransfersBeingProcessed.Currency AS Currency,
		|	FundsTransfersBeingProcessed.Document AS Document,
		|	CASE
		|		WHEN FundsTransfersBeingProcessed.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN FundsTransfersBeingProcessed.AmountCur
		|		ELSE -FundsTransfersBeingProcessed.AmountCur
		|	END AS AmountCurBeforeWrite,
		|	CASE
		|		WHEN FundsTransfersBeingProcessed.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN FundsTransfersBeingProcessed.FeeAmount
		|		ELSE -FundsTransfersBeingProcessed.FeeAmount
		|	END AS FeeAmountBeforeWrite
		|INTO RegisterRecordsFundsTransfersBeingProcessedBeforeWrite
		|FROM
		|	AccumulationRegister.FundsTransfersBeingProcessed AS FundsTransfersBeingProcessed
		|WHERE
		|	FundsTransfersBeingProcessed.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsFundsTransfersBeingProcessedChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsFundsTransfersBeingProcessedBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsFundsTransfersBeingProcessedChange.LineNumber AS LineNumber,
		|	RegisterRecordsFundsTransfersBeingProcessedChange.Company AS Company,
		|	RegisterRecordsFundsTransfersBeingProcessedChange.PresentationCurrency AS PresentationCurrency,
		|	RegisterRecordsFundsTransfersBeingProcessedChange.PaymentProcessor AS PaymentProcessor,
		|	RegisterRecordsFundsTransfersBeingProcessedChange.PaymentProcessorContract AS PaymentProcessorContract,
		|	RegisterRecordsFundsTransfersBeingProcessedChange.POSTerminal AS POSTerminal,
		|	RegisterRecordsFundsTransfersBeingProcessedChange.Currency AS Currency,
		|	RegisterRecordsFundsTransfersBeingProcessedChange.Document AS Document,
		|	RegisterRecordsFundsTransfersBeingProcessedChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsFundsTransfersBeingProcessedChange.FeeAmountBeforeWrite AS FeeAmountBeforeWrite
		|INTO RegisterRecordsFundsTransfersBeingProcessedBeforeWrite
		|FROM
		|	RegisterRecordsFundsTransfersBeingProcessedChange AS RegisterRecordsFundsTransfersBeingProcessedChange
		|
		|UNION ALL
		|
		|SELECT
		|	FundsTransfersBeingProcessed.LineNumber,
		|	FundsTransfersBeingProcessed.Company,
		|	FundsTransfersBeingProcessed.PresentationCurrency,
		|	FundsTransfersBeingProcessed.PaymentProcessor,
		|	FundsTransfersBeingProcessed.PaymentProcessorContract,
		|	FundsTransfersBeingProcessed.POSTerminal,
		|	FundsTransfersBeingProcessed.Currency,
		|	FundsTransfersBeingProcessed.Document,
		|	CASE
		|		WHEN FundsTransfersBeingProcessed.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN FundsTransfersBeingProcessed.AmountCur
		|		ELSE -FundsTransfersBeingProcessed.AmountCur
		|	END,
		|	CASE
		|		WHEN FundsTransfersBeingProcessed.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN FundsTransfersBeingProcessed.FeeAmount
		|		ELSE -FundsTransfersBeingProcessed.FeeAmount
		|	END
		|FROM
		|	AccumulationRegister.FundsTransfersBeingProcessed AS FundsTransfersBeingProcessed
		|WHERE
		|	FundsTransfersBeingProcessed.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsFundsTransfersBeingProcessedChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsFundsTransfersBeingProcessedChange") Then
		
		Query = New Query("DROP RegisterRecordsFundsTransfersBeingProcessedChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsFundsTransfersBeingProcessedChange");
	
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load
		Or Not AdditionalProperties.Property("ForPosting")
		Or Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// New set change is calculated relatively current with accounting
	// accumulated changes and placed into temporary table "RegisterRecordsFundsTransfersBeingProcessedChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsFundsTransfersBeingProcessedChange.LineNumber) AS LineNumber,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.Company AS Company,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.PresentationCurrency AS PresentationCurrency,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.PaymentProcessor AS PaymentProcessor,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.PaymentProcessorContract AS PaymentProcessorContract,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.POSTerminal AS POSTerminal,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.Currency AS Currency,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.Document AS Document,
	|	SUM(RegisterRecordsFundsTransfersBeingProcessedChange.AmountCurBeforeWrite) AS AmountCurBeforeWrite,
	|	SUM(RegisterRecordsFundsTransfersBeingProcessedChange.AmountCurChange) AS AmountCurChange,
	|	SUM(RegisterRecordsFundsTransfersBeingProcessedChange.AmountCurOnWrite) AS AmountCurOnWrite,
	|	SUM(RegisterRecordsFundsTransfersBeingProcessedChange.FeeAmountBeforeWrite) AS FeeAmountBeforeWrite,
	|	SUM(RegisterRecordsFundsTransfersBeingProcessedChange.FeeAmountChange) AS FeeAmountChange,
	|	SUM(RegisterRecordsFundsTransfersBeingProcessedChange.FeeAmountOnWrite) AS FeeAmountOnWrite
	|INTO RegisterRecordsFundsTransfersBeingProcessedChange
	|FROM
	|	(SELECT
	|		RegisterRecordsFundsTransfersBeingProcessedBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsFundsTransfersBeingProcessedBeforeWrite.Company AS Company,
	|		RegisterRecordsFundsTransfersBeingProcessedBeforeWrite.PresentationCurrency AS PresentationCurrency,
	|		RegisterRecordsFundsTransfersBeingProcessedBeforeWrite.PaymentProcessor AS PaymentProcessor,
	|		RegisterRecordsFundsTransfersBeingProcessedBeforeWrite.PaymentProcessorContract AS PaymentProcessorContract,
	|		RegisterRecordsFundsTransfersBeingProcessedBeforeWrite.POSTerminal AS POSTerminal,
	|		RegisterRecordsFundsTransfersBeingProcessedBeforeWrite.Currency AS Currency,
	|		RegisterRecordsFundsTransfersBeingProcessedBeforeWrite.Document AS Document,
	|		RegisterRecordsFundsTransfersBeingProcessedBeforeWrite.AmountCurBeforeWrite AS AmountCurBeforeWrite,
	|		RegisterRecordsFundsTransfersBeingProcessedBeforeWrite.AmountCurBeforeWrite AS AmountCurChange,
	|		0 AS AmountCurOnWrite,
	|		RegisterRecordsFundsTransfersBeingProcessedBeforeWrite.FeeAmountBeforeWrite AS FeeAmountBeforeWrite,
	|		RegisterRecordsFundsTransfersBeingProcessedBeforeWrite.FeeAmountBeforeWrite AS FeeAmountChange,
	|		0 AS FeeAmountOnWrite
	|	FROM
	|		RegisterRecordsFundsTransfersBeingProcessedBeforeWrite AS RegisterRecordsFundsTransfersBeingProcessedBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsFundsTransfersBeingProcessedOnWrite.LineNumber,
	|		RegisterRecordsFundsTransfersBeingProcessedOnWrite.Company,
	|		RegisterRecordsFundsTransfersBeingProcessedOnWrite.PresentationCurrency,
	|		RegisterRecordsFundsTransfersBeingProcessedOnWrite.PaymentProcessor,
	|		RegisterRecordsFundsTransfersBeingProcessedOnWrite.PaymentProcessorContract,
	|		RegisterRecordsFundsTransfersBeingProcessedOnWrite.POSTerminal,
	|		RegisterRecordsFundsTransfersBeingProcessedOnWrite.Currency,
	|		RegisterRecordsFundsTransfersBeingProcessedOnWrite.Document,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsFundsTransfersBeingProcessedOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsFundsTransfersBeingProcessedOnWrite.AmountCur
	|			ELSE RegisterRecordsFundsTransfersBeingProcessedOnWrite.AmountCur
	|		END,
	|		RegisterRecordsFundsTransfersBeingProcessedOnWrite.AmountCur,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsFundsTransfersBeingProcessedOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsFundsTransfersBeingProcessedOnWrite.FeeAmount
	|			ELSE RegisterRecordsFundsTransfersBeingProcessedOnWrite.FeeAmount
	|		END,
	|		RegisterRecordsFundsTransfersBeingProcessedOnWrite.FeeAmount
	|	FROM
	|		AccumulationRegister.FundsTransfersBeingProcessed AS RegisterRecordsFundsTransfersBeingProcessedOnWrite
	|	WHERE
	|		RegisterRecordsFundsTransfersBeingProcessedOnWrite.Recorder = &Recorder) AS RegisterRecordsFundsTransfersBeingProcessedChange
	|
	|GROUP BY
	|	RegisterRecordsFundsTransfersBeingProcessedChange.Company,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.PresentationCurrency,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.PaymentProcessor,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.PaymentProcessorContract,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.POSTerminal,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.Currency,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.Document
	|
	|HAVING
	|	(SUM(RegisterRecordsFundsTransfersBeingProcessedChange.AmountCurChange) <> 0
	|		OR SUM(RegisterRecordsFundsTransfersBeingProcessedChange.FeeAmountChange) <> 0)
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	PaymentProcessor,
	|	PaymentProcessorContract,
	|	POSTerminal,
	|	Currency,
	|	Document");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsFundsTransfersBeingProcessedChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsFundsTransfersBeingProcessedChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsFundsTransfersBeingProcessedBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsFundsTransfersBeingProcessedBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf