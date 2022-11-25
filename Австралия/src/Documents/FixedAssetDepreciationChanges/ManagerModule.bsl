#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

#Region TableGeneration

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableFixedAssets(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("FixedAssetAcceptanceForAccounting", NStr("en = 'Change parameters'; ru = 'Параметры изменения';pl = 'Parametry zmian';es_ES = 'Cambiar parámetros';es_CO = 'Cambiar parámetros';tr = 'Parametreleri değiştir';it = 'Modificare i parametri';de = 'Parameter ändern'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordType,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging
	|		ELSE DocumentTable.CostForDepreciationCalculationBeforeChanging - DocumentTable.CostForDepreciationCalculation
	|	END AS Cost,
	|	0 AS Depreciation,
	|	&FixedAssetAcceptanceForAccounting AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableFixedAssetDepreciationChanges AS DocumentTable
	|WHERE
	|	DocumentTable.CostForDepreciationCalculationBeforeChanging <> 0
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssets", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("IncomeReflection", NStr("en = 'Income'; ru = 'Отражение доходов';pl = 'Dochody';es_ES = 'Ingreso';es_CO = 'Ingreso';tr = 'Gelir';it = 'Entrate';de = 'Einnahme'", MainLanguageCode));
	Query.SetParameter("CostsReflection", NStr("en = 'Expenses incurred'; ru = 'Отражение расходов';pl = 'Poniesione rozchody';es_ES = 'Gastos incurridos';es_CO = 'Gastos incurridos';tr = 'Tahakkuk eden giderler';it = 'Spese sostenute';de = 'Anfallende Ausgaben'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS StructuralUnit,
	|	UNDEFINED AS SalesOrder,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	DocumentTable.RevaluationItem AS IncomeAndExpenseItem,
	|	DocumentTable.RevaluationAccount AS GLAccount,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN &IncomeReflection
	|		ELSE &CostsReflection
	|	END AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN 0
	|		ELSE DocumentTable.CostForDepreciationCalculationBeforeChanging - DocumentTable.CostForDepreciationCalculation
	|	END AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableFixedAssetDepreciationChanges AS DocumentTable
	|WHERE
	|	DocumentTable.CostForDepreciationCalculationBeforeChanging <> 0
	|	AND DocumentTable.RegisterRevaluation
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("IncomeReflection", NStr("en = 'Income'; ru = 'Отражение доходов';pl = 'Dochody';es_ES = 'Ingreso';es_CO = 'Ingreso';tr = 'Gelir';it = 'Entrate';de = 'Einnahme'", MainLanguageCode));
	Query.SetParameter("CostsReflection", NStr("en = 'Expenses incurred'; ru = 'Отражение расходов';pl = 'Poniesione rozchody';es_ES = 'Gastos incurridos';es_CO = 'Gastos incurridos';tr = 'Tahakkuk eden giderler';it = 'Spese sostenute';de = 'Anfallende Ausgaben'", MainLanguageCode));
	Query.SetParameter("Ref", DocumentRefFixedAssetDepreciationChanges);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE DocumentTable.RevaluationAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN DocumentTable.RevaluationAccount
	|		ELSE DocumentTable.GLAccount
	|	END AS AccountCr,
	|	UNDEFINED AS CurrencyDr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurDr,
	|	0 AS AmountCurCr,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging
	|		ELSE DocumentTable.CostForDepreciationCalculationBeforeChanging - DocumentTable.CostForDepreciationCalculation
	|	END AS Amount,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN &IncomeReflection
	|		ELSE &CostsReflection
	|	END AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableFixedAssetDepreciationChanges AS DocumentTable
	|WHERE
	|	DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging <> 0
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
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableFixedAssetParameters(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefFixedAssetDepreciationChanges);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.AmountOfProductsServicesForDepreciationCalculation AS AmountOfProductsServicesForDepreciationCalculation,
	|	DocumentTable.CostForDepreciationCalculation AS CostForDepreciationCalculation,
	|	DocumentTable.ApplyInCurrentMonth AS ApplyInCurrentMonth,
	|	DocumentTable.UsagePeriodForDepreciationCalculation AS UsagePeriodForDepreciationCalculation,
	|	DocumentTable.GLExpenseAccount AS GLExpenseAccount,
	|	CASE
	|		WHEN DocumentTable.RegisterExpense
	|			THEN DocumentTable.ExpenseItem
	|		ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|	END AS ExpenseItem,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.BusinessLine AS BusinessLine
	|FROM
	|	TemporaryTableFixedAssetDepreciationChanges AS DocumentTable
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssetParameters", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

#EndRegion

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefFixedAssetDepreciationChanges);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.FixedAsset.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.AmountOfProductsServicesForDepreciationCalculation AS AmountOfProductsServicesForDepreciationCalculation,
	|	DocumentTable.CostForDepreciationCalculation AS CostForDepreciationCalculation,
	|	DocumentTable.CostForDepreciationCalculationBeforeChanging AS CostForDepreciationCalculationBeforeChanging,
	|	DocumentTable.ExpenseItem AS ExpenseItem,
	|	DocumentTable.RegisterExpense AS RegisterExpense,
	|	DocumentTable.RevaluationItem AS RevaluationItem,
	|	DocumentTable.RegisterRevaluation AS RegisterRevaluation,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.RevaluationAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS RevaluationAccount,
	|	DocumentTable.ApplyInCurrentMonth AS ApplyInCurrentMonth,
	|	DocumentTable.UsagePeriodForDepreciationCalculation AS UsagePeriodForDepreciationCalculation,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLExpenseAccount,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.BusinessLine AS BusinessLine
	|INTO TemporaryTableFixedAssetDepreciationChanges
	|FROM
	|	Document.FixedAssetDepreciationChanges.FixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	GenerateTableFixedAssetParameters(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties);
	GenerateTableFixedAssets(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties);
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties);
	
	// Accounting
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties);
	ElsIf StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties);
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties);
	
EndProcedure

#EndRegion

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "FixedAssets" Then
		IncomeAndExpenseStructure.Insert("ExpenseItem", StructureData.ExpenseItem);
		IncomeAndExpenseStructure.Insert("RevaluationItem", StructureData.RevaluationItem);
		IncomeAndExpenseStructure.Insert("RegisterExpense", StructureData.RegisterExpense);
		IncomeAndExpenseStructure.Insert("RegisterRevaluation", StructureData.RegisterRevaluation);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "FixedAssets" Then
		Result.Insert("RevaluationAccount", "RevaluationItem");
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

#EndIf