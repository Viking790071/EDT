#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	ReportSettings = SettingsComposer.GetSettings();
	
	ReportParameters = PrepareReportParameters(ReportSettings);
	DriveReports.SetReportAppearanceTemplate(ReportSettings);
	DriveReports.OutputReportTitle(ReportParameters, ResultDocument);

	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);
	
	// Create and initialize a composition processor
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, , DetailsData, True);

	// Create and initialize the result output processor
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	OutputProcessor.Output(CompositionProcessor);
	
EndProcedure

Function PrepareReportParameters(ReportSettings)
	
	TitleOutput = False;
	Title = NStr("en = 'Counterparty segment content'; ru = 'Состав сегмента контрагентов';pl = 'Zawartość segmentów klienta';es_ES = 'Contenido del segmento de contrapartida';es_CO = 'Contenido del segmento de contrapartida';tr = 'Cari hesap segment içeriği';it = 'Contenuto segmento controparte';de = 'Inhalt des Geschäftspartner-Segments'");
	
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
	ReportParameters.Insert("TitleOutput",		TitleOutput);
	ReportParameters.Insert("Title",			Title);
	ReportParameters.Insert("ReportId"      ,	"CounterpartySegmentContent");
	ReportParameters.Insert("ReportSettings",	ReportSettings);
		
	Return ReportParameters;
	
EndFunction

#EndIf