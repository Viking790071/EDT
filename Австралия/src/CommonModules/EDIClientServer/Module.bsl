#Region Public

Procedure CheckCounterpartyIsReadyForExchange(Counterparty, HasErrors = False, ArrayToSaveMessages = Undefined) Export
	
	CounterpartyInfo = EDIServerCall.CounterpartyInfoToCheck(Counterparty);
	
	If Not ValueIsFilled(CounterpartyInfo.CounterpartyTIN) Then
		
		MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'To exchange documents with %1, please fill the TIN in their profile.'; ru = 'Для обмена документами с %1, пожалуйста, заполните ИНН в их профиле.';pl = 'Do wymiany dokumentów z %1, wypełnij NIP w ich profilu.';es_ES = 'Para intercambiar documentos con %1, por favor, rellene el NIF en su perfil.';es_CO = 'Para intercambiar documentos con %1, por favor, rellene el NIF en su perfil.';tr = '%1 ile belge değişimi için lütfen profillerinde VKN''yi doldurun.';it = 'Per poter scambiare i documenti con %1, compilare il cod.fiscale nel loro profilo.';de = 'Um Dokumente mit %1 auszutauschen, füllen Sie bitte die Steuernummer in deren Profil aus.'"),
			Counterparty);
		If ArrayToSaveMessages = Undefined Then
			CommonClientServer.MessageToUser(MessageToUserText);
		Else
			ArrayToSaveMessages.Add(MessageToUserText);
		EndIf;
		HasErrors = True;
		
	EndIf;
	
	If Not ValueIsFilled(CounterpartyInfo.CounterpartyEmail) Then
		
		MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'To exchange documents with %1, please fill the email in their profile.'; ru = 'Для обмена документами с %1, пожалуйста, заполните адрес электронной почты в их профиле.';pl = 'Do wymiany dokumentów z %1, wypełnij adres e-mail w ich profilu.';es_ES = 'Para intercambiar documentos con %1, por favor, rellene el correo electrónico en su perfil.';es_CO = 'Para intercambiar documentos con %1, por favor, rellene el correo electrónico en su perfil.';tr = '%1 ile belge değişimi için lütfen profillerinde e-postayı doldurun.';it = 'Per poter scambiare i documenti con %1, compilare l''email nel loro profilo.';de = 'Um Dokumente mit %1 auszutauschen, füllen Sie bitte die E-Mail in deren Profil aus.'"),
			Counterparty);
		If ArrayToSaveMessages = Undefined Then
			CommonClientServer.MessageToUser(MessageToUserText);
		Else
			ArrayToSaveMessages.Add(MessageToUserText);
		EndIf;
		HasErrors = True;
		
	EndIf;
	
	If Not ValueIsFilled(CounterpartyInfo.CounterpartyPostalAddress) Then
		
		MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'To exchange documents with %1, please fill the legal address in their profile.'; ru = 'Для обмена документами с %1, пожалуйста, заполните юридический адрес в их профиле.';pl = 'Do wymiany dokumentów z %1, wypełnij adres prawny w ich profilu.';es_ES = 'Para intercambiar documentos con %1, por favor, rellene el domicilio legal en su perfil.';es_CO = 'Para intercambiar documentos con %1, por favor, rellene el domicilio legal en su perfil.';tr = '%1 ile belge değişimi için lütfen profillerinde yasal adresi doldurun.';it = 'Per poter scambiare i documenti con %1, compilare l''indirizzo legale nel loro profilo.';de = 'Um Dokumente mit %1 auszutauschen, füllen Sie bitte die gültige Geschäftsadresse in deren Profil aus.'"),
			Counterparty);
		If ArrayToSaveMessages = Undefined Then
			CommonClientServer.MessageToUser(MessageToUserText);
		Else
			ArrayToSaveMessages.Add(MessageToUserText);
		EndIf;
		HasErrors = True;
		
	EndIf;
	
	
	
	If CounterpartyInfo.IsIndividual Then
		
		If CounterpartyInfo.NameParts.Count() < 2 Then
			MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'To exchange documents with %1, the counterparty must have at least a two-part name.'; ru = 'Для обмена документами с %1 имя контрагента должно состоять как минимум из двух частей.';pl = 'Do wymiany dokumentów z %1, kontrahent powinien mieć nazwę co najmniej dwuczęściową.';es_ES = 'Para intercambiar documentos con %1, el nombre de la contrapartida debe tener al menos dos partes.';es_CO = 'Para intercambiar documentos con %1, el nombre de la contrapartida debe tener al menos dos partes.';tr = '%1 ile belge değişimi için cari hesabın en az iki kısımlı ismi olmalıdır.';it = 'Per poter scambiare i documenti con %1, la controparte deve avere almeno un nome in due parti.';de = 'Um Dokumente mit %1 auszutauschen, muss der Geschäftspartner mindestens einen zweiteiligen Namen haben.'"),
				Counterparty);
			If ArrayToSaveMessages = Undefined Then
				CommonClientServer.MessageToUser(MessageToUserText);
			Else
				ArrayToSaveMessages.Add(MessageToUserText);
			EndIf;
			HasErrors = True;
		EndIf;
		
		If StrLen(CounterpartyInfo.CounterpartyTIN) <> 11 Then
			MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'To exchange documents with %1, the counterparty of ''Individual'' type must have 11 digits TIN.'; ru = 'Для обмена документами с %1, контрагент типа ""Физическое лицо"" должен иметь ИНН из 11 цифр.';pl = 'Do wymiany dokumentów z %1, kontrahent o typie ''Osoba fizyczna'' powinien mieć 11 cyfr NIP.';es_ES = 'Para intercambiar documentos con %1, la contrapartida del tipo ''Individual'' debe tener un NIF de 11 dígitos.';es_CO = 'Para intercambiar documentos con %1, la contrapartida del tipo ''Individual'' debe tener un NIF de 11 dígitos.';tr = '%1 ile belge değişimi için ''Kişi'' türünde cari hesabın 11 haneli VKN''si olmalıdır.';it = 'Per poter modificare i documenti con %1, la controparte di tipo ""Individuale"" deve avere un cod.fiscale di 11 cifre.';de = 'Um Dokumente mit %1 auszutauschen, muss der Geschäftspartner des Typs ''Natürliche Person'' 11 Ziffern der Steuernummer haben.'"),
				Counterparty);
			If ArrayToSaveMessages = Undefined Then
				CommonClientServer.MessageToUser(MessageToUserText);
			Else
				ArrayToSaveMessages.Add(MessageToUserText);
			EndIf;
			HasErrors = True;
		EndIf;
		
	Else
		
		If StrLen(CounterpartyInfo.CounterpartyTIN) <> 10 Then
			MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'To exchange documents with %1, the counterparty of ''Legal entity'' type must have 10 digits TIN.'; ru = 'Для обмена документами с %1, контрагент типа ""Юридическое лицо"" должен иметь ИНН из 10 цифр.';pl = 'Do wymiany dokumentów z %1, kontrahent o typie ''Osoba prawna'' powinna mieć 10 cyfr NIP.';es_ES = 'Para intercambiar documentos con %1, la contrapartida del tipo ''Entidad empresarial'' debe tener un NIF de 10 dígitos.';es_CO = 'Para intercambiar documentos con %1, la contrapartida del tipo ''Entidad empresarial'' debe tener un NIF de 10 dígitos.';tr = '%1 ile belge değişimi için ''Tüzel kişi'' türünde cari hesabın 10 haneli VKN''si olmalıdır.';it = 'Per poter scambiare i documenti con %1, la controparte del tipo ""Persona giuridica"" deve avere un cod.fiscale di 10 cifre.';de = 'Um Dokumente mit %1 auszutauschen, muss der Geschäftspartner des Typs ''Juristische Person'' 10 Ziffern der Steuernummer haben.'"),
				Counterparty);
			If ArrayToSaveMessages = Undefined Then
				CommonClientServer.MessageToUser(MessageToUserText);
			Else
				ArrayToSaveMessages.Add(MessageToUserText);
			EndIf;
			HasErrors = True;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
