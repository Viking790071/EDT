#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnCopy(CopiedObject)
	
	Prepayment.Clear();
	PrepaymentVAT.Clear();
	
	ForOpeningBalancesOnly = False;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	FillingStrategy = New Map;
	FillingStrategy[Type("DocumentRef.GoodsIssue")] = "FillByGoodsIssue";
	FillingStrategy[Type("DocumentRef.SubcontractorOrderReceived")] = "FillBySubcontractorOrderReceived";
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy);
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
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
	
	InventoryOwnershipServer.FillMainTableColumn(ThisObject, WriteMode, Cancel);
	
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
	
	//Cash flow projection
	Amount = Products.Total("Amount");
	VATAmount = Products.Total("VATAmount");
	
	PaymentTermsServer.CheckRequiredAttributes(ThisObject, CheckedAttributes, Cancel);
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);
	
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
	Documents.SubcontractorInvoiceIssued.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Limit Exceed Control
	DriveServer.CheckLimitsExceed(ThisObject, False, Cancel);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSubcontractComponents(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSubcontractorOrdersReceived(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectCustomerOwnedInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectVATOutput(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Subordinate tax invoice
	If Not Cancel And Not AdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments Then
		
		If AdditionalProperties.AccountingPolicy.IssueAutomaticallyAgainstSales Then
			WorkWithVAT.CreateTaxInvoice(DocumentWriteMode.Posting, Ref)
		EndIf;
		
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);
		
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.SubcontractorInvoiceIssued.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	
	// Subordinate tax invoice
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.UndoPosting, Ref, DeletionMark);
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.SubcontractorInvoiceIssued.RunControl(Ref, AdditionalProperties, Cancel, True);
	
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
		NewRow.Order = Order;
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
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(AccountsReceivableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsReceivableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryAccountsReceivableBalances
	|FROM
	|	(SELECT
	|		AccountsReceivableBalances.Contract AS Contract,
	|		AccountsReceivableBalances.Document AS Document,
	|		AccountsReceivableBalances.Order AS Order,
	|		AccountsReceivableBalances.AmountBalance AS AmountBalance,
	|		AccountsReceivableBalances.AmountCurBalance AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsReceivable.Balance(
	|				&Period,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					AND Order IN (&Order)
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsCustomerSettlements.Contract,
	|		DocumentRegisterRecordsCustomerSettlements.Document,
	|		DocumentRegisterRecordsCustomerSettlements.Order,
	|		CASE
	|			WHEN DocumentRegisterRecordsCustomerSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -DocumentRegisterRecordsCustomerSettlements.Amount
	|			ELSE DocumentRegisterRecordsCustomerSettlements.Amount
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsCustomerSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -DocumentRegisterRecordsCustomerSettlements.AmountCur
	|			ELSE DocumentRegisterRecordsCustomerSettlements.AmountCur
	|		END
	|	FROM
	|		AccumulationRegister.AccountsReceivable AS DocumentRegisterRecordsCustomerSettlements
	|	WHERE
	|		DocumentRegisterRecordsCustomerSettlements.Recorder = &Ref
	|		AND DocumentRegisterRecordsCustomerSettlements.Company = &Company
	|		AND DocumentRegisterRecordsCustomerSettlements.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsCustomerSettlements.Contract = &Contract
	|		AND DocumentRegisterRecordsCustomerSettlements.Order IN(&Order)
	|		AND DocumentRegisterRecordsCustomerSettlements.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalances
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON AccountsReceivableBalances.Contract = CounterpartyContracts.Ref
	|
	|GROUP BY
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Order,
	|	CounterpartyContracts.SettlementsCurrency
	|
	|HAVING
	|	SUM(AccountsReceivableBalances.AmountCurBalance) < 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.SettlementsCurrency AS SettlementsCurrency,
	|	-AccountsReceivableBalances.AmountCurBalance AS SettlementsAmount,
	|	-AccountsReceivableBalances.AmountBalance AS PaymentAmount,
	|	CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN CASE
	|					WHEN AccountsReceivableBalances.AmountBalance <> 0
	|						THEN AccountsReceivableBalances.AmountCurBalance / AccountsReceivableBalances.AmountBalance
	|					ELSE 1
	|				END
	|		ELSE CASE
	|				WHEN AccountsReceivableBalances.AmountCurBalance <> 0
	|					THEN AccountsReceivableBalances.AmountBalance / AccountsReceivableBalances.AmountCurBalance
	|				ELSE 1
	|			END
	|	END AS ExchangeRate,
	|	1 AS Multiplicity
	|FROM
	|	TemporaryAccountsReceivableBalances AS AccountsReceivableBalances
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

Procedure FillByGoodsIssue(FillingData) Export 
	
	If Not TypeOf(FillingData.Order) = Type("DocumentRef.SubcontractorOrderReceived") 
		Or Not ValueIsFilled(FillingData.Order) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Cannot generate ""Subcontractor invoice issued"" for this Goods issue. Select a Goods issue with Order set to Subcontractor order received. Then try again.'; ru = 'Не удается создать выданный инвойс переработчика для данного отпуска товаров. Выберите отпуск товаров, в котором в поле ""Заказ"" установлено значение ""Полученный заказ на переработку"". Затем повторите попытку.';pl = 'Nie można wygenerować ""Wydanej faktury podwykonawcy"" dla tego ""Wydania zewnętrznego. Wybierz Wydanie zewnętrzne, w którym w polu Zamówienie ustawiono na Otrzymane zamówienie podwykonawcy. Następnie spróbuj ponownie.';es_ES = 'No se puede generar ""Factura emitida del Subcontratista"" para esta salida de Mercancías. Seleccione una salida de Mercancías con la Orden establecida como orden recibida del Subcontratista. Inténtelo de nuevo.';es_CO = 'No se puede generar ""Factura emitida del Subcontratista"" para esta salida de Mercancías. Seleccione una salida de Mercancías con la Orden establecida como orden recibida del Subcontratista. Inténtelo de nuevo.';tr = 'Bu Ambar çıkışı için ""Düzenlenen alt yüklenici faturası"" oluşturulamıyor. Siparişi Alınan alt yüklenici siparişi olarak ayarlanmış bir Ambar çıkışı seçip tekrar deneyin.';it = 'Impossibile generare ""Fattura di subfornitura emessa"" per questo Documento di trasporto. Selezionare un Documento di trasporto con Ordine impostato su Ordine di subfornitura ricevuto. Poi riprovare.';de = 'Kann keinen ""Subunternehmerrechnung ausgestellt"" für diesen Warenausgang generieren. Wählen Sie eine Warenausgang mit dem Auftrag festgelegt für den Subunternehmerauftrag erhalten. Dann versuchen Sie es erneut.'")); 
		Return;
	EndIf;
	
	FillingBySubcontractorOrderReceived(FillingData.Order, FillingData);
	
EndProcedure

Procedure FillBySubcontractorOrderReceived(FillingData) Export 
	
	FillingBySubcontractorOrderReceived(FillingData, FillingData);
	
EndProcedure

// Procedure fills tabular section according to specification.
//
Procedure FillTabularSectionBySpecification() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TableProduction.LineNumber AS LineNumber,
	|	TableProduction.Quantity AS Quantity,
	|	TableProduction.Specification AS Specification,
	|	TableProduction.MeasurementUnit AS MeasurementUnit
	|INTO TT_Level0
	|FROM
	|	&TableProduction AS TableProduction
	|
	|INDEX BY
	|	Specification
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Level0.LineNumber AS LineNumber,
	|	TableMaterials.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(TableMaterials.Quantity / TableMaterials.Ref.Quantity * CASE
	|			WHEN TableMaterials.CalculationMethod = VALUE(Enum.BOMContentCalculationMethod.Proportional)
	|				THEN ISNULL(UOM.Factor, 1) * TT_Level0.Quantity
	|			ELSE CASE
	|					WHEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level0.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) = ISNULL(UOM.Factor, 1) * TT_Level0.Quantity / TableMaterials.Ref.Quantity
	|						THEN ISNULL(UOM.Factor, 1) * TT_Level0.Quantity
	|					WHEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level0.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) > ISNULL(UOM.Factor, 1) * TT_Level0.Quantity / TableMaterials.Ref.Quantity
	|						THEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level0.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) * TableMaterials.Ref.Quantity
	|					ELSE ((CAST(ISNULL(UOM.Factor, 1) * TT_Level0.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) + 1) * TableMaterials.Ref.Quantity
	|				END
	|		END) AS Quantity,
	|	TableMaterials.Specification AS Specification,
	|	TableMaterials.MeasurementUnit AS MeasurementUnit
	|INTO TT_Level1
	|FROM
	|	TT_Level0 AS TT_Level0
	|		INNER JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TT_Level0.Specification = TableMaterials.Ref
	|			AND (TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON TT_Level0.MeasurementUnit = UOM.Ref
	|
	|GROUP BY
	|	TT_Level0.LineNumber,
	|	TableMaterials.Specification,
	|	TableMaterials.Products,
	|	TableMaterials.Characteristic,
	|	TableMaterials.MeasurementUnit
	|
	|INDEX BY
	|	Specification
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Level1.LineNumber AS LineNumber,
	|	TableMaterials.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(TableMaterials.Quantity / TableMaterials.Ref.Quantity * CASE
	|			WHEN TableMaterials.CalculationMethod = VALUE(Enum.BOMContentCalculationMethod.Proportional)
	|				THEN ISNULL(UOM.Factor, 1) * TT_Level1.Quantity
	|			ELSE CASE
	|					WHEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level1.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) = ISNULL(UOM.Factor, 1) * TT_Level1.Quantity / TableMaterials.Ref.Quantity
	|						THEN ISNULL(UOM.Factor, 1) * TT_Level1.Quantity
	|					WHEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level1.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) > ISNULL(UOM.Factor, 1) * TT_Level1.Quantity / TableMaterials.Ref.Quantity
	|						THEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level1.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) * TableMaterials.Ref.Quantity
	|					ELSE ((CAST(ISNULL(UOM.Factor, 1) * TT_Level1.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) + 1) * TableMaterials.Ref.Quantity
	|				END
	|		END) AS Quantity,
	|	TableMaterials.Specification AS Specification,
	|	TableMaterials.MeasurementUnit AS MeasurementUnit
	|INTO TT_Level2
	|FROM
	|	TT_Level1 AS TT_Level1
	|		INNER JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TT_Level1.Specification = TableMaterials.Ref
	|			AND (TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON TT_Level1.MeasurementUnit = UOM.Ref
	|
	|GROUP BY
	|	TT_Level1.LineNumber,
	|	TableMaterials.Specification,
	|	TableMaterials.Products,
	|	TableMaterials.Characteristic,
	|	TableMaterials.MeasurementUnit
	|
	|INDEX BY
	|	Specification
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Level2.LineNumber AS LineNumber,
	|	TableMaterials.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(TableMaterials.Quantity / TableMaterials.Ref.Quantity * CASE
	|			WHEN TableMaterials.CalculationMethod = VALUE(Enum.BOMContentCalculationMethod.Proportional)
	|				THEN ISNULL(UOM.Factor, 1) * TT_Level2.Quantity
	|			ELSE CASE
	|					WHEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level2.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) = ISNULL(UOM.Factor, 1) * TT_Level2.Quantity / TableMaterials.Ref.Quantity
	|						THEN ISNULL(UOM.Factor, 1) * TT_Level2.Quantity
	|					WHEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level2.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) > ISNULL(UOM.Factor, 1) * TT_Level2.Quantity / TableMaterials.Ref.Quantity
	|						THEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level2.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) * TableMaterials.Ref.Quantity
	|					ELSE ((CAST(ISNULL(UOM.Factor, 1) * TT_Level2.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) + 1) * TableMaterials.Ref.Quantity
	|				END
	|		END) AS Quantity,
	|	TableMaterials.MeasurementUnit AS MeasurementUnit
	|INTO TT_Level3
	|FROM
	|	TT_Level2 AS TT_Level2
	|		INNER JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TT_Level2.Specification = TableMaterials.Ref
	|			AND (TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|			AND (TableMaterials.Specification = VALUE(Catalog.BillsOfMaterials.EmptyRef))
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON TT_Level2.MeasurementUnit = UOM.Ref
	|WHERE
	|	TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	TT_Level2.LineNumber,
	|	TableMaterials.Products,
	|	TableMaterials.Characteristic,
	|	TableMaterials.MeasurementUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Level1.LineNumber AS LineNumber,
	|	TT_Level1.Products AS Products,
	|	TT_Level1.Characteristic AS Characteristic,
	|	TT_Level1.Quantity AS Quantity,
	|	TT_Level1.MeasurementUnit AS MeasurementUnit
	|INTO TT_Components
	|FROM
	|	TT_Level1 AS TT_Level1
	|WHERE
	|	TT_Level1.Specification = VALUE(Catalog.BillsOfMaterials.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	TT_Level2.LineNumber,
	|	TT_Level2.Products,
	|	TT_Level2.Characteristic,
	|	TT_Level2.Quantity,
	|	TT_Level2.MeasurementUnit
	|FROM
	|	TT_Level2 AS TT_Level2
	|WHERE
	|	TT_Level2.Specification = VALUE(Catalog.BillsOfMaterials.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	TT_Level3.LineNumber,
	|	TT_Level3.Products,
	|	TT_Level3.Characteristic,
	|	TT_Level3.Quantity,
	|	TT_Level3.MeasurementUnit
	|FROM
	|	TT_Level3 AS TT_Level3
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TT_Components.LineNumber) AS LineNumber,
	|	TT_Components.Products AS Products,
	|	TT_Components.Characteristic AS Characteristic,
	|	SUM(TT_Components.Quantity) AS Quantity,
	|	TT_Components.MeasurementUnit AS MeasurementUnit
	|FROM
	|	TT_Components AS TT_Components
	|
	|GROUP BY
	|	TT_Components.Products,
	|	TT_Components.Characteristic,
	|	TT_Components.MeasurementUnit
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("TableProduction", Products.Unload());
	Query.SetParameter("UseCharacteristics", Constants.UseCharacteristics.Get());
	
	Inventory.Load(Query.Execute().Unload());
	
EndProcedure

#EndRegion

#Region Private

Procedure FillingBySubcontractorOrderReceived(SubcontractorOrderReceived, CurrentBasisDocument)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SubcontractorOrderReceived.Company AS Company,
	|	SubcontractorOrderReceived.Counterparty AS Counterparty,
	|	SubcontractorOrderReceived.StructuralUnit AS StructuralUnit,
	|	SubcontractorOrderReceived.DocumentCurrency AS DocumentCurrency,
	|	SubcontractorOrderReceived.VATTaxation AS VATTaxation,
	|	SubcontractorOrderReceived.AmountIncludesVAT AS AmountIncludesVAT,
	|	SubcontractorOrderReceived.IncludeVATInPrice AS IncludeVATInPrice,
	|	SubcontractorOrderReceived.CompanyVATNumber AS CompanyVATNumber,
	|	SubcontractorOrderReceived.AutomaticVATCalculation AS AutomaticVATCalculation,
	|	SubcontractorOrderReceived.ExchangeRate AS ExchangeRate,
	|	SubcontractorOrderReceived.Multiplicity AS Multiplicity,
	|	SubcontractorOrderReceived.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	SubcontractorOrderReceived.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	SubcontractorOrderReceived.DocumentAmount AS DocumentAmount,
	|	SubcontractorOrderReceived.DocumentSubtotal AS DocumentSubtotal,
	|	SubcontractorOrderReceived.DocumentTax AS DocumentTax,
	|	SubcontractorOrderReceived.Responsible AS Responsible,
	|	&BasisDocument AS BasisDocument,
	|	SubcontractorOrderReceived.PaymentMethod AS PaymentMethod,
	|	SubcontractorOrderReceived.BankAccount AS BankAccount,
	|	SubcontractorOrderReceived.PettyCash AS PettyCash,
	|	SubcontractorOrderReceived.SetPaymentTerms AS SetPaymentTerms,
	|	SubcontractorOrderReceived.Contract AS Contract,
	|	SubcontractorOrderReceived.CashAssetType AS CashAssetType,
	|	SubcontractorOrderReceived.Ref AS Order
	|FROM
	|	Document.SubcontractorOrderReceived AS SubcontractorOrderReceived
	|WHERE
	|	SubcontractorOrderReceived.Ref = &SubcontractorOrderReceived
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorOrderReceivedProducts.Products AS Products,
	|	SubcontractorOrderReceivedProducts.ProductsType AS ProductsType,
	|	SubcontractorOrderReceivedProducts.Characteristic AS Characteristic,
	|	SubcontractorOrderReceivedProducts.Quantity AS Quantity,
	|	SubcontractorOrderReceivedProducts.MeasurementUnit AS MeasurementUnit,
	|	SubcontractorOrderReceivedProducts.Specification AS Specification,
	|	SubcontractorOrderReceivedProducts.Price AS Price,
	|	SubcontractorOrderReceivedProducts.Amount AS Amount,
	|	SubcontractorOrderReceivedProducts.VATRate AS VATRate,
	|	SubcontractorOrderReceivedProducts.VATAmount AS VATAmount,
	|	SubcontractorOrderReceivedProducts.Total AS Total
	|FROM
	|	Document.SubcontractorOrderReceived.Products AS SubcontractorOrderReceivedProducts
	|WHERE
	|	SubcontractorOrderReceivedProducts.Ref = &SubcontractorOrderReceived
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorOrderReceivedInventory.Products AS Products,
	|	SubcontractorOrderReceivedInventory.Characteristic AS Characteristic,
	|	SubcontractorOrderReceivedInventory.Quantity AS Quantity,
	|	SubcontractorOrderReceivedInventory.MeasurementUnit AS MeasurementUnit
	|FROM
	|	Document.SubcontractorOrderReceived.Inventory AS SubcontractorOrderReceivedInventory
	|WHERE
	|	SubcontractorOrderReceivedInventory.Ref = &SubcontractorOrderReceived";
	
	Query.SetParameter("SubcontractorOrderReceived", SubcontractorOrderReceived);
	Query.SetParameter("BasisDocument", CurrentBasisDocument);
	
	QueryResult = Query.ExecuteBatch();
	
	Header = QueryResult[0].Unload();
	If Header.Count() = 0 Then
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, Header[0]);
	Products.Load(QueryResult[1].Unload());
	Inventory.Load(QueryResult[2].Unload());
	
	IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInDocument(ThisObject, CurrentBasisDocument);
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, CurrentBasisDocument);
	EndIf;
	PaymentTermsServer.FillPaymentCalendarFromDocument(ThisObject, SubcontractorOrderReceived);
	
EndProcedure

#EndRegion 

#EndIf