#Region Variables

&AtClient
Var ListItemBeforeStartChangingAtClient;
&AtClient
Var DraggingSourceAtClient;
&AtClient
Var FillingParametersAtClient;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	ParametersForm = New Structure(
		"PurposeUseKey, UserSettingsKey,
		|Details, GenerateOnOpen, ReadOnly,
		|FixedSettings, Section, Subsystem, SubsystemPresentation");
	FillPropertyValues(ParametersForm, Parameters);
	ParametersForm.Insert("Filter", New Structure);
	If TypeOf(Parameters.Filter) = Type("Structure") Then
		CommonClientServer.SupplementStructure(ParametersForm.Filter, Parameters.Filter, True);
		Parameters.Filter.Clear();
	EndIf;
	
	If Not Parameters.Property("ReportSettings", ReportSettings) Then
		Raise NStr("en = 'The ""ReportSettings"" service parameter is not passed.'; ru = 'Не передан служебный параметр ""ReportSettings"".';pl = 'Nie przekazano parametru serwisowego ""ReportSettings"".';es_ES = 'Parámetro de servicio ReportSettings no está pasado.';es_CO = 'Parámetro de servicio ReportSettings no está pasado.';tr = 'Servis parametresi ReportSettings geçmedi.';it = 'Il parametro di servizio ""ReportSettings"" non è stato trasmesso.';de = 'Der Serviceparameter ""ReportSettings"" ist nicht bestanden.'");
	EndIf;
	If Not Parameters.Property("DescriptionOption", DescriptionOption) Then
		Raise NStr("en = 'The ""OptionDescription"" service parameter is not passed.'; ru = 'Не передан служебный параметр ""OptionDescription"".';pl = 'Nie przekazano parametru serwisowego ""OptionDescription"".';es_ES = 'Parámetro de servicio VariantName no está pasado.';es_CO = 'Parámetro de servicio VariantName no está pasado.';tr = 'Servis parametresi OptionDescription geçmedi.';it = 'Il parametro di servizio ""OptionDescription"" non è stato trasmesso.';de = 'Der Serviceparameter ""OptionDescription"" ist nicht bestanden.'");
	EndIf;
	Parameters.Property("CurrentDCNodeID", CurrentDCNodeID);
	WindowOptionsKey = ReportSettings.FullName;
	If ValueIsFilled(CurrentVariantKey) Then
		WindowOptionsKey = WindowOptionsKey + "." + CurrentVariantKey;
	EndIf;
	If CurrentDCNodeID <> Undefined Then
		FullPath = CommonClientServer.StructureProperty(Parameters, "FullPathToCurrentDCNode");
		DCSettings = CommonClientServer.StructureProperty(Parameters, "Variant");
		If DCSettings = Undefined Then
			DCSettings = Report.SettingsComposer.Settings;
		EndIf;
		RootNode = ReportsClientServer.FindItemByFullPath(DCSettings, FullPath);
		If RootNode <> Undefined Then
			CurrentDCNodeID = DCSettings.GetIDByObject(RootNode);
		EndIf;
		OptionNodeChangeMode = True;
		Height = 0;
		WindowOptionsKey = WindowOptionsKey + ".Node";
		If Not Parameters.Property("Title", Title) Then
			Raise NStr("en = 'Service parameter ""Title"" is not transferred.'; ru = 'Не передан служебный параметр ""Title"".';pl = 'Nie przesłano parametru serwisowego ""Title"".';es_ES = 'Parámetro de servicio ""Título"" no se ha transferido.';es_CO = 'Parámetro de servicio ""Título"" no se ha transferido.';tr = 'Servis parametresi ""Başlık"" aktarılmaz.';it = 'Il parametro di servizio ""Titolo"" non viene trasmesso.';de = 'Der Serviceparameter ""Titel"" wird nicht übertragen.'");
		EndIf;
		If Not Parameters.Property("CurrentDCNodeType", CurrentDCNodeType) Then
			Raise NStr("en = 'The ""CurrentNodeTypeDC"" service parameter is not passed.'; ru = 'Не передан служебный параметр ""CurrentNodeTypeDC"".';pl = 'Nie przekazano parametru serwisowego ""CurrentNodeTypeDC"".';es_ES = 'Parámetro de servicio CurrentDCNode no está pasado.';es_CO = 'Parámetro de servicio CurrentDCNode no está pasado.';tr = 'Servis parametresi CurrentNodeTypeDC geçmedi.';it = 'Il parametro di servizio ""CurrentNodeTypeDC"" non è stato trasmesso.';de = 'Der Serviceparameter ""CurrentNodeTypeDC"" ist nicht bestanden.'");
		EndIf;
	Else
		If Not ValueIsFilled(DescriptionOption) Then
			DescriptionOption = ReportSettings.Description;
		EndIf;
		Title = NStr("en = 'Report settings'; ru = 'Настройки отчетов';pl = 'Ustawienia raportu';es_ES = 'Configuraciones de informe';es_CO = 'Configuraciones de informe';tr = 'Rapor ayarları';it = 'Impostazioni del report';de = 'Berichteinstellungen'") + " """ + DescriptionOption + """";
	EndIf;
	
	Items.ExtendedMode.Visible = ReportSettings.EditOptionsAllowed;
	
	If OptionNodeChangeMode Then
		PageName = CommonClientServer.StructureProperty(Parameters, "PageName", "GroupingContentPage");
		ExtendedMode = 1;
	Else
		ExtendedMode = CommonClientServer.StructureProperty(ReportSettings, "SettingsFormAdvancedMode", 0);
		PageName = CommonClientServer.StructureProperty(ReportSettings, "SettingsFormPageName", "FiltersPage");
	EndIf;
	Page = Items.Find(PageName);
	If Page <> Undefined Then
		Items.SettingsPages.CurrentPage = Page;
	EndIf;
	
	If ReportSettings.SchemaModified Then
		Report.SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(ReportSettings.SchemaURL));
	EndIf;
	
	InactiveTableValueColor = StyleColors.InaccessibleCellTextColor;
	
	// Register commands and form attributes that will not be deleted when overwriting quick settings.
	SetOfAttributes = GetAttributes();
	For Each Attribute In SetOfAttributes Do
		ConstantAttributes.Add(FullAttributeName(Attribute));
	EndDo;
	For Each Command In Commands Do
		ConstantCommands.Add(Command.Name);
	EndDo;
	
	SettingsUpdateRequired = True;
	
	ReportName = StrReplace(ReportSettings.FullName, "Report.", "");
	
	SetAccountingConditionalAppearance("AccountingGroupingTable");
	SetAccountingConditionalAppearance("AccountingGroupingByAnalyticalDimensionTypesTable");
	
EndProcedure

&AtServer
Procedure BeforeLoadVariantAtServer(Settings)
	
	If TypeOf(ParametersForm.Filter) = Type("Structure") Then
		ReportsServer.SetFixedFilters(ParametersForm.Filter, Settings, ReportSettings);
	EndIf;
	
	SettingsUpdateRequired = True;
	
	// Prepare for calling the reinitialization event.
	If ReportSettings.Events.BeforeImportSettingsToComposer Then
		Try
			NewXMLSettings = Common.ValueToXMLString(Settings);
		Except
			NewXMLSettings = Undefined;
		EndTry;
		ReportSettings.Insert("NewXMLSettings", NewXMLSettings);
	EndIf;
EndProcedure

&AtServer
Procedure BeforeLoadUserSettingsAtServer(Settings)
	
	SettingsUpdateRequired = True;
	
	// Prepare for calling the reinitialization event.
	If ReportSettings.Events.BeforeImportSettingsToComposer Then
		Try
			NewUserXMLSettings = Common.ValueToXMLString(Settings);
		Except
			NewUserXMLSettings = Undefined;
		EndTry;
		ReportSettings.Insert("NewUserXMLSettings", NewUserXMLSettings);
	EndIf;
EndProcedure

&AtServer
Procedure OnUpdateUserSettingSetAtServer(StandardProcessing)
	
	StandardProcessing = False;
	VariantModified = False;
	
	If SettingsUpdateRequired Then
		SettingsUpdateRequired = False;
		
		FillingParameters = New Structure;
		FillingParameters.Insert("EventName", "OnCreateAtServer");
		If Not OptionNodeChangeMode AND ExtendedMode = 1 Then
			FillingParameters.Insert("UpdateOptionSettings", True);
		EndIf;
		QuickSettingsFill(FillingParameters);
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	ShowSettingsFillingResult();
	SetReportSettings();
	Items.SettingsComposerSettingsFilterGroupFilterItems.Enabled = Report.SettingsComposer.Settings.Filter.Items.Count() > 0;
	OnOpenAtServer();
EndProcedure

&AtServer
Procedure OnOpenAtServer()
	If Items.Find("SettingsComposerSettingsFilterRightValue") <> Undefined Then
		
		FilterItem = Items.SettingsComposerSettingsFilterRightValue;
		
		FilterItem.SetAction("StartChoice", "Attachable_FilterValue_StartChoice");
	EndIf;
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If CheckErrors() Then
		Cancel = True;
		Return;
	EndIf;
	
	VariantModified = False;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	If SelectionResultGenerated Then
		Return;
	EndIf;
	
	If OnCloseNotifyDescription <> Undefined Then
		ExecuteNotifyProcessing(OnCloseNotifyDescription, SelectionResult(False));
	EndIf;

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ExtendedModeOnChange(Item)
	FillingParameters = New Structure;
	FillingParameters.Insert("EventName", "ExtendedModeOnChange");
	If ExtendedMode = 1 Then
		FillingParameters.Insert("UpdateOptionSettings", True);
	Else
		FillingParameters.Insert("ResetUserSettings", True);
	EndIf;
	FillQuickSettingsClient(FillingParameters);
EndProcedure

&AtClient
Procedure TooltipNoUserSettingsURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	ExtendedMode = True;
	ExtendedModeOnChange(Undefined);
EndProcedure

&AtClient
Procedure CurrentDCNodeChartTypeOnChange(Item)
	RootDCNode = Report.SettingsComposer.Settings.GetObjectByID(CurrentDCNodeID);
	If TypeOf(RootDCNode) = Type("DataCompositionNestedObjectSettings") Then
		RootDCNode = RootDCNode.Settings;
	EndIf;
	SetOutputParameter(RootDCNode, "ChartType", CurrentDCNodeChartType);
	
	UserSettingsModified = True;
	VariantModified = False;
	If ExtendedMode = 1 Then
		OptionChanged = True;
	EndIf;
EndProcedure

&AtClient
Procedure TooltipHasNestedReportsURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	TableRow = Items.OptionStructure.CurrentData;
	ChangeOptionNode(TableRow, Undefined, True);
EndProcedure

#Region AttachableObjects

&AtClient
Procedure Attachable_UsageCheckBox_OnChange(Item)
	CheckBoxName = Item.Name;
	ItemID = Right(CheckBoxName, 32);
	Type = Left(CheckBoxName, StrFind(CheckBoxName, "_")-1);
	
	DCUserSetting = FindUserSettingOfItem(ItemID);
	
	If Type = "FilterItem" Or Type = "ParameterValue" Then
		TableName = Type + "_ValueList_" + ItemID;
		FormTable = Items.Find(TableName);
		If FormTable <> Undefined Then
			FormTable.TextColor = ?(DCUserSetting.Use, New Color, InactiveTableValueColor);
		EndIf;
	EndIf;
	
	ReportsClient.RecordChangesInSubordinateItems(ThisObject, ItemID, DCUserSetting);
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		FoundItems = FindOptionSetting(ThisObject, ItemID);
		If FoundItems <> Undefined Then
			FoundItems.DCItem.Use = DCUserSetting.Use;
			OptionChanged = True;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_InputField_OnChange(Item)
	
	ClearMessages();
	
	ItemID = Right(Item.Name, 32);
	                      
	DCUserSetting = FindUserSettingOfItem(ItemID);
	If TypeOf(DCUserSetting) = Type("DataCompositionSettingsParameterValue") Then
		Value = DCUserSetting.Value;
		If ReportSettings.FullName = "Report.UniversalReport" Then
			UpdateUniversalReportParameters(DCUserSetting);
		EndIf;
		
		ParameterChangeAtServer(ItemID);
		
	ElsIf TypeOf(DCUserSetting) = Type("DataCompositionFilterItem") Then
		Value = DCUserSetting.RightValue;
	Else
		Return;
	EndIf;
	
	If ValueIsFilled(Value) Then
		DCUserSetting.Use = True;
	EndIf;
	
	ReportsClient.RecordChangesInSubordinateItems(ThisObject, ItemID, DCUserSetting);
	
	UserSettingsModified = True;
	
EndProcedure

&AtClient
Procedure Attachable_ValueCheckBox_OnChange(Item)
	ItemID = Right(Item.Name, 32);
	Value = ThisObject[Item.Name];
	
	DCUserSetting = FindUserSettingOfItem(ItemID);
	If TypeOf(DCUserSetting) = Type("DataCompositionSettingsParameterValue") Then
		DCUserSetting.Value = Value;
	Else
		DCUserSetting.RightValue = Value;
	EndIf;
	
	UserSettingsModified = True;
EndProcedure

&AtClient
Procedure Attachable_ComposerList_StartChoice(Item, ChoiceData, StandardProcessing)	
	ReportsClient.ComposerListStartChoice(ThisObject, Item, ChoiceData, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ComposerValue_StartChoice(Item, ChoiceData, StandardProcessing)
	ReportsClient.ComposerValueStartChoice(ThisObject, Item, ChoiceData, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_FilterValue_StartChoice(Item, ChoiceData, StandardProcessing)
	
	ChoiceParameters = New Array;
	
	ChartOfAccountsValue = Undefined;
	
	CurrentData = Items.SettingsComposerSettingsFilter.CurrentData;
	
	TypeDescriptionMaster = New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts");
	
	If CurrentData <> Undefined Then
		If TypeOf(CurrentData.RightValue) = Type("ChartOfAccountsRef.MasterChartOfAccounts")
			Or (TypeOf(CurrentData.RightValue) = Type("ValueList")
				And CurrentData.RightValue.ValueType = TypeDescriptionMaster) Then
			
			ChartOfAccountsValue = GetCurrentChartOfAccounts();
			
		EndIf;
	EndIf;
	
	If ValueIsFilled(ChartOfAccountsValue) Then
		ChoiceParameters.Add(New ChoiceParameter("Filter.ChartOfAccounts", ChartOfAccountsValue));
	EndIf;
	
	ChoiceParametersFixed = New FixedArray(ChoiceParameters);
	
	Items.SettingsComposerSettingsFilterRightValue.ChoiceParameters = ChoiceParametersFixed;
	
EndProcedure

#EndRegion

#Region AttachableObjectsStandardPeriod

&AtClient
Procedure Attachable_StandardPeriod_PeriodStart_OnChange(Item)
	// Generate information on the item.
	StartPeriodName = Item.Name;
	ValueName     = StrReplace(StartPeriodName, "_Start_", "_Value_");
	ItemID = Right(StartPeriodName, 32);
	
	Value = ThisObject[ValueName];
	Filled = ValueIsFilled(Value.StartDate);
	If Filled Then
		Value.StartDate = BegOfDay(Value.StartDate);
	EndIf;
	
	// Write a value to data composition user settings.
	DCUserSetting = FindUserSettingOfItem(ItemID);
	If TypeOf(DCUserSetting) = Type("DataCompositionSettingsParameterValue") Then
		DCUserSetting.Value = Value;
	Else
		DCUserSetting.RightValue = Value;
	EndIf;
	If Filled Then
		DCUserSetting.Use = True;
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_StandardPeriod_PeriodEnd_OnChange(Item)
	// Generate information on the item.
	EndPeriodName = Item.Name;
	ValueName        = StrReplace(EndPeriodName, "_End_", "_Value_");
	ItemID = Right(EndPeriodName, 32);
	
	Value = ThisObject[ValueName];
	Filled = ValueIsFilled(Value.EndDate);
	If Filled Then
		Value.EndDate = EndOfDay(Value.EndDate);
	EndIf;
	
	// Write a value to data composition user settings.
	DCUserSetting = FindUserSettingOfItem(ItemID);
	If TypeOf(DCUserSetting) = Type("DataCompositionSettingsParameterValue") Then
		DCUserSetting.Value = Value;
	Else
		DCUserSetting.RightValue = Value;
	EndIf;
	If Filled Then
		DCUserSetting.Use = True;
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_SelectPeriod(Command)
	ReportsClient.SelectPeriod(ThisObject, Command.Name);
EndProcedure

#EndRegion

#Region AttachableListWithPicking

&AtClient
Procedure Attachable_ListWithPicking_OnChange(FormTable)
	// Update selected values in DCS data.
	ItemID = Right(FormTable.Name, 32);
	
	ValueListInForm = ThisObject[FormTable.Name];
	DCUserSetting = FindUserSettingOfItem(ItemID);
	AdditionalSettings = FindAdditionalItemSettings(ItemID);
	
	ValueListInDCS = New ValueList;
	If Not AdditionalSettings.RestrictSelectionBySpecifiedValues Then
		AdditionalSettings.ValuesForSelection = New ValueList;
	EndIf;
	For Each ListItemInForm In ValueListInForm Do
		ValueInForm = ListItemInForm.Value;
		If Not AdditionalSettings.RestrictSelectionBySpecifiedValues Then
			If AdditionalSettings.ValuesForSelection.FindByValue(ValueInForm) <> Undefined Then
				Continue;
			EndIf;
			FillPropertyValues(AdditionalSettings.ValuesForSelection.Add(), ListItemInForm);
		EndIf;
		If ListItemInForm.Check Then
			ValueListInDCS.Add(ValueInForm);
		EndIf;
	EndDo;
	If TypeOf(DCUserSetting) = Type("DataCompositionFilterItem") Then
		DCUserSetting.RightValue = ValueListInDCS;
	Else
		DCUserSetting.Value = ValueListInDCS;
	EndIf;
	
	// Enable the Usage check box.
	DCUserSetting.Use = True;
	FormTable.TextColor = ?(DCUserSetting.Use, New Color, InactiveTableValueColor);
	
	UserSettingsModified = True;
EndProcedure

&AtClient
Procedure Attachable_ListWithPicking_Use_OnChange(Item)
	// Enable the Usage check box if the user selected the check box in the table row.
	UsageColumnName = Item.Name;
	ItemID   = Right(UsageColumnName, 32);
	SettingPropertiesType    = Left(UsageColumnName, StrFind(UsageColumnName, "_Column_Usage_")-1);
	
	TableName       = SettingPropertiesType + "_ValueList_" + ItemID;
	
	ListItemInForm = Items[TableName].CurrentData;
	If ListItemInForm <> Undefined AND ListItemInForm.Check Then
		// Enable the Usage check box.
		DCUserSetting = FindUserSettingOfItem(ItemID);
		DCUserSetting.Use = True;
		
		// Rows appearance.
		FormTable = Items.Find(TableName);
		FormTable.TextColor = ?(DCUserSetting.Use, New Color, InactiveTableValueColor);
		
		UserSettingsModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_ListWithPicking_OnEditStart(Item, NewRow, Copy)
	// Set references and filter parameters.
	FilterParameters = ReportsClient.FilterSelectionParameters(ThisObject, Item);
	ValueColumn = Items.Find(StrReplace(Item.Name, "_ValueList_", "_Column_Value_"));
	ValueColumn.ChoiceParameters = New FixedArray(FilterParameters.ChoiceParameters);
	ValueColumn.AvailableTypes   = New TypeDescription(FilterParameters.TypeDescription);
	
	// Save the state "before changing".
	IDRow = Item.CurrentRow;
	If IDRow = Undefined Then
		Return;
	EndIf;
	
	ValueListInForm = ThisObject[Item.Name];
	ListItemInForm = ValueListInForm.FindByID(IDRow);
	
	CurrentRow = Item.CurrentData;
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	
	If NewRow Then
		ListItemInForm.Check = True;
	EndIf;
	
	ListItemBeforeStartChanging = New Structure("ID, Check, Value, Presentation");
	FillPropertyValues(ListItemBeforeStartChanging, ListItemInForm);
	ListItemBeforeStartChanging.ID = IDRow;
	ListItemBeforeStartChangingAtClient = ListItemBeforeStartChanging;
EndProcedure

&AtClient
Procedure Attachable_ListWithPicking_BeforeEditEnd(Item, NewRow, CancelEditStart, CancelEditComplete)
	If CancelEditStart Then
		Return;
	EndIf;
	
	IDRow = Item.CurrentRow;
	If IDRow = Undefined Then
		Return;
	EndIf;
	ItemID = Right(Item.Name, 32);
	ValueListInForm  = ThisObject[Item.Name];
	ListItemInForm   = ValueListInForm.FindByID(IDRow);
	
	Value = ListItemInForm.Value;
	If Value = Undefined
		Or Value = Type("Undefined")
		Or Value = New TypeDescription("Undefined")
		Or Not ValueIsFilled(Value) Then
		CancelEditComplete = True; // Empty values are prohibited.
	Else
		For Each ListItemDuplicateInForm In ValueListInForm Do
			If ListItemDuplicateInForm.Value = Value AND ListItemDuplicateInForm <> ListItemInForm Then
				CancelEditComplete = True; // Duplicates are prohibited.
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	ListItemBeforeStartChanging = ListItemBeforeStartChangingAtClient;
	HasInformation = (ListItemBeforeStartChanging <> Undefined AND ListItemBeforeStartChanging.ID = IDRow);
	If Not CancelEditComplete AND HasInformation AND ListItemBeforeStartChanging.Value <> Value Then
		AdditionalSettings = FindAdditionalItemSettings(ItemID);
		If AdditionalSettings.RestrictSelectionBySpecifiedValues Then
			CancelEditComplete = True;
		Else
			ListItemInForm.Presentation = ""; // Autofill a presentation.
			ListItemInForm.Check = True; // Select a check box.
		EndIf;
	EndIf;
	
	If CancelEditComplete Then
		// Roll back values.
		If HasInformation Then
			FillPropertyValues(ListItemInForm, ListItemBeforeStartChanging);
		EndIf;
		// Restart the "BeforeEditEnd" event with CancelEditStart = True.
		Item.EndEditRow(True);
	Else
		If NewRow Then
			ListItemInForm.Check = True; // Select a check box.
		EndIf;
		UserSettingsModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_ListWithPicking_Pick(Command)
	PickButtonName = Command.Name;
	
	ItemID  = Right(PickButtonName, 32);
	SettingPropertiesType = Left(PickButtonName, StrFind(PickButtonName, "_Selection_")-1);
	
	TableName         = SettingPropertiesType + "_ValueList_"   + ItemID;
	ColumnValueName = SettingPropertiesType + "_Column_Value_" + ItemID;
	PickButtonName    = SettingPropertiesType + "_Selection_"  + ItemID;
	
	TableValue = ThisObject[TableName];
	ValueColumnItem = Items[ColumnValueName];
	
	TypesDetails = TableValue.ValueType;
	
	ItemParameters = New Structure;
	ItemParameters.Insert("ItemID",  ItemID);
	ItemParameters.Insert("SelectedType",           Undefined);
	ItemParameters.Insert("ValueColumnItem", ValueColumnItem);
	ItemParameters.Insert("TableItem",         Items[TableName]);
	ItemParameters.Insert("SelectGroupsOnly",       ValueColumnItem.ChoiceFoldersAndItems = FoldersAndItems.Folders);
	ItemParameters.Insert("ChoiceParameters",        New Array);
	
	FoundItems = LinksThatCanBeDisabled.FindRows(New Structure("SubordinateIDInForm", ItemID));
	For Each Link In FoundItems Do
		If Not ValueIsFilled(Link.MainIDInForm)
			Or Not ValueIsFilled(Link.SubordinateParameterName) Then
			Continue;
		EndIf;
		MasterDCSetting = FindUserSettingOfItem(Link.MainIDInForm);
		If Not MasterDCSetting.Use Then
			Continue;
		EndIf;
		If TypeOf(MasterDCSetting) = Type("DataCompositionFilterItem") Then
			MasterValue = MasterDCSetting.RightValue;
		Else
			MasterValue = MasterDCSetting.Value;
		EndIf;
		If Link.LinkType = "SelectionParameters" Then
			ItemParameters.ChoiceParameters.Add(New ChoiceParameter(Link.SubordinateParameterName, MasterValue));
		ElsIf Link.LinkType = "ByType" Then
			MasterType = TypeOf(MasterValue);
			If TypesDetails.ContainsType(MasterType) Then
				ItemParameters.SelectedType = MasterType;
			EndIf;
		EndIf;
	EndDo;
	
	If ItemParameters.SelectedType <> Undefined Then // The type is defined by the master object.
		Attachable_ListWithPicking_Pick_OpenChoiceForm(-1, ItemParameters);
		Return;
	EndIf;
	
	// Select type from the list.
	ChoiceList = New ValueList;
	
	SimpleTypes = New Map;
	SimpleTypes.Insert(Type("String"), True);
	SimpleTypes.Insert(Type("Date"),   True);
	SimpleTypes.Insert(Type("Number"),  True);
	
	TypesArray = TypesDetails.Types();
	For Each Type In TypesArray Do
		// Exclude types if there are no groups for them.
		If ItemParameters.SelectGroupsOnly Then
			MetadataObjectName = QuickSearchForMetadataObjectsNames.Get(Type);
			MetadataObjectKind = Upper(Left(MetadataObjectName, StrFind(MetadataObjectName, ".")-1));
			If MetadataObjectKind <> "CATALOG" AND MetadataObjectKind <> "CHARTOFCHARACTERISTICTYPES" AND MetadataObjectKind <> "CHARTOFACCOUNTS" Then
				Continue;
			EndIf;
		EndIf;
		// Exclude simple types.
		If SimpleTypes[Type] = True Then
			Continue;
		EndIf;
		// Add a type to the choice list.
		ChoiceList.Add(Type, String(Type));
	EndDo;
	
	If ChoiceList.Count() = 0 Then
		ItemParameters.TableItem.AddRow();
		Return;
	ElsIf ChoiceList.Count() = 1 Then
		// There is only one type, no need to select.
		ItemParameters.SelectedType = ChoiceList[0].Value;
		Attachable_ListWithPicking_Pick_OpenChoiceForm(-1, ItemParameters);
	Else
		// There is more than one type.
		Handler = New NotifyDescription("Attachable_ListWithPicking_Pick_OpenChoiceForm", ThisObject, ItemParameters);
		ShowChooseFromMenu(Handler, ChoiceList, Items[PickButtonName]);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ListWithPicking_Pick_OpenChoiceForm(SelectedItem, ItemParameters) Export
	If SelectedItem = Undefined Then
		Return;
	ElsIf SelectedItem <> -1 Then
		ItemParameters.SelectedType = SelectedItem.Value;
	EndIf;
	
	ValueColumnItem = ItemParameters.ValueColumnItem;
	
	// Full name of the choice form.
	// The "ChoiceForm" property is unavailable on the client even in the read-only mode. Therefore, to 
	//   store predefined choice form names, use the QuickSearchForMetadataObjectsNames collection.
	FormPath = QuickSearchForMetadataObjectsNames.Get(ItemParameters.ItemID);
	If Not ValueIsFilled(FormPath) Then
		MetadataObjectName = QuickSearchForMetadataObjectsNames.Get(ItemParameters.SelectedType);
		If ItemParameters.SelectGroupsOnly Then
			MetadataObjectKind = Upper(Left(MetadataObjectName, StrFind(MetadataObjectName, ".")-1));
			If MetadataObjectKind = "CATALOG" Or MetadataObjectKind = "CHARTOFCHARACTERISTICTYPES" Then
				FormPath = MetadataObjectName + ".FolderChoiceForm";
			Else
				FormPath = MetadataObjectName + ".ChoiceForm";
			EndIf;
		Else
			FormPath = MetadataObjectName + ".ChoiceForm";
		EndIf;
	EndIf;
	
	ChoiceOfGroupsAndItems = ReportsClientServer.CastValueToGroupsAndItemsUsageType(ValueColumnItem.ChoiceFoldersAndItems);
	
	ChoiceFormParameters = New Structure;
	// Standard parameters of the form.
	ChoiceFormParameters.Insert("CloseOnChoice",            False);
	ChoiceFormParameters.Insert("CloseOnOwnerClose", True);
	ChoiceFormParameters.Insert("Filter",                         New Structure);
	// Standard parameters of the choice form (see Managed form extension for dynamic list).
	ChoiceFormParameters.Insert("ChoiceFoldersAndItems",          ChoiceOfGroupsAndItems);
	ChoiceFormParameters.Insert("MultipleChoice",            True);
	ChoiceFormParameters.Insert("ChoiceMode",                   True);
	// Supposed attributes.
	ChoiceFormParameters.Insert("WindowOpeningMode",             FormWindowOpeningMode.LockOwnerWindow);
	ChoiceFormParameters.Insert("EnableStartDrag", False);
	
	// Add fixed choice parameters.
	For Each ChoiceParameter In ValueColumnItem.ChoiceParameters Do
		If IsBlankString(ChoiceParameter.Name) Then
			Continue;
		EndIf;
		If ValueIsFilled(ChoiceParameter.Name) Then
			If Upper(Left(ChoiceParameter.Name, 6)) = Upper("Filter.") Then
				ChoiceFormParameters.Filter.Insert(Mid(ChoiceParameter.Name, 7), ChoiceParameter.Value);
			Else
				ChoiceFormParameters.Insert(ChoiceParameter.Name, ChoiceParameter.Value);
			EndIf;
		EndIf;
	EndDo;
	
	// Add dynamic choice parameters (from master objects). For backward compatibility.
	For Each ChoiceParameterLink In ValueColumnItem.ChoiceParameterLinks Do
		If IsBlankString(ChoiceParameterLink.Name) Then
			Continue;
		EndIf;
		MasterValue = ThisObject[ChoiceParameterLink.DataPath];
		If Upper(Left(ChoiceParameterLink.Name, 6)) = Upper("Filter.") Then
			ChoiceFormParameters.Filter.Insert(Mid(ChoiceParameterLink.Name, 7), MasterValue);
		Else
			ChoiceFormParameters.Insert(ChoiceParameterLink.Name, MasterValue);
		EndIf;
	EndDo;
	
	// Add dynamic choice parameters (from master objects).
	For Each ChoiceParameter In ItemParameters.ChoiceParameters Do
		If IsBlankString(ChoiceParameter.Name) Then
			Continue;
		EndIf;
		If ValueIsFilled(ChoiceParameter.Name) Then
			If Upper(Left(ChoiceParameter.Name, 6)) = Upper("Filter.") Then
				ChoiceFormParameters.Filter.Insert(Mid(ChoiceParameter.Name, 7), ChoiceParameter.Value);
			Else
				ChoiceFormParameters.Insert(ChoiceParameter.Name, ChoiceParameter.Value);
			EndIf;
		EndIf;
	EndDo;
	
	OpenForm(FormPath, ChoiceFormParameters, ItemParameters.TableItem);
EndProcedure

&AtClient
Procedure Attachable_ListWithPicking_ProcessSelection(Item, SelectionResult, StandardProcessing)
	StandardProcessing = False;
	
	// Lists in form data.
	TableName = Item.Name;
	ItemID = Right(Item.Name, 32);
	ValueListInForm  = ThisObject[Item.Name];
	DCUserSetting = FindUserSettingOfItem(ItemID);
	
	If TypeOf(DCUserSetting) = Type("DataCompositionSettingsParameterValue") Then
		ValueListInDCS = DCUserSetting.Value;
	Else
		ValueListInDCS = DCUserSetting.RightValue;
	EndIf;
	ValueListInDCS = ReportsClientServer.ValuesByList(ValueListInDCS);
	
	Selected = ReportsClientServer.ValuesByList(SelectionResult);
	Selected.FillChecks(True);
	
	Supplement = ReportsClientServer.AddToList(ValueListInDCS, Selected, False, True);
	ReportsClientServer.AddToList(ValueListInForm, Selected, False, True);
	
	// Enable the Usage check box.
	DCUserSetting.Use = True;
	
	If TypeOf(DCUserSetting) = Type("DataCompositionSettingsParameterValue") Then
		DCUserSetting.Value       = ValueListInDCS;
	Else
		DCUserSetting.RightValue = ValueListInDCS;
	EndIf;
	
	// Rows appearance.
	FormTable = Items.Find(TableName);
	FormTable.TextColor = ?(DCUserSetting.Use, New Color, InactiveTableValueColor);
	
	UserSettingsModified = True;
	
	If Supplement.Total > 0 Then
		If Supplement.Total = 1 Then
			NotificationTitle = NStr("en = 'Item is added to the list'; ru = 'Элемент добавлен в список';pl = 'Element dodany do listy';es_ES = 'Elemento añadido en la lista';es_CO = 'Elemento añadido en la lista';tr = 'Öğe listeye eklendi';it = 'L''elemento è aggiunto all''elenco';de = 'Element zur Liste hinzugefügt'");
		Else
			NotificationTitle = NStr("en = 'Items are added to the list'; ru = 'Элементы добавлены в список';pl = 'Elementy zostały dodane do listy';es_ES = 'Elementos añadidos en la lista';es_CO = 'Elementos añadidos en la lista';tr = 'Öğeler listeye eklendi';it = 'Gli elementi sono aggiunti all''elenco';de = 'Elemente zur Liste hinzugefügt'");
		EndIf;
		ShowUserNotification(
			NotificationTitle,
			,
			String(Selected),
			PictureLib.ExecuteTask);
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_ListWithPicking_PasteFromClipboard(Command)
	PasteButtonName = Command.Name;
	
	ItemID    = Right(PasteButtonName, 32);
	SettingPropertiesType = Left(PasteButtonName, StrFind(PasteButtonName, "_")-1);
	
	TableName         = SettingPropertiesType + "_ValueList_"   + ItemID;
	ColumnValueName = SettingPropertiesType + "_Column_Value_" + ItemID;
	
	List = ThisObject[TableName];
	ListItem = Items[TableName];
	ValueColumnItem = Items[ColumnValueName];
	
	SearchParameters = New Structure;
	SearchParameters.Insert("TypeDescription", TypesDetailsRemovePrimitiveOnes(List.ValueType));
	SearchParameters.Insert("ChoiceParameters", ValueColumnItem.ChoiceParameters);
	SearchParameters.Insert("FieldPresentation", ListItem.Title);
	SearchParameters.Insert("Scenario", "PastingFromClipboard");
	
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("ItemID", ItemID);
	ExecutionParameters.Insert("TableName", TableName);
	Handler = New NotifyDescription("Attachable_ListWithPicking_PasteFromClipboard_Completion", ThisObject, ExecutionParameters);
	
	ModuleImportDataFromFileClient = CommonClient.CommonModule("ImportDataFromFileClient");
	ModuleImportDataFromFileClient.ShowRefFillingForm(SearchParameters, Handler);
EndProcedure

&AtClient
Procedure Attachable_ListWithPicking_PasteFromClipboard_Completion(FoundObjects, ExecutionParameters) Export
	If FoundObjects = Undefined Then
		Return;
	EndIf;
	
	ItemID = ExecutionParameters.ItemID;
	
	DCUserSetting = FindUserSettingOfItem(ItemID);
	AdditionalSettings = FindAdditionalItemSettings(ItemID);
	
	List = ThisObject[ExecutionParameters.TableName];
	If TypeOf(DCUserSetting) = Type("DataCompositionFilterItem") Then
		If DCUserSetting.RightValue = Undefined Then
			DCUserSetting.RightValue = New ValueList;
		EndIf;
		Marked = DCUserSetting.RightValue;
	Else
		Marked = DCUserSetting.Value;
	EndIf;
	For Each Value In FoundObjects Do
		ReportsClientServer.AddUniqueValueToList(List, Value, Undefined, True);
		ReportsClientServer.AddUniqueValueToList(Marked, Value, Undefined, True);
	EndDo;
	
	// Enable the Usage check box.
	DCUserSetting.Use = True;
	
	// Rows appearance.
	FormTable = Items.Find(ExecutionParameters.TableName);
	FormTable.TextColor = ?(DCUserSetting.Use, New Color, InactiveTableValueColor);
	
	UserSettingsModified = True;
EndProcedure

&AtClient
Procedure Attachable_ListWithPicking_Add(Command)
	
	PickButtonName = Command.Name;
	
	ItemID  = Right(PickButtonName, 32);
	SettingPropertiesType = Left(PickButtonName, StrFind(PickButtonName, "_Selection_") - 1);
	
	TableName = SettingPropertiesType + "_ValueList_" + ItemID;
	
	Items[TableName].AddRow();
	
EndProcedure

&AtClient
Procedure Attachable_FixedList_BeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	Cancel = True;
EndProcedure

&AtClient
Procedure Attachable_FixedList_BeforeDelete(Item, Cancel)
	Cancel = True;
EndProcedure

#EndRegion

#EndRegion

#Region FormTableItemsEventHandlersSorting

&AtClient
Procedure SortingChoice(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	TableRow = Items.Sort.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	If TableRow.SettingType = "OrderingItem" Then
		ColumnName = Field.Name;
		If ColumnName = "SortingPresentation" Then // Change a field
			FieldTablesChange("Sort", RowSelected, TableRow);
		ElsIf ColumnName = "SortDirection" Then // Change order.
			FieldTablesChangeSortDirection("Sort", TableRow, Undefined);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure SortingBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder, Parameter)
	Cancel = True;
	Handler = New NotifyDescription("SortAfterFieldChoice", ThisObject);
	FieldsTablesShowFieldSelection("Sort", Handler);
EndProcedure

&AtClient
Procedure SortAfterFieldChoice(AvailableDCField, ExecutionParameters) Export
	If AvailableDCField = Undefined Then
		Return;
	EndIf;
	
	Result = FieldTablesPaste("Sort", Type("DataCompositionOrderItem"), 0, Undefined);
	
	DCItem = Result.DCItem;
	DCItem.Use     = True;
	DCItem.Field              = AvailableDCField.Field;
	DCItem.OrderType = DataCompositionSortDirection.Asc;
	
	TableRow = Result.TableRow;
	TableRow.Use  = DCItem.Use;
	TableRow.Presentation  = AvailableDCField.Title;
	TableRow.Direction    = DCItem.OrderType;
	TableRow.SettingType   = "OrderingItem";
	TableRow.PictureIndex = ReportsClientServer.PictureIndex("Item");
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure SortingBeforeDelete(Item, Cancel)
	FieldTablesBeforeDelete(Item.Name, Cancel);
EndProcedure

&AtClient
Procedure SortingUsageOnChange(Item)
	FieldTablesChangeUsage("Sort");
EndProcedure

&AtClient
Procedure Sort_Descending(Command)
	FieldTablesChangeSortDirection("Sort", Undefined, DataCompositionSortDirection.Desc);
EndProcedure

&AtClient
Procedure Sort_Ascending(Command)
	FieldTablesChangeSortDirection("Sort", Undefined, DataCompositionSortDirection.Asc);
EndProcedure

&AtClient
Procedure Sorting_MoveUp(Command)

	Context = NewContext("Sort", "Move");
	Context.Insert("Direction", -1);
	DefineSelectedRows(Context);
	If ValueIsFilled(Context.CancelReason) Then
		ShowMessageBox(, Context.CancelReason);
		Return;
	EndIf;
	
	MoveRows(Context);
	
EndProcedure

&AtClient
Procedure Sorting_MoveDown(Command)
	
	Context = NewContext("Sort", "Move");
	Context.Insert("Direction", 1);
	DefineSelectedRows(Context);
	If ValueIsFilled(Context.CancelReason) Then
		ShowMessageBox(, Context.CancelReason);
		Return;
	EndIf;
	
	MoveRows(Context);
	
EndProcedure

&AtClient
Procedure Sorting_SelectCheckBoxes(Command)
	SetUsageCheckBoxesInWholeTree("Sort", True);
EndProcedure

&AtClient
Procedure Sorting_ClearCheckBoxes(Command)
	SetUsageCheckBoxesInWholeTree("Sort", False);
EndProcedure

&AtClient
Procedure SortingStartDrag(Item, DragParameters, Perform)
	If Not RegisterDragStart("Sort") Then
		Perform = False;
	EndIf;
EndProcedure

&AtClient
Procedure SortingCheckDrag(Item, DragParameters, StandardProcessing, Row, Field)
	StandardProcessing = False;
	CheckDragPossibility("Sort", Row, DragParameters);
EndProcedure

&AtClient
Procedure SortingDrag(Item, DragParameters, StandardProcessing, Row, Field)
	// This procedure starts in the destination object upon finishing dragging when all checks are passed.
	StandardProcessing = False;
	DraggingSource = DraggingSourceAtClient;
	If DraggingSource = Undefined Then
		Return;
	EndIf;
	If DraggingSource.TableName = "Sort" Then
		DragWithinTable(DraggingSource, Row);
	ElsIf DraggingSource.TableName = "SelectedFields" Then
		DragSelectedFieldsToSorting(DraggingSource, Row);
	EndIf;
EndProcedure

&AtClient
Procedure SortingEndDrag(Item, DragParameters, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure SelectedFields_Sorting_Right(Command)
	DraggingSource = Undefined;
	If Not RegisterDragStart("SelectedFields", DraggingSource) Then
		Return;
	EndIf;
	DragSelectedFieldsToSorting(DraggingSource, Undefined);
EndProcedure

&AtClient
Procedure SelectedFields_Sorting_Left(Command)
	DraggingSource = Undefined;
	If Not RegisterDragStart("Sort", DraggingSource) Then
		Return;
	EndIf;
	DragSortingInSelectedFields(DraggingSource, Items.SelectedFields.CurrentRow);
EndProcedure

&AtClient
Procedure SelectedFields_Sorting_LeftAll(Command)
	RootRow = DefaultRootRow("Sort");
	FieldTablesRemove("Sort", RootRow.GetItems(), True);
	DetermineIfModified();
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersSelectedFields

&AtClient
Procedure SelectedFieldsChoice(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	TableRow = Items.SelectedFields.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	ColumnName = Field.Name;
	If ColumnName = "SelectedFieldsPresentation" Then // Change order.
		If TableRow.SettingType = "SelectedField" Then
			FieldTablesChange("SelectedFields", RowSelected, TableRow);
		ElsIf TableRow.SettingType = "SelectedFieldsGroup" Then
			FieldTablesChangeGroup("SelectedFields", RowSelected, TableRow);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure SelectedFieldsBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder, Parameter)
	Cancel = True;
	If ExtendedMode = 0 Then
		Return;
	EndIf;
	
	Handler = New NotifyDescription("SelectedFieldsAfterFieldChoice", ThisObject);
	FieldsTablesShowFieldSelection("SelectedFields", Handler);
EndProcedure

&AtClient
Procedure SelectedFieldsAfterFieldChoice(AvailableDCField, ExecutionParameters) Export
	If AvailableDCField = Undefined Then
		Return;
	EndIf;
	
	Result = FieldTablesPaste("SelectedFields", Type("DataCompositionSelectedField"), 0, Undefined);
	
	DCItem = Result.DCItem;
	DCItem.Use = True;
	DCItem.Field          = AvailableDCField.Field;
	
	TableRow = Result.TableRow;
	TableRow.Use  = DCItem.Use;
	TableRow.Presentation  = AvailableDCField.Title;
	TableRow.IsFolder      = False;
	TableRow.PictureIndex = ReportsClientServer.PictureIndex("Item");
	TableRow.DCField         = DCItem.Field;
	
	AfterChangeUsageCheckBox("SelectedFields", TableRow, DCItem);
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure SelectedFieldsBeforeDelete(Item, Cancel)
	If ExtendedMode = 0 Then
		Cancel = True;
		Return;
	EndIf;
	FieldTablesBeforeDelete(Item.Name, Cancel);
EndProcedure

&AtClient
Procedure SelectedFieldsUsageOnChange(Item)
	FieldTablesChangeUsage("SelectedFields");
EndProcedure

&AtClient
Procedure SelectedFields_MoveUp(Command)
	
	Context = NewContext("SelectedFields", "Move");
	Context.Insert("Direction", -1);
	DefineSelectedRows(Context);
	If ValueIsFilled(Context.CancelReason) Then
		ShowMessageBox(, Context.CancelReason);
		Return;
	EndIf;
	
	MoveRows(Context);
	
EndProcedure

&AtClient
Procedure SelectedFields_MoveDown(Command)

	Context = NewContext("SelectedFields", "Move");
	Context.Insert("Direction", 1);
	DefineSelectedRows(Context);
	If ValueIsFilled(Context.CancelReason) Then
		ShowMessageBox(, Context.CancelReason);
		Return;
	EndIf;
	
	MoveRows(Context);
	
EndProcedure

&AtClient
Procedure SelectedFields_Group(Command)
	
	Context = NewContext("SelectedFields", "Group");
	Context.Insert("DCGroupType", Type("DataCompositionSelectedFieldGroup"));
	DefineSelectedRows(Context);
	If ValueIsFilled(Context.CancelReason) Then
		ShowMessageBox(, Context.CancelReason);
		Return;
	EndIf;
	
	FormParameters = New Structure("Placement", DataCompositionFieldPlacement.Auto);
	Handler = New NotifyDescription("SelectedFields_GroupCompletion", ThisObject, Context);
	OpenForm("SettingsStorage.ReportsVariantsStorage.Form.SelectedFieldsGroup", FormParameters, 
		ThisObject, True, , , Handler, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure SelectedFields_GroupCompletion(UserSelection, Context) Export
	
	If UserSelection = Undefined Or UserSelection = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	Context.Insert("GroupTitle", UserSelection.GroupTitle);
	Context.Insert("Placement", UserSelection.Placement);
	GroupRows(Context);
	UpdateForm(Context);
	
EndProcedure

&AtClient
Procedure SelectedFields_Ungroup(Command)
	FieldTablesUngroup("SelectedFields");
EndProcedure

&AtClient
Procedure SelectedFields_SelectCheckBoxes(Command)
	SetUsageCheckBoxesInWholeTree("SelectedFields", True);
EndProcedure

&AtClient
Procedure SelectedFields_ClearCheckBoxes(Command)
	SetUsageCheckBoxesInWholeTree("SelectedFields", False);
EndProcedure

&AtClient
Procedure SelectedFieldsStartDrag(Item, DragParameters, Perform)
	If Not RegisterDragStart("SelectedFields") Then
		Perform = False;
	EndIf;
EndProcedure

&AtClient
Procedure SelectedFieldsCheckDrag(Item, DragParameters, StandardProcessing, Row, Field)
	StandardProcessing = False;
	CheckDragPossibility("SelectedFields", Row, DragParameters);
EndProcedure

&AtClient
Procedure SelectedFieldsDrag(Item, DragParameters, StandardProcessing, Row, Field)
	// This procedure starts in the destination object upon finishing dragging when all checks are passed.
	StandardProcessing = False;
	DraggingSource = DraggingSourceAtClient;
	If DraggingSource = Undefined Then
		Return;
	EndIf;
	If DraggingSource.TableName = "SelectedFields" Then
		DragWithinTable(DraggingSource, Row);
	ElsIf DraggingSource.TableName = "Sort" Then
		DragSortingInSelectedFields(DraggingSource, Row);
	EndIf;
EndProcedure

&AtClient
Procedure SelectedFieldsEndDrag(Item, DragParameters, StandardProcessing)
	StandardProcessing = False;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersFilters

&AtClient
Procedure FiltersChoice(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	ColumnName = Field.Name;
	If ExtendedMode <> 1 Then
		Return;
	EndIf;
	TableRow = Items.Filters.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	If TableRow.IsSection Then
		Return;
	EndIf;
	
	If ColumnName = "FiltersPresentation" Then // Change order.
		
		If TableRow.IsParameter Then
			Return;
		EndIf;
		If TableRow.IsFolder Then
			FieldTablesChangeGroup("Filters", RowSelected, TableRow);
		Else
			FieldTablesChange("Filters", RowSelected, TableRow);
		EndIf;
		
	ElsIf ColumnName = "FiltersAccessPictureIndex" Then // Change quick access for the filter.
		
		FieldTablesChangeAccessLevel("Filters", RowSelected, True, Not TableRow.IsParameter);
		
	ElsIf ColumnName = "FiltersValue"
		Or ColumnName = "FiltersValuePresentation" Then
		
		If TableRow.IsFolder Then
			Return;
		EndIf;
		If TableRow.Condition = DataCompositionComparisonType.Filled
			Or TableRow.Condition = DataCompositionComparisonType.NotFilled Then
			Return;
		EndIf;
		
		IsPeriod = (TableRow.ConditionType = New TypeDescription("EnumRef.AvailableReportPeriods"));
		If IsPeriod Then
			FiltersShowPeriodSelection(TableRow);
		Else
			If TableRow.ListInput Then
				FiltersShowListWithCheckBoxes(TableRow);
			ElsIf TableRow.FixedSelectionList Then
				FiltersChooseValueFromList(TableRow);
			Else
				FiltersShowRefSelection(TableRow, StandardProcessing);
			EndIf;
		EndIf;
		
	ElsIf ColumnName = "FiltersCondition" Then
		
		If TableRow.IsFolder Then
			Return;
		EndIf;
		IsPeriod = (TableRow.ConditionType = New TypeDescription("EnumRef.AvailableReportPeriods"));
		If IsPeriod Then
			FiltersShowPeriodSelection(TableRow);
		Else
			FiltersSelectComparisonType(TableRow);
		EndIf;
		
	ElsIf ColumnName = "FiltersTitle" Then
		
		StandardProcessing = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FiltersBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder, Parameter)
	Cancel = True;
	If ExtendedMode = 0 Then
		Return;
	EndIf;
	
	If Not OptionNodeChangeMode Then
		CurrentRow = Items.Filters.CurrentData;
		If (CurrentRow = Undefined)
			Or (CurrentRow.IsParameter)
			Or (CurrentRow.IsSection AND CurrentRow.DCID = "DataParameters") Then
			CurrentRow = Filters.GetItems()[1];
			Items.Filters.CurrentRow = CurrentRow.GetID();
		EndIf;
	EndIf;
	
	Handler = New NotifyDescription("FiltersAfterFieldChoice", ThisObject);
	FieldsTablesShowFieldSelection("Filters", Handler);
EndProcedure

&AtClient
Procedure FiltersAfterFieldChoice(AvailableDCFilterField, ExecutionParameters) Export
	If AvailableDCFilterField = Undefined Then
		Return;
	EndIf;
	
	Result = FieldTablesPaste("Filters", Type("DataCompositionFilterItem"), 0, Undefined);
	
	DCItem = Result.DCItem;
	DCItem.Use  = True;
	DCItem.LeftValue  = AvailableDCFilterField.Field;
	DCItem.RightValue = AvailableDCFilterField.Type.AdjustValue();
	DCItem.ViewMode = DataCompositionSettingsItemViewMode.Normal;
	DCItem.UserSettingID = String(New UUID());
	
	DetermineIfModified();
	Update();
EndProcedure

&AtClient
Procedure FiltersBeforeDelete(Item, Cancel)
	FieldTablesBeforeDelete(Item.Name, Cancel);
EndProcedure

&AtClient
Procedure Filters_Group(Command)
	
	Context = NewContext("Filters", "Group");
	Context.Insert("DCGroupType", Type("DataCompositionFilterItemGroup"));
	DefineSelectedRows(Context);
	If ValueIsFilled(Context.CancelReason) Then
		ShowMessageBox(, Context.CancelReason);
		Return;
	EndIf;
	
	GroupRows(Context);
	UpdateForm(Context);
	
EndProcedure

&AtClient
Procedure Filters_Ungroup(Command)
	FieldTablesUngroup("Filters");
EndProcedure

&AtClient
Procedure Filters_MoveUp(Command)
	
	Context = NewContext("Filters", "Move");
	Context.Insert("Direction", -1);
	DefineSelectedRows(Context);
	If ValueIsFilled(Context.CancelReason) Then
		ShowMessageBox(, Context.CancelReason);
		Return;
	EndIf;
	
	MoveRows(Context);
	
EndProcedure

&AtClient
Procedure Filters_MoveDown(Command)
	
	Context = NewContext("Filters", "Move");
	Context.Insert("Direction", 1);
	DefineSelectedRows(Context);
	If ValueIsFilled(Context.CancelReason) Then
		ShowMessageBox(, Context.CancelReason);
		Return;
	EndIf;
	
	MoveRows(Context);

EndProcedure

&AtClient
Procedure Filters_SelectCheckBoxes(Command)
	SetUsageCheckBoxesInWholeTree("Filters", True);
EndProcedure

&AtClient
Procedure Filters_ClearCheckBoxes(Command)
	SetUsageCheckBoxesInWholeTree("Filters", False);
EndProcedure

&AtClient
Procedure Filters_ShowInReportHeader(Command)
	FiltersSetAccessLevel("ShowInReportHeader");
EndProcedure

&AtClient
Procedure Filters_ShowInReportSettings(Command)
	FiltersSetAccessLevel("ShowInReportSettings");
EndProcedure

&AtClient
Procedure Filters_ShowOnlyCheckBoxInReportHeader(Command)
	FiltersSetAccessLevel("ShowOnlyCheckBoxInReportHeader");
EndProcedure

&AtClient
Procedure Filters_ShowOnlyCheckBoxInReportSettings(Command)
	FiltersSetAccessLevel("ShowOnlyCheckBoxInReportSettings");
EndProcedure

&AtClient
Procedure Filters_DontShow(Command)
	FiltersSetAccessLevel("DontShow");
EndProcedure

&AtClient
Procedure FiltersUsageOnChange(Item)
	FieldTablesChangeUsage("Filters");
EndProcedure

&AtClient
Procedure FiltersValueOnChange(Item)
	FieldTablesChangeValue("Filters");
EndProcedure

&AtClient
Procedure FiltersTitleOnChange(Item)
	TableRow = Items.Filters.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	DCNode = FieldTablesFindNode(ThisObject, "Filters", TableRow);
	DCItem = DCNode.GetObjectByID(TableRow.DCID);
	If DCItem = Undefined Then
		Return;
	EndIf;
	
	If IsBlankString(TableRow.Title) Then
		TableRow.Title = TableRow.Presentation;
	EndIf;
	TableRow.TitleOverridden = (TableRow.Title <> TableRow.Presentation);
	
	If Not TableRow.IsParameter Then
		If TableRow.AccessPictureIndex = 1 Or TableRow.AccessPictureIndex = 3 Then
			// If UserSettingPresentation is filled in, the Presentation acts as radio buttons and can also be 
			// used for output to a spreadsheet document.
			// 
			DCItem.Presentation = TableRow.Title;
		Else
			DCItem.Presentation = "";
		EndIf;
	EndIf;
	If TableRow.TitleOverridden Then
		DCItem.UserSettingPresentation = TableRow.Title;
	Else
		DCItem.UserSettingPresentation = "";
	EndIf;
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure FiltersOnActivateRow(Item)
	
	AttachIdleHandler("FiltersOnChangeCurrentRow", 0.1, True);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersOptionStructure

&AtClient
Procedure OptionStructureOnActivateRow(Item)
	TableRow = Items.OptionStructure.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	NestedObjectsCanBeAdded = True;
	CanBeGrouped = True;
	CanBeOpened = True;
	CanBeRemovedAndMoved = True;
	TablesAndChartsCanBeAdded = False;
	
	Parent = TableRow.GetParent();
	ParentCanBeMoved = (Parent <> Undefined
		AND Parent.Type <> "Settings"
		AND Parent.Type <> "TableStructureItemCollection"
		AND Parent.Type <> "ChartStructureItemCollection");
	HasNeighboringObjects = GetItems(OptionStructure, Parent).Count() > 1;
	
	HasSubordinate = (TableRow.GetItems().Count() > 0);
	If TableRow.Type = "Table"
		Or TableRow.Type = "Chart"
		Or TableRow.Type = "NestedObjectSettings" Then
		CanBeOpened = False;
		NestedObjectsCanBeAdded = False;
	ElsIf TableRow.Type = "Settings"
		Or TableRow.Type = "TableStructureItemCollection"
		Or TableRow.Type = "ChartStructureItemCollection" Then
		CanBeOpened = False;
		CanBeRemovedAndMoved = False;
		CanBeGrouped = False;
	ElsIf TableRow.Type = "NestedObjectSettings" Then
		CanBeOpened = False;
		CanBeGrouped = False;
	EndIf;
	
	If TableRow.Type = "Settings" Or TableRow.Type = "Group" Then
		TablesAndChartsCanBeAdded = True;
	EndIf;
	
	Items.OptionStructure_Add.Enabled  = NestedObjectsCanBeAdded;
	Items.OptionStructure_Add1.Enabled = NestedObjectsCanBeAdded;
	Items.OptionStructure_Change.Enabled  = CanBeOpened;
	Items.OptionStructure_Change1.Enabled = CanBeOpened;
	Items.OptionStructure_AddTable.Enabled  = TablesAndChartsCanBeAdded;
	Items.OptionStructure_AddTable1.Enabled = TablesAndChartsCanBeAdded;
	Items.OptionStructure_AddChart.Enabled  = TablesAndChartsCanBeAdded;
	Items.OptionStructure_AddChart1.Enabled = TablesAndChartsCanBeAdded;
	Items.OptionStructure_Delete.Enabled  = CanBeRemovedAndMoved;
	Items.OptionStructure_Delete1.Enabled = CanBeRemovedAndMoved;
	Items.OptionStructure_Group.Enabled  = CanBeGrouped;
	Items.OptionStructure_Group1.Enabled = CanBeGrouped;
	Items.OptionStructure_MoveUpAndLeft.Enabled  = CanBeRemovedAndMoved AND ParentCanBeMoved AND NestedObjectsCanBeAdded AND CanBeGrouped;
	Items.OptionStructure_MoveUpAndLeft1.Enabled = CanBeRemovedAndMoved AND ParentCanBeMoved AND NestedObjectsCanBeAdded AND CanBeGrouped;
	Items.OptionStructure_MoveDownAndRight.Enabled  = CanBeRemovedAndMoved AND HasSubordinate AND NestedObjectsCanBeAdded AND CanBeGrouped;
	Items.OptionStructure_MoveDownAndRight1.Enabled = CanBeRemovedAndMoved AND HasSubordinate AND NestedObjectsCanBeAdded AND CanBeGrouped;
	Items.OptionStructure_MoveUp.Enabled  = CanBeRemovedAndMoved AND HasNeighboringObjects;
	Items.OptionStructure_MoveUp1.Enabled = CanBeRemovedAndMoved AND HasNeighboringObjects;
	Items.OptionStructure_MoveDown.Enabled  = CanBeRemovedAndMoved AND HasNeighboringObjects;
	Items.OptionStructure_MoveDown1.Enabled = CanBeRemovedAndMoved AND HasNeighboringObjects;
	
EndProcedure

&AtClient
Procedure OptionStructureChoice(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	If ExtendedMode <> 1 Then
		Return;
	EndIf;
	TableRow = Items.OptionStructure.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	If TableRow.Type = "TableStructureItemCollection"
		Or TableRow.Type = "ChartStructureItemCollection"
		Or TableRow.Type = "Settings" Then
		Return;
	EndIf;
	ColumnName = Field.Name;
	If ColumnName = "OptionStructurePresentation"
		Or ColumnName = "OptionStructureContainsFilters"
		Or ColumnName = "OptionStructureContainsFieldsOrOrders"
		Or ColumnName = "OptionStructureContainsConditionalAppearance" Then
		If ColumnName = "OptionStructureContainsFilters" Then
			PageName = "FiltersPage";
		ElsIf ColumnName = "OptionStructureContainsFieldsOrOrders" Then
			PageName = "SelectedFieldsAndSortingsPage";
		ElsIf ColumnName = "OptionStructureContainsConditionalAppearance" Then
			PageName = "AppearancePage";
		Else
			PageName = Undefined;
		EndIf;
		ChangeOptionNode(TableRow, PageName, Undefined);
	Else
		StandardProcessing = True;
	EndIf;
EndProcedure

&AtClient
Procedure OptionStructureBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder, Parameter)
	Cancel = True;
	If ExtendedMode = 0 Then
		Return;
	EndIf;
	If Not Items.OptionStructure_Add.Enabled Then
		Return;
	EndIf;
	If Clone Then
		Return;
	EndIf;
	
	OptionStructureAddGroup(True);
EndProcedure

&AtClient
Procedure OptionStructure_Group(Command)
	If Not Items.OptionStructure_Group.Enabled Then
		Return;
	EndIf;
	OptionStructureAddGroup(False);
EndProcedure

&AtClient
Procedure OptionStructureAddGroup(InsideCurrentObject)
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("InsideCurrentObject", InsideCurrentObject);
	ExecutionParameters.Insert("Wrap", True);
	
	SettingsNodeID = Undefined;
	TableRow = Items.OptionStructure.CurrentData;
	If TableRow <> Undefined Then
		If Not InsideCurrentObject Then
			TableRow = TableRow.GetParent();
		EndIf;
		If InsideCurrentObject Then
			If TableRow.Type = "Settings" AND Not TableRow.AvailableFlag Then
				ExecutionParameters.Wrap = False;
			ElsIf TableRow.GetItems().Count() > 1 Then
				ExecutionParameters.Wrap = False;
			EndIf;
		EndIf;
		While TableRow <> Undefined Do
			If TableRow.Type = "Settings"
				Or TableRow.Type = "NestedObjectSettings"
				Or TableRow.Type = "Group"
				Or TableRow.Type = "TableGroup"
				Or TableRow.Type = "ChartGroup" Then
				SettingsNodeID = TableRow.DCID;
				Break;
			EndIf;
			TableRow = TableRow.GetParent();
		EndDo;
	EndIf;
	
	Handler = New NotifyDescription("OptionStructureAddGroupAfterFieldChoice", ThisObject, ExecutionParameters);
	FieldsTablesShowFieldSelection("OptionStructure", Handler, Undefined, SettingsNodeID);
EndProcedure

&AtClient
Procedure OptionStructureAddGroupAfterFieldChoice(AvailableDCField, ExecutionParameters) Export
	If AvailableDCField = Undefined Then
		Return;
	EndIf;
	
	CurrentRow = Items.OptionStructure.CurrentData;
	
	RowsToMoveToNewGroup = New Array;
	If ExecutionParameters.Wrap Then
		If ExecutionParameters.InsideCurrentObject Then
			FoundItems = CurrentRow.GetItems();
			For Each RowToMove In FoundItems Do
				RowsToMoveToNewGroup.Add(RowToMove);
			EndDo;
		Else
			RowsToMoveToNewGroup.Add(CurrentRow);
		EndIf;
	EndIf;
	
	// Add a new group.
	Result = FieldTablesPaste("OptionStructure", Type("DataCompositionGroup"), CurrentRow, ExecutionParameters.InsideCurrentObject);
	
	DCItem = Result.DCItem;
	DCItem.Use = True;
	DCItem.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	DCItem.Order.Items.Add(Type("DataCompositionAutoOrderItem"));
	
	If AvailableDCField = "<>" Then
		// Detailed records - no need to add a field.
		Presentation = NStr("en = '<Detailed records>'; ru = '<Подробные записи>';pl = '<Wpisy szczegółowe>';es_ES = '<Registros detallados>';es_CO = '<Registros detallados>';tr = '<Ayrıntılı kayıtlar>';it = '<Registrazioni dettagliate>';de = 'Ausführliche Einträge'");
	Else
		DCGroupField = DCItem.GroupFields.Items.Add(Type("DataCompositionGroupField"));
		DCGroupField.Use = True;
		DCGroupField.Field = AvailableDCField.Field;
		Presentation = String(AvailableDCField.Title);
	EndIf;
	
	TableRow = Result.TableRow;
	TableRow.Use = DCItem.Use;
	TableRow.Presentation = Presentation;
	TableRow.PictureIndex = ReportsClientServer.PictureIndex("Group");
	TableRow.AvailableFlag = True;
	TableRow.Type = ReportsClientServer.SettingTypeAsString(TypeOf(DCItem));
	
	If Not ExecutionParameters.InsideCurrentObject Then
		TableRow.Title = CurrentRow.Title;
		OptionStructureUpdateItemTitleInComposer(TableRow);
		CurrentRow.Title = "";
		OptionStructureUpdateItemTitleInComposer(CurrentRow);
	EndIf;
	
	// Move the current group to a new one.
	For Each RowToMove In RowsToMoveToNewGroup Do
		Result = FieldTablesMove("OptionStructure", RowToMove, TableRow);
	EndDo;
	
	// Bells and whistles.
	Items.OptionStructure.Expand(TableRow.GetID(), True);
	Items.OptionStructure.CurrentRow = TableRow.GetID();
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		OptionChanged = True;
	EndIf;
EndProcedure

&AtClient
Procedure OptionStructure_AddTable(Command)
	If Not Items.OptionStructure_AddTable.Enabled Then
		Return;
	EndIf;
	AddTableOrChart(Type("DataCompositionTable"));
EndProcedure

&AtClient
Procedure OptionStructure_AddChart(Command)
	If Not Items.OptionStructure_AddChart.Enabled Then
		Return;
	EndIf;
	AddTableOrChart(Type("DataCompositionChart"));
EndProcedure

&AtClient
Procedure OptionStructure_SelectCheckBoxes(Command)
	SetUsageCheckBoxesInWholeTree("OptionStructure", True);
EndProcedure

&AtClient
Procedure OptionStructure_ClearCheckBoxes(Command)
	SetUsageCheckBoxesInWholeTree("OptionStructure", False);
EndProcedure

&AtClient
Procedure AddTableOrChart(ItemType)
	CurrentRow = Items.OptionStructure.CurrentData;
	
	Result = FieldTablesPaste("OptionStructure", ItemType, CurrentRow, True);
	DCItem = Result.DCItem;
	
	TableRow = Result.TableRow;
	TableRow.Type = ReportsClientServer.SettingTypeAsString(ItemType);
	TableRow.Title      = TableRow.Presentation;
	TableRow.AvailableFlag = True;
	TableRow.Use  = DCItem.Use;
	TableRow.PictureIndex = ReportsClientServer.PictureIndex(TableRow.Type);
	
	DCNode = FieldTablesFindNode(ThisObject, "OptionStructure");
	NestedRows = TableRow.GetItems();
	
	If TableRow.Type = "Chart" Then
		
		DCItem.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
		SetOutputParameter(DCItem, "ChartType.ValuesBySeriesConnection", ChartValuesBySeriesConnectionType.EdgesConnection);
		SetOutputParameter(DCItem, "ChartType.ValuesBySeriesConnectionLines");
		SetOutputParameter(DCItem, "ChartType.ValuesBySeriesConnectionColor", WebColors.Gainsboro);
		SetOutputParameter(DCItem, "ChartType.SplineMode", ChartSplineMode.SmoothCurve);
		SetOutputParameter(DCItem, "ChartType.SemitransparencyMode", ChartSemitransparencyMode.Use);
		
		TableRow.Presentation = NStr("en = 'Chart'; ru = 'Диаграмма';pl = 'Wykres';es_ES = 'Chart';es_CO = 'Chart';tr = 'Diyagram';it = 'Piano';de = 'Grafik'");
		
		DCNestedItem = DCItem.Points;
		NestedRow = NestedRows.Add();
		NestedRow.Type = ReportsClientServer.SettingTypeAsString(TypeOf(DCNestedItem));
		NestedRow.Subtype = "ChartPoints";
		NestedRow.DCID = DCNode.GetIDByObject(DCNestedItem);
		NestedRow.PictureIndex = -1;
		NestedRow.Presentation = NStr("en = 'Dots'; ru = 'Точки';pl = 'Punkty';es_ES = 'Puntos';es_CO = 'Puntos';tr = 'Noktalar';it = 'Punti';de = 'Punkte'");
		
		DCNestedItem = DCItem.Series;
		NestedRow = NestedRows.Add();
		NestedRow.Type = ReportsClientServer.SettingTypeAsString(TypeOf(DCNestedItem));
		NestedRow.Subtype = "ChartSeries";
		NestedRow.DCID = DCNode.GetIDByObject(DCNestedItem);
		NestedRow.PictureIndex = -1;
		NestedRow.Presentation = NStr("en = 'Series'; ru = 'Серии';pl = 'Serie';es_ES = 'Serie';es_CO = 'Serie';tr = 'Seri';it = 'Serie';de = 'Serie'");
		
	ElsIf TableRow.Type = "Table" Then
		
		TableRow.Presentation = NStr("en = 'Table'; ru = 'Таблица';pl = 'Tabela';es_ES = 'Tabla';es_CO = 'Tabla';tr = 'Tablo';it = 'Tabella';de = 'Tabelle'");
		
		DCNestedItem = DCItem.Rows;
		NestedRow = NestedRows.Add();
		NestedRow.Type = ReportsClientServer.SettingTypeAsString(TypeOf(DCNestedItem));
		NestedRow.Subtype = "TableRows";
		NestedRow.DCID = DCNode.GetIDByObject(DCNestedItem);
		NestedRow.PictureIndex = -1;
		NestedRow.Presentation = NStr("en = 'Rows'; ru = 'Строки';pl = 'Wiersze';es_ES = 'Líneas';es_CO = 'Líneas';tr = 'Satırlar';it = 'Righe';de = 'Zeilen'");
		
		DCNestedItem = DCItem.Columns;
		NestedRow = NestedRows.Add();
		NestedRow.Type = ReportsClientServer.SettingTypeAsString(TypeOf(DCNestedItem));
		NestedRow.Subtype = "ColumnsTable";
		NestedRow.DCID = DCNode.GetIDByObject(DCNestedItem);
		NestedRow.PictureIndex = -1;
		NestedRow.Presentation = NStr("en = 'Columns'; ru = 'Колонки';pl = 'Kolumny';es_ES = 'Columnas';es_CO = 'Columnas';tr = 'Sütunlar';it = 'Colonne';de = 'Spalten'");
		
	EndIf;
	
	Items.OptionStructure.Expand(TableRow.GetID(), True);
	DetermineIfModified();
EndProcedure

&AtClient
Procedure OptionStructureStartDragging(Item, DragParameters, Perform)
	// Check general conditions.
	If ExtendedMode = 0 Then
		Perform = False;
		Return;
	EndIf;
	// Check the source.
	TableRow = OptionStructure.FindByID(DragParameters.Value);
	If TableRow = Undefined Then
		Perform = False;
		Return;
	EndIf;
	If TableRow.Type = "ChartStructureItemCollection"
		Or TableRow.Type = "TableStructureItemCollection"
		Or TableRow.Type = "Settings" Then
		Perform = False;
		Return;
	EndIf;
EndProcedure

&AtClient
Procedure OptionStructureCheckDragging(Item, DragParameters, StandardProcessing, Row, Field)
	// Check general conditions.
	If Row = Undefined Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	// Check the source.
	TableRow = OptionStructure.FindByID(DragParameters.Value);
	If TableRow = Undefined Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	// Check the destination.
	NewParent = OptionStructure.FindByID(Row);
	If NewParent = Undefined Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	If NewParent.Type = "Table"
		Or NewParent.Type = "Chart" Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	
	// Check compatibility of the source and destination.
	OnlyGroupsAllowed = False;
	If NewParent.Type = "TableStructureItemCollection"
		Or NewParent.Type = "ChartStructureItemCollection"
		Or NewParent.Type = "TableGroup"
		Or NewParent.Type = "ChartGroup" Then
		OnlyGroupsAllowed = True;
	EndIf;
	
	If OnlyGroupsAllowed
		AND TableRow.Type <> "Group"
		AND TableRow.Type <> "TableGroup"
		AND TableRow.Type <> "ChartGroup" Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	
	CollectionsOfCollections = New Array;
	CollectionsOfCollections.Add(TableRow.GetItems());
	Count = 1;
	While Count > 0 Do
		Collection = CollectionsOfCollections[0];
		Count = Count - 1;
		CollectionsOfCollections.Delete(0);
		For Each NestedTableRow In Collection Do
			If NestedTableRow = NewParent Then
				DragParameters.Action = DragAction.Cancel;
				Return;
			EndIf;
			If OnlyGroupsAllowed
				AND NestedTableRow.Type <> "Group"
				AND NestedTableRow.Type <> "TableGroup"
				AND NestedTableRow.Type <> "ChartGroup" Then
				DragParameters.Action = DragAction.Cancel;
				Return;
			EndIf;
			CollectionsOfCollections.Add(NestedTableRow.GetItems());
			Count = Count + 1;
		EndDo;
	EndDo;
	
EndProcedure

&AtClient
Procedure OptionStructureDrag(Item, DragParameters, StandardProcessing, Row, Field)
	// All checks are passed.
	StandardProcessing = False;
	
	TableRow = OptionStructure.FindByID(DragParameters.Value);
	NewParent = OptionStructure.FindByID(Row);
	
	Result = FieldTablesMove("OptionStructure", TableRow, NewParent);
	
	Items.OptionStructure.Expand(NewParent.GetID(), True);
	Items.OptionStructure.CurrentRow = Result.TableRow.GetID();
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		OptionChanged = True;
	EndIf;
EndProcedure

&AtClient
Procedure OptionStructureUsageOnChange(Item)
	FieldTablesChangeUsage("OptionStructure");
EndProcedure

&AtClient
Procedure OptionStructureTitleOnChange(Item)
	TableRow = Items.OptionStructure.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	OptionStructureUpdateItemTitleInComposer(TableRow);
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		OptionChanged = True;
	EndIf;
EndProcedure

&AtClient
Procedure OptionStructure_MoveUp(Command)
	
	Context = NewContext("OptionStructure", "Move");
	Context.Insert("Direction", -1);
	DefineSelectedRows(Context);
	If ValueIsFilled(Context.CancelReason) Then
		ShowMessageBox(, Context.CancelReason);
		Return;
	EndIf;
	
	MoveRows(Context);
	
EndProcedure

&AtClient
Procedure OptionStructure_MoveDown(Command)
	
	Context = NewContext("OptionStructure", "Move");
	Context.Insert("Direction", 1);
	DefineSelectedRows(Context);
	If ValueIsFilled(Context.CancelReason) Then
		ShowMessageBox(, Context.CancelReason);
		Return;
	EndIf;
	
	MoveRows(Context);
	
EndProcedure

&AtClient
Procedure OptionStructure_Change(Command)
	TableItem = Items.OptionStructure;
	Field = TableItem.CurrentItem;
	StandardProcessing = True;
	IDRow = TableItem.CurrentRow;
	OptionStructureChoice(TableItem, IDRow, Field, StandardProcessing);
EndProcedure

&AtClient
Procedure OptionStructureBeforeDelete(Item, Cancel)
	If ExtendedMode = 0 Or Not Items.OptionStructure_Delete.Enabled Then
		Cancel = True;
		Return;
	EndIf;
	FieldTablesBeforeDelete(Item.Name, Cancel);
EndProcedure

&AtClient
Procedure OptionStructure_MoveUpAndLeft(Command)
	If Not Items.OptionStructure_MoveUpAndLeft.Enabled Then
		Return;
	EndIf;
	TableRowUp = Items.OptionStructure.CurrentData;
	If TableRowUp = Undefined Then
		Return;
	EndIf;
	TableRowDown = TableRowUp.GetParent();
	If TableRowDown = Undefined Then
		Return;
	EndIf;
	
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("Mode",              "UpAndLeft");
	ExecutionParameters.Insert("TableRowUp", TableRowUp);
	ExecutionParameters.Insert("TableRowDown",  TableRowDown);
	OptionStructure_Move(-1, ExecutionParameters);
EndProcedure

&AtClient
Procedure OptionStructure_MoveDownAndRight(Command)
	If Not Items.OptionStructure_MoveDownAndRight.Enabled Then
		Return;
	EndIf;
	TableRowDown = Items.OptionStructure.CurrentData;
	If TableRowDown = Undefined Then
		Return;
	EndIf;
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("Mode",              "DownAndRight");
	ExecutionParameters.Insert("TableRowUp", Undefined);
	ExecutionParameters.Insert("TableRowDown",  TableRowDown);
	
	SubordinateRows = TableRowDown.GetItems();
	Count = SubordinateRows.Count();
	If Count = 0 Then
		Return;
	ElsIf Count = 1 Then
		ExecutionParameters.TableRowUp = SubordinateRows[0];
		OptionStructure_Move(-1, ExecutionParameters);
	Else
		List = New ValueList;
		For RowNumber = 1 To Count Do
			SubordinateRow = SubordinateRows[RowNumber-1];
			List.Add(SubordinateRow.GetID(), SubordinateRow.Presentation);
		EndDo;
		Handler = New NotifyDescription("OptionStructure_Move", ThisObject, ExecutionParameters);
		ShowChooseFromMenu(Handler, List);
	EndIf;
	
EndProcedure

&AtClient
Procedure OptionStructure_Move(Result, ExecutionParameters) Export
	If Result <> -1 Then
		If TypeOf(Result) <> Type("ValueListItem") Then
			Return;
		EndIf;
		TableRowUp = OptionStructure.FindByID(Result.Value);
	Else
		TableRowUp = ExecutionParameters.TableRowUp;
	EndIf;
	TableRowDown = ExecutionParameters.TableRowDown;
	
	// 0. Store the item before which the upper row must be pasted.
	RowsDown = TableRowDown.GetItems();
	Index = RowsDown.IndexOf(TableRowUp);
	RowsDownIDsArray = New Array;
	For Each TableRow In RowsDown Do
		If TableRow = TableRowUp Then
			Continue;
		EndIf;
		RowsDownIDsArray.Add(TableRow.GetID());
	EndDo;
	
	// 1. Move the lower row to the level of the upper one.
	Result1 = FieldTablesMove("OptionStructure", TableRowUp, TableRowDown.GetParent(), TableRowDown);
	TableRowUp = Result1.TableRow;
	
	// 2. Store the rows to be moved.
	RowsUp = TableRowUp.GetItems();
	
	// 3. Exchange rows.
	For Each TableRow In RowsUp Do
		Result2 = FieldTablesMove("OptionStructure", TableRow, TableRowDown);
	EndDo;
	For Each TableRowID In RowsDownIDsArray Do
		TableRow = OptionStructure.FindByID(TableRowID);
		Result3 = FieldTablesMove("OptionStructure", TableRow, TableRowUp);
	EndDo;
	
	// 4. Move the upper row to the lower one.
	RowsUp = TableRowUp.GetItems();
	If RowsUp.Count() - 1 < Index Then
		PasteBeforeWhat = Undefined;
	Else
		PasteBeforeWhat = RowsUp[Index];
	EndIf;
	Result4 = FieldTablesMove("OptionStructure", TableRowDown, TableRowUp, PasteBeforeWhat);
	TableRowDown = Result4.TableRow;
	
	// Bells and whistles.
	If ExecutionParameters.Mode = "DownAndRight" Then
		CurrentRow = TableRowDown;
	Else
		CurrentRow = TableRowUp;
	EndIf;
	IDCurrentRow = CurrentRow.GetID();
	Items.OptionStructure.Expand(IDCurrentRow, True);
	Items.OptionStructure.CurrentRow = IDCurrentRow;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		OptionChanged = True;
	EndIf;
EndProcedure

&AtClient
Procedure OptionStructure_SaveToFile(Command)
	Address = SettingsAddressInXMLString();
	GetFile(Address, NStr("en = 'Settings.xml'; ru = 'Настройки.xml';pl = 'Ustawienia.xml';es_ES = 'Ajustes.xml';es_CO = 'Ajustes.xml';tr = 'Settings.xml';it = 'Settings.xml';de = 'Einstellungen.xml'"), True);
EndProcedure

&AtServer
Function SettingsAddressInXMLString()
	Return PutToTempStorage(
		Common.ValueToXMLString(Report.SettingsComposer.Settings),
		UUID);
EndFunction

#EndRegion

#Region FormTableItemsEventHandlersGroupContent

&AtClient
Procedure GroupContentUsageOnChange(Item)
	FieldTablesChangeUsage("GroupComposition");
EndProcedure

&AtClient
Procedure GroupContentChoice(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	TableRow = Items.GroupComposition.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	ColumnName = Field.Name;
	If ColumnName = "GroupCompositionPresentation" Then
		If TableRow.SettingType = "GroupField" Then
			FieldTablesChange("GroupComposition", RowSelected, TableRow);
		EndIf;
	ElsIf ColumnName = "GroupCompositionGroupType"
		Or ColumnName = "GroupCompositionAdditionType" Then
		StandardProcessing = True;
	EndIf;
EndProcedure

&AtClient
Procedure GroupContentBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder, Parameter)
	Cancel = True;
	Handler = New NotifyDescription("GroupCompositionAfterFieldChoice", ThisObject);
	FieldsTablesShowFieldSelection("GroupComposition", Handler);
EndProcedure

&AtClient
Procedure GroupCompositionAfterFieldChoice(AvailableDCField, ExecutionParameters) Export
	If AvailableDCField = Undefined Then
		Return;
	EndIf;
	
	Result = FieldTablesPaste("GroupComposition", Type("DataCompositionGroupField"), 0, False);
	
	DCItem = Result.DCItem;
	DCItem.Use = True;
	DCItem.Field          = AvailableDCField.Field;
	
	TableRow = Result.TableRow;
	TableRow.Use  = DCItem.Use;
	TableRow.Presentation  = AvailableDCField.Title;
	TableRow.GroupType = DCItem.GroupType;
	TableRow.AdditionType  = DCItem.AdditionType;
	TableRow.DCField         = DCItem.Field;
	
	If AvailableDCField.Resource Then
		TableRow.PictureIndex = ReportsClientServer.PictureIndex("Resource");
	ElsIf AvailableDCField.Table Then
		TableRow.PictureIndex = ReportsClientServer.PictureIndex("Table");
	ElsIf AvailableDCField.Folder Then
		TableRow.PictureIndex = ReportsClientServer.PictureIndex("Group");
	Else
		TableRow.PictureIndex = ReportsClientServer.PictureIndex("Item");
	EndIf;
	
	TypesInformation = ReportsClientServer.TypesAnalysis(AvailableDCField.ValueType, False);
	If TypesInformation.ContainsPeriodType Or TypesInformation.ContainsDateType Then
		TableRow.ShowAdditionType = True;
	EndIf;
	
	AfterChangeUsageCheckBox("GroupComposition", TableRow, DCItem);
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure GroupContentContentTypeOnChange(Item)
	FieldTablesChangeGroupType("GroupComposition");
EndProcedure

&AtClient
Procedure GroupContentAdditionTypeOnChange(Item)
	FieldTablesChangeGroupType("GroupComposition");
EndProcedure

&AtClient
Procedure GroupContentBeforeDelete(Item, Cancel)
	FieldTablesBeforeDelete(Item.Name, Cancel);
EndProcedure

&AtClient
Procedure GroupContent_MoveUp(Command)
	
	Context = NewContext("GroupComposition", "Move");
	Context.Insert("Direction", -1);
	DefineSelectedRows(Context);
	If ValueIsFilled(Context.CancelReason) Then
		ShowMessageBox(, Context.CancelReason);
		Return;
	EndIf;
	
	MoveRows(Context);
	
EndProcedure

&AtClient
Procedure GroupContent_MoveDown(Command)
	
	Context = NewContext("GroupComposition", "Move");
	Context.Insert("Direction", 1);
	DefineSelectedRows(Context);
	If ValueIsFilled(Context.CancelReason) Then
		ShowMessageBox(, Context.CancelReason);
		Return;
	EndIf;
	
	MoveRows(Context);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAppearance

&AtClient
Procedure AppearanceBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder, Parameter)
	Cancel = True;
	If ExtendedMode = 0 Then
		Return;
	EndIf;
	
	AppearanceChangeItem("Appearance", Undefined, Undefined);
EndProcedure

&AtClient
Procedure AppearanceChoice(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	If ExtendedMode <> 1 Then
		Return;
	EndIf;
	TableRow = Items.Appearance.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	ColumnName = Field.Name;
	If ColumnName = "AppearanceHeader" Then // Change order.
		
		AppearanceChangeItem("Appearance", RowSelected, TableRow);
		
	ElsIf ColumnName = "AppearanceAccessPictureIndex" Then // Change quick access for the filter.
		
		FieldTablesChangeAccessLevel("Appearance", RowSelected, True, False);
		
	EndIf;
EndProcedure

&AtClient
Procedure AppearanceBeforeDelete(Item, Cancel)
	FieldTablesBeforeDelete(Item.Name, Cancel);
EndProcedure

&AtClient
Procedure AppearanceUsageOnChange(Item)
	FieldTablesChangeUsage("Appearance");
EndProcedure

&AtClient
Procedure Appearance_MoveUp(Command)

	Context = NewContext("Appearance", "Move");
	Context.Insert("Direction", -1);
	DefineSelectedRows(Context);
	If ValueIsFilled(Context.CancelReason) Then
		ShowMessageBox(, Context.CancelReason);
		Return;
	EndIf;
	
	MoveRows(Context);
	
EndProcedure

&AtClient
Procedure Appearance_MoveDown(Command)

	Context = NewContext("Appearance", "Move");
	Context.Insert("Direction", 1);
	DefineSelectedRows(Context);
	If ValueIsFilled(Context.CancelReason) Then
		ShowMessageBox(, Context.CancelReason);
		Return;
	EndIf;
	
	MoveRows(Context);
	
EndProcedure

&AtClient
Procedure Appearance_SelectCheckBoxes(Command)
	SetUsageCheckBoxesInWholeTree("Appearance", True);
EndProcedure

&AtClient
Procedure Appearance_ClearCheckBoxes(Command)
	SetUsageCheckBoxesInWholeTree("Appearance", False);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CloseAndGenerate(Command)
	
	If CheckErrors() Then
		Return;
	EndIf;
	
	WriteAndClose(True);
	
EndProcedure

&AtClient
Procedure CloseWithoutGenerating(Command)
	
	If CheckErrors() Then
		Return;
	EndIf;
	
	WriteAndClose(False);
	
EndProcedure

&AtClient
Procedure DefaultSettings(Command)
	FillingParameters = New Structure;
	FillingParameters.Insert("EventName", "DefaultSettings");
	FillingParameters.Insert("UserSettingsModified", True);
	FillingParameters.Insert("ResetUserSettings", True);
	FillQuickSettingsClient(FillingParameters);
EndProcedure

&AtClient
Procedure EditFilterCriteria(Command)
	FormParameters = New Structure;
	FormParameters.Insert("ReportSettings", ReportSettings);
	FormParameters.Insert("SettingsComposer", Report.SettingsComposer);
	Handler = New NotifyDescription("EditFilterCriteriaCompletion", ThisObject);
	OpenForm("SettingsStorage.ReportsVariantsStorage.Form.ReportFiltersConditions", FormParameters, ThisObject, True, , , Handler);
EndProcedure

&AtClient
Procedure EditFilterCriteriaCompletion(UserSelection, Context) Export
	If UserSelection = Undefined
		Or UserSelection = DialogReturnCode.Cancel
		Or UserSelection.Count() = 0 Then
		Return;
	EndIf;
	FillingParameters = New Structure;
	FillingParameters.Insert("EventName", "EditFilterCriteria");
	FillingParameters.Insert("UserSettingsModified", True);
	FillingParameters.Insert("FiltersConditions", UserSelection);
	FillQuickSettingsClient(FillingParameters);
EndProcedure

&AtClient
Procedure ClearNonexistingFieldsFromSettings(Command)
	ExtendedMode = 1;
	FillingParameters = New Structure;
	FillingParameters.Insert("EventName", "ClearNonexistingFieldsFromSettings");
	FillingParameters.Insert("VariantModified", True);
	FillingParameters.Insert("UserSettingsModified", True);
	FillingParameters.Insert("ClearNonexistingFieldsFromSettings", True);
	FillingParameters.Insert("ResetUserSettings", True);
	FillQuickSettingsClient(FillingParameters);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Attachable commands

&AtClient
Procedure Attachable_ChangeComparisonKind(Command)
	ItemID = Right(Command.Name, 32);
	Context = New Structure;
	Context.Insert("ItemID", ItemID);
	Handler = New NotifyDescription("AfterComparisonTypeChoice", ThisObject, Context);
	ReportsClient.ChangeComparisonType(ThisObject, ItemID, Handler);
EndProcedure

&AtClient
Procedure AfterComparisonTypeChoice(ComparisonType, Context) Export
	If ComparisonType <> Undefined Then
		FillingParameters = New Structure;
		FillingParameters.Insert("EventName", "ChangeComparisonType");
		FillingParameters.Insert("UserSettingsModified", True);
		FillQuickSettingsClient(FillingParameters);
	EndIf;
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure FiltersOnChangeCurrentRow() Export
	
	TableRow = Items.Filters.CurrentData;
	If TableRow = Undefined Then
		FiltersOnCurrentRowChangeAtServer(False, False);
		Return;
	EndIf;
	
	IsFilter = Not TableRow.IsParameter AND Not TableRow.IsSection;
	IsParameterOrFilter = Not TableRow.IsSection;
	
	FiltersOnCurrentRowChangeAtServer(IsFilter, IsParameterOrFilter);
	
	If Not TableRow.IsSection AND Not TableRow.IsFolder Then
		Items.FiltersValue.ChoiceFoldersAndItems = ReportsClientServer.CastValueToGroupsAndItemsType(
			TableRow.Condition,
			TableRow.ChoiceFoldersAndItems);
	EndIf;
	
EndProcedure

&AtServer
Procedure FiltersOnCurrentRowChangeAtServer(IsFilter, IsParameterOrFilter)
	
	Items.Filters_Delete.Enabled  = IsFilter;
	Items.Filters_Delete1.Enabled = IsFilter;
	Items.Filters_Group.Enabled  = IsFilter;
	Items.Filters_Group1.Enabled = IsFilter;
	Items.Filters_Ungroup.Enabled  = IsFilter;
	Items.Filters_Ungroup1.Enabled = IsFilter;
	Items.Filters_MoveUp.Enabled  = IsFilter;
	Items.Filters_MoveUp1.Enabled = IsFilter;
	Items.Filters_MoveDown.Enabled  = IsFilter;
	Items.Filters_MoveDown1.Enabled = IsFilter;
	
	Items.FiltersCommands_Show.Enabled  = IsParameterOrFilter;
	Items.FiltersCommands_Show1.Enabled = IsParameterOrFilter;
	Items.Filters_ShowOnlyCheckBoxInReportHeader.Enabled  = IsFilter;
	Items.Filters_ShowOnlyCheckBoxInReportHeader1.Enabled = IsFilter;
	Items.Filters_ShowOnlyCheckBoxInReportSettings.Enabled  = IsFilter;
	Items.Filters_ShowOnlyCheckBoxInReportSettings1.Enabled = IsFilter;
	
EndProcedure

&AtClient
Procedure WriteAndClose(Regenerate)
	NotifyChoice(SelectionResult(Regenerate));
EndProcedure

&AtClient
Function SelectionResult(Regenerate)
	SelectionResultGenerated = True;
	
	If OptionNodeChangeMode AND Not Regenerate Then
		Return Undefined;
	EndIf;
	
	SelectionResult = New Structure;
	SelectionResult.Insert("EventName", "SettingsForm");
	SelectionResult.Insert("Regenerate", Regenerate);
	SelectionResult.Insert("VariantModified", OptionChanged);
	SelectionResult.Insert("UserSettingsModified", OptionChanged Or UserSettingsModified);
	SelectionResult.Insert("SettingsFormAdvancedMode", ExtendedMode);
	SelectionResult.Insert("SettingsFormPageName", Items.SettingsPages.CurrentPage.Name);
	
	If SelectionResult.VariantModified Then
		SelectionResult.Insert("DCSettings", Report.SettingsComposer.Settings);
	EndIf;
	If SelectionResult.UserSettingsModified Then
		SelectionResult.Insert("DCUserSettings", Report.SettingsComposer.UserSettings);
	EndIf;
	If OptionChanged AND ExtendedMode = 1 Then
		SelectionResult.Insert("ResetUserSettings", True);
	EndIf;
	
	Return SelectionResult;
EndFunction

&AtClient
Function FindUserSettingOfItem(ItemID) Export
	// The application stores data composition IDs for user settings because the settings cannot be 
	//  stored by reference (this will lead to copying the value).
	If ItemID = "Sort" Then
		If OptionNodeChangeMode Then
			RootNode = Report.SettingsComposer.Settings.GetObjectByID(CurrentDCNodeID);
			Return RootNode.Order;
		ElsIf ExtendedMode = 1 Then
			Return Report.SettingsComposer.Settings.Order;
		Else
			ItemID = ItemID;
		EndIf;
	ElsIf ItemID = "SelectedFields" Then
		If OptionNodeChangeMode Then
			RootNode = Report.SettingsComposer.Settings.GetObjectByID(CurrentDCNodeID);
			Return RootNode.Selection;
		ElsIf ExtendedMode = 1 Then
			Return Report.SettingsComposer.Settings.Selection;
		Else
			ItemID = ItemID;
		EndIf;
	ElsIf ItemID = "Filters" Then
		If OptionNodeChangeMode Then
			RootNode = Report.SettingsComposer.Settings.GetObjectByID(CurrentDCNodeID);
			Return RootNode.Filter;
		ElsIf ExtendedMode = 1 Then
			Return Report.SettingsComposer.Settings.Filter;
		Else
			ItemID = ItemID;
		EndIf;
	ElsIf ItemID = "OptionStructure" Then
		If ExtendedMode = 1 Then
			Return Report.SettingsComposer.Settings;
		Else
			Return Report.SettingsComposer.UserSettings;
		EndIf;
	EndIf;
	DCID = QuickSearchForUserSettings.Get(ItemID);
	Return Report.SettingsComposer.UserSettings.GetObjectByID(DCID);
EndFunction

&AtClient
Function FindAdditionalItemSettings(ItemID) Export
	// The application stores data composition IDs for user settings because the settings cannot be 
	//  stored by reference (this will lead to copying the value).
	AllAdditionalSettings = CommonClientServer.StructureProperty(Report.SettingsComposer.UserSettings.AdditionalProperties, "FormItems");
	If AllAdditionalSettings = Undefined Then
		Return Undefined;
	Else
		Return AllAdditionalSettings[ItemID];
	EndIf;
EndFunction

&AtClient
Procedure FillQuickSettingsClient(FillingParameters = Undefined)
	If FillingParameters = Undefined Then
		FillingParameters = New Structure("EventName", "AfterChangeCollection");
	EndIf;
	FillingParametersAtClient = FillingParameters;
	AttachIdleHandler("FillQuickSettingsDeferred", 0.1, True);
EndProcedure

&AtClient
Procedure FillQuickSettingsDeferred()
	QuickSettingsFill(FillingParametersAtClient);
	ShowSettingsFillingResult();
EndProcedure

&AtClient
Procedure ShowSettingsFillingResult()
	If TypeOf(SettingsFillingResult) <> Type("Structure") Then
		Return;
	EndIf;
	
	// For the platform (redefine values available at the client).
	OwnSelectionLists = CommonClientServer.StructureProperty(SettingsFillingResult, "OwnSelectionLists");
	If TypeOf(OwnSelectionLists) = Type("Array") Then
		For Each ItemID In OwnSelectionLists Do
			OptionSettingsItem = FindOptionSetting(ThisObject, ItemID);
			If OptionSettingsItem = Undefined Then
				Continue;
			EndIf;
			AdditionalSettings = FindAdditionalItemSettings(ItemID);
			If AdditionalSettings = Undefined Then
				Continue;
			EndIf;
			Type = TypeOf(OptionSettingsItem.DCItem);
			If Type = Type("DataCompositionSettingsParameterValue") Then
				AvailableParameters = OptionSettingsItem.DCNode.AvailableParameters;
				If AvailableParameters = Undefined Then
					Continue;
				EndIf;
				AvailableDCSetting = AvailableParameters.FindParameter(OptionSettingsItem.DCItem.Parameter);
			ElsIf Type = Type("DataCompositionFilterItem") Then
				FilterAvailableFields = OptionSettingsItem.DCNode.FilterAvailableFields;
				If FilterAvailableFields = Undefined Then
					Continue;
				EndIf;
				AvailableDCSetting = FilterAvailableFields.FindField(OptionSettingsItem.DCItem.LeftValue);
			EndIf;
			If AvailableDCSetting = Undefined
				Or TypeOf(AvailableDCSetting.AvailableValues) <> Type("ValueList") Then
				Continue;
			EndIf;
			Try
				AvailableDCSetting.AvailableValues.Clear();
				For Each Item In AdditionalSettings.ValuesForSelection Do
					FillPropertyValues(AvailableDCSetting.AvailableValues.Add(), Item);
				EndDo;
			Except
				Continue;
			EndTry;
		EndDo;
	EndIf;
	
	// Expand tree nodes.
	ExpandTreeNodes = CommonClientServer.StructureProperty(SettingsFillingResult, "ExpandTreeNodes");
	If TypeOf(ExpandTreeNodes) = Type("Array") Then
		For Each FormItemName In ExpandTreeNodes Do
			StandardSubsystemsClient.ExpandTreeNodes(ThisObject, FormItemName, "*", True);
		EndDo;
	EndIf;
	
	SettingsFillingResult.Clear();
	SettingsFillingResult = Undefined;
EndProcedure

&AtClient
Procedure SetOutputParameter(DCItem, Name, Value = Undefined, Usage = True)
	DCParameter = DCItem.OutputParameters.FindParameterValue(New DataCompositionParameter(Name));
	If DCParameter = Undefined Then
		Return;
	EndIf;
	If Value <> Undefined Then
		DCParameter.Value = Value;
	EndIf;
	If Usage <> Undefined Then
		DCParameter.Use = Usage;
	EndIf;
EndProcedure

&AtClient
Procedure UpdateUniversalReportParameters(DCUserSetting)
	
	SettingsUpdateRequired = False;
	ParametersToClear = New Array;
	
	MetadataObjectTypeParameter = Report.SettingsComposer.Settings.DataParameters.Items.Find("MetadataObjectType");
	If MetadataObjectTypeParameter <> Undefined Then
		If DCUserSetting.Parameter = MetadataObjectTypeParameter.Parameter
				AND MetadataObjectTypeParameter.Value <> DCUserSetting.Value Then
			MetadataObjectTypeParameter.Value = DCUserSetting.Value;
			SettingsUpdateRequired = True;
			ParametersToClear.Add("DataSource");
			ParametersToClear.Add("MetadataObjectName");
			ParametersToClear.Add("TableName");
		EndIf;
	EndIf;
	MetadataObjectNameParameter = Report.SettingsComposer.Settings.DataParameters.Items.Find("MetadataObjectName");
	If MetadataObjectNameParameter <> Undefined Then
		If DCUserSetting.Parameter = MetadataObjectNameParameter.Parameter
				AND MetadataObjectNameParameter.Value <> DCUserSetting.Value Then
			MetadataObjectNameParameter.Value = DCUserSetting.Value;
			SettingsUpdateRequired = True;
			ParametersToClear.Add("DataSource");
			ParametersToClear.Add("TableName");
		EndIf;
	EndIf;
	TableNameParameter = Report.SettingsComposer.Settings.DataParameters.Items.Find("TableName");
	If TableNameParameter <> Undefined Then
		If DCUserSetting.Parameter = TableNameParameter.Parameter
				AND TableNameParameter.Value <> DCUserSetting.Value Then
			SettingsUpdateRequired = True;
			TableNameParameter.Value = DCUserSetting.Value;
		EndIf;
	EndIf;
	
	For Each ParameterToClear In ParametersToClear Do
		Parameter = Report.SettingsComposer.Settings.DataParameters.Items.Find(ParameterToClear);
		If Parameter <> Undefined Then
			Parameter.Value = "";
		EndIf;
	EndDo;
	
	If SettingsUpdateRequired Then
		Report.SettingsComposer.Settings.AdditionalProperties.Insert("ReportInitialized", False);
		FillingParameters = New Structure;
		FillingParameters.Insert("VariantModified", True);
		FillingParameters.Insert("UserSettingsModified", True);
		FillingParameters.Insert("ResetUserSettings", True);
		FillingParameters.Insert("DCSettingsComposer", Report.SettingsComposer);
		FillQuickSettingsClient(FillingParameters);
	EndIf;
	
EndProcedure

&AtClient
Function NewContext(Val TableName, Val Action)
	Result = New Structure;
	Result.Insert("CancelReason", "");
	Result.Insert("TableName", TableName);
	Result.Insert("Action", Action);
	Return Result;
EndFunction

&AtClient
Procedure UpdateForm(Context)
	FillingParameters = New Structure("EventName", Context.TableName + "." + Context.Action);
	FillQuickSettingsClient(FillingParameters);
EndProcedure

&AtClient
Procedure DefineSelectedRows(Context)
	Context.Insert("TreeRows", New Array); // Selected rows (not IDs).
	Context.Insert("CurrentRow", Undefined); // An active row (not an ID).
	TableItem = Items[Context.TableName];
	TableAttribute = ThisObject[Context.TableName];
	IDCurrentRow = TableItem.CurrentRow;
	
	Features = New Structure("CanBeSections, CanBeParameters, CanBeGroups,
		|RequireOneParent");
	Features.CanBeSections = (Context.TableName = "Filters" Or Context.TableName = "SelectedFields" Or Context.TableName = "Sort");
	Features.CanBeParameters = (Context.TableName = "Filters");
	Features.RequireOneParent = (Context.Action = "Move" Or Context.Action = "Group");
	Features.CanBeGroups = (Context.TableName = "Filters" Or Context.TableName = "SelectedFields");
	If Features.RequireOneParent Then
		Context.Insert("CurrentParent", -1);
	EndIf;
	If Features.CanBeGroups Then
		HadGroups = False;
	EndIf;
	
	SelectedRows = ArraySort(TableItem.SelectedRows, SortDirection.Asc);
	For Each IDRow In SelectedRows Do
		TreeRow = TableAttribute.FindByID(IDRow);
		If Not AddSelectedRow(Context, TreeRow, Features) Then
			Return;
		EndIf;
		If Features.CanBeGroups AND TreeRow.IsFolder Then
			HadGroups = True;
		EndIf;
		If IDRow = IDCurrentRow Then
			Context.CurrentRow = TreeRow;
		EndIf;
	EndDo;
	If Context.TreeRows.Count() = 0 Then
		Context.CancelReason = NStr("en = 'Select items.'; ru = 'Выберите элементы.';pl = 'Wybrane elementy.';es_ES = 'Seleccionar los artículos.';es_CO = 'Seleccionar los artículos.';tr = 'Öğeleri seçin.';it = 'Seleziona elementi.';de = 'Elemente auswählen.'");
		Return;
	EndIf;
	If Context.CurrentRow = Undefined Then
		If Context.Action = "ChangeGroup" Then
			Context.CancelReason = NStr("en = 'Select group.'; ru = 'Выберите группу.';pl = 'Wybierz grupę.';es_ES = 'Seleccionar un grupo.';es_CO = 'Seleccionar un grupo.';tr = 'Grubu seçin.';it = 'Seleziona gruppo.';de = 'Gruppe auswählen.'");
			Return;
		EndIf;
	EndIf;
	
	// Remove all subordinate rows that have parents enabled from the list of rows to be deleted.
	If Context.Action = "Delete" AND Features.CanBeGroups AND HadGroups Then
		Count = Context.TreeRows.Count();
		For Number = 1 To Count Do
			ReverseIndex = Count - Number;
			Parent = Context.TreeRows[ReverseIndex];
			While Parent <> Undefined Do
				Parent = Parent.GetParent();
				If Context.TreeRows.Find(Parent) <> Undefined Then
					Context.TreeRows.Delete(ReverseIndex);
					Break;
				EndIf;
			EndDo;
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Function AddSelectedRow(Rows, TreeRow, Features)
	If Rows.TreeRows.Find(TreeRow) <> Undefined Then
		Return True; // Skip the row.
	EndIf;
	If Features.CanBeSections AND TreeRow.IsSection Then
		Return True; // Skip the row.
	EndIf;
	If Features.CanBeParameters AND TreeRow.IsParameter Then
		If Rows.Action = "Move" Then
			Rows.CancelReason = NStr("en = 'Parameters cannot be transferred.'; ru = 'Параметры не могут быть перемещены.';pl = 'Parametry nie mogą zostać przesłane.';es_ES = 'No se puede transferir los parámetros.';es_CO = 'No se puede transferir los parámetros.';tr = 'Parametreler aktarılamadı.';it = 'I parametri non possono essere spostati.';de = 'Parameter können nicht übertragen werden.'");
		ElsIf Rows.Action = "Group" Then
			Rows.CancelReason = NStr("en = 'Parameters cannot be group participants.'; ru = 'Параметры не могут быть участниками групп.';pl = 'Parametry nie mogą być uczestnikami grupy.';es_ES = 'Parámetros no pueden ser los participantes del grupo.';es_CO = 'Parámetros no pueden ser los participantes del grupo.';tr = 'Parametreler grup katılımcısı olamaz.';it = 'I parametri non possono essere membri di gruppi.';de = 'Parameter können keine Gruppenteilnehmer sein.'");
		ElsIf Rows.Action = "Delete" Then
			Rows.CancelReason = NStr("en = 'Parameters cannot be deleted.'; ru = 'Параметры не могут быть удалены.';pl = 'Parametry nie mogą być usunięte.';es_ES = 'No se puede borrar los parámetros.';es_CO = 'No se puede borrar los parámetros.';tr = 'Parametreler silinemedi.';it = 'I parametri non possono essere eliminati.';de = 'Parameter können nicht gelöscht werden.'");
		EndIf;
		Return False; 	EndIf;
	If Features.RequireOneParent Then
		Parent = TreeRow.GetParent();
		If Rows.CurrentParent = -1 Then
			Rows.CurrentParent = Parent;
		ElsIf Rows.CurrentParent <> Parent Then
			If Rows.Action = "Move" Then
				Rows.CancelReason = NStr("en = 'The selected items cannot be transferred as they have different parents.'; ru = 'Выбранные элементы не могут быть перемещены, поскольку они принадлежат разным родителям.';pl = 'Nie można przenieść wybranych dokumentów, ponieważ mają one różnych ""rodziców"".';es_ES = 'Los artículos seleccionados no pueden transferirse porque tienen diferentes padres.';es_CO = 'Los artículos seleccionados no pueden transferirse porque tienen diferentes padres.';tr = 'Seçilen öğeler farklı üst öğeleri olduğu için aktarılamaz.';it = 'Gli oggetti selezionati non possono essere spostati perché appartengono a genitori diversi.';de = 'Die ausgewählten Elemente können nicht übertragen werden, da sie unterschiedliche Übergeordnete haben.'");
			ElsIf Rows.Action = "Group" Then
				Rows.CancelReason = NStr("en = 'The selected items cannot be grouped as they have different parents.'; ru = 'Выбранные элементы не могут быть сгруппированы, поскольку они принадлежат разным родителям.';pl = 'Nie można zgrupować wybranych dokumentów, ponieważ mają one różnych ""rodziców"".';es_ES = 'Los artículos seleccionados no pueden agruparse porque tienen diferentes padres.';es_CO = 'Los artículos seleccionados no pueden agruparse porque tienen diferentes padres.';tr = 'Seçilen öğeler farklı üst öğeleri olduğu için aktarılamaz.';it = 'Gli elementi selezionati non possono essere raggruppati, poiché appartengono a genitori diversi.';de = 'Die ausgewählten Elemente können nicht gruppiert werden, da sie unterschiedliche Übergeordnete haben.'");
			EndIf;
			Return False; 
		EndIf;
	EndIf;
	Rows.TreeRows.Add(TreeRow);
	Return True; // Next row.
EndFunction

&AtClient
Procedure GroupRows(Context)
	CurrentParent = Context.CurrentParent;
	TableItem = Items[Context.TableName];
	DCNode = FieldTablesFindNode(ThisObject, Context.TableName, Undefined);
	
	If Context.CurrentParent = Undefined Then
		TableAttribute = ThisObject[Context.TableName];
		If Context.TableName = "Filters" AND Not OptionNodeChangeMode Then
			CurrentParent = TableAttribute.GetItems()[1];
		Else
			CurrentParent = TableAttribute;
		EndIf;
		DCCurrentParent = DCNode;
	ElsIf TypeOf(CurrentParent.DCID) <> Type("DataCompositionID") Then
		DCCurrentParent = DCNode;
	Else
		DCCurrentParent = DCNode.GetObjectByID(CurrentParent.DCID);
	EndIf;
	ParentRows = CurrentParent.GetItems();
	DCParentRows = DCCurrentParent.Items;
	
	// Checks are passed. Add a group to a parent's parent.
	Groups = FieldTablesPaste(Context.TableName, Context.DCGroupType, 0, False);
	
	DCItem = Groups.DCItem;
	DCItem.Use = True;
	NewCollectionOfDCItems = DCItem.Items;
	
	TreeGroup = Groups.TableRow;
	TreeGroup.Use = DCItem.Use;
	TreeGroup.IsFolder = True;
	NewTreeRowsCollection = TreeGroup.GetItems();
	
	If Context.TableName = "Filters" Then
		TreeGroup.Presentation = String(DCItem.GroupType);
		TreeGroup.PictureIndex = -1;
		TreeGroup.AccessPictureIndex = 5;
		TreeGroup.Title = TreeGroup.Presentation;
	Else
		DCItem.Title    = Context.GroupTitle;
		DCItem.Placement = Context.Placement;
		TreeGroup.PictureIndex = ReportsClientServer.PictureIndex("Group");
		TreeGroup.Presentation  = DCItem.Title;
		If DCItem.Placement <> DataCompositionFieldPlacement.Auto Then
			TreeGroup.Presentation = TreeGroup.Presentation + " (" + String(DCItem.Placement) + ")";
		EndIf;
	EndIf;
	
	For Each OldTreeRow In Context.TreeRows Do
		OldDCItem = DCNode.GetObjectByID(OldTreeRow.DCID);
		FieldTablesCopyRecursively(DCNode, OldTreeRow, NewTreeRowsCollection, OldDCItem, NewCollectionOfDCItems);
		ParentRows.Delete(OldTreeRow);
		DCParentRows.Delete(OldDCItem);
	EndDo;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		OptionChanged = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure MoveRows(Context)
	CurrentParent = Context.CurrentParent;
	TableItem = Items[Context.TableName];
	DCNode = FieldTablesFindNode(ThisObject, Context.TableName, Undefined);
	
	If Context.CurrentParent = Undefined Then
		TableAttribute = ThisObject[Context.TableName];
		If Context.TableName = "Filters" AND Not OptionNodeChangeMode Then
			CurrentParent = TableAttribute.GetItems()[1];
		Else
			CurrentParent = TableAttribute;
		EndIf;
		DCCurrentParent = DCNode;
	ElsIf TypeOf(CurrentParent.DCID) <> Type("DataCompositionID") Then
		DCCurrentParent = DCNode;
	Else
		DCCurrentParent = DCNode.GetObjectByID(CurrentParent.DCID);
	EndIf;
	ParentRows = CurrentParent.GetItems();
	DCParentRows = GetDCItems(DCNode, DCCurrentParent);
	
	UpperRowsBound = ParentRows.Count() - 1;
	RowsSelected = Context.TreeRows.Count();
	
	// An array of selected rows towards the movement:
	// If we move rows to "+", we iterate from greater to smaller.
	// If we move rows to "-", we iterate from smaller to greater.
	MoveAscending = (Context.Direction < 0);
	
	For Number = 1 To RowsSelected Do
		If MoveAscending Then 
			IndexInArray = Number - 1;
		Else
			IndexInArray = RowsSelected - Number;
		EndIf;
		
		TreeRow = Context.TreeRows[IndexInArray];
		DCItem = DCNode.GetObjectByID(TreeRow.DCID);
		
		IndexInTree = ParentRows.IndexOf(TreeRow);
		WhereRowWillBe = IndexInTree + Context.Direction;
		If WhereRowWillBe < 0 Then // Move "to the end".
			ParentRows.Move(IndexInTree, UpperRowsBound - IndexInTree);
			DCParentRows.Move(DCItem, UpperRowsBound - IndexInTree);
		ElsIf WhereRowWillBe > UpperRowsBound Then // Move "to the beginning".
			ParentRows.Move(IndexInTree, -IndexInTree);
			DCParentRows.Move(DCItem, -IndexInTree);
		Else
			ParentRows.Move(IndexInTree, Context.Direction);
			DCParentRows.Move(DCItem, Context.Direction);
		EndIf;
	EndDo;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		OptionChanged = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteRows(Context)
	
	FieldTablesRemove(Context.TableName, Context.TreeRows, False);
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		OptionChanged = True;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client - parameters and filters.

&AtClient
Procedure FiltersShowPeriodSelection(TableRow)
	Context = New Structure;
	Context.Insert("IDRow", TableRow.GetID());
	Handler = New NotifyDescription("FiltersCompletePeriodSelection", ThisObject, Context);
	Dialog = New StandardPeriodEditDialog;
	Dialog.Period = TableRow.Value;
	Dialog.Show(Handler);
EndProcedure

&AtClient
Procedure FiltersCompletePeriodSelection(Period, Context) Export
	If Period = Undefined Then
		Return;
	EndIf;
	
	TableRow = Filters.FindByID(Context.IDRow);
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	DCNode = FieldTablesFindNode(ThisObject, "Filters", TableRow);
	DCItem = DCNode.GetObjectByID(TableRow.DCID);
	If DCItem = Undefined Then
		Return;
	EndIf;
	
	TableRow.Value = Period;
	TableRow.Condition = ReportsClientServer.GetStandardPeriodType(TableRow.Value);
	
	If TableRow.IsParameter Then
		DCItem.Value = TableRow.Value;
	Else
		DCItem.RightValue = TableRow.Value;
	EndIf;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		OptionChanged = True;
	EndIf;
EndProcedure

&AtClient
Procedure FiltersShowRefSelection(TableRow, StandardProcessing)
	ChoiceParameters = FilterSelectionParameters(TableRow);
	If ChoiceParameters = Undefined Then
		StandardProcessing = True;
		Return;
	EndIf;
	
	ChoiceParameters.Insert("MultipleChoice", False);
	ChoiceParameters.Insert("Marked",         ReportsClientServer.ValuesByList(TableRow.Value));
	ChoiceParameters.Insert("Presentation",      TableRow.Presentation);
	
	Context = New Structure;
	Context.Insert("IDRow", TableRow.GetID());
	Context.Insert("ChoiceParameters",     ChoiceParameters);
	Context.Insert("CurrentValue",     TableRow.Value);
	Context.Insert("FieldPresentation",   TableRow.Presentation);
	
	// Full name of the choice form.
	// The "ChoiceForm" property is unavailable on the client even in the read-only mode. Therefore, to 
	//   store predefined choice form names, use the QuickSearchForMetadataObjectsNames collection.
	If ValueIsFilled(ChoiceParameters.FormPath) Then
		Handler = New NotifyDescription("FiltersCompleteRefSelection", ThisObject, Context);
		OpenForm(
			ChoiceParameters.FormPath,
			ChoiceParameters,
			ThisObject,
			,
			,
			,
			Handler,
			FormWindowOpeningMode.LockOwnerWindow);
	Else
		// Select type from the list.
		ChoiceList = New ValueList;
		ChoiceList.LoadValues(ChoiceParameters.TypeDescription.Types());
		
		Handler = New NotifyDescription("FiltersShowRefSelectionAfterTypeChoice", ThisObject, Context);
		If ChoiceList.Count() = 1 Then // There is only one type, no need to select.
			ExecuteNotifyProcessing(Handler, ChoiceList[0]);
		Else
			ShowChooseFromMenu(Handler, ChoiceList);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure FiltersShowRefSelectionAfterTypeChoice(ListItem, Context) Export
	If TypeOf(ListItem) <> Type("ValueListItem") Then
		Return;
	EndIf;
	Handler = New NotifyDescription("FiltersCompleteRefSelection", ThisObject, Context);
	ChoiceParameters = Context.ChoiceParameters;
	
	Type = ListItem.Value;
	TypeChoiceParameters = ReportsOptionsServerCall.TypeChoiceParameters(Type, ChoiceParameters);
	If TypeChoiceParameters = Undefined Then
		ReportsClient.SelectPrimitiveTypeValue(
			ThisObject,
			Type,
			ChoiceParameters.TypeDescription,
			Context.CurrentValue,
			Context.FieldPresentation,
			Handler);
	ElsIf TypeChoiceParameters.QuickChoice Then
		ShowChooseFromMenu(Handler, TypeChoiceParameters.ValuesForSelection);
	Else
		OpenForm(
			TypeChoiceParameters.FormPath,
			ChoiceParameters,
			ThisObject,
			,
			,
			,
			Handler,
			FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

&AtClient
Procedure FiltersCompleteRefSelection(RefOrListItem, Context) Export
	If TypeOf(RefOrListItem) = Type("ValueListItem") Then
		NewValue = RefOrListItem.Value;
	Else
		NewValue = RefOrListItem;
	EndIf;
	If Not Context.ChoiceParameters.TypeDescription.ContainsType(TypeOf(NewValue)) Or Not ValueIsFilled(NewValue) Then
		Return;
	EndIf;
	
	TableRow = Filters.FindByID(Context.IDRow);
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	DCNode = FieldTablesFindNode(ThisObject, "Filters", TableRow);
	DCItem = DCNode.GetObjectByID(TableRow.DCID);
	If DCItem = Undefined Then
		Return;
	EndIf;
	
	SetValue(TableRow, DCNode, DCItem, NewValue);
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		OptionChanged = True;
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Procedure SetValue(TableRow, DCNode, DCItem, NewValue)
	If DCNode <> Undefined Then // The field is available by functional options
		If TableRow.IsParameter Then
			If TypeOf(DCNode) = Type("DataCompositionAvailableParameter") Then
				AvailableItemWithDC = DCNode;
			Else
				AvailableItemWithDC = DCNode.AvailableParameters.FindParameter(DCItem.Parameter);
			EndIf;
			EditFormat = AvailableItemWithDC.EditFormat;
			DCItem.Value = NewValue;
		Else
			If TypeOf(DCNode) = Type("DataCompositionFilterAvailableField") Then
				AvailableItemWithDC = DCNode;
			Else
			AvailableItemWithDC = DCNode.FilterAvailableFields.FindField(DCItem.LeftValue);
			EndIf;
			EditFormat = AvailableItemWithDC.EditFormat;
			DCItem.RightValue = NewValue;
		EndIf;
	EndIf;
	TableRow.Value = NewValue;
	If Not IsBlankString(EditFormat) Then
		TableRow.ValuePresentation = Format(NewValue, EditFormat);
	Else	
		TableRow.ValuePresentation = NewValue;
	EndIf;
EndProcedure
	
&AtClient
Procedure FiltersShowListWithCheckBoxes(TableRow)
	ChoiceParameters = FilterSelectionParameters(TableRow);
	If ChoiceParameters = Undefined Then
		Return;
	EndIf;
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("IDRow", TableRow.GetID());
	Handler = New NotifyDescription("FiltersCompleteInputWithCheckBoxesList", ThisObject, HandlerParameters);
	
	ChoiceParameters.Insert("Marked",    ReportsClientServer.ValuesByList(TableRow.Value));
	ChoiceParameters.Insert("Presentation", TableRow.Presentation);
	
	Block = FormWindowOpeningMode.LockOwnerWindow;
	
	OpenForm("CommonForm.InputValuesInListWithCheckBoxes", ChoiceParameters, ThisObject, , , , Handler, Block);
EndProcedure

&AtClient
Function FilterSelectionParameters(TableRow)
	ItemID = TableRow.GetID();
	
	DCNode = FieldTablesFindNode(ThisObject, "Filters", TableRow);
	DCItem = DCNode.GetObjectByID(TableRow.DCID);
	If DCItem = Undefined Then
		Return Undefined;
	EndIf;
	
	Result = New Structure("Presentation, ValuesForSelection, ValuesForSelectionFilled, QuickChoice,
	|RestrictSelectionBySpecifiedValues, TypeDescription, ListInput");
	
	AdditionalSettings = TableRow.More;
	FillPropertyValues(Result, AdditionalSettings);
	
	ChoiceOfGroupsAndItems = ReportsClientServer.CastValueToGroupsAndItemsUsageType(
		TableRow.Condition,
		TableRow.ChoiceFoldersAndItems);
	
	// If the ListInput check box is enabled, parameters are being prepared for the InputValuesInListWithCheckBoxes intermediate form.
	Result.Insert("ListInput", TableRow.ListInput);
	
	// Standard parameters of the form.
	Result.Insert("CloseOnChoice",            True);
	Result.Insert("CloseOnOwnerClose", True);
	Result.Insert("Filter",                         New Structure);
	// Standard parameters of the choice form (see Managed form extension for dynamic list).
	Result.Insert("ChoiceFoldersAndItems",          ChoiceOfGroupsAndItems);
	Result.Insert("MultipleChoice",            False);
	Result.Insert("ChoiceMode",                   True);
	// Supposed attributes.
	Result.Insert("WindowOpeningMode",             FormWindowOpeningMode.LockOwnerWindow);
	Result.Insert("EnableStartDrag", False);
	
	Result.Insert("FormPath", AdditionalSettings.ChoiceForm);
	
	Result.Insert("ChoiceParameters", New Array);
	Result.Insert("UniqueKey", DCItem.UserSettingID);
	
	// Fixed choice parameters and links from hidden master objects (predefined in the current context).
	For Each ChoiceParameter In AdditionalSettings.ChoiceParameters Do
		If IsBlankString(ChoiceParameter.Name) Then
			Continue;
		EndIf;
		If Result.ListInput Then
			Result.ChoiceParameters.Add(ChoiceParameter);
		Else
			If Upper(Left(ChoiceParameter.Name, 6)) = Upper("Filter.") Then
				Result.Filter.Insert(Mid(ChoiceParameter.Name, 7), ChoiceParameter.Value);
			Else
				Result.Insert(ChoiceParameter.Name, ChoiceParameter.Value);
			EndIf;
		EndIf;
	EndDo;
	
	// Dynamic links from master objects.
	Links = LinksThatCanBeDisabled.FindRows(New Structure("SubordinateIDInForm", ItemID));
	For Each Link In Links Do
		RowMaster = Filters.FindByID(Link.MainIDInForm);
		If RowMaster = Undefined Then
			Continue;
		EndIf;
		If Not RowMaster.Use Then
			Continue;
		EndIf;
		ValueOfMaster = RowMaster.Value;
		ValueTypeOfMaster = TypeOf(ValueOfMaster);
		If Link.LinkType = "ByType" Then
			If RowMaster.Condition <> DataCompositionComparisonType.Equal
				AND RowMaster.Condition <> DataCompositionComparisonType.InHierarchy Then
				Continue;
			EndIf;
			If TypeOf(Link.SubordinateParameterName) = Type("Number") AND Link.SubordinateParameterName > 0 Then
				ExtDimensionType = ReportsOptionsServerCall.ExtDimensionType(ValueOfMaster, Link.SubordinateParameterName);
				If TypeOf(ExtDimensionType) = Type("TypeDescription") Then
					FilterByTypes = ExtDimensionType.Types();
				Else
					Continue;
				EndIf;
			Else
				FilterByTypes = New Array;
				FilterByTypes.Add(ValueTypeOfMaster);
			EndIf;
			RemovedTypes = Result.TypeDescription.Types();
			DescriptionTypesOverlap = False;
			For Each TypeToKeep In FilterByTypes Do
				Index = RemovedTypes.Find(TypeToKeep);
				If Index <> Undefined Then
					RemovedTypes.Delete(Index);
					DescriptionTypesOverlap = True;
				EndIf;
			EndDo;
			If DescriptionTypesOverlap Then
				Result.TypeDescription = New TypeDescription(Result.TypeDescription, , RemovedTypes);
			EndIf;
		ElsIf Link.LinkType = "ByMetadata" Or Link.LinkType = "SelectionParameters" Then
			If Not ValueIsFilled(Link.SubordinateParameterName) Then
				Continue;
			EndIf;
			If Link.LinkType = "ByMetadata" AND Not Link.MainType.ContainsType(ValueTypeOfMaster) Then
				Continue;
			EndIf;
			If Result.ListInput Then
				Result.ChoiceParameters.Add(New ChoiceParameter(Link.SubordinateParameterName, ValueOfMaster));
			Else
				If Upper(Left(Link.SubordinateParameterName, 7)) = Upper("Filter.") Then
					Result.Filter.Insert(Mid(Link.SubordinateParameterName, 8), ValueOfMaster);
				Else
					Result.Insert(Link.SubordinateParameterName, ValueOfMaster);
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

&AtClient
Procedure FiltersCompleteInputWithCheckBoxesList(SelectionResult, Context) Export
	If TypeOf(SelectionResult) <> Type("ValueList") Then
		Return;
	EndIf;
	
	TableRow = Filters.FindByID(Context.IDRow);
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	DCNode = FieldTablesFindNode(ThisObject, "Filters", TableRow);
	DCItem = DCNode.GetObjectByID(TableRow.DCID);
	If DCItem = Undefined Then
		Return;
	EndIf;
	
	AdditionalSettings = TableRow.More;
	
	// Load selected values in 2 lists.
	ValueListInDCS = New ValueList;
	If Not AdditionalSettings.RestrictSelectionBySpecifiedValues Then
		AdditionalSettings.ValuesForSelection = New ValueList;
	EndIf;
	For Each ListItemInForm In SelectionResult Do
		ValueInForm = ListItemInForm.Value;
		If Not AdditionalSettings.RestrictSelectionBySpecifiedValues Then
			If AdditionalSettings.ValuesForSelection.FindByValue(ValueInForm) <> Undefined Then
				Continue;
			EndIf;
			FillPropertyValues(AdditionalSettings.ValuesForSelection.Add(), ListItemInForm);
		EndIf;
		If ListItemInForm.Check Then
			ReportsClientServer.AddUniqueValueToList(ValueListInDCS, ValueInForm, ListItemInForm.Presentation, True);
		EndIf;
	EndDo;
	If TypeOf(DCItem) = Type("DataCompositionFilterItem") Then
		DCItem.RightValue = ValueListInDCS;
	Else
		DCItem.Value = ValueListInDCS;
	EndIf;
	TableRow.Value = ValueListInDCS;
	
	// Enable the Usage check box.
	DCItem.Use = True;
	TableRow.Use = True;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		OptionChanged = True;
	EndIf;
EndProcedure

&AtClient
Procedure FiltersSelectComparisonType(TableRow)
	If TableRow.IsParameter Then
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("IDRow", TableRow.GetID());
	Handler = New NotifyDescription("FiltersCompleteComparisonTypeSelection", ThisObject, Context);
	
	TypesInformation = ReportsClientServer.TypesAnalysis(TableRow.ValueType, False);
	BooleanOnly = TypesInformation.ContainsBooleanType AND TypesInformation.PrimitiveTypesNumber = 1;
	FixedList = CommonClientServer.StructureProperty(TableRow.More, "RestrictSelectionBySpecifiedValues", False);
	
	List = New ValueList;
	
	If TypesInformation.ReducedLengthItem Or FixedList Then
		
		List.Add(DataCompositionComparisonType.Equal);
		List.Add(DataCompositionComparisonType.NotEqual);
		
		If TypesInformation.ContainsObjectTypes Or FixedList Then
			List.Add(DataCompositionComparisonType.InList);
			List.Add(DataCompositionComparisonType.NotInList);
		EndIf;
		
	EndIf;
	
	If TypesInformation.ReducedLengthItem AND TypesInformation.ContainsObjectTypes Then
		
		List.Add(DataCompositionComparisonType.InListByHierarchy); // In the list including subordinate objects
		List.Add(DataCompositionComparisonType.NotInListByHierarchy); // Not in the list including subordinate objects
		
		List.Add(DataCompositionComparisonType.InHierarchy); // In group
		List.Add(DataCompositionComparisonType.NotInHierarchy); // Not in group
		
	EndIf;
	
	If TypesInformation.ReducedLengthItem AND TypesInformation.PrimitiveTypesNumber > 0 AND Not BooleanOnly Then
		
		List.Add(DataCompositionComparisonType.Less);
		List.Add(DataCompositionComparisonType.LessOrEqual);
		
		List.Add(DataCompositionComparisonType.Greater);
		List.Add(DataCompositionComparisonType.GreaterOrEqual);
		
	EndIf;
	
	If Not FixedList AND TypesInformation.ContainsStringType Then
		
		List.Add(DataCompositionComparisonType.Contains);
		List.Add(DataCompositionComparisonType.NotContains);
		
		List.Add(DataCompositionComparisonType.Like);
		List.Add(DataCompositionComparisonType.NotLike);
		
		List.Add(DataCompositionComparisonType.BeginsWith);
		List.Add(DataCompositionComparisonType.NotBeginsWith);
		
	EndIf;
	
	If TypesInformation.ContainsDateType Or TypesInformation.ContainsStringType 
		Or FixedList Or TypesInformation.ContainsObjectTypes Then
		
		List.Add(DataCompositionComparisonType.Filled);
		List.Add(DataCompositionComparisonType.NotFilled);
		
	EndIf;
	
	ShowChooseFromMenu(Handler, List, Items.Filters);
	
EndProcedure

&AtClient
Procedure FiltersCompleteComparisonTypeSelection(Result, Context) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
	TableRow = Filters.FindByID(Context.IDRow);
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	DCNode = FieldTablesFindNode(ThisObject, "Filters", TableRow);
	DCItem = DCNode.GetObjectByID(TableRow.DCID);
	If DCItem = Undefined Then
		Return;
	EndIf;
	
	TableRow.Condition  = Result.Value;
	DCItem.ComparisonType = Result.Value;
	
	ListInputWasUsed = TableRow.ListInput;
	BecameListInput = False;
	If TableRow.Condition = DataCompositionComparisonType.InHierarchy
		Or TableRow.Condition = DataCompositionComparisonType.NotInHierarchy Then
		TableRow.ChoiceFoldersAndItems = FoldersAndItems.Folders;
	Else
		If TableRow.Condition = DataCompositionComparisonType.InList
			Or TableRow.Condition = DataCompositionComparisonType.InListByHierarchy
			Or TableRow.Condition = DataCompositionComparisonType.NotInList
			Or TableRow.Condition = DataCompositionComparisonType.NotInListByHierarchy Then
				BecameListInput = True;
		EndIf;
		TableRow.ChoiceFoldersAndItems = FoldersAndItems.FoldersAndItems;
	EndIf;
	Items.FiltersValue.ChoiceFoldersAndItems = TableRow.ChoiceFoldersAndItems;
	
	If ListInputWasUsed <> BecameListInput Then
		If ListInputWasUsed Then
			If TypeOf(DCItem.RightValue) = Type("ValueList")
				AND DCItem.RightValue.Count() > 0 Then
				DCItem.RightValue = DCItem.RightValue[0].Value;
			Else
				DCItem.RightValue = Undefined;
			EndIf;
		Else
			If TypeOf(DCItem.RightValue) = Type("DataCompositionField") Then
				DCItem.RightValue = Undefined;
			Else
				DCItem.RightValue = ReportsClientServer.ValuesByList(DCItem.RightValue);
			EndIf;
		EndIf;
		Update(); // These changes are critical. To apply all links and output features, the output must be completely redrawn.
	EndIf;
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure FiltersChooseValueFromList(TableRow)
	If TableRow.More = Undefined Then
		Return;
	EndIf;
	ValuesForSelection = CommonClientServer.StructureProperty(TableRow.More, "ValuesForSelection");
	If TypeOf(ValuesForSelection) <> Type("ValueList") Or ValuesForSelection.Count() = 0 Then
		Return;
	EndIf;
	Context = New Structure;
	Context.Insert("IDRow", TableRow.GetID());
	Handler = New NotifyDescription("FiltersCompleteSelectingValueFromList", ThisObject, Context);
	ShowChooseFromMenu(Handler, ValuesForSelection, Items.Filters);
EndProcedure

&AtClient
Procedure FiltersCompleteSelectingValueFromList(Result, Context) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
	TableRow = Filters.FindByID(Context.IDRow);
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	DCNode = FieldTablesFindNode(ThisObject, "Filters", TableRow);
	DCItem = DCNode.GetObjectByID(TableRow.DCID);
	If DCItem = Undefined Then
		Return;
	EndIf;
	
	// Record changes in the value.
	If TypeOf(DCItem) = Type("DataCompositionFilterItem") Then
		DCItem.RightValue = Result.Value;
	Else
		DCItem.Value = Result.Value;
	EndIf;
	TableRow.ValuePresentation = Result.Presentation;
	
	// Enable the Usage check box.
	DCItem.Use = True;
	TableRow.Use = True;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		OptionChanged = True;
	EndIf;
EndProcedure

&AtClient
Procedure FiltersSetAccessLevel(AccessLevel)
	TableRow = Items.Filters.CurrentData;
	IDRow = Items.Filters.CurrentRow;
	If TableRow = Undefined Or IDRow = Undefined Then
		Return;
	EndIf;
	FieldTablesChangeAccessLevel("Filters", IDRow, True, Not TableRow.IsParameter, AccessLevel);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client - the option structure.

&AtClient
Procedure ChangeOptionNode(TableRow, PageName, UseOptionForm)
	If TableRow = Undefined Then
		StructureItems = OptionStructure.GetItems();
		If StructureItems.Count() = 0 Then
			Return;
		EndIf;
		TableRow = StructureItems[0];
	EndIf;
	If UseOptionForm = Undefined Then
		UseOptionForm = (TableRow.Type = "Table"
			Or TableRow.Type = "NestedObjectSettings");
	EndIf;
	
	Handler = New NotifyDescription("ChangeOptionNodeCompletion", ThisObject);
	
	CaptionPattern = NStr("en = 'Setting %1 of report ""%2""'; ru = 'Настройка %1 отчета ""%2""';pl = 'Ustawienia %1 raportu ""%2""';es_ES = 'Ajustes %1 del informe ""%2""';es_CO = 'Ajustes %1 del informe ""%2""';tr = '""%2"" raporunun %1 ayarı';it = 'Impostazione %1 del report ""%2""';de = 'Erstellen %1 des Berichts ""%2""'");
	If TableRow.Type = "Chart" Then
		NodePresentation = NStr("en = 'charts'; ru = 'диаграммы';pl = 'wykresy';es_ES = 'diagramas';es_CO = 'diagramas';tr = 'diyagramlar';it = 'piani';de = 'Diagramme'");
	Else
		NodePresentation = NStr("en = 'groupings'; ru = 'группировки';pl = 'grupowania';es_ES = 'agrupaciones';es_CO = 'agrupaciones';tr = 'gruplar';it = 'raggruppamenti';de = 'Gruppierungen'");
	EndIf;
	If ValueIsFilled(TableRow.Title) Then
		NodePresentation = NodePresentation + " """ + TableRow.Title + """";
	ElsIf ValueIsFilled(TableRow.Presentation) Then
		NodePresentation = NodePresentation + " """ + TableRow.Presentation + """";
	EndIf;
	
	DCNode = FieldTablesFindNode(ThisObject, "OptionStructure");
	DCItem = FindDCObject(DCNode, TableRow);
	FullPath = ReportsClientServer.FullPathToItem(Report.SettingsComposer.Settings, DCItem);
	If FullPath = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey",                String(CurrentVariantKey));
	FormParameters.Insert("Variant",                     Report.SettingsComposer.Settings);
	FormParameters.Insert("UserSettings",   Report.SettingsComposer.UserSettings);
	FormParameters.Insert("ReportSettings",             ReportSettings);
	FormParameters.Insert("DescriptionOption",         DescriptionOption);
	FormParameters.Insert("CurrentDCNodeID", TableRow.DCID);
	FormParameters.Insert("CurrentDCNodeType",           TableRow.Type);
	FormParameters.Insert("FullPathToCurrentDCNode",    FullPath);
	FormParameters.Insert("Title", StringFunctionsClientServer.SubstituteParametersToString(CaptionPattern, NodePresentation, DescriptionOption));
	If PageName <> Undefined Then
		FormParameters.Insert("PageName", PageName);
	EndIf;
	
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	
	RunMeasurements = ReportSettings.RunMeasurements AND ValueIsFilled(ReportSettings.MeasurementsKey);
	If RunMeasurements Then
		ModulePerformanceMonitorClient = CommonClient.CommonModule("PerformanceMonitorClient");
		MeasurementID = ModulePerformanceMonitorClient.StartTimeMeasurement(
			False,
			ReportSettings.MeasurementsKey + ".Settings");
		ModulePerformanceMonitorClient.SetMeasurementComment(MeasurementID, ReportSettings.MeasurementsPrefix);
	EndIf;
	
	NameOfFormToOpen = ReportSettings.FullName + ?(UseOptionForm, ".VariantForm", ".SettingsForm");
	OpenForm(NameOfFormToOpen, FormParameters, ThisObject, , , , Handler, Mode);
EndProcedure

&AtClient
Procedure ChangeOptionNodeCompletion(Result, Context) Export
	If Result = Undefined Or Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	FillQuickSettingsClient(Result);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client - field tables (universal entry points).

&AtClient
Procedure FieldTablesChangeAccessLevel(TableName, IDRow, ShowInputModes, ShowCheckBoxesModes, AccessLevel = Undefined)
	Context = New Structure("TableName, IDRow", TableName, IDRow);
	Handler = New NotifyDescription("FieldTablesChangeAccessLevelCompletion", ThisObject, Context);
	
	List = New ValueList;
	If ShowInputModes Then
		List.Add("ShowInReportHeader", NStr("en = 'In report header'; ru = 'В шапке отчета';pl = 'W nagłówku raportu';es_ES = 'En el encabezado del informe';es_CO = 'En el encabezado del informe';tr = 'Rapor başlığında';it = 'Nell''intestazione del report';de = 'In Berichtskopfzeile'"), , PictureLib.QuickAccess);
	EndIf;
	If ShowCheckBoxesModes Then
		List.Add("ShowOnlyCheckBoxInReportHeader", NStr("en = 'Only check box in report title'; ru = 'Только флажок в шапке отчета';pl = 'Tylko pole wyboru w nagłówku raportu';es_ES = 'Solo la casilla de verificación en el título del informe';es_CO = 'Solo la casilla de verificación en el título del informe';tr = 'Sadece rapor başlığında onay kutusu';it = 'Solo casella di controllo nel titolo del report';de = 'Nur Kontrollkästchen im Berichtstitel'"), , PictureLib.QuickAccessWithFlag);
	EndIf;
	If ShowInputModes Then
		List.Add("ShowInReportSettings", NStr("en = 'In report settings'; ru = 'В настройках отчета';pl = 'W ustawieniach raportu';es_ES = 'En las configuraciones del informe';es_CO = 'En las configuraciones del informe';tr = 'Rapor ayarlarında';it = 'Nelle impostazioni del report';de = 'In den Berichteinstellungen'"), , PictureLib.Attribute);
	EndIf;
	If ShowCheckBoxesModes Then
		List.Add("ShowOnlyCheckBoxInReportSettings", NStr("en = 'Only check box in report settings'; ru = 'Только флажок в настройках отчета';pl = 'Tylko pole wyboru w ustawieniach raportu';es_ES = 'Solo la casilla de verificación en las configuraciones del informe';es_CO = 'Solo la casilla de verificación en las configuraciones del informe';tr = 'Sadece rapor başlığında onay kutusu';it = 'Solo casella di controllo in impostazioni dei report';de = 'Nur das Kontrollkästchen in den Berichteinstellungen'"), , PictureLib.NormalAccessWithCheckBox);
	EndIf;
	List.Add("DontShow", NStr("en = 'Do not show'; ru = 'Не показывать';pl = 'Nie pokazuj';es_ES = 'No mostrar';es_CO = 'No mostrar';tr = 'Gösterme';it = 'Non mostrare';de = 'Nicht anzeigen'"), , PictureLib.HiddenReportSettingsItem);
	
	If AccessLevel = Undefined Then
		ShowChooseFromMenu(Handler, List);
	Else
		ListItem = List.FindByValue(AccessLevel);
		ExecuteNotifyProcessing(Handler, ListItem);
	EndIf;
EndProcedure

&AtClient
Procedure FieldTablesChangeAccessLevelCompletion(ListItem, Context) Export
	If TypeOf(ListItem) <> Type("ValueListItem") Then
		Return;
	EndIf;
	AccessLevel = ListItem.Value;
	If AccessLevel = "ShowInReportHeader" Then
		AccessPictureIndex = 2;
	ElsIf AccessLevel = "ShowOnlyCheckBoxInReportHeader" Then
		AccessPictureIndex = 1;
	ElsIf AccessLevel = "ShowInReportSettings" Then
		AccessPictureIndex = 4;
	ElsIf AccessLevel = "ShowOnlyCheckBoxInReportSettings" Then
		AccessPictureIndex = 3;
	Else
		AccessPictureIndex = 5;
	EndIf;
	
	TableRow = ThisObject[Context.TableName].FindByID(Context.IDRow);
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	DCNode = FieldTablesFindNode(ThisObject, Context.TableName, TableRow);
	DCItem = DCNode.GetObjectByID(TableRow.DCID);
	If DCItem = Undefined Then
		Return;
	EndIf;
	
	FieldTablesSetAccessLevel(Context.TableName, TableRow, DCItem, AccessPictureIndex);
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure FieldTablesSetAccessLevel(TableName, TableRow, DCItem, AccessPictureIndex)
	If AccessPictureIndex = Undefined Then
		AccessPictureIndex = TableRow.AccessPictureIndex;
	Else
		TableRow.AccessPictureIndex = AccessPictureIndex;
	EndIf;
	
	If AccessPictureIndex = 1 Or AccessPictureIndex = 2 Then
		DCItem.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess;
	ElsIf AccessPictureIndex = 3 Or AccessPictureIndex = 4 Then
		DCItem.ViewMode = DataCompositionSettingsItemViewMode.Normal;
	Else
		DCItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	EndIf;
	
	If TableName = "Filters" AND Not TableRow.IsParameter Then
		If AccessPictureIndex = 1 Or AccessPictureIndex = 3 Then
			// If UserSettingPresentation is filled in, the Presentation acts as radio buttons and can also be 
			// used for output to a spreadsheet document.
			// 
			DCItem.Presentation = TableRow.Title;
		Else
			DCItem.Presentation = "";
		EndIf;
		If TableRow.TitleOverridden Then
			DCItem.UserSettingPresentation = TableRow.Title;
		EndIf;
	ElsIf TableName = "Appearance" Then
		// Conditional appearance feature: UserSettingPresentation can be cleared after GetSettings().
		If TableRow.TitleOverridden Then
			// If UserSettingPresentation is filled in, the Presentation acts as radio buttons and can also be 
			// used for output to a spreadsheet document.
			// 
			DCItem.Presentation = TableRow.Title;
		Else
			If AccessPictureIndex = 1 Or AccessPictureIndex = 3 Then
				// If UserSettingPresentation is filled in, the Presentation acts as radio buttons and can also be 
				// used for output to a spreadsheet document.
				// 
				DCItem.Presentation = TableRow.Title;
			Else
				DCItem.Presentation = "";
			EndIf;
		EndIf;
	EndIf;
	
	If DCItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible Then
		DCItem.UserSettingID = "";
	ElsIf Not ValueIsFilled(DCItem.UserSettingID) Then
		DCItem.UserSettingID = New UUID;
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client - appearance.

&AtClient
Procedure AppearanceChangeItem(TableName, IDRow, TableRow)
	Context = New Structure("TableName, IDRow", TableName, IDRow);
	Handler = New NotifyDescription("AppearanceChangeItemCompletion", ThisObject, Context);
	
	FormParameters = New Structure;
	FormParameters.Insert("ReportSettings", ReportSettings);
	FormParameters.Insert("SettingsComposer", Report.SettingsComposer);
	FormParameters.Insert("CurrentDCNodeID", CurrentDCNodeID);
	If TableRow = Undefined Then
		FormParameters.Insert("DCID", Undefined);
		FormParameters.Insert("Description", "");
	Else
		FormParameters.Insert("DCID", TableRow.DCID);
		FormParameters.Insert("Description", TableRow.Title);
	EndIf;
	FormParameters.Insert("Title", StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Conditional report appearance item ""%1""'; ru = 'Элемент условного оформления отчета ""%1""';pl = 'Element wyglądu raportu warunkowego ""%1""';es_ES = 'Elemento de diseño condicional del informe ""%1""';es_CO = 'Elemento de diseño condicional del informe ""%1""';tr = '""%1"" raporun koşullu kayıt öğesi';it = 'Elemento della regolarizzazione condizionale del report ""%1""';de = 'Element der bedingten Berichterstattung ""%1""'"), DescriptionOption));
	
	OpenForm("SettingsStorage.ReportsVariantsStorage.Form.ConditionalReportAppearanceItem", FormParameters, ThisObject, , , , Handler);
EndProcedure

&AtClient
Procedure AppearanceChangeItemCompletion(Result, Context) Export
	If Result = Undefined Or Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	IsNew = (Context.IDRow = Undefined);
	
	Table = ThisObject[Context.TableName];
	If IsNew Then
		ResultOfPasting = FieldTablesPaste(Context.TableName, Type("DataCompositionConditionalAppearanceItem"), 0, False);
		TableRow = ResultOfPasting.TableRow;
		DCNode        = ResultOfPasting.DCNode;
		DCItem     = ResultOfPasting.DCItem;
		TableRow.AccessPictureIndex = 4;
	Else
		TableRow = Table.FindByID(Context.IDRow);
		If TableRow = Undefined Then
			Return;
		EndIf;
		
		DCNode = FieldTablesFindNode(ThisObject, Context.TableName, TableRow);
		DCItem = DCNode.GetObjectByID(TableRow.DCID);
		If DCItem = Undefined Then
			Return;
		EndIf;
		
		DCItem.Filter.Items.Clear();
		DCItem.Fields.Items.Clear();
	EndIf;
	
	ReportsClientServer.FillPropertiesRecursively(DCNode, DCItem, Result.DCItem);
	
	TableRow.Use = DCItem.Use;
	TableRow.Title = Result.Description;
	TableRow.TitleOverridden = (TableRow.Title <> TableRow.Presentation);
	
	FieldTablesSetAccessLevel(Context.TableName, TableRow, DCItem, Undefined);
	
	If TableRow.TitleOverridden Then
		DCItem.UserSettingPresentation = TableRow.Title;
	Else
		DCItem.UserSettingPresentation = "";
	EndIf;
	
	DetermineIfModified();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client - field tables (functional part).

&AtClient
Procedure FieldTablesUngroup(TableName)
	TableItem = Items[TableName];
	TableAttribute = ThisObject[TableName];
	SelectedRows = TableItem.SelectedRows;
	SelectedRows = CommonClientServer.CollapseArray(SelectedRows); // For a platform.
	If SelectedRows.Count() <> 1 Then
		ShowMessageBox(, NStr("en = 'Select one group.'; ru = 'Выберите одну группу.';pl = 'Wybierz jedną grupę.';es_ES = 'Seleccionar un grupo.';es_CO = 'Seleccionar un grupo.';tr = 'Bir grubu seçin.';it = 'Scegliete un gruppo.';de = 'Wählen Sie eine Gruppe aus.'"));
		Return;
	EndIf;
	
	TreeGroup = TableAttribute.FindByID(SelectedRows[0]);
	If TreeGroup = Undefined Or Not TreeGroup.IsFolder Then
		ShowMessageBox(, NStr("en = 'Select group.'; ru = 'Выберите группу.';pl = 'Wybierz grupę.';es_ES = 'Seleccionar un grupo.';es_CO = 'Seleccionar un grupo.';tr = 'Grubu seçin.';it = 'Seleziona gruppo.';de = 'Gruppe auswählen.'"));
		Return;
	EndIf;
	
	DCNode = FieldTablesFindNode(ThisObject, TableName, Undefined);
	DCGroup = DCNode.GetObjectByID(TreeGroup.DCID);
	
	Parent = TreeGroup.GetParent();
	If Parent = Undefined Then
		Parent = TableAttribute;
	EndIf;
	NewTreeRowsCollection = Parent.GetItems();
	
	DCParent = DCGroup.Parent;
	If DCParent = Undefined Then
		DCParent = DCNode;
	EndIf;
	NewCollectionOfDCItems = DCParent.Items;
	
	Index = NewTreeRowsCollection.IndexOf(TreeGroup);
	DCIndex = NewCollectionOfDCItems.IndexOf(DCGroup);
	
	CurrentRow = Undefined;
	SelectedRows = New Array;
	
	ParentRows = TreeGroup.GetItems();
	DCParentRows = DCGroup.Items;
	For Each OldTreeRow In ParentRows Do
		OldDCItem = DCNode.GetObjectByID(OldTreeRow.DCID);
		MovedRows = FieldTablesCopyRecursively(DCNode, OldTreeRow, NewTreeRowsCollection, OldDCItem, NewCollectionOfDCItems, Index, DCIndex);
		Index = Index + 1;
		DCIndex = DCIndex + 1;
		If CurrentRow = Undefined Then
			CurrentRow = MovedRows.TreeRow;
		EndIf;
		SelectedRows.Add(MovedRows.TreeRow);
	EndDo;
	
	NewTreeRowsCollection.Delete(TreeGroup);
	NewCollectionOfDCItems.Delete(DCGroup);
	
	If CurrentRow <> Undefined Then
		TableItem.CurrentRow = CurrentRow.GetID();
	EndIf;
	TableItem.SelectedRows.Clear();
	For Each TreeRow In SelectedRows Do
		TableItem.SelectedRows.Add(TreeRow.GetID());
	EndDo;
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure FieldTablesBeforeDelete(TableName, Cancel)
	Cancel = True;
	
	Context = NewContext(TableName, "Delete");
	DefineSelectedRows(Context);
	If ValueIsFilled(Context.CancelReason) Then
		ShowMessageBox(, Context.CancelReason);
		Return;
	EndIf;
	
	DeleteRows(Context);
	UpdateForm(Context);
EndProcedure

&AtClient
Procedure FieldTablesChange(TableName, IDRow, TableRow)
	Context = New Structure("TableName, IDRow", TableName, IDRow);
	Handler = New NotifyDescription("FieldTablesChangeCompletion", ThisObject, Context);
	
	Table = ThisObject[TableName];
	TableRow = Table.FindByID(IDRow);
	DCNode = FieldTablesFindNode(ThisObject, TableName, TableRow);
	DCItem = DCNode.GetObjectByID(TableRow.DCID);
	
	FieldsTablesShowFieldSelection(TableName, Handler, ?(TableName = "Filters", DCItem.LeftValue, DCItem.Field));
EndProcedure

&AtClient
Procedure FieldTablesChangeCompletion(AvailableDCField, Context) Export
	If AvailableDCField = Undefined Then
		Return;
	EndIf;
	
	TableRow = ThisObject[Context.TableName].FindByID(Context.IDRow);
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	DCNode = FieldTablesFindNode(ThisObject, Context.TableName, TableRow);
	DCItem = DCNode.GetObjectByID(TableRow.DCID);
	If DCItem = Undefined Then
		Return;
	EndIf;
	
	TableRow.Presentation = AvailableDCField.Title;
	If Context.TableName = "Filters" Then
		DCItem.LeftValue = AvailableDCField.Field;
		If AvailableDCField.AvailableCompareTypes <> Undefined
			AND AvailableDCField.AvailableCompareTypes.FindByValue(DCItem.ComparisonType) = Undefined
			AND AvailableDCField.AvailableCompareTypes.Count() > 0 Then
			DCItem.ComparisonType = AvailableDCField.AvailableCompareTypes[0].Value;
		EndIf;
		ReportsClientServer.CastValueToType(DCItem.RightValue, AvailableDCField.ValueType);
		Update(); // These changes are critical. To apply all links and output features, the output must be completely redrawn.
	Else
		DCItem.Field = AvailableDCField.Field;
	EndIf;
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure FieldTablesChangeUsage(TableName)
	Table = Items[TableName];
	TableRow = Table.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	If CommonClientServer.StructureProperty(TableRow, "OutputFlag") = False Then
		TableRow.Use = True;
		Return;
	EndIf;
	
	DCNode = FieldTablesFindNode(ThisObject, TableName, TableRow);
	DCItem = DCNode.GetObjectByID(TableRow.DCID);
	If DCItem = Undefined Then
		Return;
	EndIf;
	
	DCItem.Use = TableRow.Use;
	
	AfterChangeUsageCheckBox(TableName, TableRow, DCItem);
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure AfterChangeUsageCheckBox(TableName, TableRow, DCItem)
	If TableName = "GroupComposition" Then
		LinkedTableName = "SelectedFields";
	ElsIf TableName = "SelectedFields" Then
		LinkedTableName = "GroupComposition";
	Else
		LinkedTableName = Undefined;
	EndIf;
	
	If LinkedTableName <> Undefined AND ValueIsFilled(TableRow.DCField) Then
		Condition = New Structure("DCField", TableRow.DCField);
		SetUsageCheckBoxByCondition(LinkedTableName, Condition, TableRow.Use);
	EndIf;
EndProcedure

&AtClient
Procedure SetUsageCheckBoxByCondition(TableName, Condition, Usage)
	Table = ThisObject[TableName];
	FoundItems = ReportsClientServer.FindTableRows(Table, Condition);
	DCNode = Undefined;
	For Each TableRow In FoundItems Do
		If TableRow.Use = Usage Then
			Continue;
		EndIf;
		If DCNode = Undefined Then
			DCNode = FieldTablesFindNode(ThisObject, TableName, TableRow);
		EndIf;
		DCItem = DCNode.GetObjectByID(TableRow.DCID);
		If DCItem = Undefined Then
			Continue;
		EndIf;
		TableRow.Use = Usage;
		DCItem.Use     = Usage;
	EndDo;
EndProcedure

&AtClient
Procedure SetUsageCheckBoxesInWholeTree(TableName, Usage, RowsArray = Undefined, DCNode = Undefined)
	DetermineNodeOnTheFly = False;
	If RowsArray = Undefined Then
		RowsArray = ThisObject[TableName].GetItems();
		DetermineNodeOnTheFly = (TableName = "Filters");
	EndIf;
	
	For Each TreeRow In RowsArray Do
		If DCNode = Undefined Or DetermineNodeOnTheFly Then
			DCNode = FieldTablesFindNode(ThisObject, TableName, TreeRow);
		EndIf;
		
		If CommonClientServer.StructureProperty(TreeRow, "OutputFlag") <> False
			AND CommonClientServer.StructureProperty(TreeRow, "IsSection") <> True Then
			DCItem = DCNode.GetObjectByID(TreeRow.DCID);
			If DCItem <> Undefined AND TypeOf(DCItem) <> Type("DataCompositionTableStructureItemCollection")
				AND TypeOf(DCItem) <> Type("DataCompositionChartStructureItemCollection") Then
					TreeRow.Use = Usage;
					DCItem.Use     = Usage;
					AfterChangeUsageCheckBox(TableName, TreeRow, DCItem);
			EndIf;
		EndIf;
		
		SetUsageCheckBoxesInWholeTree(TableName, Usage, TreeRow.GetItems(), DCNode);
	EndDo;
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure FieldTablesChangeValue(TableName)
	TableRow = Items[TableName].CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	DCNode = FieldTablesFindNode(ThisObject, TableName, TableRow);
	DCItem = DCNode.GetObjectByID(TableRow.DCID);
	If DCItem = Undefined Then
		Return;
	EndIf;
	
	SetValue(TableRow, DCNode, DCItem, TableRow.Value);
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		OptionChanged = True;
	EndIf;
EndProcedure

&AtClient
Procedure FieldTablesChangeGroupType(TableName)
	TableRow = Items[TableName].CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	DCNode = FieldTablesFindNode(ThisObject, TableName, TableRow);
	DCItem = DCNode.GetObjectByID(TableRow.DCID);
	If DCItem = Undefined Then
		Return;
	EndIf;
	
	If TableRow.ShowAdditionType Then
		DCItem.AdditionType = TableRow.AdditionType;
	Else
		DCItem.GroupType = TableRow.GroupType;
	EndIf;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		OptionChanged = True;
	EndIf;
EndProcedure

&AtClient
Procedure FieldTablesChangeGroup(TableName, IDRow, TableRow)
	DCNode = FieldTablesFindNode(ThisObject, TableName, TableRow);
	DCItem = DCNode.GetObjectByID(TableRow.DCID);
	
	Context = New Structure("TableName, IDRow", TableName, IDRow);
	Handler = New NotifyDescription("FieldTablesChangeGroupCompletion", ThisObject, Context);
	
	If TableName = "Filters" Then
		List = New ValueList;
		List.Add(DataCompositionFilterItemsGroupType.AndGroup);
		List.Add(DataCompositionFilterItemsGroupType.OrGroup);
		List.Add(DataCompositionFilterItemsGroupType.NotGroup);
		ShowChooseFromMenu(Handler, List);
	Else
		FormParameters = New Structure;
		FormParameters.Insert("GroupTitle", DCItem.Title);
		FormParameters.Insert("Placement", DCItem.Placement);
		
		Block = FormWindowOpeningMode.LockOwnerWindow;
		
		OpenForm("SettingsStorage.ReportsVariantsStorage.Form.SelectedFieldsGroup", FormParameters, ThisObject, True, , , Handler, Block);
	EndIf;
EndProcedure

&AtClient
Procedure FieldTablesChangeGroupCompletion(Result, Context) Export
	If Result = Undefined Or Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	TableRow = ThisObject[Context.TableName].FindByID(Context.IDRow);
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	DCNode = FieldTablesFindNode(ThisObject, Context.TableName, TableRow);
	DCItem = DCNode.GetObjectByID(TableRow.DCID);
	If DCItem = Undefined Then
		Return;
	EndIf;
	
	If Context.TableName = "Filters" Then
		DCItem.GroupType = Result.Value;
		TableRow.Presentation = String(Result.Value);
		If Not TableRow.TitleOverridden Then
			TableRow.Title = TableRow.Presentation;
		EndIf;
	Else
		DCItem.Title = Result.GroupTitle;
		DCItem.Placement = Result.Placement;
		TableRow.Presentation = DCItem.Title;
		If DCItem.Placement <> DataCompositionFieldPlacement.Auto Then
			TableRow.Presentation = TableRow.Presentation + " (" + String(DCItem.Placement) + ")";
		EndIf;
	EndIf;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		OptionChanged = True;
	EndIf;
EndProcedure

&AtClient
Function FieldTablesPaste(TableName, ItemType, CurrentRow, InsideRow)
	If CurrentRow = Undefined Then
		Return Undefined;
	EndIf;
	
	TableItem  = Items[TableName];
	TableAttribute = ThisObject[TableName];
	DCNode = FieldTablesFindNode(ThisObject, TableName);
	
	If CurrentRow = 0 Then
		CurrentRow = TableItem.CurrentData;
	EndIf;
	
	If CurrentRow = Undefined Then
		
		WhereToPaste = TableAttribute.GetItems();
		Index = Undefined;
		DCItem = Undefined;
		WhereToPasteDC = GetDCItems(DCNode, CurrentRow);
		DCIndex = Undefined;
		
	Else
		
		DCItem = FindDCObject(DCNode, CurrentRow);
		If InsideRow = Undefined Then
			InsideRow = CommonClientServer.StructureProperty(CurrentRow, "IsFolder", False);
		EndIf;
		
		If DCItem = Undefined Then
			InsideRow = True;
		EndIf;
		
		If InsideRow Then
			WhereToPaste = CurrentRow.GetItems();
			Index = Undefined;
			WhereToPasteDC = GetDCItems(DCNode, DCItem);
			DCIndex = Undefined
		Else // Paste on the same level as the row.
			ParentRow = CurrentRow.GetParent();
			If ParentRow = Undefined Then
				WhereToPaste = TableAttribute.GetItems();
			Else
				WhereToPaste = ParentRow.GetItems();
			EndIf;
			Index = WhereToPaste.IndexOf(CurrentRow) + 1;
			DCParent = FindDCObject(DCNode, ParentRow);
			WhereToPasteDC = GetDCItems(DCNode, DCParent);
			DCIndex = WhereToPasteDC.IndexOf(DCItem) + 1;
		EndIf;
		
	EndIf;
	
	If Index = Undefined Then
		NewRow = WhereToPaste.Add();
	Else
		NewRow = WhereToPaste.Insert(Index);
	EndIf;
	
	If ReportsClientServer.SpecifyItemTypeOnAddToCollection(TypeOf(WhereToPasteDC)) Then
		If DCIndex = Undefined Then
			NewDCItem = WhereToPasteDC.Add(ItemType);
		Else
			NewDCItem = WhereToPasteDC.Insert(DCIndex, ItemType);
		EndIf;
	Else
		If DCIndex = Undefined Then
			NewDCItem = WhereToPasteDC.Add();
		Else
			NewDCItem = WhereToPasteDC.Insert(DCIndex);
		EndIf;
	EndIf;
	TableItem.CurrentRow = NewRow.GetID();
	NewRow.DCID = DCNode.GetIDByObject(NewDCItem);
	
	Result = New Structure("TableRow, DCNode, DCItem");
	Result.TableRow = NewRow;
	Result.DCNode = DCNode;
	Result.DCItem = NewDCItem;
	Return Result;
EndFunction

&AtClient
Function FieldTablesMove(Val TableName, Val TableRow, Val NewParent,
	Val PasteBeforeWhat = Undefined, Val Index = Undefined, Val DCIndex = Undefined)
	Result = New Structure("TableRow, DCItem, IndexOf, DCIndex");
	
	TableItem  = Items[TableName];
	TableAttribute = ThisObject[TableName];
	
	AddToEnd = (NewParent = Undefined);
	WhereToPaste = GetItems(TableAttribute, NewParent);
	If PasteBeforeWhat = Undefined AND TableName <> "OptionStructure" Then
		IsSection = CommonClientServer.StructureProperty(NewParent, "IsSection");
		IsFolder = CommonClientServer.StructureProperty(NewParent, "IsFolder");
		If IsSection <> True AND IsFolder <> True Then // To the same level as the parent.
			PasteBeforeWhat = NewParent;
			NewParent = GetParent(TableName, NewParent);
			WhereToPaste = GetItems(TableAttribute, NewParent);
		EndIf;
	EndIf;
	
	DCNode = FieldTablesFindNode(ThisObject, TableName);
	DCItem          = FindDCObject(DCNode, TableRow);
	NewDCParent    = FindDCObject(DCNode, NewParent);
	WhereToPasteDC     = GetDCItems(DCNode, NewDCParent);
	PasteDCBeforeWhat = FindDCObject(DCNode, PasteBeforeWhat);
	
	PreviousParent    = GetParent(TableName, TableRow);
	MoveFromWhere = GetItems(TableAttribute, PreviousParent);
	
	OldDCParent    = FindDCObject(DCNode, PreviousParent);
	MoveDCFromWhere = GetDCItems(DCNode, OldDCParent);
	
	If DCItem = PasteDCBeforeWhat Then
		Result.DCItem     = DCItem;
		Result.TableRow = TableRow;
	Else
		If Index = Undefined Or DCIndex = Undefined Then
			If PasteDCBeforeWhat = Undefined Then
				If AddToEnd Then
					Index   = WhereToPaste.Count();
					DCIndex = WhereToPasteDC.Count();
				Else
					Index   = 0;
					DCIndex = 0;
				EndIf;
			Else
				Index   = WhereToPaste.IndexOf(PasteBeforeWhat);
				DCIndex = WhereToPasteDC.IndexOf(PasteDCBeforeWhat);
				If PreviousParent = NewParent Then
					OldIndex = MoveFromWhere.IndexOf(TableRow);
					If OldIndex <= Index Then
						Index   = Index + 1;
						DCIndex = DCIndex + 1;
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
		SearchDCItems = New Map;
		Result.DCItem = ReportsClientServer.CopyRecursive(DCNode, DCItem, WhereToPasteDC, DCIndex, SearchDCItems);
		
		SearchTableRows = New Map;
		Result.TableRow = ReportsClientServer.CopyRecursive(Undefined, TableRow, WhereToPaste, Index, SearchTableRows);
		
		For Each KeyAndValue In SearchTableRows Do
			OldRow = KeyAndValue.Key;
			NewRow = KeyAndValue.Value;
			NewRow.DCID = SearchDCItems.Get(OldRow.DCID);
		EndDo;
		
		MoveFromWhere.Delete(TableRow);
		MoveDCFromWhere.Delete(DCItem);
	EndIf;
	
	Result.IndexOf   = WhereToPaste.IndexOf(Result.TableRow);
	Result.DCIndex = WhereToPasteDC.IndexOf(Result.DCItem);
	
	Return Result;
EndFunction

&AtClient
Procedure FieldTablesRemove(Val TableName, Val TableRowOrRowArray, Val AutoFieldsUsage)
	Table = ThisObject[TableName];
	DCNode = FieldTablesFindNode(ThisObject, TableName);
	If TypeOf(TableRowOrRowArray) = Type("FormDataTreeItem") Then
		FieldTablesRemoveMechanics(TableName, Table, DCNode, TableRowOrRowArray, AutoFieldsUsage);
	Else
		Count = TableRowOrRowArray.Count();
		For Number = 1 To Count Do
			ReverseIndex = Count - Number;
			TableRow = TableRowOrRowArray[ReverseIndex];
			FieldTablesRemoveMechanics(TableName, Table, DCNode, TableRow, AutoFieldsUsage);
		EndDo;
	EndIf;
EndProcedure

&AtClient
Procedure FieldTablesRemoveMechanics(TableName, Table, DCNode, TableRow, AutoFieldsUsage)
	DCItem = FindDCObject(DCNode, TableRow);
	
	LinkedTableName = Undefined;
	If TableName = "SelectedFields" Then
		If TableRow.IsSection Then
			Return;
		ElsIf TableRow.SettingType = "AutoSelectedField" Then
			If AutoFieldsUsage <> Undefined AND DCItem.Use <> AutoFieldsUsage Then
				TableRow.Use = AutoFieldsUsage;
				DCItem.Use     = AutoFieldsUsage;
			EndIf;
			Return;
		EndIf;
		LinkedTableName = "GroupComposition";
	ElsIf TableName = "Sort" Then
		If TableRow.IsSection Then
			Return;
		ElsIf TableRow.SettingType = "AutoOrderItem" Then
			If AutoFieldsUsage <> Undefined AND DCItem.Use <> AutoFieldsUsage  Then
				TableRow.Use = AutoFieldsUsage;
				DCItem.Use     = AutoFieldsUsage;
			EndIf;
			Return;
		EndIf;
	ElsIf TableName = "GroupComposition" Then
		If TableRow.SettingType = "AutoGroupField" Then
			If AutoFieldsUsage <> Undefined AND DCItem.Use <> AutoFieldsUsage  Then
				TableRow.Use = AutoFieldsUsage;
				DCItem.Use     = AutoFieldsUsage;
			EndIf;
			Return;
		EndIf;
		LinkedTableName = "SelectedFields";
	EndIf;
	If LinkedTableName <> Undefined AND ValueIsFilled(TableRow.DCField) Then
		Condition = New Structure("DCField", TableRow.DCField);
		SetUsageCheckBoxByCondition(LinkedTableName, Condition, False);
	EndIf;
	
	Parent = GetParent(TableName, TableRow);
	ParentRows = GetItems(Table, Parent);
	
	DCParent = FindDCObject(DCNode, Parent);
	DCParentRows = GetDCItems(DCNode, DCParent);
	
	ParentRows.Delete(TableRow);
	DCParentRows.Delete(DCItem);
	
EndProcedure

&AtClientAtServerNoContext
Function FindDCObject(Val DCNode, Val TableRow)
	If TableRow = Undefined Or TypeOf(TableRow.DCID) <> Type("DataCompositionID") Then
		Return Undefined;
	Else
		Return DCNode.GetObjectByID(TableRow.DCID);
	EndIf;
EndFunction

&AtClientAtServerNoContext
Function GetDCItems(Val DCNode, Val DCObject)
	If DCObject = Undefined Then
		DCObject = DCNode;
	EndIf;
	ObjectType = TypeOf(DCObject);
	If ObjectType = Type("DataCompositionSettings")
		Or ObjectType = Type("DataCompositionGroup")
		Or ObjectType = Type("DataCompositionTableGroup")
		Or ObjectType = Type("DataCompositionChartGroup") Then
		Return DCObject.Structure;
	ElsIf ObjectType = Type("DataCompositionTableStructureItemCollection")
		Or ObjectType = Type("DataCompositionChartStructureItemCollection") Then
		Return DCObject;
	Else
		Return DCObject.Items;
	EndIf;
EndFunction

&AtClientAtServerNoContext
Function GetItems(Val FormTree, Val TreeRow)
	If TreeRow = Undefined Then
		TreeRow = FormTree;
	EndIf;
	Return TreeRow.GetItems();
EndFunction

&AtClient
Function GetParent(Val TableName, Val TreeRow)
	If TreeRow = Undefined Then
		ParentLevelRow = Undefined;
	Else
		ParentLevelRow = TreeRow.GetParent();
	EndIf;
	
	If ParentLevelRow = Undefined Then
		ParentLevelRow = DefaultRootRow(TableName);
	EndIf;
	
	Return ParentLevelRow;
EndFunction

&AtClient
Function DefaultRootRow(Val TableName)
	
	If TableName = "SelectedFields" Then
		Return SelectedFields.GetItems()[0];
		
	ElsIf TableName = "Sort" Then
		Return Sort.GetItems()[0];
		
	ElsIf TableName = "OptionStructure" Then
		Return OptionStructure.GetItems()[0];
		
	ElsIf TableName = "Filters" Then
		If OptionNodeChangeMode Then
			Return Filters.GetItems()[0];
		Else
			Return Filters.GetItems()[1];
		EndIf;
		
	Else
		Return Undefined;
	EndIf;
	
EndFunction

&AtClient
Function FindByID(TableAttribute, RowID)
	If RowID = Undefined Then
		TableRow = Undefined;
	Else
		TableRow = TableAttribute.FindByID(RowID);
	EndIf;
	Return TableRow;
EndFunction

&AtClient
Procedure FieldTablesChangeSortDirection(TableName, TableRow, Direction)
	If TableRow = Undefined Then
		TableRow = Items[TableName].CurrentData;
		If TableRow = Undefined Then
			Return;
		EndIf;
	EndIf;
	
	DCNode = FieldTablesFindNode(ThisObject, TableName, TableRow);
	DCItem = DCNode.GetObjectByID(TableRow.DCID);
	If DCItem = Undefined Then
		Return;
	EndIf;
	
	// Fill in optional parameters.
	If Direction = Undefined Then
		If DCItem.OrderType = DataCompositionSortDirection.Asc Then
			Direction = DataCompositionSortDirection.Desc;
		Else
			Direction = DataCompositionSortDirection.Asc;
		EndIf;
	EndIf;
	
	// Change sort direction.
	DCItem.OrderType = Direction;
	TableRow.Direction = Direction;
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure FieldsTablesShowFieldSelection(TableName, Handler, DCField = Undefined, DCNodeID = Undefined)
	FormParameters = New Structure;
	FormParameters.Insert("ReportSettings", ReportSettings);
	FormParameters.Insert("SettingsComposer", Report.SettingsComposer);
	FormParameters.Insert("Mode", TableName);
	FormParameters.Insert("DCField", DCField);
	FormParameters.Insert("CurrentDCNodeID", ?(DCNodeID = Undefined, CurrentDCNodeID, DCNodeID));
	
	Block = FormWindowOpeningMode.LockOwnerWindow;
	
	OpenForm("SettingsStorage.ReportsVariantsStorage.Form.SelectReportField", FormParameters, ThisObject, True, , , Handler, Block);
EndProcedure

&AtClient
Function FieldTablesCopyRecursively(DCNode, WhatToCopy, WhereToPaste, WhatToCopyDC, WhereToPasteDC, Index = Undefined, DCIndex = Undefined)
	Result = New Structure("TreeRow, DCRow");
	
	SearchDCItems = New Map;
	Result.DCRow = ReportsClientServer.CopyRecursive(DCNode, WhatToCopyDC, WhereToPasteDC, DCIndex, SearchDCItems);
	
	SearchTableRows = New Map;
	Result.TreeRow = ReportsClientServer.CopyRecursive(Undefined, WhatToCopy, WhereToPaste, Index, SearchTableRows);
	
	For Each KeyAndValue In SearchTableRows Do
		OldRow = KeyAndValue.Key;
		NewRow = KeyAndValue.Value;
		NewRow.DCID = SearchDCItems.Get(OldRow.DCID);
	EndDo;
	
	Return Result;
EndFunction

&AtClient
Procedure OptionStructureUpdateItemTitleInComposer(TableRow)
	DCNode = FieldTablesFindNode(ThisObject, "OptionStructure", TableRow);
	DCItem = DCNode.GetObjectByID(TableRow.DCID);
	If DCItem = Undefined Then
		Return;
	EndIf;
	If TypeOf(DCItem) = Type("DataCompositionNestedObjectSettings") Then
		DCItem = DCItem.Settings;
	EndIf;
	
	TitleUsage = ValueIsFilled(TableRow.Title);
	
	DCParameterValue = DCItem.OutputParameters.FindParameterValue(New DataCompositionParameter("OutputTitle"));
	If DCParameterValue <> Undefined Then
		DCParameterValue.Use = True;
		If TitleUsage Then
			DCParameterValue.Value = DataCompositionTextOutputType.Output;
		Else
			DCParameterValue.Value = DataCompositionTextOutputType.DontOutput;
		EndIf;
	EndIf;
	
	DCParameterValue = DCItem.OutputParameters.FindParameterValue(New DataCompositionParameter("Title"));
	If DCParameterValue <> Undefined Then
		DCParameterValue.Use = True;
		DCParameterValue.Value = TableRow.Title;
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client or server

&AtClientAtServerNoContext
Function IsFolder(ItemType)
	If ItemType = Type("DataCompositionSelectedFieldGroup")
		Or ItemType = Type("DataCompositionFilterItemGroup")
		Or ItemType = Type("DataCompositionGroup")
		Or ItemType = Type("DataCompositionNestedObjectSettings")
		Or ItemType = Type("DataCompositionTableStructureItemCollection")
		Or ItemType = Type("DataCompositionChartStructureItemCollection") Then
		Return True;
	EndIf;
	Return False;
EndFunction

&AtClientAtServerNoContext
Function TypesDetailsRemovePrimitiveOnes(SourceTypesDetails)
	RemovedTypes = New Array;
	If SourceTypesDetails.ContainsType(Type("String")) Then
		RemovedTypes.Add(Type("String"));
	EndIf;
	If SourceTypesDetails.ContainsType(Type("Date")) Then
		RemovedTypes.Add(Type("Date"));
	EndIf;
	If SourceTypesDetails.ContainsType(Type("Number")) Then
		RemovedTypes.Add(Type("Number"));
	EndIf;
	If RemovedTypes.Count() = 0 Then
		Return SourceTypesDetails;
	EndIf;
	Return New TypeDescription(SourceTypesDetails, , RemovedTypes);
EndFunction

&AtClientAtServerNoContext
Function FieldTablesFindNode(ThisObject, TableName, TableRow = Undefined, DCNodeID = Undefined)
	If ThisObject.ExtendedMode = 1 Then
		If DCNodeID = Undefined Then
			DCNodeID = ThisObject.CurrentDCNodeID;
		EndIf;
		If DCNodeID = Undefined Then
			RootNode = ThisObject.Report.SettingsComposer.Settings;
		Else
			RootNode = ThisObject.Report.SettingsComposer.Settings.GetObjectByID(DCNodeID);
			If TypeOf(RootNode) = Type("DataCompositionNestedObjectSettings") Then
				RootNode = RootNode.Settings;
			EndIf;
		EndIf;
		If TableName = "Sort" Then
			Return RootNode.Order;
		ElsIf TableName = "SelectedFields" Then
			Return RootNode.Selection;
		ElsIf TableName = "Filters" Then
			If TableRow = Undefined Or Not TableRow.IsParameter Then
				Return RootNode.Filter;
			Else
				Return RootNode.DataParameters;
			EndIf;
		ElsIf TableName = "GroupComposition" Then
			Return RootNode.GroupFields;
		ElsIf TableName = "Appearance" Then
			Return RootNode.ConditionalAppearance;
		ElsIf TableName = "OptionStructure" Then
			Return RootNode;
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Changing nodes of the ""%1"" table is not supported.'; ru = 'Изменение узлов таблицы ""%1"" не поддерживается.';pl = 'Zmiana węzłów w tabeli ""%1"" nie jest możliwa.';es_ES = 'Cambio de los nodos de la tabla ""%1"" no se admite.';es_CO = 'Cambio de los nodos de la tabla ""%1"" no se admite.';tr = '""%1"" tablo ünitelerinin değiştirilmesi desteklenmiyor.';it = 'I nodi di modifica della tabella ""%1"" non sono supportati.';de = 'Das Ändern von Knoten der Tabelle ""%1"" wird nicht unterstützt.'"), TableName);
		EndIf;
	Else
		If TableName = "OptionStructure" Then
			Return ThisObject.Report.SettingsComposer.UserSettings;
		EndIf;
		DCID = ThisObject.QuickSearchForUserSettings.Get(TableName);
		If DCID = Undefined Then
			Return Undefined;
		Else
			Return ThisObject.Report.SettingsComposer.UserSettings.GetObjectByID(DCID);
		EndIf;
	EndIf;
	
EndFunction

&AtClientAtServerNoContext
Function ArraySort(SourceArray, SortDirection = Undefined)
	List = New ValueList;
	List.LoadValues(SourceArray);
	List.SortByValue(SortDirection);
	Return List.UnloadValues();
EndFunction

&AtClientAtServerNoContext
Function FindOptionSetting(ThisObject, ItemID)
	SearchOptionSetting = ThisObject.QuickSearchForOptionSettings.Get(ItemID);
	If SearchOptionSetting = Undefined Then
		Return Undefined;
	EndIf;
	RootDCNode = ThisObject.Report.SettingsComposer.Settings.GetObjectByID(SearchOptionSetting.DCNodeID);
	Result = New Structure("DCNode, DCItem");
	Result.DCNode = RootDCNode[SearchOptionSetting.CollectionName];
	Result.DCItem = Result.DCNode.GetObjectByID(SearchOptionSetting.DCItemID);
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server call

&AtServer
Function QuickSettingsFill(Val ClientParameters)
	// Paste default values for required keys of filling parameters.
	FillingParameters = QuickSettingsFillParameters(ClientParameters);
	
	// Call an overridable module.
	If ReportSettings.Events.BeforeFillQuickSettingsBar Then
		ReportObject = ReportsServer.ReportObject(FillingParameters.ReportObjectOrFullName);
		ReportObject.BeforeFillQuickSettingsBar(ThisObject, FillingParameters);
	EndIf;
	
	// Save the state before changing started.
	QuickSettingsStoreState(FillingParameters);
	
	// Record new option settings and user settings in a composer.
	QuickSettingsImportSettingsToComposer(FillingParameters);
	If FillingParameters.Abort Then
		Return FillingParameters.Result;
	EndIf;
	
	// Get information from the DC.
	OutputConditions = New Structure;
	OutputConditions.Insert("UserSettingsOnly", ExtendedMode = 0);
	OutputConditions.Insert("QuickOnly",          False);
	OutputConditions.Insert("CurrentDCNodeID", CurrentDCNodeID);
	Information = ReportsServer.AdvancedInformationOnSettings(
		Report.SettingsComposer,
		ReportSettings,
		FillingParameters.ReportObjectOrFullName,
		OutputConditions);
	
	// Remove items of old settings.
	QuickSettingsRemoveOldItemsAndCommands(FillingParameters);
	
	// Add items of relevant settings and load values.
	QuickSettingsCreateControlItemAndImportValues(FillingParameters, Information);
	
	// Add items of relevant settings and load values.
	AdvancedSettingsImportValues(FillingParameters, Information);
	
	// Links.
	RegisterLinksThatCanBeDisabled(Information);
	
	// Save the state before changing started.
	QuickSettingsRestoreState(FillingParameters);
	
	// Title and properties of items.
	UpdateVisibilityAvailability(FillingParameters.EventName);
	
	// Call an overridable module.
	If ReportSettings.Events.AfterQuickSettingsBarFilled Then
		ReportObject = ReportsServer.ReportObject(FillingParameters.ReportObjectOrFullName);
		ReportObject.AfterQuickSettingsBarFilled(ThisObject, FillingParameters);
	EndIf;
	
	SettingsFillingResult = FillingParameters.Result;
	
	ReportsServer.ClearAdvancedInformationOnSettings(Information);
	FillingParameters.Clear();
EndFunction

&AtServer
Procedure UpdateVisibilityAvailability(EventName = "")
	If EventName = "OnCreateAtServer" Then
		If OptionNodeChangeMode Then
			Items.ExtendedMode.Visible = False;
			Items.CloseAndGenerate.Title = NStr("en = 'Finish editing'; ru = 'Завершить редактирование';pl = 'Zakończ edycję';es_ES = 'Terminar de editar';es_CO = 'Terminar de editar';tr = 'Düzenlemeyi bitir';it = 'Ultimare modifica';de = 'Bearbeitung abschließen'");
			Items.Close.Title = NStr("en = 'Cancel'; ru = 'Отмена';pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal';it = 'Annulla';de = 'Abbrechen'");
		EndIf;
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	 
	// Filters.
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersTitle.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.TitleOverridden");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	//
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersUsage.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.OutputFlag");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);
	
	//
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersCondition.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersValue.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersValuePresentation.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersAccessPictureIndex.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersTitle.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsSection");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("ReadOnly", True);
	
	//
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersCondition.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersValue.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersValuePresentation.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsFolder");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("ReadOnly", True);
	
	//
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersValuePresentation.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.FixedSelectionList");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);
	
	//
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersValue.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.FixedSelectionList");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);
	
	// Selected fields.
	
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SelectedFieldsUsage.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("SelectedFields.IsSection");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);
	
	// Sorting.
	
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SortingUsage.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SortDirection.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Sort.IsSection");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);
	
	//
	
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SortDirection.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Sort.SettingType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = "AutoOrderItem";
	
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);
	
	// Group composition.
	
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.GroupCompositionGroupType.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("GroupComposition.ShowAdditionType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);
	
	//
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.GroupCompositionAdditionType.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("GroupComposition.ShowAdditionType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);
	
	// Structure.
	
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OptionStructurePresentation.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("OptionStructure.IsFolder");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Font", New Font(, , True));
	
	//
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OptionStructurePresentation.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("OptionStructure.Highlight");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Font", New Font(, , True));
	
	//
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OptionStructureUsage.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("OptionStructure.AvailableFlag");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);
	
EndProcedure

&AtServer
Function QuickSettingsFillParameters(ClientParameters)
	FillingParameters = New Structure;
	CommonClientServer.SupplementStructure(FillingParameters, ClientParameters, True);
	If Not FillingParameters.Property("EventName") Then
		FillingParameters.Insert("EventName", "");
	EndIf;
	If Not FillingParameters.Property("VariantModified") Then
		FillingParameters.Insert("VariantModified", False);
	EndIf;
	If Not FillingParameters.Property("UserSettingsModified") Then
		FillingParameters.Insert("UserSettingsModified", False);
	EndIf;
	If Not FillingParameters.Property("Result") Then
		FillingParameters.Insert("Result", New Structure);
		FillingParameters.Result.Insert("ExpandTreeNodes", New Array);
	EndIf;
	FillingParameters.Insert("Abort", False);
	FillingParameters.Insert("ReportObjectOrFullName", ReportSettings.FullName);
	If ReportSettings.Events.BeforeFillQuickSettingsBar
		Or ReportSettings.Events.AfterQuickSettingsBarFilled
		Or ReportSettings.Events.BeforeImportSettingsToComposer Then
		FillingParameters.ReportObjectOrFullName = FormAttributeToValue("Report");
	EndIf;
	
	Return FillingParameters;
EndFunction

&AtServer
Procedure QuickSettingsStoreState(FillingParameters)
	If FillingParameters.EventName = "OnCreateAtServer" Then
		Return; // No need to restore anything.
	EndIf;
	
	SelectedRows = New Structure;
	FillingParameters.Insert("SelectedRows", SelectedRows);
	
	TablesNames = "Filters, SelectedFields, Sort, " + ?(OptionNodeChangeMode, "GroupComposition", "OptionStructure");
	TablesNames = StringFunctionsClientServer.SplitStringIntoSubstringsArray(TablesNames, ",", True, True);
	For Each TableName In TablesNames Do
		SelectedRows.Insert(TableName, ReportsServer.RememberSelectedRows(ThisObject, TableName, "DCID"));
	EndDo;
	CommonClientServer.SupplementArray(FillingParameters.Result.ExpandTreeNodes, TablesNames);
EndProcedure

&AtServer
Procedure QuickSettingsRestoreState(FillingParameters)
	SelectedRows = CommonClientServer.StructureProperty(FillingParameters, "SelectedRows");
	If TypeOf(SelectedRows) = Type("Structure") Then
		For Each KeyAndValue In SelectedRows Do
			ReportsServer.RestoreSelectedRows(ThisObject, KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
	EndIf;
EndProcedure

&AtServer
Procedure QuickSettingsImportSettingsToComposer(FillingParameters)
	NewDCSettings = Undefined;
	NewDCUserSettings = Undefined;
	If FillingParameters.Property("DCSettingsComposer") Then
		NewDCSettings = FillingParameters.DCSettingsComposer.Settings;
		NewDCUserSettings = FillingParameters.DCSettingsComposer.UserSettings;
	Else
		If FillingParameters.Property("DCSettings") Then
			NewDCSettings = FillingParameters.DCSettings;
		EndIf;
		If FillingParameters.Property("DCUserSettings") Then
			NewDCUserSettings = FillingParameters.DCUserSettings;
		EndIf;
	EndIf;
	
	If ReportSettings.Events.BeforeImportSettingsToComposer Then
		NewXMLSettings = CommonClientServer.StructureProperty(ReportSettings, "NewXMLSettings");
		If TypeOf(NewXMLSettings) = Type("String") Then
			Try
				NewDCSettings = Common.ValueFromXMLString(NewXMLSettings);
			Except
				NewDCSettings = Undefined;
			EndTry;
			ReportSettings.NewXMLSettings = Undefined;
		EndIf;
		
		NewUserXMLSettings = CommonClientServer.StructureProperty(ReportSettings, "NewUserXMLSettings");
		If TypeOf(NewUserXMLSettings) = Type("String") Then
			Try
				NewDCUserSettings = Common.ValueFromXMLString(NewUserXMLSettings);
			Except
				NewDCUserSettings = Undefined;
			EndTry;
			ReportSettings.NewUserXMLSettings = Undefined;
		EndIf;
	EndIf;
	
	ClearNonexistingFieldsFromSettings = CommonClientServer.StructureProperty(FillingParameters, "ClearNonexistingFieldsFromSettings", False);
	
	UpdateOptionSettings = CommonClientServer.StructureProperty(FillingParameters, "UpdateOptionSettings", False);
	If UpdateOptionSettings Or ClearNonexistingFieldsFromSettings Then
		NewDCSettings = Report.SettingsComposer.GetSettings();
		If ClearNonexistingFieldsFromSettings Then
			ClearSettingsFromNonExistingFieldsAtServer(NewDCSettings);
		EndIf;
		Report.SettingsComposer.LoadFixedSettings(New DataCompositionSettings);
	EndIf;
	
	ResetUserSettings = CommonClientServer.StructureProperty(FillingParameters, "ResetUserSettings", False);
	If ResetUserSettings Or ClearNonexistingFieldsFromSettings Then
		NewDCUserSettings = New DataCompositionUserSettings;
	EndIf;
	
	If ReportSettings.Events.BeforeImportSettingsToComposer Then
		ReportObject = ReportsServer.ReportObject(FillingParameters.ReportObjectOrFullName);
		ReportObject.BeforeImportSettingsToComposer(
			ThisObject,
			ReportSettings.SchemaKey,
			CurrentVariantKey,
			NewDCSettings,
			NewDCUserSettings);
	EndIf;
	
	SettingsImported = ReportsClientServer.LoadSettings(Report.SettingsComposer, NewDCSettings, NewDCUserSettings);
	// To set fixed filters, use the composer as it comprises the most complete collection of settings.
	// In parameters, in BeforeImport, some parameters can be missing if their settings were not overwritten.
	If SettingsImported AND TypeOf(ParametersForm.Filter) = Type("Structure") Then
		ReportsServer.SetFixedFilters(ParametersForm.Filter, NewDCSettings, ReportSettings);
	EndIf;
	
	FilterConditions = CommonClientServer.StructureProperty(FillingParameters, "FiltersConditions");
	If FilterConditions <> Undefined Then
		DCNode = Report.SettingsComposer.UserSettings;
		For Each KeyAndValue In FilterConditions Do
			DCUserSetting = DCNode.GetObjectByID(KeyAndValue.Key);
			DCUserSetting.ComparisonType = KeyAndValue.Value;
		EndDo;
	EndIf;
	
	If FillingParameters.VariantModified Then
		OptionChanged = True;
	EndIf;
	If FillingParameters.UserSettingsModified Then
		UserSettingsModified = True;
	EndIf;
EndProcedure

&AtServer
Procedure QuickSettingsRemoveOldItemsAndCommands(FillingParameters)
	// Remove items.
	ItemsToRemove = New Array;
	AddSubordinateItems(ItemsToRemove, Items.QuickFilters.ChildItems);
	AddSubordinateItems(ItemsToRemove, Items.RegularFilters.ChildItems);
	AddSubordinateItems(ItemsToRemove, Items.AdvancedHeaderPage.ChildItems);
	AddSubordinateItems(ItemsToRemove, Items.AdvancedGroupsPage.ChildItems);
	AddSubordinateItems(ItemsToRemove, Items.AdvancedFooterPage.ChildItems);
	For Each Item In ItemsToRemove Do
		Items.Delete(Item);
	EndDo;
	
	// Delete commands
	CommandsToDelete = New Array;
	For Each Command In Commands Do
		If ConstantCommands.FindByValue(Command.Name) = Undefined Then
			CommandsToDelete.Add(Command);
		EndIf;
	EndDo;
	For Each Command In CommandsToDelete Do
		Commands.Delete(Command);
	EndDo;
EndProcedure

&AtServer
Procedure AddSubordinateItems(Destination, WhereFrom)
	For Each SubordinateItem In WhereFrom Do
		If TypeOf(SubordinateItem) = Type("FormGroup")
			Or TypeOf(SubordinateItem) = Type("FormTable") Then
			AddSubordinateItems(Destination, SubordinateItem.ChildItems);
		EndIf;
		Destination.Add(SubordinateItem);
	EndDo;
EndProcedure

&AtServer
Procedure QuickSettingsCreateControlItemAndImportValues(FillingParameters, Information)
	// Cache for quick search at client.
	UserSettingsMap = New Map;
	MetadataObjectNamesMap   = Information.MetadataObjectNamesMap;
	OptionSettingsMap         = New Map;
	
	// Remove attributes
	FillingParameters.Insert("Attributes", New Structure);
	FillingParameters.Attributes.Insert("ItemsToAdd",  New Array);
	FillingParameters.Attributes.Insert("ToDelete",    New Array);
	FillingParameters.Attributes.Insert("Existing", New Map);
	TypesDetailsValueTable = New TypeDescription("ValueTable");
	AllAttributes = GetAttributes();
	For Each Attribute In AllAttributes Do
		AttributeFullName = FullAttributeName(Attribute);
		If ConstantAttributes.FindByValue(AttributeFullName) = Undefined Then
			FillingParameters.Attributes.Existing.Insert(AttributeFullName, Attribute.ValueType);
			SubordinateAttributes = GetAttributes(AttributeFullName);
			If ReportsServer.TypesDetailsMatch(Attribute.ValueType, TypesDetailsValueTable) Then
				For Each SubordinateAttribute In SubordinateAttributes Do
					SubordinateAttributeFullName = FullAttributeName(SubordinateAttribute);
					FillingParameters.Attributes.Existing.Insert(SubordinateAttributeFullName, SubordinateAttribute.ValueType);
				EndDo;
			EndIf;
		EndIf;
	EndDo;
	
	// Local variables for setting values and properties after attributes creation.
	AddedInputFields          = New Structure;
	AddedValuesList     = New Array;
	AddedStandardPeriods = New Array;
	
	// Link structure.
	Links = Information.Links;
	
	MainFormAttributesNames     = New Map;
	NamesOfItemsForEstablishingLinks = New Map;
	SettingsWithComparisonTypeEqual    = New Map;
	
	DCSettingsComposer       = Report.SettingsComposer;
	DCUserSettings = DCSettingsComposer.UserSettings;
	DCSettings                 = DCSettingsComposer.Settings;
	
	AdditionalItemsSettings = CommonClientServer.StructureProperty(DCUserSettings.AdditionalProperties, "FormItems");
	If AdditionalItemsSettings = Undefined Then
		AdditionalItemsSettings = New Map;
	EndIf;
	
	Modes = DataCompositionSettingsItemViewMode;
	
	OutputGroups = New Structure;
	OutputGroups.Insert("QuickFilters", New Structure("Order, Size, HasLongFields", New Array, 0, False));
	OutputGroups.Insert("RegularFilters", New Structure("Order, Size, HasLongFields", New Array, 0, False));
	OutputGroups.Insert("AdditionalHeader", New Structure("Order, Size", New Array, 0));
	OutputGroups.Insert("AdditionalFooter", New Structure("Order, Size", New Array, 0));
	OutputGroups.Insert("AdditionalTabs", New ValueList);
	AdditionalTabsSearch = New Map;
	
	ReportObject = Undefined;
	
	HasDataImportFromFile = Common.SubsystemExists("StandardSubsystems.ImportDataFromFile");
	
	If OptionNodeChangeMode Then
		SettingsToOutput = New Array;
	Else
		SettingsToOutput = Information.UserSettings.Copy(New Structure("OutputAllowed", True));
		SettingsToOutput.Sort("IndexInCollection Asc");
	EndIf;
	
	SettingsTypesToOutput = New Array;
	If ExtendedMode <> 1 Then
		SettingsTypesToOutput.Add("FilterItem");
		SettingsTypesToOutput.Add("FilterItemsGroup");
		SettingsTypesToOutput.Add("SettingsParameterValue");
		SettingsTypesToOutput.Add("ConditionalAppearanceItem");
	EndIf;
	
	OtherSettings = New Structure;
	OtherSettings.Insert("Links",       Links);
	OtherSettings.Insert("ReportObject", Undefined);
	OtherSettings.Insert("FillingParameters",       FillingParameters);
	OtherSettings.Insert("PathToComposer",         "Report.SettingsComposer");
	OtherSettings.Insert("HasDataImportFromFile", HasDataImportFromFile);
	OtherSettings.Insert("AdditionalItemsSettings",   AdditionalItemsSettings);
	OtherSettings.Insert("MainFormAttributesNames",       MainFormAttributesNames);
	OtherSettings.Insert("NamesOfItemsForEstablishingLinks",   NamesOfItemsForEstablishingLinks);
	OtherSettings.Insert("MetadataObjectNamesMap", MetadataObjectNamesMap);
	OtherSettings.Insert("AddedInputFields",          AddedInputFields);
	OtherSettings.Insert("AddedStandardPeriods", AddedStandardPeriods);
	OtherSettings.Insert("AddedValuesList",     AddedValuesList);
	OtherSettings.Insert("HasFiltersWithConditions", False);
	
	CompanyField = New DataCompositionField("DataParameters.Company");
	
	For Each SettingProperties In SettingsToOutput Do
		
		OptionSettingsItem = SettingProperties.OptionSetting;
		If OptionSettingsItem = Undefined Then
			Continue;
		EndIf;
		
		If (SettingProperties.Type = "SelectedFields"
				Or SettingProperties.Type = "Filter"
				Or SettingProperties.Type = "Order")
			AND SettingProperties.TreeRow = Information.OptionTreeRootRow Then
			// Register in the information on user settings.
			TableName = SettingProperties.Type;
			If TableName = "Order" Then
				TableName = "Sort";
			EndIf;
			UserSettingsMap.Insert(TableName, SettingProperties.DCID);
			Continue; // Output is not required.
		EndIf;
		
		If SettingsTypesToOutput.Find(SettingProperties.Type) = Undefined Then
			Continue;
		EndIf;
		
		UserSettingsMap.Insert(SettingProperties.ItemID, SettingProperties.DCID);
		
		SearchOptionSetting = New Structure;
		SearchOptionSetting.Insert("DCNodeID",     SettingProperties.TreeRow.DCID);
		SearchOptionSetting.Insert("CollectionName",            OptionSettingsItem.CollectionName);
		SearchOptionSetting.Insert("DCItemID", OptionSettingsItem.DCID);
		OptionSettingsMap.Insert(SettingProperties.ItemID, SearchOptionSetting);
		
		// Determine a group for output.
		If SettingProperties.Type = "ConditionalAppearanceItem" Then
			// Determine a section.
			RootRowOfOptionTree = Undefined;
			CurrentRow = SettingProperties.TreeRow;
			While CurrentRow <> Undefined Do
				If ValueIsFilled(CurrentRow.Title) AND CurrentRow.DCNode <> DCSettings Then
					RootRowOfOptionTree = CurrentRow;
				EndIf;
				CurrentRow = CurrentRow.Parent;
			EndDo;
			If RootRowOfOptionTree = Undefined Then // Section is not found. Output to the main section.
				OutputGroup = OutputGroups.AdditionalFooter;
			Else // Section was found. Output to the group on the "Additional" tab:
				TabTitle = RootRowOfOptionTree.Title;
				OutputGroup = AdditionalTabsSearch.Get(TabTitle);
				If OutputGroup = Undefined Then
					OutputGroup = New Structure("Order, Size", New Array, 0);
					OutputGroup.Insert("Title", TabTitle);
					OutputGroup.Insert("CheckBoxName", "");
					OutputGroups.AdditionalTabs.Add(OutputGroup, TabTitle);
					AdditionalTabsSearch.Insert(TabTitle, OutputGroup);
				EndIf;
			EndIf;
		Else
			If SettingProperties.Quick Then
				OutputGroup = OutputGroups.QuickFilters;
			Else
				OutputGroup = OutputGroups.RegularFilters;
			EndIf;
			If StrLen(SettingProperties.Presentation) > 40 Then
				OutputGroup.HasLongFields = True;
			EndIf;
		EndIf;
		
		////////////////////////////////////////////////////////////////////////////////
		// Generator
		ReportsServer.OutputSettingItems(ThisObject, Items, SettingProperties, OutputGroup, OtherSettings);
	EndDo;
	
	Items.EditFilterCriteria.Visible = OtherSettings.HasFiltersWithConditions;
	
	ReportsServer.OutputInOrder(ThisObject, OutputGroups.QuickFilters, Items.QuickFilters, 2, False);
	OutputGroup = OutputGroups.RegularFilters;
	ColumnsNumber = ?(OutputGroup.HasLongFields AND OutputGroup.Size < 10, 1, 2);
	ReportsServer.OutputInOrder(ThisObject, OutputGroup, Items.RegularFilters, ColumnsNumber, False);
	ReportsServer.OutputInOrder(ThisObject, OutputGroups.AdditionalHeader, Items.AdvancedHeaderPage, 1);
	ReportsServer.OutputInOrder(ThisObject, OutputGroups.AdditionalFooter, Items.AdvancedFooterPage, 1);
	
	AdditionalGroupNumber = 0;
	For Each TabDetails In OutputGroups.AdditionalTabs Do
		AdditionalGroupNumber = AdditionalGroupNumber + 1;
		OutputGroup = TabDetails.Value;
		
		GroupName   = "SettingsGroup_" + String(AdditionalGroupNumber);
		ColumnsName  = "SettingsGroup_Columns_" + String(AdditionalGroupNumber);
		IndentName   = "SettingsGroup_Indent_" + String(AdditionalGroupNumber);
		
		CurrentGroup = Items.Add(GroupName, Type("FormGroup"), Items.AdvancedGroupsPage);
		CurrentGroup.Type         = FormGroupType.UsualGroup;
		CurrentGroup.Group = ChildFormItemsGroup.Vertical;
		CurrentGroup.Title   = OutputGroup.Title;
		CurrentGroup.Representation = UsualGroupRepresentation.None;
		CurrentGroup.ShowTitle = True;
		CurrentGroup.TitleFont      = New Font(StyleFonts.NormalTextFont, , , True);
		CurrentGroup.TitleTextColor = StyleColors.FieldTextColor;
		
		If OutputGroup.CheckBoxName <> "" Then
			CurrentGroup.ShowTitle = False;
			CheckBox = Items[OutputGroup.CheckBoxName];
			CheckBox.Title = OutputGroup.Title;
			Items.Move(CheckBox, CurrentGroup);
		EndIf;
		
		If OutputGroup.Size > 0 Then
			Columns = Items.Add(ColumnsName, Type("FormGroup"), CurrentGroup);
			Columns.Type                 = FormGroupType.UsualGroup;
			Columns.Group         = ChildFormItemsGroup.AlwaysHorizontal;
			Columns.Representation         = UsualGroupRepresentation.None;
			Columns.ShowTitle = False;
			
			Indent = Items.Add(IndentName, Type("FormDecoration"), Columns);
			Indent.Type       = FormDecorationType.Label;
			Indent.Title = "    ";
			
			ReportsServer.OutputInOrder(ThisObject, OutputGroup, Columns, 1);
		EndIf;
	EndDo;
	
	// Delete old attributes and add new ones.
	For Each KeyAndValue In FillingParameters.Attributes.Existing Do
		FillingParameters.Attributes.ToDelete.Add(KeyAndValue.Key);
	EndDo;
	ChangeAttributes(FillingParameters.Attributes.ItemsToAdd, FillingParameters.Attributes.ToDelete);
	
	// Entry fields (setting values and links).
	For Each KeyAndValue In AddedInputFields Do
		AttributeName = KeyAndValue.Key;
		ThisObject[AttributeName] = KeyAndValue.Value;
		Items[AttributeName].DataPath = AttributeName;
	EndDo;
	
	// Standard periods (setting values and links).
	For Each SettingProperties In AddedStandardPeriods Do
		More = SettingProperties.More;
		ThisObject[More.ValueName] = SettingProperties.Value;
		Items[More.StartPeriodName].DataPath    = More.ValueName + ".StartDate";
		Items[More.EndPeriodName].DataPath = More.ValueName + ".EndDate";
	EndDo;
	
	// Pickup fields (setting values and links).
	For Each SettingProperties In AddedValuesList Do
		More = SettingProperties.More;
		TableName = More.TableName;
		FormTable = Items[TableName];
		UsageColumn = Items[More.ColumnNameUsage];
		ValueColumn = Items[More.ColumnNameValue];
		ListWithCheckBoxes = New ValueList;
		
		TypeUndefined = Type("Undefined");
		TypesUndefinedDetails = New TypeDescription("Undefined");
		Count = SettingProperties.MarkedValues.Count();
		For Number = 1 To Count Do
			ReverseIndex = Count - Number;
			ListItem = SettingProperties.MarkedValues[ReverseIndex];
			Value = ListItem.Value;
			If Not ValueIsFilled(ListItem.Presentation)
				AND (Value = Undefined
					Or Value = TypeUndefined
					Or Value = TypesUndefinedDetails
					Or Not ValueIsFilled(Value)) Then
				SettingProperties.MarkedValues.Delete(ReverseIndex);
				Continue; // Empty values are prohibited.
			EndIf;
			If SettingProperties.RestrictSelectionBySpecifiedValues
				AND SettingProperties.ValuesForSelection.FindByValue(Value) = Undefined Then
				SettingProperties.MarkedValues.Delete(ReverseIndex);
				Continue; // Selected value is not in the list of values available for selection.
			EndIf;
			ReportsClientServer.AddUniqueValueToList(ListWithCheckBoxes, Value, ListItem.Presentation, True);
		EndDo;
		
		For Each ListItem In SettingProperties.ValuesForSelection Do
			ReportsClientServer.AddUniqueValueToList(ListWithCheckBoxes, ListItem.Value, ListItem.Presentation, False);
		EndDo;
		
		ListWithCheckBoxes.SortByPresentation(SortDirection.Asc);
		
		ThisObject[TableName] = ListWithCheckBoxes;
		ThisObject[TableName].ValueType = SettingProperties.TypeDescription;
		FormTable.DataPath         = TableName;
		ValueColumn.DataPath      = TableName + ".Value";
		UsageColumn.DataPath = TableName + ".Check";
		
		// Some event handlers can be attached only after setting links between items and data.
		FormTable.SetAction("OnStartEdit", "Attachable_ListWithPicking_OnEditStart");
		FormTable.SetAction("BeforeEditEnd", "Attachable_ListWithPicking_BeforeEditEnd");
		FormTable.SetAction("OnChange", "Attachable_ListWithPicking_OnChange");
		If SettingProperties.RestrictSelectionBySpecifiedValues Then
			FormTable.SetAction("BeforeAddRow", "Attachable_FixedList_BeforeAddRow");
			FormTable.SetAction("BeforeDeleteRow", "Attachable_FixedList_BeforeDelete");
		Else
			FormTable.SetAction("ChoiceProcessing", "Attachable_ListWithPicking_ProcessSelection");
		EndIf;
		UsageColumn.SetAction("OnChange", "Attachable_ListWithPicking_Use_OnChange");
	EndDo;
	
	// Save matches for quick search in the form data.
	QuickSearchForUserSettings = New FixedMap(UserSettingsMap);
	QuickSearchForMetadataObjectsNames   = New FixedMap(MetadataObjectNamesMap);
	QuickSearchForOptionSettings         = New FixedMap(OptionSettingsMap);
	
	DCUserSettings.AdditionalProperties.Insert("FormItems", AdditionalItemsSettings);
EndProcedure

&AtServer
Function FullAttributeName(Attribute)
	Return ?(IsBlankString(Attribute.Path), "", Attribute.Path + ".") + Attribute.Name;
EndFunction

&AtServer
Procedure AdvancedSettingsImportValues(FillingParameters, Information)
	If OptionNodeChangeMode Then
		FoundItems = Information.OptionTree.Rows.FindRows(New Structure("DCID", CurrentDCNodeID), True);
		RootRow = FoundItems[0];
	Else
		RootRow = Information.OptionTreeRootRow;
	EndIf;
	Information.Insert("CurrentTreeRow", RootRow);
	Information.OptionSettings.Columns.Add("IDInForm");
	
	If OptionNodeChangeMode AND CurrentDCNodeType <> "Chart" Then
		GroupComposition.GetItems().Clear();
		RegisterGroupCompositionItems();
	Else
		Items.GroupingContentPage.Visible = False;
	EndIf;
	
	SelectedFields.GetItems().Clear();
	DCNode = FieldTablesFindNode(ThisObject, "SelectedFields", Undefined);
	SelectedFieldsVisibility = RegisterItemsOfSelectedFields(DCNode);
	If SelectedFieldsVisibility Then
		FillingParameters.Result.ExpandTreeNodes.Add("SelectedFields");
	EndIf;
	
	SortingVisibility = False;
	If CurrentDCNodeType <> "Chart" Then
		Sort.GetItems().Clear();
		SortingVisibility = RegisterSortingItems();
	EndIf;
	If SortingVisibility Then
		FillingParameters.Result.ExpandTreeNodes.Add("Sort");
	EndIf;
	
	FiltersTableVisibility = (ExtendedMode = 1 AND CurrentDCNodeType <> "Chart");
	If FiltersTableVisibility Then
		Filters.GetItems().Clear();
		RegisterParametersItems(Information);
		RegisterFiltersItems(Information);
		FillingParameters.Result.ExpandTreeNodes.Add("Filters");
	EndIf;
	
	ConditionalAppearanceVisibility = (ExtendedMode = 1);
	If ConditionalAppearanceVisibility Then
		Appearance.GetItems().Clear();
		RegisterAppearanceItems(Information);
		FillingParameters.Result.ExpandTreeNodes.Add("Appearance");
	EndIf;
	
	If SelectedFieldsVisibility AND SortingVisibility Then
		Items.SelectedFieldsAndSortingsPage.Title = NStr("en = 'Fields and sortings'; ru = 'Поля и сортировки';pl = 'Pola i sortowanie';es_ES = 'Campos y clasificaciones';es_CO = 'Campos y clasificaciones';tr = 'Alanlar ve sıralama';it = 'Campi e ordinamenti';de = 'Felder und Sortierungen'");
	ElsIf SelectedFieldsVisibility Then
		Items.SelectedFieldsAndSortingsPage.Title = NStr("en = 'Fields'; ru = 'Поля';pl = 'Pola';es_ES = 'Campos';es_CO = 'Campos';tr = 'Alanlar';it = 'Campi';de = 'Felder'");
	ElsIf SortingVisibility Then
		Items.SelectedFieldsAndSortingsPage.Title = NStr("en = 'Sorting'; ru = 'Сортировка';pl = 'Sortowanie';es_ES = 'Clasificación';es_CO = 'Clasificación';tr = 'Sıralama';it = 'Ordinamento';de = 'Sortierung'");
	EndIf;
	
	If ExtendedMode = 1 AND Not OptionNodeChangeMode Then
		Items.HasNestedReportsGroup.Visible = Information.HasNestedReports;
		Items.HasNestedFiltersGroup.Visible = Information.HasNestedFilters;
		Items.HasNestedAppearanceGroup.Visible = Information.HasNestedAppearance;
		Items.HasNestedFieldsOrSortingGroup.Visible = Information.HasNestedFields Or Information.HasNestedSorting;
	Else
		Items.HasNestedReportsGroup.Visible = False;
		Items.HasNestedFiltersGroup.Visible = False;
		Items.HasNestedAppearanceGroup.Visible = False;
		Items.HasNestedFieldsOrSortingGroup.Visible = False;
	EndIf;
	
	If CurrentDCNodeType = "Chart" Then
		Items.CurrentDCNodeChartType.Visible = True;
		Items.CurrentDCNodeChartType.TypeRestriction = New TypeDescription("ChartType");
		
		RootDCNode = Report.SettingsComposer.Settings.GetObjectByID(CurrentDCNodeID);
		If TypeOf(RootDCNode) = Type("DataCompositionNestedObjectSettings") Then
			RootDCNode = RootDCNode.Settings;
		EndIf;
		DCParameter = RootDCNode.OutputParameters.FindParameterValue(New DataCompositionParameter("ChartType"));
		If DCParameter = Undefined Then
			Items.CurrentDCNodeChartType.Visible = False;
		Else
			CurrentDCNodeChartType = DCParameter.Value;
		EndIf;
	Else
		Items.CurrentDCNodeChartType.Visible = False;
	EndIf;
	
	StructureVisibility = False;
	If Not OptionNodeChangeMode AND RootRow.Type <> "NestedObjectSettings" AND ReportSettings.EditStructureAllowed Then
		ParentRows = OptionStructure.GetItems();
		ParentRows.Clear();
		HasCheckBoxes = RegisterReportStructureItem(RootRow, ParentRows);
		FillingParameters.Result.ExpandTreeNodes.Add("OptionStructure");
		StructureVisibility = HasCheckBoxes Or ExtendedMode = 1;
	EndIf;
	
	If Not Information.HasQuickSettings
		AND Not Information.HasRegularSettings
		AND Not StructureVisibility
		AND Not ConditionalAppearanceVisibility
		AND Not SelectedFieldsVisibility
		AND Not SortingVisibility
		AND Not FiltersTableVisibility Then
		Items.NoUserSettingsPage.Visible = True;
		Items.SettingsPages.PagesRepresentation = FormPagesRepresentation.None;
		Items.SettingsPages.CurrentPage = Items.NoUserSettingsPage;
		Items.CloseAndGenerate.Visible = False;
	Else
		Items.SelectedFieldsAndSortingsPage.Visible    = SelectedFieldsVisibility Or SortingVisibility;
		Items.SelectedFields.Visible                       = SelectedFieldsVisibility;
		Items.Sort.Visible                          = SortingVisibility;
		Items.FieldsAndSortingCommands.Visible             = SelectedFieldsVisibility AND SortingVisibility;
		Items.FiltersGroupExtendedMode.Visible        = FiltersTableVisibility;
		Items.AppearanceExtendedModeGroup.Visible    = ConditionalAppearanceVisibility;
		Items.OptionStructurePage.Visible           = StructureVisibility;
		Items.NoUserSettingsPage.Visible = False;
		Items.SettingsPages.PagesRepresentation = FormPagesRepresentation.TabsOnTop;
		Items.CloseAndGenerate.Visible = True;
	EndIf;
	
	// Items visibility.
	Items.OptionStructureCommands_Add.Visible  = (ExtendedMode = 1);
	Items.OptionStructureCommands_Add1.Visible = (ExtendedMode = 1);
	Items.OptionStructureCommands_Change.Visible  = (ExtendedMode = 1);
	Items.OptionStructureCommands_Change1.Visible = (ExtendedMode = 1);
	Items.OptionStructureCommands_MoveHierarchically.Visible  = (ExtendedMode = 1);
	Items.OptionStructureCommands_MoveHierarchically1.Visible = (ExtendedMode = 1);
	Items.OptionStructureCommands_MoveInsideParent.Visible  = (ExtendedMode = 1);
	Items.OptionStructureCommands_MoveInsideParent1.Visible = (ExtendedMode = 1);
	Items.OptionStructure.ChangeRowSet  = (ExtendedMode = 1);
	Items.OptionStructure.ChangeRowOrder = (ExtendedMode = 1);
	Items.OptionStructure.EnableStartDrag = (ExtendedMode = 1);
	Items.OptionStructure.EnableDrag       = (ExtendedMode = 1);
	Items.OptionStructure.Header              = (ExtendedMode = 1);
	Items.OptionStructureTitle.Visible = (ExtendedMode = 1);
	Items.OptionStructureContainsFilters.Visible             = (ExtendedMode = 1);
	Items.OptionStructureContainsFieldsOrOrders.Visible  = (ExtendedMode = 1);
	Items.OptionStructureContainsConditionalAppearance.Visible = (ExtendedMode = 1);
	Items.SelectedFieldsCommands_AddDelete.Visible    = (ExtendedMode = 1);
	Items.SelectedFieldsCommands_AddDelete1.Visible   = (ExtendedMode = 1);
	Items.SelectedFieldsCommands_Groups.Visible    = (ExtendedMode = 1);
	Items.SelectedFieldsCommands_Groups1.Visible = (ExtendedMode = 1);
	Items.SortingCommands_AddDelete.Visible    = (ExtendedMode = 1) Or (SortingVisibility AND Not SelectedFieldsVisibility);
	Items.SortingCommands_AddDelete1.Visible = (ExtendedMode = 1) Or (SortingVisibility AND Not SelectedFieldsVisibility);
	
	Items.HasNonexistentFieldsGroup.Visible = Information.HasNonexistingFields
		AND (ExtendedMode = 1)
		AND (CurrentDCNodeID = Undefined);
	
EndProcedure

// Drag.

&AtClient
Procedure DragWithinTable(DraggingSource, DestinationID)
	// Define parameters.
	TableName         = DraggingSource.TableName;
	RowsToMove = DraggingSource.TreeRows;
	CurrentRow      = DraggingSource.CurrentRow;
	
	TableAttribute = ThisObject[TableName];
	DestinationRow = FindByID(TableAttribute, DestinationID);
	Parent   = GetParent(TableName, DestinationRow);
	
	TableItem = Items[TableName];
	SelectedRows = TableItem.SelectedRows;
	SelectedRows.Clear();
	
	For Each RowToMove In RowsToMove Do
		IsCurrent = (RowToMove = CurrentRow);
		
		// Move.
		Result = FieldTablesMove(TableName, RowToMove, DestinationRow);
		
		// Bells and whistles.
		NewRowID = Result.TableRow.GetID();
		If IsCurrent Then
			TableItem.CurrentRow = NewRowID;
		EndIf;
		If SelectedRows.Find(NewRowID) = Undefined Then
			SelectedRows.Add(NewRowID);
		EndIf;
	EndDo;
	
	TableItem.Expand(Parent.GetID(), True);
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure DragSelectedFieldsToSorting(DraggingSource, DestinationID)
	// Define source parameters.
	SourceTableName = DraggingSource.TableName;
	SourceTable    = ThisObject[SourceTableName];
	SourceDCNode     = FieldTablesFindNode(ThisObject, SourceTableName);
	
	// Determining destination parameters.
	DestinationTableName = "Sort";
	DestinationTable = ThisObject[DestinationTableName];
	
	PasteBeforeWhat = FindByID(DestinationTable, DestinationID);
	
	If PasteBeforeWhat <> Undefined AND PasteBeforeWhat.IsSection Then
		// If the destination is a section, adding the object to the section.
		DestinationParent     = PasteBeforeWhat;
		PasteBeforeWhat = Undefined;
		AddToEnd  = False;
	Else
		// To the same level as the destination item.
		DestinationParent    = GetParent(DestinationTableName, PasteBeforeWhat);
		AddToEnd = True;
	EndIf;
	
	WhereToPaste = GetItems(DestinationTable, DestinationParent);
	
	If PasteBeforeWhat = Undefined Then
		Count = WhereToPaste.Count();
		If Count > 0 AND Not AddToEnd Then
			PasteBeforeWhat = WhereToPaste[0];
		EndIf;
	EndIf;
	
	DestinationDCNode = FieldTablesFindNode(ThisObject, DestinationTableName);
	PasteDCBeforeWhat = FindDCObject(DestinationDCNode, PasteBeforeWhat);
	DestinationParentInDC = FindDCObject(DestinationDCNode, DestinationParent);
	WhereToPasteDC = GetDCItems(DestinationDCNode, DestinationParentInDC);
	
	If PasteBeforeWhat = Undefined Then
		If AddToEnd Then
			Index   = WhereToPaste.Count();
			DCIndex = WhereToPasteDC.Count();
		Else
			Index   = 0;
			DCIndex = 0;
		EndIf;
	Else
		Index   = WhereToPaste.IndexOf(PasteBeforeWhat);
		DCIndex = WhereToPasteDC.IndexOf(PasteDCBeforeWhat);
	EndIf;
	
	QuickRowSearchByDCField = New Map;
	For Each TableRow In WhereToPaste Do
		DCItem = FindDCObject(DestinationDCNode, TableRow);
		If TypeOf(DCItem) = Type("DataCompositionOrderItem") Then
			QuickRowSearchByDCField.Insert(DCItem.Field, TableRow);
		EndIf;
	EndDo;
	
	ItemType = Type("DataCompositionOrderItem");
	
	// Output the result.
	SourceCurrentRow = DraggingSource.CurrentRow;
	DestinationCurrentRow     = Undefined;
	
	// Source iteration.
	MovedRows = New Array;
	ProcessedItems = New Array;
	
	Collections = New Array;
	Count = 0;
	CurrentCollection = DraggingSource.TreeRows;
	While True Do
		// Iterate the current collection.
		For Each SourceTableRow In CurrentCollection Do
			If SourceTableRow.SettingType = "AutoSelectedField" Then
				Continue;
			EndIf;
			If ProcessedItems.Find(SourceTableRow) <> Undefined Then
				Continue;
			EndIf;
			ProcessedItems.Add(SourceTableRow);
			
			// Register a new collection to be processed.
			If SourceTableRow.IsFolder Then
				Collections.Add(SourceTableRow.GetItems());
				Count = Count + 1;
				Continue;
			EndIf;
			
			// Analyze the source row.
			IsCurrent = (SourceTableRow = SourceCurrentRow);
			
			SourceDCObject = FindDCObject(SourceDCNode, SourceTableRow);
			DCField = SourceDCObject.Field;
			
			AvailableDCField = DestinationDCNode.OrderAvailableFields.FindField(DCField);
			If AvailableDCField = Undefined Then
				Continue; // Could not add the field.
			EndIf;
			
			FoundRow = QuickRowSearchByDCField.Get(DCField);
			If FoundRow <> Undefined Then
				Result = FieldTablesMove(DestinationTableName, FoundRow, DestinationParent, , Index, DCIndex);
				NewRow = Result.TableRow;
				Index   = Result.IndexOf + 1;
				DCIndex = Result.DCIndex + 1;
				MovedRows.Add(NewRow);
				QuickRowSearchByDCField.Insert(DCField, NewRow);
				Continue; // The row was moved, no need to add a new one.
			EndIf;
			
			NewDCItem = WhereToPasteDC.Insert(DCIndex, ItemType);
			NewDCItem.Use     = True;
			NewDCItem.Field              = DCField;
			NewDCItem.OrderType = DataCompositionSortDirection.Asc;
			
			NewRow = WhereToPaste.Insert(Index);
			NewRow.DCID = DestinationDCNode.GetIDByObject(NewDCItem);
			NewRow.Use   = NewDCItem.Use;
			NewRow.Presentation   = AvailableDCField.Title;
			NewRow.Direction     = NewDCItem.OrderType;
			NewRow.SettingType    = "OrderingItem";
			NewRow.PictureIndex  = ReportsClientServer.PictureIndex("Item");
			
			Index   = Index   + 1;
			DCIndex = DCIndex + 1;
			
			If IsCurrent Or DestinationCurrentRow = Undefined Then
				DestinationCurrentRow = NewRow;
			EndIf;
			
			MovedRows.Add(NewRow);
			QuickRowSearchByDCField.Insert(DCField, NewRow);
			
		EndDo;
		
		// Go to the next collection.
		If Count = 0 Then
			Break;
		EndIf;
		Count = Count - 1;
		CurrentCollection = Collections[0];
		Collections.Delete(0);
	EndDo;
	
	// Bells and whistles.
	DestinationTableItem = Items[DestinationTableName];
	CurrentItem = DestinationTableItem;
	DestinationTableItem.SelectedRows.Clear();
	If DestinationCurrentRow <> Undefined Then
		DestinationTableItem.CurrentRow = DestinationCurrentRow.GetID();
	EndIf;
	For Each NewRow In MovedRows Do
		NewRowID = NewRow.GetID();
		If DestinationTableItem.SelectedRows.Find(NewRowID) = Undefined Then
			DestinationTableItem.SelectedRows.Add(NewRowID);
		EndIf;
	EndDo;
	
	DestinationTableItem.Expand(DestinationParent.GetID(), True);
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure DragSortingInSelectedFields(DraggingSource, DestinationID)
	FieldTablesRemove(DraggingSource.TableName, DraggingSource.TreeRows, False);
	DetermineIfModified();
EndProcedure

&AtClient
Function RegisterDragStart(TableName, DraggingSource = Undefined)
	
	Context = NewContext(TableName, "DragStart");
	DefineSelectedRows(Context);
	If ValueIsFilled(Context.CancelReason) Then
		Return False;
	EndIf;
	
	DraggingSource = New Structure("TableName, TreeRows, CurrentRow");
	FillPropertyValues(DraggingSource, Context);
	DraggingSourceAtClient = DraggingSource;
	Return True;
	
EndFunction

&AtClient
Procedure CheckDragPossibility(TableName, DestinationID, DragParameters)
	DraggingSource = DraggingSourceAtClient;
	If DraggingSource = Undefined Then
		DragParameters.Action = DragAction.Cancel;
	ElsIf DraggingSource.TableName = TableName Then
		DragParameters.Action = DragAction.Move;
		If DestinationID <> Undefined Then
			ParentRow = ThisObject[TableName].FindByID(DestinationID);
			While ParentRow <> Undefined AND Not ParentRow.IsSection Do
				If DraggingSource.TreeRows.Find(ParentRow) <> Undefined Then
					DragParameters.Action = DragAction.Cancel;
					Break;
				EndIf;
				ParentRow = ParentRow.GetParent();
			EndDo;
		EndIf;
	Else
		DragParameters.Action = DragAction.Choice;
	EndIf;
EndProcedure

&AtClient
Procedure DetermineIfModified()
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		OptionChanged = True;
	EndIf;
EndProcedure

&AtClient
Procedure Update()
	FillQuickSettingsClient();
EndProcedure

// Register settings.

&AtServer
Function RegisterReportStructureItem(TreeRow, ParentRows)
	If TreeRow.Type = "ChartStructureItemCollection"
		Or TreeRow.Type = "TableStructureItemCollection"
		Or TreeRow.Type = "Settings" Then
		Usage = True;
		AvailableFlag = False;
	Else
		If TreeRow.UserSetting = Undefined Then
			Usage = TreeRow.DCNode.Use;
			AvailableFlag = (ExtendedMode = 1);
		Else
			Usage = TreeRow.UserSetting.DCUserSetting.Use;
			AvailableFlag = True;
		EndIf;
	EndIf;
	If Not Usage AND Not AvailableFlag Then
		Return False;
	EndIf;
	
	FormRow = ParentRows.Add();
	FillPropertyValues(FormRow, TreeRow, "DCID, Presentation, Title, Type, Subtype,
		|ContainsFilters, ContainsConditionalAppearance");
	FormRow.ContainsFieldsOrOrders = TreeRow.ContainsFields Or TreeRow.ContainsSorting;
	
	FormRow.AvailableFlag = AvailableFlag;
	FormRow.Use = Usage;
	If FormRow.AvailableFlag AND ExtendedMode = 0 Then
		FormRow.DCID = TreeRow.UserSetting.DCID;
	EndIf;
	
	If ExtendedMode = 0 AND ValueIsFilled(FormRow.Title) Then
		FormRow.Presentation = FormRow.Title;
		FormRow.Highlight = True;
	EndIf;
	
	// Types: "Group", "TableGroup", "ChartGroup",
	//       "Table", "Chart", "NestedObjectSettings".
	FormRow.PictureIndex = ReportsClientServer.PictureIndex(TreeRow.Type, TreeRow.State);
	If FormRow.Type = "Settings" Then
		FormRow.PictureIndex					= -1;
		FormRow.IsSection						= True;
		FormRow.Title							= "";
		FormRow.Presentation					= NStr("en = 'Report'; ru = 'Отчет';pl = 'Raport';es_ES = 'Informe';es_CO = 'Informe';tr = 'Rapor';it = 'Report';de = 'Bericht'");
		FormRow.ContainsFilters					= False;
		FormRow.ContainsFieldsOrOrders			= False;
		FormRow.ContainsConditionalAppearance	= False;
		FormRow.Highlight						= False;
	EndIf;
	
	ParentSubordinateRows = FormRow.GetItems();
	
	HasNestedCheckBoxes = False;
	For Each SubordinateTreeRow In TreeRow.Rows Do
		If RegisterReportStructureItem(SubordinateTreeRow, ParentSubordinateRows) Then
			HasNestedCheckBoxes = True;
		EndIf;
	EndDo;
	
	Return FormRow.AvailableFlag Or HasNestedCheckBoxes;
EndFunction

&AtServer
Procedure RegisterGroupCompositionItems(DCNode = Undefined, DCRowSet = Undefined, RowsSet = Undefined)
	If DCNode = Undefined Then
		DCNode = FieldTablesFindNode(ThisObject, "GroupComposition", Undefined);
		If DCNode = Undefined Then
			Return;
		EndIf;
	EndIf;
	If DCRowSet = Undefined Then
		DCRowSet = DCNode.Items;
	EndIf;
	If RowsSet = Undefined Then
		RowsSet = GroupComposition.GetItems();
	EndIf;
	AvailableFields = DCNode.GroupFieldsAvailableFields;
	For Each DCItem In DCRowSet Do
		SettingType = ReportsClientServer.SettingTypeAsString(TypeOf(DCItem));
		DCField = Undefined;
		If SettingType = "GroupField" Then
			If Not ValueIsFilled(DCItem.Field) Then
				Continue;
			EndIf;
			DCField = DCItem.Field;
		EndIf;
		
		TableRow = RowsSet.Add();
		TableRow.DCID = DCNode.GetIDByObject(DCItem);
		TableRow.SettingType    = SettingType;
		TableRow.Use   = DCItem.Use;
		TableRow.DCField          = DCField;
		
		If SettingType = "AutoGroupField" Then
			TableRow.Presentation  = NStr("en = 'Auto (by all fields)'; ru = 'Авто (по всем полям)';pl = 'Auto (dla wszystkich pól)';es_ES = 'Auto (por todos los campos)';es_CO = 'Auto (por todos los campos)';tr = 'Oto (tüm alanlarda)';it = 'Automatico (per tutti i campi)';de = 'Automatisch (nach allen Feldern)'");
			TableRow.PictureIndex = ReportsClientServer.PictureIndex("Item", "Predefined");
		ElsIf SettingType = "GroupField" Then
			TableRow.GroupType = DCItem.GroupType;
			TableRow.AdditionType  = DCItem.AdditionType;
			AvailableDCField = AvailableFields.FindField(DCItem.Field);
			If AvailableDCField = Undefined Then
				TableRow.Presentation = ReportsClientServer.NameToPresentation(String(DCItem.Field));
				TableRow.PictureIndex = ReportsClientServer.PictureIndex("Item", "DeletionMark");
			Else
				TableRow.Presentation = AvailableDCField.Title;
				If AvailableDCField.Resource Then
					TableRow.PictureIndex = ReportsClientServer.PictureIndex("Resource");
				ElsIf AvailableDCField.Table Then
					TableRow.PictureIndex = ReportsClientServer.PictureIndex("Table");
				ElsIf AvailableDCField.Folder Then
					TableRow.PictureIndex = ReportsClientServer.PictureIndex("Group");
				Else
					TableRow.PictureIndex = ReportsClientServer.PictureIndex("Item");
				EndIf;
				TypesInformation = ReportsClientServer.TypesAnalysis(AvailableDCField.ValueType, False);
				If TypesInformation.ContainsPeriodType Or TypesInformation.ContainsDateType Then
					TableRow.ShowAdditionType = True;
				EndIf;
			EndIf;
		EndIf;
	EndDo;
EndProcedure

&AtServer
Function RegisterItemsOfSelectedFields(DCNode, DCRowSet = Undefined, RowsSet = Undefined, AvailableFields = Undefined)
	If DCNode = Undefined Then
		Return False;
	EndIf;
	If DCRowSet = Undefined Then
		DCRowSet = DCNode.Items;
	EndIf;
	If RowsSet = Undefined Then
		RowSection = SelectedFields.GetItems().Add();
		RowSection.IsSection = True;
		RowSection.Presentation = NStr("en = 'Fields'; ru = 'Поля';pl = 'Pola';es_ES = 'Campos';es_CO = 'Campos';tr = 'Alanlar';it = 'Campi';de = 'Felder'");
		RowSection.PictureIndex = ReportsClientServer.PictureIndex("SelectedFields");
		RowSection.DCID = "SelectedFields";
		RowsSet = RowSection.GetItems();
	EndIf;
	If AvailableFields = Undefined Then
		AvailableFields = DCNode.SelectionAvailableFields;
	EndIf;
	
	GroupPictureIndex = ReportsClientServer.PictureIndex("Group");
	ItemPictureIndex = ReportsClientServer.PictureIndex("Item");
	For Each DCItem In DCRowSet Do
		SettingType = ReportsClientServer.SettingTypeAsString(TypeOf(DCItem));
		IsFolder = False;
		DCField = Undefined;
		If SettingType = "AutoSelectedField" Then
			Presentation = NStr("en = 'Auto (parent''s fields)'; ru = 'Авто (поля родителя)';pl = 'Auto (pole rodzica)';es_ES = 'Auto (campo de padre)';es_CO = 'Auto (campo de padre)';tr = 'Oto (ana alan)';it = 'Automatico (campi madre)';de = 'Auto (übergeordnete Felder)'");
			PictureIndex = 6;
		Else
			If SettingType = "SelectedFieldsGroup" Then
				IsFolder = True;
				PictureIndex = GroupPictureIndex;
			Else
				PictureIndex = ItemPictureIndex;
			EndIf;
			
			Presentation = DCItem.Title;
			If ValueIsFilled(DCItem.Field) Then
				AvailableField = AvailableFields.FindField(DCItem.Field);
				DCField = DCItem.Field;
			Else
				If Not IsFolder Then
					Continue;
				EndIf;
				AvailableField = Undefined;
			EndIf;
			If AvailableField = Undefined Then
				If Not IsFolder Then
					PictureIndex = 5;
					Presentation = ReportsClientServer.NameToPresentation(String(DCItem.Field));
				EndIf;
			ElsIf Presentation = "" Then
				Presentation = AvailableField.Title;
			EndIf;
			If IsFolder AND DCItem.Placement <> DataCompositionFieldPlacement.Auto Then
				Presentation = Presentation + " (" + String(DCItem.Placement) + ")";
			EndIf;
		EndIf;
		
		TableRow = RowsSet.Add();
		FillPropertyValues(TableRow, DCItem);
		TableRow.SettingType    = SettingType;
		TableRow.PictureIndex  = PictureIndex;
		TableRow.IsFolder       = IsFolder;
		TableRow.Presentation   = Presentation;
		TableRow.DCID = DCNode.GetIDByObject(DCItem);
		TableRow.DCField          = DCField;
		
		If IsFolder Then
			RegisterItemsOfSelectedFields(DCNode, DCItem.Items, TableRow.GetItems(), AvailableFields);
		EndIf;
	EndDo;
	
	Return True;
EndFunction

&AtServer
Function RegisterSortingItems()
	DCNode = FieldTablesFindNode(ThisObject, "Sort", Undefined);
	If DCNode = Undefined Then
		Return False;
	EndIf;
	DCRowSet = DCNode.Items;
	
	RowSection = Sort.GetItems().Add();
	RowSection.IsSection = True;
	RowSection.Presentation = NStr("en = 'Sorting'; ru = 'Сортировка';pl = 'Sortowanie';es_ES = 'Clasificación';es_CO = 'Clasificación';tr = 'Sıralama';it = 'Ordinamento';de = 'Sortierung'");
	RowSection.PictureIndex = ReportsClientServer.PictureIndex("Sorting");
	RowSection.DCID = Undefined;
	RowsSet = RowSection.GetItems();
	
	AvailableFields = DCNode.OrderAvailableFields;
	For Each DCItem In DCRowSet Do
		SettingType = ReportsClientServer.SettingTypeAsString(TypeOf(DCItem));
		If SettingType = "OrderingItem" AND Not ValueIsFilled(DCItem.Field) Then
			Continue;
		EndIf;
		
		TableRow = RowsSet.Add();
		TableRow.DCID = DCNode.GetIDByObject(DCItem);
		TableRow.SettingType    = SettingType;
		TableRow.Use   = DCItem.Use;
		TableRow.PictureIndex  = -1;
		
		If SettingType = "AutoOrderItem" Then
			TableRow.Presentation = NStr("en = 'Auto (parent''s sorting)'; ru = 'Авто (сортировки родителя)';pl = 'Auto (sortowanie według rodzica)';es_ES = 'Auto (clasificaciones de padre)';es_CO = 'Auto (clasificaciones de padre)';tr = 'Oto (ana filtre)';it = 'Automatico (smistamento madre)';de = 'Auto (übergeordnete Sortierung)'");
		ElsIf SettingType = "OrderingItem" Then
			TableRow.Direction = DCItem.OrderType;
			AvailableField = AvailableFields.FindField(DCItem.Field);
			If AvailableField = Undefined Then
				TableRow.Presentation = ReportsClientServer.NameToPresentation(String(DCItem.Field));
			Else
				TableRow.Presentation = AvailableField.Title;
			EndIf;
		EndIf;
	EndDo;
	
	Return True;
EndFunction

&AtServer
Procedure RegisterParametersItems(Information)
	If OptionNodeChangeMode Then
		Return;
	EndIf;
	
	SearchConditions = New Structure("TreeRow, CollectionName", Information.CurrentTreeRow, "DataParameters");
	FoundItems = Information.OptionSettings.Rows.FindRows(SearchConditions, False);
	If FoundItems.Count() = 0 Then
		Return;
	EndIf;
	OptionsRowsSet = FoundItems[0].Rows;
	
	RowSection = Filters.GetItems().Add();
	RowSection.IsSection = True;
	RowSection.IsParameter = True;
	RowSection.Presentation = NStr("en = 'Parameters'; ru = 'Параметры';pl = 'Parametry';es_ES = 'Parámetros';es_CO = 'Parámetros';tr = 'Parametreler';it = 'Parametri';de = 'Parameter'");
	RowSection.PictureIndex = ReportsClientServer.PictureIndex("DataParameters");
	RowSection.DCID = "DataParameters";
	RowsSet = RowSection.GetItems();
	
	For Each OptionSettingsItem In OptionsRowsSet Do
		If Not OptionSettingsItem.OutputAllowed Then
			Continue;
		EndIf;
		
		AvailableDCSetting = OptionSettingsItem.AvailableDCSetting;
		DCItem = OptionSettingsItem.DCItem;
		
		If ValueIsFilled(AvailableDCSetting.Title) Then
			Presentation = AvailableDCSetting.Title;
		Else
			Presentation = String(DCItem.Parameter);
		EndIf;
		
		TableRow = RowsSet.Add();
		TableRow.Use   = DCItem.Use;
		TableRow.DCID = OptionSettingsItem.DCID;
		TableRow.Presentation   = Presentation;
		TableRow.IsParameter     = True;
		TableRow.PictureIndex  = -1;
		TableRow.ValueType     = AvailableDCSetting.ValueType;
		TableRow.ListInput     = OptionSettingsItem.ListInput;
		TableRow.OutputFlag  = OptionSettingsItem.OutputFlag;
		TableRow.ChoiceFoldersAndItems = OptionSettingsItem.ChoiceFoldersAndItems;
		
		SetValue(TableRow, AvailableDCSetting, DCItem, OptionSettingsItem.Value);
		
		If OptionSettingsItem.RestrictSelectionBySpecifiedValues
			AND TypeOf(OptionSettingsItem.ValuesForSelection) = Type("ValueList") Then
			If TableRow.ListInput Then
				If TypeOf(TableRow.Value) = Type("ValueList") Then
					For Each ListItem In TableRow.Value Do
						ItemForSelection = OptionSettingsItem.ValuesForSelection.FindByValue(ListItem.Value);
						If ItemForSelection <> Undefined Then
							ListItem.Presentation = ItemForSelection.Presentation;
						EndIf;
					EndDo;
				EndIf;
			Else
				TableRow.FixedSelectionList = True;
				ItemForSelection = OptionSettingsItem.ValuesForSelection.FindByValue(TableRow.Value);
				If ItemForSelection <> Undefined Then
					TableRow.ValuePresentation = ItemForSelection.Presentation;
				EndIf;
			EndIf;
		EndIf;
		
		OptionSettingsItem.IDInForm = TableRow.GetID();
		
		If TypeOf(TableRow.Value) = Type("StandardPeriod") Then
			TableRow.Condition = ReportsClientServer.GetStandardPeriodType(TableRow.Value);
			TableRow.ConditionType = New TypeDescription("EnumRef.AvailableReportPeriods");
		Else
			TableRow.ConditionType = New TypeDescription("Undefined");
		EndIf;
		
		TableRow.Title = Presentation;
		If ValueIsFilled(DCItem.UserSettingID) Then
			If ValueIsFilled(DCItem.UserSettingPresentation) Then
				TableRow.Title = DCItem.UserSettingPresentation;
			EndIf;
			If DCItem.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
				TableRow.AccessPictureIndex = 2;
			ElsIf DCItem.ViewMode = DataCompositionSettingsItemViewMode.Normal Then
				TableRow.AccessPictureIndex = 4;
			Else
				TableRow.AccessPictureIndex = 5;
			EndIf;
		Else
			TableRow.AccessPictureIndex = 5;
		EndIf;
		
		More = New Structure(
			"TypeDescription, QuickChoice, RestrictSelectionBySpecifiedValues,
			|ChoiceParameters, ChoiceForm, ValuesForSelection, ValuesForSelectionFilled");
		FillPropertyValues(More, OptionSettingsItem);
		If More.ValuesForSelectionFilled = Undefined Then
			More.ValuesForSelectionFilled = False;
		EndIf;
		TableRow.More = More;
		
	EndDo;
EndProcedure

&AtServer
Procedure RegisterFiltersItems(Information, OptionsRowsSet = Undefined, FormRowsSet = Undefined)
	If OptionsRowsSet = Undefined Then
		SearchConditions = New Structure("TreeRow, CollectionName", Information.CurrentTreeRow, "Filter");
		FoundItems = Information.OptionSettings.Rows.FindRows(SearchConditions, False);
		If FoundItems.Count() = 0 Then
			Return;
		EndIf;
		OptionsRowsSet = FoundItems[0].Rows;
	EndIf;
	If FormRowsSet = Undefined Then
		FormRowsSet = Filters.GetItems();
		RowSection = FormRowsSet.Add();
		RowSection.IsSection = True;
		RowSection.Presentation = NStr("en = 'Filters'; ru = 'Отборы';pl = 'Filtry';es_ES = 'Filtros';es_CO = 'Filtros';tr = 'Filtreler';it = 'Filtri';de = 'Filter'");
		RowSection.PictureIndex = ReportsClientServer.PictureIndex("Filters");
		RowSection.DCID = "Filters";
		FormRowsSet = RowSection.GetItems();
	EndIf;
	For Each OptionSettingsItem In OptionsRowsSet Do
		If OptionSettingsItem.Type = "FilterItemsGroup" Then
			IsFolder = True;
		ElsIf OptionSettingsItem.Type = "FilterItem" Then
			IsFolder = False;
		Else
			Continue;
		EndIf;
		
		DCItem = OptionSettingsItem.DCItem;
		
		TableRow = FormRowsSet.Add();
		TableRow.Use   = OptionSettingsItem.DCItem.Use;
		TableRow.Presentation   = OptionSettingsItem.DefaultPresentation;
		TableRow.Title       = OptionSettingsItem.Presentation;
		TableRow.DCID = OptionSettingsItem.DCID;
		TableRow.IsParameter     = False;
		TableRow.PictureIndex  = -1;
		TableRow.IsFolder       = IsFolder;
		TableRow.ListInput     = OptionSettingsItem.ListInput;
		TableRow.OutputFlag  = OptionSettingsItem.OutputFlag;
		TableRow.ChoiceForm          = OptionSettingsItem.ChoiceForm;
		TableRow.ChoiceFoldersAndItems = OptionSettingsItem.ChoiceFoldersAndItems;
		TableRow.TitleOverridden = (TableRow.Title <> TableRow.Presentation);
		
		OptionSettingsItem.IDInForm = TableRow.GetID();
		
		If ValueIsFilled(DCItem.UserSettingID) Then
			If DCItem.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
				TableRow.AccessPictureIndex = ?(OptionSettingsItem.OutputFlagOnly, 1, 2);
			ElsIf DCItem.ViewMode = DataCompositionSettingsItemViewMode.Normal Then
				TableRow.AccessPictureIndex = ?(OptionSettingsItem.OutputFlagOnly, 3, 4);
			Else
				TableRow.AccessPictureIndex = 5;
			EndIf;
		Else
			TableRow.AccessPictureIndex = 5;
		EndIf;
		
		If OptionSettingsItem.State = "DeletionMark" Then
			TableRow.PictureIndex = ReportsClientServer.PictureIndex("Error");
		EndIf;
		
		If IsFolder Then
			RegisterFiltersItems(Information, OptionSettingsItem.Rows, TableRow.GetItems());
		Else
			SetValue(TableRow, OptionSettingsItem.AvailableDCSetting, DCItem, OptionSettingsItem.Value);
			If OptionSettingsItem.RestrictSelectionBySpecifiedValues
				AND TypeOf(OptionSettingsItem.ValuesForSelection) = Type("ValueList") Then
				If TableRow.ListInput Then
					If TypeOf(TableRow.Value) = Type("ValueList") Then
						For Each ListItem In TableRow.Value Do
							ItemForSelection = OptionSettingsItem.ValuesForSelection.FindByValue(ListItem.Value);
							If ItemForSelection <> Undefined Then
								ListItem.Presentation = ItemForSelection.Presentation;
							EndIf;
						EndDo;
					EndIf;
				Else
					TableRow.FixedSelectionList = True;
					ItemForSelection = OptionSettingsItem.ValuesForSelection.FindByValue(TableRow.Value);
					If ItemForSelection <> Undefined Then
						TableRow.ValuePresentation = ItemForSelection.Presentation;
					EndIf;
				EndIf;
			EndIf;
			TableRow.ValueType = OptionSettingsItem.TypeDescription;
			If TypeOf(TableRow.Value) = Type("StandardPeriod") Then
				TableRow.Condition = ReportsClientServer.GetStandardPeriodType(TableRow.Value);
				TableRow.ConditionType = New TypeDescription("EnumRef.AvailableReportPeriods");
			Else
				TableRow.Condition = OptionSettingsItem.ComparisonType;
				TableRow.ConditionType = New TypeDescription("DataCompositionComparisonType");
			EndIf;
		EndIf;
		
		More = New Structure(
			"TypeDescription, QuickChoice, RestrictSelectionBySpecifiedValues,
			|ChoiceParameters, ChoiceForm, ValuesForSelection, ValuesForSelectionFilled");
		FillPropertyValues(More, OptionSettingsItem);
		If More.ValuesForSelectionFilled = Undefined Then
			More.ValuesForSelectionFilled = False;
		EndIf;
		TableRow.More = More;
		
	EndDo;
EndProcedure

&AtServer
Procedure RegisterLinksThatCanBeDisabled(Information)
	LinksThatCanBeDisabled.Clear();
	For Each LinkDetails In Information.LinksThatCanBeDisabled Do
		Link = LinksThatCanBeDisabled.Add();
		FillPropertyValues(Link, LinkDetails);
		If ExtendedMode = 1 Then
			Link.MainIDInForm     = LinkDetails.Master.IDInForm;
			Link.SubordinateIDInForm = LinkDetails.SubordinateSettingsItem.IDInForm;
		Else
			Link.MainIDInForm     = LinkDetails.Master.ItemID;
			Link.SubordinateIDInForm = LinkDetails.SubordinateSettingsItem.ItemID;
		EndIf;
	EndDo;
EndProcedure

&AtServer
Procedure RegisterAppearanceItems(Information, OptionsRowsSet = Undefined, FormRowsSet = Undefined)
	If OptionsRowsSet = Undefined Then
		SearchConditions = New Structure("TreeRow, CollectionName", Information.CurrentTreeRow, "ConditionalAppearance");
		FoundItems = Information.OptionSettings.Rows.FindRows(SearchConditions, False);
		If FoundItems.Count() = 0 Then
			Return;
		EndIf;
		OptionsRowsSet = FoundItems[0].Rows;
	EndIf;
	If FormRowsSet = Undefined Then
		FormRowsSet = Appearance.GetItems();
	EndIf;
	For Each OptionSettingsItem In OptionsRowsSet Do
		DCItem = OptionSettingsItem.DCItem;
		
		TableRow = FormRowsSet.Add();
		TableRow.Use   = DCItem.Use;
		TableRow.Presentation   = OptionSettingsItem.DefaultPresentation;
		TableRow.Title       = OptionSettingsItem.Presentation;
		TableRow.DCID = OptionSettingsItem.DCID;
		TableRow.PictureIndex  = -1;
		TableRow.TitleOverridden = (TableRow.Title <> TableRow.Presentation);
		
		If ValueIsFilled(DCItem.UserSettingID) Then
			If DCItem.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
				TableRow.AccessPictureIndex = 2;
			ElsIf DCItem.ViewMode = DataCompositionSettingsItemViewMode.Normal Then
				TableRow.AccessPictureIndex = 4;
			Else
				TableRow.AccessPictureIndex = 5;
			EndIf;
		Else
			TableRow.AccessPictureIndex = 5;
		EndIf;
		If OptionSettingsItem.State = "DeletionMark" Then
			TableRow.PictureIndex = ReportsClientServer.PictureIndex("Error");
		EndIf;
	EndDo;
EndProcedure

// Clear settings from non-existing fields.

&AtServerNoContext
Procedure ClearSettingsFromNonExistingFieldsAtServer(DCSettings)
	// ".Refresh(DataCompositionSettingsRefreshMethod.Complete)" method is not suitable for the following reasons:
	// 1. The goal is to remove (not just disable).
	// 2. Using this method leaves <Detailed records> groups with disabled unavailable fields.
	
	OutputConditions = New Structure;
	OutputConditions.Insert("UserSettingsOnly",      False);
	OutputConditions.Insert("QuickOnly",               False);
	OutputConditions.Insert("CurrentDCNodeID", Undefined);
	
	Information = ReportsServer.AdvancedInformationOnSettings(
		New Structure("Settings, UserSettings", DCSettings, New DataCompositionUserSettings),
		ReportsClientServer.GetDefaultReportSettings(),
		Undefined,
		OutputConditions);
	
	FoundItems = Information.OptionTree.Rows.FindRows(New Structure("State", "DeletionMark"), True);
	For Each TreeRow In FoundItems Do
		DCOptionSetting = TreeRow.DCNode;
		If TreeRow.Type = "Group"
			Or TreeRow.Type = "TableGroup"
			Or TreeRow.Type = "ChartGroup" Then
			DCGroupFields = DCOptionSetting.GroupFields;
			AvailableDCFields = DCGroupFields.GroupFieldsAvailableFields;
			Count = DCGroupFields.Items.Count();
			ReverseIndex = Count;
			While ReverseIndex > 0 Do
				ReverseIndex = ReverseIndex - 1;
				DCGroupField = DCGroupFields.Items[ReverseIndex];
				If TypeOf(DCGroupField) = Type("DataCompositionGroupField")
					AND AvailableDCFields.FindField(DCGroupField.Field) = Undefined Then
					Count = Count - 1;
					DCGroupFields.Items.Delete(DCGroupField);
				EndIf;
			EndDo;
			If Count > 0 Then
				Continue; // Group has fields that are not marked.
			EndIf;
		EndIf;
		
		// Move subordinate items to the same level as the item to be removed.
		RootRow = TreeRow;
		While RootRow.Type <> "Settings" Do
			RootRow = RootRow.Parent;
		EndDo;
		For Each SubordinateTreeRow In TreeRow.Rows Do
			MovingLinkedRows(Information.OptionTree, RootRow.DCNode, SubordinateTreeRow, TreeRow.Parent, TreeRow);
		EndDo;
		
		// Delete a DC item.
		DCParentRows = GetDCItems(DCSettings, TreeRow.Parent.DCNode);
		DCParentRows.Delete(TreeRow.DCNode);
	EndDo;
	
	FoundItems = Information.OptionSettings.Rows.FindRows(New Structure("State", "DeletionMark"), True);
	For Each TreeRow In FoundItems Do
		If TreeRow.Parent = Undefined Then
			Continue; // Root collections (such as "Settings.Filter") cannot be removed.
		EndIf;
		DCNode = TreeRow.Owner.DCItem;
		DCParent = TreeRow.Parent.DCItem;
		DCParentRows = GetDCItems(DCNode, DCParent);
		DCParentRows.Delete(TreeRow.DCItem);
	EndDo;
	
	ReportsServer.ClearAdvancedInformationOnSettings(Information);
	
EndProcedure

&AtClientAtServerNoContext
Function MovingLinkedRows(Collection, DCNode, Val TreeItem, Val NewParent,
	Val PasteBeforeWhat = Undefined, Val Index = Undefined, Val DCIndex = Undefined)
	Result = New Structure("TreeItem, DCItem, IndexOf, DCIndex");
	
	AddToEnd = (NewParent = Undefined);
	WhereToPaste = ?(NewParent = Undefined, Collection.Rows, NewParent.Rows);
	If PasteBeforeWhat = Undefined Then
		IsSection = CommonClientServer.StructureProperty(NewParent, "IsSection");
		IsFolder = CommonClientServer.StructureProperty(NewParent, "IsFolder");
		If IsSection <> True AND IsFolder <> True Then // To the same level as the parent.
			PasteBeforeWhat = NewParent;
			NewParent = ?(NewParent.Parent = Undefined, Collection, NewParent.Parent);
			WhereToPaste = ?(NewParent = Undefined, Collection.Rows, NewParent.Rows);
		EndIf;
	EndIf;
	
	DCItem          = FindDCObject(DCNode, TreeItem);
	NewDCParent    = FindDCObject(DCNode, NewParent);
	WhereToPasteDC     = GetDCItems(DCNode, NewDCParent);
	PasteDCBeforeWhat = FindDCObject(DCNode, PasteBeforeWhat);
	
	PreviousParent    = ?(TreeItem.Parent = Undefined, Collection, TreeItem.Parent);
	MoveFromWhere = ?(PreviousParent = Undefined, Collection.Rows, PreviousParent.Rows);
	
	OldDCParent    = FindDCObject(DCNode, PreviousParent);
	MoveDCFromWhere = GetDCItems(DCNode, OldDCParent);
	
	If DCItem = PasteDCBeforeWhat Then
		Result.DCItem     = DCItem;
		Result.TreeItem = TreeItem;
	Else
		If Index = Undefined Or DCIndex = Undefined Then
			If PasteDCBeforeWhat = Undefined Then
				If AddToEnd Then
					Index   = WhereToPaste.Count();
					DCIndex = WhereToPasteDC.Count();
				Else
					Index   = 0;
					DCIndex = 0;
				EndIf;
			Else
				Index   = WhereToPaste.IndexOf(PasteBeforeWhat);
				DCIndex = WhereToPasteDC.IndexOf(PasteDCBeforeWhat);
				If PreviousParent = NewParent Then
					OldIndex = MoveFromWhere.IndexOf(TreeItem);
					If OldIndex <= Index Then
						Index   = Index + 1;
						DCIndex = DCIndex + 1;
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
		SearchDCItems = New Map;
		Result.DCItem = ReportsClientServer.CopyRecursive(DCNode, DCItem, WhereToPasteDC, DCIndex, SearchDCItems);
		
		SearchTableRows = New Map;
		Result.TreeItem = ReportsClientServer.CopyRecursive(Undefined, TreeItem, WhereToPaste, Index, SearchTableRows);
		
		For Each KeyAndValue In SearchTableRows Do
			OldRow = KeyAndValue.Key;
			NewRow = KeyAndValue.Value;
			NewRow.DCID = SearchDCItems.Get(OldRow.DCID);
		EndDo;
		
		MoveFromWhere.Delete(TreeItem);
		MoveDCFromWhere.Delete(DCItem);
	EndIf;
	
	Result.IndexOf   = WhereToPaste.IndexOf(Result.TreeItem);
	Result.DCIndex = WhereToPasteDC.IndexOf(Result.DCItem);
	
	Return Result;
EndFunction

&AtServer
Procedure ParameterChangeAtServer(ItemID)
	
	DCID = QuickSearchForUserSettings.Get(ItemID);
	
	DCUserSetting = Report.SettingsComposer.UserSettings.GetObjectByID(DCID);
	
	ManagerModule = Reports[ReportName];

	ManagerModule.ReportSettingsFormParameterOnChange(ThisObject, DCUserSetting);
	
	SetSettings();

EndProcedure

&AtClient
Procedure AccountingGroupingTableBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	Cancel = True;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("Account"					, ReportSettings.TemporaryParameters.Account);
	ChoiceFormParameters.Insert("FillExtDimensionsByAccount", True);
	ChoiceFormParameters.Insert("AttributeName"				, NStr("en = 'field'; ru = 'поле';pl = 'pole';es_ES = 'campo';es_CO = 'campo';tr = 'alan';it = 'campo';de = 'Feld'"));
	ChoiceFormParameters.Insert("AttributeID"				, "Field");
	
	AdditionalParameters = New Structure;
	
	AdditionalParameters.Insert("Table", "AccountingGroupingTable");
	
	ParametersChoiceNotification = New NotifyDescription("AttributesChoiceEnding", ThisObject, AdditionalParameters);
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		ParametersChoiceNotification,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure AccountingGroupingTableSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "AccountingGroupingTableField"
		OR Field.Name = "AccountingGroupingTableFieldPresentation" Then
		
		ChoiceFormParameters = New Structure;
		ChoiceFormParameters.Insert("Account"					, ReportSettings.TemporaryParameters.Account);
		ChoiceFormParameters.Insert("FillExtDimensionsByAccount", True);
		ChoiceFormParameters.Insert("AttributeName"				, NStr("en = 'field'; ru = 'поле';pl = 'pole';es_ES = 'campo';es_CO = 'campo';tr = 'alan';it = 'campo';de = 'Feld'"));
		ChoiceFormParameters.Insert("AttributeID"				, "Field");
		
		AdditionalParameters = New Structure;
		
		AdditionalParameters.Insert("Table", "AccountingGroupingTable");
		
		ParametersChoiceNotification = New NotifyDescription("AttributesChoiceEnding", ThisObject, AdditionalParameters);
		
		OpenForm("CommonForm.ArbitraryParametersChoiceForm",
			ChoiceFormParameters,
			ThisObject,
			,
			,
			,
			ParametersChoiceNotification,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AttributesChoiceEnding(Result, AdditionalParameters) Export

	If TypeOf(Result) = Type("Structure")
		And AdditionalParameters.Table = "AccountingGroupingTable" Then
	
		FoundRows = AccountingGroupingTable.FindRows(New Structure("Field", Result.Field));
		
		If FoundRows.Count() > 0 Then
			For Each Row In FoundRows Do
				
				Row.Use = True;
				
			EndDo;
		Else
			
			NewRow = AccountingGroupingTable.Add();
			
			NewRow.Use				 = True;
			NewRow.Field			 = Result.Field;
			NewRow.FieldPresentation = Result.Synonym;
			NewRow.GroupingType	 = 0;
			
		EndIf;
		
		SetSettings();
		
	ElsIf TypeOf(Result) = Type("Structure")
		And AdditionalParameters.Table = "AccountingGroupingByAnalyticalDimensionTypesTable" Then
		
		If AdditionalParameters.Property("CurrentData") Then
			
			NewRow = AdditionalParameters.CurrentData;
			
			NewRow.Use				 = True;
			NewRow.Field			 = Result.Field;
			NewRow.FieldPresentation = Result.Synonym;
			NewRow.GroupingType		 = 0;
			NewRow.LinkField		 = GetAnalyticalDimensionTypeRefByCode(Result.Field);
			
		Else
			
			FoundRows = AccountingGroupingByAnalyticalDimensionTypesTable.FindRows(New Structure("Field", Result.Field));
			
			If FoundRows.Count() > 0 Then
				For Each Row In FoundRows Do
					
					Row.Use = True;
					
				EndDo;
			Else
				
				NewRow = AccountingGroupingByAnalyticalDimensionTypesTable.Add();
				
				NewRow.Use				 = True;
				NewRow.Field			 = Result.Field;
				NewRow.FieldPresentation = Result.Synonym;
				NewRow.GroupingType		 = 0;
				NewRow.LinkField		 = GetAnalyticalDimensionTypeRefByCode(Result.Field);
				
			EndIf;
			
		EndIf;
		
		SetSettings();
		
	Else
		
	EndIf;
	
EndProcedure

&AtServer
Function GetAnalyticalDimensionTypeRefByCode(Field)
	
	Code = StrSplit(Field, ".")[0];
	
	Return ChartsOfCharacteristicTypes.ManagerialAnalyticalDimensionTypes.FindByCode(Code);
	
EndFunction

&AtServer
Procedure SetSettings()
	
	ManagerModule = Reports[ReportName];

	ManagerModule.SetGroupingSettings(ThisObject);
	
	ReportSettings.SchemaModified = True;
	
	UserSettingsModified = True;
	OptionChanged = True;
	
EndProcedure

&AtServer
Procedure SetReportSettings()
	
	ManagerModule = Reports[ReportName];

	ManagerModule.SetReportSettings(ThisObject);
	
	ReportSettings.SchemaModified = True;
	
EndProcedure

&AtClient
Procedure AccountingGroupingTableOnChange(Item)
	SetSettings();
EndProcedure

&AtServer
Procedure SetAccountingConditionalAppearance(TableName)
	
	FormattedFieldField = StrTemplate("%1GroupingType", TableName);
	DataFilterItemLeftValue = StrTemplate("%1.GroupingType", TableName);
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField(DataFilterItemLeftValue);
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = 0;
	DataFilterItem.Use = True;
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("Text");
	AppearanceColorItem.Value = NStr("en = 'Without groups'; ru = 'Без групп';pl = 'Bez grup';es_ES = 'Sin grupos';es_CO = 'Sin grupos';tr = 'Gruplar olmadan';it = 'Senza gruppi';de = 'Ohne Gruppen'"); 
	AppearanceColorItem.Use = True;
	
	FormattedField = ConditionalAppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField(FormattedFieldField);
	FormattedField.Use = True;
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField(DataFilterItemLeftValue);
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = 1;
	DataFilterItem.Use = True;
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("Text");
	AppearanceColorItem.Value = NStr("en = 'With groups'; ru = 'С группами';pl = 'Z grupami';es_ES = 'Con grupos';es_CO = 'Con grupos';tr = 'Gruplar ile';it = 'Con gruppi';de = 'Mit Gruppen'"); 
	AppearanceColorItem.Use = True;
	
	FormattedField = ConditionalAppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField(FormattedFieldField);
	FormattedField.Use = True;
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField(DataFilterItemLeftValue);
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = 2;
	DataFilterItem.Use = True;
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("Text");
	AppearanceColorItem.Value = NStr("en = 'Only groups'; ru = 'Только группы';pl = 'Tylko grupy';es_ES = 'Sólo grupos';es_CO = 'Sólo grupos';tr = 'Sadece gruplar';it = 'Solo gruppi';de = 'Nur Gruppen'"); 
	AppearanceColorItem.Use = True;
	
	FormattedField = ConditionalAppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField(FormattedFieldField);
	FormattedField.Use = True;
	
	
EndProcedure

&AtClient
Procedure SettingsComposerSettingsFilterOnChange(Item)
	
	UserSettingsModified = True;
	OptionChanged = True;
	Items.SettingsComposerSettingsFilterGroupFilterItems.Enabled = Report.SettingsComposer.Settings.Filter.Items.Count() > 0;
	
EndProcedure

&AtServer
Procedure BySubaccountsOnChangeAtServer()
	
	ManagerModule = Reports[ReportName];

	ManagerModule.SetFilterBySubaccounts(ThisObject);
			
	ReportSettings.SchemaModified = True;
	
	UserSettingsModified = True;
	OptionChanged = True;
	
EndProcedure

&AtClient
Procedure BySubaccountsOnChange(Item)
	BySubaccountsOnChangeAtServer();
EndProcedure

&AtServer
Procedure ItemPresentationCurrencyOnChangeAtServer()
	
	ManagerModule = Reports[ReportName];

	ManagerModule.PresentationCurrencyOnChange(ThisObject);
			
	ReportSettings.SchemaModified = True;
		
	UserSettingsModified = True;
	OptionChanged = True;
	
EndProcedure

&AtClient
Procedure ItemPresentationCurrencyOnChange(Item)
	ItemPresentationCurrencyOnChangeAtServer();
EndProcedure

&AtServer
Procedure ItemCurrencyAmountOnChangeAtServer()
	
	ManagerModule = Reports[ReportName];

	ManagerModule.CurrencyAmountOnChange(ThisObject);
			
	ReportSettings.SchemaModified = True;
		
	UserSettingsModified = True;
	OptionChanged = True;
	
EndProcedure

&AtClient
Procedure ItemCurrencyAmountOnChange(Item)
	ItemCurrencyAmountOnChangeAtServer();
EndProcedure

&AtServer
Procedure ItemQuantityOnChangeAtServer()
	
	ManagerModule = Reports[ReportName];

	ManagerModule.QuantityOnChange(ThisObject);
			
	ReportSettings.SchemaModified = True;
		
	UserSettingsModified = True;
	OptionChanged = True;
	
EndProcedure

&AtClient
Procedure ItemQuantityOnChange(Item)
	ItemQuantityOnChangeAtServer();
EndProcedure

&AtServer
Procedure ItemReportTitleOnChangeOnChangeAtServer()
	
	ManagerModule = Reports[ReportName];

	ManagerModule.ReportTitleOnChange(ThisObject);
			
	ReportSettings.SchemaModified = True;
		
	UserSettingsModified = True;
	OptionChanged = True;
	
EndProcedure

&AtClient
Procedure ItemReportTitleOnChange(Item)
	ItemReportTitleOnChangeOnChangeAtServer();
EndProcedure

&AtServer
Procedure ItemDisplayParametersAndFiltersOnChangeAtServer()
	
	ManagerModule = Reports[ReportName];

	ManagerModule.DisplayParametersAndFiltersOnChange(ThisObject);
			
	ReportSettings.SchemaModified = True;
		
	UserSettingsModified = True;
	OptionChanged = True;
	
EndProcedure

&AtClient
Procedure ItemDisplayParametersAndFiltersOnChange(Item)
	ItemDisplayParametersAndFiltersOnChangeAtServer();
EndProcedure

&AtServer
Procedure ItemAccountNameOnChangeAtServer()
	
	ManagerModule = Reports[ReportName];

	ManagerModule.AccountNameOnChange(ThisObject);
			
	ReportSettings.SchemaModified = True;
		
	UserSettingsModified = True;
	OptionChanged = True;
	
EndProcedure

&AtClient
Procedure ItemAccountNameOnChange(Item)
	ItemAccountNameOnChangeAtServer();
EndProcedure

&AtServer
Procedure ItemDetailedBalanceOnChangeAtServer()
	
	ManagerModule = Reports[ReportName];

	ManagerModule.DetailedBalanceOnChange(ThisObject);
			
	ReportSettings.SchemaModified = True;
		
	UserSettingsModified = True;
	OptionChanged = True;
	
EndProcedure

&AtClient
Procedure ItemDetailedBalanceOnChange(Item)
	ItemDetailedBalanceOnChangeAtServer();
EndProcedure

&AtServer
Procedure ItemHighlightNegativeValuesOnChangeAtServer()
	
	ManagerModule = Reports[ReportName];

	ManagerModule.HighlightNegativeValuesOnChange(ThisObject);
			
	ReportSettings.SchemaModified = True;
		
	UserSettingsModified = True;
	OptionChanged = True;
	
EndProcedure

&AtClient
Procedure ItemHighlightNegativeValuesOnChange(Item)
	ItemHighlightNegativeValuesOnChangeAtServer();
EndProcedure

&AtClient
Procedure AccountingGroupingByAccountsTableExtDimensionsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.AccountingGroupingByAccountsTable.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	
	AdditionalParameters.Insert("TableName", "AccountingGroupingByAccountsTable");
	
	NotifyDescription = New NotifyDescription("ExtDimensionsStartChoiceEnd", ThisObject, AdditionalParameters);
	
	FormParameters = New Structure("ValueList", CurrentData.ExtDimensions);
	FormParameters.Insert("Title", NStr("en = 'Select analytical dimensions'; ru = 'Укажите аналитические измерения';pl = 'Wybierz wymiary analityczne';es_ES = 'Seleccionar las dimensiones analíticas';es_CO = 'Seleccionar las dimensiones analíticas';tr = 'Analitik boyutları seç';it = 'Selezionare dimensioni analitiche';de = 'Analytische Messungen auswählen'"));
	
	OpenForm("CommonForm.SelectValueListItems",
		FormParameters, Item, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow); 
	
EndProcedure

&AtClient
Procedure ExtDimensionsStartChoiceEnd(Result, AdditionalParameters) Export 
	
	Var TableName;
	
	AdditionalParameters.Property("TableName", TableName);
	
	If Not ValueIsFilled(TableName) Then
		Return;
	EndIf;
	
	CurrentData = Items[TableName].CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Result <> Undefined Then
		
		CurrentData.ExtDimensions				= Result;
		CurrentData.ExtDimensionsPresentation	= GetExtDimensionsPresentation(Result, True);
		
	EndIf;
	
	SetSettings();
	
EndProcedure

&AtServerNoContext
Function GetExtDimensionsList(Account)
	
	ExtDimensionsList = New ValueList;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	MasterChartOfAccountsAnalyticalDimensions.Ref AS Ref,
		|	MasterChartOfAccountsAnalyticalDimensions.LineNumber AS LineNumber,
		|	MasterChartOfAccountsAnalyticalDimensions.AnalyticalDimension AS AnalyticalDimension
		|FROM
		|	ChartOfAccounts.MasterChartOfAccounts.AnalyticalDimensions AS MasterChartOfAccountsAnalyticalDimensions
		|WHERE
		|	MasterChartOfAccountsAnalyticalDimensions.Ref = &Account";
	
	Query.SetParameter("Account", Account);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		ExtDimensionsList.Add(SelectionDetailRecords.AnalyticalDimension,,True);
	EndDo;
	
	Return ExtDimensionsList;
	
EndFunction

&AtClient
Procedure AccountingGroupingByAccountsTableAccountOnChange(Item)
	
	CurrentData = Items.AccountingGroupingByAccountsTable.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	RowID = AccountingGroupingByAccountsTable.IndexOf(CurrentData);
	
	If CurrentData.Use
		And ValueIsFilled(CurrentData.Account)
		And CheckAccountsHierarchy(
			CurrentData.Account,
			RowID,
			"AccountingGroupingByAccountsTable",
			False) Then
		
		CurrentData.Use = False;
		
	EndIf;
	
	CurrentGroupingAccount = CurrentData.Account;
	
	CurrentData.ExtDimensions				= GetExtDimensionsList(CurrentData.Account);
	CurrentData.ExtDimensionsPresentation	= GetExtDimensionsPresentation(CurrentData.ExtDimensions);
	
EndProcedure

&AtClient
Function GetExtDimensionsPresentation(ExtDimensions, CheckFlag = False)
	
	ExtDimensionsPresentation	= "";
	For Each Item In ExtDimensions Do
		
		If Not CheckFlag Or Item.Check Then
			ExtDimensionsPresentation = StrTemplate("%1 %2;", ExtDimensionsPresentation, Item.Value);
		EndIf;
		
	EndDo;
	
	Return Mid(ExtDimensionsPresentation, 2);
	
EndFunction

&AtServer
Procedure PeriodicityOnChangeAtServer()
	
	ManagerModule = Reports[ReportName];
	
	ManagerModule.PeriodicityOnChange(ThisObject);
	
	ReportSettings.SchemaModified = True;
	
	FillingParameters = New Structure;
	FillingParameters.Insert("UpdateOptionSettings", True);
	QuickSettingsFill(FillingParameters);
	
	UserSettingsModified = True;
	OptionChanged = True;
	
EndProcedure

&AtClient
Procedure PeriodicityOnChange(Item)
	PeriodicityOnChangeAtServer();
EndProcedure

&AtClient
Procedure DetailedBalanceTableOnChange(Item)
	ItemDetailedBalanceOnChangeAtServer();
EndProcedure

&AtClient
Procedure DetailedBalanceTableAccountOnChange(Item)
	
	CurrentData = Items.DetailedBalanceTable.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;	
	
	CurrentData.ExtDimensions				= GetExtDimensionsList(CurrentData.Account);
	CurrentData.ExtDimensionsPresentation	= GetExtDimensionsPresentation(CurrentData.ExtDimensions);
	
EndProcedure

&AtClient
Procedure DetailedBalanceTableExtDimensionsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.DetailedBalanceTable.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	
	AdditionalParameters.Insert("TableName", "DetailedBalanceTable");
	
	NotifyDescription = New NotifyDescription("ExtDimensionsStartChoiceEnd", ThisObject, AdditionalParameters); 
	
	FormParameters = New Structure("ValueList", CurrentData.ExtDimensions);
	FormParameters.Insert("Title", NStr("en = 'Select analytical dimensions'; ru = 'Укажите аналитические измерения';pl = 'Wybierz wymiary analityczne';es_ES = 'Seleccionar las dimensiones analíticas';es_CO = 'Seleccionar las dimensiones analíticas';tr = 'Analitik boyutları seç';it = 'Selezionare dimensioni analitiche';de = 'Analytische Messungen auswählen'"));
	
	OpenForm("CommonForm.SelectValueListItems",
		FormParameters, Item, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow); 
	
EndProcedure

&AtClient
Procedure TypesStartChoiceEnd(Result, AdditionalParameters) Export
	CurrentData = Items.AccountingGroupingByAccountsTable.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;	
	
	If Result <> Undefined Then
		CurrentData.ExtDimensions = Result;	
	EndIf;
	
EndProcedure

&AtServer
Procedure ByBalancedSubaccountsOnChangeAtServer()
	
	ManagerModule = Reports[ReportName];

	ManagerModule.SetFilterByBalancedSubaccounts(ThisObject);
	
	ReportSettings.SchemaModified = True;
	
	UserSettingsModified = True;
	OptionChanged = True;
	
EndProcedure

&AtClient
Procedure ByBalancedSubaccountsOnChange(Item)
	ByBalancedSubaccountsOnChangeAtServer();
EndProcedure

&AtClient
Procedure AccountingGroupingByBalancedAccountsTableOnChange(Item)
	SetSettings();
EndProcedure

&AtClient
Procedure AccountingGroupingByBalancedAccountsTableAccountOnChange(Item)
	
	CurrentData = Items.AccountingGroupingByBalancedAccountsTable.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentData.ExtDimensions = GetExtDimensionsList(CurrentData.Account);
	CurrentData.ExtDimensionsPresentation	= GetExtDimensionsPresentation(CurrentData.ExtDimensions);
	
EndProcedure

&AtClient
Procedure AccountingGroupingByBalancedAccountsTableExtDimensionsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.AccountingGroupingByBalancedAccountsTable.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	
	AdditionalParameters.Insert("TableName", "AccountingGroupingByBalancedAccountsTable");
	
	NotifyDescription = New NotifyDescription("ExtDimensionsStartChoiceEnd", ThisObject, AdditionalParameters);
	
	FormParameters = New Structure("ValueList", CurrentData.ExtDimensions);
	FormParameters.Insert("Title", NStr("en = 'Select ext dimensions'; ru = 'Укажите субконто';pl = 'Wybierz wymiary zewnętrzne';es_ES = 'Seleccionar las dimensiones externas';es_CO = 'Seleccionar las dimensiones externas';tr = 'Ek boyut seç';it = 'Selezionare dimensioni esterne';de = 'Externe Messungen auswählen'"));
	
	OpenForm("CommonForm.SelectValueListItems",
		FormParameters, Item, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow); 
	
EndProcedure

&AtClient
Procedure AnalyticalDimensionTypesTableAnalyticalDimensionTypeOnChange(Item)
	
	CurrentData = Items.AnalyticalDimensionTypesTable.CurrentData;
	
	If ValueIsFilled(AnalyticalDimensionTypeCurrent) 
		And AnalyticalDimensionTypeCurrent <> CurrentData.AnalyticalDimensionType Then
		RemoveDataFromAccountingGroupingByAnalyticalDimensionTypesTable(AnalyticalDimensionTypeCurrent);
	ElsIf AnalyticalDimensionTypeCurrent = CurrentData.AnalyticalDimensionType Then
		Return;
	EndIf;
	
	If ValueIsFilled(CurrentData.AnalyticalDimensionType) Then
		
		Filter = New Structure;
		Filter.Insert("AnalyticalDimensionType", CurrentData.AnalyticalDimensionType);
		
		FoundRows = AnalyticalDimensionTypesTable.FindRows(Filter);
		
		If FoundRows.Count() = 2 Then
			CurrentData.AnalyticalDimensionType = AnalyticalDimensionTypeCurrent;
			Return;
		EndIf;
		
		Filter = New Structure;
		Filter.Insert("LinkField", CurrentData.AnalyticalDimensionType);
		
		FoundRows = AccountingGroupingByAnalyticalDimensionTypesTable.FindRows(Filter);
		
		If FoundRows.Count() = 0 Then
			
			NewRow = AccountingGroupingByAnalyticalDimensionTypesTable.Add();
			NewRow.Use				 = True;
			NewRow.FieldPresentation = String(CurrentData.AnalyticalDimensionType);
			NewRow.Field			 = GetCodeByRef(CurrentData.AnalyticalDimensionType);
			NewRow.LinkField		 = CurrentData.AnalyticalDimensionType;
			NewRow.GroupingType		 = 0;
			
			AnalyticalDimensionTypesOrder.Add(CurrentData.AnalyticalDimensionType);
			
		Else
			
			CurrentData.AnalyticalDimensionType = Undefined;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Function GetCodeByRef(Ref)
	Return Ref.Code;
EndFunction

&AtClient
Procedure RemoveDataFromAccountingGroupingByAnalyticalDimensionTypesTable(CurrentDataAnalyticalDimensionType)
	
	Filter = New Structure;
	Filter.Insert("LinkField", CurrentDataAnalyticalDimensionType);
	
	FoundRows = AccountingGroupingByAnalyticalDimensionTypesTable.FindRows(Filter);
	
	For Each Row In FoundRows Do
		
		AccountingGroupingByAnalyticalDimensionTypesTable.Delete(Row);
		
	EndDo;
	
	OrderItem = AnalyticalDimensionTypesOrder.FindByValue(CurrentDataAnalyticalDimensionType);
	AnalyticalDimensionTypesOrder.Delete(OrderItem);
	
EndProcedure

&AtClient
Procedure AnalyticalDimensionTypesTableBeforeDeleteRow(Item, Cancel)
	
	CurrentData = Items.AnalyticalDimensionTypesTable.CurrentData;
	
	If ValueIsFilled(CurrentData.AnalyticalDimensionType) Then
		RemoveDataFromAccountingGroupingByAnalyticalDimensionTypesTable(CurrentData.AnalyticalDimensionType);
	EndIf;
	
EndProcedure

&AtClient
Procedure AnalyticalDimensionTypesTableOnChange(Item)
	
	NeedToOrder = CheckOrderInAnalyticalDimensionTypesTable();
	
	If NeedToOrder Then
		
		RowsArray = New Array;
		AnalyticalDimensionTypesOrder.Clear();
		For Each Row In AnalyticalDimensionTypesTable Do
			
			AnalyticalDimensionTypesOrder.Add(Row.AnalyticalDimensionType);
			
			Filter = New Structure;
			Filter.Insert("LinkField", Row.AnalyticalDimensionType);
			
			FoundRows = AccountingGroupingByAnalyticalDimensionTypesTable.FindRows(Filter);
			
			RowsArray.Add(FoundRows);
			
		EndDo;
		
		RowsToDelete = AccountingGroupingByAnalyticalDimensionTypesTable.FindRows(New Structure);
		
		For Each RowArray In RowsArray Do
			
			For Each Row In RowArray Do
				
				NewRow = AccountingGroupingByAnalyticalDimensionTypesTable.Add();
				FillPropertyValues(NewRow, Row);
				AccountingGroupingByAnalyticalDimensionTypesTable.Delete(Row);
				
			EndDo;
			
		EndDo;
		
	EndIf;
	
	SetSettings();
	
EndProcedure

&AtClient
Function CheckOrderInAnalyticalDimensionTypesTable()
	
	Result = False;
	
	Count = 0;
	For Each Row In AnalyticalDimensionTypesTable Do
		
		If ValueIsFilled(Row.AnalyticalDimensionType)
			And Row.AnalyticalDimensionType <> AnalyticalDimensionTypesOrder[Count].Value Then
			Result = True;
			Break;
		EndIf;
		
		Count = Count + 1;
		
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Procedure AnalyticalDimensionTypesTableBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	If AnalyticalDimensionTypesTable.Count() = 4 Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Maximum 4 analytical dimension types allowed!'; ru = 'Допускается не более 4 типов аналитических измерений!';pl = 'Maksymalnie są dostępne 4 typy wymiarów analitycznych!';es_ES = 'Se permite un máximo de 4 tipos de dimensiones analíticas.';es_CO = 'Se permite un máximo de 4 tipos de dimensiones analíticas.';tr = 'En fazla 4 analitik boyut türüne izin verilir!';it = 'Sono concesse massimo 4 tipi di dimensioni analitiche!';de = 'Maximum 4 Typen von analytischer Messung sind gestattet! '"), , , , Cancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AnalyticalDimensionTypesTableAnalyticalDimensionTypeStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentData = Items.AnalyticalDimensionTypesTable.CurrentData;
	AnalyticalDimensionTypeCurrent = CurrentData.AnalyticalDimensionType;
	
EndProcedure

&AtClient
Procedure AccountingGroupingByAnalyticalDimensionTypesTableSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "AccountingGroupingByAnalyticalDimensionTypesTableFieldPresentation" Then
		
		StandardProcessing = False;
		
		ChoiceFormParameters = New Structure;
		SetChoiceFormParameters(ChoiceFormParameters);
		ChoiceFormParameters.Insert("AttributeName", NStr("en = 'field'; ru = 'поле';pl = 'pole';es_ES = 'campo';es_CO = 'campo';tr = 'alan';it = 'campo';de = 'Feld'"));
		ChoiceFormParameters.Insert("AttributeID", "Field");
		
		AdditionalParameters = New Structure;
		
		AdditionalParameters.Insert("Table"			, "AccountingGroupingByAnalyticalDimensionTypesTable");
		AdditionalParameters.Insert("CurrentData"	, Items.AccountingGroupingByAnalyticalDimensionTypesTable.CurrentData);
		
		ParametersChoiceNotification = New NotifyDescription("AttributesChoiceEnding", ThisObject, AdditionalParameters);
		
		OpenForm("CommonForm.ArbitraryParametersChoiceForm",
			ChoiceFormParameters,
			ThisObject,
			,
			,
			,
			ParametersChoiceNotification,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetChoiceFormParameters(ChoiceFormParameters)
	
	ChoiceFormParameters.Insert("DimensionsArray" , GetAnalyticalDimensionTypesArray());
	ChoiceFormParameters.Insert("AdditionalArray" , GetAdditionalTypesArray());
	ChoiceFormParameters.Insert("FillExtDimensions" , True);
	
EndProcedure

&AtServer
Function GetAnalyticalDimensionTypesArray()
	
	Return AnalyticalDimensionTypesTable.Unload().UnloadColumn("AnalyticalDimensionType");
	
EndFunction

&AtServer
Function GetAdditionalTypesArray()
	
	ResultArray = New Array;
	
	NewElement = New Structure;
	NewElement.Insert("Name"		, "Company");
	NewElement.Insert("Type"		, New TypeDescription("CatalogRef.Companies"));
	NewElement.Insert("Presentation", NStr("en = 'Company'; ru = 'Организация';pl = 'Firma';es_ES = 'Empresa';es_CO = 'Empresa';tr = 'İş yeri';it = 'Azienda';de = 'Firma'"));
	ResultArray.Add(NewElement);
	
	NewElement = New Structure;
	NewElement.Insert("Name"		, "Currency");
	NewElement.Insert("Type"		, New TypeDescription("CatalogRef.Currencies"));
	NewElement.Insert("Presentation", NStr("en = 'Currency'; ru = 'Валюта';pl = 'Waluta';es_ES = 'Moneda';es_CO = 'Moneda';tr = 'Para birimi';it = 'Valuta';de = 'Währung'"));
	ResultArray.Add(NewElement);
	
	NewElement = New Structure;
	NewElement.Insert("Name"		, "TypesOfAccounting");
	NewElement.Insert("Type"		, New TypeDescription("CatalogRef.TypesOfAccounting"));
	NewElement.Insert("Presentation", NStr("en = 'Types of accounting'; ru = 'Типы бухгалтерского учета';pl = 'Typy rachunkowości';es_ES = 'Tipos de contabilidad';es_CO = 'Tipos de contabilidad';tr = 'Muhasebe türleri';it = 'Tipi di contabilità';de = 'Typen der Buchhaltung'"));
	ResultArray.Add(NewElement);
	
	Return ResultArray;
	
EndFunction

&AtClient
Procedure AccountingGroupingByAnalyticalDimensionTypesTableBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	Cancel = True;
	
	ChoiceFormParameters = New Structure;
	SetChoiceFormParameters(ChoiceFormParameters);
	ChoiceFormParameters.Insert("AttributeName", NStr("en = 'field'; ru = 'поле';pl = 'pole';es_ES = 'campo';es_CO = 'campo';tr = 'alan';it = 'campo';de = 'Feld'"));
	ChoiceFormParameters.Insert("AttributeID", "Field");
	
	AdditionalParameters = New Structure;
	
	AdditionalParameters.Insert("Table", "AccountingGroupingByAnalyticalDimensionTypesTable");
	
	ParametersChoiceNotification = New NotifyDescription("AttributesChoiceEnding", ThisObject, AdditionalParameters);
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		ParametersChoiceNotification,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure SettingsComposerSettingsFilterOnActivateRow(Item)
	
	IsDataCompositionFilterCurrentRow	= False;
	IsDataCompositionFilterSelected		= False;
	
	If TypeOf(Report.SettingsComposer.Settings.Filter.GetObjectByID(Items.SettingsComposerSettingsFilter.CurrentRow)) = Type("DataCompositionFilter") Then
		IsDataCompositionFilterCurrentRow	= True;
		DataCompositionFilterSelected		= Not DataCompositionFilterSelected Or (Items.SettingsComposerSettingsFilter.SelectedRows.Count() = 1);
	EndIf;
	
	For Each Item In Items.SettingsComposerSettingsFilter.SelectedRows Do
		
		If TypeOf(Report.SettingsComposer.Settings.Filter.GetObjectByID(Item)) = Type("DataCompositionFilter") Then
			IsDataCompositionFilterSelected = True;
			Break;
		EndIf;
		
	EndDo;
	
	If Not IsDataCompositionFilterSelected Then
		DataCompositionFilterSelected = False;
	EndIf;
	
	Items.SettingsComposerSettingsFilterGroupFilterItems.Enabled = Not (DataCompositionFilterSelected And IsDataCompositionFilterSelected);
	
EndProcedure

&AtClient
Function CheckErrors()
	
	ClearMessages();
	
	AreErrors = False;
	
	If Not (ItemPresentationCurrency Or ItemCurrencyAmount Or ItemQuantity) Then
		
		ErrorText	= NStr("en = 'At least one indicator is required'; ru = 'Укажите хотя бы один показатель';pl = 'Co najmniej jeden wskaźnik jest wymagany';es_ES = 'Se requiere al menos un indicador';es_CO = 'Se requiere al menos un indicador';tr = 'En az bir gösterge gerekli';it = 'È richiesto almeno un indicatore';de = 'Zumindest ein Indikator ist erforderlich'");
		ErrorField	= "ItemPresentationCurrency";
		
		CommonClientServer.MessageToUser(ErrorText, , ErrorField);
		AreErrors = True;
		
	EndIf;
	
	ErrorTemplate		= NStr("en = 'The ""Account"" is required on line %1 of the Grouping list'; ru = 'В строке %1 списка ""Группировка"" необходимо указать ""Счет""';pl = '""Konto"" jest wymagane w wierszu %1 listy Grupowania';es_ES = 'La ""Cuenta"" se requiere en la línea %1 de la lista de Agrupación';es_CO = 'La ""Cuenta"" se requiere en la línea %1 de la lista de Agrupación';tr = 'Gruplama listesinin %1 satırında ""Hesap"" gerekli';it = '""Conto"" è richiesto nella riga %1 dell''elenco Raggruppamenti';de = 'Das ""Konto"" ist in der Zeile %1 der Liste ""Gruppierung"" erforderlich.'");
	ErrorFieldTemplate	= "AccountingGroupingByAccountsTable[%1].Account";
	
	LineNumber = 1;
	For Each Row In AccountingGroupingByAccountsTable Do
		
		If Not ValueIsFilled(Row.Account) Then
			CommonClientServer.MessageToUser(StrTemplate(ErrorTemplate, LineNumber), , StrTemplate(ErrorFieldTemplate, LineNumber - 1));
			AreErrors = True;
		EndIf;
		
		LineNumber = LineNumber + 1;
		
	EndDo;
	
	ErrorTemplate		= NStr("en = 'The ""Analytical dimension type"" is required on line %1 of the Analytical dimension types list'; ru = 'В строке %1 списка ""Типы аналитических измерений"" требуется указать ""Тип аналитического измерения""';pl = '""Typ wymiaru analitycznego"" jest wymagany w wierszu %1 listy Typy wymiarów analitycznych';es_ES = 'El "" Tipo de dimensión analítica "" se requiere en la línea %1 de la lista de Tipos de dimensión analítica';es_CO = 'El "" Tipo de dimensión analítica "" se requiere en la línea %1 de la lista de Tipos de dimensión analítica';tr = 'Analitik boyut türleri listesinin %1 satırında ""Analitik boyut türü"" gerekli';it = '""Tipo di dimensione analitica"" è richiesto nella riga %1 dell''elenco dei tipi di dimensione analitica';de = 'Der ""Typ von analytischen Messungen"" ist in der Zeile %1 der Liste von Typen von analytischen Messungen erforderlich'");
	ErrorFieldTemplate	= "AnalyticalDimensionTypesTable[%1].AnalyticalDimensionType";
	
	LineNumber = 1;
	For Each Row In AnalyticalDimensionTypesTable Do
		
		If Not ValueIsFilled(Row.AnalyticalDimensionType) Then
			CommonClientServer.MessageToUser(StrTemplate(ErrorTemplate, LineNumber), , StrTemplate(ErrorFieldTemplate, LineNumber - 1));
			AreErrors = True;
		EndIf;
		
		LineNumber = LineNumber + 1;
		
	EndDo;
	
	Return AreErrors;
	
EndFunction

&AtClient
Function GetCurrentChartOfAccounts()
	
	ChartOfAccountsValue = Undefined;
	
	ParameterChartOfAccounts = New DataCompositionParameter("ChartOfAccounts");
	
	For Each UserSettingRow In Report.SettingsComposer.UserSettings.Items Do
		If TypeOf(UserSettingRow) = Type("DataCompositionSettingsParameterValue") Then
			
			If UserSettingRow.Parameter = ParameterChartOfAccounts Then
				
				ChartOfAccountsValue = UserSettingRow.Value;
				
				Break;
				
			EndIf;
			
		EndIf;
	EndDo;
	
	Return ChartOfAccountsValue;
EndFunction

&AtClient
Procedure AccountingGroupingByAccountsTableOnActivateRow(Item)
	
	CurrentData = Items.AccountingGroupingByAccountsTable.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentGroupingAccount = CurrentData.Account;
	
EndProcedure

&AtClient
Procedure AccountingGroupingByAccountsTableOnStartEdit(Item, NewRow, Clone)
	
	If Clone Then
		CurrentData = Items.AccountingGroupingByAccountsTable.CurrentData;
		
		If CurrentData = Undefined Then
			Return;
		EndIf;
		
		RowID = AccountingGroupingByAccountsTable.IndexOf(CurrentData);
		
		If CurrentData.Use
			And ValueIsFilled(CurrentData.Account)
			And CheckAccountsHierarchy(
			CurrentData.Account,
			RowID,
			"AccountingGroupingByAccountsTable",
			False) Then
			
			CurrentData.Use = False;
			
			SetSettings();
			
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure AccountingGroupingByAccountsTableUseOnChange(Item)
	
	CurrentData = Items.AccountingGroupingByAccountsTable.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	RowID = AccountingGroupingByAccountsTable.IndexOf(CurrentData);
	
	If CurrentData.Use
		And ValueIsFilled(CurrentData.Account)
		And CheckAccountsHierarchy(
			CurrentData.Account,
			RowID,
			"AccountingGroupingByAccountsTable",
			True) Then
		
		CurrentData.Use = False;
		
	EndIf;
	
EndProcedure

&AtServer
Function CheckAccountsHierarchy(Account, RowID, TableName, CheckboxChange)
	
	CurrentRow = ThisObject[TableName][RowID];
	
	FindedRows = ThisObject[TableName].FindRows(New Structure("Use", True));
	
	FindError = False;
	
	For Each AccountRow In FindedRows Do
		
		If CurrentRow = AccountRow
			Or Not ValueIsFilled(AccountRow.Account) Then
			Continue;
		EndIf;
		
		FindedParent		= Account.BelongsToItem(AccountRow.Account);
		FindedChild			= AccountRow.Account.BelongsToItem(Account);
		FindedThisAccount	= (AccountRow.Account = Account);
		
		If CheckboxChange 
			And (FindedChild Or FindedParent) Then
			ErrorTemplate = NStr("en = 'Cannot select the Use checkbox for this account. %1.'; ru = 'Не удалось установить флажок ""Использовать"" для этого счета. %1.';pl = 'Nie można zaznaczyć pola wyboru Użycie dla tego konta. %1.';es_ES = 'No se puede seleccionar la casilla de verificación Utilizar para esta cuenta.%1.';es_CO = 'No se puede seleccionar la casilla de verificación Utilizar para esta cuenta.%1.';tr = 'Bu hesap için Kullan onay kutusu seçilemiyor. %1.';it = 'Impossibile selezionare la casella di controllo Utilizza per questo conto. %1.';de = 'Fehler beim Aktivieren des Kontrollkästchens Verwenden für dieses Konto. %1.'");
		ElsIf CheckboxChange Then
			ErrorTemplate = NStr("en = 'Cannot select the Use checkbox. %1.'; ru = 'Не удалось установить флажок ""Использовать"". %1.';pl = 'Nie można zaznaczyć pola wyboru Użycie. %1.';es_ES = 'No se puede seleccionar la casilla de verificación Utilizar.%1.';es_CO = 'No se puede seleccionar la casilla de verificación Utilizar.%1.';tr = 'Kullan onay kutusu seçilemiyor. %1.';it = 'Impossibile selezionare la casella di controllo Utilizza. %1.';de = 'Fehler beim Aktivieren des Kontrollkästchens Verwenden. %1.'");
		Else 
			ErrorTemplate = NStr("en = '%1 The Use checkbox is cleared.'; ru = '%1Флажок ""Использовать"" снят.';pl = '%1 Pole wyboru Użycie jest odznaczone.';es_ES = '%1 La casilla de verificación Utilizar está desactivada.';es_CO = '%1 La casilla de verificación Utilizar está desactivada.';tr = '%1 Kullan onay kutusu temizlendi.';it = '%1 La casella di controllo Utilizza è deselezionata.';de = '%1 Das Kontrollkästchen Verwenden ist deaktiviert.'");
		EndIf;
		
		If FindedParent Then
			ErrorText = NStr("en = 'Grouping by its parent account is already selected.'; ru = 'Группировка по родительскому счету уже установлена.';pl = 'Grupowanie według konta rodzicielskiego zostało już wybrane.';es_ES = 'La agrupación por su cuenta madre ya está seleccionada.';es_CO = 'La agrupación por su cuenta madre ya está seleccionada.';tr = 'Üst hesaba göre gruplama zaten seçili.';it = 'Raggruppamento per conto madre già selezionato.';de = 'Gruppierung nach dessen übergeordnetes Konto ist bereits ausgewählt.'");
		ElsIf FindedChild Then
			ErrorText = NStr("en = 'Grouping by its subordinate account is already selected.'; ru = 'Группировка по подчиненному счету уже установлена.';pl = 'Grupowanie według konta podrzędnego zostało już wybrane.';es_ES = 'La agrupación por su cuenta subordinada ya está seleccionada.';es_CO = 'La agrupación por su cuenta subordinada ya está seleccionada.';tr = 'Alt hesaba göre gruplama zaten seçili.';it = 'Raggruppamento per conto subordinato già selezionato.';de = 'Gruppierung nach dessen untergeordnetes Konto ist bereits ausgewählt.'");
		ElsIf FindedThisAccount Then
			ErrorText = NStr("en = 'Grouping by this account is already selected.'; ru = 'Группировка по данному счету уже установлена.';pl = 'Grupowanie według tego konta zostało już wybrane.';es_ES = 'La agrupación por esta cuenta ya está seleccionada.';es_CO = 'La agrupación por esta cuenta ya está seleccionada.';tr = 'Bu hesaba göre gruplama zaten seçili.';it = 'Raggruppamento per questo conto già selezionato.';de = 'Gruppierung nach diesem Konto ist bereits ausgewählt.'");
		Else
			Continue;
		EndIf;
		
		MessageText = StrTemplate(ErrorTemplate, ErrorText);
		
		FindError = True;
		
		CommonClientServer.MessageToUser(MessageText);
		
	EndDo;
	
	Return FindError;
	
EndFunction

#EndRegion