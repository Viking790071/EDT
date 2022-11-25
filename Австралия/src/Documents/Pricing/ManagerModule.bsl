#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRef, StructureAdditionalProperties) Export
	
	Query = New Query();
	Query.Text =
	"SELECT ALLOWED
	|	CASE
	|		WHEN Pricing.PricePeriod = DATETIME(1, 1, 1)
	|			THEN BEGINOFPERIOD(Pricing.Date, DAY)
	|		ELSE BEGINOFPERIOD(Pricing.PricePeriod, DAY)
	|	END AS Period,
	|	Pricing.Author AS Author,
	|	Pricing.PriceKind AS PriceKind,
	|	Pricing.Ref AS Ref
	|INTO PricingTable
	|FROM
	|	Document.Pricing AS Pricing
	|WHERE
	|	Pricing.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PricingInventory.Products AS Products,
	|	PricingInventory.Characteristic AS Characteristic,
	|	PricingInventory.MeasurementUnit AS MeasurementUnit,
	|	PricingInventory.Price AS Price,
	|	PricingTable.Period AS Period,
	|	PricingTable.Author AS Author,
	|	PricingTable.PriceKind AS PriceKind
	|INTO PricingInventoryTable
	|FROM
	|	Document.Pricing.Inventory AS PricingInventory
	|		INNER JOIN PricingTable AS PricingTable
	|		ON PricingInventory.Ref = PricingTable.Ref
	|WHERE
	|	PricingInventory.Price > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PricingInventoryTable.Products AS Products,
	|	PricingInventoryTable.Characteristic AS Characteristic,
	|	PricingInventoryTable.MeasurementUnit AS MeasurementUnit,
	|	PricingInventoryTable.Price AS Price,
	|	PricingInventoryTable.Period AS Period,
	|	PricingInventoryTable.Author AS Author,
	|	PricingInventoryTable.PriceKind AS PriceKind
	|FROM
	|	PricingInventoryTable AS PricingInventoryTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Prices.Products AS Products,
	|	Prices.Characteristic AS Characteristic,
	|	PricingInventoryTable.Period AS Period
	|FROM
	|	PricingInventoryTable AS PricingInventoryTable
	|		INNER JOIN InformationRegister.Prices AS Prices
	|		ON PricingInventoryTable.Products = Prices.Products
	|			AND PricingInventoryTable.Characteristic = Prices.Characteristic
	|			AND PricingInventoryTable.Period = Prices.Period
	|			AND PricingInventoryTable.PriceKind = Prices.PriceKind
	|WHERE
	|	Prices.Recorder <> &Ref";
	
	Query.SetParameter("Ref", DocumentRef);
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePrices", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAreadyExists", ResultsArray[3].Unload());
	
EndProcedure

Procedure CheckBeforePosting(DocumentObjectPricing, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	TableAreadyExists = AdditionalProperties.TableForRegisterRecords.TableAreadyExists;
	MessageTemplate = NStr("en = 'There is a price effective on the same date %1 for %2. The new price is not set.'; ru = 'Для %2 уже установлена цена на дату %1. Новая цена установлена не будет.';pl = 'W tym samym dniu obowiązuje cena %1 dla %2. Nowa cena nie jest ustalona.';es_ES = 'Existe un precio efectivo en la misma fecha%1 para %2 El nuevo precio no está fijado.';es_CO = 'Existe un precio efectivo en la misma fecha%1 para %2 El nuevo precio no está fijado.';tr = '%2 için aynı %1 tarihinde geçerli bir fiyat var. Yeni fiyat belirlenmedi.';it = 'C''è un prezzo che ha effetto alla stessa data %1 per %2. Il nuovo prezzo non è impostato.';de = 'Es gibt einen Preis, der am gleichen Tag %1 für %2 gültig ist. Der neue Preis wird nicht festgelegt.'");
	
	For Each Row In TableAreadyExists Do
		
		If ValueIsFilled(Row.Characteristic) Then
			MessageText = StrReplace(MessageTemplate, "%2", "%2 (%3)");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				MessageText,
				Format(Row.Period, "DLF=D"),
				Row.Products,
				Row.Characteristic);
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				MessageTemplate,
				Format(Row.Period, "DLF=D"),
				Row.Products);
		EndIf;
		
		CommonClientServer.MessageToUser(MessageText, , , ,Cancel);
		
	EndDo;
	
EndProcedure

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

#EndIf