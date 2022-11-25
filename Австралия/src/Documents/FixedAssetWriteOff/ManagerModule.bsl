#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefFixedAssetWriteOff, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref",							DocumentRefFixedAssetWriteOff);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseDefaultTypeOfAccounting",	StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	FixedAssetParametersSliceLast.StructuralUnit AS StructuralUnit,
	|	FixedAssetParametersSliceLast.ExpenseItem AS DepreciationItem,
	|	FixedAssetParametersSliceLast.ExpenseItem.IncomeAndExpenseType AS DepreciationItemType,
	|	DocumentTable.Ref.ExpenseItem AS ExpenseItem,
	|	DocumentTable.Ref.ExpenseItem.IncomeAndExpenseType AS ExpenseItemType,
	|	DocumentTable.Ref.RegisterExpense AS RegisterExpense,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN FixedAssetParametersSliceLast.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountAccountingDepreciation,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN FixedAssetParametersSliceLast.GLExpenseAccount.TypeOfAccount
	|		ELSE VALUE(Enum.GLAccountsTypes.EmptyRef)
	|	END AS DepreciationAccountType,
	|	FixedAssetParametersSliceLast.BusinessLine AS BusinessLine,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.FixedAsset.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN DocumentTable.Ref.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|			THEN VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS InventoryAccountType,
	|	DocumentTable.FixedAsset.DepreciationAccount AS DepreciationAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountWriteOff,
	|	DocumentTable.Ref.StructuralUnit AS StructuralUnitWriteOff,
	|	DocumentTable.Cost AS Cost,
	|	DocumentTable.Depreciation AS Depreciation,
	|	DocumentTable.MonthlyDepreciation AS MonthlyDepreciation,
	|	DocumentTable.DepreciatedCost AS DepreciatedCost,
	|	TRUE AS FixedCost
	|INTO TemporaryTableFixedAssets
	|FROM
	|	Document.FixedAssetWriteOff.FixedAssets AS DocumentTable
	|		LEFT JOIN InformationRegister.FixedAssetParameters.SliceLast(&PointInTime, ) AS FixedAssetParametersSliceLast
	|		ON (FixedAssetParametersSliceLast.Company = &Company)
	|			AND (FixedAssetParametersSliceLast.PresentationCurrency = &PresentationCurrency)
	|			AND DocumentTable.FixedAsset = FixedAssetParametersSliceLast.FixedAsset
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	Query.Execute();
	
	GenerateTableInventory(DocumentRefFixedAssetWriteOff, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefFixedAssetWriteOff, StructureAdditionalProperties);
	GenerateTableFixedAssets(DocumentRefFixedAssetWriteOff, StructureAdditionalProperties);
	GenerateTableFixedAssetStatuses(DocumentRefFixedAssetWriteOff, StructureAdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRefFixedAssetWriteOff, StructureAdditionalProperties);
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefFixedAssetWriteOff, StructureAdditionalProperties);
	
	// Accounting
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefFixedAssetWriteOff, StructureAdditionalProperties);
	ElsIf StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefFixedAssetWriteOff, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefFixedAssetWriteOff, StructureAdditionalProperties);
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRefFixedAssetWriteOff, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefFixedAssetWriteOff, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If there are records in temprorary tables,
	// it is necessary to control the occurrence of negative balances.	
	If StructureTemporaryTables.RegisterRecordsFixedAssetsChange  Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsFixedAssetsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsFixedAssetsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsFixedAssetsChange.PresentationCurrency) AS PresentationCurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsFixedAssetsChange.FixedAsset) AS FixedAssetPresentation,
		|	ISNULL(FixedAssetsBalance.CostBalance, 0) AS CostBalance,
		|	ISNULL(FixedAssetsBalance.DepreciationBalance, 0) AS DepreciationBalance,
		|	RegisterRecordsFixedAssetsChange.CostBeforeWrite AS CostBeforeWrite,
		|	RegisterRecordsFixedAssetsChange.CostOnWrite AS CostOnWrite,
		|	RegisterRecordsFixedAssetsChange.CostChanging AS CostChanging,
		|	RegisterRecordsFixedAssetsChange.CostChanging + ISNULL(FixedAssetsBalance.CostBalance, 0) AS DepreciatedCost,
		|	RegisterRecordsFixedAssetsChange.DepreciationBeforeWrite AS DepreciationBeforeWrite,
		|	RegisterRecordsFixedAssetsChange.DepreciationOnWrite AS DepreciationOnWrite,
		|	RegisterRecordsFixedAssetsChange.DepreciationUpdate AS DepreciationUpdate,
		|	RegisterRecordsFixedAssetsChange.DepreciationUpdate + ISNULL(FixedAssetsBalance.DepreciationBalance, 0) AS AccuredDepreciation
		|FROM
		|	RegisterRecordsFixedAssetsChange AS RegisterRecordsFixedAssetsChange
		|		LEFT JOIN AccumulationRegister.FixedAssets.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, FixedAsset) In
		|					(SELECT
		|						RegisterRecordsFixedAssetsChange.Company AS Company,
		|						RegisterRecordsFixedAssetsChange.PresentationCurrency AS PresentationCurrency,
		|						RegisterRecordsFixedAssetsChange.FixedAsset AS FixedAsset
		|					FROM
		|						RegisterRecordsFixedAssetsChange AS RegisterRecordsFixedAssetsChange)) AS FixedAssetsBalance
		|		ON (RegisterRecordsFixedAssetsChange.Company = RegisterRecordsFixedAssetsChange.Company)
		|			AND (RegisterRecordsFixedAssetsChange.PresentationCurrency = RegisterRecordsFixedAssetsChange.PresentationCurrency)
		|			AND (RegisterRecordsFixedAssetsChange.FixedAsset = RegisterRecordsFixedAssetsChange.FixedAsset)
		|WHERE
		|	(ISNULL(FixedAssetsBalance.CostBalance, 0) < 0
		|			OR ISNULL(FixedAssetsBalance.DepreciationBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty() Then
			DocumentObjectFixedAssetWriteOff = DocumentRefFixedAssetWriteOff.GetObject()
		EndIf;
		
		// Negative balance of property depriciation.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToFixedAssetsRegisterErrors(DocumentObjectFixedAssetWriteOff, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure;
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "Header" Then
		Result.Insert("Correspondence", "ExpenseItem");
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
Procedure GenerateTableInventory(DocumentRefFixedAssetWriteOff, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("AccrueDepreciation", NStr("en = 'Accrue depreciation'; ru = 'Начисление амортизации';pl = 'Naliczyć amortyzację';es_ES = 'Amortización de la acumulación';es_CO = 'Amortización de la acumulación';tr = 'Amortismanı tahakkuk et';it = 'Accantonamenti ammortamenti';de = 'Abschreibungsberechnung'", MainLanguageCode));
	Query.SetParameter("OtherExpenses", NStr("en = 'Other expenses'; ru = 'Прочих затраты (расходы)';pl = 'Pozostałe koszty (wydatki)';es_ES = 'Otros gastos';es_CO = 'Otros gastos';tr = 'Diğer masraflar';it = 'Altre spese';de = 'Sonstige Ausgaben'", MainLanguageCode));
	Query.SetParameter("OwnInventory", Catalogs.InventoryOwnership.OwnInventory());
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.AccountAccountingDepreciation AS GLAccount,
	|	DocumentTable.InventoryAccountType AS InventoryAccountType,
	|	DocumentTable.MonthlyDepreciation AS Amount,
	|	&OwnInventory AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	TRUE AS FixedCost,
	|	VALUE(AccountingRecordType.Debit) AS RecordKindAccountingJournalEntries,
	|	&AccrueDepreciation AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation > 0
	|	AND DocumentTable.DepreciationItemType = VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.StructuralUnitWriteOff,
	|	DocumentTable.GLAccountWriteOff,
	|	DocumentTable.InventoryAccountType,
	|	DocumentTable.Cost - DocumentTable.Depreciation - DocumentTable.MonthlyDepreciation,
	|	&OwnInventory,
	|	VALUE(Catalog.CostObjects.EmptyRef),
	|	TRUE,
	|	VALUE(AccountingRecordType.Debit),
	|	&OtherExpenses
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Cost - DocumentTable.Depreciation - DocumentTable.MonthlyDepreciation > 0
	|	AND DocumentTable.ExpenseItemType = VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefFixedAssetWriteOff, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("AccrueDepreciation", NStr("en = 'Accrue depreciation'; ru = 'Начисление амортизации';pl = 'Naliczyć amortyzację';es_ES = 'Amortización de la acumulación';es_CO = 'Amortización de la acumulación';tr = 'Amortismanı tahakkuk et';it = 'Accantonamenti ammortamenti';de = 'Abschreibungsberechnung'", MainLanguageCode));
	Query.SetParameter("OtherExpenses", NStr("en = 'Other expenses'; ru = 'Прочих затраты (расходы)';pl = 'Pozostałe koszty (wydatki)';es_ES = 'Otros gastos';es_CO = 'Otros gastos';tr = 'Diğer masraflar';it = 'Altre spese';de = 'Sonstige Ausgaben'", MainLanguageCode));
	Query.SetParameter("Ref", DocumentRefFixedAssetWriteOff);
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.BusinessLine AS BusinessLine,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	UNDEFINED AS SalesOrder,
	|	DocumentTable.DepreciationItem AS IncomeAndExpenseItem,
	|	DocumentTable.AccountAccountingDepreciation AS GLAccount,
	|	DocumentTable.MonthlyDepreciation AS AmountExpense,
	|	0 AS AmountIncome,
	|	&AccrueDepreciation AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation > 0
	|	AND (DocumentTable.DepreciationItemType = VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|			OR DocumentTable.DepreciationItemType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	DocumentTable.StructuralUnitWriteOff,
	|	UNDEFINED,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.GLAccountWriteOff,
	|	DocumentTable.Cost - DocumentTable.Depreciation - DocumentTable.MonthlyDepreciation,
	|	0,
	|	&OtherExpenses,
	|	FALSE
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Cost - DocumentTable.Depreciation - DocumentTable.MonthlyDepreciation > 0
	|	AND DocumentTable.ExpenseItemType IN (VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses), VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses))
	|	AND DocumentTable.RegisterExpense
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefFixedAssetWriteOff, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("AccrueDepreciation",	NStr("en = 'Depreciation accrued'; ru = 'Начисление амортизации';pl = 'Amortyzacja naliczona';es_ES = 'Depreciación acumulada';es_CO = 'Depreciación acumulada';tr = 'Amortisman tahakkuku';it = 'Ammortamento accumulato';de = 'Abschreibung abgegrenzt'", MainLanguageCode));
	Query.SetParameter("DepreciationDebiting",	NStr("en = 'Depreciation deducted'; ru = 'Списание амортизации';pl = 'Amortyzacja potrącono';es_ES = 'Depreciación deducida';es_CO = 'Depreciación deducida';tr = 'İndirilen amortisman';it = 'Ammortamento dedotto';de = 'Abschreibung abgezogen'", MainLanguageCode));
	Query.SetParameter("OtherExpenses",			NStr("en = 'Expenses incurred'; ru = 'Прочих затраты (расходы)';pl = 'Poniesione rozchody';es_ES = 'Gastos incurridos';es_CO = 'Gastos incurridos';tr = 'Tahakkuk eden giderler';it = 'Spese sostenute';de = 'Anfallende Ausgaben'", MainLanguageCode));
	Query.SetParameter("Ref",					DocumentRefFixedAssetWriteOff);
	
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.AccountAccountingDepreciation AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	DocumentTable.DepreciationAccount AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	DocumentTable.MonthlyDepreciation AS Amount,
	|	CAST(&AccrueDepreciation AS STRING(100)) AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.DepreciationAccount,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.GLAccount,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.MonthlyDepreciation + DocumentTable.Depreciation,
	|	&DepreciationDebiting,
	|	FALSE
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation + DocumentTable.Depreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccountWriteOff,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.GLAccount,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.Cost - DocumentTable.Depreciation - DocumentTable.MonthlyDepreciation,
	|	&OtherExpenses,
	|	FALSE
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Cost - DocumentTable.Depreciation - DocumentTable.MonthlyDepreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	4,
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
	|	AND OfflineRecords.OfflineRecord";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableFixedAssets(DocumentRefFixedAssetWriteOff, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("AccrueDepreciation",					NStr("en = 'Accrue depreciation'; ru = 'Начисление амортизации';pl = 'Naliczyć amortyzację';es_ES = 'Amortización de la acumulación';es_CO = 'Amortización de la acumulación';tr = 'Amortismanı tahakkuk et';it = 'Accantonamenti ammortamenti';de = 'Abschreibungsberechnung'", MainLanguageCode));
	Query.SetParameter("DepreciationDebiting",					NStr("en = 'Depreciation write-off'; ru = 'Списание амортизации';pl = 'Spisanie amortyzacji';es_ES = 'Amortización de la depreciación';es_CO = 'Amortización de la depreciación';tr = 'Amortisman silinmesi';it = 'Cancellazione ammortamento (write-off)';de = 'Abschreibung der Abschreibung'", MainLanguageCode));
	Query.SetParameter("WriteOffOfFixedAssetFromAccounting",	NStr("en = 'Fixed asset write-off'; ru = 'Списание основных средств';pl = 'Naprawiono odpisanie aktywów';es_ES = 'Amortización del activo fijo';es_CO = 'Amortización del activo fijo';tr = 'Sabit kıymet silme';it = 'Cancellazione (consumo) cespite';de = 'Abschreibung des Anlagevermögens'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.MonthlyDepreciation AS Depreciation,
	|	0 AS Cost,
	|	DocumentTable.MonthlyDepreciation AS Amount,
	|	DocumentTable.DepreciationAccount AS GLAccount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindAccountingJournalEntries,
	|	&AccrueDepreciation AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.FixedAsset,
	|	DocumentTable.MonthlyDepreciation + DocumentTable.Depreciation,
	|	0,
	|	DocumentTable.MonthlyDepreciation + DocumentTable.Depreciation,
	|	DocumentTable.DepreciationAccount,
	|	VALUE(AccountingRecordType.Debit),
	|	&DepreciationDebiting
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation + DocumentTable.Depreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.FixedAsset,
	|	0,
	|	DocumentTable.Cost,
	|	DocumentTable.Cost,
	|	DocumentTable.GLAccount,
	|	VALUE(AccountingRecordType.Credit),
	|	&WriteOffOfFixedAssetFromAccounting
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Cost > 0
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssets", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableFixedAssetStatuses(DocumentRefFixedAssetWriteOff, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.Company AS Company,
	|	VALUE(Enum.FixedAssetStatus.RemoveFromAccounting) AS Status,
	|	FALSE AS AccrueDepreciation,
	|	FALSE AS AccrueDepreciationInCurrentMonth
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssetStatus", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRefFixedAssetWriteOff, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

#EndRegion

#EndIf