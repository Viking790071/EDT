#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function NewQueueNumber(Priority) Export
	
	NewQueueNumber = 1;
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	ProductionOrdersPriorities.Queue + 1 AS NewQueueNumber
	|FROM
	|	InformationRegister.ProductionOrdersPriorities AS ProductionOrdersPriorities
	|WHERE
	|	ProductionOrdersPriorities.Priority = &Priority
	|
	|ORDER BY
	|	NewQueueNumber DESC";
	
	Query.SetParameter("Priority", Priority);
	
	SetPrivilegedMode(True);
	
	QueryResult = Query.Execute();
	
	SetPrivilegedMode(False);
	
	If Not QueryResult.IsEmpty() Then
		
		SelectionDetailRecords = QueryResult.Select();
		SelectionDetailRecords.Next();
		
		NewQueueNumber = SelectionDetailRecords.NewQueueNumber;
		
	EndIf;
	
	Return NewQueueNumber;
	
EndFunction

Function OrderCanBeMoved(Order, Direction) Export
	
	Result = False;
	
	If Direction <> 0 Then
		
		Query = New Query;
		
		Query.Text = 
		"SELECT TOP 1
		|	TRUE AS Field1
		|FROM
		|	InformationRegister.ProductionOrdersPriorities AS ProductionOrdersPriorities
		|		INNER JOIN InformationRegister.ProductionOrdersPriorities AS CurrentOrderPriority
		|		ON (CurrentOrderPriority.ProductionOrder = &Order)
		|			AND ProductionOrdersPriorities.Priority = CurrentOrderPriority.Priority
		|			AND (&TextDirection)
		|			AND (ProductionOrdersPriorities.ProductionOrder.Posted)";
		
		Query.SetParameter("Order", Order);
		
		If Direction > 0 Then
			
			Query.Text = StrReplace(Query.Text, "&TextDirection", "ProductionOrdersPriorities.Queue > CurrentOrderPriority.Queue");
			
		Else
			
			Query.Text = StrReplace(Query.Text, "&TextDirection", "ProductionOrdersPriorities.Queue < CurrentOrderPriority.Queue");
			
		EndIf;
		
		SetPrivilegedMode(True);
	
		QueryResult = Query.Execute();
		
		SetPrivilegedMode(False);
		
		Result = Not QueryResult.IsEmpty();
		
	EndIf;
	
	Return Result;
	
EndFunction

Procedure MoveOrderInQueue(Order, Direction) Export
	
	Query = New Query;
	
	If Direction > 0 Then
		
		Query.Text = 
		"SELECT TOP 2
		|	ProductionOrdersPriorities.Queue AS Queue,
		|	ProductionOrdersPriorities.Priority AS Priority
		|INTO TwoLowestInQueue
		|FROM
		|	InformationRegister.ProductionOrdersPriorities AS ProductionOrdersPriorities
		|		INNER JOIN InformationRegister.ProductionOrdersPriorities AS CurrentOrderPriority
		|		ON (CurrentOrderPriority.ProductionOrder = &Order)
		|			AND ProductionOrdersPriorities.Priority = CurrentOrderPriority.Priority
		|			AND ProductionOrdersPriorities.Queue > CurrentOrderPriority.Queue
		|			AND (ProductionOrdersPriorities.ProductionOrder.Posted)
		|
		|ORDER BY
		|	Queue
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	MAX(TwoLowestInQueue.Queue) AS MaxQueue,
		|	AVG(TwoLowestInQueue.Queue) AS AverageQueue,
		|	TwoLowestInQueue.Priority AS Priority
		|INTO TT_MaxAvInQueue
		|FROM
		|	TwoLowestInQueue AS TwoLowestInQueue
		|
		|GROUP BY
		|	TwoLowestInQueue.Priority
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CASE
		|		WHEN TT_MaxAvInQueue.MaxQueue = TT_MaxAvInQueue.AverageQueue
		|			THEN TT_MaxAvInQueue.AverageQueue + 1
		|		ELSE TT_MaxAvInQueue.AverageQueue
		|	END AS NewQueueNumber,
		|	TT_MaxAvInQueue.Priority AS Priority,
		|	ProductionOrdersPriorities.Order AS PriorityOrder
		|FROM
		|	TT_MaxAvInQueue AS TT_MaxAvInQueue
		|		LEFT JOIN Catalog.ProductionOrdersPriorities AS ProductionOrdersPriorities
		|		ON TT_MaxAvInQueue.Priority = ProductionOrdersPriorities.Ref";
		
	Else
		
		Query.Text = 
		"SELECT TOP 2
		|	ProductionOrdersPriorities.Queue AS Queue,
		|	ProductionOrdersPriorities.Priority AS Priority
		|INTO TwoBiggestInQueue
		|FROM
		|	InformationRegister.ProductionOrdersPriorities AS ProductionOrdersPriorities
		|		INNER JOIN InformationRegister.ProductionOrdersPriorities AS CurrentOrderPriority
		|		ON (CurrentOrderPriority.ProductionOrder = &Order)
		|			AND ProductionOrdersPriorities.Priority = CurrentOrderPriority.Priority
		|			AND ProductionOrdersPriorities.Queue < CurrentOrderPriority.Queue
		|			AND (ProductionOrdersPriorities.ProductionOrder.Posted)
		|
		|ORDER BY
		|	Queue DESC
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	MIN(TwoBiggestInQueue.Queue) AS MinQueue,
		|	AVG(TwoBiggestInQueue.Queue) AS AverageQueue,
		|	TwoBiggestInQueue.Priority AS Priority
		|INTO TT_MinAvInQueue
		|FROM
		|	TwoBiggestInQueue AS TwoBiggestInQueue
		|
		|GROUP BY
		|	TwoBiggestInQueue.Priority
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CASE
		|		WHEN TT_MinAvInQueue.MinQueue = TT_MinAvInQueue.AverageQueue
		|			THEN TT_MinAvInQueue.MinQueue / 2
		|		ELSE TT_MinAvInQueue.AverageQueue
		|	END AS NewQueueNumber,
		|	TT_MinAvInQueue.Priority AS Priority,
		|	ProductionOrdersPriorities.Order AS PriorityOrder
		|FROM
		|	TT_MinAvInQueue AS TT_MinAvInQueue
		|		LEFT JOIN Catalog.ProductionOrdersPriorities AS ProductionOrdersPriorities
		|		ON TT_MinAvInQueue.Priority = ProductionOrdersPriorities.Ref";
		
	EndIf;
	
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		InformationRegisters.JobsForProductionScheduleCalculation.AddAllOperationsOfOrder(Order);
		
		SelectionDetailRecords = QueryResult.Select();
		SelectionDetailRecords.Next();
		
		NewRecord = InformationRegisters.ProductionOrdersPriorities.CreateRecordManager();
		NewRecord.Priority = SelectionDetailRecords.Priority;
		NewRecord.PriorityOrder = SelectionDetailRecords.PriorityOrder;
		NewRecord.ProductionOrder = Order;
		NewRecord.Queue = SelectionDetailRecords.NewQueueNumber;
		NewRecord.Write(True);
		
		InformationRegisters.JobsForProductionScheduleCalculation.AddAllOperationsOfOrder(Order);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf

