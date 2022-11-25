
&AtClient
Procedure AddAndCalculateAdvanceRow(SettlementsAmount, CurrentRow)
	
	If TabName = "Debitor"
		And OperationType = OperationTypeCustomersAdvanceClearing
		And Not CurrentRow.AdvanceFlag Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Select only the documents with the ""Advance payment"" mark.'; ru = 'Выберите только те документы, у которых есть отметка ""Авансовый платеж"".';pl = 'Wybierz tylko dokumenty ze znakiem ""Zaliczka”.';es_ES = 'Seleccione sólo los documentos con la marca ""Pago de anticipo"".';es_CO = 'Seleccione sólo los documentos con la marca ""Pago Anticipado"".';tr = 'Sadece ""Avans ödeme"" işareti olan belgeleri seçin.';it = 'Selezionare solo i documenti con il contrassegno ""Pagamento anticipato"".';de = 'Wählen Sie nur die Dokumente mit der Markierung „Vorauszahlung“ aus.'"));
		Return;
		
	ElsIf TabName = "Creditor"
		And OperationType = OperationTypeCustomersAdvanceClearing
		And CurrentRow.AdvanceFlag Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Select only the documents without the ""Advance payment"" mark.'; ru = 'Выберите только те документы, у которых нет отметки ""Авансовый платеж"".';pl = 'Wybierz tylko dokumenty bez znaku ""Zaliczka”.';es_ES = 'Seleccione sólo los documentos sin la marca ""Pago de anticipo"".';es_CO = 'Seleccione sólo los documentos sin la marca ""Pago Anticipado"".';tr = 'Sadece ""Avans ödeme"" işareti olmayan belgeleri seçin.';it = 'Selezionare solo i documenti senza il contrassegno ""Pagamento anticipato"".';de = 'Wählen Sie nur die Dokumente ohne Markierung „Vorauszahlung“ aus.'"));
		Return;
		
	EndIf;
	
	SearchStructure = New Structure("Document, Order", CurrentRow.Document, CurrentRow.Order);
	Rows = ListFilteredAdvancesAndDebts.FindRows(SearchStructure);
	
	If Rows.Count() > 0 Then
		NewRow = Rows[0];
		SettlementsAmount = SettlementsAmount + NewRow.SettlementsAmount;
	Else
		NewRow = ListFilteredAdvancesAndDebts.Add();
	EndIf;
	
	FillPropertyValues(NewRow, CurrentRow);
	
	NewRow.SettlementsAmount = SettlementsAmount;
	
	ExchangeMethod = DriveServer.GetExchangeMethod(Company);
	
	NewRow.ExchangeRate = ?(NewRow.ExchangeRate = 0, 1, NewRow.ExchangeRate);
	NewRow.Multiplicity = ?(NewRow.Multiplicity = 0, 1, NewRow.Multiplicity);
	
	If ExchangeMethod = PredefinedValue("Enum.ExchangeRateMethods.Divisor") Then
		
		NewRow.ExchangeRate = ?(
			CurrentRow.AccountingAmount = 0,
			1,
			CurrentRow.SettlementsAmount / CurrentRow.AccountingAmount * RateAccountingCurrency);
			
	Else
		
		NewRow.ExchangeRate = ?(
			CurrentRow.SettlementsAmount = 0,
			1,
			CurrentRow.AccountingAmount / CurrentRow.SettlementsAmount * RateAccountingCurrency);
			
	EndIf;
		
	If Not ForeignExchangeAccounting Then
		NewRow.AccountingAmount = CurrentRow.SettlementsAmount;
	ElsIf AskAmount OR Rows.Count() > 0 Then
		NewRow.AccountingAmount = DriveServer.RecalculateFromCurrencyToCurrency(
			NewRow.SettlementsAmount,
			ExchangeMethod,
			NewRow.ExchangeRate,
			RateAccountingCurrency,
			NewRow.Multiplicity,
			AccountingCurrencyMultiplicity
		);
	EndIf;
	
	Items.ListFilteredAdvancesAndDebts.CurrentRow = NewRow.GetID();
	
	CalculateAmountsTotal();
	
	FillAdvancesAndDebts();
	
EndProcedure

// Procedure checks the correctness of the form attributes filling.
//
&AtClient
Procedure CheckFillOfFormAttributes(Cancel)
	
	// Attributes filling check.
	LineNumber = 0;
		
	For Each RowListFilteredAdvancesAndDebts In ListFilteredAdvancesAndDebts Do
		LineNumber = LineNumber + 1;
		If ForeignExchangeAccounting
		AND Not ValueIsFilled(RowListFilteredAdvancesAndDebts.ExchangeRate) Then
			Message = New UserMessage();
			Message.Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The exchange rate is empty in the line %1 of ""Selected documents"" section.'; ru = 'Не заполнен курс валют в строке %1 раздела ""Отобранные документы"".';pl = 'Kurs wymiany waluty obcej jest pusty w tym wierszu %1 ""Wybrane dokumenty"" sekcji.';es_ES = 'El tipo de cambio está vacío en la línea %1 de la sección ""Documentos seleccionados"".';es_CO = 'El tipo de cambio está vacío en la línea %1 de la sección ""Documentos seleccionados"".';tr = '""Seçilen belgeler"" bölümünün %1 satırında döviz kuru boş.';it = 'Il tasso di cambio è vuoto nella linea %1 della sezione ""Documenti selezionati"".';de = 'Der Wechselkurs ist in der Zeile %1 des Abschnitts ""Ausgewählte Dokumente"" leer.'"),
				String(LineNumber));
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
		If ForeignExchangeAccounting
		AND Not ValueIsFilled(RowListFilteredAdvancesAndDebts.Multiplicity) Then
			Message = New UserMessage();
			Message.Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The multiplier is empty in the line %1 of ""Selected documents"" section.'; ru = 'Не заполнена кратность в строке %1 раздела ""Отобранные документы"".';pl = 'Mnożnik jest pusty w wierszu %1 ""Wybrane dokumenty"" sekcji .';es_ES = 'El multiplicador está vacío en la línea %1 de la sección ""Documentos seleccionados"".';es_CO = 'El multiplicador está vacío en la línea %1 de la sección ""Documentos seleccionados"".';tr = '""Seçilen belgeler"" bölümünün %1 satırında çarpan boş.';it = 'Il moltiplicatore è vuoto nella linea %1 della sezione ""Documenti selezionati"".';de = 'Der Multiplikator ist in der Zeile %1 des Abschnitts ""Ausgewählte Dokumente"" leer.'"),
				String(LineNumber));
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
		If Not ValueIsFilled(RowListFilteredAdvancesAndDebts.SettlementsAmount) Then
			Message = New UserMessage();
			Message.Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The amount in contract currency is empty in the line %1 of ""Selected documents"" section.'; ru = 'Не заполнена сумма в валюте договора в строке %1 раздела ""Отобранные документы"".';pl = 'Wartość w walucie kontraktu jest pusta w tym wierszu %1 ""Wybrane dokumenty"" sekcji.';es_ES = 'La cantidad en moneda de contrato está vacía en la línea %1 de la sección ""Documentos seleccionados"".';es_CO = 'La cantidad en moneda de contrato está vacía en la línea %1 de la sección ""Documentos seleccionados"".';tr = '""Seçilen belgeler"" bölümünün %1 satırında sözleşme para birimindeki tutar boş.';it = 'L''importo nella valuta contrattuale è vuoto nella linea %1 della sezione ""Documenti selezionati"".';de = 'Der Betrag in Vertragswährung ist in der Zeile %1 des Abschnitts ""Ausgewählte Dokumente"" leer.'"),
				String(LineNumber));
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
		If ForeignExchangeAccounting
		AND Not ValueIsFilled(RowListFilteredAdvancesAndDebts.AccountingAmount) Then
			Message = New UserMessage();
			Message.Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The amount in presentation currency is empty in the line %1 of ""Selected documents"" section.'; ru = 'Не заполнена сумма в валюте представления отчетности в строке %1 раздела ""Отобранные документы"".';pl = 'Wartość w walucie prezentacji jest pusta w tym wierszu %1 ""Wybrane dokumenty"" sekcji.';es_ES = 'La cantidad en moneda de presentación está vacía en la línea %1 de la sección ""Documentos seleccionados"".';es_CO = 'La cantidad en moneda de presentación está vacía en la línea %1 de la sección ""Documentos seleccionados"".';tr = 'Finansal tablo para birimindeki tutar ""Seçilen belgeler"" bölümünün %1 satırında boş.';it = 'L''importo nella valuta contabile è vuoto nella linea %1 della sezione ""Documenti selezionati"".';de = 'Der Betrag in der Währung für die Berichtserstattung ist in der Zeile %1 des Abschnitts ""Ausgewählte Dokumente"" leer.'"),
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
	
	AccountingAmountTotal = 0;
	
	For Each CurRow In ListFilteredAdvancesAndDebts Do
		AccountingAmountTotal = AccountingAmountTotal + CurRow.AccountingAmount;
	EndDo;
	
EndProcedure

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Predefined values
	OperationTypeCustomersAdvanceClearing = Enums.OperationTypesArApAdjustments.CustomerAdvanceClearing;
	
	Company			= Parameters.Company;
	Counterparty	= Parameters.Counterparty;
	Date			= Parameters.Date;
	Ref				= Parameters.Ref;
	
	If Parameters.Property("AdvanceFlag") Then
		AdvanceFlagValues.Add(Parameters.AdvanceFlag);
	Else
		AdvanceFlagValues.Add(False);
		AdvanceFlagValues.Add(True);
	EndIf;
	
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	
	If Parameters.Property("DebitorAccountingAmount") And Parameters.Property("OperationType") And Parameters.Property("TabName")
		And (Parameters.OperationType = Enums.OperationTypesArApAdjustments.CustomerDebtAssignment
			Or Parameters.OperationType = Enums.OperationTypesArApAdjustments.CustomerAdvanceClearing) Then
			
		AccountingAmountTotal = Parameters.DebitorAccountingAmount;
		OperationType = Parameters.OperationType;
		TabName = Parameters.TabName;
		
	Else
		
		AccountingAmountTotal = 0;
		
		If Parameters.Property("OperationType") Then
			OperationType = Parameters.OperationType;
		Else
			OperationType = Enums.OperationTypesArApAdjustments.ArApAdjustments;
		EndIf;
		
	EndIf;
	
	Items.AdvancesDebtsListOrder.Visible = Counterparty.DoOperationsByOrders;
	Items.AdvancesDebtsListContract.Visible = Counterparty.DoOperationsByContracts;
	Items.ListFilteredAdvancesAndDebtsOrder.Visible = Counterparty.DoOperationsByOrders;
	Items.ListFilteredAdvancesAndDebtsContract.Visible = Counterparty.DoOperationsByContracts;
	
	AddressListFilteredAdvancesAndDebtsInStorage = Parameters.AddressDebitorInStorage;
	
	PresentationCurrency = DriveServer.GetPresentationCurrency(Company);
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Date, PresentationCurrency, Company);
	RateAccountingCurrency = StructureByCurrency.Rate;
	AccountingCurrencyMultiplicity = StructureByCurrency.Repetition;
	
	RowOfColumns =
		"Contract,
		|Document,
		|Order,
		|AccountingAmount,
		|ExchangeRate,
		|Multiplicity,
		|SettlementsAmount,
		|AdvanceFlag";
	
	ListFilteredAdvancesAndDebts.Load(GetFromTempStorage(AddressListFilteredAdvancesAndDebtsInStorage));
	
	Items.AdvancesDebtsListAccountingAmount.Visible = ForeignExchangeAccounting;
	
	FillAdvancesAndDebts();
	
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
	
	FillAdvancesAndDebts();
	
EndProcedure

// The procedure places pick-up results in the storage.
//
&AtServer
Procedure WritePickToStorage()
	
	ListFilteredAdvancesAndDebtsInStorage = ListFilteredAdvancesAndDebts.Unload(, RowOfColumns);
	PutToTempStorage(ListFilteredAdvancesAndDebtsInStorage, AddressListFilteredAdvancesAndDebtsInStorage);
	
EndProcedure

// It receives data set from the server for the ListFilteredAdvancesAndDebtsDocumentOnChange procedure.
//
&AtServerNoContext
Function GetDataDocumentOnChange(Document)
	
	StructureData = New Structure();
	
	StructureData.Insert("SettlementsAmount", Document.PaymentDetails.Total("SettlementsAmount"));
	
	Return StructureData;
	
EndFunction

// Adds a row into filtered.
//
&AtClient
Procedure AddRowIntoFiltered(CurrentRow)
	
	SettlementsAmount = CurrentRow.SettlementsAmount;
	If AskAmount Then
		
		NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("CurrentRow, SettlementsAmount", CurrentRow, SettlementsAmount));
		ShowInputNumber(NotifyDescription, SettlementsAmount, NStr("en = 'Enter the amount'; ru = 'Укажите сумму';pl = 'Wprowadź kwotę';es_ES = 'Introducir el importe';es_CO = 'Introducir el importe';tr = 'Tutarı girin';it = 'Inserire l''importo';de = 'Geben Sie den Betrag ein'"));
		
	Else
		
		AddAndCalculateAdvanceRow(SettlementsAmount, CurrentRow);
		
	EndIf;
	
EndProcedure

// The procedure places selection results into pick
//
&AtClient
Procedure AdvancesListValueChoice(Item, StandardProcessing, Value)
	
	StandardProcessing = False;
	CurrentRow = Item.CurrentData;
	AddRowIntoFiltered(CurrentRow);
	
EndProcedure

// Procedure - handler of event OnStartEdit of the ListFilteredAdvancesAndDebts tabular section.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsOnStartEdit(Item, NewRow, Copy)
	
	If Copy Then
		CalculateAmountsTotal();
		FillAdvancesAndDebts();
	EndIf;
	
EndProcedure

// Procedure - OnChange of input field SettlementsAmount of the
// ListFilteredAdvancesAndDebts part table event handler. Calculates the amount of the payment.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsAccountsAmountOnChange(Item)
	
	TabularSectionRow = Items.ListFilteredAdvancesAndDebts.CurrentData;
	CalculateAccountingSUM(TabularSectionRow);
	
EndProcedure

// Procedure - OnChange of input field Rate of
// the ListFilteredAdvancesAndDebts tabular section event handler. Calculates the amount of the payment.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsRateOnChange(Item)
	
	TabularSectionRow = Items.ListFilteredAdvancesAndDebts.CurrentData;
	CalculateAccountingSUM(TabularSectionRow);
	
EndProcedure

// Procedure - OnChange of input field Repetition of
// the ListFilteredAdvancesAndDebts tabular section event handler. Calculates the amount of the payment.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsMultiplicityOnChange(Item)
	
	TabularSectionRow = Items.ListFilteredAdvancesAndDebts.CurrentData;
	CalculateAccountingSUM(TabularSectionRow);
	
EndProcedure

// The OnChange event handler for the AccountingAmount field of the ListFilteredAdvancesAndDebts tabular section.
// It calculates the currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsAccountingAmountOnChange(Item)
	
	TabularSectionRow = Items.ListFilteredAdvancesAndDebts.CurrentData;
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
		1,
		TabularSectionRow.ExchangeRate
	);
	
	TabularSectionRow.Multiplicity = 1;
	
	TabularSectionRow.ExchangeRate =
		?(TabularSectionRow.SettlementsAmount = 0,
			1,
			TabularSectionRow.AccountingAmount
		  / TabularSectionRow.SettlementsAmount
		  * RateAccountingCurrency
	);
	
EndProcedure

// Procedure - OnChange of input field Document of
// the ListFilteredAdvancesAndDebts tabular section event handler.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsDocumentOnChange(Item)
	
	TabularSectionRow = Items.ListFilteredAdvancesAndDebts.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt") Then
		TabularSectionRow.AdvanceFlag = True;
	Else
		TabularSectionRow.AdvanceFlag = False;
	EndIf;
	
	If ValueIsFilled(TabularSectionRow.Document) Then
		StructureData = GetDataDocumentOnChange(TabularSectionRow.Document);
		TabularSectionRow.SettlementsAmount = StructureData.SettlementsAmount;
		CalculateAccountingSUM(TabularSectionRow);
	EndIf;
	
EndProcedure

// Procedure - handler of event StartDrag of list AdvancesList.
//
&AtClient
Procedure AdvancesListDragStart(Item, DragParameters, StandardProcessing)
	
	CurrentData = Item.CurrentData;
	Structure = New Structure;
	Structure.Insert("Contract", CurrentData.Contract);
	Structure.Insert("Document", CurrentData.Document);
	Structure.Insert("Order", CurrentData.Order);
	Structure.Insert("SettlementsAmount", CurrentData.SettlementsAmount);
	Structure.Insert("AdvanceFlag", CurrentData.AdvanceFlag);
	
	If CurrentData.Property("AccountingAmount") Then
		Structure.Insert("AccountingAmount", CurrentData.AccountingAmount);
	EndIf;
	
	DragParameters.Value = Structure;
	
	DragParameters.AllowedActions = DragAllowedActions.Copy;
	
EndProcedure

// Procedure - handler of event DragCheck of list ListFilteredAdvancesAndDebts.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	DragParameters.Action = DragAction.Copy;
	
EndProcedure

// Procedure - handler of event Drag of list ListFilteredAdvancesAndDebts.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	CurrentRow = DragParameters.Value;
	AddRowIntoFiltered(CurrentRow);
	FillAdvancesAndDebts();
	
EndProcedure

// Procedure - handler of event OnChange of list ListFilteredAdvancesAndDebts.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsOnChange(Item)
	
	CalculateAmountsTotal();
	FillAdvancesAndDebts();
	
EndProcedure

// Procedure - handler of event OnChange of list ListFilteredAdvancesAndDebtsContract.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsContractOnChange(Item)
	
	TabularSectionRow = Items.ListFilteredAdvancesAndDebts.CurrentData;
	
	StructureData = GetDataContractOnChange(Date, TabularSectionRow.Contract, Company);
	
	If ValueIsFilled(TabularSectionRow.Contract) Then 
		TabularSectionRow.ExchangeRate      = ?(StructureData.CurrencyRateRepetition.Rate = 0, 1, StructureData.CurrencyRateRepetition.Rate);
		TabularSectionRow.Multiplicity = ?(StructureData.CurrencyRateRepetition.Repetition = 0, 1, StructureData.CurrencyRateRepetition.Repetition);
	EndIf;
	
	CalculateAccountingSUM(TabularSectionRow);
	
EndProcedure

// Procedure calculates the accounting amount.
//
&AtClient
Procedure CalculateAccountingSUM(TabularSectionRow)
	
	TabularSectionRow.ExchangeRate      = ?(TabularSectionRow.ExchangeRate      = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.AccountingAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		DriveServer.GetExchangeMethod(Company),
		TabularSectionRow.ExchangeRate,
		RateAccountingCurrency,
		TabularSectionRow.Multiplicity,
		AccountingCurrencyMultiplicity
	);
	
EndProcedure

// It receives data set from the server for the CurrencyCashOnChange procedure.
//
&AtServerNoContext
Function GetDataContractOnChange(Date, Contract, Company)
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"CurrencyRateRepetition",
		CurrencyRateOperations.GetCurrencyRate(Date, Contract.SettlementsCurrency, Company)
	);
	
	Return StructureData;
	
EndFunction

// Procedure fills the advance list.
//
&AtServer
Procedure FillAdvancesAndDebts()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	FilteredAdvancesAndDebts.AdvanceFlag AS AdvanceFlag,
	|	FilteredAdvancesAndDebts.Contract AS Contract,
	|	FilteredAdvancesAndDebts.Document AS Document,
	|	FilteredAdvancesAndDebts.Order AS Order,
	|	FilteredAdvancesAndDebts.SettlementsAmount AS SettlementsAmount,
	|	FilteredAdvancesAndDebts.AccountingAmount AS AccountingAmount
	|INTO TableFilteredAdvancesAndDebts
	|FROM
	|	&TableFilteredAdvancesAndDebts AS FilteredAdvancesAndDebts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableBalances.Contract AS Contract,
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	CASE
	|		WHEN AccountsReceivableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AdvanceFlag,
	|	CASE
	|		WHEN AccountsReceivableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|			THEN -AccountsReceivableBalances.AmountBalance
	|		ELSE AccountsReceivableBalances.AmountBalance
	|	END AS AmountBalance,
	|	CASE
	|		WHEN AccountsReceivableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|			THEN -AccountsReceivableBalances.AmountCurBalance
	|		ELSE AccountsReceivableBalances.AmountCurBalance
	|	END AS AmountCurBalance
	|INTO AccountsReceivableBalances
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance) IN (&AdvanceFlagValues)) AS AccountsReceivableBalances
	|
	|UNION ALL
	|
	|SELECT
	|	FilteredAdvancesAndDebts.Contract,
	|	FilteredAdvancesAndDebts.Document,
	|	FilteredAdvancesAndDebts.Order,
	|	FilteredAdvancesAndDebts.AdvanceFlag,
	|	-FilteredAdvancesAndDebts.AccountingAmount,
	|	-FilteredAdvancesAndDebts.SettlementsAmount
	|FROM
	|	TableFilteredAdvancesAndDebts AS FilteredAdvancesAndDebts
	|WHERE
	|	FilteredAdvancesAndDebts.AdvanceFlag IN(&AdvanceFlagValues)
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentRegisterRecordsAccountsReceivable.Contract,
	|	DocumentRegisterRecordsAccountsReceivable.Document,
	|	DocumentRegisterRecordsAccountsReceivable.Order,
	|	CASE
	|		WHEN DocumentRegisterRecordsAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	CASE
	|		WHEN DocumentRegisterRecordsAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -ISNULL(DocumentRegisterRecordsAccountsReceivable.Amount, 0)
	|		ELSE ISNULL(DocumentRegisterRecordsAccountsReceivable.Amount, 0)
	|	END,
	|	CASE
	|		WHEN DocumentRegisterRecordsAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -ISNULL(DocumentRegisterRecordsAccountsReceivable.AmountCur, 0)
	|		ELSE ISNULL(DocumentRegisterRecordsAccountsReceivable.AmountCur, 0)
	|	END
	|FROM
	|	AccumulationRegister.AccountsReceivable AS DocumentRegisterRecordsAccountsReceivable
	|WHERE
	|	DocumentRegisterRecordsAccountsReceivable.Recorder = &Ref
	|	AND DocumentRegisterRecordsAccountsReceivable.Period <= &Period
	|	AND DocumentRegisterRecordsAccountsReceivable.Company = &Company
	|	AND DocumentRegisterRecordsAccountsReceivable.Counterparty = &Counterparty
	|	AND DocumentRegisterRecordsAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance) IN (&AdvanceFlagValues)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Contract AS Contract,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.AdvanceFlag AS AdvanceFlag,
	|	SUM(AccountsReceivableBalances.AmountBalance) AS AccountingAmount,
	|	SUM(AccountsReceivableBalances.AmountCurBalance) AS SettlementsAmount,
	|	AccountsReceivableBalances.Document.Date AS DocumentDate,
	|	SettlementsExchangeRate.Rate AS ExchangeRate,
	|	SettlementsExchangeRate.Repetition AS Multiplicity
	|FROM
	|	AccountsReceivableBalances AS AccountsReceivableBalances
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Period, Company = &Company) AS SettlementsExchangeRate
	|		ON AccountsReceivableBalances.Contract.SettlementsCurrency = SettlementsExchangeRate.Currency
	|
	|GROUP BY
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Contract,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.AdvanceFlag,
	|	AccountsReceivableBalances.Document.Date,
	|	SettlementsExchangeRate.Rate,
	|	SettlementsExchangeRate.Repetition
	|
	|HAVING
	|	(SUM(AccountsReceivableBalances.AmountBalance) > 0
	|		OR SUM(AccountsReceivableBalances.AmountCurBalance) > 0)
	|
	|ORDER BY
	|	DocumentDate";
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("TableFilteredAdvancesAndDebts", ListFilteredAdvancesAndDebts.Unload());
	Query.SetParameter("AdvanceFlagValues", AdvanceFlagValues);
	
	AdvancesDebtsList.Load(Query.Execute().Unload());
	
EndProcedure

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the result of entering the supplier advance offset amount.
//
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = Undefined Then
		
		Return;
		
	EndIf;
	
	SettlementsAmount = ClosingResult;
	CurrentRow = AdditionalParameters.CurrentRow;
	
	AddAndCalculateAdvanceRow(SettlementsAmount, CurrentRow);
	
EndProcedure

#EndRegion