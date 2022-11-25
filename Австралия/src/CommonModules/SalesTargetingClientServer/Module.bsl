#Region Public

// Calculates start and end date of period with specified periodicity
//
// Parameters:
//  Periodicity			- EnumRef.Periodicity - Periodicity with which you need to calculate dates
//  PeriodStartDate		- Date - Period start date
//  PeriodEndDate		- Date - Period end date
//
Procedure SetStartEndOfTargetPeriod(Val Periodicity, PeriodStartDate, PeriodEndDate) Export
	
	If Not ValueIsFilled(Periodicity) Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(PeriodStartDate) Then
		PeriodStartDate = DriveReUse.GetSessionCurrentDate();
	EndIf;
	
	PeriodStartDate = DriveClientServer.CalculateComingPeriodStartDate(PeriodStartDate, Periodicity);
	
	If ValueIsFilled(PeriodEndDate)
		And Periodicity = PredefinedValue("Enum.Periodicity.Day")
		And PeriodEndDate > PeriodStartDate Then
		
	ElsIf ValueIsFilled(PeriodEndDate) And PeriodEndDate > PeriodStartDate Then
		
		StartOfLastPeriod = DriveClientServer.CalculateComingPeriodStartDate(PeriodEndDate, Periodicity);
		PeriodEndDate = DriveClientServer.CalculatePeriodEndDate(StartOfLastPeriod, Periodicity, 0);
		
	Else
		
		PeriodEndDate = DriveClientServer.CalculatePeriodEndDate(PeriodStartDate, Periodicity, 1);
		
	EndIf;
	
EndProcedure

// Calculates start date of period by specified periodicity
//
// Parameters:
// Date			- date, for which you need to calculate begin of period
// Periodicity	- value from enumeration "Periodicity"
//
// Returns:
// Date - Period start date
//
Function CalculatePeriodStartDate(Val Date, Val Periodicity) Export
	
	OneDay = 86400;
	StartDate = Date;
	
	If Periodicity = PredefinedValue("Enum.Periodicity.Day") Then
		
		StartDate = BegOfDay(Date);
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.Week") Then
		
		StartDate = BegOfWeek(Date);
		
	ElsIf (Periodicity = PredefinedValue("Enum.Periodicity.TenDays")) Then
		
		DayOfMonth	= Day(Date);
		BegOfMonth	= BegOfMonth(Date);
		
		If DayOfMonth = 1 Or DayOfMonth = 11 Or DayOfMonth = 21 Then
			StartDate = Date;
		ElsIf DayOfMonth <= 10 Then
			StartDate = BegOfMonth
		ElsIf DayOfMonth <= 20 Then
			StartDate = BegOfMonth + OneDay * 10;
		Else
			StartDate = BegOfMonth + OneDay * 20;
		EndIf;
		
	ElsIf (Periodicity= PredefinedValue("Enum.Periodicity.Month")) Then
		
		StartDate = BegOfMonth(Date);
		
	ElsIf (Periodicity = PredefinedValue("Enum.Periodicity.Quarter")) Then
		
		StartDate = BegOfQuarter(Date);

	ElsIf (Periodicity = PredefinedValue("Enum.Periodicity.HalfYear")) Then
		
		BegOfYear		= BegOfYear(Date);
		HalfYearStart	= AddMonth(BegOfYear,6);
		
		If Date >= HalfYearStart Then
			StartDate = HalfYearStart;
		Else
			StartDate = BegOfYear;
		EndIf;

	ElsIf (Periodicity = PredefinedValue("Enum.Periodicity.Year")) Then
		
		StartDate = BegOfYear(Date);
		
	EndIf;
	
	Return StartDate;
	
EndFunction

// Calculates end date of period by specified date and periodicity
//
// Parameters:
// Date			- date, for which you need to calculate end of period
// Periodicity	- value from enumeration "Periodicity"
//
// Returns:
// Date - Period end date
//
Function CalculatePeriodEndDate(Val Date, Val Periodicity) Export
	
	OneDay = 86400;
	EndDate = Date;
	
	If Periodicity = PredefinedValue("Enum.Periodicity.Day") Then
		
		EndDate = EndOfDay(Date);
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.Week") Then
		
		EndDate = EndOfWeek(Date);
		
	ElsIf (Periodicity = PredefinedValue("Enum.Periodicity.TenDays")) Then
		
		DayOfMonth = Day(Date);
		EndOfMonth = EndOfMonth(Date);
		BegOfMonth = BegOfMonth(Date);
		
		If DayOfMonth = 10 Or DayOfMonth = 20 Or DayOfMonth = Day(EndOfMonth) Then
			EndDate = EndOfDay(Date);
		ElsIf DayOfMonth <= 9 Then
			EndDate = BegOfMonth - 1 + OneDay * 10
		ElsIf DayOfMonth <= 19 Then
			EndDate = BegOfMonth - 1 + OneDay * 20;
		Else
			EndDate = EndOfMonth;
		EndIf;
		
	ElsIf (Periodicity= PredefinedValue("Enum.Periodicity.Month")) Then
		
		EndDate = EndOfMonth(Date);
		
	ElsIf (Periodicity = PredefinedValue("Enum.Periodicity.Quarter")) Then
		
		EndDate = EndOfQuarter(Date);

	ElsIf (Periodicity = PredefinedValue("Enum.Periodicity.HalfYear")) Then
		
		EndOfYear	= EndOfYear(Date);
		HalfYearEnd	= AddMonth(EndOfYear, -6);
		
		If Date < HalfYearEnd Then
			EndDate = HalfYearEnd;
		Else
			EndDate = EndOfYear;
		EndIf;
		
	ElsIf (Periodicity = PredefinedValue("Enum.Periodicity.Year")) Then
		
		EndDate = EndOfYear(Date);
		
	EndIf;
	
	Return EndDate;
	
EndFunction

// Generates title for dates interval with specified periodicity
//
// Parameters:
//  Periodicity			- EnumRef.Periodicity - Periodicity whith which you need to farm title
//  StartDate			- Date - Period start date
//  EndDate				- Date - Period end date
//  ShowPeriodNumber	- Boolean - Flag to display the title by period number within a year
//
// Returns:
//  String - Title of the period
//
Function SetPeriodTitle(Val StartDate, Val EndDate, Val Periodicity, Val ShowPeriodNumber = False) Export
	
	Title = "";
	
	If Periodicity = PredefinedValue("Enum.Periodicity.Day") Then
		
		If ShowPeriodNumber Then
			Title = Format(DayOfYear(StartDate), "NFD=0; NG=0") + " " + NStr("en = 'day'; ru = 'день';pl = 'dzień';es_ES = 'día';es_CO = 'día';tr = 'gün';it = 'giorno';de = 'Tag'");
		Else
			Title = Format(StartDate, "DLF=D");
		EndIf;
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.Week") Then
		
		If ShowPeriodNumber Then
			Title = NStr("en = '%WeekNumber% week'; ru = '%WeekNumber% неделя';pl = 'tydzień %WeekNumber%';es_ES = '%WeekNumber% semana';es_CO = '%WeekNumber% semana';tr = '%WeekNumber% hafta';it = '%WeekNumber% settimana';de = '%WeekNumber% Woche'");
			If Year(StartDate) <> Year(EndDate) Then
				WeekNumber = Format(WeekOfYear(StartDate), "NFD=0; NG=0") + "/" +  Format(WeekOfYear(EndDate), "NFD=0; NG=0");
			Else
				WeekNumber = Format(WeekOfYear(StartDate), "NFD=0; NG=0");
			EndIf; 
			Title = StrReplace(Title, "%WeekNumber%", WeekNumber);
		Else
			TextStartDate	= Format(BegOfDay(StartDate)+1, "DF=dd.MM"); 
			TextEndDate		= Format(EndDate, "DF=dd.MM");
			Title			= StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 - %2'; ru = '%1 - %2';pl = '%1 - %2';es_ES = '%1 - %2';es_CO = '%1 - %2';tr = '%1 - %2';it = '%1 - %2';de = '%1 - %2'"), TextStartDate, TextEndDate);
		EndIf;
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.TenDays") Then
		
		TextStartDate	= Format(BegOfDay(StartDate) + 1, "DF=dd.MM"); 
		TextEndDate		= Format(EndDate, "DF=dd.MM");
		Title			= StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 - %2'; ru = '%1 - %2';pl = '%1 - %2';es_ES = '%1 - %2';es_CO = '%1 - %2';tr = '%1 - %2';it = '%1 - %2';de = '%1 - %2'"), TextStartDate, TextEndDate);
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.Month") Then
		
		If ShowPeriodNumber Then
			Title = Format(Month(BegOfDay(StartDate)+1), "NFD=0; NG=0") + " " + NStr("en = 'month'; ru = 'месяц';pl = 'miesiąc';es_ES = 'mes';es_CO = 'mes';tr = 'ay';it = 'mese';de = 'Monat'");
		Else
			Title = Format(BegOfDay(StartDate)+1, "DF='MMMM yyyy'");
		EndIf;
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.Quarter") Then
		
		If ShowPeriodNumber Then
			Title = Format(StartDate, "DF='q'") + " " + NStr("en = 'quarter'; ru = 'квартал';pl = 'kwartał';es_ES = 'trimestre';es_CO = 'trimestre';tr = 'çeyrek yıl';it = 'trimestre';de = 'Quartal'");
		Else
			TextStartDate	= Format(StartDate, "DF='q'");
			TextEndDate		= Format(StartDate, "DF=yyyy"); 
			Title			= StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 quarter %2'; ru = '%1 квартал %2';pl = '%1 kwartał %2';es_ES = '%1 trimestre %2';es_CO = '%1 trimestre %2';tr = '%1 çeyrek yıl %2';it = '%1 trimestre %2';de = '%1 Quartal %2'"), TextStartDate, TextEndDate);
		EndIf;
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.HalfYear") Then
		
		If ShowPeriodNumber Then
			Title = ?(StartDate=BegOfYear(StartDate),"1", "2");
		Else
			TextStartDate	= ?(StartDate=BegOfYear(StartDate),"1", "2");
			TextEndDate		= Format(StartDate, "DF=yyyy"); 
			Title			= StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 half %2'; ru = '%1 полугодие %2';pl = '%1 półrocze %2';es_ES = '%1medio %2';es_CO = '%1medio %2';tr = '%1 yarıyıl %2';it = '%1 metà %2';de = '%1 Hälfte %2'"), TextStartDate, TextEndDate);
		EndIf;
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.Year") Then
		
		Title = Format(StartDate, "DF='yyyy ""y.""'");
		
	Else
		
		Title = String(StartDate);
		
	EndIf;
	
	Return Title;
	
EndFunction

Function DimensionTypeDescription(SalesGoalDimension) Export
	
	Return MapSalesGoalDimensionsAndTypes()[SalesGoalDimension];
	
EndFunction

Function MapSalesGoalDimensionsAndTypes() Export
	
	Map = New Map;
	
	Map.Insert("SalesRep",			New TypeDescription("CatalogRef.Employees"));
	Map.Insert("SalesTerritory",	New TypeDescription("CatalogRef.SalesTerritories"));
	Map.Insert("Project",			New TypeDescription("CatalogRef.Projects"));
	Map.Insert("ProductCategory",	New TypeDescription("CatalogRef.ProductsCategories"));
	Map.Insert("ProductGroup",		New TypeDescription("CatalogRef.Products"));
	Map.Insert("Products",			New TypeDescription("CatalogRef.Products"));
	
	Return Map;
	
EndFunction

#EndRegion