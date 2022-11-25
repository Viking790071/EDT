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
	
	TitleOutput = False;
	Title = NStr("en = 'Profit and loss account recorders'; ru = 'Регистраторы счета затрат';pl = 'Rejestratory konta zysków i strat';es_ES = 'Registradores de cuenta de pérdidas y ganancias';es_CO = 'Registradores de cuenta de pérdidas y ganancias';tr = 'Kar-zarar hesabı kaydediciler';it = 'Profitto e perdita registratori di conto';de = 'Recorder von Gewinn- und Verlustkonto'");
	
	ParameterGLAccount = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("GLAccount"));
	If ParameterGLAccount <> Undefined 
		And ParameterGLAccount.Use
		And ValueIsFilled(ParameterGLAccount.Value) Then
		
		GLAccount = ParameterGLAccount.Value;
	EndIf;
	
	ParameterTitleOutput = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("TitleOutput"));
	If ParameterTitleOutput <> Undefined And ParameterTitleOutput.Use Then
		TitleOutput = ParameterTitleOutput.Value;
	EndIf;
	
	ParameterTitle = ReportSettings.OutputParameters.FindParameterValue(New DataCompositionParameter("Title"));
	If ParameterTitle <> Undefined And ParameterTitle.Use Then
		Title = ParameterTitle.Value;
	EndIf;
	
	ReportParameters = New Structure;
	ReportParameters.Insert("GLAccount", GLAccount);
	ReportParameters.Insert("TitleOutput", TitleOutput);
	ReportParameters.Insert("Title", Title);
	ReportParameters.Insert("ReportId", "ProfitAndLossAccountRecorders");
	ReportParameters.Insert("ReportSettings", ReportSettings);
	
	Return ReportParameters;
	
EndFunction
#EndRegion 

#EndIf