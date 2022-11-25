#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Writes to the Counterparties products prices information register.
//
Procedure RecordVendorPrices(DocumentRefSupplierQuote) Export

	If DocumentRefSupplierQuote.Posted Then
		DriveServer.DeleteVendorPrices(DocumentRefSupplierQuote);
	EndIf;
	
	If Not ValueIsFilled(DocumentRefSupplierQuote.SupplierPriceTypes) Then
		Return;
	EndIf;
	
	StructureDataSupplierQuote = Common.ObjectAttributesValues(DocumentRefSupplierQuote, 
		"Date, SupplierPriceTypes, Counterparty, DocumentCurrency, Company, RegisterVendorPrices");
	
	If Not StructureDataSupplierQuote.RegisterVendorPrices Then	
		Return;	
	EndIf; 
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	TablePrices.Ref.Date AS Period,
	|	TablePrices.Ref.SupplierPriceTypes AS SupplierPriceTypes,
	|	TablePrices.Products AS Products,
	|	TablePrices.Characteristic AS Characteristic,
	|	MAX(CASE
	|			WHEN TablePrices.Ref.AmountIncludesVAT = TablePrices.Ref.SupplierPriceTypes.PriceIncludesVAT
	|				THEN ISNULL(TablePrices.Price * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition / (RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition)
	|						END, 0)
	|			WHEN TablePrices.Ref.AmountIncludesVAT > TablePrices.Ref.SupplierPriceTypes.PriceIncludesVAT
	|				THEN ISNULL(TablePrices.Price * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition / (RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition)
	|						END * 100 / (100 + TablePrices.VATRate.Rate), 0)
	|			ELSE ISNULL(TablePrices.Price * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition / (RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition)
	|					END * (100 + TablePrices.VATRate.Rate) / 100, 0)
	|		END) AS Price,
	|	TablePrices.MeasurementUnit AS MeasurementUnit,
	|	TRUE AS Actuality,
	|	TablePrices.Ref AS DocumentRecorder,
	|	TablePrices.Ref.Author AS Author,
	|	SupplierQuote.Counterparty AS Counterparty
	|FROM
	|	Document.SupplierQuote.Inventory AS TablePrices
	|		LEFT JOIN InformationRegister.CounterpartyPrices AS CounterpartyPrices
	|		ON TablePrices.Ref.SupplierPriceTypes = CounterpartyPrices.SupplierPriceTypes
	|			AND TablePrices.Ref.Counterparty = CounterpartyPrices.Counterparty
	|			AND TablePrices.Products = CounterpartyPrices.Products
	|			AND TablePrices.Characteristic = CounterpartyPrices.Characteristic
	|			AND (BEGINOFPERIOD(TablePrices.Ref.Date, DAY) = CounterpartyPrices.Period)
	|			AND TablePrices.Ref.Date <= CounterpartyPrices.DocumentRecorder.Date
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&ProcessingDate, Company = &Company) AS RateCurrencyTypePrices
	|		ON TablePrices.Ref.SupplierPriceTypes.PriceCurrency = RateCurrencyTypePrices.Currency
	|		LEFT JOIN Document.SupplierQuote AS SupplierQuote
	|		ON TablePrices.Ref = SupplierQuote.Ref,
	|	InformationRegister.ExchangeRate.SliceLast(
	|			&ProcessingDate,
	|			Currency = &DocumentCurrency
	|				AND Company = &Company) AS DocumentCurrencyRate
	|WHERE
	|	TablePrices.Ref.RegisterVendorPrices
	|	AND CounterpartyPrices.SupplierPriceTypes IS NULL
	|	AND TablePrices.Ref = &Ref
	|	AND TablePrices.Price <> 0
	|
	|GROUP BY
	|	TablePrices.Products,
	|	TablePrices.Characteristic,
	|	TablePrices.MeasurementUnit,
	|	TablePrices.Ref.Date,
	|	TablePrices.Ref.SupplierPriceTypes,
	|	TablePrices.Ref,
	|	TablePrices.Ref.Author,
	|	SupplierQuote.Counterparty";
	
	Query.SetParameter("Ref", 					DocumentRefSupplierQuote);
	Query.SetParameter("DocumentCurrency", 		StructureDataSupplierQuote.DocumentCurrency);
	Query.SetParameter("ProcessingDate", 		StructureDataSupplierQuote.Date);
	Query.SetParameter("Company", 				StructureDataSupplierQuote.Company);
	Query.SetParameter("ExchangeRateMethod", 	DriveServer.GetExchangeMethod(StructureDataSupplierQuote.Company));
	
	QueryResult = Query.Execute();
	RecordsTable = QueryResult.Unload();
	
	For Each TableRow In RecordsTable Do
		NewRecord = InformationRegisters.CounterpartyPrices.CreateRecordManager();
		FillPropertyValues(NewRecord, TableRow);
		NewRecord.Write();
	EndDo;

EndProcedure

#Region LibrariesHandlers

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	GLAccountsForFilling = New Structure;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#EndRegion

#EndIf