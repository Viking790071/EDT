#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	StandardProcessing = False;
	UserSettingsModified = False;
	
	DriveReports.ChangeGroupsValues(SettingsComposer, UserSettingsModified);
	
	ReportSettings = SettingsComposer.GetSettings();
	
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	DriveReports.SetReportAppearanceTemplate(ReportSettings);
	DriveReports.OutputReportTitle(ReportParameters, ResultDocument);
	DriveReports.CustomizeDynamicPeriod(DataCompositionSchema, ReportParameters);
	
	// Setting horizontal group name by period for layout
	AvailableResources = New Array;
	For Each Item In ReportSettings.Selection.SelectionAvailableFields.Items Do
		If Item.Resource Then
			AvailableResources.Add(Item.Field);
		EndIf;
	EndDo;
	
	SelectedResources = New Array;
	For Each Item In ReportSettings.Selection.Items Do
		If TypeOf(Item) = Type("DataCompositionAutoSelectedField") Then
			Continue;
		EndIf;
		If Item.Use AND AvailableResources.Find(Item.Field) <> Undefined Then
			SelectedResources.Add(Item.Field);
		EndIf;
	EndDo;
	
	If SelectedResources.Count() = 1 Then
		For Each StructureItem In ReportSettings.Structure Do
			If TypeOf(StructureItem) = Type("DataCompositionTable") Then
				If ReportSettings.Structure.Count() > 1 And ReportSettings.Structure[1].Selection.Items.Count() = 0 Then
					For Each Column In StructureItem.Columns Do
						If Column.Use Then
							If Column.GroupFields.Items[0].Use
								AND Column.GroupFields.Items[0].Field = New DataCompositionField("DynamicPeriod") Then
								Column.Name = "DynamicPeriodAcross";
							EndIf;
						EndIf;
					EndDo;
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	Frequency = GetFrequencyValue(ReportParameters);
	For Each StructureItem In ReportSettings.Structure Do
		If TypeOf(StructureItem) = Type("DataCompositionGroup") Then
			For Each GroupField In StructureItem.GroupFields.Items Do
				If GroupField.Field = New DataCompositionField("DynamicPeriod") Then
					ConditionalAppearance = StructureItem.ConditionalAppearance.Items.Add();
					ConditionalAppearance.Use = True;
					ConditionalAppearance.UseInHeader = DataCompositionConditionalAppearanceUse.Use;
					ConditionalAppearance.UseInFieldsHeader = DataCompositionConditionalAppearanceUse.Use;
					ConditionalAppearance.UseInFilter = DataCompositionConditionalAppearanceUse.DontUse;
					ConditionalAppearance.UseInGroup = DataCompositionConditionalAppearanceUse.DontUse;
					ConditionalAppearance.UseInOverall = DataCompositionConditionalAppearanceUse.DontUse;
					ConditionalAppearance.UseInOverallHeader = DataCompositionConditionalAppearanceUse.DontUse;
					
					ConditionalAppearance.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
					
					DataCompositionField = ConditionalAppearance.Fields.Items.Add();
					DataCompositionField.Field = New DataCompositionField("DynamicPeriod");
					
					ConditionalAppearance.Appearance.SetParameterValue("Text", Frequency);
				EndIf;
			EndDo;	
		EndIf;
	EndDo;
	
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
	AreasForDeletion = New Array;
	ChartsQuantity = 0;
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
			// Item is received - display it using the output processor
			OutputProcessor.OutputItem(ResultItem);
			
			If ResultDocument.Drawings.Count() > ChartsQuantity Then
				
				ChartsQuantity = ResultDocument.Drawings.Count();
				CurrentPicture = ResultDocument.Drawings[ChartsQuantity-1];
				If TypeOf(CurrentPicture.Object) = Type("Chart") Then
					
					DriveReports.SetReportChartSize(CurrentPicture);
					
					CurrentLineNumber = ResultDocument.TableHeight;
					Area = ResultDocument.Area(CurrentLineNumber - 6,,CurrentLineNumber);
					AreasForDeletion.Add(Area);
				EndIf;
			EndIf;
			
		EndIf;
	EndDo;

	OutputProcessor.EndOutput();
	
	For Each Area In AreasForDeletion Do
		ResultDocument.DeleteArea(Area, SpreadsheetDocumentShiftType.Vertical);
	EndDo;
	
	DriveReports.ProcessReportCharts(ReportParameters, ResultDocument);
	
EndProcedure

Function PrepareReportParameters(ReportSettings)
	
	BeginOfPeriod = Date(1,1,1);
	EndOfPeriod  = Date(1,1,1);
	Periodicity = Enums.Periodicity.Auto;
	ChartTypeReport = Undefined;
	TitleOutput = False;
	Title = "Sales";
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("Period"));
	If ParameterPeriod <> Undefined
		AND ParameterPeriod.Use
		AND ValueIsFilled(ParameterPeriod.Value) Then
		
		BeginOfPeriod = ParameterPeriod.Value.StartDate;
		EndOfPeriod  = ParameterPeriod.Value.EndDate;
	EndIf;
	
	ParameterPeriodicity = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("Periodicity"));
	If ParameterPeriodicity <> Undefined
		AND ParameterPeriodicity.Use
		AND ValueIsFilled(ParameterPeriodicity.Value) Then
		
		Periodicity = ParameterPeriodicity.Value;
	EndIf;
	
	ChartTypeParameter = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("ChartType"));
	If ChartTypeParameter <> Undefined
		AND ChartTypeParameter.Use
		AND ValueIsFilled(ChartTypeParameter.Value) Then
		
		If ChartTypeParameter.Value <> "Arbitrary" Then
			ChartTypeReport = ChartType[ChartTypeParameter.Value];
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
	ReportParameters.Insert("BeginOfPeriod"  , BeginOfPeriod);
	ReportParameters.Insert("EndOfPeriod"    , EndOfPeriod);
	ReportParameters.Insert("Periodicity"    , Periodicity);
	ReportParameters.Insert("ChartType"      , ChartTypeReport);
	ReportParameters.Insert("TitleOutput"    , TitleOutput);
	ReportParameters.Insert("Title"          , Title);
	ReportParameters.Insert("ReportId"       , "Sales");
	ReportParameters.Insert("ReportSettings" , ReportSettings);
		
	Return ReportParameters;
	
EndFunction

Function GetFrequencyValue(ReportParameters) 
	
	Periodicity 	= ReportParameters.Periodicity;
	BeginOfPeriod 	= ReportParameters.BeginOfPeriod;
	EndOfPeriod 	= ReportParameters.EndOfPeriod;
	
	Result = Enums.Periodicity.Month;
	
	If ValueIsFilled(Periodicity) And Periodicity <> Enums.Periodicity.Auto Then		
		Result = Periodicity;
	ElsIf ValueIsFilled(BeginOfPeriod)
			And ValueIsFilled(EndOfPeriod) Then
		
		Difference = EndOfPeriod - BeginOfPeriod;
		If Difference / 86400 < 45 Then
			Result = Enums.Periodicity.Day;
		Else
			Result = Enums.Periodicity.Month; 
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

#EndIf