#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	StandardProcessing = False;

	ReportSettings = SettingsComposer.GetSettings();
	
	AvailableParametersItems = ReportSettings.DataParameters.AvailableParameters.Items;
	
	ErrorTemplate = NStr("en = '%1 is required'; ru = 'Укажите %1';pl = '%1 jest wymagane.';es_ES = 'Se requiere ""%1"".';es_CO = 'Se requiere ""%1"".';tr = '%1 gerekli';it = '%1 richiesto';de = '""%1"" ist benötigt.'");
	
	For Each AvailableParameterRow In AvailableParametersItems Do
		If AvailableParameterRow.DenyIncompleteValues Then

			ParameterRow = ReportSettings.DataParameters.Items.Find(AvailableParameterRow.Parameter);
			
			If ParameterRow <> Undefined
				And Not ValueIsFilled(ParameterRow.Value) Then
				
				Raise StrTemplate(ErrorTemplate, AvailableParameterRow.Title);
			EndIf;
			
		EndIf;
	EndDo;
	
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	TotalsCount = AccountingReportsServer.TotalsCount(ReportParameters);
	
	If TotalsCount = 0 Then
		Raise NStr("en = 'At least one indicator is required'; ru = 'Укажите хотя бы один показатель';pl = 'Co najmniej jeden wskaźnik jest wymagany';es_ES = 'Se requiere al menos un indicador';es_CO = 'Se requiere al menos un indicador';tr = 'En az bir gösterge gerekli';it = 'È richiesto almeno un indicatore';de = 'Zumindest ein Indikator ist erforderlich'");
	EndIf;
	
	DriveReports.SetReportAppearanceTemplate(ReportSettings);
	AccountingReportsServer.OutputReportTitle(ReportParameters, ResultDocument);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData,,,True);

	AfterTemplateComposition(ReportParameters, CompositionTemplate, TotalsCount);
	
	// Create and initialize a composition processor
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, , DetailsData, True);

	// Create and initialize the result output processor
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);

	// Indicate the output begin
	OutputProcessor.BeginOutput();
	
	//// Main cycle of the report output
	While True Do
		// Get the next item of a composition result
		ResultItem = CompositionProcessor.Next();

		If ResultItem = Undefined Then
			// The next item is not received - end the output cycle
			Break;
		Else
			
			BeforeOutputElementResult(ReportParameters, CompositionTemplate, DetailsData, ResultItem);
			
			OutputProcessor.OutputItem(ResultItem);
			
		EndIf;
	EndDo;

	OutputProcessor.EndOutput();

EndProcedure

#EndRegion

#Region Private

Procedure AfterTemplateComposition(ReportParameters, CompositionTemplate, TotalsCount)

	GroupCount = 0;
	
	For Each TableRow In ReportParameters.Grouping Do
		If TableRow.Use Then
			ExtDimensionsCount = 0;
			For Each ExtDimensionRow In TableRow.ExtDimensions Do
				If ExtDimensionRow.Check Then
					ExtDimensionsCount = ExtDimensionsCount + 1;
				EndIf;
			EndDo;
			GroupCount = Max(GroupCount, ExtDimensionsCount);
		EndIf;
	EndDo;

	GroupCount = GroupCount + ?(ReportParameters.CurrencyAmount, GroupCount, 0);

	HeaderRowsCount = Max(GroupCount, 1);
	ReportParameters.Insert("HeaderHeight", HeaderRowsCount + 1);

	TableHeaderTemplate = AccountingReportsServer.GetHeaderTemplate(CompositionTemplate);
	
	ReportHeaderTemplates = New Array;
	ReportHeaderTemplates.Add(TableHeaderTemplate.Name);

	SearchParameters = AccountingReportsServer.SearchParametersInCompositionTemplateBody();
	SearchParameters.PropertyForIdentification = "ItemType";
	CurrentDataCompositionTemplateTable = AccountingReportsServer.PickElementsFromTemplateBody(
		CompositionTemplate, "DataCompositionTemplateTable", SearchParameters);
	For Each Column In CurrentDataCompositionTemplateTable.Columns Do

		For Each GroupingBody In Column.Body Do
			ReportHeaderTemplates.Add(GroupingBody.Template);
		EndDo;

	EndDo;

	ArrayForDelete = New Array;
	
	For Each ReportHeaderTemplateName In ReportHeaderTemplates Do
		
		ReportHeaderTemplate = CompositionTemplate.Templates[ReportHeaderTemplateName];
		
		For Index = HeaderRowsCount + 1 To ReportHeaderTemplate.Template.Count() - 1 Do
			
			ArrayForDelete.Add(ReportHeaderTemplate.Template[Index]);
			
		EndDo;
		
		For Each Item In ArrayForDelete Do
			ReportHeaderTemplate.Template.Delete(Item);
		EndDo;
		
		If ReportHeaderTemplate = TableHeaderTemplate And HeaderRowsCount = 1 Then
			
			NeedCount = ReportHeaderTemplate.Template.Count() - 1;
			
			For Each Cell In ReportHeaderTemplate.Template[NeedCount].Cells Do
				
				Appearance = Cell.Appearance.Items.Find("VerticalMerge");
				Appearance.Value = True;
				Appearance.Use = True;
				
			EndDo;
			
		EndIf;
			
	EndDo;
	
	MapTemplatesToReportColumns = New Map;
	ReportFooterResourcesTemplates = New Array;
	AccountingReportsServer.FillTemplatesOfReportFooterResources(CurrentDataCompositionTemplateTable, ReportFooterResourcesTemplates, MapTemplatesToReportColumns);
	AccountResourcesTemplates = New Array;
	AccountingReportsServer.FillTemplatesOfGroupingResources(CurrentDataCompositionTemplateTable.Rows, AccountResourcesTemplates, MapTemplatesToReportColumns, "Account");

	SearchParameters = AccountingReportsServer.SearchParametersInCompositionTemplateBody();
	SearchParameters.MultipleChoice      = True;
	SearchParameters.PropertyForIdentification = "GroupingField";
	SearchParameters.ReturnType          = "Template";
	GroupTemplateAccount = AccountingReportsServer.PickElementsFromTemplateBody(CompositionTemplate, "Account", SearchParameters);
	TamplatesNameArrayAccount = New Array;
	For Each AccountTemplate In GroupTemplateAccount Do
		TamplatesNameArrayAccount.Add(AccountTemplate.Name);
	EndDo;

	GroupTemplateCurrency = AccountingReportsServer.PickElementsFromTemplateBody(CompositionTemplate, "Currency", SearchParameters);
	TamplatesNameArrayCurrency = New Array;
	For Each CurrencyTemplate In GroupTemplateCurrency Do
		TamplatesNameArrayCurrency.Add(CurrencyTemplate.Name);
	EndDo;
	
	ResourceGroupingTemplateCurrency = New Array;
	AccountingReportsServer.FillTemplatesOfGroupingResources(CurrentDataCompositionTemplateTable.Rows, ResourceGroupingTemplateCurrency, MapTemplatesToReportColumns, "Currency", True);

	If ReportParameters.CurrencyAmount Then
		For Each Template In CompositionTemplate.Templates Do

			If ReportHeaderTemplates.Find(Template.Name) = Undefined Then
				
				If TamplatesNameArrayCurrency.Find(Template.Name) <> Undefined Or ResourceGroupingTemplateCurrency.Find(Template.Name) <> Undefined Then
					
				ElsIf Template.Template.Count() > 1 Then
					
					Template.Template.Delete(Template.Template.Count() - 1);
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	TotalsValues = New Structure;
	
	For Each Column In CurrentDataCompositionTemplateTable.Columns Do
		
		TotalsValues.Insert(Column.Body[0].Template, New Array(TotalsCount, 2));
		
		For Each Array In TotalsValues[Column.Body[0].Template] Do
			For Index = 0 To 1 Do
				Array[Index] = 0;
			EndDo;
		EndDo;
		
	EndDo;
	
	TemporaryReportData = New Structure;
	
	TemporaryReportData.Insert("TotalsCount",						TotalsCount);
	TemporaryReportData.Insert("AccountResourcesTemplates",			AccountResourcesTemplates);
	TemporaryReportData.Insert("ReportFooterResourcesTemplates",	ReportFooterResourcesTemplates);
	TemporaryReportData.Insert("MapTemplatesToReportColumns",		MapTemplatesToReportColumns);
	TemporaryReportData.Insert("TemplateCurrency",					TamplatesNameArrayCurrency);
	TemporaryReportData.Insert("ReportHeaderTemplate",				ReportHeaderTemplates);
	TemporaryReportData.Insert("TemplateAccount",					TamplatesNameArrayAccount);
	TemporaryReportData.Insert("TotalsValues",						TotalsValues);
	TemporaryReportData.Insert("CurrentAccount",					Undefined);
	TemporaryReportData.Insert("PreviousRootAccount",				Undefined);
	TemporaryReportData.Insert("PreviousRootAccountTemplates",	New Array);
	
	ReportParameters.Insert("TemporaryReportData", TemporaryReportData);
	
EndProcedure

Procedure BeforeOutputElementResult(ReportParameters, CompositionTemplate, DetailsData, ResultItem, Cancel = False)
	
	If ResultItem.ParameterValues.Count() > 0
		And ResultItem.ParameterValues.Find("P1") <> Undefined
		And ValueIsFilled(ResultItem.Template)
		And ReportParameters.TemporaryReportData.TemplateCurrency.Find(ResultItem.Template) <> Undefined
		And ResultItem.ParameterValues.P1.Value = Null Then
		Cancel = True;
		Return;
	EndIf;

	If ReportParameters.CurrencyAmount
		And ReportParameters.TemporaryReportData.TotalsCount > 1 Then
		TotalsCount = ReportParameters.TemporaryReportData.TotalsCount - 1;
	Else
		TotalsCount = ReportParameters.TemporaryReportData.TotalsCount;
	EndIf;

	If ResultItem.ParameterValues.Count() > 0 
		And ResultItem.ParameterValues.Find("P1") <> Undefined
		And ValueIsFilled(ResultItem.Template)
		And ReportParameters.TemporaryReportData.ReportHeaderTemplate.Find(ResultItem.Template) = Undefined
		And ReportParameters.TemporaryReportData.ReportFooterResourcesTemplates.Find(ResultItem.Template) = Undefined Then

		If ReportParameters.TemporaryReportData.TemplateAccount.Find(ResultItem.Template) <> Undefined Then
			
			ReportParameters.TemporaryReportData.CurrentAccount = Undefined;
			
			For Each Parameter In ResultItem.ParameterValues Do
				If TypeOf(Parameter.Value) = Type("DataCompositionDetailsID") Then
					
					ReportParameters.TemporaryReportData.CurrentAccount = DetailsData.Items[Parameter.Value].GetFields()[0].Value;;
					Break;
					
				EndIf;
			EndDo;
			
		EndIf;
		
		If ReportParameters.TemporaryReportData.AccountResourcesTemplates.Find(ResultItem.Template) <> Undefined 
			And ValueIsFilled(ReportParameters.TemporaryReportData.CurrentAccount)
			And Not ValueIsFilled(ReportParameters.TemporaryReportData.CurrentAccount.Parent) 
			And CompositionTemplate.Templates[ResultItem.Template].Template.Count() > 0 Then
			
			ResultColumn = ReportParameters.TemporaryReportData.MapTemplatesToReportColumns.Get(ResultItem.Template);
			If ResultColumn = Undefined Then
				Return;
			EndIf;

			If ReportParameters.TemporaryReportData.CurrentAccount = ReportParameters.TemporaryReportData.PreviousRootAccount Then
				
				If ReportParameters.TemporaryReportData.PreviousRootAccountTemplates.Find(ResultColumn) = Undefined Then

					ReportParameters.TemporaryReportData.PreviousRootAccountTemplates.Add(ResultColumn);
					
				Else

					Return;
					
				EndIf;
				
			Else

				ReportParameters.TemporaryReportData.PreviousRootAccount = ReportParameters.TemporaryReportData.CurrentAccount;
				ReportParameters.TemporaryReportData.PreviousRootAccountTemplates = CommonClientServer.ValueInArray(ResultColumn);

			EndIf;

			For ItemIndex = 0 To TotalsCount - 1 Do
				
				TemplateRow = CompositionTemplate.Templates[ResultItem.Template].Template[ItemIndex];
				
				For Each Cell In TemplateRow.Cells Do
					
					If Cell.Items.Count() = 0 Then
						Continue;
					EndIf;
					
					For Each Item In Cell.Items Do
						
						ParameterName = String(Item.Value);
						ResultParameter = ResultItem.ParameterValues.Find(ParameterName);
						If ResultParameter = Undefined Or ResultParameter.Value = Null Then
							Continue;
						EndIf;
						
						CellIndex = TemplateRow.Cells.IndexOf(Cell);
						TotalForColumn = ReportParameters.TemporaryReportData.TotalsValues[ResultColumn];
						CurrentTotalValue = TotalForColumn[ItemIndex][CellIndex];
						TotalForColumn[ItemIndex][CellIndex] = CurrentTotalValue + ResultParameter.Value;
						
					EndDo;
					
				EndDo;
				
			EndDo;
			
		EndIf; 

	ElsIf ReportParameters.TemporaryReportData.ReportFooterResourcesTemplates.Find(ResultItem.Template) <> Undefined Then

		ResultColumn = ReportParameters.TemporaryReportData.MapTemplatesToReportColumns.Get(ResultItem.Template);

		If ResultColumn <> Undefined Then

			For Each TemplateRow In CompositionTemplate.Templates[ResultItem.Template].Template Do

				ItemIndex = CompositionTemplate.Templates[ResultItem.Template].Template.IndexOf(TemplateRow);

				For Each Cell In TemplateRow.Cells Do

					CellIndex =  TemplateRow.Cells.IndexOf(Cell);

					For Each Item In Cell.Items Do

						ParameterName = String(Item.Value);
						ItemParameter = ResultItem.ParameterValues.Find(ParameterName);

						If ItemParameter = Undefined Then
							
							ItemParameter = ResultItem.ParameterValues.Add();
							ItemParameter.Name = ParameterName;
							
						EndIf;
						
						ItemParameter.Value = ReportParameters.TemporaryReportData.TotalsValues[ResultColumn][ItemIndex][CellIndex];
						
					EndDo;

				EndDo;

			EndDo;

		EndIf;

	EndIf;
	
EndProcedure

Function GetReportItems()
	
	ReportItems = New Array;
	ReportItems.Add("PresentationCurrency");
	ReportItems.Add("CurrencyAmount");
	
	Return ReportItems;
	
EndFunction

Function PrepareReportParameters(ReportSettings)
	ReportParameters = New Structure;
	
	ReportStructure = Undefined;
	
	ParameterReportStructure = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("ReportStructure"));
	If ParameterReportStructure <> Undefined Then
		
		ReportStructure = ParameterReportStructure.Value.Get();
	EndIf;
	
	If ReportStructure <> Undefined Then
		
		ReportParameters.Insert("PresentationCurrency"			, ReportStructure.PresentationCurrency);
		ReportParameters.Insert("CurrencyAmount"				, ReportStructure.CurrencyAmount);
		ReportParameters.Insert("AccountName"					, ReportStructure.AccountName);
		ReportParameters.Insert("DetailedBalance"				, ReportStructure.DetailedBalance);
		ReportParameters.Insert("DisplayParametersAndFilters"	, ReportStructure.DisplayParametersAndFilters);
		ReportParameters.Insert("HighlightNegativeValues"		, ReportStructure.HighlightNegativeValues);
		ReportParameters.Insert("ReportTitle"					, ReportStructure.ReportTitle);
		ReportParameters.Insert("Grouping"						, ReportStructure.ReportStructure);
	Else	
		
		ReportParameters.Insert("PresentationCurrency"			, True);
		ReportParameters.Insert("CurrencyAmount"				, False);
		ReportParameters.Insert("AccountName"					, False);
		ReportParameters.Insert("DetailedBalance"				, False);
		ReportParameters.Insert("DisplayParametersAndFilters"	, False);
		ReportParameters.Insert("HighlightNegativeValues"		, False);
		ReportParameters.Insert("ReportTitle"					, False);
		ReportParameters.Insert("Grouping"						, New ValueTable);
		
	EndIf;
	
	BeginOfPeriod = Date(1,1,1);
	EndOfPeriod  = Date(1,1,1);
	TitleOutput = False;
	Title = NStr("en = 'Trial balance'; ru = 'Оборотно-сальдовая ведомость';pl = 'Zestawienie obrotów i sald';es_ES = 'Saldo de prueba';es_CO = 'Saldo de prueba';tr = 'Mizan';it = 'Bilancio di prova';de = 'Saldenbilanz'");
	ParametersToBeIncludedInSelectionText = New Array;
	
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
	
	
	TitleOutput					= ReportParameters.ReportTitle;
	ParametersAndFiltersOutput	= ReportParameters.DisplayParametersAndFilters;
	
	OutputParameter = ReportSettings.OutputParameters.FindParameterValue(New DataCompositionParameter("Title"));
	If OutputParameter <> Undefined
		AND OutputParameter.Use Then
		Title = OutputParameter.Value;
	EndIf;
	
	ParameterCompany			= ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("Company"));
	ParameterChartOfAccounts	= ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("ChartOfAccounts"));
	ParameterTypeOfAccounting	= ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("TypeOfAccounting"));
	
	If ParameterCompany <> Undefined
		AND ParameterCompany.Use Then
		
		ParameterCompany.UserSettingPresentation = NStr("en = 'Company'; ru = 'Организация';pl = 'Firma';es_ES = 'Empresa';es_CO = 'Empresa';tr = 'İş yeri';it = 'Azienda';de = 'Firma'");
		ParametersToBeIncludedInSelectionText.Add(ParameterCompany);
	EndIf;
	
	If ParameterChartOfAccounts <> Undefined
		AND ParameterChartOfAccounts.Use Then
		
		ParameterChartOfAccounts.UserSettingPresentation = NStr("en = 'Chart of accounts'; ru = 'План счетов';pl = 'Plan kont';es_ES = 'Diagrama primario de las cuentas';es_CO = 'Diagrama primario de las cuentas';tr = 'Hesap planı';it = 'Piano dei conti';de = 'Kontenplan'");
		ParametersToBeIncludedInSelectionText.Add(ParameterChartOfAccounts);
	EndIf;
	
	If ParameterTypeOfAccounting <> Undefined
		AND ParameterTypeOfAccounting.Use Then
		
		ParameterTypeOfAccounting.UserSettingPresentation = NStr("en = 'Type of accounting'; ru = 'Тип бухгалтерского учета';pl = 'Typ rachunkowości';es_ES = 'Tipo de contabilidad';es_CO = 'Tipo de contabilidad';tr = 'Muhasebe türü';it = 'Tipo di contabilità';de = 'Typ der Buchhaltung'");
		ParametersToBeIncludedInSelectionText.Add(ParameterTypeOfAccounting);
	EndIf;
	
	ReportParameters.Insert("BeginOfPeriod"							, BeginOfPeriod);
	ReportParameters.Insert("EndOfPeriod"							, EndOfPeriod);
	ReportParameters.Insert("TitleOutput"							, TitleOutput);
	ReportParameters.Insert("ParametersAndFiltersOutput"			, ParametersAndFiltersOutput);
	ReportParameters.Insert("ParametersToBeIncludedInSelectionText"	, ParametersToBeIncludedInSelectionText);
	ReportParameters.Insert("Title"									, Title);
	ReportParameters.Insert("ReportId"								, "TrialBalance");
	ReportParameters.Insert("ReportSettings"						, ReportSettings);
	
	ReportParameters.Insert("ReportItems", GetReportItems());
	
	Return ReportParameters;
	
EndFunction

#EndRegion

#EndIf