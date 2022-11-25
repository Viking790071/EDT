#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Print

Function GetQueryText()
	
	QueryText = 
	"SELECT ALLOWED
	|	TaxInvoiceIssued.Ref AS Ref
	|INTO TaxInvoices
	|FROM
	|	Document.TaxInvoiceIssued AS TaxInvoiceIssued
	|WHERE
	|	TaxInvoiceIssued.Ref IN(&ObjectsArray)
	|
	|UNION ALL
	|
	|SELECT
	|	TaxInvoiceIssuedBasisDocuments.Ref
	|FROM
	|	Document.TaxInvoiceIssued.BasisDocuments AS TaxInvoiceIssuedBasisDocuments
	|WHERE
	|	TaxInvoiceIssuedBasisDocuments.BasisDocument IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TaxInvoiceIssuedBasisDocuments.BasisDocument AS BasisDocument,
	|	TaxInvoiceIssued.Number AS Number,
	|	TaxInvoiceIssued.Date AS Date,
	|	TaxInvoices.Ref AS Ref
	|INTO BasisDocumentsWithTaxInvoice
	|FROM
	|	TaxInvoices AS TaxInvoices
	|		INNER JOIN Document.TaxInvoiceIssued.BasisDocuments AS TaxInvoiceIssuedBasisDocuments
	|		ON TaxInvoices.Ref = TaxInvoiceIssuedBasisDocuments.Ref
	|		INNER JOIN Document.TaxInvoiceIssued AS TaxInvoiceIssued
	|		ON TaxInvoices.Ref = TaxInvoiceIssued.Ref
	|			AND (TaxInvoiceIssued.Posted)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Number AS Number,
	|	SalesInvoice.Date AS Date,
	|	SalesInvoice.Company AS Company,
	|	SalesInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	SalesInvoice.Counterparty AS Counterparty,
	|	SalesInvoice.Contract AS Contract,
	|	SalesInvoice.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesInvoice.DocumentCurrency AS DocumentCurrency,
	|	CAST(SalesInvoice.Comment AS STRING(1024)) AS Comment,
	|	SalesInvoice.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT) AS ReverseCharge,
	|	SalesInvoice.StructuralUnit AS StructuralUnit,
	|	SalesInvoice.Ref AS BasisDocument,
	|	TRUE AS RegisterVATEntriesBySourceDocuments,
	|	SalesInvoice.Number AS ReferenceNumber,
	|	SalesInvoice.Date AS ReferenceDate,
	|	SalesInvoice.DocumentCurrency AS ReferenceCurrency,
	|	SalesInvoice.ExchangeRate AS ReferenceRate
	|INTO Documents
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref IN(&ObjectsArray)
	|
	|UNION ALL
	|
	|SELECT
	|	CreditNote.Ref,
	|	CreditNote.Number,
	|	CreditNote.Date,
	|	CreditNote.Company,
	|	CreditNote.CompanyVATNumber,
	|	CreditNote.Counterparty,
	|	CreditNote.Contract,
	|	CreditNote.AmountIncludesVAT,
	|	CreditNote.DocumentCurrency,
	|	CAST(CreditNote.Comment AS STRING(1024)),
	|	CreditNote.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT),
	|	CreditNote.StructuralUnit,
	|	CreditNote.Ref,
	|	TRUE,
	|	CreditNote.Number,
	|	CreditNote.Date,
	|	CreditNote.DocumentCurrency,
	|	CreditNote.ExchangeRate
	|FROM
	|	Document.CreditNote AS CreditNote
	|WHERE
	|	CreditNote.Ref IN(&ObjectsArray)
	|
	|UNION ALL
	|
	|SELECT
	|	BasisDocumentsWithTaxInvoice.Ref,
	|	BasisDocumentsWithTaxInvoice.Number,
	|	BasisDocumentsWithTaxInvoice.Date,
	|	SalesInvoice.Company,
	|	SalesInvoice.CompanyVATNumber,
	|	SalesInvoice.Counterparty,
	|	SalesInvoice.Contract,
	|	SalesInvoice.AmountIncludesVAT,
	|	SalesInvoice.DocumentCurrency,
	|	CAST(SalesInvoice.Comment AS STRING(1024)),
	|	SalesInvoice.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT),
	|	SalesInvoice.StructuralUnit,
	|	SalesInvoice.Ref,
	|	FALSE,
	|	SalesInvoice.Number,
	|	SalesInvoice.Date,
	|	SalesInvoice.DocumentCurrency,
	|	SalesInvoice.ExchangeRate
	|FROM
	|	BasisDocumentsWithTaxInvoice AS BasisDocumentsWithTaxInvoice
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON BasisDocumentsWithTaxInvoice.BasisDocument = SalesInvoice.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	BasisDocumentsWithTaxInvoice.Ref,
	|	BasisDocumentsWithTaxInvoice.Number,
	|	BasisDocumentsWithTaxInvoice.Date,
	|	CreditNote.Company,
	|	CreditNote.CompanyVATNumber,
	|	CreditNote.Counterparty,
	|	CreditNote.Contract,
	|	CreditNote.AmountIncludesVAT,
	|	CreditNote.DocumentCurrency,
	|	CAST(CreditNote.Comment AS STRING(1024)),
	|	CreditNote.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT),
	|	CreditNote.StructuralUnit,
	|	CreditNote.Ref,
	|	FALSE,
	|	CreditNote.Number,
	|	CreditNote.Date,
	|	CreditNote.DocumentCurrency,
	|	CreditNote.ExchangeRate
	|FROM
	|	BasisDocumentsWithTaxInvoice AS BasisDocumentsWithTaxInvoice
	|		INNER JOIN Document.CreditNote AS CreditNote
	|		ON BasisDocumentsWithTaxInvoice.BasisDocument = CreditNote.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Documents.Ref AS Ref,
	|	Documents.Number AS Number,
	|	Documents.Date AS Date,
	|	Documents.Company AS Company,
	|	Documents.CompanyVATNumber AS CompanyVATNumber,
	|	Documents.Counterparty AS Counterparty,
	|	Documents.Contract AS Contract,
	|	Documents.AmountIncludesVAT AS AmountIncludesVAT,
	|	Documents.DocumentCurrency AS DocumentCurrency,
	|	Documents.Comment AS Comment,
	|	Documents.ReverseCharge AS ReverseCharge,
	|	Documents.StructuralUnit AS StructuralUnit,
	|	Documents.BasisDocument AS BasisDocument,
	|	Documents.RegisterVATEntriesBySourceDocuments AS RegisterVATEntriesBySourceDocuments,
	|	MAX(AccountingPolicy.Period) AS Period,
	|	Documents.ReferenceDate AS ReferenceDate,
	|	Documents.ReferenceNumber AS ReferenceNumber,
	|	Documents.ReferenceCurrency AS ReferenceCurrency,
	|	Documents.ReferenceRate AS ReferenceRate,
	|	MAX(ExchangeRate.Period) AS PeriodExchangeRate
	|INTO DocumentsMaxAccountingPolicy
	|FROM
	|	Documents AS Documents
	|		LEFT JOIN InformationRegister.AccountingPolicy AS AccountingPolicy
	|		ON Documents.Company = AccountingPolicy.Company
	|			AND Documents.Date >= AccountingPolicy.Period
	|		LEFT JOIN InformationRegister.ExchangeRate AS ExchangeRate
	|		ON Documents.DocumentCurrency = ExchangeRate.Currency
	|			AND Documents.Company = ExchangeRate.Company
	|			AND Documents.Date >= ExchangeRate.Period
	|
	|GROUP BY
	|	Documents.Counterparty,
	|	Documents.DocumentCurrency,
	|	Documents.RegisterVATEntriesBySourceDocuments,
	|	Documents.ReverseCharge,
	|	Documents.Comment,
	|	Documents.AmountIncludesVAT,
	|	Documents.StructuralUnit,
	|	Documents.Contract,
	|	Documents.BasisDocument,
	|	Documents.Ref,
	|	Documents.Number,
	|	Documents.Company,
	|	Documents.CompanyVATNumber,
	|	Documents.Date,
	|	Documents.ReferenceDate,
	|	Documents.ReferenceNumber,
	|	Documents.ReferenceCurrency,
	|	Documents.ReferenceRate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DocumentsMaxAccountingPolicy.Ref AS Ref,
	|	DocumentsMaxAccountingPolicy.Number AS Number,
	|	DocumentsMaxAccountingPolicy.Date AS Date,
	|	DocumentsMaxAccountingPolicy.Company AS Company,
	|	DocumentsMaxAccountingPolicy.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentsMaxAccountingPolicy.Counterparty AS Counterparty,
	|	DocumentsMaxAccountingPolicy.Contract AS Contract,
	|	DocumentsMaxAccountingPolicy.AmountIncludesVAT AS AmountIncludesVAT,
	|	DocumentsMaxAccountingPolicy.DocumentCurrency AS DocumentCurrency,
	|	DocumentsMaxAccountingPolicy.Comment AS Comment,
	|	DocumentsMaxAccountingPolicy.ReverseCharge AS ReverseCharge,
	|	DocumentsMaxAccountingPolicy.StructuralUnit AS StructuralUnit,
	|	DocumentsMaxAccountingPolicy.BasisDocument AS BasisDocument,
	|	DocumentsMaxAccountingPolicy.RegisterVATEntriesBySourceDocuments AS RegisterVATEntriesBySourceDocuments,
	|	DocumentsMaxAccountingPolicy.ReferenceNumber AS ReferenceNumber,
	|	DocumentsMaxAccountingPolicy.ReferenceDate AS ReferenceDate,
	|	DocumentsMaxAccountingPolicy.ReferenceCurrency AS ReferenceCurrency,
	|	DocumentsMaxAccountingPolicy.ReferenceRate AS ReferenceRate,
	|	ExchangeRate.Rate AS ExchangeRate,
	|	ExchangeRate.Repetition AS Multiplicity
	|INTO FilteredDocuments
	|FROM
	|	DocumentsMaxAccountingPolicy AS DocumentsMaxAccountingPolicy
	|		INNER JOIN InformationRegister.AccountingPolicy AS AccountingPolicy
	|		ON DocumentsMaxAccountingPolicy.Company = AccountingPolicy.Company
	|			AND DocumentsMaxAccountingPolicy.Period = AccountingPolicy.Period
	|			AND DocumentsMaxAccountingPolicy.RegisterVATEntriesBySourceDocuments = AccountingPolicy.PostVATEntriesBySourceDocuments
	|		INNER JOIN InformationRegister.ExchangeRate AS ExchangeRate
	|		ON DocumentsMaxAccountingPolicy.DocumentCurrency = ExchangeRate.Currency
	|			AND DocumentsMaxAccountingPolicy.Company = ExchangeRate.Company
	|			AND DocumentsMaxAccountingPolicy.PeriodExchangeRate = ExchangeRate.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	FilteredDocuments.Ref AS Ref,
	|	FilteredDocuments.Number AS DocumentNumber,
	|	FilteredDocuments.Date AS DocumentDate,
	|	FilteredDocuments.Company AS Company,
	|	FilteredDocuments.CompanyVATNumber AS CompanyVATNumber,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	FilteredDocuments.Counterparty AS Counterparty,
	|	FilteredDocuments.Contract AS Contract,
	|	FilteredDocuments.AmountIncludesVAT AS AmountIncludesVAT,
	|	FilteredDocuments.DocumentCurrency AS DocumentCurrency,
	|	FilteredDocuments.Comment AS Comment,
	|	FilteredDocuments.ReverseCharge AS ReverseCharge,
	|	FilteredDocuments.StructuralUnit AS StructuralUnit,
	|	FilteredDocuments.BasisDocument AS BasisDocument,
	|	FilteredDocuments.ReferenceNumber AS ReferenceNumber,
	|	FilteredDocuments.ReferenceDate AS ReferenceDate,
	|	FilteredDocuments.ReferenceCurrency AS ReferenceCurrency,
	|	FilteredDocuments.ReferenceRate AS ReferenceRate,
	|	Companies.PresentationCurrency AS PresentationCurrency,
	|	Companies.ExchangeRateMethod AS ExchangeRateMethod,
	|	FilteredDocuments.ExchangeRate AS ExchangeRate,
	|	FilteredDocuments.Multiplicity AS Multiplicity
	|INTO Header
	|FROM
	|	FilteredDocuments AS FilteredDocuments
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON FilteredDocuments.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON FilteredDocuments.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON FilteredDocuments.Contract = CounterpartyContracts.Ref
	|
	|GROUP BY
	|	FilteredDocuments.Number,
	|	FilteredDocuments.Date,
	|	FilteredDocuments.Counterparty,
	|	FilteredDocuments.Company,
	|	FilteredDocuments.CompanyVATNumber,
	|	Companies.LogoFile,
	|	FilteredDocuments.Ref,
	|	FilteredDocuments.Comment,
	|	FilteredDocuments.DocumentCurrency,
	|	FilteredDocuments.AmountIncludesVAT,
	|	FilteredDocuments.ReverseCharge,
	|	FilteredDocuments.Contract,
	|	FilteredDocuments.StructuralUnit,
	|	FilteredDocuments.BasisDocument,
	|	FilteredDocuments.ReferenceNumber,
	|	FilteredDocuments.ReferenceDate,
	|	FilteredDocuments.ReferenceCurrency,
	|	Companies.PresentationCurrency,
	|	Companies.ExchangeRateMethod,
	|	FilteredDocuments.ReferenceRate,
	|	FilteredDocuments.ExchangeRate,
	|	FilteredDocuments.Multiplicity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	FilteredDocuments.Ref AS Ref,
	|	SalesInvoiceInventory.LineNumber AS LineNumber,
	|	SalesInvoiceInventory.Products AS Products,
	|	SalesInvoiceInventory.Characteristic AS Characteristic,
	|	SalesInvoiceInventory.Batch AS Batch,
	|	SalesInvoiceInventory.Quantity AS Quantity,
	|	SalesInvoiceInventory.Reserve AS Reserve,
	|	SalesInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	SalesInvoiceInventory.Price AS Price,
	|	SalesInvoiceInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SalesInvoiceInventory.Amount AS Amount,
	|	SalesInvoiceInventory.VATRate AS VATRate,
	|	SalesInvoiceInventory.VATAmount AS VATAmount,
	|	SalesInvoiceInventory.Total AS Total,
	|	SalesInvoiceInventory.Order AS Order,
	|	SalesInvoiceInventory.Content AS Content,
	|	SalesInvoiceInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	SalesInvoiceInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	SalesInvoiceInventory.ConnectionKey AS ConnectionKey,
	|	FilteredDocuments.BasisDocument AS BasisDocument,
	|	CAST(SalesInvoiceInventory.Quantity * SalesInvoiceInventory.Price - SalesInvoiceInventory.Amount AS NUMBER(15, 2)) AS DiscountAmount,
	|	SalesInvoiceInventory.BundleProduct AS BundleProduct,
	|	SalesInvoiceInventory.BundleCharacteristic AS BundleCharacteristic
	|INTO FilteredInventory
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		INNER JOIN FilteredDocuments AS FilteredDocuments
	|		ON SalesInvoiceInventory.Ref = FilteredDocuments.BasisDocument
	|
	|UNION ALL
	|
	|SELECT
	|	FilteredDocuments.Ref,
	|	CreditNoteInventory.LineNumber,
	|	CreditNoteInventory.Products,
	|	CreditNoteInventory.Characteristic,
	|	CreditNoteInventory.Batch,
	|	CreditNoteInventory.Quantity,
	|	0,
	|	CreditNoteInventory.MeasurementUnit,
	|	CASE
	|		WHEN CreditNoteInventory.Quantity = 0
	|			THEN 0
	|		ELSE CreditNoteInventory.Amount / CreditNoteInventory.Quantity
	|	END,
	|	0,
	|	CreditNoteInventory.Amount,
	|	CreditNoteInventory.VATRate,
	|	CreditNoteInventory.VATAmount,
	|	CreditNoteInventory.Total,
	|	CreditNoteInventory.Order,
	|	"""",
	|	0,
	|	0,
	|	CreditNoteInventory.ConnectionKey,
	|	FilteredDocuments.BasisDocument,
	|	0,
	|	CreditNoteInventory.BundleProduct,
	|	CreditNoteInventory.BundleCharacteristic
	|FROM
	|	Document.CreditNote.Inventory AS CreditNoteInventory
	|		INNER JOIN FilteredDocuments AS FilteredDocuments
	|		ON CreditNoteInventory.Ref = FilteredDocuments.BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Counterparty AS Counterparty,
	|	Header.Contract AS Contract,
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.Comment AS Comment,
	|	Header.ReverseCharge AS ReverseCharge,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """" AS ContentUsed,
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
	|	FilteredInventory.Price * CASE
	|		WHEN Header.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN Header.Multiplicity / Header.ExchangeRate
	|		WHEN Header.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN Header.ExchangeRate / Header.Multiplicity
	|	END AS Price,
	|	FilteredInventory.DiscountMarkupPercent AS DiscountRate,
	|	SUM(FilteredInventory.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
	|	SUM(CAST(FilteredInventory.Amount * CASE
	|				WHEN Header.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN Header.Multiplicity / Header.ExchangeRate
	|				WHEN Header.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN Header.ExchangeRate / Header.Multiplicity
	|			END AS NUMBER(15, 2))) AS Amount,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(CAST(FilteredInventory.VATAmount * CASE
	|				WHEN Header.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN Header.Multiplicity / Header.ExchangeRate
	|				WHEN Header.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN Header.ExchangeRate / Header.Multiplicity
	|			END AS NUMBER(15, 2))) AS VATAmount,
	|	SUM(CAST(FilteredInventory.Total * CASE
	|				WHEN Header.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN Header.Multiplicity / Header.ExchangeRate
	|				WHEN Header.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN Header.ExchangeRate / Header.Multiplicity
	|			END AS NUMBER(15, 2))) AS Total,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST((FilteredInventory.Amount - FilteredInventory.VATAmount + FilteredInventory.DiscountAmount) * CASE
	|							WHEN Header.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN Header.Multiplicity / Header.ExchangeRate
	|							WHEN Header.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN Header.ExchangeRate / Header.Multiplicity
	|						END AS NUMBER(15, 2))
	|			ELSE CAST(FilteredInventory.Quantity * FilteredInventory.Price * CASE
	|						WHEN Header.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN Header.Multiplicity / Header.ExchangeRate
	|						WHEN Header.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN Header.ExchangeRate / Header.Multiplicity
	|					END AS NUMBER(15, 2))
	|		END) AS Subtotal,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.StructuralUnit AS StructuralUnit,
	|	Header.BasisDocument AS BasisDocument,
	|	Header.ReferenceNumber AS ReferenceNumber,
	|	Header.ReferenceDate AS ReferenceDate,
	|	Header.ReferenceCurrency AS ReferenceCurrency,
	|	Header.ReferenceRate AS ReferenceRate,
	|	SUM(CAST(FilteredInventory.DiscountAmount * CASE
	|				WHEN Header.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN Header.Multiplicity / Header.ExchangeRate
	|				WHEN Header.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN Header.ExchangeRate / Header.Multiplicity
	|			END AS NUMBER(15, 2))) AS DiscountAmount,
	|	Header.PresentationCurrency AS PresentationCurrency,
	|	FilteredInventory.Total AS TotalCur,
	|	FilteredInventory.BundleProduct AS BundleProduct,
	|	FilteredInventory.BundleCharacteristic AS BundleCharacteristic
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.BasisDocument = FilteredInventory.BasisDocument
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
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	Header.ExchangeRateMethod,
	|	Header.Ref,
	|	Header.Counterparty,
	|	Header.CompanyLogoFile,
	|	Header.Contract,
	|	Header.AmountIncludesVAT,
	|	Header.DocumentCurrency,
	|	Header.Comment,
	|	Header.ReverseCharge,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.UseSerialNumbers,
	|	FilteredInventory.VATRate,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """",
	|	FilteredInventory.DiscountMarkupPercent,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	Header.StructuralUnit,
	|	Header.BasisDocument,
	|	Header.ReferenceNumber,
	|	Header.ReferenceDate,
	|	Header.ReferenceCurrency,
	|	Header.PresentationCurrency,
	|	Header.ReferenceRate,
	|	FilteredInventory.Total,
	|	FilteredInventory.BundleProduct,
	|	FilteredInventory.BundleCharacteristic,
	|	FilteredInventory.Price * CASE
	|		WHEN Header.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN Header.Multiplicity / Header.ExchangeRate
	|		WHEN Header.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN Header.ExchangeRate / Header.Multiplicity
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	SUM(Tabular.Total) AS TotalForCount
	|INTO TotalTable
	|FROM
	|	Tabular AS Tabular
	|
	|GROUP BY
	|	Tabular.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyVATNumber AS CompanyVATNumber,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Counterparty AS Counterparty,
	|	Tabular.Contract AS Contract,
	|	Tabular.AmountIncludesVAT AS AmountIncludesVAT,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Price AS Price,
	|	Tabular.Amount AS TaxableAmount,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	Tabular.DiscountAmount AS DiscountAmount,
	|	CASE
	|		WHEN Tabular.AutomaticDiscountAmount = 0
	|			THEN Tabular.DiscountRate
	|		WHEN Tabular.Subtotal = 0
	|			THEN 0
	|		ELSE CAST((Tabular.Subtotal - Tabular.Amount) / Tabular.Subtotal * 100 AS NUMBER(15, 2))
	|	END AS DiscountRate,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	Tabular.StructuralUnit AS StructuralUnit,
	|	Tabular.BasisDocument AS BasisDocument,
	|	Tabular.ReferenceNumber AS ReferenceNumber,
	|	Tabular.ReferenceDate AS ReferenceDate,
	|	Tabular.ReferenceCurrency AS ReferenceCurrency,
	|	Tabular.ReferenceRate AS ReferenceRate,
	|	Tabular.PresentationCurrency AS PresentationCurrency,
	|	Tabular.TotalCur AS TotalCur,
	|	Tabular.BundleProduct AS BundleProduct,
	|	Tabular.BundleCharacteristic AS BundleCharacteristic
	|FROM
	|	Tabular AS Tabular
	|		LEFT JOIN TotalTable AS TotalTable
	|		ON Tabular.Ref = TotalTable.Ref
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	ReferenceNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyVATNumber),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(AmountIncludesVAT),
	|	MAX(DocumentCurrency),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	SUM(DiscountAmount),
	|	MAX(StructuralUnit),
	|	MAX(ReferenceNumber),
	|	MAX(ReferenceDate),
	|	MAX(ReferenceCurrency),
	|	MAX(ReferenceRate),
	|	MAX(PresentationCurrency),
	|	SUM(TotalCur)
	|BY
	|	Ref,
	|	BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	CASE
	|		WHEN Tabular.ReverseCharge
	|				AND Tabular.VATRate = VALUE(Catalog.VATRates.ZeroRate)
	|			THEN &ReverseChargeAppliesRate
	|		ELSE Tabular.VATRate
	|	END AS VATRate,
	|	SUM(Tabular.Amount) AS TaxableAmount,
	|	SUM(Tabular.VATAmount) AS VATAmount
	|FROM
	|	Tabular AS Tabular
	|
	|GROUP BY
	|	Tabular.Ref,
	|	CASE
	|		WHEN Tabular.ReverseCharge
	|				AND Tabular.VATRate = VALUE(Catalog.VATRates.ZeroRate)
	|			THEN &ReverseChargeAppliesRate
	|		ELSE Tabular.VATRate
	|	END
	|TOTALS BY
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
	|			AND FilteredInventory.DiscountMarkupPercent = Tabular.DiscountRate
	|			AND FilteredInventory.Price = Tabular.Price
	|			AND FilteredInventory.VATRate = Tabular.VATRate
	|			AND (NOT Tabular.ContentUsed)
	|			AND FilteredInventory.Ref = Tabular.Ref
	|			AND FilteredInventory.Characteristic = Tabular.Characteristic
	|			AND FilteredInventory.MeasurementUnit = Tabular.MeasurementUnit
	|			AND FilteredInventory.Batch = Tabular.Batch
	|		INNER JOIN Document.SalesInvoice.SerialNumbers AS SalesInvoiceSerialNumbers
	|			LEFT JOIN Catalog.SerialNumbers AS SerialNumbers
	|			ON SalesInvoiceSerialNumbers.SerialNumber = SerialNumbers.Ref
	|		ON (SalesInvoiceSerialNumbers.ConnectionKey = FilteredInventory.ConnectionKey)
	|			AND FilteredInventory.Ref = SalesInvoiceSerialNumbers.Ref";
	
	Return QueryText;
	
EndFunction

// Procedure of generating printed form Tax invoice
//
Function PrintTaxInvoice(ObjectsArray, PrintObjects, TemplateName, PrintParams)
	
    	DisplayPrintOption = (PrintParams <> Undefined);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_TaxInvoice";
	
	Query = New Query(GetQueryText());
	
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
	
	Query.SetParameter("ObjectsArray", ObjectsArray);
	Query.SetParameter("ReverseChargeAppliesRate", NStr("en = 'Reverse charge applies'; ru = 'Применяется реверсивный НДС';pl = 'Dotyczy odwrotnego obciążenia';es_ES = 'Inversión impositiva aplica';es_CO = 'Inversión impositiva aplica';tr = 'Karşı ödemeli ücret uygulanır';it = 'Applicare l''inversione di caricamento';de = 'Steuerschuldumkehr angewendet'", LanguageCode));
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	PrintableDocuments = New Array;
	
	Header				= ResultArray[9].Select(QueryResultIteration.ByGroups);
	TaxesHeaderSel		= ResultArray[10].Select(QueryResultIteration.ByGroups);
	SerialNumbersSel	= ResultArray[11].Select();
	
	// Bundles
	TableColumns = ResultArray[9].Columns;
	// End Bundles
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_TaxInvoice";
		
		Template = PrintManagement.PrintFormTemplate("DataProcessor.PrintTaxInvoice.PF_MXL_TaxInvoice", LanguageCode);
		
		#Region PrintTaxInvoiceTitleArea
		
		TitleArea = Template.GetArea("Title");
		TitleArea.Parameters.Fill(Header);
		
		If DisplayPrintOption Then 
			TitleArea.Parameters.OriginalDuplicate = ?(PrintParams.OriginalCopy,
				NStr("en = 'ORIGINAL'; ru = 'ОРИГИНАЛ';pl = 'ORYGINAŁ';es_ES = 'ORIGINAL';es_CO = 'ORIGINAL';tr = 'ORİJİNAL';it = 'ORIGINALE';de = 'ORIGINAL'", LanguageCode),
				NStr("en = 'COPY'; ru = 'КОПИЯ';pl = 'KOPIA';es_ES = 'COPIA';es_CO = 'COPIA';tr = 'KOPYALA';it = 'COPIA';de = 'KOPIE'", LanguageCode));
		EndIf;
		
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
		
		#Region PrintTaxInvoiceCompanyInfoArea
		
		CompanyInfoArea = Template.GetArea("CompanyInfo");
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Company, Header.DocumentDate, , , Header.CompanyVATNumber, LanguageCode);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		BarcodesInPrintForms.AddBarcodeToTableDocument(CompanyInfoArea, Header.Ref);
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		#EndRegion
		
		#Region PrintTaxInvoiceCounterpartyInfoArea
		
		CounterpartyInfoArea = Template.GetArea("CounterpartyInfo");
		CounterpartyInfoArea.Parameters.Fill(Header);
		
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Counterparty,
			Header.DocumentDate,
			,
			,
			,
			LanguageCode);
		CounterpartyInfoArea.Parameters.Fill(InfoAboutCounterparty);
		
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
		#EndRegion
		
		#Region PrintTaxInvoiceCommentArea
		
		CommentArea = Template.GetArea("Comment");
		CommentArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(CommentArea);
		
		#EndRegion
		
		#Region PrintTaxInvoiceTotalsAndTaxesAreaPrefill
		
		TotalsAndTaxesAreasArray = New Array;
		
		If DisplayPrintOption and PrintParams.Discount Then
			LineTotalArea = Template.GetArea("LineTotal");
			LineTotalArea.Parameters.Fill(Header);
		Else
			LineTotalArea = Template.GetArea("LineTotalWithoutDiscount");
			LineTotalArea.Parameters.Fill(Header);
			
			// When the "Discount" column is hidden, the results calculate by subtracting the subtotal and the discount.
			LineTotalArea.Parameters.Subtotal = Header.Subtotal-Header.DiscountAmount; 
			
		EndIf;
		
		TotalsAndTaxesAreasArray.Add(LineTotalArea);
		
		TaxesHeaderSel.Reset();
		If TaxesHeaderSel.FindNext(New Structure("Ref", Header.Ref)) Then
			
			TaxSectionHeaderArea = Template.GetArea("TaxSectionHeader");
			TotalsAndTaxesAreasArray.Add(TaxSectionHeaderArea);
			
			TaxesSel = TaxesHeaderSel.Select();
			While TaxesSel.Next() Do
				
				TaxSectionLineArea = Template.GetArea("TaxSectionLine");
				TaxSectionLineArea.Parameters.Fill(TaxesSel);
				TotalsAndTaxesAreasArray.Add(TaxSectionLineArea);
				
			EndDo;
			
		EndIf;
		
		#EndRegion
		
		#Region PrintTaxInvoiceLinesArea
		
		If DisplayPrintOption Then 
			If PrintParams.Discount Then 
				If PrintParams.CodesPosition <> Enums.CodesPositionInPrintForms.SeparateColumn Then 
					// Template 1: Hide "Intem #", show "Disc.rate"
					LineHeaderArea = Template.GetArea("LineHeaderWithoutCode");
					LineSectionArea	= Template.GetArea("LineSectionWithoutCode");
				Else
					// Template 2: Show all columns
					LineHeaderArea = Template.GetArea("LineHeader");
					LineSectionArea	= Template.GetArea("LineSection");
				EndIf;    
			Else
				If PrintParams.CodesPosition <> Enums.CodesPositionInPrintForms.SeparateColumn Then 
					// Template 3: Hide "Intem #", hide "Disc.rate"
					LineHeaderArea = Template.GetArea("LineHeaderWithoutItemAndDiscount");
					LineSectionArea	= Template.GetArea("LineSectionWithoutItemAndDiscount");
				Else
					// Template 4: Show "Intem #", hide "Disc.rate"
					LineHeaderArea = Template.GetArea("LineHeaderWithoutDiscount");
					LineSectionArea	= Template.GetArea("LineSectionWithoutDiscount");
				EndIf;
			EndIf;
		Else
			LineHeaderArea = Template.GetArea("LineHeader");
			LineSectionArea	= Template.GetArea("LineSection");
		EndIf;
		
		SpreadsheetDocument.Put(LineHeaderArea);
		
		InvoiceSectionArea	= Template.GetArea("InvoiceSection");
		
		SeeNextPageArea		= Template.GetArea("SeeNextPage");
		EmptyLineArea		= Template.GetArea("EmptyLine");
		PageNumberArea		= Template.GetArea("PageNumber");
		
		PageNumber = 0;
		
		DocumentSelection = Header.Select(QueryResultIteration.ByGroups);
		PricePrecision = PrecisionAppearancetServer.CompanyPrecision(Header.Company);
		
		While DocumentSelection.Next() Do
			
			InvoiceSectionArea.Parameters.Fill(DocumentSelection);
			
			BasisDocumentMetadata = DocumentSelection.BasisDocument.Metadata();
			DocumentType = BasisDocumentMetadata.ExtendedObjectPresentation;
			If IsBlankString(DocumentType) Then
				DocumentType = BasisDocumentMetadata.ObjectPresentation;
			EndIf;
			If IsBlankString(DocumentType) Then
				DocumentType = BasisDocumentMetadata.Presentation();
			EndIf;
			InvoiceSectionArea.Parameters.ReferenceType = DocumentType;
			
			InvoiceSectionArea.Parameters.ReferenceAmount = DocumentSelection.TotalCur;
			InvoiceSectionArea.Parameters.ReferenceDate = Format(DocumentSelection.ReferenceDate, "DLF=D");
			
			If DocumentSelection.DocumentCurrency <> DocumentSelection.PresentationCurrency Then
				InvoiceSectionArea.Parameters.ReferenceExchangeRate = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Exchange rate %1.'; ru = 'Курс валюты %1.';pl = 'Kurs waluty %1.';es_ES = 'Tipo de cambio %1.';es_CO = 'Tipo de cambio %1.';tr = 'Döviz kuru %1.';it = 'Tasso di cambio %1.';de = 'Wechselkurs %1.'", LanguageCode), DocumentSelection.ReferenceRate);
			EndIf;

			AreasToBeChecked = New Array;
			AreasToBeChecked.Add(InvoiceSectionArea);
			For Each Area In TotalsAndTaxesAreasArray Do
				AreasToBeChecked.Add(Area);
			EndDo;
			AreasToBeChecked.Add(PageNumberArea);
			
			If Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
				SpreadsheetDocument.Put(InvoiceSectionArea);
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
			
			// Bundles
			TableInventoty = BundlesServer.AssemblyTableByBundles(DocumentSelection.BasisDocument, DocumentSelection, TableColumns, LineTotalArea);
			EmptyColor = LineSectionArea.CurrentArea.TextColor;
			// End Bundles
			
			For Each TabSelection In TableInventoty Do
				
				LineSectionArea.Parameters.Fill(TabSelection);
				
				DriveClientServer.ComplimentProductDescription(LineSectionArea.Parameters.ProductDescription, TabSelection, SerialNumbersSel);
				
				If DisplayPrintOption Then
					CodesPresentation = PrintManagementServerCallDrive.GetCodesPresentation(PrintParams, TabSelection.Products);
					If PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.SeparateColumn Then
						LineSectionArea.Parameters.SKU = CodesPresentation;
					ElsIf PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.ProductColumn Then
						LineSectionArea.Parameters.ProductDescription = LineSectionArea.Parameters.ProductDescription + Chars.CR + CodesPresentation;                    
					EndIf;
				EndIf;
				
				// Bundles
				If DisplayPrintOption Then 
					If PrintParams.Discount Then 
						If PrintParams.CodesPosition <> Enums.CodesPositionInPrintForms.SeparateColumn Then 
							LineSectionArea.Areas.LineSectionWithoutCode.TextColor = BundlesServer.GetBundleComponentsColor(TabSelection, EmptyColor);
						Else
							LineSectionArea.Areas.LineSection.TextColor = BundlesServer.GetBundleComponentsColor(TabSelection, EmptyColor);
						EndIf;
					Else
						// Recalculate the price to display the correct information with a hidden discount.
						LineSectionArea.Parameters.Price = (TabSelection.Price * TabSelection.Quantity - (TabSelection.Price * TabSelection.Quantity * TabSelection.DiscountRate) / 100) / TabSelection.Quantity;
						
						If PrintParams.CodesPosition <> Enums.CodesPositionInPrintForms.SeparateColumn Then 
							LineSectionArea.Areas.LineSectionWithoutItemAndDiscount.TextColor = BundlesServer.GetBundleComponentsColor(TabSelection, EmptyColor);
						Else
							LineSectionArea.Areas.LineSectionWithoutDiscount.TextColor = BundlesServer.GetBundleComponentsColor(TabSelection, EmptyColor);
						EndIf;
					EndIf;
				Else
					LineSectionArea.Areas.LineSection.TextColor = BundlesServer.GetBundleComponentsColor(TabSelection, EmptyColor);
				EndIf;
				// End Bundles
				
				LineSectionArea.Parameters.Price = Format(LineSectionArea.Parameters.Price, "NFD= " + PricePrecision);
				
				AreasToBeChecked.Clear();
				AreasToBeChecked.Add(LineSectionArea);
				For Each Area In TotalsAndTaxesAreasArray Do
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
			
			PrintableDocuments.Add(DocumentSelection.BasisDocument);
		EndDo;
		#EndRegion
		
		#Region PrintTaxInvoiceTotalsAndTaxesArea
		
		For Each Area In TotalsAndTaxesAreasArray Do
			SpreadsheetDocument.Put(Area);
		EndDo;
		
		#Region PrintAdditionalAttributes
		If DisplayPrintOption And PrintParams.AdditionalAttributes And PrintManagementServerCallDrive.HasAdditionalAttributes(Header.Ref) Then
			
			SpreadsheetDocument.Put(EmptyLineArea);
			
			AddAttribHeader = Template.GetArea("AdditionalAttributesStaticHeader");
			SpreadsheetDocument.Put(AddAttribHeader);
			
			SpreadsheetDocument.Put(EmptyLineArea);
			
			AddAttribHeader = Template.GetArea("AdditionalAttributesHeader");
			SpreadsheetDocument.Put(AddAttribHeader);
			
			AddAttribRow = Template.GetArea("AdditionalAttributesRow");
			
			For each Attr In Header.Ref.AdditionalAttributes Do
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
	
	If ObjectsArray.Count() <> PrintableDocuments.Count() Then
		Errors = Undefined;
		For Each Document In ObjectsArray Do
			If PrintableDocuments.Find(Document) = Undefined Then
				If TypeOf(Document) = Type("DocumentRef.TaxInvoiceIssued") then
					MessagePattern = NStr("en = 'Tax invoice %1 cannot be printed. Please fill in all the required fields and try again.'; ru = 'Невозможно распечатать налоговый инвойс %1. Заполните все требуемые поля и повторите попытку.';pl = 'Faktura VAT %1 nie może być wydrukowany. Wypełnij wszystkie wymagane pola i spróbuj ponownie.';es_ES = 'La factura de impuestos %1 no se puede imprimir. Por favor, rellene todos los campos obligatorios e inténtelo de nuevo.';es_CO = 'La factura de impuestos %1 no se puede imprimir. Por favor, rellene todos los campos obligatorios e inténtelo de nuevo.';tr = '%1 vergi faturası yazdırılamıyor. Lütfen, tüm gerekli alanları doldurup tekrar deneyin.';it = 'La fattura fiscale %1 non può essere stampata. Si prega di compilare tutti i campi richiesti e provare ancora.';de = 'Die Steuerrechnung %1 kann nicht gedruckt werden. Bitte füllen Sie alle Pflichtfelder aus und versuchen Sie es erneut.'");
				Else
					MessagePattern = NStr("en = 'Generate Tax invoice document for %1 before printing.'; ru = 'Создайте документ налоговый инвойс для %1 перед печатью.';pl = 'Utwórz dokument faktury VAT %1 przed drukowaniem.';es_ES = 'Generar el documento de la Factura de impuestos para %1 antes de imprimir.';es_CO = 'Generar el documento de la Factura fiscal para %1 antes de imprimir.';tr = 'Yazdırmadan önce %1 için Vergi faturası belgesi oluşturun.';it = 'Generare il documento di fattura Fiscale per %1 prima della stampa.';de = 'Steuerrechnungsbeleg für %1 vor dem Druck generieren.'");
				EndIf;
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessagePattern, Document);
				CommonClientServer.AddUserError(Errors,, MessageText, Undefined);
			EndIf;
		EndDo;
		
		CommonClientServer.ReportErrorsToUser(Errors);
	EndIf;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Generate printed forms of objects
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined) Export
	
	If TemplateName = "TaxInvoice" Then
		
		Return PrintTaxInvoice(ObjectsArray, PrintObjects, TemplateName, PrintParams)
		
	EndIf;
	
EndFunction

#EndRegion

#EndIf
