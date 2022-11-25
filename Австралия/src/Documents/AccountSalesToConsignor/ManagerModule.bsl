#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region PrintInterface

// Procedure prints document. You can send printing to the screen or printer and print required number of copies.
//
//  Printing layout name is passed
// as a parameter, find layout name by the passed name in match.
//
// Parameters:
//  TemplateName - String, layout name.
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "ServicesAcceptanceCertificate") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"ServicesAcceptanceCertificate",
			NStr("en = 'Services acceptance note'; ru = 'Акт предоставленных услуг';pl = 'Notą przyjęcia usług';es_ES = 'Nota de aceptación de servicios';es_CO = 'Nota de aceptación de servicios';tr = 'Servis kabul notu';it = 'Nota di accettazione servizio';de = 'Dienstleistungsannahmebestätigung'"),
			PrintCertificate(ObjectsArray, PrintObjects, PrintParameters.Result));
		
	EndIf;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "AccountSalesToConsignor") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"AccountSalesToConsignor",
			NStr("en = 'Principal report'; ru = 'Основной доклад';pl = 'Raport główny';es_ES = 'Informe principal';es_CO = 'Informe principal';tr = 'Ana rapor';it = 'Report importo iniziale del prestito';de = 'Hauptbericht'"),
			AccountSalesToConsignorPrinting(ObjectsArray, PrintObjects, PrintParameters.Result));
		
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
	PrintCommand.ID = "ServicesAcceptanceCertificate,AccountSalesToConsignor";
	PrintCommand.Presentation = NStr("en = 'Customizable document set'; ru = 'Настраиваемый комплект документов';pl = 'Dostosowywalny zestaw dokumentów';es_ES = 'Conjunto de documentos personalizables';es_CO = 'Conjunto de documentos personalizables';tr = 'Özelleştirilebilir belge seti';it = 'Set di documenti personalizzabili';de = 'Anpassbarer Dokumentensatz'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "ServicesAcceptanceCertificate";
	PrintCommand.Presentation = NStr("en = 'Acceptance note'; ru = 'Акт выполненных работ';pl = 'Nota przyjęcia';es_ES = 'Nota de aceptación';es_CO = 'Nota de aceptación';tr = 'Kabul notu';it = 'Nota di accettazione';de = 'Akzeptanzschein'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 2;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "AccountSalesToConsignor";
	PrintCommand.Presentation = NStr("en = 'Account sales statement'; ru = 'Отчет комитенту';pl = 'Wyciąg z raportu sprzedaży';es_ES = 'Declaración de las ventas de cuentas';es_CO = 'Declaración de las ventas de cuentas';tr = 'Hesap satışı uzlaşması';it = 'Estratto vendite in conto vendita';de = 'Verkaufsbericht Auszug'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 3;
	
EndProcedure

#EndRegion

#Region InventoryOwnership

Function InventoryOwnershipParameters(DocObject) Export
	
	Parameters = New Structure;
	
	Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.CounterpartysInventory);
	Parameters.Insert("Counterparty", DocObject.Counterparty);
	Parameters.Insert("Contract", DocObject.Contract);
	
	Return Parameters;
	
EndFunction

#EndRegion

#Region Batches

Function BatchCheckFillingParameters(DocObject) Export
	
	Parameters = New Structure;
	
	Parameters.Insert("UnconditionalFillCheck", True);
	
	Warehouses = New Array;
	
	WarehouseData = New Structure;
	WarehouseData.Insert("Warehouse", Undefined);
	WarehouseData.Insert("TrackingArea", "Inbound_FromSupplier");
	
	Warehouses.Add(WarehouseData);
	
	Parameters.Insert("Warehouses", Warehouses);
	
	Return Parameters;
	
EndFunction

#EndRegion

Function DocumentVATRate(DocumentRef) Export
	
	Return DriveServer.DocumentVATRate(DocumentRef);
	
EndFunction

#EndRegion

#Region PostingProcedures

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	SUM(TemporaryTable.VATAmount) AS VATAmount,
	|	SUM(TemporaryTable.BrokerageVATAmount) AS BrokerageVATAmount,
	|	SUM(TemporaryTable.VATAmountCur) AS VATAmountCur,
	|	SUM(TemporaryTable.BrokerageVATAmountCur) AS BrokerageVATAmountCur,
	|	SUM(TemporaryTable.CostVAT) AS CostVAT,
	|	SUM(TemporaryTable.CostVATCur) AS CostVATCur
	|FROM
	|	TemporaryTableInventory AS TemporaryTable
	|
	|GROUP BY
	|	TemporaryTable.Period,
	|	TemporaryTable.Company";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	VATAmount = 0;
	VATAmountCur = 0;
	BrokerageVATAmount=0;
	BrokerageVATAmountCur = 0;
	CostVAT = 0;
	CostVATCur = 0;
	
	While Selection.Next() Do  
		VATAmount = Selection.VATAmount;
		VATAmountCur = Selection.VATAmountCur;
		BrokerageVATAmount = Selection.BrokerageVATAmount;
		BrokerageVATAmountCur = Selection.BrokerageVATAmountCur;
		CostVAT = Selection.CostVAT;
		CostVATCur = Selection.CostVATCur;
	EndDo;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableAccountingJournalEntries.LineNumber AS LineNumber,
	|	TableAccountingJournalEntries.Period AS Period,
	|	TableAccountingJournalEntries.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements AS AccountDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN CASE
	|					WHEN TableAccountingJournalEntries.KeepBackCommissionFee
	|						THEN TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount - (TableAccountingJournalEntries.Cost - TableAccountingJournalEntries.CostVAT) + (TableAccountingJournalEntries.BrokerageAmount - TableAccountingJournalEntries.BrokerageVATAmount)
	|					ELSE TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount - (TableAccountingJournalEntries.Cost - TableAccountingJournalEntries.CostVAT)
	|				END
	|		ELSE 0
	|	END AS AmountCurDr,
	|	TableAccountingJournalEntries.AccountStatementSales AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.KeepBackCommissionFee
	|			THEN TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount - (TableAccountingJournalEntries.Cost - TableAccountingJournalEntries.CostVAT) + (TableAccountingJournalEntries.BrokerageAmount - TableAccountingJournalEntries.BrokerageVATAmount)
	|		ELSE TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount - (TableAccountingJournalEntries.Cost - TableAccountingJournalEntries.CostVAT)
	|	END AS Amount,
	|	&IncomeReflection AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.BrokerageAmount > 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TableAccountingJournalEntries.LineNumber,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN CASE
	|					WHEN TableAccountingJournalEntries.KeepBackCommissionFee
	|						THEN TableAccountingJournalEntries.Cost - TableAccountingJournalEntries.CostVAT - (TableAccountingJournalEntries.BrokerageAmount - TableAccountingJournalEntries.BrokerageVATAmount)
	|					ELSE TableAccountingJournalEntries.Cost - TableAccountingJournalEntries.CostVAT
	|				END
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.CostPriceCur - TableAccountingJournalEntries.CostVATCur - (TableAccountingJournalEntries.BrokerageAmountCur - TableAccountingJournalEntries.BrokerageVATAmountCur)
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.KeepBackCommissionFee
	|			THEN TableAccountingJournalEntries.Cost - TableAccountingJournalEntries.CostVAT - (TableAccountingJournalEntries.BrokerageAmount - TableAccountingJournalEntries.BrokerageVATAmount)
	|		ELSE TableAccountingJournalEntries.Cost - TableAccountingJournalEntries.CostVAT
	|	END,
	|	&ComitentDebt,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccountVendorSettlements,
	|	CASE
	|		WHEN DocumentTable.GLAccountVendorSettlementsCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccountVendorSettlementsCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.VendorAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.VendorAdvancesGLAccountCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.VendorAdvancesGLAccountCurrency
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
	|		DocumentTable.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|		DocumentTable.VendorAdvancesGLAccountCurrency AS VendorAdvancesGLAccountCurrency,
	|		DocumentTable.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|		DocumentTable.GLAccountVendorSettlementsCurrency AS GLAccountVendorSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|		SUM(DocumentTable.AmountCur) AS AmountCur,
	|		SUM(DocumentTable.Amount) AS Amount
	|	FROM
	|		(SELECT
	|			DocumentTable.Period AS Period,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|			DocumentTable.VendorAdvancesGLAccount.Currency AS VendorAdvancesGLAccountCurrency,
	|			DocumentTable.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|			DocumentTable.GLAccountVendorSettlements.Currency AS GLAccountVendorSettlementsCurrency,
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
	|			DocumentTable.Counterparty.VendorAdvancesGLAccount,
	|			DocumentTable.Counterparty.VendorAdvancesGLAccount.Currency,
	|			DocumentTable.Counterparty.GLAccountVendorSettlements,
	|			DocumentTable.Counterparty.GLAccountVendorSettlements.Currency,
	|			DocumentTable.Currency,
	|			0,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Company,
	|		DocumentTable.VendorAdvancesGLAccount,
	|		DocumentTable.VendorAdvancesGLAccountCurrency,
	|		DocumentTable.GLAccountVendorSettlements,
	|		DocumentTable.GLAccountVendorSettlementsCurrency,
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
	|	4,
	|	1,
	|	TableAccountingJournalEntries.Date,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN &NegativeExchangeDifferenceAccountOfAccounting
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
	|			THEN TableAccountingJournalEntries.GLAccount
	|		ELSE &PositiveExchangeDifferenceGLAccount
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
	|			THEN TableAccountingJournalEntries.AmountOfExchangeDifferences
	|		ELSE -TableAccountingJournalEntries.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	(SELECT
	|		TableOfExchangeRateDifferencesAccountsPayable.Date AS Date,
	|		TableOfExchangeRateDifferencesAccountsPayable.Company AS Company,
	|		TableOfExchangeRateDifferencesAccountsPayable.GLAccount AS GLAccount,
	|		TableOfExchangeRateDifferencesAccountsPayable.GLAccountForeignCurrency AS GLAccountForeignCurrency,
	|		TableOfExchangeRateDifferencesAccountsPayable.Currency AS Currency,
	|		SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.GLAccount AS GLAccount,
	|			DocumentTable.GLAccount.Currency AS GLAccountForeignCurrency,
	|			DocumentTable.Currency AS Currency,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
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
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableOfExchangeRateDifferencesAccountsPayable
	|	
	|	GROUP BY
	|		TableOfExchangeRateDifferencesAccountsPayable.Date,
	|		TableOfExchangeRateDifferencesAccountsPayable.Company,
	|		TableOfExchangeRateDifferencesAccountsPayable.GLAccount,
	|		TableOfExchangeRateDifferencesAccountsPayable.GLAccountForeignCurrency,
	|		TableOfExchangeRateDifferencesAccountsPayable.Currency
	|	
	|	HAVING
	|		(SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) <= -0.005)) AS TableAccountingJournalEntries
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	5,
	|	TableAccountingJournalEntries.LineNumber,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN CASE
	|					WHEN TableAccountingJournalEntries.KeepBackCommissionFee
	|						THEN &VATAmount - &CostVAT + &BrokerageVATAmount
	|					ELSE &VATAmount - &CostVAT
	|				END
	|		ELSE 0
	|	END,
	|	&TextVAT,
	|	UNDEFINED,
	|	0,
	|	CASE
	|		WHEN TableAccountingJournalEntries.KeepBackCommissionFee
	|			THEN &VATAmount - &CostVAT + &BrokerageVATAmount
	|		ELSE &VATAmount - &CostVAT
	|	END,
	|	&VAT,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	&BrokerageVATAmount > 0
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	6,
	|	TableAccountingJournalEntries.LineNumber,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&TextVAT,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN &CostVATCur - &BrokerageVATAmountCur
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.KeepBackCommissionFee
	|			THEN &CostVAT - &BrokerageVATAmount
	|		ELSE &CostVAT
	|	END,
	|	&VAT,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	&CostVAT - &BrokerageVATAmount > 0
	|
	|UNION ALL
	|
	|SELECT
	|	7,
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
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("SetOffAdvancePayment",							NStr("en = 'Advance payment clearing'; ru = 'Зачет аванса';pl = 'Rozliczanie zaliczki';es_ES = 'Amortización de pagos anticipados';es_CO = 'Amortización de pagos anticipados';tr = 'Avans ödeme mahsuplaştırılması';it = 'Annullamento del pagamento anticipato';de = 'Verrechnung der Vorauszahlung'", MainLanguageCode));
	Query.SetParameter("IncomeReflection",								NStr("en = 'Revenue'; ru = 'Выручка от продажи';pl = 'Przychód';es_ES = 'Ingreso';es_CO = 'Ingreso';tr = 'Gelir';it = 'Ricavo';de = 'Erlös'", MainLanguageCode));
	Query.SetParameter("ComitentDebt",									NStr("en = 'Accounts payable recognition'; ru = 'Задолженность комитенту';pl = 'Zobowiązania przyjęte do ewidencji';es_ES = 'Reconocimiento de las cuentas por pagar';es_CO = 'Reconocimiento de las cuentas a pagar';tr = 'Borçlu hesapların doğrulanması';it = 'Riconoscimento di debiti';de = 'Aufnahme von Offenen Posten Kreditoren'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency",							StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("VAT",											NStr("en = 'VAT'; ru = 'НДС';pl = 'Kwota VAT';es_ES = 'IVA';es_CO = 'IVA';tr = 'KDV';it = 'IVA';de = 'USt.'", MainLanguageCode));
	Query.SetParameter("TextVAT",										Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput"));
	Query.SetParameter("VATAmount",										VATAmount);
	Query.SetParameter("VATAmountCur",									VATAmountCur);
	Query.SetParameter("BrokerageVATAmount",							BrokerageVATAmount);
	Query.SetParameter("BrokerageVATAmountCur",							BrokerageVATAmountCur);
	Query.SetParameter("CostVATCur",									CostVATCur);
	Query.SetParameter("CostVAT",										CostVAT);
	Query.SetParameter("Ref",											DocumentRefReportToCommissioner);

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
Procedure GenerateTableStockReceivedFromThirdParties(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	MIN(TableStockReceivedFromThirdParties.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableStockReceivedFromThirdParties.Period AS Period,
	|	TableStockReceivedFromThirdParties.Company AS Company,
	|	TableStockReceivedFromThirdParties.Products AS Products,
	|	TableStockReceivedFromThirdParties.Characteristic AS Characteristic,
	|	TableStockReceivedFromThirdParties.Batch AS Batch,
	|	TableStockReceivedFromThirdParties.Counterparty AS Counterparty,
	|	CASE
	|		WHEN TableStockReceivedFromThirdParties.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TableStockReceivedFromThirdParties.PurchaseOrder
	|		ELSE UNDEFINED
	|	END AS Order,
	|	TableStockReceivedFromThirdParties.GLAccount AS GLAccount,
	|	SUM(TableStockReceivedFromThirdParties.Quantity) AS Quantity,
	|	&InventoryReception AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableInventory AS TableStockReceivedFromThirdParties
	|
	|GROUP BY
	|	TableStockReceivedFromThirdParties.Period,
	|	TableStockReceivedFromThirdParties.Company,
	|	TableStockReceivedFromThirdParties.Products,
	|	TableStockReceivedFromThirdParties.Characteristic,
	|	TableStockReceivedFromThirdParties.Batch,
	|	TableStockReceivedFromThirdParties.Counterparty,
	|	CASE
	|		WHEN TableStockReceivedFromThirdParties.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TableStockReceivedFromThirdParties.PurchaseOrder
	|		ELSE UNDEFINED
	|	END,
	|	TableStockReceivedFromThirdParties.GLAccount";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("InventoryReception", "");
	Query.SetParameter("InventoryreceptionPostponedIncome", NStr("en = 'Inventory increase'; ru = 'Оприходование запасов';pl = 'Zwiększenie zapasów';es_ES = 'Aumento de inventario';es_CO = 'Aumento de inventario';tr = 'Stok artırma';it = 'Aumento scorte';de = 'Bestandserhöhung'", MainLanguageCode));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockReceivedFromThirdParties", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSales(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
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
	|	0 AS Quantity,
	|	0 AS Amount,
	|	0 AS VATAmount,
	|	0 AS AmountCur,
	|	0 AS VATAmountCur,
	|	SUM(CASE
	|			WHEN TableSales.KeepBackCommissionFee
	|				THEN TableSales.Cost - TableSales.BrokerageAmount
	|			ELSE TableSales.Cost
	|		END - TableSales.CostVAT) AS Cost,
	|	FALSE AS OfflineRecord
	|INTO TableSales
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
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableSales.Period AS Period,
	|	TableSales.Company AS Company,
	|	TableSales.PresentationCurrency AS PresentationCurrency,
	|	TableSales.Counterparty AS Counterparty,
	|	TableSales.Currency AS Currency,
	|	TableSales.Products AS Products,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Batch AS Batch,
	|	TableSales.Ownership AS Ownership,
	|	TableSales.SalesOrder AS SalesOrder,
	|	TableSales.SalesRep AS SalesRep,
	|	TableSales.Document AS Document,
	|	TableSales.VATRate AS VATRate,
	|	TableSales.Department AS Department,
	|	TableSales.Responsible AS Responsible,
	|	TableSales.Quantity AS Quantity,
	|	TableSales.Amount AS Amount,
	|	TableSales.VATAmount AS VATAmount,
	|	TableSales.AmountCur AS AmountCur,
	|	TableSales.VATAmountCur AS VATAmountCur,
	|	TableSales.Cost AS Cost,
	|	TableSales.OfflineRecord AS OfflineRecord
	|FROM
	|	TableSales AS TableSales
	|WHERE
	|	TableSales.Cost > 0
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
	|	OfflineRecords.Amount,
	|	OfflineRecords.VATAmount,
	|	OfflineRecords.AmountCur,
	|	OfflineRecords.VATAmountCur,
	|	OfflineRecords.Cost,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Sales AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	Query.SetParameter("Ref", DocumentRefReportToCommissioner);
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
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
	|				THEN TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount - (TableIncomeAndExpenses.Cost - TableIncomeAndExpenses.CostVAT) + (TableIncomeAndExpenses.BrokerageAmount - TableIncomeAndExpenses.BrokerageVATAmount)
	|			ELSE TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount - (TableIncomeAndExpenses.Cost - TableIncomeAndExpenses.CostVAT)
	|		END) AS AmountIncome,
	|	0 AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableIncomeAndExpenses
	|WHERE
	|	(TableIncomeAndExpenses.KeepBackCommissionFee
	|				AND TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.Cost + TableIncomeAndExpenses.BrokerageAmount > 0
	|			OR NOT TableIncomeAndExpenses.KeepBackCommissionFee
	|				AND TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.Cost > 0)
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
	|			THEN &NegativeExchangeDifferenceAccountOfAccounting
	|		ELSE &PositiveExchangeDifferenceGLAccount
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	FALSE
	|FROM
	|	(SELECT
	|		TableOfExchangeRateDifferencesAccountsPayable.Date AS Date,
	|		TableOfExchangeRateDifferencesAccountsPayable.Company AS Company,
	|		TableOfExchangeRateDifferencesAccountsPayable.PresentationCurrency AS PresentationCurrency,
	|		SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.PresentationCurrency AS PresentationCurrency,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
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
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableOfExchangeRateDifferencesAccountsPayable
	|	
	|	GROUP BY
	|		TableOfExchangeRateDifferencesAccountsPayable.Date,
	|		TableOfExchangeRateDifferencesAccountsPayable.Company,
	|		TableOfExchangeRateDifferencesAccountsPayable.PresentationCurrency
	|	
	|	HAVING
	|		(SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) <= -0.005)) AS DocumentTable";

	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("FXIncomeItem", Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem", Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("IncomeReflection",								NStr("en = 'Revenue'; ru = 'Отражение доходов';pl = 'Przychód';es_ES = 'Ingreso';es_CO = 'Ingreso';tr = 'Gelir';it = 'Ricavo';de = 'Erlös'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",							DocumentRefReportToCommissioner);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfLiabilityToVendor",	NStr("en = 'Accounts payable recognition'; ru = 'Возникновение обязательств перед комитентом';pl = 'Zobowiązania przyjęte do ewidencji';es_ES = 'Reconocimiento de las cuentas por pagar';es_CO = 'Reconocimiento de las cuentas a pagar';tr = 'Borçlu hesapların doğrulanması';it = 'Riconoscimento di debiti';de = 'Aufnahme von Offenen Posten Kreditoren'", MainLanguageCode));
	Query.SetParameter("AdvanceCredit",					NStr("en = 'Advance payment clearing'; ru = 'Зачет аванса';pl = 'Rozliczanie zaliczki';es_ES = 'Amortización del pago adelantado';es_CO = 'Amortización de pagos anticipados';tr = 'Avans ödeme mahsuplaştırılması';it = 'Annullamento del pagamento anticipato';de = 'Verrechnung der Vorauszahlung'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExpectedPayments",				NStr("en = 'Expected payment'; ru = 'Ожидаемый платеж';pl = 'Oczekiwana płatność';es_ES = 'Pago esperado';es_CO = 'Pago esperado';tr = 'Beklenen ödeme';it = 'Pagamento previsto';de = 'Erwartete Zahlung'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod", 			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", 		GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.GLAccountVendorSettlements AS GLAccount,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE UNDEFINED
	|	END AS Order,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	SUM(CASE
	|			WHEN DocumentTable.KeepBackCommissionFee
	|				THEN DocumentTable.Cost - DocumentTable.BrokerageAmount
	|			ELSE DocumentTable.Cost
	|		END) AS Amount,
	|	SUM(CASE
	|			WHEN DocumentTable.KeepBackCommissionFee
	|				THEN DocumentTable.CostPriceCur - DocumentTable.BrokerageAmountCur
	|			ELSE DocumentTable.CostPriceCur
	|		END) AS AmountCur,
	|	SUM(CASE
	|			WHEN DocumentTable.KeepBackCommissionFee
	|				THEN DocumentTable.Cost - DocumentTable.BrokerageAmount
	|			ELSE DocumentTable.Cost
	|		END) AS AmountForBalance,
	|	SUM(CASE
	|			WHEN DocumentTable.KeepBackCommissionFee
	|				THEN DocumentTable.CostPriceCur - DocumentTable.BrokerageAmountCur
	|			ELSE DocumentTable.CostPriceCur
	|		END) AS AmountCurForBalance,
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE CASE
	|					WHEN DocumentTable.KeepBackCommissionFee
	|						THEN DocumentTable.Cost - DocumentTable.BrokerageAmount
	|					ELSE DocumentTable.Cost
	|				END
	|		END) AS AmountForPayment,
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE CASE
	|					WHEN DocumentTable.KeepBackCommissionFee
	|						THEN DocumentTable.CostPriceCur - DocumentTable.BrokerageAmountCur
	|					ELSE DocumentTable.CostPriceCur
	|				END
	|		END) AS AmountForPaymentCur,
	|	CAST(&AppearenceOfLiabilityToVendor AS STRING(100)) AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsPayable
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
	|				AND DocumentTable.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountVendorSettlements
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.VendorAdvancesGLAccount,
	|	DocumentTable.Contract,
	|	DocumentTable.Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
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
	|	DocumentTable.VendorAdvancesGLAccount,
	|	DocumentTable.Contract,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlementsType,
	|	DocumentTable.Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.GLAccountVendorSettlements,
	|	DocumentTable.Contract,
	|	DocumentTable.DocumentWhere,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
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
	|	DocumentTable.GLAccountVendorSettlements,
	|	DocumentTable.Contract,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere,
	|	DocumentTable.DocumentWhere,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	Calendar.Period,
	|	Calendar.Company,
	|	Calendar.PresentationCurrency,
	|	Calendar.Counterparty,
	|	Calendar.AccountsPayableGLAccount,
	|	Calendar.Contract,
	|	Calendar.DocumentWhere,
	|	CASE
	|		WHEN Calendar.DoOperationsByOrders
	|				AND Calendar.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
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
	
	// Setting the exclusive lock for the controlled balances of accounts payable.
	Query.Text = 
	"SELECT
	|	TemporaryTableAccountsPayable.Company AS Company,
	|	TemporaryTableAccountsPayable.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableAccountsPayable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsPayable.Contract AS Contract,
	|	TemporaryTableAccountsPayable.Document AS Document,
	|	TemporaryTableAccountsPayable.Order AS Order,
	|	TemporaryTableAccountsPayable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsPayable";

	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsPayable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesAccountsPayable(Query.TempTablesManager, True, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefReportToCommissioner);
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
	|			THEN DocumentTable.Cost - DocumentTable.CostVAT - (DocumentTable.BrokerageAmount - DocumentTable.BrokerageVATAmount)
	|		ELSE DocumentTable.Cost - DocumentTable.CostVAT
	|	END AS AmountExpense
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
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountExpense <= AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				AmountToBeWrittenOff = AmountToBeWrittenOff - StringInventoryIncomeAndExpensesRetained.AmountExpense;
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountExpense > AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				StringPrepaymentIncomeAndExpensesRetained.AmountExpense = AmountToBeWrittenOff;
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
		Item = Catalogs.CashFlowItems.PaymentToVendor;
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
	|	Table.AmountExpense AS AmountExpense
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
Procedure GenerateTableUnallocatedExpenses(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
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
	|	DocumentTable.Amount AS AmountExpense
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
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefReportToCommissioner);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	Table.Period,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.BusinessLine,
	|	Table.Item,
	|	Table.AmountExpense
	|FROM
	|	TemporaryTablePrepaidIncomeAndExpensesRetained AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

// Cash flow projection table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref"                 , DocumentRefReportToCommissioner);
	Query.SetParameter("PointInTime"         , New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company"             , StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod"  , StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text =
	"SELECT
	|	AccountSalesToConsignor.Ref AS Ref,
	|	AccountSalesToConsignor.AmountIncludesVAT AS AmountIncludesVAT,
	|	AccountSalesToConsignor.Date AS Date,
	|	AccountSalesToConsignor.CashAssetType AS CashAssetType,
	|	AccountSalesToConsignor.Contract AS Contract,
	|	AccountSalesToConsignor.PettyCash AS PettyCash,
	|	AccountSalesToConsignor.DocumentCurrency AS DocumentCurrency,
	|	AccountSalesToConsignor.BankAccount AS BankAccount,
	|	AccountSalesToConsignor.ExchangeRate AS ExchangeRate,
	|	AccountSalesToConsignor.Multiplicity AS Multiplicity,
	|	AccountSalesToConsignor.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	AccountSalesToConsignor.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	AccountSalesToConsignor.PaymentMethod AS PaymentMethod
	|INTO Document
	|FROM
	|	Document.AccountSalesToConsignor AS AccountSalesToConsignor
	|WHERE
	|	AccountSalesToConsignor.Ref = &Ref
	|	AND AccountSalesToConsignor.SetPaymentTerms
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountSalesToConsignorPaymentCalendar.PaymentDate AS Period,
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
	|			THEN AccountSalesToConsignorPaymentCalendar.PaymentAmount
	|		ELSE AccountSalesToConsignorPaymentCalendar.PaymentAmount + AccountSalesToConsignorPaymentCalendar.PaymentVATAmount
	|	END AS PaymentAmount,
	|	Document.PaymentMethod AS PaymentMethod
	|INTO PaymentCalendar
	|FROM
	|	Document AS Document
	|		INNER JOIN Document.AccountSalesToConsignor.PaymentCalendar AS AccountSalesToConsignorPaymentCalendar
	|		ON Document.Ref = AccountSalesToConsignorPaymentCalendar.Ref
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
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	CASE
	|		WHEN PaymentCalendar.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN PaymentCalendar.PettyCash
	|		WHEN PaymentCalendar.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN PaymentCalendar.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	PaymentCalendar.SettlementsCurrency AS Currency,
	|	CAST(-PaymentCalendar.PaymentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN PaymentCalendar.ExchangeRate * PaymentCalendar.ContractCurrencyMultiplicity / (PaymentCalendar.ContractCurrencyExchangeRate * PaymentCalendar.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (PaymentCalendar.ExchangeRate * PaymentCalendar.ContractCurrencyMultiplicity / (PaymentCalendar.ContractCurrencyExchangeRate * PaymentCalendar.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	PaymentCalendar.PaymentMethod AS PaymentMethod
	|FROM
	|	PaymentCalendar AS PaymentCalendar";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefReportToCommissioner, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	AccountSalesToConsignor.Ref AS Ref,
	|	AccountSalesToConsignor.Date AS Date,
	|	AccountSalesToConsignor.Counterparty AS Counterparty,
	|	AccountSalesToConsignor.DocumentCurrency AS DocumentCurrency,
	|	AccountSalesToConsignor.AccountsPayableGLAccount AS AccountsPayableGLAccount,
	|	AccountSalesToConsignor.AdvancesPaidGLAccount AS AdvancesPaidGLAccount,
	|	AccountSalesToConsignor.Contract AS Contract,
	|	AccountSalesToConsignor.KeepBackCommissionFee AS KeepBackCommissionFee,
	|	AccountSalesToConsignor.Department AS Department,
	|	AccountSalesToConsignor.Responsible AS Responsible,
	|	AccountSalesToConsignor.IncludeVATInPrice AS IncludeVATInPrice,
	|	AccountSalesToConsignor.AmountIncludesVAT AS AmountIncludesVAT,
	|	AccountSalesToConsignor.VATCommissionFeePercent AS VATCommissionFeePercent,
	|	AccountSalesToConsignor.SetPaymentTerms AS SetPaymentTerms,
	|	AccountSalesToConsignor.ExchangeRate AS ExchangeRate,
	|	AccountSalesToConsignor.Multiplicity AS Multiplicity,
	|	AccountSalesToConsignor.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	AccountSalesToConsignor.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	ISNULL(CounterpartyRef.DoOperationsByContracts, FALSE) AS DoOperationsByContracts,
	|	ISNULL(CounterpartyRef.DoOperationsByOrders, FALSE) AS DoOperationsByOrders,
	|	ISNULL(CounterpartyContractsRef.SettlementsCurrency, VALUE(Catalog.Currencies.EmptyRef)) AS SettlementsCurrency
	|INTO AccountSalesToConsignorHeader
	|FROM
	|	Document.AccountSalesToConsignor AS AccountSalesToConsignor
	|		LEFT JOIN Catalog.Counterparties AS CounterpartyRef
	|		ON AccountSalesToConsignor.Counterparty = CounterpartyRef.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContractsRef
	|		ON AccountSalesToConsignor.Contract = CounterpartyContractsRef.Ref
	|WHERE
	|	AccountSalesToConsignor.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountSalesToConsignorInventory.LineNumber AS LineNumber,
	|	AccountSalesToConsignorInventory.ConnectionKey AS ConnectionKey,
	|	Header.Ref AS Ref,
	|	Header.Ref AS Document,
	|	Header.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	Header.Counterparty AS Counterparty,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.DoOperationsByContracts AS DoOperationsByContracts,
	|	Header.DoOperationsByOrders AS DoOperationsByOrders,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Header.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountVendorSettlements,
	|	Header.Contract AS Contract,
	|	Header.SettlementsCurrency AS SettlementsCurrency,
	|	Header.KeepBackCommissionFee AS KeepBackCommissionFee,
	|	Header.Department AS DepartmentSales,
	|	Header.Responsible AS Responsible,
	|	ProductsRef.BusinessLine AS BusinessLineSales,
	|	AccountSalesToConsignorInventory.RevenueItem AS RevenueItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductsRef.BusinessLine.GLAccountRevenueFromSales
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountStatementSales,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductsRef.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	AccountSalesToConsignorInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN AccountSalesToConsignorInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN AccountSalesToConsignorInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	AccountSalesToConsignorInventory.Ownership AS Ownership,
	|	CASE
	|		WHEN VALUETYPE(AccountSalesToConsignorInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN AccountSalesToConsignorInventory.Quantity
	|		ELSE AccountSalesToConsignorInventory.Quantity * AccountSalesToConsignorInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	AccountSalesToConsignorInventory.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN Header.IncludeVATInPrice
	|				THEN 0
	|			ELSE AccountSalesToConsignorInventory.VATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN Header.ExchangeRate / Header.Multiplicity
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN Header.Multiplicity / Header.ExchangeRate
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(AccountSalesToConsignorInventory.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN Header.ExchangeRate / Header.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN Header.Multiplicity / Header.ExchangeRate
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN Header.IncludeVATInPrice
	|				THEN 0
	|			ELSE AccountSalesToConsignorInventory.ReceiptVATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN Header.ExchangeRate / Header.Multiplicity
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN Header.Multiplicity / Header.ExchangeRate
	|				END
	|		END AS NUMBER(15, 2)) AS CostVAT,
	|	CAST(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN AccountSalesToConsignorInventory.AmountReceipt * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN Header.ExchangeRate / Header.Multiplicity
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN Header.Multiplicity / Header.ExchangeRate
	|					END
	|			ELSE (AccountSalesToConsignorInventory.AmountReceipt + AccountSalesToConsignorInventory.ReceiptVATAmount) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN Header.ExchangeRate / Header.Multiplicity
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN Header.Multiplicity / Header.ExchangeRate
	|				END
	|		END AS NUMBER(15, 2)) AS Cost,
	|	CAST(CASE
	|			WHEN Header.IncludeVATInPrice
	|				THEN 0
	|			ELSE AccountSalesToConsignorInventory.BrokerageVATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN Header.ExchangeRate / Header.Multiplicity
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN Header.Multiplicity / Header.ExchangeRate
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageVATAmount,
	|	CAST(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN AccountSalesToConsignorInventory.BrokerageAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN Header.ExchangeRate / Header.Multiplicity
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN Header.Multiplicity / Header.ExchangeRate
	|					END
	|			ELSE (AccountSalesToConsignorInventory.BrokerageAmount + AccountSalesToConsignorInventory.BrokerageVATAmount) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN Header.ExchangeRate / Header.Multiplicity
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN Header.Multiplicity / Header.ExchangeRate
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageAmount,
	|	CAST(CASE
	|			WHEN Header.IncludeVATInPrice
	|				THEN 0
	|			ELSE AccountSalesToConsignorInventory.BrokerageVATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity))
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageVATAmountCur,
	|	CAST(CASE
	|			WHEN Header.IncludeVATInPrice
	|				THEN 0
	|			ELSE AccountSalesToConsignorInventory.ReceiptVATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity))
	|				END
	|		END AS NUMBER(15, 2)) AS CostVATCur,
	|	CAST(CASE
	|			WHEN Header.IncludeVATInPrice
	|				THEN 0
	|			ELSE AccountSalesToConsignorInventory.VATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity))
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN AccountSalesToConsignorInventory.BrokerageAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity))
	|					END
	|			ELSE (AccountSalesToConsignorInventory.BrokerageAmount + AccountSalesToConsignorInventory.BrokerageVATAmount) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity))
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageAmountCur,
	|	CAST(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN AccountSalesToConsignorInventory.AmountReceipt * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity))
	|					END
	|			ELSE (AccountSalesToConsignorInventory.AmountReceipt + AccountSalesToConsignorInventory.ReceiptVATAmount) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity))
	|				END
	|		END AS NUMBER(15, 2)) AS CostPriceCur,
	|	AccountSalesToConsignorInventory.ReceiptVATAmount AS ReceiptVATAmount,
	|	AccountSalesToConsignorInventory.SalesOrder AS SalesOrder,
	|	AccountSalesToConsignorInventory.SalesRep AS SalesRep,
	|	AccountSalesToConsignorInventory.PurchaseOrder AS PurchaseOrder,
	|	Header.VATCommissionFeePercent AS VATCommissionFeePercent,
	|	Header.SetPaymentTerms AS SetPaymentTerms
	|INTO TemporaryTableInventory
	|FROM
	|	AccountSalesToConsignorHeader AS Header
	|		INNER JOIN Document.AccountSalesToConsignor.Inventory AS AccountSalesToConsignorInventory
	|		ON Header.Ref = AccountSalesToConsignorInventory.Ref
	|		INNER JOIN Catalog.Products AS ProductsRef
	|		ON (AccountSalesToConsignorInventory.Products = ProductsRef.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	Header.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	Header.Counterparty AS Counterparty,
	|	Header.DoOperationsByContracts AS DoOperationsByContracts,
	|	Header.DoOperationsByOrders AS DoOperationsByOrders,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Header.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountVendorSettlements,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Header.AdvancesPaidGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VendorAdvancesGLAccount,
	|	Header.Contract AS Contract,
	|	Header.SettlementsCurrency AS SettlementsCurrency,
	|	DocumentTable.Order AS Order,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLineSales,
	|	VALUE(Enum.SettlementsTypes.Advance) AS SettlementsType,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	&Ref AS DocumentWhere,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.Document) = TYPE(Document.ExpenseReport)
	|				OR VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE DocumentTable.Document.Item
	|	END AS Item,
	|	DocumentTable.Document.Date AS DocumentDate,
	|	SUM(DocumentTable.PaymentAmount) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur,
	|	Header.SetPaymentTerms AS SetPaymentTerms
	|INTO TemporaryTablePrepayment
	|FROM
	|	AccountSalesToConsignorHeader AS Header
	|		INNER JOIN Document.AccountSalesToConsignor.Prepayment AS DocumentTable
	|		ON Header.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.Document,
	|	Header.Date,
	|	Header.Counterparty,
	|	Header.Contract,
	|	DocumentTable.Order,
	|	Header.SettlementsCurrency,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.Document) = TYPE(Document.ExpenseReport)
	|				OR VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE DocumentTable.Document.Item
	|	END,
	|	DocumentTable.Document.Date,
	|	Header.DoOperationsByContracts,
	|	Header.DoOperationsByOrders,
	|	Header.SetPaymentTerms,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Header.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Header.AdvancesPaidGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountSalesToConsignorSerialNumbers.ConnectionKey AS ConnectionKey,
	|	AccountSalesToConsignorSerialNumbers.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.AccountSalesToConsignor.SerialNumbers AS AccountSalesToConsignorSerialNumbers
	|WHERE
	|	AccountSalesToConsignorSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers
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
	|	Document.AccountSalesToConsignor.PaymentCalendar AS Calendar
	|WHERE
	|	Calendar.Ref = &Ref
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
	|	Header.AccountsPayableGLAccount AS AccountsPayableGLAccount,
	|	Header.Contract AS Contract,
	|	Header.SettlementsCurrency AS SettlementsCurrency,
	|	&Ref AS DocumentWhere,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	VALUE(Document.PurchaseOrder.EmptyRef) AS Order,
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
	|	AccountSalesToConsignorHeader AS Header
	|		INNER JOIN TemporaryTablePaymentCalendarWithoutGroup AS Calendar
	|		ON Header.Ref = Calendar.Ref
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
	|			THEN Calendar.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountsPayableGLAccount,
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
	|			THEN Calendar.AccountsPayableGLAccount
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
	|DROP TemporaryTablePaymentCalendarWithoutGroupWithHeader";
	
	Query.SetParameter("Ref"                  , DocumentRefReportToCommissioner);
	Query.SetParameter("Company"              , StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency" ,	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseCharacteristics"   , StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches"           , StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseSerialNumbers"     , StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("ExchangeRateMethod"   , StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefReportToCommissioner, StructureAdditionalProperties);

	GenerateTableStockReceivedFromThirdParties(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	GenerateTableSales(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	
	GenerateTableAccountingEntriesData(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefReportToCommissioner, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefReportToCommissioner, StructureAdditionalProperties);
		
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
	|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefReportToCommissioner, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsStockReceivedFromThirdPartiesChange" contain records,
	// control products implementation.
	If StructureTemporaryTables.RegisterRecordsStockReceivedFromThirdPartiesChange
	 OR StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange Then
	
		Query = New Query(
		"SELECT
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(StockReceivedFromThirdPartiesBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsStockReceivedFromThirdPartiesChange.QuantityChange, 0) + ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) AS BalanceStockReceivedFromThirdParties,
		|	ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) AS QuantityBalanceStockReceivedFromThirdParties
		|FROM
		|	RegisterRecordsStockReceivedFromThirdPartiesChange AS RegisterRecordsStockReceivedFromThirdPartiesChange
		|		LEFT JOIN AccumulationRegister.StockReceivedFromThirdParties.Balance(
		|				&ControlTime,
		|				(Company, Products, Characteristic, Batch, Counterparty, Order) IN
		|					(SELECT
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Company AS Company,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Products AS Products,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic AS Characteristic,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Batch AS Batch,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Counterparty AS Counterparty,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Order AS Order
		|					FROM
		|						RegisterRecordsStockReceivedFromThirdPartiesChange AS RegisterRecordsStockReceivedFromThirdPartiesChange)) AS StockReceivedFromThirdPartiesBalances
		|		ON RegisterRecordsStockReceivedFromThirdPartiesChange.Company = StockReceivedFromThirdPartiesBalances.Company
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Products = StockReceivedFromThirdPartiesBalances.Products
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic = StockReceivedFromThirdPartiesBalances.Characteristic
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Batch = StockReceivedFromThirdPartiesBalances.Batch
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Counterparty = StockReceivedFromThirdPartiesBalances.Counterparty
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Order = StockReceivedFromThirdPartiesBalances.Order
		|WHERE
		|	ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSuppliersSettlementsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.PresentationCurrency) AS PresentationCurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract.SettlementsCurrency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Document) AS DocumentPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.SettlementsType) AS CalculationsTypesPresentation,
		|	FALSE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsSuppliersSettlementsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountChange AS AmountChange,
		|	RegisterRecordsSuppliersSettlementsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite - ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AdvanceAmountsPaid,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange + ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountOfOutstandingDebt,
		|	ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange
		|		LEFT JOIN AccumulationRegister.AccountsPayable.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, Counterparty, Contract, Document, Order, SettlementsType) IN
		|					(SELECT
		|						RegisterRecordsSuppliersSettlementsChange.Company AS Company,
		|						RegisterRecordsSuppliersSettlementsChange.PresentationCurrency AS PresentationCurrency,
		|						RegisterRecordsSuppliersSettlementsChange.Counterparty AS Counterparty,
		|						RegisterRecordsSuppliersSettlementsChange.Contract AS Contract,
		|						RegisterRecordsSuppliersSettlementsChange.Document AS Document,
		|						RegisterRecordsSuppliersSettlementsChange.Order AS Order,
		|						RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType
		|					FROM
		|						RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange)) AS AccountsPayableBalances
		|		ON RegisterRecordsSuppliersSettlementsChange.Company = AccountsPayableBalances.Company
		|			AND RegisterRecordsSuppliersSettlementsChange.PresentationCurrency = AccountsPayableBalances.PresentationCurrency
		|			AND RegisterRecordsSuppliersSettlementsChange.Counterparty = AccountsPayableBalances.Counterparty
		|			AND RegisterRecordsSuppliersSettlementsChange.Contract = AccountsPayableBalances.Contract
		|			AND RegisterRecordsSuppliersSettlementsChange.Document = AccountsPayableBalances.Document
		|			AND RegisterRecordsSuppliersSettlementsChange.Order = AccountsPayableBalances.Order
		|			AND RegisterRecordsSuppliersSettlementsChange.SettlementsType = AccountsPayableBalances.SettlementsType
		|WHERE
		|	CASE
		|			WHEN RegisterRecordsSuppliersSettlementsChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|				THEN ISNULL(AccountsPayableBalances.AmountCurBalance, 0) > 0
		|			ELSE ISNULL(AccountsPayableBalances.AmountCurBalance, 0) < 0
		|		END
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty() Then
			DocumentObjectAccountSalesToConsignor = DocumentRefReportToCommissioner.GetObject();
		EndIf;
		
		// Negative balance of inventory received.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToStockReceivedFromThirdPartiesRegisterErrors(DocumentObjectAccountSalesToConsignor, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectAccountSalesToConsignor, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Inventory" Then
		IncomeAndExpenseStructure.Insert("RevenueItem", StructureData.RevenueItem);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Return New Structure;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export
	
	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	If StructureData.Property("CounterpartyGLAccounts") Then
		
		GLAccountsForFilling.Insert("AccountsPayableGLAccount", ObjectParameters.AccountsPayableGLAccount);
		GLAccountsForFilling.Insert("AdvancesPaidGLAccount", ObjectParameters.AdvancesPaidGLAccount);
		
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// Function generates tabular document as certificate of
// services provided to the amount of reward
// 
Function PrintCertificate(ObjectsArray, PrintObjects, PrintParams = Undefined)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_SalesAccountSalesToConsignor_ServicesReport";
	
	Query = New Query;
	
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	Query.Text =
	"SELECT ALLOWED
	|	SalesAccountSalesToConsignor.Ref,
	|	SalesAccountSalesToConsignor.Number,
	|	SalesAccountSalesToConsignor.Date,
	|	SalesAccountSalesToConsignor.Contract,
	|	SalesAccountSalesToConsignor.Counterparty AS Recipient,
	|	SalesAccountSalesToConsignor.Company AS Company,
	|	SalesAccountSalesToConsignor.Company AS Vendor,
	|	SalesAccountSalesToConsignor.DocumentAmount,
	|	SalesAccountSalesToConsignor.DocumentCurrency,
	|	SalesAccountSalesToConsignor.VATCommissionFeePercent,
	|	SUM(AccountSalesToConsignorInventory.BrokerageAmount) AS Amount
	|FROM
	|	Document.AccountSalesToConsignor.Inventory AS AccountSalesToConsignorInventory
	|		LEFT JOIN Document.AccountSalesToConsignor AS SalesAccountSalesToConsignor
	|		ON AccountSalesToConsignorInventory.Ref = SalesAccountSalesToConsignor.Ref
	|WHERE
	|	SalesAccountSalesToConsignor.Ref IN(&ObjectsArray)
	|
	|GROUP BY
	|	SalesAccountSalesToConsignor.Ref,
	|	SalesAccountSalesToConsignor.DocumentCurrency,
	|	SalesAccountSalesToConsignor.VATCommissionFeePercent,
	|	SalesAccountSalesToConsignor.Number,
	|	SalesAccountSalesToConsignor.Date,
	|	SalesAccountSalesToConsignor.Contract,
	|	SalesAccountSalesToConsignor.Counterparty,
	|	SalesAccountSalesToConsignor.Company,
	|	SalesAccountSalesToConsignor.DocumentAmount,
	|	SalesAccountSalesToConsignor.Company";

	Header = Query.Execute().Select();
	
	FirstDocument = True;
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument	= False;
		FirstLineNumber	= SpreadsheetDocument.TableHeight + 1;
		
		Template = GetTemplate("ServicesReport");
		
		// MultilingualSupport
		If PrintParams = Undefined Then
			LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
		Else
			LanguageCode = PrintParams.LanguageCode;
		EndIf;
		
		Template.LanguageCode = LanguageCode;
		If LanguageCode <> CurrentLanguage().LanguageCode Then 
			SessionParameters.LanguageCodeForOutput = LanguageCode;
		EndIf;
		// End MultilingualSupport
		
		TemplateArea = Template.GetArea("Header");
		TemplateArea.Parameters.Fill(Header);
		
		InfoAboutCompany	= DriveServer.InfoAboutLegalEntityIndividual(
			Header.Company,
			Header.Date,
			,
			,
			,
			LanguageCode);
		CompanyPresentation	= DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr");
		
		InfoAboutCounterparty		= DriveServer.InfoAboutLegalEntityIndividual(
			Header.Recipient,
			Header.Date,
			,
			,
			,
			LanguageCode);
		PresentationOfCounterparty	= DriveServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr");
		
		TemplateArea.Parameters.VendorPresentation = CompanyPresentation;
		TemplateArea.Parameters.RecipientPresentation = PresentationOfCounterparty;
		
		TemplateArea.Parameters.HeaderText = NStr("en = 'Acceptance note'; ru = 'Акт выполненных работ';pl = 'Nota przyjęcia';es_ES = 'Nota de aceptación';es_CO = 'Nota de aceptación';tr = 'Kabul notu';it = 'Nota di accettazione';de = 'Akzeptanzschein'", LanguageCode);
		
		FormatPaymentDocumentAmountInWords = CurrencyRateOperations.GenerateAmountInWords(
				Header.Amount,
				Header.DocumentCurrency);
				
		TemplateArea.Parameters.TextAboutSumInWords	= StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Commission fee amount is %1, including VAT %2'; ru = 'Сумма комиссии составляет %1, включая НДС %2';pl = 'Kwota prowizji wynosi %1, łącznie z VAT %2';es_ES = 'Importe de la comisión es %1, el IVA incluido %2';es_CO = 'Importe de la comisión es %1, el IVA incluido %2';tr = 'Komisyon ücreti tutarı KDV %2 dahil %1 şeklindedir';it = 'L''importo delle commissioni è %1, inclusa IVA %2';de = 'Die Provisionszahlung beträgt %1, inklusive USt. %2.'", LanguageCode),
			FormatPaymentDocumentAmountInWords,
			Header.VATCommissionFeePercent);
			
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	Return SpreadsheetDocument;

EndFunction

// Function generates tabular document with invoice
// printing form developed by coordinator
//
// Returns:
//  Spreadsheet document - invoice printing form
//
Function AccountSalesToConsignorPrinting(ObjectsArray, PrintObjects, PrintParams = Undefined)
	
	SpreadsheetDocument	= New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_SalesAccountSalesToConsignor_SalesAccountSalesToConsignor";
	Template				= GetTemplate("SalesAccountSalesToConsignor");
	
	// MultilingualSupport
	If PrintParams = Undefined Then
		LanguageCode = CommonClientServer.DefaultLanguageCode();
	Else
		LanguageCode = PrintParams.LanguageCode;
	EndIf;
	
	Template.LanguageCode = LanguageCode;
	SessionParameters.LanguageCodeForOutput = LanguageCode;
	// End MultilingualSupport
	
	Query = New Query;
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	Query.Text =
	"SELECT ALLOWED
	|	SalesAccountSalesToConsignor.Ref,
	|	SalesAccountSalesToConsignor.Number,
	|	SalesAccountSalesToConsignor.Date,
	|	SalesAccountSalesToConsignor.Contract,
	|	SalesAccountSalesToConsignor.Counterparty AS Recipient,
	|	SalesAccountSalesToConsignor.Company AS Company,
	|	SalesAccountSalesToConsignor.Company AS Vendor,
	|	SalesAccountSalesToConsignor.DocumentAmount,
	|	SalesAccountSalesToConsignor.DocumentCurrency,
	|	SalesAccountSalesToConsignor.AmountIncludesVAT,
	|	SalesAccountSalesToConsignor.VATCommissionFeePercent,
	|	SUM(AccountSalesToConsignorInventory.BrokerageAmount) AS BrokerageAmount
	|FROM
	|	Document.AccountSalesToConsignor.Inventory AS AccountSalesToConsignorInventory
	|		LEFT JOIN Document.AccountSalesToConsignor AS SalesAccountSalesToConsignor
	|		ON AccountSalesToConsignorInventory.Ref = SalesAccountSalesToConsignor.Ref
	|WHERE
	|	SalesAccountSalesToConsignor.Ref IN(&ObjectsArray)
	|
	|GROUP BY
	|	SalesAccountSalesToConsignor.Ref,
	|	SalesAccountSalesToConsignor.DocumentCurrency,
	|	SalesAccountSalesToConsignor.VATCommissionFeePercent,
	|	SalesAccountSalesToConsignor.Number,
	|	SalesAccountSalesToConsignor.Date,
	|	SalesAccountSalesToConsignor.Contract,
	|	SalesAccountSalesToConsignor.Counterparty,
	|	SalesAccountSalesToConsignor.Company,
	|	SalesAccountSalesToConsignor.DocumentAmount,
	|	SalesAccountSalesToConsignor.Company";
	
	Header = Query.Execute().Select();
	
	FirstDocument = True;
	
	While Header.Next() Do
		
		Template		= GetTemplate("SalesAccountSalesToConsignor");
		
		If Not FirstDocument Then
			
			SpreadsheetDocument.PutHorizontalPageBreak();
			
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query;
		
		Query.SetParameter("CurrentDocument", Header.Ref);
		
		Query.Text =
		"SELECT ALLOWED
		|	SalesAccountSalesToConsignorInventory.Products AS InventoryItem,
		|	SalesAccountSalesToConsignorInventory.Characteristic AS Characteristic,
		|	SalesAccountSalesToConsignorInventory.Products.Code AS Code,
		|	SalesAccountSalesToConsignorInventory.Products.SKU AS SKU,
		|	SalesAccountSalesToConsignorInventory.MeasurementUnit,
		|	SalesAccountSalesToConsignorInventory.Products.MeasurementUnit AS StorageUnit,
		|	SalesAccountSalesToConsignorInventory.Quantity AS Quantity,
		|	SalesAccountSalesToConsignorInventory.Price,
		|	SalesAccountSalesToConsignorInventory.Amount AS Amount,
		|	SalesAccountSalesToConsignorInventory.VATAmount AS VATAmount,
		|	SalesAccountSalesToConsignorInventory.Total AS Total,
		|	SalesAccountSalesToConsignorInventory.Customer AS Customer,
		|	SalesAccountSalesToConsignorInventory.DateOfSale AS SaleDate
		|FROM
		|	Document.AccountSalesToConsignor.Inventory AS SalesAccountSalesToConsignorInventory
		|WHERE
		|	SalesAccountSalesToConsignorInventory.Ref = &CurrentDocument
		|
		|ORDER BY
		|	Customer,
		|	SalesAccountSalesToConsignorInventory.LineNumber
		|TOTALS
		|	SUM(Quantity),
		|	SUM(Amount),
		|	SUM(VATAmount)
		|BY
		|	Customer";
		
		CustomersSelection = Query.Execute().Select(QueryResultIteration.ByGroups, "Customer");
		
		Total	= 0;
		SerialNumber = 1;
		
		// Displaying invoice header
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = NStr("en = 'Account sales to consignor'; ru = 'Отчет комитенту';pl = 'Raport sprzedaży komitentowi';es_ES = 'Informe de ventas a los remitentes';es_CO = 'Ventas de cuenta al remitente';tr = 'Konsinye alışlar';it = 'Saldo delle vendite per il committente';de = 'Verkaufsbericht (Kommitent) '", LanguageCode);
		SpreadsheetDocument.Put(TemplateArea);

		InfoAboutCompany    = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Company,
			Header.Date,
			,
			,
			,
			LanguageCode);
		CompanyPresentation = DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,");
		
		InfoAboutCounterparty     = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Recipient,
			Header.Date,
			,
			,
			,
			LanguageCode);
		PresentationOfCounterparty = DriveServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr,");
		
		TemplateArea = Template.GetArea("Vendor");
		TemplateArea.Parameters.Fill(Header);
		TemplateArea.Parameters.VendorPresentation = PresentationOfCounterparty;
		TemplateArea.Parameters.Vendor               = Header.Recipient;
		SpreadsheetDocument.Put(TemplateArea);

		TemplateArea = Template.GetArea("Customer");
		TemplateArea.Parameters.Fill(Header);
		TemplateArea.Parameters.RecipientPresentation = CompanyPresentation;
		TemplateArea.Parameters.Recipient              = Header.Company;
		SpreadsheetDocument.Put(TemplateArea);

		TemplateArea = Template.GetArea("TableHeader");
		SpreadsheetDocument.Put(TemplateArea);

		While CustomersSelection.Next() Do
			
			InfoAboutCustomer = DriveServer.InfoAboutLegalEntityIndividual(
				CustomersSelection.Customer,
				CustomersSelection.SaleDate,
				,
				,
				,
				LanguageCode);
			TextCustomer = "Customer: " + DriveServer.CompaniesDescriptionFull(InfoAboutCustomer, "FullDescr,LegalAddress,TIN,");

			TemplateArea = Template.GetArea("RowCustomer");
			TemplateArea.Parameters.CustomerPresentation = TextCustomer;
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("String");
			
			TotalByCounterparty = 0;
			
			StringSelectionProducts = CustomersSelection.Select();
			PricePrecision = PrecisionAppearancetServer.CompanyPrecision(Header.Company);
			
			While StringSelectionProducts.Next() Do
				
				TemplateArea.Parameters.Fill(StringSelectionProducts);
				
				TemplateArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(StringSelectionProducts.InventoryItem, 
					StringSelectionProducts.Characteristic, StringSelectionProducts.SKU);
					
				TemplateArea.Parameters.LineNumber = SerialNumber;
				
				If Not Header.AmountIncludesVAT Then
					
					AmountByRow 					= StringSelectionProducts.Total;
					TemplateArea.Parameters.Price	= ?(StringSelectionProducts.Quantity <> 0, Round(AmountByRow/StringSelectionProducts.Quantity, 2), 0);
					TemplateArea.Parameters.Amount	= AmountByRow;
					
				Else
					
					AmountByRow = StringSelectionProducts.Amount;
					
				EndIf;
				
				TemplateArea.Parameters.Price = Format(TemplateArea.Parameters.Price, "NFD= " + PricePrecision);
				
				SpreadsheetDocument.Put(TemplateArea);
				
				SerialNumber		= SerialNumber			+ 1;
				Total				= Total 				+ AmountByRow;
				TotalByCounterparty	= TotalByCounterparty	+ AmountByRow;
				
			EndDo;
			
			TemplateArea = Template.GetArea("RowCustomerTotal");
			TemplateArea.Parameters.Fill(CustomersSelection);
			TemplateArea.Parameters.Amount = TotalByCounterparty;
			
			SpreadsheetDocument.Put(TemplateArea);
			
		EndDo;
		
		TemplateArea = Template.GetArea("Total");
		TemplateArea.Parameters.Total = Total;
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("AmountInWords");
		
		TemplateArea.Parameters.AmountInWords= CurrencyRateOperations.GenerateAmountInWords(Total, Header.DocumentCurrency);
		FormatPaymentDocumentAmountInWords = CurrencyRateOperations.GenerateAmountInWords(Header.BrokerageAmount, Header.DocumentCurrency);
		
		TemplateArea.Parameters.BrokerageAmount = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Commission fee amount is %1'; ru = 'Сумма комиссии составляет %1';pl = 'Kwota prowizji wynosi %1';es_ES = 'Importe de la comisión es %1';es_CO = 'Importe de la comisión es %1';tr = 'Komisyon ücret tutarı %1 şeklindedir';it = 'L''importo delle commissioni è %1';de = 'Die Provisionszahlung beträgt %1'", LanguageCode),
			FormatPaymentDocumentAmountInWords);
			
		TemplateArea.Parameters.TotalRow = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Total titles %1, in the amount of %2'; ru = 'Количество наименований %1, в сумме %2';pl = 'Łącznie pozycji %1, na kwotę %2';es_ES = 'Títulos totales %1, en el importe de %2';es_CO = 'Títulos totales %1, en el importe de %2';tr = '%2 tutarında toplam kalem sayısı %1';it = 'Totale titoli %1, nell''importo di %2';de = 'Titel insgesamt %1, in Höhe von %2'", LanguageCode),
			StringSelectionProducts.Count(),
			DriveServer.AmountsFormat(Total, Header.DocumentCurrency));
			
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Signatures");
		
		TemplateArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
		
	Return SpreadsheetDocument;

EndFunction

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

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
	|	AccountSalesToConsignor.Ref AS Ref,
	|	SUM(AccountSalesToConsignorInventory.VATAmount) AS DocumentTax
	|FROM
	|	Document.AccountSalesToConsignor.Inventory AS AccountSalesToConsignorInventory
	|		INNER JOIN Document.AccountSalesToConsignor AS AccountSalesToConsignor
	|		ON AccountSalesToConsignorInventory.Ref = AccountSalesToConsignor.Ref
	|			AND (AccountSalesToConsignor.DocumentTax = 0)
	|			AND (AccountSalesToConsignorInventory.VATAmount > 0)
	|
	|GROUP BY
	|	AccountSalesToConsignor.Ref";
	
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
				Metadata.Documents.AccountSalesToConsignor,
				,
				ErrorDescription);
				
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf