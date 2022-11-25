#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("ProductionOrder", ProductionOrder);
	Parameters.Property("ScheduleState", ScheduleState);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	StartReportGeneration();
	SetReportEnabled(True);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure GanttChartDetailProcessing(Item, Details, StandardProcessing, Date)
	
	If TypeOf(Details) = Type("Array") And Details.Count() > 1 Then
		
		StandardProcessing = False;
		ShowValue(, Details[1]);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Generate(Command)
	
	StartReportGeneration();
	SetReportEnabled(True);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure StartReportGeneration()
	
	If ValueIsFilled(ProductionOrder) Then
		
		ReportSettings = New Structure;
		ReportSettings.Insert("ProductionOrder", ProductionOrder);
		ReportSettings.Insert("ScheduleState", ScheduleState);
		
		ResultAddress = GenerateReport(ReportSettings);
		
		NewChart = GetFromTempStorage(ResultAddress);
		
		If TypeOf(NewChart) = Type("GanttChart") Then
			
			GanttChart = NewChart;
			
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
	
	GanttChart.RefreshEnabled = False;
	
	ScaleFormat = SetPeriodicy(GanttChart, ReportSettings.ProductionOrder);
	
	Borders = New Structure("Start, End", '39991231', '00010101');
	
	Query = New Query;
	
	If ReportSettings.ScheduleState = 0 Then
		
		Query.Text = 
		"SELECT
		|	WorkcentersSchedule.StartDate AS StartDate,
		|	WorkcentersSchedule.EndDate AS EndDate,
		|	WorkcentersSchedule.Operation AS Operation,
		|	WorkcentersSchedule.Workcenter AS Workcenter,
		|	WorkcentersSchedule.WorkcenterType AS WorkcenterType,
		|	ManufacturingOperation.Status AS Status,
		|	ManufacturingOperation.Specification AS Specification,
		|	WorkcentersSchedule.Activity AS Activity,
		|	WorkcentersSchedule.ConnectionKey AS ConnectionKey,
		|	ManufacturingOperationActivities.TimeUOM AS TimeUOM,
		|	WorkcentersSchedule.WorkloadTime AS WorkloadTime
		|INTO TT_WIPsWithWCT
		|FROM
		|	InformationRegister.WorkcentersSchedule AS WorkcentersSchedule
		|		INNER JOIN Document.ManufacturingOperation AS ManufacturingOperation
		|		ON WorkcentersSchedule.Operation = ManufacturingOperation.Ref
		|		INNER JOIN Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
		|		ON WorkcentersSchedule.Operation = ManufacturingOperationActivities.Ref
		|			AND WorkcentersSchedule.ConnectionKey = ManufacturingOperationActivities.ConnectionKey
		|WHERE
		|	ManufacturingOperation.BasisDocument = &ProductionOrder
		|	AND &ScheduleState = 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ProductionSchedule.Operation AS Operation,
		|	ProductionSchedule.StartDate AS StartDate,
		|	ProductionSchedule.EndDate AS EndDate,
		|	ManufacturingOperation.Specification AS Specification,
		|	ManufacturingOperation.Status AS Status,
		|	ProductionSchedule.Activity AS Activity,
		|	ProductionSchedule.ConnectionKey AS ConnectionKey,
		|	ManufacturingOperationActivities.TimeUOM AS TimeUOM,
		|	DATEDIFF(ProductionSchedule.StartDate, ProductionSchedule.EndDate, MINUTE) AS WorkloadTime
		|INTO TT_WIPsWithoutWCT
		|FROM
		|	InformationRegister.ProductionSchedule AS ProductionSchedule
		|		INNER JOIN Document.ManufacturingOperation AS ManufacturingOperation
		|		ON ProductionSchedule.Operation = ManufacturingOperation.Ref
		|		INNER JOIN Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
		|		ON ProductionSchedule.Operation = ManufacturingOperationActivities.Ref
		|			AND ProductionSchedule.ConnectionKey = ManufacturingOperationActivities.ConnectionKey
		|WHERE
		|	ProductionSchedule.ProductionOrder = &ProductionOrder
		|	AND ProductionSchedule.ScheduleState = &ScheduleState
		|	AND NOT (ProductionSchedule.Operation, ProductionSchedule.ConnectionKey) IN
		|				(SELECT
		|					TT_WIPsWithWCT.Operation AS Operation,
		|					TT_WIPsWithWCT.ConnectionKey AS ConnectionKey
		|				FROM
		|					TT_WIPsWithWCT AS TT_WIPsWithWCT)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_WIPsWithWCT.StartDate AS StartDate,
		|	TT_WIPsWithWCT.EndDate AS EndDate,
		|	TT_WIPsWithWCT.Operation AS Operation,
		|	ISNULL(TT_WIPsWithWCT.Workcenter.Presentation, """") AS Workcenter,
		|	ISNULL(TT_WIPsWithWCT.WorkcenterType.Presentation, """") AS WorkcenterType,
		|	TT_WIPsWithWCT.Status AS Status,
		|	TT_WIPsWithWCT.Specification AS Specification,
		|	TT_WIPsWithWCT.Activity AS Activity,
		|	TT_WIPsWithWCT.TimeUOM AS TimeUOM,
		|	TT_WIPsWithWCT.ConnectionKey AS ConnectionKey,
		|	TT_WIPsWithWCT.WorkloadTime AS WorkloadTime
		|FROM
		|	TT_WIPsWithWCT AS TT_WIPsWithWCT
		|
		|UNION ALL
		|
		|SELECT
		|	TT_WIPsWithoutWCT.StartDate,
		|	TT_WIPsWithoutWCT.EndDate,
		|	TT_WIPsWithoutWCT.Operation,
		|	NULL,
		|	NULL,
		|	TT_WIPsWithoutWCT.Status,
		|	TT_WIPsWithoutWCT.Specification,
		|	TT_WIPsWithoutWCT.Activity,
		|	TT_WIPsWithoutWCT.TimeUOM,
		|	TT_WIPsWithoutWCT.ConnectionKey,
		|	TT_WIPsWithoutWCT.WorkloadTime
		|FROM
		|	TT_WIPsWithoutWCT AS TT_WIPsWithoutWCT
		|
		|ORDER BY
		|	Operation,
		|	ConnectionKey
		|TOTALS
		|	MAX(Activity)
		|BY
		|	Operation,
		|	ConnectionKey";
		
	Else
		
		Query.Text = 
		"SELECT
		|	WorkcentersAvailabilityPreliminary.StartDate AS StartDate,
		|	WorkcentersAvailabilityPreliminary.EndDate AS EndDate,
		|	WorkcentersAvailabilityPreliminary.Operation AS Operation,
		|	WorkcentersAvailabilityPreliminary.Workcenter AS Workcenter,
		|	WorkcentersAvailabilityPreliminary.WorkcenterType AS WorkcenterType,
		|	ManufacturingOperation.Status AS Status,
		|	ManufacturingOperation.Specification AS Specification,
		|	WorkcentersAvailabilityPreliminary.Activity AS Activity,
		|	WorkcentersAvailabilityPreliminary.ConnectionKey AS ConnectionKey,
		|	ManufacturingOperationActivities.TimeUOM AS TimeUOM,
		|	WorkcentersAvailabilityPreliminary.WorkloadTime AS WorkloadTime
		|INTO TT_WIPsWithWCT
		|FROM
		|	InformationRegister.WorkcentersAvailabilityPreliminary AS WorkcentersAvailabilityPreliminary
		|		INNER JOIN Document.ManufacturingOperation AS ManufacturingOperation
		|		ON WorkcentersAvailabilityPreliminary.Operation = ManufacturingOperation.Ref
		|		INNER JOIN Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
		|		ON WorkcentersAvailabilityPreliminary.Operation = ManufacturingOperationActivities.Ref
		|			AND WorkcentersAvailabilityPreliminary.ConnectionKey = ManufacturingOperationActivities.ConnectionKey
		|WHERE
		|	ManufacturingOperation.BasisDocument = &ProductionOrder
		|	AND &ScheduleState = 1
		|
		|GROUP BY
		|	WorkcentersAvailabilityPreliminary.EndDate,
		|	WorkcentersAvailabilityPreliminary.Operation,
		|	ManufacturingOperation.Status,
		|	ManufacturingOperation.Specification,
		|	WorkcentersAvailabilityPreliminary.Workcenter,
		|	WorkcentersAvailabilityPreliminary.WorkcenterType,
		|	WorkcentersAvailabilityPreliminary.Activity,
		|	WorkcentersAvailabilityPreliminary.ConnectionKey,
		|	ManufacturingOperationActivities.TimeUOM,
		|	WorkcentersAvailabilityPreliminary.StartDate,
		|	WorkcentersAvailabilityPreliminary.WorkloadTime
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ProductionSchedule.Operation AS Operation,
		|	ProductionSchedule.StartDate AS StartDate,
		|	ProductionSchedule.EndDate AS EndDate,
		|	ManufacturingOperation.Specification AS Specification,
		|	ManufacturingOperation.Status AS Status,
		|	ProductionSchedule.Activity AS Activity,
		|	ProductionSchedule.ConnectionKey AS ConnectionKey,
		|	ManufacturingOperationActivities.TimeUOM AS TimeUOM,
		|	DATEDIFF(ProductionSchedule.StartDate, ProductionSchedule.EndDate, MINUTE) AS WorkloadTime
		|INTO TT_WIPsWithoutWCT
		|FROM
		|	InformationRegister.ProductionSchedule AS ProductionSchedule
		|		INNER JOIN Document.ManufacturingOperation AS ManufacturingOperation
		|		ON ProductionSchedule.Operation = ManufacturingOperation.Ref
		|		INNER JOIN Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
		|		ON ProductionSchedule.Operation = ManufacturingOperationActivities.Ref
		|			AND ProductionSchedule.ConnectionKey = ManufacturingOperationActivities.ConnectionKey
		|WHERE
		|	ProductionSchedule.ProductionOrder = &ProductionOrder
		|	AND ProductionSchedule.ScheduleState = &ScheduleState
		|	AND NOT (ProductionSchedule.Operation, ProductionSchedule.ConnectionKey) IN
		|				(SELECT
		|					TT_WIPsWithWCT.Operation AS Operation,
		|					TT_WIPsWithWCT.ConnectionKey AS ConnectionKey
		|				FROM
		|					TT_WIPsWithWCT AS TT_WIPsWithWCT)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_WIPsWithWCT.StartDate AS StartDate,
		|	TT_WIPsWithWCT.EndDate AS EndDate,
		|	TT_WIPsWithWCT.Operation AS Operation,
		|	ISNULL(TT_WIPsWithWCT.Workcenter.Presentation, """") AS Workcenter,
		|	ISNULL(TT_WIPsWithWCT.WorkcenterType.Presentation, """") AS WorkcenterType,
		|	TT_WIPsWithWCT.Status AS Status,
		|	TT_WIPsWithWCT.Specification AS Specification,
		|	TT_WIPsWithWCT.Activity AS Activity,
		|	TT_WIPsWithWCT.TimeUOM AS TimeUOM,
		|	TT_WIPsWithWCT.ConnectionKey AS ConnectionKey,
		|	TT_WIPsWithWCT.WorkloadTime AS WorkloadTime
		|FROM
		|	TT_WIPsWithWCT AS TT_WIPsWithWCT
		|
		|UNION ALL
		|
		|SELECT
		|	TT_WIPsWithoutWCT.StartDate,
		|	TT_WIPsWithoutWCT.EndDate,
		|	TT_WIPsWithoutWCT.Operation,
		|	NULL,
		|	NULL,
		|	TT_WIPsWithoutWCT.Status,
		|	TT_WIPsWithoutWCT.Specification,
		|	TT_WIPsWithoutWCT.Activity,
		|	TT_WIPsWithoutWCT.TimeUOM,
		|	TT_WIPsWithoutWCT.ConnectionKey,
		|	TT_WIPsWithoutWCT.WorkloadTime
		|FROM
		|	TT_WIPsWithoutWCT AS TT_WIPsWithoutWCT
		|
		|ORDER BY
		|	Operation,
		|	ConnectionKey
		|TOTALS
		|	MAX(Activity)
		|BY
		|	Operation,
		|	ConnectionKey";
		
	EndIf;
	
	Query.SetParameter("ProductionOrder", ReportSettings.ProductionOrder);
	Query.SetParameter("ScheduleState", ReportSettings.ScheduleState);
	
	QueryResult = Query.Execute();
	
	SelectionWIP = QueryResult.Select(QueryResultIteration.ByGroups);
	
	While SelectionWIP.Next() Do
		
		PointWIP = GanttChart.SetPoint(SelectionWIP.Operation);
		PointWIP.Text = SelectionWIP.Operation;
		PointWIP.Details = SelectionWIP.Operation;
		
		SelectionActivity = SelectionWIP.Select(QueryResultIteration.ByGroups);
		
		While SelectionActivity.Next() Do
			
			PointUniqueValue = String(SelectionActivity.Operation) + SelectionActivity.Activity + SelectionActivity.ConnectionKey;
			Point = GanttChart.SetPoint(PointUniqueValue, SelectionActivity.Operation);
			Point.Text = SelectionActivity.Activity;
			Point.Details = SelectionActivity.Activity;
			
			SelectionDetailRecords = SelectionActivity.Select();
			
			While SelectionDetailRecords.Next() Do
				
				Series = GanttChart.SetSeries("ProductionSchedule");
				Series.BetweenIntervalsHatch = False;
				Series.OverlappedIntervalsHatch = True;
				
				Borders.Start = Min(Borders.Start, SelectionDetailRecords.StartDate);
				Borders.End = Max(Borders.End, SelectionDetailRecords.EndDate);
				
				Value = GanttChart.GetValue(Point, Series);
				OperationValue = Value.Add();
				OperationValue.Begin = SelectionDetailRecords.StartDate;
				OperationValue.End = SelectionDetailRecords.EndDate;
				OperationValue.Details = SelectionDetailRecords.Operation;
				OperationValue.Color = StatusColor(SelectionDetailRecords.Status);
				OperationValue.Text = WIPPresentation(OperationValue, SelectionDetailRecords);
				
			EndDo;
			
			GanttChart.ExpandPoint(Point, True);
			
		EndDo;
		
		GanttChart.ExpandPoint(PointWIP, True);
		
	EndDo;
	
	GanttChart.RefreshEnabled = False;
	
	If ValueIsFilled(Borders.End) Then
		
		GanttChart.SetWholeInterval(BegOfDay(Borders.Start), EndOfDay(Borders.End));
		SetBackgroundIntervals(GanttChart, ReportSettings);
		
	EndIf;
	
	Return PutToTempStorage(GanttChart);
	
EndFunction

&AtServerNoContext
Function SetPeriodicy(GanttChart, ProductionOrder)
	
	Format = NStr("en = 'DF=''MM/dd hh:mm tt'''; ru = 'DF=''dd.MM hh:mm tt''';pl = 'DF=''MM-dd hh:mm tt''';es_ES = 'DF=''dd/MM hh:mm tt''';es_CO = 'DF=''dd/MM hh:mm tt''';tr = 'DF=''dd.MM hh:mm tt''';it = 'DF=''MM/dd hh.mm tt''';de = 'DF=''dd.MM hh:mm tt'''");
	
	// Cleat time scale
	TimeScale = GanttChart.PlotArea.TimeScale.Items;
	
	For Index = 1 To TimeScale.Count() - 1 Do
		TimeScale.Delete(TimeScale[1]);
	EndDo;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ManufacturingOperationActivities.Activity AS Activity
	|INTO TT_Activities
	|FROM
	|	Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|		LEFT JOIN Document.ManufacturingOperation AS ManufacturingOperation
	|		ON ManufacturingOperationActivities.Ref = ManufacturingOperation.Ref
	|WHERE
	|	ManufacturingOperation.BasisDocument = &ProductionOrder
	|
	|INDEX BY
	|	Activity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(CASE
	|			WHEN BusinessUnits.PlanningInterval = VALUE(Enum.PlanningIntervals.Month)
	|				THEN 1
	|			WHEN BusinessUnits.PlanningInterval = VALUE(Enum.PlanningIntervals.Week)
	|				THEN 2
	|			WHEN BusinessUnits.PlanningInterval = VALUE(Enum.PlanningIntervals.Day)
	|				THEN 3
	|			WHEN BusinessUnits.PlanningInterval = VALUE(Enum.PlanningIntervals.Hour)
	|				THEN 4
	|			WHEN BusinessUnits.PlanningInterval = VALUE(Enum.PlanningIntervals.Minute)
	|				THEN 5
	|		END) AS PlanningInterval
	|FROM
	|	Catalog.ManufacturingActivities.WorkCenterTypes AS ManufacturingActivitiesWorkCenterTypes
	|		LEFT JOIN Catalog.CompanyResourceTypes AS CompanyResourceTypes
	|		ON ManufacturingActivitiesWorkCenterTypes.WorkcenterType = CompanyResourceTypes.Ref
	|		LEFT JOIN Catalog.BusinessUnits AS BusinessUnits
	|		ON (CompanyResourceTypes.BusinessUnit = BusinessUnits.Ref)
	|WHERE
	|	ManufacturingActivitiesWorkCenterTypes.Ref IN
	|			(SELECT
	|				TT_Activities.Activity AS Activity
	|			FROM
	|				TT_Activities AS TT_Activities)";
	
	Query.SetParameter("ProductionOrder", ProductionOrder);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		
		If ValueIsFilled(SelectionDetailRecords.PlanningInterval) Then
		
			// Month
			If SelectionDetailRecords.PlanningInterval <= 1 Then
				
				FirstItem = GanttChart.PlotArea.TimeScale.Items[0];
				FirstItem.Unit = TimeScaleUnitType.Month;
				FirstItem.PointLines = New Line(SpreadsheetDocumentCellLineType.Solid, 1);
				FirstItem.Format = NStr("en = 'DF=''MMMM yyyy'''; ru = 'DF=''MMMM yyyy''';pl = 'DF=''MMMM yyyy''';es_ES = 'DF=''MMMM yyyy''';es_CO = 'DF=''MMMM yyyy''';tr = 'DF=''MMMM yyyy''';it = 'DF=''MMMM yyyy''';de = 'DF=''MMMM yyyy'''");
				
				GanttChart.ScaleKeeping = GanttChartScaleKeeping.Period;
				GanttChart.PeriodicVariantRepetition = 2;
				GanttChart.PeriodicVariantUnit = TimeScaleUnitType.Month;
				
				Format = NStr("en = 'DF=''MMMM yyyy'''; ru = 'DF=''MMMM yyyy''';pl = 'DF=''MMMM yyyy''';es_ES = 'DF=''MMMM yyyy''';es_CO = 'DF=''MMMM yyyy''';tr = 'DF=''MMMM yyyy''';it = 'DF=''MMMM yyyy''';de = 'DF=''MMMM yyyy'''");
				
			// Week
			ElsIf SelectionDetailRecords.PlanningInterval <= 2 Then
				
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
				
				Format = NStr("en = 'DF=''dd MMMM'''; ru = 'DF=''dd MMMM''';pl = 'DF=''dd MMMM''';es_ES = 'DF=''dd MMMM''';es_CO = 'DF=''dd MMMM''';tr = 'DF=''dd MMMM''';it = 'DF=''dd MMMM''';de = 'DF=''dd MMMM'''");
				
			// Day
			ElsIf SelectionDetailRecords.PlanningInterval <= 3 Then
				
				FirstItem = GanttChart.PlotArea.TimeScale.Items[0];
				FirstItem.Unit = TimeScaleUnitType.Day;
				FirstItem.PointLines = New Line(SpreadsheetDocumentCellLineType.Solid, 1);
				FirstItem.DayFormat = TimeScaleDayFormat.MonthDayWeekDay;
				FirstItem.Format = NStr("en = 'DF=''dd MMMM'''; ru = 'DF=''dd MMMM''';pl = 'DF=''dd MMMM''';es_ES = 'DF=''dd MMMM''';es_CO = 'DF=''dd MMMM''';tr = 'DF=''dd MMMM''';it = 'DF=''dd MMMM''';de = 'DF=''dd MMMM'''");
				
				GanttChart.ScaleKeeping = GanttChartScaleKeeping.Period;
				GanttChart.PeriodicVariantRepetition = 12;
				GanttChart.PeriodicVariantUnit = TimeScaleUnitType.Day;
				
				Format = NStr("en = 'DF=''dd MMMM'''; ru = 'DF=''dd MMMM''';pl = 'DF=''dd MMMM''';es_ES = 'DF=''dd MMMM''';es_CO = 'DF=''dd MMMM''';tr = 'DF=''dd MMMM''';it = 'DF=''dd MMMM''';de = 'DF=''dd MMMM'''");
				
			// Hour
			Else
				
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
				
				Format = NStr("en = 'DF=''hh:mm tt'''; ru = 'DF=''hh:mm tt''';pl = 'DF=''hh:mm tt''';es_ES = 'DF=''hh:mm tt''';es_CO = 'DF=''hh:mm tt''';tr = 'DF=''hh:mm tt''';it = 'DF=hh:mm tt';de = 'DF=''hh:mm tt'''");
				
			EndIf;
		
		Else
		
			// No WCT
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
			GanttChart.PeriodicVariantRepetition = 15;
			GanttChart.PeriodicVariantUnit = TimeScaleUnitType.Hour;
			
			Format = NStr("en = 'DF=''hh:mm tt'''; ru = 'DF=''hh:mm tt''';pl = 'DF=''hh:mm tt''';es_ES = 'DF=''hh:mm tt''';es_CO = 'DF=''hh:mm tt''';tr = 'DF=''hh:mm tt''';it = 'DF=hh:mm tt';de = 'DF=''hh:mm tt'''");
			
		EndIf;
		
	EndIf;
	
	Return Format;
	
EndFunction

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
	
	If SelectionDetailRecords.WorkcenterType = Null Then
		Result = Result + NStr("en = 'Work center/Work center type: Do not applicable'; ru = 'Рабочий центр/тип рабочего центра: Не применять';pl = 'Gniazdo produkcyjne/Typ gniazda produkcyjnego: Nie dotyczy';es_ES = 'Centro de trabajo/tipo de centro de trabajo: No aplicable';es_CO = 'Centro de trabajo/tipo de centro de trabajo: No aplicable';tr = 'İş merkezi/İş merkezi türü: Uygulanamaz';it = 'Centro di lavoro/tipo centro di lavoro: non applicabile';de = 'Arbeitsabschnitt/Arbeitsabschnittstyp: nicht anwendbar'") + Chars.LF;
	Else
		StringWorkcenter = ?(SelectionDetailRecords.Workcenter = "", "", SelectionDetailRecords.Workcenter + " / ");
		StringWorkcenter = StringWorkcenter + SelectionDetailRecords.WorkcenterType;
		
		Result = Result + NStr("en = 'Work center/Work center type:'; ru = 'Рабочий центр/тип рабочего центра:';pl = 'Gniazdo produkcyjne/Typ gniazda produkcyjnego:';es_ES = 'Centro de trabajo/tipo de centro de trabajo:';es_CO = 'Centro de trabajo/tipo de centro de trabajo:';tr = 'İş merkezi/İş merkezi türü:';it = 'Centro di lavoro/ Tipo di centro di lavoro:';de = 'Arbeitsabschnitt/Arbeitsabschnittstyp:'") +" "+ StringWorkcenter + Chars.LF;
	EndIf;
	
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

&AtClient
Procedure SetReportEnabled(ReportGenerated)
	
	Items.DecorationNotGenerated.Visible = Not ReportGenerated;
	Items.GanttChart.Enabled = ReportGenerated;
	
EndProcedure

&AtServerNoContext
Procedure SetBackgroundIntervals(GanttChart, ReportSettings)
	
	NewBackIntervals = GanttChart.BackgroundIntervals.Add(GanttChart.BeginOfWholeInterval, GanttChart.EndOfWholeInterval);
	NewBackIntervals.Color = WebColors.Gainsboro;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ManufacturingActivitiesWorkCenterTypes.WorkcenterType AS WorkcenterType
		|INTO TT_WCT
		|FROM
		|	Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
		|		INNER JOIN Document.ManufacturingOperation AS ManufacturingOperation
		|		ON ManufacturingOperationActivities.Ref = ManufacturingOperation.Ref
		|		INNER JOIN Catalog.ManufacturingActivities.WorkCenterTypes AS ManufacturingActivitiesWorkCenterTypes
		|		ON ManufacturingOperationActivities.Activity = ManufacturingActivitiesWorkCenterTypes.Ref
		|WHERE
		|	ManufacturingOperation.BasisDocument = &BasisDocument
		|
		|GROUP BY
		|	ManufacturingActivitiesWorkCenterTypes.WorkcenterType
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DATEADD(WorkcentersAvailability.Date, MINUTE, DATEDIFF(DATETIME(1, 1, 1), WorkcentersAvailabilityIntervals.StartTime, MINUTE)) AS StartTime,
		|	DATEADD(WorkcentersAvailability.Date, MINUTE, DATEDIFF(DATETIME(1, 1, 1), WorkcentersAvailabilityIntervals.EndTime, MINUTE)) AS EndTime
		|FROM
		|	TT_WCT AS TT_WCT
		|		INNER JOIN Document.WorkcentersAvailability.Intervals AS WorkcentersAvailabilityIntervals
		|			INNER JOIN Document.WorkcentersAvailability AS WorkcentersAvailability
		|			ON WorkcentersAvailability.Ref = WorkcentersAvailabilityIntervals.Ref
		|		ON TT_WCT.WorkcenterType = WorkcentersAvailability.WorkcenterType
		|WHERE
		|	(DATEADD(WorkcentersAvailability.Date, MINUTE, DATEDIFF(DATETIME(1, 1, 1), WorkcentersAvailabilityIntervals.StartTime, MINUTE)) BETWEEN &StartTime AND &EndTime
		|			OR DATEADD(WorkcentersAvailability.Date, MINUTE, DATEDIFF(DATETIME(1, 1, 1), WorkcentersAvailabilityIntervals.EndTime, MINUTE)) BETWEEN &StartTime AND &EndTime
		|			OR DATEADD(WorkcentersAvailability.Date, MINUTE, DATEDIFF(DATETIME(1, 1, 1), WorkcentersAvailabilityIntervals.StartTime, MINUTE)) < &StartTime
		|				AND DATEADD(WorkcentersAvailability.Date, MINUTE, DATEDIFF(DATETIME(1, 1, 1), WorkcentersAvailabilityIntervals.EndTime, MINUTE)) > &EndTime)";
	
	Query.SetParameter("EndTime", GanttChart.EndOfWholeInterval);
	Query.SetParameter("StartTime", GanttChart.BeginOfWholeInterval);
	Query.SetParameter("BasisDocument", ReportSettings.ProductionOrder);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		NewBackIntervals = GanttChart.BackgroundIntervals.Add(SelectionDetailRecords.StartTime, SelectionDetailRecords.EndTime);
		NewBackIntervals.Color = WebColors.White;
		
	EndDo;
	
EndProcedure

#EndRegion