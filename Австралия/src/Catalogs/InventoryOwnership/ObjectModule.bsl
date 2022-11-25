#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If OwnershipType <> Enums.InventoryOwnershipTypes.CounterpartysInventory Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If IsBlankString(Description) Then
		
		If OwnershipType = Enums.InventoryOwnershipTypes.OwnInventory Then
			
			Description = String(OwnershipType);
			
		ElsIf Constants.UseContractsWithCounterparties.Get() Then
			
			Description = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 (%2)'; ru = '%1 (%2)';pl = '%1 (%2)';es_ES = '%1 (%2)';es_CO = '%1 (%2)';tr = '%1 (%2)';it = '%1 (%2)';de = '%1 (%2)'"),
				Counterparty,
				Contract);
				
		Else
			
			Description = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1'; ru = '%1';pl = '%1';es_ES = '%1';es_CO = '%1';tr = '%1';it = '%1';de = '%1'"),
				Counterparty);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf