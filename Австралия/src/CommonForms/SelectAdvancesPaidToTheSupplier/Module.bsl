// Procedure checks the correctness of the form attributes filling.
//
&AtClient
Procedure CheckFillOfFormAttributes(Cancel)
	
	// Attributes filling check.
	LineNumber = 0;
	For Each RowPrepayment In Prepayment Do
		LineNumber = LineNumber + 1;
		If ForeignExchangeAccounting
		AND Not ValueIsFilled(RowPrepayment.ExchangeRate) Then
			Message = New UserMessage();
			Message.Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The exchange rate is empty in the line %1 of ""To be cleared"" section.'; ru = 'Не заполнен курс валют в строке %1 раздела ""К зачету"".';pl = 'Kurs wymiany waluty jest pusty w tym wierszu %1 ""Do wyczyszczenia"".';es_ES = 'El tipo de cambio está vacío en la línea %1 de la sección ""Para borrar"".';es_CO = 'El tipo de cambio está vacío en la línea %1 de la sección ""Para borrar"".';tr = 'Döviz kuru, ""Silinecek/ Mahsup edilecek"" bölümünün %1 satırında boştur.';it = 'Il tasso di cambio è vuoto nella linea %1 della sezione ""Da compensare"".';de = 'Der Wechselkurs ist in der Zeile %1 des Abschnitts ""Zu löschen"" leer.'"),
				String(LineNumber));
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
		If ForeignExchangeAccounting
		AND Not ValueIsFilled(RowPrepayment.Multiplicity) Then
			Message = New UserMessage();
			Message.Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The multiplier is empty in the line %1 of ""To be cleared"" section.'; ru = 'Не заполнена кратность в строке %1 раздела ""К зачету"".';pl = 'Mnożnik jest pusty w wierszu %1 ""Do rozliczenia"" sekcji.';es_ES = 'El multiplicador está vacío en la línea %1 de la sección ""Para borrar"".';es_CO = 'El multiplicador está vacío en la línea %1 de la sección ""Para borrar"".';tr = 'Çarpan ""Silinecek"" bölümünün %1 satırında boştur.';it = 'Il moltiplicatore è vuoto nella linea %1 della sezione ""Da compensare"".';de = 'Der Multiplikator ist in der Zeile %1 des Abschnitts ""Zu löschen"" leer.'"),
				String(LineNumber));
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
		If Not ValueIsFilled(RowPrepayment.SettlementsAmount) Then
			Message = New UserMessage();
			Message.Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The clearing amount is empty in the line %1 of ""To be cleared"" section.'; ru = 'Не заполнена сумма к зачету в строке %1 раздела ""К зачету"".';pl = 'Kwota rozliczenia jest pusta w wierszu %1 sekcji ""Do rozliczenia"".';es_ES = 'La cantidad de compensación está vacía en la línea %1 de la sección ""Para borrar"".';es_CO = 'La cantidad de compensación está vacía en la línea %1 de la sección ""Para borrar"".';tr = '“Silinecek” bölümündeki %1 satırındaki mahsup etme tutarı boş. ';it = 'L''importo di compensazione è vuoto nella linea %1 della sezione ""Da compensare"".';de = 'Der Ausgleichsbetrag ist in der Zeile %1 des Abschnitts ""Zu löschen"" leer.'"),
				String(LineNumber));
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
		If ForeignExchangeAccounting
		AND Not ValueIsFilled(RowPrepayment.PaymentAmount) Then
			Message = New UserMessage();
			Message.Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The payment amount is empty in the line %1 of ""To be cleared"" section.'; ru = 'Не заполнена сумма платежа в строке %1 раздела ""К зачету"".';pl = 'Kwota płatności jest pusta w tym wierszu %1 ""Do rozliczenia"" sekcji.';es_ES = 'La cantidad de pago está vacía en la línea %1 de la sección ""Para borrar"".';es_CO = 'La cantidad de pago está vacía en la línea %1 de la sección ""Para borrar"".';tr = '""Silinecek"" bölümünün %1 satırında ödeme tutarı boş.';it = 'L''importo del pagamento è vuoto nella linea %1 della sezione ""Da compensare"".';de = 'Der Zahlungsbetrag ist in der Zeile %1 des Abschnitts ""Zu löschen"" leer.'"),
				String(LineNumber));
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
	EndDo;
	
EndProcedure

// Procedure calculates the total amounts.
//
&AtClient
Procedure CalculateAmountsTotal()
	
	PaymentAmountTotal = 0;
	SettlementsAmountTotal = 0;
	AmountDocCurTotal = 0;
	
	For Each CurRow In Prepayment Do
		PaymentAmountTotal = PaymentAmountTotal + CurRow.PaymentAmount;
		SettlementsAmountTotal = SettlementsAmountTotal + CurRow.SettlementsAmount;
		AmountDocCurTotal = AmountDocCurTotal + CurRow.AmountDocCur;
	EndDo;
	
EndProcedure

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Counterparty					= Parameters.Counterparty;
	Company							= Parameters.Company;
	Contract						= Parameters.Contract;
	ExchangeRate					= Parameters.ExchangeRate;
	Multiplicity					= Parameters.Multiplicity;
	DocumentCurrency				= Parameters.DocumentCurrency;
	ContractCurrencyExchangeRate	= Parameters.ContractCurrencyExchangeRate;
	ContractCurrencyMultiplicity	= Parameters.ContractCurrencyMultiplicity;
	IsOrder							= Parameters.IsOrder;
	OrderInHeader					= Parameters.OrderInHeader;
	Ref								= Parameters.Ref;
	Date							= Parameters.Date;
	DocumentAmount					= Parameters.DocumentAmount;
	ThisSelection					= Parameters.Pick;
	AddressPrepaymentInStorage		= Parameters.AddressPrepaymentInStorage;
	
	If ValueIsFilled(Contract) Then
		SettlementsCurrency = Common.ObjectAttributeValue(Contract, "SettlementsCurrency");
	EndIf;
	
	If ValueIsFilled(Counterparty) Then
		DoOperationsByOrders = Common.ObjectAttributeValue(Counterparty, "DoOperationsByOrders");
	EndIf;
	
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	ExchangeRateMethod = DriveServer.GetExchangeMethod(Company);
	
	Items.PrepaymentOrder.Visible = DoOperationsByOrders;
	Items.AdvancesListOrder.Visible = DoOperationsByOrders;
	
	FillOrdersList();
	
	If Not ThisSelection Then
		Items.Header.Visible = False;
		Items.Advances.Visible = False;
		Items.PrepaymentAutoFill.Visible = False;
		Title = NStr("en = 'Prepayment recovery'; ru = 'Взыскание аванса';pl = 'Odzyskiwanie przedpłaty';es_ES = 'Recuperación de prepago';es_CO = 'Recuperación de prepago';tr = 'Ön ödeme kurtarma';it = 'Recupero pagamento anticipato';de = 'Rückforderung von Anzahlungen'");
	EndIf;
	
	Items.PrepaymentDocument.ReadOnly = ThisSelection;
	Items.PrepaymentOrder.ReadOnly = ThisSelection;
	
	Items.PrepaymentAdd.Visible = Not ThisSelection;
	Items.PrepaymentCopy.Visible = Not ThisSelection;
	
	Items.PrepaymentDocument.TypeRestriction = Ref.Metadata().TabularSections.Prepayment.Attributes.Document.Type;
	
	If IsOrder Then
		Items.PrepaymentOrder.TypeRestriction = Ref.Metadata().TabularSections.Prepayment.Attributes.Order.Type;
	EndIf;
	
	FunctionalCurrency = DriveReUse.GetFunctionalCurrency();
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Date, FunctionalCurrency, Company);
	RateNationalCurrency = StructureByCurrency.Rate;
	RepetitionNationalCurrency = StructureByCurrency.Repetition;
	
	PresentationCurrency = DriveServer.GetPresentationCurrency(Company);
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Date, PresentationCurrency, Company);
	RateAccountingCurrency = StructureByCurrency.Rate;
	AccountingCurrencyMultiplicity = StructureByCurrency.Repetition;
	
	If IsOrder Then
		RowOfColumns = "
			|Document,
			|Order,
			|PaymentAmount,
			|AmountDocCur,
			|ExchangeRate,
			|Multiplicity,
			|SettlementsAmount";
	Else
		RowOfColumns = "
			|Document, 
			|PaymentAmount,
			|AmountDocCur,
			|ExchangeRate,
			|Multiplicity,
			|SettlementsAmount";
		Items.Prepayment.ChildItems.PrepaymentOrder.Visible = False;
	EndIf;
	
	For Each CurRow In Prepayment Do // for correct dragging
		If Not ValueIsFilled(CurRow.Order) Then
			CurRow.Order = Documents.PurchaseOrder.EmptyRef();
		EndIf;
	EndDo;
	
	Prepayment.Load(GetFromTempStorage(AddressPrepaymentInStorage));
	
	FillAdvances();
	
	If DocumentCurrency = SettlementsCurrency Then
		
		Items.PrepaymentAmountDocCur.Visible = False;
		Items.AdvancesListAmountDocCur.Visible = False;
		Items.AmountDocCurTotal.Visible = False;
		Items.DocumentCurrency.Visible = False;
		
	Else
		
		Items.PrepaymentAmountDocCur.Visible = True;
		Items.AdvancesListAmountDocCur.Visible = True;
		Items.AmountDocCurTotal.Visible = True;
		Items.DocumentCurrency.Visible = True;
		
		AmountDocCurTitle = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Amount (%1)'; ru = 'Сумма (%1)';pl = 'Wartość (%1)';es_ES = 'Importe (%1)';es_CO = 'Cantidad (%1)';tr = 'Tutar (%1)';it = 'Importo (%1)';de = 'Betrag (%1)'"),
				DocumentCurrency);
		Items.PrepaymentAmountDocCur.Title = AmountDocCurTitle;
		Items.AdvancesListAmountDocCur.Title = AmountDocCurTitle;
		
		SettlementsAmountTitle = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Clearing amount (%1)'; ru = 'Сумма зачета (%1)';pl = 'Kwota rozliczenia (%1)';es_ES = 'Importe de liquidaciones (%1)';es_CO = 'Importe de liquidaciones (%1)';tr = 'Mahsup edilen tutar (%1)';it = 'Importo di compensazione (%1)';de = 'Ausgleichsbetrag (%1)'"),
				SettlementsCurrency);
		Items.PrepaymentSettlementsAmount.Title = SettlementsAmountTitle;
		Items.AdvancesListSettlementsAmount.Title = SettlementsAmountTitle;
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	CalculateAmountsTotal();
	
EndProcedure

// Procedure - OK button click handler.
//
&AtClient
Procedure OK(Command)
	
	Cancel = False;
	
	CheckFillOfFormAttributes(Cancel);
	
	If Not Cancel Then
		WritePickToStorage();
		Close(DialogReturnCode.OK);
	EndIf;
	
EndProcedure

// Procedure - handler of clicking the Refresh button.
//
&AtClient
Procedure Refresh(Command)
	
	FillAdvances();
	
EndProcedure

// Procedure - handler of clicking the AskAmount button.
//
&AtClient
Procedure AskAmount(Command)
	
	AskAmount = Not AskAmount;
	Items.AskAmount.Check = AskAmount;
	
EndProcedure

// The procedure places pick-up results in the storage.
//
&AtServer
Procedure WritePickToStorage() 
	
	PrepaymentInStorage = Prepayment.Unload(, RowOfColumns);
	PutToTempStorage(PrepaymentInStorage, AddressPrepaymentInStorage);
	
EndProcedure

// Receives data set from server for procedure PrepaymentDocumentOnChange.
//
&AtServerNoContext
Function GetDataDocumentOnChange(Document)
	
	StructureData = New Structure();
	
	If TypeOf(Document) = Type("DocumentRef.ExpenseReport") Then
		StructureData.Insert("SettlementsAmount", Document.Payments.Total("SettlementsAmount"));
	Else
		StructureData.Insert("SettlementsAmount", Document.PaymentDetails.Total("SettlementsAmount"));
	EndIf;
	
	Return StructureData;
	
EndFunction

// Fills to offset by advance string.
//
&AtClient
Procedure ChoiceAdvance(CurrentRow)
	
	SettlementsAmount = CurrentRow.SettlementsAmount;
	If AskAmount Then
		ShowInputNumber(New NotifyDescription("AdvanceChoiceEnd", ThisObject, New Structure("CurrentRow, SettlementsAmount", CurrentRow, SettlementsAmount)), SettlementsAmount, "Enter the clearing amount", , );
		Return;
	EndIf;
	
	AdvanceChoiceFragment(SettlementsAmount, CurrentRow);
EndProcedure

&AtClient
Procedure AdvanceChoiceEnd(Result, AdditionalParameters) Export
    
    CurrentRow = AdditionalParameters.CurrentRow;
    SettlementsAmount = ?(Result = Undefined, AdditionalParameters.SettlementsAmount, Result);
    
    
    If Not (Result <> Undefined) Then
        Return;
    EndIf;
    
    AdvanceChoiceFragment(SettlementsAmount, CurrentRow);

EndProcedure

&AtClient
Procedure AdvanceChoiceFragment(SettlementsAmount, Val CurrentRow)
	
	Var NewRow, Rows, SearchStructure;
	
	SearchStructure = New Structure("Document, Order", CurrentRow.Document, CurrentRow.Order);
	Rows = Prepayment.FindRows(SearchStructure);
	
	If Rows.Count() > 0 Then
		NewRow = Rows[0];
		SettlementsAmount = SettlementsAmount + NewRow.SettlementsAmount;
	Else
		NewRow = Prepayment.Add();
	EndIf;
	
	NewRow.Document = CurrentRow.Document;
	NewRow.Order = CurrentRow.Order;
	NewRow.SettlementsAmount = SettlementsAmount;
	
	NewRow.ExchangeRate = ?(NewRow.ExchangeRate = 0, CurrentRow.ExchangeRate, NewRow.ExchangeRate);
	NewRow.Multiplicity = ?(NewRow.Multiplicity = 0, CurrentRow.Multiplicity, NewRow.Multiplicity);
	
	If Not ForeignExchangeAccounting Then
		NewRow.PaymentAmount = NewRow.SettlementsAmount;
		NewRow.AmountDocCur = NewRow.SettlementsAmount;
	Else
		If SettlementsAmount = CurrentRow.SettlementsAmount
			And DocumentCurrency = PresentationCurrency Then
			NewRow.PaymentAmount = CurrentRow.PaymentAmount;
		Else
			NewRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				NewRow.SettlementsAmount,
				ExchangeRateMethod,
				NewRow.ExchangeRate,
				1,
				NewRow.Multiplicity,
				1);
		EndIf;
		NewRow.AmountDocCur = DriveServer.RecalculateFromCurrencyToCurrency(
			NewRow.SettlementsAmount,
			ExchangeRateMethod,
			ContractCurrencyExchangeRate,
			ExchangeRate,
			ContractCurrencyMultiplicity,
			Multiplicity);
	EndIf;
	
	Items.Prepayment.CurrentRow = NewRow.GetID();
	
	CalculateAmountsTotal();
	FillAdvances();
	
EndProcedure

// The procedure places selection results into pick
//
&AtClient
Procedure AdvancesListValueChoice(Item, StandardProcessing, Value)
	
	StandardProcessing = False;
	CurrentRow = Item.CurrentData;
	ChoiceAdvance(CurrentRow);
	
EndProcedure

// Procedure - handler of event OnStartEdit of tablular section Prepayment.
//
&AtClient
Procedure PrepaymentOnStartEdit(Item, NewRow, Copy)
	
	If NewRow
	   AND OrderInHeader
	   AND ValueIsFilled(Order) Then
		Item.CurrentData.Order = Order;
	EndIf;
	
	If Copy Then
		CalculateAmountsTotal();
		FillAdvances();
	EndIf;
	
EndProcedure

// Procedure - handler of event OnChange of tabular section
// Prepayment input field SettlementsAmount. Calculates the amount of the payment.
//
&AtClient
Procedure PrepaymentAccountsAmountOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	TabularSectionRow.ExchangeRate = ?(TabularSectionRow.ExchangeRate = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		ExchangeRateMethod,
		TabularSectionRow.ExchangeRate,
		1,
		TabularSectionRow.Multiplicity,
		1);
	
	TabularSectionRow.AmountDocCur = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		ExchangeRateMethod,
		ContractCurrencyExchangeRate,
		ExchangeRate,
		ContractCurrencyMultiplicity,
		Multiplicity);
	
EndProcedure

// Procedure - handler of event OnChange of tabular section
// Prepayment input field ExchangeRate. Calculates the amount of the payment.
//
&AtClient
Procedure PrepaymentRateOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	TabularSectionRow.ExchangeRate = ?(TabularSectionRow.ExchangeRate = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		ExchangeRateMethod,
		TabularSectionRow.ExchangeRate,
		1,
		TabularSectionRow.Multiplicity,
		1);
	
EndProcedure

// The OnChange event handler for the Multiplicity field of the Prepayment tabular section.
// It calculates the payment amount.
//
&AtClient
Procedure PrepaymentMultiplicityOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	TabularSectionRow.ExchangeRate = ?(TabularSectionRow.ExchangeRate = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		ExchangeRateMethod,
		TabularSectionRow.ExchangeRate,
		1,
		TabularSectionRow.Multiplicity,
		1);
	
EndProcedure

// Procedure - handler of event OnChange of tabular section
// Prepayment input field Document.
//
&AtClient
Procedure PrepaymentDocumentOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	If ValueIsFilled(TabularSectionRow.Document) Then
		
		StructureData = GetDataDocumentOnChange(TabularSectionRow.Document);
		
		TabularSectionRow.SettlementsAmount = StructureData.SettlementsAmount;
		
		TabularSectionRow.AmountDocCur = DriveServer.RecalculateFromCurrencyToCurrency(
			TabularSectionRow.SettlementsAmount,
			ExchangeRateMethod,
			ContractCurrencyExchangeRate,
			ExchangeRate,
			ContractCurrencyMultiplicity,
			Multiplicity);
		
		TabularSectionRow.ExchangeRate = ?(TabularSectionRow.ExchangeRate = 0, 1, TabularSectionRow.ExchangeRate);
		TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
		
		TabularSectionRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
			TabularSectionRow.SettlementsAmount,
			ExchangeRateMethod,
			TabularSectionRow.ExchangeRate,
			1,
			TabularSectionRow.Multiplicity,
			1);
		
	EndIf;
	
EndProcedure

// Procedure - handler of event StartDrag of list AdvancesList.
//
&AtClient
Procedure AdvancesListDragStart(Item, DragParameters, StandardProcessing)
	
	CurrentData = Item.CurrentData;
	Structure = New Structure;
	Structure.Insert("Document", CurrentData.Document);
	Structure.Insert("Order", CurrentData.Order);
	Structure.Insert("SettlementsAmount", CurrentData.SettlementsAmount);
	Structure.Insert("PaymentAmount", CurrentData.PaymentAmount);
	Structure.Insert("ExchangeRate", CurrentData.ExchangeRate);
	Structure.Insert("Multiplicity", CurrentData.Multiplicity);
	
	DragParameters.Value = Structure;
	
	DragParameters.AllowedActions = DragAllowedActions.Copy;
	
EndProcedure

// Procedure - handler of list Prepayment event DragCheck.
//
&AtClient
Procedure PrepaymentDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	DragParameters.Action = DragAction.Copy;
	
EndProcedure

// Procedure - handler of list Prepayment event Drag.
//
&AtClient
Procedure PrepaymentDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	CurrentRow = DragParameters.Value;
	ChoiceAdvance(CurrentRow);
	
EndProcedure

// Procedure - handler of list Prepayment event OnChange.
//
&AtClient
Procedure PrepaymentOnChange(Item)
	
	CalculateAmountsTotal();
	FillAdvances();
	
EndProcedure

// Procedure fills prepayment.
//
&AtServer
Procedure FillPrepayment()
	
	OrdersTable = OrdersList.Unload();
	
	For Each AdvancesRow In AdvancesList Do
		
		FoundString = OrdersTable.Find(AdvancesRow.Order, "Order");
		
		If FoundString = Undefined
		 OR FoundString.TotalCalc = 0 Then
			Continue;
		EndIf;
		
		If AdvancesRow.SettlementsAmount <= FoundString.TotalCalc Then // balance amount is less or equal than it is necessary to distribute
			
			NewRow = Prepayment.Add();
			FillPropertyValues(NewRow, AdvancesRow);
			FoundString.TotalCalc = FoundString.TotalCalc - AdvancesRow.SettlementsAmount;
			
		Else // Balance amount is greater than it is necessary to distribute
			
			NewRow = Prepayment.Add();
			FillPropertyValues(NewRow, AdvancesRow);
			
			NewRow.SettlementsAmount = FoundString.TotalCalc;
			NewRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				NewRow.SettlementsAmount,
				ExchangeRateMethod,
				AdvancesRow.ExchangeRate,
				1,
				AdvancesRow.Multiplicity,
				1);
			
			FoundString.TotalCalc = 0;
			
		EndIf;
		
		NewRow.AmountDocCur = DriveServer.RecalculateFromCurrencyToCurrency(
			NewRow.SettlementsAmount,
			ExchangeRateMethod,
			ContractCurrencyExchangeRate,
			ExchangeRate,
			ContractCurrencyMultiplicity,
			Multiplicity);
		
	EndDo;
	
EndProcedure

// Procedure - Handler of clicking the FillAutomatically button.
//
&AtClient
Procedure FillAutomatically(Command)
	
	Prepayment.Clear();
	FillAdvances();
	FillPrepayment();
	CalculateAmountsTotal();
	FillAdvances();
	
EndProcedure

// Procedure fills the advance list.
//
&AtServer
Procedure FillAdvances()
	
	Query = New Query;
	QueryText =
	"SELECT
	|	FilteredAdvances.Document AS Document,
	|	CASE
	|		WHEN NOT &IsOrder
	|			THEN &Order
	|		WHEN FilteredAdvances.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|				OR FilteredAdvances.Order = VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE FilteredAdvances.Order
	|	END AS Order,
	|	&SettlementsCurrency AS SettlementsCurrency,
	|	FilteredAdvances.SettlementsAmount AS SettlementsAmount,
	|	FilteredAdvances.AmountDocCur AS AmountDocCur,
	|	FilteredAdvances.PaymentAmount AS PaymentAmount
	|INTO TableFilteredAdvances
	|FROM
	|	&TableFilteredAdvances AS FilteredAdvances
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.DocumentDate AS DocumentDate,
	|	AccountsPayableBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(AccountsPayableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsPayableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableAccountsPayableBalances
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.Contract AS Contract,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.Document.Date AS DocumentDate,
	|		AccountsPayableBalances.Order AS Order,
	|		AccountsPayableBalances.AmountBalance AS AmountBalance,
	|		AccountsPayableBalances.AmountCurBalance AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsPayable.Balance(
	|				&Period,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					AND &TextOrderInHeader
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsVendorSettlements.Contract,
	|		DocumentRegisterRecordsVendorSettlements.Document,
	|		DocumentRegisterRecordsVendorSettlements.Document.Date,
	|		DocumentRegisterRecordsVendorSettlements.Order,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -DocumentRegisterRecordsVendorSettlements.Amount
	|			ELSE DocumentRegisterRecordsVendorSettlements.Amount
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -DocumentRegisterRecordsVendorSettlements.AmountCur
	|			ELSE DocumentRegisterRecordsVendorSettlements.AmountCur
	|		END
	|	FROM
	|		AccumulationRegister.AccountsPayable AS DocumentRegisterRecordsVendorSettlements
	|	WHERE
	|		DocumentRegisterRecordsVendorSettlements.Recorder = &Ref
	|		AND DocumentRegisterRecordsVendorSettlements.Company = &Company
	|		AND DocumentRegisterRecordsVendorSettlements.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsVendorSettlements.Contract = &Contract
	|		AND DocumentRegisterRecordsVendorSettlements.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|
	|GROUP BY
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.DocumentDate,
	|	AccountsPayableBalances.Contract.SettlementsCurrency
	|
	|HAVING
	|	SUM(AccountsPayableBalances.AmountCurBalance) < 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.DocumentDate AS DocumentDate,
	|	AccountsPayableBalances.SettlementsCurrency AS SettlementsCurrency,
	|	-SUM(AccountsPayableBalances.SettlementsAmount) AS SettlementsAmount,
	|	-SUM(AccountsPayableBalances.AmountDocCur) AS AmountDocCur,
	|	-SUM(AccountsPayableBalances.PaymentAmount) AS PaymentAmount,
	|	CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN CASE
	|					WHEN SUM(AccountsPayableBalances.PaymentAmount) <> 0
	|						THEN SUM(AccountsPayableBalances.SettlementsAmount) / SUM(AccountsPayableBalances.PaymentAmount)
	|					ELSE 1
	|				END
	|		ELSE CASE
	|				WHEN SUM(AccountsPayableBalances.SettlementsAmount) <> 0
	|					THEN SUM(AccountsPayableBalances.PaymentAmount) / SUM(AccountsPayableBalances.SettlementsAmount)
	|				ELSE 1
	|			END
	|	END AS ExchangeRate,
	|	1 AS Multiplicity
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.SettlementsCurrency AS SettlementsCurrency,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.DocumentDate AS DocumentDate,
	|		AccountsPayableBalances.Order AS Order,
	|		AccountsPayableBalances.AmountCurBalance AS SettlementsAmount,
	|		CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN CAST(AccountsPayableBalances.AmountCurBalance * &ExchangeRate * &ContractCurrencyMultiplicity / (&ContractCurrencyExchangeRate * &Multiplicity) AS NUMBER(15, 2))
	|			ELSE CAST(AccountsPayableBalances.AmountCurBalance * &ContractCurrencyExchangeRate * &Multiplicity / (&ExchangeRate * &ContractCurrencyMultiplicity) AS NUMBER(15, 2))
	|		END AS AmountDocCur,
	|		AccountsPayableBalances.AmountBalance AS PaymentAmount
	|	FROM
	|		TemporaryTableAccountsPayableBalances AS AccountsPayableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		FilteredAdvances.SettlementsCurrency,
	|		FilteredAdvances.Document,
	|		FilteredAdvances.Document.Date,
	|		FilteredAdvances.Order,
	|		FilteredAdvances.SettlementsAmount,
	|		FilteredAdvances.AmountDocCur,
	|		FilteredAdvances.PaymentAmount
	|	FROM
	|		TableFilteredAdvances AS FilteredAdvances) AS AccountsPayableBalances
	|
	|GROUP BY
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.DocumentDate,
	|	AccountsPayableBalances.SettlementsCurrency
	|
	|HAVING
	|	SUM(AccountsPayableBalances.SettlementsAmount) < 0
	|
	|ORDER BY
	|	DocumentDate";
	
	Query.SetParameter("IsOrder", IsOrder);
	
	If Not DoOperationsByOrders Then
		
		QueryText = StrReplace(QueryText, "&TextOrderInHeader", "Order = &Order");
		Query.SetParameter("Order", Undefined);
		
	ElsIf OrderInHeader Or Not IsOrder Then
		
		QueryText = StrReplace(QueryText, "&TextOrderInHeader", "Order = &Order");
		Query.SetParameter("Order", Order);
		
	Else
		
		Query.SetParameter("Order", Undefined);
		QueryText = StrReplace(QueryText, "&TextOrderInHeader", "Order IN (&OrdersArray)");
		Query.SetParameter("OrdersArray", OrdersList.Unload().UnloadColumn("Order"));
		
	EndIf;
	
	Query.Text = QueryText;
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Contract", Contract);
	Query.SetParameter("Period", EndOfDay(Date) + 1);
	Query.SetParameter("SettlementsCurrency", SettlementsCurrency);
	Query.SetParameter("DocumentCurrency", DocumentCurrency);
	Query.SetParameter("PresentationCurrency", PresentationCurrency);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("TableFilteredAdvances", Prepayment.Unload());
	Query.SetParameter("ExchangeRate", ExchangeRate);
	Query.SetParameter("Multiplicity", Multiplicity);
	Query.SetParameter("ContractCurrencyExchangeRate", ContractCurrencyExchangeRate);
	Query.SetParameter("ContractCurrencyMultiplicity", ContractCurrencyMultiplicity);
	Query.SetParameter("ExchangeRateMethod", ExchangeRateMethod);
	
	AdvancesList.Load(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure FillOrdersList()
	
	If OrderInHeader And DoOperationsByOrders Then // order in header
		
		Order = Parameters.Order;
		Items.PrepaymentOrder.Visible = False;
		
		NewRow = OrdersList.Add();
		NewRow.Order = Parameters.Order;
		NewRow.Total = Parameters.DocumentAmount;
		NewRow.TotalCalc = DriveServer.RecalculateFromCurrencyToCurrency(
			NewRow.Total,
			ExchangeRateMethod,
			ExchangeRate,
			ContractCurrencyExchangeRate,
			Multiplicity,
			ContractCurrencyMultiplicity);
		
	ElsIf IsOrder And DoOperationsByOrders Then // order in tabular section
		
		Order = Undefined;
		
		If Parameters.Property("Order") And TypeOf(Parameters.Order) = Type("Array") Then
			
			OrdersTable = OrdersList.Unload();
			
			For Each ArrayElement In Parameters.Order Do
				
				OrdersRow = OrdersTable.Add();
				OrdersRow.Order = ArrayElement.Order;
				OrdersRow.Total = ArrayElement.Total;
				OrdersRow.TotalCalc = DriveServer.RecalculateFromCurrencyToCurrency(
					OrdersRow.Total,
					ExchangeRateMethod,
					ExchangeRate,
					ContractCurrencyExchangeRate,
					Multiplicity,
					ContractCurrencyMultiplicity);
				
			EndDo;
			
			OrdersTable.GroupBy("Order", "Total, TotalCalc");
			OrdersTable.Sort("Order Asc");
			OrdersList.Load(OrdersTable);
			
		EndIf;
		
	Else // no order
		
		Order = Undefined;
		
		NewRow = OrdersList.Add();
		NewRow.Order = Undefined;
		NewRow.Total = Parameters.DocumentAmount;
		NewRow.TotalCalc = DriveServer.RecalculateFromCurrencyToCurrency(
			NewRow.Total,
			ExchangeRateMethod,
			ExchangeRate,
			ContractCurrencyExchangeRate,
			Multiplicity,
			ContractCurrencyMultiplicity);
		
	EndIf;
	
EndProcedure

// Procedure prohibits to add rows if manual selection is not allowed.
//
&AtClient
Procedure PrepaymentBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If ThisSelection Then
		Cancel = True;
	EndIf;
	
EndProcedure
