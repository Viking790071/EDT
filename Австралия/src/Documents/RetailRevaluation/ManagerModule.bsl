#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefRetailRevaluation, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefRetailRevaluation);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",  StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.Text =
	"SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	RetailRevaluation.Date AS Date,
	|	UNDEFINED AS SalesOrder,
	|	RetailRevaluation.DocumentCurrency AS DocumentCurrency,
	|	RetailRevaluation.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN RetailRevaluation.StructuralUnit.GLAccountInRetail
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS StructuralUnitGLAccountInRetail,
	|	RetailRevaluation.RegisterExpense AS RegisterExpense,
	|	RetailRevaluation.RegisterIncome AS RegisterIncome,
	|	RetailRevaluation.ExpenseItem AS ExpenseItem,
	|	RetailRevaluation.IncomeItem AS IncomeItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN RetailRevaluation.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS StructuralUnitGLAccountMarkup,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	SUM(CAST(DocumentTable.Amount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfDocument.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * ExchangeRateOfDocument.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (ExchangeRateOfDocument.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * ExchangeRateOfDocument.Repetition))
	|			END AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.Amount) AS AmountCur
	|INTO TemporaryTableInventory
	|FROM
	|	Document.RetailRevaluation.Inventory AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS ExchangeRateOfDocument
	|		ON DocumentTable.Ref.DocumentCurrency = ExchangeRateOfDocument.Currency
	|		INNER JOIN Document.RetailRevaluation AS RetailRevaluation
	|		ON DocumentTable.Ref = RetailRevaluation.Ref
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	RetailRevaluation.Date,
	|	RetailRevaluation.DocumentCurrency,
	|	RetailRevaluation.StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN RetailRevaluation.StructuralUnit.GLAccountInRetail
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	RetailRevaluation.RegisterExpense,
	|	RetailRevaluation.RegisterIncome,
	|	RetailRevaluation.ExpenseItem,
	|	RetailRevaluation.IncomeItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN RetailRevaluation.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END";
	
	Query.ExecuteBatch();
	
	// Register record table creation by account sections.
	GenerateTablePOSSummary(DocumentRefRetailRevaluation, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefRetailRevaluation, StructureAdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRefRetailRevaluation, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefRetailRevaluation, StructureAdditionalProperties);
	EndIf;
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefRetailRevaluation, StructureAdditionalProperties);
	
	FinancialAccounting.FillExtraDimensions(DocumentRefRetailRevaluation, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefRetailRevaluation, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefRetailRevaluation, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefRetailRevaluation, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not Constants.CheckStockBalanceOnPosting.Get() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.
	If StructureTemporaryTables.RegisterRecordsPOSSummaryChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsPOSSummaryChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsPOSSummaryChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsPOSSummaryChange.PresentationCurrency) AS PresentationCurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsPOSSummaryChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsPOSSummaryChange.StructuralUnit.RetailPriceKind.PriceCurrency) AS CurrencyPresentation,
		|	ISNULL(POSSummaryBalances.AmountBalance, 0) AS AmountBalance,
		|	RegisterRecordsPOSSummaryChange.SumCurChange + ISNULL(POSSummaryBalances.AmountCurBalance, 0) AS BalanceInRetail,
		|	RegisterRecordsPOSSummaryChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsPOSSummaryChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsPOSSummaryChange.AmountChange AS AmountChange,
		|	RegisterRecordsPOSSummaryChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsPOSSummaryChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsPOSSummaryChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsPOSSummaryChange.CostBeforeWrite AS CostBeforeWrite,
		|	RegisterRecordsPOSSummaryChange.CostOnWrite AS CostOnWrite,
		|	RegisterRecordsPOSSummaryChange.CostUpdate AS CostUpdate
		|FROM
		|	RegisterRecordsPOSSummaryChange AS RegisterRecordsPOSSummaryChange
		|		LEFT JOIN AccumulationRegister.POSSummary.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, StructuralUnit) In
		|					(SELECT
		|						RegisterRecordsPOSSummaryChange.Company AS Company,
		|						RegisterRecordsPOSSummaryChange.PresentationCurrency AS PresentationCurrency,
		|						RegisterRecordsPOSSummaryChange.StructuralUnit AS StructuralUnit
		|					FROM
		|						RegisterRecordsPOSSummaryChange AS RegisterRecordsPOSSummaryChange)) AS POSSummaryBalances
		|		ON RegisterRecordsPOSSummaryChange.Company = POSSummaryBalances.Company
		|			AND RegisterRecordsPOSSummaryChange.PresentationCurrency = POSSummaryBalances.PresentationCurrency
		|			AND RegisterRecordsPOSSummaryChange.StructuralUnit = POSSummaryBalances.StructuralUnit
		|WHERE
		|	ISNULL(POSSummaryBalances.AmountCurBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty() Then
			DocumentObjectRetailRevaluation = DocumentRefRetailRevaluation.GetObject()
		EndIf;
		
		// Negative balance according to the amount-based account in retail.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToPOSSummaryRegisterErrors(DocumentObjectRetailRevaluation, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion 

#Region Internal

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Header" Then
		IncomeAndExpenseStructure.Insert("IncomeItem", StructureData.IncomeItem);
		IncomeAndExpenseStructure.Insert("ExpenseItem", StructureData.ExpenseItem);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export
	
	Result = New Structure;
	
	TypeOfAccount = Common.ObjectAttributeValue(StructureData.Correspondence, "TypeOfAccount");
	If StructureData.TabName = "Header" Then
		If TypeOfAccount = Enums.GLAccountsTypes.OtherExpenses Then
			Result.Insert("Correspondence", "ExpenseItem");
			
			Array = New Array;
			Array.Add("RegisterIncome");
			Array.Add("IncomeItem");
			Result.Insert("Clear", Array);
		ElsIf TypeOfAccount = Enums.GLAccountsTypes.OtherIncome Then
			Result.Insert("Correspondence", "IncomeItem");
			
			Array = New Array;
			Array.Add("RegisterExpense");
			Array.Add("ExpenseItem");
			Result.Insert("Clear", Array);
		Else
			Array = New Array;
			Array.Add("RegisterExpense");
			Array.Add("ExpenseItem");
			Array.Add("RegisterIncome");
			Array.Add("IncomeItem");
			Result.Insert("Clear", Array);
		EndIf;
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

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePOSSummary(DocumentRefRetailRevaluation, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefRetailRevaluation);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("RetailRevaluation", NStr("en = 'Revaluation in retail'; ru = 'Переоценка в рознице';pl = 'Wycena w detalu';es_ES = 'Revaluación en la venta al por menor';es_CO = 'Revaluación en la venta al por menor';tr = 'Perakendede yeniden değerleme';it = 'Rivalutazione nella vendita al dettaglio';de = 'Neubewertung im Einzelhandel'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency", 	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod", 	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);	
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Date,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.DocumentCurrency AS Currency,
	|	DocumentTable.StructuralUnitGLAccountInRetail AS GLAccount,
	|	DocumentTable.StructuralUnitGLAccountInRetail AS StructuralUnitGLAccountInRetail,
	|	DocumentTable.StructuralUnitGLAccountMarkup AS StructuralUnitGLAccountMarkup,
	|	DocumentTable.SalesOrder AS SalesOrder,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	0 AS Cost,
	|	&RetailRevaluation AS ContentOfAccountingRecord
	|INTO TemporaryTablePOSSummary
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.DocumentCurrency,
	|	DocumentTable.StructuralUnitGLAccountInRetail,
	|	DocumentTable.StructuralUnitGLAccountInRetail,
	|	DocumentTable.StructuralUnitGLAccountMarkup,
	|	DocumentTable.SalesOrder
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	StructuralUnit,
	|	Currency,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text =
	"SELECT
	|	TemporaryTablePOSSummary.Company AS Company,
	|	TemporaryTablePOSSummary.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTablePOSSummary.StructuralUnit AS StructuralUnit,
	|	TemporaryTablePOSSummary.Currency AS Currency
	|FROM
	|	TemporaryTablePOSSummary AS TemporaryTablePOSSummary";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.POSSummary");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesPOSSummary(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePOSSummary", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefRetailRevaluation, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("IncomeReflection", NStr("en = 'Record income'; ru = 'Отражение доходов';pl = 'Rejestr przychodów';es_ES = 'Registrar los ingresos';es_CO = 'Registrar los ingresos';tr = 'Gelirlerin kaydı';it = 'Registrazione fatturato';de = 'Gebuchte Einnahme'", MainLanguageCode));
	Query.SetParameter("CostsReflection", NStr("en = 'Record expenses'; ru = 'Отражение расходов';pl = 'Rejestr rozchodów';es_ES = 'Registrar los gastos';es_CO = 'Registrar los gastos';tr = 'Masrafların yansıtılması';it = 'Registrazione spese';de = 'Angezeigte Ausgaben'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("FXIncomeItem", Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem", Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	Query.SetParameter("ForeignCurrencyExchangeGain", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS StructuralUnit,
	|	UNDEFINED AS SalesOrder,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &FXIncomeItem
	|		ELSE &FXExpenseItem
	|	END AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS GLAccount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableCurrencyExchangeRateDifferencesPOSSummary AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.StructuralUnit,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.StructuralUnitGLAccountMarkup,
	|	&CostsReflection,
	|	0,
	|	-DocumentTable.Amount,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	DocumentTable.RegisterExpense
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.StructuralUnit,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	DocumentTable.IncomeItem,
	|	DocumentTable.StructuralUnitGLAccountMarkup,
	|	&IncomeReflection,
	|	DocumentTable.Amount,
	|	0,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	DocumentTable.RegisterIncome";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefRetailRevaluation, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("TradeMarkup", NStr("en = 'Retail markup'; ru = 'Торговая наценка';pl = 'Marża detaliczna';es_ES = 'Marca de la venta al por menor';es_CO = 'Marca de la venta al por menor';tr = 'Perakende kâr marjı';it = 'Margine di vendita al dettaglio';de = 'Einzelhandels-Aufschlag'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("IncomeReflection", NStr("en = 'Record income'; ru = 'Отражение доходов';pl = 'Rejestr przychodów';es_ES = 'Registrar los ingresos';es_CO = 'Registrar los ingresos';tr = 'Gelirlerin kaydı';it = 'Registrazione fatturato';de = 'Gebuchte Einnahme'", MainLanguageCode));
	Query.SetParameter("CostsReflection", NStr("en = 'Record expenses'; ru = 'Отражение расходов';pl = 'Rejestr rozchodów';es_ES = 'Registrar los gastos';es_CO = 'Registrar los gastos';tr = 'Masrafların yansıtılması';it = 'Registrazione spese';de = 'Angezeigte Ausgaben'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("Ref", DocumentRefRetailRevaluation);
		
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.StructuralUnitGLAccountInRetail AS AccountDr,
	|	DocumentTable.StructuralUnitGLAccountMarkup AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE UNDEFINED
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE UNDEFINED
	|	END AS AmountCurCr,
	|	DocumentTable.Amount AS Amount,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.TypeOfAccount = VALUE(Enum.GLAccountsTypes.RetailMarkup)
	|			THEN &TradeMarkup
	|		ELSE &IncomeReflection
	|	END AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTablePOSSummary AS DocumentTable
	|WHERE
	|	DocumentTable.StructuralUnitGLAccountMarkup.TypeOfAccount <> VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.StructuralUnitGLAccountMarkup,
	|	DocumentTable.StructuralUnitGLAccountInRetail,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE UNDEFINED
	|	END,
	|	-DocumentTable.Amount,
	|	&CostsReflection,
	|	FALSE
	|FROM
	|	TemporaryTablePOSSummary AS DocumentTable
	|WHERE
	|	DocumentTable.StructuralUnitGLAccountMarkup.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableCurrencyExchangeRateDifferencesPOSSummary AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PlanningPeriod,
	|	OfflineRecords.AccountDr,
	|	OfflineRecords.AccountCr,
	|	OfflineRecords.CurrencyDr,
	|	OfflineRecords.CurrencyCr,
	|	OfflineRecords.AmountCurDr,
	|	OfflineRecords.AmountCurCr,
	|	OfflineRecords.Amount,
	|	OfflineRecords.Content,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion 

#EndRegion 

#EndIf