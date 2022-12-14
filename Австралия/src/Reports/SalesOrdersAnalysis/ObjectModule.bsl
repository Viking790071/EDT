#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	StandardProcessing = False;
	
	ReportSettings = SettingsComposer.GetSettings();
	
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	DriveReports.SetReportAppearanceTemplate(ReportSettings);
	DriveReports.OutputReportTitle(ReportParameters, ResultDocument);
	
	FieldsToBeDisabled = New Array;
	If Not GetFunctionalOption("UseInventoryReservation") Then
		FieldsToBeDisabled.Add("Reserved");
		FieldsToBeDisabled.Add("ReceiptDate");
		FieldsToBeDisabled.Add("PurchaseOrders");
		FieldsToBeDisabled.Add("ProductionOrders");
		FieldsToBeDisabled.Add("KitOrders");
		FieldsToBeDisabled.Add("DemandBalance");
	Else
		If Constants.DriveTrade.Get() Then
			FieldsToBeDisabled.Add("ProductionOrders");
		// begin Drive.FullVersion
		ElsIf Not GetFunctionalOption("UseProductionSubsystem") Then
			FieldsToBeDisabled.Add("ProductionOrders");
		// end Drive.FullVersion
		EndIf;
		If Not GetFunctionalOption("UseKitProcessing") Then
			FieldsToBeDisabled.Add("KitOrders");
		EndIf;
	EndIf;
	DriveReports.DisableSelectionFields(ReportSettings, FieldsToBeDisabled);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);
	
	// Create and initialize a composition processor
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, , DetailsData, True);

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

Function PrepareReportParameters(ReportSettings)
	
	TitleOutput = False;
	Title = NStr("en = 'Sales orders analysis'; ru = '???????????? ?????????????? ??????????????????????';pl = 'Analiza zam??wie?? sprzeda??y';es_ES = 'An??lisis de ??rdenes de ventas';es_CO = 'An??lisis de ??rdenes de ventas';tr = 'Sat???? sipari??leri analizi';it = 'Analisi ordini cliente';de = 'Analyse der Kundenauftr??ge'");
	ParametersToBeIncludedInSelectionText = New Array;
	
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
	ReportParameters.Insert("TitleOutput", TitleOutput);
	ReportParameters.Insert("Title", Title);
	ReportParameters.Insert("ParametersToBeIncludedInSelectionText", ParametersToBeIncludedInSelectionText);
	ReportParameters.Insert("ReportId", "SalesOrdersAnalysis");
	ReportParameters.Insert("ReportSettings", ReportSettings);
		
	Return ReportParameters;
	
EndFunction

#EndIf