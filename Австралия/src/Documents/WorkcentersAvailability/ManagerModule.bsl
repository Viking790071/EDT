#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefWorkcentersAvailability, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.Text =
	"SELECT
	|	WorkcentersAvailabilityIntervals.LineNumber AS LineNumber,
	|	WorkcentersAvailability.Workcenter AS Workcenter,
	|	WorkcentersAvailabilityIntervals.StartTime AS StartTime,
	|	WorkcentersAvailabilityIntervals.EndTime AS EndTime,
	|	WorkcentersAvailabilityIntervals.Capacity AS Capacity,
	|	CompanyResourceTypes.BusinessUnit AS BusinessUnit,
	|	BEGINOFPERIOD(WorkcentersAvailability.Date, DAY) AS Date,
	|	WorkcentersAvailability.WorkcenterType AS WorkcenterType
	|INTO TT_Intervals
	|FROM
	|	Document.WorkcentersAvailability.Intervals AS WorkcentersAvailabilityIntervals
	|		LEFT JOIN Document.WorkcentersAvailability AS WorkcentersAvailability
	|		ON WorkcentersAvailabilityIntervals.Ref = WorkcentersAvailability.Ref
	|		LEFT JOIN Catalog.CompanyResourceTypes AS CompanyResourceTypes
	|		ON (WorkcentersAvailability.WorkcenterType = CompanyResourceTypes.Ref)
	|		LEFT JOIN Catalog.CompanyResources AS CompanyResources
	|		ON (WorkcentersAvailability.Workcenter = CompanyResources.Ref)
	|WHERE
	|	WorkcentersAvailability.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Intervals.LineNumber AS LineNumber,
	|	TT_Intervals.Date AS Date,
	|	TT_Intervals.WorkcenterType AS WorkcenterType,
	|	TT_Intervals.Workcenter AS Workcenter,
	|	TT_Intervals.StartTime AS StartTime,
	|	TT_Intervals.EndTime AS EndTime,
	|	TT_Intervals.Capacity AS Capacity,
	|	TT_Intervals.BusinessUnit AS BusinessUnit,
	|	BusinessUnits.PlanningInterval AS PlanningInterval,
	|	BusinessUnits.PlanningIntervalDuration AS PlanningIntervalDuration
	|FROM
	|	TT_Intervals AS TT_Intervals
	|		LEFT JOIN Catalog.BusinessUnits AS BusinessUnits
	|		ON TT_Intervals.BusinessUnit = BusinessUnits.Ref";
	
	Query.SetParameter("Ref", DocumentRefWorkcentersAvailability);
	
	TableWorkcentersAvailability = New ValueTable;
	TableWorkcentersAvailability.Columns.Add("Period", New TypeDescription("Date"));
	TableWorkcentersAvailability.Columns.Add("WorkcenterType", New TypeDescription("CatalogRef.CompanyResourceTypes"));
	TableWorkcentersAvailability.Columns.Add("Workcenter", New TypeDescription("CatalogRef.CompanyResources"));
	TableWorkcentersAvailability.Columns.Add("Available", New TypeDescription("Number", New NumberQualifiers(8, 0)));
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If SelectionDetailRecords.PlanningInterval = Enums.PlanningIntervals.Minute Then
			
			Interval = SelectionDetailRecords.PlanningIntervalDuration * 60;
			
			IntervalTime = BegOfMinute(SelectionDetailRecords.StartTime);
			While IntervalTime < SelectionDetailRecords.EndTime - 1 Do
				
				StartTime = Max(SelectionDetailRecords.StartTime, IntervalTime);
				EndTime = Min(BegOfMinute(IntervalTime) + Interval, SelectionDetailRecords.EndTime);
				
				IntervalDate = BegOfMinute(SelectionDetailRecords.Date + Hour(IntervalTime) * 3600 + Minute(IntervalTime) *60 + Second(IntervalTime));
				
				If Not ValueIsFilled(EndTime)
					Or EndOfMinute(EndTime) = '00010101235959' Then
					SecondsInInterval = EndOfMinute(EndTime) - StartTime + 1;
				Else
					SecondsInInterval = EndTime - StartTime;
				EndIf;
				
				WorkcentersAvailabilityLine = TableWorkcentersAvailability.Add();
				WorkcentersAvailabilityLine.Period = IntervalDate;
				WorkcentersAvailabilityLine.WorkcenterType = SelectionDetailRecords.WorkcenterType;
				WorkcentersAvailabilityLine.Workcenter = SelectionDetailRecords.Workcenter;
				WorkcentersAvailabilityLine.Available = (SecondsInInterval / 60 ) * SelectionDetailRecords.Capacity;
				
				IntervalTime = IntervalTime + Interval;
				
			EndDo;
			
		ElsIf SelectionDetailRecords.PlanningInterval = Enums.PlanningIntervals.Hour Then
			
			IntervalTime = BegOfHour(SelectionDetailRecords.StartTime);
			While IntervalTime < SelectionDetailRecords.EndTime - 1 Do
				
				StartTime = Max(SelectionDetailRecords.StartTime, IntervalTime);
				EndTime = Min(EndOfHour(IntervalTime) + 1, SelectionDetailRecords.EndTime);
				
				IntervalDate = BegOfHour(SelectionDetailRecords.Date + Hour(IntervalTime) * 3600 + Minute(IntervalTime) *60 + Second(IntervalTime));
				
				If Not ValueIsFilled(EndTime)
					Or EndOfMinute(EndTime) = '00010101235959' Then
					SecondsInInterval = EndOfDay(EndTime) - StartTime + 1;
				Else
					SecondsInInterval = EndTime - StartTime;
				EndIf;
				
				WorkcentersAvailabilityLine = TableWorkcentersAvailability.Add();
				WorkcentersAvailabilityLine.Period = IntervalDate;
				WorkcentersAvailabilityLine.WorkcenterType = SelectionDetailRecords.WorkcenterType;
				WorkcentersAvailabilityLine.Workcenter = SelectionDetailRecords.Workcenter;
				WorkcentersAvailabilityLine.Available = (SecondsInInterval / 60 ) * SelectionDetailRecords.Capacity;
				
				IntervalTime = IntervalTime + 3600;
				
			EndDo;
			
		Else
			
			If SelectionDetailRecords.PlanningInterval = Enums.PlanningIntervals.Day Then
				IntervalDate = BegOfDay(SelectionDetailRecords.Date);
			ElsIf SelectionDetailRecords.PlanningInterval = Enums.PlanningIntervals.Week Then
				IntervalDate = BegOfWeek(SelectionDetailRecords.Date);
			Else
				IntervalDate = BegOfMonth(SelectionDetailRecords.Date);
			EndIf;
			
			If Not ValueIsFilled(SelectionDetailRecords.EndTime)
				Or EndOfMinute(SelectionDetailRecords.EndTime) = '00010101235959' Then
				SecondsInInterval = EndOfDay(SelectionDetailRecords.EndTime) - SelectionDetailRecords.StartTime + 1;
			Else
				SecondsInInterval = SelectionDetailRecords.EndTime - SelectionDetailRecords.StartTime;
			EndIf;
			
			WorkcentersAvailabilityLine = TableWorkcentersAvailability.Add();
			WorkcentersAvailabilityLine.Period = IntervalDate;
			WorkcentersAvailabilityLine.WorkcenterType = SelectionDetailRecords.WorkcenterType;
			WorkcentersAvailabilityLine.Workcenter = SelectionDetailRecords.Workcenter;
			WorkcentersAvailabilityLine.Available = (SecondsInInterval / 60 ) * SelectionDetailRecords.Capacity;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableWorkcentersAvailability", TableWorkcentersAvailability);
	
EndProcedure

#EndRegion

#EndIf