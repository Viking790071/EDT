#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.BatchObjectModification
	If Items.Find("ListBatchObjectChanging") <> Undefined Then
		Items.ChangeSelected.Visible = AccessRight("Edit", Metadata.Catalogs.Products);
	EndIf;
	// End StandardSubsystems.BatchObjectModification
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// StandardSubsystems.BatchObjectModification

&AtClient
Procedure ChangeSelected(Command)
	BatchEditObjectsClient.ChangeSelectedItems(Items.List);
EndProcedure

// End StandardSubsystems.BatchObjectModification

#EndRegion
