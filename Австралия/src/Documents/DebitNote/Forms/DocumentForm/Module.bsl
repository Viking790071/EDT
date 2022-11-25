
#Region Variables

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
	ParametersStructure.Insert("FillAmountAllocation", True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	AdjustmentAmount = Object.AdjustedAmount;
	
	If Object.OperationKind <> PredefinedValue("Enum.OperationTypesDebitNote.PurchaseReturn")
			And Object.OperationKind <> PredefinedValue("Enum.OperationTypesDebitNote.DropShipping") Then
		AdjustmentAmount = AdjustmentAmount	+ ?(Object.AmountIncludesVAT, 0, Object.VATAmount);
	EndIf;
	
	CheckGoodsReturn(Cancel);
	
	If Not Cancel And Object.AmountAllocation.Count() <> 0
		AND Object.AmountAllocation.Total("OffsetAmount") <> AdjustmentAmount Then
		
		Cancel = True;
		Notify = New NotifyDescription("FillAllocationEnd", ThisObject);
		ShowQueryBox(Notify, 
					 NStr("en = 'The total of amount allocation does not match the amount of the document.
					      |Do you want to refill the tabular section?'; 
					      |ru = 'Итог распределения суммы не соответствует сумме документа.
					      |Перезаполнить табличную часть?';
					      |pl = 'Wartość opisu alokacji nie odpowiada wartości dokumentu.
					      |Czy chcesz ponownie wypełnić sekcję tabelaryczną?';
					      |es_ES = 'El total de la asignación de importes no coincide con el importe del documento.
					      |¿Quiere volver a rellenar la sección tabular?';
					      |es_CO = 'El total de la asignación de importes no coincide con el importe del documento.
					      |¿Quiere volver a rellenar la sección tabular?';
					      |tr = 'Toplam dağıtım tutarı belgenin tutarıyla eşleşmez.
					      |Tablo bölümünü yeniden doldurmak istiyor musunuz?';
					      |it = 'Il totale di importo di allocazione non corrisponde all''importo del documento.
					      |Volete ricompilare le sezioni tabellari?';
					      |de = 'Die Summe der Verteilung stimmt nicht mit dem Betrag des Belegs überein.
					      |Möchten Sie den Tabellenteil nachfüllen?'"),
					 QuestionDialogMode.YesNo, 0);
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	AmountsHaveChanged = WorkWithVAT.CalculateVATPerInvoiceTotal(CurrentObject);
	
	If AmountsHaveChanged And (Object.OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn
			Or Object.OperationKind = Enums.OperationTypesDebitNote.DropShipping) Then
		CurrentObject.AdjustedAmount = CurrentObject.Inventory.Total("Total");
		CurrentObject.VATAmount = CurrentObject.Inventory.Total("VATAmount");
	EndIf;
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "Document.TaxInvoiceReceived.Form.DocumentForm" Then
		TaxInvoiceText = SelectedValue;
	ElsIf GLAccountsInDocumentsClient.IsGLAccountsChoiceProcessing(ChoiceSource.FormName) Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshTaxInvoiceText" 
		AND TypeOf(Parameter) = Type("Structure") 
		AND Not Parameter.BasisDocuments.Find(Object.Ref) = Undefined Then
		TaxInvoiceText = Parameter.Presentation;
	ElsIf EventName = "SerialNumbersSelection"
		AND ValueIsFilled(Parameter) 
		// Form owner checkup
		AND Source = UUID Then
		GetSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
	EndIf;
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.CheckBasis(Object, Parameters.Basis, Cancel);
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues);
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	Contract = Object.Contract;
	
	If Not ValueIsFilled(Object.Ref)
		And Not ValueIsFilled(Parameters.Basis)
		And Not ValueIsFilled(Parameters.CopyingValue) Then
		
		FillVATRateByCompanyVATTaxation();
		
	EndIf;
	
	If ValueIsFilled(Parameters.CopyingValue)
		And ValueIsFilled(Object.BasisDocument) 
		And Not ValueIsFilled(Object.Ref)
		And Object.OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn Then
		
		FillByDocument(Object.BasisDocument);
		
	EndIf;
	
	If ValueIsFilled(Contract) Then
		SettlementCurrency = Common.ObjectAttributeValue(Contract, "SettlementsCurrency");
	EndIf;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting
		And Not ValueIsFilled(Object.Ref)
		And Not ValueIsFilled(Parameters.CopyingValue) Then
		SetDefaultValuesForGLAccount();
	EndIf;

	FunctionalCurrency				= DriveReUse.GetFunctionalCurrency();
	StructureByCurrency				= CurrencyRateOperations.GetCurrencyRate(Object.Date, FunctionalCurrency, Object.Company);
	ExchangeRateNationalCurrency	= StructureByCurrency.Rate;
	MultiplicityNationalCurrency	= StructureByCurrency.Repetition;
	
	SetAccountingPolicyValues();
	
	If GetFunctionalOption("UseAccountPayableAdjustments") Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesDebitNote.Adjustments);
	EndIf;
	
	If GetFunctionalOption("UseDropShipping") Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesDebitNote.DropShipping);
	EndIf;
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	SetContractVisible();
	
	// Generate price and currency label.
	ForeignExchangeAccounting	= GetFunctionalOption("ForeignExchangeAccounting");
	LabelStructure		= New Structure();
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementCurrency);
	LabelStructure.Insert("Rate",							Object.ExchangeRate);
	LabelStructure.Insert("RateNationalCurrency",			ExchangeRateNationalCurrency);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency	= DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", True);
	
	FillAddedColumns(ParametersStructure);
	
	SendGoodsOnConsignment 	= GetFunctionalOption("SendGoodsOnConsignment");
	// begin Drive.FullVersion
	UseProductionSubsystem 	= GetFunctionalOption("UseProductionSubsystem");
	// end Drive.FullVersion
	
	WorkWithVAT.SetTextAboutTaxInvoiceReceived(ThisObject);
	
	ProcessingCompanyVATNumbers();
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	SetFormConditionalAppearance();
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
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
	
	DriveServer.CheckObjectGeneratedEnteringBalances(ThisObject);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	FormManagement();
	SetAdjustedAmountTitle();
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesDebitNote.PurchaseReturn")
			Or Object.OperationKind = PredefinedValue("Enum.OperationTypesDebitNote.DropShipping") Then
		CalculateTotal();
	EndIf;
	
	If Parameters.Key.IsEmpty() Then
		WorkWithVATClient.ShowReverseChargeNotSupportedMessage(Object.VATTaxation);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If TypeOf(FormOwner) = Type("ClientApplicationForm") Then
		
		If Find(FormOwner.FormName, "CashVoucher") > 0
			OR Find(FormOwner.FormName, "PaymentExpense") > 0 Then
			
			StructureParameter = New Structure;
			StructureParameter.Insert("Ref", Object.Ref);
			StructureParameter.Insert("Number", Object.Number);
			StructureParameter.Insert("Date", Object.Date);
			StructureParameter.Insert("BasisDocument", Object.BasisDocument);
			
			Notify("RefreshDebitNoteText", StructureParameter);
			
		EndIf;
		
	EndIf;
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

#EndRegion

#Region FormItemEventHandlers

&AtClient
Procedure BasisDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Item", Item);
	
	DocumentTypes = New ValueList;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesDebitNote.DropShipping") Then
		TypesValues = New ValueList();
		TypesValues.Add("CreditNote");
		BasisDocumentSelectEnd(TypesValues.FindByValue("CreditNote"), AdditionalParameters);
	Else
		DocumentTypes.Add("SupplierInvoice",	BasisDocumentSynonym("SupplierInvoice"));
		
		If UseGoodsReturnToSupplier Then
			DocumentTypes.Add("GoodsIssue", 	BasisDocumentSynonym("GoodsIssue"));
		EndIf;
		
		DocumentTypes.Add("CashVoucher",		BasisDocumentSynonym("CashVoucher"));
		DocumentTypes.Add("PaymentExpense",		BasisDocumentSynonym("PaymentExpense"));
	EndIf;

	Descr = New NotifyDescription("BasisDocumentSelectEnd", ThisObject, AdditionalParameters);
	DocumentTypes.ShowChooseItem(Descr, NStr("en = 'Select document type'; ru = 'Выберите тип документа';pl = 'Wybierz rodzaj dokumentu';es_ES = 'Seleccionar el tipo de documento';es_CO = 'Seleccionar el tipo de documento';tr = 'Belge türü seç';it = 'Selezionare il tipo di documento';de = 'Dokumententyp auswählen'"));
	
EndProcedure

&AtClient
Procedure BasisDocumentChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If TypeOf(SelectedValue) <> Type("DocumentRef.SupplierInvoice")
		And TypeOf(SelectedValue) <> Type("DocumentRef.CreditNote") Then
		
		Object.BasisDocument = SelectedValue;
		FillByDocument(Object.BasisDocument);
		
		If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
			ClearVATAmount();
		EndIf;
		
		FormManagement();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BasisDocumentSelectEnd(SelectedElement, AdditionalParameters) Export
	
	If SelectedElement = Undefined Then
		Return;
	EndIf;
	
	Filter = New Structure();
	Filter.Insert("Company",		Object.Company);
	If SelectedElement.Value <> "CreditNote" Then
		Filter.Insert("Counterparty",	Object.Counterparty);
	Else
		Filter.Insert("OperationKind",	PredefinedValue("Enum.OperationTypesCreditNote.SalesReturn"));
	EndIf;
	
	If SelectedElement.Value <> "CashVoucher" And SelectedElement.Value <> "PaymentExpense"
			And SelectedElement.Value <> "CreditNote" Then
		Filter.Insert("Contract", Object.Contract);
	EndIf;
	
	ParametersStructure = New Structure("Filter", Filter);
	
	FillByBasisEnd = New NotifyDescription("FillByBasisEnd", ThisObject, AdditionalParameters);
	OpenForm("Document." + SelectedElement.Value + ".ChoiceForm", ParametersStructure, AdditionalParameters.Item);
	
EndProcedure

&AtClient
Procedure BasisDocumentOnChange(Item)
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtServer
Procedure CompanyOnChangeAtServer()
	
	CheckDropShippingReturn();
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		ContractData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
		SettlementCurrency = ContractData.SettlementsCurrency;
		
		If ValueIsFilled(Object.Contract) Then
			ContractValues = ContractData.SettlementsCurrencyRateRepetition;
			Object.ExchangeRate = ?(ContractValues.Rate = 0, 1, ContractValues.Rate);
			Object.Multiplicity = ?(ContractValues.Repetition = 0, 1, ContractValues.Repetition);
			Object.ContractCurrencyExchangeRate = Object.ExchangeRate;
			Object.ContractCurrencyMultiplicity = Object.Multiplicity;
		EndIf;
		
		Object.DocumentCurrency = SettlementCurrency;
		
	EndIf;
	
	ProcessingCompanyVATNumbers(False);
	
	SetAccountingPolicyValues();
	FillVATRateByCompanyVATTaxation();
	SetAutomaticVATCalculation();
	
	// Generate price and currency label.
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementCurrency);
	LabelStructure.Insert("Rate",							Object.ExchangeRate);
	LabelStructure.Insert("RateNationalCurrency",			ExchangeRateNationalCurrency);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", True);
	
	FillAddedColumns(ParametersStructure);
	
	InformationRegisters.AccountingSourceDocuments.CheckNotifyTypesOfAccountingProblems(
		Object.Ref,
		Object.Company,
		DocumentDate);

EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	CompanyOnChangeAtServer();
	FormManagement();
	
EndProcedure

&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	FormManagement();
	
EndProcedure

&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormOfContractParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract, Object.OperationKind);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CounterpartyOnChangeAtServer()
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
	
	FillVATRateByCompanyVATTaxation(True);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillInventory", False);
	ParametersStructure.Insert("FillAmountAllocation", True);
	
	FillAddedColumns(ParametersStructure);
	
	SetContractVisible();
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	
	CounterpartyOnChangeAtServer();
	
	ProcessContractChange();
	
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementCurrency);
	LabelStructure.Insert("Rate",							Object.ExchangeRate);
	LabelStructure.Insert("RateNationalCurrency",			ExchangeRateNationalCurrency);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
Procedure AdjustmentAmountOnChange(Item)
	
	CalculateTotalVATAmount();
	
EndProcedure

&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies();
	Modified = True;
	
EndProcedure

&AtClient
Procedure OperationKindOnChange(Item)
	
	Object.DebitedTransactions.Clear();
	Object.Inventory.Clear();
	Object.AmountAllocation.Clear();
	
	CheckDropShippingReturn();
	
	SetDefaultValuesForIncomeAndExpenseItem(Object.OperationKind, Object.IncomeItem);
	
	SetAdjustedAmountTitle();
	
	If UseDefaultTypeOfAccounting Then
		SetDefaultValuesForGLAccount();
	EndIf;
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure TaxInvoiceTextClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	WorkWithVATClient.OpenTaxInvoice(ThisForm, True);
	
EndProcedure

&AtClient
Procedure VATRateOnChange(Item)
	
	CalculateTotalVATAmount();
	
EndProcedure

&AtServer
Procedure StructuralUnitOnChangeAtServer()
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", False);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtClient
Procedure StructuralUnitOnChange(Item)
	StructuralUnitOnChangeAtServer();
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
Procedure GLAccountOnChange(Item)
	
	GLAccountOnChangeAtServer();
	FormManagement();
	
EndProcedure

&AtClient
Procedure RegisterIncomeOnChange(Item)
	
	FormManagement();
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableDebitedTransactions

&AtClient
Procedure DebitedTransactionsDocumentOnChange(Item)
	
	CurrentData = Items.DebitedTransactions.CurrentData;
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("CurrentData",		CurrentData);
	AdditionalParameters.Insert("MultipleChoice",	False);

	FillDebitTransaction(CurrentData.Document, AdditionalParameters);
	
EndProcedure

&AtClient
Procedure DebitedTransactionsDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	DebitedTransactionsStartChoice(False, Item);
	
EndProcedure

&AtClient
Procedure DebitedTransactionsSelectEnd(SelectedElement, AdditionalParameters) Export
	
	If SelectedElement = Undefined Then
		Return;
	EndIf;
	
	Filter = New Structure();
	Filter.Insert("Company",		Object.Company);
	Filter.Insert("Counterparty",	Object.Counterparty);
	Filter.Insert("Contract",		Object.Contract);
	
	ParametersStructure = New Structure();
	ParametersStructure.Insert("MultipleChoice",	AdditionalParameters.MultipleChoice);
	ParametersStructure.Insert("Filter",			Filter);
	
	FillDebitTransaction = New NotifyDescription("FillDebitTransaction", ThisObject, AdditionalParameters);
	If AdditionalParameters.MultipleChoice Then
		OpenedForm = OpenForm("Document." + SelectedElement.Value + ".ChoiceForm", ParametersStructure,,,,, FillDebitTransaction);
	Else
		OpenedForm = OpenForm("Document." + SelectedElement.Value + ".ChoiceForm", ParametersStructure,AdditionalParameters.Item);
	EndIf;
	
EndProcedure

&AtClient
Procedure DebitedTransactionsStartChoice(MultipleChoice, Item = Undefined)
	
	DocumentTypes = New ValueList;
	DocumentTypes.Add("AdditionalExpenses",	NStr("en = 'Landed costs'; ru = 'Дополнительные расходы';pl = 'Koszty z wyładunkiem';es_ES = 'Costes de entrega';es_CO = 'Costes de entrega';tr = 'Varış yeri maliyetleri';it = 'Costi di scarico';de = 'Wareneinstandspreise'"));
	DocumentTypes.Add("DebitNote",			NStr("en = 'Debit note'; ru = 'Дебетовое авизо';pl = 'Nota debetowa';es_ES = 'Nota de débito';es_CO = 'Nota de débito';tr = 'Borç dekontu';it = 'Nota di debito';de = 'Lastschrift'"));
	DocumentTypes.Add("ExpenseReport",		NStr("en = 'Expense claim'; ru = 'Авансовый отчет';pl = 'Raport rozchodów';es_ES = 'Reclamación de gastos';es_CO = 'Reclamación de gastos';tr = 'Masraf raporu';it = 'Richiesta di spese';de = 'Kostenabrechnung'"));
	DocumentTypes.Add("SupplierInvoice",	NStr("en = 'Supplier invoice'; ru = 'Инвойс поставщика';pl = 'Faktura zakupu';es_ES = 'Factura de proveedor';es_CO = 'Factura de proveedor';tr = 'Satın alma faturası';it = 'Fattura del fornitore';de = 'Lieferantenrechnung'"));
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Item",				Item);
	AdditionalParameters.Insert("MultipleChoice",	MultipleChoice);
	
	Descr = New NotifyDescription("DebitedTransactionsSelectEnd", ThisObject, AdditionalParameters);
	DocumentTypes.ShowChooseItem(Descr, NStr("en = 'Select document type'; ru = 'Выберите тип документа';pl = 'Wybierz rodzaj dokumentu';es_ES = 'Seleccionar el tipo de documento';es_CO = 'Seleccionar el tipo de documento';tr = 'Belge türü seç';it = 'Selezionare il tipo di documento';de = 'Dokumententyp auswählen'"));
	
EndProcedure

&AtClient
Procedure FillDebitTransaction(Documents, AdditionalParameters) Export
	
	AddDebitTransactionsAtServer(Documents);
	
	For Each TableRow In DebitedTransactionData Do
		
		If DebitedTransactionData.IndexOf(TableRow) > 0 Or AdditionalParameters.MultipleChoice Then
			NewRow = Object.DebitedTransactions.Add();
		ElsIf AdditionalParameters.Property("CurrentData") Then
			NewRow = AdditionalParameters.CurrentData;
		EndIf;
		
		FillPropertyValues(NewRow, TableRow);
		
	EndDo;
	
	If DebitedTransactionData.Count() Then
		Modified = True;
	EndIf;
	DebitedTransactionData.Clear();
	
EndProcedure

&AtServer
Procedure AddDebitTransactionsAtServer(Documents)
	
	If Documents = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(Documents) = Type("Array") Then
		DocumentType = Documents[0].Metadata().Name;
	Else
		DocumentType = Documents.Metadata().Name;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Documents", Documents);
	
	Query.Text = 
	"SELECT ALLOWED
	|	PurchasesTurnovers.Recorder AS Document,
	|	PurchasesTurnovers.VATRate AS VATRate,
	|	CASE
	|		WHEN PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover > 0
	|			THEN PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover
	|		ELSE -(PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover)
	|	END AS Amount,
	|	CASE
	|		WHEN PurchasesTurnovers.VATAmountTurnover > 0
	|			THEN PurchasesTurnovers.VATAmountTurnover
	|		ELSE -PurchasesTurnovers.VATAmountTurnover
	|	END AS VATAmount
	|FROM
	|	AccumulationRegister.Purchases.Turnovers(, , Recorder, ) AS PurchasesTurnovers
	|WHERE
	|	PurchasesTurnovers.Recorder IN(&Documents)
	|	AND &DocumentCondition
	|
	|ORDER BY
	|	PurchasesTurnovers.Recorder,
	|	PurchasesTurnovers.VATRate
	|AUTOORDER";
	
	Query.Text = StrReplace(Query.Text, "&DocumentCondition", "PurchasesTurnovers.Recorder REFS Document." + DocumentType);
	
	ValueToFormAttribute(Query.Execute().Unload(), "DebitedTransactionData");
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableInventory

&AtClient
Procedure InventoryAfterDeleteRow(Item)
	CalculateTotal();
	CalculateTotalVATAmount();
EndProcedure

&AtClient
Procedure InventoryAmountAdjustedOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;	
	CalculateVATAmount(CurrentData, CurrentData.Amount);
	CalculateTotal(CurrentData);
	CalculateTotalVATAmount();
	
EndProcedure

&AtClient
Procedure InventoryIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "Inventory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	CurrentData = Items.Inventory.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData,,UseSerialNumbersBalance);
	
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
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);
	
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
Procedure InventoryReturnQuantityOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	CurrentData.Amount = ?(CurrentData.InitialQuantity = 0, 0, CurrentData.InitialAmount / CurrentData.InitialQuantity * CurrentData.Quantity);
	
	CalculateVATAmount(CurrentData, CurrentData.Amount);
	CalculateTotal(CurrentData);
	CalculateTotalVATAmount();
	
	// Serial numbers
	If UseSerialNumbersBalance <> Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, CurrentData);
	EndIf;
	
EndProcedure

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection();
	
EndProcedure

&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	CurrentData.Price = CurrentData.InitialPrice;
	CurrentData.Amount = ?(CurrentData.InitialQuantity = 0, 0, CurrentData.InitialAmount / CurrentData.InitialQuantity * CurrentData.Quantity);
	
	CalculateVATAmount(CurrentData, CurrentData.Amount);
	CalculateTotal(CurrentData);
	CalculateTotalVATAmount();
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableAmountAllocation

&AtClient
Procedure AmountAllocationSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableSelection(ThisObject, "AmountAllocation", SelectedRow, Field, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure AmountAllocationOnActivateCell(Item)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnActivateCell(ThisObject, "AmountAllocation", ThisIsNewRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure AmountAllocationOnStartEdit(Item, NewRow, Clone)
	
	If UseDefaultTypeOfAccounting Then
		
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
		
		TabularSectionRow = Items.AmountAllocation.CurrentData;
		If Not TabularSectionRow.GLAccountsFilled Then
			StructureData = GetStructureDataForObject(ThisObject, "AmountAllocation", TabularSectionRow);
			StructureData = GetDataAmountAllocationContractOnChange(StructureData);
			FillPropertyValues(TabularSectionRow, StructureData);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AmountAllocationOnEditEnd(Item, NewRow, CancelEdit)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnEditEnd(ThisIsNewRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure AmountAllocationGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	GLAccountsInDocumentsClient.GLAccountsStartChoice(ThisObject, "AmountAllocation", StandardProcessing);  
	
EndProcedure

&AtClient
Procedure AmountAllocationContractOnChange(Item)
	
	If UseDefaultTypeOfAccounting Then
		FillAmounAllocationGLAccounts();
	EndIf;
	
EndProcedure

&AtClient
Procedure AmountAllocationDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	TabularSectionRow = Items.AmountAllocation.CurrentData;
	
	If TabularSectionRow.AdvanceFlag Then
		
		ShowMessageBox(, NStr("en = 'No need to select a document in case of advance recognition.'; ru = 'Для вида расчета с признаком ""Аванс"" документом расчетов будет текущий!';pl = 'Nie ma potrzeby wyboru dokumentu w przypadku uznania zaliczki.';es_ES = 'No hay necesidad de seleccionar un documento en el caso del reconocimiento de anticipos.';es_CO = 'No hay necesidad de seleccionar un documento en el caso del reconocimiento de anticipos.';tr = 'Avans tanıma durumunda bir belgeyi seçmenize gerek yoktur.';it = 'Non c''è bisogno di selezionare un documento in caso di riconoscimento di anticipo.';de = 'Im Falle einer Vorauszahlungsaufnahme ist es nicht erforderlich, ein Dokument auszuwählen.'"));
		
	Else
		
		StructureFilter = New Structure();
		StructureFilter.Insert("Company",			Object.Company);
		StructureFilter.Insert("Counterparty", 		Object.Counterparty);
		StructureFilter.Insert("DocumentCurrency",	Object.DocumentCurrency);
		
		If ValueIsFilled(TabularSectionRow.Contract) Then
			StructureFilter.Insert("Contract", TabularSectionRow.Contract);
		EndIf;
		
		ParameterStructure = New Structure("Filter, ThisIsAccountsReceivable, DocumentType",
											StructureFilter,
											False,
											TypeOf(Object.Ref));
		
		OpenForm("CommonForm.SelectDocumentOfSettlements", ParameterStructure, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AmountAllocationDocumentChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	
	ProcessAccountsDocumentSelection(SelectedValue);
	
EndProcedure

&AtClient
Procedure FillAllocationEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	Object.AmountAllocation.Clear();
	FillAmountAllocation();
	
EndProcedure

&AtClient
Procedure AmountAllocationPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.AmountAllocation.CurrentData;
	CalculateVATAmountForAmountAllocation(TabularSectionRow, TabularSectionRow.OffsetAmount);
	
EndProcedure

&AtClient
Procedure AmountAllocationVATRateOnChange(Item)
	
	TabularSectionRow = Items.AmountAllocation.CurrentData;
	CalculateVATAmountForAmountAllocation(TabularSectionRow, TabularSectionRow.OffsetAmount);
	
EndProcedure

&AtServer
Procedure FillAmountAllocation()
	
	Document = FormAttributeToValue("Object");
	Document.FillAmountAllocation();
	ValueToFormAttribute(Document, "Object");
	
	ParametersStructure = New Structure;
	
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillInventory", False);
	ParametersStructure.Insert("FillAmountAllocation", True);
	FillAddedColumns(ParametersStructure);
	
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", False);
	FillAddedColumns(ParametersStructure);
	
	Modified = True;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure DebitedTransactionsSelect(Command)
	
	DebitedTransactionsStartChoice(True);
	
EndProcedure

&AtClient
Procedure FillAllocation(Command)
	
	If Object.AdjustedAmount = 0 Then
		ShowMessageBox(Undefined, NStr("en = 'Please specify the amount.'; ru = 'Введите сумму.';pl = 'Podaj wartość.';es_ES = 'Por favor, especifique el importe.';es_CO = 'Por favor, especifique el importe.';tr = 'Lütfen, tutarı belirtin.';it = 'Si prega di specificare l''importo.';de = 'Bitte geben Sie den Betrag an.'"));
		Return;
	EndIf;
	
	Response = Undefined;
	
	If Object.AmountAllocation.Count() <> 0 Then
		ShowQueryBox(New NotifyDescription("FillAllocationEnd", ThisObject), 
						NStr("en = 'Allocation amount will be completely refilled. Do you want to continue?'; ru = 'Распределение суммы будет полностью перезаполнена. Продолжить?';pl = 'Opis transakcji zostanie w całości wypełniony ponownie. Czy chcesz kontynuować?';es_ES = 'Importe de asignación se volverá a rellenar completamente. ¿Quiere continuar?';es_CO = 'Importe de asignación se volverá a rellenar completamente. ¿Quiere continuar?';tr = 'Dağıtım tutarı tamamen yeniden doldurulacaktır. Devam etmek istiyor musunuz?';it = 'L''importo allocato sarà completamente ricompilato. Volete continuare?';de = 'Die Verteilung wird vollständig aufgefüllt. Möchten Sie fortsetzen?'"),
						QuestionDialogMode.YesNo);
	Else
		FillAmountAllocation();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillByBasis(Command)
	
	If ValueIsFilled(Object.BasisDocument) Then
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesDebitNote.DropShipping") Then
			If Not ValueIsFilled(Object.Counterparty) Then
				CommonClientServer.MessageToUser(
						NStr("en = 'Counterparty is required.'; ru = 'Поле ""Контрагент"" не заполнено.';pl = 'Wymagany jest kontrahent.';es_ES = 'Se requiere la contrapartida.';es_CO = 'Se requiere la contrapartida.';tr = 'Cari hesap gerekli.';it = 'È richiesta la controparte.';de = 'Geschäftspartner ist erforderlich.'"),,
						"Object.Counterparty");
				Return;
			EndIf;
			If Items.Contract.Visible And Not ValueIsFilled(Object.Contract) Then
				CommonClientServer.MessageToUser(
						NStr("en = 'Contract is required.'; ru = 'Поле ""Договор"" не заполнено.';pl = 'Wymagany jest kontrakt.';es_ES = 'Se requiere un contrato.';es_CO = 'Se requiere un contrato.';tr = 'Sözleşme gerekli.';it = 'È richiesto il contratto.';de = 'Kontakte ist ein Pflichtfeld.'"),,
						"Object.Contract");
				Return;
			EndIf;
		EndIf;
	
		ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
			NStr("en = 'Do you want to refill the debit note?'; ru = 'Документ будет полностью перезаполнен по основанию. Продолжить?';pl = 'Czy chcesz uzupełnić notę debetową?';es_ES = '¿Quiere volver a rellenar la nota de débito?';es_CO = '¿Quiere volver a rellenar la nota de débito?';tr = 'Borç dekontu yeniden doldurulsun mu?';it = 'Volete ricompilare la nota di debito?';de = 'Möchten Sie die Lastschrift ausfüllen?'"),
			QuestionDialogMode.YesNo);
			
	Else
		MessagesToUserClient.ShowMessageSelectBaseDocument();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillByPeriod(Command)
	
	Notify = New NotifyDescription("FillByPeriodEnd", ThisObject);
	
	If Object.DebitedTransactions.Count() = 0 Then
		ExecuteNotifyProcessing(Notify, DialogReturnCode.Yes); 
	Else
		ShowQueryBox(Notify, NStr("en = 'The tabular section will be refilled. Do you want to continue?'; ru = 'Табличная часть будет полностью перезаполнена. Продолжить?';pl = 'Sekcja tabelaryczna zostanie wypełniona ponownie. Czy chcesz kontynuować?';es_ES = 'La sección tabular se volverá a rellenar. ¿Quiere continuar?';es_CO = 'La sección tabular se volverá a rellenar. ¿Quiere continuar?';tr = 'Tablo bölümü yeniden doldurulacak. Devam etmek istiyor musunuz?';it = 'La sezione tabellare sarà ricompilata. Volete continuare?';de = 'Der Tabellenbereich wird wieder aufgefüllt. Fortsetzen?'"), QuestionDialogMode.YesNo, 0);
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

#Region Internal

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
		FillByDocument(Object.BasisDocument);
		
		If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
			ClearVATAmount();
		EndIf;
		
		FormManagement();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", True);
	
	FillAddedColumns(ParametersStructure);
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	SetContractVisible();
	
	// Generate price and currency label.
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementCurrency);
	LabelStructure.Insert("Rate",							Object.ExchangeRate);
	LabelStructure.Insert("RateNationalCurrency",			ExchangeRateNationalCurrency);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

&AtServer
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
		
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
		
		For Each TabularSectionRow In Object.Inventory Do
			
			If ValueIsFilled(TabularSectionRow.Products.VATRate) Then
				TabularSectionRow.VATRate = TabularSectionRow.Products.VATRate;
			Else
				TabularSectionRow.VATRate = DefaultVATRate;
			EndIf;	
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  		TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  		TabularSectionRow.Amount * VATRate / 100);
			TabularSectionRow.Total		= TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
		For Each TabularSectionRow In Object.AmountAllocation Do
		
			TabularSectionRow.VATRate		= DefaultVATRate;
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount		= ?(Object.AmountIncludesVAT, 
										  		TabularSectionRow.OffsetAmount - (TabularSectionRow.OffsetAmount) / ((VATRate + 100) / 100),
										  		TabularSectionRow.OffsetAmount * VATRate / 100);
			TabularSectionRow.OffsetAmount	= TabularSectionRow.OffsetAmount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesDebitNote.PurchaseReturn")
				Or Object.OperationKind = PredefinedValue("Enum.OperationTypesDebitNote.DropShipping") Then
			Object.VATAmount = Object.Inventory.Total("VATAmount");
		Else
			
			Rate = DriveReUse.GetVATRateValue(Object.VATRate);
			If Object.AmountIncludesVAT Then
				Object.VATAmount = Object.AdjustedAmount - (Object.AdjustedAmount) / ((Rate + 100) / 100);
			Else
				Object.VATAmount = Object.AdjustedAmount * Rate / 100;
			EndIf;
			
		EndIf;
		
	Else
		
		If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
			DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;	
		
		Object.VATRate = DefaultVATRate;
		Object.VATAmount = 0;
		
		For Each TabularSectionRow In Object.Inventory Do
		
			TabularSectionRow.VATRate	= DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			TabularSectionRow.Total		= TabularSectionRow.Amount;
			
		EndDo;
		
		For Each TabularSectionRow In Object.AmountAllocation Do
		
			TabularSectionRow.OffsetAmount	= TabularSectionRow.OffsetAmount - ?(Object.AmountIncludesVAT, TabularSectionRow.VATAmount, 0);
			TabularSectionRow.VATRate		= DefaultVATRate;
			TabularSectionRow.VATAmount		= 0;
			
		EndDo;
		
	EndIf;	
	
EndProcedure

&AtServerNoContext
Function GetFlagsForFormItemsVisible(OperationKind, VATTaxation, GLAccount, UseDefaultTypeOfAccounting)
	
	VisibleFlags = New Structure;
	VisibleFlags.Insert("ThisIsPurchaseReturn", (OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn));
	VisibleFlags.Insert("IsDiscountReceived", (OperationKind = Enums.OperationTypesDebitNote.DiscountReceived));
	VisibleFlags.Insert("IsAdjustments", (OperationKind = Enums.OperationTypesDebitNote.Adjustments));
	VisibleFlags.Insert("SubjectToVAT", (VATTaxation <> Enums.VATTaxationTypes.NotSubjectToVAT));
	VisibleFlags.Insert("IsDropShipping", (OperationKind = Enums.OperationTypesDebitNote.DropShipping));
	
	If UseDefaultTypeOfAccounting Then
		VisibleFlags.Insert("IsIncomeGLA", GLAccountsInDocuments.IsIncomeGLA(GLAccount));
	Else
		VisibleFlags.Insert("IsIncomeGLA", False);
	EndIf;
	
	Return VisibleFlags;
	
EndFunction

// It gets counterparty contract selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormOfContractParameters(Document, Company, Counterparty, Contract, OperationKind)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Document, OperationKind);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice",	Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty",			Counterparty);
	FormParameters.Insert("Company",				Company);
	FormParameters.Insert("ContractType",			ContractTypesList);
	FormParameters.Insert("CurrentRow",				Contract);
	
	Return FormParameters;
	
EndFunction

&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company, OperationKind)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company, OperationKind);
	
EndFunction

&AtServer
Function GetDataContractOnChange(Date, DocumentCurrency, Contract)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillInventory", False);
	ParametersStructure.Insert("FillAmountAllocation", False);
	
	FillAddedColumns(ParametersStructure);
	
	StructureData = New Structure();
	
	StructureData.Insert("ContractDescription", 				Contract.Description);
	StructureData.Insert("SettlementsCurrency",					Contract.SettlementsCurrency);
	StructureData.Insert("SettlementsCurrencyRateRepetition",	CurrencyRateOperations.GetCurrencyRate(Date, Contract.SettlementsCurrency, Object.Company));
	StructureData.Insert("PriceKind", 							Contract.PriceKind);
	StructureData.Insert("DiscountMarkupKind", 					Contract.DiscountMarkupKind);
	StructureData.Insert("AmountIncludesVAT", 					?(ValueIsFilled(Contract.PriceKind), Contract.PriceKind.PriceIncludesVAT, Undefined));
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure Attachable_ProcessDateChange()
	
	StructureData = GetDataDateOnChange(Object.DocumentCurrency, SettlementCurrency);
	
	If ValueIsFilled(SettlementCurrency) Then
		RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
	EndIf;
	
	FormManagement();
	
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementCurrency);
	LabelStructure.Insert("Rate",							Object.ExchangeRate);
	LabelStructure.Insert("RateNationalCurrency",			ExchangeRateNationalCurrency);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServer
Function GetDataDateOnChange(DocumentCurrency, SettlementsCurrency)
	
	CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, DocumentCurrency, Object.Company);
	
	ProcessingCompanyVATNumbers();
	
	SetAccountingPolicyValues();
	FillVATRateByCompanyVATTaxation();
	SetAutomaticVATCalculation();
	
	StructureData = New Structure;
	StructureData.Insert("CurrencyRateRepetition",	CurrencyRateRepetition);
	
	If DocumentCurrency <> SettlementsCurrency Then
		
		SettlementsCurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, SettlementsCurrency, Object.Company);
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", SettlementsCurrencyRateRepetition);
		
	Else
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", CurrencyRateRepetition);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange = Undefined, RefillPrices = False, RecalculatePrices = False, WarningText = "")
	
	If AttributesBeforeChange = Undefined Then
		AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
			Object.DocumentCurrency,
			Object.ExchangeRate,
			Object.Multiplicity);
	EndIf;
	
	// 1. Form parameter structure to fill the "Prices and Currency" form.
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
	ParametersStructure.Insert("Company",						Object.Company);
	ParametersStructure.Insert("DocumentDate",					Object.Date);
	ParametersStructure.Insert("RefillPrices",					RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",				RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",				False);
	ParametersStructure.Insert("WarningText",					WarningText);
	ParametersStructure.Insert("AutomaticVATCalculation",		Object.AutomaticVATCalculation);
	ParametersStructure.Insert("PerInvoiceVATRoundingRule",		PerInvoiceVATRoundingRule);
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesDebitNote.PurchaseReturn")
			Or Object.OperationKind = PredefinedValue("Enum.OperationTypesDebitNote.DropShipping") Then
		ParametersStructure.Insert("DocumentCurrencyEnabled", False);
	EndIf;
	
	// Open form "Prices and Currency".
	// Refills tabular section "Costs" if changes were made in the "Price and Currency" form.
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, AttributesBeforeChange);
	
	OpenForm("CommonForm.PricesAndCurrency",
		ParametersStructure,
		ThisObject,,,,
		NotifyDescription,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ProcessContractChange()
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		ContractData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
		ProcessContractConditionsChange(ContractData, ContractBeforeChange);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessContractConditionsChange(ContractData, ContractBeforeChange)
	
	SettlementCurrency = ContractData.SettlementsCurrency;
	
	AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
		Object.DocumentCurrency,
		Object.ExchangeRate,
		Object.Multiplicity);
	
	If ValueIsFilled(Object.Contract) Then 
		Object.ExchangeRate	= ?(ContractData.SettlementsCurrencyRateRepetition.Rate = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Rate);
		Object.Multiplicity = ?(ContractData.SettlementsCurrencyRateRepetition.Repetition = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Repetition);
		Object.ContractCurrencyExchangeRate = Object.ExchangeRate;
		Object.ContractCurrencyMultiplicity = Object.Multiplicity;
	EndIf;
	
	OpenFormPricesAndCurrencies = ValueIsFilled(Object.Contract)
		And ValueIsFilled(SettlementCurrency)
		And Object.DocumentCurrency <> SettlementCurrency
		And Object.DebitedTransactions.Count() > 0;
	
	If ValueIsFilled(SettlementCurrency) Then
		Object.DocumentCurrency = SettlementCurrency;
	EndIf;
	
	If OpenFormPricesAndCurrencies
		And Object.OperationKind <> PredefinedValue("Enum.OperationTypesDebitNote.PurchaseReturn") Then
		
		WarningText = MessagesToUserClientServer.GetSettleCurrencyOnChangeWarningText();
		ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange, False, True, WarningText);
		
	Else
		
		// Generate price and currency label.
		LabelStructure = New Structure;
		LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency",			SettlementCurrency);
		LabelStructure.Insert("Rate",							Object.ExchangeRate);
		LabelStructure.Insert("RateNationalCurrency",			ExchangeRateNationalCurrency);
		LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
		
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	StructurePricesAndCurrency = ClosingResult;
	
	If TypeOf(StructurePricesAndCurrency) = Type("Structure") AND StructurePricesAndCurrency.WereMadeChanges Then
		
		DocCurRecalcStructure = New Structure;
		DocCurRecalcStructure.Insert("DocumentCurrency", StructurePricesAndCurrency.DocumentCurrency);
		DocCurRecalcStructure.Insert("Rate", StructurePricesAndCurrency.ExchangeRate);
		DocCurRecalcStructure.Insert("Repetition", StructurePricesAndCurrency.Multiplicity);
		DocCurRecalcStructure.Insert("PrevDocumentCurrency", AdditionalParameters.DocumentCurrency);
		DocCurRecalcStructure.Insert("InitRate", AdditionalParameters.ExchangeRate);
		DocCurRecalcStructure.Insert("RepetitionBeg", AdditionalParameters.Multiplicity);
		
		Object.DocumentCurrency				= StructurePricesAndCurrency.DocumentCurrency;
		Object.ExchangeRate					= StructurePricesAndCurrency.ExchangeRate;
		Object.Multiplicity					= StructurePricesAndCurrency.Multiplicity;
		Object.ContractCurrencyExchangeRate	= StructurePricesAndCurrency.SettlementsRate;
		Object.ContractCurrencyMultiplicity	= StructurePricesAndCurrency.SettlementsMultiplicity;
		Object.VATTaxation					= StructurePricesAndCurrency.VATTaxation;
		Object.AmountIncludesVAT			= StructurePricesAndCurrency.AmountIncludesVAT;
		Object.IncludeVATInPrice			= StructurePricesAndCurrency.IncludeVATInPrice;
		Object.AutomaticVATCalculation		= StructurePricesAndCurrency.AutomaticVATCalculation;
		
		// Recalculate prices by currency.
		If Not StructurePricesAndCurrency.RefillPrices
			AND StructurePricesAndCurrency.RecalculatePrices Then	
			
			If Object.OperationKind = PredefinedValue("Enum.OperationTypesDebitNote.PurchaseReturn") Then
				DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "Inventory", PricesPrecision);
				Object.AdjustedAmount = Object.Inventory.Total("Total");
			Else
				Object.AdjustedAmount = DriveServer.RecalculateFromCurrencyToCurrency(Object.AdjustedAmount,
					GetExchangeRateMethod(Object.Company),
					DocCurRecalcStructure.InitRate, 
					DocCurRecalcStructure.Rate, 
					DocCurRecalcStructure.RepetitionBeg, 
					DocCurRecalcStructure.Repetition,
					PricesPrecision);
			EndIf;
			
			CalculateTotalVATAmount();
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "AmountAllocation", PricesPrecision);
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If StructurePricesAndCurrency.VATTaxation <> StructurePricesAndCurrency.PrevVATTaxation Then
			FillVATRateByVATTaxation();
			
			FormManagement();
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not StructurePricesAndCurrency.RefillPrices
			AND Not StructurePricesAndCurrency.AmountIncludesVAT = StructurePricesAndCurrency.PrevAmountIncludesVAT Then
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory", PricesPrecision);
			Object.AdjustedAmount = Object.Inventory.Total("Total");
			CalculateTotalVATAmount();
		EndIf;
		
		If StructurePricesAndCurrency.AmountIncludesVAT <> StructurePricesAndCurrency.PrevAmountIncludesVAT Then
			SetAdjustedAmountTitle();
		EndIf;
		
	EndIf;
	
	// Generate price and currency label.
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementCurrency);
	LabelStructure.Insert("Rate",							Object.ExchangeRate);
	LabelStructure.Insert("RateNationalCurrency",			ExchangeRateNationalCurrency);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	WorkWithVATClient.ShowReverseChargeNotSupportedMessage(Object.VATTaxation);
	
EndProcedure

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
		
		QuestionParameters = New Structure;
		QuestionParameters.Insert("NewExchangeRate",					NewExchangeRate);
		QuestionParameters.Insert("NewRatio",							NewRatio);
		QuestionParameters.Insert("NewContractCurrencyExchangeRate",	NewContractCurrencyExchangeRate);
		QuestionParameters.Insert("NewContractCurrencyRatio",			NewContractCurrencyRatio);
		
		NotifyDescription = New NotifyDescription("QuestionOnRecalculatingPaymentCurrencyRateConversionFactorEnd",
			ThisObject,
			QuestionParameters);
		
		QuestionText = MessagesToUserClientServer.GetApplyRatesOnNewDateQuestionText();
		
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure QuestionOnRecalculatingPaymentCurrencyRateConversionFactorEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		Object.ContractCurrencyExchangeRate = AdditionalParameters.NewContractCurrencyExchangeRate;
		Object.ContractCurrencyMultiplicity = AdditionalParameters.NewContractCurrencyRatio;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProccessingPeriod(SelectedPeriod, AdditionalParemeters) Export
	
	FillByPeriodAtServer(SelectedPeriod);
	
EndProcedure

&AtClient
Procedure FillByPeriodEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		Dialog = New StandardPeriodEditDialog();
		Dialog.Period = New StandardPeriod(BeginingDate, EndingDate);
		
		NotifyDescription = New NotifyDescription("ChoiceProccessingPeriod", ThisForm);
		Dialog.Show(NotifyDescription);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillByPeriodAtServer(SelectedPeriod)
	
	If SelectedPeriod <> Undefined Then
		
		Object.DebitedTransactions.Clear();
		
		BeginingDate = SelectedPeriod.StartDate;
		EndingDate	= EndOfDay(SelectedPeriod.EndDate);
		
		FillDebitTransactionsByAllTypes();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillDebitTransactionsByAllTypes()
	
	Query = New Query();
	Query.Text = 
	"SELECT ALLOWED
	|	PurchasesTurnovers.Recorder AS Document,
	|	PurchasesTurnovers.VATRate AS VATRate,
	|	CASE
	|		WHEN (PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover) > 0
	|			THEN PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover
	|		ELSE -(PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover)
	|	END AS Amount,
	|	CASE
	|		WHEN PurchasesTurnovers.VATAmountTurnover > 0
	|			THEN PurchasesTurnovers.VATAmountTurnover
	|		ELSE -PurchasesTurnovers.VATAmountTurnover
	|	END AS VATAmount
	|FROM
	|	AccumulationRegister.Purchases.Turnovers(&BeginingDate, &EndingDate, Recorder, Company = &Company) AS PurchasesTurnovers
	|WHERE
	|	(PurchasesTurnovers.Recorder REFS Document.AdditionalExpenses
	|			OR PurchasesTurnovers.Recorder REFS Document.DebitNote
	|			OR PurchasesTurnovers.Recorder REFS Document.ExpenseReport
	|			OR PurchasesTurnovers.Recorder REFS Document.SupplierInvoice)
	|	AND PurchasesTurnovers.Recorder.Counterparty = &Counterparty
	|	AND PurchasesTurnovers.Recorder.Contract = &Contract
	|	AND PurchasesTurnovers.Recorder <> &Ref
	|
	|ORDER BY
	|	PurchasesTurnovers.Recorder,
	|	PurchasesTurnovers.VATRate
	|AUTOORDER";
	
	Query.SetParameter("BeginingDate",	BeginingDate);
	Query.SetParameter("EndingDate", 	EndingDate);
	Query.SetParameter("Company", 		Object.Company);
	Query.SetParameter("Counterparty", 	Object.Counterparty);
	Query.SetParameter("Contract", 		Object.Contract);
	Query.SetParameter("Ref", 			Object.Ref);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = Object.DebitedTransactions.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

&AtServerNoContext
Function GetDataAmountAllocationContractOnChange(StructureData = Undefined)
	
	GLAccountsInDocuments.FillCounterpartyGLAccounts(StructureData);
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetExchangeRateMethod(Company)

	Return DriveServer.GetExchangeMethod(Company);	

EndFunction

&AtClient
Procedure OpenSerialNumbersSelection()
		
	CurrentDataIdentifier = Items.Inventory.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

&AtServer
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, False, "Inventory");
	
EndFunction

// Procedure fills in the PaymentDetails TS string with the billing document data.
//
&AtClient
Procedure ProcessAccountsDocumentSelection(DocumentData)
	
	TabularSectionRow = Items.AmountAllocation.CurrentData;
	If TypeOf(DocumentData) = Type("Structure") Then
		
		TabularSectionRow.Document = DocumentData.Document;
		TabularSectionRow.Order = DocumentData.Order;
		
		If Not ValueIsFilled(TabularSectionRow.Contract) Then
			
			TabularSectionRow.Contract = DocumentData.Contract;
			
			If UseDefaultTypeOfAccounting Then
				FillAmounAllocationGLAccounts();
			EndIf;
			
		EndIf;
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillVATRateByCompanyVATTaxation(IsCounterpartyOnChange = False)
	
	If Not WorkWithVAT.VATTaxationTypeIsValid(Object.VATTaxation, RegisteredForVAT, False)
		Or Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT
		Or IsCounterpartyOnChange Then
		
		TaxationBeforeChange = Object.VATTaxation;
		
		Object.VATTaxation = DriveServer.CounterpartyVATTaxation(Object.Counterparty,
			DriveServer.VATTaxation(Object.Company, Object.Date),
			False);
		
		If Not TaxationBeforeChange = Object.VATTaxation Then
			FillVATRateByVATTaxation();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function GetStructureDataForObject(Form, TabName, TabRow)
	
	StructureData = New Structure;
	
	StructureData.Insert("TabName", TabName);
	StructureData.Insert("Object", Form.Object);
	
	StructureData.Insert("Document", TabRow.Document);
	StructureData.Insert("VATRate", TabRow.VATRate);
	StructureData.Insert("LineNumber", TabRow.LineNumber);
	
	StructureData.Insert("CounterpartyIncomeAndExpenseItems", True);
	StructureData.Insert("UseDefaultTypeOfAccounting", Form.UseDefaultTypeOfAccounting);
	
	If Form.UseDefaultTypeOfAccounting Then
		
		StructureData.Insert("GLAccounts", TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled", TabRow.GLAccountsFilled);
		StructureData.Insert("CounterpartyGLAccounts", True);
		
		StructureData.Insert("AccountsPayableGLAccount", TabRow.AccountsPayableGLAccount);
		StructureData.Insert("AdvancesPaidGLAccount", TabRow.AdvancesPaidGLAccount);
		StructureData.Insert("VATInputGLAccount", TabRow.VATInputGLAccount);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

#Region GLAccounts

&AtClient
Function GetStructureDataForGLAccounts(Form, TabName, StructureData, TabRow)
	
	StructureData = New Structure;
	StructureData.Insert("TabName", 					TabName);
	StructureData.Insert("Object",						Form.Object);
	StructureData.Insert("CounterpartyGLAccounts",		True);
	StructureData.Insert("GLAccounts",					TabRow.GLAccounts);
	StructureData.Insert("GLAccountsFilled",			TabRow.GLAccountsFilled);
	StructureData.Insert("AccountsPayableGLAccount",	TabRow.AccountsPayableGLAccount);
	StructureData.Insert("AdvancesPaidGLAccount",		TabRow.AdvancesPaidGLAccount);
	StructureData.Insert("VATInputGLAccount",			TabRow.VATInputGLAccount);
	StructureData.Insert("Document",					TabRow.Document);
	StructureData.Insert("VATRate",						TabRow.VATRate);
	StructureData.Insert("LineNumber",					TabRow.LineNumber);
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure FillAddedColumns(ParametersStructure)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	StructureArray = New Array();
	
	If UseDefaultTypeOfAccounting Then
		
		If ParametersStructure.FillHeader
			And ObjectParameters.OperationKind <> Enums.OperationTypesDebitNote.Adjustments Then
			
			Header = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "Header", Object);
			GLAccountsInDocuments.CompleteCounterpartyStructureData(Header, ObjectParameters, "Header");
			StructureArray.Add(Header);
			
		EndIf;
		
		
		If ParametersStructure.FillAmountAllocation Then
			
			StructureData = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "AmountAllocation");
			GLAccountsInDocuments.CompleteCounterpartyStructureData(StructureData, ObjectParameters, "AmountAllocation");
			StructureArray.Add(StructureData);
			
		EndIf;
		
	EndIf;
	
	If ParametersStructure.FillInventory Then
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters);
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters);
		
		StructureArray.Add(StructureData);
		
	EndIf;
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, ParametersStructure.GetGLAccounts);
	
	If UseDefaultTypeOfAccounting
		And ParametersStructure.FillHeader
		And ObjectParameters.OperationKind <> Enums.OperationTypesDebitNote.Adjustments Then
		Object.GLAccount = ChartsOfAccounts.PrimaryChartOfAccounts.FindByCode(Header.GLAccounts);
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure SetDefaultValuesForIncomeAndExpenseItem(OperationKind, IncomeItem)

	If OperationKind = Enums.OperationTypesDebitNote.DiscountReceived Then 
		IncomeItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("DiscountReceived");
	ElsIf OperationKind = Enums.OperationTypesDebitNote.Adjustments Then 
		IncomeItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("OtherIncome");
	Else
		IncomeItem = Catalogs.IncomeAndExpenseItems.EmptyRef();
	EndIf;
	
EndProcedure

// Procedure sets GL account values by default depending on the operation type.
//
&AtServer
Procedure SetDefaultValuesForGLAccount()

	If Object.OperationKind = Enums.OperationTypesDebitNote.DiscountReceived Then 
		Object.GLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("DiscountReceived");
	ElsIf Object.OperationKind = Enums.OperationTypesDebitNote.Adjustments Then
		Object.GLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OtherIncome");	
	ElsIf Object.OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn 
		Or Object.OperationKind = Enums.OperationTypesDebitNote.DropShipping Then
		Object.GLAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillInventory", False);
	ParametersStructure.Insert("FillAmountAllocation", False);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

#EndRegion

&AtServer
Procedure GLAccountOnChangeAtServer()
	
	Structure = New Structure("Object,GLAccount,IncomeItem,Manual");
	Structure.Object = Object;
	FillPropertyValues(Structure, Object);
	
	GLAccountsInDocumentsServerCall.CheckItemRegistration(Structure);
	FillPropertyValues(Object, Structure);
	
EndProcedure

&AtClient
Procedure CalculateTotal(CurrentData = Undefined) 
	
	If CurrentData <> Undefined Then 
		CurrentData.Total = CurrentData.Amount + ?(Object.AmountIncludesVAT, 0, CurrentData.VATAmount);
	EndIf;
	
	AmountTotal = Object.Inventory.Total("Total");
	VATAmountTotal = Object.Inventory.Total("VATAmount");
	
	Object.AdjustedAmount = AmountTotal;
	Object.DocumentTax = VATAmountTotal;
	Object.DocumentSubtotal = AmountTotal - VATAmountTotal;
	
EndProcedure

&AtClient
Procedure CalculateTotalVATAmount() 
    
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesDebitNote.PurchaseReturn")
			Or Object.OperationKind = PredefinedValue("Enum.OperationTypesDebitNote.DropShipping") Then
		Object.VATAmount = Object.Inventory.Total("VATAmount");
	Else
		CalculateVATAmount(Object, Object.AdjustedAmount);		
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateVATAmount(CurrentData, Amount) 
    
	Rate = DriveReUse.GetVATRateValue(CurrentData.VATRate);
	If Object.AmountIncludesVAT Then
		CurrentData.VATAmount = Amount - (Amount) / ((Rate + 100) / 100);
	Else
		CurrentData.VATAmount = Amount * Rate / 100;
	EndIf;

EndProcedure

&AtClient
Procedure CalculateVATAmountForAmountAllocation(CurrentData, Amount) 
	
	Rate = DriveReUse.GetVATRateValue(CurrentData.VATRate);
	CurrentData.VATAmount = Amount - (Amount) / ((Rate + 100) / 100);
	
EndProcedure

&AtClient
Procedure ClearVATAmount() 
	
	Object.VATAmount = 0;
	
	For Each Row In Object.Inventory Do
		Row.VATAmount = 0;
	EndDo;
	
	For Each Row In Object.AmountAllocation Do
		Row.VATAmount = 0;
	EndDo;
	
EndProcedure

&AtServer
Procedure SetFormConditionalAppearance()
	
	// InventorySerialNumbers
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"UseGoodsReturnToSupplier",
		True,
		DataCompositionComparisonType.Equal);
	
	Text = StringFunctionsClientServer.SubstituteParametersToString("<%1>", NStr("en = 'Specifiy in Goods issue'; ru = 'Укажите в отпуске товаров';pl = 'Określ w Wydaniu zewnętrznym';es_ES = 'Especificar en la salida de Mercancías';es_CO = 'Especificar en la salida de Mercancías';tr = 'Ambar çıkışında belirtin';it = 'Specifica nella spedizione merce';de = 'Im Warenausgang angeben'"));
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "InventorySerialNumbers");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Enabled", False);
	
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance);
	
EndProcedure

&AtServer
Procedure SetAccountingPolicyValues()

	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Object.Date, Object.Company);
	UseGoodsReturnToSupplier	= AccountingPolicy.UseGoodsReturnToSupplier;
	UseTaxInvoice				= Not AccountingPolicy.PostVATEntriesBySourceDocuments;
	RegisteredForVAT			= AccountingPolicy.RegisteredForVAT;
	PerInvoiceVATRoundingRule	= AccountingPolicy.PerInvoiceVATRoundingRule;
	
EndProcedure

&AtServer
Procedure SetAutomaticVATCalculation()
	
	Object.AutomaticVATCalculation = PerInvoiceVATRoundingRule;
	
EndProcedure

&AtClient
Procedure SetAdjustedAmountTitle()
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesDebitNote.Adjustments")
		Or Object.OperationKind = PredefinedValue("Enum.OperationTypesDebitNote.DiscountReceived") Then
		
		If Object.AmountIncludesVAT Then
			Items.AdjustedAmount.Title = NStr("en = 'Adjustment amount, incl. tax'; ru = 'Сумма корректировки, вкл. налог';pl = 'Wartość korekty brutto';es_ES = 'Importe de corrección, incluyendo impuestos';es_CO = 'Importe de corrección, incluyendo impuestos';tr = 'Düzeltme tutarı, vergi dahil';it = 'Importo della correzione, imposte incluse';de = 'Korrekturbetrag, inkl. Steuer'");
		Else
			Items.AdjustedAmount.Title = NStr("en = 'Adjustment amount, excl. tax'; ru = 'Сумма корректировки, без налога';pl = 'Wartość korekty brutto';es_ES = 'Importe de corrección, sin impuestos';es_CO = 'Importe de corrección, sin impuestos';tr = 'Düzeltme tutarı, vergi hariç';it = 'Importo della correzione, imposte escluse';de = 'Korrekturbetrag, exkl. Steuer'");
		EndIf;
		
	Else
		Items.AdjustedAmount.Title = NStr("en = 'Adjusted amount'; ru = 'Сумма корректировки';pl = 'Wartość skorygowana';es_ES = 'Importe modificado';es_CO = 'Importe modificado';tr = 'Düzeltilmiş tutar';it = 'Importo corretto';de = 'Korrigierter Betrag'");
	EndIf;
	
EndProcedure

&AtClient
Procedure FormManagement()
	
	VisibleFlags = GetFlagsForFormItemsVisible(Object.OperationKind,
		Object.VATTaxation,
		Object.GLAccount,
		UseDefaultTypeOfAccounting);
	
	ThisIsPurchaseReturn	= VisibleFlags.ThisIsPurchaseReturn;
	SubjectToVAT			= VisibleFlags.SubjectToVAT;
	IsDiscountReceived		= VisibleFlags.IsDiscountReceived;
	IsAdjustments			= VisibleFlags.IsAdjustments;
	IsIncomeGLA				= VisibleFlags.IsIncomeGLA;
	IsDropShipping			= VisibleFlags.IsDropShipping;
	BasisDocumentVisible	= (ThisIsPurchaseReturn And Not Object.BasisDocumentInTabularSection Or IsDiscountReceived Or IsDropShipping);
	
	If IsAdjustments Then
		Items.IncomeItem.Title = NStr("en = 'Income item for adjustment'; ru = 'Статья доходов для корректировки';pl = 'Pozycja dochodów do korekty';es_ES = 'Artículo de ingresos para el ajuste';es_CO = 'Artículo de ingresos para el ajuste';tr = 'Düzeltme için gelir kalemi';it = 'Voce di entrata per l''adeguamento';de = 'Position von Einnahme zum Anpassen'"); 
	ElsIf IsDiscountReceived Then
		Items.IncomeItem.Title = NStr("en = 'Income item for discount received'; ru = 'Статья доходов для полученной скидки';pl = 'Pozycja dochodów dla otrzymanych rabatów';es_ES = 'Artículo de ingresos para el descuento recibido';es_CO = 'Artículo de ingresos para el descuento recibido';tr = 'Alınan indirim için gelir kalemi';it = 'Voce di entrata per sconto ricevuto';de = 'Position von Einnahme für Rabatt erhalten'");
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		IncomeItemVisible = (Not (ThisIsPurchaseReturn Or IsDropShipping) And IsIncomeGLA);
		RegisterIncomeVisible = False;
	Else
		IncomeItemVisible = (Not (ThisIsPurchaseReturn Or IsDropShipping) And Object.RegisterIncome);
		RegisterIncomeVisible = Not (ThisIsPurchaseReturn Or IsDropShipping);
	EndIf;
	
	CommonClientServer.SetFormItemProperty(Items, "IncomeItem",						"Visible", IncomeItemVisible);
	CommonClientServer.SetFormItemProperty(Items, "RegisterIncome",					"Visible", RegisterIncomeVisible);
	CommonClientServer.SetFormItemProperty(Items, "VATAmount",						"ReadOnly", ThisIsPurchaseReturn Or IsDropShipping);
	CommonClientServer.SetFormItemProperty(Items, "GroupInventory", 				"Visible", ThisIsPurchaseReturn Or IsDropShipping);
	CommonClientServer.SetFormItemProperty(Items, "AdjustedAmount", 				"ReadOnly", ThisIsPurchaseReturn Or IsDropShipping);
	CommonClientServer.SetFormItemProperty(Items, "GroupBasisDocument", 			"Visible", BasisDocumentVisible);
	CommonClientServer.SetFormItemProperty(Items, "InventorySupplierInvoice",       "Visible", Not BasisDocumentVisible Or IsDropShipping);
	CommonClientServer.SetFormItemProperty(Items, "InventoryGoodsIssue",			"Visible", Not BasisDocumentVisible);
	CommonClientServer.SetFormItemProperty(Items, "GLAccount", 						"Visible", UseDefaultTypeOfAccounting And Not ThisIsPurchaseReturn And Not IsDropShipping);
	CommonClientServer.SetFormItemProperty(Items, "AdjustedAmount", 				"Enabled", Not ThisIsPurchaseReturn And Not IsDropShipping);
	CommonClientServer.SetFormItemProperty(Items, "VATAmount",						"Enabled", Not ThisIsPurchaseReturn And Not IsDropShipping);
	CommonClientServer.SetFormItemProperty(Items, "GroupDebitedTransactions", 		"Visible", Not ThisIsPurchaseReturn And Not IsDropShipping);
	CommonClientServer.SetFormItemProperty(Items, "AmountAllocationProject",		"Visible", Not ThisIsPurchaseReturn And Not IsDropShipping);
	CommonClientServer.SetFormItemProperty(Items, "VAT", 							"Visible", Not ThisIsPurchaseReturn And SubjectToVAT And Not IsDropShipping);
	CommonClientServer.SetFormItemProperty(Items, "InventoryVATRate", 				"Visible", SubjectToVAT);
	CommonClientServer.SetFormItemProperty(Items, "InventoryVATAmount",				"Visible", SubjectToVAT);
	CommonClientServer.SetFormItemProperty(Items, "InventoryTotalVATAmount",		"Visible", SubjectToVAT);
	CommonClientServer.SetFormItemProperty(Items, "AmountAllocationVATRate", 		"Visible", SubjectToVAT);
	CommonClientServer.SetFormItemProperty(Items, "AmountAllocationVATAmount",		"Visible", SubjectToVAT);
	CommonClientServer.SetFormItemProperty(Items, "AmountAllocationTotalVATAmount",	"Visible", SubjectToVAT);
	CommonClientServer.SetFormItemProperty(Items, "TaxInvoiceText", 				"Visible", 	UseTaxInvoice And SubjectToVAT);
	CommonClientServer.SetFormItemProperty(Items, "Totals", 						"Visible", 	ThisIsPurchaseReturn Or IsDropShipping);
	CommonClientServer.SetFormItemProperty(Items, "Warehouse",						"Visible",	ThisIsPurchaseReturn 
																						And Not UseGoodsReturnToSupplier);
	CommonClientServer.SetFormItemProperty(Items, "InventoryPrice", 				"ReadOnly", Not IsDropShipping Or Not ValueIsFilled(Object.BasisDocument)
																						Or Not TypeOf(Object.BasisDocument) = Type("DocumentRef.CreditNote"));
	
	FormManagementServer(IsDropShipping);
	
EndProcedure

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val CatalogCounterparty)
	
	Attributes = "DoOperationsByContracts, VATTaxation";
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, CatalogCounterparty, Attributes);
	
EndProcedure

&AtServer
Procedure SetContractVisible()
	
	Items.Contract.Visible = CounterpartyAttributes.DoOperationsByContracts;
	
EndProcedure

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.InventoryPrice);
	
	Return Fields;
	
EndFunction

&AtClient
Procedure FillAmounAllocationGLAccounts()
	
	TabularSectionRow = Items.AmountAllocation.CurrentData;
	StructureData = GetStructureDataForGLAccounts(ThisObject, "AmountAllocation", StructureData, TabularSectionRow);
	
	If ValueIsFilled(TabularSectionRow.Contract) Then
		StructureData = GetDataAmountAllocationContractOnChange(StructureData);
		FillPropertyValues(TabularSectionRow, StructureData);
	Else
		TabularSectionRow.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckGoodsReturn(Cancel)
	
	For Each Row In Object.Inventory Do
		If Row.Quantity > Row.InitialQuantity Then
			CommonClientServer.MessageToUser(
					NStr("en = 'Return quantity cannot exceed Initial quantity. Edit Return quantity. Then try again.'; ru = 'Возвращаемое количество не может превышать первоначальное количество. Измените возвращаемое количество и повторите попытку.';pl = 'Ilość zwrotu nie może przekraczać ilości początkowej. Zmień ilość zwrotu. Zatem spróbuj ponownie.';es_ES = 'La cantidad de devolución no puede superar la cantidad inicial. Edite la cantidad de devolución. Inténtelo de nuevo.';es_CO = 'La cantidad de devolución no puede superar la cantidad inicial. Edite la cantidad de devolución. Inténtelo de nuevo.';tr = 'İade miktarı Başlangıç miktarından fazla olamaz. İade miktarını düzeltip tekrar deneyin.';it = 'Quantità restituita non può eccedere la Quantità iniziale. Modificare Quantità restituita, poi riprovare.';de = 'Die Retouren- Menge darf die Anfangsmenge nicht überschreiten. Bearbeiten Sie die Retouren- Menge. Dann versuchen Sie erneut.'"),,
					CommonClientServer.PathToTabularSection("Object.Inventory", Row.LineNumber, "Quantity"),,
					Cancel);
					
			Break;
		ElsIf Row.Amount > Row.InitialAmount Then
			CommonClientServer.MessageToUser(
					NStr("en = 'Adjusted amount cannot exceed Initial amount. Edit Adjusted amount. Then try again.'; ru = 'Сумма корректировки не может превышать первоначальную сумму. Измените сумму корректировки и повторите попытку.';pl = 'Wartość skorygowana nie może przekraczać Wartości początkowej. Zmień Wartość skorygowaną. Zatem spróbuj ponownie.';es_ES = 'El importe ajustado no puede superar el importe inicial. Edite el importe ajustado. Inténtelo de nuevo.';es_CO = 'El importe ajustado no puede superar el importe inicial. Edite el importe ajustado. Inténtelo de nuevo.';tr = 'Düzeltilmiş tutar Başlangıç tutarından fazla olamaz. Düzeltilmiş tutarı değiştirip tekrar deneyin.';it = 'L''importo corretto non può eccedere l''Importo iniziale. Modificare Importo corretto, poi riprovare.';de = 'Der korrigierte Betrag darf die Anfangsmenge nicht überschreiten. Bearbeiten Sie den korrigierten Betrag. Dann versuchen Sie erneut.'"),,
					CommonClientServer.PathToTabularSection("Object.Inventory", Row.LineNumber, "Amount"),,
					Cancel);
					
			Break;
		EndIf; 
	EndDo;
	
EndProcedure

&AtServer
Procedure CheckDropShippingReturn()
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesDebitNote.DropShipping") Then
		
		Params = New Structure("Company, Date", Object.Company, Object.Date);
		DriveServer.DropShippingReturnIsSupported(Params);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function BasisDocumentSynonym(DocumentName)
	Return Metadata.Documents[DocumentName].Synonym;
EndFunction

&AtServer
Procedure FormManagementServer(IsDropShipping)
	
	ChoiceParametersArray = New Array;
	If Not IsDropShipping Then
		NewLink = New ChoiceParameterLink("Filter.Contract", "Object.Contract");
		ChoiceParametersArray.Add(NewLink);
		NewLink = New ChoiceParameterLink("Filter.Counterparty", "Object.Counterparty");
		ChoiceParametersArray.Add(NewLink);
	EndIf;
	
	ChoiceParametersFixArray = New FixedArray(ChoiceParametersArray);
	Items.BasisDocument.ChoiceParameterLinks = ChoiceParametersFixArray;
	
EndProcedure

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion