
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", False);
		ParametersStructure.Insert("FillHeader", False);
		ParametersStructure.Insert("FillInventory", True);
		ParametersStructure.Insert("FillExpenses", True);
		
		FillAddedColumns(ParametersStructure);
	
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "Document.TaxInvoiceReceived.Form.DocumentForm" Then
		TaxInvoiceText = SelectedValue;
	ElsIf GLAccountsInDocumentsClient.IsGLAccountsChoiceProcessing(ChoiceSource.FormName) Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	EndIf;
	
EndProcedure

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues);
	
	If Not ValueIsFilled(Object.Ref)
		  AND ValueIsFilled(Object.Counterparty)
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
		If Not ValueIsFilled(Object.Contract) Then
			Object.Contract = DriveServer.GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
		EndIf;
		If ValueIsFilled(Object.Contract) Then
			Object.DocumentCurrency = Object.Contract.SettlementsCurrency;
			SettlementsCurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.DocumentCurrency, Object.Company);
			Object.ExchangeRate	  = ?(SettlementsCurrencyRateRepetition.Rate = 0, 1, SettlementsCurrencyRateRepetition.Rate);
			Object.Multiplicity = ?(SettlementsCurrencyRateRepetition.Repetition = 0, 1, SettlementsCurrencyRateRepetition.Repetition);
			
			If Object.PaymentCalendar.Count() = 0 Then
				FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
			EndIf;
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	If NOT ValueIsFilled(Object.IncomingDocumentDate) Then
		Object.IncomingDocumentDate = DocumentDate;
	EndIf;
	
	Company = DriveServer.GetCompany(Object.Company);
	OldCompany = Object.Company;
	Counterparty = Object.Counterparty;
	Contract = Object.Contract;
	Order = Object.PurchaseOrder;
	IncomingDocumentDate = Object.IncomingDocumentDate;
	SettlementsCurrency = Object.Contract.SettlementsCurrency;
	FunctionalCurrency = Constants.FunctionalCurrency.Get();
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Object.Date, FunctionalCurrency, Company);
	RateNationalCurrency = StructureByCurrency.Rate;
	RepetitionNationalCurrency = StructureByCurrency.Repetition;
	ExchangeRateMethod = DriveServer.GetExchangeMethod(Company);
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	
	Policy = GetAccountingPolicyValues(DocumentDate, Company);
	PerInvoiceVATRoundingRule = Policy.PerInvoiceVATRoundingRule;
	RegisteredForVAT = Policy.RegisteredForVAT;
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis)
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then	
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.ExpencesVATRate.Visible = True;
		Items.ExpencesAmountVAT.Visible = True;
		Items.TotalExpences.Visible = True;
		Items.DocumentTax.Visible = True;
	Else
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.ExpencesVATRate.Visible = False;
		Items.ExpencesAmountVAT.Visible = False;
		Items.TotalExpences.Visible = False;
		Items.DocumentTax.Visible = False;
	EndIf;
	
	SetPrepaymentColumnsProperties();
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", False);
		ParametersStructure.Insert("FillHeader", True);
		ParametersStructure.Insert("FillInventory", True);
		ParametersStructure.Insert("FillExpenses", True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
	WorkWithVAT.SetTextAboutTaxInvoiceReceived(ThisObject);
	
	// Generate price and currency label.
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency", Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency", SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate", Object.ExchangeRate);
	LabelStructure.Insert("RateNationalCurrency", RateNationalCurrency);
	LabelStructure.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting", ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation", Object.VATTaxation);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	// Setting contract visible.
	SetContractVisible();
	
	SetItemsVisibleAtServer();
	
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	SwitchTypeListOfPaymentCalendar = ?(Object.PaymentCalendar.Count() > 1, 1, 0);
	
	DriveServer.CheckObjectGeneratedEnteringBalances(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	PrepaymentWasChanged = False;
	
	SetVisibleEnablePaymentTermItems();
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
EndProcedure

// Procedure-handler of the BeforeWriteAtServer event.
// 
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(
			MessageText, 
			Object.Contract, 
			Object.Ref,
			Object.Company,
			Object.Counterparty,
			Cancel,
			CounterpartyAttributes.DoOperationsByContracts);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("en = 'Document is not posted.'; ru = 'Документ не проведен.';pl = 'Dokument niezaksięgowany.';es_ES = 'El documento no se ha publicado.';es_CO = 'El documento no se ha publicado.';tr = 'Belge kaydedilmedi.';it = 'Il documento non è pubblicato.';de = 'Beleg wird nicht gebucht.'") + " " + MessageText, MessageText);
			
			If Cancel Then
				Message.DataPath = "Object";
				Message.Field = "Contract";
				Message.Message();
				Return;
			Else
				Message.Message();
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If DriveReUse.GetAdvanceOffsettingSettingValue() = Enums.YesNo.Yes 
		And CurrentObject.Expenses.Count() > 0
		And CurrentObject.Prepayment.Count() = 0 Then
		FillPrepayment(CurrentObject);
	ElsIf PrepaymentWasChanged Then
		WorkWithVAT.FillPrepaymentVATFromVATInput(CurrentObject);
	EndIf;
	
	CalculationParameters = New Structure;
	CalculationParameters.Insert("TabularSectionName", "Expenses");
	AmountsHaveChanged = WorkWithVAT.CalculateVATPerInvoiceTotal(CurrentObject, CalculationParameters);
	If AmountsHaveChanged Then
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(CurrentObject);
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

// Procedure fills advances.
//
&AtServer
Procedure FillPrepayment(CurrentObject)
	
	CurrentObject.FillPrepayment();
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", False);
		ParametersStructure.Insert("FillHeader", True);
		ParametersStructure.Insert("FillInventory", True);
		ParametersStructure.Insert("FillExpenses", True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
	SetSwitchTypeListOfPaymentCalendar();
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("NotificationAboutChangingDebt");
	Notify("RefreshAccountingTransaction");
	
	PrepaymentWasChanged = False;
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AfterRecordingOfCounterparty" 
		AND ValueIsFilled(Parameter)
		AND Object.Counterparty = Parameter Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Parameter);
		SetContractVisible();
		
	ElsIf EventName = "PickupOnDocumentsProduced"
		AND TypeOf(Parameter) = Type("Structure")
		// Check for the form owner
		AND Source = UUID
		Then
		
		AddNewPositionsIntoTableFooter = False;
		Parameter.Property("AddNewPositionsIntoTableFooter", AddNewPositionsIntoTableFooter);
		If Not AddNewPositionsIntoTableFooter Then
			
			Object.Inventory.Clear();
			
		EndIf;
		
		InventoryAddressInStorage = "";
		Parameter.Property("InventoryAddressInStorage", InventoryAddressInStorage);
		If ValueIsFilled(InventoryAddressInStorage) 
			AND InventoryAddressInStorage <> DialogReturnCode.Cancel Then
			
			GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True, True);
			
		EndIf;
		
		Modified = True;
		
	ElsIf EventName = "RefreshTaxInvoiceText"
		AND TypeOf(Parameter) = Type("Structure")
		AND NOT Parameter.BasisDocuments.Find(Object.Ref) = Undefined Then
		
		TaxInvoiceText = Parameter.Presentation;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

// Procedure - event handler OnChange of the Company input field.
//  In procedure the document number
//  is cleared, and also the form functional options are configured.
//  Overrides the corresponding form parameter.
//
// Parameters:
//  Item - 	 - 
//
&AtClient
Procedure CompanyOnChange(Item)
	
	If OldCompany = Object.Company Then
		
		Return;
		
	Else
		
		ModeYesNo = QuestionDialogMode.YesNo;
		Notification = New NotifyDescription("CompanyOnChangeEnd", ThisObject, Parameters);
		TextQuery = NStr("en = 'You are about to change a company. 
			|If you do so, the purchase documents data will be removed from the Allocation tab. 
			|Do you want to continue?'; 
			|ru = 'Вы собираетесь сменить организацию. 
			|После этого данные закупочных документов будут удалены из вкладки Распределение. 
			|Продолжить?';
			|pl = 'Zamierzasz zmienić firmę. 
			|Jeśli to zrobisz, dane dotyczące dokumentów zakupu zostaną usunięte z karty Przydział. 
			|Czy chcesz kontynuować?';
			|es_ES = 'Usted se dispone a cambiar de empresa. 
			|Si lo hace, los datos de los documentos de compra se eliminarán de la pestaña Asignación. 
			|¿Quiere continuar?';
			|es_CO = 'Usted se dispone a cambiar de empresa. 
			|Si lo hace, los datos de los documentos de compra se eliminarán de la pestaña Asignación. 
			|¿Quiere continuar?';
			|tr = 'İş yerini değiştirmek üzeresiniz. 
			|Değişiklik yapılırsa, satın alma belgelerinin verileri Tahsis sekmesinden silinecek. 
			|Devam etmek istiyor musunuz?';
			|it = 'L''azienda sta per essere cambiata. 
			|Questo comporterà l''eliminazione dei dati dei documenti di acquisto dalla scheda Assegnazione. 
			|Continuare?';
			|de = 'Sie sind dabei, eine Firma zu wechseln. 
			|Wenn Sie dies tun, werden die Kaufdokumente aus der Registerkarte Zuteilung entfernt. 
			|Möchten Sie fortsetzen?'");
		
		ShowQueryBox(New NotifyDescription("CompanyOnChangeEnd", ThisObject), TextQuery, ModeYesNo, 0);
		
		Return;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CompanyOnChangeEnd(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.No Then
		
		Object.Company = OldCompany;
		
		Return;
		
	EndIf;
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	Object.Contract = PredefinedValue("Catalog.CounterpartyContracts.EmptyRef");
	
	For Each LineInventory In Object.Inventory Do
		
		LineInventory.ReceiptDocument = Undefined;
		
	EndDo;
	
	OldCompany = Object.Company;
	
	CompanyOnChangePart();
	
EndProcedure

&AtClient
Procedure CompanyOnChangePart()
	
	Var LabelStructure, StructureData;
	
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company, Object.Date);
	Company = StructureData.Company;
	ExchangeRateMethod = StructureData.ExchangeRateMethod;
	
	PerInvoiceVATRoundingRule = StructureData.PerInvoiceVATRoundingRule;
	RegisteredForVAT = StructureData.RegisteredForVAT;
	SetAutomaticVATCalculation();
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency", Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate", Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting", ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation", Object.VATTaxation);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	SetItemsVisibleAtServer(False);
	
	If Object.SetPaymentTerms And ValueIsFilled(Object.PaymentMethod) Then
		PaymentTermsServerCall.FillPaymentTypeAttributes(
			Object.Company, Object.CashAssetType, Object.BankAccount, Object.PettyCash);
	EndIf;

EndProcedure

// Procedure - event handler OnChange of the Counterparty input field.
// Clears the contract and tabular section.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	CounterpartyDoSettlementsByOrdersBeforeChange = CounterpartyDoSettlementsByOrders;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
		
		DataStructure = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		Object.Contract = DataStructure.Contract;
		
		DataStructure.Insert("CounterpartyBeforeChange", CounterpartyBeforeChange);
		DataStructure.Insert("CounterpartyDoSettlementsByOrdersBeforeChange", CounterpartyDoSettlementsByOrdersBeforeChange);
		
		ProcessContractChange(DataStructure);
		
		SetVisibleEnablePaymentTermItems();
		
		LabelStructure = New Structure;
		LabelStructure.Insert("DocumentCurrency", Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency", SettlementsCurrency);
		LabelStructure.Insert("ExchangeRate", Object.ExchangeRate);
		LabelStructure.Insert("RateNationalCurrency", RateNationalCurrency);
		LabelStructure.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting", ForeignExchangeAccounting);
		LabelStructure.Insert("VATTaxation", Object.VATTaxation);
		
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		Object.PurchaseOrder = Order;
		
	EndIf;
	
	Order = Object.PurchaseOrder;
	
EndProcedure

// The OnChange event handler of the Contract field.
// It updates the currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure

// Procedure - event handler StartChoice of the Contract input field.
//
&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetChoiceFormParameters(
		Object.Ref,
		Object.Company,
		Object.Counterparty,
		Object.Contract,
		CounterpartyAttributes.DoOperationsByContracts);
		
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - handler of the OnChange event of PurchaseOrder input field.
//
&AtClient
Procedure PurchaseOrderOnChange(Item)
	
	If Object.Prepayment.Count() > 0
	   AND Object.PurchaseOrder <> Order
	   AND CounterpartyDoSettlementsByOrders Then
		Mode = QuestionDialogMode.YesNo;
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("PurchaseOrderOnChangeEnd", ThisObject), NStr("en = 'Prepayment setoff will be cleared, continue?'; ru = 'Зачет аванса будет очищен, продолжить?';pl = 'Zaliczenie płatności będzie anulowane, kontynuować?';es_ES = 'Compensación del prepago se liquidará, ¿continuar?';es_CO = 'Compensación del prepago se liquidará, ¿continuar?';tr = 'Ön ödeme mahsuplaştırılması silinecek, devam mı?';it = 'Pagamento anticipato compensazione verrà cancellata, continuare?';de = 'Anzahlungsverrechnung wird gelöscht, fortsetzen?'"), Mode, 0);
		Return;
	EndIf;
	
	PurchaseOrderOnChangeFragment();
EndProcedure

&AtClient
Procedure PurchaseOrderOnChangeEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		Object.Prepayment.Clear();
	Else
		Object.PurchaseOrder = Order;
		Return;
	EndIf;
	
	PurchaseOrderOnChangeFragment();

EndProcedure

&AtClient
Procedure PurchaseOrderOnChangeFragment()
	
	Order = Object.PurchaseOrder;

EndProcedure

&AtClient
Procedure GLAccountsClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	GLAccountsInDocumentsClient.OpenCounterpartyGLAccountsForm(ThisObject, Object, "");
	
EndProcedure

// Procedure - clicking handler on the hyperlink TaxInvoiceText.
//
&AtClient
Procedure TaxInvoiceTextClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	WorkWithVATClient.OpenTaxInvoice(ThisObject, True);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtServer
Procedure OperationKindOnChangeAtServer()
	SetItemsVisibleAtServer();
EndProcedure

&AtClient
Procedure OperationKindOnChange(Item)
	OperationKindOnChangeAtServer();
EndProcedure

#Region GeneralPurposeProceduresAndFunctionsOfPaymentCalendar

&AtServer
Procedure FillPaymentCalendar(TypeListOfPaymentCalendar, IsEnabledManually = False)
	
	PaymentTermsServer.FillPaymentCalendarFromContract(Object, IsEnabledManually);
	
	TypeListOfPaymentCalendar = Number(Object.PaymentCalendar.Count() > 1);
	Modified = True;
	
EndProcedure

&AtClient
Procedure SetVisibleEnablePaymentTermItems()
	
	SetEnableGroupPaymentCalendarDetails();
	SetVisiblePaymentCalendar();
	SetVisiblePaymentMethod();
	
EndProcedure

// Procedure sets availability of the form items.
//
&AtClient
Procedure SetEnableGroupPaymentCalendarDetails()
	
	Items.GroupPaymentCalendarDetails.Enabled = Object.SetPaymentTerms;
	
EndProcedure

&AtClient
Procedure SetVisiblePaymentCalendar()
	
	If SwitchTypeListOfPaymentCalendar Then
		Items.GroupPaymentCalendarListString.CurrentPage = Items.GroupPaymentCalendarList;
	Else
		Items.GroupPaymentCalendarListString.CurrentPage = Items.GroupBillingCalendarString;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetVisiblePaymentMethod()
	
	If Object.CashAssetType = PredefinedValue("Enum.CashAssetTypes.Cash") Then
		Items.BankAccount.Visible = False;
		Items.PettyCash.Visible = True;
	ElsIf Object.CashAssetType = PredefinedValue("Enum.CashAssetTypes.Noncash") Then
		Items.BankAccount.Visible = True;
		Items.PettyCash.Visible = False;
	Else
		Items.BankAccount.Visible = False;
		Items.PettyCash.Visible = False;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function PaymentMethodCashAssetType(PaymentMethod)
	
	Return Common.ObjectAttributeValue(PaymentMethod, "CashAssetType");
	
EndFunction

&AtClient
Procedure ClearPaymentCalendarContinue(Answer, Parameters) Export
	If Answer = DialogReturnCode.Yes Then
		Object.PaymentCalendar.Clear();
		SetEnableGroupPaymentCalendarDetails();
	ElsIf Answer = DialogReturnCode.No Then
		Object.SetPaymentTerms = True;
	EndIf;
EndProcedure

&AtClient
Procedure SetEditInListEndOption(Result, AdditionalParameters) Export
	
	LineCount = AdditionalParameters.LineCount;
	
	If Result = DialogReturnCode.No Then
		SwitchTypeListOfPaymentCalendar = 1;
		Return;
	EndIf;
	
	While LineCount > 1 Do
		Object.PaymentCalendar.Delete(Object.PaymentCalendar[LineCount - 1]);
		LineCount = LineCount - 1;
	EndDo;
	Items.PaymentCalendar.CurrentRow = Object.PaymentCalendar[0].GetID();
	
	SetVisiblePaymentCalendar();

EndProcedure

&AtServer
Procedure SetSwitchTypeListOfPaymentCalendar()
	
	If Object.PaymentCalendar.Count() > 1 Then
		SwitchTypeListOfPaymentCalendar = 1;
	Else
		SwitchTypeListOfPaymentCalendar = 0;
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlersOfIncomingDocument

&AtClient
Procedure IncomingDocumentDateOnChange(Item)
	IncomingDocumentDateBeforeChange = IncomingDocumentDate;
	IncomingDocumentDate = Object.IncomingDocumentDate;
	
	If IncomingDocumentDateBeforeChange <> Object.IncomingDocumentDate
		And Object.SetPaymentTerms Then
		
		FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
		SetVisibleEnablePaymentTermItems();
		
		If ValueIsFilled(Object.Ref) Then
			MessageString = NStr("en = 'Payment terms have been changed'; ru = 'Условия оплаты изменены';pl = 'Warunki płatności zostały zmienione';es_ES = 'Se han cambiado las condiciones de pago';es_CO = 'Se han cambiado las condiciones de pago';tr = 'Ödeme şartları değiştirildi';it = 'I termini di pagamento sono stati modificati';de = 'Zahlungsbedingungen wurden geändert'");
			CommonClientServer.MessageToUser(MessageString);
		EndIf;
		
	EndIf;
EndProcedure

#EndRegion

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the result of opening the "Prices and currencies" form
//
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") And ClosingResult.WereMadeChanges Then
		
		DocCurRecalcStructure = New Structure;
		DocCurRecalcStructure.Insert("DocumentCurrency", ClosingResult.DocumentCurrency);
		DocCurRecalcStructure.Insert("Rate", ClosingResult.ExchangeRate);
		DocCurRecalcStructure.Insert("Repetition", ClosingResult.Multiplicity);
		DocCurRecalcStructure.Insert("PrevDocumentCurrency", AdditionalParameters.DocumentCurrency);
		DocCurRecalcStructure.Insert("InitRate", AdditionalParameters.ExchangeRate);
		DocCurRecalcStructure.Insert("RepetitionBeg", AdditionalParameters.Multiplicity);
		
		Object.DocumentCurrency = ClosingResult.DocumentCurrency;
		Object.ExchangeRate = ClosingResult.ExchangeRate;
		Object.Multiplicity = ClosingResult.Multiplicity;
		Object.ContractCurrencyExchangeRate = ClosingResult.SettlementsRate;
		Object.ContractCurrencyMultiplicity = ClosingResult.SettlementsMultiplicity;
		Object.VATTaxation = ClosingResult.VATTaxation;
		Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
		Object.IncludeVATInPrice = ClosingResult.IncludeVATInPrice;
		Object.AutomaticVATCalculation = ClosingResult.AutomaticVATCalculation;
		
		// Recalculate prices by currency.
		If ClosingResult.RecalculatePrices Then
			
		DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "Expenses", PricesPrecision);
			
			MessageToUser = False;
			For Each InventoryRow In Object.Inventory Do
				
				If InventoryRow.AmountExpense <> 0 Then
					InventoryRow.AmountExpense = 0;
					MessageToUser = True;
				EndIf;
				
			EndDo;
			
			If MessageToUser Then
				Message = NStr("en = 'Allocate the costs again.'; ru = 'Необходимо снова выполнить распределение затрат.';pl = 'Przydziel koszty ponownie.';es_ES = 'Asigne los costos de nuevo.';es_CO = 'Asigne los costos de nuevo.';tr = 'Maliyetleri yeniden tahsis edin.';it = 'Allocare di nuovo i costi.';de = 'Weisen Sie die Kosten erneut zu.'");
				CommonClientServer.MessageToUser(Message);
			EndIf;
			
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			
			FillVATRateByVATTaxation();
			
			If UseDefaultTypeOfAccounting Then
				
				ParametersStructure = New Structure;
				ParametersStructure.Insert("GetGLAccounts", True);
				ParametersStructure.Insert("FillHeader", True);
				ParametersStructure.Insert("FillInventory", False);
				ParametersStructure.Insert("FillExpenses", False);
				
				FillAddedColumns(ParametersStructure);
				
			EndIf;
		
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If ClosingResult.AmountIncludesVAT <> ClosingResult.PrevAmountIncludesVAT Then
			
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Expenses", PricesPrecision);
			
		EndIf;
		
		For Each TabularSectionRow In Object.Prepayment Do
			
			TabularSectionRow.AmountDocCur = DriveServer.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				ExchangeRateMethod,
				Object.ContractCurrencyExchangeRate,
				Object.ExchangeRate,
				Object.ContractCurrencyMultiplicity,
				Object.Multiplicity,
				PricesPrecision);
			
		EndDo;
		
		Modified = True;
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		
	EndIf;
	
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency", Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency", SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate", Object.ExchangeRate);
	LabelStructure.Insert("RateNationalCurrency", RateNationalCurrency);
	LabelStructure.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting", ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation", Object.VATTaxation);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	ProcessChangesOnButtonPricesAndCurrenciesEndAtServer();
	
EndProcedure

&AtServer
Procedure ProcessChangesOnButtonPricesAndCurrenciesEndAtServer()
	
	SetPrepaymentColumnsProperties();
	
EndProcedure

&AtClient
Procedure DefineTabSectionsClearEnd(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		If Object.Prepayment.Count() > 0 Then
			Object.Prepayment.Clear();
		EndIf;
		If Object.CustomsDeclaration.Count() > 0 Then
			Object.CustomsDeclaration.Clear();
		EndIf;
		HandleContractChangeProcessAndCurrenciesSettlements(AdditionalParameters);
		
	Else
		
		Object.Contract = AdditionalParameters.ContractBeforeChange;
		Contract = AdditionalParameters.ContractBeforeChange;
		
		If AdditionalParameters.Property("CounterpartyBeforeChange") Then
			
			Object.Counterparty = AdditionalParameters.CounterpartyBeforeChange;
			Counterparty = AdditionalParameters.CounterpartyBeforeChange;
			CounterpartyDoSettlementsByOrders = AdditionalParameters.CounterpartyDoSettlementsByOrdersBeforeChange;
			Items.Contract.Visible = AdditionalParameters.ContractVisibleBeforeChange;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region FormTableItemsEventHandlersExpenses

// Procedure - event handler OnChange of the any input field.
//
&AtClient
Procedure ExpensesOnChange(Item)
	
	CalculateTotal();
	
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure ExpensesProductsOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("TabName", "Expenses");
	StructureData.Insert("Object", Object);
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(ThisObject, "Expenses", StructureData);
	EndIf;
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Price = 0;
	TabularSectionRow.Amount = 0;
	TabularSectionRow.VATAmount = 0;
	TabularSectionRow.Total = 0;
	
EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure ExpensesQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Expenses");
	
EndProcedure

// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
&AtClient
Procedure ExpensesMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected
	 OR TabularSectionRow.Price = 0 Then
		Return;
	EndIf;
	
	CurrentFactor = 0;
	If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		CurrentFactor = 1;
	EndIf;
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		Factor = 1;
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		StructureData = GetDataMeasurementUnitChoiceProcessing(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitChoiceProcessing(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitChoiceProcessing(,ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
	
	CalculateAmountInTabularSectionLine("Expenses");
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure ExpensesPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Expenses");
	
EndProcedure

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure AmountExpensesOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure ExpensesVATRateOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

&AtClient
Procedure ExpensesOnStartEdit(Item, NewRow, Clone)
	
	If Not NewRow Or Clone Then
		Return;
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpensesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "ExpensesGLAccounts" Then
		StandardProcessing = False;
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Expenses");
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpensesOnActivateCell(Item)
	
	CurrentData = Items.Expenses.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Expenses.CurrentItem;
		If TableCurrentColumn.Name = "ExpensesGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.Expenses.CurrentRow;
			GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpensesOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure ExpensesGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Expenses.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure AmountExpensesVATOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersInventory

// Procedure - handler of the OnChange event of the Coefficient field of the Inventory table.
//
&AtClient
Procedure InventoryFactorOnChange(Item)
		
	VATExpenses = 0;
	If NOT Object.IncludeVATInPrice Then
		VATExpenses = Object.Expenses.Total("VATAmount");
	EndIf;	 	
	
	SrcAmount			= 0;
	DistributionBase	= Object.Inventory.Total("Factor");
	TotalExpenses		= Object.Expenses.Total("Total") - VATExpenses;
	
	For Each StringInventory In Object.Inventory Do
		StringInventory.AmountExpense = ?(DistributionBase <> 0, Round((TotalExpenses - SrcAmount) * StringInventory.Factor / DistributionBase, 2, 1),0);
		DistributionBase = DistributionBase - StringInventory.Factor;
		SrcAmount = SrcAmount + StringInventory.AmountExpense;
	EndDo;
	
EndProcedure

// Procedure - handler of the OnChange event of the ReceiptDocument attribute.
//
&AtClient
Procedure InventoryIncreaseDocumentOnChange(Item)
	
	CurrentRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("Object", Object);
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", CurrentRow.Products);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	If ValueIsFilled(CurrentRow.ReceiptDocument) Then
		StructureData.Insert("ReceiptDocument", CurrentRow.ReceiptDocument);
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(ThisObject, "Inventory", StructureData);
	EndIf;
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(CurrentRow, StructureData);
	
	If Not ValueIsFilled(CurrentRow.Factor) Then
		
		CurrentRow.Factor = 1;
		
	EndIf;
	
EndProcedure

// Procedure - handler of the OnChange event of the Products attribute.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("Object", Object);
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	If ValueIsFilled(TabularSectionRow.ReceiptDocument) Then
		StructureData.Insert("ReceiptDocument", TabularSectionRow.ReceiptDocument);
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(ThisObject, "Inventory", StructureData);
	EndIf;
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit	= StructureData.MeasurementUnit;
	TabularSectionRow.Quantity			= 1;
	TabularSectionRow.Factor			= 1;
	TabularSectionRow.Price				= 0;
	TabularSectionRow.Amount			= 0;
	TabularSectionRow.VATRate			= StructureData.VATRate;
	TabularSectionRow.VATAmount			= 0;
	TabularSectionRow.Total				= 0;
	
EndProcedure

// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
&AtClient
Procedure InventoryMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected 
	 OR TabularSectionRow.Price = 0 Then
		Return;
	EndIf;
	
	CurrentFactor = 0;
	If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		CurrentFactor = 1;
	EndIf;
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		Factor = 1;
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
	
	CalculateAmountInTabularSectionLine("Inventory");
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Inventory");
	
EndProcedure

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Inventory");
	
EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Clone)
	
	If Not NewRow Or Clone Then
		Return;
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	EndIf;
	
EndProcedure

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "InventoryGLAccounts" Then
		StandardProcessing = False;
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnActivateCell(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Inventory.CurrentItem;
		If TableCurrentColumn.Name = "InventoryGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.Inventory.CurrentRow;
			GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure InventoryGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Inventory.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
	
EndProcedure

#EndRegion 

#Region FormTableItemsEventHandlersCustomDeclaration

&AtClient
Procedure CustomsDeclarationDocumentOnChange(Item)
	
	CurrentData = Items.CustomsDeclaration.CurrentData;
	
	If Not ValueIsFilled(CurrentData.Document) Then
		
		CurrentData.Amount			= 0;
		CurrentData.IncludeToCurrentInvoice	= False;
		CurrentData.GLAccount				= Undefined;
		SetItemsVisibleAtServer();
		
	Else
		FillingStrucure = GetCustomsDeclarationData(CurrentData.Document, Object.Date);
		FillPropertyValues(CurrentData, FillingStrucure);
	EndIf;
		
EndProcedure

&AtServer
Procedure CustomsDeclarationIncludeToCurrentInvoiceOnChangeAtServer()
	SetItemsVisibleAtServer();
EndProcedure

&AtClient
Procedure CustomsDeclarationIncludeToCurrentInvoiceOnChange(Item)
	CustomsDeclarationIncludeToCurrentInvoiceOnChangeAtServer();
EndProcedure

&AtClient
Procedure CustomsDeclarationSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "CustomsDeclarationGLAccount" Then
		StandardProcessing = False;
		ShowValue( , Items.CustomsDeclaration.CurrentData.GLAccount);
	EndIf;
	
EndProcedure

&AtClient
Procedure CustomsDeclarationOnChange(Item)
	CalculateTotal();
EndProcedure

&AtClient
Procedure CustomsDeclarationAfterDeleteRow(Item)
	SetItemsVisibleAtServer();
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersPrepayment

&AtClient
Procedure PrepaymentSettlementsAmountOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	CalculatePrepaymentPaymentAmount(TabularSectionRow);
	
	TabularSectionRow.AmountDocCur = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		ExchangeRateMethod,
		Object.ContractCurrencyExchangeRate,
		Object.ExchangeRate,
		Object.ContractCurrencyMultiplicity,
		Object.Multiplicity,
		PricesPrecision);
	
EndProcedure

&AtClient
Procedure PrepaymentRateOnChange(Item)
	
	CalculatePrepaymentPaymentAmount();
	
EndProcedure

&AtClient
Procedure PrepaymentMultiplicityOnChange(Item)
	
	CalculatePrepaymentPaymentAmount();
	
EndProcedure

&AtClient
Procedure PrepaymentPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	If ExchangeRateMethod = PredefinedValue("Enum.ExchangeRateMethods.Divisor") Then
		If TabularSectionRow.PaymentAmount <> 0 Then
			TabularSectionRow.ExchangeRate = TabularSectionRow.SettlementsAmount
				* TabularSectionRow.Multiplicity
				/ TabularSectionRow.PaymentAmount;
		EndIf;
	Else
		If TabularSectionRow.SettlementsAmount <> 0 Then
			TabularSectionRow.ExchangeRate = TabularSectionRow.PaymentAmount
				/ TabularSectionRow.SettlementsAmount
				* TabularSectionRow.Multiplicity;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure PrepaymentDocumentOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	If ValueIsFilled(TabularSectionRow.Document) Then
		
		ParametersStructure = GetAdvanceExchangeRateParameters(TabularSectionRow.Document);
		
		TabularSectionRow.ExchangeRate = GetCalculatedAdvanceExchangeRate(ParametersStructure);
		
		CalculatePrepaymentPaymentAmount(TabularSectionRow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PrepaymentOnChange(Item)
	
	PrepaymentWasChanged = True;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersPaymentCalendar

// Procedure - event handler OnChange of the ReflectInPaymentCalendar input field.
//
&AtClient
Procedure SetPaymentTermsOnChange(Item)
	
	If Object.SetPaymentTerms Then
		
		FillPaymentCalendar(SwitchTypeListOfPaymentCalendar, True);
		SetVisibleEnablePaymentTermItems();
		
	Else
		
		Notify = New NotifyDescription("ClearPaymentCalendarContinue", ThisObject);
		
		QueryText = NStr("en = 'The payment terms will be cleared. Do you want to continue?'; ru = 'Условия оплаты будут очищены. Продолжить?';pl = 'Warunki płatności zostaną wyczyszczone. Czy chcesz kontynuować?';es_ES = 'Los términos de pagos se eliminarán. ¿Quiere continuar?';es_CO = 'Los términos de pagos se eliminarán. ¿Quiere continuar?';tr = 'Ödeme şartları silinecek. Devam etmek istiyor musunuz?';it = 'I termini di pagamento saranno cancellati. Continuare?';de = 'Die Zahlungsbedingungen werden gelöscht. Möchten Sie fortfahren?'");
		ShowQueryBox(Notify, QueryText,  QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field SwitchTypeListOfPaymentCalendar.
//
&AtClient
Procedure FieldSwitchTypeListOfPaymentCalendarOnChange(Item)
	
	LineCount = Object.PaymentCalendar.Count();
	
	If Not SwitchTypeListOfPaymentCalendar AND LineCount > 1 Then
		Response = Undefined;
		ShowQueryBox(
			New NotifyDescription("SetEditInListEndOption", ThisObject, New Structure("LineCount", LineCount)),
			NStr("en = 'All lines except for the first one will be deleted. Continue?'; ru = 'Все строки кроме первой будут удалены. Продолжить?';pl = 'Wszystkie wiersze za wyjątkiem pierwszego zostaną usunięte. Kontynuować?';es_ES = 'Todas las líneas a excepción de la primera se eliminarán. ¿Continuar?';es_CO = 'Todas las líneas a excepción de la primera se eliminarán. ¿Continuar?';tr = 'İlki haricinde tüm satırlar silinecek. Devam edilsin mi?';it = 'Tutte le linee eccetto la prima saranno cancellate. Continuare?';de = 'Alle Zeilen bis auf die erste werden gelöscht. Fortsetzen?'"),
			QuestionDialogMode.YesNo);
		Return;
	EndIf;
	
	SetVisiblePaymentCalendar();
	
EndProcedure

&AtClient
Procedure PaymentMethodOnChange(Item)
	Object.CashAssetType = PaymentMethodCashAssetType(Object.PaymentMethod);
	SetVisiblePaymentMethod();
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPaymentPercent input field.
//
&AtClient
Procedure PaymentCalendarPaymentPercentageOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	Total = Object.Expenses.Total("Amount") + PaymentTermsClientServer.GetCustomsDeclarationTabAmount(Object);
	
	CurrentRow.PaymentAmount = Round(Total * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount = Round(Object.Expenses.Total("VATAmount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPaymentAmount input field.
//
&AtClient
Procedure PaymentCalendarPaymentSumOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	Total = Object.Expenses.Total("Amount") + PaymentTermsClientServer.GetCustomsDeclarationTabAmount(Object);
	
	CurrentRow.PaymentPercentage = ?(Total = 0, 0, Round(CurrentRow.PaymentAmount / Total * 100, 2, 1));
	CurrentRow.PaymentVATAmount = Round(Object.Expenses.Total("VATAmount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPayVATAmount input field.
//
&AtClient
Procedure PaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	InventoryTotal = Object.Expenses.Total("VATAmount");
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentVATAmount");
	
	If PaymentCalendarTotal > InventoryTotal Then
		CurrentRow.PaymentVATAmount = CurrentRow.PaymentVATAmount - (PaymentCalendarTotal - InventoryTotal);
	EndIf;
	
EndProcedure

// Procedure - OnStartEdit event handler of the .PaymentCalendar list
//
&AtClient
Procedure PaymentCalendarOnStartEdit(Item, NewRow, Copy)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	If NewRow Then
		CurrentRow.PaymentBaselineDate = PredefinedValue("Enum.BaselineDateForPayment.InvoicePostingDate");
	EndIf;
	
	If CurrentRow.PaymentPercentage = 0 Then
		
		Total = Object.Expenses.Total("Amount") + PaymentTermsClientServer.GetCustomsDeclarationTabAmount(Object);
		
		CurrentRow.PaymentPercentage = 100 - Object.PaymentCalendar.Total("PaymentPercentage");
		CurrentRow.PaymentAmount = Total - Object.PaymentCalendar.Total("PaymentAmount");
		CurrentRow.PaymentVATAmount = Object.Expenses.Total("VATAmount") - Object.PaymentCalendar.Total("PaymentVATAmount");
	EndIf;
	
EndProcedure

// Procedure - BeforeDeletion event handler of the PaymentCalendar tabular section.
//
&AtClient
Procedure PaymentCalendarBeforeDelete(Item, Cancel)
	
	If Object.PaymentCalendar.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// Procedure is called by clicking the PricesCurrency
// button of the command bar tabular field.
//
&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies();
	Modified = True;
	
EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure DistributeExpensesByQuantity(Command)
	
	If Object.Inventory.Count() = 0 Then
		DriveClient.ShowMessageAboutError(Object, NStr("en = 'No records in tabular section ""Inventory"".'; ru = 'В табличной части ""Запасы"" нет записей!';pl = 'Brak wpisów w sekcji tabelarycznej ""Zapasy"".';es_ES = 'No hay grabaciones en la sección tabular ""Inventario"".';es_CO = 'No hay grabaciones en la sección tabular ""Inventario"".';tr = '""Stok"" tablo bölümünde kayıt yok.';it = 'Nessun record nella sezione ""Scorte"".';de = 'Keine Einträge im Tabellenteil ""Bestand"".'"));
		Return;
	EndIf;
	
	If Object.Expenses.Count() = 0 Then
		DriveClient.ShowMessageAboutError(Object, NStr("en = 'There are no records in the tabular section ""Services"".'; ru = 'В табличной части ""Услуги"" нет записей!';pl = 'Brak wpisów w sekcji tabelarycznej ""Usługi"".';es_ES = 'No hay grabaciones en la sección tabular ""Servicios"".';es_CO = 'No hay grabaciones en la sección tabular ""Servicios"".';tr = '""Hizmetler"" tablo bölümünde kayıt yok.';it = 'Non ci sono registrazioni nella sezione tabellare ""Servizi"".';de = 'Keine Einträge im Tabellenteil ""Dienstleistungen"".'"));
		Return;
	EndIf;
	
	DistributeTabSectExpensesByQuantity();
	
EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure DistributeExpensesByAmount(Command)
	
	If Object.Inventory.Count() = 0 Then
		DriveClient.ShowMessageAboutError(Object, NStr("en = 'No records in tabular section ""Inventory"".'; ru = 'В табличной части ""Запасы"" нет записей!';pl = 'Brak wpisów w sekcji tabelarycznej ""Zapasy"".';es_ES = 'No hay grabaciones en la sección tabular ""Inventario"".';es_CO = 'No hay grabaciones en la sección tabular ""Inventario"".';tr = '""Stok"" tablo bölümünde kayıt yok.';it = 'Nessun record nella sezione ""Scorte"".';de = 'Keine Einträge im Tabellenteil ""Bestand"".'"));
		Return;
	EndIf;
	
	If Object.Expenses.Count() = 0 Then
		DriveClient.ShowMessageAboutError(Object, NStr("en = 'There are no records in the tabular section ""Services"".'; ru = 'В табличной части ""Услуги"" нет записей!';pl = 'Brak wpisów w sekcji tabelarycznej ""Usługi"".';es_ES = 'No hay grabaciones en la sección tabular ""Servicios"".';es_CO = 'No hay grabaciones en la sección tabular ""Servicios"".';tr = '""Hizmetler"" tablo bölümünde kayıt yok.';it = 'Non ci sono registrazioni nella sezione tabellare ""Servizi"".';de = 'Keine Einträge im Tabellenteil ""Dienstleistungen"".'"));
		Return;
	EndIf;
	
	DistributeTabSectExpensesByAmount();
	
EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure EditPrepaymentOffset(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(, NStr("en = 'Please select a counterparty.'; ru = 'Выберите контрагента.';pl = 'Wybierz kontrahenta.';es_ES = 'Por favor, seleccione un contraparte.';es_CO = 'Por favor, seleccione un contraparte.';tr = 'Lütfen, cari hesap seçin.';it = 'Si prega di selezionare una controparte.';de = 'Bitte wählen Sie einen Geschäftspartner aus.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Contract) Then
		ShowMessageBox(, NStr("en = 'Please select a contract.'; ru = 'Выберите договор.';pl = 'Wybierz umowę.';es_ES = 'Por favor, especifique un contrato.';es_CO = 'Por favor, especifique un contrato.';tr = 'Lütfen, sözleşme seçin.';it = 'Si prega di selezionare un contratto.';de = 'Bitte wählen Sie einen Vertrag aus.'"));
		Return;
	EndIf;
	
	AddressPrepaymentInStorage = PlacePrepaymentToStorage();
	IncludedCustomsDeclarationAmount = PaymentTermsClientServer.GetCustomsDeclarationTabAmount(Object);
	
	SelectionParameters = New Structure;
	SelectionParameters.Insert("AddressPrepaymentInStorage", AddressPrepaymentInStorage);
	SelectionParameters.Insert("Pick", True);
	SelectionParameters.Insert("IsOrder", False);
	SelectionParameters.Insert("OrderInHeader", True);
	SelectionParameters.Insert("Company", Company);
	SelectionParameters.Insert("Order", ?(CounterpartyDoSettlementsByOrders, Object.PurchaseOrder, Undefined));
	SelectionParameters.Insert("Date", Object.Date);
	SelectionParameters.Insert("Ref", Object.Ref);
	SelectionParameters.Insert("Counterparty", Object.Counterparty);
	SelectionParameters.Insert("Contract", Object.Contract);
	SelectionParameters.Insert("ExchangeRate", Object.ExchangeRate);
	SelectionParameters.Insert("Multiplicity", Object.Multiplicity);
	SelectionParameters.Insert("ContractCurrencyExchangeRate", Object.ContractCurrencyExchangeRate);
	SelectionParameters.Insert("ContractCurrencyMultiplicity", Object.ContractCurrencyMultiplicity);
	SelectionParameters.Insert("DocumentCurrency", Object.DocumentCurrency);
	SelectionParameters.Insert("DocumentAmount", Object.Expenses.Total("Total") + IncludedCustomsDeclarationAmount);
	
	ReturnCode = Undefined;
	
	NotifyDescription = New NotifyDescription("EditPrepaymentOffsetEnd",
		ThisObject,
		New Structure("AddressPrepaymentInStorage", AddressPrepaymentInStorage));
	
	OpenForm("CommonForm.SelectAdvancesPaidToTheSupplier", SelectionParameters,,,,, NotifyDescription);
	
EndProcedure

&AtClient
Procedure EditPrepaymentOffsetEnd(Result, AdditionalParameters) Export
	
	AddressPrepaymentInStorage = AdditionalParameters.AddressPrepaymentInStorage;
	
	ReturnCode = Result;
	If ReturnCode = DialogReturnCode.OK Then
		GetPrepaymentFromStorage(AddressPrepaymentInStorage);
		Modified = True;
		PrepaymentWasChanged = True;
	EndIf;

EndProcedure

#EndRegion

#Region Private

#Region GeneralPurposeProceduresAndFunctions

&AtClient
// Procedure handles change process of the Contract and contract currency documents attributes
//
Procedure HandleContractChangeProcessAndCurrenciesSettlements(DocumentParameters)
	
	ContractBeforeChange = DocumentParameters.ContractBeforeChange;
	ContractData = DocumentParameters.ContractData;
	OpenFormPricesAndCurrencies = DocumentParameters.OpenFormPricesAndCurrencies;
	
	If Not ContractData.AmountIncludesVAT = Undefined Then
		
		Object.AmountIncludesVAT = ContractData.AmountIncludesVAT;
		
	EndIf;
	
	AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
		Object.DocumentCurrency,
		Object.ExchangeRate,
		Object.Multiplicity);
	
	If ValueIsFilled(Object.Contract) Then 
		
		Object.ExchangeRate = ?(ContractData.SettlementsCurrencyRateRepetition.Rate = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Rate);
		Object.Multiplicity = ?(ContractData.SettlementsCurrencyRateRepetition.Repetition = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Repetition);
		Object.ContractCurrencyExchangeRate = Object.ExchangeRate;
		Object.ContractCurrencyMultiplicity = Object.Multiplicity;
		
	EndIf;
	
	If ValueIsFilled(SettlementsCurrency) Then
		Object.DocumentCurrency = SettlementsCurrency;
	EndIf;
	
	Order = Object.PurchaseOrder;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = MessagesToUserClientServer.GetSettleCurrencyOnChangeWarningText();
		
		ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange, True, WarningText);
		
	Else
		
		LabelStructure = New Structure;
		LabelStructure.Insert("DocumentCurrency", Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency", SettlementsCurrency);
		LabelStructure.Insert("ExchangeRate", Object.ExchangeRate);
		LabelStructure.Insert("RateNationalCurrency", RateNationalCurrency);
		LabelStructure.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting", ForeignExchangeAccounting);
		LabelStructure.Insert("VATTaxation", Object.VATTaxation);
		
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
EndProcedure

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
&AtServerNoContext
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure;
	
	If CurrentMeasurementUnit = Undefined Then
		StructureData.Insert("CurrentFactor", 1);
	Else
		StructureData.Insert("CurrentFactor", CurrentMeasurementUnit.Factor);
	EndIf;
	
	If MeasurementUnit = Undefined Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", MeasurementUnit.Factor);
	EndIf;
	
	Return StructureData;
	
EndFunction

// Procedure fills the column "Payment sum", etc. Inventory.
//
&AtServer
Procedure DistributeTabSectExpensesByQuantity()
	
	Document = FormAttributeToValue("Object");
	Document.DistributeTabSectExpensesByQuantity();
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", False);
		ParametersStructure.Insert("FillHeader", False);
		ParametersStructure.Insert("FillInventory", True);
		ParametersStructure.Insert("FillExpenses", True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

// Procedure fills the column "Payment sum", etc. Inventory.
//
&AtServer
Procedure DistributeTabSectExpensesByAmount()
	
	Document = FormAttributeToValue("Object");
	Document.DistributeTabSectExpensesByAmount();
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", False);
		ParametersStructure.Insert("FillHeader", False);
		ParametersStructure.Insert("FillInventory", True);
		ParametersStructure.Insert("FillExpenses", True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ProcessDateChange()
	
	StructureData = GetDataDateOnChange();
	
	PerInvoiceVATRoundingRule = StructureData.PerInvoiceVATRoundingRule;
	RegisteredForVAT = StructureData.RegisteredForVAT;
	SetAutomaticVATCalculation();
	
	If ValueIsFilled(SettlementsCurrency) Then
		RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
	EndIf;
	
	SetItemsVisibleAtServer();
	
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency", Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency", SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate", Object.ExchangeRate);
	LabelStructure.Insert("RateNationalCurrency", RateNationalCurrency);
	LabelStructure.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting", ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation", Object.VATTaxation);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	DocumentDate = Object.Date;
	
EndProcedure

// It receives data set from server for the DateOnChange procedure.
//
&AtServer
Function GetDataDateOnChange()
	
	CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.DocumentCurrency, Company);	
	
	StructureData = New Structure;
	StructureData.Insert("CurrencyRateRepetition", CurrencyRateRepetition);
	
	If Object.DocumentCurrency <> SettlementsCurrency Then
		
		SettlementsCurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, SettlementsCurrency, Company);
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", SettlementsCurrencyRateRepetition);
		
	Else
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", CurrencyRateRepetition);
		
	EndIf;
	
	PaymentTermsServer.ShiftPaymentCalendarDates(Object, ThisObject);
	
	Policy = GetAccountingPolicyValues(Object.Date, Company);
	StructureData.Insert("PerInvoiceVATRoundingRule", Policy.PerInvoiceVATRoundingRule);
	StructureData.Insert("RegisteredForVAT", Policy.RegisteredForVAT);
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction

// Gets data set from server.
//
&AtServer
Function GetCompanyDataOnChange(Company, DocumentDate)
	
	StructureData = New Structure;
	
	StructureData.Insert("Company", DriveServer.GetCompany(Company));
	StructureData.Insert("ExchangeRateMethod", DriveServer.GetExchangeMethod(StructureData.Company));
	
	Policy = GetAccountingPolicyValues(DocumentDate, Company);
	StructureData.Insert("PerInvoiceVATRoundingRule", Policy.PerInvoiceVATRoundingRule);
	StructureData.Insert("RegisteredForVAT", Policy.RegisteredForVAT);
	
	FillVATRateByCompanyVATTaxation();
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", True);
		ParametersStructure.Insert("FillHeader", True);
		ParametersStructure.Insert("FillInventory", True);
		ParametersStructure.Insert("FillExpenses", True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataFromReceiptDocument(ReceiptDocument, Products, MeasurementUnit)
	
	Query = New Query;
		
	Query.Text =
	"SELECT ALLOWED
	|	SUM(SupplierInvoiceInventory.Quantity) AS Quantity,
	|	SUM(SupplierInvoiceInventory.Amount) AS Amount,
	|	SupplierInvoice.StructuralUnit AS StructuralUnit
	|FROM
	|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON SupplierInvoiceInventory.Ref = SupplierInvoice.Ref
	|WHERE
	|	SupplierInvoice.Ref = &Ref
	|	AND SupplierInvoiceInventory.Products = &Products
	|	AND SupplierInvoiceInventory.MeasurementUnit = &MeasurementUnit
	|
	|GROUP BY
	|	SupplierInvoiceInventory.MeasurementUnit,
	|	SupplierInvoiceInventory.VATRate,
	|	SupplierInvoice.StructuralUnit
	|
	|UNION ALL
	|
	|SELECT
	|	SUM(ExpenseReportInventory.Quantity),
	|	SUM(ExpenseReportInventory.Amount),
	|	ExpenseReportInventory.StructuralUnit
	|FROM
	|	Document.ExpenseReport.Inventory AS ExpenseReportInventory
	|WHERE
	|	ExpenseReportInventory.Ref = &Ref
	|	AND ExpenseReportInventory.Products = &Products
	|	AND ExpenseReportInventory.MeasurementUnit = &MeasurementUnit
	|
	|GROUP BY
	|	ExpenseReportInventory.MeasurementUnit,
	|	ExpenseReportInventory.VATRate,
	|	ExpenseReportInventory.StructuralUnit";
	
	Query.SetParameter("Ref", ReceiptDocument);
	Query.SetParameter("Products", Products);
	Query.SetParameter("MeasurementUnit", MeasurementUnit);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	StructureData = New Structure;
	
	If SelectionOfQueryResult.Next() Then
		StructureData.Insert("Quantity", SelectionOfQueryResult.Quantity);
		StructureData.Insert("Amount", SelectionOfQueryResult.Amount);
		StructureData.Insert("StructuralUnit", SelectionOfQueryResult.StructuralUnit);
	Else
		StructureData.Insert("Quantity", 0);
		StructureData.Insert("Amount", 0);
		StructureData.Insert("StructuralUnit", catalogs.BusinessUnits.EmptyRef());
	EndIf;
	
	Return StructureData;
	
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	ProductsAttributes = Common.ObjectAttributesValues(StructureData.Products, "MeasurementUnit, VATRate");
	
	StructureData.Insert("MeasurementUnit", ProductsAttributes.MeasurementUnit);
	
	If StructureData.Property("VATTaxation") 
	AND Not StructureData.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		If StructureData.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
		Else
			StructureData.Insert("VATRate", Catalogs.VATRates.ZeroRate);
		EndIf;
	ElsIf ValueIsFilled(StructureData.Products) And ValueIsFilled(ProductsAttributes.VATRate) Then
		StructureData.Insert("VATRate", ProductsAttributes.VATRate);
	Else
		StructureData.Insert("VATRate", InformationRegisters.AccountingPolicy.GetDefaultVATRate(, StructureData.Company));
	EndIf;
	
	If StructureData.Property("ReceiptDocument") Then
		StructureDataFromDocument = GetDataFromReceiptDocument(
			StructureData.ReceiptDocument,
			StructureData.Products,
			ProductsAttributes.MeasurementUnit);
		StructureData.Insert("StructuralUnit", StructureDataFromDocument.StructuralUnit);
	EndIf;
	
	If StructureData.UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	Return StructureData;
	
EndFunction

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
&AtServerNoContext
Function GetDataMeasurementUnitChoiceProcessing(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure;
	
	If CurrentMeasurementUnit = Undefined Then
		StructureData.Insert("CurrentFactor", 1);
	Else
		StructureData.Insert("CurrentFactor", CurrentMeasurementUnit.Factor);
	EndIf;
	
	If MeasurementUnit = Undefined Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", MeasurementUnit.Factor);
	EndIf;
	
	Return StructureData;
	
EndFunction

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	FillVATRateByCompanyVATTaxation(True);
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", True);
		ParametersStructure.Insert("FillHeader", True);
		ParametersStructure.Insert("FillInventory", False);
		ParametersStructure.Insert("FillExpenses", False);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"Contract",
		ContractByDefault
	);
		
	StructureData.Insert(
		"SettlementsCurrency",
		ContractByDefault.SettlementsCurrency
	);
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		CurrencyRateOperations.GetCurrencyRate(Date, ContractByDefault.SettlementsCurrency, Company)
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(ContractByDefault.PriceKind), Contract.PriceKind.PriceIncludesVAT, Undefined)
	);
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetDataContractOnChange(Date, DocumentCurrency, Contract)
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", True);
		ParametersStructure.Insert("FillHeader", True);
		ParametersStructure.Insert("FillInventory", False);
		ParametersStructure.Insert("FillExpenses", False);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
	StructureData = New Structure;
	StructureData.Insert("SettlementsCurrency", Contract.SettlementsCurrency);
	StructureData.Insert("SettlementsCurrencyRateRepetition", CurrencyRateOperations.GetCurrencyRate(Date, Contract.SettlementsCurrency, Object.Company));
	PriceKind = Common.ObjectAttributeValue(Contract, "PriceKind");
	StructureData.Insert("AmountIncludesVAT",
							?(ValueIsFilled(PriceKind), Common.ObjectAttributeValue(PriceKind, "PriceIncludesVAT"), Undefined));
	Return StructureData;
	
EndFunction

&AtServer
Procedure FillVATRateByCompanyVATTaxation(IsCounterpartyOnChange = False)
	
	If Not WorkWithVAT.VATTaxationTypeIsValid(Object.VATTaxation, RegisteredForVAT, True)
		Or Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT 
		Or IsCounterpartyOnChange Then
		
		TaxationBeforeChange = Object.VATTaxation;
		
		Object.VATTaxation = DriveServer.CounterpartyVATTaxation(Object.Counterparty,
			DriveServer.VATTaxation(Object.Company, Object.Date),
			True);
		
		If Not TaxationBeforeChange = Object.VATTaxation Then
			FillVATRateByVATTaxation();
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
&AtServer
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.PaymentCalendarPaymentVATAmount.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
		
		For Each TabularSectionRow In Object.Inventory Do
			
			If ValueIsFilled(TabularSectionRow.Products.VATRate) Then
				TabularSectionRow.VATRate = TabularSectionRow.Products.VATRate;
			Else
				TabularSectionRow.VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
			EndIf;	
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  		TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  		TabularSectionRow.Amount * VATRate / 100);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;	
		
		Items.ExpencesVATRate.Visible = True;
		Items.ExpencesAmountVAT.Visible = True;
		Items.TotalExpences.Visible = True;
		Items.DocumentTax.Visible = True;
		
		For Each TabularSectionRow In Object.Expenses Do
			
			If ValueIsFilled(TabularSectionRow.Products.VATRate) Then
				TabularSectionRow.VATRate = TabularSectionRow.Products.VATRate;
			Else
				TabularSectionRow.VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
			EndIf;	
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  		TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  		TabularSectionRow.Amount * VATRate / 100);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
	Else
		
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.PaymentCalendarPaymentVATAmount.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then	
			DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;
		
		For Each TabularSectionRow In Object.Inventory Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;
		
		Items.ExpencesVATRate.Visible = False;
		Items.ExpencesAmountVAT.Visible = False;
		Items.TotalExpences.Visible = False;
		Items.DocumentTax.Visible = False;
		
		For Each TabularSectionRow In Object.Expenses Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;
		
	EndIf;	
	
EndProcedure

// VAT amount is calculated in the row of tabular section.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(
		Object.AmountIncludesVAT,
		TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
		TabularSectionRow.Amount * VATRate / 100
	);
	
EndProcedure

// Procedure calculates the amount in the row of tabular section.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionName = "Inventory", TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items[TabularSectionName].CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

// Recalculates the exchange rate and multiplicity of
// the payment currency when the document date is changed.
//
&AtClient
Procedure RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData)
	
	CurrencyRateRepetition = StructureData.CurrencyRateRepetition;
	SettlementsCurrencyRateRepetition = StructureData.SettlementsCurrencyRateRepetition;
	
	NewExchangeRate = ?(CurrencyRateRepetition.Rate = 0, 1, CurrencyRateRepetition.Rate);
	NewRatio = ?(CurrencyRateRepetition.Repetition = 0, 1, CurrencyRateRepetition.Repetition);
	
	NewContractCurrencyExchangeRate = ?(SettlementsCurrencyRateRepetition.Rate = 0,
		1,
		SettlementsCurrencyRateRepetition.Rate);
		
	NewContractCurrencyRatio = ?(SettlementsCurrencyRateRepetition.Repetition = 0,
		1,
		SettlementsCurrencyRateRepetition.Repetition);
	
	If Object.ExchangeRate <> NewExchangeRate
		OR Object.Multiplicity <> NewRatio
		OR Object.ContractCurrencyExchangeRate <> NewContractCurrencyExchangeRate
		OR Object.ContractCurrencyMultiplicity <> NewContractCurrencyRatio Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("NewExchangeRate",					NewExchangeRate);
		AdditionalParameters.Insert("NewRatio",							NewRatio);
		AdditionalParameters.Insert("NewContractCurrencyExchangeRate",	NewContractCurrencyExchangeRate);
		AdditionalParameters.Insert("NewContractCurrencyRatio",			NewContractCurrencyRatio);
		
		MessageText = MessagesToUserClientServer.GetApplyRatesOnNewDateQuestionText();
		
		NotifyDescription = New NotifyDescription("RecalculatePaymentCurrencyRateConversionFactorEnd",
			ThisObject,
			AdditionalParameters);
		
		ShowQueryBox(NotifyDescription, MessageText, QuestionDialogMode.YesNo);
		
		Return;
		
	EndIf;
	
	// Generate price and currency label.
	RecalculatePaymentCurrencyRateConversionFactorFragment();
	
EndProcedure

&AtClient
Procedure RecalculatePaymentCurrencyRateConversionFactorEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		Object.ContractCurrencyExchangeRate = AdditionalParameters.NewContractCurrencyExchangeRate;
		Object.ContractCurrencyMultiplicity = AdditionalParameters.NewContractCurrencyRatio;
		
		For Each TabularSectionRow In Object.Prepayment Do
			TabularSectionRow.AmountDocCur = DriveServer.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				ExchangeRateMethod,
				Object.ContractCurrencyExchangeRate,
				Object.ExchangeRate,
				Object.ContractCurrencyMultiplicity,
				Object.Multiplicity,
				PricesPrecision);
		EndDo;
		
	EndIf;
	
	RecalculatePaymentCurrencyRateConversionFactorFragment();
	
EndProcedure

&AtClient
Procedure RecalculatePaymentCurrencyRateConversionFactorFragment()
	
	Var LabelStructure;
	
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency", Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency", SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate", Object.ExchangeRate);
	LabelStructure.Insert("RateNationalCurrency", RateNationalCurrency);
	LabelStructure.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting", ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation", Object.VATTaxation);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

// Procedure recalculates in the document tabular section after making
// changes in the "Prices and currency" form. The columns are
// recalculated as follows: price, discount, amount, VAT amount, total amount.
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange = Undefined, RecalculatePrices = False, WarningText = "")
	
	If AttributesBeforeChange = Undefined Then
		AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
			Object.DocumentCurrency,
			Object.ExchangeRate,
			Object.Multiplicity);
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",					Object.Multiplicity);
	ParametersStructure.Insert("VATTaxation",					Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice",				Object.IncludeVATInPrice);
	ParametersStructure.Insert("Counterparty",					Object.Counterparty);
	ParametersStructure.Insert("Contract",						Object.Contract);
	ParametersStructure.Insert("ContractCurrencyExchangeRate",	Object.ContractCurrencyExchangeRate);
	ParametersStructure.Insert("ContractCurrencyMultiplicity",	Object.ContractCurrencyMultiplicity);
	ParametersStructure.Insert("Company",						Company);
	ParametersStructure.Insert("DocumentDate",					Object.Date);
	ParametersStructure.Insert("RefillPrices",					False);
	ParametersStructure.Insert("RecalculatePrices",				RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",				False);
	ParametersStructure.Insert("WarningText",					WarningText);
	ParametersStructure.Insert("ReverseChargeNotApplicable",	True);
	ParametersStructure.Insert("AutomaticVATCalculation",		Object.AutomaticVATCalculation);
	ParametersStructure.Insert("PerInvoiceVATRoundingRule",		PerInvoiceVATRoundingRule);
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, AttributesBeforeChange);
	
	OpenForm("CommonForm.PricesAndCurrency",
		ParametersStructure, ThisForm,,,,
		NotifyDescription,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure sets the contract visible depending on the parameter set to the counterparty.
//
&AtServer
Procedure SetContractVisible()
	
	CounterpartyDoSettlementsByOrders = CounterpartyAttributes.DoOperationsByOrders;
	Items.Contract.Visible = CounterpartyAttributes.DoOperationsByContracts;
	
EndProcedure

// Checks the match of the "Company" and "ContractKind" contract attributes to the terms of the document.
//
&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(MessageText, Contract, Document, Company, Counterparty, Cancel, IsOperationsByContracts)
	
	If Not DriveReUse.CounterpartyContractsControlNeeded()
		OR Not IsOperationsByContracts Then
		
		Return;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	ContractKindsList = ManagerOfCatalog.GetContractTypesListForDocument(Document);
	
	If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, Contract, Company, Counterparty, ContractKindsList)
		AND Constants.CheckContractsOnPosting.Get() Then
		
		Cancel = True;
	EndIf;
	
EndProcedure

// It gets counterparty contract selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormParameters(Document, Company, Counterparty, Contract, IsOperationsByContracts)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Document);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", IsOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

// Gets the default contract depending on the billing details.
//
&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company);
	
EndFunction

// Performs actions when counterparty contract is changed.
//
&AtClient
Procedure ProcessContractChange(ContractData = Undefined)
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		DocumentParameters = New Structure;
		If ContractData = Undefined Then
			
			ContractData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
			
		Else
			
			DocumentParameters.Insert("CounterpartyBeforeChange", ContractData.CounterpartyBeforeChange);
			DocumentParameters.Insert("CounterpartyDoSettlementsByOrdersBeforeChange", ContractData.CounterpartyDoSettlementsByOrdersBeforeChange);
			DocumentParameters.Insert("ContractVisibleBeforeChange", Items.Contract.Visible);
			
		EndIf;
		
		SettlementsCurrency = ContractData.SettlementsCurrency;
		
		OpenFormPricesAndCurrencies = ValueIsFilled(Object.Contract)
			AND ValueIsFilled(SettlementsCurrency)
			AND Object.DocumentCurrency <> ContractData.SettlementsCurrency
			AND (Object.Inventory.Count() > 0 OR Object.Expenses.Count() > 0);
		
		DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
		DocumentParameters.Insert("ContractData", ContractData);
		DocumentParameters.Insert("OpenFormPricesAndCurrencies", OpenFormPricesAndCurrencies);
		
		If Object.Prepayment.Count() > 0 Or Object.CustomsDeclaration.Count() > 0 Then
			
			QuestionText = "";
			
			If Object.Prepayment.Count() > 0 Then
				QuestionText = NStr("en = 'The advance set-off will be canceled.'; ru = 'Зачет аванса будет отменен.';pl = 'Rozliczenie zaliczki zostało anulowane.';es_ES = 'Se cancelará la compensación del anticipo.';es_CO = 'Se cancelará la compensación del anticipo.';tr = 'Avans mahsubu iptal edilecek.';it = 'L''anticipo sarà annullato.';de = 'Die Vorauszahlungsaufrechnung wird aufgehoben.'");
			EndIf;
			
			If Object.CustomsDeclaration.Count() > 0 Then
				QuestionText = QuestionText
					+ ?(IsBlankString(QuestionText), "", " ")
					+ NStr("en = 'The Customs declaration tab will be cleared.'; ru = 'Вкладка ""Таможенная декларация"" будет очищена.';pl = 'Karta Deklaracja celna została anulowana.';es_ES = 'La pestaña Declaración de la aduana se eliminará.';es_CO = 'La pestaña Declaración de la aduana se eliminará.';tr = 'Gümrük beyannamesi sekmesi temizlenecek.';it = 'La scheda della Dichiarazione doganale sarà cancellata.';de = 'Die Tabelle Zollanmeldung wird gelöscht.'");
			EndIf;
			
			QuestionText = QuestionText + " " + NStr("en = 'Do you want to continue?'; ru = 'Продолжить?';pl = 'Czy chcesz kontynuować?';es_ES = '¿Quiere continuar?';es_CO = '¿Quiere continuar?';tr = 'Devam etmek istiyor musunuz?';it = 'Continuare?';de = 'Möchten Sie fortfahren?'");
			NotifyDescription = New NotifyDescription("DefineTabSectionsClearEnd", ThisObject, DocumentParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		Else
			
			HandleContractChangeProcessAndCurrenciesSettlements(DocumentParameters);
			
		EndIf;
		
		FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
		SetVisibleEnablePaymentTermItems();
		
	Else
		
		Object.PurchaseOrder = Order;
		
	EndIf;
	
	Order = Object.PurchaseOrder;
	
EndProcedure

&AtClientAtServerNoContext
Procedure AddGLAccountsToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("ProductGLAccounts",		True);
	StructureData.Insert("GLAccounts",				TabRow.GLAccounts);
	StructureData.Insert("GLAccountsFilled",		TabRow.GLAccountsFilled);
	
	If StructureData.TabName = "Inventory" Then
		StructureData.Insert("InventoryGLAccount",	TabRow.InventoryGLAccount);
		StructureData.Insert("GoodsInvoicedNotDeliveredGLAccount",	TabRow.GoodsInvoicedNotDeliveredGLAccount);
		StructureData.Insert("AdvanceInvoicing",	DriveServerCall.AdvanceInvoicing(TabRow.ReceiptDocument));
	ElsIf StructureData.TabName = "Expenses" Then
		StructureData.Insert("VATInputGLAccount",	TabRow.VATInputGLAccount);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(ParametersStructure)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	StructureArray = New Array();
	
	If ParametersStructure.FillHeader Then
		
		Header = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "Header", Object);
		GLAccountsInDocuments.CompleteCounterpartyStructureData(Header, ObjectParameters, "Header");
		
		StructureArray.Add(Header);
		
	EndIf;
	
	If ParametersStructure.FillInventory Then
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters);
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters);
		
		StructureArray.Add(StructureData);
		
	EndIf;
	
	If ParametersStructure.FillExpenses Then
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "Expenses");
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, "Expenses");
		
		StructureArray.Add(StructureData);
		
	EndIf;
	
	FillAdvanceInvoicing();
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, ParametersStructure.GetGLAccounts);
	
	If ParametersStructure.FillHeader Then
		GLAccounts = Header.GLAccounts;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAdvanceInvoicing()
	
	ValuesCache = New Map;
	
	SetPrivilegedMode(True);
	
	For Each InvRow In Object.Inventory Do
		CachedValue = ValuesCache.Get(InvRow.ReceiptDocument);
		If CachedValue = Undefined Then
			InvRow.AdvanceInvoicing = DriveServerCall.AdvanceInvoicing(InvRow.ReceiptDocument);
			ValuesCache.Insert(InvRow.ReceiptDocument, InvRow.AdvanceInvoicing);
		Else
			InvRow.AdvanceInvoicing = CachedValue;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure SetPrepaymentColumnsProperties()
	
	Items.PrepaymentSettlementsAmount.Title =
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Clearing amount (%1)'; ru = 'Сумма зачета (%1)';pl = 'Kwota rozliczenia (%1)';es_ES = 'Importe de liquidaciones (%1)';es_CO = 'Importe de liquidaciones (%1)';tr = 'Mahsup edilen tutar (%1)';it = 'Importo di compensazione (%1)';de = 'Ausgleichsbetrag (%1)'"),
			SettlementsCurrency);
	
	If Object.DocumentCurrency = SettlementsCurrency Then
		Items.PrepaymentAmountDocCur.Visible = False;
	Else
		Items.PrepaymentAmountDocCur.Visible = True;
		Items.PrepaymentAmountDocCur.Title =
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Amount (%1)'; ru = 'Сумма (%1)';pl = 'Wartość (%1)';es_ES = 'Importe (%1)';es_CO = 'Cantidad (%1)';tr = 'Tutar (%1)';it = 'Importo (%1)';de = 'Betrag (%1)'"),
				Object.DocumentCurrency);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetAccountingPolicyValues(Date, Company)
	
	RegisterPolicy = InformationRegisters.AccountingPolicy;
	Policy = RegisterPolicy.GetAccountingPolicy(Date, Company);
	
	Return Policy;
	
EndFunction

&AtClient
Procedure SetAutomaticVATCalculation()
	
	Object.AutomaticVATCalculation = PerInvoiceVATRoundingRule;
	
EndProcedure

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.InventoryPrice);
	Fields.Add(Items.ExpencesPrice);
	
	Return Fields;
	
EndFunction

&AtServer
Procedure SetItemsVisibleAtServer(FillOnlyEmptyVATNumber = True)
	
	Items.TaxInvoiceText.Visible = WorkWithVAT.GetUseTaxInvoiceForPostingVAT(Object.Date, Object.Company);
	LandedCostsFromBroker = (Object.OperationKind = Enums.OperationTypesAdditionalExpenses.LandedCostsFromCustomsBroker);
	Items.GroupCustomDeclaration.Visible = LandedCostsFromBroker;
	
	FilterSrtucture = New Structure("IncludeToCurrentInvoice", True);
	Items.CustomsDeclarationGLAccount.Visible = UseDefaultTypeOfAccounting
		And Object.CustomsDeclaration.FindRows(FilterSrtucture).Count();
	
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmptyVATNumber);
	
	Items.GLAccounts.Visible = UseDefaultTypeOfAccounting;
	
EndProcedure

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val CatalogCounterparty)
	
	Attributes = "DoOperationsByContracts, DoOperationsByOrders, VATTaxation";
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, CatalogCounterparty, Attributes);
	
EndProcedure

#Region WorkWithTheSelection

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure ExpensesPick(Command)
	
	TabularSectionName	= "Expenses";
	DocumentPresentaion	= NStr("en = 'landed costs'; ru = 'дополнительные расходы';pl = 'koszty z wyładunkiem';es_ES = 'costes de entrega';es_CO = 'costes de entrega';tr = 'varış yeri maliyetleri';it = 'costi di scarico';de = 'Wareneinstandspreise'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, False, False, False);
	SelectionParameters.Insert("Company", Company);
	NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseSelection", ThisObject);
	OpenForm("DataProcessor.ProductsSelection.Form.MainForm",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure - handler of the Action event of the PickByDocuments command
//
&AtClient
Procedure InventoryPickByDocuments(Command)
	
	TabularSectionName	= "Inventory";
	AreCharacteristics	= True;
	AreBatches			= True;
	PickupByDocuments	= True;
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period",				Object.Date);
	SelectionParameters.Insert("Company",				Company);
	SelectionParameters.Insert("Counterparty",			Counterparty);
	SelectionParameters.Insert("VATTaxation",			Object.VATTaxation);
	SelectionParameters.Insert("AmountIncludesVAT",		Object.AmountIncludesVAT);
	SelectionParameters.Insert("DocumentOrganization",	Object.Company);
	
	ProductsType = New ValueList;
	For Each ArrayElement In Items[TabularSectionName + "Products"].ChoiceParameters Do
		If ArrayElement.Name = "Filter.ProductsType" Then
			If TypeOf(ArrayElement.Value) = Type("FixedArray") Then
				For Each FixArrayItem In ArrayElement.Value Do
					ProductsType.Add(FixArrayItem);
				EndDo; 
			Else
				ProductsType.Add(ArrayElement.Value);
			EndIf;
		EndIf;
	EndDo;
	SelectionParameters.Insert("ProductsType", ProductsType);
	
	BatchStatus = New ValueList;
	For Each ArrayElement In Items[TabularSectionName + "Batch"].ChoiceParameters Do
		If ArrayElement.Name = "Filter.Status" Then
			If TypeOf(ArrayElement.Value) = Type("FixedArray") Then
				For Each FixArrayItem In ArrayElement.Value Do
					BatchStatus.Add(FixArrayItem);
				EndDo; 
			Else
				BatchStatus.Add(ArrayElement.Value);
			EndIf;
		EndIf;
	EndDo;
	
	SelectionParameters.Insert("BatchStatus", BatchStatus);
	SelectionParameters.Insert("OwnerFormUUID", UUID);
	OpenForm("Document.AdditionalExpenses.Form.PickFormByDocuments", SelectionParameters);
	
EndProcedure

// Procedure gets the list of goods from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then 
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInRow(ObjectParameters, NewRow, TabularSectionName);
		
		If UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, TabularSectionName);
		EndIf;
		
	EndDo;
	
EndProcedure

// Function places the list of advances into temporary storage and returns the address
//
&AtServer
Function PlacePrepaymentToStorage()
	
	Return PutToTempStorage(
		Object.Prepayment.Unload(,
			"Document,
			|SettlementsAmount,
			|AmountDocCur,
			|ExchangeRate,
			|Multiplicity,
			|PaymentAmount"),
		UUID
	);
	
EndFunction

// Function gets the list of advances from the temporary storage
//
&AtServer
Procedure GetPrepaymentFromStorage(AddressPrepaymentInStorage)
	
	TableForImport = GetFromTempStorage(AddressPrepaymentInStorage);
	Object.Prepayment.Load(TableForImport);
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			
			GetInventoryFromStorage(InventoryAddressInStorage, "Expenses", False, False);
			
			ExpensesOnChange(Undefined);
			Modified = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure
#EndRegion

#EndRegion

#Region Internal

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Object);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Object, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure

// End StandardSubsystems.AttachableCommands

#EndRegion

#Region CopyPasteRows

&AtClient
Procedure CopyRows(Command)
	CopyRowsTabularPart("Expenses");
EndProcedure

&AtClient
Procedure CopyRowsTabularPart(TabularPartName)
	
	If TabularPartCopyClient.CanCopyRows(Object[TabularPartName],Items[TabularPartName].CurrentData) Then
		CountOfCopied = 0;
		CopyRowsTabularPartAtSever(TabularPartName, CountOfCopied);
		TabularPartCopyClient.NotifyUserCopyRows(CountOfCopied);
	EndIf;
	
EndProcedure

&AtServer
Procedure CopyRowsTabularPartAtSever(TabularPartName, CountOfCopied)
	
	TabularPartCopyServer.Copy(Object[TabularPartName], Items[TabularPartName].SelectedRows, CountOfCopied);
	
EndProcedure

&AtClient
Procedure PasteRows(Command)
	
	PasteRowsTabularPart("Expenses");
	
EndProcedure

&AtClient
Procedure PasteRowsTabularPart(TabularPartName)
	
	CountOfCopied = 0;
	CountOfPasted = 0;
	PasteRowsTabularPartAtServer(TabularPartName, CountOfCopied, CountOfPasted);
	ProcessPastedRows(TabularPartName, CountOfPasted);
	TabularPartCopyClient.NotifyUserPasteRows(CountOfCopied, CountOfPasted);
	
EndProcedure

&AtServer
Procedure PasteRowsTabularPartAtServer(TabularPartName, CountOfCopied, CountOfPasted)
	
	TabularPartCopyServer.Paste(Object, TabularPartName, Items, CountOfCopied, CountOfPasted);
	ProcessPastedRowsAtServer(TabularPartName, CountOfPasted);
	
EndProcedure

&AtClient
Procedure ProcessPastedRows(TabularPartName, CountOfPasted)
	
	Count = Object[TabularPartName].Count();
	
	For Iterator = 1 To CountOfPasted Do
		
		Row = Object[TabularPartName][Count - Iterator];
		CalculateAmountInTabularSectionLine("Expenses",Row);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure ProcessPastedRowsAtServer(TabularPartName, CountOfPasted)
	
	Count = Object[TabularPartName].Count();
	
	For iterator = 1 To CountOfPasted Do
		
		Row = Object[TabularPartName][Count - iterator];
		
		StructureData = New Structure;
		StructureData.Insert("Company", Object.Company);
		StructureData.Insert("Products", Row.Products);
		StructureData.Insert("VATTaxation", Object.VATTaxation);
		StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
		StructureData.Insert("TabName", "Expenses");
		
		AddGLAccountsToStructure(ThisObject, TabularPartName, StructureData, Row);
		StructureData = GetDataProductsOnChange(StructureData);
		
		If Not ValueIsFilled(Row.MeasurementUnit) Then
			Row.MeasurementUnit = StructureData.MeasurementUnit;
		EndIf;
		
		Row.VATRate = StructureData.VATRate;
		
	EndDo;
	
EndProcedure

#EndRegion

&AtServer
Function GetCustomsDeclarationData(CustomsDeclaration, Period)
	
	FillingStructure = New Structure;
	FillingStructure.Insert("Amount");
	
	If UseDefaultTypeOfAccounting Then
		FillingStructure.Insert("GLAccount");
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CustomsDeclaration.Ref AS Document,
	|	CustomsDeclaration.Counterparty AS Counterparty,
	|	CustomsDeclaration.Contract AS Contract,
	|	CustomsDeclaration.Company AS Company,
	|	CustomsDeclaration.DocumentCurrency AS PresentationCurrency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	CustomsDeclaration.AccountsPayableGLAccount AS AccountsPayableGLAccount
	|INTO CustomsDeclaration
	|FROM
	|	Document.CustomsDeclaration AS CustomsDeclaration
	|WHERE
	|	CustomsDeclaration.Ref = &CustomsDeclaration
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(AccountsPayableBalance.AmountBalance, 0) AS Amount,
	|	CustomsDeclaration.AccountsPayableGLAccount AS GLAccount
	|FROM
	|	CustomsDeclaration AS CustomsDeclaration
	|		LEFT JOIN AccumulationRegister.AccountsPayable.Balance(
	|				,
	|				(Company, Counterparty, Contract, Document, PresentationCurrency, SettlementsType) IN
	|					(SELECT
	|						CustomsDeclaration.Company AS Company,
	|						CustomsDeclaration.Counterparty AS Counterparty,
	|						CustomsDeclaration.Contract AS Contract,
	|						CustomsDeclaration.Document AS Document,
	|						CustomsDeclaration.PresentationCurrency AS PresentationCurrency,
	|						CustomsDeclaration.SettlementsType AS SettlementsType
	|					FROM
	|						CustomsDeclaration AS CustomsDeclaration)) AS AccountsPayableBalance
	|		ON (TRUE)";
	
	Query.SetParameter("CustomsDeclaration", CustomsDeclaration);

	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		FillPropertyValues(FillingStructure, Selection);
	EndIf;
	
	Return FillingStructure;
	
EndFunction

&AtClient
Procedure CalculateTotal()
	
	AmountTotal = Object.Expenses.Total("Total") + PaymentTermsClientServer.GetCustomsDeclarationTabAmount(Object);
	VATAmountTotal = Object.Expenses.Total("VATAmount");
	
	Object.DocumentTax = VATAmountTotal;
	Object.DocumentSubtotal = AmountTotal - VATAmountTotal;
	Object.DocumentAmount = AmountTotal;
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

&AtClient
Procedure CustomsDeclarationTaxesAndDutiesOnChange(Item)
	CalculateTotal();
EndProcedure

#EndRegion

&AtClient
Procedure CalculatePrepaymentPaymentAmount(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Prepayment.CurrentData;
	EndIf;
	
	TabularSectionRow.ExchangeRate = ?(TabularSectionRow.ExchangeRate = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		ExchangeRateMethod,
		TabularSectionRow.ExchangeRate,
		1,
		TabularSectionRow.Multiplicity,
		1,
		PricesPrecision);
	
EndProcedure

&AtClient
Function GetAdvanceExchangeRateParameters(DocumentParam)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Ref", Object.Ref);
	ParametersStructure.Insert("Company", Company);
	ParametersStructure.Insert("Counterparty", Object.Counterparty);
	ParametersStructure.Insert("Contract", Object.Contract);
	ParametersStructure.Insert("Document", DocumentParam);
	ParametersStructure.Insert("Order", Undefined);
	ParametersStructure.Insert("Period", EndOfDay(Object.Date) + 1);
	
	Return ParametersStructure;
	
EndFunction

&AtServerNoContext
Function GetCalculatedAdvanceExchangeRate(ParametersStructure)
	
	Return DriveServer.GetCalculatedAdvancePaidExchangeRate(ParametersStructure);
	
EndFunction

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion