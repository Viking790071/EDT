#Region FormEventHandlers

// Procedure form event handler OnCreateAtServer
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

// Predefined procedure OnOpen
//
&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	DriveClientServer.SetListFilterItem(List, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	DriveClientServer.SetListFilterItem(List, "Responsible", Responsible, ValueIsFilled(Responsible));
	DriveClientServer.SetListFilterItem(List, "Status", Status, ValueIsFilled(Status));
	
EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers

// Procedure - event handler "OnChange" field "CounterpartyFilter"
//
&AtClient
Procedure CounterpartyFilterOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	
EndProcedure

// Procedure - event handler "OnChange" field "ResponsibleFilter"
//
&AtClient
Procedure ResponsibleFilterOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Responsible", Responsible, ValueIsFilled(Responsible));
	
EndProcedure

// Procedure - event handler "OnChange" field "StatusFilter"
//
&AtClient
Procedure StatusFilterOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Status", Status, ValueIsFilled(Status));
	
EndProcedure

#EndRegion

#Region ListFormTableItemsEventHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

#EndRegion

#Region Private

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