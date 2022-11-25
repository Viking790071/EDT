#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If UsersClientServer.IsExternalUserSession() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
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
	
	If UsersClientServer.IsExternalUserSession() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	UseForeignCurrency = GetFunctionalOption("ForeignExchangeAccounting");
	Items.PaymentDetailsPaymentAmount.Visible = UseForeignCurrency;
	
	SetConditionalAppearance();
	
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
	SetVisibilityEPDAttributes();
	
	DriveClientServer.SetPictureForComment(Items.GroupPageAdditionalInformation, Object.Comment);
	
	WorkWithVAT.SetTextAboutAdvancePaymentInvoiceIssued(ThisForm);
	
	SetTaxInvoiceText();
	Items.TaxInvoiceText.Enabled = WorkWithVAT.IsTaxInvoiceAccessRightEdit();
	
	EarlyPaymentDiscountsServer.SetTextAboutCreditNote(ThisObject, Object.Ref);
	SetVisibilityCreditNoteText();
	
	Items.ChargeCardKind.ChoiceList.LoadValues(Catalogs.POSTerminals.PaymentCardKinds(Object.POSTerminal));
	
	DriveServer.CheckObjectGeneratedEnteringBalances(ThisObject);
	
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
			SetVisibilityEPDAttributes();
		EndIf;
		
	ElsIf EventName = "RefreshTaxInvoiceText" 
		And TypeOf(Parameter) = Type("Structure") 
		And Not Parameter.BasisDocuments.Find(Object.Ref) = Undefined Then
		
		TaxInvoiceText = Parameter.Presentation;
		
	ElsIf EventName = "RefreshCreditNoteText" Then
		
		If TypeOf(Parameter.Ref) = Type("DocumentRef.CreditNote")
			And Parameter.BasisDocument = Object.Ref Then
			
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

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "Document.TaxInvoiceIssued.Form.DocumentForm" Then
		
		TaxInvoiceText = SelectedValue;
		
	ElsIf GLAccountsInDocumentsClient.IsGLAccountsChoiceProcessing(ChoiceSource.FormName) Then
		
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
			
			MessageText = ?(Cancel, NStr("en = 'Cannot post the document.'; ru = 'Не удалось провести документ.';pl = 'Nie można zatwierdzić dokumentu.';es_ES = 'No se puede enviar el documento.';es_CO = 'No se puede enviar el documento.';tr = 'Belge kaydedilemiyor.';it = 'Impossibile pubblicare il documento.';de = 'Das Dokument kann nicht gebucht werden.'") + Chars.LF + MessageText, MessageText);
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
Procedure PaymentStatusOnChange(Item)
	
	If Object.PaymentStatus = PredefinedValue("Enum.PaymentStatuses.Declined") Then
		If TaxInvoiceCreated(Object.Ref) Then
			CommonClientServer.MessageToUser(
				NStr("en = 'Cannot change the Payment status. Advance payment invoice is already registered for the Online receipt.'; ru = 'Не удалось изменить статус платежа. Инвойс на аванс уже зарегистрирован для этого онлайн-чека.';pl = 'Nie można zmienić statusu płatności. Faktura zaliczkowa jest już zarejestrowana dla Paragonu online.';es_ES = 'No se puede cambiar el estado del pago. La factura de pago adelantado ya está registrada para el Recibo en línea.';es_CO = 'No se puede cambiar el estado del pago. La factura de pago adelantado ya está registrada para el Recibo en línea.';tr = 'Ödeme durumu değiştirilemiyor. Çevrimiçi tahsilat için kayıtlı Avans ödeme faturası var.';it = 'Impossibile modificare lo stato di Pagamento. La fattura del pagamento anticipato è già registrata per la Ricevuta online.';de = 'Der Zahlungsstatus kann nicht geändert werden. Die Vorauszahlungsrechnung ist bereits für den Onlinebeleg registriert.'"));
			Object.PaymentStatus = PredefinedValue("Enum.PaymentStatuses.Succeeded");
			Return;
		EndIf;
		If GetSubordinateCreditNote(Object.Ref) <> Undefined Then
			CommonClientServer.MessageToUser(
				NStr("en = 'Cannot change the Payment status. Credit note is already registered for the Online receipt.'; ru = 'Не удалось изменить статус платежа. Кредитовое авизо уже зарегистрировано для этого онлайн-чека.';pl = 'Nie można zmienić statusu płatności. Nota kredytowa jest już zarejestrowana dla Paragonu online.';es_ES = 'No se puede cambiar el estado del pago. La nota de crédito ya está registrada para el Recibo en línea.';es_CO = 'No se puede cambiar el estado del pago. La nota de crédito ya está registrada para el Recibo en línea.';tr = 'Ödeme durumu değiştirilemiyor. Çevrimiçi tahsilat için kayıtlı Alacak dekontu var.';it = 'Impossibile modificare lo stato del Pagamento. La Nota di credito è già registrata per la Ricevuta online.';de = 'Der Zahlungsstatus kann nicht geändert werden. Die Gutschrift ist bereits für den Onlinebeleg registriert.'"));
			Object.PaymentStatus = PredefinedValue("Enum.PaymentStatuses.Succeeded");
			Return;
		EndIf;
	EndIf;
	
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
Procedure TaxInvoiceTextClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	If Object.PaymentStatus = PredefinedValue("Enum.PaymentStatuses.Declined") Then
		CommonClientServer.MessageToUser(
			NStr("en = 'Cannot create Advance payment invoice for this Online receipt. Its Payment status is Declined.'; ru = 'Не удалось сформировать инвойс на аванс для этого онлайн-чека. Статус платежа – отклонен.';pl = 'Nie można utworzyć faktury zaliczkowej dla tego paragonu online. Cannot create Advance payment invoice for this Online receipt. Ta płatność ma status Odrzucona.';es_ES = 'No se puede crear una factura de pago adelantado para este Recibo en línea. Su estado del pago es Rechazado.';es_CO = 'No se puede crear una factura de pago adelantado para este Recibo en línea. Su estado del pago es Rechazado.';tr = 'Bu Çevrimiçi tahsilat için Avans ödeme faturası oluşturulamıyor. Ödeme durumu ""Reddedildi"".';it = 'Impossibile creare fattura di Pagamento anticipato per questa Ricevuta online. Il suo stato di Pagamento è Rifiutata.';de = 'Die Vorauszahlungsrechnung für diesen Onlinebeleg kann nicht erstellt werden. Deren Zahlungsstatus ist Abgelehnt.'"));
		Return;
	EndIf;
	
	ParametersFilter = New Structure("AdvanceFlag", True);
	AdvanceArray = Object.PaymentDetails.FindRows(ParametersFilter);
	If AdvanceArray.Count() > 0 Then
		WorkWithVATClient.OpenTaxInvoice(ThisForm, False, True);
	Else
		CommonClientServer.MessageToUser(
			NStr("en = 'The Payment details tab does not include lines with advance payments.'; ru = 'На вкладке ""Расшифровка платежа"" нет строк с авансовыми платежами.';pl = 'Karta Szczegóły płatności nie zawiera wierszy z zaliczkami.';es_ES = 'La pestaña de Detalles de pago no incluye las líneas con pagos adelantados.';es_CO = 'La pestaña de Detalles de pago no incluye las líneas con pagos adelantados.';tr = 'Ödeme bilgileri sekmesi, avans ödeme olan satır içermiyor.';it = 'La scheda dei Dettagli di pagamento non include righe con pagamenti anticipati.';de = 'Die Registerkarte Zahlungsdetails enthält keine Zeilen mit Vorauszahlungen.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure CreditNoteTextClick(Item, StandardProcessing)
	
	StandardProcessing	= False;
	IsError				= False;
	
	If Not ValueIsFilled(Object.Ref) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Please save the document.'; ru = 'Сохраните документ.';pl = 'Zapisz dokument.';es_ES = 'Por favor, guardar el documento.';es_CO = 'Por favor, guardar el documento.';tr = 'Lütfen, belgeyi kaydedin.';it = 'Salvare il documento.';de = 'Bitte speichern Sie das Dokument.'"));
		
		IsError = True;
		
	ElsIf Object.PaymentStatus = PredefinedValue("Enum.PaymentStatuses.Declined") Then
		CommonClientServer.MessageToUser(
			NStr("en = 'Cannot create Credit note for this Online receipt. Its Payment status is Declined.'; ru = 'Не удалось сформировать кредитовое авизо для этого онлайн-чека. Статус платежа – отклонен.';pl = 'Nie można utworzyć Noty kredytowej dla tego paragonu online. Ta płatność ma status Odrzucona.';es_ES = 'No se puede crear una Nota de crédito para este Recibo en línea. Su estado del pago es Rechazado.';es_CO = 'No se puede crear una Nota de crédito para este Recibo en línea. Su estado del pago es Rechazado.';tr = 'Bu Çevrimiçi tahsilat için Alacak dekontu oluşturulamıyor. Ödeme durumu ""Reddedildi"".';it = 'Impossibile creare una Nota di credito per questa Ricevuta online. Il suo stato di Pagamento è Rifiutata.';de = 'Die Gutschrift für diesen Onlinebeleg kann nicht erstellt werden. Deren Zahlungsstatus ist Abgelehnt.'"));
		IsError = True;
		
	ElsIf CheckBeforeCreditNoteFilling(Object.Ref) Then
		
		IsError = True;
		
	EndIf;
	
	If Not IsError Then
		
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
	
	If TabularSectionRow.AdvanceFlag Then
		
		ShowMessageBox(Undefined, NStr("en = 'This field is for a billing document. 
			|It is not required for an advance payment. 
			|In this case, a billing document is this Online receipt.'; 
			|ru = 'Это поле предназначено для платежного документа. 
			|Оно не требуется для авансового платежа. 
			|В данном случае документом расчета является онлайн-чек.';
			|pl = 'To pole jest dla dokumentu rozliczeniowego. 
			|Nie jest wymagane ono dla zaliczki. 
			|W tym przypadku, dokument rozliczeniowy jest tym Paragonem online.';
			|es_ES = 'Este campo es para un documento de facturación.
			|No es necesario para un pago adelantado.
			|En este caso, un documento de facturación es este Recibo en línea.';
			|es_CO = 'Este campo es para un documento de facturación.
			|No es necesario para un pago adelantado.
			|En este caso, un documento de facturación es este Recibo en línea.';
			|tr = 'Bu alan, fatura belgesi içindir. 
			|Avans ödeme için gerekli değildir. 
			|Bu durumda fatura belgesi bu Çevrimiçi tahsilattır.';
			|it = 'Questo campo è per un documento di fatturazione. 
			|Non è richiesto per un pagamento anticipato. 
			|In questo caso, un documento di fatturazione è questa Ricevuta online.';
			|de = 'Dieses Feld ist für einen Abrechnungsbeleg. 
			|Es ist nicht für eine Vorauszahlung erforderlich. 
			|In diesem Fall ist ein Abrechnungsbeleg dieser Onlinebeleg.'"));
		
	Else
		
		StructureFilter = New Structure;
		StructureFilter.Insert("Company", Object.Company);
		
		StructureFilter.Insert("Counterparty", Object.Counterparty);
		
		If ValueIsFilled(TabularSectionRow.Contract) Then
			StructureFilter.Insert("Contract", TabularSectionRow.Contract);
		EndIf;
		
		ParameterStructure = New Structure;
		ParameterStructure.Insert("Filter", StructureFilter);
		ParameterStructure.Insert("ThisIsAccountsReceivable", True);
		ParameterStructure.Insert("DocumentType", TypeOf(Object.Ref));
		
		OpenForm("CommonForm.SelectDocumentOfSettlements", ParameterStructure, Item);
		
	EndIf;
	
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
	CalculateSettlmentsEPDAmount(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure PaymentDetailsRepetitionOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculateSettlmentsAmount(TabularSectionRow);
	CalculateSettlmentsEPDAmount(TabularSectionRow);
	
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
Procedure PaymentDetailsEPDAmountOnChange(Item)
	
	CurrentData = Items.PaymentDetails.CurrentData;
	CalculateSettlmentsEPDAmount(CurrentData);
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsAfterDeleteRow(Item)
	
	SetVisibilityCreditNoteText();
	
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
Procedure Pick(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(Undefined, NStr("en = 'Please select a counterparty.'; ru = 'Выберите контрагента.';pl = 'Wybierz kontrahenta.';es_ES = 'Por favor, seleccione una contrapartida.';es_CO = 'Por favor, seleccione una contrapartida.';tr = 'Lütfen, cari hesap seçin.';it = 'Selezionare una controparte.';de = 'Bitte wählen Sie einen Geschäftspartner aus.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.BankAccount)
		And Not ValueIsFilled(Object.POSTerminal) Then
		ShowMessageBox(Undefined, NStr("en = 'Please select a POS terminal.'; ru = 'Выберите эквайринговый терминал.';pl = 'Wybierz terminal POS.';es_ES = 'Por favor, seleccione un terminal TPV.';es_CO = 'Por favor, seleccione un terminal TPV.';tr = 'Lütfen, POS terminali seçin.';it = 'Selezionare un terminale POS.';de = 'Bitte wählen Sie ein POS-Terminal aus.'"));
		Return;
	EndIf;
	
	AddressPaymentDetailsInStorage = PlacePaymentDetailsToStorage();
	
	SelectionParameters = New Structure;
	SelectionParameters.Insert("AddressPaymentDetailsInStorage", AddressPaymentDetailsInStorage);
	SelectionParameters.Insert("ParentCompany", ParentCompany);
	SelectionParameters.Insert("Date", Object.Date);
	SelectionParameters.Insert("Counterparty", Object.Counterparty);
	SelectionParameters.Insert("Ref", Object.Ref);
	SelectionParameters.Insert("OperationKind", Object.OperationKind);
	SelectionParameters.Insert("CashCurrency", Object.CashCurrency);
	SelectionParameters.Insert("DocumentAmount", Object.DocumentAmount);
	
	NotifyDescription = New NotifyDescription("SelectionEnd",
		ThisObject, New Structure("AddressPaymentDetailsInStorage", AddressPaymentDetailsInStorage));
	
	OpenForm("CommonForm.SelectInvoicesToBePaidByTheCustomer", SelectionParameters, , , , , NotifyDescription);
	
EndProcedure

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
	
	If Object.DocumentAmount = 0 Then
		ShowMessageBox(Undefined, NStr("en = 'Please specify the amount.'; ru = 'Введите сумму.';pl = 'Podaj wartość.';es_ES = 'Por favor, especifique el importe.';es_CO = 'Por favor, especifique el importe.';tr = 'Lütfen, tutarı belirtin.';it = 'Specificare l''importo.';de = 'Bitte geben Sie den Betrag an.'"));
		Return;
	EndIf;
	
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

&AtServerNoContext
Function TaxInvoiceCreated(Ref)
	
	Return ValueIsFilled(Ref) And WorkWithVAT.GetSubordinateTaxInvoice(Ref, False, True) <> Undefined;
	
EndFunction

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
	
	FillPaymentDetails();
	
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
		
		DefinePaymentDetailsExistsEPD();
		
		If Object.PaymentDetails.Count() = 1 Then
			Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
			CalculateFeeAmount();
			CalculateFeeTotal();
			CalculateTotal();
		EndIf;
		
		SetVisibilityCreditNoteText();
		
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
		SetExistsEPD(StructureData);
		FillPropertyValues(TabularSectionRow, StructureData);
		
	EndIf;
	
	SetVisibilityCreditNoteText();
	
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

&AtServer
Procedure FillPaymentDetails()
	
	Document = FormAttributeToValue("Object");
	Document.FillPaymentDetails(WorkWithVAT.GetVATAmountFromBasisDocument(Object));
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True);
	EndIf;
	
	SetVisibilityCreditNoteText();
	
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

&AtServerNoContext
Function GetSubordinateCreditNote(BasisDocument)
	
	Return EarlyPaymentDiscountsServer.GetSubordinateCreditNote(BasisDocument);
	
EndFunction

&AtServerNoContext
Function CheckBeforeCreditNoteFilling(BasisDocument)
	
	Return EarlyPaymentDiscountsServer.CheckBeforeCreditNoteFilling(BasisDocument, False);
	
EndFunction

&AtServer
Function SetVisibilityCreditNoteText()
	
	DocumentsTable			= Object.PaymentDetails.Unload(, "Document");
	PaymentDetailsDocuments	= DocumentsTable.UnloadColumn("Document");
	
	Items.CreditNoteText.Visible = EarlyPaymentDiscountsServer.AvailableCreditNoteEPD(PaymentDetailsDocuments);
	
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
	SetVisibilityEPDAttributes();
	
	Modified = True;
	
EndProcedure

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
Procedure DefinePaymentDetailsExistsEPD()
	
	DefinePaymentDetailsExistsEPDAtServer();
	
EndProcedure

&AtServer
Procedure DefinePaymentDetailsExistsEPDAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.DefinePaymentDetailsExistsEPD();
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True);
	EndIf;
	
	Modified = True;
	
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

&AtClient
Procedure CalculateSettlmentsEPDAmount(TabularSectionRow)
	
	TabularSectionRow.SettlementsEPDAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.EPDAmount,
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
	SetVisibilityEPDAttributes();
	
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
	StructureData.Insert("ExistsEPD", TabRow.ExistsEPD);
	StructureData.Insert("EPDAmount", TabRow.EPDAmount);
	
	StructureData.Insert("CounterpartyIncomeAndExpenseItems", True);
	StructureData.Insert("UseDefaultTypeOfAccounting", Form.UseDefaultTypeOfAccounting);
	
	If Form.UseDefaultTypeOfAccounting Then
		
		StructureData.Insert("GLAccounts", TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled", TabRow.GLAccountsFilled);
		StructureData.Insert("CounterpartyGLAccounts", True);
		
		StructureData.Insert("AccountsReceivableGLAccount", TabRow.AccountsReceivableGLAccount);
		StructureData.Insert("AdvancesReceivedGLAccount", TabRow.AdvancesReceivedGLAccount);
		StructureData.Insert("DiscountAllowedGLAccount", TabRow.DiscountAllowedGLAccount);
		StructureData.Insert("VATOutputGLAccount", TabRow.VATOutputGLAccount);
		
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
	
	Total = Object.DocumentAmount - Object.FeeTotal * (1 - WithholdFeeOnPayout);
	
EndProcedure

&AtClient
Procedure CalculateExchangeRate(TablePartRow)
	
	If TablePartRow.SettlementsAmount <> 0 Then
		
		If ExchangeRateMethod = PredefinedValue("Enum.ExchangeRateMethods.Divisor")
			And Multiplicity <> 0 Then 
			
			TablePartRow.ExchangeRate = TablePartRow.SettlementsAmount / TablePartRow.PaymentAmount
				* ExchangeRate / Multiplicity * TablePartRow.Multiplicity;
			
		ElsIf ExchangeRateMethod = PredefinedValue("Enum.ExchangeRateMethods.Multiplier") Then
			
			TablePartRow.ExchangeRate = TablePartRow.PaymentAmount / TablePartRow.SettlementsAmount
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
Procedure SetConditionalAppearance()
	
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
Procedure SetVisibilityEPDAttributes()
	
	VisibleFlag = ValueIsFilled(Object.Counterparty);
	
	Items.PaymentDetailsEPDAmount.Visible				= VisibleFlag;
	Items.PaymentDetailsSettlementsEPDAmount.Visible	= VisibleFlag;
	Items.PaymentDetailsExistsEPD.Visible				= VisibleFlag;
	
EndProcedure

&AtServer
Procedure SetTaxInvoiceText()
	
	Items.TaxInvoiceText.Visible = Not WorkWithVAT.GetPostAdvancePaymentsBySourceDocuments(Object.Date, Object.Company);
	
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
	
	SetTaxInvoiceText();
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure DateOnChangeAtServer()
	
	SetAccountingPolicyValues();
	
	ProcessingCompanyVATNumbers();
	
	FillVATRateByCompanyVATTaxation();
	SetVisibleOfVATTaxation();
	SetTaxInvoiceText();
	
EndProcedure

&AtClient
Procedure Attachable_ProcessDateChange()
	
	DateOnChangeAtServer();
	
	DefinePaymentDetailsExistsEPD();
	
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