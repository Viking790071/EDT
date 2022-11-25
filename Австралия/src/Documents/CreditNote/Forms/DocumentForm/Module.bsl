
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
	
	// Bundles
	RefreshBundleAttributes(Object.Inventory);
	// End Bundles
	
	FillProductsTypes();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	AdjustedAmount = Object.AdjustedAmount;
	
	If Object.OperationKind <> PredefinedValue("Enum.OperationTypesCreditNote.SalesReturn") Then
		AdjustedAmount = AdjustedAmount	+ ?(Object.AmountIncludesVAT, 0, Object.VATAmount);
	EndIf;
	
	CheckGoodsReturn(Cancel);
	
	If Not Cancel And Object.AmountAllocation.Count() <> 0
		AND Object.AmountAllocation.Total("OffsetAmount") <> AdjustedAmount Then 
		
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
	
	If AmountsHaveChanged And Object.OperationKind = Enums.OperationTypesCreditNote.SalesReturn Then
		CurrentObject.AdjustedAmount = CurrentObject.Inventory.Total("Total") + CurrentObject.SalesTax.Total("Amount");
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
	
	If ChoiceSource.FormName = "Document.TaxInvoiceIssued.Form.DocumentForm" Then
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
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If UsersClientServer.IsExternalUserSession() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
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
	
	If ValueIsFilled(Contract) Then
		SettlementCurrency = Common.ObjectAttributeValue(Contract, "SettlementsCurrency");
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		SetDefaultValuesForIncomeAndExpenseItem(Object.OperationKind, Object.ExpenseItem);
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
	SetChoiceParameterLinks();
	
	If GetFunctionalOption("UseAccountReceivableAdjustments") Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCreditNote.Adjustments);
	EndIf;
	
	If Not ValueIsFilled(Object.Ref)
		And Not ValueIsFilled(Parameters.Basis) 
		And Not ValueIsFilled(Parameters.CopyingValue) Then
		
		FillVATRateByCompanyVATTaxation();
		FillSalesTaxRate();
		
	EndIf;
	
	If ValueIsFilled(Parameters.CopyingValue)
		And ValueIsFilled(Object.BasisDocument) 
		And Not ValueIsFilled(Object.Ref)
		And Object.OperationKind = Enums.OperationTypesCreditNote.SalesReturn Then
		
		FillByDocument(Object.BasisDocument);
		
	EndIf;

	// Generate price and currency label.
	ForeignExchangeAccounting = GetFunctionalOption("ForeignExchangeAccounting");
	GenerateLabelPricesAndCurrency(ThisObject);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", True);
	
	FillAddedColumns(ParametersStructure);
	
	FillProductsTypes();
	
	SendGoodsOnConsignment 	= GetFunctionalOption("SendGoodsOnConsignment");
	UseTolling 				= GetFunctionalOption("UseSubcontractingManufacturing");
	UseRetail 				= GetFunctionalOption("UseRetail");
	
	If TypeOf(Object.BasisDocument) = Type("DocumentRef.SalesSlip") Then
		ShiftClosure = Common.ObjectAttributeValue(Object.BasisDocument, "CashCRSession");
	EndIf;
	
	WorkWithVAT.SetTextAboutTaxInvoiceIssued(ThisObject);
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	
	SetContractVisible();
	
	// Bundles
	BundlesOnCreateAtServer();
	
	If Not ValueIsFilled(Object.Ref) Then
		
		RefreshBundlePictures(Object.Inventory);
		RefreshBundleAttributes(Object.Inventory);
		
	EndIf;
	
	SetBundlePictureVisible();
	SetBundleConditionalAppearance();
	// End Bundles
	
	ProcessingCompanyVATNumbers();
	
	SetFormConditionalAppearance();
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
	// StandardSubsystems.Interactions
	Interactions.PrepareNotifications(ThisObject, Parameters);
	// End StandardSubsystems.Interactions
	
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
	
	ChangeVisibleCOGSItem();
	
	DriveServer.CheckObjectGeneratedEnteringBalances(ThisObject);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", True);
	
	FillAddedColumns(ParametersStructure);
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Bundles
	RefreshBundlePictures(Object.Inventory);
	RefreshBundleAttributes(Object.Inventory);
	// End Bundles
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
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
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCreditNote.SalesReturn") Then
		RecalculateSubtotal();
	EndIf;
	
	If Parameters.Key.IsEmpty() Then
		WorkWithVATClient.ShowReverseChargeNotSupportedMessage(Object.VATTaxation);
		CheckDropShippingReturn();
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	// StandardSubsystems.Interactions
	InteractionsClient.InteractionSubjectAfterWrite(ThisObject, Object, WriteParameters, "CreditNote");
	// End StandardSubsystems.Interactions
	
	If TypeOf(FormOwner) = Type("ClientApplicationForm") Then
		
		// CWP
		If Find(FormOwner.FormName, "DocumentForm_CWP") > 0 Then
			Notify("CWP_Write_CreditNote", New Structure("Ref, Number, Date", Object.Ref, Object.Number, Object.Date));
		EndIf;
		// End CWP
		
		If Find(FormOwner.FormName, "CashReceipt") > 0
			OR Find(FormOwner.FormName, "PaymentReceipt") > 0 Then
			
			StructureParameter = New Structure;
			StructureParameter.Insert("Ref", Object.Ref);
			StructureParameter.Insert("Number", Object.Number);
			StructureParameter.Insert("Date", Object.Date);
			StructureParameter.Insert("BasisDocument", Object.BasisDocument);
			
			Notify("RefreshCreditNoteText", StructureParameter);
			
		EndIf;
		
	EndIf;
	
	// Bundles
	RefreshBundlePictures(Object.Inventory);
	// End Bundles
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

#EndRegion

#Region FormItemEventHandlers

&AtClient
Procedure BasisDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Item", Item);
	
	DocumentTypes = New ValueList;
	
	DocumentTypes.Add("SalesInvoice", NStr("en = 'Sales invoice'; ru = 'Инвойс покупателю';pl = 'Faktura sprzedaży';es_ES = 'Factura de ventas';es_CO = 'Factura de ventas';tr = 'Satış faturası';it = 'Fattura di vendita';de = 'Verkaufsrechnung'"));
	
	If UseGoodsReturnFromCustomer Then
		DocumentTypes.Add("GoodsReceipt", NStr("en = 'Goods receipt'; ru = 'Поступление товаров';pl = 'Przyjęcie zewnętrzne';es_ES = 'Recibo de mercancías';es_CO = 'Recibo de mercancías';tr = 'Ambar girişi';it = 'Ricezione merce';de = 'Wareneingang'"));
	EndIf;
	
	If UseRetail Then
		DocumentTypes.Add("SalesSlip", NStr("en = 'Sales slip'; ru = 'Кассовый чек';pl = 'Paragon kasowy';es_ES = 'Factura de compra';es_CO = 'Factura de compra';tr = 'Satış fişi';it = 'Corrispettivo';de = 'Verkaufsbeleg'"));
	EndIf;
	
	DocumentTypes.Add("CashReceipt", NStr("en = 'Cash receipt'; ru = 'Приходный кассовый ордер';pl = 'KP - Dowód wpłaty';es_ES = 'Recibo de efectivo';es_CO = 'Recibo de efectivo';tr = 'Nakit tahsilat';it = 'Entrata di cassa';de = 'Zahlungseingang'"));
	DocumentTypes.Add("PaymentReceipt", NStr("en = 'Bank receipt'; ru = 'Поступление на счет';pl = 'Potwierdzenie zapłaty';es_ES = 'Recibo bancario';es_CO = 'Recibo bancario';tr = 'Banka tahsilatı';it = 'Ricevuta bancaria';de = 'Eingang'"));
	
	Descr = New NotifyDescription("BasisDocumentSelectEnd", ThisObject, AdditionalParameters);
	DocumentTypes.ShowChooseItem(Descr, NStr("en = 'Select document type'; ru = 'Выберите тип документа';pl = 'Wybierz rodzaj dokumentu';es_ES = 'Seleccionar el tipo de documento';es_CO = 'Seleccionar el tipo de documento';tr = 'Belge türü seç';it = 'Selezionare il tipo di documento';de = 'Dokumententyp auswählen'"));
	
EndProcedure

&AtClient
Procedure BasisDocumentSelectEnd(SelectedElement, AdditionalParameters) Export
	
	If SelectedElement = Undefined Then
		Return;
	EndIf;
	
	Filter = New Structure();
	Filter.Insert("Company", Object.Company);
	
	If SelectedElement.Value <> "SalesSlip" Then
		
		Filter.Insert("Counterparty", Object.Counterparty);
		
		If SelectedElement.Value <> "CashReceipt"
			AND SelectedElement.Value <> "PaymentReceipt" Then
			
			Filter.Insert("Contract", Object.Contract);
			
		EndIf;
		
	EndIf;
	
	ParametersStructure = New Structure();
	ParametersStructure.Insert("Filter", Filter);

	FillByBasisEnd = New NotifyDescription("FillByBasisEnd", ThisObject, AdditionalParameters);
	
	OpenForm("Document." + SelectedElement.Value + ".ChoiceForm", ParametersStructure, AdditionalParameters.Item);
	
EndProcedure

&AtClient
Procedure BasisDocumentChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If TypeOf(SelectedValue) = Type("Array")
		AND SelectedValue.Count() > 0 Then
		
		Object.BasisDocument = SelectedValue[0];
	Else
		Object.BasisDocument = SelectedValue;
	EndIf;
	
	If ValueIsFilled(Object.BasisDocument) Then 
		
		FillByDocument(Object.BasisDocument);
		
		If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
			ClearVATAmount();
		EndIf;
		
		FormManagement();
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", False);
		ParametersStructure.Insert("FillHeader", True);
		ParametersStructure.Insert("FillInventory", True);
		ParametersStructure.Insert("FillAmountAllocation", True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
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
		
		ContractData = GetDataContractOnChange(Object.Date, Object.Contract);
		SettlementCurrency = ContractData.SettlementsCurrency;
		
		If ValueIsFilled(Object.Contract) Then 
			ContractValues = ContractData.SettlementsCurrencyRateRepetition;
			Object.ExchangeRate	= ?(ContractValues.Rate = 0, 1, ContractValues.Rate);
			Object.Multiplicity = ?(ContractValues.Repetition = 0, 1, ContractValues.Repetition);
			Object.ContractCurrencyExchangeRate = Object.ExchangeRate;
			Object.ContractCurrencyMultiplicity = Object.Multiplicity;
		EndIf;
		
		Object.DocumentCurrency = SettlementCurrency;
		
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", True);
	
	FillAddedColumns(ParametersStructure);
	
	SetAccountingPolicyValues();
	FillSalesTaxRate();
	FillVATRateByCompanyVATTaxation();
	SetAutomaticVATCalculation();
	
	// Generate price and currency label.
	GenerateLabelPricesAndCurrency(ThisObject);
	
	ProcessingCompanyVATNumbers(False);
	
	ChangeVisibleCOGSItem();
	
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
	
	DocumentAttributes = New Structure("Ref, Company, Counterparty, Contract, BasisDocument, DocumentCurrency, OperationKind");
	FillPropertyValues(DocumentAttributes, Object);
	
	FormParameters = GetChoiceFormOfContractParameters(DocumentAttributes, CounterpartyAttributes.DoOperationsByContracts);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CounterpartyOnChangeAtServer()
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
	
	FillVATRateByCompanyVATTaxation(True);
	
	FillSalesTaxRate();
	
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
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
Procedure AdjustedAmountOnChange(Item)
	
	CalculateTotalVATAmount();
	
EndProcedure

&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies();
		
EndProcedure

&AtClient
Procedure OperationKindOnChange(Item)
	
	Object.CreditedTransactions.Clear();
	Object.Inventory.Clear();
	Object.AmountAllocation.Clear();
	
	FillSalesTaxRate();
	
	SetDefaultValuesForIncomeAndExpenseItem(Object.OperationKind, Object.ExpenseItem);
	
	If UseDefaultTypeOfAccounting Then 
		SetDefaultValuesForGLAccount();
	EndIf;
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure TaxInvoiceTextClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	WorkWithVATClient.OpenTaxInvoice(ThisForm);
	
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
Procedure RegisterExpenseOnChange(Item)
	FormManagement();
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableCreditedTransactions

&AtClient
Procedure CreditedTransactionsDocumentOnChange(Item)
	
	CurrentData = Items.CreditedTransactions.CurrentData;
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("CurrentData",		CurrentData);
	AdditionalParameters.Insert("MultipleChoice",	False);

	FillCreditTransaction(CurrentData.Document, AdditionalParameters);
	
EndProcedure

&AtClient
Procedure CreditedTransactionsDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	CreditedTransactionsStartChoice(False, Item);
	
EndProcedure

&AtClient
Procedure CreditedTransactionsSelectEnd(SelectedElement, AdditionalParameters) Export
	
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
	
	FillCreditTransaction = New NotifyDescription("FillCreditTransaction", ThisObject, AdditionalParameters);
	If AdditionalParameters.MultipleChoice Then
		OpenedForm = OpenForm("Document." + SelectedElement.Value + ".ChoiceForm", ParametersStructure,,,,, FillCreditTransaction);
	Else
		OpenedForm = OpenForm("Document." + SelectedElement.Value + ".ChoiceForm", ParametersStructure,AdditionalParameters.Item);
	EndIf;
	
	TabularSectionName = GetTabularSectionName(SelectedElement.Value);
	CommonClientServer.AddCompositionItem(OpenedForm.List.Filter, TabularSectionName + ".VATRate",
												DataCompositionComparisonType.Equal, Object.VATRate,, True);   
	
EndProcedure

&AtClient
Procedure CreditedTransactionsStartChoice(MultipleChoice, Item = Undefined)
	
	DocumentTypes = New ValueList;
	
	If SendGoodsOnConsignment Then
		DocumentTypes.Add("AccountSalesFromConsignee",		NStr("en = 'Account sales from consignee'; ru = 'Отчет комиссионера';pl = 'Raport sprzedaży od komisanta';es_ES = 'Informe de ventas de los destinatarios';es_CO = 'Ventas de cuenta del destinatario';tr = 'Konsinye satışlar';it = 'Conto di vendite dall''agente in conto vendita';de = 'Verkaufsbericht (Kommissionär)'"));
	EndIf;
	
	DocumentTypes.Add("CreditNote", 			NStr("en = 'Credit note'; ru = 'Кредитовое авизо';pl = 'Nota kredytowa';es_ES = 'Nota de crédito';es_CO = 'Nota de haber';tr = 'Alacak dekontu';it = 'Nota di credito';de = 'Gutschrift'"));
	DocumentTypes.Add("SalesInvoice",	 		NStr("en = 'Sales invoice'; ru = 'Инвойс покупателю';pl = 'Faktura sprzedaży';es_ES = 'Factura de ventas';es_CO = 'Factura de ventas';tr = 'Satış faturası';it = 'Fattura di vendita';de = 'Verkaufsrechnung'"));
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Item",				Item);
	AdditionalParameters.Insert("MultipleChoice",	MultipleChoice);
	
	Descr = New NotifyDescription("CreditedTransactionsSelectEnd", ThisObject, AdditionalParameters);
	DocumentTypes.ShowChooseItem(Descr, NStr("en = 'Select document type'; ru = 'Выберите тип документа';pl = 'Wybierz rodzaj dokumentu';es_ES = 'Seleccionar el tipo de documento';es_CO = 'Seleccionar el tipo de documento';tr = 'Belge türü seç';it = 'Selezionare il tipo di documento';de = 'Dokumententyp auswählen'"));
	
EndProcedure

&AtClient
Procedure FillCreditTransaction(Documents, AdditionalParameters) Export
	
	AddCreditTransactionsAtServer(Documents);
	
	For Each TableRow In CreditedTransactionData Do
		
		If CreditedTransactionData.IndexOf(TableRow) > 0 Or AdditionalParameters.MultipleChoice Then
			NewRow = Object.CreditedTransactions.Add();
		ElsIf AdditionalParameters.Property("CurrentData") Then
			NewRow = AdditionalParameters.CurrentData;
		EndIf;
		
		FillPropertyValues(NewRow, TableRow);
		
	EndDo;
	
	If CreditedTransactionData.Count() Then
		Modified = True;
	EndIf;
	
	CreditedTransactionData.Clear();
	
EndProcedure

&AtServer
Procedure AddCreditTransactionsAtServer(Documents)
	
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
	|	SalesTurnovers.Recorder AS Document,
	|	SalesTurnovers.VATRate AS VATRate,
	|	CASE
	|		WHEN SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover > 0
	|			THEN (SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover)
	|		ELSE -(SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover)
	|	END AS Amount,
	|	CASE
	|		WHEN SalesTurnovers.VATAmountTurnover > 0
	|			THEN SalesTurnovers.VATAmountTurnover
	|		ELSE -SalesTurnovers.VATAmountTurnover
	|	END AS VATAmount
	|FROM
	|	AccumulationRegister.Sales.Turnovers(,, Recorder, ) AS SalesTurnovers
	|WHERE
	|	SalesTurnovers.Recorder IN(&Documents)
	|	AND &DocumentCondition
	|
	|ORDER BY
	|	SalesTurnovers.Recorder,
	|	SalesTurnovers.VATRate
	|AUTOORDER";
	
	Query.Text = StrReplace(Query.Text, "&DocumentCondition", "SalesTurnovers.Recorder REFS Document." + DocumentType);
	
	ValueToFormAttribute(Query.Execute().Unload(), "CreditedTransactionData");
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableInventory

&AtClient
Procedure InventoryAfterDeleteRow(Item)
	RecalculateSalesTax();
	RecalculateSubtotal();
	CalculateTotalVATAmount();
EndProcedure

&AtClient
Procedure InventoryAmountAdjustedOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	
	CalculateVATAmount(CurrentData, CurrentData.Amount);
	CalculateTotalAmount(CurrentData);
	RecalculateSalesTax();
	RecalculateSubtotal();
	CalculateTotalVATAmount();
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	// Bundles
	
	If Items.Inventory.SelectedRows.Count() = Object.Inventory.Count() Then
		
		Object.AddedBundles.Clear();
		SetBundlePictureVisible();
		
	Else
		
		BundleData = New Structure("BundleProduct, BundleCharacteristic");
		
		For Each SelectedRow In Items.Inventory.SelectedRows Do
			
			SelectedRowData = Items.Inventory.RowData(SelectedRow);
			
			If BundleData.BundleProduct = Undefined Then
				
				BundleData.BundleProduct = SelectedRowData.BundleProduct;
				BundleData.BundleCharacteristic = SelectedRowData.BundleCharacteristic;
				
			ElsIf BundleData.BundleProduct <> SelectedRowData.BundleProduct
				Or BundleData.BundleCharacteristic <> SelectedRowData.BundleCharacteristic Then
				
				CommonClientServer.MessageToUser(
					NStr("en = 'Action is unavailable for bundles.'; ru = 'Это действие недоступно для наборов.';pl = 'Działanie nie jest dostępne dla zestawów.';es_ES = 'La acción no está disponible para los paquetes.';es_CO = 'La acción no está disponible para los paquetes.';tr = 'Bu işlem setler için kullanılamaz.';it = 'Azione non disponibile per kit di prodotti.';de = 'Für Bündel ist die Aktion nicht verfügbar.'"),,
					"Object.Inventory",,
					Cancel);
				Break;
				
			EndIf;
			
		EndDo;
		
		If Not Cancel And ValueIsFilled(BundleData.BundleProduct) Then
			
			Cancel = True;
			AddedBundles = Object.AddedBundles.FindRows(BundleData);
			Notification = New NotifyDescription("InventoryBeforeDeleteRowEnd", ThisObject, BundleData);
			ButtonsList = New ValueList;
			
			QuestionText = BundlesClient.QuestionTextOneBundle();
			ButtonsList.Add(DialogReturnCode.Yes,	BundlesClient.AswerDeleteAllComponents());
			ButtonsList.Add(DialogReturnCode.Cancel);
			
			ShowQueryBox(Notification, QuestionText, ButtonsList, 0, DialogReturnCode.Yes);
			
		EndIf;
		
	EndIf;
	// End Bundles
	
	If Not Cancel Then
		CurrentData = Items.Inventory.CurrentData;
		WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData,,UseSerialNumbersBalance);
	EndIf;
	
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
	
	Document = ?(ValueIsFilled(Object.BasisDocument), Object.BasisDocument, CurrentData.SalesDocument);
	
	If CurrentData.Shipped Then
		
		StructureData = New Structure;
		StructureData.Insert("Ref",					Object.Ref);
		StructureData.Insert("Products",			CurrentData.Products);
		StructureData.Insert("Characteristic",		CurrentData.Characteristic);
		StructureData.Insert("Batch",				CurrentData.Batch);
		StructureData.Insert("Quantity", 			CurrentData.Quantity);
		StructureData.Insert("MeasurementUnit",		CurrentData.MeasurementUnit);
		StructureData.Insert("Shipped",				CurrentData.Shipped);
		StructureData.Insert("Document",			Document);
		StructureData.Insert("Date", 				Object.Date);
		CurrentData.CostOfGoodsSold = GetCostAmount(StructureData);
	Else
		CurrentData.CostOfGoodsSold = 0;
	EndIf;
	
	CalculateVATAmount(CurrentData, CurrentData.Amount);
	CalculateTotalAmount(CurrentData);
	RecalculateSalesTax();
	RecalculateSubtotal();
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
Procedure InventoryCostOfGoodsSoldOnChange(Item)

	CurrentData = Items.Inventory.CurrentData;
	If Not CurrentData.Shipped Then
		CurrentData.CostOfGoodsSold = 0;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryTaxableOnChange(Item)
	
	RecalculateSalesTax();
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure InventoryIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "Inventory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure InventoryDropShippingOnChange(Item)
	
	CurData = Items.Inventory.CurrentData;
	If CurData <> Undefined Then
		CurData.DropShipping = Not CurData.DropShipping;
		ShowQueryBox(New NotifyDescription("DropShippingOnChangeEnd", ThisObject, New Structure("DropShipping", Not CurData.DropShipping)),
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'You are about to change the delivery method for a product return.
				|It is recommended to apply the same delivery method for recording the product sale and return.
				|Are you sure you want to change the delivery method for the product in line %1?'; 
				|ru = 'Вы собираетесь изменить способ доставки для возврата товара.
				|Рекомендуется использовать одинаковый способ доставки для продажи и возврата товара.
				|Изменить способ доставки для номенклатуры в строке %1?';
				|pl = 'Zamierzasz zmienić metodę dostawy dla zwrotu produktu.
				|Zaleca się stosowanie tej samej metody dostawy do rejestrowania sprzedaży i zwrotu produktu.
				|Czy na pewno chcesz zmienić metodę dostawy dla produktu w wierszu %1?';
				|es_ES = 'Usted va a cambiar el método de entrega para la devolución de un producto.
				|Se recomienda aplicar el mismo método de entrega para registrar la venta y la devolución del producto
				|¿Está seguro de que desea cambiar el método de entrega del producto en línea%1?';
				|es_CO = 'Usted va a cambiar el método de entrega para la devolución de un producto.
				|Se recomienda aplicar el mismo método de entrega para registrar la venta y la devolución del producto
				|¿Está seguro de que desea cambiar el método de entrega del producto en línea%1?';
				|tr = 'Ürün iadesi için teslimat yöntemini değiştirmek üzeresiniz.
				|Ürün satışını ve iadesini kaydetmek için aynı teslimat yöntemini uygulamanız önerilir.
				|%1 satırındaki ürün için teslimat yöntemini değiştirmek istediğinizden emin misiniz?';
				|it = 'Vuoi modificare il metodo di consegna per il reso di un articolo.
				|Si consiglia di applicare lo stesso metodo di consegna per registrare la vendita dei prodotti e il reso.
				|Vuoi comunque modificare il metodo di consegna dell''articolo nella riga %1?';
				|de = 'Sie möchten die Zustellungsmethode für eine Produktrückgabe ändern.
				|Es ist empfehlenswert dieselbe Zustellungsmethode für Buchung von Produktverkauf und Rückgabe zu verwenden.
				|Sind Sie sicher dass Sie die Zustellungmethode für das Produkt in der Zeile %1 ändern möchten?'"),
				CurData.LineNumber),
			QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure

&AtClient
Procedure DropShippingOnChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		CurData = Items.Inventory.CurrentData;
		CurData.DropShipping = AdditionalParameters.DropShipping;
		
		If CurData.DropShipping Then
			CheckDropShippingReturn();
		EndIf;
	EndIf;

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
	
	FillAmounAllocationGLAccounts();
	
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
		StructureFilter.Insert("Counterparty",		Object.Counterparty);
		StructureFilter.Insert("DocumentCurrency",	Object.DocumentCurrency);
		
		If ValueIsFilled(TabularSectionRow.Contract) Then
			StructureFilter.Insert("Contract", TabularSectionRow.Contract);
		EndIf;
		
		ParameterStructure = New Structure("Filter, ThisIsAccountsReceivable, DocumentType",
											StructureFilter,
											True,
											TypeOf(Object.Ref));
		
		OpenForm("CommonForm.SelectDocumentOfSettlements", ParameterStructure, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AmountAllocationDocumentChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	
	FillAmounAllocationGLAccounts();
	
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

// Procedure is filling the allocation amount.
//
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

#Region FormItemEventHandlersFormTableSalesTax

&AtClient
Procedure SalesTaxSalesTaxRateOnChange(Item)
	
	SalesTaxTabularRow = Items.SalesTax.CurrentData;
	
	If SalesTaxTabularRow <> Undefined AND ValueIsFilled(SalesTaxTabularRow.SalesTaxRate) Then
		
		SalesTaxTabularRow.SalesTaxPercentage = GetSalesTaxPercentage(SalesTaxTabularRow.SalesTaxRate);
		
		CalculateSalesTaxAmount(SalesTaxTabularRow);
		
	EndIf;
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure SalesTaxSalesTaxPercentageOnChange(Item)
	
	SalesTaxTabularRow = Items.SalesTax.CurrentData;
	
	If SalesTaxTabularRow <> Undefined AND ValueIsFilled(SalesTaxTabularRow.SalesTaxRate) Then
		
		CalculateSalesTaxAmount(SalesTaxTabularRow);
		
	EndIf;
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure SalesTaxAmountOnChange(Item)
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure SalesTaxAfterDeleteRow(Item)
	
	RecalculateSubtotal();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CreditedTransactionsSelect(Command)
	
	CreditedTransactionsStartChoice(True);
	
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
		ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
			NStr("en = 'Do you want to refill the credit note?'; ru = 'Документ будет полностью перезаполнен по основанию. Продолжить?';pl = 'Czy chcesz uzupełnić notę kredytową?';es_ES = '¿Quiere volver a rellenar la nota de crédito?';es_CO = '¿Quiere volver a rellenar la nota de crédito?';tr = 'Alacak dekontu yeniden doldurulsun mu?';it = 'Volete ricompilare la nota di credito?';de = 'Möchten Sie die Gutschrift auffüllen?'"),
			QuestionDialogMode.YesNo);
	Else
		MessagesToUserClient.ShowMessageSelectBaseDocument();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillByPeriod(Command)
	
	Notify = New NotifyDescription("FillByPeriodEnd", ThisObject);
	
	If Object.CreditedTransactions.Count() = 0 Then
		ExecuteNotifyProcessing(Notify, DialogReturnCode.Yes); 
	Else
		ShowQueryBox(Notify, NStr("en = 'The tabular section will be refilled. Do you want to continue?'; ru = 'Табличная часть будет полностью перезаполнена. Продолжить?';pl = 'Sekcja tabelaryczna zostanie wypełniona ponownie. Czy chcesz kontynuować?';es_ES = 'La sección tabular se volverá a rellenar. ¿Quiere continuar?';es_CO = 'La sección tabular se volverá a rellenar. ¿Quiere continuar?';tr = 'Tablo bölümü yeniden doldurulacak. Devam etmek istiyor musunuz?';it = 'La sezione tabellare sarà ricompilata. Volete continuare?';de = 'Der Tabellenbereich wird wieder aufgefüllt. Fortsetzen?'"), QuestionDialogMode.YesNo, 0);
	EndIf;
	
EndProcedure

&AtClient
Procedure FillSalesTax(Command)
	
	RecalculateSalesTax();
	
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

#Region Private

#Region GLAccounts

&AtClient
Function GetStructureDataForGLAccounts(Form, TabName, StructureData, TabRow)
	
	StructureData = New Structure;
	StructureData.Insert("TabName", 				TabName);
	StructureData.Insert("Object",					Form.Object);
	StructureData.Insert("CounterpartyGLAccounts",	True);
	StructureData.Insert("GLAccounts",				TabRow.GLAccounts);
	StructureData.Insert("GLAccountsFilled",		TabRow.GLAccountsFilled);
	
	StructureData.Insert("AccountsReceivableGLAccount",	TabRow.AccountsReceivableGLAccount);
	StructureData.Insert("AdvancesReceivedGLAccount",	TabRow.AdvancesReceivedGLAccount);
	
	StructureData.Insert("VATOutputGLAccount",	TabRow.VATOutputGLAccount);
	StructureData.Insert("Document",			TabRow.Document);
	StructureData.Insert("VATRate",				TabRow.VATRate);
	StructureData.Insert("LineNumber",			TabRow.LineNumber);
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure FillAddedColumns(ParametersStructure)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	StructureArray = New Array();
	
	If UseDefaultTypeOfAccounting Then
		
		If ParametersStructure.FillHeader Then
			
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
		
		If UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters);
		EndIf;
		
		StructureArray.Add(StructureData);
		
	EndIf;
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, ParametersStructure.GetGLAccounts);
	
EndProcedure

&AtServer
Procedure FillProductsTypes()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Inventory.Products AS Products
	|INTO Inventory
	|FROM
	|	&Inventory AS Inventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	CatalogProducts.Ref AS Products,
	|	CatalogProducts.ProductsType AS ProductsType
	|FROM
	|	Inventory AS Inventory
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON Inventory.Products = CatalogProducts.Ref";
	Query.SetParameter("Inventory", Object.Inventory.Unload(, "Products"));
	
	ProductTypesMap = New Map;
	
	Sel = Query.Execute().Select();
	While Sel.Next() Do
		ProductTypesMap.Insert(Sel.Products, Sel.ProductsType);
	EndDo;
	
	For Each InventoryRow In Object.Inventory Do
		InventoryRow.ProductsType = ProductTypesMap[InventoryRow.Products];
	EndDo;
	
EndProcedure

&AtServer
Procedure GLAccountOnChangeAtServer()
	
	Structure = New Structure("Object, GLAccount, ExpenseItem, Manual");
	Structure.Object = Object;
	FillPropertyValues(Structure, Object);
	
	GLAccountsInDocumentsServerCall.CheckItemRegistration(Structure);
	FillPropertyValues(Object, Structure);
	
	If UseDefaultTypeOfAccounting Then
		Object.RegisterExpense = GLAccountsInDocuments.IsExpenseGLA(Object.GLAccount);
	EndIf;
	
EndProcedure

#EndRegion

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

&AtClient
Procedure RecalculateSubtotal()
	
	AmountTotal = Object.Inventory.Total("Total") + Object.SalesTax.Total("Amount");
	VATAmountTotal = Object.Inventory.Total("VATAmount") + Object.SalesTax.Total("Amount");
	
	Object.AdjustedAmount = AmountTotal;
	Object.DocumentTax = VATAmountTotal;
	Object.DocumentSubtotal = AmountTotal - VATAmountTotal;
	
EndProcedure

&AtClient
Procedure CalculateTotalAmount(CurrentData = Undefined) 
	
	If CurrentData <> Undefined Then
		CurrentData.Total = CurrentData.Amount + ?(Object.AmountIncludesVAT, 0, CurrentData.VATAmount);
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateTotalVATAmount() 
    
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCreditNote.SalesReturn") Then
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

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
		FillByDocument(Object.BasisDocument);
		
		If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
			ClearVATAmount();
		EndIf;
		
		FillProductsTypes();
		FormManagement();
		
    EndIf;

EndProcedure

&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	SetChoiceParameterLinks();
	Modified = True;
	
	FillProductsTypes();
	CheckDropShippingReturn();
	
	ParametersStructure = New Structure;
	
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillInventory", False);
	ParametersStructure.Insert("FillAmountAllocation", True);
	
	FillAddedColumns(ParametersStructure);
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	SetContractVisible();
	
	// Generate price and currency label.
	GenerateLabelPricesAndCurrency(ThisObject);
	
EndProcedure

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
									  		TabularSectionRow.InitialAmount - (TabularSectionRow.InitialAmount) / ((VATRate + 100) / 100),
									  		TabularSectionRow.InitialAmount * VATRate / 100);
			TabularSectionRow.Total		= TabularSectionRow.InitialAmount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
		For Each TabularSectionRow In Object.AmountAllocation Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
			TabularSectionRow.VATAmount		= ?(Object.AmountIncludesVAT, 
										  		TabularSectionRow.OffsetAmount - (TabularSectionRow.OffsetAmount) / ((VATRate + 100) / 100),
										  		TabularSectionRow.OffsetAmount * VATRate / 100);
			TabularSectionRow.OffsetAmount	= TabularSectionRow.OffsetAmount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesDebitNote.PurchaseReturn") Then
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
			TabularSectionRow.Total		= TabularSectionRow.InitialAmount;
			
		EndDo;
		
		For Each TabularSectionRow In Object.AmountAllocation Do
		
			TabularSectionRow.OffsetAmount	= TabularSectionRow.OffsetAmount - ?(Object.AmountIncludesVAT, TabularSectionRow.VATAmount, 0);
			TabularSectionRow.VATRate		= DefaultVATRate;
			TabularSectionRow.VATAmount		= 0;
			
		EndDo;
		
	EndIf;	
	
EndProcedure

&AtClient
Procedure FormManagement()
	
	AccountCurrency = DriveServer.GetPresentationCurrency(Object.Company);
	If Object.DocumentCurrency <> AccountCurrency Then 
		Items.InventoryCostOfGoodsSold.Title = NStr("en = 'COGS'; ru = 'Себестоимость';pl = 'KWS';es_ES = 'COGS';es_CO = 'COGS';tr = 'SMM';it = 'Costo del Venduto';de = 'Wareneinsatz'") + ", " + AccountCurrency;
	EndIf;
	
	VisibleFlags = GetFlagsForFormItemsVisible(Object.OperationKind, Object.VATTaxation, Object.GLAccount, UseDefaultTypeOfAccounting);
	
	ThisIsSalesReturn = VisibleFlags.ThisIsSalesReturn;
	SubjectToVAT = VisibleFlags.SubjectToVAT;
	IsDiscountAllowed = VisibleFlags.IsDiscountAllowed;
	IsExpenseGLA = VisibleFlags.IsExpenseGLA;
	BasisDocumentVisible = ThisIsSalesReturn And Not Object.BasisDocumentInTabularSection Or IsDiscountAllowed;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCreditNote.Adjustments") Then
		Items.ExpenseItem.Title = NStr("en = 'Expense item for adjustment'; ru = 'Статья расходов для корректировки';pl = 'Pozycja dochodów do korekty';es_ES = 'Artículo de gastos para el ajuste';es_CO = 'Artículo de gastos para el ajuste';tr = 'Düzeltme için gider kalemi';it = 'Voce di uscita per l''adeguamento';de = 'Position von Ausgaben zum Anpassen'"); 
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCreditNote.DiscountAllowed") Then
		Items.ExpenseItem.Title = NStr("en = 'Expense item for discount allowed'; ru = 'Статья расходов для предоставленной скидки';pl = 'Dozwolona pozycja rozchodów dla rabatu';es_ES = 'Artículo de gastos para el descuento permitido';es_CO = 'Artículo de gastos para el descuento permitido';tr = 'Verilen indirim için gider kalemi';it = 'Voce di uscita per sconto consentito';de = 'Position von Ausgaben zum Rabatt gestattet'");
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		IsExpenseItemVisible = (Not ThisIsSalesReturn And Not IsDiscountAllowed And IsExpenseGLA);
		IsRegisterExpenseVisible = False;
	Else
		IsExpenseItemVisible = (Not ThisIsSalesReturn And Not IsDiscountAllowed And Object.RegisterExpense);
		IsRegisterExpenseVisible = Not ThisIsSalesReturn And Not IsDiscountAllowed;
	EndIf;
	
	CommonClientServer.SetFormItemProperty(Items, "ExpenseItem",					"Visible", IsExpenseItemVisible);
	CommonClientServer.SetFormItemProperty(Items, "RegisterExpense",				"Visible", IsRegisterExpenseVisible);
	CommonClientServer.SetFormItemProperty(Items, "GroupInventory", 				"Visible", 	ThisIsSalesReturn);
	CommonClientServer.SetFormItemProperty(Items, "AdjustedAmount", 				"ReadOnly", ThisIsSalesReturn);
	CommonClientServer.SetFormItemProperty(Items, "VATAmount",						"ReadOnly", ThisIsSalesReturn);
	CommonClientServer.SetFormItemProperty(Items, "GroupBasisDocument", 			"Visible", 	BasisDocumentVisible);
	CommonClientServer.SetFormItemProperty(Items, "InventorySalesDocument", 		"Visible", 	Not BasisDocumentVisible);
	CommonClientServer.SetFormItemProperty(Items, "InventoryGoodsReceipt", 			"Visible", 	Not BasisDocumentVisible);
	CommonClientServer.SetFormItemProperty(Items, "AdjustedAmount", 				"Enabled", 	Not ThisIsSalesReturn);
	CommonClientServer.SetFormItemProperty(Items, "VATAmount",						"Enabled",	Not ThisIsSalesReturn);
	CommonClientServer.SetFormItemProperty(Items, "GroupCreditedTransactions",		"Visible", 	Not ThisIsSalesReturn);
	CommonClientServer.SetFormItemProperty(Items, "GLAccount",						"Visible", 	UseDefaultTypeOfAccounting And Not ThisIsSalesReturn);
	CommonClientServer.SetFormItemProperty(Items, "AmountAllocationProject",		"Visible",	Not ThisIsSalesReturn);
	CommonClientServer.SetFormItemProperty(Items, "VAT", 							"Visible",	Not ThisIsSalesReturn And SubjectToVAT);
	CommonClientServer.SetFormItemProperty(Items, "InventoryVATRate", 				"Visible",	SubjectToVAT);
	CommonClientServer.SetFormItemProperty(Items, "InventoryVATAmount",				"Visible",	SubjectToVAT);
	CommonClientServer.SetFormItemProperty(Items, "InventoryTotalVATAmount",		"Visible",	SubjectToVAT);
	CommonClientServer.SetFormItemProperty(Items, "AmountAllocationVATRate", 		"Visible",	SubjectToVAT);
	CommonClientServer.SetFormItemProperty(Items, "AmountAllocationVATAmount", 		"Visible",	SubjectToVAT);
	CommonClientServer.SetFormItemProperty(Items, "AmountAllocationTotalVATAmount",	"Visible",	SubjectToVAT);
	CommonClientServer.SetFormItemProperty(Items, "TaxInvoiceText", 				"Visible",	UseTaxInvoice And SubjectToVAT);
	CommonClientServer.SetFormItemProperty(Items, "Totals", 						"Visible",	ThisIsSalesReturn);
	CommonClientServer.SetFormItemProperty(Items, "Warehouse",						"Visible",	ThisIsSalesReturn
																									And Not UseGoodsReturnFromCustomer);
	CommonClientServer.SetFormItemProperty(Items, "GroupSalesTax",					"Visible",	RegisteredForSalesTax AND ThisIsSalesReturn);
	CommonClientServer.SetFormItemProperty(Items, "InventorySalesTaxAmount",		"Visible",	RegisteredForSalesTax AND ThisIsSalesReturn);
	CommonClientServer.SetFormItemProperty(Items, "InventoryTaxable",				"Visible",	RegisteredForSalesTax AND ThisIsSalesReturn);
	CommonClientServer.SetFormItemProperty(Items, "InventoryDropShipping", 			"Visible", 	ThisIsSalesReturn);
	
	SetAdjustedAmountTitle(ThisIsSalesReturn);
	
EndProcedure

&AtServerNoContext
Function GetFlagsForFormItemsVisible(OperationKind, VATTaxation, GLAccount, UseDefaultTypeOfAccounting)
	
	VisibleFlags = New Structure;
	VisibleFlags.Insert("ThisIsSalesReturn", (OperationKind = Enums.OperationTypesCreditNote.SalesReturn));
	VisibleFlags.Insert("IsDiscountAllowed", (OperationKind = Enums.OperationTypesCreditNote.DiscountAllowed));
	VisibleFlags.Insert("SubjectToVAT", (VATTaxation <> Enums.VATTaxationTypes.NotSubjectToVAT));
	
	If UseDefaultTypeOfAccounting Then
		VisibleFlags.Insert("IsExpenseGLA", GLAccountsInDocuments.IsExpenseGLA(GLAccount));
	Else
		VisibleFlags.Insert("IsExpenseGLA", False);
	EndIf;
	
	Return VisibleFlags;
	
EndFunction

// It gets counterparty contract selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormOfContractParameters(DocumentAttributes, DoOperationsByContracts)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(DocumentAttributes.Ref, DocumentAttributes.OperationKind);
	
	FormParameters = New Structure;
	FormParameters.Insert("Counterparty",			DocumentAttributes.Counterparty);
	FormParameters.Insert("Company",				DocumentAttributes.Company);
	FormParameters.Insert("ContractType",			ContractTypesList);
	FormParameters.Insert("CurrentRow",				DocumentAttributes.Contract);
	
	BasisDocument = DocumentAttributes.BasisDocument;
	
	If TypeOf(BasisDocument) = Type("DocumentRef.SalesSlip") And ValueIsFilled(BasisDocument) Then
		
		FormParameters.Insert("ControlContractChoice", True);
		FormParameters.Insert("Currency", DocumentAttributes.DocumentCurrency);
		
	Else
		
		FormParameters.Insert("ControlContractChoice", DoOperationsByContracts);
		
	EndIf;
	
	Return FormParameters;
	
EndFunction

&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company, OperationKind)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company, OperationKind);
	
EndFunction

&AtServer
Function GetDataContractOnChange(Date, Contract)
	
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
	ChangeVisibleCOGSItem();
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServer
Function GetDataDateOnChange(DocumentCurrency, SettlementsCurrency)
	
	CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, DocumentCurrency, Object.Company);
	
	SetAccountingPolicyValues();
	
	ProcessingCompanyVATNumbers();
	
	FillVATRateByCompanyVATTaxation();
	FillSalesTaxRate();
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
	
	If RegisteredForVAT Then
		ParametersStructure.Insert("VATTaxation",				Object.VATTaxation);
		ParametersStructure.Insert("AmountIncludesVAT",			Object.AmountIncludesVAT);
		ParametersStructure.Insert("IncludeVATInPrice",			Object.IncludeVATInPrice);
		ParametersStructure.Insert("AutomaticVATCalculation",	Object.AutomaticVATCalculation);
		ParametersStructure.Insert("PerInvoiceVATRoundingRule",	PerInvoiceVATRoundingRule);
	EndIf;
	
	If RegisteredForSalesTax Then
		ParametersStructure.Insert("SalesTaxRate",			Object.SalesTaxRate);
		ParametersStructure.Insert("SalesTaxPercentage",	Object.SalesTaxPercentage);
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCreditNote.SalesReturn") Then
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
	
	If ContractBeforeChange <> Object.Contract
		And TypeOf(Object.BasisDocument) <> Type("DocumentRef.SalesSlip") Then
		
		ContractData = GetDataContractOnChange(Object.Date, Object.Contract);
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
		Object.ExchangeRate = ?(ContractData.SettlementsCurrencyRateRepetition.Rate = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Rate);
		Object.Multiplicity = ?(ContractData.SettlementsCurrencyRateRepetition.Repetition = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Repetition);
		Object.ContractCurrencyExchangeRate = Object.ExchangeRate;
		Object.ContractCurrencyMultiplicity = Object.Multiplicity;
	EndIf;
	
	OpenFormPricesAndCurrencies = ValueIsFilled(Object.Contract)
		And ValueIsFilled(SettlementCurrency)
		And Object.DocumentCurrency <> SettlementCurrency
		And Object.CreditedTransactions.Count() > 0;
	
	If ValueIsFilled(SettlementCurrency) Then
		Object.DocumentCurrency = SettlementCurrency;
	EndIf;
	
	If OpenFormPricesAndCurrencies
		And Object.OperationKind <> PredefinedValue("Enum.OperationTypesCreditNote.SalesReturn") Then
		
		WarningText = MessagesToUserClientServer.GetSettleCurrencyOnChangeWarningText();
		ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange, False, True, WarningText);
		
	Else
		
		// Generate price and currency label.
		GenerateLabelPricesAndCurrency(ThisObject);
		
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
		
		// VAT
		If RegisteredForVAT Then
			Object.VATTaxation				= StructurePricesAndCurrency.VATTaxation;
			Object.AmountIncludesVAT		= StructurePricesAndCurrency.AmountIncludesVAT;
			Object.IncludeVATInPrice		= StructurePricesAndCurrency.IncludeVATInPrice;
			Object.AutomaticVATCalculation	= StructurePricesAndCurrency.AutomaticVATCalculation;
		EndIf;
		
		// Recalculate prices by currency.
		If Not StructurePricesAndCurrency.RefillPrices
			AND StructurePricesAndCurrency.RecalculatePrices Then
			
			If Object.OperationKind = PredefinedValue("Enum.OperationTypesCreditNote.SalesReturn") Then
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
		
		// VAT
		If RegisteredForVAT Then
			
			// Recalculate the amount if VAT taxation flag is changed.
			If StructurePricesAndCurrency.VATTaxation <> StructurePricesAndCurrency.PrevVATTaxation Then
				FillVATRateByVATTaxation();
			EndIf;
			
		EndIf;
		
		// Sales tax
		If RegisteredForSalesTax Then
			
			Object.SalesTaxRate = StructurePricesAndCurrency.SalesTaxRate;
			Object.SalesTaxPercentage = StructurePricesAndCurrency.SalesTaxPercentage;
			
			If StructurePricesAndCurrency.SalesTaxRate <> StructurePricesAndCurrency.PrevSalesTaxRate
				OR StructurePricesAndCurrency.SalesTaxPercentage <> StructurePricesAndCurrency.PrevSalesTaxPercentage Then
				
				RecalculateSalesTax();
				RecalculateSubtotal();
				
			EndIf;
			
		EndIf;
		
		FormManagement();
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not StructurePricesAndCurrency.RefillPrices
			AND Not StructurePricesAndCurrency.AmountIncludesVAT = StructurePricesAndCurrency.PrevAmountIncludesVAT Then
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory", PricesPrecision);
			Object.AdjustedAmount = Object.Inventory.Total("Total");
			CalculateTotalVATAmount();
		EndIf;
		
		Modified = True;
	EndIf;
	
	// Generate price and currency label.
	GenerateLabelPricesAndCurrency(ThisObject);
	
	WorkWithVATClient.ShowReverseChargeNotSupportedMessage(Object.VATTaxation);
	
EndProcedure

&AtClient
Procedure SetAdjustedAmountTitle(ThisIsSalesReturn)
	
	If Not ThisIsSalesReturn Then
		
		If Object.AmountIncludesVAT Then
			Items.AdjustedAmount.Title = NStr("en = 'Adjustment amount, incl. tax'; ru = 'Сумма корректировки, вкл. налог';pl = 'Wartość korekty brutto';es_ES = 'Importe de corrección, incluyendo impuestos';es_CO = 'Importe de corrección, incluyendo impuestos';tr = 'Düzeltme tutarı, vergi dahil';it = 'Importo della correzione, imposte incluse';de = 'Korrekturbetrag, inkl. Steuer'");
		Else
			Items.AdjustedAmount.Title = NStr("en = 'Adjustment amount, excl. tax'; ru = 'Сумма корректировки, без налога';pl = 'Wartość korekty netto';es_ES = 'Importe de corrección, sin impuestos';es_CO = 'Importe de corrección, sin impuestos';tr = 'Düzeltme tutarı, vergi hariç';it = 'Importo della correzione, imposte escluse';de = 'Korrekturbetrag, exkl. Steuer'");
		EndIf;
		
	Else
		Items.AdjustedAmount.Title = NStr("en = 'Adjusted amount'; ru = 'Сумма корректировки';pl = 'Wartość skorygowana';es_ES = 'Importe modificado';es_CO = 'Importe modificado';tr = 'Düzeltilmiş tutar';it = 'Importo corretto';de = 'Korrigierter Betrag'");
	EndIf;
	
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
		
		Object.CreditedTransactions.Clear();
		
		BeginingDate = SelectedPeriod.StartDate;
		EndingDate	= EndOfDay(SelectedPeriod.EndDate);
		
		FillCreditTransactionsByAllTypes();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCreditTransactionsByAllTypes()
	
	Query = New Query();
	Query.Text = 
	"SELECT ALLOWED
	|	SalesTurnovers.Recorder AS Document,
	|	SalesTurnovers.VATRate AS VATRate,
	|	CASE
	|		WHEN SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover > 0
	|			THEN SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover
	|		ELSE -(SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover)
	|	END AS Amount,
	|	CASE
	|		WHEN SalesTurnovers.VATAmountTurnover > 0
	|			THEN SalesTurnovers.VATAmountTurnover
	|		ELSE -SalesTurnovers.VATAmountTurnover
	|	END AS VATAmount
	|FROM
	|	AccumulationRegister.Sales.Turnovers(&BeginingDate, &EndingDate, Recorder, Company = &Company) AS SalesTurnovers
	|WHERE
	|	(SalesTurnovers.Recorder REFS Document.AccountSalesFromConsignee
	|			OR SalesTurnovers.Recorder REFS Document.CreditNote
	|			OR SalesTurnovers.Recorder REFS Document.SalesInvoice)
	|	AND SalesTurnovers.Recorder.Counterparty = &Counterparty
	|	AND SalesTurnovers.Recorder.Contract = &Contract
	|	AND SalesTurnovers.Recorder <> &Ref
	|
	|ORDER BY
	|	SalesTurnovers.Recorder,
	|	SalesTurnovers.VATRate
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
		NewRow = Object.CreditedTransactions.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

&AtServerNoContext
Function GetCostAmount(StructureData)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	SUM(SalesTurnovers.QuantityTurnover) AS QuantityTurnover,
	|	SUM(SalesTurnovers.CostTurnover) AS CostTurnover
	|INTO Table
	|FROM
	|	AccumulationRegister.Sales.Turnovers(
	|			,
	|			&PointInTime,
	|			Recorder,
	|			Products = &Products
	|				AND Characteristic = &Characteristic
	|				AND Batch = &Batch
	|				AND (Document = &Document
	|					OR Document = &ShiftClosure)) AS SalesTurnovers
	|WHERE
	|	SalesTurnovers.Recorder <> &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	CASE
	|		WHEN Table.QuantityTurnover = 0
	|			THEN 0
	|		ELSE Table.CostTurnover * &ReturnQuantity / Table.QuantityTurnover
	|	END AS CostOfGoodsSold
	|FROM
	|	Table AS Table";
	
	Query.SetParameter("Ref",					StructureData.Ref);
	Query.SetParameter("Products",				StructureData.Products);
	Query.SetParameter("Batch",					StructureData.Batch);
	Query.SetParameter("Characteristic", 		StructureData.Characteristic);
	Query.SetParameter("PointInTime", 			New Boundary(StructureData.Date, BoundaryType.Excluding));
	ReturnQuantity = ?(TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), 
						StructureData.Quantity, StructureData.Quantity * StructureData.MeasurementUnit.Factor); 
	Query.SetParameter("ReturnQuantity",		ReturnQuantity);
	Query.SetParameter("Document", 				?(TypeOf(StructureData.Document) = Type("DocumentRef.RMARequest"),
													Common.ObjectAttributeValue(StructureData.Document, "Invoice"),
													StructureData.Document));
	Query.SetParameter("ShiftClosure", 			?(TypeOf(StructureData.Document) = Type("DocumentRef.SalesSlip"),
													Common.ObjectAttributeValue(StructureData.Document, "CashCRSession"),
													Documents.ShiftClosure.EmptyRef()));
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return 0;
	Else
		Selection = QueryResult.Select();
		Selection.Next();
		Return Selection.CostOfGoodsSold;
	EndIf;
	
EndFunction

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
Function GetTabularSectionName(DocumentType)
	
	
	If DocumentType = "AccountSalesFromConsignee"
		Or DocumentType = "SalesInvoice" Then
		
		TabularSectionName = "Inventory";
		
	ElsIf DocumentType = "CreditNote" Then
		TabularSectionName = "AmountAllocation";
	EndIf;
	
	Return TabularSectionName;
	
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
		If CounterpartyAttributes.DoOperationsByOrders Then
			TabularSectionRow.Order = DocumentData.Order;
		Else
			TabularSectionRow.Order = Undefined;
		EndIf;
		
		If Not ValueIsFilled(TabularSectionRow.Contract) Then
			TabularSectionRow.Contract = DocumentData.Contract;
		EndIf;
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure SetDefaultValuesForIncomeAndExpenseItem(OperationKind, ExpenseItem)
	
	If OperationKind = Enums.OperationTypesCreditNote.DiscountAllowed Then
		ExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("DiscountAllowed");
	ElsIf OperationKind = Enums.OperationTypesCreditNote.Adjustments Then
		ExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("Expenses");
	Else
		ExpenseItem = Catalogs.IncomeAndExpenseItems.EmptyRef();
	EndIf;
	
EndProcedure

// Procedure sets GL account values by default depending on the operation type.
//
&AtServer
Procedure SetDefaultValuesForGLAccount()
	
	If Object.OperationKind = Enums.OperationTypesCreditNote.DiscountAllowed Then 
		Object.GLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("DiscountAllowed");
	ElsIf Object.OperationKind = Enums.OperationTypesCreditNote.Adjustments Then
		Object.GLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("Expenses");
	Else
		Object.GLAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	EndIf;
	
	Object.RegisterExpense = GLAccountsInDocuments.IsExpenseGLA(Object.GLAccount);
	
EndProcedure

&AtServer
Procedure SetAccountingPolicyValues()

	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Object.Date, Object.Company);
	UseGoodsReturnFromCustomer	= AccountingPolicy.UseGoodsReturnFromCustomer;
	UseTaxInvoice				= Not AccountingPolicy.PostVATEntriesBySourceDocuments;
	RegisteredForVAT			= AccountingPolicy.RegisteredForVAT;
	PerInvoiceVATRoundingRule	= AccountingPolicy.PerInvoiceVATRoundingRule;
	RegisteredForSalesTax		= AccountingPolicy.RegisteredForSalesTax;
	
EndProcedure

&AtServer
Procedure SetAutomaticVATCalculation()
	
	Object.AutomaticVATCalculation = PerInvoiceVATRoundingRule;
	
EndProcedure

&AtServer
Procedure SetChoiceParameterLinks()
	
	NewArray = New Array();
	NewConnection = New ChoiceParameterLink("Filter.Company", "Object.Company");
	NewArray.Add(NewConnection);
	
	If TypeOf(Object.BasisDocument) <> Type("DocumentRef.SalesSlip") Then
		
		NewConnection = New ChoiceParameterLink("Filter.Counterparty", "Object.Counterparty");
		NewArray.Add(NewConnection);
		
		If TypeOf(Object.BasisDocument) <> Type("DocumentRef.CashReceipt")
			AND TypeOf(Object.BasisDocument) <> Type("DocumentRef.PaymentReceipt") Then
			
			NewConnection = New ChoiceParameterLink("Filter.Contract", "Object.Contract");
			NewArray.Add(NewConnection);
			
		EndIf;
		
	EndIf;
	
	NewConnections = New FixedArray(NewArray);
	Items.BasisDocument.ChoiceParameterLinks = NewConnections;
	
EndProcedure

&AtServer
Procedure ChangeVisibleCOGSItem()
	
	InventoryValuationMethod = InformationRegisters.AccountingPolicy.InventoryValuationMethod(Object.Date, Object.Company);
	If InventoryValuationMethod = Enums.InventoryValuationMethods.FIFO Then
		Items.InventoryCostOfGoodsSold.Visible = False;
	Else
		Items.InventoryCostOfGoodsSold.Visible = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetFormConditionalAppearance()
	
	// InventoryCostOfGoodsSold
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.Inventory.ProductsType",
		Enums.ProductsTypes.InventoryItem,
		DataCompositionComparisonType.NotEqual);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "InventoryCostOfGoodsSold");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// InventorySerialNumbers
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"UseGoodsReturnFromCustomer",
		True,
		DataCompositionComparisonType.Equal);
	
	Text = StringFunctionsClientServer.SubstituteParametersToString("<%1>", NStr("en = 'Specifiy in Goods receipt'; ru = 'Укажите в поступлении товаров';pl = 'Określ w Przyjęciu zewnętrznym';es_ES = 'Especificar en el recibo de Mercancías';es_CO = 'Especificar en el recibo de Mercancías';tr = 'Ambar girişinde belirtin';it = 'Specifica nella ricezione merce';de = 'Im Wareneingang angeben'"));
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "InventorySerialNumbers");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Enabled", False);
	
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance);
	IncomeAndExpenseItemsInDocuments.SetConditionalAppearance(ThisObject, "Inventory");
	
	// Drop shipping
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.Inventory.ProductsType");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.NotEqual;
	DataFilterItem.RightValue		= Enums.ProductsTypes.InventoryItem;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Enabled", False);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("InventoryDropShipping");
	FieldAppearance.Use = True;
	
EndProcedure

&AtClientAtServerNoContext
Procedure GenerateLabelPricesAndCurrency(Form)
	
	Object = Form.Object;
	
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",		Form.SettlementCurrency);
	LabelStructure.Insert("Rate",						Object.ExchangeRate);
	LabelStructure.Insert("RateNationalCurrency",		Form.ExchangeRateNationalCurrency);
	LabelStructure.Insert("AmountIncludesVAT",			Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	Form.ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation",				Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",			Form.RegisteredForVAT);
	LabelStructure.Insert("RegisteredForSalesTax",		Form.RegisteredForSalesTax);
	LabelStructure.Insert("SalesTaxRate",				Object.SalesTaxRate);
	
	Form.PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val CatalogCounterparty)
	
	Attributes = "DoOperationsByContracts, DoOperationsByOrders, VATTaxation";
	
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
	
	If UseDefaultTypeOfAccounting Then
		
		TabularSectionRow = Items.AmountAllocation.CurrentData;
		StructureData = GetStructureDataForGLAccounts(ThisObject, "AmountAllocation", StructureData, TabularSectionRow);
		
		If ValueIsFilled(TabularSectionRow.Contract) Then
			StructureData = GetDataAmountAllocationContractOnChange(StructureData);
			FillPropertyValues(TabularSectionRow, StructureData);
		Else
			TabularSectionRow.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
		EndIf;
		
	EndIf;
	
EndProcedure

#Region Bundles

&AtClient
Procedure InventoryBeforeDeleteRowEnd(Result, BundleData) Export
	
	If Result = Undefined Or Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	BundleRows = Object.Inventory.FindRows(BundleData);
	If BundleRows.Count() = 0 Then
		Return;
	EndIf;
	
	BundleRow = BundleRows[0];
	
	If Result = DialogReturnCode.Yes Then
		
		BundlesClient.DeleteBundleRows(BundleRow.BundleProduct,
			BundleRow.BundleCharacteristic,
			Object.Inventory,
			Object.AddedBundles);
			
		Modified = True;
		RecalculateSalesTax();
		RecalculateSubtotal();
		CalculateTotalVATAmount();
		SetBundlePictureVisible();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure BundlesOnCreateAtServer()
	
	UseBundles = GetFunctionalOption("UseProductBundles");
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshBundlePictures(Inventory)
	
	For Each InventoryLine In Inventory Do
		InventoryLine.BundlePicture = ValueIsFilled(InventoryLine.BundleProduct);
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure RefreshBundleAttributes(Inventory)
	
	If Not GetFunctionalOption("UseProductBundles") Then
		Return;
	EndIf;
	
	ProductsArray = New Array;
	For Each InventoryLine In Inventory Do
		
		If ValueIsFilled(InventoryLine.Products) And Not ValueIsFilled(InventoryLine.BundleProduct) Then
			ProductsArray.Add(InventoryLine.Products);
		EndIf;
		
	EndDo;
	
	If ProductsArray.Count() > 0 Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	Products.Ref AS Ref
		|FROM
		|	Catalog.Products AS Products
		|WHERE
		|	Products.Ref IN(&ProductsArray)
		|	AND Products.IsBundle";
		
		Query.SetParameter("ProductsArray", ProductsArray);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		ProductsMap = New Map;
		
		While SelectionDetailRecords.Next() Do
			ProductsMap.Insert(SelectionDetailRecords.Ref, True);
		EndDo;
		
		For Each InventoryLine In Inventory Do
			
			If Not ValueIsFilled(InventoryLine.Products) Or ValueIsFilled(InventoryLine.BundleProduct) Then
				InventoryLine.IsBundle = False;
			Else
				InventoryLine.IsBundle = ProductsMap.Get(InventoryLine.Products);
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetBundlePictureVisible()
	
	BundlePictureVisible = False;
	
	For Each Row In Object.Inventory Do
		
		If Row.BundlePicture Then
			BundlePictureVisible = True;
			Break;
		EndIf;
		
	EndDo;
	
	If Items.InventoryBundlePicture.Visible <> BundlePictureVisible Then
		Items.InventoryBundlePicture.Visible = BundlePictureVisible;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetBundleConditionalAppearance()
	
	If UseBundles Then
		
		NewConditionalAppearance = ConditionalAppearance.Items.Add();
		WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
			"Object.Inventory.BundleProduct",
			Catalogs.Products.EmptyRef(),
			DataCompositionComparisonType.NotEqual);
			
		WorkWithForm.AddAppearanceField(NewConditionalAppearance, "InventoryProducts, InventoryCharacteristic, InventoryContent, InventoryQuantity, InventoryMeasurementUnit");
		WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
		WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.UnavailableTabularSectionTextColor);
				
	EndIf;
	
EndProcedure

#EndRegion

#Region SalesTax

&AtServerNoContext
Function GetSalesTaxPercentage(SalesTaxRate)
	
	Return Common.ObjectAttributeValue(SalesTaxRate, "Rate");
	
EndFunction

&AtClient
Procedure CalculateSalesTaxAmount(TableRow)
	
	AmountTaxable = GetTotalTaxable();
	
	TableRow.Amount = Round(AmountTaxable * TableRow.SalesTaxPercentage / 100, 2, RoundMode.Round15as20);
	
EndProcedure

&AtServer
Function GetTotalTaxable()
	
	InventoryTaxable = Object.Inventory.Unload(New Structure("Taxable", True));
	
	Return InventoryTaxable.Total("Total");
	
EndFunction

&AtServer
Procedure FillSalesTaxRate()
	
	If Object.OperationKind = Enums.OperationTypesCreditNote.SalesReturn Then
		
		SalesTaxRateBeforeChange = Object.SalesTaxRate;
		
		Object.SalesTaxRate = DriveServer.CounterpartySalesTaxRate(Object.Counterparty, RegisteredForSalesTax);
		
		If SalesTaxRateBeforeChange <> Object.SalesTaxRate Then
			
			If ValueIsFilled(Object.SalesTaxRate) Then
				Object.SalesTaxPercentage = Common.ObjectAttributeValue(Object.SalesTaxRate, "Rate");
			Else
				Object.SalesTaxPercentage = 0;
			EndIf;
			
			RecalculateSalesTax();
			
		EndIf;
		
	Else
		
		Object.SalesTaxRate = Catalogs.SalesTaxRates.EmptyRef();
		Object.SalesTaxPercentage = 0;
		Object.SalesTax.Clear();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RecalculateSalesTax()
	
	FormObject = FormAttributeToValue("Object");
	FormObject.RecalculateSalesTax();
	ValueToFormAttribute(FormObject, "Object");
	
EndProcedure

#EndRegion

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
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCreditNote.SalesReturn")
		And Object.Inventory.FindRows(New Structure("DropShipping", True)).Count() > 0 Then
		
		Params = New Structure;
		Params.Insert("Company", Object.Company);
		Params.Insert("Date", Object.Date);
		DriveServer.DropShippingReturnIsSupported(Params);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion