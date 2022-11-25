#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region CloneProductRelatedData

Procedure MakeRelatedProductGLAccounts(ProductReceiver, ProductSource) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ProductGLAccounts.Company AS Company,
		|	ProductGLAccounts.Product AS Product,
		|	ProductGLAccounts.ProductCategory AS ProductCategory,
		|	ProductGLAccounts.StructuralUnit AS StructuralUnit,
		|	ProductGLAccounts.Inventory AS Inventory,
		|	ProductGLAccounts.InventoryTransferred AS InventoryTransferred,
		|	ProductGLAccounts.InventoryReceived AS InventoryReceived,
		|	ProductGLAccounts.SignedOutEquipment AS SignedOutEquipment,
		|	ProductGLAccounts.GoodsShippedNotInvoiced AS GoodsShippedNotInvoiced,
		|	ProductGLAccounts.GoodsReceivedNotInvoiced AS GoodsReceivedNotInvoiced,
		|	ProductGLAccounts.GoodsInvoicedNotDelivered AS GoodsInvoicedNotDelivered,
		|	ProductGLAccounts.UnearnedRevenue AS UnearnedRevenue,
		|	ProductGLAccounts.VATInput AS VATInput,
		|	ProductGLAccounts.VATOutput AS VATOutput,
		|	ProductGLAccounts.Revenue AS Revenue,
		|	ProductGLAccounts.COGS AS COGS,
		|	ProductGLAccounts.Consumption AS Consumption,
		|	ProductGLAccounts.SalesReturn AS SalesReturn,
		|	ProductGLAccounts.PurchaseReturn AS PurchaseReturn,
		|	ProductGLAccounts.AbnormalScrap AS AbnormalScrap
		|FROM
		|	InformationRegister.ProductGLAccounts AS ProductGLAccounts
		|WHERE
		|	ProductGLAccounts.Product = &ProductSource";
	
	Query.SetParameter("ProductSource", ProductSource);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	NewRecords = InformationRegisters.ProductGLAccounts.CreateRecordSet();
	NewRecords.Filter.Product.Set(ProductReceiver);
	
	While SelectionDetailRecords.Next() Do
		NewRecord = NewRecords.Add();
		FillPropertyValues(NewRecord, SelectionDetailRecords,,"Product");
		NewRecord.Product = ProductReceiver;
		NewRecords.Write();
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf