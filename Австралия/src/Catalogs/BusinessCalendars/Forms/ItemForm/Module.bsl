
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		FillWithCurrentYearData(Parameters.CopyingValue);
		SetBasicCalendarFieldProperties(ThisObject);
	EndIf;
	
	DaysKindsColors = New FixedMap(Catalogs.BusinessCalendars.BusinessCalendarDayKindsAppearanceColors());
	
	DayKindsList = Catalogs.BusinessCalendars.DayKindsList();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If Common.SubsystemExists("CloudTechnology.SaaS.DataExchangeSaaS") Then
		ModuleStandaloneMode = Common.CommonModule("StandaloneMode");
		ModuleStandaloneMode.ObjectOnReadAtServer(CurrentObject, ThisObject.ReadOnly);
	EndIf;
	
	FillWithCurrentYearData();
	
	SetBasicCalendarVisibility();
	
	HasBasicCalendar = ValueIsFilled(Object.BasicCalendar);
	SetBasicCalendarFieldProperties(ThisObject);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.SelectDate") Then
		If SelectedValue = Undefined Then
			Return;
		EndIf;
		SelectedDates = Items.Calendar.SelectedDates;
		If SelectedDates.Count() = 0 Or Year(SelectedDates[0]) <> CurrentYearNumber Then
			Return;
		EndIf;
		ReplacementDate = SelectedDates[0];
		ShiftDayKind(ReplacementDate, SelectedValue);
		Items.Calendar.Refresh();
	EndIf;
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If HasBasicCalendar AND Not ValueIsFilled(Object.BasicCalendar) Then
		MessageText = NStr("ru = 'Федеральный календарь не заполнен.'; en = 'Federal calendar is not filled in.'; pl = 'Nie wypełniono kalendarza krajowego.';es_ES = 'Calendario federal no rellenado.';es_CO = 'Calendario federal no rellenado.';tr = 'Ulusal takvim doldurulmadı.';it = 'Il calendario nazionale non è compilato.';de = 'Der Bundeskalender ist nicht ausgefüllt.'");
		CommonClientServer.MessageToUser(MessageText, , , "Object.BasicCalendar", Cancel);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Var YearNumber;
	
	If Not WriteParameters.Property("YearNumber", YearNumber) Then
		YearNumber = CurrentYearNumber;
	EndIf;
	
	WriteBusinessCalendarData(YearNumber, CurrentObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CurrentYearNumberOnChange(Item)
	
	WriteScheduleData = False;
	If Modified Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Записать измененные данные за %1 год?'; en = 'Do you want to write changed data for year %1?'; pl = 'Zapisać zmienione dane za %1 rok?';es_ES = '¿Inscribir los datos cambiados para el año de %1?';es_CO = '¿Inscribir los datos cambiados para el año de %1?';tr = '%1 yılı için değiştirilmiş veriler yazılsın mı?';it = 'Volete scrivere i dati modificati per l''anno %1?';de = 'Schreiben Sie die geänderten Daten für das Jahr %1?'"), Format(PreviousYearNumber, "NG=0"));
		Notification = New NotifyDescription("CurrentYearNumberOnChangeCompletion", ThisObject);
		ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo);
		Return;
	EndIf;
	
	ProcessYearChange(WriteScheduleData);
	
	Modified = False;
	
	Items.Calendar.Refresh();
	
EndProcedure

&AtClient
Procedure CalendarOnPeriodOutput(Item, PeriodAppearance)
	
	For Each PeriodAppearanceString In PeriodAppearance.Dates Do
		DayAppearanceColor = DaysKindsColors.Get(DaysKinds.Get(PeriodAppearanceString.Date));
		If DayAppearanceColor = Undefined Then
			DayAppearanceColor = CommonClient.StyleColor("BusinessCalendarDayKindColorNotSpecified");
		EndIf;
		PeriodAppearanceString.TextColor = DayAppearanceColor;
	EndDo;
	
EndProcedure

&AtClient
Procedure HasBasicCalendarOnChange(Item)
	
	SetBasicCalendarFieldProperties(ThisObject);
	
	If Not HasBasicCalendar Then
		Object.BasicCalendar = Undefined;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ChangeDay(Command)
	
	SelectedDates = Items.Calendar.SelectedDates;
	
	If SelectedDates.Count() > 0 AND Year(SelectedDates[0]) = CurrentYearNumber Then
		Notification = New NotifyDescription("ChangeDayCompletion", ThisObject, SelectedDates);
		ShowChooseFromList(Notification, DayKindsList, , DayKindsList.FindByValue(DaysKinds.Get(SelectedDates[0])));
	EndIf;
	
EndProcedure

&AtClient
Procedure ShiftDay(Command)
	
	SelectedDates = Items.Calendar.SelectedDates;
	
	If SelectedDates.Count() = 0 Or Year(SelectedDates[0]) <> CurrentYearNumber Then
		Return;
	EndIf;
		
	ReplacementDate = SelectedDates[0];
	DayKind = DaysKinds.Get(ReplacementDate);
	
	DateSelectionParameters = New Structure(
		"InitialValue, 
		|BeginOfRepresentationPeriod, 
		|EndOfRepresentationPeriod, 
		|Title, 
		|NoteText");
		
	DateSelectionParameters.InitialValue = ReplacementDate;
	DateSelectionParameters.BeginOfRepresentationPeriod = BegOfYear(Calendar);
	DateSelectionParameters.EndOfRepresentationPeriod = EndOfYear(Calendar);
	DateSelectionParameters.Title = NStr("ru = 'Выбор даты переноса'; en = 'Select replacement date'; pl = 'Wybierz datę przeniesienia';es_ES = 'Seleccionar los datos de traslado';es_CO = 'Seleccionar los datos de traslado';tr = 'Hedef tarihi seçin';it = 'Selezionare la data di sostituzione';de = 'Wählen Sie die Übertragungsdaten aus'");
	
	MessageText = NStr("ru = 'Выберите дату, на которую будет осуществлен перенос дня %1 (%2)'; en = 'Select a date that replaces %1 (%2)'; pl = 'Wybierz datę, na którą zostanie przeniesiony termin %1 (%2)';es_ES = 'Seleccione una fecha que se trasladará a %1 (%2)';es_CO = 'Seleccionar una fecha un día %1 se trasladará a (%2)';tr = '%1 yerine geçecek tarihi seçin (%2)';it = 'Selezionare una data che sostituisce %1 (%2)';de = 'Wählen Sie einen Tagesdatum %1 aus, an das (%2) übertragen werden soll'");
	DateSelectionParameters.NoteText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, Format(ReplacementDate, "DF='d MMMM'"), DayKind);
	
	OpenForm("CommonForm.SelectDate", DateSelectionParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure FillByDefault(Command)
	
	FillWithDefaultData();
	
	Items.Calendar.Refresh();
	
EndProcedure

&AtClient
Procedure Print(Command)
	
	If Object.Ref.IsEmpty() Then
		Handler = New NotifyDescription("PrintCompletion", ThisObject);
		ShowQueryBox(
			Handler,
			NStr("ru = 'Данные производственного календаря еще не записаны.
                  |Печать возможна только после записи данных.
                  |
                  |Записать?'; 
                  |en = 'Business calendar data is not written yet.
                  |You can print it only after the data is written.
                  |
                  |Write it?'; 
                  |pl = 'Dane kalendarza firmowego nie zostały jeszcze zapisane.
                  |Można je wydrukować dopiero po zapisaniu danych.
                  |
                  |Zapisać?';
                  |es_ES = 'Datos del calendario de negocio aún no se han inscrito.
                  |Puede imprimirlo solo después de haber grabado los datos.
                  |
                  |¿Grabar?';
                  |es_CO = 'Datos del calendario de negocio aún no se han inscrito.
                  |Puede imprimirlo solo después de haber grabado los datos.
                  |
                  |¿Grabar?';
                  |tr = 'İş takvimi verileri henüz yazılmadı. 
                  |Sadece veri kaydettikten sonra yazdırabilirsiniz. 
                  |
                  |Kayıt?';
                  |it = 'I dati del calendario aziendale non sono ancora stati registrati.
                  |Potete stampare solo dopo che i dati sono stati registrati.
                  |
                  |Effettuare la registrazione?';
                  |de = 'Die Geschäftskalenderdaten sind noch nicht geschrieben.
                  |Sie können sie nur nach Datenaufzeichnung drucken.
                  |
                  |Aufzeichnend?'"),
			QuestionDialogMode.YesNo,
			,
			DialogReturnCode.Yes);
		Return;
	EndIf;
	
	PrintCompletion(-1);
		
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillWithCurrentYearData(CopyingValue = Undefined)
	
	// Fills in the form with data of the current year.
	
	SetCalendarField();
	
	RefToCalendar = Object.Ref;
	If ValueIsFilled(CopyingValue) Then
		RefToCalendar = CopyingValue;
		Object.Description = Undefined;
		Object.Code = Undefined;
	EndIf;
	
	ReadBusinessCalendarData(RefToCalendar, CurrentYearNumber);
		
EndProcedure

&AtServer
Procedure ReadBusinessCalendarData(BusinessCalendar, YearNumber)
	
	// Importing business calendar data for the specified year.
	ConvertBusinessCalendarData(
		Catalogs.BusinessCalendars.BusinessCalendarData(BusinessCalendar, YearNumber));
	
EndProcedure

&AtServer
Procedure FillWithDefaultData()
	
	DefaultData = New ValueTable;
	
	If ValueIsFilled(Object.BasicCalendar) Then
		
		DefaultData = Catalogs.BusinessCalendars.BusinessCalendarData(Object.BasicCalendar, CurrentYearNumber);
		
	EndIf;
	
	If DefaultData.Count() = 0 Then
		
		// Fills in the form with business calendar data based on information on holidays and their 
		// replacements.
		
		BasicCalendarCode = Undefined;
		If ValueIsFilled(Object.BasicCalendar) Then
			BasicCalendarCode = Common.ObjectAttributeValue(Object.BasicCalendar, "Code");
		EndIf;
		
		DefaultData = Catalogs.BusinessCalendars.BusinessCalendarDefaultFillingResult(
			Object.Code,
			CurrentYearNumber,
			BasicCalendarCode);
		
	EndIf;
	
	ConvertBusinessCalendarData(DefaultData);
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure ConvertBusinessCalendarData(BusinessCalendarData)
	
	// Business calendar data is used in the form as maps between DaysKinds and ShiftedDays.
	// 
	// The procedure fills in these maps.
	
	DaysKindsMap = New Map;
	ShiftedDaysMap = New Map;
	
	For Each TableRow In BusinessCalendarData Do
		DaysKindsMap.Insert(TableRow.Date, TableRow.DayKind);
		If ValueIsFilled(TableRow.ReplacementDate) Then
			ShiftedDaysMap.Insert(TableRow.Date, TableRow.ReplacementDate);
		EndIf;
	EndDo;
	
	DaysKinds = New FixedMap(DaysKindsMap);
	ShiftedDays = New FixedMap(ShiftedDaysMap);
	
	FillReplacementsPresentation(ThisObject);
	
EndProcedure

&AtServer
Procedure WriteBusinessCalendarData(Val YearNumber, Val CurrentObject = Undefined)
	
	// Write business calendar data for the specified year.
	
	If CurrentObject = Undefined Then
		CurrentObject = FormAttributeToValue("Object");
	EndIf;
	
	BusinessCalendarData = New ValueTable;
	BusinessCalendarData.Columns.Add("Date", New TypeDescription("Date"));
	BusinessCalendarData.Columns.Add("DayKind", New TypeDescription("EnumRef.BusinessCalendarDaysKinds"));
	BusinessCalendarData.Columns.Add("ReplacementDate", New TypeDescription("Date"));
	
	For Each KeyAndValue In DaysKinds Do
		
		TableRow = BusinessCalendarData.Add();
		TableRow.Date = KeyAndValue.Key;
		TableRow.DayKind = KeyAndValue.Value;
		
		// If the day is shifted from another date, specify the replacement date.
		ReplacementDate = ShiftedDays.Get(TableRow.Date);
		If ReplacementDate <> Undefined 
			AND ReplacementDate <> TableRow.Date Then
			TableRow.ReplacementDate = ReplacementDate;
		EndIf;
		
	EndDo;
	
	Catalogs.BusinessCalendars.WriteBusinessCalendarData(CurrentObject.Ref, YearNumber, BusinessCalendarData);
	
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
		WriteBusinessCalendarData(PreviousYearNumber);
	EndIf;
	
	FillWithCurrentYearData();	
	
EndProcedure

&AtClient
Procedure ChangeDaysKinds(DaysDates, DayKind)
	
	// Sets a particular day kind for all array dates.
	
	DaysKindsMap = New Map(DaysKinds);
	
	For Each SelectedDate In DaysDates Do
		DaysKindsMap.Insert(SelectedDate, DayKind);
	EndDo;
	
	DaysKinds = New FixedMap(DaysKindsMap);
	
EndProcedure

&AtClient
Procedure ShiftDayKind(ReplacementDate, PurposeDate)
	
	// Swap two days in the calendar
	// - Swap day kinds.
	// - Remember replacement dates.
	//	* If the day being shifted already has a replacement date (has already been moved),
	//		use the existing replacement date.
	//	* If the dates match (the day is returned to its place), delete such record.
	
	DaysKindsMap = New Map(DaysKinds);
	
	DaysKindsMap.Insert(PurposeDate, DaysKinds.Get(ReplacementDate));
	DaysKindsMap.Insert(ReplacementDate, DaysKinds.Get(PurposeDate));
	
	ShiftedDaysMap = New Map(ShiftedDays);
	
	EnterReplacementDate(ShiftedDaysMap, ReplacementDate, PurposeDate);
	EnterReplacementDate(ShiftedDaysMap, PurposeDate, ReplacementDate);
	
	DaysKinds = New FixedMap(DaysKindsMap);
	ShiftedDays = New FixedMap(ShiftedDaysMap);
	
	FillReplacementsPresentation(ThisObject);
	
EndProcedure

&AtClient
Procedure EnterReplacementDate(ShiftedDaysMap, ReplacementDate, PurposeDate)
	
	// Fills in a correct replacement date according to days replacement dates.
	
	PurposeDateDaySource = ShiftedDays.Get(PurposeDate);
	If PurposeDateDaySource = Undefined Then
		PurposeDateDaySource = PurposeDate;
	EndIf;
	
	If ReplacementDate = PurposeDateDaySource Then
		ShiftedDaysMap.Delete(ReplacementDate);
	Else	
		ShiftedDaysMap.Insert(ReplacementDate, PurposeDateDaySource);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillReplacementsPresentation(Form)
	
	// Generates a holiday replacement presentation as a value list.
	
	Form.ReplacementsList.Clear();
	For Each KeyAndValue In Form.ShiftedDays Do
		// From the applied perspective, a weekday is always replaced by a holiday, so let us select the 
		// date that previously was a holiday and now is a weekday.
		SourceDate = KeyAndValue.Key;
		DestinationDate = KeyAndValue.Value;
		DayKind = Form.DaysKinds.Get(SourceDate);
		If DayKind = PredefinedValue("Enum.BusinessCalendarDaysKinds.Saturday")
			Or DayKind = PredefinedValue("Enum.BusinessCalendarDaysKinds.Sunday") Then
			// Swap dates to show holiday replacement information as "A replaces B" instead of "B replaces A".
			ReplacementDate = DestinationDate;
			DestinationDate = SourceDate;
			SourceDate = ReplacementDate;
		EndIf;
		If Form.ReplacementsList.FindByValue(SourceDate) <> Undefined 
			Or Form.ReplacementsList.FindByValue(DestinationDate) <> Undefined Then
			// Holiday replacement is already added, skip it.
			Continue;
		EndIf;
		SourceDayKind = ShiftedDayKindPresentation(Form.DaysKinds.Get(DestinationDate), SourceDate);
		DestinationDayKind = ShiftedDayKindPresentation(Form.DaysKinds.Get(SourceDate), DestinationDate);
		Form.ReplacementsList.Add(SourceDate, ReplacementPresentation(SourceDate, DestinationDate, SourceDayKind, DestinationDayKind));
	EndDo;
	Form.ReplacementsList.SortByValue();
	
	SetReplacementsListVisibility(Form);
	
EndProcedure

&AtClientAtServerNoContext
Function ReplacementPresentation(SourceDate, DestinationDate, SourceDayKind, DestinationDayKind)
	
	Presentation = "";
	
	TemplateMale = NStr("ru = '%1 %3 перенесен на %2 %4'; en = '%1 %3 is shifted to %2 %4'; pl = '%1 %3 zostaje przeniesiony do %2 %4';es_ES = '%1 %3 se ha trasladado a %2 %4';es_CO = '%1 %3 se ha trasladado a %2 %4';tr = '%1 %3 kaydırıldı: %2 %4';it = '%1 %3 è spostato a %2 %4';de = '%1 %3 übertragen auf %2 %4'");
	TemplateNeuter = NStr("ru = '%1 %3 перенесен на %2 %4'; en = '%1 %3 is shifted to %2 %4'; pl = '%1 %3 zostaje przeniesiony do %2 %4';es_ES = '%1 %3 se ha trasladado a %2 %4';es_CO = '%1 %3 se ha trasladado a %2 %4';tr = '%1 %3 kaydırıldı: %2 %4';it = '%1 %3 è spostato a %2 %4';de = '%1 %3 übertragen auf %2 %4'");
	TemplateFemale = NStr("ru = '%1 %3 перенесен на %2 %4'; en = '%1 %3 is shifted to %2 %4'; pl = '%1 %3 zostaje przeniesiony do %2 %4';es_ES = '%1 %3 se ha trasladado a %2 %4';es_CO = '%1 %3 se ha trasladado a %2 %4';tr = '%1 %3 kaydırıldı: %2 %4';it = '%1 %3 è spostato a %2 %4';de = '%1 %3 übertragen auf %2 %4'");
	
	DaysFemale = New Map;
	DaysFemale.Insert(NStr("ru = 'Среда'; en = 'Wednesday'; pl = 'Środa';es_ES = 'Miércoles';es_CO = 'Miércoles';tr = 'Çarşamba';it = 'Mercoledì';de = 'Mittwoch'"), NStr("ru = 'Среда'; en = 'Wednesday'; pl = 'Środa';es_ES = 'Miércoles';es_CO = 'Miércoles';tr = 'Çarşamba';it = 'Mercoledì';de = 'Mittwoch'"));
	DaysFemale.Insert(NStr("ru = 'Пятница'; en = 'Friday'; pl = 'Piątek';es_ES = 'Viernes';es_CO = 'Viernes';tr = 'Cuma';it = 'Venerdì';de = 'Freitag'"), NStr("ru = 'Пятница'; en = 'Friday'; pl = 'Piątek';es_ES = 'Viernes';es_CO = 'Viernes';tr = 'Cuma';it = 'Venerdì';de = 'Freitag'"));
	DaysFemale.Insert(NStr("ru = 'Суббота'; en = 'Saturday'; pl = 'Sobota';es_ES = 'Sábado';es_CO = 'Sábado';tr = 'Cumartesi';it = 'Sabato';de = 'Samstag'"), NStr("ru = 'Суббота'; en = 'Saturday'; pl = 'Sobota';es_ES = 'Sábado';es_CO = 'Sábado';tr = 'Cumartesi';it = 'Sabato';de = 'Samstag'"));
	
	DaysNeuter = New Map;
	DaysNeuter.Insert(NStr("ru = 'воскресенье'; en = 'sunday'; pl = 'niedziela';es_ES = 'domingo';es_CO = 'domingo';tr = 'Pazar';it = 'Domenica';de = 'Sonntag'"), True);
	
	Template = TemplateMale;
	If DaysFemale[SourceDayKind] <> Undefined Then
		Template = TemplateFemale;
	EndIf;
	If DaysNeuter[SourceDayKind] <> Undefined Then
		Template = TemplateNeuter;
	EndIf;
	
	DestinationDayPresentation = DestinationDayKind;
	If DaysFemale[DestinationDayKind] <> Undefined Then
		DestinationDayPresentation = DaysFemale[DestinationDayKind];
	EndIf;
	
	Presentation = StringFunctionsClientServer.SubstituteParametersToString(
		Template, 
		Format(SourceDate, "DF='d MMMM'"), 
		Format(DestinationDate, "DF='d MMMM'"), 
		SourceDayKind, 
		DestinationDayPresentation);
	
	Return Presentation;
	
EndFunction

&AtClientAtServerNoContext
Procedure SetReplacementsListVisibility(Form)
	
	ListVisibility = Form.ReplacementsList.Count() > 0;
	CommonClientServer.SetFormItemProperty(Form.Items, "ReplacementsList", "Visible", ListVisibility);
	
EndProcedure

&AtClientAtServerNoContext
Function ShiftedDayKindPresentation(DayKind, Date)
	
	// If a day is a weekday or a holiday, display the day of the week as its presentation.
	
	If DayKind = PredefinedValue("Enum.BusinessCalendarDaysKinds.Work") 
		Or DayKind = PredefinedValue("Enum.BusinessCalendarDaysKinds.Holiday") Then
		DayKind = Format(Date, "DF='dddd'");
	EndIf;
	
	Return Lower(String(DayKind));
	
EndFunction	

&AtServer
Procedure SetCalendarField()
	
	If CurrentYearNumber = 0 Then
		CurrentYearNumber = Year(CurrentSessionDate());
	EndIf;
	PreviousYearNumber = CurrentYearNumber;
	
	Items.Calendar.BeginOfRepresentationPeriod	= Date(CurrentYearNumber, 1, 1);
	Items.Calendar.EndOfRepresentationPeriod	= Date(CurrentYearNumber, 12, 31);
		
EndProcedure

&AtClient
Procedure CurrentYearNumberOnChangeCompletion(Response, AdditionalParameters) Export
	
	ProcessYearChange(Response = DialogReturnCode.Yes);
	Modified = False;
	Items.Calendar.Refresh();
	
EndProcedure

&AtClient
Procedure ChangeDayCompletion(SelectedItem, SelectedDates) Export
	
	If SelectedItem <> Undefined Then
		ChangeDaysKinds(SelectedDates, SelectedItem.Value);
		Items.Calendar.Refresh();
	EndIf;
	
EndProcedure

&AtClient
Procedure PrintCompletion(ResponseToWriteSuggestion, ExecutionParameters = Undefined) Export
	
	If ResponseToWriteSuggestion <> -1 Then
		If ResponseToWriteSuggestion <> DialogReturnCode.Yes Then
			Return;
		EndIf;
		Written = Write();
		If Not Written Then
			Return;
		EndIf;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("BusinessCalendar", Object.Ref);
	AdditionalParameters.Insert("YearNumber", CurrentYearNumber);
	
	PrintParameters = New Structure;
	PrintParameters.Insert("AdditionalParameters", AdditionalParameters); 
	PrintParameters.Insert("ID", "BusinessCalendar");
	
	CommandParameter = New Array;
	CommandParameter.Add(Object.Ref);
	
	If CommonClient.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManagerClient = CommonClient.CommonModule("PrintManagementClient");
		ModulePrintManagerClient.ExecutePrintCommand("Catalog.BusinessCalendars", "BusinessCalendar", 
			CommandParameter, ThisObject, PrintParameters);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetBasicCalendarFieldProperties(Form)
	
	CommonClientServer.SetFormItemProperty(
		Form.Items, 
		"BasicCalendar", 
		"Enabled", 
		Form.HasBasicCalendar);
		
	CommonClientServer.SetFormItemProperty(
		Form.Items, 
		"BasicCalendar", 
		"AutoMarkIncomplete", 
		Form.HasBasicCalendar);
		
	CommonClientServer.SetFormItemProperty(
		Form.Items, 
		"BasicCalendar", 
		"MarkIncomplete", 
		Not ValueIsFilled(Form.Object.BasicCalendar));
	
EndProcedure

&AtServer
Procedure SetBasicCalendarVisibility()
	
	CalendarsTable = Catalogs.BusinessCalendars.BusinessCalendarsFromTemplate();
	If CalendarsTable.Find(TrimAll(Object.Code), "Code") <> Undefined Then
		CommonClientServer.SetFormItemProperty(Items, "BasicCalendarGroup", "Visible", False);
	EndIf;
	
EndProcedure

#EndRegion
