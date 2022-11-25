
// Opens a predefined report option
//
// Parameters:
//  Variant  - Structure - description of a report option:
//     * ReportName           - String - report
//     name * VariantKey        - String - key of a report option
//
Procedure OpenReportOption(Variant) Export
	
	OpenParameters = New Structure;
	OpenParameters.Insert("VariantKey", Variant.VariantKey);
	
	Uniqueness = "Report." + Variant.ReportName + "/VariantKey." + Variant.VariantKey;
	
	OpenParameters.Insert("PrintParametersKey",        Uniqueness);
	OpenParameters.Insert("WindowOptionsKey", Uniqueness);
	
	OpenForm("Report." + Variant.ReportName + ".Form", OpenParameters, Undefined, Uniqueness);
	
EndProcedure

Procedure DetailProcessing(ThisForm, Item, Details, StandardProcessing) Export
	
	If ThisForm.UniqueKey = "Report.AccountsReceivableTrend/VariantKey.DebtDynamics" Then
		
		StandardProcessing = False;
		
		ReportOptionProperties = New Structure("VariantKey, ObjectKey",
			"Default", "Report.AccountsReceivableAging");
		
		ReportVariantSettingsLinker = DriveReportsServerCall.ReportVariantSettingsLinker(ReportOptionProperties);
		If ReportVariantSettingsLinker = Undefined Then
			Return;
		EndIf;
		
		CurrentVariantSettingsLinker = ThisForm.Report.SettingsComposer;
		CopyFilter(ReportVariantSettingsLinker, CurrentVariantSettingsLinker);
		
		ReportVariantUserSettings = ReportVariantSettingsLinker.UserSettings;
		
		PeriodValue = DriveReportsServerCall.ReceiveDecryptionValue("Period", Details, ThisForm.ReportDetailsData);
		If PeriodValue <> Undefined Then
			LayoutParameter = New DataCompositionParameter("PeriodUs");
			For Each SettingItem In ReportVariantUserSettings.Items Do
				If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") AND SettingItem.Parameter = LayoutParameter Then
					ParameterValue = SettingItem;
					If TypeOf(ParameterValue.Value) = Type("StandardBeginningDate") Then
						ParameterValue.Value.Variant = StandardBeginningDateVariant.Custom;
						ParameterValue.Value.Date = PeriodValue;
						ParameterValue.Use = True;
					EndIf;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		ReportParameters = New Structure("UserSettings, 
											|VariantKey, 
											|PurposeUseKey, 
											|GenerateOnOpen",
											ReportVariantUserSettings,
											ReportOptionProperties.VariantKey,
											"CustomersDebtDynamicsDecryption",
											True);
		
		OpenForm("Report.AccountsReceivableAging.Form", ReportParameters);
		
	ElsIf ThisForm.UniqueKey = "Report.AccountsPayableTrend/VariantKey.DebtDynamics" Then
		
		StandardProcessing = False;
		
		ReportOptionProperties = New Structure("VariantKey, ObjectKey",
			"Default", "Report.AccountsPayableAging");
		
		ReportVariantSettingsLinker = DriveReportsServerCall.ReportVariantSettingsLinker(ReportOptionProperties);
		If ReportVariantSettingsLinker = Undefined Then
			Return;
		EndIf;
		
		CurrentVariantSettingsLinker = ThisForm.Report.SettingsComposer;
		CopyFilter(ReportVariantSettingsLinker, CurrentVariantSettingsLinker);
		
		ReportVariantUserSettings = ReportVariantSettingsLinker.UserSettings;
		
		PeriodValue = DriveReportsServerCall.ReceiveDecryptionValue("DynamicPeriod", Details, ThisForm.ReportDetailsData);
		If PeriodValue <> Undefined Then
			LayoutParameter = New DataCompositionParameter("PeriodUs");
			For Each SettingItem In ReportVariantUserSettings.Items Do
				If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") AND SettingItem.Parameter = LayoutParameter Then
					ParameterValue = SettingItem;
					If TypeOf(ParameterValue.Value) = Type("StandardBeginningDate") Then
						ParameterValue.Value.Variant = StandardBeginningDateVariant.Custom;
						ParameterValue.Value.Date = PeriodValue;
						ParameterValue.Use = True;
					EndIf;
					
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		ReportParameters = New Structure("UserSettings, 
											|VariantKey, 
											|PurposeUseKey, 
											|GenerateOnOpen",
											ReportVariantUserSettings,
											ReportOptionProperties.VariantKey,
											"DebtToVendorsDynamicsDecryption",
											True);
		
		OpenForm("Report.AccountsPayableAging.Form", ReportParameters);
		
	ElsIf ThisForm.FormName = "Report.SalesFunnel.Form" Then
	
		If ThisForm.FormOwner = Undefined Then
			
			ReportOptionProperties = New Structure("VariantKey, ObjectKey",
				ThisForm.CurrentVariantKey, "Report.SalesFunnel");
			
			ReportVariantSettingsLinker = DriveReportsServerCall.ReportVariantSettingsLinker(ReportOptionProperties);
			If ReportVariantSettingsLinker = Undefined Then
				Return;
			EndIf;
			
			StandardProcessing = False;
			
			CurrentVariantSettingsLinker = ThisForm.Report.SettingsComposer;
			CopyFilter(ReportVariantSettingsLinker, CurrentVariantSettingsLinker);
			
			ReportVariantUserSettings = ReportVariantSettingsLinker.UserSettings;
			
			For Each SettingItem In CurrentVariantSettingsLinker.UserSettings.Items Do
				
				For Each ReportVariantSettingItem In ReportVariantUserSettings.Items Do
					
					If SettingItem.Parameter = ReportVariantSettingItem.Parameter Then
						
						ReportVariantSettingItem.Value = SettingItem.Value;
						Break;
						
					EndIf;
					
				EndDo;
				
			EndDo;
			
			// Filter
			ReportVariantUserSettings.AdditionalProperties.Insert("FilterStructure",
				DriveReportsServerCall.GetDetailsDataStructure(Details, ThisForm.ReportDetailsData));
			
			ReportVariantUserSettings.AdditionalProperties.Insert("DrillDown", True);
			
			ReportParameters = New Structure();
			ReportParameters.Insert("UserSettings", ReportVariantUserSettings);
			ReportParameters.Insert("VariantKey", ReportOptionProperties.VariantKey);
			ReportParameters.Insert("GenerateOnOpen", True);
			
			OpenForm("Report.SalesFunnel.Form", ReportParameters, ThisForm, True);
			
		EndIf;
	
	ElsIf ThisForm.FormName = "Report.SalesPipeline.Form" Then
		
		If ThisForm.FormOwner = Undefined Then
			
			ReportOptionProperties = New Structure("VariantKey, ObjectKey",
				ThisForm.CurrentVariantKey, "Report.SalesPipeline");
			
			ReportVariantSettingsLinker = DriveReportsServerCall.ReportVariantSettingsLinker(ReportOptionProperties);
			If ReportVariantSettingsLinker = Undefined Then
				Return;
			EndIf;
			
			StandardProcessing = False;
			
			CurrentVariantSettingsLinker = ThisForm.Report.SettingsComposer;
			CopyFilter(ReportVariantSettingsLinker, CurrentVariantSettingsLinker);
			
			ReportVariantUserSettings = ReportVariantSettingsLinker.UserSettings;
			
			For Each SettingItem In CurrentVariantSettingsLinker.UserSettings.Items Do
				
				For Each ReportVariantSettingItem In ReportVariantUserSettings.Items Do
					
					If SettingItem.Parameter = ReportVariantSettingItem.Parameter Then
						
						ReportVariantSettingItem.Value = SettingItem.Value;
						Break;
						
					EndIf;
					
				EndDo;
				
			EndDo;
			
			// Filter
			ReportVariantUserSettings.AdditionalProperties.Insert("FilterStructure",
				DriveReportsServerCall.GetDetailsDataStructure(Details, ThisForm.ReportDetailsData));
			
			ReportVariantUserSettings.AdditionalProperties.Insert("DrillDown", True);
			
			ReportParameters = New Structure();
			ReportParameters.Insert("UserSettings", ReportVariantUserSettings);
			ReportParameters.Insert("VariantKey", ReportOptionProperties.VariantKey);
			ReportParameters.Insert("GenerateOnOpen", True);
			
			OpenForm("Report.SalesPipeline.Form", ReportParameters, ThisForm, True);
			
		EndIf;
		
	ElsIf ThisForm.FormName = "Report.QuotationPipeline.Form" Then
		
		If ThisForm.FormOwner = Undefined Then
			
			ReportOptionProperties = New Structure("VariantKey, ObjectKey",
				ThisForm.CurrentVariantKey, "Report.QuotationPipeline");
			
			ReportVariantSettingsLinker = DriveReportsServerCall.ReportVariantSettingsLinker(ReportOptionProperties);
			If ReportVariantSettingsLinker = Undefined Then
				Return;
			EndIf;
			
			StandardProcessing = False;
			
			CurrentVariantSettingsLinker = ThisForm.Report.SettingsComposer;
			CopyFilter(ReportVariantSettingsLinker, CurrentVariantSettingsLinker);
			
			ReportVariantUserSettings = ReportVariantSettingsLinker.UserSettings;
			
			For Each SettingItem In CurrentVariantSettingsLinker.UserSettings.Items Do
				
				For Each ReportVariantSettingItem In ReportVariantUserSettings.Items Do
					
					If SettingItem.Parameter = ReportVariantSettingItem.Parameter Then
						
						ReportVariantSettingItem.Value = SettingItem.Value;
						Break;
						
					EndIf;
					
				EndDo;
				
			EndDo;
			
			// Filter
			ReportVariantUserSettings.AdditionalProperties.Insert("FilterStructure",
				DriveReportsServerCall.GetDetailsDataStructure(Details, ThisForm.ReportDetailsData));
			
			ReportVariantUserSettings.AdditionalProperties.Insert("DrillDown", True);
			
			ReportParameters = New Structure();
			ReportParameters.Insert("UserSettings", ReportVariantUserSettings);
			ReportParameters.Insert("VariantKey", ReportOptionProperties.VariantKey);
			ReportParameters.Insert("GenerateOnOpen", True);
			
			OpenForm("Report.QuotationPipeline.Form", ReportParameters, ThisForm, True);
			
		EndIf;
	ElsIf ThisForm.FormName = "Report.TrialBalanceMaster.Form" Then
		
		ReportOptionProperties = New Structure("VariantKey, ObjectKey",
			"Default", "Report.AccountStatement");
		
		ReportVariantSettingsLinker = DriveReportsServerCall.ReportVariantSettingsLinker(ReportOptionProperties);
		If ReportVariantSettingsLinker = Undefined Then
			Return;
		EndIf;
		
		StandardProcessing = False;
		
		CurrentVariantSettingsLinker = ThisForm.Report.SettingsComposer;
		CopyFilter(ReportVariantSettingsLinker, CurrentVariantSettingsLinker);
		
		ReportVariantUserSettings = ReportVariantSettingsLinker.UserSettings;
		
		For Each SettingItem In CurrentVariantSettingsLinker.UserSettings.Items Do
			
			For Each ReportVariantSettingItem In ReportVariantUserSettings.Items Do
				
				If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") 
					And TypeOf(ReportVariantSettingItem) = Type("DataCompositionSettingsParameterValue") Then
					If SettingItem.Parameter = ReportVariantSettingItem.Parameter Then
						
						ReportVariantSettingItem.Value = SettingItem.Value;
						Break;
						
					EndIf;
				EndIf;
				
			EndDo;
			
		EndDo;
		
		ReportParameters = New Structure();
		ReportParameters.Insert("UserSettings", ReportVariantUserSettings);
		ReportParameters.Insert("VariantKey", "Default");
		ReportParameters.Insert("GenerateOnOpen", True);
		
		FilterStructure = DriveReportsServerCall.GetDetailsDataStructure(Details, ThisForm.ReportDetailsData, False);
		
		If FilterStructure.Property("Account") Then
			
			ParameterAccount = New DataCompositionParameter("Account");
			
			For Each ReportVariantSettingItem In ReportVariantUserSettings.Items Do
				
				If TypeOf(ReportVariantSettingItem) = Type("DataCompositionSettingsParameterValue") Then
					
					If ReportVariantSettingItem.Parameter = ParameterAccount Then
						ReportVariantSettingItem.Value = FilterStructure.Account;
						Break;
					EndIf;
					
				EndIf;
				
			EndDo;
			
			FilterStructure.Delete("Account");
		EndIf;
		
		ReportVariantUserSettings.AdditionalProperties.Insert("FilterStructure",
			FilterStructure);
		
	ElsIf ThisForm.ReportSettings.FullName = "Report.TrialBalanceMaster" Then
		
		CurrentVariantSettings = ThisForm.Report.SettingsComposer;
		
		ReportName = ReportNameByFullName(ThisForm.ReportSettings.FullName);
		StandardProcessing = False;
	
		PossibleDetailReports = DriveReportsServerCall.PossibleDetailReports(ReportName, ThisForm.ReportDetailsData, Details);
		
		If PossibleDetailReports.Count() = 0 Then
			Return;
		EndIf;
		
		IsFilterSet = False;
		For Each FilterItem In CurrentVariantSettings.Settings.Filter.Items Do
			
			If FilterItem.Use Then
				
				IsFilterSet = True;
				Break;
				
			EndIf;
			
		EndDo;
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ReportDetailsData"		, ThisForm.ReportDetailsData);
		AdditionalParameters.Insert("Details"				, Details);
		AdditionalParameters.Insert("ReportName"			, ReportName);
		AdditionalParameters.Insert("CurrentVariantSettings", CurrentVariantSettings);
		
		If PossibleDetailReports.Count() = 1 Then
			
			AdditionalParameters.Insert("DetailsValue"			, PossibleDetailReports[0].Value);
			
			If IsFilterSet Then
				ShowFiltersQueryBox(AdditionalParameters);
			Else
				DetailProcessingEnd(DialogReturnCode.Yes, AdditionalParameters);
			EndIf;
			
		Else
			
			AdditionalParameters.Insert("IsFilterSet"			, IsFilterSet);
			
			Notify = New NotifyDescription("SelectingPossibleDetailReport", ThisObject, AdditionalParameters);
			ThisForm.ShowChooseFromMenu(Notify, PossibleDetailReports, Item);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure ShowFiltersQueryBox(AdditionalParameters)
	
	Notification = New NotifyDescription("DetailProcessingEnd", DriveReportsClient, AdditionalParameters);
	
	QueryText = NStr("en = 'Filters are added to the current report settings. They will not apply to the report details you are about to view. To apply the filters, you will need to add them manually. Do you want to view the report details?'; ru = 'К текущим настройкам отчета добавлены отборы. Они не будут применяться к отчету, который вы собираетесь просмотреть. Для применения отборов добавьте их вручную. Просмотреть отчет?';pl = 'Filtry są dodane do ustawień bieżącego raportu. One nie będą zastosowane do szczegółów raportu, który zamierzasz wyświetlić. Aby zastosować filtry, należy dodać je ręcznie. Czy chcesz wyświetlić szczegóły raportu?';es_ES = 'Los filtros se añaden a la configuración actual del informe. No se aplicarán a los detalles del informe que vas a ver. Para aplicar los filtros, tendrás que añadirlos manualmente. ¿Quieres ver los detalles del informe?';es_CO = 'Los filtros se añaden a la configuración actual del informe. No se aplicarán a los detalles del informe que vas a ver. Para aplicar los filtros, tendrás que añadirlos manualmente. ¿Quieres ver los detalles del informe?';tr = 'Mevcut rapor ayarlarına filtreler eklendi. Bunlar görüntülemek üzere olduğunuz rapor bilgilerine uygulanmayacak. Filtreleri uygulamak için manuel olarak eklemeniz gerekecek. Rapor bilgilerini görüntülemek istiyor musunuz?';it = 'I filtri sono aggiunti alle impostazioni di report corrente. Non saranno applicati ai dettagli di report che stai per visualizzare. Per applicare i filtri, sarà necessario aggiungerli manualmente. Visualizzare i dettagli di report?';de = 'Filter sind zu den aktuellen Berichtseinstellungen hinzugefügt. Sie werden nicht für die Berichtsdetails, die Sie ansehen möchten, verwendet. Um diese Filter zu verwenden, müssen Sie diese manuell hinzufügen. Möchten Sie die Berichtsdetails ansehen?'");
	ShowQueryBox(Notification, QueryText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	
EndProcedure

Procedure DetailProcessingEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		ShowDetailReport(
			AdditionalParameters.DetailsValue,
			AdditionalParameters.ReportDetailsData,
			AdditionalParameters.Details,
			AdditionalParameters.ReportName,
			AdditionalParameters.CurrentVariantSettings);
		
	EndIf;
	
EndProcedure

Procedure AdditionalDetailProcessing(Form, Item, Details, StandardProcessing) Export
	
	If Form.ReportSettings.FullName = "Report.TrialBalanceMaster" Then
		Details = Undefined;
	ElsIf UsersClientServer.IsExternalUserSession()
		And (Form.ReportSettings.FullName = "Report.CustomerStatement"
			Or Form.ReportSettings.FullName = "Report.SalesOrdersStatement"
			Or Form.ReportSettings.FullName = "Report.StatementOfAccount") Then
		Details = Undefined;
	EndIf;
	
EndProcedure

Procedure CopyFilter(LinkerReceiver, LinkerSource) Export
	
	ReceiverSettings = LinkerReceiver.Settings;
	SourceSettings = LinkerSource.Settings;
	UserSettingsSource = LinkerSource.UserSettings;
	
	For Each FilterItem In SourceSettings.Filter.Items Do
		If ValueIsFilled(FilterItem.UserSettingID) Then
			
			For Each UserSetting In UserSettingsSource.Items Do
				If UserSetting.UserSettingID = FilterItem.UserSettingID Then
					If TypeOf(UserSetting) = Type("DataCompositionFilterItem")
						AND UserSetting.Use Then
						
						CommonClientServer.SetFilterItem(
							ReceiverSettings.Filter,
							String(FilterItem.LeftValue),
							UserSetting.RightValue,
							UserSetting.ComparisonType,
							,
							True);
						
					EndIf;
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	LinkerReceiver.LoadSettings(ReceiverSettings);

EndProcedure

Procedure SelectingPossibleDetailReport(SelectedItem, AdditionalParameters) Export
	
	If SelectedItem <> Undefined Then
		
		AdditionalParameters.Insert("DetailsValue", SelectedItem.Value);
		
		If AdditionalParameters.IsFilterSet Then
			ShowFiltersQueryBox(AdditionalParameters);
		Else
			DetailProcessingEnd(DialogReturnCode.Yes, AdditionalParameters);
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure ShowDetailReport(DetailsValue, ReportDetailsData, Details, OriginalReportName, CurrentVariantSettings)
	
	If IsReport(DetailsValue) Then
		
		FormParameters = FormParametersStandartReport();
		
		ReportOptionProperties = New Structure("VariantKey, ObjectKey",
			"Default", "Report." + DetailsValue.ReportName);
		
		ReportVariantSettingsLinker = DriveReportsServerCall.ReportVariantSettingsLinker(ReportOptionProperties, True);
		If ReportVariantSettingsLinker = Undefined Then
			Return;
		EndIf;
		
		CopyFilter(ReportVariantSettingsLinker, CurrentVariantSettings);
		
		ReportVariantUserSettings = ReportVariantSettingsLinker.UserSettings;
		
		For Each SettingItem In CurrentVariantSettings.UserSettings.Items Do
			
			For Each ReportVariantSettingItem In ReportVariantUserSettings.Items Do
				
				If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") 
					And TypeOf(ReportVariantSettingItem) = Type("DataCompositionSettingsParameterValue") Then
					If SettingItem.Parameter = ReportVariantSettingItem.Parameter Then
						
						ReportVariantSettingItem.Value = SettingItem.Value;
						ReportVariantSettingItem.Use = SettingItem.Use;
						Break;
						
					EndIf;
				EndIf;
				
			EndDo;
			
		EndDo;
		
		FilterStructure = DriveReportsServerCall.GetDetailsDataStructure(Details, ReportDetailsData, False);
		FilterStructure.Delete("Indicator");
		FilterStructure.Delete("BalancedAccount");
		
		If FilterStructure.Property("Account") Then
			
			ParameterAccount = New DataCompositionParameter("Account");
			
			For Each ReportVariantSettingItem In ReportVariantUserSettings.Items Do
				
				If TypeOf(ReportVariantSettingItem) = Type("DataCompositionSettingsParameterValue") Then
					
					If ReportVariantSettingItem.Parameter = ParameterAccount Then
						ReportVariantSettingItem.Value = FilterStructure.Account;
						ReportVariantSettingItem.Use = True;
						Break;
					EndIf;
					
				EndIf;
				
			EndDo;
			
			FilterStructure.Delete("Account");
		EndIf;
		
		If FilterStructure.Property("Period") Then
			
			ParameterItmPeriod = New DataCompositionParameter("ItmPeriod");
			
			PeriodicityValue = CurrentVariantSettings.Settings.DataParameters.Items.Find("Periodicity").Value;
			ItmPeriodValue = New StandardPeriod;
			ItmPeriodValue.Variant = StandardPeriodVariant.Custom;
			ItmPeriodValue.StartDate = FilterStructure.Period;
			
			If PeriodicityValue = 6 Then
				ItmPeriodValue.EndDate = EndOfDay(FilterStructure.Period);
			ElsIf PeriodicityValue = 7 Then
				ItmPeriodValue.EndDate = EndOfWeek(FilterStructure.Period);
			ElsIf PeriodicityValue = 8 Then
				ItmPeriodValue.EndDate = EndOfDay(FilterStructure.Period + 10*86400);
			ElsIf PeriodicityValue = 9 Then
				ItmPeriodValue.EndDate = EndOfMonth(FilterStructure.Period);
			ElsIf PeriodicityValue = 10 Then
				ItmPeriodValue.EndDate = EndOfQuarter(FilterStructure.Period);
			ElsIf PeriodicityValue = 11 Then
				ItmPeriodValue.EndDate = AddMonth(FilterStructure.Period, 6);
			ElsIf PeriodicityValue = 12 Then
				ItmPeriodValue.EndDate = EndOfYear(FilterStructure.Period);
			EndIf;
			
			For Each ReportVariantSettingItem In ReportVariantUserSettings.Items Do
				
				If TypeOf(ReportVariantSettingItem) = Type("DataCompositionSettingsParameterValue") Then
					
					If ReportVariantSettingItem.Parameter = ParameterItmPeriod Then
						ReportVariantSettingItem.Value = ItmPeriodValue;
						ReportVariantSettingItem.Use = True;
						Break;
					EndIf;
					
				EndIf;
				
			EndDo;
			
			FilterStructure.Delete("Period");
		EndIf;
		
		FormParameters.GenerateOnOpen			= True;
		FormParameters.ReportDetailsData		= ReportDetailsData;
		FormParameters.Details					= Details;
		FormParameters.ReportName				= DetailsValue.ReportName;
		FormParameters.Filter					= FilterStructure;
		FormParameters.OriginalReportName		= OriginalReportName;
		FormParameters.DetailsRuleAttributes	= DetailsValue.AttributeValues;
		FormParameters.UserSettings				= ReportVariantUserSettings;
		
		OpenForm("Report." + DetailsValue.ReportName + ".Form", FormParameters, , True);
		
	Else
		
		ShowValue( , DetailsValue);
		
	EndIf;
	
EndProcedure

Function FormParametersStandartReport()
	
	FormParamenters = New Structure;
	
	FormParamenters.Insert("GenerateOnOpen", False);
	FormParamenters.Insert("Details");
	FormParamenters.Insert("ReportDetailsData");
	FormParamenters.Insert("ReportName");
	FormParamenters.Insert("Filter");
	FormParamenters.Insert("DetailsRuleAttributes");
	FormParamenters.Insert("OriginalReportName");
	FormParamenters.Insert("VariantKey", "Default");
	FormParamenters.Insert("UserSettings");
	Return FormParamenters;
	
EndFunction

Function ReportNameByFullName(FullName)
	
	NameItems = StrSplit(FullName, ".");
	If NameItems.Count() > 1 And NameItems[0] = "Report" Then
		Return NameItems[1];
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function IsReport(Report)
	
	Return TypeOf(Report) = Type("Structure") And Report.Property("ReportName");
	
EndFunction