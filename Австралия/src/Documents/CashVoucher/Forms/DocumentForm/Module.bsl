
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.CheckBasis(Object, Parameters.Basis, Cancel);
	UseForeignCurrency = GetFunctionalOption("ForeignExchangeAccounting");
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues);
		
	DefaultIncomeItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("DiscountReceived");
	
	If Object.PaymentDetails.Count() = 0
		And Object.OperationKind <> Enums.OperationTypesCashVoucher.Salary Then
		
		Object.PaymentDetails.Add();
		Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		
		If Object.OperationKind = Enums.OperationTypesPaymentExpense.Vendor Then
			Object.PaymentDetails[0].DiscountReceivedIncomeItem = DefaultIncomeItem;
		EndIf;
		
	EndIf;
	
	// FO Use Payroll subsystem.
	SetVisibleByFOUseSubsystemPayroll();
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	SetAccountingPolicyValues();
	
	DocumentObject = FormAttributeToValue("Object");
	If DocumentObject.IsNew()
	AND Not ValueIsFilled(Parameters.CopyingValue) Then
		If ValueIsFilled(Parameters.BasisDocument) Then
			DocumentObject.Fill(Parameters.BasisDocument);
			ValueToFormAttribute(DocumentObject, "Object");
		EndIf;
		If Not ValueIsFilled(Object.PettyCash) Then
			Object.PettyCash = Catalogs.CashAccounts.GetPettyCashByDefault(Object.Company);
			Object.CashCurrency = ?(ValueIsFilled(Object.PettyCash.CurrencyByDefault), Object.PettyCash.CurrencyByDefault, Object.CashCurrency);
		EndIf;
		If ValueIsFilled(Object.Counterparty)
		   AND Object.PaymentDetails.Count() > 0
		AND Not ValueIsFilled(Parameters.BasisDocument) Then
			If Not ValueIsFilled(Object.PaymentDetails[0].Contract) Then
				Object.PaymentDetails[0].Contract = DriveServer.GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
			EndIf;
			If ValueIsFilled(Object.PaymentDetails[0].Contract) Then
				ContractCurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(DocumentDate, Object.PaymentDetails[0].Contract.SettlementsCurrency, Object.Company);
				Object.PaymentDetails[0].ExchangeRate = ?(ContractCurrencyRateRepetition.Rate = 0, 1, ContractCurrencyRateRepetition.Rate);
				Object.PaymentDetails[0].Multiplicity = ?(ContractCurrencyRateRepetition.Repetition = 0, 1, ContractCurrencyRateRepetition.Repetition);
			EndIf;
		EndIf;
		SetCFItem();
	EndIf;
	
	// Form attributes setting.
	ParentCompany = DriveServer.GetCompany(Object.Company);
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(DocumentDate, Object.CashCurrency, Object.Company);
	ExchangeRateMethod = DriveServer.GetExchangeMethod(ParentCompany);
	ExchangeRate = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Rate);
		
	Multiplicity = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Repetition);
	
	StructuralUnitDepartment = Catalogs.BusinessUnits.MainDepartment;
	
	SupplementOperationTypesChoiceList();
	
	If Not ValueIsFilled(Object.Ref)
		And Not ValueIsFilled(Parameters.Basis)
		And Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	EndIf;
	
	SetVisibleOfVATTaxation();
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(DocumentDate, Object.Company);
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
		DefaultVATRate = Catalogs.VATRates.Exempt;
	Else
		DefaultVATRate = Catalogs.VATRates.ZeroRate;
	EndIf;
	
	OperationKind = Object.OperationKind;
	CashCurrency = Object.CashCurrency;
	
	PrintReceiptEnabled = False;
	
	Button = Items.Find("PrintReceipt");
	If Button <> Undefined Then
		
		If Object.OperationKind = Enums.OperationTypesCashVoucher.ToCustomer
		   AND GetFunctionalOption("UsePeripherals") Then
			PrintReceiptEnabled = True;
		EndIf;
		
		Button.Enabled = PrintReceiptEnabled;
		Items.Decoration4.Visible = PrintReceiptEnabled;
		Items.SalesSlipNumber.Visible = PrintReceiptEnabled;
		
	EndIf;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			False);
	ParametersStructure.Insert("FillHeader",			True);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	StructureForFilling = EmployeeGLAccountsStructure(Object);
	GLAccounts = GetEmployeeGLAccountsDescription(StructureForFilling);
	
	Items.PaymentDetailsGLAccounts.Visible = UseDefaultTypeOfAccounting;
	
	SetIncomeAndExpenseItemsVisibility();
	
	ProcessingCompanyVATNumbers();
	
	SetVisibilityAttributesDependenceOnCorrespondence();
	SetVisibilityItemsDependenceOnOperationKind();
	
	RegistrationPeriodPresentation = Format(Object.RegistrationPeriod, "DF='MMMM yyyy'");
	
	// Fill in tabular section while entering a document from the working place.
	If TypeOf(Parameters.FillingValues) = Type("Structure")
		And Parameters.FillingValues.Property("FillDetailsOfPayment")
		And Parameters.FillingValues.FillDetailsOfPayment Then
		
		TabularSectionRow = Object.PaymentDetails[0];
		
		TabularSectionRow.PaymentAmount = Object.DocumentAmount;
		TabularSectionRow.ExchangeRate = ?(
			TabularSectionRow.ExchangeRate = 0,
			1,
			TabularSectionRow.ExchangeRate
		);
		
		TabularSectionRow.Multiplicity = ?(
			TabularSectionRow.Multiplicity = 0,
			1,
			TabularSectionRow.Multiplicity
		);
		
		TabularSectionRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
			TabularSectionRow.PaymentAmount,
			ExchangeRateMethod,
			ExchangeRate,
			TabularSectionRow.ExchangeRate,
			Multiplicity,
			TabularSectionRow.Multiplicity
		);
		
		If Not ValueIsFilled(TabularSectionRow.VATRate) Then
			TabularSectionRow.VATRate = DefaultVATRate;
		EndIf;
		
		TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount - (TabularSectionRow.PaymentAmount) / ((TabularSectionRow.VATRate.Rate + 100) / 100);
		
	EndIf;
	
	SetVisibilitySettlementAttributes();
	SetVisibilityEPDAttributes();
	SetConditionalAppearance();
	
	CurrentSystemUser = UsersClientServer.CurrentUser();
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
	
	WorkWithVAT.SetTextAboutAdvancePaymentInvoiceReceived(ThisObject);
	
	SetTaxInvoiceText();
	
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
	SetVisibleCommandFillByBasis();
	IncomeAndExpenseItemsOnChangeConditions();
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ChoiceSource) = Type("ClientApplicationForm")
		AND Find(ChoiceSource.FormName, "Calendar") > 0 Then
		
		Object.RegistrationPeriod = EndOfDay(ValueSelected);
		DriveClient.OnChangeRegistrationPeriod(ThisForm);
		
	EndIf;
	
	If ChoiceSource.FormName = "Document.TaxInvoiceReceived.Form.DocumentForm" Then
		
		TaxInvoiceText = ValueSelected;
		
	ElsIf GLAccountsInDocumentsClient.IsGLAccountsChoiceProcessing(ChoiceSource.FormName) Then
		
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, ValueSelected);
				
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, ValueSelected);
		
	ElsIf ChoiceSource.FormName = "Catalog.Employees.Form.EmployeeGLAccounts" Then
		
		EmployeeGLAccountsChoiceProcessing(ValueSelected);
		
	EndIf;
	
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
		CheckContractToDocumentConditionAccordance(
			Object.PaymentDetails,
			MessageText,
			Object.Ref,
			Object.Company,
			Object.Counterparty,
			Object.OperationKind,
			Cancel,
			Object.LoanContract);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("en = 'The cash payment is not posted.'; ru = 'Наличный платеж не проведен.';pl = 'Płatność gotówkowa nie jest zatwierdzona.';es_ES = 'El pago en efectivo no se ha enviado.';es_CO = 'El pago en efectivo no se ha enviado.';tr = 'Nakit ödeme gönderilmedi.';it = 'Il pagamento di cassa non è stato pubblicato.';de = 'Die Barzahlung wird nicht gebucht.'") + " " + MessageText, MessageText);
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
			ValueIsFilled(CurRow.Order)
		);
	EndDo;
	
	If NotifyAboutOrderPayment Then
		Notify("NotificationAboutOrderPayment");
	EndIf;
	
	Notify("NotificationAboutChangingDebt");
	
	// CWP
	If TypeOf(FormOwner) = Type("ClientApplicationForm")
		AND Find(FormOwner.FormName, "DocumentForm_CWP") > 0 
		Then
		Notify("CWP_Record_CPV", New Structure("Ref, Number, Date, OperationKind", Object.Ref, Object.Number, Object.Date, Object.OperationKind));
	EndIf;
	// End CWP
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If CurrentObject.OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToEmployee
		OR CurrentObject.OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToCounterparty
		OR CurrentObject.OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements Then
			FillCreditLoanInformationAtServer();
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

#EndRegion

#Region FormHeaderItemsEventHandlers

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
		
		Correspondence = Object.Correspondence;
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Other") Then
			
			Structure = New Structure("Object, Correspondence, ExpenseItem, Manual");
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
	
	SetIncomeAndExpenseItemsVisibility();
	SetVisibilityAttributesDependenceOnCorrespondence();
	
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

#EndRegion

#Region FormItemEventHandlersTablePaymentDetails

&AtClient
Procedure PaymentDetailsOtherSettlementsBeforeDeleteRow(Item, Cancel)
	
	If Object.PaymentDetails.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsAfterDeleteRow(Item)
	
	If Object.PaymentDetails.Count() = 1 Then
		SetCurrentPage();
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
		
	CalculatePaymentAmountAtClient(Items.PaymentDetailsOtherSettlements.CurrentData);
	
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsExchangeRateOnChange(Item)
		
	CalculatePaymentAmountAtClient(Items.PaymentDetailsOtherSettlements.CurrentData);
	
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsMultiplicityOnChange(Item)
		
	CalculatePaymentAmountAtClient(Items.PaymentDetailsOtherSettlements.CurrentData);
	
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsPaymentAmountOnChange(Item)
	
	TablePartRow = Items.PaymentDetailsOtherSettlements.CurrentData;
	
	TablePartRow.ExchangeRate = ?(
		TablePartRow.ExchangeRate = 0,
		1,
		TablePartRow.ExchangeRate
	);
	TablePartRow.Multiplicity = ?(
		TablePartRow.Multiplicity = 0,
		1,
		TablePartRow.Multiplicity
	);
	
	TablePartRow.ExchangeRate = ?(
		TablePartRow.SettlementsAmount = 0,
		1,
		TablePartRow.PaymentAmount / TablePartRow.SettlementsAmount * ExchangeRate
	);
	
	If Not ValueIsFilled(TablePartRow.VATRate) Then
		TablePartRow.VATRate = DefaultVATRate;
	EndIf;
	
	CalculateVATAmountAtClient(TablePartRow);
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsVATRateOnChange(Item)
	
	TablePartRow = Items.PaymentDetailsOtherSettlements.CurrentData;
	CalculateVATAmountAtClient(TablePartRow);

EndProcedure

#EndRegion

#Region Private

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

#Region GLAccounts

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
		Object.Correspondence = ChartsOfAccounts.PrimaryChartOfAccounts.FindByCode(StructureData.GLAccounts);
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
	
	If OperationKind = Enums.OperationTypesCashVoucher.ToAdvanceHolder Then
		
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

&AtClient
Procedure CalculatePaymentAmountAtClient(TablePartRow, ColumnName = "")
	
	StructureData = GetDataPaymentDetailsContractOnChange(
			Object.Date,
			TablePartRow.Contract);
		
	TablePartRow.ExchangeRate = ?(
		TablePartRow.ExchangeRate = 0,
		?(StructureData.ContractCurrencyRateRepetition.ExchangeRate =0, 1, StructureData.ContractCurrencyRateRepetition.ExchangeRate),
		TablePartRow.ExchangeRate);
	TablePartRow.Multiplicity = ?(
		TablePartRow.Multiplicity = 0,
		1,
		TablePartRow.Multiplicity);
	
	If TablePartRow.SettlementsAmount = 0 Then
		TablePartRow.PaymentAmount = 0;
		TablePartRow.ExchangeRate = StructureData.ContractCurrencyRateRepetition.ExchangeRate;
	ElsIf Object.CashCurrency = StructureData.SettlementsCurrency Then
		TablePartRow.PaymentAmount = TablePartRow.SettlementsAmount;
	ElsIf TablePartRow.PaymentAmount = 0 
		OR ColumnName = "ExchangeRate" 
		OR ColumnName = "Multiplicity" Then
		
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
			StructureData.ContractCurrencyRateRepetition.ExchangeRate, //TablePartRow.ExchangeRate,
			TablePartRow.PaymentAmount / TablePartRow.SettlementsAmount * ExchangeRate);
		TablePartRow.Multiplicity = ?(
			TablePartRow.SettlementsAmount = 0 OR TablePartRow.PaymentAmount = 0,
			StructureData.ContractCurrencyRateRepetition.Multiplicity,
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
Function GetDataPaymentDetailsContractOnChange(Date, Contract, StructureData = Undefined, PlanningDocument = Undefined)
	
	If StructureData = Undefined Then
		StructureData = New Structure;
	EndIf;
	
	NameCashFlowItem = "CashFlowItem";
	
	If TypeOf(Contract) = Type("DocumentRef.LoanContract") Then
		NameCashFlowItem = "PrincipalItem";
	EndIf;
	
	ContractData = Common.ObjectAttributesValues(Contract, "SettlementsCurrency, " + NameCashFlowItem);
	
	StructureData.Insert("Item", ContractData[NameCashFlowItem]);
	
	StructureData.Insert(
		"ContractCurrencyRateRepetition",
		CurrencyRateOperations.GetCurrencyRate(Date, ContractData.SettlementsCurrency, Object.Company));
	StructureData.Insert("SettlementsCurrency", ContractData.SettlementsCurrency);
	
	If UseDefaultTypeOfAccounting And StructureData.Property("GLAccounts") Then
		GLAccountsInDocuments.FillCounterpartyGLAccounts(StructureData);
	EndIf;
	
	IncomeAndExpenseItemsInDocuments.SetConditionalAppearance(ThisObject, "PaymentDetails");
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure OperationKindOnChangeAtServer(FillTaxation = True)
	
	SetChoiceParameterLinksAvailableTypes();
	
	SetVisibilityPrintReceipt();
	
	If Object.OperationKind = Enums.OperationTypesCashVoucher.OtherSettlements Then
		DefaultVATRate						= Catalogs.VATRates.Exempt;
		DefaultVATRateNumber				= DriveReUse.GetVATRateValue(DefaultVATRate);
		Object.PaymentDetails[0].VATRate	= DefaultVATRate;

	ElsIf FillTaxation Then
		FillVATRateByCompanyVATTaxation();
	EndIf;
	
	EmployeeOnChangeAtServer();
	
	SetVisibleOfVATTaxation();
	SetIncomeAndExpenseItemsVisibility();
	SetVisibilityItemsDependenceOnOperationKind();
	SetVisibilityEPDAttributes();
	SetCFItemWhenChangingTheTypeOfOperations();
	SetVisibilityDebitNoteText();
	
EndProcedure

&AtClient
Procedure ProcessOnChangeCounterpartyContractOtherSettlements()
	
	TablePartRow = Items.PaymentDetailsOtherSettlements.CurrentData;
	
	If ValueIsFilled(TablePartRow.Contract) Then
		StructureData = GetDataPaymentDetailsContractOnChange(
			Object.Date,
			TablePartRow.Contract,
			,
			TablePartRow.PlanningDocument);
		TablePartRow.ExchangeRate = ?(
			StructureData.ContractCurrencyRateRepetition.Rate = 0,
			1,
			StructureData.ContractCurrencyRateRepetition.Rate);
		TablePartRow.Multiplicity = ?(
			StructureData.ContractCurrencyRateRepetition.Repetition = 0,
			1,
			StructureData.ContractCurrencyRateRepetition.Repetition);
		
	EndIf;
	
	TablePartRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TablePartRow.PaymentAmount,
		ExchangeRateMethod,
		ExchangeRate,
		TablePartRow.ExchangeRate,
		Multiplicity,
		TablePartRow.Multiplicity);
	
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

&AtClient
Procedure RecalculationOnChangeCashAssetsCurrency()
	
	If Object.PaymentDetails.Count() > 0
		And Object.OperationKind <> PredefinedValue("Enum.OperationTypesCashVoucher.Salary") Then
		
		RecalculateDocumentAmounts(ExchangeRate, Multiplicity, False);
		
	EndIf;

EndProcedure

&AtServer
Procedure SetChoiceParametersForAccountingOtherSettlementsAtServerForAccountItem()

	If Not UseDefaultTypeOfAccounting Then 
		Return;
	EndIf;
	
	Item = Items.SettlementsOtherCorrespondence;
	
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

	Item = Items.SettlementsOtherCorrespondence;
	
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
		
		Items.Department.Visible = True;
		
		If Object.OperationKind = Enums.OperationTypesCashVoucher.OtherSettlements Then
			Object.BusinessLine			= Undefined;
			Object.Order				= Undefined;
			Items.BusinessLine.Visible	= False;
			Items.Order.Visible			= False;
		Else 
			Items.BusinessLine.Visible	= True;
			Items.Order.Visible			= True;
		EndIf;
		
		If Not ValueIsFilled(Object.Department) Then
			SettingValue	= DriveReUse.GetValueByDefaultUser(CurrentSystemUser, "MainDepartment");
			Object.Department	= ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
		EndIf;

		Items.PaymentDetailsProject.Visible = (Object.OperationKind = Enums.OperationTypesCashVoucher.Other);
		Items.PaymentDetailsOtherSettlementsProject.Visible = 
			(Object.OperationKind = Enums.OperationTypesCashVoucher.OtherSettlements);
	
	ElsIf ExpenseItemType = Catalogs.IncomeAndExpenseTypes.OtherExpenses Then
		
		Items.PaymentDetailsProject.Visible = (Object.OperationKind = Enums.OperationTypesCashVoucher.Other);
		Items.PaymentDetailsOtherSettlementsProject.Visible = 
			(Object.OperationKind = Enums.OperationTypesCashVoucher.OtherSettlements);
	
	Else
		
		If Object.OperationKind <> Enums.OperationTypesCashVoucher.Taxes // for entering based on
			And Object.OperationKind <> Enums.OperationTypesCashVoucher.SalaryForEmployee Then
			
			Object.BusinessLine	= Undefined;
		EndIf;
		
		If Not FunctionalOptionAccountingCashMethodIncomeAndExpenses
			And (Object.OperationKind = Enums.OperationTypesCashVoucher.Taxes
				Or Object.OperationKind = Enums.OperationTypesCashVoucher.SalaryForEmployee) Then
				
			Object.BusinessLine	= Undefined;
		EndIf;
		
		If Object.OperationKind = Enums.OperationTypesCashVoucher.Other
			Or Object.OperationKind = Enums.OperationTypesCashVoucher.OtherSettlements Then
			
			Object.Department	= Undefined;
		EndIf;
		
		Object.Order = Undefined;
		
		Items.BusinessLine.Visible = False;
		Items.Department.Visible = False;
		Items.Order.Visible = False;
		Items.PaymentDetailsProject.Visible = False;
		Items.PaymentDetailsOtherSettlementsProject.Visible = False;
		
	EndIf;
	
	SetVisibilityPlanningDocument();
	
EndProcedure

&AtServer
Procedure SetVisibilityItemsDependenceOnOperationKind()
	
	Items.PaymentDetailsPaymentAmount.Visible					= UseForeignCurrency;
	Items.PaymentDetailsOtherSettlementsPaymentAmount.Visible	= UseForeignCurrency;
	Items.SettlementsOnCreditsPaymentDetailsPaymentAmount.Visible = UseForeignCurrency;
	
	Items.SettlementsWithCounterparty.Visible	= False;
	Items.SettlementsWithAdvanceHolder.Visible	= False;
	Items.SalaryPayToEmployee.Visible			= False;
	Items.Payroll.Visible						= False;
	Items.TaxesSettlements.Visible				= False;
	Items.OtherSettlements.Visible				= False;
	Items.TransferToCashCR.Visible				= False;
	
	Items.DocumentAmount.Width	= 14;
	
	Items.AdvanceHolder.Visible	= False;
	Items.Counterparty.Visible	= False;
	
	Items.LoanSettlements.Visible			= False;
	Items.EmployeeLoanAgreement.Visible		= False;
	Items.FillByLoanContract.Visible		= False;
	Items.CreditContract.Visible			= False;
	Items.FillByCreditContract.Visible		= False;
	Items.GroupContractInformation.Visible	= False;
	Items.AdvanceHolder.Visible				= False;
	Items.Item.Visible						= True;
	Items.PaymentDetailsItem.Visible		= False;
	Items.PaymentDetailsSignAdvance.Visible = True;
	
	DocMetadata = Metadata.Documents.CashVoucher;
	
	BasisDocumentTypes = DocMetadata.Attributes.BasisDocument.Type;
	Items.BasisDocument.TypeRestriction = New TypeDescription(BasisDocumentTypes, , "DocumentRef.CashTransferPlan");
	
	PlanningDocumentTypes = DocMetadata.TabularSections.PaymentDetails.Attributes.PlanningDocument.Type;
	PlanningDocumentTypeRestriction = New TypeDescription(PlanningDocumentTypes, , "DocumentRef.CashTransferPlan");
	Items.PaymentDetailsPlanningDocument.TypeRestriction = PlanningDocumentTypeRestriction;
	Items.PaymentDetailsOtherSettlementsPlanningDocument.TypeRestriction = PlanningDocumentTypeRestriction;
	Items.AdvanceHoldersPaymentAccountDetailsForPayment.TypeRestriction = PlanningDocumentTypeRestriction;
	Items.SettlementsOnCreditsPaymentDetailsPlanningDocument.TypeRestriction = PlanningDocumentTypeRestriction;
	
	If OperationKind = Enums.OperationTypesCashVoucher.Vendor Then
		
		Items.SettlementsWithCounterparty.Visible	= True;
		Items.PaymentDetailsPickup.Visible			= True;
		Items.PaymentDetailsFillDetails.Visible		= True;
		
		SetChoiceParametersForCounterparty("Supplier");
		
		Items.Counterparty.Visible	= True;
		Items.Counterparty.Title	= NStr("en = 'Supplier'; ru = 'Поставщик';pl = 'Dostawca';es_ES = 'Proveedor';es_CO = 'Proveedor';tr = 'Tedarikçi';it = 'Fornitore';de = 'Lieferant'");
		
		Items.PaymentAmount.Visible		= True;
		Items.PaymentAmount.Title		= NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'");
		Items.SettlementsAmount.Visible = Not UseForeignCurrency;
		
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
		Items.Item.Visible					= False;
		Items.PaymentDetailsItem.Visible	= True;
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.ToCustomer Then
		
		Items.SettlementsWithCounterparty.Visible	= True;
		Items.PaymentDetailsPickup.Visible			= False;
		Items.PaymentDetailsFillDetails.Visible		= True;
		
		SetChoiceParametersForCounterparty("Customer");
		
		Items.Counterparty.Visible	= True;
		Items.Counterparty.Title	= NStr("en = 'Customer'; ru = 'Покупатель';pl = 'Nabywca';es_ES = 'Cliente';es_CO = 'Cliente';tr = 'Müşteri';it = 'Cliente';de = 'Kunde'");
		
		Items.PaymentAmount.Visible		= True;
		Items.PaymentAmount.Title		= NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'");
		Items.SettlementsAmount.Visible = Not UseForeignCurrency;
		
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
		Items.Item.Visible					= False;
		Items.PaymentDetailsItem.Visible	= True;
		Items.PaymentDetailsSignAdvance.Visible = False;
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.ToAdvanceHolder Then
		
		Items.SettlementsWithAdvanceHolder.Visible	= True;
		Items.AdvanceHolder.Visible					= True;
		Items.AdvanceHolder.Title					= NStr("en = 'Advance holder'; ru = 'Подотчетное лицо';pl = 'Zaliczkobiorca';es_ES = 'Titular de anticipo';es_CO = 'Titular de anticipo';tr = 'Avans sahibi';it = 'Persona che ha anticipato';de = 'Abrechnungspflichtige Person'");
		Items.DocumentAmount.Width					= 13;
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"), NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'"), NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'"));
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.SalaryForEmployee Then
		
		Items.SalaryPayToEmployee.Visible	= True;
		Items.AdvanceHolder.Visible			= True;
		Items.AdvanceHolder.Title			= NStr("en = 'Employee'; ru = 'Сотрудник';pl = 'Pracownik';es_ES = 'Empleado';es_CO = 'Empleado';tr = 'Çalışan';it = 'Dipendente';de = 'Mitarbeiter'");
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"), NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'"), NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'"));
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		
		Items.EmployeeSalaryPayoffBusinessLine.Visible = FunctionalOptionAccountingCashMethodIncomeAndExpenses;
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.Salary Then
		
		Items.Payroll.Visible	= True;
		
		Items.PaymentAmount.Visible						= False;
		Items.SettlementsAmount.Visible					= False;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= True;
		
		Items.SalaryPayoffBusinessLine.Visible = FunctionalOptionAccountingCashMethodIncomeAndExpenses;
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.Taxes Then
		
		Items.TaxesSettlements.Visible	= True;
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"), NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'"), NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'"));
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		
		Items.Counterparty.Visible	= True;
		Items.Counterparty.Title	= NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'");

		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
		Items.BusinessLineTaxes.Visible = FunctionalOptionAccountingCashMethodIncomeAndExpenses;
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.TransferToCashCR Then
		
		Items.TransferToCashCR.Visible = True;
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"), NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'"), NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'"));
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
		Items.BasisDocument.TypeRestriction = New TypeDescription;
		Items.PaymentDetailsPlanningDocument.TypeRestriction = New TypeDescription;
		Items.PaymentDetailsOtherSettlementsPlanningDocument.TypeRestriction = New TypeDescription;
		Items.AdvanceHoldersPaymentAccountDetailsForPayment.TypeRestriction = New TypeDescription;
		Items.SettlementsOnCreditsPaymentDetailsPlanningDocument.TypeRestriction = New TypeDescription;
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.Other Then
		
		Items.OtherSettlements.Visible	= True;
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"), 
			NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'"), 
			NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'"));
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;		
		Items.PaymentDetailsOtherSettlements.Visible	= False;
		SetVisibilityAttributesDependenceOnCorrespondence();
		
		Items.Counterparty.Visible	= True;
		Items.Counterparty.Title	= NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'");
		Items.Counterparty.AutoMarkIncomplete	= False;
		Items.Counterparty.MarkIncomplete		= False;

		Items.BasisDocument.TypeRestriction = New TypeDescription;
		Items.PaymentDetailsPlanningDocument.TypeRestriction = New TypeDescription;
		Items.PaymentDetailsOtherSettlementsPlanningDocument.TypeRestriction = New TypeDescription;
		Items.AdvanceHoldersPaymentAccountDetailsForPayment.TypeRestriction = New TypeDescription;
		Items.SettlementsOnCreditsPaymentDetailsPlanningDocument.TypeRestriction = New TypeDescription;
		
		Items.SettlementsOtherCorrespondence.Title = NStr("en = 'Expense account'; ru = 'Счет расходов';pl = 'Konto rozchodów';es_ES = 'Cuenta de gastos';es_CO = 'Cuenta de gastos';tr = 'Gider hesabı';it = 'Conto uscita';de = 'Ausgabenkonto'");
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.OtherSettlements Then
		
		Items.OtherSettlements.Visible	= True;
		
		Items.PaymentAmount.Visible			= False;
		Items.PaymentAmount.Title			= NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'");
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
		SetChoiceParametersForCounterparty("OtherRelationship");
		
		Items.Counterparty.Visible	= True;
		Items.Counterparty.Title	= NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'");
		
		Items.PaymentDetailsOtherSettlements.Visible	= True;
		Items.PaymentDetailsOtherSettlementsContract.Visible = Object.Counterparty.DoOperationsByContracts;
		SetVisibilityAttributesDependenceOnCorrespondence();
		
		Items.SettlementsOtherCorrespondence.Title = NStr("en = 'Debit account'; ru = 'Дебетовый счет';pl = 'Konto debetowe';es_ES = 'Cuenta de débito';es_CO = 'Cuenta de débito';tr = 'Borç hesabı';it = 'Conto debito';de = 'Soll-Konto'");
		
		If Object.PaymentDetails.Count() > 0 Then
			ID = Object.PaymentDetails[0].GetID();
			Items.PaymentDetailsOtherSettlements.CurrentRow = ID;
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToEmployee Then
		
		Items.AdvanceHolder.Visible							= True;
		Items.AdvanceHolder.Title							= NStr("en = 'Borrower'; ru = 'Заемщик';pl = 'Pożyczkobiorca';es_ES = 'Prestatario';es_CO = 'Prestatario';tr = 'Borçlanan';it = 'Mutuatario';de = 'Darlehensnehmer'");
		Items.LoanSettlements.Visible						= True;
		Items.SettlementsOnCreditsPaymentDetails.Visible	= False;
		
		Items.EmployeeLoanAgreement.Visible = True;
		Items.FillByLoanContract.Visible	= True;
		
		FillCreditLoanInformationAtServer();
		SetCFItem();
		
		Items.GroupContractInformation.Visible = True;
		
		Items.PaymentAmount.Visible						= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title						= NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'");
		Items.PaymentAmountCurrency.Visible				= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible					= False;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToCounterparty Then
		
		SetChoiceParametersForCounterparty("OtherRelationship");
		
		Items.Counterparty.Visible							= True;
		Items.Counterparty.Title							= NStr("en = 'Borrower'; ru = 'Заемщик';pl = 'Pożyczkobiorca';es_ES = 'Prestatario';es_CO = 'Prestatario';tr = 'Borçlanan';it = 'Mutuatario';de = 'Darlehensnehmer'");
		Items.LoanSettlements.Visible						= True;
		Items.SettlementsOnCreditsPaymentDetails.Visible	= False;
		
		Items.EmployeeLoanAgreement.Visible = True;
		Items.FillByLoanContract.Visible	= True;
		
		FillCreditLoanInformationAtServer();
		SetCFItem();
		
		Items.GroupContractInformation.Visible = True;
		
		Items.PaymentAmount.Visible						= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title						= NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'");
		Items.PaymentAmountCurrency.Visible				= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible					= False;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
		RemoveTypes = New Array;
		RemoveTypes.Add(Type("DocumentRef.SupplierInvoice"));
		RemoveTypes.Add(Type("DocumentRef.PurchaseOrder"));
		Items.BasisDocument.TypeRestriction = New TypeDescription(Items.BasisDocument.TypeRestriction, , RemoveTypes);;
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements Then
		
		SetChoiceParametersForCounterparty("OtherRelationship");
		
		Items.LoanSettlements.Visible = True;
		Items.Counterparty.Visible = True;
		Items.Counterparty.Title = NStr("en = 'Lender'; ru = 'Заимодатель';pl = 'Pożyczkodawca';es_ES = 'Prestamista';es_CO = 'Prestador';tr = 'Borç veren';it = 'Finanziatore';de = 'Darlehensgeber'");
		Items.SettlementsOnCreditsPaymentDetails.Visible = True;
				
		Items.CreditContract.Visible		= True;
		Items.FillByCreditContract.Visible	= True;
		Items.Item.Visible					= False;
		
		FillCreditLoanInformationAtServer();
		SetCFItem();
		
		Items.GroupContractInformation.Visible = True;
		
		Items.PaymentAmount.Visible = UseForeignCurrency;
		Items.PaymentAmount.Title = NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'");
		Items.SettlementsAmount.Visible = True;
		Items.PayrollPaymentTotalPaymentAmount.Visible = False;	
	Else
		
		Items.OtherSettlements.Visible = True;
		
		Items.PaymentAmount.Visible = True;
		Items.PaymentAmount.Title = NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'");
		Items.SettlementsAmount.Visible = False;
		Items.PayrollPaymentTotalPaymentAmount.Visible = False;
		
	EndIf;
	
	SetVisibilityPlanningDocument();
	
EndProcedure

&AtServer
Procedure SetVisibilityPlanningDocument()
	
	If Object.OperationKind = Enums.OperationTypesCashVoucher.ToCustomer
		OR Object.OperationKind = Enums.OperationTypesCashVoucher.Vendor
		OR Object.OperationKind = Enums.OperationTypesCashVoucher.Salary
		OR Not GetFunctionalOption("PaymentCalendar") Then
		Items.PlanningDocuments.Visible	= False;
	ElsIf Object.OperationKind = Enums.OperationTypesCashVoucher.OtherSettlements
		OR Object.OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements
		OR Object.OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToEmployee
		OR Object.OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToCounterparty Then
			Items.PlanningDocuments.Visible	= False;
	Else
		Items.PlanningDocuments.Visible	= True;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetVisibilitySettlementAttributes()
	
	CounterpartyDoOperationsByContracts = Object.Counterparty.DoOperationsByContracts;
	
	Items.PaymentDetailsContract.Visible	= CounterpartyDoOperationsByContracts;
	Items.PaymentDetailsOrder.Visible		= Object.Counterparty.DoOperationsByOrders;
	
	Items.PaymentDetailsOtherSettlementsContract.Visible = CounterpartyDoOperationsByContracts;
	
EndProcedure

&AtServer
Procedure SetVisibilityEPDAttributes()
	
	OperationKindVendor = (Object.OperationKind = Enums.OperationTypesCashVoucher.Vendor);
	
	VisibleFlag = (ValueIsFilled(Object.Counterparty) AND OperationKindVendor);
	
	Items.PaymentDetailsEPDAmount.Visible				= VisibleFlag;
	Items.PaymentDetailsSettlementsEPDAmount.Visible	= VisibleFlag;
	Items.PaymentDetailsExistsEPD.Visible				= VisibleFlag;
	Items.PaymentDetailsCalculateEPD.Visible			= VisibleFlag;
	
EndProcedure

&AtClient
Procedure SetVisibleCommandFillByBasis()
	
	Result = False;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Vendor") Then
		
		Result = True;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Salary") 
		And TypeOf(Object.BasisDocument) = Type("DocumentRef.ExpenditureRequest") Then
		
		Result = True;
		
	EndIf;
	
	Items.FillByBasis.Visible = Result;
	
EndProcedure

&AtServer
Procedure SetTaxInvoiceText()
	Items.TaxInvoiceText.Visible = Not WorkWithVAT.GetPostAdvancePaymentsBySourceDocuments(Object.Date, Object.Company)
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	ColorTextSpecifiedInDocument = StyleColors.TextSpecifiedInDocument;
	
	//PaymentDetailsPlanningDocument
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.OperationKind");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= Enums.OperationTypesCashVoucher.Vendor;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.PaymentDetails.AdvanceFlag");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = '<required only for advance payment>'; ru = '<указывается только для аванса>';pl = '<wymagane tylko w przypadku przedpłat>';es_ES = '<requerido solo para pagos de anticipos>';es_CO = '<requerido solo para pagos de anticipos>';tr = '<yalnızca avans ödeme için gerekli>';it = '<richiesto solo per pagamento anticipato>';de = '<nur für Vorauszahlung erforderlich>.'"));
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
	
EndProcedure

&AtServer
Procedure SetAccountingPolicyValues()
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Object.Company);
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	FunctionalOptionAccountingCashMethodIncomeAndExpenses = AccountingPolicy.CashMethodOfAccounting;
	
EndProcedure

#Region ExternalFormViewManagement

&AtServer
Procedure SetChoiceParameterLinksAvailableTypes()
	
	// Other settlemets
	If Object.OperationKind = Enums.OperationTypesCashVoucher.OtherSettlements Then
		SetChoiceParametersForAccountingOtherSettlementsAtServerForAccountItem();
	Else
		SetChoiceParametersOnMetadataForAccountItem();
	EndIf;
	// End Other settlemets
	
	If Object.OperationKind = Enums.OperationTypesCashVoucher.Vendor Then
		
		Array = New Array();
		Array.Add(Type("DocumentRef.AdditionalExpenses"));
		Array.Add(Type("DocumentRef.SupplierInvoice"));
		Array.Add(Type("DocumentRef.SalesInvoice"));
		Array.Add(Type("DocumentRef.AccountSalesToConsignor"));
		Array.Add(Type("DocumentRef.ArApAdjustments"));
		Array.Add(Type("DocumentRef.SubcontractorInvoiceReceived"));
		
		ValidTypes = New TypeDescription(Array, , );
		Items.PaymentDetailsDocument.TypeRestriction = ValidTypes;
		
		OrdersArray = New Array();
		OrdersArray.Add(Type("DocumentRef.PurchaseOrder"));
		OrdersArray.Add(Type("DocumentRef.SubcontractorOrderIssued"));
		
		ValidTypes = New TypeDescription(OrdersArray);
		Items.PaymentDetailsOrder.TypeRestriction = ValidTypes;
		
		Items.PaymentDetailsDocument.ToolTip = NStr("en = 'The source document for the payment.'; ru = 'Исходный документ для оплаты.';pl = 'Dokument źródłowy dla płatności.';es_ES = 'Documento fuente para el pago.';es_CO = 'Documento fuente para el pago.';tr = 'Ödeme için kaynak dosya.';it = 'Il documento fonte per il pagamento.';de = 'Das Quelldokument für die Zahlung.'");

	ElsIf Object.OperationKind = Enums.OperationTypesCashVoucher.ToCustomer Then
		
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
		
		ValidTypes = New TypeDescription(Array, , );
		Items.PaymentDetailsDocument.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.SalesOrder", ,);
		Items.PaymentDetailsOrder.TypeRestriction = ValidTypes;
		
		Items.PaymentDetailsDocument.ToolTip = NStr("en = 'An advance payment document that you want to refund.'; ru = 'Документ авансового платежа, по которому осуществляется возврат денежных средств.';pl = 'Dokument płatności zaliczkowej, którą chcesz zwrócić.';es_ES = 'Un documento del pago anticipado que quiere reembolsar.';es_CO = 'Un documento del pago anticipado que quiere reembolsar.';tr = 'Geri ödeme istediğiniz avans ödeme belgesi.';it = 'Un documento di pagamento anticipato che si vuole risarcire.';de = 'Ein Vorauszahlungsbeleg, der zurückgegeben werden soll.'");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetVisibilityPrintReceipt()
	
	PrintReceiptEnabled = False;
	
	Button = Items.Find("PrintReceipt");
	If Button <> Undefined Then
		
		If (Object.OperationKind = Enums.OperationTypesCashVoucher.ToCustomer
			OR Object.OperationKind = Enums.OperationTypesCashVoucher.Vendor
			OR Object.OperationKind = Enums.OperationTypesCashVoucher.Other)
		   AND GetFunctionalOption("UsePeripherals")
		   AND Not ReadOnly Then
			PrintReceiptEnabled = True;
		EndIf;
		
		Button.Enabled = PrintReceiptEnabled;
		Items.Decoration4.Visible = PrintReceiptEnabled;
		Items.SalesSlipNumber.Visible = PrintReceiptEnabled;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetCurrentPage()
	
	LineCount = Object.PaymentDetails.Count();
	
	If LineCount = 0 Then
		Object.PaymentDetails.Add();
		Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		LineCount = 1;
	EndIf;
	
EndProcedure

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// Procedure of the field change data processor Operation kind on server.
//
&AtServer
Procedure SetCFItemWhenChangingTheTypeOfOperations()
	
	If Object.OperationKind = Enums.OperationTypesCashVoucher.ToCustomer
		AND (Object.Item = Catalogs.CashFlowItems.PaymentToVendor
		OR Object.Item = Catalogs.CashFlowItems.Other
		OR Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers) Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf Object.OperationKind = Enums.OperationTypesCashVoucher.Vendor
		AND (Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers
		OR Object.Item = Catalogs.CashFlowItems.Other
		OR Object.Item = Catalogs.CashFlowItems.PaymentToVendor) Then
		Object.Item = Catalogs.CashFlowItems.PaymentToVendor;
	ElsIf (Object.OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToEmployee
		Or Object.OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToCounterparty)
		And ValueIsFilled(Object.LoanContract) Then
		Object.Item = Common.ObjectAttributeValue(Object.LoanContract, "PrincipalItem");
	ElsIf Object.OperationKind = Enums.OperationTypesCashVoucher.Salary Then
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
	
	If Object.OperationKind = Enums.OperationTypesCashVoucher.ToCustomer Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf Object.OperationKind = Enums.OperationTypesCashVoucher.Vendor Then
		Object.Item = Catalogs.CashFlowItems.PaymentToVendor;
	ElsIf (Object.OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToEmployee
		Or Object.OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToCounterparty)
		And ValueIsFilled(Object.LoanContract) Then
		Object.Item = Common.ObjectAttributeValue(Object.LoanContract, "PrincipalItem");
	ElsIf Object.OperationKind = Enums.OperationTypesCashVoucher.Salary Then
		Object.Item = Catalogs.CashFlowItems.Payroll;	
	Else
		Object.Item = Catalogs.CashFlowItems.Other;
	EndIf;
	
EndProcedure

// Procedure expands the operation kinds selection list.
//
&AtServer
Procedure SupplementOperationTypesChoiceList()
	
	If Constants.UseRetail.Get() Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashVoucher.TransferToCashCR);
	EndIf;
	
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashVoucher.Other);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashVoucher.OtherSettlements);
	
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashVoucher.IssueLoanToEmployee);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashVoucher.IssueLoanToCounterparty);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashVoucher.LoanSettlements);
	
EndProcedure

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			False);
	ParametersStructure.Insert("FillHeader",			True);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	SetVisibleOfVATTaxation();
	SetVisibilitySettlementAttributes();
	SetVisibilityEPDAttributes();
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.CashCurrency, Object.Company);
	ExchangeRate = ?(StructureByCurrency.Rate = 0, 1, StructureByCurrency.Rate);
	Multiplicity = ?(StructureByCurrency.Repetition = 0, 1, StructureByCurrency.Repetition);
	
EndProcedure

// Function puts the SettlementsDetails tabular section to
// the temporary storage and returns an address
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
	IsVendor = Object.OperationKind = Enums.OperationTypesCashVoucher.Vendor;
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
		
	EndDo;
	
EndProcedure

// Recalculates amounts by the document tabular section
// currency after changing the bank account or petty cash.
//
&AtClient
Procedure RecalculateDocumentAmounts(ExchangeRate, Multiplicity, RecalculatePaymentAmount)
	
	For Each TabularSectionRow In Object.PaymentDetails Do
		
		If RecalculatePaymentAmount Then
			
			TabularSectionRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				ExchangeRateMethod,
				TabularSectionRow.ExchangeRate,
				ExchangeRate,
				TabularSectionRow.Multiplicity,
				Multiplicity);
				
			TabularSectionRow.EPDAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsEPDAmount,
				ExchangeRateMethod,
				TabularSectionRow.ExchangeRate,
				ExchangeRate,
				TabularSectionRow.Multiplicity,
				Multiplicity);
				
			CalculateVATSUM(TabularSectionRow);
			
		Else
			
			TabularSectionRow.ExchangeRate = ?(
				TabularSectionRow.ExchangeRate = 0,
				1,
				TabularSectionRow.ExchangeRate);
				
			TabularSectionRow.Multiplicity = ?(
				TabularSectionRow.Multiplicity = 0,
				1,
				TabularSectionRow.Multiplicity);
				
			TabularSectionRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.PaymentAmount,
				ExchangeRateMethod,
				ExchangeRate,
				TabularSectionRow.ExchangeRate,
				Multiplicity,
				TabularSectionRow.Multiplicity);
				
			TabularSectionRow.SettlementsEPDAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.EPDAmount,
				ExchangeRateMethod,
				ExchangeRate,
				TabularSectionRow.ExchangeRate,
				Multiplicity,
				TabularSectionRow.Multiplicity);
				
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
	
	If Not ValueIsFilled(Object.CashCurrency) Then
		Return;
	EndIf; 
	
	ExchangeRateBeforeChange = ExchangeRate;
	MultiplicityBeforeChange = Multiplicity;
	
	If ValueIsFilled(Object.CashCurrency) Then
		ExchangeRate = ?(
			StructureData.CurrencyRateRepetition.Rate = 0,
			1,
			StructureData.CurrencyRateRepetition.Rate);
		Multiplicity = ?(
			StructureData.CurrencyRateRepetition.Repetition = 0,
			1,
			StructureData.CurrencyRateRepetition.Repetition);
	EndIf;
	
	RecalculationOnChangeCashAssetsCurrency();
	
EndProcedure

&AtClient
Procedure DateOnChangeQueryBoxHandler(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		UpdatePaymentDetailsExchangeRatesAtServer();
		RecalculateAmountsOnCashAssetsCurrencyRateChange(AdditionalParameters);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdatePaymentDetailsExchangeRatesAtServer()
	
	For each TSRow In Object.PaymentDetails Do
		
		If ValueIsFilled(TSRow.Contract) Then
			
			StructureData = GetDataPaymentDetailsContractOnChange(
				Object.Date,
				TSRow.Contract);
			
			TSRow.ExchangeRate = ?(
				StructureData.ContractCurrencyRateRepetition.Rate = 0,
				1,
				StructureData.ContractCurrencyRateRepetition.Rate);
			
			TSRow.Multiplicity = ?(
				StructureData.ContractCurrencyRateRepetition.Repetition = 0,
				1,
				StructureData.ContractCurrencyRateRepetition.Repetition);
			
		EndIf;
		
	EndDo;
	
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

&AtClient
Procedure CalculateSettlmentsEPDAmount(TabularSectionRow)
	
	TabularSectionRow.ExchangeRate = ?(TabularSectionRow.ExchangeRate = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.SettlementsEPDAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.EPDAmount,
		ExchangeRateMethod,
		ExchangeRate,
		TabularSectionRow.ExchangeRate,
		Multiplicity,
		TabularSectionRow.Multiplicity);
	
EndProcedure

// Recalculate payment amount in the tabular section passed string.
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

&AtClient
Procedure CalculateSettlmentsAmount(TabularSectionRow)
	
	TabularSectionRow.ExchangeRate = ?(TabularSectionRow.ExchangeRate = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.PaymentAmount,
		ExchangeRateMethod,
		ExchangeRate,
		TabularSectionRow.ExchangeRate,
		Multiplicity,
		TabularSectionRow.Multiplicity);
	
EndProcedure

// Recalculates amounts by the document tabular section
// currency after changing the bank account or petty cash.
//
&AtClient
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
	
	StructureData = New Structure;
	
	StructureData.Insert("CounterpartyDescriptionFull", Common.ObjectAttributeValue(Counterparty, "DescriptionFull"));
	
	StructureData.Insert("Contract", ContractByDefault);
	
	ContractData = Common.ObjectAttributesValues(ContractByDefault, "SettlementsCurrency, CashFlowItem");
	
	StructureData.Insert("Item", ContractData.CashFlowItem);
	
	StructureData.Insert(
		"ContractCurrencyRateRepetition",
		CurrencyRateOperations.GetCurrencyRate(Date, ContractData.SettlementsCurrency, Company));
	
	If Object.OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements Then
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
Function GetDataCashAssetsCurrencyOnChange(Date, CashCurrency, Company)
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"CurrencyRateRepetition",
		CurrencyRateOperations.GetCurrencyRate(Date, CashCurrency, Company)
	);
	
	Return StructureData;
	
EndFunction

// Receives data set from the server for the AdvanceHolderOnChange procedure.
//
&AtServerNoContext
Function GetDataAdvanceHolderOnChange(AdvanceHolder, Date)
	
	StructureData = New Structure;
	StructureData.Insert("AdvanceHolderDescription", "");
	StructureData.Insert("DocumentKind", "");
	StructureData.Insert("DocumentNumber", "");
	StructureData.Insert("DocumentIssueDate", "");
	StructureData.Insert("DocumentWhoIssued", "");
	
	Query = New Query();
	Query.Text =
	"SELECT ALLOWED
	|	LegalDocuments.DocumentKind,
	|	LegalDocuments.Number,
	|	LegalDocuments.IssueDate,
	|	LegalDocuments.Owner.Presentation AS Presentation,
	|	LegalDocuments.Authority
	|FROM
	|	Catalog.LegalDocuments AS LegalDocuments
	|WHERE
	|	LegalDocuments.Owner = &AdvanceHolder
	|
	|ORDER BY
	|	LegalDocuments.IssueDate DESC";
	
	Query.SetParameter("AdvanceHolder", AdvanceHolder.Ind);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	StructureData.AdvanceHolderDescription = AdvanceHolder.Description;
	
	If SelectionOfQueryResult.Next() Then
	
		StructureData.AdvanceHolderDescription = SelectionOfQueryResult.Presentation;
		StructureData.DocumentKind = SelectionOfQueryResult.DocumentKind;
		StructureData.DocumentNumber = SelectionOfQueryResult.Number;
		StructureData.DocumentIssueDate = SelectionOfQueryResult.IssueDate;
		StructureData.DocumentWhoIssued = SelectionOfQueryResult.Authority;
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure Attachable_ProcessDateChange()
	
	StructureData = GetDataDateOnChange();
	
	QueryBoxText = NStr("en = 'The document date has changed. Do you want to use the exchange rate at that date?'; ru = 'Изменилась дата документа. Установить курс валюты в соответствии с курсом на новую дату?';pl = 'Data dokumentu uległa zmianie. Czy chcesz zastosować kurs waluty na tą datę?';es_ES = 'La fecha del documento se ha cambiado. ¿Quiere utilizar el tipo de cambio aquella fecha?';es_CO = 'La fecha del documento se ha cambiado. ¿Quiere utilizar el tipo de cambio aquella fecha?';tr = 'Belge tarihi değiştirildi. O tarihteki döviz kurunu kullanmak ister misiniz?';it = 'La data del documento è stata modificata. Applicare il tasso di cambio valido alla data indicata?';de = 'Das Belegdatum hat sich geändert. Möchten Sie den Wechselkurs zu diesem Zeitpunkt verwenden?'");
	ShowQueryBox(New NotifyDescription("DateOnChangeQueryBoxHandler", ThisObject, StructureData), QueryBoxText, QuestionDialogMode.YesNo);
	
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
	
	SetAccountingPolicyValues();
	
	FillVATRateByCompanyVATTaxation();
	ProcessingCompanyVATNumbers();
	
	SetVisibleOfVATTaxation();
	SetTaxInvoiceText();
	FillCreditLoanInformationAtServer();
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"ParentCompany",
		DriveServer.GetCompany(Object.Company)
	);
	StructureData.Insert(
		"ExchangeRateMethod",
		DriveServer.GetExchangeMethod(StructureData.ParentCompany)
	);
	
	SetAccountingPolicyValues();
	FillVATRateByCompanyVATTaxation();
	SetVisibleOfVATTaxation();
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			True);
	ParametersStructure.Insert("FillHeader",			True);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	SetTaxInvoiceText();
	
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
	
	If Object.OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements
		Or Object.OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToEmployee Then

		Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;
		
	Else
		
		Object.VATTaxation = DriveServer.VATTaxation(Object.Company, Object.Date);
		
	EndIf;
	
	If (Object.OperationKind = Enums.OperationTypesCashVoucher.ToCustomer
		OR Object.OperationKind = Enums.OperationTypesCashVoucher.Vendor) Then
		
		FillVATRateByVATTaxation();
		
	Else
		
		FillDefaultVATRate();
		
	EndIf;
	
EndProcedure

&AtServer
// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
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
		
		If Object.OperationKind = Enums.OperationTypesCashVoucher.Vendor
			Or Object.OperationKind = Enums.OperationTypesCashVoucher.ToCustomer Then
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
	
	If Object.OperationKind = Enums.OperationTypesCashVoucher.Vendor
		Or Object.OperationKind = Enums.OperationTypesCashVoucher.ToCustomer
		Or Object.OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements Then
		
		Items.VATTaxation.Visible = RegisteredForVAT;
		
	Else
		
		Items.VATTaxation.Visible = False;
		
		If Object.OperationKind = Enums.OperationTypesCashVoucher.OtherSettlements Then
			Items.PaymentDetailsOtherSettlementsVATRate.Visible = RegisteredForVAT;
			Items.PaymentDetailsOtherSettlementsVATAmount.Visible = RegisteredForVAT;
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure executes actions while changing counterparty contract.
//
&AtClient
Procedure ProcessCounterpartyContractChange()
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	StructureData = GetStructureDataForObject(ThisObject, "PaymentDetails", TabularSectionRow);
	
	If ValueIsFilled(TabularSectionRow.Contract) Then
		StructureData = GetDataPaymentDetailsContractOnChange(
			Object.Date,
			TabularSectionRow.Contract,
			StructureData);
		TabularSectionRow.ExchangeRate = ?(
			StructureData.ContractCurrencyRateRepetition.Rate = 0,
			1,
			StructureData.ContractCurrencyRateRepetition.Rate
		);
		TabularSectionRow.Multiplicity = ?(
			StructureData.ContractCurrencyRateRepetition.Repetition = 0,
			1,
			StructureData.ContractCurrencyRateRepetition.Repetition
		);
		
		FillPropertyValues(TabularSectionRow, StructureData);
	ElsIf UseDefaultTypeOfAccounting Then 
		TabularSectionRow.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	EndIf;
	
	TabularSectionRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.PaymentAmount,
		ExchangeRateMethod,
		ExchangeRate,
		TabularSectionRow.ExchangeRate,
		Multiplicity,
		TabularSectionRow.Multiplicity);
		
	TabularSectionRow.SettlementsEPDAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.EPDAmount,
		ExchangeRateMethod,
		ExchangeRate,
		TabularSectionRow.ExchangeRate,
		Multiplicity,
		TabularSectionRow.Multiplicity);
	
EndProcedure

// Procedure executes actions while starting to select counterparty contract.
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
		
		RunActionsOnAccountsDocumentChange();
		
		Modified = True;
		
	EndIf;
	
EndProcedure

// Procedure determines advance flag depending on the billing document type.
//
&AtClient
Procedure RunActionsOnAccountsDocumentChange()
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.ToCustomer") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.OnlineReceipt")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CreditNote") Then
			
			TabularSectionRow.AdvanceFlag = True;
			
		Else
			
			TabularSectionRow.AdvanceFlag = False;
			
		EndIf;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Vendor") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.SupplierInvoice") Then
			
			StructureData = GetStructureDataForObject(ThisObject, "PaymentDetails", TabularSectionRow);
			SetExistsEPD(StructureData);
			FillPropertyValues(TabularSectionRow, StructureData);
			
		EndIf;
		
		SetVisibilityDebitNoteText();
		
	EndIf;
	
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
	ParametersStructure.Insert("GetGLAccounts",			True);
	ParametersStructure.Insert("FillHeader",			False);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	Modified = True;
	
	SetVisibilityDebitNoteText();
	
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
// Procedure sets the form attribute visible
// from option Use subsystem Payroll.
//
// Parameters:
// No.
//
Procedure SetVisibleByFOUseSubsystemPayroll()
	
	// Salary.
	If Constants.UsePayrollSubsystem.Get() Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashVoucher.SalaryForEmployee);
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashVoucher.Salary);
	EndIf;
	
	// Taxes.
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashVoucher.Taxes);
	
EndProcedure

// Procedure receives the default petty cash currency.
//
&AtServerNoContext
Function GetPettyCashAccountingCurrencyAtServer(PettyCash)
	
	Return Common.ObjectAttributeValue(PettyCash, "CurrencyByDefault");
	
EndFunction

// Checks the match of the "Company" and "LoanKind" contract attributes to the terms of the document.
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

&AtServerNoContext
Function GetSubordinateDebitNote(BasisDocument)
	
	Return EarlyPaymentDiscountsServer.GetSubordinateDebitNote(BasisDocument);
	
EndFunction

&AtServerNoContext
Function CheckBeforeDebitNoteFilling(BasisDocument)
	
	Return EarlyPaymentDiscountsServer.CheckBeforeDebitNoteFilling(BasisDocument, False)
	
EndFunction

&AtServer
Function SetVisibilityDebitNoteText()
	
	If Object.OperationKind = Enums.OperationTypesCashVoucher.Vendor Then
		
		DocumentsTable			= Object.PaymentDetails.Unload(, "Document");
		PaymentDetailsDocuments	= DocumentsTable.UnloadColumn("Document");
		
		Items.DebitNoteText.Visible = EarlyPaymentDiscountsServer.AvailableDebitNoteEPD(PaymentDetailsDocuments);
		
	Else
		
		Items.DebitNoteText.Visible = False;
		
	EndIf;
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

// The procedure clears the attributes that could have been
// filled in earlier but do not belong to the current operation.
//
&AtClient
Procedure ClearAttributesNotRelatedToOperation()
	
	Correspondence = Undefined;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Vendor") Then
		Object.Correspondence = Undefined;
		Object.ExpenseItem = Undefined;
		Object.RegisterExpense = False;
		Object.TaxKind = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.PayrollPayment.Clear();
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.Order = Undefined;
		Object.CashCR = Undefined;
		Object.LoanContract = Undefined;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Order = Undefined;
			TableRow.Document = Undefined;
			TableRow.AdvanceFlag = False;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.ToCustomer") Then
		Object.Correspondence = Undefined;
		Object.ExpenseItem = Undefined;
		Object.RegisterExpense = False;
		Object.TaxKind = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.PayrollPayment.Clear();
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.Order = Undefined;
		Object.CashCR = Undefined;
		Object.LoanContract = Undefined;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Order = Undefined;
			TableRow.Document = Undefined;
			TableRow.AdvanceFlag = True;
			TableRow.EPDAmount = 0;
			TableRow.SettlementsEPDAmount = 0;
			TableRow.ExistsEPD = False;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.ToAdvanceHolder") Then
		Object.Correspondence = Undefined;
		Object.ExpenseItem = Undefined;
		Object.RegisterExpense = False;
		Object.Counterparty = Undefined;
		Object.TaxKind = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.Order = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.CashCR = Undefined;
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
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Salary") Then
		Object.Correspondence = Undefined;
		Object.ExpenseItem = Undefined;
		Object.RegisterExpense = False;
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.Department = Undefined;
		Object.LoanContract = Undefined;
		If Not FunctionalOptionAccountingCashMethodIncomeAndExpenses Then
			Object.BusinessLine = Undefined;
		EndIf;
		Object.Order = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.CashCR = Undefined;
		Object.PaymentDetails.Clear();
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.SalaryForEmployee") Then
		Object.Correspondence = Undefined;
		Object.ExpenseItem = Undefined;
		Object.RegisterExpense = False;
		Object.Counterparty = Undefined;
		Object.Document = Undefined;
		Object.Department = Undefined;
		Object.LoanContract = Undefined;
		If Not FunctionalOptionAccountingCashMethodIncomeAndExpenses Then
			Object.BusinessLine = Undefined;
		EndIf;
		Object.Order = Undefined;
		Object.CashCR = Undefined;
		Object.PayrollPayment.Clear();
		If Not ValueIsFilled(Object.Department) Then
			SettingValue = DriveReUse.GetValueByDefaultUser(CurrentSystemUser, "MainDepartment");
			Object.Department = ?(ValueIsFilled(SettingValue), SettingValue, StructuralUnitDepartment);
		EndIf;
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
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Other") Then
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.TaxKind = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.CashCR = Undefined;
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
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.TransferToCashCR") Then
		Object.Counterparty = Undefined;
		Object.ExpenseItem = Undefined;
		Object.RegisterExpense = False;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.TaxKind = Undefined;
		Object.Correspondence = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.Order = Undefined;
		Object.RegistrationPeriod = Undefined;
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
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Taxes") Then
		Object.Counterparty = Undefined;
		Object.ExpenseItem = Undefined;
		Object.RegisterExpense = False;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.Correspondence = Undefined;
		Object.Department = Undefined;
		Object.LoanContract = Undefined;
		If Not FunctionalOptionAccountingCashMethodIncomeAndExpenses Then
			Object.BusinessLine = Undefined;
		EndIf;
		Object.Order = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.CashCR = Undefined;
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
	// Other settlement
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.OtherSettlements") Then
		Object.Correspondence = Undefined;
		Object.ExpenseItem = Undefined;
		Object.RegisterExpense = False;
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.TaxKind = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.CashCR = Undefined;
		Object.Order = Undefined;
		Object.PayrollPayment.Clear();
		Object.PaymentDetails.Clear();
		Object.PaymentDetails.Add();
		Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		Object.LoanContract = Undefined;
	// End Other settlement
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.IssueLoanToEmployee") Then
		Object.Correspondence = Undefined;
		Object.ExpenseItem = Undefined;
		Object.RegisterExpense = False;
		Object.Counterparty = Undefined;
		Object.TaxKind = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.Order = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.CashCR = Undefined;
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
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.IssueLoanToEmployee") Then
		
		Object.Correspondence		= Undefined;
		Object.ExpenseItem = Undefined;
		Object.RegisterExpense = False;
		Object.AdvanceHolder		= Undefined;
		Object.TaxKind				= Undefined;
		Object.Department			= Undefined;
		Object.BusinessLine			= Undefined;
		Object.Order				= Undefined;
		Object.RegistrationPeriod	= Undefined;
		Object.CashCR				= Undefined;
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
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.LoanSettlements") Then
		Object.Correspondence = Undefined;
		Object.ExpenseItem = Undefined;
		Object.RegisterExpense = False;
		Object.Counterparty = Undefined;
		Object.TaxKind = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.Order = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.CashCR = Undefined;
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
	EndIf;
	
	Correspondence = Object.Correspondence;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - handler of the Selection button clicking.
// Opens the form of debt forming documents selection.
//
&AtClient
Procedure Pick(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(Undefined,NStr("en = 'Please select a counterparty.'; ru = 'Сначала выберите контрагента.';pl = 'Wybierz kontrahenta.';es_ES = 'Por favor, seleccione una contraparte.';es_CO = 'Por favor, seleccione un contraparte.';tr = 'Lütfen, cari hesap seçin.';it = 'Si prega di selezionare una controparte.';de = 'Bitte wählen Sie einen Geschäftspartner aus.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.PettyCash) Then
		ShowMessageBox(Undefined,NStr("en = 'Select a cash account.'; ru = 'Укажите кассовый счет.';pl = 'Wybierz kasę.';es_ES = 'Seleccione una cuenta de efectivo.';es_CO = 'Seleccione una cuenta de efectivo.';tr = 'Kasa hesabı seçin.';it = 'Selezionare un conto di cassa.';de = 'Wählen Sie ein Liquiditätskonto aus.'"));
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
		Object.DocumentAmount
	);
		
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
			CalculatePaymentSUM(RowPaymentDetails);
		EndDo;
		
		DefinePaymentDetailsExistsEPD();
		
		SetCurrentPage();
		
		If Object.PaymentDetails.Count() = 1 Then
			Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
		EndIf;
		
		SetVisibilityDebitNoteText();
		
		Modified = True;
		
	EndIf;

EndProcedure

// Procedure - handler of clicking the button "Fill in by basis".
//
&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		ShowMessageBox(Undefined,NStr("en = 'Please select a base document.'; ru = 'Не выбран документ-основание.';pl = 'Wybierz dokument źródłowy.';es_ES = 'Por favor, seleccione un documento de base.';es_CO = 'Por favor, seleccione un documento de base.';tr = 'Lütfen, temel belge seçin.';it = 'Si prega di selezionare un documento di base.';de = 'Bitte wählen Sie ein Basisdokument aus.'"));
		Return;
	EndIf;
	
	If (TypeOf(Object.BasisDocument) = Type("DocumentRef.CashTransferPlan")
		OR TypeOf(Object.BasisDocument) = Type("DocumentRef.ExpenditureRequest"))
		AND Not DocumentApproved(Object.BasisDocument) Then
		Raise NStr("en = 'Please select an approved cash transfer plan.'; ru = 'Нельзя ввести перемещение денег на основании неутвержденного планового документа.';pl = 'Wybierz zatwierdzony plan przelewów gotówkowych.';es_ES = 'Por favor, seleccione un plan de traslado de efectivo aprobado.';es_CO = 'Por favor, seleccione un plan de traslado de efectivo aprobado.';tr = 'Lütfen onaylı nakit transfer planını seçin.';it = 'Si prega di selezionare un piano di trasferimento contanti approvato.';de = 'Bitte wählen Sie einen genehmigten Überweisungsplan aus.'");
	EndIf;
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), NStr("en = 'Do you want to refill the cash voucher?'; ru = 'Документ будет полностью перезаполнен по основанию. Продолжить?';pl = 'Czy chcesz ponownie wypełnić dowód kasowy KW?';es_ES = '¿Quiere volver a rellenar el vale de efectivo?';es_CO = '¿Quiere volver a rellenar el vale de efectivo?';tr = 'Kasa fişi yeniden doldurulsun mu?';it = 'Volete ricompilare l''uscita di cassa?';de = 'Möchten Sie den Kassenbeleg auffüllen?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		
		Object.PaymentDetails.Clear();
		Object.PayrollPayment.Clear();
		
		FillByDocument(Object.BasisDocument);
		
		If Object.PaymentDetails.Count() = 0
			AND Object.OperationKind <> PredefinedValue("Enum.OperationTypesCashVoucher.Salary") Then
			Object.PaymentDetails.Add();
			Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		EndIf;
		
		OperationKind = Object.OperationKind;
		CashCurrency = Object.CashCurrency;
		DocumentDate = Object.Date;
		
		SetCurrentPage();
		SetChoiceParameterLinksAvailableTypes();
		OperationKindOnChangeAtServer(False);
		
	EndIf;

EndProcedure

// Procedure is called while clicking the "Print receipt" button of the command bar.
&AtClient
Procedure PrintReceipt(Command)
	
	If Object.SalesSlipNumber <> 0 Then
		MessageText = NStr("en = 'Cannot print the sales slip because it has already been printed on the fiscal register.'; ru = 'Чек уже пробит на фискальном регистраторе!';pl = 'Nie można wydrukować dokumentu sprzedaży, ponieważ został już wydrukowany w rejestratorze fiskalnym.';es_ES = 'No se puede imprimir el recibo de compra porque ya se ha imprimido en el registro fiscal.';es_CO = 'No se puede imprimir el recibo de compra porque ya se ha imprimido en el registro fiscal.';tr = 'Mali kaydedicine önceden basıldığından satış fişini yazdıramaz.';it = 'Non è possibile stampare lo scontrino perché è stato già stampato nel registratore fiscale.';de = 'Der Kassenbeleg kann nicht gedruckt werden, da er bereits im Fiskalspeicher gedruckt wurde.'");
		CommonClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	ShowMessageBox = False;
	If DriveClient.CheckPossibilityOfReceiptPrinting(ThisForm, ShowMessageBox) Then
	
		If EquipmentManagerClient.RefreshClientWorkplace() Then
			
			NotifyDescription = New NotifyDescription("EnableFiscalRegistrarEnd", ThisObject);
			EquipmentManagerClient.OfferSelectDevice(NotifyDescription, "FiscalRegister",
					NStr("en = 'Select a fiscal register'; ru = 'Выберите фискальный регистратор';pl = 'Wybierz rejestrator fiskalny';es_ES = 'Seleccionar un registro fiscal';es_CO = 'Seleccionar un registro fiscal';tr = 'Mali kayıt seçin';it = 'Selezionare un registro fiscale.';de = 'Fiskalspeicher auswählen.'"), NStr("en = 'The fiscal register is not connected.'; ru = 'Фискальный регистратор не подключен.';pl = 'Rejestrator fiskalny nie jest podłączony.';es_ES = 'El registro fiscal no está conectado.';es_CO = 'El registro fiscal no está conectado.';tr = 'Mali kayıt bağlanmadı.';it = 'Il registratore fiscale non è collegato.';de = 'Der Fiskalspeicher ist nicht verbunden.'"));
			
		Else
			
			MessageText = NStr("en = 'First, you need to select the cashier workplace of the current session.'; ru = 'Предварительно необходимо выбрать рабочее место кассира в текущем сеансе.';pl = 'Najpierw musisz wybrać stanowiska kasjera bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo del cajero de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo del cajero de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki kasiyer çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro di cassiere per la sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'");
			
			CommonClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	ElsIf ShowMessageBox Then
		ShowMessageBox(Undefined,NStr("en = 'Failed to post document'; ru = 'Не удалось выполнить проведение документа';pl = 'Księgowanie dokumentu nie powiodło się';es_ES = 'Fallado a enviar el documento';es_CO = 'Fallado a enviar el documento';tr = 'Belge kaydedilemedi';it = 'Impossibile pubblicare il documento';de = 'Fehler beim Buchen des Dokuments'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure EnableFiscalRegistrarEnd(DeviceIdentifier, Parameters) Export
	
	ErrorDescription = "";
	
	If DeviceIdentifier <> Undefined Then
		
		// Enable FR.
		Result = EquipmentManagerClient.ConnectEquipmentByID(
			UUID,
			DeviceIdentifier,
			ErrorDescription
		);
		
		If Result Then
			
			// Prepare data.
			InputParameters  = New Array();
			Output_Parameters = Undefined;
			SectionNumber = 2;
			
			// Prepare goods table.
			ProductsTable = New Array();
			
			ProductsTableRow = New ValueList();
			ProductsTableRow.Add(NStr("en = 'Pay to:'; ru = 'Выдать:';pl = 'Zapłać:';es_ES = 'Pagar a:';es_CO = 'Pagar a:';tr = 'Ödenecek:';it = 'Pagare a:';de = 'Zahlen an:'") + " " + Object.Issue + Chars.LF
			+ NStr("en = 'Purpose:'; ru = 'Основание:';pl = 'Przeznaczenie:';es_ES = 'Propósito:';es_CO = 'Propósito:';tr = 'Amaç:';it = 'Motivo:';de = 'Zweck:'") + " " + Object.Basis); //  1 - Description
			ProductsTableRow.Add("");					 //  2 - Barcode
			ProductsTableRow.Add("");					 //  3 - SKU
			ProductsTableRow.Add(SectionNumber);			//  4 - Department number
			ProductsTableRow.Add(Object.DocumentAmount);  //  5 - Price for position without discount
			ProductsTableRow.Add(1);					  //  6 - Quantity
			ProductsTableRow.Add("");					  //  7 - Discount description
			ProductsTableRow.Add(0);					  //  8 - Discount amount
			ProductsTableRow.Add(0);					  //  9 - Discount percentage
			ProductsTableRow.Add(Object.DocumentAmount);  // 10 - Position amount with discount
			ProductsTableRow.Add(0);					  // 11 - Tax number (1)
			ProductsTableRow.Add(0);					  // 12 - Tax amount (1)
			ProductsTableRow.Add(0);					  // 13 - Tax percent (1)
			ProductsTableRow.Add(0);					  // 14 - Tax number (2)
			ProductsTableRow.Add(0);					  // 15 - Tax amount (2)
			ProductsTableRow.Add(0);					  // 16 - Tax percent (2)
			ProductsTableRow.Add("");					 // 17 - Section name of commodity string formatting
			
			ProductsTable.Add(ProductsTableRow);
			
			// Prepare the payments table.
			PaymentsTable = New Array();
			
			PaymentRow = New ValueList();
			PaymentRow.Add(0);
			PaymentRow.Add(Object.DocumentAmount);
			PaymentRow.Add("");
			PaymentRow.Add("");
			
			PaymentsTable.Add(PaymentRow);
			
			// Prepare the general parameters table.
			CommonParameters = New Array();
			CommonParameters.Add(1);					  //  1 - Receipt type
			CommonParameters.Add(True);				 //  2 - Fiscal receipt sign
			CommonParameters.Add(Undefined);		   //  3 - Print on lining document
			CommonParameters.Add(Object.DocumentAmount);  //  4 - the receipt amount without discounts
			CommonParameters.Add(Object.DocumentAmount);  //  5 - the receipt amount after applying all discounts
			CommonParameters.Add("");					 //  6 - Discount card number
			CommonParameters.Add("");					 //  7 - Header text
			CommonParameters.Add("");					 //  8 - Footer text
			CommonParameters.Add(0);					  //  9 - Session number (for receipt copy)
			CommonParameters.Add(0);					  // 10 - Receipt number (for receipt copy)
			CommonParameters.Add(0);					  // 11 - Document No (for receipt copy)
			CommonParameters.Add(0);					  // 12 - Document date (for receipt copy)
			CommonParameters.Add("");					 // 13 - Cashier name (for receipt copy)
			CommonParameters.Add("");					 // 14 - Cashier password
			CommonParameters.Add(0);					  // 15 - Template number
			CommonParameters.Add("");					 // 16 - Section name header format
			CommonParameters.Add("");					 // 17 - Section name cellar format
			
			InputParameters.Add(ProductsTable);
			InputParameters.Add(PaymentsTable);
			InputParameters.Add(CommonParameters);
			
			// Print receipt.
			Result = EquipmentManagerClient.RunCommand(
				DeviceIdentifier,
				"PrintReceipt",
				InputParameters,
				Output_Parameters
			);
			
			If Result Then
				
				// Set the received value of receipt number to document attribute.
				Object.SalesSlipNumber = Output_Parameters[1];
				Modified  = True;
				Write(New Structure("WriteMode", DocumentWriteMode.Posting));
				
			Else
				
				MessageText = NStr("en = 'Cannot print the sales slip on the fiscal register. Details: %AdditionalDetails%'; ru = 'При печати чека произошла ошибка. Чек не напечатан на фискальном регистраторе. Дополнительное описание: %AdditionalDetails%';pl = 'Nie można wydrukować dokumentu sprzedaży w rejestratorze fiskalnym. Szczegóły: %AdditionalDetails%';es_ES = 'No se puede imprimir el recibo de compra en el registro fiscal. Detalles: %AdditionalDetails%';es_CO = 'No se puede imprimir el recibo de compra en el registro fiscal. Detalles: %AdditionalDetails%';tr = 'Satış fişi, mali kayıt cihazında yazdırılamıyor. Ayrıntılar: %AdditionalDetails%';it = 'Non è possibile stampare lo scontrino nel registratore fiscale. Dettagli: %AdditionalDetails%';de = 'Der Kassenbeleg kann nicht auf dem Fiskalspeicher gedruckt werden. Details: %AdditionalDetails%'");
				MessageText = StrReplace(MessageText,"%AdditionalDetails%",Output_Parameters[1]);
				CommonClientServer.MessageToUser(MessageText);
				
			EndIf;
			
			// Disable FR.
			EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
			
		Else
			
			MessageText = NStr("en = 'Cannot print the sales slip on the fiscal register because the register is not connected. Details: %AdditionalDetails%'; ru = 'При подключении устройства произошла ошибка. Чек не напечатан на фискальном регистраторе. Дополнительное описание: %AdditionalDetails%';pl = 'Nie można wydrukować dokumentu sprzedaży w rejestratorze fiskalnym, ponieważ nie jest on podłączony. Szczegóły: %AdditionalDetails%';es_ES = 'No se puede imprimir el recibo de compra en el registro fiscal porque el registro no está conectado. Detalles: %AdditionalDetails%';es_CO = 'No se puede imprimir el recibo de compra en el registro fiscal porque el registro no está conectado. Detalles: %AdditionalDetails%';tr = 'Kaydedici bağlanmadığından mali kaydedicisinde satış fişini yazdıramıyor: Ayrıntılar: %AdditionalDetails%';it = 'Non è possibile stampare la ricevuta nel registro fiscale, dal momento che il registro non è collegato. Dettagli: %AdditionalDetails%';de = 'Der Kassenbeleg kann nicht auf dem Fiskalspeicher gedruckt werden, da das Register nicht verbunden ist. Details: %AdditionalDetails%'");
			MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
			CommonClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	EndIf;

EndProcedure

// Procedure - FillDetails command handler.
//
&AtClient
Procedure FillDetails(Command)
	
	If Object.DocumentAmount = 0
		And Object.OperationKind <> PredefinedValue("Enum.OperationTypesCashVoucher.ToCustomer") Then
		ShowMessageBox(Undefined, NStr("en = 'Please specify the amount.'; ru = 'Введите сумму.';pl = 'Podaj wartość.';es_ES = 'Por favor, especifique el importe.';es_CO = 'Por favor, especifique el importe.';tr = 'Lütfen, tutarı belirtin.';it = 'Si prega di specificare l''importo.';de = 'Bitte geben Sie den Betrag an.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.PettyCash) Then
		ShowMessageBox(Undefined, NStr("en = 'Select a cash account.'; ru = 'Укажите кассовый счет.';pl = 'Wybierz kasę.';es_ES = 'Seleccione una cuenta de efectivo.';es_CO = 'Seleccione una cuenta de efectivo.';tr = 'Kasa hesabı seçin.';it = 'Selezionare un conto di cassa.';de = 'Wählen Sie ein Liquiditätskonto aus.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(Undefined,NStr("en = 'Please select a counterparty.'; ru = 'Выберите контрагента.';pl = 'Wybierz kontrahenta.';es_ES = 'Por favor, seleccione un contraparte.';es_CO = 'Por favor, seleccione un contraparte.';tr = 'Lütfen, cari hesap seçin.';it = 'Si prega di selezionare una controparte.';de = 'Bitte wählen Sie einen Geschäftspartner aus.'"));
		Return;
	EndIf;
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillDetailsEnd", ThisObject), 
		NStr("en = 'You are about to fill the payment details. This will overwrite the current details. Do you want to continue?'; ru = 'Расшифровка будет полностью перезаполнена. Продолжить?';pl = 'Dokonujesz zapisu szczegółów płatności. Spowoduje to zastąpienie bieżących szczegółów. Czy chcesz kontynuować?';es_ES = 'Usted está a punto de rellenar los detalles de pago. Eso se sobrescribirá los detalles actuales. ¿Quiere continuar?';es_CO = 'Usted está a punto de rellenar los detalles de pago. Eso se sobrescribirá los detalles actuales. ¿Quiere continuar?';tr = 'Ödeme ayrıntılarını doldurmak üzeresiniz. Bu işlem mevcut ayrıntıların üzerine yazacaktır. Devam etmek istiyor musunuz?';it = 'State per compilare i dettagli di pagamento. Questo sovrascriverà i dettagli correnti. Volete proseguire?';de = 'Sie sind dabei, die Zahlungsdaten auszufüllen. Dadurch werden die aktuellen Details überschrieben. Möchten Sie fortsetzen?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillDetailsEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	Object.PaymentDetails.Clear();
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Vendor") Then
		
		FillPaymentDetails();
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.ToCustomer") Then
		
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
	
	If Not ValueIsFilled(Object.Issue) Then
		Object.Issue = StructureData.CounterpartyDescriptionFull;
	EndIf;
	
	FillPaymentDetailsByContractData(StructureData);
	
	If StructureData.Property("DefaultLoanContract") AND ValueIsFilled(StructureData.DefaultLoanContract) Then
		Object.LoanContract = StructureData.DefaultLoanContract;
		ProceedChangeCreditOrLoanContract();
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
		
		IncomeAndExpenseItemsOnChangeConditions();
		
		If ValueIsFilled(Object.Counterparty) Then 
			
			StructureContractData = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company, Object.Date);	
			FillPaymentDetailsByContractData(StructureContractData);
			
		EndIf;
		
		
		If Object.PaymentDetails.Count() = 1 Then
			Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		EndIf;
			
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			True);
	ParametersStructure.Insert("FillHeader",			True);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
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
	ParentCompany = StructureData.ParentCompany;
	ExchangeRateMethod = StructureData.ExchangeRateMethod;
	
	ProcessingCompanyVATNumbers(False);
	
	If ValueIsFilled(Object.Counterparty) Then 
		
		StructureContractData = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company, Object.Date);
	
		FillPaymentDetailsByContractData(StructureContractData);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CashAssetsCurrencyOnChangeEnd(AdditionalParameters) Export
	
	MessageText = AdditionalParameters.MessageText;
	
	
	Object.PayrollPayment.Clear();
	
	CashAssetsCurrencyOnChangeFragment();

EndProcedure

&AtClient
Procedure CashAssetsCurrencyOnChangeFragment()
	
	Var StructureData, MessageText;
	
	StructureData = GetDataCashAssetsCurrencyOnChange(
		Object.Date,
		Object.CashCurrency,
		Object.Company);
	
	RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData);

EndProcedure

// Procedure - OnChange event handler of AdvanceHandler input field.
// Clears the AdvanceHolders document.
//
&AtClient
Procedure AdvanceHolderOnChange(Item)
	
	If OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.IssueLoanToEmployee")
		Or OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.LoanSettlements") Then
		
		DataStructure = GetEmployeeDataOnChange(Object.AdvanceHolder, Object.Date, Object.Company);
		Object.LoanContract = DataStructure.LoanContract;
		ProceedChangeCreditOrLoanContract();
		
	Else
		DataStructure = GetDataAdvanceHolderOnChange(Object.AdvanceHolder, Object.Date);
	EndIf;
	
	Object.Issue = DataStructure.AdvanceHolderDescription;
	
	If ValueIsFilled(DataStructure.DocumentKind) Then
		Object.ByDocument = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 number %2, issued %3 %4'; ru = '%1 номер %2, выданный %3 %4';pl = '%1 numer %2, wydany %3 %4';es_ES = '%1 número %2, emitido %3 %4';es_CO = '%1 número %2, emitido %3 %4';tr = '%1 numara %2, yayımlama tarihi %3 %4';it = '%1 numero %2, emesso %3 %4';de = '%1 Anzahl %2, erstellt %3 %4'"),
			DataStructure.DocumentKind,
			DataStructure.DocumentNumber,
			Format(DataStructure.DocumentIssueDate, "DLF=D"),
			DataStructure.DocumentWhoIssued);
	Else
		Object.ByDocument = "";
	EndIf;
	
	EmployeeOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure BasisDocumentOnChange(Item)
	
	SetVisibleCommandFillByBasis();
	
EndProcedure

// Procedure - OnChange event handler of DocumentAmount input field.
//
&AtClient
Procedure DocumentAmountOnChange(Item)
	
	If Object.PaymentDetails.Count() = 1 Then
		
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
		
		TabularSectionRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
			TabularSectionRow.PaymentAmount,
			ExchangeRateMethod,
			ExchangeRate,
			TabularSectionRow.ExchangeRate,
			Multiplicity,
			TabularSectionRow.Multiplicity);
		
		If Not ValueIsFilled(TabularSectionRow.VATRate) Then
			TabularSectionRow.VATRate = DefaultVATRate;
		EndIf;
		
		CalculateVATSUM(TabularSectionRow);
	
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of PettyCash input field.
//
&AtClient
Procedure PettyCashOnChange(Item)
	
	Object.CashCurrency = GetPettyCashAccountingCurrencyAtServer(Object.PettyCash);
	
	CurrencyCashBeforeChanging = CashCurrency;
	CashCurrency = Object.CashCurrency;
	
	// If currency is not changed, do nothing.
	If CashCurrency <> CurrencyCashBeforeChanging Then
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Salary") Then
			
			MessageText = NStr("en = 'The currency has changed. The list of payslips will be cleared.'; ru = 'Изменилась валюта. Список ""Расчетные листки"" будет очищен.';pl = 'Waluta się zmieniła. Lista wypłat zostanie usunięta.';es_ES = 'La moneda se ha cambiado. La lista de nóminas se eliminará.';es_CO = 'La moneda se ha cambiado. La lista de nóminas se eliminará.';tr = 'Para birimi değişti. Maaş bordroları listesi silinecektir.';it = 'La valuta è cambiata. L''elenco dei cedolini verrà cancellato.';de = 'Die Währung hat sich geändert. Die Liste der Gehaltsabrechnungen wird gelöscht.'");
			
			Notification = New NotifyDescription(
				"CashAssetsCurrencyOnChangeEnd",
				ThisObject,
				New Structure("MessageText", MessageText));
				
			ShowMessageBox(Notification, MessageText);
			
			Return;
			
		EndIf;
		
		CashAssetsCurrencyOnChangeFragment();
		
	EndIf;
	
	If ValueIsFilled(Object.Counterparty) Then 
		
		StructureContractData = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company, Object.Date);
	
		FillPaymentDetailsByContractData(StructureContractData);
		
	EndIf;
	
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
			NStr("en = 'There are no rows with advance payments in the Payment details tab'; ru = 'В табличной части ""Расшифровка платежа"" отсутствуют авансовые платежи';pl = 'Na karcie Szczegóły płatności nie ma wierszy z zaliczkami';es_ES = 'No hay filas con los pagos anticipados en la pestaña de los Detalles de pago';es_CO = 'No hay filas con los pagos anticipados en la pestaña de los Detalles de pago';tr = 'Ödeme ayrıntıları sekmesinde avans ödemeye sahip herhangi bir satır yok';it = 'Non ci sono righe con anticipo pagamenti il nella scheda dettagli di pagamento';de = 'Auf der Registerkarte Zahlungsdetails gibt es keine Zeilen mit Vorauszahlungen'"));
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

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#Region TabularSectionAttributeEventHandlers

&AtClient
Procedure PaymentDetailsIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "PaymentDetails", StandardProcessing);
	
EndProcedure

// Procedure - BeforeDeletion event handler of PaymentDetails tabular section.
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
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	
	If NewRow And Not Clone Then
		
		CurrentData = Items.PaymentDetails.CurrentData;
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.ToCustomer") Then
			CurrentData.AdvanceFlag = True;
		EndIf;
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Vendor") Then
			CurrentData.DiscountReceivedIncomeItem = DefaultIncomeItem;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsOnEditEnd(Item, NewRow, CancelEdit)
	
	GLAccountsInDocumentsClient.TableOnEditEnd(ThisIsNewRow);
	
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
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Vendor") Then
		If TabularSectionRow.AdvanceFlag Then
			TabularSectionRow.Document = Undefined;
		Else
			TabularSectionRow.PlanningDocument = Undefined;
		EndIf;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.ToCustomer") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CreditNote")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.OnlineReceipt")
			Or TabularSectionRow.Document = Undefined Then
			
			If Not TabularSectionRow.AdvanceFlag Then
				TabularSectionRow.AdvanceFlag = True;
				CommonClientServer.MessageToUser(
					NStr("en = 'Cannot clear the ""Advance payment"" check box for this operation type.'; ru = 'Невозможно снять флажок ""Авансовый платеж"" для данного типа операций.';pl = 'Nie można oczyścić pola wyboru ""Zaliczka"" dla tego typu operacji.';es_ES = 'No se puede vaciar la casilla de verificación ""Pago anticipado"" para este tipo de operación.';es_CO = 'No se puede vaciar la casilla de verificación ""Pago anticipado"" para este tipo de operación.';tr = 'Bu işlem türü için ""Avans ödeme"" onay kutusu temizlenemez.';it = 'Impossibile cancellare la casella di controllo ""Pagamento Anticipato"" per questo tipo di operazione.';de = 'Das Kontrollkästchen ""Vorauszahlung"" für diesen Operationstyp kann nicht deaktiviert werden.'"));
			EndIf;
			
		ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.ArApAdjustments") Then
			
			If TabularSectionRow.AdvanceFlag Then
				TabularSectionRow.AdvanceFlag = False;
				CommonClientServer.MessageToUser(
					NStr("en = 'Cannot select the ""Advance payment"" check box for this operation type.'; ru = 'Для данного типа документа расчетов нельзя установить признак аванса.';pl = 'Nie można wybrać pola wyboru ""Zaliczka"" dla tego typu operacji.';es_ES = 'No se puede seleccionar la casilla de verificación ""Pago anticipado"" para este tipo de operación.';es_CO = 'No se puede seleccionar la casilla de verificación ""Pago anticipado"" para este tipo de operación.';tr = 'Bu işlem türü için ""Avans ödeme"" onay kutusu seçilemez.';it = 'Non è possibile selezionare la casella di controllo ""Pagamento Anticipato"" per questo tipo di operazione.';de = 'Das Kontrollkästchen ""Vorauszahlung"" kann für diesen Operationstyp nicht aktiviert werden.'"));
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
		AND Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Vendor") Then
		
		Mode = QuestionDialogMode.OK;
		ShowMessageBox(, NStr("en = 'This is a billing document for advance payments.'; ru = 'Это документ расчета для авансовых платежей.';pl = 'Jest to dokument rozliczeniowy dla płatności zaliczkowych.';es_ES = 'Este es un documento de facturación para pagos anticipados.';es_CO = 'Este es un documento de facturación para pagos anticipados.';tr = 'Avans ödemeler için fatura belgesidir.';it = 'Questo è un documento di fatturazione per pagamenti anticipati.';de = 'Dies ist ein Abrechnungsbeleg für Vorauszahlungen.'"));
		
	Else
		
		ThisIsAccountsReceivable = Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.ToCustomer");
		
		StructureFilter = New Structure();
		StructureFilter.Insert("Company",		Object.Company);
		StructureFilter.Insert("Counterparty",	Object.Counterparty);
		
		If ValueIsFilled(TabularSectionRow.Contract) Then
			StructureFilter.Insert("Contract", TabularSectionRow.Contract);
		EndIf;
		
		ParameterStructure = New Structure("Filter, ThisIsAccountsReceivable, DocumentType",
			StructureFilter,
			ThisIsAccountsReceivable,
			TypeOf(Object.Ref)
		);
		
		ParameterStructure.Insert("IsCustomerReturn", Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.ToCustomer"));
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
	
	If Not TabularSectionRow.SettlementsAmount = 0 Then
		TabularSectionRow.ExchangeRate = TabularSectionRow.PaymentAmount * ExchangeRate / Multiplicity
			/ TabularSectionRow.SettlementsAmount * TabularSectionRow.Multiplicity;
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of PaymentDetailsExchangeRate input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsRateOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculateSettlmentsAmount(TabularSectionRow);
	CalculateSettlmentsEPDAmount(TabularSectionRow);
	
EndProcedure

// Procedure - OnChange event handler of PaymentDetailsUnitConversionFactor input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsRepetitionOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculateSettlmentsAmount(TabularSectionRow);
	CalculateSettlmentsEPDAmount(TabularSectionRow);
	
EndProcedure

// The OnChange event handler of the PaymentDetailsPaymentAmount field.
// It updates the payment currency exchange rate and exchange rate multiplier, and also the VAT amount.
//
&AtClient
Procedure PaymentDetailsPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculateSettlmentsAmount(TabularSectionRow);
	
	If Not ValueIsFilled(TabularSectionRow.VATRate) Then
		TabularSectionRow.VATRate = DefaultVATRate;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure PaymentDetailsEPDAmountOnChange(Item)
	
	CurrentData = Items.PaymentDetails.CurrentData;
	CalculateSettlmentsEPDAmount(CurrentData);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			True);
	ParametersStructure.Insert("FillHeader",			False);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
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

// Procedure - OnChange event handler of SalaryPaymentStatement input field.
//
&AtClient
Procedure SalaryPayStatementOnChange(Item)
	
	TabularSectionRow = Items.PayrollPayment.CurrentData;
	TabularSectionRow.PaymentAmount = GetDataSalaryPayStatementOnChange(TabularSectionRow.Statement);
	
EndProcedure

// Procedure - event handler Management of attribute RegistrationPeriod.
//
&AtClient
Procedure RegistrationPeriodTuning(Item, Direction, StandardProcessing)
	
	DriveClient.OnRegistrationPeriodRegulation(ThisForm, Direction);
	DriveClient.OnChangeRegistrationPeriod(ThisForm);
	
EndProcedure

// Procedure - event handler StartChoice of attribute RegistrationPeriod.
//
&AtClient
Procedure RegistrationPeriodStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing	 = False;
	
	CalendarDateOnOpen = ?(ValueIsFilled(Object.RegistrationPeriod), Object.RegistrationPeriod, DriveReUse.GetSessionCurrentDate());
	
	OpenForm("CommonForm.Calendar", DriveClient.GetCalendarGenerateFormOpeningParameters(CalendarDateOnOpen), ThisForm);
	
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
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

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
Procedure FillCreditLoanInformationAtServer()
	
	ConfigureLoanContractItem();
	
	If Object.LoanContract.IsEmpty() Then
		Items.LabelCreditContractInformation.Title = NStr("en = '<Select loan contract>'; ru = '<Выберите договор кредита (займа)>';pl = '<Wybierz umowę pożyczki>';es_ES = '<Seleccionar el contrato de préstamo>';es_CO = '<Seleccionar el contrato de préstamo>';tr = '<Kredi sözleşmesi seç>';it = '<Seleziona contratto di prestito>';de = '<Darlehensvertrag auswählen>'");
		Items.LabelRemainingDebtByCredit.Title = "";
		
		Items.LabelCreditContractInformation.TextColor = StyleColors.BorderColor;
		Items.LabelRemainingDebtByCredit.TextColor = StyleColors.BorderColor;
		
		Return;
	EndIf;
	
	If Object.OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToEmployee
		OR Object.OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToCounterparty Then
		FillLoanInformationAtServer();
	ElsIf Object.OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements Then
		FillCreditInformationAtServer();
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCreditInformationAtServer()
	    
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
	
	ResultArray = Query.ExecuteBatch();
	
	If Object.LoanContract.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement Then
		Multiplier = 1;
	Else
		Multiplier = -1;
	EndIf;
	
	SelectionSchedule = ResultArray[0].Select();
	SelectionScheduleFutureMonth = ResultArray[2].Select();
	
	LabelCreditContractInformationTextColor	= StyleColors.BorderColor;
	LabelRemainingDebtByCreditTextColor		= StyleColors.BorderColor;
	
	If SelectionScheduleFutureMonth.Next() Then
		
		If BegOfMonth(?(Object.Date = '00010101', CurrentSessionDate(), Object.Date)) = BegOfMonth(SelectionScheduleFutureMonth.Period) Then
			PaymentDate = Format(SelectionScheduleFutureMonth.Period, "DLF=D");
		Else
			PaymentDate = Format(SelectionScheduleFutureMonth.Period, "DLF=D") + " (" + NStr("en = 'not in the current month'; ru = 'не в текущем месяце';pl = 'nie w bieżącym miesiącu';es_ES = 'no el mes corriente';es_CO = 'no el mes corriente';tr = ' cari ayda değil';it = 'non nel mese corrente';de = 'nicht im aktuellen Monat'") + ")";
			LabelCreditContractInformationTextColor = StyleColors.FormTextColor;
		EndIf;
			
		LabelCreditContractInformation = StringFunctionsClientServer.SubstituteParametersToString( 
			NStr("en = 'Payment date: %1. Debt amount: %2. Interest: %3. Commission: %4 (%5)'; ru = 'Дата платежа: %1. Сумма долга: %2. Сумма %: %3. Комиссия: %4 (%5)';pl = 'Data płatności: %1. Kwota długu: %2. Odsetki: %3. Prowizja: %4 (%5)';es_ES = 'Fecha de pago: %1. Importe de la deuda: %2. Interés: %3. Comisión: %4 (%5)';es_CO = 'Fecha de pago: %1. Importe de la deuda: %2. Interés: %3. Comisión: %4 (%5)';tr = 'Ödeme tarihi: %1. Borç tutarı: %2. Faiz: %3. Komisyon: %4 (%5)';it = 'Data di pagamento %1. Importo del debito: %2. Interessi: %3. Commissioni: %4 (%5)';de = 'Zahlungstermin: %1. Schuldenbetrag: %2. Zinsen: %3. Provisionszahlung: %4 (%5)'"),
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
			NStr("en = 'Payment date: %1. Debt amount: %2. Interest: %3. Commission: %4 (%5)'; ru = 'Дата платежа: %1. Сумма долга: %2. Сумма %: %3. Комиссия: %4 (%5)';pl = 'Data płatności: %1. Kwota długu: %2. Odsetki: %3. Prowizja: %4 (%5)';es_ES = 'Fecha de pago: %1. Importe de la deuda: %2. Interés: %3. Comisión: %4 (%5)';es_CO = 'Fecha de pago: %1. Importe de la deuda: %2. Interés: %3. Comisión: %4 (%5)';tr = 'Ödeme tarihi: %1. Borç tutarı: %2. Faiz: %3. Komisyon: %4 (%5)';it = 'Data di pagamento %1. Importo del debito: %2. Interessi: %3. Commissioni: %4 (%5)';de = 'Zahlungstermin: %1. Schuldenbetrag: %2. Zinsen: %3. Provisionszahlung: %4 (%5)'"),
			PaymentDate,
			Format(SelectionScheduleFutureMonth.Principal, "NFD=2; NZ=0"),
			Format(SelectionScheduleFutureMonth.Interest, "NFD=2; NZ=0"),
			Format(SelectionScheduleFutureMonth.Commission, "NFD=2; NZ=0"),
			SelectionScheduleFutureMonth.CurrencyPresentation);

	Else		
		LabelCreditContractInformation = NStr("en = 'Payment date: <not specified>'; ru = 'Дата платежа: <не указана>';pl = 'Data płatności: <nieokreślona>';es_ES = 'Fecha de pago: <no especificado>';es_CO = 'Fecha de pago: <no especificado>';tr = 'Ödeme tarihi: <belirtilmemiş>';it = 'Data di pagamento: <non specificata>';de = 'Zahlungstermin: <not specified>'");		
	EndIf;
	
	
	SelectionBalance = ResultArray[1].Select();
	If SelectionBalance.Next() Then
		
		LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersToString( 
			NStr("en = 'Debt balance: %1. Interest: %2. Commission amount: %3 (%4)'; ru = 'Остаток долга: %1. Сумма %: %2. Комиссия: %3 (%4)';pl = 'Saldo zadłużenia: %1. Odsetki: %2. Kwota prowizji: %3 (%4)';es_ES = 'Saldo de la deuda: %1. Interés: %2. Importe de la comisión: %3 (%4)';es_CO = 'Saldo de la deuda: %1. Interés: %2. Importe de la comisión: %3 (%4)';tr = 'Borç bakiyesi: %1. Faiz: %2. Komisyon tutarı: %3 (%4)';it = 'Saldo del debito: %1. Interesse: %2. Commissioni: %3 (%4)';de = 'Schuldensaldo: %1. Zinsen: %2Provisionszahlung: %3 (%4)'"),
			Format(Multiplier * SelectionBalance.PrincipalDebtCurBalance, "NFD=2; NZ=0"),
			Format(Multiplier * SelectionBalance.InterestCurBalance, "NFD=2; NZ=0"),
			Format(SelectionScheduleFutureMonth.Interest, "NFD=2; NZ=0"),
			Format(Multiplier * SelectionBalance.CommissionCurBalance, "NFD=2; NZ=0"),
			SelectionBalance.CurrencyPresentation);
			
		If Multiplier * SelectionBalance.PrincipalDebtCurBalance >= 0 AND (Multiplier * SelectionBalance.InterestCurBalance < 0 OR 
			Multiplier * SelectionBalance.CommissionCurBalance < 0) Then
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
Procedure FillLoanInformationAtServer()

	LabelCreditContractInformationTextColor = StyleColors.BorderColor;
	LabelRemainingDebtByCreditTextColor = StyleColors.BorderColor;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	LoanSettlementsTurnovers.LoanContract.SettlementsCurrency AS Currency,
	|	LoanSettlementsTurnovers.PrincipalDebtCurReceipt
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
	
	Query.SetParameter("LoanContract", Object.LoanContract);
	Query.SetParameter("Company", Object.Company);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		
		LabelCreditContractInformation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Loan amount: %1 (%2)'; ru = 'Сумма займа: %1 (%2)';pl = 'Kwota pożyczki: %1 (%2)';es_ES = 'Importe del préstamo: %1 (%2)';es_CO = 'Importe del préstamo: %1 (%2)';tr = 'Borç tutarı: %1 (%2)';it = 'L''importo del prestito: %1 (%2)';de = 'Darlehensbetrag: %1 (%2)'"), 
			Selection.Total, 
			Selection.Currency);
		
		If Selection.Total = Selection.PrincipalDebtCurReceipt Then
			LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Remaining amount to issue: 0 (%1)'; ru = 'Осталось выдать: 0 (%1)';pl = 'Kwota pozostała do wydan: 0 (%1)';es_ES = 'Importe restante a emitir: 0 (%1)';es_CO = 'Importe restante a emitir: 0 (%1)';tr = 'Verilecek geri kalan tutar: 0 (%1)';it = 'Importo residuo da emettere: 0 (%1)';de = 'Verbleibender Ausgabebetrag: 0 (%1)'"),
				Selection.Currency);
			LabelRemainingDebtByCreditTextColor = StyleColors.SpecialTextColor;
		Else
			LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Remaining amount to issue: %1 (%2). Issued %3 (%2)'; ru = 'Осталось выдать: %1 (%2). Уже выдано %3 (%2)';pl = 'Kwota pozostała do wydania: %1 (%2). Wydano %3 (%2)';es_ES = 'Importe restante a emitir: %1 (%2). Emitido %3 (%2)';es_CO = 'Importe restante a emitir: %1 (%2). Emitido %3 (%2)';tr = 'Verilecek geriye kalan tutar: %1 (%2). Verilen %3(%2).';it = 'Importo residuo da emettere: %1 (%2). Emesso %3 (%2)';de = 'Verbleibender Ausgabebetrag: %1(%2). Ausgegeben %3(%2).'"),
				Selection.Total - Selection.PrincipalDebtCurReceipt,
				Selection.Currency,
				Selection.PrincipalDebtCurReceipt);
			LabelRemainingDebtByCreditTextColor = StyleColors.SpecialTextColor;
		EndIf;
		
	Else
		
		LabelCreditContractInformation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Loan amount: %1 (%2)'; ru = 'Сумма займа: %1 (%2)';pl = 'Kwota pożyczki: %1 (%2)';es_ES = 'Importe del préstamo: %1 (%2)';es_CO = 'Importe del préstamo: %1 (%2)';tr = 'Borç tutarı: %1 (%2)';it = 'L''importo del prestito: %1 (%2)';de = 'Darlehensbetrag: %1 (%2)'"),
			Object.LoanContract.Total,
			Object.LoanContract.SettlementsCurrency);
		LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Remaining amount to issue: %1 (%2)'; ru = 'Осталось выдать: %1 (%2)';pl = 'Kwota pozostała do wydania: %1 (%2)';es_ES = 'Importe restante a emitir: %1 (%2)';es_CO = 'Importe restante a emitir: %1 (%2)';tr = 'Verilecek geri kalan tutar: %1 (%2)';it = 'Importo residuo da emettere: %1 (%2)';de = 'Verbleibender Ausgabebetrag: %1 (%2)'"),
			Object.LoanContract.Total,
			Object.LoanContract.SettlementsCurrency);
	EndIf;
	
	Items.LabelCreditContractInformation.Title = LabelCreditContractInformation;
	Items.LabelRemainingDebtByCredit.Title = LabelRemainingDebtByCredit;
	
	Items.LabelCreditContractInformation.TextColor = LabelCreditContractInformationTextColor;
	Items.LabelRemainingDebtByCredit.TextColor = LabelRemainingDebtByCreditTextColor;
	
EndProcedure

&AtServerNoContext
Function GetDefaultLoanContract(Document, Counterparty, Company, OperationKind)
	
	DocumentManager = Documents.LoanContract;
	
	LoanKindList = New ValueList;
	LoanKindList.Add(?(OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements, 
		Enums.LoanContractTypes.Borrowed,
		Enums.LoanContractTypes.EmployeeLoanAgreement));
	                                                   
	DefaultLoanContract = DocumentManager.ReceiveLoanContractByDefaultByCompanyLoanKind(Counterparty, Company, LoanKindList);
	
	Return DefaultLoanContract;
	
EndFunction

&AtServer
Procedure ConfigureLoanContractItem()
	
	If Object.OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToEmployee Then
		
		Items.EmployeeLoanAgreement.Enabled = NOT Object.AdvanceHolder.IsEmpty();
		If Items.EmployeeLoanAgreement.Enabled Then
			Items.EmployeeLoanAgreement.InputHint = "";
		Else
			Items.EmployeeLoanAgreement.InputHint = NStr("en = 'Before selecting a contract, select an employee.'; ru = 'Чтобы выбрать договор, выберите сотрудника';pl = 'Przed wybraniem umowy, wybierz pracownika.';es_ES = 'Antes de seleccionar un contrato, seleccionar un empleado.';es_CO = 'Antes de seleccionar un contrato, seleccionar un empleado.';tr = 'Sözleşme seçmeden önce bir çalışan seçin.';it = 'Prima di scegliere un contratto, selezionare un dipendente.';de = 'Bevor Sie einen Vertrag auswählen, wählen Sie einen Mitarbeiter aus.'");
		EndIf;
		
	ElsIf Object.OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToCounterparty Then
		
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
		Items.CreditContract.InputHint = NStr("en = 'Before selecting a contract, select a bank.'; ru = 'Чтобы выбрать договор, выберите банк';pl = 'Przed wybraniem umowy, wybierz bank.';es_ES = 'Antes de seleccionar un contrato, seleccionar un banco.';es_CO = 'Antes de seleccionar un contrato, seleccionar un banco.';tr = 'Bir sözleşmeyi seçmeden önce, bir banka seçin.';it = 'Prima di scegliere un contratto, selezionare una banca.';de = 'Bevor Sie einen Vertrag auswählen, wählen Sie eine Bank aus.'");
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
	
	Query.SetParameter("LoanContract", Object.LoanContract);
	Query.SetParameter("Company", Object.Company);
	Query.SetParameter("Ref", Object.Ref);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		
		Object.CashCurrency = Selection.Currency;
		
		MessageText = "";
		
		If Selection.Total < Selection.PrincipalDebtCurReceipt Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Issued under the loan contract %1 (%2)'; ru = 'По договору займа уже выдано %1 (%2)';pl = 'Wydano według umowy pożyczki %1 (%2)';es_ES = 'Emitido bajo el contrato de préstamo %1 (%2)';es_CO = 'Emitido bajo el contrato de préstamo %1 (%2)';tr = 'Kredi sözleşmesi kapsamında verilen %1(%2)';it = 'Emesso in base a contratto di prestito %1 (%2)';de = 'Ausgestellt unter dem Darlehensvertrag %1 (%2)'"), 
				Selection.PrincipalDebtCurReceipt,
				Selection.Currency);
		ElsIf Selection.Total = Selection.PrincipalDebtCurReceipt Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The complete amount has been already issued under the loan contract %1 (%2)'; ru = 'По договору займа уже выдана вся сумма %1 (%2)';pl = 'Cała wartość w ramach umowy pożyczki została już wydana %1 (%2)';es_ES = 'El importe completo se ha emitido bajo el contrato de préstamo %1 (%2)';es_CO = 'El importe completo se ha emitido bajo el contrato de préstamo %1 (%2)';tr = 'Toplam tutar önceden kredi sözleşmesi kapsamında %1 (%2) zaten verildi:';it = 'L''importo completo è già stato emesso in base al contratto di prestito %1 (%2)';de = 'Der gesamte Betrag wurde bereits im Rahmen des Darlehensvertrags %1 (%2) ausgegeben'"),
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
		ExchangeRate,
		Multiplicity,
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

&AtClient
Procedure ProceedChangeCreditOrLoanContract()
	
	EmployeeLoanAgreementData = ProceedChangeCreditOrLoanContractAtServer(Object.LoanContract, Object.Date);
	Object.CashCurrency = EmployeeLoanAgreementData.Currency;
	
	FillCreditLoanInformationAtServer();
	
	CashCurrencyBeforeChange = CashCurrency;
	CashCurrency = Object.CashCurrency;
	
	If CashCurrency = CashCurrencyBeforeChange Then
		Return;
	EndIf;
	
	CashAssetsCurrencyOnChangeFragment();
	
EndProcedure

&AtServerNoContext
Function ProceedChangeCreditOrLoanContractAtServer(LoanContract, Date)
	
	DataStructure = New Structure;
	
	DataStructure.Insert("Currency", 			LoanContract.SettlementsCurrency);
	DataStructure.Insert("Counterparty",		LoanContract.Counterparty);
	DataStructure.Insert("Employee",			LoanContract.Employee);
	DataStructure.Insert("ThisIsLoanContract",	LoanContract.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement);
		
	Return DataStructure;
	
EndFunction

&AtClient
Procedure EmployeeLoanAgreementOnChange(Item)
	ProceedChangeCreditOrLoanContract();
EndProcedure

&AtServerNoContext
Function GetEmployeeDataOnChange(Employee, Date, Company)
	
	DataStructure = GetDataAdvanceHolderOnChange(Employee, Date);
	
	DataStructure.Insert("LoanContract", Documents.LoanContract.ReceiveLoanContractByDefaultByCompanyLoanKind(Employee, Company));
	
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
		TabularSectionRow.ExchangeRate
	);
	TabularSectionRow.Multiplicity = ?(
		TabularSectionRow.Multiplicity = 0,
		1,
		TabularSectionRow.Multiplicity
	);
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.SettlementsAmount = 0,
		1,
		TabularSectionRow.PaymentAmount / TabularSectionRow.SettlementsAmount * ExchangeRate
	);
	
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

&AtClient
Procedure FillPaymentDetailsByContractData(StructureData)
	
	If Object.PaymentDetails.Count() = 1 Then 
		
		Object.PaymentDetails[0].Contract = StructureData.Contract;
		Object.PaymentDetails[0].Item = StructureData.Item;
		
		If ValueIsFilled(Object.PaymentDetails[0].Contract) Then
			Object.PaymentDetails[0].ExchangeRate = ?(
				StructureData.ContractCurrencyRateRepetition.Rate = 0,
				1,
				StructureData.ContractCurrencyRateRepetition.Rate);
				
			Object.PaymentDetails[0].Multiplicity = ?(
				StructureData.ContractCurrencyRateRepetition.Repetition = 0,
				1,
				StructureData.ContractCurrencyRateRepetition.Repetition);
		EndIf;
		
		Object.PaymentDetails[0].ExchangeRate = ?(
			Object.PaymentDetails[0].ExchangeRate = 0,
			1,
			Object.PaymentDetails[0].ExchangeRate);
			
		Object.PaymentDetails[0].Multiplicity = ?(
			Object.PaymentDetails[0].Multiplicity = 0,
			1,
			Object.PaymentDetails[0].Multiplicity);
		
		Object.PaymentDetails[0].SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
			Object.PaymentDetails[0].PaymentAmount,
			ExchangeRateMethod,
			ExchangeRate,
			Object.PaymentDetails[0].ExchangeRate,
			Multiplicity,
			Object.PaymentDetails[0].Multiplicity);
		
	EndIf;
	
EndProcedure

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
	
	IsOtherOperation = (OperationKind = Enums.OperationTypesCashVoucher.Other);
	
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

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion
