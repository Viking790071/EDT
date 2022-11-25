#Region FormEventHandlers

&AtServer
// Procedure - form event handler "OnCreateAtServer".
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed);

	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		
		Query = New Query(
		"SELECT ALLOWED
		|	CASE
		|		WHEN Companies.BankAccountByDefault.CashCurrency = &CashCurrency
		|			THEN Companies.BankAccountByDefault
		|		ELSE UNDEFINED
		|	END AS BankAccount
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	Companies.Ref = &Company");
		Query.SetParameter("Company", Object.Company);
		Query.SetParameter("CashCurrency", Object.DocumentCurrency);
		QueryResult = Query.Execute();
		Selection = QueryResult.Select();
		If Selection.Next() Then
			Object.BankAccount = Selection.BankAccount;
		EndIf;
		If ValueIsFilled(Parameters.CopyingValue) Then
			Object.PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.NotApproved;
		EndIf;
		
	EndIf;
	FilterForTheMandate = True;
	
	Currency = Object.DocumentCurrency;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	SetVisibleOfMandateTypeOnServer();
		
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
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditionalInformation, Object.Comment);
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
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
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
// Procedure - "AfterWrite" event handler of the forms.
//
Procedure AfterWrite()
	items.GroupMandate.ReadOnly = object.Posted;
	
	Notify();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
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
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
// Procedure - event handler OnChange of the Company input field.
//
Procedure CompanyOnChange(Item)
	
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(
		Object.Company,
		Object.DocumentCurrency,
		Object.BankAccount);
	Object.BankAccount = StructureData.BankAccount;
	
EndProcedure

&AtClient
// Procedure - handler of event OnChange of input field DocumentCurrency.
//
Procedure DocumentCurrencyOnChange(Item)
	
	If Currency <> Object.DocumentCurrency Then
		
		StructureData = GetDataDocumentCurrencyOnChange(
			Object.Company,
			Currency,
			Object.BankAccount,
			Object.DocumentCurrency,
			Object.DocumentAmount,
			Object.Date);
		
		Object.BankAccount = StructureData.BankAccount;
		
		If Object.DocumentAmount <> 0 Then
			Mode = QuestionDialogMode.YesNo;
			Response = Undefined;

			ShowQueryBox(
				New NotifyDescription("DocumentCurrencyOnChangeEnd", 
				ThisObject, 
				New Structure("StructureData", StructureData)), 
				NStr("en = 'Document currency is changed. Recalculate document amount?'; ru = 'Изменилась валюта документа. Пересчитать сумму документа?';pl = 'Waluta dokumentu uległa zmianie. Przeliczyć kwotę dokumentu?';es_ES = 'Moneda del documento se ha cambiado. ¿Recalcular el importe del documento?';es_CO = 'Moneda del documento se ha cambiado. ¿Recalcular el importe del documento?';tr = 'Belge para birimi değiştirildi. Belge tutarı yeniden hesaplansın mı?';it = 'La valuta del documento è cambiata. Ricalcolare gli importi del documento?';de = 'Belegwährung wurde geändert. Dokumentmenge neu berechnen?'"), 
				Mode);
            Return;
		EndIf;
		DocumentCurrencyOnChangeFragment();

		
	EndIf;
	
EndProcedure

&AtClient
Procedure DocumentCurrencyOnChangeEnd(Result, AdditionalParameters) Export
    
    StructureData = AdditionalParameters.StructureData;
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        Object.DocumentAmount = StructureData.Amount;
    EndIf;
    
    DocumentCurrencyOnChangeFragment();

EndProcedure

&AtClient
Procedure DocumentCurrencyOnChangeFragment()
    
    Currency = Object.DocumentCurrency;

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

&AtClient
Procedure MandateOnChange(Item)
	
	If PreviosMandateWasSelectedOnServer(object.Mandate,Object.Ref) Then
		SetVisibleOfMandateTypeOnServer();
		Return;
	EndIf;
	
	StructureData = GetDataMandateOnChange(Object.Mandate);
	
	If Not StructureData.ReadyToUse Then
		Object.Mandate = Undefined;
		MessageText = NStr("en = 'Choose mandate with status Active';ru = 'Выберите мандат со статусом Действует';pl = 'Wybierz polecenie ze statusem Aktywne';es_ES = 'Elija mandato con estado Activo';es_CO = 'Elija mandato con estado Activo';tr = 'Durumu Aktif olan bir talimat seçin';it = 'Selezionare mandato con stato Attivo';de = 'Wählen Sie ein Mandat mit dem Status Aktiv aus'");
		CommonClientServer.MessageToUser(MessageText,,,,false);
		Return;
	EndIf;
	
	If StructureData.ThisIsFinalSequenceType Then
		Object.Mandate = Undefined;
		MessageText = NStr("en = 'The selected Direct debit mandate is invalid. Select another mandate.'; ru = 'Выбранный мандат на прямое дебетование недействителен. Выберите другой мандат.';pl = 'Wybrane zezwolenie na polecenie zapłaty jest nieważne. Wybierz inne zezwolenie.';es_ES = 'La orden del Débito directo seleccionada es inválida. Seleccione otra orden.';es_CO = 'La orden del Débito directo seleccionada es inválida. Seleccione otra orden.';tr = 'Seçilen Düzenli ödeme talimatı geçersiz. Başka bir talimat seçin.';it = 'Il Mandato di addebito diretto selezionato non è valido. Selezionare un altro mandato.';de = 'Das ausgewählte Lastschriftmandat ist ungültig. Wählen Sie ein anderes Lastschriftmandat aus.'");
		CommonClientServer.MessageToUser(MessageText,,,,false);
	ElsIf StructureData.ThisIsOnceType And MandateWasUsed(Object.Mandate,Object.Ref) Then
		Object.Mandate = Undefined;
		MessageText = NStr("en = 'The selected Direct debit mandate is invalid. Select another mandate.'; ru = 'Выбранный мандат на прямое дебетование недействителен. Выберите другой мандат.';pl = 'Wybrane zezwolenie na polecenie zapłaty jest nieważne. Wybierz inne zezwolenie.';es_ES = 'La orden del Débito directo seleccionada es inválida. Seleccione otra orden.';es_CO = 'La orden del Débito directo seleccionada es inválida. Seleccione otra orden.';tr = 'Seçilen Düzenli ödeme talimatı geçersiz. Başka bir talimat seçin.';it = 'Il Mandato di addebito diretto selezionato non è valido. Selezionare un altro mandato.';de = 'Das ausgewählte Lastschriftmandat ist ungültig. Wählen Sie ein anderes Lastschriftmandat aus.'");
		CommonClientServer.MessageToUser(MessageText,,,,false);
	Else
		Object.CounterpartyAccount = StructureData.CounterpartyAccount;
		Object.SequenceType = StructureData.SequenceType;
		
		SetVisibleOfMandateTypeOnServer();
	EndIf;
	
EndProcedure

&AtServer
Procedure SetVisibleOfMandateTypeOnServer()
	If object.Mandate.DirectDebitSequenceType = enums.DirectDebitSequenceTypes.OOFF Then
		items.SequenceType.Visible = False;
	Else
		items.SequenceType.Visible = True;
	EndIf;
	
	items.GroupMandate.ReadOnly = object.Posted;
EndProcedure

// The OnChange event handler of the PaymentDetailsPaymentAmount field.
// It updates the payment currency exchange rate and exchange rate multiplier, and also the VAT amount.
//
&AtClient
Procedure PaymentDetailsPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure

// Procedure - OnChange event handler of PaymentDetailsVATRate input field.
// Calculates VAT amount.
//
&AtClient
Procedure PaymentDetailsVATRateOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure PaymentDetailsOnChange(Item)
	RecalculateDocumentAmountOnServer();
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtServerNoContext
Function PreviosMandateWasSelectedOnServer(Mandate,objRef)
	Return(Mandate = objRef.Mandate);
EndFunction	

&AtServerNoContext
// Get bank account from mandate
Function MandateWasUsed(Mandate,CurrentDoc)

	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	DirectDebit.Ref AS Ref
	|FROM
	|	Document.DirectDebit AS DirectDebit
	|WHERE
	|	DirectDebit.Ref <> &Ref
	|	AND DirectDebit.Posted
	|	AND DirectDebit.Mandate = &Mandate";
	Query.SetParameter("Ref",CurrentDoc);
	Query.SetParameter("Mandate",Mandate);
	
	If NOT Query.Execute().IsEmpty() Then
		Return(True);
	EndIf;
	
	Return(False)
EndFunction

&AtServerNoContext
// Get bank account from mandate
Function GetDataMandateOnChange(Mandate)
	StructureData = New Structure();
	StructureData.Insert("CounterpartyAccount", Mandate.BankAccount);
	StructureData.Insert("SequenceType", Mandate.DirectDebitSequenceType);
	StructureData.Insert("ThisIsFinalSequenceType", Mandate.DirectDebitSequenceType = Enums.DirectDebitSequenceTypes.FNAL);
	StructureData.Insert("ThisIsOnceType", Mandate.DirectDebitSequenceType = Enums.DirectDebitSequenceTypes.OOFF);
	StructureData.Insert("ReadyToUse", Mandate.MandateStatus = Enums.CounterpartyContractStatuses.Active);
	                           
	Return StructureData;
EndFunction

&AtServerNoContext
// Checks compliance of bank account cash assets currency and
// document currency in case of inconsistency, a default bank account (petty cash) is defined.
//
// Parameters:
// Company - CatalogRef.Companies - Document company 
// Currency - CatalogRef.Currencies - Document currency 
// BankAccount - CatalogRef.BankAccounts - Document bank account 
// PettyCash - CatalogRef.CashAccounts - Document petty cash
//
Function GetBankAccount(Company, Currency)
	
	Query = New Query(
	"SELECT
	|	BankAccounts.Ref AS Account,
	|	BankAccounts.Owner AS Company
	|INTO TT_BAcc
	|FROM
	|	Catalog.BankAccounts AS BankAccounts
	|WHERE
	|	BankAccounts.CashCurrency = &CashCurrency
	|	AND BankAccounts.Owner = &Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CASE
	|		WHEN Companies.BankAccountByDefault.CashCurrency = &CashCurrency
	|			THEN Companies.BankAccountByDefault
	|		ELSE ISNULL(BankAccounts.Account, UNDEFINED)
	|	END AS BankAccount
	|FROM
	|	Catalog.Companies AS Companies
	|		LEFT JOIN TT_BAcc AS BankAccounts
	|		ON Companies.Ref = BankAccounts.Company
	|WHERE
	|	Companies.Ref = &Company");
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("CashCurrency", Currency);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	StructureData = New Structure();
	If Selection.Next() Then
		Return Selection.BankAccount;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

&AtServerNoContext
// Checks data with server for procedure CompanyOnChange.
//
Function GetCompanyDataOnChange(Company, Currency, BankAccount)

	StructureData = New Structure();
	StructureData.Insert("BankAccount", GetBankAccount(Company, Currency));
	
	Return StructureData;

EndFunction

&AtServerNoContext
// Checks data with server for procedure DocumentCurrencyOnChange.
//
Function GetDataDocumentCurrencyOnChange(Company, Currency, BankAccount, NewCurrency, DocumentAmount, Date)
	
	StructureData = New Structure();
	StructureData.Insert("BankAccount", GetBankAccount(Company, NewCurrency));
	
	Query = New Query(
	"SELECT ALLOWED
	|	CASE
	|		WHEN ExchangeRate.Repetition <> 0
	|				AND (NOT ExchangeRate.Repetition IS NULL )
	|				AND NewExchangeRate.Rate <> 0
	|				AND (NOT NewExchangeRate.Rate IS NULL )
	|			THEN &DocumentAmount * (ExchangeRate.Rate * NewExchangeRate.Repetition) / (ExchangeRate.Repetition * NewExchangeRate.Rate)
	|		ELSE 0
	|	END AS Amount
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(&Date, Currency = &Currency) AS ExchangeRate
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, Currency = &NewCurrency) AS NewExchangeRate
	|		ON (TRUE)");
	 
	Query.SetParameter("Currency", Currency);
	Query.SetParameter("NewCurrency", NewCurrency);
	Query.SetParameter("DocumentAmount", DocumentAmount);
	Query.SetParameter("Date", Date);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	If Selection.Next() Then
		StructureData.Insert("Amount", Selection.Amount);
	Else
		StructureData.Insert("Amount", 0);
	EndIf;
	
	Return StructureData;
	
EndFunction

// Recalculates amounts by the document tabular section
// currency after changing the bank account or petty cash.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount - (TabularSectionRow.PaymentAmount) / ((VATRate + 100) / 100);
	
EndProcedure

&AtServer
Procedure RecalculateDocumentAmountOnServer()
	Object.DocumentAmount = object.PaymentDetails.Total("PaymentAmount");
EndProcedure	

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
EndProcedure
// End StandardSubsystems.Properties

#EndRegion

#Region Private

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

&AtServer
Function GetDataPaymentDetailsDocumentOnChangeAtServer(Invoice)
	Struc = New Structure;
	Struc.Insert("PaymentAmount",);
	Struc.Insert("VATRate",Catalogs.VATRates.EmptyRef());
	Struc.Insert("VATAmount",0);
	Struc.Insert("PreviousDirectDebit",Undefined);
	
	If Invoice.PriceKind.PriceIncludesVAT Then
		Struc.PaymentAmount = Invoice.Inventory.Total("Amount");
	Else
		Struc.PaymentAmount = Invoice.Inventory.Total("Amount") + Invoice.Inventory.Total("VATAmount");
	EndIf;
	Struc.VATAmount = Invoice.Inventory.Total("VATAmount");
	If(Invoice.Inventory.Count() > 0) Then
		Struc.VATRate = Invoice.Inventory[0].VATRate;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	DirectDebitPaymentDetails.Ref AS Ref
	|FROM
	|	Document.DirectDebit.PaymentDetails AS DirectDebitPaymentDetails
	|WHERE
	|	DirectDebitPaymentDetails.Document = &Document";
	Query.SetParameter("Document",Invoice);
	sel = Query.Execute().Select();
	If sel.Next() Then
		Struc.PreviousDirectDebit = sel.ref;
	EndIf;
	
	Return(Struc);
	
EndFunction

&AtClient
Procedure PaymentDetailsDocumentOnChange(Item)
	CurLine = Items.PaymentDetails.CurrentData;
	StructureFromInvoice = GetDataPaymentDetailsDocumentOnChangeAtServer(CurLine.Document);
	CurLine.PaymentAmount = StructureFromInvoice.PaymentAmount;
	CurLine.VATRate = StructureFromInvoice.VATRate;
	CurLine.VATAmount = StructureFromInvoice.VATAmount;
	Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
	If ValueIsFilled(StructureFromInvoice.PreviousDirectDebit) Then                                                                                                                                               
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'There is another Direct debit with selected invoice %1'; ru = 'С инвойсом %1 уже связано другое прямое дебетование';pl = 'Jest inne Polecenie zapłaty z wybraną fakturą %1';es_ES = 'Hay otro débito directo con la factura seleccionada %1';es_CO = 'Hay otro débito directo con la factura seleccionada %1';tr = 'Seçilen %1 faturasını içeren başka bir Düzenli ödeme var';it = 'Vi è un altro Addebito diretto con la fattura selezionata %1';de = 'Es gibt eine andere direkte Lastschrift mit der ausgewählten Rechnung%1'"),
						StructureFromInvoice.PreviousDirectDebit);
		CommonClientServer.MessageToUser(MessageText,,,,false);
	EndIf;
EndProcedure

&AtClient
Procedure PaymentDetailsDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	StructureFilter = New Structure();
	StructureFilter.Insert("Company",		Object.Company);
	StructureFilter.Insert("Counterparty",	Object.Counterparty);

	ThisIsAccountsReceivable = True;

	If ValueIsFilled(TabularSectionRow.Contract) Then
		StructureFilter.Insert("Contract", TabularSectionRow.Contract);
	EndIf;
	
	If FilterForTheMandate Then
		StructureFilter.Insert("DirectDebitMandate", object.Mandate);
	EndIf;

	ParameterStructure = New Structure("Filter, ThisIsAccountsReceivable, DocumentType",
		StructureFilter,
		ThisIsAccountsReceivable,
		TypeOf(Object.Ref));

	OpenForm("CommonForm.SelectDocumentOfSettlements", ParameterStructure, Item);

EndProcedure

&AtClient
Procedure PaymentDetailsDocumentChoiceProcessing(Item, SelectedValue, StandardProcessing)
	StandardProcessing = False;
	
	ProcessAccountsDocumentSelection(SelectedValue);
	
	PaymentDetailsDocumentOnChange(Item);
EndProcedure

// Procedure fills in the PaymentDetails TS string with the billing document data.
//
&AtClient
Procedure ProcessAccountsDocumentSelection(DocumentData)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	If TypeOf(DocumentData) = Type("Structure") Then
		
		TabularSectionRow.Document = DocumentData.Document;
		
		If Not ValueIsFilled(TabularSectionRow.Contract) Then
			TabularSectionRow.Contract = DocumentData.Contract;
		EndIf;
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetContractFieldFilterOnServer()
	CompanyLink = New ChoiceParameterLink("Filter.Company", "Object.Company",LinkedValueChangeMode.Clear);
	CounterpartyLink = New ChoiceParameterLink("Filter.Owner", "Object.Counterparty",LinkedValueChangeMode.Clear);
	MandateLink = New ChoiceParameterLink("Filter.DirectDebitMandate", "Object.Mandate",LinkedValueChangeMode.Clear);
	
	Arr = New Array;
	Arr.Add(CompanyLink);
	Arr.Add(CounterpartyLink);
	
	If FilterForTheMandate Then
		Arr.Add(MandateLink);
	EndIf;
	
	items.PaymentDetailsContract.ChoiceParameterLinks = New FixedArray(Arr);
EndProcedure

&AtClient
Procedure FilterAllocationWithMandateOnChange(Item)
	SetContractFieldFilterOnServer();
EndProcedure

&AtClient
Procedure MandateStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	
	Par = New Structure("FilterActiveMandatesOnly,FilterMandateActiveDate,FilterCompany",True,Object.Date,Object.Company);
	Notif = New NotifyDescription("AfterMandateStartChoiceProceed",ThisForm);
	OpenForm("Catalog.DirectDebitMandates.ChoiceForm",Par,ThisForm,True,,,Notif);
EndProcedure

&AtClient
Procedure AfterMandateStartChoiceProceed(res,ext) export
	object.Mandate = res;
	MandateOnChange(Undefined);
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	Notification = New NotifyDescription("CommentEndEntering", ThisObject);
	CommonClient.ShowMultilineTextEditingForm(Notification, Items.Comment.EditText, NStr("en = 'Note'; ru = 'Примечание';pl = 'Uwagi';es_ES = 'Nota';es_CO = 'Nota';tr = 'Not';it = 'Nota';de = 'Hinweis'"));

EndProcedure

#EndRegion

&AtClient
Procedure CommentEndEntering(CommentText, AdditionalParameters) Export
	
	If CommentText = Undefined Then
		Return;
	EndIf;
	
	Object.Comment = CommentText;
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditionalInformation, Object.Comment);
	
EndProcedure

#EndRegion

