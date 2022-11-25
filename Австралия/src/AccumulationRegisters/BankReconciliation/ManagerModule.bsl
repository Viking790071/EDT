#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure CreateEmptyTemporaryTableChange(AdditionalProperties) Export
	
	If Not AdditionalProperties.Property("ForPosting")
	 OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query(
	"SELECT TOP 0
	|	BankReconciliation.LineNumber AS LineNumber,
	|	BankReconciliation.BankAccount AS BankAccount,
	|	BankReconciliation.Transaction AS Transaction,
	|	BankReconciliation.TransactionType AS TransactionType,
	|	BankReconciliation.Amount AS AmountBeforeWrite,
	|	BankReconciliation.Amount AS AmountChange,
	|	BankReconciliation.Amount AS AmountOnWrite
	|INTO RegisterRecordsBankReconciliationChange
	|FROM
	|	AccumulationRegister.BankReconciliation AS BankReconciliation");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsBankReconciliationChange", False);
	
EndProcedure

Function BalancesControlQueryText() Export
	
	Return
	"SELECT ALLOWED
	|	RegisterRecordsBankReconciliationChange.LineNumber AS LineNumber,
	|	RegisterRecordsBankReconciliationChange.BankAccount AS BankAccount,
	|	RegisterRecordsBankReconciliationChange.Transaction AS Transaction,
	|	RegisterRecordsBankReconciliationChange.TransactionType AS TransactionType,
	|	ISNULL(CASE
	|			WHEN BankReconciliationTurnovers.AmountReceipt < 0
	|				THEN -BankReconciliationTurnovers.AmountReceipt
	|			ELSE BankReconciliationTurnovers.AmountReceipt
	|		END, 0) AS Amount,
	|	ISNULL(CASE
	|			WHEN BankReconciliationTurnovers.AmountExpense < 0
	|				THEN -BankReconciliationTurnovers.AmountExpense
	|			ELSE BankReconciliationTurnovers.AmountExpense
	|		END, 0) AS AmountCleared
	|FROM
	|	RegisterRecordsBankReconciliationChange AS RegisterRecordsBankReconciliationChange
	|		LEFT JOIN AccumulationRegister.BankReconciliation.Turnovers(, , , ) AS BankReconciliationTurnovers
	|		ON RegisterRecordsBankReconciliationChange.BankAccount = BankReconciliationTurnovers.BankAccount
	|			AND RegisterRecordsBankReconciliationChange.Transaction = BankReconciliationTurnovers.Transaction
	|			AND RegisterRecordsBankReconciliationChange.TransactionType = BankReconciliationTurnovers.TransactionType
	|		LEFT JOIN Catalog.BankAccounts AS CatalogBankAccounts
	|		ON RegisterRecordsBankReconciliationChange.BankAccount = CatalogBankAccounts.Ref
	|WHERE
	|	ISNULL(BankReconciliationTurnovers.AmountTurnover, 0) <> 0
	|	AND ISNULL(BankReconciliationTurnovers.AmountExpense, 0) <> 0
	|	AND NOT ISNULL(CatalogBankAccounts.AllowNegativeBalance, FALSE)
	|
	|ORDER BY
	|	LineNumber";
	
EndFunction

Procedure GenerateOrDeleteRecordsOnChangingFunctionalOption(Parameters, StorageAddress) Export
	
	SetPrivilegedMode(True);
	
	If Parameters.UseBankReconciliation Then
		GenerateRecords();
	Else
		DeleteRecords();
	EndIf;
	
EndProcedure

Function TransactionCleared(Transaction, BankAccount = Undefined) Export
	
	Query = New Query;
	
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	TRUE AS Cleared
	|FROM
	|	AccumulationRegister.BankReconciliation AS BankReconciliation
	|WHERE
	|	&BankAccount
	|	AND BankReconciliation.Transaction = &Transaction
	|	AND BankReconciliation.RecordType = VALUE(AccumulationRecordType.Expense)";
	
	Query.SetParameter("Transaction", Transaction);
	// BankAccount condition is used to fit the main register index
	// without it the result will be slower, but still correct
	If BankAccount = Undefined Then
		Query.SetParameter("BankAccount", True);
	Else
		Query.Text = StrReplace(Query.Text, "&BankAccount", "BankReconciliation.BankAccount = &BankAccount");
		Query.SetParameter("BankAccount", BankAccount);
	EndIf;
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

#EndRegion

#Region Private

Procedure GenerateRecords()
	
	RecorderFilter = CreateRecordSet().Filter.Recorder;
	RecorderTypes = RecorderFilter.ValueType.Types();
	
	For Each RecorderType In RecorderTypes Do
		
		DocumentMetadata = Metadata.FindByType(RecorderType);
		
		If Not DocumentMetadata = Undefined Then
			
			Query = New Query;
			Query.Text = StrReplace(
				"SELECT ALLOWED
				|	DocumentTable.Ref AS Ref
				|FROM
				|	&DocumentTable AS DocumentTable
				|WHERE
				|	DocumentTable.Posted",
				"&DocumentTable",
				DocumentMetadata.FullName());
			
			Sel = Query.Execute().Select();
			
			While Sel.Next() Do
				
				GenerateDocumentRecords(Sel.Ref, DocumentMetadata);
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure GenerateDocumentRecords(DocumentRef, DocumentMetadata)
	
	BeginTransaction();
	
	Try
		
		DocumentObject = DocumentRef.GetObject();
		AdditionalProperties = DocumentObject.AdditionalProperties;
		RegisterRecords = DocumentObject.RegisterRecords;
		
		DriveServer.InitializeAdditionalPropertiesForPosting(DocumentRef, AdditionalProperties);
		
		If TypeOf(DocumentObject) = Type("DocumentObject.ForeignCurrencyExchange") Then
			AdditionalProperties.Insert("CalculatedData", Documents.ForeignCurrencyExchange.GetCalculatedData(DocumentObject));
			If GetFunctionalOption("UseSeveralDepartments") Then 
				AdditionalProperties.ForPosting.Insert("StructuralUnit", DocumentObject.StructuralUnit);
			Else 
				AdditionalProperties.ForPosting.Insert("StructuralUnit", Catalogs.BusinessUnits.MainDepartment);
			EndIf;
		EndIf;
		
		Documents[DocumentMetadata.Name].InitializeDocumentData(DocumentRef, AdditionalProperties);
		
		DriveServer.ReflectBankReconciliation(AdditionalProperties, RegisterRecords, False);
		RegisterRecords.BankReconciliation.Write();
		
		AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'", DefaultLanguageCode),
			DocumentRef,
			BriefErrorDescription(ErrorInfo()));
		
		WriteLogEvent(
			NStr("en = 'BankReconciliationInitialGeneration'; ru = 'ПервичноеГенерированиеВзаиморасчетовСБанком';pl = 'BankReconciliationInitialGeneration';es_ES = 'BankReconciliationInitialGeneration';es_CO = 'BankReconciliationInitialGeneration';tr = 'BankReconciliationInitialGeneration';it = 'BankReconciliationInitialGeneration';de = 'BankReconciliationInitialGeneration'", DefaultLanguageCode),
			EventLogLevel.Error,
			DocumentMetadata,
			,
			ErrorDescription);
		
	EndTry;
	
EndProcedure

Procedure DeleteRecords()
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED DISTINCT
	|	BankReconciliation.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.BankReconciliation AS BankReconciliation";
	
	Sel = Query.Execute().Select();
	
	While Sel.Next() Do
		
		RecordSet = CreateRecordSet();
		RecordSet.Filter.Recorder.Set(Sel.Recorder);
		RecordSet.Write(True);
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf