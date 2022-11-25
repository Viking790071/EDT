
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetVisibleAndEnabled();
	
EndProcedure

#EndRegion

#Region Private

Procedure SetVisibleAndEnabled()
	
	IsCounterpartysInventory = (Object.OwnershipType = Enums.InventoryOwnershipTypes.CounterpartysInventory);
	UseContractsWithCounterparties = Constants.UseContractsWithCounterparties.Get();
	
	If Items.Find("Counterparty") <> Undefined Then
		Items.Counterparty.Visible = IsCounterpartysInventory;
	EndIf;
	If Items.Find("Contract") <> Undefined Then
		Items.Contract.Visible = IsCounterpartysInventory And UseContractsWithCounterparties;
	EndIf;
	
EndProcedure

#EndRegion