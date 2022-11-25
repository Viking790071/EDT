
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillPropertyValues(ThisObject, ExternalUsers.ExternalUserAuthorizationData());
	CommonClientServer.SetDynamicListParameter(List, "Counterparty", AuthorizedCounterparty);
	CommonClientServer.SetDynamicListParameter(List, "UseContractRestrictionsTurnOff",
		Not GetFunctionalOption("UseContractRestrictionsForExternalUsers"));
		
	Items.FilterActuality.ChoiceList.Add("All", NStr("en = 'All'; ru = 'Все';pl = 'Wszystkie';es_ES = 'Todo';es_CO = 'Todo';tr = 'Tümü';it = 'Tutti';de = 'Alle'"));
	Items.FilterActuality.ChoiceList.Add("Except closed", NStr("en = 'Except closed'; ru = 'Кроме закрытых';pl = 'Z wyjątkiem zamkniętych';es_ES = 'Excepto cerrados';es_CO = 'Excepto cerrados';tr = 'Kapatılanlar hariç';it = 'Tranne i chiusi';de = 'Außer geschlossenen'"));
	Items.FilterActuality.ChoiceList.Add("Closed", NStr("en = 'Closed'; ru = 'Закрыт';pl = 'Zamknięte';es_ES = 'Cerrado';es_CO = 'Cerrado';tr = 'Kapatılanlar';it = 'Chiuso';de = 'Geschlossen'"));
	
	StatusesChoiceList = Items.StatusFilter.ChoiceList;
	StatusesStructure = Documents.SalesOrder.GetSalesOrderStringStatuses();
	
	For Each Item In StatusesStructure Do
		StatusesChoiceList.Add(Item.Value);
		CommonClientServer.SetDynamicListParameter(List, Item.Key, Item.Value);
	EndDo;
	
	List.Parameters.SetParameterValue("CurrentDateSession", BegOfDay(CurrentSessionDate()));
	
	// Use sales order status.
	UseStatuses = Constants.UseSalesOrderStatuses.Get();
	
	If UseStatuses Then
		Items.OrderStatus.Visible = False;
		Items.StatusFilter.Visible = False;
	Else
		Items.StateFilter.Visible = False;
		Items.OrderState.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	FormManagment();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure StatusFilterOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "OrderStatus", Status, ValueIsFilled(Status));
	
EndProcedure

&AtClient
Procedure CompanyFilterOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	
EndProcedure

&AtClient
Procedure FilterActualityOnChange(Item)
	
	If FilterActuality = "Except closed" Then
		DriveClientServer.SetListFilterItem(List, "Closed", False, True);
	ElsIf FilterActuality = "Closed" Then
		DriveClientServer.SetListFilterItem(List, "Closed", True, True);
	Else
		DriveClientServer.SetListFilterItem(List, "Closed", True, False);
	EndIf;
	
EndProcedure

&AtClient
Procedure StateFilterOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "OrderState", State, ValueIsFilled(State));
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	GeneratePrintFormSalesOrder();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OpenDocument(Command)

	GeneratePrintFormSalesOrder();
	
EndProcedure

&AtClient
Procedure Copy(Command)
	
	If Items.List.SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	RefsArray = New Array;
	
	For Each Row In Items.List.SelectedRows Do
		RefsArray.Add(Row);
	EndDo;
	
	Notify("Document.SalesOrder.CopyTS", RefsArray);
	OpenForm("DataProcessor.ProductCartForExternalUsers.Form", New Structure("BasisRefsArray", RefsArray));
	
EndProcedure

&AtClient
Procedure Create(Command)
	
	OpenForm("DataProcessor.ProductCartForExternalUsers.Form");
	
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
Procedure GeneratePrintFormSalesOrder()
	
	If Items.List.SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	RefsArray = New Array;
	
	For Each Row In Items.List.SelectedRows Do
		RefsArray.Add(Row);
	EndDo;
	
	PrintManagementClientDrive.GeneratePrintFormForExternalUsers(RefsArray,
		"Document.SalesOrder",
		"OrderConfirmation",
		NStr("en = 'Order confirmation'; ru = 'Заказ покупателя';pl = 'Potwierdzenie zamówienia';es_ES = 'Confirmación de pedido';es_CO = 'Confirmación de pedido';tr = 'Sipariş onayı';it = 'Conferma ordine';de = 'Auftragsbestätigung'"),
		FormOwner,
		UniqueKey);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SalesOrderCreatedByExternalUser" Then
		Items.List.Refresh();
	EndIf;
	
EndProcedure

#EndRegion