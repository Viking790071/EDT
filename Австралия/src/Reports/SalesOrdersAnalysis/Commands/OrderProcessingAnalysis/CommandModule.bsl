#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Parameters = New Structure;
	Parameters.Insert("VariantKey", "Default");
	Parameters.Insert("PurposeUseKey", CommandParameter);
	Filter = New Structure;
	Filter.Insert("SalesOrder", LinkedSalesOrders(CommandParameter));
	Parameters.Insert("Filter", Filter);
	Parameters.Insert("GenerateOnOpen", True);
	
	OpenForm("Report.SalesOrdersAnalysis.Form",
		Parameters, , "SalesOrder=" + CommandParameter, CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function LinkedSalesOrders(CommandParameter)
	
	Query = New Query;
	
	If TypeOf(CommandParameter) = Type("DocumentRef.SalesInvoice") Then
		Query.Text =
		"SELECT ALLOWED DISTINCT
		|	SalesInvoiceInventory.Order AS Order
		|FROM
		|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
		|WHERE
		|	SalesInvoiceInventory.Ref = &CommandParameter";
	EndIf;
	
	If TypeOf(CommandParameter) = Type("DocumentRef.InventoryReservation") Then
		Query.Text =
		"SELECT ALLOWED
		|	InventoryReservation.SalesOrder AS Order
		|FROM
		|	Document.InventoryReservation AS InventoryReservation
		|WHERE
		|	InventoryReservation.Ref = &CommandParameter";
	EndIf;
	
	If TypeOf(CommandParameter) = Type("DocumentRef.GoodsIssue") Then
		Query.Text =
		"SELECT ALLOWED
		|	GoodsIssue.Order AS Order
		|FROM
		|	Document.GoodsIssue AS GoodsIssue
		|WHERE
		|	GoodsIssue.Ref = &CommandParameter";
	EndIf;
	
	Query.SetParameter("CommandParameter", CommandParameter);
	
	Return Query.Execute().Unload().UnloadColumn("Order");
	
EndFunction

#EndRegion