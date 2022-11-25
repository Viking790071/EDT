#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	CleanupSettings = InformationRegisters.FilesClearingSettings.CurrentClearSettings();
	
	UnusedFilesTable = New ValueTable;
	UnusedFilesTable.Columns.Add("FileOwner");
	UnusedFilesTable.Columns.Add("IrrelevantFilesVolume", New TypeDescription("Number"));
	
	FilesClearingSettings  = CleanupSettings.FindRows(New Structure("IsCatalogItemSetup", False));
	
	For Each Setting In FilesClearingSettings Do
		
		ExceptionsArray = New Array;
		DetailedSettings = CleanupSettings.FindRows(New Structure(
		"OwnerID, IsCatalogItemSetup",
		Setting.FileOwner,
		True));
		If DetailedSettings.Count() > 0 Then
			For Each ExceptionItem In DetailedSettings Do
				ExceptionsArray.Add(ExceptionItem.FileOwner);
				GetUnusedFilesVolume(UnusedFilesTable, ExceptionItem, , True);
			EndDo;
		EndIf;
		
		GetUnusedFilesVolume(UnusedFilesTable, Setting, ExceptionsArray, False);
	EndDo;
	
	StandardProcessing = False;
	
	ResultDocument.Clear();
	
	TemplateComposer = New DataCompositionTemplateComposer;
	Settings = SettingsComposer.GetSettings();
	
	NonExistingIBUsersIDs = New Array;
	
	ExternalDataSets = New Structure;
	ExternalDataSets.Insert("DataVolumeTotal", DataVolumeTotal());
	ExternalDataSets.Insert("IrrelevantFilesVolume", UnusedFilesTable);
	
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, Settings, DetailsData);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData, True);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	OutputProcessor.Output(CompositionProcessor);
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ReportIsBlank = Common.CommonModule("ReportsServer").ReportIsBlank(ThisObject, CompositionProcessor);
		SettingsComposer.UserSettings.AdditionalProperties.Insert("ReportIsBlank", ReportIsBlank);
	EndIf;
EndProcedure

#EndRegion

#Region Private

Procedure GetUnusedFilesVolume(UnusedFilesTable, ClearingSetup, ExceptionsArray = Undefined, IsCatalogItemSetup = False)
	
	If ClearingSetup.Action = Enums.FilesCleanupOptions.DoNotClear Then
		Return;
	EndIf;
	
	If ExceptionsArray = Undefined Then
		ExceptionsArray = New Array;
	EndIf;
	
	UnusedFiles = SelectDataByRule(ClearingSetup, ExceptionsArray);
	
	For Each Page In UnusedFiles Do
		NewRow = UnusedFilesTable.Add();
		FillPropertyValues(NewRow, Page);
	EndDo;
	
EndProcedure

Function QueryTextToClearFiles(FileOwner, Setting, ExceptionsArray, ExceptionItem)
	
	Return FilesOperationsInternal.QueryTextToClearFiles(FileOwner, Setting, ExceptionsArray, ExceptionItem, True);
	
EndFunction

Function SelectDataByRule(ClearingSetup, ExceptionsArray)
	
	TemporarySettingsComposer = New DataCompositionSettingsComposer;
	
	ClearByRule = ClearingSetup.ClearingPeriod = Enums.FilesCleanupPeriod.ByRule;
	If ClearByRule Then
		ComposerSettings = ClearingSetup.FilterRule.Get();
		If ComposerSettings <> Undefined Then
			TemporarySettingsComposer.LoadSettings(ComposerSettings);
		EndIf;
	EndIf;
	
	TemporaryDataCompositionSchema = New DataCompositionSchema;
	DataSource = TemporaryDataCompositionSchema.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "Local";
	
	DataSet = TemporaryDataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.Name = "DataSet1";
	DataSet.DataSource = DataSource.Name;
	
	TemporaryDataCompositionSchema.TotalFields.Clear();
	
	If ClearingSetup.IsCatalogItemSetup Then
		FileOwner = ClearingSetup.OwnerID;
		ExceptionItem = ClearingSetup.FileOwner;
	Else
		FileOwner = ClearingSetup.FileOwner;
		ExceptionItem = Undefined;
	EndIf;
	
	ClearOnlyVersions = False;
	If ClearingSetup.Action = Enums.FilesCleanupOptions.CleanUpVersions Then
		ClearOnlyVersions = True;
	EndIf;
	
	TemporaryDataCompositionSchema.DataSets[0].Query = QueryTextToClearFiles(
		FileOwner,
		ClearingSetup,
		ExceptionsArray,
		ExceptionItem);
	
	Structure = TemporarySettingsComposer.Settings.Structure.Add(Type("DataCompositionGroup"));
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("FileOwner");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("IrrelevantFilesVolume");
	
	TemporarySettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(TemporaryDataCompositionSchema));
	
	Settings = TemporarySettingsComposer.GetSettings();
	
	Parameter = TemporarySettingsComposer.Settings.DataParameters.Items.Find("OwnerType");
	Parameter.Value = TypeOf(FileOwner.EmptyRefValue);
	Parameter.Use = True;
	
	If ExceptionsArray.Count() > 0 AND Not ClearingSetup.IsCatalogItemSetup Then
		Parameter = TemporarySettingsComposer.Settings.DataParameters.Items.Find("ExceptionsArray");
		Parameter.Value = ExceptionsArray;
		Parameter.Use = True;
	EndIf;
	
	CurrentDateParameter = TemporarySettingsComposer.Settings.DataParameters.Items.Find("CurrentDate");
	If CurrentDateParameter <> Undefined Then
		CurrentDateParameter.Value = CurrentSessionDate();
		CurrentDateParameter.Use = True;
	EndIf;
	
	Parameter = TemporarySettingsComposer.Settings.DataParameters.Items.Find("ClearingPeriod");
	If Parameter <> Undefined Then
		If ClearingSetup.ClearingPeriod = Enums.FilesCleanupPeriod.OverOneMonth Then
			ClearingPeriodValue = AddMonth(BegOfDay(CurrentSessionDate()), -1);
		ElsIf ClearingSetup.ClearingPeriod = Enums.FilesCleanupPeriod.OverOneYear Then
			ClearingPeriodValue = AddMonth(BegOfDay(CurrentSessionDate()), -12);
		ElsIf ClearingSetup.ClearingPeriod = Enums.FilesCleanupPeriod.OverSixMonths Then
			ClearingPeriodValue = AddMonth(BegOfDay(CurrentSessionDate()), -6);
		EndIf;
		Parameter.Value = ClearingPeriodValue;
		Parameter.Use = True;
	EndIf;
	
	If ClearingSetup.IsCatalogItemSetup Then
		Parameter = TemporarySettingsComposer.Settings.DataParameters.Items.Find("ExceptionItem");
		Parameter.Value = ExceptionItem;
		Parameter.Use = True;
	EndIf;
	
	TemplateComposer = New DataCompositionTemplateComposer;
	DataCompositionProcessor = New DataCompositionProcessor;
	OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
	ValueTable = New ValueTable;
	
	DataCompositionTemplate = TemplateComposer.Execute(TemporaryDataCompositionSchema, TemporarySettingsComposer.Settings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
	DataCompositionProcessor.Initialize(DataCompositionTemplate);
	OutputProcessor.SetObject(ValueTable);
	OutputProcessor.Output(DataCompositionProcessor);
	
	Return ValueTable;
	
EndFunction

Function DataVolumeTotal()
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	
	Query.Text = FilesOperationsInternal.FullFilesVolumeQueryText();
	
	QueryResult = Query.Execute();
	
	Return QueryResult.Unload();
	
EndFunction

#EndRegion

#EndIf