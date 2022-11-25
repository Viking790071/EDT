#Region Public

// Returns the annual schedule for the event as of the specified date.
//
// Parameters:
//  EventDate - Date - an arbitrary date.
//
// Returns:
//  JobSchedule - a schedule.
//
Function AnnualSchedule(EventDate) Export
	Months = New Array;
	Months.Add(Month(EventDate));
	DayInMonth = Day(EventDate);
	
	Schedule = New JobSchedule;
	Schedule.DaysRepeatPeriod = 1;
	Schedule.WeeksPeriod = 1;
	Schedule.Months = Months;
	Schedule.DayInMonth = DayInMonth;
	Schedule.BeginTime = '000101010000' + (EventDate - BegOfDay(EventDate));
	
	Return Schedule;
EndFunction

#EndRegion

#Region Private

// Returns an array of text presentations of standard time intervals.
Function GetStandardNotificationIntervals() Export
	
	Result = New Array;
	Result.Add(NStr("ru = '5 минут'; en = '5 minutes'; pl = '5 minut';es_ES = '5 minutos';es_CO = '5 minutos';tr = '5 dakika';it = '5 minuti';de = '5 Minuten'"));
	Result.Add(NStr("ru = '10 минут'; en = '10 minutes'; pl = '10 minut';es_ES = '10 minutos';es_CO = '10 minutos';tr = '10 dakika';it = '10 minuti';de = '10 Minuten'"));
	Result.Add(NStr("ru = '15 минут'; en = '15 minutes'; pl = '15 minut';es_ES = '15 minutos';es_CO = '15 minutos';tr = '15 dakika';it = '15 minuti';de = '15 Minuten'"));
	Result.Add(NStr("ru = '30 минут'; en = '30 minutes'; pl = '30 minut';es_ES = '30 minutos';es_CO = '30 minutos';tr = '30 dakika';it = '30 minuti';de = '30 Minuten'"));
	Result.Add(NStr("ru = '1 час'; en = '1 hour'; pl = '1 godzina';es_ES = '1 hora';es_CO = '1 hora';tr = '1 saat';it = '1 ora';de = '1 Stunde'"));
	Result.Add(NStr("ru = '2 часа'; en = '2 hours'; pl = '2 godziny';es_ES = '2 horas';es_CO = '2 horas';tr = '2 saat';it = '2 ore';de = '2 Stunden'"));
	Result.Add(NStr("ru = '4 часа'; en = '4 hours'; pl = '4 godziny';es_ES = '4 horas';es_CO = '4 horas';tr = '4 saat';it = '4 ore';de = '4 Stunden'"));
	Result.Add(NStr("ru = '8 часов'; en = '8 hours'; pl = '8 godzin';es_ES = '8 horas';es_CO = '8 horas';tr = '8 saat';it = '8 ore';de = '8 Stunden'"));
	Result.Add(NStr("ru = '1 день'; en = '1 day'; pl = '1 dzień';es_ES = '1 día';es_CO = '1 día';tr = '1 gün';it = '1 giorno';de = '1 Tag'"));
	Result.Add(NStr("ru = '2 дня'; en = '2 days'; pl = '2 dni';es_ES = '2 días';es_CO = '2 días';tr = '2 gün';it = '2 giorni';de = '2 Tage'"));
	Result.Add(NStr("ru = '3 дня'; en = '3 days'; pl = '3 dni';es_ES = '3 días';es_CO = '3 días';tr = '3 gün';it = '3 giorni';de = '3 Tage'"));
	Result.Add(NStr("ru = '1 неделю'; en = '1 week'; pl = '1 tydzień';es_ES = '1 semana';es_CO = '1 semana';tr = '1 hafta';it = '1 settimana';de = '1 Woche'"));
	Result.Add(NStr("ru = '2 недели'; en = '2 weeks'; pl = '2 tygodnie';es_ES = '2 semanas';es_CO = '2 semanas';tr = '2 hafta';it = '2 settimane';de = '2 Wochen'"));
	
	Return Result;
	
EndFunction

// Returns a text presentation of a time interval specified in seconds.
//
// Parameters:
//
//  Time - Number - a time interval in seconds.
//
//  FullPresentation	- Boolean - a short or full time presentation.
//		For example, interval of 1,000,000 seconds:
//		- Full presentation:  11 days 13 hours 46 minutes 40 seconds.
//		- Short presentation: 11 days 13 hours.
//
// Returns:
//   String - a time period presentation.
//
Function TimePresentation(Val Time, FullPresentation = True, OutputSeconds = True) Export
	Result = "";
	
	// Presentation of time units of measure in Accusative for quantities: 1, 2-4, 5-20.
	WeeksPresentation = NStr("ru = ';%1 неделю;;%1 недели;%1 недель;%1 недели'; en = ';%1 week;;%1 weeks;%1 weeks;%1 weeks'; pl = ';%1 tydzień;;%1 tygodnie;%1 tygodnie;%1 tygodnia';es_ES = ';%1 semana;;%1 semanas;%1 semanas;%1 semanas';es_CO = ';%1 semana;;%1 semanas;%1 semanas;%1 semanas';tr = ';%1 hafta;;%1 hafta;%1 hafta;%1 hafta';it = ';%1 settimana;;%1 settimane;%1 settimane;%1 settimane';de = ';%1 Woche;;%1 Wochen;%1 Wochen;%1 Wochen'");
	DaysPresentation   = NStr("ru = ';%1 день;;%1 дня;%1 дней;%1 дня'; en = ';%1 day;;%1 days;%1 days;%1 days'; pl = ';%1 dzień;;%1 dnia;%1 dni;%1 dnia';es_ES = ';%1 día;;%1 días;%1 días;%1 días';es_CO = ';%1 día;;%1 días;%1 días;%1 días';tr = ';%1 gün;;%1 gün;%1 gün;%1 gün';it = ';%1 giorno;%1 giorni;%1 giorni;%1 giorni';de = ';%1 Tag;;%1 Tage;%1 Tage;%1 Tage'");
	HoursPresentation  = NStr("ru = ';%1 час;;%1 часа;%1 часов;%1 часа'; en = ';%1 hour;;%1 hours;%1 hours;%1 hours'; pl = ';%1 godzina;;%1 godziny;%1 godzin;%1 godzin';es_ES = ';%1 hora;;%1 horas;%1 horas;%1 horas';es_CO = ';%1 hora;;%1 horas;%1 horas;%1 horas';tr = ';%1 saat;;%1 saat;%1 saat;%1 saat';it = ';%1 ora;;%1 ore;%1 ore;%1 ore';de = ';%1 Stunde;;%1 Stunden;%1 Stunden;%1 Stunden'");
	MinutesPresentation  = NStr("ru = ';%1 минуту;;%1 минуты;%1 минут;%1 минуты'; en = ';%1 minute;;%1 minutes;%1 minutes;%1 minutes'; pl = ';%1 minutę;;%1 minuty;%1 minut;%1 minuty';es_ES = ';%1 minuto;;%1 minutos;%1 minutos;%1 minutos';es_CO = ';%1 minuto;;%1 minutos;%1 minutos;%1 minutos';tr = ';%1 dakika;;%1 dakika;%1 dakika;%1 dakika';it = ';%1 minuto;;%1 minuti;%1 minuti;%1 minuti';de = ';%1 Minute;;%1 Minuten;%1 Minuten;%1 Minuten'");
	SecondsPresentation = NStr("ru = ';%1 секунду;;%1 секунды;%1 секунд;%1 секунды'; en = ';%1 second;;%1 seconds;%1 seconds;%1 seconds'; pl = ';%1 sekundę;;%1 sekundy;%1 sekund;%1 sekundy';es_ES = ';%1 segundo;;%1 segundos;%1 segundos;%1 segundos';es_CO = ';%1 segundo;;%1 segundos;%1 segundos;%1 segundos';tr = ';%1 saniye;;%1 saniye;%1 saniye;%1 saniye';it = ';%1 secondo;;%1 secondi;%1 secondi;%1 secondi';de = ';%1 Sekunde;;%1 Sekunden;%1 Sekunden;%1 Sekunden'");
	
	Time = Number(Time);
	
	If Time < 0 Then
		Time = -Time;
	EndIf;
	
	WeeksCount = Int(Time / 60/60/24/7);
	DaysCount   = Int(Time / 60/60/24);
	HoursCount  = Int(Time / 60/60);
	MinutesCount  = Int(Time / 60);
	SecondsCount = Int(Time);
	
	SecondsCount = SecondsCount - MinutesCount * 60;
	MinutesCount  = MinutesCount - HoursCount * 60;
	HoursCount  = HoursCount - DaysCount * 24;
	DaysCount   = DaysCount - WeeksCount * 7;
	
	If Not OutputSeconds Then
		SecondsCount = 0;
	EndIf;
	
	If WeeksCount > 0 AND DaysCount+HoursCount+MinutesCount+SecondsCount=0 Then
		Result = StringFunctionsClientServer.StringWithNumberForAnyLanguage(WeeksPresentation, WeeksCount);
	Else
		DaysCount = DaysCount + WeeksCount * 7;
		
		Counter = 0;
		If DaysCount > 0 Then
			Result = Result + StringFunctionsClientServer.StringWithNumberForAnyLanguage(DaysPresentation, DaysCount) + " ";
			Counter = Counter + 1;
		EndIf;
		
		If HoursCount > 0 Then
			Result = Result + StringFunctionsClientServer.StringWithNumberForAnyLanguage(HoursPresentation, HoursCount) + " ";
			Counter = Counter + 1;
		EndIf;
		
		If (FullPresentation Or Counter < 2) AND MinutesCount > 0 Then
			Result = Result + StringFunctionsClientServer.StringWithNumberForAnyLanguage(MinutesPresentation, MinutesCount) + " ";
			Counter = Counter + 1;
		EndIf;
		
		If (FullPresentation Or Counter < 2) AND (SecondsCount > 0 Or WeeksCount+DaysCount+HoursCount+MinutesCount = 0) Then
			Result = Result + StringFunctionsClientServer.StringWithNumberForAnyLanguage(SecondsPresentation, SecondsCount);
		EndIf;
		
	EndIf;
	
	Return TrimR(Result);
	
EndFunction

// Gets a time interval in seconds from text details.
//
// Parameters:
//  StringWithTime - String - text details of time, where numbers are written in digits and units of 
//								measure are written as a string.
//
// Returns
//  Number - a time interval in seconds.
Function GetTimeIntervalFromString(Val StringWithTime) Export
	
	If IsBlankString(StringWithTime) Then
		Return 0;
	EndIf;
	
	StringWithTime = Lower(StringWithTime);
	StringWithTime = StrReplace(StringWithTime, Chars.NBSp," ");
	StringWithTime = StrReplace(StringWithTime, ".",",");
	StringWithTime = StrReplace(StringWithTime, "+","");
	
	SubstringWithDigits = "";
	SubstringWithLetters = "";
	
	PreviousCharacterIsDigit = False;
	HasFraction = False;
	HasUnitOfMeasure = False;
	
	Result = 0;
	For Position = 1 To StrLen(StringWithTime) Do
		CurrentCharCode = CharCode(StringWithTime,Position);
		Char = Mid(StringWithTime,Position,1);
		If (CurrentCharCode >= CharCode("0") AND CurrentCharCode <= CharCode("9"))
			OR (Char="," AND PreviousCharacterIsDigit AND Not HasFraction) Then
			If Not IsBlankString(SubstringWithLetters) Then
				SubstringWithDigits = StrReplace(SubstringWithDigits,",",".");
				Result = Result + ?(IsBlankString(SubstringWithDigits), 1, Number(SubstringWithDigits))
					* ReplaceUnitOfMeasureByMultiplier(SubstringWithLetters);
					
				SubstringWithDigits = "";
				SubstringWithLetters = "";
				
				PreviousCharacterIsDigit = False;
				HasFraction = False;
				HasUnitOfMeasure = False;
			EndIf;
			
			SubstringWithDigits = SubstringWithDigits + Mid(StringWithTime,Position,1);
			
			PreviousCharacterIsDigit = True;
			If Char = "," Then
				HasFraction = True;
			EndIf;
		Else
			If Char = " " AND ReplaceUnitOfMeasureByMultiplier(SubstringWithLetters)="0" Then
				SubstringWithLetters = "";
			EndIf;
			
			SubstringWithLetters = SubstringWithLetters + Mid(StringWithTime,Position,1);
			PreviousCharacterIsDigit = False;
		EndIf;
	EndDo;
	
	If Not IsBlankString(SubstringWithLetters) Then
		SubstringWithDigits = StrReplace(SubstringWithDigits,",",".");
		Result = Result + ?(IsBlankString(SubstringWithDigits), 1, Number(SubstringWithDigits))
			* ReplaceUnitOfMeasureByMultiplier(SubstringWithLetters);
	EndIf;
	
	Return Result;
	
EndFunction

// Analyzes the word for compliance with the time unit of measure and if it complies, the function 
// returns the number of seconds contained in the time unit of measure.
//
// Parameters:
//  Unit - String - a word being analyzed.
//
// Returns
//  Number - a number of seconds in the Unit. If the unit is undefined or blank, 0 returns.
Function ReplaceUnitOfMeasureByMultiplier(Val Unit)
	
	Result = 0;
	Unit = Lower(Unit);
	
	AllowedChars = NStr("ru = 'абвгдеёжзийклмнопрстуфхцчшщъыьэюя'; en = 'abcdefghijklmnopqrstuvwxyz'; pl = 'abcdefghijklmnopqrstuvwxyz';es_ES = 'abcdefghijklmnopqrstuvwxyz';es_CO = 'abcdefghijklmnopqrstuvwxyz';tr = 'abcdefghijklmnopqrstuvwxyz';it = 'abcdefghijklmnopqrstuvwxyz';de = 'abcdefghijklmnopqrstuvwxyz'");
	ProhibitedChars = StrConcat(StrSplit(Unit, AllowedChars, False), "");
	If ProhibitedChars <> "" Then
		Unit = StrConcat(StrSplit(Unit, ProhibitedChars, False), "");
	EndIf;
	
	WordFormsForWeek = StrSplit(NStr("ru = 'нед,н'; en = 'wee,w'; pl = 'maleńki,m';es_ES = 'wee,w';es_CO = 'wee,w';tr = 'wee,w';it = 'set,w';de = 'wee,w'"), ",", False);
	WordFormsForDay = StrSplit(NStr("ru = 'ден,дне,дня,дн,д'; en = 'day,day,day,day,d'; pl = 'dzień,dzień,dzień,dzień,d';es_ES = 'day,day,day,day,d';es_CO = 'day,day,day,day,d';tr = 'gün,gün,gün,gün,g';it = 'giorno, giorno, giorno, giorno, g';de = 'Tag,Tag,Tag,Tag,d'"), ",", False);
	WordFormsForHour = StrSplit(NStr("ru = 'час,ч'; en = 'hou,h'; pl = 'godz,g';es_ES = 'hou,h';es_CO = 'hou,h';tr = 'hou(saat),h';it = 'ore,h';de = 'hou,h'"), ",", False);
	WordFormsForMinute = StrSplit(NStr("ru = 'мин,м'; en = 'min,m'; pl = 'min,m';es_ES = 'min,m';es_CO = 'min,m';tr = 'min (dakika),m';it = 'min,m';de = 'min,m'"), ",", False);
	WordFormsForSecond = StrSplit(NStr("ru = 'сек,с'; en = 'sec,s'; pl = 'sek,s';es_ES = 'sec,s';es_CO = 'sec,s';tr = 'sec(saniye),s';it = 'sec,s';de = 'sec,s'"), ",", False);
	
	FirstThreeChars = Left(Unit,3);
	If WordFormsForWeek.Find(FirstThreeChars) <> Undefined Then
		Result = 60*60*24*7;
	ElsIf WordFormsForDay.Find(FirstThreeChars) <> Undefined Then
		Result = 60*60*24;
	ElsIf WordFormsForHour.Find(FirstThreeChars) <> Undefined Then
		Result = 60*60;
	ElsIf WordFormsForMinute.Find(FirstThreeChars) <> Undefined Then
		Result = 60;
	ElsIf WordFormsForSecond.Find(FirstThreeChars) <> Undefined Then
		Result = 1;
	EndIf;
	
	Return Format(Result,"NZ=0; NG=0");
	
EndFunction

// Gets a time interval from a string and returns its text presentation.
//
// Parameters:
//  TimeAsString - String - text details of time, where numbers are written in digits and units of 
//							measure are written as a string.
//
// Returns
//  String - an arranged time presentation.
Function ApplyAppearanceTime(TimeAsString) Export
	Return TimePresentation(GetTimeIntervalFromString(TimeAsString));
EndFunction

// Returns the reminder structure with filled values.
//
// Parameters:
//  DataToFill - Structure - values used to fill reminder parameters.
//  AllAttributes - Boolean - if true, the function also returns attributes related to reminder time 
//                          settings.
Function ReminderDetails(DataToFill = Undefined, AllAttributes = False) Export
	Result = New Structure("User,EventTime,Source,ReminderTime,Details,ID");
	If AllAttributes Then 
		Result.Insert("ReminderTimeSettingMethod");
		Result.Insert("ReminderInterval", 0);
		Result.Insert("SourceAttributeName");
		Result.Insert("Schedule");
		Result.Insert("PictureIndex", 2);
		Result.Insert("RepeatAnnually", False);
	EndIf;
	If DataToFill <> Undefined Then
		FillPropertyValues(Result, DataToFill);
	EndIf;
	Return Result;
EndFunction

#EndRegion
