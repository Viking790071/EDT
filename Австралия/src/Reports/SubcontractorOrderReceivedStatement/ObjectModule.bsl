
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

// Event handler OnResultCompose
//
Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	StandardProcessing = False;
	
	ReportSettings = SettingsComposer.GetSettings();
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	DriveReports.SetReportAppearanceTemplate(ReportSettings);
	DriveReports.OutputReportTitle(ReportParameters, ResultDocument);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);

	DataCompositionParameterValue = CompositionTemplate.ParameterValues.Find("EndOfPeriod");
	If DataCompositionParameterValue = Undefined Then
		NewParameterValue = CompositionTemplate.ParameterValues.Add();
		NewParameterValue.Name = "EndOfPeriod";
		NewParameterValue.Value = Date(3999,12,31,23,59,59);
	EndIf;
	
	// Create and initialize a composition processor
	BeginOfPeriod = CompositionTemplate.ParameterValues["BeginOfPeriod"].Value;
	EndOfPeriod = CompositionTemplate.ParameterValues["EndOfPeriod"].Value;
	ExternalDataSets = New Structure("BOMLevelsTable", GetExternalDataSets(BeginOfPeriod, EndOfPeriod));
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData, True);

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
			If  Not TableFixed 
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
	
	BeginOfPeriod = Date(1,1,1);
	EndOfPeriod  = Date(1,1,1);
	TitleOutput = False;
	Title = NStr("en = 'Subcontractor order received analysis'; ru = 'Анализ полученного заказа на переработку';pl = 'Analiza otrzymanych zamówień od podwykonawcy';es_ES = 'Análisis de la orden recibida del subcontratista';es_CO = 'Análisis de la orden recibida del subcontratista';tr = 'Alınan alt yüklenici siparişi analizi';it = 'Analisi ordine di subfornitura ricevuto';de = 'Analyse Subunternehmerauftrag erhalten'");
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("Period"));
	If ParameterPeriod <> Undefined AND ParameterPeriod.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
		If ParameterPeriod.Use
			AND ValueIsFilled(ParameterPeriod.Value) Then
			
			BeginOfPeriod = ParameterPeriod.Value.StartDate;
			EndOfPeriod  = ParameterPeriod.Value.EndDate;
		EndIf;
	EndIf;
	
	ParameterOutputTitle = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("TitleOutput"));
	If ParameterOutputTitle <> Undefined
		AND ParameterOutputTitle.Use Then
		
		TitleOutput = ParameterOutputTitle.Value;
	EndIf;
	
	OutputParameter = ReportSettings.OutputParameters.FindParameterValue(New DataCompositionParameter("Title"));
	If OutputParameter <> Undefined
		AND OutputParameter.Use Then
		Title = OutputParameter.Value;
	EndIf;
	
	ReportParameters = New Structure;
	ReportParameters.Insert("BeginOfPeriod", BeginOfPeriod);
	ReportParameters.Insert("EndOfPeriod", EndOfPeriod);
	ReportParameters.Insert("TitleOutput", TitleOutput);
	ReportParameters.Insert("Title", Title);
	ReportParameters.Insert("ReportId", "SubcontractorOrderReceivedStatement");
	ReportParameters.Insert("ReportSettings", ReportSettings);
	
	Return ReportParameters;
	
EndFunction

Function GetExternalDataSets(BeginOfPeriod, EndOfPeriod)
	
	MaxNumberOfBOMLevels = Constants.MaxNumberOfBOMLevels.Get();
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SubcontractorOrdersReceivedTurnovers.Company AS Company,
	|	SubcontractorOrdersReceivedTurnovers.SubcontractorOrder AS SubcontractorOrder,
	|	ProductionOrder.Ref AS ProductionOrder,
	|	SubcontractorOrdersReceivedTurnovers.Products AS Products,
	|	SubcontractorOrdersReceivedTurnovers.Characteristic AS Characteristic
	|INTO TT_Orders
	|FROM
	|	AccumulationRegister.SubcontractorOrdersReceived.Turnovers(&BeginOfPeriod, &EndOfPeriod, , ) AS SubcontractorOrdersReceivedTurnovers
	|		INNER JOIN Document.ProductionOrder AS ProductionOrder
	|		ON SubcontractorOrdersReceivedTurnovers.SubcontractorOrder = ProductionOrder.SalesOrder
	|			AND (NOT ProductionOrder.DeletionMark)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_Orders.Products AS ParentProduct,
	|	TT_Orders.Characteristic AS ParentCharacteristic,
	|	TT_Orders.SubcontractorOrder AS SubcontractorOrder,
	|	TT_Orders.Company AS Company,
	|	TT_Orders.ProductionOrder AS ProductionOrder,
	|	BillsOfMaterialsContent.Products AS Products,
	|	BillsOfMaterialsContent.Characteristic AS Characteristic,
	|	BillsOfMaterialsContent.Specification AS Specification
	|INTO LevelTable_1
	|FROM
	|	TT_Orders AS TT_Orders
	|		INNER JOIN Document.ProductionOrder.Products AS ProductionOrderProducts
	|		ON TT_Orders.ProductionOrder = ProductionOrderProducts.Ref
	|			AND TT_Orders.Products = ProductionOrderProducts.Products
	|			AND TT_Orders.Characteristic = ProductionOrderProducts.Characteristic
	|		INNER JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON (ProductionOrderProducts.Specification = BillsOfMaterialsContent.Ref)
	|			AND (BillsOfMaterialsContent.ManufacturedInProcess)";
	
	QueryTextFragment1 = "";
	QueryTextFragment2 = DriveClientServer.GetQueryDelimeter() + "
		|SELECT
		|	LevelTable.ParentProduct AS ParentProduct,
		|	LevelTable.ParentCharacteristic AS ParentCharacteristic,
		|	LevelTable.SubcontractorOrder AS SubcontractorOrder,
		|	LevelTable.Company AS Company,
		|	LevelTable.ProductionOrder AS ProductionOrder,
		|	LevelTable.Products AS Products,
		|	LevelTable.Characteristic AS Characteristic
		|INTO LevelTable
		|FROM
		|	LevelTable_1 AS LevelTable";
	
	For i = 2 To MaxNumberOfBOMLevels Do
		
		Text1 = DriveClientServer.GetQueryDelimeter() + "
			|SELECT
			|	LevelTable.ParentProduct AS ParentProduct,
			|	LevelTable.ParentCharacteristic AS ParentCharacteristic,
			|	LevelTable.SubcontractorOrder AS SubcontractorOrder,
			|	LevelTable.Company AS Company,
			|	LevelTable.ProductionOrder AS ProductionOrder,
			|	BillsOfMaterialsContent.Products AS Products,
			|	BillsOfMaterialsContent.Characteristic AS Characteristic,
			|	BillsOfMaterialsContent.Specification AS Specification
			|INTO %1
			|FROM
			|	%2 AS LevelTable
			|		INNER JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
			|		ON LevelTable.Specification = BillsOfMaterialsContent.Ref
			|			AND (BillsOfMaterialsContent.ManufacturedInProcess)";
		
		QueryTextFragment1 = QueryTextFragment1 + StrTemplate(Text1, "LevelTable_" + String(i), "LevelTable_" + String(i-1));
		
		Text2 = DriveClientServer.GetQueryUnion() + "
			|SELECT
			|	LevelTable.ParentProduct,
			|	LevelTable.ParentCharacteristic,
			|	LevelTable.SubcontractorOrder,
			|	LevelTable.Company AS Company,
			|	LevelTable.ProductionOrder,
			|	LevelTable.Products,
			|	LevelTable.Characteristic
			|FROM
			|	%1 AS LevelTable";
		
		QueryTextFragment2 = QueryTextFragment2 + StrTemplate(Text2, "LevelTable_" + String(i));
		
	EndDo;
	
	Query.Text = Query.Text + QueryTextFragment1 + QueryTextFragment2 + DriveClientServer.GetQueryDelimeter() + "
		|SELECT ALLOWED
		|	LevelTable.ParentProduct AS ParentProduct,
		|	LevelTable.ParentCharacteristic AS ParentCharacteristic,
		|	LevelTable.SubcontractorOrder AS SubcontractorOrder,
		|	LevelTable.Company AS Company,
		|	LevelTable.ProductionOrder AS ProductionOrder,
		|	LevelTable.Products AS Products,
		|	LevelTable.Characteristic AS Characteristic,
		|	0 AS QuantityPlan,
		|	0 AS QuantityProduced,
		|	0 AS QuantityDiff,
		|	SUM(WorkInProgressStatementTurnovers.QuantityReceipt) AS QuantityPlanSemiFinProd,
		|	SUM(WorkInProgressStatementTurnovers.QuantityExpense) AS QuantityProducedSemiFinProd,
		|	SUM(WorkInProgressStatementTurnovers.QuantityReceipt) - SUM(WorkInProgressStatementTurnovers.QuantityExpense) AS QuantityDiffSemiFinProd,
		|	0 AS QuantityIssued,
		|	0 AS QuantityToIssue,
		|	0 AS QuantityInvoiced,
		|	0 AS QuantityToInvoice
		|FROM
		|	LevelTable AS LevelTable
		|		INNER JOIN AccumulationRegister.WorkInProgressStatement.Turnovers(&BeginOfPeriod, &EndOfPeriod, , ) AS WorkInProgressStatementTurnovers
		|		ON LevelTable.Company = WorkInProgressStatementTurnovers.Company
		|			AND LevelTable.ProductionOrder = WorkInProgressStatementTurnovers.ProductionOrder
		|			AND LevelTable.Products = WorkInProgressStatementTurnovers.Products
		|			AND LevelTable.Characteristic = WorkInProgressStatementTurnovers.Characteristic
		|
		|GROUP BY
		|	LevelTable.ParentProduct,
		|	LevelTable.ParentCharacteristic,
		|	LevelTable.SubcontractorOrder,
		|	LevelTable.Company,
		|	LevelTable.ProductionOrder,
		|	LevelTable.Products,
		|	LevelTable.Characteristic";
	
	Query.SetParameter("BeginOfPeriod", BeginOfPeriod);
	Query.SetParameter("EndOfPeriod", EndOfPeriod);
	
	Return Query.Execute().Unload();
	
EndFunction

#EndRegion

#EndIf