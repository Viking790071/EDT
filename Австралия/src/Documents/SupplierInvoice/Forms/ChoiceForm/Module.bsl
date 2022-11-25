#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.OverrideStandartGenerateCustomsDeclarationCommand(ThisObject);
	DriveServer.OverrideStandartGenerateGoodsReceiptCommand(ThisForm);
	DriveServer.OverrideStandartGenerateGoodsIssueCommand(ThisObject);
	DriveServer.OverrideStandartGenerateGoodsIssueReturnCommand(ThisObject, GetFunctionalOption("UseGoodsReturnToSupplier"));
	DriveServer.OverrideStandartGenerateDebitNoteCommand(ThisObject);
	DriveServer.OverrideStandartGenerateSalesInvoiceCommand(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure Attachable_GenerateCustomsDeclaration(Command)
	DriveClient.CustomsDeclarationGenerationBasedOnSupplierInvoice(Items.List);
EndProcedure

&AtClient
Procedure Attachable_GenerateGoodsReceipt(Command)
	DriveClient.GoodsReceiptGenerationBasedOnSupplierInvoice(Items.List);
EndProcedure

&AtClient
Procedure Attachable_GenerateGoodsIssueReturn(Command)
	DriveClient.GoodsIssueReturnGenerationBasedOnSupplierInvoice(Items.List);
EndProcedure

&AtClient
Procedure Attachable_GenerateGoodsIssue(Command)
	DriveClient.GoodsIssueGenerationBasedOnSupplierInvoice(Items.List);
EndProcedure

&AtClient
Procedure Attachable_GenerateDebitNote(Command)
	DriveClient.DebitNoteGenerationBasedOnSupplierInvoice(Items.List);
EndProcedure

&AtClient
Procedure Attachable_GenerateSalesInvoice(Command)
	
	DriveClient.SalesInvoiceGenerationBasedOnSupplierInvoice(Items.List);
	
EndProcedure

#EndRegion