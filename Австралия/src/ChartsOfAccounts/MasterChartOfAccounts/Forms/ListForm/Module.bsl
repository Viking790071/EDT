#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
		
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.ChartsOfAccounts.MasterChartOfAccounts, DataLoadSettings, ThisObject, False);
	// End StandardSubsystems.DataImportFromExternalSource
	
	HasRoleUseChartsOfAccountsChangeActions = Users.IsFullUser() Or AccessManagement.HasRole("UseChartsOfAccountsChangeActions");
	
	HasEditRights = AccessRight("Edit", Metadata.ChartsOfAccounts.MasterChartOfAccounts);
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);

EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	FormManagement();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterChartOfAccountsOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "ChartOfAccounts", FilterChartOfAccounts, ValueIsFilled(FilterChartOfAccounts));
	
EndProcedure

&AtClient
Procedure FilterCompanyOnChange(Item)
	
	If ValueIsFilled(FilterCompany) Then
		
		FilterItem = List.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField("Companies.Company");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = FilterCompany;
		FilterItem.Use = True;
		
		FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	Else
		CommonClientServer.DeleteFilterItems(List.Filter, "Companies.Company"); 
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterActiveOnOnChange(Item)
	
	If ValueIsFilled(FilterActiveOn) Then
		
		GroupOr = List.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
		GroupOr.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
		GroupOr.Presentation = "GroupEndDate";
		GroupOr.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		
		FilterItem = GroupOr.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField("EndDate");
		FilterItem.ComparisonType = DataCompositionComparisonType.GreaterOrEqual;
		FilterItem.RightValue = FilterActiveOn;
		FilterItem.Use = ValueIsFilled(FilterActiveOn);
		
		FilterItem = GroupOr.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField("EndDate");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = Date(1, 1, 1);
		FilterItem.Use = ValueIsFilled(FilterActiveOn);
		
	Else
		CommonClientServer.DeleteFilterItems(List.Filter, , "GroupEndDate"); 
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure AddCompanyToAccount(Command)
	
	SelectedRows = Items.List.SelectedRows;
	
	If SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	OpenAddInformationTool(SelectedRows, "AddCompany");
	
EndProcedure

&AtClient
Procedure ChangeAccountActivityPeriod(Command)
	
	SelectedRows = Items.List.SelectedRows;
	
	If SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	OpenAddInformationTool(SelectedRows, "ChangeAccountPeriod");
	
EndProcedure

&AtClient
Procedure ChangeCompanyActivityPeriod(Command)
	
	If Not ValueIsFilled(FilterCompany) Then
		ErrorText = NStr("en = 'Specify company filter. Then try again.'; ru = 'Установите отбор по организации и повторите попытку.';pl = 'Określ filtr firm. Zatem spróbuj ponownie.';es_ES = 'Especifique el filtro de la empresa. Inténtelo de nuevo.';es_CO = 'Especifique el filtro de la empresa. Inténtelo de nuevo.';tr = 'İş yeri filtresi belirtip tekrar deneyin.';it = 'Indicare il filtro azienda, poi riprovare.';de = 'Geben Sie Firmenfilter ein. Dann versuchen Sie erneut.'");
		CommonClientServer.MessageToUser(ErrorText, , "FilterCompany");
		Return;
	EndIf;
	
	SelectedRows = Items.List.SelectedRows;
	
	If SelectedRows.Count() = 0 Then
		Return;
	EndIf;

	OpenAddInformationTool(SelectedRows, "ChangeCompanyPeriod");
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure OpenAddInformationTool(SelectedRows, Operation)

	StatusToolParameters = New Structure;
	StatusToolParameters.Insert("Operation"			, Operation);
	StatusToolParameters.Insert("Company"			, FilterCompany);
	StatusToolParameters.Insert("SelectedElements"	, SelectedRows);
	
	InfoSetEnding = New NotifyDescription("InfoSetEnding", ThisObject);
	
	OpenForm("ChartOfAccounts.MasterChartOfAccounts.Form.AddInformationToAccountTool", 
		StatusToolParameters, 
		ThisObject,
		,
		,
		,
		InfoSetEnding);
	
EndProcedure

&AtClient
Procedure InfoSetEnding(SelectedValue, AdditionalParameters) Export

	Items.List.Refresh();		

EndProcedure

#Region DataImportFromExternalSources

&AtClient
Procedure ImportChartOfAccountsFromExternalSource(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult);
		ShowMessageBox( , NStr("en = 'Data import is complete.'; ru = 'Загрузка данных завершена.';pl = 'Import danych został zakończony.';es_ES = 'Importación de datos se ha finalizado.';es_CO = 'Importación de datos se ha finalizado.';tr = 'Verinin içe aktarımı tamamlandı.';it = 'L''importazione dei dati è stata completata.';de = 'Der Datenimport ist abgeschlossen.'"));
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ProcessPreparedData" Then
		Items.List.Refresh();
	EndIf;	
	
EndProcedure

#EndRegion
	
&AtClient
Procedure FormManagement()
	Items.ActionsGroup.Visible = HasRoleUseChartsOfAccountsChangeActions;
	
	Items.FormImportChartOfAccountsFromExternalSource.Visible = HasEditRights;
	
	Items.FormAddCompanyToAccount.Enabled			= HasEditRights;
	Items.FormChangeAccountActivityPeriod.Enabled	= HasEditRights;
	Items.FormChangeCompanyActivityPeriod.Enabled	= HasEditRights;
	
EndProcedure

#EndRegion