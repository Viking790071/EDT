#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Catalogs.CompanyResourceTypes, DataLoadSettingsWCT, ThisObject);
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Catalogs.CompanyResources, DataLoadSettingsWC, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	BusinessUnitOnChangeEnd();
	PeriodOnChangeEnd();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "WorkcentersWereChanged" And Parameter = WorkcenterType Then
		
		If AvailabilityHasNoChanges() Then
			
			WorkcenterTypeOnChangeEnd();
			
		Else
			
			RefreshWorkcentersRows();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure BusinessUnitOnChange(Item)
	
	If AvailabilityHasNoChanges() Then
		
		BusinessUnitOnChangeEnd();
		
	Else
		
		ShowQueryBoxMainAttributeChanging("BusinessUnitOnChangeContinue");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PeriodOnChange(Item)
	
	If AvailabilityHasNoChanges() Then
		
		PeriodOnChangeEnd();
		
	Else
		
		ShowQueryBoxMainAttributeChanging("PeriodOnChangeContinue");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region CompanyResourceTypesFormTableItemsEventHandlers

&AtClient
Procedure CompanyResourceTypesOnActivateRow(Item)
	
	If Items.CompanyResourceTypes.CurrentRow <> WorkcenterType Then
		
		If AvailabilityHasNoChanges() Then
			
			WorkcenterTypeOnChangeEnd();
			
		Else
			
			ShowQueryBoxMainAttributeChanging("WorkcenterTypeOnChangeContinue");
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region WorkcentersAvailabilityFormTableItemsEventHandlers

&AtClient
Procedure WorkcentersAvailabilitySelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentData = Items.WorkcentersAvailability.CurrentData;
	
	If Field.Name = "WorkcentersAvailabilityWorkcenter" Then
		
		StandardProcessing = False;
		ShowValue(, CurrentData.Workcenter);
		
	ElsIf Left(Field.Name, 1) = "_" Then
		
		If StrFind(Field.Name, "Available") <> 0 Then
			
			PeriodByColumnName = PeriodByColumnName(Field.Name);
			InputSchedule(PeriodByColumnName);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ProductionPlanningWorkplace(Command)
	OpenForm("DataProcessor.ProductionOrderQueueManagement.Form");
EndProcedure

&AtClient
Procedure FillInAvailability(Command)
	
	If Not AvailabilityHasNoChanges() Then
		
		Notify = New NotifyDescription("FillInAvailabilityContinue", ThisObject);
		QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Availability of %1 has unsaved changes. Do you want to refill table?'; ru = 'Доступность %1 содержит несохраненные изменения. Перезаполнить таблицу?';pl = 'Dostępność %1 ma niezapisane zmiany. Czy chcesz ponownie wypełnić tablicę?';es_ES = 'La disponibilidad de %1 tiene cambios sin guardar. ¿Quiere rellenar la tabla?';es_CO = 'La disponibilidad de %1 tiene cambios sin guardar. ¿Quiere rellenar la tabla?';tr = '%1 uygunluğunda kaydedilmemiş değişiklikler var. Tabloyu yeniden doldurmak istiyor musunuz?';it = 'La disponibilità di %1 presenta modifiche non salvate. Ricompilare la tabella?';de = 'Verfügbarkeit von  %1 hat nicht gespeicherte Änderungen. Möchten Sie die Tabelle erneut ausfüllen?'"),
			WorkcenterType);
		
		ShowQueryBox(Notify, QuestionText,  QuestionDialogMode.YesNo);
		
	ElsIf Not AvailabilityIsEmpty() Then
		
		Notify = New NotifyDescription("FillInAvailabilityContinue", ThisObject);
		QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Availability of %1 is not empty. Do you want to refill table?'; ru = 'Доступность %1 не пустая. Перезаполнить таблицу?';pl = 'Dostępność %1 nie jest pusta. Czy chcesz ponownie wypełnić tablicę?';es_ES = 'La disponibilidad de %1 no está vacía. ¿Quiere rellenar la tabla?';es_CO = 'La disponibilidad de %1 no está vacía. ¿Quiere rellenar la tabla?';tr = '%1 uygunluğu boş değil. Tabloyu yeniden doldurmak istiyor musunuz?';it = 'La disponibilità di %1 non è vuota. Ricompilare la tabella?';de = 'Verfügbarkeit von %1 ist nicht leer. Möchten Sie die Tabelle wieder ausfüllen?'"),
			WorkcenterType);
		
		ShowQueryBox(Notify, QuestionText, QuestionDialogMode.YesNo);
		
	Else
		
		FillInAvailabilityBySchedule();
		FormManagement();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SaveChanges(Command)
	
	HasErrors = False;
	
	MinDate = Date('39991231');
	
	If IntervalIsFilled(WorkcenterType) Then
		SaveWorkcenterSheduleAtServer(HasErrors, MinDate);
	Else
		
		HasErrors = True;
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'To save the schedule, please fill in the planning interval in business unit of %1.'; ru = 'Для сохранения графика заполните периодичность планирования структурной единицы %1.';pl = 'Aby zapisać harmonogram, wypełnij w interwale planowania w jednostkę biznesową %1.';es_ES = 'Para guardar el programa, por favor, rellene el intervalo de planificación en la unidad empresarial de %1.';es_CO = 'Para guardar el programa, por favor, rellene el intervalo de planificación en la unidad de negocio de %1.';tr = 'Takvimi kaydetmek için lütfen planlama aralığını %1 departmanında doldurun.';it = 'Per salvare il grafico, compilare l''intervallo di pianificazione nell''unità aziendale di %1.';de = 'Bitte füllen Sie den Planungsintervall in der Abteilung von %1, um den Plan zu speichern.'"),
			WorkcenterType);
		CommonClientServer.MessageToUser(ErrorText);
		
	EndIf;
	
	If Not HasErrors Then
		
		ShowUserNotification(NStr("en = 'Saved successfully.'; ru = 'Сохранение успешно завершено.';pl = 'Zapisano pomyślnie.';es_ES = 'Se ha guardado con éxito';es_CO = 'Se ha guardado con éxito';tr = 'Kayıt başarı ile tamamlandı.';it = 'Salvato con successo';de = 'Speichern erfolgreich abgeschlossen.'"));
		
		If MinDate <> Date('39991231') Then
			AddJobsForReplanning(MinDate);
		EndIf;
		
		WorkScheduleWasModified = False;
		
		FormManagement();
		
		Notify("RefreshProductionOrderQueue");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure WorkCentersAvailabilityReport(Command)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "WorkcentersAvailability");
	ReportProperties.Insert("VariantKey", "Default");
	
	ParametersAndSelections = New Array;
	ParametersAndSelections.Add(New Structure("FieldName, RightValue", "ParameterPeriod", Period));
	
	SettingsComposer = DriveServer.GetOverriddenSettingsComposer(ReportProperties, ParametersAndSelections);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey", ReportProperties.VariantKey);
	FormParameters.Insert("UserSettings", SettingsComposer.UserSettings);
	FormParameters.Insert("GenerateOnOpen", True);
	
	OpenForm("Report." + ReportProperties.ReportName + ".Form", FormParameters, ThisObject, UUID);
	
EndProcedure

&AtClient
Procedure DataImportFromExternalSourcesWCT(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor",
		ThisObject, DataLoadSettingsWCT);
	
	DataLoadSettingsWCT.Insert("TemplateNameWithTemplate",	"LoadFromFile");
	DataLoadSettingsWCT.Insert("SelectionRowDescription",
		New Structure("FullMetadataObjectName, Type", "CompanyResourceTypes", "AppliedImport"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettingsWCT,
		NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure DataImportFromExternalSourcesWC(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor",
		ThisObject, DataLoadSettingsWC);
	
	DataLoadSettingsWC.Insert("TemplateNameWithTemplate",	"LoadFromFile");
	DataLoadSettingsWC.Insert("SelectionRowDescription",
		New Structure("FullMetadataObjectName, Type", "CompanyResources", "AppliedImport"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettingsWC,
		NotifyDescription, ThisObject);
	
EndProcedure

#EndRegion

#Region Private

#Region SavingWorkcentersAvailability

&AtServer
Procedure SaveWorkcenterSheduleOnDate(Workcenter, PeriodDate, ManualCorrection, HasErrors)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	WorkcentersAvailability.Ref AS Ref
	|FROM
	|	Document.WorkcentersAvailability AS WorkcentersAvailability
	|WHERE
	|	WorkcentersAvailability.Posted
	|	AND WorkcentersAvailability.Date = &PeriodDate
	|	AND WorkcentersAvailability.WorkcenterType = &WorkcenterType
	|	AND WorkcentersAvailability.Workcenter = &Workcenter";
	
	Query.SetParameter("PeriodDate", PeriodDate);
	Query.SetParameter("Workcenter", Workcenter);
	Query.SetParameter("WorkcenterType", WorkcenterType);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		
		WorkcentersAvailabilityDoc = SelectionDetailRecords.Ref.GetObject();
		WorkcentersAvailabilityDoc.Intervals.Clear();
		
	Else
		
		WorkcentersAvailabilityDoc = Documents.WorkcentersAvailability.CreateDocument();
		WorkcentersAvailabilityDoc.Date = PeriodDate;
		WorkcentersAvailabilityDoc.WorkcenterType = WorkcenterType;
		WorkcentersAvailabilityDoc.Workcenter = Workcenter;
		
	EndIf;
	
	WorkcentersAvailabilityDoc.ManualCorrection = ManualCorrection;
	
	WorkcentersSchedule = GetFromTempStorage(WorkcentersDataAddress);
	
	// Filling Intervals table
	Filter = New Structure;
	Filter.Insert("Period", PeriodDate);
	Filter.Insert("WorkcenterType", WorkcenterType);
	Filter.Insert("Workcenter", Workcenter);
	
	TempTable = WorkcentersSchedule.Copy(Filter, "StartTime, EndTime, Capacity, ManualCorrection");
	
	WorkcentersAvailabilityDoc.Intervals.Load(TempTable);
	
	Try
		
		WorkcentersAvailabilityDoc.Write(DocumentWriteMode.Posting);
		
	Except
		
		HasErrors = True;
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'"),
			WorkcentersAvailabilityDoc.Ref,
			DetailErrorDescription(ErrorInfo()));
			
		WriteLogEvent(
			NStr("en = 'WorkCentersWorkplace'; ru = 'WorkCentersWorkplace';pl = 'WorkCentersWorkplace';es_ES = 'WorkCentersWorkplace';es_CO = 'WorkCentersWorkplace';tr = 'WorkCentersWorkplace';it = 'WorkCentersWorkplace';de = 'WorkCentersWorkplace'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			Metadata.Documents.WorkcentersAvailability,
			,
			ErrorDescription);
		
		CommonClientServer.MessageToUser(
			NStr("en = 'Documents creation is completed with errors. Technical info was written to the event log.'; ru = 'Создание документов завершилось с ошибками. Технические сведения записаны в журнал регистрации.';pl = 'Utworzenie dokumentów kończy się błędami. Techniczne informacje zostały zapisane do dziennika wydarzeń.';es_ES = 'La creación de documentos se ha completado con errores. La información técnica fue grabada en el registro de eventos.';es_CO = 'La creación de documentos se ha completado con errores. La información técnica fue grabada en el registro de eventos.';tr = 'Belge oluşturma işlemi hatalarla tamamlandı. Teknik bilgiler olay günlüğüne yazıldı.';it = 'Creazione dei documenti non riuscita. I dettagli sono salvati nel registro degli eventi.';de = 'Erstellung von Dokumenten mit Fehlern gespeichert. Technische Informationen sind im Ereignisprotokoll eingetragen.'"));
		
	EndTry;
	
EndProcedure

&AtServer
Procedure SaveWorkcenterSheduleAtServer(HasErrors, MinDate)
	
	For Each WorkcenterLine In WorkcentersAvailability Do
			
			If WorkcenterLine.DataWasChanged Then
				
				// Look for changed columns
				For Each ShownDate In ListOfShownDates Do
					
					NameOfColumn = NameOfColumnByPeriod(ShownDate.Value);
					
					If WorkcenterLine[NameOfColumn + "DataWasChanged"] Then
						
						SaveWorkcenterSheduleOnDate(WorkcenterLine.Workcenter,
							ShownDate.Value,
							WorkcenterLine[NameOfColumn + "ManualCorrection"],
							HasErrors);
						
						WorkcenterLine[NameOfColumn + "DataWasChanged"] = False;
						
						MinDate = Min(MinDate, ShownDate.Value);
						
					EndIf;
					
				EndDo;
				
				WorkcenterLine.DataWasChanged = False;
				
			EndIf;
			
	EndDo;
		
EndProcedure

#EndRegion

#Region FormAppearance

&AtClient
Procedure FormManagement()
	
	WACanBeFilled = CheckWorkcentersDataFilling(WorkcenterType, Period);
	
	If WorkcenterType.IsEmpty() Then
		Items.WorkcentersAvailabilityWorkcenterType.Visible = True;
		Items.WorkcentersAvailabilityWorkcenter.Visible = True;
	Else
		PlanningOnWorkcentersLevel = GetPlanningOnWorkcentersLevel(WorkcenterType);
		Items.WorkcentersAvailabilityWorkcenterType.Visible = Not PlanningOnWorkcentersLevel;
		Items.WorkcentersAvailabilityWorkcenter.Visible = PlanningOnWorkcentersLevel;
	EndIf;
	
	Items.WorkcentersAvailability.Enabled = WACanBeFilled;
	Items.FillInAvailability.Enabled = WACanBeFilled;
	Items.NotFilledInfo.Visible = Not WACanBeFilled;
	
	Items.SaveChanges.Enabled = WorkScheduleWasModified;
	
EndProcedure

&AtClient
Procedure SetWorkcenterTypeFilter(WorkcenterType)
	
	DriveClientServer.SetListFilterItem(CompanyResources, "WorkcenterType", WorkcenterType);
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	For Each ShownDate In ListOfShownDates Do
		
		NameOfColumn = NameOfColumnByPeriod(ShownDate.Value);
		
		NewConditionalAppearance = ConditionalAppearance.Items.Add();
		WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
			"WorkcentersAvailability." + NameOfColumn + "ManualCorrection",
			True);
			
		WorkWithForm.AddAppearanceField(NewConditionalAppearance, NameOfColumn + "Available");
		WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Font", StyleFonts.NotAcceptedForExecutionTasks);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region MainAttributesChanging

&AtClient
Function AvailabilityHasNoChanges()
	
	Result = True;
	
	For Each WorkcenterLine In WorkcentersAvailability Do
		
		If WorkcenterLine.DataWasChanged Then
			Result = False;
			Break;
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Function AvailabilityIsEmpty()
	
	Result = True;
	
	For Each WorkcenterLine In WorkcentersAvailability Do
		
		If WorkcenterLine.TotalAvailable > 0 Then
			Result = False;
			Break;
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Procedure ShowQueryBoxMainAttributeChanging(ProcedureToContinue)

	Notify = New NotifyDescription(ProcedureToContinue, ThisObject);
	QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Availability of %1 has unsaved changes. Do you want to continue without saving?'; ru = 'Доступность %1 содержит несохраненные изменения. Продолжить без сохранения?';pl = 'Dostępność %1 ma niezapisane zmiany. Czy chcesz kontynuować bez zapisywania?';es_ES = 'La disponibilidad de %1 tiene cambios sin guardar. ¿Quiere continuar sin guardar?';es_CO = 'La disponibilidad de %1 tiene cambios sin guardar. ¿Quiere continuar sin guardar?';tr = '%1 uygunluğunda kaydedilmemiş değişiklikler var. Kaydetmeden devam etmek istiyor musunuz?';it = 'La disponibilità di %1 presenta modifiche non salvate. Continuare senza salvare?';de = 'Verfügbarkeit von %1 hat nicht gespeicherte Änderungen. Möchten Sie mit dem Speichern fortsetzen?'"),
		WorkcenterType);
	
	ShowQueryBox(Notify, QuestionText,  QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure BusinessUnitOnChangeEnd()
	
	DriveClientServer.SetListFilterItem(CompanyResourceTypes, "BusinessUnit", BusinessUnit, ValueIsFilled(BusinessUnit));
	WorkcenterType = Items.CompanyResourceTypes.CurrentRow;
	SetWorkcenterTypeFilter(WorkcenterType);
	FormManagement();
	FillData();
	BusinessUnitBeforeChange = BusinessUnit;
	
EndProcedure

&AtClient
Procedure BusinessUnitOnChangeContinue(Answer, Parameters) Export
	
	If Answer = DialogReturnCode.Yes Then
		BusinessUnitOnChangeEnd();
	ElsIf Answer = DialogReturnCode.No Then
		BusinessUnit = BusinessUnitBeforeChange;
	EndIf;
	
EndProcedure

&AtClient
Procedure WorkcenterTypeOnChangeEnd()
	
	WorkcenterType = Items.CompanyResourceTypes.CurrentRow;
	SetWorkcenterTypeFilter(WorkcenterType);
	FormManagement();
	FillData();
	
EndProcedure

&AtClient
Procedure WorkcenterTypeOnChangeContinue(Answer, Parameters) Export
	
	If Answer = DialogReturnCode.Yes Then
		WorkcenterTypeOnChangeEnd();
	ElsIf Answer = DialogReturnCode.No Then
		Items.CompanyResourceTypes.CurrentRow = WorkcenterType;
	EndIf;
	
EndProcedure

&AtClient
Procedure PeriodOnChangeEnd()
	
	FormManagement();
	FillData();
	PeriodBeforeChange = Period;
	
EndProcedure

&AtClient
Procedure PeriodOnChangeContinue(Answer, Parameters) Export
	
	If Answer = DialogReturnCode.Yes Then
		
		PeriodOnChangeEnd();
		
	ElsIf Answer = DialogReturnCode.No Then
		
		Period = PeriodBeforeChange;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillInAvailabilityContinue(Answer, Parameters) Export
	
	If Answer = DialogReturnCode.Yes Then
		
		FillInAvailabilityBySchedule();
		FormManagement();
		
	EndIf;
	
EndProcedure

#EndRegion

&AtServer
Procedure AddJobsForReplanning(MinDate)
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED DISTINCT
		|	ManufacturingOperation.BasisDocument AS ProductionOrder
		|FROM
		|	AccumulationRegister.WorkcentersAvailability.Turnovers(&StartDate, &EndDate, Recorder, WorkcenterType = &WorkcenterType) AS WorkcentersAvailabilityTurnovers
		|		LEFT JOIN Document.ManufacturingOperation AS ManufacturingOperation
		|		ON WorkcentersAvailabilityTurnovers.Recorder = ManufacturingOperation.Ref
		|WHERE
		|	WorkcentersAvailabilityTurnovers.UsedTurnover > 0
		|	AND ManufacturingOperation.Status = VALUE(Enum.ManufacturingOperationStatuses.Open)";
	
	Query.SetParameter("EndDate", Period.EndDate);
	Query.SetParameter("StartDate", MinDate);
	Query.SetParameter("WorkcenterType", WorkcenterType);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		InformationRegisters.JobsForProductionScheduleCalculation.AddAllOperationsOfOrder(SelectionDetailRecords.ProductionOrder);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillData()
	
	If CheckWorkcentersDataFilling(WorkcenterType, Period) Then
		
		WorkcentersSchedule = WorkcentersScheduleTable();
		WorkcentersDataAddress = PutToTempStorage(WorkcentersSchedule, UUID);
		
		RefreshWorkcentersAvailabilityColumns();
		SetConditionalAppearance();
		FillWorkcentersAvailabilityTable();
		
	Else
		
		WorkcentersAvailability.Clear();
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function CheckWorkcentersDataFilling(WorkcenterType, Period)
	
	Result = True;
	
	If WorkcenterType.IsEmpty() Or Not ValueIsFilled(Period) Then
		
		Result = False;
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function GetPlanningOnWorkcentersLevel(WorkcenterType)
	
	Return Common.ObjectAttributeValue(WorkcenterType, "PlanningOnWorkcentersLevel");
	
EndFunction

&AtServer
Procedure FillWorkcentersAvailabilityTable()
	
	AddWorkcentersRows();
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	WorkcentersAvailability.WorkcenterType AS WorkcenterType,
	|	WorkcentersAvailability.Workcenter AS Workcenter,
	|	WorkcentersAvailability.Date AS Period,
	|	WorkcentersAvailabilityIntervals.StartTime AS StartTime,
	|	WorkcentersAvailabilityIntervals.EndTime AS EndTime,
	|	WorkcentersAvailabilityIntervals.Capacity AS Capacity,
	|	WorkcentersAvailability.ManualCorrection AS ManualCorrection,
	|	CASE
	|		WHEN WorkcentersAvailabilityIntervals.EndTime = DATETIME(1, 1, 1)
	|			THEN DATEDIFF(WorkcentersAvailabilityIntervals.StartTime, DATETIME(1, 1, 1, 23, 59, 59), SECOND) + 1
	|		ELSE DATEDIFF(WorkcentersAvailabilityIntervals.StartTime, WorkcentersAvailabilityIntervals.EndTime, SECOND)
	|	END AS AvailableSeconds
	|FROM
	|	Document.WorkcentersAvailability.Intervals AS WorkcentersAvailabilityIntervals
	|		LEFT JOIN Document.WorkcentersAvailability AS WorkcentersAvailability
	|		ON WorkcentersAvailabilityIntervals.Ref = WorkcentersAvailability.Ref
	|WHERE
	|	WorkcentersAvailability.Date BETWEEN &StartDate AND &EndDate
	|	AND WorkcentersAvailability.Posted
	|	AND WorkcentersAvailability.WorkcenterType = &WorkcenterType";
	
	Query.SetParameter("EndDate", Period.EndDate);
	Query.SetParameter("StartDate", Period.StartDate);
	Query.SetParameter("WorkcenterType", WorkcenterType);
	
	WorkcentersSchedule = Query.Execute().Unload();
	
	CopyScheduleTable = WorkcentersSchedule.Copy();
	CopyScheduleTable.GroupBy("Workcenter, Period, ManualCorrection", "AvailableSeconds");
	
	For Each WorkcenterLine In WorkcentersAvailability Do
		
		Filter = New Structure();
		Filter.Insert("Workcenter", WorkcenterLine.Workcenter);
		
		ScheduleLines = CopyScheduleTable.FindRows(Filter);
		
		For Each ScheduleLine In ScheduleLines Do
			
			NameOfColumn = NameOfColumnByPeriod(ScheduleLine.Period);
			WorkcenterLine[NameOfColumn + "ManualCorrection"] = ScheduleLine.ManualCorrection;
			WorkcenterLine[NameOfColumn + "Available"] = ScheduleLine.AvailableSeconds / 3600;
			WorkcenterLine[NameOfColumn + "AvailableSeconds"] = ScheduleLine.AvailableSeconds;
			WorkcenterLine[NameOfColumn + "AvailableIsFilled"] = ValueIsFilled(ScheduleLine.AvailableSeconds);
			
		EndDo;
		
		CalculateTotalsInLine(WorkcenterLine, ThisObject);
		
	EndDo;
	
	PutToTempStorage(WorkcentersSchedule, WorkcentersDataAddress);
	
EndProcedure

&AtServer
Procedure AddWorkcentersRows()
	
	WorkcentersAvailability.Clear();
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CompanyResourceTypes.Ref AS WorkcenterType,
	|	CompanyResources.Ref AS Workcenter,
	|	CompanyResources.Capacity AS Capacity,
	|	CompanyResources.Schedule AS Schedule
	|FROM
	|	Catalog.CompanyResourceTypes AS CompanyResourceTypes
	|		LEFT JOIN Catalog.CompanyResources AS CompanyResources
	|		ON (CompanyResources.WorkcenterType = CompanyResourceTypes.Ref)
	|			AND (NOT CompanyResources.DeletionMark)
	|WHERE
	|	CompanyResourceTypes.Ref = &WorkcenterType
	|	AND CompanyResourceTypes.PlanningOnWorkcentersLevel
	|
	|UNION ALL
	|
	|SELECT
	|	CompanyResourceTypes.Ref,
	|	VALUE(Catalog.CompanyResources.EmptyRef),
	|	CompanyResourceTypes.Capacity,
	|	CompanyResourceTypes.Schedule
	|FROM
	|	Catalog.CompanyResourceTypes AS CompanyResourceTypes
	|WHERE
	|	CompanyResourceTypes.Ref = &WorkcenterType
	|	AND NOT CompanyResourceTypes.PlanningOnWorkcentersLevel";
	
	Query.SetParameter("WorkcenterType", WorkcenterType);
	
	WorkcentersAvailability.Load(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure RefreshWorkcentersRows()
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	CompanyResources.Ref AS Workcenter,
		|	CASE
		|		WHEN CompanyResourceTypes.PlanningOnWorkcentersLevel
		|			THEN CompanyResources.Capacity
		|		ELSE CompanyResourceTypes.Capacity
		|	END AS Capacity,
		|	CASE
		|		WHEN CompanyResourceTypes.PlanningOnWorkcentersLevel
		|			THEN CompanyResources.Schedule
		|		ELSE CompanyResourceTypes.Schedule
		|	END AS Schedule
		|FROM
		|	Catalog.CompanyResources AS CompanyResources
		|		LEFT JOIN Catalog.CompanyResourceTypes AS CompanyResourceTypes
		|		ON CompanyResources.WorkcenterType = CompanyResourceTypes.Ref
		|WHERE
		|	CompanyResourceTypes.Ref = &WorkcenterType";
	
	Query.SetParameter("WorkcenterType", WorkcenterType);
	
	WorkcentersRows = Query.Execute().Unload();
	
	For Each WorkcenterLine In WorkcentersAvailability Do
		
		Filter = New Structure("Workcenter", WorkcenterLine.Workcenter);
		
		FilterRows = WorkcentersRows.FindRows(Filter);
		
		If FilterRows.Count() Then
			FillPropertyValues(WorkcenterLine, FilterRows[0], "Schedule, Capacity");
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure CalculateTotalsInLine(WorkcentersAvailabilityLine, Form)
	
	TotalAvailable = 0;
	ManualCorrection = False;
	DataWasChanged = False;
	EnteredTo = '000101010000';
	
	For Each ShownDate In Form.ListOfShownDates Do
		
		NameOfColumn = NameOfColumnByPeriod(ShownDate.Value);
		
		TotalAvailable = TotalAvailable + WorkcentersAvailabilityLine[NameOfColumn + "AvailableSeconds"];
		
		If WorkcentersAvailabilityLine[NameOfColumn + "AvailableIsFilled"] Then
			EnteredTo = Max(EnteredTo, ShownDate.Value);
		EndIf;
		
		If WorkcentersAvailabilityLine[NameOfColumn + "ManualCorrection"] Then
			ManualCorrection = True;
		EndIf;
		
		If WorkcentersAvailabilityLine[NameOfColumn + "DataWasChanged"] Then
			DataWasChanged = True;
		EndIf;
		
	EndDo;
	
	WorkcentersAvailabilityLine.TotalAvailable = TotalAvailable / 3600;
	WorkcentersAvailabilityLine.ManualCorrection = ManualCorrection;
	WorkcentersAvailabilityLine.EnteredTo = EnteredTo;
	WorkcentersAvailabilityLine.DataWasChanged = DataWasChanged;
	WorkcentersAvailabilityLine.AvailabilityPicture = (TotalAvailable > 0);
	
EndProcedure

&AtServerNoContext
Function IntervalIsFilled(WorkcenterType)
	
	Result = False;
	
	BU = Common.ObjectAttributeValue(WorkcenterType, "BusinessUnit");
	
	If ValueIsFilled(BU) Then
		
		PlanningInterval = Common.ObjectAttributeValue(BU, "PlanningInterval");
		
		If ValueIsFilled(PlanningInterval) Then
			
			Result = True;
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function CheckWorkcenters()
	
	Result = True;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	CompanyResources.Ref AS Ref
		|FROM
		|	Catalog.CompanyResources AS CompanyResources
		|WHERE
		|	CompanyResources.WorkcenterType = &WorkcenterType
		|	AND NOT CompanyResources.DeletionMark";
	
	Query.SetParameter("WorkcenterType", WorkcenterType);
	
	QueryResult = Query.Execute();
	
	If Common.ObjectAttributeValue(WorkcenterType, "PlanningOnWorkcentersLevel") And QueryResult.IsEmpty() Then
		
		CommonClientServer.MessageToUser(
			NStr("en = 'Cannot show the work centers availability. Create a work center for the selected work center type.'; ru = 'Невозможно отобразить доступность рабочих центров. Создайте рабочий центр выбранного типа рабочего центра.';pl = 'Nie można pokazać dostępności gniazd produkcyjnych. Utwórz gniazdo produkcyjne dla wybranego typu gniazda produkcyjnego.';es_ES = 'No se puede mostrar la disponibilidad de los centros de trabajo. Cree un centro de trabajo para el tipo de centro de trabajo seleccionado.';es_CO = 'No se puede mostrar la disponibilidad de los centros de trabajo. Cree un centro de trabajo para el tipo de centro de trabajo seleccionado.';tr = 'İş merkezi uygunluğu gösterilemiyor. Seçilen iş merkezi türü işin bir iş merkezi oluştur.';it = 'Impossibile mostrare la disponibilità dei centri di lavoro. Creare un centro di lavoro per il tipo di centro di lavoro selezionato.';de = 'Kann die Verfügbarkeit von Arbeitsabschnitten nicht anzeigen. Erstellen Sie einen Arbeitsabschnitt für den ausgewählten Arbeitsabschnittstyp.'"));
		Result = False;
		
	EndIf;
	
	Return Result;
	
EndFunction

#Region InputSchedule

&AtClient
Procedure InputSchedule(PeriodDate)
	
	CurrentData = Items.WorkcentersAvailability.CurrentData;
	
	FormParameters = New Structure;
	FormParameters.Insert("Period", PeriodDate);
	FormParameters.Insert("WorkcenterType", WorkcenterType);
	FormParameters.Insert("Workcenter", CurrentData.Workcenter);
	FormParameters.Insert("Schedule", CurrentData.Schedule);
	FormParameters.Insert("Capacity", CurrentData.Capacity);
	FormParameters.Insert("ManualCorrection", CurrentData.ManualCorrection);
	FormParameters.Insert("WorkcentersDataAddress", WorkcentersDataAddress);
	FormParameters.Insert("ReadOnly", False);
	
	AdditionalParametes = New Structure;
	AdditionalParametes.Insert("RowID", CurrentData.GetID());
	
	NotifyDescription = New NotifyDescription("InputScheduleEnd", ThisObject, AdditionalParametes);
	OpenForm("DataProcessor.WorkCentersWorkplace.Form.WorkSchedule", FormParameters,,,,, NotifyDescription);
	
EndProcedure

&AtClient
Procedure InputScheduleEnd(Result, AdditionalParameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		
		WorkcentersAvailabilityLine = WorkcentersAvailability.FindByID(AdditionalParameters.RowID);
		
		If WorkcentersAvailabilityLine <> Undefined Then
			
			NameOfColumn = NameOfColumnByPeriod(Result.Period);
			WorkcentersAvailabilityLine[NameOfColumn + "ManualCorrection"] = Result.ManualCorrection;
			WorkcentersAvailabilityLine[NameOfColumn + "Available"] = Result.AvailableSeconds / 3600;
			WorkcentersAvailabilityLine[NameOfColumn + "AvailableSeconds"] = Result.AvailableSeconds;
			WorkcentersAvailabilityLine[NameOfColumn + "AvailableIsFilled"] = ValueIsFilled(Result.AvailableSeconds);
			WorkcentersAvailabilityLine[NameOfColumn + "DataWasChanged"] = True;
			
			CalculateTotalsInLine(WorkcentersAvailabilityLine, ThisObject);
			WorkScheduleWasModified = True;
			FormManagement();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FillingBySchedule

&AtServer
Function WorkcentersScheduleTable()
	
	WorkcentersSchedule = New ValueTable;
	WorkcentersSchedule.Columns.Add("WorkcenterType", New TypeDescription("CatalogRef.CompanyResourceTypes"));
	WorkcentersSchedule.Columns.Add("Workcenter", New TypeDescription("CatalogRef.CompanyResources"));
	WorkcentersSchedule.Columns.Add("Period", New TypeDescription("Date",,, New DateQualifiers(DateFractions.DateTime)));
	WorkcentersSchedule.Columns.Add("StartTime", New TypeDescription("Date",,, New DateQualifiers(DateFractions.Time)));
	WorkcentersSchedule.Columns.Add("EndTime", New TypeDescription("Date",,, New DateQualifiers(DateFractions.Time)));
	WorkcentersSchedule.Columns.Add("Capacity", New TypeDescription("Number", New NumberQualifiers(15, 2, AllowedSign.Nonnegative)));
	WorkcentersSchedule.Columns.Add("ManualCorrection", New TypeDescription("Boolean"));
	WorkcentersSchedule.Columns.Add("AvailableSeconds", New TypeDescription("Number", New NumberQualifiers(10, 2, AllowedSign.Nonnegative)));
	
	Return WorkcentersSchedule;
	
EndFunction

&AtServer
Procedure FillInAvailabilityBySchedule()
	
	If CheckWorkcenters() Then
		
		WorkcentersSchedule = GetFromTempStorage(WorkcentersDataAddress);
		
		Schedules = WorkcentersAvailability.Unload(, "Schedule").UnloadColumn("Schedule");
		WorkSchedulesForPeriod = CalendarSchedules.WorkSchedulesForPeriod(Schedules, Period.StartDate, Period.EndDate);
		
		For Each WorkcenterLine In WorkcentersAvailability Do
			
			Filter = New Structure();
			Filter.Insert("Workcenter", WorkcenterLine.Workcenter);
			RowsToDel = WorkcentersSchedule.FindRows(Filter);
			For Each RowToDel In RowsToDel Do
				WorkcentersSchedule.Delete(RowToDel);
			EndDo;
			
			If ValueIsFilled(WorkcenterLine.Schedule) Then
				
				SearchStructure = New Structure;
				SearchStructure.Insert("WorkSchedule", WorkcenterLine.Schedule);
				
				For Each ShownDate In ListOfShownDates Do
					
					PeriodDate = ShownDate.Value;
					
					SearchStructure.Insert("ScheduleDate", PeriodDate);
					WorkScheduleLines = WorkSchedulesForPeriod.FindRows(SearchStructure);
					AvailableSeconds = 0;
					
					For Each WorkScheduleLine In WorkScheduleLines Do
						
						If ValueIsFilled(WorkScheduleLine.BeginTime) Or ValueIsFilled(WorkScheduleLine.EndTime) Then
						
							WorkcentersScheduleLine = WorkcentersSchedule.Add();
							WorkcentersScheduleLine.WorkcenterType = WorkcenterType;
							WorkcentersScheduleLine.Workcenter = WorkcenterLine.Workcenter;
							WorkcentersScheduleLine.Period = PeriodDate;
							WorkcentersScheduleLine.StartTime = WorkScheduleLine.BeginTime;
							WorkcentersScheduleLine.EndTime = WorkScheduleLine.EndTime;
							WorkcentersScheduleLine.Capacity = WorkcenterLine.Capacity;
							
							If Not ValueIsFilled(WorkScheduleLine.EndTime)
								Or WorkScheduleLine.EndTime = '000101012359' Then
								
								SecondsInInterval = EndOfDay(WorkScheduleLine.EndTime) - WorkScheduleLine.BeginTime + 1;
								
							Else
								
								SecondsInInterval = BegOfMinute(WorkScheduleLine.EndTime) - WorkScheduleLine.BeginTime;
								
							EndIf;
							
							AvailableSeconds = AvailableSeconds + SecondsInInterval;
						
						EndIf;
						
					EndDo;
					
					NameOfColumnByPeriod = NameOfColumnByPeriod(PeriodDate);
					WorkcenterLine[NameOfColumnByPeriod + "AvailableIsFilled"] = True;
					WorkcenterLine[NameOfColumnByPeriod + "AvailableSeconds"] = AvailableSeconds;
					WorkcenterLine[NameOfColumnByPeriod + "Available"] = AvailableSeconds / 3600;
					WorkcenterLine[NameOfColumnByPeriod + "ManualCorrection"] = False;
					WorkcenterLine[NameOfColumnByPeriod + "DataWasChanged"] = True;
					
				EndDo;
				
				WorkScheduleWasModified = True;
				
			Else
				
				For Each ShownDate In ListOfShownDates Do
					
					PeriodDate = ShownDate.Value;
					NameOfColumnByPeriod = NameOfColumnByPeriod(PeriodDate);
					
					If WorkcenterLine[NameOfColumnByPeriod + "AvailableIsFilled"] Then
						WorkcenterLine[NameOfColumnByPeriod + "AvailableIsFilled"] = False;
						WorkcenterLine[NameOfColumnByPeriod + "AvailableSeconds"] = 0;
						WorkcenterLine[NameOfColumnByPeriod + "Available"] = 0;
						WorkcenterLine[NameOfColumnByPeriod + "ManualCorrection"] = False;
						WorkcenterLine[NameOfColumnByPeriod + "DataWasChanged"] = True;
					EndIf;
					
				EndDo;
				
				If Common.ObjectAttributeValue(WorkcenterType, "PlanningOnWorkcentersLevel") Then
					MessageAboutError = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'A work schedule is not specified for work center %1. Specify the work schedule and try again.'; ru = 'Для рабочего центра %1 не указан график работы. Укажите график работы и повторите попытку.';pl = 'Harmonogram pracy nie jest określony dla gniazda produkcyjnego %1. Określ harmonogram pracy i spróbuj ponownie.';es_ES = 'No se ha especificado un horario de trabajo para el centro de trabajo %1. Especifique el horario de trabajo e inténtelo de nuevo.';es_CO = 'No se ha especificado un horario de trabajo para el centro de trabajo %1. Especifique el horario de trabajo e inténtelo de nuevo.';tr = '%1 iş merkezi için çalışma takvimi belirtilmedi. Çalışma takvimini belirleyip tekrar deneyin.';it = 'Non è specificato un grafico di lavoro per il centro di lavoro %1. Specificare il grafico di lavoro e riprovare.';de = 'Für den Arbeitsabschnitt %1 ist kein Arbeitszeitplan angegeben. Geben Sie den Arbeitszeitplan an, und versuchen Sie es erneut.'"),
						WorkcenterLine.Workcenter);
				Else
					MessageAboutError = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'A work schedule is not specified for work center type %1. Specify the work schedule and try again.'; ru = 'Для типа рабочего центра %1 не указан график работы. Укажите график работы и повторите попытку.';pl = 'Harmonogram pracy nie jest określony dla typu gniazda produkcyjnego %1. Określ harmonogram pracy i spróbuj ponownie.';es_ES = 'No se ha especificado un horario de trabajo para un tipo de centro de trabajo %1. Especifique el horario de trabajo e inténtelo de nuevo.';es_CO = 'No se ha especificado un horario de trabajo para un tipo de centro de trabajo %1. Especifique el horario de trabajo e inténtelo de nuevo.';tr = '%1 iş merkezi türü için çalışma takvimi belirtilmedi. Çalışma takvimini belirleyip tekrar deneyin.';it = 'Un grafico di lavoro non è specificato per il tipo di centro di lavoro %1. Specificare il grafico di lavoro e riprovare.';de = 'Für den Typ von Arbeitsabschnitten %1 ist kein Arbeitszeitplan angegeben. Geben Sie den Arbeitszeitplan an, und versuchen Sie es erneut.'"),
						WorkcenterType);
				EndIf;
				
				PathToTabularSection = CommonClientServer.PathToTabularSection(
					"WorkcentersAvailability",
					WorkcenterLine.GetID() + 1,
					"Workcenter");
				CommonClientServer.MessageToUser(MessageAboutError, , PathToTabularSection);
				
			EndIf;
			
			CalculateTotalsInLine(WorkcenterLine, ThisObject);
			
		EndDo;
		
		PutToTempStorage(WorkcentersSchedule, WorkcentersDataAddress);
		
	EndIf;

EndProcedure

#EndRegion

#Region WorkWithColumns

&AtServer
Procedure RefreshWorkcentersAvailabilityColumns()
	
	SelectedDates = SelectedDates(Period.StartDate, Period.EndDate);
	
	ListOfNewDates = New Array;
	
	TypeHours = New TypeDescription("Number", New NumberQualifiers(10, 2, AllowedSign.Nonnegative));
	TypeSeconds = New TypeDescription("Number", New NumberQualifiers(10, 0, AllowedSign.Nonnegative));
	
	ColumnsList = New Array;
	AddColumnDescription("Show", New TypeDescription("Boolean"), False, ColumnsList);
	AddColumnDescription("ManualCorrection", New TypeDescription("Boolean"), False, ColumnsList);
	AddColumnDescription("Available", TypeHours, True, ColumnsList);
	AddColumnDescription("AvailableSeconds",TypeSeconds, False, ColumnsList);
	AddColumnDescription("AvailableIsFilled",New TypeDescription("Boolean"), False, ColumnsList);
	AddColumnDescription("DataWasChanged",New TypeDescription("Boolean"), False, ColumnsList);
	
	ListOfNewAttributes = New Array;
	For Each PeriodDate In SelectedDates Do
		
		If ListOfShownDates.FindByValue(PeriodDate) = Undefined Then
			
			NameOfColumnByPeriod = NameOfColumnByPeriod(PeriodDate);
			
			ListOfNewDates.Add(PeriodDate);
			
			For Each ColumnDescription In ColumnsList Do
				
				NewColumnName = NameOfColumnByPeriod + ColumnDescription.Name;
				NewColumn = New FormAttribute(NewColumnName, ColumnDescription.Type, "WorkcentersAvailability");
				ListOfNewAttributes.Add(NewColumn);
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	// Delete unnecessary dates
	ListOfAttributesToDel = New Array;
	ListOfDelDates = New Array;
	For Each ShownDate In ListOfShownDates Do
		
		PeriodDate = ShownDate.Value;
		
		If SelectedDates.Find(PeriodDate) = Undefined Then
			
			NameOfColumnByPeriod = NameOfColumnByPeriod(PeriodDate);
			
			For Each ColumnDescription In ColumnsList Do
				
				ColumnName = NameOfColumnByPeriod + ColumnDescription.Name;
				ListOfAttributesToDel.Add("WorkcentersAvailability." + ColumnName);
				If ColumnDescription.Show Then
					Items.Delete(Items.Find(ColumnName));
				EndIf;
				
			EndDo;
			
			Items.Delete(Items.Find(NameOfColumnByPeriod + "PeriodGroup"));
			
			ListOfDelDates.Add(ShownDate);
			
		EndIf;
		
	EndDo;
	
	For Each DelDate In ListOfDelDates Do
		
		ListOfShownDates.Delete(DelDate);
		
	EndDo;
	
	If ListOfNewAttributes.Count() Or ListOfAttributesToDel.Count() Then
		ChangeAttributes(ListOfNewAttributes, ListOfAttributesToDel);
	EndIf;
	
	For Each NewDate In ListOfNewDates Do
		
		ListOfShownDates.Add(NewDate);
		
		NameOfColumnByPeriod = NameOfColumnByPeriod(NewDate);
		
		// Find next column (our column will be before it)
		ItemNextPeriod = Items.WorkcentersAvailabilityLastEmptyColumn;
		For Each ExistingColumn In Items.WorkcentersAvailability.ChildItems Do
			
			If StrFind(ExistingColumn.Name, "PeriodGroup") Then
				
				ExistingColumnDate = PeriodByColumnName(ExistingColumn.Name);
				If ExistingColumnDate > NewDate Then
					
					ItemNextPeriod = ExistingColumn;
					Break;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		// Group for new items
		PeriodGroup = Items.Insert(
			NameOfColumnByPeriod + "PeriodGroup",
			Type("FormGroup"),
			Items.WorkcentersAvailability,
			ItemNextPeriod);
		PeriodGroup.Group = ColumnsGroup.Vertical;
		PeriodGroup.ShowTitle = True;
		PeriodGroup.ShowInHeader = True;
		
		// Add new items
		For Each ColumnDescription In ColumnsList Do
			
			NewItemName = NameOfColumnByPeriod + ColumnDescription.Name;
			NewItem = Undefined;
			If ColumnDescription.Show Then
				
				NewItem = Items.Add(NewItemName, Type("FormField"), PeriodGroup);
				NewItem.Type = FormFieldType.InputField;
				NewItem.Width = 8;
				NewItem.DataPath = "WorkcentersAvailability." + NewItemName;
				NewItem.HorizontalStretch = False;
				NewItem.ShowInHeader = False;
				NewItem.TextEdit = False;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	// Refresh columns titles
	For Each DataItem In ListOfShownDates Do
		
		PeriodDate = DataItem.Value;
		NameOfColumnByPeriod = NameOfColumnByPeriod(PeriodDate);
		PeriodGroup = Items[NameOfColumnByPeriod + "PeriodGroup"];
		PeriodGroup.Title = TitleOfPeriodColumn(PeriodDate);
		
	EndDo;
	
EndProcedure

&AtServer
Function SelectedDates(StartDate, EndDate)
	
	Result = New Array;
	
	If ValueIsFilled(StartDate) And ValueIsFilled(EndDate) Then
		
		PeriodDate = StartDate;
		While PeriodDate <= EndDate Do
			
			Result.Add(PeriodDate);
			PeriodDate = EndOfDay(PeriodDate) + 1;
			
		EndDo;
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Function NameOfColumnByPeriod(PeriodDate)

	Return "_C" + Format(PeriodDate, "DF=yyyyMMdd");

EndFunction

&AtClientAtServerNoContext
Function PeriodByColumnName(ColumnName)

	Return Date(Mid(ColumnName, 3, 8));

EndFunction

&AtServer
Function TitleOfPeriodColumn(PeriodDate)

	Result = "";
	Result = Format(PeriodDate, NStr("en = 'DF=''dd MMM (ddd)'''; ru = 'DF=''dd MMM (ddd)''';pl = 'DF=''dd MMM (ddd)''';es_ES = 'DF=''dd MMM (ddd)''';es_CO = 'DF=''dd MMM (ddd)''';tr = 'DF=''dd MMM (ddd)''';it = 'DF=''dd MMM (ddd)''';de = 'DF=''dd MMM (ddd)'''"));
	
	Return Result;
	
EndFunction

&AtServer
Procedure AddColumnDescription(ColumnName, TypeDescription, Show, ColumnsList)

	ColumnDescription = New Structure;
	ColumnDescription.Insert("Name", ColumnName);
	ColumnDescription.Insert("Type", TypeDescription);
	ColumnDescription.Insert("Show", Show);
	ColumnsList.Add(ColumnDescription);

EndProcedure

#EndRegion

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		
		ProcessPreparedData(ImportResult);
		
		If ImportResult.DataLoadSettings.FillingObjectFullName = "Catalog.CompanyResourceTypes" Then
			Items.CompanyResourceTypes.Refresh();
		ElsIf ImportResult.DataLoadSettings.FillingObjectFullName = "Catalog.CompanyResources" Then
			Items.CompanyResources.Refresh();
		EndIf;
		
		ShowMessageBox(Undefined, NStr("en = 'Data import is complete.'; ru = 'Загрузка данных завершена.';pl = 'Pobieranie danych zakończone.';es_ES = 'Importación de datos se ha finalizado.';es_CO = 'Importación de datos se ha finalizado.';tr = 'Veri içe aktarımı tamamlandı.';it = 'L''importazione dei dati è stata completata.';de = 'Der Datenimport ist abgeschlossen.'"));
		
	ElsIf ImportResult = Undefined Then
		
		Items.CompanyResourceTypes.Refresh();
		Items.CompanyResources.Refresh();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult);
	
EndProcedure

#EndRegion


