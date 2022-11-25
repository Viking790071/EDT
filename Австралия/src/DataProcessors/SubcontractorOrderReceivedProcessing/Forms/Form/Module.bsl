
#Region FormEventHandlers

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterCompany = Settings.Get("FilterCompany");
	FilterResponsible = Settings.Get("FilterResponsible");
	FilterCounterparty = Settings.Get("FilterCounterparty");
	
	DriveClientServer.SetListFilterItem(ProductionOrder, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(ProductionOrder, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	DriveClientServer.SetListFilterItem(ProductionOrder, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
	DriveClientServer.SetListFilterItem(ComponentsReceipt, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(ComponentsReceipt, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	DriveClientServer.SetListFilterItem(ComponentsReceipt, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
	DriveClientServer.SetListFilterItem(ComponentsReturn, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(ComponentsReturn, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	DriveClientServer.SetListFilterItem(ComponentsReturn, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
	DriveClientServer.SetListFilterItem(ProductsTransfer, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(ProductsTransfer, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	DriveClientServer.SetListFilterItem(ProductsTransfer, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
	DriveClientServer.SetListFilterItem(Invoices, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(Invoices, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	DriveClientServer.SetListFilterItem(Invoices, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "NotificationSubcontractingServicesDocumentsChange" Then
		Items.ProductionOrder.Refresh();
		Items.ComponentsReceipt.Refresh();
		Items.ComponentsReturn.Refresh();
		Items.ProductsTransfer.Refresh();
		Items.Invoices.Refresh();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterCompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(ProductionOrder, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(ComponentsReceipt, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(ComponentsReturn, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(ProductsTransfer, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(Invoices, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

&AtClient
Procedure FilterResponsibleOnChange(Item)
	
	DriveClientServer.SetListFilterItem(ProductionOrder, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	DriveClientServer.SetListFilterItem(ComponentsReceipt, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	DriveClientServer.SetListFilterItem(ComponentsReturn, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	DriveClientServer.SetListFilterItem(ProductsTransfer, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	DriveClientServer.SetListFilterItem(Invoices, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

&AtClient
Procedure FilterCounterpartyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(ProductionOrder, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	DriveClientServer.SetListFilterItem(ComponentsReceipt, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	DriveClientServer.SetListFilterItem(ComponentsReturn, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	DriveClientServer.SetListFilterItem(ProductsTransfer, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	DriveClientServer.SetListFilterItem(Invoices, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure PagesOnCurrentPageChange(Item, CurrentPage)
	
	For Each ChildItem In CurrentPage.ChildItems Do
		
		If TypeOf(ChildItem) = Type("FormTable") Then
			ChildItem.Refresh();
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion 

#Region FormCommandsEventHandlers

&AtClient
Procedure GenerateProductionOrder(Command)

	CurrentRowData = Items.ProductionOrder.CurrentData;
	
	If CurrentRowData <> Undefined Then
		OpenForm("Document.ProductionOrder.ObjectForm", New Structure("Basis", CurrentRowData.Ref));
	EndIf;

EndProcedure

&AtClient
Procedure GenerateGoodsReceipt(Command)
	
	CurrentRowData = Items.ComponentsReceipt.CurrentData;
	
	If CurrentRowData <> Undefined Then
		OpenForm("Document.GoodsReceipt.ObjectForm", New Structure("Basis", CurrentRowData.Ref));
	EndIf;
	
EndProcedure

&AtClient
Procedure GenerateGoodsReturn(Command)
	
	CurrentRowData = Items.ComponentsReturn.CurrentData;
	
	If CurrentRowData <> Undefined Then
		
		FillingData = New Structure(
			"SubcontractorOrderReceived, OperationType",
			CurrentRowData.Ref,
			PredefinedValue("Enum.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer"));
		
		OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", FillingData));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GenerateGoodsTransfer(Command)
	
	CurrentRowData = Items.ProductsTransfer.CurrentData;
	
	If CurrentRowData <> Undefined Then
		
		FillingData = New Structure(
			"SubcontractorOrderReceived, OperationType",
			CurrentRowData.Ref,
			PredefinedValue("Enum.OperationTypesGoodsIssue.TransferToSubcontractingCustomer"));
		
		OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", FillingData));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GenerateSubcontractorInvoiceIssued(Command)
	
	CurrentRowData = Items.Invoices.CurrentData;
	
	If CurrentRowData <> Undefined Then
		OpenForm("Document.SubcontractorInvoiceIssued.ObjectForm", New Structure("Basis", CurrentRowData.Ref));
	EndIf;
	
EndProcedure

#EndRegion
