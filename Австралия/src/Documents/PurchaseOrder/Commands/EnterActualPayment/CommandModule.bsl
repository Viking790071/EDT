#Region EventHandlers

&AtClient
// Procedure of command data processor.
//
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	CashAssetType = GetCashAssetType(CommandParameter);
	Parameters = New Structure("BasisDocument", CommandParameter);
	
	If CashAssetType = PredefinedValue("Enum.CashAssetTypes.Cash") Then
		
		OpenForm("Document.CashVoucher.ObjectForm", Parameters);
		
	Else
		
		OpenForm("Document.PaymentExpense.ObjectForm", Parameters);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function GetCashAssetType(DocumentRef)
	
	Return Common.ObjectAttributeValue(DocumentRef, "CashAssetType");
	
EndFunction

#EndRegion
