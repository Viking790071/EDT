
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DocumentInitiator = Undefined;
	Parameters.Property("DocumentInitiator", DocumentInitiator);
	
	DataProcessorObject = FormAttributeToValue("Object");
	DataProcessorObject.FillOrders(Parameters);
	ValueToFormAttribute(DataProcessorObject, "Object");
	FormManagment();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure MarkAllExecute(Command)
	
	Tab = StrReplace(Items.Pages.CurrentPage.Name, "Page", "");
	
	For Each Row In Object[Tab] Do
		Row.Mark = True;	
	EndDo;
	
EndProcedure

&AtClient
Procedure ClearAllExecute(Command)
	
	Tab = StrReplace(Items.Pages.CurrentPage.Name, "Page", "");
	
	For Each Row In Object[Tab] Do
		Row.Mark = False;	
	EndDo;
	
EndProcedure

&AtClient
Procedure Complete(Command)
	CompleteAtServer();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FormManagment()
	
	AreProductionOrders = False;
	AreSubcontractorOrdersReceived = False;
	
	// begin Drive.FullVersion
	AreProductionOrders = (Object.ProductionOrders.Count() And AccessRight("Edit", Metadata.Documents.ProductionOrder));
	AreSubcontractorOrdersReceived = (Object.SubcontractorOrdersReceived.Count()
		And AccessRight("Edit", Metadata.Documents.SubcontractorInvoiceReceived));
	// end Drive.FullVersion
	
	AreSalesOrders = (Object.SalesOrders.Count() And AccessRight("Edit", Metadata.Documents.SalesOrder));
	ArePurchaseOrders = (Object.PurchaseOrders.Count() And AccessRight("Edit", Metadata.Documents.PurchaseOrder));
	AreWorkOrders = (Object.WorkOrders.Count() And AccessRight("Edit", Metadata.Documents.WorkOrder));
	AreSubcontractorOrdersIssued = (Object.SubcontractorOrdersIssued.Count()
		And AccessRight("Edit", Metadata.Documents.SubcontractorOrderIssued));
	AreKitOrders = (Object.KitOrders.Count() And AccessRight("Edit", Metadata.Documents.KitOrder));
	
	Items.PageSalesOrders.Visible = AreSalesOrders;
	Items.PagePurchaseOrders.Visible = ArePurchaseOrders;
	Items.PageProductionOrders.Visible = AreProductionOrders;
	Items.PageWorkOrders.Visible = AreWorkOrders;
	Items.PageSubcontractorOrdersIssued.Visible = AreSubcontractorOrdersIssued;
	Items.PageSubcontractorOrdersReceived.Visible = AreSubcontractorOrdersReceived;
	Items.PageKitOrders.Visible = AreKitOrders;
	
	ThereAreOrders = AreSalesOrders
		Or ArePurchaseOrders
		Or AreProductionOrders
		Or AreWorkOrders
		Or AreSubcontractorOrdersIssued
		Or AreSubcontractorOrdersReceived
		Or AreKitOrders;
	
	Items.DecorationAllOrdersClosed.Visible = Not ThereAreOrders;
	Items.CloseOrders.Visible = ThereAreOrders;
	
EndProcedure

&AtServer
Procedure CompleteAtServer()
	
	DataProcessorObject = FormAttributeToValue("Object");
	DataProcessorObject.CloseOrders();
	ValueToFormAttribute(DataProcessorObject, "Object");
	
EndProcedure

#EndRegion
