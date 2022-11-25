#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region SoftwareLicenseCheckForCallsFromOtherSubsystems

// StandardSubsystems.BatchObjectsModification

// Returns the object attributes that are not recommended to be edited using batch attribute 
// modification data processor.
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToSkipInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("GUIDScheduledJob");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchObjectModification

#EndRegion

#EndRegion

#Region Private

Procedure CreateScenario(InfobaseNode, Schedule = Undefined) Export
	
	Cancel = False;
	
	Description = NStr("ru = 'Автоматическая синхронизация данных с %1'; en = 'Automatic synchronization with %1'; pl = 'Automatyczna synchronizacja danych z %1';es_ES = 'Sincronización de datos automática con %1';es_CO = 'Sincronización de datos automática con %1';tr = '%1 ile otomatik veri senkronizasyonu';it = 'Sincronizzazione automatica con %1';de = 'Automatische Datensynchronisation mit %1'");
	Description = StringFunctionsClientServer.SubstituteParametersToString(Description,
			Common.ObjectAttributeValue(InfobaseNode, "Description"));
	
	ExchangeTransportKind = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(InfobaseNode);
	
	DataExchangeScenario = CreateItem();
	
	// Filling in header attributes
	DataExchangeScenario.Description = Description;
	DataExchangeScenario.UseScheduledJob = True;
	
	// Creating a scheduled job.
	UpdateScheduledJobData(Cancel, Schedule, DataExchangeScenario);
	
	// Tabular section
	TableRow = DataExchangeScenario.ExchangeSettings.Add();
	TableRow.ExchangeTransportKind = ExchangeTransportKind;
	TableRow.CurrentAction = Enums.ActionsOnExchange.DataImport;
	TableRow.InfobaseNode = InfobaseNode;
	
	TableRow = DataExchangeScenario.ExchangeSettings.Add();
	TableRow.ExchangeTransportKind = ExchangeTransportKind;
	TableRow.CurrentAction = Enums.ActionsOnExchange.DataExport;
	TableRow.InfobaseNode = InfobaseNode;
	
	DataExchangeScenario.Write();
	
EndProcedure

Function DefaultJobSchedule() Export
	
	Months = New Array;
	Months.Add(1);
	Months.Add(2);
	Months.Add(3);
	Months.Add(4);
	Months.Add(5);
	Months.Add(6);
	Months.Add(7);
	Months.Add(8);
	Months.Add(9);
	Months.Add(10);
	Months.Add(11);
	Months.Add(12);
	
	WeekDays = New Array;
	WeekDays.Add(1);
	WeekDays.Add(2);
	WeekDays.Add(3);
	WeekDays.Add(4);
	WeekDays.Add(5);
	WeekDays.Add(6);
	WeekDays.Add(7);
	
	Schedule = New JobSchedule;
	Schedule.WeekDays                = WeekDays;
	Schedule.RepeatPeriodInDay = 900; // 15 minutes
	Schedule.DaysRepeatPeriod        = 1; // every day
	Schedule.Months                   = Months;
	
	Return Schedule;
EndFunction

// Gets a scheduled job schedule.
// If a scheduled job is not specified, the function returns an empty schedule (by default).
//
Function GetDataExchangeExecutionSchedule(ExchangeExecutionSettings) Export
	
	ScheduledJobObject = DataExchangeServerCall.FindScheduledJobByParameter(ExchangeExecutionSettings.GUIDScheduledJob);
	
	If ScheduledJobObject <> Undefined Then
		
		JobSchedule = ScheduledJobObject.Schedule;
		
	Else
		
		JobSchedule = New JobSchedule;
		
	EndIf;
	
	Return JobSchedule;
	
EndFunction

Procedure UpdateScheduledJobData(Cancel, JobSchedule, CurrentObject) Export
	
	// Getting a scheduled job by ID. If the scheduled job is not found, a new one is created.
	ScheduledJobObject = CreateScheduledJobIfNecessary(Cancel, CurrentObject);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Updating scheduled job properties
	SetScheduledJobParameters(ScheduledJobObject, JobSchedule, CurrentObject);
	
	// Writing a modified job.
	WriteScheduledJob(Cancel, ScheduledJobObject);
	
	// Writing GUID of the scheduled job in the object attribute.
	CurrentObject.GUIDScheduledJob = String(ScheduledJobObject.UUID);
	
EndProcedure

Function CreateScheduledJobIfNecessary(Cancel, CurrentObject)
	
	ScheduledJobObject = DataExchangeServerCall.FindScheduledJobByParameter(CurrentObject.GUIDScheduledJob);
	
	// Creating a scheduled job if necessary.
	If ScheduledJobObject = Undefined Then
		JobParameters = New Structure("Metadata", Metadata.ScheduledJobs.DataSynchronization);
		ScheduledJobObject = ScheduledJobsServer.AddJob(JobParameters);
	EndIf;
	
	Return ScheduledJobObject;
	
EndFunction

Procedure SetScheduledJobParameters(ScheduledJobObject, JobSchedule, CurrentObject)
	
	If IsBlankString(CurrentObject.Code) Then
		
		CurrentObject.SetNewCode();
		
	EndIf;
	
	ScheduledJobParameters = New Array;
	ScheduledJobParameters.Add(CurrentObject.Code);
	
	ScheduledJobDescription = NStr("ru = 'Выполнение обмена по сценарию: %1'; en = 'Exchange with the following scenario: %1'; pl = 'Wykonanie wymiany zgodnie ze scenariuszem: %1';es_ES = 'Intercambio utilizando el escenario: %1';es_CO = 'Intercambio utilizando el escenario: %1';tr = 'Senaryo kullanarak bozdurma: %1';it = 'Scambio con il seguente scenario: %1';de = 'Der Austausch des Szenarios mit: %1'");
	ScheduledJobDescription = StringFunctionsClientServer.SubstituteParametersToString(ScheduledJobDescription, TrimAll(CurrentObject.Description));
	
	ScheduledJobObject.Description  = Left(ScheduledJobDescription, 120);
	ScheduledJobObject.Use = CurrentObject.UseScheduledJob;
	ScheduledJobObject.Parameters     = ScheduledJobParameters;
	
	// Updating the schedule if it is modified.
	If JobSchedule <> Undefined Then
		ScheduledJobObject.Schedule = JobSchedule;
	EndIf;
	
EndProcedure

// Writes a scheduled job.
//
// Parameters:
//  Cancel                     - Boolean - a cancellation flag. It is set to True if errors occur 
//                                       upon the procedure execution.
//  ScheduledJobObject - a scheduled job object to record.
// 
Procedure WriteScheduledJob(Cancel, ScheduledJobObject)
	
	SetPrivilegedMode(True);
	
	Try
		
		// Writing a scheduled job
		ScheduledJobObject.Write();
		
	Except
		
		MessageString = NStr("ru = 'Произошла ошибка при сохранении расписания выполнения обменов. Подробное описание ошибки: %1'; en = 'An error occurred when saving the exchange schedule. Error description: %1'; pl = 'Wystąpił błąd podczas zapisywania harmonogramu wymiany. Opis błędu: %1';es_ES = 'Ha ocurrido un error al guardar el horario de intercambio. Descripción de error: %1';es_CO = 'Ha ocurrido un error al guardar el horario de intercambio. Descripción de error: %1';tr = 'Bozdurma takvimini kaydederken bir hata oluştu. Hata açıklaması: %1';it = 'Si è verificato un errore durante il salvataggio del programma di scambio. Descrizione di errore: %1';de = 'Beim Speichern des Austauschplans ist ein Fehler aufgetreten. Fehlerbeschreibung: %1'");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, BriefErrorDescription(ErrorInfo()));
		DataExchangeServer.ReportError(MessageString, Cancel);
		
	EndTry;
	
EndProcedure

//

// Deletes a node from all data exchange scenarios.
// If the node deletion leaves some scenarios empty, the scenario is deleted.
//
Procedure ClearRefsToInfobaseNode(Val InfobaseNode) Export
	
	If Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	QueryText = "
	|SELECT DISTINCT
	|	DataExchangeScenarioExchangeSettings.Ref AS DataExchangeScenario
	|FROM
	|	Catalog.DataExchangeScenarios.ExchangeSettings AS DataExchangeScenarioExchangeSettings
	|WHERE
	|	DataExchangeScenarioExchangeSettings.InfobaseNode = &InfobaseNode
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DataExchangeScenario = Selection.DataExchangeScenario.GetObject();
		
		DeleteExportToDataExchangeScenarios(DataExchangeScenario, InfobaseNode);
		DeleteImportToDataExchangeScenarios(DataExchangeScenario, InfobaseNode);
		
		DataExchangeScenario.Write();
		
		If DataExchangeScenario.ExchangeSettings.Count() = 0 Then
			DataExchangeScenario.Delete();
		EndIf;
		
	EndDo;
	
EndProcedure

//

Procedure DeleteExportToDataExchangeScenarios(DataExchangeScenario, InfobaseNode) Export
	
	DeleteRowInDataExchangeScenario(DataExchangeScenario, InfobaseNode, Enums.ActionsOnExchange.DataExport);
	
EndProcedure

Procedure DeleteImportToDataExchangeScenarios(DataExchangeScenario, InfobaseNode) Export
	
	DeleteRowInDataExchangeScenario(DataExchangeScenario, InfobaseNode, Enums.ActionsOnExchange.DataImport);
	
EndProcedure

Procedure AddExportToDataExchangeScenarios(DataExchangeScenario, InfobaseNode) Export
	
	WriteObjectRequired = False;
	
	If TypeOf(DataExchangeScenario) = Type("CatalogRef.DataExchangeScenarios") Then
		
		DataExchangeScenario = DataExchangeScenario.GetObject();
		
		WriteObjectRequired = True;
		
	EndIf;
	
	ExchangeTransportKind = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(InfobaseNode);
	
	ExchangeSettings = DataExchangeScenario.ExchangeSettings;
	
	// Adding data export in a loop.
	MaxIndex = ExchangeSettings.Count() - 1;
	
	For Index = 0 To MaxIndex Do
		
		ReverseIndex = MaxIndex - Index;
		
		TableRow = ExchangeSettings[ReverseIndex];
		
		// The last export row
		If TableRow.CurrentAction = Enums.ActionsOnExchange.DataExport Then
			
			NewRow = ExchangeSettings.Insert(ReverseIndex + 1);
			
			NewRow.InfobaseNode = InfobaseNode;
			NewRow.ExchangeTransportKind    = ExchangeTransportKind;
			NewRow.CurrentAction    = Enums.ActionsOnExchange.DataExport;
			
			Break;
		EndIf;
		
	EndDo;
	
	// If the row is not added in the loop, add the row to the end of the table.
	Filter = New Structure("InfobaseNode, CurrentAction", InfobaseNode, Enums.ActionsOnExchange.DataExport);
	If ExchangeSettings.FindRows(Filter).Count() = 0 Then
		
		NewRow = ExchangeSettings.Add();
		
		NewRow.InfobaseNode = InfobaseNode;
		NewRow.ExchangeTransportKind    = ExchangeTransportKind;
		NewRow.CurrentAction    = Enums.ActionsOnExchange.DataExport;
		
	EndIf;
	
	If WriteObjectRequired Then
		
		// Writing object changes.
		DataExchangeScenario.Write();
		
	EndIf;
	
EndProcedure

Procedure AddImportToDataExchangeScenarios(DataExchangeScenario, InfobaseNode) Export
	
	WriteObjectRequired = False;
	
	If TypeOf(DataExchangeScenario) = Type("CatalogRef.DataExchangeScenarios") Then
		
		DataExchangeScenario = DataExchangeScenario.GetObject();
		
		WriteObjectRequired = True;
		
	EndIf;
	
	ExchangeTransportKind = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(InfobaseNode);
	
	ExchangeSettings = DataExchangeScenario.ExchangeSettings;
	
	// Adding data import in a loop.
	For each TableRow In ExchangeSettings Do
		
		If TableRow.CurrentAction = Enums.ActionsOnExchange.DataImport Then // The first import row
			
			NewRow = ExchangeSettings.Insert(ExchangeSettings.IndexOf(TableRow));
			
			NewRow.InfobaseNode = InfobaseNode;
			NewRow.ExchangeTransportKind    = ExchangeTransportKind;
			NewRow.CurrentAction    = Enums.ActionsOnExchange.DataImport;
			
			Break;
		EndIf;
		
	EndDo;
	
	// If the row is not added in the loop, insert the row to the beginning of the table.
	Filter = New Structure("InfobaseNode, CurrentAction", InfobaseNode, Enums.ActionsOnExchange.DataImport);
	If ExchangeSettings.FindRows(Filter).Count() = 0 Then
		
		NewRow = ExchangeSettings.Insert(0);
		
		NewRow.InfobaseNode = InfobaseNode;
		NewRow.ExchangeTransportKind    = ExchangeTransportKind;
		NewRow.CurrentAction    = Enums.ActionsOnExchange.DataImport;
		
	EndIf;
	
	If WriteObjectRequired Then
		
		// Writing object changes.
		DataExchangeScenario.Write();
		
	EndIf;
	
EndProcedure

Procedure DeleteRowInDataExchangeScenario(DataExchangeScenario, InfobaseNode, ActionOnExchange)
	
	WriteObjectRequired = False;
	
	If TypeOf(DataExchangeScenario) = Type("CatalogRef.DataExchangeScenarios") Then
		
		DataExchangeScenario = DataExchangeScenario.GetObject();
		
		WriteObjectRequired = True;
		
	EndIf;
	
	ExchangeSettings = DataExchangeScenario.ExchangeSettings;
	
	MaxIndex = ExchangeSettings.Count() - 1;
	
	For Index = 0 To MaxIndex Do
		
		ReverseIndex = MaxIndex - Index;
		
		TableRow = ExchangeSettings[ReverseIndex];
		
		If  TableRow.InfobaseNode = InfobaseNode
			AND TableRow.CurrentAction = ActionOnExchange Then
			
			ExchangeSettings.Delete(ReverseIndex);
			
		EndIf;
		
	EndDo;
	
	If WriteObjectRequired Then
		
		// Writing object changes.
		DataExchangeScenario.Write();
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
