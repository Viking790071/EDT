
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If UsersClientServer.IsExternalUserSession() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	UseForeignCurrency = GetFunctionalOption("ForeignExchangeAccounting");
	
	SetConditionalAppearance();
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues);
		
	DefaultExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("DiscountAllowed");
	
	If Object.PaymentDetails.Count() = 0 Then
		
		NewRow = Object.PaymentDetails.Add();
		NewRow.PaymentAmount = Object.DocumentAmount;
		
		If Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer Then
			NewRow.DiscountAllowedExpenseItem = DefaultExpenseItem;
		EndIf;
		
		NewRow.Multiplicity = 1;
		NewRow.ExchangeRate = 1;
		NewRow.PaymentMultiplier = 1;
		NewRow.PaymentExchangeRate = 1;
		
	EndIf;
	
	DocumentObject = FormAttributeToValue("Object");
	If DocumentObject.IsNew()
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		
		If ValueIsFilled(Parameters.BasisDocument) Then
			DocumentObject.Fill(Parameters.BasisDocument);
			ValueToFormAttribute(DocumentObject, "Object");
		EndIf;
		
		If ValueIsFilled(Object.BankAccount)
			AND TypeOf(Object.BankAccount.Owner) <> Type("CatalogRef.Companies") Then
			Object.BankAccount = Catalogs.BankAccounts.EmptyRef();
		EndIf;
		
		If ValueIsFilled(Object.Company)
			AND ValueIsFilled(Object.BankAccount)
			AND Object.BankAccount.Owner <> Object.Company Then
			Object.Company = Object.BankAccount.Owner;
		EndIf;
		
		If Not ValueIsFilled(Object.BankAccount) Then
			If ValueIsFilled(Object.CashCurrency) Then
				If Object.Company.BankAccountByDefault.CashCurrency = Object.CashCurrency Then
					Object.BankAccount = Object.Company.BankAccountByDefault;
				EndIf;
			Else
				Object.BankAccount = Object.Company.BankAccountByDefault;
				Object.CashCurrency = Object.BankAccount.CashCurrency;
			EndIf;
		Else
			Object.CashCurrency = Object.BankAccount.CashCurrency;
		EndIf;
		
		PresentationCurrency = DriveServer.GetPresentationCurrency(Object.Company);
		
		If ValueIsFilled(Object.CashCurrency) Then
			
			StructureData = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.CashCurrency, Object.Company);
			Object.BankChargeMultiplier = StructureData.Repetition;
			Object.BankChargeExchangeRate = StructureData.Rate;
			Object.Multiplicity = StructureData.Repetition;
			Object.ExchangeRate = StructureData.Rate;
			
			For Each PaymentDetailsRow In Object.PaymentDetails Do
				
				PaymentDetailsRow.SettlementsCurrency = Object.CashCurrency;
				PaymentDetailsRow.PaymentMultiplier = StructureData.Repetition;
				PaymentDetailsRow.PaymentExchangeRate = StructureData.Rate;
				
			EndDo;
			
			CalculateSettlementsAmount(PaymentDetailsRow, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
			
		EndIf;
		
		If Object.OperationKind <> Enums.OperationTypesPaymentReceipt.LoanSettlements 
			AND Object.OperationKind <> Enums.OperationTypesPaymentReceipt.LoanRepaymentByEmployee Then
			
			If ValueIsFilled(Object.Counterparty)
				AND Object.PaymentDetails.Count() > 0
				AND Not ValueIsFilled(Parameters.BasisDocument) Then
				
				If Not ValueIsFilled(Object.PaymentDetails[0].Contract) Then
					Object.PaymentDetails[0].Contract = DriveServer.GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
				EndIf;
				
				If ValueIsFilled(Object.PaymentDetails[0].Contract) Then
					ContractCurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.PaymentDetails[0].Contract.SettlementsCurrency, Object.Company);
					Object.PaymentDetails[0].ExchangeRate = ?(ContractCurrencyRateRepetition.Rate = 0, 1, ContractCurrencyRateRepetition.Rate);
					Object.PaymentDetails[0].Multiplicity = ?(ContractCurrencyRateRepetition.Repetition = 0, 1, ContractCurrencyRateRepetition.Repetition);
					CalculateSettlementsAmount(Object.PaymentDetails[0], ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
				EndIf;
			EndIf;
		EndIf;
		
		SetCFItem();
		
	Else
		
		PresentationCurrency = DriveServer.GetPresentationCurrency(Object.Company);
		
	EndIf;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	SetAccountingPolicyValues();
	
	// Form attributes setting.
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	ExchangeRateMethod = DriveServer.GetExchangeMethod(Object.Company);
	
	WithholdFeeOnPayout = Common.ObjectAttributeValue(Object.POSTerminal, "WithholdFeeOnPayout");
	
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.CashCurrency, Object.Company);
	
	ExchangeRate = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Rate);
		
	Multiplicity = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Repetition);
	
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Object.Date, PresentationCurrency, Object.Company);
	
	AccountingCurrencyRate = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Rate);
		
	AccountingCurrencyMultiplicity = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Repetition);
	
	SupplementOperationTypesChoiceList();
	
	If Not ValueIsFilled(Object.Ref) 
		And Not ValueIsFilled(Parameters.Basis) 
		And Not ValueIsFilled(Parameters.CopyingValue)
		And Not ValueIsFilled(Parameters.BasisDocument) Then
		FillVATRateByCompanyVATTaxation();
	EndIf;
	
	SetVisibleOfVATTaxation();
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
		DefaultVATRate = Catalogs.VATRates.Exempt;
	Else
		DefaultVATRate = Catalogs.VATRates.ZeroRate;
	EndIf;
	
	OperationKind = Object.OperationKind;
	CashCurrency = Object.CashCurrency;
	
	SetVisibilityItemsDependenceOnOperationKindAndUseBankCharges();
	SetVisibilityAmountAttributes();
	SetVisibilityBankChargeAmountAttributes();
	
	// Fill in tabular section while entering a document from the working place.
	If TypeOf(Parameters.FillingValues) = Type("Structure")
		And Parameters.FillingValues.Property("FillDetailsOfPayment")
		And Parameters.FillingValues.FillDetailsOfPayment Then
		
		TabularSectionRow = Object.PaymentDetails[0];
		
		TabularSectionRow.PaymentAmount = Object.DocumentAmount;
		TabularSectionRow.ExchangeRate = ?(
			TabularSectionRow.ExchangeRate = 0,
			1,
			TabularSectionRow.ExchangeRate);
		
		TabularSectionRow.Multiplicity = ?(
			TabularSectionRow.Multiplicity = 0,
			1,
			TabularSectionRow.Multiplicity);
		
		CalculateSettlementsAmount(TabularSectionRow, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
		
		If Not ValueIsFilled(TabularSectionRow.VATRate) Then
			TabularSectionRow.VATRate = DefaultVATRate;
		EndIf;
		
		TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount - (TabularSectionRow.PaymentAmount) / ((TabularSectionRow.VATRate.Rate + 100) / 100);
		
	EndIf;
	
	//Loan contract
	If Object.LoanContract.CommissionType = Enums.LoanCommissionTypes.No Then
		Items.SettlementsOnCreditsPaymentDetailsTypeOfAmount.ChoiceList.Add(Enums.LoanScheduleAmountTypes.Interest);
		Items.SettlementsOnCreditsPaymentDetailsTypeOfAmount.ChoiceList.Add(Enums.LoanScheduleAmountTypes.Principal);
		Items.SettlementsOnCreditsPaymentDetailsTypeOfAmount.ListChoiceMode = True;
	Else
		Items.SettlementsOnCreditsPaymentDetailsTypeOfAmount.ListChoiceMode = False;
	EndIf;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			False);
	ParametersStructure.Insert("FillHeader",			True);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	SetIncomeAndExpenseItemsVisibility();
	
	ProcessingCompanyVATNumbers();
	
	SetVisibilitySettlementAttributes();
	SetVisibilityEPDAttributes();
	
	DriveClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	WorkWithVAT.SetTextAboutAdvancePaymentInvoiceIssued(ThisForm);
	
	SetTaxInvoiceText();
	
	FillCurrencyChoiceList(ThisForm, "CurrencyPurchaseRate", Object.CashCurrency);
	FillCurrencyChoiceList(ThisForm, "OtherSettlementsExchangeRate", Object.CashCurrency);
	FillCurrencyChoiceList(ThisForm, "TaxesSettlementsExchangeRate", Object.CashCurrency);
	FillCurrencyChoiceList(ThisForm, "BankChargeExchangeRate", Object.CashCurrency);
	FillCurrencyChoiceList(ThisForm, "PaymentDetailsPaymentExchangeRate", Object.CashCurrency);
	FillCurrencyChoiceList(ThisForm, "PaymentDetailsOtherSettlementsPaymentExchangeRate", Object.CashCurrency);
	
	Items.TaxInvoiceText.Enabled = WorkWithVAT.IsTaxInvoiceAccessRightEdit();
	
	EarlyPaymentDiscountsServer.SetTextAboutCreditNote(ThisObject, Object.Ref);
	SetVisibilityCreditNoteText();
	IncomeAndExpenseItemsInDocuments.SetConditionalAppearance(ThisObject, "PaymentDetails");
	
	DriveServer.CheckObjectGeneratedEnteringBalances(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
	SetChoiceParameterLinksAvailableTypes();
	SetCurrentPage();
	SetVisibleCommandFillByBasis();
	IncomeAndExpenseItemsOnChangeConditions();
	
	CalculateTotal();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AfterRecordingOfCounterparty" Then
		If ValueIsFilled(Parameter)
		   AND Object.Counterparty = Parameter Then
			SetVisibilitySettlementAttributes();
			SetVisibilityEPDAttributes();
		EndIf;
		
	ElsIf EventName = "RefreshTaxInvoiceText" 
		AND TypeOf(Parameter) = Type("Structure") 
		AND Not Parameter.BasisDocuments.Find(Object.Ref) = Undefined Then
		
		TaxInvoiceText = Parameter.Presentation;
		
	ElsIf EventName = "RefreshCreditNoteText" Then
		
		If TypeOf(Parameter.Ref) = Type("DocumentRef.CreditNote")
			AND Parameter.BasisDocument = Object.Ref Then
			
			CreditNoteText = EarlyPaymentDiscountsClientServer.CreditNotePresentation(Parameter.Date, Parameter.Number);
			
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If UsersClientServer.IsExternalUserSession() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	DocumentDate = CurrentObject.Date;
	
	FillPaymentProcessorPayoutDetailsAdditionalFields();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	DefaultExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("DiscountAllowed");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			False);
	ParametersStructure.Insert("FillHeader",			True);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(Object.PaymentDetails, MessageText, Object.Ref, Object.Company, Object.Counterparty, Object.OperationKind, Cancel, Object.LoanContract);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("en = 'The bank receipt is not posted.'; ru = 'Документ не проведен.';pl = 'Potwierdzenie zapłaty nie jest zatwierdzone.';es_ES = 'El recibo bancario no se ha enviado.';es_CO = 'El recibo bancario no se ha enviado.';tr = 'Banka tahsilatı kaydedilmedi.';it = 'La ricevuta bancaria non è pubblicata.';de = 'Der Zahlungseingang wird nicht gebucht.'") + MessageText, MessageText);
			Message.Message();
			
			If Cancel Then
				Return;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	// Notification of payment.
	NotifyAboutOrderPayment = False;
	
	For Each CurRow In Object.PaymentDetails Do
		NotifyAboutOrderPayment = ?(
			NotifyAboutOrderPayment,
			NotifyAboutOrderPayment,
			ValueIsFilled(CurRow.Order));
	EndDo;
	
	If NotifyAboutOrderPayment Then
		Notify("NotificationAboutOrderPayment");
	EndIf;
	
	Notify("NotificationAboutChangingDebt");
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	If CurrentObject.OperationKind = Enums.OperationTypesPaymentReceipt.LoanRepaymentByEmployee
		OR CurrentObject.OperationKind = Enums.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty
		OR CurrentObject.OperationKind = Enums.OperationTypesPaymentReceipt.LoanSettlements Then
			FillInformationAboutCreditLoanAtServer();
	EndIf;
	
	FillPaymentProcessorPayoutDetailsAdditionalFields();
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			False);
	ParametersStructure.Insert("FillHeader",			True);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "Document.TaxInvoiceIssued.Form.DocumentForm" Then
		
		TaxInvoiceText = SelectedValue;
		
	ElsIf GLAccountsInDocumentsClient.IsGLAccountsChoiceProcessing(ChoiceSource.FormName) Then
		
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
		
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

#EndRegion

#Region FormItemEventHandlers

#Region OtherSettlements

&AtClient
Procedure EmployeeOnChange(Item)
	
	If OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.LoanRepaymentByEmployee") 
		OR OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.LoanSettlements") Then
		
		DataStructure = GetEmployeeDataOnChange(Object.AdvanceHolder, Object.Date, Object.Company);
		
		Object.LoanContract = DataStructure.LoanContract;
		HandleLoanContractChange();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RegisterIncomeOnChange(Item)
	
	If Not Object.RegisterIncome Then
		Object.IncomeItem = PredefinedValue("Catalog.IncomeAndExpenseItems.EmptyRef");
		SetVisibilityAttributesDependenceOnCorrespondence();
	EndIf;
	
	IncomeAndExpenseItemsOnChangeConditions();
	
EndProcedure

&AtClient
Procedure IncomeItemOnChange(Item)
	SetVisibilityAttributesDependenceOnCorrespondence();
EndProcedure

&AtClient
Procedure OtherSettlementsCorrespondenceOnChange(Item)
	
	If Correspondence <> Object.Correspondence Then
		Correspondence = Object.Correspondence;
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.Other") Then
			
			Structure = New Structure("Object, Correspondence, BankFeeExpenseItem, IncomeItem, Manual");
			Structure.Object = Object;
			FillPropertyValues(Structure, Object);
			
			CorrespondenceOnChangeAtServer(Structure);
			
			IncomeAndExpenseItemsOnChangeConditions();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CorrespondenceOnChangeAtServer(Structure)
	
	GLAccountsInDocumentsServerCall.CheckItemRegistration(Structure);
	FillPropertyValues(Object, Structure);
	
	SetVisibilityAttributesDependenceOnCorrespondence();
	SetIncomeAndExpenseItemsVisibility();
	
EndProcedure

#EndRegion

#Region BankCharges

&AtClient
Procedure UseBankChargesOnChange(Item)
	
	StructureBankAccountData = GetDataBankAccountOnChange(
		Object.Date,
		Object.BankAccount,
		Object.Company);
	
	Object.BankChargeExchangeRate = StructureBankAccountData.ExchangeRate;
	Object.BankChargeMultiplier = StructureBankAccountData.Multiplier;
	
	SetVisibilityItemsDependenceOnOperationKindAndUseBankCharges();
	
	CalculateTotal();
	
EndProcedure

&AtClient
Procedure BankChargeOnChange(Item)
	
	StructureData = GetDataBankChargeOnChange(Object.BankCharge, Object.CashCurrency);
	
	Object.BankChargeItem = StructureData.BankChargeItem;
	Object.BankChargeAmount = StructureData.BankChargeAmount;
	Object.BankFeeExpenseItem = StructureData.ExpenseItem;
	
	CalculateTotal();
	
EndProcedure

&AtClient
Procedure BankChargeExchangeRateChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	ExchangeRateChoiceProcessing("", "BankChargeExchangeRate", SelectedValue, StandardProcessing, Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure BankChargeAmountOnChange(Item)
	
	CalculateTotal();
	
EndProcedure

#EndRegion

#EndRegion

#Region FormItemEventHandlersTablePaymentDetails

&AtClient
Procedure PaymentDetailsOtherSettlementsBeforeDeleteRow(Item, Cancel)
	
	If Object.PaymentDetails.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsOnStartEdit(Item, NewRow, Clone)
	
	If NewRow And Not Clone Then
		
		TabularSectionRow = Items.PaymentDetailsOtherSettlements.CurrentData;
		TabularSectionRow.PaymentExchangeRate = Object.ExchangeRate;
		TabularSectionRow.PaymentMultiplier = Object.Multiplicity;
		
		If ValueIsFilled(Object.Counterparty) Then
			
			CounterpartyAttributes = GetRefAttributes(Object.Counterparty, "DoOperationsByContracts");
			
			If Not CounterpartyAttributes.DoOperationsByContracts Then
				
				TabularSectionRow.Contract = GetContractByDefault(Object.Ref,
					Object.Counterparty,
					Object.Company,
					Object.OperationKind);
				
				ProcessOnChangeCounterpartyContractOtherSettlements();
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsContractOnChange(Item)
	
	ProcessOnChangeCounterpartyContractOtherSettlements();
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Object.Counterparty.IsEmpty() Then
		StandardProcessing = False;
		
		Message = New UserMessage;
		Message.Text = NStr("en = 'Please select a counterparty.'; ru = 'Сначала выберите контрагента';pl = 'Wybierz kontrahenta.';es_ES = 'Por favor, seleccione un contraparte.';es_CO = 'Por favor, seleccione un contraparte.';tr = 'Lütfen, cari hesap seçin.';it = 'Si prega di selezionare una controparte.';de = 'Bitte wählen Sie einen Geschäftspartner aus.'");
		Message.Field = "Object.Counterparty";
		Message.Message();
		
		Return;
	EndIf;
	
	ProcessStartChoiceCounterpartyContractOtherSettlements(Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsSettlementsAmountOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetailsOtherSettlements.CurrentData;
	CalculateSettlementsRate(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsExchangeRateOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetailsOtherSettlements.CurrentData;
	CalculateSettlementsAmount(TabularSectionRow, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsMultiplicityOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	CalculateSettlementsAmount(TabularSectionRow, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetailsOtherSettlements.CurrentData;
	
	CalculateSettlementsAmount(TabularSectionRow, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
	If Not ValueIsFilled(TabularSectionRow.VATRate) Then
		TabularSectionRow.VATRate = DefaultVATRate;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsVATRateOnChange(Item)
	
	TablePartRow = Items.PaymentDetailsOtherSettlements.CurrentData;
	CalculateVATAmountAtClient(TablePartRow);

EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsPaymentExchangeRateOnChange(Item)
	
	CurrentData = Items.PaymentDetailsOtherSettlements.CurrentData;
	CalculateSettlementsAmount(CurrentData, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsPaymentExchangeRateChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	ExchangeRateChoiceProcessing("PaymentDetailsOtherSettlements", 
		"PaymentExchangeRate", 
		SelectedValue, 
		StandardProcessing,
		Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsPaymentMultiplierOnChange(Item)
	
	CurrentData = Items.PaymentDetailsOtherSettlements.CurrentData;
	CalculateSettlementsAmount(CurrentData, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsSettlementsExchangeRateOnChange(Item)
	
	CurrentData = Items.PaymentDetailsOtherSettlements.CurrentData;
	CalculateSettlementsAmount(CurrentData, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsSettlementsExchangeRateChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	CurrentData = Items.PaymentDetailsOtherSettlements.CurrentData;
	ExchangeRateChoiceProcessing("PaymentDetailsOtherSettlements", 
		"ExchangeRate", 
		SelectedValue, 
		StandardProcessing,
		CurrentData.SettlementsCurrency);
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsSettlementsMultiplierOnChange(Item)
	
	CurrentData = Items.PaymentDetailsOtherSettlements.CurrentData;
	CalculateSettlementsAmount(CurrentData, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

#EndRegion

#Region PaymentProcessorPayoutDetailsFormTableItemsEventHandlers

&AtClient
Procedure PaymentProcessorPayoutDetailsOnStartEdit(Item, NewRow, Clone)
	
	If Clone Then
		CalculateProcessorPayoutTotals();
		CalculateTotal();
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentProcessorPayoutDetailsAfterDeleteRow(Item)
	
	CalculateProcessorPayoutTotals();
	CalculateTotal();
	
EndProcedure

&AtClient
Procedure PaymentProcessorPayoutDetailsDocumentOnChange(Item)
	
	PayoutDetailsRow = Items.PaymentProcessorPayoutDetails.CurrentData;
	
	If ValueIsFilled(PayoutDetailsRow.Document) Then
		
		DocumentData = PayoutDetailsDocumentData(PayoutDetailsRow.Document);
		FillPropertyValues(PayoutDetailsRow, DocumentData);
		
	EndIf;
	
	CalculateProcessorPayoutTotals();
	CalculateTotal();
	
EndProcedure

&AtClient
Procedure PaymentProcessorPayoutDetailsAmountOnChange(Item)
	
	CalculateProcessorPayoutTotals();
	CalculateTotal();
	
EndProcedure

&AtClient
Procedure PaymentProcessorPayoutDetailsFeeAmountOnChange(Item)
	
	CalculateProcessorPayoutTotals();
	CalculateTotal();
	
EndProcedure

&AtClient
Procedure PaymentProcessorPayoutDetailsRefundAmountOnChange(Item)
	
	CalculateProcessorPayoutTotals();
	CalculateTotal();
	
EndProcedure

&AtClient
Procedure PaymentProcessorPayoutDetailsRefundFeeAmountOnChange(Item)
	
	CalculateProcessorPayoutTotals();
	CalculateTotal();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region GLAccounts

&AtServer
Procedure FillAddedColumns(ParametersStructure)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	IsOtherSettlements = Object.OperationKind = Enums.OperationTypesPaymentReceipt.OtherSettlements;
	
	StructureArray = New Array();
	
	If UseDefaultTypeOfAccounting And IsOtherSettlements Then
		
		If ParametersStructure.FillHeader Then
			Header = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "Header", Object);
			GLAccountsInDocuments.CompleteCounterpartyStructureData(Header, ObjectParameters, "Header");
			StructureArray.Add(Header);
		EndIf;
		
	EndIf;
	
	If ParametersStructure.FillPaymentDetails And Not IsOtherSettlements Then
		StructureData = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters);
		GLAccountsInDocuments.CompleteCounterpartyStructureData(StructureData, ObjectParameters);
		StructureArray.Add(StructureData);
	EndIf;

	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, ParametersStructure.GetGLAccounts);
	
	If UseDefaultTypeOfAccounting
		And IsOtherSettlements
		And ParametersStructure.FillHeader Then
		Object.Correspondence = ChartsOfAccounts.PrimaryChartOfAccounts.FindByCode(Header.GLAccounts);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function GetStructureDataForObject(Form, TabName, TabRow, UseDefaultTypeOfAccounting)
	
	StructureData = New Structure;
	
	StructureData.Insert("TabName", 					TabName);
	StructureData.Insert("Object",						Form.Object);
	StructureData.Insert("CounterpartyGLAccounts",		UseDefaultTypeOfAccounting);
	StructureData.Insert("Contract",					TabRow.Contract);
	StructureData.Insert("Document",					TabRow.Document);
	StructureData.Insert("ExistsEPD",					TabRow.ExistsEPD);
	StructureData.Insert("EPDAmount",					TabRow.EPDAmount);
	StructureData.Insert("DiscountAllowedExpenseItem",	TabRow.DiscountAllowedExpenseItem);
	
	If UseDefaultTypeOfAccounting Then
		
		StructureData.Insert("GLAccounts",					TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled",			TabRow.GLAccountsFilled);
		
		StructureData.Insert("AccountsPayableGLAccount",	TabRow.AccountsPayableGLAccount);
		StructureData.Insert("AdvancesPaidGLAccount",		TabRow.AdvancesPaidGLAccount);
		StructureData.Insert("AccountsReceivableGLAccount",	TabRow.AccountsReceivableGLAccount);
		StructureData.Insert("AdvancesReceivedGLAccount",	TabRow.AdvancesReceivedGLAccount);
		StructureData.Insert("DiscountAllowedGLAccount",	TabRow.DiscountAllowedGLAccount);
		StructureData.Insert("ThirdPartyPayerGLAccount",	TabRow.ThirdPartyPayerGLAccount);
		StructureData.Insert("VATOutputGLAccount",			TabRow.VATOutputGLAccount);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

#EndRegion


&AtClient
Procedure CalculateTotal()
	
	Total = Object.DocumentAmount - Object.BankChargeAmount * Number(Object.UseBankCharges);
	BankFee = - Object.BankChargeAmount;
	
EndProcedure

&AtClient
Procedure CalculatePaymentAmountAtClient(TablePartRow, ColumnName = "")
	
	StructureData = GetDataPaymentDetailsContractOnChange(
			Object.Date,
			TablePartRow.Contract,
			Object.Company);
		
	TablePartRow.ExchangeRate = ?(
		TablePartRow.ExchangeRate = 0,
		?(StructureData.ContractCurrencyRateRepetition.Rate = 0, 1, StructureData.ContractCurrencyRateRepetition.Rate),
		TablePartRow.ExchangeRate);
		
	TablePartRow.Multiplicity = ?(
		TablePartRow.Multiplicity = 0,
		1,
		TablePartRow.Multiplicity);
	
	If TablePartRow.SettlementsAmount = 0 Then
		TablePartRow.PaymentAmount = 0;
		TablePartRow.ExchangeRate = StructureData.ContractCurrencyRateRepetition.Rate;
	ElsIf Object.CashCurrency = StructureData.SettlementsCurrency Then
		TablePartRow.PaymentAmount = TablePartRow.SettlementsAmount;
	ElsIf TablePartRow.PaymentAmount = 0 Or
		(ColumnName = "ExchangeRate" Or ColumnName = "Multiplicity") Then
		If TablePartRow.ExchangeRate = 0 Then
			TablePartRow.PaymentAmount = 0;
		Else
			TablePartRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				TablePartRow.SettlementsAmount,
				ExchangeRateMethod,
				TablePartRow.ExchangeRate,
				ExchangeRate,
				TablePartRow.Multiplicity,
				Multiplicity);
		EndIf;
	Else
		TablePartRow.ExchangeRate = ?(
			TablePartRow.SettlementsAmount = 0 Or TablePartRow.PaymentAmount = 0,
			StructureData.ContractCurrencyRateRepetition.Rate,
			TablePartRow.PaymentAmount / TablePartRow.SettlementsAmount * ExchangeRate);
		TablePartRow.Multiplicity = ?(
			TablePartRow.SettlementsAmount = 0 Or TablePartRow.PaymentAmount = 0,
			StructureData.ContractCurrencyRateRepetition.Repetition,
			TablePartRow.Multiplicity);
	EndIf;
	
	If Not ValueIsFilled(TablePartRow.VATRate) Then
		TablePartRow.VATRate = DefaultVATRate;
	EndIf;
	
	CalculateVATAmountAtClient(TablePartRow);
	
EndProcedure

&AtClient
Procedure CalculateVATAmountAtClient(TablePartRow)
	
	VATRate = DriveReUse.GetVATRateValue(TablePartRow.VATRate);
	
	TablePartRow.VATAmount = TablePartRow.PaymentAmount - (TablePartRow.PaymentAmount) / ((VATRate + 100) / 100);
	
EndProcedure

&AtServerNoContext
Function GetChoiceFormParameters(Document, Company, Counterparty, Contract, OperationKind)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Document, OperationKind);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice",	Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty",			Counterparty);
	FormParameters.Insert("Company",				Company);
	FormParameters.Insert("ContractType",			ContractTypesList);
	FormParameters.Insert("CurrentRow",				Contract);
	
	Return FormParameters;
	
EndFunction

&AtServer
Function GetDataPaymentDetailsContractOnChange(Date, Contract, Company, StructureData = Undefined, PlanningDocument = Undefined)
	
	If StructureData = Undefined Then
		StructureData = New Structure;
	EndIf;
	
	NameCashFlowItem = "CashFlowItem";
	
	If TypeOf(Contract) = Type("DocumentRef.LoanContract") Then
		NameCashFlowItem = "PrincipalItem";
	EndIf;
	
	ContractData = Common.ObjectAttributesValues(Contract, "SettlementsCurrency, "+NameCashFlowItem);
	
	CurrencyRate = CurrencyRateOperations.GetCurrencyRate(Date, ContractData.SettlementsCurrency, Company);
	CurrencyRate.Rate = ?(CurrencyRate.Rate = 0, 1, CurrencyRate.Rate);
	CurrencyRate.Repetition = ?(CurrencyRate.Repetition = 0, 1, CurrencyRate.Repetition);
	
	StructureData.Insert("ContractCurrencyRateRepetition", CurrencyRate);
	StructureData.Insert("SettlementsCurrency", ContractData.SettlementsCurrency);
	StructureData.Insert("Item", ContractData[NameCashFlowItem]);
	
	If StructureData.Property("GLAccounts") And UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillCounterpartyGLAccounts(StructureData);
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			False);
	ParametersStructure.Insert("FillHeader",			False);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	IncomeAndExpenseItemsInDocuments.SetConditionalAppearance(ThisObject, "PaymentDetails");
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure OperationKindOnChangeAtServer()
	
	SetChoiceParameterLinksAvailableTypes();
	
	If Object.OperationKind = Enums.OperationTypesPaymentReceipt.OtherSettlements Then
		
		DefaultVATRate						= Catalogs.VATRates.Exempt;
		DefaultVATRateNumber				= DriveReUse.GetVATRateValue(DefaultVATRate);
		Object.PaymentDetails[0].VATRate	= DefaultVATRate;
		
	Else
		FillVATRateByCompanyVATTaxation();
	EndIf;
	
	SetVisibleOfVATTaxation();
	SetIncomeAndExpenseItemsVisibility();
	SetVisibilityItemsDependenceOnOperationKindAndUseBankCharges();
	SetVisibilityEPDAttributes();
	SetCFItemWhenChangingTheTypeOfOperations();
	SetVisibilityCreditNoteText();
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			True);
	ParametersStructure.Insert("FillHeader",			True);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	If ValueIsFilled(Object.BankAccount) And ValueIsFilled(Object.Company) Then
		StructureData = GetDataBankAccountOnChange(Object.Date, Object.BankAccount, Object.Company);
		Object.ExchangeRate = StructureData.ExchangeRate;
		Object.Multiplicity = StructureData.Multiplier;
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessOnChangeCounterpartyContractOtherSettlements()
	
	TablePartRow = Items.PaymentDetailsOtherSettlements.CurrentData;
	
	If ValueIsFilled(TablePartRow.Contract) Then
		StructureData = GetDataPaymentDetailsContractOnChange(
			Object.Date,
			TablePartRow.Contract,
			Object.Company,
			,
			TablePartRow.PlanningDocument);
			
		TablePartRow.ExchangeRate = StructureData.ContractCurrencyRateRepetition.Rate;
		TablePartRow.Multiplicity = StructureData.ContractCurrencyRateRepetition.Repetition;
		TablePartRow.SettlementsCurrency = StructureData.SettlementsCurrency;
		
		RefreshRatesAndAmount(TablePartRow, PresentationCurrency, Object.CashCurrency);
		
	EndIf;
	
	CalculateSettlementsAmount(TablePartRow, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure ProcessStartChoiceCounterpartyContractOtherSettlements(Item, StandardProcessing)
	
	TablePartRow = Items.PaymentDetailsOtherSettlements.CurrentData;
	If TablePartRow = Undefined Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, TablePartRow.Contract, Object.OperationKind);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ColorTextSpecifiedInDocument = StyleColors.TextSpecifiedInDocument;
	
	//PaymentDetailsPlanningDocument
	
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.OperationKind");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= Enums.OperationTypesPaymentReceipt.FromCustomer;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.PaymentDetails.AdvanceFlag");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = '<required only for advance>'; ru = '<указывается только для аванса>';pl = '<wymagane tylko w przypadku zaliczki>';es_ES = '<requerido solo para el anticipo>';es_CO = '<requerido solo para el anticipo>';tr = '<yalnızca avans için gerekli>';it = '<richiesto solo per anticipo>';de = '<nur für Vorauszahlung erforderlich>.'"));
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorTextSpecifiedInDocument);
	ItemAppearance.Appearance.SetParameterValue("Enabled", False);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("PaymentDetailsPlanningDocument");
	FieldAppearance.Use = True;
	
	// PaymentDetailsEPDAmount
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.PaymentDetails.ExistsEPD");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("ReadOnly", True);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("PaymentDetailsEPDAmount");
	FieldAppearance.Use = True;
	
	// PaymentProcessorPayoutDetails
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.PaymentProcessorPayoutDetails.IsRefund",
		False,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance,
		"PaymentProcessorPayoutDetailsRefundAmount, PaymentProcessorPayoutDetailsRefundFeeAmount");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.PaymentProcessorPayoutDetails.IsRefund",
		True,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance,
		"PaymentProcessorPayoutDetailsAmount, PaymentProcessorPayoutDetailsFeeAmount");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	
	// Payment exchange rate and multiplier
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(ItemAppearance.Filter,
		"Object.CashCurrency",
		New DataCompositionField("PresentationCurrency"),
		DataCompositionComparisonType.Equal);
		
	WorkWithForm.AddAppearanceField(ItemAppearance, "PaymentDetailsPaymentMultiplier");
	WorkWithForm.AddAppearanceField(ItemAppearance, "PaymentDetailsPaymentExchangeRate");
	WorkWithForm.AddAppearanceField(ItemAppearance, "PaymentDetailsOtherSettlementsPaymentMultiplier");
	WorkWithForm.AddAppearanceField(ItemAppearance, "PaymentDetailsOtherSettlementsPaymentExchangeRate");
	
	WorkWithForm.AddConditionalAppearanceItem(ItemAppearance, "Enabled", False);
	
	// Settlement exchange rate and multiplier
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	OrGroup = WorkWithForm.CreateFilterItemGroup(ItemAppearance.Filter, DataCompositionFilterItemsGroupType.OrGroup);
	
	WorkWithForm.AddFilterItem(OrGroup,
		"Object.PaymentDetails.SettlementsCurrency",
		New DataCompositionField("Object.CashCurrency"),
		DataCompositionComparisonType.Equal);
		
	WorkWithForm.AddFilterItem(OrGroup,
		"Object.PaymentDetails.SettlementsCurrency",
		New DataCompositionField("PresentationCurrency"),
		DataCompositionComparisonType.Equal);
		
	WorkWithForm.AddAppearanceField(ItemAppearance, "PaymentDetailsSettlementsMultiplier");
	WorkWithForm.AddAppearanceField(ItemAppearance, "PaymentDetailsSettlementsExchangeRate");
	WorkWithForm.AddAppearanceField(ItemAppearance, "PaymentDetailsOtherSettlementsSettlementsMultiplier");
	WorkWithForm.AddAppearanceField(ItemAppearance, "PaymentDetailsOtherSettlementsSettlementsExchangeRate");
	
	WorkWithForm.AddConditionalAppearanceItem(ItemAppearance, "Enabled", False);
	
	// Settlement amount
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(ItemAppearance.Filter,
		"Object.PaymentDetails.SettlementsCurrency",
		New DataCompositionField("Object.CashCurrency"),
		DataCompositionComparisonType.Equal);
		
	WorkWithForm.AddAppearanceField(ItemAppearance, "PaymentDetailsSettlementsAmount");
	WorkWithForm.AddAppearanceField(ItemAppearance, "PaymentDetailsOtherSettlementsSettlementsAmount");
	
	WorkWithForm.AddConditionalAppearanceItem(ItemAppearance, "Enabled", False);
	
	// Payment currency
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddAppearanceField(ItemAppearance, "PaymentDetailsPaymentCurrency");
	WorkWithForm.AddAppearanceField(ItemAppearance, "PaymentDetailsOtherSettlementsPaymentCurrency");
	
	WorkWithForm.AddConditionalAppearanceItem(ItemAppearance, "Text", New DataCompositionField("Object.CashCurrency"));
	
EndProcedure

&AtServer
Procedure SetChoiceParametersForAccountingOtherSettlementsAtServerForAccountItem()

	Item = Items.OtherSettlementsCorrespondence;
	
	ChoiceParametersItem	= New Array;
	FilterByAccountType		= New Array;

	For Each Parameter In Item.ChoiceParameters Do
		If UseDefaultTypeOfAccounting And Parameter.Name = "Filter.TypeOfAccount" Then
			
			FilterByAccountType.Add(Enums.GLAccountsTypes.AccountsReceivable);
			FilterByAccountType.Add(Enums.GLAccountsTypes.AccountsPayable);
			
			ChoiceParametersItem.Add(New ChoiceParameter("Filter.TypeOfAccount", New FixedArray(FilterByAccountType)));
			
		Else
			ChoiceParametersItem.Add(Parameter);
		EndIf;
	EndDo;
	
	Item.ChoiceParameters = New FixedArray(ChoiceParametersItem);
	
EndProcedure

&AtServer
Procedure SetChoiceParametersOnMetadataForAccountItem()

	Item = Items.OtherSettlementsCorrespondence;
	
	ChoiceParametersItem	= New Array;
	FilterByAccountType		= New Array;
	
	ChoiceParametersFromMetadata = Object.Ref.Metadata().Attributes.Correspondence.ChoiceParameters;
	For Each Parameter In ChoiceParametersFromMetadata Do
		ChoiceParametersItem.Add(Parameter);
	EndDo;
	
	Item.ChoiceParameters = New FixedArray(ChoiceParametersItem);
	
EndProcedure

&AtServer
Procedure SetVisibilityAttributesDependenceOnCorrespondence()
	
	SetVisibilityPlanningDocument();
	SetVisibilityProject();
	
EndProcedure

&AtServer
Procedure SetVisibilityItemsDependenceOnOperationKindAndUseBankCharges()
	
	Items.PaymentDetailsPaymentAmount.Visible						= UseForeignCurrency;
	Items.SettlementsOnCreditsPaymentDetailsPaymentAmount.Visible	= UseForeignCurrency;
	
	Items.PaymentDetailsExchangeRate.Visible = False;
	Items.PaymentDetailsMultiplicity.Visible = False;
	Items.PaymentDetailsOtherSettlementsExchangeRate.Visible = False;
	Items.PaymentDetailsOtherSettlementsMultiplicity.Visible = False;
	
	Items.SettlementsWithCounterparty.Visible	= False;
	Items.SettlementsWithAdvanceHolder.Visible	= False;
	Items.CurrencyPurchase.Visible				= False;
	Items.OtherSettlements.Visible				= False;
	Items.TaxesSettlements.Visible				= False;
	Items.PlanningDocuments.Visible				= False;
	
	Items.Counterparty.Visible					= False;
	Items.AdvanceHolder.Visible					= False;
	Items.CounterpartyAccount.Visible			= False;
	
	Items.LoanSettlements.Visible			= False;
	Items.LoanSettlements.Title				= NStr("en = 'Borrowed loan details'; ru = 'Сведения о взятом займе';pl = 'Szczegóły otrzymanej pożyczki';es_ES = 'Detalles del préstamo prestado';es_CO = 'Detalles del préstamo prestado';tr = 'Alınan kredi bilgileri';it = 'Dettagli prestito';de = 'Angaben zum Darlehen geliehen'");
	Items.BorrowerLoanAgreement.Visible		= False;
	Items.FillByLoanContract.Visible		= False;
	Items.CreditContract.Visible			= False;
	Items.FillByCreditContract.Visible		= False;
	Items.GroupContractInformation.Visible	= False;
	Items.AdvanceHolder.Visible				= False;
	Items.Item.Visible						= True;
	
	Items.Item.Visible				 = True;
	Items.PaymentDetailsItem.Visible = False;
	
	Items.PaymentDetailsPlanningDocument.Visible = True;
	Items.PaymentDetailsSignAdvance.Visible = True;
	Items.PaymentDetailsThirdPartyCustomer.Visible = False;
	Items.PaymentDetailsThirdPartyCustomerContract.Visible = False;
	Items.PaymentDetailsSettlementsMultiplier.Visible = False;
	Items.PaymentDetailsSettlementsExchangeRate.Visible = False;
	
	Items.POSTerminal.Visible = False;
	Items.FeeTotal.Visible = False;
	Items.RefundTotal.Visible = False;
	Items.FeeTotalCurrency.Visible = False;
	Items.RefundTotalCurrency.Visible = False;
	Items.PayoutFromPaymentProcessor.Visible = False;
	Items.BasisFill.Visible = True;
	
	DocMetadata = Metadata.Documents.PaymentReceipt;
	
	BasisDocumentTypes = DocMetadata.Attributes.BasisDocument.Type;
	Items.BasisDocument.TypeRestriction = New TypeDescription(BasisDocumentTypes, , "DocumentRef.CashTransferPlan");
	
	PlanningDocumentTypes = DocMetadata.TabularSections.PaymentDetails.Attributes.PlanningDocument.Type;
	PlanningDocumentTypeRestriction = New TypeDescription(PlanningDocumentTypes, , "DocumentRef.CashTransferPlan");
	Items.PaymentDetailsPlanningDocument.TypeRestriction = PlanningDocumentTypeRestriction;
	Items.PaymentDetailsOtherSettlementsPlanningDocument.TypeRestriction = PlanningDocumentTypeRestriction;
	Items.AdvanceHoldersPaymentAccountDetailsForPayment.TypeRestriction = PlanningDocumentTypeRestriction;
	Items.SettlementsOnCreditsPaymentDetailsPlanningDocument.TypeRestriction = PlanningDocumentTypeRestriction;
	
	Items.PaymentDetailsContract.Title = "";
	
	If Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer Then
		
		Items.SettlementsWithCounterparty.Visible			= True;
		Items.PaymentDetailsPickup.Visible					= True;
		Items.PaymentDetailsFillDetails.Visible				= True;
		Items.PaymentDetailsSettlementsMultiplier.Visible 	= True;
		Items.PaymentDetailsSettlementsExchangeRate.Visible = True;
		
		SetChoiceParametersForCounterparty("Customer");
		
		Items.Counterparty.Visible					= True;
		Items.Counterparty.Title					= NStr("en = 'Customer'; ru = 'Покупатель';pl = 'Nabywca';es_ES = 'Cliente';es_CO = 'Cliente';tr = 'Müşteri';it = 'Cliente';de = 'Kunde'");
		Items.CounterpartyAccount.Visible			= True;
		
		Items.PaymentAmount.Visible		= UseForeignCurrency;
		Items.PaymentAmount.Title		= NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'");
		
		Items.Item.Visible				 = False;
		Items.PaymentDetailsItem.Visible = True;
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentReceipt.PayoutFromPaymentProcessor Then
		
		Items.PaymentAmount.Visible = UseForeignCurrency;
		Items.PaymentAmount.Title = NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'");
		
		Items.BasisFill.Visible = False;
		Items.Item.Visible = False;
		
		Items.POSTerminal.Visible = True;
		Items.PayoutFromPaymentProcessor.Visible = True;
		
		SetVisibilityPOSTermialWithholdFeeOnPayoutDependant();
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentReceipt.PaymentFromThirdParties Then
		
		Items.SettlementsWithCounterparty.Visible				= True;
		Items.PaymentDetailsPickup.Visible						= True;
		Items.PaymentDetailsFillDetails.Visible					= True;
		Items.PaymentDetailsPlanningDocument.Visible			= False;
		Items.PaymentDetailsSignAdvance.Visible					= False;
		Items.PaymentDetailsThirdPartyCustomer.Visible			= True;
		Items.PaymentDetailsThirdPartyCustomerContract.Visible	= True;
		Items.PaymentDetailsSettlementsMultiplier.Visible 		= True;
		Items.PaymentDetailsSettlementsExchangeRate.Visible 	= True;
		
		SetChoiceParametersForCounterparty("OtherRelationship");
		
		Items.Counterparty.Visible					= True;
		Items.Counterparty.Title					= NStr("en = 'Third-party payer'; ru = 'Сторонний плательщик';pl = 'Płatnik strony trzeciej';es_ES = 'Pago por terceros';es_CO = 'Pago por terceros';tr = 'Üçüncü taraf ödeyen';it = 'Terza parte pagatrice';de = 'Drittzahler'");
		Items.CounterpartyAccount.Visible			= True;
		Items.PaymentDetailsContract.Title			= NStr("en = 'Third-party payer''s contract'; ru = 'Договор со сторонним плательщиком';pl = 'Kontrakt płatnika strony trzeciej';es_ES = 'Contrato del cliente de terceros';es_CO = 'Contrato del cliente de terceros';tr = 'Üçüncü taraf ödeyenin sözleşmesi';it = 'Contratto cliente terza parte';de = 'Vertrag von Drittzahler'");
		
		Items.PaymentAmount.Visible		= UseForeignCurrency;
		Items.PaymentAmount.Title		= NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'");
		
		Items.Item.Visible				 = False;
		Items.PaymentDetailsItem.Visible = True;
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromVendor Then
		
		Items.SettlementsWithCounterparty.Visible			= True;
		Items.PaymentDetailsPickup.Visible					= False;
		Items.PaymentDetailsFillDetails.Visible				= True;
		Items.PaymentDetailsSettlementsMultiplier.Visible 	= True;
		Items.PaymentDetailsSettlementsExchangeRate.Visible = True;
		
		SetChoiceParametersForCounterparty("Supplier");
		
		Items.Counterparty.Visible			= True;
		Items.Counterparty.Title			= NStr("en = 'Supplier'; ru = 'Поставщик';pl = 'Dostawca';es_ES = 'Proveedor';es_CO = 'Proveedor';tr = 'Tedarikçi';it = 'Fornitore';de = 'Lieferant'");
		Items.CounterpartyAccount.Visible	= True;
		
		Items.PaymentAmount.Visible		= UseForeignCurrency;
		Items.PaymentAmount.Title		= NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'");
		
		Items.Item.Visible				 = False;
		Items.PaymentDetailsItem.Visible = True;
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromAdvanceHolder Then
		
		Items.SettlementsWithAdvanceHolder.Visible	= True;
		Items.AdvanceHolder.Visible					= True;
		
		Items.PaymentAmount.Visible		= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title		= ?(GetFunctionalOption("PaymentCalendar"),
			NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'"), NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'"));
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentReceipt.CurrencyPurchase Then
		
		Items.CurrencyPurchase.Visible = True;
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"),
			NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'"), NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'"));
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentReceipt.Taxes Then
		
		Items.TaxesSettlements.Visible	= True;
		
		SetChoiceParametersForCounterparty("OtherRelationship");
		
		Items.Counterparty.Visible			= True;
		Items.Counterparty.Title			= NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'");
		Items.CounterpartyAccount.Visible	= True;
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"),
			NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'"), NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'"));
			
		Items.BusinessLineTaxes.Visible = FunctionalOptionAccountingCashMethodIncomeAndExpenses;
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentReceipt.Other Then
		
		Items.OtherSettlements.Visible	= True;
		Items.OtherSettlementsExchangeRateMultiplier.Visible = True;
		Items.OtherSettlementsAmount.Visible = True;
		
		SetChoiceParametersForCounterparty("OtherRelationship");
		
		Items.Counterparty.Visible			= True;
		Items.Counterparty.Title			= NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'");
		Items.CounterpartyAccount.Visible	= True;
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"),
			NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'"), NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'"));
		
		Items.PaymentDetailsOtherSettlements.Visible = False;
		SetVisibilityAttributesDependenceOnCorrespondence();
		
		Items.BasisDocument.TypeRestriction = New TypeDescription;
		Items.PaymentDetailsPlanningDocument.TypeRestriction = New TypeDescription;
		Items.PaymentDetailsOtherSettlementsPlanningDocument.TypeRestriction = New TypeDescription;
		Items.AdvanceHoldersPaymentAccountDetailsForPayment.TypeRestriction = New TypeDescription;
		Items.SettlementsOnCreditsPaymentDetailsPlanningDocument.TypeRestriction = New TypeDescription;
		
		Items.OtherSettlementsCorrespondence.Title = NStr("en = 'Credit account'; ru = 'Кредитовый счет';pl = 'Konto kredytowe';es_ES = 'Cuenta de crédito';es_CO = 'Cuenta de crédito';tr = 'Alacak hesabı';it = 'Conto credito';de = 'Haben-Konto'");
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentReceipt.OtherSettlements Then
		
		Items.OtherSettlements.Visible	= True;
		Items.OtherSettlementsExchangeRateMultiplier.Visible = False;
		Items.OtherSettlementsAmount.Visible = False;
		
		Items.PaymentAmount.Visible			= UseForeignCurrency;
		Items.PaymentAmount.Title 			= NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'");
		
		SetChoiceParametersForCounterparty("OtherRelationship");
		
		Items.Counterparty.Visible								= True;
		Items.Counterparty.Title								= NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'");
		Items.PaymentDetailsOtherSettlements.Visible 			= True;
		Items.PaymentDetailsOtherSettlementsContract.Visible	= Object.Counterparty.DoOperationsByContracts;
		Items.PaymentDetailsSettlementsMultiplier.Visible 		= True;
		Items.PaymentDetailsSettlementsExchangeRate.Visible 	= True;
		SetVisibilityAttributesDependenceOnCorrespondence();
		
		Items.OtherSettlementsCorrespondence.Title = NStr("en = 'Credit account'; ru = 'Кредитовый счет';pl = 'Konto kredytowe';es_ES = 'Cuenta de crédito';es_CO = 'Cuenta de crédito';tr = 'Alacak hesabı';it = 'Conto credito';de = 'Haben-Konto'");
		
		If Object.PaymentDetails.Count() > 0 Then
			ID = Object.PaymentDetails[0].GetID();
			Items.PaymentDetailsOtherSettlements.CurrentRow = ID;
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesPaymentReceipt.LoanSettlements Then
		
		SetChoiceParametersForCounterparty("OtherRelationship");
		
		Items.LoanSettlements.Visible					= True;
		Items.Counterparty.Visible							= True;
		Items.Counterparty.Title							= NStr("en = 'Lender'; ru = 'Заимодатель';pl = 'Pożyczkodawca';es_ES = 'Prestamista';es_CO = 'Prestador';tr = 'Borç veren';it = 'Finanziatore';de = 'Darlehensgeber'");;
		Items.LoanSettlements.Visible					= True;
		Items.SettlementsOnCreditsPaymentDetails.Visible	= False;
		Items.CreditContract.Visible						= True;
		Items.FillByCreditContract.Visible					= True;
		Items.CashCurrency.Enabled							= False;
		
		FillInformationAboutCreditLoanAtServer();
		SetCFItem();
		
		Items.GroupContractInformation.Visible	= True;		
		Items.PaymentAmount.Visible				= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title				= NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'");
		
		Items.AdvanceHoldersPaymentDetailsPaymentAmount.Visible = GetFunctionalOption("PaymentCalendar");
		
	ElsIf OperationKind = Enums.OperationTypesPaymentReceipt.LoanRepaymentByEmployee Then
		
		Items.AdvanceHolder.Visible							= True;
		Items.AdvanceHolder.Title							= NStr("en = 'Employee'; ru = 'Сотрудник';pl = 'Pracownik';es_ES = 'Empleado';es_CO = 'Empleado';tr = 'Çalışan';it = 'Dipendente';de = 'Mitarbeiter'"); 
		Items.LoanSettlements.Title							= NStr("en = 'Loan repayment details'; ru = 'Выплата займа';pl = 'Szczegóły spłaty pożyczki';es_ES = 'Detalles de la entrada del pago de préstamo';es_CO = 'Detalles de devolución de préstamo';tr = 'Kredi geri ödemesi bilgileri';it = 'Dettagli di ricevuta di rimborso del prestito';de = 'Angaben zur Darlehensrückzahlung'");
		Items.LoanSettlements.Visible						= True;
		Items.SettlementsOnCreditsPaymentDetails.Visible	= True;
		Items.BorrowerLoanAgreement.Visible					= True;
		Items.FillByLoanContract.Visible					= True;
		Items.Item.Visible									= False;
		Items.CashCurrency.Enabled							= False;
		
		FillInformationAboutCreditLoanAtServer();
		SetCFItem();
		
		Items.GroupContractInformation.Visible	= True;	
		Items.PaymentAmount.Visible				= UseForeignCurrency;
		Items.PaymentAmount.Title				= NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'");
		
		Items.SettlementsOnCreditsPaymentDetailsPaymentAmount.Visible = UseForeignCurrency;
		
	ElsIf OperationKind = Enums.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty Then
		
		SetChoiceParametersForCounterparty("OtherRelationship");
		
		Items.Counterparty.Visible							= True;
		Items.Counterparty.Title							= NStr("en = 'Borrower'; ru = 'Заемщик';pl = 'Pożyczkobiorca';es_ES = 'Prestatario';es_CO = 'Prestatario';tr = 'Borçlanan';it = 'Mutuatario';de = 'Darlehensnehmer'");
		
		Items.LoanSettlements.Title							= NStr("en = 'Loan repayment details'; ru = 'Выплата займа';pl = 'Szczegóły spłaty pożyczki';es_ES = 'Detalles de la entrada del pago de préstamo';es_CO = 'Detalles de devolución de préstamo';tr = 'Kredi geri ödemesi bilgileri';it = 'Dettagli di ricevuta di rimborso del prestito';de = 'Angaben zur Darlehensrückzahlung'");
		Items.LoanSettlements.Visible						= True;
		Items.SettlementsOnCreditsPaymentDetails.Visible	= True;
		Items.BorrowerLoanAgreement.Visible					= True;
		Items.FillByLoanContract.Visible					= True;
		Items.Item.Visible									= False;
		Items.CashCurrency.Enabled							= False;
		
		FillInformationAboutCreditLoanAtServer();
		SetCFItem();
		
		Items.GroupContractInformation.Visible	= True;	
		Items.PaymentAmount.Visible				= UseForeignCurrency;
		Items.PaymentAmount.Title				= NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'");
		
		Items.SettlementsOnCreditsPaymentDetailsPaymentAmount.Visible = UseForeignCurrency;
		
	Else
		
		Items.OtherSettlements.Visible	= True;
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"),
			NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'"), NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'"));
		
	EndIf;
	
	If Not Object.UseBankCharges Then
		Items.PaymentAmount.Visible = False; 
	EndIf;
	Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
	
	Items.GroupBankCharges.Visible	= Object.UseBankCharges;
	Items.BankFee.Visible			= Object.UseBankCharges;
	Items.BankFeeCurrency.Visible	= Object.UseBankCharges;
	
	SetVisibilityPlanningDocument();
	SetVisibilityExpenseItem();
	
EndProcedure

&AtServer
Procedure SetVisibilityPlanningDocument()
	
	If Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer
		Or Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromVendor
		Or Object.OperationKind = Enums.OperationTypesPaymentReceipt.PaymentFromThirdParties
		Or Object.OperationKind = Enums.OperationTypesPaymentReceipt.OtherSettlements
		Or Object.OperationKind = Enums.OperationTypesPaymentReceipt.LoanSettlements
		Or Object.OperationKind = Enums.OperationTypesPaymentReceipt.LoanRepaymentByEmployee
		Or Object.OperationKind = Enums.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty
		Or Object.OperationKind = Enums.OperationTypesPaymentReceipt.PayoutFromPaymentProcessor
		Or Not GetFunctionalOption("PaymentCalendar") Then
		Items.PlanningDocuments.Visible = False;
	Else
		Items.PlanningDocuments.Visible = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetVisibilityProject()
	
	Items.PaymentDetailsProject.Visible = False;
	Items.PaymentDetailsOtherSettlementsProject.Visible = False;
	
	IncomeItemType = Common.ObjectAttributeValue(Object.IncomeItem, "IncomeAndExpenseType");
	
	If Object.OperationKind = Enums.OperationTypesPaymentReceipt.Other
		And (IncomeItemType = Catalogs.IncomeAndExpenseTypes.Revenue
			Or IncomeItemType = Catalogs.IncomeAndExpenseTypes.OtherIncome) Then
		
		Items.PaymentDetailsProject.Visible = True;
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentReceipt.OtherSettlements Then
		
		Items.PaymentDetailsOtherSettlementsProject.Visible = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetVisibilitySettlementAttributes()
	
	If ValueIsFilled(Object.Counterparty) Then
		DoOperationsStructure = Common.ObjectAttributesValues(Object.Counterparty,
			"DoOperationsByContracts,DoOperationsByOrders");
	Else
		DoOperationsStructure = New Structure("DoOperationsByContracts,DoOperationsByOrders", False, False);
	EndIf;
	
	Items.PaymentDetailsContract.Visible					= DoOperationsStructure.DoOperationsByContracts;
	Items.PaymentDetailsOrder.Visible						= DoOperationsStructure.DoOperationsByOrders;
	Items.PaymentDetailsOtherSettlementsContract.Visible	= DoOperationsStructure.DoOperationsByContracts;
	
EndProcedure

&AtServer
Procedure SetVisibilityEPDAttributes()
	
	OperationKindFromCustomer = (Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer);
	
	VisibleFlag = (ValueIsFilled(Object.Counterparty) AND OperationKindFromCustomer);
	
	Items.PaymentDetailsEPDAmount.Visible				= VisibleFlag;
	Items.PaymentDetailsSettlementsEPDAmount.Visible	= VisibleFlag;
	Items.PaymentDetailsExistsEPD.Visible				= VisibleFlag;
	
EndProcedure

&AtServer
Procedure SetAccountingPolicyValues()
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Object.Company);
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	FunctionalOptionAccountingCashMethodIncomeAndExpenses = AccountingPolicy.CashMethodOfAccounting;
	
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

#Region BankCharges

&AtServer
Function GetDataBankChargeOnChange(BankCharge, CashCurrency)

	StructureData	= New Structure;
	
	StructureData.Insert("BankChargeItem", BankCharge.Item);
	StructureData.Insert("ExpenseItem", BankCharge.ExpenseItem);
	
	BankChargeAmount = ?(BankCharge.ChargeType = Enums.ChargeMethod.Percent, Object.DocumentAmount * BankCharge.Value / 100, BankCharge.Value);
	
	StructureData.Insert("BankChargeAmount", BankChargeAmount);
	
	Return StructureData;

EndFunction

&AtServer
Procedure SetTaxInvoiceText()
	Items.TaxInvoiceText.Visible = Not WorkWithVAT.GetPostAdvancePaymentsBySourceDocuments(Object.Date, Object.Company)
EndProcedure

#EndRegion

#EndRegion

#Region ExternalFormViewManagement
	
&AtServer
Procedure SetChoiceParameterLinksAvailableTypes()
	
	// Other settlemets
	If Object.OperationKind = Enums.OperationTypesPaymentReceipt.OtherSettlements Then
		SetChoiceParametersForAccountingOtherSettlementsAtServerForAccountItem();
	Else
		SetChoiceParametersOnMetadataForAccountItem();
	EndIf;
	// End Other settlemets
	
	If Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer Then
		
		Array = New Array();
		Array.Add(Type("DocumentRef.FixedAssetSale"));
		Array.Add(Type("DocumentRef.SupplierInvoice"));
		Array.Add(Type("DocumentRef.SalesInvoice"));
		Array.Add(Type("DocumentRef.SalesOrder"));
		Array.Add(Type("DocumentRef.AccountSalesFromConsignee"));
		Array.Add(Type("DocumentRef.ArApAdjustments"));
		
		ValidTypes = New TypeDescription(Array, , );
		Items.PaymentDetailsDocument.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.SalesOrder, DocumentRef.WorkOrder", ,);
		Items.PaymentDetailsOrder.TypeRestriction = ValidTypes;
		
		Items.PaymentDetailsDocument.ToolTip = NStr("en = 'The document that is paid for.'; ru = 'Оплачиваемый документ отгрузки товаров, работ и услуг контрагенту.';pl = 'Opłacany dokument.';es_ES = 'El documento que se ha pagado por.';es_CO = 'El documento que se ha pagado por.';tr = 'Ödeme yapılan belge.';it = 'Documento secondo cui il pagamento viene effettuato';de = 'Das Dokument, für das bezahlt wird.'");
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromVendor Then
		
		Array = New Array();
		Array.Add(Type("DocumentRef.ExpenseReport"));
		Array.Add(Type("DocumentRef.CashVoucher"));
		Array.Add(Type("DocumentRef.PaymentExpense"));
		Array.Add(Type("DocumentRef.ArApAdjustments"));
		Array.Add(Type("DocumentRef.AdditionalExpenses"));
		Array.Add(Type("DocumentRef.AccountSalesToConsignor"));
		Array.Add(Type("DocumentRef.SupplierInvoice"));
		Array.Add(Type("DocumentRef.SalesInvoice"));
		
		ValidTypes = New TypeDescription(Array, , );
		Items.PaymentDetailsDocument.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.PurchaseOrder", , );
		Items.PaymentDetailsOrder.TypeRestriction = ValidTypes;
		
		Items.PaymentDetailsDocument.ToolTip = NStr("en = 'An advance payment document that should be returned.'; ru = 'Документ расчетов с контрагентом, по которому осуществляется возврат денежных средств.';pl = 'Dokument płatności zaliczkowej do zwrotu.';es_ES = 'Un documento del pago anticipado que tiene que devolverse.';es_CO = 'Un documento del pago anticipado que tiene que devolverse.';tr = 'Geri dönmesi gereken bir avans ödeme belgesi.';it = 'Pagamento di un anticipo, documento che deve essere restituito.';de = 'Ein Vorauszahlungsbeleg, der zurückgegeben werden soll.'");
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentReceipt.PaymentFromThirdParties Then
		
		Items.PaymentDetailsDocument.TypeRestriction = New TypeDescription("DocumentRef.SalesInvoice");
		Items.PaymentDetailsDocument.ToolTip = NStr("en = 'The document that is paid for.'; ru = 'Оплачиваемый документ отгрузки товаров, работ и услуг контрагенту.';pl = 'Opłacany dokument.';es_ES = 'El documento que se ha pagado por.';es_CO = 'El documento que se ha pagado por.';tr = 'Ödeme yapılan belge.';it = 'Documento secondo cui il pagamento viene effettuato';de = 'Das Dokument, für das bezahlt wird.'");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// Procedure of the field change data processor Operation kind on server.
//
&AtServer
Procedure SetCFItemWhenChangingTheTypeOfOperations()
	
	If Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer
		AND (Object.Item = Catalogs.CashFlowItems.PaymentToVendor
		OR Object.Item = Catalogs.CashFlowItems.Other) Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromVendor
		AND (Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers
		OR Object.Item = Catalogs.CashFlowItems.Other) Then
		Object.Item = Catalogs.CashFlowItems.PaymentToVendor;
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentReceipt.LoanSettlements
		And ValueIsFilled(Object.LoanContract) Then
		Object.Item = Common.ObjectAttributeValue(Object.LoanContract, "PrincipalItem");
	ElsIf (Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers
		OR Object.Item = Catalogs.CashFlowItems.PaymentToVendor) Then
		Object.Item = Catalogs.CashFlowItems.Other;
	EndIf;
	
EndProcedure

// The procedure sets CF item when opening the form.
//
&AtServer
Procedure SetCFItem()
	
	If ValueIsFilled(Object.Item) Then
		Return;
	EndIf;
	
	If Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromVendor Then
		Object.Item = Catalogs.CashFlowItems.PaymentToVendor;
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentReceipt.LoanSettlements
		And ValueIsFilled(Object.LoanContract) Then
		Object.Item = Common.ObjectAttributeValue(Object.LoanContract, "PrincipalItem");
	Else
		Object.Item = Catalogs.CashFlowItems.Other;
	EndIf;
	
EndProcedure

// Procedure expands the operation kinds selection list.
//
&AtServer
Procedure SupplementOperationTypesChoiceList()
	
	If Constants.ForeignExchangeAccounting.Get() Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentReceipt.CurrencyPurchase);
	EndIf;
	
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentReceipt.Taxes);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentReceipt.Other);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentReceipt.LoanRepaymentByEmployee);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentReceipt.LoanSettlements);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentReceipt.OtherSettlements);
	
	If GetFunctionalOption("UseThirdPartyPayment") Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentReceipt.PaymentFromThirdParties);
	EndIf;
	
	If GetFunctionalOption("UsePaymentProcessors") Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentReceipt.PayoutFromPaymentProcessor);
	EndIf;
	
EndProcedure

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			False);
	ParametersStructure.Insert("FillHeader",			True);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	SetVisibleOfVATTaxation();
	SetVisibilitySettlementAttributes();
	SetVisibilityEPDAttributes();
	
	Modified = True;
	
EndProcedure

// The function puts the SettlementsDecryption tabular section
// to the temporary storage and returns the address.
//
&AtServer
Function PlacePaymentDetailsToStorage() 
	
	PaymentDetailsTableColumns =
		"Contract,
		|Item,
		|AdvanceFlag,
		|Document,
		|Order,
		|SettlementsAmount,
		|ExchangeRate,
		|Multiplicity";
	
	PaymentDetailsTable = Object.PaymentDetails.Unload( , PaymentDetailsTableColumns);
	
	Return PutToTempStorage(PaymentDetailsTable, UUID);
	
EndFunction

// Function receives the SettlementsDetails tabular section from the temporary storage.
//
&AtServer
Procedure GetPaymentDetailsFromStorage(AddressPaymentDetailsInStorage)
	
	TableExplanationOfPayment = GetFromTempStorage(AddressPaymentDetailsInStorage);
	
	IsFromCustomer = Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer;
	
	Object.PaymentDetails.Clear();
	
	For Each RowPaymentDetails In TableExplanationOfPayment Do
		
		NewRow = Object.PaymentDetails.Add();
		FillPropertyValues(NewRow, RowPaymentDetails);
		
		If Object.OperationKind = Enums.OperationTypesPaymentReceipt.PaymentFromThirdParties Then
			If ValueIsFilled(NewRow.Document) And TypeOf(NewRow.Document) = Type("DocumentRef.SalesInvoice") Then
				DocumentAttributes = Common.ObjectAttributesValues(NewRow.Document, "Counterparty, Contract");
				NewRow.ThirdPartyCustomer = DocumentAttributes.Counterparty;
				NewRow.ThirdPartyCustomerContract = DocumentAttributes.Contract;
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(NewRow.VATRate) Then
			VATRateData = DriveServer.DocumentVATRateData(NewRow.Document, DefaultVATRate, False);
			NewRow.VATRate = VATRateData.VATRate;
		EndIf;
		
		If IsFromCustomer Then
			NewRow.DiscountAllowedExpenseItem = DefaultExpenseItem;
		EndIf;
		
		NewRow.PaymentExchangeRate = Object.ExchangeRate;
		NewRow.PaymentMultiplier = Object.Multiplicity;
		
	EndDo;
	
	For Each Row In Object.PaymentDetails Do
		ProcessCounterpartyContractChangeAtServer(Row.GetID());
	EndDo;
	
EndProcedure

// Recalculates amounts by the document tabular section
// currency after changing the bank account or petty cash.
//
&AtServer
Procedure RecalculateDocumentAmounts(ExchangeRate, Multiplicity, RecalculatePaymentAmount)
	
	For Each TabularSectionRow In Object.PaymentDetails Do
		
		If TabularSectionRow.Contract.SettlementsCurrency = Object.CashCurrency Then
			TabularSectionRow.SettlementsAmount = TabularSectionRow.PaymentAmount;
			Continue;
		EndIf;
		
		If RecalculatePaymentAmount Then
			TabularSectionRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				ExchangeRateMethod,
				TabularSectionRow.ExchangeRate,
				ExchangeRate,
				TabularSectionRow.Multiplicity,
				Multiplicity);
			CalculateVATSUMAtServer(TabularSectionRow);
		Else
			TabularSectionRow.ExchangeRate = ?(
				TabularSectionRow.ExchangeRate = 0,
				1,
				TabularSectionRow.ExchangeRate);
			TabularSectionRow.Multiplicity = ?(
				TabularSectionRow.Multiplicity = 0,
				1,
				TabularSectionRow.Multiplicity);
			CalculateSettlementsAmount(TabularSectionRow, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
		EndIf;
	EndDo;
	
	If RecalculatePaymentAmount Then
		Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
	EndIf;
	
EndProcedure

// Recalculates amounts by the cash assets currency.
//
&AtClient
Procedure RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData)
	
	FillCurrencyChoiceList(ThisForm, "CurrencyPurchaseRate", Object.CashCurrency);
	FillCurrencyChoiceList(ThisForm, "OtherSettlementsExchangeRate", Object.CashCurrency);
	FillCurrencyChoiceList(ThisForm, "TaxesSettlementsExchangeRate", Object.CashCurrency);
	FillCurrencyChoiceList(ThisForm, "BankChargeExchangeRate", Object.CashCurrency);
	FillCurrencyChoiceList(ThisForm, "PaymentDetailsPaymentExchangeRate", Object.CashCurrency);
	FillCurrencyChoiceList(ThisForm, "PaymentDetailsOtherSettlementsPaymentExchangeRate", Object.CashCurrency);
	
	ExchangeRateBeforeChange = ExchangeRate;
	MultiplicityBeforeChange = Multiplicity;
	
	If StructureData.Property("UpdateExchangeRate") AND StructureData.UpdateExchangeRate Then
		
		UpdateExchangeRateInPaymentDetails(StructureData);
		Return;
		
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ExchangeRateBeforeChange", ExchangeRateBeforeChange);
	AdditionalParameters.Insert("MultiplicityBeforeChange", MultiplicityBeforeChange);
	
	DefineNeedToRecalculateAmountsOnRateChange(AdditionalParameters);
	
EndProcedure

&AtClient
Procedure DefinePaymentDetailsExistsEPD()
	
	DefinePaymentDetailsExistsEPDAtServer();
	
EndProcedure

&AtServer
Procedure DefinePaymentDetailsExistsEPDAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.DefinePaymentDetailsExistsEPD();
	ValueToFormAttribute(Document, "Object");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			True);
	ParametersStructure.Insert("FillHeader",			True);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	Modified = True;
	
EndProcedure

// Recalculate a payment amount in the passed tabular section string.
//
&AtClient
Procedure CalculatePaymentSUM(TabularSectionRow)
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
		1,
		TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(
		TabularSectionRow.Multiplicity = 0,
		1,
		TabularSectionRow.Multiplicity);
	
	TabularSectionRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		ExchangeRateMethod,
		TabularSectionRow.ExchangeRate,
		ExchangeRate,
		TabularSectionRow.Multiplicity,
		Multiplicity);
	
	If Not ValueIsFilled(TabularSectionRow.VATRate) Then
		TabularSectionRow.VATRate = DefaultVATRate;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure

// Perform recalculation of the amount accounting.
//
&AtClient
Procedure CalculateAccountingAmount()
	
	Object.ExchangeRate = ?(
		Object.ExchangeRate = 0,
		1,
		Object.ExchangeRate);
	Object.Multiplicity = ?(
		Object.Multiplicity = 0,
		1,
		Object.Multiplicity);
	
	Object.AccountingAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		Object.DocumentAmount,
		ExchangeRateMethod,
		Object.ExchangeRate,
		AccountingCurrencyRate,
		Object.Multiplicity,
		AccountingCurrencyMultiplicity);
	
EndProcedure

// Recalculates amounts by the document tabular section
// currency after changing the bank account or petty cash.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount - (TabularSectionRow.PaymentAmount) / ((VATRate + 100) / 100);
	
EndProcedure

&AtServer
Procedure CalculateVATSUMAtServer(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount - (TabularSectionRow.PaymentAmount) / ((VATRate + 100) / 100);
	
EndProcedure

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Counterparty, Company, Date)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company, Object.OperationKind);
	
	StructureData = New Structure;
	
	StructureData.Insert("Contract", ContractByDefault);
	
	CounterpartyData = GetRefAttributes(Counterparty, "DoOperationsByContracts,SettlementsCurrency");
	ContractData = Common.ObjectAttributesValues(ContractByDefault, "SettlementsCurrency, CashFlowItem");
	
	If CounterpartyData.DoOperationsByContracts Then
		SettlementsCurrency = ContractData.SettlementsCurrency;
	Else
		SettlementsCurrency = CounterpartyData.SettlementsCurrency;
	EndIf;
	
	CurrencyRate = CurrencyRateOperations.GetCurrencyRate(Date, SettlementsCurrency, Company);
	Rate = ?(CurrencyRate.Rate = 0, 1, CurrencyRate.Rate);
	Repetition = ?(CurrencyRate.Repetition = 0, 1, CurrencyRate.Repetition);
	
	StructureData.Insert("ContractCurrencyRateRepetition", CurrencyRate);
	StructureData.Insert("ExchangeRate", Rate);
	StructureData.Insert("Multiplier", Repetition);
	
	StructureData.Insert("Item", ContractData.CashFlowItem);
	
	StructureData.Insert("DoOperationsByContracts", CounterpartyData.DoOperationsByContracts);
	
	StructureData.Insert("SettlementsCurrency", SettlementsCurrency);
	
	If Object.OperationKind = Enums.OperationTypesPaymentReceipt.LoanSettlements Then
		DefaultLoanContract = GetDefaultLoanContract(Object.Ref, Counterparty, Company, Object.OperationKind);
		StructureData.Insert("DefaultLoanContract", DefaultLoanContract);
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty Then
		StructureData.Insert("ConfigureLoanContractItem", True);
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			True);
	ParametersStructure.Insert("FillHeader",			True);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	SetVisibilitySettlementAttributes();
	SetVisibilityEPDAttributes();
	
	Return StructureData;
	
EndFunction

// It receives data set from the server for the CurrencyCashOnChange procedure.
//
&AtServerNoContext
Function GetDataBankAccountOnChange(Date, BankAccount, Company)
	
	StructureData = New Structure;
	
	CurrencyRate = CurrencyRateOperations.GetCurrencyRate(Date, BankAccount.CashCurrency, Company);
	
	Rate = ?(CurrencyRate.Rate = 0, 1, CurrencyRate.Rate);
	Repetition = ?(CurrencyRate.Repetition = 0, 1, CurrencyRate.Repetition);
	
	StructureData.Insert("ExchangeRate", Rate);
	StructureData.Insert("Multiplier", Repetition);
	StructureData.Insert("CashCurrency", BankAccount.CashCurrency);
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure Attachable_ProcessDateChange()
	
	StructureData = GetDataDateOnChange();
	
	StructureData.Insert("UpdateExchangeRate", Object.PaymentDetails.Count() > 0);
	StructureData.Insert("UpdateExchangeRateQueryText", MessagesToUserClientServer.GetApplyRatesOnNewDateQuestionText());
	
	StructureData.Insert("UpdateExchangeRate", Object.PaymentDetails.Count() > 0);
	StructureData.Insert("UpdatePaymentExchangeRate", True);
	StructureData.Insert("UpdateSettlementsExchangeRate", True);
	StructureData.Insert("UpdateBankFeeExchangeRate", True);
	
	RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData);
	
	DefinePaymentDetailsExistsEPD();
	
	DocumentDate = Object.Date;
	
EndProcedure

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetDataDateOnChange()
	
	CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.CashCurrency, Object.Company);
	
	StructureData = New Structure;
	StructureData.Insert("CurrencyRateRepetition", CurrencyRateRepetition);
	StructureData.Insert("ExchangeRate", CurrencyRateRepetition.Rate);
	StructureData.Insert("Multiplier", CurrencyRateRepetition.Repetition);
	
	SetAccountingPolicyValues();
	
	ProcessingCompanyVATNumbers();
	
	FillVATRateByCompanyVATTaxation();
	SetVisibleOfVATTaxation();
	SetTaxInvoiceText();
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"ParentCompany",
		DriveServer.GetCompany(Object.Company));
	
	StructureData.Insert(
		"BankAccount",
		Object.Company.BankAccountByDefault);
	
	CurrencyRate = CurrencyRateOperations.GetCurrencyRate(Object.Date, StructureData.BankAccount.CashCurrency, Object.Company);
	
	StructureData.Insert("ExchangeRate", CurrencyRate.Rate);
	StructureData.Insert("Multiplier", CurrencyRate.Repetition);
	
	StructureData.Insert(
		"CashCurrency",
		Object.Company.BankAccountByDefault.CashCurrency);
	
	StructureData.Insert(
		"ExchangeRateMethod",
		DriveServer.GetExchangeMethod(Object.Company));
		
	StructureData.Insert(
		"PresentationCurrency",
		DriveServer.GetPresentationCurrency(Object.Company));
	
	SetAccountingPolicyValues();
	
	ProcessingCompanyVATNumbers(False);
	
	FillVATRateByCompanyVATTaxation();
	SetVisibleOfVATTaxation();
	SetVisibilityAmountAttributes();
	SetVisibilityBankChargeAmountAttributes();
	SetTaxInvoiceText();
	
	InformationRegisters.AccountingSourceDocuments.CheckNotifyTypesOfAccountingProblems(
		Object.Ref,
		Object.Company,
		DocumentDate);

	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			True);
	ParametersStructure.Insert("FillHeader",			True);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	Return StructureData;
	
EndFunction

// Procedure fills in default VAT rate.
//
&AtServer
Procedure FillDefaultVATRate()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
		DefaultVATRate = Catalogs.VATRates.Exempt;
	Else
		DefaultVATRate = Catalogs.VATRates.ZeroRate;
	EndIf;
	
EndProcedure

// Procedure fills the VAT rate in the tabular section
// according to company's taxation system.
// 
&AtServer
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	
	If Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer Then
		
		Object.VATTaxation = DriveServer.VATTaxation(Object.Company, Object.Date);
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentReceipt.LoanSettlements
		Or Object.OperationKind = Enums.OperationTypesPaymentReceipt.LoanRepaymentByEmployee
		Or Object.OperationKind = Enums.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty Then
		
		Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;
		
	Else
		
		Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
		
	EndIf;
	
	If Not (Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromAdvanceHolder
		OR Object.OperationKind = Enums.OperationTypesPaymentReceipt.Other
		OR Object.OperationKind = Enums.OperationTypesPaymentReceipt.CurrencyPurchase)
	   AND Not TaxationBeforeChange = Object.VATTaxation Then
		
		FillVATRateByVATTaxation();

	Else
		FillDefaultVATRate();
	EndIf;
	
EndProcedure

// Procedure fills the VAT rate in the tabular section according to the taxation system.
//
&AtServer
Procedure FillVATRateByVATTaxation(RestoreRatesOfVAT = True)
	
	FillDefaultVATRate();
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		VATRate = DriveReUse.GetVATRateValue(DefaultVATRate);
		
		If RestoreRatesOfVAT Then
			For Each TabularSectionRow In Object.PaymentDetails Do
				TabularSectionRow.VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
				TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount - (TabularSectionRow.PaymentAmount) / ((VATRate + 100) / 100);
			EndDo;
		EndIf;
		
	Else
		
		If RestoreRatesOfVAT Then
			For Each TabularSectionRow In Object.PaymentDetails Do
				TabularSectionRow.VATRate = DefaultVATRate;
				TabularSectionRow.VATAmount = 0;
			EndDo;
		EndIf;
		
	EndIf;
	
	SetVisibilityPlanningDocument();
	
EndProcedure

// Procedure sets the Taxation field visible.
//
&AtServer
Procedure SetVisibleOfVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		Items.PaymentDetailsVATRate.Visible							= True;
		Items.PaymentDetailsVatAmount.Visible						= True;
		Items.SettlementsOnCreditsPaymentDetailsVATRate.Visible		= True;
		Items.SettlementsOnCreditsPaymentDetailsVATAmount.Visible	= True;
		
		If Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer
			Or Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromVendor
			Or Object.OperationKind = Enums.OperationTypesPaymentReceipt.PaymentFromThirdParties Then
			Items.VATAmount.Visible = True;
		Else
			Items.VATAmount.Visible = False;
		EndIf;
		
	Else
		
		Items.SettlementsOnCreditsPaymentDetailsVATRate.Visible		= False;
		Items.SettlementsOnCreditsPaymentDetailsVATAmount.Visible	= False;
		Items.PaymentDetailsVATRate.Visible							= False;
		Items.PaymentDetailsVatAmount.Visible						= False;
		Items.VATAmount.Visible										= False;
		
	EndIf;
	
	Items.VATAmountCurrency.Visible = Items.VATAmount.Visible;
	
	If Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer
		Or Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromVendor
		Or Object.OperationKind = Enums.OperationTypesPaymentReceipt.PaymentFromThirdParties
		Or OperationKind = Enums.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty
		Or OperationKind = Enums.OperationTypesPaymentReceipt.LoanRepaymentByEmployee Then
		Items.VATTaxation.Visible = RegisteredForVAT;
	Else
		Items.VATTaxation.Visible = False;
	EndIf;
	
EndProcedure

// Procedure executes actions while changing counterparty contract.
//
&AtServer
Procedure ProcessCounterpartyContractChangeAtServer(RowId)
	
	TabularSectionRow = Object.PaymentDetails.FindByID(RowId);
	
	StructureData = GetStructureDataForObject(ThisObject, "PaymentDetails", TabularSectionRow, UseDefaultTypeOfAccounting);
	
	If ValueIsFilled(TabularSectionRow.Contract) Then
		
		StructureData = GetDataPaymentDetailsContractOnChange(
			Object.Date,
			TabularSectionRow.Contract,
			Object.Company,
			StructureData);
			
		TabularSectionRow.ExchangeRate = StructureData.ContractCurrencyRateRepetition.Rate;
		TabularSectionRow.Multiplicity = StructureData.ContractCurrencyRateRepetition.Repetition;
		TabularSectionRow.SettlementsCurrency = StructureData.SettlementsCurrency;
		
		FillPropertyValues(TabularSectionRow, StructureData);
	ElsIf UseDefaultTypeOfAccounting Then
		TabularSectionRow.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	EndIf;
	
	CalculateSettlementsAmount(TabularSectionRow, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

// Procedure executes actions while starting to select a counterparty contract.
//
&AtClient
Procedure ProcessStartChoiceCounterpartyContract(Item, StandardProcessing)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, TabularSectionRow.Contract, Object.OperationKind);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure fills in the PaymentDetails TS string with the billing document data.
//
&AtClient
Procedure ProcessAccountsDocumentSelection(DocumentData)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	If TypeOf(DocumentData) = Type("Structure") Then
		
		TabularSectionRow.Document = DocumentData.Document;
		TabularSectionRow.Order = DocumentData.Order;
		
		If Not ValueIsFilled(TabularSectionRow.Contract) Then
			TabularSectionRow.Contract = DocumentData.Contract;
			ProcessCounterpartyContractChangeAtServer(Items.PaymentDetails.CurrentRow);
		EndIf;
		
		RunActionsOnAccountsDocumentChange(TabularSectionRow);
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RunActionsOnAccountsDocumentChange(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.PaymentDetails.CurrentData;
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.FromVendor") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashVoucher")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.DebitNote") Then
			
			TabularSectionRow.AdvanceFlag = True;
			
		Else
			
			TabularSectionRow.AdvanceFlag = False;
			
		EndIf;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.FromCustomer") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.SalesInvoice") Then
			
			StructureData = GetStructureDataForObject(ThisObject, "PaymentDetails", TabularSectionRow, UseDefaultTypeOfAccounting);
			StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
			
			SetExistsEPD(StructureData);
			FillPropertyValues(TabularSectionRow, StructureData);
			
		EndIf;
		
		SetVisibilityCreditNoteText();
		
	EndIf;
	
	TabularSectionRow.PaymentAmount = 0;
	TabularSectionRow.SettlementsAmount = 0;
	TabularSectionRow.VATAmount = 0;
	
EndProcedure

&AtServer
Procedure SetExistsEPD(StructureData)
	
	StructureData.ExistsEPD = ExistsEPD(StructureData.Document, Object.Date);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillCounterpartyGLAccounts(StructureData);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ExistsEPD(Document, CheckDate)
	
	Return Documents.SalesInvoice.CheckExistsEPD(Document, CheckDate);
	
EndFunction

// Procedure is filling the payment details.
//
&AtServer
Procedure FillPaymentDetails()
	
	Document = FormAttributeToValue("Object");
	Document.FillPaymentDetails(WorkWithVAT.GetVATAmountFromBasisDocument(Object));
	ValueToFormAttribute(Document, "Object");
	
	SetVisibilityCreditNoteText();
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			True);
	ParametersStructure.Insert("FillHeader",			False);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure FillAdvancesPaymentDetails()
	
	Document = FormAttributeToValue("Object");
	Document.FillAdvancesPaymentDetails();
	ValueToFormAttribute(Document, "Object");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			True);
	ParametersStructure.Insert("FillHeader",			False);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure FillThirdPartyPaymentDetails()
	
	Document = FormAttributeToValue("Object");
	Document.FillThirdPartyPaymentDetails();
	ValueToFormAttribute(Document, "Object");	
	
	SetVisibilityCreditNoteText();
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillPaymentDetails", True);
	
	FillAddedColumns(ParametersStructure);
	
	Modified = True;
	
EndProcedure

// Checks the match of the "Company" and "ContractKind" contract attributes to the terms of the document.
//
&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(Val TSPaymentDetails, MessageText, Document, Company, Counterparty, OperationKind, Cancel, LoanContract)
	
	If Not DriveReUse.CounterpartyContractsControlNeeded()
		OR Not Counterparty.DoOperationsByContracts Then
		
		Return;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	If OperationKind = Enums.OperationTypesPaymentReceipt.LoanSettlements Then
		
		LoanKindList = New ValueList;
		LoanKindList.Add(Enums.LoanContractTypes.Borrowed);
		
		If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, LoanContract, Company, Counterparty, LoanKindList)
			AND Constants.CheckContractsOnPosting.Get() Then
			
			Cancel = True;
			
		EndIf;
		
	Else
		ContractKindsList = ManagerOfCatalog.GetContractTypesListForDocument(Document, OperationKind);
		
		For Each TabularSectionRow In TSPaymentDetails Do
			
			If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, TabularSectionRow.Contract, Company, Counterparty, ContractKindsList)
				AND Constants.CheckContractsOnPosting.Get() Then
				
				Cancel = True;
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;

	
EndProcedure

// Gets the default contract depending on the billing details.
//
&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company, OperationKind)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company, OperationKind);
	
EndFunction

&AtServerNoContext
Function GetSubordinateCreditNote(BasisDocument)
	
	Return EarlyPaymentDiscountsServer.GetSubordinateCreditNote(BasisDocument);
	
EndFunction

&AtServerNoContext
Function CheckBeforeCreditNoteFilling(BasisDocument)
	
	Return EarlyPaymentDiscountsServer.CheckBeforeCreditNoteFilling(BasisDocument, False)
	
EndFunction

&AtServer
Function SetVisibilityCreditNoteText()
	
	If Object.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer Then
		
		DocumentsTable			= Object.PaymentDetails.Unload(, "Document");
		PaymentDetailsDocuments	= DocumentsTable.UnloadColumn("Document");
		
		Items.CreditNoteText.Visible = EarlyPaymentDiscountsServer.AvailableCreditNoteEPD(PaymentDetailsDocuments);
		
	Else
		
		Items.CreditNoteText.Visible = False;
		
	EndIf;
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

// Procedure sets the current page depending on the operation kind.
//
&AtClient
Procedure SetCurrentPage()
	
	LineCount = Object.PaymentDetails.Count();
	
	If LineCount = 0 Then
		Object.PaymentDetails.Add();
		Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		LineCount = 1;
	EndIf;
	
EndProcedure

// The procedure clears the attributes that could have been
// filled in earlier but do not belong to the current operation.
//
&AtClient
Procedure ClearAttributesNotRelatedToOperation()
	
	Correspondence = Undefined;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.FromCustomer") Then
		Object.Correspondence = Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
		Object.TaxKind = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Order = Undefined;
			TableRow.Document = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.ThirdPartyCustomer = Undefined;
			TableRow.ThirdPartyCustomerContract = Undefined;
		EndDo;
		Object.POSTerminal = Undefined;
		Object.FeeTotal = 0;
		Object.RefundTotal = 0;
		Object.PaymentProcessorPayoutDetails.Clear();
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.FromVendor") Then
		Object.Correspondence = Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
		Object.TaxKind = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Order = Undefined;
			TableRow.Document = Undefined;
			TableRow.AdvanceFlag = True;
			TableRow.ThirdPartyCustomer = Undefined;
			TableRow.ThirdPartyCustomerContract = Undefined;
			TableRow.EPDAmount = 0;
			TableRow.SettlementsEPDAmount = 0;
			TableRow.ExistsEPD = False;
		EndDo;
		Object.POSTerminal = Undefined;
		Object.FeeTotal = 0;
		Object.RefundTotal = 0;
		Object.PaymentProcessorPayoutDetails.Clear();
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.FromAdvanceHolder") Then
		Object.Correspondence = Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
		Object.TaxKind = Undefined;
		Object.Counterparty = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.ThirdPartyCustomer = Undefined;
			TableRow.ThirdPartyCustomerContract = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.Other") Then
		Object.Counterparty = Undefined;
		Object.TaxKind = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
			TableRow.ThirdPartyCustomer = Undefined;
			TableRow.ThirdPartyCustomerContract = Undefined;
		EndDo;
		Object.POSTerminal = Undefined;
		Object.FeeTotal = 0;
		Object.RefundTotal = 0;
		Object.PaymentProcessorPayoutDetails.Clear();
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.CurrencyPurchase") Then
		Object.Counterparty = Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
		Object.TaxKind = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.ExchangeRate = ?(ValueIsFilled(ExchangeRate),
			ExchangeRate,
			1);
		Object.Multiplicity = ?(ValueIsFilled(Multiplicity),
			Multiplicity, 1);
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
			TableRow.ThirdPartyCustomer = Undefined;
			TableRow.ThirdPartyCustomerContract = Undefined;
		EndDo;
		Object.POSTerminal = Undefined;
		Object.FeeTotal = 0;
		Object.RefundTotal = 0;
		Object.PaymentProcessorPayoutDetails.Clear();
		CalculateAccountingAmount();
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.Taxes") Then
		Object.Counterparty = Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
		Object.CounterpartyAccount = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.Correspondence = Undefined;
		If Not FunctionalOptionAccountingCashMethodIncomeAndExpenses Then
			Object.BusinessLine = Undefined;
		EndIf;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
			TableRow.ThirdPartyCustomer = Undefined;
			TableRow.ThirdPartyCustomerContract = Undefined;
		EndDo;
		Object.POSTerminal = Undefined;
		Object.FeeTotal = 0;
		Object.RefundTotal = 0;
		Object.PaymentProcessorPayoutDetails.Clear();
	// Other settlemets	
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.OtherSettlements") Then
		Object.Correspondence		= Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
		Object.Counterparty			= Undefined;
		Object.CounterpartyAccount	= Undefined;
		Object.AdvanceHolder		= Undefined;
		Object.Document				= Undefined;
		Object.BusinessLine		= Undefined;
		Object.AccountingAmount		= 0;
		Object.ExchangeRate			= 0;
		Object.Multiplicity			= 0;
		Object.PaymentDetails.Clear();
		Object.PaymentDetails.Add();
		Object.POSTerminal = Undefined;
		Object.FeeTotal = 0;
		Object.RefundTotal = 0;
		Object.PaymentProcessorPayoutDetails.Clear();
		Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.LoanSettlements") Then
		Object.Correspondence = Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
		Object.Counterparty = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.BusinessLine = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
			TableRow.ThirdPartyCustomer = Undefined;
			TableRow.ThirdPartyCustomerContract = Undefined;
		EndDo;
		Object.POSTerminal = Undefined;
		Object.FeeTotal = 0;
		Object.RefundTotal = 0;
		Object.PaymentProcessorPayoutDetails.Clear();
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.LoanRepaymentByEmployee") Then
		Object.Correspondence = Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
		Object.Counterparty = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.BusinessLine = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
			TableRow.ThirdPartyCustomer = Undefined;
			TableRow.ThirdPartyCustomerContract = Undefined;
		EndDo;
		Object.POSTerminal = Undefined;
		Object.FeeTotal = 0;
		Object.RefundTotal = 0;
		Object.PaymentProcessorPayoutDetails.Clear();
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty") Then
		Object.Correspondence = Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
		Object.Counterparty = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.BusinessLine = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
			TableRow.ThirdPartyCustomer = Undefined;
			TableRow.ThirdPartyCustomerContract = Undefined;
		EndDo;
		Object.POSTerminal = Undefined;
		Object.FeeTotal = 0;
		Object.RefundTotal = 0;
		Object.PaymentProcessorPayoutDetails.Clear();
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.PaymentFromThirdParties") Then
		Object.Correspondence = Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
		Object.TaxKind = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Order = Undefined;
			TableRow.Document = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.PlanningDocument = Undefined;
			TableRow.EPDAmount = 0;
			TableRow.SettlementsEPDAmount = 0;
			TableRow.ExistsEPD = False;
		EndDo;
		Object.POSTerminal = Undefined;
		Object.FeeTotal = 0;
		Object.RefundTotal = 0;
		Object.PaymentProcessorPayoutDetails.Clear();
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.PayoutFromPaymentProcessor") Then
		Object.Correspondence = Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
		Object.TaxKind = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		Object.PaymentDetails.Clear();
		Object.PaymentDetails.Add();
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - handler of the Execute event of the Pickup command
// Opens the form of debt forming documents selection.
//
&AtClient
Procedure Pick(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(Undefined,NStr("en = 'Please select a counterparty.'; ru = 'Сначала выберите контрагента.';pl = 'Wybierz kontrahenta.';es_ES = 'Por favor, seleccione un contraparte.';es_CO = 'Por favor, seleccione un contraparte.';tr = 'Lütfen, cari hesap seçin.';it = 'Si prega di selezionare una controparte.';de = 'Bitte wählen Sie einen Geschäftspartner aus.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.BankAccount)
	   AND Not ValueIsFilled(Object.CashCurrency) Then
		ShowMessageBox(Undefined,NStr("en = 'Please select a bank account.'; ru = 'Выберите банковский счет.';pl = 'Wybierz rachunek bankowy.';es_ES = 'Por favor, seleccione una cuenta bancaria.';es_CO = 'Por favor, seleccione una cuenta bancaria.';tr = 'Lütfen, banka hesabı seçin.';it = 'Si prega di selezionare un conto corrente';de = 'Bitte wählen Sie ein Bankkonto aus.'"));
		Return;
	EndIf;
	
	AddressPaymentDetailsInStorage = PlacePaymentDetailsToStorage();
	
	SelectionParameters = New Structure(
		"AddressPaymentDetailsInStorage,
		|ParentCompany,
		|Date,
		|Counterparty,
		|Ref,
		|OperationKind,
		|CashCurrency,
		|DocumentAmount",
		AddressPaymentDetailsInStorage,
		ParentCompany,
		Object.Date,
		Object.Counterparty,
		Object.Ref,
		Object.OperationKind,
		Object.CashCurrency,
		Object.DocumentAmount);
		
	Result = Undefined;

		
	OpenForm("CommonForm.SelectInvoicesToBePaidByTheCustomer", SelectionParameters,,,,, New NotifyDescription("SelectionEnd", ThisObject, New Structure("AddressPaymentDetailsInStorage", AddressPaymentDetailsInStorage)));
	
EndProcedure

&AtClient
Procedure SelectionEnd(Result1, AdditionalParameters) Export
	
	AddressPaymentDetailsInStorage = AdditionalParameters.AddressPaymentDetailsInStorage;
	
	Result = Result1;
	If Result = DialogReturnCode.OK Then
		
		GetPaymentDetailsFromStorage(AddressPaymentDetailsInStorage);
		For Each RowPaymentDetails In Object.PaymentDetails Do
			CalculatePaymentSUM(RowPaymentDetails);
		EndDo;
		
		DefinePaymentDetailsExistsEPD();
		
		SetCurrentPage();
		
		If Object.PaymentDetails.Count() = 1 Then
			Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
		EndIf;
		
		SetVisibilityCreditNoteText();
		
		Modified = True;
		
	EndIf;

EndProcedure

// You can call the procedure by clicking
// the button "FillByBasis" of the tabular field command panel.
//
&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		ShowMessageBox(Undefined,NStr("en = 'Please select a base document.'; ru = 'Не выбран документ-основание.';pl = 'Wybierz dokument źródłowy.';es_ES = 'Por favor, seleccione un documento de base.';es_CO = 'Por favor, seleccione un documento de base.';tr = 'Lütfen, temel belge seçin.';it = 'Si prega di selezionare un documento di base.';de = 'Bitte wählen Sie ein Basisdokument aus.'"));
		Return;
	EndIf;
	
	Response = Undefined;

	
	ShowQueryBox(
		New NotifyDescription("FillByBasisEnd", ThisObject), 
		NStr("en = 'Do you want to refill the payment receipt?'; ru = 'Документ будет полностью перезаполнен по ""Основанию""! Продолжить?';pl = 'Czy chcesz uzupełnić potwierdzenie wpłaty?';es_ES = '¿Quiere volver a rellenar el recibo de pago?';es_CO = '¿Quiere volver a rellenar el recibo de pago?';tr = 'Ödeme makbuzunu yeniden doldurmak istiyor musunuz?';it = 'Volete ricompilare la ricevuta di pagamento?';de = 'Möchten Sie den Zahlungsbeleg auffüllen?'"), 
		QuestionDialogMode.YesNo, 
		0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		
		Object.BankAccount			= Undefined;
		Object.CounterpartyAccount	= Undefined;
		FillByDocument(Object.BasisDocument);
		
		If Object.PaymentDetails.Count() = 0 Then
			Object.PaymentDetails.Add();
			Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		EndIf;
		
		OperationKind	= Object.OperationKind;
		CashCurrency	= Object.CashCurrency;
		DocumentDate	= Object.Date;
		
		SetChoiceParameterLinksAvailableTypes();
		SetCurrentPage();
		
	EndIf;
	
EndProcedure

// Procedure - FillDetails command handler.
//
&AtClient
Procedure FillDetails(Command)
	
	If Object.DocumentAmount = 0
		And Object.OperationKind <> PredefinedValue("Enum.OperationTypesPaymentReceipt.FromVendor") Then
		ShowMessageBox(Undefined, NStr("en = 'Please specify the amount.'; ru = 'Введите сумму.';pl = 'Podaj wartość.';es_ES = 'Por favor, especifique el importe.';es_CO = 'Por favor, especifique el importe.';tr = 'Lütfen, tutarı belirtin.';it = 'Si prega di specificare l''importo.';de = 'Bitte geben Sie den Betrag an.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(Undefined,NStr("en = 'Please select a counterparty.'; ru = 'Выберите контрагента.';pl = 'Wybierz kontrahenta.';es_ES = 'Por favor, seleccione un contraparte.';es_CO = 'Por favor, seleccione un contraparte.';tr = 'Lütfen, cari hesap seçin.';it = 'Si prega di selezionare una controparte.';de = 'Bitte wählen Sie einen Geschäftspartner aus.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.BankAccount)
		And Not ValueIsFilled(Object.CashCurrency) Then
		ShowMessageBox(Undefined, NStr("en = 'Please select a bank account.'; ru = 'Выберите банковский счет.';pl = 'Wybierz rachunek bankowy.';es_ES = 'Por favor, seleccione una cuenta bancaria.';es_CO = 'Por favor, seleccione una cuenta bancaria.';tr = 'Lütfen, banka hesabı seçin.';it = 'Si prega di selezionare un conto corrente';de = 'Bitte wählen Sie ein Bankkonto aus.'"));
		Return;
	EndIf;
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillDetailsEnd", ThisObject), 
		NStr("en = 'You are about to fill in the payment details. This will overwrite the current details. Do you want to continue?'; ru = 'Расшифровка будет полностью перезаполнена. Продолжить?';pl = 'Zamierzasz wypełnić szczegóły płatności. Spowoduje to nadpisanie bieżących szczegółów. Czy chcesz kontynuować?';es_ES = 'Usted está a punto de rellenar los detalles de pago. Eso sobrescribirá los detalles actuales. ¿Quiere continuar?';es_CO = 'Usted está a punto de rellenar los detalles de pago. Eso sobrescribirá los detalles actuales. ¿Quiere continuar?';tr = 'Ödeme ayrıntılarını doldurmak üzeresiniz. Bu işlem mevcut ayrıntıların üzerine yazacaktır. Devam etmek istiyor musunuz?';it = 'State compilando i dettagli di pagamento. Questo sovrascriverà i dettagli correnti. Volete continuare?';de = 'Sie sind dabei, die Zahlungsdetails auszufüllen. Dadurch werden die aktuellen Details überschrieben. Möchten Sie fortsetzen?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillDetailsEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	Object.PaymentDetails.Clear();
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.FromCustomer") Then
		
		FillPaymentDetails();
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.PaymentFromThirdParties") Then
		
		FillThirdPartyPaymentDetails();
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.FromVendor") Then
		
		FillAdvancesPaymentDetails();
		
	EndIf;
	
	SetCurrentPage();
	
EndProcedure

&AtClient
Procedure FillPayoutDetails(Command)
	
	If Object.PaymentProcessorPayoutDetails.Count() > 0 Then
		
		ShowQueryBox(New NotifyDescription("FillPayoutDetailsQueryBoxHandler", ThisObject), 
			NStr("en = 'Payout details will be repopulated. Continue?'; ru = 'Платежная информация будет перезаполнена. Продолжить?';pl = 'Szczegóły płatności zostaną wypełnione ponownie. Kontynuować?';es_ES = 'Los detalles del pago serán repoblados. ¿Continuar?';es_CO = 'Los detalles del pago serán repoblados. ¿Continuar?';tr = 'Ödeme bilgileri yeniden doldurulacak. Devam edilsin mi?';it = 'I dettagli di pagamento saranno ricompilati. Continuare?';de = 'Auszahlungsdetails werden automatisch neu ausgefüllt. Fortfahren?'"),
			QuestionDialogMode.YesNo);
			
	Else
		
		ProcessFillPayoutDetails();
		
	EndIf;
	
EndProcedure

#Region EventHandlersOfHeaderAttributes

// Procedure - event handler OnChange of the Counterparty input field.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	StructureData = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company, Object.Date);
	
	FillPaymentDetailsByContractData(StructureData);
	
	If StructureData.Property("DefaultLoanContract") Then
		Object.LoanContract = StructureData.DefaultLoanContract;
		HandleLoanContractChange();
	EndIf;
	
	If StructureData.Property("ConfigureLoanContractItem") Then
		ConfigureLoanContractItem();
	EndIf;
	
EndProcedure

// Procedure - event handler OperationKindOnChange.
// Manages pages while changing document operation kind.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	TypeOfOperationsBeforeChange = OperationKind;
	OperationKind = Object.OperationKind;
	
	If OperationKind <> TypeOfOperationsBeforeChange Then
		SetCurrentPage();
		ClearAttributesNotRelatedToOperation();
		OperationKindOnChangeAtServer();
		CalculateAccountingAmount();
		
		IncomeAndExpenseItemsOnChangeConditions();
		
		If ValueIsFilled(Object.Counterparty) Then
			
			StructureContractData = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company, Object.Date);			
			FillPaymentDetailsByContractData(StructureContractData);
			
		EndIf;
		
		If Object.PaymentDetails.Count() = 1 Then
			
			Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
			
		EndIf;
	EndIf;
	
	SetVisibleCommandFillByBasis();
	
EndProcedure

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
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange();
	ParentCompany 				= StructureData.ParentCompany;
	Object.BankAccount 			= StructureData.BankAccount;
	ExchangeRateMethod 			= StructureData.ExchangeRateMethod;
	
	CurrencyCashBeforeChanging 		= CashCurrency;
	Object.CashCurrency 			= StructureData.CashCurrency;
	CashCurrency 					= StructureData.CashCurrency;
	PresentationCurrency			= StructureData.PresentationCurrency;
	
	// If currency is not changed, do nothing.
	If CashCurrency = CurrencyCashBeforeChanging Then
		Return;
	EndIf;
	
	If ValueIsFilled(Object.Counterparty) Then 
		
		StructureContractData = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company, Object.Date);
		FillPaymentDetailsByContractData(StructureContractData);
		
	EndIf;
	
	StructureData.Insert("UpdateExchangeRate", True);
	StructureData.Insert("UpdatePaymentExchangeRate", True);
	StructureData.Insert("UpdateSettlementsExchangeRate", False);
	StructureData.Insert("UpdateBankFeeExchangeRate", True);
	
	RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData);
	
EndProcedure

// Procedure - OnChange event handler of the BankAccount input field.
//
&AtClient
Procedure BankAccountOnChange(Item)
	
	ProcessBankAccountChange();
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.PayoutFromPaymentProcessor") Then
		Object.POSTerminal = POSTerminalByBankAccount(Object.BankAccount, Object.POSTerminal);
		ProcessPOSTerminalChange();
	EndIf;
	
EndProcedure

&AtClient
Procedure POSTerminalOnChange(Item)
	
	ProcessPOSTerminalChange();
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.PayoutFromPaymentProcessor") Then
		Object.BankAccount = BankAccountByPOSTerminal(Object.POSTerminal);
		ProcessBankAccountChange();
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the DocumentAmount input field.
//
&AtClient
Procedure DocumentAmountOnChange(Item)
	
	Object.AccountingAmount = GetAccountingAmount(Object.DocumentAmount,
		ExchangeRateMethod,
		Object.ExchangeRate,
		Object.Multiplicity);
	
	If Object.PaymentDetails.Count() = 1 Then
		
		TabularSectionRow = Object.PaymentDetails[0];
		
		FillPaymentAmount = Not Items.PlanningDocuments.Visible
			Or (Items.PlanningDocuments.Visible And ValueIsFilled(TabularSectionRow.PlanningDocument));
		
		FillAmountPresentationCurrency = Not FillPaymentAmount;
		
		TabularSectionRow.PaymentAmount = Object.DocumentAmount;
			TabularSectionRow.PaymentExchangeRate = ?(
				TabularSectionRow.PaymentExchangeRate = 0,
				1,
				TabularSectionRow.PaymentExchangeRate);
	
			TabularSectionRow.PaymentMultiplier = ?(
				TabularSectionRow.PaymentMultiplier = 0,
				1,
				TabularSectionRow.PaymentMultiplier);
		
			CalculateSettlementsAmount(TabularSectionRow, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
		
		If Not ValueIsFilled(TabularSectionRow.VATRate) Then
			TabularSectionRow.VATRate = DefaultVATRate;
		EndIf;
		
		CalculateVATSUM(TabularSectionRow);
	
	EndIf;
	
	Object.AccountingAmount = GetAccountingAmount(
		Object.DocumentAmount, 
		ExchangeRateMethod, 
		Object.ExchangeRate,
		Object.Multiplicity);
	
	CalculateTotal();
	
EndProcedure

&AtClient
Procedure TaxInvoiceTextClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	ParametersFilter = New Structure("AdvanceFlag", True);
	AdvanceArray = Object.PaymentDetails.FindRows(ParametersFilter);

	If AdvanceArray.Count() > 0 Then
		WorkWithVATClient.OpenTaxInvoice(ThisForm, False, True);
	Else
		CommonClientServer.MessageToUser(
			NStr("en = 'There are no rows with advance payments in the Payment details tab'; ru = 'В табличной части ""Расшифровка платежа"" отсутствуют авансовые платежи';pl = 'Na karcie Szczegóły płatności nie ma wierszy z zaliczkami';es_ES = 'No hay filas con los pagos anticipados en la pestaña de los Detalles de pago';es_CO = 'No hay filas con los pagos anticipados en la pestaña de los Detalles de pago';tr = 'Ödeme ayrıntıları sekmesinde avans ödemeye sahip herhangi bir satır yok';it = 'Non ci sono righe con anticipo pagamenti il nella scheda dettagli di pagamento';de = 'Auf der Registerkarte Zahlungsdetails gibt es keine Zeilen mit Vorauszahlungen'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure CreditNoteTextClick(Item, StandardProcessing)
	
	StandardProcessing	= False;
	IsError				= False;
	
	If NOT ValueIsFilled(Object.Ref) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Please, save the document.'; ru = 'Следует записать документ.';pl = 'Proszę, zapisz dokument.';es_ES = 'Por favor, guardar el documento.';es_CO = 'Por favor, guardar el documento.';tr = 'Lütfen, belgeyi kaydedin.';it = 'Per piacere, salvare il documento';de = 'Bitte speichern Sie das Dokument.'"));
		
		IsError = True;
		
	ElsIf CheckBeforeCreditNoteFilling(Object.Ref) Then
		
		IsError = True;
		
	EndIf;
	
	If NOT IsError Then
		
		CreditNoteFound = GetSubordinateCreditNote(Object.Ref);
		
		ParametersStructure = New Structure;
		
		If ValueIsFilled(CreditNoteFound) Then
			ParametersStructure.Insert("Key", CreditNoteFound);
		Else
			ParametersStructure.Insert("Basis", Object.Ref);
		EndIf;
		
		OpenForm("Document.CreditNote.ObjectForm", ParametersStructure, ThisObject);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region TabularSectionAttributeEventHandlers

// Procedure - BeforeDeletion event handler of the PaymentDetails tabular section.
//
&AtClient
Procedure PaymentDetailsBeforeDelete(Item, Cancel)
	
	If Object.PaymentDetails.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableSelection(ThisObject, "PaymentDetails", SelectedRow, Field, StandardProcessing);
	EndIf;
	
	If Field.Name = "PaymentDetailsIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "PaymentDetails");
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsOnActivateCell(Item)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnActivateCell(ThisObject, "PaymentDetails", ThisIsNewRow);
	EndIf;
	
	CurrentData = Items.PaymentDetails.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Item.CurrentItem <> Undefined
		And CommonClientServer.HasAttributeOrObjectProperty(Item.CurrentItem, "Name") 
		And Item.CurrentItem.Name = "PaymentDetailsSettlementsExchangeRate" Then
		FillCurrencyChoiceList(ThisForm, "PaymentDetailsSettlementsExchangeRate", CurrentData.SettlementsCurrency);
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.PaymentDetails.CurrentItem;
		
		If TableCurrentColumn.Name = "PaymentDetailsIncomeAndExpenseItems"
			And Not CurrentData.IncomeAndExpenseItemsFilled Then
			
			SelectedRow = Items.PaymentDetails.CurrentRow;
			IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "PaymentDetails");
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsOnActivateCell(Item)
	
	CurrentData = Items.PaymentDetailsOtherSettlements.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Item.CurrentItem <> Undefined
		And CommonClientServer.HasAttributeOrObjectProperty(Item.CurrentItem, "Name") 
		And Item.CurrentItem.Name = "PaymentDetailsOtherSettlementsSettlementsExchangeRate" Then
		FillCurrencyChoiceList(ThisForm, "PaymentDetailsOtherSettlementsSettlementsExchangeRate", CurrentData.SettlementsCurrency);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsOnStartEdit(Item, NewRow, Clone)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	
	If NewRow And Not Clone Then
		
		TabularSectionRow = Items.PaymentDetails.CurrentData;
		
		TabularSectionRow = Items.PaymentDetails.CurrentData;
		TabularSectionRow.PaymentExchangeRate = Object.ExchangeRate;
		TabularSectionRow.PaymentMultiplier = Object.Multiplicity;
		
		If ValueIsFilled(Object.Counterparty) Then
			
			CounterpartyAttributes = GetRefAttributes(Object.Counterparty, "DoOperationsByContracts");
			If Not CounterpartyAttributes.DoOperationsByContracts Then
				
				TabularSectionRow.Contract = GetContractByDefault(Object.Ref,
					Object.Counterparty,
					Object.Company,
					Object.OperationKind);
				
				ProcessCounterpartyContractChangeAtServer(Items.PaymentDetails.CurrentRow);
				
			EndIf;
			
		EndIf;
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.FromVendor") Then
			TabularSectionRow.AdvanceFlag = True;
		EndIf;
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.FromCustomer") Then
			TabularSectionRow.DiscountAllowedExpenseItem = DefaultExpenseItem;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsOnEditEnd(Item, NewRow, CancelEdit)
	
	GLAccountsInDocumentsClient.TableOnEditEnd(ThisIsNewRow);
	
EndProcedure

&AtClient
Procedure PaymentDetailsGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.GLAccountsStartChoice(ThisObject, "PaymentDetails", StandardProcessing);
	EndIf;
	
EndProcedure

// The OnChange event handler of the PaymentDetailsContract field.
// It updates the contract currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure PaymentDetailsContractOnChange(Item)
	
	ProcessCounterpartyContractChangeAtServer(Items.PaymentDetails.CurrentRow);
	
EndProcedure

// The OnChange event handler of the PaymentDetailsContract field.
// It updates the contract currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure PaymentDetailsContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	ProcessStartChoiceCounterpartyContract(Item, StandardProcessing);
	
EndProcedure

// Procedure - OnChange event handler of the PaymentDetailsSettlementsKind input field.
// Clears an attribute document if a settlement type is - "Advance".
//
&AtClient
Procedure PaymentDetailsAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.FromCustomer") Then
		
		If TabularSectionRow.AdvanceFlag Then
			TabularSectionRow.Document = Undefined;
		Else
			TabularSectionRow.PlanningDocument = Undefined;
		EndIf;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.FromVendor") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashVoucher")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.DebitNote")
			Or TabularSectionRow.Document = Undefined Then
			
			If Not TabularSectionRow.AdvanceFlag Then
				TabularSectionRow.AdvanceFlag = True;
				ShowMessageBox(, NStr("en = 'Cannot clear the ""Advance payment"" check box for this operation type.'; ru = 'Невозможно снять флажок ""Авансовый платеж"" для данного типа операций.';pl = 'Nie można oczyścić pola wyboru ""Zaliczka"" dla tego typu operacji.';es_ES = 'No se puede vaciar la casilla de verificación ""Pago anticipado"" para este tipo de operación.';es_CO = 'No se puede vaciar la casilla de verificación ""Pago anticipado"" para este tipo de operación.';tr = 'Bu işlem tipi için ""Avans ödemesi"" onay kutusunu temizleyemiyor.';it = 'Impossibile cancellare la casella di controllo ""Pagamento Anticipato"" per questo tipo di operazione.';de = 'Das Kontrollkästchen ""Vorauszahlung"" für diesen Operationstyp kann nicht deaktiviert werden.'"));
			EndIf;
			
		ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.ArApAdjustments") Then
			
			If TabularSectionRow.AdvanceFlag Then
				TabularSectionRow.AdvanceFlag = False;
				ShowMessageBox(, NStr("en = 'Cannot select the ""Advance payment"" check box for this operation type.'; ru = 'Для данного типа документа нельзя установить признак аванса.';pl = 'Nie można wybrać pola wyboru ""Zaliczka"" dla tego typu operacji.';es_ES = 'No se puede seleccionar la casilla de verificación ""Pago anticipado"" para este tipo de operación.';es_CO = 'No se puede seleccionar la casilla de verificación ""Pago anticipado"" para este tipo de operación.';tr = 'Bu işlem tipi için ""Avans ödemesi"" onay kutusu seçilmiyor.';it = 'Non è possibile selezionare la casella di controllo ""Pagamento Anticipato"" per questo tipo di operazione.';de = 'Das Kontrollkästchen ""Vorauszahlung"" kann für diesen Operationstyp nicht aktiviert werden.'"));
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - SelectionStart event handler of the PaymentDetailsDocument input field.
// Passes the current attribute value to the parameters.
//
&AtClient
Procedure PaymentDetailsDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If TabularSectionRow.AdvanceFlag
		AND Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.FromCustomer") Then
		
		ShowMessageBox(, 
			NStr("en = 'This is a billing document for advance payments.'; ru = 'Это документ расчета для авансовых платежей.';pl = 'Jest to dokument rozliczeniowy dla płatności zaliczkowych.';es_ES = 'Este es un documento de facturación para pagos anticipados.';es_CO = 'Este es un documento de facturación para pagos anticipados.';tr = 'Avans ödemeler için fatura belgesidir.';it = 'Questo è un documento di fatturazione per pagamenti anticipati.';de = 'Dies ist ein Abrechnungsbeleg für Vorauszahlungen.'"));
		
	Else
		
		StructureFilter = New Structure();
		StructureFilter.Insert("Company", Object.Company);
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.PaymentFromThirdParties") Then
			
			StructureFilter.Insert("Counterparty", TabularSectionRow.ThirdPartyCustomer);
			
			If ValueIsFilled(TabularSectionRow.ThirdPartyCustomerContract) Then
				StructureFilter.Insert("Contract", TabularSectionRow.ThirdPartyCustomerContract);
			EndIf;
			
			ParameterStructure = New Structure;
			
			ParameterStructure.Insert("Filter", StructureFilter);
			ParameterStructure.Insert("ThisIsAccountsReceivable", False);
			ParameterStructure.Insert("ThisIsThirdPartyPayment", True);
			ParameterStructure.Insert("DocumentType", TypeOf(Object.Ref));
			
		Else
			
			ThisIsAccountsReceivable = Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.FromCustomer");
			
			StructureFilter.Insert("Counterparty", Object.Counterparty);
			
			If ValueIsFilled(TabularSectionRow.Contract) Then
				StructureFilter.Insert("Contract", TabularSectionRow.Contract);
			EndIf;
			
			ParameterStructure = New Structure("Filter, ThisIsAccountsReceivable, DocumentType",
				StructureFilter,
				ThisIsAccountsReceivable,
				TypeOf(Object.Ref));
				
			ParameterStructure.Insert("IsSupplierReturn", Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.FromVendor"));
			ParameterStructure.Insert("Document", Object.Ref);	
			
		EndIf;
		
		OpenForm("CommonForm.SelectDocumentOfSettlements", ParameterStructure, Item);
		
	EndIf;
	
EndProcedure

// Procedure - SelectionDataProcessor event handler of the PaymentDetailsDocument input field.
//
&AtClient
Procedure PaymentDetailsDocumentChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	ProcessAccountsDocumentSelection(ValueSelected);
	
	Items.PaymentDetails.CurrentItem = Items.PaymentDetailsPaymentAmount;
	
EndProcedure

// Procedure - OnChange event handler of the field in PaymentDetailsSettlementsMiltiplier.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsSettlementMultiplierOnChange(Item)
	
	CurrentData = Items.PaymentDetails.CurrentData;
	CalculateSettlementsAmount(CurrentData, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

// Procedure - OnChange event handler of the field in PaymentDetailsSettlementsExchangeRate.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsSettlementExchangeRateOnChange(Item)
	
	CurrentData = Items.PaymentDetails.CurrentData;
	CalculateSettlementsAmount(CurrentData, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure PaymentDetailsSettlementsExchangeRateChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	CurrentData = Items.PaymentDetails.CurrentData;
	ExchangeRateChoiceProcessing("PaymentDetails", 
		"ExchangeRate", 
		SelectedValue, 
		StandardProcessing,
		CurrentData.SettlementsCurrency);
	
EndProcedure

// Procedure - OnChange event handler of the field in PaymentDetailsSettlementsAmount.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsSettlementsAmountOnChange(Item)
	
	CurrentData = Items.PaymentDetails.CurrentData;
	CalculateSettlementsRate(CurrentData);
	
EndProcedure

// Procedure - OnChange event handler of the PaymentDetailsExchangeRate input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsRateOnChange(Item)
	
	CurrentData = Items.PaymentDetails.CurrentData;
	CalculateSettlementsAmount(CurrentData, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

// Procedure - OnChange event handler of the PaymentDetailsUnitConversionFactor input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsRepetitionOnChange(Item)
	
	CurrentData = Items.PaymentDetails.CurrentData;
	CalculateSettlementsAmount(CurrentData, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

// The OnChange event handler of the PaymentDetailsPaymentMultiplier field.
// It updates the payment currency multiplier and settlements amount
//
&AtClient
Procedure PaymentDetailsPaymentMultiplierOnChange(Item)
	
	CurrentData = Items.PaymentDetails.CurrentData;
	CalculateSettlementsAmount(CurrentData, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

// The OnChange event handler of the PaymentDetailsPaymentExchangeRate field.
// It updates the payment currency exchange rate and settlements amount
//
&AtClient
Procedure PaymentDetailsPaymentExchangeRateOnChange(Item)
	
	CurrentData = Items.PaymentDetails.CurrentData;
	CalculateSettlementsAmount(CurrentData, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure PaymentDetailsPaymentExchangeRateChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	ExchangeRateChoiceProcessing("PaymentDetails", 
		"PaymentExchangeRate", 
		SelectedValue, 
		StandardProcessing,
		Object.CashCurrency);
	
EndProcedure

// The OnChange event handler of the PaymentDetailsPaymentAmount field.
// It updates the payment currency exchange rate and exchange rate multiplier, and also the VAT amount.
//
&AtClient
Procedure PaymentDetailsPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculateSettlementsAmount(TabularSectionRow, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
	If Not ValueIsFilled(TabularSectionRow.VATRate) Then
		TabularSectionRow.VATRate = DefaultVATRate;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure PaymentDetailsEPDAmountOnChange(Item)
	
	CurrentData = Items.PaymentDetails.CurrentData;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillPaymentDetails", True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtClient
Procedure PaymentDetailsAfterDeleteRow(Item)
	
	SetVisibilityCreditNoteText();
	
EndProcedure

// Procedure - OnChange event handler of the PaymentDetailsVATRate input field.
// Calculates VAT amount.
//
&AtClient
Procedure PaymentDetailsVATRateOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure

// Procedure - OnChange event handler of the PaymentDetailsDocument input field.
//
&AtClient
Procedure PaymentDetailsDocumentOnChange(Item)
	
	RunActionsOnAccountsDocumentChange();
	
EndProcedure

&AtClient
Procedure PaymentDetailsIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "PaymentDetails", StandardProcessing);
	
EndProcedure

// Procedure - OnChange event handler of the CurrencyPurchaseRate input field.
//
&AtClient
Procedure CurrencyPurchaseRateOnChange(Item)
	
	CalculateAccountingAmount();
	
EndProcedure

&AtClient
Procedure TaxesSettlementsExchangeRateChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	ExchangeRateChoiceProcessing("", "ExchangeRate", SelectedValue, StandardProcessing, Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure OtherSettlementsExchangeRateChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	ExchangeRateChoiceProcessing("", "ExchangeRate", SelectedValue, StandardProcessing, Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure CurrencyPurchaseRateChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	ExchangeRateChoiceProcessing("", "ExchangeRate", SelectedValue, StandardProcessing, Object.CashCurrency);
	
EndProcedure

// Procedure - OnChange event handler of the CurrencyPurchaseRepetition input field.
//
&AtClient
Procedure CurrencyPurchaseRepetitionOnChange(Item)
	
	CalculateAccountingAmount();
	
EndProcedure

// Procedure - OnChange event handler of the CurrencyPurchaseAccountingAmount input field.
//
&AtClient
Procedure CurrencyPurchaseAccountingAmountOnChange(Item)
	
	AccountingAmountOnChange();
	
EndProcedure

&AtClient
Procedure OtherSettlementsAccountingAmountOnChange(Item)
	
	AccountingAmountOnChange();
	
EndProcedure

&AtClient
Procedure TaxesSettlementsAccountingAmountOnChange(Item)
	
	AccountingAmountOnChange();
	
EndProcedure


&AtClient
Procedure VATTaxationOnChange(Item)
	
	FillVATRateByVATTaxation();
	SetVisibleOfVATTaxation();
	
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
	
	DriveClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
EndProcedure

#Region InteractiveActionResultHandlers

&AtClient
Procedure DefineNeedToRecalculateAmountsOnRateChange(AdditionalParameters) Export
	
	If Object.PaymentDetails.Count() > 0 Then
		
		RecalculateDocumentAmounts(ExchangeRate, Multiplicity, False);
		
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.CurrencyPurchase") Then
		
		CalculateAccountingAmount();
		
	EndIf;
	
	If NOT (Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.FromCustomer")) Then
		If AdditionalParameters.Property("UpdateExchangeRate")  AND AdditionalParameters.UpdateExchangeRate Then
			ShowQueryBox(New NotifyDescription("UpdateExchangeRateInPaymentDetails", ThisObject, AdditionalParameters),
				AdditionalParameters.UpdateExchangeRateQueryText,
				QuestionDialogMode.YesNo);
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetDataPaymentDetailsOnChange(Date, CounterpartyOrContract, Company)
	
	StructureData = New Structure;
	
	SettlementsCurrency = Common.ObjectAttributeValue(CounterpartyOrContract, "SettlementsCurrency");
	
	StructureData.Insert(
		"ContractCurrencyExchangeRate",
		CurrencyRateOperations.GetCurrencyRate(Date, SettlementsCurrency, Company));
	
	StructureData.Insert("SettlementsCurrency", SettlementsCurrency);
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure UpdatePaymentDetailsExchangeRateAtServer(AdditionalParameters)
	
	Var UpdatePaymentExchangeRate,UpdateSettlementsExchangeRate, UpdateBankFeeExchangeRate;
	
	Object.ExchangeRate = AdditionalParameters.ExchangeRate;
	Object.Multiplicity = AdditionalParameters.Multiplier;
	Object.BankChargeExchangeRate = AdditionalParameters.ExchangeRate;
	Object.BankChargeMultiplier = AdditionalParameters.Multiplier;
	
	Object.AccountingAmount = GetAccountingAmount(Object.DocumentAmount, 
		ExchangeRateMethod,
		Object.ExchangeRate,
		Object.Multiplicity);
	
	AdditionalParameters.Property("UpdatePaymentExchangeRate", UpdatePaymentExchangeRate);
	AdditionalParameters.Property("UpdateSettlementsExchangeRate", UpdateSettlementsExchangeRate);
	AdditionalParameters.Property("UpdateBankFeeExchangeRate", UpdateBankFeeExchangeRate);
	
	If UpdatePaymentExchangeRate Or UpdateBankFeeExchangeRate Then
		
		StructureBankAccountData = GetDataBankAccountOnChange(
			Object.Date,
			Object.BankAccount,
			Object.Company);
		
	EndIf;
	
	For Each TSRow In Object.PaymentDetails Do
		
		If UpdateSettlementsExchangeRate Then
		
			If ValueIsFilled(TSRow.Contract) Then
				Target = TSRow.Contract;
			Else
				Target = Object.Counterparty;
			EndIf;
			
			StructureSettlementsData = GetDataPaymentDetailsOnChange(Object.Date, Target, Object.Company);
			
			TSRow.ExchangeRate = ?(
				StructureSettlementsData.ContractCurrencyExchangeRate.Rate = 0,
				1,
				StructureSettlementsData.ContractCurrencyExchangeRate.Rate);
				
			TSRow.Multiplicity = ?(
				StructureSettlementsData.ContractCurrencyExchangeRate.Repetition = 0,
				1,
				StructureSettlementsData.ContractCurrencyExchangeRate.Repetition);
				
			RefreshRatesAndAmount(TSRow, PresentationCurrency, Object.CashCurrency);
			
		EndIf;
		
		If UpdatePaymentExchangeRate Then
			
			TSRow.PaymentExchangeRate = StructureBankAccountData.ExchangeRate;
			TSRow.PaymentMultiplier = StructureBankAccountData.Multiplier;
			
		EndIf;
		
		CalculateSettlementsAmount(TSRow, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
		
	EndDo;
	
	If UpdateBankFeeExchangeRate Then
		
		Object.BankChargeExchangeRate = StructureBankAccountData.ExchangeRate;
		Object.BankChargeMultiplier = StructureBankAccountData.Multiplier;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateExchangeRateInPaymentDetails(AdditionalParameters) Export

	UpdatePaymentDetailsExchangeRateAtServer(AdditionalParameters);

EndProcedure

#EndRegion

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

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributeItems()
	PropertyManager.UpdateAdditionalAttributesItems(ThisObject);
EndProcedure

// End StandardSubsystems.Properties

#EndRegion

#Region LoanContract

&AtServer
Procedure FillInformationAboutCreditLoanAtServer()
	
	ConfigureLoanContractItem();
	
	If Object.LoanContract.IsEmpty() Then
		
		Items.LabelCreditContractInformation.Title		= NStr("en = '<Select loan contract>'; ru = '<Выберите договор кредита (займа)>';pl = '<Wybierz umowę pożyczki>';es_ES = '<Seleccionar el contrato de préstamo>';es_CO = '<Seleccionar el contrato de préstamo>';tr = '<Kredi sözleşmesi seç>';it = '<Seleziona contratto di prestito>';de = '<Darlehensvertrag auswählen>'");
		Items.LabelRemainingDebtByCredit.Title			= "";		
		Items.LabelCreditContractInformation.TextColor	= StyleColors.BorderColor;
		Items.LabelRemainingDebtByCredit.TextColor		= StyleColors.BorderColor;
		
		Return;
		
	EndIf;
	
	If Object.OperationKind = Enums.OperationTypesPaymentReceipt.LoanRepaymentByEmployee
		OR Object.OperationKind = Enums.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty Then
		FillInformationAboutLoanAtServer();
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentReceipt.LoanSettlements Then
		FillInformationAboutCreditAtServer();
	EndIf;
	
EndProcedure

&AtServer
Procedure ConfigureLoanContractItem()
	
	If Object.OperationKind = Enums.OperationTypesPaymentReceipt.LoanRepaymentByEmployee Then
		
		Items.BorrowerLoanAgreement.Enabled = NOT Object.AdvanceHolder.IsEmpty();
		If Items.BorrowerLoanAgreement.Enabled Then
			Items.BorrowerLoanAgreement.InputHint = "";
		Else
			Items.BorrowerLoanAgreement.InputHint = NStr("en = 'Select an employee first.'; ru = 'Сначала выберите сотрудника.';pl = 'Najpierw wybierz pracownika.';es_ES = 'Primero seleccione un prestatario.';es_CO = 'Primero seleccione un prestatario.';tr = 'Önce, bir çalışan seçin.';it = 'Selezionare prima un dipendente.';de = 'Wählen Sie einen Mitarbeiter erst aus.'");
		EndIf;
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty Then
		
		Items.BorrowerLoanAgreement.Enabled = NOT Object.Counterparty.IsEmpty();
		If Items.BorrowerLoanAgreement.Enabled Then
			Items.BorrowerLoanAgreement.InputHint = "";
		Else
			Items.BorrowerLoanAgreement.InputHint = NStr("en = 'Select a borrower first.'; ru = 'Сначала выберите заемщика.';pl = 'Najpierw wybierz pożyczkobiorcę.';es_ES = 'Primero seleccione un prestatario.';es_CO = 'Primero seleccione un prestatario.';tr = 'Önce, borçlananı seçin.';it = 'Selezionare prima un debitore.';de = 'Wählen Sie einen Darlehensnehmer erst aus.'");
		EndIf;
		
	EndIf;
	
	Items.CreditContract.Enabled = NOT Object.Counterparty.IsEmpty();	
	If Items.CreditContract.Enabled Then
		Items.CreditContract.InputHint = "";
	Else
		Items.CreditContract.InputHint = NStr("en = 'Select a lender first.'; ru = 'Сначала выберите заимодателя.';pl = 'Najpierw wybierz pożyczkodawcę.';es_ES = 'Primero seleccione un prestamista.';es_CO = 'Primero seleccione un prestamista.';tr = 'Önce, borç vereni seçin.';it = 'Selezionare prima un prestatore.';de = 'Wählen Sie einen Darlehensgeber erst aus.'");
	EndIf;
	
EndProcedure

&AtServer
Procedure FillInformationAboutLoanAtServer();
	    
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	LoanRepaymentScheduleSliceLast.Period,
	|	LoanRepaymentScheduleSliceLast.Principal,
	|	LoanRepaymentScheduleSliceLast.Interest,
	|	LoanRepaymentScheduleSliceLast.Commission,
	|	LoanRepaymentScheduleSliceLast.LoanContract.SettlementsCurrency.Description AS CurrencyPresentation
	|FROM
	|	InformationRegister.LoanRepaymentSchedule.SliceLast(&SliceLastDate, LoanContract = &LoanContract) AS LoanRepaymentScheduleSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SUM(LoanSettlementsBalance.PrincipalDebtCurBalance) AS PrincipalDebtCurBalance,
	|	LoanSettlementsBalance.LoanContract.SettlementsCurrency,
	|	SUM(LoanSettlementsBalance.InterestCurBalance) AS InterestCurBalance,
	|	SUM(LoanSettlementsBalance.CommissionCurBalance) AS CommissionCurBalance,
	|	LoanSettlementsBalance.LoanContract.SettlementsCurrency.Description AS CurrencyPresentation
	|FROM
	|	AccumulationRegister.LoanSettlements.Balance(, LoanContract = &LoanContract) AS LoanSettlementsBalance
	|
	|GROUP BY
	|	LoanSettlementsBalance.LoanContract.SettlementsCurrency,
	|	LoanSettlementsBalance.LoanContract.SettlementsCurrency.Description
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	LoanRepaymentScheduleSliceFirst.Period,
	|	LoanRepaymentScheduleSliceFirst.Principal,
	|	LoanRepaymentScheduleSliceFirst.Interest,
	|	LoanRepaymentScheduleSliceFirst.Commission,
	|	LoanRepaymentScheduleSliceFirst.LoanContract.SettlementsCurrency.Description AS CurrencyPresentation
	|FROM
	|	InformationRegister.LoanRepaymentSchedule.SliceFirst(&SliceLastDate, LoanContract = &LoanContract) AS LoanRepaymentScheduleSliceFirst";
	
	Query.SetParameter("SliceLastDate",			?(Object.Date = '00010101', BegOfDay(CurrentSessionDate()), BegOfDay(Object.Date)));
	Query.SetParameter("LoanContract",	Object.LoanContract);
	
	ResultsArray = Query.ExecuteBatch();
	
	InformationAboutLoan = "";
	
	SelectionSchedule = ResultsArray[0].Select();
	SelectionScheduleFutureMonth = ResultsArray[2].Select();
	
	LabelCreditContractInformationTextColor	= StyleColors.BorderColor;
	LabelRemainingDebtByCreditTextColor		= StyleColors.BorderColor;
	
	If SelectionScheduleFutureMonth.Next() Then
		
		If BegOfMonth(?(Object.Date = '00010101', CurrentSessionDate(), Object.Date)) = BegOfMonth(SelectionScheduleFutureMonth.Period) Then
			PaymentDate = Format(SelectionScheduleFutureMonth.Period, "DLF=D");
		Else
			
			PaymentDate = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 (not in the current month)'; ru = '%1 (не в текущем месяце)';pl = '%1 (nie w bieżącym miesiącu)';es_ES = '%1(no en el mes actual)';es_CO = '%1(no en el mes actual)';tr = '%1(mevcut ayda değil)';it = '%1 (non nel mese corrente)';de = '%1(nicht im aktuellen Monat)'"),
				Format(SelectionScheduleFutureMonth.Period, "DLF=D"));
			LabelCreditContractInformationTextColor = StyleColors.FormTextColor;
			
		EndIf;
			
		LabelCreditContractInformation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Payment date: %1. Debt amount: %2. Interest: %3. Commission: %4 (%5)'; ru = 'Дата платежа: %1. Сумма долга: %2. Сумма %: %3. Комиссия: %4 (%5)';pl = 'Data płatności: %1. Kwota długu: %2. Odsetki: %3. Prowizja: %4 (%5)';es_ES = 'Fecha de pago: %1. Importe de la deuda: %2. Interés: %3. Comisión: %4 (%5)';es_CO = 'Fecha de pago: %1. Importe de la deuda: %2. Interés: %3. Comisión: %4 (%5)';tr = 'Ödeme tarihi: %1. Borç tutarı: %2. Faiz: %3. Komisyon: %4 (%5)';it = 'Data di pagamento %1. Importo del debito: %2. Interessi: %3. Commissioni: %4 (%5)';de = 'Zahlungstermin: %1. Schuldenbetrag: %2. Zinsen: %3. Provisionszahlung: %4 (%5)'"),
			PaymentDate,
			Format(SelectionScheduleFutureMonth.Principal, 	"NFD=2; NZ=0"),
			Format(SelectionScheduleFutureMonth.Interest, 	"NFD=2; NZ=0"),
			Format(SelectionScheduleFutureMonth.Commission, "NFD=2; NZ=0"),
			SelectionScheduleFutureMonth.CurrencyPresentation);
		
	ElsIf SelectionSchedule.Next() Then
		
		If BegOfMonth(?(Object.Date = '00010101', CurrentSessionDate(), Object.Date)) = BegOfMonth(SelectionSchedule.Period) Then
			PaymentDate = Format(SelectionSchedule.Period, "DLF=D");
		Else
			PaymentDate = Format(SelectionSchedule.Period, "DLF=D") + " (" + NStr("en = 'not in the current month'; ru = 'не в текущем месяце';pl = 'nie w bieżącym miesiącu';es_ES = 'no el mes corriente';es_CO = 'no el mes corriente';tr = ' cari ayda değil';it = 'non nel mese corrente';de = 'nicht im aktuellen Monat'") + ")";
			LabelCreditContractInformationTextColor = StyleColors.FormTextColor;
		EndIf;
			
		LabelCreditContractInformation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Payment date: %1. Debt amount: %2. Interest: %3. Commission: %4 (%5)'; ru = 'Дата платежа: %1. Сумма долга: %2. Сумма %: %3. Комиссия: %4 (%5)';pl = 'Data płatności: %1. Kwota długu: %2. Odsetki: %3. Prowizja: %4 (%5)';es_ES = 'Fecha de pago: %1. Importe de la deuda: %2. Interés: %3. Comisión: %4 (%5)';es_CO = 'Fecha de pago: %1. Importe de la deuda: %2. Interés: %3. Comisión: %4 (%5)';tr = 'Ödeme tarihi: %1. Borç tutarı: %2. Faiz: %3. Komisyon: %4 (%5)';it = 'Data di pagamento %1. Importo del debito: %2. Interessi: %3. Commissioni: %4 (%5)';de = 'Zahlungstermin: %1. Schuldenbetrag: %2. Zinsen: %3. Provisionszahlung: %4 (%5)'"),
			PaymentDate,
			Format(SelectionSchedule.Principal, 	"NFD=2; NZ=0"),
			Format(SelectionSchedule.Interest, 		"NFD=2; NZ=0"),
			Format(SelectionSchedule.Commission, 	"NFD=2; NZ=0"),
			SelectionSchedule.CurrencyPresentation);
		
	Else
		
		LabelCreditContractInformation = NStr("en = 'Payment date: <not specified>'; ru = 'Дата платежа: <не указана>';pl = 'Data płatności: <nieokreślona>';es_ES = 'Fecha de pago: <no especificado>';es_CO = 'Fecha de pago: <no especificado>';tr = 'Ödeme tarihi: <belirtilmemiş>';it = 'Data di pagamento: <non specificata>';de = 'Zahlungstermin: <not specified>'");
		
	EndIf;
	
	SelectionBalance = ResultsArray[1].Select();
	If SelectionBalance.Next() Then
		
		LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Debt balance: %1. Interest: %2. Commission amount: %3 (%4)'; ru = 'Остаток долга: %1. Сумма %: %2. Комиссия: %3 (%4)';pl = 'Saldo zadłużenia: %1. Odsetki: %2. Kwota prowizji: %3 (%4)';es_ES = 'Saldo de la deuda: %1. Interés: %2. Importe de la comisión: %3 (%4)';es_CO = 'Saldo de la deuda: %1. Interés: %2. Importe de la comisión: %3 (%4)';tr = 'Borç bakiyesi: %1. Faiz: %2. Komisyon tutarı: %3 (%4)';it = 'Saldo del debito: %1. Interesse: %2. Commissioni: %3 (%4)';de = 'Schuldensaldo: %1. Zinsen: %2Provisionszahlung: %3 (%4)'"),
			Format(SelectionBalance.PrincipalDebtCurBalance, 	"NFD=2; NZ=0"),
			Format(SelectionBalance.InterestCurBalance, 		"NFD=2; NZ=0"),
			Format(SelectionBalance.CommissionCurBalance, 		"NFD=2; NZ=0"),
			SelectionBalance.CurrencyPresentation);
			
			LabelRemainingDebtByCreditTextColor = StyleColors.FormTextColor;
	Else
		
		LabelRemainingDebtByCredit = NStr("en = 'Debt balance: <not specified>'; ru = 'Остаток долга: <не указан>';pl = 'Saldo zadłużenia: <nieokreślone>';es_ES = 'Saldo de la deuda: <no especificado>';es_CO = 'Saldo de la deuda: <no especificado>';tr = 'Borç bakiyesi: <belirtilmemiş>';it = 'Saldo del debito: <non specificato>';de = 'Schuldensaldo: <not specified>'");
		
	EndIf;
	
	Items.LabelCreditContractInformation.Title		= LabelCreditContractInformation;
	Items.LabelRemainingDebtByCredit.Title			= LabelRemainingDebtByCredit;	
	Items.LabelCreditContractInformation.TextColor	= LabelCreditContractInformationTextColor;
	Items.LabelRemainingDebtByCredit.TextColor		= LabelRemainingDebtByCreditTextColor;
		
EndProcedure

&AtServer
Procedure FillInformationAboutCreditAtServer()

	LabelCreditContractInformationTextColor	= StyleColors.BorderColor;
	LabelRemainingDebtByCreditTextColor		= StyleColors.BorderColor;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	LoanSettlementsTurnovers.LoanContract.SettlementsCurrency AS Currency,
	|	LoanSettlementsTurnovers.PrincipalDebtCurExpense
	|INTO TemporaryTableAmountsIssuedBefore
	|FROM
	|	AccumulationRegister.LoanSettlements.Turnovers(
	|			,
	|			,
	|			,
	|			LoanContract = &LoanContract
	|				AND Company = &Company) AS LoanSettlementsTurnovers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TemporaryTableAmountsIssuedBefore.Currency,
	|	SUM(TemporaryTableAmountsIssuedBefore.PrincipalDebtCurExpense) AS PrincipalDebtCurExpense,
	|	LoanContract.Total
	|FROM
	|	TemporaryTableAmountsIssuedBefore AS TemporaryTableAmountsIssuedBefore
	|		INNER JOIN Document.LoanContract AS LoanContract
	|		ON TemporaryTableAmountsIssuedBefore.Currency = LoanContract.SettlementsCurrency
	|WHERE
	|	LoanContract.Ref = &LoanContract
	|
	|GROUP BY
	|	TemporaryTableAmountsIssuedBefore.Currency,
	|	LoanContract.Total";
	
	Query.SetParameter("LoanContract",	Object.LoanContract);
	Query.SetParameter("Company",				Object.Company);
	Query.SetParameter("Employee",				Object.AdvanceHolder);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		
		LabelCreditContractInformation = NStr("en = 'Credit amount:'; ru = 'Сумма кредита:';pl = 'Kwota kredytu:';es_ES = 'Importe de crédito:';es_CO = 'Importe de crédito:';tr = 'Kredi tutarı:';it = 'Importo del credito:';de = 'Kreditbetrag:'")+ " " + 
			Selection.Total + " (" + Selection.Currency + ")";
		
		If Selection.Total < Selection.PrincipalDebtCurExpense Then
			
			LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Remaining debt amount: %1 (%2). Received amount: %3 (%2)'; ru = 'Осталось получить: %1 (%2). Уже получено %3 (%2)';pl = 'Pozostała kwota długu: %1 (%2). Otrzymana kwota: %3 (%2)';es_ES = 'Importe de la deuda restante: %1 (%2). Importe recibido: %3 (%2)';es_CO = 'Importe de la deuda restante: %1 (%2). Importe recibido: %3 (%2)';tr = 'Kalan borç tutarı: %1 (%2). Alınan tutar: %3 (%2)';it = 'Importo debito residuo: %1 (%2). Importo ricevuto: %3 (%2)';de = 'Verbleibender Schuldenbetrag: %1 (%2). Erhaltener Betrag: %3 (%2)'"),
				Selection.Total - Selection.PrincipalDebtCurExpense,
				Selection.Currency,
				Selection.PrincipalDebtCurExpense);
			LabelRemainingDebtByCreditTextColor = StyleColors.SpecialTextColor;
			
		ElsIf Selection.Total = Selection.PrincipalDebtCurExpense Then
			LabelRemainingDebtByCredit = NStr("en = 'Remaining debt amount: 0 ('; ru = 'Осталось получить: 0 (';pl = 'Pozostała kwota długu: 0 (';es_ES = 'Importe de la deuda restante: 0 (';es_CO = 'Importe de la deuda restante: 0 (';tr = 'Kalan borç tutarı: 0 (';it = 'Importo debito residuo: 0 (';de = 'Verbleibender Schuldenbetrag: 0 ('") + Selection.Currency + ")";
			LabelRemainingDebtByCreditTextColor = StyleColors.SpecialTextColor;
		Else
			LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Remaining debt amount: %1 (%2). Received amount: %3 (%2)'; ru = 'Осталось получить: %1 (%2). Уже получено %3 (%2)';pl = 'Pozostała kwota długu: %1 (%2). Otrzymana kwota: %3 (%2)';es_ES = 'Importe de la deuda restante: %1 (%2). Importe recibido: %3 (%2)';es_CO = 'Importe de la deuda restante: %1 (%2). Importe recibido: %3 (%2)';tr = 'Kalan borç tutarı: %1 (%2). Alınan tutar: %3 (%2)';it = 'Importo debito residuo: %1 (%2). Importo ricevuto: %3 (%2)';de = 'Verbleibender Schuldenbetrag: %1 (%2). Erhaltener Betrag: %3 (%2)'"),
				Selection.Total - Selection.PrincipalDebtCurExpense,
				Selection.Currency,
				Selection.PrincipalDebtCurExpense);
		EndIf;
			
	Else
		LabelCreditContractInformation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Loan amount: %1 (%2).'; ru = 'Сумма займа: %1 (%2).';pl = 'Kwota pożyczki: %1 (%2).';es_ES = 'Importe del préstamo: %1 (%2).';es_CO = 'Importe del préstamo: %1 (%2).';tr = 'Borç tutarı: %1 (%2).';it = 'L''importo del prestito: %1 (%2)';de = 'Darlehensbetrag: %1 (%2)'"),
			Object.LoanContract.Total,
			Object.LoanContract.SettlementsCurrency);
		LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Remaining debt amount: %1 (%2).'; ru = 'Остаток задолженности: %1 (%2).';pl = 'Pozostała kwota długu: %1 (%2).';es_ES = 'Importe de la deuda restante: %1 (%2).';es_CO = 'Importe de la deuda restante: %1 (%2).';tr = 'Kalan borç tutarı: %1 (%2).';it = 'Importo debito residuo: %1 (%2).';de = 'Verbleibender Schuldenbetrag: %1 (%2).'"),
			Object.LoanContract.Total,
			Object.LoanContract.SettlementsCurrency);
	EndIf;
	
	Items.LabelCreditContractInformation.Title		= LabelCreditContractInformation;
	Items.LabelRemainingDebtByCredit.Title			= LabelRemainingDebtByCredit;	
	Items.LabelCreditContractInformation.TextColor	= LabelCreditContractInformationTextColor;
	Items.LabelRemainingDebtByCredit.TextColor		= LabelRemainingDebtByCreditTextColor;
	
EndProcedure

&AtClient
Procedure HandleLoanContractChange()
	
	EmployeeLoanAgreementData = EmployeeLoanContractOnChangeAtServer(Object.LoanContract, Object.Date);
	
	FillInformationAboutCreditLoanAtServer();
	
	DataStructure = GetDataPaymentDetailsContractOnChange(
		Object.Date,
		Object.LoanContract,
		Object.Company);
	
	For Each TabularSectionRow In Object.PaymentDetails Do
		
		TabularSectionRow.ExchangeRate = DataStructure.ContractCurrencyRateRepetition.Rate;
		TabularSectionRow.Multiplicity = DataStructure.ContractCurrencyRateRepetition.Repetition;
		
		CalculateSettlementsAmount(TabularSectionRow, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
		
	EndDo;
	
	Items.SettlementsOnCreditsPaymentDetailsTypeOfAmount.ChoiceList.Clear();
	
	If EmployeeLoanAgreementData.NoCommission Then
		Items.SettlementsOnCreditsPaymentDetailsTypeOfAmount.ChoiceList.Add(PredefinedValue("Enum.LoanScheduleAmountTypes.Interest"));
		Items.SettlementsOnCreditsPaymentDetailsTypeOfAmount.ChoiceList.Add(PredefinedValue("Enum.LoanScheduleAmountTypes.Principal"));
		Items.SettlementsOnCreditsPaymentDetailsTypeOfAmount.ListChoiceMode = True;
	Else
		Items.SettlementsOnCreditsPaymentDetailsTypeOfAmount.ListChoiceMode = False;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function EmployeeLoanContractOnChangeAtServer(EmployeeLoanContract, Date)
	
	DataStructure = New Structure;
	
	DataStructure.Insert("Currency",				EmployeeLoanContract.SettlementsCurrency);
	DataStructure.Insert("Counterparty",			EmployeeLoanContract.Counterparty);
	DataStructure.Insert("Employee",				EmployeeLoanContract.Employee);
	DataStructure.Insert("ThisIsLoanContract",		EmployeeLoanContract.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement
														Or EmployeeLoanContract.LoanKind = Enums.LoanContractTypes.CounterpartyLoanAgreement);
														
	DataStructure.Insert("NoCommission",			EmployeeLoanContract.CommissionType = Enums.LoanCommissionTypes.No);
	
	Return DataStructure;
	 	
EndFunction

&AtServerNoContext
Function GetDefaultLoanContract(Document, Counterparty, Company, OperationKind)
	
	DocumentManager = Documents.LoanContract;
	
	LoanKindList = New ValueList;
	LoanKindList.Add(?(OperationKind = Enums.OperationTypesPaymentReceipt.LoanSettlements, 
		Enums.LoanContractTypes.Borrowed,
		Enums.LoanContractTypes.EmployeeLoanAgreement));
	                                                   
	DefaultLoanContract = DocumentManager.ReceiveLoanContractByDefaultByCompanyLoanKind(Counterparty, Company, LoanKindList);
	
	Return DefaultLoanContract;
	
EndFunction

&AtClient
Procedure BasisDocumentOnChange(Item)
	
	If ValueIsFilled(Object.BasisDocument)
		And TypeOf(Object.BasisDocument) = Type("DocumentRef.LoanContract")
		And (Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty")
			Or Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.LoanRepaymentByEmployee")
			Or Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.LoanSettlements")) Then
		Object.LoanContract = Object.BasisDocument;
		HandleLoanContractChange();
	EndIf;
	
EndProcedure

&AtClient
Procedure BorrowerLoanAgreementOnChange(Item)
	HandleLoanContractChange();
EndProcedure

&AtClient
Procedure CreditContractOnChange(Item)
	HandleLoanContractChange();
EndProcedure

&AtServerNoContext
Function GetEmployeeDataOnChange(Employee, Date, Company)
	
	DataStructure = New Structure;
	
	DataStructure.Insert("LoanContract", 
		Documents.LoanContract.ReceiveLoanContractByDefaultByCompanyLoanKind(Employee, Company));
	
	Return DataStructure;
	
EndFunction

&AtClient
Procedure SettlementsOnCreditsPaymentDetailsSettlementsAmountOnChange(Item)
	
	CalculatePaymentAmountAtClient(Items.SettlementsOnCreditsPaymentDetails.CurrentData);
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure

&AtClient
Procedure SettlementsOnCreditsPaymentDetailsExchangeRateOnChange(Item)
	
	CalculatePaymentAmountAtClient(Items.SettlementsOnCreditsPaymentDetails.CurrentData);
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure

&AtClient
Procedure SettlementsOnCreditsPaymentDetailsMultiplicityOnChange(Item)
		
	CalculatePaymentAmountAtClient(Items.SettlementsOnCreditsPaymentDetails.CurrentData);
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure

&AtClient
Procedure SettlementsOnCreditsPaymentDetailsVATRateOnChange(Item)
		
	TabularSectionRow = Items.SettlementsOnCreditsPaymentDetails.CurrentData;
	CalculateVATAmountAtClient(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure SettlementsOnCreditsPaymentDetailsPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.SettlementsOnCreditsPaymentDetails.CurrentData;
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
		1,
		TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(
		TabularSectionRow.Multiplicity = 0,
		1,
		TabularSectionRow.Multiplicity);
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.SettlementsAmount = 0,
		1,
		TabularSectionRow.PaymentAmount / TabularSectionRow.SettlementsAmount * ExchangeRate);
	
	If NOT ValueIsFilled(TabularSectionRow.VATRate) Then
		TabularSectionRow.VATRate = DefaultVATRate;
	EndIf;
	
	CalculateVATAmountAtClient(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure SettlementsOnCreditsPaymentDetailsBeforeDeleteRow(Item, Cancel)
	
	If Object.PaymentDetails.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure FillByLoanContract(Command)
	
	If Object.LoanContract.IsEmpty() Then
		ShowMessageBox(Undefined, NStr("en = 'Select contract'; ru = 'Выберите договор';pl = 'Wybierz umowę';es_ES = 'Seleccionar un contrato';es_CO = 'Seleccionar un contrato';tr = 'Sözleşme seçin';it = 'Selezionare contratto';de = 'Wählen Sie den Vertrag aus'"));
		Return;
	EndIf;
	
	OpenFormLoanRepaymentDetails();
	
EndProcedure

&AtClient
Procedure FillByCreditContractEnd(FillingResult, CompletionParameters) Export
	
	FillDocumentAmount = False;
	
	If TypeOf(FillingResult) = Type("Structure") Then
		
		FillDocumentAmount = False;
		
		If FillingResult.Property("ClearTabularSectionOnPopulation") 
			AND FillingResult.ClearTabularSectionOnPopulation Then
				Object.PaymentDetails.Clear();
				FillDocumentAmount = True;
		EndIf;
		
		If FillingResult.Property("PaymentExplanationAddressInStorage") Then
			GetPaymentDetailsFromStorage(FillingResult.PaymentExplanationAddressInStorage);
			
			If Object.PaymentDetails.Count() = 1 Then
				Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
			EndIf;
		EndIf;
		
		If FillDocumentAmount Then
			Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
			DocumentAmountOnChange(Items.DocumentAmount);
		EndIf;
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillByCreditContract(Command)
	
	If Object.LoanContract.IsEmpty() Then
		ShowMessageBox(Undefined, NStr("en = 'Select contract'; ru = 'Выберите договор';pl = 'Wybierz umowę';es_ES = 'Seleccionar un contrato';es_CO = 'Seleccionar un contrato';tr = 'Sözleşme seçin';it = 'Selezionare contratto';de = 'Wählen Sie den Vertrag aus'"));
		Return;
	EndIf;
	
	FillByCreditContractAtServer();
	DocumentAmountOnChange(Items.DocumentAmount);
	
EndProcedure

&AtClient
Procedure FillByBorrowerLoanAgreement(Command)
	
	If Object.LoanContract.IsEmpty() Then
		ShowMessageBox(Undefined, NStr("en = 'Select contract'; ru = 'Выберите договор';pl = 'Wybierz umowę';es_ES = 'Seleccionar un contrato';es_CO = 'Seleccionar un contrato';tr = 'Sözleşme seçin';it = 'Seleziona contratto';de = 'Vertrag auswählen'"));
		Return;
	EndIf;
	
	FillByCreditContractAtServer();
	OpenFormLoanRepaymentDetails();
	DocumentAmountOnChange(Items.DocumentAmount);
	
EndProcedure

&AtClient
Procedure OpenFormLoanRepaymentDetails()
	
	PaymentExplanationAddressInStorage = PlacePaymentDetailsToStorage();
	FilterParameters = New Structure;
	FilterParameters.Insert("PaymentExplanationAddressInStorage", PaymentExplanationAddressInStorage);
	FilterParameters.Insert("Company", Object.Company);
	FilterParameters.Insert("Recorder", Object.Ref);
	FilterParameters.Insert("DocumentFormID", UUID);
	FilterParameters.Insert("OperationKind", Object.OperationKind);
	FilterParameters.Insert("Date", Object.Date);
	FilterParameters.Insert("Currency", Object.CashCurrency);
	FilterParameters.Insert("LoanContract", Object.LoanContract);
	FilterParameters.Insert("DocumentAmount", Object.DocumentAmount);
	FilterParameters.Insert("Counterparty", Object.Counterparty);
	FilterParameters.Insert("DefaultVATRate", DefaultVATRate);
	FilterParameters.Insert("PaymentAmount", Object.PaymentDetails.Total("PaymentAmount"));
	FilterParameters.Insert("Rate", ExchangeRate);
	FilterParameters.Insert("Multiplicity", Multiplicity);
	FilterParameters.Insert("Employee", Object.AdvanceHolder);
	
	OpenForm("CommonForm.LoanRepaymentDetails",
		FilterParameters,
		ThisObject,,,,
		New NotifyDescription("FillByCreditContractEnd", ThisObject));
	
EndProcedure

&AtServer
Procedure FillByCreditContractAtServer()
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	LoanSettlementsTurnovers.LoanContract.SettlementsCurrency AS Currency,
	|	LoanSettlementsTurnovers.PrincipalDebtCurExpense
	|INTO TemporaryTableAmountsIssuedBefore
	|FROM
	|	AccumulationRegister.LoanSettlements.Turnovers(
	|			,
	|			,
	|			,
	|			LoanContract = &LoanContract
	|				AND Company = &Company) AS LoanSettlementsTurnovers
	|
	|UNION ALL
	|
	|SELECT
	|	LoanSettlements.LoanContract.SettlementsCurrency,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN -LoanSettlements.PrincipalDebtCur
	|		ELSE LoanSettlements.PrincipalDebtCur
	|	END
	|FROM
	|	AccumulationRegister.LoanSettlements AS LoanSettlements
	|WHERE
	|	LoanSettlements.Recorder = &Ref
	|	AND LoanSettlements.LoanContract = &LoanContract
	|	AND LoanSettlements.Company = &Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TemporaryTableAmountsIssuedBefore.Currency,
	|	SUM(TemporaryTableAmountsIssuedBefore.PrincipalDebtCurExpense) AS PrincipalDebtCurExpense,
	|	LoanContract.Total
	|FROM
	|	TemporaryTableAmountsIssuedBefore AS TemporaryTableAmountsIssuedBefore
	|		INNER JOIN Document.LoanContract AS LoanContract
	|		ON TemporaryTableAmountsIssuedBefore.Currency = LoanContract.SettlementsCurrency
	|WHERE
	|	LoanContract.Ref = &LoanContract
	|
	|GROUP BY
	|	TemporaryTableAmountsIssuedBefore.Currency,
	|	LoanContract.Total
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ExchangeRateSlaceLast.Rate AS ExchangeRate,
	|	ExchangeRateSlaceLast.Repetition AS Multiplicity
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(, Currency = &SettlementsCurrency AND Company = &Company) AS ExchangeRateSlaceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ExchangeRateSlaceLast.Rate AS ExchangeRate,
	|	ExchangeRateSlaceLast.Repetition AS Multiplicity
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(, Currency = &CashCurrency AND Company = &Company) AS ExchangeRateSlaceLast";
	
	Query.SetParameter("LoanContract",			Object.LoanContract);
	Query.SetParameter("Company",				Object.Company);
	Query.SetParameter("Ref",					Object.Ref);
	Query.SetParameter("SettlementsCurrency",	Object.LoanContract.SettlementsCurrency);
	Query.SetParameter("CashCurrency",			Object.CashCurrency);
	
	ResultsArray = Query.ExecuteBatch();
	
	Selection = ResultsArray[1].Select();
	
	SelectionContractCurrency = ResultsArray[2].Select();
	If SelectionContractCurrency.Next() Then
		ContractExchangeRate = SelectionContractCurrency.ExchangeRate;
		ContractMultiplicity = SelectionContractCurrency.Multiplicity;
	Else
		ContractExchangeRate = 1;
		ContractMultiplicity = 1;
	EndIf;
	
	SelectionCashCurrency = ResultsArray[3].Select();
	If SelectionCashCurrency.Next() Then
		DocumentExchangeRate = SelectionCashCurrency.ExchangeRate;
		DocumentMultiplicity = SelectionCashCurrency.Multiplicity;
	Else
		DocumentExchangeRate = 1;
		DocumentMultiplicity = 1;
	EndIf;
	
	If Selection.Next() Then
		
		MessageText = "";
		
		If Selection.Total < Selection.PrincipalDebtCurExpense Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Issued under the loan contract: %1 (%2).'; ru = 'Выдано по договору займа: %1 (%2).';pl = 'Wydano według umowy pożyczki: %1 (%2).';es_ES = 'Emitido bajo el contrato de préstamo:%1 (%2).';es_CO = 'Emitido bajo el contrato de préstamo:%1 (%2).';tr = 'Kredi sözleşmesi kapsamında verilen: %1(%2).';it = 'Emesso in base a contratto di prestito %1 (%2)';de = 'Ausgestellt unter dem Darlehensvertrag %1 (%2)'"),
				Selection.PrincipalDebtCurExpense,
				Selection.Currency);
		ElsIf Selection.Total = Selection.PrincipalDebtCurExpense Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The complete amount has been already issued under the loan contract: %1 (%2).'; ru = 'По договору займа уже выдана вся сумма %1 (%2).';pl = 'Cała wartość według umowy pożyczki została już wydana %1 (%2)';es_ES = 'El importe completo se ha emitido bajo el contrato de préstamo: %1 (%2).';es_CO = 'El importe completo se ha emitido bajo el contrato de préstamo: %1 (%2).';tr = 'Toplam tutar önceden kredi sözleşmesi kapsamında zaten verildi: %1 (%2).';it = 'L''importo completo è già stato emesso in base al contratto di prestito %1 (%2)';de = 'Die gesamte Menge wurde bereits im Rahmen des Darlehensvertrags %1 (%2) ausgegeben.'"),
				Selection.PrincipalDebtCurExpense,
				Selection.Currency);
		Else
			Object.DocumentAmount = (Selection.Total - Selection.PrincipalDebtCurExpense) * ContractExchangeRate * 
				DocumentMultiplicity / (ContractMultiplicity * DocumentExchangeRate);
		EndIf;
		
		If MessageText <> "" Then
			CommonClientServer.MessageToUser(MessageText,, "BorrowerLoanAgreement");
		EndIf;
		
	Else
		Object.DocumentAmount = Object.LoanContract.Total * ContractExchangeRate * 
			DocumentMultiplicity / (ContractMultiplicity * DocumentExchangeRate);
	EndIf;
		
	Modified = True;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

&AtClient
Procedure FillPayoutDetailsQueryBoxHandler(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		ProcessFillPayoutDetails();
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessFillPayoutDetails()
	
	FillPayoutDetailsAtServer();
	CalculateProcessorPayoutTotals();
	CalculateTotal();
	
EndProcedure

&AtServer
Procedure FillPayoutDetailsAtServer()
	
	Query = New Query;
	
	Query.SetParameter("Company", Object.Company);
	Query.SetParameter("Currency", Object.CashCurrency);
	Query.SetParameter("POSTerminal", Object.POSTerminal);
	Query.SetParameter("Ref", Object.Ref);
	
	Query.Text =
	"SELECT
	|	FundsTransfersBeingProcessedBalance.Document AS Document,
	|	FundsTransfersBeingProcessedBalance.AmountCurBalance AS AmountBalance,
	|	FundsTransfersBeingProcessedBalance.FeeAmountBalance AS FeeAmountBalance
	|INTO TT_Balances
	|FROM
	|	AccumulationRegister.FundsTransfersBeingProcessed.Balance(
	|			,
	|			Company = &Company
	|				AND Currency = &Currency
	|				AND POSTerminal = &POSTerminal) AS FundsTransfersBeingProcessedBalance
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentEntries.Document,
	|	CASE
	|		WHEN DocumentEntries.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -DocumentEntries.AmountCur
	|		ELSE DocumentEntries.AmountCur
	|	END,
	|	CASE
	|		WHEN DocumentEntries.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -DocumentEntries.FeeAmount
	|		ELSE DocumentEntries.FeeAmount
	|	END
	|FROM
	|	AccumulationRegister.FundsTransfersBeingProcessed AS DocumentEntries
	|WHERE
	|	DocumentEntries.Recorder = &Ref
	|	AND DocumentEntries.Company = &Company
	|	AND DocumentEntries.Currency = &Currency
	|	AND DocumentEntries.POSTerminal = &POSTerminal
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Balances.Document AS Document,
	|	OnlineReceipt.Date AS PaymentDate,
	|	TT_Balances.AmountBalance AS Amount,
	|	TT_Balances.FeeAmountBalance AS FeeAmount,
	|	0 AS RefundAmount,
	|	0 AS RefundFeeAmount,
	|	OnlineReceipt.ChargeCardKind AS ChargeCardKind,
	|	OnlineReceipt.ChargeCardNo AS ChargeCardNo,
	|	OnlineReceipt.BasisDocument AS Order,
	|	FALSE AS IsRefund
	|FROM
	|	TT_Balances AS TT_Balances
	|		INNER JOIN Document.OnlineReceipt AS OnlineReceipt
	|		ON TT_Balances.Document = OnlineReceipt.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	TT_Balances.Document,
	|	OnlinePayment.Date,
	|	0,
	|	0,
	|	-TT_Balances.AmountBalance,
	|	TT_Balances.FeeAmountBalance,
	|	OnlinePayment.ChargeCardKind,
	|	OnlinePayment.ChargeCardNo,
	|	ISNULL(CAST(OnlinePayment.BasisDocument AS Document.SalesOrder), OnlineReceipt.BasisDocument),
	|	TRUE
	|FROM
	|	TT_Balances AS TT_Balances
	|		INNER JOIN Document.OnlinePayment AS OnlinePayment
	|		ON TT_Balances.Document = OnlinePayment.Ref
	|		LEFT JOIN Document.OnlineReceipt AS OnlineReceipt
	|		ON (OnlinePayment.BasisDocument = OnlineReceipt.Ref)
	|
	|ORDER BY
	|	OnlineReceipt.Date,
	|	Document";
	
	Object.PaymentProcessorPayoutDetails.Load(Query.Execute().Unload());
	
EndProcedure

&AtClient
Procedure CalculateProcessorPayoutTotals()
	
	Object.FeeTotal = Object.PaymentProcessorPayoutDetails.Total("FeeAmount")
		+ Object.PaymentProcessorPayoutDetails.Total("RefundFeeAmount");
	
	Object.RefundTotal = Object.PaymentProcessorPayoutDetails.Total("RefundAmount");
	
	Object.DocumentAmount = Object.PaymentProcessorPayoutDetails.Total("Amount") - Object.FeeTotal - Object.RefundTotal;
	
	If Object.PaymentDetails.Count() = 0 Then
		Object.PaymentDetails.Add();
	ElsIf Object.PaymentDetails.Count() > 1 Then
		While Object.PaymentDetails.Count() > 1 Do
			Object.PaymentDetails.Delete(Object.PaymentDetails.Count() - 1);
		EndDo;
	EndIf;
	
	Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
	
EndProcedure

&AtServerNoContext
Function PayoutDetailsDocumentData(Document)
	
	DocumentData = Common.ObjectAttributesValues(Document,
		"Date, DocumentAmount, FeeTotal, ChargeCardKind, ChargeCardNo, BasisDocument, BasisDocument.BasisDocument");
	
	Result = New Structure;
	Result.Insert("PaymentDate", DocumentData.Date);
	Result.Insert("ChargeCardKind", DocumentData.ChargeCardKind);
	Result.Insert("ChargeCardNo", DocumentData.ChargeCardNo);
	If ValueIsFilled(DocumentData.BasisDocument) And TypeOf(DocumentData.BasisDocument) = Type("DocumentRef.SalesOrder") Then
		Result.Insert("Order", DocumentData.BasisDocument);
	Else
		Result.Insert("Order", DocumentData.BasisDocumentBasisDocument);
	EndIf;
	
	If TypeOf(Document) = Type("DocumentRef.OnlinePayment") Then
		
		Result.Insert("Amount", 0);
		Result.Insert("FeeAmount", 0);
		Result.Insert("RefundAmount", DocumentData.DocumentAmount);
		Result.Insert("RefundFeeAmount", DocumentData.FeeTotal);
		Result.Insert("IsRefund", True);
		
	Else
		
		Result.Insert("Amount", DocumentData.DocumentAmount);
		Result.Insert("FeeAmount", DocumentData.FeeTotal);
		Result.Insert("RefundAmount", 0);
		Result.Insert("RefundFeeAmount", 0);
		Result.Insert("IsRefund", False);
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure FillPaymentProcessorPayoutDetailsAdditionalFields()
	
	For Each PayoutDetailsRow In Object.PaymentProcessorPayoutDetails Do
		PayoutDetailsRow.IsRefund = (TypeOf(PayoutDetailsRow.Document) = Type("DocumentRef.OnlinePayment"));
	EndDo;
	
EndProcedure

&AtServerNoContext
Function BankAccountByPOSTerminal(POSTerminal)
	
	Return Common.ObjectAttributeValue(POSTerminal, "BankAccount");
	
EndFunction

&AtClient
Procedure ProcessPOSTerminalChange()
	
	ProcessPOSTerminalChangeAtServer();
	
	CalculateTotal();
	
EndProcedure

&AtServer
Procedure ProcessPOSTerminalChangeAtServer()
	
	POSTerminalData = Common.ObjectAttributesValues(Object.POSTerminal,
		"WithholdFeeOnPayout, Project, PaymentProcessorContract.CashFlowItem, ExpenseItem");
	
	If Object.PaymentDetails.Count() = 0 Then
		Object.PaymentDetails.Add();
	EndIf;
	
	PaymentDetailsRow = Object.PaymentDetails[0];
	PaymentDetailsRow.Item = POSTerminalData.PaymentProcessorContractCashFlowItem;
	PaymentDetailsRow.Project = POSTerminalData.Project;
	
	WithholdFeeOnPayout = POSTerminalData.WithholdFeeOnPayout;
	SetVisibilityPOSTermialWithholdFeeOnPayoutDependant();
	If Not WithholdFeeOnPayout Then
		Object.PaymentProcessorPayoutDetails.Clear();
		Object.DocumentAmount = 0;
		PaymentDetailsRow.PaymentAmount = 0;
		Object.FeeTotal = 0;
		Object.RefundTotal = 0;
		Object.ExpenseItem = Catalogs.IncomeAndExpenseItems.EmptyRef();
	Else
		Object.ExpenseItem = POSTerminalData.ExpenseItem;
	EndIf;
	
	SetVisibilityExpenseItem();
	
EndProcedure

&AtServerNoContext
Function POSTerminalByBankAccount(BankAccount, POSTerminal)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	POSTerminals.Ref AS Ref
	|FROM
	|	Catalog.POSTerminals AS POSTerminals
	|WHERE
	|	POSTerminals.Ref = &POSTerminal
	|	AND POSTerminals.BankAccount = &BankAccount
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	POSTerminals.Ref AS Ref
	|FROM
	|	Catalog.POSTerminals AS POSTerminals
	|WHERE
	|	NOT POSTerminals.DeletionMark
	|	AND POSTerminals.BankAccount = &BankAccount
	|	AND POSTerminals.TypeOfPOS = VALUE(Enum.TypesOfPOS.OnlinePayments)";
	
	Query.SetParameter("BankAccount", BankAccount);
	Query.SetParameter("POSTerminal", POSTerminal);
	
	Sel = Query.Execute().Select();
	
	If Sel.Next() Then
		
		Return Sel.Ref;
		
	Else
		
		Return Catalogs.POSTerminals.EmptyRef();
		
	EndIf;
	
	
EndFunction

&AtClient
Procedure ProcessBankAccountChange()
	
	CurrencyCashBeforeChanging = CashCurrency;
	
	StructureData = GetDataBankAccountOnChange(Object.Date, Object.BankAccount, Object.Company);
	
	Object.CashCurrency = StructureData.CashCurrency;
	CashCurrency = StructureData.CashCurrency;
	
	If CurrencyCashBeforeChanging = StructureData.CashCurrency
		Or Not ValueIsFilled(StructureData.CashCurrency) Then
		Return;
	EndIf;
	
	StructureData.Insert("UpdateExchangeRate", True);
	StructureData.Insert("UpdatePaymentExchangeRate", True);
	StructureData.Insert("UpdateSettlementsExchangeRate", False);
	StructureData.Insert("UpdateBankFeeExchangeRate", True);
	
	RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData);
	
	SetVisibilityAmountAttributes();
	SetVisibilityBankChargeAmountAttributes();
	
EndProcedure

&AtServer
Procedure SetVisibilityPOSTermialWithholdFeeOnPayoutDependant()
	
	Items.DocumentAmount.ReadOnly = WithholdFeeOnPayout;
	Items.FeeTotal.Visible = WithholdFeeOnPayout;
	Items.FeeTotalCurrency.Visible = WithholdFeeOnPayout;
	Items.RefundTotal.Visible = WithholdFeeOnPayout;
	Items.RefundTotalCurrency.Visible = WithholdFeeOnPayout;
	Items.PaymentProcessorPayoutDetails.Visible = WithholdFeeOnPayout;
	
EndProcedure

&AtServer
Procedure FillPaymentDetailsByContractData(StructureData)
	
	If Object.PaymentDetails.Count() = 0
		Or StructureData.DoOperationsByContracts
		And Object.PaymentDetails.Count() > 1 Then
		Return;
	EndIf;
	
	For Each PaymentDetailsRow In Object.PaymentDetails Do
		
		PaymentDetailsRow.Contract = StructureData.Contract;
		PaymentDetailsRow.Item = StructureData.Item;
		
		PaymentDetailsRow.SettlementsCurrency = StructureData.SettlementsCurrency;
		PaymentDetailsRow.ExchangeRate = StructureData.ExchangeRate;
		PaymentDetailsRow.Multiplicity = StructureData.Multiplier;
		
		CalculateSettlementsAmount(PaymentDetailsRow, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Function GetRefAttributes(Ref, StringAttributes)
	
	Return DriveServer.GetRefAttributes(Ref, StringAttributes);
	
EndFunction

#Region FormManagement

&AtClient
Procedure SetVisibleCommandFillByBasis()
	
	Result = False;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.FromCustomer") Then
		Result = True;
	EndIf;
	
	Items.FillByBasis.Visible = Result;
	
EndProcedure

#EndRegion

&AtServer
Procedure SetChoiceParametersForCounterparty(Filter)
	
	NewArray 		= New Array();
	NewConnection	= New ChoiceParameter("Filter." + Filter, True);
	NewArray.Add(NewConnection);
	NewConnections	= New FixedArray(NewArray);
	Items.Counterparty.ChoiceParameters	= NewConnections;
	
EndProcedure

&AtServer
Procedure SetIncomeAndExpenseItemsVisibility()
	
	IsOtherOperation = (OperationKind = Enums.OperationTypesPaymentReceipt.Other);
	
	IncomeAndExpenseItemsVisibility = 
		IsOtherOperation
		And (Not UseDefaultTypeOfAccounting Or GLAccountsInDocuments.IsIncomeAndExpenseGLA(Object.Correspondence));
	
	IncomeAndExpenseItemsInDocuments.SetRegistrationAttributesVisibility(
		ThisObject, 
		"RegisterIncome", 
		IsOtherOperation And Not UseDefaultTypeOfAccounting);
		
EndProcedure

&AtClient
Procedure IncomeAndExpenseItemsOnChangeConditions()
	
	Items.IncomeItem.TitleLocation = ?(
		UseDefaultTypeOfAccounting, FormItemTitleLocation.Auto, FormItemTitleLocation.None);
		
	Items.IncomeItem.Visible = IncomeAndExpenseItemsVisibility;
	Items.IncomeItem.Enabled = Object.RegisterIncome;
	
EndProcedure

&AtServer
Procedure SetVisibilityExpenseItem()
	
	Items.ExpenseItem.Visible = (Object.OperationKind = Enums.OperationTypesPaymentReceipt.PayoutFromPaymentProcessor)
			And ValueIsFilled(Object.POSTerminal) And WithholdFeeOnPayout;
	
EndProcedure

&AtServer
Procedure SetVisibilityAmountAttributes()
	
	IsReadonly = (Object.CashCurrency = PresentationCurrency);
	
	Items.OtherSettlementsExchangeRate.ReadOnly = IsReadonly;
	Items.OtherSettlementsMultiplicity.ReadOnly = IsReadonly;
	Items.OtherSettlementsAccountingAmount.ReadOnly = IsReadonly;
	Items.CurrencyPurchaseRate.ReadOnly = IsReadonly;
	Items.CurrencyPurchaseRepetition.ReadOnly = IsReadonly;
	Items.CurrencyPurchaseAccountingAmount.ReadOnly = IsReadonly;
	Items.TaxesSettlementsExchangeRate.ReadOnly = IsReadonly;
	Items.TaxesSettlementsMultiplicity.ReadOnly = IsReadonly;
	Items.TaxesSettlementsAccountingAmount.ReadOnly = IsReadonly;
	
EndProcedure

&AtServer
Procedure SetVisibilityBankChargeAmountAttributes()
	
	IsReadonly = (Object.CashCurrency = PresentationCurrency);
	
	Items.BankChargeExchangeRate.ReadOnly = IsReadonly;
	Items.BankChargeMultiplicity.ReadOnly = IsReadonly;
	
EndProcedure

&AtClientAtServerNoContext
Procedure CalculateSettlementsAmount(TabularSectionRow, ExchangeRateMethod, PresentationCurrency, CashCurrency)
	
	RefreshRatesAndAmount(TabularSectionRow, PresentationCurrency, CashCurrency);
	
	TabularSectionRow.PaymentExchangeRate = ?(TabularSectionRow.PaymentExchangeRate = 0, 1, TabularSectionRow.PaymentExchangeRate);
	TabularSectionRow.ExchangeRate = ?(TabularSectionRow.ExchangeRate = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.PaymentMultiplier = ?(TabularSectionRow.PaymentMultiplier = 0, 1, TabularSectionRow.PaymentMultiplier);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.PaymentAmount,
		ExchangeRateMethod,
		TabularSectionRow.PaymentExchangeRate,
		TabularSectionRow.ExchangeRate,
		TabularSectionRow.PaymentMultiplier,
		TabularSectionRow.Multiplicity);
	
	TabularSectionRow.SettlementsEPDAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.EPDAmount,
		ExchangeRateMethod,
		TabularSectionRow.PaymentExchangeRate,
		TabularSectionRow.ExchangeRate,
		TabularSectionRow.PaymentMultiplier,
		TabularSectionRow.Multiplicity);
	
EndProcedure

&AtClientAtServerNoContext
Function GetAccountingAmount(DocumentAmount, ExchangeRateMethod, PaymentExchangeRate, PaymentMultiplier)
	
	If PaymentExchangeRate = 0 Or PaymentMultiplier = 0 Then
		Return 0;
	EndIf;
	
	Return DriveServer.RecalculateFromCurrencyToCurrency(
		DocumentAmount,
		ExchangeRateMethod,
		PaymentExchangeRate,
		1,
		PaymentMultiplier,
		1);
	
EndFunction

&AtClient
Procedure CalculateSettlementsRate(TabularSectionRow)
	
	If ExchangeRateMethod = PredefinedValue("Enum.ExchangeRateMethods.Divisor") Then
		If TabularSectionRow.PaymentAmount <> 0 Then
			TabularSectionRow.ExchangeRate = TabularSectionRow.SettlementsAmount
				* TabularSectionRow.PaymentExchangeRate
				/ TabularSectionRow.PaymentMultiplier
				/ TabularSectionRow.PaymentAmount
				* TabularSectionRow.Multiplicity;
		EndIf;
	Else
		If TabularSectionRow.SettlementsAmount <> 0 Then
			TabularSectionRow.ExchangeRate = TabularSectionRow.PaymentAmount
				* TabularSectionRow.PaymentExchangeRate
				/ TabularSectionRow.PaymentMultiplier
				/ TabularSectionRow.SettlementsAmount
				* TabularSectionRow.Multiplicity;
		EndIf;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshRatesAndAmount(TableRow, PresentationCurrency, CashCurrency)
	
	If PresentationCurrency = TableRow.SettlementsCurrency Then
		TableRow.ExchangeRate = 1;
		TableRow.Multiplicity = 1;
	EndIf;
	
	If PresentationCurrency = CashCurrency Then
		TableRow.PaymentExchangeRate = 1;
		TableRow.PaymentMultiplier = 1;
	EndIf;
	
	If CashCurrency = TableRow.SettlementsCurrency Then
		TableRow.ExchangeRate = TableRow.PaymentExchangeRate;
		TableRow.Multiplicity = TableRow.PaymentMultiplier;
		TableRow.SettlementsAmount = TableRow.PaymentAmount;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillCurrencyChoiceList(Form, ChoiceListItemName, Currency)
	
	FillParameters = New Structure;
	FillParameters.Insert("Currency", 				Currency);
	FillParameters.Insert("PresentationCurrency", 	Form.PresentationCurrency);
	FillParameters.Insert("DocumentDate", 			Form.DocumentDate);
	FillParameters.Insert("Company", 				Form.Object.Company);
	
	DriveClientServer.FillInCurrencyRateChoiceList(Form, ChoiceListItemName, FillParameters);
	
EndProcedure

&AtClient
Procedure ExchangeRateChoiceProcessing(TableName, AttributeName, SelectedValue, StandardProcessing, Currency)
	
	StandardProcessing = False;
	
	ChoiceContext = New Structure;
	ChoiceContext.Insert("AttributeName", AttributeName);
	ChoiceContext.Insert("TableName", TableName);
	
	NotifyDescription = New NotifyDescription("SelectExchangeRateDateEnd", ThisForm, ChoiceContext);
	
	If SelectedValue = 0 Then
		
		ExchangeRateFormParameters = DriveClient.GetSelectExchangeRateDateParameters();
		ExchangeRateFormParameters.Company 					= Object.Company;
		ExchangeRateFormParameters.Currency 				= Currency;
		ExchangeRateFormParameters.ExchangeRateMethod 		= ExchangeRateMethod;
		ExchangeRateFormParameters.PresentationCurrency 	= PresentationCurrency;
		ExchangeRateFormParameters.RateDate 				= DocumentDate;
		
		DriveClient.OpenSelectExchangeRateDateForm(ExchangeRateFormParameters, ThisForm, NotifyDescription);
		
	Else
		
		Modified = True;
		ExecuteNotifyProcessing(NotifyDescription, SelectedValue);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectExchangeRateDateEnd(Result, ChoiceContext) Export
	
	If Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	Modified = True;
	
	If ValueIsFilled(ChoiceContext.TableName) Then
	
		CurrentData = Items[ChoiceContext.TableName].CurrentData;
		CurrentData[ChoiceContext.AttributeName] = Result;
		CalculateSettlementsAmount(CurrentData, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
		
	ElsIf ChoiceContext.AttributeName = "ExchangeRate" Then
		
		Object[ChoiceContext.AttributeName] = Result;
		Object.AccountingAmount = GetAccountingAmount(Object.DocumentAmount, 
			ExchangeRateMethod,
			Object.ExchangeRate,
			Object.Multiplicity);
			
	Else
		
		Object[ChoiceContext.AttributeName] = Result;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AccountingAmountOnChange()
	
	Object.ExchangeRate = ?(
		Object.ExchangeRate = 0,
		1,
		Object.ExchangeRate);
	
	Object.Multiplicity = ?(
		Object.Multiplicity = 0,
		1,
		Object.Multiplicity);
		
	If Object.AccountingAmount = 0 Then
		Return;
	EndIf;
		
	If ExchangeRateMethod = PredefinedValue("Enum.ExchangeRateMethods.Multiplier") Then
		
		Object.ExchangeRate = ?(
			Object.DocumentAmount = 0,
			1,
			Object.AccountingAmount / Object.DocumentAmount * AccountingCurrencyRate * Object.Multiplicity);
			
	Else
		
		Object.ExchangeRate = ?(
			Object.DocumentAmount = 0,
			1,
			Object.DocumentAmount * AccountingCurrencyRate / Object.AccountingAmount / Object.Multiplicity);
			
	EndIf;
	
EndProcedure

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion