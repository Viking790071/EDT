#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetContractVisible();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CounterpartyOnChange(Item)
	
	SetContractVisible();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetContractVisible()
	
	UseContracts = Constants.UseContractsWithCounterparties.Get();
	DoOperationsByContracts = (ValueIsFilled(Record.Counterparty)
		And Not Common.ObjectAttributeValue(Record.Counterparty, "IsFolder")
		And Common.ObjectAttributeValue(Record.Counterparty, "DoOperationsByContracts"));
	
	Items.Contract.Visible = UseContracts And DoOperationsByContracts;
	
EndProcedure

#EndRegion
