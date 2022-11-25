
#Region FormEventHandlers

// Procedure - form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
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
		Object.PettyCash = Catalogs.CashAccounts.GetPettyCashByDefault(Object.Company);
		If ValueIsFilled(Parameters.CopyingValue) Then
			Object.PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.NotApproved;
		EndIf;
	EndIf;
	
	Currency = Object.DocumentCurrency;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	SetVisiblePaymentMethod();
	
	// Setting contract visible.
	SetContractVisible();
	
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

// Procedure - event handler BeforeWriteAtServer.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
// Procedure - "AfterWrite" event handler of the forms.
//
Procedure AfterWrite()
	
	Notify();
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AfterRecordingOfCounterparty" Then
		If ValueIsFilled(Parameter)
		   AND Object.Counterparty = Parameter Then
			SetContractVisible();
		EndIf;
	EndIf;
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

// Procedure - FillCheckProcessingAtServer event handler of the form.
//
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

#EndRegion

#Region FormHeaderItemsEventHandlers

// Procedure - event handler OnChange of the Company input field.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(
		Object.Company,
		Object.DocumentCurrency,
		Object.BankAccount
	);
	Object.BankAccount = StructureData.BankAccount;
	
EndProcedure

// Procedure - handler of event OnChange of input field DocumentCurrency.
//
&AtClient
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

			ShowQueryBox(New NotifyDescription("DocumentCurrencyOnChangeEnd", ThisObject, New Structure("StructureData", StructureData)), NStr("en = 'Document currency is changed. Recalculate document amount?'; ru = 'Изменилась валюта документа. Пересчитать сумму документа?';pl = 'Waluta dokumentu uległa zmianie. Przeliczyć kwotę dokumentu?';es_ES = 'Moneda del documento se ha cambiado. ¿Recalcular el importe del documento?';es_CO = 'Moneda del documento se ha cambiado. ¿Recalcular el importe del documento?';tr = 'Belge para birimi değiştirildi. Belge tutarı yeniden hesaplansın mı?';it = 'La valuta del documento è cambiata. Ricalcolare gli importi del documento?';de = 'Belegwährung wurde geändert. Dokumentmenge neu berechnen?'"), Mode);
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

&AtClient
Procedure PaymentMethodOnChange(Item)
	Object.CashAssetType = PaymentMethodCashAssetType(Object.PaymentMethod);
	SetVisiblePaymentMethod();
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

// Procedure - event handler OnChange of the Counterparty input field.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	StructureData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
	Object.Contract = StructureData.Contract;
	
EndProcedure

// Procedure - OnChange event handler of the PettyCash input field.
//
&AtClient
Procedure PettyCashOnChange(Item)
	
	Object.DocumentCurrency = ?(
		ValueIsFilled(Object.DocumentCurrency),
		Object.DocumentCurrency,
		GetPettyCashAccountingCurrencyAtServer(Object.PettyCash)
	);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

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

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
// The procedure is called while clicking the "FillInByBase" button of the command panel
//
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		MessagesToUserClient.ShowMessageSelectBaseDocument();
		Return;
	EndIf;
	
	QuestionText = NStr("en = 'Do you want to refill the Payment request?'; ru = 'Документ будет полностью перезаполнен по заявке на расходование средств. Продолжить?';pl = 'Czy chcesz uzupełnić Wezwanie do zapłaty?';es_ES = '¿Quiere volver a rellenar la solicitud de Pago?';es_CO = '¿Quiere volver a rellenar la solicitud de Pago?';tr = 'Ödeme talebini yeniden doldurmak istiyor musunuz?';it = 'Ricompilare la Richiesta di pagamento?';de = 'Möchten Sie die Zahlungsaufforderung neu auffüllen?'");
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
		QuestionText,
		QuestionDialogMode.YesNo);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetVisiblePaymentMethod()
	
	If Object.CashAssetType = Enums.CashAssetTypes.Noncash Then
		Items.BankAccount.Enabled	= True;
		Items.BankAccount.Visible 	= True;
		Items.PettyCash.Visible		= False;
		Object.PettyCash 			= Undefined;
	ElsIf Object.CashAssetType = Enums.CashAssetTypes.Cash Then
		Items.PettyCash.Enabled		= True;
		Items.PettyCash.Visible 	= True;
		Items.BankAccount.Visible 	= False;
		Object.BankAccount 			= Undefined;
	Else
		Items.BankAccount.Enabled	= False;
		Items.PettyCash.Enabled		= False;
		Object.PettyCash 			= Undefined;
		Object.BankAccount 			= Undefined;
	EndIf;

EndProcedure

&AtServerNoContext
Function PaymentMethodCashAssetType(PaymentMethod)
	
	Return Common.ObjectAttributeValue(PaymentMethod, "CashAssetType");
	
EndFunction

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		FillByDocument(Object.BasisDocument);
	EndIf;
	
EndProcedure

&AtServer
// Procedure calls the data processor for document filling by basis.
//
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	SetVisiblePaymentMethod();
	SetContractVisible();
	
EndProcedure

// Checks compliance of bank account cash assets currency and
// document currency in case of inconsistency, a default bank account (petty cash) is defined.
//
// Parameters:
// Company - CatalogRef.Companies - Document
// company Currency - CatalogRef.Currencies - Document
// currency BankAccount - CatalogRef.BankAccounts - Bank document
// account Petty cash - CatalogRef.CashAccounts - Document petty cash
//
&AtServerNoContext
Function GetBankAccount(Company, Currency)
	
	Query = New Query(
	"SELECT ALLOWED
	|	CASE
	|		WHEN Companies.BankAccountByDefault.CashCurrency = &CashCurrency
	|			THEN Companies.BankAccountByDefault
	|		WHEN (NOT BankAccounts.BankAccount IS NULL )
	|			THEN BankAccounts.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccount
	|FROM
	|	Catalog.Companies AS Companies
	|		LEFT JOIN (SELECT
	|			BankAccounts.Ref AS BankAccount
	|		FROM
	|			Catalog.BankAccounts AS BankAccounts
	|		WHERE
	|			BankAccounts.CashCurrency = &CashCurrency
	|			AND BankAccounts.Owner = &Company) AS BankAccounts
	|		ON (TRUE)
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

// Checks data with server for procedure CompanyOnChange.
//
&AtServerNoContext
Function GetCompanyDataOnChange(Company, Currency, BankAccount)
	
	StructureData = New Structure();
	StructureData.Insert("BankAccount", GetBankAccount(Company, Currency));
	
	Return StructureData;

EndFunction

// Checks data with server for procedure DocumentCurrencyOnChange.
//
&AtServerNoContext
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
	|			THEN &DocumentAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN ExchangeRate.Rate * NewExchangeRate.Repetition / (ExchangeRate.Repetition * NewExchangeRate.Rate)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (ExchangeRate.Rate * NewExchangeRate.Repetition / (ExchangeRate.Repetition * NewExchangeRate.Rate))
	|				END
	|		ELSE 0
	|	END AS Amount
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(&Date, Currency = &Currency AND Company = &Company) AS ExchangeRate
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, Currency = &NewCurrency AND Company = &Company) AS NewExchangeRate
	|		ON (TRUE)");
	 
	Query.SetParameter("Currency", Currency);
	Query.SetParameter("Company", Company);
	Query.SetParameter("NewCurrency", NewCurrency);
	Query.SetParameter("DocumentAmount", DocumentAmount);
	Query.SetParameter("Date", Date);
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(Company));
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	If Selection.Next() Then
		StructureData.Insert("Amount", Selection.Amount);
	Else
		StructureData.Insert("Amount", 0);
	EndIf;
	
	Return StructureData;

EndFunction

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	If ValueIsFilled(ContractByDefault) Then
		SettlementsCurrency = Common.ObjectAttributeValue(ContractByDefault, "SettlementsCurrency");
	Else
		SettlementsCurrency = Catalogs.Currencies.EmptyRef();
	EndIf;
	
	StructureData = New Structure;
	StructureData.Insert("Contract",			ContractByDefault);
	StructureData.Insert("SettlementsCurrency",	SettlementsCurrency);
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction

// Gets the default contract depending on the billing details.
//
&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company);
	
EndFunction

// Procedure sets the contract visible depending on the parameter set to the counterparty.
//
&AtServer
Procedure SetContractVisible()
	
	Items.Contract.Visible = Object.Counterparty.DoOperationsByContracts;
	
EndProcedure

// Procedure receives the default petty cash currency.
//
&AtServerNoContext
Function GetPettyCashAccountingCurrencyAtServer(PettyCash)
	
	Return PettyCash.CurrencyByDefault;
	
EndFunction

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

#EndRegion