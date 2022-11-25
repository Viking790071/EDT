
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructure = New Structure;
	
	If TypeOf(CommandParameter) = Type("CatalogRef.Products") Then
		FilterStructure.Insert("Products", CommandParameter);
	Else
		ProductsList = GetProductsListOfDocument(CommandParameter);
		FilterStructure.Insert("Products", ProductsList);
	EndIf;
	
	FormParameters = New Structure("VariantKey, Filter, GenerateOnOpen, ReportOptionsCommandsVisibility", "AvailableBalanceContext", FilterStructure, True, False);
	
	OpenForm("Report.AvailableStock.Form", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure

&AtServer
Function GetProductsListOfDocument(Document)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	GoodsIssueProducts.Products AS Products
	|FROM
	|	Document.GoodsIssue.Products AS GoodsIssueProducts
	|WHERE
	|	GoodsIssueProducts.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	InventoryReservationInventory.Products
	|FROM
	|	Document.InventoryReservation.Inventory AS InventoryReservationInventory
	|WHERE
	|	InventoryReservationInventory.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	SalesInvoiceInventory.Products
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|WHERE
	|	SalesInvoiceInventory.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	SalesOrderInventory.Products
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|WHERE
	|	SalesOrderInventory.Ref = &Ref
	// begin Drive.FullVersion
	|
	|UNION ALL
	|
	|SELECT
	|	ProductionOrderProducts.Products
	|FROM
	|	Document.ProductionOrder.Products AS ProductionOrderProducts
	|WHERE
	|	ProductionOrderProducts.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	ProductionOrderInventory.Products
	|FROM
	|	Document.ProductionOrder.Inventory AS ProductionOrderInventory
	|WHERE
	|	ProductionOrderInventory.Ref = &Ref
	|
	// end Drive.FullVersion
	|";
	
	Query.SetParameter("Ref", Document);
	
	ProductsList = Query.Execute().Unload().UnloadColumn("Products");
	
	Return ProductsList;
	
EndFunction
