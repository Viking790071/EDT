#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure RunControl(DocumentRefVATInvoiceForICT, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefVATInvoiceForICT, StructureAdditionalProperties) Export
	
	StructureAdditionalProperties.Insert("DefaultLanguageCode", Metadata.DefaultLanguage.LanguageCode);
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	Header.Ref AS Ref,
	|	Header.Date AS Date,
	|	&Company AS Company,
	|	Header.DestinationVATNumber AS DestinationVATNumber,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	Header.AmountIncludesVAT AS AmountIncludesVAT
	|INTO VATInvoiceForICTHeader
	|FROM
	|	Document.VATInvoiceForICT AS Header
	|WHERE
	|	Header.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VATInvoiceForICT.Ref AS Document,
	|	VATInvoiceForICT.Date AS Period,
	|	&Company AS Company,
	|	VATInvoiceForICT.DestinationVATNumber AS DestinationVATNumber,
	|	VATInvoiceForICT.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VATInvoiceForICT.DocumentCurrency AS DocumentCurrency,
	|	VATInvoiceForICTInventory.Products.ProductsType AS ProductsType,
	|	VATInvoiceForICTInventory.VATRate AS VATRate,
	|	VATInvoiceForICTInventory.VATInputGLAccount,
	|	VATInvoiceForICTInventory.VATOutputGLAccount,
	|	CAST(CASE
	|			WHEN VATInvoiceForICT.AmountIncludesVAT
	|				THEN 0
	|			ELSE VATInvoiceForICTInventory.VATAmount
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	VATInvoiceForICTInventory.Total AS Amount
	|INTO TemporaryTableInventory
	|FROM
	|	Document.VATInvoiceForICT.Inventory AS VATInvoiceForICTInventory
	|		INNER JOIN Document.VATInvoiceForICT AS VATInvoiceForICT
	|		ON VATInvoiceForICTInventory.Ref = VATInvoiceForICT.Ref
	|WHERE
	|	VATInvoiceForICTInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VATInvoiceForICT.Ref AS Document,
	|	VATInvoiceForICT.Date AS Period,
	|	&Company AS Company,
	|	VATInvoiceForICT.DestinationVATNumber AS DestinationVATNumber,
	|	VATInvoiceForICT.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VATInvoiceForICT.DocumentCurrency AS DocumentCurrency,
	|	VATInvoiceForICTInventoryDestination.Products.ProductsType AS ProductsType,
	|	VATInvoiceForICTInventoryDestination.VATRate AS VATRate,
	|	VATInvoiceForICTInventoryDestination.VATInputGLAccount,
	|	VATInvoiceForICTInventoryDestination.VATOutputGLAccount,
	|	CAST(CASE
	|			WHEN VATInvoiceForICT.AmountIncludesVAT
	|				THEN 0
	|			ELSE VATInvoiceForICTInventoryDestination.VATAmount
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	VATInvoiceForICTInventoryDestination.Total AS Amount
	|INTO TemporaryTableInventoryDestination
	|FROM
	|	Document.VATInvoiceForICT.InventoryDestination AS VATInvoiceForICTInventoryDestination
	|		INNER JOIN Document.VATInvoiceForICT AS VATInvoiceForICT
	|		ON VATInvoiceForICTInventoryDestination.Ref = VATInvoiceForICT.Ref
	|WHERE
	|	VATInvoiceForICTInventoryDestination.Ref = &Ref";
	
	Query.SetParameter("Ref",                  DocumentRefVATInvoiceForICT);
	Query.SetParameter("Company",              StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("DocumentCurrency",     DocumentRefVATInvoiceForICT.DocumentCurrency);
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefVATInvoiceForICT, StructureAdditionalProperties);
	
	GenerateTableAccountingEntriesData(DocumentRefVATInvoiceForICT, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefVATInvoiceForICT, StructureAdditionalProperties);
	EndIf;
	
	// VAT
	GenerateTableVATInput(DocumentRefVATInvoiceForICT, StructureAdditionalProperties);
	GenerateTableVATOutput(DocumentRefVATInvoiceForICT, StructureAdditionalProperties);
	
	FinancialAccounting.FillExtraDimensions(DocumentRefVATInvoiceForICT, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefVATInvoiceForICT, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefVATInvoiceForICT, StructureAdditionalProperties);
		
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

#EndRegion

#Region Private

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	ObjectParameters = StructureData.ObjectParameters;
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(ObjectParameters.Date, ObjectParameters.Company);
	GLAccountsForFilling = New Structure;
	
	GLAccountsForFilling.Insert("VATInputGLAccount", StructureData.VATInputGLAccount);
	GLAccountsForFilling.Insert("VATOutputGLAccount", StructureData.VATOutputGLAccount);
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	Return New Structure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Return New Structure;
	
EndFunction

#EndRegion

#Region TableGeneration

Procedure GenerateTableVATInput(DocumentRefVATInvoiceForICT, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	TemporaryTableInventoryDestination.Document AS ShipmentDocument,
	|	TemporaryTableInventoryDestination.Period AS Period,
	|	TemporaryTableInventoryDestination.Company AS Company,
	|	TemporaryTableInventoryDestination.DestinationVATNumber AS CompanyVATNumber,
	|	TemporaryTableInventoryDestination.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableInventoryDestination.Company AS Supplier,
	|	TemporaryTableInventoryDestination.VATRate AS VATRate,
	|	TemporaryTableInventoryDestination.VATInputGLAccount AS GLAccount,
	|	VALUE(Enum.VATOperationTypes.ReverseChargeApplied) AS OperationType,
	|	TemporaryTableInventoryDestination.ProductsType AS ProductType,
	|	SUM(TemporaryTableInventoryDestination.VATAmount) AS VATAmount,
	|	SUM(TemporaryTableInventoryDestination.Amount - TemporaryTableInventoryDestination.VATAmount) AS AmountExcludesVAT
	|FROM
	|	TemporaryTableInventoryDestination AS TemporaryTableInventoryDestination
	|
	|GROUP BY
	|	TemporaryTableInventoryDestination.Document,
	|	TemporaryTableInventoryDestination.Period,
	|	TemporaryTableInventoryDestination.Company,
	|	TemporaryTableInventoryDestination.DestinationVATNumber,
	|	TemporaryTableInventoryDestination.PresentationCurrency,
	|	TemporaryTableInventoryDestination.VATRate,
	|	TemporaryTableInventoryDestination.VATInputGLAccount,
	|	TemporaryTableInventoryDestination.ProductsType,
	|	TemporaryTableInventoryDestination.Company";
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", Query.Execute().Unload());
	
EndProcedure

Procedure GenerateTableVATOutput(DocumentRefVATInvoiceForICT, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	TemporaryTableInventoryDestination.Document AS ShipmentDocument,
	|	TemporaryTableInventoryDestination.Period AS Period,
	|	TemporaryTableInventoryDestination.Company AS Company,
	|	TemporaryTableInventoryDestination.DestinationVATNumber AS CompanyVATNumber,
	|	TemporaryTableInventoryDestination.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableInventoryDestination.Company AS Customer,
	|	TemporaryTableInventoryDestination.VATRate AS VATRate,
	|	TemporaryTableInventoryDestination.VATOutputGLAccount AS GLAccount,
	|	VALUE(Enum.VATOperationTypes.ReverseChargeApplied) AS OperationType,
	|	TemporaryTableInventoryDestination.ProductsType AS ProductType,
	|	TemporaryTableInventoryDestination.VATAmount AS VATAmount,
	|	TemporaryTableInventoryDestination.Amount - TemporaryTableInventoryDestination.VATAmount AS AmountExcludesVAT
	|INTO TT_VATOutput
	|FROM
	|	TemporaryTableInventoryDestination AS TemporaryTableInventoryDestination
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTableInventory.Document,
	|	TemporaryTableInventory.Period,
	|	TemporaryTableInventory.Company,
	|	TemporaryTableInventory.CompanyVATNumber,
	|	TemporaryTableInventory.PresentationCurrency,
	|	TemporaryTableInventory.Company,
	|	TemporaryTableInventory.VATRate,
	|	TemporaryTableInventory.VATOutputGLAccount,
	|	VALUE(Enum.VATOperationTypes.IntraCommunityTransfer),
	|	TemporaryTableInventory.ProductsType,
	|	TemporaryTableInventory.VATAmount,
	|	TemporaryTableInventory.Amount - TemporaryTableInventory.VATAmount
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_VATOutput.ShipmentDocument AS ShipmentDocument,
	|	TT_VATOutput.Period AS Period,
	|	TT_VATOutput.Company AS Company,
	|	TT_VATOutput.CompanyVATNumber AS CompanyVATNumber,
	|	TT_VATOutput.PresentationCurrency AS PresentationCurrency,
	|	TT_VATOutput.Customer AS Customer,
	|	TT_VATOutput.VATRate AS VATRate,
	|	TT_VATOutput.GLAccount AS GLAccount,
	|	TT_VATOutput.OperationType AS OperationType,
	|	TT_VATOutput.ProductType AS ProductType,
	|	SUM(TT_VATOutput.VATAmount) AS VATAmount,
	|	SUM(TT_VATOutput.AmountExcludesVAT) AS AmountExcludesVAT
	|FROM
	|	TT_VATOutput AS TT_VATOutput
	|
	|GROUP BY
	|	TT_VATOutput.ShipmentDocument,
	|	TT_VATOutput.Period,
	|	TT_VATOutput.Company,
	|	TT_VATOutput.CompanyVATNumber,
	|	TT_VATOutput.PresentationCurrency,
	|	TT_VATOutput.Customer,
	|	TT_VATOutput.GLAccount,
	|	TT_VATOutput.VATRate,
	|	TT_VATOutput.OperationType,
	|	TT_VATOutput.ProductType";
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", Query.Execute().Unload());
	
EndProcedure

Procedure GenerateTableAccountingJournalEntries(DocumentRefVATInvoiceForICT, StructureAdditionalProperties)

	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableAccountingJournalEntries.Period AS Period,
	|	TableAccountingJournalEntries.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&GLAccountVATReverseCharge AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurrDr,
	|	TableAccountingJournalEntries.VATOutputGLAccount AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	SUM(TableAccountingJournalEntries.VATAmount) AS Amount,
	|	&ReverseChargeVAT AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventoryDestination AS TableAccountingJournalEntries
	|WHERE
	|	&RegisteredForVAT
	|	AND TableAccountingJournalEntries.Amount > 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	TableAccountingJournalEntries.VATOutputGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	UNDEFINED,
	|	0,
	|	&GLAccountVATReverseCharge,
	|	UNDEFINED,
	|	0,
	|	SUM(TableAccountingJournalEntries.VATAmount),
	|	&ReverseChargeVATReclaimed,
	|	FALSE
	|FROM
	|	TemporaryTableInventoryDestination AS TableAccountingJournalEntries
	|WHERE
	|	&RegisteredForVAT
	|	AND TableAccountingJournalEntries.Amount > 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company";
	
	Query.SetParameter("RegisteredForVAT", StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	
	Query.SetParameter("ReverseChargeVAT",
		NStr("en = 'Reverse charge VAT'; ru = 'Реверсивный НДС';pl = 'Odwrotne obciążenie VAT';es_ES = 'IVA de la inversión impositiva';es_CO = 'IVA de la inversión impositiva';tr = 'Sorumlu sıfatıyla KDV';it = 'Invertire il caricamento IVA';de = 'Steuerschuldumkehr'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ReverseChargeVATReclaimed",
		NStr("en = 'Reverse charge VAT reclaimed'; ru = 'Реверсивный НДС отозван';pl = 'Odzyskane odwrotne obciążenie VAT';es_ES = 'Inversión impositiva IVA reclamado';es_CO = 'Inversión impositiva IVA reclamado';tr = 'Karşı ödemeli KDV iadesi';it = 'Reclamata l''inversione caricamento IVA';de = 'Steuerschuldumkehr zurückgewonnen'",
			StructureAdditionalProperties.DefaultLanguageCode));
			
	If Query.Parameters.RegisteredForVAT Then
		Query.SetParameter("GLAccountVATReverseCharge", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATReverseCharge"));
	Else
		Query.SetParameter("GLAccountVATReverseCharge", Undefined);
	EndIf;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

Function PrintVATInvoiceForICT(ObjectsArray, PrintObjects, TemplateName, PrintParams)
	
	DisplayPrintOption = (PrintParams <> Undefined);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_VATInvoiceForICT";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	#Region PrintOrderConfirmationQueryText
	
	Query.Text = 
	"SELECT ALLOWED
	|	VATInvoiceForICT.Ref AS Ref,
	|	VATInvoiceForICT.Number AS DocumentNumber,
	|	VATInvoiceForICT.Date AS DocumentDate,
	|	VATInvoiceForICT.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	VATInvoiceForICT.CompanyVATNumber AS CompanyVATNumber,
	|	VATInvoiceForICT.DestinationVATNumber AS DestinationVATNumber,
	|	VATInvoiceForICT.AmountIncludesVAT AS AmountIncludesVAT,
	|	VATInvoiceForICT.DocumentCurrency AS DocumentCurrency,
	|	VATInvoiceForICT.StructuralUnit AS StructuralUnit
	|INTO Header
	|FROM
	|	Document.VATInvoiceForICT AS VATInvoiceForICT
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON VATInvoiceForICT.Company = Companies.Ref
	|WHERE
	|	VATInvoiceForICT.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VATInvoiceForICTInventory.Ref AS Ref,
	|	VATInvoiceForICTInventory.LineNumber AS LineNumber,
	|	VATInvoiceForICTInventory.Products AS Products,
	|	VATInvoiceForICTInventory.Characteristic AS Characteristic,
	|	VATInvoiceForICTInventory.Batch AS Batch,
	|	VATInvoiceForICTInventory.Quantity AS Quantity,
	|	VATInvoiceForICTInventory.MeasurementUnit AS MeasurementUnit,
	|	VATInvoiceForICTInventory.Price * (VATInvoiceForICTInventory.Total - VATInvoiceForICTInventory.VATAmount) / VATInvoiceForICTInventory.Amount AS Price,
	|	VATInvoiceForICTInventory.Total - VATInvoiceForICTInventory.VATAmount AS Amount,
	|	VATInvoiceForICTInventory.VATRate AS VATRate,
	|	VATInvoiceForICTInventory.VATAmount AS VATAmount,
	|	VATInvoiceForICTInventory.Total AS Total,
	|	VATInvoiceForICTInventory.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	Document.VATInvoiceForICT.Inventory AS VATInvoiceForICTInventory
	|WHERE
	|	VATInvoiceForICTInventory.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.DestinationVATNumber AS DestinationVATNumber,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END AS BatchDescription,
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	MIN(FilteredInventory.ConnectionKey) AS ConnectionKey,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity) AS Quantity,
	|	FilteredInventory.Price AS Price,
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	SUM(FilteredInventory.Total) AS Total,
	|	SUM(FilteredInventory.Price * FilteredInventory.Quantity) AS Subtotal,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.Batch AS Batch,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	Header.StructuralUnit AS StructuralUnit
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (FilteredInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (FilteredInventory.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogBatches
	|		ON (FilteredInventory.Batch = CatalogBatches.Ref)
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOMClassifier.Ref)
	|
	|GROUP BY
	|	FilteredInventory.VATRate,
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	Header.DestinationVATNumber,
	|	CatalogProducts.SKU,
	|	Header.AmountIncludesVAT,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	Header.CompanyLogoFile,
	|	Header.DocumentNumber,
	|	Header.DocumentCurrency,
	|	Header.Ref,
	|	Header.DocumentDate,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.Batch,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Price,
	|	Header.StructuralUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyVATNumber AS CompanyVATNumber,
	|	Tabular.DestinationVATNumber AS DestinationVATNumber,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.AmountIncludesVAT AS AmountIncludesVAT,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Price AS Price,
	|	CASE
	|		WHEN Tabular.Subtotal = 0
	|			THEN 0
	|		ELSE CAST((Tabular.Subtotal - Tabular.Amount) / Tabular.Subtotal * 100 AS NUMBER(15, 2))
	|	END AS DiscountRate,
	|	Tabular.Amount AS Amount,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	Tabular.StructuralUnit AS StructuralUnit,
	|	Tabular.Products AS Products,
	|	FALSE AS ContentUsed
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyVATNumber),
	|	MAX(DestinationVATNumber),
	|	MAX(CompanyLogoFile),
	|	MAX(AmountIncludesVAT),
	|	MAX(DocumentCurrency),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	MAX(StructuralUnit)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	FilteredInventory AS FilteredInventory
	|		INNER JOIN Tabular AS Tabular
	|		ON FilteredInventory.Products = Tabular.Products
	|			AND FilteredInventory.Price = Tabular.Price
	|			AND FilteredInventory.VATRate = Tabular.VATRate
	|			AND FilteredInventory.Ref = Tabular.Ref
	|			AND FilteredInventory.Characteristic = Tabular.Characteristic
	|			AND FilteredInventory.MeasurementUnit = Tabular.MeasurementUnit
	|			AND FilteredInventory.Batch = Tabular.Batch
	|		INNER JOIN Document.SalesInvoice.SerialNumbers AS SalesOrderSerialNumbers
	|			LEFT JOIN Catalog.SerialNumbers AS SerialNumbers
	|			ON SalesOrderSerialNumbers.SerialNumber = SerialNumbers.Ref
	|		ON (SalesOrderSerialNumbers.ConnectionKey = FilteredInventory.ConnectionKey)
	|			AND FilteredInventory.Ref = SalesOrderSerialNumbers.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(Tabular.LineNumber) AS LineNumber,
	|	Tabular.Ref AS Ref,
	|	SUM(Tabular.Quantity) AS Quantity
	|FROM
	|	Tabular AS Tabular
	|
	|GROUP BY
	|	Tabular.Ref";
	
	#EndRegion
	
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	
	Header 				= ResultArray[3].Select(QueryResultIteration.ByGroupsWithHierarchy);
	SerialNumbersSel	= ResultArray[4].Select();
	TotalLineNumber		= ResultArray[5].Unload();
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_VATInvoiceForICT_VATInvoiceForICT";
		
		Template = PrintManagement.PrintFormTemplate("Document.VATInvoiceForICT.PF_MXL_VATInvoiceForICT");
		
		#Region PrintVATInvoiceForICTTitleArea
		
		TitleArea = Template.GetArea("Title");
		TitleArea.Parameters.Fill(Header);
		
		If ValueIsFilled(Header.CompanyLogoFile) Then
			
			PictureData = AttachedFiles.GetBinaryFileData(Header.CompanyLogoFile);
			If ValueIsFilled(PictureData) Then
				
				TitleArea.Drawings.Logo.Picture = New Picture(PictureData);
				
			EndIf;
			
		Else
			
			TitleArea.Drawings.Delete(TitleArea.Drawings.Logo);
			
		EndIf;
		
		SpreadsheetDocument.Put(TitleArea);
		
		#EndRegion
		
		#Region PrintVATInvoiceForICTCompanyInfoArea
		
		CompanyInfoArea = Template.GetArea("CompanyInfo");
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		
		CompanyInfoArea.Parameters.DestinationVATNumber = Header.DestinationVATNumber;
		CompanyInfoArea.Parameters.CompanyVATNumber = Header.CompanyVATNumber;
		
		BarcodesInPrintForms.AddBarcodeToTableDocument(CompanyInfoArea, Header.Ref);
		
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		#EndRegion
	
		#Region PrintVATInvoiceForICTTotalsAreaPrefill
		
		TotalsAreasArray = New Array;
         
		LineTotalArea = Template.GetArea("LineTotalWithoutDiscount");
		LineTotalArea.Parameters.Fill(Header); 
		
		SearchStructure = New Structure("Ref", Header.Ref);
		
		SearchArray = TotalLineNumber.FindRows(SearchStructure);
		If SearchArray.Count() > 0 Then
			LineTotalArea.Parameters.Quantity	= SearchArray[0].Quantity;
			LineTotalArea.Parameters.LineNumber	= SearchArray[0].LineNumber;
		Else
			LineTotalArea.Parameters.Quantity	= 0;
			LineTotalArea.Parameters.LineNumber	= 0;
		EndIf;
		
		TotalsAreasArray.Add(LineTotalArea);
		
		#EndRegion
		
		#Region PrintVATInvoiceForICTLinesArea
		
        If DisplayPrintOption Then 
            If PrintParams.CodesPosition <> Enums.CodesPositionInPrintForms.SeparateColumn Then 
                // Template 1: Hide "Item #"
                LineHeaderArea = Template.GetArea("LineHeaderWithoutItemAndDiscount");
                LineSectionArea	= Template.GetArea("LineSectionWithoutItemAndDiscount");
            Else
                // Template 2: Show "Item #"
                LineHeaderArea = Template.GetArea("LineHeaderWithoutDiscount");
                LineSectionArea	= Template.GetArea("LineSectionWithoutDiscount");
            EndIf;    
        Else            
            LineHeaderArea = Template.GetArea("LineHeaderWithoutDiscount");   		
    		LineSectionArea	= Template.GetArea("LineSectionWithoutDiscount");
        EndIf;
        
   		SpreadsheetDocument.Put(LineHeaderArea);
		
		SeeNextPageArea	= Template.GetArea("SeeNextPage");
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= Template.GetArea("PageNumber");
		
		PageNumber = 0;
		
		AreasToBeChecked = New Array;
		
		TabSelection = Header.Select();
		
		PricePrecision = PrecisionAppearancetServer.CompanyPrecision(Header.Company);
		
		While TabSelection.Next() Do
			
			LineSectionArea.Parameters.Fill(TabSelection);
			LineSectionArea.Parameters.Price = Format(TabSelection.Price,
				"NFD= " + PricePrecision);
			
			DriveClientServer.ComplimentProductDescription(LineSectionArea.Parameters.ProductDescription, TabSelection, SerialNumbersSel);
            
            // Display selected codes if functional option is turned on.
            If DisplayPrintOption Then
                CodesPresentation = PrintManagementServerCallDrive.GetCodesPresentation(PrintParams, TabSelection.Products);
                If PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.SeparateColumn Then
                    LineSectionArea.Parameters.SKU = CodesPresentation;
                ElsIf PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.ProductColumn Then
                    LineSectionArea.Parameters.ProductDescription = LineSectionArea.Parameters.ProductDescription + Chars.CR + CodesPresentation;                    
                EndIf;
            EndIf;
			
			AreasToBeChecked.Clear();
			AreasToBeChecked.Add(LineSectionArea);
			For Each Area In TotalsAreasArray Do
				AreasToBeChecked.Add(Area);
			EndDo;
			AreasToBeChecked.Add(PageNumberArea);
			
			If Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
				
				SpreadsheetDocument.Put(LineSectionArea);
				
			Else
				
				SpreadsheetDocument.Put(SeeNextPageArea);
				
				AreasToBeChecked.Clear();
				AreasToBeChecked.Add(EmptyLineArea);
				AreasToBeChecked.Add(PageNumberArea);
				
				For i = 1 To 50 Do
					
					If Not Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
						Or i = 50 Then
						
						PageNumber = PageNumber + 1;
						PageNumberArea.Parameters.PageNumber = PageNumber;
						SpreadsheetDocument.Put(PageNumberArea);
						Break;
						
					Else
						
						SpreadsheetDocument.Put(EmptyLineArea);
						
					EndIf;
					
				EndDo;
				
				SpreadsheetDocument.PutHorizontalPageBreak();
				SpreadsheetDocument.Put(TitleArea);
				SpreadsheetDocument.Put(LineHeaderArea);
				SpreadsheetDocument.Put(LineSectionArea);
				
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		#Region PrintVATInvoiceForICTTotalsArea
		
		For Each Area In TotalsAreasArray Do
			
			SpreadsheetDocument.Put(Area);
			
		EndDo;
		
		#Region PrintAdditionalAttributes
		
		If DisplayPrintOption And PrintParams.AdditionalAttributes
			And PrintManagementServerCallDrive.HasAdditionalAttributes(Header.Ref) Then
			
			SpreadsheetDocument.Put(EmptyLineArea);
			
			AddAttribHeader = Template.GetArea("AdditionalAttributesStaticHeader");
			SpreadsheetDocument.Put(AddAttribHeader);
			
			SpreadsheetDocument.Put(EmptyLineArea);
			
			AddAttribHeader = Template.GetArea("AdditionalAttributesHeader");
			SpreadsheetDocument.Put(AddAttribHeader);
			
			AddAttribRow = Template.GetArea("AdditionalAttributesRow");
			
			For Each Attr In Header.Ref.AdditionalAttributes Do
				AddAttribRow.Parameters.AddAttributeName = Attr.Property.Title;
				AddAttribRow.Parameters.AddAttributeValue = Attr.Value;
				SpreadsheetDocument.Put(AddAttribRow);
			EndDo;
			
		EndIf;
		
		#EndRegion
		
		AreasToBeChecked.Clear();
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
		
		For i = 1 To 50 Do
			
			If Not Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
				Or i = 50 Then
				
				PageNumber = PageNumber + 1;
				PageNumberArea.Parameters.PageNumber = PageNumber;
				SpreadsheetDocument.Put(PageNumberArea);
				Break;
				
			Else
				
				SpreadsheetDocument.Put(EmptyLineArea);
				
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Function checks if the document is posted and calls
// the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	If TemplateName = "VATInvoiceForICT" Then
		
		Return PrintVATInvoiceForICT(ObjectsArray, PrintObjects, TemplateName, PrintParams);
		
	EndIf;
	
EndFunction

// Generate printed forms of objects
//
// Incoming:
//  TemplateNames   - String	- Names of layouts separated by commas 
//	ObjectsArray	- Array		- Array of refs to objects that need to be printed 
//	PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection	- Values table	- Generated table documents 
//	OutputParameters		- Structure     - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "VATInvoiceForICT") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"VATInvoiceForICT",
			NStr("en = 'VAT invoice'; ru = 'Налоговая накладная';pl = 'Faktura VAT';es_ES = 'Factura de IVA';es_CO = 'Factura de IVA';tr = 'KDV faturası';it = 'IVA FATTURA';de = 'USt.-Rechnung'"), 
			PrintForm(ObjectsArray, PrintObjects, "VATInvoiceForICT", PrintParameters.Result));
		
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in Sales order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	// VAT invoice
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "VATInvoiceForICT";
	PrintCommand.Presentation				= NStr("en = 'VAT invoice'; ru = 'Налоговый инвойс';pl = 'Faktura VAT';es_ES = 'Factura de IVA';es_CO = 'Factura de IVA';tr = 'KDV faturası';it = 'IVA FATTURA';de = 'USt.-Rechnung'");
	PrintCommand.FormsList					= "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#EndRegion

#EndIf