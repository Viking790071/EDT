#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	StatusesChoiceList = Items.FilterStatus.ChoiceList;
	StatusesStructure = Documents.SubcontractorOrderIssued.GetSubcontractorOrderStringStatuses();
	
	For Each Item In StatusesStructure Do
		StatusesChoiceList.Add(Item.Value);
		CommonClientServer.SetDynamicListParameter(List, Item.Key, Item.Value);
	EndDo;
	
	PaintList();
	
	List.Parameters.SetParameterValue("CurrentDateSession", CurrentSessionDate());
	
	UseStatuses = Constants.UseSubcontractorOrderIssuedStatuses.Get();
	
	// Use the states of subcontractor orders.
	If UseStatuses Then
		Items.FilterStatus.Visible = False;
		Items.OrderStatus.Visible = False;
	Else
		Items.FilterState.Visible = False;
		Items.OrderState.Visible = False;
	EndIf;
	
	If Parameters.Property("OrderStateState") Then
		DriveClientServer.SetListFilterItem(List,
			"OrderStateState",
			Parameters.OrderStateState,
			ValueIsFilled(Parameters.OrderStateState));
	EndIf;
	
	DriveServer.AddChangeStatusCommands(ThisObject, "GroupChangeStatus", "SubcontractorOrderIssuedStatuses");
	
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

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterCompany = Settings.Get("FilterCompany");
	FilterState = Settings.Get("FilterState");
	FilterStatus = Settings.Get("FilterStatus");
	FilterResponsible = Settings.Get("FilterResponsible");
	FilterCounterparty = Settings.Get("FilterCounterparty");
	FilterActuality = Settings.Get("FilterActuality");
	If Not ValueIsFilled(FilterActuality) Then
		FilterActuality = "All";
	EndIf;
	
	If Constants.UseSubcontractorOrderIssuedStatuses.Get() Then
		FilterStatus = "";
		DriveClientServer.SetListFilterItem(List, "OrderState", FilterState, ValueIsFilled(FilterState));
	Else
		FilterActuality = "All";
		FilterState = Catalogs.SubcontractorOrderIssuedStatuses.EmptyRef();
		DriveClientServer.SetListFilterItem(List, "OrderStatus", FilterStatus, ValueIsFilled(FilterStatus));
	EndIf;
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	DriveClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
	If FilterActuality = "ExceptClosed" Then
		DriveClientServer.SetListFilterItem(List, "Closed", False);
	ElsIf FilterActuality = "Closed" Then
		DriveClientServer.SetListFilterItem(List, "Closed", True);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_SubcontractorOrderStates" Then
		PaintList();
	ElsIf EventName = "Write_SubcontractorInvoice" Then
		Items.List.Refresh();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterCompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

&AtClient
Procedure FilterStateOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "OrderState", FilterState, ValueIsFilled(FilterState));
	
EndProcedure

&AtClient
Procedure FilterStatusOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "OrderStatus", FilterStatus, ValueIsFilled(FilterStatus));
	
EndProcedure

&AtClient
Procedure FilterResponsibleOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

&AtClient
Procedure FilterCounterpartyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
EndProcedure

&AtClient
Procedure FilterActualityOnChange(Item)
	
	If FilterActuality = "ExceptClosed" Then
		DriveClientServer.SetListFilterItem(List, "Closed", False, True);
	ElsIf FilterActuality = "Closed" Then
		DriveClientServer.SetListFilterItem(List, "Closed", True, True);
	Else
		DriveClientServer.SetListFilterItem(List, "Closed", True, False);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	If Item.CurrentData = Undefined Or Not Item.CurrentData.Closed Then
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
Procedure Attachable_ExecuteChangeStatusCommand(Command)
	
	DriveClient.ExecuteChangeStatusCommand(Command, Items.List, "SubcontractorOrderIssuedStatuses");
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure CloseOrdersAtServer(OrdersArray)
	
	ClosingStructure = New Structure;
	ClosingStructure.Insert("SubcontractorOrdersIssued", OrdersArray);
	
	OrdersClosingObject = DataProcessors.OrdersClosing.Create();
	OrdersClosingObject.FillOrders(ClosingStructure);
	OrdersClosingObject.CloseOrders();
	
	Items.List.Refresh();
	
EndProcedure

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
	
	PaintByState = Constants.UseSubcontractorOrderIssuedStatuses.Get();
	
	If Not PaintByState Then
		InProcessStatus = Constants.SubcontractorOrderIssuedInProgressStatus.Get();
		BackColorInProcess = InProcessStatus.Color.Get();
		CompletedStatus = Constants.SubcontractorOrderIssuedCompletionStatus.Get();
		BackColorCompleted = CompletedStatus.Color.Get();
		StatusesStructure = Documents.SubcontractorOrderIssued.GetSubcontractorOrderStringStatuses();
	EndIf;
	
	SelectionOrderStatuses = Catalogs.SubcontractorOrderIssuedStatuses.Select();
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
				FilterItem.RightValue = StatusesStructure.StatusInProcess;
			Else
				FilterItem.RightValue = StatusesStructure.StatusCompleted;
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
		FilterItem.RightValue = StatusesStructure.StatusCanceled;
		
		If TypeOf(BackColorCompleted) = Type("Color") Then
			ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColorCompleted);
		EndIf;
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		
	EndIf;
	
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