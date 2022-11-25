#Region CommonProceduresAndFunctions

// Procedure recalculates deal amount and refills selection lists in the amount input fields.
//
&AtClient
Procedure RecalculateAmounts()
	
	PaymentByCards = TemporaryCardsTable.Total("Amount");
	AmountShortChange = CashReceived + PaymentByCards - DocumentAmount;
	// Deal amount shouldn't be more cash payment.
	// If it is true then it is necessary to return on card.
	If AmountShortChange > CashReceived Then
		// You need to warn user.
		Message = New UserMessage;
		Message.Text = "Deal amount exceeds payment in cash amount. It is required to reduce the payment amount or return on card "+(AmountShortChange - CashReceived)+" "+DocumentCurrency;
		Message.Message();
	EndIf;
	
	Delta = DocumentAmount - CashReceived - PaymentByCards;
	
	Items.CashReceived.ChoiceList.Clear();
	If Delta > 0 Then
		Items.CashReceived.ChoiceList.Add(Delta, 
			""+Delta+" "+DocumentCurrency+" (Balance)");
	EndIf;
	If Delta <> DocumentAmount Then
		Items.CashReceived.ChoiceList.Add(DocumentAmount, ""+DocumentAmount+" "+DocumentCurrency+" (document amount)");
	EndIf;
	
	For Each CurrentRow In TemporaryCardsTable Do
		IndexOf = TemporaryCardsTable.IndexOf(CurrentRow);
		Items["PaymentByCard_"+IndexOf].ChoiceList.Clear();
		If Delta > 0 Then
			Items["PaymentByCard_"+IndexOf].ChoiceList.Add(Delta, ""+Delta+" "+DocumentCurrency+" (Balance)");
		EndIf;
		If Delta <> DocumentAmount Then
			Items["PaymentByCard_"+IndexOf].ChoiceList.Add(DocumentAmount, ""+DocumentAmount+" "+DocumentCurrency+" (document amount)");
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure deletes strings with zero amount in PM PaymentByCards.
//
&AtClient
Procedure DeletePaymentStringsWithZeroSum()

	MRowsForDeletion = New Array;
	For Each CurrentRow In Object.PaymentWithPaymentCards Do
		If CurrentRow.Amount = 0 Then
			MRowsForDeletion.Add(CurrentRow);
		EndIf;
	EndDo;
	
	For Each CurrentStringToDelete In MRowsForDeletion Do
		Object.PaymentWithPaymentCards.Delete(CurrentStringToDelete);
	EndDo;
	
EndProcedure

// The procedure fills out a list of payment card kinds.
//
&AtServer
Procedure GetChoiceListOfPaymentCardKinds()
	
	ArrayTypesOfPaymentCards = Catalogs.POSTerminals.PaymentCardKinds(Object.POSTerminal);
	PaymentCardKinds.LoadValues(ArrayTypesOfPaymentCards);
	
	TotalAcc = TemporaryCardsTable.Count() - 1;
	For Ct = 0 To TotalAcc Do
		Items["ChargeCardKind_"+Ct].ChoiceList.LoadValues(PaymentCardKinds.UnloadValues());
	EndDo;
	
EndProcedure

#EndRegion

#Region ProceduresFormEventsHandlers

// Procedure - OnCreateAtServer form event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CurValue = FormDataToValue(Parameters.Object, Type("DocumentObject.SalesSlip"));
	ValueToFormAttribute(CurValue, "Object"); // Get document data.
	
	DocumentAmount = Parameters.DocumentAmount;
	DocumentCurrency = Parameters.DocumentCurrency;
	CashCR = Parameters.CashCR;
	UsePeripherals = Parameters.UsePeripherals;
	Object.POSTerminal = Parameters.POSTerminal;
	POSTerminalOnChangeAtServer();
	
	UsePeripherals = Drivereuse.UsePeripherals();
	If UsePeripherals Then
		GetRefsToEquipment();
	EndIf;
	
	ControlAtWarehouseDisabled = Not Constants.CheckStockBalanceOnPosting.Get()
						   OR Not Constants.CheckStockBalanceWhenIssuingSalesSlips.Get();
	
	CashCRUseWithoutEquipmentConnection = CashCR.UseWithoutEquipmentConnection;
	
	Items.GroupPatternCardPayments.Visible = False;
	
	// DataProcessor of cards.
	CardNumberInDocument = Parameters.PaymentWithPaymentCards.Count();
	If CardNumberInDocument = 0 AND Not ValueIsFilled(POSTerminal) Then
		Items.GroupCalculatorAndCardNumber.Enabled = True;
		AddCardOnServer();
		CardsAmountForTitle = 0;
	Else
		Items.GroupCalculatorAndCardNumber.Enabled = False;
		If CardNumberInDocument = 0 Then
			Items.CurrentInputFieldLabel.Visible = False;
		Else
			For Each PaymentRowByCard In Object.PaymentWithPaymentCards Do
				NewRow = TemporaryCardsTable.Add();
				FillPropertyValues(NewRow, PaymentRowByCard);
				AddCardOnServer(NewRow);
			EndDo;
		EndIf;
	EndIf;

	LeftToPay = DocumentAmount - TemporaryCardsTable.Total("Amount");
	Items.CashReceived.ChoiceList.Clear();
	Items.CashReceived.ChoiceList.Add(LeftToPay, ""+LeftToPay+" "+DocumentCurrency);
	
	SymbolsCountAfterComma = 2;
	FirstEntry = True;
	
	// Setting hot keys
For Ct = 0 To 9 Do
		Items["Button"+Ct].Shortcut = New Shortcut(Key["Num"+Ct], False, True, False);
	EndDo;
	Items.DelimiterFractionalParts.Shortcut = New Shortcut(Key.NumDecimal, False, True, False);
	Items.Reset.Shortcut = New Shortcut(Key.BackSpace, False, True, False);
	
	Items.GroupPaymentCards.Enabled = ValueIsFilled(Object.POSTerminal);
	
	// Block.
	If Not Object.Ref.IsEmpty() AND Parameters.Property("FormID") Then
		Try
			UnlockDataForEdit(Object.Ref, Parameters.FormID);
			LockDataForEdit(Object.Ref, , UUID); // Block will removed when closing form.
		Except
			//
		EndTry;
	EndIf;

EndProcedure

// Procedure - event handler BeforeClose form.
//
&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	If Not ButtonPressedCancel AND Not PressedButtonIssueReceipt Then
		Cancel(Commands.Cancel);
	EndIf;	
	
	Try
		UnlockFormDataForEdit();
	Except
		//
	EndTry;
	
EndProcedure

// Procedure - OnOpen form event handler.
//
&AtClient
Procedure OnOpen(Cancel)
	
	RecalculateAmounts();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - command handler AddCard form.
//
&AtClient
Procedure AddCard(Command)
	
	If ValueIsFilled(POSTerminal) Then
		AddPaymentByCard();
	Else
		AddCardOnServer();
	EndIf;
	
EndProcedure

// Procedure adds the information by card in case when POS terminal ISN'T CONNECTED.
//
&AtServer
Procedure AddCardOnServer(CurrentStringIdentifier = Undefined)
	
	CardsAmount = CardsAmount + 1;
	CardsAmountForTitle = CardsAmount;
	
	If CardsAmount % 2 = 0 Then
		GroupBackColor = StyleColors.UnselectedImageTextColor; //StyleColors.ManagingFieldBackgroundColor;
	Else
		GroupBackColor = StyleColors.SalesSlipGainsboro;
	EndIf;
	
	If CurrentStringIdentifier = Undefined Then
		NewRow = TemporaryCardsTable.Add();
		NewRow.FirstEntry = True;
	ElsIf TypeOf(CurrentStringIdentifier) = Type("Number") Then
		NewRow = TemporaryCardsTable.FindByID(CurrentStringIdentifier);
	Else
		NewRow = CurrentStringIdentifier;
	EndIf;
	
	IndexOf = TemporaryCardsTable.IndexOf(NewRow);
	
	NewFolder = Items.Add("GroupPaymentByCard_"+IndexOf, Type("FormGroup"), Items.GroupPaymentCards);
	NewFolder.Type = FormGroupType.UsualGroup;
	NewFolder.ShowTitle = False;
	NewFolder.Group = ChildFormItemsGroup.Vertical;
	NewFolder.BackColor = GroupBackColor;
	NewFolder.Width = 46;
	NewFolder.HorizontalStretch = False;
	NewFolder.ReadOnly = ValueIsFilled(POSTerminal);
	
	NewGroupCardAmount = Items.Add("GroupPaymentByCardAmount_"+IndexOf, Type("FormGroup"), NewFolder);
	NewGroupCardAmount.Type = FormGroupType.UsualGroup;
	NewGroupCardAmount.ShowTitle = False;
	NewGroupCardAmount.Group = ChildFormItemsGroup.Horizontal;
	NewGroupCardAmount.BackColor = GroupBackColor;
	
	NewGroupCardAttributesPart1 = Items.Add("GroupCardAttributesPart1"+IndexOf, Type("FormGroup"), NewFolder);
	NewGroupCardAttributesPart1.Type = FormGroupType.UsualGroup;
	NewGroupCardAttributesPart1.ShowTitle = False;
	NewGroupCardAttributesPart1.Group = ChildFormItemsGroup.Horizontal;
	NewGroupCardAttributesPart1.BackColor = GroupBackColor;
	
	NewGroupCardAttributesPart2 = Items.Add("GroupCardAttributesPart2"+IndexOf, Type("FormGroup"), NewFolder);
	NewGroupCardAttributesPart2.Type = FormGroupType.UsualGroup;
	NewGroupCardAttributesPart2.ShowTitle = False;
	NewGroupCardAttributesPart2.Group = ChildFormItemsGroup.Horizontal;
	NewGroupCardAttributesPart2.BackColor = GroupBackColor;
	
	// CardPaymentDeletionLabel
	DeletionLabelItem = Items.Add("PaymentByCardDeletionLabel_"+IndexOf, Type("FormDecoration"), NewGroupCardAmount);
	DeletionLabelItem.Type = FormDecorationType.Label;
	DeletionLabelItem.Title = "";
	DeletionLabelItem.Font = StyleFonts.LargeTextFont;
	DeletionLabelItem.TextColor = StyleColors.ErrorNoteText;
	DeletionLabelItem.Width = 35;
	DeletionLabelItem.HorizontalStretch = False;
	DeletionLabelItem.Visible = False;
	// End PaymentByCardDeletionLabel
	
	NewItem = Items.Add("PaymentByCard_"+IndexOf, Type("FormField"), NewGroupCardAmount);
	NewItem.Type = FormFieldType.InputField;
	NewItem.DataPath = "TemporaryCardsTable["+IndexOf+"].Amount";
	NewItem.TitleLocation = FormItemTitleLocation.None;
	NewItem.Font = StyleFonts.LargeTextFont;
	NewItem.Width = 35;
	NewItem.HorizontalStretch = False;
	NewItem.ChoiceButton = True;
	NewItem.DropListButton = True;
	NewItem.ToolTip = "Calculator changes data in the Amount low field or Amount last changed field
		|If you need to attach calculator to another field you should click the button with calculator picture in this field";
	NewItem.ToolTipRepresentation = ToolTipRepresentation.Button;
	
	CurrentFieldEnterAmounts = NewItem.Name;
	If TemporaryCardsTable.Count() < 2 Then
		Items.CurrentInputFieldLabel.Visible = False;
	Else
		Cur = Find(TrimAll(CurrentFieldEnterAmounts), "_");
		IndexOf = Number(Mid(TrimAll(CurrentFieldEnterAmounts), Cur+1));
		CurrentInputFieldLabel = "For card No"+(IndexOf+1);
		Items.CurrentInputFieldLabel.Visible = True;
	EndIf;
	
	NewItem.SetAction("OnChange", "Attachable_PaymentByCardOnChange");
	NewItem.SetAction("StartChoice", "Attachable_AmountPaymentByCardSelectionStart");
	
	PaymentByCards = TemporaryCardsTable.Total("Amount");
	NewItem.ChoiceList.Clear();
	Delta = DocumentAmount - CashReceived - PaymentByCards;
	If Delta > 0 Then
		NewItem.ChoiceList.Add(Delta, 
			""+Delta+" "+DocumentCurrency+" (Balance)");
	EndIf;
	If Delta <> DocumentAmount Then
		NewItem.ChoiceList.Add(DocumentAmount, ""+DocumentAmount+" "+DocumentCurrency+" (document amount)");
	EndIf;
	
	NewItem = Items.Add("DocumentCurrency_"+IndexOf, Type("FormField"), NewGroupCardAmount);
	NewItem.Type = FormFieldType.LabelField;
	NewItem.DataPath = "DocumentCurrency";
	NewItem.TitleLocation = FormItemTitleLocation.None;
	NewItem.Font = StyleFonts.LargeTextFont;
	NewItem.HorizontalStretch = False;
	
	// CardPaymentDeletionButton
	If ValueIsFilled(POSTerminal) Then
		ButtonName = "PaymentDeletionButton_"+IndexOf;
		
		NewCommand = Commands.Add(ButtonName);
		NewCommand.Action = "ChooseCashToDeletePayment";
		NewCommand.Title = "";
		NewCommand.Representation = ButtonRepresentation.Picture;
		NewCommand.Picture = PictureLib.MarkToDelete;
		NewCommand.ModifiesStoredData = False;
		NewCommand.ToolTip = "Cancel payment by cards in acquiring terminal";
		
		NewButton = Items.Add(ButtonName, Type("FormButton"), NewGroupCardAmount);
		NewButton.OnlyInAllActions = False;
		NewButton.Visible = True;
		NewButton.CommandName = NewCommand.Name;
		NewButton.Width = 4;
		NewButton.ToolTipRepresentation = ToolTipRepresentation.Balloon;
		
		NewRow.CommandName = ButtonName;
	EndIf;
	// End PaymentByCardDeletionButton
	
	NewItem = Items.Add("ChargeCardKind_"+IndexOf, Type("FormField"), NewGroupCardAttributesPart1);
	NewItem.Type = FormFieldType.InputField;
	NewItem.DataPath = "TemporaryCardsTable["+IndexOf+"].ChargeCardKind";
	NewItem.TitleLocation = FormItemTitleLocation.None;
	NewItem.Font = StyleFonts.LargeTextFont;
	NewItem.InputHint = "Card kind";
	NewItem.Width = 16;
	NewItem.HorizontalStretch = False;
	NewItem.ChoiceList.LoadValues(PaymentCardKinds.UnloadValues());
	NewItem.ListChoiceMode = True;
	NewItem.ChooseType = False;
	NewItem.SetAction("OnChange", "Attachable_CardAttributeOnChange");
	
	NewItem = Items.Add("ChargeCardNo_"+IndexOf, Type("FormField"), NewGroupCardAttributesPart1);
	NewItem.Type = FormFieldType.InputField;
	NewItem.DataPath = "TemporaryCardsTable["+IndexOf+"].ChargeCardNo";
	NewItem.TitleLocation = FormItemTitleLocation.None;
	NewItem.Font = StyleFonts.LargeTextFont;
	NewItem.InputHint = "card No";
	NewItem.Width = 27;
	NewItem.HorizontalStretch = False;
	NewItem.SetAction("OnChange", "Attachable_CardAttributeOnChange");
	
	NewItem = Items.Add("ETReceiptNo_"+IndexOf, Type("FormField"), NewGroupCardAttributesPart2);
	NewItem.Type = FormFieldType.InputField;
	NewItem.DataPath = "TemporaryCardsTable["+IndexOf+"].ETReceiptNo";
	NewItem.TitleLocation = FormItemTitleLocation.None;
	NewItem.Font = StyleFonts.LargeTextFont;
	NewItem.InputHint = "ET receipt number";
	NewItem.Width = 16;
	NewItem.HorizontalStretch = False;
	NewItem.SetAction("OnChange", "Attachable_CardAttributeOnChange");
	
	NewItem = Items.Add("RefNo_"+IndexOf, Type("FormField"), NewGroupCardAttributesPart2);
	NewItem.Type = FormFieldType.InputField;
	NewItem.DataPath = "TemporaryCardsTable["+IndexOf+"].RefNo";
	NewItem.TitleLocation = FormItemTitleLocation.None;
	NewItem.Font = StyleFonts.LargeTextFont;
	NewItem.InputHint = "Ref #";
	NewItem.Width = 27;
	NewItem.HorizontalStretch = False;
	NewItem.SetAction("OnChange", "Attachable_CardAttributeOnChange");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure adds the digit right from the entered number. Fractional part divider existence is considered.
//
&AtClient
Procedure AddDigit(EnteredDigitByString)
	
	If TemporaryCardsTable.Count() = 0 AND Items.GroupPayment.CurrentPage = Items.GroupCashlessPayment Then
		Message = New UserMessage;
		Message.Text = "Add card.";
		Message.Message();
		
		Return;
	EndIf;
	
	If Items.GroupPayment.CurrentPage = Items.GroupPaymentByCash Then
		EnteredNumber = CashReceivedRow;
		CurFirstEntry = FirstEntry;
	Else
		If Object.POSTerminal.IsEmpty() Then
			Message = New UserMessage;
			Message.Text = "Select the POS terminal";
			Message.Message();
			
			Return;
		EndIf;
		
		If TemporaryCardsTable.Count() = 1 Then
			IndexOf = 0;
		Else
			Cur = Find(TrimAll(CurrentFieldEnterAmounts), "_");
			IndexOf = Number(Mid(TrimAll(CurrentFieldEnterAmounts), Cur+1));
		EndIf;
		EnteredNumber = TemporaryCardsTable[IndexOf].AmountRow;
		CardTableCurrentString = TemporaryCardsTable[IndexOf];
		
		CurFirstEntry = CardTableCurrentString.FirstEntry;
	EndIf;
	
	If CurFirstEntry Then
		EnteredNumber = "";
		CurFirstEntry = False;
	EndIf;
	
	Comma = Mid(EnteredNumber, StrLen(EnteredNumber) - SymbolsCountAfterComma, 1);
	
	If Not Comma = "," Then
		EnteredNumber = EnteredNumber + EnteredDigitByString;
	EndIf;
	
	EnterNumber = LeadStringToNumber(EnteredNumber, True);
	
	If Items.GroupPayment.CurrentPage = Items.GroupPaymentByCash Then
		CashReceived = EnterNumber;
		CashReceivedRow = EnteredNumber;
		FirstEntry = CurFirstEntry;
	Else
		CardTableCurrentString.Amount = EnterNumber;
		CardTableCurrentString.AmountRow = EnteredNumber;
		CardTableCurrentString.FirstEntry = CurFirstEntry;
		
		AmountPaymentByCardOnChange(Items["PaymentByCard_"+IndexOf]);
	EndIf;
	
	RecalculateAmounts();
	
EndProcedure

// Function executes string reduction
// to number Parameters:
//  NumberByString           - String - String provided
//  to number ReturnUndefined - Boolean - If True and string contains incorrect value, then return Undefined
//
// Returns:
//  Number
//
&AtClient
Function LeadStringToNumber(NumberByString, ReturnUndefined = False)
	
	// Depending on regional infobase settings decimal separator may differ from ","
	// so we determine it from standart number presentation and replace if needed
	TestNumberString = String(0.1);
	DecimalSeparator = Mid(TestNumberString, 2, 1);
	If DecimalSeparator = "," Then
		AdjustedNumberByString = NumberByString;
	Else
		AdjustedNumberByString = StrReplace(NumberByString, ",", DecimalSeparator);
	EndIf;
	
	NumberTypeDescription = New TypeDescription("Number");
	NumberValue = NumberTypeDescription.AdjustValue(AdjustedNumberByString);
	
	If ReturnUndefined AND (NumberValue = 0) Then
		
		Str = String(NumberByString);
		If Str = "" Then
			Return Undefined;
		EndIf;
		
		Str = StrReplace(TrimAll(Str), "0", "");
		If (Str <> "") AND (Str <> ".") AND (Str <> ",") Then
			Return Undefined;
		EndIf;
	EndIf;
	
	Return NumberValue;
	
EndFunction

#EndRegion

#Region FormCommandsHandlers

#Region Calculator

// Procedure - command handler FractionalPartDevider form.
//
&AtClient
Procedure CommandPoint(Command)
	
	If Items.GroupPayment.CurrentPage = Items.GroupPaymentByCash Then
		EnteredNumber = CashReceivedRow;
		CurFirstEntry = FirstEntry;
	Else
		If TemporaryCardsTable.Count() = 1 Then
			IndexOf = 0;
		Else
			Cur = Find(TrimAll(CurrentFieldEnterAmounts), "_");
			IndexOf = Number(Mid(TrimAll(CurrentFieldEnterAmounts), Cur+1));
		EndIf;
		EnteredNumber = TemporaryCardsTable[IndexOf].AmountRow;
		CardTableCurrentString = TemporaryCardsTable[IndexOf];
		
		CurFirstEntry = CardTableCurrentString.FirstEntry;
	EndIf;
	
	If CurFirstEntry Then
		EnteredNumber = "";
		CurFirstEntry = False;
	EndIf;
	
	If EnteredNumber = "" Then
		EnteredNumber = "0";
	EndIf;
	
	If StrFind(EnteredNumber, ",") = 0 Then
		EnteredNumber = EnteredNumber + ",";
	EndIf;
	
	If Items.GroupPayment.CurrentPage = Items.GroupPaymentByCash Then
		CashReceivedRow = EnteredNumber;
		FirstEntry = CurFirstEntry;
	Else
		CardTableCurrentString.AmountRow = EnteredNumber;
		CardTableCurrentString.FirstEntry = CurFirstEntry;
	EndIf;

EndProcedure

// Procedure - command handler Reset forms.
//
&AtClient
Procedure CommandClear(Command)
	
	If Items.GroupPayment.CurrentPage = Items.GroupPaymentByCash Then
		CashReceived = 0;
		CashReceivedRow = "";
		FirstEntry = False;
	Else
		If TemporaryCardsTable.Count() = 1 Then
			IndexOf = 0;
		Else
			Cur = Find(TrimAll(CurrentFieldEnterAmounts), "_");
			IndexOf = Number(Mid(TrimAll(CurrentFieldEnterAmounts), Cur+1));
		EndIf;
		TemporaryCardsTable[IndexOf].AmountRow = "";
		TemporaryCardsTable[IndexOf].Amount = 0;
		TemporaryCardsTable[IndexOf].FirstEntry = False;
	EndIf;
	
	RecalculateAmounts();
	
EndProcedure

// Procedure - command handler Button7 form.
//
&AtClient
Procedure Button7(Command)
	
	AddDigit("7");
	
EndProcedure

// Procedure - command handler Button8 form.
//
&AtClient
Procedure Button8(Command)
	
	AddDigit("8");
	
EndProcedure

// Procedure - command handler Button9 form.
//
&AtClient
Procedure Button9(Command)
	
	AddDigit("9");
	
EndProcedure

// Procedure - command handler Button4 form.
//
&AtClient
Procedure Button4(Command)
	
	AddDigit("4");
	
EndProcedure

// Procedure - command handler Button5 form.
//
&AtClient
Procedure Button5(Command)
	
	AddDigit("5");
	
EndProcedure

// Procedure - command handler Button6 form.
//
&AtClient
Procedure Button6(Command)
	
	AddDigit("6");
	
EndProcedure

// Procedure - command handler Button1 form.
//
&AtClient
Procedure Button1(Command)
	
	AddDigit("1");
	
EndProcedure

// Procedure - command handler Button2 form.
//
&AtClient
Procedure Button2(Command)
	
	AddDigit("2");
	
EndProcedure

// Procedure - command handler Button3 form.
//
&AtClient
Procedure Button3(Command)
	
	AddDigit("3");
	
EndProcedure

// Procedure - command handler Button0 form.
//
&AtClient
Procedure Button0(Command)
	
	AddDigit("0");
	
EndProcedure

#EndRegion

// Procedure - command handler OK form.
//
&AtClient
Procedure OK(Command)
	
	Cancel = False;
	For Each CurrentRow In TemporaryCardsTable Do
		If CurrentRow.Amount > 0 Then
			If Not ValueIsFilled(CurrentRow.ChargeCardKind) Then
				Cancel = True;
				Message = New UserMessage;
				Message.Text = "Fill card kind";
				Message.Message();
			EndIf;
			If Not ValueIsFilled(CurrentRow.ChargeCardNo) Then
				Cancel = True;
				Message = New UserMessage;
				Message.Text = "Fill card number";
				Message.Message();
			EndIf;
		EndIf;
	EndDo;
	If Cancel Then
		Return;
	EndIf;
	
	CopyTableDataInReceiverFromSourceAtClient(Object.PaymentWithPaymentCards, TemporaryCardsTable);
	DeletePaymentStringsWithZeroSum();
	
	If Object.DocumentAmount > CashReceived + Object.PaymentWithPaymentCards.Total("Amount") Then
		
		ErrorText = NStr("en = 'The payment amount is less than the receipt amount'; ru = 'Сумма оплаты меньше суммы чека';pl = 'Kwota opłaty jest niższa niż suma paragonu';es_ES = 'El importe de pago es menor al importe de recibo';es_CO = 'El importe de pago es menor al importe de recibo';tr = 'Ödeme tutarı, giriş tutarından daha küçüktür';it = 'L''importo di pagamento è inferiore all''importo della ricevuta';de = 'Der Zahlungsbetrag ist kleiner als der Belegbetrag'");
		
		Message = New UserMessage;
		Message.Text = ErrorText;
		Message.Field = "AmountShortChange";
		Message.Message();
		
		Return;
		
	EndIf;
	If Object.DocumentAmount < Object.PaymentWithPaymentCards.Total("Amount") Then
		
		ErrorText = NStr("en = 'The amount of payment by payment cards exceeds the total of a receipt'; ru = 'Сумма оплаты платежными картами превышает сумму чека';pl = 'Kwota opłaty kartą przekracza łączną sumę paragonu';es_ES = 'El importe del pago con tarjetas de pago excede el total de un recibo';es_CO = 'El importe del pago con tarjetas de pago excede el total de un recibo';tr = 'Ödeme kartıyla ödeme tutarı, fiş toplamını aşıyor';it = 'L''importo del pagamento con carta è superiore al totale della ricevuta.';de = 'Der Betrag der Zahlung mit Zahlungskarten übersteigt den Gesamtbetrag einer Quittung'");
		
		Message = New UserMessage;
		Message.Text = ErrorText;
		Message.Field = "AmountShortChange";
		Message.Message();
		
		Return;
		
	EndIf;
	
	If Modified Then
		Modified = False;
	EndIf;
	
	CloseParameters = New Structure;
	CloseParameters.Insert("Object", Object);
	CloseParameters.Insert("Cash", CashReceived);
	CloseParameters.Insert("PaymentCards", Object.PaymentWithPaymentCards.Total("Amount"));
	CloseParameters.Insert("Deal", AmountShortChange);
	CloseParameters.Insert("GenerateSalesReceipt", GenerateSalesReceipt);
	CloseParameters.Insert("GenerateSimplifiedTaxInvoice", GenerateSimplifiedTaxInvoice);
	CloseParameters.Insert("GenerateWarrantyCardPerSerialNumber", GenerateWarrantyCardPerSerialNumber);
	CloseParameters.Insert("GenerateWarrantyCardConsolidated", GenerateWarrantyCardConsolidated);
	CloseParameters.Insert("PaymentByCards", Object.PaymentWithPaymentCards);
	CloseParameters.Insert("WriteDocument", WriteDocument);
	CloseParameters.Insert("Button", "IssueReceipt");
	
	PressedButtonIssueReceipt = True;
	Close(CloseParameters);
	
EndProcedure

// Procedure - command handler Cancel form.
//
&AtClient
Procedure Cancel(Command)
	
	If Modified Then
		Modified = False; // So there wasn't change acceptance question. Query appears as from has a default attribute of type "DocumentObject.SalesSlip".
	EndIf;
	
	DeletePaymentStringsWithZeroSum();
	
	ButtonPressedCancel = True;
	
	Try
		UnlockFormDataForEdit();
	Except
		//
	EndTry;
	
	Close(New Structure("Object, WriteDocument, Button", Object, WriteDocument, "Cancel"));
	
EndProcedure

#EndRegion

#Region ProceduresElementFormEventsHandlers

// Procedure - event handler OnChange item POSTerminal form.
//
&AtClient
Procedure POSTerminalOnChange(Item)
	
	POSTerminalOnChangeAtServer();
	Items.GroupPaymentCards.Enabled = ValueIsFilled(Object.POSTerminal);
	Items.GroupCalculatorAndCardNumber.Enabled = Not ValueIsFilled(POSTerminal);
	
EndProcedure

// Procedure - event handler OnChange item POSTerminal at server.
//
&AtServer
Procedure POSTerminalOnChangeAtServer()
	
	GetRefsToEquipment();
	GetChoiceListOfPaymentCardKinds();
	
EndProcedure

// Procedure - event handler OnChange item ReceivedCash form.
//
&AtClient
Procedure DocumentSalesSlipCashReceivedOnChange(Item)
	
	RecalculateAmounts();
	
EndProcedure

// Procedure - event handler OnChange item PaymentByCard_N form, where N - String index in TK TemporaryCardTable.
//
&AtClient
Procedure AmountPaymentByCardOnChange(Item)
	
	CurrentFieldEnterAmounts = Item.Name;
	If TemporaryCardsTable.Count() < 2 Then
		Items.CurrentInputFieldLabel.Visible = False;
	Else
		Cur = Find(TrimAll(CurrentFieldEnterAmounts), "_");
		IndexOf = Number(Mid(TrimAll(CurrentFieldEnterAmounts), Cur+1));
		CurrentInputFieldLabel = "For card No"+(IndexOf+1);
		Items.CurrentInputFieldLabel.Visible = True;
	EndIf;
	
	RecalculateAmounts();
	
	CardsAmountForTitle = CardsAmount;
	
EndProcedure

// Procedure - event handler SelectionStart item PaymentByCard_N form, where N - String index in TK TemporaryCardTable.
//
&AtClient
Procedure Attachable_AmountPaymentByCardSelectionStart(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentFieldEnterAmounts = Item.Name;
	If TemporaryCardsTable.Count() < 2 Then
		Items.CurrentInputFieldLabel.Visible = False;
	Else
		Cur = Find(TrimAll(CurrentFieldEnterAmounts), "_");
		IndexOf = Number(Mid(TrimAll(CurrentFieldEnterAmounts), Cur+1));
		CurrentInputFieldLabel = "For card No"+(IndexOf+1);
		Items.CurrentInputFieldLabel.Visible = True;
	EndIf;
	
	CurrentItem = Items.Button7_2;
	
EndProcedure

// Procedure - event handler OnChange items PaymentCardKind_N, CardNumber_N, PaymentCardNumber_N, ETReceiptNumber_N
// and ReferenceNumber_N, where N - String index in TK TemporaryCardTable.
//
&AtClient
Procedure Attachable_CardAttributeOnChange(Item)

	CardsAmountForTitle = CardsAmount;

EndProcedure

// Procedure - event handler OnCurrentPageChange item GroupPayment form.
//
&AtClient
Procedure GroupPaymentOnCurrentPageChange(Item, CurrentPage)
	
	// You need to clean the keyboard shortcuts to enter
	// card number using the numeric keypad on the payment page by payment cards!!!
	If CurrentPage = Items.GroupPaymentByCash Then
		For Ct = 0 To 9 Do
			Items["Button"+Ct].Shortcut = New Shortcut(Key["Num"+Ct], False, True, False);
		EndDo;
		Items.DelimiterFractionalParts.Shortcut= New Shortcut(Key.NumDecimal, False, True, False);
		Items.Reset.Shortcut= New Shortcut(Key.BackSpace, False, True, False);
	Else
		For Ct = 0 To 9 Do
			Items["Button"+Ct].Shortcut= New Shortcut(Key.None);
		EndDo;
		Items.DelimiterFractionalParts.Shortcut= New Shortcut(Key.None);
		Items.Reset.Shortcut= New Shortcut(Key.None);
		
		If TemporaryCardsTable.Count() > 0 Then
			CurrentItem = Items.PaymentByCard_0;
		EndIf;
	EndIf;
	
EndProcedure

// Attachable event handler "OnChange" of the PaymentByCard_index.
//
&AtClient
Procedure Attachable_PaymentByCardOnChange(Item)
	
	AmountPaymentByCardOnChange(Item);
	
EndProcedure

#EndRegion

#Region Peripherals

// Gets references to external equipment.
//
&AtServer
Procedure GetRefsToEquipment()

	FiscalRegister = ?(
		UsePeripherals // Check for the included FO "Use Peripherals"
	  AND ValueIsFilled(CashCR)
	  AND ValueIsFilled(CashCR.Peripherals),
	  CashCR.Peripherals.Ref,
	  Catalogs.Peripherals.EmptyRef()
	);

	POSTerminal = ?(
		UsePeripherals
	  AND ValueIsFilled(Object.POSTerminal)
	  AND ValueIsFilled(Object.POSTerminal.Peripherals)
	  AND Not Object.POSTerminal.UseWithoutEquipmentConnection,
	  Object.POSTerminal.Peripherals,
	  Catalogs.Peripherals.EmptyRef()
	);
	
EndProcedure

#EndRegion

#Region AutomatedPaymentByCards

// Procedure adds the information by card in case when POS terminal IS CONNECTED.
//
&AtClient
Procedure AddPaymentByCard()
	
	DeviceIdentifierET = Undefined;
	DeviceIdentifierFR = Undefined;
	ErrorDescription            = "";
	
	AmountOfOperations       = 0;
	CardNumber          = "";
	OperationRefNumber = "";
	ETReceiptNo         = "";
	SlipCheckString      = "";
	CardKind            = "";
	
	// When write values are cleared in the additional columns, so. remember the PM and then restore.
	CopyTableDataInReceiverFromSourceAtClient(Object.PaymentWithPaymentCards, TemporaryCardsTable);
	DeletePaymentStringsWithZeroSum();
	
	ShowMessageBox = False;
	If DriveClient.CheckPossibilityOfReceiptPrinting(ThisForm, ShowMessageBox) Then
		
		If UsePeripherals Then // Check on the included FO "Use ExternalEquipment"
			
			If EquipmentManagerClient.RefreshClientWorkplace()Then // Checks if the operator's workplace is specified
				
				// Device selection ET
				DeviceIdentifierET = ?(ValueIsFilled(POSTerminal),
											  POSTerminal,
											  Undefined);
				
				If DeviceIdentifierET <> Undefined Then
					
					// Device selection FR
					DeviceIdentifierFR = ?(ValueIsFilled(FiscalRegister),
												  FiscalRegister,
												  Undefined);
					
					If DeviceIdentifierFR <> Undefined
					 OR CashCRUseWithoutEquipmentConnection Then
						
						// ET device connection
						ResultET = EquipmentManagerClient.ConnectEquipmentByID(UUID,
																										DeviceIdentifierET,
																										ErrorDescription);
						
						If ResultET Then
							
							// FR device connection
							ResultFR = EquipmentManagerClient.ConnectEquipmentByID(UUID,
																											DeviceIdentifierFR,
																											ErrorDescription);
							
							If ResultFR OR CashCRUseWithoutEquipmentConnection Then
								
								// we will authorize operation previously
								FormParameters = New Structure();
								FormParameters.Insert("Amount", DocumentAmount - CashReceived - Object.PaymentWithPaymentCards.Total("Amount"));
								FormParameters.Insert("LimitAmount", DocumentAmount - Object.PaymentWithPaymentCards.Total("Amount"));
								FormParameters.Insert("ListOfCardTypes", New ValueList());
								IndexOf = 0;
								For Each CardKind In PaymentCardKinds Do
									FormParameters.ListOfCardTypes.Add(IndexOf, CardKind.Value);
									IndexOf = IndexOf + 1;
								EndDo;
								
								Result = Undefined;
								
								OpenForm("Catalog.Peripherals.Form.POSTerminalAuthorizationForm", FormParameters,,,,, New NotifyDescription("AddPaymentByCardEnd", ThisObject, New Structure("FRDeviceIdentifier, ETDeviceIdentifier, CardNumber", DeviceIdentifierFR, DeviceIdentifierET, CardNumber)), FormWindowOpeningMode.LockOwnerWindow);
							Else
								MessageText = NStr("en = 'The fiscal printer connection error:
                                                    |""%ErrorDescription%"".
                                                    |The operation by card has not been performed.'; 
                                                    |ru = 'Ошибка подключения фискального принтера:
                                                    |""%ErrorDescription%"".
                                                    |Операция по карте не может быть выполнена.';
                                                    |pl = 'Błąd podłączenia drukarki fiskalnej:
                                                    |""%ErrorDescription%"".
                                                    |Operacja kartą nie została wykonana.';
                                                    |es_ES = 'Error de conexión de la impresora fiscal:
                                                    |""%ErrorDescription%"".
                                                    |La operación con tarjeta no se ha realizado.';
                                                    |es_CO = 'Error de conexión de la impresora fiscal:
                                                    |""%ErrorDescription%"".
                                                    |La operación con tarjeta no se ha realizado.';
                                                    |tr = 'Mali yazıcı bağlantı hatası:
                                                    |""%ErrorDescription%"".
                                                    |Kartla işlem gerçekleştirilmedi.';
                                                    |it = 'Errore di connessione della stampante fiscale:
                                                    |%ErrorDescription%.
                                                    |L''operazione da scheda non è stata eseguita.';
                                                    |de = 'Der Verbindungsfehler des Steuerdruckers:
                                                    |""%ErrorDescription%"".
                                                    |Die Operation nach der Karte ist nicht ausgeführt.'");
								MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
								CommonClientServer.MessageToUser(MessageText);
							EndIf;
							
						Else
							
							MessageText = NStr("en = 'When POS terminal connection there
							                   |was error: ""%ErrorDescription%"".
							                   |Operation by card has not been performed.'; 
							                   |ru = 'При подключении эквайрингового
							                   |терминала произошла ошибка: ""%ErrorDescription%"".
							                   |Операция по карте не была выполнена.';
							                   |pl = 'W trakcie połączenia terminala POS wystąpił
							                   |błąd: ""%ErrorDescription%"".
							                   |Operacja z kartą nie została wykonana.';
							                   |es_ES = 'Conectando el terminal TPV, se ha
							                   |producido el error: ""%ErrorDescription%"".
							                   |Operación con tarjeta no se ha realizado.';
							                   |es_CO = 'Conectando el terminal TPV, se ha
							                   |producido el error: ""%ErrorDescription%"".
							                   |Operación con tarjeta no se ha realizado.';
							                   |tr = 'POS terminali bağlantısında hata oluştu:
							                   |""%ErrorDescription%"".
							                   |Kartla işlem yapılamadı.';
							                   |it = 'Alla connessione del terminale POS,
							                   |si è verificato un errore: ""%ErrorDescription%"".
							                   |L''operazione  con carta non è stata eseguita.';
							                   |de = 'Beim Anschluss des POS-Terminals
							                   |ist ein Fehler aufgetreten: ""%ErrorDescription%"".
							                   |Die Operation mit der Karte wurde nicht ausgeführt.'");
								MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
							CommonClientServer.MessageToUser(MessageText);
							
						EndIf;
						
					EndIf;
					
				EndIf;
				
			Else
				
				MessageText = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'");
				CommonClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		Else
			
			// External equipment is not used
			
		EndIf;
		
	ElsIf ShowMessageBox Then
		ShowMessageBox(Undefined,NStr("en = 'Failed to post document'; ru = 'Не удалось выполнить проведение документа';pl = 'Księgowanie dokumentu nie powiodło się';es_ES = 'Fallado a enviar el documento';es_CO = 'Fallado a enviar el documento';tr = 'Belge kaydedilemedi';it = 'Impossibile pubblicare il documento';de = 'Fehler beim Buchen des Dokuments'"));
	EndIf;
	
EndProcedure

// Procedure sends commands on ET, adds card items on form, writes document.
//
&AtClient
Procedure AddPaymentByCardEnd(Result1, AdditionalParameters) Export
	
	DeviceIdentifierFR = AdditionalParameters.DeviceIdentifierFR;
	DeviceIdentifierET = AdditionalParameters.DeviceIdentifierET;
	CardNumber = AdditionalParameters.CardNumber;
	
	// we will authorize operation previously
	Result = Result1;
	
	If TypeOf(Result) = Type("Structure") Then
		
		InputParameters  = New Array();
		Output_Parameters = Undefined;
		
		InputParameters.Add(Result.Amount);
		InputParameters.Add(Result.CardNumber);
		
		AmountOfOperations       = Result.Amount;
		CardNumber          = Result.CardNumber;
		OperationRefNumber = Result.RefNo;
		ETReceiptNo         = Result.ReceiptNumber;
		CardKind      = PaymentCardKinds[Result.CardType].Value;
		
		// Executing the operation on POS terminal
		ResultET = EquipmentManagerClient.RunCommand(DeviceIdentifierET,
		"AuthorizeSales",
		InputParameters,
		Output_Parameters);
		
		If ResultET Then
			
			CardNumber          = ?(NOT IsBlankString(CardNumber)
			AND IsBlankString(StrReplace(TrimAll(Output_Parameters[0]), "*", "")),
			CardNumber, Output_Parameters[0]);
			OperationRefNumber = Output_Parameters[1];
			ETReceiptNo         = Output_Parameters[2];
			SlipCheckString      = Output_Parameters[3][1];
			
			If Not IsBlankString(SlipCheckString) Then
				glPeripherals.Insert("LastSlipReceipt", SlipCheckString);
			EndIf;
			
			If Not IsBlankString(SlipCheckString) AND Not CashCRUseWithoutEquipmentConnection Then
				InputParameters  = New Array();
				InputParameters.Add(SlipCheckString);
				Output_Parameters = Undefined;
				
				ResultFR = EquipmentManagerClient.RunCommand(DeviceIdentifierFR,
				"PrintText",
				InputParameters,
				Output_Parameters);
			EndIf;
			
		Else
			
			MessageText = NStr("en = 'When operation execution there
			                   |was error: ""%ErrorDescription%"".
			                   |Payment by card has not been performed.'; 
			                   |ru = 'При выполнении операции возникла ошибка:
			                   |""%ErrorDescription%"".
			                   |Отмена по карте не была произведена';
			                   |pl = 'W czasie realizacji operacji wystąpił
			                   |błąd: ""%ErrorDescription%"".
			                   |Opłata kartą nie została wykonana.';
			                   |es_ES = 'Ejecutando la operación, se ha
			                   |producido el error: ""%ErrorDescription%"".
			                   |Pago con tarjeta no se ha realizado.';
			                   |es_CO = 'Ejecutando la operación, se ha
			                   |producido el error: ""%ErrorDescription%"".
			                   |Pago con tarjeta no se ha realizado.';
			                   |tr = 'İşlem esnasında bir 
			                   |hata oluştu: ""%ErrorDescription%"". 
			                   |Kartla iptal işlemi yapılmadı.';
			                   |it = 'Durante l''esecuzione dell''operazione
			                   |si è registrato un errore: ""%ErrorDescription%"".
			                   |Il pagamento con carta non è stato eseguito.';
			                   |de = 'Bei der Ausführung der Operation
			                   |ist ein Fehler aufgetreten: ""%ErrorDescription%"".
			                   |Die Zahlung per Karte wurde nicht ausgeführt.'");
			MessageText = StrReplace(MessageText,"%ErrorDescription%",Output_Parameters[1]);
			CommonClientServer.MessageToUser(MessageText);
			
		EndIf;
		
		If ResultET AND (NOT ResultFR AND Not CashCRUseWithoutEquipmentConnection) Then
			
			ErrorDescriptionFR = Output_Parameters[1];
			
			InputParameters  = New Array();
			Output_Parameters = Undefined;
			
			InputParameters.Add(AmountOfOperations);
			InputParameters.Add(OperationRefNumber);
			InputParameters.Add(ETReceiptNo);
			
			// Executing the operation on POS terminal
			EquipmentManagerClient.RunCommand(DeviceIdentifierET,
			"EmergencyVoid",
			InputParameters,
			Output_Parameters);
			
			MessageText = NStr("en = 'When printing slip receipt
			                   |there was error: ""%ErrorDescription%"".
			                   |Operation by card has been cancelled.'; 
			                   |ru = 'При печати слип-чека
			                   |возникла ошибка: ""%ErrorDescription%"".
			                   |Операция по карте была отменена.';
			                   |pl = 'W trakcie drukowania paragonu wystąpił
			                   |błąd: ""%ErrorDescription%"".
			                   |Operacja z kartą została anulowana.';
			                   |es_ES = 'Imprimiendo el recibo del comprobante
			                   |, se ha producido el error: ""%ErrorDescription%"".
			                   |Operación con tarjeta se ha cancelado.';
			                   |es_CO = 'Imprimiendo el recibo del comprobante
			                   |, se ha producido el error: ""%ErrorDescription%"".
			                   |Operación con tarjeta se ha cancelado.';
			                   |tr = 'Fiş yazdırılırken
			                   |hata oluştu: ""%ErrorDescription%"".
			                   |Kartla işlem iptal edildi.';
			                   |it = 'Durante la stampa dello scontrino
			                   |c''è stato un errore: ""%ErrorDescription%"".
			                   |L''operazione con la carta è stata cancellata.';
			                   |de = 'Beim Drucken des Belegs
			                   |ist ein Fehler aufgetreten: ""%ErrorDescription%"".
			                   |Die Bedienung per Karte wurde abgebrochen.'");
			MessageText = StrReplace(MessageText,"%ErrorDescription%",ErrorDescriptionFR);
			CommonClientServer.MessageToUser(MessageText);
			
		ElsIf ResultET Then
			
			// Add string to the temporary table.
			If TemporaryCardsTable.Count() = 1 AND 
				TemporaryCardsTable[0].Amount = 0 AND Not ValueIsFilled(TemporaryCardsTable[0].ChargeCardNo) AND
				Not ValueIsFilled(TemporaryCardsTable[0].ChargeCardKind) AND Not ValueIsFilled(TemporaryCardsTable[0].RefNo) AND Not ValueIsFilled(TemporaryCardsTable[0].ETReceiptNo) Then
				PaymentRowByCard = TemporaryCardsTable[0];
				AddItemsOnForm = False;
			Else
				PaymentRowByCard = TemporaryCardsTable.Add();
				AddItemsOnForm = True;
			EndIf;
			
			PaymentRowByCard.ChargeCardKind   = CardKind;
			PaymentRowByCard.ChargeCardNo = CardNumber; // ItIsPossible record empty Numbers maps or Numbers type "****************"
			PaymentRowByCard.Amount               = AmountOfOperations;
			PaymentRowByCard.RefNo      = OperationRefNumber;
			PaymentRowByCard.ETReceiptNo         = ETReceiptNo;
			
			If AddItemsOnForm Then
				AddCardOnServer(PaymentRowByCard.GetID());
			EndIf;
			
			RecalculateAmounts();
			
			// Add string to the PM document payments.
			PaymentRowByCard = Object.PaymentWithPaymentCards.Add();
			PaymentRowByCard.ChargeCardKind   = CardKind;
			PaymentRowByCard.ChargeCardNo = CardNumber; // ItIsPossible record empty Numbers maps or Numbers type "****************"
			PaymentRowByCard.Amount               = AmountOfOperations;
			PaymentRowByCard.RefNo      = OperationRefNumber;
			PaymentRowByCard.ETReceiptNo         = ETReceiptNo;
			
			// Record
			Write(); // It is required to write document to prevent information loss.
			WriteDocument = True;
			// End Record
			
		EndIf;
	EndIf;
	
	// FR device disconnect
	EquipmentManagerClient.DisableEquipmentById(UUID,
	DeviceIdentifierFR);
	// ET device disconnect
	EquipmentManagerClient.DisableEquipmentById(UUID,
	DeviceIdentifierET);

EndProcedure

// Procedure deletes information by card in case when POS terminal IS CONNECTED.
//
&AtClient
Procedure DeletePaymentByCardAfterCardSelection(CurrentData)

	DeviceIdentifierET = Undefined;
	DeviceIdentifierFR = Undefined;
	ErrorDescription            = "";
	
	// Check selected string in payment table by payment cards
	If CurrentData = Undefined Then
		CommonClientServer.MessageToUser(NStr("en = 'Select a row of deleted payment by card'; ru = 'Выберите строку удаляемой оплаты картой.';pl = 'Wybierz wiersz usuwanej płatności kartą';es_ES = 'Seleccionar una fila de los pagos borrados con tarjeta';es_CO = 'Seleccionar una fila de los pagos borrados con tarjeta';tr = 'Kartla silinen ödemelerin bir satırını seçin';it = 'Selezionare una riga di pagamento cancellato con carta';de = 'Wählen Sie eine Zeile mit gelöschter Zahlung per Karte aus'"));
		Return;
	EndIf;
	
	If CurrentData.Amount = 0 Then
		CommonClientServer.MessageToUser(NStr("en = 'Amount in the selected line = 0.'; ru = 'Сумма в выбранной строке = 0.';pl = 'Kwota w wybranym wierszu = 0';es_ES = 'Importe en la línea seleccionada = 0.';es_CO = 'Importe en la línea seleccionada = 0.';tr = 'Seçilen satırdaki tutar = 0.';it = 'Importo della linea selezionata = 0.';de = 'Betrag in der ausgewählten Zeile = 0.'"));
		Return;
	EndIf;
	
	CopyTableDataInReceiverFromSourceAtClient(Object.PaymentWithPaymentCards, TemporaryCardsTable);
	DeletePaymentStringsWithZeroSum();
	
	ShowMessageBox = False;
	If DriveClient.CheckPossibilityOfReceiptPrinting(ThisObject, ShowMessageBox) Then
		
		If UsePeripherals Then // Check on the included FO "Use ExternalEquipment"
			If EquipmentManagerClient.RefreshClientWorkplace()Then // Checks if the operator's workplace is specified
				AmountOfOperations       = CurrentData.Amount;
				CardNumber          = CurrentData.ChargeCardNo;
				OperationRefNumber = CurrentData.RefNo;
				ETReceiptNo         = CurrentData.ETReceiptNo;
				SlipCheckString      = "";
				
				// Device selection ET
				DeviceIdentifierET = ?(ValueIsFilled(POSTerminal),
											  POSTerminal,
											  Undefined);
				
				If DeviceIdentifierET <> Undefined Then
					// Device selection FR
					DeviceIdentifierFR = ?(ValueIsFilled(FiscalRegister),
												  FiscalRegister,
												  Undefined);
					
					If DeviceIdentifierFR <> Undefined OR CashCRUseWithoutEquipmentConnection Then
						// ET device connection
						ResultET = EquipmentManagerClient.ConnectEquipmentByID(UUID,
																										DeviceIdentifierET,
																										ErrorDescription);
						
						If ResultET Then
							// FR device connection
							ResultFR = EquipmentManagerClient.ConnectEquipmentByID(UUID,
																											DeviceIdentifierFR,
																											ErrorDescription);
							
							If ResultFR OR CashCRUseWithoutEquipmentConnection Then
								
								InputParameters  = New Array();
								Output_Parameters = Undefined;
								
								InputParameters.Add(AmountOfOperations);
								InputParameters.Add(OperationRefNumber);
								InputParameters.Add(ETReceiptNo);
								
								// Executing the operation on POS terminal
								ResultET = EquipmentManagerClient.RunCommand(DeviceIdentifierET,
																						  "AuthorizeVoid",
																						  InputParameters,
																						  Output_Parameters);
								
								If ResultET Then
									
									CardNumber          = "";
									OperationRefNumber = "";
									ETReceiptNo         = "";
									SlipCheckString      = Output_Parameters[0][1];
									
									If Not IsBlankString(SlipCheckString) Then
										glPeripherals.Insert("LastSlipReceipt", SlipCheckString);
									EndIf;
									
									If Not IsBlankString(SlipCheckString) AND Not CashCRUseWithoutEquipmentConnection Then
										InputParameters  = New Array();
										InputParameters.Add(SlipCheckString);
										Output_Parameters = Undefined;
										
										ResultFR = EquipmentManagerClient.RunCommand(DeviceIdentifierFR,
																								  "PrintText",
																								  InputParameters,
																								  Output_Parameters);
									EndIf;
									
								Else
									
									MessageText = NStr("en = 'When operation execution there
									                   |was error: ""%ErrorDescription%"".
									                   |Cancellation by card has not been performed.'; 
									                   |ru = 'При выполнении операции возникла ошибка:
									                   |""%ErrorDescription%"".
									                   |Отмена по карте не была произведена.';
									                   |pl = 'W trakcie realizacji operacji wystąpił
									                   |błąd: ""%ErrorDescription%"".
									                   |Anulowanie z karty nie zostało wykonane.';
									                   |es_ES = 'Ejecutando la operación,
									                   |se ha producido el error: ""%ErrorDescription%"".
									                   |Cancelación con tarjeta no se ha realizado.';
									                   |es_CO = 'Ejecutando la operación,
									                   |se ha producido el error: ""%ErrorDescription%"".
									                   |Cancelación con tarjeta no se ha realizado.';
									                   |tr = 'İşlem esnasında bir 
									                   |hata oluştu: ""%ErrorDescription%"". 
									                   |Kartla iptal işlemi yapılmadı.';
									                   |it = 'Durante l''esecuzione dell''operazione
									                   |si è registrato un errore: ""%ErrorDescription%"".
									                   |La cancellazione con carta non è stata eseguita.';
									                   |de = 'Bei der Ausführung der Operation gab es
									                   |einen Fehler: ""%ErrorDescription%"".
									                   |Die Stornierung durch die Karte wurde nicht durchgeführt.'");
									MessageText = StrReplace(MessageText,"%ErrorDescription%",Output_Parameters[1]);
									CommonClientServer.MessageToUser(MessageText);
									
								EndIf;
								
								If ResultET AND (NOT ResultFR AND Not CashCRUseWithoutEquipmentConnection) Then
									
									ErrorDescriptionFR = Output_Parameters[1];
									
									MessageText = NStr("en = 'When printing slip receipt
									                   |there was error: ""%ErrorDescription%"".
									                   |Operation by card has been cancelled.'; 
									                   |ru = 'При печати слип-чека
									                   |возникла ошибка: ""%ErrorDescription%"".
									                   |Операция по карте была отменена.';
									                   |pl = 'W trakcie drukowania paragonu wystąpił
									                   |błąd: ""%ErrorDescription%"".
									                   |Operacja z kartą została anulowana.';
									                   |es_ES = 'Imprimiendo el recibo del comprobante
									                   |, se ha producido el error: ""%ErrorDescription%"".
									                   |Operación con tarjeta se ha cancelado.';
									                   |es_CO = 'Imprimiendo el recibo del comprobante
									                   |, se ha producido el error: ""%ErrorDescription%"".
									                   |Operación con tarjeta se ha cancelado.';
									                   |tr = 'Fiş yazdırılırken
									                   |hata oluştu: ""%ErrorDescription%"".
									                   |Kartla işlem iptal edildi.';
									                   |it = 'Durante la stampa dello scontrino
									                   |c''è stato un errore: ""%ErrorDescription%"".
									                   |L''operazione con la carta è stata cancellata.';
									                   |de = 'Beim Drucken des Belegs
									                   |ist ein Fehler aufgetreten: ""%ErrorDescription%"".
									                   |Die Bedienung per Karte wurde abgebrochen.'");
									MessageText = StrReplace(MessageText,"%ErrorDescription%",ErrorDescriptionFR);
									CommonClientServer.MessageToUser(MessageText);
								
								ElsIf ResultET Then
									
									CurrentData.PaymentAmountDeleted = CurrentData.Amount;
									CurrentData.Amount = 0;
									CurrentData.PaymentDeleted = True;
									
									IndexOf = TemporaryCardsTable.IndexOf(CurrentData);
									ChangeItemsAfterPaymentDeletionAtServer(IndexOf, CurrentData.PaymentAmountDeleted);
									
									RecalculateAmounts();
									
									CopyTableDataInReceiverFromSourceAtClient(Object.PaymentWithPaymentCards, TemporaryCardsTable);
									DeletePaymentStringsWithZeroSum();
									
									// Record
									Write();
									WriteDocument = True;
									// End Record
									
								EndIf;
								
								// FR device disconnect
								EquipmentManagerClient.DisableEquipmentById(UUID,
																								 DeviceIdentifierFR);
								// ET device disconnect
								EquipmentManagerClient.DisableEquipmentById(UUID,
																								 DeviceIdentifierET);
							Else
								MessageText = NStr("en = 'The fiscal printer connection error:
                                                    |""%ErrorDescription%"".
                                                    |The operation by card has not been performed.'; 
                                                    |ru = 'Ошибка подключения фискального принтера:
                                                    |""%ErrorDescription%"".
                                                    |Операция по карте не может быть выполнена.';
                                                    |pl = 'Błąd podłączenia drukarki fiskalnej:
                                                    |""%ErrorDescription%"".
                                                    |Operacja kartą nie została wykonana.';
                                                    |es_ES = 'Error de conexión de la impresora fiscal:
                                                    |""%ErrorDescription%"".
                                                    |La operación con tarjeta no se ha realizado.';
                                                    |es_CO = 'Error de conexión de la impresora fiscal:
                                                    |""%ErrorDescription%"".
                                                    |La operación con tarjeta no se ha realizado.';
                                                    |tr = 'Mali yazıcı bağlantı hatası:
                                                    |""%ErrorDescription%"".
                                                    |Kartla işlem gerçekleştirilmedi.';
                                                    |it = 'Errore di connessione della stampante fiscale:
                                                    |%ErrorDescription%.
                                                    |L''operazione da scheda non è stata eseguita.';
                                                    |de = 'Der Verbindungsfehler des Steuerdruckers:
                                                    |""%ErrorDescription%"".
                                                    |Die Operation nach der Karte ist nicht ausgeführt.'");
								MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
								CommonClientServer.MessageToUser(MessageText);
							EndIf;
						Else
							MessageText = NStr("en = 'When POS terminal connection there
							                   |was error: ""%ErrorDescription%"".
							                   |Operation by card has not been performed.'; 
							                   |ru = 'При подключении эквайрингового
							                   |терминала произошла ошибка: ""%ErrorDescription%"".
							                   |Операция по карте не была выполнена.';
							                   |pl = 'W trakcie połączenia terminala POS wystąpił
							                   |błąd: ""%ErrorDescription%"".
							                   |Operacja z kartą nie została wykonana.';
							                   |es_ES = 'Conectando el terminal TPV, se ha
							                   |producido el error: ""%ErrorDescription%"".
							                   |Operación con tarjeta no se ha realizado.';
							                   |es_CO = 'Conectando el terminal TPV, se ha
							                   |producido el error: ""%ErrorDescription%"".
							                   |Operación con tarjeta no se ha realizado.';
							                   |tr = 'POS terminali bağlantısında hata oluştu:
							                   |""%ErrorDescription%"".
							                   |Kartla işlem yapılamadı.';
							                   |it = 'Alla connessione del terminale POS,
							                   |si è verificato un errore: ""%ErrorDescription%"".
							                   |L''operazione  con carta non è stata eseguita.';
							                   |de = 'Beim Anschluss des POS-Terminals
							                   |ist ein Fehler aufgetreten: ""%ErrorDescription%"".
							                   |Die Operation mit der Karte wurde nicht ausgeführt.'");
								MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
							CommonClientServer.MessageToUser(MessageText);
						EndIf;
					EndIf;
				EndIf;
			Else
				MessageText = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'");
				
				CommonClientServer.MessageToUser(MessageText);
			EndIf;
		EndIf;
		
	ElsIf ShowMessageBox Then
		ShowMessageBox(Undefined,NStr("en = 'Failed to post document'; ru = 'Не удалось выполнить проведение документа';pl = 'Księgowanie dokumentu nie powiodło się';es_ES = 'Fallado a enviar el documento';es_CO = 'Fallado a enviar el documento';tr = 'Belge kaydedilemedi';it = 'Impossibile pubblicare il documento';de = 'Fehler beim Buchen des Dokuments'"));
	EndIf;
	
EndProcedure

// Procedure changes form item content for deleted card.
//
&AtServer
Procedure ChangeItemsAfterPaymentDeletionAtServer(IndexOf, PaymentAmountDeleted);
	
	Items["PaymentByCardDeletionLabel_"+IndexOf].Title = "Payment is cancelled: -"+PaymentAmountDeleted;
	Items["PaymentByCard_"+IndexOf].Visible = False;
	Items["PaymentByCardDeletionLabel_"+IndexOf].Visible = True;
	
EndProcedure

// Procedure - command handler PaymentDeletionButton_N form, where N - card index in TK TemporaryCardTable.
//
&AtClient
Procedure ChooseCashToDeletePayment(Command)
	
	FoundStrings = TemporaryCardsTable.FindRows(New Structure("CommandName", ""+Command.Name));
	If FoundStrings.Count() > 0 Then
		
		If FoundStrings[0].Amount = 0 Then
			Return;
		EndIf;
		
		AdditionalParameters = New Structure("TableRow", FoundStrings[0]);
		NotifyDescription = New NotifyDescription("SelectCardToDeletePaymentEnd", ThisObject, AdditionalParameters);
		ShowQueryBox(NotifyDescription, "Cancel payment by card", QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
		
	Else
		
		Message = New UserMessage;
		Message.Text = "Error: delete command is not detected.";
		Message.Message();
		
	EndIf;
	
EndProcedure

// Procedure - command handler  PaymentDeletionButton_N after payment cancel confirmation. N - card index in TK TemporaryCardTable.
//
&AtClient
Procedure SelectCardToDeletePaymentEnd(Result, AdditionalParameters) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	Modified = True;
	
	If ValueIsFilled(POSTerminal) Then
		DeletePaymentByCardAfterCardSelection(AdditionalParameters.TableRow);
	Else
		CurrentData = AdditionalParameters.TableRow;
		
		If CurrentData.Amount = 0 Then
			Return;
		EndIf;
		
		CurrentData.PaymentAmountDeleted = CurrentData.Amount;
		CurrentData.Amount = 0;
		CurrentData.PaymentDeleted = True;
		
		IndexOf = TemporaryCardsTable.IndexOf(CurrentData);
		ChangeItemsAfterPaymentDeletionAtServer(IndexOf, CurrentData.PaymentAmountDeleted);
		
		RecalculateAmounts();
	EndIf;
	
EndProcedure

// Procedure copies data between TK TemporaryCardTable and PM PaymentByCards.
//
&AtClient
Procedure CopyTableDataInReceiverFromSourceAtClient(Receiver, Source);
	
	Receiver.Clear();
	For Each SourceCurrentString In Source Do
		NewTargetRow = Receiver.Add();
		FillPropertyValues(NewTargetRow, SourceCurrentString);
	EndDo;
	
EndProcedure

#EndRegion