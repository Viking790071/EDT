#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter",			New Structure("PurchaseOrder", GetPurchaseOrder(CommandParameter)));
	FormParameters.Insert("GenerateOnOpen",	True);
	
	OpenForm("Report.PurchaseOrdersStatement.Form",
		FormParameters,
		,
		"PurchaseOrder=" + CommandParameter,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function GetPurchaseOrder(ArrayOfSupplierInvoices)
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SupplierInvoiceInventory.Order AS Order
	|INTO OrdersTable
	|FROM
	|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|WHERE
	|	SupplierInvoiceInventory.Ref IN(&ArrayOfRef)
	|
	|UNION ALL
	|
	|SELECT
	|	SupplierInvoiceExpenses.PurchaseOrder
	|FROM
	|	Document.SupplierInvoice.Expenses AS SupplierInvoiceExpenses
	|WHERE
	|	SupplierInvoiceExpenses.Ref IN(&ArrayOfRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	OrdersTable.Order AS Order
	|FROM
	|	OrdersTable AS OrdersTable
	|WHERE
	|	OrdersTable.Order <> UNDEFINED
	|	AND OrdersTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)";
	
	Query.SetParameter("ArrayOfRef", ArrayOfSupplierInvoices);
	
	ResultTable = Query.Execute().Unload();
	ArrayOfOrders = ResultTable.UnloadColumn("Order");
	
	OrderList = New ValueList;
	OrderList.LoadValues(ArrayOfOrders);
	
	Return OrderList;
	
EndFunction

#EndRegion