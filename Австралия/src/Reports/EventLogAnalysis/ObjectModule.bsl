#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// The settings of the common report form of the "Reports options" subsystem.
//
// Parameters:
//   Form - ClientApplicationForm, Undefined - a report form or a report settings form.
//       Undefined when called without a context.
//   OptionKey - String, Undefined - a name of a predefined report option or a UUID of a 
//       user-defined report option.
//       Undefined when called without a context.
//   Settings - Structure - see the return value of
//       ReportsClientServer.GetDefaultReportSettings().
//
Procedure DefineFormSettings(Form, OptionKey, Settings) Export
	Settings.Events.OnDefineSelectionParameters = True;
	Settings.Events.OnLoadVariantAtServer = True;
	Settings.EditOptionsAllowed = False;
EndProcedure

// This procedure is called in the OnLoadVariantAtServer event handler of a report form after executing the form code.
// See "Client application form extension for reports.OnLoadVariantAtServer" in Syntax Assistant.
//
// Parameters:
//   Form - ClientApplicationForm - a report form.
//   NewDCSettings - DataCompositionSettings - settings to load into the settings composer.
//
Procedure OnLoadVariantAtServer(Form, NewDCSettings) Export
	If EventLogOperations.ServerTimeOffset() = 0 Then
		DCParameter = Form.Report.SettingsComposer.Settings.DataParameters.Items.Find("DatesInServerTimeZone");
		If TypeOf(DCParameter) = Type("DataCompositionSettingsParameterValue") Then
			DCParameter.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		EndIf;
	EndIf;
EndProcedure

// See ReportsOverridable.OnDefineChoiceParameters. 
Procedure OnDefineSelectionParameters(Form, SettingProperties) Export
	FieldName = String(SettingProperties.DCField);
	If FieldName = "DataParameters.HideScheduledJobs" Then
		ScheduledJobsArray = AllScheduledJobsList();
		SettingProperties.ValuesForSelection.Clear();
		For Each Item In ScheduledJobsArray Do
			SettingProperties.ValuesForSelection.Add(Item.UID, Item.Description);
		EndDo;
		SettingProperties.ValuesForSelection.SortByPresentation();
	EndIf;
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing, StorageAddress)
	StandardProcessing = False;
	ReportSettings = SettingsComposer.GetSettings();
	Period = ReportSettings.DataParameters.Items.Find("Period").Value;
	ReportOption = ReportSettings.DataParameters.Items.Find("ReportOption").Value;
	DatesInServerTimeZone = ReportSettings.DataParameters.Items.Find("DatesInServerTimeZone").Value;
	If DatesInServerTimeZone Then
		ServerTimeOffset = 0;
	Else
		ServerTimeOffset = EventLogOperations.ServerTimeOffset();
	EndIf;
	
	If ReportOption <> "GanttChart" Then
		DataCompositionSchema.Parameters.DayPeriod.Use = DataCompositionParameterUse.Auto;
	EndIf;
	
	If ReportOption = "EventLogMonitor" Then
		ReportGenerationResult = Reports.EventLogAnalysis.
			GenerateEventLogMonitorReport(Period.StartDate, Period.EndDate, ServerTimeOffset);
		// ReportIsBlank - shows whether the report contains data. It is required for report mailing.
		ReportIsBlank = ReportGenerationResult.ReportIsBlank;
		SettingsComposer.UserSettings.AdditionalProperties.Insert("ReportIsBlank", ReportIsBlank);
		ResultDocument.Put(ReportGenerationResult.Report);
	ElsIf ReportOption = "GanttChart" Then
		ScheduledJobsDuration(ReportSettings, ResultDocument, SettingsComposer, ServerTimeOffset);
	Else
		ReportParameters = UserActivityReportParameters(ReportSettings);
		ReportParameters.Insert("StartDate", Period.StartDate);
		ReportParameters.Insert("EndDate", Period.EndDate);
		ReportParameters.Insert("ReportOption", ReportOption);
		ReportParameters.Insert("DatesInServerTimeZone", DatesInServerTimeZone);
		If ReportOption = "UsersActivityAnalysis" Then
			DataCompositionSchema.Parameters.User.Use = DataCompositionParameterUse.Auto;
		EndIf;
		
		TemplateComposer = New DataCompositionTemplateComposer;
		CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);
		CompositionProcessor = New DataCompositionProcessor;
		ReportData = Reports.EventLogAnalysis.EventLogData(ReportParameters);
		SettingsComposer.UserSettings.AdditionalProperties.Insert("ReportIsBlank", ReportData.ReportIsBlank);
		ReportData.Delete("ReportIsBlank");
		CompositionProcessor.Initialize(CompositionTemplate, ReportData, DetailsData, True);
		OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
		OutputProcessor.SetDocument(ResultDocument);
		OutputProcessor.BeginOutput();
		While True Do
			ResultItem = CompositionProcessor.Next();
			If ResultItem = Undefined Then
				Break;
			Else
				OutputProcessor.OutputItem(ResultItem);
			EndIf;
		EndDo;
		ResultDocument.ShowRowGroupLevel(1);
		OutputProcessor.EndOutput();
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	ReportSettings = SettingsComposer.GetSettings();
	ReportOption = ReportSettings.DataParameters.Items.Find("ReportOption").Value;
	If ReportOption = "GanttChart" Then
		DayPeriod = ReportSettings.DataParameters.Items.Find("DayPeriod").Value;
		SelectionStart = ReportSettings.DataParameters.Items.Find("SelectionStart");
		SelectionEnd = ReportSettings.DataParameters.Items.Find("SelectionEnd");
		
		If Not ValueIsFilled(DayPeriod.Date) Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Не заполнено значение поля День.'; en = 'The ""Day"" field is blank.'; pl = 'Wartość pola Dzień nie jest wypełniona.';es_ES = 'Valor del campo Día no está introducido.';es_CO = 'Valor del campo Día no está introducido.';tr = 'Alan değeri Gün girilmemiş.';it = 'Il campo ""Giornata"" è vuoto.';de = 'Der Wert des Eingabefeldes Tag ist nicht ausgefüllt.'"), , );
			Cancel = True;
			Return;
		EndIf;
		
		If ValueIsFilled(SelectionStart.Value)
		AND ValueIsFilled(SelectionEnd.Value)
		AND SelectionStart.Value > SelectionEnd.Value
		AND SelectionStart.Use 
		AND SelectionEnd.Use Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Значение начала периода не может быть больше значения конца.'; en = 'The beginning of the period must be earlier than the end of the period.'; pl = 'Wartość początku okresu nie może być większa, niż wartość końca.';es_ES = 'El valor del inicio del período no puede ser posterior al valor del fin del período.';es_CO = 'El valor del inicio del período no puede ser posterior al valor del fin del período.';tr = 'Dönem başlangıç değeri, dönem sonu değerinden daha geç olamaz.';it = 'Il periodo di inizio deve essere precedente alla fine del periodo.';de = 'Der Wert des Beginns der Periode darf nicht größer sein als der Wert des Endes.'"), , );
			Cancel = True;
			Return;
		EndIf;
		
	ElsIf ReportOption = "UserActivity" Then
		
		User = ReportSettings.DataParameters.Items.Find("User").Value;
		
		If Not ValueIsFilled(User) Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Не заполнено значение поля Пользователь.'; en = 'The ""User"" field is blank.'; pl = 'Wartość pola Użytkownik nie jest wypełniona.';es_ES = 'Valor del campo Usuario no está introducido.';es_CO = 'Valor del campo Usuario no está introducido.';tr = 'Alan değeri Kullanıcı girilmedi.';it = 'Il campo ""Utente"" è vuoto.';de = 'Der Wert des Benutzerfelds ist nicht gefüllt.'"), , );
			Cancel = True;
			Return;
		EndIf;
		
		If Reports.EventLogAnalysis.IBUserName(User) = Undefined Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Формирование отчета возможно только для пользователя, которому указано имя для входа в программу.'; en = 'The report can be generated only for the user for whom a name for logon to the application is specified.'; pl = 'Sprawozdanie może zostać utworzone wyłącznie dla użytkownika dla którego określono login do wejścia do aplikacji.';es_ES = 'El informe puede generarse solo para el usuario para el cual un nombre de inicio de sesión en la aplicación está especificado.';es_CO = 'El informe puede generarse solo para el usuario para el cual un nombre de inicio de sesión en la aplicación está especificado.';tr = 'Rapor, yalnızca uygulama için oturum açma adı belirtilmiş olan kullanıcı için oluşturulabilir.';it = 'Il report può essere generato solo per l''utente per il quale viene specificato un nome per l''accesso all''applicazione.';de = 'Der Bericht kann nur für den Benutzer generiert werden, für den ein Name für die Anmeldung bei der Anwendung angegeben ist.'"), , );
			Cancel = True;
			Return;
		EndIf;
		
	ElsIf ReportOption = "UsersActivityAnalysis" Then
		
		UsersAndGroups = ReportSettings.DataParameters.Items.Find("UsersAndGroups").Value;
		
		If TypeOf(UsersAndGroups) = Type("CatalogRef.Users") Then
			
			If Reports.EventLogAnalysis.IBUserName(UsersAndGroups) = Undefined Then
				CommonClientServer.MessageToUser(
					NStr("ru = 'Формирование отчета возможно только для пользователя, которому указано имя для входа в программу.'; en = 'The report can be generated only for the user for whom a name for logon to the application is specified.'; pl = 'Sprawozdanie może zostać utworzone wyłącznie dla użytkownika dla którego określono login do wejścia do aplikacji.';es_ES = 'El informe puede generarse solo para el usuario para el cual un nombre de inicio de sesión en la aplicación está especificado.';es_CO = 'El informe puede generarse solo para el usuario para el cual un nombre de inicio de sesión en la aplicación está especificado.';tr = 'Rapor, yalnızca uygulama için oturum açma adı belirtilmiş olan kullanıcı için oluşturulabilir.';it = 'Il report può essere generato solo per l''utente per il quale viene specificato un nome per l''accesso all''applicazione.';de = 'Der Bericht kann nur für den Benutzer generiert werden, für den ein Name für die Anmeldung bei der Anwendung angegeben ist.'"), , );
				Cancel = True;
				Return;
			EndIf;
			
		EndIf;
		
		If Not ValueIsFilled(UsersAndGroups) Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Не заполнено значение поля Пользователи.'; en = 'The ""Users"" field is blank.'; pl = 'Wartość pola Użytkownicy nie jest wypełniona.';es_ES = 'Valor del campo Usuarios no está introducido.';es_CO = 'Valor del campo Usuarios no está introducido.';tr = 'Alan değeri Kullanıcılar girilmemiş.';it = 'Il campo ""Utenti"" è vuoto.';de = 'Der Wert des Feldes Benutzer ist nicht ausgefüllt.'"), , );
			Cancel = True;
			Return;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function UserActivityReportParameters(ReportSettings)
	
	UsersAndGroups = ReportSettings.DataParameters.Items.Find("UsersAndGroups").Value;
	User = ReportSettings.DataParameters.Items.Find("User").Value;
	OutputBusinessProcesses = ReportSettings.DataParameters.Items.Find("OutputBusinessProcesses");
	OutputTasks = ReportSettings.DataParameters.Items.Find("OutputTasks");
	OutputCatalogs = ReportSettings.DataParameters.Items.Find("OutputCatalogs");
	OutputDocuments = ReportSettings.DataParameters.Items.Find("OutputDocuments");
	
	If Not OutputBusinessProcesses.Use Then
		ReportSettings.DataParameters.SetParameterValue("OutputBusinessProcesses", False);
	EndIf;
	If Not OutputTasks.Use Then
		ReportSettings.DataParameters.SetParameterValue("OutputTasks", False);
	EndIf;
	If Not OutputCatalogs.Use Then
		ReportSettings.DataParameters.SetParameterValue("OutputCatalogs", False);
	EndIf;
	If Not OutputDocuments.Use Then
		ReportSettings.DataParameters.SetParameterValue("OutputDocuments", False);
	EndIf;		
	
	ReportParameters = New Structure;
	ReportParameters.Insert("UsersAndGroups", UsersAndGroups);
	ReportParameters.Insert("User", User);
	ReportParameters.Insert("OutputBusinessProcesses", OutputBusinessProcesses.Value);
	ReportParameters.Insert("OutputTasks", OutputTasks.Value);
	ReportParameters.Insert("OutputCatalogs", OutputCatalogs.Value);
	ReportParameters.Insert("OutputDocuments", OutputDocuments.Value);
	
	Return ReportParameters;
EndFunction

Procedure ScheduledJobsDuration(ReportSettings, DocumentResult, SettingsComposer, ServerTimeOffset)
	OutputTitle = ReportSettings.OutputParameters.Items.Find("OutputTitle");
	OutputFilter = ReportSettings.OutputParameters.Items.Find("OutputFilter");
	ReportHeader = ReportSettings.OutputParameters.Items.Find("Title");
	DayPeriod = ReportSettings.DataParameters.Items.Find("DayPeriod").Value;
	SelectionStart = ReportSettings.DataParameters.Items.Find("SelectionStart");
	SelectionEnd = ReportSettings.DataParameters.Items.Find("SelectionEnd");
	MinScheduledJobSessionDuration = ReportSettings.DataParameters.Items.Find(
																"MinScheduledJobSessionDuration");
	DisplayBackgroundJobs = ReportSettings.DataParameters.Items.Find("DisplayBackgroundJobs");
	HideScheduledJobs = ReportSettings.DataParameters.Items.Find("HideScheduledJobs");
	ConcurrentSessionsSize = ReportSettings.DataParameters.Items.Find("ConcurrentSessionsSize");
	
	// Checking for parameter usage flag.
	If Not MinScheduledJobSessionDuration.Use Then
		ReportSettings.DataParameters.SetParameterValue("MinScheduledJobSessionDuration", 0);
	EndIf;
	If Not DisplayBackgroundJobs.Use Then
		ReportSettings.DataParameters.SetParameterValue("DisplayBackgroundJobs", False);
	EndIf;
	If Not HideScheduledJobs.Use Then
		ReportSettings.DataParameters.SetParameterValue("HideScheduledJobs", "");
	EndIf;
	If Not ConcurrentSessionsSize.Use Then
		ReportSettings.DataParameters.SetParameterValue("ConcurrentSessionsSize", 0);
	EndIf;
		
	If Not ValueIsFilled(SelectionStart.Value) Then
		DayPeriodStartDate = BegOfDay(DayPeriod);
	ElsIf Not SelectionStart.Use Then
		DayPeriodStartDate = BegOfDay(DayPeriod);
	Else
		DayPeriodStartDate = Date(Format(DayPeriod.Date, "DLF=D") + " " + Format(SelectionStart.Value, "DLF=T"));
	EndIf;
	
	If Not ValueIsFilled(SelectionEnd.Value) Then
		DayPeriodEndDate = EndOfDay(DayPeriod);
	ElsIf Not SelectionEnd.Use Then
		DayPeriodEndDate = EndOfDay(DayPeriod);
	Else
		DayPeriodEndDate = Date(Format(DayPeriod.Date, "DLF=D") + " " + Format(SelectionEnd.Value, "DLF=T"));
	EndIf;
	
	FillingParameters = New Structure;
	FillingParameters.Insert("StartDate", DayPeriodStartDate);
	FillingParameters.Insert("EndDate", DayPeriodEndDate);
	FillingParameters.Insert("ConcurrentSessionsSize", ConcurrentSessionsSize.Value);
	FillingParameters.Insert("MinScheduledJobSessionDuration", 
								  MinScheduledJobSessionDuration.Value);
	FillingParameters.Insert("DisplayBackgroundJobs", DisplayBackgroundJobs.Value);
	FillingParameters.Insert("OutputTitle", OutputTitle);
	FillingParameters.Insert("OutputFilter", OutputFilter);
	FillingParameters.Insert("ReportHeader", ReportHeader);
	FillingParameters.Insert("HideScheduledJobs", HideScheduledJobs.Value);
	FillingParameters.Insert("ServerTimeOffset", ServerTimeOffset);
	
	ReportGenerationResult =
		Reports.EventLogAnalysis.GenerateScheduledJobsDurationReport(FillingParameters);
	SettingsComposer.UserSettings.AdditionalProperties.Insert("ReportIsBlank", ReportGenerationResult.ReportIsBlank);
	DocumentResult.Put(ReportGenerationResult.Report);
EndProcedure

Function AllScheduledJobsList()
	SetPrivilegedMode(True);
	ScheduledJobsList = ScheduledJobsServer.FindJobs(New Structure);
	ScheduledJobsArray = New Array;
	For Each Item In ScheduledJobsList Do
		If Item.Description <> "" Then
			ScheduledJobsArray.Add(New Structure("UID, Description", Item.UUID, 
																			Item.Description));
		ElsIf Item.Metadata.Synonym <> "" Then
			ScheduledJobsArray.Add(New Structure("UID, Description", Item.UUID,
																			Item.Metadata.Synonym));
		EndIf;
	EndDo;
	
	Return ScheduledJobsArray;
EndFunction

#EndRegion

#EndIf