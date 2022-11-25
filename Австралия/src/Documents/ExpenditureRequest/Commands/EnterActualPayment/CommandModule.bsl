&AtServer
// Returns cash assets type
//
Function GetCashAssetType(DocumentRef)
	
	Return DocumentRef.CashAssetType;
	
EndFunction

&AtClient
// Procedure of command data processor.
//
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	CashAssetType = GetCashAssetType(CommandParameter);
	If Not ValueIsFilled(CashAssetType) Then
		MessageText = NStr("en = 'Please select a payment method.'; ru = 'Укажите способ оплаты.';pl = 'Proszę, zaznacz metodę płatności.';es_ES = 'Por favor seleccione el método del pago.';es_CO = 'Por favor seleccione el método del pago.';tr = 'Lütfen, ödeme yöntemi seçin.';it = 'Si prega di selezionare un metodo di pagamento.';de = 'Bitte wählen Sie eine Zahlungsmethode aus.'");
		CommonClientServer.MessageToUser(MessageText, CommandParameter, "PaymentMethod", "Object");
		Return;
	EndIf;
	
	Parameters = New Structure("BasisDocument", CommandParameter);
	If CashAssetType = PredefinedValue("Enum.CashAssetTypes.Cash") Then
		OpenForm("Document.CashVoucher.ObjectForm", Parameters);
	ElsIf CashAssetType = PredefinedValue("Enum.CashAssetTypes.Noncash") Then
		OpenForm("Document.PaymentExpense.ObjectForm", Parameters);
	EndIf;
	
EndProcedure