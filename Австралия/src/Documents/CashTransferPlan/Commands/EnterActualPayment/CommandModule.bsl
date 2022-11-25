#Region EventHandlers

&AtClient
// Procedure of command data processor.
//
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Parameters = New Structure("BasisDocument", CommandParameter);
	
	CashAssetType = GetCashAssetType(CommandParameter);
	CashAssetTypePayee = GetCashAssetTypePayee(CommandParameter);
	
	If CashAssetType = PredefinedValue("Enum.CashAssetTypes.Cash") Then
		OpenForm("Document.CashVoucher.ObjectForm", Parameters);
	Else
		OpenForm("Document.PaymentExpense.ObjectForm", Parameters);
	EndIf;
	
	If CashAssetTypePayee = PredefinedValue("Enum.CashAssetTypes.Noncash") Then
		OpenForm("Document.CashReceipt.ObjectForm", Parameters);
	Else
		OpenForm("Document.PaymentReceipt.ObjectForm", Parameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function GetCashAssetType(DocumentRef)
	
	Return DocumentRef.CashAssetType;
	
EndFunction

&AtServer
Function GetCashAssetTypePayee(DocumentRef)
	
	Return DocumentRef.CashAssetTypePayee;
	
EndFunction

#EndRegion
