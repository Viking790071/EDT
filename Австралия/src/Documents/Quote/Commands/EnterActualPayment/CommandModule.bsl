
&AtServer
Function GetCashAssetType(DocumentRef)
	
	Return DocumentRef.CashAssetType;
	
EndFunction

&AtClient
// Procedure of command data processor.
//
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	CashAssetType = GetCashAssetType(CommandParameter);
	Parameters = New Structure("BasisDocument", CommandParameter);
	
	If CashAssetType = PredefinedValue("Enum.CashAssetTypes.Cash") Then
		
		OpenForm("Document.CashReceipt.ObjectForm", Parameters);
		
	Else
		
		OpenForm("Document.PaymentReceipt.ObjectForm", Parameters);
		
	EndIf;
	
EndProcedure
