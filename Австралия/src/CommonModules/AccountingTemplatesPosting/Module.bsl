
#Region Public

Procedure InitializeAccountingTemplatesProperties(DocumentRef, StructureAdditionalProperties, Cancel, TemplatesArray = Undefined, DoNotCheckTemplateValidityPeriod = False) Export
	
	AddRequiredTableAccountingEntriesData(StructureAdditionalProperties);
	
	ForPostingStructure = StructureAdditionalProperties.ForPosting;
	
	DocumentCompany		= ForPostingStructure.Company;
	DocumentPeriod		= ForPostingStructure.Date;
	DocumentMetadata	= ForPostingStructure.DocumentMetadata;
	
	ForPostingStructure.Insert("AccountingTemplatesPostingUnavailable", False);
	
	If TemplatesArray <> Undefined Then
		
		Query = New Query;
		Query.Text = 
		"SELECT DISTINCT
		|	VALUE(Enum.AccountingEntriesRegisterOptions.SourceDocuments) AS EntriesPostingOption,
		|	AccountingEntriesTemplates.TypeOfAccounting AS TypeOfAccounting,
		|	AccountingEntriesTemplates.ChartOfAccounts AS ChartOfAccounts,
		|	AccountingEntriesTemplates.ChartOfAccounts.ChartOfAccounts AS ChartOfAccountsMetadataObjectRef,
		|	AccountingEntriesTemplates.Company = VALUE(Catalog.Companies.EmptyRef) AS CompanyIsEmpty,
		|	AccountingEntriesTemplates.Ref AS Ref,
		|	CASE
		|		WHEN &DoNotCheckTemplateValidityPeriod
		|			THEN DATETIME(1, 1, 1)
		|		WHEN AccountingEntriesTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
		|			THEN AccountingEntriesTemplates.StartDate
		|		ELSE AccountingEntriesTemplates.PlanStartDate
		|	END AS StartDate,
		|	CASE
		|		WHEN &DoNotCheckTemplateValidityPeriod
		|			THEN DATETIME(3999, 12, 31)
		|		WHEN AccountingEntriesTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
		|				AND AccountingEntriesTemplates.EndDate = DATETIME(1, 1, 1)
		|			THEN DATETIME(3999, 12, 31)
		|		WHEN AccountingEntriesTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
		|			THEN AccountingEntriesTemplates.EndDate
		|		WHEN AccountingEntriesTemplates.PlanEndDate = DATETIME(1, 1, 1)
		|			THEN DATETIME(3999, 12, 31)
		|		ELSE AccountingEntriesTemplates.PlanEndDate
		|	END AS EndDate
		|INTO Templates
		|FROM
		|	Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
		|WHERE
		|	AccountingEntriesTemplates.Company IN (&Company, VALUE(Catalog.Companies.EmptyRef))
		|	AND AccountingEntriesTemplates.Ref IN(&TemplatesArray)
		|	AND AccountingEntriesTemplates.DocumentType = &DocumentType
		|
		|UNION ALL
		|
		|SELECT DISTINCT
		|	VALUE(Enum.AccountingEntriesRegisterOptions.SourceDocuments),
		|	AccountingTransactionsTemplates.TypeOfAccounting,
		|	AccountingTransactionsTemplates.ChartOfAccounts,
		|	AccountingTransactionsTemplates.ChartOfAccounts.ChartOfAccounts,
		|	AccountingTransactionsTemplates.Company = VALUE(Catalog.Companies.EmptyRef),
		|	AccountingTransactionsTemplates.Ref,
		|	CASE
		|		WHEN &DoNotCheckTemplateValidityPeriod
		|			THEN DATETIME(1, 1, 1)
		|		WHEN AccountingTransactionsTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
		|			THEN AccountingTransactionsTemplates.StartDate
		|		ELSE AccountingTransactionsTemplates.PlanStartDate
		|	END,
		|	CASE
		|		WHEN &DoNotCheckTemplateValidityPeriod
		|			THEN DATETIME(3999, 12, 31)
		|		WHEN AccountingTransactionsTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
		|				AND AccountingTransactionsTemplates.EndDate = DATETIME(1, 1, 1)
		|			THEN DATETIME(3999, 12, 31)
		|		WHEN AccountingTransactionsTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
		|			THEN AccountingTransactionsTemplates.EndDate
		|		WHEN AccountingTransactionsTemplates.PlanEndDate = DATETIME(1, 1, 1)
		|			THEN DATETIME(3999, 12, 31)
		|		ELSE AccountingTransactionsTemplates.PlanEndDate
		|	END
		|FROM
		|	Catalog.AccountingTransactionsTemplates AS AccountingTransactionsTemplates
		|WHERE
		|	AccountingTransactionsTemplates.Company IN (&Company, VALUE(Catalog.Companies.EmptyRef))
		|	AND AccountingTransactionsTemplates.Ref IN(&TemplatesArray)
		|	AND AccountingTransactionsTemplates.DocumentType = &DocumentType
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Templates.EntriesPostingOption AS EntriesPostingOption,
		|	Templates.TypeOfAccounting AS TypeOfAccounting,
		|	Templates.ChartOfAccounts AS ChartOfAccounts,
		|	Templates.ChartOfAccountsMetadataObjectRef AS ChartOfAccountsMetadataObjectRef,
		|	Templates.CompanyIsEmpty AS CompanyIsEmpty,
		|	Templates.Ref AS Ref,
		|	Templates.StartDate AS StartDate,
		|	Templates.EndDate AS EndDate
		|INTO TemplatesForPeriod
		|FROM
		|	Templates AS Templates
		|WHERE
		|	Templates.StartDate <= &DocumentDate
		|	AND Templates.EndDate >= &DocumentDate
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TemplatesForPeriod.TypeOfAccounting AS TypeOfAccounting,
		|	TemplatesForPeriod.ChartOfAccounts AS ChartOfAccounts,
		|	TemplatesForPeriod.Ref AS Template,
		|	TemplatesForPeriod.CompanyIsEmpty AS CompanyIsEmpty
		|FROM
		|	TemplatesForPeriod AS TemplatesForPeriod
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TemplatesForPeriod.EntriesPostingOption AS EntriesPostingOption,
		|	TemplatesForPeriod.TypeOfAccounting AS TypeOfAccounting,
		|	TemplatesForPeriod.ChartOfAccounts AS ChartOfAccounts,
		|	TemplatesForPeriod.ChartOfAccountsMetadataObjectRef AS ChartOfAccountsMetadataObjectRef,
		|	TRUE AS IsRecorder
		|FROM
		|	TemplatesForPeriod AS TemplatesForPeriod";
		
		Query.SetParameter("Company"							, DocumentCompany);
		Query.SetParameter("DocumentDate"						, DocumentPeriod);
		Query.SetParameter("DocumentType"						, Common.MetadataObjectID(DocumentMetadata));
		Query.SetParameter("DoNotCheckTemplateValidityPeriod"	, DoNotCheckTemplateValidityPeriod);
		Query.SetParameter("TemplatesArray"						, TemplatesArray);
		
		QueryResult = Query.ExecuteBatch();
		
		ApplicableTemplatesTable = QueryResult[2].Unload();
		AccountingSettingTable	 = QueryResult[3].Unload();
		
		If ApplicableTemplatesTable.Count() = 0 Then
			ForPostingStructure.Insert("ErrorID", "InvalidTemplatesPeriod");
		EndIf;
		
		ForPostingStructure.Insert("ApplicableAccountingTemplatesTable", ApplicableTemplatesTable);
		ForPostingStructure.Insert("AccountingSettingTable"	, AccountingSettingTable);
		ForPostingStructure.Insert("TemplatesArray"			, TemplatesArray);
		
		Return;
		
	EndIf;
	
	ForPostingStructure.Insert("ApplicableAccountingTemplatesTable", New ValueTable);
	
	TypesOfAccountingTable = GetCompanyAccountingSettingsTable(DocumentCompany, DocumentPeriod, DocumentRef);
	
	If TypeOf(DocumentRef) = Type("DocumentRef.AccountingTransaction") Then
		
		ForPostingStructure.Insert("AccountingSettingTable", TypesOfAccountingTable.Copy());
		Return;
		
	Else
		ForPostingStructure.Insert("AccountingSettingTable", TypesOfAccountingTable.CopyColumns());
	EndIf;

	If StructureAdditionalProperties.AccountingPolicy.AccountingModuleSettings
		<> Enums.AccountingModuleSettingsTypes.UseTemplateBasedTypesOfAccounting
		Or TypesOfAccountingTable.Count() = 0
		Or DocumentNotRecorder(TypesOfAccountingTable) Then
		Return;
	EndIf;
		
	InformationRegisters.AccountingSourceDocuments.CheckNotifyTypesOfAccountingProblems(
		DocumentRef,
		DocumentCompany,
		DocumentPeriod,
		Cancel);
		
	SetDocumentPostingStatus(DocumentRef, DocumentCompany, DocumentPeriod, TypesOfAccountingTable);
		
	If DocumentNotRecorder(TypesOfAccountingTable) Then
		Return;
	EndIf;
	
	ApplicableTemplatesTable = GetApplicableTemplatesTable(
		DocumentCompany,
		DocumentPeriod,
		DocumentMetadata,
		TypesOfAccountingTable);
		
	ErrorTemplate = NStr("en = 'Cannot post the document. 
		|The applicable Accounting transaction template is required. 
		|To be able to post the document, create the template with ""%1"", ""%2"", and ""%3"". 
		|Set the template status to Active. 
		|Then try posting the document again.'; 
		|ru = 'Не удалось провести документ. 
		|Требуется соответствующий шаблон бухгалтерских операций. 
		|Чтобы провести документ, создайте шаблон с ""%1"", ""%2"" и ""%3"". 
		|Установите для шаблона статус ""Активен"" и повторите попытку.
		|';
		|pl = 'Nie można zatwierdzić dokumentu. 
		|Wymagany jest obowiązujący szablon Transakcji księgowej. 
		|Aby mieć możliwość zatwierdzenia dokumentu, utwórz szablon z ""%1"", ""%2"", i ""%3"". 
		|Ustaw status szablonu na Aktywny. 
		|Następnie spróbuj zatwierdzić dokument ponownie.';
		|es_ES = 'No se puede contabilizar el documento
		|. Se requiere la plantilla de transacción contable aplicable.
		|Para poder contabilizar el documento, cree la plantilla con ""%1"", ""%2"" y ""%3"". 
		| Establezca el estado de la plantilla en Activo. 
		|A continuación, intente volver a contabilizar el documento.';
		|es_CO = 'No se puede contabilizar el documento
		|. Se requiere la plantilla de transacción contable aplicable.
		|Para poder contabilizar el documento, cree la plantilla con ""%1"", ""%2"" y ""%3"". 
		| Establezca el estado de la plantilla en Activo. 
		|A continuación, intente volver a contabilizar el documento.';
		|tr = 'Belge kaydedilemiyor. 
		|Uygulanabilir bir Muhasebe işlemi şablonu gerekli. 
		|Belgeyi kaydedebilmek için ""%1"", ""%2"" ve ""%3"" içeren bir şablon oluşturun. 
		|Şablonun durumunu Aktif olarak belirleyin. 
		|Ardından, belgeyi tekrar kaydetmeyi deneyin.';
		|it = 'Impossibile pubblicare il documento. 
		|È necessario il modello di transazione contabile applicabile. 
		|Per poter registrare il documento, creare il modello con ""%1"", ""%2"", e ""%3"". 
		|Impostare lo stato del modello su Attivo. 
		|Quindi provare a pubblicare di nuovo il documento.';
		|de = 'Fehler beim Buchen des Dokuments. 
		|Die verwendbare Buchhaltungstransaktionsvorlage ist erforderlich. 
		|Um dieses Dokument buchen zu können, erstellen Sie die Vorlage mit ""%1"", ""%2"", und ""%3"". 
		|Setzen Sie den Vorlagenstatus als Aktiv fest. 
		|Dann versuchen Sie mit dem Buchen des Dokuments erneut.'");

	For Each AccountingSetting In TypesOfAccountingTable Do
		
		FilterAllRows = New Structure("ChartOfAccounts, TypeOfAccounting");
		FillPropertyValues(FilterAllRows, AccountingSetting);
		
		FilterCompanyEmpty = New Structure("ChartOfAccounts, TypeOfAccounting");
		FillPropertyValues(FilterCompanyEmpty, AccountingSetting);
		FilterCompanyEmpty.Insert("CompanyIsEmpty", True);

		ApplicableTemplatesAll			= ApplicableTemplatesTable.FindRows(FilterAllRows);
		ApplicableTemplatesEmptyCompany	= ApplicableTemplatesTable.FindRows(FilterCompanyEmpty);
		
		If ApplicableTemplatesAll.Count() = 0 Then
		
			ErrorMessage = StrTemplate(ErrorTemplate, 
				DocumentCompany, 
				AccountingSetting.TypeOfAccounting,
				DocumentMetadata);
				
			DriveServer.ShowMessageAboutError(DocumentRef.GetObject(), ErrorMessage, , , , Cancel);
			
			ForPostingStructure.AccountingTemplatesPostingUnavailable = True;
			
		ElsIf ApplicableTemplatesAll.Count() > ApplicableTemplatesEmptyCompany.Count() Then
			
			For Each RowEmptyCompany In ApplicableTemplatesEmptyCompany Do
				
				ApplicableTemplatesTable.Delete(RowEmptyCompany);
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	If Not Cancel Then
		
		ForPostingStructure.ApplicableAccountingTemplatesTable = ApplicableTemplatesTable;
		ForPostingStructure.Insert("AccountingSettingTable", TypesOfAccountingTable);
		
	EndIf;
	
EndProcedure 

Procedure GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties) Export

	PostingParametersStructure = StructureAdditionalProperties.ForPosting;

	If PostingParametersStructure.Property("AccountingTransactionDocumentGeneration") Then
		PostingOption = Enums.AccountingEntriesRegisterOptions.AccountingTransactionDocument;
		PostingTypeOfAccounting = PostingParametersStructure.PostingTypeOfAccounting;
	Else
		PostingOption = Enums.AccountingEntriesRegisterOptions.SourceDocuments;
		PostingTypeOfAccounting = Catalogs.TypesOfAccounting.EmptyRef();
	EndIf;
	
	ApplicableTemplatesArray = FilterTemplatesTable(
		PostingParametersStructure.ApplicableAccountingTemplatesTable,
		PostingParametersStructure.AccountingSettingTable,
		PostingOption,
		PostingTypeOfAccounting,
		False);
	
	If ApplicableTemplatesArray.Count() = 0 Then
		Return;
	EndIf;
		
	TemplatesForConstantsTable = PostingParametersStructure.ApplicableAccountingTemplatesTable.UnloadColumn("Template");
		
	TempTablesManager	= PostingParametersStructure.StructureTemporaryTables.TempTablesManager;
	CurrentDocMetadata	= PostingParametersStructure.DocumentMetadata;

	// Doc attributes, accounting policy, constants
	AddCommonTemporaryTables(TempTablesManager, PostingParametersStructure, ApplicableTemplatesArray);
	
	EntriesTable = GetTransactionsEntriesTable(ApplicableTemplatesArray, 
		PostingParametersStructure,
		TempTablesManager,
		False);
		
	QueryParametersMap = New Map;
		
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text = DocumentPostingQueryText(StructureAdditionalProperties, EntriesTable, QueryParametersMap, False, New Array);
	
	If EntriesTable.Count() = 0 Then
		Return;
	EndIf;
	
	Query.SetParameter("DrCrEmpty"	, Enums.DebitCredit.EmptyRef());
	Query.SetParameter("DrCrCredit"	, Enums.DebitCredit.Cr);
	Query.SetParameter("DrCrDebit"	, Enums.DebitCredit.Dr);
	
	For Each Entry In EntriesTable Do
		
		AccountCrValue					= AdjustFieldValue("AccountCr"			, Entry);
		AccountDrValue					= AdjustFieldValue("AccountDr"			, Entry);
		TypeOfAccounting				= AdjustFieldValue("TypeOfAccounting"	, Entry);
		TransactionTemplate				= AdjustFieldValue("TransactionTemplate", Entry);
		TransactionTemplateLineNumber	= AdjustFieldValue("TransactionTemplateLineNumber", Entry);

		Query.SetParameter("AccountCr"						+ Entry.RowID, AccountCrValue);
		Query.SetParameter("AccountDr"						+ Entry.RowID, AccountDrValue);
		Query.SetParameter("TypeOfAccounting"				+ Entry.RowID, TypeOfAccounting);
		Query.SetParameter("TransactionTemplate"			+ Entry.RowID, TransactionTemplate);
		Query.SetParameter("TransactionTemplateLineNumber"	+ Entry.RowID, TransactionTemplateLineNumber);

		Query.SetParameter("ConnectionKey"			+ Entry.RowID, Entry.ConnectionKey);
		Query.SetParameter("DefaultAccountType"		+ Entry.RowID, Entry.DefaultAccountType);
		Query.SetParameter("DefaultAccountTypeCr"	+ Entry.RowID, Entry.DefaultAccountTypeCr);
		Query.SetParameter("DefaultAccountTypeDr"	+ Entry.RowID, Entry.DefaultAccountTypeDr);
		Query.SetParameter("AccountReferenceName"	+ Entry.RowID, Entry.AccountReferenceName);
		Query.SetParameter("AccountReferenceNameCr"	+ Entry.RowID, Entry.AccountReferenceNameCr);
		Query.SetParameter("AccountReferenceNameDr"	+ Entry.RowID, Entry.AccountReferenceNameDr);

	EndDo;
	
	SetQueryParametersFromMap(Query, QueryParametersMap);
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Period"	, StructureAdditionalProperties.ForPosting.PointInTime);
	Query.SetParameter("Ref"	, DocumentRef);
	
	QueryResult = Query.ExecuteBatch();
	
	DefaultAccountsTable			= QueryResult[QueryResult.Count() - 2].Unload();
	TableAccountingJournalEntries	= QueryResult[QueryResult.Count() - 1].Unload();
	
	ProcessDefaultAccounts(DefaultAccountsTable, TableAccountingJournalEntries, "Dr");
	ProcessDefaultAccounts(DefaultAccountsTable, TableAccountingJournalEntries, "Cr");
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", TableAccountingJournalEntries);
	
EndProcedure

Procedure GenerateTableMasterAccountingJournalEntries(DocumentRef, StructureAdditionalProperties) Export
	
	PostingParametersStructure = StructureAdditionalProperties.ForPosting;
	
	If Not PostingParametersStructure.Property("TemplatesArray")
		And PostingParametersStructure.Property("AccountingTransactionDocumentGeneration") Then
		PostingOption = Enums.AccountingEntriesRegisterOptions.AccountingTransactionDocument;
		PostingTypeOfAccounting = PostingParametersStructure.PostingTypeOfAccounting;
	Else
		PostingOption = Enums.AccountingEntriesRegisterOptions.SourceDocuments;
		PostingTypeOfAccounting = Catalogs.TypesOfAccounting.EmptyRef();
	EndIf;
	
	ApplicableTemplatesArray = FilterTemplatesTable(
		PostingParametersStructure.ApplicableAccountingTemplatesTable,
		PostingParametersStructure.AccountingSettingTable, 
		PostingOption,
		PostingTypeOfAccounting,
		True);
	
	If ApplicableTemplatesArray.Count() = 0 Then
		Return;
	EndIf;
		
	TempTablesManager	= PostingParametersStructure.StructureTemporaryTables.TempTablesManager;
	CurrentDocMetadata	= PostingParametersStructure.DocumentMetadata;
	
	// Doc attributes, accounting policy, constants
	AddCommonTemporaryTables(TempTablesManager, PostingParametersStructure, ApplicableTemplatesArray);
	
	EntriesTable = GetTransactionsEntriesTable(ApplicableTemplatesArray,
		PostingParametersStructure,
		TempTablesManager,
		True);
		
	If EntriesTable.Count() = 0 Then
		PostingParametersStructure.Insert("ErrorID", "InvalidTemplatesParameters");
		Return;
	EndIf;
		
	QueryParametersMap	= New Map;
	AdditionalQueryParameters = New Array;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text = DocumentPostingQueryText(StructureAdditionalProperties,
		EntriesTable,
		QueryParametersMap,
		True,
		AdditionalQueryParameters);
	
	Query.SetParameter("DrCrEmpty"	, Enums.DebitCredit.EmptyRef());
	Query.SetParameter("DrCrCredit"	, Enums.DebitCredit.Cr);
	Query.SetParameter("DrCrDebit"	, Enums.DebitCredit.Dr);
	
	For Each Entry In EntriesTable Do
		
		If Entry.TypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Compound Then
			
			AccountValue	= AdjustFieldValue("Account"	, Entry);
			RecordTypeValue	= AdjustFieldValue("RecordType"	, Entry); 
			
			Query.SetParameter("Account"	+ Entry.RowID, AccountValue);
			Query.SetParameter("RecordType"	+ Entry.RowID, RecordTypeValue);
			
			AnalyticalDimensionsType1Value = AdjustFieldValue("AnalyticalDimensionsType1", Entry);
			AnalyticalDimensionsType2Value = AdjustFieldValue("AnalyticalDimensionsType2", Entry);
			AnalyticalDimensionsType3Value = AdjustFieldValue("AnalyticalDimensionsType3", Entry);
			AnalyticalDimensionsType4Value = AdjustFieldValue("AnalyticalDimensionsType4", Entry);
			
			Query.SetParameter("AnalyticalDimensionsType1"	+ Entry.RowID, AnalyticalDimensionsType1Value);
			Query.SetParameter("AnalyticalDimensionsType2"	+ Entry.RowID, AnalyticalDimensionsType2Value);
			Query.SetParameter("AnalyticalDimensionsType3"	+ Entry.RowID, AnalyticalDimensionsType3Value);
			Query.SetParameter("AnalyticalDimensionsType4"	+ Entry.RowID, AnalyticalDimensionsType4Value);
			
		Else
			
			AccountCrValue = AdjustFieldValue("AccountCr", Entry); 
			AccountDrValue = AdjustFieldValue("AccountDr", Entry); 
			
			Query.SetParameter("AccountCr" + Entry.RowID, AccountCrValue);
			Query.SetParameter("AccountDr" + Entry.RowID, AccountDrValue);
			
			AnalyticalDimensionsTypeDr1Value	= AdjustFieldValue("AnalyticalDimensionsTypeDr1", Entry);
			AnalyticalDimensionsTypeDr2Value	= AdjustFieldValue("AnalyticalDimensionsTypeDr2", Entry);
			AnalyticalDimensionsTypeDr3Value	= AdjustFieldValue("AnalyticalDimensionsTypeDr3", Entry);
			AnalyticalDimensionsTypeDr4Value	= AdjustFieldValue("AnalyticalDimensionsTypeDr4", Entry);
			
			Query.SetParameter("AnalyticalDimensionsTypeDr1"	+ Entry.RowID, AnalyticalDimensionsTypeDr1Value);
			Query.SetParameter("AnalyticalDimensionsTypeDr2"	+ Entry.RowID, AnalyticalDimensionsTypeDr2Value);
			Query.SetParameter("AnalyticalDimensionsTypeDr3"	+ Entry.RowID, AnalyticalDimensionsTypeDr3Value);
			Query.SetParameter("AnalyticalDimensionsTypeDr4"	+ Entry.RowID, AnalyticalDimensionsTypeDr4Value);
			
			AnalyticalDimensionsTypeCr1Value	= AdjustFieldValue("AnalyticalDimensionsTypeCr1", Entry);
			AnalyticalDimensionsTypeCr2Value	= AdjustFieldValue("AnalyticalDimensionsTypeCr2", Entry);
			AnalyticalDimensionsTypeCr3Value	= AdjustFieldValue("AnalyticalDimensionsTypeCr3", Entry);
			AnalyticalDimensionsTypeCr4Value	= AdjustFieldValue("AnalyticalDimensionsTypeCr4", Entry);
			
			Query.SetParameter("AnalyticalDimensionsTypeCr1"	+ Entry.RowID, AnalyticalDimensionsTypeCr1Value);
			Query.SetParameter("AnalyticalDimensionsTypeCr2"	+ Entry.RowID, AnalyticalDimensionsTypeCr2Value);
			Query.SetParameter("AnalyticalDimensionsTypeCr3"	+ Entry.RowID, AnalyticalDimensionsTypeCr3Value);
			Query.SetParameter("AnalyticalDimensionsTypeCr4"	+ Entry.RowID, AnalyticalDimensionsTypeCr4Value);

		EndIf;
		
		TypeOfAccounting				= AdjustFieldValue("TypeOfAccounting", Entry);
		TransactionTemplate				= AdjustFieldValue("TransactionTemplate", Entry);
		TransactionTemplateLineNumber	= AdjustFieldValue("TransactionTemplateLineNumber", Entry);

		Query.SetParameter("TypeOfAccounting"				+ Entry.RowID, TypeOfAccounting);
		Query.SetParameter("TransactionTemplate"			+ Entry.RowID, TransactionTemplate);
		Query.SetParameter("TransactionTemplateLineNumber"	+ Entry.RowID, TransactionTemplateLineNumber);

		Query.SetParameter("ConnectionKey"			+ Entry.RowID, Entry.ConnectionKey);
		Query.SetParameter("DefaultAccountType"		+ Entry.RowID, Entry.DefaultAccountType);
		Query.SetParameter("DefaultAccountTypeCr"	+ Entry.RowID, Entry.DefaultAccountTypeCr);
		Query.SetParameter("DefaultAccountTypeDr"	+ Entry.RowID, Entry.DefaultAccountTypeDr);
		Query.SetParameter("AccountReferenceName"	+ Entry.RowID, Entry.AccountReferenceName);
		Query.SetParameter("AccountReferenceNameCr"	+ Entry.RowID, Entry.AccountReferenceNameCr);
		Query.SetParameter("AccountReferenceNameDr"	+ Entry.RowID, Entry.AccountReferenceNameDr);
		
	EndDo;
	
	For Each AdditionalQueryParameter In AdditionalQueryParameters Do
		Query.SetParameter(AdditionalQueryParameter.ParameterName, AdditionalQueryParameter.ParameterValue);
	EndDo;
		
	SetQueryParametersFromMap(Query, QueryParametersMap);
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Period"	, StructureAdditionalProperties.ForPosting.PointInTime);
	Query.SetParameter("Ref"	, DocumentRef);
	
	QueryResult = Query.ExecuteBatch();
	
	DefaultAccountsTable	= QueryResult[QueryResult.Count() - 3].Unload();
	TableSimple				= QueryResult[QueryResult.Count() - 2].Unload();
	TableCompound			= QueryResult[QueryResult.Count() - 1].Unload();
	
	ProcessDefaultAccounts(DefaultAccountsTable, TableCompound);
	ProcessDefaultAccounts(DefaultAccountsTable, TableSimple, "Dr");
	ProcessDefaultAccounts(DefaultAccountsTable, TableSimple, "Cr");
	
	ClearExcessiveAttributes(TableCompound, TableSimple);
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntriesCompound", TableCompound);
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntriesSimple"	, TableSimple);
	
EndProcedure

Procedure CreateRefreshTransactionDocuments(DocumentRef, StructureAdditionalProperties, Mode = Undefined) Export
	
	SetPrivilegedMode(True);
	
	ApplicableTypesOfAccountingTable = GetApplicableTypesOfAccounting(
		StructureAdditionalProperties.Company, 
		StructureAdditionalProperties.Period,
		StructureAdditionalProperties.TypesOfAccounting,
		Enums.AccountingEntriesRegisterOptions.AccountingTransactionDocument);
	
	TransactionDocRequired = DocumentPostingRequired(DocumentRef,
		StructureAdditionalProperties.Company,
		GetValuesArrayFromTable(ApplicableTypesOfAccountingTable, "TypeOfAccounting"),
		StructureAdditionalProperties.Period);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	TypeOfAccountingAndChartOfAccounts.TypeOfAccounting AS TypeOfAccounting,
	|	TypeOfAccountingAndChartOfAccounts.ChartOfAccounts AS ChartOfAccounts
	|INTO TT_TypeOfAccountingAndChartOfAccounts
	|FROM
	|	&TypeOfAccountingAndChartOfAccounts AS TypeOfAccountingAndChartOfAccounts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountingTransaction.Ref AS Ref,
	|	AccountingTransaction.ChartOfAccounts AS ChartOfAccounts,
	|	AccountingTransaction.TypeOfAccounting AS TypeOfAccounting
	|FROM
	|	Document.AccountingTransaction AS AccountingTransaction
	|WHERE
	|	AccountingTransaction.BasisDocument = &BasisDocument
	|	AND (AccountingTransaction.TypeOfAccounting, AccountingTransaction.ChartOfAccounts) IN
	|			(SELECT
	|				TT_TypeOfAccountingAndChartOfAccounts.TypeOfAccounting AS TypeOfAccounting,
	|				TT_TypeOfAccountingAndChartOfAccounts.ChartOfAccounts AS ChartOfAccounts
	|			FROM
	|				TT_TypeOfAccountingAndChartOfAccounts AS TT_TypeOfAccountingAndChartOfAccounts)";
	
	Query.SetParameter("BasisDocument", DocumentRef);
	Query.SetParameter("TypeOfAccountingAndChartOfAccounts", ApplicableTypesOfAccountingTable);
	
	If StructureAdditionalProperties.WriteMode = DocumentWriteMode.Posting Then
		
		If Not TransactionDocRequired Then
			Return;
		EndIf;
		
		SelectionDetailRecords = Query.Execute().Select();
		
		BeginTransaction();
		
		Try
			
			While SelectionDetailRecords.Next() Do
				
				TransactionDocument = SelectionDetailRecords.Ref.GetObject();
				TransactionDocument.Mode = Mode;
				
				SetDocumentRecords(TransactionDocument, DocumentRef);
				
				Filter = New Structure;
				Filter.Insert("TypeOfAccounting", SelectionDetailRecords.TypeOfAccounting);
				Filter.Insert("ChartOfAccounts", SelectionDetailRecords.ChartOfAccounts);
				
				Rows = ApplicableTypesOfAccountingTable.FindRows(Filter);
				
				For Each Row In Rows Do
					ApplicableTypesOfAccountingTable.Delete(Row);
				EndDo;
				
			EndDo;
			
			For Each Row In ApplicableTypesOfAccountingTable Do
				
				FillStructure = New Structure;
				FillStructure.Insert("Company", StructureAdditionalProperties.Company);
				FillStructure.Insert("TypeOfAccounting", Row.TypeOfAccounting);
				FillStructure.Insert("ChartOfAccounts", Row.ChartOfAccounts);
				FillStructure.Insert("BasisDocument", DocumentRef);
				
				TransactionDocument = Documents.AccountingTransaction.CreateDocument();
				TransactionDocument.Fill(FillStructure);
				TransactionDocument.Date = CurrentSessionDate();
				TransactionDocument.BasisDocument	 = DocumentRef;
				TransactionDocument.Author			 = Users.CurrentUser();
				TransactionDocument.Company			 = StructureAdditionalProperties.Company;
				TransactionDocument.ChartOfAccounts	 = Row.ChartOfAccounts;
				TransactionDocument.TypeOfAccounting = Row.TypeOfAccounting;
				TransactionDocument.Mode			 = Mode;
				
				SetDocumentRecords(TransactionDocument, DocumentRef);
				
			EndDo;
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot create Accounting transaction document, ""%1""'; ru = 'Не удалось создать документ бухгалтерской операции, ""%1""';pl = 'Nie można utworzyć dokumentu Transakcja księgowa, ""%1""';es_ES = 'No se puede crear el documento de transacción contable, ""%1""';es_CO = 'No se puede crear el documento de transacción contable, ""%1""';tr = 'Muhasebe işlemi belgesi oluşturulamıyor, ""%1""';it = 'Impossibile creare il documento di transazione contabile ""%1""';de = 'Fehler beim Erstellen des Buchhaltungstransaktionsdokuments, ""%1""'"),
				DetailErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				NStr("en = 'Accounting transaction document creation'; ru = 'Создание документа бухгалтерской операции';pl = 'Tworzenie dokumentu Transakcja księgowa';es_ES = 'Crear un documento de transacción contable';es_CO = 'Crear un documento de transacción contable';tr = 'Muhasebe işlemi belgesi oluşturma';it = 'Creazione documento transazione contabile';de = 'Erstellung des Buchhaltungstransaktionsdokuments'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.Documents.AccountingTransaction,
				,
				ErrorDescription);
			
		EndTry;
		
	Else
		
		SelectionDetailRecords = Query.Execute().Select();
		
		BeginTransaction();
		
		Try
			
			While SelectionDetailRecords.Next() Do
				
				TransactionDocument = SelectionDetailRecords.Ref.GetObject();
				
				If StructureAdditionalProperties.WriteMode = DocumentWriteMode.UndoPosting Then
					
					If TransactionDocument.Posted Then
						TransactionDocument.Write(DocumentWriteMode.UndoPosting);
					EndIf;
					
					If TransactionDocument.DeletionMark <> StructureAdditionalProperties.DeletionMark Then
						TransactionDocument.SetDeletionMark(StructureAdditionalProperties.DeletionMark);
					EndIf;
					
				ElsIf StructureAdditionalProperties.WriteMode = DocumentWriteMode.Write
					And TransactionDocument.DeletionMark <> StructureAdditionalProperties.DeletionMark Then
					
					TransactionDocument.SetDeletionMark(StructureAdditionalProperties.DeletionMark);
					
				EndIf;
				
			EndDo;
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot update Accounting transaction document, ""%1""'; ru = 'Не удалось обновить документ бухгалтерской операции, ""%1""';pl = 'Nie można zaktualizować dokumentu Transakcja księgowa, ""%1""';es_ES = 'No se puede actualizar el documento de transacción contable, ""%1""';es_CO = 'No se puede actualizar el documento de transacción contable, ""%1""';tr = 'Muhasebe işlemi belgesi güncellenemiyor, ""%1""';it = 'Impossibile aggiornare il documento transazione contabile ""%1""';de = 'Fehler beim Aktualisieren des Buchhaltungstransaktionsdokuments, ""%1""'"),
				DetailErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				NStr("en = 'Accounting transaction document updating'; ru = 'Обновление документа бухгалтерской операции';pl = 'Aktualizacja dokumentu Transakcja księgowa';es_ES = 'Actualización del documento de transacción contable';es_CO = 'Actualización del documento de transacción contable';tr = 'Muhasebe işlemi belgesi güncelleme';it = 'Aggiornamento documento transazione contabile';de = 'Aktualisieren des Buchhaltungstransaktionsdokuments'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.Documents.AccountingTransaction,
				,
				ErrorDescription);
			
		EndTry;
		
	EndIf;
	
	SetPrivilegedMode(False);
	
EndProcedure

Procedure CreateRefreshTransactionDocumentsByMode(DocumentRef, WriteMode, DeletionMark, Company, Period, AdditionalProperties) Export
	
	If WriteMode = DocumentWriteMode.Posting
		And Common.ObjectAttributeValue(DocumentRef,"Posted") = AdditionalProperties["Posted"] Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingTransactionGenerationSettings.TypeOfAccounting AS TypeOfAccounting
	|FROM
	|	InformationRegister.AccountingTransactionGenerationSettings AS AccountingTransactionGenerationSettings,
	|	InformationRegister.AccountingPolicy.SliceLast(
	|			&Period,
	|			Company = &Company
	|				AND &UseTemplates) AS AccountingPolicySliceLast
	|WHERE
	|	AccountingTransactionGenerationSettings.Enabled
	|	AND CASE
	|			WHEN &PostingMode
	|				THEN AccountingTransactionGenerationSettings.Mode = VALUE(Enum.AccountingTransactionGenerationMode.AutomaticallyPosted)
	|			ELSE TRUE
	|		END
	|	AND AccountingTransactionGenerationSettings.Company = &Company";
	
	Query.SetParameter("Company"		, Company);
	Query.SetParameter("Period"			, Period);
	Query.SetParameter("UseTemplates"	, Constants.AccountingModuleSettings.UseTemplatesIsEnabled());
	Query.SetParameter("PostingMode"	, (WriteMode = DocumentWriteMode.Posting));
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		StructureAdditionalProperties = New Structure;
		StructureAdditionalProperties.Insert("Company"			, Company);
		StructureAdditionalProperties.Insert("Period"			, Period);
		StructureAdditionalProperties.Insert("WriteMode"		, WriteMode);
		StructureAdditionalProperties.Insert("DeletionMark"		, DeletionMark);
		StructureAdditionalProperties.Insert("TypesOfAccounting", QueryResult.Unload().UnloadColumn("TypeOfAccounting"));
		
		CreateRefreshTransactionDocuments(
			DocumentRef,
			StructureAdditionalProperties,
			Enums.AccountingTransactionGenerationMode.AutomaticallyPosted);
		
	EndIf;
	
EndProcedure

Function GetAccountingEntriesTablesStructure(DocumentRef, Cancel, TypeOfAccounting, TemplatesArray = Undefined, DoNotCheckTemplateValidityPeriod = False) Export
	
	DocumentObject = DocumentRef.GetObject();
	
	AdditionalProperties = DocumentObject.AdditionalProperties;
	//AdditionalProperties.Insert("UseBlocks", TemplatesArray = Undefined);
	DriveServer.InitializeAdditionalPropertiesForPosting(DocumentRef, AdditionalProperties);
	
	InitializeAccountingTemplatesProperties(DocumentRef, AdditionalProperties, Cancel, TemplatesArray, DoNotCheckTemplateValidityPeriod);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return Undefined;
	EndIf;
	
	If TypeOfAccounting <> Undefined Then
		AdditionalProperties.ForPosting.Insert("AccountingTransactionDocumentGeneration", True);
		AdditionalProperties.ForPosting.Insert("PostingTypeOfAccounting"				, TypeOfAccounting);
	EndIf;
	
	TablesStructure = New Structure("TableAccountingJournalEntries, TableAccountingJournalEntriesCompound, TableAccountingJournalEntriesSimple");
	If AdditionalProperties.ForPosting.Property("ErrorID") Then
		TablesStructure.Insert("ErrorID", AdditionalProperties.ForPosting.ErrorID);
	Else
		
		ObjectManager = Common.ObjectManagerByRef(DocumentRef);
		
		If TemplatesArray = Undefined Then
			ObjectManager.InitializeDocumentData(DocumentRef, AdditionalProperties);
		Else
			
			For Each RegisterRecordSet In DocumentObject.RegisterRecords Do
				
				RegisterMetadata	= RegisterRecordSet.Metadata();
				RegisterTableName	= StringFunctionsClientServer.SubstituteParametersToString("Table%1", RegisterMetadata.Name);
				RegisterMetadataType = Undefined;
				If Metadata.InformationRegisters.IndexOf(RegisterMetadata) >= 0 Then
					RegisterMetadataType = "InformationRegister";
				ElsIf Metadata.AccumulationRegisters.IndexOf(RegisterMetadata) >= 0 Then
					RegisterMetadataType = "AccumulationRegister";
				ElsIf Metadata.AccountingRegisters.IndexOf(RegisterMetadata) >= 0 Then
					Continue;
				EndIf;
				
				RegisterRecordSet.Read();
				TempTable = RegisterRecordSet.Unload();
				TypedTable = New ValueTable;
				DriveServer.ValueTableCreateTypedColumnsByRegister(TypedTable, RegisterMetadata.Name, RegisterMetadataType);
				For Each Row In TempTable Do
					NewRow = TypedTable.Add();
					FillPropertyValues(NewRow, Row);
				EndDo;
				
				AdditionalProperties.TableForRegisterRecords.Insert(RegisterTableName, TypedTable);
				
			EndDo;
			
			//Generate entries
			GenerateTableAccountingJournalEntries(DocumentRef, AdditionalProperties);
			GenerateTableMasterAccountingJournalEntries(DocumentRef, AdditionalProperties);
		
		EndIf;
		
		AddAttributesToAdditionalPropertiesForPosting(DocumentObject, AdditionalProperties);
		
		CheckEntriesAccounts(AdditionalProperties, Cancel);
		
		If AdditionalProperties.ForPosting.Property("ErrorID") Then
			TablesStructure.Insert("ErrorID", AdditionalProperties.ForPosting.ErrorID);
		EndIf;
		
		FillPropertyValues(TablesStructure, AdditionalProperties.TableForRegisterRecords);
		
	EndIf;
	
	Return TablesStructure;
	
EndFunction

Procedure PostDocumentsByAccountingTemplates(GenSettings) Export
	
	Company = GenSettings.Company;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingSourceDocumentsSliceLast.DocumentType AS DocumentType,
	|	AccountingSourceDocumentsSliceLast.Period AS Period
	|FROM
	|	InformationRegister.AccountingSourceDocuments.SliceLast(
	|			&Period,
	|			Company = &Company
	|				AND TypeOfAccounting = &TypeOfAccounting) AS AccountingSourceDocumentsSliceLast
	|WHERE
	|	AccountingSourceDocumentsSliceLast.Uses";
	
	Query.SetParameter("Company"			, Company);
	Query.SetParameter("TypeOfAccounting"	, GenSettings.TypeOfAccounting);
	Query.SetParameter("Period"				, CurrentSessionDate());
	
	QueryResult = Query.Execute();
	SelectionDetailRecords = QueryResult.Select();
	
	Query = New Query;
	QueryText = "";
	QueryTextTemplate =
	"SELECT
	|	DocumentType.Ref AS Ref
	|FROM
	|	&TableName AS DocumentType
	|WHERE
	|	DocumentType.Posted
	|	AND DocumentType.Company = &Company
	|	AND DocumentType.Date >= &DateParameter";
	
	QueryTextTemplateFirst = 
	"SELECT
	|	DocumentType.Ref AS Ref
	|INTO DocumentList
	|FROM
	|	&TableName AS DocumentType
	|WHERE
	|	DocumentType.Posted
	|	AND DocumentType.Company = &Company
	|	AND DocumentType.Date >= &DateParameter";
	
	DocTypeNumber = 1;
	
	While SelectionDetailRecords.Next() Do
		
		DocumentMetadata = Common.MetadataObjectByID(SelectionDetailRecords.DocumentType);
		
		PeriodParameterName = "Period" + DocTypeNumber;
		DocTypeNumber = DocTypeNumber + 1;
		Query.SetParameter(PeriodParameterName, SelectionDetailRecords.Period);
		
		TableName = StrTemplate("Document.%1", DocumentMetadata.Name);
		DateParameter = StrTemplate("&%1", PeriodParameterName); 
		
		CurrentQueryTextTemplate = StrReplace(QueryTextTemplate, "&TableName", TableName);
		CurrentQueryTextTemplate = StrReplace(CurrentQueryTextTemplate, "&DateParameter", DateParameter);
		
		CurrentQueryTextTemplateFirst = StrReplace(QueryTextTemplateFirst, "&TableName", TableName);
		CurrentQueryTextTemplateFirst = StrReplace(CurrentQueryTextTemplateFirst, "&DateParameter", DateParameter);
		
		QueryText = ?(QueryText = "",
			CurrentQueryTextTemplateFirst,
			QueryText + DriveClientServer.GetQueryUnion() + CurrentQueryTextTemplate);
			
	EndDo;
	
	QueryText = QueryText + ?(QueryText = "", "", DriveClientServer.GetQueryDelimeter()) +
	"SELECT
	|	DocumentList.Ref AS Ref
	|FROM
	|	DocumentList AS DocumentList
	|		LEFT JOIN Document.AccountingTransaction AS AccountingTransaction
	|		ON DocumentList.Ref = AccountingTransaction.BasisDocument
	|WHERE
	|	AccountingTransaction.Ref IS NULL";
	
	Query.Text = QueryText;
	Query.SetParameter("Company", Company);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	DocumentCount = 0;
	
	While SelectionDetailRecords.Next() Do
		
		TypesOfAccounting = New Array;
		TypesOfAccounting.Add(GenSettings.TypeOfAccounting);
		
		StructureAdditionalProperties = New Structure;
		StructureAdditionalProperties.Insert("Company", Company);
		StructureAdditionalProperties.Insert("Period", CurrentSessionDate());
		StructureAdditionalProperties.Insert("WriteMode", DocumentWriteMode.Posting);
		StructureAdditionalProperties.Insert("DeletionMark", False);
		StructureAdditionalProperties.Insert("TypesOfAccounting", TypesOfAccounting);
		
		CreateRefreshTransactionDocuments(SelectionDetailRecords.Ref, StructureAdditionalProperties);
		
		DocumentCount = DocumentCount + 1;
		
	EndDo;
	
	Comment = StrTemplate(NStr("en = 'Created: %1 documents
		|%2
		|%3
		|%4'; 
		|ru = 'Создано: %1 документы
		|%2
		|%3
		|%4';
		|pl = 'Utworzono: %1 dokumentów
		|%2
		|%3
		|%4';
		|es_ES = 'Creado:%1 documentos
		|%2
		|%3
		|%4';
		|es_CO = 'Creado:%1 documentos
		|%2
		|%3
		|%4';
		|tr = 'Oluşturuldu: %1 belge
		|%2
		|%3
		|%4';
		|it = 'Creato: %1 documenti 
		|%2
		|%3
		|%4';
		|de = 'Erstellt: %1 Dokumente
		|%2
		|%3
		|%4'"),
		DocumentCount,
		GenSettings.Company,
		GenSettings.TypeOfAccounting,
		GenSettings.Mode);
	
	WriteLogEvent(GetEventGroupVariant() + NStr("en = 'Documents posting'; ru = 'Проведение документов';pl = 'Zatwierdzenie dokumentów';es_ES = 'Contabilización de documentos';es_CO = 'Contabilización de documentos';tr = 'Belge kaydetme';it = 'Pubblicazione documenti';de = 'Buchen von Dokumenten'", CommonClientServer.DefaultLanguageCode()),
		,
		,
		,
		Comment);
	
EndProcedure

Procedure CreateRefreshTransactionDocument(DocumentRef, TypeOfAccounting, AccountingEntriesRecorder, ChartOfAccounts, ReflectDocumentAccountingEntriesStatuses = True, Cancel = False, UpdateRows = False) Export
	
	DocRefData = Common.ObjectAttributesValues(DocumentRef, "Company, Date");
	
	If DocumentRef = AccountingEntriesRecorder Then
		
		TransactionDocument = AccountingEntriesRecorder.GetObject();
		SetDocumentRecords(TransactionDocument, TransactionDocument.Ref, ReflectDocumentAccountingEntriesStatuses, Cancel);
		
	Else
		
		If ValueIsFilled(AccountingEntriesRecorder) Then
			
			TransactionDocument = AccountingEntriesRecorder.GetObject();
			
			If TransactionDocument.DeletionMark Then
				TransactionDocument.SetDeletionMark(False);
			EndIf;
			
		Else
			TransactionDocument = Documents.AccountingTransaction.CreateDocument();
		EndIf;
		
		FillStructure = New Structure;
		FillStructure.Insert("Company", DocRefData.Company);
		FillStructure.Insert("TypeOfAccounting", TypeOfAccounting);
		FillStructure.Insert("ChartOfAccounts", ChartOfAccounts);
		FillStructure.Insert("BasisDocument", DocumentRef);
		
		TransactionDocument.Fill(FillStructure);
		TransactionDocument.Date = DocRefData.Date;
		
		If Not ValueIsFilled(AccountingEntriesRecorder) Then
			AccountingEntriesRecorder = TransactionDocument.Ref;
		EndIf;
		
		SetDocumentRecords(TransactionDocument, TransactionDocument.BasisDocument, , Cancel, UpdateRows);
		
	EndIf;
	
EndProcedure

Procedure SetDocumentRecords(DocumentObject, BasisDocument, ReflectDocumentAccountingEntriesStatuses = True, Cancel = False, UpdateRows = False) Export
	
	TemplatesList = New Array;
	
	IsAccountingTransaction = (TypeOf(DocumentObject) = Type("DocumentObject.AccountingTransaction"));
	
	TypeOfAccounting = Undefined;
	If IsAccountingTransaction Then
		TypeOfAccounting = DocumentObject.TypeOfAccounting
	EndIf;
	
	UpdateDocument = IsAccountingTransaction And DocumentObject.Posted;
	
	AccountingEntriesTables = GetAccountingEntriesTablesStructure(
		BasisDocument,
		Cancel,
		TypeOfAccounting);
	
	If IsAccountingTransaction
		And DocumentObject.Posted
		And Cancel Then
		
		Return;
	EndIf;
	
	TableAccountingJournalEntries			= AccountingEntriesTables.TableAccountingJournalEntries;
	TableAccountingJournalEntriesCompound	= AccountingEntriesTables.TableAccountingJournalEntriesCompound;
	TableAccountingJournalEntriesSimple		= AccountingEntriesTables.TableAccountingJournalEntriesSimple;
	
	If Not Cancel And TableAccountingJournalEntries <> Undefined And Not IsAccountingTransaction Then
		
		DocumentObject.RegisterRecords.AccountingJournalEntries.Load(TableAccountingJournalEntries);
		DocumentObject.RegisterRecords.AccountingJournalEntries.Write = True;
		
		
	EndIf;
	
	If (Not Cancel Or IsAccountingTransaction) And TableAccountingJournalEntriesCompound <> Undefined Then
		
		DocumentObject.RegisterRecords.AccountingJournalEntriesCompound.Load(TableAccountingJournalEntriesCompound);
		DocumentObject.RegisterRecords.AccountingJournalEntriesCompound.Write = True;
		
		CommonClientServer.SupplementArray(TemplatesList, 
			TableAccountingJournalEntriesCompound.UnloadColumn("TransactionTemplate"),
			True);
		
	EndIf;
	
	If (Not Cancel Or IsAccountingTransaction) And TableAccountingJournalEntriesSimple <> Undefined Then
		
		DocumentObject.RegisterRecords.AccountingJournalEntriesSimple.Load(TableAccountingJournalEntriesSimple);
		DocumentObject.RegisterRecords.AccountingJournalEntriesSimple.Write = True;
		
		CommonClientServer.SupplementArray(TemplatesList,
			TableAccountingJournalEntriesSimple.UnloadColumn("TransactionTemplate"),
			True);
		
	EndIf;
	
	If IsAccountingTransaction Then
		
		CommonClientServer.SupplementTableFromArray(DocumentObject.Templates, TemplatesList, "Template");
		
		UpdateRows = True;
		
		If Cancel Then
			DocumentObject.Write();
			DocumentObject.RegisterRecords.Write();
		Else
			DocumentObject.Write(DocumentWriteMode.Posting);
		EndIf;
		
	EndIf;
	
	SetPrivilegedMode(True);
	DocumentObject.Write();
	SetPrivilegedMode(False);
	
	AccountingPolicy = New Structure();
	AccountingPolicy.Insert("AccountingModuleSettings", Constants.AccountingModuleSettings.Get());
	
	AdditionalProperties = New Structure;
	DriveServer.InitializeAdditionalPropertiesForPosting(BasisDocument, AdditionalProperties);
	InitializeAccountingTemplatesProperties(BasisDocument, AdditionalProperties, Cancel);
	
	AdditionalProperties.Insert("Modified"					, True);
	AdditionalProperties.Insert("TableForRegisterRecords"	, AccountingEntriesTables);
	AdditionalProperties.Insert("AccountingPolicy"			, AccountingPolicy);
	
	If ReflectDocumentAccountingEntriesStatuses Then
		DriveServer.ReflectDocumentAccountingEntriesStatuses(
			DocumentObject,
			AdditionalProperties,
			DocumentObject.RegisterRecords,
			False);
	EndIf;

EndProcedure

Function GetApplicableTypesOfAccounting(Company, Period, TypesOfAccountingArray, EntriesPostingOption = Undefined, AllPostingOptions = False) Export
	
	If EntriesPostingOption = Undefined Then
		EntriesPostingOption = Enums.AccountingEntriesRegisterOptions.SourceDocuments;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	CompaniesTypesOfAccounting.TypeOfAccounting AS TypeOfAccounting,
	|	CompaniesTypesOfAccounting.ChartOfAccounts AS ChartOfAccounts,
	|	CompaniesTypesOfAccounting.ChartOfAccounts.ChartOfAccounts AS ChartOfAccountsID
	|FROM
	|	InformationRegister.CompaniesTypesOfAccounting.SliceLast(&Period, Company = &Company) AS CompaniesTypesOfAccounting
	|WHERE
	|	(&AllPostingOptions
	|			OR CompaniesTypesOfAccounting.EntriesPostingOption = &EntriesPostingOption)
	|	AND (&AllTypesOfAccounting
	|			OR CompaniesTypesOfAccounting.TypeOfAccounting IN (&TypesOfAccountingArray))
	|	AND NOT CompaniesTypesOfAccounting.Inactive";
	
	Query.SetParameter("Company"				, Company);
	Query.SetParameter("Period"					, Period);
	Query.SetParameter("EntriesPostingOption"	, EntriesPostingOption);
	Query.SetParameter("AllPostingOptions"		, AllPostingOptions);
	Query.SetParameter("TypesOfAccountingArray"	, TypesOfAccountingArray);
	Query.SetParameter("AllTypesOfAccounting"	, TypesOfAccountingArray = Catalogs.TypesOfAccounting.EmptyRef());
	
	Return Query.Execute().Unload();
	
EndFunction

Function GetValuesArrayFromTable(InitTable, ColumnName) Export
	
	TempArray = InitTable.UnloadColumn(ColumnName);
	
	Return CommonClientServer.CollapseArray(TempArray);
	
EndFunction

Function GetEventGroupVariant() Export
	
	Return NStr("en = 'Accounting templates.'; ru = 'Шаблоны бухгалтерского учета.';pl = 'Szablony rachunkowości.';es_ES = 'Plantillas de contabilidad.';es_CO = 'Plantillas de contabilidad.';tr = 'Muhasebe şablonları.';it = 'Modelli di contabilità.';de = 'Buchungsvorlagen.'", CommonClientServer.DefaultLanguageCode()) + " ";
	
EndFunction

Procedure CheckForDuplicateAccountingEntries(DocumentRef, Company, Period, Cancel) Export
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	CompaniesTypesOfAccounting.TypeOfAccounting AS TypeOfAccounting
	|INTO CompaniesTypesOfAccounting
	|FROM
	|	InformationRegister.CompaniesTypesOfAccounting.SliceLast(&Period, Company = &Company) AS CompaniesTypesOfAccounting
	|WHERE
	|	NOT CompaniesTypesOfAccounting.Inactive
	|	AND CompaniesTypesOfAccounting.EntriesPostingOption = VALUE(Enum.AccountingEntriesRegisterOptions.SourceDocuments)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountingTransaction.Ref AS Ref,
	|	AccountingTransaction.TypeOfAccounting AS TypeOfAccounting
	|INTO TableRelatedAccountingTransactionDocvuments
	|FROM
	|	Document.AccountingTransaction AS AccountingTransaction
	|WHERE
	|	AccountingTransaction.Posted
	|	AND AccountingTransaction.BasisDocument = &DocumentRef
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CompaniesTypesOfAccounting.TypeOfAccounting AS TypeOfAccounting,
	|	TableRelatedAccountingTransactionDocvuments.Ref AS AccountingTransaction
	|FROM
	|	CompaniesTypesOfAccounting AS CompaniesTypesOfAccounting
	|		INNER JOIN TableRelatedAccountingTransactionDocvuments AS TableRelatedAccountingTransactionDocvuments
	|		ON CompaniesTypesOfAccounting.TypeOfAccounting = TableRelatedAccountingTransactionDocvuments.TypeOfAccounting";
	
	Query.SetParameter("DocumentRef", DocumentRef);
	Query.SetParameter("Company"	, Company);
	Query.SetParameter("Period"		, Period);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
		ErrorMessageTemplate = NStr(
			"en = 'For this document, for ""%1"", ""%2"" already recorded accounting entries. They are now inapplicable because on %3 a source document must record accounting entries. To record accounting entries for ""%1"", unpost ""%2"". Then post this document.'; ru = 'Для этого документа для ""%1"", ""%2"" уже сделаны бухгалтерские проводки. Теперь они неприменимы, поскольку на %3 бухгалтерские проводки должен делать первичный документ. Чтобы сделать бухгалтерские проводки для ""%1"", отмените проведение ""%2"" и проведите данный документ.';pl = 'Dla tego dokumentu, dla ""%1"", ""%2"" są już zapisane wpisy księgowe. Obecnie nie mają zastosowania, ponieważ w %3 dokumencie źródłowym powinny być zapisane wpisy księgowe. Aby zapisać wpisy księgowe dla ""%1"", anuluj zatwierdzenie ""%2"". Następnie zatwierdź ten dokument.';es_ES = 'En este documento, para ""%1"", ""%2"" ya se registraron entradas contables. Ahora son inaplicables porque en %3 un documento de fuente deben registrarse entradas contables. Para registrar entradas contables para ""%1"", sin enviar ""%2"". Luego contabiliza este documento.';es_CO = 'En este documento, para ""%1"", ""%2"" ya se registraron entradas contables. Ahora son inaplicables porque en %3 un documento de fuente deben registrarse entradas contables. Para registrar entradas contables para ""%1"", sin enviar ""%2"". Luego contabiliza este documento.';tr = 'Bu belgede ""%1"" için ""%2"" muhasebe girişleri kaydetti. Bunlar uygulanamaz çünkü %3''de muhasebe girişlerini kaynak belge kaydetmelidir. ""%1"" için muhasebe girişleri kaydetmek için ""%2"" kaydını silip bu belgeyi yeniden kaydedin.';it = 'Per questo documento, per ""%1"" e ""%2"" sono già registrate le voci di contabilità. Adesso non sono applicabili, poiché su %3 un documento fonte deve registrare le voci di contabilità. Per registrare le voci di contabilità per ""%1"", non pubblicare ""%2"". Poi pubblicare questo documento.';de = 'Für dieses Dokument, hat ""%2"" für ""%1"", bereits Buchungen eingetragen. Sie sind jetzt nicht verwendbar, denn auf %3 ein Quelldokument muss Eintrag von Buchungen enthalten. Um die Buchungen für ""%1"" zu speichern, heben Sie Buchung ""%2"" auf. Dann buchen Sie dieses Dokument.'");
		
		ErrorMessage = ErrorTitle + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
			ErrorMessageTemplate,
			Selection.TypeOfAccounting,
			Selection.AccountingTransaction,
			Format(Period, "DLF=D; DE=..."));
		
		CommonClientServer.MessageToUser(ErrorMessage, Selection.AccountingTransaction, , , Cancel);
		
	EndDo;
	
EndProcedure

Procedure CheckTransactionsFilling(Object, TypesOfAccountingTable, Cancel, UpdateDocument = False) Export
	
	EntriesTable = New ValueTable;
	EntriesTable.Columns.Add("Period"			, New TypeDescription("Date"));
	EntriesTable.Columns.Add("Account"			, New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts"));
	EntriesTable.Columns.Add("RecordType"		, New TypeDescription("AccountingRecordType"));
	EntriesTable.Columns.Add("Amount"			, New TypeDescription("Number"));
	EntriesTable.Columns.Add("EntryNumber"		, New TypeDescription("Number"));
	EntriesTable.Columns.Add("LineNumber"		, New TypeDescription("Number"));
	EntriesTable.Columns.Add("ChartOfAccounts"	, New TypeDescription("CatalogRef.ChartsOfAccounts"));
	EntriesTable.Columns.Add("TypeOfAccounting"	, New TypeDescription("CatalogRef.TypesOfAccounting"));
	EntriesTable.Columns.Add("Compound"			, New TypeDescription("Boolean"));
	
	Ref			= Object.Ref;
	Date		= Object.Date;
	Company		= Object.Company;
	
	If TypeOf(Ref) = Type("DocumentRef.AccountingTransaction") Then
		
		BasisDocument			= Object.BasisDocument;
		BasisDocumentExist		= ValueIsFilled(BasisDocument);
		CheckSourceDocument		= BasisDocumentExist;
		BaseDocumentMetadata	= ?(BasisDocumentExist, BasisDocument.Metadata(), Ref.Metadata());
		
		If BasisDocumentExist Then
			BasisDocumentData	= Common.ObjectAttributesValues(BasisDocument, "Date");
			Date				= BasisDocumentData.Date;
		EndIf;
		
	Else
		
		CheckSourceDocument	= True;
		BaseDocumentMetadata= Ref.Metadata();
		
	EndIf;
	
	PresentationCurrency	= DriveServer.GetPresentationCurrency(Company);
	BaseDocumentMetadataID	= Common.MetadataObjectID(BaseDocumentMetadata);
	
	FieldsListEntryCompound = "Period, LineNumber, EntryNumber, Account, RecordType, Amount";
	FieldsListEntrySimple	= "Period, LineNumber, Amount";
	FieldsListRow			= "ChartOfAccounts, TypeOfAccounting";
	
	For Each Row In TypesOfAccountingTable Do
		
		ChartOfAccountsData = Common.ObjectAttributesValues(Row.ChartOfAccounts, "TypeOfEntries");
		
		If ChartOfAccountsData.TypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Compound Then
			
			For Each EntryRow In Row.Entries Do
				
				NewRow = EntriesTable.Add();
				
				FillPropertyValues(NewRow, EntryRow, FieldsListEntryCompound);
				FillPropertyValues(NewRow, Row, FieldsListRow);
				
				NewRow.Compound = True;
				
			EndDo;
			
		Else
			
			For Each EntryRow In Row.Entries Do
				
				NewRow = EntriesTable.Add();
				
				FillPropertyValues(NewRow, EntryRow, FieldsListEntrySimple);
				FillPropertyValues(NewRow, Row, FieldsListRow);
				
				NewRow.EntryNumber	= EntryRow.LineNumber;
				NewRow.Account		= EntryRow.AccountDr;
				NewRow.RecordType	= AccountingRecordType.Debit;
				NewRow.Compound		= False;
				
				NewRow = EntriesTable.Add();
				
				FillPropertyValues(NewRow, EntryRow, FieldsListEntrySimple);
				FillPropertyValues(NewRow, Row, FieldsListRow);
				
				NewRow.EntryNumber	= EntryRow.LineNumber;
				NewRow.Account		= EntryRow.AccountCr;
				NewRow.RecordType	= AccountingRecordType.Credit;
				NewRow.Compound		= False;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	EntriesTable.Period AS Period,
	|	EntriesTable.EntryNumber AS EntryNumber,
	|	EntriesTable.LineNumber AS LineNumber,
	|	EntriesTable.RecordType AS RecordType,
	|	EntriesTable.Account AS Account,
	|	&Company AS Company,
	|	EntriesTable.Amount AS Amount,
	|	EntriesTable.ChartOfAccounts AS ChartOfAccountsEntries,
	|	EntriesTable.TypeOfAccounting AS TypeOfAccounting,
	|	EntriesTable.Compound AS Compound
	|INTO ExternalEntriesTable
	|FROM
	|	&EntriesTable AS EntriesTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EntriesTable.Period AS Period,
	|	EntriesTable.EntryNumber AS EntryNumber,
	|	EntriesTable.LineNumber AS LineNumber,
	|	EntriesTable.RecordType AS RecordType,
	|	EntriesTable.Account AS Account,
	|	EntriesTable.Company AS Company,
	|	EntriesTable.Amount AS Amount,
	|	EntriesTable.ChartOfAccountsEntries AS ChartOfAccountsEntries,
	|	EntriesTable.TypeOfAccounting AS TypeOfAccounting,
	|	EntriesTable.Compound AS Compound,
	|	MasterChartOfAccounts.ChartOfAccounts AS ChartOfAccountsAccount
	|INTO MasterAccountingEntries
	|FROM
	|	ExternalEntriesTable AS EntriesTable
	|		LEFT JOIN ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
	|		ON EntriesTable.Account = MasterChartOfAccounts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MasterChartOfAccountsCompanies.Ref AS Account,
	|	MasterChartOfAccountsCompanies.Ref.Presentation AS Presentation,
	|	MasterAccountingEntries.Period AS Period,
	|	MasterAccountingEntries.EntryNumber AS EntryNumber,
	|	MasterAccountingEntries.LineNumber AS LineNumber,
	|	MasterAccountingEntries.RecordType AS RecordType,
	|	MasterChartOfAccountsCompanies.StartDate AS StartDate,
	|	MasterChartOfAccountsCompanies.EndDate AS EndDate,
	|	NOT(MasterAccountingEntries.Period >= MasterChartOfAccountsCompanies.StartDate
	|			AND NOT(MasterChartOfAccountsCompanies.EndDate <> DATETIME(1, 1, 1)
	|					AND MasterAccountingEntries.Period > MasterChartOfAccountsCompanies.EndDate)) AS DateError,
	|	MasterAccountingEntries.ChartOfAccountsAccount <> MasterAccountingEntries.ChartOfAccountsEntries AS OwnerError,
	|	MasterAccountingEntries.ChartOfAccountsEntries AS ChartOfAccountsEntries,
	|	MasterAccountingEntries.Compound AS Compound
	|INTO AccountsTableUngrouped
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts.Companies AS MasterChartOfAccountsCompanies
	|		INNER JOIN MasterAccountingEntries AS MasterAccountingEntries
	|		ON (MasterChartOfAccountsCompanies.Company = &Company)
	|			AND MasterChartOfAccountsCompanies.Ref = MasterAccountingEntries.Account
	|
	|UNION ALL
	|
	|SELECT
	|	MasterChartOfAccounts.Ref,
	|	MasterChartOfAccounts.Ref.Presentation,
	|	MasterAccountingEntries.Period,
	|	MasterAccountingEntries.EntryNumber,
	|	MasterAccountingEntries.LineNumber,
	|	MasterAccountingEntries.RecordType,
	|	MasterChartOfAccounts.StartDate,
	|	MasterChartOfAccounts.EndDate,
	|	NOT(MasterAccountingEntries.Period >= MasterChartOfAccounts.StartDate
	|			AND NOT(MasterChartOfAccounts.EndDate <> DATETIME(1, 1, 1)
	|					AND MasterAccountingEntries.Period > MasterChartOfAccounts.EndDate)),
	|	MasterAccountingEntries.ChartOfAccountsAccount <> MasterAccountingEntries.ChartOfAccountsEntries,
	|	MasterAccountingEntries.ChartOfAccountsEntries,
	|	MasterAccountingEntries.Compound
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
	|		INNER JOIN MasterAccountingEntries AS MasterAccountingEntries
	|		ON MasterChartOfAccounts.Ref = MasterAccountingEntries.Account
	|		LEFT JOIN ChartOfAccounts.MasterChartOfAccounts.Companies AS MasterChartOfAccountsCompanies
	|		ON MasterChartOfAccounts.Ref = MasterChartOfAccountsCompanies.Ref
	|WHERE
	|	MasterChartOfAccountsCompanies.Ref IS NULL
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	MasterAccountingEntries.TypeOfAccounting AS TypeOfAccounting
	|INTO TableTypesOfAccounting
	|FROM
	|	MasterAccountingEntries AS MasterAccountingEntries
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsTableUngrouped.Account AS Account,
	|	AccountsTableUngrouped.Presentation AS Presentation,
	|	AccountsTableUngrouped.Period AS Period,
	|	AccountsTableUngrouped.EntryNumber AS EntryNumber,
	|	AccountsTableUngrouped.LineNumber AS LineNumber,
	|	AccountsTableUngrouped.RecordType AS RecordType,
	|	AccountsTableUngrouped.StartDate AS StartDate,
	|	AccountsTableUngrouped.EndDate AS EndDate,
	|	MAX(AccountsTableUngrouped.DateError) AS DateError,
	|	MAX(AccountsTableUngrouped.OwnerError) AS OwnerError,
	|	AccountsTableUngrouped.ChartOfAccountsEntries AS ChartOfAccountsEntries,
	|	AccountsTableUngrouped.Compound AS Compound
	|FROM
	|	AccountsTableUngrouped AS AccountsTableUngrouped
	|WHERE
	|	(AccountsTableUngrouped.DateError
	|			OR AccountsTableUngrouped.OwnerError)
	|
	|GROUP BY
	|	AccountsTableUngrouped.Account,
	|	AccountsTableUngrouped.Presentation,
	|	AccountsTableUngrouped.EntryNumber,
	|	AccountsTableUngrouped.LineNumber,
	|	AccountsTableUngrouped.RecordType,
	|	AccountsTableUngrouped.StartDate,
	|	AccountsTableUngrouped.EndDate,
	|	AccountsTableUngrouped.Period,
	|	AccountsTableUngrouped.ChartOfAccountsEntries,
	|	AccountsTableUngrouped.Compound
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(CompaniesTypesOfAccountingSliceLast.EndDate = DATETIME(1, 1, 1), FALSE) AS IsApplicable,
	|	ISNULL(CompaniesTypesOfAccountingSliceLast.EntriesPostingOption = VALUE(Enum.AccountingEntriesRegisterOptions.AccountingTransactionDocument), FALSE) AS IsAccountingTransactionAsSourceDocument,
	|	TableTypesOfAccounting.TypeOfAccounting AS TypeOfAccounting
	|FROM
	|	TableTypesOfAccounting AS TableTypesOfAccounting
	|		LEFT JOIN InformationRegister.CompaniesTypesOfAccounting.SliceLast(&DocumentDate, Company = &Company) AS CompaniesTypesOfAccountingSliceLast
	|		ON TableTypesOfAccounting.TypeOfAccounting = CompaniesTypesOfAccountingSliceLast.TypeOfAccounting
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(CASE
	|			WHEN MasterAccountingEntries.RecordType = VALUE(AccountingRecordType.Debit)
	|				THEN MasterAccountingEntries.Amount
	|			ELSE 0
	|		END) AS AmountDr,
	|	SUM(CASE
	|			WHEN MasterAccountingEntries.RecordType = VALUE(AccountingRecordType.Credit)
	|				THEN MasterAccountingEntries.Amount
	|			ELSE 0
	|		END) AS AmountCr,
	|	MasterAccountingEntries.EntryNumber AS EntryNumber
	|FROM
	|	MasterAccountingEntries AS MasterAccountingEntries
	|
	|GROUP BY
	|	MasterAccountingEntries.EntryNumber
	|
	|HAVING
	|	SUM(CASE
	|			WHEN MasterAccountingEntries.RecordType = VALUE(AccountingRecordType.Debit)
	|				THEN MasterAccountingEntries.Amount
	|			ELSE 0
	|		END) <> SUM(CASE
	|			WHEN MasterAccountingEntries.RecordType = VALUE(AccountingRecordType.Credit)
	|				THEN MasterAccountingEntries.Amount
	|			ELSE 0
	|		END)";
	
	If CheckSourceDocument Then
		
		QueryText = 
		"SELECT
		|	ISNULL(AccountingSourceDocumentsSliceLast.Uses, FALSE) AS Uses,
		|	TableTypesOfAccounting.TypeOfAccounting AS TypeOfAccounting
		|FROM
		|	TableTypesOfAccounting AS TableTypesOfAccounting
		|		LEFT JOIN InformationRegister.AccountingSourceDocuments.SliceLast(
		|				&DocumentDate,
		|				Company = &Company
		|					AND DocumentType = &DocumentType) AS AccountingSourceDocumentsSliceLast
		|		ON TableTypesOfAccounting.TypeOfAccounting = AccountingSourceDocumentsSliceLast.TypeOfAccounting";
		
		Query.Text = Query.Text + Common.QueryBatchSeparator() + QueryText;
		
	EndIf;
	
	Query.SetParameter("Company"		, Company);
	Query.SetParameter("EntriesTable"	, EntriesTable);
	Query.SetParameter("DocumentType"	, BaseDocumentMetadataID);
	Query.SetParameter("DocumentDate"	, Date);
	
	QueryResult = Query.ExecuteBatch();
	
	InapplicableChartsOfAccounts	= QueryResult[4].Unload();
	TypeOfAccountingChecksTable		= QueryResult[5].Unload();
	DebitCreditDifference			= QueryResult[6].Unload();
	
	Errors = New Array;
	
	For Each Row In DebitCreditDifference Do
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		MessagesToUserClientServer.GetCheckTransactionsFillingDebitCreditDifferenceErrorText(),
		Row.EntryNumber,
		Row.AmountDr,
		PresentationCurrency,
		Row.AmountCr);
		
		Errors.Add(MessageText);
		
	EndDo;
	
	
	MetadataPresentation	= BaseDocumentMetadata.Presentation();
	IsAccountingTransaction	= (TypeOf(Ref) = Type("DocumentRef.AccountingTransaction"));
	
	For Each Row In TypeOfAccountingChecksTable Do
		
		IsAccountingTransactionAsSourceDocument = (Not CheckSourceDocument Or Row.IsAccountingTransactionAsSourceDocument);
		If IsAccountingTransaction And Not IsAccountingTransactionAsSourceDocument Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				MessagesToUserClientServer.GetCheckTransactionsFillingEntriesPostedErrorText(),
				Format(Date, "DLF=D"),
				Row.TypeOfAccounting,
				MetadataPresentation);
			
			Errors.Add(MessageText);
			
		EndIf;
		
		
		If Not Row.IsApplicable Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				MessagesToUserClientServer.GetCheckTransactionsFillingIsApplicableErrorText(),
				Row.TypeOfAccounting,
				Company,
				Format(Date, "DLF=D"));
			
			Errors.Add(MessageText);
			
		EndIf;
		
	EndDo;
	
	If CheckSourceDocument Then
		
		SourceDocuments = QueryResult[7].Unload();
		
		For Each Row In SourceDocuments Do
			
			If Not Row.Uses Then
					
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					MessagesToUserClientServer.GetCheckTransactionsFillingSourceDocumentErrorText(),
					Format(Date, "DLF=D"),
					BaseDocumentMetadata.Presentation(),
					Row.TypeOfAccounting);
					
				Errors.Add(MessageText);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	For Each ChartOfAccountRow In InapplicableChartsOfAccounts Do
		
		StartDatePresentation = Format(ChartOfAccountRow.StartDate, "DLF=D; DE=...");

		EndDatePresentation = Format(ChartOfAccountRow.EndDate, "DLF=D; DE=...");
		
		If ChartOfAccountRow.RecordType = AccountingRecordType.Debit Then
			RecordTypePresentation = NStr("en = 'debit'; ru = 'дебет';pl = 'zobowiązania';es_ES = 'débito';es_CO = 'débito';tr = 'borç';it = 'debito';de = 'Soll'");
		Else
			RecordTypePresentation = NStr("en = 'credit'; ru = 'кредит';pl = 'należności';es_ES = 'crédito';es_CO = 'crédito';tr = 'alacak';it = 'credito';de = 'Haben'");
		EndIf;
		
		If ChartOfAccountRow.DateError Then
				
			If ChartOfAccountRow.Compound Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					MessagesToUserClientServer.GetCheckTransactionsFillingDateErrorText(True),
					ChartOfAccountRow.EntryNumber,
					ChartOfAccountRow.LineNumber,
					StartDatePresentation,
					EndDatePresentation);
			Else
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					MessagesToUserClientServer.GetCheckTransactionsFillingDateErrorText(False),
					ChartOfAccountRow.LineNumber,
					RecordTypePresentation,
					StartDatePresentation,
					EndDatePresentation);
			EndIf;
		EndIf;
		
		If ChartOfAccountRow.OwnerError Then
			
			If ChartOfAccountRow.Compound Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					MessagesToUserClientServer.GetCheckTransactionsFillingOwnerErrorText(True),
					ChartOfAccountRow.EntryNumber,
					ChartOfAccountRow.LineNumber,
					ChartOfAccountRow.ChartOfAccountsEntries);
			Else
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					MessagesToUserClientServer.GetCheckTransactionsFillingOwnerErrorText(False),
					ChartOfAccountRow.LineNumber,
					RecordTypePresentation,
					ChartOfAccountRow.ChartOfAccountsEntries);
			EndIf;
			
		EndIf;
		
		Errors.Add(MessageText);
		
	EndDo;
	
	If Errors.Count() > 0 Then
		
		MessageText = MessagesToUserClientServer.GetPostingErrorText();
		
		CommonClientServer.MessageToUser(MessageText, , , , Cancel);
		
		For Each MessageText In Errors Do
			CommonClientServer.MessageToUser(MessageText, , , , Cancel);
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

#Region QueryTexts

Function DocumentPostingQueryText(StructureAdditionalProperties, EntriesTable, QueryParametersMap, IsMasterAccounting, AdditionalQueryParameters)
	
	Var GroupedFilters, FiltersConnectionTable, DataSourcesTable; 
	
	CurrentDocMetadata	= StructureAdditionalProperties.ForPosting.DocumentMetadata;
	ApplicableTemplates	= CommonClientServer.CollapseArray(EntriesTable.UnloadColumn("TransactionTemplate"));
	
	FilterValuesTable	= GetFilterValuesTable(ApplicableTemplates, "EntriesFilters");
	FiltersTable		= GetFiltersTable(ApplicableTemplates, FilterValuesTable);
	
	GroupFiltersConditions(FiltersTable, QueryParametersMap, GroupedFilters, FiltersConnectionTable);
		
	FillDataSourcesTable(DataSourcesTable, EntriesTable, QueryParametersMap, StructureAdditionalProperties, IsMasterAccounting);

	// Tempopary tables by data sources
	TempTables = New ValueList;
	AccountingPostingQueryText = "";
	
	For Each DataSourceRow In DataSourcesTable Do
			
		If TempTables.FindByValue(DataSourceRow.TempTableName) <> Undefined Then
			Continue;
		EndIf;
		
		TempTables.Add(DataSourceRow.TempTableName);
			
		If DataSourceRow.TableSource = "AccumulationRegister" Then
			
			CurrentRowText = RegisterRecordsTempTableQueryText(DataSourceRow);
			
		ElsIf DataSourceRow.TableSource = "TabularSections" Then
			
			CurrentRowText = TabularSectionTempTableQueryText(DataSourceRow, CurrentDocMetadata);
			
		ElsIf DataSourceRow.TableSource = "AccountingEntriesData" Then
			
			CurrentRowText = AccountingEntriesDataTempTableQueryText(DataSourceRow);
			
		EndIf;
		
		AccountingPostingQueryText = AccountingPostingQueryText + CurrentRowText + DriveClientServer.GetQueryDelimeter();
	
	EndDo;
	
	// Add filtered tables
	For Each Filter In GroupedFilters Do
		
		ConnectStructure = New Structure("DataSource", Filter.DataSource);
		
		DataSourcesRows = DataSourcesTable.FindRows(ConnectStructure);
		If DataSourcesRows.Count() = 0 Then
			Continue;
		EndIf;
		
		DataSourceRow = DataSourcesRows[0];
		
		AccountingPostingQueryText = AccountingPostingQueryText
			+ TabularSectionTempTableFilteredQueryText(DataSourceRow, Filter, CurrentDocMetadata.Name)
			+ DriveClientServer.GetQueryDelimeter();
	
	EndDo;
	
	DefaultAccountsText			= "";
	SimplePostingQueryText		= "";
	CompoundPostingQueryText	= "";
	
	DefaultAccountsTable = GetDefaultAccountsTable(EntriesTable);

	FirstDefaultAccount	= True;
	EntryIndex			= 1;
	
	For Each Entry In EntriesTable Do
		
		Entry.RowID = EntryIndex;
		
		DefAccountsFieldTextArray = DefaultAccountsFieldTextArray(Entry, DefaultAccountsTable);
		
		ConnectStructure = New Structure("TemplateRef, EntryConnectionKey", Entry.Ref, Entry.ConnectionKey);
			
		DataSourceRows	= DataSourcesTable.FindRows(ConnectStructure);
		FilterRows		= FiltersConnectionTable.FindRows(ConnectStructure);
		
		If DataSourceRows.Count() > 0 And FilterRows.Count() > 0 Then
				
			CurrentEntryQueryText = ?(IsMasterAccounting,
					MasterAccountingEntryQueryText(Entry, EntryIndex, DataSourceRows[0], CurrentDocMetadata.Name, FilterRows[0].QueryTempTableID, DefaultAccountsTable, AdditionalQueryParameters),
					PrimaryAccountingEntryQueryText(Entry, EntryIndex, DataSourceRows[0], CurrentDocMetadata.Name, FilterRows[0].QueryTempTableID, DefaultAccountsTable));
				
			For Each DefAccountField In DefAccountsFieldTextArray Do
				
				DefaultAccountsText = DefaultAccountsText 
					+ ?(FirstDefaultAccount, "", DriveClientServer.GetQueryUnion()) 
					+ ?(IsMasterAccounting,
						MasterAccountingDefaultAccountsQueryText(FirstDefaultAccount,
							Entry,
							EntryIndex,
							DataSourceRows[0],
							CurrentDocMetadata.Name,
							FilterRows[0].QueryTempTableID,
							DefAccountField),
						PrimaryAccountingDefaultAccountsQueryText(FirstDefaultAccount,
							Entry,
							EntryIndex,
							DataSourceRows[0],
							CurrentDocMetadata.Name,
							FilterRows[0].QueryTempTableID,
							DefAccountField));
							
				FirstDefaultAccount = False;
				
			EndDo;	
				
		ElsIf DataSourceRows.Count() > 0 Then
			// This entry have no filters for it
			
			CurrentEntryQueryText = ?(IsMasterAccounting,
					MasterAccountingEntryQueryText(
						Entry,
						EntryIndex,
						DataSourceRows[0],
						CurrentDocMetadata.Name,
						-1,
						DefaultAccountsTable,
						AdditionalQueryParameters),
					PrimaryAccountingEntryQueryText(
						Entry,
						EntryIndex,
						DataSourceRows[0],
						CurrentDocMetadata.Name,
						-1,
						DefaultAccountsTable));
				
			For Each DefAccountField In DefAccountsFieldTextArray Do
				
				DefaultAccountsText = DefaultAccountsText 
					+ ?(FirstDefaultAccount, "", DriveClientServer.GetQueryUnion()) 
					+ ?(IsMasterAccounting,
						MasterAccountingDefaultAccountsQueryText(
							FirstDefaultAccount,
							Entry,
							EntryIndex,
							DataSourceRows[0],
							CurrentDocMetadata.Name,
							-1,
							DefAccountField),
						PrimaryAccountingDefaultAccountsQueryText(
							FirstDefaultAccount,
							Entry,
							EntryIndex,
							DataSourceRows[0],
							CurrentDocMetadata.Name,
							-1,
							DefAccountField));
					
				FirstDefaultAccount = False;
				
			EndDo;
		
		Else
			// Empty data source, all data from doc attributes
			If FilterRows.Count() > 0 Then
				ConnectStructure = New Structure("QueryTempTableID", FilterRows[0].QueryTempTableID);
				CondRow = GroupedFilters.FindRows(ConnectStructure)[0];
				ConditionText = CondRow.ConditionText;
				QueryTempTableID = ConnectStructure.QueryTempTableID;
			Else
				ConditionText = "";
				QueryTempTableID = -1;
			EndIf;
			
			CurrentEntryQueryText = ?(IsMasterAccounting,
					MasterAccountingEntryEmptyDataSourceQueryText(
						Entry,
						EntryIndex,
						CurrentDocMetadata.Name,
						ConditionText,
						DefaultAccountsTable,
						AdditionalQueryParameters),
					PrimaryAccountingEntryEmptyDataSourceQueryText(
						Entry,
						EntryIndex,
						CurrentDocMetadata.Name,
						ConditionText,
						DefaultAccountsTable));
			
			For Each DefAccountField In DefAccountsFieldTextArray Do
				
				DefaultAccountsText = DefaultAccountsText 
					+ ?(FirstDefaultAccount, "", DriveClientServer.GetQueryUnion()) 
					+ DefaultAccountsEmptyDataSourceQueryText(
							IsMasterAccounting,
							FirstDefaultAccount,
							Entry,
							EntryIndex,
							CurrentDocMetadata.Name,
							QueryTempTableID,
							DefAccountField);
					
				FirstDefaultAccount = False;
				
			EndDo;
			
		EndIf;
		
		If Entry.TypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Simple Then
			
			If ValueIsFilled(SimplePostingQueryText) Then
				SimplePostingQueryText = SimplePostingQueryText + DriveClientServer.GetQueryUnion();
			EndIf;
			
			SimplePostingQueryText = SimplePostingQueryText + CurrentEntryQueryText;
			
		Else
			If ValueIsFilled(CompoundPostingQueryText) Then
				CompoundPostingQueryText = CompoundPostingQueryText + DriveClientServer.GetQueryUnion();
			EndIf;
			
			CompoundPostingQueryText = CompoundPostingQueryText + CurrentEntryQueryText;
			
		EndIf;
		
		EntryIndex = EntryIndex + 1;
		
	EndDo;
	
	If Not ValueIsFilled(DefaultAccountsText) Then
		DefaultAccountsText = GetEmptyDefaultAccountsText();
	Else
		DefaultAccountsText = DefaultAccountsText
			+ DriveClientServer.GetQueryDelimeter()
			+ GetDefaultAccountsText(IsMasterAccounting);
	EndIf;
		
	AccountingPostingQueryText = AccountingPostingQueryText + DefaultAccountsText; 
		
	If Not ValueIsFilled(SimplePostingQueryText) Then
		SimplePostingQueryText = SimpleRegisterEmptyTableQueryText();
	EndIf;
	
	AccountingPostingQueryText = AccountingPostingQueryText 
		+ DriveClientServer.GetQueryDelimeter()
		+ SimplePostingQueryText
		+ GetQueryOrderText();
	
	If Not ValueIsFilled(CompoundPostingQueryText) Then
		CompoundPostingQueryText = CompoundRegisterEmptyTableQueryText();
	EndIf;
	
	AccountingPostingQueryText = AccountingPostingQueryText 
		+ DriveClientServer.GetQueryDelimeter()
		+ CompoundPostingQueryText
		+ GetQueryOrderText();
	
	Return AccountingPostingQueryText;
	
EndFunction

Function GetEmptyDefaultAccountsText()
	Return
	"SELECT TOP 0
	|	VALUE(Catalog.DefaultAccountsTypes.EmptyRef) AS DefaultAccountType,
	|	"""" AS AccountReferenceName,
	|	VALUE(Enum.DebitCredit.EmptyRef) AS DrCr,
	|	0 AS ConnectionKey,
	|	Undefined AS Filter1,
	|	Undefined AS Filter2,
	|	Undefined AS Filter3,
	|	Undefined AS Filter4,
	|	Undefined AS Account";
	
EndFunction

Function GetDefaultAccountsText(IsMasterAccounting)
	
	QueryText =
	"SELECT
	|	DefaultAccountsFilters.DefaultAccountType AS DefaultAccountType,
	|	DefaultAccountsFilters.AccountReferenceName AS AccountReferenceName,
	|	DefaultAccountsFilters.DrCr AS DrCr,
	|	DefaultAccountsFilters.ConnectionKey AS ConnectionKey,
	|	DefaultAccountsFilters.Filter1 AS Filter1,
	|	DefaultAccountsFilters.Filter2 AS Filter2,
	|	DefaultAccountsFilters.Filter3 AS Filter3,
	|	DefaultAccountsFilters.Filter4 AS Filter4,
	|	DefaultAccounts.Account AS Account
	|INTO Step0
	|FROM
	|	DefaultAccountsFilters AS DefaultAccountsFilters
	|		LEFT JOIN InformationRegister.DefaultAccounts AS DefaultAccounts
	|		ON DefaultAccountsFilters.DefaultAccountType = DefaultAccounts.DefaultAccountType
	|			AND DefaultAccountsFilters.Filter1 = DefaultAccounts.Filter1
	|			AND (DefaultAccounts.Filter1 <> UNDEFINED)
	|			AND DefaultAccountsFilters.Filter2 = DefaultAccounts.Filter2
	|			AND (DefaultAccounts.Filter2 <> UNDEFINED)
	|			AND DefaultAccountsFilters.Filter3 = DefaultAccounts.Filter3
	|			AND (DefaultAccounts.Filter3 <> UNDEFINED)
	|			AND DefaultAccountsFilters.Filter4 = DefaultAccounts.Filter4
	|			AND (DefaultAccounts.Filter4 <> UNDEFINED)
	|			AND DefaultAccountsFilters.AccountReferenceName = DefaultAccounts.AccountReferenceName
	|
	|INDEX BY
	|	DefaultAccountType,
	|	Filter1,
	|	Filter2,
	|	Filter3,
	|	Filter4,
	|	AccountReferenceName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Step0.DefaultAccountType AS DefaultAccountType,
	|	Step0.AccountReferenceName AS AccountReferenceName,
	|	Step0.DrCr AS DrCr,
	|	Step0.ConnectionKey AS ConnectionKey,
	|	Step0.Filter1 AS Filter1,
	|	Step0.Filter2 AS Filter2,
	|	Step0.Filter3 AS Filter3,
	|	Step0.Filter4 AS Filter4,
	|	DefaultAccounts.Account AS Account
	|INTO Step1
	|FROM
	|	Step0 AS Step0
	|		LEFT JOIN InformationRegister.DefaultAccounts AS DefaultAccounts
	|		ON Step0.DefaultAccountType = DefaultAccounts.DefaultAccountType
	|			AND Step0.Filter1 = DefaultAccounts.Filter1
	|			AND (DefaultAccounts.Filter1 <> UNDEFINED)
	|			AND Step0.Filter2 = DefaultAccounts.Filter2
	|			AND (DefaultAccounts.Filter2 <> UNDEFINED)
	|			AND Step0.Filter3 = DefaultAccounts.Filter3
	|			AND (DefaultAccounts.Filter3 <> UNDEFINED)
	|			AND (DefaultAccounts.Filter4 <> UNDEFINED)
	|			AND Step0.AccountReferenceName = DefaultAccounts.AccountReferenceName
	|WHERE
	|	Step0.Account IS NULL
	|
	|INDEX BY
	|	DefaultAccountType,
	|	Filter1,
	|	Filter2,
	|	Filter3,
	|	Filter4,
	|	AccountReferenceName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Step1.DefaultAccountType AS DefaultAccountType,
	|	Step1.AccountReferenceName AS AccountReferenceName,
	|	Step1.DrCr AS DrCr,
	|	Step1.ConnectionKey AS ConnectionKey,
	|	Step1.Filter1 AS Filter1,
	|	Step1.Filter2 AS Filter2,
	|	Step1.Filter3 AS Filter3,
	|	Step1.Filter4 AS Filter4,
	|	DefaultAccounts.Account AS Account
	|INTO Step2
	|FROM
	|	Step1 AS Step1
	|		LEFT JOIN InformationRegister.DefaultAccounts AS DefaultAccounts
	|		ON Step1.DefaultAccountType = DefaultAccounts.DefaultAccountType
	|			AND Step1.Filter1 = DefaultAccounts.Filter1
	|			AND (DefaultAccounts.Filter1 <> UNDEFINED)
	|			AND Step1.Filter2 = DefaultAccounts.Filter2
	|			AND (DefaultAccounts.Filter2 <> UNDEFINED)
	|			AND Step1.Filter3 = DefaultAccounts.Filter3
	|			AND (DefaultAccounts.Filter3 <> UNDEFINED)
	|			AND (DefaultAccounts.Filter4 = UNDEFINED)
	|			AND Step1.AccountReferenceName = DefaultAccounts.AccountReferenceName
	|WHERE
	|	Step1.Account IS NULL
	|
	|INDEX BY
	|	DefaultAccountType,
	|	Filter1,
	|	Filter2,
	|	Filter3,
	|	Filter4,
	|	AccountReferenceName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Step2.DefaultAccountType AS DefaultAccountType,
	|	Step2.AccountReferenceName AS AccountReferenceName,
	|	Step2.DrCr AS DrCr,
	|	Step2.ConnectionKey AS ConnectionKey,
	|	Step2.Filter1 AS Filter1,
	|	Step2.Filter2 AS Filter2,
	|	Step2.Filter3 AS Filter3,
	|	Step2.Filter4 AS Filter4,
	|	DefaultAccounts.Account AS Account
	|INTO Step3
	|FROM
	|	Step2 AS Step2
	|		LEFT JOIN InformationRegister.DefaultAccounts AS DefaultAccounts
	|		ON Step2.DefaultAccountType = DefaultAccounts.DefaultAccountType
	|			AND Step2.Filter1 = DefaultAccounts.Filter1
	|			AND (DefaultAccounts.Filter1 <> UNDEFINED)
	|			AND Step2.Filter2 = DefaultAccounts.Filter2
	|			AND (DefaultAccounts.Filter2 <> UNDEFINED)
	|			AND (DefaultAccounts.Filter3 = UNDEFINED)
	|			AND Step2.Filter4 = DefaultAccounts.Filter4
	|			AND (DefaultAccounts.Filter4 <> UNDEFINED)
	|			AND Step2.AccountReferenceName = DefaultAccounts.AccountReferenceName
	|WHERE
	|	Step2.Account IS NULL
	|
	|INDEX BY
	|	DefaultAccountType,
	|	Filter1,
	|	Filter2,
	|	Filter3,
	|	Filter4,
	|	AccountReferenceName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Step3.DefaultAccountType AS DefaultAccountType,
	|	Step3.AccountReferenceName AS AccountReferenceName,
	|	Step3.DrCr AS DrCr,
	|	Step3.ConnectionKey AS ConnectionKey,
	|	Step3.Filter1 AS Filter1,
	|	Step3.Filter2 AS Filter2,
	|	Step3.Filter3 AS Filter3,
	|	Step3.Filter4 AS Filter4,
	|	DefaultAccounts.Account AS Account
	|INTO Step4
	|FROM
	|	Step3 AS Step3
	|		LEFT JOIN InformationRegister.DefaultAccounts AS DefaultAccounts
	|		ON Step3.DefaultAccountType = DefaultAccounts.DefaultAccountType
	|			AND Step3.Filter1 = DefaultAccounts.Filter1
	|			AND (DefaultAccounts.Filter1 <> UNDEFINED)
	|			AND Step3.Filter2 = DefaultAccounts.Filter2
	|			AND (DefaultAccounts.Filter2 <> UNDEFINED)
	|			AND (DefaultAccounts.Filter3 = UNDEFINED)
	|			AND (DefaultAccounts.Filter4 = UNDEFINED)
	|			AND Step3.AccountReferenceName = DefaultAccounts.AccountReferenceName
	|WHERE
	|	Step3.Account IS NULL
	|
	|INDEX BY
	|	DefaultAccountType,
	|	Filter1,
	|	Filter2,
	|	Filter3,
	|	Filter4,
	|	AccountReferenceName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Step4.DefaultAccountType AS DefaultAccountType,
	|	Step4.AccountReferenceName AS AccountReferenceName,
	|	Step4.DrCr AS DrCr,
	|	Step4.ConnectionKey AS ConnectionKey,
	|	Step4.Filter1 AS Filter1,
	|	Step4.Filter2 AS Filter2,
	|	Step4.Filter3 AS Filter3,
	|	Step4.Filter4 AS Filter4,
	|	DefaultAccounts.Account AS Account
	|INTO Step5
	|FROM
	|	Step4 AS Step4
	|		LEFT JOIN InformationRegister.DefaultAccounts AS DefaultAccounts
	|		ON Step4.DefaultAccountType = DefaultAccounts.DefaultAccountType
	|			AND Step4.Filter1 = DefaultAccounts.Filter1
	|			AND (DefaultAccounts.Filter1 <> UNDEFINED)
	|			AND (DefaultAccounts.Filter2 = UNDEFINED)
	|			AND Step4.Filter3 = DefaultAccounts.Filter3
	|			AND (DefaultAccounts.Filter3 <> UNDEFINED)
	|			AND Step4.Filter4 = DefaultAccounts.Filter4
	|			AND (DefaultAccounts.Filter4 <> UNDEFINED)
	|			AND Step4.AccountReferenceName = DefaultAccounts.AccountReferenceName
	|WHERE
	|	Step4.Account IS NULL
	|
	|INDEX BY
	|	DefaultAccountType,
	|	Filter1,
	|	Filter2,
	|	Filter3,
	|	Filter4,
	|	AccountReferenceName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Step5.DefaultAccountType AS DefaultAccountType,
	|	Step5.AccountReferenceName AS AccountReferenceName,
	|	Step5.DrCr AS DrCr,
	|	Step5.ConnectionKey AS ConnectionKey,
	|	Step5.Filter1 AS Filter1,
	|	Step5.Filter2 AS Filter2,
	|	Step5.Filter3 AS Filter3,
	|	Step5.Filter4 AS Filter4,
	|	DefaultAccounts.Account AS Account
	|INTO Step6
	|FROM
	|	Step5 AS Step5
	|		LEFT JOIN InformationRegister.DefaultAccounts AS DefaultAccounts
	|		ON Step5.DefaultAccountType = DefaultAccounts.DefaultAccountType
	|			AND Step5.Filter1 = DefaultAccounts.Filter1
	|			AND (DefaultAccounts.Filter1 <> UNDEFINED)
	|			AND (DefaultAccounts.Filter2 = UNDEFINED)
	|			AND Step5.Filter3 = DefaultAccounts.Filter3
	|			AND (DefaultAccounts.Filter3 <> UNDEFINED)
	|			AND (DefaultAccounts.Filter4 = UNDEFINED)
	|			AND Step5.AccountReferenceName = DefaultAccounts.AccountReferenceName
	|WHERE
	|	Step5.Account IS NULL
	|
	|INDEX BY
	|	DefaultAccountType,
	|	Filter1,
	|	Filter2,
	|	Filter3,
	|	Filter4,
	|	AccountReferenceName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Step6.DefaultAccountType AS DefaultAccountType,
	|	Step6.AccountReferenceName AS AccountReferenceName,
	|	Step6.DrCr AS DrCr,
	|	Step6.ConnectionKey AS ConnectionKey,
	|	Step6.Filter1 AS Filter1,
	|	Step6.Filter2 AS Filter2,
	|	Step6.Filter3 AS Filter3,
	|	Step6.Filter4 AS Filter4,
	|	DefaultAccounts.Account AS Account
	|INTO Step7
	|FROM
	|	Step6 AS Step6
	|		LEFT JOIN InformationRegister.DefaultAccounts AS DefaultAccounts
	|		ON Step6.DefaultAccountType = DefaultAccounts.DefaultAccountType
	|			AND Step6.Filter1 = DefaultAccounts.Filter1
	|			AND (DefaultAccounts.Filter1 <> UNDEFINED)
	|			AND (DefaultAccounts.Filter2 = UNDEFINED)
	|			AND (DefaultAccounts.Filter3 = UNDEFINED)
	|			AND Step6.Filter4 = DefaultAccounts.Filter4
	|			AND (DefaultAccounts.Filter4 <> UNDEFINED)
	|			AND Step6.AccountReferenceName = DefaultAccounts.AccountReferenceName
	|WHERE
	|	Step6.Account IS NULL
	|
	|INDEX BY
	|	DefaultAccountType,
	|	Filter1,
	|	Filter2,
	|	Filter3,
	|	Filter4,
	|	AccountReferenceName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Step7.DefaultAccountType AS DefaultAccountType,
	|	Step7.AccountReferenceName AS AccountReferenceName,
	|	Step7.DrCr AS DrCr,
	|	Step7.ConnectionKey AS ConnectionKey,
	|	Step7.Filter1 AS Filter1,
	|	Step7.Filter2 AS Filter2,
	|	Step7.Filter3 AS Filter3,
	|	Step7.Filter4 AS Filter4,
	|	DefaultAccounts.Account AS Account
	|INTO Step8
	|FROM
	|	Step7 AS Step7
	|		LEFT JOIN InformationRegister.DefaultAccounts AS DefaultAccounts
	|		ON Step7.DefaultAccountType = DefaultAccounts.DefaultAccountType
	|			AND Step7.Filter1 = DefaultAccounts.Filter1
	|			AND (DefaultAccounts.Filter1 <> UNDEFINED)
	|			AND (DefaultAccounts.Filter2 = UNDEFINED)
	|			AND (DefaultAccounts.Filter3 = UNDEFINED)
	|			AND (DefaultAccounts.Filter4 = UNDEFINED)
	|			AND Step7.AccountReferenceName = DefaultAccounts.AccountReferenceName
	|WHERE
	|	Step7.Account IS NULL
	|
	|INDEX BY
	|	DefaultAccountType,
	|	Filter1,
	|	Filter2,
	|	Filter3,
	|	Filter4,
	|	AccountReferenceName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Step8.DefaultAccountType AS DefaultAccountType,
	|	Step8.AccountReferenceName AS AccountReferenceName,
	|	Step8.DrCr AS DrCr,
	|	Step8.ConnectionKey AS ConnectionKey,
	|	Step8.Filter1 AS Filter1,
	|	Step8.Filter2 AS Filter2,
	|	Step8.Filter3 AS Filter3,
	|	Step8.Filter4 AS Filter4,
	|	DefaultAccounts.Account AS Account
	|INTO Step9
	|FROM
	|	Step8 AS Step8
	|		LEFT JOIN InformationRegister.DefaultAccounts AS DefaultAccounts
	|		ON Step8.DefaultAccountType = DefaultAccounts.DefaultAccountType
	|			AND (DefaultAccounts.Filter1 = UNDEFINED)
	|			AND Step8.Filter2 = DefaultAccounts.Filter2
	|			AND (DefaultAccounts.Filter2 <> UNDEFINED)
	|			AND Step8.Filter3 = DefaultAccounts.Filter3
	|			AND (DefaultAccounts.Filter3 <> UNDEFINED)
	|			AND Step8.Filter4 = DefaultAccounts.Filter4
	|			AND (DefaultAccounts.Filter4 <> UNDEFINED)
	|			AND Step8.AccountReferenceName = DefaultAccounts.AccountReferenceName
	|WHERE
	|	Step8.Account IS NULL
	|
	|INDEX BY
	|	DefaultAccountType,
	|	Filter1,
	|	Filter2,
	|	Filter3,
	|	Filter4,
	|	AccountReferenceName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Step9.DefaultAccountType AS DefaultAccountType,
	|	Step9.AccountReferenceName AS AccountReferenceName,
	|	Step9.DrCr AS DrCr,
	|	Step9.ConnectionKey AS ConnectionKey,
	|	Step9.Filter1 AS Filter1,
	|	Step9.Filter2 AS Filter2,
	|	Step9.Filter3 AS Filter3,
	|	Step9.Filter4 AS Filter4,
	|	DefaultAccounts.Account AS Account
	|INTO Step10
	|FROM
	|	Step9 AS Step9
	|		LEFT JOIN InformationRegister.DefaultAccounts AS DefaultAccounts
	|		ON Step9.DefaultAccountType = DefaultAccounts.DefaultAccountType
	|			AND (DefaultAccounts.Filter1 = UNDEFINED)
	|			AND Step9.Filter2 = DefaultAccounts.Filter2
	|			AND (DefaultAccounts.Filter2 <> UNDEFINED)
	|			AND Step9.Filter3 = DefaultAccounts.Filter3
	|			AND (DefaultAccounts.Filter3 <> UNDEFINED)
	|			AND (DefaultAccounts.Filter4 = UNDEFINED)
	|			AND Step9.AccountReferenceName = DefaultAccounts.AccountReferenceName
	|WHERE
	|	Step9.Account IS NULL
	|
	|INDEX BY
	|	DefaultAccountType,
	|	Filter1,
	|	Filter2,
	|	Filter3,
	|	Filter4,
	|	AccountReferenceName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Step10.DefaultAccountType AS DefaultAccountType,
	|	Step10.AccountReferenceName AS AccountReferenceName,
	|	Step10.DrCr AS DrCr,
	|	Step10.ConnectionKey AS ConnectionKey,
	|	Step10.Filter1 AS Filter1,
	|	Step10.Filter2 AS Filter2,
	|	Step10.Filter3 AS Filter3,
	|	Step10.Filter4 AS Filter4,
	|	DefaultAccounts.Account AS Account
	|INTO Step11
	|FROM
	|	Step10 AS Step10
	|		LEFT JOIN InformationRegister.DefaultAccounts AS DefaultAccounts
	|		ON Step10.DefaultAccountType = DefaultAccounts.DefaultAccountType
	|			AND (DefaultAccounts.Filter1 = UNDEFINED)
	|			AND Step10.Filter2 = DefaultAccounts.Filter2
	|			AND (DefaultAccounts.Filter2 <> UNDEFINED)
	|			AND (DefaultAccounts.Filter3 = UNDEFINED)
	|			AND Step10.Filter4 = DefaultAccounts.Filter4
	|			AND (DefaultAccounts.Filter4 <> UNDEFINED)
	|			AND Step10.AccountReferenceName = DefaultAccounts.AccountReferenceName
	|WHERE
	|	Step10.Account IS NULL
	|
	|INDEX BY
	|	DefaultAccountType,
	|	Filter1,
	|	Filter2,
	|	Filter3,
	|	Filter4,
	|	AccountReferenceName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Step11.DefaultAccountType AS DefaultAccountType,
	|	Step11.AccountReferenceName AS AccountReferenceName,
	|	Step11.DrCr AS DrCr,
	|	Step11.ConnectionKey AS ConnectionKey,
	|	Step11.Filter1 AS Filter1,
	|	Step11.Filter2 AS Filter2,
	|	Step11.Filter3 AS Filter3,
	|	Step11.Filter4 AS Filter4,
	|	DefaultAccounts.Account AS Account
	|INTO Step12
	|FROM
	|	Step11 AS Step11
	|		LEFT JOIN InformationRegister.DefaultAccounts AS DefaultAccounts
	|		ON Step11.DefaultAccountType = DefaultAccounts.DefaultAccountType
	|			AND (DefaultAccounts.Filter1 = UNDEFINED)
	|			AND Step11.Filter2 = DefaultAccounts.Filter2
	|			AND (DefaultAccounts.Filter2 <> UNDEFINED)
	|			AND (DefaultAccounts.Filter3 = UNDEFINED)
	|			AND (DefaultAccounts.Filter4 = UNDEFINED)
	|			AND Step11.AccountReferenceName = DefaultAccounts.AccountReferenceName
	|WHERE
	|	Step11.Account IS NULL
	|
	|INDEX BY
	|	DefaultAccountType,
	|	Filter1,
	|	Filter2,
	|	Filter3,
	|	Filter4,
	|	AccountReferenceName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Step12.DefaultAccountType AS DefaultAccountType,
	|	Step12.AccountReferenceName AS AccountReferenceName,
	|	Step12.DrCr AS DrCr,
	|	Step12.ConnectionKey AS ConnectionKey,
	|	Step12.Filter1 AS Filter1,
	|	Step12.Filter2 AS Filter2,
	|	Step12.Filter3 AS Filter3,
	|	Step12.Filter4 AS Filter4,
	|	DefaultAccounts.Account AS Account
	|INTO Step13
	|FROM
	|	Step12 AS Step12
	|		LEFT JOIN InformationRegister.DefaultAccounts AS DefaultAccounts
	|		ON Step12.DefaultAccountType = DefaultAccounts.DefaultAccountType
	|			AND (DefaultAccounts.Filter1 = UNDEFINED)
	|			AND (DefaultAccounts.Filter2 = UNDEFINED)
	|			AND Step12.Filter3 = DefaultAccounts.Filter3
	|			AND (DefaultAccounts.Filter3 <> UNDEFINED)
	|			AND Step12.Filter4 = DefaultAccounts.Filter4
	|			AND (DefaultAccounts.Filter4 <> UNDEFINED)
	|			AND Step12.AccountReferenceName = DefaultAccounts.AccountReferenceName
	|WHERE
	|	Step12.Account IS NULL
	|
	|INDEX BY
	|	DefaultAccountType,
	|	Filter1,
	|	Filter2,
	|	Filter3,
	|	Filter4,
	|	AccountReferenceName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Step13.DefaultAccountType AS DefaultAccountType,
	|	Step13.AccountReferenceName AS AccountReferenceName,
	|	Step13.DrCr AS DrCr,
	|	Step13.ConnectionKey AS ConnectionKey,
	|	Step13.Filter1 AS Filter1,
	|	Step13.Filter2 AS Filter2,
	|	Step13.Filter3 AS Filter3,
	|	Step13.Filter4 AS Filter4,
	|	DefaultAccounts.Account AS Account
	|INTO Step14
	|FROM
	|	Step13 AS Step13
	|		LEFT JOIN InformationRegister.DefaultAccounts AS DefaultAccounts
	|		ON Step13.DefaultAccountType = DefaultAccounts.DefaultAccountType
	|			AND (DefaultAccounts.Filter1 = UNDEFINED)
	|			AND (DefaultAccounts.Filter2 = UNDEFINED)
	|			AND Step13.Filter3 = DefaultAccounts.Filter3
	|			AND (DefaultAccounts.Filter3 <> UNDEFINED)
	|			AND (DefaultAccounts.Filter4 = UNDEFINED)
	|			AND Step13.AccountReferenceName = DefaultAccounts.AccountReferenceName
	|WHERE
	|	Step13.Account IS NULL
	|
	|INDEX BY
	|	DefaultAccountType,
	|	Filter1,
	|	Filter2,
	|	Filter3,
	|	Filter4,
	|	AccountReferenceName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Step14.DefaultAccountType AS DefaultAccountType,
	|	Step14.AccountReferenceName AS AccountReferenceName,
	|	Step14.DrCr AS DrCr,
	|	Step14.ConnectionKey AS ConnectionKey,
	|	Step14.Filter1 AS Filter1,
	|	Step14.Filter2 AS Filter2,
	|	Step14.Filter3 AS Filter3,
	|	Step14.Filter4 AS Filter4,
	|	DefaultAccounts.Account AS Account
	|INTO Step15
	|FROM
	|	Step14 AS Step14
	|		LEFT JOIN InformationRegister.DefaultAccounts AS DefaultAccounts
	|		ON Step14.DefaultAccountType = DefaultAccounts.DefaultAccountType
	|			AND (DefaultAccounts.Filter1 = UNDEFINED)
	|			AND (DefaultAccounts.Filter2 = UNDEFINED)
	|			AND (DefaultAccounts.Filter3 = UNDEFINED)
	|			AND Step14.Filter4 = DefaultAccounts.Filter4
	|			AND (DefaultAccounts.Filter4 <> UNDEFINED)
	|			AND Step14.AccountReferenceName = DefaultAccounts.AccountReferenceName
	|WHERE
	|	Step14.Account IS NULL
	|
	|INDEX BY
	|	DefaultAccountType,
	|	Filter1,
	|	Filter2,
	|	Filter3,
	|	Filter4,
	|	AccountReferenceName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Step1.DefaultAccountType,
	|	Step1.AccountReferenceName,
	|	Step1.DrCr,
	|	Step1.ConnectionKey,
	|	Step1.Filter1,
	|	Step1.Filter2,
	|	Step1.Filter3,
	|	Step1.Filter4,
	|	Step1.Account
	|INTO FinalStep
	|FROM
	|	Step1 AS Step1
	|WHERE
	|	Step1.Account IS NOT NULL 
	|
	|UNION ALL
	|
	|SELECT
	|	Step2.DefaultAccountType,
	|	Step2.AccountReferenceName,
	|	Step2.DrCr,
	|	Step2.ConnectionKey,
	|	Step2.Filter1,
	|	Step2.Filter2,
	|	Step2.Filter3,
	|	Step2.Filter4,
	|	Step2.Account
	|FROM
	|	Step2 AS Step2
	|WHERE
	|	Step2.Account IS NOT NULL 
	|
	|UNION ALL
	|
	|SELECT
	|	Step3.DefaultAccountType,
	|	Step3.AccountReferenceName,
	|	Step3.DrCr,
	|	Step3.ConnectionKey,
	|	Step3.Filter1,
	|	Step3.Filter2,
	|	Step3.Filter3,
	|	Step3.Filter4,
	|	Step3.Account
	|FROM
	|	Step3 AS Step3
	|WHERE
	|	Step3.Account IS NOT NULL 
	|
	|UNION ALL
	|
	|SELECT
	|	Step4.DefaultAccountType,
	|	Step4.AccountReferenceName,
	|	Step4.DrCr,
	|	Step4.ConnectionKey,
	|	Step4.Filter1,
	|	Step4.Filter2,
	|	Step4.Filter3,
	|	Step4.Filter4,
	|	Step4.Account
	|FROM
	|	Step4 AS Step4
	|WHERE
	|	Step4.Account IS NOT NULL 
	|
	|UNION ALL
	|
	|SELECT
	|	Step5.DefaultAccountType,
	|	Step5.AccountReferenceName,
	|	Step5.DrCr,
	|	Step5.ConnectionKey,
	|	Step5.Filter1,
	|	Step5.Filter2,
	|	Step5.Filter3,
	|	Step5.Filter4,
	|	Step5.Account
	|FROM
	|	Step5 AS Step5
	|WHERE
	|	Step5.Account IS NOT NULL 
	|
	|UNION ALL
	|
	|SELECT
	|	Step6.DefaultAccountType,
	|	Step6.AccountReferenceName,
	|	Step6.DrCr,
	|	Step6.ConnectionKey,
	|	Step6.Filter1,
	|	Step6.Filter2,
	|	Step6.Filter3,
	|	Step6.Filter4,
	|	Step6.Account
	|FROM
	|	Step6 AS Step6
	|WHERE
	|	Step6.Account IS NOT NULL 
	|
	|UNION ALL
	|
	|SELECT
	|	Step7.DefaultAccountType,
	|	Step7.AccountReferenceName,
	|	Step7.DrCr,
	|	Step7.ConnectionKey,
	|	Step7.Filter1,
	|	Step7.Filter2,
	|	Step7.Filter3,
	|	Step7.Filter4,
	|	Step7.Account
	|FROM
	|	Step7 AS Step7
	|WHERE
	|	Step7.Account IS NOT NULL 
	|
	|UNION ALL
	|
	|SELECT
	|	Step8.DefaultAccountType,
	|	Step8.AccountReferenceName,
	|	Step8.DrCr,
	|	Step8.ConnectionKey,
	|	Step8.Filter1,
	|	Step8.Filter2,
	|	Step8.Filter3,
	|	Step8.Filter4,
	|	Step8.Account
	|FROM
	|	Step8 AS Step8
	|WHERE
	|	Step8.Account IS NOT NULL 
	|
	|UNION ALL
	|
	|SELECT
	|	Step9.DefaultAccountType,
	|	Step9.AccountReferenceName,
	|	Step9.DrCr,
	|	Step9.ConnectionKey,
	|	Step9.Filter1,
	|	Step9.Filter2,
	|	Step9.Filter3,
	|	Step9.Filter4,
	|	Step9.Account
	|FROM
	|	Step9 AS Step9
	|WHERE
	|	Step9.Account IS NOT NULL 
	|
	|UNION ALL
	|
	|SELECT
	|	Step10.DefaultAccountType,
	|	Step10.AccountReferenceName,
	|	Step10.DrCr,
	|	Step10.ConnectionKey,
	|	Step10.Filter1,
	|	Step10.Filter2,
	|	Step10.Filter3,
	|	Step10.Filter4,
	|	Step10.Account
	|FROM
	|	Step10 AS Step10
	|WHERE
	|	Step10.Account IS NOT NULL 
	|
	|UNION ALL
	|
	|SELECT
	|	Step11.DefaultAccountType,
	|	Step11.AccountReferenceName,
	|	Step11.DrCr,
	|	Step11.ConnectionKey,
	|	Step11.Filter1,
	|	Step11.Filter2,
	|	Step11.Filter3,
	|	Step11.Filter4,
	|	Step11.Account
	|FROM
	|	Step11 AS Step11
	|WHERE
	|	Step11.Account IS NOT NULL 
	|
	|UNION ALL
	|
	|SELECT
	|	Step12.DefaultAccountType,
	|	Step12.AccountReferenceName,
	|	Step12.DrCr,
	|	Step12.ConnectionKey,
	|	Step12.Filter1,
	|	Step12.Filter2,
	|	Step12.Filter3,
	|	Step12.Filter4,
	|	Step12.Account
	|FROM
	|	Step12 AS Step12
	|WHERE
	|	Step12.Account IS NOT NULL 
	|
	|UNION ALL
	|
	|SELECT
	|	Step13.DefaultAccountType,
	|	Step13.AccountReferenceName,
	|	Step13.DrCr,
	|	Step13.ConnectionKey,
	|	Step13.Filter1,
	|	Step13.Filter2,
	|	Step13.Filter3,
	|	Step13.Filter4,
	|	Step13.Account
	|FROM
	|	Step13 AS Step13
	|WHERE
	|	Step13.Account IS NOT NULL 
	|
	|UNION ALL
	|
	|SELECT
	|	Step14.DefaultAccountType,
	|	Step14.AccountReferenceName,
	|	Step14.DrCr,
	|	Step14.ConnectionKey,
	|	Step14.Filter1,
	|	Step14.Filter2,
	|	Step14.Filter3,
	|	Step14.Filter4,
	|	Step14.Account
	|FROM
	|	Step14 AS Step14
	|WHERE
	|	Step14.Account IS NOT NULL 
	|
	|UNION ALL
	|
	|SELECT
	|	Step15.DefaultAccountType,
	|	Step15.AccountReferenceName,
	|	Step15.DrCr,
	|	Step15.ConnectionKey,
	|	Step15.Filter1,
	|	Step15.Filter2,
	|	Step15.Filter3,
	|	Step15.Filter4,
	|	Step15.Account
	|FROM
	|	Step15 AS Step15
	|WHERE
	|	Step15.Account IS NOT NULL 
	|
	|UNION ALL
	|
	|SELECT
	|	Step15.DefaultAccountType,
	|	Step15.AccountReferenceName,
	|	Step15.DrCr,
	|	Step15.ConnectionKey,
	|	Step15.Filter1,
	|	Step15.Filter2,
	|	Step15.Filter3,
	|	Step15.Filter4,
	|	DefaultAccounts.Account
	|FROM
	|	Step15 AS Step15
	|		INNER JOIN InformationRegister.DefaultAccounts AS DefaultAccounts
	|		ON Step15.DefaultAccountType = DefaultAccounts.DefaultAccountType
	|			AND (DefaultAccounts.Filter1 = UNDEFINED)
	|			AND (DefaultAccounts.Filter2 = UNDEFINED)
	|			AND (DefaultAccounts.Filter3 = UNDEFINED)
	|			AND (DefaultAccounts.Filter4 = UNDEFINED)
	|			AND Step15.AccountReferenceName = DefaultAccounts.AccountReferenceName
	|			AND (Step15.Account IS NULL)
	|
	|INDEX BY
	|	Account
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PrimaryChartOfAccounts.Ref AS Account,
	|	PrimaryChartOfAccounts.Currency AS Currency,
	|	FALSE AS Quantity
	|INTO AccountsTable
	|FROM
	|	ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|WHERE
	|	PrimaryChartOfAccounts.Ref IN
	|			(SELECT DISTINCT
	|				FinalStep.Account AS Account
	|			FROM
	|				FinalStep AS FinalStep)
	|
	|UNION ALL
	|
	|SELECT
	|	MasterChartOfAccounts.Ref,
	|	MasterChartOfAccounts.Currency,
	|	MasterChartOfAccounts.Quantity
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
	|WHERE
	|	MasterChartOfAccounts.Ref IN
	|			(SELECT DISTINCT
	|				FinalStep.Account AS Account
	|			FROM
	|				FinalStep AS FinalStep)
	|
	|INDEX BY
	|	Account
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	FinalStep.DefaultAccountType AS DefaultAccountType,
	|	FinalStep.AccountReferenceName AS AccountReferenceName,
	|	FinalStep.DrCr AS DrCr,
	|	FinalStep.ConnectionKey AS ConnectionKey,
	|	FinalStep.Filter1 AS Filter1,
	|	FinalStep.Filter2 AS Filter2,
	|	FinalStep.Filter3 AS Filter3,
	|	FinalStep.Filter4 AS Filter4,
	|	FinalStep.Account AS Account,
	|	AccountsTable.Currency AS Currency,
	|	AccountsTable.Quantity AS Quantity
	|FROM
	|	FinalStep AS FinalStep
	|		LEFT JOIN AccountsTable AS AccountsTable
	|		ON FinalStep.Account = AccountsTable.Account
	|
	|GROUP BY
	|	FinalStep.DefaultAccountType,
	|	FinalStep.AccountReferenceName,
	|	FinalStep.Filter2,
	|	FinalStep.DrCr,
	|	FinalStep.Account,
	|	FinalStep.Filter4,
	|	AccountsTable.Quantity,
	|	AccountsTable.Currency,
	|	FinalStep.Filter3,
	|	FinalStep.Filter1,
	|	FinalStep.ConnectionKey";
	
	If IsMasterAccounting Then
		QueryText = StrReplace(QueryText, "DefaultAccountsFilters", "MasterDefaultAccountsFilters"); 
	EndIf;
	
	Return QueryText;
	
EndFunction

Function GetDefaultAccountsFilterFields(Entry, DefaultAccountsTable, EntryIndex, DrCr, DefaultAccountStructure, GroupFieldsArray = Undefined, Postfix = "")
	
	SearchStructure = New Structure;
	SearchStructure.Insert("TemplateRef"	, Entry.Ref);
	SearchStructure.Insert("ConnectionKey"	, Entry.ConnectionKey);
	SearchStructure.Insert("DrCr"			, DrCr);
	
	FoundRows = DefaultAccountsTable.FindRows(SearchStructure);
	
	AccountsQueryText = "
	|	&_DefaultAccountTypeParameter__EntryIndex_ AS DefaultAccountType_Postfix_,
	|	&_AccountReferenceNameParameter__EntryIndex_ AS AccountReferenceName_Postfix_,
	|	&_DrCrParameter_ AS DrCr_Postfix_,
	|	&ConnectionKey_EntryIndex_ AS ConnectionKey_Postfix_";
	
	FilterIndex = 1;
	For Each Row In FoundRows Do
		If FilterIndex > 4 Then
			Break;
		EndIf;
		
		AccountsQueryText = AccountsQueryText
			+ StrTemplate(",
			|	%2 AS Filter%1_Postfix_", Row.EntryOrder, ?(ValueIsFilled(Row.Value), StrTemplate("%1", Row.Value), "UNDEFINED"));
			
		If GroupFieldsArray <> Undefined Then
			GroupFieldsArray.Add(Row.Value);
		EndIf;
		
		FilterIndex = FilterIndex + 1;
	EndDo;
	
	For CurrentIndex = FilterIndex To 4 Do
		AccountsQueryText = AccountsQueryText
			+ StrTemplate(",
			|	Undefined AS Filter%1_Postfix_", CurrentIndex);
	EndDo;
	
	AccountsQueryText = StrReplace(AccountsQueryText, "_DefaultAccountTypeParameter_"	, DefaultAccountStructure.DefaultAccountTypeParameter);
	AccountsQueryText = StrReplace(AccountsQueryText, "_AccountReferenceNameParameter_"	, DefaultAccountStructure.AccountReferenceNameParameter);
	AccountsQueryText = StrReplace(AccountsQueryText, "_DrCrParameter_"					, DefaultAccountStructure.DrCrParameter);
	AccountsQueryText = StrReplace(AccountsQueryText, "_Postfix_"						, Postfix);
	AccountsQueryText = StrReplace(AccountsQueryText, "_EntryIndex_"					, EntryIndex);
	
	Return AccountsQueryText;
	
EndFunction

Function DocumentAttributesTempTableQueryText(Query, DocumentMetadata)
	
	DocumentTableName = DocumentMetadata.Name;
	
	PredefinedName = StrTemplate("Document_%1", DocumentMetadata.Name);
	PredefinedNamesArray = Metadata.Catalogs.AdditionalAttributesAndInfoSets.GetPredefinedNames();
	
	AdditionalFieldsText = "";
	QueryTables			 = "&ConfigurationDocumentTableName AS Doc_DocumentTableName";
	
	If PredefinedNamesArray.Find(PredefinedName) <> Undefined Then
	
		AdditionalAttributesQuery = New Query;
		AdditionalAttributesQuery.Text =
		"SELECT
		|	AdditionalAttributesAndInfoSetsAdditionalAttributes.Property AS Property,
		|	AdditionalAttributesAndInfo.ValueType AS ValueType,
		|	AdditionalAttributesAndInfo.Name AS Name
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS AdditionalAttributesAndInfoSetsAdditionalAttributes
		|		LEFT JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
		|		ON AdditionalAttributesAndInfoSetsAdditionalAttributes.Property = AdditionalAttributesAndInfo.Ref
		|WHERE
		|	AdditionalAttributesAndInfoSetsAdditionalAttributes.Ref = &Ref";
		
		AdditionalAttributesQuery.SetParameter("Ref", Catalogs.AdditionalAttributesAndInfoSets[PredefinedName]);
		
		QueryResult = AdditionalAttributesQuery.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		AttributeIndex = 1;
		
		While SelectionDetailRecords.Next() Do
			
			FieldName = SelectionDetailRecords.Name;
			
			AdditionalAttributeParameter = StrTemplate("AdditionalAttribute%1", Format(AttributeIndex, "NDS=; NGS=; NG=")); 
			
			AdditionalFieldsText = AdditionalFieldsText + StrTemplate("
				|	, ISNULL(Table_%1.Value, Undefined) AS %1", FieldName);
			
			QueryTables = QueryTables + StrTemplate("
				|		LEFT JOIN Document.%1.AdditionalAttributes AS Table_%2
				|		ON Doc_%1.Ref = Table_%2.Ref
				|			AND Table_%2.Property = &%3", DocumentTableName, FieldName, AdditionalAttributeParameter);
			
			Query.SetParameter(AdditionalAttributeParameter, SelectionDetailRecords.Property);
			
			AttributeIndex = AttributeIndex + 1;
			
		EndDo;
	EndIf;
	
	QueryText =
	"SELECT
	|	_Field0_
	|INTO DocumentTableName
	|FROM
	|	_QueryTables_ AS Doc_DocumentTableName
	|WHERE Doc_DocumentTableName.Ref = &Ref";
	
	FieldIndex = 0;
	
	For Each Attribute In DocumentMetadata.Attributes Do
		
		FieldTemplate = StrTemplate("Doc_%1.%2 AS %2, _Field%3_", DocumentTableName, Attribute.Name, String(FieldIndex + 1));
		QueryText = StrReplace(QueryText, StrTemplate("_Field%1_", String(FieldIndex)), FieldTemplate);
		
		FieldIndex = FieldIndex + 1;
	EndDo;
	For Each Attribute In DocumentMetadata.StandardAttributes Do
		
		FieldTemplate = StrTemplate("Doc_%1.%2 AS %2, _Field%3_", DocumentTableName, Attribute.Name, String(FieldIndex + 1));
		QueryText = StrReplace(QueryText, StrTemplate("_Field%1_", String(FieldIndex)), FieldTemplate);
		
		FieldIndex = FieldIndex + 1;
	EndDo;
	
	QueryText = StrReplace(QueryText, StrTemplate(", _Field%1_", String(FieldIndex)), "");
	QueryText = StrReplace(QueryText, "_QueryTables_ AS Doc_DocumentTableName"		, QueryTables);
	QueryText = StrReplace(QueryText, "&ConfigurationDocumentTableName"				, StrTemplate("Document.%1", DocumentTableName));
	QueryText = StrReplace(QueryText, "DocumentTableName"							, DocumentTableName);
	
	Return QueryText;
	
EndFunction

Function ConstantsTableQueryText(AccountingTemplatesList)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingTransactionsTemplatesEntriesFilters.ParameterName AS ParameterName
	|FROM
	|	Catalog.AccountingTransactionsTemplates.EntriesFilters AS AccountingTransactionsTemplatesEntriesFilters
	|WHERE
	|	AccountingTransactionsTemplatesEntriesFilters.Ref IN(&TemplatesList)
	|	AND AccountingTransactionsTemplatesEntriesFilters.ParameterName LIKE ""Constant.%""
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingTransactionsTemplatesAdditionalEntriesParameters.ParameterName
	|FROM
	|	Catalog.AccountingTransactionsTemplates.AdditionalEntriesParameters AS AccountingTransactionsTemplatesAdditionalEntriesParameters
	|WHERE
	|	AccountingTransactionsTemplatesAdditionalEntriesParameters.Ref IN(&TemplatesList)
	|	AND AccountingTransactionsTemplatesAdditionalEntriesParameters.ParameterName LIKE ""Constant.%""
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingTransactionsTemplatesParameters.ParameterName
	|FROM
	|	Catalog.AccountingTransactionsTemplates.Parameters AS AccountingTransactionsTemplatesParameters
	|WHERE
	|	AccountingTransactionsTemplatesParameters.Ref IN(&TemplatesList)
	|	AND AccountingTransactionsTemplatesParameters.ParameterName LIKE ""Constant.%""";
	
	Query.SetParameter("TemplatesList", AccountingTemplatesList);
	
	QueryResult = Query.Execute();
	FiltersTable = QueryResult.Unload();
	
	QueryText = 
	"SELECT
	|	&FieldsText
	|INTO ConstantsTable
	|FROM
	|	&ConstantsText";
		
	FirstRow = True;
	FieldsText = "";
	TablesText = "";
	
	UsedConstantsArray = New Array;
	For Each FilterRow In FiltersTable Do
				
		FilterArray = StrSplit(FilterRow.ParameterName, ".", False);
		ConstantName = FilterArray[1];
		
		If UsedConstantsArray.Find(ConstantName) = Undefined Then
			UsedConstantsArray.Add(ConstantName);
		Else
			Continue;
		EndIf;
		
		If FirstRow Then
			FirstRow = False;
			RowsDelimeter = "";
		Else
			RowsDelimeter = " ," + Chars.LF;
		EndIf;
		
		FieldsText = FieldsText + RowsDelimeter + StrTemplate("%1.Value AS %1", ConstantName);
		TablesText = TablesText + RowsDelimeter + StrTemplate("Constant.%1 AS %1", ConstantName);
	EndDo;
	
	If FirstRow Then
		// There are no constant conditionds
		QueryText = 
		"SELECT
		|NULL AS Field
		|INTO ConstantsTable";
	Else
		QueryText = StrReplace(QueryText, "&FieldsText", FieldsText);
		QueryText = StrReplace(QueryText, "&ConstantsText", TablesText);
	EndIf;
	
	Return QueryText;
	
EndFunction 

Function RegisterRecordsTempTableQueryText(DataSource)
	
	QueryText = 
	"SELECT	
	| *
	|INTO TempTableName
	|FROM
	|	&RegisterRecordsTableName AS RegisterRecordsTableName";
				
	QueryText = StrReplace(QueryText, "TempTableName"				, DataSource.TempTableName);
	QueryText = StrReplace(QueryText, "RegisterRecordsTableName"	, DataSource.RegisterRecordsTableName);
		
	Return QueryText;
	
EndFunction 

Function TabularSectionTempTableQueryText(DataSource, DocumentMetadata)
	
	QueryText = 
	"SELECT
	| *
	|INTO TempTableName
	|FROM
	|	&ConfigurationDocumentTableName As DocTabsectionTable
	|WHERE
	|	DocTabsectionTable.Ref = &Ref";
				
	QueryText = StrReplace(QueryText, "TempTableName", DataSource.TempTableName);
	QueryText = StrReplace(QueryText,
		"&ConfigurationDocumentTableName",
		StrTemplate("Document.%1.%2", DocumentMetadata.Name, DataSource.TableName));
		
	Return QueryText;
	
EndFunction 

Function TabularSectionTempTableFilteredQueryText(DataSource, Filter, DocumentAttributesTableName)
	
	QueryText =
	"SELECT	
	| *
	|INTO Filtered_TempTableName__Index_
	|FROM
	|	_TempTableName_ As DataSource_ConditionTableName
	|	INNER JOIN _DocumentAttributesTable_ AS Doc__DocumentAttributesTable_
	|	ON (TRUE)
	|	INNER JOIN AccountingPolicy AS AccountingPolicy
	|	ON (TRUE)
	|	INNER JOIN ConstantsTable AS Constant
	|	ON (TRUE)
	|WHERE
	|	&ConditionText";
	
	QueryText = StrReplace(QueryText, "_TempTableName_"				, DataSource.TempTableName);
	QueryText = StrReplace(QueryText, "_Index_"						, Filter.QueryTempTableID);
	QueryText = StrReplace(QueryText, "_DocumentAttributesTable_"	, DocumentAttributesTableName);
	QueryText = StrReplace(QueryText, "ConditionTableName"			, DataSource.TableName);
	QueryText = StrReplace(QueryText, "&ConditionText"				, Filter.ConditionText);
	
	ReplaceInnerQueryTableNames(QueryText, DataSource.TableName, DataSource.TableSource, "DataSource");
	ReplaceInnerQueryTableNames(QueryText, DocumentAttributesTableName, "Document", "Doc");
	
	Return QueryText;
	
EndFunction 

Function PrimaryAccountingEntryQueryText(EntryTemplate, EntryIndex, DataSource, DocumentAttributesTableName, FilteredTableIndex, DefaultAccountsTable)
	
	QueryText =
	"SELECT	
	| *
	|INTO TempTableName
	|FROM
	|	&RegisterRecordsTableName AS RegisterRecordsTableName";
				
	QueryText = StrReplace(QueryText, "TempTableName"				, DataSource.TempTableName);
	QueryText = StrReplace(QueryText, "RegisterRecordsTableName"	, DataSource.RegisterRecordsTableName);
		
	Return QueryText;
	
EndFunction 

Function MasterAccountingEntryQueryText(EntryTemplate, EntryIndex, DataSource, DocumentAttributesTableName, FilteredTableIndex, DefaultAccountsTable, AdditionalQueryParameters)

	If EntryTemplate.TypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Compound Then
		Return MasterCompoundAccountingEntryQueryText(
			EntryTemplate,
			EntryIndex,
			DataSource,
			DocumentAttributesTableName,
			FilteredTableIndex, 
			DefaultAccountsTable,
			AdditionalQueryParameters);
	Else
		Return MasterSimpleAccountingEntryQueryText(
			EntryTemplate,
			EntryIndex,
			DataSource,
			DocumentAttributesTableName,
			FilteredTableIndex, 
			DefaultAccountsTable,
			AdditionalQueryParameters);
	EndIf;
		
EndFunction

Function PrimaryAccountingDefaultAccountsQueryText(FirstDefaultAccount, EntryTemplate, EntryIndex, DataSource, DocumentAttributesTableName, FilteredTableIndex, Fields)

	QueryText = 
	"SELECT DISTINCT
	|	&Fields
	|INTO DefaultAccountsFilters
	|FROM
	|	_Filtered__TempTableName__Index_ AS DataSource__QueryTableName_
	|	INNER JOIN _DocumentAttributesTable_ AS Doc__DocumentAttributesTable_
	|	ON (TRUE)";
	
	GroupFields = (EntryTemplate.Mode = Enums.AccountingEntriesDataSourceModes.Combined);
	GroupingFieldsArray = New Array;
	
	If Not FirstDefaultAccount Then
		QueryText = StrReplace(QueryText, "INTO DefaultAccountsFilters", "");
	EndIf;
	
	QueryText = StrReplace(QueryText, "&Fields" 					, Fields);
	QueryText = StrReplace(QueryText, "_Filtered_"		 			, ?(FilteredTableIndex > 0, "Filtered", ""));
	QueryText = StrReplace(QueryText, "_Index_" 					, ?(FilteredTableIndex > 0, FilteredTableIndex, ""));
	QueryText = StrReplace(QueryText, "_TempTableName_" 			, DataSource.TempTableName);
	QueryText = StrReplace(QueryText, "_QueryTableName_"			, DataSource.QueryTableName);
	QueryText = StrReplace(QueryText, "_EntryIndex_"				, EntryIndex);
	QueryText = StrReplace(QueryText, "_DocumentAttributesTable_"	, DocumentAttributesTableName);
	
	ReplaceInnerQueryTableNames(QueryText, DataSource.QueryTableName, DataSource.TableSource, "DataSource");
	ReplaceInnerQueryTableNames(QueryText, DocumentAttributesTableName, "Document", "Doc");
	
	Return QueryText;

EndFunction 

Function MasterAccountingDefaultAccountsQueryText(FirstDefaultAccount, EntryTemplate, EntryIndex, DataSource, DocumentAttributesTableName, FilteredTableIndex, Fields)

	QueryText = 
	"SELECT DISTINCT
	|	&Fields
	|INTO MasterDefaultAccountsFilters
	|FROM
	|	_Filtered__TempTableName__Index_ AS DataSource__QueryTableName_
	|	INNER JOIN _DocumetntAttributesTable_ AS Doc__DocumetntAttributesTable_
	|	ON (TRUE)";
	
	GroupFields = (EntryTemplate.Mode = Enums.AccountingEntriesDataSourceModes.Combined);
	GroupingFieldsArray = New Array;
	
	If Not FirstDefaultAccount Then
		QueryText = StrReplace(QueryText, "INTO MasterDefaultAccountsFilters", "");
	EndIf;
	
	QueryText = StrReplace(QueryText, "&Fields"						, Fields);
	QueryText = StrReplace(QueryText, "_TempTableName_"				, DataSource.TempTableName);
	QueryText = StrReplace(QueryText, "_Filtered_"					, ?(FilteredTableIndex > 0, "Filtered", ""));
	QueryText = StrReplace(QueryText, "_Index_"						, ?(FilteredTableIndex > 0, FilteredTableIndex, ""));
	QueryText = StrReplace(QueryText, "_QueryTableName_"			, DataSource.QueryTableName);
	QueryText = StrReplace(QueryText, "_DocumetntAttributesTable_"	, DocumentAttributesTableName);
	
	ReplaceInnerQueryTableNames(QueryText, DataSource.QueryTableName, DataSource.TableSource, "DataSource");
	ReplaceInnerQueryTableNames(QueryText, DocumentAttributesTableName, "Document", "Doc");
	
	Return QueryText;
	
EndFunction

Function MasterCompoundAccountingEntryQueryText(EntryTemplate, EntryIndex, DataSource, DocumentAttributesTableName, FilteredTableIndex, DefaultAccountsTable, AdditionalQueryParameters)
	
	QueryText =
	"SELECT
	|	&RecordType_EntryIndex_ As RecordType,
	|	&LineNumber AS LineNumber,
	|	&TransactionTemplate_EntryIndex_ AS TransactionTemplate,
	|	&TransactionTemplateLineNumber_EntryIndex_ AS TransactionTemplateLineNumber,
	|	&TypeOfAccounting_EntryIndex_ AS TypeOfAccounting,
	|	&Period AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Account_EntryIndex_ AS Account,
	|	&Currency AS Currency,
	|	&AmountCur AS AmountCur,
	|	&Amount AS Amount,
	|	&Quantity AS Quantity,
	|	&Content AS Content,
	|	FALSE AS OfflineRecord,
	|	&AnalyticalDimensions1 AS ExtDimension1,
	|	&AnalyticalDimensions2 AS ExtDimension2,
	|	&AnalyticalDimensions3 AS ExtDimension3,
	|	&AnalyticalDimensions4 AS ExtDimension4,
	|	&AnalyticalDimensionsType1_EntryIndex_ AS ExtDimensionType1,
	|	&AnalyticalDimensionsType2_EntryIndex_ AS ExtDimensionType2,
	|	&AnalyticalDimensionsType3_EntryIndex_ AS ExtDimensionType3,
	|	&AnalyticalDimensionsType4_EntryIndex_ AS ExtDimensionType4,
	|	&AccountsConnectionText
	|FROM
	|	&TempTableName AS DataSource__QueryTableName_
	|	INNER JOIN _DocumentAttributesTable_ AS Doc__DocumentAttributesTable_
	|	ON (TRUE)";
	
	GroupFields = (EntryTemplate.Mode = Enums.AccountingEntriesDataSourceModes.Combined);
	GroupingFieldsArray = New Array;
	
	DefaultAccountStructure = New Structure;
	DefaultAccountStructure.Insert("DefaultAccountTypeParameter"	, "DefaultAccountType");
	DefaultAccountStructure.Insert("AccountReferenceNameParameter"	, "AccountReferenceName");
	DefaultAccountStructure.Insert("DrCrParameter"					, "DrCrEmpty");
	
	ConnectionText = GetDefaultAccountsFilterFields(EntryTemplate,
		DefaultAccountsTable,
		EntryIndex,
		Enums.DebitCredit.EmptyRef(),
		DefaultAccountStructure,
		GroupingFieldsArray);
		
	InsertDataSourceField(QueryText, "Period"		, EntryTemplate, False, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "Currency"		, EntryTemplate, False, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "AmountCur"	, EntryTemplate, GroupFields, GroupFields, GroupingFieldsArray, True);
	InsertDataSourceField(QueryText, "Amount"		, EntryTemplate, GroupFields, GroupFields, GroupingFieldsArray, True);
	InsertDataSourceField(QueryText, "Quantity"		, EntryTemplate, GroupFields, GroupFields, GroupingFieldsArray, True);
	InsertDataSourceField(QueryText, "Content"		, EntryTemplate, False, False, GroupingFieldsArray);

	If FilteredTableIndex > 0 Then
		QueryText = StrReplace(QueryText, "&TempTableName", 
			StrTemplate("Filtered%1%2", DataSource.TempTableName, FilteredTableIndex));
	Else
		QueryText = StrReplace(QueryText, "&TempTableName", DataSource.TempTableName);
	EndIf;
	
	MaxAnalyticalDimensionsNumber = ChartsOfAccounts.MasterChartOfAccounts.MaxAnalyticalDimensionsNumber();
	For Index = 1 To MaxAnalyticalDimensionsNumber Do
		
		AnalyticalDimensionsName	= "AnalyticalDimensions" + Index;
		AnalyticalDimensionsValue	= EntryTemplate[AnalyticalDimensionsName];
		
		If TypeOf(AnalyticalDimensionsValue) = Type("String") Then
			InsertDataSourceField(QueryText, AnalyticalDimensionsName, EntryTemplate, False, GroupFields, GroupingFieldsArray);
		Else
			QueryText = StrReplace(QueryText, AnalyticalDimensionsName, AnalyticalDimensionsName + EntryIndex);
			
			AddParameter = New Structure("ParameterName, ParameterValue",
				AnalyticalDimensionsName + EntryIndex,
				AnalyticalDimensionsValue);
			AdditionalQueryParameters.Add(AddParameter);
		EndIf;
		
	EndDo;
	
	If GroupFields Then
		QueryText = QueryText + GroupingTextByFields(GroupingFieldsArray);
		QueryText = StrReplace(QueryText, "&LineNumber", "Min(&LineNumber)");
	EndIf;
	
	If DataSource.SortByLineNumber Then
		QueryText = StrReplace(QueryText, "&LineNumber", "DataSource__QueryTableName_.LineNumber");
	Else
		QueryText = StrReplace(QueryText, "&LineNumber", "0");
	EndIf;
	
	QueryText = StrReplace(QueryText, "&AccountsConnectionText"		, ConnectionText);
	
	QueryText = StrReplace(QueryText, "_QueryTableName_"			, DataSource.QueryTableName);
	QueryText = StrReplace(QueryText, "_EntryIndex_"				, EntryIndex);
	QueryText = StrReplace(QueryText, "_DocumentAttributesTable_"	, DocumentAttributesTableName);
	
	ReplaceInnerQueryTableNames(QueryText, DataSource.QueryTableName, DataSource.TableSource, "DataSource");
	ReplaceInnerQueryTableNames(QueryText, DocumentAttributesTableName, "Document", "Doc");
	
	Return QueryText;
	
EndFunction

Function MasterSimpleAccountingEntryQueryText(EntryTemplate, EntryIndex, DataSource, DocumentAttributesTableName, FilteredTableIndex, DefaultAccountsTable, AdditionalQueryParameters)
	
	QueryText =
	"SELECT
	|	&LineNumber AS LineNumber,
	|	&TransactionTemplate_EntryIndex_ AS TransactionTemplate,
	|	&TransactionTemplateLineNumber_EntryIndex_ AS TransactionTemplateLineNumber,
	|	&TypeOfAccounting_EntryIndex_ AS TypeOfAccounting,
	|	&Period AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&AccountDr_EntryIndex_ AS AccountDr,
	|	&AccountCr_EntryIndex_ AS AccountCr,
	|	&CurrencyDr AS CurrencyDr,
	|	&AmountCurDr AS AmountCurDr,
	|	&CurrencyCr AS CurrencyCr,
	|	&AmountCurCr AS AmountCurCr,
	|	&Amount AS Amount,
	|	&QuantityDr AS QuantityDr,
	|	&QuantityCr As QuantityCr,
	|	&Content AS Content,
	|	FALSE AS OfflineRecord,
	|	&AnalyticalDimensionsDr1 AS ExtDimensionDr1,
	|	&AnalyticalDimensionsDr2 AS ExtDimensionDr2,
	|	&AnalyticalDimensionsDr3 AS ExtDimensionDr3,
	|	&AnalyticalDimensionsDr4 AS ExtDimensionDr4,
	|	&AnalyticalDimensionsTypeDr1_EntryIndex_ AS ExtDimensionTypeDr1,
	|	&AnalyticalDimensionsTypeDr2_EntryIndex_ AS ExtDimensionTypeDr2,
	|	&AnalyticalDimensionsTypeDr3_EntryIndex_ AS ExtDimensionTypeDr3,
	|	&AnalyticalDimensionsTypeDr4_EntryIndex_ AS ExtDimensionTypeDr4,
	|	&AnalyticalDimensionsCr1 AS ExtDimensionCr1,
	|	&AnalyticalDimensionsCr2 AS ExtDimensionCr2,
	|	&AnalyticalDimensionsCr3 AS ExtDimensionCr3,
	|	&AnalyticalDimensionsCr4 AS ExtDimensionCr4,
	|	&AnalyticalDimensionsTypeCr1_EntryIndex_ AS ExtDimensionTypeCr1,
	|	&AnalyticalDimensionsTypeCr2_EntryIndex_ AS ExtDimensionTypeCr2,
	|	&AnalyticalDimensionsTypeCr3_EntryIndex_ AS ExtDimensionTypeCr3,
	|	&AnalyticalDimensionsTypeCr4_EntryIndex_ AS ExtDimensionTypeCr4,
	|	&AccountsConnectionTextDr,
	|	&AccountsConnectionTextCr
	|FROM
	|	&TempTableName AS DataSource__QueryTableName_
	|		INNER JOIN _DocumentAttributesTable_ AS Doc__DocumentAttributesTable_
	|		ON (TRUE)";
	
	GroupFields = (EntryTemplate.Mode = Enums.AccountingEntriesDataSourceModes.Combined);
	GroupingFieldsArray = New Array;
	
	DefaultAccountStructure = New Structure;
	DefaultAccountStructure.Insert("DefaultAccountTypeParameter"	, "DefaultAccountTypeDr");
	DefaultAccountStructure.Insert("AccountReferenceNameParameter"	, "AccountReferenceNameDr");
	DefaultAccountStructure.Insert("DrCrParameter"					, "DrCrDebit");
	
	ConnectionTextDr = GetDefaultAccountsFilterFields(EntryTemplate, 
		DefaultAccountsTable, 
		EntryIndex, 
		Enums.DebitCredit.Dr,
		DefaultAccountStructure,
		GroupingFieldsArray);
	
	InsertDataSourceField(QueryText, "Period"		, EntryTemplate, False, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "CurrencyDr"	, EntryTemplate, False, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "AmountCurDr"	, EntryTemplate, GroupFields, GroupFields, GroupingFieldsArray, True);
	InsertDataSourceField(QueryText, "CurrencyCr"	, EntryTemplate, False, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "AmountCurCr"	, EntryTemplate, GroupFields, GroupFields, GroupingFieldsArray, True);
	InsertDataSourceField(QueryText, "Amount"		, EntryTemplate, GroupFields, GroupFields, GroupingFieldsArray, True);
	InsertDataSourceField(QueryText, "QuantityDr"	, EntryTemplate, False, GroupFields, GroupingFieldsArray, True);
	InsertDataSourceField(QueryText, "QuantityCr"	, EntryTemplate, False, GroupFields, GroupingFieldsArray, True);
	InsertDataSourceField(QueryText, "Content"		, EntryTemplate, False, False, GroupingFieldsArray);

	MaxAnalyticalDimensionsNumber = ChartsOfAccounts.MasterChartOfAccounts.MaxAnalyticalDimensionsNumber();
	For Index = 1 To MaxAnalyticalDimensionsNumber Do // DR
		
		AnalyticalDimensionsName	= "AnalyticalDimensionsDr" + Index;
		AnalyticalDimensionsValue	= EntryTemplate[AnalyticalDimensionsName];
		If TypeOf(AnalyticalDimensionsValue) = Type("String") Then
			InsertDataSourceField(QueryText, AnalyticalDimensionsName, EntryTemplate, False, GroupFields, GroupingFieldsArray);
		Else
			QueryText = StrReplace(QueryText, AnalyticalDimensionsName, AnalyticalDimensionsName + EntryIndex);
			AdditionalQueryParameters.Add(New Structure("ParameterName, ParameterValue", AnalyticalDimensionsName + EntryIndex, AnalyticalDimensionsValue));
		EndIf;
		
	EndDo;
	For Index = 1 To MaxAnalyticalDimensionsNumber Do // CR
		
		AnalyticalDimensionsName	= "AnalyticalDimensionsCr" + Index;
		AnalyticalDimensionsValue	= EntryTemplate[AnalyticalDimensionsName];
		If TypeOf(AnalyticalDimensionsValue) = Type("String") Then
			InsertDataSourceField(QueryText, AnalyticalDimensionsName, EntryTemplate, False, GroupFields, GroupingFieldsArray);
		Else
			QueryText = StrReplace(QueryText, AnalyticalDimensionsName, AnalyticalDimensionsName + EntryIndex);
			AdditionalQueryParameters.Add(New Structure("ParameterName, ParameterValue", AnalyticalDimensionsName + EntryIndex, AnalyticalDimensionsValue));
		EndIf;
		
	EndDo;
	
	If GroupFields Then
		QueryText = QueryText + GroupingTextByFields(GroupingFieldsArray);
		QueryText = StrReplace(QueryText, "&LineNumber", "MIN(&LineNumber)");
	EndIf;
	
	If DataSource.SortByLineNumber Then
		QueryText = StrReplace(QueryText, "&LineNumber", "DataSource__QueryTableName_.LineNumber");
	Else
		QueryText = StrReplace(QueryText, "&LineNumber", "0");
	EndIf;
	
	DefaultAccountStructure = New Structure;
	DefaultAccountStructure.Insert("DefaultAccountTypeParameter"	, "DefaultAccountTypeDr");
	DefaultAccountStructure.Insert("AccountReferenceNameParameter"	, "AccountReferenceNameDr");
	DefaultAccountStructure.Insert("DrCrParameter"					, "DrCrDebit");
	
	ConnectionTextDr = GetDefaultAccountsFilterFields(EntryTemplate, 
		DefaultAccountsTable, 
		EntryIndex, 
		Enums.DebitCredit.Dr,
		DefaultAccountStructure,
		GroupingFieldsArray, 
		"Dr");
	
	DefaultAccountStructure = New Structure;
	DefaultAccountStructure.Insert("DefaultAccountTypeParameter"	, "DefaultAccountTypeCr");
	DefaultAccountStructure.Insert("AccountReferenceNameParameter"	, "AccountReferenceNameCr");
	DefaultAccountStructure.Insert("DrCrParameter"					, "DrCrCredit");
	
	ConnectionTextCr = GetDefaultAccountsFilterFields(EntryTemplate, 
		DefaultAccountsTable, 
		EntryIndex, 
		Enums.DebitCredit.Cr,
		DefaultAccountStructure,
		GroupingFieldsArray, 
		"Cr");
		
	If FilteredTableIndex > 0 Then
		TmpTableName = StrTemplate("Filtered%1%2", DataSource.TempTableName, FilteredTableIndex);
		QueryText = StrReplace(QueryText, "&TempTableName", TmpTableName);
	Else
		QueryText = StrReplace(QueryText, "&TempTableName", DataSource.TempTableName);
	EndIf;
	
	QueryText = StrReplace(QueryText, "_QueryTableName_"			, DataSource.QueryTableName);
	QueryText = StrReplace(QueryText, "_EntryIndex_"				, EntryIndex);
	QueryText = StrReplace(QueryText, "_DocumentAttributesTable_"	, DocumentAttributesTableName);
	QueryText = StrReplace(QueryText, "&AccountsConnectionTextDr"	, ConnectionTextDr);
	QueryText = StrReplace(QueryText, "&AccountsConnectionTextCr"	, ConnectionTextCr);
	
	ReplaceInnerQueryTableNames(QueryText, DataSource.QueryTableName, DataSource.TableSource, "DataSource");
	ReplaceInnerQueryTableNames(QueryText, DocumentAttributesTableName, "Document", "Doc");
	
	Return QueryText;
	
EndFunction

Function TransactionsEntriesConditionsQueryText(Entry, DocumentAttributesTableName, EntryFiltersText, ParametersMap, IsFirstEntry, IsMasterAccounting)
	
	EntryFiltersText = ?(ValueIsFilled(EntryFiltersText), EntryFiltersText, "TRUE");
	
	QueryText =
	"SELECT
	|	&TransactionTemplate_Index AS TransactionTemplate,
	|	&TransactionTemplateLineNumber_EntryIndex AS TransactionTemplateLineNumber
	|INTO ConditionedEntriesTable_NamePrefix 
	|FROM
	|	_DocumentAttributesTable_ AS Doc__DocumentAttributesTable_
	|	INNER JOIN AccountingPolicy AS AccountingPolicy
	|	ON (TRUE)
	|	INNER JOIN ConstantsTable AS Constant
	|	ON (TRUE)
	|WHERE
	|	&EntryFilters";
	
	QueryText = StrReplace(QueryText, "_DocumentAttributesTable_", DocumentAttributesTableName);
	QueryText = StrReplace(QueryText, "&EntryFilters", EntryFiltersText);
	If Not IsFirstEntry Then
		QueryText = StrReplace(QueryText, "INTO ConditionedEntriesTable_NamePrefix", "");
	Else
		TablePrefixedName = ?(IsMasterAccounting, "ConditionedEntriesTableMaster", "ConditionedEntriesTable");
		QueryText = StrReplace(QueryText, "ConditionedEntriesTable_NamePrefix", TablePrefixedName);
	EndIf;

	ParamIndex = ParametersMap.Count();
	
	TemplParamName		= StrTemplate("TransactionTemplate%1", ParamIndex);
	LineNumberParamName = StrTemplate("TransactionTemplateLineNumber%1", ParamIndex + 1);
	
	QueryText = StrReplace(QueryText, "TransactionTemplate_Index", TemplParamName);
	QueryText = StrReplace(QueryText, "TransactionTemplateLineNumber_EntryIndex", LineNumberParamName);
	
	ParametersMap.Insert(TemplParamName		, Entry.TransactionTemplate);
	ParametersMap.Insert(LineNumberParamName, Entry.LineNumber);
	
	ReplaceInnerQueryTableNames(QueryText, DocumentAttributesTableName, "Document", "Doc");
	
	Return QueryText;
	
EndFunction

Function TransactionsEntriesFilteredQueryText(IsMasterAccounting)
	
	QueryText =
	"SELECT
	|	ConditionedEntriesTable.TransactionTemplate AS TransactionTemplate,
	|	ConditionedEntriesTable.TransactionTemplateLineNumber AS TransactionTemplateLineNumber
	|INTO ConditionedEntriesTable
	|FROM
	|	&ConditionedEntriesTable AS ConditionedEntriesTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountingEntriesSimple.Ref AS Ref,
	|	AccountingEntriesSimple.LineNumber AS LineNumber,
	|	AccountingEntriesSimple.EntriesTemplate AS EntriesTemplate,
	|	AccountingEntriesSimple.Mode AS Mode,
	|	AccountingEntriesSimple.DataSource AS DataSource,
	|	AccountingEntriesSimple.Period AS Period,
	|	AccountingEntriesSimple.PeriodAggregateFunction AS PeriodAggregateFunction,
	|	AccountingEntriesSimple.Content AS Content,
	|	AccountingEntriesSimple.Amount AS Amount,
	|	AccountingEntriesSimple.AccountCr AS AccountCr,
	|	AccountingEntriesSimple.AccountDr AS AccountDr,
	|	AccountingEntriesSimple.AmountCurDr AS AmountCurDr,
	|	AccountingEntriesSimple.AmountCurCr AS AmountCurCr,
	|	AccountingEntriesSimple.DefaultAccountTypeCr AS DefaultAccountTypeCr,
	|	AccountingEntriesSimple.DefaultAccountTypeDr AS DefaultAccountTypeDr,
	|	AccountingEntriesSimple.AccountReferenceNameCr AS AccountReferenceNameCr,
	|	AccountingEntriesSimple.AccountReferenceNameDr AS AccountReferenceNameDr,
	|	AccountingEntriesSimple.AnalyticalDimensionsCr1 AS AnalyticalDimensionsCr1,
	|	AccountingEntriesSimple.AnalyticalDimensionsCr2 AS AnalyticalDimensionsCr2,
	|	AccountingEntriesSimple.AnalyticalDimensionsCr3 AS AnalyticalDimensionsCr3,
	|	AccountingEntriesSimple.AnalyticalDimensionsCr4 AS AnalyticalDimensionsCr4,
	|	AccountingEntriesSimple.AnalyticalDimensionsDr1 AS AnalyticalDimensionsDr1,
	|	AccountingEntriesSimple.AnalyticalDimensionsDr2 AS AnalyticalDimensionsDr2,
	|	AccountingEntriesSimple.AnalyticalDimensionsDr3 AS AnalyticalDimensionsDr3,
	|	AccountingEntriesSimple.AnalyticalDimensionsDr4 AS AnalyticalDimensionsDr4,
	|	AccountingEntriesSimple.CurrencyCr AS CurrencyCr,
	|	AccountingEntriesSimple.CurrencyDr AS CurrencyDr,
	|	AccountingEntriesSimple.AnalyticalDimensionsSetCr AS AnalyticalDimensionsSetCr,
	|	AccountingEntriesSimple.AnalyticalDimensionsSetDr AS AnalyticalDimensionsSetDr,
	|	AccountingEntriesSimple.QuantityCr AS QuantityCr,
	|	AccountingEntriesSimple.QuantityDr AS QuantityDr,
	|	AccountingEntriesSimple.ConnectionKey AS ConnectionKey,
	|	0 AS RowID,
	|	AccountingEntriesSimple.Ref AS TransactionTemplate,
	|	AccountingEntriesSimple.LineNumber AS TransactionTemplateLineNumber,
	|	AccountingEntriesSimple.Ref.TypeOfAccounting AS TypeOfAccounting,
	|	AccountingEntriesSimple.TemplateNumber AS TemplateNumber,
	|	AccountingEntriesSimple.EntryLineNumber AS EntryLineNumber,
	|	CASE
	|		WHEN VALUETYPE(AccountingEntriesSimple.AccountCr) = TYPE(Catalog.DefaultGLAccounts)
	|			THEN AccountingEntriesSimple.AccountCr.GLAccount.Currency
	|		ELSE ISNULL(AccountingEntriesSimple.AccountCr.Currency, TRUE)
	|	END AS MultiCurrencyCr,
	|	CASE
	|		WHEN VALUETYPE(AccountingEntriesSimple.AccountDr) = TYPE(Catalog.DefaultGLAccounts)
	|			THEN AccountingEntriesSimple.AccountDr.GLAccount.Currency
	|		ELSE ISNULL(AccountingEntriesSimple.AccountDr.Currency, TRUE)
	|	END AS MultiCurrencyDr,
	|	CASE
	|		WHEN VALUETYPE(AccountingEntriesSimple.AccountCr) = TYPE(Catalog.DefaultGLAccounts)
	|			THEN FALSE
	|		ELSE ISNULL(AccountingEntriesSimple.AccountCr.Quantity, TRUE)
	|	END AS UseQuantityCr,
	|	CASE
	|		WHEN VALUETYPE(AccountingEntriesSimple.AccountDr) = TYPE(Catalog.DefaultGLAccounts)
	|			THEN FALSE
	|		ELSE ISNULL(AccountingEntriesSimple.AccountDr.Quantity, TRUE)
	|	END AS UseQuantityDr,
	|	NULL AS Account,
	|	NULL AS DefaultAccountType,
	|	NULL AS AccountReferenceName,
	|	NULL AS AmountCur,
	|	NULL AS AnalyticalDimensions1,
	|	NULL AS AnalyticalDimensions2,
	|	NULL AS AnalyticalDimensions3,
	|	NULL AS AnalyticalDimensions4,
	|	NULL AS Currency,
	|	NULL AS DimensionsSet,
	|	NULL AS Quantity,
	|	FALSE AS MultiCurrency,
	|	FALSE AS UseQuantity,
	|	NULL AS RecordType,
	|	AccountingEntriesSimple.Ref.ChartOfAccounts.TypeOfEntries AS TypeOfEntries,
	|	NULL AS AnalyticalDimensionsType1,
	|	NULL AS AnalyticalDimensionsType2,
	|	NULL AS AnalyticalDimensionsType3,
	|	NULL AS AnalyticalDimensionsType4,
	|	AccountingEntriesSimple.AnalyticalDimensionsTypeCr1 AS AnalyticalDimensionsTypeCr1,
	|	AccountingEntriesSimple.AnalyticalDimensionsTypeCr2 AS AnalyticalDimensionsTypeCr2,
	|	AccountingEntriesSimple.AnalyticalDimensionsTypeCr3 AS AnalyticalDimensionsTypeCr3,
	|	AccountingEntriesSimple.AnalyticalDimensionsTypeCr4 AS AnalyticalDimensionsTypeCr4,
	|	AccountingEntriesSimple.AnalyticalDimensionsTypeDr1 AS AnalyticalDimensionsTypeDr1,
	|	AccountingEntriesSimple.AnalyticalDimensionsTypeDr2 AS AnalyticalDimensionsTypeDr2,
	|	AccountingEntriesSimple.AnalyticalDimensionsTypeDr3 AS AnalyticalDimensionsTypeDr3,
	|	AccountingEntriesSimple.AnalyticalDimensionsTypeDr4 AS AnalyticalDimensionsTypeDr4
	|FROM
	|	Catalog.AccountingTransactionsTemplates.EntriesSimple AS AccountingEntriesSimple
	|		INNER JOIN ConditionedEntriesTable AS ConditionedEntriesTable
	|		ON AccountingEntriesSimple.Ref = ConditionedEntriesTable.TransactionTemplate
	|			AND AccountingEntriesSimple.LineNumber = ConditionedEntriesTable.TransactionTemplateLineNumber
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingEntries.Ref,
	|	AccountingEntries.LineNumber,
	|	AccountingEntries.EntriesTemplate,
	|	AccountingEntries.Mode,
	|	AccountingEntries.DataSource,
	|	AccountingEntries.Period,
	|	AccountingEntries.PeriodAggregateFunction,
	|	AccountingEntries.Content,
	|	AccountingEntries.Amount,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	AccountingEntries.ConnectionKey,
	|	0,
	|	AccountingEntries.Ref,
	|	AccountingEntries.LineNumber,
	|	AccountingEntries.Ref.TypeOfAccounting,
	|	AccountingEntries.TemplateNumber,
	|	AccountingEntries.EntryLineNumber,
	|	FALSE,
	|	FALSE,
	|	FALSE,
	|	FALSE,
	|	AccountingEntries.Account,
	|	AccountingEntries.DefaultAccountType,
	|	AccountingEntries.AccountReferenceName,
	|	AccountingEntries.AmountCur,
	|	AccountingEntries.AnalyticalDimensions1,
	|	AccountingEntries.AnalyticalDimensions2,
	|	AccountingEntries.AnalyticalDimensions3,
	|	AccountingEntries.AnalyticalDimensions4,
	|	AccountingEntries.Currency,
	|	AccountingEntries.AnalyticalDimensionsSet,
	|	AccountingEntries.Quantity,
	|	ISNULL(AccountingEntries.Account.Currency, TRUE),
	|	ISNULL(AccountingEntries.Account.Quantity, TRUE),
	|	AccountingEntries.DrCr,
	|	AccountingEntries.Ref.ChartOfAccounts.TypeOfEntries,
	|	AccountingEntries.AnalyticalDimensionsType1,
	|	AccountingEntries.AnalyticalDimensionsType2,
	|	AccountingEntries.AnalyticalDimensionsType3,
	|	AccountingEntries.AnalyticalDimensionsType4,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL
	|FROM
	|	Catalog.AccountingTransactionsTemplates.Entries AS AccountingEntries
	|		INNER JOIN ConditionedEntriesTable AS ConditionedEntriesTable
	|		ON AccountingEntries.Ref = ConditionedEntriesTable.TransactionTemplate
	|			AND AccountingEntries.LineNumber = ConditionedEntriesTable.TransactionTemplateLineNumber
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingEntriesSimple.Ref,
	|	AccountingEntriesSimple.LineNumber,
	|	AccountingEntriesSimple.Ref,
	|	AccountingEntriesSimple.Mode,
	|	AccountingEntriesSimple.DataSource,
	|	AccountingEntriesSimple.Period,
	|	AccountingEntriesSimple.PeriodAggregateFunction,
	|	AccountingEntriesSimple.Content,
	|	AccountingEntriesSimple.Amount,
	|	AccountingEntriesSimple.AccountCr,
	|	AccountingEntriesSimple.AccountDr,
	|	AccountingEntriesSimple.AmountCurDr,
	|	AccountingEntriesSimple.AmountCurCr,
	|	AccountingEntriesSimple.DefaultAccountTypeCr,
	|	AccountingEntriesSimple.DefaultAccountTypeDr,
	|	AccountingEntriesSimple.AccountReferenceNameCr,
	|	AccountingEntriesSimple.AccountReferenceNameDr,
	|	AccountingEntriesSimple.AnalyticalDimensionsCr1,
	|	AccountingEntriesSimple.AnalyticalDimensionsCr2,
	|	AccountingEntriesSimple.AnalyticalDimensionsCr3,
	|	AccountingEntriesSimple.AnalyticalDimensionsCr4,
	|	AccountingEntriesSimple.AnalyticalDimensionsDr1,
	|	AccountingEntriesSimple.AnalyticalDimensionsDr2,
	|	AccountingEntriesSimple.AnalyticalDimensionsDr3,
	|	AccountingEntriesSimple.AnalyticalDimensionsDr4,
	|	AccountingEntriesSimple.CurrencyCr,
	|	AccountingEntriesSimple.CurrencyDr,
	|	AccountingEntriesSimple.AnalyticalDimensionsSetCr,
	|	AccountingEntriesSimple.AnalyticalDimensionsSetDr,
	|	AccountingEntriesSimple.QuantityCr,
	|	AccountingEntriesSimple.QuantityDr,
	|	AccountingEntriesSimple.ConnectionKey,
	|	0,
	|	AccountingEntriesSimple.Ref,
	|	AccountingEntriesSimple.LineNumber,
	|	AccountingEntriesSimple.Ref.TypeOfAccounting,
	|	AccountingEntriesSimple.Ref.Code,
	|	AccountingEntriesSimple.LineNumber,
	|	CASE
	|		WHEN VALUETYPE(AccountingEntriesSimple.AccountCr) = TYPE(Catalog.DefaultGLAccounts)
	|			THEN AccountingEntriesSimple.AccountCr.GLAccount.Currency
	|		ELSE ISNULL(AccountingEntriesSimple.AccountCr.Currency, TRUE)
	|	END,
	|	CASE
	|		WHEN VALUETYPE(AccountingEntriesSimple.AccountDr) = TYPE(Catalog.DefaultGLAccounts)
	|			THEN AccountingEntriesSimple.AccountDr.GLAccount.Currency
	|		ELSE ISNULL(AccountingEntriesSimple.AccountDr.Currency, TRUE)
	|	END,
	|	CASE
	|		WHEN VALUETYPE(AccountingEntriesSimple.AccountCr) = TYPE(Catalog.DefaultGLAccounts)
	|			THEN FALSE
	|		ELSE ISNULL(AccountingEntriesSimple.AccountCr.Quantity, TRUE)
	|	END,
	|	CASE
	|		WHEN VALUETYPE(AccountingEntriesSimple.AccountDr) = TYPE(Catalog.DefaultGLAccounts)
	|			THEN FALSE
	|		ELSE ISNULL(AccountingEntriesSimple.AccountDr.Quantity, TRUE)
	|	END,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	FALSE,
	|	FALSE,
	|	NULL,
	|	AccountingEntriesSimple.Ref.ChartOfAccounts.TypeOfEntries,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	AccountingEntriesSimple.AnalyticalDimensionsTypeCr1,
	|	AccountingEntriesSimple.AnalyticalDimensionsTypeCr2,
	|	AccountingEntriesSimple.AnalyticalDimensionsTypeCr3,
	|	AccountingEntriesSimple.AnalyticalDimensionsTypeCr4,
	|	AccountingEntriesSimple.AnalyticalDimensionsTypeDr1,
	|	AccountingEntriesSimple.AnalyticalDimensionsTypeDr2,
	|	AccountingEntriesSimple.AnalyticalDimensionsTypeDr3,
	|	AccountingEntriesSimple.AnalyticalDimensionsTypeDr4
	|FROM
	|	Catalog.AccountingEntriesTemplates.EntriesSimple AS AccountingEntriesSimple
	|		INNER JOIN ConditionedEntriesTable AS ConditionedEntriesTable
	|		ON AccountingEntriesSimple.Ref = ConditionedEntriesTable.TransactionTemplate
	|			AND AccountingEntriesSimple.LineNumber = ConditionedEntriesTable.TransactionTemplateLineNumber
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingEntries.Ref,
	|	AccountingEntries.LineNumber,
	|	AccountingEntries.Ref,
	|	AccountingEntries.Mode,
	|	AccountingEntries.DataSource,
	|	AccountingEntries.Period,
	|	AccountingEntries.PeriodAggregateFunction,
	|	AccountingEntries.Content,
	|	AccountingEntries.Amount,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	AccountingEntries.ConnectionKey,
	|	0,
	|	AccountingEntries.Ref,
	|	AccountingEntries.LineNumber,
	|	AccountingEntries.Ref.TypeOfAccounting,
	|	AccountingEntries.Ref.Code,
	|	AccountingEntries.LineNumber,
	|	FALSE,
	|	FALSE,
	|	FALSE,
	|	FALSE,
	|	AccountingEntries.Account,
	|	AccountingEntries.DefaultAccountType,
	|	AccountingEntries.AccountReferenceName,
	|	AccountingEntries.AmountCur,
	|	AccountingEntries.AnalyticalDimensions1,
	|	AccountingEntries.AnalyticalDimensions2,
	|	AccountingEntries.AnalyticalDimensions3,
	|	AccountingEntries.AnalyticalDimensions4,
	|	AccountingEntries.Currency,
	|	AccountingEntries.AnalyticalDimensionsSet,
	|	AccountingEntries.Quantity,
	|	ISNULL(AccountingEntries.Account.Currency, TRUE),
	|	ISNULL(AccountingEntries.Account.Quantity, TRUE),
	|	AccountingEntries.DrCr,
	|	AccountingEntries.Ref.ChartOfAccounts.TypeOfEntries,
	|	AccountingEntries.AnalyticalDimensionsType1,
	|	AccountingEntries.AnalyticalDimensionsType2,
	|	AccountingEntries.AnalyticalDimensionsType3,
	|	AccountingEntries.AnalyticalDimensionsType4,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL
	|FROM
	|	Catalog.AccountingEntriesTemplates.Entries AS AccountingEntries
	|		INNER JOIN ConditionedEntriesTable AS ConditionedEntriesTable
	|		ON AccountingEntries.Ref = ConditionedEntriesTable.TransactionTemplate
	|			AND AccountingEntries.LineNumber = ConditionedEntriesTable.TransactionTemplateLineNumber";
	
	TablePrefixedName = ?(IsMasterAccounting, "ConditionedEntriesTableMaster", "ConditionedEntriesTable");
	QueryText = StrReplace(QueryText, "&ConditionedEntriesTable", TablePrefixedName);
	
	Return QueryText;
	
EndFunction 

Function GroupingTextByFields(GroupingFieldsArray)

	GroupByText = 
	"
	|GROUP BY
	|";
	
	FirstField = True;
	
	For Each Field In GroupingFieldsArray Do
		
		If FirstField Then
			FirstField = False;
			GroupByText = GroupByText + Field;
		Else
			GroupByText = GroupByText + ", " + Field;
		EndIf;
	EndDo;

	Return GroupByText;
	
EndFunction

Function AccountingEntriesDataTempTableQueryText(DataSource)
	
	QueryText = 
	"SELECT	*
	|INTO &TempTableName
	|FROM
	|	&RegisterRecordsTableName AS RegisterRecordsTableName";
				
	QueryText = StrReplace(QueryText, "&TempTableName"				, DataSource.TempTableName);
	QueryText = StrReplace(QueryText, "RegisterRecordsTableName"	, DataSource.RegisterRecordsTableName);
		
	Return QueryText;
	
EndFunction 

Function SimpleRegisterEmptyTableQueryText()

	Return 
	"SELECT TOP 0
	|	AccountingJournalEntriesSimple.Period AS Period,
	|	AccountingJournalEntriesSimple.Recorder AS Recorder,
	|	AccountingJournalEntriesSimple.LineNumber AS LineNumber,
	|	AccountingJournalEntriesSimple.Active AS Active,
	|	AccountingJournalEntriesSimple.AccountDr AS AccountDr,
	|	AccountingJournalEntriesSimple.AccountCr AS AccountCr,
	|	AccountingJournalEntriesSimple.Company AS Company,
	|	AccountingJournalEntriesSimple.PlanningPeriod AS PlanningPeriod,
	|	AccountingJournalEntriesSimple.CurrencyDr AS CurrencyDr,
	|	AccountingJournalEntriesSimple.CurrencyCr AS CurrencyCr,
	|	AccountingJournalEntriesSimple.Status AS Status,
	|	AccountingJournalEntriesSimple.TypeOfAccounting AS TypeOfAccounting,
	|	AccountingJournalEntriesSimple.Amount AS Amount,
	|	AccountingJournalEntriesSimple.AmountCurDr AS AmountCurDr,
	|	AccountingJournalEntriesSimple.AmountCurCr AS AmountCurCr,
	|	AccountingJournalEntriesSimple.QuantityDr AS QuantityDr,
	|	AccountingJournalEntriesSimple.QuantityCr AS QuantityCr,
	|	AccountingJournalEntriesSimple.Content AS Content,
	|	AccountingJournalEntriesSimple.OfflineRecord AS OfflineRecord,
	|	AccountingJournalEntriesSimple.TransactionTemplate AS TransactionTemplate,
	|	AccountingJournalEntriesSimple.TransactionTemplateLineNumber AS TransactionTemplateLineNumber
	|FROM
	|	AccountingRegister.AccountingJournalEntriesSimple AS AccountingJournalEntriesSimple";

EndFunction

Function CompoundRegisterEmptyTableQueryText()

	Return 
	"SELECT TOP 0
	|	AccountingJournalEntriesCompound.Period AS Period,
	|	AccountingJournalEntriesCompound.Recorder AS Recorder,
	|	AccountingJournalEntriesCompound.LineNumber AS LineNumber,
	|	AccountingJournalEntriesCompound.Active AS Active,
	|	AccountingJournalEntriesCompound.RecordType AS RecordType,
	|	AccountingJournalEntriesCompound.Account AS Account,
	|	AccountingJournalEntriesCompound.Company AS Company,
	|	AccountingJournalEntriesCompound.PlanningPeriod AS PlanningPeriod,
	|	AccountingJournalEntriesCompound.Currency AS Currency,
	|	AccountingJournalEntriesCompound.Status AS Status,
	|	AccountingJournalEntriesCompound.TypeOfAccounting AS TypeOfAccounting,
	|	AccountingJournalEntriesCompound.Amount AS Amount,
	|	AccountingJournalEntriesCompound.AmountCur AS AmountCur,
	|	AccountingJournalEntriesCompound.Quantity AS Quantity,
	|	AccountingJournalEntriesCompound.Content AS Content,
	|	AccountingJournalEntriesCompound.OfflineRecord AS OfflineRecord,
	|	AccountingJournalEntriesCompound.TransactionTemplate AS TransactionTemplate,
	|	AccountingJournalEntriesCompound.TransactionTemplateLineNumber AS TransactionTemplateLineNumber
	|FROM
	|	AccountingRegister.AccountingJournalEntriesCompound AS AccountingJournalEntriesCompound";
	
EndFunction

Function GetQueryOrderText()

	Return "
	|ORDER BY 
	|	TransactionTemplate,
	|	TransactionTemplateLineNumber,
	|	LineNumber";

EndFunction

Function DefaultAccountsEmptyDataSourceQueryText(IsMasterAccounting, FirstDefaultAccount, EntryTemplate, EntryIndex, DocumentAttributesTableName, FilteredTableIndex, Fields)
	
	QueryText = 
	"SELECT DISTINCT
	|	&Fields
	|INTO DefaultAccountsFilters
	|FROM
	|	_DocumetntAttributesTable_ AS _DocumetntAttributesTable_";
	
	GroupFields = (EntryTemplate.Mode = Enums.AccountingEntriesDataSourceModes.Combined);
	GroupingFieldsArray = New Array;
	
	If Not FirstDefaultAccount Then
		QueryText = StrReplace(QueryText, "INTO DefaultAccountsFilters", "");
	ElsIf IsMasterAccounting Then
		QueryText = StrReplace(QueryText, "INTO DefaultAccountsFilters", "INTO MasterDefaultAccountsFilters");
	EndIf;
	
	QueryText = StrReplace(QueryText, "&Fields"						, Fields);
	QueryText = StrReplace(QueryText, "_Filtered_"					, ?(FilteredTableIndex > 0, "Filtered", ""));
	QueryText = StrReplace(QueryText, "_Index_"						, ?(FilteredTableIndex > 0, FilteredTableIndex, ""));
	QueryText = StrReplace(QueryText, "_EntryIndex_"				, EntryIndex);
	QueryText = StrReplace(QueryText, "_DocumetntAttributesTable_"	, DocumentAttributesTableName);
	
	ReplaceInnerQueryTableNames(QueryText, DocumentAttributesTableName, "Document", "Doc");
	
	Return QueryText;

EndFunction

Function PrimaryAccountingEntryEmptyDataSourceQueryText(EntryTemplate, EntryIndex, DocumentAttributesTableName, EntryFiltersText, DefaultAccountsTable)

	QueryText = 
	"SELECT
	|	0 AS LineNumber,
	|	&TransactionTemplate_EntryIndex_ AS TransactionTemplate,
	|	&TransactionTemplateLineNumber_EntryIndex_ AS TransactionTemplateLineNumber,
	|	&TypeOfAccounting_EntryIndex_ AS TypeOfAccounting,
	|	&Period AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&AccountDr_EntryIndex_ AS AccountDr,
	|	&AccountCr_EntryIndex_ AS AccountCr,
	|	&CurrencyDr AS CurrencyDr,
	|	&AmountCurDr AS AmountCurDr,
	|	&CurrencyCr AS CurrencyCr,
	|	&AmountCurCr AS AmountCurCr,
	|	&Amount AS Amount,
	|	&Content AS Content,
	|	FALSE AS OfflineRecord,
	|	&AccountsConnectionTextDr,
	|	&AccountsConnectionTextCr
	|FROM
	|	_DocumentAttributesTable_ AS Doc__DocumentAttributesTable_
	|		INNER JOIN AccountingPolicy AS AccountingPolicy
	|		ON (TRUE)
	|		INNER JOIN ConstantsTable AS Constant
	|		ON (TRUE)
	|WHERE
	|	&EntryFilters";
	
	GroupFields = (EntryTemplate.Mode = Enums.AccountingEntriesDataSourceModes.Combined);
	GroupingFieldsArray = New Array;
	
	DefaultAccountStructure = New Structure;
	DefaultAccountStructure.Insert("DefaultAccountTypeParameter"	, "DefaultAccountTypeCr");
	DefaultAccountStructure.Insert("AccountReferenceNameParameter"	, "AccountReferenceNameCr");
	DefaultAccountStructure.Insert("DrCrParameter"					, "DrCrCredit");
	
	ConnectionTextCr = GetDefaultAccountsFilterFields(EntryTemplate, 
		DefaultAccountsTable, 
		EntryIndex, 
		Enums.DebitCredit.Cr,
		DefaultAccountStructure,
		GroupingFieldsArray,
		"Cr");
		
	DefaultAccountStructure = New Structure;
	DefaultAccountStructure.Insert("DefaultAccountTypeParameter"	, "DefaultAccountTypeDr");
	DefaultAccountStructure.Insert("AccountReferenceNameParameter"	, "AccountReferenceNameDr");
	DefaultAccountStructure.Insert("DrCrParameter"					, "DrCrDebit");
	
	ConnectionTextDr = GetDefaultAccountsFilterFields(EntryTemplate, 
		DefaultAccountsTable, 
		EntryIndex, 
		Enums.DebitCredit.Dr,
		DefaultAccountStructure,
		GroupingFieldsArray,
		"Dr");
		
	InsertDataSourceField(QueryText, "Period"		, EntryTemplate, False, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "CurrencyDr"	, EntryTemplate, False, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "CurrencyCr"	, EntryTemplate, False, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "AmountCurDr"	, EntryTemplate, GroupFields, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "AmountCurCr"	, EntryTemplate, GroupFields, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "Amount"		, EntryTemplate, GroupFields, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "Content"		, EntryTemplate, False, False, GroupingFieldsArray);
	
	QueryText = StrReplace(QueryText, "_DocumentAttributesTable_"	, DocumentAttributesTableName);
	QueryText = StrReplace(QueryText, "&EntryFilters"				, ?(ValueIsFilled(EntryFiltersText), EntryFiltersText, "TRUE"));
	QueryText = StrReplace(QueryText, "_EntryIndex_"				, EntryIndex);
	QueryText = StrReplace(QueryText, "&AccountsConnectionTextDr"	, ConnectionTextDr);
	QueryText = StrReplace(QueryText, "&AccountsConnectionTextCr"	, ConnectionTextCr);
	
	ReplaceInnerQueryTableNames(QueryText, DocumentAttributesTableName, "Document", "Doc");
	
	Return QueryText;
	
EndFunction 

Function MasterAccountingEntryEmptyDataSourceQueryText(EntryTemplate, EntryIndex, DocumentAttributesTableName, EntryFiltersText, DefaultAccountsTable, AdditionalQueryParameters)
	
	If EntryTemplate.TypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Compound Then
		Return CompoundAccountingEntryEmptyDataSourceQueryText(
			EntryTemplate,
			EntryIndex,
			DocumentAttributesTableName,
			EntryFiltersText, 
			DefaultAccountsTable,
			AdditionalQueryParameters);
	Else
		Return SimpleAccountingEntryEmptyDataSourceQueryText(
			EntryTemplate,
			EntryIndex,
			DocumentAttributesTableName,
			EntryFiltersText, 
			DefaultAccountsTable,
			AdditionalQueryParameters);
	EndIf;
	
EndFunction

Function SimpleAccountingEntryEmptyDataSourceQueryText(EntryTemplate, EntryIndex, DocumentAttributesTableName, EntryFiltersText, DefaultAccountsTable, AdditionalQueryParameters)

	QueryText = 
	"SELECT
	|	0 AS LineNumber,
	|	&TransactionTemplate_EntryIndex_ AS TransactionTemplate,
	|	&TransactionTemplateLineNumber_EntryIndex_ AS TransactionTemplateLineNumber,
	|	&TypeOfAccounting_EntryIndex_ AS TypeOfAccounting,
	|	&Period AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&AccountDr_EntryIndex_ AS AccountDr,
	|	&AccountCr_EntryIndex_ AS AccountCr,
	|	&CurrencyDr AS CurrencyDr,
	|	&AmountCurDr AS AmountCurDr,
	|	&CurrencyCr AS CurrencyCr,
	|	&AmountCurCr AS AmountCurCr,
	|	&Amount AS Amount,
	|	&QuantityDr AS QuantityDr,
	|	&QuantityCr As QuantityCr,
	|	&Content AS Content,
	|	FALSE AS OfflineRecord,
	|	&AnalyticalDimensionsDr1 AS ExtDimensionDr1,
	|	&AnalyticalDimensionsDr2 AS ExtDimensionDr2,
	|	&AnalyticalDimensionsDr3 AS ExtDimensionDr3,
	|	&AnalyticalDimensionsDr4 AS ExtDimensionDr4,
	|	&AnalyticalDimensionsTypeDr1_EntryIndex_ AS ExtDimensionTypeDr1,
	|	&AnalyticalDimensionsTypeDr2_EntryIndex_ AS ExtDimensionTypeDr2,
	|	&AnalyticalDimensionsTypeDr3_EntryIndex_ AS ExtDimensionTypeDr3,
	|	&AnalyticalDimensionsTypeDr4_EntryIndex_ AS ExtDimensionTypeDr4,
	|	&AnalyticalDimensionsCr1 AS ExtDimensionCr1,
	|	&AnalyticalDimensionsCr2 AS ExtDimensionCr2,
	|	&AnalyticalDimensionsCr3 AS ExtDimensionCr3,
	|	&AnalyticalDimensionsCr4 AS ExtDimensionCr4,
	|	&AnalyticalDimensionsTypeCr1_EntryIndex_ AS ExtDimensionTypeCr1,
	|	&AnalyticalDimensionsTypeCr2_EntryIndex_ AS ExtDimensionTypeCr2,
	|	&AnalyticalDimensionsTypeCr3_EntryIndex_ AS ExtDimensionTypeCr3,
	|	&AnalyticalDimensionsTypeCr4_EntryIndex_ AS ExtDimensionTypeCr4,
	|	&AccountsConnectionTextDr,
	|	&AccountsConnectionTextCr
	|FROM
	|	_DocumentAttributesTable_ AS Doc__DocumentAttributesTable_
	|		INNER JOIN AccountingPolicy AS AccountingPolicy
	|		ON (TRUE)
	|		INNER JOIN ConstantsTable AS Constant
	|		ON (TRUE)
	|WHERE
	|	&EntryFilters";
	
	GroupFields = (EntryTemplate.Mode = Enums.AccountingEntriesDataSourceModes.Combined);
	GroupingFieldsArray = New Array;
	
	DefaultAccountStructure = New Structure;
	DefaultAccountStructure.Insert("DefaultAccountTypeParameter"	, "DefaultAccountTypeCr");
	DefaultAccountStructure.Insert("AccountReferenceNameParameter"	, "AccountReferenceNameCr");
	DefaultAccountStructure.Insert("DrCrParameter"					, "DrCrCredit");
	
	ConnectionTextCr = GetDefaultAccountsFilterFields(EntryTemplate, 
		DefaultAccountsTable, 
		EntryIndex, 
		Enums.DebitCredit.Cr,
		DefaultAccountStructure,
		GroupingFieldsArray,
		"Cr");
		
	DefaultAccountStructure = New Structure;
	DefaultAccountStructure.Insert("DefaultAccountTypeParameter"	, "DefaultAccountTypeDr");
	DefaultAccountStructure.Insert("AccountReferenceNameParameter"	, "AccountReferenceNameDr");
	DefaultAccountStructure.Insert("DrCrParameter"					, "DrCrDebit");
	
	ConnectionTextDr = GetDefaultAccountsFilterFields(EntryTemplate, 
		DefaultAccountsTable, 
		EntryIndex, 
		Enums.DebitCredit.Dr,
		DefaultAccountStructure,
		GroupingFieldsArray,
		"Dr");
		
	InsertDataSourceField(QueryText, "Period"		, EntryTemplate, False, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "CurrencyDr"	, EntryTemplate, False, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "CurrencyCr"	, EntryTemplate, False, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "AmountCurDr"	, EntryTemplate, GroupFields, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "AmountCurCr"	, EntryTemplate, GroupFields, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "Amount"		, EntryTemplate, GroupFields, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "QuantityDr"	, EntryTemplate, False, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "QuantityCr"	, EntryTemplate, False, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "Content"		, EntryTemplate, False, False, GroupingFieldsArray);
	
	MaxAnalyticalDimensionsNumber = ChartsOfAccounts.MasterChartOfAccounts.MaxAnalyticalDimensionsNumber();
	For Index = 1 To MaxAnalyticalDimensionsNumber Do // Dr
		
		AnalyticalDimensionsName	= "AnalyticalDimensionsDr" + Index;
		AnalyticalDimensionsValue	= EntryTemplate[AnalyticalDimensionsName];
		If TypeOf(AnalyticalDimensionsValue) = Type("String") Then
			InsertDataSourceField(QueryText, AnalyticalDimensionsName, EntryTemplate, False, GroupFields, GroupingFieldsArray);
		Else
			QueryText = StrReplace(QueryText, AnalyticalDimensionsName, AnalyticalDimensionsName + EntryIndex);
			AdditionalQueryParameters.Add(New Structure("ParameterName, ParameterValue", AnalyticalDimensionsName + EntryIndex, AnalyticalDimensionsValue));
		EndIf;
		
	EndDo;
	
	For Index = 1 To MaxAnalyticalDimensionsNumber Do // Cr
		
		AnalyticalDimensionsName	= "AnalyticalDimensionsCr" + Index;
		AnalyticalDimensionsValue	= EntryTemplate[AnalyticalDimensionsName];
		If TypeOf(AnalyticalDimensionsValue) = Type("String") Then
			InsertDataSourceField(QueryText, AnalyticalDimensionsName, EntryTemplate, False, GroupFields, GroupingFieldsArray);
		Else
			QueryText = StrReplace(QueryText, AnalyticalDimensionsName, AnalyticalDimensionsName + EntryIndex);
			AdditionalQueryParameters.Add(New Structure("ParameterName, ParameterValue", AnalyticalDimensionsName + EntryIndex, AnalyticalDimensionsValue));
		EndIf;
		
	EndDo;
	
	QueryText = StrReplace(QueryText, "_DocumentAttributesTable_"	, DocumentAttributesTableName);
	QueryText = StrReplace(QueryText, "&EntryFilters"				, ?(ValueIsFilled(EntryFiltersText), EntryFiltersText, "TRUE"));
	QueryText = StrReplace(QueryText, "_EntryIndex_"				, EntryIndex);
	QueryText = StrReplace(QueryText, "&AccountsConnectionTextDr"	, ConnectionTextDr);
	QueryText = StrReplace(QueryText, "&AccountsConnectionTextCr"	, ConnectionTextCr);
	
	ReplaceInnerQueryTableNames(QueryText, DocumentAttributesTableName, "Document", "Doc");
	
	Return QueryText;
	
EndFunction 

Function CompoundAccountingEntryEmptyDataSourceQueryText(EntryTemplate, EntryIndex, DocumentAttributesTableName, EntryFiltersText, DefaultAccountsTable, AdditionalQueryParameters)

	QueryText = 
	"SELECT
	|	&RecordType_EntryIndex_ As RecordType,
	|	0 AS LineNumber,
	|	&TransactionTemplate_EntryIndex_ AS TransactionTemplate,
	|	&TransactionTemplateLineNumber_EntryIndex_ AS TransactionTemplateLineNumber,
	|	&TypeOfAccounting_EntryIndex_ AS TypeOfAccounting,
	|	&Period AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Account_EntryIndex_ AS Account,
	|	&Currency AS Currency,
	|	&AmountCur AS AmountCur,
	|	&Amount AS Amount,
	|	&Quantity AS Quantity,
	|	&Content AS Content,
	|	FALSE AS OfflineRecord,
	|	&AnalyticalDimensions1 AS ExtDimension1,
	|	&AnalyticalDimensions2 AS ExtDimension2,
	|	&AnalyticalDimensions3 AS ExtDimension3,
	|	&AnalyticalDimensions4 AS ExtDimension4,
	|	&AnalyticalDimensionsType1_EntryIndex_ AS ExtDimensionType1,
	|	&AnalyticalDimensionsType2_EntryIndex_ AS ExtDimensionType2,
	|	&AnalyticalDimensionsType3_EntryIndex_ AS ExtDimensionType3,
	|	&AnalyticalDimensionsType4_EntryIndex_ AS ExtDimensionType4,
	|	&AccountsConnectionText
	|FROM
	|	_DocumentAttributesTable_ AS Doc__DocumentAttributesTable_
	|		INNER JOIN AccountingPolicy AS AccountingPolicy
	|		ON (TRUE)
	|		INNER JOIN ConstantsTable AS Constant
	|		ON (TRUE)
	|WHERE
	|	&EntryFilters";
	
	GroupFields = (EntryTemplate.Mode = Enums.AccountingEntriesDataSourceModes.Combined);
	GroupingFieldsArray = New Array;
	
	DefaultAccountStructure = New Structure;
	DefaultAccountStructure.Insert("DefaultAccountTypeParameter"	, "DefaultAccountType");
	DefaultAccountStructure.Insert("AccountReferenceNameParameter"	, "AccountReferenceName");
	DefaultAccountStructure.Insert("DrCrParameter"					, "DrCrEmpty");
	
	ConnectionText = GetDefaultAccountsFilterFields(EntryTemplate, 
		DefaultAccountsTable, 
		EntryIndex, 
		Enums.DebitCredit.EmptyRef(),
		DefaultAccountStructure,
		GroupingFieldsArray,
		"");
		
	InsertDataSourceField(QueryText, "Period"	, EntryTemplate, False, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "Currency"	, EntryTemplate, False, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "AmountCur", EntryTemplate, GroupFields, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "Amount"	, EntryTemplate, GroupFields, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "Quantity"	, EntryTemplate, False, GroupFields, GroupingFieldsArray);
	InsertDataSourceField(QueryText, "Content"	, EntryTemplate, False, False, GroupingFieldsArray);
	
	MaxAnalyticalDimensionsNumber = ChartsOfAccounts.MasterChartOfAccounts.MaxAnalyticalDimensionsNumber();
	For Index = 1 To MaxAnalyticalDimensionsNumber Do
		
		AnalyticalDimensionsName	= "AnalyticalDimensions" + Index;
		AnalyticalDimensionsValue	= EntryTemplate[AnalyticalDimensionsName];
		If TypeOf(AnalyticalDimensionsValue) = Type("String") Then
			InsertDataSourceField(QueryText, AnalyticalDimensionsName, EntryTemplate, False, GroupFields, GroupingFieldsArray);
		Else
			QueryText = StrReplace(QueryText, AnalyticalDimensionsName, AnalyticalDimensionsName + EntryIndex);
			AdditionalQueryParameters.Add(New Structure("ParameterName, ParameterValue", AnalyticalDimensionsName + EntryIndex, AnalyticalDimensionsValue));
		EndIf;
		
	EndDo;
	
	QueryText = StrReplace(QueryText, "_DocumentAttributesTable_" 	, DocumentAttributesTableName);
	QueryText = StrReplace(QueryText, "&EntryFilters"				, ?(ValueIsFilled(EntryFiltersText), EntryFiltersText, "TRUE"));
	QueryText = StrReplace(QueryText, "_EntryIndex_"				, EntryIndex);
	QueryText = StrReplace(QueryText, "&AccountsConnectionText"		, ConnectionText);
	
	ReplaceInnerQueryTableNames(QueryText, DocumentAttributesTableName, "Document", "Doc");
	
	Return QueryText;
	
EndFunction 

#EndRegion

Procedure FillDataSourcesTable(DataSourcesTable, EntriesTable, QueryParametersMap, StructureAdditionalProperties, IsMasterAccounting)
	
	DataSourcesTable = New ValueTable;
	DataSourcesTable.Columns.Add("TemplateRef");
	DataSourcesTable.Columns.Add("EntryConnectionKey");
	DataSourcesTable.Columns.Add("DataSource");
	DataSourcesTable.Columns.Add("TableName");
	DataSourcesTable.Columns.Add("TableSource");
	DataSourcesTable.Columns.Add("TempTableName");
	DataSourcesTable.Columns.Add("QueryTableName");
	DataSourcesTable.Columns.Add("RegisterRecordsTableName");
	DataSourcesTable.Columns.Add("TableNamePrefix");
	DataSourcesTable.Columns.Add("SortByLineNumber");

	For Each EntryTemplate In EntriesTable Do
		
		StructureDataSource = AdjustDataSource(EntryTemplate.DataSource);
		
		NewDataSource = DataSourcesTable.Add();
		NewDataSource.TemplateRef			= EntryTemplate.Ref;
		NewDataSource.EntryConnectionKey	= EntryTemplate.ConnectionKey;
		NewDataSource.DataSource			= EntryTemplate.DataSource;
		NewDataSource.TableName				= StructureDataSource.TableName;
		NewDataSource.QueryTableName		= StructureDataSource.TableName;
		NewDataSource.TableNamePrefix		= ?(IsMasterAccounting, "Master", "");
		NewDataSource.SortByLineNumber 		= False;
		
		If StructureDataSource.SourceName = "AccumulationRegister" Then
			
			NewDataSource.TableSource				= "AccumulationRegister";
			NewDataSource.RegisterRecordsTableName	= StrTemplate("RegisterRecordsTable%1", StructureDataSource.TableName);
			NewDataSource.TempTableName				= StrTemplate(
				"RegisterRecordsTempTable%1%2",
				StructureDataSource.TableName,
				NewDataSource.TableNamePrefix);
			
			TableFullName = StrTemplate("Table%1", StructureDataSource.TableName);
			
			DataSourcesParameter = StructureAdditionalProperties.TableForRegisterRecords[TableFullName];
			
			If DataSourcesParameter.Columns.Find("LineNumber") <> Undefined Then
				NewDataSource.SortByLineNumber = True;
			EndIf;
			
			QueryParametersMap.Insert(
				NewDataSource.RegisterRecordsTableName, 
				DataSourcesParameter);
			
		ElsIf StructureDataSource.SourceName = "TabularSections" Then
			
			NewDataSource.TableSource 	= "TabularSections";
			NewDataSource.TempTableName = StrTemplate(
				"TabSectionTempTable%1%2",
				StructureDataSource.TableName,
				NewDataSource.TableNamePrefix);
				
			NewDataSource.SortByLineNumber = True;
				
		ElsIf StructureDataSource.SourceName = "AccountingEntriesData" Then
			
			NewDataSource.TableSource 	= "AccumulationRegister";
			NewDataSource.RegisterRecordsTableName 	= StrTemplate("AccountingEntriesData%1", StructureDataSource.TableName);
			NewDataSource.TempTableName = StrTemplate(
				"AccountingEntriesDataTempTable%1%2",
				StructureDataSource.TableName,
				NewDataSource.TableNamePrefix);
				
			NewDataSource.TableName 	 = "AccountingEntriesData";
			NewDataSource.QueryTableName = "AccountingEntriesData";
				
			RegisterTable = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingEntriesData; 	
			
			If RegisterTable.Columns.Find("LineNumber") <> Undefined Then
				NewDataSource.SortByLineNumber = True;
			EndIf;
			
			SearchValue = PredefinedValue("Enum.EntryTypes."+StructureDataSource.TableName); 
			
			FindedRows = RegisterTable.FindRows(New Structure("EntryType", SearchValue));
			
			FiltredTable = RegisterTable.Copy(FindedRows);
			
			QueryParametersMap.Insert(
				NewDataSource.RegisterRecordsTableName, 
				FiltredTable);
			
		Else
			// Empty data source
			DataSourcesTable.Delete(NewDataSource);
		EndIf;
	EndDo;
	
EndProcedure 

Function FilterTemplatesTable(TemplatesTable, AccountingSettingsTable, PostingOption, TypeOfAccounting, IsMasterRegister = False)
	
	ApplicableTemplates = New Array;
	
	If IsMasterRegister Then
		CurrentChartOfAccountsEnum = Enums.ChartsOfAccounts.MasterChartOfAccounts;
	Else
		CurrentChartOfAccountsEnum = Enums.ChartsOfAccounts.PrimaryChartOfAccounts;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SettingsTable.ChartOfAccounts AS ChartOfAccounts,
	|	SettingsTable.IsRecorder AS IsRecorder,
	|	SettingsTable.EntriesPostingOption AS EntriesPostingOption,
	|	SettingsTable.TypeOfAccounting AS TypeOfAccounting
	|INTO Settings
	|FROM
	|	&SettingsTable AS SettingsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Settings.ChartOfAccounts AS ChartOfAccounts,
	|	Settings.TypeOfAccounting AS TypeOfAccounting
	|FROM
	|	Settings AS Settings
	|		INNER JOIN Catalog.ChartsOfAccounts AS CatalogChartsOfAccounts
	|		ON Settings.ChartOfAccounts = CatalogChartsOfAccounts.Ref
	|WHERE
	|	Settings.IsRecorder
	|	AND Settings.EntriesPostingOption = &PostingOption
	|	AND CASE
	|			WHEN &TypeOfAccounting <> VALUE(Catalog.TypesOfAccounting.EmptyRef)
	|				THEN Settings.TypeOfAccounting = &TypeOfAccounting
	|			ELSE TRUE
	|		END
	|	AND CatalogChartsOfAccounts.ChartOfAccounts = &ChartOfAccountsEnum";
	
	Query.SetParameter("SettingsTable"		, AccountingSettingsTable);
	Query.SetParameter("PostingOption"		, PostingOption);
	Query.SetParameter("TypeOfAccounting"	, TypeOfAccounting);
	Query.SetParameter("ChartOfAccountsEnum", CurrentChartOfAccountsEnum);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		FilterStr = New Structure("ChartOfAccounts, TypeOfAccounting");
		FillPropertyValues(FilterStr, SelectionDetailRecords);
		
		RowsArray = TemplatesTable.FindRows(FilterStr);
		
		CommonClientServer.SupplementArray(
			ApplicableTemplates,
			TemplatesTable.Copy(RowsArray, "Template").UnloadColumn("Template"),
			True);
		
	EndDo;
	
	Return ApplicableTemplates;

EndFunction

#Region TransactionTemplatesParametersAndAdditionalParameters 

Function GetTransactionsEntriesTable(AccountingTemplatesList, PostingParametersStructure, TempTablesManager, IsMasterAccounting)

	ParametersMap = New Map;
	TemplatesParametersTexts = New Map;
	
	AdditionalParametersTable	= GetAdditionalParametersTable(AccountingTemplatesList);
	AdditionalParametersValues	= GetFilterValuesTable(AccountingTemplatesList, "AdditionalEntriesParameters");
	
	ComposeTransactionTemplatesParametersTable(AccountingTemplatesList, TemplatesParametersTexts, ParametersMap);
	
	EntriesUnfiltered = GetTransactionsEntriesUnfiltered(AccountingTemplatesList);
	
	If EntriesUnfiltered.Count() = 0 Then
		Return EntriesUnfiltered;
	EndIf;
	
	TransactionsEntriesText = "";
	
	IsFirstEntry = True;
	DocTableName = PostingParametersStructure.DocumentMetadata.Name;
	
	For Each EntryRow In EntriesUnfiltered Do
		
		ConnectionStructure = New Structure("Ref, EntryConnectionKey", EntryRow.TransactionTemplate, EntryRow.ConnectionKey);
		
		TemplateParametersText = TemplatesParametersTexts[EntryRow.TransactionTemplate];
		
		AdditionalParametersText = GetDataSourceFiltersText_OLD(
			AdditionalParametersTable, 
			AdditionalParametersValues, 
			ConnectionStructure,
			ParametersMap);
			
		If Not ValueIsFilled(TemplateParametersText) And Not ValueIsFilled(AdditionalParametersText) Then
			ConditionText = "";
		ElsIf Not ValueIsFilled(AdditionalParametersText) Then
			ConditionText = TemplateParametersText;
		ElsIf Not ValueIsFilled(TemplateParametersText) Then
			ConditionText = AdditionalParametersText;
		Else
			ConditionText = StrTemplate("%1 AND %2", TemplateParametersText, AdditionalParametersText);
		EndIf;
		
		TransactionsEntriesText = TransactionsEntriesText
			+ ?(IsFirstEntry, "", DriveClientServer.GetQueryUnion())
			+ TransactionsEntriesConditionsQueryText(
				EntryRow,
				DocTableName,
				ConditionText,
				ParametersMap,
				IsFirstEntry,
				IsMasterAccounting);
	
		IsFirstEntry = False;
		
	EndDo;
	
	TransactionsEntriesText = TransactionsEntriesText
		+ DriveClientServer.GetQueryDelimeter()
		+ TransactionsEntriesFilteredQueryText(IsMasterAccounting);
		
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text = TransactionsEntriesText;
	
	SetQueryParametersFromMap(Query, ParametersMap);
	Result = Query.Execute();
	Return Result.Unload();
	
EndFunction 

Procedure ComposeTransactionTemplatesParametersTable(AccountingTemplatesList, ParametersTexts, ParametersMap)
	
	ParametersValuesTable = GetFilterValuesTable(AccountingTemplatesList, "Parameters");
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingTransactionsTemplatesParameters.Ref AS Ref,
	|	AccountingTransactionsTemplatesParameters.ParameterName AS ParameterName,
	|	AccountingTransactionsTemplatesParameters.Condition AS Condition,
	|	AccountingTransactionsTemplatesParameters.ValuesConnectionKey AS ValuesConnectionKey
	|FROM
	|	Catalog.AccountingTransactionsTemplates.Parameters AS AccountingTransactionsTemplatesParameters
	|WHERE
	|	AccountingTransactionsTemplatesParameters.Ref IN(&RefList)
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingEntriesTemplatesParameters.Ref,
	|	AccountingEntriesTemplatesParameters.ParameterName,
	|	AccountingEntriesTemplatesParameters.Condition,
	|	AccountingEntriesTemplatesParameters.ValuesConnectionKey
	|FROM
	|	Catalog.AccountingEntriesTemplates.Parameters AS AccountingEntriesTemplatesParameters
	|WHERE
	|	AccountingEntriesTemplatesParameters.Ref IN(&RefList)
	|
	|ORDER BY
	|	Ref";
	
	Query.SetParameter("RefList", AccountingTemplatesList);
	
	ParametersTable = Query.Execute().Unload();
	
	For Each TemplateRef In AccountingTemplatesList Do
		
		ConnectionStructure = New Structure("Ref", TemplateRef);
		
		TemplateParametersText = GetDataSourceFiltersText_OLD(ParametersTable, ParametersValuesTable, ConnectionStructure, ParametersMap);
		
		ParametersTexts.Insert(TemplateRef, TemplateParametersText);
		
	EndDo;

EndProcedure

#EndRegion

#Region FiltersGrouping

Procedure GroupFiltersConditions(FiltersTable, QueryParametersMap, GroupedFilters, FiltersConnectionTable)
	
	GroupedFilters = New ValueTable;
	GroupedFilters.Columns.Add("QueryTempTableID");
	GroupedFilters.Columns.Add("ConditionText");
	GroupedFilters.Columns.Add("DataSource");
	
	FiltersConnectionTable = New ValueTable;
	FiltersConnectionTable.Columns.Add("TemplateRef");
	FiltersConnectionTable.Columns.Add("EntryConnectionKey");
	FiltersConnectionTable.Columns.Add("QueryTempTableID");	
	
	FiltersByEntriesRefs = FiltersTable.Copy();
	FiltersByEntriesRefs.GroupBy("EntryConnectionKey, Ref");

	For Each EntryAndRef In FiltersByEntriesRefs Do
		
		ValueTableFilter = New Structure("EntryConnectionKey, Ref");
		FillPropertyValues(ValueTableFilter, EntryAndRef);
		
		CurrentFilterSet = FiltersTable.FindRows(ValueTableFilter);	
		
		FilterTableID = CheckFilterSetExist(CurrentFilterSet, FiltersTable, GroupedFilters, FiltersConnectionTable);
		If FilterTableID < 0 Then
			
			NewGroupedFilter = GroupedFilters.Add();
			NewGroupedFilter.DataSource 		= CurrentFilterSet[0].DataSource;
			NewGroupedFilter.QueryTempTableID	= GroupedFilters.Count();
			NewGroupedFilter.ConditionText		= GetFilterTextByFilterTableRows(CurrentFilterSet, QueryParametersMap);
			
			FilterTableID = NewGroupedFilter.QueryTempTableID;
			
		EndIf;
		
		ConnectRow = FiltersConnectionTable.Add();
		ConnectRow.TemplateRef			= EntryAndRef.Ref;
		ConnectRow.EntryConnectionKey	= EntryAndRef.EntryConnectionKey;
		ConnectRow.QueryTempTableID		= FilterTableID;

	EndDo;

EndProcedure

Function CheckFilterSetExist(CurrentFilterSet, FiltersTable, GroupedFilters, FiltersConnectionTable)

	For Each GroupedFilter In GroupedFilters Do
		
		ConnectFilter = New Structure("QueryTempTableID", GroupedFilter.QueryTempTableID);
		ExistFilterRows = FiltersConnectionTable.FindRows(ConnectFilter);
		
		ValueTableFilter = New Structure();
		ValueTableFilter.Insert("Ref"					, ExistFilterRows[0].TemplateRef);
		ValueTableFilter.Insert("EntryConnectionKey"	, ExistFilterRows[0].EntryConnectionKey);
		
		GroupedFilterSet = FiltersTable.FindRows(ValueTableFilter);

		If FiltersTablesIdentical(CurrentFilterSet, GroupedFilterSet) Then
			Return GroupedFilter.QueryTempTableID;
		EndIf;
		
	EndDo;

	Return - 1;
	
EndFunction

Function FiltersTablesIdentical(FilterSet1, FilterSet2)

	If FilterSet1.Count() <> FilterSet2.Count() Then
		Return False;
	EndIf;
	
	For Each FilterToCheck In FilterSet1 Do
		
		If Not FilterExistInSet(FilterToCheck, FilterSet2) Then
			Return False;
		EndIf;
		
	EndDo;
	
	Return True;
	
EndFunction 

Function FilterExistInSet(FilterToCheck, FilterSet)

	For Each FilterToCompare In FilterSet Do
		
		If FiltersIdentical(FilterToCheck, FilterToCompare) Then
			Return True;
		EndIf;
		
	EndDo;

	Return False;
	
EndFunction

Function FiltersIdentical(Filter1, Filter2)

	If Filter1.DataSource <> Filter2.DataSource Then
		
		Return False;
		
	ElsIf Filter1.ParameterName <> Filter2.ParameterName
		Or Filter1.Condition.Get() <> Filter2.Condition.Get() Then
		
		Return False;
		
	ElsIf TypeOf(Filter1.Value) <> TypeOf(Filter2.Value) Then
		
		Return False;
		
	ElsIf TypeOf(Filter1.Value) <> Type("Array") 
		And Filter1.Value <> Filter2.Value Then
		
		Return False;
		
	ElsIf TypeOf(Filter1.Value) = Type("Array") Then
		
		Return CommonClientServer.ValueListsAreEqual(Filter1.Value, Filter2.Value);
		
	EndIf;
	
	Return True;
	
EndFunction

#EndRegion

#Region EntriesParametersValuesConnectionTables

Function GetTransactionsEntriesUnfiltered(AccountingTemplatesList)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccountingTransactionsTemplatesEntriesSimple.LineNumber AS LineNumber,
	|	AccountingTransactionsTemplatesEntriesSimple.Ref AS TransactionTemplate,
	|	AccountingTransactionsTemplatesEntriesSimple.ConnectionKey AS ConnectionKey,
	|	AccountingTransactionsTemplatesEntriesSimple.Ref AS Ref,
	|	VALUE(Catalog.DefaultAccountsTypes.EmptyRef) AS DefaultAccountType,
	|	AccountingTransactionsTemplatesEntriesSimple.DefaultAccountTypeCr AS DefaultAccountTypeCr,
	|	AccountingTransactionsTemplatesEntriesSimple.DefaultAccountTypeDr AS DefaultAccountTypeDr
	|FROM
	|	Catalog.AccountingTransactionsTemplates.EntriesSimple AS AccountingTransactionsTemplatesEntriesSimple
	|WHERE
	|	AccountingTransactionsTemplatesEntriesSimple.Ref IN(&TmpltList)
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingTransactionsTemplatesEntries.LineNumber,
	|	AccountingTransactionsTemplatesEntries.Ref,
	|	AccountingTransactionsTemplatesEntries.ConnectionKey,
	|	AccountingTransactionsTemplatesEntries.Ref,
	|	AccountingTransactionsTemplatesEntries.DefaultAccountType,
	|	VALUE(Catalog.DefaultAccountsTypes.EmptyRef),
	|	VALUE(Catalog.DefaultAccountsTypes.EmptyRef)
	|FROM
	|	Catalog.AccountingTransactionsTemplates.Entries AS AccountingTransactionsTemplatesEntries
	|WHERE
	|	AccountingTransactionsTemplatesEntries.Ref IN(&TmpltList)
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingEntriesTemplatesEntriesSimple.LineNumber,
	|	AccountingEntriesTemplatesEntriesSimple.Ref,
	|	AccountingEntriesTemplatesEntriesSimple.ConnectionKey,
	|	AccountingEntriesTemplatesEntriesSimple.Ref,
	|	VALUE(Catalog.DefaultAccountsTypes.EmptyRef),
	|	AccountingEntriesTemplatesEntriesSimple.DefaultAccountTypeCr,
	|	AccountingEntriesTemplatesEntriesSimple.DefaultAccountTypeDr
	|FROM
	|	Catalog.AccountingEntriesTemplates.EntriesSimple AS AccountingEntriesTemplatesEntriesSimple
	|WHERE
	|	AccountingEntriesTemplatesEntriesSimple.Ref IN(&TmpltList)
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingEntriesTemplatesEntries.LineNumber,
	|	AccountingEntriesTemplatesEntries.Ref,
	|	AccountingEntriesTemplatesEntries.ConnectionKey,
	|	AccountingEntriesTemplatesEntries.Ref,
	|	AccountingEntriesTemplatesEntries.DefaultAccountType,
	|	VALUE(Catalog.DefaultAccountsTypes.EmptyRef),
	|	VALUE(Catalog.DefaultAccountsTypes.EmptyRef)
	|FROM
	|	Catalog.AccountingEntriesTemplates.Entries AS AccountingEntriesTemplatesEntries
	|WHERE
	|	AccountingEntriesTemplatesEntries.Ref IN(&TmpltList)";
	
	Query.SetParameter("TmpltList", AccountingTemplatesList);
	
	QueryResult = Query.Execute();
	Return QueryResult.Unload();
	
EndFunction

Function GetFilterValuesTable(AccountingTemplatesList, TabSectionName)
	
	FiltersValuesTable = New ValueTable;
	FiltersValuesTable.Columns.Add("TemplateRef");
	FiltersValuesTable.Columns.Add("ConnectionKey");
	FiltersValuesTable.Columns.Add("ValuesArray");
	FiltersValuesTable.Columns.Add("Value");
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingTransactionsTemplatesParametersValues.Ref AS TemplateRef,
	|	AccountingTransactionsTemplatesParametersValues.ConnectionKey AS ConnectionKey,
	|	AccountingTransactionsTemplatesParametersValues.MetadataName AS MetadataName,
	|	AccountingTransactionsTemplatesParametersValues.Value AS Value
	|FROM
	|	Catalog.AccountingTransactionsTemplates.ParametersValues AS AccountingTransactionsTemplatesParametersValues
	|WHERE
	|	AccountingTransactionsTemplatesParametersValues.Ref IN(&TemplatesList)
	|	AND AccountingTransactionsTemplatesParametersValues.MetadataName = &TabSectionName
	|
	|GROUP BY
	|	AccountingTransactionsTemplatesParametersValues.Ref,
	|	AccountingTransactionsTemplatesParametersValues.ConnectionKey,
	|	AccountingTransactionsTemplatesParametersValues.MetadataName,
	|	AccountingTransactionsTemplatesParametersValues.Value
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingEntriesTemplatesParametersValues.Ref,
	|	AccountingEntriesTemplatesParametersValues.ConnectionKey,
	|	AccountingEntriesTemplatesParametersValues.MetadataName,
	|	AccountingEntriesTemplatesParametersValues.Value
	|FROM
	|	Catalog.AccountingEntriesTemplates.ParametersValues AS AccountingEntriesTemplatesParametersValues
	|WHERE
	|	AccountingEntriesTemplatesParametersValues.Ref IN(&TemplatesList)
	|	AND AccountingEntriesTemplatesParametersValues.MetadataName = &TabSectionName
	|
	|GROUP BY
	|	AccountingEntriesTemplatesParametersValues.Ref,
	|	AccountingEntriesTemplatesParametersValues.ConnectionKey,
	|	AccountingEntriesTemplatesParametersValues.MetadataName,
	|	AccountingEntriesTemplatesParametersValues.Value
	|TOTALS BY
	|	TemplateRef,
	|	MetadataName,
	|	ConnectionKey";
	
	Query.SetParameter("TemplatesList", AccountingTemplatesList);
	Query.SetParameter("TabSectionName", TabSectionName);
	
	QueryResult = Query.Execute();
	
	SelectionRef = QueryResult.Select(QueryResultIteration.ByGroups);
	
	While SelectionRef.Next() Do
		SelectionMetadataName = SelectionRef.Select(QueryResultIteration.ByGroups);
	
		While SelectionMetadataName.Next() Do
			SelectionConnectionKey = SelectionMetadataName.Select(QueryResultIteration.ByGroups);
	
			While SelectionConnectionKey.Next() Do
				
				ValuesRow = FiltersValuesTable.Add();
				FillPropertyValues(ValuesRow, SelectionConnectionKey, "TemplateRef, ConnectionKey");
				
				SelectionDetailRecords = SelectionConnectionKey.Select();
				
				If SelectionDetailRecords.Count() = 1 Then
					
					SelectionDetailRecords.Next();
					ValuesRow.Value = ConvertAccumulationRecordType(SelectionDetailRecords.Value);
					
				Else
					
					ValuesRow.ValuesArray = New Array;
					While SelectionDetailRecords.Next() Do
						
						Value = ConvertAccumulationRecordType(SelectionDetailRecords.Value);
						ValuesRow.ValuesArray.Add(Value);
						
					EndDo;
					
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	Return FiltersValuesTable; 

EndFunction 

Function GetFiltersTable(AccountingTemplatesList, FiltersValuesTable)
	
	FiltersTable = New ValueTable;
	FiltersTable.Columns.Add("Ref");
	FiltersTable.Columns.Add("DataSource");
	FiltersTable.Columns.Add("ParameterName");
	FiltersTable.Columns.Add("Condition");
	FiltersTable.Columns.Add("EntryConnectionKey");
	FiltersTable.Columns.Add("ValuesConnectionKey");
	FiltersTable.Columns.Add("Value");
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingTransactionsTemplatesEntriesSimple.DataSource AS DataSource,
	|	AccountingTransactionsTemplatesEntriesFilters.Ref AS Ref,
	|	AccountingTransactionsTemplatesEntriesFilters.ParameterName AS ParameterName,
	|	AccountingTransactionsTemplatesEntriesFilters.Condition AS Condition,
	|	AccountingTransactionsTemplatesEntriesFilters.EntryConnectionKey AS EntryConnectionKey,
	|	AccountingTransactionsTemplatesEntriesFilters.ValuesConnectionKey AS ValuesConnectionKey,
	|	NULL AS Value,
	|	AccountingTransactionsTemplatesEntriesFilters.MultipleValuesMode AS MultipleValuesMode
	|FROM
	|	Catalog.AccountingTransactionsTemplates.EntriesFilters AS AccountingTransactionsTemplatesEntriesFilters
	|		INNER JOIN Catalog.AccountingTransactionsTemplates.EntriesSimple AS AccountingTransactionsTemplatesEntriesSimple
	|		ON AccountingTransactionsTemplatesEntriesFilters.Ref = AccountingTransactionsTemplatesEntriesSimple.Ref
	|			AND AccountingTransactionsTemplatesEntriesFilters.EntryConnectionKey = AccountingTransactionsTemplatesEntriesSimple.ConnectionKey
	|			AND (AccountingTransactionsTemplatesEntriesFilters.Ref IN (&TemplatesList))
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingTransactionsTemplatesEntries.DataSource,
	|	AccountingTransactionsTemplatesEntriesFilters.Ref,
	|	AccountingTransactionsTemplatesEntriesFilters.ParameterName,
	|	AccountingTransactionsTemplatesEntriesFilters.Condition,
	|	AccountingTransactionsTemplatesEntriesFilters.EntryConnectionKey,
	|	AccountingTransactionsTemplatesEntriesFilters.ValuesConnectionKey,
	|	NULL,
	|	AccountingTransactionsTemplatesEntriesFilters.MultipleValuesMode
	|FROM
	|	Catalog.AccountingTransactionsTemplates.EntriesFilters AS AccountingTransactionsTemplatesEntriesFilters
	|		INNER JOIN Catalog.AccountingTransactionsTemplates.Entries AS AccountingTransactionsTemplatesEntries
	|		ON AccountingTransactionsTemplatesEntriesFilters.Ref = AccountingTransactionsTemplatesEntries.Ref
	|			AND AccountingTransactionsTemplatesEntriesFilters.EntryConnectionKey = AccountingTransactionsTemplatesEntries.ConnectionKey
	|			AND (AccountingTransactionsTemplatesEntriesFilters.Ref IN (&TemplatesList))
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingEntriesTemplatesEntriesSimple.DataSource AS DataSource,
	|	AccountingEntriesTemplatesEntriesFilters.Ref AS Ref,
	|	AccountingEntriesTemplatesEntriesFilters.ParameterName AS ParameterName,
	|	AccountingEntriesTemplatesEntriesFilters.Condition AS Condition,
	|	AccountingEntriesTemplatesEntriesFilters.EntryConnectionKey AS EntryConnectionKey,
	|	AccountingEntriesTemplatesEntriesFilters.ValuesConnectionKey AS ValuesConnectionKey,
	|	NULL,
	|	AccountingEntriesTemplatesEntriesFilters.MultipleValuesMode
	|FROM
	|	Catalog.AccountingEntriesTemplates.EntriesFilters AS AccountingEntriesTemplatesEntriesFilters
	|		INNER JOIN Catalog.AccountingEntriesTemplates.EntriesSimple AS AccountingEntriesTemplatesEntriesSimple
	|		ON AccountingEntriesTemplatesEntriesFilters.Ref = AccountingEntriesTemplatesEntriesSimple.Ref
	|			AND AccountingEntriesTemplatesEntriesFilters.EntryConnectionKey = AccountingEntriesTemplatesEntriesSimple.ConnectionKey
	|			AND (AccountingEntriesTemplatesEntriesFilters.Ref IN (&TemplatesList))
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingEntriesTemplatesEntries.DataSource,
	|	AccountingEntriesTemplatesEntriesFilters.Ref,
	|	AccountingEntriesTemplatesEntriesFilters.ParameterName,
	|	AccountingEntriesTemplatesEntriesFilters.Condition,
	|	AccountingEntriesTemplatesEntriesFilters.EntryConnectionKey,
	|	AccountingEntriesTemplatesEntriesFilters.ValuesConnectionKey,
	|	NULL,
	|	AccountingEntriesTemplatesEntriesFilters.MultipleValuesMode
	|FROM
	|	Catalog.AccountingEntriesTemplates.EntriesFilters AS AccountingEntriesTemplatesEntriesFilters
	|		INNER JOIN Catalog.AccountingEntriesTemplates.Entries AS AccountingEntriesTemplatesEntries
	|		ON AccountingEntriesTemplatesEntriesFilters.Ref = AccountingEntriesTemplatesEntries.Ref
	|			AND AccountingEntriesTemplatesEntriesFilters.EntryConnectionKey = AccountingEntriesTemplatesEntries.ConnectionKey
	|			AND (AccountingEntriesTemplatesEntriesFilters.Ref IN (&TemplatesList))";
	
	Query.SetParameter("TemplatesList", AccountingTemplatesList);
	
	QueryResult = Query.Execute().Unload();
	
	For Each FilterRow In QueryResult Do
		
		NewRow = FiltersTable.Add();
		FillPropertyValues(NewRow, FilterRow, , "ParameterName");
		
		FilterStructure = New Structure("TemplateRef, ConnectionKey", FilterRow.Ref, FilterRow.ValuesConnectionKey);
		ValuesRows = FiltersValuesTable.FindRows(FilterStructure);
		ValueRow = ValuesRows[0];
		
		If FilterRow.MultipleValuesMode And Not ValueIsFilled(ValueRow.Value) And ValueRow.ValuesArray <> Undefined Then
			NewRow.Value = ValueRow.ValuesArray;
		ElsIf Not FilterRow.MultipleValuesMode And Not ValueIsFilled(ValueRow.Value) And ValueRow.ValuesArray <> Undefined Then
			NewRow.Value = ValueRow.ValuesArray[0];
		Else
			NewRow.Value = ValueRow.Value;
		EndIf;
		NewRow.ParameterName = FilterRow.ParameterName;
		
	EndDo;
	
	Return FiltersTable;
	
EndFunction

Function GetAdditionalParametersTable(AccountingTemplatesList)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingTransactionsTemplatesAdditionalEntriesParameters.Ref AS Ref,
	|	AccountingTransactionsTemplatesAdditionalEntriesParameters.ParameterName AS ParameterName,
	|	AccountingTransactionsTemplatesAdditionalEntriesParameters.Condition AS Condition,
	|	AccountingTransactionsTemplatesAdditionalEntriesParameters.EntryConnectionKey AS EntryConnectionKey,
	|	AccountingTransactionsTemplatesAdditionalEntriesParameters.ValuesConnectionKey AS ValuesConnectionKey
	|FROM
	|	Catalog.AccountingTransactionsTemplates.AdditionalEntriesParameters AS AccountingTransactionsTemplatesAdditionalEntriesParameters
	|WHERE
	|	AccountingTransactionsTemplatesAdditionalEntriesParameters.Ref IN(&Ref)";
	
	Query.SetParameter("Ref", AccountingTemplatesList);
	
	QueryResult = Query.Execute();
	
	Return QueryResult.Unload();

EndFunction

Function GetDefaultAccountsTable(EntriesTable)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	EntriesTable.Ref AS TemplateRef,
	|	EntriesTable.ConnectionKey AS ConnectionKey,
	|	EntriesTable.DefaultAccountType AS DefaultAccountType,
	|	EntriesTable.DefaultAccountTypeCr AS DefaultAccountTypeCr,
	|	EntriesTable.DefaultAccountTypeDr AS DefaultAccountTypeDr
	|INTO EntriesTable
	|FROM
	|	&EntriesTable AS EntriesTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EntriesTable.TemplateRef AS TemplateRef,
	|	EntriesTable.ConnectionKey AS ConnectionKey,
	|	EntriesTable.DefaultAccountType AS DefaultAccountType,
	|	AccountingTransactionsTemplatesEntriesDefaultAccounts.DrCr AS DrCr,
	|	AccountingTransactionsTemplatesEntriesDefaultAccounts.EntryOrder,
	|	AccountingTransactionsTemplatesEntriesDefaultAccounts.FilterName AS FilterName,
	|	AccountingTransactionsTemplatesEntriesDefaultAccounts.Value AS Value
	|FROM
	|	EntriesTable AS EntriesTable
	|		INNER JOIN Catalog.AccountingTransactionsTemplates.EntriesDefaultAccounts AS AccountingTransactionsTemplatesEntriesDefaultAccounts
	|		ON EntriesTable.TemplateRef = AccountingTransactionsTemplatesEntriesDefaultAccounts.Ref
	|			AND EntriesTable.ConnectionKey = AccountingTransactionsTemplatesEntriesDefaultAccounts.EntryConnectionKey
	|			AND (AccountingTransactionsTemplatesEntriesDefaultAccounts.DrCr = VALUE(Enum.DebitCredit.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT
	|	EntriesTable.TemplateRef,
	|	EntriesTable.ConnectionKey,
	|	EntriesTable.DefaultAccountTypeCr,
	|	AccountingTransactionsTemplatesEntriesDefaultAccounts.DrCr,
	|	AccountingTransactionsTemplatesEntriesDefaultAccounts.EntryOrder,
	|	AccountingTransactionsTemplatesEntriesDefaultAccounts.FilterName,
	|	AccountingTransactionsTemplatesEntriesDefaultAccounts.Value
	|FROM
	|	EntriesTable AS EntriesTable
	|		INNER JOIN Catalog.AccountingTransactionsTemplates.EntriesDefaultAccounts AS AccountingTransactionsTemplatesEntriesDefaultAccounts
	|		ON EntriesTable.TemplateRef = AccountingTransactionsTemplatesEntriesDefaultAccounts.Ref
	|			AND EntriesTable.ConnectionKey = AccountingTransactionsTemplatesEntriesDefaultAccounts.EntryConnectionKey
	|			AND (AccountingTransactionsTemplatesEntriesDefaultAccounts.DrCr = VALUE(Enum.DebitCredit.Cr))
	|
	|UNION ALL
	|
	|SELECT
	|	EntriesTable.TemplateRef,
	|	EntriesTable.ConnectionKey,
	|	EntriesTable.DefaultAccountTypeDr,
	|	AccountingTransactionsTemplatesEntriesDefaultAccounts.DrCr,
	|	AccountingTransactionsTemplatesEntriesDefaultAccounts.EntryOrder,
	|	AccountingTransactionsTemplatesEntriesDefaultAccounts.FilterName,
	|	AccountingTransactionsTemplatesEntriesDefaultAccounts.Value
	|FROM
	|	EntriesTable AS EntriesTable
	|		INNER JOIN Catalog.AccountingTransactionsTemplates.EntriesDefaultAccounts AS AccountingTransactionsTemplatesEntriesDefaultAccounts
	|		ON EntriesTable.TemplateRef = AccountingTransactionsTemplatesEntriesDefaultAccounts.Ref
	|			AND EntriesTable.ConnectionKey = AccountingTransactionsTemplatesEntriesDefaultAccounts.EntryConnectionKey
	|			AND (AccountingTransactionsTemplatesEntriesDefaultAccounts.DrCr = VALUE(Enum.DebitCredit.Dr))";
	
	Query.SetParameter("EntriesTable", EntriesTable);
	
	Return Query.Execute().Unload();
EndFunction

#EndRegion

Procedure SetQueryParametersFromMap(Query, QueryParametersMap)
	
	For Each FilterParameter In QueryParametersMap Do
		
		If StrStartsWith(FilterParameter.Key, "RegisterRecordsTable")
			And FilterParameter.Key <> "RegisterRecordsTableAccountingEntriesData" Then
			
			ParameterValue = RefillValueTable(FilterParameter);
			Query.SetParameter(FilterParameter.Key, ParameterValue);
			
		Else
			
			Query.SetParameter(FilterParameter.Key, FilterParameter.Value);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function RefillValueTable(FilterParameter)
	
	Try
		RegisterName = Mid(FilterParameter.Key, 21, StrLen(FilterParameter.Key) - 20);
		
		RegisterFullName = "AccumulationRegister." + RegisterName;
		
		Return RefillValueTableByObjectTable(RegisterFullName, RegisterName, FilterParameter.Value);
		
	Except
		
		Return FilterParameter.Value;
		
	EndTry;
	
EndFunction

Procedure InsertDataSourceField(QueryTemplate, FieldName, AccEntryTemplate, SumField, GroupField, GroupingFieldsArray, IsNumber = False)

	FieldValue = AccEntryTemplate[FieldName];
	
	CurrencyFields = "CurrencyDr, CurrencyCr, AmountCurDr, AmountCurCr, Currency, AmountCur,";
	QuantityFields = "QuantityDr, QuantityCr, Quantity,";
	
	FieldValue = StrReplace(FieldValue, "[", "");
	FieldValue = StrReplace(FieldValue, "]", "");
	FieldValue = StrReplace(FieldValue, ".AdditionalAttribute.", ".");
	
	If StrFind(CurrencyFields, FieldName + ",") Then
		
		If StrFind(FieldName, "Dr") <> 0 Then
			FieldType = "Dr";
		ElsIf StrFind(FieldName, "Cr") <> 0 Then
			FieldType = "Cr";
		Else
			FieldType = "";
		EndIf;
		
		MultiCurrencyFieldName = StrTemplate("MultiCurrency%1", FieldType);
		SkipCurrencyField = Not AccEntryTemplate[MultiCurrencyFieldName];
		
	ElsIf StrFind(QuantityFields, FieldName + ",") Then
		
		QuantityFieldName = StrTemplate("Use%1", FieldName);
		SkipCurrencyField = Not AccEntryTemplate[QuantityFieldName];
		
		If Not SkipCurrencyField
			And Not ValueIsFilled(FieldValue) Then
			
			Comment = NStr("en = 'In entry ""%1"" ""%2"" Quantity was not filled due to empty filling rule in Accounting transaction template'; ru = 'В проводке ""%1"" ""%2"" не было заполнено количество, поскольку в шаблоне бухгалтерской операции не указано правило заполнения';pl = 'We wpisie ""%1"" ""%2"" Ilość nie była wypełniona z powodu pustej reguły w szablonie Transakcji księgowej';es_ES = 'En la entrada diaria ""%1"" ""%2"" la cantidad no se ha rellenado debido a que la regla de rellenado está vacía en la plantilla de transacción contable';es_CO = 'En la entrada diaria ""%1"" ""%2"" la cantidad no se ha rellenado debido a que la regla de rellenado está vacía en la plantilla de transacción contable';tr = '""%1"" ""%2"" girişinde, Muhasebe işlemi şablonundaki boşları doldurma kuralı nedeniyle Miktar doldurulmadı';it = 'Nella voce ""%1"" ""%2"" Quantità non è stato compilato poiché la regola di compilazione è vuota nel modello di transazione di contabilità';de = 'In Buchung ""%1"" ""%2"" ist die Menge nicht aufgefüllt, denn die Buchhaltungstransaktionsvorlage leere Auffüllungsregeln enthält'");
			
			If StrFind(FieldName, "Dr") <> 0 Or AccEntryTemplate.RecordType = Enums.DebitCredit.Dr Then
				TypeOfAccount = NStr("en = 'Debit account'; ru = 'Дебетовый счет';pl = 'Konto debetowe';es_ES = 'Cuenta de débito';es_CO = 'Cuenta de débito';tr = 'Borç hesabı';it = 'Conto debito';de = 'Soll-Konto'");
			Else
				TypeOfAccount = NStr("en = 'Credit account'; ru = 'Кредитовый счет';pl = 'Konto kredytowe';es_ES = 'Cuenta de crédito';es_CO = 'Cuenta de crédito';tr = 'Alacak hesabı';it = 'Conto credito';de = 'Haben-Konto'");
			EndIf;
			
			WriteLogEvent(GetEventGroupVariant()
				+ NStr("en = 'Post documents by accounting templates'; ru = 'Провести документы по шаблонам бухгалтерского учета';pl = 'Zatwierdź dokumenty według szablonów rachunkowości';es_ES = 'Contabilizar documentos por plantillas de contabilidad';es_CO = 'Contabilizar documentos por plantillas de contabilidad';tr = 'Belgeleri muhasebe şablonlarına göre kaydet';it = 'Pubblicare documenti per modelli di contabilità';de = 'Dokumente nach Buchhaltungsvorlagen buchen'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Warning,
				,
				AccEntryTemplate.Ref,
				StrTemplate(Comment, AccEntryTemplate.EntryLineNumber, TypeOfAccount));
			
		EndIf;
		
	Else
		SkipCurrencyField = False; // This isn't currency field - so never skip it.
	EndIf;
	
	If StrFind(FieldName, "AnalyticalDimensions") > 0 Then
		
		TypeValue = AccEntryTemplate[StrReplace(FieldName, "AnalyticalDimensions", "AnalyticalDimensionsType")];
		
		If ValueIsFilled(TypeValue)
			And Not ValueIsFilled(FieldValue) Then
			
			Comment = NStr("en = 'In entry ""%1"" ""%2"" Analytical dimension ""%3"" was not filled due to empty filling rule in Accounting transaction template'; ru = 'В проводке ""%1"" ""%2"" не было заполнено аналитическое измерение ""%3"", поскольку в шаблоне бухгалтерской операции не указано правило заполнения';pl = 'We wpisie ""%1"" ""%2"" Wymiar analityczny ""%3"" nie był wypełniony z powodu pustej reguły w szablonie Transakcji księgowej';es_ES = 'En la entrada de diario ""%1"" ""%2"" la dimensión analítica ""%3"" no se ha rellenado debido que la regla de rellenado está vacía en la plantilla de transacción contable';es_CO = 'En la entrada de diario ""%1"" ""%2"" la dimensión analítica ""%3"" no se ha rellenado debido que la regla de rellenado está vacía en la plantilla de transacción contable';tr = '""%1"" ""%2"" girişinde, Muhasebe işlemi şablonundaki boşları doldurma kuralı nedeniyle ""%3"" Analitik boyutu doldurulmadı';it = 'Nella voce ""%1"" ""%2"" la dimensione analitica ""%3"" non è stata compilata poiché la regola di compilazione è vuota nel modello di transazione di contabilità';de = 'In Buchung ""%1"" ""%2"" ist die Analytische Messung ""%3""nicht aufgefüllt, denn die Buchhaltungstransaktionsvorlage leere Auffüllungsregeln enthält'");
			
			If StrFind(FieldName, "Dr") <> 0 Or AccEntryTemplate.RecordType = Enums.DebitCredit.Dr Then
				TypeOfAccount = NStr("en = 'Debit account'; ru = 'Дебетовый счет';pl = 'Konto debetowe';es_ES = 'Cuenta de débito';es_CO = 'Cuenta de débito';tr = 'Borç hesabı';it = 'Conto debito';de = 'Soll-Konto'");
			Else
				TypeOfAccount = NStr("en = 'Credit account'; ru = 'Кредитовый счет';pl = 'Konto kredytowe';es_ES = 'Cuenta de crédito';es_CO = 'Cuenta de crédito';tr = 'Alacak hesabı';it = 'Conto credito';de = 'Haben-Konto'");
			EndIf;
			
			WriteLogEvent(GetEventGroupVariant()
				+ NStr("en = 'Post documents by accounting templates'; ru = 'Провести документы по шаблонам бухгалтерского учета';pl = 'Zatwierdź dokumenty według szablonów rachunkowości';es_ES = 'Contabilizar documentos por plantillas de contabilidad';es_CO = 'Contabilizar documentos por plantillas de contabilidad';tr = 'Belgeleri muhasebe şablonlarına göre kaydet';it = 'Pubblicare documenti per modelli di contabilità';de = 'Dokumente nach Buchhaltungsvorlagen buchen'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Warning,
				,
				AccEntryTemplate.Ref,
				StrTemplate(Comment, AccEntryTemplate.EntryLineNumber, TypeOfAccount, TypeValue));
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(FieldValue) Or SkipCurrencyField Then
		
		If IsNumber Then
			FieldValue = "0";
		Else
			FieldValue = "UNDEFINED";
		EndIf;
		
	ElsIf GroupField And Not SumField Then
		GroupingFieldsArray.Add(FieldValue);
	EndIf;
	
	If SumField And FieldValue <> "UNDEFINED" Then
		FieldValue = StrTemplate("SUM(%1)", FieldValue);
	EndIf;
	
	If FieldName = "Content" Then
		FieldValue = StrTemplate("""%1""", FieldValue);
	EndIf;
	
	QFieldName = StrTemplate("&%1", FieldName);
	
	QueryTemplate = StrReplace(QueryTemplate, QFieldName, FieldValue);

EndProcedure

Procedure ReplaceInnerQueryTableNames(QueryText, TableName, TableSource, ReplacePreffix)
	
	Preffix = "";
	If TableSource = "TabularSections" Then
		Preffix = "TabularSection.";
	ElsIf TableSource = "AccumulationRegister" Then
		Preffix = "Register.";
	ElsIf TableSource = "Document" Then
		Preffix = "Document.";
	EndIf;
	
	SearchSubstring		= StrTemplate("%1%2.", Preffix, TableName);
	ReplaceSubstring	= StrTemplate("%1_%2.", ReplacePreffix, TableName);
	
	QueryText = StrReplace(QueryText, SearchSubstring, ReplaceSubstring);
	
EndProcedure

Function GetDataSourceFiltersText_OLD(FiltersTable, FiltersValuesTable, ConnectionStructure, QueryParametersMap)

	FiltersRows = FiltersTable.FindRows(ConnectionStructure);
	
	FiltersText = "";
	
	EmptyValues = AccountingTemplatesCached.GetEmptyValues();
	
	FirstRow = True;
	For Each Filter In FiltersRows Do
		
		ConditionTemplate = "LogicalAddition LogicalNeg FieldName COND (&ParameterIndex)";
		
		If FirstRow Then
			FirstRow = False;
			ConditionTemplate = StrReplace(ConditionTemplate, "LogicalAddition", "");
		Else
			ConditionTemplate = StrReplace(ConditionTemplate, "LogicalAddition", " " + "AND");
		EndIf;
		
		FieldName = StrReplace(Filter.ParameterName, ".AdditionalAttribute.", ".");
		
		// Condition
		ConditionStructure = ConvertCondition(Filter.Condition);
		
		ConditionTemplate = StrReplace(ConditionTemplate, "LogicalNeg"	, ConditionStructure.LogicalNeg);
		ConditionTemplate = StrReplace(ConditionTemplate, "COND"		, ConditionStructure.ConditionText);
		ConditionTemplate = StrReplace(ConditionTemplate, "FieldName"	, FieldName);
		
		// Filter(s) values
		
		If ConditionStructure.Property("ParameterName") Then
			ParameterValue	= EmptyValues;
			ParameterText	= ConditionStructure.ParameterName;
		Else
			
			FilterStructure		= New Structure("ConnectionKey, TemplateRef", Filter.ValuesConnectionKey, Filter.Ref);
			FilterValuesRows	= FiltersValuesTable.FindRows(FilterStructure);
			FilterValue			= FilterValuesRows[0];
			
			ParameterValue = ?(FilterValue.Value <> Undefined, FilterValue.Value, FilterValue.ValuesArray);
			
			If TypeOf(ParameterValue) = Type("String") And ConditionStructure.WrapParameter Then
				ParameterValue = "%" + ParameterValue + "%";
			EndIf;
			
			ParameterText = StrTemplate("Parameter%1", QueryParametersMap.Count());
			
		EndIf;
		
		ConditionTemplate = StrReplace(ConditionTemplate, "ParameterIndex", ParameterText);
		
		QueryParametersMap.Insert(ParameterText, ParameterValue);
		
		FiltersText = FiltersText + ConditionTemplate;
		
	EndDo;
	
	Return FiltersText;
	
EndFunction

Function GetFilterTextByFilterTableRows(FiltersRows, QueryParametersMap)
	
	FiltersText = "";
	
	FirstRow = True;
	For Each Filter In FiltersRows Do
		
		ConditionTemplate = "LogicalAddition LogicalNeg FieldName COND (&ParameterIndex)";
		
		If FirstRow Then
			FirstRow = False;
			ConditionTemplate = StrReplace(ConditionTemplate, "LogicalAddition", "");
		Else
			ConditionTemplate = StrReplace(ConditionTemplate, "LogicalAddition", " " + "AND");
		EndIf;
		
		ParameterName = StrReplace(Filter.ParameterName, ".AdditionalAttribute.", ".");
		
		// Condition
		ConditionStructure = ConvertCondition(Filter.Condition);
		
		ConditionTemplate = StrReplace(ConditionTemplate, "LogicalNeg"	, ConditionStructure.LogicalNeg);
		ConditionTemplate = StrReplace(ConditionTemplate, "COND"		, ConditionStructure.ConditionText);
		ConditionTemplate = StrReplace(ConditionTemplate, "FieldName"	, ParameterName);
		
		ParameterValue = ?(Filter.Value <> Undefined, Filter.Value, Filter.ValuesArray);
		
		If TypeOf(ParameterValue) = Type("String") And ConditionStructure.WrapParameter Then
			ParameterValue = "%" + ParameterValue + "%";
		EndIf;
		
		ParameterText = StrTemplate("Parameter%1", QueryParametersMap.Count());
		
		ConditionTemplate = StrReplace(ConditionTemplate, "ParameterIndex", ParameterText);
		
		QueryParametersMap.Insert(ParameterText, ParameterValue);
		
		FiltersText = FiltersText + ConditionTemplate;
		
	EndDo;

	Return FiltersText;
	
EndFunction 

Function ConvertCondition(ConditionRef)

	ReturnStructure = New Structure;
	ReturnStructure.Insert("ConditionText"	, "");
	ReturnStructure.Insert("LogicalNeg"		, "");
	ReturnStructure.Insert("WrapParameter"	, False);
	Condition = ConditionRef.Get();
	
	If Condition = DataCompositionComparisonType.Equal Then
		
		ReturnStructure.ConditionText	= "=";
		ReturnStructure.LogicalNeg		= "";
		ReturnStructure.WrapParameter	= False;
		
	ElsIf Condition = DataCompositionComparisonType.NotEqual Then
		
		ReturnStructure.ConditionText	= "<>";
		ReturnStructure.LogicalNeg		= "";
		ReturnStructure.WrapParameter	= False;
		
	ElsIf Condition = DataCompositionComparisonType.Filled Then
		
		ReturnStructure.ConditionText	= "IN";
		ReturnStructure.LogicalNeg		= "NOT";
		ReturnStructure.Insert("ParameterName", "EmptyValues");
		
	ElsIf Condition = DataCompositionComparisonType.NotFilled Then
		
		ReturnStructure.ConditionText	= "IN";
		ReturnStructure.LogicalNeg		= "";
		ReturnStructure.Insert("ParameterName", "EmptyValues");
		
	ElsIf Condition = DataCompositionComparisonType.Greater Then
		
		ReturnStructure.ConditionText	= ">";
		ReturnStructure.LogicalNeg		= "";
		ReturnStructure.WrapParameter	= False;
		
	ElsIf Condition = DataCompositionComparisonType.GreaterOrEqual Then
		
		ReturnStructure.ConditionText	= ">=";
		ReturnStructure.LogicalNeg		= "";
		ReturnStructure.WrapParameter	= False;
		
	ElsIf Condition = DataCompositionComparisonType.Less Then
		
		ReturnStructure.ConditionText	= "<";
		ReturnStructure.LogicalNeg		= "";
		ReturnStructure.WrapParameter	= False;
		
	ElsIf Condition = DataCompositionComparisonType.LessOrEqual Then
		
		ReturnStructure.ConditionText	= "<=";
		ReturnStructure.LogicalNeg		= "";
		ReturnStructure.WrapParameter	= False;
		
	ElsIf Condition = DataCompositionComparisonType.InList Then
		
		ReturnStructure.ConditionText	= "IN";
		ReturnStructure.LogicalNeg		= "";
		ReturnStructure.WrapParameter	= False;
		
	ElsIf Condition = DataCompositionComparisonType.NotInList Then
		
		ReturnStructure.ConditionText	= "IN";
		ReturnStructure.LogicalNeg		= "NOT";
		ReturnStructure.WrapParameter	= False;
		
	ElsIf Condition = DataCompositionComparisonType.Contains Then
		
		ReturnStructure.ConditionText	= "LIKE";
		ReturnStructure.LogicalNeg		= "";
		ReturnStructure.WrapParameter	= True;
		
	ElsIf Condition = DataCompositionComparisonType.NotContains Then
		
		ReturnStructure.ConditionText	= "LIKE";
		ReturnStructure.LogicalNeg		= "NOT";
		ReturnStructure.WrapParameter	= True;
		
	EndIf;
	
	Return ReturnStructure;

EndFunction 

Function AdjustFieldValue(FieldName, AccEntryTemplate)
	
	FieldValue = AccEntryTemplate[FieldName];
	QFieldName = StrTemplate("&%1", FieldName); 

	If TypeOf(FieldValue) = Type("CatalogRef.DefaultGLAccounts") Then
		
		Return Common.ObjectAttributeValue(FieldValue, "GLAccount");
		
	ElsIf TypeOf(FieldValue) = Type("EnumRef.DebitCredit") Then
		
		Return ?(FieldValue = Enums.DebitCredit.Dr, AccountingRecordType.Debit, AccountingRecordType.Credit);
		
	Else
		
		Return FieldValue;
		
	EndIf;

EndFunction

Function AdjustDataSource(DataSource)

	If StrFind(DataSource, ".") = 0 Then
		Return New Structure("TableName, SourceName", "Document", "Attributes");
	EndIf;
	
	DataSourceArray = StrSplit(DataSource, ".", False);
	
	SourceName = StrReplace(DataSourceArray[0], "AccumulationRegisters", "AccumulationRegister");
	TableName  = DataSourceArray[1];
	
	SourceStructure = New Structure("TableName, SourceName", TableName, SourceName);
	
	Return SourceStructure;
	
EndFunction

Function ConvertAccumulationRecordType(Value)

	If TypeOf(Value) = Type("EnumRef.AccumulationRecordType") Then
		Return ?(Value = Enums.AccumulationRecordType.Expense, AccumulationRecordType.Expense, AccumulationRecordType.Receipt);
	ElsIf TypeOf(Value) = Type("EnumRef.DebitCredit") Then
		Return ?(Value = Enums.DebitCredit.Dr, AccountingRecordType.Debit, AccountingRecordType.Credit);
	EndIf;
	
	Return Value;
	
EndFunction

Function DocumentIsRecorderForRegister(DocumentRef, ChartOfAccountsRef)
	
	ChartOfAccountsName = AccountingApprovalServer.GetChartOfAccountsName(ChartOfAccountsRef);
	
	If ValueIsFilled(ChartOfAccountsName) Then
		ChartOfAccountsMetadata = Metadata.ChartsOfAccounts[ChartOfAccountsName];
	Else
		Return False;
	EndIf;
	
	For Each AcccountingRegister In Metadata.AccountingRegisters Do
		
		If AcccountingRegister.ChartOfAccounts <> ChartOfAccountsMetadata Then
			Continue;
		EndIf;
		
		RecordSet = AccountingRegisters[AcccountingRegister.Name].CreateRecordSet();
		
		If RecordSet.Filter.Recorder.ValueType.ContainsType(TypeOf(DocumentRef)) Then
			Return True;
		EndIf;
	
	EndDo;
	
	Return False;
	
EndFunction

Procedure AddCommonTemporaryTables(TempTablesManager, PostingParametersStructure, ApplicableTemplatesList)

	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	If Query.TempTablesManager.Tables.Find("ConstantsTable") <> Undefined Then
		Return;
	EndIf;
	
	TempTablesQueryText = DocumentAttributesTempTableQueryText(Query, PostingParametersStructure.DocumentMetadata)
		+ DriveClientServer.GetQueryDelimeter();
		
	TempTablesQueryText = TempTablesQueryText
		+ InformationRegisters.AccountingPolicy.AccountingPolicyTableQueryText()
		+ DriveClientServer.GetQueryDelimeter();
		
	TempTablesQueryText = TempTablesQueryText
		+ ConstantsTableQueryText(ApplicableTemplatesList)
		+ DriveClientServer.GetQueryDelimeter();
	
	Query.Text = TempTablesQueryText;
	Query.SetParameter("Ref"	, PostingParametersStructure.Ref);
	Query.SetParameter("Period"	, PostingParametersStructure.PointInTime);
	Query.SetParameter("Company", PostingParametersStructure.Company);

	Query.Execute();
	
EndProcedure

Function GetCompanyAccountingSettingsTable(Company, Period, DocumentRef)

	Query = New Query;
	Query.Text = 
	"SELECT
	|	CompaniesTypesOfAccountingSliceLast.TypeOfAccounting AS TypeOfAccounting,
	|	CompaniesTypesOfAccountingSliceLast.ChartOfAccounts AS ChartOfAccounts,
	|	CompaniesTypesOfAccountingSliceLast.EntriesPostingOption AS EntriesPostingOption,
	|	CompaniesTypesOfAccountingSliceLast.ChartOfAccounts.ChartOfAccounts AS ChartOfAccountsMetadataObjectRef,
	|	CompaniesTypesOfAccountingSliceLast.Inactive AS Inactive
	|FROM
	|	InformationRegister.CompaniesTypesOfAccounting.SliceLast(&Period, Company = &Company) AS CompaniesTypesOfAccountingSliceLast
	|WHERE
	|	NOT CompaniesTypesOfAccountingSliceLast.Inactive";
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("Period"	, Period);
	
	QueryResult = Query.Execute();

	SettingsTable = QueryResult.Unload();
	
	SettingsTable.Columns.Add("IsRecorder", New TypeDescription("Boolean"));
	
	For Each Row In SettingsTable Do
		Row.IsRecorder = DocumentIsRecorderForRegister(DocumentRef, Row.ChartOfAccountsMetadataObjectRef);
	EndDo;
	
	Return SettingsTable;

	SettingsTable = QueryResult.Unload();
	
	SettingsTable.Columns.Add("IsRecorder", New TypeDescription("Boolean"));
	
	For Each Row In SettingsTable Do
		Row.IsRecorder = DocumentIsRecorderForRegister(DocumentRef, Row.ChartOfAccountsMetadataObjectRef);
	EndDo;
	
	Return SettingsTable;
	
EndFunction

Function DocumentNotRecorder(AccountingSettingsTable)

	TableToCheck = AccountingSettingsTable.Copy();
	TableToCheck.GroupBy("IsRecorder");
	
	If TableToCheck.Count() > 1 Then
		Return False;
	Else
		Return Not TableToCheck[0].IsRecorder;
	EndIf;

EndFunction

Function GetApplicableTemplatesTable(Company, DocumentDate, DocumentMetadata, AccountingSettingsTable)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CompaniesTypesOfAccounting.ChartOfAccounts AS ChartOfAccounts,
	|	CompaniesTypesOfAccounting.TypeOfAccounting AS TypeOfAccounting
	|INTO SettingsTable
	|FROM
	|	&SettingsTable AS CompaniesTypesOfAccounting
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SettingsTable.TypeOfAccounting AS TypeOfAccounting,
	|	SettingsTable.ChartOfAccounts AS ChartOfAccounts,
	|	AccountingTransactionsTemplates.Ref AS Template,
	|	AccountingTransactionsTemplates.Company = VALUE(Catalog.Companies.EmptyRef) AS CompanyIsEmpty
	|FROM
	|	Catalog.AccountingTransactionsTemplates AS AccountingTransactionsTemplates
	|		INNER JOIN SettingsTable AS SettingsTable
	|		ON AccountingTransactionsTemplates.TypeOfAccounting = SettingsTable.TypeOfAccounting
	|			AND AccountingTransactionsTemplates.ChartOfAccounts = SettingsTable.ChartOfAccounts
	|WHERE
	|	AccountingTransactionsTemplates.Company IN (&Company, VALUE(Catalog.Companies.EmptyRef))
	|	AND AccountingTransactionsTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
	|	AND AccountingTransactionsTemplates.StartDate <= &DocumentDate
	|	AND CASE
	|			WHEN AccountingTransactionsTemplates.EndDate <> DATETIME(1, 1, 1)
	|				THEN &DocumentDate <= AccountingTransactionsTemplates.EndDate
	|			ELSE TRUE
	|		END
	|	AND AccountingTransactionsTemplates.DocumentType = &DocumentType";
	
	Query.SetParameter("Company"		, Company);
	Query.SetParameter("DocumentDate"	, DocumentDate);
	Query.SetParameter("DocumentType"	, Common.MetadataObjectID(DocumentMetadata));
	Query.SetParameter("SettingsTable"	, AccountingSettingsTable);
	
	QueryResult = Query.Execute();
	
	Return QueryResult.Unload();
	
EndFunction 

Procedure SetDocumentPostingStatus(DocumentRef, Company, Period, AccountingSettingsTable)
	
	Result = New Structure("Status, EntriesPostingOption");
	Result.Status = False;
	
	DocumentType = Common.MetadataObjectID(DocumentRef.Metadata());
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CompaniesTypesOfAccounting.ChartOfAccounts AS ChartOfAccounts,
	|	CompaniesTypesOfAccounting.EntriesPostingOption AS EntriesPostingOption,
	|	CompaniesTypesOfAccounting.TypeOfAccounting AS TypeOfAccounting
	|INTO SettingsTable
	|FROM
	|	&SettingsTable AS CompaniesTypesOfAccounting
	|
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(AccountingSourceDocumentsSliceLast.Uses, FALSE) AS IsRecorder,
	|	SettingsTable.TypeOfAccounting AS TypeOfAccounting,
	|	SettingsTable.ChartOfAccounts AS ChartOfAccounts,
	|	SettingsTable.EntriesPostingOption AS EntriesPostingOption
	|FROM
	|	SettingsTable AS SettingsTable
	|		LEFT JOIN InformationRegister.AccountingSourceDocuments.SliceLast(
	|				&Period,
	|				Company = &Company
	|					AND DocumentType = &DocumentType) AS AccountingSourceDocumentsSliceLast
	|		ON (AccountingSourceDocumentsSliceLast.TypeOfAccounting = SettingsTable.TypeOfAccounting)";

	Query.SetParameter("Company"			, Company);
	Query.SetParameter("DocumentType"		, DocumentType);
	Query.SetParameter("Period"				, Period);
	Query.SetParameter("SettingsTable"		, AccountingSettingsTable);
	
	QueryResult = Query.Execute();
	
	AccountingSettingsTable = QueryResult.Unload();
		
EndProcedure

Function DefaultAccountsFieldTextArray(Entry, DefaultAccountsTable)

	FieldTextArray = New Array;
	
	If ValueIsFilled(Entry.DefaultAccountType) Then
		
		DefaultAccountStructure = New Structure;
		DefaultAccountStructure.Insert("DefaultAccountTypeParameter"	, "DefaultAccountType");
		DefaultAccountStructure.Insert("AccountReferenceNameParameter"	, "AccountReferenceName");
		DefaultAccountStructure.Insert("DrCrParameter"					, "DrCrEmpty");
		
		AccountsText = GetDefaultAccountsFilterFields(Entry, 
			DefaultAccountsTable, 
			Entry.RowID, 
			Enums.DebitCredit.EmptyRef(),
			DefaultAccountStructure);
		
		FieldTextArray.Add(AccountsText);
		
	EndIf;
	
	If ValueIsFilled(Entry.DefaultAccountTypeCr) Then
		
		DefaultAccountStructure = New Structure;
		DefaultAccountStructure.Insert("DefaultAccountTypeParameter"	, "DefaultAccountTypeCr");
		DefaultAccountStructure.Insert("AccountReferenceNameParameter"	, "AccountReferenceNameCr");
		DefaultAccountStructure.Insert("DrCrParameter"					, "DrCrCredit");
		
		AccountsText = GetDefaultAccountsFilterFields(Entry, 
			DefaultAccountsTable, 
			Entry.RowID, 
			Enums.DebitCredit.Cr,
			DefaultAccountStructure);
		
		FieldTextArray.Add(AccountsText);
		
	EndIf;
	
	If ValueIsFilled(Entry.DefaultAccountTypeDr) Then
		
		DefaultAccountStructure = New Structure;
		DefaultAccountStructure.Insert("DefaultAccountTypeParameter"	, "DefaultAccountTypeDr");
		DefaultAccountStructure.Insert("AccountReferenceNameParameter"	, "AccountReferenceNameDr");
		DefaultAccountStructure.Insert("DrCrParameter"					, "DrCrDebit");
		
		AccountsText = GetDefaultAccountsFilterFields(Entry, 
			DefaultAccountsTable, 
			Entry.RowID, 
			Enums.DebitCredit.Dr,
			DefaultAccountStructure);
		
		FieldTextArray.Add(AccountsText);
		
	EndIf;

	Return FieldTextArray;
	
EndFunction

Procedure ProcessDefaultAccounts(DefaultAccountsTable, RecordsTable, AccountPostfix = "")
	
	If RecordsTable.Count() > 0 Then
		
		For Each DefaultAccountsRow In DefaultAccountsTable Do
			
			SearchStructure = New Structure;
			SearchStructure.Insert(StrTemplate("DefaultAccountType%1"	, AccountPostfix)	, DefaultAccountsRow.DefaultAccountType);
			SearchStructure.Insert(StrTemplate("AccountReferenceName%1"	, AccountPostfix)	, DefaultAccountsRow.AccountReferenceName);
			SearchStructure.Insert(StrTemplate("ConnectionKey%1"		, AccountPostfix)	, DefaultAccountsRow.ConnectionKey);
			
			SearchStructure.Insert(StrTemplate("DrCr%1"		, AccountPostfix)				, DefaultAccountsRow.DrCr);
			SearchStructure.Insert(StrTemplate("Filter1%1"	, AccountPostfix)				, DefaultAccountsRow.Filter1);
			SearchStructure.Insert(StrTemplate("Filter2%1"	, AccountPostfix)				, DefaultAccountsRow.Filter2);
			SearchStructure.Insert(StrTemplate("Filter3%1"	, AccountPostfix)				, DefaultAccountsRow.Filter3);
			SearchStructure.Insert(StrTemplate("Filter4%1"	, AccountPostfix)				, DefaultAccountsRow.Filter4);
			
			FoundRows = RecordsTable.FindRows(SearchStructure);
			
			For Each Row In FoundRows Do
				
				Row["Account" + AccountPostfix] = DefaultAccountsRow.Account;
				
				If Not DefaultAccountsRow.Currency Then
					Row["Currency"	+ AccountPostfix] = Undefined;
					Row["AmountCur"	+ AccountPostfix] = Undefined;
				EndIf;
				
				If Not DefaultAccountsRow.Quantity Then
					Row["Quantity"	+ AccountPostfix] = Undefined;
				EndIf;
				
			EndDo;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Function DocumentPostingRequired(DocumentRef, Company, TypesOfAccounting, Period)
	
	If Not Constants.AccountingModuleSettings.UseTemplatesIsEnabled() Then
		Return False;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	CompaniesTypesOfAccounting.TypeOfAccounting AS TypeOfAccounting
	|INTO TT_CompaniesTypesOfAccounting
	|FROM
	|	InformationRegister.CompaniesTypesOfAccounting.SliceLast(&Period, Company = &Company AND TypeOfAccounting IN(&TypesOfAccounting)) AS CompaniesTypesOfAccounting
	|WHERE
	|	NOT CompaniesTypesOfAccounting.Inactive;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountingSourceDocumentsSliceLast.Uses AS Uses
	|FROM
	|	InformationRegister.AccountingSourceDocuments.SliceLast(
	|			&Period,
	|			Company = &Company
	|				AND DocumentType = &DocumentType
	|				AND TypeOfAccounting IN
	|					(SELECT
	|						TT_CompaniesTypesOfAccounting.TypeOfAccounting AS TypeOfAccounting
	|					FROM
	|						TT_CompaniesTypesOfAccounting AS TT_CompaniesTypesOfAccounting)) AS AccountingSourceDocumentsSliceLast
	|WHERE
	|	AccountingSourceDocumentsSliceLast.Uses";
	
	Query.SetParameter("Company"			, Company);
	Query.SetParameter("DocumentType"		, Common.MetadataObjectID(DocumentRef.Metadata()));
	Query.SetParameter("Period"				, Period);
	Query.SetParameter("TypesOfAccounting"	, TypesOfAccounting);
	
	QueryResult = Query.Execute();
	
	Return Not QueryResult.IsEmpty();
	
EndFunction

Function RefillValueTableByObjectTable(RegisterFullName, RegisterName, TableWithoutTypes)
	
	ParameterValueTableQuery = New Query;
	ParameterValueTableQuery.Text =
	"SELECT TOP 0
	|	*
	|FROM
	|	RegisterFullName AS RegisterName";
	
	ParameterValueTableQuery.Text = StrReplace(ParameterValueTableQuery.Text, "RegisterFullName", RegisterFullName);
	ParameterValueTableQuery.Text = StrReplace(ParameterValueTableQuery.Text, "RegisterName"	, RegisterName);
	
	TableWithTypes = ParameterValueTableQuery.Execute().Unload();
	
	For Each Row In TableWithoutTypes Do
		FillPropertyValues(TableWithTypes.Add(), Row); 
	EndDo;
	
	Return TableWithTypes;
	
EndFunction

Procedure ClearExcessiveAttributes(TableCompound, TableSimple)
	
	AccountList	= TableCompound.UnloadColumn("Account");
	AccountListDr	= TableSimple.UnloadColumn("AccountDr");
	AccountListCr	= TableSimple.UnloadColumn("AccountCr");
	
	CommonClientServer.SupplementArray(AccountList, AccountListDr);
	CommonClientServer.SupplementArray(AccountList, AccountListCr);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	MasterChartOfAccountsExtDimensionTypes.Ref AS Account,
	|	MasterChartOfAccountsExtDimensionTypes.ExtDimensionType AS ExtDimensionType
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts.ExtDimensionTypes AS MasterChartOfAccountsExtDimensionTypes
	|WHERE
	|	MasterChartOfAccountsExtDimensionTypes.Ref IN(&AccountList)";
	
	Query.SetParameter("AccountList", AccountList);
	
	QueryResult = Query.Execute();
	
	AccountTable = QueryResult.Unload();
	
	RemoveExcessiveAttributes(TableCompound	, AccountTable, "");
	RemoveExcessiveAttributes(TableSimple	, AccountTable, "Dr");
	RemoveExcessiveAttributes(TableSimple	, AccountTable, "Cr");
	
EndProcedure

Procedure CheckEntriesAccounts(StructureAdditionalProperties, Cancel) Export
	
	TableCompound = New ValueTable;
	TableCompound.Columns.Add("Period"	, New TypeDescription("Date"));
	TableCompound.Columns.Add("Company"	, New TypeDescription("CatalogRef.Companies"));
	TableCompound.Columns.Add("Account"	, New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts"));
	
	If StructureAdditionalProperties.TableForRegisterRecords.Property("TableAccountingJournalEntriesCompound") Then
		For Each Row In StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntriesCompound Do
			
			NewRow = TableCompound.Add();
			FillPropertyValues(NewRow, Row);
			
		EndDo;
	EndIf;
	
	TableSimple = New ValueTable;
	TableSimple.Columns.Add("Period"	, New TypeDescription("Date"));
	TableSimple.Columns.Add("Company"	, New TypeDescription("CatalogRef.Companies"));
	TableSimple.Columns.Add("AccountDr"	, New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts"));
	TableSimple.Columns.Add("AccountCr"	, New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts"));
	
	If StructureAdditionalProperties.TableForRegisterRecords.Property("TableAccountingJournalEntriesSimple") Then
		For Each Row In StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntriesSimple Do
			
			NewRow = TableSimple.Add();
			FillPropertyValues(NewRow, Row);
			
		EndDo;
	EndIf;
	
	If TableCompound.Count() = 0
		And TableSimple.Count() = 0 Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TableCompound.Period AS Period,
	|	TableCompound.Company AS Company,
	|	TableCompound.Account AS Account
	|INTO TemporaryTableCompound
	|FROM
	|	&TableCompound AS TableCompound
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableSimple.Period AS Period,
	|	TableSimple.Company AS Company,
	|	TableSimple.AccountDr AS AccountDr,
	|	TableSimple.AccountCr AS AccountCr
	|INTO TemporaryTableSimple
	|FROM
	|	&TableSimple AS TableSimple
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableCompound.Period AS Period,
	|	TemporaryTableCompound.Company AS Company,
	|	TemporaryTableCompound.Account AS Account
	|INTO TemporaryTableEntriesAccounts
	|FROM
	|	TemporaryTableCompound AS TemporaryTableCompound
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTableSimple.Period,
	|	TemporaryTableSimple.Company,
	|	TemporaryTableSimple.AccountDr
	|FROM
	|	TemporaryTableSimple AS TemporaryTableSimple
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTableSimple.Period,
	|	TemporaryTableSimple.Company,
	|	TemporaryTableSimple.AccountCr
	|FROM
	|	TemporaryTableSimple AS TemporaryTableSimple
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableEntriesAccounts.Period AS Period,
	|	TemporaryTableEntriesAccounts.Company AS Company,
	|	TemporaryTableEntriesAccounts.Account AS Account
	|INTO TemporaryTableEntriesAccountsGroup
	|FROM
	|	TemporaryTableEntriesAccounts AS TemporaryTableEntriesAccounts
	|
	|GROUP BY
	|	TemporaryTableEntriesAccounts.Period,
	|	TemporaryTableEntriesAccounts.Company,
	|	TemporaryTableEntriesAccounts.Account
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableEntriesAccountsGroup.Account AS Account,
	|	MAX(CASE
	|			WHEN MasterChartOfAccountsCompanies.Ref IS NULL
	|				THEN FALSE
	|			ELSE TRUE
	|		END) AS HasCompanies
	|INTO TemporaryTableAccountsHasCompanies
	|FROM
	|	TemporaryTableEntriesAccountsGroup AS TemporaryTableEntriesAccountsGroup
	|		LEFT JOIN ChartOfAccounts.MasterChartOfAccounts.Companies AS MasterChartOfAccountsCompanies
	|		ON TemporaryTableEntriesAccountsGroup.Account = MasterChartOfAccountsCompanies.Ref
	|
	|GROUP BY
	|	TemporaryTableEntriesAccountsGroup.Account
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableEntriesAccountsGroup.Period AS Period,
	|	TemporaryTableEntriesAccountsGroup.Company AS Company,
	|	TemporaryTableEntriesAccountsGroup.Account AS Account,
	|	ISNULL(TemporaryTableAccountsHasCompanies.HasCompanies, FALSE) AS HasCompanies
	|INTO TemporaryTableAccounts
	|FROM
	|	TemporaryTableEntriesAccountsGroup AS TemporaryTableEntriesAccountsGroup
	|		LEFT JOIN TemporaryTableAccountsHasCompanies AS TemporaryTableAccountsHasCompanies
	|		ON TemporaryTableEntriesAccountsGroup.Account = TemporaryTableAccountsHasCompanies.Account
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableAccounts.Period AS Period,
	|	TemporaryTableAccounts.Company AS Company,
	|	TemporaryTableAccounts.Account AS Account,
	|	TemporaryTableAccounts.HasCompanies AS HasCompanies,
	|	CASE
	|		WHEN TemporaryTableAccounts.HasCompanies
	|			THEN CASE
	|					WHEN MasterChartOfAccountsCompanies.Company IS NULL
	|						THEN 1
	|					WHEN MasterChartOfAccountsCompanies.StartDate <> DATETIME(1, 1, 1)
	|							AND TemporaryTableAccounts.Period < MasterChartOfAccountsCompanies.StartDate
	|						THEN 2
	|					WHEN MasterChartOfAccountsCompanies.EndDate <> DATETIME(1, 1, 1)
	|							AND TemporaryTableAccounts.Period > ENDOFPERIOD(MasterChartOfAccountsCompanies.EndDate, DAY)
	|						THEN 2
	|					ELSE 0
	|				END
	|		ELSE CASE
	|				WHEN MasterChartOfAccounts.StartDate <> DATETIME(1, 1, 1)
	|						AND TemporaryTableAccounts.Period < MasterChartOfAccounts.StartDate
	|					THEN 2
	|				WHEN MasterChartOfAccounts.EndDate <> DATETIME(1, 1, 1)
	|						AND TemporaryTableAccounts.Period > ENDOFPERIOD(MasterChartOfAccounts.EndDate, DAY)
	|					THEN 2
	|				ELSE 0
	|			END
	|	END AS Error
	|FROM
	|	TemporaryTableAccounts AS TemporaryTableAccounts
	|		LEFT JOIN ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
	|		ON TemporaryTableAccounts.Account = MasterChartOfAccounts.Ref
	|		LEFT JOIN ChartOfAccounts.MasterChartOfAccounts.Companies AS MasterChartOfAccountsCompanies
	|		ON TemporaryTableAccounts.Account = MasterChartOfAccountsCompanies.Ref
	|			AND TemporaryTableAccounts.Company = MasterChartOfAccountsCompanies.Company
	|WHERE
	|	CASE
	|			WHEN TemporaryTableAccounts.HasCompanies
	|				THEN CASE
	|						WHEN MasterChartOfAccountsCompanies.Company IS NULL
	|							THEN 1
	|						WHEN MasterChartOfAccountsCompanies.StartDate <> DATETIME(1, 1, 1)
	|								AND TemporaryTableAccounts.Period < MasterChartOfAccountsCompanies.StartDate
	|							THEN 2
	|						WHEN MasterChartOfAccountsCompanies.EndDate <> DATETIME(1, 1, 1)
	|								AND TemporaryTableAccounts.Period > ENDOFPERIOD(MasterChartOfAccountsCompanies.EndDate, DAY)
	|							THEN 2
	|						ELSE 0
	|					END
	|			ELSE CASE
	|					WHEN MasterChartOfAccounts.StartDate <> DATETIME(1, 1, 1)
	|							AND TemporaryTableAccounts.Period < MasterChartOfAccounts.StartDate
	|						THEN 2
	|					WHEN MasterChartOfAccounts.EndDate <> DATETIME(1, 1, 1)
	|							AND TemporaryTableAccounts.Period > ENDOFPERIOD(MasterChartOfAccounts.EndDate, DAY)
	|						THEN 2
	|					ELSE 0
	|				END
	|		END > 0";
	
	Query.SetParameter("TableCompound"	, TableCompound);
	Query.SetParameter("TableSimple"	, TableSimple);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Cancel = True;
		
		ErrorPeriodTemplate	 = MessagesToUserClientServer.GetCheckEntriesAccountsErrorPeriodText();
		ErrorCompanyTemplate = MessagesToUserClientServer.GetCheckEntriesAccountsErrorCompanyText();
		
		Selection = QueryResult.Select();
		
		While Selection.Next() Do
			ErrorText = "";
			If Selection.Error = 1 Then
				ErrorText = StrTemplate(ErrorCompanyTemplate, Selection.Account, Selection.Company);
			ElsIf Selection.Error = 2 Then
				ErrorText = StrTemplate(ErrorPeriodTemplate, Selection.Account);
			EndIf;
			
			CommonClientServer.MessageToUser(ErrorText);
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure RemoveExcessiveAttributes(DataTable, AccountTable, NameAdding)
	
	MaxDimensions = ChartsOfAccounts.MasterChartOfAccounts.MaxAnalyticalDimensionsNumber();
	EmptyDimensionType = ChartsOfCharacteristicTypes.ManagerialAnalyticalDimensionTypes.EmptyRef();
	
	For Each Row In DataTable Do
		
		For Count = 1 To MaxDimensions Do
			
			ExtDimensionType = Row[StrTemplate("ExtDimensionType%1%2", NameAdding, Count)];
			If ValueIsFilled(ExtDimensionType) Then
				
				Filter = New Structure;
				Filter.Insert("Account"			, Row[StrTemplate("Account%1", NameAdding)]);
				Filter.Insert("ExtDimensionType", ExtDimensionType);
				
				FoundRows = AccountTable.FindRows(Filter);
				
				If FoundRows.Count() = 0 Then
					
					Row[StrTemplate("ExtDimensionType%1%2"	, NameAdding, Count)] = EmptyDimensionType;
					Row[StrTemplate("ExtDimension%1%2"		, NameAdding, Count)] = Undefined;
					
				EndIf;
				
			Else
				Break;
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure AddAttributesToAdditionalPropertiesForPosting(DocumentObject, AdditionalProperties)
	
	If TypeOf(DocumentObject) = Type("DocumentObject.SalesSlip") Then
		AdditionalProperties.ForPosting.Insert("CheckIssued", DocumentObject.Status = Enums.SalesSlipStatus.Issued);
		AdditionalProperties.ForPosting.Insert("ProductReserved", DocumentObject.Status = Enums.SalesSlipStatus.ProductReserved);
		AdditionalProperties.ForPosting.Insert("Archival", DocumentObject.Archival);
	EndIf;

EndProcedure

Procedure AddRequiredTableAccountingEntriesData(AdditionalProperties)
	
	// The ability to fill in TableAccountingEntriesData in any "GenerateTable..." procedure
	AdditionalProperties.TableForRegisterRecords.Insert(
		"TableAccountingEntriesData", InformationRegisters.AccountingEntriesData.EmptyTableAccountingEntriesData());
	
EndProcedure

#EndRegion