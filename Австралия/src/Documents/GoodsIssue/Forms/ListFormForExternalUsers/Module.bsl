
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
	
	DriveClientServer.SetListFilterItem(List, "Status", Status, ValueIsFilled(Status));
	
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
	GeneratePrintFormGoodsIssue();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OpenDocument(Command)
	
	GeneratePrintFormGoodsIssue();
	
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
Procedure GeneratePrintFormGoodsIssue()
	
	If Items.List.SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	RefsArray = New Array;
	
	For Each Row In Items.List.SelectedRows Do
		RefsArray.Add(Row);
	EndDo;
	
	PrintManagementClientDrive.GeneratePrintFormForExternalUsers(RefsArray,
		"Document.GoodsIssue",
		"DeliveryNote",
		NStr("en = 'Delivery note'; ru = 'Уведомление о доставке';pl = 'Wydanie zewnętrzne';es_ES = 'Nota de entrega';es_CO = 'Nota de entrega';tr = 'Sevk irsaliyesi';it = 'Documento di trasporto';de = 'Lieferschein'"),
		FormOwner,
		UniqueKey);
	
EndProcedure

#EndRegion