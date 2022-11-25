
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillPropertyValues(ThisObject, ExternalUsers.ExternalUserAuthorizationData());
	CommonClientServer.SetDynamicListParameter(List, "Counterparty", AuthorizedCounterparty);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	FormManagment();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CompanyFilterOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	GeneratePrintFormTaxInvoiceIssued();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OpenDocument(Command)
	
	GeneratePrintFormTaxInvoiceIssued();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FormManagment()
	
	CommonClientServer.SetFormItemProperty(Items,
		"BusinessProcessJobCreateBasedOn",
		"Visible",
		GetFunctionalOption("UseSupportForExternalUsers"));
	
EndProcedure

&AtClient
Procedure GeneratePrintFormTaxInvoiceIssued()
	
	If Items.List.SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	RefsArray = New Array;
	
	For Each Row In Items.List.SelectedRows Do
		RefsArray.Add(Row);
	EndDo;
	
	PrintManagementClientDrive.GeneratePrintFormForExternalUsers(RefsArray,
		"Document.TaxInvoiceIssued",
		"TaxInvoice",
		NStr("en = 'Tax invoice'; ru = 'Налоговый инвойс';pl = 'Faktura VAT';es_ES = 'Factura de impuestos';es_CO = 'Factura de impuestos';tr = 'Vergi faturası';it = 'Fattura fiscale';de = 'Steuerrechnung'"),
		FormOwner,
		UniqueKey);
	
EndProcedure

#EndRegion