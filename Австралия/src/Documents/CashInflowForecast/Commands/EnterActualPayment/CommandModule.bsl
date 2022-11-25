
&AtServer
Function GetCashAssetType(DocumentRef)
	
	Return DocumentRef.CashAssetType;
	
EndFunction

&AtClient
// Procedure of command data processor.
//
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)

	Parameters = New Structure("BasisDocument", CommandParameter);
	CashAssetType = GetCashAssetType(CommandParameter);
	
	If Not ValueIsFilled(CashAssetType) Then
		OpenForm("CommonForm.PaymentMethod",,,,,, New NotifyDescription("CommandDataProcessorEnd", ThisObject, New Structure("Parameters", Parameters)));
		Return;
	EndIf;
	
	CommandDataProcessorFragment(Parameters, CashAssetType);
EndProcedure

&AtClient
Procedure CommandDataProcessorEnd(Result, AdditionalParameters) Export
	
	Parameters = AdditionalParameters.Parameters;
	
	CommandDataProcessorFragment(Parameters, Result);
	
EndProcedure

&AtClient
Procedure CommandDataProcessorFragment(Val Parameters, Val CashAssetType)
	
	If CashAssetType = PredefinedValue("Enum.CashAssetTypes.Cash") Then
		OpenForm("Document.CashReceipt.ObjectForm", Parameters);
	ElsIf CashAssetType = PredefinedValue("Enum.CashAssetTypes.Noncash") Then 
		OpenForm("Document.PaymentReceipt.ObjectForm", Parameters);
	EndIf;
	
EndProcedure
 // CommandProcessing()
