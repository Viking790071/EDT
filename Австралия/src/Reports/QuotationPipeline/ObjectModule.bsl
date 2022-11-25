#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	StandardProcessing = False;
	UserSettingsModified = False;
	
	SetRequiredSettings(UserSettingsModified);
	
	ArrayHeaderResources = New Array;
	ReportSettings = SettingsComposer.GetSettings();
	
	AdditionalProperties = SettingsComposer.UserSettings.AdditionalProperties;
	
	// Drill down vision
	DrillDown = AdditionalProperties.Property("DrillDown")
		AND AdditionalProperties.DrillDown;
		
	FromDrillDown = False;
	For Each StructureItem In ReportSettings.Structure Do
		If StructureItem.Name = "DrillDown" AND StructureItem.Use Then
			FromDrillDown = True;
			Break;
		EndIf;
	EndDo;
	
	If DrillDown OR FromDrillDown Then
		For Each StructureItem In ReportSettings.Structure Do
			StructureItem.Use = (StructureItem.Name = "DrillDown");
		EndDo;
		If DrillDown Then
			AdditionalProperties.DrillDown = False;
		EndIf;
	EndIf;
	
	// Filter
	If AdditionalProperties.Property("FilterStructure") Then
		For Each FilterItem In AdditionalProperties.FilterStructure Do
			CommonClientServer.SetFilterItem(ReportSettings.Filter,
				FilterItem.Key,
				FilterItem.Value);
		EndDo;
		AdditionalProperties.Delete("FilterStructure");
	EndIf;
	
	SetConditionalAppearanceInStatusesColors(ReportSettings.ConditionalAppearance);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);

	// Create and initialize the processor layout and precheck parameters
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, , DetailsData, True);

	// Create and initialize the result output processor
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	// Indicate the output begin
	OutputProcessor.Output(CompositionProcessor);
	
EndProcedure

#EndRegion

#Region Private

Procedure SetRequiredSettings(UserSettingsModified)
	
	DriveReports.SetOutputParameter(SettingsComposer, "TextPotential", " " + NStr("en = 'Potential: %1'; ru = 'Потенциал: %1';pl = 'Potencjał: %1';es_ES = 'Potencial: %1';es_CO = 'Potencial: %1';tr = 'Potansiyel: %1';it = 'Potenziale: %1';de = 'Potenzial: %1'"));
	UserSettingsModified = True;
	
EndProcedure

Procedure SetConditionalAppearanceInStatusesColors(ConditionalAppearanceCS)
	
	DeleteItems = New Array;
	
	For Each ConditionalAppearanceItem In ConditionalAppearanceCS.Items Do
		If ConditionalAppearanceItem.UserSettingID = "StatusColor" Then
			DeleteItems.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	
	For Each DeleteItem In DeleteItems Do
		ConditionalAppearanceCS.Items.Delete(DeleteItem);
	EndDo;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	QuotationStatuses.Ref AS Status,
		|	QuotationStatuses.HighlightColor AS HighlightColor
		|FROM
		|	Catalog.QuotationStatuses AS QuotationStatuses
		|WHERE
		|	NOT QuotationStatuses.DeletionMark";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		StatusColor = SelectionDetailRecords.HighlightColor.Get();
		If TypeOf(StatusColor) <> Type("Color") Or StatusColor = StyleColors.TitleColorSettingsGroup Then
			Continue;
		EndIf;
		
		ConditionalAppearanceItem =  ConditionalAppearanceCS.Items.Add();
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("ColorInChart", StatusColor);
		ConditionalAppearanceItem.UserSettingID = "StatusColor";
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess;
		ConditionalAppearanceItem.Presentation = NStr("en = 'Appearance in status color'; ru = 'Цветовое оформление статуса';pl = 'Wygląd w kolorze statusu';es_ES = 'Apariencia en el color del estado';es_CO = 'Apariencia en el color del estado';tr = 'Durum renginde görünüm';it = 'Visualizzazione nel colore  stato';de = 'Darstellung in Status-Farbe'");
		
		FilterActivity = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterActivity.LeftValue = New DataCompositionField("Status");
		FilterActivity.ComparisonType = DataCompositionComparisonType.Equal;
		FilterActivity.RightValue = SelectionDetailRecords.Status;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
