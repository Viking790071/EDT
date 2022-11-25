#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure CreateEmptyTemporaryTableChange(AdditionalProperties) Export
	
	If Not AdditionalProperties.Property("ForPosting")
		Or Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query(
	"SELECT TOP 0
	|	FundsTransfersBeingProcessed.LineNumber AS LineNumber,
	|	FundsTransfersBeingProcessed.Company AS Company,
	|	FundsTransfersBeingProcessed.PresentationCurrency AS PresentationCurrency,
	|	FundsTransfersBeingProcessed.PaymentProcessor AS PaymentProcessor,
	|	FundsTransfersBeingProcessed.PaymentProcessorContract AS PaymentProcessorContract,
	|	FundsTransfersBeingProcessed.POSTerminal AS POSTerminal,
	|	FundsTransfersBeingProcessed.Currency AS Currency,
	|	FundsTransfersBeingProcessed.Document AS Document,
	|	FundsTransfersBeingProcessed.AmountCur AS AmountCurBeforeWrite,
	|	FundsTransfersBeingProcessed.AmountCur AS AmountCurChange,
	|	FundsTransfersBeingProcessed.AmountCur AS AmountCurOnWrite,
	|	FundsTransfersBeingProcessed.FeeAmount AS FeeAmountBeforeWrite,
	|	FundsTransfersBeingProcessed.FeeAmount AS FeeAmountChange,
	|	FundsTransfersBeingProcessed.FeeAmount AS FeeAmountOnWrite
	|INTO RegisterRecordsFundsTransfersBeingProcessedChange
	|FROM
	|	AccumulationRegister.FundsTransfersBeingProcessed AS FundsTransfersBeingProcessed");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsFundsTransfersBeingProcessedChange", False);
	
EndProcedure

Function BalancesControlQueryText() Export
	
	Return
	"SELECT
	|	RegisterRecordsFundsTransfersBeingProcessedChange.LineNumber AS LineNumber,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.Company AS Company,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.PresentationCurrency AS PresentationCurrency,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.PaymentProcessor AS PaymentProcessor,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.PaymentProcessorContract AS PaymentProcessorContract,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.POSTerminal AS POSTerminal,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.Currency AS Currency,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.Document AS Document,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.AmountCurChange + ISNULL(FundsTransfersBeingProcessedBalances.AmountCurBalance, 0) AS AmountCurBalanceBeforeChange,
	|	ISNULL(FundsTransfersBeingProcessedBalances.AmountCurBalance, 0) AS AmountCurBalance,
	|	RegisterRecordsFundsTransfersBeingProcessedChange.FeeAmountChange + ISNULL(FundsTransfersBeingProcessedBalances.FeeAmountBalance, 0) AS FeeAmountBalanceBeforeChange,
	|	ISNULL(FundsTransfersBeingProcessedBalances.FeeAmountBalance, 0) AS FeeAmountBalance
	|FROM
	|	RegisterRecordsFundsTransfersBeingProcessedChange AS RegisterRecordsFundsTransfersBeingProcessedChange
	|		LEFT JOIN AccumulationRegister.FundsTransfersBeingProcessed.Balance(&ControlTime, ) AS FundsTransfersBeingProcessedBalances
	|		ON RegisterRecordsFundsTransfersBeingProcessedChange.Company = FundsTransfersBeingProcessedBalances.Company
	|			AND RegisterRecordsFundsTransfersBeingProcessedChange.PresentationCurrency = FundsTransfersBeingProcessedBalances.PresentationCurrency
	|			AND RegisterRecordsFundsTransfersBeingProcessedChange.PaymentProcessor = FundsTransfersBeingProcessedBalances.PaymentProcessor
	|			AND RegisterRecordsFundsTransfersBeingProcessedChange.PaymentProcessorContract = FundsTransfersBeingProcessedBalances.PaymentProcessorContract
	|			AND RegisterRecordsFundsTransfersBeingProcessedChange.POSTerminal = FundsTransfersBeingProcessedBalances.POSTerminal
	|			AND RegisterRecordsFundsTransfersBeingProcessedChange.Currency = FundsTransfersBeingProcessedBalances.Currency
	|			AND RegisterRecordsFundsTransfersBeingProcessedChange.Document = FundsTransfersBeingProcessedBalances.Document
	|WHERE
	|	(CASE
	|				WHEN RegisterRecordsFundsTransfersBeingProcessedChange.Document REFS Document.OnlinePayment
	|					THEN ISNULL(FundsTransfersBeingProcessedBalances.AmountCurBalance, 0) > 0
	|				ELSE ISNULL(FundsTransfersBeingProcessedBalances.AmountCurBalance, 0) < 0
	|			END
	|			OR ISNULL(FundsTransfersBeingProcessedBalances.FeeAmountBalance, 0) < 0)
	|
	|ORDER BY
	|	LineNumber";
	
EndFunction

#EndRegion

#EndIf