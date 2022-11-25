#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.ComponentsTransferGenerateGoodsIssue.Enabled = AccessRight("Posting", Metadata.Documents.GoodsIssue);
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterCompany = Settings.Get("FilterCompany");
	FilterResponsible = Settings.Get("FilterResponsible");
	FilterCounterparty = Settings.Get("FilterCounterparty");
	
	DriveClientServer.SetListFilterItem(ComponentsReturn, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(ComponentsReturn, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	DriveClientServer.SetListFilterItem(ComponentsReturn, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
	DriveClientServer.SetListFilterItem(ComponentsTransfer, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(ComponentsTransfer, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	DriveClientServer.SetListFilterItem(ComponentsTransfer, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
	DriveClientServer.SetListFilterItem(Invoices, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(Invoices, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	DriveClientServer.SetListFilterItem(Invoices, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
	DriveClientServer.SetListFilterItem(ProductsReceipt, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(ProductsReceipt, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	DriveClientServer.SetListFilterItem(ProductsReceipt, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "NotificationSubcontractDocumentsChange" Then
		Items.ComponentsTransfer.Refresh();
		Items.ProductsReceipt.Refresh();
		Items.Invoices.Refresh();
		Items.ComponentsReturn.Refresh();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterCompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(ComponentsReturn, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(ComponentsTransfer, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(Invoices, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(ProductsReceipt, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

&AtClient
Procedure FilterResponsibleOnChange(Item)
	
	DriveClientServer.SetListFilterItem(ComponentsReturn, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	DriveClientServer.SetListFilterItem(ComponentsTransfer, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	DriveClientServer.SetListFilterItem(Invoices, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	DriveClientServer.SetListFilterItem(ProductsReceipt, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

&AtClient
Procedure FilterCounterpartyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(ComponentsReturn, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	DriveClientServer.SetListFilterItem(ComponentsTransfer, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	DriveClientServer.SetListFilterItem(Invoices, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	DriveClientServer.SetListFilterItem(ProductsReceipt, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure GenerateGoodsIssue(Command)
	
	CurrentRowData = Items.ComponentsTransfer.CurrentData;
	
	If CurrentRowData <> Undefined Then
		OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", CurrentRowData.Ref));
	EndIf;
	
EndProcedure

&AtClient
Procedure GenerateGoodsReceipt(Command)
	
	CurrentRowData = Items.ProductsReceipt.CurrentData;
	
	If CurrentRowData <> Undefined Then
		
		BasisStructure = New Structure;
		BasisStructure.Insert("SubcontractorOrderRef", CurrentRowData.Ref);
		BasisStructure.Insert("OperationType", PredefinedValue("Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractor"));
		
		OpenForm("Document.GoodsReceipt.ObjectForm", New Structure("Basis", BasisStructure));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GenerateSubcontractorInvoice(Command)
	
	CurrentRowData = Items.Invoices.CurrentData;
	
	If CurrentRowData <> Undefined Then
		OpenForm("Document.SubcontractorInvoiceReceived.ObjectForm", New Structure("Basis", CurrentRowData.Ref));
	EndIf;
	
EndProcedure

&AtClient
Procedure GenerateGoodsReceiptReturn(Command)
	
	CurrentRowData = Items.ComponentsReturn.CurrentData;
	
	If CurrentRowData <> Undefined Then
		
		BasisStructure = New Structure;
		BasisStructure.Insert("SubcontractorOrderRef", CurrentRowData.Ref);
		BasisStructure.Insert("OperationType", PredefinedValue("Enum.OperationTypesGoodsReceipt.ReturnFromSubcontractor"));
		
		OpenForm("Document.GoodsReceipt.ObjectForm", New Structure("Basis", BasisStructure));
		
	EndIf;
	
EndProcedure

#EndRegion