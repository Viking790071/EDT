
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
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
			Object.DocumentCurrency				= Object.Contract.SettlementsCurrency;
			SettlementsCurrencyRateRepetition	= CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.DocumentCurrency, Object.Company);
			Object.ExchangeRate					= ?(SettlementsCurrencyRateRepetition.Rate = 0, 1, SettlementsCurrencyRateRepetition.Rate);
			Object.Multiplicity					= ?(SettlementsCurrencyRateRepetition.Repetition = 0, 1, SettlementsCurrencyRateRepetition.Repetition);
			Object.SupplierPriceTypes		= Object.Contract.SupplierPriceTypes;
			
			If Object.PaymentCalendar.Count() = 0 Then
				FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
			EndIf;
		
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany				= DriveServer.GetCompany(Object.Company);
	Counterparty				= Object.Counterparty;
	Contract					= Object.Contract;
	SettlementsCurrency			= Object.Contract.SettlementsCurrency;
	FunctionalCurrency			= Constants.FunctionalCurrency.Get();
	StructureByCurrency			= CurrencyRateOperations.GetCurrencyRate(Object.Date, FunctionalCurrency, Object.Company);
	RateNationalCurrency		= StructureByCurrency.Rate;
	RepetitionNationalCurrency	= StructureByCurrency.Repetition;
	ExchangeRateMethod          = DriveServer.GetExchangeMethod(ParentCompany);
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	
	If Not ValueIsFilled(Object.Ref)
		And Not ValueIsFilled(Parameters.Basis) 
		And Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then	
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.InventoryVATSummOfArrival.Visible = True;
		Items.InventoryTotalAmountOfVAT.Visible = True;
		Items.PaymentCalendarPaymentVATAmount.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
	Else
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.InventoryVATSummOfArrival.Visible = False;
		Items.InventoryTotalAmountOfVAT.Visible = False;
		Items.PaymentCalendarPaymentVATAmount.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
	EndIf;
	
	SetPrepaymentColumnsProperties();
	
	// Generate price and currency label.
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	LabelStructure = New Structure("SupplierPriceTypes, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.SupplierPriceTypes, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	ProcessingCompanyVATNumbers();
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Object.Date, ParentCompany);
	PerInvoiceVATRoundingRule = AccountingPolicy.PerInvoiceVATRoundingRule;
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	
	Items.CommissionFeePercent.Enabled = Not (Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating"));
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	FillAddedColumns();
	
	// Setting contract visible.
	SetContractVisible();
	
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
	
	// Peripherals
	UsePeripherals = DriveReUse.UsePeripherals();
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList("ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
	SwitchTypeListOfPaymentCalendar = ?(Object.PaymentCalendar.Count() > 1, 1, 0);
	
	DriveServer.CheckObjectGeneratedEnteringBalances(ThisObject);
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	FillAddedColumns();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	SetSwitchTypeListOfPaymentCalendar();
	
EndProcedure

// Procedure-handler of the BeforeWriteAtServer event.
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
			Message.Text = ?(Cancel, NStr("en = 'Cannot post the account sales to consignor.'; ru = 'Отчет комитенту не проведен.';pl = 'Nie można zatwierdzić raportu sprzedaży komitentowi.';es_ES = 'No se puede enviar las ventas de cuentas al destinatario.';es_CO = 'No se puede enviar las ventas de cuentas al destinatario.';tr = 'Konsinye alışlar kaydedilemiyor.';it = 'Non è possibile pubblicare la vendita in conto vendita al committente.';de = 'Fehler beim Buchen des Verkaufsberichts (Kommitent).'") + " " + MessageText, MessageText);
			
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

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillAddedColumns();
	
EndProcedure

// Procedure fills advances.
//
&AtServer
Procedure FillPrepayment(CurrentObject)
	
	CurrentObject.FillPrepayment();
	
EndProcedure

&AtClient
// Procedure - event handler AfterWriting.
//
Procedure AfterWrite(WriteParameters)
	
	Notify("NotificationAboutChangingDebt");
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtClient
// Procedure - event handler OnOpen.
//
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisObject, "BarCodeScanner");
	// End Peripherals
	
	SetVisibleEnablePaymentTermItems();
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
// Procedure - event handler OnClose.
//
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisObject);
	// End Peripherals
	
EndProcedure

&AtClient
// Procedure - event handler of the form NotificationProcessing.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() Then
		If EventName = "ScanData" Then
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
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - selection handler.
//
&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ChoiceSource.FormName = "Document.AccountSalesToConsignor.Form.PickFormBySales" Then
		GetInventoryAcceptedFromStorage(ValueSelected);
	ElsIf GLAccountsInDocumentsClient.IsGLAccountsChoiceProcessing(ChoiceSource.FormName) Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, ValueSelected);
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, ValueSelected);
	EndIf;
	
EndProcedure

// Procedure is called when clicking the "FillByCounterparty" button 
//
&AtClient
Procedure FillByCounterparty(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		MessagesToUserClient.ShowMessageSelectConsignor();
		Return;
	EndIf;
	
	ShowQueryBox(New NotifyDescription("FillByCounterpartyEnd", ThisObject),
		NStr("en = 'The document data will be repopulated. Continue?'; ru = 'Данные документа будут перезаполнены. Продолжить?';pl = 'Dokument zostanie wypełniony ponownie. Kontynuować?';es_ES = 'Los datos del documento se volverán a llenar. ¿Continuar?';es_CO = 'Los datos del documento se volverán a llenar. ¿Continuar?';tr = 'Belge verileri yeniden doldurulacak. Devam edilsin mi?';it = 'I dati del documento saranno ripopolati. Continuare?';de = 'Das Datum des Dokuments werden automatisch neu ausgefüllt. Weiter?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillByCounterpartyEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FillByBasis(Object.Counterparty);
		SetVisibleEnablePaymentTermItems();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
// Procedure - event handler OnChange of the Date input field.
// In procedure situation is determined when date change document is
// into document numbering another period and in this case
// assigns to the document new unique number.
// Overrides the corresponding form parameter.
//
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Company input field.
// In procedure is executed document
// number clearing and also make parameter set of the form functional options.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	ParentCompany = StructureData.Company;
	ExchangeRateMethod = StructureData.ExchangeRateMethod;
	
	SetAutomaticVATCalculation();
	ProcessingCompanyVATNumbers(False);
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	GenerateLabelPricesAndCurrency();
	
	If Object.SetPaymentTerms And ValueIsFilled(Object.PaymentMethod) Then
		PaymentTermsServerCall.FillPaymentTypeAttributes(
			Object.Company, Object.CashAssetType, Object.BankAccount, Object.PettyCash);
	EndIf;
	
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

&AtClient
// Procedure - event handler OnChange of the BrokerageCalculationMethod input field.
//
Procedure BrokerageCalculationMethodOnChange(Item)
	
	NeedToRecalculate = False;
	If Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating")
		AND ValueIsFilled(Object.CommissionFeePercent) Then
		
		Object.CommissionFeePercent = 0;
		If Object.Inventory.Count() > 0 AND Object.Inventory.Total("BrokerageAmount") > 0 Then
			NeedToRecalculate = True;
		EndIf;
		
	EndIf;
	
	If NeedToRecalculate Or (Object.BrokerageCalculationMethod <> PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating")
		AND ValueIsFilled(Object.CommissionFeePercent) AND Object.Inventory.Count() > 0) Then
		
		ShowQueryBox(New NotifyDescription("BrokerageCalculationMethodOnChangeEnd", ThisObject),
			NStr("en = 'The calculation method has been changed. Do you want to recalculate the commission?'; ru = 'Изменился способ расчета. Пересчитать комиссионное вознаграждение?';pl = 'Metoda rozliczeń uległa zmianie. Czy chcesz przeliczyć prowizję?';es_ES = 'El método de cálculo se ha cambiado. ¿Quiere recalcular la comisión?';es_CO = 'El método de cálculo se ha cambiado. ¿Quiere recalcular la comisión?';tr = 'Hesaplama yöntemi değiştirildi. Komisyonu yeniden hesaplamak istiyor musunuz?';it = 'Il metodo di calcolo è stato modificato. Volete ricalcolare la commissione?';de = 'Die Berechnungsmethode hat sich geändert. Provision neu berechnen?'"),
			QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
		
	EndIf;
	
	Items.CommissionFeePercent.Enabled = Not (Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating"));
	
EndProcedure

&AtClient
Procedure BrokerageCalculationMethodOnChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		For Each TabularSectionRow In Object.Inventory Do
			CalculateCommissionRemuneration(TabularSectionRow);
		EndDo;
	EndIf;
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

&AtClient
// Procedure - handler of the OnChange event of the BrokerageVATRate input field.
//
Procedure VATCommissionFeePercentOnChange(Item)
	
	If Object.Inventory.Count() = 0 Then
		Return;
	EndIf;
	
	ShowQueryBox(New NotifyDescription("BrokerageVATRateOnChangeEnd", ThisObject), "Do you want to recalculate VAT amounts of remuneration?",
		QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure BrokerageVATRateOnChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
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

&AtClient
// Procedure - event handler OnChange of the BrokeragePercent.
//
Procedure CommissionFeePercentOnChange(Item)
	
	If Object.Inventory.Count() > 0 Then
		ShowQueryBox(New NotifyDescription("BrokeragePercentOnChangeEnd", ThisObject), 
			NStr("en = 'The commission rate has been changed. Do you want to recalculate the commission?'; ru = 'Изменился процент вознаграждения. Пересчитать комиссионное вознаграждение?';pl = 'Stawka prowizji uległa zmianie. Czy chcesz przeliczyć prowizję?';es_ES = 'La tasa de comisión se ha cambiado. ¿Quiere recalcular la comisión?';es_CO = 'La tasa de comisión se ha cambiado. ¿Quiere recalcular la comisión?';tr = 'Komisyon oranı değişti. Komisyonu yeniden hesaplamak istiyor musunuz?';it = 'Il tasso della commissione è stato modificato. Ricalcolare la commissione?';de = 'Der Provisionssatz wurde geändert. Möchten Sie die Provision neu berechnen?'"),
			QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

&AtClient
Procedure BrokeragePercentOnChangeEnd(Result, AdditionalParameters) Export
	
	// We must offer to recalculate brokerage.
	If Result = DialogReturnCode.Yes Then
		For Each TabularSectionRow In Object.Inventory Do
			CalculateCommissionRemuneration(TabularSectionRow);
		EndDo;
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Counterparty input field.
// Clears the contract and tabular section.
//
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	CounterpartyDoSettlementsByOrdersBeforeChange = CounterpartyDoSettlementsByOrders;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Counterparty);
		
		StructureData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		Object.Contract = StructureData.Contract;
		
		FillSalesRepInInventory(StructureData.SalesRep);
		
		StructureData.Insert("CounterpartyDoSettlementsByOrdersBeforeChange", CounterpartyDoSettlementsByOrdersBeforeChange);
		StructureData.Insert("CounterpartyBeforeChange", CounterpartyBeforeChange);
		
		ProcessContractChange(StructureData);
		GenerateLabelPricesAndCurrency();
		
		SetVisibleEnablePaymentTermItems();
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		
	EndIf;
	
EndProcedure

&AtClient
// The OnChange event handler of the Contract field.
// It updates the currency exchange rate and exchange rate multiplier.
//
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

&AtClient
Procedure GLAccountsClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	GLAccountsInDocumentsClient.OpenCounterpartyGLAccountsForm(ThisObject, Object, "");
	
EndProcedure

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
		Object.SupplierPriceTypes = ClosingResult.SupplierPriceTypes;
		Object.AutomaticVATCalculation = ClosingResult.AutomaticVATCalculation;
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			
			DriveClient.RefillTabularSectionPricesBySupplierPriceTypes(ThisObject, "Inventory")
			
		EndIf;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices And ClosingResult.RecalculatePrices Then
			
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "Inventory");
			RecalculateReceiptPricesByCurrency(DocCurRecalcStructure);
			
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			
			FillVATRateByVATTaxation();
			
			FillAddedColumns(True);
			
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices
			And Not ClosingResult.AmountIncludesVAT = ClosingResult.PrevAmountIncludesVAT Then
			
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisObject, "Inventory", PricesPrecision);
			RecalculateAmountReceiptByFlagAmountIncludesVAT();
			
		EndIf;
		
		For Each TabularSectionRow In Object.Inventory Do
			// Amount of brokerage
			CalculateCommissionRemuneration(TabularSectionRow);
		EndDo;
		RecalculateSubtotal();
		
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
	
	GenerateLabelPricesAndCurrency();	
	ProcessChangesOnButtonPricesAndCurrenciesEndAtServer();
	
EndProcedure

&AtServer
Procedure ProcessChangesOnButtonPricesAndCurrenciesEndAtServer()
	SetPrepaymentColumnsProperties();
EndProcedure

&AtClient
// Procedure-handler of the answer to the question about repeated advances offset
//
Procedure DefineAdvancePaymentOffsetsRefreshNeed(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Object.Prepayment.Clear();
		HandleCounterpartiesPriceKindChangeAndSettlementsCurrency(AdditionalParameters);
		
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

&AtClient
// Procedure-handler response on question about document recalculate by contract data
//
Procedure DefineDocumentRecalculateNeedByContractTerms(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		ContractData = AdditionalParameters.ContractData;
		
		Object.SupplierPriceTypes = ContractData.SupplierPriceTypes;
		GenerateLabelPricesAndCurrency();
		
		// Recalculate prices by kind of prices.
		If Object.Inventory.Count() > 0 Then
			
			DriveClient.RefillTabularSectionPricesBySupplierPriceTypes(ThisObject, "Inventory");
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region FormTableItemsEventHandlersInventory

&AtClient
// Procedure - event handler OnChange of the Products input field.
//
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = CreateGeneralAttributeValuesStructure(ThisObject, "Inventory", TabularSectionRow);
	
	If ValueIsFilled(Object.SupplierPriceTypes) Then
		
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("SupplierPriceTypes", Object.SupplierPriceTypes);
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("Counterparty",	Object.Counterparty);

	EndIf;
	
	StructureData = GetDataProductsOnChange(StructureData);
	FillPropertyValues(TabularSectionRow, StructureData);
	
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Price = 0;
	TabularSectionRow.AmountReceipt = TabularSectionRow.Quantity * TabularSectionRow.ReceiptPrice;
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.ReceiptVATAmount = ?(
		Object.AmountIncludesVAT,
		TabularSectionRow.AmountReceipt
		- (TabularSectionRow.AmountReceipt)
		/ ((VATRate + 100)
		/ 100),
		TabularSectionRow.AmountReceipt
		* VATRate
		/ 100);
	
	CalculateAmountInTabularSectionLine();
	CalculateCommissionRemuneration(TabularSectionRow);
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow, , UseSerialNumbersBalance);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the variant input field.
//
Procedure InventoryCharacteristicOnChange(Item)
	
	If ValueIsFilled(Object.SupplierPriceTypes) Then
	
		TabularSectionRow = Items.Inventory.CurrentData;
		
		StructureData = New Structure;
		StructureData.Insert("ProcessingDate",		Object.Date);
		StructureData.Insert("SupplierPriceTypes",	Object.SupplierPriceTypes);
		StructureData.Insert("DocumentCurrency",		Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
		StructureData.Insert("Counterparty",		Object.Counterparty);
		StructureData.Insert("Company",				Object.Company);

		StructureData.Insert("VATRate", 		 	TabularSectionRow.VATRate);
		StructureData.Insert("Products",		TabularSectionRow.Products);
		StructureData.Insert("Characteristic",		TabularSectionRow.Characteristic);
		StructureData.Insert("MeasurementUnit",	TabularSectionRow.MeasurementUnit);
		StructureData.Insert("ReceiptPrice",		TabularSectionRow.ReceiptPrice);
		
		StructureData = GetDataCharacteristicOnChange(StructureData);
		
		TabularSectionRow.ReceiptPrice = StructureData.ReceiptPrice;
		
		TabularSectionRow.AmountReceipt = TabularSectionRow.Quantity * TabularSectionRow.ReceiptPrice;
	
		VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);

		TabularSectionRow.ReceiptVATAmount = ?(Object.AmountIncludesVAT, 
													TabularSectionRow.AmountReceipt - (TabularSectionRow.AmountReceipt) / ((VATRate + 100) / 100),
													TabularSectionRow.AmountReceipt * VATRate / 100);
    		
        CalculateAmountInTabularSectionLine();
		CalculateCommissionRemuneration(TabularSectionRow);
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Count input field.
//
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Amount of income.
	TabularSectionRow.AmountReceipt = TabularSectionRow.ReceiptPrice * TabularSectionRow.Quantity;
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.ReceiptVATAmount = ?(Object.AmountIncludesVAT, 
													TabularSectionRow.AmountReceipt - (TabularSectionRow.AmountReceipt) / ((VATRate + 100) / 100),
													TabularSectionRow.AmountReceipt * VATRate / 100);
	// Amount of brokerage
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure

&AtClient
// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
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

&AtClient
// Procedure - event handler OnChange of the Price input field.
//
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	TabularSectionRow = Items.Inventory.CurrentData;
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Amount input field.
//
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
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the VATRate input field.
//
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
	TabularSectionRow.ReceiptVATAmount = ?(Object.AmountIncludesVAT, 
													TabularSectionRow.AmountReceipt - (TabularSectionRow.AmountReceipt) / ((VATRate + 100) / 100),
													TabularSectionRow.AmountReceipt * VATRate / 100);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the VATRate input field.
//
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the ReceiptPrice input field.
//
Procedure InventoryIncreasePriceOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Amount of income.
	TabularSectionRow.AmountReceipt = TabularSectionRow.Quantity * TabularSectionRow.ReceiptPrice;
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
	TabularSectionRow.ReceiptVATAmount = ?(Object.AmountIncludesVAT, 
													TabularSectionRow.AmountReceipt - (TabularSectionRow.AmountReceipt) / ((VATRate + 100) / 100),
													TabularSectionRow.AmountReceipt * VATRate / 100);
	
	// Amount of brokerage
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the AmountReceipt input field.
//
Procedure InventoryAmountReceiptOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.ReceiptPrice = TabularSectionRow.AmountReceipt / TabularSectionRow.Quantity;
	EndIf;
	
	// VAT amount received.
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
	TabularSectionRow.ReceiptVATAmount = ?(Object.AmountIncludesVAT, 
													TabularSectionRow.AmountReceipt - (TabularSectionRow.AmountReceipt) / ((VATRate + 100) / 100),
													TabularSectionRow.AmountReceipt * VATRate / 100);
		
	// Amount of brokerage
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the BrokerageAmount input field.
//
Procedure InventoryBrokerageAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	VATRate = DriveReUse.GetVATRateValue(Object.VATCommissionFeePercent);
			
	TabularSectionRow.BrokerageVATAmount = ?(Object.AmountIncludesVAT, 
													TabularSectionRow.BrokerageAmount - (TabularSectionRow.BrokerageAmount) / ((VATRate + 100) / 100),
													TabularSectionRow.BrokerageAmount * VATRate / 100);
	
EndProcedure

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection();

EndProcedure

&AtClient
Procedure InventoryIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "Inventory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentData = Items.Inventory.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData, , UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Clone)
	
	If NewRow AND Clone Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;	
	
	If Item.CurrentItem.Name = "InventorySerialNumbers" Then
		OpenSerialNumbersSelection();
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	
EndProcedure

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "InventoryIncomeAndExpenseItems" Then
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
		If TableCurrentColumn.Name = "InventoryIncomeAndExpenseItems"
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

// Procedure - event handler OnChange of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnChange(Item)
	
	RecalculateSubtotal();
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

&AtClient
Procedure InventorySalesOrderOnChange(Item)
	
	CurrentRow = Items.Inventory.CurrentData;
	If ValueIsFilled(CurrentRow.SalesOrder) Then
		CurrentRow.SalesRep = SalesRep(CurrentRow.SalesOrder);
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

&AtClient
Procedure SalesRepOnChange(Item)
	If Object.Inventory.Count() > 1 Then
		FillSalesRepInInventory(Object.Inventory[0].SalesRep);
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersPrepayment

&AtClient
Procedure PrepaymentAccountsAmountOnChange(Item)
	
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
	
	Totals = PaymentTermsClientServer.CalculateDocumentAmountVATAmountTotals(Object);
	
	CurrentRow.PaymentAmount = Round(Totals.Amount * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount = Round(Totals.VATAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPaymentAmount input field.
//
&AtClient
Procedure PaymentCalendarPaymentSumOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	Totals = PaymentTermsClientServer.CalculateDocumentAmountVATAmountTotals(Object);
	
	CurrentRow.PaymentPercentage = ?(Totals.Amount = 0, 0, Round(CurrentRow.PaymentAmount / Totals.Amount * 100, 2, 1));
	CurrentRow.PaymentVATAmount = Round(Totals.VATAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPayVATAmount input field.
//
&AtClient
Procedure PaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	Totals = PaymentTermsClientServer.CalculateDocumentAmountVATAmountTotals(Object);
	
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentVATAmount");
	
	If PaymentCalendarTotal > Totals.Amount Then
		CurrentRow.PaymentVATAmount = CurrentRow.PaymentVATAmount - (PaymentCalendarTotal - Totals.Amount);
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
		
		Totals = PaymentTermsClientServer.CalculateDocumentAmountVATAmountTotals(Object);
		
		CurrentRow.PaymentPercentage = 100 - Object.PaymentCalendar.Total("PaymentPercentage");
		CurrentRow.PaymentAmount = Totals.Amount - Object.PaymentCalendar.Total("PaymentAmount");
		CurrentRow.PaymentVATAmount = Totals.VATAmount - Object.PaymentCalendar.Total("PaymentVATAmount");
		
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

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
// Procedure is called by clicking the PricesCurrency button of the command bar tabular field.
//
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies();
		
EndProcedure

&AtClient
// Procedure - command handler of the tabular section command panel.
//
Procedure EditPrepaymentOffset(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(, NStr("en = 'Please select a consignor.'; ru = 'Выберите комитента.';pl = 'Wybierz komitenta.';es_ES = 'Por favor, seleccione un remitente.';es_CO = 'Por favor, seleccione un remitente.';tr = 'Lütfen, gönderici seçin.';it = 'Si prega di selezionare il committente per la merce in conto vendita.';de = 'Bitte wählen Sie einen Kommittenten aus.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Contract) Then
		ShowMessageBox(, NStr("en = 'Please select a consignee.'; ru = 'Выберите комиссионера.';pl = 'Wybierz komisanta.';es_ES = 'Por favor, seleccione un destinatario.';es_CO = 'Por favor, seleccione un destinatario.';tr = 'Lütfen mal alıcısını seçin.';it = 'Si prega di selezionare un agente conto vendita.';de = 'Bitte wählen Sie einen Kommissionär aus.'"));
		Return;
	EndIf;
	
	OrdersArray = New Array;
	For Each CurItem In Object.Inventory Do
		OrderStructure = New Structure("Order, Total");
		OrderStructure.Order = CurItem.PurchaseOrder;
		OrderStructure.Total = CurItem.Total;
		OrdersArray.Add(OrderStructure);
	EndDo;
	
	AddressPrepaymentInStorage = PlacePrepaymentToStorage();
	SelectionParameters = New Structure;
	SelectionParameters.Insert("AddressPrepaymentInStorage", AddressPrepaymentInStorage);
	SelectionParameters.Insert("Pick", True);
	SelectionParameters.Insert("IsOrder", True);
	SelectionParameters.Insert("OrderInHeader", False);
	SelectionParameters.Insert("Company", ParentCompany);
	SelectionParameters.Insert("Order", ?(CounterpartyDoSettlementsByOrders, OrdersArray, Undefined));
	SelectionParameters.Insert("Date", Object.Date);
	SelectionParameters.Insert("Ref", Object.Ref);
	SelectionParameters.Insert("Counterparty", Object.Counterparty);
	SelectionParameters.Insert("Contract", Object.Contract);
	SelectionParameters.Insert("ExchangeRate", Object.ExchangeRate);
	SelectionParameters.Insert("Multiplicity", Object.Multiplicity);
	SelectionParameters.Insert("ContractCurrencyExchangeRate", Object.ContractCurrencyExchangeRate);
	SelectionParameters.Insert("ContractCurrencyMultiplicity", Object.ContractCurrencyMultiplicity);
	SelectionParameters.Insert("DocumentCurrency", Object.DocumentCurrency);
	SelectionParameters.Insert("DocumentAmount", Object.Inventory.Total("Total"));
	
	ReturnCode = Undefined;
	
	OpenForm("CommonForm.SelectAdvancesPaidToTheSupplier", SelectionParameters,,,,, New NotifyDescription("EditPrepaymentOffsetEnd", ThisObject, New Structure("AddressPrepaymentInStorage", AddressPrepaymentInStorage)));
	
EndProcedure

&AtClient
Procedure EditPrepaymentOffsetEnd(Result, AdditionalParameters) Export
    
    AddressPrepaymentInStorage = AdditionalParameters.AddressPrepaymentInStorage;
    
    
    ReturnCode = Result;
    
    If ReturnCode = DialogReturnCode.OK Then
        GetPrepaymentFromStorage(AddressPrepaymentInStorage);
		
		Modified = True;
    EndIf;

EndProcedure

// Peripherals
// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en = 'Enter barcode'; ru = 'Введите штрихкод';pl = 'Wprowadź kod kreskowy';es_ES = 'Introducir el código de barras';es_CO = 'Introducir el código de barras';tr = 'Barkod girin';it = 'Inserisci codice a barre';de = 'Geben Sie den Barcode ein'"));

EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
    
    CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);    
    
    If Not IsBlankString(CurBarcode) Then
        BarcodesReceived(New Structure("Barcode, Quantity", TrimAll(CurBarcode), 1));
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
			
			// Amount of income.
			TabularSectionRow.AmountReceipt = TabularSectionRow.ReceiptPrice * TabularSectionRow.Quantity;
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.ReceiptVATAmount = ?(
				Object.AmountIncludesVAT, 
				TabularSectionRow.AmountReceipt - (TabularSectionRow.AmountReceipt) / ((VATRate + 100) / 100),
				TabularSectionRow.AmountReceipt * VATRate / 100
			);
			
			// Amount of brokerage
			CalculateCommissionRemuneration(TabularSectionRow);
			
			RecalculateSubtotal();
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - ImportDataFromDTC command handler.
//
&AtClient
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") 
	   AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

// End Peripherals

#EndRegion

#Region Private

#Region GeneralPurposeProceduresAndFunctions

&AtClient
// The procedure handles the change of the Price type and Settlement currency document attributes
//
Procedure HandleCounterpartiesPriceKindChangeAndSettlementsCurrency(DocumentParameters)
	
	ContractData = DocumentParameters.ContractData;
	PriceKindChanged = DocumentParameters.PriceKindChanged;
	QuestionSupplierPriceTypes = DocumentParameters.QuestionSupplierPriceTypes;
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
	
	If PriceKindChanged Then
		Object.SupplierPriceTypes = ContractData.SupplierPriceTypes;
	EndIf;
	
	If ValueIsFilled(SettlementsCurrency) Then
		Object.DocumentCurrency = SettlementsCurrency;
	EndIf;
	
	GenerateLabelPricesAndCurrency();
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		If PriceKindChanged Then
			
			WarningText = MessagesToUserClientServer.GetPriceTypeOnChangeWarningText(False);
			
		EndIf;
		
		WarningText = WarningText
			+ ?(IsBlankString(WarningText), "", Chars.LF + Chars.LF)
			+ MessagesToUserClientServer.GetSettleCurrencyOnChangeWarningText();
		
		ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange, True, PriceKindChanged, WarningText);
		
	ElsIf QuestionSupplierPriceTypes Then
		
		If Object.Inventory.Count() > 0 Then
			
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
	
	PerInvoiceVATRoundingRule = StructureData.PerInvoiceVATRoundingRule;
	RegisteredForVAT = StructureData.RegisteredForVAT;
	SetAutomaticVATCalculation();
	
	If ValueIsFilled(SettlementsCurrency) Then
		RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
	EndIf;
	
	ProcessingCompanyVATNumbers();
	
	GenerateLabelPricesAndCurrency();
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServer
// It receives data set from server for the DateOnChange procedure.
//
Function GetDataDateOnChange()
	
	CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.DocumentCurrency, ParentCompany);
	
	StructureData = New Structure;
	StructureData.Insert("CurrencyRateRepetition", CurrencyRateRepetition);
	
	If Object.DocumentCurrency <> SettlementsCurrency Then
		
		SettlementsCurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, SettlementsCurrency, ParentCompany);
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", SettlementsCurrencyRateRepetition);
		
	Else
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", CurrencyRateRepetition);
		
	EndIf;
	
	PaymentTermsServer.ShiftPaymentCalendarDates(Object, ThisObject);
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Object.Date, ParentCompany);
	StructureData.Insert("PerInvoiceVATRoundingRule", AccountingPolicy.PerInvoiceVATRoundingRule);
	StructureData.Insert("RegisteredForVAT", AccountingPolicy.RegisteredForVAT);
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction

&AtServer
// Receives the data set from the server for the CompanyOnChange procedure.
//
Function GetCompanyDataOnChange(Company)
	
	FillAddedColumns(True);
	
	StructureData = New Structure();
	StructureData.Insert("Company"           , DriveServer.GetCompany(Company));
	StructureData.Insert("ExchangeRateMethod", DriveServer.GetExchangeMethod(StructureData.Company));
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Object.Date, StructureData.Company);
	PerInvoiceVATRoundingRule = AccountingPolicy.PerInvoiceVATRoundingRule;
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure SetAutomaticVATCalculation()
	Object.AutomaticVATCalculation = PerInvoiceVATRoundingRule;
EndProcedure

&AtServerNoContext
// Receives the set of data from the server for the ProductsOnChange procedure.
//
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
	
	If StructureData.Property("SupplierPriceTypes") Then
		
		ReceiptPrice = DriveServer.GetPriceProductsBySupplierPriceTypes(StructureData);
		StructureData.Insert("ReceiptPrice", ReceiptPrice);
		
	Else
		
		StructureData.Insert("ReceiptPrice", 0);
		
	EndIf;
	
	IncomeAndExpenseItemsInDocuments.FillProductIncomeAndExpenseItems(StructureData);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// It receives data set from server for the CharacteristicOnChange procedure.
//
Function GetDataCharacteristicOnChange(StructureData)
	
	If StructureData.Property("SupplierPriceTypes") Then
		
		If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
			StructureData.Insert("Factor", 1);
		Else
			StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
		EndIf;		
		
		ReceiptPrice = DriveServer.GetPriceProductsBySupplierPriceTypes(StructureData);
		StructureData.Insert("ReceiptPrice", ReceiptPrice);
		
	EndIf;
		
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
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

&AtServer
// It receives data set from the server for the CounterpartyOnChange procedure.
//
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	FillVATRateByCompanyVATTaxation(True);
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True);
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
		CurrencyRateOperations.GetCurrencyRate(Date, ContractByDefault.SettlementsCurrency, Object.Company)
	);
	
	StructureData.Insert(
		"SupplierPriceTypes",
		ContractByDefault.SupplierPriceTypes
	);
	
	StructureData.Insert(
		"SupplierPriceTypes",
		ContractByDefault.SupplierPriceTypes
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(ContractByDefault.SupplierPriceTypes), ContractByDefault.SupplierPriceTypes.PriceIncludesVAT, Undefined)
	);
	
	StructureData.Insert(
		"SalesRep",
		Common.ObjectAttributeValue(Counterparty, "SalesRep"));
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction

&AtServer
// It receives data set from server for the ContractOnChange procedure.
//
Function GetDataContractOnChange(Date, DocumentCurrency, Contract)
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True);
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
		"SupplierPriceTypes",
		Contract.SupplierPriceTypes
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(Contract.SupplierPriceTypes), Contract.SupplierPriceTypes.PriceIncludesVAT, Undefined)
	);
	
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
			Object.VATCommissionFeePercent = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date,
				Object.Company);
			FillVATRateByVATTaxation();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.InventoryVATSummOfArrival.Visible = True;
		Items.InventoryTotalAmountOfVAT.Visible = True;
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
											
			TabularSectionRow.ReceiptVATAmount = ?(Object.AmountIncludesVAT, 
													TabularSectionRow.AmountReceipt - (TabularSectionRow.AmountReceipt) / ((VATRate + 100) / 100),
													TabularSectionRow.AmountReceipt * VATRate / 100);								
											
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;	
		
	Else
		
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.InventoryVATSummOfArrival.Visible = False;
		Items.InventoryTotalAmountOfVAT.Visible = False;
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
			TabularSectionRow.ReceiptVATAmount = 0;
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;	
		
	EndIf;	
	
EndProcedure

&AtClient
// VAT amount is calculated in the row of tabular section.
//
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  TabularSectionRow.Amount * VATRate / 100);
	
EndProcedure

&AtClient
// Procedure calculates the amount in the row of tabular section.
//
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	// Amount.
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Serial numbers
	If UseSerialNumbersBalance <> Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow);
	EndIf;
	
EndProcedure

&AtClient
// Calculates the brokerage in the row of the document tabular section
//
// Parameters:
//  TabularSectionRow - String of the document tabular section.
//
Procedure CalculateCommissionRemuneration(TabularSectionRow)
	
	If Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.PercentFromSaleAmount") Then
		
		TabularSectionRow.BrokerageAmount = Object.CommissionFeePercent * TabularSectionRow.Amount / 100;
		
	ElsIf Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.PercentFromDifferenceOfSaleAndAmountReceipts") Then
		
		TabularSectionRow.BrokerageAmount = Object.CommissionFeePercent * (TabularSectionRow.Amount - TabularSectionRow.AmountReceipt) / 100;
		
	Else // Enum.CommissionFeeCalculationMethods.IsNotCalculating
		
		TabularSectionRow.BrokerageAmount = 0;
		
	EndIf;
	
	VATRate = DriveReUse.GetVATRateValue(Object.VATCommissionFeePercent);
	
	TabularSectionRow.BrokerageVATAmount = ?(Object.AmountIncludesVAT, 
	TabularSectionRow.BrokerageAmount - (TabularSectionRow.BrokerageAmount) / ((VATRate + 100) / 100),
	TabularSectionRow.BrokerageAmount * VATRate / 100);
	
EndProcedure

&AtClient
// Recalculate price by document tabular section currency after changes in the "Prices and currency" form.
//
Procedure RecalculateReceiptPricesByCurrency(RatesStructure)
	
	For Each TabularSectionRow In Object.Inventory Do
		
		TabularSectionRow.ReceiptPrice = DriveServer.RecalculateFromCurrencyToCurrency(TabularSectionRow.ReceiptPrice,
			ExchangeRateMethod,
			RatesStructure.InitRate,
			RatesStructure.Rate,
			RatesStructure.RepetitionBeg,
			RatesStructure.Repetition,
			PricesPrecision);
		
		TabularSectionRow.AmountReceipt = TabularSectionRow.Quantity * TabularSectionRow.ReceiptPrice;
		
		VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
		
		TabularSectionRow.ReceiptVATAmount = ?(Object.AmountIncludesVAT,
			TabularSectionRow.AmountReceipt - (TabularSectionRow.AmountReceipt) / ((VATRate + 100) / 100),
			TabularSectionRow.AmountReceipt * VATRate / 100);
		

	EndDo;
	
EndProcedure

&AtClient
// Recalculate prices by the AmountIncludesVAT check box of the tabular section after changes in form "Prices and currency".
//
Procedure RecalculateAmountReceiptByFlagAmountIncludesVAT()
	
	For Each TabularSectionRow In Object.Inventory Do
		
		VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
		
		If Object.AmountIncludesVAT Then
				TabularSectionRow.ReceiptPrice = Round((TabularSectionRow.ReceiptPrice * (100 + VATRate)) / 100, PricesPrecision);
		Else
				TabularSectionRow.ReceiptPrice = Round((TabularSectionRow.ReceiptPrice * 100) / (100 + VATRate), PricesPrecision);
		EndIf;
		
		TabularSectionRow.AmountReceipt = TabularSectionRow.Quantity * TabularSectionRow.ReceiptPrice;
		
		TabularSectionRow.ReceiptVATAmount = ?(Object.AmountIncludesVAT,
			TabularSectionRow.AmountReceipt - (TabularSectionRow.AmountReceipt) / ((VATRate + 100) / 100),
			TabularSectionRow.AmountReceipt * VATRate / 100);
		
	EndDo;
	
EndProcedure

&AtClient
// Recalculates the exchange rate and multiplicity of
// the payment currency when the document date is changed.
//
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
		
		NotifyDescription = New NotifyDescription("RecalculatePaymentCurrencyRateConversionFactorEnd", ThisObject, AdditionalParameters);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
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

	GenerateLabelPricesAndCurrency();

EndProcedure

&AtClient
// Procedure executes recalculate in the document tabular section
// after changes in "Prices and currency" form.Column recalculation is executed:
// price, discount, amount, VAT amount, total.
//
Procedure ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange = Undefined, RecalculatePrices = False, RefillPrices = False, WarningText = "")
	
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
	ParametersStructure.Insert("ContractCurrencyExchangeRate",	Object.ContractCurrencyExchangeRate);
	ParametersStructure.Insert("ContractCurrencyMultiplicity",	Object.ContractCurrencyMultiplicity);
	ParametersStructure.Insert("VATTaxation",					Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice",				Object.IncludeVATInPrice);
	ParametersStructure.Insert("Counterparty",					Object.Counterparty);
	ParametersStructure.Insert("Contract",						Object.Contract);
	ParametersStructure.Insert("Company",						ParentCompany);
	ParametersStructure.Insert("DocumentDate",					Object.Date);
	ParametersStructure.Insert("RefillPrices",					RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",				RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",				False);
	ParametersStructure.Insert("SupplierPriceTypes",			Object.SupplierPriceTypes);
	ParametersStructure.Insert("WarningText", 					WarningText);
	ParametersStructure.Insert("ReverseChargeNotApplicable",	True);
	ParametersStructure.Insert("AutomaticVATCalculation",		Object.AutomaticVATCalculation);
	ParametersStructure.Insert("PerInvoiceVATRoundingRule",		PerInvoiceVATRoundingRule);
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, AttributesBeforeChange);
	OpenForm("CommonForm.PricesAndCurrency", ParametersStructure, ThisObject, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
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
			AND BarcodeData.Count() <> 0 Then
			
			StructureProductsData = CreateGeneralAttributeValuesStructure(StructureData, "Inventory", BarcodeData);
			
			StructureProductsData.Insert("Counterparty", StructureData.Counterparty);
			StructureProductsData.Insert("Characteristic", BarcodeData.Characteristic);
			If ValueIsFilled(StructureData.SupplierPriceTypes) Then
				StructureProductsData.Insert("ProcessingDate", StructureData.Date);
				StructureProductsData.Insert("DocumentCurrency", StructureData.DocumentCurrency);
				StructureProductsData.Insert("AmountIncludesVAT", StructureData.AmountIncludesVAT);
				StructureProductsData.Insert("SupplierPriceTypes", StructureData.SupplierPriceTypes);
				If ValueIsFilled(BarcodeData.MeasurementUnit)
					AND TypeOf(BarcodeData.MeasurementUnit) = Type("CatalogRef.UOM") Then
					StructureProductsData.Insert("Factor", BarcodeData.MeasurementUnit.Factor);
				Else
					StructureProductsData.Insert("Factor", 1);
				EndIf;
			EndIf;
			
			IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInBarcodeData(
				StructureProductsData, StructureData.Object, "AccountSalesToConsignor");
				
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
	StructureData.Insert("Counterparty", Object.Counterparty);
	StructureData.Insert("SupplierPriceTypes", Object.SupplierPriceTypes);
	StructureData.Insert("Date", Object.Date);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("Object", Object);
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object.Inventory.FindRows(New Structure("Products,Characteristic,Batch,MeasurementUnit",BarcodeData.Products,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.ReceiptPrice = BarcodeData.StructureProductsData.ReceiptPrice;
				NewRow.VATRate = BarcodeData.StructureProductsData.VATRate;
				NewRow.AmountReceipt = NewRow.Quantity * NewRow.ReceiptPrice;
				VATRate = DriveReUse.GetVATRateValue(NewRow.VATRate);
				NewRow.ReceiptVATAmount = ?(
					Object.AmountIncludesVAT,
					NewRow.AmountReceipt
					- (NewRow.AmountReceipt)
					/ ((VATRate + 100)
					/ 100),
					NewRow.AmountReceipt
					*
					VATRate
					/ 100);
				NewRow.RevenueItem = BarcodeData.StructureProductsData.RevenueItem;
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
				WorkWithSerialNumbersClientServer.AddSerialNumberToString(NewRow, BarcodeData.SerialNumber, Object);
			EndIf;
			
			Modified = True;
		EndIf;
	EndDo;
	
	If Modified Then
		RecalculateSubtotal();
	EndIf;
	
	Return UnknownBarcodes;

EndFunction

// Procedure processes the received barcodes.
//
&AtClient
Procedure BarcodesReceived(BarcodesData)
	
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

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByBasis(Basis)
	
	Document = FormAttributeToValue("Object");
	
	If TypeOf(Basis) = Type("CatalogRef.Counterparties") Then
	
		// Add attributes to the filling structure, that have already been specified in the document
		FillingData = New Structure();
		FillingData.Insert("Counterparty",  Basis);
		FillingData.Insert("Contract", 	 Object.Contract);
		FillingData.Insert("Company", Object.Company);
		FillingData.Insert("SupplierPriceTypes", Object.SupplierPriceTypes);
		Document.Fill(FillingData);
		
	Else
		
		Document.Fill(Basis);
		
	EndIf;
	
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	FillAddedColumns();
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.InventoryTotalAmountOfVAT.Visible = True;
		
	Else
		
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.InventoryTotalAmountOfVAT.Visible = False;
		
	EndIf;
	
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
			
			DocumentParameters.Insert("CounterpartyDoSettlementsByOrdersBeforeChange", ContractData.CounterpartyDoSettlementsByOrdersBeforeChange);
			DocumentParameters.Insert("CounterpartyBeforeChange", ContractData.CounterpartyBeforeChange);
			
		EndIf;
		
		PriceKindChanged = Object.SupplierPriceTypes <> ContractData.SupplierPriceTypes AND ValueIsFilled(ContractData.SupplierPriceTypes);
		QuestionSupplierPriceTypes = (ValueIsFilled(Object.Contract) AND PriceKindChanged);
		
		SettlementsCurrency = ContractData.SettlementsCurrency;
		
		OpenFormPricesAndCurrencies = ValueIsFilled(Object.Contract) And ValueIsFilled(SettlementsCurrency)
			And Object.DocumentCurrency <> SettlementsCurrency And Object.Inventory.Count() > 0;
		
		DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
		DocumentParameters.Insert("ContractData", ContractData);
		DocumentParameters.Insert("PriceKindChanged", PriceKindChanged);
		DocumentParameters.Insert("QuestionSupplierPriceTypes", QuestionSupplierPriceTypes);
		DocumentParameters.Insert("OpenFormPricesAndCurrencies", OpenFormPricesAndCurrencies);
		DocumentParameters.Insert("ContractVisibleBeforeChange", Items.Contract.Visible);
		
		If Object.Prepayment.Count() > 0 Then
			
			QuestionText = NStr("en = 'The prepayment recognition will be cleared. Do you want to continue?'; ru = 'Зачет аванса будет очищен, продолжить?';pl = 'Uznanie przedpłaty zostanie oczyszczone. Czy chcesz kontynuować?';es_ES = 'El reconocimiento de prepago se eliminará. ¿Quiere continuar?';es_CO = 'El reconocimiento de prepago se eliminará. ¿Quiere continuar?';tr = 'Ön ödeme tanıması temizlenecektir. Devam etmek istiyor musunuz?';it = 'Il riconoscimento prepagamento sarà annullato. Volete proseguire?';de = 'Die Anzahlungsaufnahme wird verrechnet. Möchten Sie fortsetzen?'");
			
			NotifyDescription = New NotifyDescription("DefineAdvancePaymentOffsetsRefreshNeed", ThisObject, DocumentParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		Else
			
			HandleCounterpartiesPriceKindChangeAndSettlementsCurrency(DocumentParameters);
			
		EndIf;
		
		FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
		SetVisibleEnablePaymentTermItems();
		
	EndIf;
	
EndProcedure

// Procedure recalculates subtotal the document on client.
&AtClient
Procedure RecalculateSubtotal()
	
	DocumentSubtotal = Object.Inventory.Total("Total") - Object.Inventory.Total("VATAmount");
	
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

&AtClient
Procedure GenerateLabelPricesAndCurrency()
	
	LabelStructure = New Structure;
	LabelStructure.Insert("SupplierPriceTypes", Object.SupplierPriceTypes);
	LabelStructure.Insert("DocumentCurrency", Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency", SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate", Object.ExchangeRate);
	LabelStructure.Insert("RateNationalCurrency", RateNationalCurrency);
	LabelStructure.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting", ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation", Object.VATTaxation);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure OpenSerialNumbersSelection()
		
	CurrentDataIdentifier = Items.Inventory.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, False);
	
EndFunction

&AtClient
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey);
	
EndFunction

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val CatalogCounterparty)
	
	Attributes = "DoOperationsByContracts, DoOperationsByOrders, VATTaxation";
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, CatalogCounterparty, Attributes);
	
EndProcedure

#Region GLAccounts

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	StrucutreArray = New Array();
	
	If UseDefaultTypeOfAccounting Then
		
		Header = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "Header", Object);
		GLAccountsInDocuments.CompleteCounterpartyStructureData(Header, ObjectParameters, "Header");
		StrucutreArray.Add(Header);
		
	EndIf;
	
	StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters);
	GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters);
	
	StrucutreArray.Add(StructureData);
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StrucutreArray, GetGLAccounts);
	
	If UseDefaultTypeOfAccounting Then
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

#Region WorkWithTheSelection

&AtClient
// Procedure - event handler Action of the Pick command
//
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'account sales to consignor'; ru = 'отчет комитенту';pl = 'Raport sprzedaży komitentowi';es_ES = 'informe de ventas a los remitentes';es_CO = 'ventas de cuenta al remitente';tr = 'konsinye alışlar';it = 'saldo delle vendite per il committente';de = 'Verkaufsbericht (Kommitent) '");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, False);
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

// Procedure - event handler Action of the command Pick of sales.
//
&AtClient
Procedure SelectionBySales(Command)
	
	Cancel = False;
	
	If Not ValueIsFilled(Object.Company) Then
		MessageText = NStr("en = 'Please specify the consignee.'; ru = 'Поле ""Комиссионер"" не заполнено';pl = 'Wybierz komisanta.';es_ES = 'Por favor, especifique el destinatario.';es_CO = 'Por favor, especifique el destinatario.';tr = 'Lütfen müşteri belirleyin.';it = 'Si prega di specificare l''agente in conto vendita.';de = 'Bitte geben Sie den Kommissionär an.'");
		DriveClient.ShowMessageAboutError(ThisObject, MessageText,,, "Company", Cancel);
	EndIf;
	If Not ValueIsFilled(Object.Counterparty) Then
		MessageText = NStr("en = 'Please specify the consignor.'; ru = 'Поле ""Комитент"" не заполнено.';pl = 'Wybierz komitenta.';es_ES = 'Por favor, especifique el remitente.';es_CO = 'Por favor, especifique el remitente.';tr = 'Lütfen, gönderici belirleyin.';it = 'Si prega di specificare il committente.';de = 'Bitte geben Sie den Kommittenten an.'");
		DriveClient.ShowMessageAboutError(ThisObject, MessageText,,, "Counterparty", Cancel);
	EndIf;
	If Not ValueIsFilled(Object.Contract) Then
		MessageText = NStr("en = 'Please specify the contract.'; ru = 'Поле ""Договор"" не заполнено';pl = 'Określ umowę.';es_ES = 'Por favor, especifique el contrato.';es_CO = 'Por favor, especifique el contrato.';tr = 'Lütfen, sözleşmeyi belirtin.';it = 'Per piacere specificate il contratto.';de = 'Bitte geben Sie den Vertrag an.'");
		DriveClient.ShowMessageAboutError(ThisObject, MessageText,,, "Contract", Cancel);
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	SelectionParameters = New Structure("
		|ParentCompany,
		|Company,
		|Counterparty,
		|Contract,
		|DocumentCurrency,
		|SupplierPriceTypes,
		|DocumentDate,
		|CurrentDocument",
		ParentCompany,
		Object.Company,
		Object.Counterparty,
		Object.Contract,
		Object.DocumentCurrency,
		Object.SupplierPriceTypes,
		Object.Date,
		Object.Ref
	);
	
	OpenForm("Document.AccountSalesToConsignor.Form.PickFormBySales", SelectionParameters, ThisObject);
	
EndProcedure

&AtServer
// Function gets a product list from the temporary storage
//
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	For Each ImportRow In TableForImport Do
		
		NewRow 					= Object[TabularSectionName].Add();
		NewRow.ReceiptPrice 	= ImportRow.Price;
		NewRow.AmountReceipt 	= ImportRow.Amount;
		NewRow.ReceiptVATAmount = ImportRow.VATAmount;
		
		ImportRow.Price 	= 0;
		ImportRow.Amount 	= 0;
		ImportRow.VATAmount = 0;
		ImportRow.Total 	= 0;
		
		FillPropertyValues(NewRow, ImportRow);
		
		IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInRow(ObjectParameters, NewRow, TabularSectionName);
		
	EndDo;
	
EndProcedure

// Function gets the list of inventory accepted from the temporary storage
//
&AtServer
Procedure GetInventoryAcceptedFromStorage(AddressInventoryAcceptedInStorage)
	
	StockReceivedFromThirdParties = GetFromTempStorage(AddressInventoryAcceptedInStorage);
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	For Each TabularSectionRow In StockReceivedFromThirdParties Do
		
		NewRow = Object.Inventory.Add();
		FillPropertyValues(NewRow, TabularSectionRow);
		
		StructureData = CreateGeneralAttributeValuesStructure(ThisObject, "Inventory", TabularSectionRow);
		StructureData = GetDataProductsOnChange(StructureData);
		
		NewRow.MeasurementUnit = StructureData.MeasurementUnit;
		NewRow.VATRate = StructureData.VATRate;
		
		If TabularSectionRow.Quantity > TabularSectionRow.Balance
			OR TabularSectionRow.Quantity = 0 Then
			NewRow.Price = 0;
			NewRow.Amount = 0;
			NewRow.ReceiptPrice = 0;
		ElsIf TabularSectionRow.Quantity < TabularSectionRow.Balance Then
			NewRow.Amount = NewRow.Price * NewRow.Quantity;
		EndIf;
		NewRow.AmountReceipt = NewRow.ReceiptPrice * NewRow.Quantity;
		
		VATRate = DriveReUse.GetVATRateValue(NewRow.VATRate);
		
		NewRow.VATAmount = ?(Object.AmountIncludesVAT,
								NewRow.Amount - (NewRow.Amount) / ((VATRate + 100) / 100),
								NewRow.Amount * VATRate / 100);
								
		If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			VATAmount = ?(Object.AmountIncludesVAT, 0, NewRow.VATAmount);
		Else
			VATAmount = 0
		EndIf;
		NewRow.Total = TabularSectionRow.Amount + VATAmount;
		
		NewRow.ReceiptVATAmount = ?(Object.AmountIncludesVAT,
											NewRow.AmountReceipt - (NewRow.AmountReceipt) / ((VATRate + 100) / 100),
											NewRow.AmountReceipt * VATRate / 100);
		
		If Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating") Then
			// Do nothing
		ElsIf Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.PercentFromSaleAmount") Then
			NewRow.BrokerageAmount = Object.CommissionFeePercent * NewRow.Amount / 100;
		ElsIf Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.PercentFromDifferenceOfSaleAndAmountReceipts") Then
			NewRow.BrokerageAmount = Object.CommissionFeePercent * (NewRow.Amount - NewRow.AmountReceipt) / 100;
		Else
			NewRow.BrokerageAmount = 0;
		EndIf;
		VATRate = DriveReUse.GetVATRateValue(Object.VATCommissionFeePercent);
		NewRow.BrokerageVATAmount = ?(Object.AmountIncludesVAT,
												NewRow.BrokerageAmount - (NewRow.BrokerageAmount) / ((VATRate + 100) / 100),
												NewRow.BrokerageAmount * VATRate / 100);
												
		IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInRow(ObjectParameters, NewRow, "Inventory");
		
	EndDo;
	
EndProcedure

&AtServer
// Function places the list of advances into temporary storage and returns the address
//
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

&AtServer
// Function gets the list of advances from the temporary storage
//
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
			GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True, True);
			
			Modified = True;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

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

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.InventoryPrice);
	Fields.Add(Items.InventoryPriceOfEntering);
	
	Return Fields;
	
EndFunction

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
	
	Return DriveServer.GetCalculatedAdvancePaidExchangeRate(ParametersStructure);
	
EndFunction

&AtClientAtServerNoContext
Function CreateGeneralAttributeValuesStructure(Form, TabName, TabRow)
	
	Object = Form.Object;
	
	StructureData = New Structure("
	|TabName,
	|Object,
	|Company,
	|Products,
	|VATTaxation,
	|IncomeAndExpenseItems,
	|IncomeAndExpenseItemsFilled,
	|RevenueItem");
	
	FillPropertyValues(StructureData, Form);
	FillPropertyValues(StructureData, Object);
	FillPropertyValues(StructureData, TabRow);
	
	StructureData.Insert("TabName", TabName);
	
	Return StructureData;
	
EndFunction

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion