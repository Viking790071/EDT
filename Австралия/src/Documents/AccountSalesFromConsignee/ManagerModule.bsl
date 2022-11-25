#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

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

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Inventory" Then
		IncomeAndExpenseStructure.Insert("COGSItem", StructureData.COGSItem);
		IncomeAndExpenseStructure.Insert("RevenueItem", StructureData.RevenueItem);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "Inventory" Then
		Result.Insert("RevenueGLAccount", "RevenueItem");
		Result.Insert("COGSGLAccount", "COGSItem");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	If StructureData.Property("CounterpartyGLAccounts") Then
		
		ObjectParameters = StructureData.ObjectParameters;
		GLAccountsForFilling = New Structure;
		
		GLAccountsForFilling.Insert("AccountsReceivableGLAccount", ObjectParameters.AccountsReceivableGLAccount);
		GLAccountsForFilling.Insert("AdvancesReceivedGLAccount", ObjectParameters.AdvancesReceivedGLAccount);
		
	ElsIf StructureData.Property("ProductGLAccounts") Then
		
		GLAccountsForFilling = New Structure("InventoryTransferredGLAccount, VATOutputGLAccount, RevenueGLAccount, COGSGLAccount");
		FillPropertyValues(GLAccountsForFilling, StructureData); 
		
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region InventoryOwnership

Function InventoryOwnershipParameters(DocObject) Export
	
	Parameters = New Structure;
	
	Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);
	
	Return Parameters;
	
EndFunction

#EndRegion

Function DocumentVATRate(DocumentRef) Export
	
	Return DriveServer.DocumentVATRate(DocumentRef);
	
EndFunction

#EndRegion

#Region AccountingRecords

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	TableAccountingJournalEntries.Period AS Period,
	|	TableAccountingJournalEntries.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements AS AccountDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN CASE
	|					WHEN TableAccountingJournalEntries.KeepBackCommissionFee
	|						THEN TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.VATAmountCur - (TableAccountingJournalEntries.BrokerageAmountCur - TableAccountingJournalEntries.BrokerageVATAmountCur)
	|					ELSE TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.VATAmountCur
	|				END
	|		ELSE 0
	|	END AS AmountCurDr,
	|	TableAccountingJournalEntries.AccountStatementSales AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.KeepBackCommissionFee
	|			THEN TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount - (TableAccountingJournalEntries.BrokerageAmount - TableAccountingJournalEntries.BrokerageVATAmount)
	|		ELSE TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount
	|	END AS Amount,
	|	&IncomeReflection AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.CustomerAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.CustomerAdvancesGLAccountForeignCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.CustomerAdvancesGLAccountForeignCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlementsCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlementsCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	&SetOffAdvancePayment,
	|	FALSE
	|FROM
	|	(SELECT
	|		DocumentTable.Period AS Period,
	|		DocumentTable.Company AS Company,
	|		DocumentTable.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|		DocumentTable.CustomerAdvancesGLAccountForeignCurrency AS CustomerAdvancesGLAccountForeignCurrency,
	|		DocumentTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|		DocumentTable.GLAccountCustomerSettlementsCurrency AS GLAccountCustomerSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|		SUM(DocumentTable.AmountCur) AS AmountCur,
	|		SUM(DocumentTable.Amount) AS Amount
	|	FROM
	|		(SELECT
	|			DocumentTable.Period AS Period,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|			DocumentTable.CustomerAdvancesGLAccount.Currency AS CustomerAdvancesGLAccountForeignCurrency,
	|			DocumentTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|			DocumentTable.GLAccountCustomerSettlements.Currency AS GLAccountCustomerSettlementsCurrency,
	|			DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|			DocumentTable.AmountCur AS AmountCur,
	|			DocumentTable.Amount AS Amount
	|		FROM
	|			TemporaryTablePrepayment AS DocumentTable
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.Counterparty.CustomerAdvancesGLAccount,
	|			DocumentTable.Counterparty.CustomerAdvancesGLAccount.Currency,
	|			DocumentTable.Counterparty.GLAccountCustomerSettlements,
	|			DocumentTable.Counterparty.GLAccountCustomerSettlements.Currency,
	|			DocumentTable.Currency,
	|			0,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Company,
	|		DocumentTable.CustomerAdvancesGLAccount,
	|		DocumentTable.CustomerAdvancesGLAccountForeignCurrency,
	|		DocumentTable.GLAccountCustomerSettlements,
	|		DocumentTable.GLAccountCustomerSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency
	|	
	|	HAVING
	|		(SUM(DocumentTable.Amount) >= 0.005
	|			OR SUM(DocumentTable.Amount) <= -0.005
	|			OR SUM(DocumentTable.AmountCur) >= 0.005
	|			OR SUM(DocumentTable.AmountCur) <= -0.005)) AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	TableAccountingJournalEntries.Date,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN TableAccountingJournalEntries.GLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|				AND TableAccountingJournalEntries.GLAccountForeignCurrency
	|			THEN TableAccountingJournalEntries.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE TableAccountingJournalEntries.GLAccount
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences < 0
	|				AND TableAccountingJournalEntries.GLAccountForeignCurrency
	|			THEN TableAccountingJournalEntries.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN TableAccountingJournalEntries.AmountOfExchangeDifferences
	|		ELSE -TableAccountingJournalEntries.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	(SELECT
	|		TableExchangeRateDifferencesAccountsReceivable.Date AS Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company AS Company,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccount AS GLAccount,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccountForeignCurrency AS GLAccountForeignCurrency,
	|		TableExchangeRateDifferencesAccountsReceivable.Currency AS Currency,
	|		SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.GLAccount AS GLAccount,
	|			DocumentTable.GLAccount.Currency AS GLAccountForeignCurrency,
	|			DocumentTable.Currency AS Currency,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.GLAccount,
	|			DocumentTable.GLAccount.Currency,
	|			DocumentTable.Currency,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableExchangeRateDifferencesAccountsReceivable
	|	
	|	GROUP BY
	|		TableExchangeRateDifferencesAccountsReceivable.Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccount,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccountForeignCurrency,
	|		TableExchangeRateDifferencesAccountsReceivable.Currency
	|	
	|	HAVING
	|		(SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) <= -0.005)) AS TableAccountingJournalEntries
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	SUM(CASE
	|			WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|				THEN CASE
	|						WHEN TableAccountingJournalEntries.KeepBackCommissionFee
	|							THEN TableAccountingJournalEntries.VATAmountCur - TableAccountingJournalEntries.BrokerageVATAmountCur
	|						ELSE TableAccountingJournalEntries.VATAmountCur
	|					END
	|			ELSE 0
	|		END),
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	UNDEFINED,
	|	0,
	|	SUM(CASE
	|			WHEN TableAccountingJournalEntries.KeepBackCommissionFee
	|				THEN TableAccountingJournalEntries.VATAmount - TableAccountingJournalEntries.BrokerageVATAmount
	|			ELSE TableAccountingJournalEntries.VATAmount
	|		END),
	|	&VAT,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.VATAmountCur > 0
	|
	|GROUP BY
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company
	|
	|UNION ALL
	|
	|SELECT
	|	5,
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
	|
	|ORDER BY
	|	Order";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("SetOffAdvancePayment",							NStr("en = 'Advance payment clearing'; ru = 'Зачет аванса';pl = 'Rozliczanie zaliczki';es_ES = 'Amortización de pagos anticipados';es_CO = 'Amortización de pagos anticipados';tr = 'Avans ödeme mahsuplaştırılması';it = 'Annullamento del pagamento anticipato';de = 'Verrechnung der Vorauszahlung'", MainLanguageCode));
	Query.SetParameter("IncomeReflection",								NStr("en = 'Revenue'; ru = 'Выручка от продажи';pl = 'Przychód';es_ES = 'Ingreso';es_CO = 'Ingreso';tr = 'Gelir';it = 'Ricavo';de = 'Erlös'", MainLanguageCode));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("VAT",											NStr("en = 'VAT'; ru = 'НДС';pl = 'Kwota VAT';es_ES = 'IVA';es_CO = 'IVA';tr = 'KDV';it = 'IVA';de = 'USt.'", MainLanguageCode));
	Query.SetParameter("Ref",											DocumentRefAccountSalesFromConsignee);

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
Procedure GenerateTableInventory(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.Counterparty AS Counterparty,
	|	TableInventory.DocumentCurrency AS Currency,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableInventory.Document AS Document,
	|	TableInventory.Document AS SourceDocument,
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END AS CorrSalesOrder,
	|	TableInventory.DepartmentSales AS Department,
	|	TableInventory.Responsible AS Responsible,
	|	TableInventory.BusinessLineSales AS BusinessLine,
	|	TableInventory.GLAccountCost AS CorrGLAccount,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.DepartmentSales AS DepartmentSales,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.InventoryAccountType AS CorrInventoryAccountType,
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END AS SalesOrder,
	|	TableInventory.KeepBackCommissionFee AS KeepBackCommissionFee,
	|	TableInventory.VATRate AS VATRate,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.VATAmount) AS VATAmount,
	|	SUM(TableInventory.Amount) AS Amount,
	|	SUM(TableInventory.BrokerageAmount) AS BrokerageAmount,
	|	FALSE AS FixedCost,
	|	TableInventory.GLAccountCost AS AccountDr,
	|	TableInventory.GLAccount AS AccountCr,
	|	&AccountSalesFromConsignee AS Content,
	|	&AccountSalesFromConsignee AS ContentOfAccountingRecord,
	|	TableInventory.SalesRep AS SalesRep,
	|	TableInventory.CostObject AS CostObject,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) AS IncomeAndExpenseItem,
	|	TableInventory.COGSItem AS CorrIncomeAndExpenseItem
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.Counterparty,
	|	TableInventory.DocumentCurrency,
	|	TableInventory.Document,
	|	TableInventory.BusinessLineSales,
	|	TableInventory.GLAccountCost,
	|	TableInventory.StructuralUnit,
	|	TableInventory.DepartmentSales,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.SalesOrder,
	|	TableInventory.VATRate,
	|	TableInventory.KeepBackCommissionFee,
	|	TableInventory.Responsible,
	|	TableInventory.SalesRep,
	|	TableInventory.Document,
	|	TableInventory.DepartmentSales,
	|	TableInventory.GLAccountCost,
	|	TableInventory.GLAccount,
	|	TableInventory.CostObject,
	|	TableInventory.COGSItem";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("AccountSalesFromConsignee", NStr("en = 'Account sales from consignee'; ru = 'Отчет комиссионера';pl = 'Raport sprzedaży od komisanta';es_ES = 'Informe de ventas de los destinatarios';es_CO = 'Ventas de cuenta del destinatario';tr = 'Konsinye satışlar';it = 'Saldo delle vendite dall''agente in conto vendita';de = 'Verkaufsbericht (Kommissionär)'", MainLanguageCode));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text =
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.CostObject AS CostObject,
	|	TableInventory.InventoryAccountType AS InventoryAccountType
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.StructuralUnit,
	|	TableInventory.CostObject,
	|	TableInventory.InventoryAccountType";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Inventory");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving inventory balances by cost.
	Query.Text = 	
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.PresentationCurrency AS PresentationCurrency,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.Ownership AS Ownership,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.CostObject AS CostObject,
	|	InventoryBalances.InventoryAccountType AS InventoryAccountType,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.PresentationCurrency AS PresentationCurrency,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.Ownership AS Ownership,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.CostObject AS CostObject,
	|		InventoryBalances.InventoryAccountType AS InventoryAccountType,
	|		InventoryBalances.QuantityBalance AS QuantityBalance,
	|		InventoryBalances.AmountBalance AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, PresentationCurrency, Products, Characteristic, Batch, Ownership, StructuralUnit, CostObject, InventoryAccountType) IN
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.PresentationCurrency,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.Ownership,
	|						TableInventory.StructuralUnit,
	|						TableInventory.CostObject,
	|						TableInventory.InventoryAccountType
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.PresentationCurrency,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		DocumentRegisterRecordsInventory.Ownership,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.CostObject,
	|		DocumentRegisterRecordsInventory.InventoryAccountType,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.PresentationCurrency,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.Ownership,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.CostObject,
	|	InventoryBalances.InventoryAccountType";
	
	Query.SetParameter("Ref", DocumentRefAccountSalesFromConsignee);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add(
		"Company, PresentationCurrency, Products, Characteristic, Batch, Ownership, StructuralUnit, CostObject, InventoryAccountType");
	
	TemporaryTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("PresentationCurrency", RowTableInventory.PresentationCurrency);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		StructureForSearch.Insert("Ownership", RowTableInventory.Ownership);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("CostObject", RowTableInventory.CostObject);
		StructureForSearch.Insert("InventoryAccountType", RowTableInventory.InventoryAccountType);
		
		QuantityWanted = RowTableInventory.Quantity;
		
		If QuantityWanted > 0 Then
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityWanted Then
				
				AmountToBeWrittenOff = Round(AmountBalance * QuantityWanted / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityWanted;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = QuantityWanted Then
				
				AmountToBeWrittenOff = AmountBalance;
				
				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			// Add the row for the order.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount   = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityWanted;
			
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				// Generate postings.
				
				If UseDefaultTypeOfAccounting Then
					
					RowTableAccountingJournalEntries = 
						StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
						
					FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
					RowTableAccountingJournalEntries.Amount = AmountToBeWrittenOff;
					
				EndIf;
				
				// Move the cost of sales.
				StringTableSale = StructureAdditionalProperties.TableForRegisterRecords.TableSales.Add();
				FillPropertyValues(StringTableSale, RowTableInventory);
				
				StringTableSale.Quantity = 0;
				StringTableSale.Amount = 0;
				StringTableSale.VATAmount = 0;
				StringTableSale.AmountCur = 0;
				StringTableSale.VATAmountCur = 0;
				StringTableSale.Cost = AmountToBeWrittenOff;
				
				If RowTableInventory.KeepBackCommissionFee Then
					
					// It is necessary to increase the sales cost by the amount of fee.
					NewRow	= StructureAdditionalProperties.TableForRegisterRecords.TableSales.Add();
					FillPropertyValues(NewRow, RowTableInventory);
					
					NewRow.Quantity		= 0;
					NewRow.Amount			= 0;
					NewRow.VATAmount		= 0;
					NewRow.AmountCur = 0;
					NewRow.VATAmountCur = 0;
					NewRow.Cost	= RowTableInventory.BrokerageAmount;
					
				EndIf;
				
				// Move income and expenses.
				RowIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
				FillPropertyValues(RowIncomeAndExpenses, RowTableInventory);
				
				RowIncomeAndExpenses.StructuralUnit = RowTableInventory.DepartmentSales;
				RowIncomeAndExpenses.IncomeAndExpenseItem = RowTableInventory.CorrIncomeAndExpenseItem;
				RowIncomeAndExpenses.GLAccount = RowTableInventory.CorrGLAccount;
				RowIncomeAndExpenses.AmountIncome = 0;
				RowIncomeAndExpenses.AmountExpense = AmountToBeWrittenOff;
				
				RowIncomeAndExpenses.ContentOfAccountingRecord = NStr("en = 'Cost of goods sold'; ru = 'Отражение расходов';pl = 'Koszt własny towarów sprzedanych';es_ES = 'Coste de mercancías vendidas';es_CO = 'Coste de mercancías vendidas';tr = 'Satılan malların maliyeti';it = 'Costo dei beni venduti';de = 'Wareneinsatz'", MainLanguageCode);
				
			EndIf;
			
		EndIf;
			
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSales(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Period AS Period,
	|	TableSales.Company AS Company,
	|	TableSales.PresentationCurrency AS PresentationCurrency,
	|	TableSales.Counterparty AS Counterparty,
	|	TableSales.DocumentCurrency AS Currency,
	|	TableSales.Products AS Products,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Batch AS Batch,
	|	TableSales.Ownership AS Ownership,
	|	CASE
	|		WHEN TableSales.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableSales.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableSales.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	TableSales.SalesRep AS SalesRep,
	|	TableSales.Document AS Document,
	|	TableSales.VATRate AS VATRate,
	|	TableSales.DepartmentSales AS Department,
	|	TableSales.Responsible AS Responsible,
	|	SUM(TableSales.Quantity) AS Quantity,
	|	SUM(CASE
	|			WHEN TableSales.KeepBackCommissionFee
	|				THEN TableSales.VATAmount - TableSales.BrokerageVATAmount
	|			ELSE TableSales.VATAmount
	|		END) AS VATAmount,
	|	SUM(CASE
	|			WHEN TableSales.KeepBackCommissionFee
	|				THEN TableSales.Amount - TableSales.BrokerageAmount
	|			ELSE TableSales.Amount
	|		END - CASE
	|			WHEN TableSales.KeepBackCommissionFee
	|				THEN TableSales.VATAmount - TableSales.BrokerageVATAmount
	|			ELSE TableSales.VATAmount
	|		END) AS Amount,
	|	SUM(CASE
	|			WHEN TableSales.KeepBackCommissionFee
	|				THEN TableSales.VATAmountDocCur - TableSales.BrokerageVATAmountDocCur
	|			ELSE TableSales.VATAmountDocCur
	|		END) AS VATAmountCur,
	|	SUM(CASE
	|			WHEN TableSales.KeepBackCommissionFee
	|				THEN TableSales.AmountDocCur - TableSales.BrokerageAmountDocCur
	|			ELSE TableSales.AmountDocCur
	|		END - CASE
	|			WHEN TableSales.KeepBackCommissionFee
	|				THEN TableSales.VATAmountDocCur - TableSales.BrokerageVATAmountDocCur
	|			ELSE TableSales.VATAmountDocCur
	|		END) AS AmountCur,
	|	0 AS Cost,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableSales
	|
	|GROUP BY
	|	TableSales.Period,
	|	TableSales.Company,
	|	TableSales.PresentationCurrency,
	|	TableSales.Counterparty,
	|	TableSales.DocumentCurrency,
	|	TableSales.Products,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	TableSales.Ownership,
	|	CASE
	|		WHEN TableSales.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableSales.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableSales.SalesOrder
	|		ELSE UNDEFINED
	|	END,
	|	TableSales.SalesRep,
	|	TableSales.Document,
	|	TableSales.VATRate,
	|	TableSales.DepartmentSales,
	|	TableSales.Responsible
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.Counterparty,
	|	OfflineRecords.Currency,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.Ownership,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.SalesRep,
	|	OfflineRecords.Document,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.Department,
	|	OfflineRecords.Responsible,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.VATAmount,
	|	OfflineRecords.Amount,
	|	OfflineRecords.VATAmountCur,
	|	OfflineRecords.AmountCur,
	|	OfflineRecords.Cost,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Sales AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	Query.SetParameter("Ref", DocumentRefAccountSalesFromConsignee);
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableStockTransferredToThirdParties(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableStockTransferredToThirdParties.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableStockTransferredToThirdParties.Period AS Period,
	|	TableStockTransferredToThirdParties.Company AS Company,
	|	TableStockTransferredToThirdParties.Products AS Products,
	|	TableStockTransferredToThirdParties.Characteristic AS Characteristic,
	|	TableStockTransferredToThirdParties.Counterparty AS Counterparty,
	|	CASE
	|		WHEN TableStockTransferredToThirdParties.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN TableStockTransferredToThirdParties.SalesOrder
	|		ELSE UNDEFINED
	|	END AS Order,
	|	TableStockTransferredToThirdParties.Batch AS Batch,
	|	SUM(TableStockTransferredToThirdParties.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableStockTransferredToThirdParties
	|
	|GROUP BY
	|	TableStockTransferredToThirdParties.Period,
	|	TableStockTransferredToThirdParties.Company,
	|	TableStockTransferredToThirdParties.Products,
	|	TableStockTransferredToThirdParties.Characteristic,
	|	TableStockTransferredToThirdParties.Batch,
	|	TableStockTransferredToThirdParties.Counterparty,
	|	CASE
	|		WHEN TableStockTransferredToThirdParties.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN TableStockTransferredToThirdParties.SalesOrder
	|		ELSE UNDEFINED
	|	END";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockTransferredToThirdParties", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	MAX(TableIncomeAndExpenses.LineNumber) AS LineNumber,
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.PresentationCurrency AS PresentationCurrency,
	|	TableIncomeAndExpenses.DepartmentSales AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLineSales AS BusinessLine,
	|	CASE
	|		WHEN TableIncomeAndExpenses.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableIncomeAndExpenses.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableIncomeAndExpenses.SalesOrder
	|	END AS SalesOrder,
	|	TableIncomeAndExpenses.RevenueItem AS IncomeAndExpenseItem,
	|	TableIncomeAndExpenses.AccountStatementSales AS GLAccount,
	|	&IncomeReflection AS ContentOfAccountingRecord,
	|	SUM(CASE
	|			WHEN TableIncomeAndExpenses.KeepBackCommissionFee
	|				THEN TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount - (TableIncomeAndExpenses.BrokerageAmount - TableIncomeAndExpenses.BrokerageVATAmount)
	|			ELSE TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount
	|		END) AS AmountIncome,
	|	0 AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableIncomeAndExpenses
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Period,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.PresentationCurrency,
	|	TableIncomeAndExpenses.DepartmentSales,
	|	TableIncomeAndExpenses.BusinessLineSales,
	|	TableIncomeAndExpenses.SalesOrder,
	|	TableIncomeAndExpenses.RevenueItem,
	|	TableIncomeAndExpenses.AccountStatementSales
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	UNDEFINED,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &FXIncomeItem
	|		ELSE &FXExpenseItem
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	FALSE
	|FROM
	|	(SELECT
	|		TableExchangeRateDifferencesAccountsReceivable.Date AS Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company AS Company,
	|		TableExchangeRateDifferencesAccountsReceivable.PresentationCurrency AS PresentationCurrency,
	|		SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.PresentationCurrency AS PresentationCurrency,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.PresentationCurrency,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableExchangeRateDifferencesAccountsReceivable
	|	
	|	GROUP BY
	|		TableExchangeRateDifferencesAccountsReceivable.Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company,
	|		TableExchangeRateDifferencesAccountsReceivable.PresentationCurrency
	|	
	|	HAVING
	|		(SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) <= -0.005)) AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("FXIncomeItem", Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem", Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("IncomeReflection",								NStr("en = 'Revenue from account sales'; ru = 'Отражение доходов';pl = 'Przychód  na podstawie raportu sprzedaży';es_ES = 'Rentas de las ventas de la cuenta';es_CO = 'Rentas de las ventas de la cuenta';tr = 'Konsinye satışlardan gelir';it = 'I ricavi da vendita in conto vendita';de = 'Erlöse aus Verkaufsberichten'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("Ref",											DocumentRefAccountSalesFromConsignee);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCustomerAccounts(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefAccountSalesFromConsignee);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfCustomerLiability",	NStr("en = 'Accounts receivable recognition'; ru = 'Возникновение обязательств покупателя';pl = 'Przyjęcie do ewidencji należności';es_ES = 'Reconocimientos de las cuentas a cobrar';es_CO = 'Reconocimientos de las cuentas a cobrar';tr = 'Alacak hesapların onaylanması';it = 'Riconoscimento dei crediti';de = 'Offene Posten Debitoren Aufnahme'", MainLanguageCode));
	Query.SetParameter("AdvanceCredit",					NStr("en = 'Advance payment clearing'; ru = 'Зачет аванса';pl = 'Rozliczanie zaliczki';es_ES = 'Amortización de pagos anticipados';es_CO = 'Amortización de pagos anticipados';tr = 'Avans ödeme mahsuplaştırılması';it = 'Annullamento del pagamento anticipato';de = 'Verrechnung der Vorauszahlung'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExpectedPayments",				NStr("en = 'Expected payment'; ru = 'Ожидаемый платеж';pl = 'Oczekiwana płatność';es_ES = 'Pago esperado';es_CO = 'Pago esperado';tr = 'Beklenen ödeme';it = 'Pagamento previsto';de = 'Erwartete Zahlung'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text = "SELECT
	             |	MAX(DocumentTable.LineNumber) AS LineNumber,
	             |	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	             |	DocumentTable.Period AS Date,
	             |	DocumentTable.Company AS Company,
	             |	DocumentTable.PresentationCurrency AS PresentationCurrency,
	             |	DocumentTable.Counterparty AS Counterparty,
	             |	DocumentTable.GLAccountCustomerSettlements AS GLAccount,
	             |	DocumentTable.Contract AS Contract,
	             |	DocumentTable.Document AS Document,
	             |	CASE
	             |		WHEN DocumentTable.DoOperationsByOrders
	             |				AND DocumentTable.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	             |			THEN DocumentTable.SalesOrder
	             |		ELSE UNDEFINED
	             |	END AS Order,
	             |	DocumentTable.SettlementsCurrency AS Currency,
	             |	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	             |	SUM(CASE
	             |			WHEN DocumentTable.KeepBackCommissionFee
	             |				THEN DocumentTable.Amount - DocumentTable.BrokerageAmount
	             |			ELSE DocumentTable.Amount
	             |		END) AS Amount,
	             |	SUM(CASE
	             |			WHEN DocumentTable.KeepBackCommissionFee
	             |				THEN DocumentTable.AmountCur - DocumentTable.BrokerageAmountCur
	             |			ELSE DocumentTable.AmountCur
	             |		END) AS AmountCur,
	             |	SUM(CASE
	             |			WHEN DocumentTable.KeepBackCommissionFee
	             |				THEN DocumentTable.Amount - DocumentTable.BrokerageAmount
	             |			ELSE DocumentTable.Amount
	             |		END) AS AmountForBalance,
	             |	SUM(CASE
	             |			WHEN DocumentTable.KeepBackCommissionFee
	             |				THEN DocumentTable.AmountCur - DocumentTable.BrokerageAmountCur
	             |			ELSE DocumentTable.AmountCur
	             |		END) AS AmountCurForBalance,
	             |	SUM(CASE
	             |			WHEN DocumentTable.SetPaymentTerms
	             |				THEN 0
	             |			ELSE CASE
	             |					WHEN DocumentTable.KeepBackCommissionFee
	             |						THEN DocumentTable.Amount - DocumentTable.BrokerageAmount
	             |					ELSE DocumentTable.Amount
	             |				END
	             |		END) AS AmountForPayment,
	             |	SUM(CASE
	             |			WHEN DocumentTable.SetPaymentTerms
	             |				THEN 0
	             |			ELSE CASE
	             |					WHEN DocumentTable.KeepBackCommissionFee
	             |						THEN DocumentTable.AmountCur - DocumentTable.BrokerageAmountCur
	             |					ELSE DocumentTable.AmountCur
	             |				END
	             |		END) AS AmountForPaymentCur,
	             |	CAST(&AppearenceOfCustomerLiability AS STRING(100)) AS ContentOfAccountingRecord
	             |INTO TemporaryTableAccountsReceivable
	             |FROM
	             |	TemporaryTableInventory AS DocumentTable
	             |
	             |GROUP BY
	             |	DocumentTable.Period,
	             |	DocumentTable.Company,
	             |	DocumentTable.PresentationCurrency,
	             |	DocumentTable.Counterparty,
	             |	DocumentTable.Contract,
	             |	DocumentTable.Document,
	             |	CASE
	             |		WHEN DocumentTable.DoOperationsByOrders
	             |				AND DocumentTable.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	             |			THEN DocumentTable.SalesOrder
	             |		ELSE UNDEFINED
	             |	END,
	             |	DocumentTable.SettlementsCurrency,
	             |	DocumentTable.GLAccountCustomerSettlements
	             |
	             |UNION ALL
	             |
	             |SELECT
	             |	MAX(DocumentTable.LineNumber),
	             |	VALUE(AccumulationRecordType.Receipt),
	             |	DocumentTable.Period,
	             |	DocumentTable.Company,
	             |	DocumentTable.PresentationCurrency,
	             |	DocumentTable.Counterparty,
	             |	DocumentTable.CustomerAdvancesGLAccount,
	             |	DocumentTable.Contract,
	             |	DocumentTable.Document,
	             |	CASE
	             |		WHEN DocumentTable.DoOperationsByOrders
	             |				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	             |			THEN DocumentTable.Order
	             |		ELSE UNDEFINED
	             |	END,
	             |	DocumentTable.SettlementsCurrency,
	             |	DocumentTable.SettlementsType,
	             |	SUM(DocumentTable.Amount),
	             |	SUM(DocumentTable.AmountCur),
	             |	SUM(DocumentTable.Amount),
	             |	SUM(DocumentTable.AmountCur),
	             |	SUM(DocumentTable.Amount),
	             |	SUM(DocumentTable.AmountCur),
	             |	CAST(&AdvanceCredit AS STRING(100))
	             |FROM
	             |	TemporaryTablePrepayment AS DocumentTable
	             |
	             |GROUP BY
	             |	DocumentTable.Period,
	             |	DocumentTable.Company,
	             |	DocumentTable.PresentationCurrency,
	             |	DocumentTable.Counterparty,
	             |	DocumentTable.Contract,
	             |	DocumentTable.Document,
	             |	CASE
	             |		WHEN DocumentTable.DoOperationsByOrders
	             |				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	             |			THEN DocumentTable.Order
	             |		ELSE UNDEFINED
	             |	END,
	             |	DocumentTable.SettlementsType,
	             |	DocumentTable.SettlementsCurrency,
	             |	DocumentTable.CustomerAdvancesGLAccount
	             |
	             |UNION ALL
	             |
	             |SELECT
	             |	MAX(DocumentTable.LineNumber),
	             |	VALUE(AccumulationRecordType.Expense),
	             |	DocumentTable.Period,
	             |	DocumentTable.Company,
	             |	DocumentTable.PresentationCurrency,
	             |	DocumentTable.Counterparty,
	             |	DocumentTable.GLAccountCustomerSettlements,
	             |	DocumentTable.Contract,
	             |	DocumentTable.DocumentWhere,
	             |	CASE
	             |		WHEN DocumentTable.DoOperationsByOrders
	             |				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	             |			THEN DocumentTable.Order
	             |		ELSE UNDEFINED
	             |	END,
	             |	DocumentTable.SettlementsCurrency,
	             |	DocumentTable.SettlemensTypeWhere,
	             |	SUM(DocumentTable.Amount),
	             |	SUM(DocumentTable.AmountCur),
	             |	-SUM(DocumentTable.Amount),
	             |	-SUM(DocumentTable.AmountCur),
	             |	SUM(DocumentTable.Amount),
	             |	SUM(DocumentTable.AmountCur),
	             |	CAST(&AdvanceCredit AS STRING(100))
	             |FROM
	             |	TemporaryTablePrepayment AS DocumentTable
	             |
	             |GROUP BY
	             |	DocumentTable.Period,
	             |	DocumentTable.Company,
	             |	DocumentTable.PresentationCurrency,
	             |	DocumentTable.Counterparty,
	             |	DocumentTable.Contract,
	             |	DocumentTable.DocumentWhere,
	             |	CASE
	             |		WHEN DocumentTable.DoOperationsByOrders
	             |				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	             |			THEN DocumentTable.Order
	             |		ELSE UNDEFINED
	             |	END,
	             |	DocumentTable.GLAccountCustomerSettlements,
	             |	DocumentTable.SettlementsCurrency,
	             |	DocumentTable.SettlemensTypeWhere
	             |
	             |UNION ALL
	             |
	             |SELECT
	             |	Calendar.LineNumber,
	             |	VALUE(AccumulationRecordType.Receipt),
	             |	Calendar.Period,
	             |	Calendar.Company,
	             |	Calendar.PresentationCurrency,
	             |	Calendar.Counterparty,
	             |	Calendar.GLAccountCustomerSettlements,
	             |	Calendar.Contract,
	             |	Calendar.DocumentWhere,
	             |	CASE
	             |		WHEN Calendar.DoOperationsByOrders
	             |				AND Calendar.Order <> VALUE(Document.SalesOrder.EmptyRef)
	             |			THEN Calendar.Order
	             |		ELSE UNDEFINED
	             |	END,
	             |	Calendar.SettlementsCurrency,
	             |	Calendar.SettlemensTypeWhere,
	             |	0,
	             |	0,
	             |	0,
	             |	0,
	             |	Calendar.Amount,
	             |	Calendar.AmountCur,
	             |	CAST(&ExpectedPayments AS STRING(100))
	             |FROM
	             |	TemporaryTablePaymentCalendar AS Calendar
	             |
	             |INDEX BY
	             |	Company,
	             |	PresentationCurrency,
	             |	Counterparty,
	             |	Contract,
	             |	Currency,
	             |	Document,
	             |	Order,
	             |	SettlementsType,
	             |	GLAccount";
	
	Query.Execute();
	
	// Setting the exclusive lock for the controlled accounts receivable.
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsReceivable.Company AS Company,
	|	TemporaryTableAccountsReceivable.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableAccountsReceivable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsReceivable.Contract AS Contract,
	|	TemporaryTableAccountsReceivable.Document AS Document,
	|	TemporaryTableAccountsReceivable.Order AS Order,
	|	TemporaryTableAccountsReceivable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsReceivable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsReceivable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextCurrencyExchangeRateAccountsReceivable(Query.TempTablesManager, True, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsReceivable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefAccountSalesFromConsignee);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	&Ref AS Document,
	|	DocumentTable.BusinessLineSales AS BusinessLine,
	|	CASE
	|		WHEN DocumentTable.KeepBackCommissionFee
	|			THEN (DocumentTable.Amount - DocumentTable.VATAmount) - (DocumentTable.BrokerageAmount - DocumentTable.BrokerageVATAmount)    
	|			ELSE DocumentTable.Amount -  DocumentTable.VATAmount      
	|	END AS AmountIncome
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.Company AS Company,
	|	SUM(DocumentTable.Amount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|GROUP BY
	|	DocumentTable.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Item AS Item
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|ORDER BY
	|	LineNumber";
	
	ResultsArray = Query.ExecuteBatch();
	
	TableInventoryIncomeAndExpensesRetained = ResultsArray[0].Unload();
	SelectionOfQueryResult = ResultsArray[1].Select();

	TablePrepaymentIncomeAndExpensesRetained = TableInventoryIncomeAndExpensesRetained.Copy();
	TablePrepaymentIncomeAndExpensesRetained.Clear();
	
	If SelectionOfQueryResult.Next() Then
		AmountToBeWrittenOff = SelectionOfQueryResult.AmountToBeWrittenOff;
		For Each StringInventoryIncomeAndExpensesRetained In TableInventoryIncomeAndExpensesRetained Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountIncome <= AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				AmountToBeWrittenOff = AmountToBeWrittenOff - StringInventoryIncomeAndExpensesRetained.AmountIncome;
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountIncome > AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				StringPrepaymentIncomeAndExpensesRetained.AmountIncome = AmountToBeWrittenOff;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndIf;
	
	For Each StringPrepaymentIncomeAndExpensesRetained In TablePrepaymentIncomeAndExpensesRetained Do
		StringInventoryIncomeAndExpensesRetained = TableInventoryIncomeAndExpensesRetained.Add();
		FillPropertyValues(StringInventoryIncomeAndExpensesRetained, StringPrepaymentIncomeAndExpensesRetained);
		StringInventoryIncomeAndExpensesRetained.RecordType = AccumulationRecordType.Expense;
	EndDo;
	
	SelectionOfQueryResult = ResultsArray[2].Select();
	
	If SelectionOfQueryResult.Next() Then
		Item = SelectionOfQueryResult.Item;
	Else
		Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	EndIf;

	Query.Text =
	"SELECT
	|	Table.LineNumber AS LineNumber,
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Document AS Document,
	|	&Item AS Item,
	|	Table.BusinessLine AS BusinessLine,
	|	Table.AmountIncome AS AmountIncome
	|INTO TemporaryTablePrepaidIncomeAndExpensesRetained
	|FROM
	|	&Table AS Table";
	Query.SetParameter("Table", TablePrepaymentIncomeAndExpensesRetained);
	Query.SetParameter("Item", Item);
	
	Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", TableInventoryIncomeAndExpensesRetained);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableUnallocatedExpenses(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.Amount AS AmountIncome
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableUnallocatedExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefAccountSalesFromConsignee);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.DocumentDate AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS BusinessLine,
	|	DocumentTable.Item AS Item,
	|	-DocumentTable.Amount AS AmountIncome
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Period,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.BusinessLine,
	|	Table.Item,
	|	Table.AmountIncome
	|FROM
	|	TemporaryTablePrepaidIncomeAndExpensesRetained AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
// Cash flow projection table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", 					DocumentRefAccountSalesFromConsignee);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text =
	"SELECT
	|	AccountSalesFromConsignee.Ref AS Ref,
	|	AccountSalesFromConsignee.Date AS Date,
	|	AccountSalesFromConsignee.AmountIncludesVAT AS AmountIncludesVAT,
	|	AccountSalesFromConsignee.CashAssetType AS CashAssetType,
	|	AccountSalesFromConsignee.Contract AS Contract,
	|	AccountSalesFromConsignee.PettyCash AS PettyCash,
	|	AccountSalesFromConsignee.DocumentCurrency AS DocumentCurrency,
	|	AccountSalesFromConsignee.BankAccount AS BankAccount,
	|	AccountSalesFromConsignee.ExchangeRate AS ExchangeRate,
	|	AccountSalesFromConsignee.Multiplicity AS Multiplicity,
	|	AccountSalesFromConsignee.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	AccountSalesFromConsignee.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	AccountSalesFromConsignee.PaymentMethod AS PaymentMethod
	|INTO Document
	|FROM
	|	Document.AccountSalesFromConsignee AS AccountSalesFromConsignee
	|WHERE
	|	AccountSalesFromConsignee.Ref = &Ref
	|	AND AccountSalesFromConsignee.SetPaymentTerms
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountSalesFromConsigneePaymentCalendar.PaymentDate AS Period,
	|	Document.CashAssetType AS CashAssetType,
	|	Document.Ref AS Quote,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	Document.PettyCash AS PettyCash,
	|	Document.DocumentCurrency AS DocumentCurrency,
	|	Document.BankAccount AS BankAccount,
	|	Document.Ref AS Ref,
	|	Document.ExchangeRate AS ExchangeRate,
	|	Document.Multiplicity AS Multiplicity,
	|	Document.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	Document.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	CASE
	|		WHEN Document.AmountIncludesVAT
	|			THEN AccountSalesFromConsigneePaymentCalendar.PaymentAmount
	|		ELSE AccountSalesFromConsigneePaymentCalendar.PaymentAmount + AccountSalesFromConsigneePaymentCalendar.PaymentVATAmount
	|	END AS PaymentAmount,
	|	Document.PaymentMethod AS PaymentMethod
	|INTO PaymentCalendar
	|FROM
	|	Document AS Document
	|		INNER JOIN Document.AccountSalesFromConsignee.PaymentCalendar AS AccountSalesFromConsigneePaymentCalendar
	|		ON Document.Ref = AccountSalesFromConsigneePaymentCalendar.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON Document.Contract = CounterpartyContracts.Ref
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentCalendar.Period AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	PaymentCalendar.CashAssetType AS CashAssetType,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	PaymentCalendar.Quote AS Quote,
	|	VALUE(Catalog.CashFlowItems.PaymentFromCustomers) AS Item,
	|	CASE
	|		WHEN PaymentCalendar.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN PaymentCalendar.PettyCash
	|		WHEN PaymentCalendar.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN PaymentCalendar.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	PaymentCalendar.SettlementsCurrency AS Currency,
	|	CAST(PaymentCalendar.PaymentAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN PaymentCalendar.ExchangeRate * PaymentCalendar.ContractCurrencyMultiplicity / (PaymentCalendar.ContractCurrencyExchangeRate * PaymentCalendar.Multiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (PaymentCalendar.ExchangeRate * PaymentCalendar.ContractCurrencyMultiplicity / (PaymentCalendar.ContractCurrencyExchangeRate * PaymentCalendar.Multiplicity))
	|				END AS NUMBER(15, 2)) AS Amount,
	|	PaymentCalendar.PaymentMethod AS PaymentMethod
	|FROM
	|	PaymentCalendar AS PaymentCalendar";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	HeaderTable.Ref AS Ref,
	|	HeaderTable.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	HeaderTable.Counterparty AS Counterparty,
	|	HeaderTable.DocumentCurrency AS DocumentCurrency,
	|	HeaderTable.Contract AS Contract,
	|	HeaderTable.Counterparty AS StructuralUnit,
	|	HeaderTable.KeepBackCommissionFee AS KeepBackCommissionFee,
	|	HeaderTable.Department AS DepartmentSales,
	|	HeaderTable.Responsible AS Responsible,
	|	HeaderTable.IncludeVATInPrice AS IncludeVATInPrice,
	|	HeaderTable.AmountIncludesVAT AS AmountIncludesVAT,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN HeaderTable.AccountsReceivableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountsReceivableGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN HeaderTable.AdvancesReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AdvancesReceivedGLAccount,
	|	HeaderTable.SetPaymentTerms AS SetPaymentTerms,
	|	HeaderTable.ExchangeRate AS ExchangeRate,
	|	HeaderTable.Multiplicity AS Multiplicity,
	|	HeaderTable.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	HeaderTable.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity
	|INTO TemporaryHeader
	|FROM
	|	Document.AccountSalesFromConsignee AS HeaderTable
	|WHERE
	|	HeaderTable.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryHeader.Ref AS Ref,
	|	TemporaryHeader.Period AS Period,
	|	TemporaryHeader.Company AS Company,
	|	TemporaryHeader.PresentationCurrency AS PresentationCurrency,
	|	TemporaryHeader.Counterparty AS Counterparty,
	|	TemporaryHeader.DocumentCurrency AS DocumentCurrency,
	|	TemporaryHeader.Contract AS Contract,
	|	TemporaryHeader.StructuralUnit AS StructuralUnit,
	|	TemporaryHeader.KeepBackCommissionFee AS KeepBackCommissionFee,
	|	TemporaryHeader.DepartmentSales AS DepartmentSales,
	|	TemporaryHeader.Responsible AS Responsible,
	|	TemporaryHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	TemporaryHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	TemporaryHeader.SetPaymentTerms AS SetPaymentTerms,
	|	ISNULL(Counterparties.DoOperationsByContracts, FALSE) AS DoOperationsByContracts,
	|	ISNULL(Counterparties.DoOperationsByOrders, FALSE) AS DoOperationsByOrders,
	|	TemporaryHeader.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
	|	TemporaryHeader.AdvancesReceivedGLAccount AS AdvancesReceivedGLAccount,
	|	ISNULL(CounterpartyContracts.SettlementsCurrency, &PresentationCurrency) AS SettlementsCurrency,
	|	TemporaryHeader.ExchangeRate AS ExchangeRate,
	|	TemporaryHeader.Multiplicity AS Multiplicity,
	|	TemporaryHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	TemporaryHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity
	|INTO TemporaryHeaderTable
	|FROM
	|	TemporaryHeader AS TemporaryHeader
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON TemporaryHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON TemporaryHeader.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountSalesFromConsigneeInventory.LineNumber AS LineNumber,
	|	AccountSalesFromConsigneeInventory.ConnectionKey AS ConnectionKey,
	|	AccountSalesFromConsigneeInventory.ConnectionKeySerialNumbers AS ConnectionKeySerialNumbers,
	|	TemporaryHeaderTable.Ref AS Document,
	|	TemporaryHeaderTable.Period AS Period,
	|	TemporaryHeaderTable.Company AS Company,
	|	TemporaryHeaderTable.PresentationCurrency AS PresentationCurrency,
	|	TemporaryHeaderTable.Counterparty AS Counterparty,
	|	TemporaryHeaderTable.DocumentCurrency AS DocumentCurrency,
	|	TemporaryHeaderTable.DoOperationsByContracts AS DoOperationsByContracts,
	|	TemporaryHeaderTable.DoOperationsByOrders AS DoOperationsByOrders,
	|	TemporaryHeaderTable.AccountsReceivableGLAccount AS GLAccountCustomerSettlements,
	|	TemporaryHeaderTable.SettlementsCurrency AS SettlementsCurrency,
	|	TemporaryHeaderTable.Contract AS Contract,
	|	TemporaryHeaderTable.Counterparty AS StructuralUnit,
	|	TemporaryHeaderTable.KeepBackCommissionFee AS KeepBackCommissionFee,
	|	TemporaryHeaderTable.DepartmentSales AS DepartmentSales,
	|	TemporaryHeaderTable.Responsible AS Responsible,
	|	AccountSalesFromConsigneeInventory.Products.BusinessLine AS BusinessLineSales,
	|	AccountSalesFromConsigneeInventory.RevenueItem AS RevenueItem,
	|	AccountSalesFromConsigneeInventory.COGSItem AS COGSItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN AccountSalesFromConsigneeInventory.RevenueGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountStatementSales,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN AccountSalesFromConsigneeInventory.COGSGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountCost,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN AccountSalesFromConsigneeInventory.InventoryTransferredGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN AccountSalesFromConsigneeInventory.VATOutputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATOutputGLAccount,
	|	AccountSalesFromConsigneeInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN AccountSalesFromConsigneeInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN AccountSalesFromConsigneeInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	AccountSalesFromConsigneeInventory.Ownership AS Ownership,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS InventoryAccountType,
	|	CASE
	|		WHEN VALUETYPE(AccountSalesFromConsigneeInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN AccountSalesFromConsigneeInventory.Quantity
	|		ELSE AccountSalesFromConsigneeInventory.Quantity * AccountSalesFromConsigneeInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	AccountSalesFromConsigneeInventory.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN TemporaryHeaderTable.IncludeVATInPrice
	|				THEN 0
	|			ELSE AccountSalesFromConsigneeInventory.VATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN TemporaryHeaderTable.ExchangeRate / TemporaryHeaderTable.Multiplicity
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN TemporaryHeaderTable.Multiplicity / TemporaryHeaderTable.ExchangeRate
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(AccountSalesFromConsigneeInventory.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryHeaderTable.ExchangeRate / TemporaryHeaderTable.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN TemporaryHeaderTable.Multiplicity / TemporaryHeaderTable.ExchangeRate
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN TemporaryHeaderTable.IncludeVATInPrice
	|				THEN 0
	|			ELSE AccountSalesFromConsigneeInventory.VATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN TemporaryHeaderTable.ExchangeRate * TemporaryHeaderTable.ContractCurrencyMultiplicity / (TemporaryHeaderTable.ContractCurrencyExchangeRate * TemporaryHeaderTable.Multiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (TemporaryHeaderTable.ExchangeRate * TemporaryHeaderTable.ContractCurrencyMultiplicity / (TemporaryHeaderTable.ContractCurrencyExchangeRate * TemporaryHeaderTable.Multiplicity))
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CASE
	|		WHEN TemporaryHeaderTable.IncludeVATInPrice
	|			THEN 0
	|		ELSE AccountSalesFromConsigneeInventory.VATAmount
	|	END AS VATAmountDocCur,
	|	AccountSalesFromConsigneeInventory.Total AS AmountDocCur,
	|	CAST(AccountSalesFromConsigneeInventory.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TemporaryHeaderTable.ExchangeRate * TemporaryHeaderTable.ContractCurrencyMultiplicity / (TemporaryHeaderTable.ContractCurrencyExchangeRate * TemporaryHeaderTable.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (TemporaryHeaderTable.ExchangeRate * TemporaryHeaderTable.ContractCurrencyMultiplicity / (TemporaryHeaderTable.ContractCurrencyExchangeRate * TemporaryHeaderTable.Multiplicity))
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	CAST(CASE
	|			WHEN TemporaryHeaderTable.AmountIncludesVAT
	|				THEN AccountSalesFromConsigneeInventory.TransmissionAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN TemporaryHeaderTable.ExchangeRate / TemporaryHeaderTable.Multiplicity
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN TemporaryHeaderTable.Multiplicity / TemporaryHeaderTable.ExchangeRate
	|					END
	|			ELSE (AccountSalesFromConsigneeInventory.TransmissionAmount + AccountSalesFromConsigneeInventory.TransmissionVATAmount) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN TemporaryHeaderTable.ExchangeRate / TemporaryHeaderTable.Multiplicity
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN TemporaryHeaderTable.Multiplicity / TemporaryHeaderTable.ExchangeRate
	|				END
	|		END AS NUMBER(15, 2)) AS Cost,
	|	CAST(CASE
	|			WHEN TemporaryHeaderTable.IncludeVATInPrice
	|				THEN 0
	|			ELSE AccountSalesFromConsigneeInventory.BrokerageVATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN TemporaryHeaderTable.ExchangeRate / TemporaryHeaderTable.Multiplicity
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN TemporaryHeaderTable.Multiplicity / TemporaryHeaderTable.ExchangeRate
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageVATAmount,
	|	CAST(CASE
	|			WHEN TemporaryHeaderTable.AmountIncludesVAT
	|				THEN AccountSalesFromConsigneeInventory.BrokerageAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN TemporaryHeaderTable.ExchangeRate / TemporaryHeaderTable.Multiplicity
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN TemporaryHeaderTable.Multiplicity / TemporaryHeaderTable.ExchangeRate
	|					END
	|			ELSE (AccountSalesFromConsigneeInventory.BrokerageAmount + AccountSalesFromConsigneeInventory.BrokerageVATAmount) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN TemporaryHeaderTable.ExchangeRate / TemporaryHeaderTable.Multiplicity
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN TemporaryHeaderTable.Multiplicity / TemporaryHeaderTable.ExchangeRate
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageAmount,
	|	CAST(CASE
	|			WHEN TemporaryHeaderTable.IncludeVATInPrice
	|				THEN 0
	|			ELSE AccountSalesFromConsigneeInventory.BrokerageVATAmount
	|		END AS NUMBER(15, 2)) AS BrokerageVATAmountDocCur,
	|	CAST(CASE
	|			WHEN TemporaryHeaderTable.AmountIncludesVAT
	|				THEN AccountSalesFromConsigneeInventory.BrokerageAmount
	|			ELSE AccountSalesFromConsigneeInventory.BrokerageAmount + AccountSalesFromConsigneeInventory.BrokerageVATAmount
	|		END AS NUMBER(15, 2)) AS BrokerageAmountDocCur,
	|	CAST(CASE
	|			WHEN TemporaryHeaderTable.AmountIncludesVAT
	|				THEN AccountSalesFromConsigneeInventory.BrokerageAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN TemporaryHeaderTable.ExchangeRate * TemporaryHeaderTable.ContractCurrencyMultiplicity / (TemporaryHeaderTable.ContractCurrencyExchangeRate * TemporaryHeaderTable.Multiplicity)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (TemporaryHeaderTable.ExchangeRate * TemporaryHeaderTable.ContractCurrencyMultiplicity / (TemporaryHeaderTable.ContractCurrencyExchangeRate * TemporaryHeaderTable.Multiplicity))
	|					END
	|			ELSE (AccountSalesFromConsigneeInventory.BrokerageAmount + AccountSalesFromConsigneeInventory.BrokerageVATAmount) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN TemporaryHeaderTable.ExchangeRate * TemporaryHeaderTable.ContractCurrencyMultiplicity / (TemporaryHeaderTable.ContractCurrencyExchangeRate * TemporaryHeaderTable.Multiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (TemporaryHeaderTable.ExchangeRate * TemporaryHeaderTable.ContractCurrencyMultiplicity / (TemporaryHeaderTable.ContractCurrencyExchangeRate * TemporaryHeaderTable.Multiplicity))
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageAmountCur,
	|	CAST(CASE
	|			WHEN TemporaryHeaderTable.IncludeVATInPrice
	|				THEN 0
	|			ELSE AccountSalesFromConsigneeInventory.BrokerageVATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN TemporaryHeaderTable.ExchangeRate * TemporaryHeaderTable.ContractCurrencyMultiplicity / (TemporaryHeaderTable.ContractCurrencyExchangeRate * TemporaryHeaderTable.Multiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (TemporaryHeaderTable.ExchangeRate * TemporaryHeaderTable.ContractCurrencyMultiplicity / (TemporaryHeaderTable.ContractCurrencyExchangeRate * TemporaryHeaderTable.Multiplicity))
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageVATAmountCur,
	|	CASE
	|		WHEN AccountSalesFromConsigneeInventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN AccountSalesFromConsigneeInventory.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	TemporaryHeaderTable.SetPaymentTerms AS SetPaymentTerms,
	|	AccountSalesFromConsigneeInventory.SalesRep AS SalesRep,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject
	|INTO TemporaryTableInventory
	|FROM
	|	Document.AccountSalesFromConsignee.Inventory AS AccountSalesFromConsigneeInventory
	|		INNER JOIN TemporaryHeaderTable AS TemporaryHeaderTable
	|		ON (TemporaryHeaderTable.Ref = AccountSalesFromConsigneeInventory.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	TemporaryHeaderTable.Period AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	TemporaryHeaderTable.Counterparty AS Counterparty,
	|	TemporaryHeaderTable.DoOperationsByContracts AS DoOperationsByContracts,
	|	TemporaryHeaderTable.DoOperationsByOrders AS DoOperationsByOrders,
	|	TemporaryHeaderTable.AccountsReceivableGLAccount AS GLAccountCustomerSettlements,
	|	TemporaryHeaderTable.AdvancesReceivedGLAccount AS CustomerAdvancesGLAccount,
	|	TemporaryHeaderTable.Contract AS Contract,
	|	TemporaryHeaderTable.SettlementsCurrency AS SettlementsCurrency,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE DocumentTable.Document.Item
	|	END AS Item,
	|	DocumentTable.Document.Date AS DocumentDate,
	|	CASE
	|		WHEN DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLineSales,
	|	VALUE(Enum.SettlementsTypes.Advance) AS SettlementsType,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	TemporaryHeaderTable.Ref AS DocumentWhere,
	|	DocumentTable.Document AS Document,
	|	SUM(DocumentTable.PaymentAmount) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur,
	|	TemporaryHeaderTable.SetPaymentTerms AS SetPaymentTerms
	|INTO TemporaryTablePrepayment
	|FROM
	|	Document.AccountSalesFromConsignee.Prepayment AS DocumentTable
	|		INNER JOIN TemporaryHeaderTable AS TemporaryHeaderTable
	|		ON DocumentTable.Ref = TemporaryHeaderTable.Ref
	|
	|GROUP BY
	|	TemporaryHeaderTable.Ref,
	|	DocumentTable.Document,
	|	TemporaryHeaderTable.Period,
	|	TemporaryHeaderTable.Counterparty,
	|	TemporaryHeaderTable.Contract,
	|	CASE
	|		WHEN DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	TemporaryHeaderTable.SettlementsCurrency,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE DocumentTable.Document.Item
	|	END,
	|	DocumentTable.Document.Date,
	|	TemporaryHeaderTable.DoOperationsByContracts,
	|	TemporaryHeaderTable.DoOperationsByOrders,
	|	TemporaryHeaderTable.SetPaymentTerms,
	|	TemporaryHeaderTable.AccountsReceivableGLAccount,
	|	TemporaryHeaderTable.AdvancesReceivedGLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountSalesFromConsigneeSerialNumbers.ConnectionKey AS ConnectionKey,
	|	AccountSalesFromConsigneeSerialNumbers.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.AccountSalesFromConsignee.SerialNumbers AS AccountSalesFromConsigneeSerialNumbers
	|		INNER JOIN TemporaryHeader AS TemporaryHeader
	|		ON AccountSalesFromConsigneeSerialNumbers.Ref = TemporaryHeader.Ref
	|WHERE
	|	&UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendar.LineNumber AS LineNumber,
	|	Calendar.Ref AS Ref,
	|	Calendar.PaymentDate AS PaymentDate,
	|	Calendar.PaymentAmount AS PaymentAmount,
	|	Calendar.PaymentVATAmount AS PaymentVATAmount
	|INTO TemporaryTablePaymentCalendarWithoutGroup
	|FROM
	|	Document.AccountSalesFromConsignee.PaymentCalendar AS Calendar
	|		INNER JOIN TemporaryHeader AS TemporaryHeader
	|		ON Calendar.Ref = TemporaryHeader.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendar.LineNumber AS LineNumber,
	|	Calendar.PaymentDate AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	Header.Counterparty AS Counterparty,
	|	Header.DoOperationsByContracts AS DoOperationsByContracts,
	|	Header.DoOperationsByOrders AS DoOperationsByOrders,
	|	Header.AccountsReceivableGLAccount AS GLAccountCustomerSettlements,
	|	Header.Contract AS Contract,
	|	Header.SettlementsCurrency AS SettlementsCurrency,
	|	Header.Ref AS DocumentWhere,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	UNDEFINED AS Order,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN CAST(Calendar.PaymentAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN Header.ExchangeRate / Header.Multiplicity
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN Header.Multiplicity / Header.ExchangeRate
	|					END AS NUMBER(15, 2))
	|		ELSE CAST((Calendar.PaymentAmount + Calendar.PaymentVATAmount) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN Header.ExchangeRate / Header.Multiplicity
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN Header.Multiplicity / Header.ExchangeRate
	|				END AS NUMBER(15, 2))
	|	END AS Amount,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN CAST(Calendar.PaymentAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity))
	|					END AS NUMBER(15, 2))
	|		ELSE CAST((Calendar.PaymentAmount + Calendar.PaymentVATAmount) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity))
	|				END AS NUMBER(15, 2))
	|	END AS AmountCur
	|INTO TemporaryTablePaymentCalendarWithoutGroupWithHeader
	|FROM
	|	TemporaryTablePaymentCalendarWithoutGroup AS Calendar
	|		INNER JOIN TemporaryHeaderTable AS Header
	|		ON Calendar.Ref = Header.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(Calendar.LineNumber) AS LineNumber,
	|	Calendar.Period AS Period,
	|	Calendar.Company AS Company,
	|	Calendar.PresentationCurrency AS PresentationCurrency,
	|	Calendar.Counterparty AS Counterparty,
	|	Calendar.DoOperationsByContracts AS DoOperationsByContracts,
	|	Calendar.DoOperationsByOrders AS DoOperationsByOrders,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Calendar.GLAccountCustomerSettlements
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountCustomerSettlements,
	|	Calendar.Contract AS Contract,
	|	Calendar.SettlementsCurrency AS SettlementsCurrency,
	|	Calendar.DocumentWhere AS DocumentWhere,
	|	Calendar.SettlemensTypeWhere AS SettlemensTypeWhere,
	|	Calendar.Order AS Order,
	|	SUM(Calendar.Amount) AS Amount,
	|	SUM(Calendar.AmountCur) AS AmountCur
	|INTO TemporaryTablePaymentCalendar
	|FROM
	|	TemporaryTablePaymentCalendarWithoutGroupWithHeader AS Calendar
	|
	|GROUP BY
	|	Calendar.Period,
	|	Calendar.Company,
	|	Calendar.Counterparty,
	|	Calendar.DoOperationsByContracts,
	|	Calendar.DoOperationsByOrders,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Calendar.GLAccountCustomerSettlements
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	Calendar.Contract,
	|	Calendar.SettlementsCurrency,
	|	Calendar.DocumentWhere,
	|	Calendar.SettlemensTypeWhere,
	|	Calendar.Order,
	|	Calendar.PresentationCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTablePaymentCalendarWithoutGroup
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTablePaymentCalendarWithoutGroupWithHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryHeaderTable";
	
	Query.SetParameter("Ref"                 , DocumentRefAccountSalesFromConsignee);
	Query.SetParameter("Company"             , StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseCharacteristics"  , StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches"          , StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseSerialNumbers"    , StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("ExchangeRateMethod"  , StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	
	GenerateTableSales(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	GenerateTableStockTransferredToThirdParties(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	GenerateTableCustomerAccounts(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	GenerateTableInventory(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	
	GenerateTableAccountingEntriesData(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRefAccountSalesFromConsignee, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefAccountSalesFromConsignee,
			StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefAccountSalesFromConsignee,
			StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

// Generates a table of values that contains the data for the SerialNumbersInWarranty information register.
// Tables of values saves into the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRef, StructureAdditionalProperties)
	
	If DocumentRef.SerialNumbers.Count()=0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableInventory.Period AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Expense) AS Operation,
	|	SerialNumbers.SerialNumber AS SerialNumber,
	|	TemporaryTableInventory.Products AS Products,
	|	TemporaryTableInventory.Characteristic AS Characteristic
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
	|		ON TemporaryTableInventory.ConnectionKeySerialNumbers = SerialNumbers.ConnectionKey";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefAccountSalesFromConsignee, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the "RegisterRecordsInventoryChange", "TransfersStockTransferredToThirdPartiesChange"
	// temprorary tables contain records, it is necessary to control the sale of goods.
	
	If StructureTemporaryTables.RegisterRecordsInventoryChange
		Or StructureTemporaryTables.RegisterRecordsStockTransferredToThirdPartiesChange
		Or StructureTemporaryTables.RegisterRecordsAccountsReceivableChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.PresentationCurrency) AS PresentationCurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Ownership) AS OwnershipPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.InventoryAccountType) AS InventoryAccountTypePresentation,
		|	REFPRESENTATION(InventoryBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
		|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
		|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|		LEFT JOIN AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, Products, Characteristic, Batch, Ownership, StructuralUnit, InventoryAccountType, CostObject) IN
		|					(SELECT
		|						RegisterRecordsInventoryChange.Company AS Company,
		|						RegisterRecordsInventoryChange.PresentationCurrency AS PresentationCurrency,
		|						RegisterRecordsInventoryChange.Products AS Products,
		|						RegisterRecordsInventoryChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryChange.Batch AS Batch,
		|						RegisterRecordsInventoryChange.Ownership AS Ownership,
		|						RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryChange.InventoryAccountType AS InventoryAccountType,
		|						RegisterRecordsInventoryChange.CostObject AS CostObject
		|					FROM
		|						RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange)) AS InventoryBalances
		|		ON RegisterRecordsInventoryChange.Company = InventoryBalances.Company
		|			AND RegisterRecordsInventoryChange.PresentationCurrency = InventoryBalances.PresentationCurrency
		|			AND RegisterRecordsInventoryChange.Products = InventoryBalances.Products
		|			AND RegisterRecordsInventoryChange.Characteristic = InventoryBalances.Characteristic
		|			AND RegisterRecordsInventoryChange.Batch = InventoryBalances.Batch
		|			AND RegisterRecordsInventoryChange.Ownership = InventoryBalances.Ownership
		|			AND RegisterRecordsInventoryChange.StructuralUnit = InventoryBalances.StructuralUnit
		|			AND RegisterRecordsInventoryChange.InventoryAccountType = InventoryBalances.InventoryAccountType
		|			AND RegisterRecordsInventoryChange.CostObject = InventoryBalances.CostObject
		|WHERE
		|	ISNULL(InventoryBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsStockTransferredToThirdPartiesChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsStockTransferredToThirdPartiesChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsStockTransferredToThirdPartiesChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsStockTransferredToThirdPartiesChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsStockTransferredToThirdPartiesChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsStockTransferredToThirdPartiesChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsStockTransferredToThirdPartiesChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(StockTransferredToThirdPartiesBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsStockTransferredToThirdPartiesChange.QuantityChange, 0) + ISNULL(StockTransferredToThirdPartiesBalances.QuantityBalance, 0) AS BalanceStockTransferredToThirdParties,
		|	ISNULL(StockTransferredToThirdPartiesBalances.QuantityBalance, 0) AS QuantityBalanceStockTransferredToThirdParties
		|FROM
		|	RegisterRecordsStockTransferredToThirdPartiesChange AS RegisterRecordsStockTransferredToThirdPartiesChange
		|		LEFT JOIN AccumulationRegister.StockTransferredToThirdParties.Balance(
		|				&ControlTime,
		|				(Company, Products, Characteristic, Batch, Counterparty, Order) IN
		|					(SELECT
		|						RegisterRecordsStockTransferredToThirdPartiesChange.Company AS Company,
		|						RegisterRecordsStockTransferredToThirdPartiesChange.Products AS Products,
		|						RegisterRecordsStockTransferredToThirdPartiesChange.Characteristic AS Characteristic,
		|						RegisterRecordsStockTransferredToThirdPartiesChange.Batch AS Batch,
		|						RegisterRecordsStockTransferredToThirdPartiesChange.Counterparty AS Counterparty,
		|						RegisterRecordsStockTransferredToThirdPartiesChange.Order AS Order
		|					FROM
		|						RegisterRecordsStockTransferredToThirdPartiesChange AS RegisterRecordsStockTransferredToThirdPartiesChange)) AS StockTransferredToThirdPartiesBalances
		|		ON RegisterRecordsStockTransferredToThirdPartiesChange.Company = StockTransferredToThirdPartiesBalances.Company
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Products = StockTransferredToThirdPartiesBalances.Products
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Characteristic = StockTransferredToThirdPartiesBalances.Characteristic
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Batch = StockTransferredToThirdPartiesBalances.Batch
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Counterparty = StockTransferredToThirdPartiesBalances.Counterparty
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Order = StockTransferredToThirdPartiesBalances.Order
		|WHERE
		|	ISNULL(StockTransferredToThirdPartiesBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsAccountsReceivableChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.PresentationCurrency) AS PresentationCurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Contract.SettlementsCurrency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Document) AS DocumentPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.SettlementsType) AS CalculationsTypesPresentation,
		|	FALSE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsAccountsReceivableChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountChange AS AmountChange,
		|	RegisterRecordsAccountsReceivableChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite - ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AdvanceAmountsReceived,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountOfOutstandingDebt,
		|	ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange
		|		LEFT JOIN AccumulationRegister.AccountsReceivable.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, Counterparty, Contract, Document, Order, SettlementsType) IN
		|					(SELECT
		|						RegisterRecordsAccountsReceivableChange.Company AS Company,
		|						RegisterRecordsAccountsReceivableChange.PresentationCurrency AS PresentationCurrency,
		|						RegisterRecordsAccountsReceivableChange.Counterparty AS Counterparty,
		|						RegisterRecordsAccountsReceivableChange.Contract AS Contract,
		|						RegisterRecordsAccountsReceivableChange.Document AS Document,
		|						RegisterRecordsAccountsReceivableChange.Order AS Order,
		|						RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType
		|					FROM
		|						RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange)) AS AccountsReceivableBalances
		|		ON RegisterRecordsAccountsReceivableChange.Company = AccountsReceivableBalances.Company
		|			AND RegisterRecordsAccountsReceivableChange.PresentationCurrency = AccountsReceivableBalances.PresentationCurrency
		|			AND RegisterRecordsAccountsReceivableChange.Counterparty = AccountsReceivableBalances.Counterparty
		|			AND RegisterRecordsAccountsReceivableChange.Contract = AccountsReceivableBalances.Contract
		|			AND RegisterRecordsAccountsReceivableChange.Document = AccountsReceivableBalances.Document
		|			AND RegisterRecordsAccountsReceivableChange.Order = AccountsReceivableBalances.Order
		|			AND RegisterRecordsAccountsReceivableChange.SettlementsType = AccountsReceivableBalances.SettlementsType
		|WHERE
		|	CASE
		|			WHEN RegisterRecordsAccountsReceivableChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|				THEN ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) > 0
		|			ELSE ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) < 0
		|		END
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty() Then
			DocumentObjectAccountSalesFromConsignee = DocumentRefAccountSalesFromConsignee.GetObject();
		EndIf;
		
		// Negative balance of inventory.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectAccountSalesFromConsignee, QueryResultSelection, Cancel);
		EndIf;
		
		// The negative balance of transferred inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToStockTransferredToThirdPartiesRegisterErrors(DocumentObjectAccountSalesFromConsignee, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocumentObjectAccountSalesFromConsignee, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Internal

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

#Region InfobaseUpdate

Procedure FillDocumentTax() Export 
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountSalesFromConsignee.Ref AS Ref,
	|	SUM(AccountSalesFromConsigneeInventory.VATAmount) AS DocumentTax
	|FROM
	|	Document.AccountSalesFromConsignee.Inventory AS AccountSalesFromConsigneeInventory
	|		INNER JOIN Document.AccountSalesFromConsignee AS AccountSalesFromConsignee
	|		ON AccountSalesFromConsigneeInventory.Ref = AccountSalesFromConsignee.Ref
	|			AND (AccountSalesFromConsignee.DocumentTax = 0)
	|			AND (AccountSalesFromConsigneeInventory.VATAmount > 0)
	|
	|GROUP BY
	|	AccountSalesFromConsignee.Ref";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DocumentObject = Selection.Ref.GetObject();
		If DocumentObject = Undefined Then
			Continue;
		EndIf;
		
		DocumentObject.DocumentTax = Selection.DocumentTax;
		
		Try
			
			InfobaseUpdate.WriteObject(DocumentObject);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Documents.AccountSalesFromConsignee,
				,
				ErrorDescription);
				
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf