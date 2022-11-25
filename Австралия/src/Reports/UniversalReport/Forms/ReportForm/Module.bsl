#Region Variables

&AtClient
Var HandlerAfterGenerateAtClient Export;
&AtClient
Var HandlerParameters;
&AtClient
Var RunMeasurements;
&AtClient
Var MeasurementID;
&AtClient
Var Directly;
&AtClient
Var GeneratingOnOpen;
&AtClient
Var IdleInterval;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	DetermineCurrentOptionDataSource(Parameters.Ref);
	
	// Define key report parameters.
	DetailsMode = (Parameters.Property("Details") AND Parameters.Details <> Undefined);
	OutputRight = AccessRight("Output", Metadata);
	
	ReportObject     = FormAttributeToValue("Report");
	ReportMetadata = ReportObject.Metadata();
	ReportFullName  = ReportMetadata.FullName();
	PredefinedOptions = New ValueList;
	If ReportObject.DataCompositionSchema <> Undefined Then
		For Each Option In ReportObject.DataCompositionSchema.SettingVariants Do
			PredefinedOptions.Add(Option.Name, Option.Presentation);
		EndDo;
	EndIf;
	
	PanelOptionsCurrentOptionKey = " - ";
	If ValueIsFilled(Parameters.VariantKey) Then
		CurrentVariantKey = Parameters.VariantKey;
	Else
		CurrentVariantKey = Common.SystemSettingsStorageLoad(ReportFullName + "/CurrentVariantKey", "");
	EndIf;
	If Not ValueIsFilled(CurrentVariantKey) AND PredefinedOptions.Count() > 0 Then
		CurrentVariantKey = PredefinedOptions[0].Value;
	EndIf;
	
	// Preliminary initialization of the composer (if required).
	SchemaURL = CommonClientServer.StructureProperty(Parameters, "SchemaURL");
	If DetailsMode Then
		NewDCSettings = GetFromTempStorage(Parameters.Details.Data).Settings;
		SchemaURL = CommonClientServer.StructureProperty(NewDCSettings.AdditionalProperties, "SchemaURL");
	EndIf;
	If TypeOf(SchemaURL) = Type("String") AND IsTempStorageURL(SchemaURL) Then
		DataCompositionSchema = GetFromTempStorage(SchemaURL);
		If TypeOf(DataCompositionSchema) = Type("DataCompositionSchema") Then
			SchemaURL = PutToTempStorage(DataCompositionSchema, UUID);
			Report.SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
		Else
			SchemaURL = PutToTempStorage(ReportObject.DataCompositionSchema, UUID);
		EndIf;
	Else
		SchemaURL = PutToTempStorage(ReportObject.DataCompositionSchema, UUID);
	EndIf;
	
	// Save form opening parameters.
	ParametersForm = New Structure(
		"PurposeUseKey, UserSettingsKey,
		|GenerateOnOpen, ReadOnly,
		|FixedSettings, Section, Subsystem, SubsystemPresentation");
	FillPropertyValues(ParametersForm, Parameters);
	ParametersForm.Insert("Filter", New Structure);
	If TypeOf(Parameters.Filter) = Type("Structure") Then
		CommonClientServer.SupplementStructure(ParametersForm.Filter, Parameters.Filter, True);
		Parameters.Filter.Clear();
	EndIf;
	
	// Define report settings.
	ReportByStringType = ReportsOptionsClientServer.ReportType(Parameters.Report, True);
	If ReportByStringType = Undefined Then
		Information      = ReportsOptions.GenerateReportInformationByFullName(ReportFullName);
		Parameters.Report = Information.Report;
	EndIf;
	ReportSettings = ReportsOptions.ReportFormSettings(Parameters.Report, CurrentVariantKey, ReportObject);
	ReportSettings.Insert("SelectOptionsAllowed", True);
	ReportSettings.Insert("SchemaModified", False);
	ReportSettings.Insert("PredefinedOptions", PredefinedOptions);
	ReportSettings.Insert("SchemaURL",   SchemaURL);
	ReportSettings.Insert("SchemaKey",    "");
	ReportSettings.Insert("Contextual",  TypeOf(ParametersForm.Filter) = Type("Structure") AND ParametersForm.Filter.Count() > 0);
	ReportSettings.Insert("FullName",    ReportFullName);
	ReportSettings.Insert("Description", TrimAll(ReportMetadata.Presentation()));
	ReportSettings.Insert("ReportRef",  Parameters.Report);
	ReportSettings.Insert("External",      TypeOf(ReportSettings.ReportRef) = Type("String"));
	ReportSettings.Insert("Safe",   SafeMode() <> False);
	UpdateInfoOnReportOption();
	CommonClientServer.SupplementStructure(ReportSettings, ReportsOptions.ClientParameters());
	
	ReportSettings.Insert("ReadCreateFromUserSettingsImmediatelyCheckBox", True);
	If Parameters.Property("GenerateOnOpen") AND Parameters.GenerateOnOpen = True Then
		Parameters.GenerateOnOpen = False;
		Items.GenerateImmediately.Check = True;
		ReportSettings.ReadCreateFromUserSettingsImmediatelyCheckBox = False;
	EndIf;
	
	// Default parameters.
	If Not CommonClientServer.StructureProperty(ReportSettings, "OutputSelectedCellsTotal", True) Then
		Items.AutosumButton.Visible = False;
		Items.ReportSpreadsheetDocument.SetAction("OnActivateArea", "");
	EndIf;
	
	// Hide option commands.
	ReportOptionsCommandsVisibility = CommonClientServer.StructureProperty(Parameters, "ReportOptionsCommandsVisibility");
	If ReportOptionsCommandsVisibility = False Then
		ReportSettings.EditOptionsAllowed = False;
		ReportSettings.SelectOptionsAllowed = False;
		If IsBlankString(PurposeUseKey) Then
			PurposeUseKey = Parameters.VariantKey;
			ParametersForm.PurposeUseKey = PurposeUseKey;
		EndIf;
	EndIf;
	If ReportSettings.EditOptionsAllowed AND Not ReportsOptionsCached.InsertRight() Then
		ReportSettings.EditOptionsAllowed = False;
	EndIf;
	
	// Register commands and form attributes that will not be deleted when overwriting quick settings.
	SetOfAttributes = GetAttributes();
	For Each Attribute In SetOfAttributes Do
		FullAttributeName = Attribute.Name + ?(IsBlankString(Attribute.Path), "", "." + Attribute.Path);
		ConstantAttributes.Add(FullAttributeName);
	EndDo;
	For Each Command In Commands Do
		ConstantCommands.Add(Command.Name);
	EndDo;
	
	SetVisibilityAvailability();
	
	// Close integration with email and mailing.
	CanSendEmails = False;
	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmail = Common.CommonModule("EmailOperations");
		CanSendEmails = ModuleEmail.CanSendEmails();
	EndIf;
	If CanSendEmails Then
		If ReportSettings.EditOptionsAllowed
			AND Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
			ModuleReportDistribution = Common.CommonModule("ReportMailing");
			ModuleReportDistribution.ReportFormAddCommands(ThisObject, Cancel, StandardProcessing);
		Else // If the submenu contains only one command, the dropdown list is not shown.
			Items.SendByEmail.Title = Items.SendGroup.Title + "...";
			Items.Move(Items.SendByEmail, Items.SendGroup.Parent, Items.SendGroup);
		EndIf;
	Else
		Items.SendGroup.Visible = False;
	EndIf;
	
	// Determine if the report contains invalid data.
	If Not Items.GenerateImmediately.Check Then
		Try
			UsedTables = ReportsOptions.UsedTables(ReportObject.DataCompositionSchema);
			UsedTables.Add(ReportSettings.FullName);
			If ReportSettings.Events.OnDefineUsedTables Then
				ReportObject.OnDefineUsedTables(CurrentVariantKey, UsedTables);
			EndIf;
			ReportsOptions.CheckUsedTables(UsedTables);
		Except
			ErrorText = NStr("ru = 'Не удалось определить используемые таблицы:'; en = 'Cannot determine the used tables:'; pl = 'Nie można określić używanych tabel:';es_ES = 'No se ha podido determinar las tablas usadas:';es_CO = 'No se ha podido determinar las tablas usadas:';tr = 'Kullanılan tablolar belirlenemedi:';it = 'Non è possibile determinare le tabelle utilizzate:';de = 'Die verwendeten Tabellen konnten nicht ermittelt werden:'");
			ErrorText = ErrorText + Chars.LF + DetailErrorDescription(ErrorInfo());
			ReportsOptions.WriteToLog(EventLogLevel.Error, ErrorText, ReportSettings.OptionRef);
		EndTry;
	EndIf;
	
	If ParametersForm.Subsystem = Undefined Or Not ReportSettings.SelectOptionsAllowed Then
		Items.OtherReports.Visible = False;
	EndIf;
	
	ReportsOverridable.OnCreateAtServer(ThisObject, Cancel, StandardProcessing);
	If ReportSettings.Events.OnCreateAtServer Then
		ReportObject.OnCreateAtServer(ThisObject, Cancel, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	RunMeasurements = False;
	// In the safe mode, additional reports are generated directly as they cannot attach themselves and 
	// use their own methods in background jobs.
	Directly = ReportSettings.External Or ReportSettings.Safe;
	GeneratingOnOpen = False;
	IdleInterval = ?(GetClientConnectionSpeed() = ClientConnectionSpeed.Low, 1, 0.2);
	If Items.GenerateImmediately.Check Then
		GeneratingOnOpen = True;
		AttachIdleHandler("Generate", 0.1, True);
	EndIf;
	ShowSettingsFillingResult();
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	ResultProcessed = False;
	
	// Get results from standard forms.
	If TypeOf(ChoiceSource) = Type("ClientApplicationForm") Then
		SubordinateFormName = ChoiceSource.FormName;
		If SubordinateFormName = "SettingsStorage.ReportsVariantsStorage.Form.ReportSettings"
			Or ChoiceSource.OnCloseNotifyDescription <> Undefined Then
			ResultProcessed = True; // See. AllSettingsCompletion. 
		ElsIf TypeOf(SelectedValue) = Type("Structure") Then
			PointPosition = StrLen(SubordinateFormName);
			While CharCode(SubordinateFormName, PointPosition) <> 46 Do // Not a point.
				PointPosition = PointPosition - 1;
			EndDo;
			SourceFormSuffix = Upper(Mid(SubordinateFormName, PointPosition + 1));
			If SourceFormSuffix = Upper("ReportSettingsForm")
				Or SourceFormSuffix = Upper("SettingsForm")
				Or SourceFormSuffix = Upper("ReportVariantForm")
				Or SourceFormSuffix = Upper("VariantForm") Then
				QuickSettingsFillClient(SelectedValue);
				ResultProcessed = True;
			EndIf;
		EndIf;
	ElsIf TypeOf(ChoiceSource) = Type("DataCompositionSchemaWizard") Then
#If ThickClientOrdinaryApplication OR ThickClientManagedApplication Then
		If Type(SelectedValue) = Type("DataCompositionSchema") Then
			ReportSettings.SchemaURL = PutToTempStorage(SelectedValue, UUID);
			
			Path = GetTempFileName();
			
			XMLWriter = New XMLWriter; 
			XMLWriter.OpenFile(Path, "UTF-8");
			XDTOSerializer.WriteXML(XMLWriter, SelectedValue, "dataCompositionSchema", "http://v8.1c.ru/8.1/data-composition-system/schema"); 
			XMLWriter.Close();
			
			BinaryData = New BinaryData(Path);
			BeginDeletingFiles(New NotifyDescription, Path);
			
			Report.SettingsComposer.Settings.AdditionalProperties.Insert("DataCompositionSchema", BinaryData);
			Report.SettingsComposer.Settings.AdditionalProperties.Insert("ReportInitialized",  False);
			
			FillingParameters = New Structure;
			FillingParameters.Insert("ResetUserSettings", True);
			FillingParameters.Insert("UserSettingsModified", True);
			FillingParameters.Insert("DCSettingsComposer", Report.SettingsComposer);
			FillingParameters.Insert("EventName", "DefaultSettings");
			
			QuickSettingsFillClient(FillingParameters);
		EndIf;
#EndIf
	EndIf;
	
	// Extension functionality.
	If CommonClient.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportsMailingClient = CommonClient.CommonModule("ReportMailingClient");
		ModuleReportsMailingClient.ChoiceProcessingReportForm(ThisObject, SelectedValue, ChoiceSource, ResultProcessed);
	EndIf;
	ReportsClientOverridable.ChoiceProcessing(ThisObject, SelectedValue, ChoiceSource, ResultProcessed);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	NotificationProcessed = False;
	If EventName = ReportsOptionsClientServer.EventNameChangingOption()
		Or EventName = "Write_ConstantsSet" Then
		NotificationProcessed = True;
		PanelOptionsCurrentOptionKey = " - ";
		AttachIdleHandler("VisibilityAvailabilityWhenNecessary", 0.1, True);
	EndIf;
	ReportsClientOverridable.NotificationProcessing(ThisObject, EventName, Parameter, Source, NotificationProcessed);
EndProcedure

&AtServer
Procedure BeforeLoadVariantAtServer(Settings)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	If Settings = Undefined Then
		Return;
	EndIf;
	
	// If the report is not in DCS and settings are not imported, do nothing.
	If Not ReportOptionMode() AND Settings = Undefined Then
		Return;
	EndIf;
	
	// Call an overridable module.
	ReportsOverridable.BeforeLoadVariantAtServer(ThisObject, Settings);
	If ReportSettings.Events.BeforeLoadVariantAtServer Then
		ReportObject = FormAttributeToValue("Report");
		ReportObject.BeforeLoadVariantAtServer(ThisObject, Settings);
	EndIf;
	
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
Procedure OnLoadVariantAtServer(Settings)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// If the report is not in DCS and settings are not imported, do nothing.
	If Not ReportOptionMode() AND Settings = Undefined Then
		Return;
	EndIf;
	
	// Import fixed settings for the details mode.
	If DetailsMode Then
		ReportCurrentOptionDescription = CommonClientServer.StructureProperty(Settings.AdditionalProperties, "DescriptionOption");
		If Parameters <> Undefined AND Parameters.Property("Details") Then
			Report.SettingsComposer.FixedSettings.AdditionalProperties.Insert("DetailsMode", True);
		EndIf;
		If CurrentVariantKey = Undefined Then
			CurrentVariantKey = CommonClientServer.StructureProperty(Settings.AdditionalProperties, "VariantKey");
		EndIf;
	Else
		Report.SettingsComposer.Settings.AdditionalProperties.Insert("DescriptionOption", ReportCurrentOptionDescription);
	EndIf;
	// To set fixed filters, use the composer as it comprises the most complete collection of settings.
	// In parameters, in BeforeImport, some parameters can be missing if their settings were not overwritten.
	If TypeOf(ParametersForm.Filter) = Type("Structure") Then
		ReportsServer.SetFixedFilters(ParametersForm.Filter, Report.SettingsComposer.Settings, ReportSettings);
	EndIf;
	
	// Update the report option reference.
	If PanelOptionsCurrentOptionKey <> CurrentVariantKey Then
		UpdateInfoOnReportOption();
	EndIf;
	
	// Call an overridable module.
	If ReportSettings.Events.OnLoadVariantAtServer Then
		ReportObject = FormAttributeToValue("Report");
		ReportObject.OnLoadVariantAtServer(ThisObject, Settings);
	EndIf;
EndProcedure

&AtServer
Procedure BeforeLoadUserSettingsAtServer(Settings)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If ReportSettings.Events.BeforeImportSettingsToComposer Then
		// Prepare for reinitialization.
		Try
			NewUserXMLSettings = Common.ValueToXMLString(Settings);
		Except
			NewUserXMLSettings = Undefined;
		EndTry;
		ReportSettings.Insert("NewUserXMLSettings", NewUserXMLSettings);
	EndIf;
EndProcedure

&AtServer
Procedure OnLoadUserSettingsAtServer(Settings)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	If Not ReportOptionMode() Then
		Return;
	EndIf;
	
	// Call an overridable module.
	If ReportSettings.Events.OnLoadUserSettingsAtServer Then
		ReportObject = FormAttributeToValue("Report");
		ReportObject.OnLoadUserSettingsAtServer(ThisObject, Settings);
	EndIf;
EndProcedure

&AtServer
Procedure OnUpdateUserSettingSetAtServer(StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	If Not ReportOptionMode() Then
		Return;
	EndIf;
	StandardProcessing = False;
	
	FillingParameters = New Structure;
	FillingParameters.Insert("EventName", "OnUpdateUserSettingSetAtServer");
	FillingParameters.Insert("StandardEventProcessing", StandardProcessing);
	QuickSettingsFill(FillingParameters);
	If FillingParameters.StandardEventProcessing <> StandardProcessing Then
		StandardProcessing = FillingParameters.StandardEventProcessing;
	EndIf;
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	If Not ReportOptionMode() Then
		Return;
	EndIf;
	DCUserSettings = Report.SettingsComposer.UserSettings;
	For Each DCUserSetting In DCUserSettings.Items Do
		Type = ReportsClientServer.SettingTypeAsString(TypeOf(DCUserSetting));
		
		If Type = "SettingsParameterValue"
			AND TypeOf(DCUserSetting.Value) = Type("StandardPeriod")
			AND DCUserSetting.Use Then
			
			ItemID = ReportsClientServer.CastIDToName(DCUserSetting.UserSettingID);
			
			PeriodBeginning    = Items.Find(Type + "_Start_"    + ItemID);
			PeriodEnd = Items.Find(Type + "_End_" + ItemID);
			If PeriodBeginning = Undefined Or PeriodEnd = Undefined Then
				Continue;
			EndIf;
			
			Value = DCUserSetting.Value;
			If PeriodBeginning.AutoMarkIncomplete
				AND Not ValueIsFilled(Value.StartDate)
				AND Not ValueIsFilled(Value.EndDate) Then
				ErrorText = NStr("ru = 'Не указан период'; en = 'The period is not specified.'; pl = 'Okres nie jest określony';es_ES = 'Período no está especificado';es_CO = 'Período no está especificado';tr = 'Dönem belirtilmedi.';it = 'Il periodo non è specificato.';de = 'Zeitraum ist nicht angegeben'");
				DataPath = PeriodBeginning.DataPath;
			ElsIf Value.StartDate > Value.EndDate Then
				ErrorText = NStr("ru = 'Конец периода должен быть больше начала'; en = 'Period end should be later than its start'; pl = 'Koniec okresu powinien być późniejszy niż jego początek';es_ES = 'Fin del período tiene que ser más tarde que su inicio';es_CO = 'Fin del período tiene que ser más tarde que su inicio';tr = 'Dönem sonu, başlangıcından sonra olmalıdır';it = 'La fine del periodo deve essere successiva all''inizio';de = 'Das Periodenende sollte später als sein Beginn sein'");
				DataPath = PeriodEnd.DataPath;
			Else
				Continue;
			EndIf;
			
			Cancel = True;
			CommonClientServer.MessageToUser(ErrorText, , DataPath);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure OnSaveVariantAtServer(Settings)
	If Not ReportOptionMode() Then
		Return;
	EndIf;
	NewDCSettings = Report.SettingsComposer.GetSettings();
	ReportsClientServer.LoadSettings(Report.SettingsComposer, NewDCSettings);
	Settings.AdditionalProperties.Insert("Address", PutToTempStorage(NewDCSettings));
	Settings = NewDCSettings;
	PanelOptionsCurrentOptionKey = " - ";
	UpdateInfoOnReportOption();
	SetVisibilityAvailability(False);
EndProcedure

&AtServer
Procedure OnSaveUserSettingsAtServer(Settings)
	If Not ReportOptionMode() Then
		Return;
	EndIf;
	ReportsOptions.OnSaveUserSettingsAtServer(ThisObject, Settings);
	FillOptionsSelectionCommands();
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	If BackgroundJobID <> Undefined Then
		BackgroundJobCancel(BackgroundJobID);
		BackgroundJobID = Undefined;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

////////////////////////////////////////////////////////////////////////////////
// Spreadsheet document

&AtClient
Procedure ReportSpreadsheetDocumentChoice(Item, Area, StandardProcessing)
	ReportsClientOverridable.SpreadsheetDocumentSelectionHandler(ThisObject, Item, Area, StandardProcessing);
	
	If StandardProcessing AND TypeOf(Area) = Type("SpreadsheetDocumentRange") Then
		If GoToLink(Area.Text) Then
			StandardProcessing = False;
			Return;
		EndIf;
		
		Try
			DetailsValue = Area.Details;
		Except
			DetailsValue = Undefined;
			// Reading details is unavailable for some spreadsheet document area types (AreaType property), so 
			// an exclusion attempt is made.
		EndTry;
		
		If DetailsValue <> Undefined AND GoToLink(DetailsValue) Then
			StandardProcessing = False;
			Return;
		EndIf;
		If GoToLink(Area.Mask) Then
			StandardProcessing = False;
			Return;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure ReportSpreadsheetDocumentDetailsProcessing(Item, Details, StandardProcessing)
	ReportsClientOverridable.DetailProcessing(ThisObject, Item, Details, StandardProcessing);
EndProcedure

&AtClient
Procedure ReportSpreadsheetDocumentAdditionalDetailsProcessing(Item, Details, StandardProcessing)
	ReportsClientOverridable.AdditionalDetailProcessing(ThisObject, Item, Details, StandardProcessing);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Attachable objects

&AtClient
Procedure Attachable_UsageCheckBox_OnChange(Item)
	ItemID = Right(Item.Name, 32);
	
	DCUserSetting = FindUserSettingOfItem(ItemID);
	
	ReportsClient.RecordChangesInSubordinateItems(ThisObject, ItemID, DCUserSetting);
EndProcedure

&AtClient
Procedure Attachable_InputField_OnChange(Item)
	ItemID = Right(Item.Name, 32);
	
	DCUserSetting = FindUserSettingOfItem(ItemID);
	If TypeOf(DCUserSetting) = Type("DataCompositionSettingsParameterValue") Then
		Value = DCUserSetting.Value;
	ElsIf TypeOf(DCUserSetting) = Type("DataCompositionFilterItem") Then
		Value = DCUserSetting.RightValue;
	Else
		Return;
	EndIf;
	
	If ValueIsFilled(Value) Then
		DCUserSetting.Use = True;
	EndIf;
	
	ReportsClient.RecordChangesInSubordinateItems(ThisObject, ItemID, DCUserSetting);
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
Procedure Attachable_ComparisonKind_SelectionStart(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	Attachable_ChangeComparisonKind(Item);
EndProcedure

&AtServer
Function CheckCorrespondenceFlag(MetadataObjectType, MetadataObjectName, TableName)
	
	Result = True;
	
	If MetadataObjectType = "AccountingRegisters" And TableName = "DrCrTurnovers" Then
		Result = Metadata.AccountingRegisters[MetadataObjectName].Correspondence;
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure Attachable_TableName_OnChange(Item)
	
	ItemID = Right(Item.Name, 32);
	
	DCUserSetting = FindUserSettingOfItem(ItemID);
	
	MetadataObjectType = Report.SettingsComposer.Settings.DataParameters.Items.Find("MetadataObjectType");
	MetadataObjectName = Report.SettingsComposer.Settings.DataParameters.Items.Find("MetadataObjectName");
	Parameter = Report.SettingsComposer.Settings.DataParameters.Items.Find("TableName");
	
	If Not CheckCorrespondenceFlag(MetadataObjectType.Value, MetadataObjectName.Value, DCUserSetting.Value) Then
		
		MessageTemplate = MessagesToUserClientServer.GetUniversalReportInapplicableCombinationErrorText();
		CommonClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate,
				Items[StringFunctionsClientServer.SubstituteParametersToString(
					"SettingsParameterValue_Value_%1",
					StrReplace(MetadataObjectName.UserSettingID, "-", ""))].SelectedText,
				Items[StringFunctionsClientServer.SubstituteParametersToString(
					"SettingsParameterValue_Value_%1",
					StrReplace(DCUserSetting.UserSettingID, "-", ""))].SelectedText));
			
		DCUserSetting.Value = Parameter.Value;
		
		Return;
		
	EndIf;
	
	If Parameter.Value = DCUserSetting.Value Then
		Return;
	EndIf;
	Parameter.Value = DCUserSetting.Value;
	
	If ReportSettings.Property("Period") Then 
		Parameter = Report.SettingsComposer.Settings.DataParameters.Items.Find("Period");
		UserParameter = Report.SettingsComposer.UserSettings.Items.Find(Parameter.UserSettingID);
		
		If UserParameter = Undefined Then
			Parameter.Value = ReportSettings.Period;
		Else 
			Parameter.Value = UserParameter.Value;
			ReportSettings.Period = UserParameter.Value;
		EndIf;
		
	EndIf;
	
	Report.SettingsComposer.Settings.AdditionalProperties.Insert("ReportInitialized", False);
	
	FillingParameters = New Structure;
	
	FillingParameters.Insert("UserSettingsModified", True);
	FillingParameters.Insert("ResetUserSettings", True);
	FillingParameters.Insert("DCSettingsComposer", Report.SettingsComposer);
	QuickSettingsFillClient(FillingParameters);
	
EndProcedure

&AtClient
Procedure Attachable_MetadataObjectName_OnChange(Item)
	
	ItemID = Right(Item.Name, 32);
	
	DCUserSetting = FindUserSettingOfItem(ItemID);
	
	Parameter = Report.SettingsComposer.Settings.DataParameters.Items.Find("MetadataObjectName");
	If Parameter.Value = DCUserSetting.Value Then
		Return;
	EndIf;
	Parameter.Value = DCUserSetting.Value;
	
	Parameter = Report.SettingsComposer.Settings.DataParameters.Items.Find("DataSource");
	Parameter.Value = "";
	
	Parameter = Report.SettingsComposer.Settings.DataParameters.Items.Find("TableName");
	Parameter.Value = "";
	
	If ReportSettings.Property("Period") Then 
		Parameter = Report.SettingsComposer.Settings.DataParameters.Items.Find("Period");
		UserParameter = Report.SettingsComposer.UserSettings.Items.Find(Parameter.UserSettingID);
		
		If UserParameter = Undefined Then
			Parameter.Value = ReportSettings.Period;
		Else 
			Parameter.Value = UserParameter.Value;
			ReportSettings.Period = UserParameter.Value;
		EndIf;
		
	EndIf;
	
	Report.SettingsComposer.Settings.AdditionalProperties.Insert("ReportInitialized", False);
	
	FillingParameters = New Structure;
	
	FillingParameters.Insert("UserSettingsModified", True);
	FillingParameters.Insert("ResetUserSettings", True);
	FillingParameters.Insert("DCSettingsComposer", Report.SettingsComposer);
	QuickSettingsFillClient(FillingParameters);
	
EndProcedure

&AtClient
Procedure Attachable_MatedataObjectType_OnChange(Item)
	
	ItemID = Right(Item.Name, 32);
	
	DCUserSetting = FindUserSettingOfItem(ItemID);
	
	Parameter = Report.SettingsComposer.Settings.DataParameters.Items.Find("MetadataObjectType");
	If Parameter.Value = DCUserSetting.Value Then
		Return;
	EndIf;
	Parameter.Value = DCUserSetting.Value;
	
	Parameter = Report.SettingsComposer.Settings.DataParameters.Items.Find("DataSource");
	Parameter.Value = "";
	
	Parameter = Report.SettingsComposer.Settings.DataParameters.Items.Find("MetadataObjectName");
	Parameter.Value = "";
	
	Parameter = Report.SettingsComposer.Settings.DataParameters.Items.Find("TableName");
	Parameter.Value = "";
	
	If ReportSettings.Property("Period") Then 
		Parameter = Report.SettingsComposer.Settings.DataParameters.Items.Find("Period");
		UserParameter = Report.SettingsComposer.UserSettings.Items.Find(Parameter.UserSettingID);
		
		If UserParameter = Undefined Then
			Parameter.Value = ReportSettings.Period;
		Else 
			Parameter.Value = UserParameter.Value;
			ReportSettings.Period = UserParameter.Value;
		EndIf;
		
	EndIf;
	
	Report.SettingsComposer.Settings.AdditionalProperties.Insert("ReportInitialized", False);
	
	FillingParameters = New Structure;
	
	FillingParameters.Insert("UserSettingsModified", True);
	FillingParameters.Insert("ResetUserSettings", True);
	FillingParameters.Insert("DCSettingsComposer", Report.SettingsComposer);
	QuickSettingsFillClient(FillingParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Attachable objects - standard period.

&AtClient
Procedure Attachable_StandardPeriod_PeriodStart_OnChange(Item)
	// Generate information on the item.
	StartPeriodName = Item.Name;
	ValueName     = StrReplace(StartPeriodName, "_Begin_", "_Value_");
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
	
	ReportSettings.Insert("Period", Value);
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
	
	ReportSettings.Insert("Period", Value);
EndProcedure

&AtClient
Procedure Attachable_SelectPeriod(Command)
	ReportsClient.SelectPeriod(ThisObject, Command.Name);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AllSettings(Command)
	Name = ReportSettings.FullName + ".SettingsForm";
	
	FormParameters = New Structure;
	CommonClientServer.SupplementStructure(FormParameters, ParametersForm, True);
	FormParameters.Insert("VariantKey",              String(CurrentVariantKey));
	FormParameters.Insert("Variant",                   Report.SettingsComposer.Settings);
	FormParameters.Insert("UserSettings", Report.SettingsComposer.UserSettings);
	FormParameters.Insert("ReportSettings",     ReportSettings);
	FormParameters.Insert("DescriptionOption", String(ReportCurrentOptionDescription));
	
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	
	Handler = New NotifyDescription("AllSettingsCompletion", ThisObject);
	
	RunMeasurements = ReportSettings.RunMeasurements AND ValueIsFilled(ReportSettings.MeasurementsKey);
	If RunMeasurements Then
		ModulePerformanceMonitorClient = CommonClient.CommonModule("PerformanceMonitorClient");
		MeasurementID = ModulePerformanceMonitorClient.StartTimeMeasurement(
			False,
			ReportSettings.MeasurementsKey + ".Settings");
		ModulePerformanceMonitorClient.SetMeasurementComment(MeasurementID, ReportSettings.MeasurementsPrefix);
	EndIf;
	
	OpenForm(Name, FormParameters, ThisObject, , , , Handler, Mode);
	
	If RunMeasurements Then
		ModulePerformanceMonitorClient.StopTimeMeasurement(MeasurementID);
	EndIf;
EndProcedure

&AtClient
Procedure AllSettingsCompletion(Result, ExecutionParameters) Export
	If TypeOf(Result) <> Type("Structure") Then
		Return;
	EndIf;
	QuickSettingsFillClient(Result);
EndProcedure

&AtClient
Procedure ChangeReportOption(Command)
	FormParameters = New Structure;
	CommonClientServer.SupplementStructure(FormParameters, ParametersForm, True);
	FormParameters.Insert("ReportSettings",                       ReportSettings);
	FormParameters.Insert("Variant",                               Report.SettingsComposer.Settings);
	FormParameters.Insert("VariantKey",                          String(CurrentVariantKey));
	FormParameters.Insert("UserSettings",             Report.SettingsComposer.UserSettings);
	FormParameters.Insert("OptionPresentation",                 String(ReportCurrentOptionDescription));
	FormParameters.Insert("UserSettingsPresentation", "");
	
	OpenForm(ReportSettings.FullName + ".VariantForm", FormParameters, ThisObject);
EndProcedure

&AtClient
Procedure DefaultSettings(Command)
	FillingParameters = New Structure;
	FillingParameters.Insert("EventName", "DefaultSettings");
	If VariantModified Then
		FillingParameters.Insert("ClearOptionSettings", True);
		FillingParameters.Insert("VariantModified", False);
	EndIf;
	FillingParameters.Insert("ResetUserSettings", True);
	FillingParameters.Insert("UserSettingsModified", True);
	Report.SettingsComposer.Settings.AdditionalProperties.Clear();
	FillingParameters.Insert("DCSettingsComposer", Report.SettingsComposer);
	
	QuickSettingsFillClient(FillingParameters);
EndProcedure

&AtClient
Procedure SendByEmail(Command)
	StatePresentation = Items.ReportSpreadsheetDocument.StatePresentation;
	If StatePresentation.Visible = True
		AND StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance Then
		QuestionText = NStr("ru = 'Отчет не сформирован. Сформировать?'; en = 'Report not generated. Generate?'; pl = 'Nie wygenerowano raportu. Wygenerować?';es_ES = 'Informe no se ha generado. ¿Generar?';es_CO = 'Informe no se ha generado. ¿Generar?';tr = 'Rapor oluşturulmadı. Oluşturulsun mu?';it = 'Report non generato. Generare?';de = 'Bericht nicht generiert. Generieren?'");
		Handler = New NotifyDescription("GenerateBeforeEmailing", ThisObject);
		ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo, 60, DialogReturnCode.Yes);
	Else
		ShowSendByEmailDialog();
	EndIf;
EndProcedure

&AtClient
Procedure ReportComposeResult(Command)
	ClearMessages();
	Generate();
EndProcedure

&AtClient
Procedure CalculateSum(Command)
	StandardSubsystemsClient.ShowCellCalculation(ThisObject, ReportSpreadsheetDocument);
EndProcedure

&AtClient
Procedure GenerateImmediately(Command)
	
	GenerateImmediately = Not Items.GenerateImmediately.Check;
	Items.GenerateImmediately.Check = GenerateImmediately;
	
	StateBeforeChange = New Structure("Visible, AdditionalShowMode, Picture, Text");
	FillPropertyValues(StateBeforeChange, Items.ReportSpreadsheetDocument.StatePresentation);
	
	Report.SettingsComposer.UserSettings.AdditionalProperties.Insert("GenerateImmediately", GenerateImmediately);
	
	FillPropertyValues(Items.ReportSpreadsheetDocument.StatePresentation, StateBeforeChange);
	
EndProcedure

&AtClient
Procedure OtherReports(Command)
	FormParameters = New Structure;
	FormParameters.Insert("OptionRef",     ReportSettings.OptionRef);
	FormParameters.Insert("ReportRef",       ReportSettings.ReportRef);
	FormParameters.Insert("SubsystemRef",  ParametersForm.Subsystem);
	FormParameters.Insert("ReportDescription", ReportSettings.Description);
	
	Block = FormWindowOpeningMode.LockOwnerWindow;
	
	OpenForm("SettingsStorage.ReportsVariantsStorage.Form.OtherReportsPanel", FormParameters, ThisObject, True, , , , Block);
EndProcedure

&AtClient
Procedure RestoreDefaultSchema(Command)
	
	Report.SettingsComposer.Settings.AdditionalProperties.Clear();
	
	FillingParameters = New Structure;
	FillingParameters.Insert("ResetUserSettings", True);
	FillingParameters.Insert("UserSettingsModified", True);
	FillingParameters.Insert("DCSettingsComposer", Report.SettingsComposer);
	
	QuickSettingsFillClient(FillingParameters);
	
EndProcedure

&AtClient
Procedure EditSchema(Command)
	
	#If ThickClientOrdinaryApplication OR ThickClientManagedApplication Then
		
		DataCompositionSchema = GetFromTempStorage(ReportSettings.SchemaURL);
		
		If DataCompositionSchema.DefaultSettings.AdditionalProperties.Property("DataCompositionSchema") Then
			DataCompositionSchema.DefaultSettings.AdditionalProperties.DataCompositionSchema = Undefined;
		EndIf;
		
		Designer = New DataCompositionSchemaWizard(DataCompositionSchema);
		Designer.Edit(ThisObject);
		
	#Else
		
		ShowMessageBox(,(NStr("ru='Для того чтобы редактировать схему компоновки, необходимо запустить приложение в режиме толстого клиента.'; en = 'To edit the composition schema, run the application in the thick client mode.'; pl = 'Do wykonania edycji schematu układu, należy uruchomić aplikację w trybie klienta grubego.';es_ES = 'Para editar el esquema de composición, es necesario lanzar la aplicación en el modo del cliente grueso.';es_CO = 'Para editar el esquema de composición, es necesario lanzar la aplicación en el modo del cliente grueso.';tr = 'Düzen şemasını düzenlemek için uygulamayı kalın istemci modunda çalıştırmanız gerekir.';it = 'Per modificare lo schema di composizione, avviare l''applicazione nella modalità thick client.';de = 'Um das Layout-Schema zu bearbeiten, sollten Sie die Anwendung im Thick-Client-Modus starten.'")));
		
	#EndIf
	
EndProcedure

&AtClient
Procedure ImportSchemaFromFile(Command)
	
	NotifyDescription = New NotifyDescription("ImportSchemaFromFileWithExtension", ThisObject);
	CommonClient.ShowFileSystemExtensionInstallationQuestion(NotifyDescription, , True);
	
EndProcedure

&AtClient
Function GoToLink(HyperlinkAddress)
	If IsBlankString(HyperlinkAddress) Then
		Return False;
	EndIf;
	ReferenceAddressInReg = Upper(HyperlinkAddress);
	If StrStartsWith(ReferenceAddressInReg, Upper("http://"))
		Or StrStartsWith(ReferenceAddressInReg, Upper("https://"))
		Or StrStartsWith(ReferenceAddressInReg, Upper("e1cib/"))
		Or StrStartsWith(ReferenceAddressInReg, Upper("e1c://")) Then
		CommonClient.OpenURL(HyperlinkAddress);
		Return True;
	EndIf;
	Return False;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Attachable objects

&AtClient
Procedure Attachable_Command(Command)
	ConstantCommand = ConstantCommands.FindByValue(Command.Name);
	If ConstantCommand <> Undefined AND ValueIsFilled(ConstantCommand.Presentation) Then
		SubstringsArray = StrSplit(ConstantCommand.Presentation, ".");
		ModuleClient = CommonClient.CommonModule(SubstringsArray[0]);
		Handler = New NotifyDescription(SubstringsArray[1], ModuleClient, Command);
		ExecuteNotifyProcessing(Handler, ThisObject);
	Else
		ReportsClientOverridable.CommandHandler(ThisObject, Command, False);
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_ImportReportOption(Command)
	FoundItems = AddedOptions.FindRows(New Structure("CommandName", Command.Name));
	If FoundItems.Count() = 0 Then
		ShowMessageBox(, NStr("ru = 'Вариант отчета не найден.'; en = 'Report option was not found.'; pl = 'Nie znaleziono wariantu raportu.';es_ES = 'Opción del informe no se ha encontrado.';es_CO = 'Opción del informe no se ha encontrado.';tr = 'Rapor seçeneği bulunamadı.';it = 'Opzione di Report non è stata trovata.';de = 'Die Berichtsoption wurde nicht gefunden.'"));
		Return;
	EndIf;
	FormOption = FoundItems[0];
	ReportSettings.Delete("SettingsFormAdvancedMode");
	If ReportSettings.Property("Period") Then 
		ReportSettings.Delete("Period");
	EndIf;
	ImportOption(FormOption.VariantKey);
	UniqueKey = ReportsClientServer.UniqueKey(ReportSettings.FullName, FormOption.VariantKey);
	ShowSettingsFillingResult();
	If Items.GenerateImmediately.Check Then
		AttachIdleHandler("Generate", 0.1, True);
	EndIf;
EndProcedure

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
	If ComparisonType = Undefined Then
		Return;
	EndIf;
	FillingParameters = New Structure;
	FillingParameters.Insert("EventName", "ChangeComparisonType");
	FillingParameters.Insert("UserSettingsModified", True);
	QuickSettingsFillClient(FillingParameters);
EndProcedure

&AtClient
Procedure EditFilterCriteria(Command)
	FormParameters = New Structure;
	FormParameters.Insert("ReportSettings", ReportSettings);
	FormParameters.Insert("SettingsComposer", Report.SettingsComposer);
	FormParameters.Insert("QuickOnly", True);
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
	QuickSettingsFillClient(FillingParameters);
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure BackgroundJobCheckAtClient()
	Job = BackgroundJobCheckAtServer();
	If Job.Running Then
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler("BackgroundJobCheckAtClient", HandlerParameters.CurrentInterval, True);
	Else
		If ReportCreated Then
			ShowUserNotification(NStr("ru = 'Отчет сформирован'; en = 'Report is generated'; pl = 'Sprawozdanie zostało wygenerowane';es_ES = 'Informe generado';es_CO = 'Informe generado';tr = 'Rapor oluşturuldu';it = 'Il report viene generato';de = 'Bericht wurde generiert'"), , Title);
		Else
			ShowUserNotification(NStr("ru = 'Отчет не сформирован'; en = 'The report is not generated'; pl = 'Raport nie wygenerowany';es_ES = 'Informe no generado';es_CO = 'Informe no generado';tr = 'Rapor oluşturulamadı';it = 'Il report non è stato generato';de = 'Der Bericht wurde nicht generiert'"), , Title);
		EndIf;
		AfterGenerateAtClient();
	EndIf;
EndProcedure

&AtClient
Procedure GenerateBeforeEmailing(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		Handler = New NotifyDescription("SendByEmailAfterGenerate", ThisObject);
		ReportsClient.GenerateReport(ThisObject, Handler);
	EndIf;
EndProcedure

&AtClient
Procedure SendByEmailAfterGenerate(SpreadsheetDocumentGenerated, AdditionalParameters) Export
	If SpreadsheetDocumentGenerated Then
		ShowSendByEmailDialog();
	EndIf;
EndProcedure

&AtClient
Procedure Generate()
	Cancel = False;
	ReportsClientOverridable.BeforeGenerate(ThisObject, Cancel);
	If Cancel Then
		Return;
	EndIf;
	BeforeGenerateAtClient();
	NeedsHandler = BackgroundJobStart(GeneratingOnOpen, ReportSettings.External Or ReportSettings.Safe);
	If NeedsHandler Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler("BackgroundJobCheckAtClient", 1, True);
	Else
		AfterGenerateAtClient();
	EndIf;
EndProcedure

&AtClient
Procedure BeforeGenerateAtClient()
	ReportCreated = False;
	RunMeasurements = ReportSettings.RunMeasurements AND ValueIsFilled(ReportSettings.MeasurementsKey);
	If RunMeasurements Then
		Comment = ReportSettings.MeasurementsPrefix + "; " + NStr("ru = 'Непосредственно:'; en = 'Directly:'; pl = 'Bezpośrednio:';es_ES = 'Directamente:';es_CO = 'Directamente:';tr = 'Doğrudan:';it = 'Direttamente:';de = 'Direkt:'") + " " + String(Directly);
		ModulePerformanceMonitorClient = CommonClient.CommonModule("PerformanceMonitorClient");
		MeasurementID = ModulePerformanceMonitorClient.StartTimeMeasurement(
			False,
			ReportSettings.MeasurementsKey + ".Generation");
		ModulePerformanceMonitorClient.SetMeasurementComment(MeasurementID, Comment);
	EndIf;
EndProcedure

&AtClient
Procedure AfterGenerateAtClient()
	DetachIdleHandler("BackgroundJobCheckAtClient");
	GeneratingOnOpen = False;
	If RunMeasurements Then
		ModulePerformanceMonitorClient = CommonClient.CommonModule("PerformanceMonitorClient");
		ModulePerformanceMonitorClient.StopTimeMeasurement(MeasurementID);
	EndIf;
	ShowSettingsFillingResult();
	RefreshDataRepresentation(); 
	Handler = HandlerAfterGenerateAtClient;
	If TypeOf(Handler) = Type("NotifyDescription") Then
		ExecuteNotifyProcessing(Handler, ReportCreated);
		HandlerAfterGenerateAtClient = Undefined;
	EndIf;
	ReportsClientOverridable.AfterGenerate(ThisObject, ReportCreated);
EndProcedure

&AtClient
Procedure ShowSendByEmailDialog()
	Attachment = New Structure;
	Attachment.Insert("AddressInTempStorage", PutToTempStorage(ReportSpreadsheetDocument, UUID));
	Attachment.Insert("Presentation", ReportCurrentOptionDescription);
	
	AttachmentsList = CommonClientServer.ValueInArray(Attachment);
	
	If CommonClient.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailClient = CommonClient.CommonModule("EmailOperationsClient");
		SendOptions = ModuleEmailClient.EmailSendOptions();
		SendOptions.Subject = ReportCurrentOptionDescription;
		SendOptions.Attachments = AttachmentsList;
		ModuleEmailClient.CreateNewEmailMessage(SendOptions);
	EndIf;
EndProcedure

&AtClient
Procedure VisibilityAvailabilityWhenNecessary()
	If PanelOptionsCurrentOptionKey <> " - " Then // Changes are already applied.
		Return;
	EndIf;
	SetVisibilityAvailability();
EndProcedure

&AtClient
Function FindUserSettingOfItem(ItemNameOrID) Export
	// The application stores data composition IDs for user settings because the settings cannot be 
	//  stored by reference (this will lead to copying the value).
	If StrLen(ItemNameOrID) = 32 Then
		ItemID = ItemNameOrID;
	Else
		ItemID = Right(ItemNameOrID, 32);
	EndIf;
	DCID = QuickSearchForUserSettings.Get(ItemID);
	If DCID = Undefined Then
		Return Undefined;
	Else
		Return Report.SettingsComposer.UserSettings.GetObjectByID(DCID);
	EndIf;
EndFunction

&AtClient
Function FindAdditionalItemSettings(ItemID) Export
	// The application stores data composition IDs for user settings because the settings cannot be 
	//  stored by reference (this will lead to copying the value).
	AllAdditionalSettings = CommonClientServer.StructureProperty(
		Report.SettingsComposer.UserSettings.AdditionalProperties, "FormItems");
	If AllAdditionalSettings = Undefined Then
		Return Undefined;
	Else
		Return AllAdditionalSettings[ItemID];
	EndIf;
EndFunction

&AtClient
Procedure QuickSettingsFillClient(FillingParameters)
	If FillingParameters = Undefined Then
		Return;
	EndIf;
	QuickSettingsFill(FillingParameters);
	ShowSettingsFillingResult();
	If FillingParameters.Property("Regenerate") AND FillingParameters.Regenerate Then
		ClearMessages();
		Generate();
	EndIf;
EndProcedure

&AtClient
Procedure ShowSettingsFillingResult()
	If TypeOf(SettingsFillingResult) <> Type("Structure") Then
		Return;
	EndIf;
	
	OwnSelectionLists = CommonClientServer.StructureProperty(SettingsFillingResult, "OwnSelectionLists");
	If TypeOf(OwnSelectionLists) = Type("Array") Then
		For Each ItemID In OwnSelectionLists Do
			OptionSettingsItem = FindOptionSetting(ThisObject, ItemID);
			If OptionSettingsItem = Undefined Then
				Continue;
			EndIf;
			AdditionalSettings = FindAdditionalItemSettings(ItemID);
			If AdditionalSettings = Undefined
				Or TypeOf(AdditionalSettings.ValuesForSelection) <> Type("ValueList") Then
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
	
	SettingsFillingResult.Clear();
EndProcedure

&AtClient
Procedure ImportSchemaFromFileWithExtension(FileSystemExtensionAttached, AdditionalParameters) Export
	
	If FileSystemExtensionAttached Then
		
		FileSelectionDialog = New FileDialog(FileDialogMode.Open);
		FileSelectionDialog.Filter = "Files XML (*.xml) |*.xml";
		Handler = New NotifyDescription("ImportSchemaFromFileWithExtensionCompletion", ThisObject, AdditionalParameters);
		
		BeginPuttingFiles(Handler, , FileSelectionDialog, True, UUID);
		
	Else // If the web client has no extension attached.
		
		NotifyDescription = New NotifyDescription("ImportSchemaFromFileWithoutExtension", ThisObject);
		BeginPutFile(NotifyDescription, , ,True, UUID);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportSchemaFromFileWithExtensionCompletion(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles <> Undefined AND SelectedFiles.Count() > 0 Then
	
		BinaryData = GetFromTempStorage(SelectedFiles[0].Location);
		Report.SettingsComposer.Settings.AdditionalProperties.Clear();
		Report.SettingsComposer.Settings.AdditionalProperties.Insert("DataCompositionSchema", BinaryData);
		Report.SettingsComposer.Settings.AdditionalProperties.Insert("ReportInitialized", False);
		
		FillingParameters = New Structure;
		FillingParameters.Insert("ResetUserSettings", True);
		FillingParameters.Insert("UserSettingsModified", True);
		FillingParameters.Insert("DCSettingsComposer", Report.SettingsComposer);
		
		QuickSettingsFillClient(FillingParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportSchemaFromFileWithoutExtension(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Not Result Then
		Return;
	EndIf;
	
	BinaryData = GetFromTempStorage(Address);
	Report.SettingsComposer.Settings.AdditionalProperties.Clear();
	Report.SettingsComposer.Settings.AdditionalProperties.Insert("DataCompositionSchema", BinaryData);
	Report.SettingsComposer.Settings.AdditionalProperties.Insert("ReportInitialized", False);
	
	FillingParameters = New Structure;
	FillingParameters.Insert("ResetUserSettings", True);
	FillingParameters.Insert("UserSettingsModified", True);
	FillingParameters.Insert("DCSettingsComposer", Report.SettingsComposer);
	
	QuickSettingsFillClient(FillingParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client or server

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
Procedure SetVisibilityAvailability(UpdateCommands = True)
	ShowOptionsSelectionCommands = ReportOptionMode() AND ReportSettings.SelectOptionsAllowed;
	
	If UpdateCommands Then
		ShowOptionChangingCommands = ShowOptionsSelectionCommands AND ReportSettings.EditOptionsAllowed;
		HasSettings = HasQuickSettings Or HasRegularSettings;
		
		Items.AllSettings.Visible     = ShowOptionChangingCommands Or HasRegularSettings;
		Items.ReportOptions.Visible   = ShowOptionsSelectionCommands;
		Items.ChangeOption.Visible  = ShowOptionChangingCommands;
		Items.SelectOption.Visible   = ShowOptionsSelectionCommands;
		CommonClientServer.SetFormItemProperty(
			Items,
			"SaveOption",
			"Visible",
			ShowOptionChangingCommands); // If the command is unavailable due to rights, the button disappears.
		Items.EditFilterCriteria.Visible = HasSettings AND ReportOptionMode();
		CommonClientServer.SetFormItemProperty(
			Items,
			"SelectSettings",
			"Visible",
			ShowOptionsSelectionCommands AND HasSettings); // If the command is unavailable due to rights, the button disappears.
		CommonClientServer.SetFormItemProperty(
			Items,
			"SaveSettings",
			"Visible",
			ShowOptionsSelectionCommands AND HasSettings); // If the command is unavailable due to rights, the button disappears.
	EndIf;
	
	// Options selection commands.
	If PanelOptionsCurrentOptionKey <> CurrentVariantKey Then
		PanelOptionsCurrentOptionKey = CurrentVariantKey;
		
		If ShowOptionsSelectionCommands Then
			FillOptionsSelectionCommands();
		EndIf;
		
		If OutputRight Then
			WindowOptionsKey = ReportsClientServer.UniqueKey(ReportSettings.FullName, CurrentVariantKey);
			ReportSettings.Print.Insert("PrintParametersKey", WindowOptionsKey);
			FillPropertyValues(ReportSpreadsheetDocument, ReportSettings.Print);
		EndIf;
		
		URL = "";
		If ValueIsFilled(ReportSettings.OptionRef)
			AND Not ReportSettings.External
			AND Not ReportSettings.Contextual Then
			URL = GetURL(ReportSettings.OptionRef);
		EndIf;
	EndIf;
	
	Items.ImportSchemaFromFile.Visible = Not Common.DataSeparationEnabled();
	
	// Title.
	ReportCurrentOptionDescription = TrimAll(ReportCurrentOptionDescription);
	If ValueIsFilled(ReportCurrentOptionDescription) Then
		Title = ReportCurrentOptionDescription;
	Else
		Title = ReportSettings.Description;
	EndIf;
	If DetailsMode Then
		Title = Title + " (" + NStr("ru = 'Описание'; en = 'Details'; pl = 'Szczegóły';es_ES = 'Detalles';es_CO = 'Detalles';tr = 'Ayrıntılar';it = 'Dettagli';de = 'Details'") + ")";
	EndIf;
EndProcedure

&AtServer
Procedure QuickSettingsFill(Val ClientParameters)
	// Paste default values for required keys of filling parameters.
	FillingParameters = QuickSettingsFillParameters(ClientParameters);
	
	// Call an overridable module.
	If ReportSettings.Events.BeforeFillQuickSettingsBar Then
		ReportObject = ReportsServer.ReportObject(FillingParameters.ReportObjectOrFullName);
		ReportObject.BeforeFillQuickSettingsBar(ThisObject, FillingParameters);
	EndIf;
	
	// Record new option settings and user settings in a composer.
	QuickSettingsImportSettingsToComposer(FillingParameters);
	
	// Get information from the DC.
	OutputConditions = New Structure;
	OutputConditions.Insert("UserSettingsOnly", True);
	OutputConditions.Insert("QuickOnly",          True);
	OutputConditions.Insert("CurrentDCNodeID", Undefined);
	Information = ReportsServer.AdvancedInformationOnSettings(
		Report.SettingsComposer,
		ReportSettings,
		FillingParameters.ReportObjectOrFullName,
		OutputConditions);
	HasQuickSettings = Information.HasQuickSettings;
	HasRegularSettings = Information.HasRegularSettings;
	
	// Remove items of old settings.
	QuickSettingsRemoveOldItemsAndCommands(FillingParameters);
	
	// Add items of relevant settings and load values.
	QuickSettingsCreateControlItemAndImportValues(FillingParameters, Information);
	
	// Links.
	RegisterLinksThatCanBeDisabled(Information);
	
	// Standard periods.
	ReportSettings.Insert("StandardPeriods", New Array);
	StandardPeriods = Information.UserSettings.FindRows(New Structure("ItemsType", "StandardPeriod"));
	For Each SettingProperties In StandardPeriods Do
		ReportSettings.StandardPeriods.Add(SettingProperties.DCID);
	EndDo;
	
	// Process additional settings.
	AfterChangeKeyStates(FillingParameters);
	
	SetVisibilityAvailability();
	
	// Call an overridable module.
	If ReportSettings.Events.AfterQuickSettingsBarFilled Then
		ReportObject = ReportsServer.ReportObject(FillingParameters.ReportObjectOrFullName);
		ReportObject.AfterQuickSettingsBarFilled(ThisObject, FillingParameters);
	EndIf;
	
	If ReportSettings.Property("ReportObject") Then
		ReportSettings.Delete("ReportObject");
	EndIf;
	
	SettingsFillingResult = FillingParameters.Result;
	ReportsServer.ClearAdvancedInformationOnSettings(Information);
EndProcedure

&AtServer
Function BackgroundJobStart(Val GeneratingOnOpen, Directly)
	If BackgroundJobID <> Undefined Then
		BackgroundJobCancel(BackgroundJobID);
		BackgroundJobID = Undefined;
	EndIf;
	
	If Not CheckFilling() Then
		If GeneratingOnOpen Then
			ErrorText = "";
			Messages = GetUserMessages(True);
			For Each Message In Messages Do
				ErrorText = ErrorText + ?(ErrorText = "", "", ";" + Chars.LF + Chars.LF) + Message.Text;
			EndDo;
			ShowGenerationErrors(ErrorText);
		EndIf;
		Return False;
	EndIf;
	
	// Run the background job
	ReportGenerationParameters = New Structure;
	ReportGenerationParameters.Insert("ReportRef",   ReportSettings.ReportRef);
	ReportGenerationParameters.Insert("OptionRef", ReportSettings.OptionRef);
	ReportGenerationParameters.Insert("VariantKey",   CurrentVariantKey);
	ReportGenerationParameters.Insert("DCSettings",                 Report.SettingsComposer.Settings);
	ReportGenerationParameters.Insert("FixedDCSettings",    Report.SettingsComposer.FixedSettings);
	ReportGenerationParameters.Insert("DCUserSettings", Report.SettingsComposer.UserSettings);
	ReportGenerationParameters.Insert("SchemaModified", ReportSettings.SchemaModified);
	ReportGenerationParameters.Insert("SchemaKey",           ReportSettings.SchemaKey);
	
	NameOfReport = StrSplit(ReportSettings.FullName, ".")[1];
	
	If ReportSettings.RunMeasurements AND ValueIsFilled(ReportSettings.MeasurementsKey) Then
		ViewPoints = New Map;
		ViewPoints.Insert("ReportName",            NameOfReport);
		ViewPoints.Insert("OriginalOptionName", ReportSettings.OriginalOptionName);
		ViewPoints.Insert("External",          Number(ReportSettings.External));
		ViewPoints.Insert("Custom", Number(ReportSettings.Custom));
		ViewPoints.Insert("Details",      Number(DetailsMode));
		ViewPoints.Insert("ItemModified",    Number(VariantModified));
		
		If ReportSettings.Property("StandardPeriods") Then
			For Each DCID In ReportSettings.StandardPeriods Do
				DCUserSetting = Report.SettingsComposer.UserSettings.GetObjectByID(DCID);
				If TypeOf(DCUserSetting) = Type("DataCompositionFilterItem") Then
					Value = DCUserSetting.RightValue;
				ElsIf TypeOf(DCUserSetting) = Type("DataCompositionSettingsParameterValue") Then
					Value = DCUserSetting.Value;
				Else
					Continue;
				EndIf;
				If DCUserSetting.Use AND TypeOf(Value) = Type("StandardPeriod") Then
					CommonClientServer.SupplementStructure(ViewPoints, ReportsServer.PeriodAnalysis(Value), True);
					ReportSettings.Insert("Period", Value);
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		ReportGenerationParameters.Insert("KeyOperationName", ReportSettings.MeasurementsKey + ".Generation");
		ReportGenerationParameters.Insert("KeyOperationComment", ViewPoints);
	EndIf;
	
	If Directly Then
		If ReportSettings.SchemaModified Then
			ReportGenerationParameters.Insert("SchemaURL", ReportSettings.SchemaURL);
		EndIf;
		ReportGenerationParameters.Insert("Object", FormAttributeToValue("Report"));
		ReportGenerationParameters.Insert("FullName", ReportSettings.FullName);
	Else
		If ReportSettings.SchemaModified Then
			ReportGenerationParameters.Insert("DCSchema", GetFromTempStorage(ReportSettings.SchemaURL));
		EndIf;
	EndIf;
	
	StartParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Выполнение отчета: %1'; en = 'Report execution: %1'; pl = 'Wykonanie raportu: %1';es_ES = 'Realización del informe: %1';es_CO = 'Realización del informe: %1';tr = 'Rapor yürütme: %1';it = 'Esecuzione Report: %1';de = 'Ausführung des Berichts: %1'"),
		NameOfReport);
	StartParameters.WaitForCompletion = False;
	StartParameters.RunNotInBackground = Directly;
	BackgroundJobResult = TimeConsumingOperations.ExecuteInBackground(
		"ReportsOptions.GenerateReportInBackground",
		ReportGenerationParameters,
		StartParameters);
	
	If BackgroundJobResult.Status = "Error" Then
		ShowGenerationErrors(BackgroundJobResult.BriefErrorPresentation);
		Return False;
	EndIf;
	
	BackgroundJobID  = BackgroundJobResult.JobID;
	BackgroundJobStorageAddress = BackgroundJobResult.ResultAddress;
	
	If BackgroundJobResult.Status = "Completed" Then
		BackgroundJobImportResult();
		JobStarted = False;
	Else
		StatePresentation = Items.ReportSpreadsheetDocument.StatePresentation;
		StatePresentation.Visible                      = True;
		StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance;
		StatePresentation.Picture                       = PictureLib.TimeConsumingOperation48;
		StatePresentation.Text                          = NStr("ru = 'Отчет формируется...'; en = 'Generating report...'; pl = 'Generowanie raportu...';es_ES = 'Generando el informe...';es_CO = 'Generando el informe...';tr = 'Rapor oluşturma...';it = 'Generazione report...';de = 'Den Bericht erstellen...'");
		
		JobStarted = True;
	EndIf;
	
	Return JobStarted;
EndFunction

&AtServer
Function BackgroundJobCheckAtServer()
	Job = FindJobInternal(BackgroundJobID);
	If Not Job.Running Then
		If Job.Success Then
			BackgroundJobImportResult();
		Else
			ShowGenerationErrors(Job.Error);
		EndIf;
	EndIf;
	Job.Delete("Error");
	Return Job;
EndFunction

&AtServer
Function FindJobInternal(Val ID)
	// Reads the background job status by the passed ID.
	//
	// Parameters:
	//   ID - UUID - the background job ID.
	//
	// Returns:
	//   Undefined - the job is not found.
	//   Structure - info on the job.
	//       * Running - Boolean - True if the background job is running.
	//       * Success     - Boolean - True if the background job session completed without errors.
	//       * Error      - String, ErrorInfo, Undefined - error description.
	//
	Result = New Structure("Running, Success, Error", False, False, Undefined);
	If ID = Undefined Then
		Return Result;
	EndIf;
	Job = BackgroundJobs.FindByUUID(ID);
	If Job = Undefined Then
		Return Result;
	EndIf;
	
	If Job.State = BackgroundJobState.Active Then
		Result.Running = True;
	Else
		Result.Running = False;
		If Job.State = BackgroundJobState.Completed Then
			Result.Success = True;
		Else
			Result.Success = False;
			Result.Error = Job.ErrorInfo;
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

&AtServerNoContext
Procedure BackgroundJobCancel(BackgroundJobID)
	TimeConsumingOperations.CancelJobExecution(BackgroundJobID);
EndProcedure

&AtServer
Procedure ImportOption(OptionKey)
	If Not DetailsMode Then
		// Saving the current user settings.
		Common.SystemSettingsStorageSave(
			ReportSettings.FullName + "/" + CurrentVariantKey + "/CurrentUserSettings",
			"",
			Report.SettingsComposer.UserSettings);
	EndIf;
	DetailsMode = False;
	VariantModified = False;
	UserSettingsModified = False;
	ReportSettings.ReadCreateFromUserSettingsImmediatelyCheckBox = True;
	// Importing a new option.
	SetCurrentVariant(OptionKey);
	// Switch the state.
	StatePresentation = Items.ReportSpreadsheetDocument.StatePresentation;
	StatePresentation.Visible = True;
	StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance;
	StatePresentation.Picture  = PictureLib.Information32;
	StatePresentation.Text     = NStr("ru = 'Выбран другой вариант отчета. Нажмите ""Сформировать"" для получения отчета.'; en = 'Another report option is selected. Click ""Run report"" to generate the report.'; pl = 'Wybrano wariant raportu. Kliknij ""Wygeneruj"", aby otrzymać raport.';es_ES = 'Otra opción del informe se ha seleccionado. Hace clic en ""Generar"" para recibir el informe.';es_CO = 'Otra opción del informe se ha seleccionado. Hace clic en ""Generar"" para recibir el informe.';tr = 'Başka bir rapor seçeneği seçildi. Raporu almak için ""Oluştur"" ''a tıklayın.';it = 'Un altra variante di report è selezionata. Premere ""Avvia report"" per generare il report.';de = 'Eine andere Berichtsvariante ist ausgewählt. Klicken Sie auf ""Bericht asuführen"", um den Bericht zu generieren.'");
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
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
		AND SettingProperties.ItemsType <> "ValueCheckBoxOnly");
	
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
			
			ParameterName = String(SettingProperties.DCField);
			If ParameterName = "DataParameters.MetadataObjectType" Then
				InputField.SetAction("OnChange", "Attachable_MatedataObjectType_OnChange");
			ElsIf ParameterName = "DataParameters.MetadataObjectName" Then
				InputField.SetAction("OnChange", "Attachable_MetadataObjectName_OnChange");
			ElsIf ParameterName = "DataParameters.TableName" Then
				InputField.SetAction("OnChange", "Attachable_TableName_OnChange");
			Else
				InputField.SetAction("OnChange", "Attachable_InputField_OnChange");
			EndIf;
			
			// A link with DCS.
			InputField.DataPath = OtherSettings.PathToComposer + ".UserSettings[" + SettingProperties.IndexInCollection + "].Value";
			
			If SettingProperties.ListInput Then
				InputField.SetAction("StartChoice", "Attachable_ComposerList_StartChoice");
			ElsIf SettingProperties.AvailableDCSetting <> Undefined
				AND SettingProperties.AvailableDCSetting.QuickChoice <> True Then
				// If there are "ByMetadata" or "SelectionParameters" detachable references from a subordinate 
				// object, then the applied logic is used for selection.
				If SettingProperties.OptionSetting.ChoiceParameterLinks.Count() > 0
					Or SettingProperties.OptionSetting.MetadataRelations.Count() > 0 Then
					InputField.SetAction("StartChoice", "Attachable_ComposerValue_StartChoice");
				EndIf;
			EndIf;
			
			If SettingProperties.Type = "SettingsParameterValue"
				Or SettingProperties.Type = "FilterItem" Then
				
				FillPropertyValues(InputField, SettingProperties.AvailableDCSetting, "QuickChoice, Mask, ChoiceForm, EditFormat");
				
				If SettingProperties.Type = "SettingsParameterValue" Then
					InputField.AutoMarkIncomplete = SettingProperties.AvailableDCSetting.DenyIncompleteValues;
				EndIf;
				
				InputField.ChoiceFoldersAndItems = SettingProperties.ChoiceFoldersAndItems;
				
				// The following types of input fields do not stretch horizontally and do not have the clear button:
				//     Date, Boolean, Number, Type.
				InputField.OpenButton           = False;
				InputField.SpinButton      = False;
				InputField.ClearButton            = TypesInformation.ContainsObjectTypes;
				InputField.HorizontalStretch = TypesInformation.ContainsObjectTypes;
				
				If Not SettingProperties.ListInput Then
					For Each ListItemInForm In SettingProperties.ValuesForSelection Do
						FillPropertyValues(InputField.ChoiceList.Add(), ListItemInForm);
					EndDo;
					If SettingProperties.RestrictSelectionBySpecifiedValues Then
						InputField.ListChoiceMode      = True;
						InputField.CreateButton           = False;
						InputField.ChoiceButton             = False;
						InputField.DropListButton  = True;
						InputField.HorizontalStretch = True;
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
				
				// Condition.
				If OutputCondition Then
					ComparisonTypeButton = Items.Add(ComparisonTypeCommandName, Type("FormButton"), InputField.ContextMenu);
					ComparisonTypeButton.CommandName = ComparisonTypeCommandName;
				EndIf;
				
				ParameterName = String(SettingProperties.DCField);
				If ParameterName = "DataParameters.MetadataObjectType" Then
					InputField.Width = 20;
					InputField.HorizontalStretch = False;
				EndIf;
				
			EndIf;
			
		ElsIf SettingProperties.ItemsType = "StandardPeriod" Then
			
			Folder.Group = ChildFormItemsGroup.AlwaysHorizontal;
			
			OutputItem.Size = 1;
			OutputItem.Item2Name = GroupName;
			
			StartPeriodName    = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "Begin");
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
			PickButtonName    = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "Pickup");
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
						PasteCommand.Picture  = PictureLib.FillForm;
						
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
			FormTable.ChangeRowOrder      = True;
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
			
			FillPropertyValues(ValueColumnItem, SettingProperties.AvailableDCSetting, "QuickChoice, Mask, ChoiceForm, EditFormat");
			
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
	
	ParameterName = String(SettingProperties.DCField);
	If ParameterName = "DataParameters.MetadataObjectType"
		Or ParameterName = "DataParameters.MetadataObjectName"
		Or ParameterName = "DataParameters.TableName" Then
		LabelField.Visible = False;
	EndIf;
	
	If SettingProperties.ItemsType = "StandardPeriod" Then
		OutputGroup.Order.Insert(0, OutputItem);
	Else
		OutputGroup.Order.Add(OutputItem);
	EndIf;
	OutputGroup.Size = OutputGroup.Size + OutputItem.Size;
	
EndProcedure

&AtServer
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

&AtServer
Function TypesDetailsMatch(TypesDetails1, TypesDetails2)
	If TypesDetails1 = Undefined Or TypesDetails2 = Undefined Then
		Return False;
	EndIf;
	
	Return TypesDetails1 = TypesDetails2
		Or Common.ValueToXMLString(TypesDetails1) = Common.ValueToXMLString(TypesDetails2);
EndFunction

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
	EndIf;
	
	FillingParameters.Insert("ReportObjectOrFullName", ReportSettings.FullName);
	If ReportSettings.Events.BeforeFillQuickSettingsBar
		Or ReportSettings.Events.AfterQuickSettingsBarFilled
		Or ReportSettings.Events.BeforeImportSettingsToComposer Then
		FillingParameters.ReportObjectOrFullName = FormAttributeToValue("Report");
	EndIf;
	
	Return FillingParameters;
EndFunction

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
	
	ClearOptionSettings = CommonClientServer.StructureProperty(FillingParameters, "ClearOptionSettings", False);
	If ClearOptionSettings Then
		ImportOption(CurrentVariantKey);
	EndIf;
	
	ResetUserSettings = CommonClientServer.StructureProperty(FillingParameters, "ResetUserSettings", False);
	If ResetUserSettings Then
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
	If SettingsImported Then
		// To set fixed filters, use the composer as it comprises the most complete collection of settings.
		// In parameters, in BeforeImport, some parameters can be missing if their settings were not overwritten.
		If TypeOf(ParametersForm.Filter) = Type("Structure") Then
			ReportsServer.SetFixedFilters(ParametersForm.Filter, Report.SettingsComposer.Settings, ReportSettings);
		EndIf;
		Report.SettingsComposer.Settings.AdditionalProperties.Insert("VariantKey", CurrentVariantKey);
		Report.SettingsComposer.Settings.AdditionalProperties.Insert("DescriptionOption", ReportCurrentOptionDescription);
	EndIf;
	
	Report.SettingsComposer.Settings.AdditionalProperties.Insert("VariantKey", CurrentVariantKey);
	Report.SettingsComposer.Settings.AdditionalProperties.Insert("DescriptionOption", ReportCurrentOptionDescription);
	
	// Prepare for the composer preinitialization (used for details).
	If ReportSettings.SchemaModified Then
		Report.SettingsComposer.Settings.AdditionalProperties.Insert("SchemaURL", ReportSettings.SchemaURL);
	EndIf;
	
	If FillingParameters.Property("SettingsFormAdvancedMode") Then
		ReportSettings.Insert("SettingsFormAdvancedMode", FillingParameters.SettingsFormAdvancedMode);
	EndIf;
	If FillingParameters.Property("SettingsFormPageName") Then
		ReportSettings.Insert("SettingsFormPageName", FillingParameters.SettingsFormPageName);
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
		VariantModified = True;
	EndIf;
	
	If FillingParameters.UserSettingsModified Then
		UserSettingsModified = True;
	EndIf;
	
	If ReportSettings.ReadCreateFromUserSettingsImmediatelyCheckBox Then
		ReportSettings.ReadCreateFromUserSettingsImmediatelyCheckBox = False;
		Items.GenerateImmediately.Check = CommonClientServer.StructureProperty(
			Report.SettingsComposer.UserSettings.AdditionalProperties,
			"GenerateImmediately",
			ReportSettings.GenerateImmediately);
	EndIf;
EndProcedure

&AtServer
Procedure QuickSettingsRemoveOldItemsAndCommands(FillingParameters)
	// Remove items.
	ItemsToRemove = New Array;
	AddSubordinateItems(ItemsToRemove, Items.QuickSettings.ChildItems);
	AddSubordinateItems(ItemsToRemove, Items.MainParametersSettings.ChildItems);
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
	AllAttributes = GetAttributes();
	For Each Attribute In AllAttributes Do
		FullAttributeName = Attribute.Name + ?(IsBlankString(Attribute.Path), "", "." + Attribute.Path);
		If ConstantAttributes.FindByValue(FullAttributeName) = Undefined Then
			FillingParameters.Attributes.Existing.Insert(FullAttributeName, Attribute.ValueType);
		EndIf;
	EndDo;
	
	// Local variables for setting values and properties after attributes creation.
	AddedInputFields          = New Structure;
	AddedStandardPeriods = New Array;
	
	// Link structure.
	Links = Information.Links;
	
	MainFormAttributesNames     = New Map;
	NamesOfItemsForEstablishingLinks = New Map;
	
	DCSettingsComposer       = Report.SettingsComposer;
	DCUserSettings = DCSettingsComposer.UserSettings;
	
	AdditionalItemsSettings = CommonClientServer.StructureProperty(DCUserSettings.AdditionalProperties, "FormItems");
	If AdditionalItemsSettings = Undefined Then
		AdditionalItemsSettings = New Map;
	EndIf;
	
	SettingTemplate = New Structure("Type, Subtype, Template, TreeRow,
		|DCUserSetting, ID, DCOptionSetting, AvailableDCSetting");
	SettingTemplate.Insert("Hierarchy", False);
	SettingTemplate.Insert("UsageCheckBox", False);
	SettingTemplate.Insert("ListInput", False);
	SettingTemplate.Insert("RestrictSelectionBySpecifiedValues", False);
	SettingTemplate = New FixedStructure(SettingTemplate);
	
	OutputGroups = New Structure;
	OutputGroups.Insert("Quick", New Structure("Order, Size", New Array, 0));
	OutputGroups.Insert("Main", New Structure("Order, Size", New Array, 0));
	
	HasDataImportFromFile = Common.SubsystemExists("StandardSubsystems.ImportDataFromFile");
	
	SettingsToOutput = Information.UserSettings.Copy(New Structure("OutputAllowed, Quick", True, True));
	SettingsToOutput.Sort("IndexInCollection Asc");
	
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
	OtherSettings.Insert("AddedValuesList",     Undefined);
	OtherSettings.Insert("HasFiltersWithConditions", False);
	
	OutputGroup = OutputGroups.Quick;
	
	For Each SettingProperties In SettingsToOutput Do
		UserSettingsMap.Insert(SettingProperties.ItemID, SettingProperties.DCID);
		
		If SettingProperties.OptionSetting <> Undefined Then
			SearchOptionSetting = New Structure;
			SearchOptionSetting.Insert("DCNodeID",     SettingProperties.TreeRow.DCID);
			SearchOptionSetting.Insert("CollectionName",            SettingProperties.OptionSetting.CollectionName);
			SearchOptionSetting.Insert("DCItemID", SettingProperties.OptionSetting.DCID);
			OptionSettingsMap.Insert(SettingProperties.ItemID, SearchOptionSetting);
		EndIf;
		
		
		ParameterName = String(SettingProperties.DCField);
		If SettingProperties.ItemsType = "StandardPeriod" Then
			OutputSettingItems(ThisObject, Items, SettingProperties, OutputGroups.Main, OtherSettings);
		ElsIf ParameterName = "DataParameters.MetadataObjectType"
			Or ParameterName = "DataParameters.MetadataObjectName"
			Or ParameterName = "DataParameters.TableName" Then
			OutputSettingItems(ThisObject, Items, SettingProperties, OutputGroups.Main, OtherSettings);
		Else
			OutputSettingItems(ThisObject, Items, SettingProperties, OutputGroup, OtherSettings);
		EndIf;
		
	EndDo;
	
	Items.EditFilterCriteria.Visible = OtherSettings.HasFiltersWithConditions;
	
	ReportsServer.OutputInOrder(ThisObject, OutputGroup, Items.QuickSettings, 2, False);
	ReportsServer.OutputInOrder(ThisObject, OutputGroups.Main, Items.MainParametersSettings, 4, False);
	
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
		If Not ReportSettings.Property("Period") Then 
			ReportSettings.Insert("Period", SettingProperties.Value);
		EndIf;
		ThisObject[More.ValueName] = ReportSettings.Period;
		Items[More.StartPeriodName].DataPath    = More.ValueName + ".StartDate";
		Items[More.EndPeriodName].DataPath = More.ValueName + ".EndDate";
	EndDo;
	
	// Save matches for quick search in the form data.
	QuickSearchForUserSettings = New FixedMap(UserSettingsMap);
	QuickSearchForMetadataObjectsNames   = New FixedMap(MetadataObjectNamesMap);
	QuickSearchForOptionSettings         = New FixedMap(OptionSettingsMap);
	
	DCUserSettings.AdditionalProperties.Insert("FormItems", AdditionalItemsSettings);
EndProcedure

&AtServer
Procedure BackgroundJobImportResult()
	
	GenerationResult = GetFromTempStorage(BackgroundJobStorageAddress);
	
	DeleteFromTempStorage(BackgroundJobStorageAddress);
	BackgroundJobStorageAddress = Undefined;
	BackgroundJobID = Undefined;
	
	Success = CommonClientServer.StructureProperty(GenerationResult, "Success");
	If Success <> True Then
		ShowGenerationErrors(GenerationResult.ErrorText);
		Return;
	EndIf;
	
	DataStillUpdating = CommonClientServer.StructureProperty(GenerationResult, "DataStillUpdating", False);
	If DataStillUpdating Then
		CommonClientServer.MessageToUser(ReportsOptions.DataIsBeingUpdatedMessage());
	EndIf;
	
	StatePresentation = Items.ReportSpreadsheetDocument.StatePresentation;
	StatePresentation.Visible                      = False;
	StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
	StatePresentation.Picture                       = New Picture;
	StatePresentation.Text                          = "";
	
	FillPropertyValues(ReportSettings.Print, ReportSpreadsheetDocument); // Save print settings.
	ReportSpreadsheetDocument = GenerationResult.SpreadsheetDocument;
	FillPropertyValues(ReportSpreadsheetDocument, ReportSettings.Print); // Recovery.
	
	ReportCreated = True;
	
	If ValueIsFilled(ReportDetailsData) AND IsTempStorageURL(ReportDetailsData) Then
		DeleteFromTempStorage(ReportDetailsData);
	EndIf;
	ReportDetailsData = PutToTempStorage(GenerationResult.Details, UUID);
	
	If GenerationResult.VariantModified
		Or GenerationResult.UserSettingsModified Then
		GenerationResult.Insert("EventName", "AfterGenerate");
		GenerationResult.Insert("Directly", False);
		QuickSettingsFill(GenerationResult);
	EndIf;
EndProcedure

&AtServer
Procedure ShowGenerationErrors(ErrorInformation)
	If TypeOf(ErrorInformation) = Type("ErrorInfo") Then
		ErrorDescription = BriefErrorDescription(ErrorInformation);
		DetailedErrorPresentation = NStr("ru = 'Ошибка при формировании:'; en = 'Generation error:'; pl = 'Błąd generowania:';es_ES = 'Error de generación:';es_CO = 'Error de generación:';tr = 'Oluşturma hatası:';it = 'Errore di generazione:';de = 'Generierungsfehler:'") + Chars.LF + DetailErrorDescription(ErrorInformation);
		If IsBlankString(ErrorDescription) Then
			ErrorDescription = DetailedErrorPresentation;
		EndIf;
	Else
		ErrorDescription = ErrorInformation;
		DetailedErrorPresentation = "";
	EndIf;
	
	StatePresentation = Items.ReportSpreadsheetDocument.StatePresentation;
	StatePresentation.Visible                      = True;
	StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance;
	StatePresentation.Picture                       = New Picture;
	StatePresentation.Text                          = ErrorDescription;
	
	If Not IsBlankString(DetailedErrorPresentation) Then
		ReportsOptions.WriteToLog(EventLogLevel.Warning, DetailedErrorPresentation, ReportSettings.OptionRef);
	EndIf;
EndProcedure

&AtServer
Procedure FillOptionsSelectionCommands()
	FormOptions = FormAttributeToValue("AddedOptions");
	FormOptions.Columns.Add("Found", New TypeDescription("Boolean"));
	AuthorizedUser = Users.AuthorizedUser();
	
	SearchParameters = New Structure;
	SearchParameters.Insert("Reports", ReportsClientServer.ValueToArray(ReportSettings.ReportRef));
	SearchParameters.Insert("GetSummaryTable", True);
	SearchResult = ReportsOptions.FindLinks(SearchParameters);
	ReportOptionsTable = SearchResult.ValueTable;
	If ReportSettings.External Then // Add predefined options of the external report to the options table.
		For Each ListItem In ReportSettings.PredefinedOptions Do
			TableRow = ReportOptionsTable.Add();
			TableRow.Description = ListItem.Presentation;
			TableRow.VariantKey = ListItem.Value;
		EndDo;
	EndIf;
	ReportOptionsTable.GroupBy("Ref, VariantKey, Description, Author, AvailableToAuthorOnly");
	ReportOptionsTable.Sort("Description Asc, VariantKey Asc");
	
	Folder = Items.ReportOptions;
	LastIndex = FormOptions.Count() - 1;
	For Each TableRow In ReportOptionsTable Do
		If TableRow.AvailableToAuthorOnly = True
			AND TableRow.Author <> AuthorizedUser Then
			Continue;
		EndIf;
		FoundItems = FormOptions.FindRows(New Structure("VariantKey, Found", TableRow.VariantKey, False));
		If FoundItems.Count() = 1 Then
			FormOption = FoundItems[0];
			FormOption.Found = True;
			Button = Items.Find(FormOption.CommandName);
			Button.Visible = True;
			Button.Title = TableRow.Description;
			Items.Move(Button, Folder);
		Else
			LastIndex = LastIndex + 1;
			FormOption = FormOptions.Add();
			FillPropertyValues(FormOption, TableRow);
			FormOption.Found = True;
			FormOption.CommandName = "SelectOption_" + Format(LastIndex, "NZ=0; NG=");
			
			Command = Commands.Add(FormOption.CommandName);
			Command.Action = "Attachable_ImportReportOption";
			
			Button = Items.Add(FormOption.CommandName, Type("FormButton"), Folder);
			Button.Type = FormButtonType.CommandBarButton;
			Button.CommandName = FormOption.CommandName;
			Button.Title = TableRow.Description;
			
			ConstantCommands.Add(FormOption.CommandName);
		EndIf;
		Button.Check = (CurrentVariantKey = TableRow.VariantKey);
	EndDo;
	
	FoundItems = FormOptions.FindRows(New Structure("Found", False));
	For Each FormOption In FoundItems Do
		Button = Items.Find(FormOption.CommandName);
		Button.Visible = False;
	EndDo;
	
	FormOptions.Columns.Delete("Found");
	ValueToFormAttribute(FormOptions, "AddedOptions");
EndProcedure

&AtServer
Procedure AfterChangeKeyStates(FillingParameters)
	If FillingParameters.EventName <> "AfterGenerate" Then
		Regenerate = CommonClientServer.StructureProperty(FillingParameters, "Regenerate");
		If Regenerate = True Then
			StatePresentation = Items.ReportSpreadsheetDocument.StatePresentation;
			StatePresentation.Visible                      = True;
			StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
			StatePresentation.Picture                       = PictureLib.TimeConsumingOperation48;
			StatePresentation.Text                          = NStr("ru = 'Отчет формируется...'; en = 'Generating report...'; pl = 'Generowanie raportu...';es_ES = 'Generando el informe...';es_CO = 'Generando el informe...';tr = 'Rapor oluşturma...';it = 'Generazione report...';de = 'Den Bericht erstellen...'");
		ElsIf FillingParameters.VariantModified
			Or FillingParameters.UserSettingsModified Then
			StatePresentation = Items.ReportSpreadsheetDocument.StatePresentation;
			StatePresentation.Visible = True;
			StatePresentation.Text     = NStr("ru = 'Изменились настройки. Нажмите ""Сформировать"" для получения отчета.'; en = 'Settings were changed. Click ""Run report"" to get the report.'; pl = 'Ustawienia zostały zmienione. Kliknij ""Wygeneruj"", aby otrzymać sprawozdanie.';es_ES = 'Configuraciones se han cambiado. Hacer clic en ""Generar"" para obtener el informe.';es_CO = 'Configuraciones se han cambiado. Hacer clic en ""Generar"" para obtener el informe.';tr = 'Ayarlar değiştirildi. Raporu almak için ""Oluştur"" ''a tıklayın.';it = 'Sono state modificate le impostazioni. Fare clic su ""Eseguire il report"" per ottenere il report.';de = 'Einstellungen wurden geändert. Klicken Sie auf ""Bericht ausführen"", um den Bericht zu erhalten.'");
			If Regenerate = Undefined Then
				StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance;
			Else
				StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
			EndIf;
		EndIf;
	EndIf;
	// In safe mode, you cannot save reports using the standard dialog box displayed before closing 
	// because the privileged mode is not enabled while accessing the exchange plans.
	If ReportSettings.Safe
		AND Not Users.IsFullUser() Then
		VariantModified = False;
	EndIf;
	// If a user is not allowed to change options of the report, the standard dialog box is not shown as well.
	If Not ReportSettings.EditOptionsAllowed Then
		VariantModified = False;
	EndIf;
EndProcedure

&AtServer
Procedure RegisterLinksThatCanBeDisabled(Information)
	LinksThatCanBeDisabled.Clear();
	For Each LinkDetails In Information.LinksThatCanBeDisabled Do
		Link = LinksThatCanBeDisabled.Add();
		FillPropertyValues(Link, LinkDetails);
		Link.MainIDInForm     = LinkDetails.Master.ItemID;
		Link.SubordinateIDInForm = LinkDetails.SubordinateSettingsItem.ItemID;
	EndDo;
EndProcedure

&AtServer
Procedure UpdateInfoOnReportOption()
	Report.SettingsComposer.Settings.AdditionalProperties.Insert("VariantKey", CurrentVariantKey);
	Report.SettingsComposer.Settings.AdditionalProperties.Insert("DescriptionOption", ReportCurrentOptionDescription);
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	ReportsOptions.Ref AS OptionRef,
	|	ReportsOptions.PredefinedVariant.MeasurementsKey AS MeasurementsKey,
	|	ReportsOptions.PredefinedVariant AS PredefinedRef,
	|	CASE
	|		WHEN ReportsOptions.Custom
	|				OR ReportsOptions.Parent.VariantKey IS NULL 
	|			THEN ReportsOptions.VariantKey
	|		ELSE ReportsOptions.Parent.VariantKey
	|	END AS OriginalOptionName,
	|	ReportsOptions.Custom AS Custom
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Report = &Report
	|	AND ReportsOptions.VariantKey = &VariantKey";
	Query.SetParameter("Report", ReportSettings.ReportRef);
	Query.SetParameter("VariantKey", CurrentVariantKey);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		ReportSettings.Insert("OptionRef",          Selection.OptionRef);
		ReportSettings.Insert("MeasurementsKey",            Selection.MeasurementsKey);
		ReportSettings.Insert("PredefinedRef", Selection.PredefinedRef);
		ReportSettings.Insert("OriginalOptionName",   ?(Selection.Custom, Selection.OriginalOptionName, CurrentVariantKey));
		ReportSettings.Insert("Custom",       Selection.Custom);
	Else
		ReportSettings.Insert("OptionRef",          Undefined);
		ReportSettings.Insert("MeasurementsKey",            Undefined);
		ReportSettings.Insert("PredefinedRef", Undefined);
		ReportSettings.Insert("OriginalOptionName",   Undefined);
		ReportSettings.Insert("Custom",       Undefined);
	EndIf;
EndProcedure

&AtServer
Function ReportOptionMode()
	Return TypeOf(CurrentVariantKey) = Type("String") AND Not IsBlankString(CurrentVariantKey);
EndFunction

// Sets the "DataSource" parameter of current report option settings.
//
// Parameters:
//  Option - CatalogRef.ReportsOptions - a report option settings storage.
//
&AtServerNoContext
Procedure DetermineCurrentOptionDataSource(Option)
	If Not ValueIsFilled(Option) Then 
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	Reports.UniversalReport.DetermineOptionDataSource(Option);
EndProcedure

#EndRegion