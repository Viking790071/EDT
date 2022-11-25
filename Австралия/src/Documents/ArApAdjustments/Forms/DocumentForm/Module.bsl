
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillAccountsReceivable", True);
	ParametersStructure.Insert("FillAccountsPayable", True);
	ParametersStructure.Insert("FillHeader", False);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If GLAccountsInDocumentsClient.IsGLAccountsChoiceProcessing(ChoiceSource.FormName) Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
	EndIf;

EndProcedure

// Procedure - OnCreateAtServer event handler.
// The procedure implements
// - form attribute initialization,
// - setting of the form functional options parameters.
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
	
	OperationKind = Object.OperationKind;
	
	Counterparty = Object.CounterpartySource;
	CounterpartyRecipient = Object.Counterparty;
	
	ReadCounterpartyAttributes(CounterpartySourceAttributes, Object.CounterpartySource);
	ReadCounterpartyAttributes(CounterpartyRecipientAttributes, Object.Counterparty);
	
	Company = DriveServer.GetCompany(Object.Company);
	
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Object.Date, DriveServer.GetPresentationCurrency(Company), Company);
	ExchangeRate = ?(StructureByCurrency.Rate = 0, 1, StructureByCurrency.Rate);
	Multiplicity = ?(StructureByCurrency.Rate = 0, 1, StructureByCurrency.Repetition);
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	DefaultExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("OtherExpenses");
	DefaultIncomeItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("OtherIncome");
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillAccountsReceivable", True);
	ParametersStructure.Insert("FillAccountsPayable", True);
	ParametersStructure.Insert("FillHeader", True);
	
	FillAddedColumns(ParametersStructure);
	
	SetChoiceParameterLinks();
	SetVisibleAndEnabled();
	SetConditionalAppearance();
	
	CheckingFillingNotExecuted = True;
	
	DebitorDocumentType = Metadata.Documents.ArApAdjustments.TabularSections.Debitor.Attributes.Document.Type;
	CreditorDocumentType = Metadata.Documents.ArApAdjustments.TabularSections.Creditor.Attributes.Document.Type;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	DriveServer.CheckObjectGeneratedEnteringBalances(ThisObject);
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillAccountsReceivable", True);
	ParametersStructure.Insert("FillAccountsPayable", True);
	ParametersStructure.Insert("FillHeader", True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	SetAvailableTypes();
	
EndProcedure

// Procedure - event handler of the form BeforeWrite
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If CheckingFillingNotExecuted Then
		
		If (Object.Ref.IsEmpty() OR Modified) Then
			
			ErrorText = "";
			CheckCorrectnessOfDetailsOfDocumentFill(ErrorText);
			If Not IsBlankString(ErrorText) Then
				
				Cancel = True;
				RefuseFromDocumentRecord = True;
				FormClosingWithErrorsDescriptionNotification = New NotifyDescription("DetermineNeedForClosingFormWithErrors", ThisObject);
				ShowQueryBox(FormClosingWithErrorsDescriptionNotification, ErrorText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes,);
				
			EndIf;
			
		EndIf;
		
	Else 
		
		CheckingFillingNotExecuted = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		If OperationKind = Enums.OperationTypesArApAdjustments.CustomerAdvanceClearing Then
			
			MessageText = NStr("en = 'Cannot post this document, Counterparties GL accounts are required for the selected customer.
				|Open the customer card, click More actions > Counterparties GL accounts, and specify the accounts.'; 
				|ru = 'Не удается провести этот документ. Для выбранного покупателя требуются счета учету контрагентов.
				|Откройте карточку покупателя, выберите Дополнительные действия > Счета учета контрагентов и укажите счета.';
				|pl = 'Nie można zatwierdzić tego dokumentu, są wymagane konta księgowe kontrahentów dla wybranego nabywcy.
				|Otwórz kartę nabywcy, kliknij Więcej > Konta księgowe kontrahentów, i wybierz konta.';
				|es_ES = 'No se puede enviar este documento, se requieren Cuentas del libro mayor de las Contrapartes para el cliente seleccionado.
				|Abre la tarjeta del cliente, haz clic en Más acciones > Cuentas del libro mayor de las Contrapartes y especifica las cuentas.';
				|es_CO = 'No se puede enviar este documento, se requieren Cuentas del libro mayor de las Contrapartes para el cliente seleccionado.
				|Abre la tarjeta del cliente, haz clic en Más acciones > Cuentas del libro mayor de las Contrapartes y especifica las cuentas.';
				|tr = 'Bu belge kaydedilemiyor. Müşteri için Cari hesap muhasebe hesapları gerekli.
				|Müşteri kartını açıp, Daha fazla > Cari hesap muhasebe hesaplarına tıklayın ve hesapları seçin.';
				|it = 'Impossibile pubblicare questo documento, sono richiesti i Conti Mastro Controparti per il cliente selezionato.
				|Aprire la scheda cliente, cliccare su Più azioni > Conti Mastro Controparti, e specificare conti.';
				|de = 'Dieses Dokument kann nicht gebucht werden, die Hauptbuch-Konten der Geschäftspartner sind für den ausgewählten Kunden erforderlich.
				|Öffnen Sie die Kundenkarte, klicken auf Mehr Aktionen> Hauptbuch-Konten der Geschäftspartner, und geben die Konten ein.'");
			
		ElsIf OperationKind = Enums.OperationTypesArApAdjustments.SupplierAdvanceClearing Then
			
			MessageText = NStr("en = 'Cannot post this document, Counterparties GL accounts are required for the selected supplier.
				|Open the supplier card, click More actions > Counterparties GL accounts, and specify the accounts.'; 
				|ru = 'Не удается провести этот документ. Для выбранного поставщика требуются счета учету контрагентов.
				|Откройте карточку поставщика, выберите Дополнительные действия > Счета учета контрагентов и укажите счета.';
				|pl = 'Nie można zatwierdzić tego dokumentu, są wymagane konta księgowe kontrahentów dla wybranego dostawcy.
				|Otwórz kartę dostawcy, kliknij Więcej > Konta księgowe kontrahentów, i wybierz konta.';
				|es_ES = 'No se puede enviar este documento, se requieren Cuentas del libro mayor de las Contrapartes para el proveedor seleccionado.
				|Abre la tarjeta del proveedor, haz clic en Más acciones > Cuentas del libro mayor de las Contrapartes y especifica las cuentas.';
				|es_CO = 'No se puede enviar este documento, se requieren Cuentas del libro mayor de las Contrapartes para el proveedor seleccionado.
				|Abre la tarjeta del proveedor, haz clic en Más acciones > Cuentas del libro mayor de las Contrapartes y especifica las cuentas.';
				|tr = 'Bu belge kaydedilemiyor. Tedarikçi için Cari hesap muhasebe hesapları gerekli.
				|Tedarikçi kartını açıp, Daha fazla > Cari hesap muhasebe hesaplarına tıklayın ve hesapları seçin.';
				|it = 'Impossibile pubblicare questo documento, sono richiesti i Conti Mastro Controparti per il fornitore selezionato.
				|Aprire la scheda fornitore, cliccare su Più azioni > Conti Mastro Controparti, e specificare conti.';
				|de = 'Dieses Dokument kann nicht gebucht werden, die Hauptbuch-Konten der Geschäftspartner sind für den ausgewählten Lieferanten erforderlich.
				|Öffnen Sie die Lieferantenkarte, klicken auf Mehr Aktionen> Hauptbuch-Konten der Geschäftspartner, und geben die Konten ein.'");
			
		Else
			Return;
		EndIf;
		
		If UseDefaultTypeOfAccounting And Not CounterpartyGLAAccountsAreFilled() Then
			CommonClientServer.MessageToUser(MessageText,,,, Cancel);
		EndIf;
		
		CheckingAdvancesAndDebts(Cancel);
		
	EndIf;
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	// Notification of payment.
	NotifyAboutOrderPayment = False;
	
	For Each CurRow In Object.Debitor Do
			NotifyAboutOrderPayment = ?(
			NotifyAboutOrderPayment,
			NotifyAboutOrderPayment,
			ValueIsFilled(CurRow.Order)
		);
	EndDo;
	
	For Each CurRow In Object.Creditor Do
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

// Procedure - event handler NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AfterRecordingOfCounterparty" Then
		If ValueIsFilled(Parameter) Then
			If Parameter = Object.Counterparty
			 OR Parameter = Object.CounterpartySource Then
			 
				If Parameter = Object.CounterpartySource Then
					ReadCounterpartyAttributes(CounterpartySourceAttributes, Object.CounterpartySource);
				EndIf;
				
				If Parameter = Object.Counterparty Then
					ReadCounterpartyAttributes(CounterpartyRecipientAttributes, Object.Counterparty);
				EndIf;
				
				SetVisibleAndEnabled();
				Return;
				
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

// Procedure - event handler OnChange of the OperationKind input field.
// Manages pages while changing document operation kind.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	TypeOfOperationsBeforeChange = OperationKind;
	OperationKind = Object.OperationKind;
	If OperationKind <> TypeOfOperationsBeforeChange Then
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.ArApAdjustments") Then
			Object.Contract = Undefined;
			Object.AccountsDocument = Undefined;
			Object.AdvanceFlag = False;
			Object.SettlementsAmount = 0;
			Object.ExchangeRate = 0;
			Object.Multiplicity = 0;
			Object.AccountingAmount = 0;
			For Each String In Object.Creditor Do
				String.Contract = Undefined;
				String.Document = Undefined;
				String.Order = Undefined;
			EndDo;
			SetChoiceParameterLinks();
		ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.CustomerDebtAssignment") Then
			Object.Creditor.Clear();
		ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor") Then
			Object.Debitor.Clear();
			For Each String In Object.Creditor Do
				String.Contract = Undefined;
				String.Document = Undefined;
				String.Order = Undefined;
			EndDo;
			SetChoiceParameterLinks();
		ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.CustomerDebtAdjustment") Then
			Object.Creditor.Clear();
			Object.Counterparty = Undefined;
			Object.AccountsDocument = Undefined;
			Object.AdvanceFlag = False;
			Object.SettlementsAmount = 0;
			Object.ExchangeRate = 0;
			Object.Multiplicity = 0;
			Object.AccountingAmount = 0;
		ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.VendorDebtAdjustment") Then
			Object.Debitor.Clear();
			Object.CounterpartySource = Undefined;
			Object.AccountsDocument = Undefined;
			Object.AdvanceFlag = False;
			Object.SettlementsAmount = 0;
			Object.ExchangeRate = 0;
			Object.Multiplicity = 0;
			Object.AccountingAmount = 0;
		ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.CustomerAdvanceClearing")
			Or Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.SupplierAdvanceClearing") Then
			Object.Creditor.Clear();
			Object.Debitor.Clear();
			Object.Counterparty = Undefined;
			Object.CounterpartySource = Undefined;
			Object.Contract = Undefined;
			Object.AccountsDocument = Undefined;
			Object.AdvanceFlag = False;
			Object.SettlementsAmount = 0;
			Object.ExchangeRate = 0;
			Object.Multiplicity = 0;
			Object.AccountingAmount = 0;
			SetChoiceParameterLinks();
		EndIf;
		
		ReadCounterpartyAttributes(CounterpartySourceAttributes, Object.CounterpartySource);
		ReadCounterpartyAttributes(CounterpartyRecipientAttributes, Object.Counterparty);
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", False);
		ParametersStructure.Insert("FillAccountsReceivable", True);
		ParametersStructure.Insert("FillAccountsPayable", True);
		ParametersStructure.Insert("FillHeader", True);
		FillAddedColumns(ParametersStructure);
		
		SetVisibleAndEnabled();
		SetAvailableTypes();
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Counterparty input field.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.CustomerAdvanceClearing")
		Or Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.SupplierAdvanceClearing") Then
		
		Object.Counterparty = Object.CounterpartySource;
	EndIf;
	
	If Counterparty <> Object.CounterpartySource Then
		
		ReadCounterpartyAttributes(CounterpartySourceAttributes, Object.CounterpartySource);
		
		For Each String In Object.Debitor Do
			String.Contract = Undefined;
			String.Document = Undefined;
			String.Order = Undefined;
		EndDo;
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor") Then
			For Each String In Object.Creditor Do
				String.Contract = Undefined;
				String.Document = Undefined;
				String.Order = Undefined;
			EndDo;
		EndIf;
		
	EndIf;
	Counterparty = Object.CounterpartySource;
	
	SetVisibleAndEnabled();
	
EndProcedure

// Procedure - handler of the OnChange event of the CounterpartyRecipient input field.
//
&AtClient
Procedure CounterpartyRecipientOnChange(Item)
	
	If CounterpartyRecipient <> Object.Counterparty Then
		
		ReadCounterpartyAttributes(CounterpartyRecipientAttributes, Object.Counterparty);
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.ArApAdjustments") Then
			For Each String In Object.Creditor Do
				String.Contract = Undefined;
				String.Document = Undefined;
				String.Order = Undefined;
			EndDo;
		EndIf;
		Object.Contract = Undefined;
		
	EndIf;
	CounterpartyRecipient = Object.Counterparty;
	
	SetVisibleAndEnabled();
	
EndProcedure

// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
EndProcedure

// Procedure - event handler OnChange of the Company input field.
// The procedure is used to
// clear the document number and set the parameters of the form functional options.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	CompanyBeforeChange = Company;
	Company = StructureData.Company;
	
	If CompanyBeforeChange <> Object.Company Then
		
		ClearDebitorAndCreditorTabularSection();
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Contract input field.
//
&AtClient
Procedure ContractOnChange(Item)
	
	StructureData = CreateGeneralAttributeValuesStructure(ThisObject, "Header", Object);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(StructureData, ThisObject, "Header", Object);
	EndIf;
		
	FillDataContractOnChange(StructureData);
	FillPropertyValues(Object, StructureData);
		
	If UseDefaultTypeOfAccounting Then
		GLAccounts = StructureData.GLAccounts;
	EndIf;
	
	If ValueIsFilled(Object.Contract) Then 
		Object.ExchangeRate = ?(StructureData.CurrencyRateRepetition.Rate = 0, 1, StructureData.CurrencyRateRepetition.Rate);
		Object.Multiplicity = ?(StructureData.CurrencyRateRepetition.Repetition = 0, 1, StructureData.CurrencyRateRepetition.Repetition);
	EndIf;
	
	CalculateAccountingAmount(Object);
	
EndProcedure

// Procedure - event handler StartChoice of the Contract input field.
//
&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormParameters(
		Object.Ref, 
		Object.Company, 
		Object.Counterparty, 
		Object.Contract, 
		Object.OperationKind, 
		CounterpartyRecipientAttributes.DoOperationsByContracts);
		
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - handler of the OnChange event of the SettlementsAmount input field.
//
&AtClient
Procedure SettlementsAmountOnChange(Item)
	
	CalculateAccountingAmount(Object);
	
EndProcedure

// Procedure - handler of the OnChange event of the Rate input field.
//
&AtClient
Procedure RateOnChange(Item)
	
	CalculateAccountingAmount(Object);
	
EndProcedure

// Procedure - handler of the OnChange event of the Multiplicity input field.
//
&AtClient
Procedure RepetitionOnChange(Item)
	
	CalculateAccountingAmount(Object);
	
EndProcedure

// Procedure - handler of the OnChange event of the AccountingAmount input field.
//
&AtClient
Procedure AccountingAmountOnChange(Item)
	
	CalculateSettlementsAmount(Object);
	
EndProcedure

&AtClient
Procedure GLAccountsClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	GLAccountsInDocumentsClient.OpenCounterpartyGLAccountsForm(ThisObject, Object, "Header");
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
Procedure CorrespondenceOnChange(Item)
	CorrespondenceOnChangeServer();
EndProcedure

&AtClient
Procedure RegisterExpenseOnChange(Item)
	
	If Object.RegisterExpense Then
		Object.RegisterIncome = False;
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillAccountsReceivable", True);
	ParametersStructure.Insert("FillAccountsPayable", True);
	ParametersStructure.Insert("FillHeader", False);
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtClient
Procedure RegisterIncomeOnChange(Item)
	
	If Object.RegisterIncome Then
		Object.RegisterExpense = False;
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillAccountsReceivable", True);
	ParametersStructure.Insert("FillAccountsPayable", True);
	ParametersStructure.Insert("FillHeader", False);
	FillAddedColumns(ParametersStructure);
	
EndProcedure

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-result handler of the closing form with errors question
//
Procedure DetermineNeedForClosingFormWithErrors(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		CheckingFillingNotExecuted = False;
		Write();
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region FormTableItemsEventHandlers

#Region AttributeEventHandlersCWT

&AtClient
Procedure DebitorSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If UseDefaultTypeOfAccounting Then 
		GLAccountsInDocumentsClient.TableSelection(ThisObject, "Debitor", SelectedRow, Field, StandardProcessing);
	EndIf;
	
	If Field.Name = "DebitorIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Debitor");
	EndIf;
	
EndProcedure

&AtClient
Procedure DebitorOnActivateCell(Item)
	
	If UseDefaultTypeOfAccounting Then 
		GLAccountsInDocumentsClient.TableOnActivateCell(ThisObject, "Debitor", ThisIsNewRow);
	EndIf;
	
	CurrentData = Items.Debitor.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Debitor.CurrentItem;
		If TableCurrentColumn.Name = "DebitorIncomeAndExpenseItems"
			And Not Items.Debitor.IncomeAndExpenseItemsFilled Then
			SelectedRow = Items.Debitor.CurrentRow;
			IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Debitor");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure DebitorOnStartEdit(Item, NewRow, Clone)
	
	If UseDefaultTypeOfAccounting Then 
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	
	If NewRow And Not Clone Then
		
		If OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.CustomerDebtAdjustment")
			Or OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.VendorDebtAdjustment") Then
			
			Item.CurrentData.ExpenseItem = DefaultExpenseItem;
			Item.CurrentData.IncomeItem = DefaultIncomeItem;
			
		EndIf;
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", False);
		ParametersStructure.Insert("FillAccountsReceivable", True);
		ParametersStructure.Insert("FillAccountsPayable", True);
		ParametersStructure.Insert("FillHeader", False);
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DebitorOnEditEnd(Item, NewRow, CancelEdit)
	
	If UseDefaultTypeOfAccounting Then 
		GLAccountsInDocumentsClient.TableOnEditEnd(ThisIsNewRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure DebitorGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	GLAccountsInDocumentsClient.GLAccountsStartChoice(ThisObject, "Debitor", StandardProcessing);  
	
EndProcedure

// Procedure - Handler of the OnChange event of
// the Contract input field of the Debitor tabular section.
//
&AtClient
Procedure DebitorContractOnChange(Item)
	
	TabularSectionRow = Items.Debitor.CurrentData;
	
	StructureData = CreateGeneralAttributeValuesStructure(ThisObject, "Debitor", TabularSectionRow);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(StructureData, ThisObject, "Debitor", TabularSectionRow);
	EndIf;
	
	FillDataContractOnChange(StructureData);
	FillPropertyValues(TabularSectionRow, StructureData);
	
	If ValueIsFilled(TabularSectionRow.Contract) Then 
		TabularSectionRow.ExchangeRate = ?(StructureData.CurrencyRateRepetition.Rate = 0, 1, StructureData.CurrencyRateRepetition.Rate);
		TabularSectionRow.Multiplicity = ?(StructureData.CurrencyRateRepetition.Repetition = 0, 1, StructureData.CurrencyRateRepetition.Repetition);
	EndIf;
	
	CalculateAccountingAmount(TabularSectionRow);
	
EndProcedure

// Procedure - handler of SelectionBeginning of the Contract
// input field of the Debitor tabular section.
//
&AtClient
Procedure DebitorContractBeginChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Return;
	EndIf;
	
	CurrentData = Items.Debitor.CurrentData;
	
	FormParameters = GetChoiceFormParameters(
		Object.Ref, 
		Object.Company,
		Object.CounterpartySource,
		CurrentData.Contract,
		Object.OperationKind,
		CounterpartySourceAttributes.DoOperationsByContracts,
		"Debitor");
		
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - handler of the OnChange event 
//  of the Rate input field of the Debitor tabular section.
//
&AtClient
Procedure DebitorExchangeRateOnChange(Item)
	
	TabularSectionRow = Items.Debitor.CurrentData;
	
	CalculateAccountingAmount(TabularSectionRow);
	
EndProcedure

// Procedure - handler of the OnChange event of
// the Multiplicity input field of the Debitor tabular section.
//
&AtClient
Procedure DebitorMultiplicityOnChange(Item)
	
	TabularSectionRow = Items.Debitor.CurrentData;
	
	CalculateAccountingAmount(TabularSectionRow);
	
EndProcedure

&AtClient
// Procedure - handler of OnChange event of
// the AccountingAmount input field of the Debitor tabular section.
//
Procedure DebitorAccountsAmountOnChange(Item)
	
	TabularSectionRow = Items.Debitor.CurrentData;
	
	CalculateAccountingAmount(TabularSectionRow);
	
EndProcedure

// Procedure - handler of the OnChange event of
// the AccountingAmount input field of the Debitor tabular section.
//
&AtClient
Procedure DebitorAccountingAmountOnChange(Item)
	
	TabularSectionRow = Items.Debitor.CurrentData;
	
	CalculateSettlementsAmount(TabularSectionRow);
	
EndProcedure

// Procedure - handler of the OnChange event of
// the DebitorDocument input field of the Debitor tabular section.
//
&AtClient
Procedure DebitorDocumentOnChange(Item)
	
	TabularSectionRow = Items.Debitor.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
		Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt")
		Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CreditNote")
		Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.DebitNote")
		Or ((TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashVoucher"))
			And Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.SupplierAdvanceClearing")) Then
		TabularSectionRow.AdvanceFlag = True;
	Else
		TabularSectionRow.AdvanceFlag = False;
	EndIf;
	
	StructureData = CreateGeneralAttributeValuesStructure(ThisObject, "Debitor", TabularSectionRow);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(StructureData, ThisObject, "Debitor", TabularSectionRow);
	EndIf;
	
	DocumentOnChangeAtServer(StructureData);
	FillPropertyValues(TabularSectionRow, StructureData);
	
EndProcedure

&AtClient
Procedure DebitorOrderStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	TabularSectionRow = Items.Debitor.CurrentData;
	StructureFilter = New Structure();
	StructureFilter.Insert("Company", Object.Company);
	StructureFilter.Insert("Counterparty", Object.CounterpartySource);
	StructureFilter.Insert("Contract", TabularSectionRow.Contract);
	StructureFilter.Insert("IncludeTransferOrders", False);
	
	ParameterStructure = New Structure("Filter", StructureFilter);
	
	OpenForm("CommonForm.SelectDocumentOrder", ParameterStructure, Item);
	
EndProcedure

&AtClient
Procedure DebitorOrderChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	
	TabularSectionRow = Items.Debitor.CurrentData;
	
	If TypeOf(SelectedValue) = Type("Structure") Then
		TabularSectionRow.Order = SelectedValue.Document;
		Modified = True;
	EndIf;

EndProcedure

&AtClient
Procedure DebitorIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "Debitor", StandardProcessing);
	
EndProcedure

&AtClient
Procedure CreditorSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If UseDefaultTypeOfAccounting Then 
		GLAccountsInDocumentsClient.TableSelection(ThisObject, "Creditor", SelectedRow, Field, StandardProcessing);
	EndIf;
	
	If Field.Name = "CreditorIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Creditor");
	EndIf;
	
EndProcedure

&AtClient
Procedure CreditorOnActivateCell(Item)
	
	If UseDefaultTypeOfAccounting Then 
		GLAccountsInDocumentsClient.TableOnActivateCell(ThisObject, "Creditor", ThisIsNewRow);
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Creditor.CurrentItem;
		If TableCurrentColumn.Name = "CreditorIncomeAndExpenseItems"
			And Not Items.Creditor.IncomeAndExpenseItemsFilled Then
			SelectedRow = Items.Creditor.CurrentRow;
			IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Creditor");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure CreditorOnStartEdit(Item, NewRow, Clone)
	
	If UseDefaultTypeOfAccounting Then 
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	
	If NewRow And Not Clone Then
		
		If OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.CustomerDebtAdjustment")
			Or OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.VendorDebtAdjustment") Then
			
			Item.CurrentData.ExpenseItem = DefaultExpenseItem;
			Item.CurrentData.IncomeItem = DefaultIncomeItem;
			
		EndIf;
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", False);
		ParametersStructure.Insert("FillAccountsReceivable", True);
		ParametersStructure.Insert("FillAccountsPayable", True);
		ParametersStructure.Insert("FillHeader", False);
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CreditorOnEditEnd(Item, NewRow, CancelEdit)
	
	If UseDefaultTypeOfAccounting Then 
		GLAccountsInDocumentsClient.TableOnEditEnd(ThisIsNewRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure CreditorGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	GLAccountsInDocumentsClient.GLAccountsStartChoice(ThisObject, "Creditor", StandardProcessing);  
	
EndProcedure

// Procedure - handler of the OnChange event of
// the Contract input field of the Creditor tabular section.
//
&AtClient
Procedure CreditorContractOnChange(Item)
	
	TabularSectionRow = Items.Creditor.CurrentData;
	
	StructureData = CreateGeneralAttributeValuesStructure(ThisObject, "Creditor", TabularSectionRow);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(StructureData, ThisObject, "Creditor", TabularSectionRow);
	EndIf;
	
	FillDataContractOnChange(StructureData);
	FillPropertyValues(TabularSectionRow, StructureData);
	
	If ValueIsFilled(TabularSectionRow.Contract) Then 
		TabularSectionRow.ExchangeRate = ?(StructureData.CurrencyRateRepetition.Rate = 0, 1, StructureData.CurrencyRateRepetition.Rate);
		TabularSectionRow.Multiplicity = ?(StructureData.CurrencyRateRepetition.Repetition = 0, 1, StructureData.CurrencyRateRepetition.Repetition);
	EndIf;
	
	CalculateAccountingAmount(TabularSectionRow);
	
EndProcedure

// Procedure - handler of the ChoiceBeggining of the
// Contract input field of the Creditor tabular section.
//
&AtClient
Procedure CreditorContractBeginChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Return;
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor") Then
		
		CounterpartyCreditor	= Object.CounterpartySource;
		IsOperationsByContracts	= CounterpartySourceAttributes.DoOperationsByContracts;
		
	Else
		
		CounterpartyCreditor	= Object.Counterparty;
		IsOperationsByContracts	= CounterpartyRecipientAttributes.DoOperationsByContracts;
		
	EndIf;
	
	CurrentData = Items.Creditor.CurrentData;
	
	FormParameters = GetChoiceFormParameters(
		Object.Ref, 
		Object.Company,
		CounterpartyCreditor,
		CurrentData.Contract,
		Object.OperationKind,
		IsOperationsByContracts,
		"Creditor");
		
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - handler of the OnChange event of
// the Rate input field of the Creditor tabular section.
//
&AtClient
Procedure CreditorExchangeRateOnChange(Item)
	
	TabularSectionRow = Items.Creditor.CurrentData;
	
	CalculateAccountingAmount(TabularSectionRow);
	
EndProcedure

// Procedure - handler of the OnChange event of
// the Multiplicity input field of the Debitor tabular section.
//
&AtClient
Procedure CreditorMultiplicityOnChange(Item)
	
	TabularSectionRow = Items.Creditor.CurrentData;
	
	CalculateAccountingAmount(TabularSectionRow);
	
EndProcedure

// Procedure - handler of the OnChange event
// of the SettlementsAmount input field of the Creditor tabular section.
//
&AtClient
Procedure CreditorSettlementsAmountOnChange(Item)
	
	TabularSectionRow = Items.Creditor.CurrentData;
	
	CalculateAccountingAmount(TabularSectionRow);
	
EndProcedure

// Procedure - handler of the OnChange event of
// the AccountingAmount input field of the Creditor tabular section.
//
&AtClient
Procedure CreditorAccountingAmountOnChange(Item)
	
	TabularSectionRow = Items.Creditor.CurrentData;
	
	CalculateSettlementsAmount(TabularSectionRow);
	
EndProcedure

// Procedure - handler of the OnChange event of
// the Document input field of the Creditor tabular section.
//
&AtClient
Procedure CreditorDocumentOnChange(Item)
	
	TabularSectionRow = Items.Creditor.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashVoucher")
		Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
		Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ExpenseReport") Then
		TabularSectionRow.AdvanceFlag = True;
	Else
		TabularSectionRow.AdvanceFlag = False;
	EndIf;
	
	StructureData = CreateGeneralAttributeValuesStructure(ThisObject, "Creditor", TabularSectionRow);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(StructureData, ThisObject, "Creditor", TabularSectionRow);
	EndIf;
	
	DocumentOnChangeAtServer(StructureData);
	FillPropertyValues(TabularSectionRow, StructureData);
	
EndProcedure

&AtClient
Procedure CreditorIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "Creditor", StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccountsDocumentOnChange(Item)
	
	If TypeOf(Object.AccountsDocument) = Type("DocumentRef.CashReceipt")
	 OR TypeOf(Object.AccountsDocument) = Type("DocumentRef.PaymentReceipt")
	 OR TypeOf(Object.AccountsDocument) = Type("DocumentRef.CashVoucher")
	 OR TypeOf(Object.AccountsDocument) = Type("DocumentRef.PaymentExpense")
	 OR TypeOf(Object.AccountsDocument) = Type("DocumentRef.ExpenseReport") Then
		Object.AdvanceFlag = True;
	Else
		Object.AdvanceFlag = False;
	EndIf;

EndProcedure

&AtClient
Procedure DebitorAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.Debitor.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ArApAdjustments") Then
		Return;
	EndIf;
	
	If TabularSectionRow.AdvanceFlag Then
		
		If TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.CashReceipt")
			And TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.PaymentReceipt") Then
			TabularSectionRow.Document = Undefined;
		EndIf;
		
	Else
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt") Then
			TabularSectionRow.Document = Undefined;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CreditorAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.Creditor.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ArApAdjustments") Then
		Return;
	EndIf;
	
	If TabularSectionRow.AdvanceFlag Then
		
		If TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.CashVoucher")
			And TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.PaymentExpense")
			And TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.ExpenseReport") Then
			TabularSectionRow.Document = Undefined;
		EndIf;
		
	Else
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashVoucher")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
			Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ExpenseReport") Then
			TabularSectionRow.Document = Undefined;
		EndIf;
		
	EndIf;

EndProcedure

#EndRegion

#EndRegion

#Region FormCommandsEventHandlers

// Procedure is opened by clicking "FillOnBasis" button on the Additionally page
//
&AtClient
Procedure FillByDocumentBase(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		
		Message				= New UserMessage;
		Message.Text		= NStr("en = 'Please select a base document.'; ru = 'Не выбран документ-основание.';pl = 'Wybierz dokument źródłowy.';es_ES = 'Por favor, seleccione un documento de base.';es_CO = 'Por favor, seleccione un documento de base.';tr = 'Lütfen, temel belge seçin.';it = 'Si prega di selezionare un documento di base.';de = 'Bitte wählen Sie ein Basisdokument aus.'");
		Message.DataPath	= "BasisDocument";
		Message.Message();
		
		Return;
		
	EndIf;
	
	QuestionText 	= NStr("en = 'Do you want to refill AR/AP adjustments?'; ru = 'Документ будет очищен и заполнен по документу-основанию. Продолжить?';pl = 'Czy chcesz ponownie wypełnić korekty Wn/Ma?';es_ES = '¿Quiere volver a rellenar las modificaciones de las cuentas a cobrar/las cuentas a pagar?';es_CO = '¿Quiere volver a rellenar las modificaciones de las cuentas a cobrar/las cuentas a pagar?';tr = 'Alacak/Borç hesapları düzeltmelerini yeniden doldurmak ister misiniz?';it = 'Volete compilare  le regolazioni AR/AP?';de = 'Möchten Sie Offene Posten Debitoren/Kreditoren-Korrekturen nachfüllen?'");
	Response = Undefined;

	ShowQueryBox(New NotifyDescription("FillAccordingToBasisDocumentEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo, );
	
EndProcedure

&AtClient
Procedure FillAccordingToBasisDocumentEnd(Result, AdditionalParameters) Export
    
    Response 			= Result;
    
    If Response = DialogReturnCode.Yes Then
        
        FillByDocument();
        
    EndIf;

EndProcedure

// Procedure - handler of the Execute event of the Pickup command
// Opens the form of debt forming documents selection.
//
&AtClient
Procedure PickAccountsReceivable(Command)
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.SupplierAdvanceClearing") Then 
		PickUpSupplierSettlementsDebitor();
	Else
		PickUpCustomerSettlements();
	EndIf;
	
EndProcedure

&AtClient
Procedure PickUpSupplierSettlementsDebitor()
	
	If Not ValueIsFilled(Object.CounterpartySource) Then
		ShowMessageBox(, NStr("en = 'Please select a supplier.'; ru = 'Выберите поставщика.';pl = 'Proszę wybrać dostawcę.';es_ES = 'Por favor, seleccione un proveedor.';es_CO = 'Por favor, seleccione un proveedor.';tr = 'Lütfen, tedarikçi seçin.';it = 'Si prega di selezionare un fornitore.';de = 'Bitte wählen Sie einen Lieferanten aus.'"));
		Return;
	EndIf;
	
	TabName = "Debitor";
	AddressDebitorInStorage = PlaceDebitorToStorage();
	
	SelectionParameters = New Structure;
	SelectionParameters.Insert("AddressDebitorInStorage", AddressDebitorInStorage);
	SelectionParameters.Insert("Company", Company);
	SelectionParameters.Insert("Date", Object.Date);
	SelectionParameters.Insert("Counterparty", Object.CounterpartySource);
	SelectionParameters.Insert("Ref", Object.Ref);
	SelectionParameters.Insert("DebitorAccountingAmount", Object.Creditor.Total("AccountingAmount"));
	SelectionParameters.Insert("OperationType", Object.OperationKind);
	SelectionParameters.Insert("TabName", TabName);
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.CustomerAdvanceClearing") 
		Or Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.SupplierAdvanceClearing") Then
		
		SelectionParameters.Insert("AdvanceFlag", True);
	EndIf;
	
	Result = Undefined;
	
	OpenForm("CommonForm.SelectSuppliersDocument", 
		SelectionParameters,,,,, 
		New NotifyDescription(
			"PickUpPaymantsToCustomerEnd", 
			ThisObject, 
			New Structure("AddressDebitorInStorage, TabName", AddressDebitorInStorage, TabName)));

EndProcedure

&AtClient
Procedure PickUpCustomerSettlements()
	
	If Not ValueIsFilled(Object.CounterpartySource) Then
		ShowMessageBox(, NStr("en = 'Please select a customer.'; ru = 'Выберите покупателя.';pl = 'Proszę wybrać nabywcę.';es_ES = 'Por favor, seleccione un cliente.';es_CO = 'Por favor, seleccione un cliente.';tr = 'Lütfen bir müşteri seçin.';it = 'Si prega di selezionare un cliente.';de = 'Bitte wählen Sie einen Kunden aus.'"));
		Return;
	EndIf;
	
	TabName = "Debitor";
	AddressDebitorInStorage = PlaceDebitorToStorage();
	
	SelectionParameters = New Structure;
	SelectionParameters.Insert("AddressDebitorInStorage", AddressDebitorInStorage);
	SelectionParameters.Insert("Company", Company);
	SelectionParameters.Insert("Date", Object.Date);
	SelectionParameters.Insert("Counterparty", Object.CounterpartySource);
	SelectionParameters.Insert("Ref", Object.Ref);
	SelectionParameters.Insert("DebitorAccountingAmount", Object.Debitor.Total("AccountingAmount"));
	SelectionParameters.Insert("OperationType", Object.OperationKind);
	SelectionParameters.Insert("TabName", TabName);
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.CustomerAdvanceClearing") 
		Or Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.SupplierAdvanceClearing") Then
		
		SelectionParameters.Insert("AdvanceFlag", True);
	EndIf;
	
	Result = Undefined;
	
	OpenForm("CommonForm.SelectCustomersDocument", 
	SelectionParameters,,,,, 
	New NotifyDescription("PickUpPaymantsToCustomerEnd", 
		ThisObject, 
		New Structure("AddressDebitorInStorage", AddressDebitorInStorage)));
	
EndProcedure

&AtClient
Procedure PickUpPaymantsToCustomerEnd(Result1, AdditionalParameters) Export

	AddressDebitorInStorage = AdditionalParameters.AddressDebitorInStorage;

	Result = Result1;
	If Result = DialogReturnCode.OK Then
		GetDebitorFromStorage(
			AddressDebitorInStorage, 
			?(AdditionalParameters.Property("TabName"), AdditionalParameters.TabName, ""));
	EndIf;

EndProcedure


// Procedure - handler of the Execute event of the Pickup command
// Opens the form of debt forming documents selection.
//
&AtClient
Procedure PickSupplierrSettlements(Command)
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.CustomerAdvanceClearing") Then
		PickUpCustomerSettlementsCreditor();
	Else
		PickUpSupplierSettlements();
	EndIf;
	
EndProcedure

&AtClient
Procedure PickUpCustomerSettlementsCreditor()
	
	If Not ValueIsFilled(Object.CounterpartySource) Then
		ShowMessageBox(, NStr("en = 'Please select a customer.'; ru = 'Выберите покупателя.';pl = 'Proszę wybrać nabywcę.';es_ES = 'Por favor, seleccione un cliente.';es_CO = 'Por favor, seleccione un cliente.';tr = 'Lütfen bir müşteri seçin.';it = 'Si prega di selezionare un cliente.';de = 'Bitte wählen Sie einen Kunden aus.'"));
		Return;
	EndIf;
	
	TabName = "Creditor";
	AddressCreditorInStorage = PlaceCreditorToStorage();
	
	SelectionParameters = New Structure;
	SelectionParameters.Insert("AddressDebitorInStorage", AddressCreditorInStorage);
	SelectionParameters.Insert("Company", Company);
	SelectionParameters.Insert("Date", Object.Date);
	SelectionParameters.Insert("Counterparty", Object.CounterpartySource);
	SelectionParameters.Insert("Ref", Object.Ref);
	SelectionParameters.Insert("DebitorAccountingAmount", Object.Debitor.Total("AccountingAmount"));
	SelectionParameters.Insert("OperationType", Object.OperationKind);
	SelectionParameters.Insert("TabName", TabName);
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.CustomerAdvanceClearing") 
		Or Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.SupplierAdvanceClearing") Then
		
		SelectionParameters.Insert("AdvanceFlag", False);
	EndIf;
	
	Result = Undefined;
	
	OpenForm("CommonForm.SelectCustomersDocument", 
		SelectionParameters,,,,, 
		New NotifyDescription(
			"PickSupplierSettlementsEnd", 
			ThisObject, 
			New Structure("AddressCreditorInStorage, TabName", AddressCreditorInStorage, TabName)));
	
EndProcedure

&AtClient
Procedure PickUpSupplierSettlements()
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(, NStr("en = 'Please select a supplier.'; ru = 'Выберите поставщика.';pl = 'Proszę wybrać dostawcę.';es_ES = 'Por favor, seleccione un proveedor.';es_CO = 'Por favor, seleccione un proveedor.';tr = 'Lütfen, tedarikçi seçin.';it = 'Si prega di selezionare un fornitore.';de = 'Bitte wählen Sie einen Lieferanten aus.'"));
		Return;
	EndIf;
	
	TabName = "Creditor";
	AddressCreditorInStorage = PlaceCreditorToStorage();
	
	SelectionParameters = New Structure;
	SelectionParameters.Insert("AddressDebitorInStorage", AddressCreditorInStorage);
	SelectionParameters.Insert("Company", Company);
	SelectionParameters.Insert("Date", Object.Date);
	SelectionParameters.Insert("Counterparty", 
		?(Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor"), 
		Object.CounterpartySource, 
		Object.Counterparty));
	SelectionParameters.Insert("Ref", Object.Ref);
	SelectionParameters.Insert("DebitorAccountingAmount", Object.Debitor.Total("AccountingAmount"));
	SelectionParameters.Insert("OperationType", Object.OperationKind);
	SelectionParameters.Insert("TabName", TabName);
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.CustomerAdvanceClearing") 
		Or Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.SupplierAdvanceClearing") Then
		
		SelectionParameters.Insert("AdvanceFlag", False);
	EndIf;
	
	Result = Undefined;
	
	OpenForm("CommonForm.SelectSuppliersDocument", 
		SelectionParameters,,,,, 
		New NotifyDescription(
			"PickSupplierSettlementsEnd", 
			ThisObject, 
			New Structure("AddressCreditorInStorage", AddressCreditorInStorage)));
	
EndProcedure

&AtClient
Procedure PickSupplierSettlementsEnd(Result1, AdditionalParameters) Export

	AddressCreditorInStorage = AdditionalParameters.AddressCreditorInStorage;

	Result = Result1;
	If Result = DialogReturnCode.OK Then
		GetCreditorFromStorage(
			AddressCreditorInStorage,
			?(AdditionalParameters.Property("TabName"), AdditionalParameters.TabName, ""));
	EndIf;

EndProcedure

#EndRegion

#Region Private

&AtClientAtServerNoContext
Function CreateGeneralAttributeValuesStructure(Form, TabName, TabRow)
	
	Object = Form.Object;
	
	StructureData = New Structure;
	
	StructureData.Insert("TabName", TabName);
	StructureData.Insert("Object", Object);
	
	StructureData.Insert("Contract", TabRow.Contract);
	StructureData.Insert("UseDefaultTypeOfAccounting", Form.UseDefaultTypeOfAccounting);
	
	If TabName <> "Header" Then
		
		StructureData.Insert("Document", TabRow.Document);
		
		StructureData.Insert("IncomeAndExpenseTypes", True);
		StructureData.Insert("ExpenseItem", TabRow.ExpenseItem);
		StructureData.Insert("IncomeItem", TabRow.IncomeItem);
		StructureData.Insert("IncomeAndExpenseItems", TabRow.IncomeAndExpenseItems);
		StructureData.Insert("IncomeAndExpenseItemsFilled", TabRow.IncomeAndExpenseItemsFilled);
		
	Else
		StructureData.Insert("IncomeAndExpenseTypes", False);
	EndIf;
	
	Return StructureData;
	
EndFunction

#Region GLAccounts

&AtClientAtServerNoContext
Procedure AddGLAccountsToStructure(StructureData, Form, TabName, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("CounterpartyGLAccounts",	True);
	
	If TabRow.Property("GLAccounts") Then
		StructureData.Insert("GLAccounts",			TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled",	TabRow.GLAccountsFilled);
	Else
		StructureData.Insert("GLAccounts",			"");
	EndIf;
	
	If TabRow.Property("AccountsReceivableGLAccount") Then
		StructureData.Insert("AccountsReceivableGLAccount", TabRow.AccountsReceivableGLAccount);
	EndIf;
	
	If TabRow.Property("AdvancesReceivedGLAccount") Then
		StructureData.Insert("AdvancesReceivedGLAccount", TabRow.AdvancesReceivedGLAccount);
	EndIf;
		
	If TabRow.Property("AccountsPayableGLAccount") Then
		StructureData.Insert("AccountsPayableGLAccount", TabRow.AccountsPayableGLAccount);
	EndIf;
		
	If TabRow.Property("AdvancesPaidGLAccount") Then
		StructureData.Insert("AdvancesPaidGLAccount", TabRow.AdvancesPaidGLAccount);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(ParametersStructure)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	StructureArray = New Array();
	
	If UseDefaultTypeOfAccounting Then
		
		If ParametersStructure.FillHeader Then
			
			Header = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "Header", Object);
			GLAccountsInDocuments.CompleteCounterpartyStructureData(Header, ObjectParameters, "Header",);
			
			StructureArray.Add(Header);
			
		EndIf;
		
		If ParametersStructure.FillAccountsReceivable Then
			
			StructureData = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "Debitor", Object);
			GLAccountsInDocuments.CompleteCounterpartyStructureData(StructureData, ObjectParameters, "Debitor");
			
			StructureArray.Add(StructureData);
			
		EndIf;
		
		If ParametersStructure.FillAccountsPayable Then
			
			StructureData = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "Creditor", Object);
			GLAccountsInDocuments.CompleteCounterpartyStructureData(StructureData, ObjectParameters, "Creditor");
			
			StructureArray.Add(StructureData);
			
		EndIf;
	
	EndIf;
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, ParametersStructure.GetGLAccounts);
	
	If UseDefaultTypeOfAccounting And ParametersStructure.FillHeader Then
		GLAccounts = Header.GLAccounts;
	EndIf;
	
EndProcedure

#EndRegion

#Region WorkWithStorageAndTabularSection

// Function puts the Debitor tabular section in
// temporary storage and returns the address
//
&AtServer
Function PlaceDebitorToStorage()
	
	Return PutToTempStorage(
		Object.Debitor.Unload(,
			"Contract,
			|Document,
			|Order,
			|SettlementsAmount,
			|AccountingAmount,
			|ExchangeRate,
			|Multiplicity,
			|AdvanceFlag"
		),
		UUID
	);
	
EndFunction

// Function gets the Debitor tabular section from the temporary storage.
//
&AtServer
Procedure GetDebitorFromStorage(AddressDebitorInStorage, TabName = "")
	
	TableDebitor = GetFromTempStorage(AddressDebitorInStorage);
	Object.Debitor.Clear();
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then 
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	IsDebtAdjustment = Object.OperationKind = Enums.OperationTypesArApAdjustments.CustomerDebtAdjustment
			Or Object.OperationKind = Enums.OperationTypesArApAdjustments.VendorDebtAdjustment;
			
	For Each RowDebitor In TableDebitor Do
		
		If TabName = "Debitor"
			And (Object.OperationKind = Enums.OperationTypesArApAdjustments.CustomerAdvanceClearing
			Or Object.OperationKind = Enums.OperationTypesArApAdjustments.SupplierAdvanceClearing)
			And Not RowDebitor.AdvanceFlag Then
			
			Continue;
		EndIf;
		
		String = Object.Debitor.Add();
		FillPropertyValues(String, RowDebitor);
		
		IncomeAndExpenseItemsInDocuments.FillCounterpartyIncomeAndExpenseItemsInRow(ObjectParameters, String, "Debitor", RowDebitor.Document);
	
		If UseDefaultTypeOfAccounting Then 
			GLAccountsInDocuments.FillCounterpartyGLAccountsInRow(ObjectParameters, String, "Debitor", RowDebitor.Document);
		EndIf;
		
		If IsDebtAdjustment Then
			
			String.ExpenseItem = DefaultExpenseItem;
			String.IncomeItem = DefaultIncomeItem;
			
		EndIf;
		
	EndDo;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillAccountsReceivable", True);
	ParametersStructure.Insert("FillAccountsPayable", True);
	ParametersStructure.Insert("FillHeader", False);
	FillAddedColumns(ParametersStructure);
	
EndProcedure

// Function puts the Creditor tabular section in
// the temporary storage and returns the address
//
&AtServer
Function PlaceCreditorToStorage()
	
	Return PutToTempStorage(
		Object.Creditor.Unload(,
			"Contract,
			|Document,
			|Order,
			|SettlementsAmount,
			|AccountingAmount,
			|ExchangeRate,
			|Multiplicity,
			|AdvanceFlag"
		),
		UUID
	);
	
EndFunction

// Function gets the Creditor tabular section from the temporary storage.
//
&AtServer
Procedure GetCreditorFromStorage(AddressCreditorInStorage, TabName = "")
	
	TableCreditor = GetFromTempStorage(AddressCreditorInStorage);
	Object.Creditor.Clear();
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then 
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	IsDebtAdjustment = Object.OperationKind = Enums.OperationTypesArApAdjustments.CustomerDebtAdjustment
			Or Object.OperationKind = Enums.OperationTypesArApAdjustments.VendorDebtAdjustment;
			
	For Each RowCreditor In TableCreditor Do
		
		If TabName = "Creditor"
			And (Object.OperationKind = Enums.OperationTypesArApAdjustments.CustomerAdvanceClearing
			Or Object.OperationKind = Enums.OperationTypesArApAdjustments.SupplierAdvanceClearing)
			And RowCreditor.AdvanceFlag Then
			
			Continue;
		EndIf;
		
		String = Object.Creditor.Add();
		FillPropertyValues(String, RowCreditor);
		
		IncomeAndExpenseItemsInDocuments.FillCounterpartyIncomeAndExpenseItemsInRow(ObjectParameters, String, "Debitor", RowCreditor.Document);
		
		If UseDefaultTypeOfAccounting Then 
			GLAccountsInDocuments.FillCounterpartyGLAccountsInRow(ObjectParameters, String, "Creditor", RowCreditor.Document);
		EndIf;
		
		If IsDebtAdjustment Then
			
			String.ExpenseItem = DefaultExpenseItem;
			String.IncomeItem = DefaultIncomeItem;
			
		EndIf;
		
	EndDo;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillAccountsReceivable", True);
	ParametersStructure.Insert("FillAccountsPayable", True);
	ParametersStructure.Insert("FillHeader", False);
	FillAddedColumns(ParametersStructure);
	
EndProcedure

#EndRegion

// Procedure calculates the accounting amount.
//
&AtClient
Procedure CalculateAccountingAmount(TabularSectionRow)
	
	TabularSectionRow.ExchangeRate      = ?(TabularSectionRow.ExchangeRate      = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.AccountingAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		GetExchangeRateMethod(Object.Company),
		TabularSectionRow.ExchangeRate,
		ExchangeRate,
		TabularSectionRow.Multiplicity,
		Multiplicity);
	
EndProcedure

// Procedure calculates the account balance.
//
&AtClient
Procedure CalculateSettlementsAmount(TabularSectionRow)
	
	TabularSectionRow.ExchangeRate      = ?(TabularSectionRow.ExchangeRate = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.AccountingAmount,
	    GetExchangeRateMethod(Object.Company),
		ExchangeRate,
		TabularSectionRow.ExchangeRate,
		Multiplicity,
		TabularSectionRow.Multiplicity);
	
EndProcedure

// It receives data set from the server for the CurrencyCashOnChange procedure.
//
&AtServer
Procedure FillDataContractOnChange(StructureData)
	
	If UseDefaultTypeOfAccounting Then 
		GLAccountsInDocuments.FillCounterpartyGLAccounts(StructureData);
	EndIf;
	
	Contract = Object.Contract;
	StructureData.Insert(
		"CurrencyRateRepetition",
		CurrencyRateOperations.GetCurrencyRate(Object.Date, Contract.SettlementsCurrency, Object.Company));
	
EndProcedure

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert(
		"Company",
		DriveServer.GetCompany(Company)
	);
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure ClearDebitorAndCreditorTabularSection()
	
	If Object.Debitor.Count() > 0 Then
		Object.Debitor.Clear();
	EndIf;
	
	If Object.Creditor.Count() > 0 Then
		Object.Creditor.Clear();
	EndIf;
	
EndProcedure

// Procedure sets choice parameter links.
//
&AtServer
Procedure SetChoiceParameterLinks()
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.ArApAdjustments") Then
		
		NewArray = New Array();
		NewConnection = New ChoiceParameterLink("Filter.Owner", "CounterpartyRecipient");
		
		NewArray.Add(NewConnection);
		NewConnections = New FixedArray(NewArray);
		Items.Creditor.ChildItems.CreditorContract.ChoiceParameterLinks = NewConnections;
		
		NewArray = New Array();
		NewConnection = New ChoiceParameterLink("Filter.Counterparty", "CounterpartyRecipient");
		NewArray.Add(NewConnection);
		
		NewConnections = New FixedArray(NewArray);
		Items.Creditor.ChildItems.CreditorDocument.ChoiceParameterLinks = NewConnections;
		Items.Creditor.ChildItems.CreditorOrder.ChoiceParameterLinks = NewConnections;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor") Then
		
		NewArray = New Array();
		NewConnection = New ChoiceParameterLink("Filter.Owner", "Counterparty");
		NewArray.Add(NewConnection);
		
		NewConnections = New FixedArray(NewArray);
		Items.Creditor.ChildItems.CreditorContract.ChoiceParameterLinks = NewConnections;
		
		NewArray = New Array();
		NewConnection = New ChoiceParameterLink("Filter.Counterparty", "Counterparty");
		NewArray.Add(NewConnection);
		
		NewConnections = New FixedArray(NewArray);
		Items.Creditor.ChildItems.CreditorDocument.ChoiceParameterLinks = NewConnections;
		Items.Creditor.ChildItems.CreditorOrder.ChoiceParameterLinks = NewConnections;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.CustomerAdvanceClearing") Then
		
		NewArray = New Array();
		NewConnection = New ChoiceParameterLink("Filter.Owner", "Counterparty");
		NewArray.Add(NewConnection);
		
		NewConnections = New FixedArray(NewArray);
		Items.Creditor.ChildItems.CreditorContract.ChoiceParameterLinks = NewConnections;
		
		NewArray = New Array();
		NewConnection = New ChoiceParameterLink("Filter.Counterparty", "Counterparty");
		NewArray.Add(NewConnection);
		
		NewConnections = New FixedArray(NewArray);
		Items.Creditor.ChildItems.CreditorDocument.ChoiceParameterLinks = NewConnections;
		Items.Creditor.ChildItems.CreditorOrder.ChoiceParameterLinks = NewConnections;
		
		NewArray = New Array;
		NewArray.Add(New ChoiceParameter("Filter.Customer", True));
		Items.CounterpartySource.ChoiceParameters = New FixedArray(NewArray);
		
		NewArray = New Array;
		NewArray.Add(New ChoiceParameter("Filter.AdvanceFlag", False));
		Items.DebitorDocument.ChoiceParameters = New FixedArray(NewArray);
		
		NewArray = New Array;
		NewArray.Add(New ChoiceParameter("Filter.AdvanceFlag", True));
		Items.CreditorDocument.ChoiceParameters = New FixedArray(NewArray);
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.SupplierAdvanceClearing") Then
		
		NewArray = New Array();
		NewConnection = New ChoiceParameterLink("Filter.Owner", "Counterparty");
		NewArray.Add(NewConnection);
		
		NewConnections = New FixedArray(NewArray);
		Items.Creditor.ChildItems.CreditorContract.ChoiceParameterLinks = NewConnections;
		
		NewArray = New Array();
		NewConnection = New ChoiceParameterLink("Filter.Counterparty", "Counterparty");
		NewArray.Add(NewConnection);
		
		NewConnections = New FixedArray(NewArray);
		Items.Creditor.ChildItems.CreditorDocument.ChoiceParameterLinks = NewConnections;
		Items.Creditor.ChildItems.CreditorOrder.ChoiceParameterLinks = NewConnections;
		
		NewArray = New Array;
		NewArray.Add(New ChoiceParameter("Filter.Supplier", True));
		Items.CounterpartySource.ChoiceParameters = New FixedArray(NewArray);
		
		NewArray = New Array;
		NewArray.Add(New ChoiceParameter("Filter.AdvanceFlag", False));
		Items.DebitorDocument.ChoiceParameters = New FixedArray(NewArray);
		
		NewArray = New Array;
		NewArray.Add(New ChoiceParameter("Filter.AdvanceFlag", True));
		Items.CreditorDocument.ChoiceParameters = New FixedArray(NewArray);
		
	EndIf;
	
EndProcedure

// Procedure sets availability.
//
&AtServer
Procedure SetVisibleAndEnabled()
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.ArApAdjustments") Then
		
		Items.Recipient.Visible = False;
		Items.SettlementsWithDebitor.Visible = True;
		Items.PaymentsToCreditor.Visible = True;
		Items.Correspondence.Visible = False;
		Items.CounterpartySource.Visible = True;
		Items.CounterpartyRecipient.Visible = True;
		Items.CounterpartySource.Title = Nstr("en = 'Customer'; ru = 'Покупатель';pl = 'Nabywca';es_ES = 'Cliente';es_CO = 'Cliente';tr = 'Müşteri';it = 'Cliente';de = 'Kunde'");
		Items.CounterpartyRecipient.Title =  Nstr("en = 'Supplier'; ru = 'Поставщик';pl = 'Dostawca';es_ES = 'Proveedor';es_CO = 'Proveedor';tr = 'Tedarikçi';it = 'Fornitore';de = 'Lieferant'");
		Items.Pages.PagesRepresentation = FormPagesRepresentation.TabsOnTop;
		
		Items.SettlementsWithDebitor.Title = Nstr("en = 'Customer balance'; ru = 'Баланс покупателя';pl = 'Saldo nabywcy';es_ES = 'Saldo del cliente';es_CO = 'Saldo del cliente';tr = 'Müşteri bakiyesi';it = 'Saldo cliente';de = 'Kundensaldo'");
		Items.PaymentsToCreditor.Title =  Nstr("en = 'Supplier balance'; ru = 'Баланс поставщика';pl = 'Saldo dostawcy';es_ES = 'Saldo del proveedor';es_CO = 'Saldo del proveedor';tr = 'Tedarikçi bakiyesi';it = 'Saldo fornitore';de = 'Lieferantensaldo'");
		
		Items.DebitorAccountingSumTotal.Title = NStr("en = 'Debit'; ru = 'Дебет';pl = 'Wn';es_ES = 'Débito';es_CO = 'Débito';tr = 'Borç';it = 'Debito';de = 'Soll'");
		Items.CreditorAccountingAmountTotal.Title = NStr("en = 'Credit'; ru = 'Кредит';pl = 'Ma';es_ES = 'Crédito';es_CO = 'Crédito';tr = 'Alacak';it = 'Credito';de = 'Haben'");
		
		Items.DebitorContract.Visible = CounterpartySourceAttributes.DoOperationsByContracts;
		Items.DebitorAdvanceFlag.ReadOnly = True;
		Items.DebitorDocument.AutoMarkIncomplete = True And Not Object.ForOpeningBalancesOnly;
		Items.DebitorOrder.Visible = CounterpartySourceAttributes.DoOperationsByOrders;
		Items.DebitorProject.Visible = False;
		
		Items.CreditorContract.Visible = CounterpartyRecipientAttributes.DoOperationsByContracts;
		Items.CreditorAdvanceFlag.ReadOnly = True;
		Items.CreditorDocument.AutoMarkIncomplete = True And Not Object.ForOpeningBalancesOnly;
		Items.CreditorOrder.Visible = CounterpartyRecipientAttributes.DoOperationsByOrders;
		Items.CreditorProject.Visible = False;
		
		Items.DebitorAdvanceFlag.Visible = True;
		Items.CreditorAdvanceFlag.Visible = True;
		
		Items.DebitorIncomeAndExpenseItems.Visible = False;
		Items.CreditorIncomeAndExpenseItems.Visible = False;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.CustomerDebtAssignment") Then
		
		Items.Recipient.Visible = True;
		Items.SettlementsWithDebitor.Visible = True;
		Items.PaymentsToCreditor.Visible = False;
		Items.Correspondence.Visible = False;
		Items.CounterpartySource.Visible = True;
		Items.CounterpartyRecipient.Visible = True;
		Items.CounterpartySource.Title = Nstr("en = 'Customer'; ru = 'Покупатель';pl = 'Nabywca';es_ES = 'Cliente';es_CO = 'Cliente';tr = 'Müşteri';it = 'Cliente';de = 'Kunde'");
		Items.CounterpartyRecipient.Title =  Nstr("en = 'Assignee'; ru = 'Исполнитель';pl = 'Wykonawca';es_ES = 'Beneficiario';es_CO = 'Beneficiario';tr = 'Atanan';it = 'Assegnatario';de = 'Bevollmächtiger'");
		Items.Pages.PagesRepresentation = FormPagesRepresentation.TabsOnTop;
		
		Items.SettlementsWithDebitor.Title = Nstr("en = 'Customer balance'; ru = 'Баланс покупателя';pl = 'Saldo nabywcy';es_ES = 'Saldo del cliente';es_CO = 'Saldo del cliente';tr = 'Müşteri bakiyesi';it = 'Saldo cliente';de = 'Kundensaldo'");
		Items.PaymentsToCreditor.Title =  Nstr("en = 'Supplier balance'; ru = 'Баланс поставщика';pl = 'Saldo dostawcy';es_ES = 'Saldo del proveedor';es_CO = 'Saldo del proveedor';tr = 'Tedarikçi bakiyesi';it = 'Saldo fornitore';de = 'Lieferantensaldo'");
		
		Items.DebitorAccountingSumTotal.Title = NStr("en = 'Debit'; ru = 'Дебет';pl = 'Wn';es_ES = 'Débito';es_CO = 'Débito';tr = 'Borç';it = 'Debito';de = 'Soll'");
		Items.CreditorAccountingAmountTotal.Title = NStr("en = 'Credit'; ru = 'Кредит';pl = 'Ma';es_ES = 'Crédito';es_CO = 'Crédito';tr = 'Alacak';it = 'Credito';de = 'Haben'");
		
		Items.DebitorContract.Visible = CounterpartySourceAttributes.DoOperationsByContracts;
		Items.DebitorAdvanceFlag.ReadOnly = True;
		Items.DebitorDocument.AutoMarkIncomplete = True And Not Object.ForOpeningBalancesOnly;
		Items.DebitorOrder.Visible = CounterpartySourceAttributes.DoOperationsByOrders;
		Items.DebitorProject.Visible = False;
		
		Items.Contract.Visible = CounterpartyRecipientAttributes.DoOperationsByContracts;
		Items.AdvanceFlag.ReadOnly = True;
		Items.Order.Visible = CounterpartyRecipientAttributes.DoOperationsByOrders;
		
		Items.DebitorAdvanceFlag.Visible = True;
		Items.CreditorAdvanceFlag.Visible = True;
		
		Items.DebitorIncomeAndExpenseItems.Visible = False;
		Items.CreditorIncomeAndExpenseItems.Visible = False;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor") Then
		
		Items.Recipient.Visible = True;
		Items.SettlementsWithDebitor.Visible = False;
		Items.PaymentsToCreditor.Visible = True;
		Items.Correspondence.Visible = False;
		Items.CounterpartySource.Visible = True;
		Items.CounterpartyRecipient.Visible = True;
		Items.CounterpartySource.Title =  Nstr("en = 'Supplier'; ru = 'Поставщик';pl = 'Dostawca';es_ES = 'Proveedor';es_CO = 'Proveedor';tr = 'Tedarikçi';it = 'Fornitore';de = 'Lieferant'");
		Items.CounterpartyRecipient.Title =  Nstr("en = 'Assignee'; ru = 'Исполнитель';pl = 'Wykonawca';es_ES = 'Beneficiario';es_CO = 'Beneficiario';tr = 'Atanan';it = 'Assegnatario';de = 'Bevollmächtiger'");
		Items.Pages.PagesRepresentation = FormPagesRepresentation.TabsOnTop;
		
		Items.SettlementsWithDebitor.Title = Nstr("en = 'Customer balance'; ru = 'Баланс покупателя';pl = 'Saldo nabywcy';es_ES = 'Saldo del cliente';es_CO = 'Saldo del cliente';tr = 'Müşteri bakiyesi';it = 'Saldo cliente';de = 'Kundensaldo'");
		Items.PaymentsToCreditor.Title =  Nstr("en = 'Supplier balance'; ru = 'Баланс поставщика';pl = 'Saldo dostawcy';es_ES = 'Saldo del proveedor';es_CO = 'Saldo del proveedor';tr = 'Tedarikçi bakiyesi';it = 'Saldo fornitore';de = 'Lieferantensaldo'");
		
		Items.DebitorAccountingSumTotal.Title = NStr("en = 'Debit'; ru = 'Дебет';pl = 'Wn';es_ES = 'Débito';es_CO = 'Débito';tr = 'Borç';it = 'Debito';de = 'Soll'");
		Items.CreditorAccountingAmountTotal.Title = NStr("en = 'Credit'; ru = 'Кредит';pl = 'Ma';es_ES = 'Crédito';es_CO = 'Crédito';tr = 'Alacak';it = 'Credito';de = 'Haben'");
		
		Items.CreditorContract.Visible = CounterpartySourceAttributes.DoOperationsByContracts;
		Items.CreditorAdvanceFlag.ReadOnly = True;
		Items.CreditorDocument.AutoMarkIncomplete = True And Not Object.ForOpeningBalancesOnly;
		Items.CreditorOrder.Visible = CounterpartySourceAttributes.DoOperationsByOrders;
		Items.CreditorProject.Visible = False;
		
		Items.Contract.Visible = CounterpartyRecipientAttributes.DoOperationsByContracts;
		Items.AdvanceFlag.ReadOnly = True;
		Items.Order.Visible = CounterpartyRecipientAttributes.DoOperationsByOrders;
		
		Items.DebitorAdvanceFlag.Visible = True;
		Items.CreditorAdvanceFlag.Visible = True;
		
		Items.DebitorIncomeAndExpenseItems.Visible = False;
		Items.CreditorIncomeAndExpenseItems.Visible = False;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.CustomerDebtAdjustment") Then
		
		Items.Recipient.Visible = False;
		Items.SettlementsWithDebitor.Visible = True;
		Items.PaymentsToCreditor.Visible = False;
		Items.Correspondence.Visible = True;
		Items.CounterpartySource.Visible = True;
		Items.CounterpartyRecipient.Visible = False;
		Items.CounterpartySource.Title =  Nstr("en = 'Customer'; ru = 'Покупатель';pl = 'Nabywca';es_ES = 'Cliente';es_CO = 'Cliente';tr = 'Müşteri';it = 'Cliente';de = 'Kunde'");
		
		Items.SettlementsWithDebitor.Title = Nstr("en = 'Customer balance'; ru = 'Баланс покупателя';pl = 'Saldo nabywcy';es_ES = 'Saldo del cliente';es_CO = 'Saldo del cliente';tr = 'Müşteri bakiyesi';it = 'Saldo cliente';de = 'Kundensaldo'");
		Items.PaymentsToCreditor.Title =  Nstr("en = 'Supplier balance'; ru = 'Баланс поставщика';pl = 'Saldo dostawcy';es_ES = 'Saldo del proveedor';es_CO = 'Saldo del proveedor';tr = 'Tedarikçi bakiyesi';it = 'Saldo fornitore';de = 'Lieferantensaldo'");
		
		Items.DebitorAccountingSumTotal.Title = NStr("en = 'Debit'; ru = 'Дебет';pl = 'Wn';es_ES = 'Débito';es_CO = 'Débito';tr = 'Borç';it = 'Debito';de = 'Soll'");
		Items.CreditorAccountingAmountTotal.Title = NStr("en = 'Credit'; ru = 'Кредит';pl = 'Ma';es_ES = 'Crédito';es_CO = 'Crédito';tr = 'Alacak';it = 'Credito';de = 'Haben'");
		
		Items.DebitorContract.Visible = CounterpartySourceAttributes.DoOperationsByContracts;
		Items.DebitorDocument.AutoMarkIncomplete = False;
		Items.DebitorAdvanceFlag.ReadOnly = False;
		Items.DebitorOrder.Visible = CounterpartySourceAttributes.DoOperationsByOrders;
		Items.DebitorProject.Visible = True;
		
		Items.DebitorAdvanceFlag.Visible = True;
		Items.CreditorAdvanceFlag.Visible = True;
		
		Items.DebitorIncomeAndExpenseItems.Visible = True;
		Items.CreditorIncomeAndExpenseItems.Visible = True;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.VendorDebtAdjustment") Then
		
		Items.Recipient.Visible = False;
		Items.SettlementsWithDebitor.Visible = False;
		Items.PaymentsToCreditor.Visible = True;
		Items.Correspondence.Visible = True;
		Items.CounterpartySource.Visible = False;
		Items.CounterpartyRecipient.Visible = True;
		Items.CounterpartyRecipient.Title =  Nstr("en = 'Supplier'; ru = 'Поставщик';pl = 'Dostawca';es_ES = 'Proveedor';es_CO = 'Proveedor';tr = 'Tedarikçi';it = 'Fornitore';de = 'Lieferant'");
		
		Items.SettlementsWithDebitor.Title = Nstr("en = 'Customer balance'; ru = 'Баланс покупателя';pl = 'Saldo nabywcy';es_ES = 'Saldo del cliente';es_CO = 'Saldo del cliente';tr = 'Müşteri bakiyesi';it = 'Saldo cliente';de = 'Kundensaldo'");
		Items.PaymentsToCreditor.Title =  Nstr("en = 'Supplier balance'; ru = 'Баланс поставщика';pl = 'Saldo dostawcy';es_ES = 'Saldo del proveedor';es_CO = 'Saldo del proveedor';tr = 'Tedarikçi bakiyesi';it = 'Saldo fornitore';de = 'Lieferantensaldo'");
		
		Items.DebitorAccountingSumTotal.Title = NStr("en = 'Debit'; ru = 'Дебет';pl = 'Wn';es_ES = 'Débito';es_CO = 'Débito';tr = 'Borç';it = 'Debito';de = 'Soll'");
		Items.CreditorAccountingAmountTotal.Title = NStr("en = 'Credit'; ru = 'Кредит';pl = 'Ma';es_ES = 'Crédito';es_CO = 'Crédito';tr = 'Alacak';it = 'Credito';de = 'Haben'");
		
		Items.CreditorContract.Visible = CounterpartyRecipientAttributes.DoOperationsByContracts;
		Items.CreditorAdvanceFlag.ReadOnly = False;
		Items.CreditorDocument.AutoMarkIncomplete = False;
		Items.CreditorOrder.Visible = CounterpartyRecipientAttributes.DoOperationsByOrders;
		Items.CreditorProject.Visible = True;
		
		Items.DebitorAdvanceFlag.Visible = True;
		Items.CreditorAdvanceFlag.Visible = True;
		
		Items.DebitorIncomeAndExpenseItems.Visible = True;
		Items.CreditorIncomeAndExpenseItems.Visible = True;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.CustomerAdvanceClearing")
		Or Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.SupplierAdvanceClearing") Then
		
		Items.Recipient.Visible = False;
		Items.SettlementsWithDebitor.Visible = True;
		Items.PaymentsToCreditor.Visible = True;
		Items.Correspondence.Visible = False;
		Items.CounterpartySource.Visible = True;
		Items.CounterpartyRecipient.Visible = False;
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.CustomerAdvanceClearing") Then
			Items.CounterpartySource.Title =  Nstr("en = 'Customer'; ru = 'Покупатель';pl = 'Nabywca';es_ES = 'Cliente';es_CO = 'Cliente';tr = 'Müşteri';it = 'Cliente';de = 'Kunde'");
			Items.SettlementsWithDebitor.Title = Nstr("en = 'Advances received'; ru = 'Авансы полученные';pl = 'Zaliczki otrzymane';es_ES = 'Anticipos recibidos';es_CO = 'Anticipos recibidos';tr = 'Alınan avanslar';it = 'Anticipi ricevuti';de = 'Vorauszahlungen erhalten'");
			Items.PaymentsToCreditor.Title =  Nstr("en = 'Accounts receivable'; ru = 'Дебиторская задолженность';pl = 'Należności';es_ES = 'Cuentas a cobrar';es_CO = 'Cuentas a cobrar';tr = 'Alacak hesapları';it = 'Crediti';de = 'Offene Posten Debitoren'");
			Items.DebitorAccountingSumTotal.Title = NStr("en = 'Advances received'; ru = 'Авансы полученные';pl = 'Zaliczki otrzymane';es_ES = 'Anticipos recibidos';es_CO = 'Anticipos recibidos';tr = 'Alınan avanslar';it = 'Anticipi ricevuti';de = 'Vorauszahlungen erhalten'");
			Items.CreditorAccountingAmountTotal.Title = NStr("en = 'Accounts receivable'; ru = 'Дебиторская задолженность';pl = 'Należności';es_ES = 'Cuentas a cobrar';es_CO = 'Cuentas a cobrar';tr = 'Alacak hesapları';it = 'Crediti';de = 'Offene Posten Debitoren'");
		Else
			Items.CounterpartySource.Title =  Nstr("en = 'Supplier'; ru = 'Поставщик';pl = 'Dostawca';es_ES = 'Proveedor';es_CO = 'Proveedor';tr = 'Tedarikçi';it = 'Fornitore';de = 'Lieferant'");
			Items.SettlementsWithDebitor.Title = Nstr("en = 'Advances paid'; ru = 'Авансы выплаченные';pl = 'Zaliczki dla dostawców';es_ES = 'Anticipos pagados';es_CO = 'Anticipos pagados';tr = 'Verilen avanslar';it = 'Anticipi versati';de = 'Vorauszahlungen geleistet'");
			Items.PaymentsToCreditor.Title =  Nstr("en = 'Accounts payable'; ru = 'Кредиторская задолженность';pl = 'Zobowiązania';es_ES = 'Cuentas por pagar';es_CO = 'Cuentas a pagar';tr = 'Borç hesapları';it = 'Debiti contabili';de = 'Offene Posten Kreditoren'");
			Items.DebitorAccountingSumTotal.Title = NStr("en = 'Advances paid'; ru = 'Авансы выплаченные';pl = 'Zaliczki dla dostawców';es_ES = 'Anticipos pagados';es_CO = 'Anticipos pagados';tr = 'Verilen avanslar';it = 'Anticipi versati';de = 'Vorauszahlungen geleistet'");
			Items.CreditorAccountingAmountTotal.Title = NStr("en = 'Accounts payable'; ru = 'Кредиторская задолженность';pl = 'Zobowiązania';es_ES = 'Cuentas por pagar';es_CO = 'Cuentas a pagar';tr = 'Borç hesapları';it = 'Debiti contabili';de = 'Offene Posten Kreditoren'");
		EndIf;
		
		Items.DebitorContract.Visible = CounterpartySourceAttributes.DoOperationsByContracts;
		If ValueIsFilled(Object.CounterpartySource) Then
			Items.DebitorAdvanceFlag.ReadOnly = Object.CounterpartySource.DoOperationsByContracts;
		Else
			Items.DebitorAdvanceFlag.ReadOnly = True;
		EndIf;
		Items.DebitorDocument.AutoMarkIncomplete = True And Not Object.ForOpeningBalancesOnly;
		Items.DebitorOrder.Visible = CounterpartySourceAttributes.DoOperationsByOrders;
		
		Items.CreditorContract.Visible = CounterpartySourceAttributes.DoOperationsByContracts;
		If ValueIsFilled(Object.CounterpartySource) Then
			Items.CreditorAdvanceFlag.ReadOnly = Object.CounterpartySource.DoOperationsByContracts;
		Else
			Items.CreditorAdvanceFlag.ReadOnly = True;
		EndIf;
		Items.CreditorDocument.AutoMarkIncomplete = True And Not Object.ForOpeningBalancesOnly;
		Items.CreditorOrder.Visible = CounterpartySourceAttributes.DoOperationsByOrders;
		
		Items.DebitorAdvanceFlag.Visible = False;
		Items.CreditorAdvanceFlag.Visible = False;
		
		Items.DebitorIncomeAndExpenseItems.Visible = False;
		Items.CreditorIncomeAndExpenseItems.Visible = False;
		
	EndIf;
	
	Items.GLAccounts.Visible = UseDefaultTypeOfAccounting;
	
	SetIncomeAndExpenseItemsVisibility();
	
EndProcedure

// Procedure sets selection parameter links and available types.
//
&AtClient
Procedure SetAvailableTypes()
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.CustomerDebtAssignment") Then
		
		Array = New Array();
		Array.Add(Type("DocumentRef.FixedAssetSale"));
		Array.Add(Type("DocumentRef.SalesInvoice"));
		Array.Add(Type("DocumentRef.AccountSalesFromConsignee"));
		Array.Add(Type("DocumentRef.CashReceipt"));
		Array.Add(Type("DocumentRef.SalesOrder"));
		Array.Add(Type("DocumentRef.PaymentReceipt"));
		
		ValidTypes = New TypeDescription(Array, , );
		Items.AccountsDocument.TypeRestriction = ValidTypes;
		
		Items.DebitorDocument.TypeRestriction = DebitorDocumentType;
		Items.CreditorDocument.TypeRestriction = CreditorDocumentType;
		
		ValidTypes = New TypeDescription("DocumentRef.SalesOrder", , );
		Items.Order.TypeRestriction = ValidTypes;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor") Then
		
		Array = New Array();
		Array.Add(Type("DocumentRef.AdditionalExpenses"));
		Array.Add(Type("DocumentRef.PaymentExpense"));
		Array.Add(Type("DocumentRef.CashVoucher"));
		Array.Add(Type("DocumentRef.SupplierInvoice"));
		Array.Add(Type("DocumentRef.ExpenseReport"));
		Array.Add(Type("DocumentRef.AccountSalesToConsignor"));
		Array.Add(Type("DocumentRef.ArApAdjustments"));
		
		ValidTypes = New TypeDescription(Array, , );
		Items.AccountsDocument.TypeRestriction = ValidTypes;
		
		Items.DebitorDocument.TypeRestriction = DebitorDocumentType;
		Items.CreditorDocument.TypeRestriction = CreditorDocumentType;
		
		ValidTypes = New TypeDescription("DocumentRef.PurchaseOrder", , );
		Items.Order.TypeRestriction = ValidTypes;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.CustomerAdvanceClearing") Then
		
		ArrayDebitor = New Array;
		ArrayDebitor.Add(Type("DocumentRef.ArApAdjustments"));
		ArrayDebitor.Add(Type("DocumentRef.CashReceipt"));
		ArrayDebitor.Add(Type("DocumentRef.CreditNote"));
		ArrayDebitor.Add(Type("DocumentRef.PaymentReceipt"));
		
		ArrayCreditor = New Array;
		ArrayCreditor.Add(Type("DocumentRef.AccountSalesFromConsignee"));
		ArrayCreditor.Add(Type("DocumentRef.CashVoucher"));
		ArrayCreditor.Add(Type("DocumentRef.FixedAssetSale"));
		ArrayCreditor.Add(Type("DocumentRef.PaymentExpense"));
		ArrayCreditor.Add(Type("DocumentRef.SalesInvoice"));
		
		ValidTypesDebitor = New TypeDescription(ArrayDebitor, , );
		ValidTypesCreditor = New TypeDescription(ArrayCreditor, , );
		
		Items.DebitorDocument.TypeRestriction = ValidTypesDebitor;
		Items.CreditorDocument.TypeRestriction = ValidTypesCreditor;
		
		ValidTypes = New TypeDescription("DocumentRef.SalesOrder", , );
		Items.Order.TypeRestriction = ValidTypes;
		Items.CreditorOrder.TypeRestriction = ValidTypes;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesArApAdjustments.SupplierAdvanceClearing") Then
		
		ArrayDebitor = New Array;
		ArrayDebitor.Add(Type("DocumentRef.ArApAdjustments"));
		ArrayDebitor.Add(Type("DocumentRef.CashVoucher"));
		ArrayDebitor.Add(Type("DocumentRef.DebitNote"));
		ArrayDebitor.Add(Type("DocumentRef.PaymentExpense"));
		
		ArrayCreditor = New Array;
		ArrayCreditor.Add(Type("DocumentRef.AccountSalesToConsignor"));
		ArrayCreditor.Add(Type("DocumentRef.AdditionalExpenses"));
		ArrayCreditor.Add(Type("DocumentRef.ArApAdjustments"));
		ArrayCreditor.Add(Type("DocumentRef.CashReceipt"));
		ArrayCreditor.Add(Type("DocumentRef.PaymentReceipt"));
		ArrayCreditor.Add(Type("DocumentRef.SubcontractorInvoiceReceived"));
		ArrayCreditor.Add(Type("DocumentRef.SupplierInvoice"));
		
		ValidTypesDebitor = New TypeDescription(ArrayDebitor, , );
		ValidTypesCreditor = New TypeDescription(ArrayCreditor, , );
		
		Items.DebitorDocument.TypeRestriction = ValidTypesDebitor;
		Items.CreditorDocument.TypeRestriction = ValidTypesCreditor;
		
		ValidTypes = New TypeDescription("DocumentRef.PurchaseOrder", , );
		Items.Order.TypeRestriction = ValidTypes;
		Items.CreditorOrder.TypeRestriction = ValidTypes;
		
	Else
		Items.DebitorDocument.TypeRestriction = DebitorDocumentType;
		Items.CreditorDocument.TypeRestriction = CreditorDocumentType;
	EndIf;
	
EndProcedure

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	ColorTextSpecifiedInDocument = StyleColors.TextSpecifiedInDocument;
	
	//DebitorDocument
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.OperationKind");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= Enums.OperationTypesArApAdjustments.CustomerDebtAdjustment;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.Debitor.Document");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.NotFilled;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = '<auto>'; ru = '<авто>';pl = '<auto>';es_ES = '<auto>';es_CO = '<auto>';tr = '<otomatik>';it = '<auto>';de = '<auto>'"));
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorTextSpecifiedInDocument);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("DebitorDocument");
	FieldAppearance.Use = True;
	
	//CreditorDocument
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.OperationKind");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= Enums.OperationTypesArApAdjustments.VendorDebtAdjustment;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.Creditor.Document");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.NotFilled;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = '<auto>'; ru = '<авто>';pl = '<auto>';es_ES = '<auto>';es_CO = '<auto>';tr = '<otomatik>';it = '<auto>';de = '<auto>'"));
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorTextSpecifiedInDocument);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("CreditorDocument");
	FieldAppearance.Use = True;
	
EndProcedure

// It gets counterparty contract selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormParameters(Document, Company, Counterparty, Contract, OperationKind, IsOperationsByContracts, TabularSectionName = "")
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Document, OperationKind, TabularSectionName);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", IsOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

&AtServerNoContext
Function GetExchangeRateMethod(Company)

	Return DriveServer.GetExchangeMethod(Company);	

EndFunction // GetExchangeRateMethod()

// Checks the document details filling for the correct transfer to PSU.
//
&AtServer
Procedure CheckCorrectnessOfDetailsOfDocumentFill(QuestionText)

	SumAdvancesDebitor  = 0;
	SumAdvancesLender = 0;
	
	ContractsArray = New Array;
	ContractsArray.Add(Object.Contract);
	
	For Each TableRow In Object.Debitor Do
		
		If TableRow.AdvanceFlag Then
			SumAdvancesDebitor = SumAdvancesDebitor + TableRow.SettlementsAmount;
		EndIf;
		
		ContractsArray.Add(TableRow.Contract);
	EndDo;
	
	For Each TableRow In Object.Creditor Do
		
		If TableRow.AdvanceFlag Then
			SumAdvancesLender = SumAdvancesLender + TableRow.SettlementsAmount;
		EndIf;
		
		ContractsArray.Add(TableRow.Contract);
	EndDo;
	
	// Checking the availability of several currencies
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED DISTINCT
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency
	|FROM
	|	Catalog.CounterpartyContracts AS CounterpartyContracts
	|WHERE
	|	CounterpartyContracts.Ref IN(&ContractsArray)
	|	AND CounterpartyContracts.Ref <> VALUE(Catalog.CounterpartyContracts.EmptyRef)";
	
	Query.SetParameter("ContractsArray", ContractsArray);
	Selection = Query.Execute().Select();
	
	If Selection.Count() > 1 Then
		
		QuestionText = NStr("en = 'Document created in several currencies will not be transferred to Enterprise Accounting.
		                    |
		                    |Do you like to continue document record?'; 
		                    |ru = 'Документ оформленный в нескольких валютах не будет перенесен в ""Бухгалтерию предприятия"".
		                    |
		                    |Продолжить запись документа?';
		                    |pl = 'Dokument utworzony w wielu walutach, nie zostanie przeniesiony do ""Księgowości przedsiębiorstwa"".
		                    |
		                    |Kontynuować zapis dokumentu?';
		                    |es_ES = 'Documento creado en varias monedas no se trasladará a la Contabilidad de la Empresa.
		                    |
		                    |¿Le gustaría continuar con la grabación del documento?';
		                    |es_CO = 'Documento creado en varias monedas no se trasladará a la Contabilidad de la Empresa.
		                    |
		                    |¿Le gustaría continuar con la grabación del documento?';
		                    |tr = 'Birkaç para biriminde oluşturulan belge Kurumsal Muhasebeye aktarılmayacaktır. 
		                    |
		                    |Belge kaydına devam etmek ister misiniz?';
		                    |it = 'Il documento creato in diverse valute non sarà trasferiti alla Contabilità Aziendale.
		                    |
		                    |Volete continuare a registrare il documento?';
		                    |de = 'Dokumente, die in mehreren Währungen erstellt wurden, werden nicht an die Gesellschaftsbuchhaltung übertragen.
		                    |
		                    |Möchten Sie die Dokumentenaufzeichnung fortsetzen?'");
			
		Return;
		
	EndIf;
	
	// Checking the correctness of filling out the ArApAdjustments operation
	If Object.OperationKind = Enums.OperationTypesArApAdjustments.ArApAdjustments
		AND SumAdvancesDebitor <> SumAdvancesLender Then
		
		QuestionText = NStr("en = 'Document which advance amount in tabular section ""Receivables"" does
		                    |not correspond to the advance amount of tabular section ""Payables"" will not be transferred to Enterprise Accounting.
		                    |
		                    |Do you like to continue document record?'; 
		                    |ru = 'Документ, у которого сумма авансов в табличной части
		                    |""Дебиторская задолженность"" не соответствует сумме авансов в табличной части ""Кредиторская задолженность"", не будет перенесен в ""Бухгалтерию предприятия"".
		                    |
		                    |Продолжить запись документа?';
		                    |pl = 'Dokument, w któtym wartość zaliczki w sekcji tabelarycznej ""Należności"" 
		                    |nie odpowiada wartości zaliczki w sekcji tabelarycznej ""Zobowiązania"" nie zostanie przeniesiony do Ewidencji Przedsiębiorstwa.
		                    |
		                    |Czy chcesz kontynuować zapisywanie dokumentu?';
		                    |es_ES = 'Documento cuyo importe de anticipo en la sección tabular ""Cuentas a cobrar"" no
		                    |corresponde al importe de anticipo de la sección tabular ""Cuentas a pagar"", no se trasladará a la Contabilidad de la Empresa.
		                    |
		                    |¿Le gustaría continuar con la grabación del documento?';
		                    |es_CO = 'Documento cuyo importe de anticipo en la sección tabular ""Cuentas a cobrar"" no
		                    |corresponde al importe de anticipo de la sección tabular ""Cuentas a pagar"", no se trasladará a la Contabilidad de la Empresa.
		                    |
		                    |¿Le gustaría continuar con la grabación del documento?';
		                    |tr = '""Alacaklar"" sekmeli bölümünde ""Ön ödemeli hesaplar"" belgesindeki 
		                    |avans tutarı, ""Borçlar"" tablosunun ön ödeme tutarına tekabül etmez ve
		                    | Kurumsal kayıtlara aktarılmaz
		                    | Belge kaydına devam etmek ister misiniz?';
		                    |it = 'Il documento, il cui importo di pagamento anticipato nella sezione tabellare ""Importi da versare"" non
		                    |corrisponde all''importo del pagamento anticipato della sezione tabellare ""Importi da versare"", non sarà trasferito nella Contabilità di Impresa.
		                    |
		                    |Continuare con la registrazione dei documenti?';
		                    |de = 'Beleg, dessen Vorauszahlungsbetrag im Tabellenabschnitt ""Forderungen""
		                    |nicht dem Vorauszahlungsbetrag des Tabellenabschnitts ""Fällig"" entspricht, wird nicht an die Firmenbuchhaltung übertragen.
		                    |
		                    |Möchten Sie die Dokument-Buchung fortsetzen?'");
			
		Return;
		
	EndIf;

EndProcedure

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val CatalogCounterparty)
	
	Attributes = "DoOperationsByContracts, DoOperationsByOrders";
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, CatalogCounterparty, Attributes);
	
EndProcedure

&AtServer
Function CounterpartyGLAAccountsAreFilled()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Counterparties.Ref AS Ref
	|FROM
	|	Catalog.Counterparties AS Counterparties
	|WHERE
	|	Counterparties.Ref = &Ref
	|	AND (Counterparties.CustomerAdvancesGLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|			OR Counterparties.GLAccountCustomerSettlements = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|			OR Counterparties.GLAccountVendorSettlements = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|			OR Counterparties.VendorAdvancesGLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))";
	
	Query.SetParameter("Ref", Counterparty);
	
	Return Query.Execute().IsEmpty();
	
EndFunction

&AtServer
Procedure CheckingAdvancesAndDebts(Cancel = False)
	
	If OperationKind = Enums.OperationTypesArApAdjustments.CustomerAdvanceClearing Then 
		
		MainQueryText = 
		"SELECT
		|	AccountsReceivableBalance.Document AS Document,
		|	TT_DebitorDocuments.LineNumber AS LineNumber,
		|	TRUE AS IsDebitor,
		|	&Debitor AS TableName,
		|	&Advance AS SettlementType
		|FROM
		|	AccumulationRegister.AccountsReceivable.Balance(
		|			,
		|			Document IN
		|					(SELECT
		|						TT_DebitorDocuments.Document
		|					FROM
		|						TT_DebitorDocuments)
		|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalance
		|		INNER JOIN TT_DebitorDocuments AS TT_DebitorDocuments
		|		ON AccountsReceivableBalance.Document = TT_DebitorDocuments.Document
		|
		|UNION ALL
		|
		|SELECT
		|	AccountsReceivableBalance.Document,
		|	TT_CreditorDocuments.LineNumber,
		|	FALSE,
		|	&Creditor,
		|	&Debt
		|FROM
		|	AccumulationRegister.AccountsReceivable.Balance(
		|			,
		|			Document IN
		|					(SELECT
		|						TT_CreditorDocuments.Document
		|					FROM
		|						TT_CreditorDocuments)
		|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalance
		|		INNER JOIN TT_CreditorDocuments AS TT_CreditorDocuments
		|		ON AccountsReceivableBalance.Document = TT_CreditorDocuments.Document";
		
		
	ElsIf OperationKind = Enums.OperationTypesArApAdjustments.SupplierAdvanceClearing Then
		
		MainQueryText = 
		"SELECT
		|	AccountsReceivableBalance.Document AS Document,
		|	TT_DebitorDocuments.LineNumber AS LineNumber,
		|	TRUE AS IsDebitor,
		|	&Debitor AS TableName,
		|	&Advance AS SettlementType
		|FROM
		|	AccumulationRegister.AccountsPayable.Balance(
		|			,
		|			Document IN
		|					(SELECT
		|						TT_DebitorDocuments.Document
		|					FROM
		|						TT_DebitorDocuments)
		|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalance
		|		INNER JOIN TT_DebitorDocuments AS TT_DebitorDocuments
		|		ON AccountsReceivableBalance.Document = TT_DebitorDocuments.Document
		|
		|UNION ALL
		|
		|SELECT
		|	AccountsReceivableBalance.Document,
		|	TT_CreditorDocuments.LineNumber,
		|	FALSE,
		|	&Creditor,
		|	&Debt
		|FROM
		|	AccumulationRegister.AccountsPayable.Balance(
		|			,
		|			Document IN
		|					(SELECT
		|						TT_CreditorDocuments.Document
		|					FROM
		|						TT_CreditorDocuments)
		|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalance
		|		INNER JOIN TT_CreditorDocuments AS TT_CreditorDocuments
		|		ON AccountsReceivableBalance.Document = TT_CreditorDocuments.Document";
		
	Else
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DebitorDocuments.LineNumber AS LineNumber,
	|	DebitorDocuments.Document AS Document
	|INTO TT_DebitorDocuments
	|FROM
	|	&DebitorDocuments AS DebitorDocuments
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CreditorDocuments.LineNumber AS LineNumber,
	|	CreditorDocuments.Document AS Document
	|INTO TT_CreditorDocuments
	|FROM
	|	&CreditorDocuments AS CreditorDocuments" + DriveClientServer.GetQueryDelimeter() + MainQueryText;
	
	Query.SetParameter("DebitorDocuments", Object.Debitor.Unload(,"LineNumber, Document"));
	Query.SetParameter("CreditorDocuments", Object.Creditor.Unload(,"LineNumber, Document"));
	
	Query.SetParameter("Debitor", NStr("en = 'Debitor'; ru = 'Дебитор';pl = 'Dłużnik';es_ES = 'Deudor';es_CO = 'Deudor';tr = 'Borçlu';it = 'Debitore';de = 'Schuldner'"));
	Query.SetParameter("Creditor", NStr("en = 'Creditor'; ru = 'Кредитор';pl = 'Wierzyciel';es_ES = 'Acreedor';es_CO = 'Acreedor';tr = 'Alacaklı';it = 'Creditore';de = 'Kreditor'"));
	Query.SetParameter("Advance", NStr("en = 'advance'; ru = 'аванс';pl = 'zaliczka';es_ES = 'anticipo';es_CO = 'anticipo';tr = 'avans';it = 'anticipo';de = 'Vorauszahlung'"));
	Query.SetParameter("Debt", NStr("en = 'debt'; ru = 'долг';pl = 'zadłużenie';es_ES = 'deuda';es_CO = 'deuda';tr = 'borç';it = 'debito';de = 'Schuld'"));
	
	For Each Row In Query.Execute().Unload() Do
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'On %1 tab, in line %2, select another document. It must be a document of the %3 type.'; ru = 'На вкладке %1 в строке %2 выберите другой документ. Это должен быть документ типа %3.';pl = 'Na karcie %1, w wierszu %2, wybierz inny dokument. Musi to być dokument typu %3.';es_ES = 'En la pestaña %1, en la línea %2, seleccione otro documento. Debe ser un documento del tipo %3.';es_CO = 'En la pestaña %1, en la línea %2, seleccione otro documento. Debe ser un documento del tipo %3.';tr = '%1 sekmesinin %2 satırında başka bir belge seçin. %3 türünde bir belge olmalıdır.';it = 'Nella scheda %1, riga %2, selezionare un altro documento. Deve essere un documento del tipo %3.';de = 'Auf der Registerkarte %1, in Zeile %2, ein anderes Dokument auswählen. Es muss ein Dokument des %3 Typs sein.'"),
			Row.TableName,
			Row.LineNumber,
			Row.SettlementType);
			
		DataPath = "Object." + ?(Row.IsDebitor, "Debitor", "Creditor") + "[" + (Row.LineNumber - 1) + "].Document";
		CommonClientServer.MessageToUser(MessageText, , , DataPath, Cancel);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure DocumentOnChangeAtServer(StructureData)
	
	If OperationKind = Enums.OperationTypesArApAdjustments.CustomerAdvanceClearing 
		Or OperationKind = Enums.OperationTypesArApAdjustments.SupplierAdvanceClearing Then
		
		CheckingAdvancesAndDebts();
		
	EndIf;
	
	If UseDefaultTypeOfAccounting Then 
		
		ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
		GLAccountsInDocuments.FillCounterpartyGLAccountsInRow(ObjectParameters,
			StructureData,
			StructureData.TabName,
			StructureData.Document);
		
	EndIf;
	
EndProcedure

// Procedure executes fillings of attributes according to the basis document
//
&AtServer
Procedure FillByDocument()
	
	BasisDocument 	= Object.BasisDocument;
	
	// Clear the document data
	Object.Debitor.Clear();
	Object.Creditor.Clear();
	Document = FormAttributeToValue("Object");
	FillPropertyValues(Document, Documents.ArApAdjustments.EmptyRef(), , "Number, Date, OperationKind");
	
	// Fill according to basis document
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	
	Modified = True;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillAccountsReceivable", True);
	ParametersStructure.Insert("FillAccountsPayable", True);
	ParametersStructure.Insert("FillHeader", True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtServer
Procedure CorrespondenceOnChangeServer()
	
	StructureData = New Structure("
		|TabName,
		|Object,
		|Correspondence,
		|IncomeAndExpenseItems,
		|IncomeAndExpenseItemsFilled,
		|IncomeItem,
		|ExpenseItem");
	StructureData.Object = Object;
	StructureData.Correspondence = Object.Correspondence;
	
	StructureData.TabName = "Creditor";
	For Each Row In Object.Creditor Do
		FillPropertyValues(StructureData, Row);
		
		GLAccountsInDocumentsServerCall.CheckItemRegistration(StructureData);
		FillPropertyValues(Row, StructureData);
	EndDo;
	
	StructureData.TabName = "Debitor";
	For Each Row In Object.Debitor Do
		FillPropertyValues(StructureData, Row);
		
		GLAccountsInDocumentsServerCall.CheckItemRegistration(StructureData);
		FillPropertyValues(Row, StructureData);
	EndDo;
	
	GLAccountType = Common.ObjectAttributeValue(Object.Correspondence, "TypeOfAccount");
	
	If GLAccountType = Enums.GLAccountsTypes.OtherExpenses 
		Or GLAccountType = Enums.GLAccountsTypes.Expenses Then
		Object.RegisterExpense = True;
		Object.RegisterIncome = False;
	ElsIf GLAccountType = Enums.GLAccountsTypes.OtherIncome Then
		Object.RegisterExpense = False;
		Object.RegisterIncome = True;
	Else
		Object.RegisterExpense = False;
		Object.RegisterIncome = False;
	EndIf;
	
	SetIncomeAndExpenseItemsVisibility();
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillAccountsReceivable", True);
	ParametersStructure.Insert("FillAccountsPayable", True);
	ParametersStructure.Insert("FillHeader", False);
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtServer
Procedure SetIncomeAndExpenseItemsVisibility()
	
	IsCustomerDebtAdjustment = (Object.OperationKind = Enums.OperationTypesArApAdjustments.CustomerDebtAdjustment);
	IsVendorDebtAdjustment = (Object.OperationKind = Enums.OperationTypesArApAdjustments.VendorDebtAdjustment);
	IsSuitableOperation = IsCustomerDebtAdjustment Or IsVendorDebtAdjustment;
	
	IncomeAndExpenseItemsVisibility = IsSuitableOperation
		And (Not UseDefaultTypeOfAccounting Or GLAccountsInDocuments.IsIncomeAndExpenseGLA(Object.Correspondence));
	
	IncomeAndExpenseItemsInDocuments.SetRegistrationAttributesVisibility(
		ThisObject, 
		"RegisterExpense, RegisterIncome", 
		IsSuitableOperation And Not UseDefaultTypeOfAccounting);
	
	IncomeAndExpenseItemsInDocuments.SetRegistrationAttributesVisibility(
		ThisObject, 
		"DebitorIncomeAndExpenseItems, CreditorIncomeAndExpenseItems", 
		IncomeAndExpenseItemsVisibility);
	
	Items.OperationDescription.Visible = IsSuitableOperation;
	
	If IsSuitableOperation Then
		
		If IsCustomerDebtAdjustment Then
			
			If Object.RegisterExpense Then
				OperationDescription = NStr("en = 'Advances paid will be decreased. Accounts payable will be increased.'; ru = 'Выплаченные авансы будут уменьшены. Кредиторская задолженность будет увеличена.';pl = 'Wypłacone zaliczki zostaną zmniejszone. Zobowiązania zostaną zwiększone.';es_ES = 'Los pagos anticipados disminuirán. Las cuentas por pagar se incrementarán.';es_CO = 'Los pagos anticipados disminuirán. Las cuentas por pagar se incrementarán.';tr = 'Verilen avanslar azalacak. Borç hesapları artacak.';it = 'L''acconto pagato sarà ridotto. Aumenterà il debito.';de = 'Vorauszahlungen bezahlt werden verringert. Offene Posten Kreditoren werden erhöht.'");
			Else
				OperationDescription = NStr("en = 'Advances paid will be increased. Accounts payable will be decreased.'; ru = 'Выплаченные авансы будут увеличены. Кредиторская задолженность будет уменьшена.';pl = 'Wypłacone zaliczki zostaną zwiększone. Zobowiązania zostaną zmniejszone.';es_ES = 'Los pagos anticipados se incrementarán. Las cuentas por pagar disminuirán.';es_CO = 'Los pagos anticipados se incrementarán. Las cuentas por pagar disminuirán.';tr = 'Verilen avanslar artacak. Borç hesapları azalacak.';it = 'L''acconto pagato sarà aumentato. Sarà ridotto il debito.';de = 'Vorauszahlungen bezahlt werden erhöht. Offene Posten Kreditoren werden verringert.'");
			EndIf;
			
		EndIf;
		
		If IsVendorDebtAdjustment Then
			
			If Object.RegisterExpense Then
				OperationDescription = NStr("en = 'Advances received will be increased. Accounts receivable will be decreased.'; ru = 'Полученные авансы будут увеличены. Дебиторская задолженность будет уменьшена.';pl = 'Otrzymane zaliczki zostaną zwiększone. Należności zostaną zmniejszone. ';es_ES = 'Los pagos anticipados se incrementarán. Las cuentas por cobrar disminuirán.';es_CO = 'Los pagos anticipados se incrementarán. Las cuentas por cobrar disminuirán.';tr = 'Alınan avanslar artacak. Alacak hesapları azalacak.';it = 'L''acconto ricevuto sarà aumentato. I crediti saranno ridotti.';de = 'Vorauszahlungen erhalten werden erhöht. Offene Posten Debitoren werden verringert.'");
			Else
				OperationDescription = NStr("en = 'Advances received will be decreased. Accounts receivable will be increased.'; ru = 'Полученные авансы будут уменьшены. Дебиторская задолженность будет увеличена.';pl = 'Otrzymane zaliczki zostaną zmniejszone. Należności zostaną zwiększone. ';es_ES = 'Los pagos anticipados recibidos disminuirán. Las cuentas por cobrar se incrementarán.';es_CO = 'Los pagos anticipados recibidos disminuirán. Las cuentas por cobrar se incrementarán.';tr = 'Alınan avanslar azalacak. Alacak hesapları artacak.';it = 'L''acconto ricevuto sarà ridotto. I crediti saranno ridotti.';de = 'Vorauszahlungen erhalten werden verringert. Offene Posten Debitoren werden erhöht.'");
			EndIf;
			
		EndIf;
		
		Items.OperationDescription.Title = OperationDescription;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion