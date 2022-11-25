
Procedure SetFilterByPeriod(FilterList, StartDate, EndDate, FieldFilterName = "Date") Export
	
	// Filter by period
	GroupFilterByPeriod = CommonClientServer.CreateFilterItemGroup(
		FilterList.Items,
		"Period",
		DataCompositionFilterItemsGroupType.AndGroup);
	
	CommonClientServer.AddCompositionItem(
		GroupFilterByPeriod,
		FieldFilterName,
		DataCompositionComparisonType.GreaterOrEqual,
		StartDate,
		"StartDate",
		ValueIsFilled(StartDate));
	
	CommonClientServer.AddCompositionItem(
		GroupFilterByPeriod,
		FieldFilterName,
		DataCompositionComparisonType.LessOrEqual,
		EndDate,
		"EndDate",
		ValueIsFilled(EndDate));
		
EndProcedure
	
Function RefreshPeriodPresentation(Period) Export
	
	If Not ValueIsFilled(Period) Or (Not ValueIsFilled(Period.StartDate) AND Not ValueIsFilled(Period.EndDate)) Then
		PeriodPresentation = NStr("en = 'Period is not set'; ru = 'Не указан период';pl = 'Okres nie jest ustawiony';es_ES = 'Período no establecido';es_CO = 'Período no establecido';tr = 'Dönem ayarlanmadı';it = 'Il periodo non è impostato';de = 'Zeitraum ist nicht angelegt'");
	Else
		EndDate = ?(ValueIsFilled(Period.EndDate), EndOfDay(Period.EndDate), Period.EndDate);
		If EndDate < Period.StartDate Then
			
			CommonClientServer.MessageToUser(NStr("en = 'Selected date end of the period, which is less than the start date.'; ru = 'Выбрана дата окончания периода, которая меньше даты начала.';pl = 'Wybrana data końca okresu, która mniejsza niż data rozpoczęcia.';es_ES = 'Fecha del fin seleccionada del período, que es inferior a la fecha del inicio.';es_CO = 'Fecha del fin seleccionada del período, que es inferior a la fecha del inicio.';tr = 'Seçilen dönem bitiş tarihi, başlangıç tarihinden önce.';it = 'Selezionata una data di fine periodo, che è inferiore alla data di inizio.';de = 'Ausgewähltes Datumsende des Zeitraums, das kleiner als das Startdatum ist.'"));
			
			PeriodPresentation = NStr("en = 'from'; ru = 'от';pl = 'od';es_ES = 'desde';es_CO = 'desde';tr = 'itibaren';it = 'da';de = 'von'") + " " +Format(Period.StartDate,"DLF=D");
		Else
			PeriodPresentation = NStr("en = 'for'; ru = 'за';pl = 'za';es_ES = 'para';es_CO = 'para';tr = 'için';it = 'per';de = 'für'") + " " + Lower(PeriodPresentation(Period.StartDate, EndDate));
		EndIf; 
	EndIf;
	
	Return PeriodPresentation;
	
EndFunction

