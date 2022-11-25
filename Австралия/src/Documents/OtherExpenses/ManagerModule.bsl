#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefOtherExpenses, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	OtherExpensesCosts.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	OtherExpensesCosts.Ref.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	OtherExpensesCosts.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN OtherExpensesCosts.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	&OwnInventory AS Ownership,
	|	VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads) AS InventoryAccountType,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	VALUE(Enum.InventoryAccountTypes.EmptyRef) AS CorrInventoryAccountType,
	|	CASE
	|		WHEN OtherExpensesCosts.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR OtherExpensesCosts.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE OtherExpensesCosts.SalesOrder
	|	END AS SalesOrder,
	|	OtherExpensesCosts.Amount AS Amount,
	|	TRUE AS FixedCost,
	|	&OtherExpenses AS ContentOfAccountingRecord
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesCosts
	|WHERE
	|	OtherExpensesCosts.Ref = &Ref
	|	AND OtherExpensesCosts.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OtherExpensesCosts.LineNumber AS LineNumber,
	|	OtherExpenses.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	CASE
	|		WHEN OtherExpensesCosts.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|			THEN VALUE(Catalog.LinesOfBusiness.Other)
	|		ELSE OtherExpensesCosts.BusinessLine
	|	END AS BusinessLine,
	|	CASE
	|		WHEN OtherExpensesCosts.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|			THEN VALUE(Catalog.BusinessUnits.EmptyRef)
	|		ELSE OtherExpenses.StructuralUnit
	|	END AS StructuralUnit,
	|	OtherExpensesCosts.ExpenseItem AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN OtherExpensesCosts.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN OtherExpensesCosts.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|				OR OtherExpensesCosts.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR OtherExpensesCosts.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE OtherExpensesCosts.SalesOrder
	|	END AS SalesOrder,
	|	0 AS AmountIncome,
	|	OtherExpensesCosts.Amount AS AmountExpense,
	|	OtherExpensesCosts.Amount AS Amount,
	|	&OtherExpenses AS ContentOfAccountingRecord
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesCosts
	|		INNER JOIN Document.OtherExpenses AS OtherExpenses
	|		ON OtherExpensesCosts.Ref = OtherExpenses.Ref
	|WHERE
	|	OtherExpensesCosts.Ref = &Ref
	|	AND OtherExpensesCosts.RegisterExpense
	|	AND (OtherExpensesCosts.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|			OR OtherExpensesCosts.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OtherExpenses.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	OtherExpenses.StructuralUnit AS StructuralUnit,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	UNDEFINED AS SalesOrder,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN OtherExpenses.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN OtherExpenses.RegisterIncome
	|			THEN OtherExpenses.IncomeItem
	|		ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|	END AS IncomeAndExpenseItem,
	|	SUM(OtherExpensesCosts.Amount) AS AmountIncome,
	|	0 AS AmountExpense,
	|	&RevenueIncomes AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesCosts
	|		INNER JOIN Document.OtherExpenses AS OtherExpenses
	|		ON OtherExpensesCosts.Ref = OtherExpenses.Ref
	|WHERE
	|	OtherExpensesCosts.Ref = &Ref
	|	AND OtherExpenses.RegisterIncome
	|	AND OtherExpensesCosts.Amount > 0
	|
	|GROUP BY
	|	OtherExpensesCosts.Ref,
	|	OtherExpenses.Date,
	|	OtherExpenses.StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN OtherExpenses.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN OtherExpenses.RegisterIncome
	|			THEN OtherExpenses.IncomeItem
	|		ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OtherExpensesCosts.LineNumber AS LineNumber,
	|	OtherExpenses.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN OtherExpensesCosts.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountDr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN UNDEFINED
	|		WHEN OtherExpensesCosts.GLExpenseAccount.Currency
	|			THEN ExchangeRatesSettlementsDr.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN 0
	|		WHEN OtherExpensesCosts.GLExpenseAccount.Currency
	|			THEN CAST(OtherExpensesCosts.Amount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN ExchangeRatesAccounting.Rate * ExchangeRatesSettlementsDr.Repetition / (ExchangeRatesSettlementsDr.Rate * ExchangeRatesAccounting.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (ExchangeRatesAccounting.Rate * ExchangeRatesSettlementsDr.Repetition / (ExchangeRatesSettlementsDr.Rate * ExchangeRatesAccounting.Repetition))
	|					END AS NUMBER(15, 2))
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN OtherExpenses.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountCr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN UNDEFINED
	|		WHEN OtherExpenses.Correspondence.Currency
	|			THEN ExchangeRatesSettlementsCr.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|				AND OtherExpensesCosts.Ref.Correspondence.Currency
	|			THEN CAST(OtherExpensesCosts.Amount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN ExchangeRatesAccounting.Rate * ExchangeRatesSettlementsCr.Repetition / (ExchangeRatesSettlementsCr.Rate * ExchangeRatesAccounting.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (ExchangeRatesAccounting.Rate * ExchangeRatesSettlementsCr.Repetition / (ExchangeRatesSettlementsCr.Rate * ExchangeRatesAccounting.Repetition))
	|					END AS NUMBER(15, 2))
	|		ELSE 0
	|	END AS AmountCurCr,
	|	OtherExpensesCosts.Amount AS Amount,
	|	&OtherIncome AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesCosts
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS ExchangeRatesAccounting
	|		ON (ExchangeRatesAccounting.Currency = &PresentationCurrency)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS ExchangeRatesSettlementsDr
	|		ON OtherExpensesCosts.Contract.SettlementsCurrency = ExchangeRatesSettlementsDr.Currency
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS ExchangeRatesSettlementsCr
	|		ON OtherExpensesCosts.Ref.Contract.SettlementsCurrency = ExchangeRatesSettlementsCr.Currency
	|		INNER JOIN Document.OtherExpenses AS OtherExpenses
	|		ON OtherExpensesCosts.Ref = OtherExpenses.Ref
	|WHERE
	|	OtherExpensesCosts.Ref = &Ref
	|	AND OtherExpensesCosts.Amount > 0
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PlanningPeriod,
	|	OfflineRecords.AccountDr,
	|	OfflineRecords.CurrencyDr,
	|	OfflineRecords.AmountCurDr,
	|	OfflineRecords.AccountCr,
	|	OfflineRecords.CurrencyCr,
	|	OfflineRecords.AmountCurCr,
	|	OfflineRecords.Amount,
	|	OfflineRecords.Content,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS LineNumber,
	|	OtherExpenses.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN OtherExpenses.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	UNDEFINED AS SalesOrder,
	|	0 AS AmountIncome,
	|	SUM(OtherExpensesExpenses.Amount) AS AmountExpense,
	|	SUM(OtherExpensesExpenses.Amount) AS Amount,
	|	&OtherExpenses AS PostingContent
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesExpenses
	|		INNER JOIN Document.OtherExpenses AS OtherExpenses
	|		ON OtherExpensesExpenses.Ref = OtherExpenses.Ref
	|		INNER JOIN Catalog.IncomeAndExpenseItems AS IncomeAndExpenseItems
	|		ON OtherExpensesExpenses.ExpenseItem = IncomeAndExpenseItems.Ref
	|WHERE
	|	OtherExpensesExpenses.Ref = &Ref
	|	AND OtherExpenses.OtherSettlementsAccounting
	|	AND OtherExpensesExpenses.RegisterExpense
	|	AND IncomeAndExpenseItems.IncomeAndExpenseType <> VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|	AND IncomeAndExpenseItems.IncomeAndExpenseType <> VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|
	|GROUP BY
	|	OtherExpenses.Date,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN OtherExpenses.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	OtherExpensesExpenses.LineNumber,
	|	OtherExpenses.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	VALUE(Catalog.BusinessUnits.EmptyRef),
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN OtherExpenses.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	UNDEFINED,
	|	OtherExpensesExpenses.Amount,
	|	0,
	|	OtherExpensesExpenses.Amount,
	|	&RevenueIncomes
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesExpenses
	|		INNER JOIN Document.OtherExpenses AS OtherExpenses
	|		ON OtherExpensesExpenses.Ref = OtherExpenses.Ref
	|WHERE
	|	OtherExpensesExpenses.Ref = &Ref
	|	AND OtherExpenses.OtherSettlementsAccounting
	|	AND OtherExpenses.RegisterIncome
	|	AND OtherExpensesExpenses.Amount < 0");
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");

	Query.SetParameter("Ref",					DocumentRefOtherExpenses);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("OtherExpenses",			NStr("en = 'Expenses incurred'; ru = 'Отражение затрат';pl = 'Poniesione rozchody';es_ES = 'Gastos incurridos';es_CO = 'Gastos incurridos';tr = 'Tahakkuk eden giderler';it = 'Spese sostenute';de = 'Anfallende Ausgaben'", MainLanguageCode));
	Query.SetParameter("RevenueIncomes",		NStr("en = 'Other income'; ru = 'Прочие доходы';pl = 'Inne przychody';es_ES = 'Otros ingresos';es_CO = 'Otros ingresos';tr = 'Diğer gelir';it = 'Altre entrate';de = 'Sonstige Einnahmen'", MainLanguageCode));
	Query.SetParameter("OtherIncome",			NStr("en = 'Other expenses'; ru = 'Прочих затраты (расходы)';pl = 'Pozostałe koszty (wydatki)';es_ES = 'Otros gastos';es_CO = 'Otros gastos';tr = 'Diğer masraflar';it = 'Altre spese';de = 'Sonstige Ausgaben'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency",	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("OwnInventory",			Catalogs.InventoryOwnership.OwnInventory());
	Query.SetParameter("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[1].Unload());
	
	If StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Count() = 0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[2].Unload());
	Else
		
		Selection = ResultsArray[2].Select();
		While Selection.Next() Do
			
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
			FillPropertyValues(NewRow, Selection);
			
		EndDo;
		
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[3].Unload());
	EndIf;
	
	If StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Count() = 0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[4].Unload());
	Else
		
		Selection = ResultsArray[4].Select();
		While Selection.Next() Do
			
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
			FillPropertyValues(NewRow, Selection);
			
		EndDo;
		
	EndIf;
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefOtherExpenses, StructureAdditionalProperties);
	
	GenerateTableMiscellaneousPayable(DocumentRefOtherExpenses, StructureAdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRefOtherExpenses, StructureAdditionalProperties);
	
	FinancialAccounting.FillExtraDimensions(DocumentRefOtherExpenses, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefOtherExpenses, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefOtherExpenses, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

#EndRegion 

#Region Internal

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Expenses" Then
		IncomeAndExpenseStructure.Insert("ExpenseItem", StructureData.ExpenseItem);
		IncomeAndExpenseStructure.Insert("RegisterExpense", StructureData.RegisterExpense);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "Expenses" Then
		Result.Insert("GLExpenseAccount", "ExpenseItem");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	GLAccountsForFilling = New Structure;
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#Region AccountingTemplates

Function EntryTypes() Export 
	
	EntryTypes = New Array;
	
	Return EntryTypes;
	
EndFunction

Function AccountingFields() Export 
	
	AccountingFields = New Map;
	
	Return AccountingFields;
	
EndFunction

#EndRegion 

#EndRegion 

#Region Private

#Region TableGeneration

Procedure GenerateTableMiscellaneousPayable(DocumentRefOtherExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AccountingForOtherOperations",	NStr("en = 'Accounting for other operations'; ru = 'Учет расчетов по прочим операциям';pl = 'Księgowanie innych operacji';es_ES = 'Contabilidad para otras operaciones';es_CO = 'Contabilidad para otras operaciones';tr = 'Diğer işlemler için muhasebe';it = 'Contabilizzazione per altre operazioni';de = 'Abrechnung für Abwicklungen bei anderen Transaktionen'",	MainLanguageCode));
	Query.SetParameter("CommentReceipt",				NStr("en = 'Increase in counterparty debt'; ru = 'Увеличение долга контрагента';pl = 'Zwiększenie długu kontrahenta';es_ES = 'Aumento en la deuda de la contraparte';es_CO = 'Aumento en la deuda de la contraparte';tr = 'Cari hesap borcunda artış';it = 'Aumento del debito della controparte';de = 'Erhöhung der Geschäftspartnerschulden'", MainLanguageCode));
	Query.SetParameter("CommentExpense",				NStr("en = 'Decrease in counterparty debt'; ru = 'Уменьшение долга контрагента';pl = 'Zmniejszenie długu kontrahenta';es_ES = 'Disminución en la deuda de la contraparte';es_CO = 'Disminución en la deuda de la contraparte';tr = 'Cari hesap borcunun azalması';it = 'Diminuzione del debito della controparte';de = 'Abnahme der Geschäftspartnerschulden'", MainLanguageCode));
	Query.SetParameter("Ref",							DocumentRefOtherExpenses);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeRateDifference",		NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency",			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting",	StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.Text =
	"SELECT
	|	OtherExpensesExpenses.LineNumber AS LineNumber,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	OtherExpensesExpenses.Counterparty AS Counterparty,
	|	OtherExpensesExpenses.Contract AS Contract,
	|	OtherExpensesExpenses.Contract.SettlementsCurrency AS Currency,
	|	CASE
	|		WHEN OtherExpensesExpenses.Counterparty.DoOperationsByOrders
	|			THEN OtherExpensesExpenses.SalesOrder
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	OtherExpensesExpenses.Ref.Date AS Period,
	|	SUM(OtherExpensesExpenses.Amount) AS Amount,
	|	&AccountingForOtherOperations AS PostingContent,
	|	&CommentReceipt AS Comment,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN OtherExpensesExpenses.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	SUM(CAST(OtherExpensesExpenses.Amount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRatesSettlements.Repetition * ExchangeRatesAccounting.Rate / (ExchangeRatesSettlements.Rate * ExchangeRatesAccounting.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (ExchangeRatesSettlements.Repetition * ExchangeRatesAccounting.Rate / (ExchangeRatesSettlements.Rate * ExchangeRatesAccounting.Repetition))
	|			END AS NUMBER(15, 2))) AS AmountCur
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesExpenses
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS ExchangeRatesSettlements
	|		ON OtherExpensesExpenses.Contract.SettlementsCurrency = ExchangeRatesSettlements.Currency
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS ExchangeRatesAccounting
	|		ON (ExchangeRatesAccounting.Currency = &PresentationCurrency)
	|WHERE
	|	OtherExpensesExpenses.Ref = &Ref
	|	AND OtherExpensesExpenses.Ref.OtherSettlementsAccounting
	|	AND OtherExpensesExpenses.Counterparty <> VALUE(Catalog.Counterparties.EmptyRef)
	|
	|GROUP BY
	|	OtherExpensesExpenses.LineNumber,
	|	OtherExpensesExpenses.Counterparty,
	|	OtherExpensesExpenses.Contract,
	|	OtherExpensesExpenses.Contract.SettlementsCurrency,
	|	OtherExpensesExpenses.Ref.Date,
	|	CASE
	|		WHEN OtherExpensesExpenses.Counterparty.DoOperationsByOrders
	|			THEN OtherExpensesExpenses.SalesOrder
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN OtherExpensesExpenses.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	OtherExpensesExpenses.LineNumber,
	|	&Company,
	|	&PresentationCurrency,
	|	VALUE(AccumulationRecordType.Expense),
	|	OtherExpenses.Counterparty,
	|	OtherExpenses.Contract,
	|	OtherExpenses.Contract.SettlementsCurrency,
	|	UNDEFINED,
	|	OtherExpenses.Date,
	|	SUM(OtherExpensesExpenses.Amount),
	|	&AccountingForOtherOperations,
	|	&CommentExpense,
	|	OtherExpenses.Correspondence,
	|	SUM(CAST(OtherExpensesExpenses.Amount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRatesSettlements.Repetition * ExchangeRatesAccounting.Rate / (ExchangeRatesSettlements.Rate * ExchangeRatesAccounting.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (ExchangeRatesSettlements.Repetition * ExchangeRatesAccounting.Rate / (ExchangeRatesSettlements.Rate * ExchangeRatesAccounting.Repetition))
	|			END AS NUMBER(15, 2)))
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesExpenses
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS ExchangeRatesAccounting
	|		ON (ExchangeRatesAccounting.Currency = &PresentationCurrency)
	|		INNER JOIN Document.OtherExpenses AS OtherExpenses
	|			LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS ExchangeRatesSettlements
	|			ON OtherExpenses.Contract.SettlementsCurrency = ExchangeRatesSettlements.Currency
	|		ON OtherExpensesExpenses.Ref = OtherExpenses.Ref
	|WHERE
	|	OtherExpensesExpenses.Ref = &Ref
	|	AND OtherExpensesExpenses.Ref.OtherSettlementsAccounting
	|	AND OtherExpenses.Counterparty <> VALUE(Catalog.Counterparties.EmptyRef)
	|
	|GROUP BY
	|	OtherExpensesExpenses.LineNumber,
	|	OtherExpenses.Counterparty,
	|	OtherExpenses.Contract,
	|	OtherExpenses.Contract.SettlementsCurrency,
	|	OtherExpenses.Date,
	|	OtherExpenses.Correspondence";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableMiscellaneousPayable", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);
	
EndProcedure

#EndRegion 

#EndRegion

#EndIf