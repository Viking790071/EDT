#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefPlanSales, StructureAdditionalProperties) Export

	Query = New Query;
	Query.Text =
	"SELECT
	|	PlanSalesInventory.PlanningDate AS Period,
	|	&Company AS Company,
	|	PlanSalesInventory.Ref.StructuralUnit AS StructuralUnit,
	|	PlanSalesInventory.Ref.SalesGoalSetting AS SalesGoalSetting,
	|	PlanSalesInventory.SalesRep AS SalesRep,
	|	PlanSalesInventory.SalesTerritory AS SalesTerritory,
	|	PlanSalesInventory.Project AS Project,
	|	PlanSalesInventory.ProductCategory AS ProductCategory,
	|	PlanSalesInventory.ProductGroup AS ProductGroup,
	|	PlanSalesInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PlanSalesInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	PlanSalesInventory.Ref AS PlanningDocument,
	|	CASE
	|		WHEN VALUETYPE(PlanSalesInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN PlanSalesInventory.Quantity
	|		ELSE PlanSalesInventory.Quantity * PlanSalesInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CAST(PlanSalesInventory.Amount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfDocument.Rate * AccountingCurrencyRate.Repetition / (AccountingCurrencyRate.Rate * ExchangeRateOfDocument.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfDocument.Rate * AccountingCurrencyRate.Repetition / (AccountingCurrencyRate.Rate * ExchangeRateOfDocument.Repetition))
	|		END AS NUMBER(15, 2)) AS Amount
	|FROM
	|	Document.SalesTarget.Inventory AS PlanSalesInventory
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS ExchangeRateOfDocument
	|		ON PlanSalesInventory.Ref.DocumentCurrency = ExchangeRateOfDocument.Currency
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency AND Company = &Company) AS AccountingCurrencyRate
	|		ON (TRUE)
	|WHERE
	|	PlanSalesInventory.Ref = &Ref
	|	AND (PlanSalesInventory.Quantity > 0
	|			OR PlanSalesInventory.Amount > 0)
	|
	|ORDER BY
	|	PlanSalesInventory.LineNumber";
	
	Query.SetParameter("Ref", 					DocumentRefPlanSales);
	Query.SetParameter("PointInTime", 			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", 				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", 	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseCharacteristics", 	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("ExchangeRateMethod", 	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);	
	
	Result = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSalesTarget", Result);
	
EndProcedure

Procedure GetFillingData(Parameters, ResultAddress) Export
	
	Schema = Documents.SalesTarget.GetTemplate(Parameters.SchemaName);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	DataCompositionTemplate = TemplateComposer.Execute(
		Schema,
		Parameters.DataCompositionSettings,,,
		Type("DataCompositionValueCollectionTemplateGenerator"));
		
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(DataCompositionTemplate, , , True);
	
	Result = New ValueTable;
	OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
	OutputProcessor.SetObject(Result);
	OutputProcessor.Output(CompositionProcessor);
	
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	GLAccountsForFilling = New Structure;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#EndRegion

#EndIf