#Region Public

Function ChildItem(Tree, AttributeName, AttributeValue) Export
	
	ChildItem = Undefined;
	
	If TypeOf(Tree) = Type("FormDataTree")
		Or TypeOf(Tree) = Type("FormDataTreeItem")
		Or TypeOf(Tree) = Type("FormDataTreeItemCollection") Then
		
		ChildItems = ChildItems(Tree);
		For Each TreeRow In ChildItems Do
			If TreeRow[AttributeName] = AttributeValue Then
				ChildItem = TreeRow;
				Break;
			EndIf;
			ChildItem = ChildItem(TreeRow, AttributeName, AttributeValue);
			If ChildItem <> Undefined Then
				Break;
			EndIf;
		EndDo;
		
	Else
		
		TreeRows = Tree.Rows;
		Return TreeRows.Find(AttributeValue, AttributeName, True);
		
	EndIf;
	
	Return ChildItem;
	
EndFunction

Function ChildItems(TreeRow) Export
	
	If TypeOf(TreeRow) = Type("FormDataTreeItemCollection") Then
		
		ChildItems = TreeRow;
		
	ElsIf TypeOf(TreeRow) = Type("FormDataTreeItem") Or TypeOf(TreeRow) = Type("FormDataTree") Then
		
		ChildItems = TreeRow.GetItems();
		
	ElsIf TypeOf(TreeRow) = Type("ValueTreeRowCollection") Then
		
		ChildItems = TreeRow;
		
	Else
		
		ChildItems = TreeRow.Rows;
		
	EndIf;
	
	Return ChildItems;
	
EndFunction

Function ParentItem(TreeRow) Export
	
	If TypeOf(TreeRow) = Type("FormDataTreeItem")
		Or TypeOf(TreeRow) = Type("FormDataTree") Then
		ParentItem = TreeRow.GetParent();
	Else
		ParentItem = TreeRow.Parent;
	EndIf;
	
	Return ParentItem;
	
EndFunction

Function RootItem(Tree, RootItemType = Undefined) Export
	
	If RootItemType = Undefined Then
		RootItemType = PredefinedValue("Enum.FinancialReportItemsTypes.EmptyRef");
	EndIf;
	
	RootItem = Undefined;
	If TypeOf(Tree) = Type("FormDataTree") Then
		ChildRows = ChildItems(Tree);
		For Each TreeRow In ChildRows Do
			If TreeRow.ItemType = RootItemType Then
				RootItem = TreeRow;
				Break;
			EndIf;
		EndDo;
	Else
		RootItem = ParentItem(Tree);
		While RootItem <> Undefined Do
			If RootItem.ItemType = RootItemType Then
				Break;
			EndIf;
			RootItem = ParentItem(RootItem);
		EndDo;
	EndIf;
	
	Return RootItem;
	
EndFunction

Function NewRowIndex(TreeRows) Export
	
	Index = -1;
	For Each TreeRow In TreeRows Do
		
		If TreeRow.ItemType = ItemType("GroupTotal") And Not TreeRow.IsLinked Then
			Index = TreeRows.IndexOf(TreeRow);
			Break;
		EndIf;
		
	EndDo;
	
	If Index = -1 Or Index = 0 And TreeRows.Count() > 1 Then
		Index = TreeRows.Count();
	EndIf;
	
	Return Index;
	
EndFunction

Function PutItemToTempStorage(Item, StorageAddress = Undefined, ClearRefs = False) Export
	
	// If forming the storage based on a row then we form based on the item, if we have one, else based on the row itself
	If TypeOf(Item) = Type("FormDataTreeItem")
		Or TypeOf(Item) = Type("FormDataCollectionItem")
		Or TypeOf(Item) = Type("ValueTreeRow") Then
		
		If ValueIsFilled(Item.ReportItem) Then
			Return FinancialReportingServerCall.PutItemToTempStorage(Item.ReportItem, StorageAddress, ClearRefs);
		Else
			
			ItemStructure = ReportItemStructure();
			TotalsType = PredefinedValue("Enum.TotalsTypes.BalanceDr");
			FillPropertyValues(ItemStructure, Item);
			ItemStructure.Insert("IsLinked", False);
			If Item.IsLinked Then
				
				ItemStructure.Insert("IsLinked", True);
				ItemStructure.Insert("AdditionalAttribute_OutputItemTitle", True);
				ItemStructure.Insert("AdditionalAttribute_RowCode", "");
				ItemStructure.Insert("AdditionalAttribute_Note", "");
				ItemStructure.Insert("AdditionalAttribute_MarkItem", False);
				
			ElsIf ItemStructure.ItemType = ItemType("ReportTitle")
				Or ItemStructure.ItemType = ItemType("NonEditableText")
				Or ItemStructure.ItemType = ItemType("EditableText") Then
				
				ItemStructure.Insert("AdditionalAttribute_Text", Item.AccountIndicatorDimension);
				
			ElsIf ItemStructure.ItemType = ItemType("TableIndicatorsInRows")
				Or ItemStructure.ItemType = ItemType("TableIndicatorsInColumns")
				Or ItemStructure.ItemType = ItemType("TableComplex") Then
				
				ItemStructure.Insert("AdditionalAttribute_OutputItemTitle", False);
				
			ElsIf ItemStructure.ItemType = ItemType("AccountingDataIndicator") Then
				
				ItemStructure.Insert("AdditionalAttribute_Account", Item.AccountIndicatorDimension);
				ItemStructure.Insert("AdditionalAttribute_TotalsType", TotalsType);
				ItemStructure.Insert("AdditionalAttribute_OpeningBalance", False);
				ItemStructure.Insert("AdditionalAttribute_RowCode", "");
				ItemStructure.Insert("AdditionalAttribute_Note", "");
				ItemStructure.Insert("AdditionalAttribute_MarkItem", False);
				
			ElsIf ItemStructure.ItemType = ItemType("UserDefinedFixedIndicator") Then
				
				ItemStructure.Insert("AdditionalAttribute_UserDefinedFixedIndicator", Item.AccountIndicatorDimension);
				ItemStructure.Insert("AdditionalAttribute_RowCode", "");
				ItemStructure.Insert("AdditionalAttribute_Note", "");
				ItemStructure.Insert("AdditionalAttribute_MarkItem", False);
				
			ElsIf ItemStructure.ItemType = ItemType("UserDefinedCalculatedIndicator") Then
				
				ItemStructure.Insert("AdditionalAttribute_Formula", "");
				ItemStructure.Insert("AdditionalAttribute_RowCode", "");
				ItemStructure.Insert("AdditionalAttribute_Note", "");
				ItemStructure.Insert("AdditionalAttribute_MarkItem", False);
				
			ElsIf ItemStructure.ItemType = ItemType("Group")
				Or ItemStructure.ItemType = ItemType("GroupTotal") Then
				
				ItemStructure.Insert("AdditionalAttribute_OutputItemTitle", True);
				ItemStructure.Insert("AdditionalAttribute_RowCode", "");
				ItemStructure.Insert("AdditionalAttribute_Note", "");
				
			ElsIf ItemStructure.ItemType = ItemType("TableItem") Then
				
				ItemStructure.Insert("AdditionalAttribute_RowCode", "");
				ItemStructure.Insert("AdditionalAttribute_Note", "");
			
			ElsIf ItemStructure.ItemType = ItemType("Dimension") Then
				
				DimensionType = DefineDimensionTypeByValueType(Item.AccountIndicatorDimension, Item);
				ItemStructure.Insert("AdditionalAttribute_DimensionType", DimensionType);
				
				If DimensionType = DimensionType("AccountingRegisterDimension") Then
					AdditionalAttributeName = "AdditionalAttribute_DimensionName";
				ElsIf DimensionType = DimensionType("Period") Then
					AdditionalAttributeName = "AdditionalAttribute_Periodicity";
					ItemStructure.Insert("AdditionalAttribute_Sort", "ASC");
					ItemStructure.Insert("AdditionalAttribute_PeriodPresentation", PredefinedValue("Enum.PeriodPresentation.EndDate"));
				ElsIf DimensionType = DimensionType("AnalyticalDimension") Then
					AdditionalAttributeName = "AdditionalAttribute_AnalyticalDimensionType";
				EndIf;
				
				ItemStructure.Insert(AdditionalAttributeName, Item.AccountIndicatorDimension);
				
			EndIf;
			
			Return FinancialReportingServerCall.PutItemToTempStorage(ItemStructure, StorageAddress, ClearRefs);
			
		EndIf;
	Else
		Return FinancialReportingServerCall.PutItemToTempStorage(Item, StorageAddress, ClearRefs);
	EndIf;
	
EndFunction

Function PutItemCopyToTempStorage(Item, StorageAddress = Undefined) Export
	
	Return PutItemToTempStorage(Item, StorageAddress, True);
	
EndFunction

Function NewRowFillingData(RowAdditionalAttributes = "") Export
	
	If IsBlankString(RowAdditionalAttributes) Then
		RowAdditionalAttributes =
			"Account,
			|TotalsType,
			|OpeningBalance,
			|UserDefinedFixedIndicator,
			|Text,
			|RowCode,
			|Note,
			|OutputItemTitle";
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("Source");
	Parameters.Insert("RowRecipient");
	Parameters.Insert("ItemAddressInTempStorage");
	Parameters.Insert("Field");
	Parameters.Insert("RowAdditionalAttributes", RowAdditionalAttributes);
	Return Parameters;

EndFunction

Procedure FillTreeRow(Parameters) Export
	
	Source = Parameters.Source;
	RowRecipient = Parameters.RowRecipient;
	ItemAddressInTempStorage = Parameters.ItemAddressInTempStorage;
	RowAdditionalAttributes = Parameters.RowAdditionalAttributes;
	Field = Parameters.Field;
	
	If Source = Undefined Then
		Return;
	EndIf;
	
	// Form returns actual attributes
	If TypeOf(RowRecipient) = Type("Number") Then
		RowRecipient = Field.FindByID(RowRecipient);
	EndIf;
	
	FillPropertyValues(RowRecipient, Source);
	
	If Not ValueIsFilled(ItemAddressInTempStorage) Then
		AdditionalAttributes = FinancialReportingServerCall.AdditionalAttributesValues(Source, RowAdditionalAttributes);
	Else
		// Actual values of additional attributes are formed at server
		// during BeforeWriteAtServer they are in the storage
		AdditionalAttributes = FinancialReportingServerCall.AdditionalAttributesValues(ItemAddressInTempStorage, RowAdditionalAttributes);
	EndIf;
	
	FillPropertyValues(RowRecipient, AdditionalAttributes);
	If ValueIsFilled(Source.LinkedItem) Then
		
		AdditionalAttributes = FinancialReportingServerCall.AdditionalAttributesValues(Source.LinkedItem, Parameters.RowAdditionalAttributes);
		FillPropertyValues(RowRecipient, AdditionalAttributes, , "RowCode, Note");
		
	ElsIf RowRecipient.ItemType = ItemType("AccountingDataIndicator") Then
		
		RowRecipient.AccountIndicatorDimension = RowRecipient.Account;
		
	ElsIf RowRecipient.ItemType = ItemType("UserDefinedFixedIndicator") Then
		
		RowRecipient.AccountIndicatorDimension = AdditionalAttributes.UserDefinedFixedIndicator;
		
	EndIf;
	
EndProcedure

Procedure SetNewParent(CurrentRow, NewParent, IsExisting, InfiniteLoopControl,
						FormID = Undefined, Clone = False, IdentificatorsParameters = Undefined) Export
	
	If InfiniteLoopControl Then
		Parent = ParentItem(NewParent);
		While Parent <> Undefined Do
			If TypeOf(Parent) = Type("FormDataTreeItem") And Parent.GetID() = CurrentRow.GetID()
				Or ValueIsFilled(Parent.ReportItem) And Parent.ReportItem = CurrentRow.ReportItem
				Or ValueIsFilled(Parent.ItemStructureAddress) And Parent.ItemStructureAddress = CurrentRow.ItemStructureAddress Then
				Return;
			EndIf;
			Parent = ParentItem(Parent);
		EndDo;
	EndIf;
	
	ParentRows = ChildItems(NewParent);
	If IsExisting Then
		NewRow = ParentRows.Add();
	Else
		Index = NewRowIndex(ParentRows); //if there's a group total at the end of the group the new row should be placed before it
		NewRow = ParentRows.Insert(Index);
	EndIf;
	
	FillPropertyValues(NewRow, CurrentRow);
	
	If IdentificatorsParameters <> Undefined Then
		IndentificatorsMap = IdentificatorsParameters.IndentificatorsMap;
		If IdentificatorsParameters.Mode = "Save" Then
			IndentificatorsMap.Insert(CurrentRow.GetID(), NewRow.GetID());
		ElsIf IdentificatorsParameters.Mode = "Recover" Then
			NewRow.ReportItemsRowIndex = IndentificatorsMap[NewRow.ReportItemsRowIndex];
			For Counter = 2 To IdentificatorsParameters.IdentificatorsCount Do
				If NewRow["ReportItemsRowIndex" + Counter] = Undefined Then
					Continue;
				EndIf;
				NewRow["ReportItemsRowIndex" + Counter] = IndentificatorsMap[NewRow["ReportItemsRowIndex" + Counter]];
			EndDo;
		EndIf;
	EndIf;
	
	If FormID <> Undefined Then
		If Clone Then
			
			If ValueIsFilled(NewRow.ItemStructureAddress) Then
				
				NewRow.ItemStructureAddress = FinancialReportingServerCall.CopyItemByAddress(NewRow.ItemStructureAddress, FormID);
				
			ElsIf Not ValueIsFilled(NewRow.ItemStructureAddress) And ValueIsFilled(NewRow.ReportItem) Then
			
				NewRow.ItemStructureAddress = FinancialReportingServerCall.PutItemToTempStorage(NewRow.ReportItem, FormID, True);
				
			EndIf;
			
			NewRow.ReportItem = Undefined;
		
		ElsIf Not ValueIsFilled(NewRow.ItemStructureAddress) And ValueIsFilled(NewRow.ReportItem) Then
			
			NewRow.ItemStructureAddress = FinancialReportingServerCall.PutItemToTempStorage(NewRow.ReportItem, FormID);
		
		EndIf;
	EndIf;
	
	CurrentRowRows = ChildItems(CurrentRow);
	Counter = CurrentRowRows.Count();
	
	While Counter > 0 Do
		
		RowNumber = CurrentRowRows.Count() - Counter;
		ChildRow = CurrentRowRows[RowNumber];
		SetNewParent(ChildRow, NewRow, IsExisting, False, FormID, Clone, IdentificatorsParameters);
		Counter = Counter - 1;
		
	EndDo;
	
	If Not Clone Then
		CurrentParent = ParentItem(CurrentRow);
		If CurrentParent <> Undefined Then
			CurrentRowsSet = ChildItems(CurrentParent);
			CurrentRowsSet.Delete(CurrentRow);
		EndIf;
	EndIf;
	
EndProcedure

Function ItemsTreeNewParameters() Export
	
	WorkMode = PredefinedValue("Enum.NewItemsTreeDisplayModes.ReportTypeSetting");
	TreeParameters = New Structure;
	TreeParameters.Insert("TreeItemName", "NewItemsTree");
	TreeParameters.Insert("WorkMode", WorkMode);
	TreeParameters.Insert("QuickSearch", "");
	TreeParameters.Insert("ReportTypeFilter");
	TreeParameters.Insert("CurrentReportType");
	Return TreeParameters;
	
EndFunction

Function MinimalPeriodicity(PeriodicityList) Export
	
	Result = Undefined;
	
	PeriodicitySorted = PeriodicitySorted();
	For Each Periodicity In PeriodicitySorted Do 
		If ValueIsFilled(Periodicity) And PeriodicityList.Find(Periodicity) <> Undefined Then
			Result = Periodicity;
			Break;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function PeriodicitySorted() Export
	
	PeriodicityList = New Array;
	
	PeriodicityList.Add(PredefinedValue("Enum.Periodicity.EmptyRef"));
	PeriodicityList.Add(PredefinedValue("Enum.Periodicity.Day"));
	PeriodicityList.Add(PredefinedValue("Enum.Periodicity.Week"));
	PeriodicityList.Add(PredefinedValue("Enum.Periodicity.TenDays"));
	PeriodicityList.Add(PredefinedValue("Enum.Periodicity.Month"));
	PeriodicityList.Add(PredefinedValue("Enum.Periodicity.Quarter"));
	PeriodicityList.Add(PredefinedValue("Enum.Periodicity.HalfYear"));
	PeriodicityList.Add(PredefinedValue("Enum.Periodicity.Year"));
	
	Return PeriodicityList;
	
EndFunction

Function LeftPartOfNameCoincides(Name, RequiredString) Export
	
	Return Left(Name, StrLen(RequiredString)) = RequiredString;
	
EndFunction

Function ReportItemStructure() Export
	
	Result = New Structure;
	// Standard attributes
	Result.Insert("Ref");
	Result.Insert("Owner");
	Result.Insert("Description");
	Result.Insert("Code");
	
	// Attributes
	Result.Insert("ItemType");
	Result.Insert("DescriptionForPrinting");
	Result.Insert("ReverseSign");
	Result.Insert("Comment");
	Result.Insert("AdditionalFilter");
	Result.Insert("HasSettings");
	Result.Insert("AnalyticsValue");
	Result.Insert("LinkedItem");
	
	// Tabular sections
	Result.Insert("ItemTypeAttributes");
	Result.Insert("FormulaOperands");
	Result.Insert("TableItems");
	Result.Insert("AdditionalFields");
	
	Result.Insert("AppearanceItems");
	Result.Insert("AppearanceAppliedRows");
	Result.Insert("AppearanceAppliedColumns");
	Result.Insert("AppearanceItemsFilterFieldsDetails");
	Result.Insert("ValuesSources");
	
	Return Result;
	
EndFunction

Function GetStyleColor(LocalCache, ColorName) Export
	Var Color;
	
	If LocalCache = Undefined Then
		LocalCache = New Structure;
	EndIf;
	
	If LocalCache.Property(ColorName, Color) Then
		Return Color;
	EndIf;
	
	Color = FinancialReportingServerCall.GetColor(ColorName);
	LocalCache.Insert(ColorName, Color);
	
	Return Color;
	
EndFunction

Function ReportGenerationNewParameters() Export
	
	ReportParemeters = New Structure;
	ReportParemeters.Insert("PeriodType");
	ReportParemeters.Insert("BeginOfPeriod");
	ReportParemeters.Insert("EndOfPeriod");
	ReportParemeters.Insert("Company");
	ReportParemeters.Insert("BusinessUnit");
	ReportParemeters.Insert("LineOfBusiness");
	ReportParemeters.Insert("OpenForms", False);
	ReportParemeters.Insert("OpenFormsFlag", False);
	ReportParemeters.Insert("AmountsInThousands", False);
	ReportParemeters.Insert("IndicatorsType");
	
	Return ReportParemeters;
	
EndFunction

Procedure HideSettingsUponReportGeneration(Form, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		HideSettingsUponReportGeneration = Form.HideSettingsUponReportGeneration;
		SettingsPanel = Form.Items.GroupSettingsPanel;
		SettingsPanelButton = Form.Items.SettingsPanel;
	Else
		HideSettingsUponReportGeneration = AdditionalParameters.HideSettingsUponReportGeneration;
		SettingsPanel = Form.Items[AdditionalParameters.GroupSettingsPanelName];
		If AdditionalParameters.Property("SettingsPanel") Then
			SettingsPanelButton = Form.Items[AdditionalParameters.SettingsPanelName];
		Else
			SettingsPanelButton = Undefined;
		EndIf;
	EndIf;
	
	If HideSettingsUponReportGeneration Then
		If SettingsPanel.Visible Then
			Form.Report.SettingsComposer.UserSettings.AdditionalProperties.Insert("SettingsPanelHiddenAutomatically", True);
		EndIf;
		SettingsPanel.Visible = False;
		If SettingsPanelButton <> Undefined Then
			ChangeSettingsPanelButtonTitle(SettingsPanelButton, False);
		EndIf;
	EndIf;
	
EndProcedure

Procedure ChangeSettingsPanelButtonTitle(Button, SettingsPanelVisibility) Export
	
	If SettingsPanelVisibility Then
		Button.Title = NStr("en = 'Hide settings'; ru = 'Скрыть настройки';pl = 'Nie pokazuj ustawień';es_ES = 'Ocultar las configuraciones';es_CO = 'Ocultar las configuraciones';tr = 'Ayarları gizle';it = 'Nascondi impostazioni';de = 'Einstellungen ausblenden'");
	Else
		Button.Title = NStr("en = 'Show settings'; ru = 'Показывать настройки';pl = 'Pokaż ustawienia';es_ES = 'Mostrar las configuraciones';es_CO = 'Mostrar las configuraciones';tr = 'Ayarları göster';it = 'Mostra impostazioni';de = 'Einstellungen anzeigen'");
	EndIf;
	
EndProcedure

Procedure AddRowsToTree(SourceRows, RecipientRows) Экспорт
	
	AddedSourceRows = ChildItems(SourceRows);
	AddedRecipientRows = ChildItems(RecipientRows);
	FieldsControl = New Structure("NonstandardPicture, IsLinked");
	For Each SourceRow In AddedSourceRows Do
		
		NewRow = AddedRecipientRows.Add();
		FillPropertyValues(NewRow, SourceRow);
		FillPropertyValues(FieldsControl, NewRow);
		
		If FieldsControl.NonstandardPicture <> Undefined
			And FieldsControl.IsLinked <> Undefined Then
			NewRow.NonstandardPicture = NewRow.NonstandardPicture + Number(NewRow.IsLinked);
		EndIf;
		
		AddRowsToTree(SourceRow, NewRow);
		
	EndDo;
	
EndProcedure

Function NewOperandData() Export
	
	ReportParameters = New Structure;
	ReportParameters.Insert("ItemStructureAddress","");
	ReportParameters.Insert("ID","");
	ReportParameters.Insert("NonstandardPicture");
	ReportParameters.Insert("ItemType");
	ReportParameters.Insert("ReportItem");
	ReportParameters.Insert("DescriptionForPrinting", "");
	ReportParameters.Insert("AccountIndicatorDimension");
	ReportParameters.Insert("Account");
	ReportParameters.Insert("TotalsType");
	ReportParameters.Insert("OpeningBalance", False);
	ReportParameters.Insert("UserDefinedFixedIndicator");
	ReportParameters.Insert("HasSettings", False);
	ReportParameters.Insert("IsLinked", False);
	ReportParameters.Insert("LinkedItem");
	ReportParameters.Insert("Code", "");
	Return ReportParameters;
	
EndFunction

Function SplitFieldAndAttributeNames(FieldName) Export
	
	Result = New Structure("Name, Attribute", "", "");
	NamesArray = StrSplit(FieldName, ".");
	If NamesArray.Count() > 0 Then
		Result.Name = NamesArray[0];
	EndIf;
	
	If NamesArray.Count() > 1 Then
		NamesArray.Delete(0);
		Result.Attribute = StrConcat(NamesArray, ".");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region Private

Function DefineDimensionTypeByValueType(Value, AdditionalParameters = Undefined)
	
	If TypeOf(Value) = Type("EnumRef.Periodicity") Then
		
		Return DimensionType("Period");
		
	ElsIf TypeOf(Value) = Type("ChartOfCharacteristicTypesRef.ManagerialAnalyticalDimensionTypes")
		Or TypeOf(Value) = Type("ChartOfCharacteristicTypesRef.FinancialAnalyticalDimensionTypes") Then
		
		Return DimensionType("AnalyticalDimension");
		
	ElsIf TypeOf(Value) = Type("String") Then
		
		Return DimensionType("AccountingRegisterDimension");
		
	Else
		
		Raise NStr("en = 'Unknown type of financial report dimension'; ru = 'Неизвестный тип измерения финансового отчета';pl = 'Nieznany typ wymiaru raportu finansowego';es_ES = 'Tipo desconocido de dimensión del informe financiero';es_CO = 'Tipo desconocido de dimensión del informe financiero';tr = 'Bilinmeyen mali rapor boyut türü';it = 'Tipo sconosciuto della dimensione del report finanziario';de = 'Unbekannte Art der Finanzberichtsdimension'");
		
	EndIf;
	
EndFunction

Function ItemType(ItemTypeName)
	
	Return PredefinedValue("Enum.FinancialReportItemsTypes."+ItemTypeName);
	
EndFunction

Function DimensionType(ItemTypeName)
	
	Return PredefinedValue("Enum.FinancialReportDimensionTypes." + ItemTypeName);
	
EndFunction

#EndRegion