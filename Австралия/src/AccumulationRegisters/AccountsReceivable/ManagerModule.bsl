#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

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
	|	AccountsReceivable.LineNumber AS LineNumber,
	|	AccountsReceivable.Company AS Company,
	|	AccountsReceivable.PresentationCurrency AS PresentationCurrency,
	|	AccountsReceivable.Counterparty AS Counterparty,
	|	AccountsReceivable.Contract AS Contract,
	|	AccountsReceivable.Document AS Document,
	|	AccountsReceivable.Order AS Order,
	|	AccountsReceivable.SettlementsType AS SettlementsType,
	|	AccountsReceivable.Amount AS SumBeforeWrite,
	|	AccountsReceivable.Amount AS AmountChange,
	|	AccountsReceivable.Amount AS AmountOnWrite,
	|	AccountsReceivable.AmountCur AS AmountCurBeforeWrite,
	|	AccountsReceivable.AmountCur AS SumCurChange,
	|	AccountsReceivable.AmountCur AS SumCurOnWrite
	|INTO RegisterRecordsAccountsReceivableChange
	|FROM
	|	AccumulationRegister.AccountsReceivable AS AccountsReceivable");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsAccountsReceivableChange", False);
	
EndProcedure

Function AdvanceBalancesControlQueryText() Export
	
	Return
	"SELECT
	|	RegisterRecordsAccountsReceivableChange.LineNumber AS LineNumber,
	|	RegisterRecordsAccountsReceivableChange.Company AS CompanyPresentation,
	|	RegisterRecordsAccountsReceivableChange.PresentationCurrency AS PresentationCurrencyPresentation,
	|	RegisterRecordsAccountsReceivableChange.Counterparty AS CounterpartyPresentation,
	|	RegisterRecordsAccountsReceivableChange.Contract AS ContractPresentation,
	|	RegisterRecordsAccountsReceivableChange.Contract.SettlementsCurrency AS CurrencyPresentation,
	|	RegisterRecordsAccountsReceivableChange.Document AS DocumentPresentation,
	|	RegisterRecordsAccountsReceivableChange.Order AS OrderPresentation,
	|	RegisterRecordsAccountsReceivableChange.SettlementsType AS CalculationsTypesPresentation,
	|	RegisterRecordsAccountsReceivableChange.SumBeforeWrite AS SumBeforeWrite,
	|	RegisterRecordsAccountsReceivableChange.AmountOnWrite AS AmountOnWrite,
	|	RegisterRecordsAccountsReceivableChange.AmountChange AS AmountChange,
	|	RegisterRecordsAccountsReceivableChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
	|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite AS SumCurOnWrite,
	|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite - ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AdvanceAmountsReceived,
	|	ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
	|	ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|FROM
	|	RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange
	|		INNER JOIN AccumulationRegister.AccountsReceivable.Balance(&ControlTime, ) AS AccountsReceivableBalances
	|		ON RegisterRecordsAccountsReceivableChange.Company = AccountsReceivableBalances.Company
	|			AND RegisterRecordsAccountsReceivableChange.PresentationCurrency = AccountsReceivableBalances.PresentationCurrency
	|			AND RegisterRecordsAccountsReceivableChange.Counterparty = AccountsReceivableBalances.Counterparty
	|			AND RegisterRecordsAccountsReceivableChange.Contract = AccountsReceivableBalances.Contract
	|			AND RegisterRecordsAccountsReceivableChange.Document = AccountsReceivableBalances.Document
	|			AND RegisterRecordsAccountsReceivableChange.Order = AccountsReceivableBalances.Order
	|			AND RegisterRecordsAccountsReceivableChange.SettlementsType = AccountsReceivableBalances.SettlementsType
	|			AND RegisterRecordsAccountsReceivableChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|			AND ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) > 0
	|
	|ORDER BY
	|	LineNumber";
	
EndFunction

#EndRegion

#Region InfobaseUpdate

// Replaces an empty sales order reference with an undefined
//
Procedure ChangeSalesOrderEmptyRefToUndefined() Export
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	AccountsReceivable.Recorder AS Ref
	|FROM
	|	AccumulationRegister.AccountsReceivable AS AccountsReceivable
	|WHERE
	|	AccountsReceivable.Order = VALUE(Document.SalesOrder.EmptyRef)";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do
		
		Query.Text = 
		"SELECT
		|	AccountsReceivable.Period AS Period,
		|	AccountsReceivable.Recorder AS Recorder,
		|	AccountsReceivable.LineNumber AS LineNumber,
		|	AccountsReceivable.Active AS Active,
		|	AccountsReceivable.RecordType AS RecordType,
		|	AccountsReceivable.Company AS Company,
		|	AccountsReceivable.SettlementsType AS SettlementsType,
		|	AccountsReceivable.Counterparty AS Counterparty,
		|	AccountsReceivable.Contract AS Contract,
		|	AccountsReceivable.Document AS Document,
		|	CASE
		|		WHEN AccountsReceivable.Order = VALUE(Document.SalesOrder.EmptyRef)
		|			THEN UNDEFINED
		|		ELSE AccountsReceivable.Order
		|	END AS Order,
		|	AccountsReceivable.Amount AS Amount,
		|	AccountsReceivable.AmountCur AS AmountCur,
		|	AccountsReceivable.AmountForPayment AS AmountForPayment,
		|	AccountsReceivable.AmountForPaymentCur AS AmountForPaymentCur,
		|	AccountsReceivable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	AccumulationRegister.AccountsReceivable AS AccountsReceivable
		|WHERE
		|	AccountsReceivable.Recorder = &Ref";
		
		Query.SetParameter("Ref", Selection.Ref);
		
		RegisterRecords = AccumulationRegisters.AccountsReceivable.CreateRecordSet();
		RegisterRecords.Filter.Recorder.Set(Selection.Ref);
		RegisterRecords.Load(Query.Execute().Unload());
		
		Try
			
			RegisterRecords.Write();
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'", DefaultLanguageCode),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.AccumulationRegisters.AccountsReceivable,
				,
				ErrorDescription);
				
		EndTry;
			
	EndDo;
	
EndProcedure

Procedure CheckAndCorrectAmountsForPayment() Export
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	AccountsReceivable.Recorder AS Ref
	|FROM
	|	AccumulationRegister.AccountsReceivable AS AccountsReceivable
	|WHERE
	|	AccountsReceivable.Recorder REFS Document.SalesInvoice
	|
	|GROUP BY
	|	AccountsReceivable.Recorder
	|
	|HAVING
	|	(SUM(AccountsReceivable.Amount - AccountsReceivable.AmountForPayment) <> 0
	|		OR SUM(AccountsReceivable.AmountCur - AccountsReceivable.AmountForPaymentCur) <> 0)";
	
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
		Documents.SalesInvoice.InitializeDocumentData(Selection.Ref, AdditionalProperties);
		DriveServer.ReflectAccountsReceivable(AdditionalProperties, DocumentObject.RegisterRecords, False);
		
		Try
			
			InfobaseUpdate.WriteRecordSet(RegisterRecords.AccountsReceivable);
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
				Metadata.AccumulationRegisters.AccountsReceivable,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf