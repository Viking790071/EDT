#Region Public

// Checks the TIN compliance with the requirements.
//
// Parameters:
//  TIN - String - a taxpayer identification number to be checked.
//  IsLegalEntity - Boolean - a flag showing whether the TIN owner is a legal entity.
//  MessageText - String - text of a message about found errors.
//
// Returns:
//  Boolean - True if it matches.
//
Function TINMeetsRequirements(Val TIN, IsLegalEntity, MessageText) Export

	MeetsRequirements = True;
	MessageText = "";

	TIN      = TrimAll(TIN);
	TINLength = StrLen(TIN);

	If IsLegalEntity = Undefined Then
		MessageText = MessageText + NStr("ru = 'Не определен тип владельца ИНН.'; en = 'Undefined type of TIN owner.'; pl = 'Nie został zdefiniowany typ właściciela NIP.';es_ES = 'No se ha determinado el tipo del propietario de NIF.';es_CO = 'No se ha determinado el tipo del propietario de NIF.';tr = 'VKN sahibinin türü belirlenemedi.';it = 'Tipo non definito di proprietario cod.fiscale.';de = 'Der Typ des UID-Besitzers ist nicht definiert.'");
		Return False;
	EndIf;
	
	If NOT StringFunctionsClientServer.OnlyNumbersInString(TIN) Then
		MeetsRequirements = False;
		MessageText = MessageText + NStr("ru = 'ИНН должен состоять только из цифр.'; en = 'The TIN must contain only numbers.'; pl = 'NIP musi składać się tylko z cyfr';es_ES = 'El NIF tiene que contener solo dígitos.';es_CO = 'El NIF tiene que contener solo dígitos.';tr = 'VKN yalnızca rakamlardan oluşmalıdır.';it = 'Il cod.fiscale deve contenere solo cifre.';de = 'Die UID sollte nur aus Zahlen bestehen.'");
	EndIf;

	If  IsLegalEntity AND TINLength <> 10 Then
		MeetsRequirements = False;
		MessageText = MessageText + ?(ValueIsFilled(MessageText), Chars.LF, "")
			+ NStr("ru = 'ИНН юридического лица должен состоять из 10 цифр.'; en = 'The TIN of a business must contain 10 numbers.'; pl = 'NIP osoby prawnej musi składać się z 10 cyfr';es_ES = 'El NIF de la persona jurídica debe contener 10 dígitos.';es_CO = 'El NIF de la persona jurídica debe contener 10 dígitos.';tr = 'Tüzel kişinin VKN''sı 10 rakamdan oluşmalıdır.';it = 'Il cod.fiscale aziendale deve contenere 10 cifre.';de = 'Die UID einer juristischen Person sollte aus 10 Ziffern bestehen.'");
	ElsIf NOT IsLegalEntity AND TINLength <> 12 Then
		MeetsRequirements = False;
		MessageText = MessageText + ?(ValueIsFilled(MessageText), Chars.LF, "")
			+ NStr("ru = 'ИНН физического лица должен состоять из 12 цифр.'; en = 'The TIN of an individual must contain 12 numbers.'; pl = 'NIP osoby fizycznej musi składać się z 12 cyfr.';es_ES = 'El NIF de la persona física debe contener 12 dígitos.';es_CO = 'El NIF de la persona física debe contener 12 dígitos.';tr = 'Gerçek kişinin VKN''sı 12 rakamdan oluşmalıdır.';it = 'Cod.Fiscale Individuale di un individuo deve essere composto da 12 cifre.';de = 'Die Steuernummer einer natürlichen Person sollte aus 12 Ziffern bestehen.'");
	EndIf;

	If MeetsRequirements Then

		If IsLegalEntity Then

			Checksum = 0;

			For Index = 1 To 9 Do

				If Index = 1 Then
					Multiplier = 2;
				ElsIf Index = 2 Then
					Multiplier = 4;
				ElsIf Index = 3 Then
					Multiplier = 10;
				ElsIf Index = 4 Then
					Multiplier = 3;
				ElsIf Index = 5 Then
					Multiplier = 5;
				ElsIf Index = 6 Then
					Multiplier = 9;
				ElsIf Index = 7 Then
					Multiplier = 4;
				ElsIf Index = 8 Then
					Multiplier = 6;
				ElsIf Index = 9 Then
					Multiplier = 8;
				EndIf;

				Figure = Number(Mid(TIN, Index, 1));
				Checksum = Checksum + Figure * Multiplier;

			EndDo;
			
			CheckDigit = (Checksum %11) %10;

			If CheckDigit <> Number(Mid(TIN, 10, 1)) Then
				MeetsRequirements = False;
				MessageText = MessageText + ?(ValueIsFilled(MessageText), Chars.LF, "")
				               + NStr("ru = 'Контрольное число для ИНН не совпадает с рассчитанным.'; en = 'The TIN hash does not match the calculated value.'; pl = 'Numer kontrolny dla NIP nie jest zgodny z wyliczonym.';es_ES = 'El número de control para el NIF no coincide con el calculado.';es_CO = 'El número de control para el NIF no coincide con el calculado.';tr = 'VKN için kontrol rakam hesaplanmış rakamla uyumlu değil.';it = 'Il hash del cod.fiscale non corrisponde al valore calcolato.';de = 'Die Kontrollnummer für die UID stimmt nicht mit der berechneten überein.'");
			EndIf;

		Else

			CheckSum11 = 0;
			CheckSum12 = 0;

			For Index = 1 To 11 Do

				// Multiplier calculation for the 11th and 12th digits.
				If Index = 1 Then
					Multiplier11 = 7;
					Multiplier12 = 3;
				ElsIf Index = 2 Then
					Multiplier11 = 2;
					Multiplier12 = 7;
				ElsIf Index = 3 Then
					Multiplier11 = 4;
					Multiplier12 = 2;
				ElsIf Index = 4 Then
					Multiplier11 = 10;
					Multiplier12 = 4;
				ElsIf Index = 5 Then
					Multiplier11 = 3;
					Multiplier12 = 10;
				ElsIf Index = 6 Then
					Multiplier11 = 5;
					Multiplier12 = 3;
				ElsIf Index = 7 Then
					Multiplier11 = 9;
					Multiplier12 = 5;
				ElsIf Index = 8 Then
					Multiplier11 = 4;
					Multiplier12 = 9;
				ElsIf Index = 9 Then
					Multiplier11 = 6;
					Multiplier12 = 4;
				ElsIf Index = 10 Then
					Multiplier11 = 8;
					Multiplier12 = 6;
				ElsIf Index = 11 Then
					Multiplier11 = 0;
					Multiplier12 = 8;
				EndIf;

				Figure = Number(Mid(TIN, Index, 1));
				CheckSum11 = CheckSum11 + Figure * Multiplier11;
				CheckSum12 = CheckSum12 + Figure * Multiplier12;

			EndDo;

			CheckDigit11 = (CheckSum11 %11) %10;
			CheckDigit12 = (CheckSum12 %11) %10;

			If CheckDigit11 <> Number(Mid(TIN,11,1)) OR CheckDigit12 <> Number(Mid(TIN,12,1)) Then
				MeetsRequirements = False;
				MessageText = MessageText + ?(ValueIsFilled(MessageText), Chars.LF, "")
				               + NStr("ru = 'Контрольное число для ИНН не совпадает с рассчитанным.'; en = 'The TIN hash does not match the calculated value.'; pl = 'Numer kontrolny dla NIP nie jest zgodny z wyliczonym.';es_ES = 'El número de control para el NIF no coincide con el calculado.';es_CO = 'El número de control para el NIF no coincide con el calculado.';tr = 'VKN için kontrol rakam hesaplanmış rakamla uyumlu değil.';it = 'Il hash del cod.fiscale non corrisponde al valore calcolato.';de = 'Die Kontrollnummer für die UID stimmt nicht mit der berechneten überein.'");
			EndIf;

		EndIf;

	EndIf;

	Return MeetsRequirements;

EndFunction 

// Checks the CRTR compliance with the requirements.
// According to the application to the order of the Federal Tax Service of the Russian Federation dated 06/29/2012 # MMB-7-6/435@
// "On confirmation of the Procedure and terms of assignment, application, and also changes in the 
// taxpayer identification number".
//
// Parameters:
//  CRTR - String - a registration reason code to be checked.
//  MessageText - String - a text of a message about found errors.
//
// Returns:
//  Boolean - True if it matches.
//
Function CRTRMeetsRequirements(Val CRTR, MessageText) Export

	Errors = New Array;
	CRTR = TrimAll(CRTR);
	
	If StrLen(CRTR) <> 9 Then
		Errors.Add(NStr("ru = 'КПП должен состоять из 9 символов.'; en = 'The CRTR must contain 9 characters.'; pl = 'KPP musi zawierać 9 znaków.';es_ES = 'CRTR debe contener 9 dígitos.';es_CO = 'CRTR debe contener 9 dígitos.';tr = 'KPP 9 haneden oluşmalıdır.';it = 'Il Codice causale di registrazione fiscale deve essere di 9 caratteri.';de = 'Die Registrierungsnummer im Rahmen der steuerlichen Erfassung sollte aus 9 Symbolen bestehen.'"));
	Else
		If Not StringFunctionsClientServer.OnlyNumbersInString(Left(CRTR, 4)) Then
			Errors.Add(NStr("ru = 'Первые 4 символа КПП (код налогового органа) должны быть цифрами.'; en = 'The first 4 characters in the CRTR (tax authority code) must be numbers.'; pl = 'Pierwsze 4 znaki KPP (kod organu podatkowego) muszą być cyframi.';es_ES = 'Los primeros 4 símbolos de CRTR (código de la agencia tributaria) deben ser dígitos,';es_CO = 'Los primeros 4 símbolos de CRTR (código de la agencia tributaria) deben ser dígitos,';tr = 'KPP''in ilk 4 hanesi (vergi organın kodu) rakam olmalıdır.';it = 'Le prime 4 cifre nel CRTR (codice autorità tasse) dovrebbero essere numeri';de = 'Die ersten 4 Symbole der Registrierungsnummer im Rahmen der steuerlichen Erfassung (Code der Steuerbehörde) sollten Ziffern sein.'"));
		EndIf;
		
		AllowedChars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
		For CharNumber = 5 To 6 Do
			Char = Mid(CRTR, CharNumber, 1);
			If StrFind(AllowedChars, Char) = 0 Then
				Errors.Add(NStr("ru = 'Символы 5-6 КПП (причина постановки на учет) должны быть цифрами и/или заглавными буквами латинского алфавита от A до Z.'; en = 'Characters 5 and 6 in the CRTR (registration reason) must be numbers or capital Latin letters (A to Z).'; pl = 'Znaki 5 i 6 w KPP (powód rejestracji) muszą być zapisane cyframi lub dużymi literami łacińskimi (od A do Z).';es_ES = 'Los símbolos 5-6 de CRTR (razón de la inscripción) deben ser cifras y/o letras mayúsculas del alfabeto latino de A á Z.';es_CO = 'Los símbolos 5-6 de CRTR (razón de la inscripción) deben ser cifras y/o letras mayúsculas del alfabeto latino de A á Z.';tr = 'KPP (kayıt nedeni) 5-6 sembolleri rakam ve/veya A ile Z arasında Latin alfabesinin büyük harfleri olacaktır.';it = 'I caratteri 5 e 6 del Codice causale di registrazione fiscale devono essere rappresentati da cifre o lettere latine maiuscole (A -Z).';de = 'Die Symbole 5-6 der Registrierungsnummer im Rahmen der steuerlichen Erfassung (Registrierungsgrund) sollten Zahlen und/oder Großbuchstaben des lateinischen Alphabets von A bis Z sein.'"));
				Break;
			EndIf;
		EndDo;
		
		If Not StringFunctionsClientServer.OnlyNumbersInString(Right(CRTR, 3)) Then
			Errors.Add(NStr("ru = 'Последние 3 символа КПП (порядковый номер постановки на учет) должны быть цифрами.'; en = 'The last 3 characters in the CRTR (registration number) must be numbers.'; pl = 'Ostatnie 3 znaki w KPP (numer rejestracyjny) muszą być cyframi.';es_ES = 'Los últimos 3 símbolos de CRTR (número de registro) deben ser dígitos.';es_CO = 'Los últimos 3 símbolos de CRTR (número de registro) deben ser dígitos.';tr = 'KPP ''in son 3 sembolü (kayıt nedeninin sıra numarası) rakam olmalıdır.';it = 'Gli ultimi 3 caratteri nel Numero di Registrazione devono essere numeri.';de = 'Die letzten 3 Symbole der Registriernummer im Rahmen der steuerlichen Erfassung (Registriernummer) sollten Ziffern sein.'"));
		EndIf;
	EndIf;
	
	MessageText = StrConcat(Errors, Chars.LF);
	
	Return Errors.Count() = 0;

EndFunction

// Checks the registration number compliance with the requirements.
//
// Parameters:
//  Registration number - String - main state registration number to be checked.
//  IsLegalEntity - Boolean - a flag showing whether the registration number owner is a legal entity.
//  MessageText - String - text of a message about found errors.
//
// Returns:
//  Boolean - True if it matches.
//
Function RegistrationNumberMeetsRequirements(Val RegistrationNumber, IsLegalEntity, MessageText) Export

	MeetsRequirements = True;
	MessageText = "";

	RegistrationNumber = TrimAll(RegistrationNumber);
	RegistrationNumberLength = StrLen(RegistrationNumber);
	
	If IsLegalEntity = Undefined Then
		MessageText = MessageText + NStr("ru = 'Не определен тип владельца ОГРН.'; en = 'Undefined type of registration number owner.'; pl = 'Nie jest zdefiniowany rodzaj właściciela REGON.';es_ES = 'No se ha determinado el tipo del propietario del número de registro.';es_CO = 'No se ha determinado el tipo del propietario del número de registro.';tr = 'OGRN sahibinin türü belirlenmedi.';it = 'Tipo non definito di proprietario del numero di registrazione.';de = 'Unbestimmter Typ des Eigentümers der Registriernummer.'");
		Return False;
	EndIf;

	If NOT StringFunctionsClientServer.OnlyNumbersInString(RegistrationNumber) Then
		MeetsRequirements = False;
		MessageText = MessageText + NStr("ru = 'ОГРН должен состоять только из цифр.'; en = 'The registration number must contain only numbers.'; pl = 'REGON musi składać się tylko z cyfr.';es_ES = 'El número de registro tiene que contener solo dígitos.';es_CO = 'El número de registro tiene que contener solo dígitos.';tr = 'OGRN yalnızca rakamlardan oluşmalıdır.';it = 'Il numero di registrazione deve contenere solamente cifre.';de = 'Die Registriernummer darf nur Zahlen enthalten.'")
	EndIf;

	If IsLegalEntity AND RegistrationNumberLength <> 13 Then
		MeetsRequirements = False;
		MessageText = MessageText + ?(ValueIsFilled(MessageText), Chars.LF, "")
		               + NStr("ru = 'ОГРН юридического лица должен состоять из 13 цифр.'; en = 'The registration number of a business must contain 13 numbers.'; pl = 'REGON osoby prawnej musi składać się z 13 cyfr.';es_ES = 'El número de registro de la persona jurídica debe contener 13 dígitos.';es_CO = 'El número de registro de la persona jurídica debe contener 13 dígitos.';tr = 'Tüzel kişinin OGRN 13 rakamdan oluşmalıdır.';it = 'Il numero di registrazione aziendale deve essere di 13 cifre.';de = 'Die Registriernummer eines Unternehmens muss 13 Zahlen enthalten.'");
	ElsIf NOT IsLegalEntity AND RegistrationNumberLength <> 15 Then
		MeetsRequirements = False;
		MessageText = MessageText + ?(ValueIsFilled(MessageText), Chars.LF, "")
		               + NStr("ru = 'ОГРН физического лица должен состоять из 15 цифр.'; en = 'The registration number of an individual must contain 15 numbers.'; pl = 'REGON osoby fizycznej musi składać się z 15 cyfr.';es_ES = 'El número de registro de un individuo debe contener 15 números.';es_CO = 'El número de registro de un individuo debe contener 15 números.';tr = 'Gerçek kişinin OGRN 15 rakamdan oluşmalıdır.';it = 'Il numero di registrazione di persona fisica deve essere di 15 cifre.';de = 'Die Registriernummer einer natürlichen Person muss 15 Zahlen enthalten.'");
	EndIf;

	If MeetsRequirements Then

		If IsLegalEntity Then

			CheckDigit = Right(Format(Number(Left(RegistrationNumber, 12)) % 11, "NZ=0; NG=0"), 1);

			If CheckDigit <> Right(RegistrationNumber, 1) Then
				MeetsRequirements = False;
				MessageText = MessageText + ?(ValueIsFilled(MessageText), Chars.LF, "")
				               + NStr("ru = 'Контрольное число для ОГРН не совпадает с рассчитанным.'; en = 'The registration number hash does not match the calculated value.'; pl = 'Numer kontrolny dla REGON nie pasuje do obliczonego.';es_ES = 'El número de control para el número de registro no coincide con el calculado.';es_CO = 'El número de control para el número de registro no coincide con el calculado.';tr = 'OGRN için kontrol rakam hesaplanmış rakam ile uyumlu değildir.';it = 'Il hash del numero di registrazione non corrisponde al valore calcolato.';de = 'Der Hash der Registriernummer stimmt nicht mit dem berechneten Wert überein.'");
			EndIf;

		Else

			CheckDigit = Right(Format(Number(Left(RegistrationNumber, 14)) % 13, "NZ=0; NG=0"), 1);

			If CheckDigit <> Right(RegistrationNumber, 1) Then
				MeetsRequirements = False;
				MessageText = MessageText + ?(ValueIsFilled(MessageText), Chars.LF, "")
				               + NStr("ru = 'Контрольное число для ОГРН не совпадает с рассчитанным.'; en = 'The registration number hash does not match the calculated value.'; pl = 'Numer kontrolny dla REGON nie pasuje do obliczonego.';es_ES = 'El número de control para el número de registro no coincide con el calculado.';es_CO = 'El número de control para el número de registro no coincide con el calculado.';tr = 'OGRN için kontrol rakam hesaplanmış rakam ile uyumlu değildir.';it = 'Il hash del numero di registrazione non corrisponde al valore calcolato.';de = 'Der Hash der Registriernummer stimmt nicht mit dem berechneten Wert überein.'");
			EndIf;

		EndIf;

	EndIf;

	Return MeetsRequirements;

EndFunction 

// Checks the NCBO code compliance with the standard requirements.
//
// Parameters:
//  CodeToCheck - String - a NCBO code to be checked.
//  IsLegalEntity - Boolean - a flag showing whether the NCBO code owner is a legal entity.
//  MessageText - String - a text of the error message in the checked NCBO code.
//
// Returns:
//  Boolean - True if it matches.
//
Function NCBOCodeMeetsRequirements(Val CodeToCheck, IsLegalEntity, MessageText = "") Export
	
	CodeToCheck = TrimAll(CodeToCheck);
	MessageText = "";
	CodeLength = StrLen(CodeToCheck);

	If IsLegalEntity = Undefined Then
		MessageText = MessageText + NStr("ru = 'Не определен тип владельца кода ОКПО.'; en = 'Undefined type of NCBO code owner.'; pl = 'Nie został zdefiniowany typ właściciela kodu JPRPO.';es_ES = 'No se ha determinado el tipo del propietario de NCBO.';es_CO = 'No se ha determinado el tipo del propietario de NCBO.';tr = 'OKPO kod sahibinin türü belirlenmedi.';it = 'Tipo non definito di proprietario del codice del Classificatore russo delle imprese e degli enti.';de = 'Die Art des Eigentümers der OKPO-Nummer ist nicht definiert.'");
		Return False;
	EndIf;
	
	If Not StringFunctionsClientServer.OnlyNumbersInString(CodeToCheck) Then
		MessageText = MessageText + NStr("ru = 'Код ОКПО должен состоять только из цифр.'; en = 'The NCBO code must contain only numbers.'; pl = 'Kod JPRPO musi składać się tylko z cyfr.';es_ES = 'El código NCBO tiene que contener solo dígitos.';es_CO = 'El código NCBO tiene que contener solo dígitos.';tr = 'OKPO kodu sadece rakamlardan oluşmalıdır.';it = 'Il codice del Classificatore russo delle imprese e degli enti deve contenere solamente cifre.';de = 'Die OKPO-Nummer sollte nur aus Ziffern bestehen.'") + Chars.LF;
	EndIf;

	If IsLegalEntity AND CodeLength <> 8 Then
		MessageText = MessageText + NStr("ru = 'Код ОКПО юридического лица должен состоять из 8 цифр.'; en = 'The NCBO code of a business must contain 8 numbers.'; pl = 'Kod NCBO firmy musi zawierać 8 liczb.';es_ES = 'El código NCBO de la persona jurídica debe contener 8 dígitos.';es_CO = 'El código NCBO de la persona jurídica debe contener 8 dígitos.';tr = 'Tüzel kişinin OKPO 8 rakamdan oluşmalıdır.';it = 'Il codice aziendale del Classificatore russo delle imprese e degli enti deve essere di 8 cifre.';de = 'Die OKPO-Nummer einer juristischen Person sollte aus 8 Ziffern bestehen.'") + Chars.LF;
	ElsIf Not IsLegalEntity AND CodeLength <> 10 Then
		MessageText = MessageText + NStr("ru = 'Код ОКПО физического лица должен состоять из 10 цифр.'; en = 'The NCBO code of an individual must contain 10 numbers.'; pl = 'Kod JPRPO osoby fizycznej musi składać się z 10 cyfr.';es_ES = 'El código NCBO de la persona física debe contener 10 dígitos.';es_CO = 'El código NCBO de la persona física debe contener 10 dígitos.';tr = 'Gerçek kişinin OKPO 10 rakamdan oluşmalıdır.';it = 'Il codice del Classificatore russo delle imprese e degli enti di persona fisica deve essere composto da 10 cifre.';de = 'Die OKPO-Nummer einer natürlichen Person sollte aus 10 Ziffern bestehen.'") + Chars.LF;
	EndIf;
	
	If Not IsBlankString(MessageText) Then
		MessageText = TrimAll(MessageText);
		Return False;
	EndIf;
	
	If Not ClassifierCodeValid(CodeToCheck) Then
		MessageText = NStr("ru = 'Контрольное число для кода по ОКПО не совпадает с рассчитанным.'; en = 'The NCBO code hash does not match the calculated value.'; pl = 'Numer kontrolny dla kodu JPRPO nie pasuje do obliczonego.';es_ES = 'El número de control para el código NCBO no coincide con el calculado.';es_CO = 'El número de control para el código NCBO no coincide con el calculado.';tr = 'OKPO kodu için kontrol sayı hesaplanmış sayı ile uyumlu değil.';it = 'Il hash del Classificatore russo delle imprese e degli enti non corrisponde al valore calcolato.';de = 'Die Kontrollnummer für die OKPO-Nummer stimmt nicht mit der berechneten überein.'");
		Return False
	EndIf;
	
	Return True;
	
EndFunction 

// Checks whether the number of the insurance certificate complies with the PF requirements.
//
// Parameters:
//  InsuranceNumber - String - PF insurance number. The string should be entered according to the pattern "999-999-999 99".
//  MessageText - String - a message text about an error entering an insurance number.
//
// Returns:
//  Boolean - True if it matches.
//
Function PFInsuranceNumberMeetsRequirements(Val InsuranceNumber, MessageText) Export
	
	MessageText = "";
	
	StringOfNumbers = StrReplace(InsuranceNumber, "-", "");
	StringOfNumbers = StrReplace(StringOfNumbers, " ", "");
	
	If IsBlankString(StringOfNumbers) Then
		MessageText = MessageText + NStr("ru = 'Страховой номер не заполнен'; en = 'The IIAN is blank.'; pl = 'Numer ubezpieczenia nie jest zapełniony';es_ES = 'Número de seguro no especificado';es_CO = 'Número de seguro no especificado';tr = 'Sigorta numarası doldurulmamıştır';it = 'Il numero di previdenza sociale è vuoto.';de = 'Die Versicherungsnummer ist nicht ausgefüllt'");
		Return False;
	EndIf;
	
	If StrLen(StringOfNumbers) < 11 Then
		MessageText = MessageText + NStr("ru = 'Страховой номер указан не полностью.'; en = 'The IIAN is incomplete.'; pl = 'Numer ubezpieczenia określono nie w pełni';es_ES = 'Número de seguro especificado no completamente';es_CO = 'Número de seguro especificado no completamente';tr = 'Sigorta numarası eksik belirtilmiştir';it = 'Il numero di previdenza sociale non è completo.';de = 'Die Versicherungsnummer ist unvollständig'");
		Return False;
	EndIf;
	
	If NOT StringFunctionsClientServer.OnlyNumbersInString(StringOfNumbers) Then
		MessageText = MessageText + NStr("ru = 'Страховой номер должен состоять только из цифр.'; en = 'The IIAN must contain only numbers.'; pl = 'Numer ubezpieczenia musi składać się tylko z cyfr.';es_ES = 'Número de seguro tiene que contener solo dígitos.';es_CO = 'Número de seguro tiene que contener solo dígitos.';tr = 'Sigorta numarası sadece rakamlardan oluşmalıdır.';it = 'Il numero di previdenza sociale deve contenere solo cifre.';de = 'Die Versicherungsnummer sollte nur aus Ziffern bestehen.'");
		Return False;
	EndIf;
	
	ChecksumNumber = Number(Right(StringOfNumbers, 2));
	
	If Number(Left(StringOfNumbers, 9)) > 1001998 Then
		Total = 0;
		For Cnt = 1 To 9 Do
			Total = Total + Number(Mid(StringOfNumbers, 10 - Cnt, 1)) * Cnt;
		EndDo;
		Balance = Total % 101;
		Balance = ?(Balance = 100, 0, Balance);
		If Balance <> ChecksumNumber Then
			MessageText = MessageText + NStr("ru = 'Контрольное число для страхового номера не совпадает с рассчитанным.'; en = 'The IIAN hash does not match the calculated value.'; pl = 'Numer kontrolny dla numeru ubezpieczenia nie pasuje do obliczonego.';es_ES = 'El número de control para el número de seguro no coincide con el calculado.';es_CO = 'El número de control para el número de seguro no coincide con el calculado.';tr = 'Sigorta numarası için kontrol rakam hesaplanmış rakam ile uyumlu değildir.';it = 'Il hash di numero di previdenza sociale non corrisponde al valore calcolato.';de = 'Die Kontrollnummer für die Versicherungsnummer stimmt nicht mit der berechneten überein.'");
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

// Checking the control key in the personal account number (the 9th digit of the account number), 
// the algorithm is set by the document:
// "PROCEDURE OF CALCULATING THE CONTROL KEY IN THE PERSONAL ACCOUNT NUMBER"
// approved by the Central Bank of the Russian Federation dated 09/08/1997 # 515).
//
// Parameters:
//  AccountNumber - String - a bank account number.
//  BIC - String - BIC of the back in which the account is open.
//  IsBank - Boolean - is True, a bank account will be checked, otherwise it is checked as a PPC 
//                     account (the correspondent account of PPC is not filled).
//
// Returns:
//  Boolean - True if it matches.
//
Function AccountKeyDigitMeetsRequirements(AccountNumber, BIC, IsBank = True)Export
	
	AccountNumberString = TrimAll(AccountNumber);
	
	// If there is an alphabetic value in the 6th digit of the personal account (in the case of using 
	// clearing currency), this character is replaced with the matching digit:
	// 
	Digit6 = Mid(AccountNumberString, 6, 1); 
	
	If NOT StringFunctionsClientServer.OnlyNumbersInString(Digit6) Then
		AlphabeticValuesFor6thDigit = StrSplit("A,Accus,From,E,N,K,M,P,T,X", ",", False);
		Figure = AlphabeticValuesFor6thDigit.Find(Digit6);	
		If Figure = Undefined Then
			Return False;
		EndIf;
		Digit6 = String(Figure);
	EndIf;
	
	// To calculate a control key, a set of two attribute is used: a conditional number of the PPC (if 
	// the personal account is opened at the PPC) or of the depository institution (if the personal 
	// account is open in a depository institution) and a personal account number.
	// 
	If IsBank Then
		ConventionalCONumber = Right(BIC, 3);
	Else
		ConventionalCONumber = "0" + Mid(BIC, 5, 2 );
	EndIf;
	
	AccountNumberString = ConventionalCONumber + Left(AccountNumberString,5) + Digit6 + Mid(AccountNumberString, 7);
	
	If StrLen(AccountNumberString) <> 23 Then
		Return False;
	EndIf;
	
	If NOT StringFunctionsClientServer.OnlyNumbersInString(AccountNumberString) Then
		Return False;
	EndIf;
	
	Weights = "71371371371371371371371";
	Checksum = 0;
	For Digit = 1 To 23 Do
		Product = Number(Mid(AccountNumberString, Digit, 1)) * Number(Mid(Weights, Digit, 1));
		LeastSignificantDigit = Number(Right(String(Product), 1));
		Checksum = Checksum + LeastSignificantDigit;
	EndDo;
	
	// When receiving a sum multiple of 10 (the lower digit is 0), the value of the control key is 
	// considered correct.
	
	Return Right(String(Checksum), 1) = "0";
	
EndFunction

#EndRegion

#Region Private

// Checks the correctness of the code by check digit (the last digit in the code).
//
// Rule 50.1.024-2005 "The main provisions and the order of work on the development, maintenance, 
// and usage of all-Russian classifiers," appendix B.
//
// Check digit is calculated as follows:
// 1. Code digits in the All-Russian classifier, starting with the high-order digit, are assigned a 
// set of weights corresponding to the natural series of numbers from 1 to 10. If code digit capacity is greater than 10, the set of weidhts is repeated.
// 2. Each digit of the code is multiplied by the weight of the digit and the sum of the resulting products is calculated.
// 3. The control number for the code is the remainder of dividing the amount received by the module "11".
// 4. The control number should have a single digit whose value is in the range from 0 to 9.
// If the balance equals 10, to receive a single-digit control number you need to recalculate, 
// applying to it the second sequence of weights, shifted two digits to the left (3, 4, 5,…). If 
// after the second recalculation the remainder still equals 10, the control number value is set to 
// 0.
//
// Parameters:
//  CodeToCheck - String - a code to be checked.
//
// Returns:
//  Boolean - True if correct.
//
Function ClassifierCodeValid(CodeToCheck)
	
	SumOfProducts = 0;
	For Position = 1 To StrLen(CodeToCheck)-1 Do
		Figure = Number(Mid(CodeToCheck, Position, 1));
		Weight = (Position - 1) % 10 + 1;
		SumOfProducts = SumOfProducts + Figure * Weight;
	EndDo;

	ChecksumDigit = SumOfProducts % 11;
	If ChecksumDigit = 10 Then
		SumOfProducts = 0;
		For Position = 1 To StrLen(CodeToCheck)-1 Do
			Figure = Number(Mid(CodeToCheck, Position, 1));
			Weight = (Position + 1) % 10 + 1;
			SumOfProducts = SumOfProducts + Figure * Weight;
		EndDo;
		ChecksumDigit = SumOfProducts % 11;
	EndIf;
	
	ChecksumDigit = ChecksumDigit % 10;
	
	Return String(ChecksumDigit) = Right(CodeToCheck, 1);

EndFunction

#EndRegion


