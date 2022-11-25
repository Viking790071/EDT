#Region EventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
		
	If Parameters.Property("CashIncomeOfRetailRevenue") Then
		
		ValueList = New ValueList;
		ValueList.Add(Enums.OperationTypesCashReceipt.RetailIncome);
		ValueList.Add(Enums.OperationTypesCashReceipt.RetailIncomeEarningAccounting);
		
		DriveClientServer.SetListFilterItem(List,"OperationKind",ValueList,True,DataCompositionComparisonType.InList);
		
		AutoTitle = False;
		Title = "Cash receipt of retail revenue";
	
	EndIf;
	
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

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterCompany 		= Settings.Get("FilterCompany");
	PettyCashFilter 				= Settings.Get("PettyCashFilter");
	FilterTypeOperations 		= Settings.Get("FilterTypeOperations"); 
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(List, "PettyCash", PettyCashFilter, ValueIsFilled(PettyCashFilter));
	DriveClientServer.SetListFilterItem(List, "OperationKind", FilterTypeOperations, ValueIsFilled(FilterTypeOperations));
	
EndProcedure

&AtClient
Procedure FilterCompanyOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
EndProcedure

&AtClient
Procedure FilterPettyCashOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "PettyCash", PettyCashFilter, ValueIsFilled(PettyCashFilter));
EndProcedure

&AtClient
Procedure FilterOperationKindOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "OperationKind", FilterTypeOperations, ValueIsFilled(FilterTypeOperations));
EndProcedure

#EndRegion

#Region Internal

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