#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ProductionOrders = Undefined;
	If Parameters.Property("ProductionOrders", ProductionOrders) Then
		
		// If all orders in the list have an updated schedule, "Reschedule all operations" is enabled
		Query = New Query;
		Query.Text = 
		"SELECT
		|	ProductionOrder.Ref AS Ref
		|INTO TT_Orders
		|FROM
		|	Document.ProductionOrder AS ProductionOrder
		|WHERE
		|	ProductionOrder.Ref IN(&ProductionOrders)
		|
		|INDEX BY
		|	Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_Orders.Ref AS Ref
		|FROM
		|	TT_Orders AS TT_Orders
		|		INNER JOIN InformationRegister.ProductionOrdersStates AS ProductionOrdersStates
		|		ON TT_Orders.Ref = ProductionOrdersStates.ProductionOrder
		|		INNER JOIN InformationRegister.JobsForProductionScheduleCalculation AS JobsForProductionScheduleCalculation
		|		ON TT_Orders.Ref = JobsForProductionScheduleCalculation.ProductionOrder
		|WHERE
		|	ProductionOrdersStates.State = VALUE(Enum.ProductionOrdersStates.PlanStages)";
		
		Query.SetParameter("ProductionOrders", ProductionOrders);
		
		QueryResult = Query.Execute();
		
		FullReplanning = QueryResult.IsEmpty();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ScheduleOperations = True;
	FormManagment();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FullReplanningOnChange(Item)
	
	FormManagment();
	
	If Not FullReplanning Then
		
		PlanTheQueueByTheCurrentOne = False;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Plan(Command)
	
	CloseParameters = New Structure;
	CloseParameters.Insert("FullReplanning", FullReplanning);
	CloseParameters.Insert("PlanTheQueueByTheCurrentOne", PlanTheQueueByTheCurrentOne);
	
	Close(CloseParameters);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure FormManagment()
	
	Items.PlanTheQueueByTheCurrentOne.Enabled = FullReplanning;
	
EndProcedure

#EndRegion