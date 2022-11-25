#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefPayroll, StructureAdditionalProperties) Export
	
	Query = New Query(
	"SELECT
	|	ExchangeRatesSliceLast.Currency AS Currency,
	|	ExchangeRatesSliceLast.Rate AS ExchangeRate,
	|	ExchangeRatesSliceLast.Repetition AS Multiplicity
	|INTO TemporaryTableExchangeRatesSliceLatest
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(
	|			&PointInTime,
	|			Currency IN (&PresentationCurrency, &DocumentCurrency)
	|				AND Company = &Company) AS ExchangeRatesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	PayrollEarningRetention.LineNumber AS LineNumber,
	|	PayrollEarningRetention.Ref.Date AS Period,
	|	PayrollEarningRetention.Ref.RegistrationPeriod AS RegistrationPeriod,
	|	PayrollEarningRetention.Ref.DocumentCurrency AS Currency,
	|	PayrollEarningRetention.Ref.StructuralUnit AS StructuralUnit,
	|	PayrollEarningRetention.Employee AS Employee,
	|	PayrollEarningRetention.ExpenseItem AS ExpenseItem,
	|	PayrollEarningRetention.IncomeItem AS IncomeItem,
	|	ExpenseItems.IncomeAndExpenseType AS ExpenseItemType,
	|	IncomeItems.IncomeAndExpenseType AS IncomeItemType,
	|	PayrollEarningRetention.RegisterExpense AS RegisterExpense,
	|	PayrollEarningRetention.RegisterIncome AS RegisterIncome,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN PayrollEarningRetention.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLExpenseAccount,
	|	PayrollEarningRetention.SalesOrder AS SalesOrder,
	|	PayrollEarningRetention.BusinessLine AS BusinessLine,
	|	PayrollEarningRetention.StartDate AS StartDate,
	|	PayrollEarningRetention.EndDate AS EndDate,
	|	PayrollEarningRetention.DaysWorked AS DaysWorked,
	|	PayrollEarningRetention.HoursWorked AS HoursWorked,
	|	PayrollEarningRetention.Size AS Size,
	|	PayrollEarningRetention.EarningAndDeductionType AS EarningAndDeductionType,
	|	CAST(PayrollEarningRetention.Amount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	PayrollEarningRetention.Amount AS AmountCur
	|INTO TableEarning
	|FROM
	|	Document.Payroll.EarningsDeductions AS PayrollEarningRetention
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &DocumentCurrency)
	|		LEFT JOIN Catalog.IncomeAndExpenseItems AS ExpenseItems
	|		ON PayrollEarningRetention.ExpenseItem = ExpenseItems.Ref
	|		LEFT JOIN Catalog.IncomeAndExpenseItems AS IncomeItems
	|		ON PayrollEarningRetention.IncomeItem = IncomeItems.Ref
	|WHERE
	|	PayrollEarningRetention.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	&PresentationCurrency,
	|	PayrollEarningRetention.LineNumber,
	|	PayrollEarningRetention.Ref.Date,
	|	PayrollEarningRetention.Ref.RegistrationPeriod,
	|	PayrollEarningRetention.Ref.DocumentCurrency,
	|	PayrollEarningRetention.Ref.StructuralUnit,
	|	PayrollEarningRetention.Employee,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	FALSE,
	|	FALSE,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ISNULL(TaxTypes.GLAccount, VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	VALUE(Document.SalesOrder.EmptyRef),
	|	VALUE(Catalog.LinesOfBusiness.EmptyRef),
	|	PayrollEarningRetention.Ref.RegistrationPeriod,
	|	ENDOFPERIOD(PayrollEarningRetention.Ref.RegistrationPeriod, MONTH),
	|	0,
	|	0,
	|	0,
	|	PayrollEarningRetention.EarningAndDeductionType,
	|	CAST(PayrollEarningRetention.Amount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)),
	|	PayrollEarningRetention.Amount
	|FROM
	|	Document.Payroll.IncomeTaxes AS PayrollEarningRetention
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &DocumentCurrency)
	|		LEFT JOIN Catalog.EarningAndDeductionTypes AS EarningAndDeductionTypes
	|		ON PayrollEarningRetention.EarningAndDeductionType = EarningAndDeductionTypes.Ref
	|		LEFT JOIN Catalog.TaxTypes AS TaxTypes
	|		ON (EarningAndDeductionTypes.TaxKind = TaxTypes.Ref)
	|WHERE
	|	PayrollEarningRetention.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PayrollEarningRetention.Company AS Company,
	|	PayrollEarningRetention.PresentationCurrency AS PresentationCurrency,
	|	PayrollEarningRetention.Period AS Period,
	|	PayrollEarningRetention.RegistrationPeriod AS RegistrationPeriod,
	|	PayrollEarningRetention.Currency AS Currency,
	|	PayrollEarningRetention.StructuralUnit AS StructuralUnit,
	|	PayrollEarningRetention.Employee AS Employee,
	|	PayrollEarningRetention.StartDate AS StartDate,
	|	PayrollEarningRetention.EndDate AS EndDate,
	|	PayrollEarningRetention.DaysWorked AS DaysWorked,
	|	PayrollEarningRetention.HoursWorked AS HoursWorked,
	|	PayrollEarningRetention.Size AS Size,
	|	PayrollEarningRetention.EarningAndDeductionType AS EarningAndDeductionType,
	|	PayrollEarningRetention.Amount AS Amount,
	|	PayrollEarningRetention.AmountCur AS AmountCur
	|FROM
	|	TableEarning AS PayrollEarningRetention
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PayrollEarningRetention.Company AS Company,
	|	PayrollEarningRetention.PresentationCurrency AS PresentationCurrency,
	|	PayrollEarningRetention.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	PayrollEarningRetention.RegistrationPeriod AS RegistrationPeriod,
	|	PayrollEarningRetention.Currency AS Currency,
	|	PayrollEarningRetention.StructuralUnit AS StructuralUnit,
	|	PayrollEarningRetention.Employee AS Employee,
	|	CASE
	|		WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|			THEN PayrollEarningRetention.AmountCur
	|		ELSE -1 * PayrollEarningRetention.AmountCur
	|	END AS AmountCur,
	|	CASE
	|		WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|			THEN PayrollEarningRetention.Amount
	|		ELSE -1 * PayrollEarningRetention.Amount
	|	END AS Amount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN PayrollEarningRetention.Employee.SettlementsHumanResourcesGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Tax)
	|			THEN CAST(&AddedTax AS STRING(100))
	|		ELSE CAST(&Payroll AS STRING(100))
	|	END AS ContentOfAccountingRecord
	|FROM
	|	TableEarning AS PayrollEarningRetention
	|WHERE
	|	PayrollEarningRetention.AmountCur <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PayrollEarningRetention.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	PayrollEarningRetention.Period AS Period,
	|	PayrollEarningRetention.Company AS Company,
	|	PayrollEarningRetention.PresentationCurrency AS PresentationCurrency,
	|	PayrollEarningRetention.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN PayrollEarningRetention.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLExpenseAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN PayrollEarningRetention.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	&OwnInventory AS Ownership,
	|	VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads) AS InventoryAccountType,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	VALUE(Enum.InventoryAccountTypes.EmptyRef) AS CorrInventoryAccountType,
	|	CASE
	|		WHEN PayrollEarningRetention.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND PayrollEarningRetention.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN PayrollEarningRetention.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	CASE
	|		WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|			THEN -1 * PayrollEarningRetention.Amount
	|		ELSE PayrollEarningRetention.Amount
	|	END AS Amount,
	|	VALUE(AccountingRecordType.Debit) AS RecordKindAccountingJournalEntries,
	|	TRUE AS FixedCost,
	|	TRUE AS ProductionExpenses,
	|	CAST(&Payroll AS STRING(100)) AS ContentOfAccountingRecord,
	|	PayrollEarningRetention.ExpenseItem AS IncomeAndExpenseItem
	|FROM
	|	TableEarning AS PayrollEarningRetention
	|WHERE
	|	PayrollEarningRetention.EarningAndDeductionType.Type <> VALUE(Enum.EarningAndDeductionTypes.Tax)
	|	AND PayrollEarningRetention.ExpenseItemType = VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|	AND PayrollEarningRetention.RegisterExpense
	|	AND PayrollEarningRetention.AmountCur <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PayrollEarningRetention.LineNumber AS LineNumber,
	|	PayrollEarningRetention.Period AS Period,
	|	PayrollEarningRetention.Company AS Company,
	|	PayrollEarningRetention.PresentationCurrency AS PresentationCurrency,
	|	CASE
	|		WHEN PayrollEarningRetention.ExpenseItemType = VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|			THEN PayrollEarningRetention.BusinessLine
	|		ELSE VALUE(Catalog.LinesOfBusiness.Other)
	|	END AS BusinessLine,
	|	CASE
	|		WHEN PayrollEarningRetention.ExpenseItemType = VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|			THEN PayrollEarningRetention.StructuralUnit
	|		ELSE UNDEFINED
	|	END AS StructuralUnit,
	|	CASE
	|		WHEN PayrollEarningRetention.RegisterExpense
	|			THEN PayrollEarningRetention.ExpenseItem
	|		WHEN PayrollEarningRetention.RegisterIncome
	|			THEN PayrollEarningRetention.IncomeItem
	|		ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|	END AS IncomeAndExpenseItem,
	|	PayrollEarningRetention.GLExpenseAccount AS GLAccount,
	|	CASE
	|		WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|			THEN PayrollEarningRetention.Amount
	|		ELSE 0
	|	END AS AmountExpense,
	|	CASE
	|		WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|			THEN PayrollEarningRetention.Amount
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN PayrollEarningRetention.ExpenseItemType = VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|				AND NOT PayrollEarningRetention.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				AND NOT PayrollEarningRetention.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN PayrollEarningRetention.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	CAST(&Payroll AS STRING(100)) AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|FROM
	|	TableEarning AS PayrollEarningRetention
	|WHERE
	|	PayrollEarningRetention.EarningAndDeductionType.Type <> VALUE(Enum.EarningAndDeductionTypes.Tax)
	|	AND (PayrollEarningRetention.ExpenseItemType IN (VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses), VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses), VALUE(Catalog.IncomeAndExpenseTypes.Revenue))
	|			OR PayrollEarningRetention.IncomeItemType IN (VALUE(Catalog.IncomeAndExpenseTypes.Revenue), VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)))
	|	AND (PayrollEarningRetention.RegisterExpense
	|			OR PayrollEarningRetention.RegisterIncome)
	|	AND PayrollEarningRetention.AmountCur <> 0
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.SalesOrder,
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
	|	PayrollEarningRetention.Company AS Company,
	|	PayrollEarningRetention.PresentationCurrency AS PresentationCurrency,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	PayrollEarningRetention.Period AS Period,
	|	PayrollEarningRetention.EarningAndDeductionType.TaxKind AS TaxKind,
	|	PayrollEarningRetention.EarningAndDeductionType.TaxKind.GLAccount AS GLAccount,
	|	PayrollEarningRetention.Amount AS Amount,
	|	CAST(&AddedTax AS STRING(100)) AS ContentOfAccountingRecord
	|FROM
	|	TableEarning AS PayrollEarningRetention
	|WHERE
	|	PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Tax)
	|	AND PayrollEarningRetention.AmountCur <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PayrollEarningRetention.LineNumber AS LineNumber,
	|	PayrollEarningRetention.Period AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|			THEN PayrollEarningRetention.GLExpenseAccount
	|		ELSE PayrollEarningRetention.Employee.SettlementsHumanResourcesGLAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN (PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|					OR PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Tax))
	|					AND PayrollEarningRetention.Employee.SettlementsHumanResourcesGLAccount.Currency
	|				OR PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|					AND PayrollEarningRetention.GLExpenseAccount.Currency
	|			THEN PayrollEarningRetention.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN (PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|					OR PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Tax))
	|					AND PayrollEarningRetention.Employee.SettlementsHumanResourcesGLAccount.Currency
	|				OR PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|					AND PayrollEarningRetention.GLExpenseAccount.Currency
	|			THEN PayrollEarningRetention.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|			THEN PayrollEarningRetention.Employee.SettlementsHumanResourcesGLAccount
	|		ELSE PayrollEarningRetention.GLExpenseAccount
	|	END AS AccountCr,
	|	CASE
	|		WHEN (PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|					OR PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Tax))
	|					AND PayrollEarningRetention.GLExpenseAccount.Currency
	|				OR PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|					AND PayrollEarningRetention.Employee.SettlementsHumanResourcesGLAccount.Currency
	|			THEN PayrollEarningRetention.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN (PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|					OR PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Tax))
	|					AND PayrollEarningRetention.GLExpenseAccount.Currency
	|				OR PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|					AND PayrollEarningRetention.Employee.SettlementsHumanResourcesGLAccount.Currency
	|			THEN PayrollEarningRetention.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	PayrollEarningRetention.Amount AS Amount,
	|	CAST(CASE
	|			WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Tax)
	|				THEN &AddedTax
	|			ELSE &Payroll
	|		END AS STRING(100)) AS Content
	|FROM
	|	TableEarning AS PayrollEarningRetention
	|WHERE
	|	PayrollEarningRetention.AmountCur <> 0");
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", 					DocumentRefPayroll);
	Query.SetParameter("PointInTime", 			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", 				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Payroll", 				NStr("en = 'Payroll'; ru = 'Начисление зарплаты';pl = 'Lista płac';es_ES = 'Nómina';es_CO = 'Nómina';tr = 'Bordro';it = 'Stipendi';de = 'Personal'", MainLanguageCode));
	Query.SetParameter("AddedTax", 				NStr("en = 'Tax accrued'; ru = 'Начисленные налоги';pl = 'Naliczone podatki';es_ES = 'Impuesto acumulado';es_CO = 'Impuesto acumulado';tr = 'Tahakkuk edilen vergi';it = 'Imposte maturate';de = 'Steuern angefallen'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency", 	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("DocumentCurrency", 		Common.ObjectAttributeValue(DocumentRefPayroll, "DocumentCurrency"));
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("OwnInventory",			Catalogs.InventoryOwnership.OwnInventory());
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	ResultsArray = Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefPayroll, StructureAdditionalProperties);
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableEarningsAndDeductions"    , ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePayroll"                  , ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory"                , ResultsArray[4].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses"        , ResultsArray[5].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxPayable"               , ResultsArray[6].Unload());
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries" , ResultsArray[7].Unload());
	EndIf;
	
	GenerateTableLoanSettlements(DocumentRefPayroll, StructureAdditionalProperties);
	GenerateTableAccountOfLoans(DocumentRefPayroll, StructureAdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRefPayroll, StructureAdditionalProperties);
	
	FinancialAccounting.FillExtraDimensions(DocumentRefPayroll, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefPayroll, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefPayroll, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefPayroll, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
EndProcedure

#EndRegion 

#Region Internal

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "EarningsDeductions" Then
		TypeOfEarningAndDeductionType = Common.ObjectAttributeValue(StructureData.EarningAndDeductionType, "Type");
	Else
		TypeOfEarningAndDeductionType = Undefined;
	EndIf;
	
	If StructureData.TabName = "EarningsDeductions"
			And TypeOfEarningAndDeductionType = Enums.EarningAndDeductionTypes.Earning Then
		IncomeAndExpenseStructure.Insert("ExpenseItem", StructureData.ExpenseItem);
		IncomeAndExpenseStructure.Insert("RegisterExpense", StructureData.RegisterExpense);
	ElsIf StructureData.TabName = "EarningsDeductions"
			And TypeOfEarningAndDeductionType = Enums.EarningAndDeductionTypes.Deduction Then
		IncomeAndExpenseStructure.Insert("IncomeItem", StructureData.IncomeItem);
		IncomeAndExpenseStructure.Insert("RegisterIncome", StructureData.RegisterIncome);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	
	If StructureData.TabName = "EarningsDeductions" Then
		TypeOfEarningAndDeductionType = Common.ObjectAttributeValue(StructureData.EarningAndDeductionType, "Type");
	Else
		TypeOfEarningAndDeductionType = Undefined;
	EndIf;
	
	If StructureData.TabName = "EarningsDeductions"
			And TypeOfEarningAndDeductionType = Enums.EarningAndDeductionTypes.Earning Then
		Result.Insert("GLExpenseAccount", "ExpenseItem");
		
		Array = New Array;
		Array.Add("RegisterIncome");
		Array.Add("IncomeItem");
		Result.Insert("Clear", Array);
	ElsIf StructureData.TabName = "EarningsDeductions"
			And TypeOfEarningAndDeductionType = Enums.EarningAndDeductionTypes.Deduction Then
		Result.Insert("GLExpenseAccount", "IncomeItem");
		
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

#Region LoanSettlements

Procedure GenerateTableLoanSettlements(DocumentRefPayroll, StructureAdditionalProperties)

	If DocumentRefPayroll.LoanRepayment.Count() = 0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableLoanSettlements", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Company"					, StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("InterestOfEarningOnLoan"	, NStr("en = 'Interest of Earning on loan'; ru = 'Начисление процентов по займу';pl = 'Odsetki od naliczenia wynagrodzenia pożyczka';es_ES = 'Interés de Ingresos en préstamo';es_CO = 'Interés de Ingresos en préstamo';tr = 'Tahakkuk eden kredi faizi';it = 'Interessi maturati per il prestito';de = 'Bezugszinsen auf Darlehen'", MainLanguageCode));
	Query.SetParameter("InterestOfChargeOnLoan"		, NStr("en = 'Interest of charge on loan'; ru = 'Удержание процентов по займу';pl = 'Opłacone odsetki';es_ES = 'Interés de cargo en préstamo';es_CO = 'Interés de cargo en préstamo';tr = 'Kredinin faiz oranı';it = 'Interessi caricati per il prestito';de = 'Zinsen auf Darlehensgebühren'", MainLanguageCode));
	Query.SetParameter("PrincipalOfChargeOnLoan"	, NStr("en = 'Principal of charge on loan'; ru = 'Удержание основного долга по займу';pl = 'Kwota główna pożyczki';es_ES = 'Principal del cargo en préstamo';es_CO = 'Principal del cargo en préstamo';tr = 'Kredi faizinin asıl borçlusu';it = 'Caricamento del debito principale sul debito';de = 'Beibehaltung der Hauptschuld aus dem Darlehen'", MainLanguageCode));
	Query.SetParameter("Ref"						, DocumentRefPayroll);
	Query.SetParameter("PointInTime"				, New Boundary(StructureAdditionalProperties.ForPosting.PointInTime,BoundaryType.Including));
	Query.SetParameter("ControlPeriod"				, StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeRateDifference"		, NStr("en = 'Exchange difference'; ru = 'Курсовая разница';pl = 'Różnica kursowa';es_ES = 'Diferencia de cambio';es_CO = 'Diferencia de cambio';tr = 'Döviz kuru farkı';it = 'differenza di cambio';de = 'Wechselkursdifferenz'", MainLanguageCode));
	Query.SetParameter("CurrencyDR"					, DocumentRefPayroll.DocumentCurrency);
	Query.SetParameter("PresentationCurrency"		, StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod"			, StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting"	, StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.Text = 
	"SELECT
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	PayrollLoanRepayment.LineNumber AS LineNumber,
	|	PayrollLoanRepayment.Ref AS Ref,
	|	PayrollLoanRepayment.Ref.Date AS Period,
	|	PayrollLoanRepayment.Ref.StructuralUnit AS StructuralUnit,
	|	PayrollLoanRepayment.Ref.RegistrationPeriod AS RegistrationPeriod,
	|	PayrollLoanRepayment.Ref.DocumentCurrency AS Currency,
	|	PayrollLoanRepayment.Employee AS Employee,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN PayrollLoanRepayment.Employee.SettlementsHumanResourcesGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS SettlementsHumanResourcesGLAccount,
	|	PayrollLoanRepayment.LoanContract AS LoanContract,
	|	LoanContractDoc.InterestIncomeItem AS IncomeItem,
	|	LoanContractDoc.InterestExpenseItem AS ExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN LoanContractDoc.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountLoanContract,
	|	LoanContractDoc.SettlementsCurrency AS CurrencyLoanContract,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN LoanContractDoc.InterestGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InterestGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN LoanContractDoc.CostAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CostAccount,
	|	LoanContractDoc.BusinessArea AS BusinessArea,
	|	PayrollLoanRepayment.PrincipalCharged + PayrollLoanRepayment.InterestCharged AS AmountCur,
	|	CAST((PayrollLoanRepayment.PrincipalCharged + PayrollLoanRepayment.InterestCharged) * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SettlementsExchangeRate.Rate * AcoountExchangeRate.Repetition / (AcoountExchangeRate.Rate * SettlementsExchangeRate.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (SettlementsExchangeRate.Rate * AcoountExchangeRate.Repetition / (AcoountExchangeRate.Rate * SettlementsExchangeRate.Repetition))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST((PayrollLoanRepayment.PrincipalCharged + PayrollLoanRepayment.InterestCharged) * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SettlementsExchangeRate.Rate * LoanContractExchangeRate.Repetition / (LoanContractExchangeRate.Rate * SettlementsExchangeRate.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (SettlementsExchangeRate.Rate * LoanContractExchangeRate.Repetition / (LoanContractExchangeRate.Rate * SettlementsExchangeRate.Repetition))
	|		END AS NUMBER(15, 2)) AS ContractAmountCur,
	|	PayrollLoanRepayment.PrincipalCharged AS PrincipalChargedCur,
	|	CAST(PayrollLoanRepayment.PrincipalCharged * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SettlementsExchangeRate.Rate * AcoountExchangeRate.Repetition / (AcoountExchangeRate.Rate * SettlementsExchangeRate.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (SettlementsExchangeRate.Rate * AcoountExchangeRate.Repetition / (AcoountExchangeRate.Rate * SettlementsExchangeRate.Repetition))
	|		END AS NUMBER(15, 2)) AS PrincipalCharged,
	|	CAST(PayrollLoanRepayment.PrincipalCharged * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SettlementsExchangeRate.Rate * LoanContractExchangeRate.Repetition / (LoanContractExchangeRate.Rate * SettlementsExchangeRate.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (SettlementsExchangeRate.Rate * LoanContractExchangeRate.Repetition / (LoanContractExchangeRate.Rate * SettlementsExchangeRate.Repetition))
	|		END AS NUMBER(15, 2)) AS ContractPrincipalChargedCur,
	|	PayrollLoanRepayment.InterestCharged AS InterestChargedCur,
	|	CAST(PayrollLoanRepayment.InterestCharged * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SettlementsExchangeRate.Rate * AcoountExchangeRate.Repetition / (AcoountExchangeRate.Rate * SettlementsExchangeRate.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (SettlementsExchangeRate.Rate * AcoountExchangeRate.Repetition / (AcoountExchangeRate.Rate * SettlementsExchangeRate.Repetition))
	|		END AS NUMBER(15, 2)) AS InterestCharged,
	|	CAST(PayrollLoanRepayment.InterestCharged * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SettlementsExchangeRate.Rate * LoanContractExchangeRate.Repetition / (LoanContractExchangeRate.Rate * SettlementsExchangeRate.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (SettlementsExchangeRate.Rate * LoanContractExchangeRate.Repetition / (LoanContractExchangeRate.Rate * SettlementsExchangeRate.Repetition))
	|		END AS NUMBER(15, 2)) AS ContractInterestChargedCur,
	|	PayrollLoanRepayment.InterestAccrued AS InterestAccruedCur,
	|	CAST(PayrollLoanRepayment.InterestAccrued * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SettlementsExchangeRate.Rate * AcoountExchangeRate.Repetition / (AcoountExchangeRate.Rate * SettlementsExchangeRate.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (SettlementsExchangeRate.Rate * AcoountExchangeRate.Repetition / (AcoountExchangeRate.Rate * SettlementsExchangeRate.Repetition))
	|		END AS NUMBER(15, 2)) AS InterestAccrued,
	|	CAST(PayrollLoanRepayment.InterestAccrued * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SettlementsExchangeRate.Rate * LoanContractExchangeRate.Repetition / (LoanContractExchangeRate.Rate * SettlementsExchangeRate.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (SettlementsExchangeRate.Rate * LoanContractExchangeRate.Repetition / (LoanContractExchangeRate.Rate * SettlementsExchangeRate.Repetition))
	|		END AS NUMBER(15, 2)) AS ContractInterestAccruedCur,
	|	LoanContractDoc.LoanKind AS LoanKind
	|INTO TableLoans
	|FROM
	|	Document.Payroll.LoanRepayment AS PayrollLoanRepayment
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AcoountExchangeRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS SettlementsExchangeRate
	|		ON PayrollLoanRepayment.Ref.DocumentCurrency = SettlementsExchangeRate.Currency
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS LoanContractExchangeRate
	|		ON PayrollLoanRepayment.LoanContract.SettlementsCurrency = LoanContractExchangeRate.Currency
	|		LEFT JOIN Document.LoanContract AS LoanContractDoc
	|		ON PayrollLoanRepayment.LoanContract = LoanContractDoc.Ref
	|WHERE
	|	PayrollLoanRepayment.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableLoans.Company AS Company,
	|	TableLoans.PresentationCurrency AS PresentationCurrency,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableLoans.Period AS Date,
	|	TableLoans.Period AS Period,
	|	&PrincipalOfChargeOnLoan AS PostingContent,
	|	TableLoans.Employee AS Counterparty,
	|	TableLoans.ContractPrincipalChargedCur AS PrincipalDebtCur,
	|	TableLoans.PrincipalCharged AS PrincipalDebt,
	|	TableLoans.ContractPrincipalChargedCur AS PrincipalChargedCurForBalance,
	|	TableLoans.PrincipalCharged AS PrincipalChargedForBalance,
	|	0 AS InterestCur,
	|	0 AS Interest,
	|	0 AS InterestCurForBalance,
	|	0 AS InterestForBalance,
	|	0 AS CommissionCur,
	|	0 AS Commission,
	|	0 AS CommissionCurForBalance,
	|	0 AS CommissionForBalance,
	|	TableLoans.LoanContract AS LoanContract,
	|	TableLoans.Currency AS Currency,
	|	TableLoans.GLAccountLoanContract AS GLAccount,
	|	TRUE AS DeductedFromSalary,
	|	TableLoans.LoanContract.LoanKind AS LoanKind,
	|	TableLoans.StructuralUnit AS StructuralUnit,
	|	TableLoans.ContractPrincipalChargedCur AS AmountCur,
	|	TableLoans.PrincipalCharged AS Amount
	|INTO TemporaryTableLoanSettlements
	|FROM
	|	TableLoans AS TableLoans
	|WHERE
	|	TableLoans.PrincipalChargedCur <> 0
	|
	|UNION ALL
	|
	|SELECT
	|	TableLoans.Company,
	|	TableLoans.PresentationCurrency,
	|	VALUE(AccumulationRecordType.Expense),
	|	TableLoans.Period,
	|	TableLoans.Period,
	|	&InterestOfChargeOnLoan,
	|	TableLoans.Employee,
	|	0,
	|	0,
	|	0,
	|	0,
	|	TableLoans.ContractInterestChargedCur,
	|	TableLoans.InterestCharged,
	|	TableLoans.ContractInterestChargedCur,
	|	TableLoans.InterestCharged,
	|	0,
	|	0,
	|	0,
	|	0,
	|	TableLoans.LoanContract,
	|	TableLoans.Currency,
	|	TableLoans.InterestGLAccount,
	|	TRUE,
	|	TableLoans.LoanContract.LoanKind,
	|	TableLoans.StructuralUnit,
	|	TableLoans.ContractInterestChargedCur,
	|	TableLoans.InterestCharged
	|FROM
	|	TableLoans AS TableLoans
	|WHERE
	|	TableLoans.PrincipalChargedCur <> 0
	|
	|UNION ALL
	|
	|SELECT
	|	TableLoans.Company,
	|	TableLoans.PresentationCurrency,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableLoans.Period,
	|	TableLoans.Period,
	|	&InterestOfEarningOnLoan,
	|	TableLoans.Employee,
	|	0,
	|	0,
	|	0,
	|	0,
	|	TableLoans.ContractInterestAccruedCur,
	|	TableLoans.InterestAccrued,
	|	-TableLoans.ContractInterestAccruedCur,
	|	-TableLoans.InterestAccrued,
	|	0,
	|	0,
	|	0,
	|	0,
	|	TableLoans.LoanContract,
	|	TableLoans.Currency,
	|	TableLoans.InterestGLAccount,
	|	FALSE,
	|	TableLoans.LoanContract.LoanKind,
	|	TableLoans.StructuralUnit,
	|	TableLoans.ContractInterestAccruedCur,
	|	TableLoans.InterestAccrued
	|FROM
	|	TableLoans AS TableLoans
	|WHERE
	|	TableLoans.PrincipalChargedCur <> 0";
	
	QueryResult = Query.Execute();
	
	Query.Text = 
	"SELECT
	|	TemporaryTableLoanSettlements.Company,
	|	TemporaryTableLoanSettlements.PresentationCurrency,
	|	TemporaryTableLoanSettlements.Counterparty,
	|	TemporaryTableLoanSettlements.LoanContract
	|FROM
	|	TemporaryTableLoanSettlements AS TemporaryTableLoanSettlements";
	
	QueryResult = Query.Execute();
	
	Blocking = New DataLock;
	LockItem = Blocking.Add("AccumulationRegister.LoanSettlements");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each QueryResultColumn In QueryResult.Columns Do
		LockItem.UseFromDataSource(QueryResultColumn.Name, QueryResultColumn.Name);
	EndDo;
	Blocking.Lock();
	
	QueryNumber = 0;
	
	IsBusinessUnit = True;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesLoanSettlements(Query.TempTablesManager, QueryNumber, IsBusinessUnit);
	ResultsArray = Query.ExecuteBatch();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableLoanSettlements", ResultsArray[QueryNumber].Unload());
	
EndProcedure

Procedure GenerateTableAccountOfLoans(DocumentRefPayroll, StructureAdditionalProperties)

	If DocumentRefPayroll.LoanRepayment.Count() = 0 Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",										DocumentRefPayroll);
	Query.SetParameter("PointInTime",								New Boundary(StructureAdditionalProperties.ForPosting.PointInTime,BoundaryType.Including));
	Query.SetParameter("Company",									StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeRateDifference",					NStr("en = 'Exchange difference'; ru = 'Курсовая разница';pl = 'Różnica kursowa';es_ES = 'Diferencia de cambio';es_CO = 'Diferencia de cambio';tr = 'Döviz kuru farkı';it = 'differenza di cambio';de = 'Wechselkursdifferenz'", MainLanguageCode));
	Query.SetParameter("Payroll",									NStr("en = 'Payroll'; ru = 'Начисление зарплаты';pl = 'Lista płac';es_ES = 'Nómina';es_CO = 'Nómina';tr = 'Bordro';it = 'Stipendi';de = 'Personal'", MainLanguageCode));
	Query.SetParameter("TaxAccrued",								NStr("en = 'Tax accrued'; ru = 'Начислен налог';pl = 'Naliczone podatki';es_ES = 'Impuesto acumulado';es_CO = 'Impuesto acumulado';tr = 'Tahakkuk edilen vergi';it = 'Imposte maturate';de = 'Steuern angefallen'", MainLanguageCode));
	Query.SetParameter("ChargeForRepaymentPrincipalAndInterest",	NStr("en = 'Charge for repayment principal and interest'; ru = 'Удержание в счет погашения займа и процентов';pl = 'Opłata na rzecz spłaty kwoty głównej długu i odsetek';es_ES = 'Cargo por reembolso de capital e interés';es_CO = 'Cargo por el pago principal y el interés';tr = 'Geri ödeme anapara ve faizi için ücret';it = 'Trattenuta per il rimborso di prestiti e interessi';de = 'Einbehaltung für Darlehen und Zinsrückzahlung'", MainLanguageCode));
	Query.SetParameter("InterestOfChargeOnLoan",					NStr("en = 'Interest of charge on loan'; ru = 'Удержание процентов по займу';pl = 'Opłacone odsetki';es_ES = 'Interés de cargo en préstamo';es_CO = 'Interés de cargo en préstamo';tr = 'Kredinin faiz oranı';it = 'Interessi caricati per il prestito';de = 'Zinsen auf Darlehensgebühren'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency",						StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod", 						StructureAdditionalProperties.ForPosting.ExchangeRateMethod);	
	
	Query.Text = 
	"SELECT
	|	TableLoans.Company AS Company,
	|	TableLoans.PresentationCurrency AS PresentationCurrency,
	|	TableLoans.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableLoans.RegistrationPeriod AS RegistrationPeriod,
	|	TableLoans.Currency AS Currency,
	|	TableLoans.StructuralUnit AS StructuralUnit,
	|	TableLoans.Employee AS Employee,
	|	-TableLoans.AmountCur AS AmountCur,
	|	-TableLoans.Amount AS Amount,
	|	TableLoans.GLAccountLoanContract AS GLAccountLoanContract,
	|	VALUE(AccountingRecordType.Credit) AS AccountingJournalEntriesRecordType,
	|	CAST(&ChargeForRepaymentPrincipalAndInterest AS STRING(100)) AS ContentOfAccountingRecord
	|FROM
	|	TableLoans AS TableLoans
	|WHERE
	|	TableLoans.Amount <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableLoans.LineNumber AS LineNumber,
	|	TableLoans.Period AS Period,
	|	TableLoans.Company AS Company,
	|	TableLoans.PresentationCurrency AS PresentationCurrency,
	|	CASE
	|		WHEN TableLoans.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|			THEN TableLoans.BusinessArea
	|		ELSE VALUE(Catalog.LinesOfBusiness.Other)
	|	END AS BusinessLine,
	|	CASE
	|		WHEN TableLoans.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|			THEN TableLoans.StructuralUnit
	|		ELSE UNDEFINED
	|	END AS StructuralUnit,
	|	TableLoans.CostAccount AS GLAccount,
	|	CASE
	|		WHEN TableLoans.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|			THEN TableLoans.ExpenseItem
	|		ELSE TableLoans.IncomeItem
	|	END AS IncomeAndExpenseItem,
	|	TableLoans.Employee AS Analytics,
	|	0 AS AmountExpense,
	|	TableLoans.InterestAccrued AS AmountIncome,
	|	CAST(&InterestOfChargeOnLoan AS STRING(100)) AS ContentOfAccountingRecord
	|FROM
	|	TableLoans AS TableLoans
	|WHERE
	|	TableLoans.InterestAccrued <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.Date AS Date,
	|	DocumentTable.Company AS Company,
	|	CAST(CASE
	|			WHEN DocumentTable.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentTable.Counterparty.SettlementsHumanResourcesGLAccount
	|			ELSE DocumentTable.LoanContract.GLAccount
	|		END AS ChartOfAccounts.PrimaryChartOfAccounts) AS AccountDr,
	|	CAST(CASE
	|			WHEN DocumentTable.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentTable.GLAccount
	|			ELSE DocumentTable.LoanContract.CostAccount
	|		END AS ChartOfAccounts.PrimaryChartOfAccounts) AS AccountCr,
	|	DocumentTable.Currency AS Currency,
	|	DocumentTable.AmountCur AS AmountCur,
	|	DocumentTable.Amount AS Amount,
	|	CAST(DocumentTable.PostingContent AS STRING(100)) AS PostingContent
	|INTO TemporaryTableLoanSettlementsForRegisterRecord
	|FROM
	|	TemporaryTableLoanSettlements AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.AccountDr AS AccountDr,
	|	DocumentTable.AccountCr AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.AccountDr.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.AccountCr.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.AccountDr.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN DocumentTable.AccountCr.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	DocumentTable.Amount AS Amount,
	|	CAST(DocumentTable.PostingContent AS STRING(100)) AS Content
	|FROM
	|	TemporaryTableLoanSettlementsForRegisterRecord AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND &UseDefaultTypeOfAccounting
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	TemporaryTableExchangeRateDifferencesLoanSettlements.Date,
	|	TemporaryTableExchangeRateDifferencesLoanSettlements.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TemporaryTableExchangeRateDifferencesLoanSettlements.ExchangeRateDifferenceAmount > 0
	|			THEN TemporaryTableExchangeRateDifferencesLoanSettlements.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN TemporaryTableExchangeRateDifferencesLoanSettlements.ExchangeRateDifferenceAmount > 0
	|			THEN &ForeignCurrencyExchangeLoss
	|		ELSE TemporaryTableExchangeRateDifferencesLoanSettlements.GLAccount
	|	END,
	|	CASE
	|		WHEN TemporaryTableExchangeRateDifferencesLoanSettlements.ExchangeRateDifferenceAmount > 0
	|				AND TemporaryTableExchangeRateDifferencesLoanSettlements.GLAccount.Currency
	|			THEN TemporaryTableExchangeRateDifferencesLoanSettlements.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporaryTableExchangeRateDifferencesLoanSettlements.ExchangeRateDifferenceAmount < 0
	|				AND TemporaryTableExchangeRateDifferencesLoanSettlements.GLAccount.Currency
	|			THEN TemporaryTableExchangeRateDifferencesLoanSettlements.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN TemporaryTableExchangeRateDifferencesLoanSettlements.ExchangeRateDifferenceAmount > 0
	|			THEN TemporaryTableExchangeRateDifferencesLoanSettlements.ExchangeRateDifferenceAmount
	|		ELSE -TemporaryTableExchangeRateDifferencesLoanSettlements.ExchangeRateDifferenceAmount
	|	END,
	|	CAST(&ExchangeRateDifference AS STRING(100))
	|FROM
	|	TemporaryTableExchangeRateDifferencesLoanSettlements AS TemporaryTableExchangeRateDifferencesLoanSettlements
	|WHERE
	|	&UseDefaultTypeOfAccounting
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	PayrollLoanRepayment.LineNumber AS LineNumber,
	|	PayrollLoanRepayment.Ref.Date AS Period,
	|	PayrollLoanRepayment.Ref.RegistrationPeriod AS RegistrationPeriod,
	|	PayrollLoanRepayment.Ref.DocumentCurrency AS Currency,
	|	PayrollLoanRepayment.Ref.StructuralUnit AS StructuralUnit,
	|	PayrollLoanRepayment.Employee AS Employee,
	|	PayrollLoanRepayment.LoanContract.GLAccount AS CostAccount,
	|	VALUE(Document.SalesOrder.EmptyRef) AS SalesOrder,
	|	VALUE(Catalog.LinesOfBusiness.EmptyRef) AS BusinessArea,
	|	PayrollLoanRepayment.Ref.RegistrationPeriod AS StartDate,
	|	ENDOFPERIOD(PayrollLoanRepayment.Ref.RegistrationPeriod, MONTH) AS EndDate,
	|	0 AS DaysWorked,
	|	0 AS HoursWorked,
	|	0 AS Size,
	|	CASE
	|		WHEN PayrollLoanRepayment.LoanContract.DeductionPrincipalDebt = UNDEFINED
	|				OR PayrollLoanRepayment.LoanContract.DeductionPrincipalDebt = VALUE(Catalog.EarningAndDeductionTypes.EmptyRef)
	|			THEN VALUE(Catalog.EarningAndDeductionTypes.RepaymentOfLoanFromSalary)
	|		ELSE PayrollLoanRepayment.LoanContract.DeductionPrincipalDebt
	|	END AS EarningAndDeductionType,
	|	CAST(PayrollLoanRepayment.PrincipalCharged * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SettlementsExchangeRate.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * SettlementsExchangeRate.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (SettlementsExchangeRate.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * SettlementsExchangeRate.Repetition))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	PayrollLoanRepayment.PrincipalCharged AS AmountCur
	|FROM
	|	Document.Payroll.LoanRepayment AS PayrollLoanRepayment
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(, Company = &Company) AS SettlementsExchangeRate
	|		ON PayrollLoanRepayment.Ref.DocumentCurrency = SettlementsExchangeRate.Currency
	|WHERE
	|	PayrollLoanRepayment.Ref = &Ref
	|	AND PayrollLoanRepayment.PrincipalCharged > 0
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	&PresentationCurrency,
	|	PayrollLoanRepayment.LineNumber,
	|	PayrollLoanRepayment.Ref.Date,
	|	PayrollLoanRepayment.Ref.RegistrationPeriod,
	|	PayrollLoanRepayment.Ref.DocumentCurrency,
	|	PayrollLoanRepayment.Ref.StructuralUnit,
	|	PayrollLoanRepayment.Employee,
	|	PayrollLoanRepayment.LoanContract.GLAccount,
	|	VALUE(Document.SalesOrder.EmptyRef),
	|	VALUE(Catalog.LinesOfBusiness.EmptyRef),
	|	PayrollLoanRepayment.Ref.RegistrationPeriod,
	|	ENDOFPERIOD(PayrollLoanRepayment.Ref.RegistrationPeriod, MONTH),
	|	0,
	|	0,
	|	0,
	|	CASE
	|		WHEN PayrollLoanRepayment.LoanContract.DeductionInterest = UNDEFINED
	|				OR PayrollLoanRepayment.LoanContract.DeductionInterest = VALUE(Catalog.EarningAndDeductionTypes.EmptyRef)
	|			THEN VALUE(Catalog.EarningAndDeductionTypes.InterestOnLoan)
	|		ELSE PayrollLoanRepayment.LoanContract.DeductionInterest
	|	END,
	|	CAST(PayrollLoanRepayment.InterestCharged * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SettlementsExchangeRate.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * SettlementsExchangeRate.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (SettlementsExchangeRate.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * SettlementsExchangeRate.Repetition))
	|		END AS NUMBER(15, 2)),
	|	PayrollLoanRepayment.InterestCharged
	|FROM
	|	Document.Payroll.LoanRepayment AS PayrollLoanRepayment
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(, Company = &Company) AS SettlementsExchangeRate
	|		ON PayrollLoanRepayment.Ref.DocumentCurrency = SettlementsExchangeRate.Currency
	|WHERE
	|	PayrollLoanRepayment.Ref = &Ref
	|	AND PayrollLoanRepayment.InterestCharged > 0";
	
	Query.SetParameter("ForeignCurrencyExchangeLoss", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	ResultsArray = Query.ExecuteBatch();
	
	CurrentTable = ResultsArray[0].Unload();
	If ValueIsFilled(StructureAdditionalProperties.TableForRegisterRecords.TablePayroll) Then
		For Each CurrentRow In CurrentTable Do
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TablePayroll.Add();
			FillPropertyValues(NewRow, CurrentRow);
		EndDo;
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePayroll", CurrentTable);
	EndIf;
	
	CurrentTable = ResultsArray[1].Unload();
	If ValueIsFilled(StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses) Then
		For Each CurrentRow In CurrentTable Do
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
			FillPropertyValues(NewRow, CurrentRow);
		EndDo;
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", CurrentTable);
	EndIf;
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		
		CurrentTable = ResultsArray[3].Unload();
		If ValueIsFilled(StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries) Then
			For Each CurrentRow In CurrentTable Do
				NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
				FillPropertyValues(NewRow, CurrentRow);
			EndDo;
		Else
			StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", CurrentTable);
		EndIf;
		
	EndIf;
	
	CurrentTable = ResultsArray[4].Unload();
	If ValueIsFilled(StructureAdditionalProperties.TableForRegisterRecords.TableEarningsAndDeductions) Then
		For Each CurrentRow In CurrentTable Do
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableEarningsAndDeductions.Add();
			FillPropertyValues(NewRow, CurrentRow);
		EndDo;
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableEarningsAndDeductions", CurrentTable);
	EndIf;

EndProcedure

#EndRegion

#Region TableGeneration

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion 

#EndRegion 

#EndIf