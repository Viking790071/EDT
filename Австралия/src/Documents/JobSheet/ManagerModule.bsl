#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefJobSheet, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	
	"SELECT
	|	JobSheetTeamMembers.Employee AS Employee,
	|	CASE
	|		WHEN TableAmountCWP.AmountLPF = 0
	|			THEN 0
	|		ELSE JobSheetTeamMembers.LPF / TableAmountCWP.AmountLPF
	|	END AS Factor
	|INTO TableEmployees
	|FROM
	|	Document.JobSheet.TeamMembers AS JobSheetTeamMembers
	|		LEFT JOIN (SELECT
	|			SUM(JobSheetTeamMembers.LPF) AS AmountLPF,
	|			JobSheetTeamMembers.Ref AS Ref
	|		FROM
	|			Document.JobSheet.TeamMembers AS JobSheetTeamMembers
	|		WHERE
	|			JobSheetTeamMembers.Ref = &Ref
	|		
	|		GROUP BY
	|			JobSheetTeamMembers.Ref) AS TableAmountCWP
	|		ON JobSheetTeamMembers.Ref = TableAmountCWP.Ref
	|WHERE
	|	JobSheetTeamMembers.Ref = &Ref
	|	AND NOT JobSheetTeamMembers.Ref.Performer REFS Catalog.Employees
	|
	|UNION ALL
	|
	|SELECT
	|	JobSheet.Performer,
	|	1
	|FROM
	|	Document.JobSheet AS JobSheet
	|WHERE
	|	JobSheet.Ref = &Ref
	|	AND JobSheet.Performer REFS Catalog.Employees
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	JobSheetOperations.LineNumber AS LineNumber,
	|	JobSheetOperations.Period AS Period,
	|	JobSheetOperations.Ref.DocumentCurrency AS PresentationCurrency,
	|	&Company AS Company,
	|	JobSheetOperations.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN JobSheetOperations.Operation.ExpensesGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN JobSheetOperations.Products.ExpensesGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	JobSheetOperations.Products AS ProductsCorr,
	|	JobSheetOperations.Characteristic AS CharacteristicCorr,
	|	JobSheetOperations.Batch AS BatchCorr,
	|	JobSheetOperations.Specification AS SpecificationCorr,
	|	JobSheetOperations.SalesOrder AS SalesOrder,
	|	JobSheetOperations.Cost * CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN SettlementsExchangeRate.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * SettlementsExchangeRate.Repetition)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN 1 / (SettlementsExchangeRate.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * SettlementsExchangeRate.Repetition))
	|	END AS Cost,
	|	JobSheetOperations.Cost AS CostCur,
	|	VALUE(AccountingRecordType.Debit) AS RecordKindAccountingJournalEntries,
	|	&Payroll AS ContentOfAccountingRecord,
	|	JobSheetOperations.StandardHours AS StandardHours,
	|	JobSheetOperations.Tariff AS Tariff,
	|	TRUE AS FixedCost,
	|	CASE
	|		WHEN &UsePayrollSubsystem
	|			THEN JobSheetOperations.Ref.Closed
	|		ELSE FALSE
	|	END AS Closed,
	|	JobSheetOperations.Ref.ClosingDate AS ClosingDate
	|INTO TableJobSheetOperations
	|FROM
	|	Document.JobSheet.Operations AS JobSheetOperations
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS SettlementsExchangeRate
	|		ON JobSheetOperations.Ref.DocumentCurrency = SettlementsExchangeRate.Currency
	|		LEFT JOIN InformationRegister.ProductIncomeAndExpenseItems AS ProductIncomeAndExpenseItems
	|		ON JobSheetOperations.Ref.Company = ProductIncomeAndExpenseItems.Company
	|			AND JobSheetOperations.Products = ProductIncomeAndExpenseItems.Product
	|			AND JobSheetOperations.Products.ProductsCategory = ProductIncomeAndExpenseItems.ProductCategory
	|			AND JobSheetOperations.Ref.StructuralUnit = ProductIncomeAndExpenseItems.StructuralUnit
	|WHERE
	|	JobSheetOperations.Ref = &Ref
	|	AND (JobSheetOperations.Products.ExpensesGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress)
	|			OR JobSheetOperations.Products.ExpensesGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	JobSheetOperations.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	BEGINOFPERIOD(JobSheetOperations.ClosingDate, MONTH) AS RegistrationPeriod,
	|	JobSheetOperations.PresentationCurrency AS Currency,
	|	JobSheetOperations.StructuralUnit AS StructuralUnit,
	|	TableEmployees.Employee AS Employee,
	|	JobSheetOperations.Period AS StartDate,
	|	JobSheetOperations.Period AS EndDate,
	|	0 AS DaysWorked,
	|	JobSheetOperations.StandardHours AS HoursWorked,
	|	JobSheetOperations.Tariff AS Size,
	|	VALUE(Catalog.EarningAndDeductionTypes.PieceRatePay) AS EarningAndDeductionType,
	|	TableEmployees.Employee.SettlementsHumanResourcesGLAccount AS GLAccount,
	|	JobSheetOperations.LineNumber AS LineNumber,
	|	JobSheetOperations.GLAccount AS InventoryGLAccount,
	|	JobSheetOperations.CorrGLAccount AS CorrespondentAccountAccountingInventory,
	|	JobSheetOperations.ProductsCorr AS ProductsCorr,
	|	JobSheetOperations.CharacteristicCorr AS CharacteristicCorr,
	|	JobSheetOperations.BatchCorr AS BatchCorr,
	|	JobSheetOperations.SpecificationCorr AS SpecificationCorr,
	|	JobSheetOperations.SalesOrder AS SalesOrder,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindAccountingJournalEntries,
	|	&Payroll AS ContentOfAccountingRecord,
	|	CAST(JobSheetOperations.CostCur * TableEmployees.Factor AS NUMBER(15, 2)) AS AmountCur,
	|	CAST(JobSheetOperations.Cost * TableEmployees.Factor AS NUMBER(15, 2)) AS Amount,
	|	TRUE AS FixedCost,
	|	CASE
	|		WHEN &UsePayrollSubsystem
	|			THEN JobSheetOperations.Closed
	|		ELSE FALSE
	|	END AS Closed,
	|	JobSheetOperations.ClosingDate AS ClosingDate
	|INTO TableOfOperations
	|FROM
	|	TableEmployees AS TableEmployees
	|		INNER JOIN TableJobSheetOperations AS JobSheetOperations
	|		ON (TRUE)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableOfOperations.Company AS Company,
	|	TableOfOperations.PresentationCurrency AS PresentationCurrency,
	|	TableOfOperations.ClosingDate AS Period,
	|	TableOfOperations.RegistrationPeriod AS RegistrationPeriod,
	|	TableOfOperations.Currency AS Currency,
	|	TableOfOperations.StructuralUnit AS StructuralUnit,
	|	TableOfOperations.Employee AS Employee,
	|	TableOfOperations.Period AS StartDate,
	|	TableOfOperations.Period AS EndDate,
	|	TableOfOperations.DaysWorked AS DaysWorked,
	|	TableOfOperations.HoursWorked AS HoursWorked,
	|	TableOfOperations.Size AS Size,
	|	TableOfOperations.EarningAndDeductionType AS EarningAndDeductionType,
	|	TableOfOperations.AmountCur AS AmountCur,
	|	TableOfOperations.Amount AS Amount
	|FROM
	|	TableOfOperations AS TableOfOperations
	|WHERE
	|	TableOfOperations.Closed
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableOfOperations.Company AS Company,
	|	TableOfOperations.PresentationCurrency AS PresentationCurrency,
	|	TableOfOperations.ClosingDate AS Period,
	|	TableOfOperations.RecordType AS RecordType,
	|	TableOfOperations.RegistrationPeriod AS RegistrationPeriod,
	|	TableOfOperations.Currency AS Currency,
	|	TableOfOperations.StructuralUnit AS StructuralUnit,
	|	TableOfOperations.Employee AS Employee,
	|	TableOfOperations.Amount AS Amount,
	|	TableOfOperations.AmountCur AS AmountCur,
	|	TableOfOperations.GLAccount AS GLAccount,
	|	TableOfOperations.RecordKindAccountingJournalEntries AS RecordKindAccountingJournalEntries,
	|	TableOfOperations.ContentOfAccountingRecord AS ContentOfAccountingRecord
	|FROM
	|	TableOfOperations AS TableOfOperations
	|WHERE
	|	TableOfOperations.Closed
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	JobSheetOperations.Period AS Period,
	|	&Company AS Company,
	|	JobSheetOperations.Ref.StructuralUnit AS StructuralUnit,
	|	JobSheetOperations.Ref.Performer AS Performer,
	|	JobSheetOperations.Operation AS Operation,
	|	JobSheetOperations.Products AS Products,
	|	JobSheetOperations.Characteristic AS Characteristic,
	|	JobSheetOperations.SalesOrder AS SalesOrder,
	|	JobSheetOperations.StandardHours AS StandardHours,
	|	CASE
	|		WHEN VALUETYPE(JobSheetOperations.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN JobSheetOperations.QuantityPlan
	|		ELSE JobSheetOperations.QuantityPlan * JobSheetOperations.MeasurementUnit.Factor
	|	END AS QuantityPlan,
	|	CASE
	|		WHEN VALUETYPE(JobSheetOperations.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN JobSheetOperations.QuantityFact
	|		ELSE JobSheetOperations.QuantityFact * JobSheetOperations.MeasurementUnit.Factor
	|	END AS QuantityFact
	|FROM
	|	Document.JobSheet.Operations AS JobSheetOperations
	|WHERE
	|	JobSheetOperations.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableOfOperations.LineNumber) AS LineNumber,
	|	TableOfOperations.RecordType AS RecordType,
	|	TableOfOperations.ClosingDate AS Period,
	|	TableOfOperations.Company AS Company,
	|	TableOfOperations.PresentationCurrency AS PresentationCurrency,
	|	TableOfOperations.StructuralUnit AS StructuralUnit,
	|	TableOfOperations.StructuralUnit AS StructuralUnitCorr,
	|	TableOfOperations.InventoryGLAccount AS GLAccount,
	|	TableOfOperations.CorrespondentAccountAccountingInventory AS CorrGLAccount,
	|	TableOfOperations.ProductsCorr AS ProductsCorr,
	|	TableOfOperations.CharacteristicCorr AS CharacteristicCorr,
	|	TableOfOperations.BatchCorr AS BatchCorr,
	|	TableOfOperations.SpecificationCorr AS SpecificationCorr,
	|	VALUE(Catalog.Products.EmptyRef) AS Products,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS Specification,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	CASE
	|		WHEN TableOfOperations.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableOfOperations.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableOfOperations.SalesOrder
	|	END AS SalesOrder,
	|	CASE
	|		WHEN TableOfOperations.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableOfOperations.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableOfOperations.SalesOrder
	|	END AS CustomerCorrOrder,
	|	SUM(TableOfOperations.Amount) AS Amount,
	|	TRUE AS FixedCost,
	|	FALSE AS ProductionExpenses,
	|	VALUE(AccountingRecordType.Debit) AS RecordKindAccountingJournalEntries,
	|	TableOfOperations.ContentOfAccountingRecord AS ContentOfAccountingRecord
	|FROM
	|	TableOfOperations AS TableOfOperations
	|WHERE
	|	TableOfOperations.Closed
	|
	|GROUP BY
	|	TableOfOperations.InventoryGLAccount,
	|	TableOfOperations.CorrespondentAccountAccountingInventory,
	|	TableOfOperations.ProductsCorr,
	|	TableOfOperations.CharacteristicCorr,
	|	TableOfOperations.BatchCorr,
	|	TableOfOperations.ContentOfAccountingRecord,
	|	TableOfOperations.Company,
	|	TableOfOperations.StructuralUnit,
	|	TableOfOperations.SalesOrder,
	|	TableOfOperations.SpecificationCorr,
	|	TableOfOperations.ClosingDate,
	|	TableOfOperations.RecordType,
	|	TableOfOperations.PresentationCurrency,
	|	TableOfOperations.StructuralUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableOfOperations.LineNumber AS LineNumber,
	|	TableOfOperations.ClosingDate AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableOfOperations.InventoryGLAccount AS AccountDr,
	|	CASE
	|		WHEN TableOfOperations.InventoryGLAccount.Currency
	|			THEN TableOfOperations.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableOfOperations.InventoryGLAccount.Currency
	|			THEN TableOfOperations.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	TableOfOperations.GLAccount AS AccountCr,
	|	CASE
	|		WHEN TableOfOperations.GLAccount.Currency
	|			THEN TableOfOperations.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableOfOperations.GLAccount.Currency
	|			THEN TableOfOperations.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	TableOfOperations.Amount AS Amount,
	|	&Payroll AS Content
	|FROM
	|	TableOfOperations AS TableOfOperations
	|WHERE
	|	TableOfOperations.Amount > 0
	|	AND TableOfOperations.Closed
	|
	|UNION ALL
	|
	|SELECT
	|	TableOfOperations.LineNumber,
	|	TableOfOperations.ClosingDate,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableOfOperations.CorrespondentAccountAccountingInventory,
	|	CASE
	|		WHEN TableOfOperations.CorrespondentAccountAccountingInventory.Currency
	|			THEN TableOfOperations.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableOfOperations.CorrespondentAccountAccountingInventory.Currency
	|			THEN TableOfOperations.AmountCur
	|		ELSE 0
	|	END,
	|	TableOfOperations.InventoryGLAccount,
	|	CASE
	|		WHEN TableOfOperations.InventoryGLAccount.Currency
	|			THEN TableOfOperations.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableOfOperations.InventoryGLAccount.Currency
	|			THEN TableOfOperations.AmountCur
	|		ELSE 0
	|	END,
	|	TableOfOperations.Amount,
	|	&SalaryDistribution
	|FROM
	|	TableOfOperations AS TableOfOperations
	|WHERE
	|	TableOfOperations.Amount > 0
	|	AND TableOfOperations.Closed";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",					DocumentRefJobSheet);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",  StructureAdditionalProperties.ForPosting.PresentationCurrency);	
	Query.SetParameter("Payroll",				NStr("en = 'Payroll'; ru = 'Начисление зарплаты';pl = 'Lista płac';es_ES = 'Nómina';es_CO = 'Nómina';tr = 'Bordro';it = 'Stipendi';de = 'Personal'", MainLanguageCode));
	Query.SetParameter("SalaryDistribution",	NStr("en = 'Attribution of expenses for products'; ru = 'Отнесение затрат на продукцию';pl = 'Przydział kosztów na produkcję';es_ES = 'Atribución de gastos para productos';es_CO = 'Atribución de gastos para productos';tr = 'Ürünler için giderlerin itfa edilmesi';it = 'L''attribuzione delle spese per prodotti';de = 'Zuordnung von Ausgaben für Produkte'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",    StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	// FO Use Payroll subsystem.
	Query.SetParameter("UsePayrollSubsystem", Constants.UsePayrollSubsystem.Get());
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableEarningsAndDeductions"   , ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePayroll"                 , ResultsArray[4].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableWorkload"                , ResultsArray[5].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryOperations"     , ResultsArray[6].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[7].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory"               , StructureAdditionalProperties.TableForRegisterRecords.TableInventoryOperations.CopyColumns());
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	If UseDefaultTypeOfAccounting Then
		EmptyAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	EndIf;
	
	IsEmptyStructuralUnit    = Catalogs.BusinessUnits.EmptyRef();EmptyProducts            = Catalogs.Products.EmptyRef();
	EmptyCharacteristic      = Catalogs.ProductsCharacteristics.EmptyRef();
	EmptyBatch               = Catalogs.ProductsBatches.EmptyRef();
	EmptySalesOrder          = Undefined;
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryOperations.Count() - 1 Do
		
		RowTableInventoryOperations = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryOperations[n];
		
		// Credit payroll costs in the StatementOfCost.
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventoryOperations);
		
		TableRowReceipt.StructuralUnitCorr    = IsEmptyStructuralUnit;
		TableRowReceipt.ProductsCorr          = EmptyProducts;
		TableRowReceipt.CharacteristicCorr    = EmptyCharacteristic;
		TableRowReceipt.BatchCorr             = EmptyBatch;
		TableRowReceipt.CustomerCorrOrder     = EmptySalesOrder;
		
		If UseDefaultTypeOfAccounting Then 
			TableRowReceipt.CorrGLAccount = EmptyAccount;
		EndIf;
		
		// We will write off them on production.
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowExpense, RowTableInventoryOperations);
		TableRowExpense.RecordType                         = AccumulationRecordType.Expense;
		TableRowExpense.RecordKindAccountingJournalEntries = AccountingRecordType.Credit;
		TableRowExpense.FixedCost                          = False;
		TableRowExpense.ProductionExpenses                 = True;
		
		// Include in the product cost.
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventoryOperations);
		
		TableRowReceipt.StructuralUnit     = RowTableInventoryOperations.StructuralUnitCorr;
		TableRowReceipt.GLAccount          = RowTableInventoryOperations.CorrGLAccount;
		TableRowReceipt.Products           = RowTableInventoryOperations.ProductsCorr;
		TableRowReceipt.Characteristic     = RowTableInventoryOperations.CharacteristicCorr;
		TableRowReceipt.Batch              = RowTableInventoryOperations.BatchCorr;
		TableRowReceipt.SalesOrder         = RowTableInventoryOperations.CustomerCorrOrder;
		
		TableRowReceipt.StructuralUnitCorr = RowTableInventoryOperations.StructuralUnit;
		TableRowReceipt.CorrGLAccount      = RowTableInventoryOperations.GLAccount;
		TableRowReceipt.ProductsCorr       = RowTableInventoryOperations.Products;
		TableRowReceipt.CharacteristicCorr = RowTableInventoryOperations.Characteristic;
		TableRowReceipt.BatchCorr          = RowTableInventoryOperations.Batch;
		TableRowReceipt.CustomerCorrOrder  = RowTableInventoryOperations.SalesOrder;
		
		TableRowReceipt.FixedCost = False;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryOperations");
	
	FinancialAccounting.FillExtraDimensions(DocumentRefJobSheet, StructureAdditionalProperties);
	
EndProcedure

#Region LibrariesHandlers

#Region PrintInterface

// Function generates document printing form by specified layout.
//
// Parameters:
// SpreadsheetDocument - TabularDocument in which
// 			   printing form will be displayed.
//  TemplateName    - String, printing form layout name.
//
Function PrintForm(ObjectsArray, PrintObjects, PrintParams = Undefined)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	FirstDocument = True;
	
	For Each CurrentDocument In ObjectsArray Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query();
		
		Query.SetParameter("Company", 		DriveServer.GetCompany(CurrentDocument.Company));
		Query.SetParameter("CurrentDocument", 	CurrentDocument);
		
		Query.Text = 
		"SELECT ALLOWED
		|	JobSheet.Ref AS Ref,
		|	JobSheet.DataVersion,
		|	JobSheet.DeletionMark,
		|	JobSheet.Number,
		|	JobSheet.Date AS DocumentDate,
		|	JobSheet.Posted,
		|	JobSheet.Company,
		|	JobSheet.StructuralUnit,
		|	JobSheet.Performer,
		|	JobSheet.Comment,
		|	JobSheet.DocumentCurrency,
		|	JobSheet.DocumentAmount,
		|	JobSheet.Author,
		|	JobSheet.Closed,
		|	JobSheet.ClosingDate
		|FROM
		|	Document.JobSheet AS JobSheet
		|WHERE
		|	JobSheet.Ref = &CurrentDocument
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	JobSheetOperations.Ref,
		|	JobSheetOperations.LineNumber,
		|	JobSheetOperations.Period AS Day,
		|	JobSheetOperations.SalesOrder,
		|	JobSheetOperations.Products,
		|	JobSheetOperations.Products.Code AS Code,
		|	JobSheetOperations.Products.SKU AS SKU,
		|	JobSheetOperations.Characteristic,
		|	JobSheetOperations.Operation,
		|	JobSheetOperations.MeasurementUnit,
		|	JobSheetOperations.QuantityPlan AS QuantityPlan,
		|	JobSheetOperations.QuantityFact AS QuantityFact,
		|	JobSheetOperations.TimeNorm,
		|	JobSheetOperations.Tariff,
		|	JobSheetOperations.StandardHours AS StandardHours,
		|	JobSheetOperations.Cost AS Cost,
		|	JobSheetOperations.Batch,
		|	JobSheetOperations.Specification
		|FROM
		|	Document.JobSheet.Operations AS JobSheetOperations
		|WHERE
		|	JobSheetOperations.Ref = &CurrentDocument
		|
		|ORDER BY
		|	JobSheetOperations.Period
		|TOTALS
		|	SUM(QuantityPlan),
		|	SUM(QuantityFact),
		|	SUM(StandardHours),
		|	SUM(Cost)
		|BY
		|	Day";
		
		// MultilingualSupport
		
		If PrintParams = Undefined Then
			LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
		Else
			LanguageCode = PrintParams.LanguageCode;
		EndIf;
		
		If LanguageCode <> CurrentLanguage().LanguageCode Then 
			SessionParameters.LanguageCodeForOutput = LanguageCode;
		EndIf;
		
		DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
		
		// End MultilingualSupport
		
		QueryResult	= Query.ExecuteBatch();
		Header 				= QueryResult[0].Select();
		Header.Next();
		
		SelectionDays			=QueryResult[1].Select(QueryResultIteration.ByGroups);
		
		Template = PrintManagement.PrintFormTemplate("Document.JobSheet.Template", LanguageCode);
		
		RegHeader		= Template.GetArea("Header");
		OblTableHeader	= Template.GetArea("TableHeader");
		AreDey			= Template.GetArea("Day");
		RegionDetails		= Template.GetArea("Details");
		RegionFooter		= Template.GetArea("Footer");
		
		RegHeader.Parameters.Fill(Header);
		RegHeader.Parameters.DocumentTitle = "Job sheet # " + Header.Number + " dated " + Format(Header.DocumentDate, "DLF=DD");
		SpreadsheetDocument.Put(RegHeader);
		
		OblTableHeader.Parameters.Cost = "Cost (" + Header.DocumentCurrency + ")";
		SpreadsheetDocument.Put(OblTableHeader);
		
		NPP = 0;
		
		While SelectionDays.Next() Do
			
			AreDey.Parameters.Fill(SelectionDays);
			SpreadsheetDocument.Put(AreDey);
			
			SelectionOperations = SelectionDays.Select();
			While SelectionOperations.Next() Do
				
				NPP = NPP + 1;
				
				RegionDetails.Parameters.Fill(SelectionOperations);
				RegionDetails.Parameters.NPP = NPP;
				
				SpreadsheetDocument.Put(RegionDetails);
				
			EndDo;
			
		EndDo;
		
		RegionFooter.Parameters.Cost = Header.DocumentAmount;
		SpreadsheetDocument.Put(RegionFooter);
		
	EndDo;
	
	SpreadsheetDocument.PageOrientation = PageOrientation.Landscape;
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "JobSheet") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"JobSheet",
			NStr("en = 'Job sheet'; ru = 'Сдельный наряд';pl = 'Karta zadań';es_ES = 'Hoja de tarea';es_CO = 'Hoja de tarea';tr = 'İş çizelgesi';it = 'Foglio di lavoro';de = 'Arbeitszettel'"),
			PrintForm(ObjectsArray, PrintObjects, PrintParameters.Result));
		
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "JobSheet";
	PrintCommand.Presentation = NStr("en = 'Job sheet'; ru = 'Сдельный  наряд';pl = 'Karta zadań';es_ES = 'Hoja de tarea';es_CO = 'Hoja de tarea';tr = 'İş çizelgesi';it = 'Foglio di lavoro';de = 'Arbeitsblatt'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#EndIf