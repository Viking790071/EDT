
#Region Public

Procedure AddBundleInformationOnGetProductsData(StructureData, UseGLAccounts = False) Export
	
	If ValueIsFilled(StructureData.Products) Then
		
		AttributesValues = Common.ObjectAttributesValues(StructureData.Products, "IsBundle, UseCharacteristics, BundlePricingStrategy");
		
	Else
		
		AttributesValues = New Structure("IsBundle, UseCharacteristics", False, False);
		
	EndIf;
	
	If Not StructureData.Property("UseCharacteristics") Then
		
		StructureData.Insert("UseCharacteristics", AttributesValues.UseCharacteristics);
		
	EndIf;
	
	StructureData.Insert("IsBundle", AttributesValues.IsBundle);
	
	If StructureData.Property("PriceKind") Then
		
		AttributesStructure = Common.ObjectAttributesValues(StructureData.PriceKind, "PriceIncludesVAT");
		CommonClientServer.SupplementStructure(StructureData, AttributesStructure, True);
		
	Else
		
		StructureData.Insert("PriceIncludesVAT", True);
		
	EndIf;
	
	StructureData.Insert("RoundingOrder", Enums.RoundingMethods.Round0_01);
	StructureData.Insert("RoundUp", False);
	
	If StructureData.IsBundle Then
		
		If AttributesValues.UseCharacteristics And Not AreEnteredCharacteristics(StructureData.Products) Then
			StructureData.Insert("UseCharacteristics", False);
		EndIf;
		
		StructureData.Insert("BundlePricingStrategy", AttributesValues.BundlePricingStrategy);
		StructureData.Insert("BundlesComponents", New Array);
		
		TempTablesManager = New TempTablesManager;
		
		Query = New Query;
		Query.TempTablesManager = TempTablesManager;
		Query.SetParameter("BundleProduct", StructureData.Products);
		Query.SetParameter("BundleCharacteristic", ?(StructureData.Property("Characteristic") And TypeOf(StructureData.Characteristic)=Type("CatalogRef.ProductsCharacteristics"), StructureData.Characteristic, Catalogs.ProductsCharacteristics.EmptyRef()));
		Query.SetParameter("PriceKind", ?(StructureData.Property("PriceKind"), StructureData.PriceKind, Catalogs.PriceTypes.EmptyRef()));
		Query.SetParameter("DocumentCurrency", ?(StructureData.Property("DocumentCurrency"), StructureData.DocumentCurrency, Catalogs.Currencies.EmptyRef()));
		Query.SetParameter("ProcessingDate", ?(StructureData.Property("ProcessingDate"), StructureData.ProcessingDate, '0001-01-01'));
		Query.SetParameter("WorkKind", ?(Not StructureData.Property("WorkKind") Or TypeOf(StructureData.WorkKind) <> Type("CatalogRef.Products"), Catalogs.Products.EmptyRef(), StructureData.WorkKind));
		Query.SetParameter("Company", ?(StructureData.Property("Company"), StructureData.Company, DriveReUse.GetUserDefaultCompany()));
		Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(StructureData.Company));
		
		Query.Text =
		"SELECT
		|	BundlesComponents.BundleProduct AS BundleProduct,
		|	BundlesComponents.BundleProduct.BundlePricingStrategy AS BundlePricingStrategy,
		|	BundlesComponents.Products AS Products,
		|	BundlesComponents.Characteristic AS Characteristic,
		|	BundlesComponents.MeasurementUnit AS MeasurementUnit,
		|	BundlesComponents.Quantity AS Quantity,
		|	BundlesComponents.CostShare AS CostShare,
		|	BundlesComponents.Order AS Order,
		|	CatalogProducts.Warehouse AS Warehouse,
		|	CatalogProducts.Cell AS Cell,
		|	CatalogProducts.VATRate AS VATRate,
		|	CASE
		|		WHEN BundlesComponents.MeasurementUnit REFS Catalog.UOM
		|			THEN BundlesComponents.MeasurementUnit.Factor
		|		ELSE 1
		|	END AS Factor,
		|	CatalogProducts.ProductsType AS ProductsType,
		|	CatalogProducts.CountryOfOrigin AS CountryOfOrigin
		|INTO BundlesComponents
		|FROM
		|	InformationRegister.BundlesComponents AS BundlesComponents
		|		LEFT JOIN Catalog.Products AS CatalogProducts
		|		ON BundlesComponents.Products = CatalogProducts.Ref
		|WHERE
		|	BundlesComponents.BundleProduct = &BundleProduct
		|	AND (BundlesComponents.BundleCharacteristic = &BundleCharacteristic
		|				AND NOT BundlesComponents.IsCommon
		|			OR &BundleCharacteristic <> VALUE(Catalog.ProductsCharacteristics.EmptyRef)
		|				AND BundlesComponents.IsCommon)";
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		
		If StructureData.Property("PriceKind")
			AND StructureData.PriceKind.PriceCalculationMethod = Enums.PriceCalculationMethods.Formula Then
			
			Query.Text = Query.Text +
			"SELECT
			|	BundlesComponents.Products AS Products,
			|	BundlesComponents.Characteristic AS Characteristic,
			|	BundlesComponents.MeasurementUnit AS MeasurementUnit
			|FROM
			|	BundlesComponents AS BundlesComponents
			|WHERE
			|	(BundlesComponents.BundlePricingStrategy = VALUE(Enum.ProductBundlePricingStrategy.PerComponentPricing)
			|			OR BundlesComponents.BundlePricingStrategy = VALUE(Enum.ProductBundlePricingStrategy.BundlePriceProratedByPrices))";
			
			ProductsCharacteristicTable = PriceGenerationFormulaServerCall.GetTabularSectionPricesByFormula(StructureData,
				Query.Execute().Unload());
			
			Query.SetParameter("ProductsCharacteristicTable", ProductsCharacteristicTable);
			Query.Text =
			"SELECT
			|	ProductsCharacteristicTable.Products AS Products,
			|	ProductsCharacteristicTable.Characteristic AS Characteristic,
			|	ProductsCharacteristicTable.Price AS Price
			|INTO PriceTable
			|FROM
			|	&ProductsCharacteristicTable AS ProductsCharacteristicTable
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	ISNULL(PriceTypes.PriceIncludesVAT, TRUE) AS PriceIncludesVAT,
			|	BundlesComponents.Products AS Products,
			|	BundlesComponents.Characteristic AS Characteristic,
			|	BundlesComponents.MeasurementUnit AS MeasurementUnit,
			|	BundlesComponents.Factor AS Factor,
			|	BundlesComponents.Quantity AS Quantity,
			|	BundlesComponents.CostShare AS CostShare,
			|	BundlesComponents.VATRate AS VATRate,
			|	BundlesComponents.ProductsType AS ProductsType,
			|	BundlesComponents.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ProductsTypeInventory,
			|	BundlesComponents.ProductsType = VALUE(Enum.ProductsTypes.Service) AS ProductsTypeService,
			|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS Specification,
			|	ISNULL(PriceTable.Price * CASE
			|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
			|				THEN DocumentExchangeRate.Rate / DocumentExchangeRate.Repetition 
			|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
			|				THEN DocumentExchangeRate.Repetition / DocumentExchangeRate.Rate
			|		END * BundlesComponents.Factor, 0) AS Price,
			|	BundlesComponents.Warehouse AS Warehouse,
			|	BundlesComponents.Cell AS Cell,
			|	BundlesComponents.CountryOfOrigin AS CountryOfOrigin
			|FROM
			|	BundlesComponents AS BundlesComponents
			|		LEFT JOIN PriceTable AS PriceTable
			|		ON BundlesComponents.Products = PriceTable.Products
			|			AND BundlesComponents.Characteristic = PriceTable.Characteristic
			|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&ProcessingDate, Currency = &DocumentCurrency AND Company = &Company) AS DocumentExchangeRate
			|		ON (TRUE)
			|		LEFT JOIN Catalog.PriceTypes AS PriceTypes
			|		ON (PriceTypes.Ref = &PriceKind)
			|
			|ORDER BY
			|	BundlesComponents.Order";
			
		Else
			
			Query.Text = Query.Text +
			"SELECT
			|	ISNULL(PricesSliceLast.PriceKind.PriceIncludesVAT, TRUE) AS PriceIncludesVAT,
			|	BundlesComponents.Products AS Products,
			|	BundlesComponents.Characteristic AS Characteristic,
			|	BundlesComponents.MeasurementUnit AS MeasurementUnit,
			|	BundlesComponents.Factor AS Factor,
			|	BundlesComponents.Quantity AS Quantity,
			|	BundlesComponents.CostShare AS CostShare,
			|	BundlesComponents.VATRate AS VATRate,
			|	BundlesComponents.ProductsType AS ProductsType,
			|	BundlesComponents.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ProductsTypeInventory,
			|	BundlesComponents.ProductsType = VALUE(Enum.ProductsTypes.Service) AS ProductsTypeService,
			|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS Specification,
			|	ISNULL(PricesSliceLast.Price * CASE
			|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
			|				THEN DocumentExchangeRate.Rate * ExchangeRateSliceLast.Repetition / (ExchangeRateSliceLast.Rate * DocumentExchangeRate.Repetition)
			|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
			|				THEN ExchangeRateSliceLast.Rate * DocumentExchangeRate.Repetition / (DocumentExchangeRate.Rate * ExchangeRateSliceLast.Repetition)
			|		END * BundlesComponents.Factor / CASE
			|			WHEN PricesSliceLast.MeasurementUnit REFS Catalog.UOM
			|				THEN PricesSliceLast.MeasurementUnit.Factor
			|			ELSE 1
			|		END, 0) AS Price,
			|	BundlesComponents.Warehouse AS Warehouse,
			|	BundlesComponents.Cell AS Cell,
			|	BundlesComponents.CountryOfOrigin AS CountryOfOrigin
			|FROM
			|	BundlesComponents AS BundlesComponents
			|		LEFT JOIN InformationRegister.Prices.SliceLast(
			|				&ProcessingDate,
			|				PriceKind = &PriceKind
			|					AND (Products, Characteristic) IN
			|						(SELECT
			|							BundlesComponents.Products AS Products,
			|							BundlesComponents.Characteristic AS Characteristic
			|						FROM
			|							BundlesComponents AS BundlesComponents
			|						WHERE
			|							(BundlesComponents.BundlePricingStrategy = VALUE(Enum.ProductBundlePricingStrategy.PerComponentPricing)
			|								OR BundlesComponents.BundlePricingStrategy = VALUE(Enum.ProductBundlePricingStrategy.BundlePriceProratedByPrices)))) AS PricesSliceLast
			|			LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&ProcessingDate, Company = &Company) AS ExchangeRateSliceLast
			|			ON PricesSliceLast.PriceKind.PriceCurrency = ExchangeRateSliceLast.Currency
			|		ON BundlesComponents.Products = PricesSliceLast.Products
			|			AND BundlesComponents.Characteristic = PricesSliceLast.Characteristic
			|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
			|				&ProcessingDate,
			|				Currency = &DocumentCurrency
			|					AND Company = &Company) AS DocumentExchangeRate
			|		ON (TRUE)
			|
			|ORDER BY
			|	BundlesComponents.Order";
			
		EndIf;
		
		Selection = Query.Execute().Select();
		BundlePrice = 0;
		CostShare = 0;
		
		If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
			ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(StructureData.Object, "StructuralUnitReserve");
			GLAccountsInDocuments.CompleteObjectParameters(StructureData.Object, ObjectParameters);
		EndIf;
		
		While Selection.Next() Do
			
			RowsStructure = New Structure("Products, Characteristic, MeasurementUnit, Factor, Quantity, CostShare, VATRate, ProductsType, ProductsTypeInventory, ProductsTypeService, Specification, Price, Warehouse, Cell, CountryOfOrigin");
			
			FillPropertyValues(RowsStructure, Selection, , "Price");
			
			Price = Selection.Price;
			
			If StructureData.Property("AmountIncludesVAT")
				And ((StructureData.AmountIncludesVAT And Not Selection.PriceIncludesVAT)
					Or (Not StructureData.AmountIncludesVAT And Selection.PriceIncludesVAT)) Then
				
					Price = DriveServer.RecalculateAmountOnVATFlagsChange(Price, StructureData.AmountIncludesVAT, Selection.VATRate);
			
			EndIf;
			
			Price = DriveClientServer.RoundPrice(Price, StructureData.RoundingOrder);
			RowsStructure.Price = Price;
			
			If StructureData.Property("DiscountPercent") Then
				RowsStructure.Insert("DiscountPercent", StructureData.DiscountPercent);
			EndIf;
			
			If StructureData.Property("VATTaxation") 
				And Not StructureData.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
				
				If StructureData.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
					
					RowsStructure.Insert("VATRate", PredefinedValue("Catalog.VATRates.Exempt"));
					
				Else
					
					RowsStructure.Insert("VATRate", PredefinedValue("Catalog.VATRates.ZeroRate"));
					
				EndIf;
				
			ElsIf ValueIsFilled(Selection.VATRate) Then
				
				RowsStructure.Insert("VATRate", Selection.VATRate);
				
			Else
				
				RowsStructure.Insert("VATRate", InformationRegisters.AccountingPolicy.GetDefaultVATRate(, StructureData.Company));
				
			EndIf;
			
			If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
				
				TabName = "Inventory";
				
				If StructureData.Property("TabName") Then 
					TabName = StructureData.TabName; 
				EndIf;
				
				GLAccountsStructure = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, TabName);
				GLAccountsInDocuments.CompleteStructureData(GLAccountsStructure, ObjectParameters, TabName);
				
				For Each GLAccountItem In GLAccountsStructure Do
					If Not RowsStructure.Property(GLAccountItem.Key) Then
						RowsStructure.Insert(GLAccountItem.Key, GLAccountItem.Value);
					EndIf;
				EndDo;
				
				GLAccountsInDocuments.FillProductGLAccounts(RowsStructure);
				
			EndIf;
			
			StructureData.BundlesComponents.Add(RowsStructure);
			
			BundlePrice	= BundlePrice + Price * Selection.Quantity;
			CostShare	= CostShare + Selection.CostShare;
			
		EndDo;
		
		Balance = 0;
		
		If StructureData.BundlePricingStrategy = Enums.ProductBundlePricingStrategy.PerComponentPricing Then
			
			StructureData.Insert("Price", BundlePrice);
			
		ElsIf StructureData.BundlePricingStrategy = Enums.ProductBundlePricingStrategy.BundlePriceProratedByComponentsCost
			And StructureData.Property("Price") And StructureData.Price > 0 And CostShare <> 0 Then
			
			For Each ComponentsDescription In StructureData.BundlesComponents Do
				PositionPrice = StructureData.Price * ComponentsDescription.CostShare / CostShare / ComponentsDescription.Quantity;
				Balance = Balance + (PositionPrice - Round(PositionPrice, 2)) * ComponentsDescription.Quantity;
				ComponentsDescription.Price = Round(PositionPrice, 2);
			EndDo;
			
		ElsIf StructureData.BundlePricingStrategy = Enums.ProductBundlePricingStrategy.BundlePriceProratedByPrices
			And StructureData.Property("Price") And StructureData.Price > 0 And BundlePrice <> 0 Then
			
			For Each ComponentsDescription In StructureData.BundlesComponents Do
				PositionPrice = StructureData.Price * ComponentsDescription.Price / BundlePrice;
				Balance = Balance + (PositionPrice - Round(PositionPrice, 2)) * ComponentsDescription.Quantity;
				ComponentsDescription.Price = Round(PositionPrice, 2);
			EndDo;
			
		EndIf;
		
		BundlesClientServer.RoundingBundlePrice(StructureData.BundlesComponents, Balance);
		
	EndIf;
	
EndProcedure

Procedure RefreshBundleComponentsInTable(BundleProduct, BundleCharacteristic, BundesQuantity, BundlesComponents, FillingParameters, Variant = Undefined) Export
	
	Object = FillingParameters.Object;
	
	TableName = "Inventory";
	If FillingParameters.Property("TableName") Then
		TableName = FillingParameters.TableName;
	EndIf;
	
	StructuralUnitName = "StructuralUnit";
	If FillingParameters.Property("StructuralUnit") Then
		StructuralUnitName = FillingParameters.StructuralUnit;
	EndIf;
	
	UseDefaultTypeOfAccounting = False;
	If FillingParameters.Property("UseDefaultTypeOfAccounting") Then
		UseDefaultTypeOfAccounting = FillingParameters.UseDefaultTypeOfAccounting;
	EndIf;
	
	CalculationParameters = New Structure;
	CalculationParameters.Insert("ResetFlagDiscountsAreCalculated", True);
	
	If Object.Property("AmountIncludesVAT") Then
		CalculationParameters.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	EndIf;
	
	CalculationParameters.Insert("CalculateDiscounts", Object.Property("DiscountMarkupKind"));
	
	If Object.Property("DiscountMarkupKind") 
		And ValueIsFilled(Object.DiscountMarkupKind) Then
		DiscountMarkupPercentDefault = Common.ObjectAttributeValue(Object.DiscountMarkupKind, "Percent");
	Else
		DiscountMarkupPercentDefault = 0;
	EndIf;
	
	If Object.Property("DiscountPercentByDiscountCard")
		And Object.Property("DiscountCard")
		And ValueIsFilled(Object.DiscountCard) Then
		DiscountMarkupPercentDefault = DiscountMarkupPercentDefault + Object.DiscountPercentByDiscountCard;
	EndIf;
	
	FilterStructure = New Structure;
	FilterStructure.Insert("BundleProduct", BundleProduct);
	FilterStructure.Insert("BundleCharacteristic", BundleCharacteristic);
	If Variant <> Undefined Then
		FilterStructure.Insert("Variant", Variant);
	EndIf;
	
	If Object.Property("AddedBundles") Then
		
		AddedRows = Object.AddedBundles.FindRows(FilterStructure);
		
		If AddedRows.Count() = 0 Then
			AddedRow = Object.AddedBundles.Add();
			FillPropertyValues(AddedRow, FilterStructure);
		Else
			AddedRow = AddedRows[0];
		EndIf;
		
		AddedRow.Quantity = BundesQuantity;
		
	Else
		
		AddedRows = New Array;
		
	EndIf;
	
	If BundlesComponents.Count() > 0 Then
		
		FirstRow = BundlesComponents[0];
		ReplacementDone = False;
		// On replacing a bundle in the bundle editing form, the items will contain the new values
		If FirstRow.Property("BundleProduct") And ValueIsFilled(FirstRow.BundleProduct) And FirstRow.BundleProduct<>BundleProduct Then
			BundleProduct = FirstRow.BundleProduct;
			If AddedRows.Count() > 0 Then
				AddedRows[0].BundleProduct = BundleProduct;
				ReplacementDone = True;
			EndIf;
		EndIf;
		
		If FirstRow.Property("BundleCharacteristic") And ValueIsFilled(FirstRow.BundleCharacteristic) And FirstRow.BundleCharacteristic<>BundleCharacteristic Then
			BundleCharacteristic = FirstRow.BundleCharacteristic;
			If AddedRows.Count() > 0 Then
				AddedRows[0].BundleCharacteristic = BundleCharacteristic;
				ReplacementDone = True;
			EndIf; 
		EndIf;
		
		If ReplacementDone Then
			// Collapling table AddedBundles
			TP = Object.AddedBundles.Unload();
			TP.GroupBy("BundleProduct, BundleCharacteristic" + ?(AddedRows[0].Property("Variant"), ", Variant", ""), "Quantity");
			Object.AddedBundles.Load(TP);
			AddedRows.Clear();
		EndIf;
		
	EndIf;
	
	TableRows = Object[TableName].FindRows(FilterStructure);
	
	BundlePricingStrategy = BundleProduct.BundlePricingStrategy;
	SavePrices = (BundlePricingStrategy = Enums.ProductBundlePricingStrategy.PerComponentPricing);
	IsWorkOrder = (TypeOf(Object.Ref) = Type("DocumentRef.WorkOrder"));
	
	ValueBuffer = New ValueTable;
	ValueBuffer.Columns.Add("Products");
	ValueBuffer.Columns.Add("Characteristic");
	ValueBuffer.Columns.Add("MeasurementUnit");
	ValueBuffer.Columns.Add("DiscountPercent");
	ValueBuffer.Columns.Add("Reserve");
	ValueBuffer.Columns.Add("ReserveShipment");
	ValueBuffer.Columns.Add("StructuralUnit");
	ValueBuffer.Columns.Add("Cell");
	ValueBuffer.Columns.Add("Specification");
	ValueBuffer.Columns.Add("Batch");
	ValueBuffer.Columns.Add("ProductsTypeInventory");
	ValueBuffer.Columns.Add("ProductsTypeService");
	ValueBuffer.Columns.Add("CountryOfOrigin");
	ValueBuffer.Columns.Add("Check");
	
	If SavePrices Then
		ValueBuffer.Columns.Add("Price");
	EndIf;
	
	// Delete replacing rows
	NewRowIndex = Undefined;
	For Each Row In TableRows Do
		If NewRowIndex = Undefined Then
			NewRowIndex = Object[TableName].IndexOf(Row);
		EndIf;
		RowBuffer = ValueBuffer.Add();
		FillPropertyValues(RowBuffer, Row);
		Object[TableName].Delete(Row);
	EndDo;
	
	CalculatePricesOfBundleComponents(BundleProduct, BundleCharacteristic, Variant, BundesQuantity, BundlesComponents, Object);
	
	If UseDefaultTypeOfAccounting Then
		ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object, StructuralUnitName);
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	// Add rows to table
	AddRows = (NewRowIndex >= Object[TableName].Count());
	For Each Component In BundlesComponents Do
		
		If AddRows Then
			NewRow = Object[TableName].Add();
		Else
			NewRow = Object[TableName].Insert(NewRowIndex);
			NewRowIndex = NewRowIndex+1;
		EndIf;
		
		FillPropertyValues(NewRow, Component);
		// Recovery of saved prices
		FilterStructure = New Structure;
		FilterStructure.Insert("Products", NewRow.Products);
		FilterStructure.Insert("Characteristic", NewRow.Characteristic);
		
		If NewRow.Property("MeasurementUnit") Then
			FilterStructure.Insert("MeasurementUnit", NewRow.MeasurementUnit);
		EndIf;
		
		RowsBuffer = ValueBuffer.FindRows(FilterStructure);
		
		If RowsBuffer.Count() > 0 Then
			FillPropertyValues(NewRow, RowsBuffer[0], , "Products, Characteristic" + ?(NewRow.Property("MeasurementUnit"), ", MeasurementUnit", ""));
		Else
			// Default values for new products
			If NewRow.Property("DiscountPercent") Then 
				NewRow.DiscountPercent = DiscountMarkupPercentDefault;
			EndIf;
			
			If NewRow.Property("Specification") Then
				If NewRow.Property("Characteristic") Then
					NewRow.Specification = DriveServer.GetDefaultSpecification(NewRow.Products, NewRow.Characteristic);
				Else
					NewRow.Specification = DriveServer.GetDefaultSpecification(NewRow.Products);
				EndIf;
			EndIf;
			
		EndIf;
		
		If NewRow.Property("Factor") Then
			NewRow.Factor = 1;
		EndIf;
		
		If NewRow.Property("BundlePicture") Then
			NewRow.BundlePicture = True;
		EndIf;
		
		If NewRow.Property("Amount") Then
			BundlesClientServer.CalculateAmountInTableRow(NewRow, CalculationParameters);
		EndIf;
		BundlesClientServer.FillNewRowAttributes(Object[TableName], NewRow);
		
		If UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, TableName);
		EndIf;
		
		If NewRow.Property("ProductsTypeInventory") And Component.Property("ProductsType") Then
			NewRow.ProductsTypeInventory = (Component.ProductsType = Enums.ProductsTypes.InventoryItem);
		EndIf;
		
	EndDo;
	
EndProcedure

Function CalculatePricesOfBundleComponents(BundleProduct, BundleCharacteristic, Variant = Undefined, BundesQuantity, BundlesComponents, Object) Export
	
	// Filling prices of bundle components
	DataStructure = New Structure;

	DataStructure.Insert("Date", Object.Date);
	If DriveServer.DocumentAttributeExistsOnLink("PriceKind", Object.Ref) Then
		
		DataStructure.Insert("PriceKind",				Object.PriceKind);
		DataStructure.Insert("Company",					Object.Company);
		DataStructure.Insert("DocumentCurrency",		Object.DocumentCurrency);
		DataStructure.Insert("AmountIncludesVAT",		Object.AmountIncludesVAT);
		DataStructure.Insert("DiscountMarkupKind",		Object.DiscountMarkupKind);
		DataStructure.Insert("DiscountMarkupPercent",	0);
		
		If DriveServer.DocumentAttributeExistsOnLink("DiscountPercentByDiscountCard", Object.Ref) Then
			DataStructure.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
		EndIf;
		
	EndIf;
	
	For Each TableRow In BundlesComponents Do
		
		TableRow.Insert("BundleProduct",		BundleProduct);
		TableRow.Insert("BundleCharacteristic",	BundleCharacteristic);
		TableRow.Insert("Price",				0);
		
		If Variant <> Undefined Then
			TableRow.Insert("Variant", Variant);
		Else
			TableRow.Insert("Variant", 0);
		EndIf;
		
		TableRow.Insert("BundesQuantity", BundesQuantity);
		
		If TableRow.Property("OriginalProducts") Then
			RowProducts = TableRow.OriginalProducts;
		Else
			RowProducts = TableRow.Products;
		EndIf;
		
		If Not ValueIsFilled(RowProducts) Then
			Continue;
		EndIf;
		
		If Not TableRow.Property("VATRate") Then
			
			If Object.Property("VATTaxation")
				And Not Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
				
				If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
					TableRow.Insert("VATRate", PredefinedValue("Catalog.VATRates.Exempt"));
				Else
					TableRow.Insert("VATRate", PredefinedValue("Catalog.VATRates.ZeroRate"));
				EndIf;
				
			ElsIf ValueIsFilled(RowProducts.VATRate) Then
				
				TableRow.Insert("VATRate", RowProducts.VATRate);
				
			Else
				
				TableRow.Insert("VATRate", InformationRegisters.AccountingPolicy.GetDefaultVATRate(, Object.Company));
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If DataStructure.Property("PriceKind") Then
		DriveServer.GetTabularSectionPricesByPriceKind(DataStructure, BundlesComponents);
		If DataStructure.Property("BundlesRoundings") And DataStructure.BundlesRoundings.Count() > 0 Then
			BundlesClientServer.RoundingBundlePrice(BundlesComponents, DataStructure.BundlesRoundings[0].Rounding);
		EndIf;
	EndIf;
	
EndFunction

Procedure CheckTableFilling(Object, TableName, Cancel) Export
	
	If Not GetFunctionalOption("UseProductBundles") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("TP", Object[TableName].Unload());
	
	Query.Text =
	"SELECT
	|	CAST(TP.Products AS Catalog.Products) AS Products,
	|	TP.LineNumber AS LineNumber
	|INTO TP
	|FROM
	|	&TP AS TP
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TP.Products AS Products,
	|	TP.LineNumber AS LineNumber
	|FROM
	|	TP AS TP
	|WHERE
	|	TP.Products.IsBundle";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DriveServer.ShowMessageAboutError(
			Object,
			NStr("en = 'There is a bundle in the table'; ru = 'В таблице есть набор';pl = 'W tabeli jest zestaw';es_ES = 'Hay un paquete en la tabla';es_CO = 'Hay un paquete en la tabla';tr = 'Tabloda bir ürün seti var';it = 'C''è un kit di prodotti nella tabella';de = 'Es gibt eine Artikelgruppe in der Tabelle'"),
			TableName,
			Selection.LineNumber,
			"Products",
			Cancel);
		
	EndDo;
	
EndProcedure

Function BundleAttributes(BundleProduct, BundleCharacteristic) Export
	
	Components = BundlesComponents(BundleProduct, BundleCharacteristic);
	Result = New Structure;
	Result.Insert("BundlesComponents", New Array);
	For Each Row In Components Do
		Component = New Structure("Products, Characteristic, MeasurementUnit, Quantity, CostShare, Order");
		FillPropertyValues(Component, Row);
		Result.BundlesComponents.Add(Component);
	EndDo;
	Result.Insert("BundlePricingStrategy", Common.ObjectAttributeValue(BundleProduct, "BundlePricingStrategy"));
	Return Result;
	
EndFunction

Function BundlesComponents(BundleProduct, BundleCharacteristic) Export
	
	Query = New Query;
	Query.SetParameter("BundleProduct", BundleProduct);
	Query.SetParameter("BundleCharacteristic",
		?(TypeOf(BundleCharacteristic)=Type("CatalogRef.ProductsCharacteristics"), BundleCharacteristic, Catalogs.ProductsCharacteristics.EmptyRef()));
		
	Query.Text =
	"SELECT
	|	BundlesComponents.Products AS Products,
	|	BundlesComponents.Characteristic AS Characteristic,
	|	BundlesComponents.MeasurementUnit AS MeasurementUnit,
	|	BundlesComponents.Quantity AS Quantity,
	|	BundlesComponents.CostShare AS CostShare,
	|	BundlesComponents.Order AS Order
	|FROM
	|	InformationRegister.BundlesComponents AS BundlesComponents
	|WHERE
	|	BundlesComponents.BundleProduct = &BundleProduct
	|	AND (BundlesComponents.BundleCharacteristic = &BundleCharacteristic
	|			OR BundlesComponents.IsCommon
	|				AND BundlesComponents.BundleCharacteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef))
	|
	|GROUP BY
	|	BundlesComponents.Products,
	|	BundlesComponents.Characteristic,
	|	BundlesComponents.MeasurementUnit,
	|	BundlesComponents.CostShare,
	|	BundlesComponents.Order,
	|	BundlesComponents.Quantity
	|
	|ORDER BY
	|	Order";
	Return Query.Execute().Unload();
	
EndFunction

Procedure FillAddedBundles(Object, BasisArray, TableName = "Inventory", QuantityName = "Quantity", ObjectTableName = "Inventory") Export
	
	If BasisArray.Count() > 0 Then
		
		BasisDocument = BasisArray[0];
		DocumentMetadata = BasisDocument.Metadata();
		
		If DocumentMetadata.TabularSections.Find("AddedBundles") <> Undefined Then
			
			Query = New Query;
			Query.Text = 
				"SELECT
				|	DocumentTable.Products AS Products,
				|	DocumentTable.Characteristic AS Characteristic,
				|	DocumentTable.Quantity AS Quantity
				|FROM
				|	Document.SalesInvoice.Inventory AS DocumentTable
				|WHERE
				|	DocumentTable.Ref IN(&Refs)";
			
			Query.Text = StrReplace(Query.Text, "SalesInvoice", DocumentMetadata.Name);
			Query.Text = StrReplace(Query.Text, "Inventory", TableName);
			Query.SetParameter("Refs", BasisArray);
			
			BasisDocumentTable = Query.Execute().Unload();
			
			If IdenticalTables(BasisDocumentTable, Object[ObjectTableName], QuantityName) Then
				
				For Each BasisDocument In BasisArray Do
					
					For Each BundleRow In BasisDocument.AddedBundles Do
						
						NewRow = Object.AddedBundles.Add();
						FillPropertyValues(NewRow, BundleRow);
						
					EndDo;
					
				EndDo;
				
			Else
				
				For Each BundleRow In Object[ObjectTableName] Do
					
					SearchStructure = New Structure();
					SearchStructure.Insert("BundleProduct", BundleRow.BundleProduct);
					SearchStructure.Insert("BundleCharacteristic", BundleRow.BundleCharacteristic);
					
					Rows = Object.AddedBundles.FindRows(SearchStructure);
					
					If Rows.Count() = 0 Then
						NewRow = Object.AddedBundles.Add();
						FillPropertyValues(NewRow, BundleRow);
						NewRow.Quantity = 1;
					EndIf;
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndIf;

EndProcedure

#Region Print

Function AssemblyTableByBundles(Ref, HeaderSelection, TableColumns, LineTotalArea = Undefined) Export
	
	ResultTable = New ValueTable;
	
	// Get table into ResultTable
	
	For Each TableColumn In TableColumns Do
		
		ResultTable.Columns.Add(TableColumn.Name);
		
	EndDo;
	
	ResultTable.Columns.Add("IsBundle");
	
	HasColumnBundleProduct = (TableColumns.Find("BundleProduct") <> Undefined);
	HasBundles = False;
	HasVariants = (TypeOf(Ref) = Type("DocumentRef.Quote"));
	
	If TypeOf(HeaderSelection) = Type("ValueTable") Then
		
		For Each TabSelection In HeaderSelection Do
			
			Row = ResultTable.Add();
			FillPropertyValues(Row, TabSelection);
			Row.IsBundle = False;
			
			If HasColumnBundleProduct And Not HasBundles Then
				HasBundles = ValueIsFilled(TabSelection.BundleProduct);
			EndIf;
			
		EndDo;
		
	Else
	
		TabSelection = HeaderSelection.Select();
		
		While TabSelection.Next() Do
			
			Row = ResultTable.Add();
			FillPropertyValues(Row, TabSelection);
			Row.IsBundle = False;
			
			If HasColumnBundleProduct And Not HasBundles Then
				HasBundles = ValueIsFilled(TabSelection.BundleProduct);
			EndIf;
			
		EndDo;
	
	EndIf;
	// Change bundles
	
	If HasBundles Then
		
		ResultQuantity = ResultTable.Total("Quantity");
		ResultLineNumber = ResultTable.Count();
		
		CalculateDiscount = (TableColumns.Find("DiscountRate") <> Undefined);
		HasQuantityOrdered = (TableColumns.Find("QuantityOrdered") <> Undefined);
		
		If HasQuantityOrdered Then
			ResultQuantityOrdered =  ResultTable.Total("QuantityOrdered");
		EndIf;
		
		For Each Bundle In Ref.AddedBundles Do
			
			BundleDisplayInPrintForms = Common.ObjectAttributeValue(Bundle.BundleProduct, "BundleDisplayInPrintForms");
			
			If BundleDisplayInPrintForms = Enums.ProductBundleDisplay.ComponentsOnly Then
				Continue;
			EndIf;
			
			FilterStructure = New Structure;
			FilterStructure.Insert("BundleProduct",			Bundle.BundleProduct);
			FilterStructure.Insert("BundleCharacteristic",	Bundle.BundleCharacteristic);
			If HasVariants Then
				FilterStructure.Insert("Variant", Bundle.Variant);
			EndIf;
			
			BundleRows = ResultTable.FindRows(FilterStructure);
			
			If BundleRows.Count() = 0 Then
				Continue;
			EndIf;
			
			NewRowIndex = ResultTable.Count();
			BundleSums = EmptyStructureOfNumbersAttributes();
			
			If CalculateDiscount Then
				BundleSums.Insert("Subtotal", 0);
			EndIf;
			
			If HasQuantityOrdered Then
				OrdersArray = New Array;
			EndIf;
			
			For Each BundleRow In BundleRows Do
				
				NewRowIndex = Min(NewRowIndex, ResultTable.IndexOf(BundleRow));
				
				// Totals for bundle row
				RowSumsStructure = EmptyStructureOfNumbersAttributes();
				FillPropertyValues(RowSumsStructure, BundleRow);
				For Each RowSum In RowSumsStructure Do
					If TypeOf(RowSum.Value) = Type("Number") And RowSum.Value <> 0 Then
						BundleSums[RowSum.Key] = BundleSums[RowSum.Key] + RowSum.Value;
					EndIf;
				EndDo;
				
				If CalculateDiscount Then
					BundleSums.Subtotal = BundleSums.Subtotal + (BundleRow.Quantity * BundleRow.Price);
				EndIf;
				
				If HasQuantityOrdered Then
					QuantityOrdered = ?(BundleRow.QuantityOrdered = Null, 0, BundleRow.QuantityOrdered);
					ResultQuantityOrdered =  ResultQuantityOrdered - QuantityOrdered;
				EndIf;
				
				BundleRow.IsBundle = True;
				
				ResultQuantity = ResultQuantity - BundleRow.Quantity;
				ResultLineNumber = ResultLineNumber - 1;
				
			EndDo;
			
			NewRow = ResultTable.Insert(NewRowIndex);
			FillPropertyValues(NewRow, BundleSums);
			NewRow.Quantity = Bundle.Quantity;
			If CalculateDiscount Then
				BundlePrice = ?(NewRow.Quantity = 0, 0, BundleSums.Subtotal / NewRow.Quantity);
				NewRow.Price = Format(BundlePrice, "NFD=2");
			EndIf;
			NewRow.IsBundle = False;
			NewRow.ContentUsed = True;
			NewRow.ProductDescription = Common.ObjectAttributeValue(Bundle.BundleProduct, "Description");
			If ValueIsFilled(Bundle.BundleCharacteristic) Then
				StrCharacteristic = Common.ObjectAttributeValue(Bundle.BundleCharacteristic, "Description");
				NewRow.ProductDescription = NewRow.ProductDescription + " (" + StrCharacteristic + ") ";
			EndIf;
			
			If TableColumns.Find("UOM") <> Undefined Then
				NewRow.UOM = Common.ObjectAttributeValue(Bundle.BundleProduct, "MeasurementUnit");
			ElsIf TableColumns.Find("MeasurementUnit") <> Undefined Then
				NewRow.MeasurementUnit = Common.ObjectAttributeValue(Bundle.BundleProduct, "MeasurementUnit");
			EndIf;
			
			If CalculateDiscount Then
				DiscountRate = ?(BundleSums.Subtotal = 0, 0, BundleSums.DiscountAmount * 100 / BundleSums.Subtotal);
				NewRow.DiscountRate = Format(DiscountRate, "NFD=2");
			EndIf;
			
			If HasQuantityOrdered Then
				NewRow.QuantityOrdered = GetQuantityOrdered(Ref, Bundle.BundleProduct, Bundle.BundleCharacteristic);
				ResultQuantityOrdered =  ResultQuantityOrdered + NewRow.QuantityOrdered;
			EndIf;
			
			If TableColumns.Find("SKU") <> Undefined Then
				NewRow.SKU = Common.ObjectAttributeValue(Bundle.BundleProduct, "SKU");
			EndIf;
			
			ResultQuantity = ResultQuantity + Bundle.Quantity;
			ResultLineNumber = ResultLineNumber + 1;
			
			// If show only bundle
			If BundleDisplayInPrintForms = Enums.ProductBundleDisplay.Bundle Then
				
				If TableColumns.Find("VATRate") <> Undefined Then
					NewRow.VATRate = BundleRows[0].VATRate;
				EndIf;
				
				For Each BundleRow In BundleRows Do
					
					ResultTable.Delete(BundleRow);
					
				EndDo;
				
			EndIf;
			
		EndDo;
		
		If LineTotalArea <> Undefined Then
			
			LineTotalArea.Parameters.LineNumber = ResultLineNumber;
			LineTotalArea.Parameters.Quantity = ResultQuantity;
			
			If HasQuantityOrdered Then
				LineTotalArea.Parameters.QuantityOrdered = ResultQuantityOrdered;
			EndIf;
			
		EndIf;
	
	EndIf;
	
	Return ResultTable;
	
EndFunction

Function GetBundleComponentsColor(TabRow, EmptyColor = Undefined) Export
	
	If EmptyColor = Undefined Then
		EmptyColor = StyleColors.TitleColorSettingsGroup;
	EndIf;
	
	If TabRow.IsBundle Then
		Return StyleColors.PastEvent;
	Else
		Return EmptyColor;
	EndIf;
	
EndFunction

#EndRegion

#EndRegion

#Region Private

Function AreEnteredCharacteristics(Products)
	
	Query = New Query;
	Query.SetParameter("Products", Products);
	Query.Text =
	"SELECT TOP 1
	|	ProductsCharacteristics.Ref AS Ref
	|FROM
	|	Catalog.ProductsCharacteristics AS ProductsCharacteristics
	|WHERE
	|	(ProductsCharacteristics.Owner = &Products
	|			OR ProductsCharacteristics.Owner = CAST(&Products AS Catalog.Products).ProductsCategory)";
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Function EmptyStructureOfNumbersAttributes()
	
	AttributesStructure = "Price, Amount, VATAmount, Total, DiscountAmount, TaxableAmount";
	
	Result = New Structure();
	Attribute = StringFunctionsClientServer.SplitStringIntoSubstringsArray(AttributesStructure);
	
	For Each AttributeName In Attribute Do
		Result.Insert(AttributeName, 0);
	EndDo;
	
	Return Result;
	
EndFunction

Function IdenticalTables(BasisTable, DocumentTable, QuantityName)
	
	If QuantityName <> "Quantity" Then
		CopyDocumentTable = DocumentTable.Unload();
		For Each Row In CopyDocumentTable Do
			Row.Quantity = Row[QuantityName];
		EndDo;
	Else
		CopyDocumentTable = DocumentTable.Unload();
	EndIf;
	
	Return Common.IdenticalCollections(BasisTable, CopyDocumentTable);
	
EndFunction

Function GetQuantityOrdered(Document, BundleProduct, BundleCharacteristic)
	
	Result = 0;
	
	If TypeOf(Document) = Type("DocumentRef.SalesInvoice") Then
		
		Query = New Query;
		Query.Text = 
			"SELECT
			|	MAX(SalesOrderAddedBundles.Quantity) AS Quantity
			|INTO OrderedQuontity
			|FROM
			|	Document.SalesInvoice.Inventory AS DocumentInventory
			|		INNER JOIN Document.SalesOrder.AddedBundles AS SalesOrderAddedBundles
			|		ON DocumentInventory.Order = SalesOrderAddedBundles.Ref
			|WHERE
			|	DocumentInventory.Ref = &Document
			|	AND SalesOrderAddedBundles.BundleProduct = &BundleProduct
			|	AND SalesOrderAddedBundles.BundleCharacteristic = &BundleCharacteristic
			|
			|UNION ALL
			|
			|SELECT
			|	MAX(WorkOrderAddedBundles.Quantity)
			|FROM
			|	Document.SalesInvoice.Inventory AS DocumentInventory
			|		INNER JOIN Document.WorkOrder.AddedBundles AS WorkOrderAddedBundles
			|		ON DocumentInventory.Order = WorkOrderAddedBundles.Ref
			|WHERE
			|	DocumentInventory.Ref = &Document
			|	AND WorkOrderAddedBundles.BundleProduct = &BundleProduct
			|	AND WorkOrderAddedBundles.BundleCharacteristic = &BundleCharacteristic
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	SUM(OrderedQuontity.Quantity) AS Quantity
			|FROM
			|	OrderedQuontity AS OrderedQuontity";
		
		Query.SetParameter("BundleCharacteristic", BundleCharacteristic);
		Query.SetParameter("BundleProduct", BundleProduct);
		Query.SetParameter("Document", Document);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		If SelectionDetailRecords.Next() Then
			Result = ?(SelectionDetailRecords.Quantity = Null, 0, SelectionDetailRecords.Quantity);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.GoodsIssue") Then
		
		Query = New Query;
		Query.Text = 
			"SELECT
			|	MAX(SalesOrderAddedBundles.Quantity) AS Quantity
			|FROM
			|	Document.GoodsIssue.Products AS GoodsIssueProducts
			|		INNER JOIN Document.SalesOrder.AddedBundles AS SalesOrderAddedBundles
			|		ON GoodsIssueProducts.Order = SalesOrderAddedBundles.Ref
			|WHERE
			|	GoodsIssueProducts.Ref = &Document
			|	AND SalesOrderAddedBundles.BundleProduct = &BundleProduct
			|	AND SalesOrderAddedBundles.BundleCharacteristic = &BundleCharacteristic";
		
		Query.SetParameter("BundleCharacteristic", BundleCharacteristic);
		Query.SetParameter("BundleProduct", BundleProduct);
		Query.SetParameter("Document", Document);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		If SelectionDetailRecords.Next() Then
			Result = ?(SelectionDetailRecords.Quantity = Null, 0, SelectionDetailRecords.Quantity);
		EndIf;
	
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion