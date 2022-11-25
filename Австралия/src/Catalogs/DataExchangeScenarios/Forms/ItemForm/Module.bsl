#Region Variables

&AtClient
Var NumberOfRowToProcess;

&AtClient
Var StringsCount;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	IsNew = (Object.Ref.IsEmpty());
	
	InfobaseNode = Undefined;
	
	If IsNew
		AND Parameters.Property("InfobaseNode", InfobaseNode)
		AND InfobaseNode <> Undefined Then
		
		Catalogs.DataExchangeScenarios.AddImportToDataExchangeScenarios(Object, InfobaseNode);
		Catalogs.DataExchangeScenarios.AddExportToDataExchangeScenarios(Object, InfobaseNode);
		
		Description = NStr("ru = 'Сценарий синхронизации для %1'; en = 'Synchronization scenario for %1'; pl = 'Scenariusz synchronizacji dla %1';es_ES = 'Escenario de la sincronización para %1';es_CO = 'Escenario de la sincronización para %1';tr = '%1 için senkronizasyon senaryosu';it = 'Scenario di sincronizzazione per %1';de = 'Synchronisation Szenario für %1'");
		Object.Description = StringFunctionsClientServer.SubstituteParametersToString(Description, String(InfobaseNode));
		
		JobSchedule = Catalogs.DataExchangeScenarios.DefaultJobSchedule();
		
		Object.UseScheduledJob = True;
	Else
		// Getting a schedule from a scheduled job. If the scheduled job is not specified, then schedule = 
		// Undefined and it will be created on the client upon editing the schedule.
		JobSchedule = Catalogs.DataExchangeScenarios.GetDataExchangeExecutionSchedule(Object.Ref);
	EndIf;
	
	If Not IsNew Then
		RefreshDataExchangeStates();
	EndIf;
	
	SSLExchangePlans = DataExchangeCached.SSLExchangePlans();
	For Each ExchangePlanName In SSLExchangePlans Do
		ExchangeNodesList.Add(Type("ExchangePlanRef." + ExchangePlanName));
	EndDo;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RefreshSchedulePresentation();
	
	SetScheduleSetupHyperlinkAvailability();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject)
	
	Catalogs.DataExchangeScenarios.UpdateScheduledJobData(Cancel, JobSchedule, CurrentObject);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_DataExchangeScenarios", WriteParameters, Object.Ref);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UseScheduledJobOnChange(Item)
	
	SetScheduleSetupHyperlinkAvailability();
	
EndProcedure

&AtClient
Procedure ScheduleContentOnActivateRow(Item)
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	FillExchangeTransportKindChoiceList(Item.ChildItems.ExchangeSettingsExchangeTransportKind.ChoiceList, Item.CurrentData.InfobaseNode);
	
EndProcedure

&AtClient
Procedure ExchangeSettingsInfobaseNodeOnChange(Item)
	
	Items.ScheduleComposition.CurrentData.ExchangeTransportKind = Undefined;
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, 
		ThisObject, "Object.Comment");
	
EndProcedure

#EndRegion

#Region ExchangeSettingsFormTableItemsEventHandlers

&AtClient
Procedure ExchangeSettingsExchangeTransportKindStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentData = Items.ScheduleComposition.CurrentData;
	
	If CurrentData <> Undefined Then
		
		FillExchangeTransportKindChoiceList(Item.ChoiceList, CurrentData.InfobaseNode);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExchangeSettingsInfobaseNodeChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If TypeOf(ValueSelected) = Type("Type") AND ExchangeNodesList.FindByValue(ValueSelected) = Undefined Then
		MessageText = NStr("ru = 'Данные выбранного типа не могут быть использованы в этой форме.
			|Выберите другой тип данных.'; 
			|en = 'Data of the selected type cannot be used in this form.
			|Select another data type.'; 
			|pl = 'Dane wybranego typu nie mogą być używane w tym formularzu.
			|Wybierz inny typ danych.';
			|es_ES = 'Datos del tipo seleccionado no pueden ser usados en este formulario.
			|Seleccione otro tipo de datos.';
			|es_CO = 'Datos del tipo seleccionado no pueden ser usados en este formulario.
			|Seleccione otro tipo de datos.';
			|tr = 'Seçilmiş veri türleri bu şekilde kullanılamaz. 
			| Başka veri türünü seçin.';
			|it = 'Dati del tipo selezionato non possono essere usati in questo modulo.
			|Seleziona un altro tipo di dati.';
			|de = 'Die Daten des ausgewählten Typs können in diesem Formular nicht verwendet werden.
			|Wählen Sie einen anderen Datentyp aus.'");
		Field = StringFunctionsClientServer.SubstituteParametersToString("ExchangeSettings[%1].InfobaseNode", Items.ScheduleComposition.CurrentData.LineNumber-1);
		CommonClientServer.MessageToUser(MessageText, , Field, "Object");
		StandardProcessing = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RunExchange(Command)
	
	IsNew = (Object.Ref.IsEmpty());
	
	If Modified OR IsNew Then
		
		Write();
		
	EndIf;
	
	NumberOfRowToProcess     = 1;
	StringsCount = Object.ExchangeSettings.Count();
	
	AttachIdleHandler("ExecuteDataExchangeAtClient", 0.1, True);
	
EndProcedure

&AtClient
Procedure ConfigureJobSchedule(Command)
	
	EditScheduledJobSchedule();
	
	RefreshSchedulePresentation();
	
EndProcedure

&AtClient
Procedure TransportSettings(Command)
	
	CurrentData = Items.ScheduleComposition.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	ElsIf Not ValueIsFilled(CurrentData.InfobaseNode) Then
		Return;
	EndIf;
	
	Filter              = New Structure("Correspondent", CurrentData.InfobaseNode);
	FillingValues = New Structure("Correspondent", CurrentData.InfobaseNode);
	
	DataExchangeClient.OpenInformationRegisterWriteFormByFilter(Filter,
		FillingValues, "DataExchangeTransportSettings", ThisObject);
	
EndProcedure

&AtClient
Procedure GoToEventLog(Command)
	
	CurrentData = Items.ScheduleComposition.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	DataExchangeClient.GoToDataEventLogModally(CurrentData.InfobaseNode,
																	ThisObject,
																	CurrentData.CurrentAction);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure EditScheduledJobSchedule()
	
	// Creating a new schedule if it is not initialized in a form on the server.
	If JobSchedule = Undefined Then
		
		JobSchedule = New JobSchedule;
		
	EndIf;
	
	Dialog = New ScheduledJobDialog(JobSchedule);
	
	// Opening a dialog box for editing the schedule.
	NotifyDescription = New NotifyDescription("JobScheduleEditCompletion", ThisObject);
	Dialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure JobScheduleEditCompletion(Schedule, AdditionalParameters) Export
	
	If Schedule <> Undefined Then
		
		JobSchedule = Schedule;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshSchedulePresentation()
	
	SchedulePresentation = String(JobSchedule);
	
	If SchedulePresentation = String(New JobSchedule) Then
		
		SchedulePresentation = NStr("ru = 'Расписание не задано'; en = 'The schedule is not set'; pl = 'Harmonogram nie jest ustawiony';es_ES = 'Horario no está establecido';es_CO = 'Horario no está establecido';tr = 'Plan ayarlanmadı';it = 'La pianificazione non è impostata';de = 'Zeitplan ist nicht festgelegt'");
		
	EndIf;
	
	Items.ConfigureJobSchedule.Title = SchedulePresentation;
	
EndProcedure

&AtClient
Procedure SetScheduleSetupHyperlinkAvailability()
	
	Items.ConfigureJobSchedule.Enabled = Object.UseScheduledJob;
	
EndProcedure

&AtClient
Procedure ExecuteDataExchangeAtClient()
	
	If NumberOfRowToProcess > StringsCount Then // exiting the recursion
		OutputState = (StringsCount > 1);
		Status(NStr("ru = 'Данные синхронизированы.'; en = 'Synchronization completed.'; pl = 'Dane są zsynchronizowane.';es_ES = 'Datos se han sincronizado.';es_CO = 'Datos se han sincronizado.';tr = 'Senkronizasyon tamamlandı.';it = 'Sincronizzazione completata.';de = 'Daten werden synchronisiert.'"), ?(OutputState, 100, Undefined));
		Return; // exiting
	EndIf;
	
	CurrentData = Object.ExchangeSettings[NumberOfRowToProcess - 1];
	
	OutputState = (StringsCount > 1);
	
	MessageString = NStr("ru = 'Выполняется %1 для %2'; en = 'Executing %1 for %2'; pl = '%1 wykonuje się dla %2';es_ES = '%1 está ejecutado para %2';es_CO = '%1 está ejecutado para %2';tr = '%2 için %1 yürütülüyor';it = 'In esecuzione %1 per %2';de = '%1 wird ausgeführt für %2'");
	MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, 
		String(CurrentData.CurrentAction),
		String(CurrentData.InfobaseNode));
	//
	Progress = Round(100 * (NumberOfRowToProcess -1) / ?(StringsCount = 0, 1, StringsCount));
	Status(MessageString, ?(OutputState, Progress, Undefined));
	
	// Starting data exchange by setting row.
	ExecuteDataExchangeBySettingRow(NumberOfRowToProcess);
	
	UserInterruptProcessing();
	
	NumberOfRowToProcess = NumberOfRowToProcess + 1;
	
	// Calling this procedure recursively.
	AttachIdleHandler("ExecuteDataExchangeAtClient", 0.1, True);
	
EndProcedure

&AtServer
Procedure RefreshDataExchangeStates()
	
	QueryText = "
	|SELECT
	|	DataExchangeScenarioExchangeSettings.InfobaseNode,
	|	DataExchangeScenarioExchangeSettings.ExchangeTransportKind,
	|	DataExchangeScenarioExchangeSettings.CurrentAction,
	|	CASE
	|	WHEN DataExchangesStates.ExchangeExecutionResult IS NULL
	|	THEN 0
	|	WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Warning_ExchangeMessageAlreadyAccepted)
	|	THEN 2
	|	WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
	|	THEN 2
	|	WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed)
	|	THEN 0
	|	ELSE 1
	|	END AS ExchangeExecutionResult
	|FROM
	|	Catalog.DataExchangeScenarios.ExchangeSettings AS DataExchangeScenarioExchangeSettings
	|LEFT JOIN InformationRegister.DataExchangesStates AS DataExchangesStates
	|	ON DataExchangesStates.InfobaseNode = DataExchangeScenarioExchangeSettings.InfobaseNode
	|	 AND DataExchangesStates.ActionOnExchange      = DataExchangeScenarioExchangeSettings.CurrentAction
	|WHERE
	|	DataExchangeScenarioExchangeSettings.Ref = &Ref
	|ORDER BY
	|	DataExchangeScenarioExchangeSettings.LineNumber ASC
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Object.Ref);
	
	Object.ExchangeSettings.Load(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure ExecuteDataExchangeBySettingRow(Val Index)
	
	Cancel = False;
	
	// Starting data exchange.
	DataExchangeServer.ExecuteDataExchangeUsingDataExchangeScenario(Cancel, Object.Ref, Index);
	
	// Updating tabular section data of the data exchange scenario.
	RefreshDataExchangeStates();
	
EndProcedure

&AtClient
Procedure FillExchangeTransportKindChoiceList(ChoiceList, InfobaseNode)
	
	ChoiceList.Clear();
	
	If ValueIsFilled(InfobaseNode) Then
		
		For Each Item In UsedExchangeMessagesTransports(InfobaseNode) Do
			
			ChoiceList.Add(Item, String(Item));
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function UsedExchangeMessagesTransports(Val InfobaseNode)
	
	Return DataExchangeCached.UsedExchangeMessagesTransports(InfobaseNode);
	
EndFunction

#EndRegion
