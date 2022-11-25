#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataCashBudget(DocumentRefBudget, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCashBudget", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",					DocumentRefBudget);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("IncomeContent",			NStr("en = 'Forecast of funds receipt'; ru = 'Прогноз поступления денежных средств';pl = 'Prognoza wpływu środków pieniężnych';es_ES = 'Pronóstico del recibo de fondos';es_CO = 'Pronóstico del recibo de fondos';tr = 'Nakit fişlerin tahmini';it = 'Previsione di fondi ricezione';de = 'Prognose des Geldeingangs'", MainLanguageCode));
	Query.SetParameter("ExpenceContent",		NStr("en = 'Forecast of funds outflow'; ru = 'Прогноз выбытия денежных средств';pl = 'Prognoza odpływu środków pieniężnych';es_ES = 'Pronóstico de la salida de fondos';es_CO = 'Pronóstico de la salida de fondos';tr = 'Nakit çıkışı tahmini';it = 'Previsione del deflusso di fondi';de = 'Prognose des Mittelabflusses'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Account AS GLAccount,
	|	&PresentationCurrency AS Currency,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.Amount AS AmountReceiptCur,
	|	DocumentTable.Amount AS AmountReceipt,
	|	0 AS AmountExpenseCur,
	|	0 AS AmountExpense,
	|	&IncomeContent AS ContentOfAccountingRecord
	|FROM
	|	Document.Budget.Receipts AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Account,
	|	&PresentationCurrency,
	|	DocumentTable.Item,
	|	0,
	|	0,
	|	DocumentTable.Amount,
	|	DocumentTable.Amount,
	|	&ExpenceContent
	|FROM
	|	Document.Budget.Disposal AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|ORDER BY
	|	LineNumber";
	
	Result = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCashBudget", Result);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataIncomeAndExpensesBudget(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",				DocumentRefBudget);
	Query.SetParameter("Company",			StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeContent",		NStr("en = 'Income forecast'; ru = 'Прогноз доходов';pl = 'Prognoza dochodów';es_ES = 'Pronóstico de ingresos';es_CO = 'Pronóstico de ingresos';tr = 'Gelir tahmini';it = 'Previsione ricavi';de = 'Einnahmeprognose'", MainLanguageCode));
	Query.SetParameter("ExpenceContent",	NStr("en = 'Expense forecast'; ru = 'Прогноз расходов';pl = 'Prognoza rozchodów';es_ES = 'Pronóstico de gastos';es_CO = 'Pronóstico de gastos';tr = 'Gider tahmini';it = 'Previsione spese';de = 'Ausgabenprognose'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	CASE
	|		WHEN DocumentTable.IncomeItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.StructuralUnit
	|	END AS StructuralUnit,
	|	CASE
	|		WHEN DocumentTable.IncomeItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|			THEN VALUE(Catalog.LinesOfBusiness.Other)
	|		ELSE DocumentTable.BusinessLine
	|	END AS BusinessLine,
	|	CASE
	|		WHEN DocumentTable.IncomeItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.SalesOrder
	|	END AS SalesOrder,
	|	DocumentTable.IncomeItem AS IncomeAndExpenseItem,
	|	DocumentTable.Account AS GLAccount,
	|	DocumentTable.Amount AS AmountIncome,
	|	0 AS AmountExpense,
	|	&IncomeContent AS ContentOfAccountingRecord
	|FROM
	|	Document.Budget.Incomings AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	CASE
	|		WHEN DocumentTable.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.StructuralUnit
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|			THEN VALUE(Catalog.LinesOfBusiness.Other)
	|		ELSE DocumentTable.BusinessLine
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.SalesOrder
	|	END,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.Account,
	|	0,
	|	DocumentTable.Amount,
	|	&ExpenceContent
	|FROM
	|	Document.Budget.Expenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	Result = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesBudget", Result);
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataDirectCost(DocumentRefBudget, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.Account AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.CorrAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS String(100)) AS Content
	|FROM
	|	Document.Budget.DirectCost AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Amount,
	|	DocumentTable.Account.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	DocumentTable.Account,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	CAST(&DistributionOfDirectCost AS String(100))
	|FROM
	|	Document.Budget.DirectCost AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Amount,
	|	DocumentTable.Account.ClosingAccount.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	DocumentTable.Account.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	CAST(&TransferOfFinishedProducts AS String(100))
	|FROM
	|	Document.Budget.DirectCost AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Account.ClosingAccount.ClosingAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)");
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",							DocumentRefBudget);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("DistributionOfDirectCost",		NStr("en = 'Direct costs allocating'; ru = 'Распределение прямых затрат';pl = 'Bezpośredni podział kosztu własnego';es_ES = 'Asignación de los costes directos';es_CO = 'Asignación de los costes directos';tr = 'Doğrudan maliyet tahsisi';it = 'Allocazione costi diretti';de = 'Zuordnung der direkten Kosten'", MainLanguageCode));
	Query.SetParameter("TransferOfFinishedProducts",	NStr("en = 'Finished products delivery'; ru = 'Выполнена доставка товаров';pl = 'Dostawa gotowych produktów';es_ES = 'Entrega de productos acabados';es_CO = 'Entrega de productos acabados';tr = 'Bitmiş ürün teslimatı';it = 'Consegna prodotti finiti';de = 'Lieferung der fertigen Produkte'", MainLanguageCode));
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataIndirectExpenses(DocumentRefBudget, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.Account AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.CorrAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS String(100)) AS Content
	|FROM
	|	Document.Budget.IndirectExpenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Amount,
	|	DocumentTable.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	DocumentTable.Account,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	CAST(&DistributionOfIndirectCost AS String(100))
	|FROM
	|	Document.Budget.IndirectExpenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Amount,
	|	DocumentTable.Account.ClosingAccount.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	DocumentTable.Account.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	CAST(&DistributionOfDirectCost AS String(100))
	|FROM
	|	Document.Budget.IndirectExpenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Account.ClosingAccount.ClosingAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Amount,
	|	DocumentTable.Account.ClosingAccount.ClosingAccount.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.ClosingAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	DocumentTable.Account.ClosingAccount.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	CAST(&TransferOfFinishedProducts AS String(100))
	|FROM
	|	Document.Budget.IndirectExpenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Account.ClosingAccount.ClosingAccount.ClosingAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)");
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",							DocumentRefBudget);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("DistributionOfIndirectCost",	NStr("en = 'Indirect costs allocating'; ru = 'Распределение непрямых затрат';pl = 'Pośredni podział kosztu własnego';es_ES = 'Asignación de los costes indirectos';es_CO = 'Asignación de los costes indirectos';tr = 'Dolaylı maliyet tahsisi';it = 'Allocazione costi indiretti';de = 'Zuordnung der indirekten Kosten'", MainLanguageCode));
	Query.SetParameter("DistributionOfDirectCost",		NStr("en = 'Direct costs allocating'; ru = 'Распределение прямых затрат';pl = 'Bezpośredni podział kosztu własnego';es_ES = 'Asignación de los costes directos';es_CO = 'Asignación de los costes directos';tr = 'Doğrudan maliyet tahsisi';it = 'Allocazione costi diretti';de = 'Zuordnung der direkten Kosten'", MainLanguageCode));
	Query.SetParameter("TransferOfFinishedProducts",	NStr("en = 'Finished products delivery'; ru = 'Выполнена доставка товаров';pl = 'Dostawa gotowych produktów';es_ES = 'Entrega de productos acabados';es_CO = 'Entrega de productos acabados';tr = 'Bitmiş ürün teslimatı';it = 'Consegna prodotti finiti';de = 'Lieferung der fertigen Produkte'", MainLanguageCode));
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataExpenses(DocumentRefBudget, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.Account AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.CorrAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS String(100)) AS Content
	|FROM
	|	Document.Budget.Expenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref");
	
	Query.SetParameter("Ref"                 , DocumentRefBudget);
	Query.SetParameter("Company"             , StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataIncome(DocumentRefBudget, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.CorrAccount AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.Account AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS String(100)) AS Content
	|FROM
	|	Document.Budget.Incomings AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref");
	
	Query.SetParameter("Ref"                 , DocumentRefBudget);
	Query.SetParameter("Company"             , StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataOutflows(DocumentRefBudget, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.CorrAccount AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.Account AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS String(100)) AS Content
	|FROM
	|	Document.Budget.Disposal AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref");
	
	Query.SetParameter("Ref"                 , DocumentRefBudget);
	Query.SetParameter("Company"             , StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataReceipts(DocumentRefBudget, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.Account AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.CorrAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS String(100)) AS Content
	|FROM
	|	Document.Budget.Receipts AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref");
	
	Query.SetParameter("Ref"                 , DocumentRefBudget);
	Query.SetParameter("Company"             , StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataAccountingRecords(DocumentRefBudget, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.AccountDr AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.AccountDr.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.AccountDr.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.AccountCr AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.AccountCr.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.AccountCr.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS STRING(100)) AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.Budget.Operations AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref");
	
	Query.SetParameter("Ref"                 , DocumentRefBudget);
	Query.SetParameter("Company"             , StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataBalances(DocumentRefBudget, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	DATEADD(DocumentTable.Ref.PlanningPeriod.StartDate, Second, -1) AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	&OBEAccount AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	DocumentTable.Account AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(&Content AS String(100)) AS Content
	|FROM
	|	Document.Budget.Balance AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Account.TypeOfAccount IN(&CreditAccountTypes)
	|
	|UNION ALL
	|
	|SELECT
	|	DATEADD(DocumentTable.Ref.PlanningPeriod.StartDate, Second, -1),
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Amount,
	|	DocumentTable.Account,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	&OBEAccount,
	|	UNDEFINED,
	|	0,
	|	CAST(&Content AS String(100))
	|FROM
	|	Document.Budget.Balance AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Account.TypeOfAccount IN(&DebetAccountTypes)");
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("OBEAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OpeningBalanceEquity"));
	Query.SetParameter("Ref",					DocumentRefBudget);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",  StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("Content",				NStr("en = 'Opening balance forecast'; ru = 'Прогноз начальных остатков';pl = 'Prognoza salda początkowego';es_ES = 'Pronóstico del saldo de apertura';es_CO = 'Pronóstico del saldo de apertura';tr = 'Açılış bakiyesi tahmini';it = 'Previsione dei saldi iniziali';de = 'Anfangssaldo-Prognose'", MainLanguageCode));
	
	DebetAccountTypes = New ValueList;
	DebetAccountTypes.Add(Enums.GLAccountsTypes.FixedAssets);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.AccountsReceivable);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.CashAndCashEquivalents);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.Inventory);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.IndirectExpenses);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.ShorttermInvestments);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.WorkInProgress);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.OtherFixedAssets);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.OtherCurrentAssets);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.OtherExpenses);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.Expenses);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.CostOfSales);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.LoanInterest);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.IncomeTax);
	
	CreditAccountTypes = New ValueList;
	CreditAccountTypes.Add(Enums.GLAccountsTypes.Depreciation);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.LongtermLiabilities);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.Revenue);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.Capital);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.AccountsPayable);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.LoansBorrowed);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.RetainedEarnings);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.ProfitLosses);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.OtherIncome);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.OtherShorttermObligations);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.ReserveAndAdditionalCapital);
	
	Query.SetParameter("DebetAccountTypes", DebetAccountTypes);
	Query.SetParameter("CreditAccountTypes", CreditAccountTypes);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Generates allocation base table.
//
// Parameters:
// DistributionBase - Enums.CostAllocationMethod
// GLAccountsArray - Array containing filter by
// GL accounts FilterByStructuralUnit - filer by
// structural units FilterByOrder - Filter by goods orders
//
// Returns:
//  ValuesTable containing allocation base.
//
Function GenerateFinancialResultDistributionBaseTable(DistributionBase, PlanningPeriod, StartDate, EndDate, FilterByStructuralUnit, FilterByBusinessLine, FilterByOrder, AdditionalProperties)
	
	ResultTable = New ValueTable;
	
	If DistributionBase = Enums.CostAllocationMethod.SalesVolume Then
		
		QueryText = 
		"SELECT
		|	SalesTurnovers.Company AS Company,
		|	CatalogLinesOfBusiness.Ref AS BusinessLine,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN CatalogLinesOfBusiness.GLAccountRevenueFromSales
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END AS GLAccountRevenueFromSales,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN CatalogLinesOfBusiness.GLAccountCostOfSales
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END AS GLAccountCostOfSales,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN CatalogLinesOfBusiness.ProfitGLAccount
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END AS ProfitGLAccount,
		|	SalesTurnovers.StructuralUnit AS StructuralUnit,
		|	SalesTurnovers.QuantityTurnover AS Base
		|FROM
		|	AccumulationRegister.SalesTarget.Turnovers(
		|			&StartDate,
		|			&EndDate,
		|			Auto,
		|			Company = &Company
		|				AND &FilterByStructuralUnit
		|				AND &FilterByBusinessLine) AS SalesTurnovers
		|		INNER JOIN Catalog.Products AS CatalogProducts
		|			INNER JOIN Catalog.LinesOfBusiness AS CatalogLinesOfBusiness
		|			ON CatalogProducts.BusinessLine = CatalogLinesOfBusiness.Ref
		|		ON SalesTurnovers.Products = CatalogProducts.Ref";
		
		QueryText = StrReplace(QueryText, "&FilterByStructuralUnit", ?(ValueIsFilled(FilterByStructuralUnit), "StructuralUnit IN (&BusinessUnitsArray)", "TRUE"));
		QueryText = StrReplace(QueryText, "&FilterByBusinessLine", ?(ValueIsFilled(FilterByBusinessLine), "Products.BusinessLine IN (&BusinessLinesArray)", "TRUE"));
		
	ElsIf DistributionBase = Enums.CostAllocationMethod.SalesRevenue Then
		
		QueryText = 
		"SELECT
		|	&Company AS Company,
		|	Budget.BusinessLine AS BusinessLine,
		|	Budget.SalesOrder AS Order,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN Budget.BusinessLine.GLAccountRevenueFromSales
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END AS GLAccountRevenueFromSales,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN Budget.BusinessLine.GLAccountCostOfSales
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END AS GLAccountCostOfSales,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN Budget.BusinessLine.ProfitGLAccount
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END AS ProfitGLAccount,
		|	Budget.StructuralUnit AS StructuralUnit,
		|	Budget.Amount AS Base
		|FROM
		|	Document.Budget.Incomings AS Budget
		|		INNER JOIN Catalog.IncomeAndExpenseItems AS IncomeAndExpenseItems
		|		ON Budget.IncomeItem = IncomeAndExpenseItems.Ref
		|			AND (IncomeAndExpenseItems.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.Revenue))
		|WHERE
		|	Budget.Ref = &Ref
		|	AND Budget.PlanningDate BETWEEN &StartDate AND &EndDate
		|	AND &FilterByStructuralUnit
		|	AND &FilterByBusinessLine
		|	AND &FilterByOrder";
		
		QueryText = StrReplace(QueryText, "&FilterByStructuralUnit", ?(ValueIsFilled(FilterByStructuralUnit), "Budget.StructuralUnit IN (&BusinessUnitsArray)", "TRUE"));
		QueryText = StrReplace(QueryText, "&FilterByBusinessLine", ?(ValueIsFilled(FilterByBusinessLine), "Budget.BusinessLine IN (&BusinessLinesArray)", "TRUE"));
		QueryText = StrReplace(QueryText, "&FilterByOrder", ?(ValueIsFilled(FilterByOrder), "Budget.SalesOrder IN (&OdersArray)", "TRUE"));
		
	ElsIf DistributionBase = Enums.CostAllocationMethod.CostOfGoodsSold Then
		
		QueryText = 
		"SELECT
		|	&Company AS Company,
		|	Budget.BusinessLine AS BusinessLine,
		|	Budget.SalesOrder AS Order,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN Budget.BusinessLine.GLAccountRevenueFromSales
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END AS GLAccountRevenueFromSales,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN Budget.BusinessLine.GLAccountCostOfSales
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END AS GLAccountCostOfSales,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN Budget.BusinessLine.ProfitGLAccount
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END AS ProfitGLAccount,
		|	Budget.StructuralUnit AS StructuralUnit,
		|	Budget.Amount AS Base
		|FROM
		|	Document.Budget.Expenses AS Budget
		|		INNER JOIN Catalog.IncomeAndExpenseItems AS IncomeAndExpenseItems
		|		ON Budget.ExpenseItem = IncomeAndExpenseItems.Ref
		|			AND (IncomeAndExpenseItems.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales))
		|WHERE
		|	Budget.Ref = &Ref
		|	AND Budget.PlanningDate BETWEEN &StartDate AND &EndDate
		|	AND &FilterByStructuralUnit
		|	AND &FilterByBusinessLine
		|	AND &FilterByOrder";
		
		QueryText = StrReplace(QueryText, "&FilterByStructuralUnit", ?(ValueIsFilled(FilterByStructuralUnit), "Budget.StructuralUnit IN (&BusinessUnitsArray)", "TRUE"));
		QueryText = StrReplace(QueryText, "&FilterByBusinessLine", ?(ValueIsFilled(FilterByBusinessLine), "Budget.BusinessLine IN (&BusinessLinesArray)", "TRUE"));
		QueryText = StrReplace(QueryText, "&FilterByOrder", ?(ValueIsFilled(FilterByOrder), "Budget.SalesOrder IN (&OdersArray)", "TRUE"));
		
	ElsIf DistributionBase = Enums.CostAllocationMethod.GrossProfit Then
		
		QueryText =
		"SELECT
		|	Table.Company AS Company,
		|	Table.BusinessLine AS BusinessLine,
		|	Table.Order AS Order,
		|	Table.GLAccountRevenueFromSales AS GLAccountRevenueFromSales,
		|	Table.GLAccountCostOfSales AS GLAccountCostOfSales,
		|	Table.ProfitGLAccount AS ProfitGLAccount,
		|	Table.StructuralUnit AS StructuralUnit,
		|	SUM(Table.Base) AS Base
		|FROM
		|	(SELECT
		|		&Company AS Company,
		|		Budget.BusinessLine AS BusinessLine,
		|		Budget.SalesOrder AS Order,
		|		CASE
		|			WHEN &UseDefaultTypeOfAccounting
		|				THEN Budget.BusinessLine.GLAccountRevenueFromSales
		|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|		END AS GLAccountRevenueFromSales,
		|		CASE
		|			WHEN &UseDefaultTypeOfAccounting
		|				THEN Budget.BusinessLine.GLAccountCostOfSales
		|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|		END AS GLAccountCostOfSales,
		|		CASE
		|			WHEN &UseDefaultTypeOfAccounting
		|				THEN Budget.BusinessLine.ProfitGLAccount
		|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|		END AS ProfitGLAccount,
		|		Budget.StructuralUnit AS StructuralUnit,
		|		Budget.Amount AS Base
		|	FROM
		|		Document.Budget.Incomings AS Budget
		|		INNER JOIN Catalog.IncomeAndExpenseItems AS IncomeAndExpenseItems
		|		ON Budget.IncomeItem = IncomeAndExpenseItems.Ref
		|			AND (IncomeAndExpenseItems.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.Revenue))
		|	WHERE
		|		Budget.Ref = &Ref
		|		AND Budget.PlanningDate BETWEEN &StartDate AND &EndDate
		|		AND &FilterByStructuralUnit
		|		AND &FilterByBusinessLine
		|		AND &FilterByOrder
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		&Company,
		|		Budget.BusinessLine,
		|		Budget.SalesOrder,
		|		CASE
		|			WHEN &UseDefaultTypeOfAccounting
		|				THEN Budget.BusinessLine.GLAccountRevenueFromSales
		|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|		END,
		|		CASE
		|			WHEN &UseDefaultTypeOfAccounting
		|				THEN Budget.BusinessLine.GLAccountCostOfSales
		|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|		END,
		|		CASE
		|			WHEN &UseDefaultTypeOfAccounting
		|				THEN Budget.BusinessLine.ProfitGLAccount
		|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|		END,
		|		Budget.StructuralUnit,
		|		-Budget.Amount
		|	FROM
		|		Document.Budget.Expenses AS Budget
		|		INNER JOIN Catalog.IncomeAndExpenseItems AS IncomeAndExpenseItems
		|		ON Budget.ExpenseItem = IncomeAndExpenseItems.Ref
		|			AND (IncomeAndExpenseItems.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales))
		|	WHERE
		|		Budget.Ref = &Ref
		|		AND Budget.PlanningDate BETWEEN &StartDate AND &EndDate
		|		AND &FilterByStructuralUnit
		|		AND &FilterByBusinessLine
		|		AND &FilterByOrder) AS Table
		|
		|GROUP BY
		|	Table.Company,
		|	Table.BusinessLine,
		|	Table.Order,
		|	Table.GLAccountRevenueFromSales,
		|	Table.GLAccountCostOfSales,
		|	Table.ProfitGLAccount,
		|	Table.StructuralUnit";
		
	Else
		
		Return ResultTable;
		
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText;
	
	Query.SetParameter("StartDate", StartDate);
	Query.SetParameter("EndDate", EndDate);
	Query.SetParameter("Ref", AdditionalProperties.ForPosting.Ref);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	If ValueIsFilled(FilterByOrder) Then
		If TypeOf(FilterByOrder) = Type("Array") Then
			Query.SetParameter("OrdersArray", FilterByOrder);
		Else
			ArrayForSelection = New Array;
			ArrayForSelection.Add(FilterByOrder);
			Query.SetParameter("OrdersArray", ArrayForSelection);
		EndIf;
	EndIf;
	
	If ValueIsFilled(FilterByStructuralUnit) Then
		If TypeOf(FilterByStructuralUnit) = Type("Array") Then
			Query.SetParameter("BusinessUnitsArray", FilterByStructuralUnit);
		Else
			ArrayForSelection = New Array;
			ArrayForSelection.Add(FilterByStructuralUnit);
			Query.SetParameter("BusinessUnitsArray", ArrayForSelection);
		EndIf;
	EndIf;
	
	If ValueIsFilled(FilterByBusinessLine) Then
		If TypeOf(FilterByBusinessLine) = Type("Array") Then
			Query.SetParameter("BusinessLinesArray", FilterByBusinessLine);
		Else
			ArrayForSelection = New Array;
			ArrayForSelection.Add(FilterByBusinessLine);
			Query.SetParameter("BusinessLinesArray", FilterByBusinessLine);
		EndIf;
	EndIf;
	
	ResultTable = Query.Execute().Unload();
	
	Return ResultTable;
	
EndFunction

// Distributing financial result throughtout the base.
//
Procedure DistributeFinancialResultThroughoutBase(DocumentRefBudget, StructureAdditionalProperties, StartDate, EndDate)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	IncomeAndExpenses.Company AS Company,
	|	IncomeAndExpenses.Date AS Date,
	|	IncomeAndExpenses.PlanningPeriod AS PlanningPeriod,
	|	IncomeAndExpenses.StructuralUnit AS StructuralUnit,
	|	IncomeAndExpenses.BusinessLine AS BusinessLine,
	|	IncomeAndExpenses.ProfitGLAccount AS ProfitGLAccount,
	|	IncomeAndExpenses.Order AS Order,
	|	IncomeAndExpenses.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	IncomeAndExpenses.GLAccount AS GLAccount,
	|	IncomeAndExpenses.MethodOfDistribution AS MethodOfDistribution,
	|	SUM(IncomeAndExpenses.AmountIncome) AS AmountIncome,
	|	SUM(IncomeAndExpenses.AmountExpense) AS AmountExpense
	|FROM
	|	(SELECT
	|		&Company AS Company,
	|		DocumentTable.PlanningDate AS Date,
	|		DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|		DocumentTable.StructuralUnit AS StructuralUnit,
	|		DocumentTable.BusinessLine AS BusinessLine,
	|		CASE
	|			WHEN &UseDefaultTypeOfAccounting
	|				THEN DocumentTable.BusinessLine.ProfitGLAccount
	|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		END AS ProfitGLAccount,
	|		DocumentTable.SalesOrder AS Order,
	|		CASE
	|			WHEN &UseDefaultTypeOfAccounting
	|				THEN DocumentTable.Account
	|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		END AS GLAccount,
	|		DocumentTable.IncomeItem AS IncomeAndExpenseItem,
	|		DocumentTable.IncomeItem.MethodOfDistribution AS MethodOfDistribution,
	|		DocumentTable.Amount AS AmountIncome,
	|		0 AS AmountExpense
	|	FROM
	|		Document.Budget.Incomings AS DocumentTable
	|	WHERE
	|		DocumentTable.PlanningDate BETWEEN &StartDate AND &EndDate
	|		AND DocumentTable.Ref = &Ref
	|		AND (DocumentTable.IncomeItem.MethodOfDistribution <> VALUE(Enum.CostAllocationMethod.DoNotDistribute)
	|				OR (DocumentTable.IncomeItem <> &CostOfSalesItem
	|						AND DocumentTable.IncomeItem <> &RevenueItem
	|					OR DocumentTable.BusinessLine = VALUE(Catalog.LinesOfBusiness.Other)
	|					OR DocumentTable.BusinessLine = VALUE(Catalog.LinesOfBusiness.EmptyRef)))
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		&Company,
	|		DocumentTable.PlanningDate,
	|		DocumentTable.Ref.PlanningPeriod,
	|		DocumentTable.StructuralUnit,
	|		DocumentTable.BusinessLine,
	|		CASE
	|			WHEN &UseDefaultTypeOfAccounting
	|				THEN DocumentTable.BusinessLine.ProfitGLAccount
	|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		END,
	|		DocumentTable.SalesOrder,
	|		CASE
	|			WHEN &UseDefaultTypeOfAccounting
	|				THEN DocumentTable.Account
	|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		END,
	|		DocumentTable.ExpenseItem,
	|		DocumentTable.ExpenseItem.MethodOfDistribution,
	|		0,
	|		DocumentTable.Amount
	|	FROM
	|		Document.Budget.Expenses AS DocumentTable
	|	WHERE
	|		DocumentTable.PlanningDate BETWEEN &StartDate AND &EndDate
	|		AND DocumentTable.Ref = &Ref
	|		AND (DocumentTable.ExpenseItem.MethodOfDistribution <> VALUE(Enum.CostAllocationMethod.DoNotDistribute)
	|				OR (DocumentTable.ExpenseItem <> &CostOfSalesItem
	|						AND DocumentTable.ExpenseItem <> &RevenueItem
	|					OR DocumentTable.BusinessLine = VALUE(Catalog.LinesOfBusiness.Other)
	|					OR DocumentTable.BusinessLine = VALUE(Catalog.LinesOfBusiness.EmptyRef)))) AS IncomeAndExpenses
	|
	|GROUP BY
	|	IncomeAndExpenses.Company,
	|	IncomeAndExpenses.Date,
	|	IncomeAndExpenses.PlanningPeriod,
	|	IncomeAndExpenses.StructuralUnit,
	|	IncomeAndExpenses.BusinessLine,
	|	IncomeAndExpenses.ProfitGLAccount,
	|	IncomeAndExpenses.Order,
	|	IncomeAndExpenses.GLAccount,
	|	IncomeAndExpenses.IncomeAndExpenseItem,
	|	IncomeAndExpenses.MethodOfDistribution
	|
	|ORDER BY
	|	MethodOfDistribution,
	|	StructuralUnit,
	|	BusinessLine,
	|	Order
	|TOTALS
	|	SUM(AmountIncome),
	|	SUM(AmountExpense)
	|BY
	|	MethodOfDistribution,
	|	StructuralUnit,
	|	BusinessLine,
	|	Order";
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	Query.SetParameter("Ref", DocumentRefBudget);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("StartDate", StartDate);
	Query.SetParameter("EndDate", EndDate);
	Query.SetParameter("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	Query.SetParameter("CostOfSalesItem", Catalogs.DefaultIncomeAndExpenseItems.GetItem("CostOfSales"));
	Query.SetParameter("RevenueItem", Catalogs.DefaultIncomeAndExpenseItems.GetItem("Revenue"));
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	BypassByDistributionMethod = QueryResult.Select(QueryResultIteration.ByGroups);
	
	
	While BypassByDistributionMethod.Next() Do
		
		BypassByStructuralUnit = BypassByDistributionMethod.Select(QueryResultIteration.ByGroups);
		
		// Bypass on departments.
		While BypassByStructuralUnit.Next() Do
			
			FilterByStructuralUnit = BypassByStructuralUnit.StructuralUnit;
			
			BypassByActivityDirection = BypassByStructuralUnit.Select(QueryResultIteration.ByGroups);
			
			While BypassByActivityDirection.Next() Do
				
				FilterByBusinessLine = BypassByActivityDirection.BusinessLine;
				
				BypassByOrder = BypassByActivityDirection.Select(QueryResultIteration.ByGroups);
				
				// Bypass on orders.
				While BypassByOrder.Next() Do
				
					FilterByOrder = BypassByOrder.Order;
					
					If BypassByOrder.MethodOfDistribution = Enums.CostAllocationMethod.DoNotDistribute Then
						Continue;
					EndIf;
					
					// Generate allocation base table.
					BaseTable = GenerateFinancialResultDistributionBaseTable(
						BypassByOrder.MethodOfDistribution,
						StructureAdditionalProperties.ForPosting.PlanningPeriod,
						StartDate,
						EndDate,
						FilterByStructuralUnit,
						FilterByBusinessLine,
						FilterByOrder,
						StructureAdditionalProperties);
					
					If BaseTable.Count() = 0 Then
						
						BaseTable = GenerateFinancialResultDistributionBaseTable(
							BypassByOrder.MethodOfDistribution,
							StructureAdditionalProperties.ForPosting.PlanningPeriod,
							StartDate,
							EndDate,
							FilterByStructuralUnit,
							FilterByBusinessLine,
							Undefined,
							StructureAdditionalProperties);
						
					EndIf;
					
					If BaseTable.Count() = 0 Then
						
						BaseTable = GenerateFinancialResultDistributionBaseTable(
							BypassByOrder.MethodOfDistribution,
							StructureAdditionalProperties.ForPosting.PlanningPeriod,
							StartDate,
							EndDate,
							FilterByStructuralUnit,
							Undefined,
							Undefined,
							StructureAdditionalProperties);
						
					EndIf;
					
					If BaseTable.Count() = 0 Then
						
						BaseTable = GenerateFinancialResultDistributionBaseTable(
							BypassByOrder.MethodOfDistribution,
							StructureAdditionalProperties.ForPosting.PlanningPeriod,
							StartDate,
							EndDate,
							Undefined,
							Undefined,
							Undefined,
							StructureAdditionalProperties);
						
					EndIf;
					
					If BaseTable.Count() = 0 Then
						TotalBaseDistribution = 0;
					Else
						TotalBaseDistribution = BaseTable.Total("Base");
					EndIf;
					DirectionsQuantity  = BaseTable.Count() - 1;
					
					BypassByDetails = BypassByOrder.Select();
					
					// Bypass on the expenses accounts.
					While BypassByDetails.Next() Do
						
						If BaseTable.Count() = 0
							Or TotalBaseDistribution = 0 Then
							
							BaseTable = New ValueTable;
							BaseTable.Columns.Add("Company");
							BaseTable.Columns.Add("StructuralUnit");
							BaseTable.Columns.Add("BusinessLine");
							BaseTable.Columns.Add("Order");
							BaseTable.Columns.Add("IncomeAndExpenseItem");
							BaseTable.Columns.Add("GLAccountRevenueFromSales");
							BaseTable.Columns.Add("GLAccountCostOfSales");
							BaseTable.Columns.Add("ProfitGLAccount");
							BaseTable.Columns.Add("Base");
							
							TableRow = BaseTable.Add();
							TableRow.Company = BypassByDetails.Company;
							TableRow.StructuralUnit = BypassByDetails.StructuralUnit;
							TableRow.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
							TableRow.Order = BypassByDetails.Order;
							TableRow.IncomeAndExpenseItem = BypassByDetails.IncomeAndExpenseItem;
							TableRow.GLAccountRevenueFromSales = BypassByDetails.GLAccount;
							TableRow.GLAccountCostOfSales = BypassByDetails.GLAccount;
							TableRow.ProfitGLAccount = Catalogs.LinesOfBusiness.MainLine.ProfitGLAccount;
							TableRow.Base = 1;
							
							TotalBaseDistribution = 1;
							
						EndIf;
					
						// Allocate amount.
						If BypassByDetails.AmountIncome <> 0 
							Or BypassByDetails.AmountExpense <> 0 Then
							
							If BypassByDetails.AmountIncome <> 0 Then
								SumDistribution = BypassByDetails.AmountIncome;
							ElsIf BypassByDetails.AmountExpense <> 0 Then
								SumDistribution = BypassByDetails.AmountExpense;
							EndIf;
							
							SumWasDistributed = 0;
							
							For Each DistributionDirection In BaseTable Do
							
								CostAmount = ?(SumDistribution = 0, 0, Round(DistributionDirection.Base / TotalBaseDistribution * SumDistribution, 2, 1));
								SumWasDistributed = SumWasDistributed + CostAmount;
							
								// If it is the last string - , correct amount in it to the rounding error.
								If BaseTable.IndexOf(DistributionDirection) = DirectionsQuantity Then
									CostAmount = CostAmount + SumDistribution - SumWasDistributed;
								EndIf;
							
								If CostAmount <> 0 Then
									
									// Movements by register Financial result.
									NewRow	= StructureAdditionalProperties.TableForRegisterRecords.TableFinancialResultForecast.Add();
									NewRow.Period = BypassByDetails.Date;
									NewRow.Recorder = DocumentRefBudget;
									NewRow.Company = DistributionDirection.Company;
									NewRow.PlanningPeriod = BypassByDetails.PlanningPeriod;
									NewRow.StructuralUnit = DistributionDirection.StructuralUnit;
									NewRow.BusinessLine = DistributionDirection.BusinessLine;
									NewRow.IncomeAndExpenseItem = BypassByDetails.IncomeAndExpenseItem;
									
									NewRow.GLAccount = BypassByDetails.GLAccount;
									
									If BypassByDetails.AmountIncome <> 0 Then
										NewRow.AmountIncome = CostAmount;
									ElsIf BypassByDetails.AmountExpense <> 0 Then
										NewRow.AmountExpense = CostAmount;
									EndIf;
									
									// Movements by register AccountingJournalEntries.
									If UseDefaultTypeOfAccounting Then
										
										NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
										NewRow.Period = BypassByDetails.Date;
										NewRow.Company = StructureAdditionalProperties.ForPosting.Company;
										NewRow.PlanningPeriod = BypassByDetails.PlanningPeriod;
										
										If BypassByDetails.AmountIncome <> 0 Then
											NewRow.AccountDr = BypassByDetails.GLAccount;
											NewRow.AccountCr = DistributionDirection.ProfitGLAccount;
											NewRow.Amount = CostAmount; 
										ElsIf BypassByDetails.AmountExpense <> 0 Then
											NewRow.AccountDr = DistributionDirection.ProfitGLAccount;
											NewRow.AccountCr = BypassByDetails.GLAccount;
											NewRow.Amount = CostAmount;
										EndIf;
										
										NewRow.Content = "Financial result (forecast)";
										
									EndIf;
									
								EndIf;
								
							EndDo;
						
							If SumWasDistributed = 0 Then
								
								MessageText = NStr("en = 'Financial result calculation: The ""%GLAccount%"" GL account has no distribution base.'; ru = 'Расчет финансового результата: Счет учета ""%GLAccount%"", не имеет базы распределения!';pl = 'Obliczanie wyniku finansowego: Konto ""%GLAccount%"" księgi głównej nie posiada bazy dystrybucyjnej.';es_ES = 'Cálculo del resultado financiero: La cuenta del libro mayor ""%GLAccount%"" no tiene una base de distribución.';es_CO = 'Cálculo del resultado financiero: La cuenta del libro mayor ""%GLAccount%"" no tiene una base de distribución.';tr = 'Finansal sonuç hesaplaması: ""%GLAccount%"" Muhasebe hesabının dağıtım tabanı yoktur.';it = 'Calcolo del risultato finanziario: il conto mastro""%GLAccount%"" non ha alcuna base di distribuzione.';de = 'Berechnung des Finanzergebnisses: Das Hauptbuch-Konto ""%GLAccount%"" hat keine Verteilungsbasis.'");
								MessageText = StrReplace(MessageText, "%GLAccount%", String(BypassByDetails.GLAccount));
								DriveServer.ShowMessageAboutError(DocumentRefBudget, MessageText); 
								
								Continue;
								
							EndIf;
						
						EndIf
					
					EndDo;
				
				EndDo;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataFinancialResultForecast(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	DocumentTable.PlanningDate AS Date,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.BusinessLine AS BusinessLine,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.BusinessLine.ProfitGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ProfitGLAccount,
	|	DocumentTable.SalesOrder AS Order,
	|	DocumentTable.IncomeItem AS IncomeAndExpenseItem,
	|	DocumentTable.Account AS GLAccount,
	|	DocumentTable.Amount AS AmountIncome,
	|	0 AS AmountExpense
	|FROM
	|	Document.Budget.Incomings AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (DocumentTable.IncomeItem.MethodOfDistribution = VALUE(Enum.CostAllocationMethod.DoNotDistribute)
	|			OR (DocumentTable.IncomeItem = &CostOfSalesItem
	|				OR DocumentTable.IncomeItem = &RevenueItem)
	|				AND DocumentTable.BusinessLine <> VALUE(Catalog.LinesOfBusiness.Other))
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	DocumentTable.PlanningDate,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.BusinessLine,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.BusinessLine.ProfitGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	DocumentTable.SalesOrder,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.Account,
	|	0,
	|	DocumentTable.Amount
	|FROM
	|	Document.Budget.Expenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (DocumentTable.ExpenseItem.MethodOfDistribution = VALUE(Enum.CostAllocationMethod.DoNotDistribute)
	|			OR (DocumentTable.ExpenseItem = &CostOfSalesItem
	|				OR DocumentTable.ExpenseItem = &RevenueItem)
	|				AND DocumentTable.BusinessLine <> VALUE(Catalog.LinesOfBusiness.Other))";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Ref", DocumentRefBudget);
	Query.SetParameter("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	Query.SetParameter("CostOfSalesItem", Catalogs.DefaultIncomeAndExpenseItems.GetItem("CostOfSales"));
	Query.SetParameter("RevenueItem", Catalogs.DefaultIncomeAndExpenseItems.GetItem("Revenue"));
	
	QueryResult = Query.Execute();
	
	TableFinancialResultForecast = New ValueTable;
	
	TableFinancialResultForecast.Columns.Add("LineNumber");
	TableFinancialResultForecast.Columns.Add("Recorder");
	TableFinancialResultForecast.Columns.Add("Period");
	TableFinancialResultForecast.Columns.Add("Company");
	TableFinancialResultForecast.Columns.Add("PlanningPeriod");
	TableFinancialResultForecast.Columns.Add("StructuralUnit");
	TableFinancialResultForecast.Columns.Add("BusinessLine");
	TableFinancialResultForecast.Columns.Add("IncomeAndExpenseItem");
	TableFinancialResultForecast.Columns.Add("GLAccount");
	TableFinancialResultForecast.Columns.Add("AmountIncome");
	TableFinancialResultForecast.Columns.Add("AmountExpense");
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFinancialResultForecast", TableFinancialResultForecast);
	
	SelectionQueryResult = QueryResult.Select();
	
	While SelectionQueryResult.Next() Do
		
		// Movements by register Financial result.
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableFinancialResultForecast.Add();
		NewRow.Period = SelectionQueryResult.Date;
		NewRow.Recorder = DocumentRefBudget;
		NewRow.PlanningPeriod = SelectionQueryResult.PlanningPeriod;
		NewRow.Company = SelectionQueryResult.Company;
		NewRow.StructuralUnit = SelectionQueryResult.StructuralUnit;
		NewRow.BusinessLine = ?(
			ValueIsFilled(SelectionQueryResult.BusinessLine), 
			SelectionQueryResult.BusinessLine, 
			Catalogs.LinesOfBusiness.MainLine);
		NewRow.IncomeAndExpenseItem = SelectionQueryResult.IncomeAndExpenseItem;
		
		NewRow.GLAccount = SelectionQueryResult.GLAccount;
		
		If SelectionQueryResult.AmountIncome <> 0 Then
			NewRow.AmountIncome = SelectionQueryResult.AmountIncome;
		ElsIf SelectionQueryResult.AmountExpense <> 0 Then
			NewRow.AmountExpense = SelectionQueryResult.AmountExpense;
		EndIf;
		
		// Movements by register AccountingJournalEntries.
		If UseDefaultTypeOfAccounting Then
			
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
			NewRow.Period = SelectionQueryResult.Date;
			NewRow.Company = SelectionQueryResult.Company;
			NewRow.PlanningPeriod = SelectionQueryResult.PlanningPeriod;
			
			If SelectionQueryResult.AmountIncome <> 0 Then
				
				NewRow.AccountDr = SelectionQueryResult.GLAccount;
				NewRow.AccountCr = ?(
					ValueIsFilled(SelectionQueryResult.BusinessLine),
					SelectionQueryResult.ProfitGLAccount,
					Catalogs.LinesOfBusiness.MainLine.ProfitGLAccount);
				NewRow.Amount = SelectionQueryResult.AmountIncome;
				
			ElsIf SelectionQueryResult.AmountExpense <> 0 Then
				
				NewRow.AccountDr = ?(
					ValueIsFilled(SelectionQueryResult.BusinessLine),
					SelectionQueryResult.ProfitGLAccount,
					Catalogs.LinesOfBusiness.MainLine.ProfitGLAccount);
				NewRow.AccountCr = SelectionQueryResult.GLAccount;
				NewRow.Amount = SelectionQueryResult.AmountExpense;
				
			EndIf;
			
			NewRow.Content = NStr("en = 'Financial result (forecast)'; ru = 'Финансовый результат (прогноз)';pl = 'Finansowy wynik (prognoza)';es_ES = 'Resultado financiero (pronóstico)';es_CO = 'Resultado financiero (pronóstico)';tr = 'Finansal sonuç (tahmini)';it = 'Risultato finanziario (previsione)';de = 'Finanzergebnis (Prognose)'", MainLanguageCode);
			
		EndIf;
		
	EndDo;
	
	StartDate = StructureAdditionalProperties.ForPosting.StartDate;
	EndDate = StructureAdditionalProperties.ForPosting.EndDate;
	
	While StartDate < EndDate Do
		DistributeFinancialResultThroughoutBase(DocumentRefBudget, StructureAdditionalProperties, StartDate, EndOfMonth(StartDate));
		StartDate = EndOfMonth(StartDate) + 1;;
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefBudget, StructureAdditionalProperties) Export
	
	InitializeDocumentDataBalances(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataDirectCost(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataIndirectExpenses(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataAccountingRecords(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataReceipts(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataOutflows(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataIncome(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataExpenses(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataIncomeAndExpensesBudget(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataCashBudget(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataFinancialResultForecast(DocumentRefBudget, StructureAdditionalProperties);
	
	FinancialAccounting.FillExtraDimensions(DocumentRefBudget, StructureAdditionalProperties);
	
EndProcedure

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Incomings" Then
		IncomeAndExpenseStructure.Insert("IncomeItem", StructureData.IncomeItem);
	ElsIf StructureData.TabName = "Expenses" Then
		IncomeAndExpenseStructure.Insert("ExpenseItem", StructureData.ExpenseItem);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "Incomings" Then
		Result.Insert("Account", "IncomeItem");
	ElsIf StructureData.TabName = "Expenses" Then
		Result.Insert("Account", "ExpenseItem");
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

#EndIf