#Region FormEventHandlers

&AtClient
Procedure SetAsDefault(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Or CurrentData.IsDefault Then
		Return;
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Counterparty", CurrentData.Owner);
	ParametersStructure.Insert("NewDefaultShippingAddresses", CurrentData.Ref);
	
	SetAddressAsDefault(ParametersStructure);
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure SetAddressAsDefault(ParametersStructure)
	
	ShippingAddressesServer.SetShippingAddressAsDefault(ParametersStructure);
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.BatchObjectModification
	Items.ChangeSelected.Visible = AccessRight("Edit", Metadata.Catalogs.ShippingAddresses);
	// End StandardSubsystems.BatchObjectModification
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

#Region LibrariesHandlers

// StandardSubsystems.SearchAndDeleteDuplicates

&AtClient
Procedure MergeSelected(Command)
	FindAndDeleteDuplicatesDuplicatesClient.MergeSelectedItems(Items.List);
EndProcedure

&AtClient
Procedure ShowUsage(Command)
	FindAndDeleteDuplicatesDuplicatesClient.ShowUsageInstances(Items.List);
EndProcedure

// End StandardSubsystems.SearchAndDeleteDuplicates

// StandardSubsystems.BatchObjectModification

&AtClient
Procedure ChangeSelected(Command)
	BatchEditObjectsClient.ChangeSelectedItems(Items.List);
EndProcedure

// End StandardSubsystems.BatchObjectModification

#EndRegion

#EndRegion
