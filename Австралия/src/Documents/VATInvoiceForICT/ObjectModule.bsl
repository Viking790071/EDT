#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure FillByGoodsIssue(FillingData) Export
	
	TempTableManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTableManager;
	Query.Text =
	"SELECT ALLOWED
	|	GoodsIssue.Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	GoodsIssueProducts.Products AS Products,
	|	GoodsIssueProducts.Characteristic AS Characteristic,
	|	GoodsIssueProducts.Batch AS Batch,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsIssueProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	GoodsIssue.StructuralUnit AS StructuralUnit
	|INTO TT_Parameters
	|FROM
	|	Document.GoodsIssue.Products AS GoodsIssueProducts
	|		INNER JOIN Document.GoodsIssue AS GoodsIssue
	|		ON GoodsIssueProducts.Ref = GoodsIssue.Ref
	|WHERE
	|	GoodsIssueProducts.Ref = &GoodsIssue
	|	AND GoodsIssue.OperationType = VALUE(Enum.OperationTypesGoodsIssue.IntraCommunityTransfer)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VATInvoiceForICT.Ref AS Ref
	|FROM
	|	Document.VATInvoiceForICT AS VATInvoiceForICT
	|WHERE
	|	VATInvoiceForICT.BasisDocument = &GoodsIssue
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountingPolicySliceLast.InventoryValuationMethod = VALUE(Enum.InventoryValuationMethods.FIFO) AS UseFIFO,
	|	CASE
	|		WHEN AccountingPolicySliceLast.DefaultVATRate = VALUE(Catalog.VATRates.EmptyRef)
	|			THEN VALUE(Catalog.VATRates.Exempt)
	|		ELSE AccountingPolicySliceLast.DefaultVATRate
	|	END AS DefaultVATRate
	|FROM
	|	InformationRegister.AccountingPolicy.SliceLast(
	|			&PointInTime,
	|			Company IN
	|				(SELECT TOP 1
	|					TT_Parameters.Company AS Company
	|				FROM
	|					TT_Parameters AS TT_Parameters)) AS AccountingPolicySliceLast";
	
	Query.SetParameter("GoodsIssue", FillingData.Ref);
	Query.SetParameter("PointInTime", New Boundary(
		New PointInTime(FillingData.Date, FillingData.Ref), BoundaryType.Including));
	Query.SetParameter("PresentationCurrency", DriveReUse.GetFunctionalCurrency());
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	QueryResult = Query.ExecuteBatch();
	
	TT_ParametersInfo = QueryResult[0].Unload();
	If TT_ParametersInfo[0].Count = 0 Then
		MessageText = NStr("en = 'Please select a goods issue with ""Intra-community transfer"" operation.'; ru = 'Выберите отпуск товаров с операцией ""Перемещение внутри ЕС"".';pl = 'Wybierz wydanie zewnętrzne z operacją ""Przemieszczenie wewnątrz wspólnoty"".';es_ES = 'Por favor, seleccionar la salida de mercancías con la operación ""Transferencia intracomunitaria"".';es_CO = 'Por favor, seleccionar la salida de mercancías con la operación ""Transferencia intracomunitaria"".';tr = 'Lütfen ''''Topluluk içi transfer'''' işlemi ile ambar çıkışı seçin.';it = 'Selezionare un documento di trasporto con operazione ""Trasferimento intra-UE"".';de = 'Bitte wählen Sie einen Wareneingang mit der Operation ""Gemeinde interner Transfer"" aus.'");
		Raise MessageText;
	EndIf;
	
	If Not QueryResult[1].IsEmpty() Then
		MessageText = NStr("en = 'VAT invoice for intra-community transfer has already been created.'; ru = 'Налоговая накладная для перемещения внутри ЕС уже создана.';pl = 'Faktura VAT dla przemieszczenia wewnątrz wspólnoty została już utworzona.';es_ES = 'Se ha creado la factura de IVA para la transferencia intracomunitaria.';es_CO = 'Se ha creado la factura de IVA para la transferencia intracomunitaria.';tr = 'Topluluk içi transfer için KDV faturası zaten oluşturuldu.';it = 'La fattura IVA per il trasferimento intra-UE è già stata creata.';de = 'Die USt.-Rechnung für den Gemeinde interne Transfer wurde bereits erstellt.'");
		Raise MessageText;
	EndIf;
	
	Selection = QueryResult[2].Select();
	If Selection.Next() Then
		UseFIFO = Selection.UseFIFO;
		DefaultVATRate = Selection.DefaultVATRate;
	Else
		UseFIFO = False;
		DefaultVATRate = Catalogs.VATRates.Exempt;
	EndIf;
	
	If UseFIFO Then
		Query.Text = GetQueryTextForFIFO();
	Else
		Query.Text = GetQueryTextForWeightedAverage();
	EndIf;
	
	Query.Execute();
	
	Query.Text =
	"SELECT ALLOWED DISTINCT
	|	CatalogProducts.Ref AS Products,
	|	CASE
	|		WHEN CatalogProducts.VATRate = VALUE(Catalog.VATRates.EmptyRef)
	|			THEN &DefaultVATRate
	|		ELSE CatalogProducts.VATRate
	|	END AS VATRate,
	|	CASE
	|		WHEN CatalogProducts.VATRate = VALUE(Catalog.VATRates.EmptyRef)
	|			THEN CAST(&DefaultVATRate AS Catalog.VATRates).Rate
	|		ELSE CatalogProducts.VATRate.Rate
	|	END AS Rate
	|INTO TT_VATRates
	|FROM
	|	Document.GoodsIssue.Products AS GoodsIssueProducts
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON GoodsIssueProducts.Products = CatalogProducts.Ref
	|WHERE
	|	GoodsIssueProducts.Ref = &GoodsIssue
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsIssue.AmountIncludesVAT AS AmountIncludesVAT,
	|	GoodsIssue.AutomaticVATCalculation AS AutomaticVATCalculation,
	|	GoodsIssue.Ref AS BasisDocument,
	|	GoodsIssue.Company AS Company,
	|	GoodsIssue.CompanyVATNumber AS CompanyVATNumber,
	|	GoodsIssue.DocumentCurrency AS DocumentCurrency,
	|	GoodsIssue.StructuralUnit AS StructuralUnit,
	|	VALUE(Enum.VATTaxationTypes.NotSubjectToVAT) AS VATTaxation,
	|	VALUE(Enum.VATTaxationTypes.ReverseChargeVAT) AS VATTaxationDestination
	|FROM
	|	Document.GoodsIssue AS GoodsIssue
	|WHERE
	|	GoodsIssue.Ref = &GoodsIssue
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsIssueProducts.Products AS Products,
	|	GoodsIssueProducts.Characteristic AS Characteristic,
	|	GoodsIssueProducts.Batch AS Batch,
	|	GoodsIssueProducts.MeasurementUnit AS MeasurementUnit,
	|	GoodsIssueProducts.SerialNumbers AS SerialNumbers,
	|	ISNULL(TT_Prices.Price, 0) AS Price,
	|	ISNULL(TT_Prices.Quantity, 0) AS Quantity,
	|	ISNULL(TT_Prices.Amount, 0) AS Amount,
	|	VALUE(Catalog.VATRates.Exempt) AS VATRate,
	|	0 AS VATAmount,
	|	ISNULL(TT_Prices.Amount, 0) AS Total,
	|	GoodsIssueProducts.ConnectionKey AS ConnectionKey
	|FROM
	|	Document.GoodsIssue.Products AS GoodsIssueProducts
	|		LEFT JOIN TT_Prices AS TT_Prices
	|		ON GoodsIssueProducts.Products = TT_Prices.Products
	|			AND GoodsIssueProducts.Characteristic = TT_Prices.Characteristic
	|			AND GoodsIssueProducts.Batch = TT_Prices.Batch
	|WHERE
	|	GoodsIssueProducts.Ref = &GoodsIssue
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsIssueProducts.Products AS Products,
	|	GoodsIssueProducts.Characteristic AS Characteristic,
	|	GoodsIssueProducts.Batch AS Batch,
	|	GoodsIssueProducts.MeasurementUnit AS MeasurementUnit,
	|	GoodsIssueProducts.SerialNumbers AS SerialNumbers,
	|	ISNULL(TT_Prices.Price, 0) AS Price,
	|	ISNULL(TT_Prices.Quantity, 0) AS Quantity,
	|	ISNULL(TT_Prices.Amount, 0) AS Amount,
	|	TT_VATRates.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN GoodsIssue.AmountIncludesVAT
	|				THEN ISNULL(TT_Prices.Amount, 0) * (1 - 100 / (TT_VATRates.Rate + 100))
	|			ELSE ISNULL(TT_Prices.Amount, 0) * TT_VATRates.Rate / 100
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	ISNULL(TT_Prices.Amount, 0) + (CAST(CASE
	|			WHEN GoodsIssue.AmountIncludesVAT
	|				THEN ISNULL(TT_Prices.Amount, 0) * (1 - 100 / (TT_VATRates.Rate + 100))
	|			ELSE ISNULL(TT_Prices.Amount, 0) * TT_VATRates.Rate / 100
	|		END AS NUMBER(15, 2))) AS Total,
	|	GoodsIssueProducts.ConnectionKey AS ConnectionKey
	|FROM
	|	Document.GoodsIssue.Products AS GoodsIssueProducts
	|		LEFT JOIN TT_Prices AS TT_Prices
	|		ON GoodsIssueProducts.Products = TT_Prices.Products
	|			AND GoodsIssueProducts.Characteristic = TT_Prices.Characteristic
	|			AND GoodsIssueProducts.Batch = TT_Prices.Batch
	|		INNER JOIN TT_VATRates AS TT_VATRates
	|		ON GoodsIssueProducts.Products = TT_VATRates.Products
	|		INNER JOIN Document.GoodsIssue AS GoodsIssue
	|		ON GoodsIssueProducts.Ref = GoodsIssue.Ref
	|WHERE
	|	GoodsIssueProducts.Ref = &GoodsIssue";
	
	Query.SetParameter("DefaultVATRate", DefaultVATRate);
	
	QueryResult = Query.ExecuteBatch();
	
	Header = QueryResult[1].Unload();
	If Header.Count() > 0 Then
		FillPropertyValues(ThisObject, Header[0]);
	EndIf;
	
	Inventory.Load(QueryResult[2].Unload());
	InventoryDestination.Load(QueryResult[3].Unload());
	
	WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(ThisObject, FillingData, "Products");
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData.Ref);
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.GoodsIssue") Then
		
		If FillingData.OperationType <> Enums.OperationTypesGoodsIssue.IntraCommunityTransfer Then
			Raise NStr("en = 'Please select a goods issue with ""Intra-community transfer"" operation.'; ru = 'Выберите отпуск товаров с операцией ""Перемещение внутри ЕС"".';pl = 'Wybierz wydanie zewnętrzne z operacją ""Przemieszczenie wewnątrz wspólnoty"".';es_ES = 'Por favor, seleccionar la salida de mercancías con la operación ""Transferencia intracomunitaria"".';es_CO = 'Por favor, seleccionar la salida de mercancías con la operación ""Transferencia intracomunitaria"".';tr = 'Lütfen ''''Topluluk içi transfer'''' işlemi ile ambar çıkışı seçin.';it = 'Selezionare un documento di trasporto con operazione ""Trasferimento intra-UE"".';de = 'Bitte wählen Sie einen Warenausgang mit der Operation ""Gemeinde interner Transfer"" aus.'");
		EndIf;
		
	EndIf;
	
	FillingStrategy = New Map;
	FillingStrategy[Type("Structure")]						= "FillByStructure";
	FillingStrategy[Type("DocumentRef.GoodsIssue")]			= "FillByGoodsIssue";

	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	Documents.VATInvoiceForICT.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectVATInput(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectVATOutput(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);

	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.VATInvoiceForICT.RunControl(Ref, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.VATInvoiceForICT.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

Procedure OnCopy(CopiedObject)
	
	Author = Users.CurrentUser();
	
	If SerialNumbers.Count() Then
		
		For Each InventoryRow In Inventory Do
			InventoryRow.SerialNumbers = "";
		EndDo;
		
		SerialNumbers.Clear();
		
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, AdditionalProperties.WriteMode, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

#EndRegion

#Region Private

Function GetQueryTextForFIFO()
	
	Return
	"SELECT ALLOWED
	|	TT_Parameters.Products AS Products,
	|	TT_Parameters.Characteristic AS Characteristic,
	|	TT_Parameters.Batch AS Batch,
	|	ISNULL(InventoryCostLayer.CostLayer, UNDEFINED) AS CostLayer,
	|	ISNULL(InventoryCostLayer.Quantity, 0) AS Quantity,
	|	ISNULL(InventoryCostLayer.Amount, 0) AS Amount
	|INTO TT_FIFOData
	|FROM
	|	TT_Parameters AS TT_Parameters
	|		LEFT JOIN AccumulationRegister.InventoryCostLayer AS InventoryCostLayer
	|		ON TT_Parameters.Company = InventoryCostLayer.Company
	|			AND TT_Parameters.PresentationCurrency = InventoryCostLayer.PresentationCurrency
	|			AND TT_Parameters.Products = InventoryCostLayer.Products
	|			AND TT_Parameters.Characteristic = InventoryCostLayer.Characteristic
	|			AND TT_Parameters.Batch = InventoryCostLayer.Batch
	|			AND TT_Parameters.GLAccount = InventoryCostLayer.GLAccount
	|			AND TT_Parameters.StructuralUnit = InventoryCostLayer.StructuralUnit
	|			AND (InventoryCostLayer.Recorder = &GoodsIssue)
	|			AND (InventoryCostLayer.RecordType = VALUE(AccumulationRecordType.Expense))
	|
	|UNION ALL
	|
	|SELECT
	|	TT_Parameters.Products,
	|	TT_Parameters.Characteristic,
	|	TT_Parameters.Batch,
	|	ISNULL(LandedCosts.CostLayer, UNDEFINED),
	|	0,
	|	ISNULL(LandedCosts.Amount, 0)
	|FROM
	|	TT_Parameters AS TT_Parameters
	|		LEFT JOIN AccumulationRegister.LandedCosts AS LandedCosts
	|		ON TT_Parameters.Company = LandedCosts.Company
	|			AND TT_Parameters.PresentationCurrency = LandedCosts.PresentationCurrency
	|			AND TT_Parameters.Products = LandedCosts.Products
	|			AND TT_Parameters.Characteristic = LandedCosts.Characteristic
	|			AND TT_Parameters.Batch = LandedCosts.Batch
	|			AND TT_Parameters.GLAccount = LandedCosts.GLAccount
	|			AND TT_Parameters.StructuralUnit = LandedCosts.StructuralUnit
	|			AND (LandedCosts.Recorder = &GoodsIssue)
	|			AND (LandedCosts.RecordType = VALUE(AccumulationRecordType.Expense))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_FIFOData.Products AS Products,
	|	TT_FIFOData.Characteristic AS Characteristic,
	|	TT_FIFOData.Batch AS Batch,
	|	SUM(TT_FIFOData.Quantity) AS Quantity,
	|	SUM(TT_FIFOData.Amount) AS Amount
	|INTO TT_FIFODataUnion
	|FROM
	|	TT_FIFOData AS TT_FIFOData
	|WHERE
	|	TT_FIFOData.CostLayer <> UNDEFINED
	|
	|GROUP BY
	|	TT_FIFOData.Products,
	|	TT_FIFOData.Characteristic,
	|	TT_FIFOData.Batch,
	|	TT_FIFOData.CostLayer
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_FIFODataUnion.Products AS Products,
	|	TT_FIFODataUnion.Characteristic AS Characteristic,
	|	TT_FIFODataUnion.Batch AS Batch,
	|	TT_FIFODataUnion.Quantity AS Quantity,
	|	CAST(CASE
	|			WHEN TT_FIFODataUnion.Quantity = 0
	|				THEN 0
	|			ELSE TT_FIFODataUnion.Amount / TT_FIFODataUnion.Quantity
	|		END AS NUMBER(15, 2)) AS Price,
	|	TT_FIFODataUnion.Amount AS Amount
	|INTO TT_Prices
	|FROM
	|	TT_FIFODataUnion AS TT_FIFODataUnion
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TT_FIFOData
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TT_FIFODataUnion
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TT_Parameters";
	
EndFunction

Function GetQueryTextForWeightedAverage()
	
	Return
	"SELECT ALLOWED
	|	TT_Parameters.Products AS Products,
	|	TT_Parameters.Characteristic AS Characteristic,
	|	TT_Parameters.Batch AS Batch,
	|	ISNULL(Inventory.Quantity, 0) AS Quantity,
	|	CAST(CASE
	|			WHEN ISNULL(Inventory.Quantity, 0) = 0
	|				THEN 0
	|			ELSE ISNULL(Inventory.Amount, 0) / ISNULL(Inventory.Quantity, 0)
	|		END AS NUMBER(15, 2)) AS Price,
	|	ISNULL(Inventory.Amount, 0) AS Amount
	|INTO TT_Prices
	|FROM
	|	TT_Parameters AS TT_Parameters
	|		LEFT JOIN AccumulationRegister.Inventory AS Inventory
	|		ON TT_Parameters.Company = Inventory.Company
	|			AND TT_Parameters.PresentationCurrency = Inventory.PresentationCurrency
	|			AND TT_Parameters.Products = Inventory.Products
	|			AND TT_Parameters.Characteristic = Inventory.Characteristic
	|			AND TT_Parameters.Batch = Inventory.Batch
	|			AND TT_Parameters.GLAccount = Inventory.GLAccount
	|			AND TT_Parameters.StructuralUnit = Inventory.StructuralUnit
	|			AND (Inventory.Recorder = &GoodsIssue)
	|			AND (Inventory.RecordType = VALUE(AccumulationRecordType.Expense))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TT_Parameters";
	
EndFunction

#EndRegion 

#EndIf