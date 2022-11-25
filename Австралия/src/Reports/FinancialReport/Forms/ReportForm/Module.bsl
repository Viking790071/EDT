#Region Variables

&AtClient
Var IdleHandlerParameters;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Parameters.Property("GenerateReport") Then
		Cancel = True;
		Raise NStr("en = 'Manual usage of this report is not provided.'; ru = 'Использование данного отчета в ручном режиме не предполагается.';pl = 'Ręczne używanie tego raportu nie jest przewidziane.';es_ES = 'No se facilita la utilización manual de este informe.';es_CO = 'No se facilita la utilización manual de este informe.';tr = 'Bu raporun manuel kullanımı mümkün değildir.';it = 'L''utilizzo manuale di questo report non è fornito.';de = 'Eine manuelle Verwendung dieses Berichts ist nicht vorgesehen.'");
		Return;
	EndIf;
	
	Items.GroupFilterByBusinessUnits.Visible = Catalogs.BusinessUnits.AccountingByBusinessUnits();
	Items.GroupFilterByLinesOfBusiness.Visible = Catalogs.LinesOfBusiness.AccountingByLinesOfBusiness();
	
	Resource = "Amount";
	If Parameters.Property("Filter") Then
		
		FillPropertyValues(Report, Parameters.Filter);
		FillReportCurrency();
		
	EndIf;
	
	If Parameters.Property("StorageAddress") Then
		
		StorageAddress = Parameters.StorageAddress;
		LoadPreparedData();
		
	EndIf;
	
	If Parameters.GenerateReport Then
		
		GenerateReport = Parameters.GenerateReport;
		
	EndIf;
	
	If Parameters.Property("DetailsParameters") Then
		DetailsParameters = Parameters.DetailsParameters;
		FillPropertyValues(Report, DetailsParameters);
		FillPropertyValues(Report, DetailsParameters.Filter);
		If DetailsParameters.Filter.Property("Company") And ValueIsFilled(DetailsParameters.Filter.Company) Then
			UseFilterByCompanies = True;
			Companies.LoadValues(DetailsParameters.Filter.Company);
		EndIf;
		If DetailsParameters.Filter.Property("BusinessUnit") And ValueIsFilled(DetailsParameters.Filter.BusinessUnit) Then
			UseFilterByBusinessUnits = True;
			BusinessUnits.LoadValues(DetailsParameters.Filter.BusinessUnit);
		EndIf;
		If DetailsParameters.Filter.Property("LineOfBusiness") And ValueIsFilled(DetailsParameters.Filter.LineOfBusiness) Then
			UseFilterByLinesOfBusiness = True;
			LinesOfBusiness.LoadValues(DetailsParameters.Filter.LineOfBusiness);
		EndIf;
		Report.BeginOfPeriod = DetailsParameters.ReportPeriod.StartDate;
		Report.EndOfPeriod = DetailsParameters.ReportPeriod.EndDate;
		Resource = DetailsParameters.Resource;
		IndicatorData = PutToTempStorage(DetailsParameters.Indicator, UUID);
		UserDefinedCalculatedIndicator = DetailsParameters.Indicator.Ref;
		Title = NStr("en = 'Indicator details:'; ru = 'Реквизиты индикатора:';pl = 'Szczegóły wskaźnika:';es_ES = 'Detalles del indicador:';es_CO = 'Detalles del indicador:';tr = 'Gösterge detayları:';it = 'Dettagli indicatore:';de = 'Angaben zum Indikator:'")+ " " + UserDefinedCalculatedIndicator.DescriptionForPrinting;
		Items.GroupAdditionalCommandPanel.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not ValueIsFilled(UserDefinedCalculatedIndicator) Then
		RefreshTitleText(ThisObject);
	EndIf;
	
	FileInfobase = StandardSubsystemsClient.ClientRunParameters().FileInfobase;
	AttachIdleHandler = Not FileInfobase And ValueIsFilled(JobID);
	If AttachIdleHandler Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
		CommonClientServer.SetSpreadsheetDocumentFieldState(Items.Result, "ReportGeneration");
	EndIf;
	
	If ValueIsFilled(UserDefinedCalculatedIndicator) Then
		SetSettingsPanelVisibility(False);
	EndIf;
	
	If GenerateReport Then
		CommonClientServer.SetSpreadsheetDocumentFieldState(Items.Result, "ReportGeneration");
		AttachIdleHandler("GenerateImmediately", 0.1, True);
	EndIf;
	
	If ValueIsFilled(StorageAddress) Then
		CommonClientServer.SetSpreadsheetDocumentFieldState(Items.Result, "DontUse");
	EndIf;
	Items.SettingsPanel.Check = Items.GroupSettingsPanel.Visible;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	VariantModified = False;
	UserSettingsModified = True;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	If JobID <> Undefined Then
		CancelJobExecution();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnSaveUserSettingsAtServer(Settings)
	
	ReportData = New Structure;
	ReportData.Insert("ReportType", Report.ReportType);
	ReportData.Insert("BeginOfPeriod", Report.BeginOfPeriod);
	ReportData.Insert("EndOfPeriod", Report.EndOfPeriod);
	ReportData.Insert("AmountsInThousands", Report.AmountsInThousands);
	ReportData.Insert("HideSettingsUponReportGeneration", HideSettingsUponReportGeneration);
	ReportData.Insert("Companies", Companies.UnloadValues());
	ReportData.Insert("BusinessUnits", BusinessUnits.UnloadValues());
	
	Settings.AdditionalProperties.Insert("ReportData", ReportData);
	
EndProcedure

&AtServer
Procedure OnLoadUserSettingsAtServer(Settings)
	
	ReportType = Report.ReportType;
	ReportsSet = Report.ReportsSet;
	
	If Not Parameters.Property("DetailsParameters") Then
		If Settings <> Undefined And Settings.AdditionalProperties.Property("ReportData") Then
			ReportData = Settings.AdditionalProperties.ReportData;
			If TypeOf(ReportData) = Type("Structure") Then
				FillPropertyValues(ThisObject, ReportData);
				FillPropertyValues(Report, ReportData);
				Companies.ValueType = New TypeDescription("CatalogRef.Companies");
				Companies.LoadValues(ReportData.Companies);
				BusinessUnits.ValueType = New TypeDescription("CatalogRef.BusinessUnits");
				BusinessUnits.LoadValues(ReportData.BusinessUnits);
				UseFilterByCompanies = Companies.Count();
				UseFilterByBusinessUnits = BusinessUnits.Count();
			EndIf;
		EndIf;
	EndIf;
	Items.SettingsPanel.Title = NStr("en = 'Quick settings'; ru = 'Быстрые настройки';pl = 'Szybkie ustawienia';es_ES = 'Ajustes rápidos';es_CO = 'Ajustes rápidos';tr = 'Hızlı ayarlar';it = 'Impostazioni rapide';de = 'Schnelleinstellungen'");
	
	If ValueIsFilled(ReportType) Then
		Report.ReportType = ReportType;
	EndIf;
	
	If ValueIsFilled(ReportsSet) Then
		Report.ReportsSet = ReportsSet;
	EndIf;
	
	If Not Parameters.Property("DetailsParameters") Then
		RefreshTitleText(ThisObject);
	EndIf;
	
	SetCurrentYearToEmptyPeriod();
	
	If Not ValueIsFilled(JobID) Then
		CommonClientServer.SetSpreadsheetDocumentFieldState(Items.Result, "Irrelevance");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SelectPeriodEnd(SelectionResult, AdditionalParameters) Export
	
	If SelectionResult = Undefined Then
		Return;
	EndIf;
	FillPropertyValues(Report, SelectionResult, "BeginOfPeriod, EndOfPeriod");
	
	RefreshPeriodDates(); 
	If Not ValueIsFilled(JobID) Then
		CommonClientServer.SetSpreadsheetDocumentFieldState(Items.Result, "Irrelevance");
	EndIf;
	
EndProcedure

&AtClient
Procedure BeginOfPeriodOnChange(Item)
	
	RefreshPeriodDates();
	If Not ValueIsFilled(JobID) Then
		CommonClientServer.SetSpreadsheetDocumentFieldState(Items.Result, "Irrelevance");
	EndIf;
	
EndProcedure

&AtClient
Procedure EndOfPeriodOnChange(Item)
	
	RefreshPeriodDates();
	If Not ValueIsFilled(JobID) Then
		CommonClientServer.SetSpreadsheetDocumentFieldState(Items.Result, "Irrelevance");
	EndIf;
	
EndProcedure

&AtClient
Procedure ReportsSetOnChange(Item)
	
	ReportsSetOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure CompaniesChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	FilterListsPickupProcessing(Companies, SelectedValue, StandardProcessing);
	
EndProcedure

&AtClient
Procedure BusinessUnitsChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	FilterListsPickupProcessing(BusinessUnits, SelectedValue, StandardProcessing);
	
EndProcedure

&AtClient
Procedure LinesOfBusinessChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	FilterListsPickupProcessing(LinesOfBusiness, SelectedValue, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ReportParameterOnChange(Item)
	
	CommonClientServer.SetSpreadsheetDocumentFieldState(Items.Result, "Irrelevance");
	Modified = False;
	
EndProcedure

&AtClient
Procedure ResultDetailProcessing(Item, Details, StandardProcessing)
	
	StandardProcessing = False;
	FinancialReportingClient.ReportDetailProcessing(ThisObject, Item, Details);
	
EndProcedure

&AtClient
Procedure ResultAdditionalDetailProcessing(Item, Details, StandardProcessing)
	
	// No mouse right-click processing
	// Showing standard spreadsheet document cell context menu instead
	Details = Undefined;
	
EndProcedure

&AtClient
Procedure ResultOnActivate(Item)
	
	If TypeOf(Result.SelectedAreas) = Type("SpreadsheetDocumentSelectedAreas") Then
		Interval = ?(GetClientConnectionSpeed() = ClientConnectionSpeed.Low, 1, 0.2);
		AttachIdleHandler("Attachable_ResultOnActivateAreaHandler", Interval, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure GenerateReport(Command)
	
	GenerateImmediately();
	
EndProcedure

&AtClient
Procedure SettingsPanel(Command)
	
	SetSettingsPanelVisibility(Not Items.GroupSettingsPanel.Visible);
	
EndProcedure

&AtClient
Procedure SendByEmail(Command)
	
	ReportTypeDescription = String(Report.ReportType);
	StatePresentation = Items.Result.StatePresentation;
	If StatePresentation.Visible = True
		And StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance Then
		
		QueryText = NStr("en = 'The report is not generated. Generate?'; ru = 'Отчет не сформирован. Сформировать его?';pl = 'Nie utworzono raportu. Utworzyć?';es_ES = 'Informe no generado. ¿Generar?';es_CO = 'Informe no generado. ¿Generar?';tr = 'Rapor oluşturulmadı. Oluşturulsun mu?';it = 'Il report non è stato generato. Generarlo?';de = 'Der Bericht ist nicht generiert. Generieren?'");
		
		NotifyDescription = New NotifyDescription("SendByEmailEnd", ThisObject, New Structure("ReportTypeDescription", ReportTypeDescription));
		ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNo, 60, DialogReturnCode.Yes);
		Return;
		
	EndIf;
	
	SendByEmailFragment(ReportTypeDescription);
	
EndProcedure

&AtClient
Procedure SelectPeriod(Command)
	
	EditedPeriod = New StandardPeriod;
	EditedPeriod.StartDate = Report.BeginOfPeriod;
	EditedPeriod.EndDate = Report.EndOfPeriod;
	
	EditPeriodDialog = New StandardPeriodEditDialog;
	EditPeriodDialog.Period = EditedPeriod;
	EditPeriodHandler = New NotifyDescription("SelectPeriodProcessing", ThisObject);
	EditPeriodDialog.Show(EditPeriodHandler);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure GenerateImmediately()
	
	ClearMessages();
	
	ExecutionResult = GenerateReportAtServer();
	If Not ExecutionResult.JobCompleted Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
		CommonClientServer.SetSpreadsheetDocumentFieldState(Items.Result, "ReportGeneration");
	EndIf;
	
EndProcedure

&AtClient
Procedure SetSettingsPanelVisibility(Show)
	
	Items.GroupSettingsPanel.Visible = Show;
	Items.SettingsPanel.Check = Items.GroupSettingsPanel.Visible;
	
EndProcedure

&AtServer
Function PrepareReportParameters()
	
	ReportFilter = New Structure;
	If UseFilterByCompanies Then
		ReportFilter.Insert("Company", Companies.UnloadValues());
	EndIf;
	If UseFilterByBusinessUnits Then
		ReportFilter.Insert("BusinessUnit", BusinessUnits.UnloadValues());
	EndIf;
	If UseFilterByLinesOfBusiness Then
		ReportFilter.Insert("LineOfBusiness", LinesOfBusiness.UnloadValues());
	EndIf;
	
	Attributes = Common.ObjectAttributesValues(Report.ReportType, "OutputRowCode, OutputNote");
	ReportParameters = New Structure;
	ReportParameters.Insert("OutputRowCode",			Attributes.OutputRowCode);
	ReportParameters.Insert("OutputNote",				Attributes.OutputNote);
	ReportParameters.Insert("ReportPeriod",				FinancialReportingServer.ReportPeriod(Report.BeginOfPeriod, EndOfDay(Report.EndOfPeriod)));
	ReportParameters.Insert("Filter",					ReportFilter);
	ReportParameters.Insert("ReportsSet",				Report.ReportsSet);
	ReportParameters.Insert("ReportType",				Report.ReportType);
	ReportParameters.Insert("Resource",					Resource);
	ReportParameters.Insert("DetailsData",				PutToTempStorage(Undefined, UUID));
	ReportParameters.Insert("ReportFormID",				UUID);
	ReportParameters.Insert("AmountsInThousands",		Report.AmountsInThousands);
	If Not UserDefinedCalculatedIndicator.IsEmpty() Then
		Indicator = GetFromTempStorage(IndicatorData);
		ReportParameters.Insert("IndicatorData",		Indicator);
		ReportParameters.Insert("IndicatorDataAddress",	IndicatorData);
	EndIf;
	ReportParameters.Insert("ReportGenerationDate", CurrentSessionDate());
	
	Return ReportParameters;
	
EndFunction

&AtClient
Procedure RefreshPeriodDates()
	
	If ValueIsFilled(Report.BeginOfPeriod) Then
		Report.BeginOfPeriod = BegOfMonth(Report.BeginOfPeriod);
	EndIf;
	
	If ValueIsFilled(Report.EndOfPeriod) Then
		Report.EndOfPeriod = EndOfMonth(Report.EndOfPeriod);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshTitleText(Form)
	
	Report = Form.Report;
	ReportTitle = NStr("en = 'Financial report'; ru = 'Финансовый отчет';pl = 'Raport finansowy';es_ES = 'Informe financiero';es_CO = 'Informe financiero';tr = 'Mali rapor';it = 'Report finanziario';de = 'Finanzbericht'");
	If ValueIsFilled(Report.ReportType) Then
		ReportTitle = String(Report.ReportType);
	EndIf;
	
	Form.Title = ReportTitle;
	
EndProcedure

&AtServer
Procedure SetCurrentYearToEmptyPeriod()
	
	If Not ValueIsFilled(Report.BeginOfPeriod) Then
		Report.BeginOfPeriod = BegOfYear(CurrentSessionDate());
		Report.EndOfPeriod = EndOfYear(CurrentSessionDate());
	EndIf;
	
EndProcedure

&AtServer
Function GenerateReportAtServer()
	
	SetCurrentYearToEmptyPeriod();
	
	If Not CheckFilling() Then
		Return New Structure("JobCompleted", True);
	EndIf;
	
	FileInfobase = Common.FileInfobase();
	
	TimeConsumingOperations.CancelJobExecution(JobID);
	
	JobID = Undefined;
	
	CommonClientServer.SetSpreadsheetDocumentFieldState(Items.Result, "DontUse");
	
	Report.SettingsComposer.Settings.AdditionalProperties.Insert("OutputTitle", OutputTitle);
	Report.SettingsComposer.Settings.AdditionalProperties.Insert("OutputFooter", OutputFooter);
	
	ReportParameters = PrepareReportParameters();
	If FileInfobase Then
		StorageAddress = PutToTempStorage(Undefined, UUID);
		FinancialReportingServer.GenerateReport(ReportParameters, StorageAddress);
		ExecutionResult = New Structure("JobCompleted", True);
	Else
		ProcedureName = "FinancialReportingServer.GenerateReport";
		ExecutionResult = TimeConsumingOperations.StartBackgroundExecution(
			UUID,
			ProcedureName,
			ReportParameters,
			DriveReports.ReportGenerationJobName(ThisObject));
		
		StorageAddress = ExecutionResult.StorageAddress;
		JobID = ExecutionResult.JobID;
	EndIf;
	
	If ExecutionResult.JobCompleted Then
		LoadPreparedData(FileInfobase);
	EndIf;
	
	FinancialReportingClientServer.HideSettingsUponReportGeneration(ThisObject);
	Modified = False;
	
	Return ExecutionResult;
	
EndFunction

&AtServer
Procedure LoadPreparedData(FileInfobase = Undefined)
	
	ExecutionResult = GetFromTempStorage(StorageAddress);
	Result = ExecutionResult.Result;
	
	If FileInfobase = Undefined Then
		FileInfobase = Common.FileInfobase();
	EndIf;
	If Not FileInfobase And ExecutionResult.Property("ErrorMessages") Then
		For Each Message In ExecutionResult.ErrorMessages Do
			Message.Message();
		EndDo;
	EndIf;
	
	JobID = Undefined;
	
	CommonClientServer.SetSpreadsheetDocumentFieldState(Items.Result, "DontUse");
	If Not ValueIsFilled(Report.ReportType) Then
		FillPropertyValues(Report, ExecutionResult);
	EndIf;
	
	If Parameters.Property("UserSettings") Then
		If Parameters.UserSettings.AdditionalProperties.Property("ReportData") Then
			ReportData = Parameters.UserSettings.AdditionalProperties.ReportData;
			If TypeOf(ReportData) = Type("ValueStorage") Then
				ReportData = ReportData.Get();
				FillPropertyValues(Report, ReportData);
				Resource = ReportData.Resource;
				Companies.LoadValues(ReportData.Companies.UnloadValues());
				UseFilterByCompanies = Companies.Count() > 0;
				BusinessUnits.LoadValues(ReportData.BusinessUnits.UnloadValues());
				UseFilterByBusinessUnits = BusinessUnits.Count() > 0;
			EndIf;
		EndIf;
	EndIf;
	FillReportCurrency();
	
EndProcedure

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Try
		If JobCompleted(JobID) Then
			LoadPreparedData();
			CommonClientServer.SetSpreadsheetDocumentFieldState(Items.Result, "DontUse");
		Else
			TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler(
				"Attachable_CheckJobExecution",
				IdleHandlerParameters.CurrentInterval,
				True);
		EndIf;
	Except
		CommonClientServer.SetSpreadsheetDocumentFieldState(Items.Result, "DontUse");
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return TimeConsumingOperations.JobCompleted(JobID);
	
EndFunction

&AtServer
Procedure CancelJobExecution()
	
	TimeConsumingOperations.CancelJobExecution(JobID);
	
EndProcedure

&AtServer
Procedure FillReportCurrency()
	
	If ValueIsFilled(Report.ReportType) Then
		FinancialReportingServer.FillReportCurrency(Items.Resource);
	EndIf;
	
EndProcedure

&AtClient
Procedure SendByEmailEnd(QueryBoxResult, AdditionalParameters) Export
	
	ReportTypeDescription = AdditionalParameters.ReportTypeDescription;
	
	If QueryBoxResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	GenerateImmediately();
	
	SendByEmailFragment(ReportTypeDescription);
	
EndProcedure

&AtClient
Procedure SendByEmailFragment(Val ReportTypeDescription)
	
	Attachment = New Structure;
	Attachment.Insert("AddressInTempStorage", PutToTempStorage(ThisObject.Result, UUID));
	Attachment.Insert("Presentation", ReportTypeDescription);
	
	Attachments = CommonClientServer.ValueInArray(Attachment);
	
	If CommonClient.SubsystemExists("StandardSubsystems.EmailOperations") Then
		EmailOperationsClientModule = CommonClient.CommonModule("EmailOperationsClient");
		EmailSendOptions = EmailOperationsClientModule.EmailSendOptions();
		EmailSendOptions.Subject = ReportTypeDescription;
		EmailSendOptions.Attachments = Attachments;
		EmailOperationsClientModule.CreateNewEmailMessage(EmailSendOptions);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectPeriodProcessing(NewPeriod, AdditionalParameters) Export
	
	If NewPeriod <> Undefined Then
		
		Report.BeginOfPeriod = NewPeriod.StartDate;
		Report.EndOfPeriod = NewPeriod.EndDate;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterListsPickupProcessing(List, SelectedValue, StandardProcessing)
	
	If TypeOf(SelectedValue) = Type("Array") Then
		
		ValuesCount = SelectedValue.Count();
		
		For Counter = 1 To ValuesCount Do
			
			Index = ValuesCount - Counter;
			Value = SelectedValue[Index];
			
			If List.FindByValue(Value) <> Undefined Then
				SelectedValue.Delete(Index);
			EndIf;
			
		EndDo;
		
		If SelectedValue.Count() = 0 Then
			StandardProcessing = False;
		EndIf;
		
	ElsIf List.FindByValue(SelectedValue) <> Undefined Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ReportsSetOnChangeAtServer()
	
	ReportsList = Items.ReportType.ChoiceList;
	For Each ReportsTypesRow In Report.ReportsSet.ReportsTypes Do
		ReportsList.Add(ReportsTypesRow.FinancialReportType);
	EndDo;
	
	If ReportsList.Count() > 0 Then
		Report.ReportType = ReportsList[0].Value;
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ResultOnActivateAreaHandler()
	
	CalculationAtServerNeeded = False;
	FinancialReportingClient.CalculateSpreadsheetDocumentSelectedCellsTotalAmount(
		TotalAmount, Result, SelectedAreaCache, CalculationAtServerNeeded);
	
	If CalculationAtServerNeeded Then
		CalculateSpreadsheetDocumentSelectedCellsTotalAmountAtServer();
	EndIf;
	
	DetachIdleHandler("Attachable_ResultOnActivateAreaHandler");
	
EndProcedure

&AtServer
Procedure CalculateSpreadsheetDocumentSelectedCellsTotalAmountAtServer()
	
	TotalAmount = FinancialReportingServer.CalculateSpreadsheetDocumentSelectedCellsTotalAmount(
		Result, SelectedAreaCache);
	
EndProcedure

#EndRegion