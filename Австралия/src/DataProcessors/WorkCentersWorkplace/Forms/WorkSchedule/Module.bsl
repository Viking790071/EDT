#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("Workcenter", Workcenter);
	Parameters.Property("WorkcenterType", WorkcenterType);
	Parameters.Property("Period", Period);
	Parameters.Property("Schedule", Schedule);
	Parameters.Property("WorkcentersDataAddress", WorkcentersDataAddress);
	Parameters.Property("ManualCorrection", ManualCorrection);
	Parameters.Property("Capacity", Capacity);
	
	WorkcentersData = GetFromTempStorage(WorkcentersDataAddress);
	SearchStructure = New Structure("Workcenter, Period", Workcenter, Period);
	ScheduleOnDate = WorkcentersData.FindRows(SearchStructure);
	
	For Each ScheduleOnDateLine In ScheduleOnDate Do
		
		If ScheduleOnDateLine.Capacity <> 0 Then
			IntervalsLine = Intervals.Add();
			FillPropertyValues(IntervalsLine, ScheduleOnDateLine, "StartTime, EndTime");
		EndIf;
		
	EndDo;
	
	Intervals.Sort("StartTime");
	
	CalculateTotalTime(ThisObject);
	
	If Parameters.ReadOnly Then
		Items.Intervals.ReadOnly = True;
		Items.IntervalsFillInBySchedule.Visible = False;
		Items.Intervals.CommandBarLocation = FormItemCommandBarLabelLocation.None;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	If Modified Then
		
		StandardProcessing = False;
		
		SaveAndCloseNotification = New NotifyDescription("BeforeCloseEnd", ThisObject);
		QuestionText = NStr("en = 'Data has been changed. Save the changes?'; ru = 'Данные изменены. Сохранить изменения?';pl = 'Dane zostały zmienione. Zapisać zmiany?';es_ES = 'Se han cambiado los datos. ¿Guardar los cambios?';es_CO = 'Se han cambiado los datos. ¿Guardar los cambios?';tr = 'Veriler değiştirildi. Değişiklikler kaydedilsin mi?';it = 'I dati sono stati modificati. Salvare le modifiche?';de = 'Die Daten sind geändert. Änderungen speichern?'");
		
		CommonClient.ShowFormClosingConfirmation(SaveAndCloseNotification, Cancel, Exit, QuestionText, MessageText);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region IntervalsFormTableItemsEventHandlers

&AtClient
Procedure IntervalsOnChange(Item)
	
	ManualCorrection = True;
	CalculateTotalTime(ThisObject);
	
EndProcedure

&AtClient
Procedure IntervalsOnEditEnd(Item, NewRow, CancelEdit)
	
	If CancelEdit Then
		CalculateTotalTime(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure IntervalsStartTimeOnChange(Item)
	
	Intervals.Sort("StartTime");
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure FillInBySchedule(Command)
	
	If ValueIsFilled(Schedule) Then
		
		FillInAvailabilityBySchedule();
		
	Else
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		NotifyDescription = New NotifyDescription("FillInByScheduleEnd", ThisObject);
		OpenForm("Catalog.Calendars.ChoiceForm", FormParameters,,,,, NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OK(Command)
	
	WorkWithFormEnd();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure WorkWithFormEnd()
	
	ClearMessages();
	
	If CheckIntervals() Then
		
		SaveDayScheduleAtWorkcentersDataAddress();
		
		Result = New Structure;
		Result.Insert("Period", Period);
		Result.Insert("AvailableSeconds", TotalTimeSeconds);
		Result.Insert("ManualCorrection", ManualCorrection);
		
		Modified = False;
		
		Close(Result);
		
	EndIf;
	
EndProcedure

&AtClient
Function CheckIntervals()
	
	Cancel = False;
	
	EndOfDay = Undefined;
	
	For Each IntervalsRow In Intervals Do
		
		RowIndex = Intervals.IndexOf(IntervalsRow);
		
		If IntervalsRow.StartTime > IntervalsRow.EndTime
			And ValueIsFilled(IntervalsRow.EndTime) Then
			
			CommonClientServer.MessageToUser(
				NStr("en = 'Start time is greater than the end time.'; ru = 'Время начала больше времени окончания.';pl = 'Czas rozpoczęcia jest późniejszy niż czas zakończenia.';es_ES = 'Hora inicial es mayor que la hora final.';es_CO = 'Hora inicial es mayor que la hora final.';tr = 'Başlangıç zamanı bitiş zamanından daha büyüktür.';it = 'Ora di inizio è maggiore del tempo della fine.';de = 'Startzeit ist größer als die Endzeit.'"),
				,
				StringFunctionsClientServer.SubstituteParametersToString("Intervals[%1].EndTime", RowIndex),
				,
				Cancel);
			
		EndIf;
		
		If IntervalsRow.StartTime = IntervalsRow.EndTime Then
			
			CommonClientServer.MessageToUser(
				NStr("en = 'Interval duration is not specified.'; ru = 'Продолжительность периодичности не указана.';pl = 'Nie wybrano czasu trwania interwału';es_ES = 'Duración del intervalo no está especificada.';es_CO = 'Duración del intervalo no está especificada.';tr = 'Aralık süresi belirtilmedi.';it = 'durata dell''intervallo non è specificato';de = 'Intervalldauer ist nicht angegeben .'"),
				,
				StringFunctionsClientServer.SubstituteParametersToString("Intervals[%1].EndTime", RowIndex),
				,
				Cancel);
			
		EndIf;
		
		If EndOfDay <> Undefined Then
			
			If EndOfDay > IntervalsRow.StartTime
				Or Not ValueIsFilled(EndOfDay) Then
				CommonClientServer.MessageToUser(
					NStr("en = 'Overlapping intervals are detected.'; ru = 'Обнаружены пересекающиеся периодичности.';pl = 'Wykryto nakładające się interwały.';es_ES = 'Intervalos de superposición se han detectado.';es_CO = 'Intervalos de superposición se han detectado.';tr = 'Çakışan aralıklar tespit edildi.';it = 'Gli intervalli sovrapposti vengono rilevati';de = 'Überlappende Intervalle werden erkannt.'"),
					,
					StringFunctionsClientServer.SubstituteParametersToString("Intervals[%1].StartTime", RowIndex),
					,
					Cancel);
				EndIf;
				
		EndIf;
		
		EndOfDay = IntervalsRow.EndTime;
		
	EndDo;
	
	Return Not Cancel;
	
EndFunction

&AtServer
Procedure SaveDayScheduleAtWorkcentersDataAddress()
	
	WorkcentersSchedule = GetFromTempStorage(WorkcentersDataAddress);
	
	Filter = New Structure();
	Filter.Insert("Workcenter", Workcenter);
	Filter.Insert("Period", Period);
	RowsToDel = WorkcentersSchedule.FindRows(Filter);
	For Each RowToDel In RowsToDel Do
		WorkcentersSchedule.Delete(RowToDel);
	EndDo;
	
	For Each IntervalsRow In Intervals Do
		
		WorkcentersScheduleLine = WorkcentersSchedule.Add();
		WorkcentersScheduleLine.WorkcenterType = WorkcenterType;
		WorkcentersScheduleLine.Workcenter = Workcenter;
		WorkcentersScheduleLine.Period = Period;
		WorkcentersScheduleLine.StartTime = IntervalsRow.StartTime;
		WorkcentersScheduleLine.EndTime = IntervalsRow.EndTime;
		WorkcentersScheduleLine.Capacity = Capacity;
		WorkcentersScheduleLine.ManualCorrection = ManualCorrection;
		
		If Not ValueIsFilled(WorkcentersScheduleLine.EndTime)
			Or WorkcentersScheduleLine.EndTime = '000101012359'
			Or WorkcentersScheduleLine.EndTime = '00010101235959' Then
			
			AvailableSeconds = EndOfDay(WorkcentersScheduleLine.EndTime) - WorkcentersScheduleLine.StartTime + 1;
			
		Else
			
			AvailableSeconds = WorkcentersScheduleLine.EndTime - WorkcentersScheduleLine.StartTime;
			
		EndIf;
		
		WorkcentersScheduleLine.AvailableSeconds = AvailableSeconds;
		
	EndDo;
	
	PutToTempStorage(WorkcentersSchedule, WorkcentersDataAddress);
	
EndProcedure

&AtClient
Procedure FillInByScheduleEnd(Result, AdditionalParameters) Export
	
	If ValueIsFilled(Result) Then
		
		Schedule = Result;
		FillInAvailabilityBySchedule();
		ManualCorrection = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillInAvailabilityBySchedule()
	
	Intervals.Clear();
	
	Schedules = CommonClientServer.ValueInArray(Schedule);
	WorkScheduleOnDate = CalendarSchedules.WorkSchedulesForPeriod(Schedules, BegOfDay(Period), EndOfDay(Period));
	
	For Each WorkScheduleLine In WorkScheduleOnDate Do
		
		IntervalsLine = Intervals.Add();
		IntervalsLine.StartTime = WorkScheduleLine.BeginTime;
		IntervalsLine.EndTime = WorkScheduleLine.EndTime;
		
	EndDo;
	
	CalculateTotalTime(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure CalculateTotalTime(Form)
	
	Form.TotalTimeSeconds = 0;
	
	For Each IntervalLine In Form.Intervals Do
		
		If Not ValueIsFilled(IntervalLine.EndTime) Then
			
			SecondsInInterval = EndOfDay(IntervalLine.EndTime) - IntervalLine.StartTime + 1;
			
		Else
			
			SecondsInInterval = BegOfMinute(IntervalLine.EndTime) - IntervalLine.StartTime;
			
		EndIf;
		
		Form.TotalTimeSeconds = Form.TotalTimeSeconds + SecondsInInterval;
		
	EndDo;
	
	Form.TotalTime = Form.TotalTimeSeconds / 3600;
	
EndProcedure

&AtClient
Procedure BeforeCloseEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		WorkWithFormEnd();
		
	ElsIf Result = DialogReturnCode.No Then
		
		Modified = False;
		Close();
		
	EndIf;
	
EndProcedure

#EndRegion