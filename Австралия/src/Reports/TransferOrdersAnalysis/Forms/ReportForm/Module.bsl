
#Region ServiceProceduresAndFunctions

&AtServer
//  Replaces account documents when report call by settlement documents from receipt
//  If receipt by purchase order - the settlement document is the purchase order
//
//  Parameters:
//  Parameters - FormDataStructure - Report parameters
//
Procedure SetSelectionReport(Parameters) Export
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("TransferOrder") Then
		
		ParameterTransferOrder = Parameters.Filter.TransferOrder;
		
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED DISTINCT
		|	InventoryTransferInventory.SalesOrder AS Order
		|FROM
		|	Document.InventoryTransfer.Inventory AS InventoryTransferInventory
		|WHERE
		|	InventoryTransferInventory.Ref IN(&ParameterTransferOrder)";
		
		If AccessRight("Read", Metadata.Documents.InventoryReservation) Then
			Query.Text = Query.Text + "
			|UNION ALL
			|
			|SELECT DISTINCT
			|	InventoryReservation.SalesOrder
			|FROM
			|	Document.InventoryReservation AS InventoryReservation
			|WHERE
			|	InventoryReservation.Ref IN(&ParameterTransferOrder)
			|";
		EndIf;
		
		Query.Text = Query.Text + "
		|UNION ALL
		|
		|SELECT DISTINCT
		|	TransferOrder.Ref
		|FROM
		|	Document.TransferOrder AS TransferOrder
		|WHERE
		|	TransferOrder.Ref IN(&ParameterTransferOrder)";
		
		Query.SetParameter("ParameterTransferOrder", ParameterTransferOrder);
		
		ResultTable 				= Query.Execute().Unload();
		Parameters.Filter.TransferOrder = ResultTable.UnloadColumn("Order");
		
	EndIf;
	
EndProcedure

#Region ProcedureFormEventHandlers

&AtServer
//  Procedure - form event handler "OnCreateAtServer".
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Report.FilterByOrderStatuses = Items.FilterByOrderStatuses.ChoiceList[0].Value;
	
	If Parameters.Property("Filter")
		AND Parameters.Filter.Property("TransferOrder") Then
		
		Items.FilterByOrderStatuses.Enabled = False;
		SetSelectionReport(Parameters);
	
	EndIf;
	
	Parameters.GenerateOnOpen = True;

EndProcedure

&AtServer
Procedure OnSaveUserSettingsAtServer(Settings)
	ReportsOptions.OnSaveUserSettingsAtServer(ThisObject, Settings);
EndProcedure

&AtClient
// Procedure event handler OnChange of the FilterByOrderStatuses attribute 
//
Procedure FilterByOrderStatusesOnChange(Item)
	
	ComposeResult();
	
EndProcedure

#EndRegion

#EndRegion