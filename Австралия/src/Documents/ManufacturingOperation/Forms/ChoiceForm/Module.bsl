
#Region Variables

&AtClient
Var CompletedStatus;

&AtClient
Var OpenStatus;

#EndRegion

#Region FormEventHandlers

&AtClient
Procedure OnOpen(Cancel)
	
	CompletedStatus = PredefinedValue("Enum.ManufacturingOperationStatuses.Completed");
	OpenStatus = PredefinedValue("Enum.ManufacturingOperationStatuses.Open");
	
EndProcedure

#EndRegion

#Region ListFormTableItemsEventHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	DriveClient.DocumentWIPGenerationVisibility(Items, Item, 
		New Structure("CompletedStatus, OpenStatus", CompletedStatus, OpenStatus));
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "DocumentWIPGenerationVisibility" Then
		DriveClient.DocumentWIPGenerationVisibility(Items, Items.List, 
			New Structure("CompletedStatus, OpenStatus", CompletedStatus, OpenStatus));
	EndIf;
		
EndProcedure

#EndRegion