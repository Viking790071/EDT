#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	UserSettingsModified = False;
	
	ReportSettings = SettingsComposer.GetSettings();
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	DriveReports.SetReportAppearanceTemplate(ReportSettings);
	
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
			If Not TableFixed
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
	
	TitleOutput = True;
	Title = NStr("en = 'Production status report'; ru = 'Отчет по статусам производства';pl = 'Analiza zleceń produkcyjnych';es_ES = 'Informe del estado de la producción';es_CO = 'Informe del estado de la producción';tr = 'Üretim durumu raporu';it = 'Report di stato di produzione';de = 'Produktionsstatus-Bericht'");
	
	CurrentDateParameter = CurrentSessionDate();
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("CurrentDateParameter"));
	If ParameterPeriod <> Undefined Then
		ParameterPeriod.Value = CurrentDateParameter;
	EndIf;
	
	ParameterOutputTitle = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("TitleOutput"));
	If ParameterOutputTitle <> Undefined And ParameterOutputTitle.Use Then
		TitleOutput = ParameterOutputTitle.Value;
	EndIf;
	
	OutputParameter = ReportSettings.OutputParameters.FindParameterValue(New DataCompositionParameter("Title"));
	If OutputParameter <> Undefined And OutputParameter.Use Then
		Title = OutputParameter.Value;
	EndIf;
	
	ReportParameters = New Structure;
	ReportParameters.Insert("CurrentDateParameter", CurrentDateParameter);
	ReportParameters.Insert("TitleOutput",			TitleOutput);
	ReportParameters.Insert("Title",				Title);
	ReportParameters.Insert("ReportId",				"ProductionStatusReport");
	ReportParameters.Insert("ReportSettings",		ReportSettings);
	
	Return ReportParameters;
	
EndFunction

#EndRegion

#EndIf