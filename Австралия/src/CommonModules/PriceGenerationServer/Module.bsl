#Region Public

Function RecalculationMeasurementUnits(MeasurementUnitSource, MeasurementUnitReceiver, IsResultString = False) Export
	
	FactorSource = 0;
	If TypeOf(MeasurementUnitSource) = Type("CatalogRef.UOMClassifier") Then
		
		FactorSource = 1;
		
	ElsIf TypeOf(MeasurementUnitSource) = Type("CatalogRef.UOM") Then
		
		FactorSource = MeasurementUnitSource.Factor;
		
	EndIf;
	
	If FactorSource = 0 Then
		
		FactorSource = 1;
		
	EndIf;
	
	FactorReceiver = 0;
	If TypeOf(MeasurementUnitReceiver) = Type("CatalogRef.UOMClassifier") Then
		
		FactorReceiver = 1;
		
	ElsIf TypeOf(MeasurementUnitReceiver) = Type("CatalogRef.UOM") Then
		
		FactorReceiver = MeasurementUnitReceiver.Factor;
		
	EndIf;
	
	If FactorReceiver = 0 Then
		
		FactorReceiver = 1;
		
	EndIf;
	
	If IsResultString Then
		
		Return Format(FactorReceiver / FactorSource, "ND=20; NFD=8; NDS=.; NG=");
		
	Else
		
		Return FactorReceiver / FactorSource;
		
	EndIf;
	
EndFunction

Function ExistRecordAboutPrice(RecordKey) Export
	
	ReturnStructure = New Structure("ExistRecord, Period, PriceType, Products, Characteristic, Recorder", False);
	FillPropertyValues(ReturnStructure, RecordKey);
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	Prices.Period AS Period,
	|	Prices.PriceKind AS PriceKind,
	|	Prices.Products AS Products,
	|	Prices.Characteristic AS Characteristic,
	|	Prices.MeasurementUnit AS MeasurementUnit,
	|	Prices.Price AS Price,
	|	Prices.Recorder AS Recorder
	|FROM
	|	InformationRegister.Prices AS Prices
	|WHERE
	|	Prices.Period = &Period
	|	AND Prices.PriceKind = &PriceKind
	|	AND Prices.Products = &Products
	|	AND Prices.Characteristic = &Characteristic";
	
	Query.SetParameter("Period", BegOfDay(RecordKey.Period));
	Query.SetParameter("PriceKind", RecordKey.PriceType);
	Query.SetParameter("Products", RecordKey.Products);
	Query.SetParameter("Characteristic", RecordKey.Characteristic);
	
	ResultTable = Query.Execute().Unload();
	
	ReturnStructure.ExistRecord = (ResultTable.Count() > 0);
	ReturnStructure.Recorder = ?(ResultTable.Count() > 0, ResultTable[0].Recorder, Undefined);
	
	Return ReturnStructure;
	
EndFunction

#Region CalculationFormulas

Procedure PricesValuesToTableOperands(Period, TableOperands, RegisterRecordsFromPeriod) Export
	
	If TableOperands.Columns.Find("Value") = Undefined Then
		
		TableOperands.Columns.Add("Value");
		
	EndIf;
	
	If TableOperands.Columns.Find("KeyConnection") = Undefined Then
		
		TableOperands.Columns.Add("KeyConnection");
		
	EndIf;
	
	QueryTextTemplate_ProductsPrice = DriveClientServer.GetQueryDelimeter() + 
		"SELECT ALLOWED
		|	ProductsPricesTable.PriceType AS PriceType,
		|	CatalogPriceTypes.OperandID AS ID,
		|	ProductsPricesTable.Products AS Products,
		|	ProductsPricesTable.Characteristic AS Characteristic,
		|	ProductsPricesTable.MeasurementUnit AS MeasurementUnit,
		|	ProductsPricesTable.Value AS Value,
		|	&ExchangeRate AS ExchangeRate,
		|	&Multiplicity AS Multiplicity
		|FROM
		|	(SELECT
		|		&OperandID AS PriceType,
		|		ProductsCharacteristics.Products AS Products,
		|		ProductsCharacteristics.Characteristic AS Characteristic,
		|		ISNULL(PricesSliceLast.MeasurementUnit, CommonPrices.MeasurementUnit) AS MeasurementUnit,
		|		ISNULL(PricesSliceLast.Price, CommonPrices.Price) AS Value
		|	FROM
		|		ProductsCharacteristics AS ProductsCharacteristics
		|			LEFT JOIN InformationRegister.Prices.SliceLast(&Period, PriceKind = &OperandID) AS PricesSliceLast
		|			ON ProductsCharacteristics.Products = PricesSliceLast.Products
		|				AND ProductsCharacteristics.Characteristic = PricesSliceLast.Characteristic
		|			LEFT JOIN InformationRegister.Prices.SliceLast(
		|					&Period,
		|					PriceKind = &OperandID
		|						AND Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)) AS CommonPrices
		|			ON ProductsCharacteristics.Products = CommonPrices.Products
		|	WHERE
		|		(NOT PricesSliceLast.Products IS NULL
		|				OR NOT CommonPrices.Products IS NULL)) AS ProductsPricesTable
		|		LEFT JOIN Catalog.PriceTypes AS CatalogPriceTypes
		|		ON ProductsPricesTable.PriceType = CatalogPriceTypes.Ref";
	
	QueryTextTemplate_SupplierPrice = DriveClientServer.GetQueryDelimeter() + 
		"SELECT ALLOWED
		|	ProductsPricesTable.PriceType AS PriceType,
		|	CatalogSupplierPriceTypes.OperandID AS ID,
		|	ProductsPricesTable.Products AS Products,
		|	ProductsPricesTable.Characteristic AS Characteristic,
		|	ProductsPricesTable.MeasurementUnit AS MeasurementUnit,
		|	ProductsPricesTable.Value AS Value,
		|	&ExchangeRate AS ExchangeRate,
		|	&Multiplicity AS Multiplicity
		|FROM
		|	(SELECT
		|		&OperandID AS PriceType,
		|		ProductsCharacteristics.Products AS Products,
		|		ProductsCharacteristics.Characteristic AS Characteristic,
		|		ISNULL(CounterpartyPricesSliceLast.MeasurementUnit, CommonPrices.MeasurementUnit) AS MeasurementUnit,
		|		ISNULL(CounterpartyPricesSliceLast.Price, CommonPrices.Price) AS Value
		|	FROM
		|		ProductsCharacteristics AS ProductsCharacteristics
		|			LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast(
		|					&Period,
		|					Actuality
		|						AND SupplierPriceTypes = &OperandID) AS CounterpartyPricesSliceLast
		|			ON ProductsCharacteristics.Products = CounterpartyPricesSliceLast.Products
		|				AND ProductsCharacteristics.Characteristic = CounterpartyPricesSliceLast.Characteristic
		|			LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast(
		|					&Period,
		|					Actuality
		|						AND SupplierPriceTypes = &OperandID
		|						AND Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)) AS CommonPrices
		|			ON ProductsCharacteristics.Products = CommonPrices.Products
		|	WHERE
		|		(NOT CounterpartyPricesSliceLast.Products IS NULL
		|				OR NOT CommonPrices.Products IS NULL)) AS ProductsPricesTable
		|		LEFT JOIN Catalog.SupplierPriceTypes AS CatalogSupplierPriceTypes
		|		ON ProductsPricesTable.PriceType = CatalogSupplierPriceTypes.Ref";
	
	QueryByPrices = New Query;
	QueryByPrices.SetParameter("Period", Period);
	QueryByPrices.SetParameter("RegisterRecordsFromPeriod", RegisterRecordsFromPeriod);
	
	QueryByPrices.Text = 
	"SELECT
	|	RegisterRecordsFromPeriod.Products AS Products,
	|	RegisterRecordsFromPeriod.Characteristic AS Characteristic
	|INTO ProductsCharacteristics
	|FROM
	|	&RegisterRecordsFromPeriod AS RegisterRecordsFromPeriod
	|WHERE
	|	RegisterRecordsFromPeriod.IsNeedNewCalculation = TRUE
	|
	|INDEX BY
	|	Products,
	|	Characteristic";
	
	QueryResultIndex = 1;
	For Each RowTable In TableOperands Do
		
		If RowTable.ThisIsProductsPrice = True Then
			
			QueryTextTemplate = QueryTextTemplate_ProductsPrice;
			
		ElsIf RowTable.ThisIsProductsPrice = False Then
			
			QueryTextTemplate = QueryTextTemplate_SupplierPrice;
			
		Else
			
			Continue;
			
		EndIf;
		
		QueryByPrices.SetParameter(RowTable.PriceType.OperandID, RowTable.PriceType);
		QueryByPrices.SetParameter("ExchangeRate", RowTable.PriceTypeExchangeRate);
		QueryByPrices.SetParameter("Multiplicity", RowTable.PriceTypeMultiplicity);
		QueryByPrices.Text = QueryByPrices.Text + StrReplace(QueryTextTemplate, "&OperandID", "&" + RowTable.PriceType.OperandID);
		
		RowTable.KeyConnection = QueryResultIndex;
		QueryResultIndex = QueryResultIndex + 1;
		
	EndDo;
	
	QueryResult = QueryByPrices.ExecuteBatch();
	For Each RowTable In TableOperands Do
		
		If RowTable.KeyConnection = Undefined Then
			
			Continue;
			
		EndIf;
		
		RowTable.Value = QueryResult[RowTable.KeyConnection].Unload();
		
	EndDo;
	
	TableOperands.Columns.Delete("KeyConnection");
	
EndProcedure

#EndRegion

#EndRegion