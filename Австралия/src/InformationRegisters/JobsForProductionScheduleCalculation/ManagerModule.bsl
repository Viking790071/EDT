#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure AddJobs(Operations) Export
	
	JobNumber = Constants.NumberOfJobToTheProductionScheduleCalculation.Get();
	
	BeginTransaction();
	
	Try
		
		If TypeOf(Operations) = Type("Array")
			And Operations.Count() > 1 Then
			
			Query = New Query;
			Query.Text = 
			"SELECT
			|	JobsForProductionScheduleCalculation.ProductionOrder AS ProductionOrder,
			|	JobsForProductionScheduleCalculation.ManufacturingOperation AS ManufacturingOperation,
			|	JobsForProductionScheduleCalculation.JobNumber AS JobNumber
			|INTO TT_Records
			|FROM
			|	InformationRegister.JobsForProductionScheduleCalculation AS JobsForProductionScheduleCalculation
			|WHERE
			|	JobsForProductionScheduleCalculation.JobNumber = &JobNumber
			|
			|UNION ALL
			|
			|SELECT
			|	ManufacturingOperation.BasisDocument,
			|	ManufacturingOperation.Ref,
			|	&JobNumber
			|FROM
			|	Document.ManufacturingOperation AS ManufacturingOperation
			|WHERE
			|	ManufacturingOperation.Ref IN(&Operations)
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT DISTINCT
			|	TT_Records.ProductionOrder AS ProductionOrder,
			|	TT_Records.ManufacturingOperation AS ManufacturingOperation,
			|	TT_Records.JobNumber AS JobNumber
			|FROM
			|	TT_Records AS TT_Records";
			
			Query.SetParameter("JobNumber", JobNumber);
			Query.SetParameter("Operations", Operations);
			
			QueryResult = Query.Execute().Unload();
			
			RecordSet = InformationRegisters.JobsForProductionScheduleCalculation.CreateRecordSet();
			RecordSet.Filter.JobNumber.Set(JobNumber);
			RecordSet.Load(QueryResult);
			RecordSet.Write();
			
		Else
			
			ManufacturingOperation = Undefined;
			
			If TypeOf(Operations) = Type("DocumentRef.ManufacturingOperation") Then
				
				ManufacturingOperation = Operations;
				
			ElsIf TypeOf(Operations) = Type("Array") And Operations.Count() = 1 Then
				
				ManufacturingOperation = Operations[0];
				
			EndIf;
			
			If ManufacturingOperation <> Undefined
				And Common.ObjectAttributeValue(ManufacturingOperation, "Status") = Enums.ManufacturingOperationStatuses.Open Then
				
				Manager = InformationRegisters.JobsForProductionScheduleCalculation.CreateRecordManager();
				Manager.ProductionOrder = Common.ObjectAttributeValue(ManufacturingOperation, "BasisDocument");
				Manager.ManufacturingOperation = ManufacturingOperation;
				Manager.JobNumber = JobNumber;
				Manager.Write();
				
			EndIf;
			
		EndIf;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		EventName = NStr("en = 'Add jobs to the production schedule calculation'; ru = 'Добавить задания в расчет графика производства';pl = 'Dodaj prace do obliczenia planowania produkcji';es_ES = 'Añadir las tareas para el cálculo del programa de producción';es_CO = 'Añadir las tareas para el cálculo del programa de producción';tr = 'Üretim takvimi hesaplamasına iş ekle';it = 'Aggiungere lavori al calcolo della pianificazione di produzione';de = 'Arbeiten zur Berechnung des Produktionsplans hinzufügen'", CommonClientServer.DefaultLanguageCode());
		
		WriteLogEvent(
			EventName,
			EventLogLevel.Error,
			,
			,
			DetailErrorDescription(ErrorInfo()));
		
	EndTry;
	
EndProcedure

Procedure DeleteJobs(ProductionOrder, JobNumber = Undefined) Export
	
	If JobNumber = Undefined Then
		JobNumber = Constants.NumberOfJobToTheProductionScheduleCalculation.Get();
	EndIf;
	
	BeginTransaction();
	
	Try
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	JobsForProductionScheduleCalculation.ProductionOrder AS ProductionOrder,
		|	JobsForProductionScheduleCalculation.ManufacturingOperation AS ManufacturingOperation,
		|	JobsForProductionScheduleCalculation.JobNumber AS JobNumber
		|INTO TT_AllRecords
		|FROM
		|	InformationRegister.JobsForProductionScheduleCalculation AS JobsForProductionScheduleCalculation
		|WHERE
		|	JobsForProductionScheduleCalculation.ProductionOrder = &ProductionOrder
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	JobsForProductionScheduleCalculation.ProductionOrder AS ProductionOrder,
		|	JobsForProductionScheduleCalculation.ManufacturingOperation AS ManufacturingOperation,
		|	JobsForProductionScheduleCalculation.JobNumber AS JobNumber
		|INTO TT_RecordsToDelete
		|FROM
		|	InformationRegister.JobsForProductionScheduleCalculation AS JobsForProductionScheduleCalculation
		|WHERE
		|	JobsForProductionScheduleCalculation.ProductionOrder = &ProductionOrder
		|	AND JobsForProductionScheduleCalculation.JobNumber <= &JobNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_AllRecords.ProductionOrder AS ProductionOrder,
		|	TT_AllRecords.ManufacturingOperation AS ManufacturingOperation,
		|	TT_AllRecords.JobNumber AS JobNumber
		|FROM
		|	TT_AllRecords AS TT_AllRecords
		|		LEFT JOIN TT_RecordsToDelete AS TT_RecordsToDelete
		|		ON TT_AllRecords.ProductionOrder = TT_RecordsToDelete.ProductionOrder
		|			AND TT_AllRecords.ManufacturingOperation = TT_RecordsToDelete.ManufacturingOperation
		|			AND TT_AllRecords.JobNumber = TT_RecordsToDelete.JobNumber
		|WHERE
		|	TT_RecordsToDelete.ProductionOrder IS NULL";
		
		Query.SetParameter("JobNumber", JobNumber);
		Query.SetParameter("ProductionOrder", ProductionOrder);
		
		QueryResult = Query.Execute().Unload();
		
		RecordSet = InformationRegisters.JobsForProductionScheduleCalculation.CreateRecordSet();
		RecordSet.Filter.ProductionOrder.Set(ProductionOrder);
		RecordSet.Load(QueryResult);
		RecordSet.Write();
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		EventName = NStr("en = 'Delete jobs from the production schedule calculation'; ru = 'Удалить задания из расчета графика производства';pl = 'Usuń prace z obliczenia planowania produkcji';es_ES = 'Borrar las tareas para el cálculo del programa de producción';es_CO = 'Borrar las tareas para el cálculo del programa de producción';tr = 'Üretim takvimi hesaplamasından iş sil';it = 'Eliminare lavori dal calcolo della pianificazione di produzione';de = 'Arbeiten aus der Berechnung des Produktionsplans entfernen'", CommonClientServer.DefaultLanguageCode());
		
		WriteLogEvent(
			EventName,
			EventLogLevel.Error,
			,
			,
			DetailErrorDescription(ErrorInfo()));
		
	EndTry;
	
EndProcedure

Function WIPIsActual(ManufacturingOperation) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	JobsForProductionScheduleCalculation.ManufacturingOperation AS ManufacturingOperation
	|FROM
	|	InformationRegister.JobsForProductionScheduleCalculation AS JobsForProductionScheduleCalculation
	|WHERE
	|	JobsForProductionScheduleCalculation.ManufacturingOperation = &ManufacturingOperation";
	
	Query.SetParameter("ManufacturingOperation", ManufacturingOperation);
	
	QueryResult = Query.Execute();
	
	Return QueryResult.IsEmpty();
	
EndFunction

Procedure AddAllOperationsOfOrder(ProductionOrder) Export
	
	If Common.ObjectAttributeValue(ProductionOrder, "Posted") = True
		And OrderInProgress(ProductionOrder) Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	ManufacturingOperation.Ref AS WIP
		|FROM
		|	Document.ManufacturingOperation AS ManufacturingOperation
		|WHERE
		|	ManufacturingOperation.Posted
		|	AND ManufacturingOperation.BasisDocument = &ProductionOrder
		|	AND ManufacturingOperation.Status = VALUE(Enum.ManufacturingOperationStatuses.Open)";
		
		Query.SetParameter("ProductionOrder", ProductionOrder);
		
		Operations = Query.Execute().Unload().UnloadColumn("WIP");
		
		AddJobs(Operations);
		
		CheckWIPsQueue(Operations);
		
	EndIf;
	
EndProcedure

// Checks the queue of WIPs and adds new WIPs for planning
// Every open WIP which uses the same WCT on the same period (and has lower order) will be added to the queue
Procedure CheckWIPsQueue(WIPs, OrdersToExclude = Undefined) Export
	
	If OrdersToExclude = Undefined Then
		OrdersToExclude = New Array;
	EndIf;
	
	AddStartesOrdersInOrdersToExclude(OrdersToExclude);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ManufacturingOperationActivities.Activity AS Activity,
	|	ManufacturingActivitiesWorkCenterTypes.WorkcenterType AS WorkcenterType,
	|	ProductionOrderDoc.Ref AS ProductionOrder,
	|	ManufacturingActivitiesWorkCenterTypes.Ref AS WIP,
	|	CASE
	|		WHEN ProductionSchedule.StartDate IS NULL
	|			THEN ProductionOrderDoc.Start
	|		WHEN ProductionOrderDoc.Start <= ProductionSchedule.StartDate
	|			THEN ProductionOrderDoc.Start
	|		ELSE ProductionSchedule.StartDate
	|	END AS Start
	|INTO TT_WorkCenterTypes
	|FROM
	|	Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|		INNER JOIN Catalog.ManufacturingActivities.WorkCenterTypes AS ManufacturingActivitiesWorkCenterTypes
	|		ON ManufacturingOperationActivities.Activity = ManufacturingActivitiesWorkCenterTypes.Ref
	|		INNER JOIN Document.ProductionOrder AS ProductionOrderDoc
	|		ON ManufacturingOperationActivities.Ref.BasisDocument = ProductionOrderDoc.Ref
	|		LEFT JOIN InformationRegister.ProductionSchedule AS ProductionSchedule
	|		ON ManufacturingOperationActivities.Ref = ProductionSchedule.Operation
	|WHERE
	|	ManufacturingOperationActivities.Ref IN(&WIPs)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ManufacturingOperationActivities.Ref.BasisDocument AS ProductionOrder,
	|	ManufacturingOperationActivities.Ref AS WIP,
	|	TT_WorkCenterTypes.Start AS Start
	|INTO TT_AllMatchingOrders
	|FROM
	|	Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|		INNER JOIN Catalog.ManufacturingActivities.WorkCenterTypes AS ManufacturingActivitiesWorkCenterTypes
	|		ON ManufacturingOperationActivities.Activity = ManufacturingActivitiesWorkCenterTypes.Ref
	|		INNER JOIN TT_WorkCenterTypes AS TT_WorkCenterTypes
	|		ON (ManufacturingActivitiesWorkCenterTypes.WorkcenterType = TT_WorkCenterTypes.WorkcenterType)
	|WHERE
	|	NOT ManufacturingOperationActivities.Ref IN (&WIPs)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TT_AllMatchingOrders.ProductionOrder AS ProductionOrder
	|INTO TT_AllLaterPlannedOrders
	|FROM
	|	TT_AllMatchingOrders AS TT_AllMatchingOrders
	|		INNER JOIN InformationRegister.ProductionSchedule AS ProductionSchedule
	|		ON TT_AllMatchingOrders.WIP = ProductionSchedule.Operation
	|			AND TT_AllMatchingOrders.Start <= ProductionSchedule.StartDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReplanningOrdersPriorities.ProductionOrder AS ProductionOrder,
	|	SUM(ISNULL(ManufacturingProcessSupplyTurnovers.ScheduledTurnover, 0)) AS Scheduled
	|FROM
	|	InformationRegister.ProductionOrdersPriorities AS ProductionOrdersPriorities
	|		INNER JOIN InformationRegister.ProductionOrdersPriorities AS ReplanningOrdersPriorities
	|		ON (CASE
	|				WHEN ProductionOrdersPriorities.PriorityOrder < ReplanningOrdersPriorities.PriorityOrder
	|					THEN TRUE
	|				WHEN ProductionOrdersPriorities.PriorityOrder = ReplanningOrdersPriorities.PriorityOrder
	|					THEN ProductionOrdersPriorities.Queue < ReplanningOrdersPriorities.Queue
	|				ELSE FALSE
	|			END)
	|		LEFT JOIN AccumulationRegister.ManufacturingProcessSupply.Turnovers AS ManufacturingProcessSupplyTurnovers
	|		ON (ReplanningOrdersPriorities.ProductionOrder = ManufacturingProcessSupplyTurnovers.Reference)
	|WHERE
	|	ProductionOrdersPriorities.ProductionOrder IN
	|			(SELECT
	|				TT_WorkCenterTypes.ProductionOrder AS ProductionOrder
	|			FROM
	|				TT_WorkCenterTypes AS TT_WorkCenterTypes)
	|	AND ReplanningOrdersPriorities.ProductionOrder IN
	|			(SELECT
	|				TT_AllLaterPlannedOrders.ProductionOrder AS ProductionOrder
	|			FROM
	|				TT_AllLaterPlannedOrders AS TT_AllLaterPlannedOrders)
	|
	|GROUP BY
	|	ReplanningOrdersPriorities.ProductionOrder";
	
	Query.SetParameter("WIPs", WIPs);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If SelectionDetailRecords.Scheduled = 0
			And OrdersToExclude.Find(SelectionDetailRecords.ProductionOrder) = Undefined Then
		
			AddAllOperationsOfOrder(SelectionDetailRecords.ProductionOrder);
		
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

Function OrderInProgress(ProductionOrder)
	
	Result = False;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ProductionOrdersStates.State AS State
		|FROM
		|	InformationRegister.ProductionOrdersStates AS ProductionOrdersStates
		|WHERE
		|	ProductionOrdersStates.ProductionOrder = &ProductionOrder";
	
	Query.SetParameter("ProductionOrder", ProductionOrder);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		
		Result = (SelectionDetailRecords.State = Enums.ProductionOrdersStates.PlanStages);
		
	EndIf;
	
	Return Result;
	
EndFunction

Procedure AddStartesOrdersInOrdersToExclude(OrdersToExclude)
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	ManufacturingOperation.BasisDocument AS ProductionOrder
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|WHERE
	|	ManufacturingOperation.Status <> VALUE(Enum.ManufacturingOperationStatuses.Open)";
	
	StartedOrders = Query.Execute().Unload().UnloadColumn("ProductionOrder");
	
	CommonClientServer.SupplementArray(OrdersToExclude, StartedOrders, True);
	
EndProcedure

#EndRegion

#EndIf