
#Region FormEventHandlers

// Procedure - Form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	StatusesStructure = Documents.TransferOrder.GetTransferOrderStringStatuses();
	
	For Each Item In StatusesStructure Do
		CommonClientServer.SetDynamicListParameter(List, Item.Key, Item.Value);
	EndDo;
	
	PaintList();
	
	UseStatuses = Constants.UseTransferOrderStatuses.Get();
	
	// Use the states of transfer orders.
	Items.OrderStatus.Visible = Not UseStatuses;
	Items.OrderState.Visible = UseStatuses;
	
	If Parameters.Property("OrderStateState") Then
		DriveClientServer.SetListFilterItem(List,
			"OrderStateState",
			Parameters.OrderStateState,
			ValueIsFilled(Parameters.OrderStateState));
	EndIf;
	
	DriveServer.AddChangeStatusCommands(ThisObject, "GroupChangeStatus", "TransferOrderStatuses");

	// Setting the method of Business unit selection depending on FO.
	If Not Constants.UseSeveralDepartments.Get()
		AND Not Constants.UseSeveralWarehouses.Get() Then
		
		Items.FilterRecipient.ListChoiceMode = True;
		Items.FilterRecipient.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		Items.FilterRecipient.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		
		Items.FilterWarehouse.ListChoiceMode = True;
		Items.FilterWarehouse.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.FilterWarehouse.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
	EndIf;
	
	CompletedStatus = Constants.StateCompletedTransferOrders.Get();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	DriveServer.OverrideStandartGenerateInventoryTransferCommand(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_TransferOrderStates" Then
		PaintList();
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
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterWarehouse.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterWarehouseOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "StructuralUnit", FilterWarehouse, ValueIsFilled(FilterWarehouse));
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterRecipient.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterRecipientOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "StructuralUnitPayee", FilterRecipient, ValueIsFilled(FilterRecipient));
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	If Item.CurrentData <> Undefined
		And Item.CurrentData.OrderState = CompletedStatus Then
		Items.FormCreateBasedOn.Enabled = False;
	Else
		Items.FormCreateBasedOn.Enabled = True;
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterCompany	= Settings.Get("FilterCompany");
	FilterWarehouse	= Settings.Get("FilterWarehouse");
	FilterRecipient	= Settings.Get("FilterRecipient");
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(List, "StructuralUnit", FilterWarehouse, ValueIsFilled(FilterWarehouse));
	DriveClientServer.SetListFilterItem(List, "StructuralUnitPayee", FilterRecipient, ValueIsFilled(FilterRecipient));
	
EndProcedure

&AtClient
Procedure Attachable_GenerateInventoryTransfer(Command)
	
	DriveClient.InventoryTransferGenerationBasedOnTransferOrder(Items.List);
	
EndProcedure

&AtClient
Procedure Attachable_ExecuteChangeStatusCommand(Command)
	
	DriveClient.ExecuteChangeStatusCommand(Command, Items.List, "TransferOrderStatuses");
	
	If Items.List.CurrentData <> Undefined
		And Items.List.CurrentData.OrderState = CompletedStatus Then
		Items.FormCreateBasedOn.Enabled = False;
	Else
		Items.FormCreateBasedOn.Enabled = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

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
	
	PaintByState = UseStatuses;
	
	If Not PaintByState Then
		InProcessStatus = Constants.TransferOrdersInProgressStatus.Get();
		BackColorInProcess = InProcessStatus.Color.Get();
		CompletedStatus = Constants.StateCompletedTransferOrders.Get();
		BackColorCompleted = CompletedStatus.Color.Get();
		StatusesStructure = Documents.TransferOrder.GetTransferOrderStringStatuses();
	EndIf;
	
	SelectionOrderStatuses = Catalogs.TransferOrderStatuses.Select();
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
