#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure ReflectOrdersStates(ProductionOrder) Export
	
	OrdersArray = DriveClientServer.ArrayFromItem(ProductionOrder);
	If OrdersArray.Count() Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	ManufacturingProcessSupplyTurnovers.Reference AS Reference,
		|	ManufacturingProcessSupplyTurnovers.Products AS Products,
		|	ManufacturingProcessSupplyTurnovers.Characteristic AS Characteristic,
		|	ManufacturingProcessSupplyTurnovers.Specification AS Specification,
		|	ManufacturingProcessSupplyTurnovers.RequiredTurnover AS RequiredTurnover
		|INTO TT_Required
		|FROM
		|	AccumulationRegister.ManufacturingProcessSupply.Turnovers(, , , Reference IN (&ProductionOrders)) AS ManufacturingProcessSupplyTurnovers
		|WHERE
		|	ManufacturingProcessSupplyTurnovers.RequiredTurnover > 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_Required.Reference AS Reference,
		|	SUM(TT_Required.RequiredTurnover) AS RequiredTurnover,
		|	SUM(ManufacturingProcessSupplyTurnovers.TransferredToProductionTurnover + ManufacturingProcessSupplyTurnovers.ScheduledTurnover) AS TransferredToProductionTurnover,
		|	SUM(ManufacturingProcessSupplyTurnovers.ProducedTurnover) AS ProducedTurnover
		|INTO TT_ManufacturingProcessSupply
		|FROM
		|	TT_Required AS TT_Required
		|		LEFT JOIN AccumulationRegister.ManufacturingProcessSupply.Turnovers AS ManufacturingProcessSupplyTurnovers
		|		ON TT_Required.Reference = ManufacturingProcessSupplyTurnovers.Reference
		|			AND TT_Required.Products = ManufacturingProcessSupplyTurnovers.Products
		|			AND TT_Required.Characteristic = ManufacturingProcessSupplyTurnovers.Characteristic
		|			AND TT_Required.Specification = ManufacturingProcessSupplyTurnovers.Specification
		|
		|GROUP BY
		|	TT_Required.Reference
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_ManufacturingProcessSupply.Reference AS ProductionOrder,
		|	CASE
		|		WHEN TT_ManufacturingProcessSupply.ProducedTurnover = TT_ManufacturingProcessSupply.RequiredTurnover
		|			THEN VALUE(Enum.ProductionOrdersStates.EmptyRef)
		|		ELSE CASE
		|				WHEN TT_ManufacturingProcessSupply.ProducedTurnover + TT_ManufacturingProcessSupply.TransferredToProductionTurnover = TT_ManufacturingProcessSupply.RequiredTurnover
		|					THEN VALUE(Enum.ProductionOrdersStates.PlanStages)
		|				ELSE VALUE(Enum.ProductionOrdersStates.CreateStages)
		|			END
		|	END AS State
		|INTO TT_NewStates
		|FROM
		|	TT_ManufacturingProcessSupply AS TT_ManufacturingProcessSupply
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_NewStates.ProductionOrder AS ProductionOrder,
		|	TT_NewStates.State AS State
		|FROM
		|	TT_NewStates AS TT_NewStates
		|		LEFT JOIN InformationRegister.ProductionOrdersStates AS ProductionOrdersStates
		|		ON TT_NewStates.ProductionOrder = ProductionOrdersStates.ProductionOrder
		|WHERE
		|	(TT_NewStates.State <> ProductionOrdersStates.State
		|			OR ProductionOrdersStates.State IS NULL)";
		
		Query.SetParameter("ProductionOrders", OrdersArray);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		While SelectionDetailRecords.Next() Do
			
			RecordsSet = InformationRegisters.ProductionOrdersStates.CreateRecordSet();
			RecordsSet.Filter.ProductionOrder.Set(SelectionDetailRecords.ProductionOrder);
			If ValueIsFilled(SelectionDetailRecords.State) Then
				RecordsSet.Read();
				If RecordsSet.Count() Then
					RecordsSet[0].State = SelectionDetailRecords.State;
				Else
					NewRecord = RecordsSet.Add();
					FillPropertyValues(NewRecord, SelectionDetailRecords);
				EndIf;
			EndIf;
			RecordsSet.Write(True);
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure ClearOrdersStates(ProductionOrder) Export
	
	OrdersArray = DriveClientServer.ArrayFromItem(ProductionOrder);
	If OrdersArray.Count() Then
		
		For Each Order In OrdersArray Do
			
			RecordsSet = InformationRegisters.ProductionOrdersStates.CreateRecordSet();
			RecordsSet.Filter.ProductionOrder.Set(Order);
			RecordsSet.Write(True);
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf