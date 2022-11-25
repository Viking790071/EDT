#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	
	ReportSettings = SettingsComposer.GetSettings();
	ReportParameters = PrepareReportParameters(ReportSettings);
	ChangeStructureWithCurrencyAmount(ReportSettings);
	
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

Function PrepareReportParameters(ReportSettings)
	
	BeginOfPeriod = Date(1,1,1);
	EndOfPeriod = Date(1,1,1);
	TitleOutput = False;
	Title = NStr("en = 'Turnover balance sheet'; ru = 'Баланс по обороту';pl = 'Bilans obrotów';es_ES = 'Hoja de balance de facturación';es_CO = 'Hoja de balance de facturación';tr = 'Ciro bilançosu';it = 'Fatturato bilancio';de = 'Umsatz-Bilanz'");
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("ItmPeriod"));
	If ParameterPeriod <> Undefined AND ParameterPeriod.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
		If ParameterPeriod.Use	AND ValueIsFilled(ParameterPeriod.Value) Then
			BeginOfPeriod = ParameterPeriod.Value.StartDate;
			EndOfPeriod  = ParameterPeriod.Value.EndDate;
		EndIf;
	EndIf;
	
	ParameterOutputTitle = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("TitleOutput"));
	If ParameterOutputTitle <> Undefined AND ParameterOutputTitle.Use Then
		TitleOutput = ParameterOutputTitle.Value;
	EndIf;
	
	OutputParameter = ReportSettings.OutputParameters.FindParameterValue(New DataCompositionParameter("Title"));
	If OutputParameter <> Undefined AND OutputParameter.Use Then
		Title = OutputParameter.Value;
	EndIf;
	
	ReportParameters = New Structure;
	ReportParameters.Insert("BeginOfPeriod",	BeginOfPeriod);
	ReportParameters.Insert("EndOfPeriod",		EndOfPeriod);
	ReportParameters.Insert("TitleOutput",		TitleOutput);
	ReportParameters.Insert("Title",			Title);
	ReportParameters.Insert("ReportId",			"TrialBalanceFinancial");
	ReportParameters.Insert("ReportSettings",	ReportSettings);
	
	Return ReportParameters;
	
EndFunction

Procedure ChangeStructureWithCurrencyAmount(ReportSettings)
	
	ParameterCurrencyAmount = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("CurrencyAmount"));
	If ParameterCurrencyAmount = Undefined Then
		CurrencyAmount = False;
	Else
		CurrencyAmount = ParameterCurrencyAmount.Value AND ParameterCurrencyAmount.Use;
	EndIf;
	
	For Each GroupField In ReportSettings.Selection.Items Do
		
		If TypeOf(GroupField) = Type("DataCompositionSelectedFieldGroup") Then
			
			For Each ItemField In GroupField.Items Do
				
				If TypeOf(ItemField) = Type("DataCompositionSelectedField") Then
					
					ItemFieldTitle = String(ItemField.Field);
					
					If StrStartsWith(ItemFieldTitle, "AmountCur") Then
						
						ItemField.Use = CurrencyAmount;
						
					ElsIf StrStartsWith(ItemFieldTitle, "Amount") Then
						
						ItemField.Use = Not CurrencyAmount;
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf