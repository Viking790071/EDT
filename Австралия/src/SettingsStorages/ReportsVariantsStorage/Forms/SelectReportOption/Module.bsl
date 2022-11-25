#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	VariantKey = Parameters.CurrentSettingsKey;
	CurrentUser = Users.AuthorizedUser();
	
	ReportInformation = ReportsOptions.GenerateReportInformationByFullName(Parameters.ObjectKey);
	If TypeOf(ReportInformation.ErrorText) = Type("String") Then
		Raise ReportInformation.ErrorText;
	EndIf;
	ReportInformation.Delete("ReportMetadata");
	ReportInformation.Delete("ErrorText");
	ReportInformation.Insert("ReportFullName", Parameters.ObjectKey);
	ReportInformation = New FixedStructure(ReportInformation);
	
	FullRightsToOptions = ReportsOptions.FullRightsToOptions();
	
	If Not FullRightsToOptions Then
		Items.ShowPersonalReportsOptionsByOtherAuthors.Visible = False;
		Items.ShowPersonalReportsOptionsOfOtherAuthorsCM.Visible = False;
		ShowPersonalReportsOptionsByOtherAuthors = False;
	EndIf;
	
	FillOptionsList();
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	Show = Settings.Get("ShowPersonalReportsOptionsByOtherAuthors");
	If Show <> ShowPersonalReportsOptionsByOtherAuthors Then
		ShowPersonalReportsOptionsByOtherAuthors = Show;
		Items.ShowPersonalReportsOptionsByOtherAuthors.Check = Show;
		Items.ShowPersonalReportsOptionsOfOtherAuthorsCM.Check = Show;
		FillOptionsList();
	EndIf;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = ReportsOptionsClientServer.EventNameChangingOption()
		Or EventName = "Write_ConstantsSet" Then
		FillOptionsList();
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterAuthorOnChange(Item)
	FilterEnabled = ValueIsFilled(FilterAuthor);
	
	GroupsOrOptions = ReportOptionsTree.GetItems();
	For Each GroupOrOption In GroupsOrOptions Do
		HasEnabledItems = Undefined;
		NestedOptions = GroupOrOption.GetItems();
		For Each Option In NestedOptions Do
			Option.HiddenByFilter = FilterEnabled AND Option.Author <> FilterAuthor;
			If Not Option.HiddenByFilter Then
				HasEnabledItems = True;
			ElsIf HasEnabledItems = Undefined Then
				HasEnabledItems = False;
			EndIf;
		EndDo;
		If HasEnabledItems = Undefined Then // Group is an option.
			GroupOrOption.HiddenByFilter = FilterEnabled AND GroupOrOption.Author <> FilterAuthor;
		Else // This is folder.
			GroupOrOption.HiddenByFilter = HasEnabledItems;
		EndIf;
	EndDo;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersReportOptionTree

&AtClient
Procedure ReportOptionsTreeOnActivateRow(Item)
	Option = Items.ReportOptionsTree.CurrentData;
	If Option = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Option.VariantKey) Then
		OptionDetails = "";
	Else
		OptionDetails = Option.Details;
	EndIf;
EndProcedure

&AtClient
Procedure ReportOptionsTreeBeforeChangeRow(Item, Cancel)
	Cancel = True;
	OpenOptionForChange();
EndProcedure

&AtClient
Procedure ReportOptionsTreeBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	Cancel = True;
EndProcedure

&AtClient
Procedure ReportOptionsTreeBeforeDelete(Item, Cancel)
	Cancel = True;
	
	Option = Items.ReportOptionsTree.CurrentData;
	If Option = Undefined Or Not ValueIsFilled(Option.VariantKey) Then
		Return;
	EndIf;
	
	If Option.PictureIndex = 4 Then
		QuestionText = NStr("ru = 'Do you want to clear a deletion mark for ""%1""?'; en = 'Do you want to clear a deletion mark for ""%1""?'; pl = 'Do you want to clear a deletion mark for ""%1""?';es_ES = 'Do you want to clear a deletion mark for ""%1""?';es_CO = 'Do you want to clear a deletion mark for ""%1""?';tr = 'Do you want to clear a deletion mark for ""%1""?';it = 'Do you want to clear a deletion mark for ""%1""?';de = 'Do you want to clear a deletion mark for ""%1""?'");
	Else
		QuestionText = NStr("ru = 'Do you want to mark %1 for deletion?'; en = 'Do you want to mark %1 for deletion?'; pl = 'Do you want to mark %1 for deletion?';es_ES = 'Do you want to mark %1 for deletion?';es_CO = 'Do you want to mark %1 for deletion?';tr = 'Do you want to mark %1 for deletion?';it = 'Do you want to mark %1 for deletion?';de = 'Do you want to mark %1 for deletion?'");
	EndIf;
	QuestionText = StringFunctionsClientServer.SubstituteParametersToString(QuestionText, Option.Description);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Variant", Option);
	Handler = New NotifyDescription("ReportOptionsTreeBeforeDeleteCompletion", ThisObject, AdditionalParameters);
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo, 60, DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure ReportOptionsTreeChoice(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	SelectAndClose();
EndProcedure

&AtClient
Procedure ReportOptionsTreeValueChoice(Item, Value, StandardProcessing)
	StandardProcessing = False;
	SelectAndClose();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ShowPersonalReportsOptionsByOtherAuthors(Command)
	ShowPersonalReportsOptionsByOtherAuthors = Not ShowPersonalReportsOptionsByOtherAuthors;
	Items.ShowPersonalReportsOptionsByOtherAuthors.Check = ShowPersonalReportsOptionsByOtherAuthors;
	Items.ShowPersonalReportsOptionsOfOtherAuthorsCM.Check = ShowPersonalReportsOptionsByOtherAuthors;
	
	FillOptionsList();
	
	For Each TreeGroup In ReportOptionsTree.GetItems() Do
		If TreeGroup.HiddenByFilter = False Then
			Items.ReportOptionsTree.Expand(TreeGroup.GetID(), True);
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure Update(Command)
	FillOptionsList();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportOptionsTree.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportOptionsTreePresentation.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportOptionsTreeAuthor.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReportOptionsTree.HiddenByFilter");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);

	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportOptionsTreePresentation.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportOptionsTreeAuthor.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReportOptionsTree.CurrentUserAuthor");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.MyReportOptionsColor);

EndProcedure

&AtClient
Procedure SelectAndClose()
	Option = Items.ReportOptionsTree.CurrentData;
	If Option = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Option.VariantKey) Then
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("VariantKey", Option.VariantKey);
	If Option.PictureIndex = 4 Then
		QuestionText = NStr("ru = 'The selected report option is marked for deletion.
		|Select this report option?'; 
		|en = 'The selected report option is marked for deletion.
		|Select this report option?'; 
		|pl = 'The selected report option is marked for deletion.
		|Select this report option?';
		|es_ES = 'The selected report option is marked for deletion.
		|Select this report option?';
		|es_CO = 'The selected report option is marked for deletion.
		|Select this report option?';
		|tr = 'The selected report option is marked for deletion.
		|Select this report option?';
		|it = 'The selected report option is marked for deletion.
		|Select this report option?';
		|de = 'The selected report option is marked for deletion.
		|Select this report option?'");
		Handler = New NotifyDescription("SelectAndCloseCompletion", ThisObject, AdditionalParameters);
		ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo, 60);
	Else
		SelectAndCloseCompletion(DialogReturnCode.Yes, AdditionalParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectAndCloseCompletion(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		Close(New SettingsChoice(AdditionalParameters.VariantKey));
	EndIf;
EndProcedure

&AtClient
Procedure OpenOptionForChange()
	Option = Items.ReportOptionsTree.CurrentData;
	If Option = Undefined Or Not ValueIsFilled(Option.Ref) Then
		Return;
	EndIf;
	If Not OptionChangeRight(Option, FullRightsToOptions) Then
		WarningText = NStr("ru = 'Insufficient rights to change option ""%1"".'; en = 'Insufficient rights to change option ""%1"".'; pl = 'Insufficient rights to change option ""%1"".';es_ES = 'Insufficient rights to change option ""%1"".';es_CO = 'Insufficient rights to change option ""%1"".';tr = 'Insufficient rights to change option ""%1"".';it = 'Insufficient rights to change option ""%1"".';de = 'Insufficient rights to change option ""%1"".'");
		WarningText = StringFunctionsClientServer.SubstituteParametersToString(WarningText, Option.Description);
		ShowMessageBox(, WarningText);
		Return;
	EndIf;
	ReportsOptionsClient.ShowReportSettings(Option.Ref);
EndProcedure

&AtClient
Procedure ReportOptionsTreeBeforeDeleteCompletion(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		DeleteOptionAtServer(AdditionalParameters.Variant.Ref, AdditionalParameters.Variant.PictureIndex);
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Function OptionChangeRight(Option, FullRightsToOptions)
	Return FullRightsToOptions Or Option.CurrentUserAuthor;
EndFunction

&AtServer
Procedure FillOptionsList()
	
	CurrentOptionKey = VariantKey;
	If ValueIsFilled(Items.ReportOptionsTree.CurrentRow) Then
		CurrentTreeRow = ReportOptionsTree.FindByID(Items.ReportOptionsTree.CurrentRow);
		If ValueIsFilled(CurrentTreeRow.VariantKey) Then
			CurrentOptionKey = CurrentTreeRow.VariantKey;
		EndIf;
	EndIf;
	
	QueryText =
	"SELECT ALLOWED
	|	ReportsOptions.Ref AS Ref,
	|	ReportsOptions.Description AS Description,
	|	ReportsOptions.VariantKey AS VariantKey,
	|	CASE
	|		WHEN SUBSTRING(ReportsOptions.Details, 1, 1) = """"
	|			THEN CAST(ReportsOptions.PredefinedVariant.Details AS STRING(1000))
	|		ELSE CAST(ReportsOptions.Details AS STRING(1000))
	|	END AS Details,
	|	CASE
	|		WHEN NOT ReportsOptions.Custom
	|				AND NOT ReportsOptions.DefaultVisibilityOverridden
	|			THEN ISNULL(ReportsOptions.PredefinedVariant.VisibleByDefault, FALSE)
	|		ELSE ReportsOptions.VisibleByDefault
	|	END AS VisibleByDefault,
	|	ReportsOptions.Author AS Author,
	|	ReportsOptions.AvailableToAuthorOnly AS AvailableToAuthorOnly,
	|	ReportsOptions.Custom AS Custom,
	|	ReportsOptions.DeletionMark AS DeletionMark,
	|	ReportsOptions.PredefinedVariant AS PredefinedVariant
	|INTO ttOptions
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Report = &Report
	|	AND (ReportsOptions.Custom = TRUE
	|			OR ReportsOptions.DeletionMark = FALSE)
	|	AND (ReportsOptions.AvailableToAuthorOnly = FALSE
	|			OR ReportsOptions.Author = &CurrentUser)
	|	AND NOT ReportsOptions.PredefinedVariant IN (&DIsabledApplicationOptions)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReportsOptions.Ref AS Ref,
	|	OptionsPlacement.Use AS Use,
	|	OptionsPlacement.Subsystem AS Subsystem
	|INTO ttAdministratorPlacement
	|FROM
	|	ttOptions AS ReportsOptions
	|		INNER JOIN Catalog.ReportsOptions.Placement AS OptionsPlacement
	|		ON ReportsOptions.Ref = OptionsPlacement.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReportsOptions.Ref AS Ref,
	|	ConfigurationPlacement.Subsystem AS Subsystem
	|INTO ttDeveloperPlacement
	|FROM
	|	ttOptions AS ReportsOptions
	|		INNER JOIN Catalog.PredefinedReportsOptions.Placement AS ConfigurationPlacement
	|		ON (ReportsOptions.Custom = FALSE)
	|			AND ReportsOptions.PredefinedVariant = ConfigurationPlacement.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	ReportsOptions.Ref,
	|	ExtensionsPlacement.Subsystem
	|FROM
	|	ttOptions AS ReportsOptions
	|		INNER JOIN Catalog.PredefinedExtensionsReportsOptions.Placement AS ExtensionsPlacement
	|		ON (ReportsOptions.Custom = FALSE)
	|			AND ReportsOptions.PredefinedVariant = ExtensionsPlacement.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	ISNULL(AdministratorPlacement.Ref, DeveloperPlacement.Ref) AS Ref,
	|	ISNULL(AdministratorPlacement.Subsystem, DeveloperPlacement.Subsystem) AS Subsystem,
	|	ISNULL(AdministratorPlacement.Use, TRUE) AS Use,
	|	CASE
	|		WHEN AdministratorPlacement.Ref IS NULL
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ThisIsDeveloperSettingItem
	|INTO ttOptionsPlacement
	|FROM
	|	ttAdministratorPlacement AS AdministratorPlacement
	|		FULL JOIN ttDeveloperPlacement AS DeveloperPlacement
	|		ON AdministratorPlacement.Ref = DeveloperPlacement.Ref
	|			AND AdministratorPlacement.Subsystem = DeveloperPlacement.Subsystem
	|WHERE
	|	ISNULL(AdministratorPlacement.Use, TRUE)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	Placement.Ref AS Ref,
	|	MAX(ISNULL(PersonalSettings.Visible, Variants.VisibleByDefault)) AS VisibilityOnReportPanel
	|INTO ttVisibility
	|FROM
	|	ttOptionsPlacement AS Placement
	|		LEFT JOIN InformationRegister.ReportOptionsSettings AS PersonalSettings
	|		ON Placement.Subsystem = PersonalSettings.Subsystem
	|			AND Placement.Ref = PersonalSettings.Variant
	|			AND (PersonalSettings.User = &CurrentUser)
	|		LEFT JOIN ttOptions AS Variants
	|		ON Placement.Ref = Variants.Ref
	|
	|GROUP BY
	|	Placement.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Variants.Ref AS Ref,
	|	Variants.Description AS Description,
	|	Variants.VariantKey AS VariantKey,
	|	Variants.VisibleByDefault AS VisibleByDefault,
	|	Variants.Author AS Author,
	|	Variants.AvailableToAuthorOnly AS AvailableToAuthorOnly,
	|	Variants.Custom AS Custom,
	|	Variants.DeletionMark AS DeletionMark,
	|	CASE
	|		WHEN Variants.DeletionMark = TRUE
	|			THEN 3
	|		WHEN Visible.VisibilityOnReportPanel = TRUE
	|			THEN 1
	|		ELSE 2
	|	END AS GroupNumber,
	|	Variants.Details AS Details,
	|	CASE
	|		WHEN Variants.DeletionMark
	|			THEN 4
	|		WHEN Variants.Custom
	|			THEN 3
	|		ELSE 5
	|	END AS PictureIndex,
	|	CASE
	|		WHEN Variants.Author = &CurrentUser
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS CurrentUserAuthor
	|FROM
	|	ttOptions AS Variants
	|		LEFT JOIN ttVisibility AS Visible
	|		ON Variants.Ref = Visible.Ref";
	
	
	Query = New Query;
	Query.SetParameter("Report", ReportInformation.Report);
	Query.SetParameter("CurrentUser", CurrentUser);
	Query.SetParameter("DIsabledApplicationOptions", ReportsOptionsCached.DIsabledApplicationOptions());
	
	If ShowPersonalReportsOptionsByOtherAuthors Then
		QueryText = StrReplace(QueryText, "AND NOT(NOT ReportsOptions.AvailableToAuthorOnly = FALSE
		|				AND NOT ReportsOptions.Author = &CurrentUser)", "");
	EndIf;
	
	Query.Text = QueryText;
	
	ReportOptionsTable = Query.Execute().Unload();
	
	// Add predefined options of an external report to the table of options (to sort when adding to the tree).
	If ReportInformation.ReportType = Enums.ReportTypes.External Then
		
		Try
			ReportObject = ExternalReports.Create(ReportInformation.ReportName);
		Except
			ReportsOptions.WriteToLog(EventLogLevel.Error,
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Cannot receive a list of predefined options
						| of external report ""%1"":'; 
						|en = 'Cannot receive a list of predefined options
						| of external report ""%1"":'; 
						|pl = 'Cannot receive a list of predefined options
						| of external report ""%1"":';
						|es_ES = 'Cannot receive a list of predefined options
						| of external report ""%1"":';
						|es_CO = 'Cannot receive a list of predefined options
						| of external report ""%1"":';
						|tr = 'Cannot receive a list of predefined options
						| of external report ""%1"":';
						|it = 'Cannot receive a list of predefined options
						| of external report ""%1"":';
						|de = 'Cannot receive a list of predefined options
						| of external report ""%1"":'"),
					ReportInformation.ReportName)
				+ Chars.LF
				+ DetailErrorDescription(ErrorInfo()));
			Return;
		EndTry;
		
		If ReportObject.DataCompositionSchema <> Undefined Then
			For Each DCSettingsOption In ReportObject.DataCompositionSchema.SettingVariants Do
				Option = ReportOptionsTable.Add();
				Option.GroupNumber    = 1;
				Option.VariantKey   = DCSettingsOption.Name;
				Option.Description   = DCSettingsOption.Presentation;
				Option.PictureIndex = 5;
				Option.CurrentUserAuthor = False;
			EndDo;
		EndIf;
		
	EndIf;
	
	ReportOptionsTable.Sort("GroupNumber ASC, Description ASC");
	ReportOptionsTree.GetItems().Clear();
	TreeGroups = New Map;
	TreeGroups.Insert(1, ReportOptionsTree.GetItems());
	
	For Each TableRow In ReportOptionsTable Do
		If Not ValueIsFilled(TableRow.VariantKey) Then
			Continue;
		EndIf;
		TreeRowsSet = TreeGroups.Get(TableRow.GroupNumber);
		If TreeRowsSet = Undefined Then
			TreeGroup = ReportOptionsTree.GetItems().Add();
			TreeGroup.GroupNumber = TableRow.GroupNumber;
			If TableRow.GroupNumber = 2 Then
				TreeGroup.Description = NStr("ru = 'Hidden in report panels'; en = 'Hidden in report panels'; pl = 'Hidden in report panels';es_ES = 'Hidden in report panels';es_CO = 'Hidden in report panels';tr = 'Hidden in report panels';it = 'Hidden in report panels';de = 'Hidden in report panels'");
				TreeGroup.PictureIndex = 0;
				TreeGroup.AuthorPicture = -1;
			ElsIf TableRow.GroupNumber = 3 Then
				TreeGroup.Description = NStr("ru = 'Marked for deletion'; en = 'Marked for deletion'; pl = 'Marked for deletion';es_ES = 'Marked for deletion';es_CO = 'Marked for deletion';tr = 'Marked for deletion';it = 'Marked for deletion';de = 'Marked for deletion'");
				TreeGroup.PictureIndex = 1;
				TreeGroup.AuthorPicture = -1;
			EndIf;
			TreeRowsSet = TreeGroup.GetItems();
			TreeGroups.Insert(TableRow.GroupNumber, TreeRowsSet);
		EndIf;
		
		Option = TreeRowsSet.Add();
		FillPropertyValues(Option, TableRow);
		If Option.VariantKey = CurrentOptionKey Then
			Items.ReportOptionsTree.CurrentRow = Option.GetID();
		EndIf;
		Option.AuthorPicture = ?(Option.AvailableToAuthorOnly, -1, 0);
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure DeleteOptionAtServer(Ref, PictureIndex)
	OptionObject = Ref.GetObject();
	DeletionMark = Not OptionObject.DeletionMark;
	Custom = OptionObject.Custom;
	OptionObject.SetDeletionMark(DeletionMark);
	PictureIndex = ?(DeletionMark, 4, ?(Custom, 3, 5));
EndProcedure

#EndRegion
