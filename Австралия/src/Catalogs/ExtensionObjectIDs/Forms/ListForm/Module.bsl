
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Catalogs.MetadataObjectIDs.ListFormOnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListValueChoice(Item, Value, StandardProcessing)
	
	StandardSubsystemsClient.MetadataObjectIDsListFormListValueChoice(ThisObject,
		Item, Value, StandardProcessing);
	
EndProcedure

#EndRegion
