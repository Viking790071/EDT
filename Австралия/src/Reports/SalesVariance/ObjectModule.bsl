#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	StandardProcessing = False;
	
	SetRequiredSettings();
	
	ReportSettings = SettingsComposer.GetSettings();
	
	If SettingsComposer.UserSettings.AdditionalProperties.Property("VariantKey")
		And SettingsComposer.UserSettings.AdditionalProperties.VariantKey = "Default" Then
		
		ChangeStructureWithSalesGoalDimensions(ReportSettings);
		
	EndIf;
	
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

#EndRegion

#Region Private

Procedure SetRequiredSettings()
	
	DriveReports.SetOutputParameter(SettingsComposer, "TextUndefined", "<" + NStr("en = 'not specified'; ru = 'не указан';pl = 'nieokreślony';es_ES = 'no especificado';es_CO = 'no especificado';tr = 'belirtilmemiş';it = 'non specificato';de = 'keine angabe'") + ">");
	
EndProcedure

Function PrepareReportParameters(ReportSettings)
	
	BeginOfPeriod = Date(1,1,1);
	EndOfPeriod  = Date(1,1,1);
	TitleOutput = False;
	Title = "Sales plan-actual analysis";
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("ItmPeriod"));
	If ParameterPeriod <> Undefined AND ParameterPeriod.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
		If ParameterPeriod.Use
			AND ValueIsFilled(ParameterPeriod.Value) Then
			
			BeginOfPeriod = ParameterPeriod.Value.StartDate;
			EndOfPeriod  = ParameterPeriod.Value.EndDate;
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
	ReportParameters.Insert("BeginOfPeriod"            , BeginOfPeriod);
	ReportParameters.Insert("EndOfPeriod"             , EndOfPeriod);
	ReportParameters.Insert("TitleOutput"        , TitleOutput);
	ReportParameters.Insert("Title"                , Title);
	ReportParameters.Insert("ReportId"      , "SalesVariance");
	ReportParameters.Insert("ReportSettings", ReportSettings);
		
	Return ReportParameters;
	
EndFunction

Procedure ChangeStructureWithSalesGoalDimensions(ReportSettings)
	
	SalesGoalSetting = Catalogs.SalesGoalSettings.EmptyRef();
	
	ParameterSalesGoalSetting = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("SalesGoalSetting"));
	If ParameterSalesGoalSetting <> Undefined AND ParameterSalesGoalSetting.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
		If ParameterSalesGoalSetting.Use
			AND ValueIsFilled(ParameterSalesGoalSetting.Value) Then
			
			SalesGoalSetting = ParameterSalesGoalSetting.Value;
			
		EndIf;
	EndIf;
	
	If ValueIsFilled(SalesGoalSetting) Then
		
		// SpecifyQuantity
		For Each ColumnGroup In ReportSettings.Selection.Items Do
			
			If ColumnGroup.Title = "Quantity" Then
				
				ColumnGroup.Use = SalesGoalSetting.SpecifyQuantity;
				Break;
				
			EndIf;
			
		EndDo;
		
		// Dimensions
		ReportSettings.Structure.Clear();
		
		Node = ReportSettings;
		
		For Each DimensionRow In SalesGoalSetting.Dimensions do
			
			Dimension = DimensionRow.Dimension;
			
			DataCompositionGroup = Node.Structure.Add(Type("DataCompositionGroup"));
			DataCompositionGroup.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
			
			GroupField = DataCompositionGroup.GroupFields.Items.Add(Type("DataCompositionGroupField"));
			GroupField.Use = True;
			GroupField.Field = New DataCompositionField(XMLString(Dimension));
			
			Node = DataCompositionGroup;
			
			If Dimension = Enums.SalesGoalDimensions.Products Then
				
				If GetFunctionalOption("UseCharacteristics") Then
					
					DataCompositionGroup = Node.Structure.Add(Type("DataCompositionGroup"));
					DataCompositionGroup.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
					
					GroupField = DataCompositionGroup.GroupFields.Items.Add(Type("DataCompositionGroupField"));
					GroupField.Use = True;
					GroupField.Field = New DataCompositionField("Characteristic");
					
					Node = DataCompositionGroup;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf