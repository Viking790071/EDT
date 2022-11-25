
#Region EventHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	CloseOnOwnerClose = True;
	
	If ValueIsFilled(Parameters.InfobaseNode) Then
		CommonSyncSettingsAsString = DataExchangeServer.DataSynchronizationRuleDetails(Parameters.InfobaseNode);
		NodeDescription = String(Parameters.InfobaseNode);
	Else
		NodeDescription = "";
	EndIf;
	
	Title = StrReplace(Title, "%1", NodeDescription);
	
EndProcedure

#EndRegion
