#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing) Export

	StandardProcessing = False;
	
	ReportSettings = SettingsComposer.GetSettings();
	
	AccountingPolicySettings = AccountingPolicySettingsStructure();
	
	ParameterCompany = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("Company"));
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("ItmPeriod"));
	If ParameterPeriod <> Undefined
			And ParameterCompany <> Undefined Then
			
		AccountingPolicySettings = AccountingPolicySettings(
			ParameterCompany.Value,
			ParameterPeriod.Value.StartDate,
			ParameterPeriod.Value.EndDate);
		
	EndIf;
	
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	DriveReports.SetReportAppearanceTemplate(ReportSettings);
	DriveReports.OutputReportTitle(ReportParameters, ResultDocument);
	
	If AccountingPolicySettings.TwoDiffColumns Then
		
		FieldsToBeDisabled = New Array;
		FieldsToBeDisabled.Add("AmountDiffCOGS");
		FieldsToBeDisabled.Add("AmountDiff");
		
		DriveReports.DisableSelectionFields(ReportSettings, FieldsToBeDisabled);
		
	Else
		
		FieldsToBeDisabled = New Array;
		If AccountingPolicySettings.AdjustedAllocationRate Then
			FieldsToBeDisabled.Add("AmountDiffCOGS");
		Else
			FieldsToBeDisabled.Add("AmountDiff");
		EndIf;
		
		FieldsToBeDisabled.Add("AmountDiffGrouped");
		FieldsToBeDisabled.Add("AmountDiffCOGSGrouped");
		
		DriveReports.DisableSelectionFields(ReportSettings, FieldsToBeDisabled);
		
	EndIf;
	
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
	
	Period = Date(1,1,1);
	TitleOutput = False;
	Title = NStr("en = 'Manufacturing overheads statement'; ru = 'Ведомость производственных накладных расходов';pl = 'Koszty ogólne produkcji';es_ES = 'Declaración de gastos generales de fabricación';es_CO = 'Declaración de gastos generales de fabricación';tr = 'Üretim genel giderleri ekstresi';it = 'Dichiarazione spese generali di produzione';de = 'Auszug von Fertigungsgemeinkosten'");
	
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
	ReportParameters.Insert("TitleOutput", TitleOutput);
	ReportParameters.Insert("Title", Title);
	ReportParameters.Insert("ReportId", "ManufacturingOverheadsStatement");
	ReportParameters.Insert("ReportSettings", ReportSettings);
	
	Return ReportParameters;
	
EndFunction

Function AccountingPolicySettingsStructure()
	
	Structure = New Structure;
	Structure.Insert("AdjustedAllocationRate", False);
	Structure.Insert("TwoDiffColumns", False);
	Return Structure;
	
EndFunction

Function AccountingPolicySettings(Company, StartDate, EndDate)
	
	Result = AccountingPolicySettingsStructure();
	
	Query = New Query(
	"SELECT ALLOWED
	|	CASE
	|		WHEN AccountingPolicySliceLast.UnderOverAllocatedOverheadsSetting = VALUE(Enum.UnderOverAllocatedOverheadsSettings.AdjustedAllocationRate)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AdjustedAllocationRate
	|FROM
	|	InformationRegister.AccountingPolicy.SliceLast(&StartDate, Company = &Company) AS AccountingPolicySliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	AccountingPolicy.UnderOverAllocatedOverheadsSetting AS Setting,
	|	AccountingPolicySliceLast.UnderOverAllocatedOverheadsSetting AS SettingLast
	|FROM
	|	InformationRegister.AccountingPolicy AS AccountingPolicy
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&StartDate, Company = &Company) AS AccountingPolicySliceLast
	|		ON AccountingPolicy.Company = AccountingPolicySliceLast.Company
	|WHERE
	|	AccountingPolicy.Company = &Company
	|	AND AccountingPolicy.Period BETWEEN &StartDate AND &EndDate");
	
	Query.SetParameter("Company",	Company);
	Query.SetParameter("StartDate", StartDate);
	Query.SetParameter("EndDate", 	EndDate);
	
	QueryResult = Query.ExecuteBatch();
	
	If Not QueryResult[0].IsEmpty() Then
		Selection = QueryResult[0].Select();
		Selection.Next();
		FillPropertyValues(Result, Selection);
		
		TwoDiffColumnsSelection = QueryResult[1].Select();
		If TwoDiffColumnsSelection.Count() > 1 Then
			Result.TwoDiffColumns = True;
		ElsIf TwoDiffColumnsSelection.Next() Then
			Result.TwoDiffColumns = (TwoDiffColumnsSelection.Setting <> TwoDiffColumnsSelection.SettingLast);
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf