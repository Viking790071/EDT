
#Region Public

Function GetAccountInformationMap(Account) Export
	
	If TypeOf(Account) = Type("Array") Then
		AccountArray = Account;
		CommonClientServer.CollapseArray(AccountArray);
	Else
		AccountArray = CommonClientServer.ValueInArray(Account);
	EndIf;
	
	AccountsMap = New Map;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	MasterChartOfAccounts.StartDate AS StartDate,
	|	MasterChartOfAccounts.EndDate AS EndDate,
	|	MasterChartOfAccounts.Currency AS UseCurrency,
	|	MasterChartOfAccounts.Quantity AS UseQuantity,
	|	MasterChartOfAccounts.Ref AS Ref
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
	|WHERE
	|	MasterChartOfAccounts.Ref IN(&Accounts)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MasterChartOfAccountsAnalyticalDimensions.AnalyticalDimension AS AnalyticalDimension,
	|	MasterChartOfAccountsAnalyticalDimensions.AnalyticalDimension.Presentation AS Presentation,
	|	MasterChartOfAccountsAnalyticalDimensions.AnalyticalDimension.ValueType AS ValueType,
	|	MasterChartOfAccountsAnalyticalDimensions.Ref AS Ref
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts.AnalyticalDimensions AS MasterChartOfAccountsAnalyticalDimensions
	|WHERE
	|	MasterChartOfAccountsAnalyticalDimensions.Ref IN(&Accounts)";
	
	Query.SetParameter("Accounts", AccountArray);
	ResultArray = Query.ExecuteBatch();
	
	HeaderSelection = ResultArray[0].Select();
	While HeaderSelection.Next() Do
		
		AccountSctructure = New Structure;
		AccountSctructure.Insert("AnalyticalDimensions", New Array);
		AccountSctructure.Insert("StartDate");
		AccountSctructure.Insert("EndDate");
		AccountSctructure.Insert("UseQuantity");
		AccountSctructure.Insert("UseCurrency");

		FillPropertyValues(AccountSctructure, HeaderSelection);
		AccountsMap.Insert(HeaderSelection.Ref, AccountSctructure);
		
	EndDo;
	
	ExtDimensionsSelection = ResultArray[1].Select();
	While ExtDimensionsSelection.Next() Do
		
		SelectionRow = New Structure("AnalyticalDimension, Presentation, ValueType");
		FillPropertyValues(SelectionRow, ExtDimensionsSelection);
		AccountsMap[ExtDimensionsSelection.Ref].AnalyticalDimensions.Add(SelectionRow);
		
	EndDo;

	Return AccountsMap;
	
EndFunction

Procedure FillMiscFields(RecordSetMasterTable, Suffixes = Undefined) Export
	
	If RecordSetMasterTable.Count() = 0 Then
		Return;
	EndIf;
	
	If Suffixes = Undefined Then
		
		Suffixes = New Array;
		
		If CommonClientServer.HasAttributeOrObjectProperty(RecordSetMasterTable[0], "Account") Then
			Suffixes.Add("");
		Else
			Suffixes.Add("Cr");
			Suffixes.Add("Dr");
		EndIf;
		
	EndIf;
	
	AccountInfoMap = New Map;
	For Each Suffix In Suffixes Do
		
		If Suffixes.Find("") <> Undefined Then
			CommonClientServer.SupplementMap(AccountInfoMap, 
				GetAccountInformationMap(PopulateAccounts(RecordSetMasterTable, "Account")), True);
		EndIf;
		
		If Suffixes.Find("Dr") <> Undefined Then
			CommonClientServer.SupplementMap(AccountInfoMap, 
				GetAccountInformationMap(PopulateAccounts(RecordSetMasterTable, "AccountDr")), True);
		EndIf;
		
		If Suffixes.Find("Cr") <> Undefined Then
			CommonClientServer.SupplementMap(AccountInfoMap, 
				GetAccountInformationMap(PopulateAccounts(RecordSetMasterTable, "AccountCr")), True);
		EndIf;
		
	EndDo;
	
	TemplatesInfoTable = GetTemplatesInfo(RecordSetMasterTable);
	
	MaxExtDimensions = WorkWithArbitraryParametersServerCall.MaxAnalyticalDimensionsNumber();
	
	IsRecordSetPicture = (TypeOf(RecordSetMasterTable) = Type("ValueTable"));
	
	For Each Row In RecordSetMasterTable Do
		
		For Each Suffix In Suffixes Do
			
			If Suffix = "Dr" Then
				AccountFieldName = "AccountDr";
			ElsIf Suffix = "Cr" Then
				AccountFieldName = "AccountCr";
			Else
				AccountFieldName = "Account";
			EndIf;
			
			Account = Row[AccountFieldName];
			IsAccountEmpty = Not ValueIsFilled(Account);
			
			// 1.1 Reset Ext Dimensions fields
			For Index = 1 To MaxExtDimensions Do
				
				EnabledField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, Suffix, "Enabled");
				PresentationField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, Suffix, "Presentation");
				Row[EnabledField] = False;
				Row[PresentationField] = "";
				
				If IsAccountEmpty Then
					
					TypeField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, Suffix, "Type");
					ExtField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, Suffix);
					Row[TypeField] = Undefined;
					Row[ExtField] = Undefined;
					
				EndIf;
				
			EndDo;
			
			// 1.2 Reset misc fields
			If IsAccountEmpty Then
			
				Row["UseQuantity" + Suffix] = False;
				Row["UseCurrency" + Suffix] = False;
				Row["Quantity" + Suffix] = Undefined;
				Row["Currency" + Suffix] = Undefined;
				Row["AmountCur" + Suffix] = Undefined;
				
				Continue;
				
			EndIf;
			
			AccountInfo = AccountInfoMap[Row[AccountFieldName]];
			
			// 2.1 Set Ext Dimensions fields
			MaxIndex = Min(AccountInfo.AnalyticalDimensions.Count(), MaxExtDimensions);
			For Index = 1 To MaxExtDimensions Do
				
				ExtField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, Suffix);
				TypeField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, Suffix, "Type");
				EnabledField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, Suffix, "Enabled");
				PresentationField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, Suffix, "Presentation");
				
				If Index <= MaxIndex Then
					
					ExtDimensionRow = AccountInfo.AnalyticalDimensions[Index - 1];
					
					Row[TypeField] = ExtDimensionRow.AnalyticalDimension;
					Row[ExtField] = ExtDimensionRow.ValueType.AdjustValue(Row[ExtField]);
					Row[EnabledField] = True;
					Row[PresentationField] = MasterAccountingClientServer.GetExtDimensionPresentation(ExtDimensionRow.Presentation);
					
				Else
					
					Row[TypeField] = Undefined;
					Row[ExtField] = Undefined;
					Row[EnabledField] = False;
					Row[PresentationField] = "";
					
				EndIf;
			
			EndDo;
			
			// 2.2 Set misc fields
			Row["UseQuantity" + Suffix] = AccountInfo.UseQuantity;
			Row["UseCurrency" + Suffix] = AccountInfo.UseCurrency;
			
			If Not AccountInfo.UseQuantity Then
				
				If IsBlankString(Suffix) Then
					
					Row["QuantityDr"] = Undefined;
					Row["QuantityCr"] = Undefined;
					Row["Quantity"] = Undefined;
					
				Else
					
					Row["Quantity" + Suffix] = Undefined;
					
				EndIf;
				
			EndIf;
			
			If Not AccountInfo.UseCurrency Then
				
				If IsBlankString(Suffix) Then
					
					Row["CurrencyDr"] = Undefined;
					Row["CurrencyCr"] = Undefined;
					Row["Currency"] = Undefined;
					Row["AmountCurDr"] = Undefined;
					Row["AmountCurCr"] = Undefined;
					Row["AmountCur"] = Undefined;
					
				Else
					
					Row["Currency" + Suffix] = Undefined;
					Row["AmountCur" + Suffix] = 0;
					
				EndIf;
				
			EndIf;
			
			If IsBlankString(Suffix) Then
				
				If Row.RecordType = AccountingRecordType.Credit Then
					
					Row.CurrencyCr = Row.Currency;
					Row.AmountCurCr = Row.AmountCur;
					Row.QuantityCr = Row.Quantity;
					Row.AmountCr = Row.Amount;
					If IsRecordSetPicture Then
						Row.RecordSetPicture = ?(Row.Active, 2, 4);
					EndIf;
					
				Else
					
					Row.CurrencyDr = Row.Currency;
					Row.AmountCurDr = Row.AmountCur;
					Row.QuantityDr = Row.Quantity;
					Row.AmountDr = Row.Amount;
					
					If IsRecordSetPicture Then
						Row.RecordSetPicture = ?(Row.Active, 1, 3);
					EndIf;
					
				EndIf;
				
			ElsIf IsRecordSetPicture Then
				
				Row.RecordSetPicture = ?(Row.Active, 1, 3);
				
			EndIf;
			
		EndDo;
				
		If CommonClientServer.HasAttributeOrObjectProperty(Row, "EntryNumber")
			And CommonClientServer.HasAttributeOrObjectProperty(Row, "EntryLineNumber")
			And CommonClientServer.HasAttributeOrObjectProperty(Row, "NumberPresentation") Then
			
			Row.NumberPresentation = StrTemplate("%1/%2", 
				Row.EntryNumber, Row.EntryLineNumber);
			
		EndIf;
		
	EndDo;
		
EndProcedure

Function GetAccountChoiceList(Company, ChartOfAccounts, Date) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	MasterChartOfAccountsCompanies.Ref AS Account,
	|	CASE
	|		WHEN MasterChartOfAccountsCompanies.StartDate <> DATETIME(1, 1, 1)
	|				AND MasterChartOfAccountsCompanies.EndDate <> DATETIME(1, 1, 1)
	|			THEN &Date BETWEEN MasterChartOfAccountsCompanies.StartDate AND MasterChartOfAccountsCompanies.EndDate
	|		WHEN MasterChartOfAccountsCompanies.StartDate <> DATETIME(1, 1, 1)
	|			THEN &Date >= MasterChartOfAccountsCompanies.StartDate
	|		WHEN MasterChartOfAccountsCompanies.EndDate <> DATETIME(1, 1, 1)
	|			THEN &Date <= MasterChartOfAccountsCompanies.EndDate
	|		ELSE TRUE
	|	END OR NOT &IsDateFilled AS DateWithinBounds
	|INTO MasterChartOfAccountsCompanies
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts.Companies AS MasterChartOfAccountsCompanies
	|WHERE
	|	MasterChartOfAccountsCompanies.Ref.ChartOfAccounts = &ChartOfAccounts
	|	AND MasterChartOfAccountsCompanies.Company = &Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	MasterChartOfAccounts.Ref AS Account,
	|	CASE
	|		WHEN MasterChartOfAccounts.StartDate <> DATETIME(1, 1, 1)
	|				AND MasterChartOfAccounts.EndDate <> DATETIME(1, 1, 1)
	|			THEN &Date BETWEEN MasterChartOfAccounts.StartDate AND MasterChartOfAccounts.EndDate
	|		WHEN MasterChartOfAccounts.StartDate <> DATETIME(1, 1, 1)
	|			THEN &Date >= MasterChartOfAccounts.StartDate
	|		WHEN MasterChartOfAccounts.EndDate <> DATETIME(1, 1, 1)
	|			THEN &Date <= MasterChartOfAccounts.EndDate
	|		ELSE TRUE
	|	END OR NOT &IsDateFilled AS DateWithinBounds
	|INTO MasterChartOfAccounts
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
	|WHERE
	|	MasterChartOfAccounts.ChartOfAccounts = &ChartOfAccounts
	|	AND NOT MasterChartOfAccounts.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MasterChartOfAccounts.Account AS Account,
	|	MAX(MasterChartOfAccounts.DateWithinBounds) AS DateWithinBounds,
	|	MAX(ISNULL(MasterChartOfAccountsCompanies.DateWithinBounds, TRUE)) AS CompanyDateWithinBounds
	|INTO AccountsGrouped
	|FROM
	|	MasterChartOfAccounts AS MasterChartOfAccounts
	|		LEFT JOIN MasterChartOfAccountsCompanies AS MasterChartOfAccountsCompanies
	|		ON MasterChartOfAccounts.Account = MasterChartOfAccountsCompanies.Account
	|
	|GROUP BY
	|	MasterChartOfAccounts.Account
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsGrouped.Account AS Account
	|FROM
	|	AccountsGrouped AS AccountsGrouped
	|WHERE
	|	AccountsGrouped.DateWithinBounds
	|			AND AccountsGrouped.CompanyDateWithinBounds";
	
	Query.SetParameter("ChartOfAccounts", ChartOfAccounts);
	Query.SetParameter("Company", Company);
	Query.SetParameter("Date", Date);
	Query.SetParameter("IsDateFilled", ValueIsFilled(Date));
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return New Array;
	Else
		Return QueryResult.Unload().UnloadColumn("Account");
	EndIf;
	
EndFunction

Procedure ConvertEntryTablesIntoRecordSet(Form, MasterTablesMap, AccountingRecordSetSimple, AccountingRecordSetCompound) Export
	
	If MasterTablesMap.Count() > 0 Then
		
		AccountingRecordSetSimple.Clear();
		AccountingRecordSetCompound.Clear();
		
		For Each Row In MasterTablesMap Do
			
			If Row.Compound Then
				
				AccountingRegisters.AccountingJournalEntriesCompound.DecomposeCompoundPresentation(
					Form[Row.TableName].Unload(), AccountingRecordSetCompound, False);
				
			Else
				
				AccountingRegisters.AccountingJournalEntriesSimple.DecomposeSimplePresentation(
					Form[Row.TableName].Unload(), AccountingRecordSetSimple, False);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Function RestoreOriginalEntries(Document, BasisDocument, TypeOfAccounting = Undefined, ChartOfAccounts = Undefined) Export
	
	CommonClientServer.Validate(
		ValueIsFilled(Document) And ValueIsFilled(BasisDocument),
		,
		"MasterAccounting.RestoreOriginalEntries");
	
	Result = True;
	
	SetPrivilegedMode(True);
	BeginTransaction();
	
	Try
		Cancel = False;
		AccountingTemplatesPosting.CreateRefreshTransactionDocument(
			BasisDocument,
			TypeOfAccounting,
			Document,
			ChartOfAccounts,
			,
			Cancel);
			
		Result = Not Cancel;
			
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			MessagesToUserClientServer.GetRestoreOriginalEntriesErrorText(DefaultLanguageCode),
			Document,
			DetailErrorDescription(ErrorInfo()));
		
		CommonClientServer.MessageToUser(ErrorInfo().Description);
		
		EventName = StrTemplate(
			"%1%2",
			AccountingTemplatesPosting.GetEventGroupVariant(),
			MessagesToUserClientServer.GetRestoreOriginalEntriesEventName(DefaultLanguageCode));
			
		WriteLogEvent(EventName, EventLogLevel.Error, Document.Metadata(), , ErrorDescription);
		
		Result = False;
		
	EndTry;
	
	SetPrivilegedMode(False);
	
	Return Result;
	
EndFunction

Procedure RefreshTotalData(Form) Export
	
	Items = Form.Items;
	Pages = Items.Pages;
	CurrentPage = Pages.CurrentPage;
	MasterTablesMap = Form.MasterTablesMap;
	
	If CurrentPage = Undefined
		And MasterTablesMap.Count() > 0 Then
		
		CurrentPage = Items[MasterTablesMap[0].PageName];
		
	EndIf;
	
	If CurrentPage = Undefined Then
		Return;
	EndIf;
	
	MasterTablesMapRows = MasterTablesMap.FindRows(New Structure("PageName", CurrentPage.Name));
	
	If MasterTablesMapRows.Count() = 0 Then
		Return;
	EndIf;
	
	CurrentTableName = MasterTablesMapRows[0].TableName;

	TotalDebits		= 0;
	TotalCredits	= 0;
	For Each Row In Form[CurrentTableName] Do
		
		If CommonClientServer.HasAttributeOrObjectProperty(Row, "Account") Then
			
			If Row.RecordType = AccountingRecordType.Debit Then
				TotalDebits = TotalDebits + Row.AmountDr;
			Else
				TotalCredits = TotalCredits + Row.AmountCr;
			EndIf;
			
		Else
			
			TotalDebits = TotalDebits + Row.Amount;
			TotalCredits = TotalCredits + Row.Amount;
			
		EndIf;
		
	EndDo;
	
	TotalDifference = TotalDebits - TotalCredits;
	
	Form.TotalDebits = TotalDebits;
	Form.TotalCredits = TotalCredits;
	Form.TotalDifference = TotalDifference;

EndProcedure

Function GetEntriesNumber(Table) Export

	If TypeOf(Table) = Type("ValueTable") Then
		EntriesNumberVT = Table.Copy(, "EntryNumber");
	ElsIf TypeOf(Table) = Type("FormDataCollection")
		Or TypeOf(Table) = Type("FormDataStructureAndCollection") Then
		EntriesNumberVT = Table.Unload( , "EntryNumber");
	Else
		Raise NStr("en = 'Undefined type'; ru = 'Неопределенный тип';pl = 'Nieokreślony typ';es_ES = 'Tipo indefinido';es_CO = 'Tipo indefinido';tr = 'Tanımısız tür';it = 'Tipo indefinito';de = 'Nicht definierter Typ'");
	EndIf;
	
	EntriesNumberVT.GroupBy("EntryNumber");
	
	Return EntriesNumberVT.UnloadColumn("EntryNumber");

EndFunction

#EndRegion

#Region Private

Function GetTemplatesInfo(Collection)
	
	TemplatesTable = New ValueTable;
	
	TemplatesTable.Columns.Add("TransactionTemplate", 
		New TypeDescription("CatalogRef.AccountingTransactionsTemplates"));
		
	TemplatesTable.Columns.Add("TransactionTemplateLineNumber", 
		New TypeDescription("Number", , , New NumberQualifiers(8)));
		
	For Each Row In Collection Do
		FillPropertyValues(TemplatesTable.Add(), Row);
	EndDo;
	
	TemplatesTable.GroupBy("TransactionTemplate, TransactionTemplateLineNumber");
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TemplatesTable.TransactionTemplate AS TransactionTemplate,
	|	TemplatesTable.TransactionTemplateLineNumber AS TransactionTemplateLineNumber
	|INTO TemplatesTable
	|FROM
	|	&TemplatesTable AS TemplatesTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TemplatesTable.TransactionTemplate AS TransactionTemplate,
	|	TemplatesTable.TransactionTemplateLineNumber AS TransactionTemplateLineNumber,
	|	AccountingTransactionsTemplates.EntryNumber AS EntryNumber,
	|	AccountingTransactionsTemplates.EntryLineNumber AS EntryLineNumber
	|FROM
	|	TemplatesTable AS TemplatesTable
	|		INNER JOIN Catalog.AccountingTransactionsTemplates.Entries AS AccountingTransactionsTemplates
	|		ON TemplatesTable.TransactionTemplate = AccountingTransactionsTemplates.Ref
	|			AND TemplatesTable.TransactionTemplateLineNumber = AccountingTransactionsTemplates.LineNumber";
	
	Query.SetParameter("TemplatesTable", TemplatesTable);
	
	Result = Query.Execute().Unload();
	Result.Indexes.Add("TransactionTemplate, TransactionTemplateLineNumber");
	
	Return Result;
	
EndFunction

Function PopulateAccounts(Collection, FieldName)
	
	If TypeOf(Collection) = Type("ValueTable") Then
		Return Collection.UnloadColumn(FieldName);
	EndIf;
	
	AccountsArray = New Array;
	For Each Row In Collection Do
		AccountsArray.Add(Row[FieldName]);
	EndDo;
	
	Return AccountsArray;
	
EndFunction

#EndRegion