
#Region FormEventHandlers

&AtServer
// Procedure - form event handler "OnCreateAtServer".
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues);
	
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
		Query.SetParameter("CashCurrency", Object.CashCurrency);
		QueryResult = Query.Execute();
		Selection = QueryResult.Select();
		If Selection.Next() Then
			If Not ValueIsFilled(Object.BankAccount) Then
				Object.BankAccount = Selection.BankAccount;
			EndIf;
		EndIf;
		If Not ValueIsFilled(Object.BankAccountPayee) Then
			Object.BankAccountPayee = Object.BankAccount;
		EndIf;
		
		If Not ValueIsFilled(Object.PettyCash) Then
			Object.PettyCash = Catalogs.CashAccounts.GetPettyCashByDefault(Object.Company);
		EndIf;
		If Not ValueIsFilled(Object.PettyCashPayee) Then
			Object.PettyCashPayee = Object.PettyCash;
		EndIf;
	EndIf;
	
	Currency = Object.CashCurrency;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	SetVisiblePaymentMethod();
	SetVisiblePaymentMethodPayee();
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
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
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
// Procedure - "AfterWrite" event handler of the forms.
//
Procedure AfterWrite()

	Notify();
	Notify("RefreshAccountingTransaction");

EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
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
		Object.CashCurrency,
		Object.BankAccount
	);
	Object.BankAccount = StructureData.BankAccount;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field CashAssetsCurrency.
//
Procedure CashAssetsCurrencyOnChange(Item)
	
	If Currency <> Object.CashCurrency Then
		
		StructureData = GetDataCashAssetsCurrencyOnChange(
			Object.Company,
			Currency,
			Object.BankAccount,
			Object.CashCurrency,
			Object.DocumentAmount,
			Object.Date);
		
		Object.BankAccount = StructureData.BankAccount;
		
		If Object.DocumentAmount <> 0 Then
			Mode = QuestionDialogMode.YesNo;
			Response = Undefined;

			ShowQueryBox(New NotifyDescription("CashAssetsCurrencyOnChangeEnd", ThisObject, New Structure("StructureData", StructureData)), NStr("en = 'Document currency is changed. Recalculate document amount?'; ru = 'Изменилась валюта документа. Пересчитать сумму документа?';pl = 'Waluta dokumentu uległa zmianie. Przeliczyć kwotę dokumentu?';es_ES = 'Moneda del documento se ha cambiado. ¿Recalcular el importe del documento?';es_CO = 'Moneda del documento se ha cambiado. ¿Recalcular el importe del documento?';tr = 'Belge para birimi değiştirildi. Belge tutarı yeniden hesaplansın mı?';it = 'La valuta del documento è cambiata. Ricalcolare gli importi del documento?';de = 'Belegwährung wurde geändert. Dokumentmenge neu berechnen?'"), Mode);
            Return;
		EndIf;
		CashAssetsCurrencyOnChangeFragment();

		
	EndIf;
	
EndProcedure

&AtClient
Procedure CashAssetsCurrencyOnChangeEnd(Result, AdditionalParameters) Export
    
    StructureData = AdditionalParameters.StructureData;
    
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        Object.DocumentAmount = StructureData.Amount;
    EndIf;
    
    CashAssetsCurrencyOnChangeFragment();

EndProcedure

&AtClient
Procedure CashAssetsCurrencyOnChangeFragment()
    
    Currency = Object.CashCurrency;

EndProcedure

&AtClient
Procedure PaymentMethodOnChange(Item)
	Object.CashAssetType = PaymentMethodCashAssetType(Object.PaymentMethod);
	SetVisiblePaymentMethod();
EndProcedure

&AtClient
Procedure PaymentMethodPayeeOnChange(Item)
	
	Object.CashAssetTypePayee= PaymentMethodCashAssetType(Object.PaymentMethodPayee);	
	SetVisiblePaymentMethodPayee();
	
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

// Procedure - OnChange event handler of the PettyCash input field.
//
&AtClient
Procedure PettyCashOnChange(Item)
	
	SetAccountingCurrencyOnPettyCashChange(Object.PettyCash);
	
EndProcedure

// Procedure - event handler OnChange input field PettyCashPayee.
//
&AtClient
Procedure CashPayeeOnChange(Item)
	
	SetAccountingCurrencyOnPettyCashChange(Object.PettyCashPayee);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

// Procedure sets the currency default.
//
&AtClient
Procedure SetAccountingCurrencyOnPettyCashChange(PettyCash)
	
	Object.CashCurrency = ?(
		ValueIsFilled(Object.CashCurrency),
		Object.CashCurrency,
		GetPettyCashAccountingCurrencyAtServer(PettyCash)
	);
	
EndProcedure

// Procedure receives the default petty cash currency.
//
&AtServerNoContext
Function GetPettyCashAccountingCurrencyAtServer(PettyCash)
	
	Return PettyCash.CurrencyByDefault;
	
EndFunction

// Procedure - handler of clicking the button "Fill in by basis".
//
&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		ShowMessageBox(Undefined,NStr("en = 'Please select a base document.'; ru = 'Не выбран документ-основание.';pl = 'Wybierz dokument źródłowy.';es_ES = 'Por favor, seleccione un documento de base.';es_CO = 'Por favor, seleccione un documento de base.';tr = 'Lütfen, temel belge seçin.';it = 'Si prega di selezionare un documento di base.';de = 'Bitte wählen Sie ein Basisdokument aus.'"));
		Return;
	EndIf;
	
	If TypeOf(Object.BasisDocument) = Type("DocumentRef.CashTransferPlan")
		AND Not DocumentApproved(Object.BasisDocument) Then
		Raise NStr("en = 'Please select an approved cash transfer plan.'; ru = 'Нельзя ввести перемещение денег на основании неутвержденного планового документа.';pl = 'Wybierz zatwierdzony plan przelewów gotówkowych.';es_ES = 'Por favor, seleccione un plan de traslado de efectivo aprobado.';es_CO = 'Por favor, seleccione un plan de traslado de efectivo aprobado.';tr = 'Lütfen onaylı nakit transfer planını seçin.';it = 'Si prega di selezionare un piano di trasferimento contanti approvato.';de = 'Bitte wählen Sie einen genehmigten Überweisungsplan aus.'");
	EndIf;
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), NStr("en = 'Do you want to refill the cash transfer?'; ru = 'Документ будет полностью перезаполнен по ""Основанию"". Продолжить?';pl = 'Czy chcesz uzupełnić przelew gotówkowy?';es_ES = '¿Quiere volver a rellenar la transferencia de efectivo?';es_CO = '¿Quiere volver a rellenar la transferencia de efectivo?';tr = 'Nakit transferini yeniden doldurmak istiyor musunuz?';it = 'Volete ricompilare il trasferimento di denaro?';de = 'Möchten Sie die Überweisung auffüllen?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		
		FillByDocument(Object.BasisDocument);
		
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
	
	If Not ValueIsFilled(Object.Ref) Then
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
		Query.SetParameter("CashCurrency", Object.CashCurrency);
		QueryResult = Query.Execute();
		Selection = QueryResult.Select();
		If Selection.Next() Then
			If Not ValueIsFilled(Object.BankAccount) Then
				Object.BankAccount = Selection.BankAccount;
			EndIf;
		EndIf;
		If Not ValueIsFilled(Object.BankAccountPayee) Then
			Object.BankAccountPayee = Object.BankAccount;
		EndIf;
		If Not ValueIsFilled(Object.PettyCash) Then
			Object.PettyCash = Catalogs.CashAccounts.GetPettyCashByDefault(Object.Company);
		EndIf;
		If Not ValueIsFilled(Object.PettyCashPayee) Then
			Object.PettyCashPayee = Object.PettyCash;
		EndIf;
	EndIf;
	
	Currency = Object.CashCurrency;
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	SetVisiblePaymentMethod();
	SetVisiblePaymentMethodPayee();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtServerNoContext
// Checks compliance of bank account cash assets currency and
// document currency in case of inconsistency, a default bank account (petty cash) is defined.
//
// Parameters:
// Company - CatalogRef.Companies - Document company 
// Currency - CatalogRef.Currencies - Document currency 
// BankAccount - CatalogRef.BankAccounts - Document bank account 
// Petty cash - CatalogRef.CashAccounts - Document petty cash
//
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

&AtServerNoContext
// Checks data with server for procedure CompanyOnChange.
//
Function GetCompanyDataOnChange(Company, Currency, BankAccount)

	StructureData = New Structure();
	StructureData.Insert("BankAccount", GetBankAccount(Company, Currency));
	
	Return StructureData;

EndFunction

&AtServerNoContext
// Checks data with server for procedure CashAssetsCurrencyOnChange.
//
Function GetDataCashAssetsCurrencyOnChange(Company, Currency, BankAccount, NewCurrency, DocumentAmount, Date)
	
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
	Query.SetParameter("NewCurrency", NewCurrency);
	Query.SetParameter("Company", Company);
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

// Checks whether document is approved or not.
//
&AtServerNoContext
Function DocumentApproved(BasisDocument)
	
	Return BasisDocument.PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.Approved;
	
EndFunction

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

&AtServer
Procedure SetVisiblePaymentMethodPayee()
	
	If Object.CashAssetTypePayee = Enums.CashAssetTypes.Noncash Then
		Items.BankAccountPayee.Enabled 	= True;
		Items.BankAccountPayee.Visible 	= True;
		Items.PettyCashPayee.Visible 	= False;
		Object.PettyCashPayee 			= Undefined;
	ElsIf Object.CashAssetTypePayee = Enums.CashAssetTypes.Cash Then
		Items.PettyCashPayee.Enabled 	= True;
		Items.PettyCashPayee.Visible 	= True;
		Items.BankAccountPayee.Visible 	= False;
		Object.BankAccountPayee			= Undefined;
	Else
		Items.BankAccountPayee.Enabled 	= False;
		Items.PettyCashPayee.Enabled 	= False;
		Object.PettyCashPayee 			= Undefined;
		Object.BankAccountPayee			= Undefined;
	EndIf;
	
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

#EndRegion

#EndRegion
