#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefTaxAccrual, StructureAdditionalProperties) Export
	
	Query = New Query(
	"SELECT
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordType,
	|	TaxAccrual.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.TaxKind AS TaxKind,
	|	TaxAccrual.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentTable.Amount AS Amount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|			THEN &AddedTax
	|		ELSE &RecoveredTax
	|	END AS ContentOfAccountingRecord
	|FROM
	|	Document.TaxAccrual.Taxes AS DocumentTable
	|		INNER JOIN Document.TaxAccrual AS TaxAccrual
	|		ON DocumentTable.Ref = TaxAccrual.Ref
	|WHERE
	|	DocumentTable.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Ref.Date AS Period,
	|	CASE
	|		WHEN DocumentTable.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|				OR DocumentTable.IncomeItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|			THEN VALUE(Catalog.LinesOfBusiness.Other)
	|		ELSE DocumentTable.BusinessLine
	|	END AS BusinessLine,
	|	CASE
	|		WHEN DocumentTable.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|				OR DocumentTable.IncomeItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|			THEN VALUE(Catalog.BusinessUnits.EmptyRef)
	|		ELSE DocumentTable.Department
	|	END AS StructuralUnit,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|			THEN DocumentTable.ExpenseItem
	|		ELSE DocumentTable.IncomeItem
	|	END AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN DocumentTable.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|				OR DocumentTable.IncomeItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|				OR DocumentTable.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR DocumentTable.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.SalesOrder
	|	END AS SalesOrder,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|			THEN &Expenses
	|		ELSE &Incomings
	|	END AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|			THEN 0
	|		ELSE DocumentTable.Amount
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.TaxAccrual.Taxes AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND CASE
	|			WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|				THEN DocumentTable.ExpenseItem.IncomeAndExpenseType IN (VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses), VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses), VALUE(Catalog.IncomeAndExpenseTypes.Revenue))
	|			ELSE DocumentTable.IncomeItem.IncomeAndExpenseType IN (VALUE(Catalog.IncomeAndExpenseTypes.Revenue), VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome))
	|		END
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|				AND DocumentTable.RegisterExpense
	|			OR DocumentTable.Ref.OperationKind <> VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|				AND DocumentTable.RegisterIncome)
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.Period,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.AmountExpense,
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
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|						THEN DocumentTable.Correspondence
	|					ELSE DocumentTable.TaxKind.GLAccountForReimbursement
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|						THEN DocumentTable.TaxKind.GLAccount
	|					ELSE DocumentTable.Correspondence
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	DocumentTable.Amount AS Amount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|			THEN &AddedTax
	|		ELSE &RecoveredTax
	|	END AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.TaxAccrual.Taxes AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
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
	|	DocumentTable.LineNumber AS LineNumber,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordType,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Department AS StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN DocumentTable.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR DocumentTable.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.SalesOrder
	|	END AS SalesOrder,
	|	&OwnInventory AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads) AS InventoryAccountType,
	|	DocumentTable.Amount AS Amount,
	|	TRUE AS FixedCost,
	|	&AddedTax AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.TaxAccrual.Taxes AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.Ownership,
	|	OfflineRecords.CostObject,
	|	OfflineRecords.InventoryAccountType,
	|	OfflineRecords.Amount,
	|	OfflineRecords.FixedCost,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord");
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", 					DocumentRefTaxAccrual);
	Query.SetParameter("PointInTime", 			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", 				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AddedTax", 				NStr("en = 'Tax accrued'; ru = 'Начисленные налоги';pl = 'Naliczone podatki';es_ES = 'Impuesto acumulado';es_CO = 'Impuesto acumulado';tr = 'Tahakkuk edilen vergi';it = 'Imposte maturate';de = 'Steuern angefallen'", MainLanguageCode));
	Query.SetParameter("RecoveredTax", 			NStr("en = 'Tax reimbursed'; ru = 'Возмещен налог';pl = 'Zwrot podatku';es_ES = 'Impuesto reembolsado';es_CO = 'Impuesto reembolsado';tr = 'Geri ödenmiş vergi';it = 'Imposte rimborsate';de = 'Steuer erstattet'", MainLanguageCode));
	Query.SetParameter("Incomings", 			NStr("en = 'Income'; ru = 'Доходы';pl = 'Dochody';es_ES = 'Ingreso';es_CO = 'Ingreso';tr = 'Gelir';it = 'Entrate';de = 'Einnahme'", MainLanguageCode));
	Query.SetParameter("Expenses", 				NStr("en = 'Expenses'; ru = 'Расходы';pl = 'Rozchody';es_ES = 'Gastos';es_CO = 'Gastos';tr = 'Masraflar';it = 'Spese';de = 'Ausgaben'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency",	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("OwnInventory",			Catalogs.InventoryOwnership.OwnInventory());
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxPayable", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[3].Unload());
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[2].Unload());
	EndIf;
	
	GenerateTableAccountingEntriesData(DocumentRefTaxAccrual, StructureAdditionalProperties);
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefTaxAccrual, StructureAdditionalProperties);
	
	FinancialAccounting.FillExtraDimensions(DocumentRefTaxAccrual, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefTaxAccrual, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefTaxAccrual, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Internal
#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Taxes" Then
		If StructureData.ObjectParameters.OperationKind = Enums.OperationTypesTaxAccrual.Accrual Then
			IncomeAndExpenseStructure.Insert("ExpenseItem", StructureData.ExpenseItem);
			IncomeAndExpenseStructure.Insert("RegisterExpense", StructureData.RegisterExpense);
		Else
			IncomeAndExpenseStructure.Insert("IncomeItem", StructureData.IncomeItem);
			IncomeAndExpenseStructure.Insert("RegisterIncome", StructureData.RegisterIncome);
		EndIf;
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "Taxes" Then
		If StructureData.ObjectParameters.OperationKind = Enums.OperationTypesTaxAccrual.Accrual Then
			Result.Insert("Correspondence", "ExpenseItem");
			
			Array = New Array;
			Array.Add("RegisterIncome");
			Array.Add("IncomeItem");
			Result.Insert("Clear", Array);
		Else
			Result.Insert("Correspondence", "IncomeItem");
			
			Array = New Array;
			Array.Add("RegisterExpense");
			Array.Add("ExpenseItem");
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

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);
	
EndProcedure

#EndRegion 

#EndIf