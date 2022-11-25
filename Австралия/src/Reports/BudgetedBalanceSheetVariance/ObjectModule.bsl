#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	
	ReportSettings = SettingsComposer.GetSettings();
	DriveReports.SetReportAppearanceTemplate(ReportSettings);
	
	PlanningPeriodParameter = ReportSettings.DataParameters.FindParameterValue(
		New DataCompositionParameter("PlanningPeriodUser"));
		
	If Not PlanningPeriodParameter = Undefined Then
		PlanningPeriodValue = PlanningPeriodParameter.Value;	
		ReportSettings.DataParameters.SetParameterValue("StartDateOfPlanningPeriod", PlanningPeriodValue.StartDate);
		ReportSettings.DataParameters.SetParameterValue("EndDateOfPlanningPeriod", EndOfDay(PlanningPeriodValue.EndDate));
	EndIf;
	
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

#EndRegion

#EndIf