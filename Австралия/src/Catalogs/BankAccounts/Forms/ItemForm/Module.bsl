
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FunctionalCurrency = DriveReUse.GetFunctionalCurrency();
	
	If Not ValueIsFilled(Object.CashCurrency) Then
		
		Object.CashCurrency = FunctionalCurrency;
		
	EndIf;
	
	// Fill SWIFT.
	FillBankDetails(SWIFTBank, Object.Bank, Object.Owner);
	
	// Fill SWIFT of correspondent bank.
	FillSWIFT(Object.AccountsBank, SWIFTBankForSettlements);
	
	FormItemsManagement();
	
	If Not ValueIsFilled(Object.AccountType) Then
		Object.AccountType = "Transactional";
	EndIf;
	
	DataSeparationEnabled = False;
	
	AccountType = Object.AccountType;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End of StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);

EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	FillInAccountViewList();
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// If correspondent bank is not used, clear the bank value.
	If Not BankForSettlementsIsUsed
		AND ValueIsFilled(Object.AccountsBank) Then
		
		Object.AccountsBank = Undefined;
		
	EndIf; 
	
	// Fill in the correspondent text.
	If EditCorrespondentText Then
		Object.CorrespondentText = CorrespondentText;
	Else
		Object.CorrespondentText = "";
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AccountsChangedBankAccounts" Then
		Object.GLAccount = Parameter.GLAccount;
		Modified = True;
	ElsIf EventName = "OvedraftsChangedBankAccounts" Then
		SetOverdraftLabelTitle();
	ElsIf EventName = "Record_ConstantsSet" And Source = "UseOverdraft" Then
		SetOverdraftLabelTitle();
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
	If Not GetFunctionalOption("AllowNegativeBalance") Then
		CurrentObject.AllowNegativeBalance = False;
	EndIf;
	
	If Not GetFunctionalOption("UseOverdraft") Then
		CurrentObject.UseOverdraft = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	FormItemsManagement();
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure SWIFTBankOnChange(Item)
	
	FillDescription();
	
	FillInAccountViewList();
	
EndProcedure

&AtClient
Procedure SWIFTBankStartChoice(Item, ChoiceData, StandardProcessing)
	
	OpenBankChoiceForm(True);
	
EndProcedure

&AtClient
Procedure SWIFTBankChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	Object.Bank = ValueSelected;
	FillBankDetails(SWIFTBank, Object.Bank, Object.Owner);
	FillDescription();
	
	If IsBlankString(SWIFTBank) Then
		
		CurrentItem = Items.SWIFTBank;
		
	EndIf;
	
	FillInAccountViewList();
	
EndProcedure

&AtClient
Procedure SWIFTBankTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	#If WebClient Then
		
		If StrLen(Text) > 11 Then
			Message = New UserMessage;
			Message.Text = NStr("en = 'Entered value exceeds the allowed length SWIFT of 11 characters.'; ru = 'Введенное значение превышает допустимую длину SWIFT 11 символов.';pl = 'Wprowadzona wartość przekracza dozwoloną długość SWIFT - 11 znaków.';es_ES = 'Valor introducido excede la longitud permitida del SWIFT de 11 símbolos.';es_CO = 'Valor introducido excede la longitud permitida del SWIFT de 11 símbolos.';tr = 'Girilen değer, izin verilen 11 karakterlik SWIFT uzunluğunu aşıyor.';it = 'Il valore inserito nello SWIFT supera la lunghezza consentita di 11 caratteri.';de = 'Der eingegebene Wert überschreitet die zulässige SWIFT-Länge von 11 Zeichen.'");
			Message.Message();
			
			StandardProcessing = False;
			
			Return;
			
		EndIf;
		
	#EndIf
	
	ListOfFoundBanks = FindBanks(Text, Item.Name, Object.CashCurrency <> FunctionalCurrency);
	If TypeOf(ListOfFoundBanks) = Type("ValueList") Then
		
		If ListOfFoundBanks.Count() = 1 Then
			
			NotifyChanged(Type("CatalogRef.Banks"));
			
			Object.Bank = ListOfFoundBanks[0].Value;
			FillBankDetails(SWIFTBank, Object.Bank, Object.Owner);
			
		ElsIf ListOfFoundBanks.Count() > 1 Then
			
			NotifyChanged(Type("CatalogRef.Banks"));
			
			OpenBankChoiceForm(True, ListOfFoundBanks);
			
		Else
			
			OpenBankChoiceForm(True);
			
		EndIf;
		
	Else
		
		CurrentItem = Item;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SWIFTBankForSettlementsStartChoice(Item, ChoiceData, StandardProcessing)
	
	OpenBankChoiceForm(False);
	
EndProcedure

&AtClient
Procedure SWIFTBankForSettlementsTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	#If WebClient Then
		
		If StrLen(Text) > 11 Then
			Message = New UserMessage;
			Message.Text = NStr("en = 'Entered value exceeds the allowed length SWIFT of 11 characters.'; ru = 'Введенное значение превышает допустимую длину SWIFT 11 символов!';pl = 'Wprowadzona wartość przekracza dozwoloną długość SWIFT - 11 znaków.';es_ES = 'Valor introducido excede la longitud permitida del SWIFT de 11 símbolos.';es_CO = 'Valor introducido excede la longitud permitida del SWIFT de 11 símbolos.';tr = 'Girilen değer, izin verilen 11 karakterlik SWIFT uzunluğunu aşıyor.';it = 'Il valore inserito nello SWIFT supera la lunghezza consentita di 11 caratteri.';de = 'Der eingegebene Wert überschreitet die zulässige SWIFT-Länge von 11 Zeichen.'");
			Message.Message();
			
			StandardProcessing = False;
			
			Return;
			
		EndIf;
		
	#EndIf
	
	ListOfFoundBanks = FindBanks(TrimAll(Text), Item.Name, Object.CashCurrency <> FunctionalCurrency);
	If TypeOf(ListOfFoundBanks) = Type("ValueList") Then
		
		If ListOfFoundBanks.Count() = 1 Then
		
			NotifyChanged(Type("CatalogRef.Banks"));
			
			Object.AccountsBank = ListOfFoundBanks[0].Value;
			FillSWIFT(Object.AccountsBank,  SWIFTBankForSettlements);
			
		ElsIf ListOfFoundBanks.Count() > 1 Then
			
			NotifyChanged(Type("CatalogRef.Banks"));
			
			OpenBankChoiceForm(False, ListOfFoundBanks);
			
		Else
			
			OpenBankChoiceForm(False);
			
		EndIf;
		
	Else
		
		CurrentItem = Item;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SWIFTBankForSettlementsChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	FillSWIFT(ValueSelected, SWIFTBankForSettlements);
	Object.AccountsBank = ValueSelected;
	
	If IsBlankString(SWIFTBankForSettlements) Then
		
		CurrentItem = Items.SWIFTBankForSettlements;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BankForSettlementsIsUsedOnChange(Item)
	
	Items.SWIFTBankForSettlements.Visible		= BankForSettlementsIsUsed;
	Items.BankForSettlements.Visible			= BankForSettlementsIsUsed;
	Items.BankForSettlementsCity.Visible		= BankForSettlementsIsUsed;
	
EndProcedure

&AtClient
Procedure EditPayerTextOnChange(Item)
	
	Items.PayerText.Enabled = EditCorrespondentText;
	
	If Not EditCorrespondentText Then
		FillCorrespondentText();
	EndIf;
	
EndProcedure

&AtClient
Procedure EditPayeeTextOnChange(Item)
	
	Items.PayeeText.Enabled = EditCorrespondentText;
	
	If Not EditCorrespondentText Then
		FillCorrespondentText();
	EndIf;
	
EndProcedure

&AtClient
Procedure AccountNoOnChange(Item)
	
	FillDescription();
	FillInAccountViewList();
	
EndProcedure

&AtClient
Procedure IBANOnChange(Item)
	
	Object.Description = GetAccountDescription(Object.IBAN);
	FillInAccountViewList();
	
EndProcedure

&AtClient
Procedure CashAssetsCurrencyOnChange(Item)
	
	FillInAccountViewList();
	SetOverdraftLabelTitle();
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

&AtClient
Procedure OwnerOnChange(Item)
	
	SetAllowNegativeBalanceVisible();
	SetUseOverdraftVisible();
	
EndProcedure

&AtClient
Procedure AccountTypeOnChange(Item)
	
	If Not Object.Ref.IsEmpty() And Object.AllowNegativeBalance
		And Object.AccountType = "Savings" Then
		
		Result = HasNegativeBalance(Object.Ref);
		
		If Result.HasNegativeBalance Then
			Object.AccountType = AccountType;
			CommonClientServer.MessageToUser(Result.MessageText,, "Object.AllowNegativeBalance");
			Return;
		EndIf;
	EndIf;
	
	AccountType = Object.AccountType;
	
	SetAllowNegativeBalanceVisible();
	
EndProcedure

&AtClient
Procedure AllowNegativeBalanceOnChange(Item)
	
	If Not Object.Ref.IsEmpty() And Not Object.AllowNegativeBalance
		And HasNegativeBalance(Object.Ref) Then
		
		If Not Object.UseOverdraft Then
			Object.AllowNegativeBalance = True;
			MessageText = NStr("en = 'Cannot clear the ""Allow negative balance"" checkbox. A negative balance is already recorded for this bank account.'; ru = 'Не удалось снять флажок ""Разрешить отрицательный остаток"". Отрицательный остаток уже записан на этом банковском счете.';pl = 'Nie można wyczyścić pola wyboru ""Zezwalaj saldo ujemne"". Saldo ujemne jest już zarejestrowane dla tego rachunku bankowego.';es_ES = 'No se puede desmarcar la casilla de verificación ""Permitir un saldo negativo"". Ya se ha registrado un saldo negativo para esta cuenta bancaria.';es_CO = 'No se puede desmarcar la casilla de verificación ""Permitir un saldo negativo"". Ya se ha registrado un saldo negativo para esta cuenta bancaria.';tr = '""Eksi bakiyeye izin ver"" onay kutusu temizlenemiyor. Bu banka hesabı için kayıtlı eksi bakiye mevcut.';it = 'Impossibile deselezionare la casella di controllo ""Permettere saldo negativo"". Un saldo negativo è già registrato per questo conto corrente.';de = 'Das Kontrollkästchen ""Negativen Saldo gestatten"" darf nicht deaktiviert werden. Ein negativer Saldo ist bereit für dieses Bankkonto eingetragen.'");
			CommonClientServer.MessageToUser(MessageText,, "Object.AllowNegativeBalance");
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UseOverdraftOnChange(Item)
	
	If Not Object.Ref.IsEmpty() And Not Object.UseOverdraft
		And Not Object.AllowNegativeBalance And HasNegativeBalance(Object.Ref) Then
		
		Object.UseOverdraft = True;
		MessageText = NStr("en = 'Cannot clear the ""Use overdraft"" checkbox. An overdraft is already recorded for this bank account.'; ru = 'Не удалось снять флажок ""Использовать овердрафт"". Для этого банковского счета уже зарегистрирован овердрафт.';pl = 'Nie można odznaczyć pola wyboru ""Używaj przekroczenia stanu rachunku"". Przekroczenie stanu rachunku już zostało zapisane dla tego rachunku bankowego.';es_ES = 'No se puede desmarcar la casilla de verificación "" Utilizar el sobregiro "". Ya se ha registrado un sobregiro para esta cuenta bancaria.';es_CO = 'No se puede desmarcar la casilla de verificación "" Utilizar el sobregiro "". Ya se ha registrado un sobregiro para esta cuenta bancaria.';tr = '""Fazla para çekme kullan"" onay kutusu temizlenemiyor. Bu banka hesabı için kayıtlı bir fazla para çekme işlemi mevcut.';it = 'Impossibile deselezionare la casella di controllo ""Utilizzare scoperto"". Vi è già uno scoperto registrato per questo conto corrente.';de = 'Fehler beim Deaktivieren des Kontrollkästchen ""Kontoüberziehung verwenden"". Kontoüberziehung ist für dieses Bankkonto bereits eingetragen.'");
		CommonClientServer.MessageToUser(MessageText,, "Object.UseOverdraft");
		
	EndIf;
	
	SetOverdraftLabelTitle();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure FillDescription()
	
	AccountNo = ?(IsBlankString(Object.AccountNo), Object.IBAN, Object.AccountNo);
	
	Object.Description = GetAccountDescription(AccountNo);
	
EndProcedure

// The procedure fills in the SWIFT field value.
//
&AtServerNoContext
Procedure FillSWIFT(Bank, SWIFT)
	
	If Not ValueIsFilled(Bank) Then
		
		Return;
		
	EndIf;
	
	SWIFT	= Bank.Code;
	
EndProcedure

// The procedure fills in the CorrespondentText field value.
//
&AtServer
Procedure FillCorrespondentText()
	
	Query = New Query;
	Query.SetParameter("Ref", Object.Owner);
		
	If TypeOf(Object.Owner) = Type("CatalogRef.Companies") Then
		
		Query.Text =
		"SELECT ALLOWED
		|	Companies.DescriptionFull
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	Companies.Ref = &Ref";
		
	Else
		
		Query.Text =
		"SELECT ALLOWED
		|	Counterparties.DescriptionFull
		|FROM
		|	Catalog.Counterparties AS Counterparties
		|WHERE
		|	Counterparties.Ref = &Ref";
		
	EndIf;
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	If Selection.Next() Then
		CorrespondentText = TrimAll(Selection.DescriptionFull);
	EndIf;
	
EndProcedure

// The procedure opens a form with a list of banks for manual selection.
//
&AtClient
Procedure OpenBankChoiceForm(IsBank, ListOfFoundBanks = Undefined)
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentRow", ?(IsBank, Object.Bank, Object.AccountsBank));
	FormParameters.Insert("ChoiceFoldersAndItemsParameter", FoldersAndItemsUse.Items);
	FormParameters.Insert("CloseOnChoice", True);
	FormParameters.Insert("Multiselect", False);
	
	If ListOfFoundBanks <> Undefined Then
		
		FormParameters.Insert("ListOfFoundBanks", ListOfFoundBanks);
		
	EndIf;
	
	OpenForm("Catalog.Banks.ChoiceForm", FormParameters, ?(IsBank, Items.SWIFTBank, Items.SWIFTBankForSettlements));
	
EndProcedure

&AtServerNoContext
Function GetListOfBanksByAttributes(Val Field, Val Value) Export

	BankList = New ValueList;
	
	If IsBlankString(Value) Then
	
		Return BankList;
		
	EndIf;
	
	BanksTable = Catalogs.Banks.GetBanksTableByAttributes(Field, Value);
	
	BankList.LoadValues(BanksTable.UnloadColumn("Ref"));
	
	Return BankList;
	
EndFunction

&AtClientAtServerNoContext
Function CheckCorrectnessOfSWIFT(SWIFT, ErrorText = "")
	
	If IsBlankString(SWIFT) Then
		
		Return True;
		
	EndIf;
	
	ErrorText = "";
	If StrLen(SWIFT) <> 8 AND StrLen(SWIFT) <> 11 Then
		
		ErrorText = NStr("en = 'Bank is not found by the specified SWIFT. SWIFT might be specified incompletely.'; ru = 'По указанному SWIFT банк не найден. Возможно SWIFT указан не полностью.';pl = 'Nie znaleziono banku na podstawie wprowadzonego SWIFT. Możliwe, że SWIFT został wprowadzony nieprawidłowo.';es_ES = 'Banco no se ha encontrado por el SWIFT especificado. Puede ser que el SWIFT no esté especificado completamente.';es_CO = 'Banco no se ha encontrado por el SWIFT especificado. Puede ser que el SWIFT no esté especificado completamente.';tr = 'Belirtilen SWIFT''e göre bir banka bulunamadı. SWIFT eksik olarak girilmiş olabilir.';it = 'Banca non viene trovato dalla SWIFT specificato. SWIFT potrebbe essere specificato in modo incompleto.';de = 'Bank wird vom angegebenen SWIFT nicht gefunden. SWIFT wird möglicherweise unvollständig angegeben.'");
		
	EndIf;
	
	Return IsBlankString(ErrorText);
	
EndFunction

// The function returns a list of banks that satisfy the search condition
// 
// IN case of failure returns "Undefined" or empty value list.
//
&AtClient
Function FindBanks(TextForSearch, Field, Currency = False)
	
	Var ErrorText;
	
	IsBank = (Field = "SWIFTBank");
	ClearValuesInAssociatedFieldsInForms(IsBank);
	
	If IsBlankString(TextForSearch) Then
		
		ClearMessages();
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The ""%1"" field value is incorrect.'; ru = 'Поле ""%1"" заполнено не корректно.';pl = 'Wartość pola ""%1"" jest niepoprawna.';es_ES = 'El valor del campo ""%1"" es incorrecto.';es_CO = 'El valor del campo ""%1"" es incorrecto.';tr = '""%1"" alan değeri yanlış.';it = 'Il valore del campo ""%1"" non è corretto.';de = 'Das Feld ""%1"" ist nicht korrekt ausgefüllt.'"), 
			"SWIFT"
			);
		
		CommonClientServer.MessageToUser(MessageText,, Field);
		
		Return Undefined;
		
	EndIf;
	
	If Find(Field, "SWIFT") = 1 Then
		
		SearchArea = "Code";
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	ListOfFoundBanks = GetListOfBanksByAttributes(SearchArea, TextForSearch);
	If ListOfFoundBanks.Count() = 0 Then
		
		If SearchArea = "Code" Then
			
			If Not CheckCorrectnessOfSWIFT(TextForSearch, ErrorText) Then
				
				ClearMessages();
				CommonClientServer.MessageToUser(ErrorText,, Field);
				Return Undefined;
				
			EndIf;
			
			QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Bank with SWIFT ""%1"" was not found in the Banks catalog'; ru = 'Банк с SWIFT ""%1"" не найден в справочнике банков';pl = 'Bank z numerem SWIFT ""%1"" nie został znaleziony w katalogu banków';es_ES = 'Banco con el SWIFT ""%1"" no se ha encontrado en el catálogo de Bancos';es_CO = 'Banco con el SWIFT ""%1"" no se ha encontrado en el catálogo de Bancos';tr = 'Bankalar kataloğunda ""%1"" SWIFT''li bir banka bulunamadı';it = 'La banca con SWIFT ""%1"" non è stato trovato nelle anagrafiche Banche';de = 'Bank mit SWIFT ""%1"" wurde im Banken-Katalog nicht gefunden'"), TextForSearch);
			
		EndIf;
		
		// Generate variants
		Buttons	= New ValueList;
		Buttons.Add("Select",     NStr("en = 'Select from the catalog'; ru = 'Выбрать из справочника';pl = 'Wybierz z katalogu';es_ES = 'Seleccionar desde el catálogo';es_CO = 'Seleccionar desde el catálogo';tr = 'Katalogdan seç';it = 'Selezionare dalle anagrafiche';de = 'Wählen Sie aus dem Katalog'"));
		Buttons.Add("Cancel",   NStr("en = 'Cancel entering'; ru = 'Отменить ввод';pl = 'Anuluj wprowadzanie';es_ES = 'Cancelar la introducción';es_CO = 'Cancelar la introducción';tr = 'Girişi iptal et';it = 'Annullare l''immissione';de = 'Eingabe abbrechen'"));
		
		// Choice processor
		NotifyDescription = New NotifyDescription("DetermineIfBankIsToBeSelectedFromCatalog", ThisObject, New Structure("IsBank", IsBank));
		ShowQueryBox(NotifyDescription, QuestionText, Buttons,, "Select", NStr("en = 'Bank is not found'; ru = 'Банк не найден';pl = 'Bank nie został znaleziony';es_ES = 'Banco no se ha encontrado';es_CO = 'Banco no se ha encontrado';tr = 'Banka bulunamadı';it = 'La banca non si trova';de = 'Bank wird nicht gefunden'"));
		Return Undefined;
		
	EndIf;
	
	Return ListOfFoundBanks;
	
EndFunction

// Procedure for managing form controls.
//
&AtServer
Procedure FormItemsManagement()
	
	// Set using the correspondent bank.
	BankForSettlementsIsUsed = ValueIsFilled(Object.AccountsBank);
	
	Items.SWIFTBankForSettlements.Visible		= BankForSettlementsIsUsed;
	Items.BankForSettlements.Visible			= BankForSettlementsIsUsed;
	Items.BankForSettlementsCity .Visible		= BankForSettlementsIsUsed;
	
	Items.Owner.ReadOnly = NOT Object.Ref.IsEmpty() OR ValueIsFilled(Object.Owner);
	
	// Edit company name.
	EditCorrespondentText = ValueIsFilled(Object.CorrespondentText);
	Items.PayerText.Enabled = EditCorrespondentText;
	Items.PayeeText.Enabled = EditCorrespondentText;
	
	If EditCorrespondentText Then
		CorrespondentText = Object.CorrespondentText;
	Else
		FillCorrespondentText();
	EndIf;
	
	// Print settings
	Items.GroupCompanyAccountAttributes.Visible			= (TypeOf(Object.Owner) = Type("CatalogRef.Companies"));
	Items.GroupCounterpartyAccountAttributes.Visible	= Not (TypeOf(Object.Owner) = Type("CatalogRef.Companies"));
	
	SetAllowNegativeBalanceVisible();
	SetUseOverdraftVisible();
	
EndProcedure

// Function generates a bank account description.
//
&AtClient
Procedure FillInAccountViewList()
	
	Items.Description.ChoiceList.Clear();
	
	If NOT IsBlankString(Object.AccountNo) Then
		Items.Description.ChoiceList.Add(GetAccountDescription(Object.AccountNo));
	EndIf;
	
	If NOT IsBlankString(Object.IBAN) Then
		Items.Description.ChoiceList.Add(GetAccountDescription(Object.IBAN));
	EndIf;
	
	DescriptionString = ?(ValueIsFilled(Object.Bank), String(Object.Bank), "") + " (" + String(Object.CashCurrency) + ")";
	DescriptionString = Left(DescriptionString, 100);
	
	Items.Description.ChoiceList.Add(DescriptionString);
	
EndProcedure

&AtClient
Function GetAccountDescription(AccountNo)
	
	Text = AccountNo;
	
	If ValueIsFilled(Object.Bank) Then
		Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1, in %2'; ru = '%1, в %2';pl = '%1, w %2';es_ES = '%1, en %2';es_CO = '%1, en %2';tr = '%1, %2'' te';it = '%1, in %2';de = '%1, in %2'"),
				TrimAll(AccountNo),
				String(Object.Bank));
	EndIf;
			
	Return Left(Text, 100);
	
EndFunction

// The procedure clears the related fields of the form
//
// It is useful if a user opens a selection form and refuses to select a value.
//
&AtClient
Procedure ClearValuesInAssociatedFieldsInForms(IsBank)
	
	If IsBank Then
		
		Object.Bank = Undefined;
		SWIFTBank = "";
		
	Else
		
		Object.AccountsBank = Undefined;
		SWIFTBankForSettlements = "";
		
	EndIf;
	
EndProcedure

// Fills in the bank details and direct exchange settings.
//
&AtServerNoContext
Procedure FillBankDetails(SWIFTBank, Val Bank, Val AccountOwner)

	FillSWIFT(Bank, SWIFTBank);

EndProcedure

&AtServer
Procedure SetAllowNegativeBalanceVisible()
	
	WasItemVisible = Items.AllowNegativeBalance.Visible;
	
	IsCompany = TypeOf(Object.Owner) = Type("CatalogRef.Companies");
	Items.AllowNegativeBalance.Visible = Object.AccountType <> "Savings" And IsCompany;
	
	If WasItemVisible And Not Items.AllowNegativeBalance.Visible Then
		Object.AllowNegativeBalance = False;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function HasNegativeBalance(BankAccount)
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED TOP 1
	|	CashAssetsBalanceAndTurnovers.BankAccountPettyCash AS BankAccountPettyCash
	|FROM
	|	AccumulationRegister.CashAssets.BalanceAndTurnovers(, , Recorder, , BankAccountPettyCash = &BankAccount) AS CashAssetsBalanceAndTurnovers
	|WHERE
	|	CashAssetsBalanceAndTurnovers.AmountCurClosingBalance < 0";
	
	Query.SetParameter("BankAccount", BankAccount);
	
	QueryResult = Query.Execute();
	
	Return Not QueryResult.IsEmpty();
	
EndFunction

&AtServer
Procedure SetUseOverdraftVisible()
	
	Items.UseOverdraft.Visible = (TypeOf(Object.Owner) = Type("CatalogRef.Companies"));
	SetOverdraftLabelTitle();
	
	If Not Items.UseOverdraft.Visible Then
		Object.UseOverdraft = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetOverdraftLabelTitle()
	
	If GetFunctionalOption("UseOverdraft") And Items.UseOverdraft.Visible And Object.UseOverdraft Then
		Items.OverdraftLabel.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Overdraft limit: %1 %2.'; ru = 'Лимит овердрафта: %1 %2.';pl = 'Limit przekroczenia stanu rachunku: %1 %2.';es_ES = 'Límite de sobregiro:%1%2.';es_CO = 'Límite de sobregiro:%1%2.';tr = 'Fazla para çekme limiti: %1 %2.';it = 'Limite scoperto: %1 %2.';de = 'Überziehungsgrenze: %1 %2.'"),
			InformationRegisters.OverdraftLimits.GetCurrentOvedraftLimit(Object.Ref, Object.Owner),
			Object.CashCurrency);
	Else
		Items.OverdraftLabel.Title = "";
	EndIf;
	
EndProcedure

#EndRegion

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the prompt result about selecting the bank from classifier
//
//
Procedure DetermineIfBankIsToBeSelectedFromCatalog(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = "Select" Then
		
		OpenBankChoiceForm(AdditionalParameters.IsBank);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.ObjectAttributesLock

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
EndProcedure

// End StandardSubsystems.ObjectAttributesLock

#EndRegion
