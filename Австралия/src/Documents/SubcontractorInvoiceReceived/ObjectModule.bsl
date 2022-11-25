#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnCopy(CopiedObject)
	
	IncomingDocumentNumber = "";
	IncomingDocumentDate = "";
	
	Prepayment.Clear();
	PrepaymentVAT.Clear();
	
	ForOpeningBalancesOnly = False;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	FillingStrategy = New Map;
	FillingStrategy[Type("DocumentRef.SubcontractorOrderIssued")] = "FillBySubcontractorOrderIssued";
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy);
	
	Allocation.Clear();
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not ManualAllocation And WriteMode = DocumentWriteMode.Posting Then
		Allocate();
	EndIf;
	
	If Counterparty.DoOperationsByOrders Then
		For Each TabularSectionRow In Prepayment Do
			TabularSectionRow.Order = BasisDocument;
		EndDo;
	EndIf;
	
	DocumentAmount = Products.Total("Total");
	DocumentTax = Products.Total("VATAmount");
	DocumentSubtotal = DocumentAmount - DocumentTax;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If ForOpeningBalancesOnly Then
		CheckedAttributes.Clear();
		Return;
	EndIf;
	
	If Products.Count() > 0 Then
		CheckedAttributes.Add("StructuralUnit");
	EndIf;
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	BatchesServer.CheckFilling(ThisObject, Cancel);
	
	//Cash flow projection
	Amount = Products.Total("Amount");
	VATAmount = Products.Total("VATAmount");
	
	PaymentTermsServer.CheckRequiredAttributes(ThisObject, CheckedAttributes, Cancel);
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);
	
	If ManualAllocation And Not CheckAllocationCorrectness() Then
		Cancel = True;
	EndIf;
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	// Document data initialization.
	Documents.SubcontractorInvoiceReceived.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Limit Exceed Control
	DriveServer.CheckLimitsExceed(ThisObject, False, Cancel);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectCostOfSubcontractorGoods(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPurchases(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectStockTransferredToThirdParties(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsReceivedNotInvoiced(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUsingPaymentTermsInDocuments(Ref, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// VAT
	DriveServer.ReflectVATIncurred(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectVATInput(AdditionalProperties, RegisterRecords, Cancel);
	
	// Offline registers
	DriveServer.ReflectLandedCosts(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	// Subordinate tax invoice
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.SubcontractorInvoiceReceived.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

Procedure UndoPosting(Cancel)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	// Subordinate tax invoice
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.UndoPosting, Ref, DeletionMark);
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.SubcontractorInvoiceReceived.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	// Subordinate tax invoice
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(AdditionalProperties.WriteMode, Ref, DeletionMark);
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, AdditionalProperties.WriteMode, DeletionMark, Company, Date, AdditionalProperties);
			
	EndIf;
	
EndProcedure

#EndRegion

#Region Internal

// Procedure fills advances.
//
Procedure FillPrepayment() Export
	
	ParentCompany = DriveServer.GetCompany(Company);
	ExchangeRateMethod = DriveServer.GetExchangeMethod(Company);
	
	OrdersTable = New ValueTable;
	OrdersTable.Columns.Add("Order");
	OrdersTable.Columns.Add("Total");
	OrdersTable.Columns.Add("TotalCalc");
	
	NewRow = OrdersTable.Add();
	
	If Not Counterparty.DoOperationsByOrders Then
		NewRow.Order = Undefined;
	Else
		NewRow.Order = BasisDocument;
	EndIf;
	
	NewRow.Total = Products.Total("Total");
	NewRow.TotalCalc = DriveServer.RecalculateFromCurrencyToCurrency(
		NewRow.Total,
		ExchangeRateMethod,
		ExchangeRate,
		ContractCurrencyExchangeRate,
		Multiplicity,
		ContractCurrencyMultiplicity);
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(AccountsPayableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsPayableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryAccountsPayableBalances
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.Contract AS Contract,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.Order AS Order,
	|		AccountsPayableBalances.AmountBalance AS AmountBalance,
	|		AccountsPayableBalances.AmountCurBalance AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsPayable.Balance(
	|				&Period,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					AND Order IN (&Order)
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsVendorSettlements.Contract,
	|		DocumentRegisterRecordsVendorSettlements.Document,
	|		DocumentRegisterRecordsVendorSettlements.Order,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -DocumentRegisterRecordsVendorSettlements.Amount
	|			ELSE DocumentRegisterRecordsVendorSettlements.Amount
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -DocumentRegisterRecordsVendorSettlements.AmountCur
	|			ELSE DocumentRegisterRecordsVendorSettlements.AmountCur
	|		END
	|	FROM
	|		AccumulationRegister.AccountsPayable AS DocumentRegisterRecordsVendorSettlements
	|	WHERE
	|		DocumentRegisterRecordsVendorSettlements.Recorder = &Ref
	|		AND DocumentRegisterRecordsVendorSettlements.Company = &Company
	|		AND DocumentRegisterRecordsVendorSettlements.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsVendorSettlements.Contract = &Contract
	|		AND DocumentRegisterRecordsVendorSettlements.Order IN(&Order)
	|		AND DocumentRegisterRecordsVendorSettlements.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON AccountsPayableBalances.Contract = CounterpartyContracts.Ref
	|
	|GROUP BY
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	CounterpartyContracts.SettlementsCurrency
	|
	|HAVING
	|	SUM(AccountsPayableBalances.AmountCurBalance) < 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.SettlementsCurrency AS SettlementsCurrency,
	|	-AccountsPayableBalances.AmountCurBalance AS SettlementsAmount,
	|	-AccountsPayableBalances.AmountBalance AS PaymentAmount,
	|	CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN CASE
	|					WHEN AccountsPayableBalances.AmountBalance <> 0
	|						THEN AccountsPayableBalances.AmountCurBalance / AccountsPayableBalances.AmountBalance
	|					ELSE 1
	|				END
	|		ELSE CASE
	|				WHEN AccountsPayableBalances.AmountCurBalance <> 0
	|					THEN AccountsPayableBalances.AmountBalance / AccountsPayableBalances.AmountCurBalance
	|				ELSE 1
	|			END
	|	END AS ExchangeRate,
	|	1 AS Multiplicity
	|FROM
	|	TemporaryAccountsPayableBalances AS AccountsPayableBalances
	|
	|ORDER BY
	|	Document";
	
	Query.SetParameter("Order", OrdersTable.UnloadColumn("Order"));
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Contract", Contract);
	Query.SetParameter("Period", EndOfDay(Date) + 1);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("ExchangeRateMethod", ExchangeRateMethod);
	
	Prepayment.Clear();
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		FoundRow = OrdersTable.Find(Selection.Order, "Order");
		
		If FoundRow.TotalCalc = 0 Then
			Continue;
		EndIf;
		
		NewRow = Prepayment.Add();
		FillPropertyValues(NewRow, Selection);
		
		If Selection.SettlementsAmount <= FoundRow.TotalCalc Then
			
			FoundRow.TotalCalc = FoundRow.TotalCalc - Selection.SettlementsAmount;
			
		Else
			
			NewRow.SettlementsAmount = FoundRow.TotalCalc;
			NewRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				NewRow.SettlementsAmount,
				ExchangeRateMethod,
				Selection.ExchangeRate,
				1,
				Selection.Multiplicity,
				1);
			
			FoundRow.TotalCalc = 0;
			
		EndIf;
		
		NewRow.AmountDocCur = DriveServer.RecalculateFromCurrencyToCurrency(
			NewRow.SettlementsAmount,
			ExchangeRateMethod,
			ContractCurrencyExchangeRate,
			ExchangeRate,
			ContractCurrencyMultiplicity,
			Multiplicity);
		
	EndDo;
	
	WorkWithVAT.FillPrepaymentVATFromVATInput(ThisObject);
	
EndProcedure

// Procedure of document filling based on subcontractor order issued.
//
// Parameters:
// FillingData - Structure - Document filling data
//
Procedure FillBySubcontractorOrderIssued(FillingData) Export
	
	OrdersArray = New Array;
	OrdersArray.Add(FillingData);
	
	BasisDocument = FillingData;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SubcontractorOrderIssued.Ref AS Ref,
	|	SubcontractorOrderIssued.Posted AS Posted,
	|	SubcontractorOrderIssued.Closed AS Closed,
	|	SubcontractorOrderIssued.OrderState AS OrderState,
	|	SubcontractorOrderIssued.StructuralUnit AS StructuralUnit,
	|	SubcontractorOrderIssued.Company AS Company,
	|	SubcontractorOrderIssued.CompanyVATNumber AS CompanyVATNumber,
	|	SubcontractorOrderIssued.Counterparty AS Counterparty,
	|	SubcontractorOrderIssued.Contract AS Contract,
	|	SubcontractorOrderIssued.DocumentCurrency AS DocumentCurrency,
	|	SubcontractorOrderIssued.AmountIncludesVAT AS AmountIncludesVAT,
	|	SubcontractorOrderIssued.IncludeVATInPrice AS IncludeVATInPrice,
	|	SubcontractorOrderIssued.VATTaxation AS VATTaxation,
	|	SubcontractorOrderIssued.AutomaticVATCalculation AS AutomaticVATCalculation
	|INTO TT_SubcontractorOrders
	|FROM
	|	Document.SubcontractorOrderIssued AS SubcontractorOrderIssued
	|WHERE
	|	SubcontractorOrderIssued.Ref IN(&OrdersArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_SubcontractorOrders.Ref AS Order,
	|	TT_SubcontractorOrders.Posted AS Posted,
	|	TT_SubcontractorOrders.Closed AS Closed,
	|	TT_SubcontractorOrders.OrderState AS OrderState,
	|	TT_SubcontractorOrders.StructuralUnit AS StructuralUnit,
	|	TT_SubcontractorOrders.Company AS Company,
	|	TT_SubcontractorOrders.CompanyVATNumber AS CompanyVATNumber,
	|	TT_SubcontractorOrders.Counterparty AS Counterparty,
	|	TT_SubcontractorOrders.Contract AS Contract,
	|	TT_SubcontractorOrders.DocumentCurrency AS DocumentCurrency,
	|	TT_SubcontractorOrders.AmountIncludesVAT AS AmountIncludesVAT,
	|	TT_SubcontractorOrders.IncludeVATInPrice AS IncludeVATInPrice,
	|	TT_SubcontractorOrders.VATTaxation AS VATTaxation,
	|	TT_SubcontractorOrders.AutomaticVATCalculation AS AutomaticVATCalculation,
	|	DC_ExchRates.Rate AS ExchangeRate,
	|	DC_ExchRates.Repetition AS Multiplicity,
	|	CC_ExchRates.Rate AS ContractCurrencyExchangeRate,
	|	CC_ExchRates.Repetition AS ContractCurrencyMultiplicity
	|FROM
	|	TT_SubcontractorOrders AS TT_SubcontractorOrders
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON TT_SubcontractorOrders.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS DC_ExchRates
	|		ON TT_SubcontractorOrders.DocumentCurrency = DC_ExchRates.Currency
	|			AND TT_SubcontractorOrders.Company = DC_ExchRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS CC_ExchRates
	|		ON (Contracts.SettlementsCurrency = CC_ExchRates.Currency)
	|			AND TT_SubcontractorOrders.Company = CC_ExchRates.Company";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		VerifiedAttributesValues = New Structure("OrderState, Closed, Posted, Order, Ref");
		FillPropertyValues(VerifiedAttributesValues, Selection);
		VerifiedAttributesValues.Ref = Ref;
		
		Documents.SubcontractorOrderIssued.CheckEnterBasedOnSubcontractorOrder(VerifiedAttributesValues);
		
	EndDo;
	
	FillPropertyValues(ThisObject, Selection, , "Posted");
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref",					Ref);
	DocumentData.Insert("Counterparty",			Counterparty);
	DocumentData.Insert("AmountIncludesVAT",	AmountIncludesVAT);
	
	Documents.SubcontractorInvoiceReceived.FillBySubcontractorOrder(
		DocumentData,
		New Structure("OrdersArray", OrdersArray),
		Products,
		Inventory,
		ByProducts);
	
	If Products.Count() = 0 Then
		If OrdersArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 has already been invoiced.'; ru = 'Для %1 уже зарегистрирован инвойс.';pl = '%1 został już zafakturowany.';es_ES = '%1 ha sido facturado ya.';es_CO = '%1 ha sido facturado ya.';tr = '%1 zaten faturalandırıldı.';it = '%1 è già stato fatturato.';de = '%1 wurde bereits in Rechnung gestellt.'"),
				OrdersArray[0]);
		Else
			MessageText = NStr("en = 'The selected orders have already been invoiced.'; ru = 'Для выбранных заказов уже зарегистрированы инвойсы.';pl = 'Wybrane zamówienia zostały już zafakturowane.';es_ES = 'Las facturas seleccionadas han sido facturadas ya.';es_CO = 'Las facturas seleccionadas han sido facturadas ya.';tr = 'Seçilen siparişler zaten faturalandırıldı.';it = 'Gli ordini selezionati sono già stati fatturati.';de = 'Die ausgewählten Aufträge wurden bereits in Rechnung gestellt.'");
		EndIf;
		CommonClientServer.MessageToUser(MessageText, Ref);
	EndIf;
	
	DocumentAmount = Products.Total("Total");
	DocumentTax = Products.Total("VATAmount");
	DocumentSubtotal = DocumentAmount - DocumentTax;
	
	PaymentTermsServer.FillPaymentCalendarFromContract(ThisObject);
	
EndProcedure

Procedure Allocate() Export
	
	Cancel = False;
	WriteMode = DocumentWriteMode.Posting;
	InventoryOwnershipServer.FillMainTableColumn(ThisObject, WriteMode, Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	Query = New Query;
	
	Query.SetParameter("TableProduction",	Products);
	Query.SetParameter("TableInventory",	Inventory);
	Query.SetParameter("TableByProducts",	ByProducts);
	Query.SetParameter("StructuralUnit",	StructuralUnit);
	
	Query.SetParameter("UseCharacteristics",	GetFunctionalOption("UseCharacteristics"));
	Query.SetParameter("UseBatches",			GetFunctionalOption("UseBatches"));
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT
	|	ProductionProducts.LineNumber AS LineNumber,
	|	ProductionProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProductionProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	ProductionProducts.Ownership AS Ownership,
	|	ProductionProducts.Specification AS Specification,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	ProductionProducts.StructuralUnit AS StructuralUnit,
	|	ProductionProducts.MeasurementUnit AS MeasurementUnit,
	|	ProductionProducts.Quantity AS Quantity
	|INTO TableProduction
	|FROM
	|	&TableProduction AS ProductionProducts
	|WHERE
	|	ProductionProducts.Quantity > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableProduction.LineNumber) AS CorrLineNumber,
	|	TableProduction.Products AS CorrProducts,
	|	TableProduction.Characteristic AS CorrCharacteristic,
	|	TableProduction.Batch AS CorrBatch,
	|	TableProduction.Ownership AS CorrOwnership,
	|	TableProduction.Specification AS Specification,
	|	TableProduction.InventoryGLAccount AS CorrGLAccount,
	|	CatalogProducts.MeasurementUnit AS CorrMeasurementUnit,
	|	TableProduction.StructuralUnit AS CorrStructuralUnit,
	|	SUM(TableProduction.Quantity * ISNULL(CatalogUOM.Factor, 1)) AS CorrQuantity
	|INTO TemporaryTableVT
	|FROM
	|	TableProduction AS TableProduction
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON TableProduction.MeasurementUnit = CatalogUOM.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON TableProduction.Products = CatalogProducts.Ref
	|
	|GROUP BY
	|	TableProduction.Batch,
	|	TableProduction.Ownership,
	|	CatalogProducts.MeasurementUnit,
	|	TableProduction.Specification,
	|	TableProduction.Characteristic,
	|	TableProduction.InventoryGLAccount,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Products
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableVT.CorrLineNumber AS CorrLineNumber,
	|	TemporaryTableVT.CorrProducts AS CorrProducts,
	|	TemporaryTableVT.CorrCharacteristic AS CorrCharacteristic,
	|	TemporaryTableVT.CorrBatch AS CorrBatch,
	|	TemporaryTableVT.CorrOwnership AS CorrOwnership,
	|	TemporaryTableVT.Specification AS Specification,
	|	TemporaryTableVT.CorrGLAccount AS CorrGLAccount,
	|	TemporaryTableVT.CorrMeasurementUnit AS CorrMeasurementUnit,
	|	TemporaryTableVT.CorrStructuralUnit AS CorrStructuralUnit,
	|	TemporaryTableVT.CorrQuantity AS CorrQuantity,
	|	FALSE AS Distributed
	|FROM
	|	TemporaryTableVT AS TemporaryTableVT
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	TableProductsContent.CorrLineNumber AS CorrLineNumber,
	|	TableProductsContent.CorrProducts AS CorrProducts,
	|	TableProductsContent.CorrCharacteristic AS CorrCharacteristic,
	|	TableProductsContent.CorrBatch AS CorrBatch,
	|	TableProductsContent.CorrOwnership AS CorrOwnership,
	|	TableProductsContent.Specification AS Specification,
	|	TableProductsContent.CorrGLAccount AS CorrGLAccount,
	|	TableProductsContent.CorrMeasurementUnit AS CorrMeasurementUnit,
	|	TableProductsContent.CorrStructuralUnit AS CorrStructuralUnit,
	|	TableProductsContent.CorrQuantity AS CorrQuantity,
	|	CASE
	|		WHEN TableMaterials.Quantity = 0
	|			THEN 1
	|		ELSE TableMaterials.Quantity
	|	END * TableProductsContent.CorrQuantity * ISNULL(CatalogUOM.Factor, 1) / TableBOM.Quantity AS TMQuantity,
	|	TableMaterials.Products AS TMProducts,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS TMCharacteristic,
	|	FALSE AS Distributed
	|FROM
	|	TemporaryTableVT AS TableProductsContent
	|		LEFT JOIN Catalog.BillsOfMaterials AS TableBOM
	|		ON TableProductsContent.Specification = TableBOM.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TableProductsContent.Specification = TableMaterials.Ref
	|			AND (TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (TableMaterials.MeasurementUnit = CatalogUOM.Ref)
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TableProductsContent.CorrLineNumber,
	|	TableProductsContent.CorrProducts,
	|	TableProductsContent.CorrCharacteristic,
	|	TableProductsContent.CorrBatch,
	|	TableProductsContent.CorrOwnership,
	|	TableProductsContent.Specification,
	|	TableProductsContent.CorrGLAccount,
	|	TableProductsContent.CorrMeasurementUnit,
	|	TableProductsContent.CorrStructuralUnit,
	|	TableProductsContent.CorrQuantity,
	|	CASE
	|		WHEN TableByProducts.Quantity = 0
	|			THEN 1
	|		ELSE TableByProducts.Quantity
	|	END * TableProductsContent.CorrQuantity * ISNULL(CatalogUOM.Factor, 1) / TableBOM.Quantity,
	|	TableByProducts.Product,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableByProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	FALSE
	|FROM
	|	TemporaryTableVT AS TableProductsContent
	|		LEFT JOIN Catalog.BillsOfMaterials AS TableBOM
	|		ON TableProductsContent.Specification = TableBOM.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.ByProducts AS TableByProducts
	|		ON TableProductsContent.Specification = TableByProducts.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (TableByProducts.MeasurementUnit = CatalogUOM.Ref)
	|
	|ORDER BY
	|	Order,
	|	CorrLineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	TableInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN TableInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.InventoryTransferredGLAccount AS InventoryTransferredGLAccount,
	|	TableInventory.MeasurementUnit AS MeasurementUnit,
	|	&StructuralUnit AS StructuralUnit,
	|	TableInventory.Quantity AS Quantity
	|INTO TableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableByProducts.LineNumber AS LineNumber,
	|	TableByProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableByProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN TableByProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	TableByProducts.Ownership AS Ownership,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableByProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	TableByProducts.MeasurementUnit AS MeasurementUnit,
	|	TableByProducts.StructuralUnit AS StructuralUnit,
	|	TableByProducts.Quantity AS Quantity
	|INTO TableByProducts
	|FROM
	|	&TableByProducts AS TableByProducts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	TableInventory.LineNumber AS LineNumber,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.InventoryTransferredGLAccount AS GLAccount,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	TableInventory.Quantity * ISNULL(CatalogUOM.Factor, 1) AS Quantity,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS CorrGLAccount,
	|	VALUE(Catalog.Products.EmptyRef) AS CorrProducts,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS CorrCharacteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS CorrBatch,
	|	VALUE(Catalog.InventoryOwnership.EmptyRef) AS CorrOwnership,
	|	VALUE(Catalog.UOMClassifier.EmptyRef) AS CorrMeasurementUnit,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS CorrStructuralUnit,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS Specification,
	|	0 AS CorrLineNumber,
	|	0 AS CorrQuantity,
	|	FALSE AS IsByProduct,
	|	FALSE AS Distributed
	|FROM
	|	TableInventory AS TableInventory
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON TableInventory.MeasurementUnit = CatalogUOM.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON TableInventory.Products = CatalogProducts.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TableByProducts.LineNumber,
	|	TableByProducts.Products,
	|	TableByProducts.Characteristic,
	|	TableByProducts.Batch,
	|	TableByProducts.Ownership,
	|	TableByProducts.StructuralUnit,
	|	TableByProducts.InventoryGLAccount,
	|	CatalogProducts.MeasurementUnit,
	|	TableByProducts.Quantity * ISNULL(CatalogUOM.Factor, 1),
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef),
	|	VALUE(Catalog.Products.EmptyRef),
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef),
	|	VALUE(Catalog.ProductsBatches.EmptyRef),
	|	VALUE(Catalog.InventoryOwnership.EmptyRef),
	|	VALUE(Catalog.UOMClassifier.EmptyRef),
	|	VALUE(Catalog.BusinessUnits.EmptyRef),
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef),
	|	0,
	|	0,
	|	TRUE,
	|	FALSE
	|FROM
	|	TableByProducts AS TableByProducts
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON TableByProducts.MeasurementUnit = CatalogUOM.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON TableByProducts.Products = CatalogProducts.Ref
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	ResultsArray = Query.ExecuteBatch();
	
	TableProduction = ResultsArray[2].Unload();
	TableProductsContent = ResultsArray[3].Unload();
	MaterialsTable = ResultsArray[6].Unload();
	
	TableProduction.GroupBy(
		"CorrBatch,
		|CorrCharacteristic,
		|CorrGLAccount,
		|CorrMeasurementUnit,
		|CorrOwnership,
		|CorrProducts,
		|CorrStructuralUnit,
		|Distributed,
		|Specification",
		"CorrQuantity");
	TableProduction.Indexes.Add("CorrProducts, CorrCharacteristic");
	
	TableProductsContent.GroupBy(
		"CorrProducts,
		|CorrCharacteristic,
		|CorrBatch,
		|CorrOwnership,
		|Specification,
		|CorrGLAccount,
		|CorrQuantity,
		|CorrMeasurementUnit,
		|CorrStructuralUnit,
		|TMProducts,
		|TMCharacteristic,
		|Distributed",
		"TMQuantity");
	TableProductsContent.Indexes.Add("TMProducts, TMCharacteristic");
	
	MaterialsTable.GroupBy(
		"Batch,
		|Characteristic,
		|CorrBatch,
		|CorrCharacteristic,
		|CorrGLAccount,
		|CorrMeasurementUnit,
		|CorrOwnership,
		|CorrProducts,
		|CorrStructuralUnit,
		|Distributed,
		|GLAccount,
		|IsByProduct,
		|MeasurementUnit,
		|Order,
		|Ownership,
		|Products,
		|Specification,
		|StructuralUnit",
		"Quantity,
		|CorrQuantity");
	MaterialsTable.Indexes.Add("Products, Characteristic, CorrProducts, CorrCharacteristic");
	
	DistributedMaterials = 0;
	
	ProductsCount	= TableProductsContent.Count();
	MaterialsCount	= MaterialsTable.Count();
	
	For n = 0 To MaterialsCount - 1 Do
		
		RowMaterials = MaterialsTable[n];
		
		SearchStructure = New Structure;
		SearchStructure.Insert("TMProducts",		RowMaterials.Products);
		SearchStructure.Insert("TMCharacteristic",	RowMaterials.Characteristic);
		
		SearchResult = TableProductsContent.FindRows(SearchStructure);
		If SearchResult.Count() <> 0 Then
			DistributeMaterialsAccordingToNorms(RowMaterials, SearchResult, MaterialsTable);
			DistributedMaterials = DistributedMaterials + 1;
		EndIf;
		
	EndDo;
	
	DistributedProducts = 0;
	For Each ProductsContentRow In TableProductsContent Do
		If ProductsContentRow.Distributed Then
			DistributedProducts = DistributedProducts + 1;
		EndIf;
	EndDo;
	
	If DistributedMaterials < MaterialsCount Then
		If DistributedProducts = ProductsCount Then
			DistributionBase = TableProduction.Total("CorrQuantity");
			DistributeMaterialsByQuantity(TableProduction, MaterialsTable, DistributionBase);
		Else
			DistributeMaterialsByQuantity(TableProductsContent, MaterialsTable);
		EndIf;
	EndIf;
	
	Allocation.Load(MaterialsTable);
	Allocation.GroupBy(
		"CorrProducts,
		|CorrCharacteristic,
		|CorrBatch,
		|CorrOwnership,
		|CorrQuantity,
		|CorrMeasurementUnit,
		|CorrGLAccount,
		|CorrStructuralUnit,
		|Specification,
		|Products,
		|Characteristic,
		|Batch,
		|Ownership,
		|MeasurementUnit,
		|GLAccount,
		|StructuralUnit,
		|IsByProduct",
		"Quantity");
	
EndProcedure

Function CheckAllocationCorrectness(DisplaySuccessMessage = False) Export
	
	If Allocation.Count() = 0 Then
		MessageText = NStr("en = 'The allocation hasn''t been performed.
			|Use the ""Allocate automatically"" command and then make the needed manual changes.'; 
			|ru = 'Распределение не выполнено.
			|Нажмите ""Распределить автоматически"", после чего внесите необходимые изменения вручную.';
			|pl = 'Nie wykonano przydzielenia.
			|Użyj polecenia ""Przydziel automatycznie"" i następnie dokonaj wszystkich niezbędnych zmian ręcznie.';
			|es_ES = 'La asignación no se ha realizado.
			| Use el comando ""Asignar automáticamente"" y luego haga los cambios manuales necesarios.';
			|es_CO = 'La asignación no se ha realizado.
			| Use el comando ""Asignar automáticamente"" y luego haga los cambios manuales necesarios.';
			|tr = 'Tahsis gerçekleştirilemedi.
			|""Otomatik tahsis et"" komutunu seçip gerekli manuel değişiklikleri yapın.';
			|it = 'Non è stata eseguita l''allocazione. 
			| Utilizzare il comando ""Allocare automaticamente"" ed effettuare poi le modifiche manuali necessarie.';
			|de = 'Die Zuordnung wurde nicht ausgeführt
			|Verwenden Sie den ""Automatisch zuordnen""-Befehl und dann machen erforderliche Änderungen manuell.'");
		CommonClientServer.MessageToUser(MessageText, ThisObject, "Allocation");
		Return False;
	EndIf;
	
	Cancel = False;
	
	Query = New Query;
	
	Query.SetParameter("Allocation", Allocation);
	Query.SetParameter("TableProduction", Products);
	Query.SetParameter("TableInventory", Inventory);
	Query.SetParameter("TableByProducts", ByProducts);
	Query.SetParameter("UseCharacteristics", GetFunctionalOption("UseCharacteristics"));
	Query.SetParameter("UseBatches", GetFunctionalOption("UseBatches"));
	Query.SetParameter("StructuralUnit", StructuralUnit);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT
	|	Allocation.LineNumber AS LineNumber,
	|	Allocation.CorrProducts AS CorrProducts,
	|	Allocation.CorrCharacteristic AS CorrCharacteristic,
	|	Allocation.CorrBatch AS CorrBatch,
	|	Allocation.CorrOwnership AS CorrOwnership,
	|	Allocation.CorrMeasurementUnit AS CorrMeasurementUnit,
	|	Allocation.CorrQuantity AS CorrQuantity,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Allocation.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	Allocation.CorrStructuralUnit AS CorrStructuralUnit,
	|	Allocation.Specification AS Specification,
	|	Allocation.Products AS Products,
	|	Allocation.Characteristic AS Characteristic,
	|	Allocation.Batch AS Batch,
	|	Allocation.Ownership AS Ownership,
	|	Allocation.MeasurementUnit AS MeasurementUnit,
	|	Allocation.Quantity AS Quantity,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Allocation.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	Allocation.StructuralUnit AS StructuralUnit
	|INTO TT_Allocation
	|FROM
	|	&Allocation AS Allocation
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.LineNumber AS LineNumber,
	|	TableProduction.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableProduction.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN TableProduction.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	TableProduction.Ownership AS Ownership,
	|	TableProduction.MeasurementUnit AS MeasurementUnit,
	|	TableProduction.Quantity AS Quantity,
	|	TableProduction.Specification AS Specification,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableProduction.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	TableProduction.StructuralUnit AS StructuralUnit
	|INTO TableProduction
	|FROM
	|	&TableProduction AS TableProduction
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	TableInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN TableInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableInventory.InventoryTransferredGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryTransferredGLAccount,
	|	&StructuralUnit AS StructuralUnit,
	|	TableInventory.MeasurementUnit AS MeasurementUnit,
	|	TableInventory.Quantity AS Quantity
	|INTO TableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableByProducts.LineNumber AS LineNumber,
	|	TableByProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableByProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN TableByProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	TableByProducts.Ownership AS Ownership,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableByProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	TableByProducts.StructuralUnit AS StructuralUnit,
	|	TableByProducts.MeasurementUnit AS MeasurementUnit,
	|	TableByProducts.Quantity AS Quantity
	|INTO TableByProducts
	|FROM
	|	&TableByProducts AS TableByProducts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.Ownership AS Ownership,
	|	TableProduction.InventoryGLAccount AS GLAccount,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.Specification AS Specification,
	|	TableProduction.Quantity * ISNULL(CatalogUOM.Factor, 1) AS QuantityConsumed,
	|	NULL AS QuantityAllocated
	|INTO TT_ProductionComplete
	|FROM
	|	TableProduction AS TableProduction
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON TableProduction.MeasurementUnit = CatalogUOM.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	TT_Allocation.CorrProducts,
	|	TT_Allocation.CorrCharacteristic,
	|	TT_Allocation.CorrBatch,
	|	TT_Allocation.CorrOwnership,
	|	TT_Allocation.CorrGLAccount,
	|	TT_Allocation.CorrStructuralUnit,
	|	TT_Allocation.Specification,
	|	0,
	|	TT_Allocation.CorrQuantity
	|FROM
	|	TT_Allocation AS TT_Allocation
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Complete.Products AS Products,
	|	TT_Complete.Characteristic AS Characteristic,
	|	TT_Complete.Batch AS Batch,
	|	TT_Complete.Ownership AS Ownership,
	|	TT_Complete.GLAccount AS GLAccount,
	|	TT_Complete.StructuralUnit AS StructuralUnit,
	|	TT_Complete.Specification AS Specification,
	|	SUM(TT_Complete.QuantityConsumed) AS QuantityConsumed,
	|	MIN(TT_Complete.QuantityAllocated) AS QuantityAllocated
	|INTO TT_ProductionCompleteGrouped
	|FROM
	|	TT_ProductionComplete AS TT_Complete
	|
	|GROUP BY
	|	TT_Complete.GLAccount,
	|	TT_Complete.Specification,
	|	TT_Complete.StructuralUnit,
	|	TT_Complete.Characteristic,
	|	TT_Complete.Batch,
	|	TT_Complete.Ownership,
	|	TT_Complete.Products
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NULL AS LineNumber,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.InventoryTransferredGLAccount AS GLAccount,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	TableInventory.Quantity * ISNULL(CatalogUOM.Factor, 1) AS QuantityConsumed,
	|	0 AS QuantityAllocated
	|INTO TT_InventoryComplete
	|FROM
	|	TableInventory AS TableInventory
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON TableInventory.MeasurementUnit = CatalogUOM.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON TableInventory.Products = CatalogProducts.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	NULL,
	|	TableByProducts.Products,
	|	TableByProducts.Characteristic,
	|	TableByProducts.Batch,
	|	TableByProducts.Ownership,
	|	TableByProducts.InventoryGLAccount,
	|	TableByProducts.StructuralUnit,
	|	CatalogProducts.MeasurementUnit,
	|	TableByProducts.Quantity * ISNULL(CatalogUOM.Factor, 1),
	|	0
	|FROM
	|	TableByProducts AS TableByProducts
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON TableByProducts.MeasurementUnit = CatalogUOM.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON TableByProducts.Products = CatalogProducts.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	TT_Allocation.LineNumber,
	|	TT_Allocation.Products,
	|	TT_Allocation.Characteristic,
	|	TT_Allocation.Batch,
	|	TT_Allocation.Ownership,
	|	TT_Allocation.GLAccount,
	|	TT_Allocation.StructuralUnit,
	|	TT_Allocation.MeasurementUnit,
	|	0,
	|	TT_Allocation.Quantity
	|FROM
	|	TT_Allocation AS TT_Allocation
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TT_Complete.LineNumber) AS LineNumber,
	|	TT_Complete.Products AS Products,
	|	TT_Complete.Characteristic AS Characteristic,
	|	TT_Complete.Batch AS Batch,
	|	TT_Complete.Ownership AS Ownership,
	|	TT_Complete.GLAccount AS GLAccount,
	|	TT_Complete.StructuralUnit AS StructuralUnit,
	|	TT_Complete.MeasurementUnit AS MeasurementUnit,
	|	SUM(TT_Complete.QuantityConsumed) AS QuantityConsumed,
	|	SUM(TT_Complete.QuantityAllocated) AS QuantityAllocated
	|INTO TT_InventoryCompleteGrouped
	|FROM
	|	TT_InventoryComplete AS TT_Complete
	|
	|GROUP BY
	|	TT_Complete.MeasurementUnit,
	|	TT_Complete.GLAccount,
	|	TT_Complete.StructuralUnit,
	|	TT_Complete.Characteristic,
	|	TT_Complete.Batch,
	|	TT_Complete.Ownership,
	|	TT_Complete.Products
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TRUE AS Field
	|FROM
	|	TT_ProductionCompleteGrouped AS TT_CompleteGrouped
	|WHERE
	|	TT_CompleteGrouped.QuantityConsumed <> TT_CompleteGrouped.QuantityAllocated
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_CompleteGrouped.LineNumber AS LineNumber,
	|	TT_CompleteGrouped.Products AS Products,
	|	TT_CompleteGrouped.Characteristic AS Characteristic,
	|	TT_CompleteGrouped.Batch AS Batch,
	|	TT_CompleteGrouped.Ownership AS Ownership,
	|	TT_CompleteGrouped.MeasurementUnit AS MeasurementUnit,
	|	TT_CompleteGrouped.QuantityConsumed AS QuantityConsumed,
	|	TT_CompleteGrouped.QuantityAllocated AS QuantityAllocated
	|FROM
	|	TT_InventoryCompleteGrouped AS TT_CompleteGrouped
	|WHERE
	|	TT_CompleteGrouped.QuantityConsumed <> TT_CompleteGrouped.QuantityAllocated
	|
	|ORDER BY
	|	LineNumber";
	
	MessageTemplate = NStr("en = 'Component ""%1"" misallocation. Consumed: %2 %3, allocated: %4 %3, discrepancy: %5 %3'; ru = 'Неправильное распределение компонентов ""%1"". Расход: %2 %3, распределено: %4 %3, расхождение: %5 %3';pl = 'Komponent ""%1"" jest przydzielony niepoprawnie. Zużyto: %2 %3, przydzielono: %4 %3, rozbieżność: %5 %3';es_ES = 'Desviación del producto ""%1"". Consumido: %2 %3, asignado: %4 %3, discrepancia: %5 %3';es_CO = 'Desviación del producto ""%1"". Consumido: %2 %3, asignado: %4 %3, discrepancia: %5 %3';tr = '""%1"" malzemesi yanlış tahsis edildi. Tüketilen: %2 %3, tahsis edilen: %4 %3, uyuşmazlık: %5 %3';it = 'Allocazione errata della componente ""%1"". Consumato: %2 %3, allocato: %4 %3, discrepanza: %5 %3';de = 'Fehlerhafte Zuordnung der Komponente ""%1"". Verbraucht: %2 %3, zugeordnet: %4 %3, Abweichung: %5 %3'");
	MessageAllocate = NStr("en = 'Products table has been modified, allocation table contains irrelevant products data.
		|Use the ""Allocate automatically"" command and then make the needed manual changes.'; 
		|ru = 'Таблица номенклатуры изменена, таблица разнесения содержит неактуальные данные о номенклатуре.
		|Используйте команду ""Разнести автоматически"", после чего внесите необходимые изменения вручную.';
		|pl = 'Tabela Produkty została zmieniona, tabela przydzielenia zawiera niepoprawne dane o produktach.
		|Użyj polecenia ""Przydziel automatycznie"" i następnie zrób wszystkie niezbędne zmiany ręcznie.';
		|es_ES = 'Se ha modificado la tabla de productos, la tabla de asignación contiene datos de productos irrelevantes. 
		|Use el comando ""Asignar automáticamente"" y luego haga los cambios manuales necesarios.';
		|es_CO = 'Se ha modificado la tabla de productos, la tabla de asignación contiene datos de productos irrelevantes. 
		|Use el comando ""Asignar automáticamente"" y luego haga los cambios manuales necesarios.';
		|tr = 'Ürünler tablosu değiştirildi; tahsis tablosu geçersiz ürün bilgisi içeriyor.
		|""Otomatik tahsis et"" komutunu seçip gerekli manuel değişiklikleri yapın.';
		|it = 'La tabella degli articoli è stata modificata, la tabella allocazioni contiene dati irrilevanti sugli articoli.
		| Utilizzare il comando ""Allocare automaticamente"" ed effettuare poi le modifiche manuali necessarie.';
		|de = 'Die Tabelle von Produkten wurde modifiziert, die Zuordnungstabelle enthält unzutreffende Daten der Produkte.
		|Verwenden Sie den ""Automatisch zuordnen""-Befehl und dann machen erforderliche Änderungen manuell.'");
	
	Results = Query.ExecuteBatch();
	ResultsCount = Results.Count();
	
	If Not Results[ResultsCount - 2].IsEmpty() Then
		CommonClientServer.MessageToUser(MessageAllocate, ThisObject, "Allocation", , Cancel);
	EndIf;
	
	Selection = Results[ResultsCount - 1].Select();
	While Selection.Next() Do
		
		ProductPresentationArray = New Array;
		ProductPresentationArray.Add(Selection.Products);
		
		If ValueIsFilled(Selection.Characteristic) Then
			ProductPresentationArray.Add(Selection.Characteristic);
		EndIf;
		
		If ValueIsFilled(Selection.Batch) Then
			ProductPresentationArray.Add(Selection.Batch);
		EndIf;
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessageTemplate,
			StrConcat(ProductPresentationArray, " "),
			Selection.QuantityConsumed,
			Selection.MeasurementUnit,
			Selection.QuantityAllocated,
			Selection.QuantityAllocated - Selection.QuantityConsumed);
		
		If Selection.LineNumber = Null Then
			MessageField = "Allocation";
		Else
			MessageField = CommonClientServer.PathToTabularSection("Allocation", Selection.LineNumber, "Quantity");
		EndIf;
		
		CommonClientServer.MessageToUser(MessageText, ThisObject, MessageField, , Cancel);
		
	EndDo;
	
	If DisplaySuccessMessage And Not Cancel Then
		MessageText = NStr("en = 'No allocation errors were found.'; ru = 'Ошибки распределения не выявлены.';pl = 'Nie znaleziono błędów przydzielenia.';es_ES = 'No se encontraron errores de asignación.';es_CO = 'No se encontraron errores de asignación.';tr = 'Tahsis hatası bulunamadı.';it = 'Nessun errore di allocazione rilevato.';de = 'Keine Zuordnungsfehler gefunden.'");
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
	Return Not Cancel;
	
EndFunction

#EndRegion

#Region Private

Procedure DistributeMaterialsAccordingToNorms(RowMaterials, BaseTable, MaterialsTable)
	
	RowMaterials.Distributed = True;
	
	DistributionBase = 0;
	For Each BaseRow In BaseTable Do
		DistributionBase = DistributionBase + BaseRow.TMQuantity;
		BaseRow.Distributed = True;
	EndDo;
	
	DistributeTabularSectionRowMaterials(RowMaterials, BaseTable, MaterialsTable, DistributionBase, True);
	
EndProcedure

Procedure DistributeMaterialsByQuantity(BaseTable, MaterialsTable, DistributionBase = 0)
	
	ExcDistributed = False;
	If DistributionBase = 0 Then
		ExcDistributed = True;
		For Each BaseRow In BaseTable Do
			If Not BaseRow.Distributed Then
				DistributionBase = DistributionBase + BaseRow.CorrQuantity;
			EndIf;
		EndDo;
	EndIf;
	
	For n = 0 To MaterialsTable.Count() - 1 Do
		
		RowMaterials = MaterialsTable[n];
		
		If Not RowMaterials.Distributed Then
			DistributeTabularSectionRowMaterials(
				RowMaterials,
				BaseTable,
				MaterialsTable,
				DistributionBase,
				False, 
				ExcDistributed);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure DistributeTabularSectionRowMaterials(
	RowMaterials,
	BaseTable,
	MaterialsTable,
	DistributionBase,
	AccordingToNorms,
	ExcDistributed = False)
	
	InitQuantity = 0;
	QuantityToWriteOff = RowMaterials.Quantity;
	
	DistributionBaseQuantity = DistributionBase;
	
	For Each BasicTableRow In BaseTable Do
		
		If ExcDistributed And BasicTableRow.Distributed Then
			Continue;
		EndIf;
		
		If InitQuantity = QuantityToWriteOff Then
			Continue;
		EndIf;
		
		If ValueIsFilled(RowMaterials.CorrProducts) Then
			NewRow = MaterialsTable.Add();
			FillPropertyValues(NewRow, RowMaterials);
			FillPropertyValues(NewRow, BasicTableRow);
			RowMaterials = NewRow;
		Else
			FillPropertyValues(RowMaterials, BasicTableRow);
		EndIf;
		
		If AccordingToNorms Then
			BasicTableQuantity = BasicTableRow.TMQuantity;
		Else
			BasicTableQuantity = BasicTableRow.CorrQuantity
		EndIf;
		
		RowMaterials.Quantity = Round((QuantityToWriteOff - InitQuantity) * BasicTableQuantity / DistributionBaseQuantity, 3, 1);
		
		If (InitQuantity + RowMaterials.Quantity) > QuantityToWriteOff Then
			RowMaterials.Quantity = QuantityToWriteOff - InitQuantity;
			InitQuantity = QuantityToWriteOff;
		Else
			DistributionBaseQuantity = DistributionBaseQuantity - BasicTableQuantity;
			InitQuantity = InitQuantity + RowMaterials.Quantity;
		EndIf;
		
	EndDo;
	
	If InitQuantity < QuantityToWriteOff Then
		RowMaterials.Quantity = RowMaterials.Quantity + (QuantityToWriteOff - InitQuantity);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf