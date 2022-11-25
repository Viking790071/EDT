Procedure FillInParentFieldInDataMappingTable(Value, DataMatchingTable, DataLoadSettings)
	
	If DataLoadSettings.FillingObjectFullName = "Catalog.Counterparties" Then
		
		CheckedFieldName = "Counterparty";
		PopulatedFieldName = "Parent";
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Catalog.Products" Then
		
		CheckedFieldName = "Products";
		PopulatedFieldName = "Parent";
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Catalog.Cells" Then
		
		CheckedFieldName = "Cells";
		PopulatedFieldName = "Parent";
		
		If Value = Undefined Then
			ValueOwner = Undefined;
		Else 
			ValueOwner = DataImportFromExternalSourcesOverridable.GetOwner(Value);
		EndIf;
		
	ElsIf DataLoadSettings.FillingObjectFullName = "InformationRegister.Prices" Then
		
		CheckedFieldName = "PriceKind";
		PopulatedFieldName = "PriceKind";
		
	ElsIf DataLoadSettings.FillingObjectFullName = "ChartOfAccounts.PrimaryChartOfAccounts" Then
		
		CheckedFieldName = "Account";
		PopulatedFieldName = "Parent";
		
	EndIf;
	
	For Each TableRow In DataMatchingTable Do
		
		If PopulatedFieldName = "Parent" Then
			
			CommonValueIsFilled = ValueIsFilled(TableRow[CheckedFieldName]);
			If Not CommonValueIsFilled Then
				
				TableRow[PopulatedFieldName] = Value;
				
				If CheckedFieldName = "Cells" 
					And TableRow.Owner <> ValueOwner 
					And ValueOwner <> Undefined Then
					
					TableRow._ImportToApplicationPossible = False;
					
				EndIf;
				
			EndIf;
			
		ElsIf PopulatedFieldName = "PriceKind" Then
			
			TableRow[PopulatedFieldName] = Value;
			
		EndIf;
		
	EndDo;
	
	If CheckedFieldName = "Cells" Then
		
		Notify("DataImportFromExternalSourcesClientOverridable_SetGoToNumber_6");
		
	EndIf;
	
EndProcedure

Procedure OnSetGeneralValue(Form, DataLoadSettings, DataMatchingTable) Export
	
	AdditionalSettings = New Structure("Form, DataLoadSettings, DataMatchingTable", Form, DataLoadSettings, DataMatchingTable);
	NotifyDescription 		= New NotifyDescription("WhenProcessingCommonValueSelectionResult", ThisObject, AdditionalSettings);
	
	OpenParameters = New Structure;
	OpenParameters.Insert("Multiselect", False);
	OpenParameters.Insert("CloseOnChoice", True);
	OpenParameters.Insert("ChoiceFoldersAndItems", FoldersAndItems.Folders);
	
	GroupChoiceFormName = Undefined;
	
	If DataLoadSettings.FillingObjectFullName = "Catalog.Counterparties" Then
		
		GroupChoiceFormName = "Catalog.Counterparties.FolderChoiceForm";
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Catalog.Products" Then
		
		GroupChoiceFormName = "Catalog.Products.FolderChoiceForm";
		
	ElsIf DataLoadSettings.FillingObjectFullName = "InformationRegister.Prices" Then
		
		OpenParameters.ChoiceFoldersAndItems = FoldersAndItems.Items;
		GroupChoiceFormName = "Catalog.PriceTypes.ChoiceForm";
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Catalog.Leads" Then
		
		GroupChoiceFormName = "Catalog.Leads.ChoiceForm";
		
	ElsIf DataLoadSettings.FillingObjectFullName = "ChartOfAccounts.PrimaryChartOfAccounts" Then
		
		GroupChoiceFormName = "ChartOfAccounts.PrimaryChartOfAccounts.ChoiceForm";
		
		OpenParameters.Insert("AllowHeaderAccountsSelection", True);
		
	ElsIf DataLoadSettings.FillingObjectFullName = "ChartOfAccounts.MasterChartOfAccounts" Then
		
		GroupChoiceFormName = "ChartOfAccounts.MasterChartOfAccounts.ChoiceForm";
		
		OpenParameters.Insert("AllowHeaderAccountsSelection", True);
	
	ElsIf DataLoadSettings.FillingObjectFullName = "Catalog.Cells" Then
		
		GroupChoiceFormName = "Catalog.Cells.ChoiceForm";
		
	EndIf;
	
	If GroupChoiceFormName <> Undefined Then
		OpenForm(GroupChoiceFormName, OpenParameters, ThisObject, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

Procedure OnClearGeneralValue(Form, DataLoadSettings, DataMatchingTable) Export
	
	If DataLoadSettings.FillingObjectFullName = "Catalog.Counterparties" 
		OR DataLoadSettings.FillingObjectFullName = "Catalog.Products"
		OR DataLoadSettings.FillingObjectFullName = "Catalog.Cells" Then
		
		Form.Items.CommonValueCatalog.Title = NStr("en = '< not indicated >'; ru = '< не указана >';pl = '< nie wskazana >';es_ES = '< no indicado >';es_CO = '< no indicado >';tr = '< belirtilmedi >';it = '< non indicato >';de = '< nicht angegeben>'");
		FillInParentFieldInDataMappingTable(Undefined, DataMatchingTable, DataLoadSettings);
		
	ElsIf DataLoadSettings.FillingObjectFullName = "ChartOfAccounts.PrimaryChartOfAccounts" Then
		
		Form.Items.CommonValueChartOfAccounts.Title = NStr("en = '< not indicated >'; ru = '< не указана >';pl = '< nie wskazana >';es_ES = '< no indicado >';es_CO = '< no indicado >';tr = '< belirtilmedi >';it = '< non indicato >';de = '< nicht angegeben>'");
		FillInParentFieldInDataMappingTable(Undefined, DataMatchingTable, DataLoadSettings);
	
	ElsIf DataLoadSettings.FillingObjectFullName = "InformationRegister.Prices" Then
		
		Form.Items.CommonValueIR.Title = NStr("en = '< not indicated >'; ru = '< не указана >';pl = '< nie wskazana >';es_ES = '< no indicado >';es_CO = '< no indicado >';tr = '< belirtilmedi >';it = '< non indicato >';de = '< nicht angegeben>'");
		FillInParentFieldInDataMappingTable(DataImportFromExternalSourcesOverridable.DefaultPriceKind(), DataMatchingTable, DataLoadSettings);
		
	EndIf;
	
EndProcedure

Procedure WhenProcessingCommonValueSelectionResult(Result, AdditionalSettings) Export
	
	Form = AdditionalSettings.Form;
	DataLoadSettings = AdditionalSettings.DataLoadSettings;
	DataMatchingTable = AdditionalSettings.DataMatchingTable;
	
	If DataMatchingTable.Count() > 0 
		AND ValueIsFilled(Result) Then
		
		FillInParentFieldInDataMappingTable(Result, DataMatchingTable, DataLoadSettings);
		If DataLoadSettings.FillingObjectFullName = "Catalog.Counterparties"
			OR DataLoadSettings.FillingObjectFullName = "Catalog.Products"
			OR DataLoadSettings.FillingObjectFullName = "Catalog.Cells" Then
			
			Form.Items.CommonValueCatalog.Title = StringFunctionsClientServer.SubstituteParametersToString("< %1 >", Result);
			
		ElsIf DataLoadSettings.FillingObjectFullName = "ChartOfAccounts.PrimaryChartOfAccounts" Then
			
			Form.Items.CommonValueChartOfAccounts.Title = StringFunctionsClientServer.SubstituteParametersToString("< %1 >", Result);
		
		ElsIf DataLoadSettings.FillingObjectFullName = "InformationRegister.Prices" Then
			
			Form.Items.CommonValueIR.Title = StringFunctionsClientServer.SubstituteParametersToString("< %1 >", Result);
			
		EndIf;
		
	EndIf;
	
EndProcedure
