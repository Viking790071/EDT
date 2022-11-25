#Region Public

Function IsIntervalsIntersect(Start1, End1, Start2, End2) Export
	
	Return Max(Start1, Start2) < Min(End1, End2);
	
EndFunction

Function IsWorkingDay(DateToCheck, WorkSchedule) Export
	
	WorkingDays = Catalogs.Calendars.ReadScheduleDataFromRegister(WorkSchedule, Year(DateToCheck));
	If WorkingDays.Get(BegOfDay(DateToCheck)) <> Undefined Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

Function GetPeriodEndDateSec(WorkSchedule, Val StartDate, DurationSec = 0) Export
	
	EndDate = StartDate;
	
	If DurationSec > 0 Then
		
		Duration = DurationSec;
		
		PeriodStart = StartDate;
		PeriodEnd = PeriodStart + 10*24*3600;
		
		WorkTimeTable = GenerateWorkTimeTable(WorkSchedule, PeriodStart, PeriodEnd);
		While WorkTimeTable.Count() < 2 Do
			PeriodEnd = PeriodEnd + 10*24*3600;
			WorkTimeTable = GenerateWorkTimeTable(WorkSchedule, PeriodStart, PeriodEnd);
		EndDo;
		
		EndDate = WorkTimeTable[0].StartDate;
		
		While Duration > 0 Do
			
			For Indx = 0 По WorkTimeTable.Count()-2 Do
				Row = WorkTimeTable[Indx];
				If Row.Duration = Duration Then
					EndDate = Row.EndDate;
					Duration = 0;
					Break;
				ElsIf Row.Duration < Duration Then
					EndDate = WorkTimeTable[Indx+1].StartDate;
					Duration = Duration - Row.Duration;
				Else
					EndDate = EndDate + Duration;
					Duration = 0;
					Break;
				EndIf;
			EndDo;
			
			If Duration > 0 Then  
				PeriodStart = EndDate;
				PeriodEnd = PeriodStart + 10*24*3600;
				
				WorkTimeTable = GenerateWorkTimeTable(WorkSchedule, PeriodStart, PeriodEnd);
				While WorkTimeTable.Count() < 2 Do
					PeriodEnd = PeriodEnd + 10*24*3600;
					WorkTimeTable = GenerateWorkTimeTable(WorkSchedule, PeriodStart, PeriodEnd);
				EndDo;
			EndIf;
			
		EndDo;
		
	EndIf;
	
	Return EndDate;
	
EndFunction

Function GetPeriodDurationSec(WorkSchedule, StartDate, EndDate, WorkTimeTable = Undefined) Export
	
	If WorkTimeTable = Undefined Then
		Table = GenerateWorkTimeTable(WorkSchedule, StartDate, EndDate);
	Else
		Table = WorkTimeTable;
	EndIf;
	
	Duration = 0;
	For Each Row In Table Do
		
		If StartDate > Row.StartDate And StartDate > Row.EndDate Then
			Continue;
		ElsIf EndDate < Row.StartDate And EndDate < Row.EndDate Then
			Continue;
		ElsIf StartDate >= Row.StartDate And StartDate <= Row.EndDate Then
			Duration = Duration + (Row.EndDate - StartDate);
		ElsIf EndDate >= Row.StartDate And EndDate <= Row.EndDate Then
			Duration = Duration + (EndDate - Row.StartDate);
		Else
			Duration = Duration + (Row.EndDate - Row.StartDate);
		EndIf;
		
	EndDo;
	
	Return Duration;
	
EndFunction

Function GetPeriodStartDateSec(WorkSchedule, EndDate, DurationSec) Export
	
	Duration = DurationSec;
	
	PeriodEnd = EndDate;
	PeriodStart = PeriodEnd - 10*24*3600;
	
	WorkTimeTable = GenerateWorkTimeTable(WorkSchedule, PeriodStart, PeriodEnd);
	While WorkTimeTable.Count() < 2 Do
		PeriodStart = PeriodStart - 10*24*3600;
		WorkTimeTable = GenerateWorkTimeTable(WorkSchedule, PeriodStart, PeriodEnd);
	EndDo;
	
	UBound = WorkTimeTable.Count() - 1;
	
	StartDate = WorkTimeTable[UBound].EndDate;
	
	While Duration > 0 Do
		
		For Indx = 0 По WorkTimeTable.Count()-2 Do
			
			Row = WorkTimeTable[UBound - Indx];
			
			If Row.Duration = Duration Then 
				StartDate = Row.StartDate;
				Duration = 0;
				Break;
			ElsIf Row.Duration < Duration Then
				StartDate = WorkTimeTable[UBound - Indx - 1].EndDate;
				Duration = Duration - Row.Duration;
			Else
				StartDate = StartDate - Duration;
				Duration = 0;
				Break;
			EndIf;
			
		EndDo;
		
		If Duration > 0 Then
			
			PeriodEnd = StartDate;
			PeriodStart = PeriodEnd - 10*24*3600;
			
			WorkTimeTable = GenerateWorkTimeTable(WorkSchedule, PeriodStart, PeriodEnd);
			
			While WorkTimeTable.Count() < 2 Do
				PeriodStart = PeriodStart - 10*24*3600;
				WorkTimeTable = GenerateWorkTimeTable(WorkSchedule, PeriodStart, PeriodEnd);
			EndDo;
			
			UBound = WorkTimeTable.Count() - 1;
			
		EndIf;
		
	EndDo;
	
	Return StartDate;
	
EndFunction

Function GetFirstWorkingTimeOfDay(WorkSchedule, Date) Export
	
	If IsWorkingDateTime(WorkSchedule, Date) Then
		Return Date;
	EndIf;
	
	WorkTimeTable = GenerateWorkTimeTable(WorkSchedule, BegOfDay(Date), EndOfDay(Date));
	
	If WorkTimeTable.Count() > 0 Then
		If Date > WorkTimeTable[0].StartDate
			And Date < WorkTimeTable[WorkTimeTable.Count() - 1].EndDate Then
			Return Date;
		ElsIf Date < WorkTimeTable[WorkTimeTable.Count() - 1].EndDate Then
			Return WorkTimeTable[0].StartDate;
		Else
			Return GetFirstWorkingTimeOfDay(WorkSchedule, BegOfDay(Date + 24 * 3600));
		EndIf;
	Else
		Return GetFirstWorkingTimeOfDay(WorkSchedule, BegOfDay(Date + 24 * 3600));
	EndIf;
	
EndFunction

Function GetLastWorkingTimeOfDay(WorkSchedule, Date) Export
	
	If IsWorkingDateTime(WorkSchedule, Date) Then
		Return Date;
	EndIf;
	
	WorkTimeTable = GenerateWorkTimeTable(WorkSchedule, BegOfDay(Date), EndOfDay(Date));
	
	If WorkTimeTable.Count() > 0 Then
		If Date < WorkTimeTable[WorkTimeTable.Count() - 1].EndDate
			And Date > WorkTimeTable[0].StartDate Then
			Return Date;
		ElsIf Date < WorkTimeTable[WorkTimeTable.Count() - 1].EndDate Then
			Return WorkTimeTable[WorkTimeTable.Count() - 1].EndDate;
		Else
			Return GetLastWorkingTimeOfDay(WorkSchedule, BegOfDay(Date + 24 * 3600));
		EndIf;
	Else
		Return GetLastWorkingTimeOfDay(WorkSchedule, BegOfDay(Date + 24 * 3600));
	EndIf;
	
EndFunction

#EndRegion

#Region Private

Function AddTime(Date, Time)
	
	Return BegOfDay(Date) + Hour(Time)*3600 + Minute(Time)*60 + Second(Time);
	
EndFunction

Function IsWorkingDateTime(WorkSchedule, DateToCheck)
	
	If Not IsWorkingDay(DateToCheck, WorkSchedule) Then
		Return False;
	EndIf;
	
	WorkTimeTable = GenerateWorkTimeTable(WorkSchedule, BegOfDay(DateToCheck), EndOfDay(DateToCheck));
	
	For Each TableRow In WorkTimeTable Do
		If TableRow.StartDate <= DateToCheck And DateToCheck <= TableRow.EndDate Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function GenerateWorkTimeTable(WorkSchedule, StartDate, EndDate)
	
	Schedules = CommonClientServer.ValueInArray(WorkSchedule);
	WorkTime = CalendarSchedules.WorkSchedulesForPeriod(Schedules, BegOfDay(StartDate), EndOfDay(EndDate));
	WorkTime.Sort("ScheduleDate, BeginTime");
	
	WorkTimeTable = New ValueTable;
	WorkTimeTable.Columns.Add("StartDate");
	WorkTimeTable.Columns.Add("EndDate");
	WorkTimeTable.Columns.Add("Duration");
	
	For Each Row In WorkTime Do
		
		EndDateValue = AddTime(Row.ScheduleDate, Row.EndTime);
		StartDateValue = AddTime(Row.ScheduleDate, Row.BeginTime);
		
		If EndDateValue < StartDate Or StartDateValue > EndDate Then
			Continue;
		EndIf;
		
		NewRow = WorkTimeTable.Add();
		NewRow.StartDate = StartDateValue;
		NewRow.EndDate = EndDateValue;
		
		If NewRow.StartDate < StartDate Then
			NewRow.StartDate = StartDate;
		EndIf;
		
		If NewRow.EndDate > EndDate Then
			NewRow.EndDate = EndDate;
		EndIf;
		
		NewRow.Duration = NewRow.EndDate - NewRow.StartDate;
		If NewRow.EndDate = EndOfDay(NewRow.EndDate) Then
			NewRow.Duration = NewRow.Duration + 1
		EndIf;
		
	EndDo;
	
	Return WorkTimeTable;
	
EndFunction

#EndRegion