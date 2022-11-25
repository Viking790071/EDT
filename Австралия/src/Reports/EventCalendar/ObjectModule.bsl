#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	
	ReportSettings = SettingsComposer.GetSettings();
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	SetDataParameters(ReportSettings);
	
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
	
	StartOfPeriod = Date(1, 1, 1);
	EndOfPeriod = Date(3999, 12, 31, 23, 59, 59);
	TitleOutput = False;
	Title = "Event calendar";
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("ItmPeriod"));
	If ParameterPeriod <> Undefined And ParameterPeriod.Use Then
		StartOfPeriod = ParameterPeriod.Value.StartDate;
		EndOfPeriod = ParameterPeriod.Value.EndDate;
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
	ReportParameters.Insert("StartOfPeriod"		, StartOfPeriod);
	ReportParameters.Insert("EndOfPeriod"		, EndOfPeriod);
	ReportParameters.Insert("TitleOutput"		, TitleOutput);
	ReportParameters.Insert("Title"				, Title);
	ReportParameters.Insert("ReportId"			, "EventCalendar");
	ReportParameters.Insert("ReportSettings"	, ReportSettings);
	
	Return ReportParameters;
	
EndFunction

Procedure SetDataParameters(ReportSettings)
	
	ParametersMap = New Map;
	ParametersMap.Insert(New DataCompositionParameter("CurrentDate"), CurrentSessionDate());
	ParametersMap.Insert(New DataCompositionParameter("TextOverdue"), NStr("en = 'Overdue'; ru = 'Просрочено';pl = 'Zaległe';es_ES = 'Vencido';es_CO = 'Vencido';tr = 'Vadesi geçmiş';it = 'In ritardo';de = 'Überfällig'"));
	ParametersMap.Insert(New DataCompositionParameter("TextForToday"), NStr("en = 'For today'; ru = 'На сегодня';pl = 'Na dzisiaj';es_ES = 'Para hoy';es_CO = 'Para hoy';tr = 'Bugün için';it = 'Odierni';de = 'Für Heute'"));
	ParametersMap.Insert(New DataCompositionParameter("TextPlanned"), NStr("en = 'Planned'; ru = 'Запланировано';pl = 'Planowane';es_ES = 'Planificado';es_CO = 'Planificado';tr = 'Planlanan';it = 'Pianificato';de = 'Geplant'"));
	
	For Each MapItem In ParametersMap Do
		If ReportSettings.DataParameters.FindParameterValue(MapItem.Key) <> Undefined Then
			ReportSettings.DataParameters.SetParameterValue(MapItem.Key, MapItem.Value);
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#EndIf