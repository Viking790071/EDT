#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure InitializeDocumentData(Ref, StructureAdditionalProperties) Export
	
	AddAttributesToAdditionalPropertiesForPosting(Ref.Date, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(Ref, StructureAdditionalProperties);
	ElsIf StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		DriveServer.GenerateTransactionsTable(Ref, StructureAdditionalProperties);
	EndIf;
	
	InitializeTableForRegisterRecords(StructureAdditionalProperties);
	
	ErrorsTable = StructureAdditionalProperties.TableForRegisterRecords.TableMonthEndErrors;
	
	// Verify tax invoices
	If Ref.VerifyTaxInvoices Then
		VerifyTaxInvoices(Ref, StructureAdditionalProperties, ErrorsTable);
	EndIf;
	
	InventoryValuationMethod = InformationRegisters.AccountingPolicy.InventoryValuationMethod(Ref.Date, Ref.Company);
	
	// Direct cost calculation
	If Ref.DirectCostCalculation And Not Ref.ActualCostCalculation Then
		If InventoryValuationMethod =Enums.InventoryValuationMethods.FIFO Then
			CalculateActualOutputCostPrice(Ref, StructureAdditionalProperties, "DirectCostCalculation", ErrorsTable, InventoryValuationMethod);
		Else
			CalculateCostOfReturns(Ref, StructureAdditionalProperties); // refunds cost precalculation.
			CalculateActualOutputCostPrice(Ref, StructureAdditionalProperties, "DirectCostCalculation", ErrorsTable, InventoryValuationMethod);
			CalculateCostOfReturns(Ref, StructureAdditionalProperties); // refunds cost final calculation.
		EndIf;
	EndIf;
	
	// Costs allocation.
	If Ref.CostAllocation Then
		DistributeCosts(Ref, StructureAdditionalProperties, ErrorsTable, InventoryValuationMethod);
	EndIf;
	
	// COGS calculation.
	If Ref.ActualCostCalculation Then
		If InventoryValuationMethod =Enums.InventoryValuationMethods.FIFO Then
			CalculateActualOutputCostPrice(Ref, StructureAdditionalProperties, "ActualCostCalculation", ErrorsTable, InventoryValuationMethod);
		Else
			CalculateCostOfReturns(Ref, StructureAdditionalProperties); // refunds cost precalculation.
			CalculateActualOutputCostPrice(Ref, StructureAdditionalProperties, "ActualCostCalculation", ErrorsTable, InventoryValuationMethod);
			CalculateCostOfReturns(Ref, StructureAdditionalProperties); // refunds cost final calculation.
		EndIf;
	EndIf;
	
	// COGS in retail calculation Earning accounting.
	If Ref.RetailCostCalculationEarningAccounting Then
		CalculateCostPriceInRetailEarningAccounting(Ref, StructureAdditionalProperties,ErrorsTable);
	EndIf;
	
	// Exchange differences calculation.
	If Ref.ExchangeDifferencesCalculation Then
		CalculateExchangeDifferences(Ref, StructureAdditionalProperties, ErrorsTable);
	EndIf;
	
	// Financial result calculation.
	If Ref.FinancialResultCalculation Then
		CalculateFinancialResult(Ref, StructureAdditionalProperties, ErrorsTable);
	EndIf;
	
	// VAT payable calculation.
	If Ref.VATPayableCalculation Then
		CalculateVATPayable(Ref, StructureAdditionalProperties, ErrorsTable);
	EndIf;
	
	If ErrorsTable.Count() > 0 Then
		MessageText = NStr("en = 'Warnings were generated on month-end closing. For more information, see the month-end closing report.'; ru = 'При закрытии месяца были сформированы предупреждения! Подробнее см. в отчете о закрытии месяца.';pl = 'Przy zamknięciu miesiąca zostały wygenerowane ostrzeżenia. Aby uzyskać więcej informacji, zobacz raport z zamknięcia miesiąca.';es_ES = 'Avisos se han generado al cerrar el fin de mes. Para más información, ver el informe del cierre del fin de mes.';es_CO = 'Avisos se han generado al cerrar el fin de mes. Para más información, ver el informe del cierre del fin de mes.';tr = 'Ay sonu kapanışında uyarılar oluşturuldu. Daha fazla bilgi için, ay sonu kapanış raporuna bakın.';it = 'Durante la chiusura del mese sono stati generati avvisi! Per ulteriori dettagli, consultare il report sulla chiusura del mese.';de = 'Warnungen wurden am Monatsabschluss generiert. Weitere Informationen finden Sie im Monatsabschlussbericht.'");
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(Ref, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(Ref, StructureAdditionalProperties);
		AccountingTemplatesPosting.CheckEntriesAccounts(StructureAdditionalProperties, False);
		
	EndIf;

	GroupRecordTables(StructureAdditionalProperties.TableForRegisterRecords, StructureAdditionalProperties.AccountingPolicy);
	
	ErrorsTable.GroupBy("Period, Recorder, Active, Company, OperationKind, ErrorDescription, Analytics");
	
EndProcedure

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

#Region Internal

#Region LibrariesHandlers

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure
#EndRegion

#Region ToDoList
// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	
	If Not AccessRight("Edit", Metadata.Documents.MonthEndClosing) Then
		Return;
	EndIf;
	
	DocumentsCount = DocumentsCount();
	DocumentsID = "MonthEndClosing";
	
	// Month-end closing
	ToDo				= ToDoList.Add();
	ToDo.ID				= DocumentsID;
	ToDo.HasUserTasks	= (DocumentsCount.MonthClosureNotCalculatedTotals > 0);
	ToDo.Presentation	= NStr("en = 'Month-end closing'; ru = 'Закрытие месяца';pl = 'Zamknięcie miesiąca';es_ES = 'Cierre del fin de mes';es_CO = 'Cierre del fin de mes';tr = 'Ay sonu kapanışı';it = 'Chiusura mensile';de = 'Monatsabschluss'");
	ToDo.Owner			= Metadata.Subsystems.Enterprise;
	
	// Last month totals are not calculated
	ToDo				= ToDoList.Add();
	ToDo.ID				= "MonthClosureNotCalculatedTotals";
	ToDo.HasUserTasks	= (DocumentsCount.MonthClosureNotCalculatedTotals > 0);
	ToDo.Presentation	= NStr("en = 'Last month totals are not calculated'; ru = 'Итоги по прошлому месяцу не рассчитаны';pl = 'Nie obliczono kwot z ostatniego miesiąca';es_ES = 'Los totales del último mes no se calculan';es_CO = 'Los totales del último mes no se calculan';tr = 'Geçen ayın toplamları hesaplanmadı';it = 'I totali nell''ultimo mese non verranno conteggiati';de = 'Summe von letzten Monaten nicht abgerechnet'"); 
	ToDo.Count			= DocumentsCount.MonthClosureNotCalculatedTotals;
	ToDo.Form			= "DataProcessor.MonthEndClosing.Form";
	ToDo.Owner			= DocumentsID;
	
EndProcedure
// End StandardSubsystems.ToDoList
#EndRegion

#EndRegion

#Region Private

#Region TableGeneration

Procedure GenerateTableAccountingJournalEntries(Ref, StructureAdditionalProperties)
	
	Query = New Query();
	Query.Text = 
	"SELECT ALLOWED
	|	AccountingJournalEntries.Period AS Period,
	|	AccountingJournalEntries.Active AS Active,
	|	AccountingJournalEntries.AccountDr AS AccountDr,
	|	AccountingJournalEntries.AccountCr AS AccountCr,
	|	AccountingJournalEntries.Company AS Company,
	|	AccountingJournalEntries.PlanningPeriod AS PlanningPeriod,
	|	AccountingJournalEntries.CurrencyDr AS CurrencyDr,
	|	AccountingJournalEntries.CurrencyCr AS CurrencyCr,
	|	SUM(AccountingJournalEntries.Amount) AS Amount,
	|	SUM(AccountingJournalEntries.AmountCurDr) AS AmountCurDr,
	|	SUM(AccountingJournalEntries.AmountCurCr) AS AmountCurCr,
	|	AccountingJournalEntries.Content AS Content,
	|	AccountingJournalEntries.Recorder AS Recorder
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries
	|WHERE
	|	AccountingJournalEntries.Recorder = &Recorder
	|
	|GROUP BY
	|	AccountingJournalEntries.Period,
	|	AccountingJournalEntries.Active,
	|	AccountingJournalEntries.AccountDr,
	|	AccountingJournalEntries.AccountCr,
	|	AccountingJournalEntries.Company,
	|	AccountingJournalEntries.PlanningPeriod,
	|	AccountingJournalEntries.CurrencyDr,
	|	AccountingJournalEntries.CurrencyCr,
	|	AccountingJournalEntries.Content,
	|	AccountingJournalEntries.Recorder
	|
	|HAVING
	|	(SUM(AccountingJournalEntries.Amount) <> 0
	|		OR SUM(AccountingJournalEntries.AmountCurDr) <> 0
	|		OR SUM(AccountingJournalEntries.AmountCurCr) <> 0)"; 
	
	Query.SetParameter("Recorder", Ref);
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

Procedure GenerateRegisterRecordsByLandedCostsRegister(Ref, RecordSet, CostLayer, RegisterRecordRow, Amount)
	
	If CostLayer = Undefined Then
		CostLayer = Ref;
	EndIf;
	
	NewRow 					= RecordSet.Add();
	NewRow.RecordType 		= AccumulationRecordType.Receipt;
	NewRow.Period 			= Ref.Date;
	NewRow.Recorder 		= Ref;
	NewRow.Company 			= RegisterRecordRow.Company;
	NewRow.PresentationCurrency = RegisterRecordRow.PresentationCurrency;
	NewRow.CostLayer 		= CostLayer;
	NewRow.CostObject 		= RegisterRecordRow.CostObjectCorr;
	NewRow.Amount 			= Amount;
	NewRow.SourceRecord 	= True;
	NewRow.Active 			= True;
	
	If TypeOf(RegisterRecordRow) = Type("Structure") And RegisterRecordRow.Property("OwnershipCorr") Then
		NewRow.Ownership = RegisterRecordRow.OwnershipCorr;
	Else
		NewRow.Ownership = RegisterRecordRow.Ownership;
	EndIf;
	
	NewRow.Specification 			= RegisterRecordRow.SpecificationCorr;
	NewRow.GLAccount 				= RegisterRecordRow.CorrGLAccount;
	NewRow.InventoryAccountType 	= RegisterRecordRow.CorrInventoryAccountType;
	NewRow.IncomeAndExpenseItem 	= RegisterRecordRow.CorrIncomeAndExpenseItem;
	NewRow.StructuralUnit 			= RegisterRecordRow.StructuralUnitCorr;
	NewRow.Products 				= RegisterRecordRow.ProductsCorr;
	NewRow.Characteristic 			= RegisterRecordRow.CharacteristicCorr;
	NewRow.Batch 					= RegisterRecordRow.BatchCorr;
	NewRow.CorrSpecification 		= RegisterRecordRow.Specification;
	NewRow.CorrGLAccount 			= RegisterRecordRow.GLAccount;
	NewRow.CorrInventoryAccountType = RegisterRecordRow.InventoryAccountType;
	NewRow.CorrIncomeAndExpenseItem = RegisterRecordRow.IncomeAndExpenseItem;
	NewRow.CorrProducts 			= RegisterRecordRow.Products;
	NewRow.CorrCharacteristic 		= RegisterRecordRow.Characteristic;
	NewRow.CorrBatch 				= RegisterRecordRow.Batch;
	
EndProcedure

Procedure GenerateRegisterRecordsByExpensesRegister(Ref, RecordSet, TableWorkInProgress, TableAccountingJournalEntries, RegisterRecordRow, Amount, FixedCost, ParametersForRecords)
	
	ContentOfAccountingRecord = ParametersForRecords.ContentOfAccountingRecord;
	IsReturn = ParametersForRecords.IsReturn;
	Recorder = ParametersForRecords.Recorder;
	IsFIFO = ParametersForRecords.IsFIFO;
	
	If Recorder = Undefined Then
		Recorder = Ref;
	EndIf;
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If ContentOfAccountingRecord = Undefined Then
		If RegisterRecordRow.InventoryAccountType = Enums.InventoryAccountTypes.InventoryOnHand Then
			ContentOfAccountingRecord = NStr("en = 'Write off warehouse inventory'; ru = 'Списание запасов со склада';pl = 'Spisanie zapasów z magazynu';es_ES = 'Amortizar el inventario del almacén';es_CO = 'Amortizar el inventario del almacén';tr = 'Ambar stokunu düş';it = 'Consumo di scorte di magazzino';de = 'Lagerbestand abschreiben'", DefaultLanguageCode);
		Else
			If ValueIsFilled(RegisterRecordRow.Products) Then
				ContentOfAccountingRecord = NStr("en = 'Expense write-off'; ru = 'Списание расходов';pl = 'Spisanie rozchodów';es_ES = 'Amortización de gastos';es_CO = 'Amortización de gastos';tr = 'Giderlerin silinmesi';it = 'Scrittura di spese (write-off)';de = 'Aufwandsabschreibung'", DefaultLanguageCode);
			Else
				ContentOfAccountingRecord = NStr("en = 'Inventory write-off from Production'; ru = 'Списание запасов из производства';pl = 'Spisanie zapasów z produkcji';es_ES = 'Amortización de gastos de la Producción';es_CO = 'Amortización de gastos de la Producción';tr = 'Üretimden stok azaltma';it = 'Cancellazione (write-off) di scorte dalla produzione';de = 'Bestandsabschreibung von Produktion'", DefaultLanguageCode);
			EndIf;
		EndIf;
	EndIf;
	
	If IsReturn Then
		RecordType = AccumulationRecordType.Receipt;
	Else
		RecordType = AccumulationRecordType.Expense;
	EndIf;
	
	// Expense by the register Inventory and costs accounting.
	NewRow 						= RecordSet.Add();
	FillPropertyValues(NewRow, RegisterRecordRow);
	NewRow.Recorder 			= Recorder;
	NewRow.RecordType 			= RecordType;
	NewRow.Period 				= ?(ValueIsFilled(NewRow.Period), NewRow.Period, Ref.Date); // period will be filled in for returns, this is required for FIFO
	NewRow.FixedCost 			= FixedCost;
	NewRow.Quantity 			= 0;
	NewRow.Amount 				= Amount;
	NewRow.ContentOfAccountingRecord = ContentOfAccountingRecord;
	NewRow.SalesOrder 			= ?(ValueIsFilled(NewRow.SalesOrder), NewRow.SalesOrder, Undefined);
	NewRow.CustomerCorrOrder 	= ?(ValueIsFilled(NewRow.CustomerCorrOrder), NewRow.CustomerCorrOrder, Undefined);
	NewRow.CorrSalesOrder 		= ?(ValueIsFilled(NewRow.CorrSalesOrder), NewRow.CorrSalesOrder, Undefined);
	NewRow.Active 				= True;
	
	// begin Drive.FullVersion
	If ValueIsFilled(RegisterRecordRow.CostObject) Then
		NewRow 				= TableWorkInProgress.Add();
		FillPropertyValues(NewRow, RegisterRecordRow);
		NewRow.Recorder 	= Recorder;
		NewRow.RecordType 	= RecordType;
		NewRow.Period 		= ?(ValueIsFilled(NewRow.Period), NewRow.Period, Ref.Date);
		NewRow.Quantity 	= 0;
		NewRow.Amount 		= Amount;
		NewRow.Active 		= True;
	EndIf;
	// end Drive.FullVersion
	
	If Not ValueIsFilled(RegisterRecordRow.CorrInventoryAccountType) Or IsFIFO Then
		Return;
	EndIf;
	
	// Movements by register AccountingJournalEntries.
	If UseDefaultTypeOfAccounting Then 
		
		NewRow = TableAccountingJournalEntries.Add();
		NewRow.Active			= True;
		NewRow.Period 			= Ref.Date;
		NewRow.Recorder 		= Recorder;
		NewRow.Company 			= RegisterRecordRow.Company;
		NewRow.PlanningPeriod 	= Catalogs.PlanningPeriods.Actual;
		NewRow.AccountDr 		= RegisterRecordRow.CorrGLAccount;
		NewRow.AccountCr 		= RegisterRecordRow.GLAccount;
		NewRow.Amount 			= Amount;
		NewRow.Content 			= ContentOfAccountingRecord;
		
	EndIf;
	
	If Not ValueIsFilled(RegisterRecordRow.ProductsCorr) And Not RegisterRecordRow.ProductionExpenses Then
		Return;
	EndIf;
	
	If RegisterRecordRow.CorrInventoryAccountType = Enums.InventoryAccountTypes.InventoryOnHand Then
		ContentOfAccountingRecord = NStr("en = 'Inventory increase to warehouse'; ru = 'Оприходование запасов на склад';pl = 'Zwiększenie zapasów do magazynu';es_ES = 'Aumento del inventario para el almacén';es_CO = 'Aumento del inventario para el almacén';tr = 'Ambara stok artışı';it = 'Aumento delle scorte al magazzino';de = 'Bestandserhöhung zum Lager'", DefaultLanguageCode);
	Else
		If ValueIsFilled(RegisterRecordRow.Products) Then
			ContentOfAccountingRecord = NStr("en = 'Expense receipt'; ru = 'Поступление расходов';pl = 'Pokwitowanie rozchodów';es_ES = 'Recibo de gastos';es_CO = 'Recibo de gastos';tr = 'Gider makbuzu';it = 'Ricezione di spese';de = 'Ausgabebeleg'", DefaultLanguageCode);
		Else
			ContentOfAccountingRecord = NStr("en = 'Inventory increase in production'; ru = 'Оприходование запасов в производство';pl = 'Zwiększenie zapasów w produkcji';es_ES = 'Aumento del inventario en la producción';es_CO = 'Aumento del inventario en la producción';tr = 'Stokların üretimde artışı';it = 'Aumento delle scorte in produzione';de = 'Bestandserhöhung in Produktion'", DefaultLanguageCode);
		EndIf;
	EndIf;
	NewRow 							= RecordSet.Add();
	NewRow.RecordType 				= AccumulationRecordType.Receipt;
	NewRow.Period 					= Ref.Date;
	NewRow.Recorder 				= Recorder;
	NewRow.Company 					= RegisterRecordRow.Company;
	NewRow.PresentationCurrency 	= RegisterRecordRow.PresentationCurrency; 
	NewRow.StructuralUnit 			= RegisterRecordRow.StructuralUnitCorr;
	NewRow.GLAccount 				= RegisterRecordRow.CorrGLAccount;
	NewRow.IncomeAndExpenseItem 	= RegisterRecordRow.CorrIncomeAndExpenseItem;
	NewRow.Products 				= RegisterRecordRow.ProductsCorr;
	NewRow.Characteristic 			= RegisterRecordRow.CharacteristicCorr;
	NewRow.Batch 					= RegisterRecordRow.BatchCorr;
	NewRow.Ownership 				= RegisterRecordRow.OwnershipCorr;
	NewRow.Specification 			= RegisterRecordRow.SpecificationCorr;
	NewRow.SpecificationCorr 		= RegisterRecordRow.Specification;
	NewRow.StructuralUnitCorr 		= RegisterRecordRow.StructuralUnit;
	NewRow.CorrGLAccount 			= RegisterRecordRow.GLAccount;
	NewRow.CorrIncomeAndExpenseItem = RegisterRecordRow.IncomeAndExpenseItem;
	NewRow.ProductsCorr 			= RegisterRecordRow.Products;
	NewRow.CharacteristicCorr 		= RegisterRecordRow.Characteristic;
	NewRow.BatchCorr 				= RegisterRecordRow.Batch;
	NewRow.OwnershipCorr 			= RegisterRecordRow.Ownership;
	NewRow.FixedCost 				= FixedCost;
	NewRow.Amount 					= Amount;
	NewRow.ContentOfAccountingRecord = ContentOfAccountingRecord;
	NewRow.SalesOrder 				= ?(ValueIsFilled(NewRow.SalesOrder), NewRow.SalesOrder, Undefined);
	
	If ValueIsFilled(RegisterRecordRow.CorrInventoryAccountType) Then
		NewRow.InventoryAccountType 	= RegisterRecordRow.CorrInventoryAccountType;
		NewRow.CorrInventoryAccountType = RegisterRecordRow.InventoryAccountType;
	Else
		NewRow.InventoryAccountType 	= RegisterRecordRow.InventoryAccountType;
		NewRow.CorrInventoryAccountType = Undefined;
	EndIf;
	
	NewRow.Active = True;
	
	// begin Drive.FullVersion
	If ValueIsFilled(RegisterRecordRow.CostObjectCorr) Then
		
		NewRow.CostObject = RegisterRecordRow.CostObjectCorr;
		
		NewWIPRow = TableWorkInProgress.Add();
		FillPropertyValues(NewWIPRow, NewRow);
		NewWIPRow.CostObject = RegisterRecordRow.CostObjectCorr;
		NewWIPRow.Active = True;
		
	EndIf;
	// end Drive.FullVersion
	
EndProcedure

Procedure GenerateCorrectiveRegisterRecordsByExpensesRegister(Ref, StructureAdditionalProperties)
	
	DateBeg = StructureAdditionalProperties.ForPosting.BeginOfPeriodningDate;
	DateEnd = StructureAdditionalProperties.ForPosting.EndDatePeriod;	
	
	Query = New Query();
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT ALLOWED DISTINCT
	|	InventoryTransfer.Ref AS SourceDocument,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	InventoryTransferInventory.Products AS Products,
	|	InventoryTransferInventory.Characteristic AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND InventoryTransfer.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|				AND (ISNULL(BatchTrackingPoliciesCorr.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPoliciesCorr.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN InventoryTransferInventory.Batch
	|		WHEN &UseBatches
	|				AND InventoryTransfer.OperationKind <> VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN InventoryTransferInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	InventoryTransferInventory.Ownership AS Ownership,
	|	InventoryTransfer.StructuralUnit AS StructuralUnit,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	CASE
	|		WHEN InventoryTransfer.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|			THEN VALUE(Enum.InventoryAccountTypes.SignedOutEquipment)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS InventoryAccountType,
	|	InventoryTransferInventory.ExpenseItem.IncomeAndExpenseType AS IncomeAndExpenseType,
	|	InventoryTransferInventory.ExpenseItem AS ExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN InventoryTransferInventory.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ConsumptionGLAccount,
	|	CostAccounting.RecordType AS RecordType,
	|	CostAccounting.Return AS Return
	|INTO TT_InventoryTransfer
	|FROM
	|	Document.InventoryTransfer AS InventoryTransfer
	|		INNER JOIN AccumulationRegister.Inventory AS CostAccounting
	|		ON InventoryTransfer.Ref = CostAccounting.SourceDocument
	|		INNER JOIN Document.InventoryTransfer.Inventory AS InventoryTransferInventory
	|		ON InventoryTransfer.Ref = InventoryTransferInventory.Ref
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON (InventoryTransferInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON InventoryTransfer.StructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicyCorr
	|		ON InventoryTransfer.StructuralUnitPayee = BatchTrackingPolicyCorr.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicyCorr.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPoliciesCorr
	|		ON (BatchTrackingPolicyCorr.Policy = BatchTrackingPoliciesCorr.Ref)
	|WHERE
	|	CostAccounting.Period BETWEEN &DateBeg AND &DateEnd
	|	AND CostAccounting.Company = &Company
	|	AND CostAccounting.PresentationCurrency = &PresentationCurrency
	|	AND NOT CostAccounting.FixedCost
	|
	|INDEX BY
	|	SourceDocument,
	|	Company,
	|	PresentationCurrency,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	Ownership,
	|	StructuralUnit,
	|	CostObject,
	|	InventoryAccountType,
	|	RecordType,
	|	Return
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CASE
	|		WHEN CostAccounting.RetailTransferEarningAccounting
	|			THEN CASE
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.SupplierInvoice)
	|						THEN CostAccounting.SourceDocument.StructuralUnit
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|						THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END AS RetailStructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|				AND VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.BusinessLine
	|		ELSE UNDEFINED
	|	END AS ActivityDirectionWriteOff,
	|	CostAccounting.Company AS Company,
	|	CostAccounting.PresentationCurrency AS PresentationCurrency,
	|	CostAccounting.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|		ELSE CostAccounting.SourceDocument.StructuralUnit
	|	END AS StructuralUnitPayee,
	|	CostAccounting.InventoryAccountType AS InventoryAccountType,
	|	CostAccounting.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	CostAccounting.Products AS Products,
	|	CostAccounting.Characteristic AS Characteristic,
	|	CostAccounting.Batch AS Batch,
	|	CostAccounting.Ownership AS Ownership,
	|	CostAccounting.SalesOrder AS SalesOrder,
	|	CostAccounting.Specification AS Specification,
	|	CostAccounting.SpecificationCorr AS SpecificationCorr,
	|	CostAccounting.StructuralUnitCorr AS StructuralUnitCorr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	CostAccounting.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	CostAccounting.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	ISNULL(CostAccounting.IncomeAndExpenseItem.IncomeAndExpenseType, VALUE(Catalog.IncomeAndExpenseTypes.EmptyRef)) AS IncomeAndExpenseType,
	|	ISNULL(CostAccounting.CorrIncomeAndExpenseItem.IncomeAndExpenseType, VALUE(Catalog.IncomeAndExpenseTypes.EmptyRef)) AS CorrIncomeAndExpenseType,
	|	CostAccounting.ProductsCorr AS ProductsCorr,
	|	CostAccounting.CharacteristicCorr AS CharacteristicCorr,
	|	CostAccounting.BatchCorr AS BatchCorr,
	|	CostAccounting.OwnershipCorr AS OwnershipCorr,
	|	SUM(CASE
	|			WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN CostAccounting.Quantity
	|			ELSE -CostAccounting.Quantity
	|		END) AS Quantity,
	|	SUM(CASE
	|			WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN CostAccounting.Amount
	|			ELSE -CostAccounting.Amount
	|		END) AS Amount,
	|	CostAccounting.Products.ProductsCategory AS ProductsProductsCategory,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.Products.BusinessLine
	|		ELSE VALUE(Catalog.LinesOfBusiness.MainLine)
	|	END AS BusinessLineSales,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.Products.BusinessLine.GLAccountCostOfSales
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS BusinessLineSalesGLAccountOfSalesCost,
	|	CostAccounting.SourceDocument AS SourceDocument,
	|	CostAccounting.Department AS Department,
	|	CostAccounting.Responsible AS Responsible,
	|	CostAccounting.VATRate AS VATRate,
	|	CostAccounting.ProductionExpenses AS ProductionExpenses,
	|	CostAccounting.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	CostAccounting.SalesRep AS SalesRep,
	|	CostAccounting.Counterparty AS Counterparty,
	|	CostAccounting.Currency AS Currency,
	|	CostAccounting.CostObject AS CostObject,
	|	CostAccounting.CostObjectCorr AS CostObjectCorr,
	|	CostAccounting.RecordType AS RecordType
	|INTO TT_CostAccountingWriteOff
	|FROM
	|	AccumulationRegister.Inventory AS CostAccounting
	|WHERE
	|	CostAccounting.Period BETWEEN &DateBeg AND &DateEnd
	|	AND CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND NOT CostAccounting.Return
	|	AND CostAccounting.Company = &Company
	|	AND CostAccounting.PresentationCurrency = &PresentationCurrency
	|	AND NOT CostAccounting.FixedCost
	|	AND VALUETYPE(CostAccounting.Recorder) <> TYPE(Document.MonthEndClosing)
	|
	|GROUP BY
	|	CASE
	|		WHEN CostAccounting.RetailTransferEarningAccounting
	|			THEN CASE
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.SupplierInvoice)
	|						THEN CostAccounting.SourceDocument.StructuralUnit
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|						THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|				AND VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.BusinessLine
	|		ELSE UNDEFINED
	|	END,
	|	CostAccounting.Company,
	|	CostAccounting.PresentationCurrency,
	|	CostAccounting.StructuralUnit,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|		ELSE CostAccounting.SourceDocument.StructuralUnit
	|	END,
	|	CostAccounting.InventoryAccountType,
	|	CostAccounting.CorrInventoryAccountType,
	|	CostAccounting.Products,
	|	CostAccounting.Characteristic,
	|	CostAccounting.Batch,
	|	CostAccounting.Ownership,
	|	CostAccounting.SalesOrder,
	|	CostAccounting.Specification,
	|	CostAccounting.SpecificationCorr,
	|	CostAccounting.StructuralUnitCorr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CostAccounting.IncomeAndExpenseItem,
	|	CostAccounting.CorrIncomeAndExpenseItem,
	|	ISNULL(CostAccounting.IncomeAndExpenseItem.IncomeAndExpenseType, VALUE(Catalog.IncomeAndExpenseTypes.EmptyRef)),
	|	ISNULL(CostAccounting.CorrIncomeAndExpenseItem.IncomeAndExpenseType, VALUE(Catalog.IncomeAndExpenseTypes.EmptyRef)),
	|	CostAccounting.ProductsCorr,
	|	CostAccounting.CharacteristicCorr,
	|	CostAccounting.BatchCorr,
	|	CostAccounting.OwnershipCorr,
	|	CostAccounting.Products.ProductsCategory,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.Products.BusinessLine
	|		ELSE VALUE(Catalog.LinesOfBusiness.MainLine)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.Products.BusinessLine.GLAccountCostOfSales
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CostAccounting.SourceDocument,
	|	CostAccounting.Department,
	|	CostAccounting.Responsible,
	|	CostAccounting.VATRate,
	|	CostAccounting.ProductionExpenses,
	|	CostAccounting.RetailTransferEarningAccounting,
	|	CostAccounting.SalesRep,
	|	CostAccounting.Counterparty,
	|	CostAccounting.Currency,
	|	CostAccounting.CostObject,
	|	CostAccounting.CostObjectCorr,
	|	CostAccounting.RecordType
	|
	|UNION ALL
	|
	|SELECT
	|	CASE
	|		WHEN CostAccounting.RetailTransferEarningAccounting
	|			THEN CASE
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.SupplierInvoice)
	|						THEN CostAccounting.SourceDocument.StructuralUnit
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|						THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|				AND VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.BusinessLine
	|		ELSE UNDEFINED
	|	END,
	|	CostAccounting.Company,
	|	CostAccounting.PresentationCurrency,
	|	CostAccounting.StructuralUnit,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|		ELSE CostAccounting.SourceDocument.StructuralUnit
	|	END,
	|	CostAccounting.InventoryAccountType,
	|	CostAccounting.CorrInventoryAccountType,
	|	CostAccounting.Products,
	|	CostAccounting.Characteristic,
	|	CostAccounting.Batch,
	|	CostAccounting.Ownership,
	|	CostAccounting.SalesOrder,
	|	CostAccounting.Specification,
	|	CostAccounting.SpecificationCorr,
	|	CostAccounting.StructuralUnitCorr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CostAccounting.IncomeAndExpenseItem,
	|	CostAccounting.CorrIncomeAndExpenseItem,
	|	ISNULL(CostAccounting.IncomeAndExpenseItem.IncomeAndExpenseType, VALUE(Catalog.IncomeAndExpenseTypes.EmptyRef)),
	|	ISNULL(CostAccounting.CorrIncomeAndExpenseItem.IncomeAndExpenseType, VALUE(Catalog.IncomeAndExpenseTypes.EmptyRef)),
	|	CostAccounting.ProductsCorr,
	|	CostAccounting.CharacteristicCorr,
	|	CostAccounting.BatchCorr,
	|	CostAccounting.OwnershipCorr,
	|	SUM(CASE
	|			WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN CostAccounting.Quantity
	|			ELSE -CostAccounting.Quantity
	|		END),
	|	SUM(CASE
	|			WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN CostAccounting.Amount
	|			ELSE -CostAccounting.Amount
	|		END),
	|	CostAccounting.Products.ProductsCategory,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.Products.BusinessLine
	|		ELSE VALUE(Catalog.LinesOfBusiness.MainLine)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.Products.BusinessLine.GLAccountCostOfSales
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CostAccounting.SourceDocument,
	|	CostAccounting.Department,
	|	CostAccounting.Responsible,
	|	CostAccounting.VATRate,
	|	CostAccounting.ProductionExpenses,
	|	CostAccounting.RetailTransferEarningAccounting,
	|	CostAccounting.SalesRep,
	|	CostAccounting.Counterparty,
	|	CostAccounting.Currency,
	|	CostAccounting.CostObject,
	|	CostAccounting.CostObjectCorr,
	|	CostAccounting.RecordType
	|FROM
	|	TableInventory AS CostAccounting
	|WHERE
	|	CostAccounting.Period BETWEEN &DateBeg AND &DateEnd
	|	AND CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND NOT CostAccounting.Return
	|	AND CostAccounting.Company = &Company
	|	AND CostAccounting.PresentationCurrency = &PresentationCurrency
	|	AND NOT CostAccounting.FixedCost
	|
	|GROUP BY
	|	CASE
	|		WHEN CostAccounting.RetailTransferEarningAccounting
	|			THEN CASE
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.SupplierInvoice)
	|						THEN CostAccounting.SourceDocument.StructuralUnit
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|						THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|				AND VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.BusinessLine
	|		ELSE UNDEFINED
	|	END,
	|	CostAccounting.Company,
	|	CostAccounting.PresentationCurrency,
	|	CostAccounting.StructuralUnit,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|		ELSE CostAccounting.SourceDocument.StructuralUnit
	|	END,
	|	CostAccounting.InventoryAccountType,
	|	CostAccounting.CorrInventoryAccountType,
	|	CostAccounting.Products,
	|	CostAccounting.Characteristic,
	|	CostAccounting.Batch,
	|	CostAccounting.Ownership,
	|	CostAccounting.SalesOrder,
	|	CostAccounting.Specification,
	|	CostAccounting.SpecificationCorr,
	|	CostAccounting.StructuralUnitCorr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CostAccounting.IncomeAndExpenseItem,
	|	CostAccounting.CorrIncomeAndExpenseItem,
	|	ISNULL(CostAccounting.IncomeAndExpenseItem.IncomeAndExpenseType, VALUE(Catalog.IncomeAndExpenseTypes.EmptyRef)),
	|	ISNULL(CostAccounting.CorrIncomeAndExpenseItem.IncomeAndExpenseType, VALUE(Catalog.IncomeAndExpenseTypes.EmptyRef)),
	|	CostAccounting.ProductsCorr,
	|	CostAccounting.CharacteristicCorr,
	|	CostAccounting.BatchCorr,
	|	CostAccounting.OwnershipCorr,
	|	CostAccounting.Products.ProductsCategory,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.Products.BusinessLine
	|		ELSE VALUE(Catalog.LinesOfBusiness.MainLine)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.Products.BusinessLine.GLAccountCostOfSales
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CostAccounting.SourceDocument,
	|	CostAccounting.Department,
	|	CostAccounting.Responsible,
	|	CostAccounting.VATRate,
	|	CostAccounting.ProductionExpenses,
	|	CostAccounting.RetailTransferEarningAccounting,
	|	CostAccounting.SalesRep,
	|	CostAccounting.Counterparty,
	|	CostAccounting.Currency,
	|	CostAccounting.CostObject,
	|	CostAccounting.CostObjectCorr,
	|	CostAccounting.RecordType
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	StructuralUnit,
	|	InventoryAccountType,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	Ownership
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN VALUETYPE(TT_CostAccountingWriteOff.SourceDocument) = TYPE(Document.InventoryWriteOff)
	|			THEN TT_CostAccountingWriteOff.SourceDocument.Correspondence
	|		WHEN VALUETYPE(TT_CostAccountingWriteOff.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN TT_InventoryTransfer.ConsumptionGLAccount
	|		ELSE UNDEFINED
	|	END AS GLAccountWriteOff,
	|	CASE
	|		WHEN VALUETYPE(TT_CostAccountingWriteOff.SourceDocument) = TYPE(Document.InventoryWriteOff)
	|			THEN TT_CostAccountingWriteOff.SourceDocument.ExpenseItem
	|		WHEN VALUETYPE(TT_CostAccountingWriteOff.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN TT_InventoryTransfer.ExpenseItem
	|		ELSE UNDEFINED
	|	END AS ExpenseItemWriteOff,
	|	CASE
	|		WHEN TT_CostAccountingWriteOff.RetailTransferEarningAccounting
	|			THEN CASE
	|					WHEN VALUETYPE(TT_CostAccountingWriteOff.SourceDocument) = TYPE(Document.SupplierInvoice)
	|						THEN TT_CostAccountingWriteOff.SourceDocument.StructuralUnit
	|					WHEN VALUETYPE(TT_CostAccountingWriteOff.SourceDocument) = TYPE(Document.InventoryTransfer)
	|						THEN TT_CostAccountingWriteOff.SourceDocument.StructuralUnitPayee
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END AS RetailStructuralUnit,
	|	CASE
	|		WHEN VALUETYPE(TT_CostAccountingWriteOff.SourceDocument) = TYPE(Document.InventoryWriteOff)
	|			THEN TT_CostAccountingWriteOff.SourceDocument.ExpenseItem.IncomeAndExpenseType
	|		WHEN VALUETYPE(TT_CostAccountingWriteOff.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN TT_InventoryTransfer.IncomeAndExpenseType
	|		ELSE UNDEFINED
	|	END AS WriteOffIncomeAndExpenseType,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|				AND VALUETYPE(TT_CostAccountingWriteOff.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN TT_CostAccountingWriteOff.SourceDocument.BusinessLine
	|		ELSE UNDEFINED
	|	END AS ActivityDirectionWriteOff,
	|	TT_CostAccountingWriteOff.Company AS Company,
	|	TT_CostAccountingWriteOff.PresentationCurrency AS PresentationCurrency,
	|	TT_CostAccountingWriteOff.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN VALUETYPE(TT_CostAccountingWriteOff.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN TT_CostAccountingWriteOff.SourceDocument.StructuralUnitPayee
	|		ELSE TT_CostAccountingWriteOff.SourceDocument.StructuralUnit
	|	END AS StructuralUnitPayee,
	|	TT_CostAccountingWriteOff.InventoryAccountType AS InventoryAccountType,
	|	TT_CostAccountingWriteOff.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TT_CostAccountingWriteOff.Products AS Products,
	|	TT_CostAccountingWriteOff.Characteristic AS Characteristic,
	|	TT_CostAccountingWriteOff.Batch AS Batch,
	|	TT_CostAccountingWriteOff.Ownership AS Ownership,
	|	TT_CostAccountingWriteOff.SalesOrder AS SalesOrder,
	|	TT_CostAccountingWriteOff.Specification AS Specification,
	|	TT_CostAccountingWriteOff.SpecificationCorr AS SpecificationCorr,
	|	TT_CostAccountingWriteOff.StructuralUnitCorr AS StructuralUnitCorr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TT_CostAccountingWriteOff.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TT_CostAccountingWriteOff.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	TT_CostAccountingWriteOff.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	TT_CostAccountingWriteOff.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	ISNULL(TT_CostAccountingWriteOff.IncomeAndExpenseItem.IncomeAndExpenseType, VALUE(Catalog.IncomeAndExpenseTypes.EmptyRef)) AS IncomeAndExpenseType,
	|	ISNULL(TT_CostAccountingWriteOff.CorrIncomeAndExpenseItem.IncomeAndExpenseType, VALUE(Catalog.IncomeAndExpenseTypes.EmptyRef)) AS CorrIncomeAndExpenseType,
	|	TT_CostAccountingWriteOff.ProductsCorr AS ProductsCorr,
	|	TT_CostAccountingWriteOff.CharacteristicCorr AS CharacteristicCorr,
	|	TT_CostAccountingWriteOff.BatchCorr AS BatchCorr,
	|	TT_CostAccountingWriteOff.OwnershipCorr AS OwnershipCorr,
	|	SUM(CASE
	|			WHEN TT_CostAccountingWriteOff.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN TT_CostAccountingWriteOff.Quantity
	|			ELSE -TT_CostAccountingWriteOff.Quantity
	|		END) AS Quantity,
	|	SUM(CASE
	|			WHEN TT_CostAccountingWriteOff.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN TT_CostAccountingWriteOff.Amount
	|			ELSE -TT_CostAccountingWriteOff.Amount
	|		END) AS Amount,
	|	TT_CostAccountingWriteOff.Products.ProductsCategory AS ProductsProductsCategory,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TT_CostAccountingWriteOff.Products.BusinessLine
	|		ELSE VALUE(Catalog.LinesOfBusiness.MainLine)
	|	END AS BusinessLineSales,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TT_CostAccountingWriteOff.Products.BusinessLine.GLAccountCostOfSales
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS BusinessLineSalesGLAccountOfSalesCost,
	|	TT_CostAccountingWriteOff.SourceDocument AS SourceDocument,
	|	TT_CostAccountingWriteOff.Department AS Department,
	|	TT_CostAccountingWriteOff.Responsible AS Responsible,
	|	TT_CostAccountingWriteOff.VATRate AS VATRate,
	|	TT_CostAccountingWriteOff.ProductionExpenses AS ProductionExpenses,
	|	TT_CostAccountingWriteOff.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	TT_CostAccountingWriteOff.SalesRep AS SalesRep,
	|	TT_CostAccountingWriteOff.Counterparty AS Counterparty,
	|	TT_CostAccountingWriteOff.Currency AS Currency,
	|	TT_CostAccountingWriteOff.CostObject AS CostObject,
	|	TT_CostAccountingWriteOff.CostObjectCorr AS CostObjectCorr
	|INTO CostAccountingWriteOff
	|FROM
	|	TT_CostAccountingWriteOff AS TT_CostAccountingWriteOff
	|		LEFT JOIN TT_InventoryTransfer AS TT_InventoryTransfer
	|		ON TT_CostAccountingWriteOff.SourceDocument = TT_InventoryTransfer.SourceDocument
	|			AND TT_CostAccountingWriteOff.Company = TT_InventoryTransfer.Company
	|			AND TT_CostAccountingWriteOff.PresentationCurrency = TT_InventoryTransfer.PresentationCurrency
	|			AND TT_CostAccountingWriteOff.Products = TT_InventoryTransfer.Products
	|			AND TT_CostAccountingWriteOff.Characteristic = TT_InventoryTransfer.Characteristic
	|			AND TT_CostAccountingWriteOff.Batch = TT_InventoryTransfer.Batch
	|			AND TT_CostAccountingWriteOff.Ownership = TT_InventoryTransfer.Ownership
	|			AND TT_CostAccountingWriteOff.StructuralUnit = TT_InventoryTransfer.StructuralUnit
	|			AND TT_CostAccountingWriteOff.CostObject = TT_InventoryTransfer.CostObject
	|			AND TT_CostAccountingWriteOff.InventoryAccountType = TT_InventoryTransfer.InventoryAccountType
	|			AND (TT_InventoryTransfer.RecordType = VALUE(AccumulationRecordType.Expense))
	|			AND (NOT TT_InventoryTransfer.Return)
	|
	|GROUP BY
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN VALUETYPE(TT_CostAccountingWriteOff.SourceDocument) = TYPE(Document.InventoryWriteOff)
	|			THEN TT_CostAccountingWriteOff.SourceDocument.Correspondence
	|		WHEN VALUETYPE(TT_CostAccountingWriteOff.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN TT_InventoryTransfer.ConsumptionGLAccount
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TT_CostAccountingWriteOff.RetailTransferEarningAccounting
	|			THEN CASE
	|					WHEN VALUETYPE(TT_CostAccountingWriteOff.SourceDocument) = TYPE(Document.SupplierInvoice)
	|						THEN TT_CostAccountingWriteOff.SourceDocument.StructuralUnit
	|					WHEN VALUETYPE(TT_CostAccountingWriteOff.SourceDocument) = TYPE(Document.InventoryTransfer)
	|						THEN TT_CostAccountingWriteOff.SourceDocument.StructuralUnitPayee
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN VALUETYPE(TT_CostAccountingWriteOff.SourceDocument) = TYPE(Document.InventoryWriteOff)
	|			THEN TT_CostAccountingWriteOff.SourceDocument.ExpenseItem.IncomeAndExpenseType
	|		WHEN VALUETYPE(TT_CostAccountingWriteOff.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN TT_InventoryTransfer.IncomeAndExpenseType
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|				AND VALUETYPE(TT_CostAccountingWriteOff.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN TT_CostAccountingWriteOff.SourceDocument.BusinessLine
	|		ELSE UNDEFINED
	|	END,
	|	TT_CostAccountingWriteOff.Company,
	|	TT_CostAccountingWriteOff.PresentationCurrency,
	|	TT_CostAccountingWriteOff.StructuralUnit,
	|	CASE
	|		WHEN VALUETYPE(TT_CostAccountingWriteOff.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN TT_CostAccountingWriteOff.SourceDocument.StructuralUnitPayee
	|		ELSE TT_CostAccountingWriteOff.SourceDocument.StructuralUnit
	|	END,
	|	TT_CostAccountingWriteOff.InventoryAccountType,
	|	TT_CostAccountingWriteOff.CorrInventoryAccountType,
	|	TT_CostAccountingWriteOff.Products,
	|	TT_CostAccountingWriteOff.Characteristic,
	|	TT_CostAccountingWriteOff.Batch,
	|	TT_CostAccountingWriteOff.Ownership,
	|	TT_CostAccountingWriteOff.SalesOrder,
	|	TT_CostAccountingWriteOff.Specification,
	|	TT_CostAccountingWriteOff.SpecificationCorr,
	|	TT_CostAccountingWriteOff.StructuralUnitCorr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TT_CostAccountingWriteOff.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TT_CostAccountingWriteOff.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	TT_CostAccountingWriteOff.IncomeAndExpenseItem,
	|	TT_CostAccountingWriteOff.CorrIncomeAndExpenseItem,
	|	ISNULL(TT_CostAccountingWriteOff.IncomeAndExpenseItem.IncomeAndExpenseType, VALUE(Catalog.IncomeAndExpenseTypes.EmptyRef)),
	|	ISNULL(TT_CostAccountingWriteOff.CorrIncomeAndExpenseItem.IncomeAndExpenseType, VALUE(Catalog.IncomeAndExpenseTypes.EmptyRef)),
	|	TT_CostAccountingWriteOff.ProductsCorr,
	|	TT_CostAccountingWriteOff.CharacteristicCorr,
	|	TT_CostAccountingWriteOff.BatchCorr,
	|	TT_CostAccountingWriteOff.OwnershipCorr,
	|	TT_CostAccountingWriteOff.Products.ProductsCategory,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TT_CostAccountingWriteOff.Products.BusinessLine
	|		ELSE VALUE(Catalog.LinesOfBusiness.MainLine)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TT_CostAccountingWriteOff.Products.BusinessLine.GLAccountCostOfSales
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	TT_CostAccountingWriteOff.SourceDocument,
	|	TT_CostAccountingWriteOff.Department,
	|	TT_CostAccountingWriteOff.Responsible,
	|	TT_CostAccountingWriteOff.VATRate,
	|	TT_CostAccountingWriteOff.ProductionExpenses,
	|	TT_CostAccountingWriteOff.RetailTransferEarningAccounting,
	|	CASE
	|		WHEN VALUETYPE(TT_CostAccountingWriteOff.SourceDocument) = TYPE(Document.InventoryWriteOff)
	|			THEN TT_CostAccountingWriteOff.SourceDocument.ExpenseItem
	|		WHEN VALUETYPE(TT_CostAccountingWriteOff.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN TT_InventoryTransfer.ExpenseItem
	|		ELSE UNDEFINED
	|	END,
	|	TT_CostAccountingWriteOff.SalesRep,
	|	TT_CostAccountingWriteOff.Counterparty,
	|	TT_CostAccountingWriteOff.Currency,
	|	TT_CostAccountingWriteOff.CostObject,
	|	TT_CostAccountingWriteOff.CostObjectCorr
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	StructuralUnit,
	|	InventoryAccountType,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	Ownership
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	WriteOffCostAdjustment.Company AS Company,
	|	WriteOffCostAdjustment.PresentationCurrency AS PresentationCurrency,
	|	WriteOffCostAdjustment.StructuralUnit AS StructuralUnit,
	|	CostAccounting.StructuralUnitPayee AS StructuralUnitPayee,
	|	WriteOffCostAdjustment.InventoryAccountType AS InventoryAccountType,
	|	CostAccounting.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	CostAccounting.GLAccount AS GLAccount,
	|	WriteOffCostAdjustment.Products AS Products,
	|	WriteOffCostAdjustment.Characteristic AS Characteristic,
	|	WriteOffCostAdjustment.Batch AS Batch,
	|	WriteOffCostAdjustment.Ownership AS Ownership,
	|	CostAccounting.SalesOrder AS SalesOrder,
	|	WriteOffCostAdjustment.NodeNo AS NodeNo,
	|	CostAccounting.Specification AS Specification,
	|	CostAccounting.SpecificationCorr AS SpecificationCorr,
	|	CostAccounting.ExpenseItemWriteOff AS ExpenseItemWriteOff,
	|	CostAccounting.WriteOffIncomeAndExpenseType AS WriteOffIncomeAndExpenseType,
	|	CostAccounting.StructuralUnitCorr AS StructuralUnitCorr,
	|	CostAccounting.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	CostAccounting.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	CostAccounting.IncomeAndExpenseType AS IncomeAndExpenseType,
	|	CostAccounting.CorrIncomeAndExpenseType AS CorrIncomeAndExpenseType,
	|	CostAccounting.CorrGLAccount AS CorrGLAccount,
	|	CostAccounting.ProductsCorr AS ProductsCorr,
	|	CostAccounting.CharacteristicCorr AS CharacteristicCorr,
	|	CostAccounting.BatchCorr AS BatchCorr,
	|	CostAccounting.OwnershipCorr AS OwnershipCorr,
	|	CASE
	|		WHEN ISNULL(CostAccounting.Quantity, 0) = 0
	|			THEN ISNULL(CostAccounting.Amount, 0)
	|		ELSE ISNULL(CostAccounting.Quantity, 0)
	|	END AS Quantity,
	|	ISNULL(CostAccounting.Amount, 0) AS Amount,
	|	ISNULL(SolutionsTable.Amount, 0) AS Price,
	|	CostAccounting.ProductsProductsCategory AS ProductsProductsCategory,
	|	CostAccounting.BusinessLineSales AS BusinessLineSales,
	|	CostAccounting.BusinessLineSalesGLAccountOfSalesCost AS BusinessLineSalesGLAccountOfSalesCost,
	|	CostAccounting.SourceDocument AS SourceDocument,
	|	CostAccounting.Department AS Department,
	|	CostAccounting.Responsible AS Responsible,
	|	CostAccounting.VATRate AS VATRate,
	|	CostAccounting.ProductionExpenses AS ProductionExpenses,
	|	CostAccounting.ActivityDirectionWriteOff AS ActivityDirectionWriteOff,
	|	CostAccounting.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	CostAccounting.RetailStructuralUnit AS RetailStructuralUnit,
	|	CostAccounting.SalesRep AS SalesRep,
	|	CostAccounting.Counterparty AS Counterparty,
	|	CostAccounting.Currency AS Currency,
	|	CostAccounting.CostObject AS CostObject,
	|	CostAccounting.CostObjectCorr AS CostObjectCorr,
	|	CostAccounting.GLAccountWriteOff AS GLAccountWriteOff
	|FROM
	|	InformationRegister.WriteOffCostAdjustment AS WriteOffCostAdjustment
	|		LEFT JOIN CostAccountingWriteOff AS CostAccounting
	|		ON WriteOffCostAdjustment.Company = CostAccounting.Company
	|			AND WriteOffCostAdjustment.PresentationCurrency = CostAccounting.PresentationCurrency
	|			AND WriteOffCostAdjustment.StructuralUnit = CostAccounting.StructuralUnit
	|			AND WriteOffCostAdjustment.InventoryAccountType = CostAccounting.InventoryAccountType
	|			AND WriteOffCostAdjustment.Products = CostAccounting.Products
	|			AND WriteOffCostAdjustment.Characteristic = CostAccounting.Characteristic
	|			AND WriteOffCostAdjustment.Batch = CostAccounting.Batch
	|			AND WriteOffCostAdjustment.Ownership = CostAccounting.Ownership
	|			AND WriteOffCostAdjustment.CostObject = CostAccounting.CostObject
	|		LEFT JOIN SolutionsTable AS SolutionsTable
	|		ON (SolutionsTable.NodeNo = WriteOffCostAdjustment.NodeNo)
	|WHERE
	|	WriteOffCostAdjustment.Recorder = &Recorder
	|
	|ORDER BY
	|	NodeNo DESC";

	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("DateBeg",				DateBeg);
	Query.SetParameter("DateEnd",				DateEnd);
	Query.SetParameter("Recorder",				Ref);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	Result = Query.ExecuteBatch();
	
	If Result[3].IsEmpty() Then
		Return;
	EndIf;
	
	TableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory;

	TableWorkInProgress = Undefined;
	// begin Drive.FullVersion
	TableWorkInProgress = StructureAdditionalProperties.TableForRegisterRecords.TableWorkInProgress;
	// end Drive.FullVersion
	
	TableSales = StructureAdditionalProperties.TableForRegisterRecords.TableSales;
	
	TableIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses;
	
	TablePOSSummary = StructureAdditionalProperties.TableForRegisterRecords.TablePOSSummary;
	
	TableCostOfSubcontractorGoods = StructureAdditionalProperties.TableForRegisterRecords.TableCostOfSubcontractorGoods;
	
	UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	If UseDefaultTypeOfAccounting Then
		TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
	EndIf;
	
	ResultTable = Result[3].Unload();
	
	For Each SelectionDetailRecords In ResultTable Do
		
		// Calculate amounts of transfer and correction.
		SumOfMovement = SelectionDetailRecords.Price * SelectionDetailRecords.Quantity;
		CorrectionAmount = SumOfMovement - SelectionDetailRecords.Amount;
		
		If Round(CorrectionAmount, 2) <> 0 Then
			
			// Movements on the register Inventory and costs accounting.
			ParametersForRecords = ParametersForRecordsByExpensesRegister();
			GenerateRegisterRecordsByExpensesRegister(
				Ref,
				TableInventory,
				TableWorkInProgress,
				TableAccountingJournalEntries,
				SelectionDetailRecords,
				CorrectionAmount,
				False,
				ParametersForRecords);
				
			If SelectionDetailRecords.CorrIncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.CostOfSales Then
				
				If ValueIsFilled(SelectionDetailRecords.SourceDocument)
					And ((TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.SalesInvoice")
							And SelectionDetailRecords.WriteOffIncomeAndExpenseType <> Catalogs.IncomeAndExpenseTypes.OtherIncome)
						Or TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.ShiftClosure")
						Or TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.AccountSalesFromConsignee")
						// begin Drive.FullVersion
						Or TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.SubcontractorInvoiceIssued")
						// end Drive.FullVersion
						Or TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.SalesOrder")) Then
					
					// Movements on the register Sales.
					NewRow = TableSales.Add();
					NewRow.Period				= Ref.Date;
					NewRow.Recorder				= Ref;
					NewRow.Company				= SelectionDetailRecords.Company;
					NewRow.PresentationCurrency	= SelectionDetailRecords.PresentationCurrency;
					NewRow.Counterparty			= SelectionDetailRecords.Counterparty;
					NewRow.Currency				= SelectionDetailRecords.Currency;
					NewRow.SalesOrder			= SelectionDetailRecords.SalesOrder;
					NewRow.Department			= SelectionDetailRecords.Department;
					NewRow.Responsible			= SelectionDetailRecords.Responsible;
					NewRow.Products				= SelectionDetailRecords.Products;
					NewRow.Characteristic		= SelectionDetailRecords.Characteristic;
					NewRow.Batch				= SelectionDetailRecords.Batch;
					NewRow.Ownership			= SelectionDetailRecords.Ownership;
					NewRow.Document				= SelectionDetailRecords.SourceDocument;
					NewRow.VATRate				= SelectionDetailRecords.VATRate;
					NewRow.Cost					= CorrectionAmount;
					NewRow.Active 				= True;
					
					// Movements on the register IncomeAndExpenses.
					NewRow = TableIncomeAndExpenses.Add();
					NewRow.Period				= Ref.Date;
					NewRow.Recorder				= Ref;
					NewRow.Company				= SelectionDetailRecords.Company;
					NewRow.PresentationCurrency	= SelectionDetailRecords.PresentationCurrency;
					NewRow.StructuralUnit		= SelectionDetailRecords.Department;
					NewRow.SalesOrder			= SelectionDetailRecords.SalesOrder;
					If Not ValueIsFilled(NewRow.SalesOrder) Then
						NewRow.SalesOrder = Undefined;
					EndIf;
					NewRow.BusinessLine					= SelectionDetailRecords.BusinessLineSales;
					NewRow.IncomeAndExpenseItem			= SelectionDetailRecords.CorrIncomeAndExpenseItem;
					NewRow.GLAccount					= SelectionDetailRecords.CorrGLAccount;
					NewRow.AmountExpense				= CorrectionAmount;
					NewRow.ContentOfAccountingRecord	= NStr("en = 'Record expenses'; ru = 'Отражение расходов';pl = 'Rejestr rozchodów';es_ES = 'Registrar los gastos';es_CO = 'Registrar los gastos';tr = 'Masrafların yansıtılması';it = 'Registrazione spese';de = 'Ausgaben buchen'", DefaultLanguageCode);
					NewRow.Active						= True;
				EndIf;
				
			ElsIf SelectionDetailRecords.InventoryAccountType = Enums.InventoryAccountTypes.ComponentsForSubcontractor Then
				
				NewRow = TableCostOfSubcontractorGoods.Add();
				NewRow.Period							= Ref.Date;
				NewRow.Recorder							= Ref;
				NewRow.Company							= SelectionDetailRecords.Company;
				NewRow.PresentationCurrency				= SelectionDetailRecords.PresentationCurrency;
				NewRow.Counterparty						= SelectionDetailRecords.Counterparty;
				NewRow.SubcontractorOrder				= SelectionDetailRecords.SourceDocument;
				NewRow.FinishedProducts					= SelectionDetailRecords.ProductsCorr;
				NewRow.FinishedProductsCharacteristic	= SelectionDetailRecords.CharacteristicCorr;
				NewRow.Products							= SelectionDetailRecords.Products;
				NewRow.Characteristic					= SelectionDetailRecords.Characteristic;
				NewRow.Amount							= CorrectionAmount;
				NewRow.Active							= True;
				
			ElsIf SelectionDetailRecords.CorrInventoryAccountType = StructureAdditionalProperties.ForPosting.EmptyInventoryAccountType Then
				
				If ValueIsFilled(SelectionDetailRecords.SourceDocument)
					And ((TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.SalesInvoice")
							And SelectionDetailRecords.WriteOffIncomeAndExpenseType <> Catalogs.IncomeAndExpenseTypes.OtherIncome)
						Or TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.ShiftClosure")
						Or TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.AccountSalesFromConsignee")
						Or TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.SalesOrder")) Then
					
					// Movements on the register Sales.
					NewRow = TableSales.Add();
					NewRow.Period				= Ref.Date;
					NewRow.Recorder				= Ref;
					NewRow.Company				= SelectionDetailRecords.Company;
					NewRow.PresentationCurrency	= SelectionDetailRecords.PresentationCurrency;
					NewRow.Counterparty			= SelectionDetailRecords.Counterparty;
					NewRow.Currency				= SelectionDetailRecords.Currency;
					NewRow.SalesOrder			= SelectionDetailRecords.SalesOrder;
					NewRow.Department			= SelectionDetailRecords.Department;
					NewRow.Responsible			= SelectionDetailRecords.Responsible;
					NewRow.Products				= SelectionDetailRecords.Products;
					NewRow.Characteristic		= SelectionDetailRecords.Characteristic;
					NewRow.Batch				= SelectionDetailRecords.Batch;
					NewRow.Ownership			= SelectionDetailRecords.Ownership;
					NewRow.Document				= SelectionDetailRecords.SourceDocument;
					NewRow.VATRate				= SelectionDetailRecords.VATRate;
					NewRow.Cost					= CorrectionAmount;
					NewRow.Active				= True;
					
					// Movements on the register IncomeAndExpenses.
					NewRow = TableIncomeAndExpenses.Add();
					NewRow.Period						= Ref.Date;
					NewRow.Recorder						= Ref;
					NewRow.Company						= SelectionDetailRecords.Company;
					NewRow.PresentationCurrency			= SelectionDetailRecords.PresentationCurrency;
					NewRow.StructuralUnit				= SelectionDetailRecords.Department;
					NewRow.SalesOrder					= SelectionDetailRecords.SalesOrder;
					If Not ValueIsFilled(NewRow.SalesOrder) Then
						NewRow.SalesOrder = Undefined;
					EndIf;
					NewRow.BusinessLine					= SelectionDetailRecords.BusinessLineSales;
					NewRow.IncomeAndExpenseItem			= SelectionDetailRecords.CorrIncomeAndExpenseItem;
					NewRow.GLAccount					= SelectionDetailRecords.BusinessLineSalesGLAccountOfSalesCost;
					NewRow.AmountExpense				= CorrectionAmount;
					NewRow.ContentOfAccountingRecord	= NStr("en = 'Record expenses'; ru = 'Отражение расходов';pl = 'Rejestr rozchodów';es_ES = 'Registrar los gastos';es_CO = 'Registrar los gastos';tr = 'Masrafların yansıtılması';it = 'Registrazione spese';de = 'Ausgaben buchen'", DefaultLanguageCode);
					NewRow.Active				= True;
					
					// Movements by register AccountingJournalEntries.
					If UseDefaultTypeOfAccounting Then
						
						NewRow = TableAccountingJournalEntries.Add();
						NewRow.Active			= True;
						NewRow.Period			= Ref.Date;
						NewRow.Recorder			= Ref;
						NewRow.Company			= SelectionDetailRecords.Company;
						NewRow.PlanningPeriod	= Catalogs.PlanningPeriods.Actual;
						NewRow.AccountDr		= SelectionDetailRecords.BusinessLineSalesGLAccountOfSalesCost;
						NewRow.AccountCr		= SelectionDetailRecords.GLAccount;
						NewRow.Content			= NStr("en = 'Record expenses'; ru = 'Отражение расходов';pl = 'Rejestr rozchodów';es_ES = 'Registrar los gastos';es_CO = 'Registrar los gastos';tr = 'Masrafların yansıtılması';it = 'Registrazione spese';de = 'Ausgaben buchen'", DefaultLanguageCode);
						NewRow.Amount			= CorrectionAmount;
						
					EndIf;
					
				ElsIf ValueIsFilled(SelectionDetailRecords.SourceDocument)
						And SelectionDetailRecords.WriteOffIncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.OtherIncome Then
						
					// Movements on the register Income and expenses.
					NewRow = TableIncomeAndExpenses.Add();
					NewRow.Period               = StructureAdditionalProperties.ForPosting.Date;
					NewRow.Recorder             = Ref;
					NewRow.Company              = SelectionDetailRecords.Company;
					NewRow.PresentationCurrency = SelectionDetailRecords.PresentationCurrency;
					NewRow.StructuralUnit       = SelectionDetailRecords.StructuralUnitPayee;
					NewRow.BusinessLine         = Catalogs.LinesOfBusiness.Other;
					NewRow.Active				= True;
					
					NewRow.IncomeAndExpenseItem = SelectionDetailRecords.CorrIncomeAndExpenseItem;
					NewRow.GLAccount                 = SelectionDetailRecords.GLAccountWriteOff;
					NewRow.AmountExpense             = CorrectionAmount;
					NewRow.ContentOfAccountingRecord = NStr("en = 'Other expenses'; ru = 'Прочие затраты (расходы)';pl = 'Inne rozchody';es_ES = 'Otros gastos';es_CO = 'Otros gastos';tr = 'Diğer masraflar';it = 'Altre spese';de = 'Sonstige Ausgaben'", DefaultLanguageCode);
					
					// Movements by register AccountingJournalEntries.
					If UseDefaultTypeOfAccounting Then
						
						NewRow = TableAccountingJournalEntries.Add();
						NewRow.Active = True;
						NewRow.Period = Ref.Date;
						NewRow.Recorder = Ref;
						NewRow.Company = SelectionDetailRecords.Company;
						NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
						NewRow.AccountDr = SelectionDetailRecords.GLAccountWriteOff;
						NewRow.AccountCr = SelectionDetailRecords.GLAccount;
						NewRow.Content = NStr("en = 'Other expenses'; ru = 'Прочие затраты (расходы)';pl = 'Inne rozchody';es_ES = 'Otros gastos';es_CO = 'Otros gastos';tr = 'Diğer masraflar';it = 'Altre spese';de = 'Sonstige Ausgaben'", DefaultLanguageCode);
						NewRow.Amount = CorrectionAmount;
						
					EndIf;
					
				ElsIf SelectionDetailRecords.RetailTransferEarningAccounting Then
					
					// Movements on the register POSSummary.
					NewRow = TablePOSSummary.Add();
					NewRow.Period 				= Ref.Date;
					NewRow.RecordType 			= AccumulationRecordType.Receipt;
					NewRow.Recorder 			= Ref;
					NewRow.Company 				= SelectionDetailRecords.Company;
					NewRow.PresentationCurrency = SelectionDetailRecords.PresentationCurrency;
					NewRow.StructuralUnit 		= SelectionDetailRecords.RetailStructuralUnit;
					NewRow.Currency 			= SelectionDetailRecords.RetailStructuralUnit.RetailPriceKind.PriceCurrency;
					NewRow.Cost 				= CorrectionAmount;
					NewRow.Active 				= True;
					NewRow.ContentOfAccountingRecord = NStr("en = 'Move to retail'; ru = 'Перемещение в розницу';pl = 'Przeniesienie do sprzedaży detalicznej';es_ES = 'Mover a la venta al por menor';es_CO = 'Mover a la venta al por menor';tr = 'Perakendeye geç';it = 'Spostare alla vendita al dettaglio';de = 'In den Einzelhandel wechseln'", DefaultLanguageCode);
					
					// Movements by register AccountingJournalEntries.
					If UseDefaultTypeOfAccounting Then
						
						NewRow = TableAccountingJournalEntries.Add();
						NewRow.Active		= True;
						NewRow.Period 		= Ref.Date;
						NewRow.Recorder 	= Ref;
						NewRow.Company 		= SelectionDetailRecords.Company;
						NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
						NewRow.AccountDr 	= SelectionDetailRecords.RetailStructuralUnit.GLAccountInRetail;
						NewRow.AccountCr 	= SelectionDetailRecords.GLAccount;
						NewRow.Content 		= NStr("en = 'Move to retail'; ru = 'Перемещение в розницу';pl = 'Przeniesienie do sprzedaży detalicznej';es_ES = 'Mover a la venta al por menor';es_CO = 'Mover a la venta al por menor';tr = 'Perakendeye geç';it = 'Spostare alla vendita al dettaglio';de = 'In den Einzelhandel wechseln'", DefaultLanguageCode);
						NewRow.Amount 		= CorrectionAmount;
						
					EndIf;
					
				ElsIf SelectionDetailRecords.WriteOffIncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.OtherExpenses
					Or SelectionDetailRecords.WriteOffIncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses Then
					
					// Movements on the register Income and expenses.
					NewRow = TableIncomeAndExpenses.Add();
					NewRow.Period = StructureAdditionalProperties.ForPosting.Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.PresentationCurrency = SelectionDetailRecords.PresentationCurrency;
					NewRow.StructuralUnit = SelectionDetailRecords.StructuralUnitPayee;
					NewRow.Active = True;
					If TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.InventoryTransfer")
						And SelectionDetailRecords.WriteOffIncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses Then
						
						NewRow.BusinessLine = SelectionDetailRecords.ActivityDirectionWriteOff;
						NewRow.SalesOrder = SelectionDetailRecords.SalesOrder;
						If Not ValueIsFilled(NewRow.SalesOrder) Then
							NewRow.SalesOrder = Undefined;
						EndIf;
						
					Else
						NewRow.BusinessLine = Catalogs.LinesOfBusiness.Other;
					EndIf;
					
					NewRow.IncomeAndExpenseItem = SelectionDetailRecords.CorrIncomeAndExpenseItem;
					NewRow.GLAccount = SelectionDetailRecords.GLAccountWriteOff;
					NewRow.AmountExpense = CorrectionAmount;
					NewRow.ContentOfAccountingRecord = NStr("en = 'Other expenses'; ru = 'Прочие затраты (расходы)';pl = 'Inne rozchody';es_ES = 'Otros gastos';es_CO = 'Otros gastos';tr = 'Diğer masraflar';it = 'Altre spese';de = 'Sonstige Ausgaben'", DefaultLanguageCode);
					
					// Movements by register AccountingJournalEntries.
					If UseDefaultTypeOfAccounting Then
						
						NewRow = TableAccountingJournalEntries.Add();
						NewRow.Active			= True;
						NewRow.Period 			= Ref.Date;
						NewRow.Recorder 		= Ref;
						NewRow.Company 			= SelectionDetailRecords.Company;
						NewRow.PlanningPeriod 	= Catalogs.PlanningPeriods.Actual;
						NewRow.AccountDr 		= SelectionDetailRecords.GLAccountWriteOff;
						NewRow.AccountCr 		= SelectionDetailRecords.GLAccount;
						NewRow.Content 			= NStr("en = 'Other expenses'; ru = 'Прочие затраты (расходы)';pl = 'Inne rozchody';es_ES = 'Otros gastos';es_CO = 'Otros gastos';tr = 'Diğer masraflar';it = 'Altre spese';de = 'Sonstige Ausgaben'", DefaultLanguageCode);
						NewRow.Amount 			= CorrectionAmount;
						
					EndIf;
					
				ElsIf UseDefaultTypeOfAccounting Then 
					
					// Movements by register AccountingJournalEntries.
					NewRow = TableAccountingJournalEntries.Add();
					NewRow.Active				= True;
					NewRow.Period 				= Ref.Date;
					NewRow.Recorder 			= Ref;
					NewRow.Company 				= SelectionDetailRecords.Company;
					NewRow.PlanningPeriod 		= Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr 			= SelectionDetailRecords.GLAccountWriteOff;
					NewRow.AccountCr 			= SelectionDetailRecords.GLAccount;
					NewRow.Content 				= NStr("en = 'Inventory write-off'; ru = 'Списание запасов';pl = 'Rozchód zapasów';es_ES = 'Amortización del inventario';es_CO = 'Amortización del inventario';tr = 'Stok azaltma';it = 'Cancellazione di scorte';de = 'Bestandsabschreibung'", DefaultLanguageCode);
					NewRow.Amount 				= CorrectionAmount;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;

	TemporaryConvertTable(TableInventory, "TableInventory", StructureAdditionalProperties);
	
EndProcedure

Procedure GenerateCorrectiveRegisterRecordsByFIFO(StructureAdditionalProperties)
	
	DateBeg = StructureAdditionalProperties.ForPosting.BeginOfPeriodningDate;
	DateEnd = StructureAdditionalProperties.ForPosting.EndDatePeriod;
	Company = StructureAdditionalProperties.ForPosting.Company;
	
	FIFO.CalculateAll(EndOfMonth(DateEnd), Company);
	
	Query = New Query();
	
	Query.Text =
	"SELECT ALLOWED
	|	CostLayers.Recorder AS Recorder,
	|	CostLayers.Period AS Period,
	|	CostLayers.RecordType AS RecordType,
	|	CostLayers.Company AS Company,
	|	CostLayers.PresentationCurrency AS PresentationCurrency,
	|	CostLayers.Products AS Products,
	|	CostLayers.SalesOrder AS SalesOrder,
	|	CostLayers.Characteristic AS Characteristic,
	|	CostLayers.Batch AS Batch,
	|	CostLayers.Ownership AS Ownership,
	|	CostLayers.StructuralUnit AS StructuralUnit,
	|	CostLayers.InventoryAccountType AS InventoryAccountType,
	|	0 AS Quantity,
	|	SUM(CostLayers.Amount) AS Amount,
	|	CostLayers.VATRate AS VATRate,
	|	CostLayers.Responsible AS Responsible,
	|	CostLayers.Department AS Department,
	|	CostLayers.SourceDocument AS SourceDocument,
	|	CostLayers.CorrStructuralUnit AS CorrStructuralUnit,
	|	CostLayers.CorrGLAccount AS CorrGLAccount,
	|	CostLayers.RIMTransfer AS RetailTransferEarningAccounting,
	|	CostLayers.SalesRep AS SalesRep,
	|	CostLayers.Counterparty AS Counterparty,
	|	CostLayers.Currency AS Currency,
	|	CostLayers.CostObject AS CostObject,
	|	CostLayers.CorrCostObject AS CorrCostObject,
	|	CostLayers.CorrProducts AS CorrProducts,
	|	CostLayers.CorrCharacteristic AS CorrCharacteristic,
	|	CostLayers.CorrBatch AS CorrBatch,
	|	CostLayers.CorrOwnership AS CorrOwnership,
	|	CostLayers.CorrSpecification AS CorrSpecification,
	|	CostLayers.Specification AS Specification,
	|	CostLayers.GLAccount AS GLAccount,
	|	CostLayers.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	CostLayers.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	CostLayers.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	CostLayers.CorrSalesOrder AS CorrSalesOrder
	|INTO Costslayers
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS CostLayers
	|WHERE
	|	CostLayers.Period BETWEEN &DateBeg AND &DateEnd
	|	AND CostLayers.Company = &Company
	|	AND NOT CostLayers.SourceRecord
	|	AND CostLayers.PresentationCurrency = &PresentationCurrency
	|
	|GROUP BY
	|	CostLayers.Recorder,
	|	CostLayers.Period,
	|	CostLayers.RecordType,
	|	CostLayers.Company,
	|	CostLayers.PresentationCurrency,
	|	CostLayers.StructuralUnit,
	|	CostLayers.GLAccount,
	|	CostLayers.Products,
	|	CostLayers.Characteristic,
	|	CostLayers.Batch,
	|	CostLayers.Ownership,
	|	CostLayers.SalesOrder,
	|	CostLayers.CorrStructuralUnit,
	|	CostLayers.CorrGLAccount,
	|	CostLayers.SourceDocument,
	|	CostLayers.Department,
	|	CostLayers.Responsible,
	|	CostLayers.VATRate,
	|	CostLayers.RIMTransfer,
	|	CostLayers.SalesRep,
	|	CostLayers.Counterparty,
	|	CostLayers.Currency,
	|	CostLayers.CostObject,
	|	CostLayers.CorrCostObject,
	|	CostLayers.CorrProducts,
	|	CostLayers.CorrCharacteristic,
	|	CostLayers.CorrBatch,
	|	CostLayers.CorrOwnership,
	|	CostLayers.CorrSpecification,
	|	CostLayers.Specification,
	|	CostLayers.IncomeAndExpenseItem,
	|	CostLayers.InventoryAccountType,
	|	CostLayers.CorrInventoryAccountType,
	|	CostLayers.CorrIncomeAndExpenseItem,
	|	CostLayers.CorrSalesOrder
	|
	|UNION ALL
	|
	|SELECT
	|	LandedCosts.Recorder,
	|	LandedCosts.Period,
	|	LandedCosts.RecordType,
	|	LandedCosts.Company,
	|	LandedCosts.PresentationCurrency,
	|	LandedCosts.Products,
	|	LandedCosts.SalesOrder,
	|	LandedCosts.Characteristic,
	|	LandedCosts.Batch,
	|	LandedCosts.Ownership,
	|	LandedCosts.StructuralUnit,
	|	LandedCosts.InventoryAccountType,
	|	0,
	|	SUM(LandedCosts.Amount),
	|	LandedCosts.VATRate,
	|	LandedCosts.Responsible,
	|	LandedCosts.Department,
	|	LandedCosts.SourceDocument,
	|	LandedCosts.CorrStructuralUnit,
	|	LandedCosts.CorrGLAccount,
	|	LandedCosts.RIMTransfer,
	|	LandedCosts.SalesRep,
	|	LandedCosts.Counterparty,
	|	LandedCosts.Currency,
	|	LandedCosts.CostObject,
	|	LandedCosts.CorrCostObject,
	|	LandedCosts.CorrProducts,
	|	LandedCosts.CorrCharacteristic,
	|	LandedCosts.CorrBatch,
	|	LandedCosts.CorrOwnership,
	|	LandedCosts.CorrSpecification,
	|	LandedCosts.Specification,
	|	LandedCosts.GLAccount,
	|	LandedCosts.CorrInventoryAccountType,
	|	LandedCosts.IncomeAndExpenseItem,
	|	LandedCosts.CorrIncomeAndExpenseItem,
	|	LandedCosts.CorrSalesOrder
	|FROM
	|	AccumulationRegister.LandedCosts AS LandedCosts
	|WHERE
	|	LandedCosts.Period BETWEEN &DateBeg AND &DateEnd
	|	AND LandedCosts.Company = &Company
	|	AND LandedCosts.PresentationCurrency = &PresentationCurrency
	|	AND NOT LandedCosts.SourceRecord
	|
	|GROUP BY
	|	LandedCosts.Recorder,
	|	LandedCosts.Period,
	|	LandedCosts.RecordType,
	|	LandedCosts.Company,
	|	LandedCosts.PresentationCurrency,
	|	LandedCosts.StructuralUnit,
	|	LandedCosts.GLAccount,
	|	LandedCosts.Products,
	|	LandedCosts.Characteristic,
	|	LandedCosts.Batch,
	|	LandedCosts.Ownership,
	|	LandedCosts.SalesOrder,
	|	LandedCosts.CorrStructuralUnit,
	|	LandedCosts.CorrGLAccount,
	|	LandedCosts.SourceDocument,
	|	LandedCosts.Department,
	|	LandedCosts.Responsible,
	|	LandedCosts.VATRate,
	|	LandedCosts.RIMTransfer,
	|	LandedCosts.SalesRep,
	|	LandedCosts.Counterparty,
	|	LandedCosts.Currency,
	|	LandedCosts.CostObject,
	|	LandedCosts.CorrCostObject,
	|	LandedCosts.CorrOwnership,
	|	LandedCosts.CorrBatch,
	|	LandedCosts.CorrCharacteristic,
	|	LandedCosts.CorrProducts,
	|	LandedCosts.CorrSpecification,
	|	LandedCosts.Specification,
	|	LandedCosts.IncomeAndExpenseItem,
	|	LandedCosts.CorrIncomeAndExpenseItem,
	|	LandedCosts.InventoryAccountType,
	|	LandedCosts.CorrInventoryAccountType,
	|	LandedCosts.CorrSalesOrder
	|
	|UNION ALL
	|
	|SELECT
	|	LandedCosts.Recorder,
	|	LandedCosts.Period,
	|	LandedCosts.RecordType,
	|	LandedCosts.Company,
	|	LandedCosts.PresentationCurrency,
	|	LandedCosts.Products,
	|	LandedCosts.SalesOrder,
	|	LandedCosts.Characteristic,
	|	LandedCosts.Batch,
	|	LandedCosts.Ownership,
	|	LandedCosts.StructuralUnit,
	|	LandedCosts.InventoryAccountType,
	|	0,
	|	SUM(LandedCosts.Amount),
	|	LandedCosts.VATRate,
	|	LandedCosts.Responsible,
	|	LandedCosts.Department,
	|	LandedCosts.SourceDocument,
	|	LandedCosts.CorrStructuralUnit,
	|	LandedCosts.CorrGLAccount,
	|	LandedCosts.RIMTransfer,
	|	LandedCosts.SalesRep,
	|	LandedCosts.Counterparty,
	|	LandedCosts.Currency,
	|	LandedCosts.CostObject,
	|	LandedCosts.CorrCostObject,
	|	LandedCosts.CorrProducts,
	|	LandedCosts.CorrCharacteristic,
	|	LandedCosts.CorrBatch,
	|	LandedCosts.CorrOwnership,
	|	LandedCosts.CorrSpecification,
	|	LandedCosts.Specification,
	|	LandedCosts.GLAccount,
	|	LandedCosts.CorrInventoryAccountType,
	|	LandedCosts.IncomeAndExpenseItem,
	|	LandedCosts.CorrIncomeAndExpenseItem,
	|	LandedCosts.CorrSalesOrder
	|FROM
	|	AccumulationRegister.LandedCosts AS LandedCosts
	|WHERE
	|	LandedCosts.Period BETWEEN &DateBeg AND &DateEnd
	|	AND LandedCosts.Company = &Company
	|	AND LandedCosts.PresentationCurrency = &PresentationCurrency
	|	AND VALUETYPE(LandedCosts.Recorder) = TYPE(Document.MonthEndClosing)
	|
	|GROUP BY
	|	LandedCosts.Recorder,
	|	LandedCosts.Period,
	|	LandedCosts.RecordType,
	|	LandedCosts.Company,
	|	LandedCosts.PresentationCurrency,
	|	LandedCosts.StructuralUnit,
	|	LandedCosts.GLAccount,
	|	LandedCosts.Products,
	|	LandedCosts.Characteristic,
	|	LandedCosts.Batch,
	|	LandedCosts.Ownership,
	|	LandedCosts.SalesOrder,
	|	LandedCosts.CorrStructuralUnit,
	|	LandedCosts.CorrGLAccount,
	|	LandedCosts.SourceDocument,
	|	LandedCosts.Department,
	|	LandedCosts.Responsible,
	|	LandedCosts.VATRate,
	|	LandedCosts.RIMTransfer,
	|	LandedCosts.SalesRep,
	|	LandedCosts.Counterparty,
	|	LandedCosts.Currency,
	|	LandedCosts.CostObject,
	|	LandedCosts.CorrCostObject,
	|	LandedCosts.CorrOwnership,
	|	LandedCosts.CorrBatch,
	|	LandedCosts.CorrCharacteristic,
	|	LandedCosts.CorrProducts,
	|	LandedCosts.CorrSpecification,
	|	LandedCosts.Specification,
	|	LandedCosts.CorrIncomeAndExpenseItem,
	|	LandedCosts.InventoryAccountType,
	|	LandedCosts.IncomeAndExpenseItem,
	|	LandedCosts.CorrInventoryAccountType,
	|	LandedCosts.CorrSalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CostLayers.Recorder AS Recorder,
	|	CostLayers.Period AS Period,
	|	CostLayers.RecordType AS RecordType,
	|	CostLayers.Company AS Company,
	|	CostLayers.PresentationCurrency AS PresentationCurrency,
	|	CostLayers.Products AS Products,
	|	CostLayers.SalesOrder AS SalesOrder,
	|	CostLayers.Characteristic AS Characteristic,
	|	CostLayers.Batch AS Batch,
	|	CostLayers.Ownership AS Ownership,
	|	CostLayers.StructuralUnit AS StructuralUnit,
	|	CostLayers.InventoryAccountType AS InventoryAccountType,
	|	CostLayers.Quantity AS Quantity,
	|	SUM(CostLayers.Amount) AS Amount,
	|	CostLayers.VATRate AS VATRate,
	|	CostLayers.Responsible AS Responsible,
	|	CostLayers.Department AS Department,
	|	CostLayers.SourceDocument AS SourceDocument,
	|	CostLayers.CorrStructuralUnit AS CorrStructuralUnit,
	|	CostLayers.CorrGLAccount AS CorrGLAccount,
	|	CostLayers.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	CostLayers.SalesRep AS SalesRep,
	|	CostLayers.Counterparty AS Counterparty,
	|	CostLayers.Currency AS Currency,
	|	CostLayers.CostObject AS CostObject,
	|	CostLayers.CorrCostObject AS CorrCostObject,
	|	CostLayers.CorrProducts AS CorrProducts,
	|	CostLayers.CorrCharacteristic AS CorrCharacteristic,
	|	CostLayers.CorrBatch AS CorrBatch,
	|	CostLayers.CorrOwnership AS CorrOwnership,
	|	CostLayers.CorrSpecification AS CorrSpecification,
	|	CostLayers.Specification AS Specification,
	|	CostLayers.GLAccount AS GLAccount,
	|	CostLayers.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	CostLayers.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	CostLayers.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	CostLayers.CorrSalesOrder AS CorrSalesOrder
	|INTO FullCostslayers
	|FROM
	|	Costslayers AS CostLayers
	|
	|GROUP BY
	|	CostLayers.Recorder,
	|	CostLayers.Period,
	|	CostLayers.RecordType,
	|	CostLayers.Company,
	|	CostLayers.PresentationCurrency,
	|	CostLayers.Products,
	|	CostLayers.SalesOrder,
	|	CostLayers.Characteristic,
	|	CostLayers.Batch,
	|	CostLayers.Ownership,
	|	CostLayers.StructuralUnit,
	|	CostLayers.GLAccount,
	|	CostLayers.Quantity,
	|	CostLayers.VATRate,
	|	CostLayers.Responsible,
	|	CostLayers.Department,
	|	CostLayers.SourceDocument,
	|	CostLayers.CorrStructuralUnit,
	|	CostLayers.CorrGLAccount,
	|	CostLayers.RetailTransferEarningAccounting,
	|	CostLayers.SalesRep,
	|	CostLayers.Counterparty,
	|	CostLayers.Currency,
	|	CostLayers.CostObject,
	|	CostLayers.CorrCostObject,
	|	CostLayers.CorrProducts,
	|	CostLayers.CorrCharacteristic,
	|	CostLayers.CorrBatch,
	|	CostLayers.CorrOwnership,
	|	CostLayers.CorrSpecification,
	|	CostLayers.Specification,
	|	CostLayers.CorrInventoryAccountType,
	|	CostLayers.CorrIncomeAndExpenseItem,
	|	CostLayers.InventoryAccountType,
	|	CostLayers.IncomeAndExpenseItem,
	|	CostLayers.CorrSalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CostLayers.Recorder AS Ref,
	|	CostLayers.Period AS Period,
	|	CostLayers.RecordType AS RecordType,
	|	CostLayers.Company AS Company,
	|	CostLayers.PresentationCurrency AS PresentationCurrency,
	|	CostLayers.StructuralUnit AS StructuralUnit,
	|	CostLayers.InventoryAccountType AS InventoryAccountType,
	|	CostLayers.GLAccount AS GLAccount,
	|	IncomeAndExpenseItems.IncomeAndExpenseType AS IncomeAndExpenseType,
	|	CostLayers.Products AS Products,
	|	CostLayers.Characteristic AS Characteristic,
	|	CostLayers.Batch AS Batch,
	|	CostLayers.Ownership AS Ownership,
	|	CostLayers.SalesOrder AS SalesOrder,
	|	CostLayers.Quantity AS Quantity,
	|	CostLayers.Amount AS Amount,
	|	CostLayers.CorrStructuralUnit AS StructuralUnitCorr,
	|	CostLayers.CorrGLAccount AS CorrGLAccount,
	|	CorrIncomeAndExpenseItems.IncomeAndExpenseType AS CorrIncomeAndExpenseType,
	|	UNDEFINED AS CustomerCorrOrder,
	|	CostLayers.Specification AS Specification,
	|	CostLayers.CorrSpecification AS SpecificationCorr,
	|	CostLayers.SourceDocument AS SourceDocument,
	|	CostLayers.Department AS Department,
	|	CostLayers.Responsible AS Responsible,
	|	CostLayers.VATRate AS VATRate,
	|	FALSE AS FixedCost,
	|	FALSE AS ProductionExpenses,
	|	CASE
	|		WHEN VALUETYPE(CostLayers.Recorder) = TYPE(Document.CreditNote)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS Return,
	|	UNDEFINED AS ContentOfAccountingRecord,
	|	CostLayers.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	CASE
	|		WHEN CostLayers.RetailTransferEarningAccounting
	|			THEN ISNULL(SupplierInvoice.StructuralUnit, InventoryTransfer.StructuralUnit)
	|		ELSE UNDEFINED
	|	END AS StructuralUnitPayee,
	|	RetailPriceTypes.PriceCurrency AS RetailPriceCurrency,
	|	CostLayers.Products.BusinessLine AS BusinessLine,
	|	CostLayers.SalesRep AS SalesRep,
	|	CostLayers.Counterparty AS Counterparty,
	|	CostLayers.Currency AS Currency,
	|	CASE
	|		WHEN VALUETYPE(CostLayers.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostLayers.SourceDocument.BusinessLine
	|		ELSE UNDEFINED
	|	END AS ActivityDirectionWriteOff,
	|	CostLayers.CostObject AS CostObject,
	|	CostLayers.CorrCostObject AS CostObjectCorr,
	|	CostLayers.CorrProducts AS ProductsCorr,
	|	CostLayers.CorrCharacteristic AS CharacteristicCorr,
	|	CostLayers.CorrBatch AS BatchCorr,
	|	CostLayers.CorrOwnership AS OwnershipCorr,
	|	CostLayers.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	CostLayers.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	CostLayers.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	CostLayers.CorrSalesOrder AS CorrSalesOrder,
	|	ISNULL(SubcontractorInvoiceReceived.BasisDocument, UNDEFINED) AS SubcontractorOrder
	|FROM
	|	FullCostslayers AS CostLayers
	|		LEFT JOIN Catalog.Products AS Product
	|		ON CostLayers.Products = Product.Ref
	|		LEFT JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON CostLayers.SourceDocument = SupplierInvoice.Ref
	|		LEFT JOIN Document.InventoryTransfer AS InventoryTransfer
	|		ON CostLayers.Recorder = InventoryTransfer.Ref
	|		LEFT JOIN Catalog.BusinessUnits AS RetailBusinessUnits
	|		ON CostLayers.CorrStructuralUnit = RetailBusinessUnits.Ref
	|		LEFT JOIN Catalog.PriceTypes AS RetailPriceTypes
	|		ON (RetailBusinessUnits.RetailPriceKind = RetailPriceTypes.Ref)
	|		LEFT JOIN Catalog.IncomeAndExpenseItems AS IncomeAndExpenseItems
	|		ON CostLayers.IncomeAndExpenseItem = IncomeAndExpenseItems.Ref
	|		LEFT JOIN Catalog.IncomeAndExpenseItems AS CorrIncomeAndExpenseItems
	|		ON CostLayers.CorrIncomeAndExpenseItem = CorrIncomeAndExpenseItems.Ref
	|		LEFT JOIN Document.SubcontractorInvoiceReceived AS SubcontractorInvoiceReceived
	|		ON CostLayers.Recorder = SubcontractorInvoiceReceived.Ref
	|TOTALS BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP Costslayers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP FullCostslayers";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("DateBeg", DateBeg);
	Query.SetParameter("DateEnd", DateEnd);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = Result.Select(QueryResultIteration.ByGroups);
	While Selection.Next() Do
	
		RecordSetInventory = AccumulationRegisters.Inventory.CreateRecordSet();
		RecordSetInventory.Filter.Recorder.Set(Selection.Ref);
	
		RecordSetSales = AccumulationRegisters.Sales.CreateRecordSet();
		RecordSetSales.Filter.Recorder.Set(Selection.Ref);
		
		RecordSetIncomeAndExpenses = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
		RecordSetIncomeAndExpenses.Filter.Recorder.Set(Selection.Ref);
	
		RecordSetPOSSummary = AccumulationRegisters.POSSummary.CreateRecordSet();
		RecordSetPOSSummary.Filter.Recorder.Set(Selection.Ref);
		
		// begin Drive.FullVersion
		RecordSetWorkInProgress = AccumulationRegisters.WorkInProgress.CreateRecordSet();
		RecordSetWorkInProgress.Filter.Recorder.Set(Selection.Ref);
		// end Drive.FullVersion
		
		RecordSetCostOfSubcontractorGoods = AccumulationRegisters.CostOfSubcontractorGoods.CreateRecordSet();
		RecordSetCostOfSubcontractorGoods.Filter.Recorder.Set(Selection.Ref);
		
		If UseDefaultTypeOfAccounting Then
			RecordSetAccountingJournalEntries = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
			RecordSetAccountingJournalEntries.Filter.Recorder.Set(Selection.Ref);
		EndIf;
		
		SelectionDetailRecords = Selection.Select();
	
		While SelectionDetailRecords.Next() Do
			
			Record = RecordSetInventory.Add();
			FillPropertyValues(Record, SelectionDetailRecords);
			
			IsWIP = False;
			// begin Drive.FullVersion
			IsWIP = (TypeOf(SelectionDetailRecords.Ref) = Type("DocumentRef.ManufacturingOperation"));
			// end Drive.FullVersion
			IsMonthEndClosing = (TypeOf(SelectionDetailRecords.Ref) = Type("DocumentRef.MonthEndClosing"));
			
			If SelectionDetailRecords.RecordType = AccumulationRecordType.Receipt
				And Not (TypeOf(SelectionDetailRecords.Ref) = Type("DocumentRef.CreditNote") Or IsWIP Or IsMonthEndClosing)Then
				Continue;
			EndIf;
			
			If TypeOf(SelectionDetailRecords.Ref) = Type("DocumentRef.CreditNote") Then
				Denominator = -1;
			Else
				Denominator = 1;
			EndIf;
				
			If ValueIsFilled(SelectionDetailRecords.SourceDocument)
				And (TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.SalesInvoice")
					Or TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.ShiftClosure")
					Or TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.AccountSalesFromConsignee")
					Or TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.SalesOrder")
					Or TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.GoodsIssue")
					Or (TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.WorkOrder")
						And StructureAdditionalProperties.AccountingPolicy.PostExpensesByWorkOrder))
				And TypeOf(SelectionDetailRecords.Ref) <> Type("DocumentRef.SalesOrder") Then
				
				If TypeOf(SelectionDetailRecords.SourceDocument) <> Type("DocumentRef.GoodsIssue")
					Or SelectionDetailRecords.CorrIncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.CostOfSales Then
					
					// Movements on the register Sales.
					Record = RecordSetSales.Add();
					FillPropertyValues(Record, SelectionDetailRecords);
					Record.Document  = SelectionDetailRecords.SourceDocument;
					If TypeOf(SelectionDetailRecords.Ref) <> Type("DocumentRef.ShiftClosure") Then
						Record.Counterparty = Common.ObjectAttributeValue(SelectionDetailRecords.Ref, "Counterparty");
					EndIf;
					Record.Amount    = 0;
					Record.VATAmount = 0;
					Record.Quantity  = 0;
					Record.Cost      = SelectionDetailRecords.Amount * Denominator;
					
					If TypeOf(Selection.Ref) = Type("DocumentRef.WorkOrder") Then
						Record.Products = SelectionDetailRecords.ProductsCorr;
						Record.Characteristic = SelectionDetailRecords.CharacteristicCorr;
						Record.Batch = SelectionDetailRecords.BatchCorr;
						Record.Ownership = SelectionDetailRecords.OwnershipCorr;
					EndIf;
					
					// Movements on the register IncomeAndExpenses.
					Record = RecordSetIncomeAndExpenses.Add();
					FillPropertyValues(Record, SelectionDetailRecords);
					Record.IncomeAndExpenseItem = SelectionDetailRecords.CorrIncomeAndExpenseItem;
					Record.GLAccount     = SelectionDetailRecords.CorrGLAccount;
					Record.AmountIncome  = 0;
					Record.AmountExpense = SelectionDetailRecords.Amount * Denominator;
					Record.ContentOfAccountingRecord = NStr("en = 'Record expenses'; ru = 'Отражение расходов';pl = 'Rejestr rozchodów';es_ES = 'Registrar los gastos';es_CO = 'Registrar los gastos';tr = 'Masrafların yansıtılması';it = 'Registrazione spese';de = 'Ausgaben buchen'", MainLanguageCode);
					
				EndIf;
				
				// Movements by register AccountingJournalEntries.
				If UseDefaultTypeOfAccounting Then
					
					Record = RecordSetAccountingJournalEntries.Add();
					Record.Period         = SelectionDetailRecords.Period;
					Record.Company        = SelectionDetailRecords.Company;
					Record.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					If Denominator < 1 Then
						Record.AccountDr      = SelectionDetailRecords.GLAccount;
						Record.AccountCr      = SelectionDetailRecords.CorrGLAccount;
					Else
						Record.AccountDr      = SelectionDetailRecords.CorrGLAccount;
						Record.AccountCr      = SelectionDetailRecords.GLAccount;
					EndIf;
					Record.Content        = NStr("en = 'Record expenses'; ru = 'Отражение расходов';pl = 'Rejestr rozchodów';es_ES = 'Registrar los gastos';es_CO = 'Registrar los gastos';tr = 'Masrafların yansıtılması';it = 'Registrazione spese';de = 'Ausgaben buchen'", MainLanguageCode);
					Record.Amount         = SelectionDetailRecords.Amount;
					
				EndIf;
					
			ElsIf ValueIsFilled(SelectionDetailRecords.SourceDocument)
				And SelectionDetailRecords.CorrIncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.OtherIncome Then
				
				// Movements on the register Income and expenses.
				Record = RecordSetIncomeAndExpenses.Add();
				Record.Period               = SelectionDetailRecords.Period;
				Record.Company              = SelectionDetailRecords.Company;
				Record.PresentationCurrency = SelectionDetailRecords.PresentationCurrency;
				Record.StructuralUnit       = SelectionDetailRecords.StructuralUnitCorr;
				Record.BusinessLine         = Catalogs.LinesOfBusiness.Other;
				Record.IncomeAndExpenseItem = SelectionDetailRecords.CorrIncomeAndExpenseItem;
				Record.GLAccount            = SelectionDetailRecords.CorrGLAccount;
				Record.AmountExpense 	    = SelectionDetailRecords.Amount * Denominator;
				Record.ContentOfAccountingRecord = NStr("en = 'Other expenses'; ru = 'Прочие затраты (расходы)';pl = 'Inne rozchody';es_ES = 'Otros gastos';es_CO = 'Otros gastos';tr = 'Diğer masraflar';it = 'Altre spese';de = 'Sonstige Ausgaben'", MainLanguageCode);
				
				// Movements by register AccountingJournalEntries.
				If UseDefaultTypeOfAccounting Then
					
					Record = RecordSetAccountingJournalEntries.Add();
					Record.Period         = SelectionDetailRecords.Period;
					Record.Company        = SelectionDetailRecords.Company;
					Record.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					Record.AccountDr      = SelectionDetailRecords.CorrGLAccount;
					Record.AccountCr      = SelectionDetailRecords.GLAccount;
					Record.Amount         = SelectionDetailRecords.Amount * Denominator;
					Record.Content        = NStr("en = 'Other expenses'; ru = 'Прочие затраты (расходы)';pl = 'Inne rozchody';es_ES = 'Otros gastos';es_CO = 'Otros gastos';tr = 'Diğer masraflar';it = 'Altre spese';de = 'Sonstige Ausgaben'", MainLanguageCode);
					
				EndIf;
				
			ElsIf SelectionDetailRecords.RetailTransferEarningAccounting Then
				
				// Movements on the register POSSummary.
				Record = RecordSetPOSSummary.Add();
				Record.Period               = SelectionDetailRecords.Period;
				Record.RecordType           = AccumulationRecordType.Receipt;
				Record.Company              = SelectionDetailRecords.Company;
				Record.PresentationCurrency = SelectionDetailRecords.PresentationCurrency;
				Record.StructuralUnit       = SelectionDetailRecords.StructuralUnitCorr;
				Record.Currency             = SelectionDetailRecords.RetailPriceCurrency;
				Record.Cost                 = SelectionDetailRecords.Amount * Denominator;
				Record.ContentOfAccountingRecord = NStr("en = 'Move to retail'; ru = 'Перемещение в розницу';pl = 'Przeniesienie do sprzedaży detalicznej';es_ES = 'Mover a la venta al por menor';es_CO = 'Mover a la venta al por menor';tr = 'Perakendeye geç';it = 'Spostare alla vendita al dettaglio';de = 'In den Einzelhandel wechseln'", MainLanguageCode);
				
				// Movements by register AccountingJournalEntries.
				If UseDefaultTypeOfAccounting Then
					
					Record = RecordSetAccountingJournalEntries.Add();
					Record.Period         = SelectionDetailRecords.Period;
					Record.Company        = SelectionDetailRecords.Company;
					Record.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					Record.AccountDr      = SelectionDetailRecords.CorrGLAccount;
					Record.AccountCr      = SelectionDetailRecords.GLAccount;
					Record.Amount         = SelectionDetailRecords.Amount * Denominator;
					Record.Content        = NStr("en = 'Move to retail'; ru = 'Перемещение в розницу';pl = 'Przeniesienie do sprzedaży detalicznej';es_ES = 'Mover a la venta al por menor';es_CO = 'Mover a la venta al por menor';tr = 'Perakendeye geç';it = 'Spostare alla vendita al dettaglio';de = 'In den Einzelhandel wechseln'", MainLanguageCode);
					
				EndIf;
				
			ElsIf TypeOf(Selection.Ref) = Type("DocumentRef.WorkOrder")
				AND StructureAdditionalProperties.AccountingPolicy.PostExpensesByWorkOrder
				AND ValueIsFilled(SelectionDetailRecords.InventoryAccountType)
				AND ValueIsFilled(SelectionDetailRecords.CorrInventoryAccountType)
				AND SelectionDetailRecords.InventoryAccountType <> SelectionDetailRecords.CorrInventoryAccountType Then
				
				Content = NStr("en = 'Inventory consumption'; ru = 'Материалы';pl = 'Zużycie zapasów';es_ES = 'Consumación del inventario';es_CO = 'Consumación del inventario';tr = 'Stok tüketimi';it = 'Consumo di scorte';de = 'Bestandsverbrauch'", MainLanguageCode);
				
				// Movements on the register Income and expenses.
				Record = RecordSetIncomeAndExpenses.Add();
				Record.Period						= SelectionDetailRecords.Period;
				Record.Company						= SelectionDetailRecords.Company;
				Record.PresentationCurrency			= SelectionDetailRecords.PresentationCurrency;
				Record.StructuralUnit				= SelectionDetailRecords.Department;
				Record.IncomeAndExpenseItem			= SelectionDetailRecords.CorrIncomeAndExpenseItem;
				Record.GLAccount					= SelectionDetailRecords.CorrGLAccount;
				Record.AmountExpense				= SelectionDetailRecords.Amount * Denominator;
				Record.BusinessLine					= SelectionDetailRecords.BusinessLine;
				Record.SalesOrder					= SelectionDetailRecords.SalesOrder;
				Record.ContentOfAccountingRecord	= Content;
				
				If NOT ValueIsFilled(Record.SalesOrder) Then
					Record.SalesOrder = Undefined;
				EndIf;
				
				// Movements by register AccountingJournalEntries.
				If UseDefaultTypeOfAccounting Then
					
					Record = RecordSetAccountingJournalEntries.Add();
					Record.Period			= SelectionDetailRecords.Period;
					Record.Company			= SelectionDetailRecords.Company;
					Record.PlanningPeriod	= Catalogs.PlanningPeriods.Actual;
					Record.AccountDr		= SelectionDetailRecords.CorrGLAccount;
					Record.AccountCr		= SelectionDetailRecords.GLAccount;
					Record.Amount			= SelectionDetailRecords.Amount * Denominator;
					Record.Content			= Content;
					
				EndIf;
				
			ElsIf SelectionDetailRecords.CorrIncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.OtherExpenses
					Or SelectionDetailRecords.CorrIncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses Then
				
				// Movements on the register Income and expenses.
				Record = RecordSetIncomeAndExpenses.Add();
				Record.Period               = SelectionDetailRecords.Period;
				Record.Company              = SelectionDetailRecords.Company;
				Record.PresentationCurrency = SelectionDetailRecords.PresentationCurrency;
				Record.StructuralUnit       = SelectionDetailRecords.StructuralUnitPayee;
				Record.IncomeAndExpenseItem = SelectionDetailRecords.CorrIncomeAndExpenseItem;
				Record.GLAccount            = SelectionDetailRecords.CorrGLAccount;
				Record.AmountExpense        = SelectionDetailRecords.Amount * Denominator;
				
				If TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.InventoryTransfer")
					AND SelectionDetailRecords.CorrIncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses Then
					Record.BusinessLine = SelectionDetailRecords.ActivityDirectionWriteOff;
					Record.SalesOrder = SelectionDetailRecords.SalesOrder;
				Else
					Record.BusinessLine = Catalogs.LinesOfBusiness.Other;
				EndIf;
				Record.ContentOfAccountingRecord = NStr("en = 'Other expenses'; ru = 'Прочие затраты (расходы)';pl = 'Inne rozchody';es_ES = 'Otros gastos';es_CO = 'Otros gastos';tr = 'Diğer masraflar';it = 'Altre spese';de = 'Sonstige Ausgaben'", MainLanguageCode);
				
				// Movements by register AccountingJournalEntries.
				If UseDefaultTypeOfAccounting Then
					
					Record = RecordSetAccountingJournalEntries.Add();
					Record.Period         = SelectionDetailRecords.Period;
					Record.Company        = SelectionDetailRecords.Company;
					Record.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					Record.AccountDr      = SelectionDetailRecords.CorrGLAccount;
					Record.AccountCr      = SelectionDetailRecords.GLAccount;
					Record.Amount         = SelectionDetailRecords.Amount * Denominator;
					Record.Content = NStr("en = 'Other expenses'; ru = 'Прочие затраты (расходы)';pl = 'Inne rozchody';es_ES = 'Otros gastos';es_CO = 'Otros gastos';tr = 'Diğer masraflar';it = 'Altre spese';de = 'Sonstige Ausgaben'", MainLanguageCode);
					
				EndIf;
				
			ElsIf TypeOf(SelectionDetailRecords.Ref) = Type("DocumentRef.DebitNote") Then
				
				// Movements on the register Income and expenses.
				Record = RecordSetIncomeAndExpenses.Add();
				Record.Period               = SelectionDetailRecords.Period;
				Record.Company              = SelectionDetailRecords.Company;
				Record.PresentationCurrency = SelectionDetailRecords.PresentationCurrency;
				Record.StructuralUnit       = SelectionDetailRecords.Department;
				Record.BusinessLine         = SelectionDetailRecords.BusinessLine;
				Record.IncomeAndExpenseItem = SelectionDetailRecords.CorrIncomeAndExpenseItem;
				Record.GLAccount            = SelectionDetailRecords.CorrGLAccount;
				Record.AmountExpense        = SelectionDetailRecords.Amount * Denominator;
				Record.ContentOfAccountingRecord = NStr("en = 'Purchase return'; ru = 'Сторнирование поставки';pl = 'Zwrot zakupu';es_ES = 'Devolución de la compra';es_CO = 'Devolución de la compra';tr = 'Satın alma iadesi';it = 'Reso dell''acquisto';de = 'Kaufrückgabe'", MainLanguageCode);
				
			// begin Drive.FullVersion
			ElsIf (TypeOf(SelectionDetailRecords.Ref) = Type("DocumentRef.Manufacturing")
				Or TypeOf(SelectionDetailRecords.Ref) = Type("DocumentRef.ManufacturingOperation")
				Or TypeOf(SelectionDetailRecords.Ref) = Type("DocumentRef.MonthEndClosing"))
				And SelectionDetailRecords.InventoryAccountType = Enums.InventoryAccountTypes.WorkInProgress Then
				
				// Movements on the register Work-in-progress.
				Record = RecordSetWorkInProgress.Add();
				FillPropertyValues(Record, SelectionDetailRecords);
				
				If UseDefaultTypeOfAccounting
					And ValueIsFilled(SelectionDetailRecords.GLAccount)
					And ValueIsFilled(SelectionDetailRecords.CorrGLAccount)
					And SelectionDetailRecords.GLAccount <> SelectionDetailRecords.CorrGLAccount Then
					
					// Movements by register AccountingJournalEntries.
					Record = RecordSetAccountingJournalEntries.Add();
					Record.Period         = SelectionDetailRecords.Period;
					Record.Company        = SelectionDetailRecords.Company;
					Record.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					
					If SelectionDetailRecords.RecordType = AccumulationRecordType.Expense Then
						Record.AccountDr      = SelectionDetailRecords.CorrGLAccount;
						Record.AccountCr      = SelectionDetailRecords.GLAccount;
					Else
						Record.AccountDr      = SelectionDetailRecords.GLAccount;
						Record.AccountCr      = SelectionDetailRecords.CorrGLAccount;
					EndIf;
					
					Record.Amount         = SelectionDetailRecords.Amount * Denominator;
					Record.Content = NStr("en = 'Inventory write-off'; ru = 'Списание запасов';pl = 'Rozchód zapasów';es_ES = 'Amortización del inventario';es_CO = 'Amortización del inventario';tr = 'Stok azaltma';it = 'Cancellazione di scorte';de = 'Bestandsabschreibung'", MainLanguageCode);
						
				EndIf;
				
			// end Drive.FullVersion
			ElsIf (TypeOf(SelectionDetailRecords.Ref) = Type("DocumentRef.SubcontractorInvoiceReceived")
				And SelectionDetailRecords.InventoryAccountType = Enums.InventoryAccountTypes.ComponentsForSubcontractor) Then
				
				// Movements on the register Cost of goods produced by the subcontractor.
				Record = RecordSetCostOfSubcontractorGoods.Add();
				FillPropertyValues(Record, SelectionDetailRecords);
				Record.FinishedProducts = SelectionDetailRecords.ProductsCorr;
				Record.FinishedProductsCharacteristic = SelectionDetailRecords.CharacteristicCorr;
				
				If UseDefaultTypeOfAccounting
					And ValueIsFilled(SelectionDetailRecords.GLAccount)
					And ValueIsFilled(SelectionDetailRecords.CorrGLAccount)
					And SelectionDetailRecords.GLAccount <> SelectionDetailRecords.CorrGLAccount Then
					
					// Movements by register AccountingJournalEntries.
					Record = RecordSetAccountingJournalEntries.Add();
					Record.Period         = SelectionDetailRecords.Period;
					Record.Company        = SelectionDetailRecords.Company;
					Record.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					Record.AccountDr      = SelectionDetailRecords.CorrGLAccount;
					Record.AccountCr      = SelectionDetailRecords.GLAccount;
					Record.Amount         = SelectionDetailRecords.Amount * Denominator;
					Record.Content        = NStr("en = 'Inventory write-off'; ru = 'Списание запасов';pl = 'Rozchód zapasów';es_ES = 'Amortización del inventario';es_CO = 'Amortización del inventario';tr = 'Stok azaltma';it = 'Cancellazione di scorte';de = 'Bestandsabschreibung'", MainLanguageCode);
						
				EndIf;
				
			Else
				
				If UseDefaultTypeOfAccounting
					And ValueIsFilled(SelectionDetailRecords.GLAccount)
					And ValueIsFilled(SelectionDetailRecords.CorrGLAccount)
					And SelectionDetailRecords.GLAccount <> SelectionDetailRecords.CorrGLAccount Then
					
					// Movements by register AccountingJournalEntries.
					Record = RecordSetAccountingJournalEntries.Add();
					Record.Period         = SelectionDetailRecords.Period;
					Record.Company        = SelectionDetailRecords.Company;
					Record.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					
					If SelectionDetailRecords.RecordType = AccumulationRecordType.Expense Then
						Record.AccountDr      = SelectionDetailRecords.CorrGLAccount;
						Record.AccountCr      = SelectionDetailRecords.GLAccount;
					Else
						Record.AccountDr      = SelectionDetailRecords.GLAccount;
						Record.AccountCr      = SelectionDetailRecords.CorrGLAccount;
					EndIf;
					
					Record.Amount         = SelectionDetailRecords.Amount * Denominator;
					Record.Content        = NStr("en = 'Inventory write-off'; ru = 'Списание запасов';pl = 'Rozchód zapasów';es_ES = 'Amortización del inventario';es_CO = 'Amortización del inventario';tr = 'Stok azaltma';it = 'Cancellazione di scorte';de = 'Bestandsabschreibung'", MainLanguageCode);
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		WriteInventoryRegister(Selection.Ref,RecordSetInventory, StructureAdditionalProperties.ForPosting);
		WriteSalesRegister(Selection.Ref, RecordSetSales, StructureAdditionalProperties.ForPosting);
		WriteIncomeAndExpensesRegister(Selection.Ref, RecordSetIncomeAndExpenses, StructureAdditionalProperties.ForPosting);
		WriteAccountingJournalEntriesRegister(Selection.Ref, RecordSetAccountingJournalEntries, StructureAdditionalProperties.ForPosting);
		WritePOSSummaryRegister(Selection.Ref, RecordSetPOSSummary, StructureAdditionalProperties.ForPosting);
		// begin Drive.FullVersion
		WriteWorkInProgressRegister(Selection.Ref, RecordSetWorkInProgress, StructureAdditionalProperties.ForPosting);
		// end Drive.FullVersion
		WritetCostOfSubcontractorGoods(Selection.Ref, RecordSetCostOfSubcontractorGoods, StructureAdditionalProperties.ForPosting);
		
	EndDo;
	
EndProcedure

Procedure GeneratTableDistributeAmountsWithoutQuantity(Ref, StructureAdditionalProperties);
	
	TemporaryConvertTable(StructureAdditionalProperties.TableForRegisterRecords.TableInventory, "TableInventory", StructureAdditionalProperties);
	
	TemporaryConvertTable(Undefined, "GroupInventoryTable", StructureAdditionalProperties);
	TemporaryConvertTable(Undefined, "TableBalance", StructureAdditionalProperties);
	TemporaryConvertTable(Undefined, "TableAccountingCostBalance", StructureAdditionalProperties);
	TemporaryConvertTable(Undefined, "TTGroupInventoryTable", StructureAdditionalProperties);
	TemporaryConvertTable(Undefined, "TableInventoryBalance", StructureAdditionalProperties);
	TemporaryConvertTable(Undefined, "TableAccountingCostBalanceCorr", StructureAdditionalProperties);
	TemporaryConvertTable(Undefined, "CostAccountingExpenseRecordsRegister", StructureAdditionalProperties);
	TemporaryConvertTable(Undefined, "TTCostAccounting", StructureAdditionalProperties);

	Query = New Query();
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	
	"SELECT
	|	InventoryBalance.Company AS Company,
	|	InventoryBalance.PresentationCurrency AS PresentationCurrency,
	|	InventoryBalance.StructuralUnit AS StructuralUnit,
	|	InventoryBalance.InventoryAccountType AS InventoryAccountType,
	|	InventoryBalance.Products AS Products,
	|	InventoryBalance.Characteristic AS Characteristic,
	|	InventoryBalance.Batch AS Batch,
	|	InventoryBalance.Ownership AS Ownership,
	|	InventoryBalance.CostObject AS CostObject,
	|	SUM(CASE
	|			WHEN InventoryBalance.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN InventoryBalance.Quantity
	|			ELSE -InventoryBalance.Quantity
	|		END) AS QuantityBalance,
	|	SUM(CASE
	|			WHEN InventoryBalance.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN InventoryBalance.Amount
	|			ELSE -InventoryBalance.Amount
	|		END) AS AmountBalance
	|INTO GroupInventoryTable
	|FROM
	|	TableInventory AS InventoryBalance
	|
	|GROUP BY
	|	InventoryBalance.CostObject,
	|	InventoryBalance.Company,
	|	InventoryBalance.PresentationCurrency,
	|	InventoryBalance.Products,
	|	InventoryBalance.Characteristic,
	|	InventoryBalance.InventoryAccountType,
	|	InventoryBalance.StructuralUnit,
	|	InventoryBalance.Batch,
	|	InventoryBalance.Ownership
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	InventoryBalance.Company AS Company,
	|	InventoryBalance.PresentationCurrency AS PresentationCurrency,
	|	InventoryBalance.StructuralUnit AS StructuralUnit,
	|	InventoryBalance.InventoryAccountType AS InventoryAccountType,
	|	InventoryBalance.Products AS Products,
	|	InventoryBalance.Characteristic AS Characteristic,
	|	InventoryBalance.Batch AS Batch,
	|	InventoryBalance.Ownership AS Ownership,
	|	InventoryBalance.CostObject AS CostObject,
	|	InventoryBalance.QuantityBalance AS QuantityBalance,
	|	InventoryBalance.AmountBalance AS AmountBalance
	|INTO TableBalance
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			,
	|			Company = &Company
	|				AND PresentationCurrency = &PresentationCurrency) AS InventoryBalance
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	GroupInventoryTable.Company,
	|	GroupInventoryTable.PresentationCurrency,
	|	GroupInventoryTable.StructuralUnit,
	|	GroupInventoryTable.InventoryAccountType,
	|	GroupInventoryTable.Products,
	|	GroupInventoryTable.Characteristic,
	|	GroupInventoryTable.Batch,
	|	GroupInventoryTable.Ownership,
	|	GroupInventoryTable.CostObject,
	|	GroupInventoryTable.QuantityBalance,
	|	GroupInventoryTable.AmountBalance
	|FROM
	|	GroupInventoryTable AS GroupInventoryTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableBalance.Company AS Company,
	|	TableBalance.PresentationCurrency AS PresentationCurrency,
	|	TableBalance.StructuralUnit AS StructuralUnit,
	|	TableBalance.InventoryAccountType AS InventoryAccountType,
	|	TableBalance.Products AS Products,
	|	TableBalance.Characteristic AS Characteristic,
	|	TableBalance.Batch AS Batch,
	|	TableBalance.Ownership AS Ownership,
	|	TableBalance.CostObject AS CostObject,
	|	SUM(TableBalance.QuantityBalance) AS QuantityBalance,
	|	SUM(TableBalance.AmountBalance) AS AmountBalance
	|INTO TableAccountingCostBalance
	|FROM
	|	TableBalance AS TableBalance
	|
	|GROUP BY
	|	TableBalance.PresentationCurrency,
	|	TableBalance.Batch,
	|	TableBalance.Company,
	|	TableBalance.Products,
	|	TableBalance.Characteristic,
	|	TableBalance.Ownership,
	|	TableBalance.StructuralUnit,
	|	TableBalance.CostObject,
	|	TableBalance.InventoryAccountType";	
	
	Query.SetParameter("BoundaryDateEnd", EndOfMonth(Ref.Date));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalance.Company AS Company,
	|	InventoryBalance.PresentationCurrency AS PresentationCurrency,
	|	InventoryBalance.StructuralUnit AS StructuralUnit,
	|	InventoryBalance.InventoryAccountType AS InventoryAccountType,
	|	InventoryBalance.Products AS Products,
	|	InventoryBalance.Characteristic AS Characteristic,
	|	InventoryBalance.Batch AS Batch,
	|	InventoryBalance.Ownership AS Ownership,
	|	InventoryBalance.CostObject AS CostObject,
	|	SUM(CASE
	|			WHEN InventoryBalance.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN InventoryBalance.Quantity
	|			ELSE -InventoryBalance.Quantity
	|		END) AS QuantityBalance,
	|	SUM(CASE
	|			WHEN InventoryBalance.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN InventoryBalance.Amount
	|			ELSE -InventoryBalance.Amount
	|		END) AS AmountBalance
	|INTO TTGroupInventoryTable
	|FROM
	|	TableInventory AS InventoryBalance
	|
	|GROUP BY
	|	InventoryBalance.Products,
	|	InventoryBalance.Company,
	|	InventoryBalance.Batch,
	|	InventoryBalance.Ownership,
	|	InventoryBalance.CostObject,
	|	InventoryBalance.InventoryAccountType,
	|	InventoryBalance.Characteristic,
	|	InventoryBalance.PresentationCurrency,
	|	InventoryBalance.StructuralUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	InventoryBalance.Company AS Company,
	|	InventoryBalance.PresentationCurrency AS PresentationCurrency,
	|	InventoryBalance.StructuralUnit AS StructuralUnit,
	|	InventoryBalance.InventoryAccountType AS InventoryAccountType,
	|	InventoryBalance.Products AS Products,
	|	InventoryBalance.Characteristic AS Characteristic,
	|	InventoryBalance.Batch AS Batch,
	|	InventoryBalance.Ownership AS Ownership,
	|	InventoryBalance.CostObject AS CostObject,
	|	InventoryBalance.QuantityBalance AS QuantityBalance,
	|	InventoryBalance.AmountBalance AS AmountBalance
	|INTO TableInventoryBalance
	|FROM
	|	AccumulationRegister.Inventory.Balance(&BoundaryDateEnd, ) AS InventoryBalance
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	GroupInventoryTable.Company,
	|	GroupInventoryTable.PresentationCurrency,
	|	GroupInventoryTable.StructuralUnit,
	|	GroupInventoryTable.InventoryAccountType,
	|	GroupInventoryTable.Products,
	|	GroupInventoryTable.Characteristic,
	|	GroupInventoryTable.Batch,
	|	GroupInventoryTable.Ownership,
	|	GroupInventoryTable.CostObject,
	|	GroupInventoryTable.QuantityBalance,
	|	GroupInventoryTable.AmountBalance
	|FROM
	|	TTGroupInventoryTable AS GroupInventoryTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableBalance.Company AS Company,
	|	TableBalance.PresentationCurrency AS PresentationCurrency,
	|	TableBalance.StructuralUnit AS StructuralUnit,
	|	TableBalance.InventoryAccountType AS InventoryAccountType,
	|	TableBalance.Products AS Products,
	|	TableBalance.Characteristic AS Characteristic,
	|	TableBalance.Batch AS Batch,
	|	TableBalance.Ownership AS Ownership,
	|	TableBalance.CostObject AS CostObject,
	|	SUM(TableBalance.QuantityBalance) AS QuantityBalance,
	|	SUM(TableBalance.AmountBalance) AS AmountBalance
	|INTO TableAccountingCostBalanceCorr
	|FROM
	|	TableInventoryBalance AS TableBalance
	|
	|GROUP BY
	|	TableBalance.Company,
	|	TableBalance.InventoryAccountType,
	|	TableBalance.Products,
	|	TableBalance.Characteristic,
	|	TableBalance.PresentationCurrency,
	|	TableBalance.StructuralUnit,
	|	TableBalance.Batch,
	|	TableBalance.CostObject,
	|	TableBalance.Ownership";
	
	
	Query.Execute();
	
	// Movements table is being prepared.
	Query.Text =
	"SELECT ALLOWED
	|	CostAccounting.Company AS Company,
	|	CostAccounting.PresentationCurrency AS PresentationCurrency,
	|	CostAccounting.StructuralUnit AS StructuralUnit,
	|	CostAccounting.InventoryAccountType AS InventoryAccountType,
	|	CostAccounting.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	CostAccounting.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	CostAccounting.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	CostAccounting.IncomeAndExpenseItem.IncomeAndExpenseType AS IncomeAndExpenseType,
	|	CostAccounting.CorrIncomeAndExpenseItem.IncomeAndExpenseType AS CorrIncomeAndExpenseType,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CostAccounting.Products AS Products,
	|	CostAccounting.Characteristic AS Characteristic,
	|	CostAccounting.Batch AS Batch,
	|	CostAccounting.Ownership AS Ownership,
	|	CostAccounting.SalesOrder AS SalesOrder,
	|	CostAccounting.StructuralUnitCorr AS StructuralUnitCorr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	CostAccounting.ProductsCorr AS ProductsCorr,
	|	CostAccounting.CharacteristicCorr AS CharacteristicCorr,
	|	CostAccounting.BatchCorr AS BatchCorr,
	|	CostAccounting.OwnershipCorr AS OwnershipCorr,
	|	CostAccounting.SourceDocument AS SourceDocument,
	|	CostAccounting.Department AS Department,
	|	CostAccounting.Responsible AS Responsible,
	|	CostAccounting.VATRate AS VATRate,
	|	CostAccounting.ProductionExpenses AS ProductionExpenses,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|				AND VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.BusinessLine
	|		ELSE UNDEFINED
	|	END AS ActivityDirectionWriteOff,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|		ELSE CostAccounting.SourceDocument.StructuralUnit
	|	END AS StructuralUnitPayee,
	|	CASE
	|		WHEN CostAccounting.RetailTransferEarningAccounting
	|			THEN CASE
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.SupplierInvoice)
	|						THEN CostAccounting.SourceDocument.StructuralUnit
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|						THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END AS RetailStructuralUnit,
	|	CostAccounting.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	CostAccounting.Products.ProductsCategory AS ProductsProductsCategory,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.Products.BusinessLine
	|		ELSE VALUE(Catalog.LinesOfBusiness.MainLine)
	|	END AS BusinessLineSales,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.Products.BusinessLine.GLAccountCostOfSales
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS BusinessLineSalesGLAccountOfSalesCost,
	|	SUM(CASE
	|			WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|						AND NOT CostAccounting.Return
	|					OR CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						AND CostAccounting.Return
	|				THEN CostAccounting.Amount
	|			ELSE 0
	|		END) AS Amount,
	|	CostAccounting.Counterparty AS Counterparty,
	|	CostAccounting.Currency AS Currency,
	|	CostAccounting.CostObject AS CostObject,
	|	CostAccounting.CostObjectCorr AS CostObjectCorr
	|INTO TTCostAccounting
	|FROM
	|	AccumulationRegister.Inventory AS CostAccounting
	|WHERE
	|	CostAccounting.Period BETWEEN &DateBeg AND &DateEnd
	|	AND CostAccounting.Company = &Company
	|	AND CostAccounting.PresentationCurrency = &PresentationCurrency
	|	AND NOT CostAccounting.FixedCost
	|
	|GROUP BY
	|	CostAccounting.Company,
	|	CostAccounting.PresentationCurrency,
	|	CostAccounting.StructuralUnit,
	|	CostAccounting.InventoryAccountType,
	|	CostAccounting.CorrInventoryAccountType,
	|	CostAccounting.IncomeAndExpenseItem,
	|	CostAccounting.CorrIncomeAndExpenseItem,
	|	CostAccounting.IncomeAndExpenseItem.IncomeAndExpenseType,
	|	CostAccounting.CorrIncomeAndExpenseItem.IncomeAndExpenseType,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CostAccounting.Products,
	|	CostAccounting.Characteristic,
	|	CostAccounting.Batch,
	|	CostAccounting.Ownership,
	|	CostAccounting.SalesOrder,
	|	CostAccounting.StructuralUnitCorr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CostAccounting.ProductsCorr,
	|	CostAccounting.CharacteristicCorr,
	|	CostAccounting.BatchCorr,
	|	CostAccounting.OwnershipCorr,
	|	CostAccounting.SourceDocument,
	|	CostAccounting.Department,
	|	CostAccounting.Responsible,
	|	CostAccounting.VATRate,
	|	CostAccounting.ProductionExpenses,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|				AND VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.BusinessLine
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|		ELSE CostAccounting.SourceDocument.StructuralUnit
	|	END,
	|	CASE
	|		WHEN CostAccounting.RetailTransferEarningAccounting
	|			THEN CASE
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.SupplierInvoice)
	|						THEN CostAccounting.SourceDocument.StructuralUnit
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|						THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END,
	|	CostAccounting.RetailTransferEarningAccounting,
	|	CostAccounting.Products.ProductsCategory,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.Products.BusinessLine
	|		ELSE VALUE(Catalog.LinesOfBusiness.MainLine)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.Products.BusinessLine.GLAccountCostOfSales
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CostAccounting.Counterparty,
	|	CostAccounting.Currency,
	|	CostAccounting.CostObject,
	|	CostAccounting.CostObjectCorr
	|
	|UNION ALL
	|
	|SELECT
	|	CostAccounting.Company,
	|	CostAccounting.PresentationCurrency,
	|	CostAccounting.StructuralUnit,
	|	CostAccounting.InventoryAccountType,
	|	CostAccounting.CorrInventoryAccountType,
	|	CostAccounting.IncomeAndExpenseItem,
	|	CostAccounting.CorrIncomeAndExpenseItem,
	|	CostAccounting.IncomeAndExpenseItem.IncomeAndExpenseType,
	|	CostAccounting.CorrIncomeAndExpenseItem.IncomeAndExpenseType,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CostAccounting.Products,
	|	CostAccounting.Characteristic,
	|	CostAccounting.Batch,
	|	CostAccounting.Ownership,
	|	CostAccounting.SalesOrder,
	|	CostAccounting.StructuralUnitCorr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CostAccounting.ProductsCorr,
	|	CostAccounting.CharacteristicCorr,
	|	CostAccounting.BatchCorr,
	|	CostAccounting.OwnershipCorr,
	|	CostAccounting.SourceDocument,
	|	CostAccounting.Department,
	|	CostAccounting.Responsible,
	|	CostAccounting.VATRate,
	|	CostAccounting.ProductionExpenses,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|				AND VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.BusinessLine
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|		ELSE CostAccounting.SourceDocument.StructuralUnit
	|	END,
	|	CASE
	|		WHEN CostAccounting.RetailTransferEarningAccounting
	|			THEN CASE
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.SupplierInvoice)
	|						THEN CostAccounting.SourceDocument.StructuralUnit
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|						THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END,
	|	CostAccounting.RetailTransferEarningAccounting,
	|	CostAccounting.Products.ProductsCategory,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.Products.BusinessLine
	|		ELSE VALUE(Catalog.LinesOfBusiness.MainLine)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.Products.BusinessLine.GLAccountCostOfSales
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	SUM(CASE
	|			WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|						AND NOT CostAccounting.Return
	|					OR CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						AND CostAccounting.Return
	|				THEN CostAccounting.Amount
	|			ELSE 0
	|		END),
	|	CostAccounting.Counterparty,
	|	CostAccounting.Currency,
	|	CostAccounting.CostObject,
	|	CostAccounting.CostObjectCorr
	|FROM
	|	TableInventory AS CostAccounting
	|WHERE
	|	CostAccounting.Period BETWEEN &DateBeg AND &DateEnd
	|	AND CostAccounting.Company = &Company
	|	AND CostAccounting.PresentationCurrency = &PresentationCurrency
	|	AND NOT CostAccounting.FixedCost
	|
	|GROUP BY
	|	CostAccounting.Company,
	|	CostAccounting.PresentationCurrency,
	|	CostAccounting.StructuralUnit,
	|	CostAccounting.InventoryAccountType,
	|	CostAccounting.CorrInventoryAccountType,
	|	CostAccounting.IncomeAndExpenseItem,
	|	CostAccounting.CorrIncomeAndExpenseItem,
	|	CostAccounting.IncomeAndExpenseItem.IncomeAndExpenseType,
	|	CostAccounting.CorrIncomeAndExpenseItem.IncomeAndExpenseType,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CostAccounting.Products,
	|	CostAccounting.Characteristic,
	|	CostAccounting.Batch,
	|	CostAccounting.Ownership,
	|	CostAccounting.SalesOrder,
	|	CostAccounting.StructuralUnitCorr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CostAccounting.ProductsCorr,
	|	CostAccounting.CharacteristicCorr,
	|	CostAccounting.BatchCorr,
	|	CostAccounting.OwnershipCorr,
	|	CostAccounting.SourceDocument,
	|	CostAccounting.Department,
	|	CostAccounting.Responsible,
	|	CostAccounting.VATRate,
	|	CostAccounting.ProductionExpenses,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|				AND VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.BusinessLine
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|		ELSE CostAccounting.SourceDocument.StructuralUnit
	|	END,
	|	CASE
	|		WHEN CostAccounting.RetailTransferEarningAccounting
	|			THEN CASE
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.SupplierInvoice)
	|						THEN CostAccounting.SourceDocument.StructuralUnit
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|						THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END,
	|	CostAccounting.RetailTransferEarningAccounting,
	|	CostAccounting.Products.ProductsCategory,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.Products.BusinessLine
	|		ELSE VALUE(Catalog.LinesOfBusiness.MainLine)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CostAccounting.Products.BusinessLine.GLAccountCostOfSales
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CostAccounting.Counterparty,
	|	CostAccounting.Currency,
	|	CostAccounting.CostObject,
	|	CostAccounting.CostObjectCorr
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	StructuralUnit,
	|	GLAccount,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	Ownership,
	|	SalesOrder,
	|	StructuralUnitCorr,
	|	CorrGLAccount,
	|	ProductsCorr,
	|	CharacteristicCorr,
	|	BatchCorr
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TTCostAccounting.Company AS Company,
	|	TTCostAccounting.PresentationCurrency AS PresentationCurrency,
	|	TTCostAccounting.StructuralUnit AS StructuralUnit,
	|	TTCostAccounting.InventoryAccountType AS InventoryAccountType,
	|	TTCostAccounting.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TTCostAccounting.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	TTCostAccounting.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	TTCostAccounting.IncomeAndExpenseType AS IncomeAndExpenseType,
	|	TTCostAccounting.CorrIncomeAndExpenseType AS CorrIncomeAndExpenseType,
	|	TTCostAccounting.GLAccount AS GLAccount,
	|	TTCostAccounting.Products AS Products,
	|	TTCostAccounting.Characteristic AS Characteristic,
	|	TTCostAccounting.Batch AS Batch,
	|	TTCostAccounting.Ownership AS Ownership,
	|	TTCostAccounting.SalesOrder AS SalesOrder,
	|	TTCostAccounting.StructuralUnitCorr AS StructuralUnitCorr,
	|	TTCostAccounting.CorrGLAccount AS CorrGLAccount,
	|	TTCostAccounting.ProductsCorr AS ProductsCorr,
	|	TTCostAccounting.CharacteristicCorr AS CharacteristicCorr,
	|	TTCostAccounting.BatchCorr AS BatchCorr,
	|	TTCostAccounting.OwnershipCorr AS OwnershipCorr,
	|	TTCostAccounting.SourceDocument AS SourceDocument,
	|	TTCostAccounting.Department AS Department,
	|	TTCostAccounting.Responsible AS Responsible,
	|	TTCostAccounting.VATRate AS VATRate,
	|	TTCostAccounting.ProductionExpenses AS ProductionExpenses,
	|	TTCostAccounting.ActivityDirectionWriteOff AS ActivityDirectionWriteOff,
	|	TTCostAccounting.StructuralUnitPayee AS StructuralUnitPayee,
	|	TTCostAccounting.RetailStructuralUnit AS RetailStructuralUnit,
	|	TTCostAccounting.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	TTCostAccounting.ProductsProductsCategory AS ProductsProductsCategory,
	|	TTCostAccounting.BusinessLineSales AS BusinessLineSales,
	|	TTCostAccounting.BusinessLineSalesGLAccountOfSalesCost AS BusinessLineSalesGLAccountOfSalesCost,
	|	SUM(TTCostAccounting.Amount) AS Amount,
	|	TTCostAccounting.Counterparty AS Counterparty,
	|	TTCostAccounting.Currency AS Currency,
	|	TTCostAccounting.CostObject AS CostObject,
	|	TTCostAccounting.CostObjectCorr AS CostObjectCorr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN VALUETYPE(TTCostAccounting.SourceDocument) = TYPE(Document.InventoryWriteOff)
	|			THEN TTCostAccounting.SourceDocument.Correspondence
	|		WHEN VALUETYPE(TTCostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN TT_InventoryTransfer.ConsumptionGLAccount
	|		ELSE UNDEFINED
	|	END AS GLAccountWriteOff,
	|	CASE
	|		WHEN VALUETYPE(TTCostAccounting.SourceDocument) = TYPE(Document.InventoryWriteOff)
	|			THEN TTCostAccounting.SourceDocument.ExpenseItem.IncomeAndExpenseType
	|		WHEN VALUETYPE(TTCostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN TT_InventoryTransfer.IncomeAndExpenseType
	|		ELSE UNDEFINED
	|	END AS WriteOffIncomeAndExpenseType
	|INTO CostAccountingExpenseRecordsRegister
	|FROM
	|	TTCostAccounting AS TTCostAccounting
	|		LEFT JOIN TT_InventoryTransfer AS TT_InventoryTransfer
	|		ON TTCostAccounting.Company = TT_InventoryTransfer.Company
	|			AND TTCostAccounting.PresentationCurrency = TT_InventoryTransfer.PresentationCurrency
	|			AND TTCostAccounting.Products = TT_InventoryTransfer.Products
	|			AND TTCostAccounting.Characteristic = TT_InventoryTransfer.Characteristic
	|			AND TTCostAccounting.Batch = TT_InventoryTransfer.Batch
	|			AND TTCostAccounting.Ownership = TT_InventoryTransfer.Ownership
	|			AND TTCostAccounting.StructuralUnit = TT_InventoryTransfer.StructuralUnit
	|			AND TTCostAccounting.CostObject = TT_InventoryTransfer.CostObject
	|			AND TTCostAccounting.InventoryAccountType = TT_InventoryTransfer.InventoryAccountType
	|
	|GROUP BY
	|	TTCostAccounting.GLAccount,
	|	TTCostAccounting.StructuralUnitCorr,
	|	TTCostAccounting.CorrGLAccount,
	|	TTCostAccounting.OwnershipCorr,
	|	TTCostAccounting.Products,
	|	TTCostAccounting.SalesOrder,
	|	TTCostAccounting.Company,
	|	TTCostAccounting.Responsible,
	|	TTCostAccounting.Department,
	|	TTCostAccounting.VATRate,
	|	TTCostAccounting.ProductionExpenses,
	|	TTCostAccounting.CorrIncomeAndExpenseItem,
	|	TTCostAccounting.CorrIncomeAndExpenseType,
	|	TTCostAccounting.Characteristic,
	|	TTCostAccounting.CorrInventoryAccountType,
	|	TTCostAccounting.IncomeAndExpenseItem,
	|	TTCostAccounting.Batch,
	|	TTCostAccounting.Ownership,
	|	TTCostAccounting.ProductsCorr,
	|	TTCostAccounting.CharacteristicCorr,
	|	TTCostAccounting.BatchCorr,
	|	TTCostAccounting.InventoryAccountType,
	|	TTCostAccounting.SourceDocument,
	|	TTCostAccounting.IncomeAndExpenseType,
	|	TTCostAccounting.PresentationCurrency,
	|	TTCostAccounting.StructuralUnit,
	|	TTCostAccounting.Counterparty,
	|	TTCostAccounting.BusinessLineSalesGLAccountOfSalesCost,
	|	TTCostAccounting.StructuralUnitPayee,
	|	TTCostAccounting.RetailTransferEarningAccounting,
	|	TTCostAccounting.ProductsProductsCategory,
	|	TTCostAccounting.BusinessLineSales,
	|	TTCostAccounting.CostObject,
	|	TTCostAccounting.ActivityDirectionWriteOff,
	|	TTCostAccounting.RetailStructuralUnit,
	|	TTCostAccounting.Currency,
	|	TTCostAccounting.CostObjectCorr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN VALUETYPE(TTCostAccounting.SourceDocument) = TYPE(Document.InventoryWriteOff)
	|			THEN TTCostAccounting.SourceDocument.Correspondence
	|		WHEN VALUETYPE(TTCostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN TT_InventoryTransfer.ConsumptionGLAccount
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN VALUETYPE(TTCostAccounting.SourceDocument) = TYPE(Document.InventoryWriteOff)
	|			THEN TTCostAccounting.SourceDocument.ExpenseItem.IncomeAndExpenseType
	|		WHEN VALUETYPE(TTCostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN TT_InventoryTransfer.IncomeAndExpenseType
	|		ELSE UNDEFINED
	|	END
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	StructuralUnit,
	|	GLAccount,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	Ownership,
	|	SalesOrder,
	|	StructuralUnitCorr,
	|	CorrGLAccount,
	|	ProductsCorr,
	|	CharacteristicCorr,
	|	BatchCorr";
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	DateBeg = StructureAdditionalProperties.ForPosting.BeginOfPeriodningDate;
	DateEnd = StructureAdditionalProperties.ForPosting.EndDatePeriod;

	Query.SetParameter("DateBeg", DateBeg);
	Query.SetParameter("DateEnd", DateEnd);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	Query.Execute();
	
EndProcedure

#EndRegion

#Region ToDoList

Function DocumentsCount()
	
	Result = New Structure;
	Result.Insert("MonthClosureNotCalculatedTotals", 0);
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	COUNT(DISTINCT CASE
	|			WHEN VALUETYPE(DocMonthEnd.Ref) <> Type(Document.MonthEndClosing)
	|				THEN InventoryBalances.Company
	|		END) AS MonthClosureNotCalculatedTotals
	|FROM
	|	AccumulationRegister.Inventory.Balance(&EndOfLastSessionOfMonth, ) AS InventoryBalances
	|		LEFT JOIN Document.MonthEndClosing AS DocMonthEnd
	|		ON InventoryBalances.Company = DocMonthEnd.Company
	|			AND (DocMonthEnd.Posted)
	|			AND (BEGINOFPERIOD(&EndOfLastSessionOfMonth, MONTH) = BEGINOFPERIOD(DocMonthEnd.Date, MONTH))";
	
	Query.SetParameter("EndOfLastSessionOfMonth",	BegOfMonth(CurrentSessionDate()) - 1);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		FillPropertyValues(Result, SelectionDetailRecords);
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region Errors

Procedure AddErrorIntoTable(Ref, ErrorDescription, OperationKind, ErrorsTable, Analytics = Undefined)
	
	If Analytics = Undefined Then
		Analytics = Documents.SalesOrder.EmptyRef()
	EndIf;
	
	NewRow = ErrorsTable.Add();
	NewRow.Period 			= Ref.Date;
	NewRow.Company 			= Ref.Company;
	NewRow.OperationKind 	= OperationKind;
	NewRow.Analytics 		= Analytics;
	NewRow.ErrorDescription = ErrorDescription;
	NewRow.Recorder 		= Ref;
	NewRow.Active 			= True;
	
EndProcedure

Function GenerateErrorDescriptionCostAllocation(Ref, InventoryAccountType, MethodOfDistribution, Amount)
	
	AmountText = String(Amount) + " " + TrimAll(String(DriveServer.GetPresentationCurrency(Ref.Company)));
	
	If MethodOfDistribution = Enums.UnderOverAllocatedOverheadsSettings.AdjustedAllocationRate Then
		Template = NStr("en = 'The ""%1"" cost in the %2 amount allocated for production release by adjusted allocation-rate approach
			|can not be allocated as in the calculated period there was no manufacturing operation reflection.'; 
			|ru = 'Затрата ""%1"" в сумме %2, распределяемая на выпуск продукции по скорректированной норме распределения
			|не может быть распределена, т.к. в расчетном периоде не было отражения производственных операций.';
			|pl = 'Koszt ""%1"" w kwocie %2 przydzielonej na wypuszczenie produkcji według metody skorygowanej stopy alokacji
			| nie może być alokowany, gdyż w rozliczanym okresie nie było odzwierciedlona operacja produkcyjna.';
			|es_ES = 'El coste ""%1"" en la %2cantidad asignada para el lanzamiento de la producción por el enfoque de la tasa de asignación ajustada 
			|no puede ser asignado ya que en el período calculado no hubo reflejo de la operación de fabricación.';
			|es_CO = 'El coste ""%1"" en la %2cantidad asignada para el lanzamiento de la producción por el enfoque de la tasa de asignación ajustada 
			|no puede ser asignado ya que en el período calculado no hubo reflejo de la operación de fabricación.';
			|tr = 'Hesaplanan dönemde üretim işlemi yansıması olmadığından,
			|üretim sürümü için düzeltilmiş tahsis oranı yaklaşımına göre tahsis edilmiş %2 tutarındaki ""%1"" maliyeti tahsis edilemiyor.';
			|it = 'Il costo ""%1"" nell''importo %2 allocato per il rilascio della produzione per approccio del tasso di allocazione rettificato
			|non può essere allocato poiché nel periodo calcolato non c''era alcun riflesso delle operazioni di produzione.';
			|de = 'Die Kosten ""%1"" in der Menge %2 zugeordnet der Produktionsfreigabe nach dem angepassten Zuordnungssatzansatz 
			|können nicht zugeordnet werden, denn im berechneten Zeitraum gab es keine Spiegelung der Herstellungsoperation.'");
	ElsIf MethodOfDistribution = Enums.CostAllocationMethod.ProductionVolume Then
		Template = NStr("en = 'The ""%1"" cost in the %2 amount allocated for production release by release volume
			|can not be allocated as in the calculated period there was no production release.'; 
			|ru = 'Затрата ""%1"" в сумме %2, распределяемая на выпуск продукции по объему выпуска
			|не может быть распределена, т.к. в расчетном периоде не было выпуска продукции.';
			|pl = 'Koszt ""%1"" w kwocie %2 przydzielonej na wypuszczenie produkcji według zmniejszenia woluminu
			| nie może być alokowany, gdyż w rozliczanym okresie nie było wypuszczenia produkcji.';
			|es_ES = 'El coste ""%1"" en la %2cantidad asignada para el lanzamiento de la producción por el volumen 
			|de lanzamiento no puede ser asignado ya que en el período calculado no hubo lanzamiento de la producción.';
			|es_CO = 'El coste ""%1"" en la %2cantidad asignada para el lanzamiento de la producción por el volumen 
			|de lanzamiento no puede ser asignado ya que en el período calculado no hubo lanzamiento de la producción.';
			|tr = 'Hesaplanan dönemde üretim sürümü olmadığından,
			|üretim sürümü için sürüm hacmine göre tahsis edilmiş %2 tutarındaki ""%1"" maliyeti tahsis edilemiyor.';
			|it = 'Il costo ""%1"" nell''importo %2 allocato per il rilascio di produzione per volume di rilascio
			|non può essere allocato poiché nel periodo calcolato non c''era alcun rilascio di produzione.';
			|de = 'Die ""%1"" Kosten in der Menge %2, zugeordnet der Produktionsfreigabe durch Freigabenvolumen 
			|, können nicht zugeordnet werden, denn im berechneten Zeitraum gab es keine Produktionsfreigabe.'");
	Else
		Template = NStr("en = 'The ""%1"" cost in the %2 amount allocated for production release by direct costs
			|can not be allocated as in the calculated period there was no allocation of direct costs%Order% specified in the allocation setting.'; 
			|ru = 'Затрата ""%1"" в сумме %2, распределяемая на выпуск продукции по прямым затратам
			|не может быть распределена, т.к. в расчетном периоде не было распределения прямых затрат%Order%, указанных в настройке распределения.';
			|pl = 'Koszt ""%1"" w kwocie %2 przydzielonej na wypuszczenie produkcji według kosztów bezpośrednich
			|nie może być przydzielony, gdyż w obliczonym okresie nie było alokacji kosztów bezpośrednich %Order%, określonych w ustawieniu alokacji.';
			|es_ES = 'El coste ""%1"" en la %2cantidad asignada para el lanzamiento de la producción por los costes directos 
			|no se puede asignar ya que en el período calculado no había ninguna asignación de los costes directos %Order%especificados en el ajuste de la asignación.';
			|es_CO = 'El coste ""%1"" en la %2cantidad asignada para el lanzamiento de la producción por los costes directos 
			|no se puede asignar ya que en el período calculado no había ninguna asignación de los costes directos %Order%especificados en el ajuste de la asignación.';
			|tr = 'Hesaplanan dönemde, tahsis ayarında belirtilmiş direkt giderlerin%Order% tahsisi olmadığından,
			|üretim sürümü için direkt giderlere göre tahsis edilen %2 tutarındaki ""%1"" maliyeti tahsis edilemiyor.';
			|it = 'Il costo ""%1"" nell''importo %2 allocato per il rilascio della produzione per costi diretti
			|non può essere allocato poiché nel periodo calcolato non c''era alcuna allocazione di costi diretti%Order% specificata nell''impostazione di allocazione.';
			|de = 'Die Kosten ""%1"" in der Menge %2 zugeordnet der Produktionsfreigabe nach direkten Kosten 
			| können nicht zugeordnet werden, denn im berechneten Zeitraum gab es keine Zuordnung von direkten Kosten %Order% angegeben in den Zuordnungseinstellungen.'");
	EndIf;
	
	ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
		Template,
		InventoryAccountType,
		AmountText);
	
	Return ErrorDescription;
	
EndFunction

Function GenerateErrorDescriptionExpensesDistribution(Ref, GLAccount, MethodOfDistribution, Amount)
	
	Template = "";
	
	AmountText = String(Amount) + " " + TrimAll(String(DriveServer.GetPresentationCurrency(Ref.Company)));
	
	If MethodOfDistribution = Enums.CostAllocationMethod.SalesVolume Then
		Template = Template + NStr("en = 'The ""%1"" expense in the %2 amount allocated for a financial result by quantity
			|can not be allocated as in the calculated period there was no quantity.'; 
			|ru = 'Затрата ""%1"" в сумме %2, распределяемая на финансовый результат по количеству
			|не может быть распределена, т.к. в расчетном периоде не было количества.';
			|pl = 'Rozchód ""%1"" w kwocie %2 przydzielonej na wynik finansowy według ilości
			|nie może być przydzielony, ponieważ w obliczonym okresie nie było ilości.';
			|es_ES = 'El gasto ""%1"" en el importe %2 asignado para un resultado financiero por cantidad 
			| no puede asignarse porque en el período calculado no había ninguna cantidad.';
			|es_CO = 'El gasto ""%1"" en el importe %2 asignado para un resultado financiero por cantidad 
			| no puede asignarse porque en el período calculado no había ninguna cantidad.';
			|tr = 'Hesaplanan dönemde miktar olmadığından,
			|finansal sonuç için miktara göre tahsis edilen %2 tutarındaki ""%1"" masrafı tahsis edilemiyor.';
			|it = 'La spesa ""%1"" nell''importo %2 allocato per un risultato finanziario per quantità
			|non può essere allocata poiché nel periodo calcolato non c''era alcuna quantità.';
			|de = 'Der Aufwand ""%1"" in der Menge %2 zugeordnet für ein Finanzergebnis nach Anzahl 
			| kann nicht zugeordnet werden, denn im berechneten Zeitraum gab es keine Anzahl.'");
	ElsIf MethodOfDistribution = Enums.CostAllocationMethod.SalesRevenue Then
		Template = Template + NStr("en = 'The ""%1"" expense in the %2 amount allocated for a financial result by revenue
			|can not be allocated as in the calculated period there was no revenue.'; 
			|ru = 'Затрата ""%1"" в сумме %2, распределяемая на финансовый результат по выручке
			|не может быть распределена, т.к. в расчетном периоде не было выручки.';
			|pl = 'Rozchód ""%1"" w kwocie %2 przydzielonej dla wyniku finansowego według przychodu
			|nie może być przydzielony ponieważ w rozliczanym okresie nie było przychodu.';
			|es_ES = 'El gasto ""%1"" en el importe %2asignado para un resultado financiero por ingresos 
			| no puede asignarse porque en el período calculado no había ningún ingreso.';
			|es_CO = 'El gasto ""%1"" en el importe %2asignado para un resultado financiero por ingresos 
			| no puede asignarse porque en el período calculado no había ningún ingreso.';
			|tr = 'Hesaplanan dönemde gelir olmadığından,
			|finansal sonuç için gelire göre tahsis edilen %2 tutarındaki ""%1"" masrafı tahsis edilemiyor.';
			|it = 'La spesa ""%1"" nell''importo %2 allocato per un risultato finanziario per ricavo
			|non può essere allocata poiché nel periodo calcolato non c''era alcun ricavo.';
			|de = 'Der Aufwand ""%1"" in der Menge %2 zugeordnet für ein Finanzergebnis nach Erlös 
			|kann nicht zugeordnet werden, denn im berechneten Zeitraum gab es keinen Erlös.'");
	ElsIf MethodOfDistribution = Enums.CostAllocationMethod.CostOfGoodsSold Then
		Template = Template + NStr("en = 'The ""%1"" expense in the %2 amount allocated for a financial result by cost of goods sold
			|can not be allocated as in the calculated period there was no cost of goods sold.'; 
			|ru = 'Затрата ""%1"" в сумме %2, распределяемая на финансовый результат по себестоимости продаж
			|не может быть распределена, т.к. в расчетном периоде не было себестоимости продаж.';
			|pl = 'Rozchód ""%1"" w kwocie %2 przydzielonej na wynik finansowy według KWS
			|nie może być przydzielony, ponieważ w obliczonym okresie nie KWS.';
			|es_ES = 'El gasto ""%1"" en el importe %2asignado para un resultado financiero por el coste de las mercancías vendidas
			| no puede asignarse ya que en el período calculado no hubo coste de las mercancías vendidas.';
			|es_CO = 'El gasto ""%1"" en el importe %2asignado para un resultado financiero por el coste de las mercancías vendidas
			| no puede asignarse ya que en el período calculado no hubo coste de las mercancías vendidas.';
			|tr = 'Hesaplanan dönemde satılan malların maliyeti olmadığından,
			|finansal sonuç için satılan malların maliyetine göre tahsis edilen %2 tutarındaki ""%1"" masrafı tahsis edilemiyor.';
			|it = 'La spesa ""%1"" nell''importo %2 allocato per un risultato finanziario per costo del venduto
			|non può essere allocata poiché nel periodo calcolato non c''era alcun costo del venduto.';
			|de = 'Der Aufwand ""%1"" in der Menge %2 zugeordnet für ein Finanzergebnis nach Wareneinsatz 
			| kann nicht zugeordnet werden, denn im berechneten Zeitraum gab es keinen Wareneinsatz.'");
	ElsIf MethodOfDistribution = Enums.CostAllocationMethod.GrossProfit Then
		Template = Template + NStr("en = 'The ""%1"" expense in the %2 amount allocated for a financial result by gross profit
			|can not be allocated as in the calculated period there was no gross profit.'; 
			|ru = 'Затрата ""%1"" в сумме %2, распределяемая на финансовый результат по валовой прибыли
			|не может быть распределена, т.к. в расчетном периоде не было валовой прибыли.';
			|pl = 'Rozchód ""%1"" w kwocie %2 przydzielonej dla wyniku finansowego według zysku brutto
			|nie może być przydzielony ponieważ w rozliczanym okresie nie zysku brutto.';
			|es_ES = 'El gasto ""%1"" en el importe %2asignado para un resultado financiero por el beneficio bruto
			| no puede asignarse ya que en el período calculado no hubo beneficio bruto.';
			|es_CO = 'El gasto ""%1"" en el importe %2asignado para un resultado financiero por el beneficio bruto
			| no puede asignarse ya que en el período calculado no hubo beneficio bruto.';
			|tr = 'Hesaplanan dönemde brüt kar olmadığından,
			|finansal sonuç için brüt kara göre tahsis edilen %2 tutarındaki ""%1"" masrafı tahsis edilemedi.';
			|it = 'La spesa ""%1"" nell''importo %2 allocato per un risultato finanziario per profitto lordo
			|non può essere allocata poiché nel periodo calcolato non c''era alcun profitto lordo.';
			|de = 'Der Aufwand ""%1"" in der Menge %2 zugeordnet für ein Finanzergebnis nach Bruttoertrag 
			|kann nicht zugeordnet werden, denn im berechneten Zeitraum gab es keinen Bruttoertrag.'");
	EndIf;
	
	ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
		Template,
		String(GLAccount),
		AmountText);
	
	Return ErrorDescription;
	
EndFunction

#EndRegion

#Region VerifyTaxInvoices

Procedure VerifyTaxInvoices(Ref, StructureAdditionalProperties, ErrorsTable)
	
	If Not StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		Or StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	SalesInvoice.Ref AS Ref
	|INTO DocumentsTable
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Date BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND SalesInvoice.Company = &Company
	|	AND SalesInvoice.Posted
	|	AND SalesInvoice.VATTaxation <> VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
	|	AND SalesInvoice.OperationKind <> VALUE(Enum.OperationTypesSalesInvoice.ZeroInvoice)
	|
	|UNION ALL
	|
	|SELECT
	|	CreditNote.Ref
	|FROM
	|	Document.CreditNote AS CreditNote
	|WHERE
	|	CreditNote.Date BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND CreditNote.Company = &Company
	|	AND CreditNote.Posted
	|	AND CreditNote.VATTaxation <> VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	DocumentsTable.Ref AS Ref
	|INTO DocumentsWithTaxInvoice
	|FROM
	|	DocumentsTable AS DocumentsTable
	|		INNER JOIN Document.TaxInvoiceIssued.BasisDocuments AS TaxInvoiceBasisDocuments
	|		ON DocumentsTable.Ref = TaxInvoiceBasisDocuments.BasisDocument
	|		INNER JOIN Document.TaxInvoiceIssued AS TaxInvoiceIssued
	|		ON (TaxInvoiceBasisDocuments.Ref = TaxInvoiceIssued.Ref)
	|			AND (TaxInvoiceIssued.Posted)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentsTable.Ref AS Ref,
	|	PRESENTATION(DocumentsTable.Ref) AS RefPresentation
	|FROM
	|	DocumentsTable AS DocumentsTable
	|		LEFT JOIN DocumentsWithTaxInvoice AS DocumentsWithTaxInvoice
	|		ON DocumentsTable.Ref = DocumentsWithTaxInvoice.Ref
	|WHERE
	|	DocumentsWithTaxInvoice.Ref IS NULL";
	
	Query.SetParameter("Company",		Ref.Company);
	Query.SetParameter("BeginOfPeriod",	BegOfMonth(Ref.Date));
	Query.SetParameter("EndOfPeriod",	EndOfMonth(Ref.Date));
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then 
		
		Selection = Result.Select();
		
		While Selection.Next() Do
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The Tax invoice is required for %1.'; ru = 'Для %1 не указан налоговый инвойс.';pl = 'Faktura VAT jest wymagana dla %1.';es_ES = 'La factura de impuestos se requiere para %1.';es_CO = 'La factura de impuestos se requiere para %1.';tr = '%1 için Vergi faturası gerekli.';it = 'È richiesta fattura fiscale per %1.';de = 'Die Steuerrechnung ist für %1 erforderlich.'"),
				Selection.RefPresentation);
			
			AddErrorIntoTable(Ref, ErrorDescription, NStr("en = 'Verify tax invoices'; ru = 'Проверить налоговые инвойсы';pl = 'Weryfikacja faktur VAT';es_ES = 'Verificar las facturas de impuestos';es_CO = 'Verificar las facturas de impuestos';tr = 'Vergi faturalarını doğrula';it = 'Verificare fattura fiscale';de = 'Steuerrechnungen überprüfen'"), ErrorsTable, Selection.Ref);
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region CalculateReleaseActualCost

// Function generates movements on the WriteOffCostCorrectionNodes information register.
//
// Parameters:
//  Cancel        - Boolean - check box of document posting canceling.
//
// Returns:
//  Number - number of a written node.
//
Function MakeRegisterRecordsByRegisterWriteOffCostAdjustment(Ref, StructureAdditionalProperties)
	
	Query = New Query();
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("DateBeg",				StructureAdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd",				StructureAdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("Recorder",				Ref);
	Query.SetParameter("EmptyAccount",			StructureAdditionalProperties.ForPosting.EmptyAccount);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	
	// Receive a new nodes table, each node is defined by the combination of all accounting dimensions.
	// An average price is put to the Amount column according to the corresponding
	// InventoryAndCostAccounting register resource by the external receipt for each node.
	// These columns are the right parts in the linear equations system.
	// The total quantity of receipt to each node is put to the Quantity columns.
	// If  there are no movements on quantity in this node but there are
	// only movements on cost, then the cost is used instead of the quantity
	// (the node corresponds to the non material expenses).
	// If there is a writeoff by the fixed cost from the node, then reduce
	// the quantity and the cost of Earning to this node  on the quantity
	// and the cost by the fixed operation.
	
	Query.Text =
	"SELECT ALLOWED
	|	Receipts.Company AS Company,
	|	Receipts.PresentationCurrency AS PresentationCurrency,
	|	Receipts.StructuralUnit AS StructuralUnit,
	|	Receipts.InventoryAccountType AS InventoryAccountType,
	|	Receipts.Products AS Products,
	|	Receipts.Characteristic AS Characteristic,
	|	Receipts.Batch AS Batch,
	|	Receipts.Ownership AS Ownership,
	|	Receipts.CostObject AS CostObject,
	|	Receipts.Quantity AS Quantity,
	|	Receipts.Amount AS SumForQuantity,
	|	CASE
	|		WHEN Receipts.FixedCost
	|			THEN Receipts.Amount
	|		ELSE 0
	|	END AS Amount
	|INTO ReceiptsAndBalanceWithoutFixedCosts
	|FROM
	|	AccumulationRegister.Inventory AS Receipts
	|WHERE
	|	Receipts.Period BETWEEN &DateBeg AND &DateEnd
	|	AND Receipts.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Receipts.Company = &Company
	|	AND Receipts.PresentationCurrency = &PresentationCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	FixedCostExpense.Company,
	|	FixedCostExpense.PresentationCurrency,
	|	FixedCostExpense.StructuralUnit,
	|	FixedCostExpense.InventoryAccountType,
	|	FixedCostExpense.Products,
	|	FixedCostExpense.Characteristic,
	|	FixedCostExpense.Batch,
	|	FixedCostExpense.Ownership,
	|	FixedCostExpense.CostObject,
	|	-FixedCostExpense.Quantity,
	|	-FixedCostExpense.Amount,
	|	-FixedCostExpense.Amount
	|FROM
	|	AccumulationRegister.Inventory AS FixedCostExpense
	|WHERE
	|	FixedCostExpense.Period BETWEEN &DateBeg AND &DateEnd
	|	AND FixedCostExpense.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND FixedCostExpense.FixedCost
	|	AND FixedCostExpense.Company = &Company
	|	AND FixedCostExpense.PresentationCurrency = &PresentationCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	Balance.Company,
	|	Balance.PresentationCurrency,
	|	Balance.StructuralUnit,
	|	Balance.InventoryAccountType,
	|	Balance.Products,
	|	Balance.Characteristic,
	|	Balance.Batch,
	|	Balance.Ownership,
	|	Balance.CostObject,
	|	Balance.QuantityBalance,
	|	Balance.AmountBalance,
	|	Balance.AmountBalance
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			&DateBeg,
	|			Company = &Company
	|				AND PresentationCurrency = &PresentationCurrency) AS Balance
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Balance.Company AS Company,
	|	Balance.PresentationCurrency AS PresentationCurrency,
	|	Balance.StructuralUnit AS StructuralUnit,
	|	Balance.InventoryAccountType AS InventoryAccountType,
	|	Balance.Products AS Products,
	|	Balance.Characteristic AS Characteristic,
	|	Balance.Batch AS Batch,
	|	Balance.Ownership AS Ownership,
	|	Balance.CostObject AS CostObject,
	|	SUM(Balance.Quantity) AS Quantity,
	|	SUM(Balance.SumForQuantity) AS SumForQuantity,
	|	SUM(Balance.Amount) AS Amount
	|INTO Balance
	|FROM
	|	ReceiptsAndBalanceWithoutFixedCosts AS Balance
	|
	|GROUP BY
	|	Balance.Company,
	|	Balance.StructuralUnit,
	|	Balance.InventoryAccountType,
	|	Balance.Products,
	|	Balance.Characteristic,
	|	Balance.Batch,
	|	Balance.Ownership,
	|	Balance.CostObject,
	|	Balance.PresentationCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	FilledRecords.Company AS Company,
	|	FilledRecords.PresentationCurrency AS PresentationCurrency,
	|	FilledRecords.StructuralUnit AS StructuralUnit,
	|	FilledRecords.InventoryAccountType AS InventoryAccountType,
	|	FilledRecords.Products AS Products,
	|	FilledRecords.Characteristic AS Characteristic,
	|	FilledRecords.Batch AS Batch,
	|	FilledRecords.Ownership AS Ownership,
	|	FilledRecords.CostObject AS CostObject
	|INTO FilledRecords
	|FROM
	|	AccumulationRegister.Inventory AS FilledRecords
	|WHERE
	|	FilledRecords.Period BETWEEN &DateBeg AND &DateEnd
	|	AND FilledRecords.Company = &Company
	|	AND FilledRecords.PresentationCurrency = &PresentationCurrency
	|	AND (FilledRecords.Quantity <> 0
	|			OR FilledRecords.Amount <> 0)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Records.Company AS Company,
	|	Records.PresentationCurrency AS PresentationCurrency,
	|	Records.StructuralUnit AS StructuralUnit,
	|	Records.InventoryAccountType AS InventoryAccountType,
	|	Records.Products AS Products,
	|	Records.Characteristic AS Characteristic,
	|	Records.Batch AS Batch,
	|	Records.Ownership AS Ownership,
	|	Records.CostObject AS CostObject,
	|	CASE
	|		WHEN SUM(Balance.Quantity) = 0
	|			THEN SUM(Balance.SumForQuantity)
	|		ELSE SUM(Balance.Quantity)
	|	END AS Quantity,
	|	CASE
	|		WHEN SUM(Balance.Quantity) = 0
	|				AND SUM(Balance.SumForQuantity) = 0
	|			THEN 0
	|		ELSE CAST(SUM(Balance.Amount) / CASE
	|					WHEN SUM(Balance.Quantity) = 0
	|						THEN SUM(Balance.SumForQuantity)
	|					ELSE SUM(Balance.Quantity)
	|				END AS NUMBER(23, 10))
	|	END AS Amount
	|FROM
	|	FilledRecords AS Records
	|		LEFT JOIN Balance AS Balance
	|		ON Records.Company = Balance.Company
	|			AND Records.PresentationCurrency = Balance.PresentationCurrency
	|			AND Records.StructuralUnit = Balance.StructuralUnit
	|			AND Records.InventoryAccountType = Balance.InventoryAccountType
	|			AND Records.Products = Balance.Products
	|			AND Records.Characteristic = Balance.Characteristic
	|			AND Records.Batch = Balance.Batch
	|			AND Records.Ownership = Balance.Ownership
	|			AND Records.CostObject = Balance.CostObject
	|		INNER JOIN Catalog.Products AS ProductsRef
	|		ON (ProductsRef.Ref = Records.Products)
	|
	|GROUP BY
	|	Records.Company,
	|	Records.PresentationCurrency,
	|	Records.StructuralUnit,
	|	Records.InventoryAccountType,
	|	Records.Products,
	|	Records.Characteristic,
	|	Records.Batch,
	|	Records.Ownership,
	|	Records.CostObject";
	
	NodeNo = 0;
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		RecordSet = InformationRegisters.WriteOffCostAdjustment.CreateRecordSet();
		RecordSet.Filter.Recorder.Set(Ref);
		RecordSet.Write(True);
		
		Selection = Result.Select();
		While Selection.Next() Do
			NodeNo = NodeNo + 1;
			NewNode = RecordSet.Add();
			NewNode.NodeNo = NodeNo;
			NewNode.Recorder = Ref;
			NewNode.Period = Ref.Date;
			FillPropertyValues(NewNode, Selection);
			NewNode.Active = True;
		EndDo;
		RecordSet.Write(False);
	EndIf;
	
	Query.Text =
	"SELECT ALLOWED
	|	WriteOffCostAdjustment.NodeNo,
	|	WriteOffCostAdjustment.Amount
	|INTO SolutionsTable
	|FROM
	|	InformationRegister.WriteOffCostAdjustment AS WriteOffCostAdjustment
	|WHERE
	|	WriteOffCostAdjustment.Recorder = &Recorder
	|
	|INDEX BY
	|	NodeNo
	|";
	Query.Execute();
	
	Return NodeNo;
	
EndFunction

// Solve the linear equations system
//
// Parameters:
// No.
//
// Returns:
//  Boolean - check box of finding a solution.
//
Function SolveLES(Ref, StructureAdditionalProperties)
	
	Query = New Query();
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("DateBeg", 				StructureAdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd",				StructureAdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("Recorder",				Ref);
	Query.SetParameter("EmptyAccount",			StructureAdditionalProperties.ForPosting.EmptyAccount);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	
	CurrentVariance = 1;
	RequiredPrecision = 0.00001;
	IterationsQuantity = 0;
	
	// Prepare the table of movements and writeoffs for the report period. The
	// current period returns are processed as usual movements.
	Query.Text =
	"SELECT ALLOWED
	|	InventoryAndCostAccounting.Company AS Company,
	|	InventoryAndCostAccounting.PresentationCurrency AS PresentationCurrency,
	|	InventoryAndCostAccounting.StructuralUnit AS StructuralUnit,
	|	InventoryAndCostAccounting.InventoryAccountType AS InventoryAccountType,
	|	InventoryAndCostAccounting.Products AS Products,
	|	InventoryAndCostAccounting.Characteristic AS Characteristic,
	|	InventoryAndCostAccounting.Batch AS Batch,
	|	InventoryAndCostAccounting.Ownership AS Ownership,
	|	InventoryAndCostAccounting.CostObject AS CostObject,
	|	InventoryAndCostAccounting.SourceDocument AS SourceDocument,
	|	SUM(InventoryAndCostAccounting.Quantity) AS Quantity,
	|	SUM(InventoryAndCostAccounting.Amount) AS Amount
	|INTO CostAccountingReturnsCurPeriod
	|FROM
	|	AccumulationRegister.Inventory AS InventoryAndCostAccounting
	|WHERE
	|	InventoryAndCostAccounting.Company = &Company
	|	AND InventoryAndCostAccounting.PresentationCurrency = &PresentationCurrency
	|	AND InventoryAndCostAccounting.Period BETWEEN &DateBeg AND &DateEnd
	|	AND InventoryAndCostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND InventoryAndCostAccounting.Return
	|	AND NOT InventoryAndCostAccounting.FixedCost
	|	AND InventoryAndCostAccounting.SourceDocument <> UNDEFINED
	|	AND ENDOFPERIOD(InventoryAndCostAccounting.SourceDocument.Date, MONTH) = ENDOFPERIOD(InventoryAndCostAccounting.Period, MONTH)
	|
	|GROUP BY
	|	InventoryAndCostAccounting.Company,
	|	InventoryAndCostAccounting.PresentationCurrency,
	|	InventoryAndCostAccounting.StructuralUnit,
	|	InventoryAndCostAccounting.InventoryAccountType,
	|	InventoryAndCostAccounting.Products,
	|	InventoryAndCostAccounting.Characteristic,
	|	InventoryAndCostAccounting.Batch,
	|	InventoryAndCostAccounting.Ownership,
	|	InventoryAndCostAccounting.CostObject,
	|	InventoryAndCostAccounting.SourceDocument
	|
	|INDEX BY
	|	SourceDocument,
	|	Company,
	|	PresentationCurrency,
	|	StructuralUnit,
	|	InventoryAccountType,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	Ownership,
	|	CostObject
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CostAccountingReturnsCurPeriod.Company AS Company,
	|	CostAccountingReturnsCurPeriod.PresentationCurrency AS PresentationCurrency,
	|	CostAccountingReturnsCurPeriod.StructuralUnit AS StructuralUnit,
	|	CostAccountingReturnsCurPeriod.InventoryAccountType AS InventoryAccountType,
	|	CostAccountingReturnsCurPeriod.Products AS Products,
	|	CostAccountingReturnsCurPeriod.Characteristic AS Characteristic,
	|	CostAccountingReturnsCurPeriod.Batch AS Batch,
	|	CostAccountingReturnsCurPeriod.Ownership AS Ownership,
	|	CostAccountingReturnsCurPeriod.CostObject AS CostObject,
	|	WriteOffCostAdjustment.NodeNo AS NodeNo,
	|	SUM(ISNULL(InventoryAndCostAccounting.Quantity, 0)) AS QuantitySold,
	|	SUM(ISNULL(InventoryAndCostAccounting.Amount, 0)) AS AmountSold,
	|	CostAccountingReturnsCurPeriod.Quantity AS QuantityReturn,
	|	CostAccountingReturnsCurPeriod.Amount AS AmountReturn,
	|	CostAccountingReturnsCurPeriod.SourceDocument AS SourceDocument
	|INTO CostAccountingReturnsFree
	|FROM
	|	CostAccountingReturnsCurPeriod AS CostAccountingReturnsCurPeriod
	|		LEFT JOIN AccumulationRegister.Inventory AS InventoryAndCostAccounting
	|		ON CostAccountingReturnsCurPeriod.SourceDocument = InventoryAndCostAccounting.SourceDocument
	|			AND CostAccountingReturnsCurPeriod.Company = InventoryAndCostAccounting.Company
	|			AND CostAccountingReturnsCurPeriod.PresentationCurrency = InventoryAndCostAccounting.PresentationCurrency
	|			AND CostAccountingReturnsCurPeriod.Products = InventoryAndCostAccounting.Products
	|			AND CostAccountingReturnsCurPeriod.Characteristic = InventoryAndCostAccounting.Characteristic
	|			AND CostAccountingReturnsCurPeriod.Batch = InventoryAndCostAccounting.Batch
	|			AND CostAccountingReturnsCurPeriod.Ownership = InventoryAndCostAccounting.Ownership
	|			AND CostAccountingReturnsCurPeriod.CostObject = InventoryAndCostAccounting.CostObject
	|			AND (NOT InventoryAndCostAccounting.Return)
	|		LEFT JOIN InformationRegister.WriteOffCostAdjustment AS WriteOffCostAdjustment
	|		ON (WriteOffCostAdjustment.Recorder = &Recorder)
	|			AND (InventoryAndCostAccounting.Company = WriteOffCostAdjustment.Company)
	|			AND (InventoryAndCostAccounting.PresentationCurrency = WriteOffCostAdjustment.PresentationCurrency)
	|			AND (InventoryAndCostAccounting.StructuralUnit = WriteOffCostAdjustment.StructuralUnit)
	|			AND (InventoryAndCostAccounting.InventoryAccountType = WriteOffCostAdjustment.InventoryAccountType)
	|			AND (InventoryAndCostAccounting.Products = WriteOffCostAdjustment.Products)
	|			AND (InventoryAndCostAccounting.Characteristic = WriteOffCostAdjustment.Characteristic)
	|			AND (InventoryAndCostAccounting.Batch = WriteOffCostAdjustment.Batch)
	|			AND (InventoryAndCostAccounting.Ownership = WriteOffCostAdjustment.Ownership)
	|			AND (InventoryAndCostAccounting.CostObject = WriteOffCostAdjustment.CostObject)
	|
	|GROUP BY
	|	CostAccountingReturnsCurPeriod.Company,
	|	CostAccountingReturnsCurPeriod.PresentationCurrency,
	|	CostAccountingReturnsCurPeriod.StructuralUnit,
	|	CostAccountingReturnsCurPeriod.InventoryAccountType,
	|	CostAccountingReturnsCurPeriod.Products,
	|	CostAccountingReturnsCurPeriod.Characteristic,
	|	CostAccountingReturnsCurPeriod.Batch,
	|	CostAccountingReturnsCurPeriod.Ownership,
	|	CostAccountingReturnsCurPeriod.CostObject,
	|	WriteOffCostAdjustment.NodeNo,
	|	CostAccountingReturnsCurPeriod.Quantity,
	|	CostAccountingReturnsCurPeriod.Amount,
	|	CostAccountingReturnsCurPeriod.SourceDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CostAccountingReturns.Company AS Company,
	|	CostAccountingReturns.PresentationCurrency AS PresentationCurrency,
	|	CostAccountingReturns.StructuralUnit AS StructuralUnit,
	|	CostAccountingReturns.InventoryAccountType AS InventoryAccountType,
	|	CostAccountingReturns.Products AS Products,
	|	CostAccountingReturns.Characteristic AS Characteristic,
	|	CostAccountingReturns.Batch AS Batch,
	|	CostAccountingReturns.Ownership AS Ownership,
	|	CostAccountingReturns.CostObject AS CostObject,
	|	CostAccountingReturns.NodeNo AS NodeNo,
	|	CostAccountingReturns.QuantitySold AS QuantitySold,
	|	CostAccountingReturns.AmountSold AS AmountSold,
	|	CostAccountingReturns.QuantityReturn AS QuantityReturn,
	|	CostAccountingReturns.AmountReturn AS AmountReturn,
	|	0 AS QuantityDistributed,
	|	0 AS SumIsDistributed,
	|	CostAccountingReturns.SourceDocument AS SourceDocument
	|FROM
	|	CostAccountingReturnsFree AS CostAccountingReturns
	|
	|ORDER BY
	|	NodeNo
	|TOTALS BY
	|	Company,
	|	PresentationCurrency,
	|	StructuralUnit,
	|	InventoryAccountType,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	Ownership,
	|	CostObject,
	|	SourceDocument,
	|	AmountReturn,
	|	QuantityReturn";
	
	QueryResult = Query.ExecuteBatch();
	
	ReturnsTable = QueryResult[2].Unload();
	ReturnsTable.Clear();
	
	BypassOnCounterparty = QueryResult[2].Select(QueryResultIteration.ByGroups);
	While BypassOnCounterparty.Next() Do
		BypassByPresentationCurrency = BypassOnCounterparty.Select(QueryResultIteration.ByGroups);
		While BypassByPresentationCurrency.Next() Do
			BypassByStructuralUnit = BypassByPresentationCurrency.Select(QueryResultIteration.ByGroups);
			While BypassByStructuralUnit.Next() Do
				BypassingByAccountStatement = BypassByStructuralUnit.Select(QueryResultIteration.ByGroups);
				While BypassingByAccountStatement.Next() Do
					BypassOnProducts = BypassingByAccountStatement.Select(QueryResultIteration.ByGroups);
					While BypassOnProducts.Next() Do
						BypassByCharacteristic = BypassOnProducts.Select(QueryResultIteration.ByGroups);
						While BypassByCharacteristic.Next() Do
							CrawlByBatch = BypassByCharacteristic.Select(QueryResultIteration.ByGroups);
							While CrawlByBatch.Next() Do
								BypassByOwnership = CrawlByBatch.Select(QueryResultIteration.ByGroups);
								While BypassByOwnership.Next() Do
									BypassByCostObject = BypassByOwnership.Select(QueryResultIteration.ByGroups);
									While BypassByCostObject.Next() Do
										BypassBySourceDocument = BypassByCostObject.Select(QueryResultIteration.ByGroups);
										While BypassBySourceDocument.Next() Do
											BypassOnSumReturn = BypassBySourceDocument.Select(QueryResultIteration.ByGroups);
											While BypassOnSumReturn.Next() Do
												BypassByQuantityReturn = BypassOnSumReturn.Select(QueryResultIteration.ByGroups);
												While BypassByQuantityReturn.Next() Do
													QuantityLeftToDistribute = BypassByQuantityReturn.QuantityReturn;
													AmountLeftToDistribute = BypassByQuantityReturn.AmountReturn;
													SelectionDetailRecords = BypassByQuantityReturn.Select();
													While SelectionDetailRecords.Next() Do
														If QuantityLeftToDistribute > 0 Then
															If QuantityLeftToDistribute <= SelectionDetailRecords.QuantitySold Then
																NewRow = ReturnsTable.Add();
																FillPropertyValues(NewRow, SelectionDetailRecords);
																NewRow.QuantityDistributed = QuantityLeftToDistribute;
																QuantityLeftToDistribute = 0;
																NewRow.SumIsDistributed = AmountLeftToDistribute;
																AmountLeftToDistribute = 0;
															Else
																NewRow = ReturnsTable.Add();
																FillPropertyValues(NewRow, SelectionDetailRecords);
																NewRow.QuantityDistributed = SelectionDetailRecords.QuantitySold;
																QuantityLeftToDistribute = QuantityLeftToDistribute - SelectionDetailRecords.QuantitySold;
																NewRow.SumIsDistributed = SelectionDetailRecords.AmountSold;
																AmountLeftToDistribute = AmountLeftToDistribute - SelectionDetailRecords.AmountSold;
															EndIf;
														EndIf;
													EndDo;
												EndDo;
											EndDo;
										EndDo;
									EndDo;
								EndDo;
							EndDo;
						EndDo;
					EndDo;
				EndDo;
			EndDo;
		EndDo;
	EndDo;
	
	Query.SetParameter("ReturnsTable", ReturnsTable);
	
	Query.Text =
	"SELECT DISTINCT
	|	ReturnsTable.Company AS Company,
	|	ReturnsTable.PresentationCurrency AS PresentationCurrency,
	|	ReturnsTable.StructuralUnit AS StructuralUnit,
	|	ReturnsTable.InventoryAccountType AS InventoryAccountType,
	|	ReturnsTable.Products AS Products,
	|	ReturnsTable.Characteristic AS Characteristic,
	|	ReturnsTable.Batch AS Batch,
	|	ReturnsTable.Ownership AS Ownership,
	|	ReturnsTable.CostObject AS CostObject,
	|	ReturnsTable.NodeNo AS NodeNo,
	|	ReturnsTable.QuantityDistributed AS Quantity,
	|	ReturnsTable.SumIsDistributed AS Amount
	|INTO CostAccountingReturns
	|FROM
	|	&ReturnsTable AS ReturnsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	InventoryAndCostAccounting.Company AS Company,
	|	InventoryAndCostAccounting.PresentationCurrency AS PresentationCurrency,
	|	InventoryAndCostAccounting.StructuralUnitCorr AS StructuralUnit,
	|	InventoryAndCostAccounting.CorrInventoryAccountType AS InventoryAccountType,
	|	InventoryAndCostAccounting.ProductsCorr AS Products,
	|	InventoryAndCostAccounting.CharacteristicCorr AS Characteristic,
	|	InventoryAndCostAccounting.BatchCorr AS Batch,
	|	InventoryAndCostAccounting.OwnershipCorr AS Ownership,
	|	InventoryAndCostAccounting.CostObjectCorr AS CostObject,
	|	WriteOffCostAdjustment.NodeNo AS NodeNo,
	|	SUM(CASE
	|			WHEN InventoryAndCostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|					AND NOT InventoryAndCostAccounting.Return
	|				THEN InventoryAndCostAccounting.Quantity
	|			ELSE 0
	|		END) AS Quantity,
	|	SUM(CAST(CASE
	|				WHEN InventoryAndCostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|						AND NOT InventoryAndCostAccounting.Return
	|					THEN InventoryAndCostAccounting.Amount
	|				WHEN InventoryAndCostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						AND InventoryAndCostAccounting.Return
	|					THEN -InventoryAndCostAccounting.Amount
	|				ELSE 0
	|			END AS NUMBER(23, 10))) AS Amount
	|INTO CostAccountingWithoutReturnAccounting
	|FROM
	|	AccumulationRegister.Inventory AS InventoryAndCostAccounting
	|		LEFT JOIN InformationRegister.WriteOffCostAdjustment AS WriteOffCostAdjustment
	|		ON (WriteOffCostAdjustment.Recorder = &Recorder)
	|			AND InventoryAndCostAccounting.Company = WriteOffCostAdjustment.Company
	|			AND InventoryAndCostAccounting.PresentationCurrency = WriteOffCostAdjustment.PresentationCurrency
	|			AND InventoryAndCostAccounting.StructuralUnit = WriteOffCostAdjustment.StructuralUnit
	|			AND InventoryAndCostAccounting.InventoryAccountType = WriteOffCostAdjustment.InventoryAccountType
	|			AND InventoryAndCostAccounting.Products = WriteOffCostAdjustment.Products
	|			AND InventoryAndCostAccounting.Characteristic = WriteOffCostAdjustment.Characteristic
	|			AND InventoryAndCostAccounting.Batch = WriteOffCostAdjustment.Batch
	|			AND InventoryAndCostAccounting.Ownership = WriteOffCostAdjustment.Ownership
	|			AND InventoryAndCostAccounting.CostObject = WriteOffCostAdjustment.CostObject
	|WHERE
	|	InventoryAndCostAccounting.Period BETWEEN &DateBeg AND &DateEnd
	|	AND InventoryAndCostAccounting.Company = &Company
	|	AND InventoryAndCostAccounting.PresentationCurrency = &PresentationCurrency
	|	AND InventoryAndCostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND NOT InventoryAndCostAccounting.FixedCost
	|
	|GROUP BY
	|	InventoryAndCostAccounting.Company,
	|	InventoryAndCostAccounting.PresentationCurrency,
	|	InventoryAndCostAccounting.StructuralUnitCorr,
	|	InventoryAndCostAccounting.CorrInventoryAccountType,
	|	InventoryAndCostAccounting.ProductsCorr,
	|	InventoryAndCostAccounting.CharacteristicCorr,
	|	InventoryAndCostAccounting.BatchCorr,
	|	InventoryAndCostAccounting.OwnershipCorr,
	|	InventoryAndCostAccounting.CostObjectCorr,
	|	WriteOffCostAdjustment.NodeNo,
	|	InventoryAndCostAccounting.PresentationCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CostAccounting.Company AS Company,
	|	CostAccounting.PresentationCurrency AS PresentationCurrency,
	|	CostAccounting.StructuralUnit AS StructuralUnit,
	|	CostAccounting.InventoryAccountType AS InventoryAccountType,
	|	CostAccounting.Products AS Products,
	|	CostAccounting.Characteristic AS Characteristic,
	|	CostAccounting.Batch AS Batch,
	|	CostAccounting.Ownership AS Ownership,
	|	CostAccounting.CostObject AS CostObject,
	|	CostAccounting.NodeNo AS NodeNo,
	|	SUM(CostAccounting.Quantity) AS Quantity,
	|	SUM(CostAccounting.Amount) AS Amount
	|INTO CostAccounting
	|FROM
	|	(SELECT
	|		CostAccountingNetOfRefunds.Company AS Company,
	|		CostAccountingNetOfRefunds.PresentationCurrency AS PresentationCurrency,
	|		CostAccountingNetOfRefunds.StructuralUnit AS StructuralUnit,
	|		CostAccountingNetOfRefunds.InventoryAccountType AS InventoryAccountType,
	|		CostAccountingNetOfRefunds.Products AS Products,
	|		CostAccountingNetOfRefunds.Characteristic AS Characteristic,
	|		CostAccountingNetOfRefunds.Batch AS Batch,
	|		CostAccountingNetOfRefunds.Ownership AS Ownership,
	|		CostAccountingNetOfRefunds.CostObject AS CostObject,
	|		CostAccountingNetOfRefunds.NodeNo AS NodeNo,
	|		CostAccountingNetOfRefunds.Quantity AS Quantity,
	|		CostAccountingNetOfRefunds.Amount AS Amount
	|	FROM
	|		CostAccountingWithoutReturnAccounting AS CostAccountingNetOfRefunds
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CostAccountingReturns.Company,
	|		CostAccountingReturns.PresentationCurrency,
	|		CostAccountingReturns.StructuralUnit,
	|		CostAccountingReturns.InventoryAccountType,
	|		CostAccountingReturns.Products,
	|		CostAccountingReturns.Characteristic,
	|		CostAccountingReturns.Batch,
	|		CostAccountingReturns.Ownership,
	|		CostAccountingReturns.CostObject,
	|		CostAccountingReturns.NodeNo,
	|		CostAccountingReturns.Quantity,
	|		CostAccountingReturns.Amount
	|	FROM
	|		CostAccountingReturns AS CostAccountingReturns
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CostAccountingReturns.Company,
	|		CostAccountingReturns.PresentationCurrency,
	|		UNDEFINED,
	|		VALUE(Enum.InventoryAccountTypes.EmptyRef),
	|		VALUE(Catalog.Products.EmptyRef),
	|		VALUE(Catalog.ProductsCharacteristics.EmptyRef),
	|		VALUE(Catalog.ProductsBatches.EmptyRef),
	|		CostAccountingReturns.Ownership,
	|		CostAccountingReturns.CostObject,
	|		CostAccountingReturns.NodeNo,
	|		-CostAccountingReturns.Quantity,
	|		-CostAccountingReturns.Amount
	|	FROM
	|		CostAccountingReturns AS CostAccountingReturns) AS CostAccounting
	|
	|GROUP BY
	|	CostAccounting.Company,
	|	CostAccounting.PresentationCurrency,
	|	CostAccounting.StructuralUnit,
	|	CostAccounting.InventoryAccountType,
	|	CostAccounting.Products,
	|	CostAccounting.Characteristic,
	|	CostAccounting.Batch,
	|	CostAccounting.Ownership,
	|	CostAccounting.CostObject,
	|	CostAccounting.NodeNo
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	StructuralUnit,
	|	InventoryAccountType,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	Ownership,
	|	CostObject,
	|	NodeNo";
	
	Query.ExecuteBatch();
	
	// Iteratively search for the solution of linear
	// equations system until the deviation is less than the required one or 100 calculation iterations are not executed.
	While (CurrentVariance > RequiredPrecision * RequiredPrecision) AND (IterationsQuantity < 100) Do
		
		IterationsQuantity = IterationsQuantity + 1;
		
		// The next settlement iteration.
		Query.Text = 
		"SELECT ALLOWED
		|	WriteOffCostAdjustment.NodeNo AS NodeNo,
		|	SUM(CAST(CASE
		|				WHEN WriteOffCostAdjustment.Quantity <> 0
		|					THEN SolutionsTable.Amount * CASE
		|							WHEN CostAccounting.Quantity = 0
		|								THEN CostAccounting.Amount
		|							ELSE CostAccounting.Quantity
		|						END / WriteOffCostAdjustment.Quantity
		|				ELSE 0
		|			END AS NUMBER(23, 10))) AS Amount
		|INTO TemporaryTableSolutions
		|FROM
		|	InformationRegister.WriteOffCostAdjustment AS WriteOffCostAdjustment
		|		LEFT JOIN CostAccounting AS CostAccounting
		|		ON WriteOffCostAdjustment.Company = CostAccounting.Company
		|			AND WriteOffCostAdjustment.PresentationCurrency = CostAccounting.PresentationCurrency
		|			AND WriteOffCostAdjustment.StructuralUnit = CostAccounting.StructuralUnit
		|			AND WriteOffCostAdjustment.InventoryAccountType = CostAccounting.InventoryAccountType
		|			AND WriteOffCostAdjustment.Products = CostAccounting.Products
		|			AND WriteOffCostAdjustment.Characteristic = CostAccounting.Characteristic
		|			AND WriteOffCostAdjustment.Batch = CostAccounting.Batch
		|			AND WriteOffCostAdjustment.Ownership = CostAccounting.Ownership
		|			AND WriteOffCostAdjustment.CostObject = CostAccounting.CostObject
		|		LEFT JOIN SolutionsTable AS SolutionsTable
		|		ON (CostAccounting.NodeNo = SolutionsTable.NodeNo)
		|WHERE
		|	WriteOffCostAdjustment.Recorder = &Recorder
		|
		|GROUP BY
		|	WriteOffCostAdjustment.NodeNo
		|
		|INDEX BY
		|	NodeNo
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SUM((ISNULL(SolutionsTable.Amount, 0) - (WriteOffCostAdjustment.Amount + ISNULL(TemporaryTableSolutions.Amount, 0))) * (ISNULL(SolutionsTable.Amount, 0) - (WriteOffCostAdjustment.Amount + ISNULL(TemporaryTableSolutions.Amount, 0)))) AS AmountOfSquaresOfRejections
		|FROM
		|	InformationRegister.WriteOffCostAdjustment AS WriteOffCostAdjustment
		|		LEFT JOIN TemporaryTableSolutions AS TemporaryTableSolutions
		|		ON (TemporaryTableSolutions.NodeNo = WriteOffCostAdjustment.NodeNo)
		|		LEFT JOIN SolutionsTable AS SolutionsTable
		|		ON (SolutionsTable.NodeNo = WriteOffCostAdjustment.NodeNo)
		|WHERE
		|	WriteOffCostAdjustment.Recorder = &Recorder";
		
		ResultsArray = Query.ExecuteBatch();
		Result = ResultsArray[1];
		
		OldRejection = CurrentVariance;
		If Result.IsEmpty() Then
			CurrentVariance = 0; // there are no deviations
		Else
			Selection = Result.Select();
			Selection.Next();
			
			// Determine the current solution variance.
			CurrentVariance = ?(Selection.AmountOfSquaresOfRejections = NULL, 0, Selection.AmountOfSquaresOfRejections);
		EndIf;
		
		Query.Text =
		"DROP SolutionsTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	WriteOffCostAdjustment.NodeNo AS NodeNo,
		|	WriteOffCostAdjustment.Amount + ISNULL(TemporaryTableSolutions.Amount, 0) AS Amount
		|INTO SolutionsTable
		|FROM
		|	InformationRegister.WriteOffCostAdjustment AS WriteOffCostAdjustment
		|		LEFT JOIN TemporaryTableSolutions AS TemporaryTableSolutions
		|		ON (TemporaryTableSolutions.NodeNo = WriteOffCostAdjustment.NodeNo)
		|WHERE
		|	WriteOffCostAdjustment.Recorder = &Recorder
		|
		|INDEX BY
		|	NodeNo
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableSolutions";
		
		Query.ExecuteBatch();
		
	EndDo;

	Return True;
	
EndFunction

Function ParametersForRecordsByExpensesRegister()
	
	Result = New Structure;
	Result.Insert("ContentOfAccountingRecord", Undefined);
	Result.Insert("IsReturn", False);
	Result.Insert("Recorder", Undefined);
	Result.Insert("IsFIFO", False);
	
	Return Result;
	
EndFunction

Procedure WriteInventoryRegister(Ref, InventoryRecords, WriteParameters)
	
	Query = New Query(
	"SELECT
	|	Inventory.RecordType AS RecordType,
	|	Inventory.Period AS Period,
	|	Inventory.Company AS Company,
	|	Inventory.PresentationCurrency AS PresentationCurrency,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.Ownership AS Ownership,
	|	Inventory.SalesOrder AS SalesOrder,
	|	Inventory.Quantity AS Quantity,
	|	Inventory.Amount AS Amount,
	|	Inventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	Inventory.CorrGLAccount AS CorrGLAccount,
	|	Inventory.ProductsCorr AS ProductsCorr,
	|	Inventory.CharacteristicCorr AS CharacteristicCorr,
	|	Inventory.BatchCorr AS BatchCorr,
	|	Inventory.Specification AS Specification,
	|	Inventory.SpecificationCorr AS SpecificationCorr,
	|	Inventory.SourceDocument AS SourceDocument,
	|	Inventory.Department AS Department,
	|	Inventory.Responsible AS Responsible,
	|	Inventory.VATRate AS VATRate,
	|	Inventory.FixedCost AS FixedCost,
	|	Inventory.ProductionExpenses AS ProductionExpenses,
	|	Inventory.Return AS Return,
	|	Inventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	Inventory.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	Inventory.CostObject AS CostObject,
	|	Inventory.CostObjectCorr AS CostObjectCorr,
	|	Inventory.OwnershipCorr AS OwnershipCorr,
	|	TRUE AS OfflineRecord,
	|	Inventory.InventoryAccountType AS InventoryAccountType,
	|	Inventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	Inventory.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	Inventory.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	Inventory.CorrSalesOrder AS CorrSalesOrder,
	|	Inventory.SalesRep AS SalesRep,
	|	Inventory.Counterparty AS Counterparty,
	|	Inventory.Currency AS Currency
	|INTO NewRecords
	|FROM
	|	&RegisterRecords AS Inventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OnlineRecords.RecordType AS RecordType,
	|	OnlineRecords.Period AS Period,
	|	OnlineRecords.Company AS Company,
	|	OnlineRecords.PresentationCurrency AS PresentationCurrency,
	|	OnlineRecords.StructuralUnit AS StructuralUnit,
	|	OnlineRecords.GLAccount AS GLAccount,
	|	OnlineRecords.Products AS Products,
	|	OnlineRecords.Characteristic AS Characteristic,
	|	OnlineRecords.Batch AS Batch,
	|	OnlineRecords.Ownership AS Ownership,
	|	OnlineRecords.SalesOrder AS SalesOrder,
	|	OnlineRecords.Quantity AS Quantity,
	|	OnlineRecords.Amount AS Amount,
	|	OnlineRecords.StructuralUnitCorr AS StructuralUnitCorr,
	|	OnlineRecords.CorrGLAccount AS CorrGLAccount,
	|	OnlineRecords.ProductsCorr AS ProductsCorr,
	|	OnlineRecords.CharacteristicCorr AS CharacteristicCorr,
	|	OnlineRecords.BatchCorr AS BatchCorr,
	|	OnlineRecords.Specification AS Specification,
	|	OnlineRecords.SpecificationCorr AS SpecificationCorr,
	|	OnlineRecords.SourceDocument AS SourceDocument,
	|	OnlineRecords.Department AS Department,
	|	OnlineRecords.Responsible AS Responsible,
	|	OnlineRecords.VATRate AS VATRate,
	|	OnlineRecords.FixedCost AS FixedCost,
	|	OnlineRecords.ProductionExpenses AS ProductionExpenses,
	|	OnlineRecords.Return AS Return,
	|	OnlineRecords.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	OnlineRecords.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	OnlineRecords.CostObject AS CostObject,
	|	OnlineRecords.CostObjectCorr AS CostObjectCorr,
	|	OnlineRecords.OwnershipCorr AS OwnershipCorr,
	|	OnlineRecords.OfflineRecord AS OfflineRecord,
	|	OnlineRecords.InventoryAccountType AS InventoryAccountType,
	|	OnlineRecords.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	OnlineRecords.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	OnlineRecords.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	OnlineRecords.CorrSalesOrder AS CorrSalesOrder,
	|	OnlineRecords.SalesRep AS SalesRep,
	|	OnlineRecords.Counterparty AS Counterparty,
	|	OnlineRecords.Currency AS Currency
	|FROM
	|	AccumulationRegister.Inventory AS OnlineRecords
	|WHERE
	|	OnlineRecords.Recorder = &Ref
	|	AND OnlineRecords.Period BETWEEN &DateBeg AND &DateEnd
	|	AND OnlineRecords.Company = &Company
	|	AND NOT OnlineRecords.OfflineRecord
	|	AND OnlineRecords.PresentationCurrency = &PresentationCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.Ownership,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.Amount,
	|	OfflineRecords.StructuralUnitCorr,
	|	OfflineRecords.CorrGLAccount,
	|	OfflineRecords.ProductsCorr,
	|	OfflineRecords.CharacteristicCorr,
	|	OfflineRecords.BatchCorr,
	|	OfflineRecords.Specification,
	|	OfflineRecords.SpecificationCorr,
	|	OfflineRecords.SourceDocument,
	|	OfflineRecords.Department,
	|	OfflineRecords.Responsible,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.FixedCost,
	|	OfflineRecords.ProductionExpenses,
	|	OfflineRecords.Return,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.RetailTransferEarningAccounting,
	|	OfflineRecords.CostObject,
	|	OfflineRecords.CostObjectCorr,
	|	OfflineRecords.OwnershipCorr,
	|	OfflineRecords.OfflineRecord,
	|	OfflineRecords.InventoryAccountType,
	|	OfflineRecords.CorrInventoryAccountType,
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.CorrIncomeAndExpenseItem,
	|	OfflineRecords.CorrSalesOrder,
	|	OfflineRecords.SalesRep,
	|	OfflineRecords.Counterparty,
	|	OfflineRecords.Currency
	|FROM
	|	NewRecords AS OfflineRecords");
	
	Query.SetParameter("RegisterRecords", InventoryRecords);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("DateBeg", WriteParameters.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd", WriteParameters.EndDatePeriod);
	Query.SetParameter("Company", WriteParameters.Company);
	Query.SetParameter("PresentationCurrency", WriteParameters.PresentationCurrency);
	
	Query.TempTablesManager = New TempTablesManager;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		InventoryRecords.Load(Result.Unload());
		InventoryRecords.Write();
	EndIf;
	
EndProcedure

Procedure WriteSalesRegister(Ref, SalesRecords, WriteParameters)
	
	Query = New Query(
	"SELECT
	|	Sales.Period AS Period,
	|	Sales.Products AS Products,
	|	Sales.Characteristic AS Characteristic,
	|	Sales.Batch AS Batch,
	|	Sales.Ownership AS Ownership,
	|	Sales.Document AS Document,
	|	Sales.VATRate AS VATRate,
	|	Sales.Company AS Company,
	|	Sales.PresentationCurrency AS PresentationCurrency,
	|	Sales.Counterparty AS Counterparty,
	|	Sales.SalesOrder AS SalesOrder,
	|	Sales.Department AS Department,
	|	Sales.Responsible AS Responsible,
	|	Sales.SalesRep AS SalesRep,
	|	Sales.Currency AS Currency,
	|	Sales.Quantity AS Quantity,
	|	Sales.Amount AS Amount,
	|	Sales.VATAmount AS VATAmount,
	|	Sales.Cost AS Cost,
	|	Sales.AmountCur AS AmountCur,
	|	Sales.VATAmountCur AS VATAmountCur,
	|	TRUE AS OfflineRecord
	|INTO NewRecords
	|FROM
	|	&RegisterRecords AS Sales
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OnlineRecords.Period AS Period,
	|	OnlineRecords.Products AS Products,
	|	OnlineRecords.Characteristic AS Characteristic,
	|	OnlineRecords.Batch AS Batch,
	|	OnlineRecords.Ownership AS Ownership,
	|	OnlineRecords.Document AS Document,
	|	OnlineRecords.VATRate AS VATRate,
	|	OnlineRecords.Company AS Company,
	|	OnlineRecords.PresentationCurrency AS PresentationCurrency,
	|	OnlineRecords.Counterparty AS Counterparty,
	|	OnlineRecords.SalesOrder AS SalesOrder,
	|	OnlineRecords.Department AS Department,
	|	OnlineRecords.Responsible AS Responsible,
	|	OnlineRecords.SalesRep AS SalesRep,
	|	OnlineRecords.Currency AS Currency,
	|	OnlineRecords.Quantity AS Quantity,
	|	OnlineRecords.Amount AS Amount,
	|	OnlineRecords.VATAmount AS VATAmount,
	|	OnlineRecords.Cost AS Cost,
	|	OnlineRecords.AmountCur AS AmountCur,
	|	OnlineRecords.VATAmountCur AS VATAmountCur,
	|	OnlineRecords.OfflineRecord AS OfflineRecord
	|FROM
	|	AccumulationRegister.Sales AS OnlineRecords
	|WHERE
	|	OnlineRecords.Recorder = &Ref
	|	AND OnlineRecords.Period BETWEEN &DateBeg AND &DateEnd
	|	AND OnlineRecords.Company = &Company
	|	AND NOT OnlineRecords.OfflineRecord
	|	AND OnlineRecords.PresentationCurrency = &PresentationCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.Ownership,
	|	OfflineRecords.Document,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.Counterparty,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.Department,
	|	OfflineRecords.Responsible,
	|	OfflineRecords.SalesRep,
	|	OfflineRecords.Currency,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.Amount,
	|	OfflineRecords.VATAmount,
	|	OfflineRecords.Cost,
	|	OfflineRecords.AmountCur,
	|	OfflineRecords.VATAmountCur,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	NewRecords AS OfflineRecords");
	
	Query.SetParameter("RegisterRecords", SalesRecords);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("DateBeg", WriteParameters.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd", WriteParameters.EndDatePeriod);
	Query.SetParameter("Company", WriteParameters.Company);
	Query.SetParameter("ExchangeRateMethod", WriteParameters.ExchangeRateMethod);
	Query.SetParameter("PresentationCurrency", WriteParameters.PresentationCurrency);
	
	Query.TempTablesManager = New TempTablesManager;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		SalesRecords.Load(Result.Unload());
		SalesRecords.Write();
	EndIf;
	
EndProcedure

Procedure WriteIncomeAndExpensesRegister(Ref, IncomeAndExpensesRecords, WriteParameters)
	
	Query = New Query(
	"SELECT
	|	NewRecords.Period AS Period,
	|	NewRecords.Company AS Company,
	|	NewRecords.PresentationCurrency AS PresentationCurrency,
	|	NewRecords.StructuralUnit AS StructuralUnit,
	|	NewRecords.BusinessLine AS BusinessLine,
	|	NewRecords.SalesOrder AS SalesOrder,
	|	NewRecords.GLAccount AS GLAccount,
	|	NewRecords.AmountIncome AS AmountIncome,
	|	NewRecords.AmountExpense AS AmountExpense,
	|	NewRecords.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	TRUE AS OfflineRecord,
	|	NewRecords.IncomeAndExpenseItem AS IncomeAndExpenseItem
	|INTO NewRecords
	|FROM
	|	&RegisterRecords AS NewRecords
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OnlineRecords.Period AS Period,
	|	OnlineRecords.Company AS Company,
	|	OnlineRecords.PresentationCurrency AS PresentationCurrency,
	|	OnlineRecords.StructuralUnit AS StructuralUnit,
	|	OnlineRecords.BusinessLine AS BusinessLine,
	|	OnlineRecords.SalesOrder AS SalesOrder,
	|	OnlineRecords.GLAccount AS GLAccount,
	|	OnlineRecords.AmountIncome AS AmountIncome,
	|	OnlineRecords.AmountExpense AS AmountExpense,
	|	OnlineRecords.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	OnlineRecords.OfflineRecord AS OfflineRecord,
	|	OnlineRecords.IncomeAndExpenseItem AS IncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS OnlineRecords
	|WHERE
	|	OnlineRecords.Recorder = &Ref
	|	AND OnlineRecords.Period BETWEEN &DateBeg AND &DateEnd
	|	AND OnlineRecords.Company = &Company
	|	AND NOT OnlineRecords.OfflineRecord
	|	AND OnlineRecords.PresentationCurrency = &PresentationCurrency
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
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord,
	|	OfflineRecords.IncomeAndExpenseItem
	|FROM
	|	NewRecords AS OfflineRecords");
	
	Query.SetParameter("RegisterRecords", IncomeAndExpensesRecords);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("DateBeg", WriteParameters.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd", WriteParameters.EndDatePeriod);
	Query.SetParameter("Company", WriteParameters.Company);
	Query.SetParameter("PresentationCurrency", WriteParameters.PresentationCurrency);
	
	Query.TempTablesManager = New TempTablesManager;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		IncomeAndExpensesRecords.Load(Result.Unload());
		IncomeAndExpensesRecords.Write();
	EndIf;
	
EndProcedure

Procedure WriteAccountingJournalEntriesRegister(Ref, AccountingJournalEntriesRecords, WriteParameters)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	NewRecords.Period AS Period,
	|	NewRecords.AccountDr AS AccountDr,
	|	NewRecords.AccountCr AS AccountCr,
	|	NewRecords.Company AS Company,
	|	NewRecords.PlanningPeriod AS PlanningPeriod,
	|	NewRecords.CurrencyDr AS CurrencyDr,
	|	NewRecords.CurrencyCr AS CurrencyCr,
	|	NewRecords.Amount AS Amount,
	|	NewRecords.AmountCurDr AS AmountCurDr,
	|	NewRecords.AmountCurCr AS AmountCurCr,
	|	NewRecords.Content AS Content,
	|	TRUE AS OfflineRecord
	|INTO NewRecords
	|FROM
	|	&RegisterRecords AS NewRecords
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OnlineRecords.Period AS Period,
	|	OnlineRecords.AccountDr AS AccountDr,
	|	OnlineRecords.AccountCr AS AccountCr,
	|	OnlineRecords.Company AS Company,
	|	OnlineRecords.PlanningPeriod AS PlanningPeriod,
	|	OnlineRecords.CurrencyDr AS CurrencyDr,
	|	OnlineRecords.CurrencyCr AS CurrencyCr,
	|	OnlineRecords.Amount AS Amount,
	|	OnlineRecords.AmountCurDr AS AmountCurDr,
	|	OnlineRecords.AmountCurCr AS AmountCurCr,
	|	OnlineRecords.Content AS Content,
	|	OnlineRecords.OfflineRecord AS OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS OnlineRecords
	|WHERE
	|	OnlineRecords.Recorder = &Ref
	|	AND OnlineRecords.Period BETWEEN &DateBeg AND &DateEnd
	|	AND OnlineRecords.Company = &Company
	|	AND NOT OnlineRecords.OfflineRecord
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.AccountDr,
	|	OfflineRecords.AccountCr,
	|	OfflineRecords.Company,
	|	OfflineRecords.PlanningPeriod,
	|	OfflineRecords.CurrencyDr,
	|	OfflineRecords.CurrencyCr,
	|	OfflineRecords.Amount,
	|	OfflineRecords.AmountCurDr,
	|	OfflineRecords.AmountCurCr,
	|	OfflineRecords.Content,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	NewRecords AS OfflineRecords");
	
	Query.SetParameter("RegisterRecords", AccountingJournalEntriesRecords);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("DateBeg", WriteParameters.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd", WriteParameters.EndDatePeriod);
	Query.SetParameter("Company", WriteParameters.Company);
	
	Query.TempTablesManager = New TempTablesManager;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		AccountingJournalEntriesRecords.Load(Result.Unload());
		AccountingJournalEntriesRecords.Write();
	EndIf;
	
EndProcedure

Procedure WritePOSSummaryRegister(Ref, POSSummaryRecords, WriteParameters)
	
	Query = New Query(
	"SELECT
	|	POS.Period AS Period,
	|	POS.Company AS Company,
	|	POS.PresentationCurrency AS PresentationCurrency,
	|	POS.StructuralUnit AS StructuralUnit,
	|	POS.Currency AS Currency,
	|	POS.Amount AS Amount,
	|	POS.AmountCur AS AmountCur,
	|	POS.Cost AS Cost,
	|	POS.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	POS.SalesDocument AS SalesDocument,
	|	TRUE AS OfflineRecord
	|INTO NewRecords
	|FROM
	|	&RegisterRecords AS POS
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OnlineRecords.Period AS Period,
	|	OnlineRecords.Company AS Company,
	|	OnlineRecords.PresentationCurrency AS PresentationCurrency,
	|	OnlineRecords.StructuralUnit AS StructuralUnit,
	|	OnlineRecords.Currency AS Currency,
	|	OnlineRecords.Amount AS Amount,
	|	OnlineRecords.AmountCur AS AmountCur,
	|	OnlineRecords.Cost AS Cost,
	|	OnlineRecords.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	OnlineRecords.SalesDocument AS SalesDocument,
	|	OnlineRecords.OfflineRecord AS OfflineRecord
	|FROM
	|	AccumulationRegister.POSSummary AS OnlineRecords
	|WHERE
	|	OnlineRecords.Recorder = &Ref
	|	AND OnlineRecords.Period BETWEEN &DateBeg AND &DateEnd
	|	AND OnlineRecords.Company = &Company
	|	AND OnlineRecords.PresentationCurrency = &PresentationCurrency
	|	AND NOT OnlineRecords.OfflineRecord
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.Currency,
	|	OfflineRecords.Amount,
	|	OfflineRecords.AmountCur,
	|	OfflineRecords.Cost,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.SalesDocument,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	NewRecords AS OfflineRecords");
	
	Query.SetParameter("RegisterRecords", POSSummaryRecords);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("DateBeg", WriteParameters.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd", WriteParameters.EndDatePeriod);
	Query.SetParameter("Company", WriteParameters.Company);
	Query.SetParameter("PresentationCurrency", WriteParameters.PresentationCurrency);
	
	Query.TempTablesManager = New TempTablesManager;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		POSSummaryRecords.Load(Result.Unload());
		POSSummaryRecords.Write();
	EndIf;
	
EndProcedure

Procedure WriteOfLandedCostsFromSoldOutProducts(Ref, StructureAdditionalProperties)
	
	DateEnd = StructureAdditionalProperties.ForPosting.EndDatePeriod;
	Company = StructureAdditionalProperties.ForPosting.Company;
	
	Query = New Query(
	"SELECT ALLOWED
	|	Balance.Company AS Company,
	|	Balance.PresentationCurrency AS PresentationCurrency,
	|	Balance.StructuralUnit AS StructuralUnit,
	|	Balance.InventoryAccountType AS InventoryAccountType,
	|	Balance.CostObject AS CostObject,
	|	Balance.CostLayer AS CostLayer,
	|	Balance.Products AS Products,
	|	Balance.Characteristic AS Characteristic,
	|	Balance.Batch AS Batch,
	|	Balance.Ownership AS Ownership
	|INTO CostLayerBalance
	|FROM
	|	AccumulationRegister.InventoryCostLayer.Balance(
	|			&Period,
	|			Company = &Company
	|				AND PresentationCurrency = &PresentationCurrency) AS Balance
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&EndOfMonth AS Period,
	|	Balance.Company AS Company,
	|	Balance.PresentationCurrency AS PresentationCurrency,
	|	Balance.StructuralUnit AS StructuralUnit,
	|	Balance.InventoryAccountType AS InventoryAccountType,
	|	Balance.CostObject AS CostObject,
	|	Balance.CostLayer AS CostLayer,
	|	Balance.Products AS Products,
	|	Balance.Characteristic AS Characteristic,
	|	Balance.Batch AS Batch,
	|	Balance.Ownership AS Ownership,
	|	Balance.AmountBalance AS Amount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CatalogLinesOfBusiness.GLAccountCostOfSales
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountCostOfSales,
	|	CatalogLinesOfBusiness.Ref AS BusinessLine
	|FROM
	|	AccumulationRegister.LandedCosts.Balance(
	|			&Period,
	|			Company = &Company
	|				AND PresentationCurrency = &PresentationCurrency) AS Balance
	|		LEFT JOIN CostLayerBalance AS CostLayerBalance
	|		ON Balance.Company = CostLayerBalance.Company
	|			AND Balance.PresentationCurrency = CostLayerBalance.PresentationCurrency
	|			AND Balance.StructuralUnit = CostLayerBalance.StructuralUnit
	|			AND Balance.InventoryAccountType = CostLayerBalance.InventoryAccountType
	|			AND Balance.CostObject = CostLayerBalance.CostObject
	|			AND Balance.CostLayer = CostLayerBalance.CostLayer
	|			AND Balance.Products = CostLayerBalance.Products
	|			AND Balance.Characteristic = CostLayerBalance.Characteristic
	|			AND Balance.Batch = CostLayerBalance.Batch
	|			AND Balance.Ownership = CostLayerBalance.Ownership
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON Balance.Products = CatalogProducts.Ref
	|		INNER JOIN Catalog.LinesOfBusiness AS CatalogLinesOfBusiness
	|		ON (CatalogProducts.BusinessLine = CatalogLinesOfBusiness.Ref)
	|WHERE
	|	CostLayerBalance.Company IS NULL");
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	EndOfMonth = EndOfMonth(DateEnd);
	Query.SetParameter("EndOfMonth", EndOfMonth);
	Query.SetParameter("Period", New Boundary(EndOfMonth, BoundaryType.Including));
	Query.SetParameter("Company", Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = Result.Select();
	
	RecordSetLandedCosts = AccumulationRegisters.LandedCosts.CreateRecordSet();
	RecordSetLandedCosts.Filter.Recorder.Set(Ref);
	
	TableIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses;
	
	While Selection.Next() Do
		
		LandedCostsRecord = RecordSetLandedCosts.Add();
		FillPropertyValues(LandedCostsRecord, Selection);
		
		IncomeAndExpensesRecord = TableIncomeAndExpenses.Add();
		FillPropertyValues(IncomeAndExpensesRecord, Selection);
		IncomeAndExpensesRecord.GLAccount = Selection.GLAccountCostOfSales;
		IncomeAndExpensesRecord.AmountExpense = Selection.Amount;
		IncomeAndExpensesRecord.Active = True;
	EndDo;
	
	If UseDefaultTypeOfAccounting Then
		
		TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
		
		WriteOffLandedCostsInAccounting(StructureAdditionalProperties, TableAccountingJournalEntries, Result.Unload(), EndOfMonth);
		
	EndIf;
	
	RecordSetLandedCosts.Write(True);
	
EndProcedure

Procedure WritetCostOfSubcontractorGoods(Ref, CostOfSubcontractorGoodsRecords, WriteParameters)
	
	Query = New Query(
	"SELECT
	|	OfflineRecords.Period AS Period,
	|	OfflineRecords.Company AS Company,
	|	OfflineRecords.PresentationCurrency AS PresentationCurrency,
	|	OfflineRecords.Products AS Products,
	|	OfflineRecords.Characteristic AS Characteristic,
	|	OfflineRecords.Quantity AS Quantity,
	|	OfflineRecords.Amount AS Amount,
	|	OfflineRecords.Counterparty AS Counterparty,
	|	OfflineRecords.SubcontractorOrder AS SubcontractorOrder,
	|	OfflineRecords.FinishedProducts AS FinishedProducts,
	|	OfflineRecords.FinishedProductsCharacteristic AS FinishedProductsCharacteristic,
	|	TRUE AS OfflineRecord
	|INTO OfflineRecords
	|FROM
	|	&RegisterRecords AS OfflineRecords
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OnlineRecords.Period AS Period,
	|	OnlineRecords.Company AS Company,
	|	OnlineRecords.PresentationCurrency AS PresentationCurrency,
	|	OnlineRecords.Products AS Products,
	|	OnlineRecords.Characteristic AS Characteristic,
	|	OnlineRecords.Quantity AS Quantity,
	|	OnlineRecords.Amount AS Amount,
	|	OnlineRecords.OfflineRecord AS OfflineRecord,
	|	OnlineRecords.Counterparty AS Counterparty,
	|	OnlineRecords.SubcontractorOrder AS SubcontractorOrder,
	|	OnlineRecords.FinishedProducts AS FinishedProducts,
	|	OnlineRecords.FinishedProductsCharacteristic AS FinishedProductsCharacteristic
	|FROM
	|	AccumulationRegister.CostOfSubcontractorGoods AS OnlineRecords
	|WHERE
	|	OnlineRecords.Recorder = &Ref
	|	AND OnlineRecords.Period BETWEEN &DateBeg AND &DateEnd
	|	AND OnlineRecords.Company = &Company
	|	AND OnlineRecords.PresentationCurrency = &PresentationCurrency
	|	AND NOT OnlineRecords.OfflineRecord
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.Amount,
	|	OfflineRecords.OfflineRecord,
	|	OfflineRecords.Counterparty,
	|	OfflineRecords.SubcontractorOrder,
	|	OfflineRecords.FinishedProducts,
	|	OfflineRecords.FinishedProductsCharacteristic
	|FROM
	|	OfflineRecords AS OfflineRecords");
	
	Query.SetParameter("RegisterRecords", CostOfSubcontractorGoodsRecords);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("DateBeg", WriteParameters.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd", WriteParameters.EndDatePeriod);
	Query.SetParameter("Company", WriteParameters.Company);
	Query.SetParameter("PresentationCurrency", WriteParameters.PresentationCurrency);
	
	Query.TempTablesManager = New TempTablesManager;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		CostOfSubcontractorGoodsRecords.Load(Result.Unload());
		CostOfSubcontractorGoodsRecords.Write();
	EndIf;
	
EndProcedure

// begin Drive.FullVersion
Procedure WriteWorkInProgressRegister(Ref, WorkInProgressRecords, WriteParameters)
	
	Query = New Query(
	"SELECT
	|	WIP.Period AS Period,
	|	WIP.RecordType AS RecordType,
	|	WIP.Company AS Company,
	|	WIP.PresentationCurrency AS PresentationCurrency,
	|	WIP.StructuralUnit AS StructuralUnit,
	|	WIP.CostObject AS CostObject,
	|	WIP.Products AS Products,
	|	WIP.Characteristic AS Characteristic,
	|	WIP.Quantity AS Quantity,
	|	WIP.Amount AS Amount,
	|	TRUE AS OfflineRecord
	|INTO NewRecords
	|FROM
	|	&RegisterRecords AS WIP
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OnlineRecords.Period AS Period,
	|	OnlineRecords.RecordType AS RecordType,
	|	OnlineRecords.Company AS Company,
	|	OnlineRecords.PresentationCurrency AS PresentationCurrency,
	|	OnlineRecords.StructuralUnit AS StructuralUnit,
	|	OnlineRecords.CostObject AS CostObject,
	|	OnlineRecords.Products AS Products,
	|	OnlineRecords.Characteristic AS Characteristic,
	|	OnlineRecords.Quantity AS Quantity,
	|	OnlineRecords.Amount AS Amount,
	|	OnlineRecords.OfflineRecord AS OfflineRecord
	|FROM
	|	AccumulationRegister.WorkInProgress AS OnlineRecords
	|WHERE
	|	OnlineRecords.Recorder = &Ref
	|	AND OnlineRecords.Period BETWEEN &DateBeg AND &DateEnd
	|	AND OnlineRecords.Company = &Company
	|	AND OnlineRecords.PresentationCurrency = &PresentationCurrency
	|	AND NOT OnlineRecords.OfflineRecord
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.CostObject,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.Amount,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	NewRecords AS OfflineRecords");
	
	Query.SetParameter("RegisterRecords", WorkInProgressRecords);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("DateBeg", WriteParameters.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd", WriteParameters.EndDatePeriod);
	Query.SetParameter("Company", WriteParameters.Company);
	Query.SetParameter("PresentationCurrency", WriteParameters.PresentationCurrency);
	
	Query.TempTablesManager = New TempTablesManager;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		WorkInProgressRecords.Load(Result.Unload());
		WorkInProgressRecords.Write();
	EndIf;
	
EndProcedure
// end Drive.FullVersion

// Procedure of hung amounts distribution without quantity (rounding errors while solving SLU).
//
//
Procedure DistributeAmountsWithoutQuantity(Ref, StructureAdditionalProperties, OperationKind, ErrorsTable)
	
	
	ListOfProcessedNodes = New Array();
	ListOfProcessedNodes.Add("");
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	DateEnd = StructureAdditionalProperties.ForPosting.EndDatePeriod;
	
	Query = New Query();
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT ALLOWED DISTINCT
	|	""DistributeAmountsWithoutQuantity"" AS Field1,
	|	AccountingCostBalance.Company AS Company,
	|	AccountingCostBalance.PresentationCurrency AS PresentationCurrency,
	|	AccountingCostBalance.StructuralUnit AS StructuralUnit,
	|	AccountingCostBalance.InventoryAccountType AS InventoryAccountType,
	|	CostAccountingExpenseRecordsRegister.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	CostAccountingExpenseRecordsRegister.GLAccount AS GLAccount,
	|	CostAccountingExpenseRecordsRegister.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	CostAccountingExpenseRecordsRegister.IncomeAndExpenseType AS IncomeAndExpenseType,
	|	CostAccountingExpenseRecordsRegister.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	AccountingCostBalance.Products AS Products,
	|	AccountingCostBalance.Characteristic AS Characteristic,
	|	AccountingCostBalance.Batch AS Batch,
	|	AccountingCostBalance.Ownership AS Ownership,
	|	AccountingCostBalance.CostObject AS CostObject,
	|	CASE
	|		WHEN AccountingCostBalance.QuantityBalance = 0
	|				AND CostAccountingExpenseRecordsRegister.Amount <> 0
	|				AND (AccountingCostBalance.AmountBalance BETWEEN -1 AND 1
	|					OR AccountingCostBalance.Products <> VALUE(Catalog.Products.EmptyRef))
	|			THEN AccountingCostBalance.AmountBalance
	|		ELSE 0
	|	END AS Amount,
	|	CostAccountingExpenseRecordsRegister.StructuralUnitCorr AS StructuralUnitCorr,
	|	UNDEFINED AS Specification,
	|	UNDEFINED AS SpecificationCorr,
	|	CostAccountingExpenseRecordsRegister.SalesOrder AS SalesOrder,
	|	CostAccountingExpenseRecordsRegister.CorrGLAccount AS CorrGLAccount,
	|	ISNULL(CostAccountingExpenseRecordsRegister.CorrIncomeAndExpenseType, UNDEFINED) AS CorrIncomeAndExpenseType,
	|	CostAccountingExpenseRecordsRegister.ProductsCorr AS ProductsCorr,
	|	CostAccountingExpenseRecordsRegister.CharacteristicCorr AS CharacteristicCorr,
	|	CostAccountingExpenseRecordsRegister.BatchCorr AS BatchCorr,
	|	CostAccountingExpenseRecordsRegister.OwnershipCorr AS OwnershipCorr,
	|	CostAccountingExpenseRecordsRegister.SourceDocument AS SourceDocument,
	|	CostAccountingExpenseRecordsRegister.Department AS Department,
	|	CostAccountingExpenseRecordsRegister.Responsible AS Responsible,
	|	CostAccountingExpenseRecordsRegister.VATRate AS VATRate,
	|	CostAccountingExpenseRecordsRegister.ProductionExpenses AS ProductionExpenses,
	|	CostAccountingExpenseRecordsRegister.ProductsProductsCategory AS ProductsProductsCategory,
	|	CostAccountingExpenseRecordsRegister.BusinessLineSales AS BusinessLineSales,
	|	CostAccountingExpenseRecordsRegister.ActivityDirectionWriteOff AS ActivityDirectionWriteOff,
	|	CostAccountingExpenseRecordsRegister.BusinessLineSalesGLAccountOfSalesCost AS BusinessLineSalesGLAccountOfSalesCost,
	|	WriteOffCostAdjustment.NodeNo AS NodeNo,
	|	CostAdjustmentsNodesWriteOffSource.NodeNo AS NumberNodeSource,
	|	CostAccountingExpenseRecordsRegister.GLAccountWriteOff AS GLAccountWriteOff,
	|	CostAccountingExpenseRecordsRegister.WriteOffIncomeAndExpenseType AS WriteOffIncomeAndExpenseType,
	|	CostAccountingExpenseRecordsRegister.StructuralUnitPayee AS StructuralUnitPayee,
	|	CostAccountingExpenseRecordsRegister.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	CostAccountingExpenseRecordsRegister.RetailStructuralUnit AS RetailStructuralUnit,
	|	CostAccountingExpenseRecordsRegister.Counterparty AS Counterparty,
	|	CostAccountingExpenseRecordsRegister.Currency AS Currency,
	|	CostAccountingExpenseRecordsRegister.CostObjectCorr AS CostObjectCorr,
	|	AccountingCostBalanceCorr.QuantityBalance AS QuantityBalance
	|FROM
	|	TableAccountingCostBalance AS AccountingCostBalance
	|		LEFT JOIN CostAccountingExpenseRecordsRegister AS CostAccountingExpenseRecordsRegister
	|			LEFT JOIN TableAccountingCostBalanceCorr AS AccountingCostBalanceCorr
	|			ON CostAccountingExpenseRecordsRegister.Company = AccountingCostBalanceCorr.Company
	|				AND CostAccountingExpenseRecordsRegister.PresentationCurrency = AccountingCostBalanceCorr.PresentationCurrency
	|				AND CostAccountingExpenseRecordsRegister.StructuralUnitCorr = AccountingCostBalanceCorr.StructuralUnit
	|				AND CostAccountingExpenseRecordsRegister.CorrInventoryAccountType = AccountingCostBalanceCorr.InventoryAccountType
	|				AND CostAccountingExpenseRecordsRegister.ProductsCorr = AccountingCostBalanceCorr.Products
	|				AND CostAccountingExpenseRecordsRegister.CharacteristicCorr = AccountingCostBalanceCorr.Characteristic
	|				AND CostAccountingExpenseRecordsRegister.BatchCorr = AccountingCostBalanceCorr.Batch
	|				AND CostAccountingExpenseRecordsRegister.Ownership = AccountingCostBalanceCorr.Ownership
	|				AND CostAccountingExpenseRecordsRegister.CostObject = AccountingCostBalanceCorr.CostObject
	|			LEFT JOIN InformationRegister.WriteOffCostAdjustment AS WriteOffCostAdjustment
	|			ON CostAccountingExpenseRecordsRegister.Company = WriteOffCostAdjustment.Company
	|				AND CostAccountingExpenseRecordsRegister.PresentationCurrency = WriteOffCostAdjustment.PresentationCurrency
	|				AND CostAccountingExpenseRecordsRegister.StructuralUnitCorr = WriteOffCostAdjustment.StructuralUnit
	|				AND CostAccountingExpenseRecordsRegister.CorrInventoryAccountType = WriteOffCostAdjustment.InventoryAccountType
	|				AND CostAccountingExpenseRecordsRegister.ProductsCorr = WriteOffCostAdjustment.Products
	|				AND CostAccountingExpenseRecordsRegister.CharacteristicCorr = WriteOffCostAdjustment.Characteristic
	|				AND CostAccountingExpenseRecordsRegister.BatchCorr = WriteOffCostAdjustment.Batch
	|				AND CostAccountingExpenseRecordsRegister.Ownership = WriteOffCostAdjustment.Ownership
	|				AND CostAccountingExpenseRecordsRegister.CostObject = WriteOffCostAdjustment.CostObject
	|				AND (WriteOffCostAdjustment.Recorder = &Recorder)
	|		ON AccountingCostBalance.Company = CostAccountingExpenseRecordsRegister.Company
	|			AND AccountingCostBalance.PresentationCurrency = CostAccountingExpenseRecordsRegister.PresentationCurrency
	|			AND AccountingCostBalance.StructuralUnit = CostAccountingExpenseRecordsRegister.StructuralUnit
	|			AND AccountingCostBalance.InventoryAccountType = CostAccountingExpenseRecordsRegister.InventoryAccountType
	|			AND AccountingCostBalance.Products = CostAccountingExpenseRecordsRegister.Products
	|			AND AccountingCostBalance.Characteristic = CostAccountingExpenseRecordsRegister.Characteristic
	|			AND AccountingCostBalance.Batch = CostAccountingExpenseRecordsRegister.Batch
	|			AND AccountingCostBalance.Ownership = CostAccountingExpenseRecordsRegister.Ownership
	|			AND AccountingCostBalance.CostObject = CostAccountingExpenseRecordsRegister.CostObject
	|		LEFT JOIN InformationRegister.WriteOffCostAdjustment AS CostAdjustmentsNodesWriteOffSource
	|		ON (CostAdjustmentsNodesWriteOffSource.Recorder = &Recorder)
	|			AND AccountingCostBalance.Company = CostAdjustmentsNodesWriteOffSource.Company
	|			AND AccountingCostBalance.PresentationCurrency = CostAdjustmentsNodesWriteOffSource.PresentationCurrency
	|			AND AccountingCostBalance.StructuralUnit = CostAdjustmentsNodesWriteOffSource.StructuralUnit
	|			AND AccountingCostBalance.InventoryAccountType = CostAdjustmentsNodesWriteOffSource.InventoryAccountType
	|			AND AccountingCostBalance.Products = CostAdjustmentsNodesWriteOffSource.Products
	|			AND AccountingCostBalance.Characteristic = CostAdjustmentsNodesWriteOffSource.Characteristic
	|			AND AccountingCostBalance.Batch = CostAdjustmentsNodesWriteOffSource.Batch
	|			AND AccountingCostBalance.Ownership = CostAdjustmentsNodesWriteOffSource.Ownership
	|			AND AccountingCostBalance.CostObject = CostAdjustmentsNodesWriteOffSource.CostObject
	|WHERE
	|	AccountingCostBalance.AmountBalance <> 0
	|	AND AccountingCostBalance.QuantityBalance = 0
	|	AND CostAccountingExpenseRecordsRegister.Amount <> 0
	|	AND (AccountingCostBalance.AmountBalance BETWEEN -1 AND 1
	|			OR AccountingCostBalance.Products <> VALUE(Catalog.Products.EmptyRef))
	|	AND AccountingCostBalance.AmountBalance <> 0
	|	AND NOT CostAccountingExpenseRecordsRegister.IncomeAndExpenseItem IS NULL
	|	AND NOT ISNULL(CostAdjustmentsNodesWriteOffSource.NodeNo, 0) = ISNULL(WriteOffCostAdjustment.NodeNo, 0)
	|
	|ORDER BY
	|	QuantityBalance DESC,
	|	CASE
	|		WHEN WriteOffCostAdjustment.NodeNo IN (&ListOfProcessedNodes)
	|			THEN 0
	|		ELSE 1
	|	END DESC";

	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	Query.SetParameter("BoundaryDateEnd", New Boundary(DateEnd, BoundaryType.Including));
	Query.SetParameter("Recorder", Ref);
	Query.SetParameter("ListOfProcessedNodes", ListOfProcessedNodes);
	
	TableWorkInProgress = Undefined;
	// begin Drive.FullVersion
	TableWorkInProgress = StructureAdditionalProperties.TableForRegisterRecords.TableWorkInProgress;
	// end Drive.FullVersion
	
	TableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory;
	TableSales = StructureAdditionalProperties.TableForRegisterRecords.TableSales;
	
	TableIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses;
	
	TablePOSSummary = StructureAdditionalProperties.TableForRegisterRecords.TablePOSSummary;
	
	If UseDefaultTypeOfAccounting Then 
		TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
	EndIf;
	
	IterationsQuantity = 0;
	
	Result = Query.Execute();
	While Not Result.IsEmpty() Do
		
		IterationsQuantity = IterationsQuantity + 1;
		If IterationsQuantity > 60 Then
			ErrorDescription = NStr("en = 'Cannot adjust cost balance values.'; ru = 'Не удалось скорректировать суммовые остатки по затратам.';pl = 'Nie można skorygować wartości salda kosztów.';es_ES = 'No se puede modificar los valores del saldo de costes.';es_CO = 'No se puede modificar los valores del saldo de costes.';tr = 'Maliyet bakiyesi değerleri ayarlanamaz.';it = 'Non è possibile regolare i valori di bilancio del costo.';de = 'Kostenausgleichswerte können nicht angepasst werden.'");
			AddErrorIntoTable(Ref,ErrorDescription, OperationKind, ErrorsTable);
			Break;
		EndIf;
	SelectionDetailRecords = Result.Select();
	ListOfNodesProcessedSources = New Array();
	
	While SelectionDetailRecords.Next() Do
		
		If ListOfNodesProcessedSources.Find(SelectionDetailRecords.NumberNodeSource) = Undefined Then
			ListOfNodesProcessedSources.Add(SelectionDetailRecords.NumberNodeSource);
		Else
			Continue; // This source is already corrected.
		EndIf;
		
		If ListOfProcessedNodes.Find(SelectionDetailRecords.NodeNo) = Undefined Then
			ListOfProcessedNodes.Add(SelectionDetailRecords.NodeNo);
		EndIf;
		
		CorrectionAmount = SelectionDetailRecords.Amount;
		
		ParametersForRecords = ParametersForRecordsByExpensesRegister();
		GenerateRegisterRecordsByExpensesRegister(
			Ref,
			TableInventory,
			TableWorkInProgress,
			TableAccountingJournalEntries,
			SelectionDetailRecords,
			CorrectionAmount,
			False,
			ParametersForRecords);
		
		If SelectionDetailRecords.CorrIncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.CostOfSales Then
			
			If ValueIsFilled(SelectionDetailRecords.SourceDocument)
				And ((TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.SalesInvoice")
				And SelectionDetailRecords.WriteOffIncomeAndExpenseType <> Catalogs.IncomeAndExpenseTypes.OtherIncome)
				Or TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.ShiftClosure")
				Or TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.AccountSalesFromConsignee")
				Or TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.SalesOrder")) Then
				
				// Movements on the register Sales.
				NewRow = TableSales.Add();
				NewRow.Period				= Ref.Date;
				NewRow.Recorder				= Ref;
				NewRow.Company				= SelectionDetailRecords.Company;
				NewRow.PresentationCurrency	= SelectionDetailRecords.PresentationCurrency;
				NewRow.Counterparty			= SelectionDetailRecords.Counterparty;
				NewRow.Currency				= SelectionDetailRecords.Currency;
				NewRow.SalesOrder			= SelectionDetailRecords.SalesOrder;
				NewRow.Department			= SelectionDetailRecords.Department;
				NewRow.Responsible			= SelectionDetailRecords.Responsible;
				NewRow.Products				= SelectionDetailRecords.Products;
				NewRow.Characteristic		= SelectionDetailRecords.Characteristic;
				NewRow.Batch				= SelectionDetailRecords.Batch;
				NewRow.Ownership			= SelectionDetailRecords.Ownership;
				NewRow.Document				= SelectionDetailRecords.SourceDocument;
				NewRow.VATRate				= SelectionDetailRecords.VATRate;
				NewRow.Cost					= CorrectionAmount;
				NewRow.Active               = True;
				
				// Movements on the register IncomeAndExpenses.
				NewRow = TableIncomeAndExpenses.Add();
				NewRow.Period				= Ref.Date;
				NewRow.Recorder				= Ref;
				NewRow.Company				= SelectionDetailRecords.Company;
				NewRow.PresentationCurrency	= SelectionDetailRecords.PresentationCurrency;
				NewRow.StructuralUnit		= SelectionDetailRecords.Department;
				NewRow.SalesOrder			= SelectionDetailRecords.SalesOrder;
				If Not ValueIsFilled(NewRow.SalesOrder) Then
					NewRow.SalesOrder = Undefined;
				EndIf;
				NewRow.BusinessLine					= SelectionDetailRecords.BusinessLineSales;
				NewRow.GLAccount					= SelectionDetailRecords.BusinessLineSalesGLAccountOfSalesCost;
				NewRow.IncomeAndExpenseItem			= SelectionDetailRecords.CorrIncomeAndExpenseItem;
				NewRow.AmountExpense				= CorrectionAmount;
				NewRow.ContentOfAccountingRecord	= NStr("en = 'Record expenses'; ru = 'Отражение расходов';pl = 'Rejestr rozchodów';es_ES = 'Registrar los gastos';es_CO = 'Registrar los gastos';tr = 'Masrafların yansıtılması';it = 'Registrazione spese';de = 'Ausgaben buchen'", DefaultLanguageCode);
				NewRow.Active						= True;
				
			EndIf;
			
		ElsIf SelectionDetailRecords.CorrInventoryAccountType = StructureAdditionalProperties.ForPosting.EmptyInventoryAccountType Then
			
			If ValueIsFilled(SelectionDetailRecords.SourceDocument)
				And (TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.SalesInvoice")
				Or TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.ShiftClosure")
				Or TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.AccountSalesFromConsignee")
				Or TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.SalesOrder")) Then
				
				// Movements on the register Sales.
				NewRow = TableSales.Add();
				NewRow.Period				= Ref.Date;
				NewRow.Recorder				= Ref;
				NewRow.Company				= SelectionDetailRecords.Company;
				NewRow.PresentationCurrency = SelectionDetailRecords.PresentationCurrency;
				NewRow.Counterparty			= SelectionDetailRecords.Counterparty;
				NewRow.Currency				= SelectionDetailRecords.Currency;
				NewRow.SalesOrder			= SelectionDetailRecords.SalesOrder;
				NewRow.Department			= SelectionDetailRecords.Department;
				NewRow.Responsible			= SelectionDetailRecords.Responsible;
				NewRow.Products				= SelectionDetailRecords.Products;
				NewRow.Characteristic		= SelectionDetailRecords.Characteristic;
				NewRow.Batch				= SelectionDetailRecords.Batch;
				NewRow.Ownership			= SelectionDetailRecords.Ownership;
				NewRow.Document				= SelectionDetailRecords.SourceDocument;
				NewRow.VATRate				= SelectionDetailRecords.VATRate;
				NewRow.Cost					= CorrectionAmount;
				NewRow.Active				= True;
				
				// Movements on the register IncomeAndExpenses.
				NewRow = TableIncomeAndExpenses.Add();
				NewRow.Period						= Ref.Date;
				NewRow.Recorder						= Ref;
				NewRow.Company						= SelectionDetailRecords.Company;
				NewRow.PresentationCurrency  		= SelectionDetailRecords.PresentationCurrency;
				NewRow.StructuralUnit				= SelectionDetailRecords.Department;
				NewRow.SalesOrder					= SelectionDetailRecords.SalesOrder;
				If Not ValueIsFilled(NewRow.SalesOrder) Then
					NewRow.SalesOrder = Undefined;
				EndIf;
				NewRow.Active						= True;
				NewRow.BusinessLine					= SelectionDetailRecords.BusinessLineSales;
				NewRow.GLAccount					= SelectionDetailRecords.BusinessLineSalesGLAccountOfSalesCost;
				NewRow.IncomeAndExpenseItem			= SelectionDetailRecords.CorrIncomeAndExpenseItem;
				NewRow.AmountExpense				= CorrectionAmount;
				NewRow.ContentOfAccountingRecord	= NStr("en = 'Record sale expenses'; ru = 'Отражение расходов по продаже';pl = 'Rejestr kosztów sprzedaży';es_ES = 'Grabar los gastos de ventas';es_CO = 'Grabar los gastos de ventas';tr = 'Satış masrafları kayıtları';it = 'Spese registrazioni di vendita';de = 'Verkaufsausgaben buchen'", DefaultLanguageCode);
				
				// Movements by register AccountingJournalEntries.
				If UseDefaultTypeOfAccounting Then
					
					NewRow = TableAccountingJournalEntries.Add();
					NewRow.Active			= True;
					NewRow.Period			= Ref.Date;
					NewRow.Recorder			= Ref;
					NewRow.Company			= SelectionDetailRecords.Company;
					NewRow.PlanningPeriod	= Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr		= SelectionDetailRecords.BusinessLineSalesGLAccountOfSalesCost;
					NewRow.AccountCr		= SelectionDetailRecords.GLAccount;
					NewRow.Content			= NStr("en = 'Record sale expenses'; ru = 'Отражение расходов по продаже';pl = 'Rejestr kosztów sprzedaży';es_ES = 'Grabar los gastos de ventas';es_CO = 'Grabar los gastos de ventas';tr = 'Satış masrafları kayıtları';it = 'Spese registrazioni di vendita';de = 'Verkaufsausgaben buchen'", DefaultLanguageCode);
					NewRow.Amount			= CorrectionAmount;
					
				EndIf;
				
			ElsIf SelectionDetailRecords.RetailTransferEarningAccounting Then
				
				// Movements on the register POSSummary.
				NewRow = TablePOSSummary.Add();
				NewRow.Period 				= Ref.Date;
				NewRow.RecordType 			= AccumulationRecordType.Receipt;
				NewRow.Recorder 			= Ref;
				NewRow.Company 				= SelectionDetailRecords.Company;
				NewRow.PresentationCurrency	= SelectionDetailRecords.PresentationCurrency;
				NewRow.StructuralUnit 		= SelectionDetailRecords.RetailStructuralUnit;
				NewRow.Currency 			= SelectionDetailRecords.RetailStructuralUnit.RetailPriceKind.PriceCurrency;
				NewRow.ContentOfAccountingRecord = NStr("en = 'Move to retail'; ru = 'Перемещение в розницу';pl = 'Przeniesienie do sprzedaży detalicznej';es_ES = 'Mover a la venta al por menor';es_CO = 'Mover a la venta al por menor';tr = 'Perakendeye geç';it = 'Spostare alla vendita al dettaglio';de = 'In den Einzelhandel wechseln'", DefaultLanguageCode);
				NewRow.Cost 				= CorrectionAmount;
				NewRow.Active 				= True;
				
				// Movements by register AccountingJournalEntries.
				If UseDefaultTypeOfAccounting Then
					
					NewRow = TableAccountingJournalEntries.Add();
					NewRow.Active			= True;
					NewRow.Period 			= Ref.Date;
					NewRow.Recorder 		= Ref;
					NewRow.Company 			= SelectionDetailRecords.Company;
					NewRow.PlanningPeriod 	= Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr 		= SelectionDetailRecords.RetailStructuralUnit.GLAccountInRetail;
					NewRow.AccountCr 		= SelectionDetailRecords.GLAccount;
					NewRow.Content 			= NStr("en = 'Move to retail'; ru = 'Перемещение в розницу';pl = 'Przeniesienie do sprzedaży detalicznej';es_ES = 'Mover a la venta al por menor';es_CO = 'Mover a la venta al por menor';tr = 'Perakendeye geç';it = 'Spostare alla vendita al dettaglio';de = 'In den Einzelhandel wechseln'", DefaultLanguageCode);
					NewRow.Amount 			= CorrectionAmount;
					
				EndIf;
				
			ElsIf SelectionDetailRecords.WriteOffIncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.OtherExpenses
				Or SelectionDetailRecords.WriteOffIncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses Then
				
				// Movements on the register Income and expenses.
				NewRow = TableIncomeAndExpenses.Add();
				NewRow.Period 				= StructureAdditionalProperties.ForPosting.Date;
				NewRow.Recorder 			= Ref;
				NewRow.Company 				= SelectionDetailRecords.Company;
				NewRow.PresentationCurrency = SelectionDetailRecords.PresentationCurrency;
				NewRow.StructuralUnit 		= SelectionDetailRecords.StructuralUnitPayee;
				NewRow.Active = True;
				
				If TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.InventoryTransfer")
					And SelectionDetailRecords.WriteOffIncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses Then
					
					NewRow.BusinessLine = SelectionDetailRecords.ActivityDirectionWriteOff;
					NewRow.SalesOrder = SelectionDetailRecords.SalesOrder;
					If Not ValueIsFilled(NewRow.SalesOrder) Then
						NewRow.SalesOrder = Undefined;
					EndIf;
					
				Else
					NewRow.BusinessLine = Catalogs.LinesOfBusiness.Other;
				EndIf;
				
				NewRow.IncomeAndExpenseItem = SelectionDetailRecords.CorrIncomeAndExpenseItem;
				NewRow.GLAccount = SelectionDetailRecords.GLAccountWriteOff;
				NewRow.AmountExpense = CorrectionAmount;
				NewRow.ContentOfAccountingRecord = NStr("en = 'Other expenses'; ru = 'Прочие затраты (расходы)';pl = 'Inne rozchody';es_ES = 'Otros gastos';es_CO = 'Otros gastos';tr = 'Diğer masraflar';it = 'Altre spese';de = 'Sonstige Ausgaben'", DefaultLanguageCode);
				
				// Movements by register AccountingJournalEntries.
				If UseDefaultTypeOfAccounting Then
					
					NewRow = TableAccountingJournalEntries.Add();
					NewRow.Active			= True;
					NewRow.Period 			= Ref.Date;
					NewRow.Recorder 		= Ref;
					NewRow.Company 			= SelectionDetailRecords.Company;
					NewRow.PlanningPeriod 	= Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr 		= SelectionDetailRecords.GLAccountWriteOff;
					NewRow.AccountCr 		= SelectionDetailRecords.GLAccount;
					NewRow.Content 			= NStr("en = 'Other expenses'; ru = 'Прочие затраты (расходы)';pl = 'Inne rozchody';es_ES = 'Otros gastos';es_CO = 'Otros gastos';tr = 'Diğer masraflar';it = 'Altre spese';de = 'Sonstige Ausgaben'", DefaultLanguageCode);
					NewRow.Amount 			= CorrectionAmount;
					
				EndIf;
				
			ElsIf UseDefaultTypeOfAccounting Then
				
				// Movements by register AccountingJournalEntries.
				NewRow = TableAccountingJournalEntries.Add();
				NewRow.Active			= True;
				NewRow.Period 			= Ref.Date;
				NewRow.Recorder 		= Ref;
				NewRow.Company 			= SelectionDetailRecords.Company;
				NewRow.PlanningPeriod 	= Catalogs.PlanningPeriods.Actual;
				NewRow.AccountDr 		= SelectionDetailRecords.GLAccountWriteOff;
				NewRow.AccountCr 		= SelectionDetailRecords.GLAccount;
				NewRow.Content 			= NStr("en = 'Inventory write-off to arbitrary account'; ru = 'Списание запасов на произвольный счет';pl = 'Spisanie zapasów na dowolny rachunek';es_ES = 'Amortización del inventario a la cuenta arbitraria';es_CO = 'Amortización del inventario a la cuenta arbitraria';tr = 'Stokların serbest hesaplara aktarılarak silinmesi';it = 'Cancellazione di scorte a un conto arbitrario';de = 'Bestandsabschreibung für ein beliebiges Konto'", DefaultLanguageCode);
				NewRow.Amount 			= CorrectionAmount;
				
			EndIf;
			
		EndIf;
	EndDo;
	
	If IterationsQuantity = 15 OR IterationsQuantity = 30 OR IterationsQuantity = 45 Then
		// Clear processed nodes list.
		ListOfProcessedNodes.Clear();
		ListOfProcessedNodes.Add("");
	EndIf;
	
	Query.SetParameter("ListOfProcessedNodes", ListOfProcessedNodes);
	
	GeneratTableDistributeAmountsWithoutQuantity(Ref,StructureAdditionalProperties);
	Result = Query.Execute();
	
EndDo;
	
	Query.Text = "DROP CostAccountingExpenseRecordsRegister";
	Query.Execute();
	
	TemporaryConvertTable(TableInventory, "TableInventory", StructureAdditionalProperties);
	
EndProcedure

Procedure WriteCorrectiveRecordsInInventory(Ref, StructureAdditionalProperties)
	
	Query = New Query(
	"SELECT ALLOWED
	|	Inventory.Company AS Company,
	|	Inventory.PresentationCurrency AS PresentationCurrency,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.InventoryAccountType AS InventoryAccountType,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.Ownership AS Ownership,
	|	Inventory.QuantityBalance AS Quantity,
	|	Inventory.AmountBalance AS Amount
	|INTO InventoryCostLayerBalance
	|FROM
	|	AccumulationRegister.InventoryCostLayer.Balance(
	|			&AtBoundary,
	|			Company = &Company
	|				AND PresentationCurrency = &PresentationCurrency) AS Inventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Filter.Company AS Company,
	|	Filter.PresentationCurrency AS PresentationCurrency,
	|	Filter.StructuralUnit AS StructuralUnit,
	|	Filter.InventoryAccountType AS InventoryAccountType,
	|	Filter.Products AS Products,
	|	Filter.Characteristic AS Characteristic,
	|	Filter.Batch AS Batch,
	|	Filter.Ownership AS Ownership
	|INTO BalanceFilter
	|FROM
	|	InventoryCostLayerBalance AS Filter
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&BeginOfMonth AS Period,
	|	InventoryCostLayer.Company AS Company,
	|	InventoryCostLayer.PresentationCurrency AS PresentationCurrency,
	|	InventoryCostLayer.StructuralUnit AS StructuralUnit,
	|	InventoryCostLayer.InventoryAccountType AS InventoryAccountType,
	|	InventoryCostLayer.Products AS Products,
	|	InventoryCostLayer.Characteristic AS Characteristic,
	|	InventoryCostLayer.Batch AS Batch,
	|	InventoryCostLayer.Ownership AS Ownership,
	|	0 AS Quantity,
	|	InventoryCostLayer.AmountBalance AS Amount
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			&AtBoundary,
	|			(Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership) IN
	|				(SELECT
	|					Filter.Company AS Company,
	|					Filter.PresentationCurrency AS PresentationCurrency,
	|					Filter.StructuralUnit AS StructuralUnit,
	|					Filter.InventoryAccountType AS InventoryAccountType,
	|					Filter.Products AS Products,
	|					Filter.Characteristic AS Characteristic,
	|					Filter.Batch AS Batch,
	|					Filter.Ownership AS Ownership
	|				FROM
	|					BalanceFilter AS Filter)) AS InventoryCostLayer
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	&BeginOfMonth,
	|	Inventory.Company,
	|	Inventory.PresentationCurrency,
	|	Inventory.StructuralUnit,
	|	Inventory.InventoryAccountType,
	|	Inventory.Products,
	|	Inventory.Characteristic,
	|	Inventory.Batch,
	|	Inventory.Ownership,
	|	0,
	|	Inventory.Amount
	|FROM
	|	InventoryCostLayerBalance AS Inventory");
	
	BeginOfMonth = BegOfMonth(Ref.Date);
	Query.SetParameter("BeginOfMonth", BeginOfMonth);
	Query.SetParameter("AtBoundary", New Boundary(BeginOfMonth, BoundaryType.Excluding));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	
	Result = Query.Execute();
	
	TableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory;
	TableInventory = Result.Unload();
	
EndProcedure

// Corrects expenses accounting writeoff.
//
// Parameters:
//  Cancel        - Boolean - check box of document posting canceling.
//
Procedure WriteOffCorrectionAccountingCost(Ref, StructureAdditionalProperties, OperationKind, InventoryValuationMethod,  ErrorsTable)
	
	If InventoryValuationMethod = Enums.InventoryValuationMethods.FIFO Then
		
		PreviousMonth = AddMonth(EndOfMonth(Ref.Date), -1);
		If ThereAreRecordsInPreviousPeriods(PreviousMonth, Ref.Company) Then
			PreviousInventoryValuationMethod = InformationRegisters.AccountingPolicy.InventoryValuationMethod(PreviousMonth, Ref.Company);
			If PreviousInventoryValuationMethod <> InventoryValuationMethod
				And PreviousInventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage Then
				WriteCorrectiveRecordsInInventory(Ref, StructureAdditionalProperties);
			EndIf;
		EndIf;
		
		GenerateCorrectiveRegisterRecordsByFIFO(StructureAdditionalProperties);
		WriteOfLandedCostsFromSoldOutProducts(Ref, StructureAdditionalProperties);
		
	Else
		CountEquationsSLE = MakeRegisterRecordsByRegisterWriteOffCostAdjustment(Ref, StructureAdditionalProperties);
		If CountEquationsSLE > 0 Then
			
			SolutionIsFound = SolveLES(Ref, StructureAdditionalProperties);
			
			If Not SolutionIsFound Then
				Return;
			EndIf;
			GenerateCorrectiveRegisterRecordsByExpensesRegister(Ref, StructureAdditionalProperties);
			
			GeneratTableDistributeAmountsWithoutQuantity(Ref, StructureAdditionalProperties);
			
			DistributeAmountsWithoutQuantity(Ref, StructureAdditionalProperties, OperationKind, ErrorsTable);
		Else
			
			Query = New Query(
			"SELECT
			|	&ErrorText
			|INTO CostAccounting
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	&ErrorText
			|INTO CostAccountingReturnsCurPeriod
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	&ErrorText
			|INTO CostAccountingWriteOff
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	&ErrorText
			|INTO CostAccountingReturnsFree
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	&ErrorText
			|INTO CostAccountingReturns
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	&ErrorText
			|INTO CostAccountingWithoutReturnAccounting
			|");
			
			Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
			Query.SetParameter("ErrorText", NStr("en = 'There are no equations'; ru = 'Равенства отсутствуют';pl = 'Brak równań';es_ES = 'No hay ecuaciones';es_CO = 'No hay ecuaciones';tr = 'Denklem yok';it = 'Non ci sono equazioni';de = 'Es gibt keine Gleichungen'", CommonClientServer.DefaultLanguageCode()));
			Query.Execute();
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CalculateCostOfReturns(Ref, StructureAdditionalProperties)
	
	TemporaryConvertTable(StructureAdditionalProperties.TableForRegisterRecords.TableInventory, "TableInventory", StructureAdditionalProperties);
	TemporaryConvertTable(Undefined, "TtReturns", StructureAdditionalProperties);
	TemporaryConvertTable(Undefined, "GroupSales", StructureAdditionalProperties);

	Query = New Query();
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT ALLOWED
	|	Inventory.Period AS Period,
	|	Inventory.Company AS Company,
	|	Inventory.PresentationCurrency AS PresentationCurrency,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.InventoryAccountType AS InventoryAccountType,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.Ownership AS Ownership,
	|	Inventory.SalesOrder AS SalesOrder,
	|	Inventory.VATRate AS VATRate,
	|	Inventory.SourceDocument AS SourceDocument,
	|	Inventory.Department AS Department,
	|	Inventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	Inventory.Responsible AS Responsible,
	|	CASE
	|		WHEN ENDOFPERIOD(Inventory.SourceDocument.Date, MONTH) < ENDOFPERIOD(Inventory.Period, MONTH)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ItsReturnOfLastPeriod,
	|	SUM(Inventory.Quantity) AS Quantity,
	|	SUM(Inventory.Amount) AS Amount,
	|	Inventory.Counterparty AS Counterparty,
	|	Inventory.Currency AS Currency,
	|	Inventory.CostObject AS CostObject,
	|	Inventory.CostObjectCorr AS CostObjectCorr
	|INTO TtReturns
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Inventory.Return
	|	AND Inventory.Company = &Company
	|	AND Inventory.PresentationCurrency = &PresentationCurrency
	|	AND Inventory.CorrInventoryAccountType = VALUE(Enum.InventoryAccountTypes.EmptyRef)
	|	AND Inventory.SourceDocument <> UNDEFINED
	|
	|GROUP BY
	|	Inventory.Period,
	|	CASE
	|		WHEN ENDOFPERIOD(Inventory.SourceDocument.Date, MONTH) < ENDOFPERIOD(Inventory.Period, MONTH)
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	Inventory.Company,
	|	Inventory.PresentationCurrency,
	|	Inventory.StructuralUnit,
	|	Inventory.GLAccount,
	|	Inventory.InventoryAccountType,
	|	Inventory.Products,
	|	Inventory.Characteristic,
	|	Inventory.Batch,
	|	Inventory.Ownership,
	|	Inventory.SalesOrder,
	|	Inventory.VATRate,
	|	Inventory.SourceDocument,
	|	Inventory.Department,
	|	Inventory.CorrInventoryAccountType,
	|	Inventory.Responsible,
	|	Inventory.Counterparty,
	|	Inventory.Currency,
	|	Inventory.CostObject,
	|	Inventory.CostObjectCorr
	|
	|UNION ALL
	|
	|SELECT
	|	Inventory.Period,
	|	Inventory.Company,
	|	Inventory.PresentationCurrency,
	|	Inventory.StructuralUnit,
	|	Inventory.InventoryAccountType,
	|	Inventory.GLAccount,
	|	Inventory.Products,
	|	Inventory.Characteristic,
	|	Inventory.Batch,
	|	Inventory.Ownership,
	|	Inventory.SalesOrder,
	|	Inventory.VATRate,
	|	Inventory.SourceDocument,
	|	Inventory.Department,
	|	Inventory.CorrInventoryAccountType,
	|	Inventory.Responsible,
	|	CASE
	|		WHEN ENDOFPERIOD(Inventory.SourceDocument.Date, MONTH) < ENDOFPERIOD(Inventory.Period, MONTH)
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	SUM(Inventory.Quantity),
	|	SUM(Inventory.Amount),
	|	Inventory.Counterparty,
	|	Inventory.Currency,
	|	Inventory.CostObject,
	|	Inventory.CostObjectCorr
	|FROM
	|	TableInventory AS Inventory
	|WHERE
	|	Inventory.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Inventory.Return
	|	AND Inventory.Company = &Company
	|	AND Inventory.PresentationCurrency = &PresentationCurrency
	|	AND Inventory.CorrInventoryAccountType = VALUE(Enum.InventoryAccountTypes.EmptyRef)
	|	AND Inventory.SourceDocument <> UNDEFINED
	|
	|GROUP BY
	|	Inventory.Period,
	|	CASE
	|		WHEN ENDOFPERIOD(Inventory.SourceDocument.Date, MONTH) < ENDOFPERIOD(Inventory.Period, MONTH)
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	Inventory.Company,
	|	Inventory.PresentationCurrency,
	|	Inventory.StructuralUnit,
	|	Inventory.GLAccount,
	|	Inventory.InventoryAccountType,
	|	Inventory.Products,
	|	Inventory.Characteristic,
	|	Inventory.Batch,
	|	Inventory.Ownership,
	|	Inventory.SalesOrder,
	|	Inventory.VATRate,
	|	Inventory.SourceDocument,
	|	Inventory.Department,
	|	Inventory.CorrInventoryAccountType,
	|	Inventory.Responsible,
	|	Inventory.Counterparty,
	|	Inventory.Currency,
	|	Inventory.CostObject,
	|	Inventory.CostObjectCorr
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SUM(TableSales.Quantity) AS SalesQuantity,
	|	SUM(TableSales.Amount) AS SalesAmount,
	|	TableSales.Company AS Company1,
	|	TableSales.PresentationCurrency AS PresentationCurrency,
	|	TableSales.InventoryAccountType AS InventoryAccountType,
	|	TableSales.Products AS Products,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Batch AS Batch,
	|	TableSales.Ownership AS Ownership,
	|	TableSales.SourceDocument AS SourceDocument,
	|	TableSales.SalesOrder AS SalesOrder,
	|	TableSales.VATRate AS VATRate
	|INTO GroupSales
	|FROM
	|	AccumulationRegister.Inventory AS TableSales
	|WHERE
	|	TableSales.CorrInventoryAccountType = VALUE(Enum.InventoryAccountTypes.EmptyRef)
	|	AND TableSales.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND NOT TableSales.Recorder REFS Document.MonthEndClosing
	|	AND NOT TableSales.Return
	|	AND TableSales.Company = &Company
	|	AND TableSales.PresentationCurrency = &PresentationCurrency
	|
	|GROUP BY
	|	TableSales.InventoryAccountType,
	|	TableSales.Ownership,
	|	TableSales.SalesOrder,
	|	TableSales.VATRate,
	|	TableSales.Products,
	|	TableSales.Batch,
	|	TableSales.Characteristic,
	|	TableSales.SourceDocument,
	|	TableSales.Company,
	|	TableSales.PresentationCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	SUM(TableSales.Quantity),
	|	SUM(TableSales.Amount),
	|	TableSales.Company,
	|	TableSales.PresentationCurrency,
	|	TableSales.InventoryAccountType,
	|	TableSales.Products,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	TableSales.Ownership,
	|	TableSales.SourceDocument,
	|	TableSales.SalesOrder,
	|	TableSales.VATRate
	|FROM
	|	TableInventory AS TableSales
	|WHERE
	|	TableSales.CorrInventoryAccountType = VALUE(Enum.InventoryAccountTypes.EmptyRef)
	|	AND TableSales.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND NOT TableSales.Recorder REFS Document.MonthEndClosing
	|	AND NOT TableSales.Return
	|	AND TableSales.Company = &Company
	|	AND TableSales.PresentationCurrency = &PresentationCurrency
	|
	|GROUP BY
	|	TableSales.InventoryAccountType,
	|	TableSales.Ownership,
	|	TableSales.SalesOrder,
	|	TableSales.VATRate,
	|	TableSales.Products,
	|	TableSales.Batch,
	|	TableSales.Characteristic,
	|	TableSales.SourceDocument,
	|	TableSales.Company,
	|	TableSales.PresentationCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ReturnsTable.Period AS Period,
	|	TRUE AS Return,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	ReturnsTable.StructuralUnit AS StructuralUnit,
	|	ReturnsTable.InventoryAccountType AS InventoryAccountType,
	|	ReturnsTable.GLAccount AS GLAccount,
	|	ReturnsTable.Products AS Products,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ReturnsTable.Products.BusinessLine
	|		ELSE VALUE(Catalog.LinesOfBusiness.MainLine)
	|	END AS BusinessLineSales,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ReturnsTable.Products.BusinessLine.GLAccountCostOfSales
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS BusinessLineSalesGLAccountOfSalesCost,
	|	ReturnsTable.Characteristic AS Characteristic,
	|	ReturnsTable.Batch AS Batch,
	|	ReturnsTable.Ownership AS Ownership,
	|	ReturnsTable.SalesOrder AS SalesOrder,
	|	ReturnsTable.Quantity AS ReturnQuantity,
	|	ReturnsTable.Amount AS AmountOfRefunds,
	|	ReturnsTable.SourceDocument AS SourceDocument,
	|	ReturnsTable.Department AS Department,
	|	ReturnsTable.VATRate AS VATRate,
	|	ReturnsTable.Responsible AS Responsible,
	|	ReturnsTable.ItsReturnOfLastPeriod AS ItsReturnOfLastPeriod,
	|	ReturnsTable.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	SUM(TableSales.SalesQuantity) AS Quantity,
	|	SUM(TableSales.SalesAmount) AS Amount,
	|	ReturnsTable.Counterparty AS Counterparty,
	|	ReturnsTable.Currency AS Currency,
	|	ReturnsTable.CostObject AS CostObject,
	|	ReturnsTable.CostObjectCorr AS CostObjectCorr
	|FROM
	|	TtReturns AS ReturnsTable
	|		LEFT JOIN GroupSales AS TableSales
	|		ON ReturnsTable.InventoryAccountType = TableSales.InventoryAccountType
	|			AND ReturnsTable.Products = TableSales.Products
	|			AND ReturnsTable.Characteristic = TableSales.Characteristic
	|			AND ReturnsTable.Batch = TableSales.Batch
	|			AND ReturnsTable.Ownership = TableSales.Ownership
	|			AND ReturnsTable.SalesOrder = TableSales.SalesOrder
	|			AND ReturnsTable.SourceDocument = TableSales.SourceDocument
	|			AND ReturnsTable.VATRate = TableSales.VATRate
	|
	|GROUP BY
	|	ReturnsTable.Period,
	|	ReturnsTable.StructuralUnit,
	|	ReturnsTable.InventoryAccountType,
	|	ReturnsTable.GLAccount,
	|	ReturnsTable.Products,
	|	ReturnsTable.Characteristic,
	|	ReturnsTable.Batch,
	|	ReturnsTable.Ownership,
	|	ReturnsTable.SalesOrder,
	|	ReturnsTable.Quantity,
	|	ReturnsTable.Amount,
	|	ReturnsTable.SourceDocument,
	|	ReturnsTable.Department,
	|	ReturnsTable.VATRate,
	|	ReturnsTable.Responsible,
	|	ReturnsTable.ItsReturnOfLastPeriod,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ReturnsTable.Products.BusinessLine
	|		ELSE VALUE(Catalog.LinesOfBusiness.MainLine)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ReturnsTable.Products.BusinessLine.GLAccountCostOfSales
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	ReturnsTable.CorrInventoryAccountType,
	|	ReturnsTable.Counterparty,
	|	ReturnsTable.Currency,
	|	ReturnsTable.CostObject,
	|	ReturnsTable.CostObjectCorr
	|
	|HAVING
	|	(CAST(SUM(TableSales.SalesAmount) - ReturnsTable.Amount AS NUMBER(15, 2))) <> 0";
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("BeginOfPeriod", StructureAdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("EndOfPeriod", StructureAdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	// Cost correction.
	TableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory;
	
	TableWorkInProgress = Undefined;
	// begin Drive.FullVersion
	TableWorkInProgress = StructureAdditionalProperties.TableForRegisterRecords.TableWorkInProgress;
	// end Drive.FullVersion
	
	TableSales = StructureAdditionalProperties.TableForRegisterRecords.TableSales;
	
	TableIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses;
	
	If UseDefaultTypeOfAccounting Then
		TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
	EndIf;
	
	SelectionDetailRecords = Result.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If SelectionDetailRecords.SalesQuantity = 0 Then
			CorrectionAmount = 0;
		Else
			SalePrice = SelectionDetailRecords.SalesAmount / SelectionDetailRecords.SalesQuantity;
			AmountOfRefunds = SalePrice * SelectionDetailRecords.ReturnQuantity;
			If SelectionDetailRecords.AmountOfRefunds = 0 Then
				CorrectionAmount = SalePrice * SelectionDetailRecords.ReturnQuantity;
			Else
				CorrectionAmount = SelectionDetailRecords.AmountOfRefunds - SalePrice * SelectionDetailRecords.ReturnQuantity;
			EndIf;
		EndIf;
		
		If (NOT Round(CorrectionAmount, 2) = 0) Then
			
			// Movements on the register Inventory and costs accounting.
			ParametersForRecords = ParametersForRecordsByExpensesRegister();
			ParametersForRecords.ContentOfAccountingRecord = NStr("en = 'Cost of return from customer'; ru = 'Себестоимость возврата от покупателя';pl = 'Koszt zwrotu od nabywcy';es_ES = 'Coste de la devolución del cliente';es_CO = 'Coste de la devolución del cliente';tr = 'Müşteriden iade maliyeti';it = 'Costo di restituzione dal cliente';de = 'Rücksendungskosten vom Kunden'", DefaultLanguageCode);
			ParametersForRecords.IsReturn = True;
			GenerateRegisterRecordsByExpensesRegister(
				Ref,
				TableInventory,
				TableWorkInProgress,
				TableAccountingJournalEntries,
				SelectionDetailRecords,
				CorrectionAmount,
				SelectionDetailRecords.ItsReturnOfLastPeriod, // returns of the last year period by the fixed cost
				ParametersForRecords);
			
			// Movements on the register Sales.
			NewRow = TableSales.Add();
			NewRow.Period 				= Ref.Date;
			NewRow.Recorder 			= Ref;
			NewRow.Company 				= SelectionDetailRecords.Company;
			NewRow.PresentationCurrency = SelectionDetailRecords.PresentationCurrency;
			NewRow.Counterparty 		= SelectionDetailRecords.Counterparty;
			NewRow.Currency 			= SelectionDetailRecords.Currency;
			NewRow.SalesOrder 			= SelectionDetailRecords.SalesOrder;
			NewRow.Department 			= SelectionDetailRecords.Department;
			NewRow.Responsible 			= SelectionDetailRecords.Responsible;
			NewRow.Products 			= SelectionDetailRecords.Products;
			NewRow.Characteristic 		= SelectionDetailRecords.Characteristic;
			NewRow.Batch 				= SelectionDetailRecords.Batch;
			NewRow.Ownership 			= SelectionDetailRecords.Ownership;
			NewRow.Document 			= SelectionDetailRecords.SourceDocument;
			NewRow.VATRate 				= SelectionDetailRecords.VATRate;
			NewRow.Cost 				= CorrectionAmount;
			NewRow.Active = True;
			
			// Movements on the register IncomeAndExpenses.
			NewRow = TableIncomeAndExpenses.Add();
			NewRow.Period 				= Ref.Date;
			NewRow.Recorder 			= Ref;
			NewRow.Company 				= SelectionDetailRecords.Company;
			NewRow.PresentationCurrency = SelectionDetailRecords.PresentationCurrency;
			NewRow.StructuralUnit 		= SelectionDetailRecords.Department;
			NewRow.SalesOrder 			= SelectionDetailRecords.SalesOrder;
			If Not ValueIsFilled(NewRow.SalesOrder) Then
				NewRow.SalesOrder = Undefined;
			EndIf;
			NewRow.BusinessLine 		= SelectionDetailRecords.BusinessLineSales;
			NewRow.IncomeAndExpenseItem = SelectionDetailRecords.CorrIncomeAndExpenseItem;
			NewRow.GLAccount 			= SelectionDetailRecords.CorrGLAccount;
			NewRow.AmountExpense 		= CorrectionAmount;
			NewRow.ContentOfAccountingRecord = NStr("en = 'Record expenses'; ru = 'Отражение расходов';pl = 'Rejestr rozchodów';es_ES = 'Registrar los gastos';es_CO = 'Registrar los gastos';tr = 'Masrafların yansıtılması';it = 'Registrazione spese';de = 'Ausgaben buchen'", DefaultLanguageCode);
			NewRow.Active = True;
			
			// Movements by register AccountingJournalEntries.
			If UseDefaultTypeOfAccounting Then
				
				NewRow = TableAccountingJournalEntries.Add();
				NewRow.Active			= True;
				NewRow.Period 			= Ref.Date;
				NewRow.Recorder 		= Ref;
				NewRow.Company 			= SelectionDetailRecords.Company;
				NewRow.PlanningPeriod 	= Catalogs.PlanningPeriods.Actual;
				NewRow.AccountDr 		= SelectionDetailRecords.CorrGLAccount;
				NewRow.AccountCr 		= SelectionDetailRecords.GLAccount;
				NewRow.Content 			= NStr("en = 'Record expenses'; ru = 'Отражение расходов';pl = 'Rejestr rozchodów';es_ES = 'Registrar los gastos';es_CO = 'Registrar los gastos';tr = 'Masrafların yansıtılması';it = 'Registrazione spese';de = 'Ausgaben buchen'", DefaultLanguageCode);
				NewRow.Amount 			= CorrectionAmount;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	TemporaryConvertTable(TableInventory, "TableInventory", StructureAdditionalProperties);

EndProcedure

// The procedure calculates the release actual primecost.
//
// Parameters:
//  Cancel        - Boolean - check box of document posting canceling.
//
Procedure CalculateActualOutputCostPrice(Ref, StructureAdditionalProperties, OperationKind, ErrorsTable, InventoryValuationMethod)
	
	WriteOffCorrectionAccountingCost(Ref, StructureAdditionalProperties, OperationKind, InventoryValuationMethod, ErrorsTable);
	
	If InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage Then
		
		DeleteTempTables(StructureAdditionalProperties);
	
		// Clear records set WriteOffCostCorrectionNodes.
		RecordSet = InformationRegisters.WriteOffCostAdjustment.CreateRecordSet();
		RecordSet.Filter.Recorder.Set(Ref);
		RecordSet.Write(True);
	EndIf;
	
EndProcedure

Procedure DeleteTempTables(StructureAdditionalProperties)
	
	// Delete temporary tables.
	Query = New Query();
	Query.Text = 
	"DROP SolutionsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP CostAccounting
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP CostAccountingReturnsCurPeriod
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP CostAccountingWriteOff
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP CostAccountingReturnsFree
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP CostAccountingReturns
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP CostAccountingWithoutReturnAccounting";
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.ExecuteBatch();
	
EndProcedure

#EndRegion

#Region Distribution

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
Function GenerateDistributionBaseTable(StructureAdditionalProperties, DistributionBase, FilterByStructuralUnit)
	
	ResultTable = New ValueTable;
	
	Query = New Query;
	
	If DistributionBase = Enums.UnderOverAllocatedOverheadsSettings.AdjustedAllocationRate Then
		
		QueryText =
		"SELECT
		|	CostAccounting.Recorder AS Recorder,
		|	CostAccounting.Company AS Company,
		|	CostAccounting.StructuralUnit AS StructuralUnit,
		|	CostAccounting.Products AS Products,
		|	CostAccounting.Characteristic AS Characteristic,
		|	CostAccounting.Batch AS Batch,
		|	CostAccounting.Ownership AS Ownership,
		|	CostAccounting.InventoryAccountType AS InventoryAccountType,
		|	CostAccounting.SalesOrder AS SalesOrder,
		|	CostAccounting.Specification AS Specification,
		|	CostAccounting.CostObject AS CostObject,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN CostAccounting.GLAccount
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END AS GLAccount,
		|	CostAccounting.IncomeAndExpenseItem AS IncomeAndExpenseItem,
		|	SUM(CostAccounting.Amount) AS Base
		|FROM
		|	AccumulationRegister.Inventory AS CostAccounting
		|WHERE
		|	CostAccounting.Period BETWEEN &BegDate AND &EndDate
		|	AND CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
		|	AND CostAccounting.Company = &Company
		// begin Drive.FullVersion
		|	AND CostAccounting.Products REFS Catalog.ManufacturingActivities
		// end Drive.FullVersion
		|	AND CostAccounting.CorrInventoryAccountType = VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads)
		|	AND &FilterByStructuralUnit
		|
		|GROUP BY
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN CostAccounting.GLAccount
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END,
		|	CostAccounting.IncomeAndExpenseItem,
		|	CostAccounting.InventoryAccountType,
		|	CostAccounting.Specification,
		|	CostAccounting.CostObject,
		|	CostAccounting.SalesOrder,
		|	CostAccounting.StructuralUnit,
		|	CostAccounting.Products,
		|	CostAccounting.Characteristic,
		|	CostAccounting.Company,
		|	CostAccounting.Batch,
		|	CostAccounting.Ownership,
		|	CostAccounting.Recorder";
		
		QueryText = StrReplace(QueryText, "&FilterByStructuralUnit",
			?(ValueIsFilled(FilterByStructuralUnit), "CostAccounting.StructuralUnit IN (&BusinessUnitsArray)", "TRUE"));
		
	ElsIf DistributionBase = Enums.CostAllocationMethod.ProductionVolume Then
		
		QueryText =
		"SELECT ALLOWED
		|	UNDEFINED AS Recorder,
		|	ProductReleaseTurnovers.Company AS Company,
		|	ProductReleaseTurnovers.StructuralUnit AS StructuralUnit,
		|	ProductReleaseTurnovers.Products AS Products,
		|	ProductReleaseTurnovers.Characteristic AS Characteristic,
		|	ProductReleaseTurnovers.Batch AS Batch,
		|	ProductReleaseTurnovers.Ownership AS Ownership,
		|	CASE
		|		WHEN ProductReleaseTurnovers.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
		|			THEN VALUE(Enum.InventoryAccountTypes.ThirdPartyInventory)
		|		WHEN ProductReleaseTurnovers.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
		|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedFinishedProducts)
		|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
		|	END AS InventoryAccountType,
		|	ProductReleaseTurnovers.SalesOrder AS SalesOrder,
		|	ProductReleaseTurnovers.Specification AS Specification,
		|	UNDEFINED AS CostObject,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN ProductReleaseTurnovers.Products.ExpensesGLAccount
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END AS GLAccount,
		|	&Expenses AS IncomeAndExpenseItem,
		|	ProductReleaseTurnovers.QuantityTurnover AS Base
		|FROM
		|	AccumulationRegister.ProductRelease.Turnovers(
		|			&BegDate,
		|			&EndDate,
		|			,
		|			Company = &Company
		|				AND &FilterByStructuralUnit) AS ProductReleaseTurnovers
		|WHERE
		|	ProductReleaseTurnovers.Company = &Company
		|	AND ProductReleaseTurnovers.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|	AND ProductReleaseTurnovers.Products.ProductsType <> VALUE(Enum.ProductsTypes.Service)";
		
		QueryText = StrReplace(QueryText, "&FilterByStructuralUnit", ?(ValueIsFilled(FilterByStructuralUnit), "StructuralUnit IN (&BusinessUnitsArray)", "TRUE"));
		
	ElsIf DistributionBase = Enums.CostAllocationMethod.DirectCost Then
		
		QueryText =
		"SELECT ALLOWED
		|	UNDEFINED AS Recorder,
		|	CostAccounting.Company AS Company,
		|	CostAccounting.StructuralUnit AS StructuralUnit,
		|	UNDEFINED AS Products,
		|	UNDEFINED AS Characteristic,
		|	UNDEFINED AS Batch,
		|	CostAccounting.Ownership AS Ownership,
		|	VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads) AS InventoryAccountType,
		|	UNDEFINED AS SalesOrder,
		|	UNDEFINED AS Specification,
		|	UNDEFINED AS CostObject,
		|	UNDEFINED AS GLAccount,
		|	UNDEFINED AS IncomeAndExpenseItem,
		|	CostAccounting.AmountClosingBalance AS Base
		|FROM
		|	AccumulationRegister.Inventory.BalanceAndTurnovers(
		|			&BegDate,
		|			&EndDate,
		|			,
		|			,
		|			Company = &Company
		|				AND InventoryAccountType = VALUE(Enum.InventoryAccountTypes.WorkInProgress)
		|				AND &FilterByStructuralUnitTurnovers) AS CostAccounting
		|
		|UNION ALL
		|
		|SELECT
		|	CostAccounting.Recorder,
		|	CostAccounting.Company,
		|	CostAccounting.StructuralUnitCorr,
		|	CostAccounting.ProductsCorr,
		|	CostAccounting.CharacteristicCorr,
		|	CostAccounting.BatchCorr,
		|	CostAccounting.OwnershipCorr,
		|	CostAccounting.CorrInventoryAccountType,
		|	CostAccounting.SalesOrder,
		|	CostAccounting.SpecificationCorr,
		|	CostAccounting.CostObjectCorr,
		|	CostAccounting.CorrGLAccount,
		|	CostAccounting.CorrIncomeAndExpenseItem,
		|	SUM(CostAccounting.Amount)
		|FROM
		|	AccumulationRegister.Inventory AS CostAccounting
		|WHERE
		|	CostAccounting.Period BETWEEN &BegDate AND &EndDate
		|	AND CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
		|	AND CostAccounting.Company = &Company
		|	AND CostAccounting.InventoryAccountType = VALUE(Enum.InventoryAccountTypes.WorkInProgress)
		|	AND CostAccounting.ProductionExpenses
		|	AND &FilterByStructuralUnit
		|
		|GROUP BY
		|	CostAccounting.Recorder,
		|	CostAccounting.Company,
		|	CostAccounting.StructuralUnitCorr,
		|	CostAccounting.ProductsCorr,
		|	CostAccounting.CharacteristicCorr,
		|	CostAccounting.BatchCorr,
		|	CostAccounting.OwnershipCorr,
		|	CostAccounting.CorrInventoryAccountType,
		|	CostAccounting.SalesOrder,
		|	CostAccounting.SpecificationCorr,
		|	CostAccounting.CostObjectCorr,
		|	CostAccounting.CorrGLAccount,
		|	CostAccounting.CorrIncomeAndExpenseItem";
		
		QueryText = StrReplace(QueryText, "&FilterByStructuralUnitTurnovers", ?(ValueIsFilled(FilterByStructuralUnit), 
																					"StructuralUnit IN (&BusinessUnitsArray)", 
																					"TRUE"));
		QueryText = StrReplace(QueryText, "&FilterByStructuralUnit", ?(ValueIsFilled(FilterByStructuralUnit), 
																		"CostAccounting.StructuralUnitCorr IN (&BusinessUnitsArray)", 
																		"TRUE"));
	Else
		Return ResultTable;
	EndIf;
	
	Query.Text = QueryText;
	
	Query.SetParameter("BegDate", StructureAdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("EndDate", StructureAdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.SetParameter("Expenses", Catalogs.DefaultIncomeAndExpenseItems.GetItem("Expenses"));
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	If ValueIsFilled(FilterByStructuralUnit) Then
		If TypeOf(FilterByStructuralUnit) = Type("Array") Then
			Query.SetParameter("BusinessUnitsArray", FilterByStructuralUnit);
		Else
			ArrayForSelection = New Array;
			ArrayForSelection.Add(FilterByStructuralUnit);
			Query.SetParameter("BusinessUnitsArray", ArrayForSelection);
		EndIf;
	EndIf;
	
	ResultTable = Query.Execute().Unload();
	
	Return ResultTable;
	
EndFunction

// Distributes costs.
//
// Parameters:
//  Cancel        - Boolean - check box of document posting canceling.
//
Procedure DistributeCosts(Ref, StructureAdditionalProperties, ErrorsTable, InventoryValuationMethod)
	
	UnderOverAllocatedOverheadsSetting = StructureAdditionalProperties.AccountingPolicy.UnderOverAllocatedOverheadsSetting;
	
	If UnderOverAllocatedOverheadsSetting = Enums.UnderOverAllocatedOverheadsSettings.WriteOffToCostOfGoodsSold Then
		
		DistributeCosts_WriteOffToCostOfGoodsSold(Ref, StructureAdditionalProperties);
		
	Else
		
		DistributeCosts_AllocationalMethods(Ref, StructureAdditionalProperties, UnderOverAllocatedOverheadsSetting,  ErrorsTable, InventoryValuationMethod);
		
	EndIf;
	
EndProcedure

Procedure DistributeCosts_AllocationalMethods(Ref, StructureAdditionalProperties, UnderOverAllocatedOverheadsSetting, ErrorsTable, InventoryValuationMethod)
	
	Query = New Query;
	
	AdjustedAllocationRate = Enums.UnderOverAllocatedOverheadsSettings.AdjustedAllocationRate;
	BalancesTable = GetInventoryBalanceTableToDistributeCosts(StructureAdditionalProperties,
		UnderOverAllocatedOverheadsSetting = AdjustedAllocationRate,
		StructureAdditionalProperties.ForPosting.LastBoundaryPeriod.Value);
	
	If UnderOverAllocatedOverheadsSetting = AdjustedAllocationRate Then
		
		Query.Text =
		"SELECT
		|	BalancesTable.Company AS Company,
		|	BalancesTable.PresentationCurrency AS PresentationCurrency,
		|	BalancesTable.StructuralUnit AS StructuralUnit,
		|	BalancesTable.Ownership AS Ownership,
		|	BalancesTable.InventoryAccountType AS InventoryAccountType,
		|	BalancesTable.GLAccount AS GLAccount,
		|	BalancesTable.IncomeAndExpenseItem AS IncomeAndExpenseItem,
		|	BalancesTable.Amount AS Amount
		|INTO TT_BalancesTable
		|FROM
		|	&BalancesTable AS BalancesTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_BalancesTable.Company AS Company,
		|	TT_BalancesTable.PresentationCurrency AS PresentationCurrency,
		|	TT_BalancesTable.StructuralUnit AS StructuralUnit,
		|	TT_BalancesTable.Ownership AS Ownership,
		|	TT_BalancesTable.InventoryAccountType AS InventoryAccountType,
		|	TT_BalancesTable.GLAccount AS GLAccount,
		|	TT_BalancesTable.IncomeAndExpenseItem AS IncomeAndExpenseItem,
		|	0 AS AdditionalAmount,
		|	TT_BalancesTable.Amount AS Amount
		|INTO TT_BalancesAndAbsorption
		|FROM
		|	TT_BalancesTable AS TT_BalancesTable
		|
		|UNION ALL
		|
		|SELECT
		|	Inventory.Company,
		|	Inventory.PresentationCurrency,
		|	Inventory.StructuralUnitCorr,
		|	Inventory.Ownership,
		|	Inventory.CorrInventoryAccountType,
		|	Inventory.CorrGLAccount,
		|	Inventory.CorrIncomeAndExpenseItem,
		|	Inventory.Amount,
		|	-Inventory.Amount
		|FROM
		|	AccumulationRegister.Inventory AS Inventory
		|WHERE
		|	Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
		|	AND Inventory.Period BETWEEN &BegDate AND &EndDate
		|	AND Inventory.Company = &Company
		|	AND Inventory.PresentationCurrency = &PresentationCurrency
		|	AND Inventory.CorrInventoryAccountType = VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads)
		|	AND (Inventory.ProductsCorr = UNDEFINED
		|			OR Inventory.ProductsCorr = VALUE(Catalog.Products.EmptyRef))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	FinalTable.Company AS Company,
		|	FinalTable.PresentationCurrency AS PresentationCurrency,
		|	FinalTable.StructuralUnit AS StructuralUnit,
		|	FinalTable.Ownership AS Ownership,
		|	FinalTable.InventoryAccountType AS InventoryAccountType,
		|	FinalTable.GLAccount AS GLAccount,
		|	PrimaryChartOfAccounts.TypeOfAccount AS GLAccountGLAccountType,
		|	FinalTable.IncomeAndExpenseItem AS IncomeAndExpenseItem,
		|	VALUE(Enum.UnderOverAllocatedOverheadsSettings.AdjustedAllocationRate) AS MethodOfDistribution,
		|	SUM(FinalTable.AdditionalAmount) AS AdditionalAmount,
		|	SUM(FinalTable.Amount) AS Amount
		|FROM
		|	TT_BalancesAndAbsorption AS FinalTable
		|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
		|		ON FinalTable.GLAccount = PrimaryChartOfAccounts.Ref
		|
		|GROUP BY
		|	FinalTable.InventoryAccountType,
		|	FinalTable.GLAccount,
		|	FinalTable.IncomeAndExpenseItem,
		|	PrimaryChartOfAccounts.TypeOfAccount,
		|	FinalTable.Ownership,
		|	FinalTable.Company,
		|	FinalTable.StructuralUnit,
		|	FinalTable.PresentationCurrency
		|
		|ORDER BY
		|	MethodOfDistribution,
		|	StructuralUnit
		|TOTALS
		|	SUM(AdditionalAmount),
		|	SUM(Amount)
		|BY
		|	MethodOfDistribution,
		|	StructuralUnit";
		
	Else
		
		Query.Text =
		"SELECT
		|	BalancesTable.Company AS Company,
		|	BalancesTable.PresentationCurrency AS PresentationCurrency,
		|	BalancesTable.StructuralUnit AS StructuralUnit,
		|	BalancesTable.Ownership AS Ownership,
		|	BalancesTable.InventoryAccountType AS InventoryAccountType,
		|	BalancesTable.GLAccount AS GLAccount,
		|	BalancesTable.IncomeAndExpenseItem AS IncomeAndExpenseItem,
		|	BalancesTable.MethodOfDistribution AS MethodOfDistribution,
		|	BalancesTable.Products AS Products,
		|	BalancesTable.Characteristic AS Characteristic,
		|	BalancesTable.Batch AS Batch,
		|	BalancesTable.Amount AS Amount
		|INTO TT_BalancesTable
		|FROM
		|	&BalancesTable AS BalancesTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	FinalTable.Company AS Company,
		|	FinalTable.PresentationCurrency AS PresentationCurrency,
		|	FinalTable.StructuralUnit AS StructuralUnit,
		|	FinalTable.Ownership AS Ownership,
		|	FinalTable.InventoryAccountType AS InventoryAccountType,
		|	FinalTable.GLAccount AS GLAccount,
		|	PrimaryChartOfAccounts.TypeOfAccount AS GLAccountGLAccountType,
		|	FinalTable.IncomeAndExpenseItem AS IncomeAndExpenseItem,
		|	FinalTable.MethodOfDistribution AS MethodOfDistribution,
		|	PrimaryChartOfAccounts.ClosingAccount AS ClosingAccount,
		|	PrimaryChartOfAccounts.ClosingAccount.TypeOfAccount AS GLAccountClosingAccountAccountType,
		|	FinalTable.Products AS Products,
		|	FinalTable.Characteristic AS Characteristic,
		|	FinalTable.Batch AS Batch,
		|	SUM(FinalTable.Amount) AS Amount
		|FROM
		|	TT_BalancesTable AS FinalTable
		|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
		|		ON FinalTable.GLAccount = PrimaryChartOfAccounts.Ref
		|
		|GROUP BY
		|	FinalTable.InventoryAccountType,
		|	FinalTable.MethodOfDistribution,
		|	FinalTable.GLAccount,
		|	PrimaryChartOfAccounts.TypeOfAccount,
		|	FinalTable.IncomeAndExpenseItem,
		|	FinalTable.Ownership,
		|	FinalTable.Company,
		|	FinalTable.StructuralUnit,
		|	FinalTable.PresentationCurrency,
		|	FinalTable.Products,
		|	FinalTable.Characteristic,
		|	FinalTable.Batch,
		|	PrimaryChartOfAccounts.ClosingAccount,
		|	PrimaryChartOfAccounts.ClosingAccount.TypeOfAccount
		|
		|ORDER BY
		|	MethodOfDistribution,
		|	StructuralUnit
		|TOTALS
		|	SUM(Amount)
		|BY
		|	MethodOfDistribution,
		|	StructuralUnit";
		
	EndIf;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	Query.SetParameter("BalancesTable", BalancesTable);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("BegDate", StructureAdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("EndDate", StructureAdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("BalancesPeriod", StructureAdditionalProperties.ForPosting.LastBoundaryPeriod);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	TableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory;
	
	TableWorkInProgress = Undefined;
	// begin Drive.FullVersion
	TableWorkInProgress = StructureAdditionalProperties.TableForRegisterRecords.TableWorkInProgress;
	// end Drive.FullVersion

	RecordSetLandedCosts = AccumulationRegisters.LandedCosts.CreateRecordSet();
	RecordSetLandedCosts.Filter.Recorder.Set(Ref);
	
	If UseDefaultTypeOfAccounting Then
		TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
	EndIf;
	
	BypassByDistributionMethod = QueryResult.Select(QueryResultIteration.ByGroups);
	
	While BypassByDistributionMethod.Next() Do
		
		If BypassByDistributionMethod.MethodOfDistribution = Enums.CostAllocationMethod.DoNotDistribute Then
			Continue;
		EndIf;
		
		BypassByStructuralUnit = BypassByDistributionMethod.Select(QueryResultIteration.ByGroups);
		
		// Bypass on departments.
		While BypassByStructuralUnit.Next() Do
			
			FilterByStructuralUnit = BypassByStructuralUnit.StructuralUnit;
			
			BypassByDetails = BypassByStructuralUnit.Select();
			
			// Bypass on the expenses accounts.
			While BypassByDetails.Next() Do
				
				// Generate allocation base table.
				If UnderOverAllocatedOverheadsSetting = AdjustedAllocationRate Then
					BaseTable = GenerateDistributionBaseTable(
						StructureAdditionalProperties,
						BypassByDetails.MethodOfDistribution,
						FilterByStructuralUnit);
				EndIf;
				
				If BaseTable.Count() = 0 Then
					BaseTable = GenerateDistributionBaseTable(
						StructureAdditionalProperties,
						BypassByDetails.MethodOfDistribution,
						Undefined);
				EndIf;
				
				// Check distribution base table.
				If BaseTable.Count() = 0 Then
					ErrorDescription = GenerateErrorDescriptionCostAllocation(
						Ref,
						BypassByDetails.InventoryAccountType,
						BypassByDetails.MethodOfDistribution,
						BypassByDetails.Amount);
					AddErrorIntoTable(Ref, ErrorDescription, "CostAllocation", ErrorsTable);
					Continue;
				EndIf;
					
				TotalBaseDistribution = BaseTable.Total("Base");
				DirectionsQuantity  = BaseTable.Count() - 1;
				
				If BypassByDetails.MethodOfDistribution = AdjustedAllocationRate
					And BypassByDetails.AdditionalAmount <> 0 Then
					
						RegisterRecordRow = New Structure;
						RegisterRecordRow.Insert("Company"               , BypassByDetails.Company);
						RegisterRecordRow.Insert("PresentationCurrency"  , BypassByDetails.PresentationCurrency);
						RegisterRecordRow.Insert("StructuralUnit"        , BypassByDetails.StructuralUnit);
						RegisterRecordRow.Insert("GLAccount"             , BypassByDetails.GLAccount);
						RegisterRecordRow.Insert("GLAccountGLAccountType", Enums.GLAccountsTypes.IndirectExpenses);
						RegisterRecordRow.Insert("Products"              , Undefined);
						RegisterRecordRow.Insert("Characteristic"        , Undefined);
						RegisterRecordRow.Insert("Batch"                 , Undefined);
						RegisterRecordRow.Insert("Ownership"             , BypassByDetails.Ownership);
						RegisterRecordRow.Insert("StructuralUnitCorr"    , Undefined);
						RegisterRecordRow.Insert("CorrGLAccount"         , Undefined);
						RegisterRecordRow.Insert("ProductsCorr"          , Undefined);
						RegisterRecordRow.Insert("CharacteristicCorr"    , Undefined);
						RegisterRecordRow.Insert("BatchCorr"             , Undefined);
						RegisterRecordRow.Insert("SourceDocument"        , Undefined);
						RegisterRecordRow.Insert("ProductionExpenses"    , True);
						RegisterRecordRow.Insert("Specification"         , Undefined);
						RegisterRecordRow.Insert("SpecificationCorr"     , Undefined);
						RegisterRecordRow.Insert("VATRate"               , Undefined);
						RegisterRecordRow.Insert("CostObjectCorr"        , Undefined);
						RegisterRecordRow.Insert("CostObject"            , Undefined);
						RegisterRecordRow.Insert("InventoryAccountType", BypassByDetails.InventoryAccountType);
						RegisterRecordRow.Insert("CorrInventoryAccountType", Undefined);
						RegisterRecordRow.Insert("IncomeAndExpenseItem", BypassByDetails.IncomeAndExpenseItem);
						RegisterRecordRow.Insert("CorrIncomeAndExpenseItem", Undefined);
						
						// Movements on the register Inventory and costs accounting.
						ParametersForRecords = ParametersForRecordsByExpensesRegister();
						GenerateRegisterRecordsByExpensesRegister(
							Ref,
							TableInventory,
							TableWorkInProgress,
							TableAccountingJournalEntries,
							RegisterRecordRow,
							BypassByDetails.AdditionalAmount,
							True,
							ParametersForRecords);
					
				EndIf;
				
				// Allocate amount.
				If BypassByDetails.Amount <> 0 Then
						
					SumDistribution = BypassByDetails.Amount;
					SumWasDistributed = 0;
					
					For Each DistributionDirection In BaseTable Do
							
						CostAmount = ?(SumDistribution = 0, 0, Round(DistributionDirection.Base / TotalBaseDistribution * SumDistribution, 2, 1));
						SumWasDistributed = SumWasDistributed + CostAmount;
						
						// If it is the last string - , correct amount in it to the rounding error.
						If BaseTable.IndexOf(DistributionDirection) = DirectionsQuantity Then
							CostAmount = CostAmount + SumDistribution - SumWasDistributed;
							SumWasDistributed = SumWasDistributed + CostAmount;
						EndIf;
						
						If CostAmount <> 0 Then
							
							If BypassByDetails.MethodOfDistribution = AdjustedAllocationRate Then
								
								RegisterRecordRow = New Structure;
								RegisterRecordRow.Insert("Company"               , BypassByDetails.Company);
								RegisterRecordRow.Insert("PresentationCurrency"  , BypassByDetails.PresentationCurrency);
								RegisterRecordRow.Insert("StructuralUnit"        , BypassByDetails.StructuralUnit);
								RegisterRecordRow.Insert("GLAccount"             , BypassByDetails.GLAccount);
								RegisterRecordRow.Insert("GLAccountGLAccountType", Enums.GLAccountsTypes.IndirectExpenses);
								RegisterRecordRow.Insert("Products"              , Undefined);
								RegisterRecordRow.Insert("Characteristic"        , Undefined);
								RegisterRecordRow.Insert("Batch"                 , Undefined);
								RegisterRecordRow.Insert("Ownership"             , BypassByDetails.Ownership);
								RegisterRecordRow.Insert("StructuralUnitCorr"    , DistributionDirection.StructuralUnit);
								RegisterRecordRow.Insert("CorrGLAccount"         , DistributionDirection.GLAccount);
								RegisterRecordRow.Insert("ProductsCorr"          , DistributionDirection.Products);
								RegisterRecordRow.Insert("CharacteristicCorr"    , DistributionDirection.Characteristic);
								RegisterRecordRow.Insert("BatchCorr"             , DistributionDirection.Batch);
								RegisterRecordRow.Insert("OwnershipCorr"         , DistributionDirection.Ownership);
								RegisterRecordRow.Insert("SourceDocument"        , Undefined);
								RegisterRecordRow.Insert("ProductionExpenses"    , True);
								RegisterRecordRow.Insert("Specification"         , Undefined);
								RegisterRecordRow.Insert("SpecificationCorr"     , DistributionDirection.Specification);
								RegisterRecordRow.Insert("VATRate"               , Undefined);
								RegisterRecordRow.Insert("CostObjectCorr"        , DistributionDirection.CostObject);
								RegisterRecordRow.Insert("CostObject"            , Undefined);
								RegisterRecordRow.Insert("InventoryAccountType", BypassByDetails.InventoryAccountType);
								RegisterRecordRow.Insert("CorrInventoryAccountType", DistributionDirection.InventoryAccountType);
								RegisterRecordRow.Insert("IncomeAndExpenseItem", BypassByDetails.IncomeAndExpenseItem);
								RegisterRecordRow.Insert("CorrIncomeAndExpenseItem", DistributionDirection.IncomeAndExpenseItem);
								
								IsFIFO = (InventoryValuationMethod = Enums.InventoryValuationMethods.FIFO);
								
								// Movements on the register Inventory and costs accounting.
								ParametersForRecords = ParametersForRecordsByExpensesRegister();
								ParametersForRecords.IsFIFO = IsFIFO;
								GenerateRegisterRecordsByExpensesRegister(
									Ref,
									TableInventory,
									TableWorkInProgress,
									TableAccountingJournalEntries,
									RegisterRecordRow,
									CostAmount,
									True,
									ParametersForRecords);
									
								If IsFIFO Then
									
									GenerateRegisterRecordsByLandedCostsRegister(
										Ref,
										RecordSetLandedCosts,
										DistributionDirection.Recorder,
										RegisterRecordRow,
										CostAmount);
									
								EndIf;
								
							ElsIf BypassByDetails.InventoryAccountType = Enums.InventoryAccountTypes.ManufacturingOverheads Then // the indirect ones are allocated via the closing account
								
								RegisterRecordRow = New Structure;
								RegisterRecordRow.Insert("Company"               , BypassByDetails.Company);
								RegisterRecordRow.Insert("PresentationCurrency"  , BypassByDetails.PresentationCurrency);
								RegisterRecordRow.Insert("StructuralUnit"        , BypassByDetails.StructuralUnit);
								RegisterRecordRow.Insert("GLAccount"             , BypassByDetails.GLAccount);
								RegisterRecordRow.Insert("GLAccountGLAccountType", BypassByDetails.GLAccountGLAccountType);
								RegisterRecordRow.Insert("Products"              , BypassByDetails.Products);
								RegisterRecordRow.Insert("Characteristic"        , BypassByDetails.Characteristic);
								RegisterRecordRow.Insert("Batch"                 , BypassByDetails.Batch);
								RegisterRecordRow.Insert("Ownership"             , BypassByDetails.Ownership);
								RegisterRecordRow.Insert("StructuralUnitCorr"    , DistributionDirection.StructuralUnit);
								RegisterRecordRow.Insert("CorrGLAccount"         , Undefined);
								RegisterRecordRow.Insert("ProductsCorr"          , Catalogs.Products.EmptyRef());
								RegisterRecordRow.Insert("CharacteristicCorr"    , Catalogs.ProductsCharacteristics.EmptyRef());
								RegisterRecordRow.Insert("BatchCorr"             , Catalogs.ProductsBatches.EmptyRef());
								RegisterRecordRow.Insert("SourceDocument"        , Undefined);
								RegisterRecordRow.Insert("ProductionExpenses"    , False);
								RegisterRecordRow.Insert("Specification"         , Catalogs.BillsOfMaterials.EmptyRef());
								RegisterRecordRow.Insert("SpecificationCorr"     , Catalogs.BillsOfMaterials.EmptyRef());
								RegisterRecordRow.Insert("VATRate"               , Catalogs.VATRates.EmptyRef());
								RegisterRecordRow.Insert("CostObjectCorr"        , Undefined);
								RegisterRecordRow.Insert("CostObject"            , Undefined);
								RegisterRecordRow.Insert("InventoryAccountType", BypassByDetails.InventoryAccountType);
								RegisterRecordRow.Insert("CorrInventoryAccountType", Undefined);
								RegisterRecordRow.Insert("IncomeAndExpenseItem", BypassByDetails.IncomeAndExpenseItem);
								RegisterRecordRow.Insert("CorrIncomeAndExpenseItem", Undefined);
								
								// Movements on the register Inventory and costs accounting.
								ParametersForRecords = ParametersForRecordsByExpensesRegister();
								GenerateRegisterRecordsByExpensesRegister(
									Ref,
									TableInventory,
									TableWorkInProgress,
									TableAccountingJournalEntries,
									RegisterRecordRow,
									CostAmount,
									True,
									ParametersForRecords);
								
								If ValueIsFilled(DistributionDirection.Products) Then
									
									RegisterRecordRow = New Structure;
									RegisterRecordRow.Insert("Company"               , BypassByDetails.Company);
									RegisterRecordRow.Insert("PresentationCurrency"  , BypassByDetails.PresentationCurrency);
									RegisterRecordRow.Insert("StructuralUnit"        , DistributionDirection.StructuralUnit);
									RegisterRecordRow.Insert("GLAccount"             , BypassByDetails.GLAccountClosingAccount);
									RegisterRecordRow.Insert("GLAccountGLAccountType", BypassByDetails.GLAccountClosingAccountAccountType);
									RegisterRecordRow.Insert("Products"              , Catalogs.Products.EmptyRef());
									RegisterRecordRow.Insert("Characteristic"        , Catalogs.ProductsCharacteristics.EmptyRef());
									RegisterRecordRow.Insert("Batch"                 , Catalogs.ProductsBatches.EmptyRef());
									RegisterRecordRow.Insert("Ownership"             , BypassByDetails.Ownership);
									RegisterRecordRow.Insert("StructuralUnitCorr"    , DistributionDirection.StructuralUnit);
									RegisterRecordRow.Insert("CorrGLAccount"         , Undefined);
									RegisterRecordRow.Insert("ProductsCorr"          , DistributionDirection.Products);
									RegisterRecordRow.Insert("CharacteristicCorr"    , DistributionDirection.Characteristic);
									RegisterRecordRow.Insert("BatchCorr"             , DistributionDirection.Batch);
									RegisterRecordRow.Insert("OwnershipCorr"         , DistributionDirection.Ownership);
									RegisterRecordRow.Insert("SourceDocument"        , Undefined);
									RegisterRecordRow.Insert("ProductionExpenses"    , True);
									RegisterRecordRow.Insert("Specification"         , Catalogs.BillsOfMaterials.EmptyRef());
									RegisterRecordRow.Insert("SpecificationCorr"     , DistributionDirection.Specification);
									RegisterRecordRow.Insert("VATRate"               , Catalogs.VATRates.EmptyRef());
									RegisterRecordRow.Insert("CostObjectCorr"        , Undefined);
									RegisterRecordRow.Insert("CostObject"            , Undefined);
									RegisterRecordRow.Insert("InventoryAccountType", BypassByDetails.InventoryAccountType);
									RegisterRecordRow.Insert("CorrInventoryAccountType", Undefined);
									RegisterRecordRow.Insert("IncomeAndExpenseItem", BypassByDetails.IncomeAndExpenseItem);
									RegisterRecordRow.Insert("CorrIncomeAndExpenseItem", Undefined);
									
									// Movements on the register Inventory and costs accounting.
									ParametersForRecords = ParametersForRecordsByExpensesRegister();
									GenerateRegisterRecordsByExpensesRegister(
										Ref,
										TableInventory,
										TableWorkInProgress,
										TableAccountingJournalEntries,
										RegisterRecordRow,
										CostAmount,
										True,
										ParametersForRecords);
										
								EndIf;
									
							ElsIf ValueIsFilled(DistributionDirection.Products) Then // allocation of the direct ones
									
								RegisterRecordRow = New Structure;
								RegisterRecordRow.Insert("Company"               , BypassByDetails.Company);
								RegisterRecordRow.Insert("PresentationCurrency"  , BypassByDetails.PresentationCurrency);
								RegisterRecordRow.Insert("StructuralUnit"        , BypassByDetails.StructuralUnit);
								RegisterRecordRow.Insert("GLAccount"             , BypassByDetails.GLAccount);
								RegisterRecordRow.Insert("GLAccountGLAccountType", BypassByDetails.GLAccountGLAccountType);
								RegisterRecordRow.Insert("Products"              , BypassByDetails.Products);
								RegisterRecordRow.Insert("Characteristic"        , BypassByDetails.Characteristic);
								RegisterRecordRow.Insert("Batch"                 , BypassByDetails.Batch);
								RegisterRecordRow.Insert("Ownership"             , BypassByDetails.Ownership);
								RegisterRecordRow.Insert("StructuralUnitCorr"    , DistributionDirection.StructuralUnit);
								RegisterRecordRow.Insert("CorrGLAccount"         , DistributionDirection.GLAccount);
								RegisterRecordRow.Insert("ProductsCorr"          , DistributionDirection.Products);
								RegisterRecordRow.Insert("CharacteristicCorr"    , DistributionDirection.Characteristic);
								RegisterRecordRow.Insert("BatchCorr"             , DistributionDirection.Batch);
								RegisterRecordRow.Insert("OwnershipCorr"         , DistributionDirection.Ownership);
								RegisterRecordRow.Insert("SourceDocument"        , Undefined);
								RegisterRecordRow.Insert("ProductionExpenses"    , True);
								RegisterRecordRow.Insert("Specification"         , Catalogs.BillsOfMaterials.EmptyRef());
								RegisterRecordRow.Insert("SpecificationCorr"     , DistributionDirection.Specification);
								RegisterRecordRow.Insert("VATRate"               , Catalogs.VATRates.EmptyRef());
								RegisterRecordRow.Insert("CostObjectCorr"        , Undefined);
								RegisterRecordRow.Insert("CostObject"            , Undefined);
								RegisterRecordRow.Insert("InventoryAccountType", BypassByDetails.InventoryAccountType);
								RegisterRecordRow.Insert("CorrInventoryAccountType", DistributionDirection.InventoryAccountType);
								RegisterRecordRow.Insert("IncomeAndExpenseItem", BypassByDetails.IncomeAndExpenseItem);
								RegisterRecordRow.Insert("CorrIncomeAndExpenseItem", DistributionDirection.IncomeAndExpenseItem);
								
								// Movements on the register Inventory and costs accounting.
								ParametersForRecords = ParametersForRecordsByExpensesRegister();
								GenerateRegisterRecordsByExpensesRegister(
									Ref,
									TableInventory,
									TableWorkInProgress,
									TableAccountingJournalEntries,
									RegisterRecordRow,
									CostAmount,
									True,
									ParametersForRecords);
									
							EndIf;
							
						EndIf;
						
					EndDo;
						
					If SumWasDistributed = 0 Then
						ErrorDescription = GenerateErrorDescriptionCostAllocation(
							Ref,
							BypassByDetails.InventoryAccountType,
							BypassByDetails.MethodOfDistribution,
							BypassByDetails.Amount);
						AddErrorIntoTable(Ref, ErrorDescription, "CostAllocation", ErrorsTable);
						Continue;
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndDo;
		
	EndDo;
		
	If InventoryValuationMethod = Enums.InventoryValuationMethods.FIFO Then
		
		RecordSetLandedCosts.Write(False);
		RecordSetLandedCosts = AccumulationRegisters.LandedCosts.CreateRecordSet();
		RecordSetLandedCosts.Filter.Recorder.Set(Ref);
		GroupRecordSetLandedCosts(Ref, RecordSetLandedCosts);
		RecordSetLandedCosts.Write(True);
		
		InformationRegisters.TasksForCostsCalculation.CreateRegisterRecord(
			BegOfMonth(Ref.Date),
			Ref.Company,
			Ref);
		
	EndIf;
	
	TemporaryConvertTable(TableInventory, "TableInventory", StructureAdditionalProperties);
	
EndProcedure

Procedure GroupRecordSetLandedCosts(Ref, RegisterRecordSet)
	
	Query = New Query();
	Query.Text = 
	"SELECT ALLOWED
	|	LandedCosts.Period AS Period,
	|	LandedCosts.Recorder AS Recorder,
	|	LandedCosts.RecordType AS RecordType,
	|	LandedCosts.Company AS Company,
	|	LandedCosts.PresentationCurrency AS PresentationCurrency,
	|	LandedCosts.Products AS Products,
	|	LandedCosts.Characteristic AS Characteristic,
	|	LandedCosts.Batch AS Batch,
	|	LandedCosts.Ownership AS Ownership,
	|	LandedCosts.StructuralUnit AS StructuralUnit,
	|	LandedCosts.CostObject AS CostObject,
	|	LandedCosts.CostLayer AS CostLayer,
	|	LandedCosts.InventoryAccountType AS InventoryAccountType,
	|	SUM(LandedCosts.Amount) AS Amount,
	|	LandedCosts.SourceRecord AS SourceRecord,
	|	LandedCosts.VATRate AS VATRate,
	|	LandedCosts.Responsible AS Responsible,
	|	LandedCosts.Department AS Department,
	|	LandedCosts.SourceDocument AS SourceDocument,
	|	LandedCosts.CorrSalesOrder AS CorrSalesOrder,
	|	LandedCosts.CorrStructuralUnit AS CorrStructuralUnit,
	|	LandedCosts.CorrGLAccount AS CorrGLAccount,
	|	LandedCosts.RIMTransfer AS RIMTransfer,
	|	LandedCosts.SalesRep AS SalesRep,
	|	LandedCosts.Counterparty AS Counterparty,
	|	LandedCosts.Currency AS Currency,
	|	LandedCosts.SalesOrder AS SalesOrder,
	|	LandedCosts.CorrCostObject AS CorrCostObject,
	|	LandedCosts.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	LandedCosts.CorrProducts AS CorrProducts,
	|	LandedCosts.GLAccount AS GLAccount,
	|	LandedCosts.CorrCharacteristic AS CorrCharacteristic,
	|	LandedCosts.CorrBatch AS CorrBatch,
	|	LandedCosts.CorrOwnership AS CorrOwnership,
	|	LandedCosts.CorrSpecification AS CorrSpecification,
	|	LandedCosts.Specification AS Specification,
	|	LandedCosts.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	LandedCosts.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.LandedCosts AS LandedCosts
	|WHERE
	|	LandedCosts.Recorder = &Recorder
	|
	|GROUP BY
	|	LandedCosts.Period,
	|	LandedCosts.Recorder,
	|	LandedCosts.RecordType,
	|	LandedCosts.Company,
	|	LandedCosts.PresentationCurrency,
	|	LandedCosts.Products,
	|	LandedCosts.Characteristic,
	|	LandedCosts.Batch,
	|	LandedCosts.Ownership,
	|	LandedCosts.StructuralUnit,
	|	LandedCosts.CostObject,
	|	LandedCosts.CostLayer,
	|	LandedCosts.InventoryAccountType,
	|	LandedCosts.SourceRecord,
	|	LandedCosts.VATRate,
	|	LandedCosts.Responsible,
	|	LandedCosts.Department,
	|	LandedCosts.SourceDocument,
	|	LandedCosts.CorrSalesOrder,
	|	LandedCosts.CorrStructuralUnit,
	|	LandedCosts.CorrGLAccount,
	|	LandedCosts.RIMTransfer,
	|	LandedCosts.SalesRep,
	|	LandedCosts.Counterparty,
	|	LandedCosts.Currency,
	|	LandedCosts.SalesOrder,
	|	LandedCosts.CorrCostObject,
	|	LandedCosts.CorrInventoryAccountType,
	|	LandedCosts.CorrProducts,
	|	LandedCosts.GLAccount,
	|	LandedCosts.CorrCharacteristic,
	|	LandedCosts.CorrBatch,
	|	LandedCosts.CorrOwnership,
	|	LandedCosts.CorrSpecification,
	|	LandedCosts.Specification,
	|	LandedCosts.IncomeAndExpenseItem,
	|	LandedCosts.CorrIncomeAndExpenseItem";
	
	Query.SetParameter("Recorder", Ref);
	
	RecordsTableRegister = Query.Execute().Unload();
	
	RegisterRecordSet.Load(RecordsTableRegister);
	
EndProcedure

Procedure DistributeCosts_WriteOffToCostOfGoodsSold(Ref, StructureAdditionalProperties)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	InventoryBalance.Products AS Products,
	|	InventoryBalance.Characteristic AS Characteristic,
	|	InventoryBalance.Batch AS Batch,
	|	InventoryBalance.Ownership AS Ownership,
	|	InventoryBalance.StructuralUnit AS StructuralUnit,
	|	InventoryBalance.InventoryAccountType AS InventoryAccountType,
	|	InventoryBalance.AmountBalance AS Amount
	|INTO InventoryTT
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			&LastBoundaryPeriod,
	|			Company = &Company
	|				AND PresentationCurrency = &PresentationCurrency
	|				AND Products = UNDEFINED
	|				AND InventoryAccountType = VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads)) AS InventoryBalance
	|
	|UNION ALL
	|
	|SELECT
	|	InventoryBalance.Products,
	|	InventoryBalance.Characteristic,
	|	InventoryBalance.Batch,
	|	InventoryBalance.Ownership,
	|	InventoryBalance.StructuralUnit,
	|	InventoryBalance.InventoryAccountType,
	|	InventoryBalance.AmountBalance
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			&LastBoundaryPeriod,
	|			Company = &Company
	|				AND PresentationCurrency = &PresentationCurrency
	|				AND Products = VALUE(Catalog.Products.EmptyRef)
	|				AND InventoryAccountType = VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads)) AS InventoryBalance
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(InventoryTT.Amount) AS Amount,
	|	InventoryTT.InventoryAccountType AS InventoryAccountType,
	|	ProductsCatalog.BusinessLine AS BusinessLine,
	|	InventoryTT.StructuralUnit AS StructuralUnit
	|INTO AccountingTT
	|FROM
	|	InventoryTT AS InventoryTT
	|		LEFT JOIN Catalog.Products AS ProductsCatalog
	|		ON InventoryTT.Products = ProductsCatalog.Ref
	|
	|GROUP BY
	|	InventoryTT.InventoryAccountType,
	|	ProductsCatalog.BusinessLine,
	|	InventoryTT.StructuralUnit
	|
	|UNION ALL
	|
	|SELECT
	|	SUM(-Inventory.Amount),
	|	Inventory.CorrInventoryAccountType,
	|	ProductsCatalog.BusinessLine,
	|	Inventory.StructuralUnit
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|		LEFT JOIN Catalog.Products AS ProductsCatalog
	|		ON Inventory.Products = ProductsCatalog.Ref
	|WHERE
	|	Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Inventory.Period BETWEEN &BegDate AND &EndDate
	|	AND Inventory.Company = &Company
	|	AND Inventory.PresentationCurrency = &PresentationCurrency
	|	AND Inventory.CorrInventoryAccountType = VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads)
	|	AND Inventory.ProductsCorr = UNDEFINED
	|
	|GROUP BY
	|	Inventory.CorrInventoryAccountType,
	|	ProductsCatalog.BusinessLine,
	|	Inventory.StructuralUnit
	|
	|UNION ALL
	|
	|SELECT
	|	SUM(-Inventory.Amount),
	|	Inventory.CorrInventoryAccountType,
	|	ProductsCatalog.BusinessLine,
	|	Inventory.StructuralUnit
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|		LEFT JOIN Catalog.Products AS ProductsCatalog
	|		ON Inventory.Products = ProductsCatalog.Ref
	|WHERE
	|	Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Inventory.Period BETWEEN &BegDate AND &EndDate
	|	AND Inventory.Company = &Company
	|	AND Inventory.PresentationCurrency = &PresentationCurrency
	|	AND Inventory.CorrInventoryAccountType = VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads)
	|	AND Inventory.ProductsCorr = VALUE(Catalog.Products.EmptyRef)
	|
	|GROUP BY
	|	Inventory.CorrInventoryAccountType,
	|	ProductsCatalog.BusinessLine,
	|	Inventory.StructuralUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryTT.Products AS Products,
	|	InventoryTT.Characteristic AS Characteristic,
	|	InventoryTT.Batch AS Batch,
	|	InventoryTT.Ownership AS Ownership,
	|	InventoryTT.StructuralUnit AS StructuralUnit,
	|	InventoryTT.InventoryAccountType AS InventoryAccountType,
	|	InventoryTT.Amount AS Amount
	|FROM
	|	InventoryTT AS InventoryTT
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountingTT.BusinessLine AS BusinessLine,
	|	AccountingTT.StructuralUnit AS StructuralUnit,
	|	AccountingTT.InventoryAccountType AS InventoryAccountType,
	|	SUM(AccountingTT.Amount) AS Amount
	|FROM
	|	AccountingTT AS AccountingTT
	|
	|GROUP BY
	|	AccountingTT.BusinessLine,
	|	AccountingTT.StructuralUnit,
	|	AccountingTT.InventoryAccountType";
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("BegDate", StructureAdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("EndDate", StructureAdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("LastBoundaryPeriod", StructureAdditionalProperties.ForPosting.LastBoundaryPeriod);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	
	ResultsArray = Query.ExecuteBatch();
	
	InventoryDetailRecord = ResultsArray[2].Select();
	AccountingDetailRecord = ResultsArray[3].Select();
	
	TableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory;
	
	While InventoryDetailRecord.Next() Do
		
		If InventoryDetailRecord.Amount > 0 Then
			DistributeCosts_DistributeInventoryAmounts(Ref, StructureAdditionalProperties,
				TableInventory, InventoryDetailRecord, Ref.Date, InventoryDetailRecord.Amount);
		EndIf;
		
	EndDo;
		
	TableIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses;
	
	GLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("WriteOffOverUnderMOHToCOGS");
	IncomeAndExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("COGS");
	
	While AccountingDetailRecord.Next() Do
		
		AmountBalance = AccountingDetailRecord.Amount;
		
		If AmountBalance <> 0 Then
			
			Content = ?(AmountBalance < 0,
				NStr("en = 'Overallocated manufacturing overheads'; ru = 'Избыточно отнесенные производственные накладные расходы';pl = 'Nadmiernie przydzielone koszty ogólne produkcji';es_ES = 'Sobreasignación de los gastos generales de fabricación';es_CO = 'Sobreasignación de los gastos generales de fabricación';tr = 'Fazla tahsis edilmiş üretim genel giderleri';it = 'Spese generali di produzione sovrastimate';de = 'Überlastete Fertigungsgemeinkosten'", DefaultLanguageCode),
				NStr("en = 'Underallocated manufacturing overheads'; ru = 'Недостаточно отнесенные производственные накладные расходы';pl = 'Niewystarczająco przydzielone koszty ogólne produkcji';es_ES = 'Gastos generales de fabricación sin asignación';es_CO = 'Gastos generales de fabricación sin asignación';tr = 'Az tahsis edilmiş üretim genel giderleri';it = 'Spese generali di produzione sottostimate';de = 'Mangelhaft verteilte Fertigungsgemeinkosten'", DefaultLanguageCode));
			
			// Manufacturing overheads
			IncomeAndExpensesRow = TableIncomeAndExpenses.Add();
			IncomeAndExpensesRow.Period						= Ref.Date;
			IncomeAndExpensesRow.Recorder					= Ref;
			IncomeAndExpensesRow.Company					= StructureAdditionalProperties.ForPosting.Company;
			IncomeAndExpensesRow.PresentationCurrency		= StructureAdditionalProperties.ForPosting.PresentationCurrency;
			IncomeAndExpensesRow.StructuralUnit				= AccountingDetailRecord.StructuralUnit;
			IncomeAndExpensesRow.BusinessLine				= AccountingDetailRecord.BusinessLine;
			IncomeAndExpensesRow.IncomeAndExpenseItem		= IncomeAndExpenseItem;
			IncomeAndExpensesRow.AmountExpense				= AmountBalance;
			IncomeAndExpensesRow.ContentOfAccountingRecord	= Content;
			IncomeAndExpensesRow.GLAccount					= GLAccount;
			IncomeAndExpensesRow.Active						= True;
			
		EndIf;
		
	EndDo;
	
	// Create the accounting register records set Accounting journal entries.
	If UseDefaultTypeOfAccounting Then
		
		TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
		WriteOffToCostsOfGoodsSoldInAccounting(Ref, StructureAdditionalProperties, TableAccountingJournalEntries);
		
	EndIf;
	
	TemporaryConvertTable(TableInventory, "TableInventory", StructureAdditionalProperties);
	
EndProcedure

Procedure WriteOffToCostsOfGoodsSoldInAccounting(Ref, StructureAdditionalProperties, TableAccountingJournalEntries)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Inventory.GLAccount AS Account,
	|	CASE
	|		WHEN Inventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN -Inventory.Amount
	|		ELSE Inventory.Amount
	|	END AS Amount
	|INTO TT_Overheads
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Company = &Company
	|	AND Inventory.Period BETWEEN &DateStart AND &DateEnd
	|	AND Inventory.InventoryAccountType = VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads)
	|	AND Inventory.Recorder <> &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	Inventory.CorrGLAccount,
	|	CASE
	|		WHEN Inventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN Inventory.Amount
	|		ELSE -Inventory.Amount
	|	END
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Company = &Company
	|	AND Inventory.Period BETWEEN &DateStart AND &DateEnd
	|	AND Inventory.CorrInventoryAccountType = VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads)
	|	AND Inventory.Recorder <> &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Overheads.Account AS Account,
	|	SUM(TT_Overheads.Amount) AS Amount
	|FROM
	|	TT_Overheads AS TT_Overheads
	|
	|GROUP BY
	|	TT_Overheads.Account";
	
	Query.SetParameter("DateStart", StructureAdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd", StructureAdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Ref", Ref);
	
	AccountDr = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("WriteOffOverUnderMOHToCOGS");
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If Selection.Amount = 0 Then 
			Continue;
		EndIf;
		
		Content = ?(Selection.Amount < 0,
			NStr("en = 'Overallocated manufacturing overheads'; ru = 'Избыточно отнесенные производственные накладные расходы';pl = 'Nadmiernie przydzielone koszty ogólne produkcji';es_ES = 'Sobreasignación de los gastos generales de fabricación';es_CO = 'Sobreasignación de los gastos generales de fabricación';tr = 'Fazla tahsis edilmiş üretim genel giderleri';it = 'Spese generali di produzione sovrastimate';de = 'Überlastete Fertigungsgemeinkosten'"),
			NStr("en = 'Underallocated manufacturing overheads'; ru = 'Недостаточно отнесенные производственные накладные расходы';pl = 'Niewystarczająco przydzielone koszty ogólne produkcji';es_ES = 'Gastos generales de fabricación sin asignación';es_CO = 'Gastos generales de fabricación sin asignación';tr = 'Az tahsis edilmiş üretim genel giderleri';it = 'Spese generali di produzione sottostimate';de = 'Mangelhaft verteilte Fertigungsgemeinkosten'"));
		
		AccountingRow = TableAccountingJournalEntries.Add();
		AccountingRow.Active = True;
		AccountingRow.Period = Ref.Date;
		AccountingRow.Recorder = Ref;
		AccountingRow.Company = StructureAdditionalProperties.ForPosting.Company;
		AccountingRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
		AccountingRow.AccountDr = AccountDr;
		AccountingRow.AccountCr = Selection.Account;
		AccountingRow.Amount = Selection.Amount;
		AccountingRow.Content = Content;
		
	EndDo;
	
EndProcedure

Procedure WriteOffLandedCostsInAccounting(StructureAdditionalProperties,TableAccountingJournalEntries, TableToWriteOff, DateEnd)
	
	If TableToWriteOff.Columns.Find("LineNumber") = Undefined Then
		
		TableToWriteOff.Columns.Add("LineNumber", New TypeDescription("Number",,,New NumberQualifiers(6,0)));
		TableToWriteOff.Columns.Add("RegistrationDate", New TypeDescription("Date"));
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	CASE
		|		WHEN Companies.RegistrationDate = DATETIME(1, 1, 1)
		|			THEN ISNULL(AccountingPolicySliceFirst.Period, &DefaultDate)
		|		ELSE Companies.RegistrationDate
		|	END AS RegistrationDate
		|FROM
		|	Catalog.Companies AS Companies
		|		LEFT JOIN InformationRegister.AccountingPolicy.SliceFirst AS AccountingPolicySliceFirst
		|		ON Companies.Ref = AccountingPolicySliceFirst.Company
		|WHERE
		|	Companies.Ref = &Company";
		
		Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
		Query.SetParameter("DefaultDate", DriveServer.GetDefaultDate());
		
		QueryResultTable = Query.Execute().Unload();
		RegistrationDate = QueryResultTable[0].RegistrationDate;
		
		For LineNumber = 1 To TableToWriteOff.Count() Do
			TableToWriteOff[LineNumber - 1].LineNumber = LineNumber;
			TableToWriteOff[LineNumber - 1].RegistrationDate = RegistrationDate;
		EndDo;
		
	EndIf;
	
	DateStart = BegOfMonth(DateEnd);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TableToWriteOff.LineNumber AS LineNumber,
	|	TableToWriteOff.Company AS Company,
	|	TableToWriteOff.PresentationCurrency AS PresentationCurrency,
	|	TableToWriteOff.StructuralUnit AS StructuralUnit,
	|	TableToWriteOff.InventoryAccountType AS InventoryAccountType,
	|	TableToWriteOff.CostObject AS CostObject,
	|	TableToWriteOff.CostLayer AS CostLayer,
	|	TableToWriteOff.Products AS Products,
	|	TableToWriteOff.Characteristic AS Characteristic,
	|	TableToWriteOff.Batch AS Batch,
	|	TableToWriteOff.Ownership AS Ownership,
	|	TableToWriteOff.GLAccountCostOfSales AS GLAccountCostOfSales,
	|	TableToWriteOff.Amount AS Amount
	|INTO TT_TableToWriteOff
	|FROM
	|	&TableToWriteOff AS TableToWriteOff
	|WHERE
	|	TableToWriteOff.RegistrationDate < &DateEnd
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_TableToWriteOff.LineNumber AS LineNumber,
	|	TT_TableToWriteOff.Company AS Company,
	|	TT_TableToWriteOff.PresentationCurrency AS PresentationCurrency,
	|	TT_TableToWriteOff.StructuralUnit AS StructuralUnit,
	|	TT_TableToWriteOff.InventoryAccountType AS InventoryAccountType,
	|	TT_TableToWriteOff.CostObject AS CostObject,
	|	TT_TableToWriteOff.CostLayer AS CostLayer,
	|	TT_TableToWriteOff.Products AS Products,
	|	TT_TableToWriteOff.Characteristic AS Characteristic,
	|	TT_TableToWriteOff.Batch AS Batch,
	|	TT_TableToWriteOff.Ownership AS Ownership,
	|	TT_TableToWriteOff.GLAccountCostOfSales AS GLAccountCostOfSales,
	|	ISNULL(LandedCosts.GLAccount, VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)) AS GLAccount,
	|	TT_TableToWriteOff.Amount AS AmountToWriteOff,
	|	ISNULL(LandedCosts.Amount, 0) AS Amount
	|FROM
	|	TT_TableToWriteOff AS TT_TableToWriteOff
	|		LEFT JOIN AccumulationRegister.LandedCosts AS LandedCosts
	|		ON (LandedCosts.Period BETWEEN &DateStart AND &DateEnd)
	|			AND TT_TableToWriteOff.Company = LandedCosts.Company
	|			AND TT_TableToWriteOff.PresentationCurrency = LandedCosts.PresentationCurrency
	|			AND TT_TableToWriteOff.Products = LandedCosts.Products
	|			AND TT_TableToWriteOff.Characteristic = LandedCosts.Characteristic
	|			AND TT_TableToWriteOff.Batch = LandedCosts.Batch
	|			AND TT_TableToWriteOff.Ownership = LandedCosts.Ownership
	|			AND TT_TableToWriteOff.StructuralUnit = LandedCosts.StructuralUnit
	|			AND TT_TableToWriteOff.CostObject = LandedCosts.CostObject
	|			AND TT_TableToWriteOff.CostLayer = LandedCosts.CostLayer
	|			AND TT_TableToWriteOff.InventoryAccountType = LandedCosts.InventoryAccountType
	|TOTALS
	|	MAX(AmountToWriteOff)
	|BY
	|	LineNumber";
	
	Query.SetParameter("TableToWriteOff", TableToWriteOff);
	Query.SetParameter("DateStart", DateStart);
	Query.SetParameter("DateEnd", DateEnd);
	
	PreviousMonthTableToWriteOff = TableToWriteOff.CopyColumns();
	
	SelectionLineNumber = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While SelectionLineNumber.Next() Do
		
		AmountToWriteOff = SelectionLineNumber.AmountToWriteOff;
		
		Selection = SelectionLineNumber.Select();
		While Selection.Next() Do
			
			If Selection.Amount = 0 Then 
				Continue;
			EndIf;
			
			Record = TableAccountingJournalEntries.Add();
			Record.Active = True;
			Record.Period = DateEnd;
			Record.Company = Selection.Company;
			Record.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
			Record.AccountDr = Selection.GLAccountCostOfSales;
			Record.AccountCr = Selection.GLAccount;
			Record.Amount = Selection.Amount;
			Record.Content = NStr("en = 'Landed costs allocated'; ru = 'Отнесенные дополнительные расходы';pl = 'Przydzielone koszty z wyładunkiem';es_ES = 'Costes de entrega acumulados';es_CO = 'Costes de entrega acumulados';tr = 'Varış yeri maliyetleri dağıtıldı';it = 'Costi di scarico allocati';de = 'Wareneinstandspreise zugewiesen'");
			
			AmountToWriteOff = AmountToWriteOff - Selection.Amount;
			
			If AmountToWriteOff <= 0 Then
				Break;
			EndIf;
			
		EndDo;
		
		If AmountToWriteOff > 0 Then
			
			Selection.Reset();
			Selection.Next();
			
			NewRow = PreviousMonthTableToWriteOff.Add();
			FillPropertyValues(NewRow, Selection);
			NewRow.Amount = AmountToWriteOff;
			NewRow.Active = True;
		EndIf;
		
	EndDo;
	
	If PreviousMonthTableToWriteOff.Count() Then
		WriteOffLandedCostsInAccounting(StructureAdditionalProperties, TableAccountingJournalEntries, PreviousMonthTableToWriteOff, DateStart - 1);
	EndIf;
	
EndProcedure

Function GetInventoryBalanceTableToDistributeCosts(StructureAdditionalProperties, IsAdjustedAllocationRate, BalancesPeriod, BalancesTable = Undefined)
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	Query = New Query;
	
	If BalancesTable = Undefined Then
		
		If IsAdjustedAllocationRate Then
			
			Query.Text =
			"SELECT ALLOWED
			|	InventoryAndCostAccounting.Company AS Company,
			|	InventoryAndCostAccounting.PresentationCurrency AS PresentationCurrency,
			|	InventoryAndCostAccounting.StructuralUnit AS StructuralUnit,
			|	InventoryAndCostAccounting.Ownership AS Ownership,
			|	InventoryAndCostAccounting.InventoryAccountType AS InventoryAccountType,
			|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS GLAccount,
			|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) AS IncomeAndExpenseItem,
			|	TRUE AS IsBalancesRow,
			|	InventoryAndCostAccounting.AmountBalance AS Amount
			|FROM
			|	AccumulationRegister.Inventory.Balance(
			|			&BalancesPeriod,
			|			Company = &Company
			|				AND PresentationCurrency = &PresentationCurrency
			|				AND InventoryAccountType = VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads)
			|				AND Products = UNDEFINED) AS InventoryAndCostAccounting";
			
		Else
			
			Query.Text =
			"SELECT ALLOWED
			|	InventoryAndCostAccounting.Company AS Company,
			|	InventoryAndCostAccounting.PresentationCurrency AS PresentationCurrency,
			|	InventoryAndCostAccounting.StructuralUnit AS StructuralUnit,
			|	InventoryAndCostAccounting.Ownership AS Ownership,
			|	InventoryAndCostAccounting.InventoryAccountType AS InventoryAccountType,
			|	ISNULL(DefaultIncomeAndExpenseItems.IncomeAndExpenseItem.MethodOfDistribution, VALUE(Enum.CostAllocationMethod.DoNotDistribute)) AS MethodOfDistribution,
			|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS GLAccount,
			|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) AS IncomeAndExpenseItem,
			|	InventoryAndCostAccounting.Products AS Products,
			|	InventoryAndCostAccounting.Characteristic AS Characteristic,
			|	InventoryAndCostAccounting.Batch AS Batch,
			|	TRUE AS IsBalancesRow,
			|	InventoryAndCostAccounting.AmountBalance AS Amount
			|FROM
			|	AccumulationRegister.Inventory.Balance(
			|			&BalancesPeriod,
			|			Company = &Company
			|				AND PresentationCurrency = &PresentationCurrency
			|				AND (InventoryAccountType = VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads)
			|					OR InventoryAccountType = VALUE(Enum.InventoryAccountTypes.WorkInProgress)
			|						AND Products = VALUE(Catalog.Products.EmptyRef))) AS InventoryAndCostAccounting
			|		LEFT JOIN Catalog.DefaultIncomeAndExpenseItems AS DefaultIncomeAndExpenseItems
			|		ON (DefaultIncomeAndExpenseItems.Ref = VALUE(Catalog.DefaultIncomeAndExpenseItems.ManufacturingOverheads))
			|WHERE
			|	ISNULL(DefaultIncomeAndExpenseItems.IncomeAndExpenseItem.MethodOfDistribution, VALUE(Enum.CostAllocationMethod.DoNotDistribute)) <> VALUE(Enum.CostAllocationMethod.DoNotDistribute)";
			
		EndIf;
		
		Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
		Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
		Query.SetParameter("BalancesPeriod", StructureAdditionalProperties.ForPosting.LastBoundaryPeriod);
		
		BalancesTable = Query.Execute().Unload();
		
	EndIf;
	
	BegOfPeriod = BegOfMonth(BalancesPeriod);
	EndOfPeriod = EndOfMonth(BalancesPeriod);
	
	If IsAdjustedAllocationRate Then
		
		Query.Text =
		"SELECT
		|	BalancesTable.Company AS Company,
		|	BalancesTable.PresentationCurrency AS PresentationCurrency,
		|	BalancesTable.StructuralUnit AS StructuralUnit,
		|	BalancesTable.Ownership AS Ownership,
		|	BalancesTable.InventoryAccountType AS InventoryAccountType,
		|	BalancesTable.Amount AS Amount
		|INTO TT_BalancesTable
		|FROM
		|	&BalancesTable AS BalancesTable
		|WHERE
		|	BalancesTable.GLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Inventory.Company AS Company,
		|	Inventory.PresentationCurrency AS PresentationCurrency,
		|	Inventory.StructuralUnit AS StructuralUnit,
		|	Inventory.Ownership AS Ownership,
		|	Inventory.InventoryAccountType AS InventoryAccountType,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN Inventory.GLAccount
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END AS GLAccount,
		|	Inventory.IncomeAndExpenseItem AS IncomeAndExpenseItem,
		|	FALSE AS IsBalancesRow,
		|	SUM(Inventory.Amount) AS Amount
		|FROM
		|	AccumulationRegister.Inventory AS Inventory
		|		INNER JOIN TT_BalancesTable AS TT_BalancesTable
		|		ON (Inventory.Period BETWEEN &BegOfPeriod AND &EndOfPeriod)
		|			AND (Inventory.Products = UNDEFINED)
		|			AND Inventory.Company = TT_BalancesTable.Company
		|			AND Inventory.PresentationCurrency = TT_BalancesTable.PresentationCurrency
		|			AND Inventory.StructuralUnit = TT_BalancesTable.StructuralUnit
		|			AND Inventory.Ownership = TT_BalancesTable.Ownership
		|			AND Inventory.InventoryAccountType = TT_BalancesTable.InventoryAccountType
		|
		|GROUP BY
		|	Inventory.Company,
		|	Inventory.PresentationCurrency,
		|	Inventory.StructuralUnit,
		|	Inventory.Ownership,
		|	Inventory.InventoryAccountType,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN Inventory.GLAccount
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END,
		|	Inventory.IncomeAndExpenseItem";
		
		SearchStructure = New Structure("StructuralUnit, Ownership, InventoryAccountType, IsBalancesRow");
		
		SearchStructure.IsBalancesRow = True;
		
	Else
		
		Query.Text =
		"SELECT
		|	BalancesTable.Company AS Company,
		|	BalancesTable.PresentationCurrency AS PresentationCurrency,
		|	BalancesTable.StructuralUnit AS StructuralUnit,
		|	BalancesTable.Ownership AS Ownership,
		|	BalancesTable.InventoryAccountType AS InventoryAccountType,
		|	BalancesTable.MethodOfDistribution AS MethodOfDistribution,
		|	BalancesTable.Products AS Products,
		|	BalancesTable.Characteristic AS Characteristic,
		|	BalancesTable.Batch AS Batch,
		|	FALSE AS IsBalancesRow,
		|	BalancesTable.Amount AS Amount
		|INTO TT_BalancesTable
		|FROM
		|	&BalancesTable AS BalancesTable
		|WHERE
		|	BalancesTable.GLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Inventory.Company AS Company,
		|	Inventory.PresentationCurrency AS PresentationCurrency,
		|	Inventory.StructuralUnit AS StructuralUnit,
		|	Inventory.Ownership AS Ownership,
		|	Inventory.InventoryAccountType AS InventoryAccountType,
		|	CASE 
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN Inventory.GLAccount
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END AS GLAccount,
		|	Inventory.IncomeAndExpenseItem AS IncomeAndExpenseItem,
		|	Inventory.Products AS Products,
		|	Inventory.Characteristic AS Characteristic,
		|	Inventory.Batch AS Batch,
		|	SUM(Inventory.Amount) AS Amount
		|FROM
		|	AccumulationRegister.Inventory AS Inventory
		|		INNER JOIN TT_BalancesTable AS TT_BalancesTable
		|		ON (Inventory.Period BETWEEN &BegOfPeriod AND &EndOfPeriod)
		|			AND (Inventory.Products = UNDEFINED)
		|			AND Inventory.Company = TT_BalancesTable.Company
		|			AND Inventory.PresentationCurrency = TT_BalancesTable.PresentationCurrency
		|			AND Inventory.StructuralUnit = TT_BalancesTable.StructuralUnit
		|			AND Inventory.Ownership = TT_BalancesTable.Ownership
		|			AND Inventory.InventoryAccountType = TT_BalancesTable.InventoryAccountType
		|			AND Inventory.Products = TT_BalancesTable.Products
		|			AND Inventory.Characteristic = TT_BalancesTable.Characteristic
		|			AND Inventory.Batch = TT_BalancesTable.Batch
		|
		|GROUP BY
		|	Inventory.Company,
		|	Inventory.PresentationCurrency,
		|	Inventory.StructuralUnit,
		|	Inventory.Ownership,
		|	Inventory.InventoryAccountType,
		|	CASE 
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN Inventory.GLAccount
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END,
		|	Inventory.IncomeAndExpenseItem,
		|	Inventory.Products,
		|	Inventory.Characteristic,
		|	Inventory.Batch";
		
		SearchStructure = New Structure("StructuralUnit, Ownership, IncomeAndExpenseItem, Products, Characteristic, Batch, IsBalancesRow");
		SearchStructure.IsBalancesRow = True;
		
	EndIf;
	
	Query.SetParameter("BalancesTable", BalancesTable);
	Query.SetParameter("BegOfPeriod", BegOfPeriod);
	Query.SetParameter("EndOfPeriod", EndOfPeriod);
	Query.SetParameter("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	For Each TurnoversRow In Query.Execute().Unload() Do
		
		FillPropertyValues(SearchStructure, TurnoversRow, , "IsBalancesRow");
		
		BalancesRow = BalancesTable.FindRows(SearchStructure)[0];
		BalancesRow.Amount = BalancesRow.Amount - TurnoversRow.Amount;
		
		If BalancesRow.Amount = 0 Then
			BalancesTable.Delete(BalancesRow);
		EndIf;
		
		FillPropertyValues(BalancesTable.Add(), TurnoversRow);
		
	EndDo;
	
	If BalancesTable.Find(True, "IsBalancesRow") = Undefined Then
		Return BalancesTable;
	Else
		Return GetInventoryBalanceTableToDistributeCosts(StructureAdditionalProperties, IsAdjustedAllocationRate, BegOfPeriod - 1, BalancesTable);
	EndIf;
	
EndFunction

Procedure DistributeCosts_DistributeInventoryAmounts(Ref, StructureAdditionalProperties, TableInventory, InventoryDetailRecord, Date, Val Amount)
	
	BeginDate = BegOfMonth(Date);
	EndDate = EndOfMonth(Date);
	Content = NStr("en = 'Expenses write-off'; ru = 'Списание расходов';pl = 'Spisanie rozchodów';es_ES = 'Amortización de gastos';es_CO = 'Amortización de gastos';tr = 'Giderlerin silinmesi';it = 'Spese cancellate';de = 'Ausgabenabschreibung'");
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.Ownership AS Ownership,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.InventoryAccountType AS InventoryAccountType,
	|	Inventory.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	Inventory.GLAccount AS GLAccount,
	|	CASE
	|		WHEN Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN Inventory.Amount
	|		ELSE -Inventory.Amount
	|	END AS Amount
	|INTO InventoryTT
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Period BETWEEN &BeginDate AND &EndDate
	|	AND Inventory.Company = &Company
	|	AND Inventory.PresentationCurrency = &PresentationCurrency
	|	AND Inventory.Products = UNDEFINED
	|	AND Inventory.InventoryAccountType = VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads)
	|
	|UNION ALL
	|
	|SELECT
	|	Inventory.Products,
	|	Inventory.Characteristic,
	|	Inventory.Batch,
	|	Inventory.Ownership,
	|	Inventory.StructuralUnit,
	|	Inventory.InventoryAccountType,
	|	Inventory.IncomeAndExpenseItem,
	|	Inventory.GLAccount,
	|	CASE
	|		WHEN Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN Inventory.Amount
	|		ELSE -Inventory.Amount
	|	END
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Period BETWEEN &BeginDate AND &EndDate
	|	AND Inventory.Company = &Company
	|	AND Inventory.PresentationCurrency = &PresentationCurrency
	|	AND Inventory.Products = VALUE(Catalog.Products.EmptyRef)
	|	AND Inventory.InventoryAccountType = VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryTT.Products AS Products,
	|	InventoryTT.Characteristic AS Characteristic,
	|	InventoryTT.Batch AS Batch,
	|	InventoryTT.Ownership AS Ownership,
	|	InventoryTT.StructuralUnit AS StructuralUnit,
	|	InventoryTT.InventoryAccountType AS InventoryAccountType,
	|	InventoryTT.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	InventoryTT.GLAccount AS GLAccount,
	|	SUM(InventoryTT.Amount) AS Amount
	|FROM
	|	InventoryTT AS InventoryTT
	|
	|GROUP BY
	|	InventoryTT.Products,
	|	InventoryTT.Characteristic,
	|	InventoryTT.Batch,
	|	InventoryTT.Ownership,
	|	InventoryTT.StructuralUnit,
	|	InventoryTT.InventoryAccountType,
	|	InventoryTT.IncomeAndExpenseItem,
	|	InventoryTT.GLAccount";
	
	Query.SetParameter("BeginDate", BeginDate);
	Query.SetParameter("EndDate", EndDate);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If Selection.Amount < Amount Then
			
			InventoryRow = TableInventory.Add();
			FillPropertyValues(InventoryRow, InventoryDetailRecord);
			InventoryRow.RecordType 			= AccumulationRecordType.Expense;
			InventoryRow.Period 				= StructureAdditionalProperties.ForPosting.Date;
			InventoryRow.Recorder 				= StructureAdditionalProperties.ForPosting.Ref;
			InventoryRow.Company 				= StructureAdditionalProperties.ForPosting.Company;
			InventoryRow.PresentationCurrency 	= StructureAdditionalProperties.ForPosting.PresentationCurrency;
			InventoryRow.Amount 				= Selection.Amount;
			InventoryRow.IncomeAndExpenseItem 	= Selection.IncomeAndExpenseItem;
			InventoryRow.GLAccount 				= Selection.GLAccount;
			InventoryRow.Active 				= True;
			Amount 								= Selection.Amount - Amount;
			InventoryRow.ContentOfAccountingRecord = Content;
			
		Else
			
			InventoryRow = TableInventory.Add();
			FillPropertyValues(InventoryRow, InventoryDetailRecord);
			InventoryRow.RecordType 				= AccumulationRecordType.Expense;
			InventoryRow.Period 					= StructureAdditionalProperties.ForPosting.Date;
			InventoryRow.Recorder 					= StructureAdditionalProperties.ForPosting.Ref;
			InventoryRow.Company 					= StructureAdditionalProperties.ForPosting.Company;
			InventoryRow.PresentationCurrency 		= StructureAdditionalProperties.ForPosting.PresentationCurrency;
			InventoryRow.Amount 					= Amount;
			InventoryRow.ContentOfAccountingRecord 	= Content;
			InventoryRow.IncomeAndExpenseItem 		= Selection.IncomeAndExpenseItem;
			InventoryRow.GLAccount 					= Selection.GLAccount;
			InventoryRow.Active 					= True;
			Amount = 0;
			
			Break;
			
		EndIf;
		
	EndDo;
	
	If Amount > 0 Then
		DistributeCosts_DistributeInventoryAmounts(Ref, StructureAdditionalProperties, TableInventory, InventoryDetailRecord, BeginDate - 1, Amount);
	EndIf;
	
EndProcedure

#EndRegion

#Region FinancialResultCalculation

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
Function GenerateFinancialResultDistributionBaseTable(StructureAdditionalProperties, DistributionBase, FilterByStructuralUnit, FilterByBusinessLine, FilterByOrder)
	
	ResultTable = New ValueTable;
	
	Query = New Query;
	
	If DistributionBase = Enums.CostAllocationMethod.SalesRevenue
		Or DistributionBase = Enums.CostAllocationMethod.CostOfGoodsSold
		Or DistributionBase = Enums.CostAllocationMethod.SalesVolume
		Or DistributionBase = Enums.CostAllocationMethod.GrossProfit Then
		
		If DistributionBase = Enums.CostAllocationMethod.SalesRevenue Then
			TextOfDatabase = "SalesTurnovers.AmountTurnover";
		ElsIf DistributionBase = Enums.CostAllocationMethod.CostOfGoodsSold Then 
			TextOfDatabase = "SalesTurnovers.CostTurnover";
		ElsIf DistributionBase = Enums.CostAllocationMethod.GrossProfit Then 
			TextOfDatabase = "SalesTurnovers.AmountTurnover - SalesTurnovers.CostTurnover";
		Else
			TextOfDatabase = "SalesTurnovers.QuantityTurnover";
		EndIf; 
		
		QueryText = 
		"SELECT ALLOWED
		|	SalesTurnovers.Company AS Company,
		|	SalesTurnovers.PresentationCurrency AS PresentationCurrency,
		|	SalesTurnovers.Products.BusinessLine AS BusinessLine,
		|	SalesTurnovers.SalesOrder AS Order,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN SalesTurnovers.Products.BusinessLine.GLAccountRevenueFromSales
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END AS GLAccountRevenueFromSales,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN SalesTurnovers.Products.BusinessLine.GLAccountCostOfSales
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END AS GLAccountCostOfSales,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN SalesTurnovers.Products.BusinessLine.ProfitGLAccount
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END AS ProfitGLAccount,
		|	&TextOfDatabase AS Base,
		|	SalesTurnovers.Department AS StructuralUnit
		|FROM
		|	AccumulationRegister.Sales.Turnovers(
		|			&BegDate,
		|			&EndDate,
		|			Auto,
		|			Company = &Company
		|				AND PresentationCurrency = &PresentationCurrency
		|				AND &FilterByStructuralUnit
		|				AND &FilterByBusinessLine
		|				AND &FilterByOrder) AS SalesTurnovers
		|WHERE
		|	SalesTurnovers.Products.BusinessLine <> VALUE(Catalog.LinesOfBusiness.Other)";
		
		QueryText = StrReplace(QueryText, "&FilterByStructuralUnit", ?(ValueIsFilled(FilterByStructuralUnit), "Department IN (&BusinessUnitsArray)", "TRUE"));
		QueryText = StrReplace(QueryText, "&FilterByBusinessLine", ?(ValueIsFilled(FilterByBusinessLine), "Products.BusinessLine IN (&BusinessLineArray)", "TRUE"));
		QueryText = StrReplace(QueryText, "&FilterByOrder", ?(ValueIsFilled(FilterByOrder), "SalesOrder IN (&OrdersArray)", "TRUE"));
		QueryText = StrReplace(QueryText, "&TextOfDatabase", TextOfDatabase);
		
	Else
		Return ResultTable;
	EndIf;
	
	Query.Text = QueryText;
	
	Query.SetParameter("BegDate"             , StructureAdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("EndDate"             , StructureAdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("Company"             , StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
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
			Query.SetParameter("BusinessLineArray", FilterByBusinessLine);
		Else
			ArrayForSelection = New Array;
			ArrayForSelection.Add(FilterByBusinessLine);
			Query.SetParameter("BusinessLineArray", FilterByBusinessLine);
		EndIf;
	EndIf;
	
	ResultTable = Query.Execute().Unload();
	
	Return ResultTable;
	
EndFunction

// Calculates the financial result.
//
// Parameters:
//  Cancel        - Boolean - check box of document posting canceling.
//
Procedure CalculateFinancialResult(Ref, StructureAdditionalProperties, ErrorsTable)
	
	// 1) Direct allocation.
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.StructuralUnit AS StructuralUnit,
	|	TableIncomeAndExpenses.PresentationCurrency AS PresentationCurrency,
	|	TableIncomeAndExpenses.BusinessLine AS BusinessLine,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableIncomeAndExpenses.BusinessLine
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ProfitGLAccount,
	|	TableIncomeAndExpenses.SalesOrder AS SalesOrder,
	|	TableIncomeAndExpenses.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	TableIncomeAndExpenses.GLAccount AS GLAccount,
	|	TableIncomeAndExpenses.AmountIncome AS AmountIncome,
	|	TableIncomeAndExpenses.AmountExpense AS AmountExpense
	|INTO TableIncomeAndExpenses
	|FROM
	|	&TableIncomeAndExpenses AS TableIncomeAndExpenses
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	IncomeAndExpenses.Company AS Company,
	|	IncomeAndExpenses.PresentationCurrency AS PresentationCurrency,
	|	IncomeAndExpenses.StructuralUnit AS StructuralUnit,
	|	IncomeAndExpenses.BusinessLine AS BusinessLine,
	|	IncomeAndExpenses.SalesOrder AS Order,
	|	IncomeAndExpenses.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN IncomeAndExpenses.BusinessLine.ProfitGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ProfitGLAccount,
	|	IncomeAndExpenses.GLAccount AS GLAccount,
	|	SUM(IncomeAndExpenses.AmountIncome) AS AmountIncome,
	|	SUM(IncomeAndExpenses.AmountExpense) AS AmountExpense
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses
	|WHERE
	|	IncomeAndExpenses.Period BETWEEN &BegDate AND &EndDate
	|	AND IncomeAndExpenses.Company = &Company
	|	AND IncomeAndExpenses.PresentationCurrency = &PresentationCurrency
	|	AND (IncomeAndExpenses.IncomeAndExpenseItem.MethodOfDistribution = VALUE(Enum.CostAllocationMethod.DoNotDistribute)
	|			OR (IncomeAndExpenses.IncomeAndExpenseItem = &COGSItem
	|				OR IncomeAndExpenses.IncomeAndExpenseItem = &RevenueItem)
	|				AND IncomeAndExpenses.BusinessLine <> VALUE(Catalog.LinesOfBusiness.Other))
	|
	|GROUP BY
	|	IncomeAndExpenses.Company,
	|	IncomeAndExpenses.PresentationCurrency,
	|	IncomeAndExpenses.StructuralUnit,
	|	IncomeAndExpenses.BusinessLine,
	|	IncomeAndExpenses.SalesOrder,
	|	IncomeAndExpenses.IncomeAndExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN IncomeAndExpenses.BusinessLine.ProfitGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	IncomeAndExpenses.GLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.PresentationCurrency,
	|	TableIncomeAndExpenses.StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLine,
	|	TableIncomeAndExpenses.SalesOrder,
	|	TableIncomeAndExpenses.IncomeAndExpenseItem,
	|	TableIncomeAndExpenses.ProfitGLAccount,
	|	TableIncomeAndExpenses.GLAccount,
	|	SUM(TableIncomeAndExpenses.AmountIncome),
	|	SUM(TableIncomeAndExpenses.AmountExpense)
	|FROM
	|	TableIncomeAndExpenses AS TableIncomeAndExpenses
	|WHERE
	|	TableIncomeAndExpenses.AmountExpense <> 0
	|
	|GROUP BY
	|	TableIncomeAndExpenses.PresentationCurrency,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.ProfitGLAccount,
	|	TableIncomeAndExpenses.BusinessLine,
	|	TableIncomeAndExpenses.SalesOrder,
	|	TableIncomeAndExpenses.IncomeAndExpenseItem,
	|	TableIncomeAndExpenses.GLAccount,
	|	TableIncomeAndExpenses.StructuralUnit";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("TableIncomeAndExpenses", StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("BegDate", StructureAdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("EndDate", StructureAdditionalProperties.ForPosting.LastBoundaryPeriod.Value);
	Query.SetParameter("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	Query.SetParameter("COGSItem", Catalogs.DefaultIncomeAndExpenseItems.GetItem("COGS"));
	Query.SetParameter("RevenueItem", Catalogs.DefaultIncomeAndExpenseItems.GetItem("Revenue"));
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		TableFinancialResult = StructureAdditionalProperties.TableForRegisterRecords.TableFinancialResult;
		
		If UseDefaultTypeOfAccounting Then
			TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
		EndIf;
		
	EndIf;
	
	SelectionQueryResult = QueryResult.Select();
	
	While SelectionQueryResult.Next() Do
		
		NewRow = TableFinancialResult.Add();
		NewRow.Period = Ref.Date;
		NewRow.Recorder = Ref;
		NewRow.Company = SelectionQueryResult.Company;
		NewRow.PresentationCurrency = SelectionQueryResult.PresentationCurrency;
		NewRow.StructuralUnit = SelectionQueryResult.StructuralUnit;
		NewRow.BusinessLine = ?(
			ValueIsFilled(SelectionQueryResult.BusinessLine),
			SelectionQueryResult.BusinessLine,
			Catalogs.LinesOfBusiness.MainLine);
		NewRow.SalesOrder = SelectionQueryResult.Order;
		NewRow.IncomeAndExpenseItem = SelectionQueryResult.IncomeAndExpenseItem;
		NewRow.GLAccount = SelectionQueryResult.GLAccount;
		NewRow.Active = True;
		
		If SelectionQueryResult.AmountIncome <> 0 Then
			NewRow.AmountIncome = SelectionQueryResult.AmountIncome;
		EndIf;
		If SelectionQueryResult.AmountExpense <> 0 Then
			NewRow.AmountExpense = SelectionQueryResult.AmountExpense;
		EndIf;
		
		NewRow.ContentOfAccountingRecord = NStr("en = 'Temporary accounts closing'; ru = 'Расчёт финансового результата';pl = 'Zamknięcie kont tymczasowych';es_ES = 'Cierre de cuentas temporal';es_CO = 'Cierre de cuentas temporal';tr = 'Geçici hesap kapatma';it = 'Chiusura conti temporanei';de = 'Abschließen von temporären Konten'", MainLanguageCode);
		
		Content = NStr("en = 'Temporary accounts closing'; ru = 'Расчёт финансового результата';pl = 'Zamknięcie kont tymczasowych';es_ES = 'Cierre de cuentas temporal';es_CO = 'Cierre de cuentas temporal';tr = 'Geçici hesap kapatma';it = 'Chiusura conti temporanei';de = 'Abschließen von temporären Konten'", MainLanguageCode);
		
		// Movements by register AccountingJournalEntries.
		If UseDefaultTypeOfAccounting And SelectionQueryResult.AmountIncome <> 0 Then
			
			NewRow = TableAccountingJournalEntries.Add();
			NewRow.Active = True;
			NewRow.Period = Ref.Date;
			NewRow.Recorder = Ref;
			NewRow.Company = SelectionQueryResult.Company;
			NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
			NewRow.AccountDr = SelectionQueryResult.GLAccount;
			NewRow.AccountCr = ?(
				ValueIsFilled(SelectionQueryResult.BusinessLine),
				SelectionQueryResult.ProfitGLAccount,
				Catalogs.LinesOfBusiness.MainLine.ProfitGLAccount);
			NewRow.Amount = SelectionQueryResult.AmountIncome;
			NewRow.Content = Content;
			
		EndIf;
		
		If UseDefaultTypeOfAccounting And SelectionQueryResult.AmountExpense <> 0 Then
			
			NewRow = TableAccountingJournalEntries.Add();
			NewRow.Active = True;
			NewRow.Period = Ref.Date;
			NewRow.Recorder = Ref;
			NewRow.Company = SelectionQueryResult.Company;
			NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
			NewRow.AccountDr = ?(
				ValueIsFilled(SelectionQueryResult.BusinessLine),
				SelectionQueryResult.BusinessLine.ProfitGLAccount,
				Catalogs.LinesOfBusiness.MainLine.ProfitGLAccount);
			NewRow.AccountCr = SelectionQueryResult.GLAccount;
			NewRow.Amount = SelectionQueryResult.AmountExpense;
			NewRow.Content = Content;
			
		EndIf;
		
	EndDo;
	
	// 2) Allocation by the allocation base.
	Query.Text =
	"SELECT ALLOWED
	|	IncomeAndExpenses.Company AS Company,
	|	IncomeAndExpenses.StructuralUnit AS StructuralUnit,
	|	IncomeAndExpenses.PresentationCurrency AS PresentationCurrency,
	|	IncomeAndExpenses.BusinessLine AS BusinessLine,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN IncomeAndExpenses.BusinessLine.ProfitGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ProfitGLAccount,
	|	IncomeAndExpenses.SalesOrder AS Order,
	|	IncomeAndExpenses.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	IncomeAndExpenses.IncomeAndExpenseItem.MethodOfDistribution AS MethodOfDistribution,
	|	IncomeAndExpenses.GLAccount AS GLAccount,
	|	SUM(IncomeAndExpenses.AmountIncome) AS AmountIncome,
	|	SUM(IncomeAndExpenses.AmountExpense) AS AmountExpense
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses
	|WHERE
	|	IncomeAndExpenses.Period BETWEEN &BegDate AND &EndDate
	|	AND IncomeAndExpenses.Company = &Company
	|	AND IncomeAndExpenses.PresentationCurrency = &PresentationCurrency
	|	AND IncomeAndExpenses.IncomeAndExpenseItem.MethodOfDistribution <> VALUE(Enum.CostAllocationMethod.DoNotDistribute)
	|	AND (IncomeAndExpenses.IncomeAndExpenseItem <> &COGSItem
	|				AND IncomeAndExpenses.IncomeAndExpenseItem <> &RevenueItem
	|			OR IncomeAndExpenses.BusinessLine = VALUE(Catalog.LinesOfBusiness.Other)
	|			OR IncomeAndExpenses.BusinessLine = VALUE(Catalog.LinesOfBusiness.EmptyRef))
	|
	|GROUP BY
	|	IncomeAndExpenses.Company,
	|	IncomeAndExpenses.StructuralUnit,
	|	IncomeAndExpenses.PresentationCurrency,
	|	IncomeAndExpenses.BusinessLine,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN IncomeAndExpenses.BusinessLine.ProfitGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	IncomeAndExpenses.SalesOrder,
	|	IncomeAndExpenses.IncomeAndExpenseItem,
	|	IncomeAndExpenses.IncomeAndExpenseItem.MethodOfDistribution,
	|	IncomeAndExpenses.GLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Company,
	|	Table.StructuralUnit,
	|	Table.PresentationCurrency,
	|	Table.BusinessLine,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Table.BusinessLine.ProfitGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	Table.SalesOrder,
	|	Table.IncomeAndExpenseItem,
	|	Table.IncomeAndExpenseItem.MethodOfDistribution,
	|	Table.GLAccount,
	|	SUM(Table.AmountIncome),
	|	SUM(Table.AmountExpense)
	|FROM
	|	TableIncomeAndExpenses AS Table
	|WHERE
	|	Table.Company = &Company
	|	AND Table.PresentationCurrency = &PresentationCurrency
	|	AND Table.IncomeAndExpenseItem.MethodOfDistribution <> VALUE(Enum.CostAllocationMethod.DoNotDistribute)
	|	AND (Table.IncomeAndExpenseItem <> &COGSItem
	|				AND Table.IncomeAndExpenseItem <> &RevenueItem
	|			OR Table.BusinessLine = VALUE(Catalog.LinesOfBusiness.Other)
	|			OR Table.BusinessLine = VALUE(Catalog.LinesOfBusiness.EmptyRef))
	|
	|GROUP BY
	|	Table.SalesOrder,
	|	Table.StructuralUnit,
	|	Table.IncomeAndExpenseItem.MethodOfDistribution,
	|	Table.GLAccount,
	|	Table.PresentationCurrency,
	|	Table.IncomeAndExpenseItem,
	|	Table.Company,
	|	Table.BusinessLine,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Table.BusinessLine.ProfitGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END
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
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		// Create the accumulation register records set Inventory and expenses accounting.
		TableFinancialResult = StructureAdditionalProperties.TableForRegisterRecords.TableFinancialResult;
		
		If UseDefaultTypeOfAccounting Then
			TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
		EndIf;
		
	Else
		
		Return;
		
	EndIf;
	
	BypassByDistributionMethod = QueryResult.Select(QueryResultIteration.ByGroups);
	
	// Bypass by the allocation methods.
	While BypassByDistributionMethod.Next() Do
		
		BypassByStructuralUnit = BypassByDistributionMethod.Select(QueryResultIteration.ByGroups);
		
		// Bypass on departments.
		While BypassByStructuralUnit.Next() Do
			
			FilterByStructuralUnit = BypassByStructuralUnit.StructuralUnit;
			
			BypassByActivityDirection = BypassByStructuralUnit.Select(QueryResultIteration.ByGroups);
			
			// Bypass by the activity directions.
			While BypassByActivityDirection.Next() Do
				
				FilterByBusinessLine = BypassByActivityDirection.BusinessLine;
				
				BypassByOrder = BypassByActivityDirection.Select(QueryResultIteration.ByGroups);
				
				// Bypass on orders.
				While BypassByOrder.Next() Do
					
					FilterByOrder = BypassByOrder.Order;
										
					// Generate allocation base table.
					BaseTable = GenerateFinancialResultDistributionBaseTable(
						StructureAdditionalProperties,
						BypassByOrder.MethodOfDistribution,
						FilterByStructuralUnit,
						Undefined,
						Undefined);
					
					If BaseTable.Count() > 0 Then
						
						BaseTable = GenerateFinancialResultDistributionBaseTable(
							StructureAdditionalProperties,
							BypassByOrder.MethodOfDistribution,
							FilterByStructuralUnit,
							FilterByBusinessLine,
							FilterByOrder);
						
						If BaseTable.Count() = 0 Then
							BaseTable = GenerateFinancialResultDistributionBaseTable(
								StructureAdditionalProperties,
								BypassByOrder.MethodOfDistribution,
								FilterByStructuralUnit,
								FilterByBusinessLine,
								Undefined);
						EndIf;
						
						If BaseTable.Count() = 0 Then
							BaseTable = GenerateFinancialResultDistributionBaseTable(
								StructureAdditionalProperties,
								BypassByOrder.MethodOfDistribution,
								FilterByStructuralUnit,
								Undefined,
								Undefined);
						EndIf;
						
					Else
						
						BaseTable = GenerateFinancialResultDistributionBaseTable(
							StructureAdditionalProperties,
							BypassByOrder.MethodOfDistribution,
							Undefined,
							FilterByBusinessLine,
							FilterByOrder);
						
						If BaseTable.Count() = 0 Then
							BaseTable = GenerateFinancialResultDistributionBaseTable(
								StructureAdditionalProperties,
								BypassByOrder.MethodOfDistribution,
								Undefined,
								FilterByBusinessLine,
								Undefined);
						EndIf;
						
						If BaseTable.Count() = 0 Then
							BaseTable = GenerateFinancialResultDistributionBaseTable(
								StructureAdditionalProperties,
								BypassByOrder.MethodOfDistribution,
								Undefined,
								Undefined,
								Undefined);
						EndIf;
						
					EndIf;
					
					If BaseTable.Count() > 0 Then
						TotalBaseDistribution = BaseTable.Total("Base");
						DirectionsQuantity  = BaseTable.Count() - 1;
					Else
						TotalBaseDistribution = 0;
						DirectionsQuantity  = 0;
					EndIf;
					
					BypassByDetails = BypassByOrder.Select(QueryResultIteration.ByGroups);
					
					// Bypass on the expenses accounts.
					While BypassByDetails.Next() Do
						
						If BaseTable.Count() = 0
							Or TotalBaseDistribution = 0 Then
							
							BaseTable = New ValueTable;
							BaseTable.Columns.Add("Company");
							BaseTable.Columns.Add("PresentationCurrency");
							BaseTable.Columns.Add("StructuralUnit");
							BaseTable.Columns.Add("BusinessLine");
							BaseTable.Columns.Add("Order");
							BaseTable.Columns.Add("GLAccountRevenueFromSales");
							BaseTable.Columns.Add("GLAccountCostOfSales");
							BaseTable.Columns.Add("ProfitGLAccount");
							BaseTable.Columns.Add("Base");
							
							TableRow = BaseTable.Add();
							TableRow.Company = BypassByDetails.Company;
							TableRow.PresentationCurrency = BypassByDetails.PresentationCurrency;
							TableRow.StructuralUnit = BypassByDetails.StructuralUnit;
							TableRow.BusinessLine = BypassByDetails.BusinessLine;
							TableRow.Order = BypassByDetails.Order;
							TableRow.GLAccountRevenueFromSales = BypassByDetails.GLAccount;
							TableRow.GLAccountCostOfSales = BypassByDetails.GLAccount;
							TableRow.ProfitGLAccount = ?(
								UseDefaultTypeOfAccounting,
								Catalogs.LinesOfBusiness.MainLine.ProfitGLAccount,
								ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef());
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
								
								CostAmount = ?(
									SumDistribution = 0, 
									0, 
									Round(DistributionDirection.Base / TotalBaseDistribution * SumDistribution, 2, 1));
								SumWasDistributed = SumWasDistributed + CostAmount;
								
								// If it is the last string - , correct amount in it to the rounding error.
								If BaseTable.IndexOf(DistributionDirection) = DirectionsQuantity Then
									CostAmount = CostAmount + SumDistribution - SumWasDistributed;
									SumWasDistributed = SumWasDistributed + CostAmount;
								EndIf;
								
								If CostAmount <> 0 Then
									
									// Movements by register Financial result.
									NewRow	= TableFinancialResult.Add();
									NewRow.Period = Ref.Date;
									NewRow.Recorder	= Ref;
									NewRow.Company	= DistributionDirection.Company;
									NewRow.PresentationCurrency	= DistributionDirection.PresentationCurrency;
									NewRow.StructuralUnit = DistributionDirection.StructuralUnit;
									NewRow.BusinessLine	 = Catalogs.LinesOfBusiness.MainLine;
									NewRow.SalesOrder	= DistributionDirection.Order;
									NewRow.Active	= True;
									
									NewRow.IncomeAndExpenseItem = BypassByDetails.IncomeAndExpenseItem;
									NewRow.GLAccount = BypassByDetails.GLAccount;
									
									If BypassByDetails.AmountIncome <> 0 Then
										NewRow.AmountIncome = CostAmount;
									ElsIf BypassByDetails.AmountExpense <> 0 Then
										NewRow.AmountExpense = CostAmount;
									EndIf;
									
									NewRow.ContentOfAccountingRecord = NStr("en = 'Temporary accounts closing'; ru = 'Расчёт финансового результата';pl = 'Zamknięcie kont tymczasowych';es_ES = 'Cierre de cuentas temporal';es_CO = 'Cierre de cuentas temporal';tr = 'Geçici hesap kapatma';it = 'Chiusura conti temporanei';de = 'Abschließen von temporären Konten'", MainLanguageCode);
									
									// Movements by register AccountingJournalEntries.
									If UseDefaultTypeOfAccounting Then
										
										NewRow = TableAccountingJournalEntries.Add();
										NewRow.Active = True;
										NewRow.Period = Ref.Date;
										NewRow.Recorder = Ref;
										NewRow.Company = DistributionDirection.Company;
										NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
										
										If BypassByDetails.AmountIncome <> 0 Then
											If CostAmount > 0 Then
												NewRow.AccountDr = BypassByDetails.GLAccount;
												NewRow.AccountCr = DistributionDirection.ProfitGLAccount;
												NewRow.Amount = CostAmount;
											Else
												NewRow.AccountDr = DistributionDirection.ProfitGLAccount;
												NewRow.AccountCr = BypassByDetails.GLAccount;
												NewRow.Amount = -CostAmount;
											EndIf;
										ElsIf BypassByDetails.AmountExpense <> 0 Then
											If CostAmount > 0 Then 
												NewRow.AccountDr = DistributionDirection.ProfitGLAccount;
												NewRow.AccountCr = BypassByDetails.GLAccount;
												NewRow.Amount = CostAmount;
											Else
												NewRow.AccountDr = BypassByDetails.GLAccount;
												NewRow.AccountCr = DistributionDirection.ProfitGLAccount;
												NewRow.Amount = -CostAmount;
											EndIf;
										EndIf;
										
										NewRow.Content = NStr("en = 'Temporary accounts closing'; ru = 'Расчёт финансового результата';pl = 'Zamknięcie kont tymczasowych';es_ES = 'Cierre de cuentas temporal';es_CO = 'Cierre de cuentas temporal';tr = 'Geçici hesap kapatma';it = 'Chiusura conti temporanei';de = 'Abschließen von temporären Konten'", MainLanguageCode);
										
									EndIf;
									
								EndIf;
								
							EndDo;
							
							If SumWasDistributed = 0 Then
								
								ErrorDescription = GenerateErrorDescriptionExpensesDistribution(
									StructureAdditionalProperties,
									BypassByDetails.GLAccount,
									BypassByOrder.MethodOfDistribution,
									?(BypassByDetails.AmountIncome <> 0,
										BypassByDetails.AmountIncome,
										BypassByDetails.AmountExpense));
										
								AddErrorIntoTable(Ref, ErrorDescription, "FinancialResultCalculation", ErrorsTable);
								
								Continue;
								
							EndIf;
							
						EndIf
						
					EndDo;
					
				EndDo;
				
			EndDo;
			
		EndDo;
		
	EndDo;
		
EndProcedure

#EndRegion

#Region PrimecostInRetailCalculationEarningAccounting

Procedure CalculateCostPriceInRetailEarningAccounting(Ref, StructureAdditionalProperties, ErrorsTable)
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	POSSummaryTurnovers.Company AS Company,
	|	POSSummaryTurnovers.PresentationCurrency AS PresentationCurrency,
	|	POSSummaryTurnovers.StructuralUnit AS StructuralUnit,
	|	POSSummaryTurnovers.Currency AS Currency,
	|	POSSummaryTurnovers.AmountCurReceipt AS AmountCurReceipt,
	|	POSSummaryTurnovers.AmountCurExpense AS AmountCurExpense,
	|	POSSummaryTurnovers.CostReceipt AS CostReceipt,
	|	POSSummaryTurnovers.CostExpense AS CostExpense,
	|	CASE
	|		WHEN POSSummaryTurnovers.AmountCurReceipt <> 0
	|			THEN (CAST(POSSummaryTurnovers.AmountCurExpense * POSSummaryTurnovers.CostReceipt / POSSummaryTurnovers.AmountCurReceipt AS NUMBER(15, 2))) - POSSummaryTurnovers.CostExpense
	|		ELSE 0
	|	END AS TotalCorrectionAmount
	|INTO TemporaryTableCorrectionAmount
	|FROM
	|	AccumulationRegister.POSSummary.Turnovers(
	|			,
	|			&DateEnd,
	|			,
	|			Company = &Company
	|				AND PresentationCurrency = &PresentationCurrency) AS POSSummaryTurnovers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	POSSummary.Company AS Company,
	|	POSSummary.PresentationCurrency AS PresentationCurrency,
	|	POSSummary.StructuralUnit AS StructuralUnit,
	|	POSSummary.Currency AS Currency,
	|	SUM(POSSummary.Cost) AS CostExpense
	|INTO TemporaryTableTotalCostPriceExpense
	|FROM
	|	AccumulationRegister.POSSummary AS POSSummary
	|WHERE
	|	POSSummary.Period BETWEEN &DateBeg AND &DateEnd
	|	AND POSSummary.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND POSSummary.Cost <> 0
	|	AND POSSummary.Company = &Company
	|	AND POSSummary.PresentationCurrency = &PresentationCurrency
	|	AND POSSummary.SalesDocument <> VALUE(Document.CashReceipt.EmptyRef)
	|
	|GROUP BY
	|	POSSummary.Company,
	|	POSSummary.PresentationCurrency,
	|	POSSummary.StructuralUnit,
	|	POSSummary.Currency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	POSSummary.Company AS Company,
	|	POSSummary.PresentationCurrency AS PresentationCurrency,
	|	POSSummary.StructuralUnit AS StructuralUnit,
	|	POSSummary.Currency AS Currency,
	|	POSSummary.SalesDocument AS SalesDocument,
	|	POSSummary.SalesDocument.Department AS DocumentSalesUnit,
	|	POSSummary.SalesDocument.StructuralUnit.RetailPriceKind.PriceCurrency AS SalesDocumentStructuralUnitPriceTypeRetailCurrencyPrices,
	|	POSSummary.SalesDocument.BusinessLine AS DocumentSalesBusinessLine,
	|	&COGSItem AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN POSSummary.SalesDocument.BusinessLine.GLAccountCostOfSales
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS DocumentSalesBusinessLineGLAccountCost,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN POSSummary.SalesDocument.StructuralUnit.GLAccountInRetail
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS DocumentSalesUnitAccountStructureInRetail,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN POSSummary.SalesDocument.StructuralUnit.MarkupGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS DocumentSalesUnitStructureMarkupAccount,
	|	CASE
	|		WHEN ISNULL(TemporaryTableTotalCostPriceExpense.CostExpense, 0) <> 0
	|			THEN CAST(POSSummary.Cost / TemporaryTableTotalCostPriceExpense.CostExpense * TemporaryTableCorrectionAmount.TotalCorrectionAmount AS NUMBER(15, 2))
	|		ELSE 0
	|	END AS CorrectionAmount
	|FROM
	|	AccumulationRegister.POSSummary AS POSSummary
	|		LEFT JOIN TemporaryTableCorrectionAmount AS TemporaryTableCorrectionAmount
	|		ON POSSummary.Company = TemporaryTableCorrectionAmount.Company
	|			AND POSSummary.PresentationCurrency = TemporaryTableCorrectionAmount.PresentationCurrency
	|			AND POSSummary.StructuralUnit = TemporaryTableCorrectionAmount.StructuralUnit
	|			AND POSSummary.Currency = TemporaryTableCorrectionAmount.Currency
	|		LEFT JOIN TemporaryTableTotalCostPriceExpense AS TemporaryTableTotalCostPriceExpense
	|		ON POSSummary.Company = TemporaryTableTotalCostPriceExpense.Company
	|			AND POSSummary.PresentationCurrency = TemporaryTableTotalCostPriceExpense.PresentationCurrency
	|			AND POSSummary.StructuralUnit = TemporaryTableTotalCostPriceExpense.StructuralUnit
	|			AND POSSummary.Currency = TemporaryTableTotalCostPriceExpense.Currency
	|WHERE
	|	POSSummary.Period BETWEEN &DateBeg AND &DateEnd
	|	AND POSSummary.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND POSSummary.Cost <> 0
	|	AND POSSummary.Company = &Company
	|	AND POSSummary.PresentationCurrency = &PresentationCurrency
	|	AND POSSummary.SalesDocument <> VALUE(Document.CashReceipt.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTableCorrectionAmount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTableTotalCostPriceExpense";
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	Query.SetParameter("DateBeg", StructureAdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd", StructureAdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	Query.SetParameter("COGSItem", Catalogs.DefaultIncomeAndExpenseItems.GetItem("COGS"));
	
	QueryResult = Query.ExecuteBatch();
	
	SelectionDetailRecords = QueryResult[2].Select();
	
	TablePOSSummary = StructureAdditionalProperties.TableForRegisterRecords.TablePOSSummary;

	// Create the accumulation register records set IncomeAndExpensesAccounting.
	TableIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses;
	
	If UseDefaultTypeOfAccounting Then
		TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
	EndIf;
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.CorrectionAmount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements on the register POSSummary.
		NewRow = TablePOSSummary.Add();
		NewRow.Period 				= Ref.Date;
		NewRow.RecordType 			= AccumulationRecordType.Expense;
		NewRow.Recorder				= Ref;
		NewRow.Company 				= SelectionDetailRecords.Company;
		NewRow.PresentationCurrency = SelectionDetailRecords.PresentationCurrency;
		NewRow.StructuralUnit 		= SelectionDetailRecords.StructuralUnit;
		NewRow.Currency 			= SelectionDetailRecords.SalesDocumentStructuralUnitPriceTypeRetailCurrencyPrices;
		NewRow.ContentOfAccountingRecord = NStr("en = 'Cost'; ru = 'Стоимость';pl = 'Koszt';es_ES = 'Coste';es_CO = 'Coste';tr = 'Maliyet';it = 'Costo';de = 'Kosten'");
		NewRow.Cost 				= SelectionDetailRecords.CorrectionAmount;
		NewRow.Active 				= True;
		
		// Movements on the register IncomeAndExpenses.
		NewRow = TableIncomeAndExpenses.Add();
		NewRow.Period 				= Ref.Date;
		NewRow.Recorder 			= Ref;
		NewRow.Company 				= SelectionDetailRecords.Company;
		NewRow.PresentationCurrency = SelectionDetailRecords.PresentationCurrency;
		NewRow.StructuralUnit 		= SelectionDetailRecords.DocumentSalesUnit;
		NewRow.BusinessLine 		= SelectionDetailRecords.DocumentSalesBusinessLine;
		NewRow.IncomeAndExpenseItem = SelectionDetailRecords.IncomeAndExpenseItem;
		NewRow.GLAccount 			= SelectionDetailRecords.DocumentSalesBusinessLineGLAccountCost;
		NewRow.AmountExpense 		= SelectionDetailRecords.CorrectionAmount;
		NewRow.Active 				= True;
		NewRow.ContentOfAccountingRecord = NStr("en = 'Record expenses'; ru = 'Отражение расходов';pl = 'Rejestr rozchodów';es_ES = 'Registrar los gastos';es_CO = 'Registrar los gastos';tr = 'Masrafların yansıtılması';it = 'Registrazione spese';de = 'Ausgaben buchen'");
		
		// Movements by register AccountingJournalEntries.
		If UseDefaultTypeOfAccounting Then
			
			NewRow = TableAccountingJournalEntries.Add();
			NewRow.Active			= True;
			NewRow.Period 			= Ref.Date;
			NewRow.Recorder 		= Ref;
			NewRow.Company 			= SelectionDetailRecords.Company;
			NewRow.PlanningPeriod 	= Catalogs.PlanningPeriods.Actual;
			NewRow.AccountDr 		= SelectionDetailRecords.DocumentSalesBusinessLineGLAccountCost;
			NewRow.AccountCr 		= SelectionDetailRecords.DocumentSalesUnitAccountStructureInRetail;
			NewRow.Content 			= NStr("en = 'Cost'; ru = 'Стоимость';pl = 'Koszt';es_ES = 'Coste';es_CO = 'Coste';tr = 'Maliyet';it = 'Costo';de = 'Kosten'");
			NewRow.Amount 			= SelectionDetailRecords.CorrectionAmount;
			
			NewRow = TableAccountingJournalEntries.Add();
			NewRow.Active			= True;
			NewRow.Period 			= Ref.Date;
			NewRow.Recorder 		= Ref;
			NewRow.Company 			= SelectionDetailRecords.Company;
			NewRow.PlanningPeriod 	= Catalogs.PlanningPeriods.Actual;
			NewRow.AccountDr 		= SelectionDetailRecords.DocumentSalesUnitAccountStructureInRetail;
			NewRow.AccountCr 		= SelectionDetailRecords.DocumentSalesUnitStructureMarkupAccount;
			NewRow.Content 			= NStr("en = 'Markup'; ru = 'Наценка';pl = 'Marża';es_ES = 'Marcar';es_CO = 'Marcar';tr = 'Fiyat artışı';it = 'Maggiorazione';de = 'Aufschlag'");
			NewRow.Amount 			= - SelectionDetailRecords.CorrectionAmount;
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ExchangeDifferencesCalculation

Procedure CalculateExchangeDifferences(Ref, StructureAdditionalProperties, ErrorsTable)
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	TableCashAssets 			= StructureAdditionalProperties.TableForRegisterRecords.TableCashAssets;
	TableCashInCashRegisters 	= StructureAdditionalProperties.TableForRegisterRecords.TableCashInCashRegisters;
	TablePayroll 				= StructureAdditionalProperties.TableForRegisterRecords.TablePayroll;
	TableAdvanceHolders 		= StructureAdditionalProperties.TableForRegisterRecords.TableAdvanceHolders;
	TableAccountsReceivable 	= StructureAdditionalProperties.TableForRegisterRecords.TableAccountsReceivable;
	TableAccountsPayable		= StructureAdditionalProperties.TableForRegisterRecords.TableAccountsPayable;
	TableIncomeAndExpenses 		= StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses;
	TableLoanSettlements 		= StructureAdditionalProperties.TableForRegisterRecords.TableLoanSettlements;
	
	TableFundsTransfersBeingProcessed = StructureAdditionalProperties.TableForRegisterRecords.TableFundsTransfersBeingProcessed;
	
	TableForeignExchangeGainsAndLosses = StructureAdditionalProperties.TableForRegisterRecords.TableForeignExchangeGainsAndLosses;
	
	If UseDefaultTypeOfAccounting Then
		TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
	EndIf;
	
	Query = New Query;
	
	Query.SetParameter("Date",					Ref.Date);
	Query.SetParameter("Ref",					Ref);
	Query.SetParameter("DateEnd",				StructureAdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("PresentationCurrency",	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Курсовая разница';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'"));
	
	Query.SetParameter("ForeignCurrencyExchangeGain",
		Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",
		Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("FundsTransfersBeingProcessedGLAccount",
		Catalogs.DefaultGLAccounts.GetDefaultGLAccount("FundsTransfersBeingProcessed"));
	Query.SetParameter("FXIncome", Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenses", Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	
	// Cash assets.
	Query.Text =
	"SELECT ALLOWED
	|	TableBalances.Company AS Company,
	|	TableBalances.PresentationCurrency AS PresentationCurrency,
	|	TableBalances.PaymentMethod AS PaymentMethod,
	|	TableBalances.CashAssetType AS CashAssetType,
	|	TableBalances.BankAccountPettyCash AS BankAccountPettyCash,
	|	TableBalances.Currency AS Currency,
	|	TableBalances.AmountBalance AS AmountBalance,
	|	TableBalances.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN TableBalances.AmountCurBalance * CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate / CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN TableBalances.AmountCurBalance / CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition
	|	END AS AmountBalanceCalc,
	|	CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN TableBalances.AmountCurBalance * CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate / CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN TableBalances.AmountCurBalance / CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition
	|	END - TableBalances.AmountBalance > 0 AS PositiveAmount
	|INTO CashAssetsBalance
	|FROM
	|	AccumulationRegister.CashAssets.Balance(
	|			&DateEnd,
	|			Company = &Company
	|				AND PresentationCurrency = &PresentationCurrency) AS TableBalances
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DateEnd, Company = &Company) AS CurrencyExchangeRateBankAccountPettyCashSliceLast
	|		ON TableBalances.Currency = CurrencyExchangeRateBankAccountPettyCashSliceLast.Currency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TableBalances.Company AS Company,
	|	TableBalances.PresentationCurrency AS PresentationCurrency,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	TableBalances.PaymentMethod AS PaymentMethod,
	|	TableBalances.CashAssetType AS CashAssetType,
	|	TableBalances.BankAccountPettyCash AS BankAccountPettyCash,
	|	TableBalances.Currency AS Currency,
	|	TableBalances.AmountBalance AS AmountBalance,
	|	TableBalances.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN TableBalances.PositiveAmount
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN TableBalances.PositiveAmount
	|			THEN TableBalances.AmountBalanceCalc - TableBalances.AmountBalance
	|		ELSE -(TableBalances.AmountBalanceCalc - TableBalances.AmountBalance)
	|	END AS Amount,
	|	CASE
	|		WHEN TableBalances.PositiveAmount
	|			THEN VALUE(Catalog.CashFlowItems.PositiveExchangeDifference)
	|		ELSE VALUE(Catalog.CashFlowItems.NegativeExchangeDifference)
	|	END AS Item,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN TableBalances.PositiveAmount
	|			THEN TableBalances.AmountBalanceCalc - TableBalances.AmountBalance
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN TableBalances.PositiveAmount
	|			THEN 0
	|		ELSE -(TableBalances.AmountBalanceCalc - TableBalances.AmountBalance)
	|	END AS AmountExpense,
	|	CASE
	|		WHEN TableBalances.PositiveAmount
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS GLAccount,
	|	CASE
	|		WHEN TableBalances.PositiveAmount
	|			THEN &FXIncome
	|		ELSE &FXExpenses
	|	END AS IncomeAndExpenseItem,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN TableBalances.PositiveAmount
	|			THEN TableBalances.BankAccountPettyCash.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS AccountDr,
	|	CASE
	|		WHEN TableBalances.PositiveAmount
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE TableBalances.BankAccountPettyCash.GLAccount
	|	END AS AccountCr,
	|	CASE
	|		WHEN TableBalances.PositiveAmount
	|				AND TableBalances.BankAccountPettyCash.GLAccount.Currency
	|			THEN TableBalances.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN NOT TableBalances.PositiveAmount
	|				AND TableBalances.BankAccountPettyCash.GLAccount.Currency
	|			THEN TableBalances.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	&ExchangeDifference AS Content
	|FROM
	|	CashAssetsBalance AS TableBalances
	|WHERE
	|	TableBalances.AmountBalanceCalc <> TableBalances.AmountBalance
	|	AND (TableBalances.AmountBalanceCalc - TableBalances.AmountBalance >= 0.005
	|			OR TableBalances.AmountBalanceCalc - TableBalances.AmountBalance <= -0.005)";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.Amount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements by registers.
		NewRow = TableCashAssets.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.RecordType = SelectionDetailRecords.RecordKindAccountingJournalEntries;
		NewRow.Active = True;
		
		NewRow = TableIncomeAndExpenses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Active = True;
		
		If UseDefaultTypeOfAccounting Then
			NewRow = TableAccountingJournalEntries.Add();
			NewRow.Active = True;
			FillPropertyValues(NewRow, SelectionDetailRecords);
		EndIf;
		
		NewRow = TableForeignExchangeGainsAndLosses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Amount = ?(SelectionDetailRecords.RecordKindAccountingJournalEntries = AccumulationRecordType.Receipt, NewRow.Amount, -NewRow.Amount);
		NewRow.Analytics = "" + SelectionDetailRecords.BankAccountPettyCash;
		NewRow.Section = "Cash assets";
		NewRow.Active = True;
	EndDo;
	
	// Cash assets in CR receipts.
	Query.Text =
	"SELECT ALLOWED
	|	TableBalances.Company AS Company,
	|	TableBalances.PresentationCurrency AS PresentationCurrency,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	TableBalances.CashCR AS CashCR,
	|	TableBalances.CashCR.CashCurrency AS Currency,
	|	TableBalances.AmountBalance AS AmountBalance,
	|	TableBalances.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|				END - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS Amount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|				END - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN 0
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS AmountExpense,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS GLAccount,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &FXIncome
	|		ELSE &FXExpenses
	|	END AS IncomeAndExpenseItem,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN TableBalances.CashCR.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS AccountDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE TableBalances.CashCR.GLAccount
	|	END AS AccountCr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|				END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|				AND TableBalances.CashCR.GLAccount.Currency
	|			THEN TableBalances.CashCR.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|				END - ISNULL(TableBalances.AmountBalance, 0) < 0
	|				AND TableBalances.CashCR.GLAccount.Currency
	|			THEN TableBalances.CashCR.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	&ExchangeDifference AS Content
	|FROM
	|	AccumulationRegister.CashInCashRegisters.Balance(&DateEnd, Company = &Company AND PresentationCurrency = &PresentationCurrency) AS TableBalances
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&DateEnd,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRateSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DateEnd, Company = &Company) AS CurrencyExchangeRateBankAccountPettyCashSliceLast
	|		ON TableBalances.CashCR.CashCurrency = CurrencyExchangeRateBankAccountPettyCashSliceLast.Currency
	|WHERE
	|	TableBalances.AmountCurBalance * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|		END <> TableBalances.AmountBalance
	|	AND (TableBalances.AmountCurBalance * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - TableBalances.AmountBalance >= 0.005
	|			OR TableBalances.AmountCurBalance * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - TableBalances.AmountBalance <= -0.005)";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.Amount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements by registers.
		NewRow = TableCashInCashRegisters.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.RecordType = SelectionDetailRecords.RecordKindAccountingJournalEntries;
		NewRow.Active = True;
		
		NewRow = TableIncomeAndExpenses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Active = True;
		
		If UseDefaultTypeOfAccounting Then
			NewRow = TableAccountingJournalEntries.Add();
			NewRow.Active = True;
			FillPropertyValues(NewRow, SelectionDetailRecords);
		EndIf;
		
		NewRow = TableForeignExchangeGainsAndLosses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Amount = ?(SelectionDetailRecords.RecordKindAccountingJournalEntries = AccumulationRecordType.Receipt, NewRow.Amount, -NewRow.Amount);
		NewRow.Analytics = "" + SelectionDetailRecords.CashCR;
		NewRow.Section = NStr("en = 'Cash in cash registers'; ru = 'Денежные средства в кассах ККМ';pl = 'Gotówka w kasach fiskalnych';es_ES = 'Efectivo en la caja';es_CO = 'Efectivo en la caja';tr = 'Yazar kasalardaki nakit';it = 'Contante nei registratori di cassa';de = 'Bargeld in Kassen'");
		NewRow.Active = True;
	EndDo;
	
	// Staff payables.
	Query.Text =
	"SELECT ALLOWED
	|	TableBalances.Company AS Company,
	|	TableBalances.PresentationCurrency AS PresentationCurrency,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	TableBalances.StructuralUnit AS StructuralUnit,
	|	TableBalances.Employee AS Employee,
	|	TableBalances.Employee.Code AS EmployeeCode,
	|	TableBalances.Currency AS Currency,
	|	TableBalances.RegistrationPeriod AS RegistrationPeriod,
	|	TableBalances.AmountBalance AS AmountBalance,
	|	TableBalances.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|				END - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS Amount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN 0
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS AmountIncome,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|				END - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE 0
	|	END AS AmountExpense,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &ForeignCurrencyExchangeLoss
	|		ELSE &ForeignCurrencyExchangeGain
	|	END AS GLAccount,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &FXExpenses
	|		ELSE &FXIncome
	|	END AS IncomeAndExpenseItem,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &ForeignCurrencyExchangeLoss
	|		ELSE TableBalances.Employee.SettlementsHumanResourcesGLAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN TableBalances.Employee.SettlementsHumanResourcesGLAccount
	|		ELSE &ForeignCurrencyExchangeGain
	|	END AS AccountCr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|				END - ISNULL(TableBalances.AmountBalance, 0) < 0
	|				AND TableBalances.Employee.SettlementsHumanResourcesGLAccount.Currency
	|			THEN TableBalances.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|				END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|				AND TableBalances.Employee.SettlementsHumanResourcesGLAccount.Currency
	|			THEN TableBalances.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	&ExchangeDifference AS Content
	|FROM
	|	AccumulationRegister.Payroll.Balance(&DateEnd, Company = &Company AND PresentationCurrency = &PresentationCurrency) AS TableBalances
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&DateEnd,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRateSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DateEnd, Company = &Company) AS CurrencyExchangeRateBankAccountPettyCashSliceLast
	|		ON TableBalances.Currency = CurrencyExchangeRateBankAccountPettyCashSliceLast.Currency
	|WHERE
	|	TableBalances.AmountCurBalance * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|		END <> TableBalances.AmountBalance
	|	AND (TableBalances.AmountCurBalance * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - TableBalances.AmountBalance >= 0.005
	|			OR TableBalances.AmountCurBalance * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - TableBalances.AmountBalance <= -0.005)";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.Amount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements by registers.
		NewRow = TablePayroll.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.RecordType = SelectionDetailRecords.RecordKindAccountingJournalEntries;
		NewRow.Active = True;
		
		NewRow = TableIncomeAndExpenses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.StructuralUnit = Undefined;
		NewRow.Active = True;
		
		If UseDefaultTypeOfAccounting Then
			NewRow = TableAccountingJournalEntries.Add();
			NewRow.Active = True;
			FillPropertyValues(NewRow, SelectionDetailRecords);
		EndIf;
		
		NewRow = TableForeignExchangeGainsAndLosses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Amount = ?(SelectionDetailRecords.RecordKindAccountingJournalEntries = AccumulationRecordType.Receipt, NewRow.Amount, -NewRow.Amount);
		NewRow.Analytics = 
			""
			+ SelectionDetailRecords.Employee + " (" + SelectionDetailRecords.EmployeeCode + ")"
			+ " / "
			+ SelectionDetailRecords.StructuralUnit
			+ " / "
			+ Format(SelectionDetailRecords.RegistrationPeriod, "DF='MMMM yyyy'")+ " g.";
		NewRow.Section = NStr("en = 'Personnel settlements'; ru = 'Расчеты с персоналом';pl = 'Rozliczenia z personelem';es_ES = 'Liquidaciones con el personal';es_CO = 'Liquidaciones con el personal';tr = 'Personel uzlaşmaları';it = 'Accordi con il personale';de = 'Abrechnungen der Mitarbeiter'");
		NewRow.Active = True;
	EndDo;
	
	// Advance holder payments.
	Query.Text =
	"SELECT ALLOWED
	|	TableBalances.Company AS Company,
	|	TableBalances.PresentationCurrency AS PresentationCurrency,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	TableBalances.Employee AS Employee,
	|	TableBalances.Document AS Document,
	|	TableBalances.Currency AS Currency,
	|	TableBalances.AmountBalance AS AmountBalance,
	|	TableBalances.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|				END - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS Amount,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(Catalog.CashFlowItems.PositiveExchangeDifference)
	|		ELSE VALUE(Catalog.CashFlowItems.NegativeExchangeDifference)
	|	END AS Item,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|				END - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN 0
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS AmountExpense,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS GLAccount,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &FXIncome
	|		ELSE &FXExpenses
	|	END AS IncomeAndExpenseItem,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN CASE
	|					WHEN ISNULL(TableBalances.AmountCurBalance, 0) > 0
	|						THEN TableBalances.Employee.AdvanceHoldersGLAccount
	|					ELSE TableBalances.Employee.OverrunGLAccount
	|				END
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS AccountDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE CASE
	|				WHEN ISNULL(TableBalances.AmountCurBalance, 0) > 0
	|					THEN TableBalances.Employee.AdvanceHoldersGLAccount
	|				ELSE TableBalances.Employee.OverrunGLAccount
	|			END
	|	END AS AccountCr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|				END - ISNULL(TableBalances.AmountBalance, 0) > 0
	|				AND CASE
	|					WHEN ISNULL(TableBalances.AmountCurBalance, 0) > 0
	|						THEN TableBalances.Employee.AdvanceHoldersGLAccount.Currency
	|					ELSE TableBalances.Employee.OverrunGLAccount.Currency
	|				END
	|			THEN TableBalances.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|				END - ISNULL(TableBalances.AmountBalance, 0) < 0
	|				AND CASE
	|					WHEN ISNULL(TableBalances.AmountCurBalance, 0) > 0
	|						THEN TableBalances.Employee.AdvanceHoldersGLAccount.Currency
	|					ELSE TableBalances.Employee.OverrunGLAccount.Currency
	|				END
	|			THEN TableBalances.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	&ExchangeDifference AS Content
	|FROM
	|	AccumulationRegister.AdvanceHolders.Balance(
	|			&DateEnd,
	|			Company = &Company
	|				AND PresentationCurrency = &PresentationCurrency) AS TableBalances
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&DateEnd,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRateSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DateEnd, Company = &Company) AS CurrencyExchangeRateBankAccountPettyCashSliceLast
	|		ON TableBalances.Currency = CurrencyExchangeRateBankAccountPettyCashSliceLast.Currency
	|WHERE
	|	TableBalances.AmountCurBalance * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|		END <> TableBalances.AmountBalance
	|	AND (TableBalances.AmountCurBalance * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - TableBalances.AmountBalance >= 0.005
	|			OR TableBalances.AmountCurBalance * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|			END - TableBalances.AmountBalance <= -0.005)";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.Amount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements by registers.
		NewRow = TableAdvanceHolders.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.RecordType = SelectionDetailRecords.RecordKindAccountingJournalEntries;
		NewRow.Active = True;
		
		NewRow = TableIncomeAndExpenses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Active = True;
		
		If UseDefaultTypeOfAccounting Then
			NewRow = TableAccountingJournalEntries.Add();
			NewRow.Active = True;
			FillPropertyValues(NewRow, SelectionDetailRecords);
		EndIf;
		
		NewRow = TableForeignExchangeGainsAndLosses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Amount = ?(SelectionDetailRecords.RecordKindAccountingJournalEntries = AccumulationRecordType.Receipt, NewRow.Amount, -NewRow.Amount);
		NewRow.Analytics =
			""
			+ SelectionDetailRecords.Employee
			+ " / "
			+ SelectionDetailRecords.Document;
		NewRow.Section = NStr("en = 'Settlements with advance holders'; ru = 'Расчеты с подотчетниками';pl = 'Rozliczenia z zaliczkobiorcami';es_ES = 'Liquidaciones con los titulares del anticipo';es_CO = 'Liquidaciones con los titulares del anticipo';tr = 'Avans sahipleriyle mutabakat';it = 'Pagamenti con titolari di anticipo';de = 'Abrechnungen mit abrechnungspflichtigen Personen'");
		NewRow.Active = True;
	EndDo;
	
	// Accounts receivable.
	Query.Text =
	"SELECT ALLOWED
	|	TableBalances.Company AS Company,
	|	TableBalances.PresentationCurrency AS PresentationCurrency,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	TableBalances.SettlementsType AS SettlementsType,
	|	TableBalances.Counterparty AS Counterparty,
	|	TableBalances.Contract AS Contract,
	|	TableBalances.Document AS Document,
	|	TableBalances.Order AS Order,
	|	ISNULL(TableBalances.AmountBalance, 0) AS AmountBalance,
	|	ISNULL(TableBalances.AmountCurBalance, 0) AS AmountCurBalance,
	|	CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|	END AS Rate
	|INTO Balances
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			&DateEnd,
	|			Company = &Company
	|				AND PresentationCurrency = &PresentationCurrency
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS TableBalances
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&DateEnd,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRateSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DateEnd, Company = &Company) AS CurrencyExchangeRateBankAccountPettyCashSliceLast
	|		ON TableBalances.Contract.SettlementsCurrency = CurrencyExchangeRateBankAccountPettyCashSliceLast.Currency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Balances.Company AS Company,
	|	Balances.PresentationCurrency AS PresentationCurrency,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	Balances.SettlementsType AS SettlementsType,
	|	Balances.Counterparty AS Counterparty,
	|	Balances.Contract AS Contract,
	|	Balances.Document AS Document,
	|	Balances.Order AS Order,
	|	Balances.AmountBalance AS AmountBalance,
	|	Balances.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance > 0
	|			THEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance
	|		ELSE -(Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance)
	|	END AS Amount,
	|	CASE
	|		WHEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance > 0
	|			THEN VALUE(Catalog.CashFlowItems.PositiveExchangeDifference)
	|		ELSE VALUE(Catalog.CashFlowItems.NegativeExchangeDifference)
	|	END AS Item,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance > 0
	|			THEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance > 0
	|			THEN 0
	|		ELSE -(Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance)
	|	END AS AmountExpense,
	|	CASE
	|		WHEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS GLAccount,
	|	CASE
	|		WHEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance > 0
	|			THEN &FXIncome
	|		ELSE &FXExpenses
	|	END AS IncomeAndExpenseItem,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance > 0
	|			THEN UNDEFINED
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS AccountDr,
	|	CASE
	|		WHEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE UNDEFINED
	|	END AS AccountCr,
	|	&ExchangeDifference AS Content,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency
	|FROM
	|	Balances AS Balances
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON Balances.Contract = CounterpartyContracts.Ref
	|WHERE
	|	Balances.AmountCurBalance * Balances.Rate <> Balances.AmountBalance
	|	AND (Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance >= 0.005
	|			OR Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance <= -0.005)";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.Amount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements by registers.
		NewRow = TableAccountsReceivable.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		If Not ValueIsFilled(NewRow.Order) Then
			NewRow.Order = Undefined;
		EndIf;
		NewRow.RecordType = SelectionDetailRecords.RecordKindAccountingJournalEntries;
		NewRow.Active = True;
		
		NewRow = TableIncomeAndExpenses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Active = True;
		
		If UseDefaultTypeOfAccounting Then
			
			NewRow = TableAccountingJournalEntries.Add();
			NewRow.Active = True;
			FillPropertyValues(NewRow, SelectionDetailRecords);
			
			If Not ValueIsFilled(NewRow.AccountDr)
				Or Not ValueIsFilled(NewRow.AccountCr) Then
				FillCounterpartyGLAccountsInRow(SelectionDetailRecords, NewRow, "Accounts receivable");
			EndIf;
			
		EndIf;
		
		NewRow = TableForeignExchangeGainsAndLosses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Currency = SelectionDetailRecords.Contract.SettlementsCurrency;
		NewRow.Amount = ?(SelectionDetailRecords.RecordKindAccountingJournalEntries = AccumulationRecordType.Receipt, NewRow.Amount, - NewRow.Amount);
		NewRow.Analytics =
			""
			+ SelectionDetailRecords.Counterparty
			+ " / "
			+ SelectionDetailRecords.Contract
			+ " / "
			+ SelectionDetailRecords.Document
			+ " / "
			+ SelectionDetailRecords.Order;
		NewRow.Section = NStr("en = 'Accounts receivable'; ru = 'Дебиторская задолженность';pl = 'Należności';es_ES = 'Cuentas a cobrar';es_CO = 'Cuentas a cobrar';tr = 'Alacak hesapları';it = 'Crediti';de = 'Offene Posten Debitoren'");
		NewRow.Active = True;
		
	EndDo;
	
	// Accounts payable.
	Query.Text =
	"SELECT ALLOWED
	|	TableBalances.Company AS Company,
	|	TableBalances.PresentationCurrency AS PresentationCurrency,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	TableBalances.SettlementsType AS SettlementsType,
	|	TableBalances.Counterparty AS Counterparty,
	|	TableBalances.Contract AS Contract,
	|	TableBalances.Document AS Document,
	|	TableBalances.Order AS Order,
	|	ISNULL(TableBalances.AmountBalance, 0) AS AmountBalance,
	|	ISNULL(TableBalances.AmountCurBalance, 0) AS AmountCurBalance,
	|	CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN 1 / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition))
	|	END AS Rate
	|INTO Balances
	|FROM
	|	AccumulationRegister.AccountsPayable.Balance(
	|			&DateEnd,
	|			Company = &Company
	|				AND PresentationCurrency = &PresentationCurrency
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS TableBalances
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&DateEnd,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRateSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DateEnd, Company = &Company) AS CurrencyExchangeRateBankAccountPettyCashSliceLast
	|		ON TableBalances.Contract.SettlementsCurrency = CurrencyExchangeRateBankAccountPettyCashSliceLast.Currency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Balances.Company AS Company,
	|	Balances.PresentationCurrency AS PresentationCurrency,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	Balances.SettlementsType AS SettlementsType,
	|	Balances.Counterparty AS Counterparty,
	|	Balances.Contract AS Contract,
	|	Balances.Document AS Document,
	|	Balances.Order AS Order,
	|	Balances.AmountBalance AS AmountBalance,
	|	Balances.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance > 0
	|			THEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance
	|		ELSE -(Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance)
	|	END AS Amount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance > 0
	|			THEN 0
	|		ELSE -(Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance)
	|	END AS AmountIncome,
	|	CASE
	|		WHEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance > 0
	|			THEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance
	|		ELSE 0
	|	END AS AmountExpense,
	|	CASE
	|		WHEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance > 0
	|			THEN &ForeignCurrencyExchangeLoss
	|		ELSE &ForeignCurrencyExchangeGain
	|	END AS GLAccount,
	|	CASE
	|		WHEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance > 0
	|			THEN &FXExpenses
	|		ELSE &FXIncome
	|	END AS IncomeAndExpenseItem,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance > 0
	|			THEN &ForeignCurrencyExchangeLoss
	|		ELSE UNDEFINED
	|	END AS AccountDr,
	|	CASE
	|		WHEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance > 0
	|			THEN UNDEFINED
	|		ELSE &ForeignCurrencyExchangeGain
	|	END AS AccountCr,
	|	&ExchangeDifference AS Content,
	|	CASE
	|		WHEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance > 0
	|			THEN Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance
	|		ELSE -(Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance)
	|	END AS AmountForPayment,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency
	|FROM
	|	Balances AS Balances
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON Balances.Contract = CounterpartyContracts.Ref
	|WHERE
	|	Balances.AmountCurBalance * Balances.Rate <> Balances.AmountBalance
	|	AND (Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance >= 0.005
	|			OR Balances.AmountCurBalance * Balances.Rate - Balances.AmountBalance <= -0.005)";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.Amount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements by registers.
		NewRow = TableAccountsPayable.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.RecordType = SelectionDetailRecords.RecordKindAccountingJournalEntries;
		NewRow.Active = True;
		
		NewRow = TableIncomeAndExpenses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Active = True;
		
		If UseDefaultTypeOfAccounting Then
			
			NewRow = TableAccountingJournalEntries.Add();
			NewRow.Active = True;
			FillPropertyValues(NewRow, SelectionDetailRecords);
			
			If Not ValueIsFilled(NewRow.AccountDr)
				Or Not ValueIsFilled(NewRow.AccountCr) Then
				FillCounterpartyGLAccountsInRow(SelectionDetailRecords, NewRow, NStr("en = 'Accounts payable'; ru = 'Кредиторская задолженность';pl = 'Zobowiązania';es_ES = 'Cuentas por pagar';es_CO = 'Cuentas por pagar';tr = 'Borç hesapları';it = 'Debiti contabili';de = 'Offene Posten Kreditoren'"));
			EndIf;
			
		EndIf;
		
		NewRow = TableForeignExchangeGainsAndLosses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Currency = SelectionDetailRecords.Contract.SettlementsCurrency;
		NewRow.Amount = ?(SelectionDetailRecords.RecordKindAccountingJournalEntries = AccumulationRecordType.Receipt, NewRow.Amount, -NewRow.Amount);
		NewRow.Analytics =
			""
			+ SelectionDetailRecords.Counterparty
			+ " / "
			+ SelectionDetailRecords.Contract
			+ " / "
			+ SelectionDetailRecords.Document
			+ " / "
			+ SelectionDetailRecords.Order;
		NewRow.Section = NStr("en = 'Accounts payable'; ru = 'Кредиторская задолженность';pl = 'Zobowiązania';es_ES = 'Cuentas por pagar';es_CO = 'Cuentas por pagar';tr = 'Borç hesapları';it = 'Debiti contabili';de = 'Offene Posten Kreditoren'");
		NewRow.Active = True;
		
	EndDo;
	
	// Loans.
	Query.Text =
	"SELECT ALLOWED
	|	TableBalances.Company AS Company,
	|	TableBalances.PresentationCurrency AS PresentationCurrency,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	TableBalances.LoanKind AS LoanKind,
	|	TableBalances.Counterparty AS Counterparty,
	|	TableBalances.LoanContract AS LoanContract,
	|	TableBalances.PrincipalDebtCurBalance * CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN CC_ExchangeRate.Rate * PC_ExchangeRate.Repetition / (PC_ExchangeRate.Rate * CC_ExchangeRate.Repetition)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN 1 / (CC_ExchangeRate.Rate * PC_ExchangeRate.Repetition / (PC_ExchangeRate.Rate * CC_ExchangeRate.Repetition))
	|	END - TableBalances.PrincipalDebtBalance AS PrincipalDebt,
	|	TableBalances.InterestCurBalance * CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN CC_ExchangeRate.Rate * PC_ExchangeRate.Repetition / (PC_ExchangeRate.Rate * CC_ExchangeRate.Repetition)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN 1 / (CC_ExchangeRate.Rate * PC_ExchangeRate.Repetition / (PC_ExchangeRate.Rate * CC_ExchangeRate.Repetition))
	|	END - TableBalances.InterestBalance AS Interest,
	|	TableBalances.CommissionCurBalance * CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN CC_ExchangeRate.Rate * PC_ExchangeRate.Repetition / (PC_ExchangeRate.Rate * CC_ExchangeRate.Repetition)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN 1 / (CC_ExchangeRate.Rate * PC_ExchangeRate.Repetition / (PC_ExchangeRate.Rate * CC_ExchangeRate.Repetition))
	|	END - TableBalances.CommissionBalance AS Commission,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	&ExchangeDifference AS Content,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableBalances.PrincipalDebtBalance AS PrincipalDebtBalance,
	|	TableBalances.PrincipalDebtCurBalance AS PrincipalDebtCurBalance,
	|	TableBalances.InterestBalance AS InterestBalance,
	|	TableBalances.InterestCurBalance AS InterestCurBalance,
	|	TableBalances.CommissionBalance AS CommissionBalance,
	|	TableBalances.CommissionCurBalance AS CommissionCurBalance
	|INTO TemporaryTableBalances
	|FROM
	|	AccumulationRegister.LoanSettlements.Balance(
	|			&DateEnd,
	|			Company = &Company
	|				AND PresentationCurrency = &PresentationCurrency) AS TableBalances
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&DateEnd,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS PC_ExchangeRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DateEnd, Company = &Company) AS CC_ExchangeRate
	|		ON TableBalances.LoanContract.SettlementsCurrency = CC_ExchangeRate.Currency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableBalances.Company AS Company,
	|	TableBalances.PresentationCurrency AS PresentationCurrency,
	|	TableBalances.Period AS Period,
	|	TableBalances.Recorder AS Recorder,
	|	TableBalances.LoanKind AS LoanKind,
	|	TableBalances.Counterparty AS Counterparty,
	|	TableBalances.LoanContract AS LoanContract,
	|	CASE
	|		WHEN TableBalances.PrincipalDebt > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RegisterRecordType,
	|	CASE
	|		WHEN TableBalances.PrincipalDebt > 0
	|			THEN TableBalances.PrincipalDebt
	|		ELSE -TableBalances.PrincipalDebt
	|	END AS PrincipalDebt,
	|	0 AS Interest,
	|	0 AS Commission,
	|	CASE
	|		WHEN TableBalances.PrincipalDebt > 0
	|			THEN TableBalances.PrincipalDebt
	|		ELSE -TableBalances.PrincipalDebt
	|	END AS Amount,
	|	TableBalances.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	TableBalances.BusinessLine AS BusinessLine,
	|	CASE
	|		WHEN TableBalances.PrincipalDebt > 0
	|			THEN TableBalances.PrincipalDebt
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN TableBalances.PrincipalDebt > 0
	|			THEN 0
	|		ELSE -TableBalances.PrincipalDebt
	|	END AS AmountExpense,
	|	CASE
	|		WHEN TableBalances.PrincipalDebt > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS GLAccount,
	|	CASE
	|		WHEN TableBalances.PrincipalDebt > 0
	|			THEN &FXIncome
	|		ELSE &FXExpenses
	|	END AS IncomeAndExpenseItem,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN TableBalances.PrincipalDebt > 0
	|			THEN DocumentLoanContract.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS AccountDr,
	|	CASE
	|		WHEN TableBalances.PrincipalDebt > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentLoanContract.GLAccount
	|	END AS AccountCr,
	|	CASE
	|		WHEN TableBalances.PrincipalDebt > 0
	|				AND DocumentLoanContract.GLAccount.Currency
	|			THEN DocumentLoanContract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableBalances.PrincipalDebt < 0
	|				AND DocumentLoanContract.GLAccount.Currency
	|			THEN DocumentLoanContract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	&ExchangeDifference AS Content,
	|	TableBalances.PrincipalDebtBalance AS AmountBalance,
	|	TableBalances.PrincipalDebtCurBalance AS AmountCurBalance,
	|	DocumentLoanContract.SettlementsCurrency AS SettlementsCurrency
	|FROM
	|	TemporaryTableBalances AS TableBalances
	|		INNER JOIN Document.LoanContract AS DocumentLoanContract
	|		ON TableBalances.LoanContract = DocumentLoanContract.Ref
	|WHERE
	|	(TableBalances.PrincipalDebt >= 0.005
	|			OR TableBalances.PrincipalDebt <= -0.005)
	|
	|UNION ALL
	|
	|SELECT
	|	TableBalances.Company,
	|	TableBalances.PresentationCurrency,
	|	TableBalances.Period,
	|	TableBalances.Recorder,
	|	TableBalances.LoanKind,
	|	TableBalances.Counterparty,
	|	TableBalances.LoanContract,
	|	CASE
	|		WHEN TableBalances.Interest > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END,
	|	0,
	|	CASE
	|		WHEN TableBalances.Interest > 0
	|			THEN TableBalances.Interest
	|		ELSE -TableBalances.Interest
	|	END,
	|	0,
	|	CASE
	|		WHEN TableBalances.Interest > 0
	|			THEN TableBalances.Interest
	|		ELSE -TableBalances.Interest
	|	END,
	|	TableBalances.ContentOfAccountingRecord,
	|	TableBalances.BusinessLine,
	|	CASE
	|		WHEN TableBalances.Interest > 0
	|			THEN TableBalances.Interest
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN TableBalances.Interest > 0
	|			THEN 0
	|		ELSE -TableBalances.Interest
	|	END,
	|	CASE
	|		WHEN TableBalances.Interest > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN TableBalances.Interest > 0
	|			THEN &FXIncome
	|		ELSE &FXExpenses
	|	END,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TableBalances.Interest > 0
	|			THEN DocumentLoanContract.InterestGLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN TableBalances.Interest > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentLoanContract.InterestGLAccount
	|	END,
	|	CASE
	|		WHEN TableBalances.Interest > 0
	|				AND DocumentLoanContract.InterestGLAccount.Currency
	|			THEN DocumentLoanContract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableBalances.Interest < 0
	|				AND DocumentLoanContract.InterestGLAccount.Currency
	|			THEN DocumentLoanContract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	&ExchangeDifference,
	|	TableBalances.InterestBalance,
	|	TableBalances.InterestCurBalance,
	|	DocumentLoanContract.SettlementsCurrency
	|FROM
	|	TemporaryTableBalances AS TableBalances
	|		INNER JOIN Document.LoanContract AS DocumentLoanContract
	|		ON TableBalances.LoanContract = DocumentLoanContract.Ref
	|WHERE
	|	(TableBalances.Interest >= 0.005
	|			OR TableBalances.Interest <= -0.005)
	|
	|UNION ALL
	|
	|SELECT
	|	TableBalances.Company,
	|	TableBalances.PresentationCurrency,
	|	TableBalances.Period,
	|	TableBalances.Recorder,
	|	TableBalances.LoanKind,
	|	TableBalances.Counterparty,
	|	TableBalances.LoanContract,
	|	CASE
	|		WHEN TableBalances.Commission > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN TableBalances.Commission > 0
	|			THEN TableBalances.Commission
	|		ELSE -TableBalances.Commission
	|	END,
	|	CASE
	|		WHEN TableBalances.Commission > 0
	|			THEN TableBalances.Commission
	|		ELSE -TableBalances.Commission
	|	END,
	|	TableBalances.ContentOfAccountingRecord,
	|	TableBalances.BusinessLine,
	|	CASE
	|		WHEN TableBalances.Commission > 0
	|			THEN TableBalances.Commission
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN TableBalances.Commission > 0
	|			THEN 0
	|		ELSE -TableBalances.Commission
	|	END,
	|	CASE
	|		WHEN TableBalances.Commission > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN TableBalances.Interest > 0
	|			THEN &FXIncome
	|		ELSE &FXExpenses
	|	END,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TableBalances.Commission > 0
	|			THEN DocumentLoanContract.CommissionGLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN TableBalances.Commission > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentLoanContract.CommissionGLAccount
	|	END,
	|	CASE
	|		WHEN TableBalances.Commission > 0
	|				AND DocumentLoanContract.CommissionGLAccount.Currency
	|			THEN DocumentLoanContract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableBalances.Commission < 0
	|				AND DocumentLoanContract.CommissionGLAccount.Currency
	|			THEN DocumentLoanContract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	&ExchangeDifference,
	|	TableBalances.CommissionBalance,
	|	TableBalances.CommissionCurBalance,
	|	DocumentLoanContract.SettlementsCurrency
	|FROM
	|	TemporaryTableBalances AS TableBalances
	|		INNER JOIN Document.LoanContract AS DocumentLoanContract
	|		ON TableBalances.LoanContract = DocumentLoanContract.Ref
	|WHERE
	|	(TableBalances.Commission >= 0.005
	|			OR TableBalances.Commission <= -0.005)";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.Amount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements by registers.
		NewRow = TableLoanSettlements.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.RecordType = SelectionDetailRecords.RegisterRecordType;
		NewRow.Active = True;
		
		NewRow = TableIncomeAndExpenses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Active = True;
		
		If UseDefaultTypeOfAccounting Then
			NewRow = TableAccountingJournalEntries.Add();
			NewRow.Active = True;
			FillPropertyValues(NewRow, SelectionDetailRecords);
		EndIf;
		
		NewRow = TableForeignExchangeGainsAndLosses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Currency = SelectionDetailRecords.SettlementsCurrency;
		NewRow.Amount = ?(SelectionDetailRecords.RegisterRecordType = AccumulationRecordType.Receipt, NewRow.Amount, -NewRow.Amount);
		NewRow.Analytics = "" + SelectionDetailRecords.Counterparty + " / " + SelectionDetailRecords.LoanContract;
		NewRow.Section = NStr("en = 'Loans'; ru = 'Расчеты по кредитам и займам';pl = 'Pożyczki';es_ES = 'Préstamos';es_CO = 'Préstamos';tr = 'Krediler';it = 'Prestiti';de = 'Darlehen'");
		NewRow.Active = True;
		
	EndDo;
	
	// funds transfers being processed
	Query.Text =
	"SELECT ALLOWED
	|	TableBalances.Company AS Company,
	|	TableBalances.PresentationCurrency AS PresentationCurrency,
	|	TableBalances.PaymentProcessor AS PaymentProcessor,
	|	TableBalances.PaymentProcessorContract AS PaymentProcessorContract,
	|	TableBalances.POSTerminal AS POSTerminal,
	|	TableBalances.Currency AS Currency,
	|	TableBalances.Document AS Document,
	|	TableBalances.AmountBalance AS AmountBalance,
	|	TableBalances.AmountCurBalance AS AmountCurBalance,
	|	TableBalances.AmountCurBalance * CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN CurrencyExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateSliceLast.Repetition)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN 1 / (CurrencyExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateSliceLast.Repetition))
	|	END - TableBalances.AmountBalance AS Amount
	|INTO TableBalances
	|FROM
	|	AccumulationRegister.FundsTransfersBeingProcessed.Balance(
	|			&DateEnd,
	|			Company = &Company
	|				AND PresentationCurrency = &PresentationCurrency) AS TableBalances
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&DateEnd,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRateSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DateEnd, Company = &Company) AS CurrencyExchangeRateSliceLast
	|		ON TableBalances.Currency = CurrencyExchangeRateSliceLast.Currency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableBalances.Company AS Company,
	|	TableBalances.PresentationCurrency AS PresentationCurrency,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	TableBalances.PaymentProcessor AS PaymentProcessor,
	|	TableBalances.PaymentProcessorContract AS PaymentProcessorContract,
	|	TableBalances.POSTerminal AS POSTerminal,
	|	TableBalances.Currency AS Currency,
	|	TableBalances.Document AS Document,
	|	TableBalances.AmountBalance AS AmountBalance,
	|	TableBalances.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN TableBalances.Amount > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN TableBalances.Amount > 0
	|			THEN TableBalances.Amount
	|		ELSE -TableBalances.Amount
	|	END AS Amount,
	|	CASE
	|		WHEN TableBalances.Amount > 0
	|			THEN VALUE(Catalog.CashFlowItems.PositiveExchangeDifference)
	|		ELSE VALUE(Catalog.CashFlowItems.NegativeExchangeDifference)
	|	END AS Item,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN TableBalances.Amount > 0
	|			THEN TableBalances.Amount
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN TableBalances.Amount > 0
	|			THEN 0
	|		ELSE -TableBalances.Amount
	|	END AS AmountExpense,
	|	CASE
	|		WHEN TableBalances.Amount > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS GLAccount,
	|	CASE
	|		WHEN TableBalances.Amount > 0
	|			THEN &FXIncome
	|		ELSE &FXExpenses
	|	END AS IncomeAndExpenseItem,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN TableBalances.Amount > 0
	|			THEN FundsGLAccount.Ref
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS AccountDr,
	|	CASE
	|		WHEN TableBalances.Amount > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE FundsGLAccount.Ref
	|	END AS AccountCr,
	|	CASE
	|		WHEN TableBalances.Amount > 0
	|				AND FundsGLAccount.Currency
	|			THEN TableBalances.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableBalances.Amount < 0
	|				AND FundsGLAccount.Currency
	|			THEN TableBalances.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	&ExchangeDifference AS Content
	|FROM
	|	TableBalances AS TableBalances
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS FundsGLAccount
	|		ON (FundsGLAccount.Ref = &FundsTransfersBeingProcessedGLAccount)
	|WHERE
	|	(TableBalances.Amount >= 0.005
	|			OR TableBalances.Amount <= -0.005)";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.Amount, 2) = 0 Then
			Continue;
		EndIf;
		
		NewRow = TableFundsTransfersBeingProcessed.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.RecordType = SelectionDetailRecords.RecordKindAccountingJournalEntries;
		NewRow.Active = True;
		
		NewRow = TableIncomeAndExpenses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Active = True;
		
		If UseDefaultTypeOfAccounting Then
			NewRow = TableAccountingJournalEntries.Add();
			NewRow.Active = True;
			FillPropertyValues(NewRow, SelectionDetailRecords);
		EndIf;
		
		NewRow = TableForeignExchangeGainsAndLosses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		If SelectionDetailRecords.RecordKindAccountingJournalEntries = AccumulationRecordType.Receipt Then
			NewRow.Amount = NewRow.Amount;
		Else
			NewRow.Amount = -NewRow.Amount;
		EndIf;
		NewRow.Analytics = "" + SelectionDetailRecords.POSTerminal;
		If ValueIsFilled(SelectionDetailRecords.Document) Then
			NewRow.Analytics = NewRow.Analytics + " / " + SelectionDetailRecords.Document;
		EndIf;
		NewRow.Section = NStr("en = 'Funds transfers being processed'; ru = 'Денежные переводы в обработке';pl = 'Przetwarzane przelewy środków';es_ES = 'Transferencias de fondos que se están procesando';es_CO = 'Transferencias de fondos que se están procesando';tr = 'Fon transferleri işleniyor';it = 'Trasferimento fondi in elaborazione';de = 'Geldtransfer in Bearbeitung'", DefaultLanguageCode);
		NewRow.Active = True;
		
	EndDo;
	
	TableForeignExchangeGainsAndLosses.GroupBy("Period, Active, Company, Analytics, Currency, Section",
												"Amount, AmountIncome, AmountExpense, AmountBalance, AmountCurBalance");
	
EndProcedure

Procedure FillCounterpartyGLAccountsInRow(Selection, NewRow, Type)
	
	StructureData = New Structure("Company, Counterparty, Contract");
	FillPropertyValues(StructureData, Selection);
	
	If Common.HasObjectAttribute("VATTaxation", Selection.Document.Metadata()) Then
		VATTaxation = Common.ObjectAttributeValue(Selection.Document, "VATTaxation");
		StructureData.Insert("VATTaxation", VATTaxation);
	EndIf;
	
	GLAccounts = GLAccountsInDocuments.GetCounterpartyGLAccounts(StructureData);
	
	If Not ValueIsFilled(NewRow.AccountDr) Then
		
		If Selection.SettlementsType = Enums.SettlementsTypes.Debt Then
			NewRow.AccountDr = ?(Type = "Accounts receivable", GLAccounts.AccountsReceivableGLAccount,
			GLAccounts.AccountsPayableGLAccount);
		Else
			NewRow.AccountDr = ?(Type = "Accounts receivable", GLAccounts.AdvancesReceivedGLAccount,
			GLAccounts.AdvancesPaidGLAccount);
		EndIf;
		
		If Common.ObjectAttributeValue(NewRow.AccountDr, "Currency") Then
			NewRow.CurrencyDr =  Selection.SettlementsCurrency;
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(NewRow.AccountCr) Then
		
		If Selection.SettlementsType = Enums.SettlementsTypes.Debt Then
			NewRow.AccountCr = ?(Type = "Accounts receivable", GLAccounts.AccountsReceivableGLAccount,
				GLAccounts.AccountsPayableGLAccount);
		Else
			NewRow.AccountCr = ?(Type = "Accounts receivable", GLAccounts.AdvancesReceivedGLAccount,
				GLAccounts.AdvancesPaidGLAccount);
		EndIf;
		
		If Common.ObjectAttributeValue(NewRow.AccountCr, "Currency") Then
			NewRow.CurrencyCr =  Selection.SettlementsCurrency;
		EndIf;
		
	EndIf;

EndProcedure

#EndRegion

#Region VATPayableCalculation

// Calculates the VAT payable.
//
// Parameters:
//  Cancel			- Boolean - check box of document posting canceling.
//  ErrorsTable		- ValueTable - table of errors of document posting
//
Procedure CalculateVATPayable(Ref, StructureAdditionalProperties, ErrorsTable)
	
	AccountTaxPayable = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("TaxPayable");
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting") And ValueIsFilled(AccountTaxPayable);
	
	// 1. Balances of VAT
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	VATInput.Company AS Company,
	|	VATInput.PresentationCurrency AS PresentationCurrency,
	|	VATInput.CompanyVATNumber AS CompanyVATNumber,
	|	VATInput.OperationType AS OperationType,
	|	VATInput.GLAccount AS GLAccount,
	|	VATInput.VATAmount AS VATAmount
	|INTO TT_VATTurnovers
	|FROM
	|	AccumulationRegister.VATInput AS VATInput
	|WHERE
	|	VATInput.Period BETWEEN &StartDate AND &EndDate
	|	AND VATInput.Company = &Company
	|
	|UNION ALL
	|
	|SELECT
	|	VATOutput.Company,
	|	VATOutput.PresentationCurrency,
	|	VATOutput.CompanyVATNumber,
	|	VATOutput.OperationType,
	|	VATOutput.GLAccount,
	|	-VATOutput.VATAmount
	|FROM
	|	AccumulationRegister.VATOutput AS VATOutput
	|WHERE
	|	VATOutput.Period BETWEEN &StartDate AND &EndDate
	|	AND VATOutput.Company = &Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_VATTurnovers.Company AS Company,
	|	TT_VATTurnovers.PresentationCurrency AS PresentationCurrency,
	|	TT_VATTurnovers.CompanyVATNumber AS CompanyVATNumber,
	|	SUM(TT_VATTurnovers.VATAmount) AS VATAmount
	|FROM
	|	TT_VATTurnovers AS TT_VATTurnovers
	|WHERE
	|	TT_VATTurnovers.OperationType = VALUE(Enum.VATOperationTypes.ReverseChargeApplied)
	|
	|GROUP BY
	|	TT_VATTurnovers.Company,
	|	TT_VATTurnovers.PresentationCurrency,
	|	TT_VATTurnovers.CompanyVATNumber
	|
	|HAVING
	|	SUM(TT_VATTurnovers.VATAmount) <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Ref AS Recorder,
	|	TRUE AS Active,
	|	&Period AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN SUM(TT_VATTurnovers.VATAmount) > 0
	|			THEN VALUE(AccumulationRecordType.Expense)
	|		ELSE VALUE(AccumulationRecordType.Receipt)
	|	END AS RecordType,
	|	TT_VATTurnovers.Company AS Company,
	|	TT_VATTurnovers.PresentationCurrency AS PresentationCurrency,
	|	TT_VATTurnovers.PresentationCurrency AS Currency,
	|	VALUE(Catalog.TaxTypes.VAT) AS TaxKind,
	|	TT_VATTurnovers.CompanyVATNumber AS CompanyVATNumber,
	|	CASE
	|		WHEN SUM(TT_VATTurnovers.VATAmount) > 0
	|			THEN &AccountTaxPayable
	|		ELSE TT_VATTurnovers.GLAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN SUM(TT_VATTurnovers.VATAmount) > 0
	|			THEN TT_VATTurnovers.GLAccount
	|		ELSE &AccountTaxPayable
	|	END AS AccountCr,
	|	&Content AS ContentOfAccountingRecord,
	|	&Content AS Content,
	|	CASE
	|		WHEN SUM(TT_VATTurnovers.VATAmount) > 0
	|			THEN SUM(TT_VATTurnovers.VATAmount)
	|		ELSE -SUM(TT_VATTurnovers.VATAmount)
	|	END AS Amount
	|FROM
	|	TT_VATTurnovers AS TT_VATTurnovers
	|WHERE
	|	TT_VATTurnovers.OperationType <> VALUE(Enum.VATOperationTypes.ReverseChargeApplied)
	|
	|GROUP BY
	|	TT_VATTurnovers.Company,
	|	TT_VATTurnovers.PresentationCurrency,
	|	TT_VATTurnovers.CompanyVATNumber,
	|	TT_VATTurnovers.GLAccount,
	|	TT_VATTurnovers.PresentationCurrency
	|
	|HAVING
	|	SUM(TT_VATTurnovers.VATAmount) <> 0";
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("StartDate", StructureAdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("EndDate", StructureAdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("Period", Ref.Date);
	Query.SetParameter("AccountTaxPayable", AccountTaxPayable);
	Query.SetParameter("Content", NStr("en = 'Tax accrued'; ru = 'Начисленные налоги';pl = 'Naliczone podatki';es_ES = 'Impuesto acumulado';es_CO = 'Impuesto acumulado';tr = 'Tahakkuk edilen vergi';it = 'Imposte maturate';de = 'Steuern angefallen'"));
	
	QueryResult = Query.ExecuteBatch();
	
	// 2. Reverse charge check
	
	ReverseChargeSelection = QueryResult[1].Select();
	If ReverseChargeSelection.Next() Then
		
		ErrorDescription = NStr(
			"en = 'Cannot post this document. For operation ""Reverse charge applied"", the VAT input does not match the VAT output.'; ru = 'Не удалось провести этот документ. Для операции ""Применяется реверсивный НДС"", входящий НДС не соответствует исходящему НДС.';pl = 'Nie można zatwierdzić dokumentu. Dla operacji ""Odwrotne obciążenie"", VAT naliczony nie jest zgodny z VAT należnym.';es_ES = 'No se puede enviar este documento. Para la operación ""Inversión impositiva aplicada"", la entrada del IVA no coincide con la salida del IVA.';es_CO = 'No se puede enviar este documento. Para la operación ""Inversión impositiva aplicada"", la entrada del IVA no coincide con la salida del IVA.';tr = 'Bu belge kaydedilemiyor. ""Karşı taraf ödemesi uygulandı"" işlemi için KDV girişi ile KDV çıkışı uyuşmuyor.';it = 'Impossibile pubblicare questo documento. Per l''operazione ""Inversione contabile applicata"", l''IVA in entrata non corrisponde all''IVA in uscita.';de = 'Fehler beim Buchen dieses Dokuments. Für die Operation „Steuerschuldumkehr verwendet“ stimmt die USt.-Eingabe nicht mit der USt.-Ausgabe überein.'"); 
		AddErrorIntoTable(Ref, ErrorDescription, "CalculateVATPayable", ErrorsTable);
		
		Return;
		
	EndIf;
	
	// 3. Movements by registers TaxPayable and AccountingJournalEntries
	
	ResultTable = QueryResult[2].Unload();
	
	If UseDefaultTypeOfAccounting Then
		
		TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
		
		For Each Result In ResultTable Do
			FillPropertyValues(TableAccountingJournalEntries.Add(),Result);
		EndDo;
		
	EndIf;
	
	ResultTable.GroupBy(
		"Recorder, Period, RecordType, TaxKind, Company, PresentationCurrency, CompanyVATNumber, ContentOfAccountingRecord",
		"Amount");
	
	TableTaxPayable = StructureAdditionalProperties.TableForRegisterRecords.TableTaxPayable;
	TableTaxPayable = ResultTable;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableTaxPayable = TableTaxPayable;
	
EndProcedure

#EndRegion

Procedure InitializeTableForRegisterRecords(StructureAdditionalProperties)
	
	TableForRegisterRecords = StructureAdditionalProperties.TableForRegisterRecords;
	TableForRegisterRecords.Insert("TableForeignExchangeGainsAndLosses" 	, GetRegisterColumns("InformationRegisters", "ForeignExchangeGainsAndLosses"));
	TableForRegisterRecords.Insert("TableMonthEndErrors" 					, GetRegisterColumns("InformationRegisters", "MonthEndErrors"));
	
	TableForRegisterRecords.Insert("TableCashInCashRegisters"				, GetRegisterColumns("AccumulationRegisters", "CashInCashRegisters"));
	TableForRegisterRecords.Insert("TableCashAssets" 						, GetRegisterColumns("AccumulationRegisters", "CashAssets"));
	TableForRegisterRecords.Insert("TablePayroll" 							, GetRegisterColumns("AccumulationRegisters", "Payroll"));
	TableForRegisterRecords.Insert("TableAdvanceHolders" 					, GetRegisterColumns("AccumulationRegisters", "AdvanceHolders"));
	TableForRegisterRecords.Insert("TableAccountsReceivable" 				, GetRegisterColumns("AccumulationRegisters", "AccountsReceivable"));
	TableForRegisterRecords.Insert("TableAccountsPayable" 					, GetRegisterColumns("AccumulationRegisters", "AccountsPayable"));
	TableForRegisterRecords.Insert("TableIncomeAndExpenses" 				, GetRegisterColumns("AccumulationRegisters", "IncomeAndExpenses"));
	TableForRegisterRecords.Insert("TableLoanSettlements" 					, GetRegisterColumns("AccumulationRegisters", "LoanSettlements"));
	TableForRegisterRecords.Insert("TableFundsTransfersBeingProcessed" 		, GetRegisterColumns("AccumulationRegisters", "FundsTransfersBeingProcessed"));
	TableForRegisterRecords.Insert("TablePOSSummary"						, GetRegisterColumns("AccumulationRegisters", "POSSummary"));
	TableForRegisterRecords.Insert("TableFinancialResult"					, GetRegisterColumns("AccumulationRegisters", "FinancialResult"));
	TableForRegisterRecords.Insert("TableInventory"							, GetRegisterColumns("AccumulationRegisters", "Inventory"));
	TableForRegisterRecords.Insert("TableSales"								, GetRegisterColumns("AccumulationRegisters", "Sales"));
	TableForRegisterRecords.Insert("TableTaxPayable" 						, GetRegisterColumns("AccumulationRegisters", "TaxPayable"));
	// begin Drive.FullVersion
	TableForRegisterRecords.Insert("TableWorkInProgress" 					, GetRegisterColumns("AccumulationRegisters", "WorkInProgress"));
	// end Drive.FullVersion
	TableForRegisterRecords.Insert("TableCostOfSubcontractorGoods" 			, GetRegisterColumns("AccumulationRegisters", "CostOfSubcontractorGoods"));
	
EndProcedure

// Adds additional attributes necessary for document
// posting to passed structure.
//
// Parameters:
//  StructureAdditionalProperties - Structure of additional document properties.
//
Procedure AddAttributesToAdditionalPropertiesForPosting(Date, StructureAdditionalProperties)
	
	InitialPeriodBoundary	= New Boundary(BegOfMonth(Date), BoundaryType.Including);
	LastBoundaryPeriod		= New Boundary(EndOfMonth (Date), BoundaryType.Including);
	BeginOfPeriodningDate	= BegOfMonth(Date);
	EndDatePeriod			= EndOfMonth(Date);
	
	StructureAdditionalProperties.ForPosting.Insert("EmptyInventoryAccountType", Enums.InventoryAccountTypes.EmptyRef());
	StructureAdditionalProperties.ForPosting.Insert("EmptyAccount",				ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef());
	StructureAdditionalProperties.ForPosting.Insert("InitialPeriodBoundary",	InitialPeriodBoundary);
	StructureAdditionalProperties.ForPosting.Insert("LastBoundaryPeriod",		LastBoundaryPeriod);
	StructureAdditionalProperties.ForPosting.Insert("BeginOfPeriodningDate",	BeginOfPeriodningDate);
	StructureAdditionalProperties.ForPosting.Insert("EndDatePeriod",			EndDatePeriod);
	
EndProcedure

Function ThereAreRecordsInPreviousPeriods(Period, Company)
	
	Query = New Query("
	|SELECT ALLOWED TOP 1
	|	1
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Period < &Period
	|	AND Inventory.Company = &Company
	|");
	
	Query.SetParameter("Period", Period);
	Query.SetParameter("Company", Company);
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
EndFunction

Function GetRegisterColumns(Register, NameRegister)
	
	ValueTable = New ValueTable;
	For Each Atribut In Metadata[Register][NameRegister].Dimensions Do
		ValueTable.Columns.Add(Atribut.Name, Atribut.Type);
	EndDo;
	For Each Atribut In Metadata[Register][NameRegister].Resources Do
		ValueTable.Columns.Add(Atribut.Name, Atribut.Type);
	EndDo;
	For Each Atribut In Metadata[Register][NameRegister].Attributes Do
		ValueTable.Columns.Add(Atribut.Name, Atribut.Type);
	EndDo;
	For Each Atribut In Metadata[Register][NameRegister].StandardAttributes Do
		ValueTable.Columns.Add(Atribut.Name, Atribut.Type);
	EndDo;
	
	Return ValueTable;
EndFunction	

Procedure GroupRecordTables(TableForRegisterRecords, AccountingPolicy)
	
	TableInventory = TableForRegisterRecords.TableInventory;
	TableInventory.GroupBy("Period, Active, RecordType, Company, PresentationCurrency, Products, Characteristic, Batch, Ownership,
		| StructuralUnit, CostObject, InventoryAccountType, StructuralUnitCorr, CorrGLAccount, ProductsCorr,CharacteristicCorr, BatchCorr,
		| CustomerCorrOrder, Specification, SpecificationCorr, CorrSalesOrder, SourceDocument, Department, Responsible, VATRate, FixedCost,
		| ProductionExpenses, Return, ContentOfAccountingRecord, RetailTransferEarningAccounting, SalesRep, Counterparty, Currency, SalesOrder,
		| CostObjectCorr, CorrInventoryAccountType, GLAccount, IncomeAndExpenseItem, CorrIncomeAndExpenseItem, OwnershipCorr", "Quantity, Amount");
	
	DeleteValueTableRow(TableInventory, New Structure("Quantity, Amount",0,0));
	TableForRegisterRecords.TableInventory = TableInventory;
	
	// begin Drive.FullVersion
	TableWorkInProgress = TableForRegisterRecords.TableWorkInProgress;
	TableWorkInProgress.GroupBy("Period, Active, RecordType, Company, PresentationCurrency, StructuralUnit, CostObject, Products, Characteristic", "Quantity, Amount");
	DeleteValueTableRow(TableWorkInProgress, New Structure("Quantity, Amount",0,0));
	TableForRegisterRecords.TableWorkInProgress = TableWorkInProgress;
	// end Drive.FullVersion
	
	TableSales = TableForRegisterRecords.TableSales;
	TableSales.GroupBy("Period, Active, Products, Characteristic, Batch, Ownership, Document, VATRate, Company, PresentationCurrency, Counterparty, 
		| Currency, SalesOrder, Department, Responsible", "Quantity, Amount, VATAmount, AmountCur, VATAmountCur, Cost");
	DeleteValueTableRow(TableSales, New Structure("Quantity, Amount, VATAmount, AmountCur, VATAmountCur, Cost", 0, 0, 0, 0, 0, 0));
	TableForRegisterRecords.TableSales = TableSales;
	
	TableFinancialResult = TableForRegisterRecords.TableFinancialResult;
	TableFinancialResult.GroupBy("Period, Active, Company, PresentationCurrency, StructuralUnit, BusinessLine, SalesOrder, IncomeAndExpenseItem,
		| GLAccount, ContentOfAccountingRecord", "AmountIncome, AmountExpense");
	DeleteValueTableRow(TableFinancialResult, New Structure("AmountIncome, AmountExpense",0 , 0));
	TableForRegisterRecords.TableFinancialResult = TableFinancialResult;
	
	If AccountingPolicy.UseDefaultTypeOfAccounting Then
		TableAccountingJournalEntries = TableForRegisterRecords.TableAccountingJournalEntries;
		TableAccountingJournalEntries.GroupBy("Period, Active, AccountDr, AccountCr, Company, PlanningPeriod, CurrencyDr, CurrencyCr, Content", "Amount, AmountCurDr, AmountCurCr");
		DeleteValueTableRow(TableAccountingJournalEntries, New Structure("Amount, AmountCurDr, AmountCurCr", 0, 0, 0));
		TableForRegisterRecords.TableAccountingJournalEntries = TableAccountingJournalEntries;
	EndIf;
	
	TableIncomeAndExpenses = TableForRegisterRecords.TableIncomeAndExpenses;
	TableIncomeAndExpenses.GroupBy("Period, Active, Company, PresentationCurrency, StructuralUnit, BusinessLine, SalesOrder, IncomeAndExpenseItem, 
		|ContentOfAccountingRecord, OfflineRecord, GLAccount", "AmountIncome, AmountExpense");
	DeleteValueTableRow(TableIncomeAndExpenses, New Structure("AmountIncome, AmountExpense", 0, 0));
	TableForRegisterRecords.TableIncomeAndExpenses = TableIncomeAndExpenses;
	
EndProcedure

Procedure DeleteValueTableRow(ValueTable,FilterParameters)
	
	ArrayRows = ValueTable.FindRows(FilterParameters);
	
	For Each Row In ArrayRows Do
		ValueTable.Delete(Row);
	EndDo;
	
EndProcedure

Procedure TemporaryConvertTable(Table, NameTable, StructureAdditionalProperties)
	
	Query = New Query();
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	If Query.TempTablesManager.Tables.Find(NameTable) <> Undefined Then
		Query.Text = "DROP "+ NameTable;
		Query.Execute();
	EndIf;

	If Table<> Undefined Then
		Query.Text = 
		"SELECT 
		|	*
		|INTO #TableName
		|FROM
		|	&Table AS Table";
		
		Query.Text = StrReplace(Query.Text,"#TableName", NameTable);
		Query.SetParameter("Table", Table);
		
		Query.Execute();
	EndIf;
	
EndProcedure

#EndRegion

#EndIf