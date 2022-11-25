
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillPropertyValues(ThisObject, ExternalUsers.ExternalUserAuthorizationData());
	CommonClientServer.SetDynamicListParameter(List, "Counterparty", AuthorizedCounterparty);
	CommonClientServer.SetDynamicListParameter(List, "UseContractRestrictionsTurnOff",
		Not GetFunctionalOption("UseContractRestrictionsForExternalUsers"));
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	FormManagment();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure StatusFilterOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "PaymentStatus", Status, ValueIsFilled(Status));
	
EndProcedure

&AtClient
Procedure CompanyFilterOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	
EndProcedure

&AtClient
Procedure WarehouseFilterOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "StructuralUnit", Warehouse, ValueIsFilled(Warehouse));
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	GeneratePrintFormSalesInvoice();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OpenDocument(Command)
	
	GeneratePrintFormSalesInvoice();
	
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
Procedure GeneratePrintFormSalesInvoice()
	
	If Items.List.SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	RefsArray = New Array;
	
	For Each Row In Items.List.SelectedRows Do
		RefsArray.Add(Row);
	EndDo;
	
	PrintManagementClientDrive.GeneratePrintFormForExternalUsers(RefsArray,
		"Document.SalesInvoice",
		"SalesInvoice",
		NStr("en = 'Sales invoice'; ru = 'Инвойс покупателю';pl = 'Faktura sprzedaży';es_ES = 'Factura de ventas';es_CO = 'Factura de ventas';tr = 'Satış faturası';it = 'Fattura di vendita';de = 'Verkaufsrechnung'"),
		FormOwner,
		UniqueKey);
	
EndProcedure

#EndRegion