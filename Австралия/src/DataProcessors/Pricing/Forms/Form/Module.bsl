
#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillPricesFirstTime(Period, ParameterPriceKind, ParameterPriceGroup, ParameterProducts)
	
	If ValueIsFilled(ParameterPriceKind) Then
	
		Query = New Query();
		Query.Text = 
		"SELECT ALLOWED
		|	PricesSliceLast.Products AS Products,
		|	PricesSliceLast.Characteristic AS Characteristic,
		|	PricesSliceLast.Price AS OriginalPrice,
		|	PricesSliceLast.Price AS Price,
		|	PricesSliceLast.MeasurementUnit AS MeasurementUnit,
		|	TRUE AS Check
		|FROM
		|	InformationRegister.Prices.SliceLast(
		|			&Period,
		|			PriceKind = &PriceKind
		|				AND CASE
		|					WHEN &Products = UNDEFINED
		|							OR Products = &Products
		|						THEN TRUE
		|					ELSE FALSE
		|				END
		|				AND CASE
		|					WHEN &PriceGroup = UNDEFINED
		|							OR Products.PriceGroup = &PriceGroup
		|						THEN TRUE
		|					ELSE FALSE
		|				END) AS PricesSliceLast
		|
		|ORDER BY
		|	PricesSliceLast.Products.Description";
			
		Query.SetParameter("Period", Period);
		Query.SetParameter("PriceKind", ParameterPriceKind);
		Query.SetParameter("Products", ParameterProducts);
		Query.SetParameter("PriceGroup", ParameterPriceGroup);
		Prices.Load(Query.Execute().Unload());	
	
	Else
	
		If ValueIsFilled(ParameterProducts) OR ValueIsFilled(ParameterPriceGroup) Then
		
			Query = New Query();
			Query.Text = 
			"SELECT
			|	CatalogProducts.Ref AS Products,
			|	TRUE AS Check,
			|	CatalogProducts.MeasurementUnit
			|FROM
			|	Catalog.Products AS CatalogProducts
			|WHERE
			|	CASE
			|			WHEN &PriceGroup = UNDEFINED
			|					OR CatalogProducts.PriceGroup = &PriceGroup
			|				THEN TRUE
			|			ELSE FALSE
			|		END
			|	AND CASE
			|			WHEN &Products = UNDEFINED
			|					OR CatalogProducts.Ref = &Products
			|				THEN TRUE
			|			ELSE FALSE
			|		END
			|
			|ORDER BY
			|	CatalogProducts.Description";
				
			Query.SetParameter("Products", ParameterProducts);
			Query.SetParameter("PriceGroup", ParameterPriceGroup);
			Prices.Load(Query.Execute().Unload());		
		
		EndIf; 	
	
	EndIf;		
	
EndProcedure

&AtServer
Function GetProductsTable(Briefly = False)
	
	ProductsTable = New ValueTable;
	
	Array = New Array;
	
	Array.Add(Type("CatalogRef.Products"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	ProductsTable.Columns.Add("Products", TypeDescription);
	
	Array.Add(Type("CatalogRef.ProductsCharacteristics"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	ProductsTable.Columns.Add("Characteristic", TypeDescription);
	
	If Not Briefly Then
	
		Array.Add(Type("Boolean"));
		TypeDescription = New TypeDescription(Array, ,);
		Array.Clear();

		ProductsTable.Columns.Add("Check", TypeDescription);
		
		Array.Add(Type("CatalogRef.UOM"));
		Array.Add(Type("CatalogRef.UOMClassifier"));
		TypeDescription = New TypeDescription(Array, ,);
		Array.Clear();

		ProductsTable.Columns.Add("MeasurementUnit", TypeDescription);
		
		NQ = New NumberQualifiers(15,2);
		Array.Add(Type("Number"));
		TypeDescription = New TypeDescription(Array, , , NQ);

		ProductsTable.Columns.Add("Price", TypeDescription);
		
		Array.Add(Type("Number"));
		TypeDescription = New TypeDescription(Array, , );

		ProductsTable.Columns.Add("Factor", TypeDescription);	
	
	EndIf; 
	
	For Each TSRow In Prices Do
		
		If Not ValueIsFilled(TSRow.Products) Then
			
			Continue;
			
		EndIf; 
		
		NewRow = ProductsTable.Add();
		FillPropertyValues(NewRow, TSRow);
		
		If Not Briefly Then
			
			If TypeOf(TSRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
				NewRow.Factor = 1;
			Else
				NewRow.Factor = TSRow.MeasurementUnit.Factor;
			EndIf;
			
		EndIf; 
		
	EndDo;
	
	Return ProductsTable;

EndFunction

&AtServer
Procedure AddProducts(ProductsTable)
	
	For Each TableRow In ProductsTable Do
		
		NewRow = Prices.Add();
		FillPropertyValues(NewRow, TableRow);
		NewRow.OriginalPrice = TableRow.Price;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure AddByPriceTypesAtServer(ValueSelected, ToDate, PriceFilled, UseCharacteristics = False)
	
	DynamicPriceKind	= ValueSelected.CalculatesDynamically;
	ParameterPriceKind		= ?(DynamicPriceKind, ValueSelected.PricesBaseKind, ValueSelected);
	
	Query = New Query();
	
	Query.Text = DataProcessors.Pricing.QueryTextForAddingByPriceKind(PriceFilled, UseCharacteristics);
	
	CurrencySource = ?(ValueIsFilled(ParameterPriceKind.PriceCurrency), ValueSelected.PriceCurrency, FunctionalCurrency);
	CurrencyOfReceiver = ?(ValueIsFilled(PriceKindInstallation.PriceCurrency), PriceKindInstallation.PriceCurrency, FunctionalCurrency);
	
	Query.SetParameter("ToDate", ToDate);
	Query.SetParameter("PriceKind", ParameterPriceKind);
	Query.SetParameter("CurrencySource",CurrencySource);
	Query.SetParameter("CurrencyOfReceiver",CurrencyOfReceiver);
	Query.SetParameter("ProductsTable", GetProductsTable(True));
	Query.SetParameter("Company", Company);
	
	ResultTable = Query.Execute().Unload();
	
	If DynamicPriceKind AND ResultTable.Count() > 0 Then
		
		Markup = ValueSelected.Percent;
		
		For Each TableRow In ResultTable Do
			
			TableRow.Price = TableRow.Price * (1 + Markup / 100);
			
		EndDo; 
	
	EndIf; 
	
	AddProducts(ResultTable);
	
EndProcedure

&AtServer
Procedure AddByPriceGroupsAtServer(ValueSelected, UseCharacteristics = False)
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	TRUE AS IsInTable
	|INTO ProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable
	|
	|INDEX BY
	|	ProductsTable.Products,
	|	ProductsTable.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CatalogProducts.Ref AS Products,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	FALSE AS IsInTable
	|INTO NewProducts
	|FROM
	|	Catalog.Products AS CatalogProducts
	|WHERE
	|	CatalogProducts.PriceGroup IN(&PriceGroups)
	|
	|INDEX BY
	|	CatalogProducts.Ref,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsCharacteristics.Owner AS Products,
	|	ProductsCharacteristics.Ref AS Characteristic,
	|	ProductsCharacteristics.Owner.MeasurementUnit AS MeasurementUnit,
	|	FALSE AS IsInTable
	|INTO NewCharacteristics
	|FROM
	|	Catalog.ProductsCharacteristics AS ProductsCharacteristics
	|WHERE
	|	ProductsCharacteristics.Owner.PriceGroup IN(&PriceGroups)
	|	AND &UseCharacteristics
	|
	|INDEX BY
	|	ProductsCharacteristics.Owner,
	|	ProductsCharacteristics.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsTable.Products,
	|	ProductsTable.Characteristic,
	|	ProductsTable.MeasurementUnit,
	|	ProductsTable.IsInTable
	|INTO TemporaryTableOfAllProducts
	|FROM
	|	ProductsTable AS ProductsTable
	|
	|UNION ALL
	|
	|SELECT
	|	NewProducts.Products,
	|	NewProducts.Characteristic,
	|	NewProducts.MeasurementUnit,
	|	NewProducts.IsInTable
	|FROM
	|	NewProducts AS NewProducts
	|
	|UNION ALL
	|
	|SELECT
	|	NewCharacteristics.Products,
	|	NewCharacteristics.Characteristic,
	|	NewCharacteristics.MeasurementUnit,
	|	NewCharacteristics.IsInTable
	|FROM
	|	NewCharacteristics AS NewCharacteristics
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TRUE AS Check,
	|	ProductsTableWithPrices.Products,
	|	ProductsTableWithPrices.Characteristic,
	|	ProductsTableWithPrices.MeasurementUnit,
	|	Prices.Price AS Price,
	|	MAX(ProductsTableWithPrices.IsInTable) AS IsInTable
	|FROM
	|	TemporaryTableOfAllProducts AS ProductsTableWithPrices
	|		LEFT JOIN InformationRegister.Prices.SliceLast(
	|				&Period,
	|				PriceKind = &PriceKind) AS Prices
	|		ON ProductsTableWithPrices.Products = Prices.Products
	|			AND ProductsTableWithPrices.Characteristic = Prices.Characteristic
	|
	|GROUP BY
	|	ProductsTableWithPrices.Products,
	|	ProductsTableWithPrices.Characteristic,
	|	ProductsTableWithPrices.MeasurementUnit,
	|	Prices.Price
	|
	|HAVING
	|	MAX(ProductsTableWithPrices.IsInTable) = FALSE
	|
	|ORDER BY
	|	ProductsTableWithPrices.Products.Description,
	|	ProductsTableWithPrices.Characteristic.Description";
	
	Query.SetParameter("Period",					InstallationPeriod);
	Query.SetParameter("PriceKind",					PriceKindInstallation);
	Query.SetParameter("PriceGroups",			ValueSelected);
	Query.SetParameter("ProductsTable",	GetProductsTable(False));
	Query.SetParameter("UseCharacteristics", UseCharacteristics);
	
	AddProducts(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure AddByProductsCategoriesAtServer(ValueSelected, UseCharacteristics = False)
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	TRUE AS IsInTable
	|INTO ProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable
	|
	|INDEX BY
	|	ProductsTable.Products,
	|	ProductsTable.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CatalogProducts.Ref AS Products,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	FALSE AS IsInTable
	|INTO NewProducts
	|FROM
	|	Catalog.Products AS CatalogProducts
	|WHERE
	|	CatalogProducts.Ref IN HIERARCHY(&ProductsGroup)
	|	AND Not CatalogProducts.IsFolder
	|
	|INDEX BY
	|	CatalogProducts.Ref,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsCharacteristics.Owner AS Products,
	|	ProductsCharacteristics.Ref AS Characteristic,
	|	ProductsCharacteristics.Owner.MeasurementUnit AS MeasurementUnit,
	|	FALSE AS IsInTable
	|INTO NewCharacteristics
	|FROM
	|	Catalog.ProductsCharacteristics AS ProductsCharacteristics
	|WHERE
	|	ProductsCharacteristics.Owner IN HIERARCHY(&ProductsGroup)
	|	AND &UseCharacteristics
	|
	|INDEX BY
	|	ProductsCharacteristics.Owner,
	|	ProductsCharacteristics.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsTable.Products,
	|	ProductsTable.Characteristic,
	|	ProductsTable.MeasurementUnit,
	|	ProductsTable.IsInTable
	|INTO TemporaryTableOfAllProducts
	|FROM
	|	ProductsTable AS ProductsTable
	|
	|UNION ALL
	|
	|SELECT
	|	NewProducts.Products,
	|	NewProducts.Characteristic,
	|	NewProducts.MeasurementUnit,
	|	NewProducts.IsInTable
	|FROM
	|	NewProducts AS NewProducts
	|
	|UNION ALL
	|
	|SELECT
	|	NewCharacteristics.Products,
	|	NewCharacteristics.Characteristic,
	|	NewCharacteristics.MeasurementUnit,
	|	NewCharacteristics.IsInTable
	|FROM
	|	NewCharacteristics AS NewCharacteristics
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TRUE AS Check,
	|	ProductsTableWithPrices.Products,
	|	ProductsTableWithPrices.Characteristic,
	|	ProductsTableWithPrices.MeasurementUnit,
	|	Prices.Price AS Price,
	|	MAX(ProductsTableWithPrices.IsInTable) AS IsInTable
	|FROM
	|	TemporaryTableOfAllProducts AS ProductsTableWithPrices
	|		LEFT JOIN InformationRegister.Prices.SliceLast(
	|				&Period,
	|				PriceKind = &PriceKind) AS Prices
	|		ON ProductsTableWithPrices.Products = Prices.Products
	|			AND ProductsTableWithPrices.Characteristic = Prices.Characteristic
	|
	|GROUP BY
	|	ProductsTableWithPrices.Products,
	|	ProductsTableWithPrices.Characteristic,
	|	ProductsTableWithPrices.MeasurementUnit,
	|	Prices.Price
	|
	|HAVING
	|	MAX(ProductsTableWithPrices.IsInTable) = FALSE
	|
	|ORDER BY
	|	ProductsTableWithPrices.Products.Description,
	|	ProductsTableWithPrices.Characteristic.Description";
	
	Query.SetParameter("Period",					InstallationPeriod);
	Query.SetParameter("PriceKind",					PriceKindInstallation);
	Query.SetParameter("ProductsGroup",		ValueSelected);
	Query.SetParameter("ProductsTable",	GetProductsTable(False));
	Query.SetParameter("UseCharacteristics", UseCharacteristics);
	
	AddProducts(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure AddByReceiptInvoiceAtServer(ValueSelected)
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic
	|INTO ProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	MAX(ExchangeRate.Period) AS Period,
	|	ExchangeRate.Company AS Company,
	|	ExchangeRate.Rate AS ExchangeRate,
	|	ExchangeRate.Repetition AS Multiplicity
	|INTO PriceKindCurrencyRate
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(&Period, Currency = &CurrencyPriceKind) AS ExchangeRate
	|
	|GROUP BY
	|	ExchangeRate.Rate,
	|	ExchangeRate.Repetition,
	|	ExchangeRate.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TRUE AS Check,
	|	SupplierInvoiceInventory.Products AS Products,
	|	SupplierInvoiceInventory.Characteristic AS Characteristic,
	|	SupplierInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN &CurrencyPriceKind <> SupplierInvoice.DocumentCurrency
	|			THEN SupplierInvoiceInventory.Price * CASE
	|					WHEN Companies.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN PriceKindCurrencyRate.ExchangeRate * SupplierInvoice.Multiplicity / (SupplierInvoice.ExchangeRate * PriceKindCurrencyRate.Multiplicity)
	|					WHEN Companies.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SupplierInvoice.ExchangeRate * PriceKindCurrencyRate.Multiplicity / (PriceKindCurrencyRate.ExchangeRate * SupplierInvoice.Multiplicity)
	|				END
	|		ELSE SupplierInvoiceInventory.Price
	|	END AS Price
	|FROM
	|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON SupplierInvoiceInventory.Ref = SupplierInvoice.Ref
	|		INNER JOIN Catalog.Companies AS Companies
	|		ON (SupplierInvoice.Company = Companies.Ref)
	|		LEFT JOIN PriceKindCurrencyRate AS PriceKindCurrencyRate
	|		ON SupplierInvoiceInventory.Ref.Company = PriceKindCurrencyRate.Company
	|WHERE
	|	SupplierInvoiceInventory.Ref = &SupplierInvoice
	|	AND NOT (SupplierInvoiceInventory.Products, SupplierInvoiceInventory.Characteristic) IN
	|				(SELECT
	|					Table.Products,
	|					Table.Characteristic
	|				FROM
	|					ProductsTable AS Table)
	|
	|ORDER BY
	|	SupplierInvoiceInventory.LineNumber";
	
	CurrencyPriceKind = ?(ValueIsFilled(PriceKindInstallation.PriceCurrency), PriceKindInstallation.PriceCurrency, FunctionalCurrency);
	
	Query.SetParameter("CurrencyPriceKind", CurrencyPriceKind);
	Query.SetParameter("Period", ValueSelected.Date);
	Query.SetParameter("SupplierInvoice", ValueSelected);
	Query.SetParameter("ProductsTable", GetProductsTable(True));
	
	AddProducts(Query.Execute().Unload());
	
EndProcedure

#Region FillingPrices

&AtServer
Procedure PlacePrices(PricesTable)

	For Each TabularSectionRow In Prices Do
		
		If Not TabularSectionRow.Check Then
			Continue;		
		EndIf; 
		
		SearchStructure = New Structure;
		SearchStructure.Insert("Products",	 TabularSectionRow.Products);
		SearchStructure.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		
		SearchResult = PricesTable.FindRows(SearchStructure);
		If SearchResult.Count() > 0 Then			
			TabularSectionRow.Price = SearchResult[0].Price;
		EndIf;
		
	EndDo;	

EndProcedure

&AtServer
Procedure FillPricesByPriceKindAtServer()
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsTable.Factor AS Factor,
	|	ProductsTable.Check AS Check
	|INTO ProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable
	|WHERE
	|	ProductsTable.Check
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ISNULL(PricesSliceLast.Price * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN CurrencyRateOfPriceKindInstallation.Rate * RateCurrencyTypePrices.Repetition / (RateCurrencyTypePrices.Rate * CurrencyRateOfPriceKindInstallation.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN RateCurrencyTypePrices.Rate * CurrencyRateOfPriceKindInstallation.Repetition / (CurrencyRateOfPriceKindInstallation.Rate * RateCurrencyTypePrices.Repetition)
	|		END * ISNULL(ProductsTable.Factor, 1) / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Price,
	|	ProductsTable.MeasurementUnit
	|FROM
	|	ProductsTable AS ProductsTable
	|		LEFT JOIN InformationRegister.Prices.SliceLast(
	|				&ToDate,
	|				PriceKind = &PriceKind
	|					AND (Products, Characteristic) In
	|						(SELECT
	|							Table.Products,
	|							Table.Characteristic
	|						FROM
	|							ProductsTable AS Table)) AS PricesSliceLast
	|		ON ProductsTable.Products = PricesSliceLast.Products
	|			AND ProductsTable.Characteristic = PricesSliceLast.Characteristic
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&ToDate, Company = &Company) AS RateCurrencyTypePrices
	|		ON (PricesSliceLast.PriceKind.PriceCurrency = RateCurrencyTypePrices.Currency),
	|	InformationRegister.ExchangeRate.SliceLast(&ToDate, Currency = &Currency AND Company = &Company) AS CurrencyRateOfPriceKindInstallation";
		
	Query.SetParameter("ToDate", 				Period);
	Query.SetParameter("PriceKind", 			PriceKind);
	Query.SetParameter("Currency", 				PriceKindInstallation.PriceCurrency);
	Query.SetParameter("ProductsTable", 		GetProductsTable());
	Query.SetParameter("Company", 				Company);
	Query.SetParameter("ExchangeRateMethod",	DriveServer.GetExchangeMethod(Company));
	PlacePrices(Query.Execute().Unload());	
	
EndProcedure

&AtServer
Procedure FillPricesBySupplierPriceTypesAtServer()
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsTable.Factor AS Factor,
	|	ProductsTable.Check AS Check
	|INTO ProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable
	|WHERE
	|	ProductsTable.Check
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	CASE
	|		WHEN CounterpartyPricesSliceLast.Actuality
	|			THEN ISNULL(CounterpartyPricesSliceLast.Price * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN CurrencyRateOfPriceKindInstallation.Rate * RateCurrencyTypePrices.Repetition / (RateCurrencyTypePrices.Rate * CurrencyRateOfPriceKindInstallation.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN RateCurrencyTypePrices.Rate * CurrencyRateOfPriceKindInstallation.Repetition / (CurrencyRateOfPriceKindInstallation.Rate * RateCurrencyTypePrices.Repetition)
	|					END * ISNULL(ProductsTable.Factor, 1) / ISNULL(CounterpartyPricesSliceLast.MeasurementUnit.Factor, 1), 0)
	|		ELSE 0
	|	END AS Price,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit
	|FROM
	|	ProductsTable AS ProductsTable
	|		LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast(
	|				&ToDate,
	|				SupplierPriceTypes = &SupplierPriceTypes
	|					AND Counterparty = &Counterparty
	|					AND (Products, Characteristic) IN
	|						(SELECT
	|							Table.Products,
	|							Table.Characteristic
	|						FROM
	|							ProductsTable AS Table)) AS CounterpartyPricesSliceLast
	|		ON ProductsTable.Products = CounterpartyPricesSliceLast.Products
	|			AND ProductsTable.Characteristic = CounterpartyPricesSliceLast.Characteristic
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&ToDate, Company = &Company) AS RateCurrencyTypePrices
	|		ON (CounterpartyPricesSliceLast.SupplierPriceTypes.PriceCurrency = RateCurrencyTypePrices.Currency),
	|	InformationRegister.ExchangeRate.SliceLast(&ToDate, Currency = &Currency AND Company = &Company) AS CurrencyRateOfPriceKindInstallation";
		
	Query.SetParameter("ToDate", 				Period);
	Query.SetParameter("SupplierPriceTypes", 	SupplierPriceTypes);
	Query.SetParameter("Counterparty", 		Counterparty);
	Query.SetParameter("Currency", 				PriceKindInstallation.PriceCurrency);
	Query.SetParameter("ProductsTable", 		GetProductsTable());
	Query.SetParameter("Company", 				Company);
	Query.SetParameter("ExchangeRateMethod",	DriveServer.GetExchangeMethod(Company));
	PlacePrices(Query.Execute().Unload());	
	
EndProcedure

&AtServer
Procedure FillPricesByReceiptInvoiceAtServer()
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsTable.Factor AS Factor,
	|	ProductsTable.Check AS Check
	|INTO ProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable
	|WHERE
	|	ProductsTable.Check
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ISNULL(SupplierInvoiceInventory.Price * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN CurrencyRateOfPriceKindInstallation.Rate * RateCurrencyTypePrices.Repetition / (RateCurrencyTypePrices.Rate * CurrencyRateOfPriceKindInstallation.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN RateCurrencyTypePrices.Rate * CurrencyRateOfPriceKindInstallation.Repetition / (CurrencyRateOfPriceKindInstallation.Rate * RateCurrencyTypePrices.Repetition)
	|		END * ISNULL(ProductsTable.Factor, 1) / ISNULL(SupplierInvoiceInventory.MeasurementUnit.Factor, 1), 0) AS Price,
	|	ProductsTable.MeasurementUnit
	|FROM
	|	ProductsTable AS ProductsTable
	|		LEFT JOIN Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		ON ProductsTable.Products = SupplierInvoiceInventory.Products
	|			AND ProductsTable.Characteristic = SupplierInvoiceInventory.Characteristic
	|			AND (SupplierInvoiceInventory.Ref = &SupplierInvoice)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&ToDate, Company = &Company) AS RateCurrencyTypePrices
	|		ON (SupplierInvoiceInventory.Ref.DocumentCurrency = RateCurrencyTypePrices.Currency),
	|	InformationRegister.ExchangeRate.SliceLast(&ToDate, Currency = &Currency AND Company = &Company) AS CurrencyRateOfPriceKindInstallation";
		
	Query.SetParameter("ToDate", 				Period);
	Query.SetParameter("SupplierInvoice", 		SupplierInvoice);
	Query.SetParameter("Currency", 				PriceKindInstallation.PriceCurrency);
	Query.SetParameter("ProductsTable", 		GetProductsTable());
	Query.SetParameter("Company", 				Company);
	Query.SetParameter("ExchangeRateMethod",	DriveServer.GetExchangeMethod(Company));
	PlacePrices(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure CalculateByBasicPriceKindAtServer()
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsTable.Factor AS Factor,
	|	ProductsTable.Check AS Check
	|INTO ProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable
	|WHERE
	|	ProductsTable.Check
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ISNULL(PricesSliceLast.Price * (1 + &Markup / 100) * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN CurrencyRateOfPriceKindInstallation.Rate * RateCurrencyTypePrices.Repetition / (RateCurrencyTypePrices.Rate * CurrencyRateOfPriceKindInstallation.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN RateCurrencyTypePrices.Rate * CurrencyRateOfPriceKindInstallation.Repetition / (CurrencyRateOfPriceKindInstallation.Rate * RateCurrencyTypePrices.Repetition)
	|		END * ISNULL(ProductsTable.Factor, 1) / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Price,
	|	ProductsTable.MeasurementUnit
	|FROM
	|	ProductsTable AS ProductsTable
	|		LEFT JOIN InformationRegister.Prices.SliceLast(
	|				&ToDate,
	|				PriceKind = &PriceKind
	|					AND (Products, Characteristic) In
	|						(SELECT
	|							Table.Products,
	|							Table.Characteristic
	|						FROM
	|							ProductsTable AS Table)) AS PricesSliceLast
	|		ON ProductsTable.Products = PricesSliceLast.Products
	|			AND ProductsTable.Characteristic = PricesSliceLast.Characteristic
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&ToDate, Company = &Company) AS RateCurrencyTypePrices
	|		ON (PricesSliceLast.PriceKind.PriceCurrency = RateCurrencyTypePrices.Currency),
	|	InformationRegister.ExchangeRate.SliceLast(&ToDate, Currency = &Currency AND Company = &Company) AS CurrencyRateOfPriceKindInstallation";
		
	Query.SetParameter("ToDate", 				Period);
	Query.SetParameter("PriceKind",				PricesBaseKind);
	Query.SetParameter("Currency", 				PriceKindInstallation.PriceCurrency);
	Query.SetParameter("Markup", 				Markup);
	Query.SetParameter("ProductsTable", 		GetProductsTable());
	Query.SetParameter("Company", 				Company);
	Query.SetParameter("ExchangeRateMethod",	DriveServer.GetExchangeMethod(Company));
	PlacePrices(Query.Execute().Unload());	
	
EndProcedure

&AtClient
Procedure ChangeForPercentAtClient()
	
	For Each TSRow In Prices Do
		
		If TSRow.Check Then
			
			If PlusMinus = "+" Then
				Price = TSRow.Price * (1 + Percent / 100);
			Else
				Price = TSRow.Price * (1 - Percent / 100);
			EndIf;
			
			TSRow.Price = Price;
			
		EndIf;
	
	EndDo;
	
EndProcedure

&AtClient
Procedure ChangeForAmountAtClient()
	
	For Each TSRow In Prices Do
		
		If TSRow.Check Then
			
			If PlusMinus = "+" Then
				Price = TSRow.Price + Amount;
			Else
				Price = TSRow.Price - Amount;
			EndIf;
			
			TSRow.Price = Price;
			
		EndIf;
	
	EndDo;
	
EndProcedure

&AtClient
Procedure RoundAtClient()
	
	For Each TSRow In Prices Do
		
		TSRow.Price = DriveClientServer.RoundPrice(TSRow.Price, RoundingOrder, RoundUp);
		
	EndDo;	
	
EndProcedure

#EndRegion

#Region PricesSettings

&AtServer
Procedure SetupAtServer()
	
	Query = New Query();
	
	Query.Text = 
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsTable.Price AS Price,
	|	ProductsTable.Check AS Check
	|INTO ProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable
	|;
	|	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsTable.Price AS Price,
	|	CASE
	|		WHEN Prices.PriceKind IS NULL 
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS double,
	|	MAX(ProductAndServicesPricesPeriods.Period) AS ProductsPricePeriod
	|FROM
	|	ProductsTable AS ProductsTable
	|		LEFT JOIN InformationRegister.Prices AS Prices
	|		ON ProductsTable.Products = Prices.Products
	|			AND ProductsTable.Characteristic = Prices.Characteristic
	|			AND (Prices.PriceKind = &PriceKind)
	|			AND (Prices.Period = &ToDate)
	|		LEFT JOIN InformationRegister.Prices AS ProductAndServicesPricesPeriods
	|		ON ProductsTable.Products = ProductAndServicesPricesPeriods.Products
	|			AND ProductsTable.Characteristic = ProductAndServicesPricesPeriods.Characteristic
	|			AND (ProductAndServicesPricesPeriods.PriceKind = &PriceKind)
	|			AND (ProductAndServicesPricesPeriods.Period < &ToDate)
	|WHERE
	|	ProductsTable.Check
	|	
	|GROUP BY
	|	ProductsTable.Products,
	|	ProductsTable.Characteristic,
	|	ProductsTable.MeasurementUnit,
	|	ProductsTable.Price,
	|	CASE
	|		WHEN Prices.PriceKind IS NULL 
	|			THEN FALSE
	|		ELSE TRUE
	|	END
	|;
	|	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NestedSelect.Products,
	|	NestedSelect.Characteristic,
	|	NestedSelect.Counter
	|FROM
	|	(SELECT
	|		ProductsTable.Products AS Products,
	|		ProductsTable.Characteristic AS Characteristic,
	|		SUM(1) AS Counter
	|	FROM
	|		ProductsTable AS ProductsTable
	|	WHERE
	|		ProductsTable.Check
	|	
	|	GROUP BY
	|		ProductsTable.Characteristic,
	|		ProductsTable.Products) AS NestedSelect
	|WHERE
	|	NestedSelect.Counter > 1";
		
	Query.SetParameter("PriceKind", PriceKindInstallation);
	Query.SetParameter("ToDate", InstallationPeriod);
	Query.SetParameter("ProductsTable", GetProductsTable());
	
	ResultsArray = Query.ExecuteBatch();
	
	// Duplication check. If duplicates exist - cancel!
	Selection = ResultsArray[2].Select();
	Cancel = False;
	
	While Selection.Next() Do
		
		Message = New UserMessage();
		Message.Text = NStr("en = '%Products%%Characteristic% is duplicated.'; ru = '???????????????????????????? ???????????????????????? %Products%%Characteristic%.';pl = '%Products%%Characteristic% jest zduplikowana.';es_ES = '%Products%%Characteristic% est?? duplicada.';es_CO = '%Products%%Characteristic% est?? duplicada.';tr = '%Products%%Characteristic% ??o??alt??ld??.';it = '%Products%%Characteristic% ?? duplicato.';de = '%Products%%Characteristic% ist dupliziert.'");
		Message.Text = StrReplace(Message.Text, "%Products%", Selection.Products);
		Message.Text = StrReplace(Message.Text, "%Characteristic%", ?(ValueIsFilled(Selection.Characteristic), 
										(" (" + Selection.Characteristic + ")"), ""));
		Message.Message();
		Cancel = True;
		
	EndDo;
	
	If Cancel Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Price changes are not applied.'; ru = '???????? ???? ???????? ????????????????.';pl = 'Zmiany cen nie s?? stosowane.';es_ES = 'No se aplican cambios en el precio.';es_CO = 'No se aplican cambios en el precio.';tr = 'Fiyat de??i??iklikleri uygulanmad??.';it = 'Le modifiche di prezzo non sono state applicate.';de = 'Preis??nderungen werden nicht ber??cksichtigt.'");
		Message.Message();
		Return;
	EndIf;
	
	// Price setting
	Selection = ResultsArray[1].Select();
	
	DocumentObject = Undefined;
	
	While Selection.Next() Do
		
		If Selection.double Then
			
			Message = New UserMessage();
			Message.Text = NStr("en = 'There is a price effective on the same date %ToDate% for %Products%%Characteristic%. The new price is not set.'; ru = '?????? %Products%%Characteristic% ?????? ?????????????????????? ???????? ???? ???????? %ToDate%. ?????????? ???????? ?????????????????????? ???? ??????????.';pl = 'W tym samym dniu obowi??zuje cena %ToDate% dla %Products%%Characteristic%. Nowa cena nie jest ustalona.';es_ES = 'Existe un precio efectivo en la misma fecha %ToDate% para %Products%%Characteristic%. El nuevo precio no est?? fijado.';es_CO = 'Existe un precio efectivo en la misma fecha %ToDate% para %Products%%Characteristic%. El nuevo precio no est?? fijado.';tr = '%Products% %Characteristic%i??in ayn?? tarihte %ToDate% ge??erli olan bir fiyat var. Yeni fiyat belirlenmedi.';it = 'C''?? un prezzo definito alla stessa data %ToDate% per %Products%%Characteristic%. Il nuovo prezzo non ?? impostato.';de = 'Am selben Datum %ToDate% ist ein Preis f??r %Products%%Characteristic%g??ltig. Der neue Preis ist nicht festgelegt.'");
			Message.Text = StrReplace(Message.Text, "%ToDate%", Format(InstallationPeriod, "DF=dd.MM.yy"));
			Message.Text = StrReplace(Message.Text, "%Products%", Selection.Products);
			Message.Text = StrReplace(Message.Text, "%Characteristic%", ?(ValueIsFilled(Selection.Characteristic), 
										 (" (" + Selection.Characteristic + ")"), ""));
			Message.Message();
			
			FilterStructure = New Structure;
			FilterStructure.Insert("Products", Selection.Products);
			FilterStructure.Insert("Characteristic", Selection.Characteristic);
			FilterStructure.Insert("Check", True);
			RowArray = Prices.FindRows(FilterStructure);
			
			For Each FoundString In RowArray Do
				FoundString.Picture = 2;
			EndDo;
		
		ElsIf Not ValueIsFilled(Selection.Price) Then
			
			Message = New UserMessage();
			Message.Text = NStr("en = 'Price for product %Products%%Characteristic% is not specified.'; ru = '?????? ???????????????????????? %Products%%Characteristic% ???? ?????????????? ????????.';pl = 'Cena za produkt %Products%%Characteristic% nie jest okre??lona.';es_ES = 'Precio para los productos %Products%%Characteristic% no est?? especificado.';es_CO = 'Precio para los productos %Products%%Characteristic% no est?? especificado.';tr = '??r??nler %Products%%Characteristic% i??in fiyat belirlenmemi??.';it = 'Il prezzo per l''articolo %Products%%Characteristic% non ?? specificato.';de = 'Der Preis f??r das Produkt %Products%%Characteristic% ist nicht angegeben.'");
			Message.Text = StrReplace(Message.Text, "%Products%", Selection.Products);
			Message.Text = StrReplace(Message.Text, "%Characteristic%", ?(ValueIsFilled(Selection.Characteristic), 
										 (" (" + Selection.Characteristic + ")"), ""));
			Message.Message();
			
			FilterStructure = New Structure;
			FilterStructure.Insert("Products", Selection.Products);
			FilterStructure.Insert("Characteristic", Selection.Characteristic);
			FilterStructure.Insert("Check", True);
			RowArray = Prices.FindRows(FilterStructure);
			
			For Each FoundString In RowArray Do
				FoundString.Picture = 2;
			EndDo;
			
		Else
			
			If DocumentObject = Undefined Then
				
				DocumentObject = Documents.Pricing.CreateDocument();
				DocumentObject.Date = InstallationPeriod;
				DocumentObject.PricePeriod = InstallationPeriod;
				DocumentObject.PriceKind = PriceKindInstallation;
				DocumentObject.Author = Author;
				DocumentObject.Comment = NStr("en = 'Created automatically by pricing tool'; ru = '???????????? ?????????????????????????? ?? ?????????????? ???????????????? ??????????????????????????????';pl = 'Stworzono automatycznie przez narz??dzie ustalania cen';es_ES = 'Creado autom??ticamente por la herramienta de tarificaci??n';es_CO = 'Creado autom??ticamente por la herramienta de tarificaci??n';tr = 'Fiyatland??rma arac?? taraf??ndan otomatik olu??turuldu';it = 'Creato automaticamente attraverso strumento definizione prezzo';de = 'Wird automatisch durch das Preisgestaltungstool erstellt'");
				
			EndIf;
			
			FillPropertyValues(DocumentObject.Inventory.Add(), Selection);
			
			FilterStructure = New Structure;
			FilterStructure.Insert("Products", Selection.Products);
			FilterStructure.Insert("Characteristic", Selection.Characteristic);
			FilterStructure.Insert("Check", True);
			RowArray = Prices.FindRows(FilterStructure);
			
			For Each FoundString In RowArray Do
				
				FoundString.Picture = 1;
				FoundString.Price = Selection.Price;
				
			EndDo; 
			
		EndIf;
	
	EndDo;
	
	If DocumentObject <> Undefined AND DocumentObject.Inventory.Count() > 0 Then
		
		Try
			
			DocumentObject.Write(DocumentWriteMode.Posting);
			
		Except
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot create document pricing with price type %1 on the date %2'; ru = '???????????????????? ?????????????? ???????????????? ""??????????????????????????????"" ?? ?????????? ?????? %1 ???? %2';pl = 'Nie udaje si?? utworzy?? dokumentu ustalanie cen z rodzajem ceny %1 na dzie?? %2';es_ES = 'No se ha podido crear la tarificaci??n del documento con el tipo de precio%1 en la fecha%2';es_CO = 'No se ha podido crear la tarificaci??n del documento con el tipo de precio%1 en la fecha%2';tr = ' %2 tarihinde %1 fiyat t??r?? ile belge fiyatland??rmas?? olu??turulam??yor';it = 'Impossibile create documento di definizione prezzo con il tipo prezzo %1 alla data %2';de = 'Es ist nicht m??glich das Dokument Preisgestaltung mit Preistyp %1 zum Datum zu erstellen %2'"),
				PriceKindInstallation,
				InstallationPeriod);
			
		EndTry;
		
	EndIf;
	
EndProcedure

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.PricesPrice);
	Fields.Add(Items.PricesOriginalPrice);
	
	Return Fields;
	
EndFunction

#EndRegion

#Region Other

&AtClient
Procedure ClearTabularSection()
	
	If Prices.Count() = 0 Then
		
		Return;
		
	EndIf;
	
	QuestionText = NStr("en = 'Tabular section will be cleared.
	                    |Continue?'; 
	                    |ru = '?????????????????? ?????????? ?????????? ??????????????!
	                    |?????????????????????';
	                    |pl = 'Sekcja tabelaryczna zostanie wyczyszczona.
	                    |Kontynuowa???';
	                    |es_ES = 'Secci??n tabular se eliminar??.
	                    |??Continuar?';
	                    |es_CO = 'Secci??n tabular se eliminar??.
	                    |??Continuar?';
	                    |tr = 'Tablo b??l??m?? silinecek.
	                    |Devam edilsin mi?';
	                    |it = 'La sezione tabellare verr?? cancellata.
	                    |Proseguire?';
	                    |de = 'Der tabellarische Abschnitt wird gel??scht.
	                    |Fortsetzen?'");
	
	NotifyDescription = New NotifyDescription("DetermineNecessityForTabularSectionClearing", ThisObject);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtServerNoContext
// Receives the set of data from the server for the ProductsOnChange procedure.
//
Function GetDataProductsOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	
	If StructureData.Property("PriceKind") Then
		
		StructureData.Insert("Characteristic", Catalogs.ProductsCharacteristics.EmptyRef());
		StructureData.Insert("DocumentCurrency", StructureData.PriceKind.PriceCurrency);
		StructureData.Insert("Factor", 1);
		
		PriceByPriceKind = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", PriceByPriceKind);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// It receives data set from server for the CharacteristicOnChange procedure.
//
Function GetDataCharacteristicOnChange(StructureData)
	
	StructureData.Insert("DocumentCurrency", StructureData.PriceKind.PriceCurrency);
	
	If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
	EndIf;
	
	PriceByPriceKind = DriveServer.GetProductsPriceByPriceKind(StructureData);
	StructureData.Insert("Price", PriceByPriceKind);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure;
	
	If CurrentMeasurementUnit = Undefined Then
		StructureData.Insert("CurrentFactor", 1);
	Else
		StructureData.Insert("CurrentFactor", CurrentMeasurementUnit.Factor);
	EndIf;
	
	If MeasurementUnit = Undefined Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", MeasurementUnit.Factor);
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Procedure GetPriceKindAttributesAtServer(StructurePriceKind)
	
	StructurePriceKind.Insert("PricesBaseKind", StructurePriceKind.PriceKind.PricesBaseKind);
	StructurePriceKind.Insert("Markup", StructurePriceKind.PriceKind.Percent);
	
EndProcedure

&AtClient
Function CheckCompany()
	
	If Not ValueIsFilled(Company) Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'The company must be filled.'; ru = '???????? ""??????????????????????"" ???? ?????????? ???????? ????????????.';pl = 'Firma powinna by?? wype??niona.';es_ES = 'La empresa debe estar rellenada.';es_CO = 'La empresa debe estar rellenada.';tr = '???? yeri mutlaka doldurulmal??d??r.';it = 'L''azienda deve essere compilata!';de = 'Die Firma soll ausgef??llt sein.'");
		Message.Field = "Company";
		Message.Message();
		Return False;
	Else
		Return True;
	EndIf
	
EndFunction

&AtClient
Procedure SetCompanyToolTipVisible()
	
	If ValueIsFilled(Company) Then
		Items.Company.ToolTipRepresentation = ToolTipRepresentation.None;
	Else
		Items.Company.ToolTipRepresentation = ToolTipRepresentation.ShowRight;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetPriceTypesChoiceList()

	WorkWithForm.SetChoiceParametersByCompany(Company, ThisForm, "PriceKindInstallation");
	
EndProcedure

#EndRegion

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ValueDates 	= ?(Parameters.Property("ToDate") AND ValueIsFilled(Parameters.ToDate), Parameters.ToDate, CurrentSessionDate());
	Period 			= ValueDates;
	InstallationPeriod = ValueDates;
	
	If GetFunctionalOption("UseSeveralCompanies") Then
		If Parameters.Property("Company") Then 
			Company = Parameters.Company; 
		Else
			Company = DriveReUse.GetUserDefaultCompany();
		EndIf;
	Else
		Company = Catalogs.Companies.MainCompany;
	EndIf;
	
	SetPriceTypesChoiceList();
	
	If Parameters.Property("PriceKind") AND ValueIsFilled(Parameters.PriceKind) Then
		
		ParameterPriceKind = Parameters.PriceKind;
		
		If ParameterPriceKind.CalculatesDynamically Then
			
			MessageText = NStr("en = 'Cannot generate dynamic price types.'; ru = '???? ?????????????? ???????????????????????? ???????????????????????? ???????? ??????.';pl = 'Nie mo??na wygenerowa?? dynamicznych rodzaj??w cen.';es_ES = 'No se puede generar los tipos de precios din??micos.';es_CO = 'No se puede generar los tipos de precios din??micos.';tr = 'Dinamik fiyat t??rleri olu??turulam??yor.';it = 'Impossibile generare tipi di prezzo dinamici.';de = 'Fehler beim Generieren von dynamischen Preistypen.'");
			DriveServer.ShowMessageAboutError(Object, MessageText, , , , Cancel);
			
		EndIf;
		
		PriceKindInstallation = Parameters.PriceKind;
		
	Else
		
		ParameterPriceKind = Undefined;
		
	EndIf;
	
	RoundingOrder	= Enums.RoundingMethods.Round0_01;
	RoundUp			= True;
	PricesBaseKind	= PriceKindInstallation.PricesBaseKind;
	Markup			= PriceKindInstallation.Percent;
	
	If Parameters.Property("PriceGroup") AND ValueIsFilled(Parameters.PriceGroup) Then
		ParameterPriceGroup = Parameters.PriceGroup;
	Else
		ParameterPriceGroup = Undefined;
	EndIf;
	
	If Parameters.Property("Products") AND ValueIsFilled(Parameters.Products) Then
		ParameterProducts = Parameters.Products;
	Else
		ParameterProducts = Undefined;
	EndIf;
	
	If Parameters.Property("AddressInventoryInStorage") Then
		Prices.Load(GetFromTempStorage(Parameters.AddressInventoryInStorage));
		For Each CurRow In Prices Do
			CurRow.Check = True;
		EndDo;
	EndIf;
	
	FillPricesFirstTime(Period, ParameterPriceKind, ParameterPriceGroup, ParameterProducts);
	
	FillingPrices = "Choose action...";
	CurrentAction = "";
	CurrentActionFill = "";
	Author = Users.CurrentUser();
	
	Items.PageSetup.CurrentPage = Items.Page0; 
	
	FunctionalCurrency = DriveReUse.GetFunctionalCurrency();;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetCompanyToolTipVisible();
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Company, PricesFields());
	// Prices precision end
	
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ValueSelected.FillVariant = "AddOnPrice" Then
		
		AddByPriceTypesAtServer(ValueSelected.ValueSelected, ValueSelected.ToDate, True, ValueSelected.UseCharacteristics);
		
	ElsIf ValueSelected.FillVariant = "AddBlankPricesByPriceKind" Then
		
		AddByPriceTypesAtServer(ValueSelected.ValueSelected, ValueSelected.ToDate, False, ValueSelected.UseCharacteristics);
		
	ElsIf ValueSelected.FillVariant = "AddOnPriceToFolders" Then
		
		AddByPriceGroupsAtServer(ValueSelected.ValueSelected, ValueSelected.UseCharacteristics);
		
	ElsIf ValueSelected.FillVariant = "AddByProductsGroups" Then
		
		AddByProductsCategoriesAtServer(ValueSelected.ValueSelected, ValueSelected.UseCharacteristics);
		
	ElsIf ValueSelected.FillVariant = "AddToInvoiceReceipt" Then
		
		AddByReceiptInvoiceAtServer(ValueSelected.ValueSelected);
		
	EndIf; 
	
EndProcedure

&AtClient
Procedure ExecuteActions(Command)
	
	If Not CheckCompany() Then 
		Return;
	EndIf;
	
	If CurrentAction = "FillPricesByPriceKind" Then
		
		FillPricesByPriceKindAtServer();
		
	ElsIf CurrentAction = "FillPricesBySupplierPriceTypes" Then
		
		FillPricesBySupplierPriceTypesAtServer();
		
	ElsIf CurrentAction = "CalculateByBasicPriceKind" Then
		
		CalculateByBasicPriceKindAtServer()
		
	ElsIf CurrentAction = "ChangeForPercent" Then
		
		ChangeForPercentAtClient();
		
	ElsIf CurrentAction = "ChangeForAmount" Then
		
		ChangeForAmountAtClient();
		
	ElsIf CurrentAction = "Rounding" Then
		
		RoundAtClient();
		
	ElsIf CurrentAction = "FillPricesByReceiptInvoice" Then
		
		FillPricesByReceiptInvoiceAtServer();
		
	EndIf; 
	
EndProcedure

&AtClient
Procedure Set(Command)
	
	If Not ValueIsFilled(PriceKindInstallation) Then
	
		Message = New UserMessage();
		Message.Text = NStr("en = 'Step 1: The price type is not selected.'; ru = '?????? 1: ???? ???????????? ?????? ??????.';pl = 'Krok 1: Rodzaj ceny nie jest wybrany.';es_ES = 'Paso 1: El tipo de precios no est?? seleccionado.';es_CO = 'Paso 1: El tipo de precios no est?? seleccionado.';tr = 'Ad??m 1: Fiyat t??r?? se??ilmedi.';it = 'Passaggio 1: Non ?? selezionato il tipo di prezzo.';de = 'Schritt 1: Der Preistyp ist nicht ausgew??hlt.'");
		Message.Field = "PriceKindInstallation";
		Message.Message();
		Return;
	
	EndIf; 
	
	If Not ValueIsFilled(InstallationPeriod) Then
	
		Message = New UserMessage();
		Message.Text = NStr("en = 'Step 4: Price set date is not selected.'; ru = '?????? 4: ???? ?????????????? ???????? ?????????????????? ??????!';pl = 'Krok 4: nie wybrano daty ustawienia cen.';es_ES = 'Paso 4: Fecha de establecimiento de precios no est?? seleccionada.';es_CO = 'Paso 4: Fecha de establecimiento de precios no est?? seleccionada.';tr = 'Ad??m 4: Fiyat ayar tarihi se??ilmemi??.';it = 'Passaggio 4: La data di impostazione del prezzo non ?? stata selezionata.';de = 'Schritt 4: Das Preisfestlegungsdatum ist nicht ausgew??hlt.'");
		Message.Field = "InstallationPeriod";
		Message.Message();
		Return;
	
	EndIf; 
	
	SetupAtServer();
	
EndProcedure

&AtClient
Procedure CloseForm(Command)
	
	Close(True);
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	SetCompanyToolTipVisible();
	SetPriceTypesChoiceList();
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Company, PricesFields());
	// Prices precision end
	
EndProcedure

#Region TableFillingMechanisms

&AtClient
Procedure FillPriceTabularSection(Command)
	
	If Not CheckCompany() Then 
		Return;
	EndIf;
	
	OpenForm("DataProcessor.Pricing.Form.FillingSettingsForm", , ThisForm);
	
EndProcedure

&AtClient
Procedure ClearPriceTabularSection(Command)
	
	ClearTabularSection();
	
EndProcedure

#EndRegion

#Region PagesAndActionsAttributesProcessingsSwitching

&AtClient
Procedure FillingPricesOnChange(Item)
	
	If FillingPrices = "Choose action..." Then
		
		CurrentAction = "";
		Items.PageSetup.CurrentPage = Items.Page0;
		
	ElsIf FillingPrices = "FillPricesByPriceKind" Then
		
		FillPricesByPriceKind(Undefined);
		
	ElsIf FillingPrices = "FillPricesBySupplierPriceTypes" Then
		
		FillPricesBySupplierPriceTypes(Undefined);
		
	ElsIf FillingPrices = "FillPricesByReceiptInvoice" Then
		
		FillPricesByReceiptInvoice(Undefined);
		
	ElsIf FillingPrices = "CalculateByBasicPriceKind" Then
		
		CalculateByBasicPriceKind(Undefined);
		
	ElsIf FillingPrices = "Rounding" Then
		
		Rounding(Undefined);
		
	ElsIf FillingPrices = "ChangeForAmount" Then
		
		ChangeForAmount(Undefined);
		
	ElsIf FillingPrices = "ChangeForPercent" Then
		
		ChangeForPercent(Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillPricesByPriceKind(Command)
	
	If CurrentAction = "FillPricesByPriceKind" Then
		Return;
	EndIf;
	CurrentAction = "FillPricesByPriceKind";
	
	Items.PageSetup.CurrentPage = Items.Page1;
	PriceKind = PriceKindInstallation;
	Period = CommonClient.SessionDate();
	
EndProcedure

&AtClient
Procedure FillPricesBySupplierPriceTypes(Command)
	
	If CurrentAction = "FillPricesBySupplierPriceTypes" Then
		Return;
	EndIf;
	CurrentAction = "FillPricesBySupplierPriceTypes";
	
	Items.PageSetup.CurrentPage = Items.Page2;
	
EndProcedure

&AtClient
Procedure CalculateByBasicPriceKind(Command)
	
	If CurrentAction = "CalculateByBasicPriceKind" Then
		Return;
	EndIf;
	CurrentAction = "CalculateByBasicPriceKind";
	
	Items.PageSetup.CurrentPage = Items.Page3;
	
EndProcedure

&AtClient
Procedure ChangeForPercent(Command)
	
	If CurrentAction = "ChangeForPercent" Then
		Return;
	EndIf;
	CurrentAction = "ChangeForPercent";
	
	Items.PageSetup.CurrentPage = Items.Page4;
	PlusMinus = "+";
	
EndProcedure

&AtClient
Procedure ChangeForAmount(Command)
	
	If CurrentAction = "ChangeForAmount" Then
		Return;
	EndIf;
	CurrentAction = "ChangeForAmount";
	
	Items.PageSetup.CurrentPage = Items.Page5;
	PlusMinus = "+";
	
EndProcedure

&AtClient
Procedure Rounding(Command)
	
	If CurrentAction = "Rounding" Then
		Return;
	EndIf;
	CurrentAction = "Rounding";
	
	Items.PageSetup.CurrentPage = Items.Page6;
	
EndProcedure

&AtClient
Procedure FillPricesByReceiptInvoice(Command)
	
	If CurrentAction = "FillPricesByReceiptInvoice" Then
		Return;
	EndIf;
	CurrentAction = "FillPricesByReceiptInvoice";
	
	Items.PageSetup.CurrentPage = Items.Page7;
	
EndProcedure

&AtClient
Procedure MarkAll(Command)
	
	For Each TableRow In Prices Do
		TableRow.Check = True;
	EndDo;  
	
EndProcedure

&AtClient
Procedure UncheckMarks(Command)
	For Each TableRow In Prices Do
		TableRow.Check = False;
	EndDo;
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Products input field.
//
Procedure PricesProductsOnChange(Item)
	
	TabularSectionRow = Items.Prices.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	
	If ValueIsFilled(PriceKindInstallation) Then
		StructureData.Insert("PriceKind", PriceKindInstallation);
		StructureData.Insert("ProcessingDate", InstallationPeriod);
	EndIf;
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Check = True;
	
	TabularSectionRow.OriginalPrice = StructureData.Price;
	TabularSectionRow.Price = StructureData.Price;
	
EndProcedure

&AtClient
Procedure PricesCharacteristicOnChange(Item)
	
	If ValueIsFilled(PriceKindInstallation) Then
		
		TabularSectionRow = Items.Prices.CurrentData;
		
		StructureData = New Structure;
		StructureData.Insert("Company", Company);
		StructureData.Insert("PriceKind", PriceKindInstallation);
		StructureData.Insert("ProcessingDate", InstallationPeriod);
		StructureData.Insert("Products", TabularSectionRow.Products);
		StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
		StructureData.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		
		StructureData = GetDataCharacteristicOnChange(StructureData);
		
		TabularSectionRow.OriginalPrice = StructureData.Price;
		TabularSectionRow.Price = StructureData.Price;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
Procedure PricesMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Prices.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected 
	 OR TabularSectionRow.Price = 0 Then
		Return;
	EndIf;
	
	CurrentFactor = 0;
	If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		CurrentFactor = 1;
	EndIf;
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		Factor = 1;
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
		
EndProcedure

&AtClient
Procedure PriceKindInstallationOnChange(Item)
	
	If Not ValueIsFilled(PriceKindInstallation) Then
		Return;
	EndIf; 
	
	StructurePriceKind = New Structure("PriceKind", PriceKindInstallation);
	
	GetPriceKindAttributesAtServer(StructurePriceKind);
	
	PricesBaseKind = StructurePriceKind.PricesBaseKind;
	Markup = StructurePriceKind.Markup;
	
EndProcedure

// Procedure - event handler StartChoice of PriceKindCounterparty2 input field
//
&AtClient
Procedure PriceKindCounterparty2StartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenForm("Catalog.SupplierPriceTypes.ChoiceForm", New Structure("Counterparty", Counterparty), Item);
	
EndProcedure

#EndRegion

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the question result document form filling by a basis document
//
//
Procedure DetermineNecessityForTabularSectionClearing(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Prices.Clear();
		
	EndIf;
	
EndProcedure


#EndRegion

#EndRegion