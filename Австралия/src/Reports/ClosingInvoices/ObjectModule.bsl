#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	
	ReportSettings = SettingsComposer.GetSettings();
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	DriveReports.SetReportAppearanceTemplate(ReportSettings);
	PricePrecision = PrecisionAppearancetServer.CompanyPrecision(ParameterValue(ReportSettings, "Company"));
	
	ConditionalAppearanceItem = ReportSettings.ConditionalAppearance.Items.Add();
	ItemField = ConditionalAppearanceItem.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("Price");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("Price");
	FilterItem.ComparisonType = DataCompositionComparisonType.GreaterOrEqual;
	FilterItem.RightValue = 0;
	ConditionalAppearanceItem.Appearance.SetParameterValue("Format", "NFD=" + PricePrecision);
	
	DriveReports.OutputReportTitle(ReportParameters, ResultDocument);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);
	
	// Create and initialize a composition processor
	CompositionProcessor = New DataCompositionProcessor;
	
	ExternalDataSets = New Structure;
	DataParameters = New Structure;
	Period = ParameterValue(ReportSettings, "Period");
	DataParameters.Insert("StartDate", Period.StartDate);
	DataParameters.Insert("EndDate", Period.EndDate);
	DataParameters.Insert("Company", ParameterValue(ReportSettings, "Company"));
	DataParameters.Insert("Department", ParameterValue(ReportSettings, "Department"));
	DataParameters.Insert("FilterDepartment", ValueIsFilled(DataParameters.Department));
	Counterparties = ParameterValue(ReportSettings, "FilterCounterparties");
	
	If Counterparties = Undefined Then
		DataParameters.Insert("Counterparties", New Array);
	ElsIf TypeOf(Counterparties) = Type("CatalogRef.Counterparties") Then
		DataParameters.Insert("Counterparties", New Array);
		DataParameters.Counterparties.Add(Counterparties);
	Else
		DataParameters.Insert("Counterparties", Counterparties.UnloadValues());
	EndIf;
	DataParameters.Insert("FilterCounterparty", DataParameters.Counterparties.Count() > 0);
	DataParameters.Insert("Date", ParameterValue(ReportSettings, "Date"));
	DataParameters.Insert("Template", DataCompositionSchema);
	DataTable = DataProcessors.ClosingInvoiceProcessing.GetData(DataParameters);
	ExternalDataSets.Insert("DataTable", DataTable);
	
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
				And ResultItem.ParameterValues.Count() > 0 
				And TypeOf(SettingsComposer.Settings.Structure[0]) <> Type("DataCompositionChart") Then
				
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
	Period = Date(1,1,1);
	TitleOutput = False;
	Title = NStr("en = 'Closing invoices'; ru = 'Заключительные инвойсы';pl = 'Faktury końcowe';es_ES = 'Facturas de cierre';es_CO = 'Facturas de cierre';tr = 'Kapanış faturaları';it = 'Fatture di chiusura';de = 'Abschlussrechnungen'");
	
	ParameterOutputTitle = ParameterValue(ReportSettings, "TitleOutput");
	If ParameterOutputTitle <> Undefined
		And ParameterOutputTitle.Use Then
		
		TitleOutput = ParameterOutputTitle.Value;
	EndIf;
	
	OutputParameter = ReportSettings.OutputParameters.FindParameterValue(New DataCompositionParameter("Title"));
	If OutputParameter <> Undefined
		And OutputParameter.Use Then
		Title = OutputParameter.Value;
	EndIf;
	
	ReportParameters = New Structure;
	ReportParameters.Insert("TitleOutput"		, TitleOutput);
	ReportParameters.Insert("Title"				, Title);
	ReportParameters.Insert("ReportId"			, "CostOfGoodsProduced");
	ReportParameters.Insert("ReportSettings"	, ReportSettings);
		
	Return ReportParameters;
	
EndFunction

Function ParameterValue(ReportSettings, ParameterName)
	
	Parameter = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter(ParameterName));
	If Parameter = Undefined Then
		Return Undefined;
	Else
		Return Parameter.Value;
	EndIf;
	
EndFunction

#EndRegion

#EndIf