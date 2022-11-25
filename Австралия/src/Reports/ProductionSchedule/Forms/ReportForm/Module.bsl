#Region FormEventHandlers

&AtClient
Procedure OnOpen(Cancel)
	
	StartReportGeneration();
	SetWIPChoiceParameterLink();
	SetReportEnabled(True);
	SetIntervalDurationVisible();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure GanttChartDetailProcessing(Item, Details, StandardProcessing, Date)
	
	If TypeOf(Details) = Type("Array") And Details.Count() > 1 Then
		
		CollapsedDetails = CommonClientServer.CollapseArray(Details);
		CommonClientServer.DeleteValueFromArray(CollapsedDetails, Undefined);
		
		If CollapsedDetails.Count() = 1 Then
			
			StandardProcessing = False;
			ShowValue(, CollapsedDetails[0]);
			
		Else
			
			StandardProcessing = False;
			
			SelectedWIPs.LoadValues(CollapsedDetails);
			Notification = New NotifyDescription("AfterItemSelection", ThisObject);
			SelectedWIPs.ShowChooseItem(Notification, NStr("en = 'Works-in-progress'; ru = 'Незавершенное производство';pl = 'Prace w toku';es_ES = 'Trabajo en progreso';es_CO = 'Trabajo en progreso';tr = 'İşlem bitişleri';it = 'Lavori in corso';de = 'Arbeiten in Bearbeitung'"), SelectedWIPs[0]);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductionOrderOnChange(Item)
	
	WIP = PredefinedValue("Document.ManufacturingOperation.EmptyRef");
	SetWIPChoiceParameterLink();
	SetReportEnabled(False);
	
EndProcedure

&AtClient
Procedure PeriodOnChange(Item)
	
	SetReportEnabled(False);
	
EndProcedure

&AtClient
Procedure IntervalOnChange(Item)
	
	SetReportEnabled(False);
	SetIntervalDurationVisible();
	
EndProcedure

&AtClient
Procedure IntervalDurationOnChange(Item)
	
	SetReportEnabled(False);
	
EndProcedure

&AtClient
Procedure WIPOnChange(Item)
	
	SetReportEnabled(False);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Generate(Command)
	
	StartReportGeneration();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AfterItemSelection(ItemSelection, ListOfParameters) Export
	
	If ItemSelection <> Undefined Then
		
		ShowValue(, ItemSelection.Value);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure StartReportGeneration()
	
	If ValueIsFilled(Period) And ValueIsFilled(Interval) Then
		
		If Period.StartDate > Period.EndDate Then
			
			CommonClientServer.MessageToUser(NStr("en = 'Period end should be later than its start'; ru = 'Конец периода должен быть больше начала';pl = 'Koniec okresu powinien być późniejszy niż jego początek';es_ES = 'Fin del período tiene que ser más tarde que su inicio';es_CO = 'Fin del período tiene que ser más tarde que su inicio';tr = 'Dönem sonu, başlangıcından sonra olmalıdır';it = 'La fine del periodo deve essere successiva all''inizio';de = 'Das Periodenende sollte später als sein Beginn sein'"), , "Period");
			Return;
			
		EndIf;
		
		ReportSettings = New Structure;
		ReportSettings.Insert("StartDate", Period.StartDate);
		ReportSettings.Insert("EndDate", Period.EndDate);
		ReportSettings.Insert("Interval", Interval);
		ReportSettings.Insert("IntervalDuration", 0);
		ReportSettings.Insert("ProductionOrder", ProductionOrder);
		ReportSettings.Insert("WIP", WIP);
		
		If Interval = PredefinedValue("Enum.PlanningIntervals.Minute") Then
			
			If ValueIsFilled(IntervalDuration) Then
				
				ReportSettings.IntervalDuration = IntervalDuration;
				
			Else
				
				Return;
				
			EndIf;
			
		EndIf;
		
		ResultAddress = GenerateReport(ReportSettings);
		
		NewChart = GetFromTempStorage(ResultAddress);
		
		If TypeOf(NewChart) = Type("GanttChart") Then
			
			GanttChart = NewChart;
			SetReportEnabled(True);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GenerateReport(ReportSettings)
	
	GanttChart = New GanttChart;
	
	GanttChart.AutoDetectWholeInterval = False;
	GanttChart.ScaleKeeping = GanttChartScaleKeeping.AllData;
	GanttChart.Outline = True;
	GanttChart.ShowLegend = False;
	GanttChart.VerticalScroll = True;
	GanttChart.ShowEmptyValues = False;
	GanttChart.ShowTitle = False;
	GanttChart.ValueTextRepresentation = GanttChartValueTextRepresentation.None;
	GanttChart.PlotArea.Right = 1;
	GanttChart.PlotArea.TimeScale.Transparent = True;
	
	GanttChart.RefreshEnabled = False;
	
	Query = New Query;
	
	Query.Text = 
	"SELECT ALLOWED
	|	WorkcentersSchedule.WorkcenterType AS WorkcenterType,
	|	WorkcentersSchedule.Workcenter AS Workcenter,
	|	WorkcentersSchedule.Operation AS Operation,
	|	WorkcentersSchedule.StartDate AS StartDate,
	|	WorkcentersSchedule.EndDate AS EndDate,
	|	WorkcentersSchedule.WorkloadTime AS WorkloadTime,
	|	ManufacturingOperation.BasisDocument AS BasisDocument,
	|	ManufacturingOperation.Status AS Status,
	|	WorkcentersSchedule.Activity AS Activity,
	|	WorkcentersSchedule.ConnectionKey AS ConnectionKey,
	|	ManufacturingOperationActivities.TimeUOM AS TimeUOM
	|INTO TT_UsedWCT
	|FROM
	|	InformationRegister.WorkcentersSchedule AS WorkcentersSchedule
	|		INNER JOIN Document.ManufacturingOperation AS ManufacturingOperation
	|		ON WorkcentersSchedule.Operation = ManufacturingOperation.Ref
	|		INNER JOIN Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|		ON WorkcentersSchedule.Operation = ManufacturingOperationActivities.Ref
	|			AND WorkcentersSchedule.ConnectionKey = ManufacturingOperationActivities.ConnectionKey
	|WHERE
	|	(WorkcentersSchedule.StartDate BETWEEN &StartDate AND &EndDate
	|			OR WorkcentersSchedule.EndDate BETWEEN &StartDate AND &EndDate)
	|	AND &ProductionOrderCondition
	|	AND &WIPCondition
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CompanyResourceTypes.Ref AS WorkcenterType,
	|	CompanyResources.Ref AS Workcenter,
	|	CompanyResourceTypes.PlanningOnWorkcentersLevel AS PlanningOnWorkcentersLevel,
	|	CompanyResourceTypes.BusinessUnit AS BusinessUnit
	|INTO TT_Workcenters
	|FROM
	|	Catalog.CompanyResourceTypes AS CompanyResourceTypes
	|		LEFT JOIN Catalog.CompanyResources AS CompanyResources
	|		ON (CompanyResources.WorkcenterType = CompanyResourceTypes.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Workcenters.WorkcenterType AS WorkcenterType,
	|	CASE
	|		WHEN TT_Workcenters.PlanningOnWorkcentersLevel
	|			THEN TT_Workcenters.Workcenter
	|		ELSE VALUE(Catalog.CompanyResources.EmptyRef)
	|	END AS Workcenter,
	|	TT_UsedWCT.Operation AS Operation,
	|	TT_UsedWCT.StartDate AS StartDate,
	|	TT_UsedWCT.EndDate AS EndDate,
	|	SUM(TT_UsedWCT.WorkloadTime) AS WorkloadTime,
	|	TT_UsedWCT.BasisDocument AS BasisDocument,
	|	TT_UsedWCT.Status AS Status,
	|	TT_Workcenters.PlanningOnWorkcentersLevel AS PlanningOnWorkcentersLevel,
	|	TT_Workcenters.BusinessUnit AS BusinessUnit,
	|	TT_UsedWCT.Activity AS Activity,
	|	TT_UsedWCT.TimeUOM AS TimeUOM
	|FROM
	|	TT_Workcenters AS TT_Workcenters
	|		LEFT JOIN TT_UsedWCT AS TT_UsedWCT
	|		ON TT_Workcenters.WorkcenterType = TT_UsedWCT.WorkcenterType
	|			AND (NOT TT_Workcenters.PlanningOnWorkcentersLevel
	|				OR TT_Workcenters.Workcenter = TT_UsedWCT.Workcenter)
	|
	|GROUP BY
	|	TT_Workcenters.WorkcenterType,
	|	CASE
	|		WHEN TT_Workcenters.PlanningOnWorkcentersLevel
	|			THEN TT_Workcenters.Workcenter
	|		ELSE VALUE(Catalog.CompanyResources.EmptyRef)
	|	END,
	|	TT_UsedWCT.Operation,
	|	TT_UsedWCT.StartDate,
	|	TT_UsedWCT.EndDate,
	|	TT_UsedWCT.BasisDocument,
	|	TT_UsedWCT.Status,
	|	TT_Workcenters.PlanningOnWorkcentersLevel,
	|	TT_Workcenters.BusinessUnit,
	|	TT_UsedWCT.Activity,
	|	TT_UsedWCT.TimeUOM
	|TOTALS BY
	|	BusinessUnit,
	|	WorkcenterType";
	
	Query.SetParameter("StartDate", ReportSettings.StartDate);
	Query.SetParameter("EndDate", ReportSettings.EndDate);
	
	If ValueIsFilled(ReportSettings.ProductionOrder) Then
		
		Query.Text = StrReplace(
			Query.Text,
			"&ProductionOrderCondition",
			"ManufacturingOperation.BasisDocument = &ProductionOrder");
		Query.SetParameter("ProductionOrder", ReportSettings.ProductionOrder);
		
	Else
		
		Query.SetParameter("ProductionOrderCondition", True);
		
	EndIf;
	
	If ValueIsFilled(ReportSettings.WIP) Then
		
		Query.Text = StrReplace(
			Query.Text,
			"&WIPCondition",
			"WorkcentersSchedule.Operation = &WIP");
		Query.SetParameter("WIP", ReportSettings.WIP);
		
	Else
		
		Query.SetParameter("WIPCondition", True);
		
	EndIf;
	
	QueryResult = Query.Execute();
	
	SelectionBusinessUnit = QueryResult.Select(QueryResultIteration.ByGroups);
	
	While SelectionBusinessUnit.Next() Do
		
		If ValueIsFilled(SelectionBusinessUnit.BusinessUnit) Then
		
			PointBusinessUnit = GanttChart.SetPoint(SelectionBusinessUnit.BusinessUnit);
			PointBusinessUnit.Text = SelectionBusinessUnit.BusinessUnit;
			PointBusinessUnit.Details = SelectionBusinessUnit.BusinessUnit;
		
			SelectionWorkcenterType = SelectionBusinessUnit.Select(QueryResultIteration.ByGroups);
			
			While SelectionWorkcenterType.Next() Do
				
				PointWorkcenterType = GanttChart.SetPoint(SelectionWorkcenterType.WorkcenterType, SelectionWorkcenterType.BusinessUnit);
				PointWorkcenterType.Text = SelectionWorkcenterType.WorkcenterType;
				PointWorkcenterType.Details = SelectionWorkcenterType.WorkcenterType;
				
				SelectionDetailRecords = SelectionWorkcenterType.Select();
				
				PrevValue = Undefined;
				
				While SelectionDetailRecords.Next() Do
					
					Series = GanttChart.SetSeries("ProductionSchedule");
					Series.BetweenIntervalsHatch = False;
					Series.OverlappedIntervalsHatch = True;
					
					If SelectionDetailRecords.PlanningOnWorkcentersLevel Then
						
						Point = GanttChart.SetPoint(SelectionDetailRecords.Workcenter, SelectionDetailRecords.WorkcenterType);
						Point.Text = SelectionDetailRecords.Workcenter;
						Point.Details = SelectionDetailRecords.Workcenter;
						
					Else
						
						Point = PointWorkcenterType;
						
					EndIf;
					
					If ValueIsFilled(SelectionDetailRecords.StartDate) Then
						
						Value = GanttChart.GetValue(Point, Series);
						OperationValue = Value.Add();
						OperationValue.Begin = SelectionDetailRecords.StartDate;
						OperationValue.Details = SelectionDetailRecords.Operation;
						OperationValue.Color = StatusColor(SelectionDetailRecords.Status);
						
						OperationValue.End = SelectionDetailRecords.EndDate;
						OperationValue.Text = WIPPresentation(OperationValue, SelectionDetailRecords);
						
					EndIf;
					
				EndDo;
				
				GanttChart.ExpandPoint(PointWorkcenterType, True);
				
			EndDo;
			
			GanttChart.ExpandPoint(PointBusinessUnit, True);
			
		EndIf;
		
	EndDo;
	
	SetPeriodicy(GanttChart, ReportSettings.Interval, ReportSettings.IntervalDuration);
	
	GanttChart.SetWholeInterval(BegOfDay(ReportSettings.StartDate), EndOfDay(ReportSettings.EndDate));
	
	SetBackgroundIntervals(GanttChart);
	
	Return PutToTempStorage(GanttChart);
	
EndFunction

&AtServerNoContext
Procedure SetPeriodicy(GanttChart, Interval, IntervalDuration)
	
	// Cleat time scale
	TimeScale = GanttChart.PlotArea.TimeScale.Items;
	
	For Index = 1 To TimeScale.Count() - 1 Do
		TimeScale.Delete(TimeScale[1]);
	EndDo;
	
	If Interval = Enums.PlanningIntervals.Minute Then
		
		FirstItem = GanttChart.PlotArea.TimeScale.Items[0];
		FirstItem.Unit = TimeScaleUnitType.Day;
		FirstItem.PointLines = New Line(SpreadsheetDocumentCellLineType.Solid, 1);
		FirstItem.DayFormat = TimeScaleDayFormat.MonthDayWeekDay;
		FirstItem.Format = NStr("en = 'DF=''dd MMMM'''; ru = 'DF=''dd MMMM''';pl = 'DF=''dd MMMM''';es_ES = 'DF=''dd MMMM''';es_CO = 'DF=''dd MMMM''';tr = 'DF=''dd MMMM''';it = 'DF=''dd MMMM''';de = 'DF=''dd MMMM'''");
		
		Item = GanttChart.PlotArea.TimeScale.Items.Add();
		Item.Unit = TimeScaleUnitType.Hour;
		Item.PointLines = New Line(SpreadsheetDocumentCellLineType.Dotted, 1);
		Item.Format = NStr("en = 'DF=''hh:mm tt'''; ru = 'DF=''hh:mm tt''';pl = 'DF=''hh:mm tt''';es_ES = 'DF=''hh:mm tt''';es_CO = 'DF=''hh:mm tt''';tr = 'DF=''hh:mm tt''';it = 'DF=hh:mm tt';de = 'DF=''hh:mm tt'''");
		
		Item = GanttChart.PlotArea.TimeScale.Items.Add();
		Item.Unit = TimeScaleUnitType.Minute;
		Item.PointLines = New Line(SpreadsheetDocumentCellLineType.Dotted, 1);
		Item.Format = NStr("en = 'DF=''mm'''; ru = 'ДФ=''мм''';pl = 'DF=''mm''';es_ES = 'DF=''mm''';es_CO = 'DF=''mm''';tr = 'DF=''mm''';it = 'DF=''mm''';de = 'DF=''mm'''");
		Item.Repetition = IntervalDuration;
		
		GanttChart.ScaleKeeping = GanttChartScaleKeeping.Period;
		GanttChart.PeriodicVariantRepetition = 5;
		GanttChart.PeriodicVariantUnit = TimeScaleUnitType.Hour;
		
	ElsIf Interval = Enums.PlanningIntervals.Hour Then
		
		FirstItem = GanttChart.PlotArea.TimeScale.Items[0];
		FirstItem.Unit = TimeScaleUnitType.Day;
		FirstItem.PointLines = New Line(SpreadsheetDocumentCellLineType.Solid, 1);
		FirstItem.DayFormat = TimeScaleDayFormat.MonthDayWeekDay;
		FirstItem.Format = NStr("en = 'DF=''dd MMMM'''; ru = 'DF=''dd MMMM''';pl = 'DF=''dd MMMM''';es_ES = 'DF=''dd MMMM''';es_CO = 'DF=''dd MMMM''';tr = 'DF=''dd MMMM''';it = 'DF=''dd MMMM''';de = 'DF=''dd MMMM'''");
		
		Item = GanttChart.PlotArea.TimeScale.Items.Add();
		Item.Unit = TimeScaleUnitType.Hour;
		Item.PointLines = New Line(SpreadsheetDocumentCellLineType.Dotted, 1);
		Item.Format = NStr("en = 'DF=''hh:mm tt'''; ru = 'DF=''hh:mm tt''';pl = 'DF=''hh:mm tt''';es_ES = 'DF=''hh:mm tt''';es_CO = 'DF=''hh:mm tt''';tr = 'DF=''hh:mm tt''';it = 'DF=hh:mm tt';de = 'DF=''hh:mm tt'''");
		
		GanttChart.ScaleKeeping = GanttChartScaleKeeping.Period;
		GanttChart.PeriodicVariantRepetition = 12;
		GanttChart.PeriodicVariantUnit = TimeScaleUnitType.Hour;
		
	ElsIf Interval = Enums.PlanningIntervals.Day Then
		
		FirstItem = GanttChart.PlotArea.TimeScale.Items[0];
		FirstItem.Unit = TimeScaleUnitType.Day;
		FirstItem.PointLines = New Line(SpreadsheetDocumentCellLineType.Solid, 1);
		FirstItem.DayFormat = TimeScaleDayFormat.MonthDayWeekDay;
		FirstItem.Format = NStr("en = 'DF=''dd MMMM'''; ru = 'DF=''dd MMMM''';pl = 'DF=''dd MMMM''';es_ES = 'DF=''dd MMMM''';es_CO = 'DF=''dd MMMM''';tr = 'DF=''dd MMMM''';it = 'DF=''dd MMMM''';de = 'DF=''dd MMMM'''");
		
		GanttChart.ScaleKeeping = GanttChartScaleKeeping.Period;
		GanttChart.PeriodicVariantRepetition = 12;
		GanttChart.PeriodicVariantUnit = TimeScaleUnitType.Day;

	ElsIf Interval = Enums.PlanningIntervals.Week Then
		
		FirstItem = GanttChart.PlotArea.TimeScale.Items[0];
		FirstItem.Unit = TimeScaleUnitType.Week;
		FirstItem.PointLines = New Line(SpreadsheetDocumentCellLineType.Solid, 1);
		
		Item = GanttChart.PlotArea.TimeScale.Items.Add();
		Item.Unit = TimeScaleUnitType.Day;
		Item.PointLines = New Line(SpreadsheetDocumentCellLineType.Dotted, 1);
		Item.DayFormat = TimeScaleDayFormat.MonthDayWeekDay;
		
		GanttChart.ScaleKeeping = GanttChartScaleKeeping.Period;
		GanttChart.PeriodicVariantRepetition = 2;
		GanttChart.PeriodicVariantUnit = TimeScaleUnitType.Week;
		
	ElsIf Interval = Enums.PlanningIntervals.Month Then
		
		FirstItem = GanttChart.PlotArea.TimeScale.Items[0];
		FirstItem.Unit = TimeScaleUnitType.Month;
		FirstItem.PointLines = New Line(SpreadsheetDocumentCellLineType.Solid, 1);
		FirstItem.Format = NStr("en = 'DF=''MMMM yyyy'''; ru = 'DF=''MMMM yyyy''';pl = 'DF=''MMMM yyyy''';es_ES = 'DF=''MMMM yyyy''';es_CO = 'DF=''MMMM yyyy''';tr = 'DF=''MMMM yyyy''';it = 'DF=''MMMM yyyy''';de = 'DF=''MMMM yyyy'''");
		
		GanttChart.ScaleKeeping = GanttChartScaleKeeping.Period;
		GanttChart.PeriodicVariantRepetition = 2;
		GanttChart.PeriodicVariantUnit = TimeScaleUnitType.Month;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure SetBackgroundIntervals(GanttChart)
	
	NewBackIntervals = GanttChart.BackgroundIntervals.Add(GanttChart.BeginOfWholeInterval, GanttChart.EndOfWholeInterval);
	NewBackIntervals.Color = WebColors.Gainsboro;
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	DATEADD(WorkcentersAvailability.Date, MINUTE, DATEDIFF(DATETIME(1, 1, 1), WorkcentersAvailabilityIntervals.StartTime, MINUTE)) AS StartTime,
		|	DATEADD(WorkcentersAvailability.Date, MINUTE, DATEDIFF(DATETIME(1, 1, 1), WorkcentersAvailabilityIntervals.EndTime, MINUTE)) AS EndTime
		|FROM
		|	Document.WorkcentersAvailability.Intervals AS WorkcentersAvailabilityIntervals
		|		LEFT JOIN Document.WorkcentersAvailability AS WorkcentersAvailability
		|		ON WorkcentersAvailabilityIntervals.Ref = WorkcentersAvailability.Ref
		|WHERE
		|	(DATEADD(WorkcentersAvailability.Date, MINUTE, DATEDIFF(DATETIME(1, 1, 1), WorkcentersAvailabilityIntervals.StartTime, MINUTE)) BETWEEN &StartTime AND &EndTime
		|			OR DATEADD(WorkcentersAvailability.Date, MINUTE, DATEDIFF(DATETIME(1, 1, 1), WorkcentersAvailabilityIntervals.EndTime, MINUTE)) BETWEEN &StartTime AND &EndTime
		|			OR DATEADD(WorkcentersAvailability.Date, MINUTE, DATEDIFF(DATETIME(1, 1, 1), WorkcentersAvailabilityIntervals.StartTime, MINUTE)) < &StartTime
		|				AND DATEADD(WorkcentersAvailability.Date, MINUTE, DATEDIFF(DATETIME(1, 1, 1), WorkcentersAvailabilityIntervals.EndTime, MINUTE)) > &EndTime)";
	
	Query.SetParameter("EndTime", GanttChart.EndOfWholeInterval);
	Query.SetParameter("StartTime", GanttChart.BeginOfWholeInterval);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		NewBackIntervals = GanttChart.BackgroundIntervals.Add(SelectionDetailRecords.StartTime, SelectionDetailRecords.EndTime);
		NewBackIntervals.Color = WebColors.White;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Function WIPPresentation(OperationValue, SelectionDetailRecords)
	
	WIP = OperationValue.Details;
	StructureWIP = Common.ObjectAttributesValues(WIP, "Specification, Products");
	
	Result = "" + WIP + Chars.LF;
	
	Result = Result + NStr("en = 'Operation:'; ru = 'Операция:';pl = 'Operacja:';es_ES = 'Operación:';es_CO = 'Operación:';tr = 'İşlem:';it = 'Operazione:';de = 'Operation:'") + " " + TrimAll(SelectionDetailRecords.Activity) + Chars.LF;
	
	DurationInMins = SelectionDetailRecords.WorkloadTime;
	Factor = Common.ObjectAttributeValue(SelectionDetailRecords.TimeUOM, "Factor");
	Duration = DurationInMins / Factor;
	Result = Result + NStr("en = 'Duration:'; ru = 'Длительность:';pl = 'Czas trwania:';es_ES = 'Duración:';es_CO = 'Duración:';tr = 'Süre:';it = 'Durata:';de = 'Dauer:'") + " " + TrimAll(Duration) + " " + TrimAll(SelectionDetailRecords.TimeUOM) + Chars.LF;
	
	Result = Result + NStr("en = 'Bill of materials:'; ru = 'Спецификация:';pl = 'Specyfikacja materiałowa:';es_ES = 'Lista de materiales:';es_CO = 'Lista de materiales:';tr = 'Ürün reçetesi:';it = 'Distinta base:';de = 'Stückliste:'") +" "+ TrimAll(StructureWIP.Specification) + Chars.LF;
	
	Result = Result + NStr("en = 'Product:'; ru = 'Номенклатура:';pl = 'Produkt:';es_ES = 'Producto:';es_CO = 'Producto:';tr = 'Ürün:';it = 'Articolo:';de = 'Produkt:'") +" "+ TrimAll(StructureWIP.Products) + Chars.LF;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function StatusColor(WIPStatus)
	
	Result = StyleColors.ProductionScheduleColorOliveRab;
	
	If WIPStatus = Enums.ManufacturingOperationStatuses.InProcess Then
		
		Result = StyleColors.ProductionScheduleColorDarkOrange;
		
	ElsIf WIPStatus = Enums.ManufacturingOperationStatuses.Completed Then
		
		Result = StyleColors.ProductionScheduleColorTomato;
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SetWIPChoiceParameterLink()
	
	NewArray = New Array;
	Items.WIP.ChoiceParameterLinks = New FixedArray(NewArray);
	
	If ValueIsFilled(ProductionOrder) Then
		NewLink = New ChoiceParameterLink("Filter.BasisDocument", "ProductionOrder");
		NewArray.Add(NewLink);
		NewLinks = New FixedArray(NewArray);
		Items.WIP.ChoiceParameterLinks = NewLinks;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetReportEnabled(ReportGenerated)
	
	Items.DecorationNotGenerated.Visible = Not ReportGenerated;
	Items.GanttChart.Enabled = ReportGenerated;
	
EndProcedure

&AtClient
Procedure SetIntervalDurationVisible()
	
	Items.IntervalDuration.Visible = (Interval = PredefinedValue("Enum.PlanningIntervals.Minute"));
	
EndProcedure

#EndRegion