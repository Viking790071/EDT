#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	
	ReportSettings = SettingsComposer.GetSettings();
	
	PrepareReportParameters(ReportSettings);
	
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

Procedure PrepareReportParameters(ReportSettings)
	
	Parameter_ShouldCompleted = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("ShouldCompleted"));
	Parameter_ShouldStarted = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("ShouldStarted"));
	
	FilterFieldComplete = New DataCompositionField("ShouldCompletedDay");
	FilterFieldStart = New DataCompositionField("ShouldStartedDay");
	
	ComposerFilter = ReportSettings.Filter.Items;
	For Each Row In ComposerFilter Do
		If TypeOf(Row) = Type("DataCompositionFilterItemGroup") And Row.Use Then
			
			For Each ItemRow In Row.Items Do
				If ItemRow.LeftValue = FilterFieldComplete Then
					Row.Use = Parameter_ShouldCompleted.Use;
					Break;
				ElsIf ItemRow.LeftValue = FilterFieldStart Then
					Row.Use = Parameter_ShouldStarted.Use;
					Break;
				EndIf;
			EndDo;
			
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#EndIf