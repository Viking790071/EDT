#Region FormEventHandlers

// Procedure - Form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Constants.KitProcessingUpdateWasCompleted.Get() = False Then
		
		CommonClientServer.MessageToUser(
			NStr("en = '1C:Drive update is not completed. It required to install the Kit processing updates. If you have Administrator rights, open the All functions menu and run the Kit processing update installer. Otherwise, contact the 1C:Drive administrator with the request to install the updates.'; ru = 'Обновление 1C:Drive не завершено. Требуется установить обновления обработки комплектации. Если у вас есть права администратора, откройте меню Все функции и запустите Программу установки обновления обработки комплектации. В противном случае обратитесь к администратору 1C:Drive с просьбой установить обновления.';pl = 'Aktualizacja 1C:Drive nie jest zakończona. Wymagane jest zainstalowanie aktualizacji przetwarzania zestawu. Jeśli masz uprawnienia Administratora, otwórz menu ""Wszystkie funkcje"" i uruchom instalator aktualizacji przetwarzania zestawu. W przeciwnym razie, skontaktuj się z administratorem 1C:Drive z zapytaniem o instalację aktualizacji.';es_ES = 'La actualización de 1C:Drive no se ha finalizado. Es necesario instalar las actualizaciones de procesamiento del kit. Si tiene derechos de Administrador, abra el menú Todas las funciones y ejecute el instalador de la actualización del procesamiento del kit. De lo contrario, póngase en contacto con el administrador de 1C:Drive para solicitar la instalación de las actualizaciones.';es_CO = 'La actualización de 1C:Drive no se ha finalizado. Es necesario instalar las actualizaciones de procesamiento del kit. Si tiene derechos de Administrador, abra el menú Todas las funciones y ejecute el instalador de la actualización del procesamiento del kit. De lo contrario, póngase en contacto con el administrador de 1C:Drive para solicitar la instalación de las actualizaciones.';tr = '1C:Drive güncellemesi tamamlanmadı. Set işleme güncellemelerinin yüklenmesi gerekiyor. Yönetici yetkilerine sahipseniz Tüm işlevler menüsünü açıp Set işleme güncellemesi yükleyiciyi çalıştırın. Yetkiniz yoksa 1C:Drive yöneticisinden güncellemeleri yüklemesini talep edin.';it = 'L''aggiornamento di 1C:Drive non è completato. Viene richiesta l''installazione degli aggiornamenti dell''elaborazione del Kit. In caso di possesso dei diritti di Amministratore, aprire il menu Tutte le funzioni ed eseguire il programma di installazione degli aggiornamenti dell''elaboratore del Kit. Altrimenti, contattare l''amministratore di 1C:Drive per richiedere l''installamento degli aggiornamenti.';de = '1C:Drive-Update ist nicht abgeschlossen. Updates for Kit-Bearbeitung müssen installiert werden. Sollen Sie Administratorrechte haben, öffnen Sie das Menü ""Alle Funktionen"" und starten den Installateur für Kit-Bearbeitungs-Update. Ansonsten kontaktieren Sie den 1C:Drive-Administrator mit einer Anfrage um Installations von den Updates.'"),
			,,,
			Cancel);
		
	EndIf;
	
	If Not Constants.UseSeveralDepartments.Get()
		AND Not Constants.UseSeveralWarehouses.Get() Then
		
		Items.FilterDepartment.ListChoiceMode = True;
		Items.FilterDepartment.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.FilterDepartment.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
	EndIf;
	
	Items.FilterActuality.ChoiceList.Add("All", NStr("en = 'All'; ru = 'Все';pl = 'Wszystkie';es_ES = 'Todo';es_CO = 'Todo';tr = 'Tümü';it = 'Tutti';de = 'Alle'"));
	Items.FilterActuality.ChoiceList.Add("Except closed", NStr("en = 'Except closed'; ru = 'Кроме закрытых';pl = 'Z wyjątkiem zamkniętych';es_ES = 'Excepto cerrados';es_CO = 'Excepto cerrados';tr = 'Kapatılanlar hariç';it = 'Tranne chiusi';de = 'Außer geschlossenem'"));
	Items.FilterActuality.ChoiceList.Add("Closed", NStr("en = 'Closed'; ru = 'Закрытые';pl = 'Zamknięte';es_ES = 'Cerrado';es_CO = 'Cerrado';tr = 'Kapatıldı';it = 'Chiuso';de = 'Geschlossen'"));
	
	StatusesChoceList = Items.FilterStatus.ChoiceList;
	StatusesChoceList.Add(NStr("en = 'In process'; ru = 'В работе';pl = 'W toku';es_ES = 'En proceso';es_CO = 'En proceso';tr = 'İşlemde';it = 'In corso';de = 'In Bearbeitung'"));
	StatusesChoceList.Add(NStr("en = 'Completed'; ru = 'Завершен';pl = 'Zakończono';es_ES = 'Finalizado';es_CO = 'Finalizado';tr = 'Tamamlandı';it = 'Completato';de = 'Abgeschlossen'"));
	StatusesChoceList.Add(NStr("en = 'Canceled'; ru = 'Отменен';pl = 'Anulowano';es_ES = 'Cancelado';es_CO = 'Cancelado';tr = 'İptal edildi';it = 'Annullato';de = 'Abgebrochen'"));
	
	CommonClientServer.SetDynamicListParameter(List, "StatusInProcess", StatusesChoceList[0].Value);
	CommonClientServer.SetDynamicListParameter(List, "StatusCompleted", StatusesChoceList[1].Value);
	CommonClientServer.SetDynamicListParameter(List, "StatusCanceled", StatusesChoceList[2].Value);
	
	CommonClientServer.SetDynamicListParameter(ListSalesOrders, "StatusInProcess", StatusesChoceList[0].Value);
	CommonClientServer.SetDynamicListParameter(ListSalesOrders, "StatusCompleted", StatusesChoceList[1].Value);
	CommonClientServer.SetDynamicListParameter(ListSalesOrders, "StatusCanceled", StatusesChoceList[2].Value);
	
	If GetFunctionalOption("UseSalesOrderStatuses") Then
		Items.ListSalesOrdersOrderStatus.Visible = False;
	Else
		Items.ListSalesOrdersOrderState.Visible = False;
	EndIf;
	
	PaintList();
	PaintListSalesOrders();
	
	List.Parameters.SetParameterValue("CurrentDateSession", CurrentSessionDate());
	
	UseStatuses = Constants.UseKitOrderStatuses.Get();
	
	// Use the states of kit orders.
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
	
	SetFilterToDoList();
	
	DriveServer.AddChangeStatusCommands(ThisObject, "GroupChangeStatus", "KitOrderStatuses");
	
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
		
		If Constants.UseKitOrderStatuses.Get() Then
			FilterStatus = "";
			DriveClientServer.SetListFilterItem(List, "OrderState", FilterState, ValueIsFilled(FilterState));
		Else
			FilterActuality = "All";
			FilterState = Catalogs.KitOrderStatuses.EmptyRef();
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
	
	If EventName = "Record_KitOrderStates" Then
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

#Region FormTableItemsEventHandlersList

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
Procedure CreateKitOrder(Command)
	
	TabularSectionRow = Items.ListSalesOrders.CurrentData;
	
	If TabularSectionRow <> Undefined Then
		OpenForm("Document.KitOrder.ObjectForm", New Structure("Basis", TabularSectionRow.Ref));
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ExecuteChangeStatusCommand(Command)
	DriveClient.ExecuteChangeStatusCommand(Command, Items.List, "KitOrderStatuses");
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure CloseOrdersAtServer(OrdersArray)
	
	ClosingStructure = New Structure;
	ClosingStructure.Insert("KitOrders", OrdersArray);
	
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
	
	PaintByState = Constants.UseKitOrderStatuses.Get();
	
	If Not PaintByState Then
		InProcessStatus = Constants.KitOrdersInProgressStatus.Get();
		BackColorInProcess = InProcessStatus.Color.Get();
		CompletedStatus = Constants.KitOrdersCompletionStatus.Get();
		BackColorCompleted = CompletedStatus.Color.Get();
		StatusesChoceList = Items.FilterStatus.ChoiceList;
	EndIf;
	
	SelectionOrderStatuses = Catalogs.KitOrderStatuses.Select();
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
				FilterItem.RightValue = StatusesChoceList[0].Value;
			Else
				FilterItem.RightValue = StatusesChoceList[1].Value;
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
		FilterItem.RightValue = StatusesChoceList[2].Value;
		
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
		StatusesChoceList = Items.FilterStatus.ChoiceList;
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
				FilterItem.RightValue = StatusesChoceList[0].Value;
			Else
				FilterItem.RightValue = StatusesChoceList[1].Value;
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
		FilterItem.RightValue = StatusesChoceList[2].Value;
		
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
		FormHeaderText = NStr("en = 'Kit orders: execution is overdue'; ru = 'Заказы на комплектацию: просрочено выполнение';pl = 'Zamówienia zestawów: wykonanie zaległe';es_ES = 'Pedidos del Kit: ejecución vencida';es_CO = 'Pedidos del Kit: ejecución vencida';tr = 'Set siparişleri: yerine getirme gecikti';it = 'Ordini kit: esecuzione è scaduta';de = 'Kit-Aufträge: Ausführung ist überfällig'");
		DriveClientServer.SetListFilterItem(List, "PastPerformance", True);
	EndIf;
	
	If Parameters.Property("ForToday") Then
		FormHeaderText = NStr("en = 'Kit orders: for today'; ru = 'Заказы на комплектацию: на сегодня';pl = 'Zamówienia zestawów: na dzisiaj';es_ES = 'Pedidos del Kit: para hoy';es_CO = 'Pedidos del Kit: para hoy';tr = 'Set siparişleri: bugün için';it = 'Ordini kit: odierni';de = 'Kit-Aufträge: für heute'");
		DriveClientServer.SetListFilterItem(List, "ForToday", True);
	EndIf;
	
	If Parameters.Property("InProcess") Then
		FormHeaderText = NStr("en = 'Kit orders: in progress'; ru = 'Заказы на комплектацию: в работе';pl = 'Zamówienia zestawów: w toku';es_ES = 'Pedidos del Kit: en progreso';es_CO = 'Pedidos del Kit: en progreso';tr = 'Set siparişleri: işlemde';it = 'Ordini kit: in corso';de = 'Kit-Aufträge: in Bearbeitung'");
		DriveClientServer.SetListFilterItem(List, "OrderInProcess", True);
	EndIf;
	
	If Parameters.Property("Responsible") Then
		DriveClientServer.SetListFilterItem(List, "Responsible", Parameters.Responsible.List, True, DataCompositionComparisonType.InList);
		FormHeaderText = FormHeaderText + ", " + NStr("en = 'responsible'; ru = 'ответственный';pl = 'osoba odpowiedzialna';es_ES = 'responsable';es_CO = 'responsable';tr = 'sorumlu';it = 'responsabile';de = 'verantwortlich'") + " " + Parameters.Responsible.Initials;
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


