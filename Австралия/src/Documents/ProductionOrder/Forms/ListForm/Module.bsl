#Region FormEventHandlers

// Procedure - Form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Constants.UseSeveralDepartments.Get()
		AND Not Constants.UseSeveralWarehouses.Get() Then
		
		Items.FilterDepartment.ListChoiceMode = True;
		Items.FilterDepartment.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.FilterDepartment.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
	EndIf;
	
	Items.FilterActuality.ChoiceList.Add("All", NStr("en = 'All'; ru = 'Все';pl = 'Wszystkie';es_ES = 'Todo';es_CO = 'Todo';tr = 'Tümü';it = 'Tutti';de = 'Alle'"));
	Items.FilterActuality.ChoiceList.Add("Except closed", NStr("en = 'Except closed'; ru = 'Кроме закрытых';pl = 'Z wyjątkiem zamkniętego';es_ES = 'Excepto cerrados';es_CO = 'Excepto cerrados';tr = 'Kapatılanlar hariç';it = 'Tranne i chiusi';de = 'Außer geschlossenem'"));
	Items.FilterActuality.ChoiceList.Add("Closed", NStr("en = 'Closed'; ru = 'Закрытые';pl = 'Zamknięty';es_ES = 'Cerrado';es_CO = 'Cerrado';tr = 'Kapatılanlar';it = 'Chiuso';de = 'Geschlossen'"));
	
	StatusesChiceList = Items.FilterStatus.ChoiceList;
	StatusesChiceList.Add(NStr("en = 'In process'; ru = 'В работе';pl = 'W toku';es_ES = 'En proceso';es_CO = 'En proceso';tr = 'İşlemde';it = 'In lavorazione';de = 'In Bearbeitung'"));
	StatusesChiceList.Add(NStr("en = 'Completed'; ru = 'Завершенные';pl = 'Zakończono';es_ES = 'Finalizado';es_CO = 'Finalizado';tr = 'Tamamlandı';it = 'Completato';de = 'Abgeschlossen'"));
	StatusesChiceList.Add(NStr("en = 'Canceled'; ru = 'Отменено';pl = 'Anulowano';es_ES = 'Cancelado';es_CO = 'Cancelado';tr = 'İptal edildi';it = 'Cancellati';de = 'Abgebrochen'"));
	
	CommonClientServer.SetDynamicListParameter(List, "StatusInProcess", StatusesChiceList[0].Value);
	CommonClientServer.SetDynamicListParameter(List, "StatusCompleted", StatusesChiceList[1].Value);
	CommonClientServer.SetDynamicListParameter(List, "StatusCanceled", StatusesChiceList[2].Value);
	
	CommonClientServer.SetDynamicListParameter(ListSalesOrders, "StatusInProcess", StatusesChiceList[0].Value);
	CommonClientServer.SetDynamicListParameter(ListSalesOrders, "StatusCompleted", StatusesChiceList[1].Value);
	CommonClientServer.SetDynamicListParameter(ListSalesOrders, "StatusCanceled", StatusesChiceList[2].Value);
	
	If GetFunctionalOption("UseSalesOrderStatuses") Then
		Items.ListSalesOrdersOrderStatus.Visible = False;
	Else
		Items.ListSalesOrdersOrderState.Visible = False;
	EndIf;
	
	PaintList();
	PaintListSalesOrders();
	
	List.Parameters.SetParameterValue("CurrentDateSession", CurrentSessionDate());
	
	UseStatuses = Constants.UseProductionOrderStatuses.Get();
	
	// Use the states of production orders.
	If UseStatuses Then
		Items.FilterStatus.Visible = False;
		Items.OrderStatus.Visible = False;
	Else
		Items.FilterState.Visible = False;
		Items.OrderState.Visible = False;
	EndIf;
	
	If Parameters.Property("OrderStateState") Then
		DriveClientServer.SetListFilterItem(List, "OrderStateState", Parameters.OrderStateState, ValueIsFilled(Parameters.OrderStateState));
	EndIf;
	
	If Parameters.Property("UseProductionPlanning") Then
		DriveClientServer.SetListFilterItem(List, "UseProductionPlanning", Parameters.UseProductionPlanning, ValueIsFilled(Parameters.UseProductionPlanning));
	EndIf;
	
	SetFilterToDoList();
	
	DriveServer.AddChangeStatusCommands(ThisObject, "GroupChangeStatus", "ProductionOrderStatuses");
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If Parameters.Property("ToDoList") Then
		
		Settings.Delete("FilterCompany");
		Settings.Delete("FilterState");
		Settings.Delete("FilterStatus");
		Settings.Delete("FilterDepartment");
		Settings.Delete("FilterActuality");
		Settings.Delete("FilterResponsible");
		
	Else
		
		FilterCompany = Settings.Get("FilterCompany");
		FilterState = Settings.Get("FilterState");
		FilterStatus = Settings.Get("FilterStatus");
		FilterResponsible = Settings.Get("FilterResponsible");
		FilterDepartment = Settings.Get("FilterDepartment");
		FilterActuality = Settings.Get("FilterActuality");
		If Not ValueIsFilled(FilterActuality) Then
			FilterActuality = "All";
		EndIf;
		
		If Constants.UseProductionOrderStatuses.Get() Then
			FilterStatus = "";
			DriveClientServer.SetListFilterItem(List, "OrderState", FilterState, ValueIsFilled(FilterState));
		Else
			FilterActuality = "All";
			FilterState = Catalogs.ProductionOrderStatuses.EmptyRef();
			DriveClientServer.SetListFilterItem(List, "OrderStatus", FilterStatus, ValueIsFilled(FilterStatus));
		EndIf;
		
		DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
		DriveClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
		DriveClientServer.SetListFilterItem(List, "StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
		
		If FilterActuality = "Except closed" Then
			DriveClientServer.SetListFilterItem(List, "Closed", False);
		ElsIf FilterActuality = "Closed" Then
			DriveClientServer.SetListFilterItem(List, "Closed", True);
		EndIf;
		
		DriveClientServer.SetListFilterItem(ListSalesOrders, "Company", FilterCompany, ValueIsFilled(FilterCompany));
		DriveClientServer.SetListFilterItem(ListSalesOrders, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
		
	EndIf;
	
EndProcedure

// Procedure - Form event handler "NotificationProcessing".
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_ProductionOrderStates" Then
		PaintList();
	EndIf;
	
	If EventName = "Record_SalesOrderStates" Then
		PaintListSalesOrders();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
// Procedure - event handler OnChange input field FilterCompany.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterCompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(ListSalesOrders, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterState.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterStateOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "OrderState", FilterState, ValueIsFilled(FilterState));
EndProcedure

// Procedure - event handler OnChange input field FilterStatus.
//
&AtClient
Procedure FilterStatusOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "OrderStatus", FilterStatus, ValueIsFilled(FilterStatus));
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterResponsible.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterResponsibleOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	DriveClientServer.SetListFilterItem(ListSalesOrders, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterDepartment.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterDepartmentOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterActuality.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterActualityOnChange(Item)
	
	If FilterActuality = "Except closed" Then
		DriveClientServer.SetListFilterItem(List, "Closed", False, True);
	ElsIf FilterActuality = "Closed" Then
	    DriveClientServer.SetListFilterItem(List, "Closed", True, True);
	Else
	    DriveClientServer.SetListFilterItem(List, "Closed", True, False);
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormTableItemsEventHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	If Item.CurrentData = Undefined
		OR Not Item.CurrentData.Closed Then
		Items.FormCreateBasedOn.Enabled = True;
	Else
		Items.FormCreateBasedOn.Enabled = False;
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CloseOrders(Command)
	
	OrdersArray = DriveClient.CheckGetSelectedRefsInList(Items.List);
	If OrdersArray.Count() = 0 Then
		Return;
	EndIf;
	
	CloseOrdersAtServer(OrdersArray);
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined
		OR Not CurrentData.Closed Then
		Items.FormCreateBasedOn.Enabled = True;
	Else
		Items.FormCreateBasedOn.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure CloseSalesOrders(Command)
	
	OrdersArray = DriveClient.CheckGetSelectedRefsInList(Items.ListSalesOrders);
	If OrdersArray.Count() = 0 Then
		Return;
	EndIf;
	
	ClosingStructure = New Structure;
	ClosingStructure.Insert("SalesOrders", OrdersArray);
	
	OpenForm("DataProcessor.OrdersClosing.Form.Form", ClosingStructure, ThisObject);
	
EndProcedure

&AtClient
Procedure CreateProductionOrder(Command)
	
	TabularSectionRow = Items.ListSalesOrders.CurrentData;
	
	If TabularSectionRow <> Undefined Then
		OpenForm("Document.ProductionOrder.ObjectForm", New Structure("Basis", TabularSectionRow.Ref));
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ExecuteChangeStatusCommand(Command)
	DriveClient.ExecuteChangeStatusCommand(Command, Items.List, "ProductionOrderStatuses");
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure CloseOrdersAtServer(OrdersArray)
	
	ClosingStructure = New Structure;
	ClosingStructure.Insert("ProductionOrders", OrdersArray);
	
	OrdersClosingObject = DataProcessors.OrdersClosing.Create();
	OrdersClosingObject.FillOrders(ClosingStructure);
	OrdersClosingObject.CloseOrders();
	Items.List.Refresh();
	
EndProcedure

// Procedure colors list.
//
&AtServer
Procedure PaintList()
	
	// List coloring
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem In List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item In ListOfItemsForDeletion Do
		List.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	PaintByState = Constants.UseProductionOrderStatuses.Get();
	
	If Not PaintByState Then
		InProcessStatus = Constants.ProductionOrdersInProgressStatus.Get();
		BackColorInProcess = InProcessStatus.Color.Get();
		CompletedStatus = Constants.ProductionOrdersCompletionStatus.Get();
		BackColorCompleted = CompletedStatus.Color.Get();
		StatusesChiceList = Items.FilterStatus.ChoiceList;
	EndIf;
	
	SelectionOrderStatuses = Catalogs.ProductionOrderStatuses.Select();
	While SelectionOrderStatuses.Next() Do
		
		If PaintByState Then
			BackColor = SelectionOrderStatuses.Color.Get();
			If TypeOf(BackColor) <> Type("Color") Then
				Continue;
			EndIf;
		Else
			If SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.InProcess Then
				If TypeOf(BackColorInProcess) <> Type("Color") Then
					Continue;
				EndIf;
				BackColor = BackColorInProcess;
			ElsIf SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.Completed Then
				If TypeOf(BackColorCompleted) <> Type("Color") Then
					Continue;
				EndIf;
				BackColor = BackColorCompleted;
			Else
				Continue;
			EndIf;
		EndIf;
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		If PaintByState Then
			FilterItem.LeftValue = New DataCompositionField("OrderState");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			FilterItem.RightValue = SelectionOrderStatuses.Ref;
		Else
			FilterItem.LeftValue = New DataCompositionField("OrderStatus");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			If SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.InProcess Then
				FilterItem.RightValue = StatusesChiceList[0].Value;
			Else
				FilterItem.RightValue = StatusesChiceList[1].Value;
			EndIf;
		EndIf;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColor);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		
	EndDo;
	
	If Not PaintByState Then
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("OrderStatus");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = StatusesChiceList[2].Value;
		
		If TypeOf(BackColorCompleted) = Type("Color") Then
			ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColorCompleted);
		EndIf;
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure PaintListSalesOrders()
	
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem In ListSalesOrders.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	
	For Each Item In ListOfItemsForDeletion Do
		ListSalesOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	PaintByState = GetFunctionalOption("UseSalesOrderStatuses");
	
	If Not PaintByState Then
		InProcessStatus = DriveReUse.GetStatusInProcessOfSalesOrders();
		BackColorInProcess = InProcessStatus.Color.Get();
		CompletedStatus = DriveReUse.GetStatusCompletedSalesOrders();
		BackColorCompleted = CompletedStatus.Color.Get();
		StatusesChiceList = Items.FilterStatus.ChoiceList;
	EndIf;
	
	SelectionOrderStatuses = Catalogs.SalesOrderStatuses.Select();
	While SelectionOrderStatuses.Next() Do
		
		If PaintByState Then
			BackColor = SelectionOrderStatuses.Color.Get();
			If TypeOf(BackColor) <> Type("Color") Then
				Continue;
			EndIf;
		Else
			If SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.InProcess Then
				If TypeOf(BackColorInProcess) <> Type("Color") Then
					Continue;
				EndIf;
				BackColor = BackColorInProcess;
			ElsIf SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.Completed Then
				If TypeOf(BackColorCompleted) <> Type("Color") Then
					Continue;
				EndIf;
				BackColor = BackColorCompleted;
			Else
				Continue;
			EndIf;
		EndIf;
		
		ConditionalAppearanceItem = ListSalesOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		If PaintByState Then
			FilterItem.LeftValue = New DataCompositionField("OrderState");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			FilterItem.RightValue = SelectionOrderStatuses.Ref;
		Else
			FilterItem.LeftValue = New DataCompositionField("OrderStatus");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			If SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.InProcess Then
				FilterItem.RightValue = StatusesChiceList[0].Value;
			Else
				FilterItem.RightValue = StatusesChiceList[1].Value;
			EndIf;
		EndIf;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColor);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		
	EndDo;
	
	If Not PaintByState Then
		
		ConditionalAppearanceItem = ListSalesOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("OrderStatus");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = StatusesChiceList[2].Value;
		
		TextFontRows = StyleFonts.DeletedAdditionalAttributeFont;
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", TextFontRows);
		If TypeOf(BackColorCompleted) = Type("Color") Then
			ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColorCompleted);
		EndIf;
		
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		
	EndIf;
	
EndProcedure

// Procedure sets filter in the list table for section To-do list.
//
&AtServer
Procedure SetFilterToDoList()
	
	If Not Parameters.Property("ToDoList") Then
		Return;
	EndIf;
	
	FormHeaderText = "";
	If Parameters.Property("PastPerformance") Then
		FormHeaderText = NStr("en = 'Production orders: execution is overdue'; ru = 'Заказы на производство: просрочено выполнение';pl = 'Zlecenia produkcyjne: wykonanie opóźnione';es_ES = 'Órdenes de producción: ejecución vencida';es_CO = 'Órdenes de producción: ejecución vencida';tr = 'Üretim emirleri: uygulama gecikmiş';it = 'Ordini di produzione: adempimento in ritardo';de = 'Fertigungsaufträge: Ausführung ist überfällig'");
		DriveClientServer.SetListFilterItem(List, "PastPerformance", True);
	EndIf;
	
	If Parameters.Property("ForToday") Then
		FormHeaderText = NStr("en = 'Production orders: for today'; ru = 'Заказы на производство: на сегодня';pl = 'Zlecenia produkcyjne: na dzisiaj';es_ES = 'Órdenes de producción: para hoy';es_CO = 'Órdenes de producción: para hoy';tr = 'Üretim emirleri: bugün için';it = 'Ordini di produzione: odierni';de = 'Produktionsaufträge: für heute'");
		DriveClientServer.SetListFilterItem(List, "ForToday", True);
	EndIf;
	
	If Parameters.Property("InProcess") Then
		FormHeaderText = NStr("en = 'Production orders: in progress'; ru = 'Заказы на производство: в работе';pl = 'Zlecenia produkcyjne: w toku';es_ES = 'Órdenes de producción: en progreso';es_CO = 'Órdenes de producción: en progreso';tr = 'Üretim emirleri: işlemde';it = 'Ordini di produzione: in corso';de = 'Produktionsaufträge: in Bearbeitung'");
		DriveClientServer.SetListFilterItem(List, "OrderInProcess", True);
	EndIf;
	
	If Parameters.Property("Responsible") Then
		DriveClientServer.SetListFilterItem(List, "Responsible", Parameters.Responsible.List, True, DataCompositionComparisonType.InList);
		FormHeaderText = FormHeaderText + ", " + NStr("en = 'responsible'; ru = 'ответственный';pl = 'odpowiedzialny';es_ES = 'responsable';es_CO = 'responsable';tr = 'sorumlu';it = 'responsabile';de = 'verantwortlich'") + " " + Parameters.Responsible.Initials;
	EndIf;
	
	If Not IsBlankString(FormHeaderText) Then
		AutoTitle = False;
		Title = FormHeaderText;
	EndIf;
	
	Items.FilterResponsible.Visible = False;
	Items.FilterState.Visible = False;
	Items.FilterStatus.Visible = False;
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Items.List);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Items.List, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion


