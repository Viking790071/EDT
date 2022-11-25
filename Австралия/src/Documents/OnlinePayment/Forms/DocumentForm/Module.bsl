#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
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
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	UseForeignCurrency = GetFunctionalOption("ForeignExchangeAccounting");
	Items.PaymentDetailsPaymentAmount.Visible = UseForeignCurrency;
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues);
	
	If Object.PaymentDetails.Count() = 0 Then
		Object.PaymentDetails.Add();
		Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
	EndIf;
	
	If Parameters.Key.IsEmpty() And Not ValueIsFilled(Parameters.CopyingValue) Then
		If ValueIsFilled(Object.Counterparty) And Object.PaymentDetails.Count() > 0 Then
			If Not ValueIsFilled(Object.PaymentDetails[0].Contract) Then
				Object.PaymentDetails[0].Contract = DriveServer.GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
			EndIf;
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	SetAccountingPolicyValues();
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	ExchangeRateMethod = DriveServer.GetExchangeMethod(Object.Company);
	
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.CashCurrency, Object.Company);
	ExchangeRate = ?(StructureByCurrency.Rate = 0, 1, StructureByCurrency.Rate);
	Multiplicity = ?(StructureByCurrency.Rate = 0, 1, StructureByCurrency.Repetition);
	
	WithholdFeeOnPayout = Common.ObjectAttributeValue(Object.POSTerminal, "WithholdFeeOnPayout");
	
	If Not ValueIsFilled(Object.Ref) 
		And Not ValueIsFilled(Parameters.Basis) 
		And Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	EndIf;
	
	SetVisibleOfVATTaxation();
	
	FillDefaultVATRate();
	
	CashCurrency = Object.CashCurrency;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
	ProcessingCompanyVATNumbers();
	
	SetVisibilitySettlementAttributes();
	
	DriveClientServer.SetPictureForComment(Items.GroupPageAdditionalInformation, Object.Comment);
	
	Items.ChargeCardKind.ChoiceList.LoadValues(Catalogs.POSTerminals.PaymentCardKinds(Object.POSTerminal));
	
	SetVisibilityExpenseItem();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	CalculateTotal();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AfterRecordingOfCounterparty" Then
		If ValueIsFilled(Parameter) And Object.Counterparty = Parameter Then
			SetVisibilitySettlementAttributes();
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If GLAccountsInDocumentsClient.IsGLAccountsChoiceProcessing(ChoiceSource.FormName) Then
		
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(Object.PaymentDetails,
			MessageText, Object.Ref, Object.Company, Object.Counterparty, Object.OperationKind, Cancel);
		
		If MessageText <> "" Then
			
			MessageText = ?(Cancel, NStr("en = 'Cannot post the document.'; ru = 'Не удалось провести документ.';pl = 'Nie można zatwierdzić dokumentu.';es_ES = 'No se puede enviar el documento.';es_CO = 'No se puede enviar el documento.';tr = 'Belge kaydedilemiyor.';it = 'Impossibile pubblicare il documento.';de = 'Fehler beim Buchen des Dokuments.'") + Chars.LF + MessageText, MessageText);
			CommonClientServer.MessageToUser(MessageText);
			
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
	
	NotifyAboutOrderPayment = False;
	
	For Each CurRow In Object.PaymentDetails Do
		If ValueIsFilled(CurRow.Order) Then
			NotifyAboutOrderPayment = True;
			Break;
		EndIf;
	EndDo;
	
	If NotifyAboutOrderPayment Then
		Notify("NotificationAboutOrderPayment");
	EndIf;
	
	Notify("NotificationAboutChangingDebt");
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CounterpartyOnChange(Item)
	
	StructureData = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company, Object.Date);
	FillPaymentDetailsByContractData(StructureData);
	
EndProcedure

&AtClient
Procedure POSTerminalOnChange(Item)
	
	ProcessPOSTerminalChange();
	
EndProcedure

&AtClient
Procedure ChargeCardKindOnChange(Item)
	
	ProcessChargeCardKindChange();
	
EndProcedure

&AtClient
Procedure FeePercentOnChange(Item)
	
	CalculateFeeAmount();
	CalculateFeeTotal();
	CalculateTotal();
	
EndProcedure

&AtClient
Procedure FeeAmountOnChange(Item)
	
	CalculateFeeTotal();
	CalculateTotal();
	
	If Object.DocumentAmount > 0 Then
		Object.FeePercent = Object.FeeAmount / Object.DocumentAmount * 100;
	EndIf;
	
EndProcedure

&AtClient
Procedure FeeFixedPartOnChange(Item)
	
	CalculateFeeTotal();
	CalculateTotal();
	
EndProcedure

&AtClient
Procedure DocumentAmountOnChange(Item)
	
	If Object.PaymentDetails.Count() = 1 Then
	 
		TabularSectionRow = Object.PaymentDetails[0];
		
		If TabularSectionRow.PaymentAmount <> Object.DocumentAmount Then
			
			TabularSectionRow.PaymentAmount = Object.DocumentAmount;
			
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
		
	EndIf;
	
	CalculateFeeAmount();
	CalculateFeeTotal();
	CalculateTotal();
	
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	Object.Number = "";
	
	StructureData = GetCompanyDataOnChange();
	
	ParentCompany		= StructureData.ParentCompany;
	ExchangeRateMethod	= StructureData.ExchangeRateMethod;
	
	If ValueIsFilled(Object.Counterparty) Then 
		
		StructureContractData = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company, Object.Date);
		FillPaymentDetailsByContractData(StructureContractData);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure VATTaxationOnChange(Item)
	
	FillVATRateByVATTaxation();
	SetVisibleOfVATTaxation();
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#EndRegion

#Region PaymentDetailsFormTableItemsEventHandlers

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
	
EndProcedure

&AtClient
Procedure PaymentDetailsOnActivateCell(Item)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnActivateCell(ThisObject, "PaymentDetails", ThisIsNewRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsOnStartEdit(Item, NewRow, Clone)
	
	If NewRow And Not Clone Then
		TabularSectionRow = Items.PaymentDetails.CurrentData;
		TabularSectionRow.AdvanceFlag = True;
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
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

&AtClient
Procedure PaymentDetailsContractOnChange(Item)
	
	ProcessCounterpartyContractChange();
	
EndProcedure

&AtClient
Procedure PaymentDetailsContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	ProcessStartChoiceCounterpartyContract(Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure PaymentDetailsAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If TabularSectionRow.AdvanceFlag Then
		TabularSectionRow.Document = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	StructureFilter = New Structure;
	StructureFilter.Insert("Company", Object.Company);
	StructureFilter.Insert("Counterparty", Object.Counterparty);
	If ValueIsFilled(TabularSectionRow.Contract) Then
		StructureFilter.Insert("Contract", TabularSectionRow.Contract);
	EndIf;
	StructureFilter.Insert("AdvanceFlag", TabularSectionRow.AdvanceFlag);
	StructureFilter.Insert("Currency", Object.CashCurrency);
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("Filter", StructureFilter);
	ParameterStructure.Insert("ThisIsAccountsReceivable", True);
	ParameterStructure.Insert("DocumentType", TypeOf(Object.Ref));
	
	OpenForm("CommonForm.SelectDocumentOfSettlements", ParameterStructure, Item);
	
EndProcedure

&AtClient
Procedure PaymentDetailsDocumentChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	ProcessAccountsDocumentSelection(ValueSelected);
	
	Items.PaymentDetails.CurrentItem = Items.PaymentDetailsPaymentAmount;
	
EndProcedure

&AtClient
Procedure PaymentDetailsSettlementsAmountOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculateExchangeRate(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure PaymentDetailsRateOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculateSettlmentsAmount(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure PaymentDetailsRepetitionOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculateSettlmentsAmount(TabularSectionRow);
	
EndProcedure

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
Procedure PaymentDetailsVATRateOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure PaymentDetailsDocumentOnChange(Item)
	
	RunActionsOnAccountsDocumentChange();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		ShowMessageBox(Undefined, NStr("en = 'Please select a base document.'; ru = 'Выберите документ-основание.';pl = 'Wybierz dokument źródłowy.';es_ES = 'Por favor, seleccione un documento base.';es_CO = 'Por favor, seleccione un documento base.';tr = 'Lütfen, temel belge seçin.';it = 'Selezionare un documento di base.';de = 'Bitte wählen Sie ein Basisdokument aus.'"));
		Return;
	EndIf;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), 
		NStr("en = 'The document will be populated with the data from the selected base document. Continue?'; ru = 'Документ будет заполнен данными из выбранного документа-основания. Продолжить?';pl = 'Dokument zostanie wypełniony danymi z wybranego dokumentu źródłowego. Kontynuować?';es_ES = 'El documento se rellenará con los datos del documento base seleccionado. ¿Continuar?';es_CO = 'El documento se rellenará con los datos del documento base seleccionado. ¿Continuar?';tr = 'Belge, seçilen temel belgenin verileriyle doldurulacak. Devam edilsin mi?';it = 'Il documento sarà popolato con i dati dal documento di base selezionato. Continuare?';de = 'Das Dokument wird mit den Daten aus dem ausgewählten Basisdokument automatisch aufgefüllt. Fortfahren?'"), 
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillDetails(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(Undefined, NStr("en = 'Please select a counterparty.'; ru = 'Выберите контрагента.';pl = 'Wybierz kontrahenta.';es_ES = 'Por favor, seleccione una contrapartida.';es_CO = 'Por favor, seleccione una contrapartida.';tr = 'Lütfen, cari hesap seçin.';it = 'Selezionare una controparte.';de = 'Bitte wählen Sie einen Geschäftspartner aus.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.POSTerminal)
		And Not ValueIsFilled(Object.CashCurrency) Then
		ShowMessageBox(Undefined, NStr("en = 'Please select a POS terminal.'; ru = 'Выберите эквайринговый терминал.';pl = 'Wybierz terminal POS.';es_ES = 'Por favor, seleccione un terminal TPV.';es_CO = 'Por favor, seleccione un terminal TPV.';tr = 'Lütfen, POS terminali seçin.';it = 'Selezionare un terminale POS.';de = 'Bitte wählen Sie ein POS-Terminal aus.'"));
		Return;
	EndIf;
	
	ShowQueryBox(New NotifyDescription("FillDetailsEnd", ThisObject), 
		NStr("en = 'Payment details will be repopulated. Continue?'; ru = 'Расшифровка платежа будет перезаполнена. Продолжить?';pl = 'Szczegóły płatności zostaną wypełnione ponownie. Kontynuować?';es_ES = 'Los detalles de pago serán repoblados. ¿Continuar?';es_CO = 'Los detalles de pago serán repoblados. ¿Continuar?';tr = 'Ödeme bilgileri yeniden doldurulacak. Devam edilsin mi?';it = 'I dettagli di pagamento saranno ricompilati. Continuare?';de = 'Zahlungsdetails werden automatisch neu ausgefüllt. Fortfahren?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Object);
	
EndProcedure
// End StandardSubsystems.AttachableCommands

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
	
EndProcedure
// End StandardSubsystems.Properties

#EndRegion

#Region Private

&AtClient
Procedure ProcessPOSTerminalChange()
	
	StructureData = GetPOSTerminalDataOnChange(
		Object.Date,
		Object.POSTerminal,
		Object.Company);
	
	Object.CashCurrency = StructureData.CashCurrency;
	WithholdFeeOnPayout = StructureData.WithholdFeeOnPayout;
	
	If WithholdFeeOnPayout Then
		Object.ExpenseItem = PredefinedValue("Catalog.IncomeAndExpenseItems.EmptyRef");
	Else
		Object.ExpenseItem = StructureData.ExpenseItem;
	EndIf;
	SetVisibilityExpenseItem();
	
	Items.ChargeCardKind.ChoiceList.LoadValues(StructureData.PaymentCardKinds);
	If StructureData.PaymentCardKinds.Find(Object.ChargeCardKind) = Undefined Then
		Object.ChargeCardKind = "";
	EndIf;
	ProcessChargeCardKindChange();
	
	If CashCurrency = Object.CashCurrency Then
		Return;
	EndIf;
	
	CashCurrency = Object.CashCurrency;
	
	RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData);
	
	If ValueIsFilled(Object.Counterparty) Then
		
		StructureContractData = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company, Object.Date);
		FillPaymentDetailsByContractData(StructureContractData);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateFeeAmount()
	
	Object.FeeAmount = Object.DocumentAmount * Object.FeePercent / 100;
	
EndProcedure

&AtClient
Procedure CalculateFeeTotal()
	
	Object.FeeTotal = Object.FeeAmount + Object.FeeFixedPart;
	
EndProcedure

&AtClient
Procedure ProcessChargeCardKindChange()
	
	If Not ValueIsFilled(Object.ChargeCardKind) Then
		Return;
	EndIf;
	
	FeeData = GetFeeData(Object.POSTerminal, Object.ChargeCardKind);
	
	FillPropertyValues(Object, FeeData);
	
	CalculateFeeAmount();
	CalculateFeeTotal();
	CalculateTotal();
	
EndProcedure

&AtServerNoContext
Function GetFeeData(POSTerminal, ChargeCardKind)
	
	Return Catalogs.POSTerminals.GetFeeData(POSTerminal, ChargeCardKind);
	
EndFunction

&AtClient
Procedure FillDetailsEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	Object.PaymentDetails.Clear();
	
	FillAdvancesPaymentDetails();
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		FillByDocument(Object.BasisDocument);
		
		If Object.PaymentDetails.Count() = 0 Then
			Object.PaymentDetails.Add();
			Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		EndIf;
		
		ProcessPOSTerminalChange();
		
		CashCurrency	= Object.CashCurrency;
		DocumentDate	= Object.Date;
		
		CalculateFeeAmount();
		CalculateFeeTotal();
		CalculateTotal();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectionEnd(Result, AdditionalParameters) Export
	
	AddressPaymentDetailsInStorage = AdditionalParameters.AddressPaymentDetailsInStorage;
	
	If Result = DialogReturnCode.OK Then
		
		GetPaymentDetailsFromStorage(AddressPaymentDetailsInStorage);
		For Each RowPaymentDetails In Object.PaymentDetails Do
			CalculatePaymentSUM(RowPaymentDetails);
		EndDo;
		
		If Object.PaymentDetails.Count() = 1 Then
			Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
			CalculateFeeAmount();
			CalculateFeeTotal();
			CalculateTotal();
		EndIf;
		
	EndIf;

EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.GroupPageAdditionalInformation, Object.Comment);
	
EndProcedure

&AtClient
Procedure FillPaymentDetailsByContractData(StructureData)
	
	If Object.PaymentDetails.Count() = 1 Then 
		
		PaymentDetailsRow = Object.PaymentDetails[0];
		If Not ValueIsFilled(PaymentDetailsRow.Contract) Then
			PaymentDetailsRow.Contract = StructureData.Contract;
			PaymentDetailsRow.Item = StructureData.Item;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessCounterpartyContractChange()
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	StructureData = GetStructureDataForObject(ThisObject, "PaymentDetails", TabularSectionRow);
	
	If ValueIsFilled(TabularSectionRow.Contract) Then
		
		StructureData = GetDataPaymentDetailsContractOnChange(
			Object.Date,
			TabularSectionRow.Contract, 
			Object.Company,
			StructureData,
			UseDefaultTypeOfAccounting);
			
		FillPropertyValues(TabularSectionRow, StructureData);
		
	ElsIf UseDefaultTypeOfAccounting Then
		TabularSectionRow.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	EndIf;
	
EndProcedure

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

&AtClient
Procedure RunActionsOnAccountsDocumentChange()
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.SalesInvoice") Then
		
		StructureData = GetStructureDataForObject(ThisObject, "PaymentDetails", TabularSectionRow);
		FillPropertyValues(TabularSectionRow, StructureData);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAdvancesPaymentDetails()
	
	Document = FormAttributeToValue("Object");
	Document.FillAdvancesPaymentDetails();
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True);
	EndIf;
	
	Modified = True;
	
EndProcedure

&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(Val TSPaymentDetails,
	MessageText, Document, Company, Counterparty, OperationKind, Cancel)
	
	If Not DriveReUse.CounterpartyContractsControlNeeded()
		Or Not ValueIsFilled(Counterparty)
		Or Not Common.ObjectAttributeValue(Counterparty, "DoOperationsByContracts") Then
		Return;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	ContractKindsList = ManagerOfCatalog.GetContractTypesListForDocument(Document, OperationKind);
	
	For Each TabularSectionRow In TSPaymentDetails Do
		
		If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText,
				TabularSectionRow.Contract, Company, Counterparty, ContractKindsList)
			And Constants.CheckContractsOnPosting.Get() Then
			
			Cancel = True;
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company, OperationKind)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company, OperationKind);
	
EndFunction

&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
	SetVisibleOfVATTaxation();
	SetVisibilitySettlementAttributes();
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure GetPaymentDetailsFromStorage(AddressPaymentDetailsInStorage)
	
	TableExplanationOfPayment = GetFromTempStorage(AddressPaymentDetailsInStorage);
	
	Object.PaymentDetails.Clear();
	
	For Each RowPaymentDetails In TableExplanationOfPayment Do
		
		NewRow = Object.PaymentDetails.Add();
		FillPropertyValues(NewRow, RowPaymentDetails);
		
		If Not ValueIsFilled(NewRow.VATRate) Then
			VATRateData = DriveServer.DocumentVATRateData(NewRow.Document, DefaultVATRate, False);
			NewRow.VATRate = VATRateData.VATRate;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure RecalculateDocumentAmounts(ExchangeRate, Multiplicity)
	
	For Each TabularSectionRow In Object.PaymentDetails Do
		
		If TabularSectionRow.Contract.SettlementsCurrency = Object.CashCurrency Then
			TabularSectionRow.PaymentAmount = TabularSectionRow.SettlementsAmount;
			Continue;
		EndIf;
		
		TabularSectionRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
			TabularSectionRow.SettlementsAmount,
			ExchangeRateMethod,
			TabularSectionRow.ExchangeRate,
			ExchangeRate,
			TabularSectionRow.Multiplicity,
			Multiplicity);
		
		CalculateVATSUM(TabularSectionRow);
		
	EndDo;
	
	Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
	
EndProcedure

&AtClient
Procedure RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData)
	
	If ValueIsFilled(Object.CashCurrency) Then
		ExchangeRate = ?(StructureData.CurrencyRateRepetition.Rate = 0, 1, StructureData.CurrencyRateRepetition.Rate);
		Multiplicity = ?(StructureData.CurrencyRateRepetition.Repetition = 0, 1, StructureData.CurrencyRateRepetition.Repetition);
	EndIf;
	
	RecalculateDocumentAmounts(ExchangeRate, Multiplicity);
	CalculateFeeAmount();
	CalculateFeeTotal();
	CalculateTotal();
	
EndProcedure

&AtClient
Procedure CalculatePaymentSUM(TabularSectionRow)
	
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
	
	TabularSectionRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.PaymentAmount,
		ExchangeRateMethod,
		ExchangeRate,
		TabularSectionRow.ExchangeRate,
		Multiplicity,
		TabularSectionRow.Multiplicity);
	
EndProcedure

&AtClientAtServerNoContext
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount
		- (TabularSectionRow.PaymentAmount) / ((VATRate + 100) / 100);
	
EndProcedure

&AtServer
Function GetDataCounterpartyOnChange(Counterparty, Company, Date)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company, Object.OperationKind);
	
	StructureData = New Structure;
	
	StructureData.Insert("Contract", ContractByDefault);
	
	ContractData = Common.ObjectAttributesValues(ContractByDefault, "SettlementsCurrency, CashFlowItem");
	
	StructureData.Insert("Item", ContractData.CashFlowItem);
	
	CounterpartyData = Common.ObjectAttributesValues(Counterparty, "DoOperationsByContracts, DoOperationsByOrders");
	
	StructureData.Insert("DoOperationsByContracts",	CounterpartyData.DoOperationsByContracts);
	StructureData.Insert("DoOperationsByOrders",	CounterpartyData.DoOperationsByOrders);
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True);
	EndIf;
	
	SetVisibilitySettlementAttributes();
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetPOSTerminalDataOnChange(Date, POSTerminal, Company)
	
	StructureData = New Structure;
	
	POSTerminalData = Common.ObjectAttributesValues(POSTerminal,
		"WithholdFeeOnPayout, PaymentProcessorContract.SettlementsCurrency, ExpenseItem");
	
	StructureData.Insert("WithholdFeeOnPayout", POSTerminalData.WithholdFeeOnPayout);
	
	CashCurrency = POSTerminalData.PaymentProcessorContractSettlementsCurrency;
	
	StructureData.Insert("CashCurrency", CashCurrency);
	
	StructureData.Insert("CurrencyRateRepetition",
		CurrencyRateOperations.GetCurrencyRate(Date, CashCurrency, Company));
		
	StructureData.Insert("PaymentCardKinds", Catalogs.POSTerminals.PaymentCardKinds(POSTerminal));
	StructureData.Insert("ExpenseItem", POSTerminalData.ExpenseItem);
	
	Return StructureData;
	
EndFunction

&AtClientAtServerNoContext
Function GetStructureDataForObject(Form, TabName, TabRow)
	
	StructureData = New Structure;
	
	StructureData.Insert("TabName", TabName);
	StructureData.Insert("Object", Form.Object);
	
	StructureData.Insert("Contract", TabRow.Contract);
	StructureData.Insert("Document", TabRow.Document);
	
	StructureData.Insert("CounterpartyIncomeAndExpenseItems", True);
	StructureData.Insert("UseDefaultTypeOfAccounting", Form.UseDefaultTypeOfAccounting);
	
	If Form.UseDefaultTypeOfAccounting Then
		
		StructureData.Insert("GLAccounts", TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled", TabRow.GLAccountsFilled);
		StructureData.Insert("CounterpartyGLAccounts", True);
		
		StructureData.Insert("AccountsReceivableGLAccount", TabRow.AccountsReceivableGLAccount);
		StructureData.Insert("AdvancesReceivedGLAccount", TabRow.AdvancesReceivedGLAccount);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

#Region GLAccounts

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	StructureArray = New Array();
	
	StructureData = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters);
	GLAccountsInDocuments.CompleteCounterpartyStructureData(StructureData, ObjectParameters);
	
	StructureArray.Add(StructureData);
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, GetGLAccounts);
	
EndProcedure

#EndRegion

&AtClient
Procedure CalculateTotal()
	
	Total = Object.DocumentAmount + Object.FeeTotal * (1 - WithholdFeeOnPayout);
	
EndProcedure

&AtClient
Procedure CalculateExchangeRate(TablePartRow)
	
	If TablePartRow.SettlementsAmount <> 0 Then
		
		If ExchangeRateMethod = PredefinedValue("Enum.ExchangeRateMethods.Divisor")
			And Multiplicity <> 0 Then 
			
			TablePartRow.ExchangeRate =  TablePartRow.SettlementsAmount / TablePartRow.PaymentAmount
				* ExchangeRate / Multiplicity * TablePartRow.Multiplicity;
			
		ElsIf ExchangeRateMethod = PredefinedValue("Enum.ExchangeRateMethods.Multiplier") Then
			
			TablePartRow.ExchangeRate =  TablePartRow.PaymentAmount / TablePartRow.SettlementsAmount
				* ExchangeRate / Multiplicity * TablePartRow.Multiplicity;
			
		EndIf;
	EndIf;
	
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

&AtServerNoContext
Function GetDataPaymentDetailsContractOnChange(Date, Contract, Company, StructureData, UseDefaultTypeOfAccounting)
	
	If StructureData = Undefined Then
		StructureData = New Structure;
	EndIf;
	
	ContractData = Common.ObjectAttributesValues(Contract, "SettlementsCurrency, CashFlowItem");
	
	StructureData.Insert("SettlementsCurrency", ContractData.SettlementsCurrency);
	StructureData.Insert("Item", ContractData.CashFlowItem);
	
	If StructureData.Property("GLAccounts") And UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillCounterpartyGLAccounts(StructureData);
	EndIf;
	
	Return StructureData;
	
EndFunction

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
	
EndProcedure

&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure;
	
	StructureData.Insert("ParentCompany", DriveServer.GetCompany(Object.Company));
	StructureData.Insert("ExchangeRateMethod", DriveServer.GetExchangeMethod(Object.Company));
	
	SetAccountingPolicyValues();
	
	ProcessingCompanyVATNumbers(False);
	
	FillVATRateByCompanyVATTaxation();
	SetVisibleOfVATTaxation();
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True);
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure DateOnChangeAtServer()
	
	SetAccountingPolicyValues();
	
	ProcessingCompanyVATNumbers();
	
	FillVATRateByCompanyVATTaxation();
	SetVisibleOfVATTaxation();
	
EndProcedure

&AtClient
Procedure Attachable_ProcessDateChange()
	
	DateOnChangeAtServer();
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);
	
EndProcedure

&AtServer
Procedure SetVisibleOfVATTaxation()
	
	VisiblityFlag = (Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT);
	
	Items.PaymentDetailsVATRate.Visible		= VisiblityFlag;
	Items.PaymentDetailsVatAmount.Visible	= VisiblityFlag;
	Items.VATAmount.Visible					= VisiblityFlag;
	Items.VATAmountCurrency.Visible			= VisiblityFlag;
	
	Items.VATTaxation.Visible = RegisteredForVAT;
	
EndProcedure

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

&AtServer
Procedure FillVATRateByVATTaxation(RestoreRatesOfVAT = True)
	
	FillDefaultVATRate();
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		VATRate = DriveReUse.GetVATRateValue(DefaultVATRate);
		
		If RestoreRatesOfVAT Then
			For Each TabularSectionRow In Object.PaymentDetails Do
				TabularSectionRow.VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
				TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount
					- TabularSectionRow.PaymentAmount / ((VATRate + 100) / 100);
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
	
EndProcedure

&AtServer
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	
	Object.VATTaxation = DriveServer.VATTaxation(Object.Company, Object.Date);
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		FillVATRateByVATTaxation();
	Else
		FillDefaultVATRate();
	EndIf;
	
EndProcedure

&AtServer
Procedure SetAccountingPolicyValues()
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Object.Company);
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	
EndProcedure

&AtServer
Procedure SetVisibilityExpenseItem()
	
	Items.ExpenseItem.Visible = ValueIsFilled(Object.POSTerminal) And Not WithholdFeeOnPayout;
	
EndProcedure

// StandardSubsystems.AttachableCommands

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

#Region Initialize

ThisIsNewRow = False;

#EndRegion