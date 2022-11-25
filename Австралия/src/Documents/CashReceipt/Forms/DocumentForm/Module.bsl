
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
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues);
	
	DefaultExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("DiscountAllowed");
		
	If Object.PaymentDetails.Count() = 0 Then
		Object.PaymentDetails.Add();
		Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		
		If Object.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer Then
			Object.PaymentDetails[0].DiscountAllowedExpenseItem = DefaultExpenseItem;
		EndIf;
		
	EndIf;
	
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
		
		If Object.OperationKind <> Enums.OperationTypesCashReceipt.LoanSettlements AND
			Object.OperationKind <> Enums.OperationTypesCashReceipt.LoanRepaymentByEmployee Then
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
				EndIf;
			EndIf;
		EndIf;
		
		SetCFItem();
	EndIf;
	
	// Form attributes setting.
	ParentCompany       = DriveServer.GetCompany(Object.Company);
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.CashCurrency, Object.Company);
	ExchangeRateMethod  = DriveServer.GetExchangeMethod(ParentCompany);
	
	ExchangeRate = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Rate);
		
	Multiplicity = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Repetition);
	
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Object.Date, DriveServer.GetPresentationCurrency(Object.Company), Object.Company);
	
	AccountingCurrencyRate = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Rate);
		
	AccountingCurrencyMultiplicity = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Repetition);
	
	SupplementOperationTypesChoiceList();
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	SetAccountingPolicyValues();
	
	If Not ValueIsFilled(Object.Ref)
		And Not ValueIsFilled(Parameters.Basis)
		And Not ValueIsFilled(Parameters.CopyingValue) Then
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
	
	PrintReceiptEnabled = False;
	
	Button = Items.Find("PrintReceipt");
	If Button <> Undefined Then
		
		If Object.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer Then
			PrintReceiptEnabled = True;
		EndIf;
		
		Button.Enabled = PrintReceiptEnabled;
		Items.Decoration3.Visible = PrintReceiptEnabled;
		Items.SalesSlipNumber.Visible = PrintReceiptEnabled;
		
	EndIf;
	
	PresentationCurrency = DriveServer.GetPresentationCurrency(Object.Company);
	
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
		
		TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount - (TabularSectionRow.PaymentAmount) / ((TabularSectionRow.VATRate.Rate + 100) / 100);
		
	EndIf;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			False);
	ParametersStructure.Insert("FillHeader",			True);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	SetIncomeAndExpenseItemsVisibility();
	
	ProcessingCompanyVATNumbers();
	
	SetVisibilityItemsDependenceOnOperationKind();
	SetVisibilitySettlementAttributes();
	SetVisibilityEPDAttributes();
	SetConditionalAppearance();
	
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
	
	WorkWithVAT.SetTextAboutAdvancePaymentInvoiceIssued(ThisObject);
	
	SetTaxInvoiceText();
	
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
			
			CommonClientServer.MessageToUser(
				?(Cancel, 
					NStr("en = 'The cash receipt is not posted.'; ru = 'Приходный кассовый ордер не проведен';pl = 'KP - Dowód wpłaty nie jest zatwierdzony.';es_ES = 'El recibo de efectivo no se ha enviado.';es_CO = 'El recibo de efectivo no se ha enviado.';tr = 'Nakit tahsilat kaydedilmemiş.';it = 'L''entrata di cassa non è stata pubblicata.';de = 'Der Zahlungseingang wird nicht gebucht.'") + " " + MessageText, 
					MessageText));
			
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
	
	LineCount = Object.PaymentDetails.Count();
	
	// Notification about payment.
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
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If CurrentObject.OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByEmployee
		Or CurrentObject.OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByCounterparty
		Or CurrentObject.OperationKind = Enums.OperationTypesCashReceipt.LoanSettlements Then
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
	
	If ChoiceSource.FormName = "Document.TaxInvoiceIssued.Form.DocumentForm" Then
		
		TaxInvoiceText = SelectedValue;
		
	ElsIf GLAccountsInDocumentsClient.IsGLAccountsChoiceProcessing(ChoiceSource.FormName) Then
		
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
		
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

#Region OtherSettlements

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
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.Other") Then
			
			Structure = New Structure("Object, Correspondence, IncomeItem, Manual");
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

#EndRegion

#Region FormItemEventHandlersTablePaymentDetails

&AtClient
Procedure PaymentDetailsOtherSettlementsBeforeDeleteRow(Item, Cancel)
	
	If Object.PaymentDetails.Count() = 1 Then
		Cancel = True;
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

#Region FormItemAdvanceHoldersPaymentDetails

&AtClient
Procedure AdvanceHoldersPaymentDetailsPaymentAmountOnChange(Item)
	
	TablePartRow = Items.PlanningDocumentsPaymentDetails.CurrentData;
	
	If Not ValueIsFilled(TablePartRow.VATRate) Then
		TablePartRow.VATRate = DefaultVATRate;
	EndIf;
	
	CalculateVATAmountAtClient(TablePartRow);

EndProcedure

#EndRegion

#Region Internal

&AtClientAtServerNoContext
Function GetStructureDataForObject(Form, TabName, TabRow)
	
	StructureData = New Structure;
	
	StructureData.Insert("TabName", TabName);
	StructureData.Insert("Object", Form.Object);
	
	StructureData.Insert("Contract", TabRow.Contract);
	StructureData.Insert("Document", TabRow.Document);
	StructureData.Insert("ExistsEPD", TabRow.ExistsEPD);
	StructureData.Insert("EPDAmount", TabRow.EPDAmount);
	StructureData.Insert("DiscountAllowedExpenseItem",	TabRow.DiscountAllowedExpenseItem);
	
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
		StructureData.Insert("DiscountAllowedGLAccount", TabRow.DiscountAllowedGLAccount);
		StructureData.Insert("ThirdPartyPayerGLAccount", TabRow.ThirdPartyPayerGLAccount);
		StructureData.Insert("VATOutputGLAccount", TabRow.VATOutputGLAccount);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

#Region GLAccounts

&AtServer
Procedure FillAddedColumns(ParametersStructure)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	IsOtherSettlements = Object.OperationKind = Enums.OperationTypesCashReceipt.OtherSettlements;
	
	StructureArray = New Array();
	
	If UseDefaultTypeOfAccounting And IsOtherSettlements Then
		
		If ParametersStructure.FillHeader Then
			StructureData = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "Header", Object);
			GLAccountsInDocuments.CompleteCounterpartyStructureData(StructureData, ObjectParameters, "Header");
			StructureArray.Add(StructureData);
		EndIf;
		
	EndIf;
	
	If ParametersStructure.FillPaymentDetails And Not IsOtherSettlements Then
		StructureData = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters);
		GLAccountsInDocuments.CompleteCounterpartyStructureData(StructureData, ObjectParameters);
		StructureArray.Add(StructureData);
	EndIf;
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, ParametersStructure.GetGLAccounts);
	
	If UseDefaultTypeOfAccounting And IsOtherSettlements Then
		Object.Correspondence = ChartsOfAccounts.PrimaryChartOfAccounts.FindByCode(StructureData.GLAccounts);
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
		?(StructureData.ContractCurrencyRateRepetition.Rate =0, 1, StructureData.ContractCurrencyRateRepetition.Rate),
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
	FormParameters.Insert("ControlContractChoice", Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
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
	
	StructureData.Insert(
		"ContractCurrencyRateRepetition",
		CurrencyRateOperations.GetCurrencyRate(Date, ContractData.SettlementsCurrency, Object.Company));
	StructureData.Insert("SettlementsCurrency", ContractData.SettlementsCurrency);
	StructureData.Insert("Item", ContractData[NameCashFlowItem]);
	
	If UseDefaultTypeOfAccounting And StructureData.Property("GLAccounts") Then
		GLAccountsInDocuments.FillCounterpartyGLAccounts(StructureData);
	EndIf;
	
	IncomeAndExpenseItemsInDocuments.SetConditionalAppearance(ThisObject, "PaymentDetails");
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure OperationKindOnChangeAtServer()
	
	SetChoiceParameterLinksAvailableTypes();
	
	SetVisibilityPrintReceipt();
	
	If OperationKind = Enums.OperationTypesCashReceipt.RetailIncomeEarningAccounting
		Or Not ValueIsFilled(OperationKind) Then
		User = Users.CurrentUser();
		SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
		Object.Department = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
	EndIf;
	
	If Object.OperationKind = Enums.OperationTypesCashReceipt.OtherSettlements Then
		DefaultVATRate			= Catalogs.VATRates.Exempt;
		DefaultVATRateNumber	= DriveReUse.GetVATRateValue(DefaultVATRate);
		Object.PaymentDetails[0].VATRate = DefaultVATRate;
	Else
		FillVATRateByCompanyVATTaxation();
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			True);
	ParametersStructure.Insert("FillHeader",			True);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	SetVisibleOfVATTaxation();
	SetIncomeAndExpenseItemsVisibility();
	SetVisibilityItemsDependenceOnOperationKind();
	SetVisibilityEPDAttributes();
	SetCFItemWhenChangingTheTypeOfOperations();
	SetVisibilityCreditNoteText();
	
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

&AtServer
Procedure SetChoiceParametersForAccountingOtherSettlementsAtServerForAccountItem()

	If Not UseDefaultTypeOfAccounting Then 
		Return;
	EndIf;
	
	Item = Items.OtherSettlementsCorrespondence;
	
	ChoiceParametersItem	= New Array;
	FilterByAccountType		= New Array;

	For Each Parameter In Item.ChoiceParameters Do
		If GetFunctionalOption("UseDefaultTypeOfAccounting") And Parameter.Name = "Filter.TypeOfAccount" Then
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
Procedure SetTaxInvoiceText()
	Items.TaxInvoiceText.Visible = Not WorkWithVAT.GetPostAdvancePaymentsBySourceDocuments(Object.Date, Object.Company)
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

#EndRegion

#Region ExternalFormViewManagement

&AtServer
Procedure SetVisibilityPrintReceipt()
	
	PrintReceiptEnabled = False;
	
	Button = Items.Find("PrintReceipt");
	If Button <> Undefined Then
		
		If Object.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer Then
			PrintReceiptEnabled = True;
		EndIf;
		
		Button.Enabled = PrintReceiptEnabled;
		Items.Decoration3.Visible = PrintReceiptEnabled;
		Items.SalesSlipNumber.Visible = PrintReceiptEnabled;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetChoiceParameterLinksAvailableTypes()
	
	// Other settlemets
	If Object.OperationKind = Enums.OperationTypesCashReceipt.OtherSettlements Then
		SetChoiceParametersForAccountingOtherSettlementsAtServerForAccountItem();
	Else
		SetChoiceParametersOnMetadataForAccountItem();
	EndIf;
	// End Other settlemets
	
	If Object.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer Then
		
		Array = New Array();
		Array.Add(Type("DocumentRef.FixedAssetSale"));
		Array.Add(Type("DocumentRef.SupplierInvoice"));
		Array.Add(Type("DocumentRef.SalesInvoice"));
		Array.Add(Type("DocumentRef.SalesOrder"));
		Array.Add(Type("DocumentRef.AccountSalesFromConsignee"));
		Array.Add(Type("DocumentRef.ArApAdjustments"));
		
		ValidTypes = New TypeDescription(Array, , );
		Items.PaymentDetails.ChildItems.PaymentDetailsDocument.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.SalesOrder, DocumentRef.WorkOrder", , );
		Items.PaymentDetailsOrder.TypeRestriction = ValidTypes;
		
		Items.PaymentDetailsDocument.ToolTip = NStr("en = 'The document that is paid for.'; ru = 'Оплачиваемый документ отгрузки товаров, работ и услуг контрагенту.';pl = 'Opłacany dokument.';es_ES = 'El documento que se ha pagado por.';es_CO = 'El documento que se ha pagado por.';tr = 'Ödeme yapılan belge.';it = 'Documento secondo cui il pagamento viene effettuato';de = 'Das Dokument, für das bezahlt wird.'");
		
		
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.FromVendor Then
		
		Array = New Array();
		Array.Add(Type("DocumentRef.ExpenseReport"));
		Array.Add(Type("DocumentRef.CashVoucher"));
		Array.Add(Type("DocumentRef.PaymentExpense"));
		Array.Add(Type("DocumentRef.ArApAdjustments"));
		Array.Add(Type("DocumentRef.AdditionalExpenses"));
		Array.Add(Type("DocumentRef.AccountSalesToConsignor"));
		Array.Add(Type("DocumentRef.SupplierInvoice"));
		Array.Add(Type("DocumentRef.SalesInvoice"));
		
		ValidTypes = New TypeDescription(Array,,);
		Items.PaymentDetailsDocument.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.PurchaseOrder",,);
		Items.PaymentDetailsOrder.TypeRestriction = ValidTypes;
		
		Items.PaymentDetailsDocument.ToolTip = NStr("en = 'An advance payment document that should be returned.'; ru = 'Документ расчетов с контрагентом, по которому осуществляется возврат денежных средств.';pl = 'Dokument płatności zaliczkowej do zwrotu.';es_ES = 'Un documento del pago anticipado que tiene que devolverse.';es_CO = 'Un documento del pago anticipado que tiene que devolverse.';tr = 'Geri dönmesi gereken bir avans ödeme belgesi.';it = 'Pagamento di un anticipo, documento che deve essere restituito.';de = 'Ein Vorauszahlungsbeleg, der zurückgegeben werden soll.'");
		
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.PaymentFromThirdParties Then
		
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
	
	If (Object.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.RetailIncome
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.RetailIncomeEarningAccounting)
		AND (Object.Item = Catalogs.CashFlowItems.PaymentToVendor
		OR Object.Item = Catalogs.CashFlowItems.Other) Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.FromVendor 
		AND (Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers
		OR Object.Item = Catalogs.CashFlowItems.Other) Then
		Object.Item = Catalogs.CashFlowItems.PaymentToVendor;
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.LoanSettlements
		And ValueIsFilled(Object.LoanContract) Then
		Object.Item = Common.ObjectAttributeValue(Object.LoanContract, "PrincipalItem");
	ElsIf (Object.OperationKind = Enums.OperationTypesCashReceipt.FromAdvanceHolder
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.CurrencyPurchase
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.LoanSettlements
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByEmployee
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByCounterparty
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.Other)
		AND (Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers
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
	
	If Object.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.RetailIncome
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.RetailIncomeEarningAccounting Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.FromVendor Then
		Object.Item = Catalogs.CashFlowItems.PaymentToVendor;
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.LoanSettlements
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
	
	If Constants.UseRetail.Get() Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashReceipt.RetailIncome);
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashReceipt.RetailIncomeEarningAccounting);
	EndIf;
	
	If Constants.ForeignExchangeAccounting.Get() Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashReceipt.CurrencyPurchase);
	EndIf;
	
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashReceipt.Other);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashReceipt.OtherSettlements);
	
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashReceipt.LoanRepaymentByEmployee);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashReceipt.LoanRepaymentByCounterparty);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashReceipt.LoanSettlements);
	
	If GetFunctionalOption("UseThirdPartyPayment") Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashReceipt.PaymentFromThirdParties);
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
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			False);
	ParametersStructure.Insert("FillHeader",			True);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	SetVisibleOfVATTaxation();
	SetVisibilitySettlementAttributes();
	SetVisibilityEPDAttributes();
	
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
		UUID
	);
	
EndFunction

// Function receives the SettlementsDetails tabular section from the temporary storage.
//
&AtServer
Procedure GetPaymentDetailsFromStorage(AddressPaymentDetailsInStorage)
	
	TableExplanationOfPayment = GetFromTempStorage(AddressPaymentDetailsInStorage);
	IsFromCustomer = Object.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer;
	
	Object.PaymentDetails.Clear();
	
	For Each RowPaymentDetails In TableExplanationOfPayment Do
		
		NewRow = Object.PaymentDetails.Add();
		FillPropertyValues(NewRow, RowPaymentDetails);
		
		If Object.OperationKind = Enums.OperationTypesCashReceipt.PaymentFromThirdParties Then
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
		EndIf;
	EndDo;
	
	If RecalculatePaymentAmount Then
		Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
	EndIf;
	
EndProcedure

&AtClient
Procedure DateOnChangeQueryBoxHandler(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		UpdatePaymentDetailsExchangeRateAtServer();
		RecalculateAmountsOnCashAssetsCurrencyRateChange(AdditionalParameters);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdatePaymentDetailsExchangeRateAtServer()
	
	For each TSRow In Object.PaymentDetails Do
			
		If ValueIsFilled(TSRow.Contract) Then
			StructureData = GetDataPaymentDetailsContractOnChange(
				Object.Date,
				TSRow.Contract
			);
			TSRow.ExchangeRate = ?(
				StructureData.ContractCurrencyRateRepetition.Rate = 0,
				1,
				StructureData.ContractCurrencyRateRepetition.Rate
			);
			TSRow.Multiplicity = ?(
				StructureData.ContractCurrencyRateRepetition.Repetition = 0,
				1,
				StructureData.ContractCurrencyRateRepetition.Repetition
			);
		EndIf;
		
	EndDo;
	
EndProcedure

// Recalculates amounts by the cash assets currency.
//
&AtClient
Procedure RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData)
	
	ExchangeRateBeforeChange = ExchangeRate;
	MultiplicityBeforeChange = Multiplicity;
	
	If ValueIsFilled(Object.CashCurrency) Then
		ExchangeRate = ?(
			StructureData.CurrencyRateRepetition.Rate = 0,
			1,
			StructureData.CurrencyRateRepetition.Rate
		);
		Multiplicity = ?(
			StructureData.CurrencyRateRepetition.Repetition = 0,
			1,
			StructureData.CurrencyRateRepetition.Repetition
		);
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.CurrencyPurchase") Then
			Object.ExchangeRate = ExchangeRate;
			Object.Multiplicity = Multiplicity;
		EndIf;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ExchangeRateBeforeChange", ExchangeRateBeforeChange);
	AdditionalParameters.Insert("MultiplicityBeforeChange", MultiplicityBeforeChange);
	
	DetermineNeedForDocumentAmountRecalculation(AdditionalParameters);
	
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

&AtClient
Procedure CalculateSettlmentsEPDAmount(TabularSectionRow)
	
	TabularSectionRow.ExchangeRate = ?(TabularSectionRow.ExchangeRate = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.SettlementsEPDAmount = TabularSectionRow.EPDAmount * ExchangeRate / Multiplicity
		/ TabularSectionRow.ExchangeRate * TabularSectionRow.Multiplicity;
	
EndProcedure

// Perform recalculation of the amount accounting.
//
&AtClient
Procedure CalculateAccountingAmount()
	
	Object.ExchangeRate = ?(Object.ExchangeRate = 0, 1, Object.ExchangeRate);
	Object.Multiplicity = ?(Object.Multiplicity = 0, 1, Object.Multiplicity);
	
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
	
	CounterpartyData = Common.ObjectAttributesValues(Counterparty,
		"DescriptionFull, DoOperationsByContracts, DoOperationsByOrders");
	
	ContractData = Common.ObjectAttributesValues(ContractByDefault, "SettlementsCurrency, CashFlowItem");
	
	StructureData.Insert("CounterpartyDescriptionFull", CounterpartyData.DescriptionFull);
	
	StructureData.Insert("Contract", ContractByDefault);
	StructureData.Insert("Item", ContractData.CashFlowItem);
	
	StructureData.Insert(
		"ContractCurrencyRateRepetition",
		CurrencyRateOperations.GetCurrencyRate(Date, ContractData.SettlementsCurrency, Company));
	
	StructureData.Insert("DoOperationsByContracts", CounterpartyData.DoOperationsByContracts);
	StructureData.Insert("DoOperationsByOrders", CounterpartyData.DoOperationsByOrders);
	
	If Object.OperationKind = Enums.OperationTypesCashReceipt.LoanSettlements Then
		DefaultLoanContract = GetDefaultLoanContract(Object.Ref, Counterparty, Company, Object.OperationKind);
		StructureData.Insert("DefaultLoanContract", DefaultLoanContract);
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByCounterparty Then
		StructureData.Insert("ConfigureLoanContractItem", True);	
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
Function GetDataAdvanceHolderOnChange(AdvanceHolder)
	
	StructureData = New Structure;
	
	StructureData.Insert("AdvanceHolderDescription", AdvanceHolder.Description);
	
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
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure;
	StructureData.Insert("ParentCompany", DriveServer.GetCompany(Object.Company));
	StructureData.Insert("ExchangeRateMethod", DriveServer.GetExchangeMethod(Object.Company));
	
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
	
	If Object.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer 
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.RetailIncomeEarningAccounting
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.RetailIncome Then
		
		Object.VATTaxation = DriveServer.VATTaxation(Object.Company, Object.Date);
		
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.FromAdvanceHolder
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.LoanSettlements
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByEmployee
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByCounterparty Then
		Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;		
	Else
		Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;		
	EndIf;
	
	If Not (Object.OperationKind = Enums.OperationTypesCashReceipt.FromAdvanceHolder
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.Other
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.CurrencyPurchase)
		And Not TaxationBeforeChange = Object.VATTaxation Then
		
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
		Items.RetailIncomePaymentDetailsVATRate.Visible				= True;
		Items.RetailRevenueDetailsOfPaymentAmountOfVat.Visible		= True;
		
		If Object.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer
			Or Object.OperationKind = Enums.OperationTypesCashReceipt.PaymentFromThirdParties
			Or Object.OperationKind = Enums.OperationTypesCashReceipt.FromVendor
			Or Object.OperationKind = Enums.OperationTypesCashReceipt.RetailIncome
			Or Object.OperationKind = Enums.OperationTypesCashReceipt.RetailIncomeEarningAccounting Then
			
			Items.VATAmount.Visible = True;
			
		Else
			
			Items.VATAmount.Visible = False;
			
		EndIf;
		
	Else
		
		Items.RetailIncomePaymentDetailsVATRate.Visible				= False;
		Items.RetailRevenueDetailsOfPaymentAmountOfVat.Visible		= False;
		Items.SettlementsOnCreditsPaymentDetailsVATRate.Visible		= False;
		Items.SettlementsOnCreditsPaymentDetailsVATAmount.Visible	= False;
		Items.PaymentDetailsVATRate.Visible							= False;
		Items.PaymentDetailsVatAmount.Visible						= False;
		Items.VATAmount.Visible										= False;
		
	EndIf;
	
	If Object.OperationKind = Enums.OperationTypesCashReceipt.RetailIncome
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.RetailIncomeEarningAccounting Then
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			Items.RetailIncomePaymentDetailsVATRate.Visible			= False;
			Items.RetailRevenueDetailsOfPaymentAmountOfVat.Visible	= False;
		Else
			Items.RetailIncomePaymentDetailsVATRate.Visible			= True;
			Items.RetailRevenueDetailsOfPaymentAmountOfVat.Visible	= True;
		EndIf;
		
	Else
		
		Items.RetailIncomePaymentDetailsVATRate.Visible			= False;
		Items.RetailRevenueDetailsOfPaymentAmountOfVat.Visible	= False;
		
	EndIf;
	
	If Object.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.PaymentFromThirdParties
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.FromVendor
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.RetailIncome
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.RetailIncomeEarningAccounting
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByEmployee Then
		
		Items.VATTaxation.Visible = RegisteredForVAT;
		
	Else
		
		Items.VATTaxation.Visible = False;
		
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
		TabularSectionRow.Multiplicity
	);
	
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
		
		RunActionsOnAccountsDocumentChange();
		
		Modified = True;
		
	EndIf;
	
EndProcedure

// Procedure determines an advance flag depending on the billing document type.
//
&AtClient
Procedure RunActionsOnAccountsDocumentChange()
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromVendor") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashVoucher")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.DebitNote") Then
			
			TabularSectionRow.AdvanceFlag = True;
			
		Else
			
			TabularSectionRow.AdvanceFlag = False;
			
		EndIf;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromCustomer") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.SalesInvoice") Then
			
			StructureData = GetStructureDataForObject(ThisObject, "PaymentDetails", TabularSectionRow);
			SetExistsEPD(StructureData);
			FillPropertyValues(TabularSectionRow, StructureData);
			
		EndIf;
		
		SetVisibilityCreditNoteText();
		
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
	
	Return Documents.SalesInvoice.CheckExistsEPD(Document, CheckDate);
	
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
	
	SetVisibilityCreditNoteText();
	
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
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",			True);
	ParametersStructure.Insert("FillHeader",			False);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
	FillAddedColumns(ParametersStructure);
	
	Modified = True;
	
	SetVisibilityCreditNoteText();
	
EndProcedure

// Procedure receives the default petty cash currency.
//
&AtServerNoContext
Function GetPettyCashAccountingCurrencyAtServer(Date, PettyCash, Company)
	
	StructureData = New Structure;
	StructureData.Insert("CashCurrency", Common.ObjectAttributeValue(PettyCash, "CurrencyByDefault"));
	
	StructureData.Insert("CurrencyRateRepetition",
		CurrencyRateOperations.GetCurrencyRate(Date, StructureData.CashCurrency, Company));
		
	Return StructureData;
	
EndFunction

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
		
		ContractKindList = New ValueList;
		ContractKindList.Add(Enums.LoanContractTypes.Borrowed);
		
		If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, LoanContract, Company, Counterparty, ContractKindList)
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
	
	If Object.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer Then
		
		DocumentsTable			= Object.PaymentDetails.Unload(, "Document");
		PaymentDetailsDocuments	= DocumentsTable.UnloadColumn("Document");
		
		Items.CreditNoteText.Visible = EarlyPaymentDiscountsServer.AvailableCreditNoteEPD(PaymentDetailsDocuments);
		
	Else
		
		Items.CreditNoteText.Visible = False;
		
	EndIf;
	
EndFunction

&AtServer
Procedure SetAccountingPolicyValues()
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Object.Company);
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	
EndProcedure

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
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromCustomer") Then
		Object.Correspondence = Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.CashCR = Undefined;
		Object.StructuralUnit = Undefined;
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
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromVendor") Then
		Object.Correspondence = Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.CashCR = Undefined;
		Object.StructuralUnit = Undefined;
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
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromAdvanceHolder") Then
		Object.Correspondence = Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
		Object.Counterparty = Undefined;
		Object.CashCR = Undefined;
		Object.StructuralUnit = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.ThirdPartyCustomer = Undefined;
			TableRow.ThirdPartyCustomerContract = Undefined;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.RetailIncome") Then
		Object.Counterparty = Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.StructuralUnit = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.ThirdPartyCustomer = Undefined;
			TableRow.ThirdPartyCustomerContract = Undefined;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.RetailIncomeEarningAccounting") Then
		Object.Counterparty = Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.CashCR = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.ThirdPartyCustomer = Undefined;
			TableRow.ThirdPartyCustomerContract = Undefined;
			TableRow.Document = Undefined;
			TableRow.SettlementsAmount = 0;
			TableRow.ExchangeRate = 0;
			TableRow.Multiplicity = 0;
			TableRow.Order = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.LoanSettlements") Then
		Object.Correspondence = Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.CashCR = Undefined;
		Object.StructuralUnit = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.ThirdPartyCustomer = Undefined;
			TableRow.ThirdPartyCustomerContract = Undefined;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee") Then
		Object.Correspondence = Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.CashCR = Undefined;
		Object.StructuralUnit = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.ThirdPartyCustomer = Undefined;
			TableRow.ThirdPartyCustomerContract = Undefined;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.LoanRepaymentByCounterparty") Then
		Object.Correspondence = Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.CashCR = Undefined;
		Object.StructuralUnit = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.ThirdPartyCustomer = Undefined;
			TableRow.ThirdPartyCustomerContract = Undefined;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.Other") Then
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.CashCR = Undefined;
		Object.StructuralUnit = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.ThirdPartyCustomer = Undefined;
			TableRow.ThirdPartyCustomerContract = Undefined;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.CurrencyPurchase") Then
		Object.Counterparty = Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.CashCR = Undefined;
		Object.StructuralUnit = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.ExchangeRate = ?(ValueIsFilled(ExchangeRate),
			ExchangeRate,
			1);
		Object.Multiplicity = ?(ValueIsFilled(Multiplicity),
			Multiplicity, 1);
		CalculateAccountingAmount();
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.ThirdPartyCustomer = Undefined;
			TableRow.ThirdPartyCustomerContract = Undefined;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.PaymentFromThirdParties") Then
		Object.Correspondence = Undefined;
		Object.IncomeItem = Undefined;
		Object.RegisterIncome = False;
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
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// The procedure is called when you click "PrintReceipt" on the command panel.
//
&AtClient
Procedure PrintReceipt(Command)
	
	If Object.SalesSlipNumber <> 0 Then
		MessageText = NStr("en = 'Cannot print the sales slip because it has already been printed on the fiscal register.'; ru = 'Чек уже пробит на фискальном регистраторе!';pl = 'Nie można wydrukować dokumentu sprzedaży, ponieważ został już wydrukowany w rejestratorze fiskalnym.';es_ES = 'No se puede imprimir el recibo de compra porque ya se ha imprimido en el registro fiscal.';es_CO = 'No se puede imprimir el recibo de compra porque ya se ha imprimido en el registro fiscal.';tr = 'Mali kayıtta daha önce yazdırıldığından satış fişi yazdırılamıyor.';it = 'Non è possibile stampare lo scontrino perché è stato già stampato nel registratore fiscale.';de = 'Der Kassenbeleg kann nicht gedruckt werden, da er bereits im Fiskalspeicher gedruckt wurde.'");
		CommonClientServer.MessageToUser(MessageText);
		
		Return;
	EndIf;
	
	ShowMessageBox = False;
	If DriveClient.CheckPossibilityOfReceiptPrinting(ThisForm, ShowMessageBox) Then
		
		If EquipmentManagerClient.RefreshClientWorkplace() Then
			
			NotifyDescription = New NotifyDescription("EnableFiscalRegistrarEnd", ThisObject);
			EquipmentManagerClient.OfferSelectDevice(NotifyDescription, "FiscalRegister",
					NStr("en = 'Select a fiscal register.'; ru = 'Выберите фискальный регистратор.';pl = 'Wybierz rejestrator fiskalny.';es_ES = 'Seleccionar un registro fiscal.';es_CO = 'Seleccionar un registro fiscal.';tr = 'Mali kayıt seçin.';it = 'Selezionare un registro fiscale.';de = 'Fiskalspeicher auswählen.'"), 
					NStr("en = 'The fiscal register is not connected.'; ru = 'Фискальный регистратор не подключен.';pl = 'Rejestrator fiskalny nie jest podłączony.';es_ES = 'El registro fiscal no está conectado.';es_CO = 'El registro fiscal no está conectado.';tr = 'Mali kayıt bağlanmadı.';it = 'Il registratore fiscale non è collegato.';de = 'Der Fiskalspeicher ist nicht verbunden.'"));
			                     
		Else
			
			MessageText = NStr("en = 'First, you need to select a cashier workplace for the current session.'; ru = 'Предварительно необходимо выбрать рабочее место кассира для текущего сеанса.';pl = 'Najpierw musisz wybrać stanowiska kasjera dla bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar un lugar de trabajo del cajero para la sesión actual.';es_CO = 'Primero, usted necesita seleccionar un lugar de trabajo del cajero para la sesión actual.';tr = 'İlk olarak, mevcut oturum için kasiyer çalışma alanı seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare una postazione di lavoro di cassiere per la sessione corrente.';de = 'Zunächst müssen Sie einen Kassierer-Arbeitsplatz für die aktuelle Sitzung auswählen.'");
			CommonClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	ElsIf ShowMessageBox Then
		ShowMessageBox(Undefined, NStr("en = 'Cannot post the cash receipt.'; ru = 'Не удалось выполнить проведение документа.';pl = 'Nie można zatwierdzić dowodu wpłaty.';es_ES = 'No se puede enviar el recibo de efectivo.';es_CO = 'No se puede enviar el recibo de efectivo.';tr = 'Nakit tahsilat kaydedilemiyor.';it = 'Non è possibile registrare l''entrata di cassa.';de = 'Fehler beim Buchen des Zahlungseingangs.'"));
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
			
			// Preparation of the product table
			ProductsTable = New Array();
			
			ProductsTableRow = New ValueList();
			ProductsTableRow.Add(NStr("en = 'Payment from:'; ru = 'Оплата от:';pl = 'Płatność od:';es_ES = 'Pago de:';es_CO = 'Pago de:';tr = 'Şuradan alınan ödeme:';it = 'Pagamento da:';de = 'Zahlung von:'") + " " + Object.AcceptedFrom + Chars.LF
			+ NStr("en = 'Purpose:'; ru = 'Основание:';pl = 'Przeznaczenie:';es_ES = 'Propósito:';es_CO = 'Propósito:';tr = 'Amaç:';it = 'Motivo:';de = 'Zweck:'") + " " + Object.Basis); //  1 - Description
			ProductsTableRow.Add("");					   //  2 - Barcode
			ProductsTableRow.Add("");					   //  3 - SKU
			ProductsTableRow.Add(SectionNumber);			   //  4 - Department number
			ProductsTableRow.Add(Object.DocumentAmount);  //  5 - Price for position without discount
			ProductsTableRow.Add(1);					   //  6 - Quantity
			ProductsTableRow.Add("");					   //  7 - Discount description
			ProductsTableRow.Add(0);					   //  8 - Discount amount
			ProductsTableRow.Add(0);					   //  9 - Discount percentage
			ProductsTableRow.Add(Object.DocumentAmount);  // 10 - Position amount with discount
			ProductsTableRow.Add(0);					   // 11 - Tax number (1)
			ProductsTableRow.Add(0);					   // 12 - Tax amount (1)
			ProductsTableRow.Add(0);					   // 13 - Tax percent (1)
			ProductsTableRow.Add(0);					   // 14 - Tax number (2)
			ProductsTableRow.Add(0);					   // 15 - Tax amount (2)
			ProductsTableRow.Add(0);					   // 16 - Tax percent (2)
			ProductsTableRow.Add("");					   // 17 - Section name of commodity string formatting
			
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
			CommonParameters.Add(0);						//  1 - Receipt type
			CommonParameters.Add(True);				//  2 - Fiscal receipt sign
			CommonParameters.Add(Undefined);			//  3 - Print on lining document
			CommonParameters.Add(Object.DocumentAmount); //  4 - the receipt amount without discounts
			CommonParameters.Add(Object.DocumentAmount); //  5 - the receipt amount after applying all discounts
			CommonParameters.Add("");					//  6 - Discount card number
			CommonParameters.Add("");					//  7 - Header text
			CommonParameters.Add("");					//  8 - Footer text
			CommonParameters.Add(0);						//  9 - Session number (for receipt copy)
			CommonParameters.Add(0);						// 10 - Receipt number (for receipt copy)
			CommonParameters.Add(0);						// 11 - Document No (for receipt copy)
			CommonParameters.Add(0);						// 12 - Document date (for receipt copy)
			CommonParameters.Add("");					// 13 - Cashier name (for receipt copy)
			CommonParameters.Add("");					// 14 - Cashier password
			CommonParameters.Add(0);						// 15 - Template number
			CommonParameters.Add("");					// 16 - Section name header format
			CommonParameters.Add("");					// 17 - Section name cellar format
			
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
				Modified = True;
				Write(New Structure("WriteMode", DocumentWriteMode.Posting));
				
			Else
				MessageText = NStr("en = 'Cannot print the sales slip on the fiscal register. Details: %AdditionalDetails%'; ru = 'При печати чека произошла ошибка. Чек не напечатан на фискальном регистраторе. Дополнительное описание: %AdditionalDetails%';pl = 'Nie można wydrukować dokumentu sprzedaży w rejestratorze fiskalnym. Szczegóły: %AdditionalDetails%';es_ES = 'No se puede imprimir el recibo de compra en el registro fiscal. Detalles: %AdditionalDetails%';es_CO = 'No se puede imprimir el recibo de compra en el registro fiscal. Detalles: %AdditionalDetails%';tr = 'Mali kaydedicideki satış fişini yazdıramıyor. Ayrıntılar: %AdditionalDetails%';it = 'Non è possibile stampare lo scontrino nel registratore fiscale. Dettagli: %AdditionalDetails%';de = 'Der Kassenbeleg kann nicht auf dem Fiskalspeicher gedruckt werden. Details: %AdditionalDetails%'");
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

// Procedure - handler of the Execute event of the Pickup command
// Opens the form of debt forming documents selection.
//
&AtClient
Procedure Pick(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(Undefined,NStr("en = 'Please select a counterparty.'; ru = 'Сначала выберите контрагента.';pl = 'Wybierz kontrahenta.';es_ES = 'Por favor, seleccione un contraparte.';es_CO = 'Por favor, seleccione un contraparte.';tr = 'Lütfen, cari hesap seçin.';it = 'Si prega di selezionare una controparte.';de = 'Bitte wählen Sie einen Geschäftspartner aus.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.CashCurrency) Then
		ShowMessageBox(Undefined,NStr("en = 'Please select a currency.'; ru = 'Выберите валюту.';pl = 'Proszę wybrać walutę.';es_ES = 'Por favor, selecciona una moneda.';es_CO = 'Por favor, selecciona una moneda.';tr = 'Lütfen para birimini seçin.';it = 'Si prega di selezionare una valuta.';de = 'Bitte wählen Sie eine Währung aus.'"));
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
	
	OpenForm("CommonForm.SelectInvoicesToBePaidByTheCustomer", SelectionParameters,,,,, New NotifyDescription("SelectionEnd", ThisObject, New Structure("AddressPaymentDetailsInStorage", AddressPaymentDetailsInStorage)));
	
EndProcedure

&AtClient
Procedure SelectionEnd(Result, AdditionalParameters) Export
	
	AddressPaymentDetailsInStorage = AdditionalParameters.AddressPaymentDetailsInStorage;
	
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
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), 
		NStr("en = 'Do you want to refill the cash receipt?'; ru = 'Документ будет полностью перезаполнен по основанию. Продолжить?';pl = 'Czy chcesz uzupełnić rachunek gotówkowy?';es_ES = '¿Quiere volver a rellenar el recibo de efectivo?';es_CO = '¿Quiere volver a rellenar el recibo de efectivo?';tr = 'Nakit tahsilatını yeniden doldurmak istiyor musunuz?';it = 'Volete ricompilare l''entrata di cassa?';de = 'Möchten Sie den Zahlungseingang auffüllen?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		
		FillByDocument(Object.BasisDocument);
		
		If Object.PaymentDetails.Count() = 0 Then
			Object.PaymentDetails.Add();
			Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		EndIf;
		
		OperationKind = Object.OperationKind;
		CashCurrency = Object.CashCurrency;
		DocumentDate = Object.Date;
		
		SetChoiceParameterLinksAvailableTypes();
		SetCurrentPage();
		
	EndIf;

EndProcedure

// Procedure - FillDetails command handler.
//
&AtClient
Procedure FillDetails(Command)
	
	If Object.DocumentAmount = 0
		And Object.OperationKind <> PredefinedValue("Enum.OperationTypesCashReceipt.FromVendor") Then
		ShowMessageBox(Undefined, NStr("en = 'Please specify the amount.'; ru = 'Введите сумму.';pl = 'Podaj wartość.';es_ES = 'Por favor, especifique el importe.';es_CO = 'Por favor, especifique el importe.';tr = 'Lütfen, tutarı belirtin.';it = 'Si prega di specificare l''importo.';de = 'Bitte geben Sie den Betrag an.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.CashCurrency) Then
		ShowMessageBox(Undefined, NStr("en = 'Please select a currency.'; ru = 'Выберите валюту.';pl = 'Proszę wybrać walutę.';es_ES = 'Por favor, selecciona una moneda.';es_CO = 'Por favor, selecciona una moneda.';tr = 'Lütfen para birimini seçin.';it = 'Si prega di selezionare una valuta.';de = 'Bitte wählen Sie eine Währung aus.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(Undefined,NStr("en = 'Please select a counterparty.'; ru = 'Выберите контрагента.';pl = 'Wybierz kontrahenta.';es_ES = 'Por favor, seleccione un contraparte.';es_CO = 'Por favor, seleccione un contraparte.';tr = 'Lütfen, cari hesap seçin.';it = 'Si prega di selezionare una controparte.';de = 'Bitte wählen Sie einen Geschäftspartner aus.'"));
		Return;
	EndIf;
	
	ShowQueryBox(New NotifyDescription("FillDetailsEnd", ThisObject), 
		NStr("en = 'You are about to fill in the payment details. This will overwrite the current details. Do you want to continue?'; ru = 'Расшифровка будет полностью перезаполнена. Продолжить?';pl = 'Zamierzasz wypełnić szczegóły płatności. Spowoduje to nadpisanie bieżących szczegółów. Czy chcesz kontynuować?';es_ES = 'Usted está a punto de rellenar los detalles de pago. Eso sobrescribirá los detalles actuales. ¿Quiere continuar?';es_CO = 'Usted está a punto de rellenar los detalles de pago. Eso sobrescribirá los detalles actuales. ¿Quiere continuar?';tr = 'Ödeme ayrıntılarını doldurmak üzeresiniz. Bu işlem mevcut ayrıntıların üzerine yazacaktır. Devam etmek istiyor musunuz?';it = 'State compilando i dettagli di pagamento. Questo sovrascriverà i dettagli correnti. Volete continuare?';de = 'Sie sind dabei, die Zahlungsdaten auszufüllen. Dadurch werden die aktuellen Details überschrieben. Möchten Sie fortsetzen?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillDetailsEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	Object.PaymentDetails.Clear();
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromCustomer") Then
		
		FillPaymentDetails();
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.PaymentFromThirdParties") Then
		
		FillThirdPartyPaymentDetails();
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromVendor") Then
		
		FillAdvancesPaymentDetails();
		
	EndIf;
	
	SetCurrentPage();

EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

// Procedure - event handler OnChange of the Counterparty input field.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	StructureData = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company, Object.Date);
	
	If Not ValueIsFilled(Object.AcceptedFrom) Then
		Object.AcceptedFrom = StructureData.CounterpartyDescriptionFull;
	EndIf;
	
	FillPaymentDetailsByContractData(StructureData);
	
	If StructureData.Property("DefaultLoanContract") Then
		Object.LoanContract = StructureData.DefaultLoanContract;
		HandleChangeLoanContract();
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
	ParentCompany = StructureData.ParentCompany;
	ExchangeRateMethod = StructureData.ExchangeRateMethod;

	ProcessingCompanyVATNumbers(False);
	
	If ValueIsFilled(Object.Counterparty) Then 
		
		StructureContractData = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company, Object.Date);
	
		FillPaymentDetailsByContractData(StructureContractData);
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of
// the Currency input field Recalculates the PaymentDetails tabular section.
//
&AtClient
Procedure CashAssetsCurrencyOnChange(Item)
	
	CurrencyCashBeforeChanging = CashCurrency;
	CashCurrency = Object.CashCurrency;
	
	// If currency is not changed, do nothing.
	If CashCurrency = CurrencyCashBeforeChanging Then
		Return;
	EndIf;
	
	StructureData = GetDataCashAssetsCurrencyOnChange(
		Object.Date,
		Object.CashCurrency,
		Object.Company
	);
	
	RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData);
	
EndProcedure

// Procedure - OnChange event handler of the AdvanceHolder input field.
// Clears the AdvanceHolders document.
//
&AtClient
Procedure AdvanceHolderOnChange(Item)
	
	If OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee") 
		OR OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.LoanSettlements") Then
		
		DataStructure = GetEmployeeDataOnChange(Object.AdvanceHolder, Object.Date, Object.Company);
	
		If Not ValueIsFilled(Object.AcceptedFrom) Then
			Object.AcceptedFrom = DataStructure.AdvanceHolderDescription;
		EndIf;
		
		Object.LoanContract = DataStructure.LoanContract;
		
		HandleChangeLoanContract();
		
	ElsIf Not ValueIsFilled(Object.AcceptedFrom) Then
		StructureData = GetDataAdvanceHolderOnChange(Object.AdvanceHolder);
		Object.AcceptedFrom = StructureData.AdvanceHolderDescription;
	EndIf;
		
EndProcedure

// Procedure - OnChange event handler of the DocumentAmount input field.
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
	
	CalculateAccountingAmount();
	
EndProcedure

// Procedure - OnChange event handler of the CashCR input field.
//
&AtClient
Procedure CashCROnChange(Item)
	
	FillVATRateByCompanyVATTaxation();
	SetVisibleOfVATTaxation();
	
EndProcedure

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	FillVATRateByCompanyVATTaxation();
	SetVisibleOfVATTaxation();
	
EndProcedure

// Procedure - OnChange event handler of the VATTaxation input field.
//
&AtClient
Procedure VATTaxationOnChange(Item)
	
	FillVATRateByVATTaxation();
	SetVisibleOfVATTaxation();
	
EndProcedure

// Procedure - OnChange event handler of the PettyCash input field.
//
&AtClient
Procedure PettyCashOnChange(Item)
	
	CurrencyCashBeforeChanging = CashCurrency;
	
	StructureData = GetPettyCashAccountingCurrencyAtServer(Object.Date, Object.PettyCash, Object.Company);
	
	Object.CashCurrency = StructureData.CashCurrency;
	CashCurrency = StructureData.CashCurrency;
	
	// If currency is not changed, do nothing.
	If CashCurrency = CurrencyCashBeforeChanging Then
		Return;
	EndIf;
	
	RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData);
	
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
		WorkWithVATClient.OpenTaxInvoice(ThisForm, False, True);
	Else
		CommonClientServer.MessageToUser(
			NStr("en = 'There are no rows with advance payments in the Payment details tab'; ru = 'В табличной части Расшифровка платежа отсутствуют авансовые платежи';pl = 'Na karcie Szczegóły płatności nie ma wierszy z zaliczkami';es_ES = 'No hay filas con los pagos anticipados en la pestaña de los Detalles de pago';es_CO = 'No hay filas con los pagos anticipados en la pestaña de los Detalles de pago';tr = 'Ödeme ayrıntıları sekmesinde avans ödemeye sahip herhangi bir satır yok';it = 'Non ci sono righe con anticipo pagamenti il nella scheda dettagli di pagamento';de = 'Auf der Registerkarte Zahlungsdetails gibt es keine Zeilen mit Vorauszahlungen'"));
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
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromVendor") Then
			CurrentData = Items.PaymentDetails.CurrentData;
			CurrentData.AdvanceFlag = True;
		ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.FromCustomer") Then
			CurrentData.DiscountAllowedExpenseItem = DefaultExpenseItem;
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

// Procedure - OnChange event handler of the PaymentDetailsSettlementsKind input field.
// Clears an attribute document if a settlement type is - "Advance".
//
&AtClient
Procedure PaymentDetailsAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromCustomer") Then
		
		If TabularSectionRow.AdvanceFlag Then
			TabularSectionRow.Document = Undefined;
		Else
			TabularSectionRow.PlanningDocument = Undefined;
		EndIf;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromVendor") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashVoucher")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.DebitNote")
			Or TabularSectionRow.Document = Undefined Then
			
			If Not TabularSectionRow.AdvanceFlag Then
				TabularSectionRow.AdvanceFlag = True;
				ShowMessageBox(, NStr("en = 'Cannot clear the ""Advance payment"" check box for this operation type.'; ru = 'Невозможно снять флажок ""Авансовый платеж"" для данного типа операций.';pl = 'Nie można oczyścić pola wyboru ""Zaliczka"" dla tego typu operacji.';es_ES = 'No se puede vaciar la casilla de verificación ""Pago anticipado"" para este tipo de operación.';es_CO = 'No se puede vaciar la casilla de verificación ""Pago anticipado"" para este tipo de operación.';tr = 'Bu işlem türü için ""Avans ödeme"" onay kutusu temizlenemez.';it = 'Impossibile cancellare la casella di controllo ""Pagamento Anticipato"" per questo tipo di operazione.';de = 'Das Kontrollkästchen ""Vorauszahlung"" für diesen Operationstyp kann nicht deaktiviert werden.'"));
			EndIf;
			
		ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.ArApAdjustments") Then
			
			If TabularSectionRow.AdvanceFlag Then
				TabularSectionRow.AdvanceFlag = False;
				ShowMessageBox(, NStr("en = 'Cannot select the ""Advance payment"" check box for this operation type.'; ru = 'Для данного типа документа расчетов нельзя установить признак аванса.';pl = 'Nie można wybrać pola wyboru ""Zaliczka"" dla tego typu operacji.';es_ES = 'No se puede seleccionar la casilla de verificación ""Pago anticipado"" para este tipo de operación.';es_CO = 'No se puede seleccionar la casilla de verificación ""Pago anticipado"" para este tipo de operación.';tr = 'Bu işlem türü için ""Avans ödeme"" onay kutusu seçilemez.';it = 'Non è possibile selezionare la casella di controllo ""Pagamento Anticipato"" per questo tipo di operazione.';de = 'Das Kontrollkästchen ""Vorauszahlung"" kann für diesen Operationstyp nicht aktiviert werden.'"));
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
		AND Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromCustomer") Then
		
		ShowMessageBox(, NStr("en = 'This is a billing document for advance payments.'; ru = 'Это документ расчета для авансовых платежей.';pl = 'Jest to dokument rozliczeniowy dla płatności zaliczkowych.';es_ES = 'Este es un documento de facturación para pagos anticipados.';es_CO = 'Este es un documento de facturación para pagos anticipados.';tr = 'Avans ödemeler için fatura belgesidir.';it = 'Questo è un documento di fatturazione per pagamenti anticipati.';de = 'Dies ist ein Abrechnungsbeleg für Vorauszahlungen.'"));
		
	Else
		
		StructureFilter = New Structure();
		StructureFilter.Insert("Company", Object.Company);
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.PaymentFromThirdParties") Then
			
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
			
			ThisIsAccountsReceivable = OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromCustomer");
			
			StructureFilter.Insert("Counterparty", Object.Counterparty);
			
			If ValueIsFilled(TabularSectionRow.Contract) Then
				StructureFilter.Insert("Contract", TabularSectionRow.Contract);
			EndIf;
			
			ParameterStructure = New Structure("Filter, ThisIsAccountsReceivable, DocumentType",
				StructureFilter,
				ThisIsAccountsReceivable,
				TypeOf(Object.Ref));
				
			ParameterStructure.Insert("IsSupplierReturn", Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromVendor"));
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

// Procedure - OnChange event handler of the PaymentDetailsExchangeRate input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsRateOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculateSettlmentsAmount(TabularSectionRow);
	CalculateSettlmentsEPDAmount(TabularSectionRow);
	
EndProcedure

// Procedure - OnChange event handler of the PaymentDetailsUnitConversionFactor input field.
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
	ParametersStructure.Insert("GetGLAccounts",			False);
	ParametersStructure.Insert("FillHeader",			False);
	ParametersStructure.Insert("FillPaymentDetails",	True);
	
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

// Procedure - OnChange event handler of the RetailIncomePaymentDetailsVATRate input field.
//
&AtClient
Procedure RetailIncomePaymentDetailsVATRateOnChange(Item)
	
	TabularSectionRow = Items.PlanningDocumentsPaymentDetails.CurrentData;
	CalculateVATAmountAtClient(TabularSectionRow);
	
EndProcedure

// Procedure - OnChange event handler of the CurrencyPurchaseRate input field.
//
&AtClient
Procedure CurrencyPurchaseRateOnChange(Item)
	
	CalculateAccountingAmount();
	
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
	
	Object.ExchangeRate = ?(
		Object.ExchangeRate = 0,
		1,
		Object.ExchangeRate
	);
	
	Object.Multiplicity = ?(
		Object.Multiplicity = 0,
		1,
		Object.Multiplicity
	);
	
	Object.ExchangeRate = ?(
		Object.DocumentAmount = 0,
		1,
		Object.AccountingAmount / Object.DocumentAmount * AccountingCurrencyRate
	);
	
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

#Region InteractiveActionResultHandlers

// Procedure-handler of a result of the question on document amount recalculation. 
//
//
&AtClient
Procedure DetermineNeedForDocumentAmountRecalculation(AdditionalParameters) Export
	
	If Object.PaymentDetails.Count() > 0 Then
		
		RecalculateDocumentAmounts(ExchangeRate, Multiplicity, False);
		
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.CurrencyPurchase") Then
		CalculateAccountingAmount();
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
	
	If Object.OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByEmployee
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByCounterparty Then
		FillInformationAboutLoanAtServer();
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.LoanSettlements Then
		FillInformationAboutCreditAtServer();
	EndIf;
	
EndProcedure

&AtServer
Procedure ConfigureLoanContractItem()
	
	If Object.OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByEmployee Then
		
		Items.BorrowerLoanAgreement.Enabled = NOT Object.AdvanceHolder.IsEmpty();
		If Items.BorrowerLoanAgreement.Enabled Then
			Items.BorrowerLoanAgreement.InputHint = "";
		Else
			Items.BorrowerLoanAgreement.InputHint = NStr("en = 'To select a contract, select an employee first.'; ru = 'Чтобы выбрать договор, выберите сотрудника';pl = 'Aby wybrać umowę, najpierw wybierz pracownika.';es_ES = 'Para seleccionar un contrato, seleccionar primero un empleado.';es_CO = 'Para seleccionar un contrato, seleccionar primero un empleado.';tr = 'Bir sözleşme seçmek için, ilk önce bir çalışan seçin.';it = 'Per selezionare un contratto selezionare un impiegato prima di tutto.';de = 'Um einen Vertrag auszuwählen, wählen Sie zuerst einen Mitarbeiter aus.'");
		EndIf;
		
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByCounterparty Then
		
		Items.BorrowerLoanAgreement.Enabled = NOT Object.Counterparty.IsEmpty();
		If Items.BorrowerLoanAgreement.Enabled Then
			Items.BorrowerLoanAgreement.InputHint = "";
		Else
			Items.BorrowerLoanAgreement.InputHint = NStr("en = 'To select a contract, select a counterparty first.'; ru = 'Чтобы выбрать договор, выберите контрагента.';pl = 'Aby wybrać kontrakt, najpierw wybierz kontrahenta.';es_ES = 'Para seleccionar un contrato, seleccionar primero una contrapartida.';es_CO = 'Para seleccionar un contrato, seleccionar primero una contrapartida.';tr = 'Bir sözleşme seçmek için, ilk önce bir cari hesap seçin.';it = 'Per selezionare un contratto, selezionare prima una controparte.';de = 'Um einen Vertrag auszuwählen, wählen Sie zuerst einen Geschäftspartner aus.'");
		EndIf;
		
	EndIf;
	
	Items.CreditContract.Enabled = NOT Object.Counterparty.IsEmpty();
	If Items.CreditContract.Enabled Then
		Items.CreditContract.InputHint = "";
	Else
		Items.CreditContract.InputHint = NStr("en = 'To select a contract, select a bank first.'; ru = 'Чтобы выбрать договор, выберите банк';pl = 'Aby wybrać umowę, najpierw wybierz bank.';es_ES = 'Para seleccionar un contrato, seleccionar primero un banco.';es_CO = 'Para seleccionar un contrato, seleccionar primero un banco.';tr = 'Bir sözleşme seçmek için, ilk önce bir banka seçin.';it = 'Per selezionare un contratto selezionare una banca prima di tutto.';de = 'Um einen Vertrag auszuwählen, wählen Sie zuerst eine Bank aus.'");
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
	
	ResultArray = Query.ExecuteBatch();
	
	If Object.LoanContract.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement
		OR Object.LoanContract.LoanKind = Enums.LoanContractTypes.CounterpartyLoanAgreement Then
		Multiplier = 1;
	Else
		Multiplier = -1;
	EndIf;
	
	InformationAboutLoan = "";
	
	SelectionSchedule = ResultArray[0].SElECT();
	SelectionScheduleFutureMonth = ResultArray[2].SElECT();
	
	LabelCreditContractInformationTextColor = StyleColors.BorderColor;
	LabelRemainingDebtByCreditTextColor = StyleColors.BorderColor;
	
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
			NStr("en = 'Payment date: %1. Debt amount: %2. Interest: %3. Commission: %4 (%5).'; ru = 'Дата платежа: %1. Сумма долга: %2. Проценты %: %3. Комиссия: %4 (%5).';pl = 'Data płatności: %1. Kwota długu: %2. Odsetki: %3. Prowizja: %4 (%5).';es_ES = 'Fecha de pago: %1. Importe de la deuda:%2. Interés: %3. Comisión: %4 (%5).';es_CO = 'Fecha de pago: %1. Importe de la deuda:%2. Interés: %3. Comisión: %4 (%5).';tr = 'Ödeme tarihi: %1. Borç tutarı: %2. Faiz: %3. Komisyon: %4 (%5).';it = 'Data di pagamento %1. Importo del debito: %2. Interessi: %3. Commissioni: %4 (%5)';de = 'Zahlungstermin: %1. Schuldenbetrag: %2. Zinsen: %3. Provisionszahlung: %4 (%5)'"),
			PaymentDate,
			Format(SelectionScheduleFutureMonth.Principal, 	"NFD=2; NZ=0"),
			Format(SelectionScheduleFutureMonth.Interest, 	"NFD=2; NZ=0"),
			Format(SelectionScheduleFutureMonth.Commission, "NFD=2; NZ=0"),
			SelectionScheduleFutureMonth.CurrencyPresentation);
		
	ElsIf SelectionSchedule.Next() Then
		
		If BegOfMonth(?(Object.Date = '00010101', CurrentSessionDate(), Object.Date)) = BegOfMonth(SelectionSchedule.Period) Then
			PaymentDate = Format(SelectionSchedule.Period, "DLF=D");
		Else
		
			PaymentDate = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 (not in the current month)'; ru = '%1 (не в текущем месяце)';pl = '%1 (nie w bieżącym miesiącu)';es_ES = '%1(no en el mes actual)';es_CO = '%1(no en el mes actual)';tr = '%1(mevcut ayda değil)';it = '%1 (non nel mese corrente)';de = '%1(nicht im aktuellen Monat)'"),
				Format(SelectionSchedule.Period, "DLF=D"));
			LabelCreditContractInformationTextColor = StyleColors.FormTextColor;
			
		EndIf;
			
		LabelCreditContractInformation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Payment date: %1. Debt amount: %2. Interest: %3. Commission: %4 (%5).'; ru = 'Дата платежа: %1. Сумма долга: %2. Проценты %: %3. Комиссия: %4 (%5).';pl = 'Data płatności: %1. Kwota długu: %2. Odsetki: %3. Prowizja: %4 (%5).';es_ES = 'Fecha de pago: %1. Importe de la deuda:%2. Interés: %3. Comisión: %4 (%5).';es_CO = 'Fecha de pago: %1. Importe de la deuda:%2. Interés: %3. Comisión: %4 (%5).';tr = 'Ödeme tarihi: %1. Borç tutarı: %2. Faiz: %3. Komisyon: %4 (%5).';it = 'Data di pagamento %1. Importo del debito: %2. Interessi: %3. Commissioni: %4 (%5)';de = 'Zahlungstermin: %1. Schuldenbetrag: %2. Zinsen: %3. Provisionszahlung: %4 (%5)'"),
			PaymentDate, 
			Format(SelectionSchedule.Principal, 	"NFD=2; NZ=0"),
			Format(SelectionSchedule.Interest, 		"NFD=2; NZ=0"),
			Format(SelectionSchedule.Commission, 	"NFD=2; NZ=0"), 
			SelectionSchedule.CurrencyPresentation);
		
	Else
		
		LabelCreditContractInformation = NStr("en = 'Payment date: <not specified>'; ru = 'Дата платежа: <не указана>';pl = 'Data płatności: <nieokreślona>';es_ES = 'Fecha de pago: <no especificado>';es_CO = 'Fecha de pago: <no especificado>';tr = 'Ödeme tarihi: <belirtilmemiş>';it = 'Data di pagamento: <non specificata>';de = 'Zahlungstermin: <Nicht eingegeben>'");
		
	EndIf;
	
	
	SelectionBalance = ResultArray[1].SElECT();
	If SelectionBalance.Next() Then
		
		LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Debt balance: %1. Interest: %2. Commission: %3 (%4).'; ru = 'Остаток долга: %1. Проценты %: %2. Комиссия: %3 (%4).';pl = 'Saldo zadłużenia: %1. Odsetki: %2. Prowizja: %3 (%4).';es_ES = 'Saldo de la deuda: %1. Interés: %2. Comisión:%3 (%4).';es_CO = 'Saldo de la deuda: %1. Interés: %2. Comisión:%3 (%4).';tr = 'Borç bakiyesi: %1. Faiz: %2. Komisyon: %3 (%4).';it = 'Saldo debito: %1. Interesse: %2. Commissione: %3 (%4).';de = 'Schuldensaldo: %1. Zinsen: %2Provisionszahlung: %3 (%4)'"),
			Format(Multiplier * SelectionBalance.PrincipalDebtCurBalance, 	"NFD=2; NZ=0"),
			Format(Multiplier * SelectionBalance.InterestCurBalance, 		"NFD=2; NZ=0"),
			Format(Multiplier * SelectionBalance.CommissionCurBalance, 		"NFD=2; NZ=0"),
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
	
	Items.LabelCreditContractInformation.Title	= LabelCreditContractInformation;
	Items.LabelRemainingDebtByCredit.Title		= LabelRemainingDebtByCredit;
	
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
		Object.CashCurrency = Selection.Currency;
		
		LabelCreditContractInformation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Loan amount: %1 (%2)'; ru = 'Сумма займа: %1 (%2)';pl = 'Kwota pożyczki: %1 (%2)';es_ES = 'Importe del préstamo: %1 (%2)';es_CO = 'Importe del préstamo: %1 (%2)';tr = 'Kredi tutarı: %1 (%2)';it = 'L''importo del prestito: %1 (%2)';de = 'Darlehensbetrag: %1 (%2)'"),
			Selection.Total,
			Selection.Currency);
		
		If Selection.Total < Selection.PrincipalDebtCurExpense Then
			
			LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Remaining loan amount: %1 (%2). Received loan amount: %3 (%2).'; ru = 'Остаток суммы займа: %1 (%2). Полученная сумма займа: %3 (%2).';pl = 'Pozostała kwota pożyczki: %1 (%2). Otrzymana kwota pożyczki: %3 (%2).';es_ES = 'Importe del préstamo restante: %1 (%2). Importe del préstamo recibid: %3 (%2).';es_CO = 'Importe del préstamo restante: %1 (%2). Importe del préstamo recibid: %3 (%2).';tr = 'Kalan kredi tutarı: %1 (%2). Alınan kredi tutarı: %3 (%2).';it = 'Importo prestito rimanente: %1 (%2). Importo prestito ricevuto: %3 (%2).';de = 'Verbleibender Darlehensbetrag: %1 (%2). Erhaltener Darlehensbetrag: %3 (%2)'"),
				(Selection.Total - Selection.PrincipalDebtCurExpense),
				Selection.Currency,
				Selection.PrincipalDebtCurExpense);
			LabelRemainingDebtByCreditTextColor = StyleColors.SpecialTextColor;
			
		ElsIf Selection.Total = Selection.PrincipalDebtCurExpense Then
			
			LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Remaining loan amount: 0 (%1)'; ru = 'Остаток суммы займа: 0 (%1)';pl = 'Pozostała kwota pożyczki: 0 (%1)';es_ES = 'Importe del préstamo restante: 0 (%1)';es_CO = 'Importe del préstamo restante: 0 (%1)';tr = 'Kalan kredi tutarı: 0 (%1)';it = 'Importo prestito rimanente: 0 (%1)';de = 'Darlehensrückstand: 0 (%1)'"),
				Selection.Currency);
			LabelRemainingDebtByCreditTextColor = StyleColors.SpecialTextColor;
			
		Else
			
			LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Remaining loan amount: %1 (%2). Received loan amount: %3 (%2)'; ru = 'Остаток суммы займа: %1 (%2). Полученная сумма займа: %3 (%2)';pl = 'Pozostała kwota pożyczki: %1 (%2). Otrzymana kwota pożyczki: %3 (%2)';es_ES = 'Importe del préstamo restante: %1 (%2). Importe del préstamo recibid: %3 (%2)';es_CO = 'Importe del préstamo restante: %1 (%2). Importe del préstamo recibid: %3 (%2)';tr = 'Kalan kredi tutarı: %1 (%2). Alınan kredi tutarı: %3 (%2)';it = 'Importo rimanente del prestito: %1 (%2). Importo ricevuto del prestito: %3 (%2)';de = 'Verbleibender Darlehensbetrag: %1 (%2). Erhaltener Darlehensbetrag: %3 (%2)'"),
				(Selection.Total - Selection.PrincipalDebtCurExpense), 
				Selection.Currency,
				Selection.PrincipalDebtCurExpense);
				
		EndIf;
	Else
		
		LabelCreditContractInformation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Loan amount: %1 (%2)'; ru = 'Сумма займа: %1 (%2)';pl = 'Kwota pożyczki: %1 (%2)';es_ES = 'Importe del préstamo: %1 (%2)';es_CO = 'Importe del préstamo: %1 (%2)';tr = 'Kredi tutarı: %1 (%2)';it = 'L''importo del prestito: %1 (%2)';de = 'Darlehensbetrag: %1 (%2)'"),
			Object.LoanContract.Total,
			Object.LoanContract.SettlementsCurrency);
		
		LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Balance to receive: %1 (%2)'; ru = 'Остаток к получению: %1 (%2)';pl = 'Saldo do otrzymania: %1 (%2)';es_ES = 'Saldo a recibir: %1 (%2)';es_CO = 'Saldo a recibir: %1 (%2)';tr = 'Alınacak bakiye: %1 (%2)';it = 'Saldo da ricevere: %1 (%2)';de = 'BIlanz zum Erhalten: %1 (%2)'"),
			Object.LoanContract.Total,
			Object.LoanContract.SettlementsCurrency);
			
	EndIf;
	
	Items.LabelCreditContractInformation.Title		= LabelCreditContractInformation;
	Items.LabelRemainingDebtByCredit.Title			= LabelRemainingDebtByCredit;
	
	Items.LabelCreditContractInformation.TextColor	= LabelCreditContractInformationTextColor;
	Items.LabelRemainingDebtByCredit.TextColor		= LabelRemainingDebtByCreditTextColor;
	
EndProcedure

&AtClient
Procedure HandleChangeLoanContract()
	
	EmployeeLoanAgreementData	= EmployeeLoanContractOnChange(Object.LoanContract, Object.Date);
	Object.CashCurrency			= EmployeeLoanAgreementData.Currency;
	
	FillInformationAboutCreditLoanAtServer();
	
	CashCurrencyBeforeChange	= CashCurrency;
	CashCurrency				= Object.CashCurrency;
	
	If CashCurrency = CashCurrencyBeforeChange Then
		Return;
	EndIf;
	                  
	DataStructure = GetDataCashAssetsCurrencyOnChange(
		Object.Date,
		Object.CashCurrency,
		Object.Company
	);
	
	RecalculateAmountsOnCashAssetsCurrencyRateChange(DataStructure);
	
EndProcedure

&AtServerNoContext
Function GetDefaultLoanContract(Document, Counterparty, Company, OperationKind)
	
	DocumentManager = Documents.LoanContract;
	
	ContractKindList = New ValueList;
	ContractKindList.Add(?(OperationKind = Enums.OperationTypesCashReceipt.LoanSettlements, 
		Enums.LoanContractTypes.Borrowed,
		Enums.LoanContractTypes.EmployeeLoanAgreement));
	                                                   
	DefaultLoanContract = DocumentManager.ReceiveLoanContractByDefaultByCompanyLoanKind(Counterparty, Company, ContractKindList);
	
	Return DefaultLoanContract;
	
EndFunction

&AtServerNoContext
Function EmployeeLoanContractOnChange(EmployeeLoanContract, Date)
	
	DataStructure = New Structure;
	
	DataStructure.Insert("Currency", 			EmployeeLoanContract.SettlementsCurrency);
	DataStructure.Insert("Counterparty",		EmployeeLoanContract.Counterparty);
	DataStructure.Insert("Employee",			EmployeeLoanContract.Employee);
	DataStructure.Insert("ThisIsLoanContract",	EmployeeLoanContract.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement
														Or EmployeeLoanContract.LoanKind = Enums.LoanContractTypes.CounterpartyLoanAgreement);
	
	Return DataStructure;
	 	
EndFunction

&AtClient
Procedure EmployeeLoanAgreementOnChange(Item)
	HandleChangeLoanContract();
EndProcedure

&AtServerNoContext
Function GetEmployeeDataOnChange(Employee, Date, Company)
	
	DataStructure = GetDataAdvanceHolderOnChange(Employee);
	
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
		ShowMessageBox(Undefined, NStr("en = 'Select a contract'; ru = 'Выберите договор';pl = 'Wybierz umowę';es_ES = 'Seleccionar un contrato';es_CO = 'Seleccionar un contrato';tr = 'Bir sözleşme seçin';it = 'Selezionare un contratto';de = 'Einen Vertrag auswählen'"));
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
	
	FillDocumentAmount = False;
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
Procedure FillByCreditContract(Command)
	
	If Object.LoanContract.IsEmpty() Then
		ShowMessageBox(Undefined, NStr("en = 'Select a contract'; ru = 'Выберите договор';pl = 'Wybierz umowę';es_ES = 'Seleccionar un contrato';es_CO = 'Seleccionar un contrato';tr = 'Bir sözleşme seçin';it = 'Selezionare un contratto';de = 'Einen Vertrag auswählen'"));
		Return;
	EndIf;
	
	FillByLoanContractAtServer();
	DocumentAmountOnChange(Items.DocumentAmount);
	
EndProcedure

&AtServer
Procedure FillByLoanContractAtServer()
	
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
	|	LoanContract.Total";
	
	Query.SetParameter("LoanContract",	Object.LoanContract);
	Query.SetParameter("Company",		Object.Company);
	Query.SetParameter("Ref",			Object.Ref);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		
		Object.CashCurrency = Selection.Currency;
		
		MessageText = "";
		
		If Selection.Total < Selection.PrincipalDebtCurExpense Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Issued under the loan contract: %1 (%2).'; ru = 'Выдано по договору займа: %1 (%2).';pl = 'Wydano według umowy pożyczki: %1 (%2).';es_ES = 'Emitido bajo el contrato de préstamo:%1 (%2)';es_CO = 'Emitido bajo el contrato de préstamo:%1 (%2)';tr = 'Kredi sözleşmesi kapsamında verilen %1(%2).';it = 'Emesso in base a contratto di prestito %1 (%2)';de = 'Ausgestellt unter dem Darlehensvertrag %1 (%2)'"),
				Selection.PrincipalDebtCurExpense,
				Selection.Currency);
		ElsIf Selection.Total = Selection.PrincipalDebtCurExpense Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The complete amount has been already issued under the loan contract: %1 (%2).'; ru = 'По договору займа уже выдана вся сумма %1 (%2).';pl = 'Cała wartość w ramach umowy pożyczki została już wydana %1 (%2).';es_ES = 'El importe completo se ha emitido bajo el contrato de préstamo: %1 (%2).';es_CO = 'El importe completo se ha emitido bajo el contrato de préstamo: %1 (%2).';tr = 'Toplam tutar önceden kredi sözleşmesi kapsamında zaten verildi: %1 (%2).';it = 'L''importo completo è già stato emesso in base al contratto di prestito %1 (%2)';de = 'Die gesamte Menge wurde bereits im Rahmen des Darlehensvertrags %1 (%2) ausgegeben.'"),
				Selection.PrincipalDebtCurExpense,
				Selection.Currency);
		Else
			Object.DocumentAmount = Selection.Total - Selection.PrincipalDebtCurExpense;
			Object.CashCurrency = Selection.Currency;
		EndIf;
		
		If MessageText <> "" Then
			CommonClientServer.MessageToUser(MessageText,, "BorrowerLoanAgreement");
		EndIf;
	Else
		Object.DocumentAmount	= Object.LoanContract.Total;
		Object.CashCurrency		= Object.LoanContract.SettlementsCurrency;
	EndIf;
	
	Modified = True;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

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

#Region FormManagement

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	ColorTextSpecifiedInDocument = StyleColors.TextSpecifiedInDocument;
	
	// PaymentDetailsPlanningDocument
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.OperationKind");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= Enums.OperationTypesCashReceipt.FromCustomer;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.PaymentDetails.AdvanceFlag");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = '<specified only for advance>'; ru = '<указывается только для аванса>';pl = '<wypełnia się tylko dla zaliczki>';es_ES = '<especificado solo para el anticipo>';es_CO = '<especificado solo para el anticipo>';tr = '<sadece peşinler için belirtilir>';it = '<Indicato solo per anticipo>';de = '<nur für Vorschuss angegeben>'"));
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
	
EndProcedure

&AtServer
Procedure SetVisibilityAttributesDependenceOnCorrespondence()
	
	SetVisibilityPlanningDocument();
	SetVisibilityProject();
	
EndProcedure

&AtServer
Procedure SetVisibilityProject()
	
	Items.PaymentDetailsProject.Visible = False;
	Items.PaymentDetailsOtherSettlementsProject.Visible = False;
	
	IncomeItemType = Common.ObjectAttributeValue(Object.IncomeItem, "IncomeAndExpenseType");
	
	If Object.OperationKind = Enums.OperationTypesCashReceipt.Other
		And (IncomeItemType = Catalogs.IncomeAndExpenseTypes.Revenue
			Or IncomeItemType = Catalogs.IncomeAndExpenseTypes.OtherIncome) Then
		
		Items.PaymentDetailsProject.Visible = True;
		
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.OtherSettlements Then
		
		Items.PaymentDetailsProject.Visible = True;
		Items.PaymentDetailsOtherSettlementsProject.Visible = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetVisibilityItemsDependenceOnOperationKind()
	
	Items.PaymentDetailsPaymentAmount.Visible					= UseForeignCurrency;
	Items.PaymentDetailsOtherSettlementsPaymentAmount.Visible = UseForeignCurrency;
	
	Items.SettlementsWithCounterparty.Visible				= False;
	Items.SettlementsWithAdvanceHolder.Visible				= False;
	Items.RetailIncome.Visible								= False;
	Items.RetailIncomeEarningAccounting.Visible				= False;
	Items.CurrencyPurchase.Visible							= False;
	Items.AdvanceHoldersPaymentDetailsPaymentAmount.Visible	= False;
	Items.OtherSettlements.Visible							= False;
	Items.PaymentDetailsOtherSettlements.Visible			= False;
	Items.PlanningDocuments.Title							= NStr("en = 'Planning'; ru = 'Планирование';pl = 'Planowanie';es_ES = 'Planificando';es_CO = 'Planificando';tr = 'Planlama';it = 'Pianificazione';de = 'Planung'");
	Items.DocumentAmount.Width								= 14;
	Items.AdvanceHolder.Visible								= False;
	Items.Counterparty.Visible								= False;
	Items.Item.Visible										= True;
	
	Items.Item.Visible										= True;
	Items.PaymentDetailsItem.Visible						= False;
	
	// Miscellaneous payable
	Items.LoanSettlements.Visible	    	= False;
	Items.LoanSettlements.Title		        = NStr("en = 'Loan account statement'; ru = 'Расчеты по кредитам';pl = 'Wyciąg z rachunku kredytowego';es_ES = 'Declaración de la cuenta de préstamo';es_CO = 'Declaración de la cuenta de préstamo';tr = 'Kredi hesabı ekstresi';it = 'Resoconto prestiti';de = 'Darlehenskontoauszug'");
	Items.BorrowerLoanAgreement.Visible		= False;
	Items.FillByLoanContract.Visible		= False;
	Items.CreditContract.Visible			= False;
	Items.FillByCreditContract.Visible		= False;
	Items.GroupContractInformation.Visible	= False;
	Items.AdvanceHolder.Visible				= False;
	// End Miscellaneous payable
	
	Items.PaymentDetailsPlanningDocument.Visible = True;
	Items.PaymentDetailsSignAdvance.Visible = True;
	Items.PaymentDetailsThirdPartyCustomer.Visible = False;
	Items.PaymentDetailsThirdPartyCustomerContract.Visible = False;
	
	DocMetadata = Metadata.Documents.CashReceipt;
	
	BasisDocumentTypes = DocMetadata.Attributes.BasisDocument.Type;
	Items.BasisDocument.TypeRestriction = New TypeDescription(BasisDocumentTypes, , "DocumentRef.CashTransferPlan");
	
	PlanningDocumentTypes = DocMetadata.TabularSections.PaymentDetails.Attributes.PlanningDocument.Type;
	PlanningDocumentTypeRestriction = New TypeDescription(PlanningDocumentTypes, , "DocumentRef.CashTransferPlan");
	Items.PaymentDetailsPlanningDocument.TypeRestriction = PlanningDocumentTypeRestriction;
	Items.PaymentDetailsOtherSettlementsPlanningDocument.TypeRestriction = PlanningDocumentTypeRestriction;
	Items.AdvanceHoldersPaymentAccountDetailsForPayment.TypeRestriction = PlanningDocumentTypeRestriction;
	Items.SettlementsOnCreditsPaymentDetailsPlanningDocument.TypeRestriction = PlanningDocumentTypeRestriction;
	
	Items.PaymentDetailsContract.Title = "";
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromCustomer") Then
		
		Items.SettlementsWithCounterparty.Visible	= True;
		Items.PaymentDetailsPickup.Visible			= True;
		Items.PaymentDetailsFillDetails.Visible		= True;
		
		SetChoiceParametersForCounterparty("Customer");
		
		Items.Counterparty.Visible	= True;
		Items.Counterparty.Title	= NStr("en = 'Customer'; ru = 'Покупатель';pl = 'Nabywca';es_ES = 'Cliente';es_CO = 'Cliente';tr = 'Müşteri';it = 'Cliente';de = 'Kunde'");
		
		Items.PaymentAmount.Visible		= True;
		Items.PaymentAmount.Title		=  NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'");
		Items.SettlementsAmount.Visible	= Not UseForeignCurrency;
		
		Items.PaymentDetailsItem.Visible = True;
		Items.Item.Visible = False;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.PaymentFromThirdParties") Then
		
		Items.SettlementsWithCounterparty.Visible	= True;
		Items.PaymentDetailsPickup.Visible			= True;
		Items.PaymentDetailsFillDetails.Visible		= True;
		
		Items.PaymentDetailsPlanningDocument.Visible	= False;
		Items.PaymentDetailsSignAdvance.Visible			= False;
		
		Items.PaymentDetailsThirdPartyCustomer.Visible			= True;
		Items.PaymentDetailsThirdPartyCustomerContract.Visible	= True;
		
		SetChoiceParametersForCounterparty("OtherRelationship");
		
		Items.Counterparty.Visible			= True;
		Items.Counterparty.Title			= NStr("en = 'Third-party payer'; ru = 'Сторонний плательщик';pl = 'Płatnik strony trzeciej';es_ES = 'Pago por terceros';es_CO = 'Pago por terceros';tr = 'Üçüncü taraf ödeyen';it = 'Terza parte pagatrice';de = 'Drittzahler'");
		Items.PaymentDetailsContract.Title	= NStr("en = 'Third-party payer''s contract'; ru = 'Договор со сторонним плательщиком';pl = 'Kontrakt płatnika strony trzeciej';es_ES = 'Contrato del cliente de terceros';es_CO = 'Contrato del cliente de terceros';tr = 'Üçüncü taraf ödeyenin sözleşmesi';it = 'Contratto cliente terza parte';de = 'Vertrag von Drittzahler'");
		
		Items.PaymentAmount.Visible		= True;
		Items.PaymentAmount.Title		=  NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'");
		Items.SettlementsAmount.Visible	= Not UseForeignCurrency;
		
		Items.PaymentDetailsItem.Visible = True;
		Items.Item.Visible = False;
		
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.FromVendor Then
		
		Items.SettlementsWithCounterparty.Visible	= True;
		Items.PaymentDetailsPickup.Visible			= False;
		Items.PaymentDetailsFillDetails.Visible		= True;
		
		SetChoiceParametersForCounterparty("Supplier");
		
		Items.Counterparty.Visible	= True;
		Items.Counterparty.Title	= NStr("en = 'Supplier'; ru = 'Поставщик';pl = 'Dostawca';es_ES = 'Proveedor';es_CO = 'Proveedor';tr = 'Tedarikçi';it = 'Fornitore';de = 'Lieferant'");
		
		Items.PaymentAmount.Visible		= True;
		Items.PaymentAmount.Title		= NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'");
		Items.SettlementsAmount.Visible	= Not UseForeignCurrency;
		
		Items.PaymentDetailsItem.Visible = True;
		Items.Item.Visible = False;
		
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.FromAdvanceHolder Then
		
		Items.SettlementsWithAdvanceHolder.Visible	= True;
		
		Items.AdvanceHoldersPaymentDetailsPaymentAmount.Visible	= GetFunctionalOption("PaymentCalendar");
		
		Items.AdvanceHolder.Visible	= True;
		Items.DocumentAmount.Width	= 13;
		
		Items.PaymentAmount.Visible		= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title		= ?(GetFunctionalOption("PaymentCalendar"), NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'"), NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'"));
		Items.SettlementsAmount.Visible	= False;
		
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.RetailIncome Then
		
		Items.AdvanceHoldersPaymentDetailsPaymentAmount.Visible	= GetFunctionalOption("PaymentCalendar");
		Items.RetailIncome.Visible								= True;
		
		Items.PaymentAmount.Visible		= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title		= ?(GetFunctionalOption("PaymentCalendar"), 
			NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'"), 
			NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'"));
		Items.SettlementsAmount.Visible = False;
		
		Items.BasisDocument.TypeRestriction = New TypeDescription;
		Items.PaymentDetailsPlanningDocument.TypeRestriction = New TypeDescription;
		Items.PaymentDetailsOtherSettlementsPlanningDocument.TypeRestriction = New TypeDescription;
		Items.AdvanceHoldersPaymentAccountDetailsForPayment.TypeRestriction = New TypeDescription;
		Items.SettlementsOnCreditsPaymentDetailsPlanningDocument.TypeRestriction = New TypeDescription;
		
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.RetailIncomeEarningAccounting Then
		
		Items.AdvanceHoldersPaymentDetailsPaymentAmount.Visible	= GetFunctionalOption("PaymentCalendar");
		Items.RetailIncomeEarningAccounting.Visible				= True;
		
		Items.PaymentAmount.Visible		= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title		= ?(GetFunctionalOption("PaymentCalendar"), NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'"), NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'"));
		Items.SettlementsAmount.Visible = False;
		
		Items.BasisDocument.TypeRestriction = New TypeDescription;
		Items.PaymentDetailsPlanningDocument.TypeRestriction = New TypeDescription;
		Items.PaymentDetailsOtherSettlementsPlanningDocument.TypeRestriction = New TypeDescription;
		Items.AdvanceHoldersPaymentAccountDetailsForPayment.TypeRestriction = New TypeDescription;
		Items.SettlementsOnCreditsPaymentDetailsPlanningDocument.TypeRestriction = New TypeDescription;
		
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.CurrencyPurchase Then
		
		Items.AdvanceHoldersPaymentDetailsPaymentAmount.Visible	= GetFunctionalOption("PaymentCalendar");
		
		Items.CurrencyPurchase.Visible	= True;
		
		Items.PaymentAmount.Visible 		= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"), NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'"), NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'"));
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		
	// Miscellaneous payable	
	ElsIf OperationKind = Enums.OperationTypesCashReceipt.LoanSettlements Then
		
		SetChoiceParametersForCounterparty("OtherRelationship");
		
		Items.LoanSettlements.Visible					= True;
		Items.Counterparty.Visible							= True;
		Items.Counterparty.Title							= NStr("en = 'Lender'; ru = 'Заимодатель';pl = 'Pożyczkodawca';es_ES = 'Prestamista';es_CO = 'Prestador';tr = 'Borç veren';it = 'Finanziatore';de = 'Darlehensgeber'");;
		Items.LoanSettlements.Visible					= True;
		Items.SettlementsOnCreditsPaymentDetails.Visible	= False;	
		Items.CreditContract.Visible						= True;
		Items.FillByCreditContract.Visible					= True;
		
		FillInformationAboutCreditLoanAtServer();
		SetCFItem();
		
		Items.GroupContractInformation.Visible = True;
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.PaymentAmount.Title			= NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'");
		Items.SettlementsAmount.Visible		= False;
		
		Items.AdvanceHoldersPaymentDetailsPaymentAmount.Visible = GetFunctionalOption("PaymentCalendar");
		
		Items.OtherSettlementsCorrespondence.Title = NStr("en = 'Cr account'; ru = 'Счет Кт';pl = 'Konto Ma';es_ES = 'Cuenta de crédito';es_CO = 'Cuenta de crédito';tr = 'Alacak hesabı';it = 'Conto Cred.';de = 'Haben Konto'");
		
	ElsIf OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByEmployee Then
		
		Items.AdvanceHolder.Visible							= True;
		Items.LoanSettlements.Title							= NStr("en = 'Loan account statement'; ru = 'Расчеты по кредитам';pl = 'Wyciąg z rachunku kredytowego';es_ES = 'Declaración de la cuenta de préstamo';es_CO = 'Declaración de la cuenta de préstamo';tr = 'Kredi hesabı ekstresi';it = 'Resoconto prestiti';de = 'Darlehenskontoauszug'");
		Items.LoanSettlements.Visible						= True;
		Items.SettlementsOnCreditsPaymentDetails.Visible	= True;		
		Items.BorrowerLoanAgreement.Visible					= True;
		Items.FillByLoanContract.Visible					= True;
		Items.Item.Visible									= False;
		
		FillInformationAboutCreditLoanAtServer();
		SetCFItem();
		
		Items.GroupContractInformation.Visible	= True;	
		Items.PaymentAmount.Visible				= UseForeignCurrency;
		Items.PaymentAmount.Title				= NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'");
		Items.SettlementsAmount.Visible			= True;
		
		Items.SettlementsOnCreditsPaymentDetailsPaymentAmount.Visible = UseForeignCurrency;
		
		Items.OtherSettlementsCorrespondence.Title = NStr("en = 'Cr account'; ru = 'Счет Кт';pl = 'Konto Ma';es_ES = 'Cuenta de crédito';es_CO = 'Cuenta de crédito';tr = 'Alacak hesabı';it = 'Conto Cred.';de = 'Haben Konto'");
		
	ElsIf OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByCounterparty Then
		
		SetChoiceParametersForCounterparty("OtherRelationship");
		
		Items.Counterparty.Visible							= True;
		Items.Counterparty.Title							= NStr("en = 'Borrower'; ru = 'Заемщик';pl = 'Pożyczkobiorca';es_ES = 'Prestatario';es_CO = 'Prestatario';tr = 'Borçlanan';it = 'Mutuatario';de = 'Darlehensnehmer'");
		Items.LoanSettlements.Title							= NStr("en = 'Loan account statement'; ru = 'Расчеты по кредитам';pl = 'Wyciąg z rachunku kredytowego';es_ES = 'Declaración de la cuenta de préstamo';es_CO = 'Declaración de la cuenta de préstamo';tr = 'Kredi hesabı ekstresi';it = 'Resoconto prestiti';de = 'Darlehenskontoauszug'");
		Items.LoanSettlements.Visible						= True;
		Items.SettlementsOnCreditsPaymentDetails.Visible	= True;		
		Items.BorrowerLoanAgreement.Visible					= True;
		Items.FillByLoanContract.Visible					= True;
		Items.Item.Visible									= False;
		
		FillInformationAboutCreditLoanAtServer();
		SetCFItem();
		
		Items.GroupContractInformation.Visible	= True;	
		Items.PaymentAmount.Visible				= UseForeignCurrency;
		Items.PaymentAmount.Title				= NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'");
		Items.SettlementsAmount.Visible			= True;
		
		Items.SettlementsOnCreditsPaymentDetailsPaymentAmount.Visible = UseForeignCurrency;
		
		Items.OtherSettlementsCorrespondence.Title = NStr("en = 'Cr account'; ru = 'Счет Кт';pl = 'Konto Ma';es_ES = 'Cuenta de crédito';es_CO = 'Cuenta de crédito';tr = 'Alacak hesabı';it = 'Conto Cred.';de = 'Haben Konto'");
		
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.Other Then
		
		Items.OtherSettlements.Visible	= True;
		Items.PaymentDetailsOtherSettlements.Visible	= True;
		
		Items.PaymentAmount.Visible 		= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"), 
			NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'"), 
			NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'"));
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		
		Items.Counterparty.Visible	= True;
		Items.Counterparty.Title	= NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'");
		
		Items.AdvanceHoldersPaymentDetailsPaymentAmount.Visible	= GetFunctionalOption("PaymentCalendar");
		
		Items.PaymentDetailsOtherSettlements.Visible		= False;
		
		Items.BasisDocument.TypeRestriction = New TypeDescription;
		Items.PaymentDetailsPlanningDocument.TypeRestriction = New TypeDescription;
		Items.PaymentDetailsOtherSettlementsPlanningDocument.TypeRestriction = New TypeDescription;
		Items.AdvanceHoldersPaymentAccountDetailsForPayment.TypeRestriction = New TypeDescription;
		Items.SettlementsOnCreditsPaymentDetailsPlanningDocument.TypeRestriction = New TypeDescription;
		
		Items.OtherSettlementsCorrespondence.Title = NStr("en = 'Credit account'; ru = 'Кредитовый счет';pl = 'Konto kredytowe';es_ES = 'Cuenta de crédito';es_CO = 'Cuenta de crédito';tr = 'Alacak hesabı';it = 'Conto credito';de = 'Haben-Konto'"); 
		
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.OtherSettlements Then
		
		Items.OtherSettlements.Visible	= True;
		Items.PaymentDetailsOtherSettlements.Visible	= True;
		
		Items.PaymentAmount.Visible			= False;
		Items.PaymentAmount.Title			= NStr("en = 'Payment amount'; ru = 'Сумма платежа';pl = 'Kwota płatności';es_ES = 'Importe de pago';es_CO = 'Importe de pago';tr = 'Ödeme tutarı';it = 'Importo del pagamento';de = 'Zahlungsbetrag'");
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		
		SetChoiceParametersForCounterparty("OtherRelationship");
		
		Items.Counterparty.Visible	= True;
		Items.Counterparty.Title	= NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'");
		
		Items.PaymentDetailsOtherSettlementsContract.Visible = Object.Counterparty.DoOperationsByContracts;
		Items.PaymentDetailsOtherSettlements.Visible = True;
		
		Items.OtherSettlementsCorrespondence.Title = NStr("en = 'Credit account'; ru = 'Кредитовый счет';pl = 'Konto kredytowe';es_ES = 'Cuenta de crédito';es_CO = 'Cuenta de crédito';tr = 'Alacak hesabı';it = 'Conto credito';de = 'Haben-Konto'");
		
		If Object.PaymentDetails.Count() > 0 Then
			ID = Object.PaymentDetails[0].GetID();
			Items.PaymentDetailsOtherSettlements.CurrentRow = ID;
		EndIf;
		
	// End Miscellaneous payable	
	Else
		
		Items.AdvanceHoldersPaymentDetailsPaymentAmount.Visible = GetFunctionalOption("PaymentCalendar");
		Items.OtherSettlements.Visible	= True;
		Items.PaymentDetailsOtherSettlements.Visible = True;
		Items.PaymentAmount.Visible		= True;
		Items.PaymentAmount.Title		= NStr("en = 'Amount (planned)'; ru = 'Сумма (план)';pl = 'Kwota (planowana)';es_ES = 'Importe (planificado)';es_CO = 'Importe (planificado)';tr = 'Tutar (planlanan)';it = 'Importo (pianificato)';de = 'Betrag (geplant)'");
		Items.SettlementsAmount.Visible	= False;
		
	EndIf;
	
	SetVisibilityAttributesDependenceOnCorrespondence();
	
EndProcedure

&AtServer
Procedure SetVisibilityPlanningDocument()
	
	If Object.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.FromVendor
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.PaymentFromThirdParties
		Or (Not GetFunctionalOption("PaymentCalendar")
		And Items.RetailIncomePaymentDetailsVATRate.Visible = False
		And Items.RetailRevenueDetailsOfPaymentAmountOfVat.Visible = False)
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.OtherSettlements
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.LoanSettlements
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByEmployee
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByCounterparty Then
		Items.PlanningDocuments.Visible = False;
	Else
		Items.PlanningDocuments.Visible = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetVisibilitySettlementAttributes()
	
	If ValueIsFilled(Object.Counterparty) Then
		DoOperationsStructure = Common.ObjectAttributesValues(
			Object.Counterparty, 
			"DoOperationsByContracts,DoOperationsByOrders");
	Else
		DoOperationsStructure = New Structure("DoOperationsByContracts,DoOperationsByOrders",
			False,
			False,
			False);
	EndIf;
	
	Items.PaymentDetailsContract.Visible					= DoOperationsStructure.DoOperationsByContracts;
	Items.PaymentDetailsOrder.Visible						= DoOperationsStructure.DoOperationsByOrders;
	Items.PaymentDetailsOtherSettlementsContract.Visible= DoOperationsStructure.DoOperationsByContracts;
	
EndProcedure

&AtServer
Procedure SetVisibilityEPDAttributes()
	
	OperationKindFromCustomer = (Object.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer);
	
	VisibleFlag = (ValueIsFilled(Object.Counterparty) AND OperationKindFromCustomer);
	
	Items.PaymentDetailsEPDAmount.Visible				= VisibleFlag;
	Items.PaymentDetailsSettlementsEPDAmount.Visible	= VisibleFlag;
	Items.PaymentDetailsExistsEPD.Visible				= VisibleFlag;
	
EndProcedure

&AtClient
Procedure SetVisibleCommandFillByBasis()
	
	Result = False;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromCustomer") Then
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
	
	IsOtherOperation = (OperationKind = Enums.OperationTypesCashReceipt.Other);
	
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

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion