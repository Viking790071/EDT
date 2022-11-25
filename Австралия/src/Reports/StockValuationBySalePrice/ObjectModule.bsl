#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	
	PeriodDate = Date(1, 1, 1);
	PriceKind = Catalogs.PriceTypes.EmptyRef();
	
	ReportSettings = SettingsComposer.GetSettings();
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("Period"));
	If ParameterPeriod <> Undefined AND ParameterPeriod.Use AND ValueIsFilled(ParameterPeriod.Value) Then
		
		PeriodDate = ParameterPeriod.Value;
		PeriodDate = EndOfDay(PeriodDate);
		
	EndIf;
	
	ParameterPriceKind = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("PriceKind"));
	If ParameterPriceKind <> Undefined AND ParameterPriceKind.Use AND ValueIsFilled(ParameterPriceKind.Value) Then
		
		PriceKind = ParameterPriceKind.Value;
		
	EndIf;
	
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	DriveReports.SetReportAppearanceTemplate(ReportSettings);
	DriveReports.OutputReportTitle(ReportParameters, ResultDocument);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);
	
	ExternalDataSet = New Structure("CalculationTable", GetCalculationTable(PeriodDate, PriceKind));
	
	// Create and initialize a composition processor
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSet, DetailsData, True);
	
	// Create and initialize the result output processor
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	// Indicate the output begin
	OutputProcessor.BeginOutput();
	TableFixed = False;
	
	ResultDocument.FixedTop = 0;
	// Main cycle of the report output
	While True Do
		// Get the next item of a composition result 
		ResultItem = CompositionProcessor.Next();
		
		If ResultItem = Undefined Then
			// The next item is not received - end the output cycle
			Break;
		Else
			// Fix header
			If NOT TableFixed 
				AND ResultItem.ParameterValues.Count() > 0
				AND TypeOf(SettingsComposer.Settings.Structure[0]) <> Type("DataCompositionChart") Then
				
				TableFixed = True;
				ResultDocument.FixedTop = ResultDocument.TableHeight;
				
			EndIf;
			
			// Item is received - output it using an output processor
			OutputProcessor.OutputItem(ResultItem);
			
		EndIf;
	EndDo;
	
	OutputProcessor.EndOutput();
	
EndProcedure

#EndRegion

#Region Private

Function PrepareReportParameters(ReportSettings)
	
	Period = Date(1,1,1);
	TitleOutput = False;
	Title = NStr("en = 'Stock valuation by a sale price'; ru = 'Товары в ценах продажи';pl = 'Wartość zapasów według ceny sprzedaży';es_ES = 'Valor del stock a precios de venta';es_CO = 'Valor del stock a precios de venta';tr = 'Satış fiyatına göre ambar stok değerlemesi';it = 'Valutazione scorte per prezzo di vendita';de = 'Bestandsbewertung durch einen Verkaufspreis'");
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("Period"));
	If ParameterPeriod <> Undefined AND ParameterPeriod.Use AND ValueIsFilled(ParameterPeriod.Value) Then
		Period = ParameterPeriod.Value;
	EndIf;
	
	ParameterOutputTitle = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("TitleOutput"));
	If ParameterOutputTitle <> Undefined AND ParameterOutputTitle.Use Then
		TitleOutput = ParameterOutputTitle.Value;
	EndIf;
	
	OutputParameter = ReportSettings.OutputParameters.FindParameterValue(New DataCompositionParameter("Title"));
	If OutputParameter <> Undefined AND OutputParameter.Use Then
		Title = OutputParameter.Value;
	EndIf;
	
	ReportParameters = New Structure;
	ReportParameters.Insert("Period",			Period);
	ReportParameters.Insert("TitleOutput",		TitleOutput);
	ReportParameters.Insert("Title",			Title);
	ReportParameters.Insert("ReportId",			"StockValuationBySalePrice");
	ReportParameters.Insert("ReportSettings",	ReportSettings);
	
	Return ReportParameters;
	
EndFunction

Function GetCalculationTable(Period, PriceKind)
	
	Query = New Query;
	Query.SetParameter("Period", Period);
	
	PriceKindAttributes = Common.ObjectAttributesValues(PriceKind,
		"PriceCalculationMethod,CalculatesDynamically,PricesBaseKind,Percent");
	
	If PriceKindAttributes.PriceCalculationMethod = Enums.PriceCalculationMethods.Formula Then
		
		Query.SetParameter("PriceKind", PriceKind);
		
		DataStructure = New Structure("PriceKind, MeasurementUnit, Products, Characteristic");
		
		Query.Text =
		"SELECT ALLOWED
		|	InventoryInWarehousesBalance.StructuralUnit AS StructuralUnit,
		|	InventoryInWarehousesBalance.Products AS Products,
		|	InventoryInWarehousesBalance.Characteristic AS Characteristic,
		|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
		|	&PriceKind AS PriceKind,
		|	InventoryInWarehousesBalance.QuantityBalance AS QuantityBalance,
		|	0 AS AmountBalance
		|FROM
		|	AccumulationRegister.InventoryInWarehouses.Balance(&Period, ) AS InventoryInWarehousesBalance
		|		LEFT JOIN Catalog.Products AS CatalogProducts
		|		ON InventoryInWarehousesBalance.Products = CatalogProducts.Ref";
		
		CalculationTable = Query.Execute().Unload();
		
		For Each Row In CalculationTable Do
			
			FillPropertyValues(DataStructure, Row);
			
			Price = PriceGenerationFormulaServerCall.GetPriceByFormula(DataStructure);
			
			Row.AmountBalance = DriveClientServer.RoundPrice(Row.QuantityBalance * Price, Enums.RoundingMethods.Round0_01);
			
		EndDo;
		
	Else
		
		If PriceKindAttributes.CalculatesDynamically Then
			PriceKindParameter = PriceKindAttributes.PricesBaseKind;
			Markup = PriceKindAttributes.Percent;
		Else
			PriceKindParameter = PriceKind;
			Markup = 0;
		EndIf;
		
		Query.Text =
		"SELECT ALLOWED
		|	InventoryInWarehousesBalance.StructuralUnit AS StructuralUnit,
		|	InventoryInWarehousesBalance.Products AS Products,
		|	InventoryInWarehousesBalance.Characteristic AS Characteristic,
		|	InventoryInWarehousesBalance.QuantityBalance AS QuantityBalance,
		|	0 AS Price
		|INTO InventoryTable
		|FROM
		|	AccumulationRegister.InventoryInWarehouses.Balance(&Period, ) AS InventoryInWarehousesBalance
		|
		|INDEX BY
		|	Products,
		|	Characteristic
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	PricesTable.Products AS Products,
		|	PricesTable.Characteristic AS Characteristic,
		|	PricesTable.Price * ISNULL(UOM.Factor, 1) AS Price
		|INTO PriceTable
		|FROM
		|	(SELECT
		|		PricesSliceLast.Price * (1 + &Markup / 100) AS Price,
		|		PricesSliceLast.Products AS Products,
		|		PricesSliceLast.Characteristic AS Characteristic,
		|		PricesSliceLast.MeasurementUnit AS MeasurementUnit
		|	FROM
		|		InformationRegister.Prices.SliceLast(&Period, PriceKind = &PriceKind) AS PricesSliceLast) AS PricesTable
		|		LEFT JOIN Catalog.UOM AS UOM
		|		ON PricesTable.MeasurementUnit = UOM.Ref
		|
		|INDEX BY
		|	Products,
		|	Characteristic
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	PricesTable.Products AS Products,
		|	PricesTable.Price * ISNULL(UOM.Factor, 1) AS Price
		|INTO CommonPriceTable
		|FROM
		|	(SELECT
		|		PricesSliceLast.Price * (1 + &Markup / 100) AS Price,
		|		PricesSliceLast.Products AS Products,
		|		PricesSliceLast.MeasurementUnit AS MeasurementUnit
		|	FROM
		|		InformationRegister.Prices.SliceLast(
		|				&Period,
		|				PriceKind = &PriceKind
		|					AND Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)) AS PricesSliceLast) AS PricesTable
		|		LEFT JOIN Catalog.UOM AS UOM
		|		ON PricesTable.MeasurementUnit = UOM.Ref
		|
		|INDEX BY
		|	Products
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	InventoryTable.StructuralUnit AS StructuralUnit,
		|	InventoryTable.Products AS Products,
		|	InventoryTable.Characteristic AS Characteristic,
		|	InventoryTable.QuantityBalance AS QuantityBalance,
		|	InventoryTable.QuantityBalance * ISNULL(PriceTable.Price, ISNULL(CommonPriceTable.Price, InventoryTable.Price)) AS AmountBalance
		|FROM
		|	InventoryTable AS InventoryTable
		|		LEFT JOIN PriceTable AS PriceTable
		|		ON InventoryTable.Products = PriceTable.Products
		|			AND InventoryTable.Characteristic = PriceTable.Characteristic
		|		LEFT JOIN CommonPriceTable AS CommonPriceTable
		|		ON InventoryTable.Products = CommonPriceTable.Products";
		
		Query.SetParameter("Markup", Markup);
		Query.SetParameter("PriceKind", PriceKindParameter);
		
		CalculationTable = Query.Execute().Unload();
		
	EndIf;
	
	Return CalculationTable;
	
EndFunction

#EndRegion

#EndIf