
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.OverrideStandartGenerateSupplierInvoiceCommand(ThisForm);
	DriveServer.OverrideStandartGenerateCreditNoteCommand(ThisForm);
	
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
	
	SetContinentalMethodAttributesVisibility();
	
EndProcedure

#EndRegion

#Region FormItemEventHandlers

&AtClient
Procedure FilterWarehouseStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	Filter = New Structure("StructuralUnitType", PredefinedValue("Enum.BusinessUnitsTypes.Warehouse"));
	ParametersStructure = New Structure("ChoiceMode, Filter", True, Filter);
	OpenForm("Catalog.BusinessUnits.ChoiceForm", ParametersStructure, Item);
	
EndProcedure

&AtClient
Procedure FilterStatusOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "Status", FilterStatus, ValueIsFilled(FilterStatus));
EndProcedure

&AtClient
Procedure FilterCounterpartyOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
EndProcedure

&AtClient
Procedure FilterWarehouseOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "StructuralUnit", FilterWarehouse, ValueIsFilled(FilterWarehouse));
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

&AtClient
Procedure Attachable_GenerateSupplierInvoice(Command)
	DriveClient.SupplierInvoiceGenerationBasedOnGoodsReceipt(Items.List);
EndProcedure

&AtClient
Procedure Attachable_GenerateCreditNote(Command)
	DriveClient.CreditNoteGenerationBasedOnGoodsReceipt(Items.List);
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

&AtServer
Procedure SetContinentalMethodAttributesVisibility()
	ContinentalMethod = InformationRegisters.AccountingPolicy.ContinentalStockTransactionsMethodologyIsEnabled();
	Items.DocumentAmount.Visible = ContinentalMethod;
	Items.DocumentCurrency.Visible = ContinentalMethod;
EndProcedure

#EndRegion
