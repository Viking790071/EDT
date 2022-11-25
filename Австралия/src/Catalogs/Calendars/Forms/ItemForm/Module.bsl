#Region Variables

&AtClient
Var ChoiceContext;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Not Object.Ref.IsEmpty() Then
		Return;
	EndIf;	
	
	InfobaseUpdate.CheckObjectProcessed("Catalog.Calendars", ThisObject);
	
	// If there is only one business calendar in the application, fill it in by default.
	BusinessCalendars = Catalogs.BusinessCalendars.BusinessCalendarsList();
	If BusinessCalendars.Count() = 1 Then
		Object.BusinessCalendar = BusinessCalendars[0];
	EndIf;
	
	Object.FillingMethod = Enums.WorkScheduleFillingMethods.ByWeeks;
	
	PeriodLength = 7;
	
	Object.StartDate = BegOfYear(CurrentSessionDate());
	Object.StartingDate = BegOfYear(CurrentSessionDate());
	
	ConfigureFillingSettingItems(ThisObject);
	
	GenerateFillingTemplate(Object.FillingMethod, Object.FillingTemplate, PeriodLength, Object.StartingDate);
	
	FillSchedulePresentation(ThisObject);
	
	SetEnabledConsiderHolidays(ThisObject);
	
	SpecifyFillDate();
	
	FillWithCurrentYearData(Parameters.CopyingValue);
	
	SetClearResultsMatchTemplateFlag(ThisObject, True);
	
	SetEnabledPreholidaySchedule(ThisObject);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	PeriodLength = Object.FillingTemplate.Count();
	
	ConfigureFillingSettingItems(ThisObject);
	
	GenerateFillingTemplate(Object.FillingMethod, Object.FillingTemplate, PeriodLength, Object.StartingDate);
	
	FillSchedulePresentation(ThisObject);
	
	SetEnabledConsiderHolidays(ThisObject);
	
	SpecifyFillDate();
	
	FillWithCurrentYearData();
	
	SetClearResultsMatchTemplateFlag(ThisObject, True);
	SetRemoveTemplateModified(ThisObject, False);
	
	SetEnabledPreholidaySchedule(ThisObject);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("Catalog.Calendars.Form.WorkSchedule") Then
		
		If SelectedValue = Undefined Or ReadOnly Then
			Return;
		EndIf;
		
		// Delete the previously filled in schedule for this day.
		DayRows = New Array;
		For Each ScheduleString In Object.WorkSchedule Do
			If ScheduleString.DayNumber = ChoiceContext.DayNumber Then
				DayRows.Add(ScheduleString.GetID());
			EndIf;
		EndDo;
		For Each RowID In DayRows Do
			Object.WorkSchedule.Delete(Object.WorkSchedule.FindByID(RowID));
		EndDo;
		
		// Filling the work hours for a day.
		For Each IntervalDetails In SelectedValue.WorkSchedule Do
			NewRow = Object.WorkSchedule.Add();
			FillPropertyValues(NewRow, IntervalDetails);
			NewRow.DayNumber = ChoiceContext.DayNumber;
		EndDo;
		
		If ChoiceContext.DayNumber = 0 Then
			PreholidaySchedule = DaySchedulePresentation(ThisObject, 0);
		EndIf;
		
		SetClearResultsMatchTemplateFlag(ThisObject, False);
		SetRemoveTemplateModified(ThisObject, True);
		
		If ChoiceContext.Source = "FillingTemplateChoice" Then
			
			TemplateRow = Object.FillingTemplate.FindByID(ChoiceContext.TemplateRowID);
			TemplateRow.DayAddedToSchedule = SelectedValue.WorkSchedule.Count() > 0; // schedule is filled in
			TemplateRow.SchedulePresentation = DaySchedulePresentation(ThisObject, ChoiceContext.DayNumber);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	Var YearNumber;
	
	If Not WriteParameters.Property("YearNumber", YearNumber) Then
		YearNumber = CurrentYearNumber;
	EndIf;
	
	// If the data of the current year is edited manually, write it as it is and update other periods by 
	// template.
	
	If ResultModified Then
		Catalogs.Calendars.WriteScheduleDataToRegister(CurrentObject.Ref, ScheduleDays, Date(YearNumber, 1, 1), Date(YearNumber, 12, 31), True);
	EndIf;
	SaveManualEditingFlag(CurrentObject, YearNumber);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	PeriodLength = Object.FillingTemplate.Count();
	
	ConfigureFillingSettingItems(ThisObject);
	
	GenerateFillingTemplate(Object.FillingMethod, Object.FillingTemplate, PeriodLength, Object.StartingDate);
	
	FillSchedulePresentation(ThisObject);
	
	SpecifyFillDate();
	
	SetRemoveTemplateModified(ThisObject, False);
	
	FillWithCurrentYearData();
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Object.FillingMethod = Enums.WorkScheduleFillingMethods.ByArbitraryLengthPeriods Then
		CheckedAttributes.Add("PeriodLength");
		CheckedAttributes.Add("StartingDate");
	EndIf;
	
	If Object.FillingTemplate.FindRows(New Structure("DayAddedToSchedule", True)).Count() = 0 Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Не отмечены дни, включаемые в график работы'; en = 'Days included in the work schedule are not marked'; pl = 'Dni zawarte w harmonogramie prac nie są oznaczone';es_ES = 'Seleccionar días laborales para el padrón';es_CO = 'Seleccionar días laborales para el padrón';tr = 'Çalışma programına dahil edilen günler işaretlenmedi';it = 'Giorni incluse nel programma di lavoro non sono contrassegnati';de = 'Tage, die im Arbeitszeitplan enthalten sind, sind nicht markiert'"), , "Object.FillingTemplate", , Cancel);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure FillFromTemplate(Command)
	
	FillByTemplateAtServer();
	
	Items.WorkSchedule.Refresh();
	
EndProcedure

&AtClient
Procedure FillingResult(Command)
	
	Items.Pages.CurrentPage = Items.FillingResultPage;
	
	If Not ResultFilledByTemplate Then
		FillByTemplateAtServer(True);
	EndIf;
	
	Items.WorkSchedule.Refresh();
	
EndProcedure

&AtClient
Procedure FillingSettings(Command)
	
	Items.Pages.CurrentPage = Items.FillingSettingsPage;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM ITEM EVENT HANDLERS

&AtClient
Procedure BusinessCalendarOnChange(Item)
	
	SetEnabledConsiderHolidays(ThisObject);
	
	SetClearResultsMatchTemplateFlag(ThisObject, False);
	SetRemoveTemplateModified(ThisObject, True);
	
EndProcedure

&AtClient
Procedure FillingMethodOnChange(Item)

	ConfigureFillingSettingItems(ThisObject);
	
	ClarifyStartingDate();	
	
	GenerateFillingTemplate(Object.FillingMethod, Object.FillingTemplate, PeriodLength, Object.StartingDate);
	FillSchedulePresentation(ThisObject);

	SetClearResultsMatchTemplateFlag(ThisObject, False);
	SetRemoveTemplateModified(ThisObject, True);
	
EndProcedure

&AtClient
Procedure StartDateOnChange(Item)
	
	If Object.StartDate < Date(1900, 1, 1) Then
		Object.StartDate = BegOfYear(CommonClient.SessionDate());
	EndIf;
	
EndProcedure

&AtClient
Procedure PeriodStartDateOnChange(Item)
	
	ClarifyStartingDate();
	
	GenerateFillingTemplate(Object.FillingMethod, Object.FillingTemplate, PeriodLength, Object.StartingDate);
	
	SetClearResultsMatchTemplateFlag(ThisObject, False);
	SetRemoveTemplateModified(ThisObject, True);
	
EndProcedure

&AtClient
Procedure PeriodLengthOnChange(Item)
	
	GenerateFillingTemplate(Object.FillingMethod, Object.FillingTemplate, PeriodLength, Object.StartingDate);
	FillSchedulePresentation(ThisObject);

	SetClearResultsMatchTemplateFlag(ThisObject, False);
	SetRemoveTemplateModified(ThisObject, True);
	
EndProcedure

&AtClient
Procedure ConsiderHolidaysOnChange(Item)
	
	SetClearResultsMatchTemplateFlag(ThisObject, False);
	SetRemoveTemplateModified(ThisObject, True);
	
	SetEnabledPreholidaySchedule(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetEnabledPreholidaySchedule(Form)
	Form.Items.PreholidaySchedule.Enabled = Form.Object.ConsiderHolidays;
EndProcedure

&AtClient
Procedure FillingTemplateChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	TemplateRow = Object.FillingTemplate.FindByID(RowSelected);
	
	ChoiceContext = New Structure;
	ChoiceContext.Insert("Source", "FillingTemplateChoice");
	ChoiceContext.Insert("DayNumber", TemplateRow.LineNumber);
	ChoiceContext.Insert("SchedulePresentation", TemplateRow.SchedulePresentation);
	ChoiceContext.Insert("TemplateRowID", RowSelected);
	
	FormParameters = New Structure;
	FormParameters.Insert("WorkSchedule", WorkSchedule(ChoiceContext.DayNumber));
	FormParameters.Insert("ReadOnly", ReadOnly);
	
	OpenForm("Catalog.Calendars.Form.WorkSchedule", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure FillingTemplateDayAddedToScheduleOnChange(Item)
	
	SetClearResultsMatchTemplateFlag(ThisObject, False);
	SetRemoveTemplateModified(ThisObject, True);
	
EndProcedure

&AtClient
Procedure PreholidayScheduleClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ChoiceContext = New Structure;
	ChoiceContext.Insert("Source", "PreholidayScheduleClick");
	ChoiceContext.Insert("DayNumber", 0);
	ChoiceContext.Insert("SchedulePresentation", PreholidaySchedule);
	
	FormParameters = New Structure;
	FormParameters.Insert("WorkSchedule", WorkSchedule(ChoiceContext.DayNumber));
	FormParameters.Insert("ReadOnly", ReadOnly);
	
	OpenForm("Catalog.Calendars.Form.WorkSchedule", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure PlanningHorizonOnChange(Item)
	
	AdjustScheduleFilled(ThisObject);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject, "Object.Details");
	
EndProcedure

&AtClient
Procedure CurrentYearNumberOnChange(Item)
	
	If CurrentYearNumber < Year(Object.StartDate)
		Or (ValueIsFilled(Object.EndDate) AND CurrentYearNumber > Year(Object.EndDate)) Then
		CurrentYearNumber = PreviousYearNumber;
		Return;
	EndIf;
	
	WriteScheduleData = False;
	
	If ResultModified Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Записать измененные данные за %1 год?'; en = 'Do you want to write changed data for year %1?'; pl = 'Zapisać zmienione dane za %1 rok?';es_ES = '¿Inscribir los datos cambiados para el año de %1?';es_CO = '¿Inscribir los datos cambiados para el año de %1?';tr = '%1 yılı için değiştirilmiş veriler yazılsın mı?';it = 'Volete scrivere i dati modificati per l''anno %1?';de = 'Schreiben Sie die geänderten Daten für das Jahr %1?'"), Format(PreviousYearNumber, "NG=0"));
		
		Notification = New NotifyDescription("CurrentYearNumberOnChangeCompletion", ThisObject);
		ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo);
		Return;
		
	EndIf;
	
	ProcessYearChange(WriteScheduleData);
	
	SetRemoveResultModified(ThisObject, False);
	
	Items.WorkSchedule.Refresh();
	
EndProcedure

&AtClient
Procedure WorkScheduleOnPeriodOutput(Item, PeriodAppearance)
	
	For Each PeriodAppearanceString In PeriodAppearance.Dates Do
		If ScheduleDays.Get(PeriodAppearanceString.Date) = Undefined Then
			DayTextColor = CommonClient.StyleColor("BusinessCalendarDayKindColorNotSpecified");
		Else
			DayTextColor = CommonClient.StyleColor("BusinessCalendarDayKindWorkdayColor");
		EndIf;
		PeriodAppearanceString.TextColor = DayTextColor;
		// Manual editing
		If ChangedDays.Get(PeriodAppearanceString.Date) = Undefined Then
			DayBgColor = CommonClient.StyleColor("FieldBackColor");
		Else
			DayBgColor = CommonClient.StyleColor("ChangedScheduleDateBackground");
		EndIf;
		PeriodAppearanceString.BackColor = DayBgColor;
	EndDo;
	
EndProcedure

&AtClient
Procedure WorkScheduleChoice(Item, SelectedDate)
	
	If ScheduleDays.Get(SelectedDate) = Undefined Then
		// Include in the schedule
		WorkSchedulesClientServer.InsertIntoFixedMap(ScheduleDays, SelectedDate, True);
		DayAddedToSchedule = True;
	Else
		// Exclude from the schedule
		WorkSchedulesClientServer.DeleteFromFixedMap(ScheduleDays, SelectedDate);
		DayAddedToSchedule = False;
	EndIf;
	
	// Save the manual change as of the date.
	WorkSchedulesClientServer.InsertIntoFixedMap(ChangedDays, SelectedDate, DayAddedToSchedule);
	
	Items.WorkSchedule.Refresh();
	
	SetRemoveManualEditingFlag(ThisObject, True);
	SetRemoveResultModified(ThisObject, True);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FillingTemplateSchedulePresentation.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.FillingTemplate.SchedulePresentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.FillingTemplate.DayAddedToSchedule");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Text", BlankSchedulePresentation());

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FillingTemplateLineNumber.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.FillingMethod");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.WorkScheduleFillingMethods.ByWeeks;

	Item.Appearance.SetParameterValue("Visible", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.IsFilledInformationText.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("RequiresFilling");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FillingResultInformationText.Name);

	FIlterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FIlterGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ResultFilledByTemplate");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ManualEditing");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.PreholidaySchedule.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("PreholidaySchedule");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.ConsiderHolidays");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Text", BlankSchedulePresentation());

EndProcedure

&AtClientAtServerNoContext
Procedure ConfigureFillingSettingItems(Form)
	
	CanChangeSetting = Form.Object.FillingMethod = PredefinedValue("Enum.WorkScheduleFillingMethods.ByArbitraryLengthPeriods");
	
	Form.Items.PeriodLength.ReadOnly = Not CanChangeSetting;
	Form.Items.StartingDate.ReadOnly = Not CanChangeSetting;
	
	Form.Items.StartingDate.AutoMarkIncomplete = CanChangeSetting;
	Form.Items.StartingDate.MarkIncomplete = CanChangeSetting AND Not ValueIsFilled(Form.Object.StartingDate);
	
EndProcedure

&AtClientAtServerNoContext
Procedure GenerateFillingTemplate(FillingMethod, FillingTemplate, Val PeriodLength, Val StartingDate = Undefined)
	
	// Generates the table for editing the template used for filling by days.
	
	If FillingMethod = PredefinedValue("Enum.WorkScheduleFillingMethods.ByWeeks") Then
		PeriodLength = 7;
	EndIf;
	
	While FillingTemplate.Count() > PeriodLength Do
		FillingTemplate.Delete(FillingTemplate.Count() - 1);
	EndDo;

	While FillingTemplate.Count() < PeriodLength Do
		FillingTemplate.Add();
	EndDo;
	
	If FillingMethod = PredefinedValue("Enum.WorkScheduleFillingMethods.ByWeeks") Then
		FillingTemplate[0].DayPresentation = NStr("ru = 'Понедельник'; en = 'Monday'; pl = 'Poniedziałek';es_ES = 'Lunes';es_CO = 'Lunes';tr = 'Pazartesi';it = 'Lunedi';de = 'Montag'");
		FillingTemplate[1].DayPresentation = NStr("ru = 'Вторник'; en = 'Tuesday'; pl = 'Wtorek';es_ES = 'Martes';es_CO = 'Martes';tr = 'Salı';it = 'Martedì';de = 'Dienstag'");
		FillingTemplate[2].DayPresentation = NStr("ru = 'Среда'; en = 'Wednesday'; pl = 'Środa';es_ES = 'Miércoles';es_CO = 'Miércoles';tr = 'Çarşamba';it = 'Mercoledì';de = 'Mittwoch'");
		FillingTemplate[3].DayPresentation = NStr("ru = 'Четверг'; en = 'Thursday'; pl = 'Czwartek';es_ES = 'Jueves';es_CO = 'Jueves';tr = 'Perşembe';it = 'Giovedì';de = 'Donnerstag'");
		FillingTemplate[4].DayPresentation = NStr("ru = 'Пятница'; en = 'Friday'; pl = 'Piątek';es_ES = 'Viernes';es_CO = 'Viernes';tr = 'Cuma';it = 'Venerdì';de = 'Freitag'");
		FillingTemplate[5].DayPresentation = NStr("ru = 'Суббота'; en = 'Saturday'; pl = 'Sobota';es_ES = 'Sábado';es_CO = 'Sábado';tr = 'Cumartesi';it = 'Sabato';de = 'Samstag'");
		FillingTemplate[6].DayPresentation = NStr("ru = 'Воскресенье'; en = 'Sunday'; pl = 'Niedziela';es_ES = 'Domingo';es_CO = 'Domingo';tr = 'Pazar';it = 'Domenica';de = 'Sonntag'");
	Else
		DayDate = StartingDate;
		For Each DayRow In FillingTemplate Do
			DayRow.DayPresentation = Format(DayDate, "DF=d.MM");
			DayRow.SchedulePresentation = BlankSchedulePresentation();
			DayDate = DayDate + 86400;
		EndDo;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillSchedulePresentation(Form)
	
	For Each TemplateRow In Form.Object.FillingTemplate Do
		TemplateRow.SchedulePresentation = DaySchedulePresentation(Form, TemplateRow.LineNumber);
	EndDo;
	
	Form.PreholidaySchedule = DaySchedulePresentation(Form, 0);
	
EndProcedure

&AtClientAtServerNoContext
Function DaySchedulePresentation(Form, DayNumber)
	
	IntervalsPresentation = "";
	Seconds = 0;
	For Each ScheduleString In Form.Object.WorkSchedule Do
		If ScheduleString.DayNumber <> DayNumber Then
			Continue;
		EndIf;
		IntervalPresentation = StringFunctionsClientServer.SubstituteParametersToString("%1-%2, ", Format(ScheduleString.BeginTime, "DF=HH:mm; DE="), Format(ScheduleString.EndTime, "DF=HH:mm; DE="));
		IntervalsPresentation = IntervalsPresentation + IntervalPresentation;
		If Not ValueIsFilled(ScheduleString.EndTime) Then
			IntervalInSeconds = EndOfDay(ScheduleString.EndTime) - ScheduleString.BeginTime + 1;
		Else
			IntervalInSeconds = ScheduleString.EndTime - ScheduleString.BeginTime;
		EndIf;
		Seconds = Seconds + IntervalInSeconds;
	EndDo;
	StringFunctionsClientServer.DeleteLastCharInString(IntervalsPresentation, 2);
	
	If Seconds = 0 Then
		Return BlankSchedulePresentation();
	EndIf;
	
	Hours = Round(Seconds / 3600, 1);
	
	Return StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 ч. (%2)'; en = '%1 h. (%2)'; pl = '%1 g. (%2)';es_ES = '%1 horas (%2)';es_CO = '%1 horas (%2)';tr = '%1 s. (%2)';it = '%1 h. (%2)';de = '%1 h. (%2)'"), Hours, IntervalsPresentation);
	
EndFunction

&AtClient
Function WorkSchedule(DayNumber)
	
	DaySchedule = New Array;
	
	For Each ScheduleString In Object.WorkSchedule Do
		If ScheduleString.DayNumber = DayNumber Then
			DaySchedule.Add(New Structure("BeginTime, EndTime", ScheduleString.BeginTime, ScheduleString.EndTime));
		EndIf;
	EndDo;
	
	Return DaySchedule;
	
EndFunction

&AtClientAtServerNoContext
Function BlankSchedulePresentation()
	
	Return NStr("ru = 'Заполнить расписание'; en = 'Fill in the schedule'; pl = 'Wypełnij harmonogram';es_ES = 'Establecer las horas laborales';es_CO = 'Establecer las horas laborales';tr = 'Programı doldur';it = 'Compila la pianificazione';de = 'Arbeitszeiten einstellen'");
	
EndFunction

&AtClientAtServerNoContext
Procedure SetEnabledConsiderHolidays(Form)
	
	Form.Items.ConsiderHolidays.Enabled = ValueIsFilled(Form.Object.BusinessCalendar);
	If Not Form.Items.ConsiderHolidays.Enabled Then
		Form.Object.ConsiderHolidays = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure SpecifyFillDate()
	
	QueryText = 
	"SELECT
	|	MAX(CalendarSchedules.ScheduleDate) AS Date
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|WHERE
	|	CalendarSchedules.Calendar = &WorkSchedule";
	
	Query = New Query(QueryText);
	Query.SetParameter("WorkSchedule", Object.Ref);
	Selection = Query.Execute().Select();
	
	FillDate = Undefined;
	If Selection.Next() Then
		FillDate = Selection.Date;
	EndIf;	
	
	AdjustScheduleFilled(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure AdjustScheduleFilled(Form)
	
	Return; // temporary not used
	
	Form.RequiresFilling = False;
	
	If Form.Parameters.Key.IsEmpty() Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Form.FillDate) Then
		Form.IsFilledInformationText = NStr("ru = 'График работы не заполнен'; en = 'The work schedule is required'; pl = 'Nie wypełniono harmonogramu pracy';es_ES = 'Horario no rellenado';es_CO = 'Horario no rellenado';tr = 'Çalışma programı doldurulmadı';it = 'La pianificazione del lavoro è richiesta';de = 'Der Arbeitszeitplan ist erforderlich'");
		Form.RequiresFilling = True;
	Else	
		If Not ValueIsFilled(Form.Object.PlanningHorizon) Then
			InformationText = NStr("ru = 'График работы заполнен до %1'; en = 'The work schedule is filled in till %1'; pl = 'Harmonogram pracy jest wypełniony do %1';es_ES = 'Horario rellenado hasta %1';es_CO = 'Horario rellenado hasta %1';tr = 'Çalışma programı %1 tarihine kadar dolduruldu';it = 'La pianificazione del lavoro è compilata fino al %1';de = 'Arbeitszeitplan ausgefüllt bis %1'");
			Form.IsFilledInformationText = StringFunctionsClientServer.SubstituteParametersToString(InformationText, Format(Form.FillDate, "DLF=D"));
		Else											
			#If WebClient Or ThinClient OR MobileClient Then
				CurrentDate = CommonClient.SessionDate();
			#Else
				CurrentDate = CurrentSessionDate();
			#EndIf
			EndPlanningHorizon = AddMonth(CurrentDate, Form.Object.PlanningHorizon);
			InformationText = NStr("ru = 'График работы заполнен до %1, с учетом горизонта планирования график должен быть заполнен до %2'; en = 'The work schedule is filled in till %1, considering the planning horizon, the schedule is to be filled in till %2'; pl = 'Harmonogram pracy jest wypełniony do %1, z uwzględnieniem horyzontu planowania harmonogram powinien być wypełniony do %2';es_ES = 'El horario rellenado hasta %1, incluso el horizonte de planificación el horario debe ser rellenado hasta %2';es_CO = 'El horario rellenado hasta %1, incluso el horizonte de planificación el horario debe ser rellenado hasta %2';tr = 'Çalışma programı %1 tarihine kadar dolduruldu; planlama sınırı dikkate alınarak program %2 tarihine kadar doldurulmalıdır';it = 'La pianificazione del lavoro è compilata fino a %1, considerando l''orizzonte di pianificazione, la pianificazione dovrebbe essere compilata fino al %2';de = 'Der Arbeitszeitplan ist bis %1 ausgefüllt, unter Berücksichtigung des Planungshorizonts muss der Arbeitsplan bis %2 ausgefüllt werden'");
			Form.IsFilledInformationText = StringFunctionsClientServer.SubstituteParametersToString(InformationText, Format(Form.FillDate, "DLF=D"), Format(EndPlanningHorizon, "DLF=D"));
			If EndPlanningHorizon > Form.FillDate Then
				Form.RequiresFilling = True;
			EndIf;
		EndIf;
	EndIf;
	Form.Items.IsFilledDecoration.Picture = ?(Form.RequiresFilling, PictureLib.Warning, PictureLib.Information);
	
EndProcedure

&AtServer
Procedure FillByTemplateAtServer(PreserveManualEditing = False)

	DaysIncludedInSchedule = Catalogs.Calendars.DaysIncludedInSchedule(
								Object.StartDate, 
								Object.FillingMethod, 
								Object.FillingTemplate, 
								Object.EndDate,
								Object.BusinessCalendar, 
								Object.ConsiderHolidays, 
								Object.StartingDate);
	
	If ManualEditing Then
		If PreserveManualEditing Then
			// Applying manual adjustments.
			For Each KeyAndValue In ChangedDays Do
				ChangeDate = KeyAndValue.Key;
				DayAddedToSchedule = KeyAndValue.Value;
				If DayAddedToSchedule Then
					DaysIncludedInSchedule.Insert(ChangeDate, True);
				Else
					DaysIncludedInSchedule.Delete(ChangeDate);
				EndIf;
			EndDo;
		Else
			SetRemoveResultModified(ThisObject, True);
			SetRemoveManualEditingFlag(ThisObject, False);
		EndIf;
	EndIf;
	
	// Copying the result to the original filling map to ensure that the dates outside of the filling 
	// interval are not cleared.
	ScheduleDaysMap = New Map(ScheduleDays);
	DayDate = Object.StartDate;
	EndDate = Object.EndDate;
	If Not ValueIsFilled(EndDate) Then
		EndDate = EndOfYear(Object.StartDate);
	EndIf;
	While DayDate <= EndDate Do
		DayAddedToSchedule = DaysIncludedInSchedule[DayDate];
		If DayAddedToSchedule = Undefined Then
			ScheduleDaysMap.Delete(DayDate);
		Else
			ScheduleDaysMap.Insert(DayDate, DayAddedToSchedule);
		EndIf;
		DayDate = DayDate + 86400;
	EndDo;
	
	ScheduleDays = New FixedMap(ScheduleDaysMap);
	
	SetClearResultsMatchTemplateFlag(ThisObject, True);
	
EndProcedure

&AtServer
Procedure FillWithCurrentYearData(CopyingValue = Undefined)
	
	// Fills in the form with data of the current year.
	
	SetCalendarField();
	
	If ValueIsFilled(CopyingValue) Then
		ScheduleRef = CopyingValue;
	Else
		ScheduleRef = Object.Ref;
	EndIf;
	
	ScheduleDays = New FixedMap(
		Catalogs.Calendars.ReadScheduleDataFromRegister(ScheduleRef, CurrentYearNumber));

	ReadManualEditingFlag(Object, CurrentYearNumber);
	
	// If there are no manual adjustments or data, generate the result by template for the selected year.
	If ScheduleDays.Count() = 0 AND ChangedDays.Count() = 0 Then
		DaysIncludedInSchedule = Catalogs.Calendars.DaysIncludedInSchedule(
									Object.StartDate, 
									Object.FillingMethod, 
									Object.FillingTemplate, 
									Date(CurrentYearNumber, 12, 31),
									Object.BusinessCalendar, 
									Object.ConsiderHolidays, 
									Object.StartingDate);
		ScheduleDays = New FixedMap(DaysIncludedInSchedule);
	EndIf;
	
	SetRemoveResultModified(ThisObject, False);
	SetClearResultsMatchTemplateFlag(ThisObject, Not TemplateModified);

EndProcedure

&AtServer
Procedure ReadManualEditingFlag(CurrentObject, YearNumber)
	
	If CurrentObject.Ref.IsEmpty() Then
		SetRemoveManualEditingFlag(ThisObject, False);
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	ManualChanges.ScheduleDate
	|FROM
	|	InformationRegister.ManualWorkScheduleChanges AS ManualChanges
	|WHERE
	|	ManualChanges.WorkSchedule = &WorkSchedule
	|	AND ManualChanges.Year = &Year");
	
	Query.SetParameter("WorkSchedule", CurrentObject.Ref);
	Query.SetParameter("Year", YearNumber);
	
	Map = New Map;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Map.Insert(Selection.ScheduleDate, True);
	EndDo;
	ChangedDays = New FixedMap(Map);
	
	SetRemoveManualEditingFlag(ThisObject, ChangedDays.Count() > 0);
	
EndProcedure

&AtServer
Procedure SaveManualEditingFlag(CurrentObject, YearNumber)
	
	RecordSet = InformationRegisters.ManualWorkScheduleChanges.CreateRecordSet();
	RecordSet.Filter.WorkSchedule.Set(CurrentObject.Ref);
	RecordSet.Filter.Year.Set(YearNumber);
	
	For Each KeyAndValue In ChangedDays Do
		SetRow = RecordSet.Add();
		SetRow.ScheduleDate = KeyAndValue.Key;
		SetRow.WorkSchedule = CurrentObject.Ref;
		SetRow.Year = YearNumber;
	EndDo;
	
	RecordSet.Write();
	
EndProcedure

&AtServer
Procedure WriteWorkScheduleDataForYear(YearNumber)
	
	Catalogs.Calendars.WriteScheduleDataToRegister(Object.Ref, ScheduleDays, Date(YearNumber, 1, 1), Date(YearNumber, 12, 31), True);
	SaveManualEditingFlag(Object, YearNumber);
	
EndProcedure

&AtServer
Procedure ProcessYearChange(WriteScheduleData)
	
	If Not WriteScheduleData Then
		FillWithCurrentYearData();
		Return;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		Write(New Structure("YearNumber", PreviousYearNumber));
	Else
		WriteWorkScheduleDataForYear(PreviousYearNumber);
		FillWithCurrentYearData();	
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetRemoveManualEditingFlag(Form, ManualEditing)
	
	Form.ManualEditing = ManualEditing;
	
	If Not ManualEditing Then
		Form.ChangedDays = New FixedMap(New Map);
	EndIf;
	
	FillFillingResultInformationText(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetClearResultsMatchTemplateFlag(Form, ResultFilledByTemplate)
	
	Form.ResultFilledByTemplate = ResultFilledByTemplate;
	
	FillFillingResultInformationText(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetRemoveTemplateModified(Form, TemplateModified)
	
	Form.TemplateModified = TemplateModified;
	
	Form.Modified = Form.TemplateModified Or Form.ResultModified;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetRemoveResultModified(Form, ResultModified)
	
	Form.ResultModified = ResultModified;
	
	Form.Modified = Form.TemplateModified Or Form.ResultModified;
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillFillingResultInformationText(Form)
	
	InformationText = "";
	InformationPicture = New Picture;
	CanFillByTemplate = False;
	If Form.ManualEditing Then
		InformationText = NStr("ru = 'График работы на текущий год изменен вручную. 
                                    |Нажмите ""Заполнить по шаблону"" чтобы вернуться к автоматическому заполнению.'; 
                                    |en = 'Work schedule for the current year is changed manually. 
                                    |Click ""Fill in by template"" to return to automatic filling.'; 
                                    |pl = 'Harmonogram pracy bieżącego roku jest zmieniany ręcznie.
                                    |Kliknij ""Wypełnij według szablonu"", aby powrócić do automatycznego wypełniania.';
                                    |es_ES = 'El horario de trabajo de este año ha sido cambiado manualmente.
                                    |Pulse ""Rellenar según el modelo"" para volver al relleno automático.';
                                    |es_CO = 'El horario de trabajo de este año ha sido cambiado manualmente.
                                    |Pulse ""Rellenar según el modelo"" para volver al relleno automático.';
                                    |tr = 'Çalışma programın, iş günü takvimine göre kullanıcı tanımlı özel durumları vardır. 
                                    |""Varsayılan Geri Yükle"" düğmesine basarak varsayılan değerleri geri yükleyebilirsiniz.';
                                    |it = 'La pianificazione del lavoro per l''anno corrente è modificata manualmente.
                                    |Premi ""Compila attraverso template"" per restituire compilazione automatica.';
                                    |de = 'Der Arbeitszeitplan für das aktuelle Jahr wurde manuell geändert.
                                    |Drücken Sie ""Ausfüllen aus der Vorlage"", um zum automatischen Ausfüllen zurückzukehren.'");
		InformationPicture = PictureLib.Warning;
		CanFillByTemplate = True;
	Else
		If Form.ResultFilledByTemplate Then
			If ValueIsFilled(Form.Object.BusinessCalendar) Then
				InformationText = NStr("ru = 'График работы автоматически обновляется при изменении производственного календаря за текущий год.'; en = 'The work schedule is updated automatically upon changing the business calendar for the current year.'; pl = 'Harmonogram pracy jest aktualizowany przy zmianie wymiaru czasu pracy na bieżący rok.';es_ES = 'El horario de trabajo se ha actualizado según el calendario de días laborales.';es_CO = 'El horario de trabajo se ha actualizado según el calendario de días laborales.';tr = 'Mevcut yıl için iş takvimi değiştiğinde çalışma programı otomatik olarak güncellenir.';it = 'La pianificazione del lavoro è aggiornata automaticamente a seguito della modifica del calendario aziendale per l''anno corrente.';de = 'Der Arbeitszeitplan wird entsprechend dem Arbeitstage-Kalender aktualisiert.'");
				InformationPicture = PictureLib.Information;
			EndIf;
		Else
			InformationText = NStr("ru = 'Отображаемый результат не соответствует настройке шаблона. 
                                        |Нажмите ""Заполнить по шаблону"", чтобы увидеть как выглядит график работы с учетом изменений шаблона.'; 
                                        |en = 'The displayed result does not match the template setting.
                                        |Click ""Fill in by template"" to see how the work schedule looks like considering template changes.'; 
                                        |pl = 'Odzwierciedlany rezultat nie odpowiada ustawieniom szablonu. 
                                        |Naciśnij ""Wypełnij według szablonu"", aby zobaczyć jak wygląda harmonogram pracy z uwzględnieniem zmian wprowadzonych do szablonu.';
                                        |es_ES = 'El resultado mostrado no corresponde al ajuste del modelo. 
                                        |Pulse ""Rellenar según el modelo"" para ver como es el horario con los cambios del modelo.';
                                        |es_CO = 'El resultado mostrado no corresponde al ajuste del modelo. 
                                        |Pulse ""Rellenar según el modelo"" para ver como es el horario con los cambios del modelo.';
                                        |tr = 'Görüntülenen sonuç şablon ayarıyla eşleşmiyor. 
                                        |Şablon değişiklikleri göz önüne alındığında çalışma grafiğinin nasıl göründüğünü görmek için ""Şablona göre Doldur"" ''u tıklayın.';
                                        |it = 'Il risultato mostrato non corrisponde alle impostazioni del modello.
                                        |Cliccare su ""Compilare da modello"" per vedere come appare il grafico di lavoro in base alle modifiche al modello.';
                                        |de = 'Das angezeigte Ergebnis stimmt nicht mit der Vorlageneinstellung überein.
                                        |Klicken Sie auf ""Ausfüllen aus der Vorlage"", um zu sehen, wie der Arbeitszeitplan unter Berücksichtigung der Änderungen in der Vorlage aussieht.'");
			InformationPicture = PictureLib.Warning;
			CanFillByTemplate = True;
		EndIf;
	EndIf;
	
	Form.FillingResultInformationText = InformationText;
	Form.Items.FillingResultDecoration.Picture = InformationPicture;
	Form.Items.FillFromTemplate.Enabled = CanFillByTemplate;
	
	FillInformationTextManualEditing(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillInformationTextManualEditing(Form)
	
	InformationText = "";
	InformationPicture = New Picture;
	If Form.ManualEditing Then
		InformationPicture = PictureLib.Warning;
		InformationText = NStr("ru = 'График работы на текущий год изменен вручную. Изменения выделены в результатах заполнения.'; en = 'Work schedule for the current year is changed manually. Changes are highlighted in filling results.'; pl = 'Harmonogram pracy na bieżący rok ma zdefiniowane jest zmieniany ręcznie. Zmiany są wyróżniane w wynikach wypełniania.';es_ES = 'El horario de trabajo tiene excepciones definidas por el usuario en cuanto al calendario de días laborales. Revisar el resultado para ver estas excepciones (marcadas en gris).';es_CO = 'El horario de trabajo tiene excepciones definidas por el usuario en cuanto al calendario de días laborales. Revisar el resultado para ver estas excepciones (marcadas en gris).';tr = 'Çalışma programın, iş günü takvimine göre kullanıcı tanımlı özel durumları vardır. Bu özel durumları görmek için sonucu kontrol edin (gri olarak vurgulanır).';it = 'La pianificazione del lavoro per l''anno corrente è modificata manualmente. Le modifiche sono evidenziate nella compilazione risultati.';de = 'Der Arbeitszeitplan hat benutzerdefinierte Ausnahmen relativ zum Arbeitstage-Kalender. Überprüfen Sie das Ergebnis, um diese Ausnahmen anzuzeigen (grau hervorgehoben).'");
	EndIf;
	
	Form.ManualEditingInformationText = InformationText;
	Form.Items.ManualEditingDecoration.Picture = InformationPicture;
	
EndProcedure

&AtServer
Procedure SetCalendarField()
	
	If CurrentYearNumber = 0 Then
		CurrentYearNumber = Year(CurrentSessionDate());
	EndIf;
	PreviousYearNumber = CurrentYearNumber;
	
	WorkSchedule = Date(CurrentYearNumber, 1, 1);
	Items.WorkSchedule.BeginOfRepresentationPeriod	= Date(CurrentYearNumber, 1, 1);
	Items.WorkSchedule.EndOfRepresentationPeriod	= Date(CurrentYearNumber, 12, 31);
		
EndProcedure

&AtClient
Procedure CurrentYearNumberOnChangeCompletion(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		WriteScheduleData = True;
	EndIf;
	
	ProcessYearChange(WriteScheduleData);
	SetRemoveResultModified(ThisObject, False);
	Items.WorkSchedule.Refresh();
	
EndProcedure

&AtClient
Procedure ClarifyStartingDate()
	
	If Object.StartingDate < Date(1900, 1, 1) Then
		Object.StartingDate = BegOfYear(CommonClient.SessionDate());
	EndIf;
	
EndProcedure

#EndRegion
