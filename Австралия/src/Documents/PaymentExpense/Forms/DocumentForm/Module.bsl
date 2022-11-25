
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.CheckBasis(Object, Parameters.Basis, Cancel);
	UseForeignCurrency = GetFunctionalOption("ForeignExchangeAccounting");
	
	SetConditionalAppearance();
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues);
		
	DefaultIncomeItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("DiscountReceived");
	
	If Object.PaymentDetails.Count() = 0 Then
		
		NewRow = Object.PaymentDetails.Add();
		NewRow.PaymentAmount = Object.DocumentAmount;
		
		If Object.OperationKind = Enums.OperationTypesPaymentExpense.Vendor Then
			NewRow.DiscountReceivedIncomeItem = DefaultIncomeItem;
		EndIf;
		
		NewRow.Multiplicity = 1;
		NewRow.ExchangeRate = 1;
		NewRow.PaymentMultiplier = 1;
		NewRow.PaymentExchangeRate = 1;
		
	EndIf;
	
	// FO Use Payroll subsystem.
	SetVisibleByFOUseSubsystemPayroll();
	
	DocumentObject = FormAttributeToValue("Object");
	If DocumentObject.IsNew()
		And Not ValueIsFilled(Parameters.CopyingValue) Then
		If ValueIsFilled(Parameters.BasisDocument) Then
			DocumentObject.Fill(Parameters.BasisDocument);
			ValueToFormAttribute(DocumentObject, "Object");
		EndIf;
		If ValueIsFilled(Object.BankAccount)
			And TypeOf(Object.BankAccount.Owner) <> Type("CatalogRef.Companies") Then
			Object.BankAccount = Catalogs.BankAccounts.EmptyRef();
		EndIf; 
		If ValueIsFilled(Object.Company) Then
			ExchangeRateMethod = DriveServer.GetExchangeMethod(Object.Company);
			If ValueIsFilled(Object.BankAccount)
				And Object.BankAccount.Owner <> Object.Company Then
				Object.Company = Object.BankAccount.Owner;
			EndIf;
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
				
				If Not ValueIsFilled(PaymentDetailsRow.SettlementsCurrency) Then
					PaymentDetailsRow.SettlementsCurrency = Object.CashCurrency;
					PaymentDetailsRow.PaymentMultiplier = StructureData.Repetition;
					PaymentDetailsRow.PaymentExchangeRate = StructureData.Rate;
				EndIf;
				
				If Not Object.OperationKind = Enums.OperationTypesPaymentExpense.LoanSettlements Then
					CalculateSettlementsAmount(PaymentDetailsRow, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
				EndIf;
				
			EndDo;
			
		EndIf;
		
		FillInContract(Parameters);
		SetCFItem();
	Else
		
		PresentationCurrency = DriveServer.GetPresentationCurrency(Object.Company);
		ExchangeRateMethod = DriveServer.GetExchangeMethod(Object.Company);
		
	EndIf;
	
	If Object.PaymentDetails.Count() = 0 Then
		IsAdvance = False;
	Else
		IsAdvance = Object.PaymentDetails[0].AdvanceFlag;
	EndIf;
	
	If IsAdvance Then
		AdvanceFlag = Enums.YesNo.Yes;
	Else
		AdvanceFlag = Enums.YesNo.No;
	EndIf;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	SetAccountingPolicyValues();
	
	// Form attributes setting.
	ParentCompany = DriveServer.GetCompany(Object.Company);
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.CashCurrency, Object.Company);
	ExchangeRate = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Rate);
	Multiplicity = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Repetition);
	
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
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");

	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Object.Date, PresentationCurrency, Object.Company);
	
	AccountingCurrencyRate = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Rate);
		
	AccountingCurrencyMultiplicity = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Repetition);
	
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			False);
	ParametersStructure.Insert("FillHeader",			True);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	StructureForFilling = EmployeeGLAccountsStructure(Object);
	GLAccounts = GetEmployeeGLAccountsDescription(StructureForFilling);
	
	SetIncomeAndExpenseItemsVisibility();
	
	Items.PaymentDetailsGLAccounts.Visible = UseDefaultTypeOfAccounting;
	
	SetVisibilityAttributesDependenceOnCorrespondence();
	SetVisibilityItemsDependenceOnOperationKindAndUseBankCharges();
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.Taxes Then
		Items.BusinessLineTaxes.Visible = FunctionalOptionAccountingCashMethodIncomeAndExpenses;
	EndIf;
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.Salary Then
		CommonClientServer.SetFormItemProperty(
			Items,
			"SalaryPayoffsBusinessLine",
			"Visible",
			FunctionalOptionAccountingCashMethodIncomeAndExpenses);
	EndIf;
	
	// Fill in tabular section while entering a document from the working place.
	If TypeOf(Parameters.FillingValues) = Type("Structure")
	   AND Parameters.FillingValues.Property("FillDetailsOfPayment")
	   AND Parameters.FillingValues.FillDetailsOfPayment Then
		
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
	
	ProcessingCompanyVATNumbers();
	
	SetVisibilitySettlementAttributes();
	SetVisibilityEPDAttributes();
	SetVisibilityAmountAttributes();
	SetVisibilityBankChargeAmountAttributes();
	If GetFunctionalOption("UseBankReconciliation") And ValueIsFilled(Object.Ref) And Object.Paid Then
		Items.GroupPaid.ReadOnly = AccumulationRegisters.BankReconciliation.TransactionCleared(
			Object.Ref, Object.BankAccount);
	EndIf;
		
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
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	WorkWithVAT.SetTextAboutAdvancePaymentInvoiceReceived(ThisForm);
	
	SetTaxInvoiceText();
	
	FillCurrencyChoiceList(ThisForm, "TaxesSettlementsExchangeRate", Object.CashCurrency);
	FillCurrencyChoiceList(ThisForm, "OtherSettlementsExchangeRate", Object.CashCurrency);
	FillCurrencyChoiceList(ThisForm, "BankChargeExchangeRate", Object.CashCurrency);
	FillCurrencyChoiceList(ThisForm, "PaymentDetailsPaymentExchangeRate", Object.CashCurrency);
	FillCurrencyChoiceList(ThisForm, "PaymentDetailsOtherSettlementsPaymentExchangeRate", Object.CashCurrency);
	
	EarlyPaymentDiscountsServer.SetTextAboutDebitNote(ThisObject, Object.Ref);
	SetVisibilityDebitNoteText();
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
	SetVisiblePaymentDate();
	SetMarkIncompletePaymentDate();
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
		
	ElsIf EventName = "RefreshDebitNoteText" Then
		
		If TypeOf(Parameter.Ref) = Type("DocumentRef.DebitNote")
			AND Parameter.BasisDocument = Object.Ref Then
			
			DebitNoteText = EarlyPaymentDiscountsClientServer.DebitNotePresentation(Parameter.Date, Parameter.Number);
			
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
	
	DocumentDate = CurrentObject.Date;
	
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
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
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
			Message.Text = ?(Cancel, NStr("en = 'Cannot post the bank payment.'; ru = 'Не удалось провести списание со счета';pl = 'Nie można zatwierdzić płatności przelew wychodzący.';es_ES = 'No se puede enviar el pago bancario.';es_CO = 'No se puede enviar el pago bancario.';tr = 'Banka ödemesi kaydedilemiyor.';it = 'Non è possibile pubblicare il pagamento bancario.';de = 'Die Überweisung kann nicht gebucht werden.'") + " " + MessageText, MessageText);
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
	
	SetVisiblePaymentDate();
		
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If CurrentObject.OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToEmployee
		OR CurrentObject.OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToCounterparty
		OR CurrentObject.OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements Then
			FillInformationAboutCreditLoanAtServer();
	EndIf;
	
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
	
	If ChoiceSource.FormName = "Document.TaxInvoiceReceived.Form.DocumentForm" Then
		
		TaxInvoiceText = SelectedValue;
		
	ElsIf GLAccountsInDocumentsClient.IsGLAccountsChoiceProcessing(ChoiceSource.FormName) Then
		
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
		
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
		
	ElsIf ChoiceSource.FormName = "Catalog.Employees.Form.EmployeeGLAccounts" Then
		
		EmployeeGLAccountsChoiceProcessing(SelectedValue);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

#Region OtherSettlements

&AtClient
Procedure RegisterExpenseOnChange(Item)
	
	If Not Object.RegisterExpense Then
		Object.ExpenseItem = PredefinedValue("Catalog.IncomeAndExpenseItems.EmptyRef");
		SetVisibilityAttributesDependenceOnCorrespondence();
	EndIf;
	
	IncomeAndExpenseItemsOnChangeConditions();
	
EndProcedure

&AtClient
Procedure ExpenseItemOnChange(Item)
	SetVisibilityAttributesDependenceOnCorrespondence();
EndProcedure

&AtClient
Procedure CorrespondenceOnChange(Item)
	
	If Correspondence <> Object.Correspondence Then
		SetVisibilityAttributesDependenceOnCorrespondence();
		Correspondence = Object.Correspondence;
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Other") Then
			
			Structure = New Structure("Object, Correspondence, BankFeeExpenseItem, ExpenseItem, Manual");
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

&AtClient
Procedure EmployeeOnChange(Item)
	
	If OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.IssueLoanToEmployee") 
		OR OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.LoanSettlements") Then

		DataStructure = GetEmployeeDataOnChange(Object.AdvanceHolder, Object.Date, Object.Company);
		
		Object.LoanContract = DataStructure.LoanContract;
		HandleLoanContractChange();
		
	EndIf;
	
	EmployeeOnChangeAtServer();
	
EndProcedure

#EndRegion 

#Region BankCharges

&AtClient
Procedure UseBankChargesOnChange(Item)
	
	StructureBankAccountData = GetDataBankAccountOnChange(
		Object.Date,
		Object.BankAccount,
		Object.CounterpartyAccount,
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
Procedure BankChargeAmountOnChange(Item)
	
	CalculateTotal();
	
EndProcedure

&AtClient
Procedure BankChargeExchangeRateChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	ExchangeRateChoiceProcessing("", "BankChargeExchangeRate", SelectedValue, StandardProcessing, Object.CashCurrency);
	
EndProcedure

#EndRegion

&AtClient
Procedure BasisDocumentOnChange(Item)
	
	SetVisibleCommandFillByBasis();
	
	If ValueIsFilled(Object.BasisDocument)
		And TypeOf(Object.BasisDocument) = Type("DocumentRef.LoanContract")
		And (Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.IssueLoanToCounterparty")
			Or Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.IssueLoanToEmployee")
			Or Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.LoanSettlements")) Then
		Object.LoanContract = Object.BasisDocument;
		HandleLoanContractChange();
	EndIf;
	
EndProcedure

&AtClient
Procedure PaidOnChange(Item)
	
	If Not Object.Paid Then
		Object.PaymentDate = Undefined;
	Else
		Object.PaymentDate = Object.Date;
	EndIf;
	
	SetVisiblePaymentDate();
	SetMarkIncompletePaymentDate();
	
EndProcedure

&AtClient
Procedure TaxInvoiceTextClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	ParametersFilter = New Structure("AdvanceFlag", True);
	AdvanceArray = Object.PaymentDetails.FindRows(ParametersFilter);

	If AdvanceArray.Count() > 0 Then
		WorkWithVATClient.OpenTaxInvoice(ThisForm, True, True);
	Else
		CommonClientServer.MessageToUser(
			NStr("en = 'There are no rows with advance payments in the Payment details tab'; ru = 'В табличной части вкладки ""Расшифровка платежа"" отсутствуют авансовые платежи';pl = 'Na karcie Szczegóły płatności nie ma wierszy z zaliczkami';es_ES = 'No hay filas con los pagos adelantados en la pestaña de los Detalles de pago';es_CO = 'No hay filas con los pagos anticipados en la pestaña de los Detalles de pago';tr = 'Ödeme ayrıntıları sekmesinde avans ödemeye sahip herhangi bir satır yok';it = 'Non ci sono righe con anticipo pagamenti il nella scheda dettagli di pagamento';de = 'Auf der Registerkarte Zahlungsdetails gibt es keine Zeilen mit Vorauszahlungen'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure DebitNoteTextClick(Item, StandardProcessing)
	
	StandardProcessing	= False;
	IsError				= False;
	
	If NOT ValueIsFilled(Object.Ref) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Please, save the document.'; ru = 'Следует записать документ.';pl = 'Proszę, zapisz dokument.';es_ES = 'Por favor, guardar el documento.';es_CO = 'Por favor, guardar el documento.';tr = 'Lütfen, belgeyi kaydedin.';it = 'Per piacere, salvare il documento';de = 'Bitte speichern Sie das Dokument.'"));
		
		IsError = True;
		
	ElsIf CheckBeforeDebitNoteFilling(Object.Ref) Then
		
		IsError = True;
		
	EndIf;
	
	If NOT IsError Then
		
		DebitNoteFound = GetSubordinateDebitNote(Object.Ref);
		
		ParametersStructure = New Structure;
		
		If ValueIsFilled(DebitNoteFound) Then
			ParametersStructure.Insert("Key", DebitNoteFound);
		Else
			ParametersStructure.Insert("Basis", Object.Ref);
		EndIf;
		
		OpenForm("Document.DebitNote.ObjectForm", ParametersStructure, ThisObject);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersPaymentDetails

&AtClient
Procedure PaymentDetailsOnChange(Item)
	
	Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
	CalculateTotal();
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsBeforeDeleteRow(Item, Cancel)
	
	If Object.PaymentDetails.Count() = 1 Then
		Cancel = True;
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
		Message.Text = NStr("en = 'Please select a counterparty.'; ru = 'Сначала выберите контрагента.';pl = 'Wybierz kontrahenta.';es_ES = 'Por favor, seleccione un contraparte.';es_CO = 'Por favor, seleccione un contraparte.';tr = 'Lütfen, cari hesap seçin.';it = 'Si prega di selezionare una controparte.';de = 'Bitte wählen Sie einen Geschäftspartner aus.'");
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
	
	TabularSectionRow = Items.PaymentDetailsOtherSettlements.CurrentData;
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
Procedure PaymentDetailsPaymentMultiplierOnChange(Item)
	
	CurrentData = Items.PaymentDetails.CurrentData;
	CalculateSettlementsAmount(CurrentData, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure PaymentDetailsPaymentExchangeRateOnChange(Item)
	
	CurrentData = Items.PaymentDetails.CurrentData;
	CalculateSettlementsAmount(CurrentData, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure PaymentDetailsSettlementsMultiplierOnChange(Item)
	
	CurrentData = Items.PaymentDetails.CurrentData;
	CalculateSettlementsAmount(CurrentData, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure PaymentDetailsSettlementsExchangeRateOnChange(Item)
	
	CurrentData = Items.PaymentDetails.CurrentData;
	CalculateSettlementsAmount(CurrentData, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsPaymentMultiplierOnChange(Item)
	
	CurrentData = Items.PaymentDetailsOtherSettlements.CurrentData;
	CalculateSettlementsAmount(CurrentData, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsPaymentExchangeRateOnChange(Item)
	
	CurrentData = Items.PaymentDetailsOtherSettlements.CurrentData;
	CalculateSettlementsAmount(CurrentData, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsSettlementMultiplierOnChange(Item)
	
	CurrentData = Items.PaymentDetailsOtherSettlements.CurrentData;
	CalculateSettlementsAmount(CurrentData, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsSettlementExchangeRateOnChange(Item)
	
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
Procedure PaymentDetailsOtherSettlementsSettlementsExchangeRateChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	CurrentData = Items.PaymentDetailsOtherSettlements.CurrentData;
	ExchangeRateChoiceProcessing("PaymentDetailsOtherSettlements", 
		"ExchangeRate", SelectedValue, 
		StandardProcessing, 
		CurrentData.SettlementsCurrency);
	
EndProcedure

&AtClient
Procedure PaymentDetailsPaymentExchangeRateChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	ExchangeRateChoiceProcessing("PaymentDetails", 
		"PaymentExchangeRate", 
		SelectedValue, 
		StandardProcessing,
		Object.CashCurrency);
	
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

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClientAtServerNoContext
Function GetStructureDataForObject(Form, TabName, TabRow)
	
	StructureData = New Structure;
	
	StructureData.Insert("TabName", TabName);
	StructureData.Insert("Object", Form.Object);
	
	StructureData.Insert("Contract", TabRow.Contract);
	StructureData.Insert("Document", TabRow.Document);
	StructureData.Insert("ExistsEPD", TabRow.ExistsEPD);
	StructureData.Insert("EPDAmount", TabRow.EPDAmount);
	
	StructureData.Insert("CounterpartyIncomeAndExpenseItems", True);
	StructureData.Insert("UseDefaultTypeOfAccounting", Form.UseDefaultTypeOfAccounting);
	StructureData.Insert("DiscountReceivedIncomeItem", TabRow.DiscountReceivedIncomeItem);
	
	If Form.UseDefaultTypeOfAccounting Then
		
		StructureData.Insert("GLAccounts", TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled", TabRow.GLAccountsFilled);
		StructureData.Insert("CounterpartyGLAccounts", True);
		
		StructureData.Insert("AccountsPayableGLAccount", TabRow.AccountsPayableGLAccount);
		StructureData.Insert("AdvancesPaidGLAccount", TabRow.AdvancesPaidGLAccount);
		StructureData.Insert("AccountsReceivableGLAccount", TabRow.AccountsReceivableGLAccount);
		StructureData.Insert("AdvancesReceivedGLAccount", TabRow.AdvancesReceivedGLAccount);
		StructureData.Insert("DiscountReceivedGLAccount", TabRow.DiscountReceivedGLAccount);
		StructureData.Insert("VATInputGLAccount", TabRow.VATInputGLAccount);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure FillAddedColumns(ParametersStructure)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	IsOtherSettlements = Object.OperationKind = Enums.OperationTypesPaymentExpense.OtherSettlements;
	
	StructureArray = New Array();
	
	If UseDefaultTypeOfAccounting Then
		
		If IsOtherSettlements Or ParametersStructure.FillHeader Then
			
			Header = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "Header", Object);
			GLAccountsInDocuments.CompleteCounterpartyStructureData(Header, ObjectParameters, "Header");
			StructureArray.Add(Header);
			
		EndIf;
		
	EndIf;
		
	If Not IsOtherSettlements And ParametersStructure.FillPaymentDetails Then
	
		StructureData = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters);
		GLAccountsInDocuments.CompleteCounterpartyStructureData(StructureData, ObjectParameters);
		StructureArray.Add(StructureData);
		
	EndIf;
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, ParametersStructure.GetGLAccounts);
	
	If UseDefaultTypeOfAccounting
		And IsOtherSettlements Then
		Object.Correspondence = ChartsOfAccounts.PrimaryChartOfAccounts.FindByCode(Header.GLAccounts);
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateTotal()
	
	Total = Object.DocumentAmount + Object.BankChargeAmount * Number(Object.UseBankCharges);
	
EndProcedure

&AtServerNoContext
Function GetLoanContractItemByTypeOfAmount(LoanContract, TypeOfAmount)
	Return Common.ObjectAttributeValue(LoanContract, Common.EnumValueName(TypeOfAmount) + "Item");
EndFunction

&AtClient
Procedure CalculatePaymentAmountAtClient(TablePartRow, ColumnName = "")
	
	StructureData = GetDataPaymentDetailsContractOnChange(
			Object.Date,
			TablePartRow.Contract,
			Object.Company);
		
	TablePartRow.ExchangeRate = StructureData.ContractCurrencyRateRepetition.Rate;
	TablePartRow.Multiplicity = ?(
		TablePartRow.Multiplicity = 0,
		1,
		TablePartRow.Multiplicity);
	
	If TablePartRow.SettlementsAmount = 0 Then
		TablePartRow.PaymentAmount = 0;
		TablePartRow.ExchangeRate = StructureData.ContractCurrencyRateRepetition.Rate;
	ElsIf Object.CashCurrency = StructureData.Currency Then
		TablePartRow.PaymentAmount = TablePartRow.SettlementsAmount;
	ElsIf TablePartRow.PaymentAmount = 0 OR
		(ColumnName = "ExchangeRate" OR ColumnName = "Multiplicity") Then
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
			TablePartRow.SettlementsAmount = 0 OR TablePartRow.PaymentAmount = 0,
			StructureData.ContractCurrencyRateRepetition.Rate,
			TablePartRow.PaymentAmount / TablePartRow.SettlementsAmount * ExchangeRate);
		TablePartRow.Multiplicity = ?(
			TablePartRow.SettlementsAmount = 0 OR TablePartRow.PaymentAmount = 0,
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
	
	StructureData.Insert("Item", ContractData[NameCashFlowItem]);
	
	CurrencyRate = CurrencyRateOperations.GetCurrencyRate(Date, ContractData.SettlementsCurrency, Company);
	CurrencyRate.Rate = ?(CurrencyRate.Rate = 0, 1, CurrencyRate.Rate);
	CurrencyRate.Repetition = ?(CurrencyRate.Repetition = 0, 1, CurrencyRate.Repetition);
	
	StructureData.Insert("ContractCurrencyRateRepetition", CurrencyRate);
	StructureData.Insert("Currency", ContractData.SettlementsCurrency);
	
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
Procedure OperationKindOnChangeAtServer(FillTaxation = True)
	
	SetChoiceParameterLinksAvailableTypes();
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.OtherSettlements Then
		
		DefaultVATRate						= Catalogs.VATRates.Exempt;
		DefaultVATRateNumber				= DriveReUse.GetVATRateValue(DefaultVATRate);
		Object.PaymentDetails[0].VATRate	= DefaultVATRate;
		
	ElsIf Object.OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements Then
		
		DefaultVATRate			= Catalogs.VATRates.Exempt;
		DefaultVATRateNumber	= DriveReUse.GetVATRateValue(DefaultVATRate);
		
	ElsIf FillTaxation Then
		FillVATRateByCompanyVATTaxation();
	EndIf;
	
	EmployeeOnChangeAtServer();
	
	SetVisibleOfVATTaxation();
	SetIncomeAndExpenseItemsVisibility();
	SetVisibilityItemsDependenceOnOperationKindAndUseBankCharges();
	SetVisibilityEPDAttributes();
	SetCFItemWhenChangingTheTypeOfOperations();
	SetVisibilityDebitNoteText();
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			True);
	ParametersStructure.Insert("FillHeader",			True);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	If ValueIsFilled(Object.BankAccount) And ValueIsFilled(Object.Company) Then
		StructureData = GetDataBankAccountOnChange(Object.Date, Object.BankAccount, Object.CounterpartyAccount, Object.Company);
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
		TablePartRow.SettlementsCurrency = StructureData.Currency;
		
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
	
	// Payment date is required if the payment was marked as Paid
	Item = ConditionalAppearance.Items.Add();
	
	FilterGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.PaymentDate.Name);
	
	ItemFilter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Paid");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	ItemFilter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.PaymentDate");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
	
	Item.Appearance.SetParameterValue("MarkIncomplete", False);
	
	// PaymentDetailsPlanningDocument
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.OperationKind");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= Enums.OperationTypesPaymentExpense.Vendor;
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
	
	// EPD Amount
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

&AtClient
Procedure SetVisibleCommandFillByBasis()
	
	Result = False;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Vendor") Then
		
		Result = True;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Salary") 
		And TypeOf(Object.BasisDocument) = Type("DocumentRef.ExpenditureRequest") Then
		
		Result = True;
		
	EndIf;
	
	Items.FillByBasis.Visible = Result;
	
EndProcedure

&AtServer
Procedure SetChoiceParametersForAccountingOtherSettlementsAtServerForAccountItem()

	Item = Items.Correspondence;
	
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

	Item = Items.Correspondence;
	
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
	
	ExpenseItemType = Common.ObjectAttributeValue(Object.ExpenseItem, "IncomeAndExpenseType");
	
	If ExpenseItemType = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses Then
		
		Items.Department.Visible	= True;
		
		If Object.OperationKind = Enums.OperationTypesPaymentExpense.OtherSettlements Then
			Object.BusinessLine			= Undefined;
			Object.Order				= Undefined;
			Items.BusinessLine.Visible	= False;
			Items.Order.Visible			= False;
		Else 
			Items.BusinessLine.Visible	= True;
			Items.Order.Visible			= True;
		EndIf;
		
		If Not ValueIsFilled(Object.Department) Then
			User = Users.CurrentUser();
			SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
			Object.Department = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
		EndIf;
		
		Items.Project.Visible = (Object.OperationKind = Enums.OperationTypesPaymentExpense.Other);
		Items.PaymentDetailsOtherSettlementsProject.Visible = 
			(Object.OperationKind = Enums.OperationTypesPaymentExpense.OtherSettlements);
			
	ElsIf ExpenseItemType = Catalogs.IncomeAndExpenseTypes.OtherExpenses Then
		
		Items.Project.Visible = (Object.OperationKind = Enums.OperationTypesPaymentExpense.Other);
		Items.PaymentDetailsOtherSettlementsProject.Visible = 
			(Object.OperationKind = Enums.OperationTypesPaymentExpense.OtherSettlements);
	
	Else
			
		If Object.OperationKind <> Enums.OperationTypesPaymentExpense.Taxes // for entering based on
			Or (Object.OperationKind = Enums.OperationTypesPaymentExpense.Taxes
				And  Not FunctionalOptionAccountingCashMethodIncomeAndExpenses) Then
			
			Object.BusinessLine	= Undefined;
		EndIf;
		
		Object.Department			= Undefined;
		Object.Order				= Undefined;
		Items.BusinessLine.Visible	= False;
		Items.Department.Visible	= False;
		Items.Order.Visible			= False;
		Items.Project.Visible		= False;
		Items.PaymentDetailsOtherSettlementsProject.Visible = False;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetVisibilityItemsDependenceOnOperationKindAndUseBankCharges()
	
	Items.PaymentDetailsPaymentAmount.Visible						= UseForeignCurrency;
	Items.SettlementsOnCreditsPaymentDetailsPaymentAmount.Visible	= UseForeignCurrency;
	
	Items.SettlementsWithCounterparty.Visible	= False;
	Items.SettlementsWithAdvanceHolder.Visible	= False;
	Items.OtherSettlements.Visible				= False;
	Items.Payroll.Visible						= False;
	Items.TaxesSettlements.Visible				= False;
	
	Items.Counterparty.Visible					= False;
	Items.CounterpartyAccount.Visible			= False;
	Items.Counterparty.AutoMarkIncomplete		= Undefined;
	Items.Counterparty.MarkIncomplete			= True;
	Items.AdvanceHolder.Visible					= False;
	
	NewArray		= New Array();
	NewConnection	= New ChoiceParameterLink("Filter.Owner", "Object.Counterparty");
	NewArray.Add(NewConnection);
	NewConnection	= New ChoiceParameterLink("Filter.CashCurrency", "Object.CashCurrency");
	NewArray.Add(NewConnection);
	Items.CounterpartyAccount.ChoiceParameterLinks	= New FixedArray(NewArray);
	Items.Counterparty.ChoiceParameters				= New FixedArray(New Array());
	
	Items.LoanSettlements.Visible			= False;
	Items.EmployeeLoanAgreement.Visible		= False;
	Items.FillByLoanContract.Visible		= False;
	Items.CreditContract.Visible			= False;
	Items.FillByCreditContract.Visible		= False;
	Items.GroupContractInformation.Visible	= False;
	Items.AdvanceHolder.Visible				= False;
	
	Items.Item.Visible				 = True;
	Items.PaymentDetailsItem.Visible = False;
	
	Items.Project.Visible								= False;
	Items.PaymentDetailsOtherSettlementsProject.Visible	= False;
	
	DocMetadata = Metadata.Documents.PaymentExpense;
	
	BasisDocumentTypes = DocMetadata.Attributes.BasisDocument.Type;
	Items.BasisDocument.TypeRestriction = New TypeDescription(BasisDocumentTypes, , "DocumentRef.CashTransferPlan");
	
	PlanningDocumentTypes = DocMetadata.TabularSections.PaymentDetails.Attributes.PlanningDocument.Type;
	PlanningDocumentTypeRestriction = New TypeDescription(PlanningDocumentTypes, , "DocumentRef.CashTransferPlan");
	Items.PaymentDetailsPlanningDocument.TypeRestriction = PlanningDocumentTypeRestriction;
	Items.PaymentDetailsOtherSettlementsPlanningDocument.TypeRestriction = PlanningDocumentTypeRestriction;
	Items.AdvanceHoldersPaymentAccountDetailsForPayment.TypeRestriction = PlanningDocumentTypeRestriction;
	Items.SettlementsOnCreditsPaymentDetailsPlanningDocument.TypeRestriction = PlanningDocumentTypeRestriction;
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.Vendor Then
		
		Items.SettlementsWithCounterparty.Visible					= True;
		Items.PaymentDetailsPickup.Visible							= True;
		Items.PaymentDetailsFillDetails.Visible						= True;
		Items.PaymentDetailsSignAdvance.Visible						= True;
		Items.PaymentDetailsIncomeAndExpenseItems.Visible			= True;
		
		SetChoiceParametersForCounterparty("Supplier");
		
		Items.Counterparty.Visible					= True;
		Items.Counterparty.Title					= NStr("en = 'Supplier'; ru = 'Поставщик';pl = 'Dostawca';es_ES = 'Proveedor';es_CO = 'Proveedor';tr = 'Tedarikçi';it = 'Fornitore';de = 'Lieferant'");
		Items.CounterpartyAccount.Visible			= True;
		
		Items.PaymentAmount.Visible		= True;
		Items.PaymentAmount.Title		= NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'");
		
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
		Items.Item.Visible				 = False;
		Items.PaymentDetailsItem.Visible = True;
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer Then
		
		Items.SettlementsWithCounterparty.Visible					= True;
		Items.PaymentDetailsPickup.Visible							= False;
		Items.PaymentDetailsFillDetails.Visible						= True;
		Items.PaymentDetailsSignAdvance.Visible						= False;
		Items.PaymentDetailsIncomeAndExpenseItems.Visible			= False;
		
		SetChoiceParametersForCounterparty("Customer");
		
		Items.Counterparty.Visible					= True;
		Items.Counterparty.Title					= NStr("en = 'Customer'; ru = 'Покупатель';pl = 'Nabywca';es_ES = 'Cliente';es_CO = 'Cliente';tr = 'Müşteri';it = 'Cliente';de = 'Kunde'");
		Items.CounterpartyAccount.Visible			= True;
		
		Items.PaymentAmount.Visible		= True;
		Items.PaymentAmount.Title		= NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'");
		
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
		Items.Item.Visible				 = False;
		Items.PaymentDetailsItem.Visible = True;
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentExpense.ToAdvanceHolder Then
		
		NewArray		= New Array();
		NewConnection	= New ChoiceParameterLink("Filter.Owner", "Object.AdvanceHolder");
		NewArray.Add(NewConnection);
		NewConnections	= New FixedArray(NewArray);
		Items.CounterpartyAccount.ChoiceParameterLinks	= NewConnections;
		
		Items.CounterpartyAccount.Visible			= True;
		Items.SettlementsWithAdvanceHolder.Visible	= True;
		Items.AdvanceHolder.Visible					= True;
		Items.AdvanceHolder.Title					= NStr("en = 'Advance holder'; ru = 'Подотчетное лицо';pl = 'Zaliczkobiorca';es_ES = 'Titular del anticipo';es_CO = 'Titular de anticipo';tr = 'Avans sahibi';it = 'Persona che ha anticipato';de = 'Abrechnungspflichtige Person'");
		Items.PaymentAmount.Visible					= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title					= ?(GetFunctionalOption("PaymentCalendar"), 
			NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'"), 
			NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'"));
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentExpense.Salary Then
		
		Items.Payroll.Visible					= True;	
		Items.PaymentAmount.Visible						= False;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= True;
		CommonClientServer.SetFormItemProperty(Items, "SalaryPayoffsBusinessLine", "Visible", False);
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentExpense.Taxes Then
		
		SetChoiceParametersForCounterparty("OtherRelationship");
		
		Items.Counterparty.Visible			= True;
		Items.Counterparty.Title			= NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contrapartida';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'");
		Items.CounterpartyAccount.Visible	= True;
		Items.TaxesSettlements.Visible		= True;
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"), 
			NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'"), 
			NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'"));
		
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentExpense.Other Then
		
		Items.OtherSettlements.Visible	= True;
		Items.OtherSettlementsGroupExchangeRateMultiplier.Visible = True;
		Items.OtherSettlementsGroupAmount.Visible = True;
		
		SetChoiceParametersForCounterparty("OtherRelationship");
		
		Items.Counterparty.Visible				= True;
		Items.Counterparty.Title				= NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contrapartida';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'");
		Items.Counterparty.AutoMarkIncomplete	= False;
		Items.Counterparty.MarkIncomplete		= False;
		Items.CounterpartyAccount.Visible		= True;
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"), 
			NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'"), 
			NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'"));
		
		Items.PaymentDetailsOtherSettlements.Visible = False;
		
		SetVisibilityAttributesDependenceOnCorrespondence();
		
		Items.BasisDocument.TypeRestriction = New TypeDescription;
		Items.PaymentDetailsPlanningDocument.TypeRestriction = New TypeDescription;
		Items.PaymentDetailsOtherSettlementsPlanningDocument.TypeRestriction = New TypeDescription;
		Items.AdvanceHoldersPaymentAccountDetailsForPayment.TypeRestriction = New TypeDescription;
		Items.SettlementsOnCreditsPaymentDetailsPlanningDocument.TypeRestriction = New TypeDescription;
		
		Items.Correspondence.Title = NStr("en = 'Expense account'; ru = 'Счет расходов';pl = 'Konto rozchodów';es_ES = 'Cuenta de gastos';es_CO = 'Cuenta de gastos';tr = 'Gider hesabı';it = 'Conto uscita';de = 'Ausgabenkonto'");
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentExpense.OtherSettlements Then
		
		Items.OtherSettlements.Visible	= True;
		Items.OtherSettlementsGroupExchangeRateMultiplier.Visible = False;
		Items.OtherSettlementsGroupAmount.Visible = False;
		
		Items.PaymentAmount.Visible			= UseForeignCurrency;
		Items.PaymentAmount.Title 			= NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'");
		
		SetChoiceParametersForCounterparty("OtherRelationship");
		
		Items.Counterparty.Visible	= True;
		Items.Counterparty.Title	= NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contrapartida';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'");
		Items.CounterpartyAccount.Visible = True;
		
		Items.PaymentDetailsOtherSettlements.Visible 			= True;
		Items.PaymentDetailsOtherSettlementsContract.Visible	= Object.Counterparty.DoOperationsByContracts;
		Items.PaymentDetailsIncomeAndExpenseItems.Visible 		= False;
		
		SetVisibilityAttributesDependenceOnCorrespondence();
		
		Items.Correspondence.Title = NStr("en = 'Debit account'; ru = 'Дебетовый счет';pl = 'Konto debetowe';es_ES = 'Cuenta de débito';es_CO = 'Cuenta de débito';tr = 'Borç hesabı';it = 'Conto debito';de = 'Soll-Konto'");
		
		If Object.PaymentDetails.Count() > 0 Then
			ID = Object.PaymentDetails[0].GetID();
			Items.PaymentDetailsOtherSettlements.CurrentRow = ID;
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToEmployee Then
		
		NewArray		= New Array();
		NewConnection	= New ChoiceParameterLink("Filter.Owner", "Object.AdvanceHolder");
		NewArray.Add(NewConnection);
		NewConnections	= New FixedArray(NewArray);
		Items.CounterpartyAccount.ChoiceParameterLinks	= NewConnections;
		
		Items.CounterpartyAccount.Visible					= True;
		Items.AdvanceHolder.Visible							= True;
		Items.AdvanceHolder.Title							= NStr("en = 'Employee'; ru = 'Сотрудник';pl = 'Pracownik';es_ES = 'Empleado';es_CO = 'Empleado';tr = 'Çalışan';it = 'Dipendente';de = 'Mitarbeiter'");
		Items.LoanSettlements.Visible						= True;
		Items.SettlementsOnCreditsPaymentDetails.Visible	= False;
		Items.EmployeeLoanAgreement.Visible					= True;
		Items.FillByLoanContract.Visible					= True;
		
		FillInformationAboutCreditLoanAtServer();
		
		Items.GroupContractInformation.Visible			= True;		
		Items.PaymentAmount.Visible						= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title						= NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'");
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
		Items.Correspondence.Title = NStr("en = 'Expense account'; ru = 'Счет расходов';pl = 'Konto rozchodów';es_ES = 'Cuenta de gastos';es_CO = 'Cuenta de gastos';tr = 'Gider hesabı';it = 'Conto uscita';de = 'Ausgabenkonto'");
		
	ElsIf OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToCounterparty Then
		
		NewArray		= New Array();
		NewConnection	= New ChoiceParameterLink("Filter.Owner", "Object.Counterparty");
		NewArray.Add(NewConnection);
		NewConnections	= New FixedArray(NewArray);
		Items.CounterpartyAccount.ChoiceParameterLinks	= NewConnections;
		
		SetChoiceParametersForCounterparty("OtherRelationship");
		
		Items.CounterpartyAccount.Visible					= True;
		Items.Counterparty.Visible							= True;
		Items.Counterparty.Title							= NStr("en = 'Borrower'; ru = 'Заемщик';pl = 'Pożyczkobiorca';es_ES = 'Prestatario';es_CO = 'Prestatario';tr = 'Borçlanan';it = 'Mutuatario';de = 'Darlehensnehmer'");
		Items.LoanSettlements.Visible						= True;
		Items.SettlementsOnCreditsPaymentDetails.Visible	= False;
		Items.EmployeeLoanAgreement.Visible					= True;
		Items.FillByLoanContract.Visible					= True;
		
		FillInformationAboutCreditLoanAtServer();
		
		Items.GroupContractInformation.Visible			= True;		
		Items.PaymentAmount.Visible						= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title						= NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'");
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
		Items.Correspondence.Title = NStr("en = 'Expense account'; ru = 'Счет расходов';pl = 'Konto rozchodów';es_ES = 'Cuenta de gastos';es_CO = 'Cuenta de gastos';tr = 'Gider hesabı';it = 'Conto uscita';de = 'Ausgabenkonto'");
		
	ElsIf OperationKind = Enums.OperationTypesPaymentExpense.LoanSettlements Then
		
		SetChoiceParametersForCounterparty("OtherRelationship");
		
		Items.LoanSettlements.Visible					= True;
		Items.Counterparty.Visible							= True;
		Items.Counterparty.Title							= NStr("en = 'Lender'; ru = 'Заимодатель';pl = 'Pożyczkodawca';es_ES = 'Prestamista';es_CO = 'Prestador';tr = 'Borç veren';it = 'Finanziatore';de = 'Darlehensgeber'");
		Items.CounterpartyAccount.Visible					= True;
		Items.SettlementsOnCreditsPaymentDetails.Visible	= True;
		Items.CreditContract.Visible						= True;
		Items.FillByCreditContract.Visible					= True;
		Items.Item.Visible									= False;
		FillInformationAboutCreditLoanAtServer();
		
		Items.GroupContractInformation.Visible			= True;	
		Items.PaymentAmount.Visible						= UseForeignCurrency;
		Items.PaymentAmount.Title						= NStr("en = 'Payment'; ru = 'Платеж';pl = 'Płatność';es_ES = 'Pago';es_CO = 'Pago';tr = 'Ödeme';it = 'Pagamento';de = 'Bezahlung'");
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
		Items.Correspondence.Title = NStr("en = 'Expense account'; ru = 'Счет расходов';pl = 'Konto rozchodów';es_ES = 'Cuenta de gastos';es_CO = 'Cuenta de gastos';tr = 'Gider hesabı';it = 'Conto uscita';de = 'Ausgabenkonto'");
		
	Else
		
		Items.OtherSettlements.Visible					= True;
		Items.PaymentAmount.Visible						= True;
		Items.PaymentAmount.Title						= NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'");
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		CommonClientServer.SetFormItemProperty(
			Items,
			"SalaryPayoffsBusinessLine",
			"Visible",
			FunctionalOptionAccountingCashMethodIncomeAndExpenses);
		
	EndIf;
	
	If Not Object.UseBankCharges Then
		Items.PaymentAmount.Visible = False; 
		Items.PayrollPaymentTotalPaymentAmount.Visible = False;
	EndIf;
	
	Items.PaymentAmountCurrency.Visible = Items.PaymentAmount.Visible
		Or Items.PayrollPaymentTotalPaymentAmount.Visible;
		
	Items.GroupBankCharges.Visible	= Object.UseBankCharges;
	Items.BankFee.Visible			= Object.UseBankCharges;
	Items.BankFeeCurrency.Visible	= Object.UseBankCharges;
		
	SetVisibilityPlanningDocument();
	
EndProcedure

&AtServer
Procedure SetVisibilityPlanningDocument()
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer
		OR Object.OperationKind = Enums.OperationTypesPaymentExpense.Vendor
		OR Object.OperationKind = Enums.OperationTypesPaymentExpense.Salary
		OR Not GetFunctionalOption("PaymentCalendar") Then
			Items.PlanningDocuments.Visible = False;
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentExpense.OtherSettlements 
		OR Object.OperationKind = Enums.OperationTypesPaymentExpense.LoanSettlements 
		OR Object.OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToEmployee
		OR Object.OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToCounterparty Then
			Items.PlanningDocuments.Visible = False;
	Else
		Items.PlanningDocuments.Visible = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetVisibilityEPDAttributes()
	
	OperationKindVendor = (Object.OperationKind = Enums.OperationTypesPaymentExpense.Vendor);
	
	VisibleFlag = (ValueIsFilled(Object.Counterparty) AND OperationKindVendor);
	
	Items.PaymentDetailsEPDAmount.Visible				= VisibleFlag;
	Items.PaymentDetailsSettlementsEPDAmount.Visible	= VisibleFlag;
	Items.PaymentDetailsExistsEPD.Visible				= VisibleFlag;
	Items.PaymentDetailsCalculateEPD.Visible			= VisibleFlag;
	
EndProcedure

&AtServer
Procedure SetVisibilitySettlementAttributes()
	
	CounterpartyDoOperationsByContracts = Object.Counterparty.DoOperationsByContracts;
	
	Items.PaymentDetailsContract.Visible			= CounterpartyDoOperationsByContracts;
	Items.PaymentDetailsOrder.Visible				= Object.Counterparty.DoOperationsByOrders;
	
	Items.PaymentDetailsOtherSettlementsContract.Visible = CounterpartyDoOperationsByContracts;
	
EndProcedure

&AtServer
Function SetVisibilityDebitNoteText()
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.Vendor Then
		
		DocumentsTable			= Object.PaymentDetails.Unload(, "Document");
		PaymentDetailsDocuments	= DocumentsTable.UnloadColumn("Document");
		
		Items.DebitNoteText.Visible = EarlyPaymentDiscountsServer.AvailableDebitNoteEPD(PaymentDetailsDocuments);
		
	Else
		
		Items.DebitNoteText.Visible = False;
		
	EndIf;
	
EndFunction

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

&AtClient
Procedure SetVisiblePaymentDate()

	Items.PaymentDate.ReadOnly = Not Object.Paid;

EndProcedure

&AtServer
Function GetDataBankChargeOnChange(BankCharge, CashCurrency)

	StructureData	= New Structure;
	
	StructureData.Insert("BankChargeItem", BankCharge.Item);
	StructureData.Insert("ExpenseItem", BankCharge.ExpenseItem);
	
	BankChargeAmount = ?(BankCharge.ChargeType = Enums.ChargeMethod.Percent, Object.DocumentAmount * BankCharge.Value / 100, BankCharge.Value);
	
	StructureData.Insert("BankChargeAmount", BankChargeAmount);
	
	Return StructureData;

EndFunction

#EndRegion 

#EndRegion

#Region ExternalFormViewManagement

&AtServer
Procedure SetChoiceParameterLinksAvailableTypes()
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.OtherSettlements Then
		SetChoiceParametersForAccountingOtherSettlementsAtServerForAccountItem();
	Else
		SetChoiceParametersOnMetadataForAccountItem();
	EndIf;
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.Vendor Then
		
		Array = New Array();
		Array.Add(Type("DocumentRef.AdditionalExpenses"));
		Array.Add(Type("DocumentRef.SupplierInvoice"));
		Array.Add(Type("DocumentRef.SalesInvoice"));
		Array.Add(Type("DocumentRef.AccountSalesToConsignor"));
		Array.Add(Type("DocumentRef.ArApAdjustments"));
		Array.Add(Type("DocumentRef.SubcontractorInvoiceReceived"));
		Array.Add(Type("DocumentRef.CustomsDeclaration"));
		
		ValidTypes = New TypeDescription(Array, ,);
		Items.PaymentDetailsDocument.TypeRestriction = ValidTypes;
		
		OrdersArray = New Array();
		OrdersArray.Add(Type("DocumentRef.PurchaseOrder"));
		OrdersArray.Add(Type("DocumentRef.SubcontractorOrderIssued"));
		
		ValidTypes = New TypeDescription(OrdersArray);
		Items.PaymentDetailsOrder.TypeRestriction = ValidTypes;
		
		Items.PaymentDetailsDocument.ToolTip = NStr("en = 'The source document for the payment.'; ru = 'Исходный документ для оплаты.';pl = 'Dokument źródłowy dla płatności.';es_ES = 'Documento fuente para el pago.';es_CO = 'Documento fuente para el pago.';tr = 'Ödeme için kaynak dosya.';it = 'Il documento fonte per il pagamento.';de = 'Das Quelldokument für die Zahlung.'");
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer Then
		
		Array = New Array();
		Array.Add(Type("DocumentRef.CashReceipt"));
		Array.Add(Type("DocumentRef.PaymentReceipt"));
		Array.Add(Type("DocumentRef.ArApAdjustments"));
		Array.Add(Type("DocumentRef.SalesOrder"));
		Array.Add(Type("DocumentRef.AccountSalesFromConsignee"));
		Array.Add(Type("DocumentRef.FixedAssetSale"));
		Array.Add(Type("DocumentRef.SupplierInvoice"));
		Array.Add(Type("DocumentRef.SalesInvoice"));
		Array.Add(Type("DocumentRef.CreditNote"));
		
		ValidTypes = New TypeDescription(Array, ,);
		Items.PaymentDetailsDocument.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.SalesOrder", , );
		Items.PaymentDetailsOrder.TypeRestriction = ValidTypes;
		
		Items.PaymentDetailsDocument.ToolTip = NStr("en = 'An advance payment document that should be returned.'; ru = 'Документ расчетов с контрагентом, по которому осуществляется возврат денежных средств';pl = 'Dokument płatności zaliczkowej do zwrotu.';es_ES = 'Un documento del pago anticipado que tiene que devolverse.';es_CO = 'Un documento del pago anticipado que tiene que devolverse.';tr = 'Geri dönmesi gereken bir avans ödeme belgesi.';it = 'Pagamento di un anticipo, documento che deve essere restituito.';de = 'Ein Vorauszahlungsbeleg, der zurückgegeben werden soll.'");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// Procedure of the field change data processor Operation kind on server.
//
&AtServer
Procedure SetCFItemWhenChangingTheTypeOfOperations()
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer
		AND (Object.Item = Catalogs.CashFlowItems.PaymentToVendor
		OR Object.Item = Catalogs.CashFlowItems.Other
		OR Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers) Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentExpense.Vendor
		AND (Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers
		OR Object.Item = Catalogs.CashFlowItems.Other
		OR Object.Item = Catalogs.CashFlowItems.PaymentToVendor) Then
		Object.Item = Catalogs.CashFlowItems.PaymentToVendor;
	ElsIf (Object.OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToEmployee
		Or Object.OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToCounterparty)
		And ValueIsFilled(Object.LoanContract) Then
		Object.Item = Common.ObjectAttributeValue(Object.LoanContract, "PrincipalItem");
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentExpense.Salary Then
		Object.Item = Catalogs.CashFlowItems.Payroll;
	ElsIf (Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers
		OR Object.Item = Catalogs.CashFlowItems.PaymentToVendor) Then
		Object.Item = Catalogs.CashFlowItems.Other;
	EndIf;
	
EndProcedure

// Procedure of the field change data processor Operation kind on server.
//
&AtServer
Procedure SetCFItem()
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentExpense.Vendor Then
		Object.Item = Catalogs.CashFlowItems.PaymentToVendor;
	ElsIf (Object.OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToEmployee
		Or Object.OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToCounterparty)
		And ValueIsFilled(Object.LoanContract) Then
		Object.Item = Common.ObjectAttributeValue(Object.LoanContract, "PrincipalItem");
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentExpense.Salary Then
		Object.Item = Catalogs.CashFlowItems.Payroll;
	Else
		Object.Item = Catalogs.CashFlowItems.Other;
	EndIf;
	
EndProcedure

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	SetVisibleOfVATTaxation();
	SetVisibilitySettlementAttributes();
	SetVisibilityEPDAttributes();
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			False);
	ParametersStructure.Insert("FillHeader",			True);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.CashCurrency, Object.Company);
	ExchangeRate = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Rate);
		
	Multiplicity = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Repetition);
	
EndProcedure

// Function puts the SettlementsDetails tabular section to
// the temporary storage and returns an address
//
&AtServer
Function PlacePaymentDetailsToStorage()
	
	Return PutToTempStorage(
		Object.PaymentDetails.Unload(,
			"Contract,
			|Item,
			|AdvanceFlag,
			|Document,
			|Order,
			|SettlementsAmount,
			|ExchangeRate,
			|Multiplicity"
		),
		UUID);
	
EndFunction

// Function receives the SettlementsDetails tabular section from the temporary storage.
//
&AtServer
Procedure GetPaymentDetailsFromStorage(AddressPaymentDetailsInStorage)
	
	TableExplanationOfPayment = GetFromTempStorage(AddressPaymentDetailsInStorage);
	
	IsVendor = Object.OperationKind = Enums.OperationTypesPaymentExpense.Vendor;
	
	Object.PaymentDetails.Clear();
	
	For Each RowPaymentDetails In TableExplanationOfPayment Do
		
		String = Object.PaymentDetails.Add();
		FillPropertyValues(String, RowPaymentDetails);
		
		If Not ValueIsFilled(String.VATRate) Then
			VATRateData = DriveServer.DocumentVATRateData(String.Document, DefaultVATRate, False);
			String.VATRate = VATRateData.VATRate;
		EndIf;
		
		If IsVendor Then
			String.DiscountReceivedIncomeItem = DefaultIncomeItem;
		EndIf;
		
		String.PaymentExchangeRate = Object.ExchangeRate;
		String.PaymentMultiplier = Object.Multiplicity;
		
		If Not Object.OperationKind = Enums.OperationTypesPaymentExpense.LoanSettlements Then
			CalculatePaymentSUM(String, ExchangeRateMethod, Multiplicity, ExchangeRate, DefaultVATRate);
		EndIf;
		
	EndDo;
	
	If Not Object.OperationKind = Enums.OperationTypesPaymentExpense.LoanSettlements Then
		For Each Row In Object.PaymentDetails Do
			ProcessCounterpartyContractChangeAtServer(Row.GetID());
		EndDo;
	EndIf;
	
EndProcedure

// Recalculates amounts by the cash assets currency.
//
&AtClient
Procedure RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData, MessageText = "")
	
	If Not ValueIsFilled(Object.CashCurrency) Then
		Return;
	EndIf;
	
	ExchangeRateBeforeChange = ExchangeRate;
	MultiplicityBeforeChange = Multiplicity;
	
	StructureData.Insert("ExchangeRateBeforeChange", ExchangeRateBeforeChange);
	StructureData.Insert("MultiplicityBeforeChange", MultiplicityBeforeChange);
	
	If Not IsBlankString(MessageText) Then
		NotifyDescription = New NotifyDescription("DefineNeedToRecalculateAmountsOnRateChange", ThisObject, StructureData);
		ShowQueryBox(NotifyDescription, MessageText, QuestionDialogMode.YesNo, 0);
	ElsIf StructureData.ExchangeRate <> ExchangeRateBeforeChange
		Or StructureData.Multiplier <> MultiplicityBeforeChange
		Or StructureData.Property("UpdateExchangeRate") And StructureData.UpdateExchangeRate Then
		DefineNeedToRecalculateAmountsOnRateChangeProcessing(StructureData);
	EndIf;
	
EndProcedure

// Procedure-handler of a response to the question on document recalculation after currency rate change
//
&AtClient
Procedure DefineNeedToRecalculateAmountsOnRateChange(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		DefineNeedToRecalculateAmountsOnRateChangeProcessing(AdditionalParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DefineNeedToRecalculateAmountsOnRateChangeProcessing(AdditionalParameters)
	
	AdditionalParameters.Insert("UpdatePaymentExchangeRate", True);
	AdditionalParameters.Insert("UpdateSettlementsExchangeRate", False);
	AdditionalParameters.Insert("UpdateBankFeeExchangeRate", True);
	UpdatePaymentDetailsExchangeRatesAtServer(AdditionalParameters);
	
EndProcedure

&AtServerNoContext
Function GetDataPaymentDetailsOnChange(Date, CounterpartyOrContract, Company)
	
	StructureData = New Structure;
	
	SettlementsCurrency = Common.ObjectAttributeValue(CounterpartyOrContract, "SettlementsCurrency");
	
	StructureData.Insert(
		"ContractCurrencyExchangeRate",
		CurrencyRateOperations.GetCurrencyRate(Date, SettlementsCurrency, Company));
		
	StructureData.Insert("Currency", SettlementsCurrency);
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure UpdatePaymentDetailsExchangeRatesAtServer(AdditionalParameters)
	
	Var UpdatePaymentExchangeRate, UpdateSettlementsExchangeRate, UpdateBankFeeExchangeRate;
	
	AdditionalParameters.Property("UpdatePaymentExchangeRate", UpdatePaymentExchangeRate);
	AdditionalParameters.Property("UpdateSettlementsExchangeRate", UpdateSettlementsExchangeRate);
	AdditionalParameters.Property("UpdateBankFeeExchangeRate", UpdateBankFeeExchangeRate);
	
	Object.ExchangeRate = AdditionalParameters.ExchangeRate;
	Object.Multiplicity = AdditionalParameters.Multiplier;
	Object.BankChargeExchangeRate = AdditionalParameters.ExchangeRate;
	Object.BankChargeMultiplier = AdditionalParameters.Multiplier;
	
	Object.AccountingAmount = GetAccountingAmount(Object.DocumentAmount, 
		ExchangeRateMethod,
		Object.ExchangeRate,
		Object.Multiplicity);
	
	If UpdatePaymentExchangeRate Or UpdateBankFeeExchangeRate Then
		
		StructureBankAccountData = GetDataBankAccountOnChange(
			Object.Date,
			Object.BankAccount,
			Object.CounterpartyAccount,
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

// Recalculate a payment amount in the passed tabular section string.
//
&AtClientAtServerNoContext
Procedure CalculatePaymentSUM(TabularSectionRow, ExchangeRateMethod, Multiplicity, ExchangeRate,  DefaultVATRate)
	
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

// Recalculates amounts by the document tabular section
// currency after changing the bank account or petty cash.
//
&AtClientAtServerNoContext
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount - (TabularSectionRow.PaymentAmount) / ((VATRate + 100) / 100);
	
EndProcedure

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Counterparty, Company, Date)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company, Object.OperationKind);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			True);
	ParametersStructure.Insert("FillHeader",			True);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	If ValueIsFilled(Object.CounterpartyAccount) 
		AND Common.ObjectAttributeValue(Object.CounterpartyAccount, "Owner") = Counterparty Then
		CounterpartyAccount = Object.CounterpartyAccount;
	Else
		CounterpartyAccount = Common.ObjectAttributeValue(Counterparty, "BankAccountByDefault");
	EndIf;
	
	StructureData = New Structure;
	StructureData.Insert("Contract", ContractByDefault);
	StructureData.Insert("CounterpartyAccount", CounterpartyAccount);
	
	CounterpartyData = GetRefAttributes(Counterparty, "DoOperationsByContracts, SettlementsCurrency");
	ContractData = Common.ObjectAttributesValues(ContractByDefault, "SettlementsCurrency, CashFlowItem");
	
	If CounterpartyData.DoOperationsByContracts Then
		SettlementsCurrency = ContractData.SettlementsCurrency;
	Else
		SettlementsCurrency = CounterpartyData.SettlementsCurrency;
	EndIf;
	
	StructureData.Insert("Item", ContractData.CashFlowItem);
	
	StructureData.Insert("DoOperationsByContracts", CounterpartyData.DoOperationsByContracts);
	
	StructureData.Insert("SettlementsCurrency", SettlementsCurrency);
	
	CurrencyRate = CurrencyRateOperations.GetCurrencyRate(Date, SettlementsCurrency, Company);
	Rate = ?(CurrencyRate.Rate = 0, 1, CurrencyRate.Rate);
	Repetition = ?(CurrencyRate.Repetition = 0, 1, CurrencyRate.Repetition);
	
	StructureData.Insert("ContractCurrencyRateRepetition", CurrencyRate);
	StructureData.Insert("ExchangeRate", Rate);
	StructureData.Insert("Multiplier", Repetition);
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.LoanSettlements Then
		DefaultLoanContract = GetDefaultLoanContract(Object.Ref, Counterparty, Company, Object.OperationKind);
		StructureData.Insert(
			"DefaultLoanContract",
			DefaultLoanContract);
	EndIf;

	SetVisibilitySettlementAttributes();
	SetVisibilityEPDAttributes();
	
	Return StructureData;
	
EndFunction

// It receives data set from the server for the CurrencyCashOnChange procedure.
//
&AtServerNoContext
Function GetDataBankAccountOnChange(Date, BankAccount, CounterpartyAccount, Company)
	
	StructureData = New Structure;
	
	CurrencyRate = CurrencyRateOperations.GetCurrencyRate(Date, BankAccount.CashCurrency, Company);
	
	Rate = ?(CurrencyRate.Rate = 0, 1, CurrencyRate.Rate);
	Repetition = ?(CurrencyRate.Repetition = 0, 1, CurrencyRate.Repetition);
	
	StructureData.Insert("ExchangeRate", Rate);
	StructureData.Insert("Multiplier", Repetition);
	StructureData.Insert("CashCurrency", BankAccount.CashCurrency);
	
	StructureData.Insert(
		"CounterpartyAccount",
		?(ValueIsFilled(CounterpartyAccount) AND CounterpartyAccount.CashCurrency = BankAccount.CashCurrency, CounterpartyAccount, Undefined));
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure Attachable_ProcessDateChange()
	
	StructureData = GetDataDateOnChange();
	
	StructureData.Insert("UpdateExchangeRate", Object.PaymentDetails.Count() > 0);
	StructureData.Insert("UpdatePaymentExchangeRate", True);
	StructureData.Insert("UpdateSettlementsExchangeRate", True);
	StructureData.Insert("UpdateBankFeeExchangeRate", True);
	
	MessageText = MessagesToUserClientServer.GetApplyRatesOnNewDateQuestionText();
	
	RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData, MessageText);
	
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
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		FillVATRateByCompanyVATTaxation();
		SetVisibleOfVATTaxation();
	EndIf;
	
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
		?(ValueIsFilled(Object.BankAccount) AND Object.BankAccount.Owner = Object.Company, Object.BankAccount, Object.Company.BankAccountByDefault));
		
	CurrencyRate = CurrencyRateOperations.GetCurrencyRate(Object.Date, StructureData.BankAccount.CashCurrency, Object.Company);
	
	StructureData.Insert("ExchangeRate", CurrencyRate.Rate);
	StructureData.Insert("Multiplier", CurrencyRate.Repetition);
	
	StructureData.Insert(
		"CashCurrency",
		StructureData.BankAccount.CashCurrency);
	
	StructureData.Insert(
		"PresentationCurrency",
		DriveServer.GetPresentationCurrency(Object.Company));
	
	StructureData.Insert(
		"CounterpartyAccount",
		?(ValueIsFilled(Object.CounterpartyAccount) AND StructureData.BankAccount.CashCurrency = Object.CounterpartyAccount.CashCurrency, Object.CounterpartyAccount, Catalogs.BankAccounts.EmptyRef()));
	
	StructureData.Insert(
		"ExchangeRateMethod",
		DriveServer.GetExchangeMethod(Object.Company));
	
	SetAccountingPolicyValues();
	
	SetTaxInvoiceText();
	ProcessingCompanyVATNumbers(False);
	
	FillVATRateByCompanyVATTaxation();
	SetVisibleOfVATTaxation();
	SetVisibilityAmountAttributes();
	SetVisibilityBankChargeAmountAttributes();
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			True);
	ParametersStructure.Insert("FillHeader",			True);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	InformationRegisters.AccountingSourceDocuments.CheckNotifyTypesOfAccountingProblems(
		Object.Ref,
		Object.Company,
		DocumentDate);

	Return StructureData;
	
EndFunction

// It receives data set from the server for the SalaryPaymentStatementOnChange procedure.
//
&AtServerNoContext
Function GetDataSalaryPayStatementOnChange(Statement)
	
	Return Statement.Employees.Total("PaymentAmount");
	
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

// Procedure fills VAT Rate in tabular section
// by company taxation system.
//
&AtServer
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.LoanSettlements
		OR Object.OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToEmployee Then
		
		Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;
		
	Else
		
		Object.VATTaxation = DriveServer.VATTaxation(Object.Company, Object.Date);
		
	EndIf;
	
	If (Object.OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer
			OR Object.OperationKind = Enums.OperationTypesPaymentExpense.Vendor) Then
		
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

&AtServer
// Procedure sets the Taxation field visible.
//
Procedure SetVisibleOfVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		Items.PaymentDetailsVATRate.Visible							= True;
		Items.PaymentDetailsVatAmount.Visible						= True;
		Items.SettlementsOnCreditsPaymentDetailsVATRate.Visible		= True;
		Items.SettlementsOnCreditsPaymentDetailsVATAmount.Visible	= True;
		
		If Object.OperationKind = Enums.OperationTypesPaymentExpense.Vendor
			Or Object.OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer Then
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
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.Vendor 
		Or Object.OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer
		Or Object.OperationKind = Enums.OperationTypesPaymentExpense.LoanSettlements Then
		
		Items.VATTaxation.Visible = RegisteredForVAT;
		
		
	Else
		
		Items.VATTaxation.Visible = False;
		
		If Object.OperationKind = Enums.OperationTypesPaymentExpense.OtherSettlements Then
			Items.PaymentDetailsOtherSettlementsVATRate.Visible = RegisteredForVAT;
			Items.PaymentDetailsOtherSettlementsVATAmount.Visible = RegisteredForVAT;
		EndIf;
		
	EndIf;
	
	
EndProcedure

// Procedure sets the form attribute visible
// from option Use subsystem Payroll.
//
// Parameters:
// No.
//
&AtServer
Procedure SetVisibleByFOUseSubsystemPayroll()
	
	// Salary.
	If Constants.UsePayrollSubsystem.Get() Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentExpense.Salary);
	EndIf;
	
	// Taxes.
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentExpense.Taxes);
	
	// Other.
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentExpense.Other);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentExpense.IssueLoanToEmployee);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentExpense.IssueLoanToCounterparty);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentExpense.LoanSettlements);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentExpense.OtherSettlements);
	
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
	If OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements Then
		
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

// Checks whether document is approved or not.
//
&AtServerNoContext
Function DocumentApproved(BasisDocument)
	
	Return BasisDocument.PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.Approved;
	
EndFunction

// Fills in the contract.
//
&AtServer
Procedure FillInContract(Parameters = Undefined)
	
	If Object.OperationKind <> Enums.OperationTypesPaymentExpense.IssueLoanToEmployee
		And Object.OperationKind <> Enums.OperationTypesPaymentExpense.LoanSettlements Then
		
		If ValueIsFilled(Object.Counterparty)
			And Object.PaymentDetails.Count() > 0
			And (Parameters = Undefined Or (Parameters <> Undefined And Not ValueIsFilled(Parameters.BasisDocument))) Then
			If Not ValueIsFilled(Object.PaymentDetails[0].Contract) Then
				Object.PaymentDetails[0].Contract = Object.Counterparty.ContractByDefault;
			EndIf;
			If ValueIsFilled(Object.PaymentDetails[0].Contract)
				And Object.PaymentDetails[0].ExchangeRate = 0 Then
				ContractCurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.PaymentDetails[0].Contract.SettlementsCurrency, Object.Company);
				Object.PaymentDetails[0].ExchangeRate = ?(ContractCurrencyRateRepetition.Rate = 0, 1, ContractCurrencyRateRepetition.Rate);
				Object.PaymentDetails[0].Multiplicity = ?(ContractCurrencyRateRepetition.Repetition = 0, 1, ContractCurrencyRateRepetition.Repetition);
				CalculateSettlementsAmount(Object.PaymentDetails[0], ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
			EndIf;
		EndIf;
		
	EndIf;
	
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
	ParametersStructure.Insert("FillHeader",			False);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	Modified = True;
	
EndProcedure

&AtServerNoContext
Function GetSubordinateDebitNote(BasisDocument)
	
	Return EarlyPaymentDiscountsServer.GetSubordinateDebitNote(BasisDocument);
	
EndFunction

&AtServerNoContext
Function CheckBeforeDebitNoteFilling(BasisDocument)
	
	Return EarlyPaymentDiscountsServer.CheckBeforeDebitNoteFilling(BasisDocument, False)
	
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
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Vendor") Then
		Object.Correspondence = Undefined;
		Object.ExpenseItem = Undefined;
		Object.RegisterExpense = False;
		Object.TaxKind = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.PayrollPayment.Clear();
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.Order = Undefined;
		Object.LoanContract = Undefined;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Order = Undefined;
			TableRow.Document = Undefined;
			TableRow.AdvanceFlag = False;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.ToCustomer") Then
		Object.Correspondence = Undefined;
		Object.ExpenseItem = Undefined;
		Object.RegisterExpense = False;
		Object.TaxKind = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.PayrollPayment.Clear();
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.Order = Undefined;
		Object.LoanContract = Undefined;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Order = Undefined;
			TableRow.Document = Undefined;
			TableRow.AdvanceFlag = True;
			TableRow.EPDAmount = 0;
			TableRow.SettlementsEPDAmount = 0;
			TableRow.ExistsEPD = False;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.ToAdvanceHolder") Then
		Object.Correspondence = Undefined;
		Object.ExpenseItem = Undefined;
		Object.RegisterExpense = False;
		Object.TaxKind = Undefined;
		Object.Counterparty = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.Order = Undefined;
		Object.PayrollPayment.Clear();
		Object.LoanContract = Undefined;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
			TableRow.EPDAmount = 0;
			TableRow.SettlementsEPDAmount = 0;
			TableRow.ExistsEPD = False;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Salary") Then
		Object.Correspondence = Undefined;
		Object.ExpenseItem = Undefined;
		Object.RegisterExpense = False;
		Object.Counterparty = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.Department = Undefined;
		Object.LoanContract = Undefined;
		If Not FunctionalOptionAccountingCashMethodIncomeAndExpenses Then
			Object.BusinessLine = Undefined;
		EndIf;
		Object.Order = Undefined;
		Object.PaymentDetails.Clear();
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Other") Then
		Object.Counterparty = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.TaxKind = Undefined;
		Object.LoanContract = Undefined;
		Object.PayrollPayment.Clear();
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
			TableRow.EPDAmount = 0;
			TableRow.SettlementsEPDAmount = 0;
			TableRow.ExistsEPD = False;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Taxes") Then
		Object.Counterparty = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.Correspondence = Undefined;
		Object.ExpenseItem = Undefined;
		Object.RegisterExpense = False;
		Object.Department = Undefined;
		Object.LoanContract = Undefined;
		If Not FunctionalOptionAccountingCashMethodIncomeAndExpenses Then
			Object.BusinessLine = Undefined;
		EndIf;
		Object.Order = Undefined;
		Object.PayrollPayment.Clear();
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
			TableRow.EPDAmount = 0;
			TableRow.SettlementsEPDAmount = 0;
			TableRow.ExistsEPD = False;
		EndDo;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.OtherSettlements") Then
		
		Object.Correspondence		= Undefined;
		Object.ExpenseItem 			= Undefined;
		Object.RegisterExpense 		= False;
		Object.Counterparty			= Undefined;
		Object.CounterpartyAccount	= Undefined;
		Object.AdvanceHolder		= Undefined;
		Object.Document				= Undefined;
		Object.TaxKind				= Undefined;
		Object.Order				= Undefined;
		Object.LoanContract			= Undefined;
		
		Object.PayrollPayment.Clear();
		Object.PaymentDetails.Clear();
		
		Object.PaymentDetails.Add();
		Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.LoanSettlements") Then
		
		Object.Correspondence		= Undefined;
		Object.ExpenseItem 			= Undefined;
		Object.RegisterExpense 		= False;
		Object.Counterparty			= Undefined;
		Object.CounterpartyAccount	= Undefined;
		Object.AdvanceHolder		= Undefined;
		Object.TaxKind				= Undefined;
		Object.Department			= Undefined;
		Object.BusinessLine			= Undefined;
		Object.Order				= Undefined;
		Object.LoanContract			= Undefined;
		
		Object.PayrollPayment.Clear();
		
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract				= Undefined;
			TableRow.AdvanceFlag			= False;
			TableRow.Document				= Undefined;
			TableRow.Order					= Undefined;
			TableRow.VATRate				= Undefined;
			TableRow.VATAmount				= Undefined;
			TableRow.EPDAmount				= 0;
			TableRow.SettlementsEPDAmount	= 0;
			TableRow.ExistsEPD				= False;
		EndDo;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.IssueLoanToEmployee") Then
		
		Object.Correspondence		= Undefined;
		Object.ExpenseItem 			= Undefined;
		Object.RegisterExpense 		= False;
		Object.Counterparty			= Undefined;
		Object.CounterpartyAccount	= Undefined;
		Object.AdvanceHolder		= Undefined;
		Object.TaxKind				= Undefined;
		Object.Department			= Undefined;
		Object.BusinessLine			= Undefined;
		Object.Order				= Undefined;
		Object.LoanContract			= Undefined;
		
		Object.PayrollPayment.Clear();
		
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract				= Undefined;
			TableRow.AdvanceFlag			= False;
			TableRow.Document				= Undefined;
			TableRow.Order					= Undefined;
			TableRow.VATRate				= Undefined;
			TableRow.VATAmount				= Undefined;
			TableRow.EPDAmount				= 0;
			TableRow.SettlementsEPDAmount	= 0;
			TableRow.ExistsEPD				= False;
		EndDo;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.IssueLoanToCounterparty") Then
		
		Object.Correspondence		= Undefined;
		Object.ExpenseItem 			= Undefined;
		Object.RegisterExpense 		= False;
		Object.Counterparty			= Undefined;
		Object.CounterpartyAccount	= Undefined;
		Object.AdvanceHolder		= Undefined;
		Object.TaxKind				= Undefined;
		Object.Department			= Undefined;
		Object.BusinessLine			= Undefined;
		Object.Order				= Undefined;
		Object.LoanContract			= Undefined;
		
		Object.PayrollPayment.Clear();
		
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract				= Undefined;
			TableRow.AdvanceFlag			= False;
			TableRow.Document				= Undefined;
			TableRow.Order					= Undefined;
			TableRow.VATRate				= Undefined;
			TableRow.VATAmount				= Undefined;
			TableRow.EPDAmount				= 0;
			TableRow.SettlementsEPDAmount	= 0;
			TableRow.ExistsEPD				= False;
		EndDo;
		
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

	
	OpenForm("CommonForm.SelectInvoicesToBePaidToTheSupplier", SelectionParameters,,,,, New NotifyDescription("SelectionEnd", ThisObject, New Structure("AddressPaymentDetailsInStorage", AddressPaymentDetailsInStorage)));
	
EndProcedure

&AtClient
Procedure SelectionEnd(Result1, AdditionalParameters) Export
	
	AddressPaymentDetailsInStorage = AdditionalParameters.AddressPaymentDetailsInStorage;
	
	Result = Result1;
	If Result = DialogReturnCode.OK Then
		
		GetPaymentDetailsFromStorage(AddressPaymentDetailsInStorage);
		For Each RowPaymentDetails In Object.PaymentDetails Do
			CalculatePaymentSUM(RowPaymentDetails, ExchangeRateMethod, Multiplicity, ExchangeRate, DefaultVATRate);
		EndDo;
		
		DefinePaymentDetailsExistsEPD();
		
		SetCurrentPage();
		
		If Object.PaymentDetails.Count() > 0 Then
			Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
		EndIf;
		
		CalculateTotal();
		
		SetVisibilityDebitNoteText();
		
		Modified = True;
		
	EndIf;

EndProcedure

// You can call the procedure by clicking
// the button "FillByBasis" of the tabular field command panel.
//
&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		ShowMessageBox(Undefined, NStr("en = 'Please select a base document.'; ru = 'Не выбран документ-основание.';pl = 'Wybierz dokument źródłowy.';es_ES = 'Por favor, seleccione un documento de base.';es_CO = 'Por favor, seleccione un documento de base.';tr = 'Lütfen, temel belge seçin.';it = 'Si prega di selezionare un documento di base.';de = 'Bitte wählen Sie ein Basisdokument aus.'"));
		Return;
	EndIf;
	
	If (TypeOf(Object.BasisDocument) = Type("DocumentRef.CashTransferPlan")
		OR TypeOf(Object.BasisDocument) = Type("DocumentRef.ExpenditureRequest"))
		AND Not DocumentApproved(Object.BasisDocument) Then
			Raise NStr("en = 'Please select an approved cash transfer plan.'; ru = 'Нельзя ввести перемещение денег на основании неутвержденного планового документа.';pl = 'Wybierz zatwierdzony plan przelewów gotówkowych.';es_ES = 'Por favor, seleccione un plan de traslado de efectivo aprobado.';es_CO = 'Por favor, seleccione un plan de traslado de efectivo aprobado.';tr = 'Lütfen, onaylı bir nakit transfer planı seçin.';it = 'Si prega di selezionare un piano di trasferimento contanti approvato.';de = 'Bitte wählen Sie einen genehmigten Überweisungsplan aus.'");
	EndIf;
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), 
		NStr("en = 'Do you want to refill the bank payment?'; ru = 'Вы хотите перезаполнить списание со счета?';pl = 'Czy chcesz uzupełnić płatność bankową?';es_ES = '¿Quiere volver a rellenar el pago bancario?';es_CO = '¿Quiere volver a rellenar el pago bancario?';tr = 'Banka ödemesi yeniden doldurulsun mu?';it = 'Ricompilare il pagamento bancario?';de = 'Möchten Sie die Überweisung auffüllen?'"), 
		QuestionDialogMode.YesNo, 
		0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		
		Object.BankAccount = Undefined;
		Object.CounterpartyAccount = Undefined;
		
		Object.PaymentDetails.Clear();
		Object.PayrollPayment.Clear();
		
		FillByDocument(Object.BasisDocument);
		
		If Object.OperationKind <> PredefinedValue("Enum.OperationTypesPaymentExpense.Salary")
			AND Object.PaymentDetails.Count() = 0 Then
			Object.PaymentDetails.Add();
			Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		EndIf;
		
		OperationKind = Object.OperationKind;
		CashCurrency = Object.CashCurrency;
		DocumentDate = Object.Date;
		
		SetCurrentPage();
		SetChoiceParameterLinksAvailableTypes();
		OperationKindOnChangeAtServer(False);
		
		FillInContract();
		
	EndIf;
	
EndProcedure

// Procedure - FillDetails command handler.
//
&AtClient
Procedure FillDetails(Command)
	
	If Object.DocumentAmount = 0
		And Object.OperationKind <> PredefinedValue("Enum.OperationTypesPaymentExpense.ToCustomer") Then
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
		NStr("en = 'Do you want to overwrite the payment details?'; ru = 'Расшифровка будет полностью перезаполнена. Продолжить?';pl = 'Czy chcesz nadpisać szczegóły płatności?';es_ES = '¿Quiere sobrescribir los detalles de pago?';es_CO = '¿Quiere sobrescribir los detalles de pago?';tr = 'Ödeme ayrıntıları üzerine yazmak istiyor musunuz?';it = 'Volete riscrivere i dettagli di pagamento?';de = 'Möchten Sie die Zahlungsdetails überschreiben?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillDetailsEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	Object.PaymentDetails.Clear();
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Vendor") Then
		
		FillPaymentDetails();
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.ToCustomer") Then
		
		FillAdvancesPaymentDetails();
		
	EndIf;
	
	SetCurrentPage();
	
EndProcedure

&AtClient
Procedure CalculateEPD(Command)
	
	CalculateEPDServer();
	
	PaymentAmount = Object.PaymentDetails.Total("PaymentAmount");
	
	If PaymentAmount <> Object.DocumentAmount Then
		
		Notification	= New NotifyDescription("ChangeDocumentAmountAfterCalculateEPD", ThisObject);
		MessageText		= NStr("en = 'Document total is not equal to the sum of the allocated payments.
			|Do you want to correct the document amount?'; 
			|ru = 'Сумма документа не совпадает с суммой отнесенных платежей.
			|Скорректировать сумму документа?';
			|pl = 'Łączna wartość dokumentu nie jest równa wartości przydzielonych płatności.
			|Czy chcesz poprawić wartość dokumentu?';
			|es_ES = 'El documento total no es igual a la suma de los pagos asignados.
			|¿Quiere corregir el importe del documento?';
			|es_CO = 'El documento total no es igual a la suma de los pagos asignados.
			|¿Quiere corregir el importe del documento?';
			|tr = 'Belge toplamı, ödenen ödemelerin toplamına eşit değildir. 
			| Belge tutarını düzeltmek ister misiniz?';
			|it = 'Il totale del documento non è uguale alla somma dei documenti assegnati.
			|Volete correggere l''importo del documento?';
			|de = 'Die Belegsumme entspricht nicht der Summe der zugeordneten Zahlungen.
			|Möchten Sie den Belegbetrag korrigieren?'");
		
		ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo, ,DialogReturnCode.Yes);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeDocumentAmountAfterCalculateEPD(Response, NotSpecified) Export
	
	If Response = DialogReturnCode.Yes Then
		
		Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
		
		CalculateTotal();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CalculateEPDServer()
	
	Document = FormAttributeToValue("Object");
	Document.CalculateEPD();
	ValueToFormAttribute(Document, "Object");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			True);
	ParametersStructure.Insert("FillHeader",			False);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	Modified = True;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

// Procedure - event handler OnChange of the Counterparty input field.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	StructureData = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company, Object.Date);
	
	If NOT ValueIsFilled(Object.CounterpartyAccount) AND StructureData.Property("CounterpartyAccount") 
		AND ValueIsFilled(StructureData.CounterpartyAccount) Then
		Object.CounterpartyAccount = StructureData.CounterpartyAccount;
	EndIf;
	
	FillPaymentDetailsByContractData(StructureData);
	
	If StructureData.Property("DefaultLoanContract") AND ValueIsFilled(StructureData.DefaultLoanContract) Then
		Object.LoanContract = StructureData.DefaultLoanContract;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.LoanSettlements") Then
		CommonClientServer.MessageToUser(NStr("en = 'Please select a lender with an unpaid loan contract.'; ru = 'Выберите заимодателя с невыплаченным договором кредита (займа).';pl = 'Wybierz pożyczkodawcę z nieopłaconym umową pożyczki.';es_ES = 'Por favor, seleccione un prestamista con un contrato de préstamo sin pagar.';es_CO = 'Por favor, seleccionar un prestamista con un contrato de préstamo sin pagar.';tr = 'Lütfen, ödenmemiş kredi sözleşmesi olan bir borç veren seçin.';it = 'Selezionare un prestatore con contratto di prestito non pagato.';de = 'Bitte wählen Sie einen Darlehensgeber mit einem unbezahlten Darlehensvertrag.'"),
			,
			"Counterparty",
			"Object");
	EndIf;
	
	HandleLoanContractChange();
	
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
		SetChoiceParameterLinksAvailableTypes();
		OperationKindOnChangeAtServer();
		
		Object.AccountingAmount = GetAccountingAmount(Object.DocumentAmount, 
			ExchangeRateMethod,
			Object.ExchangeRate,
			Object.Multiplicity);
		
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
// In procedure situation is determined when date change document is
// into document numbering another period and in this case
// assigns to the document new unique number.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
Procedure PaymentDateOnChange(Item)
	
	DefinePaymentDetailsExistsEPD();
	
EndProcedure

// Procedure - event handler OnChange of the Company input field.
// In procedure is executed document
// number clearing and also make parameter set of the form functional options.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	Object.Number					= "";
	StructureData					= GetCompanyDataOnChange();
	ParentCompany					= StructureData.ParentCompany;
	Object.BankAccount				= StructureData.BankAccount;
	Object.CounterpartyAccount		= StructureData.CounterpartyAccount;
	
	CurrencyCashBeforeChanging		= CashCurrency;
	PresentationCurrency			= StructureData.PresentationCurrency;
	ExchangeRateMethod 				= StructureData.ExchangeRateMethod;
	
	BankAccountOnChange(Undefined);
	
	// If currency is not changed, do nothing.
	If CashCurrency = CurrencyCashBeforeChanging Then
		Return;
	EndIf;
	
	If ValueIsFilled(Object.Counterparty) Then 
		
		StructureContractData = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company, Object.Date);
		FillPaymentDetailsByContractData(StructureContractData);
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of BankAccount input field.
//
&AtClient
Procedure BankAccountOnChange(Item)
	
	StructureData = GetDataBankAccountOnChange(
		Object.Date,
		Object.BankAccount,
		Object.CounterpartyAccount,
		Object.Company);
		
	CashCurrencyBeforeChange = Object.CashCurrency;
	
	If CashCurrencyBeforeChange = StructureData.CashCurrency
		Or Not ValueIsFilled(StructureData.CashCurrency) Then
		
		Return;
		
	EndIf;
	
	Object.CounterpartyAccount		= StructureData.CounterpartyAccount;
	Object.CashCurrency				= StructureData.CashCurrency;
	CashCurrency 					= StructureData.CashCurrency;
	
	SetVisibilityAmountAttributes();
	SetVisibilityBankChargeAmountAttributes();
	
	FillCurrencyChoiceList(ThisForm, "TaxesSettlementsExchangeRate", Object.CashCurrency);
	FillCurrencyChoiceList(ThisForm, "OtherSettlementsExchangeRate", Object.CashCurrency);
	FillCurrencyChoiceList(ThisForm, "BankChargeExchangeRate", Object.CashCurrency);
	FillCurrencyChoiceList(ThisForm, "PaymentDetailsPaymentExchangeRate", Object.CashCurrency);
	FillCurrencyChoiceList(ThisForm, "PaymentDetailsOtherSettlementsPaymentExchangeRate", Object.CashCurrency);
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Salary") Then
		
		MessageText = NStr("en = 'The bank account currency has been changed. The list of payslips will be cleared.'; ru = 'Валюта банковского счета была изменена. Список расчетных листков будет очищен.';pl = 'Waluta rachunku bankowego została zmieniona. Lista pasków wynagrodzenia zostanie wyczyszczona.';es_ES = 'La moneda de la cuenta bancaria se ha cambiado. La lista de nóminas se eliminará.';es_CO = 'La moneda de la cuenta bancaria se ha cambiado. La lista de nóminas se eliminará.';tr = 'Banka hesabının para birimi değiştirildi. Maaş bordrosu listesi temizlenecek.';it = 'La valuta del conto corrente è stata modificata. L''elenco di buste paga sarà cancellato.';de = 'Die Währung hat sich geändert. Die Liste der Lohnzettel wird gelöscht. '");
		StructureData.Insert("MessageText", MessageText);
		ShowMessageBox(New NotifyDescription("BankAccountOnChangeEnd", 
			ThisObject, 
			StructureData), 
			MessageText);
			
		Return;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Vendor")
		Or Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.ToCustomer")
		Or Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.OtherSettlements")
		Or Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Taxes")
		Or Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Other") Then
		
		StructureData.Insert("UpdateExchangeRate", True);
		StructureData.Insert("UpdatePaymentExchangeRate", True);
		StructureData.Insert("UpdateSettlementsExchangeRate", False);
		StructureData.Insert("UpdateBankFeeExchangeRate", True);
		
		BankAccountOnChangeEnd(StructureData);
		
		Return;
		
	EndIf;
	
	StructureData.Insert("UpdateExchangeRate", True);
	BankAccountOnChangeFragment(StructureData);
	
EndProcedure

&AtClient
Procedure BankAccountOnChangeEnd(AdditionalParameters) Export
	
	BankAccountOnChangeFragment(AdditionalParameters);

EndProcedure

&AtClient
Procedure BankAccountOnChangeFragment(StructureData)
	
	RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData);
	SetVisibilityAmountAttributes();
	SetVisibilityBankChargeAmountAttributes();
	
EndProcedure

// Procedure - OnChange event handler of DocumentAmount input field.
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
Procedure TaxesSettlementsExchangeRateOnChange(Item)
	
	If Not Object.CashCurrency = PresentationCurrency Then
		
		Object.AccountingAmount = GetAccountingAmount(Object.DocumentAmount, 
			ExchangeRateMethod,
			Object.ExchangeRate,
			Object.Multiplicity);
			
	EndIf;
	
EndProcedure

&AtClient
Procedure OtherSettlementsExchangeRateChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	ExchangeRateChoiceProcessing(, "ExchangeRate", SelectedValue, StandardProcessing, Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure TaxesSettlementsExchangeRateChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	ExchangeRateChoiceProcessing(, "ExchangeRate", SelectedValue, StandardProcessing, Object.CashCurrency);
	
EndProcedure

&AtClient
Procedure TaxesSettlementsMultiplicityOnChange(Item)
	
	If Not Object.CashCurrency = PresentationCurrency Then
		
		Object.AccountingAmount = GetAccountingAmount(Object.DocumentAmount, 
			ExchangeRateMethod,
			Object.ExchangeRate,
			Object.Multiplicity);
			
	EndIf;
	
EndProcedure

&AtClient
Procedure GLAccountsClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not ReadOnly Then
		LockFormDataForEdit();
	EndIf;
	
	FormParameters = EmployeeGLAccountsStructure(Object);
	FormParameters.Insert("Employee", Object.AdvanceHolder);
	
	OpenForm("Catalog.Employees.Form.EmployeeGLAccounts", FormParameters, ThisObject);
	
EndProcedure

#Region TabularSectionAttributeEventHandlers

// Procedure - BeforeDeletion event handler of PaymentDetails tabular section.
//
&AtClient
Procedure PaymentDetailsBeforeDelete(Item, Cancel)
	
	If Object.PaymentDetails.Count() <= 1 Then
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
Procedure PaymentDetailsOnStartEdit(Item, NewRow, Clone)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If UseDefaultTypeOfAccounting Then
	
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	
	If NewRow And Not Clone Then
		
		TabularSectionRow.PaymentExchangeRate = Object.ExchangeRate;
		TabularSectionRow.PaymentMultiplier = Object.Multiplicity;
		
		If ValueIsFilled(Object.Counterparty) Then
			
			CounterpartyAttributes = GetRefAttributes(Object.Counterparty, "DoOperationsByContracts");
			If Not CounterpartyAttributes.DoOperationsByContracts Then
				
				TabularSectionRow.Contract = GetContractByDefault(Object.Ref,
					Object.Counterparty,
					Object.Company,
					Object.OperationKind);
				
				ProcessCounterpartyContractChange();
				
			EndIf;
			
		EndIf;
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.ToCustomer") Then
			TabularSectionRow.AdvanceFlag = True;
		EndIf;
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Vendor") Then
			TabularSectionRow.DiscountReceivedIncomeItem = DefaultIncomeItem;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsOnEditEnd(Item, NewRow, CancelEdit)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnEditEnd(ThisIsNewRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	GLAccountsInDocumentsClient.GLAccountsStartChoice(ThisObject, "PaymentDetails", StandardProcessing);  
	
EndProcedure

// The OnChange event handler of the PaymentDetailsContract field.
// It updates the contract currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure PaymentDetailsContractOnChange(Item)
	
	ProcessCounterpartyContractChange();
	
EndProcedure

// The OnChange event handler of the PaymentDetailsContract field.
// It updates the contract currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure PaymentDetailsContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	ProcessStartChoiceCounterpartyContract(Item, StandardProcessing);
	
EndProcedure

// Procedure - OnChange event handler of PaymentDetailsSettlementsKind input field.
// Clears an attribute document if a settlement type is - "Advance".
//
&AtClient
Procedure PaymentDetailsAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Vendor") Then
		
		If TabularSectionRow.AdvanceFlag Then
			TabularSectionRow.Document = Undefined;
		Else
			TabularSectionRow.PlanningDocument = Undefined;
		EndIf;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.ToCustomer") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CreditNote")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.OnlineReceipt")
			Or TabularSectionRow.Document = Undefined Then
			
			If Not TabularSectionRow.AdvanceFlag Then
				TabularSectionRow.AdvanceFlag = True;
				CommonClientServer.MessageToUser(
					NStr("en = 'Cannot clear the ""Advance payment"" check box for documents of this type.'; ru = 'Невозможно снять флажок ""Авансовый платеж"" для документов данного типа.';pl = 'Nie można oczyścić pola wyboru ""Zaliczka"" dla tego typu operacji.';es_ES = 'No se puede desmarcar la casilla de verificación ""Pago anticipado"" para este tipo de documento.';es_CO = 'No se puede desmarcar la casilla de verificación ""Pago anticipado"" para este tipo de documento.';tr = 'Bu tür belgeler için ""Avans ödeme"" onay kutusu temizlenemez.';it = 'Impossibile deselezionare la casella di controllo ""Pagamento anticipato"" per documenti di questo tipo.';de = 'Das Kontrollkästchen ""Vorauszahlung"" für diesen Dokumententyp kann nicht deaktiviert werden.'"));
			EndIf;
			
		ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.ArApAdjustments") Then
			
			If TabularSectionRow.AdvanceFlag Then
				TabularSectionRow.AdvanceFlag = False;
				CommonClientServer.MessageToUser(
					NStr("en = 'Cannot select the ""Advance payment"" check box for documents of this type.'; ru = 'Не удается установить флажок ""Авансовый платеж"" для документов данного типа.';pl = 'Nie zaznaczyć pola wyboru ""Zaliczka"" dla tego typu operacji.';es_ES = 'No se puede seleccionar la casilla de verificación ""Pago anticipado"" para este tipo de documento.';es_CO = 'No se puede seleccionar la casilla de verificación ""Pago anticipado"" para este tipo de documento.';tr = 'Bu tür belgeler için ""Avans ödemeler"" onay kutusu seçilemez.';it = 'Impossibile selezionare la casella di controllo ""Pagamento anticipato"" per documenti di questo tipo.';de = 'Das Kontrollkästchen ""Vorauszahlung"" für diesen Dokumententyp kann nicht deaktiviert werden.'"));
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - SelectionStart event handler of PaymentDetailsDocument input field.
// Passes the current attribute value to the parameters.
//
&AtClient
Procedure PaymentDetailsDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If TabularSectionRow.AdvanceFlag
		AND Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Vendor") Then
		
		ShowMessageBox(, NStr("en = 'This field is for a billing document. 
			|It is not required for an advance payment. 
			|In this case, a billing document is this Bank payment.'; 
			|ru = 'Это поле предназначено для платежного документа. 
			|Оно не требуется для авансового платежа. 
			|В данном случае документом расчета является списание со счета.';
			|pl = 'To pole jest dla dokumentu rozliczeniowego. 
			|To nie jest wymagane dla zaliczki. 
			|W tym przypadku, dokument rozliczeniowy jest tym przelewem bankowym.';
			|es_ES = 'Este campo es para un documento de facturación.
			|No es necesario para un pago anticipado.
			|En este caso, un documento de facturación es este Pago bancario.';
			|es_CO = 'Este campo es para un documento de facturación.
			|No es necesario para un pago anticipado.
			|En este caso, un documento de facturación es este Pago bancario.';
			|tr = 'Bu alan, fatura belgesi içindir. 
			|Avans ödeme için gerekli değildir. 
			|Bu durumda fatura belgesi bu Banka ödemesidir.';
			|it = 'Questo campo è per un documento di fatturazione.
			| Non è richiesto per il pagamento anticipato. 
			|In questo caso, un documento di fatturazione è questo Pagamento bancario.';
			|de = 'Dieses Feld ist für einen Abrechnungsbeleg. 
			|Es ist nicht für eine Vorauszahlung erforderlich. 
			|In diesem Fall ist ein Abrechnungsbeleg diese Bankzahlung.'"));
		
	Else
		
		ThisIsAccountsReceivable = Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.ToCustomer");
		
		StructureFilter = New Structure();
		StructureFilter.Insert("Company",		Object.Company);
		StructureFilter.Insert("Counterparty",	Object.Counterparty);
		
		If ValueIsFilled(TabularSectionRow.Contract) Then
			StructureFilter.Insert("Contract", TabularSectionRow.Contract);
		EndIf;
		
		ParameterStructure = New Structure("Filter, ThisIsAccountsReceivable, DocumentType",
			StructureFilter,
			ThisIsAccountsReceivable,
			TypeOf(Object.Ref));
		
		ParameterStructure.Insert("IsCustomerReturn", Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.ToCustomer"));
		ParameterStructure.Insert("Document", Object.Ref);
		
		OpenForm("CommonForm.SelectDocumentOfSettlements", ParameterStructure, Item);
		
	EndIf;
	
EndProcedure

// Procedure - SelectionDataProcessor event handler of PaymentDetailsDocument input field.
//
&AtClient
Procedure PaymentDetailsDocumentChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	ProcessAccountsDocumentSelection(ValueSelected);
	
EndProcedure

// Procedure - OnChange event handler of the field in PaymentDetailsSettlementsAmount.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsSettlementsAmountOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	CalculateSettlementsRate(TabularSectionRow);
	
EndProcedure

// Procedure - OnChange event handler of PaymentDetailsExchangeRate input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsRateOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculateSettlementsAmount(TabularSectionRow, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
EndProcedure

// Procedure - OnChange event handler of PaymentDetailsUnitConversionFactor input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsRepetitionOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculateSettlementsAmount(TabularSectionRow, ExchangeRateMethod, PresentationCurrency, Object.CashCurrency);
	
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
	
	SetVisibilityDebitNoteText();
	
EndProcedure

// Procedure - OnChange event handler of PaymentDetailsVATRate input field.
// Calculates VAT amount.
//
&AtClient
Procedure PaymentDetailsVATRateOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure

// Procedure - OnChange event handler of PaymentDetailsDocument input field.
//
&AtClient
Procedure PaymentDetailsDocumentOnChange(Item)
	
	RunActionsOnAccountsDocumentChange();
	
EndProcedure

&AtClient
Procedure PaymentDetailsIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "PaymentDetails", StandardProcessing);
	
EndProcedure

// Procedure - OnChange event handler of SalaryPaymentStatement input field.
//
&AtClient
Procedure SalaryPayStatementOnChange(Item)
	
	TabularSectionRow = Items.PayrollPayment.CurrentData;
	TabularSectionRow.PaymentAmount = GetDataSalaryPayStatementOnChange(TabularSectionRow.Statement);
	
EndProcedure

&AtClient
Procedure OtherSettlementsAccountingAmountOnChange(Item)
	
	AccountingAmountOnChange();
	
EndProcedure

&AtClient
Procedure TaxesSettlementsAccountingAmountOnChange(Item)
	
	AccountingAmountOnChange();
	
EndProcedure

#EndRegion

// Procedure executes actions while changing counterparty contract.
//
&AtClient
Procedure ProcessCounterpartyContractChange()
	
	ProcessCounterpartyContractChangeAtServer(Items.PaymentDetails.CurrentRow);
	
EndProcedure

&AtServer
Procedure ProcessCounterpartyContractChangeAtServer(RowId)
	
	TabularSectionRow = Object.PaymentDetails.FindByID(RowId);
	
	StructureData = GetStructureDataForObject(ThisObject, "PaymentDetails", TabularSectionRow);
	
	If ValueIsFilled(TabularSectionRow.Contract) Then
		
		StructureData = GetDataPaymentDetailsContractOnChange(
			Object.Date,
			TabularSectionRow.Contract,
			Object.Company,
			StructureData);
			
		TabularSectionRow.ExchangeRate = StructureData.ContractCurrencyRateRepetition.Rate;
		TabularSectionRow.Multiplicity = StructureData.ContractCurrencyRateRepetition.Repetition;
		TabularSectionRow.SettlementsCurrency = StructureData.Currency;
		
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
			ProcessCounterpartyContractChange();
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
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.ToCustomer") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.OnlineReceipt")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CreditNote")
			Then
			
			TabularSectionRow.AdvanceFlag = True;
			
		Else
			
			TabularSectionRow.AdvanceFlag = False;
			
		EndIf;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Vendor") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.SupplierInvoice") Then
			
			StructureData = GetStructureDataForObject(ThisObject, "PaymentDetails", TabularSectionRow);
			
			SetExistsEPD(StructureData);
			FillPropertyValues(TabularSectionRow, StructureData);
			
		EndIf;
		
		SetVisibilityDebitNoteText();
		
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
	
	Return Documents.SupplierInvoice.CheckExistsEPD(Document, CheckDate);
	
EndFunction

// Procedure is filling the payment details.
//
&AtServer
Procedure FillPaymentDetails(CurrentObject = Undefined)
	
	Document = FormAttributeToValue("Object");
	Document.FillPaymentDetails(WorkWithVAT.GetVATAmountFromBasisDocument(Object));
	ValueToFormAttribute(Document, "Object");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillPaymentDetails", True);
	
	FillAddedColumns(ParametersStructure);
	
	SetVisibilityDebitNoteText();
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure FillAdvancesPaymentDetails()
	
	Document = FormAttributeToValue("Object");
	Document.FillAdvancesPaymentDetails();
	ValueToFormAttribute(Document, "Object");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillPaymentDetails", True);
	
	FillAddedColumns(ParametersStructure);
	
	Modified = True;
	
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

&AtServer
Procedure SetTaxInvoiceText()
	Items.TaxInvoiceText.Visible = Not WorkWithVAT.GetPostAdvancePaymentsBySourceDocuments(Object.Date, Object.Company)
EndProcedure

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

&AtClient
Procedure HandleLoanContractChange()
	
	EmployeeLoanAgreementData = LoanContractOnChangeAtServer(Object.LoanContract, Object.Date);
	
	FillInformationAboutCreditLoanAtServer();
		
EndProcedure

&AtServerNoContext
Function LoanContractOnChangeAtServer(LoanContract, Date)
	
	DataStructure = New Structure;
	
	DataStructure.Insert("Currency", 			LoanContract.SettlementsCurrency);
	DataStructure.Insert("Counterparty",		LoanContract.Counterparty);
	DataStructure.Insert("Employee",			LoanContract.Employee);
	DataStructure.Insert("ThisIsLoanContract",	LoanContract.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement);
		
	Return DataStructure;
	
EndFunction

&AtServer
Procedure FillInformationAboutCreditLoanAtServer()
	
	ConfigureLoanContractItem();
	
	If Object.LoanContract.IsEmpty() Then
		
		Items.LabelCreditContractInformation.Title	= NStr("en = '<Select a loan contract>'; ru = '<Выберите договор кредита (займа)>';pl = '<Wybierz umowę pożyczki>';es_ES = '<Seleccionar un contrato de préstamo>';es_CO = '<Seleccionar un contrato de préstamo>';tr = '<Kredi sözleşmesi seç>';it = '<Selezionate contratto di prestito>';de = '<Einen Darlehensvertrag auswählen>'");
		Items.LabelRemainingDebtByCredit.Title		= "";
		
		Items.LabelCreditContractInformation.TextColor	= StyleColors.BorderColor;
		Items.LabelRemainingDebtByCredit.TextColor		= StyleColors.BorderColor;
		
		Return;
		
	EndIf;
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToEmployee 
		OR Object.OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToCounterparty Then
		FillInformationAboutLoanAtServer();
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentExpense.LoanSettlements Then
		FillInformationAboutCreditAtServer();
	EndIf;
	
EndProcedure

&AtServer
Procedure FillInformationAboutCreditAtServer();
	    
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
	|	LoanSettlementsBalance.LoanContract.SettlementsCurrency.Description AS CurrencyPresentation,
	|	SUM(LoanSettlementsBalance.InterestCurBalance) AS InterestCurBalance,
	|	SUM(LoanSettlementsBalance.CommissionCurBalance) AS CommissionCurBalance
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
	
	Query.SetParameter("SliceLastDate", ?(Object.Date = '00010101', BegOfDay(CurrentSessionDate()), BegOfDay(Object.Date)));
	Query.SetParameter("LoanContract", Object.LoanContract);
	
	ResultsArray = Query.ExecuteBatch();
	
	If Object.LoanContract.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement Then
		Multiplier = 1;
	Else
		Multiplier = -1;
	EndIf;
	
	SelectionSchedule = ResultsArray[0].Select();
	SelectionScheduleFutureMonth = ResultsArray[2].Select();
	
	LabelCreditContractInformationTextColor = StyleColors.BorderColor;
	LabelRemainingDebtByCreditTextColor = StyleColors.BorderColor;
	
	If SelectionScheduleFutureMonth.Next() Then
		
		If BegOfMonth(?(Object.Date = '00010101', CurrentSessionDate(), Object.Date)) = BegOfMonth(SelectionScheduleFutureMonth.Period) Then
			PaymentDate = Format(SelectionScheduleFutureMonth.Period, "DLF=D");
		Else
			PaymentDate = Format(SelectionScheduleFutureMonth.Period, "DLF=D") + " (" + NStr("en = 'not in the current month'; ru = 'не в текущем месяце';pl = 'nie w bieżącym miesiącu';es_ES = 'no el mes corriente';es_CO = 'no el mes corriente';tr = ' cari ayda değil';it = 'non nel mese corrente';de = 'nicht im aktuellen Monat'") + ")";
			LabelCreditContractInformationTextColor = StyleColors.FormTextColor;
		EndIf;
			
		LabelCreditContractInformation = StringFunctionsClientServer.SubstituteParametersToString( 
			NStr("en = 'Payment date: %1. Debt amount: %2. Interest: %3. Commission: %4 (%5).'; ru = 'Дата платежа: %1. Сумма долга: %2. Проценты %: %3. Комиссия: %4 (%5).';pl = 'Data płatności: %1. Kwota zobowiązania: %2. Odsetki: %3. Prowizja: %4 (%5).';es_ES = 'Fecha de pago: %1. Importe de la deuda:%2. Interés: %3. Comisión: %4 (%5).';es_CO = 'Fecha de pago: %1. Importe de la deuda:%2. Interés: %3. Comisión: %4 (%5).';tr = 'Ödeme tarihi: %1. Borç tutarı: %2. Faiz: %3. Komisyon: %4 (%5).';it = 'Data pagamento: %1. Importo debito: %2. Interesse: %3. Commissione: %4 (%5).';de = 'Zahlungstermin: %1. Schuldenbetrag: %2. Zinsen: %3. Provisionszahlung: %4 (%5).'"),
			PaymentDate,
			Format(SelectionScheduleFutureMonth.Principal, "NFD=2; NZ=0"),
			Format(SelectionScheduleFutureMonth.Interest, "NFD=2; NZ=0"),
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
			NStr("en = 'Payment date: %1. Debt amount: %2. Interest: %3. Commission: %4 (%5).'; ru = 'Дата платежа: %1. Сумма долга: %2. Проценты %: %3. Комиссия: %4 (%5).';pl = 'Data płatności: %1. Kwota zobowiązania: %2. Odsetki: %3. Prowizja: %4 (%5).';es_ES = 'Fecha de pago: %1. Importe de la deuda:%2. Interés: %3. Comisión: %4 (%5).';es_CO = 'Fecha de pago: %1. Importe de la deuda:%2. Interés: %3. Comisión: %4 (%5).';tr = 'Ödeme tarihi: %1. Borç tutarı: %2. Faiz: %3. Komisyon: %4 (%5).';it = 'Data pagamento: %1. Importo debito: %2. Interesse: %3. Commissione: %4 (%5).';de = 'Zahlungstermin: %1. Schuldenbetrag: %2. Zinsen: %3. Provisionszahlung: %4 (%5).'"),
			PaymentDate,
			Format(SelectionSchedule.Principal, "NFD=2; NZ=0"),
			Format(SelectionSchedule.Interest, "NFD=2; NZ=0"),
			Format(SelectionSchedule.Commission, "NFD=2; NZ=0"),
			SelectionSchedule.CurrencyPresentation);
		
	Else
		
		LabelCreditContractInformation = NStr("en = 'Payment date: <not specified>'; ru = 'Дата платежа: <не указана>';pl = 'Data płatności: <nieokreślona>';es_ES = 'Fecha de pago: <no especificado>';es_CO = 'Fecha de pago: <no especificado>';tr = 'Ödeme tarihi: <belirtilmemiş>';it = 'Data di pagamento: <non specificata>';de = 'Zahlungstermin: <not specified>'");
		
	EndIf;
		
	SelectionBalance = ResultsArray[1].Select();
	If SelectionBalance.Next() Then
		
		LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Debt balance: %1. Interest: %2. Commission: %3 (%4).'; ru = 'Остаток долга: %1. Проценты %: %2. Комиссия: %3 (%4).';pl = 'Saldo zobowiązania: %1. Odsetki: %2. Prowizja: %3 (%4).';es_ES = 'Saldo de la deuda: %1. Interés: %2. Comisión:%3 (%4).';es_CO = 'Saldo de la deuda: %1. Interés: %2. Comisión:%3 (%4).';tr = 'Borç bakiyesi: %1. Faiz: %2. Komisyon: %3 (%4).';it = 'Saldo debito: %1. Interesse: %2. Commissione: %3 (%4).';de = 'Schuldensaldo: %1. Zinsen: %2Provisionszahlung: %3 (%4).'"),
			Format(Multiplier * SelectionBalance.PrincipalDebtCurBalance, "NFD=2; NZ=0"),
			Format(Multiplier * SelectionBalance.InterestCurBalance, "NFD=2; NZ=0"),
			Format(Multiplier * SelectionBalance.CommissionCurBalance, "NFD=2; NZ=0"),
			SelectionBalance.CurrencyPresentation);
			
		If Multiplier * SelectionBalance.PrincipalDebtCurBalance >= 0 
			AND (Multiplier * SelectionBalance.InterestCurBalance < 0 
				OR Multiplier * SelectionBalance.CommissionCurBalance < 0) Then
				
			LabelRemainingDebtByCreditTextColor = StyleColors.FormTextColor;
			
		EndIf;
		
		If Multiplier * SelectionBalance.PrincipalDebtCurBalance < 0 Then
			LabelRemainingDebtByCreditTextColor = StyleColors.SpecialTextColor;
		EndIf;
	Else
		
		LabelRemainingDebtByCredit = NStr("en = 'Debt balance: <not specified>'; ru = 'Остаток долга: <не указан>';pl = 'Saldo zadłużenia: <nieokreślone>';es_ES = 'Saldo de la deuda: <no especificado>';es_CO = 'Saldo de la deuda: <no especificado>';tr = 'Borç bakiyesi: <belirtilmemiş>';it = 'Saldo del debito: <non specificato>';de = 'Schuldensaldo: <not specified>'");
		
	EndIf;
	
	Items.LabelCreditContractInformation.Title		= LabelCreditContractInformation;
	Items.LabelRemainingDebtByCredit.Title			= LabelRemainingDebtByCredit;	
	Items.LabelCreditContractInformation.TextColor	= LabelCreditContractInformationTextColor;
	Items.LabelRemainingDebtByCredit.TextColor		= LabelRemainingDebtByCreditTextColor;
		
EndProcedure

&AtServer
Procedure ConfigureLoanContractItem()
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToEmployee Then
		
		Items.EmployeeLoanAgreement.Enabled = NOT Object.AdvanceHolder.IsEmpty();
		If Items.EmployeeLoanAgreement.Enabled Then
			Items.EmployeeLoanAgreement.InputHint = "";
		Else
			Items.EmployeeLoanAgreement.InputHint = NStr("en = 'Before selecting a contract, select an employee.'; ru = 'Чтобы выбрать договор, выберите сотрудника';pl = 'Przed wybraniem umowy, wybierz pracownika.';es_ES = 'Antes de seleccionar un contrato, seleccione un empleado.';es_CO = 'Antes de seleccionar un contrato, seleccionar un empleado.';tr = 'Sözleşme seçmeden önce bir çalışan seçin.';it = 'Prima di scegliere un contratto, selezionare un dipendente.';de = 'Bevor Sie einen Vertrag auswählen, wählen Sie einen Mitarbeiter aus.'");
		EndIf;
		
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToCounterparty Then
		
		Items.EmployeeLoanAgreement.Enabled = NOT Object.Counterparty.IsEmpty();
		If Items.EmployeeLoanAgreement.Enabled Then
			Items.EmployeeLoanAgreement.InputHint = "";
		Else
			Items.EmployeeLoanAgreement.InputHint = NStr("en = 'Select a borrower first.'; ru = 'Сначала выберите заемщика.';pl = 'Najpierw wybierz pożyczkobiorcę.';es_ES = 'Primero seleccione un prestatario.';es_CO = 'Primero seleccione un prestatario.';tr = 'Önce, borçlananı seçin.';it = 'Selezionare prima un mutuatario.';de = 'Wählen Sie einen Darlehensnehmer erst aus.'");
		EndIf;
		
	EndIf;
	
	Items.CreditContract.Enabled = NOT Object.Counterparty.IsEmpty();
	If Items.CreditContract.Enabled Then
		Items.CreditContract.InputHint = "";
	Else
		Items.CreditContract.InputHint = NStr("en = 'Select a lender first.'; ru = 'Сначала выберите заимодателя.';pl = 'Najpierw wybierz pożyczkodawcę.';es_ES = 'Primero seleccione un prestamista.';es_CO = 'Primero seleccione un prestamista.';tr = 'Önce, borç vereni seçin.';it = 'Selezionare prima un finanziatore.';de = 'Wählen Sie einen Darlehensgeber erst aus.'");
	EndIf;
	
EndProcedure

&AtServer
Procedure FillInformationAboutLoanAtServer()

	LabelCreditContractInformationTextColor = StyleColors.BorderColor;
	LabelRemainingDebtByCreditTextColor = StyleColors.BorderColor;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	LoanSettlementsTurnovers.LoanContract.SettlementsCurrency AS Currency,
	|	LoanSettlementsTurnovers.PrincipalDebtCurReceipt AS PrincipalDebtCurReceipt
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
	|	TemporaryTableAmountsIssuedBefore.Currency AS Currency,
	|	SUM(TemporaryTableAmountsIssuedBefore.PrincipalDebtCurReceipt) AS PrincipalDebtCurReceipt,
	|	LoanContract.Total AS Total
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
	Query.SetParameter("Company",		Object.Company);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		
		LabelCreditContractInformation = NStr("en = 'Loan amount:'; ru = 'Сумма займа:';pl = 'Kwota pożyczki:';es_ES = 'Importe del préstamo:';es_CO = 'Importe del préstamo:';tr = 'Kredi tutarı:';it = 'Importo del prestito:';de = 'Darlehensbetrag:'") + " " +
			Selection.Total +
			" (" + Selection.Currency + ")";
		
		If Selection.Total < Selection.PrincipalDebtCurReceipt Then
			
			LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Remaining amount to issue: %1 (%2). Issued %3 (%2).'; ru = 'Осталось выдать: %1 (%2). Уже выдано %3 (%2).';pl = 'Kwota pozostała do wydania: %1 (%2). Wydano %3 (%2).';es_ES = 'Importe restante para emitir: %1 (%2). Emitido %3 (%2).';es_CO = 'Importe restante para emitir: %1 (%2). Emitido %3 (%2).';tr = 'Verilecek geriye kalan bakiye: %1 (%2). Düzenleme tarihi %3 (%2).';it = 'Importo rimanente da emettere: %1 (%2). Emesso %3 (%2).';de = 'Verbleibender Ausgabebetrag: %1(%2). Ausgegeben %3(%2).'"),
				Selection.Total - Selection.PrincipalDebtCurReceipt,
				Selection.Currency,
				Selection.PrincipalDebtCurReceipt);
			LabelRemainingDebtByCreditTextColor = StyleColors.SpecialTextColor;
			
		ElsIf Selection.Total = Selection.PrincipalDebtCurReceipt Then
			LabelRemainingDebtByCredit = NStr("en = 'Remaining amount to issue: 0 ('; ru = 'Осталось выдать: 0 (';pl = 'Kwota pozostała do wydania: 0 (';es_ES = 'Importe restante para emitir: 0 (';es_CO = 'Importe restante para emitir: 0 (';tr = 'Verilecek geri kalan tutar: 0 (';it = 'Importo rimanente da emettere: 0 (';de = 'Verbleibender Ausgabebetrag: 0 ('") + Selection.Currency + ").";
			LabelRemainingDebtByCreditTextColor = StyleColors.SpecialTextColor;
		Else
			LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Remaining amount to issue: %1 (%2). Issued %3 (%2).'; ru = 'Осталось выдать: %1 (%2). Уже выдано %3 (%2).';pl = 'Kwota pozostała do wydania: %1 (%2). Wydano %3 (%2).';es_ES = 'Importe restante para emitir: %1 (%2). Emitido %3 (%2).';es_CO = 'Importe restante para emitir: %1 (%2). Emitido %3 (%2).';tr = 'Verilecek geriye kalan bakiye: %1 (%2). Düzenleme tarihi %3 (%2).';it = 'Importo rimanente da emettere: %1 (%2). Emesso %3 (%2).';de = 'Verbleibender Ausgabebetrag: %1(%2). Ausgegeben %3(%2).'"),
				Selection.Total - Selection.PrincipalDebtCurReceipt,
				Selection.Currency,
				Selection.PrincipalDebtCurReceipt);
		EndIf;
			
	Else
		LabelCreditContractInformation = NStr("en = 'Loan amount:'; ru = 'Сумма займа:';pl = 'Kwota pożyczki:';es_ES = 'Importe del préstamo:';es_CO = 'Importe del préstamo:';tr = 'Kredi tutarı:';it = 'Importo del prestito:';de = 'Darlehensbetrag:'") + " " + Object.LoanContract.Total + " (" + Object.LoanContract.SettlementsCurrency + ").";
		LabelRemainingDebtByCredit = NStr("en = 'Remaining amount to issue:'; ru = 'Осталось выдать:';pl = 'Kwota pozostała do wydania:';es_ES = 'Importe restante para emitir:';es_CO = 'Importe restante para emitir:';tr = 'Verilecek geri kalan tutar:';it = 'Importo rimanente da emettere:';de = 'Verbleibender Ausgabebetrag:'") + " " + Object.LoanContract.Total + " (" + Object.LoanContract.SettlementsCurrency + ").";
	EndIf;
	
	Items.LabelCreditContractInformation.Title		= LabelCreditContractInformation;
	Items.LabelRemainingDebtByCredit.Title			= LabelRemainingDebtByCredit;	
	Items.LabelCreditContractInformation.TextColor	= LabelCreditContractInformationTextColor;
	Items.LabelRemainingDebtByCredit.TextColor		= LabelRemainingDebtByCreditTextColor;
	
EndProcedure

&AtServerNoContext
Function GetDefaultLoanContract(Document, Counterparty, Company, OperationKind)
	
	DocumentManager = Documents.LoanContract;
	
	LoanKindList = New ValueList;
	LoanKindList.Add(?(OperationKind = Enums.OperationTypesPaymentExpense.LoanSettlements, 
		Enums.LoanContractTypes.Borrowed,
		Enums.LoanContractTypes.EmployeeLoanAgreement));
	                                                   
	DefaultLoanContract = DocumentManager.ReceiveLoanContractByDefaultByCompanyLoanKind(Counterparty, Company, LoanKindList);
	
	Return DefaultLoanContract;
	
EndFunction

&AtClient
Procedure FillByLoanContract(Command)
	
	If Object.LoanContract.IsEmpty() Then
		ShowMessageBox(Undefined, NStr("en = 'Please select a contract.'; ru = 'Выберите договор.';pl = 'Wybierz umowę.';es_ES = 'Por favor, especifique un contrato.';es_CO = 'Por favor, especifique un contrato.';tr = 'Lütfen, bir sözleşme seçin.';it = 'Si prega di selezionare un contratto.';de = 'Bitte wählen Sie einen Vertrag aus.'"));
		Return;
	EndIf;
	
	FillByLoanContractAtServer();
	DocumentAmountOnChange(Items.DocumentAmount);
	
EndProcedure

&AtClient
Procedure FillByCreditContract(Command)
	
	If Object.LoanContract.IsEmpty() Then
		ShowMessageBox(Undefined, NStr("en = 'Please select a contract.'; ru = 'Выберите договор.';pl = 'Wybierz umowę.';es_ES = 'Por favor, especifique un contrato.';es_CO = 'Por favor, especifique un contrato.';tr = 'Lütfen, sözleşme seçin.';it = 'Si prega di selezionare un contratto.';de = 'Bitte wählen Sie einen Vertrag aus.'"));
		Return;
	EndIf;
	
	PaymentExplanationAddressInStorage = PlacePaymentDetailsToStorage();
	FilterParameters = New Structure("
		|PaymentExplanationAddressInStorage,
		|Company,
		|Recorder,
		|DocumentFormID,
		|OperationKind,
		|Date,
		|Currency,
		|LoanContract,
		|DocumentAmount,
		|Counterparty,
		|DefaultVATRate,
		|PaymentAmount,
		|Rate,
		|Multiplicity,
		|Employee",
		PaymentExplanationAddressInStorage,
		Object.Company,
		Object.Ref,
		UUID,
		Object.OperationKind,
		Object.Date,
		Object.CashCurrency,
		Object.LoanContract,
		Object.DocumentAmount,
		Object.Counterparty,
		DefaultVATRate,
		Object.PaymentDetails.Total("PaymentAmount"),
		Object.ExchangeRate,
		Object.Multiplicity,
		Object.AdvanceHolder);
	
	OpenForm("CommonForm.LoanRepaymentDetails", 
		FilterParameters,
		ThisObject,,,,
		New NotifyDescription("FillByCreditContractEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure FillByCreditContractEnd(FillingResult, CompletionParameters) Export

	If TypeOf(FillingResult) = Type("Structure") Then
		
		FillDocumentAmount = False;
		
		If FillingResult.Property("ClearTabularSectionOnPopulation") AND FillingResult.ClearTabularSectionOnPopulation Then
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

&AtServer
Procedure FillByLoanContractAtServer()
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	LoanSettlementsTurnovers.LoanContract.SettlementsCurrency AS Currency,
	|	LoanSettlementsTurnovers.PrincipalDebtCurReceipt,
	|	NULL AS Field1
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
	|	NULL,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
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
	|	SUM(TemporaryTableAmountsIssuedBefore.PrincipalDebtCurReceipt) AS PrincipalDebtCurReceipt,
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
	Query.SetParameter("Company",		Object.Company);
	Query.SetParameter("Ref",			Object.Ref);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		
		Object.CashCurrency = Selection.Currency;
		MessageText = "";
		
		If Selection.Total < Selection.PrincipalDebtCurReceipt Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Issued under the loan contract %1 (%2).'; ru = 'По договору займа уже выдано %1 (%2).';pl = 'Wydano według umowy pożyczki %1 (%2).';es_ES = 'Emitido bajo el contrato de préstamo%1 (%2).';es_CO = 'Emitido bajo el contrato de préstamo%1 (%2).';tr = 'Kredi sözleşmesi kapsamında verilen %1(%2).';it = 'Emesso in base a contratto di prestito %1 (%2)';de = 'Ausgestellt unter dem Darlehensvertrag %1 (%2)'"),
				Selection.PrincipalDebtCurReceipt,
				Selection.Currency);
		ElsIf Selection.Total = Selection.PrincipalDebtCurReceipt Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The complete amount has been already issued under the loan contract %1 (%2).'; ru = 'По договору займа уже выдана вся сумма %1 (%2).';pl = 'Cała kwota w ramach umowy pożyczki została już wydana %1 (%2).';es_ES = 'El importe completo se ha emitido bajo el contrato de préstamo %1 (%2).';es_CO = 'El importe completo se ha emitido bajo el contrato de préstamo %1 (%2).';tr = 'Toplam tutar önceden kredi sözleşmesi kapsamında %1 (%2) zaten verildi:';it = 'L''importo completo è già stato emesso in base al contratto di prestito %1 (%2)';de = 'Der gesamte Betrag wurde bereits im Rahmen des Darlehensvertrags %1 (%2) ausgegeben.'"),
				Selection.PrincipalDebtCurReceipt,
				Selection.Currency);
		Else
			Object.DocumentAmount = Selection.Total - Selection.PrincipalDebtCurReceipt;
		EndIf;
		
		If MessageText <> "" Then
			CommonClientServer.MessageToUser(MessageText,, "LoanContract");
		EndIf;
		
	Else
		Object.DocumentAmount = Object.LoanContract.Total;
		Object.CashCurrency = Object.LoanContract.SettlementsCurrency;
	EndIf;
	
	Modified = True;
	
EndProcedure

&AtServerNoContext
Function GetEmployeeDataOnChange(Employee, Date, Company)
	
	DataStructure = New Structure;
	
	DataStructure.Insert("LoanContract", Documents.LoanContract.ReceiveLoanContractByDefaultByCompanyLoanKind(Employee, Company));
	
	Return DataStructure;
	
EndFunction

&AtClient
Procedure EmployeeLoanAgreementOnChange(Item)
	HandleLoanContractChange();
EndProcedure

&AtClient
Procedure SettlementsOnCreditsPaymentDetailsTypeOfAmountOnChange(Item)
	
	If ValueIsFilled(Object.LoanContract) Then
		RowData = Items.SettlementsOnCreditsPaymentDetails.CurrentData;
		If ValueIsFilled(RowData.TypeOfAmount) Then
			RowData.Item = GetLoanContractItemByTypeOfAmount(Object.LoanContract, RowData.TypeOfAmount);
		EndIf;
	EndIf;
	
EndProcedure

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

#EndRegion

#EndRegion

#Region Private

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

&AtClient
Procedure SetMarkIncompletePaymentDate()
	
	If Object.ForOpeningBalancesOnly Then
		
		Items.PaymentDate.AutoMarkIncomplete	= False;
		
	Else
		
		If Not Object.Paid Then
			
			Items.PaymentDate.AutoMarkIncomplete	= Object.Paid;
			Items.PaymentDate.MarkIncomplete		= Object.Paid;
			
		Else
			
			Items.PaymentDate.AutoMarkIncomplete = Undefined;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetRefAttributes(Ref, StringAttributes)
	
	Return DriveServer.GetRefAttributes(Ref, StringAttributes);
	
EndFunction

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
	
	IsOtherOperation = (OperationKind = Enums.OperationTypesPaymentExpense.Other);
	
	IncomeAndExpenseItemsVisibility = 
		IsOtherOperation
		And (Not UseDefaultTypeOfAccounting Or GLAccountsInDocuments.IsIncomeAndExpenseGLA(Object.Correspondence));
	
	IncomeAndExpenseItemsInDocuments.SetRegistrationAttributesVisibility(
		ThisObject, 
		"RegisterExpense", 
		IsOtherOperation And Not UseDefaultTypeOfAccounting);
		
EndProcedure

&AtClient
Procedure IncomeAndExpenseItemsOnChangeConditions()
	
	Items.ExpenseItem.TitleLocation = ?(
		UseDefaultTypeOfAccounting, FormItemTitleLocation.Auto, FormItemTitleLocation.None);
		
	Items.ExpenseItem.Visible = IncomeAndExpenseItemsVisibility;
	Items.ExpenseItem.Enabled = Object.RegisterExpense;
	
EndProcedure

&AtServer
Procedure SetVisibilityAmountAttributes()
	
	IsReadonly = (Object.CashCurrency = PresentationCurrency);
	
	Items.TaxesSettlementsExchangeRate.ReadOnly = IsReadonly;
	Items.TaxesSettlementsMultiplicity.ReadOnly = IsReadonly;
	Items.TaxesSettlementsAccountingAmount.ReadOnly = IsReadonly;
	Items.OtherSettlementsExchangeRate.ReadOnly = IsReadonly;
	Items.OtherSettlementsMultiplicity.ReadOnly = IsReadonly;
	Items.OtherSettlementsAccountingAmount.ReadOnly = IsReadonly;
	
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

&AtClient
Procedure EmployeeGLAccountsChoiceProcessing(StructureData);
	
	FillPropertyValues(Object, StructureData);
	
	GLAccounts = GetEmployeeGLAccountsDescription(StructureData);
	
EndProcedure

&AtServerNoContext
Function GetEmployeeGLAccountsDescription(StructureData)
	
	GLAccountsInDocumentsServerCall.GetGLAccountsDescription(StructureData);
	
	Return StructureData.GLAccounts;
	
EndFunction

&AtClientAtServerNoContext
Function EmployeeGLAccountsStructure(DocObject)
	
	StructureData = New Structure("AdvanceHoldersReceivableGLAccount, AdvanceHoldersPayableGLAccount");
	
	FillPropertyValues(StructureData, DocObject);
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure EmployeeOnChangeAtServer()
	
	If OperationKind = Enums.OperationTypesPaymentExpense.ToAdvanceHolder Then
		
		DocumentObject = FormAttributeToValue("Object");
		DocumentObject.FillInEmployeeGLAccounts();
		ValueToFormAttribute(DocumentObject, "Object");
		
		If UseDefaultTypeOfAccounting Then
			StructureForFilling = EmployeeGLAccountsStructure(Object);
			GLAccounts = GetEmployeeGLAccountsDescription(StructureForFilling);
		EndIf;
		
		Modified = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion