
&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Drivereuse.CounterpartyContractsControlNeeded() Then
		
		Items.ListCompanies.Visible = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ValueChoiceList(Item, Value, StandardProcessing)
	
	Close(Value);
	
EndProcedure