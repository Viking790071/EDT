
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.OverrideStandartGenerateSalesInvoiceCommand(ThisForm);
	DriveServer.OverrideStandartGenerateDebitNoteCommand(ThisObject);
	
	OrderFilter = Undefined;
	Parameters.Property("OrderFilter", OrderFilter);
	List.Parameters.SetParameterValue("OrderFilter", OrderFilter);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure Attachable_GenerateSalesInvoice(Command)
	DriveClient.SalesInvoiceGenerationBasedOnGoodsIssue(Items.List);
EndProcedure

&AtClient
Procedure Attachable_GenerateDebitNote(Command)
	DriveClient.DebitNoteGenerationBasedOnGoodsIssue(Items.List);
EndProcedure

#EndRegion
