
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Parameters.ChoiceMode Then
		Items.List.ChoiceMode = True;
	EndIf;
	
	SetListParameters();
	
	CanBeEdited = AccessRight("Edit", Metadata.Catalogs.Calendars);
	HasAttributeBulkEditing = Common.SubsystemExists("StandardSubsystems.BatchEditObjects");
	Items.ListChangeSelectedItems.Visible = HasAttributeBulkEditing AND CanBeEdited;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
		For each FormItem In Items.CommandBar.ChildItems Do
			
			Items.Move(FormItem, Items.CommandBarForm);
			
		EndDo;
		
		CommonClientServer.SetFormItemProperty(Items, "CommandBar", "Visible", False);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ChangeSelectedItems(Command)
	If CommonClient.SubsystemExists("StandardSubsystems.BatchEditObjects") Then
		ModuleBatchEditObjectsClient = CommonClient.CommonModule("BatchEditObjectsClient");
		ModuleBatchEditObjectsClient.ChangeSelectedItems(Items.List);
	EndIf;
EndProcedure

#EndRegion

#Region FormItemsEventHandlers

&AtServerNoContext
Procedure ListOnReceiveDataAtServer(ItemName, Settings, Rows)
	
	Query = New Query;
	Query.SetParameter("Calendars", Rows.GetKeys());
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("CalendarNotFilled", NStr("ru = 'Производственный календарь не заполнен'; en = 'The business calendar is required'; pl = 'Nie wypełniono kalendarza produkcyjnego';es_ES = 'Calendario laboral no rellenado';es_CO = 'Calendario laboral no rellenado';tr = 'Üretim takvimi doldurulmadı';it = 'Il calendario aziendale è richiesto';de = 'Der Produktionskalender ist nicht ausgefüllt'"));
	Query.SetParameter("YearCalendarNotFilled", NStr("ru = 'Производственный календарь не заполнен на очередной календарный год'; en = 'The business calendar for the next calendar year is required'; pl = 'Nie wypełniono kalendarza produkcyjnego na następny rok kalendarzowy';es_ES = 'Calendario laboral no rellenado para este año';es_CO = 'Calendario laboral no rellenado para este año';tr = 'Üretim takvimi sonraki takvim yılı için doldurulmadı';it = 'Il calendario aziendale per il prossimo anno è richiesto';de = 'Der Produktionskalender wird für das nächste Kalenderjahr nicht ausgefüllt'"));
	Query.SetParameter("ScheduleNotFilled", NStr("ru = 'График не был заполнен на очередной календарный год'; en = 'The schedule for the next calendar year is not completed'; pl = 'Harmonogram nie został wypełniony na następny rok kalendarzowy';es_ES = 'El horario no ha sido rellenado para este año';es_CO = 'El horario no ha sido rellenado para este año';tr = 'Grafik sonraki takvim yılı için doldurulmadı';it = 'La pianificazione per il prossimo anno di calendario non è completata';de = 'Der Zeitplan wurde für das nächste Kalenderjahr nicht ausgefüllt'"));
	Query.SetParameter("SchedulePeriodLimited", NStr("ru = 'Период заполнения графика ограничен (см. поле ""Дата окончания"")'; en = 'Schedule filling period is limited (see the End date field)'; pl = 'Okres wypełniania harmonogramu jest ograniczony (zob. pole ""Data zakończenia"")';es_ES = 'El período de rellenar el horario está restringido (véase el campo ""Fecha de terminación"")';es_CO = 'El período de rellenar el horario está restringido (véase el campo ""Fecha de terminación"")';tr = 'Grafik doldurma süresi sınırlıdır (bkz. ""Bitiş tarihi"" alanı)';it = 'Il periodo di compilazione del grafico è limitato (vedi il campo Data di fine)';de = 'Der Füllzeitraum des Diagramms ist begrenzt (siehe Feld ""Enddatum"")'"));
	Query.Text = 
		"SELECT
		|	CalendarSchedules.Calendar AS WorkSchedule,
		|	MAX(CalendarSchedules.ScheduleDate) AS FillDate
		|INTO TTScheduleBusyDates
		|FROM
		|	InformationRegister.CalendarSchedules AS CalendarSchedules
		|WHERE
		|	CalendarSchedules.Calendar IN(&Calendars)
		|
		|GROUP BY
		|	CalendarSchedules.Calendar
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	BusinessCalendarsData.BusinessCalendar AS BusinessCalendar,
		|	MAX(BusinessCalendarsData.Date) AS FillDate
		|INTO TTCalendarBusyDates
		|FROM
		|	InformationRegister.BusinessCalendarData AS BusinessCalendarsData
		|		INNER JOIN Catalog.Calendars AS Calendars
		|		ON (Calendars.BusinessCalendar = BusinessCalendarsData.BusinessCalendar)
		|			AND (Calendars.Ref IN (&Calendars))
		|
		|GROUP BY
		|	BusinessCalendarsData.BusinessCalendar
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CatalogWorkSchedules.Ref AS Ref,
		|	DATEADD(&CurrentDate, MONTH, CatalogWorkSchedules.PlanningHorizon) AS RequiredFillingDate,
		|	SchedulesData.FillDate AS FillDate,
		|	BusinessCalendarsData.FillDate AS BusinessCalendarFillDate,
		|	CASE
		|		WHEN SchedulesData.FillDate < DATEADD(&CurrentDate, MONTH, CatalogWorkSchedules.PlanningHorizon)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS RequiresFilling
		|FROM
		|	Catalog.Calendars AS CatalogWorkSchedules
		|		LEFT JOIN TTScheduleBusyDates AS SchedulesData
		|		ON CatalogWorkSchedules.Ref = SchedulesData.WorkSchedule
		|		LEFT JOIN TTCalendarBusyDates AS BusinessCalendarsData
		|		ON CatalogWorkSchedules.BusinessCalendar = BusinessCalendarsData.BusinessCalendar
		|WHERE
		|	CatalogWorkSchedules.Ref IN(&Calendars)";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		ListLine = Rows[Selection.Ref];
		ListLine.Data["RequiredFillingDate"] = Selection.RequiredFillingDate;
		ListLine.Data["FillDate"] = Selection.FillDate;
		ListLine.Data["BusinessCalendarFillDate"] = Selection.BusinessCalendarFillDate;
		ListLine.Data["RequiresFilling"] = Selection.RequiresFilling;
		
		If Selection.RequiresFilling Then
			For Each KeyAndValue In ListLine.Appearance Do
				KeyAndValue.Value.SetParameterValue("TextColor", StyleColors.OverdueDataColor);
			EndDo;
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetListParameters()
	
	CommonClientServer.SetDynamicListFilterItem(
		List, "ScheduleOwner", , DataCompositionComparisonType.NotFilled, , ,
		DataCompositionSettingsItemViewMode.Normal);
	
EndProcedure

#EndRegion
