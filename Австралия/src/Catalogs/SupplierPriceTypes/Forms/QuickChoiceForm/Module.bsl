
&AtClient
// Procedure - OnChange event handler of the Counterparty field
//
Procedure CounterpartyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(
		List, 
		"Counterparty", Counterparty,
		ValueIsFilled(Counterparty));
	
EndProcedure
