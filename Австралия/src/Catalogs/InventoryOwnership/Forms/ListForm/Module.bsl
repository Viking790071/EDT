#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.List.ChoiceMode = Parameters.ChoiceMode;
	
	If Items.Find("Contract") <> Undefined Then
		Items.Contract.Visible = Constants.UseContractsWithCounterparties.Get();
	EndIf;
	
EndProcedure

#EndRegion