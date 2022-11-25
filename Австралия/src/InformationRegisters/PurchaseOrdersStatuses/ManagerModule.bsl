#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure ReflectOrderStates(PurchaseOrder) Export
	
	DateRecords = CurrentSessionDate();
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	HeaderPurchaseOrder.Ref AS PurchaseOrder,
	|	HeaderPurchaseOrder.OrderState AS Status,
	|	CASE
	|		WHEN HeaderPurchaseOrder.OrderState = PurchaseOrdersStatusesSliceLast.Status
	|			THEN FALSE
	|		WHEN PurchaseOrdersStatusesSliceLast.Status IS NULL
	|			THEN TRUE
	|		ELSE TRUE
	|	END AS IsNewRecord,
	|	PurchaseOrdersStatusesSliceLast.StatusHistory AS StatusHistory,
	|	HeaderPurchaseOrder.OrderState.Presentation AS OrderStatePresentation
	|FROM
	|	Document.PurchaseOrder AS HeaderPurchaseOrder
	|		LEFT JOIN InformationRegister.PurchaseOrdersStatuses.SliceLast(&PointInTime, PurchaseOrder = &PurchaseOrder) AS PurchaseOrdersStatusesSliceLast
	|		ON (PurchaseOrdersStatusesSliceLast.PurchaseOrder = HeaderPurchaseOrder.Ref)
	|WHERE
	|	HeaderPurchaseOrder.Ref = &PurchaseOrder";
	
	Query.SetParameter("PurchaseOrder", PurchaseOrder);
	Query.SetParameter("PointInTime", DateRecords);
	
	QueryResult = Query.Execute();
	
	SelectionDetailStatus = QueryResult.Select();
	
	While SelectionDetailStatus.Next() Do
		
		If Not SelectionDetailStatus.IsNewRecord Then
			Break;
		EndIf;
		
		RecordsSet = InformationRegisters.PurchaseOrdersStatuses.CreateRecordSet();
		RecordsSet.Filter.PurchaseOrder.Set(PurchaseOrder);
		RecordsSet.Filter.Period.Set(DateRecords);
		
		NewRecord = RecordsSet.Add();
		FillPropertyValues(NewRecord, SelectionDetailStatus);
		NewRecord.Period = DateRecords;
		NewRecord.StatusHistory = NewRecord.StatusHistory + Chars.CR + SelectionDetailStatus.OrderStatePresentation 
			+ " " + Format(DateRecords, "DLF=D");
		
		RecordsSet.Write();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf