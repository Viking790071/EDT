#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillPropertyValues(
		ThisObject,
		Parameters,
		"OwnerUUID, SchemaName, Periodicity, PeriodStartDate, PeriodsQuantity, CurrentDocument, DocumentCurrency, PresentationCurrency");
		
	For Each Dimension In Parameters.Dimensions Do
		Dimensions.Add(Dimension);
	EndDo;
	
	If Not IsBlankString(Parameters.Title) Then
		AutoTitle = False;
		Title = Parameters.Title;
	EndIf;
	
	PeriodOffset = -1;
	ChangePeriod(ThisObject);
	LoadDefaultFilter(Parameters.StartFilter);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure AddToDocument(Command)
	
	ExecuteTimeConsumingOperation(False);
	
EndProcedure

&AtClient
Procedure RefillDocument(Command)
	
	ExecuteTimeConsumingOperation(True);
	
EndProcedure

&AtClient
Procedure PreviousPeriod(Command)
	
	PeriodOffset = PeriodOffset - 1;
	ChangePeriod(ThisObject);
	
EndProcedure

&AtClient
Procedure NextPeriod(Command)
	
	PeriodOffset = PeriodOffset + 1;
	ChangePeriod(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtClientAtServerNoContext
Procedure ChangePeriod(Form)
	
	Form.StartDate = BegOfDay(DriveClientServer.CalculatePeriodEndDate(
		Form.PeriodStartDate, Form.Periodicity, Form.PeriodOffset) + 86400);
		
	Form.EndDate = DriveClientServer.CalculatePeriodEndDate(
		Form.StartDate, Form.Periodicity, Form.PeriodsQuantity);
		
	Form.PeriodPresentation = StrTemplate("%1 - %2", Format(Form.StartDate, "DLF=DD"), Format(Form.EndDate, "DLF=DD"));
	
EndProcedure

&AtServer
Procedure LoadDefaultFilter(StartFilter = Undefined)
	
	Schema = Documents.SalesTarget.GetTemplate(SchemaName);
	
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(PutToTempStorage(Schema, ThisObject.UUID)));
	SettingsComposer.LoadSettings(Schema.DefaultSettings);
	SettingsComposer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
	
	If TypeOf(StartFilter) = Type("Structure") Then
		
		For Each KeyAndValue In StartFilter Do
			
			FilterItem = SettingsComposer.Settings.Filter.FilterAvailableFields.FindField(
				New DataCompositionField(KeyAndValue.Key));
			
			If FilterItem <> Undefined Then
				CommonClientServer.SetFilterItem(
					SettingsComposer.Settings.Filter,
					KeyAndValue.Key,
					KeyAndValue.Value,
					,, False);
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetSchemaParameters()
	
	SettingsComposer.Settings.DataParameters.SetParameterValue("BeginOfPeriod",			StartDate);
	SettingsComposer.Settings.DataParameters.SetParameterValue("EndOfPeriod",			EndOfDay(EndDate));
	SettingsComposer.Settings.DataParameters.SetParameterValue("Periodicity",			Periodicity);
	SettingsComposer.Settings.DataParameters.SetParameterValue("PeriodOffset",			PeriodOffset);
	SettingsComposer.Settings.DataParameters.SetParameterValue("DocumentCurrency",		DocumentCurrency);    
	SettingsComposer.Settings.DataParameters.SetParameterValue("PresentationCurrency",	PresentationCurrency);
	
	If SettingsComposer.Settings.DataParameters.AvailableParameters.FindParameter(
			New DataCompositionParameter("CurrentDocument")) <> Undefined Then
		
		SettingsComposer.Settings.DataParameters.SetParameterValue("CurrentDocument", CurrentDocument);
		
	EndIf;
	
EndProcedure

#Region TimeConsumingOperations

&AtClient
Procedure ExecuteTimeConsumingOperation(ClearBeforeFilling)
	
	ThisObject.ReadOnly = True;
	Items.Pages.CurrentPage = Items.PareWaiting;
	
	TimeConsumingOperation = ExecuteTimeConsumingOperationAtServer();
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow			= False;
	IdleParameters.OutputProgressBar		= False;
	IdleParameters.OutputMessages			= False;
	IdleParameters.UserNotification.Show	= False;
	
	CompletionNotification = New NotifyDescription(
		"TimeConsumingOperationEnd",
		ThisObject,
		New Structure("ClearBeforeFilling", ClearBeforeFilling));
		
	TimeConsumingOperationsClient.WaitForCompletion(TimeConsumingOperation, CompletionNotification, IdleParameters);
	
EndProcedure

&AtServer
Function ExecuteTimeConsumingOperationAtServer()
	
	SetSchemaParameters();
	
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("DataCompositionSettings", SettingsComposer.GetSettings());
	ProcedureParameters.Insert("SchemaName", SchemaName);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(ThisObject.OwnerUUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Getting data for sales target filling'; ru = 'Получение данных для заполнения плана продаж';pl = 'Pobieranie danych do wypełnienia planu sprzedaży';es_ES = 'Obtener datos para rellenar el objetivo de ventas';es_CO = 'Obtener datos para rellenar el objetivo de ventas';tr = 'Satış hedefini doldurmak için veri alınıyor';it = 'Acquisendo dati per la compilazione target di vendita';de = 'Datenbeschaffung für die Befüllung von Verkaufszielen'");
	ExecutionParameters.WaitForCompletion = 0;
	
	Return TimeConsumingOperations.ExecuteInBackground(
		"Documents.SalesTarget.GetFillingData",
		ProcedureParameters,
		ExecutionParameters);
	
EndFunction

&AtClient
Procedure TimeConsumingOperationEnd(Result, AdditionalParameters) Export
	
	ThisObject.ReadOnly = False;
	Items.Pages.CurrentPage = Items.PageFilters;
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		
		CommonClientServer.MessageToUser(
			StrTemplate(NStr("en = 'Can''t get filling data:'; ru = 'Невозможно получить данные для заполнения:';pl = 'Nie można pobrać danych wypełniania:';es_ES = 'No se pueden obtener datos de relleno:';es_CO = 'No se pueden obtener datos de relleno:';tr = 'Doldurma verileri alınamıyor:';it = 'Impossibile ricevere i dati di compilazione:';de = 'Erhalte keine Fülldaten:'"), Result.DetailedErrorPresentation));
		Return;
		
	EndIf;
	
	CloseParameter = New Structure;
	CloseParameter.Insert("ClearBeforeFilling", AdditionalParameters.ClearBeforeFilling);
	CloseParameter.Insert("ResultAddress", Result.ResultAddress);
	
	Close(CloseParameter);
	
EndProcedure

#EndRegion

#EndRegion