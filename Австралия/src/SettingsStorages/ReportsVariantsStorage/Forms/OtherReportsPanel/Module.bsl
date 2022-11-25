#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, Parameters, "OptionRef, ReportRef, SubsystemRef, ReportDescription");
	Items.OtherReportOptionsGroup.Title = ReportDescription + " (" + NStr("ru = 'report options'; en = 'report options'; pl = 'report options';es_ES = 'report options';es_CO = 'report options';tr = 'report options';it = 'report options';de = 'report options'") + "):";
	
	If ClientApplication.CurrentInterfaceVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		ReportsOptionsGroupColor = StyleColors.ReportOptionsGroupColor82;
		NormalGroupFont = New Font("MS Shell Dlg", 8, True, False, False, False, 100);
	Else // Taxi.
		ReportsOptionsGroupColor = StyleColors.ReportOptionsGroupColor;
		NormalGroupFont = New Font("Arial", 12, False, False, False, False, 90);
	EndIf;
	Items.OtherReportOptionsGroup.TitleTextColor = ReportsOptionsGroupColor;
	Items.OtherReportOptionsGroup.TitleFont = NormalGroupFont;
	
	ReadThisFormSettings();
	
	WindowOptionsKey = String(OptionRef.UUID()) + "\" + String(SubsystemRef.UUID());
	
	FillInReportPanel();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CloseThisWindowAfterMoveToReportOnChange(Item)
	SaveThisFormSettings();
EndProcedure

&AtClient
Procedure Attachable_OptionClick(Item)
	FoundItems = PanelOptions.FindRows(New Structure("LabelName", Item.Name));
	If FoundItems.Count() <> 1 Then
		Return;
	EndIf;
	Option = FoundItems[0];
	
	ReportsOptionsClient.OpenReportForm(FormOwner, Option, New Structure("Subsystem", SubsystemRef));
	
	If CloseAfterChoice Then
		Close();
	EndIf;
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Server call, Server

&AtServer
Procedure SaveThisFormSettings()
	FormSettings = DefaultSettings();
	FillPropertyValues(FormSettings, ThisObject);
	Common.FormDataSettingsStorageSave(
		ReportsOptionsClientServer.FullSubsystemName(),
		"OtherReportsPanel", 
		FormSettings);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Procedure ReadThisFormSettings()
	DefaultSettings = DefaultSettings();
	Items.CloseAfterChoice.Visible = DefaultSettings.ShowCheckBox;
	FormSettings = Common.CommonSettingsStorageLoad(
		ReportsOptionsClientServer.FullSubsystemName(),
		"OtherReportsPanel",
		DefaultSettings);
	FillPropertyValues(ThisObject, FormSettings);
EndProcedure

&AtServer
Function DefaultSettings()
	Return ReportsOptions.GlobalSettings().OtherReports;
EndFunction

&AtServer
Procedure FillInReportPanel()
	OtherReportsAvailable = False;
	
	OutputTable = FormAttributeToValue("PanelOptions");
	OutputTable.Columns.Add("ItemMustBeAdded", New TypeDescription("Boolean"));
	OutputTable.Columns.Add("KeepThisItem", New TypeDescription("Boolean"));
	OutputTable.Columns.Add("Group");
	
	QueryText =
	"SELECT ALLOWED
	|	ReportsOptions.Ref,
	|	ReportsOptions.Report,
	|	ReportsOptions.VariantKey,
	|	ReportsOptions.Description AS Description,
	|	CASE
	|		WHEN SUBSTRING(ReportsOptions.Details, 1, 1) = """"
	|			THEN CAST(ReportsOptions.PredefinedVariant.Details AS STRING(1000))
	|		ELSE CAST(ReportsOptions.Details AS STRING(1000))
	|	END AS Details,
	|	ReportsOptions.Author,
	|	ReportsOptions.Custom,
	|	ReportsOptions.ReportType,
	|	ReportsOptions.Report.Name AS ReportName
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Report = &Report
	|	AND ReportsOptions.DeletionMark = FALSE
	|	AND (ReportsOptions.AvailableToAuthorOnly = FALSE
	|			OR ReportsOptions.Author = &CurrentUser)
	|	AND NOT ReportsOptions.PredefinedVariant IN (&DIsabledApplicationOptions)
	|	AND ReportsOptions.VariantKey <> """"
	|
	|ORDER BY
	|	Description";
	
	Query = New Query;
	Query.SetParameter("Report", ReportRef);
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	Query.SetParameter("DIsabledApplicationOptions", ReportsOptionsCached.DIsabledApplicationOptions());
	Query.Text = QueryText;
	
	CommonSettings = ReportsOptions.CommonPanelSettings();
	ShowTooltips = CommonSettings.ShowTooltips = 1;
	
	ReportOptionsTable = Query.Execute().Unload();
	For Each TableRow In ReportOptionsTable Do
		// Other options only.
		If TableRow.Ref = OptionRef Then
			Continue;
		EndIf;
		OtherReportsAvailable = True;
		OutputHyperlinkToPanel(OutputTable, TableRow, Items.OtherReportOptionsGroup, ShowTooltips);
	EndDo;
	Items.OtherReportOptionsGroup.Visible = (ReportOptionsTable.Count() > 0);
	
	If ValueIsFilled(SubsystemRef) Then
		Subsystems = Subsystems();
		
		SearchParameters = New Structure;
		SearchParameters.Insert("Subsystems", Subsystems);
		SearchParameters.Insert("OnlyItemsVisibleInReportPanel", True);
		SearchParameters.Insert("GetSummaryTable", True);
		
		SearchResult = ReportsOptions.FindLinks(SearchParameters);
		
		ReportOptionsTable = SearchResult.ValueTable;
		ReportOptionsTable.Columns.OptionDescription.Name = "Description";
		ReportOptionsTable.Sort("Description");
		
		// Deleting rows that correspond to the current (currently open) option.
		FoundItems = ReportOptionsTable.FindRows(New Structure("Ref", OptionRef));
		For Each TableRow In FoundItems Do
			ReportOptionsTable.Delete(TableRow);
		EndDo;
		
		// Subsystem iteration and found options output.
		For Each SubsystemRef In Subsystems Do
			FoundItems = ReportOptionsTable.FindRows(New Structure("Subsystem", SubsystemRef));
			If FoundItems.Count() = 0 Then
				Continue;
			EndIf;
			
			Folder = DetermineOutputGroup(FoundItems[0].SubsystemDescription);
			For Each TableRow In FoundItems Do
				OtherReportsAvailable = True;
				OutputHyperlinkToPanel(OutputTable, TableRow, Folder, ShowTooltips);
			EndDo;
		EndDo;
	EndIf;
	
	// PanelOptionsItemNumber
	ItemsFoundForRemoving = OutputTable.FindRows(New Structure("KeepThisItem", False));
	For Each TableRow In ItemsFoundForRemoving Do
		OptionItem = Items.Find(TableRow.LabelName);
		If OptionItem <> Undefined Then
			Items.Delete(OptionItem);
		EndIf;
		OutputTable.Delete(TableRow);
	EndDo;
	
	OutputTable.Columns.Delete("KeepThisItem");
	OutputTable.Columns.Delete("Group");
	ValueToFormAttribute(OutputTable, "PanelOptions");
EndProcedure

&AtServer
Procedure OutputHyperlinkToPanel(OutputTable, Option, Folder, ShowTooltips)
	
	FoundItems = OutputTable.FindRows(New Structure("Ref, Group", Option.Ref, Folder.Name));
	If FoundItems.Count() > 0 Then
		OutputRow = FoundItems[0];
		OutputRow.KeepThisItem = True;
		Return;
	EndIf;
	
	OutputRow = OutputTable.Add();
	FillPropertyValues(OutputRow, Option);
	PanelOptionsItemNumber = PanelOptionsItemNumber + 1;
	OutputRow.LabelName = "Variant" + Format(PanelOptionsItemNumber, "NG=");
	OutputRow.Additional = (Option.ReportType = Enums.ReportTypes.Additional);
	OutputRow.NameOfGroup = Folder.Name;
	OutputRow.KeepThisItem = True;
	OutputRow.Group = Folder;
	
	// Add a report option hyperlink title.
	Label = Items.Insert(OutputRow.LabelName, Type("FormDecoration"), OutputRow.Group);
	Label.Type = FormDecorationType.Label;
	Label.Hyperlink = True;
	Label.HorizontalStretch = True;
	Label.VerticalStretch = False;
	Label.Height = 1;
	Label.TextColor = StyleColors.HyperlinkColor;
	Label.Title = TrimAll(String(Option.Ref));
	If ValueIsFilled(Option.Details) Then
		Label.ToolTip = TrimAll(Option.Details);
	EndIf;
	If ValueIsFilled(Option.Author) Then
		Label.ToolTip = TrimL(Label.ToolTip + Chars.LF) + NStr("ru = 'Author:'; en = 'Author:'; pl = 'Author:';es_ES = 'Author:';es_CO = 'Author:';tr = 'Author:';it = 'Author:';de = 'Author:'") + " " + TrimAll(String(Option.Author));
	EndIf;
	If ShowTooltips Then
		Label.ToolTipRepresentation = ToolTipRepresentation.ShowBottom;
		Label.ExtendedTooltip.HorizontalStretch = True;
		Label.ExtendedTooltip.TextColor = StyleColors.NoteText;
	EndIf;
	Label.SetAction("Click", "Attachable_OptionClick");
	
EndProcedure

&AtServer
Function Subsystems()
	Result = New Array;
	Result.Add(SubsystemRef);
	
	SubsystemsTree = ReportsOptionsCached.CurrentUserSubsystems();
	FoundItems = SubsystemsTree.Rows.FindRows(New Structure("Ref", SubsystemRef), True);
	While FoundItems.Count() > 0 Do
		RowsCollection = FoundItems[0].Rows;
		FoundItems.Delete(0);
		For Each TreeRow In RowsCollection Do
			Result.Add(TreeRow.Ref);
			FoundItems.Add(TreeRow);
		EndDo;
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Function DetermineOutputGroup(SubsystemPresentation)
	ListItem = SubsystemsGroups.FindByValue(SubsystemPresentation);
	If ListItem <> Undefined Then
		Return Items.Find(ListItem.Presentation);
	EndIf;
	
	GroupNumber = SubsystemsGroups.Count() + 1;
	DecorationName = "IndentSubsystems_" + GroupNumber;
	GroupName    = "SubsystemsGroup_" + GroupNumber;
	
	If OtherReportsAvailable Then
		Decoration = Items.Add(DecorationName, Type("FormDecoration"), Items.OtherReportsPage);
		Decoration.Type = FormDecorationType.Label;
		Decoration.Title = " ";
	EndIf;
	
	Folder = Items.Add(GroupName, Type("FormGroup"), Items.OtherReportsPage);
	Folder.Type = FormGroupType.UsualGroup;
	Folder.Group = ChildFormItemsGroup.Vertical;
	Folder.Title = SubsystemPresentation;
	Folder.ShowTitle = True;
	Folder.TitleTextColor = ReportsOptionsGroupColor;
	Folder.TitleFont = NormalGroupFont;
	
	SubsystemsGroups.Add(SubsystemPresentation, GroupName);
	Return Folder;
EndFunction

#EndRegion
