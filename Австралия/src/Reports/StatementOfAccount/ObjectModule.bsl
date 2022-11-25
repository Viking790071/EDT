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

Function PrepareReportParameters(ReportSettings)
	
	BeginOfPeriod = Date(1,1,1);
	EndOfPeriod  = Date(1,1,1);
	Period = Date(1,1,1);
	TitleOutput = False;
	Title = "StatementOfAccount";
	
	VariantBalance = False;
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("EndOfPeriod"));
	If ParameterPeriod <> Undefined AND ParameterPeriod.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
		VariantBalance = True;
		If ParameterPeriod.Use Then
			If TypeOf(ParameterPeriod.Value) = Type("StandardBeginningDate") Then
				ParameterPeriod.Value.Date = EndOfDay(ParameterPeriod.Value.Date);
				Period = Format(ParameterPeriod.Value.Date, "DLF=D");
			Else
				ParameterPeriod.Value = EndOfDay(ParameterPeriod.Value);
				Period = Format(ParameterPeriod.Value, "DLF=D");
			EndIf;
		EndIf;
	EndIf;
	
	If Not VariantBalance Then
		ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("Period"));
		If ParameterPeriod <> Undefined AND ParameterPeriod.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
			If ParameterPeriod.Use
				AND ValueIsFilled(ParameterPeriod.Value) Then
				
				BeginOfPeriod = ParameterPeriod.Value.StartDate;
				EndOfPeriod  = ParameterPeriod.Value.EndDate;
			EndIf;
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
	If VariantBalance Then
		ReportParameters.Insert("Period"               , Period);
	Else
		ReportParameters.Insert("BeginOfPeriod"        , BeginOfPeriod);
		ReportParameters.Insert("EndOfPeriod"         , EndOfPeriod);
	EndIf;
	ReportParameters.Insert("TitleOutput"        , TitleOutput);
	ReportParameters.Insert("Title"                , Title);
	ReportParameters.Insert("ReportId"      , "StatementOfAccount");
	ReportParameters.Insert("ReportSettings", ReportSettings);
		
	Return ReportParameters;
	
EndFunction

#EndRegion

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// The settings of the common report form of the "Reports options" subsystem.
//
// Parameters:
//   Form - ClientApplicationForm, Undefined - a report form or a report settings form.
//       Undefined when called without a context.
//   OptionKey - String, Undefined - a name of a predefined report option or a UUID of a 
//       user-defined report option.
//       Undefined when called without a context.
//   Settings - Structure - see the return value of
//       ReportsClientServer.GetDefaultReportSettings().
//
Procedure DefineFormSettings(Form, OptionKey, Settings) Export
	
	If UsersClientServer.IsExternalUserSession() Then
		OptionKey = "StatementInCurrencyForExternalUsers";
		Settings.Events.OnCreateAtServer = True;
		Settings.Events.OnLoadVariantAtServer = True;
		Settings.Events.OnLoadUserSettingsAtServer = True;
	EndIf;
	
EndProcedure

Procedure OnCreateAtServer(Form, Cancel, StandardProcessing) Export
	
	Form.Items.ReportOptionsGroup.Visible		= False;
	Form.Items.OtherReportSettingsGroup.Visible = False;
	Form.Items.AllSettings.Visible				= False;
	Form.Items.ReportOptions.Visible			= False;
	Form.Items.ChangeOption.Visible				= False;
	Form.Items.SelectOption.Visible				= False;

	CommonClientServer.SetFormItemProperty(
		Form.Items,
		"SaveOption",
		"Visible",
		False); // If the command is unavailable due to rights, the button disappears.
		
	Form.Items.EditFilterCriteria.Visible = False;
		
	CommonClientServer.SetFormItemProperty(
		Form.Items,
		"SelectSettings",
		"Visible",
		False); // If the command is unavailable due to rights, the button disappears.
	CommonClientServer.SetFormItemProperty(
		Form.Items,
		"SaveSettings",
		"Visible",
		False); // If the command is unavailable due to rights, the button disappears.
		
	CommonClientServer.SetFormItemProperty(Form.Items, "SaveOption", "Visible", False);

EndProcedure

Procedure OnLoadVariantAtServer(ReportForm, Settings) Export
	
	ExternalUserAuthorizationData = ExternalUsers.ExternalUserAuthorizationData();
	Counterparty = ExternalUserAuthorizationData.AuthorizedCounterparty;
	
	If ValueIsFilled(Counterparty) Then
		
		ReportSettings = ReportForm.Report.SettingsComposer.Settings;
		ReportFilter = ReportSettings.Filter;
		
		CommonClientServer.SetFilterItem(ReportFilter, "Counterparty", Counterparty);
		
		DoOperationsByContracts = Common.ObjectAttributeValue(Counterparty, "DoOperationsByContracts");
		If DoOperationsByContracts Then
			Query = New Query;
			Query.Text = "SELECT ALLOWED
			|	CounterpartyContracts.Ref AS Ref
			|FROM
			|	Catalog.CounterpartyContracts AS CounterpartyContracts
			|WHERE
			|	NOT CounterpartyContracts.DeletionMark
			|	AND CounterpartyContracts.Owner = &Owner
			|	AND (CounterpartyContracts.VisibleToExternalUsers
			|			OR &UseContractRestrictionsTurnOff)";
			Query.SetParameter("Owner", Counterparty);
			Query.SetParameter("UseContractRestrictionsTurnOff", 
				Not GetFunctionalOption("UseContractRestrictionsForExternalUsers"));
				
			Selection = Query.Execute().Select();
			If Selection.Count() = 1 Then
				Selection.Next();
				
				CommonClientServer.SetFilterItem(ReportFilter,
					"Contract",
					Selection.Ref,
					,
					,
					True,
					DataCompositionSettingsItemViewMode.Inaccessible);
			ElsIf Selection.Count() > 1 Then
				Contracts = New Array;
				While Selection.Next() Do
					Contracts.Add(Selection.Ref);
				EndDo;
				CommonClientServer.SetFilterItem(ReportFilter, "ContractForExternalUser", Contracts);
			EndIf;
		Else
			CommonClientServer.SetFilterItem(ReportFilter,
				"Contract",
				Catalogs.CounterpartyContracts.EmptyRef(),
				,
				,
				False,
				DataCompositionSettingsItemViewMode.Inaccessible);
		EndIf;
		
		Query = New Query;
		Query.Text = "SELECT ALLOWED
		|	Companies.Ref AS Ref
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	NOT Companies.DeletionMark";
		
		Selection = Query.Execute().Select();
		If Selection.Count() = 1 Then
			Selection.Next();
			
			CommonClientServer.SetFilterItem(ReportFilter,
				"Company",
				Selection.Ref,
				,
				,
				True,
				DataCompositionSettingsItemViewMode.Inaccessible);
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure OnLoadUserSettingsAtServer(ReportForm, Settings) Export
	
	ExternalUserAuthorizationData = ExternalUsers.ExternalUserAuthorizationData();
	Counterparty = ExternalUserAuthorizationData.AuthorizedCounterparty;
	
	If ValueIsFilled(Counterparty) Then
		
		UserSettings = ReportForm.Report.SettingsComposer.UserSettings;
		
		If UserSettings.AdditionalProperties.Property("FormItems") Then
		
			FormItems = UserSettings.AdditionalProperties.FormItems;
			
			For Each SettingsItem In UserSettings.Items Do
				
				UserSettingID = SettingsItem.UserSettingID;
				FormItem = FormItems.Get(ReportsClientServer.CastIDToName(UserSettingID));
				
				If FormItem <> Undefined Then
					
					If FormItem.Presentation = "Counterparty" Then
						
						SettingsItem.Use = True;
						SettingsItem.RightValue = Counterparty;
						
					EndIf;
					
				EndIf;
				
			EndDo;
		
		EndIf;
		
	EndIf;
	
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf