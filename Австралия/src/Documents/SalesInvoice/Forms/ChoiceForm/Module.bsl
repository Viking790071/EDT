#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	DriveServer.OverrideStandartGenerateGoodsIssueCommand(ThisObject);
	DriveServer.OverrideStandartGenerateGoodsReceiptCommand(ThisObject, GetFunctionalOption("UseGoodsReturnFromCustomer"));
EndProcedure

#EndRegion

#Region ListFormTableItemsEventHandlers

&AtServerNoContext
Procedure ListOnGetDataAtServer(ItemName, Settings, Rows)
	
	Documents.SalesInvoice.ListOnGetDataAtServer(ItemName, Settings, Rows);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Attachable_GenerateGoodsIssue(Command)
	DriveClient.GoodsIssueGenerationBasedOnSalesInvoice(Items.List);
EndProcedure

&AtClient
Procedure Attachable_GenerateGoodsReceipt(Command)
	DriveClient.GoodsReceiptGenerationBasedOnSalesInvoice(Items.List);
EndProcedure

#EndRegion