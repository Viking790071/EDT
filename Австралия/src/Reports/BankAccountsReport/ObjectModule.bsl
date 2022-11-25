#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

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
	
	Period = Date(1,1,1);
	TitleOutput = False;
	Title = NStr("en = 'Bank accounts report'; ru = 'Отчет о банковских счетах';pl = 'Raport rachunki bankowe';es_ES = 'Informe de cuentas bancarias';es_CO = 'Informe de cuentas bancarias';tr = 'Banka hesapları raporu';it = 'Report conti corrente';de = 'Bericht Bankkonten'");
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("Period"));
	If ParameterPeriod <> Undefined
		And ParameterPeriod.Use
		And ValueIsFilled(ParameterPeriod.Value) Then
		
		Period  = ParameterPeriod.Value;
	EndIf;
	
	ParameterOutputTitle = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("TitleOutput"));
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
	ReportParameters.Insert("Period"              , Period);
	ReportParameters.Insert("TitleOutput"   , TitleOutput);
	ReportParameters.Insert("Title"           , Title);
	ReportParameters.Insert("ReportId" , "BankAccountsReport");
	ReportParameters.Insert("ReportSettings"	   , ReportSettings);
	
	Return ReportParameters;
	
EndFunction

#EndRegion

#EndIf