
#Region Public

Procedure OnReadAtServer(Form, CurrentObject) Export
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	UseAccountingApproval = GetFunctionalOption("UseAccountingApproval");
	
	If Not UseAccountingApproval
		And Not UseDefaultTypeOfAccounting Then
		Return;
	EndIf;
	
	IsAccountingTransaction			= (TypeOf(CurrentObject) = Type("DocumentObject.AccountingTransaction"));
	IsManualAccountingTransaction	= (IsAccountingTransaction And CurrentObject.IsManual);
	
	If IsAccountingTransaction Then
		Return;
	EndIf;
	
	StatusStructure = GetAccountinEntriesStatus(CurrentObject.Ref);
	If StatusStructure = Undefined Then
		Return;
	EndIf;
	
	MessageText = "";
	
	If StatusStructure.Status = Enums.AccountingEntriesStatus.NotApproved Then
		
		If StatusStructure.AdjustedManually And Not IsManualAccountingTransaction Then
			MessageText = NStr("en = 'For this document, the accounting entries are already adjusted. It is not recommended to edit the document.'; ru = 'Для этого документа бухгалтерские проводки уже скорректированы. Изменение документа не рекомендуется.';pl = 'Dla tego dokumentu, wpisy księgowe są już skorygowane. Edycja dokumentu nie jest zalecana.';es_ES = 'En este documento, las entradas contables ya están ajustadas. No se recomienda editar el documento.';es_CO = 'En este documento, los asientos contables ya están ajustados. No se recomienda editar el documento.';tr = 'Bu belge için muhasebe girişleri zaten ayarlandı. Bu belgeyi düzenlemek önerilmez.';it = 'Gli inserimenti contabili sono già stati corretti per questo documento. Non è consigliata la modifica del documento.';de = 'Für dieses Dokument werden die Buchhaltungseinträge bereits angepasst. Es wird nicht empfohlen, das Dokument zu bearbeiten.'");
		Else
			Return;
		EndIf;
		
	Else
		
		PreventRepostingDocuments = GetFunctionalOption("PreventRepostingDocumentsWithApprovedAccountingEntries");
		HasRightChangeApprovedDocuments = Users.IsFullUser(Users.AuthorizedUser())
			Or AccessManagement.HasRole("ChangeApprovedDocuments");
		
		If PreventRepostingDocuments
			And Not HasRightChangeApprovedDocuments Then
			MessageText = NStr("en = 'For this document, the accounting entries are posted and approved. The document editing is restricted.'; ru = 'Для этого документа бухгалтерские проводки проведены и утверждены. Изменение документа запрещено.';pl = 'Dla tego dokumentu, wpisy księgowe są zatwierdzane i potwierdzane. Edycja dokumentu jest ograniczona.';es_ES = 'En este documento, las entradas contables se contabilizan y aprueban. La edición del documento está limitada.';es_CO = 'En este documento, las entradas contables se contabilizan y aprueban. La edición del documento está limitada.';tr = 'Bu belge için muhasebe girişleri kaydedildi ve onaylandı. Belge düzenlemesi sınırlandırılmıştır.';it = 'Gli inserimenti contabili sono pubblicati e approvati per questo documento. La modifica del documento è limitata.';de = 'Für dieses Dokument werden die Buchhaltungseinträge gebucht und genehmigt. Die Bearbeitung des Dokuments ist beschränkt.'");
			Form.ReadOnly = True;
		Else
			MessageText = NStr("en = 'For this document, the accounting entries are posted and approved. It is not recommended to edit the document.'; ru = 'Для этого документа бухгалтерские проводки проведены и утверждены. Изменение документа не рекомендуется.';pl = 'Dla tego dokumentu, wpisy księgowe są zatwierdzane i potwierdzane. Edycja dokumentu nie jest zalecana.';es_ES = 'En este documento, la entradas contables se contabilizan y aprueban. No se recomienda editar el documento.';es_CO = 'En este documento, los asientos contables se contabilizan y aprueban. No se recomienda editar el documento.';tr = 'Bu belge için muhasebe girişleri kaydedildi ve onaylandı. Bu belgeyi düzenlemek önerilmez.';it = 'Gli inserimenti contabili sono pubblicati e approvati per questo documento. Non è consigliata la modifica del documento.';de = 'Für dieses Dokument werden die Buchhaltungseinträge gebucht und genehmigt. Es wird nicht empfohlen, das Dokument zu bearbeiten.'");
		EndIf;
		
	EndIf;
	
	If Not IsBlankString(MessageText) Then
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

Procedure BeforeWriteAtServer(CurrentObject, Cancel, Form = Undefined) Export

	If Cancel
		Or CurrentObject.DataExchange.Load Then
		Return;
	EndIf;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	If Not UseDefaultTypeOfAccounting Then
		Return;
	EndIf;
	
	If Form <> Undefined Then
		CurrentObject.AdditionalProperties.Insert("Modified", Form.Modified Or CurrentObject.IsNew());
	EndIf;
	
	StatusStructure = GetAccountinEntriesStatus(CurrentObject.Ref);
	If StatusStructure = Undefined
		Or StatusStructure.Status = Enums.AccountingEntriesStatus.NotApproved Then
		Return;
	EndIf;
	
	MessageText = "";
	
	PreventRepostingDocuments = GetFunctionalOption("PreventRepostingDocumentsWithApprovedAccountingEntries");
	HasRightChangeApprovedDocuments = Users.IsFullUser(Users.AuthorizedUser())
		Or AccessManagement.HasRole("ChangeApprovedDocuments");
	
	If PreventRepostingDocuments
		And Not HasRightChangeApprovedDocuments Then
		MessageText = NStr("en = 'For this document, the accounting entries are posted and approved. The document editing is restricted.'; ru = 'Для этого документа бухгалтерские проводки проведены и утверждены. Изменение документа запрещено.';pl = 'Dla tego dokumentu, wpisy księgowe są zatwierdzane i potwierdzane. Edycja dokumentu jest ograniczona.';es_ES = 'En este documento, las entradas contables se contabilizan y aprueban. La edición del documento está limitada.';es_CO = 'En este documento, las entradas contables se contabilizan y aprueban. La edición del documento está limitada.';tr = 'Bu belge için muhasebe girişleri kaydedildi ve onaylandı. Belge düzenlemesi sınırlandırılmıştır.';it = 'Gli inserimenti contabili sono pubblicati e approvati per questo documento. La modifica del documento è limitata.';de = 'Für dieses Dokument werden die Buchhaltungseinträge gebucht und genehmigt. Die Bearbeitung des Dokuments ist beschränkt.'");
	EndIf;
	
	If Not IsBlankString(MessageText) Then
		Cancel = True;
		CommonClientServer.MessageToUser(MessageText, , , , Cancel);
	EndIf;
	
EndProcedure

Procedure DocumentListOnGetDataAtServer(Rows, RecordersArray = Undefined, RecordersTable = Undefined, SimpleKey = False) Export
	
	If RecordersArray = Undefined Then
		RecordersArray = Rows.GetKeys();
	EndIf;
	
	If RecordersTable = Undefined Then
		RecordersTable = New ValueTable;
	EndIf;
	
	RecordersTable.Columns.Add("Ref"							, Metadata.DefinedTypes.AccountingEntriesRecorder.Type);
	RecordersTable.Columns.Add("TypeOfAccounting"				, New TypeDescription("CatalogRef.TypesOfAccounting"));
	RecordersTable.Columns.Add("ChartOfAccounts"				, New TypeDescription("CatalogRef.ChartsOfAccounts"));
	
	For Each Recorder In RecordersArray Do
		Row = RecordersTable.Add();
		FillPropertyValues(Row, Recorder);
	EndDo;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	RecordersTable.TypeOfAccounting AS TypeOfAccounting,
	|	RecordersTable.Ref AS Ref,
	|	RecordersTable.ChartOfAccounts
	|INTO Recorders
	|FROM
	|	&Recorders AS RecordersTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Recorders.Ref AS Recorder,
	|	Recorders.TypeOfAccounting AS TypeOfAccounting,
	|	Recorders.ChartOfAccounts,
	|	CASE
	|		WHEN FilesExist.HasFiles
	|			THEN 1
	|		ELSE 0
	|	END AS HasFiles
	|FROM
	|	Recorders AS Recorders
	|		LEFT JOIN InformationRegister.FilesExist AS FilesExist
	|		ON Recorders.Ref = FilesExist.ObjectWithFiles";
	
	Query.SetParameter("Recorders", RecordersTable);
	QueryResult = Query.Execute();
		
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		
		If SimpleKey Then
			
			RowKey = Selection.Recorder;
			
		Else
			
			KeyStructure = New Structure;
			KeyStructure.Insert("Ref"							, Selection.Recorder);
			KeyStructure.Insert("TypeOfAccounting"				, Selection.TypeOfAccounting);
			KeyStructure.Insert("ChartOfAccounts"				, Selection.ChartOfAccounts);
			
			RowKey	 = New DynamicListRowKey(KeyStructure);
			
		EndIf;
		
		ListRow	 = Rows[RowKey];
		FillPropertyValues(ListRow.Data, Selection);
		
	EndDo;
	
EndProcedure

Function GetRecordSetMasterByRecorder(Recorder) Export 

	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.Period AS Period,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.Recorder AS Recorder,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.LineNumber AS LineNumber,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.Active AS Active,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.RecordType AS RecordType,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.Account AS Account,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.Company AS Company,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.PlanningPeriod AS PlanningPeriod,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.Currency AS Currency,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.Status AS Status,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.Amount AS Amount,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.AmountCur AS AmountCur,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.Content AS Content,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.OfflineRecord AS OfflineRecord,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.TransactionTemplate AS TransactionTemplate,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.TransactionTemplateLineNumber AS TransactionTemplateLineNumber,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.TypeOfAccounting AS TypeOfAccounting,
	|	CASE
	|		WHEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.RecordType = VALUE(AccountingRecordType.Credit)
	|			THEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.Amount
	|		ELSE 0
	|	END AS AmountCr,
	|	CASE
	|		WHEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.RecordType = VALUE(AccountingRecordType.Debit)
	|			THEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.Amount
	|		ELSE 0
	|	END AS AmountDr,
	|	CASE
	|		WHEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.RecordType = VALUE(AccountingRecordType.Credit)
	|			THEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.Quantity
	|		ELSE 0
	|	END AS QuantityCr,
	|	CASE
	|		WHEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.RecordType = VALUE(AccountingRecordType.Debit)
	|			THEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.Quantity
	|		ELSE 0
	|	END AS QuantityDr,
	|	CASE
	|		WHEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.RecordType = VALUE(AccountingRecordType.Credit)
	|			THEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CASE
	|		WHEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.RecordType = VALUE(AccountingRecordType.Debit)
	|			THEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.RecordType = VALUE(AccountingRecordType.Credit)
	|			THEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.Currency
	|		ELSE NULL
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.RecordType = VALUE(AccountingRecordType.Debit)
	|			THEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.Currency
	|		ELSE NULL
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.RecordType = VALUE(AccountingRecordType.Credit)
	|				AND AccountingJournalEntriesCompoundRecordsWithExtDimensions.Active
	|			THEN 2
	|		WHEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.RecordType = VALUE(AccountingRecordType.Credit)
	|				AND NOT AccountingJournalEntriesCompoundRecordsWithExtDimensions.Active
	|			THEN 4
	|		WHEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.RecordType = VALUE(AccountingRecordType.Debit)
	|				AND AccountingJournalEntriesCompoundRecordsWithExtDimensions.Active
	|			THEN 1
	|		WHEN AccountingJournalEntriesCompoundRecordsWithExtDimensions.RecordType = VALUE(AccountingRecordType.Debit)
	|				AND NOT AccountingJournalEntriesCompoundRecordsWithExtDimensions.Active
	|			THEN 3
	|	END AS RecordSetPicture,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.ExtDimension1 AS ExtDimension1,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.ExtDimension2 AS ExtDimension2,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.ExtDimension3 AS ExtDimension3,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.ExtDimension4 AS ExtDimension4,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.ExtDimensionType1 AS ExtDimensionType1,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.ExtDimensionType2 AS ExtDimensionType2,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.ExtDimensionType3 AS ExtDimensionType3,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.ExtDimensionType4 AS ExtDimensionType4,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.Quantity AS Quantity,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.EntryNumber AS EntryNumber,
	|	AccountingJournalEntriesCompoundRecordsWithExtDimensions.EntryLineNumber AS EntryLineNumber
	|FROM
	|	AccountingRegister.AccountingJournalEntriesCompound.RecordsWithExtDimensions(, , Recorder = &Recorder, , ) AS AccountingJournalEntriesCompoundRecordsWithExtDimensions";
	
	Query.SetParameter("Recorder", Recorder);
	
	QureyResult = Query.Execute();
	
	ResultTable = QureyResult.Unload();
	
	ResultTable.Columns.Add("ExtDimensionPresentation1");
	ResultTable.Columns.Add("ExtDimensionPresentation2");
	ResultTable.Columns.Add("ExtDimensionPresentation3");
	ResultTable.Columns.Add("ExtDimensionPresentation4");
	ResultTable.Columns.Add("ExtDimensionEnabled1");
	ResultTable.Columns.Add("ExtDimensionEnabled2");
	ResultTable.Columns.Add("ExtDimensionEnabled3");
	ResultTable.Columns.Add("ExtDimensionEnabled4");
	ResultTable.Columns.Add("UseQuantity");
	ResultTable.Columns.Add("UseCurrency");
	ResultTable.Columns.Add("NumberPresentation");
	
	Return ResultTable;
	
EndFunction

Function GetRecordSetSimpleByRecorder(Recorder) Export 

	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.Period AS Period,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.Recorder AS Recorder,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.LineNumber AS LineNumber,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.Active AS Active,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.AccountDr AS AccountDr,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionDr1 AS ExtDimensionDr1,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionTypeDr1 AS ExtDimensionTypeDr1,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionDr2 AS ExtDimensionDr2,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionTypeDr2 AS ExtDimensionTypeDr2,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionDr3 AS ExtDimensionDr3,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionTypeDr3 AS ExtDimensionTypeDr3,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionDr4 AS ExtDimensionDr4,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionTypeDr4 AS ExtDimensionTypeDr4,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.AccountCr AS AccountCr,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionCr1 AS ExtDimensionCr1,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionTypeCr1 AS ExtDimensionTypeCr1,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionCr2 AS ExtDimensionCr2,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionTypeCr2 AS ExtDimensionTypeCr2,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionCr3 AS ExtDimensionCr3,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionTypeCr3 AS ExtDimensionTypeCr3,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionCr4 AS ExtDimensionCr4,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.ExtDimensionTypeCr4 AS ExtDimensionTypeCr4,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.Company AS Company,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.PlanningPeriod AS PlanningPeriod,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.CurrencyDr AS CurrencyDr,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.CurrencyCr AS CurrencyCr,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.Status AS Status,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.TypeOfAccounting AS TypeOfAccounting,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.Amount AS Amount,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.AmountCurDr AS AmountCurDr,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.AmountCurCr AS AmountCurCr,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.QuantityDr AS QuantityDr,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.QuantityCr AS QuantityCr,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.Content AS Content,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.OfflineRecord AS OfflineRecord,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.TransactionTemplate AS TransactionTemplate,
	|	AccountingJournalEntriesSimpleRecordsWithExtDimensions.TransactionTemplateLineNumber AS TransactionTemplateLineNumber
	|FROM
	|	AccountingRegister.AccountingJournalEntriesSimple.RecordsWithExtDimensions(, , Recorder = &Recorder, , ) AS AccountingJournalEntriesSimpleRecordsWithExtDimensions";
	
	Query.SetParameter("Recorder", Recorder);
	
	QureyResult = Query.Execute();
	
	ResultTable = QureyResult.Unload();
	
	ResultTable.Columns.Add("RecordSetPicture");
	ResultTable.Columns.Add("UseQuantityDr");
	ResultTable.Columns.Add("UseQuantityCr");
	ResultTable.Columns.Add("UseCurrencyDr");
	ResultTable.Columns.Add("UseCurrencyCr");
	ResultTable.Columns.Add("ExtDimensionPresentationDr1");
	ResultTable.Columns.Add("ExtDimensionPresentationDr2");
	ResultTable.Columns.Add("ExtDimensionPresentationDr3");
	ResultTable.Columns.Add("ExtDimensionPresentationDr4");
	ResultTable.Columns.Add("ExtDimensionPresentationCr1");
	ResultTable.Columns.Add("ExtDimensionPresentationCr2");
	ResultTable.Columns.Add("ExtDimensionPresentationCr3");
	ResultTable.Columns.Add("ExtDimensionPresentationCr4");
	ResultTable.Columns.Add("ExtDimensionEnabledDr1");
	ResultTable.Columns.Add("ExtDimensionEnabledDr2");
	ResultTable.Columns.Add("ExtDimensionEnabledDr3");
	ResultTable.Columns.Add("ExtDimensionEnabledDr4");
	ResultTable.Columns.Add("ExtDimensionEnabledCr1");
	ResultTable.Columns.Add("ExtDimensionEnabledCr2");
	ResultTable.Columns.Add("ExtDimensionEnabledCr3");
	ResultTable.Columns.Add("ExtDimensionEnabledCr4");
	
	Return ResultTable;
	
EndFunction

Function GetMasterByChartOfAccounts(ChartOfAccounts) Export
	
	ChartOfAccountsEnum = Common.ObjectAttributeValue(ChartOfAccounts, "ChartOfAccounts");

	Return ChartOfAccountsEnum = Enums.ChartsOfAccounts.MasterChartOfAccounts;
	
EndFunction

Function GetChartOfAccountsName(ChartOfAccountsEnum) Export
	
	If ChartOfAccountsEnum = Enums.ChartsOfAccounts.FinancialChartOfAccounts Then
		ChartOfAccountsName = Metadata.ChartsOfAccounts.FinancialChartOfAccounts.Name;
	ElsIf ChartOfAccountsEnum = Enums.ChartsOfAccounts.MasterChartOfAccounts Then
		ChartOfAccountsName = Metadata.ChartsOfAccounts.MasterChartOfAccounts.Name;
	ElsIf ChartOfAccountsEnum = Enums.ChartsOfAccounts.PrimaryChartOfAccounts Then
		ChartOfAccountsName = Metadata.ChartsOfAccounts.PrimaryChartOfAccounts.Name;
	Else
		ChartOfAccountsName = "";
	EndIf;

	Return ChartOfAccountsName;
	
EndFunction

#EndRegion

#Region Internal

Procedure ChangeDocumentAccountingEntriesStatus(Parameters, ResultAddress = "") Export
	
	RegisterAccountingEntriesStatus(Parameters, ResultAddress);
	
EndProcedure

Function GetAllDocumentTypes()

	Types = New ValueList;
	
	AttributesTable = WorkWithArbitraryParameters.InitParametersTable();
	
	WorkWithArbitraryParameters.GetRecordersListByCoA(AttributesTable);
	
	AttributesTable.Sort("Synonym");
	
	For Each Row In AttributesTable Do
		
		EmptyRefValue = Common.ObjectAttributeValue(Row.Field, "EmptyRefValue");
		If EmptyRefValue = Documents.AccountingTransaction.EmptyRef() Then
			Continue;
		EndIf;
		
		If Types.FindByValue(Row.Field) = Undefined Then
			Types.Add(Row.Field, Row.Synonym, True);
		EndIf;
		
	EndDo;
	
	Return Types;
	
EndFunction

Function GetDocumentTypes(FilterStructure = Undefined) Export
	
	Var OldTypes, PeriodStart, PeriodEnd, Company, TypeOfAccounting;
	
	If FilterStructure = Undefined Then
		
		OldTypes		 = Undefined;
		PeriodStart		 = Undefined;
		PeriodEnd		 = Undefined;
		Company			 = Undefined;
		TypeOfAccounting = Undefined;
		
	Else
		
		FilterStructure.Property("OldTypes"			, OldTypes);
		FilterStructure.Property("PeriodStart"		, PeriodStart);
		FilterStructure.Property("PeriodEnd"		, PeriodEnd);
		FilterStructure.Property("Company"			, Company);
		FilterStructure.Property("TypeOfAccounting"	, TypeOfAccounting);
		
	EndIf;

	If Not ValueIsFilled(Company) Or Not ValueIsFilled(TypeOfAccounting) Then
		Return GetAllDocumentTypes();
	EndIf;
	
	If Not ValueIsFilled(PeriodStart) Then
		PeriodStart = Date(1, 1, 1, 0, 0, 0);
	EndIf;
	
	If Not ValueIsFilled(PeriodEnd) Then
		PeriodEnd = CurrentSessionDate();
	EndIf;
	
	If OldTypes = Undefined Then
		OldTypes = New ValueList;
	EndIf;
	
	Types = New ValueList;
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	AccountingSourceDocuments.DocumentType AS DocumentType,
	|	VALUETYPE(AccountingSourceDocuments.DocumentType.EmptyRefValue) AS TypePresentation
	|FROM
	|	InformationRegister.AccountingSourceDocuments AS AccountingSourceDocuments
	|WHERE
	|	AccountingSourceDocuments.Period BETWEEN &PeriodStart AND &PeriodEnd
	|	AND AccountingSourceDocuments.Company = &Company
	|	AND AccountingSourceDocuments.TypeOfAccounting = &TypeOfAccounting
	|	AND AccountingSourceDocuments.Uses";
	
	Query.SetParameter("PeriodStart"		, PeriodStart);
	Query.SetParameter("PeriodEnd"			, PeriodEnd);
	Query.SetParameter("Company"			, Company);
	Query.SetParameter("TypeOfAccounting"	, TypeOfAccounting);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If Selection.DocumentType.EmptyRefValue = Documents.AccountingTransaction.EmptyRef() Then
			Continue;
		EndIf;
		
		ValueType = Types.FindByValue(Selection.DocumentType);
		If ValueType = Undefined Then
			
			OldType = OldTypes.FindByValue(Selection.DocumentType);
			If OldType = Undefined Then
				Types.Add(Selection.DocumentType, Selection.TypePresentation, True);
			Else
				Types.Add(OldType.Value, OldType.Presentation, OldType.Check);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Types.SortByPresentation();
	
	Return Types;
	
EndFunction

Function GetAccountinEntriesStatus(Document) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	DocumentAccountingEntriesStatuses.Status AS Status,
	|	DocumentAccountingEntriesStatuses.AdjustedManually AS AdjustedManually
	|FROM
	|	InformationRegister.DocumentAccountingEntriesStatuses AS DocumentAccountingEntriesStatuses
	|WHERE
	|	DocumentAccountingEntriesStatuses.Recorder = &Document";
	
	Query.SetParameter("Document", Document);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		
		StatusStructure = New Structure("Status, AdjustedManually");
		FillPropertyValues(StatusStructure, Selection);
		Return StatusStructure;
		
	Else
		Return Undefined;
	EndIf;
	
EndFunction

#EndRegion

#Region Private

Procedure RegisterAccountingEntriesStatus(Parameters, ResultAddress)
	SetPrivilegedMode(True);
	If Not GetFunctionalOption("UseAccountingApproval")
		And Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	If Parameters.Property("DocumentsArray") Then
		
		If Parameters.DocumentsArray.Count() = 0 Then
			Return;
		EndIf;
		
		DocumentsArray = Parameters.DocumentsArray;
	Else
		DocumentsArray = New Array;
		DocumentsArray.Add(Parameters.Document);
	EndIf;
	
	If Not Parameters.Property("Comment") Then
		Parameters.Insert("Comment", "");
	EndIf;
	
	Status = Parameters.Status;
		
	If Status = Enums.AccountingEntriesStatus.Approved Then
		Parameters.Insert("ApprovalDate", CurrentSessionDate());
	Else
		Parameters.Insert("ApprovalDate", Date(1, 1, 1));
	EndIf;
	
	BeginTransaction();
	
	Try
		
		For Each DocumentKey In DocumentsArray Do
			
			If TypeOf(DocumentKey) = Type("DynamicListRowKey") Then
				Document = DocumentKey.AccountingEntriesRecorder;
			Else
				Document = DocumentKey;
			EndIf;
			
			If TypeOf(Document) = Type("Structure") Then
				
				If Not ValueIsFilled(Document.AccountingEntriesRecorder) Then
					Continue;
				EndIf;
				
				DocumentRef = Document.AccountingEntriesRecorder;
				
			Else
				DocumentRef = Document;
			EndIf;
			
			DocumentAccountingEntriesStatuses = InformationRegisters.DocumentAccountingEntriesStatuses.CreateRecordSet();
			DocumentAccountingEntriesStatuses.Filter.Recorder.Set(DocumentRef);
			DocumentAccountingEntriesStatuses.Read();
			
			If DocumentAccountingEntriesStatuses.Count() = 0 Then
				
				Record = DocumentAccountingEntriesStatuses.Add();
				
				FillPropertyValues(Record, Document);
				
				If Common.HasObjectAttribute("OperationType", Document.Metadata()) Then
					
					DocumentAttributes		= Common.ObjectAttributesValues(Document, "Date, OperationType");
					Record.Period			= DocumentAttributes.Date;
					Record.OperationKind	= DocumentAttributes.OperationType;
					Record.EntriesGenerated	= Enums.AccountingEntriesGenerationStatus.Generated;
					
				Else
					Record.Period = Common.ObjectAttributeValue(Document, "Date");
				EndIf;
				
				If ValueIsFilled(Record.DocumentAmount) 
					And Not ValueIsFilled(Record.DocumentCurrency) Then
					
					If Common.HasObjectAttribute("CashCurrency", Document.Metadata()) Then
						Record.DocumentCurrency = Common.ObjectAttributeValue(Document, "CashCurrency");
					ElsIf Common.HasObjectAttribute("Currency", Document.Metadata()) Then
						Record.DocumentCurrency = Common.ObjectAttributeValue(Document, "Currency");
					EndIf;
					
				ElsIf Not ValueIsFilled(Record.DocumentAmount) 
					And ValueIsFilled(Record.DocumentCurrency) Then 
					Record.DocumentCurrency = Undefined;
				EndIf;
				
				FillPropertyValues(Record, Parameters);
				
			Else
				For Each Record In DocumentAccountingEntriesStatuses Do
					
					If Parameters.Property("AdjustedManually") And Record.AdjustedManually <> Parameters.AdjustedManually Then
						Record.AdjustedManually = Parameters.AdjustedManually;
					EndIf;
					
					If TypeOf(DocumentRef) = Type("DocumentRef.AccountingTransaction")
						And Record.TypeOfAccounting <> DocumentRef.TypeOfAccounting Then
						
						Continue;
						
					EndIf;
					
					FillPropertyValues(Record, Parameters);
					
				EndDo;
			EndIf;
			
			DocumentAccountingEntriesStatuses.Write();
			
			AccountingJournalEntries = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
			AccountingJournalEntries.Filter.Recorder.Set(DocumentRef);
			AccountingJournalEntries.Read();
			
			If AccountingJournalEntries.Count() > 0
				And AccountingJournalEntries[0].Status <> Status Then
				
				For Each Record In AccountingJournalEntries Do
					If TypeOf(DocumentRef) = Type("DocumentRef.AccountingTransaction") 
						And Record.TypeOfAccounting = DocumentRef.TypeOfAccounting Then
						
						Record.Status = Status;
						
					EndIf;
				EndDo;
				
				AccountingJournalEntries.Write();
			EndIf;
			
			If TypeOf(DocumentRef) = Type("DocumentRef.Operation") Then
				DocumentAccountingEntries = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
				DocumentAccountingEntries.Filter.Recorder.Set(DocumentRef);
				DocumentAccountingEntries.Read();
				
				DocumentObject = DocumentRef.GetObject();
				DocumentObject.AccountingRecords.Load(DocumentAccountingEntries.Unload());
				DocumentObject.DataExchange.Load = True;
				DocumentObject.Write();
			EndIf;
			
		EndDo;
		
		If Parameters.Property("AdjustedManually")
			And Not Parameters.AdjustedManually
			And Status = Enums.AccountingEntriesStatus.NotApproved Then
			
			ResetEntriesForDocument(DocumentsArray);
			
		EndIf;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot set status ""%1"" for document ""%2"" due to ""%3""'; ru = 'Не удалось установить статус ""%1"" для документа ""%2"" по причине ""%3""';pl = 'Nie można ustawić statusu ""%1"" dla dokumentu ""%2"" z powodu ""%3""';es_ES = 'No se puede establecer el estado ""%1"" para el documento ""%2"" a causa de ""%3""';es_CO = 'No se puede establecer el estado ""%1"" para el documento ""%2"" a causa de ""%3""';tr = '""%3"" sebebiyle ""%2"" belgesi için ""%1"" durumu ayarlanamıyor';it = 'Impossibile impostare lo stato ""%1"" per il documento ""%2"" a causa di ""%3""';de = 'Status ""%1"" für Dokument ""%2"" kann aufgrund von ""%3 "" nicht gesetzt werden'"),
			Parameters.Status,
			Document.Ref,
			DetailErrorDescription(ErrorInfo()));
		WriteLogEvent(
			NStr("en = 'Set a new status for accounting entries'; ru = 'Установить новый статус для бухгалтерских проводок';pl = 'Ustaw nowy status dla wpisów księgowych';es_ES = 'Establecer un nuevo estado para las entradas contables';es_CO = 'Establecer un nuevo estado para las entradas contables';tr = 'Muhasebe girişleri için yeni bir durum ayarla';it = 'Impostare un nuovo stato per gli inserimenti contabili';de = 'Neuen Status für Buchhaltungseinträge festlegen'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			Document.Ref.Metadata(),
			Document.Ref,
			ErrorDescription);
		
	EndTry;
	
	PutToTempStorage(DocumentAccountingEntriesStatuses.Unload(), ResultAddress); 
	
	SetPrivilegedMode(False);
	
EndProcedure

Procedure ResetEntriesForDocument(Val DocumentsArray)
	
	If DocumentsArray.Count() > 0
		And TypeOf(DocumentsArray[0]) = Type("DynamicListRowKey") Then
		
		TempDocumentsArray = New Array;
		For Each Row In DocumentsArray Do
			TempDocumentsArray.Add(Row.Ref);
		EndDo;
		
	ElsIf DocumentsArray.Count() > 0
		And TypeOf(DocumentsArray[0]) = Type("Structure") Then
		
		TempDocumentsArray = New Array;
		For Each Row In DocumentsArray Do
			
			If ValueIsFilled(Row.AccountingEntriesRecorder) Then
				TempDocumentsArray.Add(Row.AccountingEntriesRecorder);
			EndIf;
			
		EndDo;
		
	Else
		
		TempDocumentsArray = DocumentsArray;
		
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	AccountingTransactionDocuments.AccountingEntriesRecorder AS AccountingEntriesRecorder,
	|	AccountingTransactionDocuments.TypeOfAccounting AS TypeOfAccounting,
	|	AccountingTransactionDocuments.ChartOfAccounts AS ChartOfAccounts,
	|	AccountingTransactionDocuments.Company AS Company,
	|	AccountingTransactionDocuments.SourceDocument AS Ref
	|FROM
	|	InformationRegister.AccountingTransactionDocuments AS AccountingTransactionDocuments
	|WHERE
	|	AccountingTransactionDocuments.AccountingEntriesRecorder IN(&RecordersList)";
	
	Query.SetParameter("RecordersList", TempDocumentsArray);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If ValueIsFilled(SelectionDetailRecords.AccountingEntriesRecorder) Then
		
			AccountingTemplatesPosting.CreateRefreshTransactionDocument(
				SelectionDetailRecords.Ref,
				SelectionDetailRecords.TypeOfAccounting,
				SelectionDetailRecords.AccountingEntriesRecorder,
				SelectionDetailRecords.ChartOfAccounts,
				False);
				
		EndIf;
			
	EndDo;
	
EndProcedure

#EndRegion

