#Region Public

Procedure MainPlanAndSaveSeveralOrders(StartPlanningSettings, ResultAddress) Export
	
	ReturnStructure = ReturnStructure();
	
	If CheckFilling(StartPlanningSettings, ReturnStructure.ListOfErrorsToShow) Then
		
		PlanningSettings = PlanningSettings(StartPlanningSettings);
		
		ReturnStructure = PlanSeveralOrders(PlanningSettings, True);
		
	Else
		
		ReturnStructure.ErrorsToShow = True;
		ReturnStructure.Delete("IntervalsTable");
		
	EndIf;
	
	ReturnStructure.ListOfErrorsToShow = CommonClientServer.CollapseArray(ReturnStructure.ListOfErrorsToShow);
	PutToTempStorage(ReturnStructure, ResultAddress);
	
EndProcedure

Procedure MainPlanOneOrder(StartPlanningSettings, ResultAddress) Export
	
	ReturnStructure = ReturnStructure();
	
	If CheckFilling(StartPlanningSettings, ReturnStructure.ListOfErrorsToShow) Then
		
		PlanningSettings = PlanningSettings(StartPlanningSettings);
		
		ReturnStructure = PlanSeveralOrders(PlanningSettings, False);
		
	Else
		
		ReturnStructure.ErrorsToShow = True;
		ReturnStructure.Delete("IntervalsTable");
		
	EndIf;
	
	ReturnStructure.ListOfErrorsToShow = CommonClientServer.CollapseArray(ReturnStructure.ListOfErrorsToShow);
	PutToTempStorage(ReturnStructure, ResultAddress);
	
EndProcedure

Procedure MainSaveOneOrder(PlanningSettings, ResultAddress) Export
	
	OrderSavingStructure = SaveOrderSchedule(PlanningSettings);
	
	PutToTempStorage(OrderSavingStructure, ResultAddress);
	
EndProcedure

Procedure MainCancelOneOrder(PlanningSettings, ResultAddress) Export
	
	OrderCancellationStructure = CancelOrderSchedule(PlanningSettings);
	
	PutToTempStorage(OrderCancellationStructure, ResultAddress);
	
EndProcedure

Procedure MarkWorkcentersAvailabilityForDeletion(JobSettings, ResultAddress) Export
	
	WorkcenterType = JobSettings.WorkcenterType;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	WorkcentersAvailability.Ref AS Ref
	|FROM
	|	Document.WorkcentersAvailability AS WorkcentersAvailability
	|WHERE
	|	WorkcentersAvailability.WorkcenterType = &WorkcenterType
	|	AND NOT WorkcentersAvailability.DeletionMark";
	
	Query.SetParameter("WorkcenterType", WorkcenterType);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		DocObject = SelectionDetailRecords.Ref.GetObject();
		DocObject.SetDeletionMark(True);
		InfobaseUpdate.WriteObject(DocObject);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Internal

Function MaxDateInArray(DatesArray) Export
	
	Result = Date('00010101000000');
	
	If DatesArray.Count() > 0 Then
	
		VL = New ValueList;
		VL.LoadValues(DatesArray);
		VL.SortByValue(SortDirection.Desc);
		
		Result = VL[0].Value;
		
	EndIf;

	Return Result;
	
EndFunction

Function MinDateInArray(DatesArray) Export
	
	Result = Date('00010101000000');
	
	If DatesArray.Count() > 0 Then
	
		VL = New ValueList;
		VL.LoadValues(DatesArray);
		VL.SortByValue(SortDirection.Asc);
		
		Result = VL[0].Value;
		
	EndIf;

	Return Result;
	
EndFunction

#EndRegion

#Region Private

#Region OrdersPlanning

Function PlanSeveralOrders(PlanningSettings, Save)
	
	ReturnStructure = ReturnStructure();
	ReturnStructure.PlannedSuccessfully = True;
	ReturnStructure.JobNumber = PlanningSettings.JobNumber;
	
	If PlanningSettings.StartedProductionOrders.Count() Then
		
		ReturnStructure.ErrorsToShow = True;
		
		For Each StartedProductionOrder In PlanningSettings.StartedProductionOrders Do
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'One or more operations of the %1 are in progress or completed and can not be scheduled or rescheduled.'; ru = 'Одна или несколько операций %1 в работе или завершены и не могут быть запланированы или перепланированы.';pl = 'Jedna lub więcej operacji %1 są w toku lub zakończone i nie mogą być zaplanowane lub przesunięte.';es_ES = 'Una o más operaciones del %1 están en progreso o han finalizado y no pueden ser programadas o reprogramadas.';es_CO = 'Una o más operaciones del %1 están en progreso o han finalizado y no pueden ser programadas o reprogramadas.';tr = 'Bir veya birkaç %1 işlemi devam ettiğinden veya tamamlandığından (yeniden) programlanamıyor.';it = 'Una o più operazioni di %1 sono in lavorazione o completate e non possono essere programmate o riprogrammate.';de = 'Eine oder mehr Operationen von %1 sind in Bearbeitung oder abgeschlossen und können nicht geplant oder neu geplant werden.'"),
				StartedProductionOrder);
			ReturnStructure.ListOfErrorsToShow.Add(MessageText);
			
		EndDo;
		
	EndIf;
	
	// By queue order
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProductionOrdersPriorities.ProductionOrder AS ProductionOrder
	|FROM
	|	InformationRegister.ProductionOrdersPriorities AS ProductionOrdersPriorities
	|WHERE
	|	ProductionOrdersPriorities.ProductionOrder IN(&ProductionOrders)
	|
	|ORDER BY
	|	ProductionOrdersPriorities.PriorityOrder,
	|	ProductionOrdersPriorities.Queue";
	
	Query.SetParameter("ProductionOrders", PlanningSettings.ProductionOrders);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		PlanningSettings.Insert("ProductionOrder", SelectionDetailRecords.ProductionOrder);
		OrderPlanningStructure = PlanOneOrder(PlanningSettings);
		
		UniteStructures(ReturnStructure, OrderPlanningStructure);
		
		If OrderPlanningStructure.PlannedSuccessfully Then
			
			OrderPlanningStructure.IntervalsTable.GroupBy("Operation, Activity, ConnectionKey, WorkcenterType, Workcenter, StartDate, EndDate, NoWCT", "WorkloadTime");
			
			ReflectWorkcentersAvailabilityPreliminary(OrderPlanningStructure.IntervalsTable);
			ReflectPreliminaryProductionSchedule(PlanningSettings.ProductionOrder, OrderPlanningStructure);
			
			If Save Then
				
				WIPs = OrderPlanningStructure.IntervalsTable.UnloadColumn("Operation");
				WIPs = CommonClientServer.CollapseArray(WIPs);
				
				Orders = New Array;
				Orders.Add(SelectionDetailRecords.ProductionOrder);
				
				SavingSettings = New Structure;
				SavingSettings.Insert("Orders", Orders);
				SavingSettings.Insert("OrdersToExclude", PlanningSettings.ProductionOrders);
				SavingSettings.Insert("WIPs", WIPs);
				SavingSettings.Insert("JobNumber", PlanningSettings.JobNumber);
				SavingSettings.Insert("PlanTheQueueByTheCurrentOne", PlanningSettings.PlanTheQueueByTheCurrentOne);
				
				OrderSavingStructure = SaveOrderSchedule(SavingSettings);
				If OrderSavingStructure.ErrorsInEventLog Then
					ReturnStructure.ErrorsInEventLog = True;
				EndIf;
				
			EndIf;
			
			ReturnStructure.Orders.Add(SelectionDetailRecords.ProductionOrder);
			
		Else
			
			Break;
			
		EndIf;
		
	EndDo;
	
	ReturnStructure.Delete("IntervalsTable");
	
	Return ReturnStructure;
	
EndFunction

Function PlanOneOrder(PlanningSettings)
	
	ReturnStructure = ReturnStructure();
	
	ProductionOrder = PlanningSettings.ProductionOrder;
	
	#Region TempTablesFilling
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ManufacturingOperation.Ref AS Ref,
	|	ManufacturingOperation.Specification AS Specification
	|INTO WIPs
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|WHERE
	|	ManufacturingOperation.BasisDocument = &ProductionOrder
	|	AND ManufacturingOperation.Posted
	|	AND ManufacturingOperation.Status = VALUE(Enum.ManufacturingOperationStatuses.Open)
	|	AND (&FullReplanning
	|			OR ManufacturingOperation.Ref IN
	|				(SELECT
	|					JobsForProductionScheduleCalculation.ManufacturingOperation AS ManufacturingOperation
	|				FROM
	|					InformationRegister.JobsForProductionScheduleCalculation AS JobsForProductionScheduleCalculation
	|				WHERE
	|					JobsForProductionScheduleCalculation.ProductionOrder = &ProductionOrder
	|					AND JobsForProductionScheduleCalculation.JobNumber <= &JobNumber))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WIPs.Specification AS Specification,
	|	ManufacturingOperationActivities.ActivityNumber AS ActivityNumber,
	|	ManufacturingOperationActivities.NextActivityNumber AS NextActivityNumber,
	|	ManufacturingOperationActivities.Activity AS Activity,
	|	ManufacturingOperationActivities.Quantity AS Quantity,
	|	ManufacturingOperationActivities.StandardTime AS StandardTime,
	|	ManufacturingOperationActivities.Ref AS WIP,
	|	ManufacturingOperationActivities.ConnectionKey AS ConnectionKey,
	|	ManufacturingOperationActivities.LineNumber AS LineNumber
	|INTO TemporaryTable
	|FROM
	|	WIPs AS WIPs
	|		INNER JOIN Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|		ON WIPs.Ref = ManufacturingOperationActivities.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTable.Specification AS Specification,
	|	TemporaryTable.ConnectionKey AS ConnectionKey,
	|	TemporaryTable.ActivityNumber AS ActivityNumber,
	|	TemporaryTable.NextActivityNumber AS NextActivityNumber,
	|	TemporaryTable.Activity AS Activity,
	|	TemporaryTable.Quantity AS Quantity,
	|	TemporaryTable.StandardTime AS StandardTime,
	|	TemporaryTable.WIP AS WIP,
	|	DATETIME(1, 1, 1, 0, 0, 0) AS EndDate,
	|	TemporaryTable.LineNumber AS LineNumber
	|FROM
	|	TemporaryTable AS TemporaryTable
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TemporaryTable.Specification AS ParentSpecification,
	|	BillsOfMaterialsContent.LineNumber AS LineNumber,
	|	BillsOfMaterialsContent.Specification AS ChildSpecification,
	|	DATETIME(1, 1, 1, 0, 0, 0) AS StartDate
	|FROM
	|	TemporaryTable AS TemporaryTable
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON TemporaryTable.Specification = BillsOfMaterialsContent.Ref
	|			AND TemporaryTable.ConnectionKey = BillsOfMaterialsContent.ActivityConnectionKey
	|
	|ORDER BY
	|	LineNumber DESC
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(ProductionOrderProducts.LineNumber) AS LineNumber,
	|	ProductionOrderProducts.Specification AS Specification
	|FROM
	|	Document.ProductionOrder.Products AS ProductionOrderProducts
	|WHERE
	|	ProductionOrderProducts.Ref = &ProductionOrder
	|
	|GROUP BY
	|	ProductionOrderProducts.Specification
	|
	|ORDER BY
	|	LineNumber DESC
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTable.Specification AS Specification,
	|	TemporaryTable.ActivityNumber AS ActivityNumber
	|FROM
	|	TemporaryTable AS TemporaryTable
	|
	|GROUP BY
	|	TemporaryTable.Specification,
	|	TemporaryTable.ActivityNumber
	|
	|ORDER BY
	|	Specification,
	|	ActivityNumber";
	
	Query.SetParameter("ProductionOrder", ProductionOrder);
	Query.SetParameter("JobNumber", PlanningSettings.JobNumber);
	Query.SetParameter("FullReplanning", PlanningSettings.FullReplanning);
	
	QueryResult = Query.ExecuteBatch();
	
	#EndRegion

	Operations = QueryResult[2].Unload();
	BOMsStructure = QueryResult[3].Unload();
	OrderSpecifications = QueryResult[4].Unload();
	OperationsSequence = QueryResult[5].Unload();
	
	OrderStartDate = Common.ObjectAttributeValue(ProductionOrder, "Start");
	PlanningSettings.Insert("StartDate", Max(PlanningSettings.CurrentDate, OrderStartDate));
	
	WIPs = Operations.UnloadColumn("WIP");
	ReturnStructure.WIPs = CommonClientServer.CollapseArray(WIPs);
	
	If WIPs.Count() Then
	
		// Queue of specifications in back order
		Queue = New ValueList;
		For Each OrderSpecificationLine In OrderSpecifications Do
			
			Queue.Add(OrderSpecificationLine.Specification);
			AddChildSpecificationsToQueue(OrderSpecificationLine.Specification, Queue, BOMsStructure);
			
		EndDo;
		
		// By specifications - successively
		Index = Queue.Count() - 1;
		While Index >= 0 Do
			
			SpecificationToPlan = Queue[Index].Value;
			
			// Queue of operations of BOM
			Filter = New Structure;
			Filter.Insert("Specification", SpecificationToPlan);
			
			SpecificationOperations = Operations.Copy(Filter);
			
			OperationsQueue = OperationsSequence.FindRows(Filter);
			
			// By operation number: if numbers are the same - simultaneously, else - successively
			For Each OperationsQueueLine In OperationsQueue Do
				
				StartDate = PlanningSettings.StartDate;
				
				ActivityNumberFilter = New Structure;
				ActivityNumberFilter.Insert("ActivityNumber", OperationsQueueLine.ActivityNumber);
				
				OperationsWithNumber = SpecificationOperations.FindRows(ActivityNumberFilter);
				
				For Each OperationWithNumberLine In OperationsWithNumber Do
					
					// Firstly, find child specification end date.
					ParentFilter = New Structure;
					ParentFilter.Insert("ParentSpecification", OperationWithNumberLine.Specification);
					
					BOMsStructureLines = BOMsStructure.FindRows(ParentFilter);
					For Each BOMsStructureLine In BOMsStructureLines Do
						If ValueIsFilled(BOMsStructureLine.StartDate) Then
							StartDate = Max(StartDate, BOMsStructureLine.StartDate);
						EndIf;
					EndDo;
					
					// If it is "next operation" with this number, then new start time
					NextOperationFilter = New Structure;
					NextOperationFilter.Insert("NextActivityNumber", OperationsQueueLine.ActivityNumber);
					
					PrevOperations = SpecificationOperations.FindRows(NextOperationFilter);
					If PrevOperations.Count() Then
						For Each PreviousOperation In PrevOperations Do
							If ValueIsFilled(PreviousOperation.EndDate) Then
								StartDate = Max(StartDate, PreviousOperation.EndDate);
							EndIf;
						EndDo;
					EndIf;
					
					// By quantity - simultaneously
					
					QuantityLeft = OperationWithNumberLine.Quantity;
					SameWIPQuantity = False;
					Workcenter = Catalogs.CompanyResources.EmptyRef();
					While QuantityLeft > 0 Do
						
						QuantityToPlan = ?(QuantityLeft > 1, 1, QuantityLeft);
						
						If OperationWithNumberLine.StandardTime = 0 Then
							
							IntervalLine = ReturnStructure.IntervalsTable.Add();
							IntervalLine.StartDate = StartDate;
							IntervalLine.EndDate = StartDate;
							IntervalLine.WorkloadTime = 0;
							IntervalLine.Operation = OperationWithNumberLine.WIP;
							IntervalLine.Activity = OperationWithNumberLine.Activity;
							IntervalLine.ConnectionKey = OperationWithNumberLine.ConnectionKey;
							
							OperationWithNumberLine.EndDate = Max(OperationWithNumberLine.EndDate, IntervalLine.EndDate);
							
						Else
							
							OperationSettings = New Structure();
							OperationSettings.Insert("WIP", OperationWithNumberLine.WIP);
							OperationSettings.Insert("Activity", OperationWithNumberLine.Activity);
							OperationSettings.Insert("ConnectionKey", OperationWithNumberLine.ConnectionKey);
							OperationSettings.Insert("WorkloadTime", QuantityToPlan * OperationWithNumberLine.StandardTime);
							OperationSettings.Insert("StartDate", StartDate);
							OperationSettings.Insert("SameWIPQuantity", SameWIPQuantity);
							OperationSettings.Insert("Workcenter", Workcenter);
							OperationSettings.Insert("TotalWorkloadTime", QuantityLeft * OperationWithNumberLine.StandardTime);
							
							OperationStructure = PlanOperation(PlanningSettings, OperationSettings);
							
							UniteStructures(ReturnStructure, OperationStructure);
							EndDate = MaxDateInTable(OperationStructure.IntervalsTable);
							
							OperationWithNumberLine.EndDate = Max(OperationWithNumberLine.EndDate, EndDate);
							
							OperationWithNumberLine.EndDate = Max(OperationWithNumberLine.EndDate, EndDate);
							
							OperationStructure.Property("Workcenter", Workcenter);
							
						EndIf;
						
						QuantityLeft = QuantityLeft - QuantityToPlan;
						SameWIPQuantity = True;
						
					EndDo;
					
					// Fill parent specification start
					ChildFilter = New Structure;
					ChildFilter.Insert("ChildSpecification", OperationWithNumberLine.Specification);
					
					BOMsStructureLines = BOMsStructure.FindRows(ChildFilter);
					For Each BOMsStructureLine In BOMsStructureLines Do
						BOMsStructureLine.StartDate = Max(BOMsStructureLine.StartDate, OperationWithNumberLine.EndDate);
					EndDo;
					
				EndDo;
				
			EndDo;
			
			Index = Index - 1;
			
		EndDo;
		
		If Not ReturnStructure.ErrorsToShow Then
			ReturnStructure.PlannedSuccessfully = True;
		EndIf;
		
	Else
		
		ReturnStructure.PlannedSuccessfully = True;
		ReturnStructure.ErrorsToShow = True;
		
		ErrorText = ProductionPlanningClientServer.ErrorTextNothingToPlan(ProductionOrder);
		
		ReturnStructure.ListOfErrorsToShow.Add(ErrorText);
		
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

#Region Records

Procedure ReflectPreliminaryProductionSchedule(ProductionOrder, OrderPlanningStructure)
	
	For Each WIP In OrderPlanningStructure.WIPs Do
		
		Filter = New Structure;
		Filter.Insert("Operation", WIP);
		
		WIPIntervals = OrderPlanningStructure.IntervalsTable.Copy(Filter);
		
		ActivitiesTable = WIPIntervals.Copy();
		ActivitiesTable.GroupBy("Activity, ConnectionKey");
		
		For Each ActivitiesTableLine In ActivitiesTable Do
			
			Filter = New Structure;
			Filter.Insert("ConnectionKey", ActivitiesTableLine.ConnectionKey);
			
			ActivityIntervals = WIPIntervals.Copy(Filter);
			
			Record = InformationRegisters.ProductionSchedule.CreateRecordManager();
			Record.ProductionOrder = ProductionOrder;
			Record.ScheduleState = 1;
			Record.Operation = WIP;
			Record.Activity = ActivitiesTableLine.Activity;
			Record.ConnectionKey = ActivitiesTableLine.ConnectionKey;
			Record.StartDate = MinDateInArray(ActivityIntervals.UnloadColumn("StartDate"));
			Record.EndDate = MaxDateInArray(ActivityIntervals.UnloadColumn("EndDate"));
			
			Record.Write(True);
		
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure ReflectWorkcentersAvailabilityPreliminary(IntervalsTable)
	
	WorkcentersAvailabilityPreliminary = InformationRegisters.WorkcentersAvailabilityPreliminary.CreateRecordSet();
	
	Filter = New Structure;
	Filter.Insert("NoWCT", False);
	
	WorkcentersAvailabilityPreliminary.Load(IntervalsTable.Copy(Filter));
	
	WorkcentersAvailabilityPreliminary.Write(True);
	
EndProcedure

#EndRegion

#Region Queues

Procedure AddChildSpecificationsToQueue(ParentSpecification, Queue, BOMsStructure)
	
	Filter = New Structure;
	Filter.Insert("ParentSpecification", ParentSpecification);
	
	Children = BOMsStructure.FindRows(Filter);
	
	For Each ChildLine In Children Do
		
		If ValueIsFilled(ChildLine.ChildSpecification) Then
			
			Queue.Add(ChildLine.ChildSpecification);
			AddChildSpecificationsToQueue(ChildLine.ChildSpecification, Queue, BOMsStructure);
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region AvailabilityTable

Function PrepareQueryAvailabilityTable(PlanningSettings)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ManufacturingOperation.BasisDocument AS BasisDocument,
		|	ManufacturingOperation.Ref AS Ref
		|INTO TT_WIPs
		|FROM
		|	Document.ManufacturingOperation AS ManufacturingOperation
		|WHERE
		|	CASE
		|			WHEN &FullReplanning
		|				THEN ManufacturingOperation.BasisDocument IN (&ProductionOrders)
		|						AND ManufacturingOperation.Posted
		|						AND ManufacturingOperation.Status = VALUE(Enum.ManufacturingOperationStatuses.Open)
		|			ELSE ManufacturingOperation.Ref IN
		|					(SELECT
		|						JobsForProductionScheduleCalculation.ManufacturingOperation AS ManufacturingOperation
		|					FROM
		|						InformationRegister.JobsForProductionScheduleCalculation AS JobsForProductionScheduleCalculation
		|					WHERE
		|						JobsForProductionScheduleCalculation.ProductionOrder IN (&ProductionOrders)
		|						AND JobsForProductionScheduleCalculation.JobNumber <= &JobNumber)
		|		END
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ManufacturingOperationActivities.Activity AS Activity,
		|	ManufacturingOperationActivities.Ref AS WIP,
		|	TT_WIPs.BasisDocument AS BasisDocument
		|INTO TT_Activities
		|FROM
		|	Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
		|		INNER JOIN TT_WIPs AS TT_WIPs
		|		ON (TT_WIPs.Ref = ManufacturingOperationActivities.Ref)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ManufacturingActivitiesWorkCenterTypes.WorkcenterType AS WorkcenterType
		|INTO WCTs
		|FROM
		|	Catalog.ManufacturingActivities.WorkCenterTypes AS ManufacturingActivitiesWorkCenterTypes
		|WHERE
		|	ManufacturingActivitiesWorkCenterTypes.Ref IN
		|			(SELECT
		|				TT_Activities.Activity AS Activity
		|			FROM
		|				TT_Activities AS TT_Activities)
		|
		|INDEX BY
		|	WorkcenterType
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorkcentersAvailabilityTurnovers.Period AS Period,
		|	WorkcentersAvailabilityTurnovers.WorkcenterType AS WorkcenterType,
		|	CASE
		|		WHEN CompanyResourceTypes.PlanningOnWorkcentersLevel
		|			THEN WorkcentersAvailabilityTurnovers.Workcenter
		|		ELSE VALUE(Catalog.CompanyResources.EmptyRef)
		|	END AS Workcenter,
		|	SUM(WorkcentersAvailabilityTurnovers.AvailableTurnover - WorkcentersAvailabilityTurnovers.UsedTurnover) AS Available
		|FROM
		|	AccumulationRegister.WorkcentersAvailability.Turnovers(
		|			&Start,
		|			&End,
		|			Recorder,
		|			WorkcenterType IN
		|				(SELECT
		|					WCTs.WorkcenterType AS WorkcenterType
		|				FROM
		|					WCTs AS WCTs)) AS WorkcentersAvailabilityTurnovers
		|		LEFT JOIN Catalog.CompanyResourceTypes AS CompanyResourceTypes
		|		ON WorkcentersAvailabilityTurnovers.WorkcenterType = CompanyResourceTypes.Ref
		|WHERE
		|	NOT WorkcentersAvailabilityTurnovers.Recorder IN
		|				(SELECT
		|					TT_Activities.WIP AS WIP
		|				FROM
		|					TT_Activities AS TT_Activities)
		|
		|GROUP BY
		|	WorkcentersAvailabilityTurnovers.Period,
		|	WorkcentersAvailabilityTurnovers.WorkcenterType,
		|	CASE
		|		WHEN CompanyResourceTypes.PlanningOnWorkcentersLevel
		|			THEN WorkcentersAvailabilityTurnovers.Workcenter
		|		ELSE VALUE(Catalog.CompanyResources.EmptyRef)
		|	END
		|
		|ORDER BY
		|	Period,
		|	WorkcenterType,
		|	Workcenter";
	
	Query.SetParameter("ProductionOrders", PlanningSettings.ProductionOrders);
	Query.SetParameter("JobNumber", PlanningSettings.JobNumber);
	Query.SetParameter("FullReplanning", PlanningSettings.FullReplanning);
	
	Query.SetParameter("Start", PlanningSettings.Start);
	PlanningHorizon = Constants.PlanningHorizon.Get();
	Query.SetParameter("End", EndOfDay(PlanningSettings.Start + 24 * 60 * 60 * PlanningHorizon));
	
	Return Query;
	
EndFunction

#EndRegion

#Region OneOperationPlanning

// Plan one activity
Function PlanOperation(PlanningSettings, OperationSettings)
	
	ReturnStructure = ReturnStructure();
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ManufacturingActivitiesWorkCenterTypes.WorkcenterType AS WorkcenterType,
	|	CompanyResourceTypes.PlanningOnWorkcentersLevel AS PlanningOnWorkcentersLevel,
	|	CompanyResourceTypes.EachOperationForSingleWC AS EachOperationForSingleWC
	|FROM
	|	Catalog.ManufacturingActivities.WorkCenterTypes AS ManufacturingActivitiesWorkCenterTypes
	|		LEFT JOIN Catalog.CompanyResourceTypes AS CompanyResourceTypes
	|		ON ManufacturingActivitiesWorkCenterTypes.WorkcenterType = CompanyResourceTypes.Ref
	|WHERE
	|	ManufacturingActivitiesWorkCenterTypes.Ref = &Activity";
	
	Query.SetParameter("Activity", OperationSettings.Activity);
	
	WCT = Query.Execute().Unload();
	
	If WCT.Count() = 0 Then
		
		CompanyCalendar = CompanyCalendar(OperationSettings);
		
		If ValueIsFilled(CompanyCalendar) Then
			
			NoWCTReturnStructure = PlanOperationWithNoWCT(OperationSettings, CompanyCalendar);
			UniteStructures(ReturnStructure, NoWCTReturnStructure);
			
		Else
			
			IntervalLine = ReturnStructure.IntervalsTable.Add();
			IntervalLine.StartDate = OperationSettings.StartDate;
			IntervalLine.EndDate = OperationSettings.StartDate + OperationSettings.WorkloadTime * 60;
			IntervalLine.WorkloadTime = OperationSettings.WorkloadTime;
			IntervalLine.Operation = OperationSettings.WIP;
			IntervalLine.Activity = OperationSettings.Activity;
			IntervalLine.ConnectionKey = OperationSettings.ConnectionKey;
			IntervalLine.NoWCT = True;
			
		EndIf;
		
	ElsIf WCT.Count() = 1 Then
		
		OperationSettings.Insert("WorkcenterType", WCT[0].WorkcenterType);
		OperationSettings.Insert("PlanningOnWorkcentersLevel", WCT[0].PlanningOnWorkcentersLevel);
		OperationSettings.Insert("EachOperationForSingleWC", WCT[0].EachOperationForSingleWC);
		
		OneWCTReturnStructure = PlanOperationPerOneWCT(PlanningSettings, OperationSettings);
		UniteStructures(ReturnStructure, OneWCTReturnStructure);
		
	Else
		
		OperationSettings.Insert("WorkcenterTypes", WCT.UnloadColumn("WorkcenterType"));
		
		SeveralWCTReturnStructure = PlanOperationPerSeveralWCT(PlanningSettings, OperationSettings);
		UniteStructures(ReturnStructure, SeveralWCTReturnStructure);
		
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

// Plan one operation with no WCT
Function PlanOperationWithNoWCT(OperationSettings, CompanyCalendar)
	
	ReturnStructure = ReturnStructure();
	
	PlanningHorizon = Constants.PlanningHorizon.Get();
	
	WorkSchedulesForPeriod = CalendarSchedules.WorkSchedulesForPeriod(
		CompanyCalendar,
		BegOfDay(OperationSettings.StartDate),
		OperationSettings.StartDate + PlanningHorizon * 24 * 3600);
	
	WorkSchedulesCount = WorkSchedulesForPeriod.Count();
	
	TimeLeft = OperationSettings.WorkloadTime;
	Index = 0;
	StartDate = OperationSettings.StartDate;
	
	While TimeLeft > 0 And Index < WorkSchedulesCount Do
		
		WorkScheduleLine = WorkSchedulesForPeriod[Index];
		
		ScheduleStartDate = WorkScheduleLine.ScheduleDate + (WorkScheduleLine.BeginTime - Date(1, 1, 1));
		ScheduleEndDate = WorkScheduleLine.ScheduleDate + (WorkScheduleLine.EndTime - Date(1, 1, 1));
		
		If StartDate <= ScheduleStartDate Then
			StartDate = ScheduleStartDate;
		ElsIf StartDate >= ScheduleEndDate Then
			Index = Index + 1;
			Continue;
		EndIf;
		
		Available = (ScheduleEndDate - StartDate) / 60;
		
		If Available > TimeLeft Then
			
			WorkloadTime = TimeLeft;
			EndDate = StartDate + (TimeLeft * 60);
			TimeLeft = 0;
			
		Else
			
			WorkloadTime = Available;
			EndDate = ScheduleEndDate;
			TimeLeft = TimeLeft - WorkloadTime;
			
		EndIf;
		
		NewInterval = ReturnStructure.IntervalsTable.Add();
		NewInterval.Operation = OperationSettings.WIP;
		NewInterval.StartDate = StartDate;
		NewInterval.EndDate = EndDate;
		NewInterval.WorkloadTime = WorkloadTime;
		NewInterval.NoWCT = True;
		NewInterval.Activity = OperationSettings.Activity;
		NewInterval.ConnectionKey = OperationSettings.ConnectionKey;
		
		Index = Index + 1;
		
	EndDo;
	
	If TimeLeft > 0 Then
		
		AddMessageNotEnoughtTimeOnCalendar(ReturnStructure, CompanyCalendar);
		
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

// Plan one operation with one WCT
Function PlanOperationPerOneWCT(PlanningSettings, OperationSettings)
	
	ReturnStructure = ReturnStructure();
	
	If WCTHasEnoughTime(PlanningSettings, OperationSettings) Then
		
		BusinessUnit = Common.ObjectAttributeValue(OperationSettings.WorkcenterType, "BusinessUnit");
		BUAttributes = Common.ObjectAttributesValues(BusinessUnit, "PlanningInterval, PlanningIntervalDuration");
		PlanningInterval = BUAttributes.PlanningInterval;
		PlanningIntervalDuration = BUAttributes.PlanningIntervalDuration;
		
		TimeLeft = OperationSettings.WorkloadTime;
		
		Filter = New Structure;
		Filter.Insert("WorkcenterType", OperationSettings.WorkcenterType);
		
		WorkcenterAvailability = FilterWithSort(PlanningSettings.Availability, Filter);
		
		Index = 0;
		WorkcenterAvailabilityCount = WorkcenterAvailability.Count();
		
		StartDate = OperationSettings.StartDate;
		
		CheckWorkcenter = OperationSettings.PlanningOnWorkcentersLevel;
		EachOperationForSingleWC = OperationSettings.EachOperationForSingleWC;
		
		If CheckWorkcenter And EachOperationForSingleWC
				And OperationSettings.SameWIPQuantity Then
				
			Workcenter = ?(OperationSettings.Workcenter = Undefined,
				Catalogs.CompanyResources.EmptyRef(),
				OperationSettings.Workcenter);
				
		Else
			Workcenter = Catalogs.CompanyResources.EmptyRef();
		EndIf;
		
		While TimeLeft > 0 And Index < WorkcenterAvailabilityCount Do
			
			If Not CheckWorkcenter
				Or Workcenter.IsEmpty()
				Or Workcenter = WorkcenterAvailability[Index].Workcenter Then

				Available = WorkcenterAvailability[Index].Available;
				If Available > 0 AND WorkcenterAvailability[Index].Period >= StartDate Then
					
					If CheckWorkcenter And Workcenter.IsEmpty() Then
						
						If Not WCHasEnoughTime(PlanningSettings,
												OperationSettings,
												WorkcenterAvailability[Index].Workcenter,
												EachOperationForSingleWC) Then
							
							Index = Index + 1;
							Continue;
							
						EndIf;
						
					EndIf;
					
					If Available >= TimeLeft Then 
						
						WorkloadTime = TimeLeft;
						WorkcenterAvailability[Index].Available = Available - TimeLeft;
						TimeLeft = 0;
						
					Else
						
						WorkloadTime = Available;
						WorkcenterAvailability[Index].Available = 0;
						TimeLeft = TimeLeft - WorkloadTime;
						
					EndIf;
					
					NewInterval = ReturnStructure.IntervalsTable.Add();
					NewInterval.Operation = OperationSettings.WIP;
					NewInterval.Activity = OperationSettings.Activity;
					NewInterval.ConnectionKey = OperationSettings.ConnectionKey;
					NewInterval.WorkcenterType = OperationSettings.WorkcenterType;
					
					If CheckWorkcenter Then
						NewInterval.Workcenter = WorkcenterAvailability[Index].Workcenter;
						Workcenter = NewInterval.Workcenter;
					EndIf;
					
					NewInterval.StartDate = WorkcenterAvailability[Index].Period;
					NewInterval.EndDate = ProductionPlanningClientServer.EndOfPlanningInterval(
						NewInterval.StartDate,
						PlanningInterval,
						PlanningIntervalDuration);
					NewInterval.WorkloadTime = WorkloadTime;
					
					StartDate = NewInterval.EndDate;
					
				EndIf;
				
			EndIf;
			
			Index = Index + 1;
			
		EndDo;
		
		If TimeLeft > 0 Then
			
			AddMessageNotEnoughtTimeOnWCT(ReturnStructure, OperationSettings.WorkcenterType);
			
		EndIf;
		
		If CheckWorkcenter And OperationSettings.EachOperationForSingleWC Then
			ReturnStructure.Insert("Workcenter", Workcenter);
		EndIf;
		
	Else
		
		AddMessageNotEnoughtTimeOnWCT(ReturnStructure, OperationSettings.WorkcenterType);
		
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

// Plan one operation with several WCT
Function PlanOperationPerSeveralWCT(PlanningSettings, OperationSettings)
	
	ReturnStructure = ReturnStructure();
	
	TimeLeft = OperationSettings.WorkloadTime;
	
	WorkcenterAvailability = PlanningSettings.Availability;
	
	FirstWorkcenter = Undefined;
	
	Index = 0;
	WorkcenterAvailabilityCount = WorkcenterAvailability.Count();
	
	While TimeLeft > 0 And Index < WorkcenterAvailabilityCount Do
		
		Available = WorkcenterAvailability[Index].Available;
		WorkcenterType = WorkcenterAvailability[Index].WorkcenterType;
		
		If OperationSettings.WorkcenterTypes.Find(WorkcenterType) <> Undefined
			And Available > 0
			And WorkcenterAvailability[Index].Period >= OperationSettings.StartDate Then
			
			// Per one WorkcenterType - successively, different - simultaneously
			Filter = New Structure;
			Filter.Insert("WorkcenterType", WorkcenterType);
			IntervalsTable = ReturnStructure.IntervalsTable.Copy(Filter);
			If IntervalsTable.Count() Then
				StartDate = MaxDateInTable(IntervalsTable);
			Else
				StartDate = OperationSettings.StartDate;
			EndIf;
			
			If WorkcenterAvailability[Index].Period >= StartDate Then
				
				PlanningOnWorkcentersLevel = Common.ObjectAttributeValue(WorkcenterType, "PlanningOnWorkcentersLevel");
				
				If Available >= TimeLeft Then
					
					WorkloadTime = TimeLeft;
					WorkcenterAvailability[Index].Available = Available - TimeLeft;
					TimeLeft = 0;
					
				Else
					
					WorkloadTime = Available;
					WorkcenterAvailability[Index].Available = 0;
					TimeLeft = TimeLeft - WorkloadTime;
					
				EndIf;
				
				NewInterval = ReturnStructure.IntervalsTable.Add();
				NewInterval.Operation = OperationSettings.WIP;
				NewInterval.Activity = OperationSettings.Activity;
				NewInterval.ConnectionKey = OperationSettings.ConnectionKey;
				NewInterval.WorkcenterType = WorkcenterType;
				
				If PlanningOnWorkcentersLevel Then
					NewInterval.Workcenter = WorkcenterAvailability[Index].Workcenter;
				EndIf;
				
				NewInterval.StartDate = WorkcenterAvailability[Index].Period;
				
				BusinessUnit = Common.ObjectAttributeValue(WorkcenterType, "BusinessUnit");
				BUAttributes = Common.ObjectAttributesValues(BusinessUnit, "PlanningInterval, PlanningIntervalDuration");
				NewInterval.EndDate = ProductionPlanningClientServer.EndOfPlanningInterval(
					NewInterval.StartDate,
					BUAttributes.PlanningInterval,
					BUAttributes.PlanningIntervalDuration);
				
				NewInterval.WorkloadTime = WorkloadTime;
			
			EndIf;
			
		EndIf;
		
		Index = Index + 1;
		
	EndDo;
	
	If TimeLeft > 0 Then
		
		AddMessageNotEnoughtTimeOnWCTs(ReturnStructure, OperationSettings.WorkcenterTypes);
		
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

// Check total available time on work center type
Function WCTHasEnoughTime(PlanningSettings, OperationSettings)
	
	Result = False;
	
	Filter = New Structure;
	Filter.Insert("WorkcenterType", OperationSettings.WorkcenterType);
	
	WorkcenterIntervals = PlanningSettings.Availability.Copy(Filter, "Period, Available");
	
	If WorkcenterIntervals.Count() Then
	
		TotalAvailable = WorkcenterIntervals.Total("Available");
		
		If TotalAvailable >= OperationSettings.WorkloadTime Then
			
			For Each WorkcenterIntervalsLine In WorkcenterIntervals Do
				
				If WorkcenterIntervalsLine.Period <= OperationSettings.StartDate Then
					TotalAvailable = TotalAvailable - WorkcenterIntervalsLine.Available;
				Else
					Break;
				EndIf;
				
			EndDo;
			
			Result = (TotalAvailable >= OperationSettings.WorkloadTime);
			
		EndIf;
	
	EndIf;
	
	Return Result;
	
EndFunction

// Check total available time on work center
Function WCHasEnoughTime(PlanningSettings, OperationSettings, Workcenter, EachOperationForSingleWC)
	
	Result = False;
	
	Filter = New Structure;
	Filter.Insert("WorkcenterType", OperationSettings.WorkcenterType);
	Filter.Insert("Workcenter", Workcenter);
	
	WorkloadTime = ?(EachOperationForSingleWC, OperationSettings.TotalWorkloadTime, OperationSettings.WorkloadTime);
	
	WorkcenterIntervals = PlanningSettings.Availability.Copy(Filter, "Period, Available");
	
	If WorkcenterIntervals.Count() Then
	
		TotalAvailable = WorkcenterIntervals.Total("Available");
		
		If TotalAvailable >= WorkloadTime Then
			
			For Each WorkcenterIntervalsLine In WorkcenterIntervals Do
				
				If WorkcenterIntervalsLine.Period <= OperationSettings.StartDate Then
					TotalAvailable = TotalAvailable - WorkcenterIntervalsLine.Available;
				Else
					Break;
				EndIf;
				
			EndDo;
			
			Result = (TotalAvailable >= WorkloadTime);
			
		EndIf;
	
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndRegion

#Region OrdersSaving

Function SaveOrderSchedule(PlanningSettings)
	
	ReturnStructure = SavingReturnStructure();
	
	WIPs = PlanningSettings.WIPs;
	
	BeginTransaction();
	
	Try
		
		For Each ProductionOrder In PlanningSettings.Orders Do
			
			// ProductionSchedule register
			WriteWorkProductionSchedule(ProductionOrder, WIPs);
			
			// WorkcentersSchedule register
			WriteWorkcentersSchedule(ProductionOrder, WIPs);
			
			ReflectWorkcentersAvailabilityFromPreliminary(ProductionOrder, WIPs, ReturnStructure);
			
			InformationRegisters.JobsForProductionScheduleCalculation.DeleteJobs(ProductionOrder, PlanningSettings.JobNumber);
			
		EndDo;
		
		InformationRegisters.JobsForProductionScheduleCalculation.CheckWIPsQueue(WIPs, PlanningSettings.OrdersToExclude);
		
		CommitTransaction();
		
	Except
		
		ReturnStructure.ErrorsInEventLog = True;
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot save planning schedule for ""%1"". Details: %2'; ru = 'Не удается сохранить график планирования для ""%1"". Подробнее: %2';pl = 'Nie można zapisać harmonogramu planowania dla ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el programa de planificación para ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el programa de planificación para ""%1"". Detalles: %2';tr = '""%1"" için planlama takvimi kaydedilemiyor. Ayrıntılar: %2';it = 'Impossibile salvare il grafico di programmazione per ""%1"". Dettagli: %2';de = 'Fehler beim Speichern der Terminplanung für ""%1. Details: %2'", CommonClientServer.DefaultLanguageCode()),
			ValueToStringInternal(PlanningSettings.Orders),
			BriefErrorDescription(ErrorInfo()));
		
		WriteLogEvent(
			NStr("en = 'Production schedule.Planning'; ru = 'Производственный график.Планирование';pl = 'Harmonogram produkcji.Planowanie';es_ES = 'Production schedule.Planning';es_CO = 'Production schedule.Planning';tr = 'Planlama takvimi.Planlama';it = 'Pianificazione di produzione.Pianificazione';de = 'Produktionsplan.Planung'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			Metadata.Documents.ProductionOrder,
			,
			ErrorDescription);
		
		RollbackTransaction();
		
	EndTry;
	
	Return ReturnStructure;
	
EndFunction

Procedure WriteWorkProductionSchedule(ProductionOrder, WIPs)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ProductionSchedule.ProductionOrder AS ProductionOrder,
		|	0 AS ScheduleState,
		|	ProductionSchedule.Operation AS Operation,
		|	ProductionSchedule.Activity AS Activity,
		|	ProductionSchedule.ConnectionKey AS ConnectionKey,
		|	ProductionSchedule.StartDate AS StartDate,
		|	ProductionSchedule.EndDate AS EndDate,
		|	ProductionSchedule.ManualChanges AS ManualChanges
		|FROM
		|	InformationRegister.ProductionSchedule AS ProductionSchedule
		|WHERE
		|	ProductionSchedule.ProductionOrder = &ProductionOrder
		|	AND ProductionSchedule.ScheduleState = 1
		|
		|UNION ALL
		|
		|SELECT
		|	ProductionSchedule.ProductionOrder,
		|	ProductionSchedule.ScheduleState,
		|	ProductionSchedule.Operation,
		|	ProductionSchedule.Activity,
		|	ProductionSchedule.ConnectionKey,
		|	ProductionSchedule.StartDate,
		|	ProductionSchedule.EndDate,
		|	ProductionSchedule.ManualChanges
		|FROM
		|	InformationRegister.ProductionSchedule AS ProductionSchedule
		|WHERE
		|	ProductionSchedule.ProductionOrder = &ProductionOrder
		|	AND ProductionSchedule.ScheduleState = 0
		|	AND NOT ProductionSchedule.Operation IN (&WIPs)";
	
	Query.SetParameter("ProductionOrder", ProductionOrder);
	Query.SetParameter("WIPs", WIPs);
	
	QueryResult = Query.Execute();
	
	ProductionScheduleRecordSet = InformationRegisters.ProductionSchedule.CreateRecordSet();
	ProductionScheduleRecordSet.Filter.ProductionOrder.Set(ProductionOrder);
	ProductionScheduleRecordSet.Load(QueryResult.Unload());
	ProductionScheduleRecordSet.Write(True);
	
EndProcedure

Procedure ReflectWorkcentersAvailabilityFromPreliminary(ProductionOrder, WIPs, ReturnStructure)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ManufacturingOperation.Ref AS Ref
		|INTO TT_WIPs
		|FROM
		|	Document.ManufacturingOperation AS ManufacturingOperation
		|WHERE
		|	ManufacturingOperation.Ref IN(&WIPs)
		|	AND ManufacturingOperation.BasisDocument = &ProductionOrder
		|;
		|
		|/////////////////////////////.///////////////////////////////////////////////////
		|SELECT
		|	TT_WIPs.Ref AS Recorder,
		|	WorkcentersAvailabilityPreliminary.WorkcenterType AS WorkcenterType,
		|	WorkcentersAvailabilityPreliminary.Workcenter AS Workcenter,
		|	WorkcentersAvailabilityPreliminary.StartDate AS Period,
		|	SUM(WorkcentersAvailabilityPreliminary.WorkloadTime) AS Used,
		|	WorkcentersAvailabilityPreliminary.ManualCorrection AS ManualCorrection
		|FROM
		|	TT_WIPs AS TT_WIPs
		|		LEFT JOIN InformationRegister.WorkcentersAvailabilityPreliminary AS WorkcentersAvailabilityPreliminary
		|		ON TT_WIPs.Ref = WorkcentersAvailabilityPreliminary.Operation
		|
		|GROUP BY
		|	TT_WIPs.Ref,
		|	WorkcentersAvailabilityPreliminary.WorkcenterType,
		|	WorkcentersAvailabilityPreliminary.Workcenter,
		|	WorkcentersAvailabilityPreliminary.StartDate,
		|	WorkcentersAvailabilityPreliminary.ManualCorrection
		|TOTALS BY
		|	Recorder";
	
	Query.SetParameter("WIPs", WIPs);
	Query.SetParameter("ProductionOrder", ProductionOrder);
	
	QueryResult = Query.Execute();
	
	SelectionRecorder = QueryResult.Select(QueryResultIteration.ByGroups);
	
	While SelectionRecorder.Next() Do
		
		If Common.ObjectAttributeValue(SelectionRecorder.Recorder, "Posted") Then
			
			WorkcentersAvailability = AccumulationRegisters.WorkcentersAvailability.CreateRecordSet();
			WorkcentersAvailability.Filter.Recorder.Set(SelectionRecorder.Recorder);
			
			SelectionDetailRecords = SelectionRecorder.Select();
			
			While SelectionDetailRecords.Next() Do
				
				If ValueIsFilled(SelectionDetailRecords.Used) Then
					Record = WorkcentersAvailability.Add();
					FillPropertyValues(Record, SelectionDetailRecords);
				EndIf;
				
			EndDo;
			
			WorkcentersAvailability.Write(True);
			
		Else
			
			ReturnStructure.ErrorsInEventLog = True;
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save production schedule for ""%1"". Details: Document not posted'; ru = 'Не удалось записать график производства для ""%1"". Подробнее: Документ не проведен';pl = 'Nie można zapisać planowania produkcji dla ""%1"". Szczegóły: Dokument nie jest zatiwerdzony';es_ES = 'Ha ocurrido un error al guardar el programa de producción para %1: Detalles: Documento no enviado';es_CO = 'Ha ocurrido un error al guardar el programa de producción para %1: Detalles: Documento no enviado';tr = '""%1"" için üretim takvimi kaydedilemedi. Ayrıntılar: Belge kaydedilmedi';it = 'Impossibile salvare il grafico di produzione per ""%1"". Dettagli: Documento non pubblicato';de = 'Fehler beim Speichern der Produktionsplanung für ""%1"". Details: Dokument nicht gebucht'", CommonClientServer.DefaultLanguageCode()),
				SelectionRecorder.Recorder);
			
			WriteLogEvent(
				NStr("en = 'Production schedule.Planning'; ru = 'Производственный график.Планирование';pl = 'Harmonogram produkcji.Planowanie';es_ES = 'Production schedule.Planning';es_CO = 'Production schedule.Planning';tr = 'Planlama takvimi.Planlama';it = 'Pianificazione di produzione.Pianificazione';de = 'Produktionsplan.Planung'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.Documents.ManufacturingOperation,
				,
				ErrorDescription);
			
		EndIf;
		
		// Clear preliminary schedule
		WorkcentersAvailabilityPreliminary = InformationRegisters.WorkcentersAvailabilityPreliminary.CreateRecordSet();
		WorkcentersAvailabilityPreliminary.Filter.Operation.Set(SelectionRecorder.Recorder);
		WorkcentersAvailabilityPreliminary.Write(True);
		
	EndDo;
	
EndProcedure

Procedure WriteWorkcentersSchedule(ProductionOrder, WIPs)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ManufacturingOperationActivities.Ref AS Operation,
	|	ManufacturingOperationActivities.ConnectionKey AS ConnectionKey,
	|	SUM(ManufacturingOperationActivities.Quantity) AS Quantity,
	|	SUM(ManufacturingOperationActivities.StandardTime * ManufacturingOperationActivities.Quantity) AS WorkloadTime
	|FROM
	|	Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|WHERE
	|	ManufacturingOperationActivities.Ref IN(&WIPs)
	|
	|GROUP BY
	|	ManufacturingOperationActivities.Ref,
	|	ManufacturingOperationActivities.ConnectionKey
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkcentersAvailabilityPreliminary.Operation AS Operation,
	|	WorkcentersAvailabilityPreliminary.WorkcenterType AS WorkcenterType,
	|	WorkcentersAvailabilityPreliminary.Workcenter AS Workcenter,
	|	WorkcentersAvailabilityPreliminary.StartDate AS StartDate,
	|	WorkcentersAvailabilityPreliminary.EndDate AS EndDate,
	|	WorkcentersAvailabilityPreliminary.Activity AS Activity,
	|	WorkcentersAvailabilityPreliminary.ConnectionKey AS ConnectionKey,
	|	WorkcentersAvailabilityPreliminary.WorkloadTime AS WorkloadTime
	|FROM
	|	InformationRegister.WorkcentersAvailabilityPreliminary AS WorkcentersAvailabilityPreliminary
	|WHERE
	|	WorkcentersAvailabilityPreliminary.Operation IN(&WIPs)
	|TOTALS BY
	|	Operation,
	|	ConnectionKey,
	|	WorkcenterType,
	|	Workcenter";
	
	Query.SetParameter("WIPs", WIPs);
	
	ResultsArray = Query.ExecuteBatch();
	
	WIPsActivities = ResultsArray[0].Unload();
	SelectionWIP = ResultsArray[1].Select(QueryResultIteration.ByGroups);
	
	FilterActivity = New Structure("Operation, ConnectionKey");
	
	While SelectionWIP.Next() Do
		
		SelectionActivity = SelectionWIP.Select(QueryResultIteration.ByGroups);
		
		While SelectionActivity.Next() Do
			
			FilterActivity.Operation = SelectionActivity.Operation;
			FilterActivity.ConnectionKey = SelectionActivity.ConnectionKey;
			
			ActivityTimeQuantity = WIPsActivities.FindRows(FilterActivity);
			
			If ActivityTimeQuantity.Count() Then
				Quantity = ActivityTimeQuantity[0].Quantity;
				QuantityLeft = ActivityTimeQuantity[0].Quantity;
				WorkloadTime = ActivityTimeQuantity[0].WorkloadTime;
			Else
				Continue;
			EndIf;
			
			WorkcentersScheduleRecordSet = InformationRegisters.WorkcentersSchedule.CreateRecordSet();
			WorkcentersScheduleRecordSet.Filter.Operation.Set(SelectionActivity.Operation);
			WorkcentersScheduleRecordSet.Filter.ConnectionKey.Set(SelectionActivity.ConnectionKey);
			
			SelectionWorkcenterType = SelectionActivity.Select(QueryResultIteration.ByGroups);
			
			While SelectionWorkcenterType.Next() Do
				
				SelectionWorkcenter = SelectionWorkcenterType.Select(QueryResultIteration.ByGroups);
				
				While SelectionWorkcenter.Next() Do
					
					WorkcentersSchedule = WorkcentersScheduleRecordSet.Unload();
					
					SelectionDetailRecords = SelectionWorkcenter.Select();
					
					While SelectionDetailRecords.Next() Do
						
						Filter = New Structure;
						Filter.Insert("EndDate", SelectionDetailRecords.StartDate);
						Filter.Insert("WorkcenterType", SelectionWorkcenter.WorkcenterType);
						Filter.Insert("Workcenter", SelectionWorkcenter.Workcenter);
						
						TheSamePeriodRows = WorkcentersSchedule.FindRows(Filter);
						
						If TheSamePeriodRows.Count() Then
							
							WorkcentersScheduleLine = TheSamePeriodRows[0];
							
							QuantityLeft = QuantityLeft + WorkcentersScheduleLine.Quantity;
							
							WorkcentersScheduleLine.EndDate = SelectionDetailRecords.EndDate;
							WorkcentersScheduleLine.WorkloadTime = WorkcentersScheduleLine.WorkloadTime + SelectionDetailRecords.WorkloadTime;
							WorkcentersScheduleLine.Quantity = ?(WorkloadTime = 0, 0, Quantity * WorkcentersScheduleLine.WorkloadTime / WorkloadTime);
							QuantityLeft = QuantityLeft - WorkcentersScheduleLine.Quantity;
							
						Else
							
							WorkcentersScheduleLine = WorkcentersSchedule.Add();
							WorkcentersScheduleLine.WorkcenterType = SelectionWorkcenter.WorkcenterType;
							WorkcentersScheduleLine.Workcenter = SelectionWorkcenter.Workcenter;
							WorkcentersScheduleLine.Operation = SelectionWorkcenter.Operation;
							WorkcentersScheduleLine.ConnectionKey = SelectionWorkcenter.ConnectionKey;
							WorkcentersScheduleLine.Activity = SelectionDetailRecords.Activity;
							WorkcentersScheduleLine.StartDate = SelectionDetailRecords.StartDate;
							WorkcentersScheduleLine.EndDate = SelectionDetailRecords.EndDate;
							WorkcentersScheduleLine.WorkloadTime = SelectionDetailRecords.WorkloadTime;
							WorkcentersScheduleLine.Quantity = ?(WorkloadTime = 0, 0, Quantity * WorkcentersScheduleLine.WorkloadTime / WorkloadTime);
							QuantityLeft = QuantityLeft - WorkcentersScheduleLine.Quantity;
							
						EndIf;
						
					EndDo;
					
					WorkcentersScheduleRecordSet.Load(WorkcentersSchedule);
					WorkcentersScheduleRecordSet.Write(True);
					
				EndDo;
				
			EndDo;
			
			If QuantityLeft <> 0 Then
				
				WorkcentersSchedule = WorkcentersScheduleRecordSet.Unload();
				
				If WorkcentersSchedule.Count() Then
					
					WorkcentersScheduleLine = WorkcentersSchedule[WorkcentersSchedule.Count() - 1];
					WorkcentersScheduleLine.Quantity = WorkcentersScheduleLine.Quantity + QuantityLeft;
					
				EndIf;
				
				WorkcentersScheduleRecordSet.Load(WorkcentersSchedule);
				WorkcentersScheduleRecordSet.Write(True);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Function SavingReturnStructure()
	
	ReturnStructure = New Structure;
	ReturnStructure.Insert("ErrorsInEventLog", False);
	
	Return ReturnStructure;
	
EndFunction

#EndRegion

#Region OrdersCancellation

Function CancelOrderSchedule(PlanningSettings)
	
	ReturnStructure = CancellationReturnStructure();
	
	WIPs = PlanningSettings.WIPs;
	
	BeginTransaction();
	
	Try
		
		For Each ProductionOrder In PlanningSettings.Orders Do
		
			// ProductionSchedule register
			ProductionScheduleRecordSet = InformationRegisters.ProductionSchedule.CreateRecordSet();
			ProductionScheduleRecordSet.Filter.ProductionOrder.Set(ProductionOrder);
			ProductionScheduleRecordSet.Filter.ScheduleState.Set(1);
			ProductionScheduleRecordSet.Write(True);
			
			ReflectWorkcentersAvailabilityFromPreliminary(ProductionOrder, WIPs, ReturnStructure);
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		ReturnStructure.ErrorsInEventLog = True;
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t clear preliminary production schedule for ""%1"". Details: %2'; ru = 'Не удалось очистить предварительный график производства для ""%1"". Подробнее: %2';pl = 'Nie udało się wyczyścić wstępnego harmonogramu produkcji dla ""%1"". Szczegóły: %2';es_ES = 'No se pudo borrar el programa de producción preliminar para ""%1"". Detalles: %2';es_CO = 'No se pudo borrar el programa de producción preliminar para ""%1"". Detalles: %2';tr = '""%1"" için ön üretim takvimi temizlenemedi. Ayrıntılar: %2';it = 'Impossibile cancellare il grafico di produzione preliminare per ""%1"". Dettagli: %2';de = 'Fehler beim Löschen der vorläufigen Produktionsplanung für ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
			ValueToStringInternal(PlanningSettings.Orders),
			BriefErrorDescription(ErrorInfo()));
		
		WriteLogEvent(
			NStr("en = 'Production schedule.Planning'; ru = 'Производственный график.Планирование';pl = 'Harmonogram produkcji.Planowanie';es_ES = 'Production schedule.Planning';es_CO = 'Production schedule.Planning';tr = 'Planlama takvimi.Planlama';it = 'Pianificazione di produzione.Pianificazione';de = 'Produktionsplan.Planung'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			Metadata.Documents.ProductionOrder,
			,
			ErrorDescription);
		
		RollbackTransaction();
		
	EndTry;
	
	Return ReturnStructure;
	
EndFunction

Function CancellationReturnStructure()
	
	ReturnStructure = New Structure;
	ReturnStructure.Insert("ErrorsInEventLog", False);
	
	Return ReturnStructure;
	
EndFunction

#EndRegion

#Region Common

Function PlanningSettings(StartPlanningSettings)
	
	Result = New Structure();
	Result.Insert("FullReplanning", StartPlanningSettings.FullReplanning);
	
	If StartPlanningSettings.Property("ProductionOrders") Then
		ProductionOrders = StartPlanningSettings.ProductionOrders;
	Else
		ProductionOrders = New Array;
		ProductionOrders.Add(StartPlanningSettings.ProductionOrder);
	EndIf;
	
	StartedProductionOrders = DeleteStartedProductionOrders(ProductionOrders);
	Result.Insert("StartedProductionOrders", StartedProductionOrders);
	
	Result.Insert("PlanTheQueueByTheCurrentOne", StartPlanningSettings.PlanTheQueueByTheCurrentOne);
	Result.Insert("JobNumber", FixJobNumber());
	
	If StartPlanningSettings.PlanTheQueueByTheCurrentOne Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	MAX(ProductionOrdersPriorities.PriorityOrder) AS PriorityOrder,
		|	MAX(ProductionOrdersPriorities.Queue) AS Queue
		|INTO TT_MaxOrder
		|FROM
		|	InformationRegister.ProductionOrdersPriorities AS ProductionOrdersPriorities
		|WHERE
		|	ProductionOrdersPriorities.ProductionOrder IN(&ProductionOrders)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	ProductionOrdersPriorities.ProductionOrder AS ProductionOrder
		|INTO TT_MoreImportantOrders
		|FROM
		|	InformationRegister.ProductionOrdersPriorities AS ProductionOrdersPriorities
		|		INNER JOIN TT_MaxOrder AS TT_MaxOrder
		|			ON (CASE
		|				WHEN ProductionOrdersPriorities.PriorityOrder < TT_MaxOrder.PriorityOrder
		|					THEN TRUE
		|				WHEN ProductionOrdersPriorities.PriorityOrder = TT_MaxOrder.PriorityOrder
		|					THEN ProductionOrdersPriorities.Queue < TT_MaxOrder.Queue
		|				ELSE FALSE
		|			END)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	JobsForProductionScheduleCalculation.ProductionOrder AS ProductionOrder
		|FROM
		|	InformationRegister.JobsForProductionScheduleCalculation AS JobsForProductionScheduleCalculation
		|WHERE
		|	JobsForProductionScheduleCalculation.ProductionOrder IN
		|			(SELECT
		|				TT_MoreImportantOrders.ProductionOrder AS ProductionOrder
		|			FROM
		|				TT_MoreImportantOrders AS TT_MoreImportantOrders)
		|	AND JobsForProductionScheduleCalculation.JobNumber <= &JobNumber";
		
		Query.SetParameter("ProductionOrders", ProductionOrders);
		Query.SetParameter("JobNumber", Result.JobNumber);
		
		QueryResult = Query.Execute().Unload().UnloadColumn("ProductionOrder");
		
		CommonClientServer.SupplementArray(ProductionOrders, QueryResult, True);
		
	EndIf;
	
	Result.Insert("ProductionOrders", ProductionOrders);
	
	Result.Insert("CurrentDate", CurrentSessionDate());
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	MIN(ProductionOrder.Start) AS Start
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|WHERE
	|	ProductionOrder.Ref IN(&ProductionOrders)";
	
	Query.SetParameter("ProductionOrders", ProductionOrders);
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	If Selection.Next() Then
		If ValueIsFilled(Selection.Start) Then
			Result.Insert("Start", Max(Result.CurrentDate, Selection.Start));
		Else
			Result.Insert("Start", Result.CurrentDate);
		EndIf;
	EndIf;
	
	#Region AvailabilityTablePreparing
	
	AvailabilityQuery = PrepareQueryAvailabilityTable(Result);
	Availability = AvailabilityQuery.Execute().Unload();
	Availability.Indexes.Add("Period, WorkcenterType");
	
	Availability.Columns.Add("LineNumber");
	
	RowsInAvailability = Availability.Count() - 1;
	For Index = 0 To RowsInAvailability Do
		Availability[Index].LineNumber = Index;
	EndDo;
	
	Result.Insert("Availability", Availability);
	
	#EndRegion
	
	Return Result;
	
EndFunction

Function DeleteStartedProductionOrders(ProductionOrders)
	
	StartedProductionOrders = New Array;
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	ManufacturingOperation.BasisDocument AS ProductionOrder
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|WHERE
	|	ManufacturingOperation.Posted
	|	AND ManufacturingOperation.Status <> VALUE(Enum.ManufacturingOperationStatuses.Open)
	|	AND ManufacturingOperation.BasisDocument IN(&ProductionOrders)";
	
	Query.SetParameter("ProductionOrders", ProductionOrders);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		StartedProductionOrders.Add(SelectionDetailRecords.ProductionOrder);
		IndexToDel = ProductionOrders.Find(SelectionDetailRecords.ProductionOrder);
		If IndexToDel <> Undefined Then
			ProductionOrders.Delete(IndexToDel);
		EndIf;
	EndDo;
	
	Return StartedProductionOrders;
	
EndFunction

Function IntervalsTable()
	
	QN = New NumberQualifiers(10,0);
	Array = New Array;
	Array.Add(Type("Number"));
	TypeDescriptionN = New TypeDescription(Array, , ,QN);
	
	QN5 = New NumberQualifiers(5,0);
	TypeDescriptionN5 = New TypeDescription(Array, , ,QN5);
	
	QD = New DateQualifiers(DateFractions.DateTime);
	Array.Clear();
	Array.Add(Type("Date"));
	TypeDescriptionD = New TypeDescription(Array, , , , , QD);
	
	Array.Clear();
	Array.Add(Type("DocumentRef.ManufacturingOperation"));
	TypeDescriptionOperation = New TypeDescription(Array);
	
	Array.Clear();
	Array.Add(Type("CatalogRef.CompanyResourceTypes"));
	TypeDescriptionWorkcenterType = New TypeDescription(Array);
	
	Array.Clear();
	Array.Add(Type("CatalogRef.CompanyResources"));
	TypeDescriptionWorkcenter = New TypeDescription(Array);
	
	Array.Clear();
	Array.Add(Type("Boolean"));
	TypeDescriptionB = New TypeDescription(Array);
	
	Array.Clear();
	Array.Add(Type("CatalogRef.ManufacturingActivities"));
	TypeDescriptionActivity = New TypeDescription(Array);
	
	Intervals = New ValueTable;
	Intervals.Columns.Add("Operation", TypeDescriptionOperation);
	Intervals.Columns.Add("Activity", TypeDescriptionActivity);
	Intervals.Columns.Add("ConnectionKey", TypeDescriptionN5);
	Intervals.Columns.Add("WorkcenterType", TypeDescriptionWorkcenterType);
	Intervals.Columns.Add("Workcenter", TypeDescriptionWorkcenter);
	Intervals.Columns.Add("StartDate", TypeDescriptionD);
	Intervals.Columns.Add("EndDate", TypeDescriptionD);
	Intervals.Columns.Add("WorkloadTime", TypeDescriptionN);
	Intervals.Columns.Add("NoWCT", TypeDescriptionB);
	
	Return Intervals;
	
EndFunction

Function ReturnStructure()
	
	ReturnStructure = New Structure;
	ReturnStructure.Insert("WIPs", New Array);
	ReturnStructure.Insert("Orders", New Array);
	ReturnStructure.Insert("IntervalsTable", IntervalsTable());
	ReturnStructure.Insert("ErrorsInEventLog", False);
	ReturnStructure.Insert("ErrorsToShow", False);
	ReturnStructure.Insert("ListOfErrorsToShow", New Array);
	ReturnStructure.Insert("PlannedSuccessfully", False);
	ReturnStructure.Insert("JobNumber", 0);
	ReturnStructure.Insert("Workcenter", Undefined);
	
	Return ReturnStructure;
	
EndFunction

Procedure UniteStructures(MainStructure, ChildStructure)
	
	If ChildStructure.ErrorsInEventLog Then
		MainStructure.ErrorsInEventLog = True;
	EndIf;
	
	If ChildStructure.ErrorsToShow Then
		MainStructure.ErrorsToShow = True;
	EndIf;
	
	If Not ChildStructure.PlannedSuccessfully Then
		MainStructure.PlannedSuccessfully = False;
	EndIf;
	
	If ChildStructure.ListOfErrorsToShow.Count() > 0 Then
		
		CommonClientServer.SupplementArray(MainStructure.ListOfErrorsToShow, ChildStructure.ListOfErrorsToShow, True);
		
	EndIf;
	
	CommonClientServer.SupplementArray(MainStructure.WIPs, ChildStructure.WIPs, True);
	
	CommonClientServer.SupplementTable(ChildStructure.IntervalsTable, MainStructure.IntervalsTable);
	
	If ValueIsFilled(ChildStructure.Workcenter) Then
		MainStructure.Workcenter = ChildStructure.Workcenter;
	EndIf;
	
EndProcedure

Function MaxDateInTable(Intervals)
	
	Result = Date('00010101000000');
	
	If Intervals.Count() > 0 Then
		
		EndDates = Intervals.Copy(,"EndDate");
		EndDates.Sort("EndDate Desc");
		
		Result = EndDates[0].EndDate;
		
	EndIf;
	
	Return Result;
	
EndFunction

Procedure AddMessageNotEnoughtTimeOnWCT(ReturnStructure, WorkcenterType)
	
	ReturnStructure.ErrorsToShow = True;
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Not enough time on work center type %1.
			|Please, check planning horizon in production settings and the availability of work centers.'; 
			|ru = 'Недостаточно времени на рабочем центре типа %1.
			|Проверьте горизонт планирования в настройках производства и доступность рабочих центров.';
			|pl = 'Nie wystarcza czasu dla typu gniazda produkcyjnego%1.
			|Sprawdź horyzont planowania w ustawieniach produkcji i dostępność gniazd produkcyjnych.';
			|es_ES = 'No hay suficiente tiempo en el tipo de centro de trabajo%1.
			| Por favor, compruebe el horizonte de planificación en los ajustes de producción y la disponibilidad de los centros de trabajo.';
			|es_CO = 'No hay suficiente tiempo en el tipo de centro de trabajo%1.
			| Por favor, compruebe el horizonte de planificación en los ajustes de producción y la disponibilidad de los centros de trabajo.';
			|tr = '%1 iş merkezi türünde süre yeterli değil.
			|Lütfen, üretim ayarlarında planlama süresini ve iş merkezlerinin uygunluğunu kontrol edin.';
			|it = 'Tempo insufficiente nel tipo di centro di lavoro %1.
			|Verificare l''orizzonte di pianificazione nelle impostazioni di produzione e la disponibilità di centri di lavoro.';
			|de = 'Nicht ausreichende Zeit am Arbeitsabschnittstyp %1.
			|Bitte prüfen Sie den Planungshorizont unter Produktionseinstellungen und die Verfügbarkeit von Arbeitsabschnitten.'"),
		WorkcenterType);
	
	ReturnStructure.ListOfErrorsToShow.Add(ErrorText);
	
EndProcedure

Procedure AddMessageNotEnoughtTimeOnCalendar(ReturnStructure, CompanyCalendar)
	
	ReturnStructure.ErrorsToShow = True;
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Not enough time for planning operations without work center types.
			|Please, check planning horizon in production settings and work schedule %1 of the company.'; 
			|ru = 'Не достаточно времени для планирования операций без типов рабочих центров.
			|Проверьте горизонт планирования в настройках производства и график работы %1 организации.';
			|pl = 'Nie wystarcza czasu do planowania działań bez typów gniazd produkcyjnych.
			|Sprawdź horyzont planowania w ustawieniach produkcji i harmonogramie pracy %1 firmy.';
			|es_ES = 'No hay tiempo suficiente para planificar operaciones sin tipos de centro de trabajo
			|. Por favor, compruebe el horizonte de planificación en las configuraciones de producción y el plan de trabajo%1 de la empresa.';
			|es_CO = 'No hay tiempo suficiente para planificar operaciones sin tipos de centro de trabajo
			|. Por favor, compruebe el horizonte de planificación en las configuraciones de producción y el plan de trabajo%1 de la empresa.';
			|tr = 'İş merkezi türü olmadan işlem planlaması için süre yeterli değil.
			|Lütfen, üretim ayarlarında planlama süresini ve iş yerinin %1 çalışma takvimini kontrol edin.';
			|it = 'Tempo insufficiente per la pianificazione di operazioni senza il tipo centro di lavoro.
			|Verificare l''orizzonte di pianificazione nelle impostaizoni di produzione e il grafico di lavoro %1 dell''azienda.';
			|de = 'Nicht ausreichende Zeit für Planungsoperationen ohne Arbeitsabschnittstypen.
			|Bitte prüfen Sie den Planungshorizont unter Produktionseinstellungen und den Arbeitszeitplan %1 der Firma.'"),
		CompanyCalendar);
	
	ReturnStructure.ListOfErrorsToShow.Add(ErrorText);
	
EndProcedure

Procedure AddMessageNotEnoughtTimeOnWCTs(ReturnStructure, WorkcenterTypesArray)
	
	ReturnStructure.ErrorsToShow = True;
	
	WorkcenterTypes = "";
	For Each WorkcenterType In WorkcenterTypesArray Do
		WorkcenterTypes = WorkcenterTypes + WorkcenterType + " ";
	EndDo;
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Not enough time on work center types %1.
			|Please, check planning horizon in production settings and the availability of work centers.'; 
			|ru = 'Недостаточно времени на рабочих центрах типа %1.
			|Проверьте горизонт планирования в настройках производства и доступность рабочих центров.';
			|pl = 'Nie wystarcza czasu dla typów gniazd produkcyjnych%1.
			|Sprawdź horyzont planowania w ustawieniach produkcji i dostępność gniazd produkcyjnych.';
			|es_ES = 'No hay suficiente tiempo en los tipos de centro de trabajo%1.
			| Por favor, compruebe el horizonte de planificación en las configuraciones de producción y la disponibilidad de los centros de trabajo.';
			|es_CO = 'No hay suficiente tiempo en los tipos de centro de trabajo%1.
			| Por favor, compruebe el horizonte de planificación en las configuraciones de producción y la disponibilidad de los centros de trabajo.';
			|tr = '%1 iş merkezi türlerinde süre yeterli değil.
			|Lütfen, üretim ayarlarında planlama süresini ve iş merkezlerinin uygunluğunu kontrol edin.';
			|it = 'Tempo insufficiente nei tipi di centro di lavoro %1.
			|Verificare l''orizzonte di pianificazione nelle impostazioni di produzione e la disponibilità di centri di lavoro.';
			|de = 'Nicht ausreichende Zeit an den Arbeitsabschnittstypen %1.
			|Bitte prüfen Sie den Planungshorizont unter Produktionseinstellungen und die Verfügbarkeit von Arbeitsabschnitten.'"),
		WorkcenterTypes);
	
	ReturnStructure.ListOfErrorsToShow.Add(ErrorText);
	
EndProcedure

Function FilterWithSort(Availability, Filter)
	
	FilterRows = Availability.FindRows(Filter);
	
	// Sort table
	
	Return FilterRows;
	
EndFunction

Function CompanyCalendar(OperationSettings)
	
	Result = Catalogs.Calendars.EmptyRef();
	
	Company = Common.ObjectAttributeValue(OperationSettings.WIP, "Company");
	Calendar = Common.ObjectAttributeValue(Company, "BusinessCalendar");
	
	If ValueIsFilled(Calendar) Then
		
		CalendarEndDate = Common.ObjectAttributeValue(Calendar, "EndDate");
		If Not ValueIsFilled(CalendarEndDate) Or (CalendarEndDate > OperationSettings.StartDate) Then
			Result = Calendar;
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function FixJobNumber()
	
	JobNumber = 0;
	
	BeginTransaction();
	
	Try
		
		Lock = New DataLock;
		LockItem = Lock.Add("Constant.NumberOfJobToTheProductionScheduleCalculation");
		LockItem.Mode = DataLockMode.Exclusive;
		Lock.Lock();
		
		JobNumber = Constants.NumberOfJobToTheProductionScheduleCalculation.Get();
		Constants.NumberOfJobToTheProductionScheduleCalculation.Set(JobNumber + 1);
		
		CommitTransaction();
		
	Except
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Error on setting ''Number of job to the production schedule calculation'' constant: %1'; ru = 'Ошибка при установке константы ''Номер задания при расчете графика производства'': %1';pl = 'Błąd w ustawieniu stałej ''Ilość pracy do obliczenia harmonogramu produkcji'': %1';es_ES = 'Error al establecer la constante ""Número de tarea para calcular el programa de producción"": %1';es_CO = 'Error al establecer la constante ""Número de tarea para calcular el programa de producción"": %1';tr = '""Üretim takvimi hesaplaması için iş sayısı"" sabitini ayarlarken bir hata oluştu: %1';it = 'Errore nell''impostazione della costante ''Numero di processi del calcolo della pianificazione produzione'': %1';de = 'Fehler beim Festlegen von ''Nummer der Arbeit für Berechnung des Produktionsplanes'' Konstante: %1'", CommonClientServer.DefaultLanguageCode()),
			DetailErrorDescription(ErrorInfo()));
		
		WriteLogEvent(
			NStr("en = 'Production schedule.Planning'; ru = 'Производственный график.Планирование';pl = 'Harmonogram produkcji.Planowanie';es_ES = 'Production schedule.Planning';es_CO = 'Production schedule.Planning';tr = 'Planlama takvimi.Planlama';it = 'Pianificazione di produzione.Pianificazione';de = 'Produktionsplan.Planung'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			Metadata.Constants.NumberOfJobToTheProductionScheduleCalculation,
			,
			ErrorDescription);
		
		RollbackTransaction();
		
	EndTry;
	
	Return JobNumber;
	
EndFunction

Function CheckFilling(PlanningSettings, ListOfErrorsToShow)
	
	Result = True;
	
	// PlanningHorizon
	PlanningHorizon = Constants.PlanningHorizon.Get();
	
	If PlanningHorizon = 0 Then
		
		Result = False;
		ErrorText = NStr("en = 'Before you start the planning, please fill in the planning horizon in production subsystem settings.'; ru = 'Перед началом планирования заполните горизонт планирования в настройках подсистемы ""Производство"".';pl = 'Przed rozpoczęciem planowania, wypełnij horyzont planowania w ustawieniach podsystemu produkcji.';es_ES = 'Antes de iniciar la planificación, por favor, rellene el horizonte de planificación en las configuraciones del subsistema de producción.';es_CO = 'Antes de iniciar la planificación, por favor, rellene el horizonte de planificación en las configuraciones del subsistema de producción.';tr = 'Planlamaya başlamadan önce lütfen üretim alt sistemi ayarlarında planlama süresini doldurun.';it = 'Prima di iniziare la pianificazione, compilare l''orizzonte di pianificazione nelle impostazione del sotto sistema di produzione.';de = 'Vor Beginn der Planung bitte füllen Sie zuerst den Planungshorizont unter den Einstellungen des Produktionssubsystems aus.'");
		ListOfErrorsToShow.Add(ErrorText);
		
	EndIf;
	
	// WIPs
	If PlanningSettings.Property("ProductionOrders") Then
		ProductionOrders = PlanningSettings.ProductionOrders;
	Else
		ProductionOrders = New Array;
		ProductionOrders.Add(PlanningSettings.ProductionOrder);
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProductionOrdersStates.ProductionOrder AS ProductionOrder
	|INTO TT_Orders
	|FROM
	|	InformationRegister.ProductionOrdersStates AS ProductionOrdersStates
	|WHERE
	|	ProductionOrdersStates.ProductionOrder IN(&ProductionOrders)
	|	AND ProductionOrdersStates.State = VALUE(Enum.ProductionOrdersStates.PlanStages)
	|
	|INDEX BY
	|	ProductionOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ManufacturingOperation.Ref AS Ref
	|INTO TT_WIPs
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|		INNER JOIN TT_Orders AS TT_Orders
	|		ON ManufacturingOperation.BasisDocument = TT_Orders.ProductionOrder
	|WHERE
	|	ManufacturingOperation.Posted
	|	AND ManufacturingOperation.Status = VALUE(Enum.ManufacturingOperationStatuses.Open)
	|
	|INDEX BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ManufacturingOperationActivities.Activity AS Activity,
	|	ManufacturingOperationActivities.Quantity AS Quantity,
	|	ManufacturingOperationActivities.Ref AS WIP,
	|	ManufacturingActivitiesWorkCenterTypes.WorkcenterType AS WorkcenterType,
	|	CompanyResourceTypes.BusinessUnit AS BusinessUnit,
	|	BusinessUnits.PlanningInterval AS PlanningInterval
	|FROM
	|	Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|		INNER JOIN TT_WIPs AS TT_WIPs
	|		ON ManufacturingOperationActivities.Ref = TT_WIPs.Ref
	|		LEFT JOIN Catalog.ManufacturingActivities.WorkCenterTypes AS ManufacturingActivitiesWorkCenterTypes
	|		ON ManufacturingOperationActivities.Activity = ManufacturingActivitiesWorkCenterTypes.Ref
	|		LEFT JOIN Catalog.CompanyResourceTypes AS CompanyResourceTypes
	|		ON (ManufacturingActivitiesWorkCenterTypes.WorkcenterType = CompanyResourceTypes.Ref)
	|		LEFT JOIN Catalog.BusinessUnits AS BusinessUnits
	|		ON (CompanyResourceTypes.BusinessUnit = BusinessUnits.Ref)";
	
	Query.SetParameter("ProductionOrders", ProductionOrders);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		
		Result = False;
		ErrorText = ProductionPlanningClientServer.ErrorTextNothingToPlan(ProductionOrders);
		ListOfErrorsToShow.Add(ErrorText);
		
	Else
		
		SelectionDetailRecords = QueryResult.Select();
		
		While SelectionDetailRecords.Next() Do
			
			If ValueIsFilled(SelectionDetailRecords.WorkcenterType) And Not ValueIsFilled(SelectionDetailRecords.PlanningInterval) Then
				
				Result = False;
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Before you start the planning, please fill in the planning interval in %1.'; ru = 'Перед началом планирования заполните периодичность планирования в %1.';pl = 'Przed rozpoczęciem planowania, wypełnij interwał planowania w %1.';es_ES = 'Antes de iniciar la planificación, por favor, rellene el intervalo de planificación en %1.';es_CO = 'Antes de iniciar la planificación, por favor, rellene el intervalo de planificación en %1.';tr = 'Planlamaya başlamadan önce lütfen %1''de planlama aralığını doldurun.';it = 'Prima di iniziare la pianificazione, compilare l''intervallo di pianificazione in %1.';de = 'Vor Beginn der Planung bitte füllen Sie zuerst das Planungsintervall unter %1aus.'"),
					SelectionDetailRecords.BusinessUnit);
				ListOfErrorsToShow.Add(ErrorText);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndRegion