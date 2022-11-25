#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure FillTemporaryParameters(Form) Export
	
	ReportSetting = Form.ReportSettings;
	
	TemporaryParameters = New Structure;
	
	BySubaccounts	= Undefined;
	ReportStructure = Undefined;
	
	ParameterBySubaccounts 	 = New DataCompositionParameter("BySubaccounts");
	ParameterReportStructure = New DataCompositionParameter("ReportStructure");
	
	For Each UserSetting In Form.Report.SettingsComposer.Settings.DataParameters.Items Do
		
		If TypeOf(UserSetting) = Type("DataCompositionSettingsParameterValue") Then
			If UserSetting.Parameter = ParameterReportStructure Then
				ReportStructure = UserSetting.Value.Get();
			ElsIf UserSetting.Parameter = ParameterBySubaccounts Then
				BySubaccounts = UserSetting.Value; 
			EndIf;
		EndIf;
		
	EndDo;
	
	TemporaryParameters.Insert("BySubaccounts", BySubaccounts);
	
	FillDefaultSettings(TemporaryParameters, ReportStructure);
	
	TemporaryParameters.Insert("ReportStructure", New ValueStorage(ReportStructure));
	
	ReportSetting.Insert("TemporaryParameters", TemporaryParameters);
	
EndProcedure

Procedure FillDefaultSettings(SettingsStructure, SavedReportStructure) Export

	PresentationCurrency		= Undefined;
	CurrencyAmount				= Undefined;
	Quantity					= Undefined;
	AccountName					= Undefined;
	DetailedBalance				= Undefined;
	DisplayParametersAndFilters	= Undefined;
	HighlightNegativeValues		= Undefined;
	ReportTitle					= Undefined;

	If SavedReportStructure <> Undefined Then
		
		SavedReportStructure.Property("PresentationCurrency"		, PresentationCurrency);
		SavedReportStructure.Property("CurrencyAmount"				, CurrencyAmount);
		SavedReportStructure.Property("Quantity"					, Quantity);
		SavedReportStructure.Property("AccountName"					, AccountName);
		SavedReportStructure.Property("DetailedBalance"				, DetailedBalance);
		SavedReportStructure.Property("DisplayParametersAndFilters"	, DisplayParametersAndFilters);
		SavedReportStructure.Property("HighlightNegativeValues"		, HighlightNegativeValues);
		SavedReportStructure.Property("ReportTitle"					, ReportTitle);
		
	EndIf;
	
	If PresentationCurrency = Undefined Then
		PresentationCurrency = True;
	EndIf;
	
	If AccountName = Undefined Then
		AccountName = False;
	EndIf;
	
	If DetailedBalance = Undefined Then
		DetailedBalance = False;
	EndIf;
	
	If DisplayParametersAndFilters = Undefined Then
		DisplayParametersAndFilters = True;
	EndIf;
	
	If HighlightNegativeValues = Undefined Then
		HighlightNegativeValues = True;
	EndIf;
	
	If ReportTitle = Undefined Then
		ReportTitle = True;
	EndIf;
	
	If CurrencyAmount = Undefined Then
		CurrencyAmount = False;
	EndIf;
	
	Quantity = False;
	
	SettingsStructure.Insert("PresentationCurrency"			, PresentationCurrency);
	SettingsStructure.Insert("CurrencyAmount"				, CurrencyAmount);
	SettingsStructure.Insert("Quantity"						, Quantity);
	SettingsStructure.Insert("AccountName"					, AccountName);
	SettingsStructure.Insert("DetailedBalance"				, DetailedBalance);
	SettingsStructure.Insert("DisplayParametersAndFilters"	, DisplayParametersAndFilters);
	SettingsStructure.Insert("HighlightNegativeValues"		, HighlightNegativeValues);
	SettingsStructure.Insert("ReportTitle"					, ReportTitle);
	
EndProcedure

Procedure ReadGroupingSettings(Form) Export
	
	ReportSettings						= Form.ReportSettings;
	AccountingGroupingByAccountsTable	= Form.AccountingGroupingByAccountsTable;
	DetailedBalanceTable				= Form.DetailedBalanceTable;
	Report								= Form.Report;
	
	ReportStructure = ReportSettings.TemporaryParameters.ReportStructure.Get();
	
	If ReportStructure <> Undefined Then
		If ReportStructure.Property("ReportStructure") Then
			AccountingGroupingByAccountsTable.Load(ReportStructure.ReportStructure);
		EndIf;
		
		If ReportStructure.Property("DetailedBalanceTable") Then
			DetailedBalanceTable.Load(ReportStructure.DetailedBalanceTable);
		EndIf;
	EndIf;
	
EndProcedure

Procedure SetReportSettings(Form) Export
	
	Report = Form.Report;
	
	FillTemporaryParameters(Form);
	ReadGroupingSettings(Form);
	
	ReportSettings = Form.ReportSettings;
	
	Form.BySubaccounts						= ReportSettings.TemporaryParameters.BySubaccounts;
	Form.ItemPresentationCurrency			= ReportSettings.TemporaryParameters.PresentationCurrency;
	Form.ItemCurrencyAmount					= ReportSettings.TemporaryParameters.CurrencyAmount;
	Form.ItemQuantity						= ReportSettings.TemporaryParameters.Quantity;
	Form.ItemAccountName					= ReportSettings.TemporaryParameters.AccountName;
	Form.ItemDetailedBalance				= ReportSettings.TemporaryParameters.DetailedBalance;
	Form.ItemDisplayParametersAndFilters	= ReportSettings.TemporaryParameters.DisplayParametersAndFilters;
	Form.ItemHighlightNegativeValues		= ReportSettings.TemporaryParameters.HighlightNegativeValues;
	Form.ItemReportTitle					= ReportSettings.TemporaryParameters.ReportTitle;
	
	SetSettingsItemsVisible(Form);
	
	SetChoiceParameterLinks(Form, Report.SettingsComposer.UserSettings);
	
EndProcedure

Procedure SetChoiceParameterLinks(Form, UserSettings) Export 

	Items = Form.Items;
	
	ParameterChartOfAccounts	= New DataCompositionParameter("ChartOfAccounts");
	
	ChartOfAccountsValue 		= Undefined;
	
	AccountItem = Undefined;
	
	For Each UserSetting In UserSettings.Items Do
		
		If TypeOf(UserSetting) = Type("DataCompositionSettingsParameterValue") Then
			
			If UserSetting.Parameter = ParameterChartOfAccounts Then
				
				ChartOfAccountsValue = UserSetting.Value;
				Break;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	ChoiceParameters = New Array;
	
	If ValueIsFilled(ChartOfAccountsValue) Then
		ChoiceParameters.Add(New ChoiceParameter("Filter.ChartOfAccounts", ChartOfAccountsValue));
	EndIf;
	
	ChoiceParametersFixed = New FixedArray(ChoiceParameters);
	
	Items.AccountingGroupingByAccountsTableAccount.ChoiceParameters = ChoiceParametersFixed;
	Items.DetailedBalanceTableAccount.ChoiceParameters = ChoiceParametersFixed;
	
	If ValueIsFilled(ChartOfAccountsValue) Then
		CheckAccountRows(ChartOfAccountsValue, Form.AccountingGroupingByAccountsTable);
		CheckAccountRows(ChartOfAccountsValue, Form.DetailedBalanceTable);
	EndIf;
	
	SetChoiceParameterLinksForFilters(ChartOfAccountsValue, Form.Report.SettingsComposer.Settings.Filter.Items);
	
EndProcedure

Procedure SetGroupingSettings(Form) Export
	
	ReportSettings = Form.ReportSettings;
	
	Report = Form.Report;
	
	AccountingGroupingByAccountsTable = Form.AccountingGroupingByAccountsTable;
	
	DetailedBalanceTable = Form.DetailedBalanceTable;
	
	BySubaccounts = Form.BySubaccounts;
	
	GenerateReportSchema(Form, ReportSettings, Report, AccountingGroupingByAccountsTable, DetailedBalanceTable, BySubaccounts);
	
	ReportSettings.SchemaModified = True;
	
	StorageStructure = New Structure;
	
	SaveReportParameters(Form, StorageStructure);
	
	GenerateReportStructure(Report.SettingsComposer.Settings.Structure, StorageStructure);  
	
	SetFilterBySubaccounts(Form);
	
	SetChoiceParameterLinks(Form, Report.SettingsComposer.UserSettings);
	
EndProcedure

Procedure GenerateReportSchema(Form, ReportSettings, Report, AccountingGroupingByAccountsTable, DetailedBalanceTable, BySubaccounts) Export
	
	DataCompositionSchema = GetFromTempStorage(ReportSettings.SchemaURL);
	
	ParametersArray = New Array;
	
	ParametersMap = New Map;
	
	AccountsExcludedFromQueryForAccounts = New ValueList;
	
	ExtDimensionsTable = New ValueTable;
	
	ExtDimensionsTable.Columns.Add("LineNumber", New TypeDescription("Number"));
	ExtDimensionsTable.Columns.Add("ExtDimension");
	ExtDimensionsTable.Columns.Add("Check", New TypeDescription("Boolean"));
	
	AccountsTable = New ValueTable; 
	AccountsTable.Columns.Add("Account");
	AccountsTable.Columns.Add("ExtDimensions");
	
	For Each GroupingRow In AccountingGroupingByAccountsTable Do
		
		If GroupingRow.Use And ValueIsFilled(GroupingRow.Account) Then
			
			AccountsArray = New Array;
			
			SubordinateAccounts = GetSubordinateAccounts(GroupingRow.Account);
			
			For Each SubordinateAccount In SubordinateAccounts Do
				AccountsExcludedFromQueryForAccounts.Add(SubordinateAccount.Value);
			EndDo;
			
			If BySubaccounts Or GroupingRow.BySubaccounts Then
			
				For Each SubordinateAccount In SubordinateAccounts Do
					AccountsArray.Add(SubordinateAccount.Value);
				EndDo;
			
			Else
				AccountsArray.Add(GroupingRow.Account);
			EndIf;
			
			ExtDimensionsList = New ValueList;
			
			ExtDimensionsTable.Clear();
			
			Index = 1;
			
			For Each ExtDimensionsRow In GroupingRow.ExtDimensions Do
				
				If ExtDimensionsRow.Check Then
					
					ExtDimensionsList.Add(ExtDimensionsRow.Value);
					
					ExtDimensionsTableRow = ExtDimensionsTable.Add();
					
					ExtDimensionsTableRow.LineNumber	= Index;
					ExtDimensionsTableRow.ExtDimension	= ExtDimensionsRow.Value;
					ExtDimensionsTableRow.Check			= ExtDimensionsRow.Check;
					
					Index = Index + 1;
					
				EndIf;
				
			EndDo;
			
			For Each Row In AccountsArray Do
				
				AccountsTableRow = AccountsTable.Add();
				
				AccountsTableRow.Account = Row;
				AccountsTableRow.ExtDimensions = ExtDimensionsTable.Copy();
				
			EndDo;
			
			ArrayStructure = New Structure;
			
			ArrayStructure.Insert("Accounts"			, SubordinateAccounts);
			ArrayStructure.Insert("ExtDimensions"		, ExtDimensionsList);
			ArrayStructure.Insert("ExtDimensionsCount"	, ExtDimensionsList.Count());
			
			ParametersArray.Add(ArrayStructure);
			
		EndIf;
		
	EndDo;
	
	DeleteArray = New Array;
	
	For Each Field In DataCompositionSchema.TotalFields Do
		
		If Field.DataPath = "AmountOpeningBalanceDr"
			Or Field.DataPath = "AmountOpeningBalanceCr"
			Or Field.DataPath = "AmountCurOpeningBalanceDr"
			Or Field.DataPath = "AmountCurOpeningBalanceCr"
			Or Field.DataPath = "AmountClosingBalanceDr"
			Or Field.DataPath = "AmountClosingBalanceCr"
			Or Field.DataPath = "AmountCurClosingBalanceDr"
			Or Field.DataPath = "AmountCurClosingBalanceCr" Then
			
			DeleteArray.Add(Field);
			
		EndIf;
		
	EndDo;
	
	For Each Field In DeleteArray Do
		DataCompositionSchema.TotalFields.Delete(Field);
	EndDo;
	
	DetailedSettingsStructure = New Structure;
	
	DetailedSettingsStructure.Insert("ArrayAccounts",				New Array);
	DetailedSettingsStructure.Insert("ArrayAccountsExtDimension1",	New Array);
	DetailedSettingsStructure.Insert("ArrayAccountsExtDimension2",	New Array);
	DetailedSettingsStructure.Insert("ArrayAccountsExtDimension3",	New Array);
	DetailedSettingsStructure.Insert("ArrayAccountsExtDimension4",	New Array);
	
	If DetailedBalanceTable <> Undefined Then
		
		RowIndex = 1;
		
		For Each DetailedRow In DetailedBalanceTable Do
			
			If DetailedRow.Use And ValueIsFilled(DetailedRow.Account) Then
				
				AccountsArray = New Array;
				
				If DetailedRow.BySubaccounts Then
				
					SubordinateAccounts = GetSubordinateAccounts(DetailedRow.Account, True);
					
					For Each SubordinateAccount In SubordinateAccounts Do
						
						AccountsArray.Add(SubordinateAccount.Value);
						
					EndDo;
					
				Else
					
					If DetailedRow.Account.Type = AccountType.ActivePassive Then
						AccountsArray.Add(DetailedRow.Account);
					EndIf;
					
				EndIf;
				
				ExtDimensionsList = New ValueList;
				
				AccountIndex = 1;
				
				For Each CurrentAccount In AccountsArray Do
					
					ParameterName = StrTemplate("DetailedAccount_%1_%2", RowIndex, AccountIndex);
					
					ParameterStructure = New Structure("ParameterName, Account", ParameterName, CurrentAccount);
					
					DetailedSettingsStructure.ArrayAccounts.Add(ParameterStructure);
					
					FoundRows = AccountsTable.FindRows(New Structure("Account", CurrentAccount));
					
					If FoundRows.Count() > 0 Then
						
						DimensionTable = FoundRows[0].ExtDimensions;
						
						For Each ExtDimensionRow In DetailedRow.ExtDimensions Do
							
							If ExtDimensionRow.Check Then
							
								FoundDimensionsRows = DimensionTable.FindRows(New Structure("ExtDimension", ExtDimensionRow.Value));
								
								If FoundDimensionsRows.Count() > 0 Then
									
									DetailedSettingsStructure[StrTemplate("ArrayAccountsExtDimension%1", FoundDimensionsRows[0].LineNumber)].Add(ParameterStructure);
									
								EndIf;
							
							EndIf;
							
						EndDo;
					EndIf;
					
					ParametersMap.Insert(New DataCompositionParameter(ParameterName), CurrentAccount);
					
					If DataCompositionSchema.Parameters.Find(ParameterName) = Undefined Then
						NewParameter = DataCompositionSchema.Parameters.Add();
						NewParameter.Name = ParameterName;
						NewParameter.IncludeInAvailableFields = False;
					EndIf;
					
					AccountIndex = AccountIndex + 1;
					
				EndDo;
				
				RowIndex = RowIndex + 1;
			EndIf;
			
		EndDo;
	EndIf;
	
	
	If DetailedSettingsStructure.ArrayAccounts.Count() = 0
		And DetailedSettingsStructure.ArrayAccountsExtDimension1.Count() = 0
		And DetailedSettingsStructure.ArrayAccountsExtDimension2.Count() = 0
		And DetailedSettingsStructure.ArrayAccountsExtDimension3.Count() = 0
		And DetailedSettingsStructure.ArrayAccountsExtDimension4.Count() = 0 Then
		
		SetTotalsFields(DataCompositionSchema);
		
	Else
		
		AccountExpression		= "False";
		ExtDimension1Expression = "False";
		ExtDimension2Expression = "False";
		ExtDimension3Expression = "False";
		ExtDimension4Expression = "False";
		
		For Each AccountRow In DetailedSettingsStructure.ArrayAccounts Do
			AccountExpression = AccountExpression + " " + "Or Account = &" + AccountRow.ParameterName;
		EndDo;
		
		For Each AccountRow In DetailedSettingsStructure.ArrayAccountsExtDimension1 Do
			ExtDimension1Expression = ExtDimension1Expression + " " + "Or Account = &" + AccountRow.ParameterName;
		EndDo;
		
		For Each AccountRow In DetailedSettingsStructure.ArrayAccountsExtDimension2 Do
			ExtDimension2Expression = ExtDimension2Expression + " " + "Or Account = &" + AccountRow.ParameterName;
		EndDo;
		
		For Each AccountRow In DetailedSettingsStructure.ArrayAccountsExtDimension3 Do
			ExtDimension3Expression = ExtDimension3Expression + " " + "Or Account = &" + AccountRow.ParameterName;
		EndDo;
		
		For Each AccountRow In DetailedSettingsStructure.ArrayAccountsExtDimension4 Do
			ExtDimension4Expression = ExtDimension4Expression + " " + "Or Account = &" + AccountRow.ParameterName;
		EndDo;
		
		GrandTotal = New Array;
		GrandTotal.Add("Overall");

		AccountGroups = New Array;
		AccountGroups.Add("Account");
		AccountGroups.Add("Account Hierarchy");
		AccountGroups.Add("Currency");
		
		ExtDimension1Groups = New Array;
		ExtDimension1Groups.Add("ExtDimension1");
		
		ExtDimension2Groups = New Array;
		ExtDimension2Groups.Add("ExtDimension2");
		
		ExtDimension3Groups = New Array;
		ExtDimension3Groups.Add("ExtDimension3");
		
		ExtDimension4Groups = New Array;
		ExtDimension4Groups.Add("ExtDimension4");
		
		SetTotalsFields(DataCompositionSchema, , GrandTotal);
		SetTotalsFields(DataCompositionSchema, AccountExpression, AccountGroups);
		SetTotalsFields(DataCompositionSchema, ExtDimension1Expression, ExtDimension1Groups);
		SetTotalsFields(DataCompositionSchema, ExtDimension2Expression, ExtDimension2Groups);
		SetTotalsFields(DataCompositionSchema, ExtDimension3Expression, ExtDimension3Groups);
		SetTotalsFields(DataCompositionSchema, ExtDimension4Expression, ExtDimension4Groups);
		
	EndIf;
	
	StandardQuery = Reports.TrialBalanceMaster.GetTemplate("MainDataCompositionSchema").DataSets.DataSet1.Query;

	ResultQuery = "" + StandardQuery;
	
	ResultQuery = StrReplace(ResultQuery, "NestedQuery.ExtDimension1", "NULL");
	ResultQuery = StrReplace(ResultQuery, "NestedQuery.ExtDimension2", "NULL");
	ResultQuery = StrReplace(ResultQuery, "NestedQuery.ExtDimension3", "NULL");
	ResultQuery = StrReplace(ResultQuery, "NestedQuery.ExtDimension4", "NULL");
	
	ResultQuery = StrReplace(ResultQuery, "&AccountCondition", "Not Account in (&AccountsExcludedFromQueryForAccounts)");
	ResultQuery = StrReplace(ResultQuery, "&ExtDimensionsCondition", "");
	
	If DataCompositionSchema.Parameters.Find("AccountsExcludedFromQueryForAccounts") = Undefined Then
		
		NewParameter = DataCompositionSchema.Parameters.Add();
		NewParameter.Use						= DataCompositionParameterUse.Always;
		NewParameter.Name						= "AccountsExcludedFromQueryForAccounts";
		NewParameter.ValueListAllowed			= True;
		NewParameter.IncludeInAvailableFields	= False;
		
	EndIf;
	
	ParametersMap.Insert(New DataCompositionParameter("AccountsExcludedFromQueryForAccounts"), AccountsExcludedFromQueryForAccounts);
	
	Index = 1;
	
	MaxAnalyticalDimensionsNumber = ChartsOfAccounts.MasterChartOfAccounts.MaxAnalyticalDimensionsNumber();
	
	For Each ParametersRow In ParametersArray Do
		
		ParameterNameAccount 	= StrTemplate("Accounts%1", Index);
		ParameterNameDimensions = StrTemplate("ExtDimensions%1", Index);
		
		AccountCondition = StrTemplate("Account in (&%1)", ParameterNameAccount);
		
		If ParametersRow.ExtDimensionsCount = 0 Then
			DimensionsCondition = "";
		Else
			DimensionsCondition = StrTemplate("&%1", ParameterNameDimensions);
		EndIf;
		
		QueryByExtdimension = "" + StandardQuery;
	
		QueryByExtdimension = StrReplace(QueryByExtdimension, "SELECT ALLOWED", "SELECT");
		If ParametersRow.ExtDimensionsCount < MaxAnalyticalDimensionsNumber  Then
			
			For Count = ParametersRow.ExtDimensionsCount + 1 To MaxAnalyticalDimensionsNumber Do 
				
				ExDimension = StrTemplate("NestedQuery.ExtDimension%1", Count);
				QueryByExtdimension = StrReplace(QueryByExtdimension, ExDimension, "NULL");
				
				ExDimension = StrTemplate("AccountingJournalEntriesCompoundBalanceAndTurnovers.ExtDimension%1", Count);
				QueryByExtdimension = StrReplace(QueryByExtdimension, ExDimension, "NULL");
				
				ExDimension = StrTemplate("AccountingJournalEntriesSimpleBalanceAndTurnovers.ExtDimension%1", Count);
				QueryByExtdimension = StrReplace(QueryByExtdimension, ExDimension, "NULL");
	
			EndDo;
		EndIf;
		
		QueryByExtdimension = StrReplace(QueryByExtdimension, "&AccountCondition", AccountCondition);
		QueryByExtdimension = StrReplace(QueryByExtdimension, "&ExtDimensionsCondition", DimensionsCondition);
		
		ParametersMap.Insert(New DataCompositionParameter(ParameterNameAccount), ParametersRow.Accounts);
		ParametersMap.Insert(New DataCompositionParameter(ParameterNameDimensions), ParametersRow.ExtDimensions);
		
		If DataCompositionSchema.Parameters.Find(ParameterNameAccount) = Undefined Then
			NewParameter = DataCompositionSchema.Parameters.Add();
			NewParameter.Name = ParameterNameAccount;
			NewParameter.ValueListAllowed = True;
			NewParameter.IncludeInAvailableFields = False;
		EndIf;
		
		If DataCompositionSchema.Parameters.Find(ParameterNameDimensions) = Undefined Then
			NewParameter = DataCompositionSchema.Parameters.Add();
			NewParameter.Name = ParameterNameDimensions;
			NewParameter.ValueListAllowed = True;
			NewParameter.IncludeInAvailableFields = False;
		EndIf;
		
		ResultQuery = ResultQuery + "
			|
			|UNION ALL
			|
			|" +
			QueryByExtdimension;
		
		Index = Index + 1;
		
	EndDo;
	
	DataCompositionSchema.DataSets.DataSet1.Query = ResultQuery;
	
	SettingsOrderItems = Report.SettingsComposer.Settings.Order.Items;
	
	SettingsOrderItems.Clear();
	
	For Each OrderItems In DataCompositionSchema.DefaultSettings.Order.Items Do
		
		NewItem = SettingsOrderItems.Add(TypeOf(OrderItems));
		
		FillPropertyValues(NewItem, OrderItems);
		
	EndDo;
	
	ReportSettings.SchemaURL = PutToTempStorage(DataCompositionSchema, Form.UUID);
	
	Report.SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(ReportSettings.SchemaURL));
	
	For Each ReportParameter In Report.SettingsComposer.Settings.DataParameters.Items Do
		
		ParameterMap = ParametersMap.Get(ReportParameter.Parameter);
		
		If ParameterMap <> Undefined Then
			ReportParameter.Use = True;
			ReportParameter.Value = ParameterMap;
			ReportParameter.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure GenerateReportStructure(ReportStructure, SettingsStructure) Export
	
	PresentationCurrency		= SettingsStructure.PresentationCurrency;
	CurrencyAmount				= SettingsStructure.CurrencyAmount;
	Quantity					= SettingsStructure.Quantity;
	AccountName					= SettingsStructure.AccountName;
	DetailedBalance				= SettingsStructure.DetailedBalance;
	DisplayParametersAndFilters	= SettingsStructure.DisplayParametersAndFilters;
	HighlightNegativeValues		= SettingsStructure.HighlightNegativeValues;
	ReportTitle					= SettingsStructure.ReportTitle;
	
	DetailsRowCount = 0;
	
	If PresentationCurrency Then
		DetailsRowCount = DetailsRowCount + 1;
	EndIf;
	
	If CurrencyAmount Then 
		DetailsRowCount = DetailsRowCount + 1;
	EndIf;
	
	If Quantity Then 
		DetailsRowCount = DetailsRowCount + 1;
	EndIf;
	
	PresentationCurrencyFindedFields	= PresentationCurrencyFindedFields();
	CurrencyAmountFindedFields			= CurrencyAmountFindedFields();
	
	FilterOutput = New DataCompositionParameter("FilterOutput");
	
	HasTable = False;
	
	ArrayForDelete = New Array;
	
	For Each StructureRow In ReportStructure Do
		If Not HasTable And TypeOf(StructureRow) = Type("DataCompositionTable") Then
			HasTable = True;
		Else
			ArrayForDelete.Add(StructureRow);
		EndIf;
	EndDo;
	
	If HasTable Then
		For Each DeleteRow In ArrayForDelete Do
			ReportStructure.Delete(DeleteRow);
		EndDo;
	Else
		ReportStructure.Clear();
		
		NewTable = ReportStructure.Add(Type("DataCompositionTable")); 
		
		AddDefaultGroupDetails(NewTable);
		AddDefaultGroupOpeningBalance(NewTable);
		AddDefaultGroupTurnovers(NewTable);
		AddDefaultGroupClosingBalance(NewTable);
	EndIf;
	
	MaxAnalyticalDimensionsNumber = ChartsOfAccounts.MasterChartOfAccounts.MaxAnalyticalDimensionsNumber();
	For Each StructureRow In ReportStructure Do
		
		If TypeOf(StructureRow) = Type("DataCompositionTable") Then
			
			For Each StructureColumn In StructureRow.Columns Do
				
				If StructureColumn.Name = "Details" Then
					
					StructureColumn.Use = DetailsRowCount > 1;
					
				EndIf;
				
				SetSelectedFieldVisible(StructureColumn.Selection.Items, PresentationCurrencyFindedFields, PresentationCurrency);
				SetSelectedFieldVisible(StructureColumn.Selection.Items, CurrencyAmountFindedFields, CurrencyAmount);
				
			EndDo;
			
			StructureRow.Rows.Clear();
			
			CurrentStructure = StructureRow.Rows;
			
			CurrentGroup			= CurrentStructure.Add();
			NewGroupField			= CurrentGroup.GroupFields.Items.Add(Type("DataCompositionGroupField"));
			NewGroupField.Field		= New DataCompositionField("Account");
			NewGroupField.GroupType = DataCompositionGroupType.Hierarchy;
			
			NewSelectionField = CurrentGroup.Selection.Items.Add(Type("DataCompositionSelectedField"));
			NewSelectionField.Field = New DataCompositionField("Account");
			
			If AccountName Then
				NewSelectionField = CurrentGroup.Selection.Items.Add(Type("DataCompositionSelectedField"));
				NewSelectionField.Field = New DataCompositionField("Account.Description");
			EndIf;
			
			For Each OutputParameter In CurrentGroup.OutputParameters.Items Do
				If OutputParameter.Parameter = FilterOutput Then
					OutputParameter.Use		= True;
					OutputParameter.Value	= DataCompositionTextOutputType.DontOutput;
				EndIf;
			EndDo;
			
			CurrentGroup.Name = "Account";
			
			CurrentStructure = CurrentGroup.Structure;
			
			If CurrencyAmount Then
				CurrentGroup = CurrentStructure.Add();
				NewGroupField = CurrentGroup.GroupFields.Items.Add(Type("DataCompositionGroupField"));
				NewGroupField.Field = New DataCompositionField("Currency");
				NewGroupField.GroupType = DataCompositionGroupType.Items;
				NewSelectionField = CurrentGroup.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
			EndIf;
			
			For Index = 1 To MaxAnalyticalDimensionsNumber Do
				
				ExtDimensionName = StrTemplate("ExtDimension%1", Index);
				
				CurrentGroup = CurrentStructure.Add();
				NewGroupField = CurrentGroup.GroupFields.Items.Add(Type("DataCompositionGroupField"));
				NewGroupField.Field = New DataCompositionField(ExtDimensionName);
				NewGroupField.GroupType = DataCompositionGroupType.Items;	
				NewSelectionField = CurrentGroup.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
				
				CurrentStructure = CurrentGroup.Structure;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure SetFilterBySubaccounts(Form) Export
	
	Report = Form.Report;
	
	SetFiltersBySubaccounts(Report, Form.AccountingGroupingByAccountsTable, Form.BySubaccounts);
	
EndProcedure

Procedure SetFiltersBySubaccounts(Report, AccountingGroupingByAccountsTable, BySubaccounts) Export
	
	ParameterBySubaccounts = New DataCompositionParameter("BySubaccounts");
	
	For Each UserSetting In Report.SettingsComposer.Settings.DataParameters.Items Do
		
		If TypeOf(UserSetting) = Type("DataCompositionSettingsParameterValue") Then
			If UserSetting.Parameter = ParameterBySubaccounts Then
				UserSetting.Value = BySubaccounts; 
			EndIf;
		EndIf;
		
	EndDo;
	
	SetReportSettingsBySubaccounts(Report, AccountingGroupingByAccountsTable, BySubaccounts);
	
EndProcedure

Procedure PresentationCurrencyOnChange(Form) Export
	SetGroupingSettings(Form);
EndProcedure

Procedure CurrencyAmountOnChange(Form) Export
	SetGroupingSettings(Form);
EndProcedure

Procedure ReportTitleOnChange(Form) Export
	
	Report = Form.Report;
	
	SetReportTitle(Report, Form.ItemReportTitle);
	
	SaveReportParameters(Form);
	
EndProcedure

Procedure SetReportTitle(Report, ItemReportTitle) Export 
	OutputParameters = Report.SettingsComposer.Settings.OutputParameters.Items;
	
	ParameterReportTitle = New DataCompositionParameter("TitleOutput");
	
	For Each ParameterRow In OutputParameters Do
		
		If ParameterRow.Parameter = ParameterReportTitle Then
			
			ParameterRow.Use = True;
			
			If ItemReportTitle Then
				ParameterRow.Value = DataCompositionTextOutputType.Output;
			Else
				ParameterRow.Value = DataCompositionTextOutputType.DontOutput;
			EndIf;
			
		EndIf;
		
	EndDo;
EndProcedure

Procedure DisplayParametersAndFiltersOnChange(Form) Export
	
	Report = Form.Report;
	
	SetDisplayParametersAndFilters(Report, Form.ItemDisplayParametersAndFilters);
	
	SaveReportParameters(Form);
	
EndProcedure

Procedure SetDisplayParametersAndFilters(Report, ItemDisplayParametersAndFilters) Export
	OutputParameters = Report.SettingsComposer.Settings.OutputParameters.Items;
	
	ParameterDataParametersOutput = New DataCompositionParameter("DataParametersOutput");
	ParameterFilterOutput = New DataCompositionParameter("FilterOutput");
	
	For Each ParameterRow In OutputParameters Do
		
		If ParameterRow.Parameter = ParameterDataParametersOutput Then
			
			ParameterRow.Use = True;
			
			If ItemDisplayParametersAndFilters Then
				ParameterRow.Value = DataCompositionTextOutputType.Output;
			Else
				ParameterRow.Value = DataCompositionTextOutputType.DontOutput;
			EndIf;
			
		EndIf;
		
		If ParameterRow.Parameter = ParameterFilterOutput Then
			
			ParameterRow.Use = True;
			
			If ItemDisplayParametersAndFilters Then
				ParameterRow.Value = DataCompositionTextOutputType.Output;
			Else
				ParameterRow.Value = DataCompositionTextOutputType.DontOutput;
			EndIf;
			
		EndIf;
		
	EndDo;
EndProcedure

Procedure HighlightNegativeValuesOnChange(Form) Export
	
	Report = Form.Report;
	
	SetHighlightNegativeValues(Report, Form.ItemHighlightNegativeValues);
	
	SaveReportParameters(Form);

EndProcedure

Procedure SetHighlightNegativeValues(Report, ItemHighlightNegativeValues) Export
	
	ConditionalAppearance = Report.SettingsComposer.Settings.ConditionalAppearance.Items;
	
	SettingsFound = False;
	
	MarkNegativesParameter = New DataCompositionParameter("MarkNegatives");
	
	For Each ConditionalAppearanceItem In ConditionalAppearance Do
		
		For Each AppearanceItem In ConditionalAppearanceItem.Appearance.Items Do
			
			If AppearanceItem.Parameter = MarkNegativesParameter AND AppearanceItem.Use Then
				
				AppearanceItem.Use = ItemHighlightNegativeValues;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure AccountNameOnChange(Form) Export
	ReportSettings = Form.ReportSettings;
	
	Report = Form.Report;
	
	StorageStructure = New Structure;
	
	SaveReportParameters(Form, StorageStructure);
	
	GenerateReportStructure(Report.SettingsComposer.Settings.Structure, StorageStructure);  
	
	SetFilterBySubaccounts(Form);
EndProcedure

Procedure DetailedBalanceOnChange(Form) Export
	SetGroupingSettings(Form);
EndProcedure

Procedure ReportSettingsFormParameterOnChange(Form, DCUserSetting) Export
	
EndProcedure

Procedure ReportFormParameterOnChange(Form, DCUserSetting) Export
	
	ReportStructure = Form.Report.SettingsComposer.Settings.DataParameters.Items.Find("ReportStructure").Value.Get();
	
	If ReportStructure = Undefined Then
		LoadDefaultReportSettings(Form);
	EndIf;
	
EndProcedure

Procedure OnLoadUserSettingsAtServer(Form) Export
	ReloadReport(Form);
EndProcedure

Procedure LoadDefaultReportSettings(Form) Export
	Report			= Form.Report;
	ReportSettings	= Form.ReportSettings;
	
	AccountingGroupingTable = New ValueTable;
	
	AccountingGroupingTable.Columns.Add("Use", New TypeDescription("Boolean"));
	AccountingGroupingTable.Columns.Add("Account", New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts"));
	AccountingGroupingTable.Columns.Add("BySubaccounts", New TypeDescription("Boolean"));
	AccountingGroupingTable.Columns.Add("ExtDimensions", New TypeDescription("ValueList"));
	
	DetailedBalanceTable = New ValueTable;
	
	DetailedBalanceTable.Columns.Add("Use", New TypeDescription("Boolean"));
	DetailedBalanceTable.Columns.Add("Account", New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts"));
	DetailedBalanceTable.Columns.Add("BySubaccounts", New TypeDescription("Boolean"));
	DetailedBalanceTable.Columns.Add("ExtDimensions", New TypeDescription("ValueList"));
	
	NewReportStructure = New Structure;
	
	FillDefaultSettings(NewReportStructure, Undefined);
	
	GenerateReportSchema(Form, ReportSettings, Report, AccountingGroupingTable, DetailedBalanceTable, False);
	GenerateReportStructure(Report.SettingsComposer.Settings.Structure, NewReportStructure);
	SetReportSettingsBySubaccounts(Report, AccountingGroupingTable, False);
	
	SetReportTitle(Report, True);
	SetDisplayParametersAndFilters(Report, True);
	SetHighlightNegativeValues(Report, True);
	
EndProcedure

Procedure FillReportFormSettings(ReportSettings) Export
	
	ReportSettings.Insert("UseProcedureOnLoadUserSettingsAtServer", True);
	ReportSettings.Insert("ReportFormParameterOnChange", True);
	ReportSettings.Insert("LoadDefaultReportSettings", True);
	
EndProcedure

Procedure FillDetailsRules(Rules) Export
	
	// To be developed
	
EndProcedure

#EndRegion

#Region Private

Procedure SetSettingsItemsVisible(Form)
	
	Items = Form.Items;
	
	Items.AccountingGroupingByAccounts.Visible		= True;
	Items.BySubaccountsAccountingGrouping.Visible	= True;
	Items.AccountingGroupingByAccountsTable.Visible	= True;
	
	Items.AccountingFilters.Visible					= True;
	Items.SettingsComposerSettingsFilter.Visible	= True;
	
	Items.ReportItems.Visible						= True;
	Items.ItemPresentationCurrency.Visible			= True;
	Items.ItemCurrencyAmount.Visible				= True;
	Items.ItemReportTitle.Visible					= True;
	Items.ItemDisplayParametersAndFilters.Visible	= True;
	Items.ItemAccountName.Visible					= True;
	Items.ItemHighlightNegativeValues.Visible		= True;
	
	Items.DetailedBalance.Visible		= True;
	Items.DetailedBalanceTable.Visible	= True;
	
EndProcedure

Procedure SetChoiceParameterLinksForFilters(ChartOfAccountsValue, FilterItems)
	For Each FilterItem In FilterItems Do
		If TypeOf(FilterItem) = Type("DataCompositionFilterItemGroup") Then
			SetChoiceParameterLinksForFilters(ChartOfAccountsValue, FilterItem.Items);
		Else
			If TypeOf(FilterItem.RightValue) = Type("ChartOfAccountsRef.MasterChartOfAccounts")
				And ValueIsFilled(FilterItem.RightValue) 
				And FilterItem.RightValue.ChartOfAccounts <> ChartOfAccountsValue Then
				
				FilterItem.RightValue = ChartsOfAccounts.MasterChartOfAccounts.EmptyRef();
				
			ElsIf TypeOf(FilterItem.RightValue) = Type("ValueList")
					And FilterItem.RightValue.Count() > 0
					And TypeOf(FilterItem.RightValue[0].Value) = Type("ChartOfAccountsRef.MasterChartOfAccounts")
					And FilterItem.RightValue[0].Value.ChartOfAccounts <> ChartOfAccountsValue Then
					
					FilterItem.RightValue.Clear();
					
			EndIf;
		EndIf;
	EndDo;
EndProcedure

Procedure CheckAccountRows(ChartOfAccountsValue, Table)
	For Each Row In Table Do
		If ValueIsFilled(Row.Account) 
			And Row.Account.ChartOfAccounts <> ChartOfAccountsValue Then
			
			Row.Account = Undefined;
			Row.ExtDimensionsPresentation = "";
			
			Row.ExtDimensions.Clear();
			
		EndIf;
	EndDo;
EndProcedure

Procedure AddDefaultGroupDetails(NewTable)
	
	Details				= NewTable.Columns.Add();
	Details.Use			= True;
	
	ParameterTotalsPlacement = New DataCompositionParameter("OverallsPlacement");

	For Each OutputParameter In Details.OutputParameters.Items Do
		If OutputParameter.Parameter = ParameterTotalsPlacement Then
			OutputParameter.Use = True;
			OutputParameter.Value = DataCompositionTotalPlacement.None;
		EndIf;
	EndDo;
	
	NewGroupField		= Details.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	NewGroupField.Field	= New DataCompositionField("Indicator");
	NewGroupField.Use	= True;
	
	Details.Name = "Details";
	
	FieldIndicator			= Details.Selection.Items.Add(Type("DataCompositionSelectedField"));
	FieldIndicator.Field	= New DataCompositionField("Indicator");
	FieldIndicator.Use		= True;
	
	FieldGroup				= Details.Selection.Items.Add(Type("DataCompositionSelectedFieldGroup"));
	FieldGroup.Title		= "Details";
	FieldGroup.Placement	= DataCompositionFieldPlacement.Vertically;
	FieldGroup.Use			= True;
	
	Field		= FieldGroup.Items.Add(Type("DataCompositionSelectedField"));
	Field.Field	= New DataCompositionField("Details.PresentationCurrency");
	Field.Use	= True;
	
	Field		= FieldGroup.Items.Add(Type("DataCompositionSelectedField"));
	Field.Field	= New DataCompositionField("Details.Currency");
	Field.Use	= True;

EndProcedure

Procedure AddDefaultGroupOpeningBalance(NewTable)
	OpeningBalance		= NewTable.Columns.Add();
	OpeningBalance.Use	= True;
	
	ParameterTotalsPlacement = New DataCompositionParameter("OverallsPlacement");

	For Each OutputParameter In OpeningBalance.OutputParameters.Items Do
		If OutputParameter.Parameter = ParameterTotalsPlacement Then
			OutputParameter.Use = True;
			OutputParameter.Value = DataCompositionTotalPlacement.None;
		EndIf;
	EndDo;
	
	NewGroupField		= OpeningBalance.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	NewGroupField.Field	= New DataCompositionField("Indicator");
	NewGroupField.Use	= True;
	
	OpeningBalance.Name = "OpeningBalance";
	
	FieldIndicator			= OpeningBalance.Selection.Items.Add(Type("DataCompositionSelectedField"));
	FieldIndicator.Field	= New DataCompositionField("Indicator");
	FieldIndicator.Use		= True;
	
	FieldGroup				= OpeningBalance.Selection.Items.Add(Type("DataCompositionSelectedFieldGroup"));
	FieldGroup.Title		= "OpeningBalance";
	FieldGroup.Placement	= DataCompositionFieldPlacement.Horizontally;
	FieldGroup.Use			= True;
	
	FieldGroupDr			= FieldGroup.Items.Add(Type("DataCompositionSelectedFieldGroup"));
	FieldGroupDr.Title		= "Debit";
	FieldGroupDr.Placement	= DataCompositionFieldPlacement.Vertically;
	FieldGroupDr.Use		= True;
	
	Field		= FieldGroupDr.Items.Add(Type("DataCompositionSelectedField"));
	Field.Field = New DataCompositionField("AmountOpeningBalanceDr");
	Field.Use	= True;
	
	Field		= FieldGroupDr.Items.Add(Type("DataCompositionSelectedField"));
	Field.Field = New DataCompositionField("AmountCurOpeningBalanceDr");
	Field.Use	= True;
	
	FieldGroupCr			= FieldGroup.Items.Add(Type("DataCompositionSelectedFieldGroup"));
	FieldGroupCr.Title		= "Credit";
	FieldGroupCr.Placement	= DataCompositionFieldPlacement.Vertically;
	FieldGroupCr.Use		= True;
	
	Field		= FieldGroupCr.Items.Add(Type("DataCompositionSelectedField"));
	Field.Field = New DataCompositionField("AmountOpeningBalanceCr");
	Field.Use	= True;
	
	Field		= FieldGroupCr.Items.Add(Type("DataCompositionSelectedField"));
	Field.Field = New DataCompositionField("AmountCurOpeningBalanceCr");
	Field.Use	= True;
	
EndProcedure

Procedure AddDefaultGroupTurnovers(NewTable)
	Turnovers			= NewTable.Columns.Add();
	Turnovers.Use		= True;
	
	ParameterTotalsPlacement = New DataCompositionParameter("OverallsPlacement");

	For Each OutputParameter In Turnovers.OutputParameters.Items Do
		If OutputParameter.Parameter = ParameterTotalsPlacement Then
			OutputParameter.Use = True;
			OutputParameter.Value = DataCompositionTotalPlacement.None;
		EndIf;
	EndDo;
	
	NewGroupField		= Turnovers.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	NewGroupField.Field	= New DataCompositionField("Indicator");
	NewGroupField.Use	= True;
	
	Turnovers.Name = "TurnoverForPeriod";
	
	FieldIndicator			= Turnovers.Selection.Items.Add(Type("DataCompositionSelectedField"));
	FieldIndicator.Field	= New DataCompositionField("Indicator");
	FieldIndicator.Use		= True;
	
	FieldGroup = Turnovers.Selection.Items.Add(Type("DataCompositionSelectedFieldGroup"));
	FieldGroup.Title		= "TurnoverForPeriod";
	FieldGroup.Placement	= DataCompositionFieldPlacement.Horizontally;
	FieldGroup.Use			= True;
	
	FieldGroupDr			= FieldGroup.Items.Add(Type("DataCompositionSelectedFieldGroup"));
	FieldGroupDr.Title		= "Debit";
	FieldGroupDr.Placement	= DataCompositionFieldPlacement.Vertically;
	FieldGroupDr.Use		= True;
	
	Field		= FieldGroupDr.Items.Add(Type("DataCompositionSelectedField"));
	Field.Field = New DataCompositionField("AmountTurnoverDr");
	Field.Use		= True;
	
	Field		= FieldGroupDr.Items.Add(Type("DataCompositionSelectedField"));
	Field.Field = New DataCompositionField("AmountCurTurnoverDr");
	Field.Use	= True;
	
	FieldGroupCr			= FieldGroup.Items.Add(Type("DataCompositionSelectedFieldGroup"));
	FieldGroupCr.Title		= "Credit";
	FieldGroupCr.Placement	= DataCompositionFieldPlacement.Vertically;
	FieldGroupCr.Use		= True;
	
	Field		= FieldGroupCr.Items.Add(Type("DataCompositionSelectedField"));
	Field.Field = New DataCompositionField("AmountTurnoverCr");
	Field.Use	= True;
	
	Field		= FieldGroupCr.Items.Add(Type("DataCompositionSelectedField"));
	Field.Field = New DataCompositionField("AmountCurTurnoverCr");
	Field.Use	= True;
	
EndProcedure

Procedure AddDefaultGroupClosingBalance(NewTable)
	ClosingBalance		= NewTable.Columns.Add();
	ClosingBalance.Use	= True;
	
	ParameterTotalsPlacement = New DataCompositionParameter("OverallsPlacement");

	For Each OutputParameter In ClosingBalance.OutputParameters.Items Do
		If OutputParameter.Parameter = ParameterTotalsPlacement Then
			OutputParameter.Use = True;
			OutputParameter.Value = DataCompositionTotalPlacement.None;
		EndIf;
	EndDo;
	
	NewGroupField		= ClosingBalance.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	NewGroupField.Field	= New DataCompositionField("Indicator");
	NewGroupField.Use	= True;
	
	ClosingBalance.Name = "ClosingBalance";
	
	FieldIndicator			= ClosingBalance.Selection.Items.Add(Type("DataCompositionSelectedField"));
	FieldIndicator.Field	= New DataCompositionField("Indicator");
	FieldIndicator.Use		= True;
	
	FieldGroup = ClosingBalance.Selection.Items.Add(Type("DataCompositionSelectedFieldGroup"));
	FieldGroup.Title		= "ClosingBalance";
	FieldGroup.Placement	= DataCompositionFieldPlacement.Horizontally;
	FieldGroup.Use			= True;
	
	FieldGroupDr			= FieldGroup.Items.Add(Type("DataCompositionSelectedFieldGroup"));
	FieldGroupDr.Title		= "Debit";
	FieldGroupDr.Placement	= DataCompositionFieldPlacement.Vertically;
	FieldGroupDr.Use		= True;
	
	Field		= FieldGroupDr.Items.Add(Type("DataCompositionSelectedField"));
	Field.Field = New DataCompositionField("AmountClosingBalanceDr");
	Field.Use		= True;
	
	Field		= FieldGroupDr.Items.Add(Type("DataCompositionSelectedField"));
	Field.Field = New DataCompositionField("AmountCurClosingBalanceDr");
	Field.Use	= True;
	
	FieldGroupCr			= FieldGroup.Items.Add(Type("DataCompositionSelectedFieldGroup"));
	FieldGroupCr.Title		= "Credit";
	FieldGroupCr.Placement	= DataCompositionFieldPlacement.Vertically;
	FieldGroupCr.Use		= True;
	
	Field		= FieldGroupCr.Items.Add(Type("DataCompositionSelectedField"));
	Field.Field = New DataCompositionField("AmountClosingBalanceCr");
	Field.Use	= True;
	
	Field		= FieldGroupCr.Items.Add(Type("DataCompositionSelectedField"));
	Field.Field = New DataCompositionField("AmountCurClosingBalanceCr");
	Field.Use	= True;
	
EndProcedure

Procedure SetTotalsFields(DataCompositionSchema, Expression = Undefined, Groups = Undefined)
	
	If Expression = Undefined Or Expression = "False" Then
		ExpressionAmountOpeningBalanceDr	= "SUM(AmountOpeningBalanceDr)";
		ExpressionAmountOpeningBalanceCr	= "SUM(AmountOpeningBalanceCr)";
		ExpressionAmountCurOpeningBalanceDr = "SUM(AmountCurOpeningBalanceDr)";
		ExpressionAmountCurOpeningBalanceCr = "SUM(AmountCurOpeningBalanceCr)";
		ExpressionAmountClosingBalanceDr	= "SUM(AmountClosingBalanceDr)";
		ExpressionAmountClosingBalanceCr	= "SUM(AmountClosingBalanceCr)";
		ExpressionAmountCurClosingBalanceDr = "SUM(AmountCurClosingBalanceDr)";
		ExpressionAmountCurClosingBalanceCr = "SUM(AmountCurClosingBalanceCr)";
	Else
		ExpressionAmountOpeningBalanceDr = StrTemplate(
			"Case 
			|	When %1
			|		Then SUM(AmountOpeningSplittedBalanceDr)
			|	Else SUM(AmountOpeningBalanceDr) 
			|End",
			Expression);
		ExpressionAmountOpeningBalanceCr = StrTemplate(
			"Case 
			|	When %1
			|		Then SUM(AmountOpeningSplittedBalanceCr)
			|	Else SUM(AmountOpeningBalanceCr) 
			|End",
			Expression);
		ExpressionAmountCurOpeningBalanceDr = StrTemplate(
			"Case 
			|	When %1
			|		Then SUM(AmountCurOpeningSplittedBalanceDr)
			|	Else SUM(AmountCurOpeningBalanceDr) 
			|End",
			Expression);
		ExpressionAmountCurOpeningBalanceCr = StrTemplate(
			"Case 
			|	When %1
			|		Then SUM(AmountCurOpeningSplittedBalanceCr)
			|	Else SUM(AmountCurOpeningBalanceCr) 
			|End",
			Expression);
		ExpressionAmountClosingBalanceDr = StrTemplate(
			"Case 
			|	When %1
			|		Then SUM(AmountClosingSplittedBalanceDr)
			|	Else SUM(AmountClosingBalanceDr) 
			|End",
			Expression);
		ExpressionAmountClosingBalanceCr = StrTemplate(
			"Case 
			|	When %1
			|		Then SUM(AmountClosingSplittedBalanceCr)
			|	Else SUM(AmountClosingBalanceCr) 
			|End",
			Expression);
		ExpressionAmountCurClosingBalanceDr = StrTemplate(
			"Case 
			|	When %1
			|		Then SUM(AmountCurClosingSplittedBalanceDr)
			|	Else SUM(AmountCurClosingBalanceDr) 
			|End",
			Expression);
		ExpressionAmountCurClosingBalanceCr = StrTemplate(
			"Case 
			|	When %1
			|		Then SUM(AmountCurClosingSplittedBalanceCr)
			|	Else SUM(AmountCurClosingBalanceCr) 
			|End",
			Expression);
	EndIf;
	
	AddTotalItem(
		DataCompositionSchema,
		"AmountOpeningBalanceDr",
		ExpressionAmountOpeningBalanceDr,
		Groups);
	
	AddTotalItem(
		DataCompositionSchema,
		"AmountOpeningBalanceCr",
		ExpressionAmountOpeningBalanceCr,
		Groups);
	
	AddTotalItem(
		DataCompositionSchema,
		"AmountCurOpeningBalanceDr",
		ExpressionAmountCurOpeningBalanceDr,
		Groups);
	
	AddTotalItem(
		DataCompositionSchema,
		"AmountCurOpeningBalanceCr",
		ExpressionAmountCurOpeningBalanceCr,
		Groups);
	
	AddTotalItem(
		DataCompositionSchema,
		"AmountClosingBalanceDr",
		ExpressionAmountClosingBalanceDr,
		Groups);
	
	AddTotalItem(
		DataCompositionSchema,
		"AmountClosingBalanceCr",
		ExpressionAmountClosingBalanceCr,
		Groups);
	
	AddTotalItem(
		DataCompositionSchema,
		"AmountCurClosingBalanceDr",
		ExpressionAmountCurClosingBalanceDr,
		Groups);
	
	AddTotalItem(
		DataCompositionSchema,
		"AmountCurClosingBalanceCr",
		ExpressionAmountCurClosingBalanceCr,
		Groups);

EndProcedure

Procedure AddTotalItem(DataCompositionSchema, DataPath, Expression, Groups)
	
	TotalItem				= DataCompositionSchema.TotalFields.Add();
	TotalItem.DataPath		= DataPath;
	TotalItem.Expression	= Expression;
	
	TotalItem.Groups.Clear();
	
	If Groups <> Undefined Then
		For Each GroupItem In Groups Do
			TotalItem.Groups.Add(GroupItem);
		EndDo;
	EndIf;

EndProcedure

Function PresentationCurrencyFindedFields()
	
	PresentationCurrencyFindedFields = New Array;
	
	PresentationCurrencyFindedFields.Add(New DataCompositionField("Details.PresentationCurrency"));
	PresentationCurrencyFindedFields.Add(New DataCompositionField("AmountOpeningBalanceDr"));
	PresentationCurrencyFindedFields.Add(New DataCompositionField("AmountOpeningBalanceCr"));
	PresentationCurrencyFindedFields.Add(New DataCompositionField("AmountTurnoverDr"));
	PresentationCurrencyFindedFields.Add(New DataCompositionField("AmountTurnoverCr"));
	PresentationCurrencyFindedFields.Add(New DataCompositionField("AmountClosingBalanceDr"));
	PresentationCurrencyFindedFields.Add(New DataCompositionField("AmountClosingBalanceCr"));

	Return PresentationCurrencyFindedFields; 
	
EndFunction

Function CurrencyAmountFindedFields()
	
	CurrencyAmountFindedFields = New Array;
	
	CurrencyAmountFindedFields.Add(New DataCompositionField("Details.Currency"));
	CurrencyAmountFindedFields.Add(New DataCompositionField("AmountCurOpeningBalanceDr"));
	CurrencyAmountFindedFields.Add(New DataCompositionField("AmountCurOpeningBalanceCr"));
	CurrencyAmountFindedFields.Add(New DataCompositionField("AmountCurTurnoverDr"));
	CurrencyAmountFindedFields.Add(New DataCompositionField("AmountCurTurnoverCr"));
	CurrencyAmountFindedFields.Add(New DataCompositionField("AmountCurClosingBalanceDr"));
	CurrencyAmountFindedFields.Add(New DataCompositionField("AmountCurClosingBalanceCr"));

	Return CurrencyAmountFindedFields; 
	
EndFunction

Procedure SetSelectedFieldVisible(SelectedFields, FindedFields, Visible)

	For Each SelectedField In SelectedFields Do
		
		If TypeOf(SelectedField) = Type("DataCompositionSelectedFieldGroup") Then
			
			SetSelectedFieldVisible(SelectedField.Items, FindedFields, Visible);
			
		Else
			
			If FindedFields.Find(SelectedField.Field) <> Undefined Then
				
				SelectedField.Use = Visible;
				
			EndIf;
			
		EndIf;
		
	EndDo;

EndProcedure

Procedure RebuildStructureBySubaccounts(CurrentStructure, AccountList, BySubaccounts)
	
	For Each StructureRow In CurrentStructure Do
		
		If StructureRow.Name = "Account" Then
			
			StructureRow.Filter.Items.Clear();
			StructureRow.ConditionalAppearance.Items.Clear();
			
			If Not BySubaccounts Then 
				
				CurrentGroup = StructureRow.Filter.Items;
				
				If AccountList.Count() > 0 Then
					FilterGroup = CurrentGroup.Add(Type("DataCompositionFilterItemGroup"));
					FilterGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
					FilterGroup.Application = DataCompositionFilterApplicationType.Hierarchy;
					
					CurrentGroup = FilterGroup.Items;
					
					FilterItem = CurrentGroup.Add(Type("DataCompositionFilterItem"));
					
					FilterItem.LeftValue = New DataCompositionField("Account");
					FilterItem.ComparisonType = DataCompositionComparisonType.InListByHierarchy;
					FilterItem.RightValue = AccountList;
					FilterItem.Use = True;
					FilterItem.Application = DataCompositionFilterApplicationType.Hierarchy;
					
				EndIf;
				
				FilterItem = CurrentGroup.Add(Type("DataCompositionFilterItem"));
				
				FilterItem.LeftValue = New DataCompositionField("SystemFields.LevelInGroup");
				FilterItem.RightValue = 1;
				FilterItem.Use = True;
				FilterItem.Application = DataCompositionFilterApplicationType.Hierarchy;
				
				CurrentGroup = StructureRow.ConditionalAppearance.Items;
				
				ConditionalAppearanceItem = CurrentGroup.Add();
				
				ConditionalAppearanceItem.UseInFieldsHeader					= DataCompositionConditionalAppearanceUse.DontUse;
				ConditionalAppearanceItem.UseInFilter 						= DataCompositionConditionalAppearanceUse.DontUse;
				ConditionalAppearanceItem.UseInGroup						= DataCompositionConditionalAppearanceUse.DontUse;
				ConditionalAppearanceItem.UseInHeader						= DataCompositionConditionalAppearanceUse.DontUse;
				ConditionalAppearanceItem.UseInOverall						= DataCompositionConditionalAppearanceUse.DontUse;
				ConditionalAppearanceItem.UseInOverallHeader				= DataCompositionConditionalAppearanceUse.DontUse;
				ConditionalAppearanceItem.UseInOverallResourceFieldsHeader	= DataCompositionConditionalAppearanceUse.DontUse;
				ConditionalAppearanceItem.UseInParameters					= DataCompositionConditionalAppearanceUse.DontUse;
				ConditionalAppearanceItem.UseInResourceFieldsHeader			= DataCompositionConditionalAppearanceUse.DontUse;
				
				FontItem = ConditionalAppearanceItem.Appearance.Items.Find("Font");
				FontItem.Value	= New Font(, , , False);
				FontItem.Use	= True;
				
			EndIf;
			
		EndIf;
		
		RebuildStructureBySubaccounts(StructureRow.Structure, AccountList, BySubaccounts);
		
	EndDo;
	
EndProcedure

Procedure SetReportSettingsBySubaccounts(Report, AccountingGroupingByAccountsTable, BySubaccounts)
	
	CurrentStructure = Report.SettingsComposer.Settings.Structure;
	
	AccountList = New ValueList;
	
	For Each GroupingRow In AccountingGroupingByAccountsTable Do
		If GroupingRow.Use AND GroupingRow.BySubaccounts Then
			AccountList.Add(GroupingRow.Account);
		EndIf;
	EndDo;
	
	For Each Table In CurrentStructure Do
		
		If TypeOf(Table) = Type("DataCompositionTable") Then
			
			RebuildStructureBySubaccounts(Table.Rows, AccountList, BySubaccounts);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function GetSubordinateAccounts(Account, OnlyActivePassive = False)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	MasterChartOfAccounts.Ref AS Ref
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
	|WHERE
	|	MasterChartOfAccounts.Ref IN HIERARCHY(&Account)
	|	AND CASE
	|			WHEN &OnlyActivePassive
	|				THEN MasterChartOfAccounts.Type = VALUE(AccountType.ActivePassive)
	|			ELSE TRUE
	|		END";
	
	Query.SetParameter("Account", Account);
	Query.SetParameter("OnlyActivePassive", OnlyActivePassive);
	
	QueryResult = Query.Execute();
	
	AccountsArray = QueryResult.Unload().UnloadColumn("Ref");
	
	AccountsList = New ValueList;
	
	AccountsList.LoadValues(AccountsArray);
	
	Return AccountsList; 
	
EndFunction

Procedure SaveReportParameters(Form, StorageStructure = Undefined)
	
	AccountingGroupingByAccountsTable	= Form.AccountingGroupingByAccountsTable;
	DetailedBalanceTable				= Form.DetailedBalanceTable;
	
	ReportSettings = Form.ReportSettings;
	
	StorageStructure = GetSettingsStructure(Form);
	
	StorageStructure.Insert("ReportStructure"		, AccountingGroupingByAccountsTable.Unload());
	StorageStructure.Insert("DetailedBalanceTable"	, DetailedBalanceTable.Unload());
	
	ReportStructureStorage = New ValueStorage(StorageStructure);
	
	ParameterReportStructure = New DataCompositionParameter("ReportStructure");
	
	For Each UserSetting In Form.Report.SettingsComposer.Settings.DataParameters.Items Do
		
		If TypeOf(UserSetting) = Type("DataCompositionSettingsParameterValue") Then
			If UserSetting.Parameter = ParameterReportStructure Then
				
				UserSetting.Value = ReportStructureStorage;
				
			EndIf;
		EndIf;
		
	EndDo;

	ReportSettings.TemporaryParameters.Insert("ReportStructure", ReportStructureStorage);
	
EndProcedure 

Function GetSettingsStructure(Form)
	
	SettingsStructure = New Structure;
	
	SettingsStructure.Insert("PresentationCurrency"			, Form.ItemPresentationCurrency);
	SettingsStructure.Insert("CurrencyAmount"				, Form.ItemCurrencyAmount);
	SettingsStructure.Insert("Quantity"						, Form.ItemQuantity);
	SettingsStructure.Insert("AccountName"					, Form.ItemAccountName);
	SettingsStructure.Insert("DetailedBalance"				, Form.ItemDetailedBalance);
	SettingsStructure.Insert("DisplayParametersAndFilters"	, Form.ItemDisplayParametersAndFilters);
	SettingsStructure.Insert("HighlightNegativeValues"		, Form.ItemHighlightNegativeValues);
	SettingsStructure.Insert("ReportTitle"					, Form.ItemReportTitle);
	
	Return SettingsStructure;
	
EndFunction

Procedure ReloadReport(Form)

	Report			= Form.Report;
	ReportSettings	= Form.ReportSettings;
	
	AccountingGroupingTable = New ValueTable;
	
	AccountingGroupingTable.Columns.Add("Use", New TypeDescription("Boolean"));
	AccountingGroupingTable.Columns.Add("Account", New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts"));
	AccountingGroupingTable.Columns.Add("BySubaccounts", New TypeDescription("Boolean"));
	AccountingGroupingTable.Columns.Add("ExtDimensions", New TypeDescription("ValueList"));
	
	DetailedBalanceTable = New ValueTable;
	
	DetailedBalanceTable.Columns.Add("Use", New TypeDescription("Boolean"));
	DetailedBalanceTable.Columns.Add("Account", New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts"));
	DetailedBalanceTable.Columns.Add("BySubaccounts", New TypeDescription("Boolean"));
	DetailedBalanceTable.Columns.Add("ExtDimensions", New TypeDescription("ValueList"));
	
	ParameterReportStructure = New DataCompositionParameter("ReportStructure");
	ParameterBySubaccounts 	 = New DataCompositionParameter("BySubaccounts");
	
	SavedGroupingTable			= Undefined;
	SavedDetailedBalanceTable	= Undefined;
	SavedReportStructure		= Undefined;
	
	BySubaccounts = False;
	
	For Each ParameterRow In Report.SettingsComposer.Settings.DataParameters.Items Do
		If TypeOf(ParameterRow) = Type("DataCompositionSettingsParameterValue") Then
			If ParameterRow.Parameter = ParameterReportStructure	Then
				
				ReportStructure = ParameterRow.Value.Get();
				
				If ReportStructure <> Undefined Then
					
					SavedReportStructure = ReportStructure;
					
					If ReportStructure.Property("ReportStructure") Then
						SavedGroupingTable = ReportStructure.ReportStructure;
					EndIf;
					
					If ReportStructure.Property("DetailedBalanceTable") Then
						SavedDetailedBalanceTable = ReportStructure.DetailedBalanceTable;
					EndIf;
					
				EndIf;
				
			ElsIf ParameterRow.Parameter = ParameterBySubaccounts Then
				BySubaccounts = ParameterRow.Value;
			EndIf;
		EndIf;
	EndDo;
	
	NewReportStructure = New Structure;
	
	Reports.TrialBalanceMaster.FillDefaultSettings(NewReportStructure, SavedReportStructure);
	
	If SavedGroupingTable <> Undefined Then
		CurrentGrouping = SavedGroupingTable;
	Else
		CurrentGrouping = AccountingGroupingTable.Copy();
	EndIf;
	
	If SavedDetailedBalanceTable <> Undefined Then
		CurrentDetailedBalanceTable = SavedDetailedBalanceTable;
	Else
		CurrentDetailedBalanceTable = DetailedBalanceTable.Copy();
	EndIf;
	
	StorageStructure = New Structure;
	
	StorageStructure.Insert("ReportStructure", CurrentGrouping);
	StorageStructure.Insert("DetailedBalanceTable", CurrentDetailedBalanceTable);
	
	For Each NewReportStructureRow In NewReportStructure Do
		StorageStructure.Insert(NewReportStructureRow.Key, NewReportStructureRow.Value);
	EndDo;
	
	ReportStructureStorage = New ValueStorage(StorageStructure);
	
	ParameterReportStructure = New DataCompositionParameter("ReportStructure");
	
	For Each UserSetting In Report.SettingsComposer.Settings.DataParameters.Items Do
		
		If TypeOf(UserSetting) = Type("DataCompositionSettingsParameterValue") Then
			If UserSetting.Parameter = ParameterReportStructure Then
				UserSetting.Value = ReportStructureStorage;
			EndIf;
		EndIf;
		
	EndDo;
	
	GenerateReportSchema(Form, ReportSettings, Report, CurrentGrouping, CurrentDetailedBalanceTable, BySubaccounts);
	GenerateReportStructure(Report.SettingsComposer.Settings.Structure, NewReportStructure);
	SetFiltersBySubaccounts(Report, CurrentGrouping, BySubaccounts);
	
	SetReportTitle(Report, NewReportStructure.ReportTitle);
	SetDisplayParametersAndFilters(Report, NewReportStructure.DisplayParametersAndFilters);
	SetHighlightNegativeValues(Report, NewReportStructure.HighlightNegativeValues);
	
	ReportSettings.SchemaModified = True;
	
EndProcedure

#EndRegion

#EndIf