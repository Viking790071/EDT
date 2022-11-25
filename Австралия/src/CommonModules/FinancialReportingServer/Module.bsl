#Region Public

Function PicturesIndexesTable() Export
	
	PicturesTable = New ValueTable;
	PicturesTable.Columns.Add("ItemType", New TypeDescription("EnumRef.FinancialReportItemsTypes"));
	PicturesTable.Columns.Add("AuxiliaryItemName", New TypeDescription("String", , New StringQualifiers(10)));
	PicturesTable.Columns.Add("PictureIndex", New TypeDescription("Number", New NumberQualifiers(3, 0)));
	
	AddPicturesIndexesTableRow(PicturesTable, "ReportTitle",		"", 0);
	AddPicturesIndexesTableRow(PicturesTable, "NonEditableText",	"", 3);
	AddPicturesIndexesTableRow(PicturesTable, "EditableText",		"", 6);
	
	AddPicturesIndexesTableRow(PicturesTable, "BudgetItem", 					""	,		9);
	AddPicturesIndexesTableRow(PicturesTable, "BudgetItem", 					"Target",	39);
	AddPicturesIndexesTableRow(PicturesTable, "BudgetIndicator",				"",			39);
	AddPicturesIndexesTableRow(PicturesTable, "BudgetItemsAll", 				"",			9);
	AddPicturesIndexesTableRow(PicturesTable, "BudgetIndicatorsAll",			"",			39);
	AddPicturesIndexesTableRow(PicturesTable, "EditableValue", 					"",			51);
	AddPicturesIndexesTableRow(PicturesTable, "NonfinancialIndicator",			"",			50);
	AddPicturesIndexesTableRow(PicturesTable, "UserDefinedCalculatedIndicator",	"",			15);
	
	AddPicturesIndexesTableRow(PicturesTable, "AccountingDataIndicator",	"",		9);
	AddPicturesIndexesTableRow(PicturesTable, "AccountingDataIndicator",	"Fin",	39);
	AddPicturesIndexesTableRow(PicturesTable, "UserDefinedFixedIndicator",	"",		12);
	
	AddPicturesIndexesTableRow(PicturesTable, "TableIndicatorsInRows",		"",			21);
	AddPicturesIndexesTableRow(PicturesTable, "TableIndicatorsInColumns",	"",			21);
	AddPicturesIndexesTableRow(PicturesTable, "TableComplex", 				"",			21);
	AddPicturesIndexesTableRow(PicturesTable, "Columns", 					"",			24);
	AddPicturesIndexesTableRow(PicturesTable, "Rows", 						"",			27);
	AddPicturesIndexesTableRow(PicturesTable, "Columns", 					"Input",	46);
	AddPicturesIndexesTableRow(PicturesTable, "Rows", 						"Input",	47);
	AddPicturesIndexesTableRow(PicturesTable, "ConfigureCells", 			"",			48);
	AddPicturesIndexesTableRow(PicturesTable, "TableCell", 					"",			49);
	
	AddPicturesIndexesTableRow(PicturesTable, "GroupTotal",		"",			18);
	AddPicturesIndexesTableRow(PicturesTable, "Dimension",		"",			30);
	AddPicturesIndexesTableRow(PicturesTable, "Group",			"",			36);
	AddPicturesIndexesTableRow(PicturesTable, "",				"Group",	42);
	AddPicturesIndexesTableRow(PicturesTable, "TableItem",		"",			45);
	
	QueryText = 
	"SELECT
	|	PicturesIndexesTable.ItemType,
	|	PicturesIndexesTable.AuxiliaryItemName,
	|	PicturesIndexesTable.PictureIndex
	|INTO PicturesIndexesTable
	|FROM
	|	&PicturesIndexesTable AS PicturesIndexesTable";
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query(QueryText);
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("PicturesIndexesTable", PicturesTable);
	Query.Execute();
	
	Return TempTablesManager;
	
EndFunction

Function ReportItemReferencesQueryText() Export
	
	QueryText = 
	"SELECT
	|	FinancialReportsItems.Owner AS ReportType,
	|	FinancialReportsItems.Ref AS ReportItem,
	|	FinancialReportsItems.DescriptionForPrinting AS DescriptionForPrinting,
	|	PicturesIndexesTable.PictureIndex + 1 AS NonstandardPicture
	|FROM
	|	Catalog.FinancialReportsItems AS FinancialReportsItems
	|		LEFT JOIN PicturesIndexesTable AS PicturesIndexesTable
	|		ON FinancialReportsItems.ItemType = PicturesIndexesTable.ItemType
	|			AND (PicturesIndexesTable.AuxiliaryItemName = """")
	|WHERE
	|	FinancialReportsItems.DeletionMark = FALSE
	|	AND FinancialReportsItems.LinkedItem = &ReportItem
	|	AND (FinancialReportsItems.Owner <> &Owner
	|			OR &Owner = UNDEFINED)
	|
	|ORDER BY
	|	DescriptionForPrinting";
	
	Return QueryText;
	
EndFunction

Procedure RefreshNewItemsTree(Form, Parameters) Export
	
	QuickSearch = Undefined;
	TreeItemName = Parameters.TreeItemName;
	QuickSearch = Parameters.QuickSearch;
	WorkMode = Parameters.WorkMode;
	
	Query = New Query;
	TempTablesManager = PicturesIndexesTable();
	Query.TempTablesManager = TempTablesManager;
	Query.Text = QueryTextNewReportItems(QuickSearch);
	
	AvailableItemsTypes = AvailableNewReportItems(WorkMode);
	Query.SetParameter("AvailableItemsTypes", AvailableItemsTypes);
	
	ResultsArray = Query.ExecuteBatch();
	
	ItemsTree = Form.FormAttributeToValue(TreeItemName);
	ItemsTree.Rows.Clear();
	
	QueryResultToTree(ResultsArray[0], ItemsTree);
	// Empty user-defined fixed indicator is not available for selection
	ItemType = PredefinedValue("Enum.FinancialReportItemsTypes.UserDefinedFixedIndicator");
	IndicatorsRow = ItemsTree.Rows.Find(ItemType);
	IndicatorsRow.IsFolder = True;
	
	// Adding balance accounting data indicators
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		
		IndicatorTitleMng = NStr("en = 'Managerial accounting data indicator'; ru = 'Индикатор данных управленческого учета';pl = 'Wskaźnik danych rachunkowości zarządczej';es_ES = 'Indicador de datos de contables empresarial';es_CO = 'Indicador de datos de contables empresarial';tr = 'Yönetim muhasebesi veri göstergesi';it = 'Indicatore dati contabili gestionali';de = 'Indikator für die Daten des Betriebsrechnungswesens'");
		IndicatorTitleFin = NStr("en = 'Financial accounting data indicator'; ru = 'Индикатор данных финансового учета';pl = 'Wskaźnik danych rachunkowości finansowej';es_ES = 'Indicador de datos de contables financiero';es_CO = 'Indicador de datos de contables financiero';tr = 'Mali muhasebe veri göstergesi';it = 'Indicatore dati di contabilità finanziaria';de = 'Indikator für die Daten der Finanzbuchhaltung'");
		EmptyAccountMng = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
		EmptyAccountFin = ChartsOfAccounts.FinancialChartOfAccounts.EmptyRef();
		AddAccountingDataIndicators(ItemsTree, ResultsArray[1], EmptyAccountMng, IndicatorTitleMng);
		AddAccountingDataIndicators(ItemsTree, ResultsArray[2], EmptyAccountFin, IndicatorTitleFin, True);
		
	EndIf;

	// Adding user-defined fixed indicators
	UserDefinedFixedIndicatorsRow = ItemsTree.Rows.Find(Enums.FinancialReportItemsTypes.UserDefinedFixedIndicator);
	QueryResultToTree(ResultsArray[3], UserDefinedFixedIndicatorsRow);
	
	If WorkMode = Enums.NewItemsTreeDisplayModes.ReportTypeSetting Then
	
		// Adding table items
		TableRow = ItemsTree.Rows.Find(Enums.FinancialReportItemsTypes.TableComplex);
		RowItem = TableRow.Rows.Add();
		TableItem = Enums.FinancialReportItemsTypes.TableItem;
		RowItem.NonstandardPicture = FinancialReportingCached.NonstandardPicture(TableItem);
		RowItem.Description = String(TableItem);
		RowItem.DescriptionForPrinting = String(TableItem);
		RowItem.ItemType = TableItem;
		
		// Adding dimensions
		AddDimensionsToNewItemsTree(ItemsTree, QuickSearch);
		
	EndIf;
	
	Form.ValueToFormAttribute(ItemsTree, TreeItemName);
	
EndProcedure

Procedure RefreshExistingItemsTree(Form, Parameters) Export
	
	TreeItemName = GetParameter(Parameters, "TreeItemName");
	ReportTypeFilter = GetParameter(Parameters, "ReportTypeFilter");
	CurrentReportType = GetParameter(Parameters, "CurrentReportType");
	QuickSearch = GetParameter(Parameters, "QuickSearch");
	OutputComplexTableItems = GetParameter(Parameters, "OutputComplexTableItems", False);
	WorkMode = Parameters.WorkMode;
	AvailableItemsTypes = AvailableExistingReportItems(WorkMode);
	
	TreeSchema = Catalogs.FinancialReportsTypes.GetTemplate("ExistingItemsTree");
	TreeSchemaComposer = SchemaComposer(TreeSchema);
	DCSettings = TreeSchemaComposer.Settings;
	NewSelectionField(DCSettings, "LinkedItem.[Account]", "Account");
	NewSelectionField(DCSettings, "LinkedItem.[Totals type]", "Totals type");
	NewSelectionField(DCSettings, "LinkedItem.[Opening balance]", "Opening balance");
	NewSelectionField(DCSettings, "LinkedItem.[User defined fixed indicator]", "User defined fixed indicator");
	NewSelectionField(DCSettings, "LinkedItem.[Output item title]", "Output item title");
	
	SetCompositionParameter(DCSettings, "AvailableItemsTypes", AvailableItemsTypes);
	SetCompositionParameter(DCSettings, "OutputComplexTableItems", OutputComplexTableItems);
	SetCompositionParameter(DCSettings, "CurrentReport", CurrentReportType);
	
	SetFilter(DCSettings.Filter, "DescriptionForPrinting", QuickSearch, , ValueIsFilled(QuickSearch));
	SetFilter(DCSettings.Filter, "ReportType", ReportTypeFilter, , ValueIsFilled(ReportTypeFilter));
	
	ItemsTree = UnloadDataCompositionResult(TreeSchema, TreeSchemaComposer, , True);
	
	AdditionalAttributes = New Structure("Account, TotalsType, OpeningBalance, UserDefinedFixedIndicator, OutputItemTitle");
	For Each Column In ItemsTree.Columns Do
		For Each Attribute In AdditionalAttributes Do
			If StrFind(Column.Name, Attribute.Key) > 0 Then
				Column.Name = Attribute.Key;
			EndIf;
		EndDo;
	EndDo;
	
	ItemType = PredefinedValue("Enum.FinancialReportItemsTypes.AccountingDataIndicator");
	Filter = New Structure("ItemType", ItemType);
	AccountingDataIndicators = ItemsTree.Rows.FindRows(Filter, True);
	For Each Indicator In AccountingDataIndicators Do
		If TypeOf(Indicator.Account) = Type("ChartOfAccountsRef.FinancialChartOfAccounts") Then
			Indicator.NonstandardPicture = FinancialReportingCached.NonstandardPicture(ItemType, "Fin");
		EndIf;
	EndDo;
	
	GroupTreeByReportsTypes(ItemsTree);
	
	Form.ValueToFormAttribute(ItemsTree, TreeItemName);
	
EndProcedure

Function RefreshReportTree(ReportType, Val ItemsParent = Undefined,
						AttributesCache = Undefined, OutputComplexTableItems = False) Export
	
	TreeSchema = Catalogs.FinancialReportsTypes.GetTemplate("ReportItemsTree");
	If ValueIsFilled(ItemsParent) Then
		Attributes = Common.ObjectAttributesValues(ItemsParent, "ItemType, Parent");
		If Attributes.ItemType = Enums.FinancialReportItemsTypes.GroupTotal Then
			ItemsParent = Attributes.Parent;
			TreeSchema.DataSetLinks.Delete(TreeSchema.DataSetLinks[0]);
			QueryText = TreeSchema.DataSets.ReportItems.Query;
			TreeSchema.DataSets.ReportItems.Query = StrReplace(QueryText, "AND FinancialReportsItems.Parent IN(&Parents)", "");
		EndIf;
	EndIf;
	TreeSchemaComposer = SchemaComposer(TreeSchema);
	SetCompositionParameter(TreeSchemaComposer, "OutputComplexTableItems", OutputComplexTableItems);
	SetCompositionParameter(TreeSchemaComposer, "ReportType", ReportType);
	AttributesCache = AdditionalAttributesCache(ReportType);
	SetCompositionParameter(TreeSchemaComposer, "AttributesCache", AttributesCache);
	
	If ItemsParent <> Undefined Then
		SetFilter(TreeSchemaComposer.Settings.Filter,"ReportItem", ItemsParent, DataCompositionComparisonType.InHierarchy);
	EndIf;
	
	Result = UnloadDataCompositionResult(TreeSchema, TreeSchemaComposer, , True);
	
	Return Result;
	
EndFunction

Procedure RefreshItemRefsTree(Form, Parameters) Export
	
	QuickSearch = Undefined;
	TreeItemName = GetParameter(Parameters, "TreeItemName");
	ReportItem = GetParameter(Parameters, "ReportItem");
	Account = GetParameter(Parameters, "Account");
	
	Query = New Query;
	TempTablesManager = PicturesIndexesTable();
	Query.TempTablesManager = TempTablesManager;
	Query.Text = ItemRefsTreeQueryText();
	IsMngAccount = True;
	If ValueIsFilled(Account) Then
		IsMngAccount = TypeOf(Account) = Type("ChartOfAccountsRef.PrimaryChartOfAccounts");
	EndIf;
	Query.SetParameter("IsMngAccount", IsMngAccount);
	Query.SetParameter("ReportItem", ReportItem);
	Query.SetParameter("Owner", ReportItem.Owner);
	QueryResult = Query.Execute();
	
	ItemsTree = QueryResult.Unload(QueryResultIteration.ByGroupsWithHierarchy);
	
	Parameters.Insert("RefsCount", ItemsTree.Rows.Count());
	
	GroupTreeByReportsTypes(ItemsTree);
	
	Form.ValueToFormAttribute(ItemsTree, TreeItemName);
	
EndProcedure

Function ItemRefsTreeQueryText() Export
	
	QueryText = 
	"SELECT
	|	FinancialReportsItems.Owner AS ReportType,
	|	FinancialReportsItems.Ref AS ReportItem,
	|	FinancialReportsItems.DescriptionForPrinting AS DescriptionForPrinting,
	|	PicturesIndexesTable.PictureIndex + 1 AS NonstandardPicture
	|FROM
	|	Catalog.FinancialReportsItems AS FinancialReportsItems
	|		LEFT JOIN PicturesIndexesTable
	|		ON FinancialReportsItems.ItemType = PicturesIndexesTable.ItemType
	|		AND PicturesIndexesTable.AuxiliaryItemName = """"
	|WHERE
	|	FinancialReportsItems.DeletionMark = FALSE
	|	AND (FinancialReportsItems.LinkedItem = &ReportItem
	|				AND (FinancialReportsItems.Owner <> &Owner OR &Owner = UNDEFINED)
	|	)
	|
	|ORDER BY
	|	DescriptionForPrinting";
	
	Return QueryText;
	
EndFunction

Function AdditionalAttributeValue(Val ObjectRef, Val Attribute, AttributesCache) Export
	
	If TypeOf(Attribute) = Type("String") Then
		Attribute = ChartsOfCharacteristicTypes.FinancialReportsItemsAttributes[Attribute];
	EndIf;
	
	SearchStructure = New Structure;
	If ValueIsFilled(ObjectRef) Then
		SearchStructure.Insert("ReportItem", ObjectRef);
	EndIf;
	SearchStructure.Insert("Attribute", Attribute);
	FoundRows = AttributesCache.FindRows(SearchStructure);
	If FoundRows.Count() Then
		Return FoundRows[0].Value;
	EndIf;
	
	Return Undefined;
	
EndFunction

Function SchemaComposer(Schema, RestoreSettings = True) Export
	
	AvailableSettingsSource = New DataCompositionAvailableSettingsSource(Schema);
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(AvailableSettingsSource);
	Composer.LoadSettings(Schema.DefaultSettings);
	
	If RestoreSettings Then
		Composer.Refresh(DataCompositionSettingsRefreshMethod.Full);
	EndIf;
	
	Return Composer;
	
EndFunction

Function FindFilterItem(Filter, ItemName, FilterValue = "NotSet", ComparisonType = Undefined) Export
	
	Result = Undefined;
	For Each FilterItem In Filter.Items Do
		If TypeOf(FilterItem) = Type("DataCompositionFilterItemGroup") Then
			Result = FindFilterItem(FilterItem, ItemName);
			If Result <> Undefined Then
				Break;
			EndIf;
		ElsIf FilterItem.LeftValue = New DataCompositionField(ItemName) Then
			If FilterValue <> "NotSet" And FilterItem.RightValue = FilterValue Or FilterValue = "NotSet" Then
				If ComparisonType <> Undefined And FilterItem.ComparisonType = ComparisonType Or ComparisonType = Undefined Then
					Result = FilterItem;
					Break;
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	Return Result;
	
EndFunction

Function NewFilter(Filter, LeftValue, RightValue, FilterType = Undefined,
					ComparisonType = Undefined, FieldRightValue = False) Export
	
	If FilterType = Undefined Then
		FilterType = Type("DataCompositionFilterItem");
	EndIf;
	
	NewFilter = Filter.Items.Add(FilterType);
	If LeftValue <> Undefined Then
		If TypeOf(LeftValue) = Type("DataCompositionField") Then
			NewFilter.LeftValue = LeftValue;
		Else
			NewFilter.LeftValue = New DataCompositionField(LeftValue);
		EndIf;
	EndIf;
	
	If RightValue <> Undefined Then
		If FieldRightValue Then
			If TypeOf(RightValue) = Type("DataCompositionField") Then
				NewFilter.RightValue = RightValue;
			Else
				NewFilter.RightValue = New DataCompositionField(RightValue);
			EndIf;
		Else
			NewFilter.RightValue = RightValue;
		EndIf;
	EndIf;
	
	If FilterType = Type("DataCompositionFilterItem") Then
		If ComparisonType = Undefined Then
			NewFilter.ComparisonType = DataCompositionComparisonType.Equal;
			If TypeOf(RightValue) = Type("Array") Or TypeOf(RightValue) = Type("ValueList") Then
				NewFilter.ComparisonType = DataCompositionComparisonType.InList;
			EndIf;
		Else
			NewFilter.ComparisonType = ComparisonType;
		EndIf;
	EndIf;
	
	Return NewFilter;
	
EndFunction

Function NewSetField(DataSet, Field, DataPath = "", Title = "", ValueType = Undefined) Export
	
	If IsBlankString(DataPath) Then
		DataPath = Field;
	EndIf;
	
	If IsBlankString(Title) Then
		Title = Field;
	EndIf;
	
	NewField = DataSet.Fields.Add(Type("DataCompositionSchemaDataSetField"));
	NewField.Field = Field;
	NewField.DataPath = DataPath;
	NewField.Title = Title;
	If ValueType <> Undefined Then
		NewField.ValueType = ValueType;
	EndIf;
	
	Return NewField;
	
EndFunction

Procedure SetCompositionParameter(ComposerSettings, ParameterName, Value = Undefined, Use = True) Export
	
	DCSettings = ComposerSettings;
	If TypeOf(ComposerSettings) = Type("DataCompositionSettingsComposer") Then
		DCSettings = ComposerSettings.Settings;
	EndIf;
	SetParameter(DCSettings.DataParameters, ParameterName, Value, Use);
	
EndProcedure

Procedure SetParameter(Parameters, ParameterName, Value = Undefined, Use = True) Export
	
	Parameter = Parameters.Items.Find(ParameterName);
	If Parameter = Undefined Then
		Return;
	EndIf;
	
	Parameter.Use = Use;
	If Use Then
		Parameter.Value = Value;
	EndIf;
	
EndProcedure

Procedure CopyFilter(FilterSource, FilterRecipient, UsedOnly, ExceptionFields = Undefined,
					Postfix = "", CheckFieldsAvailability = False) Export
	
	CheckFieldsAvailabilityParameters = New Structure;
	CheckFieldsAvailabilityParameters.Insert("CheckFieldsAvailability", CheckFieldsAvailability);
	
	AvailableFilterFields = New ValueTable;
	AvailableFilterFields.Columns.Add("CompositionField");
	AvailableFilterFields.Columns.Add("FieldName");
	If CheckFieldsAvailability Then
		FillAvailableFieldsRecursively(AvailableFilterFields, FilterRecipient.AvailableFilterFields.Items);
	EndIf;
	AvailableFilterFields.Indexes.Add("CompositionField");
	AvailableFilterFields.Indexes.Add("FieldName");
	
	CheckFieldsAvailabilityParameters.Insert("AvailableFilterFields", AvailableFilterFields);
	
	CopyFilterRecursively(FilterSource, FilterRecipient, UsedOnly, ExceptionFields, Postfix, CheckFieldsAvailabilityParameters);
	
EndProcedure

Function DataSetFieldNewRole() Export
	
	NewRole = New Structure;
	NewRole.Insert("AccountTypeExpression",	"");
	NewRole.Insert("BalanceGroup",			"");
	NewRole.Insert("IgnoreNULLValues",		False);
	NewRole.Insert("Dimension",				False);
	NewRole.Insert("PeriodNumber",			0);
	NewRole.Insert("Required",				False);
	NewRole.Insert("Balance",				False);
	NewRole.Insert("AccountField",			"");
	NewRole.Insert("DimensionAttribute",	False);
	NewRole.Insert("ParentDimension",		"");
	NewRole.Insert("Account",				False);
	NewRole.Insert("AccountingBalanceType",	DataCompositionAccountingBalanceType.None);
	NewRole.Insert("BalanceType",			DataCompositionBalanceType.None);
	NewRole.Insert("PeriodType",			DataCompositionPeriodType.Main);
	Return NewRole;
	
EndFunction

Procedure SetDataSetFieldRole(DataSet, DataPath, FieldRole = Undefined) Export
	
	If FieldRole = Undefined Then
		FieldRole = DataSetFieldNewRole();
	EndIf;
	
	SetField = DataSet.Fields.Find(DataPath);
	FillPropertyValues(SetField.Role, FieldRole);
	
EndProcedure

Procedure SetFilter(Filter, LeftValue, RightValue = Undefined, ComparisonType = Undefined, Use = True) Export
	
	FilterItem = FindFilterItem(Filter, LeftValue);
	If FilterItem = Undefined Then
		FilterItem = NewFilter(Filter, LeftValue, RightValue);
	EndIf;
	FilterItem.Use = Use;
	If ComparisonType <> Undefined Then
		FilterItem.ComparisonType = ComparisonType;
	EndIf;
	If Use Then
		FilterItem.RightValue = RightValue;
	EndIf;
	
EndProcedure

Function NewSelectionField(Structure, Field, Title = "") Export
	
	NewSelectionField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	NewSelectionField.Use = True;
	NewSelectionField.Field = New DataCompositionField(Field);
	NewSelectionField.Title = ?(IsBlankString(Title), Field, Title);
	
	Return NewSelectionField;
	
EndFunction

Function TypeDescriptionByValue(Value) Export
	
	TypesArray = New Array;
	TypesArray.Add(TypeOf(Value));
	Return New TypeDescription(TypesArray);
	
EndFunction

Procedure GenerateReportsSet(Parameters, StorageAddress) Export
	
	MainStorageID = Parameters.MainStorageID;
	
	InstancesData = New Map;
	For Each Instance In Parameters.ReportsInstances Do
		
		ReportType = Instance.Key;
		Parameters.Insert("DetailsData", PutToTempStorage(Undefined, MainStorageID));
		Parameters.ReportType = ReportType;
		Parameters.OutputRowCode = ReportType.OutputRowCode;
		Parameters.OutputNote = ReportType.OutputNote;
		
		ReportDataAddress = Instance.Value;
		ReportGenerationResult = GenerateReport(Parameters);
		PutToTempStorage(ReportGenerationResult, ReportDataAddress);
		
		Parameters.ReportResult = ReportGenerationResult.Result;
		
		NewInstance = Documents.FinancialReportInstance.CreateDocument();
		NewInstance.Date = CurrentSessionDate();
		NewInstance.Responsible = Users.CurrentUser();
		NewInstance.Fill(Parameters);
		NewInstance.Currency = DriveServer.GetPresentationCurrency(NewInstance.Company);
		
		NewInstance.Write();
		
		InstancesData.Insert(ReportDataAddress, ReportSettings(Parameters));
		
	EndDo;
	
	BackgroundJobExecutionResult = New Structure;
	BackgroundJobExecutionResult.Insert("Completed", True);
	BackgroundJobExecutionResult.Insert("ReportPeriod", Parameters.ReportPeriod);
	BackgroundJobExecutionResult.Insert("Filter", Parameters.Filter);
	BackgroundJobExecutionResult.Insert("ReportsPack", Parameters.ReportsPack);
	BackgroundJobExecutionResult.Insert("OpenForms", Parameters.OpenForms);
	BackgroundJobExecutionResult.Insert("InstancesData", InstancesData);
	
	PutToTempStorage(BackgroundJobExecutionResult, StorageAddress);
	
EndProcedure

Procedure FillReportCurrency(ResourceItem) Export
	
	MngCurrency = DriveReUse.GetFunctionalCurrency();
	ChoiceList = ResourceItem.ChoiceList;
	ChoiceList.Clear();
	
	ChoiceList.Add(
		"Amount",
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Managerial accounting (%1)'; ru = 'Управленческий учет (%1)';pl = 'Rachunkowość zarządcza (%1)';es_ES = 'Contabilidad administrativa (%1)';es_CO = 'Contabilidad administrativa (%1)';tr = 'Yönetim muhasebesi (%1)';it = 'Contabilità gestionale (%1)';de = 'Betriebsbuchhaltung (%1)'"),
			MngCurrency));
	
EndProcedure

Function ReportPeriod(BeginOfPeriod = Undefined, EndOfPeriod = Undefined) Export
	
	Result = New Structure;
	Result.Insert("BeginOfPeriod", BeginOfPeriod);
	Result.Insert("EndOfPeriod", EndOfPeriod);
	Result.Insert("Periodicity", New Array);
	
	Return Result;
	
EndFunction

Function GenerateReport(Parameters, StorageAddress = Undefined) Export
	
	AttributesCache = Undefined;
	ReportItemsTree = RefreshReportTree(Parameters.ReportType, , AttributesCache, True);
	Parameters.Insert("AttributesCache", AttributesCache);
	Parameters.Insert("MessagesAboutErrors", New Array);
	Parameters.Insert("AdditionalSuffix", "");
	Parameters.Insert("ReportBlocks", New Array);
	Parameters.Insert("ItemsTypes", Enums.FinancialReportItemsTypes.Cache());
	Parameters.Insert("ValuesFormat", "ND=15; NZ=-; NN=0" + ?(Parameters.AmountsInThousands, "; NS=3;", ""));
	Parameters.Insert("MaximumColumnNumber", 0);
	
	ExecutionResult = New Structure;
	If Parameters.Property("IndicatorData") Then
		UserDefinedCalculatedIndicatorDetails(Parameters);
		ExecutionResult.Insert("Result", Parameters.Result);
		If ValueIsFilled(StorageAddress) Then
			PutToTempStorage(ExecutionResult, StorageAddress);
		EndIf;
		Return ExecutionResult;
	Else
		ReportTypeDescription(Parameters, ReportItemsTree);
	EndIf;
	Parameters.Delete("AdditionalSuffix");
	
	Result = OutputReport(Parameters, ReportItemsTree);
	
	ExecutionResult.Insert("MessagesAboutErrors", Parameters.MessagesAboutErrors);
	ExecutionResult.Insert("Result", Result);
	
	If ValueIsFilled(StorageAddress) Then
		PutToTempStorage(ExecutionResult, StorageAddress);
	Else
		Return ExecutionResult;
	EndIf;
	
EndFunction

Function ItemID(Item) Export
	
	If TypeOf(Item) = Type("ValueTreeRow") Then
		ItemTypeString = RefDescription(Item.ItemType) + String(Item.Code);
	ElsIf TypeOf(Item) = Type("CatalogRef.FinancialReportsItems") Then
		Attributes = Common.ObjectAttributesValues(Item, "Code, ItemType");
		ItemTypeString = RefDescription(Attributes.ItemType) + String(Attributes.Code);
	ElsIf TypeOf(Item) = Type("Structure") Then
		ItemTypeString = Item.ID;
	Else
		ItemTypeString = StrReplace(Title(String(Item)), " ", "");
	EndIf;
	
	ItemTypeString = StringFunctionsClientServer.ReplaceCharsWithOther("()/", ItemTypeString, "");
	
	Return ItemTypeString;
	
EndFunction

Procedure QueryResultToTree(QueryResult, Tree) Export
	
	QueryTree = QueryResult.Unload(QueryResultIteration.ByGroupsWithHierarchy);
	FinancialReportingClientServer.AddRowsToTree(QueryTree.Rows, Tree.Rows);
	
EndProcedure

Function GetParameter(Parameters, ParameterName, DefaultValue = Undefined) Export
	
	ParameterValue = DefaultValue;
	If Not Parameters.Property(ParameterName, ParameterValue) Then
		Return DefaultValue;
	EndIf;
	
	Return ParameterValue;
	
EndFunction

Function CalculateLevelDepth(TreeRows, ConsiderAdditionalFields = False, Val Depth = 1, PreviousFlag = False) Export
	
	If Not PreviousFlag Then
		LevelFinalDepth = 1;
	Else
		LevelFinalDepth = Depth;
	EndIf;
	
	Result = LevelFinalDepth;
	ChildItems = FinancialReportingClientServer.ChildItems(TreeRows);
	For Each TreeRow In ChildItems Do
		
		Addition = 0;
		
		If TreeRow.OutputWithParental Then
			Addition = 1;
		EndIf;
		
		If ConsiderAdditionalFields Then
			Addition = Addition + NumberOfAdditionalFieldsForTreeDepthCalculation(TreeRow);
			If TreeRow.OutputWithParental And Not PreviousFlag Then
				// Additional fields of the first united item are not added to the column total
				Addition = Addition + NumberOfAdditionalFieldsForTreeDepthCalculation(TreeRow.Parent);
			EndIf;
		EndIf;
		
		CurrentLevelDepth = LevelFinalDepth + Addition;
		
		Result = Max(Result, CurrentLevelDepth);
		Result = Max(Result, CalculateLevelDepth(TreeRow, ConsiderAdditionalFields, CurrentLevelDepth, TreeRow.OutputWithParental));
		
	EndDo;
	
	Return Result;
	
EndFunction

Function NumberOfAdditionalFieldsForTreeDepthCalculation(TreeRow) Export
	
	If TreeRow.ItemType = Enums.FinancialReportItemsTypes.Dimension Then
		AdditionalFields = TreeRow.AdditionalFields;
		If AdditionalFields.Count() Then
			Return AdditionalFields.FindRows(New Structure("InSeparateColumn", True)).Count();
		EndIf;
	EndIf;
	
	Return 0;
	
EndFunction

Function ItemValuesSources(Cache, TreeRow, Filling = False, WithoutDerivatives = False) Export
	
	SourcesTable = New ValueTable;
	SourcesTable.Columns.Add("ItemType");
	SourcesTable.Columns.Add("Item");
	SourcesTable.Columns.Add("Parent");
	SourcesTable.Columns.Add("Description");
	
	ComplexTable = False;
	ChildItemsSources = Undefined;
	
	Table = FinancialReportingClientServer.RootItem(TreeRow, Enums.FinancialReportItemsTypes.TableComplex);
	If Table <> Undefined Then
		ComplexTable = True;
	EndIf;
	
	IsRows = FinancialReportingClientServer.RootItem(TreeRow, Enums.FinancialReportItemsTypes.Columns) = Undefined;
	
	ValuesItemsTypes = New Array;
	If Not Filling And Not WithoutDerivatives Then
		ValuesItemsTypes.Add(Enums.FinancialReportItemsTypes.UserDefinedCalculatedIndicator);
	EndIf;
	
	If Not ComplexTable Then
		
		// 1. Parent items
		Parent = TreeRow;
		While Parent <> Undefined Do
			If ValuesItemsTypes.Find(Parent.ItemType) <> Undefined Then
				NewRow = SourcesTable.Add();
				NewRow.Item = ?(ValueIsFilled(Parent.ItemStructureAddress), Parent.ItemStructureAddress, Parent.ReportItem);
				NewRow.ItemType = Parent.ItemType;
				NewRow.Description = Parent.DescriptionForPrinting;
			EndIf;
			Parent = FinancialReportingClientServer.ParentItem(Parent);
		EndDo;
		
		// 2. Child items
		SimpleTableItemChildValuesSources(
			FinancialReportingClientServer.ChildItems(TreeRow),
			SourcesTable,
			ValuesItemsTypes);
		
		// 3. Transposed items
		ChildItemsSources = Undefined;
		
		Table = FinancialReportingClientServer.RootItem(TreeRow, Enums.FinancialReportItemsTypes.TableIndicatorsInRows);
		If Table = Undefined Then
			Table = FinancialReportingClientServer.RootItem(TreeRow, Enums.FinancialReportItemsTypes.TableIndicatorsInColumns);
		EndIf;
		
		If Table <> Undefined Then //Dimensions can be selected without table
			
			If IsRows Then
				ChildItemsSources = FinancialReportingClientServer.ChildItem(
					Table,
					"ItemType",
					Enums.FinancialReportItemsTypes.Columns);
			Else
				ChildItemsSources = FinancialReportingClientServer.ChildItem(
					Table,
					"ItemType",
					Enums.FinancialReportItemsTypes.Rows);
			EndIf;
		
			SimpleTableItemChildValuesSources(
				FinancialReportingClientServer.ChildItems(ChildItemsSources),
				SourcesTable,
				ValuesItemsTypes);
		EndIf;
		
	Else
		
		// 1. Items table
		
		ConfigureCells = FinancialReportingClientServer.ChildItem(
			Table,
			"ItemType",
			Enums.FinancialReportItemsTypes.ConfigureCells);
		If ValueIsFilled(ConfigureCells.ItemStructureAddress) Then
			ItemsTable = GetFromTempStorage(ConfigureCells.ItemStructureAddress).TableItems;
		ElsIf Not ValueIsFilled(ConfigureCells.ReportItem) Then
			ConfigureCells.ItemStructureAddress = FinancialReportingClientServer.PutItemToTempStorage(
				ConfigureCells,
				New UUID);
			ItemsTable = GetFromTempStorage(ConfigureCells.ItemStructureAddress).TableItems;
		Else
			ItemsTable = Catalogs.FinancialReportsItems.ItemFieldValueFromCache(
				ConfigureCells.ReportItem,
				"TableItems",
				Cache);
		EndIf;
		
		SearchByAddress = ValueIsFilled(ConfigureCells.ItemStructureAddress);
		
		// 2. Linked items
		
		AllTreeBranch = New Array;
		AllTreeBranch.Add(TreeRow);
		ComplexTableItemChildValuesSources(TreeRow.Rows, AllTreeBranch);
		
		For Each ProcessedRow In AllTreeBranch Do
			
			SearchItem = ?(SearchByAddress, ProcessedRow.ItemStructureAddress, ProcessedRow.ReportItem);
			SearchStructure = New Structure(?(IsRows, "Row", "Column"), SearchItem);
			
			If ValueIsFilled(SearchItem) Then
				ObjectAttributes = ObjectAttributesByRefOrAddress(SearchItem, "DescriptionForPrinting", Cache);
				SearchItemDescription = ObjectAttributes.DescriptionForPrinting;
			Else
				SearchItemDescription = "";
			EndIf;
			
			FoundRows = ItemsTable.FindRows(SearchStructure);
			For Each FoundRow In FoundRows Do
				
				Item = FoundRow.Item;
				
				ObjectAttributes = ObjectAttributesByRefOrAddress(Item, "ItemType, DescriptionForPrinting", Cache);
				
				If ValuesItemsTypes.Find(ObjectAttributes.ItemType) = Undefined Then
					Continue;
				EndIf;
				
				Parent = ?(IsRows, FoundRow.Column, FoundRow.Row);
				ItemsListFoundRow = SourcesTable.Find(Parent, "Item");
				If ItemsListFoundRow = Undefined Then
					ItemsListFoundRow = SourcesTable.Add();
					ItemsListFoundRow.Item = Parent;
					ParentAttributes = ObjectAttributesByRefOrAddress(Parent, "ItemType, DescriptionForPrinting", Cache);
					ItemsListFoundRow.ItemType = ParentAttributes.ItemType;
					ItemsListFoundRow.Description = ParentAttributes.DescriptionForPrinting;
				EndIf;
				NewRow = SourcesTable.Add();
				NewRow.ItemType = ObjectAttributes.ItemType;
				NewRow.Item = Item;
				NewRow.Parent = Parent;
				NewRow.Description = ObjectAttributes.DescriptionForPrinting + " (" + SearchItemDescription + ")";
				
			EndDo;
		
		EndDo;
		
	EndIf;
	
	Result = SourcesTable.CopyColumns();
	SupplimentSourcesWithOperandsRecursively(SourcesTable, ValuesItemsTypes, ItemsTable, Result, Cache, Filling);
	
	Return Result;
	
EndFunction

Function DefaultValuesSources(Cache, TreeRowReportItemsAddress, ItemAddressInTempStorage = Undefined,
							Filling = False, WithoutDerivatives = False) Export
	
	If TypeOf(TreeRowReportItemsAddress) = Type("ValueTreeRow") Then
		TreeRow = TreeRowReportItemsAddress;
	Else
		ItemsTree = GetFromTempStorage(TreeRowReportItemsAddress);
		TreeRow = FinancialReportingClientServer.ChildItem(ItemsTree, "ItemStructureAddress", ItemAddressInTempStorage);
	EndIf;
	
	SourcesTable = ItemValuesSources(Cache, TreeRow, Filling, WithoutDerivatives);
	
	CalculatedValuesSources = ItemValuesItemsAndIndicators(SourcesTable, True);
	
	Return CalculatedValuesSources;
	
EndFunction

Function TreeDepth(Rows, Val Depth = 0, TotalDepth = 0) Export
	
	If Rows.Count() Then
		TotalDepth = Max(TotalDepth, Depth);
	EndIf;
	
	For Each IndicatorRow In Rows Do
		
		TreeDepth(IndicatorRow.Rows, Depth + 1, TotalDepth);
		
	EndDo;
	
	Return TotalDepth
	
EndFunction

Procedure GetCustomizableFilterItems(Filter, List, Name) Export
	
	For Each FilterItem In Filter.Items Do
		
		If TypeOf(FilterItem) = Type("DataCompositionFilterItemGroup") Then
			
			GetCustomizableFilterItems(FilterItem, List, Name);
			Continue;
			
		EndIf;
		
		If StrFind(FilterItem.RightValue, "<fill")
			And StrFind(Lower(FilterItem.LeftValue), Name) Then
			
			List.Add(FilterItem);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function IntervalPresentation(PeriodDate, Val Periodicity) Export
	
	If TypeOf(PeriodDate) <> Type("Date") Then
		Return PeriodDate;
	EndIf;
	
	If Periodicity = 6 Then
		Periodicity = Enums.Periodicity.Day;
	ElsIf Periodicity = 7 Then
		Periodicity = Enums.Periodicity.Week;
	ElsIf Periodicity = 8 Then
		Periodicity = Enums.Periodicity.TenDays;
	ElsIf Periodicity = 9 Then
		Periodicity = Enums.Periodicity.Month;
	ElsIf Periodicity = 10 Then
		Periodicity = Enums.Periodicity.Quarter;
	ElsIf Periodicity = 11 Then
		Periodicity = Enums.Periodicity.HalfYear;
	ElsIf Periodicity = 12 Then
		Periodicity = Enums.Periodicity.Year;
	EndIf;
	
	StartDate = BeginOfPeriod(PeriodDate, Periodicity);
	EndDate = EndOfPeriod(PeriodDate, Periodicity);
	If Periodicity = Enums.Periodicity.HalfYear And Month(StartDate) = 7 Then
		Return "2 " + NStr("en = 'half-year'; ru = 'полугодие';pl = 'półrocze';es_ES = 'medio año';es_CO = 'medio año';tr = 'yarıyıl';it = 'semestre';de = 'Halbjahr'") + " " + Format(Year(StartDate), "NG=0");
	EndIf;
	
	Return PeriodPresentation(StartDate, EndDate, "FP=True");
	
EndFunction

Function BeginOfPeriod(Val PeriodDate, Periodicity) Export
	
	BeginOfPeriod = PeriodDate;
	If Periodicity = Enums.Periodicity.Day Then
		
		BeginOfPeriod = BegOfDay(PeriodDate);
		
	ElsIf Periodicity = Enums.Periodicity.Week Then
		
		BeginOfPeriod = BegOfWeek(PeriodDate);
		
	ElsIf Periodicity = Enums.Periodicity.TenDays Then
		
		If Day(PeriodDate) <= 10 Then
			BeginOfPeriod = Date(Year(PeriodDate), Month(PeriodDate), 1);
		ElsIf Day(PeriodDate) <= 20 Then
			BeginOfPeriod = Date(Year(PeriodDate), Month(PeriodDate), 11);
		Else
			BeginOfPeriod = Date(Year(PeriodDate), Month(PeriodDate), 21);
		EndIf;
		
	ElsIf Periodicity = Enums.Periodicity.Month Then
		
		BeginOfPeriod = BegOfMonth(PeriodDate);
		
	ElsIf Periodicity = Enums.Periodicity.Quarter Then
		
		BeginOfPeriod = BegOfQuarter(PeriodDate);
		
	ElsIf Periodicity = Enums.Periodicity.HalfYear Then
		
		If Month(BeginOfPeriod) <= 6 Then
			BeginOfPeriod = Date(Year(PeriodDate), 1, 1);
		Else
			BeginOfPeriod = Date(Year(PeriodDate), 7, 1);
		EndIf;
		
	ElsIf Periodicity = Enums.Periodicity.Year Then
		
		BeginOfPeriod = BegOfYear(PeriodDate);
		
	EndIf;
	
	Return BeginOfPeriod;
	
EndFunction

Function EndOfPeriod(Val PeriodDate, Periodicity) Export
	
	EndOfPeriod = PeriodDate;
	If Periodicity = Enums.Periodicity.Day Then
		
		EndOfPeriod = EndOfDay(PeriodDate);
		
	ElsIf Periodicity = Enums.Periodicity.Week Then
		
		EndOfPeriod = EndOfWeek(PeriodDate);
		
	ElsIf Periodicity = Enums.Periodicity.TenDays Then
		
		If Day(PeriodDate) <= 10 Then
			EndOfPeriod = EndOfDay(Date(Year(PeriodDate), Month(PeriodDate), 10));
		ElsIf Day(PeriodDate) <= 20 Then
			EndOfPeriod = EndOfDay(Date(Year(PeriodDate), Month(PeriodDate), 20));
		Else
			EndOfPeriod = EndOfMonth(PeriodDate);
		EndIf;
		
	ElsIf Periodicity = Enums.Periodicity.Month Then
		
		EndOfPeriod = EndOfMonth(PeriodDate);
		
	ElsIf Periodicity = Enums.Periodicity.Quarter Then
		
		EndOfPeriod = EndOfQuarter(PeriodDate);
		
	ElsIf Periodicity = Enums.Periodicity.HalfYear Then
		
		If Month(EndOfPeriod) <= 6 Then
			EndOfPeriod = Date(Year(PeriodDate), 6, 30, 23, 59, 59);
		Else
			EndOfPeriod = Date(Year(PeriodDate), 12, 31, 23, 59, 59);
		EndIf;
		
	ElsIf Periodicity = Enums.Periodicity.Year Then
		
		EndOfPeriod = EndOfYear(PeriodDate);
		
	EndIf;
	
	Return EndOfPeriod;
	
EndFunction

Function EmptySchema(SourceName = "DataSource1", SourceType = "Local") Export
	
	NewSchema = New DataCompositionSchema;
	
	DataSource = NewSchema.DataSources.Add();
	DataSource.Name = SourceName;
	DataSource.DataSourceType = SourceType;
	
	Return NewSchema;
	
EndFunction

Function AddEmptyDataSet(SchemaSet) Export
	
	DataSetType = Type("DataCompositionSchemaDataSetQuery");
	DataSetName = "DataSet1";
	SourceName = "DataSource1";
	ObjectName = "";
	
	If SchemaSet = Undefined Then
		SchemaSet = EmptySchema();
	EndIf;
	
	If TypeOf(SchemaSet) = Type("DataCompositionSchema") Then
		
		DataSets = SchemaSet.DataSets;
		
	ElsIf TypeOf(SchemaSet) = Type("DataCompositionSchemaDataSets") Then
		
		DataSets = SchemaSet;
		
	ElsIf TypeOf(SchemaSet) = Type("DataCompositionSchemaDataSetUnion") Then
		
		DataSets = SchemaSet.Items;
		
	EndIf;
	
	NewSet = DataSets.Add(DataSetType);
	
	NewSet.Name = DataSetName;
	If Not DataSetType = Type("DataCompositionSchemaDataSetUnion")
		And ValueIsFilled(SourceName) Then
		
		NewSet.DataSource = SourceName;
		
	EndIf;
	
	If DataSetType = Type("DataCompositionSchemaDataSetObject") Then
		NewSet.ObjectName = ?(ValueIsFilled(ObjectName), ObjectName, DataSetName);
	EndIf;
		
	Return NewSet;
	
EndFunction

Function UnloadDataCompositionResult(DataCompositionSchema, ComposerSettings, ExternalDataSets = Undefined,
										OutputToTree = False) Export
	
	CompositionTemplate = PrepareDataCompositionTemplateForUnloading(DataCompositionSchema, ComposerSettings);
	Return UnloadDataCompositionTemplateResult(CompositionTemplate, ExternalDataSets, OutputToTree);
	
EndFunction

Function CalculateSpreadsheetDocumentSelectedCellsTotalAmount(Val Result, SelectedAreaCache) Export
	
	Amount = 0;
	For Each KeyValue In SelectedAreaCache Do
		SelectedAreaAddressStructure = KeyValue.Value;
		For IndexRow = SelectedAreaAddressStructure.Top To SelectedAreaAddressStructure.Bottom Do
			For IndexColumn = SelectedAreaAddressStructure.Left To SelectedAreaAddressStructure.Right Do
				Try
					Cell = Result.Area(IndexRow, IndexColumn, IndexRow, IndexColumn);
					If Cell.Visible = True Then
						If Cell.ContainsValue And TypeOf(Cell.Value) = Type("Number") Then
							Amount = Amount + Cell.Value;
						ElsIf ValueIsFilled(Cell.Text) Then
							AmountInCell = Number(StringFunctionsClientServer.ReplaceCharsWithOther(
								Char(32) + Char(43), Cell.Text, Char(0)));
							Amount = Amount + AmountInCell;
						EndIf;
					EndIf;
				Except
					// No event log record is required
				EndTry;
			EndDo;
		EndDo;
	EndDo;
	
	SelectedAreaCache.Insert("Amount", Amount);
	
	Return Amount;
	
EndFunction

#Region WorkWtihFormulas

Function GetOperandsEmptyTree() Export
	
	Tree = New ValueTree;
	Tree.Columns.Add("Description");
	Tree.Columns.Add("Operator");
	Tree.Columns.Add("Indent", New TypeDescription("Number"));
	
	Return Tree;
	
EndFunction

Function AddOperatorsGroup(Tree, Description) Export
	
	NewGroup = Tree.Rows.Add();
	NewGroup.Description = Description;
	
	Return NewGroup;
	
EndFunction

Function AddOperator(Tree, Parent, Description, Operator, Indent = 0) Export
	
	NewRow = ?(Parent <> Undefined, Parent.Rows.Add(), Tree.Rows.Add());
	NewRow.Description = Description;
	NewRow.Operator = ?(ValueIsFilled(Operator), Operator, Description);
	NewRow.Indent = Indent;
	
	Return NewRow;
	
EndFunction

#EndRegion

#EndRegion

#Region Private

Procedure AddPicturesIndexesTableRow(PicturesTable, ItemType, AuxiliaryDataName, PictureIndex)
	
	NewRow = PicturesTable.Add();
	If Not IsBlankString(ItemType) Then
		NewRow.ItemType = Enums.FinancialReportItemsTypes[ItemType];
	EndIf;
	NewRow.AuxiliaryItemName = AuxiliaryDataName;
	NewRow.PictureIndex = PictureIndex;
	
EndProcedure

Function AvailableExistingReportItems(TreeMode)
	
	List = New ValueList;
	List.Add(Enums.FinancialReportItemsTypes.AccountingDataIndicator);
	List.Add(Enums.FinancialReportItemsTypes.UserDefinedFixedIndicator);
	List.Add(Enums.FinancialReportItemsTypes.UserDefinedCalculatedIndicator);
	
	If TreeMode = Enums.NewItemsTreeDisplayModes.ReportTypeSetting Then
		List.Add(Enums.FinancialReportItemsTypes.ReportTitle);
		List.Add(Enums.FinancialReportItemsTypes.NonEditableText);
		List.Add(Enums.FinancialReportItemsTypes.EditableText);
		List.Add(Enums.FinancialReportItemsTypes.UserDefinedCalculatedIndicator);
		List.Add(Enums.FinancialReportItemsTypes.TableIndicatorsInRows);
		List.Add(Enums.FinancialReportItemsTypes.TableIndicatorsInColumns);
		List.Add(Enums.FinancialReportItemsTypes.TableComplex);
		List.Add(Enums.FinancialReportItemsTypes.Group);
		List.Add(Enums.FinancialReportItemsTypes.GroupTotal);
	EndIf;
	
	Return List;
	
EndFunction

Procedure GroupTreeByReportsTypes(Tree)
	
	TreeByReportsTypes = Tree.Copy();
	TreeByReportsTypes.Rows.Clear();
	
	TreeRows = Tree.Rows;
	TreeRows.Sort("ReportType");
	TreeByReportsTypesRows = TreeByReportsTypes.Rows;
	GroupingRow = Undefined;
	For Each TreeRow In TreeRows Do 
		
		If GroupingRow = Undefined Or GroupingRow.ReportType <> TreeRow.ReportType Then
			GroupingRow = TreeByReportsTypesRows.Add();
			GroupingRow.DescriptionForPrinting = TreeRow.ReportType;
			GroupingRow.ReportType = TreeRow.ReportType;
			GroupingRow.NonstandardPicture = 43;
		EndIf;

		FinancialReportingClientServer.SetNewParent(TreeRow, GroupingRow, True, True);
		
	EndDo;
	
	Tree = TreeByReportsTypes;
	
EndProcedure

Function QueryTextNewReportItems(QuickSearch)
	
	QueryText = "
	|////////////////////////////////////////////////////////////////////////////////
	|// 1. BASIC STRUCTURE
	|"
	+
	"SELECT
	|	ReportItemsTypes.Ref AS ItemType,
	|	PicturesIndexesTable.PictureIndex AS NonstandardPicture,
	|	PRESENTATION(ReportItemsTypes.Ref) AS Description,
	|	PRESENTATION(ReportItemsTypes.Ref) AS DescriptionForPrinting
	|FROM
	|	Enum.FinancialReportItemsTypes AS ReportItemsTypes
	|		LEFT JOIN PicturesIndexesTable
	|		ON ReportItemsTypes.Ref = PicturesIndexesTable.ItemType
	|		AND PicturesIndexesTable.AuxiliaryItemName = """"
	|WHERE
	|	ReportItemsTypes.Ref IN (&AvailableItemsTypes)
	|
	|ORDER BY
	|	ReportItemsTypes.Order"
	+"
	|;";
	
	QueryText = QueryText + "
	|////////////////////////////////////////////////////////////////////////////////
	|// 2.1.1 BASIC MANAGERIAL ACCOUNTING DATA INDICATORS
	|"
	+
	"SELECT
	|	VALUE(Enum.FinancialReportItemsTypes.AccountingDataIndicator) AS ItemType,
	|	PicturesIndexesTable.PictureIndex AS NonstandardPicture,
	|	FinancialReportsItems.Ref AS ReportItem,
	|	FinancialReportsItems.Code AS AccountCode,
	|	FinancialReportsItems.Order AS Code,
	|	FinancialReportsItems.Description AS Description,
	|	FinancialReportsItems.Description AS DescriptionForPrinting
	|FROM
	|	ChartOfAccounts.PrimaryChartOfAccounts AS FinancialReportsItems
	|		LEFT JOIN PicturesIndexesTable AS PicturesIndexesTable
	|		ON (PicturesIndexesTable.ItemType = VALUE(Enum.FinancialReportItemsTypes.AccountingDataIndicator))
	|			AND (PicturesIndexesTable.AuxiliaryItemName = """")
	|WHERE
	|	FinancialReportsItems.DeletionMark = FALSE"
	+ ?(ValueIsFilled(QuickSearch), "	AND (FinancialReportsItems.Description LIKE ""%" + TrimAll(QuickSearch) + "%""
							|		OR FinancialReportsItems.Code LIKE ""%" + TrimAll(QuickSearch) + "%"")", "") + 
	"
	|ORDER BY 
	|	Code HIERARCHY"
	+"
	|;";
	
	QueryText = QueryText + "
	|////////////////////////////////////////////////////////////////////////////////
	|// 2.1.2 BASIC FINANCIAL ACCOUNTING DATA INDICATORS
	|"
	+
	"SELECT
	|	VALUE(Enum.FinancialReportItemsTypes.AccountingDataIndicator) AS ItemType,
	|	PicturesIndexesTable.PictureIndex AS NonstandardPicture,
	|	FinancialReportsItems.Ref AS ReportItem,
	|	FinancialReportsItems.Code AS AccountCode,
	|	FinancialReportsItems.Order AS Code,
	|	FinancialReportsItems.Description AS Description,
	|	FinancialReportsItems.Description AS DescriptionForPrinting
	|FROM
	|	ChartOfAccounts.FinancialChartOfAccounts AS FinancialReportsItems
	|		LEFT JOIN PicturesIndexesTable AS PicturesIndexesTable
	|		ON (PicturesIndexesTable.ItemType = VALUE(Enum.FinancialReportItemsTypes.AccountingDataIndicator))
	|			AND (PicturesIndexesTable.AuxiliaryItemName = ""Fin"")
	|WHERE
	|	FinancialReportsItems.DeletionMark = FALSE"
	+ ?(ValueIsFilled(QuickSearch), "	AND (FinancialReportsItems.Description LIKE ""%" + TrimAll(QuickSearch) + "%""
										|		OR FinancialReportsItems.Code LIKE ""%" + TrimAll(QuickSearch) + "%"")", "") + 
	"
	|ORDER BY 
	|	Code HIERARCHY
	|;";
	
	QueryText = QueryText + "
	|////////////////////////////////////////////////////////////////////////////////
	|// 2.2. USER-DEFINED FIXED INDICATORS
	|"
	+
	"SELECT
	|	VALUE(Enum.FinancialReportItemsTypes.UserDefinedFixedIndicator) AS ItemType,
	|	PicturesIndexesTable.PictureIndex AS NonstandardPicture,
	|	UserDefinedFinancialReportIndicators.Ref AS ReportItem,
	|	UserDefinedFinancialReportIndicators.Code AS Code,
	|	UserDefinedFinancialReportIndicators.Description AS Description,
	|	UserDefinedFinancialReportIndicators.DescriptionForPrinting AS DescriptionForPrinting,
	|	UserDefinedFinancialReportIndicators.IsFolder AS IsFolder
	|FROM
	|	Catalog.UserDefinedFinancialReportIndicators AS UserDefinedFinancialReportIndicators
	|		LEFT JOIN PicturesIndexesTable AS PicturesIndexesTable
	|		ON (CASE
	|				WHEN UserDefinedFinancialReportIndicators.IsFolder
	|					THEN PicturesIndexesTable.AuxiliaryItemName = ""Group""
	|				ELSE PicturesIndexesTable.ItemType = VALUE(Enum.FinancialReportItemsTypes.UserDefinedFixedIndicator)
	|						AND PicturesIndexesTable.AuxiliaryItemName = """"
	|			END)
	|WHERE
	|	UserDefinedFinancialReportIndicators.DeletionMark = FALSE
	|	AND UserDefinedFinancialReportIndicators.Predefined = FALSE
	|"
	+ ?(ValueIsFilled(QuickSearch), "	AND UserDefinedFinancialReportIndicators.DescriptionForPrinting LIKE ""%" + TrimAll(QuickSearch) + "%""", "") + 
	"
	|ORDER BY
	|	IsFolder HIERARCHY,
	|	Description
	|;";
	
	Return QueryText;
	
EndFunction

Function AvailableNewReportItems(TreeMode = Undefined)
	
	List = New ValueList;
	List.Add(Enums.FinancialReportItemsTypes.AccountingDataIndicator);
	List.Add(Enums.FinancialReportItemsTypes.UserDefinedFixedIndicator);
	If TreeMode = Enums.NewItemsTreeDisplayModes.ReportTypeSettingIndicatorsOnly Then
		List.Add(Enums.FinancialReportItemsTypes.UserDefinedCalculatedIndicator);
	EndIf;
	
	If TreeMode = Enums.NewItemsTreeDisplayModes.ReportTypeSetting Then
		List.Add(Enums.FinancialReportItemsTypes.ReportTitle);
		List.Add(Enums.FinancialReportItemsTypes.NonEditableText);
		List.Add(Enums.FinancialReportItemsTypes.EditableText);
		List.Add(Enums.FinancialReportItemsTypes.UserDefinedCalculatedIndicator);
		List.Add(Enums.FinancialReportItemsTypes.TableComplex);
		List.Add(Enums.FinancialReportItemsTypes.Dimension);
		List.Add(Enums.FinancialReportItemsTypes.Group);
		List.Add(Enums.FinancialReportItemsTypes.GroupTotal);
	EndIf;
	
	Return List;
	
EndFunction

Procedure AddAccountingDataIndicators(ItemsTree, QueryResult, Account, DescriptionForPrinting, AddRow = False)
	
	ItemType = PredefinedValue("Enum.FinancialReportItemsTypes.AccountingDataIndicator");
	// Adding balance accounting data indicators
	If Not QueryResult.IsEmpty() Then
		IndicatorsRow = ItemsTree.Rows.Find(ItemType);
		If AddRow Then
			IndicatorsRow.Description = IndicatorsRow.DescriptionForPrinting;
			Index = ItemsTree.Rows.IndexOf(IndicatorsRow);
			IndicatorsRow = ItemsTree.Rows.Insert(Index + 1);
			IndicatorsRow.ItemType = ItemType;
			IndicatorsRow.Description = DescriptionForPrinting;
			IndicatorsRow.IsFolder = True;
		EndIf;
		IndicatorsRow.ReportItem = Account;
		IndicatorsRow.NonstandardPicture = ?(TypeOf(Account) = Type("ChartOfAccountsRef.PrimaryChartOfAccounts"), 9, 39);
		IndicatorsRow.DescriptionForPrinting = DescriptionForPrinting;
		IndicatorsRow.IsFolder = True;
		QueryResultToTree(QueryResult, IndicatorsRow);
	EndIf;
	
EndProcedure

Procedure AddDimensionsToNewItemsTree(ItemsTree, QuickSearch)

	DimensionRow = ItemsTree.Rows.Find(Enums.FinancialReportItemsTypes.Dimension);
	DimensionRow.ItemType = Undefined; // dimension grouping item cannot be moved to report items
	
	PeriodRow = AddDimensionRow(DimensionRow, NStr("en = 'Period'; ru = 'Период';pl = 'Okres';es_ES = 'Período';es_CO = 'Período';tr = 'Dönem';it = 'Periodo';de = 'Zeitraum'"), "Period");
	PeriodRow.ItemType = Undefined; // dimension grouping item
	PeriodRow.IsFolder = True;		//cannot be moved to budget items
	PeriodRow.NonstandardPicture = FinancialReportingServerCall.NonstandardPicture(Undefined, "Group");
	
	AddDimensionRow(PeriodRow, NStr("en = 'Year'; ru = 'Год';pl = 'Rok';es_ES = 'Año';es_CO = 'Año';tr = 'Yıl';it = 'Anno';de = 'Jahr'")     , PredefinedValue("Enum.Periodicity.Year"));
	AddDimensionRow(PeriodRow, NStr("en = 'Half-year'; ru = 'Полугодие';pl = 'Półrocze';es_ES = 'Medio año';es_CO = 'Medio año';tr = 'Yarıyıl';it = 'Semestre';de = 'Halbjahr'"), PredefinedValue("Enum.Periodicity.HalfYear"));
	AddDimensionRow(PeriodRow, NStr("en = 'Quarter'; ru = 'Квартал';pl = 'Kwartał';es_ES = 'Trimestre';es_CO = 'Trimestre';tr = 'Çeyrek yıl';it = 'Trimestre';de = 'Quartal'")  , PredefinedValue("Enum.Periodicity.Quarter"));
	AddDimensionRow(PeriodRow, NStr("en = 'Month'; ru = 'Месяц';pl = 'Miesiąc';es_ES = 'Mes';es_CO = 'Mes';tr = 'Ay';it = 'Mese';de = 'Monat'")    , PredefinedValue("Enum.Periodicity.Month"));
	
	TitleMng = NStr("en = 'Managerial analytical dimension types'; ru = 'Типы аналитических управленческих измерений';pl = 'Typy zarządczych wymiarów analitycznych';es_ES = 'Tipos de dimensión analítica administrativa';es_CO = 'Tipos de dimensión analítica administrativa';tr = 'İdari analitik boyut türleri';it = 'Tipi dimensione analitica manageriale';de = 'Betriebswirtschaftliche analytische Dimensionstypen'");
	TitleFin = NStr("en = 'Financial analytical dimension types'; ru = 'Типы аналитических финансовых измерений';pl = 'Typy finansowych wymiarów analitycznych';es_ES = 'Tipos de dimensión analítica financiera';es_CO = 'Tipos de dimensión analítica financiera';tr = 'Mali analitik boyut türleri';it = 'Tipi dimensione analitica finanziaria';de = 'Finanzanalytische Dimensionstypen'");
	AddAnalyticalDimensionTypes(DimensionRow, TitleMng, QuickSearch);
	AddAnalyticalDimensionTypes(DimensionRow, TitleFin, QuickSearch, "FinancialAnalyticalDimensionTypes");
	
	AddDimensionRow(DimensionRow, NStr("en = 'Company'; ru = 'Организация';pl = 'Firma';es_ES = 'Empresa';es_CO = 'Empresa';tr = 'İş yeri';it = 'Azienda';de = 'Firma'"), "Company");
	
	If Catalogs.BusinessUnits.AccountingByBusinessUnits() Then
		AddDimensionRow(DimensionRow, NStr("en = 'Business unit'; ru = 'Подразделение';pl = 'Jednostka biznesowa';es_ES = 'Unidad empresarial';es_CO = 'Unidad de negocio';tr = 'Departman';it = 'Business unit';de = 'Abteilung'"), "BusinessUnit");
	EndIf;
	
	If Catalogs.LinesOfBusiness.AccountingByLinesOfBusiness() Then
		AddDimensionRow(DimensionRow, NStr("en = 'Line of business'; ru = 'Направление деятельности';pl = 'Rodzaj działalności';es_ES = 'Dirección de negocio';es_CO = 'Dirección de negocio';tr = 'İş kolu';it = 'Linea di business';de = 'Geschäftsbereich'"), "LineOfBusiness");
	EndIf;
	
EndProcedure

Function AddDimensionRow(RecipientRow, Description, ReportItem = Undefined, DescriptionForPrinting = "")
	
	NewRow = RecipientRow.Rows.Add();
	Dimension = PredefinedValue("Enum.FinancialReportItemsTypes.Dimension");
	NewRow.ItemType = Dimension;
	NewRow.NonstandardPicture = FinancialReportingCached.NonstandardPicture(Dimension);
	NewRow.Description = Description;
	NewRow.DescriptionForPrinting = Description;
	If Not IsBlankString(DescriptionForPrinting) Then
		NewRow.DescriptionForPrinting = DescriptionForPrinting;
	EndIf;
	NewRow.ReportItem = ReportItem;
	
	Return NewRow;
	
EndFunction

Procedure AddAnalyticalDimensionTypes(DimensionRow, GroupName, QuickSearch, TableName = "")
	
	Query = New Query;
	QueryText = 
	"SELECT
	|	AnalyticalDimensions.Ref,
	|	AnalyticalDimensions.Description AS Description
	|FROM
	|	ChartOfCharacteristicTypes.ManagerialAnalyticalDimensionTypes AS AnalyticalDimensions
	|WHERE
	|	NOT AnalyticalDimensions.DeletionMark
	|"+ ?(ValueIsFilled(QuickSearch),
			"	AND AnalyticalDimensions.Description LIKE ""%" + TrimAll(QuickSearch) + "%""", "") 
	+"
	|ORDER BY
	|	Description";
	
	If Not IsBlankString(TableName) Then
		QueryText = StrReplace(QueryText, "ManagerialAnalyticalDimensionTypes", TableName);
	EndIf;
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		AnalyticalDimensionRow = AddDimensionRow(DimensionRow, GroupName);
		AnalyticalDimensionRow.ItemType = Undefined;	//dimension grouping item
		AnalyticalDimensionRow.IsFolder = True; 		//cannot be moved to report items
		AnalyticalDimensionRow.NonstandardPicture = FinancialReportingServerCall.NonstandardPicture(Undefined, "Group");
		
		Selection = QueryResult.Select();
		While Selection.Next() Do
			AddDimensionRow(AnalyticalDimensionRow, Selection.Description, Selection.Ref);
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure SimpleTableItemChildValuesSources(ChildItems, ItemsList, ValuesItemsTypes)
	
	For Each TreeRow In ChildItems Do
		
		If ValuesItemsTypes <> Undefined
			And ValuesItemsTypes.Find(TreeRow.ItemType) <> Undefined Then
			
			NewRow = ItemsList.Add();
			NewRow.Item = ?(ValueIsFilled(TreeRow.ItemStructureAddress), TreeRow.ItemStructureAddress, TreeRow.ReportItem);
			NewRow.ItemType = TreeRow.ItemType;
			NewRow.Description = TreeRow.DescriptionForPrinting;
			
		EndIf;
		
		SimpleTableItemChildValuesSources(FinancialReportingClientServer.ChildItems(TreeRow), ItemsList, ValuesItemsTypes);
		
	EndDo;
	
EndProcedure

Procedure ComplexTableItemChildValuesSources(ChildItems, ItemsList)
	
	For Each TreeRow In ChildItems Do
		
		ItemsList.Add(TreeRow);
		
		ComplexTableItemChildValuesSources(FinancialReportingClientServer.ChildItems(TreeRow), ItemsList);
		
	EndDo;
	
EndProcedure

Function ObjectAttributesByRefOrAddress(Item, AttributesNames, Cache)
	
	If TypeOf(Item) = Type("String") Then
		ObjectAttributes = GetFromTempStorage(Item);
	Else
		Structure = New Structure(AttributesNames);
		ObjectAttributes = New Structure;
		For Each KeyValue In Structure Do
			ObjectAttributes.Insert(
				KeyValue.Key,
				Catalogs.FinancialReportsItems.ItemFieldValueFromCache(Item, KeyValue.Key, Cache));
		EndDo;
	EndIf;
	
	Return ObjectAttributes;
	
EndFunction

Procedure SupplimentSourcesWithOperandsRecursively(ItemsList, ValuesItemsTypes, ItemsTable, Result, Cache, Filling)
	
	For Each ListItem In ItemsList Do
		ProcessSourceOperands(ListItem, ValuesItemsTypes, ItemsTable, Result, Cache, Filling);
	EndDo;
	
EndProcedure

Procedure ProcessSourceOperands(ListItem, ValuesItemsTypes, ItemsTable, Result, Cache, Filling)
	
	Item = ListItem.Item;
	
	SearchOperandByAddress = False;
	ItemStructure = ObjectAttributesByRefOrAddress(Item, "ItemType, FormulaOperands", Cache);
	If TypeOf(Item) = Type("String") Then
		SearchOperandByAddress = True;
	EndIf;
	
	NewRow = Result.Add();
	FillPropertyValues(NewRow, ListItem);
	
	If ItemStructure.ItemType = Enums.FinancialReportItemsTypes.UserDefinedCalculatedIndicator
		Or (ItemStructure.ItemType = Enums.FinancialReportItemsTypes.BudgetItem And Filling) Then
		
		If Filling Then
			NewRow.ItemType = Enums.FinancialReportItemsTypes.UserDefinedCalculatedIndicator;
		EndIf;
		
		HasSources = False;
		
		For Each OperandRow In ItemStructure.FormulaOperands Do
			
			If SearchOperandByAddress And ValueIsFilled(OperandRow.ItemStructureAddress) Then
				OperandStructure = GetFromTempStorage(OperandRow.ItemStructureAddress);
				OperandRef = OperandRow.ItemStructureAddress;
			Else
				OperandStructure = New Structure;
				OperandStructure.Insert("ItemType", 
					Catalogs.FinancialReportsItems.ItemFieldValueFromCache(OperandRow.Operand, "ItemType", Cache));
				OperandRef = OperandRow.Operand;
			EndIf;
			
			If ValuesItemsTypes.Find(OperandStructure.ItemType) <> Undefined Then
				NewRow = Result.Add();
				NewRow.ItemType = OperandStructure.ItemType;
				NewRow.Item = OperandRef;
				NewRow.Parent = Item;
				NewRow.Description = "[" + OperandRow.ID + "]";
				HasSources = True;
			EndIf;
			
		EndDo;
		
		If Not HasSources Then
			Result.Delete(NewRow);
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure FillAvailableFieldsRecursively(AvailableFields, AvailableFieldsItems)
	
	For Each AvailableFieldsItem In AvailableFieldsItems Do
		
		If AvailableFieldsItem.Folder Then
			FillAvailableFieldsRecursively(AvailableFields, AvailableFieldsItem.Items);
		Else
			NewRow = AvailableFields.Add();
			NewRow.CompositionField = AvailableFieldsItem.Field;
			NewRow.FieldName = String(AvailableFieldsItem.Field);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure CopyFilterRecursively(FilterSource, FilterRecipient, UsedOnly, ExceptionFields,
								Postfix, CheckFieldsAvailabilityParameters)
	
	CheckFieldsAvailability = CheckFieldsAvailabilityParameters.CheckFieldsAvailability;
	AvailableFilterFields = CheckFieldsAvailabilityParameters.AvailableFilterFields;
	
	For Each Item In FilterSource.Items Do
		
		If Not (UsedOnly And Item.Use Or Not UsedOnly) Then
			Continue;
		EndIf;
		
		If TypeOf(Item) = Type("DataCompositionFilterItemGroup") Then
			
			NewItem = NewFilter(FilterRecipient, Undefined, Undefined, Type("DataCompositionFilterItemGroup"));
			FillPropertyValues(NewItem, Item);
			CopyFilterRecursively(Item, NewItem, UsedOnly, ExceptionFields, Postfix, CheckFieldsAvailabilityParameters);
			
		Else
			
			If Not ValueIsFilled(Item.LeftValue) Then
				Continue;
			EndIf;
			
			If ValueIsFilled(ExceptionFields) Then
				Field = FinancialReportingClientServer.SplitFieldAndAttributeNames(String(Item.LeftValue));
				If ExceptionFields.Property(Field.Name) Then
					Continue;
				EndIf;
			EndIf;
			
			If CheckFieldsAvailability Then
				FieldIsAvailable = False;
				If Not AvailableFilterFields.Find(Item.LeftValue, "CompositionField") = Undefined Then
					FieldIsAvailable = True;
				EndIf;
				If Not FieldIsAvailable Then
					FieldNameAndAttribute = FinancialReportingClientServer.SplitFieldAndAttributeNames(String(Item.LeftValue));
					If Not AvailableFilterFields.Find(FieldNameAndAttribute.Name, "FieldName") = Undefined Then
						FieldIsAvailable = True;
					EndIf;
				EndIf;
				If Not FieldIsAvailable Then
					Continue;
				EndIf;
			EndIf;
			
			NewItem = NewFilter(FilterRecipient, Undefined, Undefined, Type("DataCompositionFilterItem"));
			FillPropertyValues(NewItem, Item);
			
			If Postfix <> "" Then
				Field = FinancialReportingClientServer.SplitFieldAndAttributeNames(String(NewItem.LeftValue));
				NewFieldName = Field.Name + Postfix + "." + Field.Attribute;
				If StrFind(Field.Name, "AnalyticalDimension") And StrFind("DRCR", Upper(Postfix)) Then
					Number = Right(Field.Name, 1);
					If StrFind("12345", Number) Then
						Pattern = StrReplace(Field.Name, Number, "%1");
						NewFieldName = StrTemplate(Pattern, Postfix + Number) + "." + Field.Attribute;
					EndIf;
				EndIf;
				NewItem.LeftValue = New DataCompositionField(NewFieldName);
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function ItemValuesItemsAndIndicators(SourcesTable, IncludeNonfinancial)
	
	DataSources = New ValueTable;
	DataSources.Columns.Add("Source");
	DataSources.Columns.Add("ItemType");
	
	For Each AvailableSourcesRow In SourcesTable Do
		
		If AvailableSourcesRow.ItemType = Enums.FinancialReportItemsTypes.NonfinancialIndicator Then
			
			If IncludeNonfinancial Then
				NewRow = DataSources.Add();
				NewRow.Source = AvailableSourcesRow.Item;
				NewRow.ItemType = AvailableSourcesRow.ItemType;
			EndIf;
			
		ElsIf AvailableSourcesRow.ItemType = Enums.FinancialReportItemsTypes.BudgetItem
			Or AvailableSourcesRow.ItemType = Enums.FinancialReportItemsTypes.BudgetIndicator
			Or AvailableSourcesRow.ItemType = Enums.FinancialReportItemsTypes.EditableValue Then
			
			NewRow = DataSources.Add();
			NewRow.Source = AvailableSourcesRow.Item;
			NewRow.ItemType = AvailableSourcesRow.ItemType;
			
		EndIf;
		
	EndDo;
	
	Return DataSources;
	
EndFunction

Function ReportSettings(Parameters)
	
	// Context report settings
	SettingsComposer = New DataCompositionSettingsComposer;
	UserSettings = SettingsComposer.UserSettings;
	NewSettings = New Structure;
	NewSettings.Insert("ReportsSet", Parameters.ReportsSet);
	NewSettings.Insert("ReportType", Parameters.ReportType);
	NewSettings.Insert("BeginOfPeriod", Parameters.ReportPeriod.BeginOfPeriod);
	NewSettings.Insert("EndOfPeriod", Parameters.ReportPeriod.EndOfPeriod);
	
	List = New ValueList;
	If ValueIsFilled(Parameters.Filter.Company) Then
		List.Add(Parameters.Filter.Company);
	EndIf;
	NewSettings.Insert("Companies", List);
	
	List = New ValueList;
	If Catalogs.BusinessUnits.AccountingByBusinessUnits() Then
		If ValueIsFilled(Parameters.Filter.BusinessUnit) Then
			List.Add(Parameters.Filter.BusinessUnit);
		EndIf;
	EndIf;
	NewSettings.Insert("BusinessUnits", List);
	
	If Catalogs.LinesOfBusiness.AccountingByLinesOfBusiness() Then
		List = New ValueList;
		If ValueIsFilled(Parameters.Filter.LineOfBusiness) Then
			List.Add(Parameters.Filter.LineOfBusiness);
		EndIf;
		NewSettings.Insert("LinesOfBusiness", List);
	EndIf;
	
	NewSettings.Insert("AmountsInThousands", Parameters.AmountsInThousands);
	NewSettings.Insert("OutputTitle", False);
	NewSettings.Insert("OutputFooter", False);
	NewSettings.Insert("HideSettingsUponReportGeneration", False);
	NewSettings.Insert("SettingsPanelVisibility", True);
	NewSettings.Insert("Resource", Parameters.Resource);
	UserSettings.AdditionalProperties.Insert("ReportData", New ValueStorage(NewSettings));
	
	Return UserSettings;
	
EndFunction

Procedure UserDefinedCalculatedIndicatorDetails(ReportSettings)
	
	IndicatorData = ReportSettings.IndicatorData;
	ReverseSign = IndicatorData.ReverseSign;
	Currency = DriveReUse.GetFunctionalCurrency();
	
	// Prepare the template
	SpreadsheetDocument = New SpreadsheetDocument;
	Template = Reports.FinancialReport.GetTemplate("UserDefinedCalculatedIndicatorDetails");
	SectionArea = Template.GetArea("Section");
	
	// Output the report title
	Area = Template.GetArea("Indicator");
	Area.Parameters.Indicator = IndicatorData.DescriptionForPrinting;
	SpreadsheetDocument.Put(Area);
	OutputRow(SpreadsheetDocument, SectionArea);
	
	// Output the parameters section
	SectionTitleArea = Template.GetArea("SectionTitle");
	SectionTitleArea.Parameters.Title = "Parameters";
	SpreadsheetDocument.Put(SectionTitleArea);
	SpreadsheetDocument.StartRowGroup();
	// Period
	Period = ReportSettings.ReportPeriod;
	PeriodString = DriveReports.GetPeriodPresentation(
			New Structure("BeginOfPeriod, EndOfPeriod", Period.BeginOfPeriod, Period.EndOfPeriod), True);
	OutputRow(SpreadsheetDocument, SectionArea, NStr("en = 'Period'; ru = 'Период';pl = 'Okres';es_ES = 'Período';es_CO = 'Período';tr = 'Dönem';it = 'Periodo';de = 'Zeitraum'") + ": " + PeriodString);
	// Currency
	Pattern = NStr("en = 'Currency'; ru = 'Валюта';pl = 'Waluta';es_ES = 'Moneda';es_CO = 'Moneda';tr = 'Para birimi';it = 'Valuta';de = 'Währung'")+": %1";
	Text = StringFunctionsClientServer.SubstituteParametersToString(Pattern, Currency);
	OutputRow(SpreadsheetDocument, SectionArea, Text);
	SpreadsheetDocument.EndRowGroup();
	OutputRow(SpreadsheetDocument, SectionArea);
	
	// Output the filter section
	If ReportSettings.Filter.Count() Then
		SectionTitleArea.Parameters.Title = NStr("en = 'Filter'; ru = 'Отбор';pl = 'Filtr';es_ES = 'Filtro';es_CO = 'Filtro';tr = 'Filtre';it = 'Filtro';de = 'Filter'");
		SpreadsheetDocument.Put(SectionTitleArea);
		SpreadsheetDocument.StartRowGroup();
		For Each FilterItem In ReportSettings.Filter Do
			If ValueIsFilled(FilterItem.Value) Then
				Pattern = "%1: %2";
				FilterValue = StrConcat(FilterItem.Value, ",");
				Text = StringFunctionsClientServer.SubstituteParametersToString(Pattern, FilterItem.Key, FilterValue);
				OutputRow(SpreadsheetDocument, SectionArea, Text);
			EndIf;
		EndDo;
		SpreadsheetDocument.EndRowGroup();
		OutputRow(SpreadsheetDocument, SectionArea);
	EndIf;
	
	// Output the formula text
	FormulaText = IndicatorData.Formula;
	If ReverseSign Then
		FormulaText = "-(" + FormulaText + ")";
	EndIf;
	SectionTitleArea.Parameters.Title = NStr("en = 'Calculation formula'; ru = 'Формула расчета';pl = 'Formuła rozliczenia';es_ES = 'Fórmula de cálculo';es_CO = 'Fórmula de cálculo';tr = 'Hesaplama formülü';it = 'Formula di calcolo';de = 'Berechnungsformel'");
	SpreadsheetDocument.Put(SectionTitleArea);
	SpreadsheetDocument.StartRowGroup();
	OutputRow(SpreadsheetDocument, SectionArea, FormulaText);
	SpreadsheetDocument.EndRowGroup();
	
	// Getting formula's operand values
	FormulaText = "";
	FormulaOperands = GetFormulaOperands(IndicatorData, ReportSettings, FormulaText);
	
	// Output the formula's text with substituted values
	If FormulaOperands.Count() Then
		If ReverseSign Then
			FormulaText = "-(" + FormulaText + ")";
		EndIf;
		SectionTitleArea.Parameters.Title = NStr("en = 'Calculations'; ru = 'Расчеты';pl = 'Obliczenia';es_ES = 'Cálculos';es_CO = 'Cálculos';tr = 'Hesaplamalar';it = 'Calcoli';de = 'Berechnungen'");
		SpreadsheetDocument.Put(SectionTitleArea);
		SpreadsheetDocument.StartRowGroup();
		OutputRow(SpreadsheetDocument, SectionArea, FormulaText);
		SpreadsheetDocument.EndRowGroup();
	EndIf;
	
	// Output the result of calculation
	Area = Template.GetArea("IndicatorValue");
	Area.Parameters.Result = IndicatorData.Value;
	SpreadsheetDocument.Put(Area);
	OutputRow(SpreadsheetDocument, SectionArea);
	OutputRow(SpreadsheetDocument, SectionArea);
	
	// Output operands' values
	SectionTitleArea.Parameters.Title = NStr("en = 'Formula operands'; ru = 'Операнды формулы';pl = 'Operandy formuły';es_ES = 'Operandos de fórmula';es_CO = 'Operandos de fórmula';tr = 'Formül işlenenleri';it = 'Operandi formula';de = 'Formel-Operanden'");
	SpreadsheetDocument.Put(SectionTitleArea);
	
	Area = Template.GetArea("OperandsHeader");
	SpreadsheetDocument.Put(Area);
	
	Area = Template.GetArea("Operand");
	For Each Operand In FormulaOperands Do
		Area.Parameters.Fill(Operand);
		DetailsData = New Structure("Indicator, StartDate, EndDate", Operand.ReportItem);
		DetailsData.Insert("StartDate", Period.BeginOfPeriod);
		DetailsData.Insert("EndDate", Period.EndOfPeriod);
		If IndicatorData.Property("AnalyticalDimension1") Then
			DetailsData.Insert("AnalyticalDimension1", IndicatorData.AnalyticalDimension1);
			DetailsData.Insert("AnalyticalDimensionType", IndicatorData.AnalyticalDimensionType);
		EndIf;
		Area.Parameters.Indicator = DetailsData;
		SpreadsheetDocument.Put(Area);
	EndDo;
	
	// Setting additional parameters of the spreadsheet document
	SpreadsheetDocument.BlackAndWhite = True;
	SpreadsheetDocument.FitToPage = True;
	
	ReportSettings.Insert("Result", SpreadsheetDocument);
	
EndProcedure

Procedure ReportTypeDescription(Parameters, ReportItemsTree)
	
	ItemsTypes = Parameters.ItemsTypes;
	If TypeOf(ReportItemsTree) = Type("ValueTreeRow") Then
		If ReportItemsTree.ItemType = ItemsTypes.TableIndicatorsInColumns
			Or ReportItemsTree.ItemType = ItemsTypes.TableIndicatorsInRows
			Or ReportItemsTree.ItemType = ItemsTypes.TableComplex Then
			Return;
		EndIf;
	EndIf;
	
	For Each ReportItem In ReportItemsTree.Rows Do
		
		If ReportItem.ItemType = ItemsTypes.ReportTitle
			Or ReportItem.ItemType = ItemsTypes.NonEditableText
			Or ReportItem.ItemType = ItemsTypes.EditableText Then
			
			AddTextBlock(Parameters, ReportItem);
			ReportTypeDescription(Parameters, ReportItem);
			
		ElsIf ReportItem.ItemType = ItemsTypes.TableIndicatorsInColumns
			Or ReportItem.ItemType = ItemsTypes.TableIndicatorsInRows
			Or ReportItem.ItemType = ItemsTypes.TableComplex Then
			
			AddTable(Parameters, ReportItem);
			
		ElsIf IsIndicator(ReportItem.ItemType, ItemsTypes, ReportItem.IsLinked) Then
			
			AddReportIndicator(Parameters, ReportItem);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function OutputReport(Parameters, ReportItemsTree)
	
	ItemsTypes = Parameters.ItemsTypes;
	
	ResultDocument = New SpreadsheetDocument;
	ReportOutputParameters(Parameters);
	
	ResultDocument.StartRowAutoGrouping();
	For Each BlockDescription In Parameters.ReportBlocks Do
		
		If BlockDescription.ItemType = ItemsTypes.ReportTitle
			Or BlockDescription.ItemType = ItemsTypes.EditableText
			Or BlockDescription.ItemType = ItemsTypes.NonEditableText Then
			
			OutputText(Parameters.OutputTemplate, BlockDescription, ResultDocument, ItemsTypes, Parameters.MaximumColumnNumber);
			
		ElsIf BlockDescription.ItemType = ItemsTypes.AccountingDataIndicator
			Or BlockDescription.ItemType = ItemsTypes.UserDefinedFixedIndicator 
			Or BlockDescription.ItemType = ItemsTypes.UserDefinedCalculatedIndicator
			Or BlockDescription.ItemType = ItemsTypes.GroupTotal Then
			
			OutputIndicator(Parameters, BlockDescription, ResultDocument);
			
		ElsIf BlockDescription.ItemType = ItemsTypes.TableIndicatorsInRows
			Or BlockDescription.ItemType = ItemsTypes.TableIndicatorsInColumns 
			Or BlockDescription.ItemType = ItemsTypes.TableComplex Then
			
			OutputTable(Parameters, BlockDescription, ResultDocument);
			
		EndIf;
		
	EndDo;
	ResultDocument.EndRowAutoGrouping();
	
	Return ResultDocument;
	
EndFunction

Procedure OutputRow(SpreadsheetDocument, Area, Text = "")
	
	Area.Parameters.Row = Text;
	SpreadsheetDocument.Put(Area);
	
EndProcedure

Function GetFormulaOperands(ItemData, ReportSettings, FormulaText)
	
	ReportType = ItemData.Ref.Owner;
	Indicator = ItemData.Ref;
	If ValueIsFilled(ItemData.LinkedItem) Then
		Indicator = ItemData.LinkedItem;
	EndIf;
	
	TreeSchema = Reports.FinancialReport.GetTemplate("UserDefinedCalculatedIndicatorOperands");
	TreeSchemaComposer = SchemaComposer(TreeSchema);
	SetCompositionParameter(TreeSchemaComposer, "ReportType", ReportType);
	SetCompositionParameter(TreeSchemaComposer, "ReportItem", ItemData.Ref);
	AttributesCache = AdditionalAttributesCache(ReportType);
	SetCompositionParameter(TreeSchemaComposer, "AttributesCache", AttributesCache);
	
	FormulaOperands = UnloadDataCompositionResult(TreeSchema, TreeSchemaComposer);
	FormulaText = ItemData.Formula;
	IndicatorParameters = IndicatorObtainingParameters(ReportSettings);
	For Each Operand In FormulaOperands Do
		FilterString = "";
		If Operand.HasSettings Then
			FilterSetting = Operand.AdditionalFilter.Get();
			If FilterSetting <> Undefined Then
				FilterString = String(FilterSetting.Filter);
			EndIf;
		EndIf;
		Operand.Filter = FilterString;
		Operand.TotalsPresentation = TotalsTypePresentation(Operand.TotalsType, Operand.OpeningBalance);
		OperandValues = SimpleIndicatorValue(IndicatorParameters, Operand);
		If OperandValues.Count() Then
			Value = OperandValues.Total("Value");
			Operand.Value = Format(Value, ReportSettings.ValuesFormat);
			Result = OperandValues[0];
			ValueString = Format(Result.Value, ReportSettings.ValuesFormat);
			If Value = 0 Then
				ValueString = "0";
			EndIf;
			FormulaText = StrReplace(FormulaText, "[" + Operand.ID + "]", ValueString);
		EndIf;
	EndDo;
	
	If IsBlankString(FormulaText) Then
		FormulaText = "0";
	EndIf;
	
	Return FormulaOperands;
	
EndFunction

Procedure AddTextBlock(Parameters, ReportItem)

	ReportPeriod = Parameters.ReportPeriod;
	TitleText = AdditionalAttributeValue(ReportItem.ReportItem, "Text", Parameters.AttributesCache);
	ReportsSet = ReportTypeReportsSet(Parameters.ReportType);
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	PatternText = "[" + NStr("en = 'Reports set'; ru = 'Набор отчетов';pl = 'Zestaw raportów';es_ES = 'Configuración de informes';es_CO = 'Configuración de informes';tr = 'Raporlar ayarlı';it = 'Insieme di report';de = 'Berichte festgelegt'", DefaultLanguageCode) + "]";
	If StrFind(TitleText, PatternText) > 0 Then
		TitleText = StrReplace(TitleText, PatternText, String(ReportsSet));
	EndIf;
	
	PatternText = "[" + NStr("en = 'Report type'; ru = 'Тип отчета';pl = 'Typ sprawozdania';es_ES = 'Tipo de informe';es_CO = 'Tipo de informe';tr = 'Rapor türü';it = 'Tipo di report';de = 'Berichtstyp'", DefaultLanguageCode) + "]";
	If StrFind(TitleText, PatternText) > 0 Then
		TitleText = StrReplace(TitleText, PatternText, String(Parameters.ReportType));
	EndIf;
	
	PatternText = "[" + NStr("en = 'Report period'; ru = 'Период отчета';pl = 'Okres sprawozdawczy';es_ES = 'Período de informes';es_CO = 'Período de informes';tr = 'Rapor dönemi';it = 'Periodo report';de = 'Berichtszeitraum'", DefaultLanguageCode) + "]";
	If StrFind(TitleText, PatternText) > 0 Then
		PeriodString = DriveReports.GetPeriodPresentation(
			New Structure("BeginOfPeriod, EndOfPeriod", ReportPeriod.BeginOfPeriod, ReportPeriod.EndOfPeriod), True);
		TitleText = StrReplace(TitleText, PatternText, TrimAll(PeriodString));
	EndIf;
	
	PatternText = "[" + NStr("en = 'Report period end date'; ru = 'Дата окончания период отчета';pl = 'Data zakończenia okresu sprawozdawczego';es_ES = 'Fecha de fin del período del informe';es_CO = 'Fecha de fin del período del informe';tr = 'Rapor dönemi bitiş tarihi';it = 'Data di fine periodo del report';de = 'Enddatum des Berichtszeitraums'", DefaultLanguageCode) + "]";
	If StrFind(TitleText, PatternText) > 0 Then
		ReportEnd = Format(ReportPeriod.EndOfPeriod, "DLF=DD");
		TitleText = StrReplace(TitleText,PatternText,String(ReportEnd));
	EndIf;
	
	PatternText = "[" + NStr("en = 'Current date and time'; ru = 'Текущая дата и время';pl = 'Aktualna data i godzina';es_ES = 'Fecha y hora actuales';es_CO = 'Fecha y hora actuales';tr = 'Güncel tarih ve saat';it = 'Data e orario corrente';de = 'Aktuelles Datum und Uhrzeit'", DefaultLanguageCode) + "]";
	If StrFind(TitleText, PatternText) > 0 Then
		ReportGenerationDate = Format(Parameters.ReportGenerationDate, "DLF=DT");
		TitleText = StrReplace(TitleText,PatternText, ReportGenerationDate);
	EndIf;
	
	PatternText = "[" + Nstr("en = 'Company'; ru = 'Организация';pl = 'Firma';es_ES = 'Empresa';es_CO = 'Empresa';tr = 'İş yeri';it = 'Azienda';de = 'Firma'", DefaultLanguageCode) + "]";
	If StrFind(TitleText, PatternText) > 0 Then
		If Parameters.Property("Filter") And Parameters.Filter.Property("Company") Then
			FilterValue = Parameters.Filter.Company;
			
			Companies = New Array;
			If TypeOf(FilterValue) = Type("CatalogRef.Companies") Then
				Companies.Add(FilterValue);
			ElsIf TypeOf(FilterValue) = Type("Array") Then
				Companies = FilterValue;
			ElsIf TypeOf(FilterValue) = Type("ValueList") Then
				Companies = FilterValue.UnloadValues();
			EndIf;
			
			CompanyName = "";
			AttributesNames = "Description, DescriptionFull";
			Attributes = Common.ObjectsAttributesValues(Companies, AttributesNames);
			
			For Each Company In Attributes Do
				CompanyName = CompanyName + ?(IsBlankString(CompanyName), "", ", ");
				CompanyName = CompanyName + Company.Value.Description;
			EndDo;
			
		EndIf;
		TitleText = StrReplace(TitleText, PatternText, CompanyName);
	EndIf;
	
	Data = New Structure("Text", TitleText);
	AddReportBlockDescription(Parameters, ReportItem, Data);
	
EndProcedure

Procedure AddTable(Parameters, ReportItem)
	
	TableID = ItemID(ReportItem);
	TableTree = ReportItem;
	If TableTree.IsLinked Then
		LinkedTable = RefreshReportTree(ReportItem.LinkedItem.Owner, ReportItem.LinkedItem);
		TableTree = LinkedTable.Rows[0];
	EndIf;
	
	TableData = PrepareTableData(TableTree, Parameters);
	
	If Parameters.OutputNote Then
		NewRow = TableData.ReportColumns.Insert(0);
		NewRow.ColumnName = "Note";
		NewRow.TotalLevel = -1;
	EndIf;
	
	If Parameters.OutputRowCode Then
		NewRow = TableData.ReportColumns.Insert(0);
		NewRow.ColumnName = "RowCode";
		NewRow.TotalLevel = -1;
	EndIf;
	
	Parameters.MaximumColumnNumber = Max(Parameters.MaximumColumnNumber, TableData.ReportColumns.Count());
	AddReportBlockDescription(Parameters, ReportItem, TableData);
	Parameters.ReportPeriod.Periodicity.Clear();
	
EndProcedure

Function IsIndicator(ItemType, ItemsTypes, IsLinked = False)
	
	Return ItemType = ItemsTypes.AccountingDataIndicator
			Or ItemType = ItemsTypes.UserDefinedFixedIndicator 
			Or ItemType = ItemsTypes.UserDefinedCalculatedIndicator
			Or ItemType = ItemsTypes.GroupTotal And IsLinked;
	
EndFunction

Procedure AddReportIndicator(Parameters, ReportItem)
	
	IndicatorParameters = IndicatorObtainingParameters(Parameters);
	IndicatorParameters.Indicator = ReportItem;
	
	IndicatorValue = ReportIndicatorValue(IndicatorParameters);
	
	CellDetails = New Structure("StartDate, EndDate, ItemType, Account, UserDefinedFixedIndicator");
	FillPropertyValues(CellDetails, ReportItem);
	CellDetails.StartDate = Parameters.ReportPeriod.BeginOfPeriod;
	CellDetails.EndDate = Parameters.ReportPeriod.EndOfPeriod;
	CellDetails.Insert("Indicator", ReportItem.ReportItem);
	
	Data = New Structure("MarkItem, IsLinked");
	FillPropertyValues(Data, ReportItem);
	Data.Insert("Details", CellDetails);
	Data.Insert("Value", IndicatorValue[0].Value);
	
	AddReportBlockDescription(Parameters, ReportItem, Data);
	
EndProcedure

Function ReportOutputParameters(Parameters)
	
	ItemsTypes = Parameters.ItemsTypes;
	LayoutTemplate = Catalogs.FinancialReportsTypes.GetTemplate("FinancialReport");
	OutputTemplate = New Structure;
	OutputTemplate.Insert("ItemType", New Map);
	
	// All output templates
	OutputTemplate.Insert("ReportTitle",	LayoutTemplate.GetArea("ReportTitle"));
	OutputTemplate.Insert("Text",			LayoutTemplate.GetArea("Text"));
	OutputTemplate.Insert("TableTitle",		LayoutTemplate.GetArea("TableTitle"));
	OutputTemplate.Insert("EmptyRow",		LayoutTemplate.GetArea("EmptyRow"));
	OutputTemplate.Insert("ColumnTotal",	LayoutTemplate.GetArea("Grouping|Value"));
	
	OutputTemplate.Insert("Header",					RowTemplate(LayoutTemplate, "Header"));
	OutputTemplate.Insert("ReportRow",				RowTemplate(LayoutTemplate, "ReportRow"));
	OutputTemplate.Insert("Grouping",				RowTemplate(LayoutTemplate, "Grouping"));
	OutputTemplate.Insert("RowsTotal",				RowTemplate(LayoutTemplate, "RowsTotal"));
	OutputTemplate.Insert("SingleIndicator",		RowTemplate(LayoutTemplate, "SingleIndicator"));
	OutputTemplate.Insert("SingleIndicatorMarked",	RowTemplate(LayoutTemplate, "SingleIndicatorMarked"));
	OutputTemplate.Insert("TableLowerBoundary",		RowTemplate(LayoutTemplate, "TableLowerBoundary"));
	
	// Sorting by item types
	RowTemplate = RowTemplate(LayoutTemplate, "ReportRow");
	OutputTemplate.ItemType.Insert(ItemsTypes.AccountingDataIndicator,			RowTemplate);
	OutputTemplate.ItemType.Insert(ItemsTypes.UserDefinedFixedIndicator,		RowTemplate);
	OutputTemplate.ItemType.Insert(ItemsTypes.UserDefinedCalculatedIndicator,	RowTemplate);
	OutputTemplate.ItemType.Insert(ItemsTypes.TableItem,						RowTemplate);
	
	RowTemplate = RowTemplate(LayoutTemplate, "Grouping");
	OutputTemplate.ItemType.Insert(ItemsTypes.Dimension,	RowTemplate);
	OutputTemplate.ItemType.Insert(ItemsTypes.Group,		RowTemplate);
	
	RowTemplate = RowTemplate(LayoutTemplate, "RowsTotal");
	OutputTemplate.ItemType.Insert(ItemsTypes.GroupTotal,	RowTemplate);
	
	Parameters.Insert("OutputTemplate", OutputTemplate);
	
	Return OutputTemplate;
	
EndFunction

Procedure OutputText(OutputTemplate, OutputItem, ResultDocument, ItemsTypes, TextWidth)
	
	If OutputItem.ItemType = ItemsTypes.ReportTitle Then
		
		Area = OutputTemplate.ReportTitle;
		Area.Parameters.ReportTitle = OutputItem.Description.Text;
		
	ElsIf OutputItem.ItemType = ItemsTypes.TableComplex
		Or OutputItem.ItemType = ItemsTypes.TableIndicatorsInColumns
		Or OutputItem.ItemType = ItemsTypes.TableIndicatorsInRows Then
		
		Area = OutputTemplate.TableTitle;
		Area.Parameters.TableTitle = OutputItem.DescriptionForPrinting;
		
	Else
		
		Area = OutputTemplate.Text;
		Area.Parameters.Text = OutputItem.Description.Text;
		
	EndIf;
	
	MergeHorizontally(Area, 1, 3, 2);
	NewArea = ResultDocument.Put(Area, 0);
	
	If OutputItem.ItemType = ItemsTypes.EditableText Then
		
		TextArea = ResultDocument.Area(NewArea.Top + 1, 1);
		TextArea.Protection = False;
		TextArea.BackColor = StyleColors.MasterFieldBackground;
		
	EndIf;
	
EndProcedure

Procedure OutputIndicator(Parameters, OutputItem, ResultDocument)
	
	ItemsTypes = Parameters.ItemsTypes;
	RowTemplate = Parameters.OutputTemplate.SingleIndicator;
	If OutputItem.Description.MarkItem Then
		RowTemplate = Parameters.OutputTemplate.SingleIndicatorMarked;
	EndIf;
	
	RowTemplate.Indicator.Parameters.Description = OutputItem.DescriptionForPrinting;
	RowTemplate.Indicator.Parameters.Details = OutputItem.ReportItem;
	ResultDocument.Put(RowTemplate.Indicator);
	
	CellTemplate = RowTemplate.Value;
	CellTemplate.Parameters.Value = Format(OutputItem.Description.Value, Parameters.ValuesFormat);
	CellTemplate.Parameters.Details = OutputItem.Description.Details;
	ResultDocument.Join(CellTemplate);
	
EndProcedure

Procedure OutputTable(Parameters, OutputItem, ResultDocument)
	
	If OutputItem.Description.TableHeader = Undefined Then
		Return;
	EndIf;
	
	If OutputItem.OutputItemTitle Then
		OutputText(Parameters.OutputTemplate, OutputItem, ResultDocument,
				Parameters.ItemsTypes, Parameters.MaximumColumnNumber);
	EndIf;
	OutputTableHeader(Parameters, OutputItem, ResultDocument);
	
	RowsTree = OutputItem.Description.RowsTree;
	For Each TableRow In RowsTree.Rows Do
		Parameters.Insert("RowFilter", New Structure);
		OutputTableRow(TableRow, ResultDocument, OutputItem.Description, Parameters);
	EndDo;
	ResultDocument.Put(Parameters.OutputTemplate.EmptyRow);
	Parameters.Delete("RowFilter");
	
EndProcedure

Function IndicatorObtainingParameters(ReportSettings, TableDescription = Undefined)
	
	IndicatorParameters = NewIndicatorObtainingParameters();
	IndicatorParameters.ReportPeriod = ReportSettings.ReportPeriod;
	IndicatorParameters.ReportFilter = ReportSettings.Filter;
	IndicatorParameters.MessagesAboutErrors = ReportSettings.MessagesAboutErrors;
	IndicatorParameters.Resource = ReportSettings.Resource;
	IndicatorParameters.Insert("ItemsTypes", ReportSettings.ItemsTypes);
	
	If TableDescription <> Undefined Then
		IndicatorParameters.ReportPeriod.Insert("Periodicity", TableDescription.Periodicity);
		IndicatorParameters.Dimensions = TableDescription.RegisterDimensions;
		If TableDescription.Property("AnalyticalDimension") Then
			AnalyticalDimension = New Structure;
			AnalyticalDimension.Insert("Type", TableDescription.AnalyticalDimension.AnalyticalDimension);
			AnalyticalDimension.Insert("HasSettings", TableDescription.AnalyticalDimension.HasSettings);
			AnalyticalDimension.Insert("Filter", TableDescription.AnalyticalDimension.AdditionalFilter);
			AnalyticalDimension.Insert("Description", TableDescription.AnalyticalDimension.DescriptionForPrinting);
			IndicatorParameters.AnalyticalDimension = AnalyticalDimension;
		EndIf;
	EndIf;
	
	IndicatorParameters.ReportIntervals = Catalogs.FinancialReportsItems.ReportIntervals(ReportSettings.ReportPeriod);
	
	Return IndicatorParameters;
	
EndFunction

Function TotalsTypePresentation(TotalsType, OpeningBalance)
	
	Result = "";
	TotalsTypes = Enums.TotalsTypes;
	
	If TotalsType = TotalsTypes.Balance And OpeningBalance Then
		
		Result = NStr("en = 'Opening balance'; ru = 'Начальный остаток';pl = 'Saldo początkowe';es_ES = 'Saldo de apertura';es_CO = 'Saldo de apertura';tr = 'Açılış bakiyesi';it = 'Saldo di apertura';de = 'Anfangssaldo'");
		
	ElsIf TotalsType = TotalsTypes.BalanceDr And OpeningBalance Then
		
		Result = NStr("en = 'Opening balance Dr'; ru = 'Начальный остаток Дт';pl = 'Saldo początkowe Wn';es_ES = 'Saldo de débito inicial';es_CO = 'Saldo de débito inicial';tr = 'Açılış borç bakiyesi';it = 'Saldo iniziale Deb';de = 'Anfangssaldo Soll'");
		
	ElsIf TotalsType = TotalsTypes.BalanceCr And OpeningBalance Then
		
		Result = NStr("en = 'Opening balance Cr'; ru = 'Начальный остаток Кт';pl = 'Saldo początkowe Ma';es_ES = 'Saldo de crédito inicial';es_CO = 'Saldo de crédito inicial';tr = 'Açılış alacak bakiyesi';it = 'Saldo iniziale Cred';de = 'Anfangssaldo Haben'");
		
	ElsIf TotalsType = TotalsTypes.Balance And Not OpeningBalance Then
		
		Result = NStr("en = 'Closing balance'; ru = 'Конечный остаток';pl = 'Saldo końcowe';es_ES = 'Saldo final';es_CO = 'Saldo final';tr = 'Kapanış bakiyesi';it = 'Saldo di chiusura';de = 'Abschlusssaldo'");
		
	ElsIf TotalsType = TotalsTypes.BalanceDr And Not OpeningBalance Then
		
		Result = NStr("en = 'Closing balance Dr'; ru = 'Конечный остаток Дт';pl = 'Saldo końcowe Wn';es_ES = 'Saldo de débito final';es_CO = 'Saldo de débito final';tr = 'Kapanış borç bakiyesi';it = 'Saldo finale Deb';de = 'Soll-Abschlusssaldo'");
		
	ElsIf TotalsType = TotalsTypes.BalanceCr And Not OpeningBalance Then
		
		Result = NStr("en = 'Closing balance Cr'; ru = 'Конечный остаток Кт';pl = 'Saldo końcowe Ma';es_ES = 'Saldo de crédito final';es_CO = 'Saldo de crédito final';tr = 'Kapanış alacak bakiyesi';it = 'Saldo finale Cred';de = 'Abschlusssaldo Haben'");
		
	ElsIf TotalsType = TotalsTypes.Turnover Then
		
		Result = NStr("en = 'Turnover for the period'; ru = 'Оборот за период';pl = 'Obrót za okres';es_ES = 'Facturación por el período';es_CO = 'Facturación por el período';tr = 'Dönem cirosu';it = 'Fatturato per il periodo';de = 'Umsatz für den Zeitraum'");
		
	ElsIf TotalsType = TotalsTypes.TurnoverDr Then
		
		Result = NStr("en = 'Turnover Dr for the period'; ru = 'Оборот Дт за период';pl = 'Obrót Dr za okres';es_ES = 'Facturación de débito por el período';es_CO = 'Facturación de débito por el período';tr = 'Dönem borç devir hızı';it = 'Fatturato a debito per il periodo';de = 'Umsatz Soll für den Zeitraum'");
		
	ElsIf TotalsType = TotalsTypes.TurnoverCr Then
		
		Result = NStr("en = 'Turnover Cr for the period'; ru = 'Оборот Кт за период';pl = 'Obrót Cr za okres';es_ES = 'Facturación de crédito por el período';es_CO = 'Facturación de crédito por el período';tr = 'Dönem alacak devir hızı';it = 'Fatturato a credito per il periodo';de = 'Umsatz Haben für den Zeitraum'");
		
	EndIf;
	
	Return Result;
	
EndFunction

Function SimpleIndicatorValue(Parameters, Indicator = Undefined)
	
	ItemsTypes = Parameters.ItemsTypes;
	ReportItem = Indicator;
	If ReportItem = Undefined Then
		ReportItem = Parameters.Indicator;
	EndIf;
	ReportPeriod = Parameters.ReportPeriod;
	ReportIntervals = Parameters.ReportIntervals.Copy();
	ReportIntervals.FillValues(ReportItem.ReportItem,	"Indicator");
	ReportIntervals.FillValues(ReportItem.RowCode,		"RowCode");
	ReportIntervals.FillValues(ReportItem.Note,			"Note");
	Dimensions = Parameters.Dimensions;
	IndicatorValue = IndicatorEmptyValue(ReportIntervals, Dimensions);
	AnalyticalDimension = Parameters.AnalyticalDimension;
	Resource = Parameters.Resource;
	
	UserDefinedFixed = ItemsTypes.UserDefinedFixedIndicator;
	AccountingData = ItemsTypes.AccountingDataIndicator;
	
	IndicatorSchema = Catalogs.FinancialReportsItems.IndicatorSchema(ReportItem, Dimensions, AnalyticalDimension, Resource);
	Settings = IndicatorSchema.Settings;
	If ReportItem.ItemType = AccountingData And Not ValueIsFilled(ReportItem.Account) Then
		TextPattern = NStr("en = '%1 (%2) indicator
							|value is not defined.
							|report type: %3
							|reason: account is not specified.'; 
							|ru = '%1 (%2) значение индикатора 
							|не определено.
							|тип отчета: %3
							|причина: счет не указан.';
							|pl = '%1 (%2) wartość wskaźnika
							| nie jest zdefiniowana.
							|typ raportu: %3
							|przyczyna: nie określono konta.';
							|es_ES = '%1 (%2) No se ha definido
							|el valor del indicador.
							|tipo de informe: %3
							|motivo: No se ha especificado la cuenta.';
							|es_CO = '%1 (%2) No se ha definido
							|el valor del indicador.
							|tipo de informe: %3
							|motivo: No se ha especificado la cuenta.';
							|tr = '%1 (%2) gösterge
							|değeri tanımlanmamış. 
							| rapor tipi: %3
							|sebebi: hesap belirtilmemiş.';
							|it = 'Il valore dell''indicatore %1 (%2)
							|non è definito.
							|tipo di report: %3
							|motivo: il conto non è specificato.';
							|de = '%1 (%2) Indikator
							|wert ist nicht definiert.
							|Berichtstyp: %3
							|Grund: Konto ist nicht angegeben.'");
		Text = StringFunctionsClientServer.SubstituteParametersToString(
			TextPattern, 
			ReportItem.DescriptionForPrinting, 
			ReportItem.Code,
			ReportItem.ReportType);
		CommonClientServer.MessageToUser(Text, ReportItem.ReportItem);
		AddErrorMessage(Parameters.MessagesAboutErrors, Text, ReportItem.ReportItem);
		Parameters.Insert("CalculationError");
	EndIf;
	
	For Each FilterItem In Parameters.ReportFilter Do
		If ValueIsFilled(FilterItem.Value) Then
			If ReportItem.ItemType = AccountingData
				Or (ReportItem.ItemType = UserDefinedFixed
					And StrFind(FilterItem.Key, "AnalyticalDimension") = 0
					And StrFind(FilterItem.Key, "LineOfBusiness") = 0) Then
				
				NewFilter = NewFilter(Settings.Filter, FilterItem.Key, FilterItem.Value);
				If TypeOf(NewFilter.RightValue) = Type("Array") Then
					NewFilter.ComparisonType = DataCompositionComparisonType.InList;
				EndIf;
				
			EndIf;
		EndIf;
	EndDo;
	
	AddPeriodicitySetting(Settings, ReportPeriod);
	
	IndicatorData = UnloadDataCompositionResult(IndicatorSchema.Schema, Settings, New Structure("ReportIntervals", ReportIntervals));
	
	If IndicatorData.Count() > 0 Then
		IndicatorValue.Clear();
		LoadToValueTable(IndicatorData, IndicatorValue);
	EndIf;
	
	Return IndicatorValue;
	
EndFunction

Function ReportTypeReportsSet(ReportType)
	
	Result = Catalogs.FinancialReportsSets.EmptyRef();
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	FinancialReportsSetsReportsTypes.Ref AS Ref
	|FROM
	|	Catalog.FinancialReportsSets.ReportsTypes AS FinancialReportsSetsReportsTypes
	|WHERE
	|	FinancialReportsSetsReportsTypes.FinancialReportType = &FinancialReportType
	|
	|ORDER BY
	|	Ref";
	
	Query.SetParameter("FinancialReportType", ReportType);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Result = Selection.Ref;
	EndIf;
	
	Return Result;
	
EndFunction

Procedure AddReportBlockDescription(Parameters, ReportItem, ItemData)
	
	BlockDescription = New Structure("ItemType, OutputItemTitle, DescriptionForPrinting, ReportItem");
	ItemsTypes = Parameters.ItemsTypes;
	
	FillPropertyValues(BlockDescription, ReportItem);
	BlockDescription.Insert("Description", ItemData);
	
	Parameters.ReportBlocks.Add(BlockDescription);
	
EndProcedure

Function RefDescription(SourceString)
	
	Return StrReplace(Title(String(SourceString)), " ", "");
	
EndFunction

Function PrepareTableData(TableTree, Parameters)
	
	IsComplex = TableTree.ItemType = Parameters.ItemsTypes.TableComplex;
	TableIndicatorsInColumns = TableTree.ItemType = Parameters.ItemsTypes.TableIndicatorsInColumns;
	TableDescription = TableDescription(IsComplex, TableIndicatorsInColumns);
	TableDescription.Insert("ItemsTypes", Parameters.ItemsTypes);
	
	HorizontalTotalsTree = TableDescription.ColumnsTree.Copy();
	FillTableDescription(TableTree, TableDescription, Parameters);
	
	IndicatorsValues = TableDescription.IndicatorsValues;
	For Each Dimension In TableDescription.RowsDimensions Do
		IndicatorsValues.Columns.Add(Dimension);
	EndDo;
	If IsComplex Then
		IndicatorsValues.Columns.Add("TableRow");
	EndIf;
	If TableIndicatorsInColumns Then
		IndicatorsValues.Columns.Add("StartDate");
		IndicatorsValues.Columns.Add("EndDate");
	EndIf;
	
	IndicatorsSelection = TableIndicatorsValues(Parameters, TableDescription);
	GenerateHorizontalTotalsTree(TableDescription.ColumnsTree, IndicatorsSelection, TableDescription, HorizontalTotalsTree);
	DefineHorizontalTotalsOperandsSet(HorizontalTotalsTree, TableDescription);
	
	For Each Indicator In TableDescription.Indicators Do
		
		TableDescription.CurrentIndicator = Indicator.Value.Description;
		If TableDescription.IsComplex Then
			TableDescription.IndicatorRow = Indicator.Value.Row;
			TableDescription.IndicatorColumn = Indicator.Value.Column;
		EndIf;
		Filter = New Structure("Indicator", Indicator.Key);
		IndicatorValue = IndicatorsSelection.Copy(Filter);
		
		// Suppliment indicator's table with rows grouping columns
		If IsComplex Then
			VerticalGroupings = TableDescription.VerticalGroupings[Indicator.Value.Row];
		Else
			VerticalGroupings = TableDescription.VerticalGroupings[Indicator.Value.Description.ReportItem];
		EndIf;
		
		If TableIndicatorsInColumns Then
			LoadIndicatorValuesToColumn(IndicatorValue, TableDescription);
		Else
			LoadIndicatorValuesToRow(IndicatorValue, VerticalGroupings, TableDescription);
		EndIf;
		
	EndDo;
	
	If TableIndicatorsInColumns Then
		CalculateHorizontalTotals(TableDescription);
	EndIf;
	
	// Rows totals calculation
	VerticalTotalsTree = TableDescription.RowsTree.Copy();
	VerticalTotalsTree.Rows.Clear();
	NumberType = Common.TypeDescriptionNumber(15, 2);
	For Each Name In TableDescription.Resources Do
		VerticalTotalsTree.Columns.Add(Name, NumberType);
	EndDo;
	GenerateVerticalTotalsTree(TableDescription.RowsTree, TableDescription, VerticalTotalsTree);
	TableDescription.Insert("RowsTree", VerticalTotalsTree);
	
	// Returning only the necessary
	DataForPrinting = TableForPrintingData();
	FillPropertyValues(DataForPrinting, TableDescription);
	Return DataForPrinting;
	
EndFunction

Function ReportIndicatorValue(Parameters, Indicator = Undefined)
	
	ItemsTypes = Parameters.ItemsTypes;
	ReportItem = Indicator;
	
	If ReportItem = Undefined Then
		ReportItem = Parameters.Indicator;
	EndIf;
	
	If ReportItem.ItemType = ItemsTypes.AccountingDataIndicator 
		Or ReportItem.ItemType = ItemsTypes.UserDefinedFixedIndicator Then
		
		Result = SimpleIndicatorValue(Parameters, Indicator);
		
	ElsIf ReportItem.ItemType = ItemsTypes.UserDefinedCalculatedIndicator Then
		
		Result = CalculatedIndicatorValue(Parameters, Indicator);
		
	ElsIf ReportItem.ItemType = ItemsTypes.GroupTotal And ReportItem.IsLinked Then
		
		Result = GroupTotalValue(Parameters, Indicator);
		
	EndIf;
	
	Return Result;
	
EndFunction

Function RowTemplate(LayoutTemplate, AreaName)
	
	RowTemplate = New Structure;
	RowTemplate.Insert("Indicator",	LayoutTemplate.GetArea(AreaName + "|Indicator"));
	RowTemplate.Insert("RowCode",	LayoutTemplate.GetArea(AreaName + "|RowCode"));
	RowTemplate.Insert("Note",		LayoutTemplate.GetArea(AreaName + "|Note"));
	RowTemplate.Insert("Value",		LayoutTemplate.GetArea(AreaName + "|Value"));
	Return RowTemplate;
	
EndFunction

Procedure MergeHorizontally(Document, LeftColumnNumber, Val CellsCount, RowNumber, AreaText = "", Center = False)
	
	If CellsCount <= 1 Then
		Return;
	EndIf;
	
	Area = Document.Area(RowNumber, LeftColumnNumber, RowNumber, LeftColumnNumber + CellsCount - 1);
	Area.Merge();
	If Not IsBlankString(AreaText) Then
		Area.Text = AreaText;
	EndIf;
	If Center Then
		Area.HorizontalAlign = HorizontalAlign.Center;
		Area.VerticalAlign = VerticalAlign.Center;
	EndIf;
	
EndProcedure

Procedure OutputTableHeader(Parameters, OutputItem, ResultDocument)
	
	OutputTemplate = Parameters.OutputTemplate.Header;
	ItemsCorrespondenceByLevels = New Map;
	TableHeader = OutputItem.Description.TableHeader;
	HeaderLevelsCount = OutputItem.Description.HeaderLevelsCount + 1;
	DistributeItemsByLevels(TableHeader.Rows, HeaderLevelsCount, ItemsCorrespondenceByLevels);
	
	HeaderFirstRow = Undefined;
	ChildItemsCount = 0;
	
	For i = 1 To HeaderLevelsCount Do
		
		OutputArea = ResultDocument.Put(OutputTemplate.Indicator, 0);
		
		If HeaderFirstRow = Undefined Then
			HeaderFirstRow = OutputArea.Top;
		EndIf;
		If Parameters.OutputRowCode Then
			ResultDocument.Join(OutputTemplate.RowCode);
		EndIf;
		If Parameters.OutputNote Then
			ResultDocument.Join(OutputTemplate.Note);
		EndIf;
		
		If ItemsCorrespondenceByLevels.Count() Then // checking if columns values exist
			
			CurrentLevelItems = ItemsCorrespondenceByLevels[i];
			For Each CurrentLevelItem In CurrentLevelItems Do
				Section = OutputTemplate.Value;
				
				If CurrentLevelItem = Undefined
					Or Not ValueIsFilled(CurrentLevelItem.DescriptionForPrinting) Then
					
					Section.Parameters.Description = "";
					
				ElsIf Not CurrentLevelItem.OutputItemTitle Then
					
					Continue;
					
				ElsIf ValueIsFilled(CurrentLevelItem.DescriptionForPrinting) Then
					
					Section.Parameters.Description = CurrentLevelItem.DescriptionForPrinting;
					
				EndIf;
				
				OutputArea = ResultDocument.Join(Section);
				If CurrentLevelItem = Undefined Then
					Area = ResultDocument.Area(OutputArea.Top - 1, OutputArea.Left, OutputArea.Top, OutputArea.Left);
					Area.Merge();
					Continue;
				EndIf;
				ChildItemsCount = CurrentLevelItem.ChildItemsCount;
				If ChildItemsCount > 1 Then
					For SectionNumber = 1 To ChildItemsCount - 1 Do
						ResultDocument.Join(Section);
					EndDo;
					MergeHorizontally(ResultDocument, OutputArea.Left, ChildItemsCount, OutputArea.Top);
				EndIf;
			EndDo;
			
		EndIf;
		
	EndDo;
	
	HeaderFirstColumn = 1;
	MergeVertically(ResultDocument, HeaderFirstRow, HeaderLevelsCount, HeaderFirstColumn);
	If Parameters.OutputRowCode Then
		HeaderFirstColumn = HeaderFirstColumn + 1;
		MergeVertically(ResultDocument, HeaderFirstRow, HeaderLevelsCount, HeaderFirstColumn, NStr("en = 'Row code'; ru = 'Код строки';pl = 'Kod wiersza';es_ES = 'Código de fila';es_CO = 'Código de fila';tr = 'Satır kodu';it = 'Codice Riga';de = 'Zeilen-Code'"), True);
	EndIf;
	If Parameters.OutputNote Then
		HeaderFirstColumn = HeaderFirstColumn + 1;
		MergeVertically(ResultDocument, HeaderFirstRow, HeaderLevelsCount, HeaderFirstColumn, NStr("en = 'Note'; ru = 'Примечание';pl = 'Uwagi';es_ES = 'Nota';es_CO = 'Nota';tr = 'Not';it = 'Nota';de = 'Hinweis'"), True);
	EndIf;
	
EndProcedure

Procedure OutputTableRow(TableRowData, ResultDocument, TableDescription, Parameters, Level = 0)
	
	If TableRowData.OutputItemTitle Then
		OutputRowCells(TableRowData, ResultDocument, TableDescription, Parameters, Level);
	Else
		Level = Level - 1;
	EndIf;

	For Each TableRow In TableRowData.Rows Do
		OutputTableRow(TableRow, ResultDocument, TableDescription, Parameters, Level + 1);
	EndDo;
	
	If TableRowData.ItemType = Parameters.ItemsTypes.Group Then
		Parameters.Filter.Delete(TableRowData.ItemID);
	EndIf;
	
EndProcedure

Function NewIndicatorObtainingParameters()
	
	Result = New Structure;
	Result.Insert("Indicator");
	Result.Insert("Resource", "Amount");
	Result.Insert("ReportPeriod", ReportPeriod());
	Result.Insert("ReportIntervals");
	Result.Insert("ReportFilter", New ValueList);
	Result.Insert("AnalyticalDimension");
	Result.Insert("Dimensions", New ValueList);
	Result.Insert("MessagesAboutErrors");
	
	Return Result;
	
EndFunction

Procedure GenerateVerticalTotalsTree(RowsTree, TableDescription, ReportRow, Filter = Undefined)
	
	If Not ValueIsFilled(Filter) Then
		Filter = New Structure;
		Data = TableDescription.IndicatorsValues.Copy();
	Else
		Data = TableDescription.IndicatorsValues.Copy(Filter);
	EndIf;
	
	ItemsTypes = TableDescription.ItemsTypes;
	PeriodPresentationDescription = Enums.PeriodPresentation.Description;
	For Each Row In RowsTree.Rows Do
		If Row.ItemType = ItemsTypes.Group Then
			
			ReportNewRow = ReportRow.Rows.Add();
			FillPropertyValues(ReportNewRow, Row);
			GenerateVerticalTotalsTree(Row, TableDescription, ReportNewRow, Filter);
			CalculateVerticalTotals(ReportNewRow, TableDescription);
			
		ElsIf Row.ItemType = ItemsTypes.GroupTotal And Row.OutputItemTitle And Not Row.IsLinked Then
			
			ReportNewRow = ReportRow.Rows.Add();
			FillPropertyValues(ReportNewRow, Row);
			
		ElsIf Row.ItemType = ItemsTypes.Dimension Then
			
			If Row.Rows.Count() Then
				Data.GroupBy(Row.ColumnName);
				If ValueIsFilled(Row.Sort) Then
					Data.Sort(Row.ColumnName + " " + Row.Sort);
				EndIf;
			EndIf;
			
			For Each DataRow In Data Do
				
				DimensionValue = DataRow[Row.ColumnName];
				ReportNewRow = ReportRow.Rows.Add();
				FillPropertyValues(ReportNewRow, Row);
				FillPropertyValues(ReportNewRow, DataRow);
				ReportNewRow.GroupingValue = DimensionValue;
				If Row.PeriodPresentation = PeriodPresentationDescription Then
					ReportNewRow.DescriptionForPrinting = IntervalPresentation(DimensionValue,Row.Periodicity);
				Else
					ReportNewRow.DescriptionForPrinting = Format(DimensionValue, "DLF=DD");
				EndIf;
				If Row.Rows.Count() Then
					Filter.Insert(Row.ColumnName, DimensionValue);
					GenerateVerticalTotalsTree(Row, TableDescription, ReportNewRow, Filter);
					CalculateVerticalTotals(ReportNewRow, TableDescription);
					Filter.Delete(Row.ColumnName);
				EndIf;
				
			EndDo;
			
			If Row.Level() = 0 Then
				If Not ValueIsFilled(Filter) Then
					Data = TableDescription.IndicatorsValues.Copy();
				Else
					Data = TableDescription.IndicatorsValues.Copy(Filter);
				EndIf;
			EndIf;
			
		Else
			
			ReportNewRow = ReportRow.Rows.Add();
			FillPropertyValues(ReportNewRow, Row);
			FillTableResources(ReportNewRow, Data, TableDescription);
			
		EndIf;
	EndDo;
	
EndProcedure

Function IndicatorEmptyValue(ReportIntervals, Dimensions = Undefined)
	
	DimensionsTypes = New Map;
	DimensionsTypes.Insert("Company", New TypeDescription("CatalogRef.Companies"));
	DimensionsTypes.Insert("BusinessUnit", New TypeDescription("CatalogRef.BusinessUnits"));
	DimensionsTypes.Insert("LineOfBusiness", New TypeDescription("CatalogRef.LinesOfBusiness"));
	
	Result = ReportIntervals.Copy();
	Result.Columns.Add("Value", Common.TypeDescriptionNumber(15, 2));
	For Each Dimension In Dimensions Do
		Result.Columns.Add(Dimension.Value, DimensionsTypes[Dimension.Value], Dimension.Presentation);
		If Dimension.Value = "AnalyticalDimension1" Then
			Result.Columns.Add("AnalyticalDimensionType", , "AnalyticalDimensionType");
		EndIf;
	EndDo;
	Return Result;
	
EndFunction

Procedure AddErrorMessage(MessagesArray, MessageToUserText, DataKey = Undefined)
	
	Message = New UserMessage;
	Message.Text = MessageToUserText;
	Message.DataKey = DataKey;
	
	MessagesArray.Add(Message);
	
EndProcedure

Procedure AddPeriodicitySetting(Settings, ReportPeriod)
	
	For Each Period In ReportPeriod.Periodicity Do
		NewSelectionField(Settings, Period.ColumnName, Period.Presentation);
		NewOrder(Settings, Period.ColumnName, Period.Sort);
	EndDo;
	
EndProcedure

Function NewOrder(ComposerSettings, FieldName = "", Sort = "ASC")
	
	If TypeOf(ComposerSettings) = Type("DataCompositionSettingsComposer") Then
		DCSettings = ComposerSettings.Settings;
	Else
		DCSettings = ComposerSettings;
	EndIf;
	
	NewOrder = DCSettings.Order.Items.Add(Type("DataCompositionOrderItem"));
	NewOrder.Use = True;
	If Not IsBlankString(FieldName) Then
		NewOrder.Field = New DataCompositionField(FieldName);
	EndIf;
	NewOrder.OrderType = DataCompositionSortDirection[Sort];
	
	Return NewOrder;
	
EndFunction

Procedure LoadToValueTable(SourceTable, RecipientTable)
	
	CommonClientServer.SupplementTable(SourceTable, RecipientTable);
	
EndProcedure

Function TableDescription(IsComplex = False, TableIndicatorsInColumns = False)
	
	DateType = New TypeDescription("Date", , , New DateQualifiers(DateFractions.DateTime));
	StringType = New TypeDescription("String", , New StringQualifiers(0));
	NumberType = Common.TypeDescriptionNumber(15, 2);
	BooleanType = New TypeDescription("Boolean");
	ItemsRefType = New TypeDescription("CatalogRef.FinancialReportsItems");
	
	TableDescription = New Structure;
	TableDescription.Insert("IsComplex", IsComplex);
	TableDescription.Insert("TableIndicatorsInColumns", TableIndicatorsInColumns);
	TableDescription.Insert("Indicators", New Map);
	TableDescription.Insert("Periodicity", New Array);
	TableDescription.Insert("ResourcesString", Undefined);
	
	// Rows tree and Columns tree common columns
	RowsTree = New ValueTree;
	RowsTree.Columns.Add("ItemType");
	RowsTree.Columns.Add("ItemID");
	RowsTree.Columns.Add("ReportItem");
	RowsTree.Columns.Add("DescriptionForPrinting");
	RowsTree.Columns.Add("OutputItemTitle", BooleanType);
	RowsTree.Columns.Add("MarkItem", BooleanType);
	RowsTree.Columns.Add("TotalPosition");
	RowsTree.Columns.Add("ReverseSign", BooleanType);
	RowsTree.Columns.Add("PeriodPresentation");
	RowsTree.Columns.Add("Periodicity");
	RowsTree.Columns.Add("ColumnName");
	RowsTree.Columns.Add("Sort");
	
	// Additional Columns tree columns
	ColumnsTree = RowsTree.Copy();
	ColumnsTree.Columns.Add("Operands");
	ColumnsTree.Columns.Add("ChildItemsCount", NumberType);
	ColumnsTree.Columns.Add("IndicatorValue");
	ColumnsTree.Columns.Add("Description");
	
	// Additional Rows tree columns
	RowsTree.Columns.Add("RowCode");
	RowsTree.Columns.Add("Note");
	RowsTree.Columns.Add("IsLinked", BooleanType);
	RowsTree.Columns.Add("GroupingValue");
	
	IndicatorsValues = New ValueTable;
	IndicatorsValues.Columns.Add("ReportItem", ItemsRefType);
	IndicatorsValues.Columns.Add("DescriptionForPrinting", StringType);
	IndicatorsValues.Columns.Add("RowCode", StringType);
	IndicatorsValues.Columns.Add("Note", StringType);
	
	ColumnsDescription = New ValueTable;
	ColumnsDescription.Columns.Add("ColumnName", StringType);
	ColumnsDescription.Columns.Add("ItemType");
	ColumnsDescription.Columns.Add("ReportItem", ItemsRefType);
	ColumnsDescription.Columns.Add("DescriptionForPrinting", StringType);
	ColumnsDescription.Columns.Add("ReverseSign", BooleanType);
	ColumnsDescription.Columns.Add("Operands");
	ColumnsDescription.Columns.Add("Filter");
	ColumnsDescription.Columns.Add("TotalLevel", NumberType);
	ColumnsDescription.Columns.Add("IsTotal", BooleanType);
	
	TableDescription.Insert("IndicatorsValues", IndicatorsValues);
	TableDescription.Insert("TableHeader", Undefined);
	TableDescription.Insert("HeaderLevelsCount", 0);
	TableDescription.Insert("ColumnsLevelsTotalNumber", 0);
	TableDescription.Insert("ColumnNumber", 1);
	TableDescription.Insert("Resources", New Array);
	TableDescription.Insert("Details", New Map);
	
	TableDescription.Insert("ColumnsTree", ColumnsTree);
	TableDescription.Insert("RowsTree", RowsTree);
	
	TableDescription.Insert("CurrentLevel", Undefined);
	TableDescription.Insert("CurrentParent", Undefined);
	TableDescription.Insert("CurrentIndicator", Undefined);
	
	TableDescription.Insert("ReportColumns", ColumnsDescription);
	TableDescription.Insert("VerticalGroupings", New Map);
	
	TableDescription.Insert("RegisterDimensions", New Array);
	TableDescription.Insert("TableDimensions", New Array);
	TableDescription.Insert("RowsDimensions", New Array);
	TableDescription.Insert("CurrentGroupings", New Structure);
	
	If IsComplex Then
		TableDescription.Insert("IndicatorRow", Undefined);
		TableDescription.Insert("IndicatorColumn" , Undefined);
	EndIf;
	
	Return TableDescription;
	
EndFunction

Procedure FillTableDescription(TableTree, TableItems, Parameters, IsColumns = False)
	
	IsLinkedGroup = False;
	ItemsTypes = Parameters.ItemsTypes;
	For Each Item In TableTree.Rows Do
		
		IsIndicator = IsIndicator(Item.ItemType, ItemsTypes, Item.IsLinked);
		ItemID = ItemID(Item) + Parameters.AdditionalSuffix;
		
		If Item.ItemType = ItemsTypes.Dimension Then
			
			AddDimensionTableItem(TableItems, Item, Parameters.AdditionalSuffix, IsColumns);
			
		ElsIf Item.ItemType = ItemsTypes.Group Then
			
			If Item.IsLinked Then// receiving original tree by ref
				LinkedTree = RefreshReportTree(Item.LinkedItem.Owner, Item.LinkedItem);
				If LinkedTree.Rows.Count() > 0 Then
					GroupDescription = LinkedTree.Rows[0];
					Parameters.AdditionalSuffix = Parameters.AdditionalSuffix + "X";
					// Infinite loop rough control
					If GroupDescription.ReportType = Parameters.ReportType Then
						Continue;
					EndIf;
					Item = GroupDescription;
					IsLinkedGroup = True;
					ItemID = ItemID(Item) + Parameters.AdditionalSuffix;
				Else
					Continue;
				EndIf;
			EndIf;
			
			AddToOutputTree(TableItems, Item, ItemID);
			TableItems.CurrentGroupings.Insert(ItemID, Item.ReportItem);
			
		ElsIf IsIndicator Then
			
			TableItems.Indicators.Insert(Item.ReportItem, New Structure("Description", Item));
			If Not IsColumns Then
				Parents = CommonClientServer.CopyStructure(TableItems.CurrentGroupings);
				TableItems.VerticalGroupings.Insert(Item.ReportItem, Parents);
			EndIf;
			
			AddToOutputTree(TableItems, Item, ItemID);
			
		ElsIf Item.ItemType = ItemsTypes.GroupTotal And Not Item.IsLinked Then
			
			TotalID = "Total" + ItemID(Item.Parent) + Parameters.AdditionalSuffix;
			AddToOutputTree(TableItems, Item, TotalID, , TableTree.Rows.IndexOf(Item));
			
		ElsIf Item.ItemType = ItemsTypes.TableItem Then
			
			If Not IsColumns Then
				Parents = CommonClientServer.CopyStructure(TableItems.CurrentGroupings);
				TableItems.VerticalGroupings.Insert(Item.ReportItem, Parents);
			EndIf;
			AddToOutputTree(TableItems, Item, ItemID);
			
		ElsIf Item.ItemType = ItemsTypes.Columns Then
			
			IsColumns = True;
			TableItems.CurrentLevel = TableItems.ColumnsTree.Rows;
			
		ElsIf Item.ItemType = ItemsTypes.Rows Then
			
			IsColumns = False;
			TableItems.CurrentLevel = TableItems.RowsTree.Rows;
			
		ElsIf Item.ItemType = Parameters.ItemsTypes.ConfigureCells Then
			
			ComplexTableIndicators(Item, TableItems, Parameters, IsColumns);
			
		EndIf;
		
		If Not IsIndicator And Item.ItemType <> ItemsTypes.ConfigureCells Then
			FillTableDescription(Item, TableItems, Parameters, IsColumns);
		EndIf;
		
		If Item.ItemType = ItemsTypes.Group And IsLinkedGroup Then
			Parameters.AdditionalSuffix = Left(Parameters.AdditionalSuffix, StrLen(Parameters.AdditionalSuffix) - 1);
		EndIf;
		
		If Item.ItemType = ItemsTypes.Dimension Or Item.ItemType = ItemsTypes.Group Then
			TableItems.CurrentGroupings.Delete(ItemID);
		EndIf;
		
		If ValueIsFilled(TableItems.CurrentParent) Then
			Parent = TableItems.CurrentParent.Parent;
			TableItems.CurrentParent = Parent;
			If Parent = Undefined And IsColumns Then
				CurrentLevel = TableItems.ColumnsTree.Rows;
			ElsIf Parent = Undefined And Not IsColumns Then
				CurrentLevel = TableItems.RowsTree.Rows;
			Else
				CurrentLevel = Parent.Rows;
			EndIf;
			TableItems.CurrentLevel = CurrentLevel;
		EndIf;
		
	EndDo;
	
EndProcedure

Function TableIndicatorsValues(Parameters, TableDescription)
	
	IndicatorsValues = TableDescription.IndicatorsValues;
	IndicatorParameters = IndicatorObtainingParameters(Parameters, TableDescription);
	IndicatorsSelection = Undefined;
	For Each Indicator In TableDescription.Indicators Do
		
		IndicatorParameters.Indicator = Indicator.Value.Description;
		IndicatorValue = ReportIndicatorValue(IndicatorParameters);
		If IndicatorParameters.Property("CalculationError") Then
			IndicatorParameters.Delete("CalculationError");
		EndIf;
		
		If IndicatorsSelection = Undefined Then
			IndicatorsSelection = IndicatorValue.Copy();
		EndIf;
		
		// Supplimenting the indicator table with row groupping columns
		If TableDescription.IsComplex Then
			VerticalGroupings = TableDescription.VerticalGroupings[Indicator.Value.Row];
		Else
			VerticalGroupings = TableDescription.VerticalGroupings[Indicator.Value.Description.ReportItem];
		EndIf;
		
		If ValueIsFilled(VerticalGroupings) Then
			For Each Grouping In VerticalGroupings Do
				If IndicatorsValues.Columns.Find(Grouping.Key) = Undefined Then
					IndicatorsValues.Columns.Add(Grouping.Key);
					IndicatorsSelection.Columns.Add(Grouping.Key);
				EndIf;
			EndDo;
		EndIf;
		
		CommonClientServer.SupplementTable(IndicatorValue, IndicatorsSelection);
		
	EndDo;
	
	If IndicatorsSelection = Undefined Then
		Raise NStr("en = 'The structure of the report is wrong. Please review it.'; ru = 'Неправильная структура отчета. Проанализируйте структуру.';pl = 'Struktura raportu jest nieprawidłowa. Sprawdź go.';es_ES = 'La estructura del informe es errónea. Por favor, revíselo.';es_CO = 'La estructura del informe es errónea. Por favor, revíselo.';tr = 'Raporun yapısı yanlış. Lütfen onu gözden geçirin.';it = 'La struttura del report è errata. Ricontrollarla.';de = 'Die Struktur des Berichts ist falsch. Bitte überprüfen Sie sie.'");
	EndIf;
	
	ColumnsNames = "";
	For Each Column In IndicatorsSelection.Columns Do
		ColumnsNames = ColumnsNames + Column.Name + ",";
	EndDo;
	StringFunctionsClientServer.DeleteLastCharInString(ColumnsNames, 1);
	IndicatorsSelection.GroupBy(ColumnsNames);
	
	SortString = "";
	For Each Period In Parameters.ReportPeriod.Periodicity Do
		If ValueIsFilled(Period.Periodicity) Then
			SortString = SortString + ?(IsBlankString(SortString), "", ",")
			+ Period.ColumnName + " " + Period.Sort;
		EndIf;
	EndDo;
	If SortString <> "" Then
		IndicatorsSelection.Sort(SortString);
	EndIf;
	
	Return IndicatorsSelection;
	
EndFunction

Procedure GenerateHorizontalTotalsTree(ColumnsTree, ValuesSelection, TableDescription, ReportColumn,
										Filter = Undefined, Val GroupingColumns = "")
	
	If Not ValueIsFilled(Filter) Then
		Filter = New Structure;
		TableDescription.ColumnNumber = 1;
		Data = ValuesSelection.Copy();
	Else
		Data = ValuesSelection.Copy(Filter);
	EndIf;
	
	ItemsTypes = TableDescription.ItemsTypes;
	IndicatorsValues = TableDescription.IndicatorsValues;
	PeriodPresentationDescription = Enums.PeriodPresentation.Description;
	For Each Column In ColumnsTree.Rows Do
		
		If Column.ItemType = ItemsTypes.Group Then
			NewReportColumn = ReportColumn.Rows.Add();
			FillPropertyValues(NewReportColumn, Column);
			GenerateHorizontalTotalsTree(Column, ValuesSelection, TableDescription, NewReportColumn, Filter, GroupingColumns);
			If NewReportColumn <> ReportColumn And TypeOf(ReportColumn) = Type("ValueTreeRow") Then
				ReportColumn.ChildItemsCount = ReportColumn.ChildItemsCount + NewReportColumn.ChildItemsCount;
			EndIf;
			
		ElsIf Column.ItemType = ItemsTypes.GroupTotal And Column.OutputItemTitle Then
			If TypeOf(ReportColumn) = Type("ValueTreeRow") Then
				ReportColumn.ChildItemsCount = ReportColumn.ChildItemsCount + 1;
			EndIf;
			NewReportColumn = ReportColumn.Rows.Add();
			FillPropertyValues(NewReportColumn, Column);
			ColumnName = Column.ItemID + "_" + String(TableDescription.ColumnNumber);
			AddTableColumn(ColumnName, NewReportColumn, Filter, TableDescription, True);
			
		ElsIf Column.ItemType = ItemsTypes.Dimension Then
			GroupingColumns = GroupingColumns + ?(IsBlankString(GroupingColumns), "", ",") + Column.ColumnName;
			Data.GroupBy(GroupingColumns);
			For Each ColumnData In Data Do
				
				DimensionValue = ColumnData[Column.ColumnName];
				NewReportColumn = ReportColumn.Rows.Add();
				FillPropertyValues(NewReportColumn, Column);
				If Column.PeriodPresentation = PeriodPresentationDescription Then
					NewReportColumn.DescriptionForPrinting = IntervalPresentation(DimensionValue,Column.Periodicity);
				Else
					NewReportColumn.DescriptionForPrinting = Format(DimensionValue, "DLF=DD");
				EndIf;
				If Column.Rows.Count() Then
					Filter.Insert(Column.ColumnName, DimensionValue);
					GenerateHorizontalTotalsTree(Column, ValuesSelection, TableDescription, NewReportColumn, Filter, GroupingColumns);
					If TypeOf(ReportColumn) = Type("ValueTreeRow") Then
						ReportColumn.ChildItemsCount = ReportColumn.ChildItemsCount + NewReportColumn.ChildItemsCount;
					EndIf;
					Filter.Delete(Column.ColumnName);
					
				Else
					If TypeOf(ReportColumn) = Type("ValueTreeRow") Then
						ReportColumn.ChildItemsCount = ReportColumn.ChildItemsCount + 1;
					EndIf;
					ColumnName = Column.ColumnName + String(TableDescription.ColumnNumber);
					Filter.Insert(Column.ColumnName, DimensionValue);
					AddTableColumn(ColumnName, NewReportColumn, Filter, TableDescription);
					Filter.Delete(Column.ColumnName);
					
				EndIf;
				
			EndDo;
			
		Else
			NewReportColumn = ReportColumn.Rows.Add();
			FillPropertyValues(NewReportColumn, Column);
			If TypeOf(ReportColumn) = Type("ValueTreeRow") Then
				ReportColumn.ChildItemsCount = ReportColumn.ChildItemsCount + 1;
			EndIf;
			ColumnName = Column.ItemID + "_" + String(TableDescription.ColumnNumber);
			AddTableColumn(ColumnName, NewReportColumn, Filter, TableDescription);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure DefineHorizontalTotalsOperandsSet(TotalsTree, TableDescription)
	
	Filter = New Structure("TotalLevel", -2);
	DetailedColumns = TableDescription.ReportColumns.FindRows(Filter);
	GroupTotal = TableDescription.ItemsTypes.GroupTotal;
	
	For Each Column In DetailedColumns Do
		AddTotalOperand(Column.ColumnName, TotalsTree, TableDescription);
	EndDo;
	
	TotalLevel = TableDescription.ColumnsLevelsTotalNumber;
	For i = 0 To TableDescription.ColumnsLevelsTotalNumber Do
		
		Filter.TotalLevel = TotalLevel;
		TotalsColumns = TableDescription.ReportColumns.FindRows(Filter);
		For Each Column In TotalsColumns Do
			AddTotalOperand(Column.ColumnName, TotalsTree, TableDescription);
		EndDo;
		TotalLevel = TotalLevel - 1;
		
	EndDo;
	
	TableHeader = TotalsTree.Copy();
	TableHeader.Rows.Clear();
	GenerateTableHeader(TotalsTree, TableHeader, TableDescription.HeaderLevelsCount);
	TableDescription.Insert("TableHeader", TableHeader);
	
EndProcedure

Procedure LoadIndicatorValuesToColumn(IndicatorSelection, TableDescription)
	
	Column = TableDescription.ReportColumns.Find(TableDescription.CurrentIndicator.ReportItem, "ReportItem");
	If Column = Undefined Then
		Return;
	EndIf;
	
	If TableDescription.ResourcesString = Undefined Then
		TableDescription.ResourcesString = StrConcat(TableDescription.Resources, ",");
	EndIf;
	
	IndicatorValues = TableDescription.IndicatorsValues.CopyColumns();
	FillDetails = False;
	ValuesPeriods = New Map;
	For Each Cell In IndicatorSelection Do
		Period = New Structure("StartDate, EndDate", Cell.StartDate, Cell.EndDate);
		ValuesPeriods.Insert(Column.ColumnName, Period);
		
		NewValuesRow = IndicatorValues.Add();
		FillPropertyValues(NewValuesRow, Cell);
		FillPropertyValues(NewValuesRow, TableDescription.CurrentIndicator);
		NewValuesRow[Column.ColumnName] = Cell.Value;
		For Each Dimension In TableDescription.RowsDimensions Do
			ReportRowID = Cell[Dimension];
			FillCellDetails(ReportRowID, Column, TableDescription, ValuesPeriods);
		EndDo;
	EndDo;
	Grouping = "StartDate, EndDate";
	For Each Dimension In TableDescription.TableDimensions Do
		Grouping = Grouping + "," + Dimension;
	EndDo;
	LoadToValueTable(IndicatorValues, TableDescription.IndicatorsValues);
	TableDescription.IndicatorsValues.GroupBy(Grouping, TableDescription.ResourcesString);
	
EndProcedure

Procedure LoadIndicatorValuesToRow(IndicatorSelection, IndicatorGroupings, TableDescription)
	
	ItemsTypes = TableDescription.ItemsTypes;
	Filter = New Structure("TotalLevel", -2);
	DetailedColumns = TableDescription.ReportColumns.FindRows(Filter);
	ValuesPeriods = New Map;
	IndicatorValues = TableDescription.IndicatorsValues.CopyColumns();
	IsIndicator = TableDescription.CurrentIndicator.ReportItem;
	If TableDescription.IsComplex Then
		IsIndicator = TableDescription.IndicatorRow;
	EndIf;
	
	// Filling row's detailed columns
	For Each Column In DetailedColumns Do
		
		If ValueIsFilled(Column.Filter) Then
			ColumnValues = IndicatorSelection.FindRows(Column.Filter);
		Else
			ColumnValues = IndicatorSelection;
		EndIf;
		FillDetails = False;
		For Each Cell In ColumnValues Do
			Period = New Structure("StartDate, EndDate", Cell.StartDate, Cell.EndDate);
			ValuesPeriods.Insert(Column.ColumnName, Period);
			
			NewValuesRow = IndicatorValues.Add();
			FillPropertyValues(NewValuesRow, Cell);
			FillPropertyValues(NewValuesRow, TableDescription.CurrentIndicator);
			If TableDescription.IsComplex And Column.ReportItem = TableDescription.IndicatorColumn
				Or Not TableDescription.IsComplex Then
				NewValuesRow[Column.ColumnName] = Cell.Value;
				FillDetails = True;
			EndIf;
		EndDo;
		If FillDetails Then
			FillCellDetails(IsIndicator, Column, TableDescription, ValuesPeriods);
		EndIf;
	EndDo;
	
	If TableDescription.ResourcesString = Undefined Then
		TableDescription.ResourcesString = StrConcat(TableDescription.Resources, ",");
	EndIf;
	
	Grouping = "ReportItem, DescriptionForPrinting, RowCode, Note";
	For Each Dimension In TableDescription.RowsDimensions Do
		Grouping = Grouping + "," + Dimension;
	EndDo;
	If ValueIsFilled(IndicatorGroupings) Then
		For Each GroupingValue In IndicatorGroupings Do
			Grouping = Grouping + "," + GroupingValue.Key;
			IndicatorValues.FillValues(GroupingValue.Value, GroupingValue.Key);
		EndDo;
	EndIf;
	IndicatorValues.GroupBy(Grouping, TableDescription.ResourcesString);
	If TableDescription.IsComplex Then
		IndicatorValues.Columns.Add("TableRow");
		IndicatorValues.FillValues(TableDescription.IndicatorRow, "TableRow");
	EndIf;
	
	// Calculating row's totals
	Filter = New Structure("TotalLevel");
	TotalLevel = TableDescription.ColumnsLevelsTotalNumber;
	For i = 0 To TableDescription.ColumnsLevelsTotalNumber Do
		
		Filter.TotalLevel = TotalLevel;
		TotalColumns = TableDescription.ReportColumns.FindRows(Filter);
		For Each Column In TotalColumns Do
			For Each ValuesRow In IndicatorValues Do
				ValuesRow[Column.ColumnName] = RowTotal(ValuesRow, Column, ValuesPeriods);
			EndDo;
			If IndicatorValues.Count() Then
				FillCellDetails(IsIndicator, Column, TableDescription, ValuesPeriods);
			EndIf;
		EndDo;
		TotalLevel = TotalLevel - 1;
		
	EndDo;
	
	LoadToValueTable(IndicatorValues, TableDescription.IndicatorsValues);
	
EndProcedure

Procedure CalculateHorizontalTotals(TableDescription)
	
	IndicatorsValues = TableDescription.IndicatorsValues;
	ValuesPeriods = New Map;
	
	Filter = New Structure("TotalLevel");
	TotalLevel = TableDescription.ColumnsLevelsTotalNumber - 1;
	For i = 0 To TableDescription.ColumnsLevelsTotalNumber - 1 Do
		
		Filter.TotalLevel = TotalLevel;
		TotalColumns = TableDescription.ReportColumns.FindRows(Filter);
		For Each Column In TotalColumns Do
			If Not Column.Operands.Count() Then
				Continue;
			EndIf;
			For Each ValuesRow In IndicatorsValues Do
				Period = New Structure("StartDate, EndDate", ValuesRow.StartDate, ValuesRow.EndDate);
				ValuesPeriods.Insert(Column.ColumnName, Period);
				ValuesRow[Column.ColumnName] = RowTotal(ValuesRow, Column, ValuesPeriods);
			EndDo;
		EndDo;
		TotalLevel = TotalLevel - 1;
		
	EndDo;
	
EndProcedure

Function TableForPrintingData()
	
	DataForPrinting = New Structure;
	DataForPrinting.Insert("ItemsTypes");
	DataForPrinting.Insert("RowsTree");
	DataForPrinting.Insert("IndicatorsValues");
	DataForPrinting.Insert("HeaderLevelsCount");
	DataForPrinting.Insert("ReportColumns");
	DataForPrinting.Insert("Details");
	DataForPrinting.Insert("Resources");
	DataForPrinting.Insert("TableIndicatorsInColumns");
	DataForPrinting.Insert("TableHeader");
	DataForPrinting.Insert("IsComplex");
	
	Return DataForPrinting;
	
EndFunction

Function CalculatedIndicatorValue(Parameters, Indicator = Undefined)
	
	ReportItem = Indicator;
	If ReportItem = Undefined Then
		ReportItem = Parameters.Indicator;
	EndIf;
	ReportPeriod = Parameters.ReportPeriod;
	ReportIntervals = Parameters.ReportIntervals.Copy();
	ReportIntervals.FillValues(ReportItem.ReportItem, "Indicator");
	ReportIntervals.FillValues(ReportItem.RowCode, "RowCode");
	ReportIntervals.FillValues(ReportItem.Note, "Note");
	IndicatorValue = IndicatorEmptyValue(ReportIntervals, Parameters.Dimensions);
	
	FormulaOperands = ReportItem.ReportItem.FormulaOperands;
	If ReportItem.IsLinked Then
		FormulaOperands = ReportItem.LinkedItem.FormulaOperands;
	EndIf;
	
	If ValueIsFilled(FormulaOperands) Then
		
		OperandsValues = Undefined;
		OperandsIDs = "";
		For Each Operand In FormulaOperands Do
			OperandsIDs = OperandsIDs + Operand.ID + ",";
			OperandData = ReportItem.Rows.Find(Operand.Operand, "ReportItem");
			If OperandData = Undefined Then
				OperandData = Common.ObjectAttributesValues(
					Operand.Operand,
					"DescriptionForPrinting, ItemType, HasSettings, AdditionalFilter, ReverseSign");
				AdditionalAttributes = FinancialReportingServerCall.AdditionalAttributesValues(
					Operand.Operand,
					"Account, TotalsType, OpeningBalance, UserDefinedFixedIndicator, RowCode, Note");
				For Each KeyValue In AdditionalAttributes Do
					OperandData.Insert(KeyValue.Key, KeyValue.Value);
				EndDo;
				OperandData.Insert("ReportItem", Operand.Operand);
				OperandData.Insert("IsLinked", False);
			EndIf;
			ValueOperand = SimpleIndicatorValue(Parameters, OperandData);
			ValueOperand.Columns.Value.Name = Operand.ID;
			If OperandsValues = Undefined Then
				OperandsValues = ValueOperand.Copy();
				Continue;
			EndIf;
			OperandsValues.Columns.Add(Operand.ID, Common.TypeDescriptionNumber(15, 2));
			LoadToValueTable(ValueOperand, OperandsValues);
		EndDo;
		StringFunctionsClientServer.DeleteLastCharInString(OperandsIDs,1);
		If Parameters.Property("CalculationError") Then
			TextPattern = NStr("en = 'Unreliable value of the indicator
								|%1(%2)
								|reason: error calculating composite indicators.'; 
								|ru = 'Недостоверное значение индикатора
								|%1(%2)
								|причина: ошибка при расчете комбинированных индикаторов.';
								|pl = 'Nierzetelna wartość przyczyny wskaźnika
								| %1(%2)
								|: błąd przy obliczaniu wskaźników złożonych.';
								|es_ES = 'Valor del indicador
								|%1poco fiable (%2)
								|motivo: error en el cálculo de los indicadores compuestos.';
								|es_CO = 'Valor del indicador
								|%1poco fiable (%2)
								|motivo: error en el cálculo de los indicadores compuestos.';
								|tr = 'Göstergenin değeri güvenilir değil 
								|%1(%2)
								| sebebi: bileşik göstergelerin hesaplanmasında hata.';
								|it = 'Valore non affidabile dell''indicatorer
								|%1(%2)
								|causa: errore di calcolo degli indicatori compositi.';
								|de = 'Unzuverlässiger Wert des Indikators
								|%1(%2)
								|Grund: Fehler bei der Berechnung von zusammengesetzten Indikatoren.'");
			Text = StringFunctionsClientServer.SubstituteParametersToString(
				TextPattern, 
				ReportItem.DescriptionForPrinting, 
				ReportItem.Code);
			CommonClientServer.MessageToUser(Text, ReportItem.ReportItem);
			AddErrorMessage(Parameters.MessagesAboutErrors, Text, ReportItem.ReportItem);
		EndIf;
		
		GroupingColumns = "";
		For Each Column In OperandsValues.Columns Do
			If StrFind(OperandsIDs, Column.Name) = 0 Then
				GroupingColumns = GroupingColumns + Column.Name + ",";
			EndIf;
		EndDo;
		StringFunctionsClientServer.DeleteLastCharInString(GroupingColumns,1);
		
		OperandsValues.FillValues(ReportItem.ReportItem, "Indicator");
		OperandsValues.FillValues(ReportItem.RowCode, "RowCode");
		OperandsValues.FillValues(ReportItem.Note, "Note");
		OperandsValues.GroupBy(GroupingColumns, OperandsIDs);
		
	Else
		
		OperandsValues = ReportIntervals.Copy();
		
	EndIf;
	
	If IsBlankString(ReportItem.Formula) Then
		TextPattern = NStr("en = '%1 (%2) indicator
							|value was not calculated
							|reason: calculation formula is not specified.'; 
							|ru = '%1 (%2) значение индикатора
							|не было рассчитано
							|причина: формула для расчета не указана.';
							|pl = '%1 (%2) wartość wskaźnika
							|nie została obliczona 
							|przyczyna: nie wybrano formuły obliczenia.';
							|es_ES = 'El valor %1 (%2) del indicador 
							| no se ha calculado
							|motivo: la fórmula de cálculo no se ha especificado.';
							|es_CO = 'El valor %1 (%2) del indicador 
							| no se ha calculado
							|motivo: la fórmula de cálculo no se ha especificado.';
							|tr = '%1 (%2) gösterge
							|değeri hesaplanmadı
							| sebebi: hesaplama formülü belirtilmemiş.';
							|it = '%1 (%2) indicatore
							|il valore non è stato calcolato
							|causa: calcolo della formula non specificato.';
							|de = '%1 (%2) Indikator
							|wert wurde nicht berechnet
							|Grund: Berechnungsformel ist nicht angegeben.'");
		Text = StringFunctionsClientServer.SubstituteParametersToString(
			TextPattern, 
			ReportItem.DescriptionForPrinting, 
			ReportItem.Code);
		CommonClientServer.MessageToUser(Text);
		AddErrorMessage(Parameters.MessagesAboutErrors, Text, ReportItem.ReportItem);
		Parameters.Insert("CalculationError");
	EndIf;
	
	// Calculating formula
	IndicatorSchema = Catalogs.FinancialReportsItems.IndicatorSchema(ReportItem, Parameters.Dimensions);
	ExternalSets = New Structure;
	ExternalSets.Insert("OperandsValues", OperandsValues);
	ExternalSets.Insert("ReportIntervals", ReportIntervals);
	
	Settings = IndicatorSchema.Settings;
	SetCompositionParameter(Settings, "ReportItem", ReportItem.ReportItem);
	SetCompositionParameter(Settings, "ReverseSign" , ReportItem.ReverseSign);
	SetCompositionParameter(Settings, "BeginOfPeriod", ReportPeriod.BeginOfPeriod);
	SetCompositionParameter(Settings, "EndOfPeriod" , ReportPeriod.EndOfPeriod);
	SetCompositionParameter(Settings, "Periodicity" , ReportPeriod.Periodicity);
	AddPeriodicitySetting(Settings, ReportPeriod);
	
	IndicatorData = UnloadDataCompositionResult(IndicatorSchema.Schema, Settings, ExternalSets);
	If Not ValueIsFilled(IndicatorData) Then
		IndicatorData = OperandsValues.Copy();
	EndIf;
	
	If IndicatorData.Count() > 0 Then
		IndicatorValue.Clear();
		LoadToValueTable(IndicatorData, IndicatorValue);
	EndIf;
	
	Return IndicatorValue;
	
EndFunction

Function GroupTotalValue(Parameters, Indicator = Undefined)
	
	ReportItem = Indicator;
	If ReportItem = Undefined Then
		ReportItem = Parameters.Indicator;
	EndIf;
	ReportPeriod = Parameters.ReportPeriod;
	TotalIndicators = RefreshReportTree(ReportItem.LinkedItem.Owner, ReportItem.LinkedItem);
	
	ItemID = ItemID(ReportItem);
	GroupTotal = Undefined;
	For Each TotalIndicator In TotalIndicators.Rows Do
		
		IndicatorValue = ReportIndicatorValue(Parameters, TotalIndicator);
		If IndicatorValue = Undefined Then
			Continue;
		EndIf;
		
		If GroupTotal = Undefined Then
			GroupTotal = IndicatorValue.Copy();
		Else
			LoadToValueTable(IndicatorValue, GroupTotal);
		EndIf;
		
	EndDo;
	If Parameters.Property("CalculationError") Then
		TextPattern = NStr("en = 'Unreliable value of the group total
							|%1 (%2)
							|reason: error calculating composite indicators.'; 
							|ru = 'Недостоверное значение итога по группе
							|%1 (%2)
							|причина: ошибка при расчете комбинированных индикаторов.';
							|pl = 'Nierzetelna wartość grupy wartości łącznych
							| %1(%2)
							|przyczyna: błąd przy obliczaniu wskaźników złożonych.';
							|es_ES = 'Valor del total del grupo
							|%1 poco fiable (%2)
							|motivo: error en el cálculo de los indicadores compuestos.';
							|es_CO = 'Valor del total del grupo
							|%1 poco fiable (%2)
							|motivo: error en el cálculo de los indicadores compuestos.';
							|tr = '
							|%1 grup toplamının değeri güvenilir değil (%2) 
							| sebebi: bileşik göstergelerin hesaplanmasında hata.';
							|it = 'Valore non affidabile del totale del gruppo
							|%1 (%2)
							|causa: errore di calcolo degli indicatori compositi.';
							|de = 'Unzuverlässiger Wert der Gruppensumme
							|%1 (%2)
							|Grund: Fehler bei der Berechnung von zusammengesetzten Indikatoren.'");
		Text = StringFunctionsClientServer.SubstituteParametersToString(
			TextPattern, 
			ReportItem.DescriptionForPrinting, 
			ReportItem.Code);
		CommonClientServer.MessageToUser(Text);
		Parameters.MessagesAboutErrors.Add(Text);
	EndIf;
	
	GroupTotal.FillValues(ReportItem.ReportItem, "Indicator");
	GroupTotal.FillValues(ReportItem.RowCode, "RowCode");
	GroupTotal.FillValues(ReportItem.Note, "Note");
	
	GroupingColumns = "";
	For Each Column In GroupTotal.Columns Do
		If Column.Name = "Value" Then
			Continue;
		EndIf;
		GroupingColumns = GroupingColumns + Column.Name + ",";
	EndDo;
	StringFunctionsClientServer.DeleteLastCharInString(GroupingColumns,1);
	
	GroupTotal.GroupBy(GroupingColumns, "Value");
	If ReportItem.ReverseSign Then
		For Each Total In GroupTotal Do
			Total.Value = -1 * Total.Value;
		EndDo;
	EndIf;
	Return GroupTotal;
	
EndFunction

Procedure DistributeItemsByLevels(Rows, TotalDepth, RowsToLevelsMap, CurrentDepth = 0)
	
	If CurrentDepth > TotalDepth Then
		Return;
	EndIf;
	
	RowsList = RowsToLevelsMap[CurrentDepth + 1];
	If RowsList = Undefined Then
		RowsList = New Array;
	EndIf;
	RowsToLevelsMap.Insert(CurrentDepth + 1, RowsList);
	
	If Rows = Undefined Or Not Rows.Count() Then
		
		RowsList.Add(Undefined);
		DistributeItemsByLevels(Undefined, TotalDepth, RowsToLevelsMap, CurrentDepth + 1);
		
	Else
		
		For Each IndicatorRow In Rows Do
			
			RowsList.Add(IndicatorRow);
			DistributeItemsByLevels(IndicatorRow.Rows, TotalDepth, RowsToLevelsMap, CurrentDepth + 1);
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure MergeVertically(Document, TopRowNumber, Val CellsCount, ColumnNumber, AreaText = "", Center = False)
	
	If CellsCount <= 1 Then
		Return;
	EndIf;
	
	Area = Document.Area(TopRowNumber, ColumnNumber, TopRowNumber + CellsCount - 1, ColumnNumber);
	Area.Merge();
	If Not IsBlankString(AreaText) Then
		Area.Text = AreaText;
	EndIf;
	If Center Then
		Area.HorizontalAlign = HorizontalAlign.Center;
		Area.VerticalAlign = VerticalAlign.Center;
	EndIf;
	
EndProcedure

Procedure OutputRowCells(TableRowData, ResultDocument, TableDescription, Parameters, Level)
	
	ItemsTypes = Parameters.ItemsTypes;
	If TableRowData.ItemType = ItemsTypes.GroupTotal And TableRowData.TotalPosition = 0 Then
		Return;
	EndIf;
	
	HasTotalAtBegin = TableRowData.TotalPosition = 0;
	IsFolder = TableRowData.ItemType = ItemsTypes.Group;
	IsPeriodDimension = ValueIsFilled(TableRowData.PeriodPresentation);
	// Group titles are output without resources
	OutputResources = ((HasTotalAtBegin And IsFolder) // groups with totals at the beginning are output with resources
		Or Not IsFolder) // indicators, dimensions and totals are output with resources
		And Not (TableDescription.IsComplex And IsPeriodDimension); // period dimensions in "matrix" reports are output without resources
	
	RowTemplate = Parameters.OutputTemplate.ItemType[TableRowData.ItemType];
	If TableRowData.ItemType = ItemsTypes.GroupTotal And TableRowData.IsLinked Then
		RowTemplate = Parameters.OutputTemplate.ReportRow;
	EndIf;
	If TableRowData.MarkItem Then
		RowTemplate = Parameters.OutputTemplate.Grouping;
	EndIf;
	
	RowTemplate.Indicator.Parameters.Description = TableRowData.DescriptionForPrinting;
	RowTemplate.Indicator.Parameters.Details = TableRowData.ReportItem;
	OutputArea = ResultDocument.Put(RowTemplate.Indicator, Level);
	
	For Each Column In TableDescription.ReportColumns Do
		
		If RowTemplate.Property(Column.ColumnName) Then
			CellTemplate = RowTemplate[Column.ColumnName];
		Else
			CellTemplate = RowTemplate.Value;
		EndIf;
		If OutputResources Then
			CellTemplate.Parameters.Value = Format(TableRowData[Column.ColumnName], Parameters.ValuesFormat);
			CellTemplate.Parameters.Details = CellDetails(TableDescription, TableRowData, Column.ColumnName);
		Else
			CellTemplate.Parameters.Value = "";
			CellTemplate.Parameters.Details = Undefined;
		EndIf;
		ResultDocument.Join(CellTemplate);
		
	EndDo;
	
EndProcedure

Procedure CalculateVerticalTotals(ReportNewRow, TableDescription)
	
	Filter = New Structure("ItemType, IsLinked", TableDescription.ItemsTypes.GroupTotal, False);
	Rows = ReportNewRow.Rows.FindRows(Filter);
	GroupTotal = Undefined;
	If Rows.Count() Then
		GroupTotal = Rows[0];
	EndIf;
	ReverseSign = 1;
	If GroupTotal <> Undefined And GroupTotal.ReverseSign Then
		ReverseSign = -1;
	EndIf;
	
	For Each Name In TableDescription.Resources Do
		TotalValue = ReverseSign * ReportNewRow.Rows.Total(Name);
		ReportNewRow[Name] = TotalValue;
		If GroupTotal <> Undefined Then
			GroupTotal[Name] = TotalValue;
		EndIf;
	EndDo;
	
EndProcedure

Procedure FillTableResources(ReportNewRow, ResourcesValues, TableDescription)
	
	If ResourcesValues.Count() Then
		If TableDescription.IsComplex Then
			Filter = New Structure("TableRow", ReportNewRow.ReportItem);
			RowResources = ResourcesValues.FindRows(Filter);
			For Each Resource In TableDescription.Resources Do
				ReportNewRow[Resource] = TotalByColumn(RowResources, Resource);
			EndDo;
		Else
			RowResources = ResourcesValues.Find(ReportNewRow.ReportItem, "ReportItem");
			If RowResources <> Undefined Then
				FillPropertyValues(ReportNewRow, RowResources, TableDescription.ResourcesString);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

Procedure AddDimensionTableItem(TableItems, Item, AdditionalSuffix, IsColumns)
	
	DimensionsTypes = Enums.FinancialReportDimensionTypes;
	ItemID = ItemID(Item);
	IsPeriod = Item.DimensionType = DimensionsTypes.Period;
	IsAnalyticalDimension = Item.DimensionType = DimensionsTypes.AnalyticalDimension;
	If IsPeriod Then
		Data = New Structure("Periodicity", Item.Periodicity);
		Data.Insert("Presentation", Item.DescriptionForPrinting);
		Data.Insert("Sort", ?(ValueIsFilled(Item.Sort), Item.Sort, "ASC"));
		TableItems.Periodicity.Add(Data);
		ColumnName = "Period" + XMLString(Item.Periodicity);
		Data.Insert("ColumnName", ColumnName);
	EndIf;
	If IsAnalyticalDimension Then
		TableItems.Insert("AnalyticalDimension", Item);
		ColumnName = "ExtDimension1";
		DimensionData = New Structure("Value, Presentation, Filter", ColumnName, Item.DescriptionForPrinting, Undefined);
		TableItems.RegisterDimensions.Add(DimensionData);
	EndIf;
	If Item.DimensionType = DimensionsTypes.AccountingRegisterDimension Then
		ColumnName = Item.DimensionName;
		DimensionData = New Structure("Value, Presentation, Filter", ColumnName, Item.DescriptionForPrinting, Undefined);
		Settings = Item.AdditionalFilter.Get();
		If Settings <> Undefined Then
			DimensionData.Filter = Settings.Filter;
		EndIf;
		TableItems.RegisterDimensions.Add(DimensionData);
	EndIf;
	TableItems.TableDimensions.Add(ColumnName);
	If Not IsColumns Then
		TableItems.RowsDimensions.Add(ColumnName);
	EndIf;
	AddToOutputTree(TableItems, Item, ItemID, ColumnName);
	
EndProcedure

Procedure AddToOutputTree(TableItems, Item, ItemID, ColumnName = "", TotalPosition = Undefined)
	
	NewColumn = TableItems.CurrentLevel.Add();
	FillPropertyValues(NewColumn, Item);
	NewColumn.ItemID = ItemID;
	If Item.ItemType = TableItems.ItemsTypes.GroupTotal Then
		If Item.OutputItemTitle Then
			NewColumn.TotalPosition = TotalPosition;
		EndIf;
		If ValueIsFilled(NewColumn.Parent) Then
			NewColumn.Parent.TotalPosition = NewColumn.TotalPosition;
		EndIf;
	EndIf;
	
	If Not IsBlankString(ColumnName) Then
		NewColumn.ColumnName = ColumnName;
	EndIf;
	
	TableItems.CurrentLevel = NewColumn.Rows;
	TableItems.CurrentParent = NewColumn;
	
EndProcedure

Procedure ComplexTableIndicators(TableCells, TableItems, Parameters, IsColumns = False)
	
	For Each CellItem In TableCells.Rows Do
		If IsIndicator(CellItem.ItemType, Parameters.ItemsTypes, CellItem.IsLinked) Then
			CellAddress = TableCells.ReportItem.TableItems.Find(CellItem.ReportItem, "Item");
			If CellAddress <> Undefined Then
				Description = New Structure("Description", CellItem);
				Description.Insert("Row", CellAddress.Row);
				Description.Insert("Column", CellAddress.Column);
				TableItems.Indicators.Insert(CellItem.ReportItem, Description);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Procedure AddTableColumn(ColumnName, NewReportColumn, Filter, TableDescription, IsTotal = False)
	
	IndicatorsValues = TableDescription.IndicatorsValues;
	
	NewReportColumn.ColumnName = ColumnName;
	If IndicatorsValues.Columns.Find(ColumnName) <> Undefined Then
		Return;
	EndIf;
	
	NumberType = Common.TypeDescriptionNumber(15, 2);
	IndicatorsValues.Columns.Add(ColumnName, NumberType, NewReportColumn.DescriptionForPrinting);
	
	ColumnDescription = TableDescription.ReportColumns.Add();
	FillPropertyValues(ColumnDescription, NewReportColumn);
	TotalLevel = ?(IsTotal,NewReportColumn.Level() - 1, -2);
	ColumnDescription.TotalLevel = TotalLevel;
	ColumnDescription.ColumnName = ColumnName;
	ColumnDescription.Operands = New Array;
	ColumnDescription.Filter = CommonClientServer.CopyStructure(Filter);
	ColumnDescription.IsTotal = IsTotal;
	
	NewReportColumn.Description = ColumnDescription;
	
	TableDescription.Resources.Add(ColumnName);
	TableDescription.ColumnsLevelsTotalNumber = Max(TotalLevel, TableDescription.ColumnsLevelsTotalNumber);
	TableDescription.ColumnNumber = TableDescription.ColumnNumber + 1;
	
EndProcedure

Procedure AddTotalOperand(ColumnName, TotalsTree, TableDescription)
	
	HeaderColumn = TotalsTree.Rows.Find(ColumnName, "ColumnName", True);
	Total = FindParentTotal(HeaderColumn, TableDescription.ItemsTypes.GroupTotal);
	If ValueIsFilled(Total) Then
		TotalDescription = TableDescription.ReportColumns.Find(Total.ColumnName, "ColumnName");
		If ValueIsFilled(TotalDescription) Then
			TotalDescription.Operands.Add(ColumnName);
		EndIf;
	EndIf;
	
EndProcedure

Procedure GenerateTableHeader(TotalsTree, TableHeader, TotalDepth = 0)
	
	For Each Title In TotalsTree.Rows Do
		NewTitle = TableHeader;
		If Title.OutputItemTitle Then
			NewTitle = TableHeader.Rows.Add();
			FillPropertyValues(NewTitle, Title);
		EndIf;
		GenerateTableHeader(Title, NewTitle, TotalDepth);
		If NewTitle.Rows.Count() = 0 And TypeOf(NewTitle) = Type("ValueTreeRow") Then
			TotalDepth = Max(TotalDepth, NewTitle.Level());
		EndIf;
	EndDo;
	
EndProcedure

Procedure FillCellDetails(ReportRowID, ColumnData, TableDescription, ColumnsPeriods = Undefined)
	
	RowDetails = TableDescription.Details[ReportRowID];
	If RowDetails = Undefined Then
		RowDetails = New Map;
		TableDescription.Details.Insert(ReportRowID, RowDetails);
	EndIf;
	
	CellDetails = RowDetails[ColumnData.ColumnName];
	If CellDetails = Undefined Then
		CellDetails = New Structure("Indicator, StartDate, EndDate, ItemType, Account, UserDefinedFixedIndicator, Filter");
		FillPropertyValues(CellDetails, TableDescription.CurrentIndicator);
		CellDetails.Indicator = TableDescription.CurrentIndicator.ReportItem;
		RowDetails.Insert(ColumnData.ColumnName, CellDetails);
	EndIf;
	FillPropertyValues(CellDetails, ColumnData);
	
	If ColumnsPeriods <> Undefined And ColumnsPeriods[ColumnData.ColumnName] <> Undefined Then
		FillPropertyValues(CellDetails, ColumnsPeriods[ColumnData.ColumnName]);
	EndIf;
	
EndProcedure

Function RowTotal(OperandsValues, TotalDescription, ValuesPeriods);
	
	Total = 0;
	For Each Name In TotalDescription.Operands Do
		Total = Total + OperandsValues[Name];
		OperandPeriod = ValuesPeriods[Name];
		TotalPeriod = ValuesPeriods[TotalDescription.ColumnName];
		If TotalPeriod = Undefined Then
			ValuesPeriods.Insert(TotalDescription.ColumnName, OperandPeriod);
		ElsIf OperandPeriod <> Undefined Then
			TotalPeriod.StartDate = Min(TotalPeriod.StartDate, OperandPeriod.StartDate);
			TotalPeriod.EndDate = Max(TotalPeriod.EndDate, OperandPeriod.EndDate);
		EndIf;
	EndDo;
	Total = ?(TotalDescription.ReverseSign, -1, 1) * Total;
	Return Total;
	
EndFunction

Function TotalByColumn(TableRows, ColumnName)
	
	Result = 0;
	For Each Row In TableRows Do
		Result = Result + Row[ColumnName];
	EndDo;
	Return Result;
	
EndFunction

Function CellDetails(TableDescription, TableRowData, ColumnName)
	
	ReportRowID = TableRowData.ReportItem;
	If TableDescription.TableIndicatorsInColumns Then
		ReportRowID = TableRowData.GroupingValue;
	EndIf;
	RowDetails = TableDescription.Details[ReportRowID];
	If RowDetails = Undefined Then
		Return Undefined;
	EndIf;
	
	Details = RowDetails[ColumnName];
	If TypeOf(Details) = Type("Structure") Then
		Details = CommonClientServer.CopyStructure(Details);
		If TableDescription.TableIndicatorsInColumns Then
			GroupingValue = TableRowData.GroupingValue;
			GroupingColumnName = TableRowData.ColumnName;
		ElsIf ValueIsFilled(TableRowData.Parent) Then
			GroupingValue = TableRowData.Parent.GroupingValue;
			GroupingColumnName = TableRowData.Parent.ColumnName;
		EndIf;
		If ValueIsFilled(GroupingColumnName) Then
			Details.Filter.Insert(GroupingColumnName, GroupingValue);
		EndIf;
	EndIf;
	
	Return Details;
	
EndFunction

Function FindParentTotal(Val TreeBranch, ItemTypeTotal)
	
	ColumnName = TreeBranch.ColumnName;
	While ValueIsFilled(TreeBranch) Do
		Total = TreeBranch.Rows.Find(ItemTypeTotal, "ItemType");
		If ValueIsFilled(Total) And Total.ColumnName <> ColumnName Then
			Break;
		ElsIf ValueIsFilled(Total) And Total.ColumnName = ColumnName Then
			Total = Undefined;
		EndIf;
		TreeBranch = TreeBranch.Parent;
	EndDo;
	Return Total;
	
EndFunction

Function PrepareDataCompositionTemplateForUnloading(DataCompositionSchema, ComposerSettings)
	
	DCSettings = ComposerSettings;
	If TypeOf(ComposerSettings) = Type("DataCompositionSettingsComposer") Then
		DCSettings = ComposerSettings.GetSettings();
	EndIf;
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, DCSettings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
	
	Return CompositionTemplate;
	
EndFunction

Function UnloadDataCompositionTemplateResult(CompositionTemplate, ExternalDataSets = Undefined,
											OutputToTree = False) Export
	
	Result = New ValueTable;
	If OutputToTree Then
		Result = New ValueTree;
	EndIf;
	
	CompositionProcessor = New DataCompositionProcessor;
	If ExternalDataSets = Undefined Then
		CompositionProcessor.Initialize(CompositionTemplate, , , True);
	Else
		CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, , True);
	EndIf;
	
	OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
	OutputProcessor.SetObject(Result);
	Result = OutputProcessor.Output(CompositionProcessor, True);
	Return Result;
	
EndFunction

Function AdditionalAttributesCache(ReportType)
	
	Query = New Query;
	QueryText = 
	"SELECT
	|	CatalogTabularSection.Ref AS ReportItem,
	|	CatalogTabularSection.Attribute AS Attribute,
	|	CatalogTabularSection.Value AS Value
	|FROM
	|	Catalog.FinancialReportsItems.ItemTypeAttributes AS CatalogTabularSection
	|		LEFT JOIN Catalog.FinancialReportsItems AS Catalog
	|		ON CatalogTabularSection.Ref = Catalog.Ref
	|WHERE
	|	Catalog.Owner = &ReportType";
	
	Query.Text = QueryText;
	Query.SetParameter("ReportType", ReportType);
	
	Table = Query.Execute().Unload();
	Table.Indexes.Add("ReportItem, Attribute");
	Return Table;
	
EndFunction

#EndRegion