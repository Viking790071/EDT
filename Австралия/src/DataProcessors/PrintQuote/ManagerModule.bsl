#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region PrintInterface

Function GetQueryText(ObjectsArray, TemplateName)
	
	QueryText = "";
	If ObjectsArray.Count() > 0 Then
		If TypeOf(ObjectsArray[0]) = Type("DocumentRef.Quote") And TemplateName = "Quote" Then
			QueryText = GetQuoteQueryTextForQuote(False);
		ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.Quote") And TemplateName = "QuoteAllVariants" Then
			QueryText = GetQuoteQueryTextForQuote(True);
		ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.Quote") And TemplateName = "ProformaInvoice" Then
			QueryText = GetProformaInvoiceQueryTextForQuote(False);
		ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.Quote") And TemplateName = "ProformaInvoiceAllVariants" Then
			QueryText = GetProformaInvoiceQueryTextForQuote(True);
		ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.SalesOrder") And TemplateName = "Quote" Then
			QueryText = GetQuoteQueryTextForSalesOrder();
		ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.SalesOrder") And TemplateName = "ProformaInvoice" Then
			QueryText = GetProformaInvoiceQueryTextForSalesOrder();
		EndIf;
	EndIf;
	
	Return QueryText;
	
EndFunction

Function GetProformaInvoiceQueryTextForQuote(AllVariants)
	
	QueryText = 
	"SELECT ALLOWED
	|	Quote.Ref AS Ref,
	|	Quote.Number AS Number,
	|	Quote.Date AS Date,
	|	Quote.Company AS Company,
	|	Quote.CompanyVATNumber AS CompanyVATNumber,
	|	Quote.Counterparty AS Counterparty,
	|	Quote.Contract AS Contract,
	|	Quote.BankAccount AS BankAccount,
	|	Quote.AmountIncludesVAT AS AmountIncludesVAT,
	|	Quote.DocumentCurrency AS DocumentCurrency,
	|	Quote.PreferredVariant AS PreferredVariant
	|INTO Quotes
	|FROM
	|	Document.Quote AS Quote
	|WHERE
	|	Quote.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Quote.Ref AS Ref,
	|	Quote.Number AS DocumentNumber,
	|	Quote.Date AS DocumentDate,
	|	Quote.Company AS Company,
	|	Quote.CompanyVATNumber AS CompanyVATNumber,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	Quote.Counterparty AS Counterparty,
	|	Quote.Contract AS Contract,
	|	Quote.BankAccount AS BankAccount,
	|	CASE
	|		WHEN CounterpartyContracts.ContactPerson = VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN Counterparties.ContactPerson
	|		ELSE CounterpartyContracts.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	Quote.AmountIncludesVAT AS AmountIncludesVAT,
	|	Quote.DocumentCurrency AS DocumentCurrency,
	|	Quote.PreferredVariant AS PreferredVariant
	|INTO Header
	|FROM
	|	Quotes AS Quote
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON Quote.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON Quote.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON Quote.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	QuoteInventory.Ref AS Ref,
	|	QuoteInventory.LineNumber AS LineNumber,
	|	QuoteInventory.Products AS Products,
	|	QuoteInventory.Characteristic AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	QuoteInventory.Quantity AS Quantity,
	|	QuoteInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN QuoteInventory.Quantity = 0
	|			THEN 0
	|		ELSE CASE
	|				WHEN QuoteInventory.DiscountMarkupPercent > 0
	|						OR QuoteInventory.AutomaticDiscountAmount > 0
	|					THEN (QuoteInventory.Price * QuoteInventory.Quantity - QuoteInventory.AutomaticDiscountAmount - QuoteInventory.Price * QuoteInventory.Quantity * QuoteInventory.DiscountMarkupPercent / 100) / QuoteInventory.Quantity
	|				ELSE QuoteInventory.Price
	|			END
	|	END AS Price,
	|	QuoteInventory.Price AS PurePrice,
	|	QuoteInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	QuoteInventory.Total - QuoteInventory.VATAmount AS Amount,
	|	QuoteInventory.VATRate AS VATRate,
	|	QuoteInventory.VATAmount AS VATAmount,
	|	QuoteInventory.Total AS Total,
	|	QuoteInventory.Content AS Content,
	|	QuoteInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	QuoteInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	QuoteInventory.ConnectionKey AS ConnectionKey,
	|	QuoteInventory.Variant AS Variant,
	|	QuoteInventory.BundleProduct AS BundleProduct,
	|	QuoteInventory.BundleCharacteristic AS BundleCharacteristic,
	|	CASE
	|		WHEN QuoteInventory.DiscountMarkupPercent + QuoteInventory.AutomaticDiscountsPercent > 100
	|			THEN 100
	|		ELSE QuoteInventory.DiscountMarkupPercent + QuoteInventory.AutomaticDiscountsPercent
	|	END AS DiscountPercent,
	|	VATRates.Rate AS NumberVATRate,
	|	QuoteInventory.Amount AS PureAmount,
	|	CAST(QuoteInventory.Quantity * QuoteInventory.Price - QuoteInventory.Amount AS NUMBER(15, 2)) AS DiscountAmount
	|INTO FilteredInventory
	|FROM
	|	Document.Quote.Inventory AS QuoteInventory
	|		LEFT JOIN Catalog.VATRates AS VATRates
	|		ON QuoteInventory.VATRate = VATRates.Ref
	|WHERE
	|	QuoteInventory.Ref IN(&ObjectsArray)
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
	|	Header.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Header.BankAccount AS BankAccount,
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.DocumentCurrency AS DocumentCurrency,
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
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN FilteredInventory.PurePrice
	|		ELSE FilteredInventory.Price
	|	END AS Price,
	|	FilteredInventory.DiscountMarkupPercent AS DiscountRate,
	|	SUM(FilteredInventory.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	SUM(CAST(FilteredInventory.PurePrice * CASE
	|				WHEN CatalogProducts.IsFreightService
	|					THEN FilteredInventory.Quantity
	|				ELSE 0
	|			END * CASE
	|				WHEN Header.AmountIncludesVAT
	|					THEN 1 / (1 + FilteredInventory.NumberVATRate / 100)
	|				ELSE 1
	|			END AS NUMBER(15, 2))) AS Freight,
	|	SUM(FilteredInventory.Total) AS Total,
	|	SUM(CASE
	|			WHEN &IsDiscount
	|				THEN CASE
	|						WHEN Header.AmountIncludesVAT
	|							THEN CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|						ELSE CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice AS NUMBER(15, 2))
	|					END
	|			ELSE CASE
	|					WHEN Header.AmountIncludesVAT
	|						THEN CAST((FilteredInventory.Quantity * FilteredInventory.PurePrice - FilteredInventory.DiscountAmount) / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|					ELSE CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice - FilteredInventory.DiscountAmount AS NUMBER(15, 2))
	|				END
	|		END * CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN 0
	|			ELSE 1
	|		END) AS Subtotal,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	FilteredInventory.Variant AS Variant,
	|	CatalogProducts.IsFreightService AS IsFreightService,
	|	FilteredInventory.BundleProduct AS BundleProduct,
	|	FilteredInventory.BundleCharacteristic AS BundleCharacteristic,
	|	FilteredInventory.DiscountPercent AS DiscountPercent,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST(FilteredInventory.DiscountAmount / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|			ELSE FilteredInventory.DiscountAmount
	|		END) AS DiscountAmount,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST((FilteredInventory.PurePrice * FilteredInventory.Quantity - FilteredInventory.DiscountAmount) / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|			ELSE FilteredInventory.PurePrice * FilteredInventory.Quantity - FilteredInventory.DiscountAmount
	|		END) AS NetAmount
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|			AND (Header.PreferredVariant = FilteredInventory.Variant
	|				OR &AllVariants)
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
	|	Header.Ref,
	|	Header.Counterparty,
	|	Header.CompanyLogoFile,
	|	Header.Contract,
	|	Header.CounterpartyContactPerson,
	|	Header.BankAccount,
	|	Header.AmountIncludesVAT,
	|	Header.DocumentCurrency,
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
	|	FilteredInventory.Variant,
	|	CatalogProducts.IsFreightService,
	|	FilteredInventory.BundleProduct,
	|	FilteredInventory.BundleCharacteristic,
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN FilteredInventory.PurePrice
	|		ELSE FilteredInventory.Price
	|	END,
	|	FilteredInventory.DiscountPercent,
	|	FilteredInventory.Price
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
	|	Tabular.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Tabular.BankAccount AS BankAccount,
	|	Tabular.AmountIncludesVAT AS AmountIncludesVAT,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Price AS Price,
	|	Tabular.Amount AS Amount,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	Tabular.Freight AS FreightTotal,
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
	|	VALUE(Catalog.ShippingAddresses.EmptyRef) AS ShippingAddress,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS StructuralUnit,
	|	VALUE(Enum.DeliveryOptions.EmptyRef) AS DeliveryOption,
	|	Tabular.Variant AS Variant,
	|	Tabular.IsFreightService AS IsFreightService,
	|	Tabular.BundleProduct AS BundleProduct,
	|	Tabular.BundleCharacteristic AS BundleCharacteristic,
	|	Tabular.DiscountPercent AS DiscountPercent,
	|	Tabular.NetAmount AS NetAmount
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	Variant,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyVATNumber),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(CounterpartyContactPerson),
	|	MAX(BankAccount),
	|	MAX(AmountIncludesVAT),
	|	MAX(DocumentCurrency),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	SUM(FreightTotal),
	|	SUM(DiscountAmount),
	|	MAX(ShippingAddress),
	|	MAX(StructuralUnit),
	|	MAX(DeliveryOption)
	|BY
	|	Ref,
	|	Variant
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.Variant AS Variant,
	|	Tabular.VATRate AS VATRate,
	|	SUM(Tabular.Amount) AS Amount,
	|	SUM(Tabular.VATAmount) AS VATAmount
	|FROM
	|	Tabular AS Tabular
	|
	|GROUP BY
	|	Tabular.Ref,
	|	Tabular.Variant,
	|	Tabular.VATRate
	|TOTALS BY
	|	Ref,
	|	Variant
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(Tabular.LineNumber) AS LineNumber,
	|	Tabular.Ref AS Ref,
	|	SUM(Tabular.Quantity) AS Quantity,
	|	Tabular.Variant AS Variant
	|FROM
	|	Tabular AS Tabular
	|WHERE
	|	NOT Tabular.IsFreightService
	|
	|GROUP BY
	|	Tabular.Ref,
	|	Tabular.Variant";
	
	Return QueryText;
	
EndFunction

Function GetProformaInvoiceQueryTextForSalesOrder()
	
	QueryText = 
	"SELECT ALLOWED
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Number AS Number,
	|	SalesOrder.Date AS Date,
	|	SalesOrder.Company AS Company,
	|	SalesOrder.CompanyVATNumber AS CompanyVATNumber,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.Contract AS Contract,
	|	SalesOrder.BankAccount AS BankAccount,
	|	SalesOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrder.DocumentCurrency AS DocumentCurrency,
	|	SalesOrder.EstimateIsCalculated AS EstimateIsCalculated,
	|	SalesOrder.ContactPerson AS ContactPerson,
	|	SalesOrder.ShippingAddress AS ShippingAddress,
	|	SalesOrder.StructuralUnitReserve AS StructuralUnit,
	|	SalesOrder.DeliveryOption AS DeliveryOption
	|INTO SalesOrders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Number AS DocumentNumber,
	|	SalesOrder.Date AS DocumentDate,
	|	SalesOrder.Company AS Company,
	|	SalesOrder.CompanyVATNumber AS CompanyVATNumber,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.Contract AS Contract,
	|	CASE
	|		WHEN SalesOrder.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN SalesOrder.ContactPerson
	|		WHEN CounterpartyContracts.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN CounterpartyContracts.ContactPerson
	|		ELSE Counterparties.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	SalesOrder.BankAccount AS BankAccount,
	|	SalesOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrder.DocumentCurrency AS DocumentCurrency,
	|	SalesOrder.ShippingAddress AS ShippingAddress,
	|	SalesOrder.StructuralUnit AS StructuralUnit,
	|	SalesOrder.DeliveryOption AS DeliveryOption
	|INTO Header
	|FROM
	|	SalesOrders AS SalesOrder
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON SalesOrder.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON SalesOrder.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON SalesOrder.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrderInventory.Ref AS Ref,
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.Batch AS Batch,
	|	SalesOrderInventory.Quantity AS Quantity,
	|	SalesOrderInventory.Reserve AS Reserve,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN SalesOrderInventory.Quantity = 0
	|			THEN 0
	|		ELSE CASE
	|				WHEN SalesOrderInventory.DiscountMarkupPercent > 0
	|						OR SalesOrderInventory.AutomaticDiscountAmount > 0
	|					THEN (SalesOrderInventory.Price * SalesOrderInventory.Quantity - SalesOrderInventory.AutomaticDiscountAmount - SalesOrderInventory.Price * SalesOrderInventory.Quantity * SalesOrderInventory.DiscountMarkupPercent / 100) / SalesOrderInventory.Quantity
	|				ELSE SalesOrderInventory.Price
	|			END
	|	END AS Price,
	|	SalesOrderInventory.Price AS PurePrice,
	|	SalesOrderInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SalesOrderInventory.Total - SalesOrderInventory.VATAmount AS Amount,
	|	SalesOrderInventory.VATRate AS VATRate,
	|	SalesOrderInventory.VATAmount AS VATAmount,
	|	SalesOrderInventory.Total AS Total,
	|	SalesOrderInventory.Content AS Content,
	|	SalesOrderInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	SalesOrderInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	SalesOrderInventory.ConnectionKey AS ConnectionKey,
	|	SalesOrderInventory.BundleProduct AS BundleProduct,
	|	SalesOrderInventory.BundleCharacteristic AS BundleCharacteristic,
	|	CASE
	|		WHEN SalesOrderInventory.DiscountMarkupPercent + SalesOrderInventory.AutomaticDiscountsPercent > 100
	|			THEN 100
	|		ELSE SalesOrderInventory.DiscountMarkupPercent + SalesOrderInventory.AutomaticDiscountsPercent
	|	END AS DiscountPercent,
	|	SalesOrderInventory.Amount AS PureAmount,
	|	ISNULL(VATRates.Rate, 0) AS NumberVATRate,
	|	CAST(SalesOrderInventory.Quantity * SalesOrderInventory.Price - SalesOrderInventory.Amount AS NUMBER(15, 2)) AS DiscountAmount
	|INTO FilteredInventory
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|		LEFT JOIN Catalog.VATRates AS VATRates
	|		ON SalesOrderInventory.VATRate = VATRates.Ref
	|WHERE
	|	SalesOrderInventory.Ref IN(&ObjectsArray)
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
	|	Header.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Header.BankAccount AS BankAccount,
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.DocumentCurrency AS DocumentCurrency,
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
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN FilteredInventory.PurePrice
	|		ELSE FilteredInventory.Price
	|	END AS Price,
	|	FilteredInventory.DiscountMarkupPercent AS DiscountRate,
	|	SUM(FilteredInventory.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	SUM(CAST(FilteredInventory.PurePrice * CASE
	|				WHEN CatalogProducts.IsFreightService
	|					THEN FilteredInventory.Quantity
	|				ELSE 0
	|			END * CASE
	|				WHEN Header.AmountIncludesVAT
	|					THEN 1 / (1 + FilteredInventory.NumberVATRate / 100)
	|				ELSE 1
	|			END AS NUMBER(15, 2))) AS Freight,
	|	SUM(FilteredInventory.Total) AS Total,
	|	SUM(CASE
	|			WHEN &IsDiscount
	|				THEN CASE
	|						WHEN Header.AmountIncludesVAT
	|							THEN CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|						ELSE CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice AS NUMBER(15, 2))
	|					END
	|			ELSE CASE
	|					WHEN Header.AmountIncludesVAT
	|						THEN CAST((FilteredInventory.Quantity * FilteredInventory.PurePrice - FilteredInventory.DiscountAmount) / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|					ELSE CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice - FilteredInventory.DiscountAmount AS NUMBER(15, 2))
	|				END
	|		END * CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN 0
	|			ELSE 1
	|		END) AS Subtotal,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.ShippingAddress AS ShippingAddress,
	|	Header.StructuralUnit AS StructuralUnit,
	|	Header.DeliveryOption AS DeliveryOption,
	|	CatalogProducts.IsFreightService AS IsFreightService,
	|	FilteredInventory.BundleProduct AS BundleProduct,
	|	FilteredInventory.BundleCharacteristic AS BundleCharacteristic,
	|	FilteredInventory.DiscountPercent AS DiscountPercent,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST(FilteredInventory.DiscountAmount / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|			ELSE FilteredInventory.DiscountAmount
	|		END) AS DiscountAmount,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST(FilteredInventory.PureAmount / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|			ELSE FilteredInventory.PureAmount
	|		END) AS NetAmount
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
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	Header.Ref,
	|	Header.Counterparty,
	|	Header.CompanyLogoFile,
	|	Header.Contract,
	|	Header.CounterpartyContactPerson,
	|	Header.BankAccount,
	|	Header.AmountIncludesVAT,
	|	Header.DocumentCurrency,
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
	|	Header.ShippingAddress,
	|	Header.StructuralUnit,
	|	Header.DeliveryOption,
	|	CatalogProducts.IsFreightService,
	|	FilteredInventory.BundleProduct,
	|	FilteredInventory.BundleCharacteristic,
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN FilteredInventory.PurePrice
	|		ELSE FilteredInventory.Price
	|	END,
	|	FilteredInventory.DiscountPercent,
	|	FilteredInventory.Price
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
	|	Tabular.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Tabular.BankAccount AS BankAccount,
	|	Tabular.AmountIncludesVAT AS AmountIncludesVAT,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Price AS Price,
	|	Tabular.Amount AS Amount,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	Tabular.Freight AS FreightTotal,
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
	|	Tabular.ShippingAddress AS ShippingAddress,
	|	Tabular.StructuralUnit AS StructuralUnit,
	|	Tabular.DeliveryOption AS DeliveryOption,
	|	0 AS Variant,
	|	Tabular.IsFreightService AS IsFreightService,
	|	Tabular.BundleProduct AS BundleProduct,
	|	Tabular.BundleCharacteristic AS BundleCharacteristic,
	|	Tabular.DiscountPercent AS DiscountPercent,
	|	Tabular.NetAmount AS NetAmount
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyVATNumber),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(CounterpartyContactPerson),
	|	MAX(BankAccount),
	|	MAX(AmountIncludesVAT),
	|	MAX(DocumentCurrency),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	SUM(FreightTotal),
	|	SUM(DiscountAmount),
	|	MAX(ShippingAddress),
	|	MAX(StructuralUnit),
	|	MAX(DeliveryOption)
	|BY
	|	Ref,
	|	Variant
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	0 AS Variant,
	|	Tabular.VATRate AS VATRate,
	|	SUM(Tabular.Amount) AS Amount,
	|	SUM(Tabular.VATAmount) AS VATAmount
	|FROM
	|	Tabular AS Tabular
	|
	|GROUP BY
	|	Tabular.Ref,
	|	Tabular.VATRate
	|TOTALS BY
	|	Ref,
	|	Variant
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(Tabular.LineNumber) AS LineNumber,
	|	Tabular.Ref AS Ref,
	|	SUM(Tabular.Quantity) AS Quantity,
	|	0 AS Variant
	|FROM
	|	Tabular AS Tabular
	|WHERE
	|	NOT Tabular.IsFreightService
	|
	|GROUP BY
	|	Tabular.Ref";
	
	Return QueryText;
	
EndFunction

Function GetQuoteQueryTextForQuote(AllVariants)
	
	QueryText = 
	"SELECT ALLOWED
	|	Quote.Ref AS Ref,
	|	Quote.Number AS Number,
	|	Quote.Date AS Date,
	|	Quote.Company AS Company,
	|	Quote.CompanyVATNumber AS CompanyVATNumber,
	|	Quote.Counterparty AS Counterparty,
	|	Quote.Contract AS Contract,
	|	Quote.BankAccount AS BankAccount,
	|	Quote.AmountIncludesVAT AS AmountIncludesVAT,
	|	Quote.DocumentCurrency AS DocumentCurrency,
	|	Quote.ValidUntil AS ValidUntil,
	|	CASE
	|		WHEN Quote.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN &ReverseChargeAppliesRate
	|		ELSE """"
	|	END AS ReverseChargeApplies,
	|	Quote.PreferredVariant AS PreferredVariant
	|INTO Quotes
	|FROM
	|	Document.Quote AS Quote
	|WHERE
	|	Quote.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Quote.Ref AS Ref,
	|	Quote.Number AS DocumentNumber,
	|	Quote.Date AS DocumentDate,
	|	Quote.Company AS Company,
	|	Quote.CompanyVATNumber AS CompanyVATNumber,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	Quote.Counterparty AS Counterparty,
	|	Quote.Contract AS Contract,
	|	Quote.BankAccount AS BankAccount,
	|	CASE
	|		WHEN CounterpartyContracts.ContactPerson = VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN Counterparties.ContactPerson
	|		ELSE CounterpartyContracts.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	Quote.AmountIncludesVAT AS AmountIncludesVAT,
	|	Quote.DocumentCurrency AS DocumentCurrency,
	|	Quote.ValidUntil AS ValidUntil,
	|	Quote.ReverseChargeApplies AS ReverseChargeApplies,
	|	Quote.PreferredVariant AS PreferredVariant
	|INTO Header
	|FROM
	|	Quotes AS Quote
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON Quote.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON Quote.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON Quote.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	QuoteInventory.Ref AS Ref,
	|	QuoteInventory.LineNumber AS LineNumber,
	|	QuoteInventory.Products AS Products,
	|	QuoteInventory.Characteristic AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	QuoteInventory.Quantity AS Quantity,
	|	QuoteInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN QuoteInventory.Quantity = 0
	|			THEN 0
	|		ELSE CASE
	|				WHEN QuoteInventory.DiscountMarkupPercent > 0
	|						OR QuoteInventory.AutomaticDiscountAmount > 0
	|					THEN (QuoteInventory.Price * QuoteInventory.Quantity - QuoteInventory.AutomaticDiscountAmount - QuoteInventory.Price * QuoteInventory.Quantity * QuoteInventory.DiscountMarkupPercent / 100) / QuoteInventory.Quantity
	|				ELSE QuoteInventory.Price
	|			END
	|	END AS Price,
	|	QuoteInventory.Price AS PurePrice,
	|	QuoteInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	QuoteInventory.Total - QuoteInventory.VATAmount AS Amount,
	|	QuoteInventory.VATRate AS VATRate,
	|	QuoteInventory.VATAmount AS VATAmount,
	|	QuoteInventory.Total AS Total,
	|	QuoteInventory.Content AS Content,
	|	QuoteInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	QuoteInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	QuoteInventory.ConnectionKey AS ConnectionKey,
	|	QuoteInventory.Variant AS Variant,
	|	QuoteInventory.BundleProduct AS BundleProduct,
	|	QuoteInventory.BundleCharacteristic AS BundleCharacteristic,
	|	CASE
	|		WHEN QuoteInventory.DiscountMarkupPercent + QuoteInventory.AutomaticDiscountsPercent > 100
	|			THEN 100
	|		ELSE QuoteInventory.DiscountMarkupPercent + QuoteInventory.AutomaticDiscountsPercent
	|	END AS DiscountPercent,
	|	VATRates.Rate AS NumberVATRate,
	|	QuoteInventory.Amount AS PureAmount,
	|	CAST(QuoteInventory.Quantity * QuoteInventory.Price - QuoteInventory.Amount AS NUMBER(15, 2)) AS DiscountAmount
	|INTO FilteredInventory
	|FROM
	|	Document.Quote.Inventory AS QuoteInventory
	|		LEFT JOIN Catalog.VATRates AS VATRates
	|		ON QuoteInventory.VATRate = VATRates.Ref
	|WHERE
	|	QuoteInventory.Ref IN(&ObjectsArray)
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
	|	Header.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Header.BankAccount AS BankAccount,
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.DocumentCurrency AS DocumentCurrency,
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
	|	SUM(FilteredInventory.Quantity * CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN 0
	|			ELSE 1
	|		END) AS Quantity,
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN FilteredInventory.PurePrice
	|		ELSE FilteredInventory.Price
	|	END AS Price,
	|	SUM(FilteredInventory.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
	|	FilteredInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	SUM(FilteredInventory.Total) AS Total,
	|	SUM(CASE
	|			WHEN &IsDiscount
	|				THEN CASE
	|						WHEN Header.AmountIncludesVAT
	|							THEN CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|						ELSE CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice AS NUMBER(15, 2))
	|					END
	|			ELSE CASE
	|					WHEN Header.AmountIncludesVAT
	|						THEN CAST((FilteredInventory.Quantity * FilteredInventory.PurePrice - FilteredInventory.DiscountAmount) / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|					ELSE CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice - FilteredInventory.DiscountAmount AS NUMBER(15, 2))
	|				END
	|		END * CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN 0
	|			ELSE 1
	|		END) AS Subtotal,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.Batch AS Batch,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	Header.ValidUntil AS ValidUntil,
	|	Header.ReverseChargeApplies AS ReverseChargeApplies,
	|	FilteredInventory.Variant AS Variant,
	|	FilteredInventory.BundleProduct AS BundleProduct,
	|	FilteredInventory.BundleCharacteristic AS BundleCharacteristic,
	|	FilteredInventory.DiscountPercent AS DiscountPercent,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST(FilteredInventory.DiscountAmount / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|			ELSE FilteredInventory.DiscountAmount
	|		END) AS DiscountAmount,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST((FilteredInventory.PurePrice * FilteredInventory.Quantity - FilteredInventory.DiscountAmount) / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|			ELSE FilteredInventory.PurePrice * FilteredInventory.Quantity - FilteredInventory.DiscountAmount
	|		END) AS NetAmount,
	|	SUM(CAST(FilteredInventory.PurePrice * CASE
	|				WHEN CatalogProducts.IsFreightService
	|					THEN FilteredInventory.Quantity
	|				ELSE 0
	|			END * CASE
	|				WHEN Header.AmountIncludesVAT
	|					THEN 1 / (1 + FilteredInventory.NumberVATRate / 100)
	|				ELSE 1
	|			END AS NUMBER(15, 2))) AS Freight,
	|	CatalogProducts.IsFreightService AS IsFreightService
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|			AND (Header.PreferredVariant = FilteredInventory.Variant
	|				OR &AllVariants)
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
	|	Header.Counterparty,
	|	Header.Contract,
	|	CatalogProducts.SKU,
	|	Header.CounterpartyContactPerson,
	|	Header.BankAccount,
	|	Header.AmountIncludesVAT,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """",
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
	|	FilteredInventory.DiscountMarkupPercent,
	|	FilteredInventory.Products,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.Batch,
	|	FilteredInventory.MeasurementUnit,
	|	Header.ValidUntil,
	|	Header.ReverseChargeApplies,
	|	FilteredInventory.Variant,
	|	FilteredInventory.BundleProduct,
	|	FilteredInventory.BundleCharacteristic,
	|	FilteredInventory.DiscountPercent,
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN FilteredInventory.PurePrice
	|		ELSE FilteredInventory.Price
	|	END,
	|	FilteredInventory.Price,
	|	CatalogProducts.IsFreightService
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
	|	Tabular.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Tabular.BankAccount AS BankAccount,
	|	Tabular.AmountIncludesVAT AS AmountIncludesVAT,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Price AS Price,
	|	CASE
	|		WHEN Tabular.AutomaticDiscountAmount = 0
	|			THEN Tabular.DiscountMarkupPercent
	|		WHEN Tabular.Subtotal = 0
	|			THEN 0
	|		ELSE CAST((Tabular.Subtotal - Tabular.Amount) / Tabular.Subtotal * 100 AS NUMBER(15, 2))
	|	END AS DiscountRate,
	|	Tabular.Amount AS Amount,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	Tabular.DiscountAmount AS DiscountAmount,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	Tabular.ValidUntil AS ValidUntil,
	|	Tabular.ReverseChargeApplies AS ReverseChargeApplies,
	|	Tabular.Variant AS Variant,
	|	Tabular.BundleProduct AS BundleProduct,
	|	Tabular.BundleCharacteristic AS BundleCharacteristic,
	|	Tabular.Products AS Products,
	|	Tabular.DiscountPercent AS DiscountPercent,
	|	Tabular.NetAmount AS NetAmount,
	|	Tabular.Freight AS FreightTotal,
	|	Tabular.IsFreightService AS IsFreightService
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	DocumentNumber,
	|	Variant,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyVATNumber),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(CounterpartyContactPerson),
	|	MAX(BankAccount),
	|	MAX(AmountIncludesVAT),
	|	MAX(DocumentCurrency),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	SUM(DiscountAmount),
	|	MAX(ValidUntil),
	|	MAX(ReverseChargeApplies),
	|	SUM(NetAmount),
	|	SUM(FreightTotal)
	|BY
	|	Ref,
	|	Variant";
	
	Return QueryText;
	
EndFunction

Function GetQuoteQueryTextForSalesOrder()
	
	QueryText = 
	"SELECT ALLOWED
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Number AS Number,
	|	SalesOrder.Date AS Date,
	|	SalesOrder.Company AS Company,
	|	SalesOrder.CompanyVATNumber AS CompanyVATNumber,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.Contract AS Contract,
	|	SalesOrder.BankAccount AS BankAccount,
	|	SalesOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrder.DocumentCurrency AS DocumentCurrency,
	|	SalesOrder.ShipmentDate AS ShipmentDate,
	|	CASE
	|		WHEN SalesOrder.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN &ReverseChargeAppliesRate
	|		ELSE """"
	|	END AS ReverseChargeApplies
	|INTO SalesOrders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Number AS DocumentNumber,
	|	SalesOrder.Date AS DocumentDate,
	|	SalesOrder.Company AS Company,
	|	SalesOrder.CompanyVATNumber AS CompanyVATNumber,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.Contract AS Contract,
	|	CASE
	|		WHEN CounterpartyContracts.ContactPerson = VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN Counterparties.ContactPerson
	|		ELSE CounterpartyContracts.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	SalesOrder.BankAccount AS BankAccount,
	|	SalesOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrder.DocumentCurrency AS DocumentCurrency,
	|	SalesOrder.ShipmentDate AS ShipmentDate,
	|	SalesOrder.ReverseChargeApplies AS ReverseChargeApplies
	|INTO Header
	|FROM
	|	SalesOrders AS SalesOrder
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON SalesOrder.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON SalesOrder.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON SalesOrder.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrderInventory.Ref AS Ref,
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.Batch AS Batch,
	|	SalesOrderInventory.Quantity AS Quantity,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN SalesOrderInventory.Quantity = 0
	|			THEN 0
	|		ELSE CASE
	|				WHEN SalesOrderInventory.DiscountMarkupPercent > 0
	|						OR SalesOrderInventory.AutomaticDiscountAmount > 0
	|					THEN (SalesOrderInventory.Price * SalesOrderInventory.Quantity - SalesOrderInventory.AutomaticDiscountAmount - SalesOrderInventory.Price * SalesOrderInventory.Quantity * SalesOrderInventory.DiscountMarkupPercent / 100) / SalesOrderInventory.Quantity
	|				ELSE SalesOrderInventory.Price
	|			END
	|	END AS Price,
	|	SalesOrderInventory.Price AS PurePrice,
	|	SalesOrderInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SalesOrderInventory.Total - SalesOrderInventory.VATAmount AS Amount,
	|	SalesOrderInventory.VATRate AS VATRate,
	|	SalesOrderInventory.VATAmount AS VATAmount,
	|	SalesOrderInventory.Total AS Total,
	|	SalesOrderInventory.Content AS Content,
	|	SalesOrderInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	SalesOrderInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	SalesOrderInventory.ConnectionKey AS ConnectionKey,
	|	SalesOrderInventory.BundleProduct AS BundleProduct,
	|	SalesOrderInventory.BundleCharacteristic AS BundleCharacteristic,
	|	CASE
	|		WHEN SalesOrderInventory.DiscountMarkupPercent + SalesOrderInventory.AutomaticDiscountsPercent > 100
	|			THEN 100
	|		ELSE SalesOrderInventory.DiscountMarkupPercent + SalesOrderInventory.AutomaticDiscountsPercent
	|	END AS DiscountPercent,
	|	SalesOrderInventory.Amount AS PureAmount,
	|	ISNULL(VATRates.Rate, 0) AS NumberVATRate,
	|	CAST(SalesOrderInventory.Quantity * SalesOrderInventory.Price - SalesOrderInventory.Amount AS NUMBER(15, 2)) AS DiscountAmount
	|INTO FilteredInventory
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|		LEFT JOIN Catalog.VATRates AS VATRates
	|		ON SalesOrderInventory.VATRate = VATRates.Ref
	|WHERE
	|	SalesOrderInventory.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Counterparty AS Counterparty,
	|	Header.Contract AS Contract,
	|	Header.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Header.BankAccount AS BankAccount,
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.ShipmentDate AS ShipmentDate,
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
	|	SUM(FilteredInventory.Quantity * CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN 0
	|			ELSE 1
	|		END) AS Quantity,
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN FilteredInventory.PurePrice
	|		ELSE FilteredInventory.Price
	|	END AS Price,
	|	SUM(FilteredInventory.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
	|	FilteredInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	SUM(FilteredInventory.Total) AS Total,
	|	SUM(CASE
	|			WHEN &IsDiscount
	|				THEN CASE
	|						WHEN Header.AmountIncludesVAT
	|							THEN CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|						ELSE CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice AS NUMBER(15, 2))
	|					END
	|			ELSE CASE
	|					WHEN Header.AmountIncludesVAT
	|						THEN CAST((FilteredInventory.Quantity * FilteredInventory.PurePrice - FilteredInventory.DiscountAmount) / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|					ELSE CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice - FilteredInventory.DiscountAmount AS NUMBER(15, 2))
	|				END
	|		END * CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN 0
	|			ELSE 1
	|		END) AS Subtotal,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.Batch AS Batch,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	Header.ReverseChargeApplies AS ReverseChargeApplies,
	|	FilteredInventory.BundleProduct AS BundleProduct,
	|	FilteredInventory.BundleCharacteristic AS BundleCharacteristic,
	|	FilteredInventory.DiscountPercent AS DiscountPercent,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST(FilteredInventory.DiscountAmount / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|			ELSE FilteredInventory.DiscountAmount
	|		END) AS DiscountAmount,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST(FilteredInventory.PureAmount / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|			ELSE FilteredInventory.PureAmount
	|		END) AS NetAmount,
	|	SUM(CAST(FilteredInventory.PurePrice * CASE
	|				WHEN CatalogProducts.IsFreightService
	|					THEN FilteredInventory.Quantity
	|				ELSE 0
	|			END * CASE
	|				WHEN Header.AmountIncludesVAT
	|					THEN 1 / (1 + FilteredInventory.NumberVATRate / 100)
	|				ELSE 1
	|			END AS NUMBER(15, 2))) AS Freight,
	|	CatalogProducts.IsFreightService AS IsFreightService
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
	|	Header.Counterparty,
	|	Header.Contract,
	|	CatalogProducts.SKU,
	|	Header.CounterpartyContactPerson,
	|	Header.BankAccount,
	|	Header.AmountIncludesVAT,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	Header.ShipmentDate,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """",
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
	|	FilteredInventory.DiscountMarkupPercent,
	|	FilteredInventory.Products,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.Batch,
	|	FilteredInventory.MeasurementUnit,
	|	Header.ReverseChargeApplies,
	|	FilteredInventory.BundleProduct,
	|	FilteredInventory.BundleCharacteristic,
	|	FilteredInventory.DiscountPercent,
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN FilteredInventory.PurePrice
	|		ELSE FilteredInventory.Price
	|	END,
	|	CatalogProducts.IsFreightService
	|
	|UNION ALL
	|
	|SELECT
	|	Header.Ref,
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	Header.CompanyLogoFile,
	|	Header.Counterparty,
	|	Header.Contract,
	|	Header.CounterpartyContactPerson,
	|	Header.BankAccount,
	|	Header.AmountIncludesVAT,
	|	Header.DocumentCurrency,
	|	Header.ShipmentDate,
	|	SalesOrderWorks.LineNumber,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN (CAST(SalesOrderWorks.Content AS STRING(1024))) <> """"
	|			THEN CAST(SalesOrderWorks.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	(CAST(SalesOrderWorks.Content AS STRING(1024))) <> """",
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	"""",
	|	CatalogProducts.UseSerialNumbers,
	|	SalesOrderWorks.ConnectionKey,
	|	CatalogUOMClassifier.Description,
	|	CAST(SalesOrderWorks.Quantity * SalesOrderWorks.Factor * SalesOrderWorks.Multiplicity * CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN 0
	|			ELSE 1
	|		END AS NUMBER(15, 3)),
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN SalesOrderWorks.Price
	|		ELSE CASE
	|				WHEN SalesOrderWorks.Quantity = 0
	|					THEN 0
	|				ELSE SalesOrderWorks.Amount / SalesOrderWorks.Quantity
	|			END
	|	END,
	|	SalesOrderWorks.AutomaticDiscountAmount,
	|	SalesOrderWorks.DiscountMarkupPercent,
	|	SalesOrderWorks.Amount,
	|	SalesOrderWorks.VATRate,
	|	SalesOrderWorks.VATAmount,
	|	SalesOrderWorks.Total,
	|	CASE
	|		WHEN &IsDiscount
	|			THEN CASE
	|					WHEN Header.AmountIncludesVAT
	|						THEN CAST(SalesOrderWorks.Quantity * SalesOrderWorks.Price / (1 + ISNULL(VATRates.Rate, 0) / 100) AS NUMBER(15, 2))
	|					ELSE CAST(SalesOrderWorks.Quantity * SalesOrderWorks.Price AS NUMBER(15, 2))
	|				END
	|		ELSE CASE
	|				WHEN Header.AmountIncludesVAT
	|					THEN CAST(SalesOrderWorks.Amount / (1 + ISNULL(VATRates.Rate, 0) / 100) AS NUMBER(15, 2))
	|				ELSE CAST(SalesOrderWorks.Amount AS NUMBER(15, 2))
	|			END
	|	END,
	|	CatalogProducts.Ref,
	|	CatalogCharacteristics.Ref,
	|	VALUE(Catalog.ProductsBatches.EmptyRef),
	|	CatalogUOMClassifier.Ref,
	|	NULL,
	|	NULL,
	|	NULL,
	|	CASE
	|		WHEN SalesOrderWorks.DiscountMarkupPercent + SalesOrderWorks.AutomaticDiscountsPercent > 100
	|			THEN 100
	|		ELSE SalesOrderWorks.DiscountMarkupPercent + SalesOrderWorks.AutomaticDiscountsPercent
	|	END,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN CAST(SalesOrderWorks.Quantity * SalesOrderWorks.Price - SalesOrderWorks.Amount / (1 + ISNULL(VATRates.Rate, 0) / 100) AS NUMBER(15, 2))
	|		ELSE CAST(SalesOrderWorks.Quantity * SalesOrderWorks.Price - SalesOrderWorks.Amount AS NUMBER(15, 2))
	|	END,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN CAST(SalesOrderWorks.Amount / (1 + ISNULL(VATRates.Rate, 0) / 100) AS NUMBER(15, 2))
	|		ELSE SalesOrderWorks.Amount
	|	END,
	|	NULL,
	|	CatalogProducts.IsFreightService
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.SalesOrder.Works AS SalesOrderWorks
	|			LEFT JOIN Catalog.VATRates AS VATRates
	|			ON SalesOrderWorks.VATRate = VATRates.Ref
	|		ON Header.Ref = SalesOrderWorks.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (SalesOrderWorks.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (SalesOrderWorks.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (CatalogProducts.MeasurementUnit = CatalogUOMClassifier.Ref)
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
	|	Tabular.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Tabular.BankAccount AS BankAccount,
	|	Tabular.AmountIncludesVAT AS AmountIncludesVAT,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.ShipmentDate AS ValidUntil,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Price AS Price,
	|	CASE
	|		WHEN Tabular.AutomaticDiscountAmount = 0
	|			THEN Tabular.DiscountMarkupPercent
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
	|	Tabular.ReverseChargeApplies AS ReverseChargeApplies,
	|	0 AS Variant,
	|	Tabular.BundleProduct AS BundleProduct,
	|	Tabular.BundleCharacteristic AS BundleCharacteristic,
	|	Tabular.Products AS Products,
	|	Tabular.DiscountPercent AS DiscountPercent,
	|	Tabular.DiscountAmount AS DiscountAmount,
	|	Tabular.NetAmount AS NetAmount,
	|	Tabular.Freight AS FreightTotal,
	|	Tabular.IsFreightService AS IsFreightService
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
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(CounterpartyContactPerson),
	|	MAX(BankAccount),
	|	MAX(AmountIncludesVAT),
	|	MAX(DocumentCurrency),
	|	MAX(ValidUntil),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	MAX(ReverseChargeApplies),
	|	SUM(DiscountAmount),
	|	SUM(FreightTotal)
	|BY
	|	Ref,
	|	Variant";
	
	Return QueryText;
	
EndFunction

// Document printing procedure.
//
Function PrintQuote(ObjectsArray, PrintObjects, TemplateName, PrintParams) Export
	
	DisplayPrintOption = (PrintParams <> Undefined);
	
	StructureFlags			= DriveServer.GetStructureFlags(DisplayPrintOption, PrintParams);
	StructureSecondFlags	= DriveServer.GetStructureSecondFlags(DisplayPrintOption, PrintParams);
	CounterShift			= DriveServer.GetCounterShift(StructureFlags);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_Quote";
	
	Query = New Query();
	Query.Text = GetQueryText(ObjectsArray, TemplateName);
	
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
	Query.SetParameter("AllVariants", StrFind(TemplateName, "AllVariants") > 0);
	Query.SetParameter("IsPriceBeforeDiscount", StructureSecondFlags.IsPriceBeforeDiscount);
	Query.SetParameter("IsDiscount", StructureFlags.IsDiscount);
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	
	HeaderVariants = ResultArray[4].Select(QueryResultIteration.ByGroups);
	
	// Bundles
	TableColumns = ResultArray[4].Columns;
	// End Bundles
	
	While HeaderVariants.Next() Do
		
		Header = HeaderVariants.Select(QueryResultIteration.ByGroups);
		While Header.Next() Do
			
			If Not FirstDocument Then
				SpreadsheetDocument.PutHorizontalPageBreak();
			EndIf;
			FirstDocument = False;
			
			FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_Quote";
			
			Template = PrintManagement.PrintFormTemplate("DataProcessor.PrintQuote.PF_MXL_Quote", LanguageCode);
			
			#Region PrintQuoteTitleArea
			
			StringNameLineArea = "Title";
			
			TitleArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
			TitleArea.Parameters.Fill(Header);
			
			IsPictureLogo = False;
			
			If ValueIsFilled(Header.CompanyLogoFile) Then
				
				PictureData = AttachedFiles.GetBinaryFileData(Header.CompanyLogoFile);
				If ValueIsFilled(PictureData) Then
					
					TitleArea.Drawings.Logo.Picture = New Picture(PictureData);
					
					IsPictureLogo = True;
					
				EndIf;
				
			Else
				
				TitleArea.Drawings.Delete(TitleArea.Drawings.Logo);
				
			EndIf;
			
			SpreadsheetDocument.Put(TitleArea);
			
			DriveServer.AddPartAdditionalToAreaWithShift(
				Template,
				SpreadsheetDocument,
				CounterShift,
				StringNameLineArea,
				"PartAdditional" + StringNameLineArea);
			
			If IsPictureLogo Then
				DriveServer.MakeShiftPictureWithShift(SpreadsheetDocument.Drawings.Logo, CounterShift - 1);
			EndIf;
			
			#EndRegion
			
			#Region PrintQuoteCompanyInfoArea
			
			StringNameLineArea = "CompanyInfo";
			
			CompanyInfoArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
			
			InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
				Header.Company, Header.DocumentDate, ,Header.BankAccount, Header.CompanyVATNumber, LanguageCode);
			CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
			BarcodesInPrintForms.AddBarcodeToTableDocument(CompanyInfoArea, Header.Ref);
			SpreadsheetDocument.Put(CompanyInfoArea);
			
			DriveServer.AddPartAdditionalToAreaWithShift(
				Template,
				SpreadsheetDocument,
				CounterShift,
				StringNameLineArea,
				"PartAdditional" + StringNameLineArea);
				
			IsPictureBarcode = GetFunctionalOption("UseBarcodesInPrintForms");	
			If IsPictureBarcode Then
				DriveServer.MakeShiftPictureWithShift(SpreadsheetDocument.Drawings.DocumentBarcode, CounterShift - 1);
			EndIf;
			
			#EndRegion
			
			#Region PrintQuoteCounterpartyInfoArea
			
			StringNameLineArea = "CounterpartyInfo";
		
			CounterpartyInfoArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
			CounterpartyInfoArea.Parameters.Fill(Header);
			
			InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(
				Header.Counterparty,
				Header.DocumentDate,
				,
				,
				,
				LanguageCode);
			CounterpartyInfoArea.Parameters.Fill(InfoAboutCounterparty);
			
			CounterpartyInfoArea.Parameters.PaymentTerms = PaymentTermsServer.TitleStagesOfPayment(Header.Ref);
			If ValueIsFilled(CounterpartyInfoArea.Parameters.PaymentTerms) Then
				CounterpartyInfoArea.Parameters.PaymentTermsTitle = PaymentTermsServer.PaymentTermsPrintTitle();
			EndIf;
			
			SpreadsheetDocument.Put(CounterpartyInfoArea);
			
			DriveServer.AddPartAdditionalToAreaWithShift(
				Template,
				SpreadsheetDocument,
				CounterShift,
				StringNameLineArea,
				"PartAdditional" + StringNameLineArea);
			
			#EndRegion
			
			#Region PrintQuoteCommentArea
			
			StringNameLineArea = "Comment";
			
			CommentArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
			
			CommentArea = Template.GetArea("Comment");
			If Common.HasObjectAttribute("TermsAndConditions", Header.Ref.Metadata()) Then
				CommentArea.Parameters.TermsAndConditions = Common.ObjectAttributeValue(Header.Ref, "TermsAndConditions");
			Else
				CommentArea.Parameters.TermsAndConditions = Common.ObjectAttributeValue(Header.Ref, "Comment");
			EndIf;
			
			SpreadsheetDocument.Put(CommentArea);
			
			DriveServer.AddPartAdditionalToAreaWithShift(
				Template,
				SpreadsheetDocument,
				CounterShift,
				StringNameLineArea,
				"PartAdditional" + StringNameLineArea);
		
			#EndRegion
			
			#Region PrintQuoteTotalsAreaPrefill
			
			TotalsAreasArray = New Array;
			TotalsArea = New SpreadsheetDocument;
			
			StringNameLineTotalArea = ?(StructureFlags.IsDiscount, "LineTotal", "LineTotalWithoutDiscount");
			
			StringNameTotalAreaStart		= ?(StructureFlags.IsDiscount, "PartStartLineTotal", "PartStartLineTotalWithoutDiscount");
			StringNameTotalAreaAdditional	= ?(StructureFlags.IsDiscount, "PartAdditional", "PartAdditionalWithoutDiscount");
			StringNameTotalAreaEnd			= ?(StructureFlags.IsDiscount, "PartEndLineTotal", "PartEndLineTotalWithoutDiscount");
			
			LineTotalArea = Template.GetArea(StringNameLineTotalArea + "|" + StringNameTotalAreaStart);
			LineTotalArea.Parameters.Fill(Header);
			
			TotalsArea = New SpreadsheetDocument;
			TotalsArea.Put(LineTotalArea);
			
			DriveServer.AddPartAdditionalToAreaWithShift(
				Template,
				TotalsArea,
				CounterShift + 1,
				StringNameLineTotalArea,
				"PartAdditional" + StringNameLineTotalArea);
			
			LineTotalEndArea = Template.GetArea(StringNameLineTotalArea + "|" + StringNameTotalAreaEnd);
			LineTotalEndArea.Parameters.Fill(Header);
			
			LineTotalEndArea.Parameters.Subtotal = Header.Subtotal;
			
			TotalsArea.Join(LineTotalEndArea);
			
			// Wish area
			
			DocumentWish = New SpreadsheetDocument;
			
			StringNameLineTotalWish = "LineTotalWish";
			StringNameLineTotalWishStart = "PartStart"+StringNameLineTotalWish;
			
			LineTotalWish = Template.GetArea(StringNameLineTotalWish + "|" + StringNameLineTotalWishStart);
			
			DocumentWish.Put(LineTotalWish);
			DriveServer.AddPartAdditionalToAreaWithShift(
				Template,
				DocumentWish,
				CounterShift + 1,
				StringNameLineTotalWish,
				"PartAdditional" + StringNameLineTotalWish);
				
			RangeDocumentWish = DocumentWish.Area(1, 1, 1, DocumentWish.TableWidth);
			RangeDocumentWish.Merge();
			RangeDocumentWish.HorizontalAlign = HorizontalAlign.Center;
			
			TotalsArea.Put(DocumentWish);
			
			TotalsAreasArray.Add(TotalsArea);
			
			#EndRegion
			
			#Region PrintQuoteLinesArea
			
			CounterBundle = DriveServer.GetCounterBundle();
			
			If DisplayPrintOption 
				And PrintParams.CodesPosition <> Enums.CodesPositionInPrintForms.SeparateColumn Then
				
				StringNameLineHeader	= "LineHeaderWithoutCode";
				StringNameLineSection	= "LineSectionWithoutCode";
				
				StringPostfix 			= "LineWithoutCode";
				
			Else
				
				StringNameLineHeader	= "LineHeader";
				StringNameLineSection	= "LineSection";
				
				StringPostfix 			= "Line";
				
			EndIf;
			
			StringNameStartPart		= "PartStart"+StringPostfix;
			StringNamePrice			= ?(StructureSecondFlags.IsPriceBeforeDiscount, "PartPriceBefore", "PartPrice")+StringPostfix;
			StringNameVATPart		= "PartVAT"+StringPostfix;
			StringNameDiscount		= "PartDiscount"+StringPostfix;
			StringNameNetAmount		= "PartNetAmount"+StringPostfix;
			StringNameTotalPart		= "PartTotal"+StringPostfix;
			
			// Start
			
			LineHeaderAreaStart		= Template.GetArea(StringNameLineHeader + "|" + StringNameStartPart);
			LineSectionAreaStart	= Template.GetArea(StringNameLineSection + "|" + StringNameStartPart);
			
			SpreadsheetDocument.Put(LineHeaderAreaStart);
			
			// Price
			
			LineHeaderAreaPrice = Template.GetArea(StringNameLineHeader + "|" + StringNamePrice);
			LineSectionAreaPrice = Template.GetArea(StringNameLineSection + "|" + StringNamePrice);
				
			SpreadsheetDocument.Join(LineHeaderAreaPrice);
			
			// Discount 
			
			If StructureFlags.IsDiscount Then
				
				LineHeaderAreaDiscount = Template.GetArea(StringNameLineHeader + "|" + StringNameDiscount);
				LineSectionAreaDiscount = Template.GetArea(StringNameLineSection + "|" + StringNameDiscount);
				
				SpreadsheetDocument.Join(LineHeaderAreaDiscount);
				
			EndIf;
			
			// Tax
			
			If StructureSecondFlags.IsTax Then
				
				LineHeaderAreaVAT		= Template.GetArea(StringNameLineHeader + "|" + StringNameVATPart);
				LineSectionAreaVAT		= Template.GetArea(StringNameLineSection + "|" + StringNameVATPart);
				
				SpreadsheetDocument.Join(LineHeaderAreaVAT);
				
			EndIf;
			
			// Net amount
			
			If StructureFlags.IsNetAmount Then
				
				LineHeaderAreaNetAmount = Template.GetArea(StringNameLineHeader + "|" + StringNameNetAmount);
				LineSectionAreaNetAmount = Template.GetArea(StringNameLineSection + "|" + StringNameNetAmount);
				
				SpreadsheetDocument.Join(LineHeaderAreaNetAmount);
				
			EndIf;
			
			// Total
			
			If StructureFlags.IsLineTotal Then
				
				LineHeaderAreaTotal		= Template.GetArea(StringNameLineHeader + "|" + StringNameTotalPart);
				LineSectionAreaTotal	= Template.GetArea(StringNameLineSection + "|" + StringNameTotalPart);
				
				SpreadsheetDocument.Join(LineHeaderAreaTotal);
				
			EndIf;
			
			SeeNextPageArea	= DriveServer.GetAreaDocumentFooters(Template, "SeeNextPage", CounterShift);
			EmptyLineArea	= Template.GetArea("EmptyLine");
			PageNumberArea	= DriveServer.GetAreaDocumentFooters(Template, "PageNumber", CounterShift);
			
			PageNumber = 0;
			
			AreasToBeChecked = New Array;
			
			// Bundles
			TableInventoty = BundlesServer.AssemblyTableByBundles(Header.Ref, Header, TableColumns, LineTotalArea);
			EmptyColor = LineSectionAreaStart.CurrentArea.TextColor;
			// End Bundles
			
			PricePrecision = PrecisionAppearancetServer.CompanyPrecision(Header.Company);
			
			For Each TabSelection In TableInventoty Do
				
				If TabSelection.IsFreightService = True Then
					Continue;
				EndIf;
				
				LineSectionAreaStart.Parameters.Fill(TabSelection);
				LineSectionAreaPrice.Parameters.Fill(TabSelection);
				LineSectionAreaPrice.Parameters.Price = Format(TabSelection.Price,
					"NFD= " + PricePrecision);
				
				If StructureFlags.IsDiscount Then
					
					If Not TabSelection.DiscountPercent = Undefined Then
						LineSectionAreaDiscount.Parameters.SignPercent = "%";
					Else
						LineSectionAreaDiscount.Parameters.SignPercent = "";
					EndIf;
					
					LineSectionAreaDiscount.Parameters.Fill(TabSelection);
					
				EndIf;
				
				If StructureSecondFlags.IsTax Then
					LineSectionAreaVAT.Parameters.Fill(TabSelection);
				EndIf;
				
				If StructureFlags.IsNetAmount Then
					LineSectionAreaNetAmount.Parameters.Fill(TabSelection);
				EndIf;
				
				If StructureFlags.IsLineTotal Then
					LineSectionAreaTotal.Parameters.Fill(TabSelection);
				EndIf;
				
				DriveClientServer.ComplimentProductDescription(LineSectionAreaStart.Parameters.ProductDescription, TabSelection);
				
				// Display selected codes if functional option is turned on.
				If DisplayPrintOption Then
					CodesPresentation = PrintManagementServerCallDrive.GetCodesPresentation(PrintParams, TabSelection.Products);
					If PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.SeparateColumn Then
						LineSectionAreaStart.Parameters.SKU = CodesPresentation;
					ElsIf PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.ProductColumn Then
						LineSectionAreaStart.Parameters.ProductDescription = 
							LineSectionAreaStart.Parameters.ProductDescription + Chars.CR + CodesPresentation;
					EndIf;
				EndIf;
				
				// Bundles
				
				BundleColor =  BundlesServer.GetBundleComponentsColor(TabSelection, EmptyColor);
				
				LineSectionAreaStart.Area(1,1,1,CounterBundle).TextColor = BundleColor;
				LineSectionAreaPrice.CurrentArea.TextColor = BundleColor;
				If StructureFlags.IsDiscount Then
					LineSectionAreaDiscount.CurrentArea.TextColor = BundleColor;
				EndIf;
				If StructureSecondFlags.IsTax Then
					LineSectionAreaVAT.Area(1,1,1,2).TextColor = BundleColor;
				EndIf;
				If StructureFlags.IsNetAmount Then
					LineSectionAreaNetAmount.CurrentArea.TextColor = BundleColor;
				EndIf;
				If StructureFlags.IsLineTotal Then
					LineSectionAreaTotal.CurrentArea.TextColor = BundleColor;
				EndIf;
				
				// End Bundles
				
				AreasToBeChecked.Clear();
				AreasToBeChecked.Add(LineSectionAreaStart);
				If TableInventoty.IndexOf(TabSelection) = TableInventoty.Count() - 1 Then
					For Each Area In TotalsAreasArray Do
						AreasToBeChecked.Add(Area);
					EndDo;
				EndIf;
				AreasToBeChecked.Add(PageNumberArea);
				
				If Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
					
					SpreadsheetDocument.Put(LineSectionAreaStart);
					SpreadsheetDocument.Join(LineSectionAreaPrice);
					If StructureFlags.IsDiscount Then
						SpreadsheetDocument.Join(LineSectionAreaDiscount);
					EndIf;
					If StructureSecondFlags.IsTax Then
						SpreadsheetDocument.Join(LineSectionAreaVAT);
					EndIf;
					If StructureFlags.IsNetAmount Then
						SpreadsheetDocument.Join(LineSectionAreaNetAmount);
					EndIf;
					If StructureFlags.IsLineTotal Then
						SpreadsheetDocument.Join(LineSectionAreaTotal);
					EndIf;
					
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
					
					#Region PrintTitleArea
					
					SpreadsheetDocument.Put(TitleArea);
					StringNameLineArea = "Title";
					DriveServer.AddPartAdditionalToAreaWithShift(
						Template,
						SpreadsheetDocument,
						CounterShift,
						StringNameLineArea,
						"PartAdditional" + StringNameLineArea); 
						
					If IsPictureLogo Then
						DriveServer.MakeShiftPictureWithShift(SpreadsheetDocument.Drawings.Logo, CounterShift - 1);
					EndIf;
					
					#EndRegion
					
					// Header
					
					SpreadsheetDocument.Put(LineHeaderAreaStart);
					SpreadsheetDocument.Join(LineHeaderAreaPrice);
					If StructureFlags.IsDiscount Then
						SpreadsheetDocument.Join(LineHeaderAreaDiscount);
					EndIf;
					If StructureSecondFlags.IsTax Then
						SpreadsheetDocument.Join(LineHeaderAreaVAT);
					EndIf;
					If StructureFlags.IsNetAmount Then
						SpreadsheetDocument.Join(LineHeaderAreaNetAmount);
					EndIf;
					If StructureFlags.IsLineTotal Then
						SpreadsheetDocument.Join(LineHeaderAreaTotal);
					EndIf;
					
					// Section
					
					SpreadsheetDocument.Put(LineSectionAreaStart);
					SpreadsheetDocument.Join(LineSectionAreaPrice);
					If StructureFlags.IsDiscount Then
						SpreadsheetDocument.Join(LineSectionAreaDiscount);
					EndIf;
					If StructureSecondFlags.IsTax Then
						SpreadsheetDocument.Join(LineSectionAreaVAT);
					EndIf;
					If StructureFlags.IsNetAmount Then
						SpreadsheetDocument.Join(LineSectionAreaNetAmount);
					EndIf;
					If StructureFlags.IsLineTotal Then
						SpreadsheetDocument.Join(LineSectionAreaTotal);
					EndIf;
					
				EndIf;
				
			EndDo;
			
			#EndRegion
			
			#Region PrintQuoteTotalsArea
			
			For Each Area In TotalsAreasArray Do
				
				SpreadsheetDocument.Put(Area);
				
			EndDo;
			
			#Region PrintAdditionalAttributes
			If DisplayPrintOption 
				And PrintParams.AdditionalAttributes 
				And PrintManagementServerCallDrive.HasAdditionalAttributes(Header.Ref) Then
				
				SpreadsheetDocument.Put(EmptyLineArea);
				
				StringNameLineArea = "AdditionalAttributesStaticHeader";
				
				AddAttribHeader = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
				SpreadsheetDocument.Put(AddAttribHeader);
				
				DriveServer.AddPartAdditionalToAreaWithShift(
					Template,
					SpreadsheetDocument,
					CounterShift,
					StringNameLineArea,
					"PartAdditional" + StringNameLineArea);
				
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
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Document printing procedure
//
Function PrintProformaInvoice(ObjectsArray, PrintObjects, TemplateName, PrintParams) Export
	
	DisplayPrintOption = (PrintParams <> Undefined);
	
	StructureFlags			= DriveServer.GetStructureFlags(DisplayPrintOption, PrintParams);
	StructureSecondFlags	= DriveServer.GetStructureSecondFlags(DisplayPrintOption, PrintParams);
	CounterShift			= DriveServer.GetCounterShift(StructureFlags);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_ProformaInvoice";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	Query.SetParameter("AllVariants", StrFind(TemplateName, "AllVariants") > 0);
	Query.SetParameter("IsPriceBeforeDiscount", StructureSecondFlags.IsPriceBeforeDiscount);
	Query.SetParameter("IsDiscount", StructureFlags.IsDiscount);
	
	Query.Text = GetQueryText(ObjectsArray, TemplateName);
	
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
	
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	
	HeaderVariants			= ResultArray[4].Select(QueryResultIteration.ByGroups);
	TaxesHeaderSelVariants	= ResultArray[5].Select(QueryResultIteration.ByGroups);
	TotalLineNumber			= ResultArray[6].Unload();
	
	// Bundles
	TableColumns = ResultArray[4].Columns;
	// End Bundles
	
	While HeaderVariants.Next() Do
		
		Header = HeaderVariants.Select(QueryResultIteration.ByGroups);
		While Header.Next() Do
			
			If Not FirstDocument Then
				SpreadsheetDocument.PutHorizontalPageBreak();
			EndIf;
			FirstDocument = False;
			
			FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_ProformaInvoice";
			
			Template = PrintManagement.PrintFormTemplate("DataProcessor.PrintQuote.PF_MXL_ProformaInvoice", LanguageCode);
			
			#Region PrintProformaInvoiceTitleArea
			
			StringNameLineArea = "Title";
			TitleArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
			TitleArea.Parameters.Fill(Header);
			
			If DisplayPrintOption Then 
				TitleArea.Parameters.OriginalDuplicate = ?(PrintParams.OriginalCopy,
					NStr("en = 'ORIGINAL'; ru = 'ОРИГИНАЛ';pl = 'ORYGINAŁ';es_ES = 'ORIGINAL';es_CO = 'ORIGINAL';tr = 'ORİJİNAL';it = 'ORIGINALE';de = 'ORIGINAL'", LanguageCode),
					NStr("en = 'COPY'; ru = 'КОПИЯ';pl = 'KOPIA';es_ES = 'COPIA';es_CO = 'COPIA';tr = 'KOPYA';it = 'COPIA';de = 'KOPIE'", LanguageCode));
			EndIf;
			
			SpreadsheetDocument.Put(TitleArea);
			
			DriveServer.AddPartAdditionalToAreaWithShift(
				Template,
				SpreadsheetDocument,
				CounterShift,
				StringNameLineArea,
				"PartAdditional" + StringNameLineArea);
				
			IsPictureLogo = False;
			
			If ValueIsFilled(Header.CompanyLogoFile) Then
				
				PictureData = AttachedFiles.GetBinaryFileData(Header.CompanyLogoFile);
				If ValueIsFilled(PictureData) Then
					
					SpreadsheetDocument.Drawings.Logo.Picture = New Picture(PictureData);
					
					IsPictureLogo = True;
					
				EndIf;
				
			Else
				
				TitleArea.Drawings.Delete(TitleArea.Drawings.Logo);
				
			EndIf;
			
			If IsPictureLogo Then
				DriveServer.MakeShiftPictureWithShift(SpreadsheetDocument.Drawings.Logo, CounterShift - 1);
			EndIf;
			
			#EndRegion
			
			#Region PrintProformaInvoiceCompanyInfoArea
			
			StringNameLineArea = "CompanyInfo";
			CompanyInfoArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
			
			InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
				Header.Company, Header.DocumentDate, , Header.BankAccount, Header.CompanyVATNumber, LanguageCode);
			CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
			BarcodesInPrintForms.AddBarcodeToTableDocument(CompanyInfoArea, Header.Ref);
			SpreadsheetDocument.Put(CompanyInfoArea);
			
			DriveServer.AddPartAdditionalToAreaWithShift(
				Template,
				SpreadsheetDocument,
				CounterShift,
				StringNameLineArea,
				"PartAdditional" + StringNameLineArea);
				
			IsPictureBarcode = GetFunctionalOption("UseBarcodesInPrintForms");
			If IsPictureBarcode Then
				DriveServer.MakeShiftPictureWithShift(SpreadsheetDocument.Drawings.DocumentBarcode, CounterShift - 1);
			EndIf;
			
			#EndRegion
			
			#Region PrintProformaInvoiceCounterpartyInfoArea
			
			StringNameLineArea = "CounterpartyInfo";
			CounterpartyInfoArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
			CounterpartyInfoArea.Parameters.Fill(Header);
			
			InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(
				Header.Counterparty,
				Header.DocumentDate,
				,
				,
				,
				LanguageCode);
			CounterpartyInfoArea.Parameters.Fill(InfoAboutCounterparty);
			
			TitleParameters = New Structure;
			TitleParameters.Insert("TitleShipTo", NStr("en = 'Ship to'; ru = 'Грузополучатель';pl = 'Dostawa do';es_ES = 'Enviar a';es_CO = 'Enviar a';tr = 'Sevk et';it = 'Spedire a';de = 'Versand an'", LanguageCode));
			TitleParameters.Insert("TitleShipDate", NStr("en = 'Ship date'; ru = 'Дата доставки';pl = 'Data wysyłki';es_ES = 'Fecha de envío';es_CO = 'Fecha de envío';tr = 'Gönderme tarihi';it = 'Data di spedizione';de = 'Versanddatum'", LanguageCode));
			
			If Header.DeliveryOption = Enums.DeliveryOptions.SelfPickup Then
				
				InfoAboutPickupLocation	= DriveServer.InfoAboutLegalEntityIndividual(
					Header.StructuralUnit,
					Header.DocumentDate,
					,
					,
					,
					LanguageCode);
				ResponsibleEmployee		= InfoAboutPickupLocation.ResponsibleEmployee;
				
				If NOT IsBlankString(InfoAboutPickupLocation.FullDescr) Then
					CounterpartyInfoArea.Parameters.FullDescrShipTo = InfoAboutPickupLocation.FullDescr;
				EndIf;
				
				If NOT IsBlankString(InfoAboutPickupLocation.DeliveryAddress) Then
					CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutPickupLocation.DeliveryAddress;
				EndIf;
				
				If ValueIsFilled(ResponsibleEmployee) Then
					CounterpartyInfoArea.Parameters.CounterpartyContactPerson = ResponsibleEmployee.Description;
				EndIf;
				
				If NOT IsBlankString(InfoAboutPickupLocation.PhoneNumbers) Then
					CounterpartyInfoArea.Parameters.PhoneNumbers = InfoAboutPickupLocation.PhoneNumbers;
				EndIf;
				
				TitleParameters.TitleShipTo		= NStr("en = 'Pickup location'; ru = 'Место самовывоза';pl = 'Miejsce odbioru osobistego';es_ES = 'Ubicación de recogida';es_CO = 'Ubicación de recogida';tr = 'Toplama yeri';it = 'Punto di presa';de = 'Abholort'", LanguageCode);
				TitleParameters.TitleShipDate	= NStr("en = 'Pickup date'; ru = 'Дата самовывоза';pl = 'Data odbioru osobistego';es_ES = 'Fecha de recogida';es_CO = 'Fecha de recogida';tr = 'Toplama tarihi';it = 'Data di presa';de = 'Abholdatum'", LanguageCode);
				
			Else
				
				InfoAboutShippingAddress	= DriveServer.InfoAboutShippingAddress(Header.ShippingAddress);
				InfoAboutContactPerson		= DriveServer.InfoAboutContactPerson(Header.CounterpartyContactPerson);
			
				If NOT IsBlankString(InfoAboutShippingAddress.DeliveryAddress) Then
					CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutShippingAddress.DeliveryAddress;
				EndIf;
				
				If NOT IsBlankString(InfoAboutContactPerson.PhoneNumbers) Then
					CounterpartyInfoArea.Parameters.PhoneNumbers = InfoAboutContactPerson.PhoneNumbers;
				EndIf;
				
			EndIf;
			
			CounterpartyInfoArea.Parameters.Fill(TitleParameters);
			
			If IsBlankString(CounterpartyInfoArea.Parameters.DeliveryAddress) Then
				
				If Not IsBlankString(InfoAboutCounterparty.ActualAddress) Then
					
					CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutCounterparty.ActualAddress;
					
				Else
					
					CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutCounterparty.LegalAddress;
					
				EndIf;
				
			EndIf;
			
			CounterpartyInfoArea.Parameters.PaymentTerms = PaymentTermsServer.TitleStagesOfPayment(Header.Ref);
			If ValueIsFilled(CounterpartyInfoArea.Parameters.PaymentTerms) Then
				CounterpartyInfoArea.Parameters.PaymentTermsTitle = PaymentTermsServer.PaymentTermsPrintTitle();
			EndIf;
			
			SpreadsheetDocument.Put(CounterpartyInfoArea);
			
			DriveServer.AddPartAdditionalToAreaWithShift(
				Template,
				SpreadsheetDocument,
				CounterShift,
				StringNameLineArea,
				"PartAdditional" + StringNameLineArea);
			
			#EndRegion
			
			#Region PrintProformaInvoiceCommentArea
			
			StringNameLineArea = "Comment";
			CommentArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
			CommentArea.Parameters.Comment = Common.ObjectAttributeValue(Header.Ref, "Comment");
			SpreadsheetDocument.Put(CommentArea);
			
			DriveServer.AddPartAdditionalToAreaWithShift(
				Template,
				SpreadsheetDocument,
				CounterShift,
				StringNameLineArea,
				"PartAdditional" + StringNameLineArea);
				
			#EndRegion
			
			#Region PrintProformaInvoiceTotalsAndTaxesAreaPrefill
			
			TotalsAndTaxesAreasArray = New Array;
			
			TotalsArea = New SpreadsheetDocument;
			
			StringNameLineTotalArea = ?(StructureFlags.IsDiscount, "LineTotal", "LineTotalWithoutDiscount");
			
			StringNameTotalAreaStart		= ?(StructureFlags.IsDiscount, "PartStartLineTotal", "PartStartLineTotalWithoutDiscount");
			StringNameTotalAreaAdditional	= ?(StructureFlags.IsDiscount, "PartAdditional", "PartAdditionalWithoutDiscount");
			StringNameTotalAreaEnd			= ?(StructureFlags.IsDiscount, "PartEndLineTotal", "PartEndLineTotalWithoutDiscount");
			
			LineTotalArea = Template.GetArea(StringNameLineTotalArea + "|" + StringNameTotalAreaStart);
			LineTotalArea.Parameters.Fill(Header);
			
			SearchStructure = New Structure("Ref, Variant", Header.Ref, Header.Variant);
			
			SearchArray = TotalLineNumber.FindRows(SearchStructure);
			If SearchArray.Count() > 0 Then
				LineTotalArea.Parameters.Quantity	= SearchArray[0].Quantity;
				LineTotalArea.Parameters.LineNumber	= SearchArray[0].LineNumber;
			Else
				LineTotalArea.Parameters.Quantity	= 0;
				LineTotalArea.Parameters.LineNumber	= 0;
			EndIf;
			
			TotalsArea.Put(LineTotalArea);
			
			DriveServer.AddPartAdditionalToAreaWithShift(
				Template,
				TotalsArea,
				CounterShift + 1,
				StringNameLineTotalArea,
				"PartAdditional" + StringNameLineTotalArea);
				
			LineTotalEndArea = Template.GetArea(StringNameLineTotalArea + "|" + StringNameTotalAreaEnd);
			LineTotalEndArea.Parameters.Fill(Header);
			
			TotalsArea.Join(LineTotalEndArea);
			
			TotalsAndTaxesAreasArray.Add(TotalsArea);
			
			TaxesHeaderSelVariants.Reset();
			If TaxesHeaderSelVariants.FindNext(New Structure("Ref", Header.Ref)) Then
				
				TaxesHeaderSel = TaxesHeaderSelVariants.Select(QueryResultIteration.ByGroups);
				If TaxesHeaderSel.FindNext(New Structure("Variant", Header.Variant)) Then
					
					TaxSectionHeaderArea = Template.GetArea("TaxSectionHeader");
					TotalsAndTaxesAreasArray.Add(TaxSectionHeaderArea);
					
					TaxesSel = TaxesHeaderSel.Select();
					While TaxesSel.Next() Do
						
						TaxSectionLineArea = Template.GetArea("TaxSectionLine");
						TaxSectionLineArea.Parameters.Fill(TaxesSel);
						TotalsAndTaxesAreasArray.Add(TaxSectionLineArea);
						
					EndDo;
					
				EndIf;
				
			EndIf;
			
			#EndRegion
			
			#Region PrintProformaInvoiceLinesArea
			
			CounterBundle = DriveServer.GetCounterBundle();
			
			If DisplayPrintOption 
				And PrintParams.CodesPosition <> Enums.CodesPositionInPrintForms.SeparateColumn Then
				
				StringNameLineHeader	= "LineHeaderWithoutCode";
				StringNameLineSection	= "LineSectionWithoutCode";
				
				StringPostfix 			= "LineWithoutCode";
				
			Else
				
				StringNameLineHeader	= "LineHeader";
				StringNameLineSection	= "LineSection";
				
				StringPostfix 			= "Line";
				
			EndIf;
			
			StringNameStartPart		= "PartStart"+StringPostfix;
			StringNamePrice			= ?(StructureSecondFlags.IsPriceBeforeDiscount, "PartPriceBefore", "PartPrice")+StringPostfix;
			StringNameVATPart		= "PartVAT"+StringPostfix;
			StringNameDiscount		= "PartDiscount"+StringPostfix;
			StringNameNetAmount		= "PartNetAmount"+StringPostfix;
			StringNameTotalPart		= "PartTotal"+StringPostfix;
			
			// Start
			
			LineHeaderAreaStart		= Template.GetArea(StringNameLineHeader + "|" + StringNameStartPart);
			LineSectionAreaStart	= Template.GetArea(StringNameLineSection + "|" + StringNameStartPart);
			
			SpreadsheetDocument.Put(LineHeaderAreaStart);
			
			// Price
			
			LineHeaderAreaPrice = Template.GetArea(StringNameLineHeader + "|" + StringNamePrice);
			LineSectionAreaPrice = Template.GetArea(StringNameLineSection + "|" + StringNamePrice);
				
			SpreadsheetDocument.Join(LineHeaderAreaPrice);
			
			// Discount 
			
			If StructureFlags.IsDiscount Then
				
				LineHeaderAreaDiscount = Template.GetArea(StringNameLineHeader + "|" + StringNameDiscount);
				LineSectionAreaDiscount = Template.GetArea(StringNameLineSection + "|" + StringNameDiscount);
				
				SpreadsheetDocument.Join(LineHeaderAreaDiscount);
				
			EndIf;
			
			// Tax
			
			If StructureSecondFlags.IsTax Then
				
				LineHeaderAreaVAT		= Template.GetArea(StringNameLineHeader + "|" + StringNameVATPart);
				LineSectionAreaVAT		= Template.GetArea(StringNameLineSection + "|" + StringNameVATPart);
				
				SpreadsheetDocument.Join(LineHeaderAreaVAT);
				
			EndIf;
			
			// Net amount
			
			If StructureFlags.IsNetAmount Then
				
				LineHeaderAreaNetAmount = Template.GetArea(StringNameLineHeader + "|" + StringNameNetAmount);
				LineSectionAreaNetAmount = Template.GetArea(StringNameLineSection + "|" + StringNameNetAmount);
				
				SpreadsheetDocument.Join(LineHeaderAreaNetAmount);
				
			EndIf;
			
			// Total
			
			If StructureFlags.IsLineTotal Then
				
				LineHeaderAreaTotal		= Template.GetArea(StringNameLineHeader + "|" + StringNameTotalPart);
				LineSectionAreaTotal	= Template.GetArea(StringNameLineSection + "|" + StringNameTotalPart);
				
				SpreadsheetDocument.Join(LineHeaderAreaTotal);
				
			EndIf;
			
			SeeNextPageArea	= DriveServer.GetAreaDocumentFooters(Template, "SeeNextPage", CounterShift);
			EmptyLineArea	= Template.GetArea("EmptyLine");
			PageNumberArea	= DriveServer.GetAreaDocumentFooters(Template, "PageNumber", CounterShift);
			
			PageNumber = 0;
			
			AreasToBeChecked = New Array;
			
			// Bundles
			TableInventoty = BundlesServer.AssemblyTableByBundles(Header.Ref, Header, TableColumns, LineTotalArea);
			EmptyColor = LineSectionAreaStart.CurrentArea.TextColor;
			// End Bundles
			
			PricePrecision = PrecisionAppearancetServer.CompanyPrecision(Header.Company);
			
			For Each TabSelection In TableInventoty Do
				
				If TabSelection.IsFreightService = True Then
					Continue;
				EndIf;
				
				LineSectionAreaStart.Parameters.Fill(TabSelection);
				LineSectionAreaPrice.Parameters.Fill(TabSelection);
				LineSectionAreaPrice.Parameters.Price = Format(TabSelection.Price,
					"NFD= " + PricePrecision);
				
				If StructureFlags.IsDiscount Then
					
					If Not TabSelection.DiscountPercent = Undefined Then
						LineSectionAreaDiscount.Parameters.SignPercent = "%";
					Else
						LineSectionAreaDiscount.Parameters.SignPercent = "";
					EndIf;
					
					LineSectionAreaDiscount.Parameters.Fill(TabSelection);
					
				EndIf;
				
				If StructureSecondFlags.IsTax Then
					LineSectionAreaVAT.Parameters.Fill(TabSelection);
				EndIf;
				
				If StructureFlags.IsNetAmount Then
					LineSectionAreaNetAmount.Parameters.Fill(TabSelection);
				EndIf;
				
				If StructureFlags.IsLineTotal Then
					LineSectionAreaTotal.Parameters.Fill(TabSelection);
				EndIf;
				
				DriveClientServer.ComplimentProductDescription(LineSectionAreaStart.Parameters.ProductDescription, TabSelection);
				
				// Display selected codes if functional option is turned on.
				If DisplayPrintOption Then
					CodesPresentation = PrintManagementServerCallDrive.GetCodesPresentation(PrintParams, TabSelection.Products);
					If PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.SeparateColumn Then
						LineSectionAreaStart.Parameters.SKU = CodesPresentation;
					ElsIf PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.ProductColumn Then
						LineSectionAreaStart.Parameters.ProductDescription = 
							LineSectionAreaStart.Parameters.ProductDescription + Chars.CR + CodesPresentation;
					EndIf;
				EndIf;
				
				// Bundles
				
				BundleColor =  BundlesServer.GetBundleComponentsColor(TabSelection, EmptyColor);
				
				LineSectionAreaStart.Area(1,1,1,CounterBundle).TextColor = BundleColor;
				LineSectionAreaPrice.CurrentArea.TextColor = BundleColor;
				If StructureFlags.IsDiscount Then
					LineSectionAreaDiscount.CurrentArea.TextColor = BundleColor;
				EndIf;
				If StructureSecondFlags.IsTax Then
					LineSectionAreaVAT.Area(1,1,1,2).TextColor = BundleColor;
				EndIf;
				If StructureFlags.IsNetAmount Then
					LineSectionAreaNetAmount.CurrentArea.TextColor = BundleColor;
				EndIf;
				If StructureFlags.IsLineTotal Then
					LineSectionAreaTotal.CurrentArea.TextColor = BundleColor;
				EndIf;
				
				// End Bundles
				
				AreasToBeChecked.Clear();
				AreasToBeChecked.Add(LineSectionAreaStart);
				If TableInventoty.IndexOf(TabSelection) = TableInventoty.Count() - 1 Then
					For Each Area In TotalsAndTaxesAreasArray Do
						AreasToBeChecked.Add(Area);
					EndDo;
				EndIf;
				AreasToBeChecked.Add(PageNumberArea);
				
				If Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
					
					SpreadsheetDocument.Put(LineSectionAreaStart);
					SpreadsheetDocument.Join(LineSectionAreaPrice);
					If StructureFlags.IsDiscount Then
						SpreadsheetDocument.Join(LineSectionAreaDiscount);
					EndIf;
					If StructureSecondFlags.IsTax Then
						SpreadsheetDocument.Join(LineSectionAreaVAT);
					EndIf;
					If StructureFlags.IsNetAmount Then
						SpreadsheetDocument.Join(LineSectionAreaNetAmount);
					EndIf;
					If StructureFlags.IsLineTotal Then
						SpreadsheetDocument.Join(LineSectionAreaTotal);
					EndIf;
					
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
					
					#Region PrintTitleArea
					
					SpreadsheetDocument.Put(TitleArea);
					StringNameLineArea = "Title";
					DriveServer.AddPartAdditionalToAreaWithShift(
						Template,
						SpreadsheetDocument,
						CounterShift,
						StringNameLineArea,
						"PartAdditional" + StringNameLineArea); 
						
					If IsPictureLogo Then
						DriveServer.MakeShiftPictureWithShift(SpreadsheetDocument.Drawings.Logo, CounterShift - 1);
					EndIf;
					
					#EndRegion
				
					
					// Header
					
					SpreadsheetDocument.Put(LineHeaderAreaStart);
					SpreadsheetDocument.Join(LineHeaderAreaPrice);
					If StructureFlags.IsDiscount Then
						SpreadsheetDocument.Join(LineHeaderAreaDiscount);
					EndIf;
					If StructureSecondFlags.IsTax Then
						SpreadsheetDocument.Join(LineHeaderAreaVAT);
					EndIf;
					If StructureFlags.IsNetAmount Then
						SpreadsheetDocument.Join(LineHeaderAreaNetAmount);
					EndIf;
					If StructureFlags.IsLineTotal Then
						SpreadsheetDocument.Join(LineHeaderAreaTotal);
					EndIf;
					
					// Section
					
					SpreadsheetDocument.Put(LineSectionAreaStart);
					SpreadsheetDocument.Join(LineSectionAreaPrice);
					If StructureFlags.IsDiscount Then
						SpreadsheetDocument.Join(LineSectionAreaDiscount);
					EndIf;
					If StructureSecondFlags.IsTax Then
						SpreadsheetDocument.Join(LineSectionAreaVAT);
					EndIf;
					If StructureFlags.IsNetAmount Then
						SpreadsheetDocument.Join(LineSectionAreaNetAmount);
					EndIf;
					If StructureFlags.IsLineTotal Then
						SpreadsheetDocument.Join(LineSectionAreaTotal);
					EndIf;
					
				EndIf;
				
			EndDo;
			
			#EndRegion
			
			#Region PrintProformaInvoiceTotalsAndTaxesArea
			
			For Each Area In TotalsAndTaxesAreasArray Do
				
				SpreadsheetDocument.Put(Area);
				
			EndDo;
			
			#Region PrintAdditionalAttributes
			If DisplayPrintOption And PrintParams.AdditionalAttributes And PrintManagementServerCallDrive.HasAdditionalAttributes(Header.Ref) Then
				
				SpreadsheetDocument.Put(EmptyLineArea);
				
				StringNameLineArea = "AdditionalAttributesStaticHeader";
				
				AddAttribHeader = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
				SpreadsheetDocument.Put(AddAttribHeader);
				
				DriveServer.AddPartAdditionalToAreaWithShift(
					Template,
					SpreadsheetDocument,
					CounterShift,
					StringNameLineArea,
					"PartAdditional" + StringNameLineArea);
				
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
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;

EndFunction

#EndRegion

#EndIf