
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Parameters.Property("Company") Then 
		Company = Parameters.Company; 
	Else
		Company = DriveReUse.GetUserDefaultCompany();
	EndIf;
	If Not ValueIsFilled(Company) Then 
		Company = Catalogs.Companies.MainCompany;
	EndIf;
	
	Items.Currencies.ChoiceMode = Parameters.ChoiceMode;
	
	RateDate = BegOfDay(CurrentSessionDate());
	List.SettingsComposer.Settings.AdditionalProperties.Insert("RateDate", RateDate);
	List.SettingsComposer.Settings.AdditionalProperties.Insert("Company", Company);
	
	EditableFields = New Array;
	EditableFields.Add("Rate");
	EditableFields.Add("Repetition");
	List.SetRestrictionsForUseInGroup(EditableFields);
	List.SetRestrictionsForUseInOrder(EditableFields);
	List.SetRestrictionsForUseInFilter(EditableFields);
	
	CurrenciesChangeAvailable = AccessRight("Update", Metadata.InformationRegisters.ExchangeRate);
	CurrenciesImportAvailable = Metadata.DataProcessors.Find("ImportCurrenciesRates") <> Undefined AND CurrenciesChangeAvailable;
	
	Items.FormPickFromClassifier.Visible = CurrenciesImportAvailable;
	Items.FormImportCurrenciesRates.Visible = CurrenciesImportAvailable;
	If Not CurrenciesImportAvailable Then
		If CurrenciesChangeAvailable Then
			Items.CreateCurrency.Title = NStr("ru = 'Создать'; en = 'Create'; pl = 'Utwórz';es_ES = 'Crear';es_CO = 'Crear';tr = 'Oluştur';it = 'Crea';de = 'Erstellen'");
		EndIf;
		Items.Create.Type = FormGroupType.ButtonGroup;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetVisibleByValueOfCompany();
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	Items.Currencies.Refresh();
	Items.Currencies.CurrentRow = SelectedValue;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_CurrencyRates"
		Or EventName = "Write_CurrencyRateImport" Then
		Items.Currencies.Refresh();
	EndIf;
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	List.SettingsComposer.Settings.AdditionalProperties.Insert("Company", Company);	
	SetVisibleByValueOfCompany();
	
EndProcedure

#EndRegion

#Region CurrencyFormTableItemsEventHandlers

&AtServerNoContext
Procedure CurrenciesOnGetDataAtServer(ItemName, Settings, Rows)
	
	Var RateDate, CompanyForQuery;
	
	If Not Settings.AdditionalProperties.Property("RateDate", RateDate) 
		Or Not Settings.AdditionalProperties.Property("Company", CompanyForQuery) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
		"SELECT ALLOWED
		|	ExchangeRate.Currency AS Currency,
		|	ExchangeRate.Rate AS Rate,
		|	ExchangeRate.Repetition AS Repetition
		|FROM
		|	InformationRegister.ExchangeRate.SliceLast(&EndOfPeriod, Currency IN (&Currencies) AND Company = &Company) AS ExchangeRate";
	Query.SetParameter("Currencies", Rows.GetKeys());
	Query.SetParameter("EndOfPeriod", RateDate);
	Query.SetParameter("Company", CompanyForQuery);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ListLine = Rows[Selection.Currency];
		ListLine.Data["Rate"] = Selection.Rate;
		If Selection.Repetition <> 1 Then 
			ListLine.Data["Repetition"] = Selection.Repetition;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure PickFromClassifier(Command)
	
	PickingFormName = "DataProcessor.ImportCurrenciesRates.Form.PickCurrenciesFromClassifier";
	OpenForm(PickingFormName, , ThisObject);
	
EndProcedure

&AtClient
Procedure ImportCurrenciesRates(Command)
	
	ImportFormName = "DataProcessor.ImportCurrenciesRates.Form";
	FormParameters = New Structure("OpeningFromList");
	FormParameters.Insert("Company", Company);
	OpenForm(ImportFormName, FormParameters);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetVisibleByValueOfCompany()
	
	CompanyIsFilled = ValueIsFilled(Company);
	
	If Not CompanyIsFilled Then
		EmptyCurrency = PredefinedValue("Catalog.Currencies.EmptyRef");
		
		CommonClientServer.SetDynamicListFilterItem(List, "Ref", EmptyCurrency, DataCompositionComparisonType.Equal, "EmptyRef", True); 
	Else
		CommonClientServer.DeleteFilterItems(List.Filter, "Ref", "EmptyRef");
	EndIf;
	
	Items.CommandBar.ChildItems.Create.Enabled = CompanyIsFilled;
	Items.CommandBar.ChildItems.FormCommands.Enabled = CompanyIsFilled;
	Items.CommandBar.ChildItems.FormImportCurrenciesRates.Enabled = CompanyIsFilled;
	Items.CurrenciesContextMenu.ChildItems.CurrenciesContextMenuCreate.Enabled = CompanyIsFilled;
	
EndProcedure

#EndRegion