#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Procedure creates an empty temporary table of records change.
//
Procedure CreateEmptyTemporaryTableChange(AdditionalProperties) Export
	
	If Not AdditionalProperties.Property("ForPosting")
	 OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query(
	"SELECT TOP 0
	|	AccountsPayable.LineNumber AS LineNumber,
	|	AccountsPayable.Company AS Company,
	|	AccountsPayable.PresentationCurrency AS PresentationCurrency,
	|	AccountsPayable.Counterparty AS Counterparty,
	|	AccountsPayable.Contract AS Contract,
	|	AccountsPayable.Document AS Document,
	|	AccountsPayable.Order AS Order,
	|	AccountsPayable.SettlementsType AS SettlementsType,
	|	AccountsPayable.Amount AS SumBeforeWrite,
	|	AccountsPayable.Amount AS AmountChange,
	|	AccountsPayable.Amount AS AmountOnWrite,
	|	AccountsPayable.AmountCur AS AmountCurBeforeWrite,
	|	AccountsPayable.AmountCur AS SumCurChange,
	|	AccountsPayable.AmountCur AS SumCurOnWrite
	|INTO RegisterRecordsSuppliersSettlementsChange
	|FROM
	|	AccumulationRegister.AccountsPayable AS AccountsPayable");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsSuppliersSettlementsChange", False);
	
EndProcedure

Function AdvanceBalancesControlQueryText() Export
	
	Return
	"SELECT
	|	RegisterRecordsSuppliersSettlementsChange.LineNumber AS LineNumber,
	|	RegisterRecordsSuppliersSettlementsChange.Company AS CompanyPresentation,
	|	RegisterRecordsSuppliersSettlementsChange.PresentationCurrency AS PresentationCurrencyPresentation,
	|	RegisterRecordsSuppliersSettlementsChange.Counterparty AS CounterpartyPresentation,
	|	RegisterRecordsSuppliersSettlementsChange.Contract AS ContractPresentation,
	|	RegisterRecordsSuppliersSettlementsChange.Contract.SettlementsCurrency AS CurrencyPresentation,
	|	RegisterRecordsSuppliersSettlementsChange.Document AS DocumentPresentation,
	|	RegisterRecordsSuppliersSettlementsChange.Order AS OrderPresentation,
	|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS CalculationsTypesPresentation,
	|	RegisterRecordsSuppliersSettlementsChange.SumBeforeWrite AS SumBeforeWrite,
	|	RegisterRecordsSuppliersSettlementsChange.AmountOnWrite AS AmountOnWrite,
	|	RegisterRecordsSuppliersSettlementsChange.AmountChange AS AmountChange,
	|	RegisterRecordsSuppliersSettlementsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
	|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite AS SumCurOnWrite,
	|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite - ISNULL(AccountsPayableeBalances.AmountCurBalance, 0) AS AdvanceAmountsReceived,
	|	ISNULL(AccountsPayableeBalances.AmountBalance, 0) AS AmountBalance,
	|	ISNULL(AccountsPayableeBalances.AmountCurBalance, 0) AS AmountCurBalance
	|FROM
	|	RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange
	|		INNER JOIN AccumulationRegister.AccountsPayable.Balance(&ControlTime, ) AS AccountsPayableeBalances
	|		ON RegisterRecordsSuppliersSettlementsChange.Company = AccountsPayableeBalances.Company
	|			AND RegisterRecordsSuppliersSettlementsChange.PresentationCurrency = AccountsPayableeBalances.PresentationCurrency
	|			AND RegisterRecordsSuppliersSettlementsChange.Counterparty = AccountsPayableeBalances.Counterparty
	|			AND RegisterRecordsSuppliersSettlementsChange.Contract = AccountsPayableeBalances.Contract
	|			AND RegisterRecordsSuppliersSettlementsChange.Document = AccountsPayableeBalances.Document
	|			AND RegisterRecordsSuppliersSettlementsChange.Order = AccountsPayableeBalances.Order
	|			AND RegisterRecordsSuppliersSettlementsChange.SettlementsType = AccountsPayableeBalances.SettlementsType
	|			AND RegisterRecordsSuppliersSettlementsChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|			AND	ISNULL(AccountsPayableeBalances.AmountCurBalance, 0) > 0
	|
	|ORDER BY
	|	LineNumber";
	
EndFunction

#Region InfobaseUpdate

Procedure CheckAndCorrectAmountsForPayment() Export
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	AccountsPayable.Recorder AS Ref
	|FROM
	|	AccumulationRegister.AccountsPayable AS AccountsPayable
	|WHERE
	|	AccountsPayable.Recorder REFS Document.SupplierInvoice
	|
	|GROUP BY
	|	AccountsPayable.Recorder
	|
	|HAVING
	|	(SUM(AccountsPayable.Amount - AccountsPayable.AmountForPayment) <> 0
	|		OR SUM(AccountsPayable.AmountCur - AccountsPayable.AmountForPaymentCur) <> 0)";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DocumentObject = Selection.Ref.GetObject();
		If DocumentObject = Undefined Then
			Continue;
		EndIf;
		
		AdditionalProperties = DocumentObject.AdditionalProperties;
		RegisterRecords = DocumentObject.RegisterRecords;
		
		BeginTransaction();
		
		DriveServer.InitializeAdditionalPropertiesForPosting(Selection.Ref, AdditionalProperties);
		Documents.SupplierInvoice.InitializeDocumentData(Selection.Ref, AdditionalProperties);
		DriveServer.ReflectAccountsPayable(AdditionalProperties, DocumentObject.RegisterRecords, False);
		
		Try
			
			InfobaseUpdate.WriteRecordSet(RegisterRecords.AccountsPayable);
			AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Error while saving record set %1: %2.'; ru = 'Ошибка при записи набора записей %1: %2.';pl = 'Błąd podczas zapisywania zestawu wpisów %1: %2.';es_ES = 'Error al guardar el conjunto de registros %1: %2.';es_CO = 'Error al guardar el conjunto de registros %1: %2.';tr = '%1 kayıt kümesi kaydedilirken hata oluştu: %2.';it = 'Si è verificato un errore durante il salvataggio dell''insieme di registrazioni %1: %2.';de = 'Fehler beim Speichern von Satz von Einträgen %1: %2.'", DefaultLanguageCode),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.AccumulationRegisters.AccountsPayable,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf