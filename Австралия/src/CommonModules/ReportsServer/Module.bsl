#Region Public

// It initializes composer on the basis of schema and imports new settings.
// To call from the BeforeImportSettingsToComposer event handler of the report form located in the 
// report object module.
//
// Parameters:
//   ReportObject - ReportObject, ExternalReportObject - a report that requires a schema to be connected.
//   Context    - ClientApplicationForm      - a report form or a report setting form.
//                                         It is passed as it is from the similarly named parameter of event
//                                         BeforeImportSettingsToComposer.
//               - Structure             - report parameters. See ReportOptions. AttachReportAndImportSettings.
//   DCSchema     - DataCompositionSchema - a schema to be attached.
//   SchemaKey   - String                - new schema ID that will be written to additional 
//                                         properties of user settings.
//
Procedure AttachSchema(ReportObject, Context, DCSchema, SchemaKey) Export
	EventFromReportForm = (TypeOf(Context) = Type("ClientApplicationForm"));
	
	ReportObject.DataCompositionSchema = DCSchema;
	If EventFromReportForm Then
		ReportSettings = Context.ReportSettings;
		SchemaURL = ReportSettings.SchemaURL;
		ReportSettings.Insert("SchemaModified", True);
	Else
		SchemaURLFilled = (TypeOf(Context.SchemaURL) = Type("String") AND IsTempStorageURL(Context.SchemaURL));
		If Not SchemaURLFilled Then
			FormID = CommonClientServer.StructureProperty(Context, "FormID");
			If TypeOf(FormID) = Type("UUID") Then
				SchemaURLFilled = True;
				Context.SchemaURL = PutToTempStorage(DCSchema, FormID);
			EndIf;
		EndIf;
		If SchemaURLFilled Then
			SchemaURL = Context.SchemaURL;
		Else
			SchemaURL = PutToTempStorage(DCSchema);
		EndIf;
		Context.SchemaModified = True;
	EndIf;
	PutToTempStorage(DCSchema, SchemaURL);
	
	ReportObject.SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
	
	If EventFromReportForm Then
		ValueToFormData(ReportObject, Context.Report);
	EndIf;
EndProcedure

// Outputs command to a report form as a button to the specified group.
// It also registers the command protecting it from deletion upon redrawing the form.
// To call from the OnCreateAtServer report form event.
//
// Parameters:
//   ReportForm       - ClientApplicationForm - a report form, to which command is added.
//   CommandOrCommands - FormCommand     - a command, to which the displayed buttons will be connected.
//					       If the Action property has a blank string, when the command is executed, the 
//					       ReportsClientOverridable.CommandHandler procedure will be called.
//					       If the Action property contains a string of the "<CommonClientModuleName>.
//					       <ExportProcedureName>" kind, when the command is executed in the specified module, the 
//					       specified procedure with two parameters will be called, similar to the first two parameters of the ReportsClientOverridable.CommandHandler procedure.
//				       - Array - a set of commands (FormCommand), that will be output to the specified group.
//   GroupType         - String - conditional name of the group, in which a button is to be output.
//					       "Main"          - a group with the "Generate" and "Generate now" buttons.
//					       "Settings"        - a group with buttons "Settings", "Change report options", and so on.
//					       "SpreadsheetDocumentOperations" - a group with buttons "Find", "Expand all groups", and so on.
//					       "Integration"       - a group with such buttons as "Print, Save, Send", and so on.
//					       "SubmenuSend" - a submenu in the "Integration" group to send via email.
//					       "Other"           - a group with such buttons as "Change form", "Help", and so on.
//   ToGroupBeginning      - Boolean - if True, a biutton will be output to group beginning. Otherwise, a button will be output to group end.
//   OnlyInAllActions - Boolean - if True, a button will be output only to the "More actions" submenu.
//                                    Otherwise, a button will be output both to the "More actions" submenu and to the form command bar.
//   SubgroupSuffix   - String - if it is filled, commands will be merged into a subgroup.
//                                 SubgroupSuffix is added to the right subgroup name.
//
Procedure OutputCommand(ReportForm, CommandOrCommands, GroupType, ToGroupBeginning = False, OnlyInAllActions = False, 
	SubgroupSuffix = "") Export
	
	PasteBeforeWhat = Undefined;
	If GroupType = "Main" Then
		Folder = ReportForm.Items.MainGroup;
	ElsIf GroupType = "Settings" Then
		Folder = ReportForm.Items.ReportSettingsGroup;
	ElsIf GroupType = "SpreadsheetDocumentOperations" Then
		Folder = ReportForm.Items.TableOperationsGroup;
	ElsIf GroupType = "Integration" Then
		Folder = ReportForm.Items.OutputGroup;
	ElsIf GroupType = "SubmenuSend" Then
		Folder = ReportForm.Items.SendGroup;
	ElsIf GroupType = "Other" Then
		Folder = ReportForm.Items.MainCommandBar;
		PasteBeforeWhat = ?(ToGroupBeginning, ReportForm.Items.NewWindow, Undefined);
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'При вызове процедуры ""%1"" передано недопустимо значение параметра ""%2"".'; en = 'Invalid value of the ""%2"" parameter is transferred when calling the ""%1"" procedure.'; pl = 'Podczas wywołania procedury ""%1"" została przekazana niedopuszczalna wartość parametru ""%2"".';es_ES = 'Al llamar el procedimiento ""%1"" ha sido pasado un valor inadmisible del parámetro ""%2"".';es_CO = 'Al llamar el procedimiento ""%1"" ha sido pasado un valor inadmisible del parámetro ""%2"".';tr = '""%1"" prosedürü çağrıldığında ""%2"" parametrenin değeri kullanılamıyor.';it = 'Trasferito un valore non valido del parametro ""%2"" durante la chiamata della procedura ""%1"".';de = 'Beim Aufruf der Prozedur ""%1"" ist der Wert des Parameters ""%2"" ungültig.'"),
			"ReportsServer.OutputCommand",
			"GroupType");
	EndIf;
	If ToGroupBeginning AND PasteBeforeWhat = Undefined Then
		PasteBeforeWhat = Folder.ChildItems[0];
	EndIf;
	
	If TypeOf(CommandOrCommands) = Type("FormCommand") Then
		Commands = New Array;
		Commands.Add(CommandOrCommands);
	Else
		Commands = CommandOrCommands;
	EndIf;
	
	If SubgroupSuffix <> "" Then
		Subgroup = ReportForm.Items.Find(Folder.Name + SubgroupSuffix);
		If Subgroup = Undefined Then
			Subgroup = ReportForm.Items.Insert(Folder.Name + SubgroupSuffix, Type("FormGroup"), Folder, PasteBeforeWhat);
			If Subgroup.Type = FormGroupType.Popup Then
				Subgroup.Type = FormGroupType.ButtonGroup;
			EndIf;
		EndIf;
		Folder = Subgroup;
		PasteBeforeWhat = Undefined;
	EndIf;
	
	For Each Command In Commands Do
		
		Handler = ?(StrOccurrenceCount(Command.Action, ".") = 0, "", Command.Action);
		ReportForm.ConstantCommands.Add(Command.Name, Handler);
		Command.Action = "Attachable_Command";
		
		Button = ReportForm.Items.Insert(Command.Name, Type("FormButton"), Folder, PasteBeforeWhat);
		Button.CommandName = Command.Name;
		Button.OnlyInAllActions = OnlyInAllActions;
		
	EndDo;
	
EndProcedure

// Hyperlinks the cell and fills address fields and reference presentations.
//
// Parameters:
//   Cell      - SpreadsheetDocumentRange - spreadsheet document area.
//   HyperlinkAddress - String                          - an address of the hyperlink to be displayed in the specified cell.
//			       Hyperlinks of the following formats automatically open in a standard report form:
//			       "http://<address>", "https://<address>", "e1cib/<address>", "e1c://<address>"
//			       Such hyperlinks are opened using the CommonClient.OpenURL procedure.
//			       See also URLPresentation.URL in Syntax Assistant.
//			       To open hyperlinks of other formats write code in the ReportsClientOverridable.
//			       SpreadsheetDocumentChoiceProcessing procedure.
//   RefPresentation - String, Undefined - description to be displayed in the specified cell.
//                                                If Undefined, HyperlinkAddress is displayed as is.
//
Procedure OutputHyperlink(Cell, HyperlinkAddress, RefPresentation = Undefined) Export
	Cell.Hyperlink = True;
	Cell.Font       = New Font(Cell.Font, , , , , True);
	Cell.TextColor  = StyleColors.HyperlinkColor;
	Cell.Details = HyperlinkAddress;
	Cell.Text       = ?(RefPresentation = Undefined, HyperlinkAddress, RefPresentation);
EndProcedure

// Defines that a report is blank.
//
// Parameters:
//   ReportObject - ReportObject, ExternalReportObject - a report to be checked.
//   DCProcessor - DataCompositionProcessor - an object composing the data in the report.
//
// Returns:
//   Boolean - True if a report is blank. False if a report contains data.
//
Function ReportIsBlank(ReportObject, DCProcessor = Undefined) Export
	If DCProcessor = Undefined Then
		
		If ReportObject.DataCompositionSchema = Undefined Then
			Return False; // Not DCS Report.
		EndIf;
		
		// Objects to create a data composition template.
		DCTemplateComposer = New DataCompositionTemplateComposer;
		
		// Composes a template.
		DCTemplate = DCTemplateComposer.Execute(ReportObject.DataCompositionSchema, ReportObject.SettingsComposer.GetSettings());
		
		// Skip the check whether the report is empty.
		If ThereIsExternalDataSet(DCTemplate.DataSets) Then
			Return False;
		EndIf;
		
		// Object that composes data.
		DCProcessor = New DataCompositionProcessor;
		
		// Initialize an object.
		DCProcessor.Initialize(DCTemplate, , , True);
		
	Else
		
		// Stand at the beginning of the composition.
		DCProcessor.Reset();
		
	EndIf;
	
	// The object to output a composition result to the spreadsheet document.
	DCResultOutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	
	// Determines the spreadsheet document in which the result has to be displayed.
	DCResultOutputProcessor.SetDocument(New SpreadsheetDocument);
	
	// Sequential output
	DCResultOutputProcessor.BeginOutput();
	
	// Gets the next item of the composition result.
	DCResultItem = DCProcessor.Next();
	While DCResultItem <> Undefined Do
		
		// Output the item of the report composition result into the document.
		DCResultOutputProcessor.OutputItem(DCResultItem);
		
		// Determine a non-empty result.
		For Each DCTemplateParameterValue In DCResultItem.ParameterValues Do
			Try
				ValueIsFilled = ValueIsFilled(DCTemplateParameterValue.Value);
			Except
				ValueIsFilled = False; // Line, Border, Color and other DC objects which can appear on the output.
			EndTry;
			If ValueIsFilled Then
				DCResultOutputProcessor.EndOutput();
				Return False;
			EndIf;
		EndDo;
		
		Try
			// Gets the next item of the composition result.
			DCResultItem = DCProcessor.Next();
		Except
			Return False;
		EndTry;
		
	EndDo;
	
	// Indicate to the object that the output of the result is complete.
	DCResultOutputProcessor.EndOutput();
	
	Return True;
EndFunction

#EndRegion

#Region Internal

// Generates the period details for compiling statistics.
// The information to be obtained does not contain specific dates so it can be considered anonymous.
//
// Parameters:
//   Period - StandardPeriod - a period to analyze.
//
// Returns:
//   Structure - period description:
//       * PeriodType   - String - a period classification. For example: "Year", "FromBegOfYear" or "TillEndOfYear".
//       * PeriodShift - Number  - the number of steps required to get the period relative to the current date.
//                                 The step size is determined by the period kind.
//
Function PeriodAnalysis(Period) Export
	If Period.Variant = StandardPeriodVariant.Custom Then
		Return ArbitraryPeriodAnalysis(Period.StartDate, Period.EndDate);
	Else
		Return StandardPeriodAnalysis(Period.Variant);
	EndIf;
EndFunction

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Analysis

// Returns information on composer settings.
// After completing setting operations, call ClearAdvancedInformationOnSettings to clear cyclic 
// references for correct clearing of memory.
//
Function AdvancedInformationOnSettings(DCSettingsComposer, ReportSettings, ReportObjectOrFullName, OutputConditions = Undefined) Export
	DCSettings = DCSettingsComposer.Settings;
	DCUserSettings = DCSettingsComposer.UserSettings;
	
	AdditionalItemsSettings = CommonClientServer.StructureProperty(DCUserSettings.AdditionalProperties, "FormItems");
	If AdditionalItemsSettings = Undefined Then
		AdditionalItemsSettings = New Map;
	EndIf;
	
	Information = New Structure;
	Information.Insert("UserSettingsOnly", False);
	Information.Insert("QuickOnly", False);
	Information.Insert("CurrentDCNodeID", Undefined);
	If OutputConditions <> Undefined Then
		FillPropertyValues(Information, OutputConditions);
	EndIf;
	
	Information.Insert("DCSettings", DCSettings);
	
	Information.Insert("ReportSettings",           ReportSettings);
	Information.Insert("ReportObjectOrFullName",   ReportObjectOrFullName);
	Information.Insert("OptionTree",            OptionTree());
	Information.Insert("OptionSettings",         OptionSettingsTable());
	Information.Insert("UserSettings", UserSettingsTable());
	
	Information.Insert("LinksThatCanBeDisabled", New Array);
	Information.Insert("Links", New Structure);
	Information.Links.Insert("ByType",             TableOfLinksByType());
	Information.Links.Insert("SelectionParameters",   ChoiceParametersLinksTable());
	Information.Links.Insert("MetadataObjects", MetadataObjectsLinksTable(ReportSettings, Information.ReportObjectOrFullName));
	
	Information.Insert("AdditionalItemsSettings",   AdditionalItemsSettings);
	Information.Insert("MetadataObjectNamesMap", New Map);
	Information.Insert("Search", New Structure);
	Information.Search.Insert("OptionSettingsByDCField", New Map);
	Information.Search.Insert("UserSettings", New Map);
	Information.Insert("HasQuickSettings", False);
	Information.Insert("HasRegularSettings", False);
	Information.Insert("HasNonexistingFields", False);
	
	Information.Insert("HasNestedReports", False);
	Information.Insert("HasNestedFilters", False);
	Information.Insert("HasNestedAppearance", False);
	Information.Insert("HasNestedFields", False);
	Information.Insert("HasNestedSorting", False);
	
	For Each DCUserSetting In DCUserSettings.Items Do
		SettingProperties = Information.UserSettings.Add();
		SettingProperties.DCUserSetting = DCUserSetting;
		SettingProperties.ID               = DCUserSetting.UserSettingID;
		SettingProperties.IndexInCollection = DCUserSettings.Items.IndexOf(DCUserSetting);
		SettingProperties.DCID  = DCUserSettings.GetIDByObject(DCUserSetting);
		SettingProperties.Type              = ReportsClientServer.SettingTypeAsString(TypeOf(DCUserSetting));
		Information.Search.UserSettings.Insert(SettingProperties.ID, SettingProperties);
	EndDo;
	
	TreeRow = RegisterOptionTreeNode(Information, DCSettings, DCSettings, Information.OptionTree.Rows, "Report");
	TreeRow.Global = True;
	Information.Insert("OptionTreeRootRow", TreeRow);
	If Information.CurrentDCNodeID = Undefined Then
		Information.CurrentDCNodeID = TreeRow.DCID;
		If Not Information.UserSettingsOnly Then
			TreeRow.OutputAllowed = True;
		EndIf;
	EndIf;
	
	RegisterOptionSettings(DCSettings, Information);
	RegisterLinksFromMasterItems(Information);
	
	Return Information;
EndFunction

// Clear from circular references to release memory.
Procedure ClearAdvancedInformationOnSettings(InformationOnSettings) Export
	
	ClearValueTree(InformationOnSettings.OptionTree);
	ClearValueTree(InformationOnSettings.OptionSettings);
	InformationOnSettings.Search.Clear();
	InformationOnSettings.UserSettings.Columns.Clear();
	InformationOnSettings.Links.Clear();
	InformationOnSettings.Clear();

EndProcedure

// Clear the value tree from circular references to release memory.
//
Procedure ClearValueTree(Val Tree) Export
	
	TreeRows = Tree.Rows;
	ColumnsToClear = New Array;
	ColumnIndex = 0;
	For each TreeColumn In Tree.Columns Do
		If TreeColumn.ValueType <> New TypeDescription("String")
			AND TreeColumn.ValueType <> New TypeDescription("Boolean")
			AND TreeColumn.ValueType <> New TypeDescription("Number") 
			AND TreeColumn.ValueType <> New TypeDescription("Date") Then
			ColumnsToClear.Add(ColumnIndex);
		EndIf;	
		ColumnIndex = ColumnIndex + 1;
	EndDo;
	
	If ColumnsToClear.Count() = 0 Then
		Return;
	EndIf;
	
	For each TreeRow In TreeRows Do
		ClearValueTreeRows(TreeRow.Rows, ColumnsToClear);
	EndDo;
	Tree.Columns.Clear();
	
EndProcedure

Procedure ClearValueTreeRows(Val TreeRows, Val ColumnsToClear)
	
	For each TreeRow In TreeRows Do
		ClearValueTreeRows(TreeRow.Rows, ColumnsToClear);
	EndDo;
	
	For each TreeRow In TreeRows Do
		For each Column In ColumnsToClear Do
			TreeRow[Column] = Undefined;
		EndDo;	
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Option tree

Function OptionTree()
	Result = New ValueTree;
	
	// DCS nodes.
	Result.Columns.Add("DCNode");
	Result.Columns.Add("AvailableDCSetting");
	Result.Columns.Add("DCUserSetting");
	
	// Application structure.
	Result.Columns.Add("UserSetting");
	
	// Search for this setting in a node.
	Result.Columns.Add("DCID");
	
	// A link with DCS nodes.
	Result.Columns.Add("ID", New TypeDescription("String"));
	
	// Setting type.
	Result.Columns.Add("Type", New TypeDescription("String"));
	Result.Columns.Add("Subtype", New TypeDescription("String"));
	Result.Columns.Add("State", New TypeDescription("String"));
	
	Result.Columns.Add("HasStructure", New TypeDescription("Boolean"));
	Result.Columns.Add("HasFieldsAndDecorations", New TypeDescription("Boolean"));
	Result.Columns.Add("Global", New TypeDescription("Boolean"));
	
	// Setting content.
	Result.Columns.Add("ContainsFilters", New TypeDescription("Boolean"));
	Result.Columns.Add("ContainsFields", New TypeDescription("Boolean"));
	Result.Columns.Add("ContainsSorting", New TypeDescription("Boolean"));
	Result.Columns.Add("ContainsConditionalAppearance", New TypeDescription("Boolean"));
	
	// Output.
	Result.Columns.Add("Presentation", New TypeDescription("String"));
	Result.Columns.Add("DefaultPresentation", New TypeDescription("String"));
	Result.Columns.Add("Title", New TypeDescription("String"));
	Result.Columns.Add("OutputAllowed", New TypeDescription("Boolean"));
	Result.Columns.Add("OutputFlagOnly", New TypeDescription("Boolean"));
	
	Return Result;
EndFunction

Function RegisterOptionTreeNode(Information, DCSettings, DCNode, TreeRowsSet, Subtype = "")
	TreeRow = TreeRowsSet.Add();
	TreeRow.DCNode = DCNode;
	TreeRow.Type = ReportsClientServer.SettingTypeAsString(TypeOf(DCNode));
	TreeRow.Subtype = Subtype;
	If TreeRow.Type <> "Settings" Then
		TreeRow.ID = DCNode.UserSettingID;
	EndIf;
	
	TreeRow.DCID = DCSettings.GetIDByObject(DCNode);
	TreeRow.Global = (Subtype = "Report");
	
	If TreeRow.Type = "Settings" Then
		TreeRow.HasStructure = True;
		TreeRow.HasFieldsAndDecorations = True;
	ElsIf TreeRow.Type = "Group"
		Or TreeRow.Type = "ChartGroup"
		Or TreeRow.Type = "TableGroup" Then
		TreeRow.HasStructure = True;
		TreeRow.HasFieldsAndDecorations = True;
	ElsIf TreeRow.Type = "Table" Then
		TreeRow.HasFieldsAndDecorations = True;
	ElsIf TreeRow.Type = "Chart" Then
		TreeRow.HasFieldsAndDecorations = True;
	ElsIf TreeRow.Type = "NestedObjectSettings" Then
		TreeRow.AvailableDCSetting = DCSettings.AvailableObjects.Items.Find(DCNode.ObjectID);
	ElsIf TreeRow.Type = "TableStructureItemCollection"
		Or TreeRow.Type = "ChartStructureItemCollection" Then
		// see below.
	Else
		Return TreeRow;
	EndIf;
	
	FillSettingPresentationAndState(
		TreeRow,
		TreeRow.DCNode,
		Undefined,
		TreeRow.AvailableDCSetting);
	
	If TreeRow.HasFieldsAndDecorations Then
		TreeRow.Title = TitleFromOutputParameters(DCNode.OutputParameters);
		TreeRow.ContainsFields               = DCSettings.HasItemSelection(DCNode);
		TreeRow.ContainsConditionalAppearance = DCSettings.HasItemConditionalAppearance(DCNode);
	EndIf;
	
	If Not Information.QuickOnly Then
		TreeRow.OutputAllowed = (TreeRow.DCID = Information.CurrentDCNodeID);
	EndIf;
	
	If TypeOf(TreeRow.ID) = Type("String") AND Not IsBlankString(TreeRow.ID) Then
		SettingProperties = Information.Search.UserSettings.Get(TreeRow.ID);
		If SettingProperties <> Undefined Then
			TreeRow.UserSetting   = SettingProperties;
			TreeRow.DCUserSetting = SettingProperties.DCUserSetting;
			RegisterUserSetting(Information, SettingProperties, TreeRow, Undefined);
			If ValueIsFilled(TreeRow.Title) Then
				SettingProperties.Presentation = TreeRow.Title;
			EndIf;
			If Information.UserSettingsOnly Then
				TreeRow.OutputAllowed = SettingProperties.OutputAllowed;
				TreeRow.State = SettingProperties.State;
			EndIf;
		EndIf;
	EndIf;
	
	If TreeRow.HasStructure Then
		For Each NestedItem In DCNode.Structure Do
			RegisterOptionTreeNode(Information, DCSettings, NestedItem, TreeRow.Rows);
		EndDo;
		TreeRow.ContainsFilters     = DCSettings.HasItemFilter(DCNode);
		TreeRow.ContainsSorting = DCSettings.HasItemOrder(DCNode);
	EndIf;
	
	If TreeRow.Type = "Table" Then
		RegisterOptionTreeNode(Information, DCSettings, DCNode.Rows, TreeRow.Rows, "TableRows");
		RegisterOptionTreeNode(Information, DCSettings, DCNode.Columns, TreeRow.Rows, "ColumnsTable");
	ElsIf TreeRow.Type = "Chart" Then
		RegisterOptionTreeNode(Information, DCSettings, DCNode.Points, TreeRow.Rows, "ChartPoints");
		RegisterOptionTreeNode(Information, DCSettings, DCNode.Series, TreeRow.Rows, "ChartSeries");
	ElsIf TreeRow.Type = "TableStructureItemCollection"
		Or TreeRow.Type = "ChartStructureItemCollection" Then
		For Each NestedItem In DCNode Do
			RegisterOptionTreeNode(Information, DCSettings, NestedItem, TreeRow.Rows);
		EndDo;
	ElsIf TreeRow.Type = "NestedObjectSettings" Then
		Information.HasNestedReports = True;
		RegisterOptionTreeNode(Information, DCSettings, DCNode.Settings, TreeRow.Rows);
	EndIf;
	
	If Not TreeRow.Global Then
		If TreeRow.ContainsFields Then
			Information.HasNestedFields = True;
		EndIf;
		If TreeRow.ContainsConditionalAppearance Then
			Information.HasNestedAppearance = True;
		EndIf;
		If TreeRow.ContainsFilters Then
			Information.HasNestedFilters = True;
		EndIf;
		If TreeRow.ContainsSorting Then
			Information.HasNestedSorting = True;
		EndIf;
	EndIf;
	
	Return TreeRow;
EndFunction

Function TitleFromOutputParameters(OutputParameters)
	OutputDCTitle = OutputParameters.FindParameterValue(New DataCompositionParameter("OutputTitle"));
	If OutputDCTitle = Undefined Then
		Return "";
	EndIf;
	If OutputDCTitle.Use = True
		AND OutputDCTitle.Value = DataCompositionTextOutputType.DontOutput Then
		Return "";
	EndIf;
	// In the Auto value, it is considered that the header is displayed.
	// When the OutputTitle parameter is disabled, this is an equivalent to the Auto value.
	DCTitle = OutputParameters.FindParameterValue(New DataCompositionParameter("Title"));
	If DCTitle = Undefined Then
		Return "";
	EndIf;
	Return DCTitle.Value;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Option settings

Function OptionSettingsTable()
	Result = New ValueTree;
	
	// DCS nodes.
	Result.Columns.Add("DCItem");
	Result.Columns.Add("AvailableDCSetting");
	Result.Columns.Add("DCUserSetting");
	
	// Application structure.
	Result.Columns.Add("TreeRow");
	Result.Columns.Add("UserSetting");
	Result.Columns.Add("Owner");
	Result.Columns.Add("Global", New TypeDescription("Boolean"));
	
	// Search for this setting in a node.
	Result.Columns.Add("CollectionName", New TypeDescription("String"));
	Result.Columns.Add("DCID");
	
	// A link with DCS nodes.
	Result.Columns.Add("ID", New TypeDescription("String"));
	Result.Columns.Add("ItemID", New TypeDescription("String"));
	
	// A setting description.
	Result.Columns.Add("Type", New TypeDescription("String"));
	Result.Columns.Add("Subtype", New TypeDescription("String"));
	Result.Columns.Add("State", New TypeDescription("String"));
	
	Result.Columns.Add("DCField");
	Result.Columns.Add("Value");
	Result.Columns.Add("ComparisonType");
	Result.Columns.Add("ListInput", New TypeDescription("Boolean"));
	Result.Columns.Add("TypesInformation");
	Result.Columns.Add("ChoiceForm", New TypeDescription("String"));
	
	Result.Columns.Add("MarkedValues");
	Result.Columns.Add("ChoiceParameters");
	
	Result.Columns.Add("TypeLink");
	Result.Columns.Add("ChoiceParameterLinks");
	Result.Columns.Add("MetadataRelations");
	Result.Columns.Add("TypeRestriction");
	
	// API
	Result.Columns.Add("TypeDescription");
	Result.Columns.Add("ValuesForSelection");
	Result.Columns.Add("SelectionValuesQuery");
	Result.Columns.Add("ValueListRedefined",           New TypeDescription("Boolean"));
	Result.Columns.Add("QuickChoice",                          New TypeDescription("Boolean"));
	Result.Columns.Add("RestrictSelectionBySpecifiedValues", New TypeDescription("Boolean"));
	Result.Columns.Add("EventOnChange", New TypeDescription("Boolean"));
	Result.Columns.Add("Width", New TypeDescription("Number"));
	Result.Columns.Add("OutputInMainSettingsGroup", New TypeDescription("Boolean"));
	
	// Output.
	Result.Columns.Add("DefaultPresentation", New TypeDescription("String"));
	Result.Columns.Add("Presentation", New TypeDescription("String"));
	Result.Columns.Add("OutputAllowed", New TypeDescription("Boolean"));
	Result.Columns.Add("OutputFlag", New TypeDescription("Boolean"));
	Result.Columns.Add("ChoiceFoldersAndItems");
	Result.Columns.Add("OutputFlagOnly", New TypeDescription("Boolean"));
	
	Return Result;
EndFunction

Function UserSettingsTable()
	Result = New ValueTable;
	
	// DCS nodes.
	Result.Columns.Add("DCNode");
	Result.Columns.Add("DCOptionSetting");
	Result.Columns.Add("DCUserSetting");
	Result.Columns.Add("AvailableDCSetting");
	
	// Application structure.
	Result.Columns.Add("TreeRow");
	Result.Columns.Add("OptionSetting");
	
	// Search for this setting in a node.
	Result.Columns.Add("DCID");
	Result.Columns.Add("IndexInCollection", New TypeDescription("Number"));
	
	// A link with DCS nodes.
	Result.Columns.Add("ID", New TypeDescription("String"));
	Result.Columns.Add("ItemID", New TypeDescription("String"));
	
	// A setting description.
	Result.Columns.Add("Type", New TypeDescription("String"));
	Result.Columns.Add("Subtype", New TypeDescription("String"));
	Result.Columns.Add("State", New TypeDescription("String"));
	
	Result.Columns.Add("DCField");
	Result.Columns.Add("Value");
	Result.Columns.Add("ComparisonType");
	Result.Columns.Add("ListInput", New TypeDescription("Boolean"));
	Result.Columns.Add("TypesInformation");
	
	Result.Columns.Add("MarkedValues");
	Result.Columns.Add("ChoiceParameters");
	
	// API
	Result.Columns.Add("TypeDescription");
	Result.Columns.Add("ValuesForSelection");
	Result.Columns.Add("SelectionValuesQuery");
	Result.Columns.Add("QuickChoice",                          New TypeDescription("Boolean"));
	Result.Columns.Add("RestrictSelectionBySpecifiedValues", New TypeDescription("Boolean"));
	
	// Output.
	Result.Columns.Add("DefaultPresentation", New TypeDescription("String"));
	Result.Columns.Add("Presentation", New TypeDescription("String"));
	Result.Columns.Add("Quick", New TypeDescription("Boolean"));
	Result.Columns.Add("Ordinary", New TypeDescription("Boolean"));
	Result.Columns.Add("OutputAllowed", New TypeDescription("Boolean"));
	Result.Columns.Add("OutputFlag", New TypeDescription("Boolean"));
	Result.Columns.Add("OutputFlagOnly", New TypeDescription("Boolean"));
	
	Result.Columns.Add("ItemsType", New TypeDescription("String"));
	Result.Columns.Add("ChoiceFoldersAndItems");
	
	// Additional properties.
	Result.Columns.Add("More", New TypeDescription("Structure"));
	
	Return Result;
EndFunction

Function TableOfLinksByType()
	// Links from DCS.
	TableOfLinksByType = New ValueTable;
	TableOfLinksByType.Columns.Add("Master");
	TableOfLinksByType.Columns.Add("MasterDCField");
	TableOfLinksByType.Columns.Add("SubordinateSettingsItem");
	TableOfLinksByType.Columns.Add("SubordinateParameterName");
	
	Return TableOfLinksByType;
EndFunction

Function ChoiceParametersLinksTable()
	ChoiceParametersLinksTable = New ValueTable;
	ChoiceParametersLinksTable.Columns.Add("Master");
	ChoiceParametersLinksTable.Columns.Add("MasterDCField");
	ChoiceParametersLinksTable.Columns.Add("SubordinateSettingsItem");
	ChoiceParametersLinksTable.Columns.Add("SubordinateParameterName");
	ChoiceParametersLinksTable.Columns.Add("Action");
	
	Return ChoiceParametersLinksTable;
EndFunction

Function MetadataObjectsLinksTable(ReportSettings, ReportObjectOrFullName)
	// Links from metadata.
	Result = New ValueTable;
	Result.Columns.Add("MainType",          New TypeDescription("Type"));
	Result.Columns.Add("SubordinateType",      New TypeDescription("Type"));
	Result.Columns.Add("SubordinateAttribute", New TypeDescription("String"));
	
	// Extension functionality.
	ReportsOverridable.AddMetadataObjectsConnections(Result); // Global links...
	If ReportSettings.Events.AddMetadataObjectsConnections Then // ... can be locally overridden for a report.
		ReportObject(ReportObjectOrFullName).AddMetadataObjectsConnections(Result);
	EndIf;
	
	Result.Columns.Add("HasParent",     New TypeDescription("Boolean"));
	Result.Columns.Add("HasSubordinate", New TypeDescription("Boolean"));
	Result.Columns.Add("LeadingItems",     New TypeDescription("Array"));
	Result.Columns.Add("SubordinateSettingsItems", New TypeDescription("Array"));
	Result.Columns.Add("MasterFullName",     New TypeDescription("String"));
	Result.Columns.Add("SubordinateAttributeFullName", New TypeDescription("String"));
	
	Return Result;
EndFunction

Procedure RegisterOptionSettings(DCSettings, Information)
	
	OptionTree = Information.OptionTree;
	
	FoundItems = OptionTree.Rows.FindRows(New Structure("HasStructure", True), True);
	For Each TreeRow In FoundItems Do
		
		// Settings, Filter property
		// Group, Filter property
		// TableGroup, Filter property.
		// ChartGroup, Filter property.
		
		// Settings, Filter.Items property.
		// Group, Filter.Items property
		// TableGroup, Filter.Items property
		// ChartGroup, Filter.Items property.
		
		RegisterSettingsNode(DCSettings, Information, TreeRow, "Filter");
		
		// Settings, Order property.
		// Group, Order property
		// TableGroup, Order property.
		// ChartGroup, Order property.
		
		RegisterSettingsNode(DCSettings, Information, TreeRow, "Order");
		
		// Settings, Structure property.
		// Group, Structure property.
		// TableGroup, Structure property.
		// ChartGroup, Structure property.
		
		RegisterSettingsNode(DCSettings, Information, TreeRow, "Structure");
		
	EndDo;
	
	FoundItems = OptionTree.Rows.FindRows(New Structure("HasFieldsAndDecorations", True), True);
	For Each TreeRow In FoundItems Do
		
		// Settings, Choice property
		// Table, Choice property
		// Chart, Choice property
		// Group, Choice property
		// ChartGroup, Choice property.
		// TableGroup, Choice property.
		
		RegisterSettingsNode(DCSettings, Information, TreeRow, "Selection");
		
		// Settings, ConditionalAppearance property.
		// Table, ConditionalAppearance property.
		// Chart, ConditionalAppearance property.
		// Group, ConditionalAppearance property.
		// ChartGroup, ConditionalAppearance property.
		// TableGroup, ConditionalAppearance property.
		
		// Settings, ConditionalAppearance.Items property.
		// Table, ConditionalAppearance.Items property.
		// Chart, ConditionalAppearance.Items property.
		// Group, ConditionalAppearance.Items property
		// ChartGroup, ConditionalAppearance.Items property
		// TableGroup,  ConditionalAppearance.Items property.
		
		RegisterSettingsNode(DCSettings, Information, TreeRow, "ConditionalAppearance");
		
		// Settings, OutputParameters property.
		// Table, OutputParameters property.
		// Chart, OutputParameters property.
		// Group, OutputParameters property
		// ChartGroup, OutputParameters property
		// TableGroup, OutputParameters property.
		
		RegisterSettingsNode(DCSettings, Information, TreeRow, "OutputParameters");
		
	EndDo;
	
	FoundItems = OptionTree.Rows.FindRows(New Structure("Type", "Settings"), True);
	For Each TreeRow In FoundItems Do
		
		// Settings, DataParameters property, FindParameterValue() method.
		
		RegisterSettingsNode(DCSettings, Information, TreeRow, "DataParameters");
		
	EndDo;
	
EndProcedure

Procedure RegisterSettingsNode(DCSettings, Information, TreeRow, CollectionName, ItemsSet = Undefined, Parent = Undefined, Owner = Undefined)
	DCNode = TreeRow.DCNode[CollectionName];
	
	Owner = Information.OptionSettings.Rows.Add();
	Owner.TreeRow = TreeRow;
	If CollectionName <> "DataParameters" AND CollectionName <> "OutputParameters" Then
		Owner.ID = DCNode.UserSettingID;
	EndIf;
	Owner.Type           = ReportsClientServer.SettingTypeAsString(TypeOf(DCNode));
	Owner.CollectionName  = CollectionName;
	Owner.Global    = TreeRow.Global;
	Owner.DCItem     = DCNode;
	Owner.OutputAllowed = Not Information.QuickOnly AND TreeRow.OutputAllowed;
	
	If TypeOf(Owner.ID) = Type("String") AND Not IsBlankString(Owner.ID) Then
		SettingProperties = Information.Search.UserSettings.Get(Owner.ID);
		If SettingProperties <> Undefined Then
			Owner.UserSetting = SettingProperties;
			RegisterUserSetting(Information, SettingProperties, Undefined, Owner);
			SettingProperties.ChoiceParameters = New Array;
			Owner.ChoiceParameters          = New Array;
			Owner.ChoiceParameterLinks    = New Array;
			Owner.MetadataRelations        = New Array;
			If Information.UserSettingsOnly Then
				Owner.OutputAllowed = SettingProperties.OutputAllowed;
			EndIf;
		EndIf;
	EndIf;
	
	If Owner.OutputAllowed Then
		If Owner.UserSetting = Undefined Then
			FillSettingPresentationAndState(
				Owner,
				Owner.DCItem,
				Undefined,
				Undefined);
		Else
			FillPropertyValues(Owner, Owner.UserSetting, "Presentation, OutputFlagOnly");
		EndIf;
	EndIf;
	
	If CollectionName = "Filter"
		Or CollectionName = "DataParameters"
		Or CollectionName = "OutputParameters"
		Or CollectionName = "ConditionalAppearance" Then
		RegisterSettingsItems(Information, DCNode, DCNode.Items, Owner, Owner);
	ElsIf Not Information.QuickOnly // (Optimization) Fields are sortings are not displayed in quick settings.
		AND (CollectionName = "Order" Or CollectionName = "Selection") Then
		RegisterSettingsItems(Information, DCNode, DCNode.Items, Owner, Owner);
	EndIf;
	
EndProcedure

Procedure RegisterSettingsItems(Information, DCNode, ItemsSet, Owner, Parent)
	HasUnmarkedItems = False;
	HasMarkedItems = False;
	
	For Each DCItem In ItemsSet Do
		OptionSettingsItem = Parent.Rows.Add();
		FillPropertyValues(OptionSettingsItem, Owner, "TreeRow, CollectionName, Global");
		OptionSettingsItem.Type = ReportsClientServer.SettingTypeAsString(TypeOf(DCItem));
		OptionSettingsItem.DCID = DCNode.GetIDByObject(DCItem);
		OptionSettingsItem.Owner = Owner;
		OptionSettingsItem.DCItem = DCItem;
		OptionSettingsItem.OutputAllowed = Not Information.QuickOnly AND Owner.OutputAllowed;
		OptionSettingsItem.OutputFlag = True;
		
		If OptionSettingsItem.Type = "AutoOrderItem"
			Or OptionSettingsItem.Type = "AutoSelectedField"
			Or OptionSettingsItem.Type = "SelectedFieldsGroup" Then
			// No action required.
		ElsIf OptionSettingsItem.Type = "OrderingItem" Then
			OptionSettingsItem.Value = DCItem.OrderType;
			OptionSettingsItem.DCField = DCItem.Field;
			OptionSettingsItem.AvailableDCSetting = DCNode.OrderAvailableFields.FindField(DCItem.Field);
			If OptionSettingsItem.AvailableDCSetting = Undefined Then
				OptionSettingsItem.State = "DeletionMark";
			EndIf;
		ElsIf OptionSettingsItem.Type = "SelectedField" Then
			OptionSettingsItem.DCField = DCItem.Field;
			OptionSettingsItem.AvailableDCSetting = DCNode.SelectionAvailableFields.FindField(DCItem.Field);
			If OptionSettingsItem.AvailableDCSetting = Undefined Then
				OptionSettingsItem.State = "DeletionMark";
			EndIf;
		Else
			OptionSettingsItem.ID = DCItem.UserSettingID;
		EndIf;
		
		If OptionSettingsItem.Type = "SelectedFields"
			Or OptionSettingsItem.Type = "Order"
			Or OptionSettingsItem.Type = "TableStructureItemCollection"
			Or OptionSettingsItem.Type = "ChartStructureItemCollection"
			Or OptionSettingsItem.Type = "Filter"
			Or OptionSettingsItem.Type = "ConditionalAppearance"
			Or OptionSettingsItem.Type = "SettingsStructure" Then
			OptionSettingsItem.OutputFlag = False;
		EndIf;
		
		SettingProperties = Undefined;
		If TypeOf(OptionSettingsItem.ID) = Type("String") AND Not IsBlankString(OptionSettingsItem.ID) Then
			SettingProperties = Information.Search.UserSettings.Get(OptionSettingsItem.ID);
		EndIf;
		
		If OptionSettingsItem.Type = "FilterItem" Or OptionSettingsItem.Type = "SettingsParameterValue" Then
			// Skipping all DCS settings that are not included in user settings, except for DCS parameters.
			If SettingProperties = Undefined AND Owner.CollectionName <> "DataParameters" Then
				Parent.Rows.Delete(OptionSettingsItem); // As an optimization.
				Continue;
			EndIf;
			RegisterField(Information, DCNode, DCItem, OptionSettingsItem);
			RegisterTypesAndLinks(Information, OptionSettingsItem);
		EndIf;
		
		If SettingProperties <> Undefined Then
			OptionSettingsItem.UserSetting = SettingProperties;
			RegisterUserSetting(Information, SettingProperties, Undefined, OptionSettingsItem);
			If Information.UserSettingsOnly Then
				OptionSettingsItem.OutputAllowed = SettingProperties.OutputAllowed;
				OptionSettingsItem.Value      = SettingProperties.Value;
				OptionSettingsItem.ComparisonType  = SettingProperties.ComparisonType;
			EndIf;
		EndIf;
		
		If OptionSettingsItem.OutputAllowed Then
			FillSettingPresentationAndState(
				OptionSettingsItem,
				OptionSettingsItem.DCItem,
				Undefined,
				OptionSettingsItem.AvailableDCSetting);
			If OptionSettingsItem.State = "DeletionMark" Then
				Information.HasNonexistingFields = True;
				OptionSettingsItem.OutputAllowed = False;
			ElsIf OptionSettingsItem.Type = "FilterItem"
				Or OptionSettingsItem.Type = "SettingsParameterValue" Then
				OnDefineSelectionParameters(Information, OptionSettingsItem);
			EndIf;
		EndIf;
		
		If OptionSettingsItem.Type = "FilterItemsGroup" Then
			OptionSettingsItem.Value = DCItem.GroupType;
			RegisterSettingsItems(Information, DCNode, DCItem.Items, Owner, OptionSettingsItem);
		ElsIf OptionSettingsItem.Type = "SelectedFieldsGroup" Then
			OptionSettingsItem.Value = DCItem.Placement;
			RegisterSettingsItems(Information, DCNode, DCItem.Items, Owner, OptionSettingsItem);
		ElsIf OptionSettingsItem.Type = "SettingsParameterValue" Then
			If SettingProperties <> Undefined Then // As an optimization.
				RegisterSettingsItems(Information, DCNode, DCItem.NestedParameterValues, Owner, OptionSettingsItem);
			EndIf;
		EndIf;
		
		If SettingProperties <> Undefined Then
			SettingProperties.ValuesForSelection = OptionSettingsItem.ValuesForSelection;
			SettingProperties.ChoiceParameters   = OptionSettingsItem.ChoiceParameters;
			SettingProperties.QuickChoice      = OptionSettingsItem.QuickChoice;
			SettingProperties.RestrictSelectionBySpecifiedValues = OptionSettingsItem.RestrictSelectionBySpecifiedValues;
		EndIf;
		
		If OptionSettingsItem.State = "DeletionMark" Then
			Information.HasNonexistingFields = True;
			HasMarkedItems = True;
		Else
			HasUnmarkedItems = True;
		EndIf;
	EndDo;
	
	If HasMarkedItems AND Not HasUnmarkedItems AND Parent <> Owner Then
		Parent.State = "DeletionMark";
	EndIf;
EndProcedure

Procedure RegisterField(Information, DCNode, DCItem, OptionSettingsItem)
	If IsBlankString(OptionSettingsItem.ID) Then
		ID = String(OptionSettingsItem.TreeRow.DCID);
		If Not IsBlankString(ID) Then
			ID = ID + "_";
		EndIf;
		OptionSettingsItem.ID = ID + OptionSettingsItem.CollectionName + "_" + String(OptionSettingsItem.DCID);
	EndIf;
	OptionSettingsItem.ItemID = ReportsClientServer.CastIDToName(OptionSettingsItem.ID);
	
	If OptionSettingsItem.Type = "SettingsParameterValue" Then
		OptionSettingsItem.DCField = New DataCompositionField("DataParameters." + String(DCItem.Parameter));
		AvailableParameters = DCNode.AvailableParameters;
		If AvailableParameters = Undefined Then
			Return;
		EndIf;
		AvailableDCSetting = AvailableParameters.FindParameter(DCItem.Parameter);
		If AvailableDCSetting = Undefined Then
			Return;
		EndIf;
		// AvailableDCSetting has the DataCompositionAvailableParameter type:
		//   Visibility - Boolean - parameter visibility on editing values.
		//   Parameter - DataCompositionParameter - a parameter name.
		//   Value - Arbitrary - the initial value.
		//   ValueListAvailable - Boolean - Можно ли указывать несколько значений.
		//   AvailableValues - ValueList, Undefined - values available for selection.
		//   QuickChoice, ChoiceFoldersAndItems, DenyIncompleteValues,
		//   Use, Mask, TypeLink, ChoiceForm, EditFormat.
		If Not AvailableDCSetting.Visible Then
			OptionSettingsItem.OutputAllowed = False;
		EndIf;
		OptionSettingsItem.AvailableDCSetting = AvailableDCSetting;
		OptionSettingsItem.Value = DCItem.Value;
		If AvailableDCSetting.ValueListAllowed Then
			OptionSettingsItem.ComparisonType = DataCompositionComparisonType.InList;
		Else
			OptionSettingsItem.ComparisonType = DataCompositionComparisonType.Equal;
		EndIf;
		If AvailableDCSetting.Use = DataCompositionParameterUse.Always Then
			OptionSettingsItem.OutputFlag = False;
		EndIf;
	Else
		OptionSettingsItem.DCField       = DCItem.LeftValue;
		OptionSettingsItem.Value     = DCItem.RightValue;
		OptionSettingsItem.ComparisonType = DCItem.ComparisonType;
		FilterAvailableFields = DCNode.FilterAvailableFields;
		If FilterAvailableFields = Undefined Then
			Return;
		EndIf;
		AvailableDCSetting = FilterAvailableFields.FindField(DCItem.LeftValue);
		If AvailableDCSetting = Undefined Then
			Return;
		EndIf;
		// AvailableDCSetting has the DataCompositionFilterAvailableField type.
		OptionSettingsItem.AvailableDCSetting = AvailableDCSetting;
	EndIf;
	
	If OptionSettingsItem.ComparisonType = DataCompositionComparisonType.InList
		Or OptionSettingsItem.ComparisonType = DataCompositionComparisonType.InListByHierarchy
		Or OptionSettingsItem.ComparisonType = DataCompositionComparisonType.NotInList
		Or OptionSettingsItem.ComparisonType = DataCompositionComparisonType.NotInListByHierarchy Then
		OptionSettingsItem.ListInput = True;
		OptionSettingsItem.ChoiceFoldersAndItems = FoldersAndItems.FoldersAndItems;
	ElsIf OptionSettingsItem.ComparisonType = DataCompositionComparisonType.InHierarchy
		Or OptionSettingsItem.ComparisonType = DataCompositionComparisonType.NotInHierarchy Then
		OptionSettingsItem.ChoiceFoldersAndItems = FoldersAndItems.Folders;
	Else
		OptionSettingsItem.ChoiceFoldersAndItems = ReportsClientServer.CastValueToGroupsAndItemsType(AvailableDCSetting.ChoiceFoldersAndItems);
	EndIf;
	
	OptionSettingsItem.TypeDescription = AvailableDCSetting.ValueType;
	OptionSettingsItem.ChoiceForm   = AvailableDCSetting.ChoiceForm;
	OptionSettingsItem.QuickChoice  = AvailableDCSetting.QuickChoice;
	
	If Information.Search.OptionSettingsByDCField.Get(OptionSettingsItem.DCField) = Undefined Then
		Information.Search.OptionSettingsByDCField.Insert(OptionSettingsItem.DCField, OptionSettingsItem);
	EndIf;
	
EndProcedure

Procedure RegisterTypesAndLinks(Information, OptionSettingsItem)
	
	///////////////////////////////////////////////////////////////////
	// Information on types.
	
	OptionSettingsItem.MetadataRelations     = New Array;
	OptionSettingsItem.ChoiceParameterLinks = New Array;
	OptionSettingsItem.ChoiceParameters       = New Array;
	
	If OptionSettingsItem.ListInput Then
		OptionSettingsItem.MarkedValues = ReportsClientServer.ValuesByList(OptionSettingsItem.Value);
	EndIf;
	OptionSettingsItem.SelectionValuesQuery = New Query;
	OptionSettingsItem.ValuesForSelection = New ValueList;
	
	TypesInformation = ReportsClientServer.TypesAnalysis(OptionSettingsItem.TypeDescription, True);
	TypesInformation.Insert("ContainsRefTypes", False);
	TypesInformation.Insert("NumberOfItemsWithQuickAccess", 0);
	AllTypesWithQuickChoice = TypesInformation.TypesCount < 10
		AND (TypesInformation.TypesCount = TypesInformation.ObjectTypes.Count());
	
	For Each Type In TypesInformation.ObjectTypes Do
		MetadataObject = Metadata.FindByType(Type);
		FullName = Information.MetadataObjectNamesMap.Get(Type);
		If FullName = Undefined Then // Registering a metadata object name.
			If MetadataObject = Undefined Then
				FullName = -1;
			Else
				FullName = MetadataObject.FullName();
			EndIf;
			Information.MetadataObjectNamesMap.Insert(Type, FullName);
		EndIf;
		If FullName = -1 Then
			AllTypesWithQuickChoice = False;
			Continue;
		EndIf;
		
		TypesInformation.ContainsRefTypes = True;
		
		If AllTypesWithQuickChoice Then
			Kind = Upper(StrSplit(FullName, ".")[0]);
			If Kind <> "ENUM" Then
				If Kind = "CATALOG"
					Or Kind = "CHARTOFCALCULATIONTYPES"
					Or Kind = "CHARTOFCHARACTERISTICTYPES"
					Or Kind = "EXCHANGEPLAN"
					Or Kind = "CHARTOFACCOUNTS" Then
					If MetadataObject.ChoiceMode <> Metadata.ObjectProperties.ChoiceMode.QuickChoice Then
						AllTypesWithQuickChoice = False;
					EndIf;
				Else
					AllTypesWithQuickChoice = False;
				EndIf;
			EndIf;
		EndIf;
		
		// Search for a type in the global links among subordinates.
		FoundItems = Information.Links.MetadataObjects.FindRows(New Structure("SubordinateType", Type));
		For Each LinkByMetadata In FoundItems Do // Registering a setting as subordinate.
			LinkByMetadata.HasSubordinate = True;
			LinkByMetadata.SubordinateSettingsItems.Add(OptionSettingsItem);
		EndDo;
		
		// Search for a type in the global links among leading.
		If OptionSettingsItem.ComparisonType = DataCompositionComparisonType.Equal Then
			// The field can be leading if it has the "Equal" comparison kind.
			FoundItems = Information.Links.MetadataObjects.FindRows(New Structure("MainType", Type));
			For Each LinkByMetadata In FoundItems Do // Registering a setting as leading.
				LinkByMetadata.HasParent = True;
				LinkByMetadata.LeadingItems.Add(OptionSettingsItem);
			EndDo;
		EndIf;
	EndDo;
	
	// Only enumerations or types with quick selection.
	If AllTypesWithQuickChoice AND TypesInformation.ObjectTypes.Count() = TypesInformation.TypesCount Then
		OptionSettingsItem.QuickChoice = True;
	EndIf;
	
	OptionSettingsItem.TypesInformation = TypesInformation;
	OptionSettingsItem.TypeDescription = TypesInformation.TypesDetailsForForm;
	
	///////////////////////////////////////////////////////////////////
	// Information on selection links and parameters.
	
	AvailableDCSetting = OptionSettingsItem.AvailableDCSetting;
	If AvailableDCSetting = Undefined Then
		Return;
	EndIf;
	
	If ValueIsFilled(AvailableDCSetting.TypeLink) Then
		LinkRow = Information.Links.ByType.Add();
		LinkRow.SubordinateSettingsItem   = OptionSettingsItem;
		LinkRow.MasterDCField = AvailableDCSetting.TypeLink.Field;
		LinkRow.SubordinateParameterName = AvailableDCSetting.TypeLink.LinkItem;
	EndIf;
	
	For Each LinkRow In AvailableDCSetting.GetChoiceParameterLinks() Do
		If IsBlankString(String(LinkRow.Field)) Then
			Continue;
		EndIf;
		ParametersLinkRow = Information.Links.SelectionParameters.Add();
		ParametersLinkRow.SubordinateSettingsItem             = OptionSettingsItem;
		ParametersLinkRow.SubordinateParameterName = LinkRow.Name;
		ParametersLinkRow.MasterDCField           = LinkRow.Field;
		ParametersLinkRow.Action                = LinkRow.ValueChange;
	EndDo;
	
	For Each DCChoiceParameters In AvailableDCSetting.GetChoiceParameters() Do
		OptionSettingsItem.ChoiceParameters.Add(New ChoiceParameter(DCChoiceParameters.Name, DCChoiceParameters.Value));
	EndDo;
	
	///////////////////////////////////////////////////////////////////
	// Value list.
	
	If TypeOf(AvailableDCSetting.AvailableValues) = Type("ValueList") Then
		OptionSettingsItem.ValuesForSelection = AvailableDCSetting.AvailableValues;
		OptionSettingsItem.RestrictSelectionBySpecifiedValues = OptionSettingsItem.ValuesForSelection.Count() > 0;
	Else
		EarlierSavedSettings = Information.AdditionalItemsSettings[OptionSettingsItem.ItemID];
		Limit = CommonClientServer.StructureProperty(EarlierSavedSettings, "RestrictSelectionBySpecifiedValues");
		If EarlierSavedSettings <> Undefined AND Limit = False Then
			OldValuesForSelection = CommonClientServer.StructureProperty(EarlierSavedSettings, "ValuesForSelection");
			If TypeOf(OldValuesForSelection) = Type("ValueList") Then
				OptionSettingsItem.ValuesForSelection.ValueType = OptionSettingsItem.TypeDescription;
				For Each OldListItem In OldValuesForSelection Do
					If Not OptionSettingsItem.TypeDescription.ContainsType(TypeOf(OldListItem.Value)) Then
						Continue;
					EndIf;
					If OptionSettingsItem.ValuesForSelection.FindByValue(OldListItem.Value) <> Undefined Then
						Continue;
					EndIf;
					DestinationItem = OptionSettingsItem.ValuesForSelection.Add();
					DestinationItem.Value = OldListItem.Value;
				EndDo;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

Procedure OnDefineSelectionParameters(Information, OptionSettingsItem)
	PresentationBefore = String(OptionSettingsItem.ValuesForSelection);
	CountBefore = OptionSettingsItem.ValuesForSelection.Count();
	
	// Extension functionality.
	// Global settings of type output.
	ReportsOverridable.OnDefineSelectionParameters(Undefined, OptionSettingsItem);
	// Local override for a report.
	If Information.ReportSettings.Events.OnDefineSelectionParameters Then
		ReportObject(Information.ReportObjectOrFullName).OnDefineSelectionParameters(Undefined, OptionSettingsItem);
	EndIf;
	
	// Automatic filling.
	If OptionSettingsItem.SelectionValuesQuery.Text <> "" Then
		ValuesToAdd = OptionSettingsItem.SelectionValuesQuery.Execute().Unload().UnloadColumn(0);
		For Each ValueInForm In ValuesToAdd Do
			ReportsClientServer.AddUniqueValueToList(OptionSettingsItem.ValuesForSelection, ValueInForm, Undefined, False);
		EndDo;
		OptionSettingsItem.ValuesForSelection.SortByPresentation(SortDirection.Asc);
	EndIf;
	
	// Deleting values that cannot be selected.
	If OptionSettingsItem.ListInput
		AND OptionSettingsItem.RestrictSelectionBySpecifiedValues
		AND TypeOf(OptionSettingsItem.Value) = Type("ValueList")
		AND TypeOf(OptionSettingsItem.ValuesForSelection) = Type("ValueList") Then
		List = OptionSettingsItem.Value;
		Count = List.Count();
		For Number = 1 To Count Do
			ReverseIndex = Count - Number;
			Value = List[ReverseIndex].Value;
			If OptionSettingsItem.ValuesForSelection.FindByValue(Value) = Undefined Then
				List.Delete(ReverseIndex);
			EndIf;
		EndDo;
	EndIf;
	
	If CountBefore <> OptionSettingsItem.ValuesForSelection.Count()
		Or PresentationBefore <> String(OptionSettingsItem.ValuesForSelection) Then
		OptionSettingsItem.ValueListRedefined = True;
	EndIf;
EndProcedure

Procedure RegisterLinksFromMasterItems(Information)
	Links = Information.Links;
	
	// Register the link of choice parameters (dynamic link disabled by the Usage checkbox).
	FoundItems = Links.MetadataObjects.FindRows(New Structure("HasSubordinate, HasParent", True, True));
	For Each LinkByMetadata In FoundItems Do
		For Each Master In LinkByMetadata.LeadingItems Do
			For Each SubordinateSettingsItem In LinkByMetadata.SubordinateSettingsItems Do
				If Master.OutputAllowed Then // Link to be disabled.
					LinkDetails = New Structure;
					LinkDetails.Insert("LinkType",                "ByMetadata");
					LinkDetails.Insert("Master",                 Master);
					LinkDetails.Insert("SubordinateSettingsItem",             SubordinateSettingsItem);
					LinkDetails.Insert("MainType",              LinkByMetadata.MainType);
					LinkDetails.Insert("SubordinateType",          LinkByMetadata.SubordinateType);
					LinkDetails.Insert("SubordinateParameterName", LinkByMetadata.SubordinateAttribute);
					Information.LinksThatCanBeDisabled.Add(LinkDetails);
					SubordinateSettingsItem.MetadataRelations.Add(LinkDetails);
				Else // Fixed choice parameter.
					SubordinateSettingsItem.ChoiceParameters.Add(New ChoiceParameter(LinkByMetadata.SubordinateAttribute, Master.Value));
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	// Links by type.
	For Each LinkByType In Links.ByType Do
		Master = Information.Search.OptionSettingsByDCField.Get(LinkByType.MasterDCField);
		If Master = Undefined Then
			Continue;
		EndIf;
		SubordinateSettingsItem = LinkByType.SubordinateSettingsItem;
		If Master.OutputAllowed Then // Link to be disabled.
			LinkDetails = New Structure;
			LinkDetails.Insert("LinkType",                "ByType");
			LinkDetails.Insert("Master",                 Master);
			LinkDetails.Insert("SubordinateSettingsItem",             SubordinateSettingsItem);
			LinkDetails.Insert("SubordinateParameterName", LinkByType.SubordinateParameterName);
			Information.LinksThatCanBeDisabled.Add(LinkDetails);
			SubordinateSettingsItem.TypeLink = LinkDetails;
		Else // Fixed type restriction.
			TypesArray = New Array;
			TypesArray.Add(TypeOf(Master.Value));
			SubordinateSettingsItem.TypeRestriction = New TypeDescription(TypesArray);
		EndIf;
	EndDo;
	
	// Selection parameters links.
	For Each ChoiceParametersLink In Links.SelectionParameters Do
		Master     = ChoiceParametersLink.Master;
		SubordinateSettingsItem = ChoiceParametersLink.SubordinateSettingsItem;
		If Master = Undefined Then
			BestOption = 99;
			FoundItems = Information.OptionSettings.Rows.FindRows(New Structure("DCField", ChoiceParametersLink.MasterDCField), True);
			For Each PotentialParent In FoundItems Do
				If PotentialParent.Type <> "FilterItem"
					AND PotentialParent.Type <> "SettingsParameterValue" Then
					Continue;
				EndIf;
				If PotentialParent.Parent = SubordinateSettingsItem.Parent Then // Items in one group.
					If Not IsBlankString(PotentialParent.ItemID) Then // Master is displayed to the user.
						Master = PotentialParent;
						BestOption = 0;
						Break; // The best option.
					Else
						Master = PotentialParent;
						BestOption = 1;
					EndIf;
				ElsIf BestOption > 2 AND PotentialParent.Owner = SubordinateSettingsItem.Owner Then // Items in one collection.
					If Not IsBlankString(PotentialParent.ItemID) Then // Master is displayed to the user.
						If BestOption > 2 Then
							Master = PotentialParent;
							BestOption = 2;
						EndIf;
					Else
						If BestOption > 3 Then
							Master = PotentialParent;
							BestOption = 3;
						EndIf;
					EndIf;
				ElsIf BestOption > 4 AND PotentialParent.TreeRow = SubordinateSettingsItem.TreeRow Then // Items in one node.
					If Not IsBlankString(PotentialParent.ItemID) Then // Master is displayed to the user.
						If BestOption > 4 Then
							Master = PotentialParent;
							BestOption = 4;
						EndIf;
					Else
						If BestOption > 5 Then
							Master = PotentialParent;
							BestOption = 5;
						EndIf;
					EndIf;
				ElsIf BestOption > 6 Then
					Master = PotentialParent;
					BestOption = 6;
				EndIf;
			EndDo;
			If Master = Undefined Then
				Continue;
			EndIf;
		EndIf;
		If Master.OutputAllowed Then // Link to be disabled.
			LinkDetails = New Structure;
			LinkDetails.Insert("LinkType",      "SelectionParameters");
			LinkDetails.Insert("Master",       Master);
			LinkDetails.Insert("SubordinateSettingsItem",   SubordinateSettingsItem);
			LinkDetails.Insert("SubordinateParameterName", ChoiceParametersLink.SubordinateParameterName);
			LinkDetails.Insert("SubordinateAction",     ChoiceParametersLink.Action);
			Information.LinksThatCanBeDisabled.Add(LinkDetails);
			SubordinateSettingsItem.ChoiceParameterLinks.Add(LinkDetails);
		Else // Fixed choice parameter.
			If TypeOf(Master.Value) = Type("DataCompositionField") Then
				Continue; // Extended operations with filters by the data composition field are not supported.
			EndIf;
			Try
				ValueIsFilled = ValueIsFilled(Master.Value);
			Except
				ValueIsFilled = True;
			EndTry;
			If Not ValueIsFilled Then
				Continue;
			EndIf;
			SubordinateSettingsItem.ChoiceParameters.Add(New ChoiceParameter(ChoiceParametersLink.SubordinateParameterName, Master.Value));
		EndIf;
	EndDo;
EndProcedure

Procedure SetFixedFilters(FiltersStructure, DCSettings, ReportSettings) Export
	If TypeOf(DCSettings) <> Type("DataCompositionSettings")
		Or FiltersStructure = Undefined
		Or FiltersStructure.Count() = 0 Then
		Return;
	EndIf;
	DCParameters = DCSettings.DataParameters;
	DCFilters = DCSettings.Filter;
	Unavailable = DataCompositionSettingsItemViewMode.Inaccessible;
	For Each KeyAndValue In FiltersStructure Do
		Name = KeyAndValue.Key;
		Value = KeyAndValue.Value;
		If TypeOf(Value) = Type("FixedArray") Then
			Value = New Array(Value);
		EndIf;
		If TypeOf(Value) = Type("Array") Then
			List = New ValueList;
			List.LoadValues(Value);
			Value = List;
		EndIf;
		DCParameter = DCParameters.FindParameterValue(New DataCompositionParameter(Name));
		If TypeOf(DCParameter) = Type("DataCompositionSettingsParameterValue") Then
			DCParameter.UserSettingID = "";
			DCParameter.Use    = True;
			DCParameter.ViewMode = Unavailable;
			DCParameter.Value         = Value;
			Continue;
		EndIf;
		If TypeOf(Value) = Type("ValueList") Then
			DCComparisonType = DataCompositionComparisonType.InList;
		Else
			DCComparisonType = DataCompositionComparisonType.Equal;
		EndIf;
		CommonClientServer.SetFilterItem(DCFilters, Name, Value, DCComparisonType, , True, Unavailable, "");
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// User settings

Function RegisterUserSetting(Information, SettingProperties, TreeRow, OptionSettingsItem)
	DCUserSetting = SettingProperties.DCUserSetting;
	
	DisplayMode = DCUserSetting.ViewMode;
	If DisplayMode = DataCompositionSettingsItemViewMode.Inaccessible Then
		Return SettingProperties;
	EndIf;
	
	If Not ValueIsFilled(SettingProperties.ID) Then
		Return SettingProperties;
	EndIf;
	SettingProperties.ItemID = ReportsClientServer.CastIDToName(SettingProperties.ID);
	
	If OptionSettingsItem <> Undefined Then
		If OptionSettingsItem.Owner <> Undefined Then
			SettingProperties.DCNode = OptionSettingsItem.Owner.DCItem;
		EndIf;
		SettingProperties.TreeRow         = OptionSettingsItem.TreeRow;
		SettingProperties.DCOptionSetting  = OptionSettingsItem.DCItem;
		SettingProperties.OptionSetting    = OptionSettingsItem;
		SettingProperties.Subtype               = OptionSettingsItem.Subtype;
		SettingProperties.DCField               = OptionSettingsItem.DCField;
		SettingProperties.AvailableDCSetting = OptionSettingsItem.AvailableDCSetting;
		SettingProperties.TypesInformation     = OptionSettingsItem.TypesInformation;
		SettingProperties.TypeDescription        = OptionSettingsItem.TypeDescription;
		If DisplayMode = DataCompositionSettingsItemViewMode.Auto Then
			DisplayMode = SettingProperties.DCOptionSetting.ViewMode;
		EndIf;
	Else
		SettingProperties.DCNode              = TreeRow.DCNode;
		SettingProperties.TreeRow        = TreeRow;
		SettingProperties.Type                 = TreeRow.Type;
		SettingProperties.Subtype              = TreeRow.Subtype;
		SettingProperties.DCOptionSetting = SettingProperties.DCNode;
		If DisplayMode = DataCompositionSettingsItemViewMode.Auto Then
			DisplayMode = SettingProperties.DCNode.ViewMode;
		EndIf;
	EndIf;
	
	If DisplayMode = DataCompositionSettingsItemViewMode.QuickAccess Then
		SettingProperties.Quick = True;
		Information.HasQuickSettings = True;
	ElsIf DisplayMode = DataCompositionSettingsItemViewMode.Normal Then
		SettingProperties.Ordinary = True;
		Information.HasRegularSettings = True;
	ElsIf Information.UserSettingsOnly Then
		Return SettingProperties;
	EndIf;
	
	// Defining an available setting.
	If SettingProperties.Type = "NestedObjectSettings" Then
		SettingProperties.AvailableDCSetting = Information.DCSettings.AvailableObjects.Items.Find(SettingProperties.TreeRow.DCNode.ObjectID);
	EndIf;
	
	If Information.UserSettingsOnly Then
		If Information.QuickOnly Then
			SettingProperties.OutputAllowed = SettingProperties.Quick;
		Else
			SettingProperties.OutputAllowed = True;
		EndIf;
	EndIf;
	
	SettingProperties.OutputFlag = True;
	SettingProperties.OutputFlagOnly = False;
	
	FillSettingPresentationAndState(
		SettingProperties,
		SettingProperties.DCOptionSetting,
		SettingProperties.DCUserSetting,
		SettingProperties.AvailableDCSetting);
	
	If SettingProperties.State = "DeletionMark" Then
		Information.HasNonexistingFields = True;
		SettingProperties.OutputAllowed = False;
	EndIf;
	
	If SettingProperties.Type = "FilterItemsGroup"
		Or SettingProperties.Type = "NestedObjectSettings"
		Or SettingProperties.Type = "Group"
		Or SettingProperties.Type = "Table"
		Or SettingProperties.Type = "TableGroup"
		Or SettingProperties.Type = "Chart"
		Or SettingProperties.Type = "ChartGroup"
		Or SettingProperties.Type = "ConditionalAppearanceItem" Then
		
		SettingProperties.OutputFlagOnly = True;
		
	ElsIf SettingProperties.Type = "SettingsParameterValue"
		Or SettingProperties.Type = "FilterItem" Then
		
		If SettingProperties.Type = "SettingsParameterValue" Then
			SettingProperties.Value = DCUserSetting.Value;
		Else
			SettingProperties.Value = DCUserSetting.RightValue;
		EndIf;
		
		// Defining a setting value type.
		If SettingProperties.Type = "SettingsParameterValue" Then
			If SettingProperties.AvailableDCSetting.Use = DataCompositionParameterUse.Always Then
				SettingProperties.OutputFlag = False;
				DCUserSetting.Use = True;
			EndIf;
			If SettingProperties.AvailableDCSetting.ValueListAllowed Then
				SettingProperties.ComparisonType = DataCompositionComparisonType.InList;
			Else
				SettingProperties.ComparisonType = DataCompositionComparisonType.Equal;
			EndIf;
		ElsIf SettingProperties.Type = "FilterItem" Then
			SettingProperties.ComparisonType = DCUserSetting.ComparisonType;
		EndIf;
		
		If SettingProperties.TypesInformation.ContainsPeriodType
			AND SettingProperties.TypesInformation.TypesCount = 1 Then
			
			SettingProperties.ItemsType = "StandardPeriod";
			
		ElsIf Not SettingProperties.OutputFlag
			AND SettingProperties.TypesInformation.ContainsBooleanType
			AND SettingProperties.TypesInformation.TypesCount = 1 Then
			
			SettingProperties.ItemsType = "ValueCheckBoxOnly";
			
		ElsIf SettingProperties.ComparisonType = DataCompositionComparisonType.Filled
			Or SettingProperties.ComparisonType = DataCompositionComparisonType.NotFilled Then
			
			SettingProperties.ItemsType = "ConditionInViewingMode";
			
		ElsIf SettingProperties.ComparisonType = DataCompositionComparisonType.InList
			Or SettingProperties.ComparisonType = DataCompositionComparisonType.InListByHierarchy
			Or SettingProperties.ComparisonType = DataCompositionComparisonType.NotInList
			Or SettingProperties.ComparisonType = DataCompositionComparisonType.NotInListByHierarchy Then
			
			SettingProperties.ListInput = True;
			SettingProperties.ItemsType = "ListWithSelection";
			SettingProperties.ChoiceFoldersAndItems = FoldersAndItems.FoldersAndItems;
			
		Else
			
			SettingProperties.ItemsType = "LinkWithComposer";
			If SettingProperties.ComparisonType = DataCompositionComparisonType.InHierarchy
				Or SettingProperties.ComparisonType = DataCompositionComparisonType.NotInHierarchy Then
				SettingProperties.ChoiceFoldersAndItems = FoldersAndItems.Folders;
			EndIf;
			
		EndIf;
		
		If SettingProperties.ChoiceFoldersAndItems = Undefined Then
			SettingProperties.ChoiceFoldersAndItems = OptionSettingsItem.ChoiceFoldersAndItems;
		EndIf;
		
	ElsIf SettingProperties.Type = "SelectedFields"
		Or SettingProperties.Type = "Order"
		Or SettingProperties.Type = "TableStructureItemCollection"
		Or SettingProperties.Type = "ChartStructureItemCollection"
		Or SettingProperties.Type = "Filter"
		Or SettingProperties.Type = "ConditionalAppearance"
		Or SettingProperties.Type = "SettingsStructure" Then
		
		SettingProperties.ItemsType = "LinkWithComposer";
		SettingProperties.OutputFlag = False;
		
	Else
		
		SettingProperties.ItemsType = "LinkWithComposer";
		
	EndIf;
	
	If SettingProperties.OutputFlagOnly Then
		SettingProperties.ItemsType = "";
	ElsIf SettingProperties.Quick AND SettingProperties.ItemsType = "ListWithSelection" Then
		SettingProperties.ItemsType = "LinkWithComposer";
	EndIf;
	
	Return SettingProperties;
EndFunction

Procedure FillSettingPresentationAndState(SettingProperties, DCOptionSetting, DCUserSetting, AvailableDCSetting)
	If DCUserSetting = Undefined Then
		DCUserSetting = DCOptionSetting;
	EndIf;
	
	PresentationStructure = New Structure("Presentation, UserSettingPresentation", "", "");
	FillPropertyValues(PresentationStructure, DCOptionSetting);
	
	SettingProperties.OutputFlagOnly = ValueIsFilled(PresentationStructure.Presentation);
	
	If ValueIsFilled(PresentationStructure.UserSettingPresentation) Then
		Presentation = PresentationStructure.UserSettingPresentation;
	ElsIf ValueIsFilled(PresentationStructure.Presentation) AND PresentationStructure.Presentation <> "1" Then
		Presentation = PresentationStructure.Presentation;
	Else
		Presentation = "";
	EndIf;
	SettingProperties.Presentation = TrimAll(Presentation);
	
	// Default presentation.
	If AvailableDCSetting <> Undefined AND ValueIsFilled(AvailableDCSetting.Title) Then
		DefaultPresentation = AvailableDCSetting.Title;
	ElsIf ValueIsFilled(SettingProperties.Subtype) Then
		If SettingProperties.Subtype = "ChartSeries" Then
			DefaultPresentation = NStr("ru = 'Серии'; en = 'Series'; pl = 'Seria';es_ES = 'Serie';es_CO = 'Serie';tr = 'Seri';it = 'Serie';de = 'Serie'");
		ElsIf SettingProperties.Subtype = "ChartPoints" Then
			DefaultPresentation = NStr("ru = 'Точки'; en = 'Dots'; pl = 'Punkty';es_ES = 'Puntos';es_CO = 'Puntos';tr = 'Noktalar';it = 'Punti';de = 'Punkte'");
		ElsIf SettingProperties.Subtype = "TableRows" Then
			DefaultPresentation = NStr("ru = 'Строки'; en = 'Rows'; pl = 'Wiersze';es_ES = 'Líneas';es_CO = 'Líneas';tr = 'Satırlar';it = 'Righe';de = 'Zeilen'");
		ElsIf SettingProperties.Subtype = "ColumnsTable" Then
			DefaultPresentation = NStr("ru = 'Колонки'; en = 'Columns'; pl = 'Kolumny';es_ES = 'Columnas';es_CO = 'Columnas';tr = 'Sütunlar';it = 'Colonne';de = 'Spalten'");
		ElsIf SettingProperties.Subtype = "Report" Then
			DefaultPresentation = NStr("ru = 'Отчет'; en = 'Report'; pl = 'Deklaracja';es_ES = 'Informe';es_CO = 'Informe';tr = 'Rapor';it = 'Report';de = 'Bericht'");
		Else
			DefaultPresentation = String(SettingProperties.Subtype);
		EndIf;
	
	// Parameters and filters.
	ElsIf SettingProperties.Type = "Filter" Then
		DefaultPresentation = NStr("ru = 'Отбор'; en = 'Filter'; pl = 'Filtr';es_ES = 'Filtro';es_CO = 'Filtro';tr = 'Filtre';it = 'Filtro';de = 'Filter'");
	ElsIf SettingProperties.Type = "FilterItemsGroup" Then
		DefaultPresentation = String(DCOptionSetting.GroupType);
	ElsIf SettingProperties.Type = "FilterItem" Then
		DefaultPresentation = String(DCOptionSetting.LeftValue);
	ElsIf SettingProperties.Type = "SettingsParameterValue" Then
		DefaultPresentation = String(DCOptionSetting.Parameter);
	
	// Sorting.
	ElsIf SettingProperties.Type = "Order" Then
		DefaultPresentation = NStr("ru = 'Сортировка'; en = 'Sort'; pl = 'Sortuj';es_ES = 'Clasificar';es_CO = 'Clasificar';tr = 'Sırala';it = 'Ordinare';de = 'Sortieren'");
	ElsIf SettingProperties.Type = "AutoOrderItem" Then
		DefaultPresentation = NStr("ru = 'Авто (сортировки родителя)'; en = 'Auto (parent sorting)'; pl = 'Auto (sortowania rodzica)';es_ES = 'Auto (clasificaciones de padre)';es_CO = 'Auto (clasificaciones de padre)';tr = 'Oto (ana filtre)';it = 'Auto (ordinamento genitori)';de = 'Automatisch (übergeordnete Sortierung)'");
	ElsIf SettingProperties.Type = "OrderingItem" Then
		DefaultPresentation = String(DCOptionSetting.Field);
	
	// Selected fields.
	ElsIf SettingProperties.Type = "SelectedFields" Then
		DefaultPresentation = NStr("ru = 'Поля'; en = 'Fields'; pl = 'Pola';es_ES = 'Campos';es_CO = 'Campos';tr = 'Alanlar';it = 'Campi';de = 'Felder'");
	ElsIf SettingProperties.Type = "SelectedField" Then
		DefaultPresentation = String(DCOptionSetting.Field);
	ElsIf SettingProperties.Type = "AutoSelectedField" Then
		DefaultPresentation = NStr("ru = 'Авто (поля родителя)'; en = 'Auto (parent field)'; pl = 'Auto (pola rodzica)';es_ES = 'Auto (campo de padre)';es_CO = 'Auto (campo de padre)';tr = 'Oto (ana alan)';it = 'Auto (campo genitore)';de = 'Automatisch (übergeordnete Felder)'");
	ElsIf SettingProperties.Type = "SelectedFieldsGroup" Then
		DefaultPresentation = DCOptionSetting.Title;
		If DCOptionSetting.Placement <> DataCompositionFieldPlacement.Auto Then
			DefaultPresentation = DefaultPresentation + " (" + String(DCOptionSetting.Placement) + ")";
		EndIf;
	
	// Conditional appearance.
	ElsIf SettingProperties.Type = "ConditionalAppearance" Then
		DefaultPresentation = NStr("ru = 'Оформление'; en = 'Appearance'; pl = 'Wygląd';es_ES = 'Formato';es_CO = 'Formato';tr = 'Görünüm';it = 'Aspetto';de = 'Aussehen'");
	ElsIf SettingProperties.Type = "ConditionalAppearanceItem" Then
		DefaultPresentation = ReportsClientServer.ConditionalAppearanceItemPresentation(
			DCUserSetting,
			DCOptionSetting,
			SettingProperties.State);
	
	// Structure.
	ElsIf SettingProperties.Type = "Group"
		Or SettingProperties.Type = "TableGroup"
		Or SettingProperties.Type = "ChartGroup" Then
		DefaultPresentation = TrimAll(String(DCOptionSetting.GroupFields));
		If IsBlankString(DefaultPresentation) Then
			DefaultPresentation = NStr("ru = '<Подробные записи>'; en = '<Detailed records>'; pl = '<Zapisy szczegółowe>';es_ES = '<Registros detallados>';es_CO = '<Detailed records>';tr = '<Ayrıntılı kayıtlar>';it = '<Registrazioni dettagliate>';de = 'Ausführliche Einträge'");
		Else
			AvailableDCFields = DCOptionSetting.GroupFields.GroupFieldsAvailableFields;
			For Each DCGroupField In DCOptionSetting.GroupFields.Items Do
				If TypeOf(DCGroupField) = Type("DataCompositionGroupField")
					AND AvailableDCFields.FindField(DCGroupField.Field) = Undefined Then
					SettingProperties.State = "DeletionMark";
					Break;
				EndIf;
			EndDo;
		EndIf;
	ElsIf SettingProperties.Type = "Table" Then
		DefaultPresentation = NStr("ru = 'Таблица'; en = 'Table'; pl = 'Tabela';es_ES = 'Tabla';es_CO = 'Tabla';tr = 'Tablo';it = 'Tabella';de = 'Tabelle'");
	ElsIf SettingProperties.Type = "Chart" Then
		DefaultPresentation = NStr("ru = 'Диаграмма'; en = 'Chart'; pl = 'Wykres';es_ES = 'Diagrama';es_CO = 'Diagrama';tr = 'Diyagram';it = 'Grafico';de = 'Grafik'");
	ElsIf SettingProperties.Type = "NestedObjectSettings" Then
		DefaultPresentation = String(DCUserSetting);
		If IsBlankString(DefaultPresentation) Then
			DefaultPresentation = NStr("ru = 'Вложенная группировка'; en = 'Nested grouping'; pl = 'Załączone grupowanie';es_ES = 'Añadir la agrupación';es_CO = 'Añadir la agrupación';tr = 'Gruplandırmayı ekle';it = 'Raggruppamento annidato';de = 'Gruppierung anhängen'");
		EndIf;
	ElsIf SettingProperties.Type = "SettingsStructure" Then
		DefaultPresentation = NStr("ru = 'Структура'; en = 'Structure'; pl = 'Struktura';es_ES = 'Estructura';es_CO = 'Estructura';tr = 'Yapı';it = 'Struttura';de = 'Struktur'");
	Else
		DefaultPresentation = String(SettingProperties.Type);
	EndIf;
	SettingProperties.DefaultPresentation = TrimAll(DefaultPresentation);
	
	If SettingProperties.AvailableDCSetting = Undefined
		AND (SettingProperties.Type = "FilterItem"
			Or SettingProperties.Type = "SettingsParameterValue"
			Or SettingProperties.Type = "OrderingItem"
			Or SettingProperties.Type = "SelectedField")Then
		SettingProperties.State = "DeletionMark";
	EndIf;
	
	If Not ValueIsFilled(SettingProperties.Presentation) Then
		SettingProperties.Presentation = SettingProperties.DefaultPresentation;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Secondary

Function TypesDetailsMatch(TypesDetails1, TypesDetails2) Export
	If TypesDetails1 = Undefined Or TypesDetails2 = Undefined Then
		Return False;
	EndIf;
	
	Return TypesDetails1 = TypesDetails2
		Or Common.ValueToXMLString(TypesDetails1) = Common.ValueToXMLString(TypesDetails2);
EndFunction

Function ReportObject(ReportObjectOrFullName) Export
	If TypeOf(ReportObjectOrFullName) = Type("String") Then
		ReportObjectOrFullName = Common.ObjectByFullName(ReportObjectOrFullName);
	EndIf;
	Return ReportObjectOrFullName;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Output

Procedure OutputSettingItems(Form, Items, SettingProperties, OutputGroup, OtherSettings) Export
	OutputItem = New Structure("Size, Item1Name, Item2Name");
	OutputItem.Size = 1;
	
	ItemNameTemplate = SettingProperties.Type + "_%1_" + SettingProperties.ItemID;
	
	// Some field types require a group for output.
	If SettingProperties.ItemsType = "StandardPeriod"
		Or SettingProperties.ItemsType = "ListWithSelection" Then
		GroupName = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "Group");
		
		Folder = Items.Add(GroupName, Type("FormGroup"), Items.Unsorted);
		Folder.Type                 = FormGroupType.UsualGroup;
		Folder.Representation         = UsualGroupRepresentation.None;
		Folder.Title           = SettingProperties.Presentation;
		Folder.ShowTitle = False;
	EndIf;
	
	// Condition.
	OutputCondition = (SettingProperties.Type = "FilterItem"
		AND SettingProperties.ItemsType <> "StandardPeriod"
		AND SettingProperties.ItemsType <> "ValueCheckBoxOnly"
		AND Not SettingProperties.OutputFlagOnly);
	
	If OutputCondition Then
		OtherSettings.HasFiltersWithConditions = True;
		
		ComparisonTypeCommandName = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "ComparisonType");
		ComparisonTypeCommand = Form.Commands.Add(ComparisonTypeCommandName);
		ComparisonTypeCommand.Action    = "Attachable_ChangeComparisonKind";
		ComparisonTypeCommand.Title   = NStr("ru = 'Изменить условие отбора...'; en = 'Change filter criteria...'; pl = 'Zmień warunek wyboru...';es_ES = 'Cambiar la condición de la selección...';es_CO = 'Cambiar la condición de la selección...';tr = 'Seçim şartını değiştir...';it = 'Modifica criteri di filtro...';de = 'Ändern der Auswahlbedingung...'");
		ComparisonTypeCommand.ToolTip   = ComparisonTypeCommand.Title; // For a platform.
		ComparisonTypeCommand.Representation = ButtonRepresentation.Text;
		ComparisonTypeCommand.Picture    = PictureLib.ComparisonType;
	EndIf;
	
	// Usage check box.
	If SettingProperties.OutputFlag Then
		CheckBoxName = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "Use");
		
		If SettingProperties.ItemsType = "ListWithSelection" Then
			GroupForCheckBox = Folder;
			OutputItem.Item1Name = GroupName;
		Else
			GroupForCheckBox = Items.Unsorted;
			OutputItem.Item1Name = CheckBoxName;
		EndIf;
		
		CheckBoxTitle = SettingProperties.Presentation;
		If OutputCondition
			AND SettingProperties.ComparisonType <> DataCompositionComparisonType.Equal
			AND SettingProperties.ComparisonType <> DataCompositionComparisonType.InList
			AND SettingProperties.ComparisonType <> DataCompositionComparisonType.InListByHierarchy
			AND SettingProperties.ComparisonType <> DataCompositionComparisonType.Contains
			AND SettingProperties.ItemsType <> "ConditionInViewingMode" Then
			CheckBoxTitle = CheckBoxTitle + " (" + Lower(String(SettingProperties.ComparisonType)) + ")";
		EndIf;
		If Not SettingProperties.OutputFlagOnly Then
			CheckBoxTitle = CheckBoxTitle + ":";
		EndIf;
		
		CheckBox = Items.Add(CheckBoxName, Type("FormField"), GroupForCheckBox);
		CheckBox.Type         = FormFieldType.CheckBoxField;
		CheckBox.Title   = CheckBoxTitle;
		If StrLen(CheckBoxTitle) > 40 Then // If the header is significantly longer than the other headers, wrapping it.
			CheckBox.TitleHeight = 2;
		EndIf;
		CheckBox.DataPath = OtherSettings.PathToComposer + ".UserSettings[" + SettingProperties.IndexInCollection + "].Use";
		CheckBox.TitleLocation = FormItemTitleLocation.Right;
		CheckBox.SetAction("OnChange", "Attachable_UsageCheckBox_OnChange");
		
		If OutputCondition Then
			ButtonName = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "ComparisonKind_Usage");
			ComparisonTypeButton = Items.Add(ButtonName, Type("FormButton"), CheckBox.ContextMenu);
			ComparisonTypeButton.CommandName = ComparisonTypeCommandName;
		EndIf;
	EndIf;
	
	If SettingProperties.Type = "SettingsParameterValue"
		Or SettingProperties.Type = "FilterItem" Then
		
		If SettingProperties.ListInput Then
			SettingProperties.MarkedValues = ReportsClientServer.ValuesByList(SettingProperties.Value);
		EndIf;
		
		// Save setting choice parameters in additional attributes of user settings.
		ItemSettings = New Structure("Presentation, OutputFlag,
		|ListInput, TypeDescription, ChoiceParameters, ValuesForSelection, ValuesForSelectionFilled,
		|QuickChoice, RestrictSelectionBySpecifiedValues, ChoiceFoldersAndItems, ChoiceForm");
		ItemSettings.ChoiceForm = SettingProperties.AvailableDCSetting.ChoiceForm;
		ItemSettings.ValuesForSelectionFilled = False;
		FillPropertyValues(ItemSettings, SettingProperties);
		OtherSettings.AdditionalItemsSettings.Insert(SettingProperties.ItemID, ItemSettings);
	EndIf;
	
	// Fields for values.
	If SettingProperties.ItemsType <> "" Then
		
		TypesInformation = SettingProperties.TypesInformation;
		
		////////////////////////////////////////////////////////////////////////////////
		// OUTPUT.
		
		ValueName = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "Value");
		
		If SettingProperties.ItemsType = "ValueCheckBoxOnly" Then
			
			QuickSettingsAddAttribute(OtherSettings.FillingParameters, ValueName, SettingProperties.TypeDescription);
			
			OutputItem.Item1Name = ValueName;
			
			CheckBoxField = Items.Add(ValueName, Type("FormField"), Folder);
			CheckBoxField.Type                = FormFieldType.CheckBoxField;
			CheckBoxField.Title          = SettingProperties.Presentation;
			If StrLen(SettingProperties.Presentation) > 40 Then // If the header is significantly longer than the other headers, wrapping it.
				CheckBoxField.TitleHeight = 2;
			EndIf;
			CheckBoxField.TitleLocation = FormItemTitleLocation.Right;
			CheckBoxField.SetAction("OnChange", "Attachable_ValueCheckBox_OnChange");
			
			If OutputCondition Then
				ComparisonTypeButton = Items.Add(ComparisonTypeCommandName, Type("FormButton"), CheckBoxField.ContextMenu);
				ComparisonTypeButton.CommandName = ComparisonTypeCommandName;
			EndIf;
			
			OtherSettings.AddedInputFields.Insert(ValueName, SettingProperties.Value);
			
		ElsIf SettingProperties.ItemsType = "ConditionInViewingMode" Then
			
			OutputItem.Item2Name = ValueName;
			
			InputField = Items.Add(ValueName, Type("FormField"), Folder);
			InputField.Type                = FormFieldType.InputField;
			InputField.Title          = SettingProperties.Presentation;
			InputField.TitleLocation = FormItemTitleLocation.None;
			InputField.ReadOnly     = True;
			InputField.DataPath = OtherSettings.PathToComposer + ".UserSettings[" + SettingProperties.IndexInCollection + "].ComparisonType";
			InputField.SetAction("StartChoice", "Attachable_ComparisonKind_StartChoice");
			
			If OutputCondition Then
				ComparisonTypeButton = Items.Add(ComparisonTypeCommandName, Type("FormButton"), InputField.ContextMenu);
				ComparisonTypeButton.CommandName = ComparisonTypeCommandName;
			EndIf;
			
		ElsIf SettingProperties.ItemsType = "LinkWithComposer" Then
			
			OtherSettings.MainFormAttributesNames.Insert(SettingProperties.ItemID, ValueName);
			OtherSettings.NamesOfItemsForEstablishingLinks.Insert(SettingProperties.ItemID, ValueName);
			
			OutputItem.Item2Name = ValueName;
			
			InputField = Items.Add(ValueName, Type("FormField"), Folder);
			InputField.Type                = FormFieldType.InputField;
			InputField.Title          = SettingProperties.Presentation;
			InputField.TitleLocation = FormItemTitleLocation.None;
			If StrLen(SettingProperties.Presentation) > 40 Then // If the header is significantly longer than the other headers, wrapping it.
				InputField.TitleHeight = 2;
			EndIf;
			
			// A link with DCS.
			InputField.DataPath = OtherSettings.PathToComposer + ".UserSettings[" + SettingProperties.IndexInCollection + "].Value";
			
			If SettingProperties.Type = "SettingsParameterValue"
				Or SettingProperties.Type = "FilterItem" Then
				
				InputField.SetAction("OnChange", "Attachable_InputField_OnChange");
				
				If SettingProperties.ListInput Then
					InputField.SetAction("StartChoice", "Attachable_ComposerList_StartChoice");
				EndIf;
				
				InputField.QuickChoice = SettingProperties.QuickChoice;
				FillPropertyValues(InputField, SettingProperties.AvailableDCSetting, "Mask, ChoiceForm, EditFormat");
				
				OutputClearButton = True;
				If SettingProperties.Type = "SettingsParameterValue" Then
					InputField.AutoMarkIncomplete = SettingProperties.AvailableDCSetting.DenyIncompleteValues;
					OutputClearButton = SettingProperties.AvailableDCSetting.Use <> DataCompositionParameterUse.Always;
				EndIf;
				
				InputField.ChoiceFoldersAndItems = SettingProperties.ChoiceFoldersAndItems;
				
				// The following types of input fields do not stretch horizontally and do not have the clear button:
				//     Date, Boolean, Number, Type.
				InputField.OpenButton           = False;
				InputField.SpinButton      = False;
				InputField.ClearButton            = TypesInformation.ContainsObjectTypes AND OutputClearButton;
				InputField.HorizontalStretch = TypesInformation.ContainsObjectTypes;
				
				If Not SettingProperties.ListInput Then
					If SettingProperties.RestrictSelectionBySpecifiedValues
						AND SettingProperties.ValuesForSelection.Count() > 0 Then
						For Each ListItemInForm In SettingProperties.ValuesForSelection Do
							FillPropertyValues(InputField.ChoiceList.Add(), ListItemInForm);
						EndDo;
						InputField.ListChoiceMode      = True;
						InputField.CreateButton           = False;
						InputField.ChoiceButton             = False;
						InputField.DropListButton  = True;
						InputField.HorizontalStretch = True;
					ElsIf SettingProperties.OptionSetting.ChoiceParameterLinks.Count() > 0
						Or SettingProperties.OptionSetting.MetadataRelations.Count() > 0 Then
						// If there are "ByMetadata" or "SelectionParameters" detachable references from a subordinate 
						// object, then the applied logic is used for selection.
						InputField.SetAction("StartChoice", "Attachable_ComposerValue_StartChoice");
					EndIf;
					// For the platform (redefine values available at the client).
					If SettingProperties.OptionSetting.ValueListRedefined Then
						ClientResult = OtherSettings.FillingParameters.Result;
						OwnSelectionLists = CommonClientServer.StructureProperty(ClientResult, "OwnSelectionLists");
						If OwnSelectionLists = Undefined Then
							OwnSelectionLists = New Array;
							ClientResult.Insert("OwnSelectionLists", OwnSelectionLists);
						EndIf;
						If OwnSelectionLists.Find(SettingProperties.ItemID) = Undefined Then
							OwnSelectionLists.Add(SettingProperties.ItemID);
						EndIf;
					EndIf;
				EndIf;
				
				// Increase the field size of the 'Date' type to accommodate the 'StandardBeginningDate' selection options.
				If InputField.HorizontalStretch = False AND TypesInformation.ContainsDateType AND TypesInformation.TypesCount = 1 Then
					InputField.HorizontalStretch = True;
					InputField.AutoMaxWidth   = False;
					InputField.MaxWidth       = 25;
				EndIf;
				
				// Condition.
				If OutputCondition Then
					ComparisonTypeButton = Items.Add(ComparisonTypeCommandName, Type("FormButton"), InputField.ContextMenu);
					ComparisonTypeButton.CommandName = ComparisonTypeCommandName;
				EndIf;
				
			EndIf;
			
		ElsIf SettingProperties.ItemsType = "StandardPeriod" Then
			
			Folder.Group = ChildFormItemsGroup.AlwaysHorizontal;
			
			OutputItem.Size = 1;
			OutputItem.Item2Name = GroupName;
			
			StartPeriodName    = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "Start");
			EndPeriodName = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "End");
			DashName            = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "Dash");
			ChoiceButtonName    = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "ChoiceButton");
			
			// Attributes.
			QuickSettingsAddAttribute(OtherSettings.FillingParameters, ValueName, "StandardPeriod");
			
			// Beginning of an arbitrary period.
			PeriodBeginning = Items.Add(StartPeriodName, Type("FormField"), Folder);
			PeriodBeginning.Type    = FormFieldType.InputField;
			PeriodBeginning.Width = 9;
			PeriodBeginning.HorizontalStretch = False;
			PeriodBeginning.ChoiceButton   = True;
			PeriodBeginning.OpenButton = False;
			PeriodBeginning.ClearButton  = False;
			PeriodBeginning.SpinButton  = False;
			PeriodBeginning.TextEdit = True;
			PeriodBeginning.TitleLocation   = FormItemTitleLocation.None;
			PeriodBeginning.SetAction("OnChange", "Attachable_StandardPeriod_PeriodStart_OnChange");
			
			If SettingProperties.Type = "SettingsParameterValue" Then
				PeriodBeginning.AutoMarkIncomplete = SettingProperties.AvailableDCSetting.DenyIncompleteValues;
			EndIf;
			
			Dash = Items.Add(DashName, Type("FormDecoration"), Folder);
			Dash.Type       = FormDecorationType.Label;
			Dash.Title = Char(8211); // En dash.
			
			// End of an arbitrary period.
			PeriodEnd = Items.Add(EndPeriodName, Type("FormField"), Folder);
			PeriodEnd.Type = FormFieldType.InputField;
			FillPropertyValues(PeriodEnd, PeriodBeginning, "HorizontalStretch, Width, TitleLocation, 
			|TextEdit, ChoiceButton, OpenButton, ClearButton, SpinButton, AutoMarkIncomplete");
			PeriodEnd.SetAction("OnChange", "Attachable_StandardPeriod_PeriodEnd_OnChange");
			
			// A choice button.
			ChoiceCommand = Form.Commands.Add(ChoiceButtonName);
			ChoiceCommand.Action    = "Attachable_SelectPeriod";
			ChoiceCommand.Title   = NStr("ru = 'Выбрать период...'; en = 'Select period ...'; pl = 'Wybierz okres...';es_ES = 'Seleccionar un período...';es_CO = 'Seleccionar un período...';tr = 'Dönem seç...';it = 'Selezione periodo ...';de = 'Zeitraum auswählen...'");
			ChoiceCommand.ToolTip   = ChoiceCommand.Title; // For a platform.
			ChoiceCommand.Representation = ButtonRepresentation.Picture;
			ChoiceCommand.Picture    = PictureLib.Select;
			
			ChoiceButton = Items.Add(ChoiceButtonName, Type("FormButton"), Folder);
			ChoiceButton.CommandName = ChoiceButtonName;
			
			More = New Structure;
			More.Insert("ValueName",        ValueName);
			More.Insert("StartPeriodName",    StartPeriodName);
			More.Insert("EndPeriodName", EndPeriodName);
			SettingProperties.More = More;
			OtherSettings.AddedStandardPeriods.Add(SettingProperties);
			
		ElsIf SettingProperties.ItemsType = "ListWithSelection" Then
			
			Folder.Group = ChildFormItemsGroup.Vertical;
			
			OutputItem.Size = 5;
			OutputItem.Item1Name = GroupName;
			
			GroupTitleName = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "TitleGroup");
			DecorationName       = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "Decoration");
			TableName              = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "ValueList");
			ColumnGroupName        = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "ColumnGroup");
			UsageColumnName = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "Column_Usage");
			ColumnValueName      = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "Column_Value");
			PickButtonName    = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "Selection");
			PasteButtonName  = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "PasteFromClipboard");
			
			OtherSettings.MainFormAttributesNames.Insert(SettingProperties.ItemID, TableName);
			OtherSettings.NamesOfItemsForEstablishingLinks.Insert(SettingProperties.ItemID, ColumnValueName);
			
			If Not SettingProperties.OutputFlag Or Not SettingProperties.RestrictSelectionBySpecifiedValues Then
				
				// Группа-строка для заголовка и командной панели таблицы.
				TitleGroupTables = Items.Add(GroupTitleName, Type("FormGroup"), Folder);
				TitleGroupTables.Type                 = FormGroupType.UsualGroup;
				TitleGroupTables.Group         = ChildFormItemsGroup.AlwaysHorizontal;
				TitleGroupTables.Representation         = UsualGroupRepresentation.None;
				TitleGroupTables.ShowTitle = False;
				
				// The check box is already generated.
				If SettingProperties.OutputFlag Then
					Items.Move(CheckBox, TitleGroupTables);
				EndIf;
				
				// Header / Empty decoration.
				BlankDecoration = Items.Add(DecorationName, Type("FormDecoration"), TitleGroupTables);
				BlankDecoration.Type                      = FormDecorationType.Label;
				BlankDecoration.Title                = ?(SettingProperties.OutputFlag, " ", SettingProperties.Presentation + ":");
				BlankDecoration.AutoMaxWidth   = False;
				BlankDecoration.HorizontalStretch = True;
				
				// Buttons.
				If Not SettingProperties.RestrictSelectionBySpecifiedValues Then
					If TypesInformation.ContainsRefTypes Then
						PickCommand = Form.Commands.Add(PickButtonName);
						PickCommand.Action  = "Attachable_ListWithPicking_Pick";
						PickCommand.Title = NStr("ru = 'Подбор'; en = 'Pickup'; pl = 'Odebrać';es_ES = 'Recopilar';es_CO = 'Recopilar';tr = 'Almak';it = 'Selezione';de = 'Abholen'");
					Else
						PickCommand = Form.Commands.Add(PickButtonName);
						PickCommand.Action  = "Attachable_ListWithPicking_Add";
						PickCommand.Title = NStr("ru = 'Добавить'; en = 'Add'; pl = 'Dodaj';es_ES = 'Añadir';es_CO = 'Añadir';tr = 'Ekle';it = 'Aggiungi';de = 'Hinzufügen'");
						PickCommand.Picture  = PictureLib.CreateListItem;
					EndIf;
					
					PickButton = Items.Add(PickButtonName, Type("FormButton"), TitleGroupTables);
					PickButton.CommandName  = PickButtonName;
					PickButton.Type         = FormButtonType.Hyperlink;
					PickButton.Representation = ButtonRepresentation.Text;
					
					If SettingProperties.TypesInformation.ContainsRefTypes AND OtherSettings.HasDataImportFromFile Then
						PasteCommand = Form.Commands.Add(PasteButtonName);
						PasteCommand.Action  = "Attachable_ListWithPicking_PasteFromClipboard";
						PasteCommand.Title = NStr("ru = 'Вставить из буфера обмена...'; en = 'Insert from clipboard...'; pl = 'Wstaw ze schowka...';es_ES = 'Insertar desde el portapapeles...';es_CO = 'Insertar desde el portapapeles...';tr = 'Panodan ekle ...';it = 'Incollare dagli appunti...';de = 'Aus der Zwischenablage einfügen...'");
						PasteCommand.ToolTip = PasteCommand.Title; // For a platform.
						PasteCommand.Picture  = PictureLib.PasteFromClipboard;
						
						PasteButton = Items.Add(PasteButtonName, Type("FormButton"), TitleGroupTables);
						PasteButton.CommandName  = PasteButtonName;
						PasteButton.Type         = FormButtonType.Hyperlink;
						PasteButton.Representation = ButtonRepresentation.Picture;
					EndIf;
				EndIf;
				
			EndIf;
			
			// Attribute.
			QuickSettingsAddAttribute(OtherSettings.FillingParameters, TableName, "ValueList");
			
			// A group with an indent and a table.
			GroupWithIndent = Items.Add(GroupName + "Indent", Type("FormGroup"), Folder);
			GroupWithIndent.Type                 = FormGroupType.UsualGroup;
			GroupWithIndent.Group         = ChildFormItemsGroup.AlwaysHorizontal;
			GroupWithIndent.Representation         = UsualGroupRepresentation.None;
			GroupWithIndent.Title           = SettingProperties.Presentation;
			GroupWithIndent.ShowTitle = False;
			
			// An indent decoration.
			BlankDecoration = Items.Add(DecorationName + "Indent", Type("FormDecoration"), GroupWithIndent);
			BlankDecoration.Type                      = FormDecorationType.Label;
			BlankDecoration.Title                = "     ";
			BlankDecoration.HorizontalStretch = False;
			
			// Table.
			FormTable = Items.Add(TableName, Type("FormTable"), GroupWithIndent);
			FormTable.Representation               = TableRepresentation.List;
			FormTable.Title                 = SettingProperties.Presentation;
			FormTable.TitleLocation        = FormItemTitleLocation.None;
			FormTable.CommandBarLocation  = FormItemCommandBarLabelLocation.None;
			FormTable.VerticalLines         = False;
			FormTable.HorizontalLines       = False;
			FormTable.Header                     = False;
			FormTable.Footer                    = False;
			FormTable.ChangeRowOrder      = Not SettingProperties.RestrictSelectionBySpecifiedValues;
			FormTable.ChangeRowSet       = Not SettingProperties.RestrictSelectionBySpecifiedValues;
			FormTable.HorizontalStretch  = True;
			FormTable.VerticalStretch    = True;
			FormTable.Height                    = 3;
			
			If SettingProperties.OutputFlag Then
				If Not SettingProperties.DCUserSetting.Use Then
					FormTable.TextColor = Form.InactiveTableValueColor;
				EndIf;
			EndIf;
			
			// A group of columns "in a cell".
			Columns_Group = Items.Add(ColumnGroupName, Type("FormGroup"), FormTable);
			Columns_Group.Type         = FormGroupType.ColumnGroup;
			Columns_Group.Group = ColumnsGroup.InCell;
			
			// "Usage" column.
			UsageColumnItem = Items.Add(UsageColumnName, Type("FormField"), Columns_Group);
			UsageColumnItem.Type = FormFieldType.CheckBoxField;
			
			// "Value" column.
			ValueColumnItem = Items.Add(ColumnValueName, Type("FormField"), Columns_Group);
			ValueColumnItem.Type = FormFieldType.InputField;
			ValueColumnItem.QuickChoice = SettingProperties.QuickChoice;
			
			FillPropertyValues(ValueColumnItem, SettingProperties.AvailableDCSetting, "Mask, ChoiceForm, EditFormat");
			
			ValueColumnItem.ChoiceFoldersAndItems = SettingProperties.ChoiceFoldersAndItems;
			
			If SettingProperties.RestrictSelectionBySpecifiedValues Then
				ValueColumnItem.ReadOnly = True;
			EndIf;
			
			// Fill in metadata object names broken down by types and items IDs (for predefined objects).
			// It is used when clicking the "Pick" button to get the pick form name.
			If ValueIsFilled(ValueColumnItem.ChoiceForm) Then
				OtherSettings.MetadataObjectNamesMap.Insert(SettingProperties.ItemID, ValueColumnItem.ChoiceForm);
			EndIf;
			
			// Fixed choice parameters.
			If SettingProperties.ChoiceParameters.Count() > 0 Then
				ValueColumnItem.ChoiceParameters = New FixedArray(SettingProperties.ChoiceParameters);
			EndIf;
			
			If OutputCondition Then
				ComparisonTypeButton = Items.Add(ComparisonTypeCommandName, Type("FormButton"), FormTable.ContextMenu);
				ComparisonTypeButton.CommandName  = ComparisonTypeCommandName;
			EndIf;
			
			More = New Structure;
			More.Insert("TableName",              TableName);
			More.Insert("ColumnNameValue",      ColumnValueName);
			More.Insert("ColumnNameUsage", UsageColumnName);
			SettingProperties.More = More;
			OtherSettings.AddedValuesList.Add(SettingProperties);
			
		EndIf;
	EndIf;
	
	If OutputItem.Item1Name = Undefined Then
		TitleName = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "Title");
		LabelField = Items.Add(TitleName, Type("FormDecoration"), Items.Unsorted);
		LabelField.Type       = FormDecorationType.Label;
		LabelField.Title = SettingProperties.Presentation + ":";
		OutputItem.Item1Name = TitleName;
	EndIf;
	
	If SettingProperties.ItemsType = "StandardPeriod" Then
		OutputGroup.Order.Insert(0, OutputItem);
	Else
		OutputGroup.Order.Add(OutputItem);
	EndIf;
	OutputGroup.Size = OutputGroup.Size + OutputItem.Size;
	
	ControlItemsPlacementParameters = CommonClientServer.StructureProperty(Form.ReportSettings, "ControlItemsPlacementParameters");
	
	If ControlItemsPlacementParameters <> Undefined Then
		
		For Each ControlItemPlacementParameter In ControlItemsPlacementParameters Do
		
			SettingsKey     = ControlItemPlacementParameter.Key;
			SettingsValues = ControlItemPlacementParameter.Value;
			
			Settings = Form.Report.SettingsComposer.Settings[SettingsKey].Items;
			
			For Each Setting In Settings Do
			
				For Each SettingValue In SettingsValues Do
				
					ReplacementItem = Undefined;
					
					If SettingsKey = "Filter" Then
						DSCField = New DataCompositionField(SettingValue.Field);
						If DSCField = Setting.LeftValue Then
							ReplacementItem = Items.Find("FilterItem_Value_" + StrReplace(Setting.UserSettingID, "-", ""));
						EndIf;
					ElsIf SettingsKey = "DataParameters" Then
						DSCParameter = New DataCompositionParameter(SettingValue.Field);
						If DSCParameter = Setting.Parameter Then
							ReplacementItem = Items.Find("SettingsParameterValue_Value_" + StrReplace(Setting.UserSettingID, "-", ""));
						EndIf;
					EndIf;
					
					If ReplacementItem <> Undefined Then
						FillPropertyValues(ReplacementItem, SettingValue);
					EndIf;
					
				EndDo;
				
			EndDo;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure QuickSettingsAddAttribute(FillingParameters, AttributeFullName, AttributeType)
	If TypeOf(AttributeType) = Type("TypeDescription") Then
		TypesOfItemsToAdd = AttributeType;
	ElsIf TypeOf(AttributeType) = Type("String") Then
		TypesOfItemsToAdd = New TypeDescription(AttributeType);
	ElsIf TypeOf(AttributeType) = Type("Array") Then
		TypesOfItemsToAdd = New TypeDescription(AttributeType);
	ElsIf TypeOf(AttributeType) = Type("Type") Then
		TypesArray = New Array;
		TypesArray.Add(AttributeType);
		TypesOfItemsToAdd = New TypeDescription(TypesArray);
	Else
		Return;
	EndIf;
	
	TypesOfExistingItems = FillingParameters.Attributes.Existing.Get(AttributeFullName);
	If TypesDetailsMatch(TypesOfExistingItems, TypesOfItemsToAdd) Then
		FillingParameters.Attributes.Existing.Delete(AttributeFullName);
	Else
		PointPosition = StrFind(AttributeFullName, ".");
		If PointPosition = 0 Then
			AttributePath = "";
			AttributeShortName = AttributeFullName;
		Else
			AttributePath = Left(AttributeFullName, PointPosition - 1);
			AttributeShortName = Mid(AttributeFullName, PointPosition + 1);
		EndIf;
		
		FillingParameters.Attributes.ItemsToAdd.Add(New FormAttribute(AttributeShortName, TypesOfItemsToAdd, AttributePath));
		If TypesOfExistingItems <> Undefined Then
			FillingParameters.Attributes.ToDelete.Add(AttributeFullName);
			FillingParameters.Attributes.Existing.Delete(AttributeFullName);
		EndIf;
	EndIf;
EndProcedure

Procedure OutputInOrder(Form, OutputGroup, Parent, ColumnsNumber, FlexibleBalancing = True) Export
	Items = Form.Items;
	If FlexibleBalancing Then
		If OutputGroup.Size <= 7 Then
			ColumnsNumber = 1;
		EndIf;
	EndIf;
	
	ParentName = Parent.Name;
	
	ColumnNumber = 0;
	ColumnsLeft = ColumnsNumber + 1;
	TotalSpaceLeft = OutputGroup.Size;
	SpaceLeftInColumn = 0;
	
	For Each OutputItem In OutputGroup.Order Do
		If ColumnsLeft > 0
			AND OutputItem.Size > SpaceLeftInColumn*4 Then // The current step is greater than the remaining space.
			ColumnNumber = ColumnNumber + 1;
			ColumnsLeft = ColumnsLeft - 1;
			SpaceLeftInColumn = TotalSpaceLeft/ColumnsLeft;
			
			HigherLevelColumn = Items.Add(ParentName + ColumnNumber, Type("FormGroup"), Items[ParentName]);
			HigherLevelColumn.Type                 = FormGroupType.UsualGroup;
			HigherLevelColumn.Group         = ChildFormItemsGroup.Vertical;
			HigherLevelColumn.Representation         = UsualGroupRepresentation.None;
			HigherLevelColumn.ShowTitle = False;
			
			SubgroupNumber = 0;
			CurrentGroup1 = Undefined;
			CurrentGroup2 = Undefined;
		EndIf;
		
		If OutputItem.Item2Name = Undefined Then
			// Output to one column.
			CurrentGroup2 = Undefined;
			Items.Move(Items[OutputItem.Item1Name], HigherLevelColumn);
		Else
			// Output to two columns.
			If CurrentGroup2 = Undefined Then
				SubgroupNumber = SubgroupNumber + 1;
				
				Columns = Items.Add(ParentName + ColumnNumber + "_" + SubgroupNumber, Type("FormGroup"), HigherLevelColumn);
				Columns.Type                 = FormGroupType.UsualGroup;
				Columns.Group         = ChildFormItemsGroup.AlwaysHorizontal;
				Columns.Representation         = UsualGroupRepresentation.None;
				Columns.ShowTitle = False;
				
				CurrentGroup1 = Items.Add(ParentName + ColumnNumber + "_" + SubgroupNumber + "_1", Type("FormGroup"), Columns);
				CurrentGroup1.Type                 = FormGroupType.UsualGroup;
				CurrentGroup1.Group         = ChildFormItemsGroup.Vertical;
				CurrentGroup1.Representation         = UsualGroupRepresentation.None;
				CurrentGroup1.ShowTitle = False;
				CurrentGroup1.United        = False;
				
				CurrentGroup2 = Items.Add(ParentName + ColumnNumber + "_" + SubgroupNumber + "_2", Type("FormGroup"), Columns);
				CurrentGroup2.Type                 = FormGroupType.UsualGroup;
				CurrentGroup2.Group         = ChildFormItemsGroup.Vertical;
				CurrentGroup2.Representation         = UsualGroupRepresentation.None;
				CurrentGroup2.ShowTitle = False;
				CurrentGroup2.United        = False;
			EndIf;
			Items.Move(Items[OutputItem.Item1Name], CurrentGroup1);
			Items.Move(Items[OutputItem.Item2Name], CurrentGroup2);
		EndIf;
		
		TotalSpaceLeft = TotalSpaceLeft - OutputItem.Size;
		SpaceLeftInColumn = SpaceLeftInColumn - OutputItem.Size;
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Saving a form status

Function RememberSelectedRows(Form, TableName, KeyColumns) Export
	TableAttribute = Form[TableName];
	TableItem = Form.Items[TableName];
	
	Result = New Structure;
	Result.Insert("Selected", New Array);
	Result.Insert("Current", Undefined);
	
	CurrentRowID = TableItem.CurrentRow;
	If CurrentRowID <> Undefined Then
		TableRow = TableAttribute.FindByID(CurrentRowID);
		If TableRow <> Undefined Then
			RowData = New Structure(KeyColumns);
			FillPropertyValues(RowData, TableRow);
			Result.Current = RowData;
		EndIf;
	EndIf;
	
	SelectedRows = TableItem.SelectedRows;
	If SelectedRows <> Undefined Then
		For Each SelectedID In SelectedRows Do
			If SelectedID = CurrentRowID Then
				Continue;
			EndIf;
			TableRow = TableAttribute.FindByID(SelectedID);
			If TableRow <> Undefined Then
				RowData = New Structure(KeyColumns);
				FillPropertyValues(RowData, TableRow);
				Result.Selected.Add(RowData);
			EndIf;
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

Procedure RestoreSelectedRows(Form, TableName, TableRows) Export
	TableAttribute = Form[TableName];
	TableItem = Form.Items[TableName];
	
	TableItem.SelectedRows.Clear();
	
	If TableRows.Current <> Undefined Then
		FoundItems = ReportsClientServer.FindTableRows(TableAttribute, TableRows.Current);
		If FoundItems <> Undefined AND FoundItems.Count() > 0 Then
			For Each TableRow In FoundItems Do
				If TableRow <> Undefined Then
					ID = TableRow.GetID();
					TableItem.CurrentRow = ID;
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	For Each RowData In TableRows.Selected Do
		FoundItems = ReportsClientServer.FindTableRows(TableAttribute, RowData);
		If FoundItems <> Undefined AND FoundItems.Count() > 0 Then
			For Each TableRow In FoundItems Do
				If TableRow <> Undefined Then
					TableItem.SelectedRows.Add(TableRow.GetID());
				EndIf;
			EndDo;
		EndIf;
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Period

Function StandardPeriodAnalysis(Val Option)
	Result = New Structure("PeriodType, PeriodOffset");
	
	If Option = StandardPeriodVariant.ThisYear Then
		Result.PeriodType   = "Year";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.LastYear Then
		Result.PeriodType   = "Year";
		Result.PeriodOffset = -1;
		
	ElsIf Option = StandardPeriodVariant.NextYear Then
		Result.PeriodType   = "Year";
		Result.PeriodOffset = 1;
		
	ElsIf Option = StandardPeriodVariant.FromBeginningOfThisYear Then
		Result.PeriodType   = "SinceBeginningOfYear";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.LastYearTillSameDate Then
		Result.PeriodType   = "SinceBeginningOfYear";
		Result.PeriodOffset = -1
		
	ElsIf Option = StandardPeriodVariant.NextYearTillSameDate Then
		Result.PeriodType   = "SinceBeginningOfYear";
		Result.PeriodOffset = 1;
		
	ElsIf Option = StandardPeriodVariant.TillEndOfThisYear Then
		Result.PeriodType   = "TillYearEnd";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.ThisHalfYear Then
		Result.PeriodType   = "HalfYear";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.LastHalfYear Then
		Result.PeriodType   = "HalfYear";
		Result.PeriodOffset = -1;
		
	ElsIf Option = StandardPeriodVariant.NextHalfYear Then
		Result.PeriodType   = "HalfYear";
		Result.PeriodOffset = 1;
		
	ElsIf Option = StandardPeriodVariant.FromBeginningOfThisHalfYear Then
		Result.PeriodType   = "SinceBeginningOfHalfYear";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.LastHalfYearTillSameDate Then
		Result.PeriodType   = "SinceBeginningOfHalfYear";
		Result.PeriodOffset = -1;
		
	ElsIf Option = StandardPeriodVariant.NextHalfYearTillSameDate Then
		Result.PeriodType   = "SinceBeginningOfHalfYear";
		Result.PeriodOffset = 1;
		
	ElsIf Option = StandardPeriodVariant.TillEndOfThisHalfYear Then
		Result.PeriodType   = "TillHalfYearEnd";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.ThisQuarter Then
		Result.PeriodType   = "Quarter";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.LastQuarter Then
		Result.PeriodType   = "Quarter";
		Result.PeriodOffset = -1;
		
	ElsIf Option = StandardPeriodVariant.NextQuarter Then
		Result.PeriodType   = "Quarter";
		Result.PeriodOffset = 1;
		
	ElsIf Option = StandardPeriodVariant.FromBeginningOfThisQuarter Then
		Result.PeriodType   = "SinceBeginningOfQuarter";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.LastQuarterTillSameDate Then
		Result.PeriodType   = "SinceBeginningOfQuarter";
		Result.PeriodOffset = -1;
		
	ElsIf Option = StandardPeriodVariant.NextQuarterTillSameDate Then
		Result.PeriodType   = "SinceBeginningOfQuarter";
		Result.PeriodOffset = 1;
		
	ElsIf Option = StandardPeriodVariant.TillEndOfThisQuarter Then
		Result.PeriodType   = "TillQuarterEnd";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.ThisMonth Then
		Result.PeriodType   = "Month";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.LastMonth Then
		Result.PeriodType   = "Month";
		Result.PeriodOffset = -1;
		
	ElsIf Option = StandardPeriodVariant.NextMonth Then
		Result.PeriodType   = "Month";
		Result.PeriodOffset = 1;
		
	ElsIf Option = StandardPeriodVariant.Month Then
		Result.PeriodType   = "LastMonth";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.FromBeginningOfThisMonth Then
		Result.PeriodType   = "SinceBeginningOfMonth";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.LastMonthTillSameDate Then
		Result.PeriodType   = "SinceBeginningOfMonth";
		Result.PeriodOffset = -1;
		
	ElsIf Option = StandardPeriodVariant.NextMonthTillSameDate Then
		Result.PeriodType   = "SinceBeginningOfMonth";
		Result.PeriodOffset = 1;
		
	ElsIf Option = StandardPeriodVariant.TillEndOfThisMonth Then
		Result.PeriodType   = "TillMonthEnd";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.ThisTenDays Then
		Result.PeriodType   = "TenDays";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.LastTenDays Then
		Result.PeriodType   = "TenDays";
		Result.PeriodOffset = -1;
		
	ElsIf Option = StandardPeriodVariant.NextTenDays Then
		Result.PeriodType   = "TenDays";
		Result.PeriodOffset = 1;
		
	ElsIf Option = StandardPeriodVariant.FromBeginningOfThisTenDays Then
		Result.PeriodType   = "SinceBeginningOfTenDayPeriod";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.LastTenDaysTillSameDayNumber Then
		Result.PeriodType   = "SinceBeginningOfTenDayPeriod";
		Result.PeriodOffset = -1;
		
	ElsIf Option = StandardPeriodVariant.NextTenDaysTillSameDayNumber Then
		Result.PeriodType   = "SinceBeginningOfTenDayPeriod";
		Result.PeriodOffset = 1;
		
	ElsIf Option = StandardPeriodVariant.TillEndOfThisTenDays Then
		Result.PeriodType   = "TillTenDaysPeriodEnd";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.ThisWeek Then
		Result.PeriodType   = "Week";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.LastWeek Then
		Result.PeriodType   = "Week";
		Result.PeriodOffset = -1;
		
	ElsIf Option = StandardPeriodVariant.NextWeek Then
		Result.PeriodType   = "Week";
		Result.PeriodOffset = 1;
		
	ElsIf Option = StandardPeriodVariant.Last7Days Then
		Result.PeriodType   = "Last7Days";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.Next7Days Then
		Result.PeriodType   = "Next7Days";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.FromBeginningOfThisWeek Then
		Result.PeriodType   = "SinceBeginningOfWeek";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.LastWeekTillSameWeekDay Then
		Result.PeriodType   = "SinceBeginningOfWeek";
		Result.PeriodOffset = -1
		
	ElsIf Option = StandardPeriodVariant.NextWeekTillSameWeekDay Then
		Result.PeriodType   = "SinceBeginningOfWeek";
		Result.PeriodOffset = 1
		
	ElsIf Option = StandardPeriodVariant.TillEndOfThisWeek Then
		Result.PeriodType   = "TillWeekEnd";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.Today Then
		Result.PeriodType   = "Day";
		Result.PeriodOffset = 0;
		
	ElsIf Option = StandardPeriodVariant.Yesterday Then
		Result.PeriodType   = "Day";
		Result.PeriodOffset = -1;
		
	ElsIf Option = StandardPeriodVariant.Tomorrow Then
		Result.PeriodType   = "Day";
		Result.PeriodOffset = 1;
		
	EndIf;
	
	Return Result;
EndFunction

Function ArbitraryPeriodAnalysis(Val BeginOfPeriod, Val EndOfPeriod)
	Result = New Structure("PeriodType, PeriodOffset");
	
	BeginOfPeriod = BegOfDay(BeginOfPeriod);
	EndOfPeriod  = BegOfDay(EndOfPeriod);
	Today       = BegOfDay(CurrentSessionDate());
	DaysInPeriod    = (EndOfPeriod - BeginOfPeriod) / 86400 + 1;
	EndShiftInDays = (EndOfPeriod - Today) / 86400;
	
	If DaysInPeriod = 1 Then
		Result.PeriodType   = "Day";
		Result.PeriodOffset = EndShiftInDays;
		Return Result;
	EndIf;
	
	If DaysInPeriod <= 7 Then
		BeginingWeekDay  = WeekDay(BeginOfPeriod);
		EndWeekDay   = WeekDay(EndOfPeriod);
		CurrentWeekDay = WeekDay(Today);
		If BeginingWeekDay = 1 AND EndWeekDay = 7 Then
			Result.PeriodType = "Week";
			Result.PeriodOffset = (BegOfWeek(EndOfPeriod) - BegOfWeek(Today)) / 604800;
		ElsIf BeginingWeekDay = 1 AND EndWeekDay = CurrentWeekDay Then
			Result.PeriodType = "SinceBeginningOfWeek";
			Result.PeriodOffset = (BegOfWeek(EndOfPeriod) - BegOfWeek(Today)) / 604800;
		ElsIf BeginingWeekDay = CurrentWeekDay AND EndWeekDay = 7 Then
			Result.PeriodType = "TillWeekEnd";
			Result.PeriodOffset = (BegOfWeek(EndOfPeriod) - BegOfWeek(Today)) / 604800;
		ElsIf EndWeekDay = CurrentWeekDay AND DaysInPeriod = 7 Then
			Result.PeriodType = "Last7Days";
			Result.PeriodOffset = (BegOfWeek(EndOfPeriod) - BegOfWeek(Today)) / 604800;
		ElsIf BeginingWeekDay = CurrentWeekDay AND DaysInPeriod = 7 Then
			Result.PeriodType = "Next7Days";
			Result.PeriodOffset = (BegOfWeek(BeginOfPeriod) - BegOfWeek(Today)) / 604800;
		EndIf;
		If Result.PeriodType <> Undefined Then
			Return Result;
		EndIf;
	EndIf;
	
	EndYearNumber   = Year(EndOfPeriod);
	CurrentYearNumber = Year(Today);
	
	BeginingMonthNumber  = Month(BeginOfPeriod);
	EndMonthNumber   = Month(EndOfPeriod);
	CurrentMonthNumber = Month(Today);
	
	EndShiftInYears   = EndYearNumber - CurrentYearNumber;
	EndShiftInMonths = EndShiftInYears*12 + EndMonthNumber - CurrentMonthNumber;
	
	BeginingDayOfMonth  = Day(BeginOfPeriod);
	EndDayOfMonth   = Day(EndOfPeriod);
	CurrentDayOfMonth = Day(Today);
	
	EndIsLastDayOfMonth = EndDayOfMonth >= 27 AND EndDayOfMonth = Day(EndOfMonth(EndOfPeriod));
	
	If DaysInPeriod <= 31 Then
		If BeginingDayOfMonth = 1 AND EndIsLastDayOfMonth Then
			Result.PeriodType   = "Month";
			Result.PeriodOffset = EndShiftInMonths;
			Return Result;
		ElsIf BeginingDayOfMonth = 1 AND EndDayOfMonth = CurrentDayOfMonth Then
			Result.PeriodType   = "SinceBeginningOfMonth";
			Result.PeriodOffset = EndShiftInMonths;
			Return Result;
		ElsIf BeginingDayOfMonth = CurrentDayOfMonth AND EndIsLastDayOfMonth Then
			Result.PeriodType   = "TillMonthEnd";
			Result.PeriodOffset = EndShiftInMonths;
			Return Result;
		ElsIf EndDayOfMonth = CurrentDayOfMonth AND BeginOfPeriod = AddMonth(EndOfPeriod + 86400, -1) Then
			Result.PeriodType   = "LastMonth";
			Result.PeriodOffset = EndShiftInMonths;
			Return Result;
		EndIf;
	EndIf;
	
	If DaysInPeriod <= 93 Then // Easy optimization of calculations.
		BeginingNumberOfMonthInQuarter = (BeginingMonthNumber-1)%3 + 1;
		EndNumberOfMonthInQuarter  = (EndMonthNumber-1)%3 + 1;
		
		BeginingIsBegOfQuarter = (BeginingNumberOfMonthInQuarter = 1 AND BeginingDayOfMonth = 1);
		EndIsEndOfQuarter   = (EndNumberOfMonthInQuarter  = 3 AND EndIsLastDayOfMonth);
		
		If BeginingIsBegOfQuarter Or EndIsEndOfQuarter Then // Easy optimization of calculations.
			
			CurrentNumberOfMonthInQuarter = (CurrentMonthNumber-1)%3 + 1;
			
			If BeginingIsBegOfQuarter AND EndIsEndOfQuarter Then
				Result.PeriodType = "Quarter";
			ElsIf BeginingIsBegOfQuarter
				AND EndNumberOfMonthInQuarter = CurrentNumberOfMonthInQuarter
				AND EndDayOfMonth = CurrentDayOfMonth Then
				Result.PeriodType = "SinceBeginningOfQuarter";
			ElsIf EndIsEndOfQuarter
				AND BeginingNumberOfMonthInQuarter = CurrentNumberOfMonthInQuarter
				AND BeginingDayOfMonth = CurrentDayOfMonth Then
				Result.PeriodType = "TillQuarterEnd";
			EndIf;
			
			If Result.PeriodType <> Undefined Then // Easy optimization of calculations.
				EndNumberOfQuarterInYear   = Int((EndMonthNumber-1)/3)+1;
				CurrentNumberOfQuarterInYear = Int((CurrentMonthNumber-1)/3)+1;
				Result.PeriodOffset = EndShiftInYears*4 + EndNumberOfQuarterInYear - CurrentNumberOfQuarterInYear;
				Return Result;
			EndIf;
			
		EndIf;
	EndIf;
	
	If DaysInPeriod <= 186 Then // Easy optimization of calculations.
		StartNumberOfMonthInHalfYear = (BeginingMonthNumber-1)%6 + 1;
		EndNumberOfMonthInHalfYear  = (EndMonthNumber-1)%6 + 1;
		
		BeginingIsBegOfHalfYear = (StartNumberOfMonthInHalfYear = 1 AND BeginingDayOfMonth = 1);
		EndIsEndOfHalfYear   = (EndNumberOfMonthInHalfYear  = 6 AND EndIsLastDayOfMonth);
		
		If BeginingIsBegOfHalfYear Or EndIsEndOfHalfYear Then // Easy optimization of calculations.
			
			CurrentNumberOfMonthInHalfYear = (CurrentMonthNumber-1)%6 + 1;
			
			If BeginingIsBegOfHalfYear AND EndIsEndOfHalfYear Then
				Result.PeriodType = "HalfYear";
			ElsIf BeginingIsBegOfHalfYear
				AND EndNumberOfMonthInHalfYear = CurrentNumberOfMonthInHalfYear
				AND EndDayOfMonth = CurrentDayOfMonth Then
				Result.PeriodType = "SinceBeginningOfHalfYear";
			ElsIf EndIsEndOfHalfYear
				AND StartNumberOfMonthInHalfYear = CurrentNumberOfMonthInHalfYear
				AND BeginingDayOfMonth = CurrentDayOfMonth Then
				Result.PeriodType = "TillHalfYearEnd";
			EndIf;
			
			If Result.PeriodType <> Undefined Then // Easy optimization of calculations.
				EndNumberOfHalfYearInYear   = ?(EndMonthNumber   <= 6, 1, 2);
				CurrentNumberOfHalfYearInYear = ?(CurrentMonthNumber <= 6, 1, 2);
				Result.PeriodOffset = EndShiftInYears*2 + EndNumberOfHalfYearInYear - CurrentNumberOfHalfYearInYear;
				Return Result;
			EndIf;
			
		EndIf;
	EndIf;
	
	If DaysInPeriod <= 366 Then // Easy optimization of calculations.
		
		BeginingIsBegOfYear = (BeginingMonthNumber = 1 AND BeginingDayOfMonth = 1);
		EndIsEndOfYear   = (EndMonthNumber  = 12 AND EndIsLastDayOfMonth);
		
		If BeginingIsBegOfYear Or EndIsEndOfYear Then // Easy optimization of calculations.
			
			If BeginingIsBegOfYear AND EndIsEndOfYear Then
				Result.PeriodType   = "Year";
				Result.PeriodOffset = EndShiftInYears;
				Return Result;
			ElsIf BeginingIsBegOfYear
				AND EndMonthNumber = CurrentMonthNumber
				AND EndDayOfMonth  = CurrentDayOfMonth Then
				Result.PeriodType   = "SinceBeginningOfYear";
				Result.PeriodOffset = EndShiftInYears;
				Return Result;
			ElsIf EndIsEndOfYear
				AND BeginingMonthNumber = CurrentMonthNumber
				AND BeginingDayOfMonth  = CurrentDayOfMonth Then
				Result.PeriodType   = "TillYearEnd";
				Result.PeriodOffset = EndShiftInYears;
				Return Result;
			EndIf;
		EndIf;
	EndIf;
	
	If DaysInPeriod <= 11 Then
		BeginingIsBegOfTenDays = (BeginingDayOfMonth = 1 Or BeginingDayOfMonth = 11 Or BeginingDayOfMonth = 21);
		EndIsEndOfTenDays   = (EndDayOfMonth = 10 Or EndDayOfMonth = 20 Or EndIsLastDayOfMonth);
		If BeginingIsBegOfTenDays AND EndIsEndOfTenDays Then
			Result.PeriodType = "TenDays";
		Else
			BeginingDayOfTenDays  = (BeginingDayOfMonth-1)%10 + 1; // % this is remainder of the division.
			EndDayOfTenDays   = (EndDayOfMonth-1)%10 + 1;
			CurrentDayOfTenDays = (CurrentDayOfMonth-1)%10 + 1;
			If BeginingIsBegOfTenDays AND EndDayOfTenDays = CurrentDayOfTenDays Then
				Result.PeriodType = "SinceBeginningOfTenDayPeriod";
			ElsIf BeginingDayOfTenDays = CurrentDayOfTenDays AND EndIsEndOfTenDays Then
				Result.PeriodType = "TillTenDaysPeriodEnd";
			EndIf;
		EndIf;
		If Result.PeriodType <> Undefined Then
			EndNumberOfTenDaysInMonth   = ?(EndDayOfMonth   <= 10, 1, ?(EndDayOfMonth   <= 20, 2, 3));
			CurrentNumberOfTenDaysInMonth = ?(CurrentDayOfMonth <= 10, 1, ?(CurrentDayOfMonth <= 20, 2, 3));
			Result.PeriodOffset = EndShiftInMonths*3 + EndNumberOfTenDaysInMonth - CurrentNumberOfTenDaysInMonth;
			Return Result;
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Report is blank

// Checks if there are external data sets.
//
// Parameters:
//   DataSets - DataCompositionTemplateDataSets - a collection of data sets to be checked.
//
// Returns:
//   Boolean - True if there are external data sets.
//
Function ThereIsExternalDataSet(DataSets)
	
	For Each DataSet In DataSets Do
		
		If TypeOf(DataSet) = Type("DataCompositionTemplateDataSetObject") Then
			
			Return True;
			
		ElsIf TypeOf(DataSet) = Type("DataCompositionTemplateDataSetUnion") Then
			
			If ThereIsExternalDataSet(DataSet.Items) Then
				
				Return True;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Selection parameters

Function TypeChoiceParameters(Val Type, Val SetupParameters) Export
	MetadataObject = Metadata.FindByType(Type);
	If MetadataObject = Undefined Then
		Return Undefined;
	EndIf;
	
	Result = New Structure("QuickChoice, FormPath, ValuesForSelection");
	
	FullName = MetadataObject.FullName();
	Kind = Upper(StrSplit(FullName, ".")[0]);
	
	If SetupParameters.QuickChoice = True Then
		Result.QuickChoice = True;
	ElsIf Kind = "ENUM" Then
		Result.QuickChoice = True;
	ElsIf Kind = "CATALOG"
		Or Kind = "CHARTOFCALCULATIONTYPES"
		Or Kind = "CHARTOFCHARACTERISTICTYPES"
		Or Kind = "EXCHANGEPLAN"
		Or Kind = "CHARTOFACCOUNTS" Then
		Result.QuickChoice = (MetadataObject.ChoiceMode = Metadata.ObjectProperties.ChoiceMode.QuickChoice);
	Else
		Result.QuickChoice = False;
	EndIf;
	
	If Result.QuickChoice Then
		Result.ValuesForSelection = ValuesForSelection(SetupParameters, Type);
		If Result.ValuesForSelection.Count() = 0 Then
			Result.QuickChoice = False;
		EndIf;	
	EndIf;
	
	If SetupParameters.ChoiceFoldersAndItems = FoldersAndItemsUse.Folders Then
		If Kind = "CATALOG" Or Kind = "CHARTOFCHARACTERISTICTYPES" Then
			Result.FormPath = FullName + ".FolderChoiceForm";
		Else
			Result.FormPath = FullName + ".ChoiceForm";
		EndIf;
	Else
		Result.FormPath = FullName + ".ChoiceForm";
	EndIf;
	
	Return Result;
EndFunction

Function ValuesForSelection(SetupParameters, TypeOrTypes = Undefined) Export
	GettingChoiceDataParameters = New Structure("Filter, ChoiceFoldersAndItems");
	FillPropertyValues(GettingChoiceDataParameters, SetupParameters);
	AddItemsFromChoiceParametersToStructure(GettingChoiceDataParameters, SetupParameters.ChoiceParameters);
	
	ValuesForSelection = New ValueList;
	If TypeOf(TypeOrTypes) = Type("Type") Then
		Types = New Array;
		Types.Add(TypeOrTypes);
	ElsIf TypeOf(TypeOrTypes) = Type("Array") Then
		Types = TypeOrTypes;
	Else
		Types = SetupParameters.TypeDescription.Types();
	EndIf;
	
	For Each Type In Types Do
		MetadataObject = Metadata.FindByType(Type);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		Manager = Common.ObjectManagerByFullName(MetadataObject.FullName());
		
		ChoiceList = Manager.GetChoiceData(GettingChoiceDataParameters);
		For Each ListItem In ChoiceList Do
			ValueForSelection = ValuesForSelection.Add();
			FillPropertyValues(ValueForSelection, ListItem);
			
			// For enumerations, values are returned as a structure with the Value property.
			EnumValue = Undefined;
			If TypeOf(ValueForSelection.Value) = Type("Structure") 
				AND ValueForSelection.Value.Property("Value", EnumValue) Then
				ValueForSelection.Value = EnumValue;
			EndIf;	
				
		EndDo;
	EndDo;
	Return ValuesForSelection;
EndFunction

Procedure AddItemsFromChoiceParametersToStructure(Structure, ChoiceParametersArray)
	For Each ChoiceParameter In ChoiceParametersArray Do
		CurrentStructure = Structure;
		RowsArray = StrSplit(ChoiceParameter.Name, ".");
		Count = RowsArray.Count();
		If Count > 1 Then
			For Index = 0 To Count-2 Do
				varKey = RowsArray[Index];
				If CurrentStructure.Property(varKey) AND TypeOf(CurrentStructure[varKey]) = Type("Structure") Then
					CurrentStructure = CurrentStructure[varKey];
				Else
					CurrentStructure = CurrentStructure.Insert(varKey, New Structure);
				EndIf;
			EndDo;
		EndIf;
		varKey = RowsArray[Count-1];
		CurrentStructure.Insert(varKey, ChoiceParameter.Value);
	EndDo;
EndProcedure

#EndRegion
