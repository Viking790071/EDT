#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillReservationTable();
	
	Items.ReservationTable.RowFilter = New FixedStructure("InStock", True);
	
EndProcedure

#EndRegion

#Region ReservationTableFormTableItemsEventHandlers

&AtClient
Procedure ReservationTableValueChoice(Item, Value, StandardProcessing)
	
	NotifyChoice(ReservationTable.FindByID(Value).SalesOrder);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillReservationTable()
	
	DocumentData = GetFromTempStorage(Parameters.DocumentDataTempStorageAddress);
	
	KeyFieldsString = "Products, Characteristic, Order";
	SearchFilter = New Structure(KeyFieldsString);
	
	FillPropertyValues(SearchFilter, Parameters.CurrentRow);
	
	Balances = DocumentData.Parameters.Table_Balances.FindRows(SearchFilter);
	
	For Each RowBalance In Balances Do
		
		NewRow = ReservationTable.Add();
		NewRow.SalesOrder = RowBalance.SalesOrder;
		NewRow.Balance = RowBalance.Quantity;
		NewRow.InStock = (RowBalance.Quantity > 0);
		
		If Parameters.CurrentRow.SalesOrder = RowBalance.SalesOrder Then
			Items.ReservationTable.CurrentRow = NewRow.GetID();
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion