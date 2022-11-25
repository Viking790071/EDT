
#Region FormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	CashCR = Settings.Get("CashCR");
	SetDynamicListsFilter();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SetEnabledOfCreateNewDocumentButtons()
	
	CashCRFilled = ValueIsFilled(CashCR);
	
	Items.RetailSalesReports.ChangeRowSet = Not CashFiscalRegister And CashCRFilled;
	
EndProcedure

// Procedure sets filter of dynamic form lists.
//
&AtServer
Procedure SetDynamicListsFilter()
	
	DriveClientServer.SetListFilterItem(RetailSalesReports, "CashCR", CashCR, ValueIsFilled(CashCR), DataCompositionComparisonType.Equal);
	DriveClientServer.SetListFilterItem(RetailSalesReports, "CashCRSessionStatus", CashCRSessionStatus, ValueIsFilled(CashCRSessionStatus), DataCompositionComparisonType.Equal);
	
EndProcedure

// Procedure - event handler "OnChange" of field "CashCR".
//
&AtServer
Procedure PettyCashFilterOnChangeAtServer()
	
	SetDynamicListsFilter();
	CashFiscalRegister = Catalogs.CashRegisters.GetCashRegisterAttributes(CashCR).CashCRType = Enums.CashRegisterTypes.FiscalRegister;
	
EndProcedure

// Procedure - event handler "OnChange" of field "CashRegister" at server.
//
&AtClient
Procedure PettyCashFilterOnChange(Item)
	
	PettyCashFilterOnChangeAtServer();
	SetEnabledOfCreateNewDocumentButtons();
	
EndProcedure

// Procedure - event handler "OnChange" of field "CashRegister" at server.
//
&AtClient
Procedure CashCRSessionStatusFilterOnChange(Item)
	
	SetDynamicListsFilter();
	
EndProcedure

&AtClient
// Procedure - form event handler "NotificationProcessing".
//
Procedure NotificationProcessing(EventName, Parameter, Source)

	If EventName  = "RefreshFormsAfterZReportIsDone" Then
		Items.RetailSalesReports.Refresh();
	ElsIf EventName = "RefreshFormsAfterClosingCashCRSession" Then
		Items.RetailSalesReports.Refresh();
	EndIf;

EndProcedure

// Procedure - form event handler "OnOpen".
//
&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	SetEnabledOfCreateNewDocumentButtons();
	
EndProcedure

// Procedure - command handler "OpenFiscalRegisterManagement".
//
&AtClient
Procedure OpenFiscalRegisterManagement(Command)
	
	OpenForm("Catalog.Peripherals.Form.CashRegisterShiftClosure");

EndProcedure

// Procedure - command handler "OpenPOSTerminalManagement".
//
&AtClient
Procedure OpenPOSTerminalManagement(Command)
	
	OpenForm("Catalog.Peripherals.Form.PaymentTerminalFunctions");

EndProcedure

#EndRegion

#Region RetailSalesReportsFormTableItemsEventHandlers

&AtClient
Procedure RetailSalesReportsOnActivateRow(Item)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure Attachable_GenerateSupplierInvoice(Command)
	DriveClient.SupplierInvoiceGenerationBasedOnGoodsReceipt(Items.RetailSalesReports);
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Items.RetailSalesReports);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Items.RetailSalesReports, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Items.RetailSalesReports);
EndProcedure
// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion
