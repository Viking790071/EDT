
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.OverrideStandartGenerateSupplierInvoiceCommand(ThisForm);
	DriveServer.OverrideStandartGenerateCreditNoteCommand(ThisForm);
	
	OrderFilter = Undefined;
	Parameters.Property("OrderFilter", OrderFilter);
	List.Parameters.SetParameterValue("OrderFilter", OrderFilter);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	SetContinentalMethodAttributesVisibility();
	
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

&AtServer
Procedure SetContinentalMethodAttributesVisibility()
	ContinentalMethod = InformationRegisters.AccountingPolicy.ContinentalStockTransactionsMethodologyIsEnabled();
	Items.DocumentAmount.Visible = ContinentalMethod;
	Items.DocumentCurrency.Visible = ContinentalMethod;
EndProcedure
#EndRegion
