
#Region Variables

&AtClient
Var LineCopyInventory;

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillInventory", True);
	
	FillAddedColumns(ParametersStructure);
	
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
		And ValueIsFilled(Object.Counterparty)
		And Not ValueIsFilled(Parameters.CopyingValue) Then
		
		If Not ValueIsFilled(Object.Contract) Then
			Object.Contract = DriveServer.GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
		EndIf;
		
		If ValueIsFilled(Object.Contract) Then
			Object.DocumentCurrency = Object.Contract.SettlementsCurrency;
			SettlementsCurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.DocumentCurrency, Object.Company);
			Object.ExchangeRate      = ?(SettlementsCurrencyRateRepetition.Rate = 0, 1, SettlementsCurrencyRateRepetition.Rate);
			Object.Multiplicity = ?(SettlementsCurrencyRateRepetition.Repetition = 0, 1, SettlementsCurrencyRateRepetition.Repetition);
			Object.PriceKind = Object.Contract.PriceKind;
			
			If Object.PaymentCalendar.Count() = 0 Then
				FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
			EndIf;
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	Counterparty = Object.Counterparty;
	Contract = Object.Contract;
	SettlementsCurrency = Object.Contract.SettlementsCurrency;
	FunctionalCurrency = Constants.FunctionalCurrency.Get();
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Object.Date, FunctionalCurrency, Object.Company);
	RateNationalCurrency = StructureByCurrency.Rate;
	RepetitionNationalCurrency = StructureByCurrency.Repetition;
	ExchangeRateMethod = DriveServer.GetExchangeMethod(ParentCompany);
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	
	SetPrepaymentColumnsProperties();
	
	RegisterPolicy = InformationRegisters.AccountingPolicy;
	Policy = RegisterPolicy.GetAccountingPolicy(Object.Date, ParentCompany);
	Object.VATCommissionFeePercent = RegisterPolicy.DefaultVATRateFromAccountingPolicy(Policy);
	PerInvoiceVATRoundingRule = Policy.PerInvoiceVATRoundingRule;
	RegisteredForVAT = Policy.RegisteredForVAT;
	
	If Not ValueIsFilled(Object.Ref)
		And Not ValueIsFilled(Parameters.Basis) 
		And Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.InventoryVATAmountTransfer.Visible = True;
		Items.InventoryTotalAmountOfVAT.Visible = True;
		Items.PaymentVATAmount.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
	Else
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.InventoryVATAmountTransfer.Visible = False;
		Items.InventoryTotalAmountOfVAT.Visible = False;
		Items.PaymentVATAmount.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
	EndIf;
	
	// Generate price and currency label.
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	LabelStructure = New Structure("PriceKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	ProcessingCompanyVATNumbers();
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillInventory", True);
	
	FillAddedColumns(ParametersStructure);
	
	Items.GLAccounts.Visible = UseDefaultTypeOfAccounting;
	Items.InventoryGLAccounts.Visible = UseDefaultTypeOfAccounting;
	
	// Setting contract visible.
	SetContractVisible();
	
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance);
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.InventoryPriceOfTransfer.ReadOnly 	   = Not AllowedEditDocumentPrices;
	Items.InventorySumOfTransfers.ReadOnly    = Not AllowedEditDocumentPrices;
	Items.InventoryVATAmountTransfer.ReadOnly = Not AllowedEditDocumentPrices;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// Peripherals
	UsePeripherals = DriveReUse.UsePeripherals();
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList("ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
	SwitchTypeListOfPaymentCalendar = ?(Object.PaymentCalendar.Count() > 1, 1, 0);
	
	DriveServer.CheckObjectGeneratedEnteringBalances(ThisObject);
	
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
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillInventory", True);
	
	FillAddedColumns(ParametersStructure);
	
	SetSwitchTypeListOfPaymentCalendar();
	
EndProcedure

// Procedure - event handler BeforeWriteAtServer form.
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
			Message.Text = ?(Cancel, NStr("en = 'Cannot post the account sales.'; ru = 'Отчет о продаже товаров на комиссии не проведен.';pl = 'Nie można zatwierdzić raportu sprzedaży.';es_ES = 'No se puede enviar las ventas de cuentas.';es_CO = 'No se puede enviar las ventas de cuentas.';tr = 'Hesap satışları gönderilemiyor.';it = 'Non è possibile pubblicare le vendite in conto vendita.';de = 'Fehler beim Buchen des Verkaufsberichts. '") + " " + MessageText, MessageText);
			
			If Cancel Then
				Message.DataPath = "Object";
				Message.Field = "Contract";
				Message.Message();
				Return;
			Else
				Message.Message();
			EndIf;
			
		EndIf;
		
		If DriveReUse.GetAdvanceOffsettingSettingValue() = Enums.YesNo.Yes
			AND CurrentObject.Prepayment.Count() = 0 Then
			FillPrepayment(CurrentObject);
		EndIf;
		
	EndIf;
	
	AmountsHaveChanged = WorkWithVAT.CalculateVATPerInvoiceTotal(CurrentObject);
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

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("NotificationAboutChangingDebt");
	Notify("RefreshAccountingTransaction");
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	SetVisibleAndEnabled();
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisObject, "BarCodeScanner");
	// End Peripherals
	
	SetVisibleEnablePaymentTermItems();
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	RecalculateSubtotal();
	
EndProcedure

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisObject);
	// End Peripherals
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() Then
	   If EventName = "ScanData" Then
			TabularSectionName = "Customers";
			If DriveClient.BeforeAddToSubordinateTabularSection(ThisObject, "Inventory") Then
				Return;
			EndIf;
			// Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1)); // Get a barcode from the additional data
			EndIf;
			BarcodesReceived(Data);
		EndIf;
	EndIf;
	// End Peripherals
	
	If EventName = "AfterRecordingOfCounterparty" 
		AND ValueIsFilled(Parameter)
		AND Object.Counterparty = Parameter Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Parameter);
		SetContractVisible();
		
	ElsIf EventName = "SerialNumbersSelection"
		AND ValueIsFilled(Parameter) 
		// Form owner checkup
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
		
		ChangedCount = GetSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		If ChangedCount Then
			CalculateAmountInTabularSectionLine();
			RecalculateSubtotal();
		EndIf; 	
	EndIf;
	
EndProcedure

// Procedure - event handler ChoiceProcessing.
//
&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ChoiceSource.FormName = "Document.AccountSalesFromConsignee.Form.PickFormByBalances" Then
		GetStockTransferredToThirdPartiesFromStorage(ValueSelected);
	ElsIf GLAccountsInDocumentsClient.IsGLAccountsChoiceProcessing(ChoiceSource.FormName) Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, ValueSelected);
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, ValueSelected);
	EndIf;
	
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
		
		ParametersStructure = GetAdvanceExchangeRateParameters(TabularSectionRow.Document, TabularSectionRow.Order);
		
		TabularSectionRow.ExchangeRate = GetCalculatedAdvanceExchangeRate(ParametersStructure);
		
		CalculatePrepaymentPaymentAmount(TabularSectionRow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PrepaymentOrderOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	If ValueIsFilled(TabularSectionRow.Document) And ValueIsFilled(TabularSectionRow.Order) Then
		
		ParametersStructure = GetAdvanceExchangeRateParameters(TabularSectionRow.Document, TabularSectionRow.Order);
		
		TabularSectionRow.ExchangeRate = GetCalculatedAdvanceExchangeRate(ParametersStructure);
		
		CalculatePrepaymentPaymentAmount(TabularSectionRow);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

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

&AtClient
// The procedure handles the change of the Price type and Settlement currency document
// attributes
Procedure ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters)
	
	ContractBeforeChange = DocumentParameters.ContractBeforeChange;
	ContractData = DocumentParameters.ContractData;
	QueryPriceKind = DocumentParameters.QueryPriceKind;
	OpenFormPricesAndCurrencies = DocumentParameters.OpenFormPricesAndCurrencies;
	PriceKindChanged = DocumentParameters.PriceKindChanged;
	RecalculationRequired = DocumentParameters.RecalculationRequired;
	
	If Not ContractData.AmountIncludesVAT = Undefined Then
		
		Object.AmountIncludesVAT = ContractData.AmountIncludesVAT;
		
	EndIf;
	
	AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
		Object.DocumentCurrency,
		Object.ExchangeRate,
		Object.Multiplicity);
	
	If ValueIsFilled(Object.Contract) Then 
		
		Object.ExchangeRate      = ?(ContractData.SettlementsCurrencyRateRepetition.Rate = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Rate);
		Object.Multiplicity = ?(ContractData.SettlementsCurrencyRateRepetition.Repetition = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Repetition);
		Object.ContractCurrencyExchangeRate = Object.ExchangeRate;
		Object.ContractCurrencyMultiplicity = Object.Multiplicity;
		
	EndIf;
	
	If PriceKindChanged Then
		
		Object.PriceKind = ContractData.PriceKind;
		
	EndIf;
	
	If ValueIsFilled(SettlementsCurrency) Then
		Object.DocumentCurrency = SettlementsCurrency;
	EndIf;
	
	GenerateLabelPricesAndCurrency();
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		If QueryPriceKind AND RecalculationRequired Then
			
			WarningText = MessagesToUserClientServer.GetPriceTypeOnChangeWarningText(False);
			
		EndIf;
		
		WarningText = WarningText
			+ ?(IsBlankString(WarningText), "", Chars.LF + Chars.LF)
			+ MessagesToUserClientServer.GetSettleCurrencyOnChangeWarningText();
		
		ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange, True, QueryPriceKind, WarningText);
		
	ElsIf QueryPriceKind Then
		
		If RecalculationRequired Then
			
			QuestionText = NStr("en = 'The counterparty contract allows for the kind of prices other than prescribed in the document. 
			                    |Recalculate the document according to the contract?'; 
			                    |ru = 'Договор с контрагентом предусматривает вид цен, отличный от установленного в документе. 
			                    |Пересчитать документ в соответствии с договором?';
			                    |pl = 'Rodzaj cen w kontrakcie z kontrahentem różni się od ustawionego w dokumencie! 
			                    |Przeliczyć dokument zgodnie z kontraktem?';
			                    |es_ES = 'El contrato de la contraparte permite para el tipo de precios distinto al pre-inscrito en el documento.
			                    |¿Recalcular el documento según el contrato?';
			                    |es_CO = 'El contrato de la contraparte permite para el tipo de precios distinto al pre-inscrito en el documento.
			                    |¿Recalcular el documento según el contrato?';
			                    |tr = 'Cari hesap sözleşmesi, belgede belirtilenler dışındaki fiyatlara izin verir. 
			                    |Belgeyi sözleşmeye göre yeniden hesaplayın?';
			                    |it = 'Il contratto della controparte permette tipologie di prezzi diverse da quelle definite nel documento.
			                    |Ricalcolare il documento secondo il contratto.';
			                    |de = 'Der Geschäftspartnervertrag sieht andere als die im Dokument vorgeschriebenen Preise vor.
			                    |Das Dokument gemäß dem Vertrag neu berechnen?'");
				
			NotifyDescription = New NotifyDescription("DefineDocumentRecalculateNeedByContractTerms", ThisObject, DocumentParameters);
			
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ProcessDateChange()
	
	StructureData = GetDataDateOnChange();
	
	If ValueIsFilled(SettlementsCurrency) Then
		RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
	EndIf;
	
	GenerateLabelPricesAndCurrency();
	
	DocumentDate = Object.Date;
	
EndProcedure

// It receives data set from server for the DateOnChange procedure.
//
&AtServer
Function GetDataDateOnChange()
	
	CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.DocumentCurrency, Object.Company);
	
	StructureData = New Structure;
	StructureData.Insert("CurrencyRateRepetition", CurrencyRateRepetition);
	
	If Object.DocumentCurrency <> SettlementsCurrency Then
		
		SettlementsCurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, SettlementsCurrency, Object.Company);
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", SettlementsCurrencyRateRepetition);
		
	Else
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", CurrencyRateRepetition);
		
	EndIf;
	
	PaymentTermsServer.ShiftPaymentCalendarDates(Object, ThisObject);
	ProcessingCompanyVATNumbers();
	
	RegisterPolicy = InformationRegisters.AccountingPolicy;
	Policy = RegisterPolicy.GetAccountingPolicy(Object.Date, ParentCompany);
	PerInvoiceVATRoundingRule = Policy.PerInvoiceVATRoundingRule;
	RegisteredForVAT = Policy.RegisteredForVAT;
		
	FillVATRateByCompanyVATTaxation();
	
	SetAutomaticVATCalculation();
	
	Return StructureData;
	
EndFunction

// Receives the data set from the server for the CompanyOnChange procedure.
//
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure();
	
	StructureData.Insert("Company", DriveServer.GetCompany(Object.Company));
	
	RegisterPolicy = InformationRegisters.AccountingPolicy;
	Policy = RegisterPolicy.GetAccountingPolicy(Object.Date, StructureData.Company);
	
	StructureData.Insert("VATRate", RegisterPolicy.DefaultVATRateFromAccountingPolicy(Policy));
	StructureData.Insert("ExchangeRateMethod", DriveServer.GetExchangeMethod(Object.Company));
	
	PerInvoiceVATRoundingRule = Policy.PerInvoiceVATRoundingRule;
	SetAutomaticVATCalculation();
	
	RegisteredForVAT = Policy.RegisteredForVAT;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillInventory", True);
	
	FillAddedColumns(ParametersStructure);
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure SetAutomaticVATCalculation()
	Object.AutomaticVATCalculation = PerInvoiceVATRoundingRule;
EndProcedure

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
	
	If StructureData.Property("PriceKind") Then
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
	Else
		StructureData.Insert("Price", 0);
	EndIf;
	
	IncomeAndExpenseItemsInDocuments.FillProductIncomeAndExpenseItems(StructureData);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
	EndIf;
	
	Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
	StructureData.Insert("Price", Price);
	
	Return StructureData;
	
EndFunction

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
&AtServerNoContext
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure();
	
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

// It receives data set from server for the ContractOnChange procedure.
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
		
		FillAddedColumns(ParametersStructure);
	
	EndIf;
	
	StructureData = New Structure();
	
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
		"PriceKind",
		ContractByDefault.PriceKind
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(ContractByDefault.PriceKind), ContractByDefault.PriceKind.PriceIncludesVAT, Undefined)
	);
	
	StructureData.Insert(
		"SalesRep",
		Common.ObjectAttributeValue(Counterparty, "SalesRep"));
	
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
		
		FillAddedColumns(ParametersStructure);
	
	EndIf;
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"SettlementsCurrency",
		Contract.SettlementsCurrency
	);
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		CurrencyRateOperations.GetCurrencyRate(Date, Contract.SettlementsCurrency, Object.Company)
	);
	
	StructureData.Insert(
		"PriceKind",
		Contract.PriceKind
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(Contract.PriceKind), Contract.PriceKind.PriceIncludesVAT, Undefined)
	);
	
	Return StructureData;
	
EndFunction

// Procedure fills VAT Rate in tabular section
// by company taxation system.
// 
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
		Items.InventoryVATAmountTransfer.Visible = True;
		Items.PaymentVATAmount.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
		Items.InventoryTotalAmountOfVAT.Visible = True;
		
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
											
			TabularSectionRow.TransmissionVATAmount = ?(Object.AmountIncludesVAT,
													TabularSectionRow.TransmissionAmount - (TabularSectionRow.TransmissionAmount) / ((VATRate + 100) / 100),
													TabularSectionRow.TransmissionAmount * VATRate / 100);
								                    											
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;	
		
	Else
		
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.InventoryVATAmountTransfer.Visible = False;
		Items.PaymentVATAmount.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
		Items.InventoryTotalAmountOfVAT.Visible = False;
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
		    DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;	
		
		For Each TabularSectionRow In Object.Inventory Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			TabularSectionRow.TransmissionVATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;	
		
	EndIf;	
	
EndProcedure

// VAT amount is calculated in the row of tabular section.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  TabularSectionRow.Amount * VATRate / 100);
	
EndProcedure

// Procedure calculates the amount in the row of tabular section.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Serial numbers
	If UseSerialNumbersBalance <> Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow,, "ConnectionKeySerialNumbers");
	EndIf;
	
EndProcedure

// Calculates the brokerage in the row of the document tabular section
//
// Parameters:
//  TabularSectionRow - String of the document
// tabular section,
&AtClient
Procedure CalculateCommissionRemuneration(TabularSectionRow)
	
	If Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating") Then
	
	ElsIf Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.PercentFromSaleAmount") Then
		TabularSectionRow.BrokerageAmount = Object.CommissionFeePercent * TabularSectionRow.Amount / 100;
	ElsIf Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.PercentFromDifferenceOfSaleAndAmountReceipts") Then
		TabularSectionRow.BrokerageAmount = Object.CommissionFeePercent * (TabularSectionRow.Amount - TabularSectionRow.TransmissionAmount) / 100;
	Else
		TabularSectionRow.BrokerageAmount = 0;
	EndIf;
	
	VATRate = DriveReUse.GetVATRateValue(Object.VATCommissionFeePercent);
	
	TabularSectionRow.BrokerageVATAmount = ?(Object.AmountIncludesVAT,
													TabularSectionRow.BrokerageAmount - (TabularSectionRow.BrokerageAmount) / ((VATRate + 100) / 100),
													TabularSectionRow.BrokerageAmount * VATRate / 100);
													
	// Serial numbers
	If UseSerialNumbersBalance<>Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow, ,"ConnectionKeySerialNumbers");
	EndIf;
	
EndProcedure

// Recalculates the exchange rate and multiplicity of
// the payment currency when the document date is changed.
//
&AtClient
Procedure RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData)
	
	CurrencyRateRepetition = StructureData.CurrencyRateRepetition;
	SettlementsCurrencyRateRepetition = StructureData.SettlementsCurrencyRateRepetition;
	
	NewExchangeRate	= ?(CurrencyRateRepetition.Rate = 0, 1, CurrencyRateRepetition.Rate);
	NewRatio		= ?(CurrencyRateRepetition.Repetition = 0, 1, CurrencyRateRepetition.Repetition);
	
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
		
		QuestionText = MessagesToUserClientServer.GetApplyRatesOnNewDateQuestionText();
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("NewExchangeRate",					NewExchangeRate);
		AdditionalParameters.Insert("NewRatio",							NewRatio);
		AdditionalParameters.Insert("NewContractCurrencyExchangeRate",	NewContractCurrencyExchangeRate);
		AdditionalParameters.Insert("NewContractCurrencyRatio",			NewContractCurrencyRatio);
		
		NotifyDescription = New NotifyDescription("DefineNewExchangeRateettingNeed", ThisObject, AdditionalParameters);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

// Procedure executes recalculate in the document tabular section
// after changes in "Prices and currency" form.Column recalculation is executed:
// price, discount, amount, VAT amount, total.
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange = Undefined, RecalculatePrices = False, RefillPrices = False, WarningText = "")
	
	If AttributesBeforeChange = Undefined Then
		AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
			Object.DocumentCurrency,
			Object.ExchangeRate,
			Object.Multiplicity);
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("PriceKind",							Object.PriceKind);
	ParametersStructure.Insert("DocumentCurrency",					Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate",						Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",						Object.Multiplicity);
	ParametersStructure.Insert("VATTaxation",						Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",					Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice",					Object.IncludeVATInPrice);
	ParametersStructure.Insert("Counterparty",						Object.Counterparty);
	ParametersStructure.Insert("Contract",							Object.Contract);
	ParametersStructure.Insert("ContractCurrencyExchangeRate",		Object.ContractCurrencyExchangeRate);
	ParametersStructure.Insert("ContractCurrencyMultiplicity",		Object.ContractCurrencyMultiplicity);
	ParametersStructure.Insert("Company",							ParentCompany);
	ParametersStructure.Insert("DocumentDate",						Object.Date);
	ParametersStructure.Insert("RefillPrices",						RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",					RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",					False);
	ParametersStructure.Insert("WarningText",						WarningText);
	ParametersStructure.Insert("ReverseChargeNotApplicable",		True);
	ParametersStructure.Insert("AutomaticVATCalculation",			Object.AutomaticVATCalculation);
	ParametersStructure.Insert("PerInvoiceVATRoundingRule",			PerInvoiceVATRoundingRule);
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd",
		ThisObject,
		AttributesBeforeChange);
	
	OpenForm("CommonForm.PricesAndCurrency",
		ParametersStructure,
		ThisObject,,,,
		NotifyDescription,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Column value Total PM is being calculated Customers on client.
//
&AtClient
Procedure CalculateColumnTotalAtClient(RowCustomers)
	
	FilterParameters = New Structure;
	FilterParameters.Insert("ConnectionKey", RowCustomers.ConnectionKey);
	SearchResult = Object.Inventory.FindRows(FilterParameters);
	If SearchResult.Count() = 0 Then
		RowCustomers.Total = 0;
	Else
		TotalAmount = 0;
		For Each TSRow In SearchResult Do
			TotalAmount = TotalAmount + TSRow.Total;
		EndDo;
		RowCustomers.Total = TotalAmount;
	EndIf;
	
EndProcedure

// Update the column value Total PM Customers on client.
//
&AtClient
Procedure UpdateColumnTotalAtClient(UpdateAllRows = False)
	
	CurrentRowCustomers = Items.Customers.CurrentData;
	If CurrentRowCustomers = Undefined Then
		Return;
	EndIf;
	
	If UpdateAllRows Then
		
		For Each RowCustomers In Object.Customers Do
			
			CalculateColumnTotalAtClient(RowCustomers);
			
		EndDo;
		
	Else
		
		CalculateColumnTotalAtClient(CurrentRowCustomers);
		
	EndIf;
	
EndProcedure

// Peripherals
// Procedure gets data by barcodes.
//
&AtServerNoContext
Procedure GetDataByBarCodes(StructureData)
	
	// Transform weight barcodes.
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		InformationRegisters.Barcodes.ConvertWeightBarcode(CurBarcode);
		
	EndDo;
	
	DataByBarCodes = InformationRegisters.Barcodes.GetDataByBarCodes(StructureData.BarcodesArray);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		BarcodeData = DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
			And BarcodeData.Count() <> 0 Then
			
			StructureProductsData = CreateGeneralAttributeValuesStructure(StructureData, "Inventory", BarcodeData);
			
			If ValueIsFilled(StructureData.PriceKind) Then
				StructureProductsData.Insert("ProcessingDate", StructureData.Date);
				StructureProductsData.Insert("DocumentCurrency", StructureData.DocumentCurrency);
				StructureProductsData.Insert("AmountIncludesVAT", StructureData.AmountIncludesVAT);
				StructureProductsData.Insert("PriceKind", StructureData.PriceKind);
				If ValueIsFilled(BarcodeData.MeasurementUnit)
					And TypeOf(BarcodeData.MeasurementUnit) = Type("CatalogRef.UOM") Then
					StructureProductsData.Insert("Factor", BarcodeData.MeasurementUnit.Factor);
				Else
					StructureProductsData.Insert("Factor", 1);
				EndIf;
			EndIf;
			
			IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInBarcodeData(
				StructureProductsData, StructureData.Object, "AccountSalesFromConsignee");
			
			If StructureData.UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillGLAccountsInBarcodeData(
					StructureProductsData, StructureData.Object, "AccountSalesFromConsignee");
			EndIf;
			
			BarcodeData.Insert("StructureProductsData", GetDataProductsOnChange(StructureProductsData));
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit  = BarcodeData.Products.MeasurementUnit;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure

&AtClient
Function FillByBarcodesData(BarcodesData)
	
	UnknownBarcodes = New Array;
	
	If TypeOf(BarcodesData) = Type("Array") Then
		BarcodesArray = BarcodesData;
	Else
		BarcodesArray = New Array;
		BarcodesArray.Add(BarcodesData);
	EndIf;
	
	StructureData = New Structure();
	StructureData.Insert("BarcodesArray", BarcodesArray);
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("PriceKind", Object.PriceKind);
	StructureData.Insert("Date", Object.Date);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("Object", Object);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	GetDataByBarCodes(StructureData);
	
	CurrentConnectionKey = Items.Inventory.RowFilter["ConnectionKey"];
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object.Inventory.FindRows(New Structure("Products,Characteristic,Batch,MeasurementUnit,ConnectionKey",BarcodeData.Products,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit,CurrentConnectionKey));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				FillPropertyValues(NewRow, BarcodeData.StructureProductsData);
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Price = BarcodeData.StructureProductsData.Price;
				NewRow.VATRate = BarcodeData.StructureProductsData.VATRate;
				NewRow.ConnectionKey = CurrentConnectionKey;
				CalculateAmountInTabularSectionLine(NewRow);
				CalculateCommissionRemuneration(NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine(NewRow);
				CalculateCommissionRemuneration(NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			EndIf;
			
			If BarcodeData.Property("SerialNumber") AND ValueIsFilled(BarcodeData.SerialNumber) Then
				WorkWithSerialNumbersClientServer.AddSerialNumberToString(NewRow, BarcodeData.SerialNumber, Object, "ConnectionKeySerialNumbers");
			EndIf;
		EndIf;
	EndDo;
	
	Return UnknownBarcodes;
	
EndFunction

// Procedure processes the received barcodes.
//
&AtClient
Procedure BarcodesReceived(BarcodesData)
	
	Modified = True;
	
	UnknownBarcodes = FillByBarcodesData(BarcodesData);
	
	ReturnParameters = Undefined;
	
	If UnknownBarcodes.Count() > 0 Then
		
		Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisObject, UnknownBarcodes);
		
		OpenForm(
			"InformationRegister.Barcodes.Form.BarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisObject,,,,Notification
		);
		
		Return;
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedEnd(ReturnParameters, Parameters) Export
	
	UnknownBarcodes = Parameters;
	
	If ReturnParameters <> Undefined Then
		
		BarcodesArray = New Array;
		
		For Each ArrayElement In ReturnParameters.RegisteredBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		For Each ArrayElement In ReturnParameters.ReceivedNewBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		UnknownBarcodes = FillByBarcodesData(BarcodesArray);
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedFragment(UnknownBarcodes) Export
	
	For Each CurUndefinedBarcode In UnknownBarcodes Do
		
		MessageString = NStr("en = 'Barcode data is not found: %1%; quantity: %2%'; ru = 'Данные по штрихкоду не найдены: %1%; количество: %2%';pl = 'Nie znaleziono danych kodu kreskowego: %1%; ilość: %2%';es_ES = 'Datos del código de barras no encontrados: %1%; cantidad: %2%';es_CO = 'Datos del código de barras no encontrados: %1%; cantidad: %2%';tr = 'Barkod verisi bulunamadı: %1%; miktar: %2%';it = 'Il codice a barre non è stato trovato: %1%; quantità: %2%';de = 'Barcode-Daten wurden nicht gefunden: %1%; Menge: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

// End Peripherals

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
			
		EndIf;
		
		QueryBoxPrepayment = Object.Prepayment.Count() > 0;
		
		PriceKindChanged = Object.PriceKind <> ContractData.PriceKind AND ValueIsFilled(ContractData.PriceKind);
		QueryPriceKind = ValueIsFilled(Object.Contract) AND PriceKindChanged;
		
		SettlementsCurrency = ContractData.SettlementsCurrency;
		
		RecalculationRequired = (Object.Inventory.Count() > 0);
		
		OpenFormPricesAndCurrencies = ValueIsFilled(Object.Contract)
			AND ValueIsFilled(SettlementsCurrency)
			AND Object.DocumentCurrency <> ContractData.SettlementsCurrency
			AND Object.Inventory.Count() > 0;
		
		DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
		DocumentParameters.Insert("ContractData", ContractData);
		DocumentParameters.Insert("RecalculationRequired", RecalculationRequired);
		DocumentParameters.Insert("PriceKindChanged", PriceKindChanged);
		DocumentParameters.Insert("QueryBoxPrepayment", QueryBoxPrepayment);
		DocumentParameters.Insert("QueryPriceKind", QueryPriceKind);
		DocumentParameters.Insert("OpenFormPricesAndCurrencies", OpenFormPricesAndCurrencies);
		DocumentParameters.Insert("ContractVisibleBeforeChange", Items.Contract.Visible);
		
		If QueryBoxPrepayment Then
			
			QuestionText = NStr("en = 'The prepayment recognition will be cleared. Do you want to continue?'; ru = 'Зачет аванса будет очищен, продолжить?';pl = 'Uznanie przedpłaty zostanie oczyszczone. Czy chcesz kontynuować?';es_ES = 'El reconocimiento de prepago se eliminará. ¿Quiere continuar?';es_CO = 'El reconocimiento de prepago se eliminará. ¿Quiere continuar?';tr = 'Ön ödeme tanıması temizlenecektir. Devam etmek istiyor musunuz?';it = 'Il riconoscimento prepagamento sarà annullato. Volete proseguire?';de = 'Die Anzahlungserkennung wird ausgeglichen. Wollen Sie fortfahren?'");
			
			NotifyDescription = New NotifyDescription("DefineAdvancePaymentOffsetsRefreshNeed", ThisObject, DocumentParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		Else
			
			ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters);
			
		EndIf;
		
		FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
		SetVisibleEnablePaymentTermItems();
		SetPrepaymentColumnsProperties();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

#Region WorkWithSelection 

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Customers";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisObject, "Inventory");
	If Cancel Then
		Return;
	EndIf;
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'account sales from consignee'; ru = 'Отчет комиссионера';pl = 'Raport sprzedaży od komisanta';es_ES = 'Informe de ventas de los destinatarios';es_CO = 'ventas de cuenta del destinatario';tr = 'konsinye satışlar';it = 'saldo delle vendite dall''agente in conto vendita';de = 'verkaufsbericht (kommissionär)'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, True, False);
	SelectionParameters.Insert("Company", ParentCompany);
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

// Procedure - event handler Action of the command pick by balances.
//
&AtClient
Procedure SelectionByBalances(Command)
	
	TabularSectionName = "Customers";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisObject, "Inventory");
	
	If Not ValueIsFilled(Object.Company) Then
		MessageText = NStr("en = 'Please specify the consignor.'; ru = 'Поле ""Комитент"" не заполнено.';pl = 'Wybierz komitenta.';es_ES = 'Por favor, especifique el remitente.';es_CO = 'Por favor, especifique el remitente.';tr = 'Lütfen yük gönderenini belirleyin.';it = 'Si prega di specificare il committente.';de = 'Bitte geben Sie den Kommittenten an.'");
		DriveClient.ShowMessageAboutError(ThisObject, MessageText,,, "Company", Cancel);
	EndIf;
	If Not ValueIsFilled(Object.Counterparty) Then
		MessageText = NStr("en = 'Please specify the consignee.'; ru = 'Поле ""Контрагент"" не заполнено';pl = 'Wybierz komisanta.';es_ES = 'Por favor, especifique el destinatario.';es_CO = 'Por favor, especifique el destinatario.';tr = 'Lütfen müşteri belirleyin.';it = 'Si prega di specificare l''agente in conto vendita.';de = 'Bitte geben Sie den Kommissionär an.'");
		DriveClient.ShowMessageAboutError(ThisObject, MessageText,,, "Counterparty", Cancel);
	EndIf;
	If Not ValueIsFilled(Object.Contract) Then
		MessageText = NStr("en = 'Please specify the contract.'; ru = 'Поле ""Договор"" не заполнено';pl = 'Określ umowę.';es_ES = 'Por favor, especifique el contrato.';es_CO = 'Por favor, especifique el contrato.';tr = 'Lütfen, sözleşmeyi belirtin.';it = 'Per piacere specificate il contratto.';de = 'Bitte geben Sie den Vertrag an.'");
		DriveClient.ShowMessageAboutError(ThisObject, MessageText,,, "Contract", Cancel);
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	TabularSectionName = "Inventory";
	
	SelectionParameters = New Structure("Company,
		|Counterparty,
		|Contract,
		|DocumentCurrency,
		|DocumentDate",
		ParentCompany,
		Object.Counterparty,
		Object.Contract,
		Object.DocumentCurrency,
		Object.Date
	);
	
	OpenForm("Document.AccountSalesFromConsignee.Form.PickFormByBalances", SelectionParameters, ThisObject);
	
	FilterStr = New FixedStructure("ConnectionKey", Items[TabularSectionName].RowFilter["ConnectionKey"]);
	Items[TabularSectionName].RowFilter = FilterStr;
	
EndProcedure

// Function gets a product list from the temporary storage
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
		
		NewRow.TransmissionPrice = NewRow.Price;
		NewRow.TransmissionAmount = NewRow.Amount;
		NewRow.TransmissionVATAmount = NewRow.VATAmount;
		
		NewRow.ConnectionKey = Items[TabularSectionName].RowFilter["ConnectionKey"];
		
		IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInRow(ObjectParameters, NewRow, TabularSectionName);
		
		If UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, TabularSectionName);
		EndIf;
		
	EndDo;
	
EndProcedure

// Function receives the inventory list transferred from the temporary storage
//
&AtServer
Procedure GetStockTransferredToThirdPartiesFromStorage(AddressStockTransferredToThirdPartiesInStorage)
	
	StockTransferredToThirdParties = GetFromTempStorage(AddressStockTransferredToThirdPartiesInStorage);
	
	For Each TabularSectionRow In StockTransferredToThirdParties Do
		
		NewRow = Object.Inventory.Add();
		FillPropertyValues(NewRow, TabularSectionRow);
		
		StructureData = CreateGeneralAttributeValuesStructure(ThisObject, "Inventory", NewRow);
		
		If UseDefaultTypeOfAccounting Then
			AddGLAccountsToStructure(StructureData, ThisObject, "Inventory", NewRow);
		EndIf;
		
		StructureData = GetDataProductsOnChange(StructureData);
		
		FillPropertyValues(NewRow, StructureData); 
		NewRow.MeasurementUnit = StructureData.MeasurementUnit;
		NewRow.VATRate = StructureData.VATRate;
		
		If TabularSectionRow.Quantity > TabularSectionRow.Balance
			Or TabularSectionRow.Quantity = 0
			Or TabularSectionRow.SettlementsAmount = 0 Then
			NewRow.TransmissionAmount = 0;
		ElsIf TabularSectionRow.Quantity = TabularSectionRow.Balance Then
			NewRow.TransmissionAmount = TabularSectionRow.SettlementsAmount;
		Else
			NewRow.TransmissionAmount = Round(TabularSectionRow.SettlementsAmount / TabularSectionRow.Balance * TabularSectionRow.Quantity,2,0);
		EndIf;
		
		NewRow.TransmissionPrice = NewRow.TransmissionAmount / NewRow.Quantity;
		
		VATRate = DriveReUse.GetVATRateValue(NewRow.VATRate);
		NewRow.TransmissionVATAmount = ?(Object.AmountIncludesVAT,
										NewRow.TransmissionAmount - (NewRow.TransmissionAmount) / ((VATRate + 100) / 100),
										NewRow.TransmissionAmount * VATRate / 100);
		
		NewRow.ConnectionKey = Items[TabularSectionName].RowFilter["ConnectionKey"];
		
	EndDo;
	
EndProcedure

// Function places the list of advances into temporary storage and returns the address
//
&AtServer
Function PlacePrepaymentToStorage()
	
	Return PutToTempStorage(
		Object.Prepayment.Unload(,
			"Document,
			|Order,
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
			TabularSectionName	= "Inventory";
		
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, False);
			
			FilterStr = New FixedStructure("ConnectionKey", Items[TabularSectionName].RowFilter["ConnectionKey"]);
			Items[TabularSectionName].RowFilter = FilterStr;
			
			UpdateColumnTotalAtClient();
			RecalculateSubtotal();
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseVariantsSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If ClosingResult.WereMadeChanges And Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			AreCharacteristics 			= True;
			
			AreBatches			= False;
			
			TabularSectionName	= "Inventory";
			
			// Clear inventory
			Filter = New Structure;
			Filter.Insert("Products", ClosingResult.FilterProducts);
			
			RowsToDelete = Object[TabularSectionName].FindRows(Filter);
			For Each RowToDelete In RowsToDelete Do
				WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, RowToDelete,, UseSerialNumbersBalance);
				Object[TabularSectionName].Delete(RowToDelete);
			EndDo;
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches);
			
			RowsToRecalculate = Object[TabularSectionName].FindRows(Filter);
			For Each RowToRecalculate In RowsToRecalculate Do
				CalculateAmountInTabularSectionLine(RowToRecalculate);
			EndDo;
			
			FilterStr = New FixedStructure("ConnectionKey", Items[TabularSectionName].RowFilter["ConnectionKey"]);
			Items[TabularSectionName].RowFilter = FilterStr;
			
			UpdateColumnTotalAtClient();
			RecalculateSubtotal();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ControlOfTheFormAppearance

// Procedure sets availability of the form items.
//
&AtClient
Procedure SetVisibleAndEnabled()
	
	If Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating") Then
		Object.CommissionFeePercent = 0;
		Items.CommissionFeePercent.Enabled = False;
	Else
		Items.CommissionFeePercent.Enabled = True;
	EndIf;
	
	SetVisiblePaymentCalendar();
	
EndProcedure

&AtClient
Procedure SetVisiblePaymentCalendar()
	
	If SwitchTypeListOfPaymentCalendar Then
		Items.PagesPaymentCalendar.CurrentPage = Items.PagePaymentCalendarAsList;
	Else
		Items.PagesPaymentCalendar.CurrentPage = Items.PagePaymentCalendarWithoutSplitting;
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure is called by clicking the PricesCurrency button of the command bar tabular field.
//
&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies();
	Modified = True;
	
EndProcedure

// Procedure is called when clicking the "AddCounterpartyToCustomers" button
//
&AtClient
Procedure AddCounterpartyToCustomers(Command)
	
	If ValueIsFilled(Object.Counterparty) Then
		
		NewRow = Object.Customers.Add();
		NewRow.Customer = Object.Counterparty;
		
		TabularSectionName = "Customers";
		NewRow.ConnectionKey = DriveClient.CreateNewLinkKey(ThisObject);
		DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "Inventory");
		
		Items.Customers.CurrentRow = NewRow.GetID();
		
	Else
		MessagesToUserClient.ShowMessageSelectConsignee();
	EndIf;
	
EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure EditPrepaymentOffset(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(, NStr("en = 'Please select a consignee.'; ru = 'Выберите комиссионера.';pl = 'Wybierz komisanta.';es_ES = 'Por favor, seleccione un destinatario.';es_CO = 'Por favor, seleccione un destinatario.';tr = 'Lütfen mal alıcısını seçin.';it = 'Si prega di selezionare un agente conto vendita.';de = 'Bitte wählen Sie einen Kommissionär aus.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Contract) Then
		ShowMessageBox(, NStr("en = 'Please select a contract.'; ru = 'Выберите договор.';pl = 'Wybierz umowę.';es_ES = 'Por favor, especifique un contrato.';es_CO = 'Por favor, especifique un contrato.';tr = 'Lütfen, sözleşme seçin.';it = 'Si prega di selezionare un contratto.';de = 'Bitte wählen Sie einen Vertrag aus.'"));
		Return;
	EndIf;
	
	OrdersArray = New Array;
	For Each CurItem In Object.Inventory Do
		OrderStructure = New Structure("Order, Total");
		OrderStructure.Order = CurItem.SalesOrder;
		OrderStructure.Total = CurItem.Total;
		OrdersArray.Add(OrderStructure);
	EndDo;
	
	AddressPrepaymentInStorage = PlacePrepaymentToStorage();
	
	SelectionParameters = New Structure;
	SelectionParameters.Insert("AddressPrepaymentInStorage"		, AddressPrepaymentInStorage);
	SelectionParameters.Insert("Pick" 							, True);
	SelectionParameters.Insert("IsOrder"						, True);
	SelectionParameters.Insert("OrderInHeader"					, False);
	SelectionParameters.Insert("Company"						, ParentCompany);
	SelectionParameters.Insert("Order"							, ?(CounterpartyDoSettlementsByOrders, OrdersArray, Undefined));
	SelectionParameters.Insert("Date"							, Object.Date);
	SelectionParameters.Insert("Ref"							, Object.Ref);
	SelectionParameters.Insert("Counterparty"					, Object.Counterparty);
	SelectionParameters.Insert("Contract"						, Object.Contract);
	SelectionParameters.Insert("ContractCurrencyExchangeRate"	, Object.ContractCurrencyExchangeRate);
	SelectionParameters.Insert("ContractCurrencyMultiplicity"	, Object.ContractCurrencyMultiplicity);
	SelectionParameters.Insert("ExchangeRate"					, Object.ExchangeRate);
	SelectionParameters.Insert("Multiplicity"					, Object.Multiplicity);
	SelectionParameters.Insert("DocumentCurrency"				, Object.DocumentCurrency);
	SelectionParameters.Insert("DocumentAmount"					, Object.Inventory.Total("Total"));
	
	ReturnCode = Undefined;
	
	NotifyDescription = New NotifyDescription("EditPrepaymentOffsetEnd",
		ThisObject,
		New Structure("AddressPrepaymentInStorage", AddressPrepaymentInStorage));
	
	OpenForm("CommonForm.SelectAdvancesReceivedFromTheCustomer", SelectionParameters,,,,, NotifyDescription);
	
EndProcedure

&AtClient
Procedure EditPrepaymentOffsetEnd(Result, AdditionalParameters) Export
	
	AddressPrepaymentInStorage = AdditionalParameters.AddressPrepaymentInStorage;
	
	ReturnCode = Result;
	
	If ReturnCode = DialogReturnCode.OK Then
		GetPrepaymentFromStorage(AddressPrepaymentInStorage);
	EndIf;
	
EndProcedure

// Peripherals
// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	TabularSectionName = "Customers";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisObject, "Inventory");
	If Cancel Then
		Return;
	EndIf;
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en = 'Enter barcode'; ru = 'Введите штрихкод';pl = 'Wprowadź kod kreskowy';es_ES = 'Introducir el código de barras';es_CO = 'Introducir el código de barras';tr = 'Barkod girin';it = 'Inserisci codice a barre';de = 'Geben Sie den Barcode ein'"));

EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	If Not IsBlankString(CurBarcode) Then
		
		BarcodesReceived(New Structure("Barcode, Quantity", TrimAll(CurBarcode), 1));
		
		TabularSectionName = "Inventory";
		FilterStr = New FixedStructure("ConnectionKey", Items[TabularSectionName].RowFilter["ConnectionKey"]);
		Items[TabularSectionName].RowFilter = FilterStr;
		
		UpdateColumnTotalAtClient();
		
	EndIf;
	
EndProcedure

// Procedure - event handler Action of the GetWeight command
//
&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow = Undefined Then
		
		ShowMessageBox(Undefined, NStr("en = 'Select a line where you want to record the weight.'; ru = 'Необходимо выбрать строку, для которой необходимо получить вес.';pl = 'Wybierz wiersz, dla którego należy otrzymać wagę.';es_ES = 'Seleccionar una línea donde quiere grabar el peso.';es_CO = 'Seleccionar una línea donde quiere grabar el peso.';tr = 'Ağırlığı kaydetmek istediğiniz yerde satırı seçin.';it = 'Selezionare una linea in cui si desidera registrare il peso.';de = 'Wählen Sie eine Zeile aus, in der Sie das Gewicht erfassen möchten.'"));
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		
		NotifyDescription = New NotifyDescription("GetWeightEnd", ThisObject, TabularSectionRow);
		EquipmentManagerClient.StartWeightReceivingFromElectronicScales(NotifyDescription, UUID);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GetWeightEnd(Weight, Parameters) Export
	
	TabularSectionRow = Parameters;
	
	If Not Weight = Undefined Then
		If Weight = 0 Then
			MessageText = NStr("en = 'The electronic scale returned zero weight.'; ru = 'Электронные весы вернули нулевой вес.';pl = 'Waga elektroniczna zwróciła wagę zerową.';es_ES = 'Las escalas electrónicas han devuelto el peso cero.';es_CO = 'Las escalas electrónicas han devuelto el peso cero.';tr = 'Elektronik tartı sıfır ağırlık gösteriyor.';it = 'La bilancia elettronica ha dato peso pari a zero.';de = 'Die elektronische Waage gab Nullgewicht zurück.'");
			CommonClientServer.MessageToUser(MessageText);
		Else
			// Weight is received.
			TabularSectionRow.Quantity = Weight;
								
			CalculateAmountInTabularSectionLine(TabularSectionRow);
			
			// Amount of the transfer.
			TabularSectionRow.TransmissionAmount = TabularSectionRow.TransmissionPrice * TabularSectionRow.Quantity;
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
			// VAT amount of the transfer.
			TabularSectionRow.TransmissionVATAmount = ?(
				Object.AmountIncludesVAT,
				TabularSectionRow.TransmissionAmount - (TabularSectionRow.TransmissionAmount) / ((VATRate + 100) / 100),
				TabularSectionRow.TransmissionAmount * VATRate / 100
			);
			
			// Amount of brokerage
			CalculateCommissionRemuneration(TabularSectionRow);
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - ImportDataFromDTC command handler.
//
&AtClient
Procedure ImportDataFromDCT(Command)
	
	TabularSectionName = "Customers";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisObject, "Inventory");
	If Cancel Then
		Return;
	EndIf;
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") 
	   AND Result.Count() > 0 Then
		
		BarcodesReceived(Result);
		
		TabularSectionName = "Inventory";
		FilterStr = New FixedStructure("ConnectionKey", Items[TabularSectionName].RowFilter["ConnectionKey"]);
		Items[TabularSectionName].RowFilter = FilterStr;
		
		UpdateColumnTotalAtClient();
		
	EndIf;
	
EndProcedure

// End Peripherals

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

// Procedure - event handler OnChange of the Date input field.
// In procedure situation is determined when date change document is
// into document numbering another period and in this case
// assigns to the document new unique number.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

// Procedure - event handler OnChange of the Company input field.
// In procedure is executed document
// number clearing and also make parameter set of the form functional options.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange();
	ParentCompany = StructureData.Company;
	ExchangeRateMethod = StructureData.ExchangeRateMethod;
	
	Object.VATCommissionFeePercent = StructureData.VATRate;
	
	GenerateLabelPricesAndCurrency();
	
	ProcessingCompanyVATNumbers(False);
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
	If Object.SetPaymentTerms And ValueIsFilled(Object.PaymentMethod) Then
		PaymentTermsServerCall.FillPaymentTypeAttributes(
			Object.Company, Object.CashAssetType, Object.BankAccount, Object.PettyCash);
	EndIf;
		
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
EndProcedure

&AtClient
Procedure KeepBackCommissionFeeOnChange(Item)
	
	If NOT Object.KeepBackCommissionFee Then
		Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating");
	EndIf;
	
	For Each TabularSectionRow In Object.Inventory Do
		CalculateCommissionRemuneration(TabularSectionRow);
	EndDo;
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

// Procedure - event handler OnChange of the BrokerageCalculationMethod input field.
//
&AtClient
Procedure BrokerageCalculationMethodOnChange(Item)
	
	If Object.BrokerageCalculationMethod <> PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating")
		AND ValueIsFilled(Object.CommissionFeePercent) Then
		If Object.Inventory.Count() > 0 Then
			Response = Undefined;
			
			ShowQueryBox(New NotifyDescription("BrokerageCalculationMethodOnChangeEnd", ThisObject), 
				NStr("en = 'The calculation method has been changed. Do you want to recalculate the commission?'; ru = 'Изменился способ расчета. Пересчитать комиссионное вознаграждение?';pl = 'Metoda rozliczeń uległa zmianie. Czy chcesz przeliczyć prowizję?';es_ES = 'El método de cálculo se ha cambiado. ¿Quiere recalcular la comisión?';es_CO = 'El método de cálculo se ha cambiado. ¿Quiere recalcular la comisión?';tr = 'Hesaplama yöntemi değiştirildi. Komisyonu yeniden hesaplamak istiyor musunuz?';it = 'Il metodo di calcolo è stato modificato. Volete ricalcolare la commissione?';de = 'Die Berechnungsmethode hat sich geändert. Provision neu berechnen?'"),
				QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
			Return;
		EndIf;
	EndIf;
	
	BrokerageCalculationMethodOnChangeFragment();
EndProcedure

&AtClient
Procedure BrokerageCalculationMethodOnChangeEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		For Each TabularSectionRow In Object.Inventory Do
			CalculateCommissionRemuneration(TabularSectionRow);
		EndDo;
	EndIf;
	
	BrokerageCalculationMethodOnChangeFragment();
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);

EndProcedure

&AtClient
Procedure BrokerageCalculationMethodOnChangeFragment()
    
    SetVisibleAndEnabled();

EndProcedure

// Procedure - handler of the OnChange event of the BrokerageVATRate input field.
//
&AtClient
Procedure VATCommissionFeePercentOnChange(Item)
	
	If Object.Inventory.Count() = 0 Then
		Return;
	EndIf;
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("BrokerageVATRateOnChangeEnd", ThisObject), "Do you want to recalculate VAT amounts of remuneration?", QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure BrokerageVATRateOnChangeEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	VATRate = DriveReUse.GetVATRateValue(Object.VATCommissionFeePercent);
	
	For Each TabularSectionRow In Object.Inventory Do
		
		TabularSectionRow.BrokerageVATAmount = ?(Object.AmountIncludesVAT,
		TabularSectionRow.BrokerageAmount - (TabularSectionRow.BrokerageAmount) / ((VATRate + 100) / 100),
		TabularSectionRow.BrokerageAmount * VATRate / 100);
		
	EndDo;
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

// Procedure - event handler OnChange of the BrokeragePercent.
//
&AtClient
Procedure CommissionFeePercentOnChange(Item)
	
	If Object.Inventory.Count() > 0 Then
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("BrokeragePercentOnChangeEnd", ThisObject),
			NStr("en = 'The calculation method has been changed. Do you want to recalculate the commission?'; ru = 'Изменился способ расчета. Пересчитать комиссионное вознаграждение?';pl = 'Metoda rozliczeń uległa zmianie. Czy chcesz przeliczyć prowizję?';es_ES = 'El método de cálculo se ha cambiado. ¿Quiere recalcular la comisión?';es_CO = 'El método de cálculo se ha cambiado. ¿Quiere recalcular la comisión?';tr = 'Hesaplama yöntemi değiştirildi. Komisyonu yeniden hesaplamak istiyor musunuz?';it = 'Il metodo di calcolo è stato modificato. Volete ricalcolare la commissione?';de = 'Die Berechnungsmethode hat sich geändert. Provision neu berechnen?'"),
			QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
		
EndProcedure

&AtClient
Procedure BrokeragePercentOnChangeEnd(Result, AdditionalParameters) Export
	
	// We must offer to recalculate brokerage.
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		For Each TabularSectionRow In Object.Inventory Do
			CalculateCommissionRemuneration(TabularSectionRow);
		EndDo;
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
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
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Counterparty);
		
		StructureData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		Object.Contract = StructureData.Contract;
		
		FillSalesRepInInventory(StructureData.SalesRep);
		
		StructureData.Insert("CounterpartyBeforeChange", CounterpartyBeforeChange);
		StructureData.Insert("CounterpartyDoSettlementsByOrdersBeforeChange", CounterpartyDoSettlementsByOrdersBeforeChange);
		
		ProcessContractChange(StructureData);
		
		SetVisibleEnablePaymentTermItems();
		GenerateLabelPricesAndCurrency();
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		
	EndIf;
	
EndProcedure

// The OnChange event handler of the Contract field.
// It updates the currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	SetVisibleEnablePaymentTermItems();
	
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

&AtClient
Procedure SalesRepOnChange(Item)
	If Object.Inventory.Count() > 1 Then
		FillSalesRepInInventory(Object.Inventory[0].SalesRep);
	EndIf;
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
Procedure FieldSwitchTypeListOfPaymentCalendarOnChange(Item)
	
	PaymentCalendarCount = Object.PaymentCalendar.Count();
	
	If Not SwitchTypeListOfPaymentCalendar Then
		If PaymentCalendarCount > 1 Then
			ClearMessages();
			TextMessage = NStr("en = 'You can''t change the mode of payment terms because there is more than one payment date'; ru = 'Вы не можете переключить режим отображения условий оплаты, т.к. указано более одной даты оплаты.';pl = 'Nie możesz zmienić trybu warunków płatności, ponieważ istnieje kilka dat płatności';es_ES = 'Usted no puede cambiar el modo de los términos de pago porque hay más de una fecha de pago';es_CO = 'Usted no puede cambiar el modo de los términos de pago porque hay más de una fecha de pago';tr = 'Birden fazla ödeme tarihi olduğundan, ödeme şartlarının modu değiştirilemez';it = 'Non è possibile modificare i termini di pagamento, perché c''è più di una data di pagamento';de = 'Sie können den Modus der Zahlungsbedingungen nicht ändern, da es mehr als einen Zahlungsdatum gibt.'");
			CommonClientServer.MessageToUser(TextMessage);
			
			SwitchTypeListOfPaymentCalendar = 1;
		ElsIf PaymentCalendarCount = 0 Then
			NewLine = Object.PaymentCalendar.Add();
		EndIf;
	EndIf;
		
	SetVisiblePaymentCalendar();
	SetVisiblePaymentMethod();
	
EndProcedure

&AtClient
Procedure PaymentMethodOnChange(Item)
	Object.CashAssetType = PaymentMethodCashAssetType(Object.PaymentMethod);
	SetVisiblePaymentMethod();
EndProcedure

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

&AtClient
Procedure PaymentCalendarPaymentPercentageOnChange(Item)
	
	Totals = PaymentTermsClientServer.CalculateDocumentAmountVATAmountTotals(Object);
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	CurrentRow.PaymentAmount = Round(Totals.Amount * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount = Round(Totals.VATAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

&AtClient
Procedure PaymentCalendarPaymentAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	Totals = PaymentTermsClientServer.CalculateDocumentAmountVATAmountTotals(Object);
	
	If Totals.Amount = 0 Then
		CurrentRow.PaymentPercentage = 0;
		CurrentRow.PaymentVATAmount = 0;
	Else
		CurrentRow.PaymentPercentage = Round(CurrentRow.PaymentAmount / Totals.Amount * 100, 2, 1);
		CurrentRow.PaymentVATAmount = Round(Totals.VATAmount * CurrentRow.PaymentAmount / Totals.Amount, 2, 1);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentVATAmount");
	Totals = PaymentTermsClientServer.CalculateDocumentAmountVATAmountTotals(Object);
	
	If PaymentCalendarTotal > Totals.VATAmount Then
		CurrentRow.PaymentVATAmount = CurrentRow.PaymentVATAmount - (PaymentCalendarTotal - Totals.VATAmount);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarOnStartEdit(Item, NewRow, Clone)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	If NewRow Then
		CurrentRow.PaymentBaselineDate = PredefinedValue("Enum.BaselineDateForPayment.InvoicePostingDate");
	EndIf;
	
	If CurrentRow.PaymentPercentage = 0 Then
		
		Totals = PaymentTermsClientServer.CalculateDocumentAmountVATAmountTotals(Object);
		
		CurrentRow.PaymentPercentage = 100 - Object.PaymentCalendar.Total("PaymentPercentage");
		CurrentRow.PaymentAmount = Totals.Amount - Object.PaymentCalendar.Total("PaymentAmount");
		CurrentRow.PaymentVATAmount = Totals.VATAmount - Object.PaymentCalendar.Total("PaymentVATAmount");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarBeforeDeleteRow(Item, Cancel)
		
	If Object.PaymentCalendar.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure GLAccountsClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	GLAccountsInDocumentsClient.OpenCounterpartyGLAccountsForm(ThisObject, Object, "");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF TABULAR SECTION ATTRIBUTES CUSTOMERS

// Procedure - event handler OnActivateRow of the Customers tabular section.
//
&AtClient
Procedure CustomersOnActivateRow(Item)
	
	TabularSectionName = "Customers";
	DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "Inventory");
	
EndProcedure

// Procedure - OnStartEdit event handler of the Customers tabular section.
//
&AtClient
Procedure CustomersOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Customers";
	TabularSectionRow = Item.CurrentData;
	
	If NewRow Then
		DriveClient.AddConnectionKeyToTabularSectionLine(ThisObject);
		DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "Inventory");
	EndIf;
	
	If Copy Then
		TabularSectionRow.Total = 0;
	EndIf;
	
EndProcedure

// Procedure - event handler BeforeDelete of the Customers tabular section.
//
&AtClient
Procedure CustomersBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentCustomer = Items.Customers.CurrentData;
	SearchResult = Object.Inventory.FindRows(New Structure("ConnectionKey", CurrentCustomer.ConnectionKey));
	For Each StringInventory In SearchResult Do
		
		SearchResultSN = Object.SerialNumbers.FindRows(New Structure("ConnectionKey", StringInventory.ConnectionKeySerialNumbers));
		For Each StrSerialNumbers In SearchResultSN Do
			IndexToBeDeleted = Object.SerialNumbers.IndexOf(StrSerialNumbers);
			Object.SerialNumbers.Delete(IndexToBeDeleted);
		EndDo;
	EndDo;
	// Serial numbers
	
	TabularSectionName = "Customers";
	DriveClient.DeleteRowsOfSubordinateTabularSection(ThisObject, "Inventory");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////PROCEDURE - EVENT HANDLERS OF THE
//    INVENTORY TABULAR SECTION ATTRIBUTES

// Procedure - OnStartEdit event handler of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Customers";
	
	If NewRow Then
		DriveClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisObject, Item.Name);
	EndIf;
	
	If NewRow AND Copy Then
		Item.CurrentData.ConnectionKeySerialNumbers = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;

	If Item.CurrentItem.Name = "InventorySerialNumbers" Then
		OpenSerialNumbersSelection();
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);
	
EndProcedure

// Procedure - event handler BeforeAddStart of the Inventory tabular section.
//
&AtClient
Procedure InventoryBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	TabularSectionName = "Customers";
	
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisObject, Item.Name);
	
	If Not Cancel AND Copy Then
		
		UpdateColumnTotalAtClient();
		
		CurRowCustomers = Items.Customers.CurrentData;
		CurRowCustomers.Total = CurRowCustomers.Total + Item.CurrentData.Total;
		
		LineCopyInventory = True;
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnChange(Item)
	
	If LineCopyInventory = Undefined OR Not LineCopyInventory Then
		UpdateColumnTotalAtClient();
	Else
		LineCopyInventory = False;
	EndIf;
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = CreateGeneralAttributeValuesStructure(ThisObject, "Inventory", TabularSectionRow);
	
	If ValueIsFilled(Object.PriceKind) Then
		StructureData.Insert("ProcessingDate",	 Object.Date);
		StructureData.Insert("PriceKind",			 Object.PriceKind);
		StructureData.Insert("DocumentCurrency",	 Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		StructureData.Insert("Factor",		 1);
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(StructureData, ThisObject, "Inventory");
	EndIf;
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.TransmissionPrice = 0;
	TabularSectionRow.TransmissionAmount = 0;
	TabularSectionRow.TransmissionVATAmount = 0;
	
	CalculateAmountInTabularSectionLine();
	CalculateCommissionRemuneration(TabularSectionRow);
	
	// Serial numbers
	For Each SelectedRow In Items.Inventory.SelectedRows Do
		CurrentRowData = Items.Inventory.RowData(SelectedRow);
		WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentRowData,, UseSerialNumbersBalance);
	EndDo;
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	For Each SelectedRow In Items.Inventory.SelectedRows Do
		CurrentRowData = Items.Inventory.RowData(SelectedRow);
		WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentRowData,,UseSerialNumbersBalance);
	EndDo;
	
EndProcedure

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "InventoryGLAccounts" Then
		StandardProcessing = False;
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
	ElsIf Field.Name = "InventoryIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Inventory");
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
		ElsIf TableCurrentColumn.Name = "InventoryIncomeAndExpenseItems"
			And Not CurrentData.IncomeAndExpenseItemsFilled Then
			SelectedRow = Items.Inventory.CurrentRow;
			IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Inventory");
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

&AtClient
Procedure InventoryIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "Inventory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection();
	
EndProcedure

// Procedure - event handler OnChange of the variant input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	If ValueIsFilled(Object.PriceKind) Then
		
		TabularSectionRow = Items.Inventory.CurrentData;
		
		StructureData = New Structure;
		StructureData.Insert("Company", 			Object.Company);
		StructureData.Insert("ProcessingDate",	 Object.Date);
		StructureData.Insert("PriceKind",			 Object.PriceKind);
		StructureData.Insert("DocumentCurrency",	 Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		
		StructureData.Insert("VATRate", 		 TabularSectionRow.VATRate);
		StructureData.Insert("Products",	 TabularSectionRow.Products);
		StructureData.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		StructureData.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		StructureData.Insert("Price",			 TabularSectionRow.Price);
		
		StructureData = GetDataCharacteristicOnChange(StructureData);
		
		TabularSectionRow.Price = StructureData.Price;
		
		CalculateAmountInTabularSectionLine();
		CalculateCommissionRemuneration(TabularSectionRow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.Inventory.CurrentData;
	
	If DriveClient.UseMatrixForm(CurrentRow.Products) Then
		
		StandardProcessing = False;
		
		TabularSectionName	= "Inventory";
		SelectionMarker		= "Inventory";
		SelectionParameters	= DriveClient.GetMatrixParameters(ThisObject, TabularSectionName, True);
		NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseVariantsSelection", ThisObject);
		OpenForm("Catalog.ProductsCharacteristics.Form.MatrixChoiceForm",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;

EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
	// Amount of the transfer.
	TabularSectionRow.TransmissionAmount = TabularSectionRow.TransmissionPrice * TabularSectionRow.Quantity;
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	// VAT amount of the transfer.
	TabularSectionRow.TransmissionVATAmount = ?(
		Object.AmountIncludesVAT,
		TabularSectionRow.TransmissionAmount - (TabularSectionRow.TransmissionAmount) / ((VATRate + 100) / 100),
		TabularSectionRow.TransmissionAmount * VATRate / 100);
	
	// Amount of brokerage
	CalculateCommissionRemuneration(TabularSectionRow);
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
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
	
	// Price.
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
	
	CalculateAmountInTabularSectionLine();
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	TabularSectionRow = Items.Inventory.CurrentData;
	CalculateCommissionRemuneration(TabularSectionRow);
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Amount of brokerage
	CalculateCommissionRemuneration(TabularSectionRow);
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
		
	// VAT amount of the transfer.
	TabularSectionRow.TransmissionVATAmount = ?(Object.AmountIncludesVAT,
		TabularSectionRow.TransmissionAmount - (TabularSectionRow.TransmissionAmount) / ((VATRate + 100) / 100),
		TabularSectionRow.TransmissionAmount * VATRate / 100);
		
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

// Procedure - event handler OnChange of the TransmissionPrice input field.
//
&AtClient
Procedure InventoryTransferPriceOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Amount of the transfer.
	TabularSectionRow.TransmissionAmount = TabularSectionRow.Quantity * TabularSectionRow.TransmissionPrice;
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	// VAT amount of the transfer.
	TabularSectionRow.TransmissionVATAmount = ?(Object.AmountIncludesVAT,
												TabularSectionRow.TransmissionAmount - (TabularSectionRow.TransmissionAmount) / ((VATRate + 100) / 100),
												TabularSectionRow.TransmissionAmount * VATRate / 100);	
	
	// Amount of brokerage
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure

// Procedure - event handler OnChange of the TransmissionAmount input field.
//
&AtClient
Procedure InventoryAmountTransferOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.TransmissionPrice = TabularSectionRow.TransmissionAmount / TabularSectionRow.Quantity;
	EndIf;
	
	// VAT amount of the transfer.
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
		
	TabularSectionRow.TransmissionVATAmount = ?(Object.AmountIncludesVAT,
												TabularSectionRow.TransmissionAmount - (TabularSectionRow.TransmissionAmount) / ((VATRate + 100) / 100),
												TabularSectionRow.TransmissionAmount * VATRate / 100);	
	
	// Amount of brokerage
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure

// Procedure - event handler OnChange of the BrokerageAmount input field.
//
&AtClient
Procedure InventoryBrokerageAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	VATRate = DriveReUse.GetVATRateValue(Object.VATCommissionFeePercent);
		
	TabularSectionRow.BrokerageVATAmount = ?(Object.AmountIncludesVAT,
		TabularSectionRow.BrokerageAmount - (TabularSectionRow.BrokerageAmount) / ((VATRate + 100) / 100),
		TabularSectionRow.BrokerageAmount * VATRate / 100);
		
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

&AtClient
Procedure InventoryVATAmountRemunerationOnChange(Item)
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
EndProcedure

&AtClient
Procedure InventorySalesOrderOnChange(Item)
	
	CurrentRow = Items.Inventory.CurrentData;
	If ValueIsFilled(CurrentRow.SalesOrder) Then
		CurrentRow.SalesRep = SalesRep(CurrentRow.SalesOrder);
	EndIf;
	
EndProcedure

#Region InteractiveActionResultHandlers

// Procedure-handler of the result of opening the "Prices and currencies" form
//
&AtClient
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") And ClosingResult.WereMadeChanges Then
		
		DocCurRecalcStructure = New Structure;
		DocCurRecalcStructure.Insert("DocumentCurrency", ClosingResult.DocumentCurrency);
		DocCurRecalcStructure.Insert("Rate", ClosingResult.ExchangeRate);
		DocCurRecalcStructure.Insert("Repetition", ClosingResult.Multiplicity);
		DocCurRecalcStructure.Insert("PrevDocumentCurrency", AdditionalParameters.DocumentCurrency);
		DocCurRecalcStructure.Insert("InitRate", AdditionalParameters.ExchangeRate);
		DocCurRecalcStructure.Insert("RepetitionBeg", AdditionalParameters.Multiplicity);
		
		Object.PriceKind = ClosingResult.PriceKind;
		Object.DocumentCurrency = ClosingResult.DocumentCurrency;
		Object.ExchangeRate = ClosingResult.ExchangeRate;
		Object.Multiplicity = ClosingResult.Multiplicity;
		Object.ContractCurrencyExchangeRate = ClosingResult.SettlementsRate;
		Object.ContractCurrencyMultiplicity = ClosingResult.SettlementsMultiplicity;
		Object.VATTaxation = ClosingResult.VATTaxation;
		Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
		Object.IncludeVATInPrice = ClosingResult.IncludeVATInPrice;
		Object.AutomaticVATCalculation = ClosingResult.AutomaticVATCalculation;
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisObject, "Inventory");
			
		EndIf;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices
			AND ClosingResult.RecalculatePrices Then
			
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "Inventory", PricesPrecision);
			
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			
			FillVATRateByVATTaxation();
			
			ParametersStructure = New Structure;
			ParametersStructure.Insert("GetGLAccounts", True);
			ParametersStructure.Insert("FillHeader", True);
			ParametersStructure.Insert("FillInventory", False);
			
			FillAddedColumns(ParametersStructure);
			
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices
			AND Not ClosingResult.AmountIncludesVAT = ClosingResult.PrevAmountIncludesVAT Then
			
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisObject, "Inventory", PricesPrecision);
			
		EndIf;
		
		// Amount of brokerage
		For Each TabularSectionRow In Object.Inventory Do
			
			CalculateCommissionRemuneration(TabularSectionRow);
			
		EndDo;
		
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
		
		UpdateColumnTotalAtClient(True);
		
	EndIf;
	
	GenerateLabelPricesAndCurrency();
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
	OpenPricesAndCurrencyFormEndAtServer();
	
EndProcedure

&AtServer
Procedure OpenPricesAndCurrencyFormEndAtServer()
	
	SetPrepaymentColumnsProperties();
	
EndProcedure

// Procedure-handler of the response to question about the necessity to set a new currency rate
//
&AtClient
Procedure DefineNewExchangeRateettingNeed(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
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
		
		GenerateLabelPricesAndCurrency();
		
	EndIf;
	
EndProcedure

// Procedure-handler of the answer to the question about repeated advances offset
//
&AtClient
Procedure DefineAdvancePaymentOffsetsRefreshNeed(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Object.Prepayment.Clear();
		
		ProcessPricesKindAndSettlementsCurrencyChange(AdditionalParameters);
		
	Else
		
		Object.Contract = AdditionalParameters.ContractBeforeChange;
		Contract = AdditionalParameters.ContractBeforeChange;
		
		If AdditionalParameters.Property("CounterpartyBeforeChange") Then
			
			Counterparty = AdditionalParameters.CounterpartyBeforeChange;
			CounterpartyDoSettlementsByOrders = AdditionalParameters.CounterpartyDoSettlementsByOrdersBeforeChange;
			Object.Counterparty = AdditionalParameters.CounterpartyBeforeChange;
			Items.Contract.Visible = AdditionalParameters.ContractVisibleBeforeChange;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure-handler response on question about document recalculate by contract data
//
&AtClient
Procedure DefineDocumentRecalculateNeedByContractTerms(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		DriveClient.RefillTabularSectionPricesByPriceKind(ThisObject, "Inventory");
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

&AtClient
Procedure OpenSerialNumbersSelection()
	
	CurrentDataIdentifier = Items.Inventory.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);
	
EndProcedure

&AtServer
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	
	ParametersFieldNames = New Structure;
	ParametersFieldNames.Insert("FieldNameConnectionKey", "ConnectionKeySerialNumbers");
	
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey, ParametersFieldNames);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier,
		False,,, "ConnectionKeySerialNumbers");
	
EndFunction

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

&AtServer
Procedure SetSwitchTypeListOfPaymentCalendar()
	
	If Object.PaymentCalendar.Count() > 1 Then
		SwitchTypeListOfPaymentCalendar = 1;
	Else
		SwitchTypeListOfPaymentCalendar = 0;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetEnableGroupPaymentCalendarDetails()
	Items.GroupPaymentCalendarDetails.Enabled = Object.SetPaymentTerms;
EndProcedure

&AtClient
Procedure ClearPaymentCalendarContinue(Answer, Parameters) Export
	If Answer = DialogReturnCode.Yes Then
		Object.PaymentCalendar.Clear();
		SetEnableGroupPaymentCalendarDetails();
	ElsIf Answer = DialogReturnCode.No Then
		Object.SetPaymentTerms = True;
	EndIf;
EndProcedure

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

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.InventoryPrice);
	Fields.Add(Items.InventoryPriceOfTransfer);
	
	Return Fields;
	
EndFunction

// Procedure recalculates subtotal the document on client.
&AtClient
Procedure RecalculateSubtotal()
	
	DocumentSubtotal = Object.Inventory.Total("Total") - Object.Inventory.Total("VATAmount");
	
EndProcedure

&AtClient
Procedure FillSalesRepInInventory(SalesRep)
	
	For Each CurrentRow In Object.Inventory Do
		CurrentRow.SalesRep = SalesRep;
	EndDo;
	
EndProcedure

&AtServerNoContext
Function SalesRep(SalesOrder)
	Return Common.ObjectAttributeValue(SalesOrder, "SalesRep");
EndFunction

&AtClientAtServerNoContext
Function CreateGeneralAttributeValuesStructure(Form, TabName, TabRow)
	
	Object = Form.Object;
	
	StructureData = New Structure("
	|TabName,
	|Object,
	|Company,
	|Products,
	|Characteristic,
	|VATTaxation,
	|UseDefaultTypeOfAccounting,
	|IncomeAndExpenseItems,
	|IncomeAndExpenseItemsFilled,
	|RevenueItem,
	|COGSItem");
	
	FillPropertyValues(StructureData, Form);
	FillPropertyValues(StructureData, Object);
	FillPropertyValues(StructureData, TabRow);
	
	StructureData.Insert("TabName", TabName);
	
	Return StructureData;
	
EndFunction

&AtClientAtServerNoContext
Procedure AddGLAccountsToStructure(StructureData, Form, TabName, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("ProductGLAccounts",				True);
	StructureData.Insert("GLAccounts",						TabRow.GLAccounts);
	StructureData.Insert("GLAccountsFilled",				TabRow.GLAccountsFilled);
	StructureData.Insert("InventoryTransferredGLAccount",	TabRow.InventoryTransferredGLAccount);
	StructureData.Insert("VATOutputGLAccount",				TabRow.VATOutputGLAccount);
	StructureData.Insert("RevenueGLAccount",				TabRow.RevenueGLAccount);
	StructureData.Insert("COGSGLAccount",					TabRow.COGSGLAccount);
	
EndProcedure

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val CatalogCounterparty)
	
	Attributes = "DoOperationsByContracts, DoOperationsByOrders, VATTaxation";
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, CatalogCounterparty, Attributes);
	
EndProcedure

&AtClient
Procedure GenerateLabelPricesAndCurrency()
	
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind", Object.PriceKind);
	LabelStructure.Insert("DocumentCurrency", Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency", SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate", Object.ExchangeRate);
	LabelStructure.Insert("RateNationalCurrency", RateNationalCurrency);
	LabelStructure.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting", ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation", Object.VATTaxation);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

#Region Prepayment

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
Function GetAdvanceExchangeRateParameters(DocumentParam, OrderParam)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Ref", Object.Ref);
	ParametersStructure.Insert("Company", ParentCompany);
	ParametersStructure.Insert("Counterparty", Object.Counterparty);
	ParametersStructure.Insert("Contract", Object.Contract);
	ParametersStructure.Insert("Document", DocumentParam);
	ParametersStructure.Insert("Order", OrderParam);
	ParametersStructure.Insert("Period", EndOfDay(Object.Date) + 1);
	
	Return ParametersStructure;
	
EndFunction

&AtServerNoContext
Function GetCalculatedAdvanceExchangeRate(ParametersStructure)
	
	Return DriveServer.GetCalculatedAdvanceReceivedExchangeRate(ParametersStructure);
	
EndFunction

#EndRegion

#Region GLAccounts

&AtServer
Procedure FillAddedColumns(ParametersStructure)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	StructureArray = New Array();
	
	If UseDefaultTypeOfAccounting
		And ParametersStructure.FillHeader Then
		
		Header = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "Header", Object);
		GLAccountsInDocuments.CompleteCounterpartyStructureData(Header, ObjectParameters, "Header");
		
		StructureArray.Add(Header);
		
	EndIf;
	
	If ParametersStructure.FillInventory Then
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters);
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters);
		
		StructureArray.Add(StructureData);
		
	EndIf;
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, ParametersStructure.GetGLAccounts);
	
	If UseDefaultTypeOfAccounting
		And ParametersStructure.FillHeader Then
		GLAccounts = Header.GLAccounts;
	EndIf;
	
EndProcedure

#EndRegion

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

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion