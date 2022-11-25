
#Region FormEventHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterEmployee			= Settings.Get("FilterEmployee");
	FilterCompany 		= Settings.Get("FilterCompany");
	FilterDepartment 		= Settings.Get("FilterDepartment");
	
	DriveClientServer.SetListFilterItem(List, "Employees.Employee", FilterEmployee, ValueIsFilled(FilterEmployee));
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(List, "Employees.StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

// Procedure - event handler OnChange input field FilterEmployee
//
&AtClient
Procedure FilterEmployeeOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Employees.Employee", FilterEmployee, ValueIsFilled(FilterEmployee));
	
EndProcedure

// Procedure - event handler OnChange input field FilterCompany
// In procedure situation is defined, when on change its
// date document is in another document numbering period, and in
// this case appropriates for document new unique number.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterCompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

// Procedure - event handler OnChange input field FilterDepartment
// In procedure the situation is defined, when on change its
// date document is in another document numbering period, and in
// this case appropriates for document new unique number.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterDepartmentOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Employees.StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
	
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
