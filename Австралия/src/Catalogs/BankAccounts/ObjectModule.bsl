#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Or TypeOf(FillingData) = Type("CatalogRef.Companies") Then
		
		StandardProcessing = False;
		
		Owner				= FillingData;
		AccountType			= "Transactional";
		MonthOutputOption	= Enums.MonthOutputTypesInDocumentDate.Number;
		CashCurrency		= DriveReUse.GetFunctionalCurrency();
		
	EndIf;
	
	GLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("BankAccount");
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") And TypeOf(Owner) = Type("CatalogRef.Companies") Then
		CheckedAttributes.Add("GLAccount");
	EndIf;
	
	If IsBlankString(IBAN)
		AND IsBlankString(AccountNo) Then
		
		CommonClientServer.MessageToUser(
			NStr("en = 'At least one of the fields must be filled in: IBAN, Account number'; ru = 'Как минимум одно из полей должно быть заполнено: IBAN, Номер счета';pl = 'Co najmniej jedno z pól musi zostać wypełnione: IBAN, numer konta';es_ES = 'Como mínimo uno de los campos tiene que estar rellenado: IBAN, número de cuenta';es_CO = 'Como mínimo uno de los campos tiene que estar rellenado: IBAN, número de cuenta';tr = 'Alanlardan en az biri doldurulmalıdır: IBAN, Hesap numarası';it = 'Almeno uno dei campi deve essere compilato: IBAN, numero di Conto';de = 'Mindestens eines der Felder muss ausgefüllt werden: IBAN, Kontonummer'"),,,,
			Cancel);
		
	EndIf;
	
	If NOT IsBlankString(IBAN) Then
		
		MessageText = "";
		
		If NOT StringFunctionsClientServer.OnlyRomanInString(IBAN,, "0123456789") Then
			MessageText = NStr("en = 'This field can contain only latin letters and numbers.'; ru = 'Это поле может содержать только латинские буквы и числа.';pl = 'To pole może zawierać tylko łacińskie litery i cyfry.';es_ES = 'Este campo puede contener solo letras latinas y números.';es_CO = 'Este campo puede contener solo letras latinas y números.';tr = 'Bu alan yalnızca Latin harfleri ve rakamlar içerebilir.';it = 'Questo campo può contenere solo lettere e numeri latini.';de = 'Dieses Feld darf nur lateinische Buchstaben und Zahlen enthalten.'");
		EndIf;
		
		If StrLen(IBAN) < 12 Then
			
			If NOT IsBlankString(MessageText) Then
				MessageText = MessageText + Chars.LF;
			EndIf;
			
			MessageText = MessageText + NStr("en = 'The minimum length of IBAN is 12 chars.'; ru = 'Минимальная длина IBAN 12 символов.';pl = 'Numer IBAN musi zawierać co najmniej 12 znaków.';es_ES = 'La longitud mínima del IBAN son 12 símbolos.';es_CO = 'La longitud mínima del IBAN son 12 símbolos.';tr = 'IBAN en az 12 karakter içermelidir.';it = 'La lunghezza minima dell''IBAN è di 12 caratteri.';de = 'Die Mindestlänge der IBAN beträgt 12 Zeichen.'");
			
		EndIf;
		
		If NOT StringFunctionsClientServer.OnlyRomanInString(Left(IBAN, 2)) Then
			
			If NOT IsBlankString(MessageText) Then
				MessageText = MessageText + Chars.LF;
			EndIf;
			
			MessageText = MessageText + NStr("en = 'The first two IBAN chars must be latin letters.'; ru = 'Первые 2 символа IBAN должны быть латинскими буквами.';pl = 'Pierwsze dwa znaki IBAN muszą być łacińskimi literami.';es_ES = 'Los primeros dos símbolos del IBAN tienen que ser letras latinas.';es_CO = 'Los primeros dos símbolos del IBAN tienen que ser letras latinas.';tr = 'İlk iki IBAN karakteri Latin harfi olmalıdır.';it = 'I primi due caratteri dell''IBAN devono essere lettere latine.';de = 'Die ersten beiden IBAN-Zeichen müssen lateinische Buchstaben sein.'");
			
		EndIf;
		
		If NOT StringFunctionsClientServer.OnlyNumbersInString(Mid(IBAN, 3, 2)) Then
			
			If NOT IsBlankString(MessageText) Then
				MessageText = MessageText + Chars.LF;
			EndIf;
			
			MessageText = MessageText + NStr("en = 'The third and the fourth IBAN chars must be numbers.'; ru = 'Третий и четвертый символы IBAN должны быть цифрами.';pl = 'Trzeci i czwarty znak IBAN muszą być liczbami.';es_ES = 'El tercer y el cuarto símbolo del IBAN tienen que ser números.';es_CO = 'El tercer y el cuarto símbolo del IBAN tienen que ser números.';tr = 'Üçüncü ve dördüncü IBAN karakterleri rakam olmalıdır.';it = 'Il terzo e il quarto carattere dell''IBAN devono essere numeri.';de = 'Das dritte und vierte IBAN-Zeichen müssen Zahlen sein.'");
			
		EndIf;
		
		If NOT IsBlankString(MessageText) Then
			
			MessageText = NStr("en = 'IBAN is not valid.'; ru = 'IBAN некорректный.';pl = 'Błędny IBAN.';es_ES = 'IBAN no es válido.';es_CO = 'IBAN no es válido.';tr = 'IBAN geçerli değil.';it = 'IBAN non valido.';de = 'IBAN ist nicht gültig.'")
							+ " " + MessageText;
							
			CommonClientServer.MessageToUser(
				MessageText,,
				"IBAN",
				"Object",
				Cancel);
		
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ClearAttributeMainBankAccount();
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	IsCompanyAccount = TypeOf(Owner) = Type("CatalogRef.Companies");
	
EndProcedure

#EndRegion

#Region Private

Procedure GenerateDescription() Export
	
	Description = StrTemplate(
		NStr("en = '%1, in %2'; ru = '%1, в %2';pl = '%1, w %2';es_ES = '%1, en %2';es_CO = '%1, en %2';tr = '%1, %2'' te';it = '%1, in %2';de = '%1, in %2'"),
		TrimAll(AccountNo),
		Bank);
	
EndProcedure

Procedure ClearAttributeMainBankAccount()
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	Counterparties.Ref AS Ref
		|FROM
		|	Catalog.Counterparties AS Counterparties
		|WHERE
		|	Counterparties.BankAccountByDefault = &BankAccount
		|
		|UNION ALL
		|
		|SELECT
		|	Companies.Ref
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	Companies.BankAccountByDefault = &BankAccount";
	
	Query.SetParameter("BankAccount", Ref);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		CatalogObject = Selection.Ref.GetObject();
		CatalogObject.BankAccountByDefault = Undefined;
		CatalogObject.Write();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf