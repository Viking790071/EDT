#Region Public

#Region MessageTexts

#Region TabularSections

Function TabularSectionWillBeCleared(TabularSectionName = "", Refill = False) Export 
	
	If IsBlankString(TabularSectionName) Then
		
		If Refill Then
			Return NStr("en = 'Tabular section will be cleared and filled in again. Continue?'; ru = 'Табличная часть будит очищена и заполнена повторно. Продолжить?';pl = 'Sekcja tabelaryczna zostanie wyczyszczona i wypełniona ponownie. Kontynuować?';es_ES = 'Sección tabular se eliminará y rellenará de nuevo. ¿Continuar?';es_CO = 'Sección tabular se eliminará y rellenará de nuevo. ¿Continuar?';tr = 'Tablo bölümü silinip tekrar doldurulacak. Devam edilsin mi?';it = 'La sezione tabellare viene cancellata e riempita di nuovo. Continuare?';de = 'Der Tabellenabschnitt wird gelöscht und erneut ausgefüllt. Fortsetzen?'");
		Else
			Return NStr("en = 'Tabular section will be cleared. Continue?'; ru = 'Табличная часть будет очищена. Продолжить выполнение операции?';pl = 'Sekcja tabelaryczna zostanie wyczyszczona. Kontynuować?';es_ES = 'Sección tabular se vaciará. ¿Continuar?';es_CO = 'Sección tabular se vaciará. ¿Continuar?';tr = 'Tablo bölümü temizlenecek. Devam edilsin mi?';it = 'La sezione tabellare sarà annullata. Proseguire?';de = 'Der Tabellenabschnitt wird gelöscht. Fortsetzen?'");
		EndIf;
		
	Else
		
		If Refill Then
			StringPattern = NStr("en = 'The ""%1"" tabular section will be cleared and filled in again. Continue?'; ru = 'Табличная часть %1 будет очищена и повторно заполнена. Продолжить?';pl = 'Sekcja tabelaryczna ""%1"" zostanie wyczyszczona i wypełniona ponownie. Kontynuować?';es_ES = 'La sección tabular ""%1"" se eliminará y rellenará de nuevo. ¿Continuar?';es_CO = 'La sección tabular ""%1"" se eliminará y rellenará de nuevo. ¿Continuar?';tr = '""%1"" tablo bölümü silinip tekrar doldurulacak. Devam edilsin mi?';it = 'La parte tabellare ""%1"" sarà cancellata e ricompilata, continuare?';de = 'Der Tabellenabschnitt ""%1"" wird gelöscht und erneut ausgefüllt. Fortsetzen?'");
		Else
			StringPattern = NStr("en = 'The ""%1"" tabular section will be cleared. Continue?'; ru = 'Табличная часть %1 будет очищена. Продолжить?';pl = 'Sekcja tabelaryczna ""%1"" zostanie wyczyszczona. Kontynuować?';es_ES = 'La sección tabular ""%1"" se limpiará. ¿Continuar?';es_CO = 'La sección tabular ""%1"" se limpiará. ¿Continuar?';tr = '""%1"" tablo bölümü silinecek. Devam edilsin mi?';it = 'La parte tabellare ""%1"" sarà cancellata, continuare?';de = 'Der Tabellenabschnitt ""%1"" wird gelöscht. Fortsetzen?'");
		EndIf;
		
		Return StringFunctionsClientServer.SubstituteParametersToString(StringPattern, TabularSectionName);
		
	EndIf;
	
EndFunction

#EndRegion

#EndRegion

#Region PriceAndCurrency

Function GetPriceTypeOnChangeWarningText(IsDiscount = True) Export
	
	If IsDiscount Then
		Return NStr("en = 'The counterparty''s price type and discount type differ from prices and discounts in the document. If you want to refill prices, select the ""Refill prices"" checkbox.'; ru = 'Тип цены и тип скидки контрагента отличаются от цен и скидок в документе. Если вы хотите перезаполнить цены, установите флажок ""Перезаполнить цены"".';pl = 'Rodzaj ceny kontrahenta i typ rabatu różnią się od cen i rabatów w dokumencie. Jeśli chcesz ponownie wypełnić ceny, zaznacz pole wyboru ""Wypełnij ponownie ceny"".';es_ES = 'El tipo de precio y el tipo de descuento de la contraparte difieren de los precios y descuentos del documento. Si desea recargar los precios, seleccione la casilla de verificación ""Rellenar los precios"".';es_CO = 'El tipo de precio y el tipo de descuento de la contraparte difieren de los precios y descuentos del documento. Si desea recargar los precios, seleccione la casilla de verificación ""Rellenar los precios"".';tr = 'Cari hesabın fiyat türü ve indirim türü belgedeki fiyatlardan ve indirimlerden farklı. Fiyatları yeniden doldurmak istiyorsanız ""Fiyatları yeniden doldur"" onay kutusunu işaretleyin.';it = 'Il tipo di prezzo della controparte e il tipo di sconto differiscono da prezzi e sconti nel documento. Per ricompilare i prezzi, selezionare la casella di controllo ""Ricompilare prezzi"".';de = 'Der Preis- und Rabatttyp des Geschäftspartners unterscheidet sich von Preisen und Rabatten im Dokument. Aktivieren Sie das Kontrollkästchen ""Preise neu auffüllen"" wenn Sie die Preise neu auffüllen möchten.'");
	Else
		Return NStr("en = 'The counterparty''s price type differ from prices in the document. If you want to refill prices, select the ""Refill prices"" checkbox.'; ru = 'Тип цены контрагента отличается от цен в документе. Если вы хотите перезаполнить цены, установите флажок ""Перезаполнить цены"".';pl = 'Rodzaj ceny kontrahenta różni się od cen w dokumencie. Jeśli chcesz ponownie wypełnić ceny zaznacz pole wyboru ""Wypełnij ponownie ceny"".';es_ES = 'El tipo de precio de la contraparte difiere de los precios del documento. Si desea rellenar los precios, seleccione la casilla de verificación ""Rellenar los precios"".';es_CO = 'El tipo de precio de la contraparte difiere de los precios del documento. Si desea rellenar los precios, seleccione la casilla de verificación ""Rellenar los precios"".';tr = 'Cari hesabın fiyat türü belgedeki fiyatlardan farklı. Fiyatları yeniden doldurmak istiyorsanız ""Fiyatları yeniden doldur"" onay kutusunu işaretleyin.';it = 'Il tipo di prezzo della controparte differisce dai prezzi nel documento. Per ricompilare i prezzi, selezionare la casella di controllo ""Ricompilare prezzi"".';de = 'Der Preistyp des Geschäftspartners unterscheidet sich von Preisen im Dokument. Aktivieren Sie das Kontrollkästchen ""Preise neu auffüllen"" wenn Sie die Preise neu auffüllen möchten.'");
	EndIf;
	
EndFunction

Function GetSettleCurrencyOnChangeWarningText() Export
	
	Return NStr("en = 'The contract currency has changed. Check the document currency. If required, change it. Then, if you want to recalculate the prices according to the new document currency, select the ""Recalculate prices according to the document currency rate"" checkbox.'; ru = 'Изменилась валюта договора. Проверьте валюту документа и при необходимости измените ее. Затем, если вы хотите пересчитать цены в соответствии с новой валютой документа, установите флажок ""Пересчитать цены по курсу валюты документа"".';pl = 'Waluta kontraktu została zmieniona. Sprawdź walutę dokumentu. W razie konieczności, zmień ją. Następnie, jeśli chcesz przeliczyć ceny zgodnie z nową walutą dokumentu, zaznacz pole wyboru ""Przelicz ceny zgodnie z kursem waluty dokumentu"".';es_ES = 'La moneda del contrato ha cambiado. Compruebe la moneda del documento. Si es necesario, cámbiela. A continuación, si desea recalcular los precios según la nueva moneda del documento, seleccione la casilla de verificación ""Recalcular los precios según el tipo de moneda del documento"".';es_CO = 'La moneda del contrato ha cambiado. Compruebe la moneda del documento. Si es necesario, cámbiela. A continuación, si desea recalcular los precios según la nueva moneda del documento, seleccione la casilla de verificación ""Recalcular los precios según el tipo de moneda del documento"".';tr = 'Sözleşme para birimi değiştirildi. Belge para birimini kontrol edip, gerekirse değiştirin. Ardından, yeni belge para birimine göre fiyatları yeniden hesaplamak istiyorsanız ""Fiyatları belge para birimine göre yeniden hesapla"" onay kutusunu işaretleyin.';it = 'La valuta del contratto è stata modificata. Verificare la valuta del documento. Se richiesto, modificarla. Poi, per ricalcolare i prezzi in base alla nuova valuta del documento, selezionare la casella di controllo ""Ricalcolare i prezzi in base al tasso di valuta del documento"".';de = 'Die Vertragswährung wurde verändert. Überprüfen Sie die Belegwährung. Ggf. ändern Sie sie. Dann aktivieren Sie das Kontrollkästchen ""Preise in Übereinstimmung mit dem Kurs der Belegwährung neu berechnen"" wenn Sie die Preise in Übereinstimmung mit dem Kurs der Belegwährung neu berechnen möchten.'");
	
EndFunction

Function GetApplyRatesOnNewDateQuestionText() Export
	
	Return NStr("en = 'The document date has changed. Do you want to apply the exchange rates effective on the new date?'; ru = 'Изменилась дата документа. Установить курс валюты в соответствии с курсом на новую дату?';pl = 'Data dokumentu uległa zmianie. Czy chcesz zastosować kurs waluty, obowiązujący na nową datę?';es_ES = 'La fecha del documento se ha cambiado. ¿Quiere aplicar los tipos de cambio vigentes en la nueva fecha?';es_CO = 'La fecha del documento se ha cambiado. ¿Quiere aplicar los tipos de cambio vigentes en la nueva fecha?';tr = 'Belge tarihi değiştirildi. Yeni tarihte geçerli olan döviz kurlarını uygulamak ister misiniz?';it = 'La data del documento è stata modificata. Applicare il tasso di cambio effetivo alla nuova data?';de = 'Das Datum des Dokuments wurde verändert. Möchten Sie die Wechselkurse für das neue Datum verwenden?'");
	
EndFunction

#EndRegion

#Region AccountingTemplates

Function GetAccountingTransactionCompanyTypeOfAccountingOnChangeQueryText(IsTypeOfAccountingApplicable = True) Export
	
	If IsTypeOfAccountingApplicable Then
		Return NStr("en = 'The selected chart of accounts ""%1"" is inapplicable to ""%2"" and type of accounting ""%3"" on %4. An applicable chart of accounts will be autofilled. The Entries tab will be cleared. Continue?'; ru = 'Выбранный план счетов ""%1"" неприменим к ""%2"" и типу бухгалтерского учета ""%3"" на %4. Подходящий план счетов будет заполнен автоматически. Вкладка ""Проводки"" будет очищена. Продолжить?';pl = 'Wybrany plan kont ""%1"" jest zastosowany na ""%2"" i typ rachunkowości ""%3"" na %4. Zastosowany plan kont zostanie wypełniony automatycznie. Karta wpisy zostanie wyczyszczona. Kontynuować?';es_ES = 'El diagrama de cuentas seleccionado ""%1"" es inaplicable a ""%2"" y el tipo de contabilidad ""%3"" en %4. Se rellenará automáticamente un diagrama de cuentas aplicable. La pestaña Entradas de diario se borrará. ¿Continuar?';es_CO = 'El diagrama de cuentas seleccionado ""%1"" es inaplicable a ""%2"" y el tipo de contabilidad ""%3"" en %4. Se rellenará automáticamente un diagrama de cuentas aplicable. La pestaña Entradas de diario se borrará. ¿Continuar?';tr = 'Seçilen hesap planı ""%1"", %4''de ""%2""ya ve ""%3"" muhasebe türüne uygulanamıyor. Uygulanabilir bir hesap planı otomatik olarak doldurulacak. Girişler sekmesi temizlenecek. Devam edilsin mi?';it = 'Il piano dei conti ""%1"" selezionato non è applicabile a ""%2"" e al tipo di contabilità ""%3"" in %4. Un piano dei conti applicabile sarà compilato automaticamente. La scheda Voci sarà cancellata. Continuare?';de = 'Der ausgewählte Kontenplan ""%1"" ist für ""%2"" und Typ der Buchhaltung ""%3"" auf %4 nicht verwendbar. Ein verwendbarer Kontenplan wird automatisch gefüllt. Die Registerkarte Buchungen wird gelöscht. Weiter?'");
	Else
		Return NStr("en = 'The selected type of accounting ""%1"" is inapplicable to ""%2"" on %3. Type of accounting will be cleared. Continue?'; ru = 'Выбранный тип бухгалтерского учета ""%1"" неприменим к ""%2"" на %3. Тип бухгалтерского учета будет очищен. Продолжить?';pl = 'Wybrany typ księgowości ""%1"" nie ma zastosowania do ""%2"" na %3. Typ księgowości zostanie wyczyszczony. Kontynuować?';es_ES = 'El tipo de contabilidad seleccionado ""%1"" es inaplicable a ""%2"" en %3. El tipo de contabilidad se borrará. ¿Continuar?';es_CO = 'El tipo de contabilidad seleccionado ""%1"" es inaplicable a ""%2"" en %3. El tipo de contabilidad se borrará. ¿Continuar?';tr = 'Seçilen muhasebe türü ""%1"", %3''de ""%2""ye uygulanamıyor. Muhasebe türü temizlenecek. Devam edilsin mi?';it = 'Il tipo selezionato di contabilità ""%1"" non è applicabile a ""%2"" in %3. Il tipo di contabilità sarà cancellata. Continuare?';de = 'Der ausgewählte Typ der Buchhaltung ""%1"" ist für ""%2"" auf ""%3"" Der Typ der Buchhaltung wird gelöscht. Weiter?'");
	EndIf;
	
EndFunction

Function GetEntriesTableUpdateQueryText() Export
	
	Return NStr("en = 'The Entries table will be updated. Continue?'; ru = 'Таблица ""Проводки"" будет обновлена. Продолжить?';pl = 'Tabela Wpisy zostanie zaktualizowana. Kontynuować?';es_ES = 'La tabla Entradas de diario se actualizará. ¿Continuar?';es_CO = 'La tabla Entradas de diario se actualizará. ¿Continuar?';tr = 'Girişler tablosu güncellenecek. Devam edilsin mi?';it = 'La tabella Voci sarà aggiornata. Continuare?';de = 'Die Tabelle Buchungen wird aktualisiert. Weiter?'");
	
EndFunction

Function GetDataSaveQueryText() Export
	
	Return NStr("en = 'Data has been changed. Do you want to save the changes?'; ru = 'Данные были изменены. Сохранить изменения?';pl = 'Dane zostały zmienione. Czy chcesz zapisać zmiany?';es_ES = 'Los datos han sido cambiados. ¿Quiere guardar los cambios?';es_CO = 'Los datos han sido cambiados. ¿Quiere guardar los cambios?';tr = 'Veriler değiştirildi. Değişiklikleri kaydetmek istiyor musunuz?';it = 'I dati sono stati modificati. Salvare le modifiche?';de = 'Die Daten wurden geändert. Wollen Sie die Änderungen speichern?'");
	
EndFunction

Function GetAccountingTransactionDateChangeQueryText(IsTypeOfAccountingApplicable) Export
	
	If IsTypeOfAccountingApplicable Then
		Return NStr("en = 'The selected chart of accounts ""%1"" is inapplicable to ""%2"" and type of accounting ""%3"" on %4. An applicable chart of accounts will be autofilled. The Entries tab will be cleared. Continue?'; ru = 'Выбранный план счетов ""%1"" неприменим к ""%2"" и типу бухгалтерского учета ""%3"" на %4. Подходящий план счетов будет заполнен автоматически. Вкладка ""Проводки"" будет очищена. Продолжить?';pl = 'Wybrany plan kont ""%1"" jest zastosowany na ""%2"" i typ rachunkowości ""%3"" na %4. Zastosowany plan kont zostanie wypełniony automatycznie. Karta wpisy zostanie wyczyszczona. Kontynuować?';es_ES = 'El diagrama de cuentas seleccionado ""%1"" es inaplicable a ""%2"" y el tipo de contabilidad ""%3"" en %4. Se rellenará automáticamente un diagrama de cuentas aplicable. La pestaña Entradas de diario se borrará. ¿Continuar?';es_CO = 'El diagrama de cuentas seleccionado ""%1"" es inaplicable a ""%2"" y el tipo de contabilidad ""%3"" en %4. Se rellenará automáticamente un diagrama de cuentas aplicable. La pestaña Entradas de diario se borrará. ¿Continuar?';tr = 'Seçilen hesap planı ""%1"", %4''de ""%2""ya ve ""%3"" muhasebe türüne uygulanamıyor. Uygulanabilir bir hesap planı otomatik olarak doldurulacak. Girişler sekmesi temizlenecek. Devam edilsin mi?';it = 'Il piano dei conti ""%1"" selezionato non è applicabile a ""%2"" e al tipo di contabilità ""%3"" in %4. Un piano dei conti applicabile sarà compilato automaticamente. La scheda Voci sarà cancellata. Continuare?';de = 'Der ausgewählte Kontenplan ""%1"" ist für ""%2"" und Typ der Buchhaltung ""%3"" auf %4 nicht verwendbar. Ein verwendbarer Kontenplan wird automatisch gefüllt. Die Registerkarte Buchungen wird gelöscht. Weiter?'");
	Else
		Return NStr("en = 'The selected type of accounting ""%1"" is inapplicable to ""%2"" on %3. Type of accounting will be cleared. Continue?'; ru = 'Выбранный тип бухгалтерского учета ""%1"" неприменим к ""%2"" на %3. Тип бухгалтерского учета будет очищен. Продолжить?';pl = 'Wybrany typ rachunkowości ""%1"" nie ma zastosowania do ""%2"" na %3. Typ rachunkowości zostanie wyczyszczony. Kontynuować?';es_ES = 'El tipo de contabilidad seleccionado ""%1"" es inaplicable a ""%2"" en %3. El tipo de contabilidad se borrará. ¿Continuar?';es_CO = 'El tipo de contabilidad seleccionado ""%1"" es inaplicable a ""%2"" en %3. El tipo de contabilidad se borrará. ¿Continuar?';tr = 'Seçilen muhasebe türü ""%1"", %3''de ""%2""ye uygulanamıyor. Muhasebe türü temizlenecek. Devam edilsin mi?';it = 'Il tipo selezionato di contabilità ""%1"" non è applicabile a ""%2"" in %3. Il tipo di contabilità sarà cancellata. Continuare?';de = 'Der ausgewählte Typ der Buchhaltung ""%1"" ist für ""%2"" auf ""%3"" Der Typ der Buchhaltung wird gelöscht. Weiter?'");
	EndIf;
	
EndFunction

Function GetCopyMoveLinesErrorText(Action) Export
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot %1 the selected lines of accounting entries. 
			|Select a single line or all lines of the same accounting entry. 
			|Then try again.'; 
			|ru = 'Не удалось %1 выбранные строки бухгалтерских проводок. 
			|Выберите одну строку или все строки одной бухгалтерской проводки и повторите попытку.';
			|pl = 'Nie można %1 wybranych wierszy wpisów księgowych. 
			|Wybierz oddzielny wiersz lub wszystkie wiersze tego samego wpisu księgowego. 
			|Zatem spróbuj ponownie.';
			|es_ES = 'No se pueden %1 seleccionar las líneas de entradas contables. 
			|Seleccione una sola línea o todas las líneas de una misma entrada contable. 
			|Inténtelo de nuevo.';
			|es_CO = 'No se pueden %1 seleccionar las líneas de entradas contables. 
			|Seleccione una sola línea o todas las líneas de una misma entrada contable. 
			|Inténtelo de nuevo.';
			|tr = 'Seçilen muhasebe girişi satırlarına şu yapılamıyor: %1. 
			|1 muhasebe girişinin tek bir satırını veya
			| tüm satırlarını seçip tekrar deneyin.';
			|it = 'Impossibile %1 le righe selezionate delle voci di contabilità. 
			|Selezionare una singola riga o tutte le righe della stessa voce di contabilità,
			|poi riprovare.';
			|de = 'Fehler beim %1 von ausgewählten Zeilen von Buchungen. 
			|Wählen Sie eine einzelne Zeile oder alle Zeilen der Buchung aus. 
			|Dann versuchen Sie erneut.'"),
		Action);
	
EndFunction

Function GetCheckEntriesAccountsErrorPeriodText() Export
	
	Return NStr("en = 'Document period does not match account %1 period.'; ru = 'Период документа не совпадает с периодом счета %1.';pl = 'Okres dokumentu nie jest zgodny okres konta%1.';es_ES = 'El periodo del documento no coincide con el periodo %1 de la cuenta.';es_CO = 'El periodo del documento no coincide con el periodo %1 de la cuenta.';tr = 'Belge dönemi %1 hesabının dönemi ile eşleşmiyor.';it = 'Il periodo del documento non corrisponde al periodo%1 del conto.';de = 'Dokumentenzeitraum stimmt mit dem Kontenzeitraum %1 nicht überein.'");
	
EndFunction

Function GetCheckEntriesAccountsErrorCompanyText() Export
	
	Return NStr("en = 'Account ""%1"" is not applicable to company ""%2""'; ru = 'Счет ""%1"" неприменим к организации ""%2""';pl = 'Konto ""%1"" nie ma zastosowania do firmy ""%2""';es_ES = 'La cuenta ""%1"" no es aplicable a la empresa ""%2""';es_CO = 'La cuenta ""%1"" no es aplicable a la empresa ""%2""';tr = '""%1"" hesabı ""%2"" iş yerine uygulanamıyor.';it = 'Il conto ""%1"" non è applicabile all''azienda ""%2""';de = 'Konto ""%1"" ist für die Firma ""%2"" nicht verwendbar'");
	
EndFunction

Function GetCheckTransactionsFillingDateErrorText(Compound) Export
	
	If Compound Then
		Return NStr("en = 'In line %1/%2, account must be valid from %3 to %4. Select another account.'; ru = 'В строке %1/%2 счет должен быть действителен с %3 по %4. Выберите другой счет.';pl = 'W wierszu %1/%2, konto musi być wapne od %3 do %4. Wybierz inne konto.';es_ES = 'En la línea %1/%2, la cuenta debe ser válida desde%3 hasta %4. Seleccione otra cuenta.';es_CO = 'En la línea %1/%2, la cuenta debe ser válida desde%3 hasta %4. Seleccione otra cuenta.';tr = '%1/%2 satırında, hesap %3 - %4 arasında geçerli olmalıdır. Başka bir hesap seçin.';it = 'Nella riga %1/%2, il conto deve essere valido da %3a %4. Selezionare un altro conto.';de = 'In der Zeile %1/%2, muss das Konto vom %3 bis %4 gültig sein. Wählen Sie ein anderes Konto aus.'");
	Else
		Return NStr("en = 'In line %1, %2 account must be valid from %3 to %4. Select another account.'; ru = 'В строке %1, %2 счет должен быть действителен с %3 по %4. Выберите другой счет.';pl = 'W wierszu %1, konto %2 musi być ważne od%3 do %4. Wybierz inne konto.';es_ES = 'En la línea %1,%2, la cuenta debe ser válida desde %3 hasta %4. Seleccione otra cuenta.';es_CO = 'En la línea %1,%2, la cuenta debe ser válida desde %3 hasta %4. Seleccione otra cuenta.';tr = '%1 satırında, %2hesabı %3 - %4 arası geçerli olmalıdır. Başka bir hesap seçin.';it = 'Nella riga %1,%2 il conto deve essere valido da%3 a%4. Selezionare un altro conto.';de = 'In der Zeile %1, %2, muss das Konto vom %3 bis %4 gültig sein. Wählen Sie ein anderes Konto aus.'");
	EndIf;
	
EndFunction

Function GetCheckTransactionsFillingOwnerErrorText(Compound) Export
	
	If Compound Then
		Return NStr("en = 'In line %1/%2, account must belong to the ""%3"" chart of accounts. Select another account.'; ru = 'В строке %1/%2 счет должен принадлежать плану счетов ""%3"". Выберите другой счет.';pl = 'W wierszu %1/%2, konto musi należeć do planu kont ""%3"". Wybierz inne konto.';es_ES = 'En la línea %1/%2, la cuenta debe pertenecer al diagrama de cuentas ""%3"". Seleccione otra cuenta.';es_CO = 'En la línea %1/%2, la cuenta debe pertenecer al diagrama de cuentas ""%3"". Seleccione otra cuenta.';tr = '%1/%2 satırında hesap ""%3"" hesap planına ait olmalıdır. Başka bir hesap seçin.';it = 'Nella riga %1/%2, il conto deve appartenere al piano dei conti ""%3"". Selezionare un altro conto.';de = 'In der Zeile %1/%2, muss das Konto zu dem Kontenplan ""%3"" gehören. Wählen Sie ein anderes Konto aus.'");
	Else
		Return NStr("en = 'In line %1, %2 account must belong to the ""%3"" chart of accounts. Select another account.'; ru = 'В строке %1 счет %2 должен принадлежать плану счетов ""%3"". Выберите другой счет.';pl = 'W wierszu %1, konto %2 musi należeć do planu kont ""%3"". Wybierz inne konto.';es_ES = 'En la línea %1,%2 la cuenta debe pertenecer al diagrama de cuentas ""%3,"". Seleccione otra cuenta.';es_CO = 'En la línea %1,%2 la cuenta debe pertenecer al diagrama de cuentas ""%3,"". Seleccione otra cuenta.';tr = '%1 satırında, %2 hesabı ""%3"" hesap planına ait olmalıdır. Başka bir hesap seçin.';it = 'Nella riga %1, %2il conto deve appartenere al piano dei conti ""%3"". Selezionare un altro conto.';de = 'In der Zeile %1/%2, muss das Konto zu dem Kontenplan ""%3"" gehören. Wählen Sie ein anderes Konto aus.'");
	EndIf;
	
EndFunction

Function GetCheckTransactionsFillingSourceDocumentErrorText() Export
	
	Return NStr("en = 'On %1 ""%2"" is not included in the list of Accounting source documents of ""%3""'; ru = 'На %1 ""%2"" не входит в список первичных бухгалтерских документов ""%3""';pl = 'Na %1 ""%2"" nie jest włączone do listy źródłowych dokumentów księgowych ""%3""';es_ES = 'En %1""%2"" no está incluido en la lista de documentos de fuente contable de ""%3""';es_CO = 'En %1""%2"" no está incluido en la lista de documentos de fuente contable de ""%3""';tr = '%1''de ""%2"", ""%3""nin Muhasebe kaynak belgeleri listesine dahil değil.';it = 'In %1 ""%2"" non è incluso nell''elenco dei documenti fonte di contabilità di ""%3""';de = 'In %1 ist ""%2"" in die Liste von Buchhaltungsquelldokumenten von ""%3"" nicht eingeschlossen'");
	
EndFunction

Function GetCheckTransactionsFillingIsApplicableErrorText() Export
	
	Return NStr("en = 'Type of accounting ""%1"" is inapplicable to ""%2"" on %3. Select a type of accounting applicable to the company according to its accounting policy. Then try again.'; ru = 'Тип бухгалтерского учета ""%1"" неприменим к ""%2"" на %3. Выберите тип бухгалтерского учета, применимый к организации в соответствии с ее учетной политикой и повторите попытку.';pl = 'Typ rachunkowości ""%1"" nie ma zastosowania do ""%2"" na %3. Wybierz typ rachunkowości, który ma zastosowanie do firmy zgodnie z jej polityką rachunkowości. Zatem spróbuj ponownie.';es_ES = 'El tipo de contabilidad ""%1"" es inaplicable a ""%2"" en %3. Seleccione un tipo de contabilidad aplicable a la empresa según su política de contabilidad. Inténtelo de nuevo.';es_CO = 'El tipo de contabilidad ""%1"" es inaplicable a ""%2"" en %3. Seleccione un tipo de contabilidad aplicable a la empresa según su política de contabilidad. Inténtelo de nuevo.';tr = '""%1"" muhasebe türü %3''de ""%2""ye uygulanamıyor. Muhasebe politikasına göre iş yerine uygulanabilecek bir muhasebe türü seçip tekrar deneyin.';it = 'Il tipo di contabilità ""%1"" non è applicabile a ""%2"" in %3. Selezionare un tipo di contabiità applicabile all''azienda in base alla sua politica contabile, poi riprovare.';de = 'Typ der Buchhaltung ""%1"" ist für ""%2"" auf %3 nicht verwendbar. Wählen Sie einen Typ der Buchhaltung, verwendbar für die Firma in Übereinstimmung mit deren Bilanzierungsrichtlinien, aus. Dann versuchen Sie erneut.'");
	
EndFunction

Function GetCheckTransactionsFillingEntriesPostedErrorText() Export
	
	Return NStr("en = 'On %1 for type of accounting %2 accounting entries must be posted with %3'; ru = 'На %1 для типа бухгалтерского учета %2 бухгалтерские проводки должны быть сформированы с помощью %3';pl = 'Na %1 dla typu rachunkowości %2 wpisy kwięgowe muszą być zatwierdzone z %3';es_ES = 'En %1 para el tipo de contabilidad %2 las entradas contables se deben contabilizar con %3';es_CO = 'En %1 para el tipo de contabilidad %2 las entradas contables se deben contabilizar con %3';tr = '%1''de %2 muhasebe türü için muhasebe girişleri %3 ile kaydedilmelidir';it = 'In %1 per questo tipo di contabilità %2 le voci di contabilità devono essere pubblicate con %3';de = 'In %1 müssen die Buchungen für Typ der Buchhaltung %2 mit %3 gebucht werden'");
	
EndFunction

Function GetCheckTransactionsFillingDebitCreditDifferenceErrorText() Export
	
	Return NStr("en = 'In entry %1 Amount in Total debit %2, %3 does not match amount in Total credit %4, %3. Adjust amounts so that difference is equal to 0.00.'; ru = 'В проводке %1 сумма общего дебета %2, %3 не совпадают с суммой общего кредита %4, %3. Скорректируйте суммы так, чтобы разница была равна 0.00.';pl = 'W wpisie %1 Wartość w polu Wn %2, %3 nie jest zgodna z wartością Ma %4, %3. Skoryguj wartości, aby różnica była równa0.00.';es_ES = 'En la entrada de diario %1El importe en el débito total %2, %3no coincide con el importe en el crédito total. Ajuste las cantidades para que la diferencia sea igual a 0,00.';es_CO = 'En la entrada de diario %1El importe en el débito total %2, %3no coincide con el importe en el crédito total. Ajuste las cantidades para que la diferencia sea igual a 0,00.';tr = '%1 girişinde, Toplam borç tutarı %2, %3 Toplam alacak tutarı %4, %3 ile eşleşmiyor. Fark 0.00 olacak şekilde tutarları düzeltin.';it = 'Nella voce %1Importo in Debito totale%2,%3 non corrisponde all''importo in Credito totale%4, %3.Correggere l''importo così che la differenza sia pari a 0.00.';de = 'In Buchung %1 Betrag in Soll gesamt %2, stimmt %3 mit dem Betrag in Haben gesamt %4, %3. Ändern Sie Beträge, sodass die Differenz 0.00 gleich ist.'");
	
EndFunction

Function GetFormulaTooltip(AttributeID, AdditionalParameter) Export
	
	ResultText = "";
	
	If Upper(AttributeID) = Upper("Period") Then
		ResultText = NStr("en = 'Create a formula for calculating a period. To take a period from a certain data field, switch to Data field.'; ru = 'Создайте формулу для вычисления периода. Чтобы взять период из определенного поля данных, нажмите ""Поле данных"".';pl = 'Utwórz formułę do obliczenia okresu. Aby wziąć okres z określonego pola danych, przełącz na pole danych.';es_ES = 'Cree una fórmula para calcular un periodo. Para tomar un período de un determinado campo de datos, cambie a Campo de datos.';es_CO = 'Cree una fórmula para calcular un periodo. Para tomar un período de un determinado campo de datos, cambie a Campo de datos.';tr = 'Dönem hesaplamak için formül oluşturun. Belirli bir veri alanından dönem almak için Veri alanına geçiş yapın.';it = 'Creare una dormula per calcolare il periodo. Per ricavare il periodo da un determinato campo dati, passare a Campo dati.';de = 'Erstellen Sie eine Formel für Berechnung des Zeitraums. Um ein Zeitraum aus einem bestimmten Datenfeld zu entnehmen, schalten Sie zum Datenfeld um.'");
	ElsIf Upper(AttributeID) = Upper("AmountCur") And AdditionalParameter = "" Then
		ResultText = NStr("en = 'Specify a rule to determine the account amount in the transaction currency. To take the amount from a certain field, click Data field and select a field from the list. The fields are grouped by source.
			|To calculate the amount by formula, click Formula and create a formula.'; 
			|ru = 'Укажите правило для определения суммы счета в валюте операции. Чтобы взять сумму из определенного поля, нажмите ""Поле данных"" и выберите поле из списка. Поля сгруппированы по источнику.
			|Чтобы рассчитать сумму по формуле, нажмите ""Формула"" и создайте формулу.';
			|pl = 'Wybierz regułę do określenia wartości konta w walucie transakcji. Aby wziąć wartość z określonego pola, kliknij pole danych i wybierz pole z listy. Pola są grupowane według źródła.
			|Aby obliczyć wartość według formuły, kliknij Formuła i utwórz formułę.';
			|es_ES = 'Especifique una regla para determinar el importe de la cuenta en la moneda de la transacción. Para extraer el importe de un campo determinado, haga clic en Campo de datos y seleccione un campo de la lista. Los campos se agrupan por fuente. 
			|Para calcular el importe mediante una fórmula, haga clic en Fórmula y cree una fórmula.';
			|es_CO = 'Especifique una regla para determinar el importe de la cuenta en la moneda de la transacción. Para extraer el importe de un campo determinado, haga clic en Campo de datos y seleccione un campo de la lista. Los campos se agrupan por fuente. 
			|Para calcular el importe mediante una fórmula, haga clic en Fórmula y cree una fórmula.';
			|tr = 'İşlem para birimindeki hesap tutarını belirlemek için kural belirtin. Tutarı belirli bir alandan almak için veri alanına tıklayın ve listeden bir alan seçin. Alanlar kaynağa göre gruplanır.
			|Tutarı formülle hesaplamak için Formül''e tıklayıp formül oluşturun.';
			|it = 'Indicare una regola per determinare l''importo del conto nella valuta di transazione. Per ricavare l''importo da un certo campo, cliccare su Campo dati e selezionare un campo dall''elenco. I campi sono raggruppati per fonte.
			| Per calcolare l''importo tramite formula, cliccare su Formula e crearne una.';
			|de = 'Geben Sie eine Regel zum Festlegen des Kontobetrags in der Transaktionswährung ein. Um den Betrag aus einem bestimmten Feld zu entnehmen, klicken Sie auf Datenfeld und wählen ein Feld aus der Liste aus. Die Felder sind nach Quelle gruppiert.
			|Um den Betrag nach Formel zu berechnen, klicken Sie auf Formel und erstellen Sie eine Formel.'");
	ElsIf Upper(AttributeID) = Upper("AmountCur") And AdditionalParameter = "Dr" Then
		ResultText = NStr("en = 'Specify a rule to determine the debit account amount in the transaction currency. To take the amount from a certain field, click Data field and select a field from the list. The fields are grouped by source.
			|To calculate the amount by formula, click Formula and create a formula.'; 
			|ru = 'Укажите правило для определения суммы дебетового счета в валюте операции. Чтобы взять сумму из определенного поля, нажмите ""Поле данных"" и выберите поле из списка. Поля сгруппированы по источнику.
			|Чтобы рассчитать сумму по формуле, нажмите ""Формула"" и создайте формулу.';
			|pl = 'Wybierz regułę do określenia wartości konta zobowiązania w walucie transakcji. Aby wziąć wartość z określonego pola, kliknij pole danych i wybierz pole z listy. Pola są grupowane według źródła.
			|Aby obliczyć wartość według formuły, kliknij Formuła i utwórz formułę.';
			|es_ES = 'Especifique una regla para determinar el importe de la cuenta en la moneda de la transacción. Para extraer el importe de un campo determinado, haga clic en Campo de datos y seleccione un campo de la lista. Los campos se agrupan por fuente. 
			|Para calcular el importe mediante una fórmula, haga clic en Fórmula y cree una fórmula.';
			|es_CO = 'Especifique una regla para determinar el importe de la cuenta en la moneda de la transacción. Para extraer el importe de un campo determinado, haga clic en Campo de datos y seleccione un campo de la lista. Los campos se agrupan por fuente. 
			|Para calcular el importe mediante una fórmula, haga clic en Fórmula y cree una fórmula.';
			|tr = 'İşlem para birimindeki borç hesabı tutarını belirlemek için kural belirtin. Tutarı belirli bir alandan almak için veri alanına tıklayın ve listeden bir alan seçin. Alanlar kaynağa göre gruplanır.
			|Tutarı formülle hesaplamak için Formül''e tıklayıp formül oluşturun.';
			|it = 'Indicare una regola per determinare l''importo del conto di debito nella valuta della transazione. Per ricavare l''importo da un determinato campo, cliccare su Campo dati e selezionare un campo dall''elenco. I campi sono raggruppati per fonte.
			| Per calcolare l''importo tramite formula, cliccare su Formula e crearne una.';
			|de = 'Geben Sie eine Regel zum Festlegen des Soll-Kontobetrags in der Transaktionswährung ein. Um den Betrag aus einem bestimmten Feld zu entnehmen, klicken Sie auf Datenfeld und wählen ein Feld aus der Liste aus. Die Felder sind nach Quelle gruppiert.
			|Um den Betrag nach Formel zu berechnen, klicken Sie auf Formel und erstellen Sie eine Formel.'");
	ElsIf Upper(AttributeID) = Upper("AmountCur") And AdditionalParameter = "Cr" Then
		ResultText = NStr("en = 'Specify a rule to determine the credit account amount in the transaction currency. To take the amount from a certain field, click Data field and select a field from the list. The fields are grouped by source.
			|To calculate the amount by formula, click Formula and create a formula.'; 
			|ru = 'Укажите правило для определения суммы кредитового счета в валюте операции. Чтобы взять сумму из определенного поля, нажмите ""Поле данных"" и выберите поле из списка. Поля сгруппированы по источнику.
			|Чтобы рассчитать сумму по формуле, нажмите ""Формула"" и создайте формулу.';
			|pl = 'Wybierz regułę do określenia wartości konta należności w walucie transakcji. Aby wziąć wartość z określonego pola, kliknij pole danych i wybierz pole z listy. Pola są grupowane według źródła.
			|Aby obliczyć wartość według formuły, kliknij Formuła i utwórz formułę.';
			|es_ES = 'Especifique una regla para determinar el importe de la cuenta en la moneda de la transacción. Para extraer el importe de un campo determinado, haga clic en Campo de datos y seleccione un campo de la lista. Los campos se agrupan por fuente. 
			|Para calcular el importe mediante una fórmula, haga clic en Fórmula y cree una fórmula.';
			|es_CO = 'Especifique una regla para determinar el importe de la cuenta en la moneda de la transacción. Para extraer el importe de un campo determinado, haga clic en Campo de datos y seleccione un campo de la lista. Los campos se agrupan por fuente. 
			|Para calcular el importe mediante una fórmula, haga clic en Fórmula y cree una fórmula.';
			|tr = 'İşlem para birimindeki alacak hesabı tutarını belirlemek için kural belirtin. Tutarı belirli bir alandan almak için veri alanına tıklayın ve listeden bir alan seçin. Alanlar kaynağa göre gruplanır.
			|Tutarı formülle hesaplamak için Formül''e tıklayıp formül oluşturun.';
			|it = 'Indicare una regola per determinare l''importo del conto di credito nella valuta della transazione. Per ricavare l''importo da un determinato campo, cliccare su Campo dati e selezionare un campo dall''elenco. I campi sono raggruppati per fonte.
			|Per calcolare l''importo tramite formula, cliccare su Formula e crearne una.';
			|de = 'Geben Sie eine Regel zum Festlegen des Haben-Kontobetrags in der Transaktionswährung ein. Um den Betrag aus einem bestimmten Feld zu entnehmen, klicken Sie auf Datenfeld und wählen ein Feld aus der Liste aus. Die Felder sind nach Quelle gruppiert.
			|Um den Betrag nach Formel zu berechnen, klicken Sie auf Formel und erstellen Sie eine Formel.'");
	ElsIf Upper(AttributeID) = Upper("amount") Then
		ResultText = NStr("en = 'Specify a rule to determine the amount in the presentation currency. To take the amount from a certain field, click Data field and select a field from the table. The fields are grouped by source.
			|To calculate the amount by formula, click Formula and create a formula.'; 
			|ru = 'Укажите правило для определения суммы в валюте представления отчетности. Чтобы взять сумму из определенного поля, нажмите ""Поле данных"" и выберите поле из таблицы. Поля сгруппированы по источнику.
			|Чтобы рассчитать сумму по формуле, нажмите ""Формула"" и создайте формулу.';
			|pl = 'Wybierz regułę do określenia kwoty w walucie prezentacji. Aby wziąć wartość z określonego pola, kliknij pole Dane i wybierz pole z tabeli. Pola są grupowane według źródła.
			|Aby obliczyć wartość według formuły, kliknij Formuła i utwórz formułę.';
			|es_ES = 'Especifique una regla para determinar el importe en la moneda de presentación. Para extraer el importe de un campo determinado, haga clic en Campo de datos y seleccione un campo de la tabla. Los campos se agrupan por fuente.
			| Para calcular el importe mediante una fórmula, haga clic en Fórmula y cree una fórmula.';
			|es_CO = 'Especifique una regla para determinar el importe en la moneda de presentación. Para extraer el importe de un campo determinado, haga clic en Campo de datos y seleccione un campo de la tabla. Los campos se agrupan por fuente.
			| Para calcular el importe mediante una fórmula, haga clic en Fórmula y cree una fórmula.';
			|tr = 'Finansal tablo para birimindeki hesap tutarını belirlemek için kural belirtin. Tutarı belirli bir alandan almak için veri alanına tıklayın ve listeden bir alan seçin. Alanlar kaynağa göre gruplanır.
			|Tutarı formülle hesaplamak için Formül''e tıklayıp formül oluşturun.';
			|it = 'Indicare una regola per determinare l''importo nella valuta di presentazione. Per ricavare un importo da un determinato campo, cliccare su Campo dati e selezionare un campo dalla tabella. I campi sono raggruppati per fonte.
			|Per calcolare l''importo tramite formula, cliccare su Formula e crearne una.';
			|de = 'Geben Sie eine Regel zum Festlegen des Kontobetrags in der Währung für die Berichtserstattung ein. Um den Betrag aus einem bestimmten Feld zu entnehmen, klicken Sie auf Datenfeld und wählen ein Feld aus der Tabelle aus. Die Felder sind nach Quelle gruppiert.
			|Um den Betrag nach Formel zu berechnen, klicken Sie auf Formel und erstellen Sie eine Formel.'");
	Else
		
	EndIf;
	
	Return ResultText;
	
EndFunction

Function GetTooltip(AttributeID, AdditionalParameter = "", ChoiceType = Undefined) Export
	
	ResultText = "";
	
	If Upper(AttributeID) = Upper("Parameter") Then
		ResultText = NStr("en = 'The following list shows parameter fields grouped by source. Expand a group and select a field to determine a parameter.'; ru = 'В списке показаны поля параметров, сгруппированные по источнику. Разверните группу и выберите поле для определения параметра.';pl = 'Następująca lista wyświetla pola parametrów, zgrupowane według źródła. Rozwiń grupę i wybierz pole do określenia parametru.';es_ES = 'La siguiente lista muestra los campos de los parámetros agrupados por fuente. Expanda un grupo y seleccione un campo para determinar un parámetro.';es_CO = 'La siguiente lista muestra los campos de los parámetros agrupados por fuente. Expanda un grupo y seleccione un campo para determinar un parámetro.';tr = 'Aşağıdaki liste, kaynağa göre gruplanmış parametre alanlarını gösteriyor. Parametre belirlemek için bir grubu genişletip alan seçin.';it = 'L''elenco seguente mostra i campi di parametri raggruppati per fonte. Espandere un gruppo e selezionare un campo per determinare una parametro.';de = 'Die folgende Liste zeigt die Parameterfelder gruppiert nach Quelle an. Erweitern Sie eine Gruppe und wählen Sie ein Feld aus, um den Parameter festzulegen.'");
	ElsIf Upper(AttributeID) = Upper("DataSource") Then
		ResultText = NStr("en = 'The following list shows data sources grouped by type. Expand a group and select a data source. This source will be used to fill in accounting entry details such as company, period, and transaction currency.'; ru = 'В списке показаны источники данных, сгруппированные по типу. Разверните группу и выберите источник данных. Он будет использоваться для заполнения сведений о бухгалтерской проводке, таких как организация, период и валюта операции.';pl = 'Następująca lista wyświetla źródła danych, zgrupowane według typu. Rozwiń grupę i wybierz źródło danych. To źródło będzie użyte do wypełniania szczegółów wpisu księgowego, takiego jak firma, okres, i waluta transakcji.';es_ES = 'La siguiente lista muestra las fuentes de datos agrupadas por tipo. Expanda un grupo y seleccione una fuente de datos. Esta fuente se utilizará para rellenar los detalles de la entrada contable, como la empresa, el período y la moneda de la transacción.';es_CO = 'La siguiente lista muestra las fuentes de datos agrupadas por tipo. Expanda un grupo y seleccione una fuente de datos. Esta fuente se utilizará para rellenar los detalles de la entrada contable, como la empresa, el período y la moneda de la transacción.';tr = 'Aşağıdaki liste, türe göre gruplanmış veri kaynaklarını gösteriyor. Bir grubu genişletip veri kaynağı seçin. İş yeri, dönem ve işlem para birimi gibi muhasebe girişi bilgilerinin doldurması için bu kaynak kullanılacaktır.';it = 'L''elenco seguente mostra fonti dati raggruppati per tipo. Espandere un gruppo e selezionare una fonte dati. Questa fonte sarà utilizzata per compilare i dettagli delle voci di entrata come azienda, periodo e valuta della transazione.';de = 'Die folgende Liste zeigt die Datenquellen gruppiert nach Typ an. Erweitern Sie eine Gruppe und wählen Sie eine Datenquelle aus. Diese Quelle wird für Auffüllen von Buchungsdetails wie Firma, Zeitraum und Transaktionswährung verwendet.'");
	ElsIf Upper(AttributeID) = Upper("Company") Then
		ResultText = NStr("en = 'The following list shows company fields grouped by source. Expand a group and select a source data field to determine a company.'; ru = 'В списке показаны поля организаций, сгруппированные по источнику. Разверните группу и выберите поле исходных данных для определения организации.';pl = 'Następująca lista wyświetla pola firmy, zgrupowane według źródła. Rozwiń grupę i wybierz źródłowe pole danych do określenia firmy.';es_ES = 'La siguiente lista muestra los campos de la empresa agrupados por fuente. Expanda un grupo y seleccione un campo de datos de origen para determinar una empresa.';es_CO = 'La siguiente lista muestra los campos de la empresa agrupados por fuente. Expanda un grupo y seleccione un campo de datos de origen para determinar una empresa.';tr = 'Aşağıdaki liste, kaynağa göre gruplanmış iş yeri alanlarını gösteriyor. İş yeri belirlemek için bir grubu genişletip kaynak veri alanı seçin.';it = 'L''elenco seguente mostra i campi dell''azienda raggruppati per fonte. Espandere un gruppo e selezionare un campo dati fonte per determinare una azienda.';de = 'Die folgende Liste zeigt die Firmenfelder gruppiert nach Quelle an. Erweitern Sie eine Gruppe und wählen Sie ein Feld von Quelldaten aus, um eine Firma festzulegen.'");
	ElsIf Upper(AttributeID) = Upper("Period") Then
		ResultText = NStr("en = 'The following list shows date fields grouped by source. Expand a group and select a source data field to determine a period. To calculate a period by formula, switch to Formula.'; ru = 'В списке показаны поля дат, сгруппированные по источнику. Разверните группу и выберите поле исходных данных для определения периода. Чтобы рассчитать период по формуле, нажмите ""Формула"".';pl = 'Następująca lista wyświetla pola danych, zgrupowana według źródła. Rozwiń grupę i wybierz pole źródła danych do określenia okresu. Aby obliczyć okres według formuły, przełącz na Formułę.';es_ES = 'La siguiente lista muestra los campos de fecha agrupados por fuente. Expanda un grupo y seleccione un campo de datos de origen para determinar un periodo. Para calcular un periodo por fórmula, cambie a Fórmula.';es_CO = 'La siguiente lista muestra los campos de fecha agrupados por fuente. Expanda un grupo y seleccione un campo de datos de origen para determinar un periodo. Para calcular un periodo por fórmula, cambie a Fórmula.';tr = 'Aşağıdaki liste, kaynağa göre gruplanmış tarih alanlarını gösteriyor. Dönem belirlemek için bir grubu genişletip kaynak veri alanı seçin. Dönemi formülle hesaplamak için Formül''e geçiş yapın.';it = 'L''elenco seguente mostra i campi data raggruppati per fonte. Espandere un gruppo e selezionare un campo dati fonte per determinare un perodo. Per calcolare un periodo tramite formula, passare a Formula.';de = 'Die folgende Liste zeigt die Datenfelder gruppiert nach Quelle an. Erweitern Sie eine Gruppe und wählen Sie ein Feld von Quelldaten aus, um einen Zeitraum festzulegen. Um einen Zeitraum nach Formel zu berechnen, schalten Sie zu Formel um.'");
	ElsIf Upper(AttributeID) = Upper("Account") And ChoiceType = 1 Then
		ResultText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Specify the settings of the default account%1.'; ru = 'Укажите настройки счета по умолчанию%1.';pl = 'Określ ustawienia domyślnego konta%1.';es_ES = 'Especifique la configuración de la cuenta por defecto%1.';es_CO = 'Especifique la configuración de la cuenta por defecto%1.';tr = 'Varsayılan hesabın ayarlarını belirtin%1.';it = 'Indicare le impostazione del conto predefinito %1.';de = 'Geben Sie die Einstellungen des Standardkontos %1 ein.'"),
			?(AdditionalParameter, " " + NStr("en = 'and the settings of analytical dimensions applicable to this account'; ru = 'и настройки аналитических измерений, применимые к этому счету';pl = 'i ustawienia wymiarów analitycznych, które mają zastosowanie do tego konta';es_ES = 'y los ajustes de las dimensiones analíticas aplicables a esta cuenta';es_CO = 'y los ajustes de las dimensiones analíticas aplicables a esta cuenta';tr = 've bu hesaba uygulanabilen analitik boyutların ayarları';it = 'e le impostazioni delle dimensioni analitiche applicabili a questo conto';de = 'und die Einstellungen von analytischen Messungen, verwendbar für dieses Konto'"), ""));
	ElsIf Upper(AttributeID) = Upper("AccountDr") And ChoiceType = 1 Then
		ResultText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Specify the settings of the default debit account%1.'; ru = 'Укажите настройки дебетового счета по умолчанию%1.';pl = 'Określ ustawienia domyślnego konta zobowiązania%1.';es_ES = 'Especifique la configuración de la cuenta de débito por defecto%1.';es_CO = 'Especifique la configuración de la cuenta de débito por defecto%1.';tr = 'Varsayılan borç hesabının ayarlarını belirtin%1.';it = 'Indicare le impostazioni del conto di debito predefinito%1.';de = 'Die Einstellungen des Soll-Standardkontos %1 eingeben.'"),
			?(AdditionalParameter, " " + NStr("en = 'and the settings of analytical dimensions applicable to this account'; ru = 'и настройки аналитических измерений, применимые к этому счету';pl = 'i ustawienia wymiarów analitycznych, które mają zastosowanie do tego konta';es_ES = 'y los ajustes de las dimensiones analíticas aplicables a esta cuenta';es_CO = 'y los ajustes de las dimensiones analíticas aplicables a esta cuenta';tr = 've bu hesaba uygulanabilen analitik boyutların ayarları';it = 'e le impostazioni delle dimensioni analitiche applicabili a questo conto';de = 'und die Einstellungen von analytischen Messungen, verwendbar für dieses Konto'"), ""));
	ElsIf Upper(AttributeID) = Upper("AccountCr") And ChoiceType = 1 Then
		ResultText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Specify the settings of the default credit account%1.'; ru = 'Укажите настройки кредитового счета по умолчанию%1.';pl = 'Określ ustawienia domyślnego konta należności%1.';es_ES = 'Especifique la configuración de la cuenta de crédito por defecto%1.';es_CO = 'Especifique la configuración de la cuenta de crédito por defecto%1.';tr = 'Varsayılan alacak hesabının ayarlarını belirtin%1.';it = 'Indicare le impostazioni del conto di credito predefinito%1.';de = 'Die Einstellungen des Haben-Standardkontos %1 eingeben.'"),
			?(AdditionalParameter, " " + NStr("en = 'and the settings of analytical dimensions applicable to this account'; ru = 'и настройки аналитических измерений, применимые к этому счету';pl = 'i ustawienia wymiarów analitycznych, które mają zastosowanie do tego konta';es_ES = 'y los ajustes de las dimensiones analíticas aplicables a esta cuenta';es_CO = 'y los ajustes de las dimensiones analíticas aplicables a esta cuenta';tr = 've bu hesaba uygulanabilen analitik boyutların ayarları';it = 'e le impostazioni delle dimensioni analitiche applicabili a questo conto';de = 'und die Einstellungen von analytischen Messungen, verwendbar für dieses Konto'"), ""));
	ElsIf Upper(AttributeID) = Upper("Account") Then
		ResultText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Specify an account%1.'; ru = 'Укажите счет%1.';pl = 'Określ konto%1.';es_ES = 'Especifique una cuenta%1.';es_CO = 'Especifique una cuenta%1.';tr = 'Hesap belirtin%1.';it = 'Indicare un conto%1.';de = 'Konto %1 eingeben.'"),
			?(AdditionalParameter, " " + NStr("en = 'and the settings of analytical dimensions applicable to this account'; ru = 'и настройки аналитических измерений, применимые к этому счету';pl = 'i ustawienia wymiarów analitycznych, które mają zastosowanie do tego konta';es_ES = 'y los ajustes de las dimensiones analíticas aplicables a esta cuenta';es_CO = 'y los ajustes de las dimensiones analíticas aplicables a esta cuenta';tr = 've bu hesaba uygulanabilen analitik boyutların ayarları';it = 'e le impostazioni delle dimensioni analitiche applicabili a questo conto';de = 'und die Einstellungen von analytischen Messungen, verwendbar für dieses Konto'"), ""));
	ElsIf Upper(AttributeID) = Upper("AccountDr") Then
		ResultText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Specify a debit account%1.'; ru = 'Укажите дебетовый счет%1.';pl = 'Określ konto zobowiązania%1.';es_ES = 'Especifique una cuenta de débito%1.';es_CO = 'Especifique una cuenta de débito%1.';tr = 'Borç hesabı belirtin%1.';it = 'Indicare un conto di debito%1.';de = 'Soll-Konto %1 eingeben.'"),
			?(AdditionalParameter, " " + NStr("en = 'and the settings of analytical dimensions applicable to this account'; ru = 'и настройки аналитических измерений, применимые к этому счету';pl = 'i ustawienia wymiarów analitycznych, które mają zastosowanie do tego konta';es_ES = 'y los ajustes de las dimensiones analíticas aplicables a esta cuenta';es_CO = 'y los ajustes de las dimensiones analíticas aplicables a esta cuenta';tr = 've bu hesaba uygulanabilen analitik boyutların ayarları';it = 'e le impostazioni delle dimensioni analitiche applicabili a questo conto';de = 'und die Einstellungen von analytischen Messungen, verwendbar für dieses Konto'"), ""));
	ElsIf Upper(AttributeID) = Upper("AccountCr") Then
		ResultText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Specify a credit account%1.'; ru = 'Укажите кредитовый счет%1.';pl = 'Określ konto należności%1.';es_ES = 'Especifique una cuenta de crédito%1.';es_CO = 'Especifique una cuenta de crédito%1.';tr = 'Alacak hesabı belirtin%1.';it = 'Indicare un conto di credito%1.';de = 'Haben-Konto %1 eingeben.'"),
			?(AdditionalParameter, " " + NStr("en = 'and the settings of analytical dimensions applicable to this account'; ru = 'и настройки аналитических измерений, применимые к этому счету';pl = 'i ustawienia wymiarów analitycznych, które mają zastosowanie do tego konta';es_ES = 'y los ajustes de las dimensiones analíticas aplicables a esta cuenta';es_CO = 'y los ajustes de las dimensiones analíticas aplicables a esta cuenta';tr = 've bu hesaba uygulanabilen analitik boyutların ayarları';it = 'e le impostazioni delle dimensioni analitiche applicabili a questo conto';de = 'und die Einstellungen von analytischen Messungen, verwendbar für dieses Konto'"), ""));
	ElsIf Upper(AttributeID) = Upper("AnalyticalDimensionValue") And ChoiceType Then
		ResultText = NStr("en = 'Select an analytical dimension value from the list. To select a source data field, switch to Data field.'; ru = 'Выберите значение аналитического измерения из списка. Чтобы выбрать поле исходных данных, нажмите ""Поле данных"".';pl = 'Wybierz wartość wymiaru analitycznego z listy. Aby wybrać pole danych źródłowych, przełącz na pole danych.';es_ES = 'Seleccione un valor de dimensión analítica de la lista. Para seleccionar un campo de datos de origen, cambie a Campo de datos.';es_CO = 'Seleccione un valor de dimensión analítica de la lista. Para seleccionar un campo de datos de origen, cambie a Campo de datos.';tr = 'Listeden analitik boyut değeri seçin. Kaynak veri alanı seçmek için Veri alanına geçiş yapın.';it = 'Selezionare un valore di dimensione analitica dall''elenco. Per selezionare un campo dati fonte, passare al campo Dati.';de = 'Einen Wert von analytischer Messung aus der Liste auswählen. Um ein Quelldatenfeld auszuwählen, schalten Sie zu Datenfeld um.'");
	ElsIf Upper(AttributeID) = Upper("AnalyticalDimensionValue") And Not ChoiceType Then
		ResultText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The following list shows %1 data fields grouped by source.
			|Expand a group and select a data field that will be a source for an analytical dimension value. 
			|To select a certain value, switch to Value.'; 
			|ru = 'В списке показаны поля данных %1, сгруппированные по источнику.
			|Разверните группу и выберите поле данных, которое будет источником для значения аналитического измерения. 
			|Чтобы выбрать определенное значение, нажмите ""Значение"".';
			|pl = 'Następująca lista wyświetla pola danych%1. zgrupowane według źródła.
			|Rozwiń grupę i wybierz pole danych, które będzie źródłem dla wartości wymiaru analitycznego. 
			|Aby wybrać określoną wartość , Przełącz na Wartość.';
			|es_ES = 'La siguiente lista muestra %1 los campos de datos agrupados por fuente. 
			|Expanda un grupo y seleccione un campo de datos que será la fuente de un valor de la dimensión analítica. 
			|Para seleccionar un valor determinado, cambie a Valor.';
			|es_CO = 'La siguiente lista muestra %1 los campos de datos agrupados por fuente. 
			|Expanda un grupo y seleccione un campo de datos que será la fuente de un valor de la dimensión analítica. 
			|Para seleccionar un valor determinado, cambie a Valor.';
			|tr = 'Aşağıdaki liste, kaynağa göre gruplanmış %1 veri alanlarını gösteriyor. Bir grubu genişletin ve analitik boyut değerinin kaynağı olacak veri alanını seçin. 
			|Belirli bir değer seçmek için Değer''e geçiş yapın.';
			|it = 'L''elenco seguente mostra %1 i campi dati raggruppati per fonte.
			|Espandere un gruppo e selezionare un campo dati che sarà una fonte per un valore di dimensione analitica.
			|Per selezionare un determinato valore, passare a Valore.';
			|de = 'Die folgende Liste zeigt %1 Datenfelder gruppiert nach Quelle an.
			|Erweitern Sie eine Gruppe und wählen Sie ein Datenfeld, das als Quelle für einen Wert von analytischer Messung dienen wird, aus. 
			|Um einen bestimmten Wert auszuwählen, schalten Sie zu Wert um.'"), AdditionalParameter);
	ElsIf Upper(AttributeID) = Upper("DefaultAccountFilter") And Not ChoiceType Then
		ResultText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The following list shows %1 data fields grouped by source. 
			|Expand a group and select a data field that will be a source for a parameter value.'; 
			|ru = 'В списке показаны поля данных %1, сгруппированные по источнику. 
			|Разверните группу и выберите поле данных, которое будет источником значения параметра.';
			|pl = 'Następująca lista wyświetla %1 pola danych, zgrupowane według źródła.
			|Rozwiń grupę i wybierz pole danych, które będzie źródłem dla wartości parametru.';
			|es_ES = 'La siguiente lista muestra%1 los campos de datos agrupados por fuente. 
			|Expanda un grupo y seleccione un campo de datos que será una fuente para un valor de parámetro.';
			|es_CO = 'La siguiente lista muestra%1 los campos de datos agrupados por fuente. 
			|Expanda un grupo y seleccione un campo de datos que será una fuente para un valor de parámetro.';
			|tr = 'Aşağıdaki liste, kaynağa göre gruplanmış %1 veri alanlarını gösteriyor. 
			|Bir grubu genişletin ve parametre değerinin kaynağı olacak veri alanını seçin.';
			|it = 'L''elenco seguente mostra %1i campi dati raggruppati per fonte.
			|Espandere un gruppo e selezionare un campo dati che sarà la fonte per il valore del parametro.';
			|de = 'Die folgende Liste zeigt %1 Datenfelder gruppiert nach Quelle an.
			|Erweitern Sie eine Gruppe und wählen Sie ein Datenfeld, das als Quelle für einen Parameterwert dienen wird, aus. '"), AdditionalParameter);
	ElsIf Upper(AttributeID) = Upper("Quantity") And AdditionalParameter = "" Then
		ResultText = NStr("en = 'The following list shows data fields with numeric values grouped by source. Expand a group and select a source data field to determine the account quantity.'; ru = 'В списке показаны поля данных с числовыми значениями, сгруппированные по источнику. Разверните группу и выберите поле исходных данных, чтобы определить количество по счету.';pl = 'Następująca lista wyświetla pola danych z wartościami numerycznymi, zgrupowane według źródła. Rozwiń grupę i wybierz źródłowe pole danych do określenia ilości konta.';es_ES = 'La siguiente lista muestra los campos de datos con valores numéricos agrupados por fuente. Expanda un grupo y seleccione un campo de datos de origen para determinar la cantidad de la cuenta.';es_CO = 'La siguiente lista muestra los campos de datos con valores numéricos agrupados por fuente. Expanda un grupo y seleccione un campo de datos de origen para determinar la cantidad de la cuenta.';tr = 'Aşağıdaki liste, kaynağa göre gruplanmış sayısal değerli veri alanlarını gösteriyor. Hesap miktarını belirlemek için bir grubu genişletip kaynak veri alanı seçin.';it = 'L''elenco seguente mostra i campi dati con valori numerici raggruppati per fonte. Espandere un gruppo e selezionare un campo dati fonti per determinare la quantità di conto.';de = 'Die folgende Liste zeigt die Datenfelder mit numerischen Werten gruppiert nach Quelle an. Erweitern Sie eine Gruppe und wählen Sie ein Feld von Quelldaten aus, um die Kontenmenge festzulegen.'");
	ElsIf Upper(AttributeID) = Upper("Quantity") And AdditionalParameter = "Dr" Then
		ResultText = NStr("en = 'The following list shows data fields with numeric values grouped by source. Expand a group and select a source data field to determine the debit account quantity.'; ru = 'В списке показаны поля данных с числовыми значениями, сгруппированные по источнику. Разверните группу и выберите поле исходных данных, чтобы определить количество по дебетовому счету.';pl = 'Następująca lista wyświetla pola danych z wartościami numerycznymi, zgrupowane według źródła. Rozwiń grupę i wybierz źródłowe pole danych do określenia ilości konta zobowiązania.';es_ES = 'La siguiente lista muestra los campos de datos con valores numéricos agrupados por fuente. Expanda un grupo y seleccione un campo de datos de origen para determinar la cantidad de la cuenta de débito.';es_CO = 'La siguiente lista muestra los campos de datos con valores numéricos agrupados por fuente. Expanda un grupo y seleccione un campo de datos de origen para determinar la cantidad de la cuenta de débito.';tr = 'Aşağıdaki liste, kaynağa göre gruplanmış sayısal değerli veri alanlarını gösteriyor. Borç hesabı miktarını belirlemek için bir grubu genişletip kaynak veri alanı seçin.';it = 'L''elenco seguente mostra i campi dati con valori numerici raggruppati per fonte. Espandere un gruppo e selezionare un campo dati fonte per determinare la quantità del conto di debito.';de = 'Die folgende Liste zeigt die Datenfelder mit numerischen Werten gruppiert nach Quelle an. Erweitern Sie eine Gruppe und wählen Sie ein Feld von Quelldaten aus, um die Soll-Kontenmenge festzulegen.'");
	ElsIf Upper(AttributeID) = Upper("Quantity") And AdditionalParameter = "Cr" Then
		ResultText = NStr("en = 'The following list shows data fields with numeric values grouped by source. Expand a group and select a source data field to determine the credit account quantity.'; ru = 'В списке показаны поля данных с числовыми значениями, сгруппированные по источнику. Разверните группу и выберите поле исходных данных, чтобы определить количество по кредитовому счету.';pl = 'Następująca lista wyświetla pola danych z wartościami numerycznymi, zgrupowane według źródła. Rozwiń grupę i wybierz źródłowe pole danych do określenia ilości konta należności.';es_ES = 'La siguiente lista muestra los campos de datos con valores numéricos agrupados por fuente. Expanda un grupo y seleccione un campo de datos de origen para determinar la cantidad de la cuenta de crédito.';es_CO = 'La siguiente lista muestra los campos de datos con valores numéricos agrupados por fuente. Expanda un grupo y seleccione un campo de datos de origen para determinar la cantidad de la cuenta de crédito.';tr = 'Aşağıdaki liste, kaynağa göre gruplanmış sayısal değerli veri alanlarını gösteriyor. Alacak hesabı miktarını belirlemek için bir grubu genişletip kaynak veri alanı seçin.';it = 'L''elenco seguente mostra i campi dati con valori numerici raggruppati per fonte. Espandere un gruppo e selezionare un campo dati fonte per determinare la quantità del conto di credito.';de = 'Die folgende Liste zeigt die Datenfelder mit numerischen Werten gruppiert nach Quelle an. Erweitern Sie eine Gruppe und wählen Sie ein Feld von Quelldaten aus, um die Haben-Kontenmenge festzulegen.'");
	ElsIf Upper(AttributeID) = Upper("currency") And AdditionalParameter = "" Then
		ResultText = NStr("en = 'The following list shows currency fields grouped by source. Expand a group and select a source data field to determine the account currency.'; ru = 'В списке показаны поля валют, сгруппированные по источнику. Разверните группу и выберите поле исходных данных для определения валюты счета.';pl = 'Następująca lista wyświetla pola waluta, zgrupowane według źródła. Rozwiń grupę i wybierz źródłowe pole danych do określenia waluty konta.';es_ES = 'La siguiente lista muestra los campos de moneda agrupados por fuente. Expanda un grupo y seleccione un campo de datos de origen para determinar la moneda de la cuenta.';es_CO = 'La siguiente lista muestra los campos de moneda agrupados por fuente. Expanda un grupo y seleccione un campo de datos de origen para determinar la moneda de la cuenta.';tr = 'Aşağıdaki liste, kaynağa göre gruplanmış para birimi alanlarını gösteriyor. Hesap para birimini belirlemek için bir grubu genişletip kaynak veri alanı seçin.';it = 'L''elenco seguente mostra i campi valuta raggruppati per fonte. Espandere un gruppo e selezionare un campo dati fonte per determinare la valuta di conto.';de = 'Die folgende Liste zeigt die Währungsfelder gruppiert nach Quelle an. Erweitern Sie eine Gruppe und wählen Sie ein Feld von Quelldaten aus, um die Kontowährung festzulegen.'");
	ElsIf Upper(AttributeID) = Upper("currency") And AdditionalParameter = "Dr" Then
		ResultText = NStr("en = 'The following list shows currency fields grouped by source. Expand a group and select a source data field to determine the debit account transaction currency.'; ru = 'В списке показаны поля валют, сгруппированные по источнику. Разверните группу и выберите поле исходных данных для определения валюты операции дебетового счета.';pl = 'Następująca lista wyświetla pola waluta, zgrupowane według źródła. Rozwiń grupę i wybierz źródłowe pole danych do określenia waluty transakcji konta zobowiązania.';es_ES = 'La siguiente lista muestra los campos de moneda agrupados por fuente. Expanda un grupo y seleccione un campo de datos de origen para determinar la moneda de la transacción de la cuenta de débito.';es_CO = 'La siguiente lista muestra los campos de moneda agrupados por fuente. Expanda un grupo y seleccione un campo de datos de origen para determinar la moneda de la transacción de la cuenta de débito.';tr = 'Aşağıdaki liste, kaynağa göre gruplanmış para birimi alanlarını gösteriyor. Borç hesabı işlem para birimini belirlemek için bir grubu genişletip kaynak veri alanı seçin.';it = 'L''elenco successivo mostra i campi valuta raggruppati per fonte. Espandere un gruppo e selezionare un campo dati fonte per determinare la valuta della transazione del conto di debito.';de = 'Die folgende Liste zeigt die Währungsfelder gruppiert nach Quelle an. Erweitern Sie eine Gruppe und wählen Sie ein Feld von Quelldaten aus, um die Soll-Kontentransaktionswährung festzulegen.'");
	ElsIf Upper(AttributeID) = Upper("currency") And AdditionalParameter = "Cr" Then
		ResultText = NStr("en = 'The following list shows currency fields grouped by source. Expand a group and select a source data field to determine the credit account transaction currency.'; ru = 'В списке показаны поля валют, сгруппированные по источнику. Разверните группу и выберите поле исходных данных для определения валюты операции кредитового счета.';pl = 'Następująca lista wyświetla pola waluta, zgrupowane według źródła. Rozwiń grupę i wybierz źródłowe pole danych do określenia waluty transakcji konta należności.';es_ES = 'La siguiente lista muestra los campos de moneda agrupados por fuente. Expanda un grupo y seleccione un campo de datos de origen para determinar la moneda de la transacción de la cuenta de crédito.';es_CO = 'La siguiente lista muestra los campos de moneda agrupados por fuente. Expanda un grupo y seleccione un campo de datos de origen para determinar la moneda de la transacción de la cuenta de crédito.';tr = 'Aşağıdaki liste, kaynağa göre gruplanmış para birimi alanlarını gösteriyor. Alacak hesabı işlem para birimini belirlemek için bir grubu genişletip kaynak veri alanı seçin.';it = 'L''elenco seguente mostra i campi valuta raggruppati per fonte. Espandere un gruppo e selezionare un campo dati fonte per determinare la valuta della transazione del conto di credito.';de = 'Die folgende Liste zeigt die Währungsfelder gruppiert nach Quelle an. Erweitern Sie eine Gruppe und wählen Sie ein Feld von Quelldaten aus, um die Haben-Kontotransaktionswährung festzulegen.'");
	ElsIf Upper(AttributeID) = Upper("AmountCur") And AdditionalParameter = "" Then
		ResultText = NStr("en = 'Specify a rule to determine the account amount in the transaction currency. To take the amount from a certain field, click Data field and select a field from the list. The fields are grouped by source.
			|To calculate the amount by formula, click Formula and create a formula.'; 
			|ru = 'Укажите правило для определения суммы счета в валюте операции. Чтобы взять сумму из определенного поля, нажмите ""Поле данных"" и выберите поле из списка. Поля сгруппированы по источнику.
			|Чтобы рассчитать сумму по формуле, нажмите ""Формула"" и создайте формулу.';
			|pl = 'Wybierz regułę do określenia wartości konta w walucie transakcji. Aby wziąć wartość z określonego pola, kliknij pole danych i wybierz pole z listy. Pola są grupowane według źródła.
			|Aby obliczyć wartość według formuły, kliknij Formuła i utwórz formułę.';
			|es_ES = 'Especifique una regla para determinar el importe de la cuenta en la moneda de la transacción. Para extraer el importe de un campo determinado, haga clic en Campo de datos y seleccione un campo de la lista. Los campos se agrupan por fuente. 
			|Para calcular el importe mediante una fórmula, haga clic en Fórmula y cree una fórmula.';
			|es_CO = 'Especifique una regla para determinar el importe de la cuenta en la moneda de la transacción. Para extraer el importe de un campo determinado, haga clic en Campo de datos y seleccione un campo de la lista. Los campos se agrupan por fuente. 
			|Para calcular el importe mediante una fórmula, haga clic en Fórmula y cree una fórmula.';
			|tr = 'İşlem para birimindeki hesap tutarını belirlemek için kural belirtin. Tutarı belirli bir alandan almak için veri alanına tıklayın ve listeden bir alan seçin. Alanlar kaynağa göre gruplanır.
			|Tutarı formülle hesaplamak için Formül''e tıklayıp formül oluşturun.';
			|it = 'Indicare una regola per determinare l''importo del conto nella valuta di transazione. Per ricavare l''importo da un certo campo, cliccare su Campo dati e selezionare un campo dall''elenco. I campi sono raggruppati per fonte.
			| Per calcolare l''importo tramite formula, cliccare su Formula e crearne una.';
			|de = 'Geben Sie eine Regel zum Festlegen des Kontobetrags in der Transaktionswährung ein. Um den Betrag aus einem bestimmten Feld zu entnehmen, klicken Sie auf Datenfeld und wählen ein Feld aus der Liste aus. Die Felder sind nach Quelle gruppiert.
			|Um den Betrag nach Formel zu berechnen, klicken Sie auf Formel und erstellen Sie eine Formel.'");
	ElsIf Upper(AttributeID) = Upper("AmountCur") And AdditionalParameter = "Dr" Then
		ResultText = NStr("en = 'Specify a rule to determine the debit account amount in the transaction currency. To take the amount from a certain field, click Data field and select a field from the list. The fields are grouped by source.
			|To calculate the amount by formula, click Formula and create a formula.'; 
			|ru = 'Укажите правило для определения суммы дебетового счета в валюте операции. Чтобы взять сумму из определенного поля, нажмите ""Поле данных"" и выберите поле из списка. Поля сгруппированы по источнику.
			|Чтобы рассчитать сумму по формуле, нажмите ""Формула"" и создайте формулу.';
			|pl = 'Wybierz regułę do określenia wartości konta zobowiązania w walucie transakcji. Aby wziąć wartość z określonego pola, kliknij pole danych i wybierz pole z listy. Pola są grupowane według źródła.
			|Aby obliczyć wartość według formuły, kliknij Formuła i utwórz formułę.';
			|es_ES = 'Especifique una regla para determinar el importe de la cuenta en la moneda de la transacción. Para extraer el importe de un campo determinado, haga clic en Campo de datos y seleccione un campo de la lista. Los campos se agrupan por fuente. 
			|Para calcular el importe mediante una fórmula, haga clic en Fórmula y cree una fórmula.';
			|es_CO = 'Especifique una regla para determinar el importe de la cuenta en la moneda de la transacción. Para extraer el importe de un campo determinado, haga clic en Campo de datos y seleccione un campo de la lista. Los campos se agrupan por fuente. 
			|Para calcular el importe mediante una fórmula, haga clic en Fórmula y cree una fórmula.';
			|tr = 'İşlem para birimindeki borç hesabı tutarını belirlemek için kural belirtin. Tutarı belirli bir alandan almak için veri alanına tıklayın ve listeden bir alan seçin. Alanlar kaynağa göre gruplanır.
			|Tutarı formülle hesaplamak için Formül''e tıklayıp formül oluşturun.';
			|it = 'Indicare una regola per determinare l''importo del conto di debito nella valuta della transazione. Per ricavare l''importo da un determinato campo, cliccare su Campo dati e selezionare un campo dall''elenco. I campi sono raggruppati per fonte.
			| Per calcolare l''importo tramite formula, cliccare su Formula e crearne una.';
			|de = 'Geben Sie eine Regel zum Festlegen des Soll-Kontobetrags in der Transaktionswährung ein. Um den Betrag aus einem bestimmten Feld zu entnehmen, klicken Sie auf Datenfeld und wählen ein Feld aus der Liste aus. Die Felder sind nach Quelle gruppiert.
			|Um den Betrag nach Formel zu berechnen, klicken Sie auf Formel und erstellen Sie eine Formel.'");
	ElsIf Upper(AttributeID) = Upper("AmountCur") And AdditionalParameter = "Cr" Then
		ResultText = NStr("en = 'Specify a rule to determine the credit account amount in the transaction currency. To take the amount from a certain field, click Data field and select a field from the list. The fields are grouped by source.
			|To calculate the amount by formula, click Formula and create a formula.'; 
			|ru = 'Укажите правило для определения суммы кредитового счета в валюте операции. Чтобы взять сумму из определенного поля, нажмите ""Поле данных"" и выберите поле из списка. Поля сгруппированы по источнику.
			|Чтобы рассчитать сумму по формуле, нажмите ""Формула"" и создайте формулу.';
			|pl = 'Wybierz regułę do określenia wartości konta należności w walucie transakcji. Aby wziąć wartość z określonego pola, kliknij pole danych i wybierz pole z listy. Pola są grupowane według źródła.
			|Aby obliczyć wartość według formuły, kliknij Formuła i utwórz formułę.';
			|es_ES = 'Especifique una regla para determinar el importe de la cuenta en la moneda de la transacción. Para extraer el importe de un campo determinado, haga clic en Campo de datos y seleccione un campo de la lista. Los campos se agrupan por fuente. 
			|Para calcular el importe mediante una fórmula, haga clic en Fórmula y cree una fórmula.';
			|es_CO = 'Especifique una regla para determinar el importe de la cuenta en la moneda de la transacción. Para extraer el importe de un campo determinado, haga clic en Campo de datos y seleccione un campo de la lista. Los campos se agrupan por fuente. 
			|Para calcular el importe mediante una fórmula, haga clic en Fórmula y cree una fórmula.';
			|tr = 'İşlem para birimindeki alacak hesabı tutarını belirlemek için kural belirtin. Tutarı belirli bir alandan almak için veri alanına tıklayın ve listeden bir alan seçin. Alanlar kaynağa göre gruplanır.
			|Tutarı formülle hesaplamak için Formül''e tıklayıp formül oluşturun.';
			|it = 'Indicare una regola per determinare l''importo del conto di credito nella valuta della transazione. Per ricavare l''importo da un determinato campo, cliccare su Campo dati e selezionare un campo dall''elenco. I campi sono raggruppati per fonte.
			|Per calcolare l''importo tramite formula, cliccare su Formula e crearne una.';
			|de = 'Geben Sie eine Regel zum Festlegen des Haben-Kontobetrags in der Transaktionswährung ein. Um den Betrag aus einem bestimmten Feld zu entnehmen, klicken Sie auf Datenfeld und wählen ein Feld aus der Liste aus. Die Felder sind nach Quelle gruppiert.
			|Um den Betrag nach Formel zu berechnen, klicken Sie auf Formel und erstellen Sie eine Formel.'");
	ElsIf Upper(AttributeID) = Upper("PresentationCurrency") Then
		ResultText = NStr("en = 'The following list shows currency fields grouped by source. Expand a group and select a source data field to determine the presentation currency.'; ru = 'В списке показаны поля валют, сгруппированные по источнику. Разверните группу и выберите поле исходных данных для определения валюты представления отчетности.';pl = 'Następująca lista wyświetla pola waluta, zgrupowane według źródła. Rozwiń grupę i wybierz źródłowe pole danych do określenia waluty prezentacji.';es_ES = 'La siguiente lista muestra los campos de moneda agrupados por fuente. Expanda un grupo y seleccione un campo de datos de origen para determinar la moneda de presentación.';es_CO = 'La siguiente lista muestra los campos de moneda agrupados por fuente. Expanda un grupo y seleccione un campo de datos de origen para determinar la moneda de presentación.';tr = 'Aşağıdaki liste, kaynağa göre gruplanmış para birimi alanlarını gösteriyor. Finansal tablo para birimini belirlemek için bir grubu genişletip kaynak veri alanı seçin.';it = 'L''elenco seguente mostra i campi valuta raggruppati per fonte. Espandere un gruppo e selezionare un campo dati fonte per determinare la valuta di presentazione.';de = 'Die folgende Liste zeigt die Währungsfelder gruppiert nach Quelle an. Erweitern Sie eine Gruppe und wählen Sie ein Feld von Quelldaten aus, um die Kontowährung festzulegen.'");
	ElsIf Upper(AttributeID) = Upper("amount") Then
		ResultText = NStr("en = 'Specify a rule to determine the amount in the presentation currency. To take the amount from a certain field, click Data field and select a field from the table. The fields are grouped by source.
			|To calculate the amount by formula, click Formula and create a formula.'; 
			|ru = 'Укажите правило для определения суммы в валюте представления отчетности. Чтобы взять сумму из определенного поля, нажмите ""Поле данных"" и выберите поле из таблицы. Поля сгруппированы по источнику.
			|Чтобы рассчитать сумму по формуле, нажмите ""Формула"" и создайте формулу.';
			|pl = 'Wybierz regułę do określenia kwoty w walucie prezentacji. Aby wziąć wartość z określonego pola, kliknij pole Dane i wybierz pole z tabeli. Pola są grupowane według źródła.
			|Aby obliczyć wartość według formuły, kliknij Formuła i utwórz formułę.';
			|es_ES = 'Especifique una regla para determinar el importe en la moneda de presentación. Para extraer el importe de un campo determinado, haga clic en Campo de datos y seleccione un campo de la tabla. Los campos se agrupan por fuente.
			| Para calcular el importe mediante una fórmula, haga clic en Fórmula y cree una fórmula.';
			|es_CO = 'Especifique una regla para determinar el importe en la moneda de presentación. Para extraer el importe de un campo determinado, haga clic en Campo de datos y seleccione un campo de la tabla. Los campos se agrupan por fuente.
			| Para calcular el importe mediante una fórmula, haga clic en Fórmula y cree una fórmula.';
			|tr = 'Finansal tablo para birimindeki hesap tutarını belirlemek için kural belirtin. Tutarı belirli bir alandan almak için veri alanına tıklayın ve listeden bir alan seçin. Alanlar kaynağa göre gruplanır.
			|Tutarı formülle hesaplamak için Formül''e tıklayıp formül oluşturun.';
			|it = 'Indicare una regola per determinare l''importo nella valuta di presentazione. Per ricavare un importo da un determinato campo, cliccare su Campo dati e selezionare un campo dalla tabella. I campi sono raggruppati per fonte.
			|Per calcolare l''importo tramite formula, cliccare su Formula e crearne una.';
			|de = 'Geben Sie eine Regel zum Festlegen des Kontobetrags in der Währung für die Berichtserstattung ein. Um den Betrag aus einem bestimmten Feld zu entnehmen, klicken Sie auf Datenfeld und wählen ein Feld aus der Tabelle aus. Die Felder sind nach Quelle gruppiert.
			|Um den Betrag nach Formel zu berechnen, klicken Sie auf Formel und erstellen Sie eine Formel.'");
	Else
		
	EndIf;
	
	Return ResultText;
	
EndFunction

Function GetManagerialAnalyticalDimensionTypeLeftWarning() Export
	Return NStr("en = 'Analytical dimension ""%1"" is applied to analytical dimension sets, accounts, or accounting entry templates. It is recommended to review the accounting entries, accounting entries templates, and accounting transaction templates where this account is applied and adjust them if needed. Continue?'; ru = 'Аналитическое измерение ""%1"" применяется в наборах аналитических измерений, счетах или шаблонах бухгалтерских проводок. Рекомендуется просмотреть бухгалтерские проводки, шаблоны бухгалтерских проводок и шаблоны бухгалтерских операций, в которых применяется этот счет, и скорректировать их при необходимости. Продолжить?';pl = 'Wymiar analityczny ""%1"" jest zastosowany do zestawów wymiarów analitycznych, kont lub szablonów wpisów księgowych. Zaleca się przejrzenie wpisów księgowych, szablonów wpisów księgowych i szablonów transakcji księgowych, gdzie to konto jest zastosowane i zmienić go w razie potrzeby. Kontynuować?';es_ES = 'La dimensión analítica ""%1"" se aplica a los conjuntos de dimensiones analíticas, a las cuentas o a las plantillas de entradas contables. Se recomienda revisar las entradas contables, las plantillas de entradas contables y las plantillas de transacciones contables donde se aplica esta cuenta y ajustarlas si es necesario. ¿Continuar?';es_CO = 'La dimensión analítica ""%1"" se aplica a los conjuntos de dimensiones analíticas, a las cuentas o a las plantillas de entradas contables. Se recomienda revisar las entradas contables, las plantillas de entradas contables y las plantillas de transacciones contables donde se aplica esta cuenta y ajustarlas si es necesario. ¿Continuar?';tr = '""%1"" analitik boyutu analitik boyut kümelerine, hesaplara veya muhasebe girişi şablonlarına uygulanıyor. Bu hesabın uygulandığı muhasebe girişlerini, muhasebe girişi şablonlarını ve muhasebe işlemi şablonlarını inceleyip gerekirse düzeltmeniz önerilir. Devam edilsin mi?';it = 'La dimensione analitica ""%1"" è applicata a set di dimensioni analitiche, conti o modelli di voci di contabilità. Si consiglia di rivedere le voci di contabilità, i modelli di voci di contabilità e i modelli di transazione di contabilità in cui questo conto è applicato e correggerli se necessario. Continuare?';de = 'Analytische Messung ""%1"" ist für Sätze von analytischer Messung, Konten oder Buchungsvorlagen verwendet. Es ist empfehlenswert die Buchungen, Buchungsvorlagen und Buchhaltungstransaktionsvorlagen wo dieses Konto verwendet ist zu überprüfen und sie ggf. anzupassen. Weiter?'");
EndFunction 	

Function GetManagerialAnalyticalDimensionSaveErrorText() Export
	Return NStr("en = 'Cannot save the changes. Analytical dimension ""%1"" is applied to analytical dimension sets, accounts, or accounting entry templates.'; ru = 'Не удалось сохранить изменения. Аналитическое измерение ""%1"" уже используется в наборах аналитических измерений, счетах или шаблонах бухгалтерских проводок.';pl = 'Nie można zapisać zmian. Wymiar analityczny ""%1"" jest zastosowany do zestawów wymiarów analitycznych, kont, lub szablonów wpisów księgowych.';es_ES = 'No se pueden guardar los cambios. La dimensión analítica ""%1"" se aplica a conjuntos de dimensiones analíticas, cuentas o plantillas de entrada contables.';es_CO = 'No se pueden guardar los cambios. La dimensión analítica ""%1"" se aplica a conjuntos de dimensiones analíticas, cuentas o plantillas de entrada contables.';tr = 'Değişiklikler kaydedilemiyor. ""%1"" analitik boyutu analitik boyut kümelerine, hesaplara veya muhasebe girişi şablonlarına uygulanıyor.';it = 'Impossibile salvare le modifiche. La dimensione analitica ""%1"" è applicata a set di dimensioni analitiche, conti o modelli di voci di contabilità.';de = 'Fehler beim Speichern von Änderungen. Analytische Messung ""%1"" ist für Sätze analytischer Messung, Konten oder Buchungsvorlagen verwendet.'");
EndFunction

Function GetMasterChartOfAccountsActiveToErrorText() Export
	Return NStr("en = '""Active to"" date must be equal to or later than ""Active from"" date. Edit ""Active to"" date. Then try again.'; ru = 'Дата в поле ""Активен до"" не может быть меньше даты в поле ""Активен с"". Отредактируйте дату в поле ""Активен по"" и повторите попытку.';pl = 'Data ""Aktywny do"" musi być równa lub późniejsza niż data ""Aktywny od"". Edytuj datę ""Aktywny do"". Zatem spróbuj ponownie.';es_ES = 'La fecha ""Activo hasta"" debe ser igual o posterior a la fecha ""Activo desde"". Edite la fecha ""Activo hasta"". Inténtelo de nuevo.';es_CO = 'La fecha ""Activo hasta"" debe ser igual o posterior a la fecha ""Activo desde"". Edite la fecha ""Activo hasta"". Inténtelo de nuevo.';tr = '""Aktivasyon bitişi"" tarihi ""Aktivasyon başlangıcı"" tarihi ile aynı veya daha sonra olmalıdır. ""Aktivasyon bitişi"" tarihini değiştirip tekrar deneyin.';it = 'La data ""Attivo fino a"" deve essere pari o successiva alla data ""Attivo da"". Modificare la data ""Attivo fino a"", poi riprovare.';de = '""Aktiv bis "" muss gleich oder später als Datum ""Aktiv vom "" liegen. Bearbeiten Sie das Datum ""Aktiv bis"". Dann versuchen Sie erneut.'");
EndFunction

Function GetMasterChartOfAccountsActiveToComapniesErrorText() Export
	Return NStr("en = '""Active to"" date of account must be equal to or later than ""Active to"" dates specified on Companies’ tab. 
					|Edit ""Active to"" date of an account. Then try again.'; 
					|ru = 'Дата в поле ""Активен до"" этого счета не может быть меньше даты в поле ""Активен с"", указанной на вкладке ""Организации"". 
					|Отредактируйте дату в поле ""Активен до"" и повторите попытку.';
					|pl = 'Data ""Aktywny do"" konta musi być równa lub nie mniejsza niż daty ""Aktywny do"", określone na karcie Firmy. 
					|Edytuj datę ""Aktywny do"" konta. Zatem spróbuj ponownie.';
					|es_ES = 'La fecha ""Activo hasta"" de una cuenta debe ser igual o posterior a las fechas ""Activo hasta"" especificadas en la pestaña Empresas. 
					|Edite la fecha ""Activo hasta"" de una cuenta. Inténtelo de nuevo.';
					|es_CO = 'La fecha ""Activo hasta"" de una cuenta debe ser igual o posterior a las fechas ""Activo hasta"" especificadas en la pestaña Empresas. 
					|Edite la fecha ""Activo hasta"" de una cuenta. Inténtelo de nuevo.';
					|tr = 'Hesabın ""Aktivasyon bitişi"" tarihi, İş yerleri sekmesinde belirtilen ""Aktivasyon bitişi"" tarihleri ile aynı ve daha sonra olmalıdır. 
					|Hesabın ""Aktivasyon bitişi"" tarihini düzenleyip tekrar deneyin.';
					|it = 'La data del conto ""Attivo fino a"" deve essere pari o successivo alla data ""Attivo fino a"" indicata sulla scheda Aziende.
					|Modificare la data ""Attiva fino a"" di questo conto, poi riprovare.';
					|de = 'Das Datum des Kontos ""Aktiv bis "" muss gleich oder später als Daten ""Aktiv vom "", angegeben auf der Registerkarte Firmen liegen. Bearbeiten Sie das Datum des Kontos ""Aktiv bis"". Dann versuchen Sie erneut.'");
EndFunction

Function GetMasterChartOfAccountsActiveFromErrorText() Export
	Return NStr("en = '""Active from"" date of account must be equal to or less than 
					|""Active from"" dates specified on Companies tab. 
					|Edit ""Active from"" date of account. Then try again.'; 
					|ru = 'Дата в поле ""Активен с"" этого счета не может быть больше даты в поле ""Активен до"", указанной на вкладке ""Организации"". 
					|Отредактируйте дату в поле ""Активен с"" и повторите попытку.';
					|pl = 'Data ""Aktywny od"" konta musi być równa lub mniejsza niż 
					|daty ""Aktywny od"", określone na karcie Firmy. 
					|Edytuj datę ""Aktywny od"" konta. Zatem spróbuj ponownie.';
					|es_ES = 'La fecha ""Activo desde"" de la cuenta debe ser igual o menor que las fechas ""Activo desde"" especificadas en la pestaña Empresas. 
					|Edite la fecha ""Activo desde"" de la cuenta. Inténtelo de nuevo.';
					|es_CO = 'La fecha ""Activo desde"" de la cuenta debe ser igual o menor que las fechas ""Activo desde"" especificadas en la pestaña Empresas. 
					|Edite la fecha ""Activo desde"" de la cuenta. Inténtelo de nuevo.';
					|tr = 'Hesabın ""Aktivasyon başlangıcı"" tarihi, İş yerleri sekmesinde belirtilen ""Aktivasyon başlangıcı"" tarihleri ile aynı ve daha önce olmalıdır. 
					|Hesabın ""Aktivasyon başlangıcı"" tarihini düzenleyip tekrar deneyin.';
					|it = 'La data del conto ""Attivo da"" deve essere pari o precedente alle dati 
					|""Attivo da"" indicate nella scheda Aziende.
					|Modificare la data del conto ""Attivo da"", poi riprovare.';
					|de = 'Das Datum des Kontos ""Aktiv vom"" muss gleich oder weniger als Daten ""Aktiv vom "", angegeben auf der Registerkarte Firmen liegen. Bearbeiten Sie das Datum des Kontos ""Aktiv vom"". Dann versuchen Sie erneut.'")
EndFunction

Function GetMasterChartOfAccountsCompanySelectionErrorText() Export
	Return NStr("en = 'Cannot save the changes. Duplicate companies are specified in lines #%1. Remove the duplicates. Then try again.'; ru = 'Не удалось сохранить изменения. В строках №%1 указаны одинаковые организации. Удалите дубликаты и повторите попытку.';pl = 'Nie można zapisać zmian. Zduplikowane firmy są określony w wierszach nr%1. Usuń duplikaty. Zatem spróbuj ponownie.';es_ES = 'No se pueden guardar los cambios. Hay empresas duplicadas en las líneas #%1. Elimine los duplicados. Inténtelo de nuevo.';es_CO = 'No se pueden guardar los cambios. Hay empresas duplicadas en las líneas #%1. Elimine los duplicados. Inténtelo de nuevo.';tr = 'Değişiklikler kaydedilemiyor. %1 satırlarında tekrarlayan iş yerleri belirtilmiş. Tekrarları çıkarıp yeniden deneyin.';it = 'Impossibile salvare le modifiche. Le aziende duplicate sono indicate nella riga #%1. Rimuovere i duplicati, poi riprovare.';de = 'Fehler beim Speichern von Änderungen. Verdoppelte Firmen sind in Zeilen Nr. %1 angegeben. Entfernen Sie Duplikate. Dann versuchen Sie erneut.'");
EndFunction

Function GetMasterChartOfAccountsNotUniqueCodeErrorText() Export
	Return NStr("en = 'The value ""%1"" of the field ""Code"" is not unique.'; ru = 'Значение ""%1"" поля ""Код"" уже существует.';pl = 'Wartość ""%1"" pola ""Kod"" nie jest unikalna.';es_ES = 'El valor ""%1"" del campo ""Código"" no es único.';es_CO = 'El valor ""%1"" del campo ""Código"" no es único.';tr = '""Kod"" alanının ""%1"" değeri benzersiz değil.';it = 'Il valore ""%1"" del campo ""Codice"" non è univoco.';de = 'Der Wert ""%1"" des Felds ""Code"" ist nicht einzigartig.'");
EndFunction

Function GetMasterChartOfAccountsFieldIsRequiredErrorText() Export
	Return NStr("en = '""%1"" is a required field.'; ru = 'Заполните поле ""%1"".';pl = 'Pole ""%1"" jest wymagane';es_ES = '""%1"" es un campo obligatorio.';es_CO = '""%1"" es un campo obligatorio.';tr = '""%1"" zorunlu alandır.';it = '""%1"" è un campo richiesto.';de = '""%1"" ist ein Pflichtfeld.'");
EndFunction

Function GetMasterChartOfAccountsQuantitySettingsErrorTemplate() Export
	Return NStr("en = 'Check entries template ""%1"" for quantity settings in line %2.'; ru = 'Проверьте настройки количества в строке %2 шаблона проводок ""%1"".';pl = 'Sprawdź szablon wpisów ""%1"" dla ustawień ilości w wierszu %2.';es_ES = 'Compruebe la plantilla de entradas de diario ""%1"" para los ajustes de cantidad en la línea %2.';es_CO = 'Compruebe la plantilla de entradas de diario ""%1"" para los ajustes de cantidad en la línea %2.';tr = '%2 satırında miktar ayarları için ""%1"" giriş şablonunu kontrol edin.';it = 'Controllare il modello di voci ""%1"" per le impostazioni di quantità nella riga %2.';de = 'Buchungsvorlage ""%1"" für Mengeneinstellungen in Zeile %2 überprüfen.'");
EndFunction

Function GetMasterChartOfAccountsDimensionsSettingsErrorTemplate() Export
	Return NStr("en = 'Check entries template ""%1"" for Analytical dimensions settings in line %2.'; ru = 'Проверьте настройки аналитических измерений в строке %2 шаблона проводок ""%1"".';pl = 'Sprawdź szablon wpisów ""%1"" dla ustawień wymiarów analitycznych w wierszu %2.';es_ES = 'Compruebe la plantilla de entradas de diario ""%1"" para los ajustes de las dimensiones analíticas en la línea %2.';es_CO = 'Compruebe la plantilla de entradas de diario ""%1"" para los ajustes de las dimensiones analíticas en la línea %2.';tr = '%2 satırında Analitik boyut ayarları için ""%1"" giriş şablonunu kontrol edin.';it = 'Controllare il modello di voci ""%1"" per le impostazioni di dimensioni analitiche nella riga %2.';de = 'Buchungsvorlage ""%1"" für Einstellungen von analytischen Messungen in Zeile %2 überprüfen.'")
EndFunction

Function GetAccountingTransactionsTemplatesChageStateSaveTemplateWarning() Export
	Return NStr("en = 'To apply the %1 status, save the template.'; ru = 'Для применения статуса %1 нужно сохранить шаблон.';pl = 'Aby zastosować status %1, zapisz szablon.';es_ES = 'Para aplicar el estado %1, guarda la plantilla.';es_CO = 'Para aplicar el estado %1, guarda la plantilla.';tr = '%1 durumunu uygulamak için şablonu kaydedin.';it = 'Per applicare lo stato %1, salvare il modello.';de = 'Speichern Sie die Vorlage, um den Status %1 zu verwenden.'");
EndFunction

Function GetAccountingTransactionsTemplatesDocumentTypeIsRequiredErrorText() Export
	Return NStr("en = 'Document type is required. Specify it and try again.'; ru = 'Укажите тип документа и повторите попытку.';pl = 'Typ dokumentu jest wymagany. Określ go i spróbuj ponownie.';es_ES = 'Se requiere el tipo de documento. Especifíquelo e inténtelo de nuevo.';es_CO = 'Se requiere el tipo de documento. Especifíquelo e inténtelo de nuevo.';tr = 'Belge türünü belirtip tekrar deneyin.';it = 'È richiesto il tipo di documento. Indicarlo e riprovare.';de = 'Dokumententyp is erforderlich. Geben Sie ihn ein und versuchen erneut.'");
EndFunction

Function GetAccountingTransactionsTemplatesParameterChangedQuestion() Export
	Return NStr("en = 'After you change the parameter, the Entries tab will be cleared. Continue?'; ru = 'Изменение параметра приведет к очищению вкладки ""Проводки"". Продолжить?';pl = 'Po tym jak zmienisz parametr, karta Wpisy zostanie wyczyszczona. Kontynuować?';es_ES = 'Después de cambiar el parámetro, la pestaña Entradas de diario se borrará. ¿Continuar?';es_CO = 'Después de cambiar el parámetro, la pestaña Entradas de diario se borrará. ¿Continuar?';tr = 'Parametre değiştirildikten sonra Girişler sekmesi temizlenecek. Devam edilsin mi?';it = 'Dopo la modifica del parametro, la scheda Voci sarà cancellata. Continuare?';de = 'Nachdem Sie die Parameter ändern, wird die Registerkarte Buchungen gelöscht. Weiter?'");
EndFunction

Function GetAccountingTransactionsTemplatesParameterAddedQuestion() Export
	Return NStr("en = 'After you add a parameter, the Entries tab will be cleared. Continue?'; ru = 'Добавление параметра приведет к очищению вкладки ""Проводки"". Продолжить?';pl = 'Po tym jak dodasz parametr, karta Wpisy zostanie wyczyszczona. Kontynuować?';es_ES = 'Después de añadir un parámetro, la pestaña Entradas de diario se borrará. ¿Continuar?';es_CO = 'Después de añadir un parámetro, la pestaña Entradas de diario se borrará. ¿Continuar?';tr = 'Parametre eklendikten sonra Girişler sekmesi temizlenecek. Devam edilsin mi?';it = 'Dopo aver aggiunto un parametro, la scheda Voci sarà cancellata. Continuare?';de = 'Nachdem Sie die Parameter hinzufügen, wird die Registerkarte Buchungen gelöscht. Weiter?'");
EndFunction

Function GetAccountingTransactionsTemplatesParameterDeletedQuestion() Export
	Return NStr("en = 'After you delete the parameter, the Entries tab will be cleared. Continue?'; ru = 'Удаление параметра приведет к очищению вкладки ""Проводки"". Продолжить?';pl = 'Po tym jak usuniesz parametr, karta Wpisy zostanie wyczyszczona. Kontynuować?';es_ES = 'Después de eliminar el parámetro, la pestaña Entradas de diario se borrará. ¿Continuar?';es_CO = 'Después de eliminar el parámetro, la pestaña Entradas de diario se borrará. ¿Continuar?';tr = 'Parametre silindikten sonra Girişler sekmesi temizlenecek. Devam edilsin mi?';it = 'Dopo aver eliminato il parametro, la scheda Voci sarà cancellata. Continuare?';de = 'Nachdem Sie die Parameter löschen, wird die Registerkarte Buchungen gelöscht. Weiter?'");
EndFunction

Function GetAccountingTransactionsTemplatesParameterRefillQuestion() Export
	Return NStr("en = 'Parameters will be repopulated. The Entries tab will be cleared. Continue?'; ru = 'Параметры будут перезаполнены. Вкладка ""Проводки"" будет очищена. Продолжить?';pl = 'Parametry zostaną wypełnione ponownie. Karta Wpisy zostanie wyczyszczona. Kontynuować?';es_ES = 'Los parámetros se rellenarán. La pestaña Entradas de diario se borrará. ¿Continuar?';es_CO = 'Los parámetros se rellenarán. La pestaña Entradas de diario se borrará. ¿Continuar?';tr = 'Parametreler çoğaltılacak. Girişler sekmesi temizlenecek. Devam edilsin mi?';it = 'I parametri saranno ricompilati. La scheda Voci sarà cancellata. Continuare?';de = 'Parameter werden neu gebucht. Die die Registerkarte Buchungen wird gelöscht. Weiter?'");
EndFunction

Function GetAccountingTransactionsTemplatesEntriesRefillQuestion() Export
	Return NStr("en = 'Tabular section ""Entries"" will be filled in again. Do you want to continue?'; ru = 'Табличная часть ""Проводки"" будет перезаполнена. Продолжить?';pl = 'Sekcja tabelaryczna ""Wpisy"" zostanie wypełniona ponownie. Czy chcesz kontynuować?';es_ES = 'La sección tabular ""Entradas de diario"" se rellenará de nuevo. ¿Quiere continuar?';es_CO = 'La sección tabular ""Entradas de diario"" se rellenará de nuevo. ¿Quiere continuar?';tr = '""Girişler"" tablo bölümü tekrar doldurulacak. Devam etmek istiyor musunuz?';it = 'La sezione tabellare ""Voci"" sarà compilata nuovamente. Continuare?';de = 'Der tabellarische Abschnitt ""Buchungen"" wird erneut ausgefüllt. Möchten Sie fortsetzen?'");
EndFunction

Function GetAccountingTransactionsTemplatesMoveLineErrorText() Export
	Return NStr("en = 'Cannot move %1 the selected lines. Do any of the following:
		|- Select all lines of the same accounting entries template. Then try again. 
		|- Click Select and, in the ""Selected entries templates"" list, arrange the order of the accounting entries templates.'; 
		|ru = 'Не удалось переместить %1выбранные строки. Выполните одно из следующих действий:
		|- Выберите все строки одного шаблона бухгалтерских проводок и повторите попытку. 
		|- Нажмите ""Подобрать"" и в списке ""Выбранные шаблоны проводок"" упорядочите шаблоны бухгалтерских проводок.';
		|pl = 'Nie można przenieść %1 wybranych wierszy. Wykonaj jedną z następujących czynności:
		|- Wybierz wszystkie wiersze tego samego szablonu wpisów księgowych. Zatem spróbuj ponownie. 
		|- Kliknij Wybierz i na liście ""Wybrane szablony wpisów"", ustal kolejność szablony wpisów księgowych.';
		|es_ES = 'No se pueden mover %1 las líneas seleccionadas. Realice una de las siguientes acciones: 
		|- Seleccione todas las líneas de la misma plantilla de entradas contables. Inténtelo de nuevo. 
		|- Haga clic en Seleccionar y, en la lista ""Plantillas de entradas seleccionadas"", ordene las plantillas de entradas contables.';
		|es_CO = 'No se pueden mover %1 las líneas seleccionadas. Realice una de las siguientes acciones: 
		|- Seleccione todas las líneas de la misma plantilla de entradas contables. Inténtelo de nuevo. 
		|- Haga clic en Seleccionar y, en la lista ""Plantillas de entradas seleccionadas"", ordene las plantillas de entradas contables.';
		|tr = 'Seçilen satırlar %1 taşınamıyor. Şunlardan birini yapın:
		|- Aynı muhasebe girişi şablonunun tüm satırlarını seçip tekrar deneyin. 
		|- Seç''e tıklayın, ""Seçilen giriş şablonları"" listesinde muhasebe girişi şablonlarının sırasını düzenleyin.';
		|it = 'Impossibile spostare%1 le righe selezionate. Eseguire una delle seguenti azioni:
		|- Selezionare tutte le righe dello stesso modello di voci di contabilità, poi riprovare.
		|- Cliccare Seleziona e, nell''elenco ""Modelli di voci selezionate, ordinare i modelli di voci di contabilità.';
		|de = 'Fehler beim Verschieben %1 von ausgewählten Zeilen. Machen Sie eins des Folgenden:
		|- Wählen Sie alle Zeilen derselben Buchungsvorlage aus. Dann versuchen Sie erneut. 
		|- Klicken Sie auf und in der Liste ""Ausgewählte Buchungsvorlagen"" setzen Sie die Ordnung der Buchungsvorlagen fest.'");

EndFunction

Function GetAccountingTransactionsTemplatesValidityPeriodErrorText() Export
	Return NStr("en = 'Fill ""Planned validity period from"". Then try again.'; ru = 'Заполните поле ""Планируемый срок действия с"" и повторите попытку.';pl = 'Wypełnij ""Zaplanowany okres ważności od"". Zatem spróbuj ponownie.';es_ES = 'Rellene ""Periodo de validez planificado desde"". Inténtelo de nuevo.';es_CO = 'Rellene ""Periodo de validez planificado desde"". Inténtelo de nuevo.';tr = '""Planlanan geçerlilik dönemi başlangıcı""nı doldurup tekrar deneyin.';it = 'Compilare ""Periodo di validità pianificata fino a"", poi riprovare.';de = 'Füllen Sie ""Geplante Gültigkeitsdauer von"". Dann versuchen Sie erneut.'");
EndFunction

Function GetAccountingTemplatesValidityPeriodPlannedDateFromErrorText() Export
	Return NStr("en = 'Cannot save changes. Select the ""Planned validity period from"" date that is equal to or earlier than the ""to"" date.'; ru = 'Не удалось сохранить изменения. Укажите в поле ""Планируемый срок действия с"" дату, не превышающую дату в поле ""по"".';pl = 'Nie można zapisać zmian. Wybierz datę Zaplanowany okres ważności od"", która jest równa lub wcześniejsza niż data ""do"".';es_ES = 'No se pueden guardar los cambios. Seleccione la fecha del ""Periodo de validez planificado desde"" que sea igual o anterior a la fecha ""hasta"".';es_CO = 'No se pueden guardar los cambios. Seleccione la fecha del ""Periodo de validez planificado desde"" que sea igual o anterior a la fecha ""hasta"".';tr = 'Değişiklikler kaydedilemiyor. ""Bitiş"" tarihiyle aynı veya daha erken bir ""Planlanan geçerlilik dönemi başlangıcı"" tarihi seçin.';it = 'Impossibile salvare le modifiche. Selezionare la data ""Periodo di validità pianificato da"" che sia pari o precedente alla data ""fino a"".';de = 'Fehler beim Speichern von Änderungen. Wählen Sie das Datum ""Geplante Gültigkeitsdauer von"" das gleich oder vor dem Datum ""bis"" liegt aus.'");
EndFunction

Function GetAccountingTemplatesValidityPeriodPlannedDateTillErrorText() Export
	Return NStr("en = 'Cannot save changes. Select the ""to"" date that is equal to or later than the ""Planned validity period from"" date.'; ru = 'Не удалось сохранить изменения. Укажите в поле ""по"" дату, превышающую дату в поле ""Планируемый срок действия с"".';pl = 'Nie można zapisać zmian. Wybierz datę ""do"", równą lub późniejszą niż data ""Zaplanowany okres ważności od"".';es_ES = 'No se pueden guardar los cambios. Seleccione la fecha ""hasta"" que sea igual o posterior a la fecha ""Periodo de validez planificado desde"".';es_CO = 'No se pueden guardar los cambios. Seleccione la fecha ""hasta"" que sea igual o posterior a la fecha ""Periodo de validez planificado desde"".';tr = 'Değişiklikler kaydedilemiyor. ""Planlanan geçerlilik dönemi başlangıcı"" tarihiyle aynı veya daha geç bir ""bitiş"" tarihi seçin.';it = 'Impossibile salvare le modifiche. Selezionare la data ""fino a"" che sia pari o successiva alla data ""Periodo di validità pianificato fino a"".';de = 'Fehler beim Speichern von Änderungen. Wählen Sie das Datum ""Bis"" das gleich oder nach dem Datum ""bis"" liegt aus.'");
EndFunction

Function GetAccountingTemplatesValidityPeriodDateFromErrorText() Export
	Return NStr("en = 'Cannot save changes. Select the ""From"" date that is equal to or earlier than the ""to"" date.'; ru = 'Не удалось сохранить изменения. Укажите в поле ""С"" дату, не превышающую дату в поле ""до"".';pl = 'Nie można zapisać zmian. Wybierz datę ""Od"", która jest równa lub wcześniejsza niż data ""do"".';es_ES = 'No se pueden guardar los cambios. Seleccione la fecha ""Desde"" que sea igual o anterior a la fecha ""hasta"".';es_CO = 'No se pueden guardar los cambios. Seleccione la fecha ""Desde"" que sea igual o anterior a la fecha ""hasta"".';tr = 'Değişiklikler kaydedilemiyor. ""Bitiş"" tarihiyle aynı veya daha erken bir ""Başlangıç"" tarihi seçin.';it = 'Impossibile salvare le modifiche. Selezionare la data ""Da"" che sia pari o precedente alla data ""fino a"".';de = 'Fehler beim Speichern von Änderungen. Wählen Sie das Datum ""Von"" das gleich oder vor dem Datum ""bis"" liegt aus.'");
EndFunction

Function GetAccountingTemplatesValidityPeriodDateTillErrorText() Export
	Return NStr("en = 'Cannot save changes. Select the ""to"" date that is equal to or later than the ""From"" date.'; ru = 'Не удалось сохранить изменения. Укажите в поле ""по"" дату, превышающую дату в поле ""С"".';pl = 'Nie można zapisać zmian. Wybierz datę ""do"", równą lub późniejszą niż data ""Od"".';es_ES = 'No se pueden guardar los cambios. Seleccione la fecha ""hasta"" que sea igual o posterior a la fecha ""desde"".';es_CO = 'No se pueden guardar los cambios. Seleccione la fecha ""hasta"" que sea igual o posterior a la fecha ""desde"".';tr = 'Değişiklikler kaydedilemiyor. ""Başlangıç"" tarihiyle aynı veya daha geç bir ""bitiş"" tarihi seçin.';it = 'Impossibile salvare le modifiche. Selezionare la data ""fino a"" che sia pari o successiva alla data ""Da"".';de = 'Fehler beim Speichern von Änderungen. Wählen Sie das Datum ""Bis"" das gleich oder nach dem Datum ""Von"" liegt aus.'");
EndFunction

Function GetAccountingPolicyEffectiveDateErrorText() Export
	Return  NStr("en = 'Cannot save the accounting policy. The Effective date %1 is within the closed period. Change the Effective date.'; ru = 'Не удалось сохранить учетную политику. Дата начала действия %1 относится к закрытому периоду. Измените дату начала действия. ';pl = 'Nie można zapisać polityki rachunkowości. Data wejścia w życie %1 mieści się w zamkniętym okresie. Zmień datę wejścia w życie.';es_ES = 'No se puede guardar la política de contabilidad. La Fecha efectiva %1 está dentro del periodo cerrado. Cambie la Fecha efectiva.';es_CO = 'No se puede guardar la política de contabilidad. La Fecha efectiva %1 está dentro del periodo cerrado. Cambie la Fecha efectiva.';tr = 'Muhasebe politikası kaydedilemiyor. %1 yürürlük tarihi, kapanış dönemi içinde. Yürürlük tarihini değiştirin. ';it = 'Impossibile salvare la politica contabile. La Data effettiva%1 è inclusa nel periodo chiuso. Modificare la Data effettiva.';de = 'Fehler beim Speichern von Bilanzierungsrichtlinien. Der Stichtag%1 liegt im geschlossenen Zeitraum. Ändern Sie den Stichtag.'");
EndFunction

Function GetAccountingPolicyDocumentsExistErrorText() Export
	Return NStr("en = 'There are documents which were created with the current accounting policy setting.
		|To apply the new settings, please create a new accounting policy setting.'; 
		|ru = 'В базе содержатся документы с текущей настройкой учетной политики. 
		|Для применения новых настроек создайте новые настройки учетной политики.';
		|pl = 'Istnieją dokumenty, które zostały utworzone przy bieżących ustawieniach polityki rachunkowości.
		|Aby zastosować nowe ustawienia, utwórz nowe ustawienia polityki rachunkowości.';
		|es_ES = 'Hay documentos que se han creado con la configuración actual de la política de contabilidad.
		|Para aplicar las nuevas configuraciones, por favor, cree una nueva configuración de la política de contabilidad.';
		|es_CO = 'Hay documentos que se han creado con la configuración actual de la política de contabilidad.
		|Para aplicar las nuevas configuraciones, por favor, cree una nueva configuración de la política de contabilidad.';
		|tr = 'Mevcut muhasebe politikası ayarı ile oluşturulmuş belgeler var.
		|Yeni ayarları uygulamak için, lütfen yeni bir muhasebe politikası ayarı oluşturun.';
		|it = 'Ci sono documenti che sono stati creati con l''attuale impostazione di politica contabile.
		|Per applicare le nuove impostazioni, si prega di creare una nuova politica contabile.';
		|de = 'Es gibt Belege, die mit der aktuellen Einstellung der Bilanzierungsrichtlinie erstellt wurden.
		|Um die neuen Einstellungen zu übernehmen, erstellen Sie bitte eine neue Einstellung für die Bilanzierungsrichtlinie.'")
EndFunction

Function GetAccountingPolicyAlredyAppliedTemplateErrorText() Export
	Return NStr("en = 'Cannot save the changes. Type of accounting ""%1"" is already applied in the period from %2 to %3 and cannot be added to this accounting policy.'; ru = 'Не удалось сохранить изменения. Тип бухгалтерского учета ""%1"" уже используется в периоде с %2 по %3 и не может быть добавлен в данную учетную политику.';pl = 'Nie można zapisać zmian. Typ rachunkowości ""%1"" jest już zastosowany w okresie od %2 do %3 i nie może być dodany do tej polityki rachunkowości.';es_ES = 'No se pueden guardar los cambios. El tipo de contabilidad ""%1"" ya se aplica en el periodo desde%2 hasta %3 y no se puede añadir a esta política de contabilidad.';es_CO = 'No se pueden guardar los cambios. El tipo de contabilidad ""%1"" ya se aplica en el periodo desde%2 hasta %3 y no se puede añadir a esta política de contabilidad.';tr = 'Değişiklikler kaydedilemiyor. ""%1"" muhasebe türü %2 - %3 döneminde uygulanmış durumda ve bu muhasebe politikasına eklenemiyor.';it = 'Impossibile salvare le modifiche. Il tipo di contabilità ""%1"" è già applicato al periodo da %2 a %3 e non può essere aggiunto a questa politica contabile.';de = 'Fehler beim Speichern von Änderungen. Typ der Buchhaltung ""%1"" ist bereits im Zeitraum vom %2 bis zum %3 verwendet und kann nicht zu diesen Bilanzierungsrichtlinien hinzugefügt werden.'");
EndFunction

Function GetAccountingPolicyDataChangedQuestion() Export
	Return NStr("en = 'You have changed the %1 while the ""Types of accounting"" tab contains unsaved data. This data will be cleared. Continue?'; ru = 'Вы изменили %1. Вкладка ""Типы бухгалтерского учета"" содержала несохраненные данные. Эти данные будут удалены. Продолжить?';pl = 'Zmieniono %1 podczas gdy karta ""Typy rachunkowości"" zawiera niezapisane dane. Te dane zostaną wyczyszczone. Kontynuować?';es_ES = 'Usted ha cambiado la %1 mientras que la pestaña ""Tipos de contabilidad"" contiene datos no guardados. Estos datos se borrarán. ¿Continuar?';es_CO = 'Usted ha cambiado la %1 mientras que la pestaña ""Tipos de contabilidad"" contiene datos no guardados. Estos datos se borrarán. ¿Continuar?';tr = '""Muhasebe türleri"" sekmesi kaydedilmemiş veriler içerirken %1 değiştirildi. Bu veriler silinecek. Devam edilsin mi?';it = 'Hai modificato %1 mentre la scheda ""Tipi di contabilità"" contiene dati non salvati. Questi dati saranno cancellati. Continuare?';de = 'Sie haben %1 geändert, und die Registerkarte ""Typen der Buchhaltung"" enthält nicht gespeicherte Daten. Diese Daten werden gelöscht. Weiter?'");
EndFunction

Function GetAccountingPolicySalesInvoiceWarningText() Export
	Return	NStr("en = 'For the existing Sales invoices, the delivery dates are not filled in by default.
		|If required, fill them in and repost the Sales invoices.'; 
		|ru = 'Для существующих инвойсов покупателям даты доставки по умолчанию не заполняются.
		|При необходимости заполните их и повторно проведите инвойсы покупателям.';
		|pl = 'Dla istniejących Faktur sprzedaży, nie wypełniono domyślnych dat dostawy.
		|W razie potrzeby, wypełnij je i zaksięguj Faktury sprzedaży.';
		|es_ES = 'Para las Facturas de venta existentes, las fechas de entrega no están rellenadas por defecto.
		|Si es necesario, rellénelas y vuelva a enviar las Facturas de venta.';
		|es_CO = 'Para las Facturas de venta existentes, las fechas de entrega no están rellenadas por defecto.
		|Si es necesario, rellénelas y vuelva a enviar las Facturas de venta.';
		|tr = 'Mevcut satış faturaları için teslimat tarihleri varsayılan olarak doldurulmaz.
		|Gerekirse, tarihleri doldurup Satış faturalarını yeniden kaydedin.';
		|it = 'Per le Fatture di vendita esistenti, le date di consegna non sono compilate da impostazione predefinita. 
		|Se richiesto, compilarle e ripubblicare le Fatture di vendita.';
		|de = 'Für die vorhandenen Verkaufsrechnungen sind die Lieferdaten standardmäßig nicht ausgefüllt.
		|Ggf., füllen Sie sie aus und buchen die Verkaufsrechnungen erneut.'");
EndFunction

Function GetAccountingPolicyItemPresentationText() Export
	Return NStr("en = 'ReadOnly %1 in Types of accounting'; ru = 'ТолькоПросмотр %1 в Типах бухгалтерского учета';pl = 'ReadOnly %1 w Typach rachunkowości';es_ES = 'ReadOnly %1 en Tipos de contabilidad';es_CO = 'ReadOnly %1 en Tipos de contabilidad';tr = 'Muhasebe türlerinde salt okunur %1';it = 'ReadOnly%1 in Tipi di contabilità';de = 'ReadOnly %1 in Typen der Buchhaltung'");
EndFunction

Function GetAccountingPolicyVATNumberErrorText() Export
	Return NStr("en = 'First, specify the company''s VAT ID.'; ru = 'Сначала укажите номер плательщика НДС организации.';pl = 'Najpierw, podaj numer VAT firmy.';es_ES = 'Primero, especifique el identificador del IVA de la empresa.';es_CO = 'Primero, especifique el identificador del IVA de la empresa.';tr = 'İlk olarak, iş yerinin KDV kodunu belirtin.';it = 'Prima specificare la P.IVA dell''azienda.';de = 'Geben Sie zuerst die USt.-IdNr. der Firma an.'");
EndFunction

Function GetAccountingPolicyVATOptionTemplateErrorText() Export
	Return NStr("en = 'You can''t change the option ""%1"" because there are records in VAT registers.'; ru = 'Вы не можете изменить опцию ""%1"", потому что в регистрах НДС есть движения.';pl = 'Nie można zmienić opcji ""%1"", ponieważ istnieją wpisy w rejestrach VAT.';es_ES = 'Usted no puede cambiar la opción ""%1"" porque hay grabaciones en los registros del IVA.';es_CO = 'Usted no puede cambiar la opción ""%1"" porque hay grabaciones en los registros del IVA.';tr = 'KDV kaydedicisinde kayıtlar olduğundan ""%1"" seçeneğini değiştiremezsiniz.';it = 'Non è possibile modificare l''opzione ""%1"", perché ci sono registrazioni nei registri IVA.';de = 'Sie können die Option ""%1"" nicht ändern, da es Datensätze in USt-Registern gibt.'")
EndFunction

Function GetAccountingPolicyApliedSamePolicyTemplateErrorText() Export
	Return NStr("en = 'Cannot save changes. For %1, the Start date and End date cannot be applied in the same accounting policy.'; ru = 'Не удалось сохранить изменения. Для %1 дата начала и дата окончания не могут быть применены в одной учетной политике.';pl = 'Nie można zapisać zmian. Dla %1, Data rozpoczęcia i data zakończenia nie mogą być zastosowane w tej samej polityce rachunkowości.';es_ES = 'No se pueden guardar los cambios. Para %1, la fecha de inicio y la fecha final no pueden aplicarse en la misma política de contabilidad.';es_CO = 'No se pueden guardar los cambios. Para %1, la fecha de inicio y la fecha final no pueden aplicarse en la misma política de contabilidad.';tr = 'Değişiklikler kaydedilemiyor. %1 için, Başlangıç tarihi ve Bitiş tarihi aynı muhasebe politikasında uygulanamaz.';it = 'Impossibile salvare le modifiche. Per %1, la Data di inizio e la Data di fine non possono essere applicate nella stessa politica contabile.';de = 'Fehler beim Speichern von Änderungen. Für %1, können das Startdatum und Enddatum in denselben Bilanzierungsrichtlinien nicht verwendet werden.'");
EndFunction

Function GetAccountingPolicyTypeOfAccountngDeleteErrorText() Export
	Return NStr("en = 'Cannot delete ""%1"". Accounting entries are already recorded for this type of accounting.'; ru = 'Не удалось удалить ""%1"". Для этого типа бухгалтерского учета уже сделаны бухгалтерские проводки.';pl = 'Nie można usunąć ""%1"". Wpisy księgowe są już zapisane dla tego typu rachunkowości.';es_ES = 'No se puede borrar ""%1"". Las entradas de diario ya están registradas para este tipo de contabilidad.';es_CO = 'No se puede borrar ""%1"". Las entradas de diario ya están registradas para este tipo de contabilidad.';tr = '""%1"" silinemiyor. Bu muhasebe türü için kayıtlı muhasebe girişleri var.';it = 'Impossibile eliminare ""%1"". Le voci di contabilità sono già registrate per questo tipo di contabilità.';de = 'Fehler beim Löschen von ""%1"". Buchungen sind bereits für diesen Typ der Buchhaltung eingetragen.'");
EndFunction

Function GetAccountingPolicyPeroidDeleteErrorText() Export
	Return NStr("en = 'Cannot delete this type of accounting. It was added to the accounting policy effective from %1. Delete the type of accounting from that accounting policy.'; ru = 'Не удалось удалить тип бухгалтерского учета, поскольку он включен в учетную политику, действующую с %1. Удалите этот типов бухгалтерского учета из учетной политики.';pl = 'Nie można usunąć tego typu rachunkowości. Został on dodany do polityki rachunkowości obowiązującej od %1. Usuń typ rachunkowości z tej polityki rachunkowości';es_ES = 'No se puede borrar este tipo de contabilidad. Se añadió a la política de contabilidad efectiva desde %1. Borre el tipo de contabilidad de esa política de contabilidad.';es_CO = 'No se puede borrar este tipo de contabilidad. Se añadió a la política de contabilidad efectiva desde %1. Borre el tipo de contabilidad de esa política de contabilidad.';tr = 'Bu muhasebe türü silinemiyor. %1 itibarıyla geçerli muhasebe politikası eklendi. Muhasebe türünü o muhasebe politikasından silin.';it = 'Impossibile eliminare questo tipo di contabilità. È stata aggiunta alla politica contabile effettiva da %1. Eliminare il tipo di contabilità da questo politica contabilità.';de = 'Fehler beim Löschen dieses Typs der Buchhaltung. Er ist zu den Bilanzierungsrichtlinien gültig seit %1 hinzugefügt. Löschen Sie den Typ der Buchhaltung aus diesen Bilanzierungsrichtlinien.'");
EndFunction

Function GetAccountingPolicyFieldIsRequierdErrorText() Export
	Return NStr("en = 'The ""%1"" is required on line %2 of the ""Types of accounting"" list.'; ru = 'В строке %2 списка ""Типы бухгалтерского учета"" необходимо указать ""%1"".';pl = '""%1"" jest wymagane w wierszu %2 listy ""Typy rachunkowości"".';es_ES = 'El ""%1"" se requiere en la línea %2 de la lista de ""Tipos de contabilidad"".';es_CO = 'El ""%1"" se requiere en la línea %2 de la lista de ""Tipos de contabilidad"".';tr = '""Muhasebe türleri"" listesinin %2 satırında ""%1"" gerekli.';it = 'Il ""%1"" è richiesto nella riga %2 dell''elenco ""Tipi di contabilità"". ';de = '""%1"" ist in der Zeile %2 der ""Liste ""Typen der Buchhaltung"" erforderlich.'");
EndFunction

Function GetAccountingPolicyAlredyRecordedAccountingErrorText() Export
	
	Return NStr("en='Cannot save the changes. For ""%1"", the %6 was changed from %2 to %3 
		|Accounting entries are already recorded for ""%1"" in the period from %4 to %5'; 
		|ru = 'Не удалось сохранить изменения. Для ""%1"" %6 был изменен с %2 на %3 
		|Для ""%1"" уже сделаны бухгалтерские проводки в период с %4 по %5';
		|pl = 'Nie można zapisać zmian. Dla ""%1"", %6 został zmieniony z %2 na %3 
		|Wpisy księgowe są już zapisane dla ""%1"" w okresie od %4 do %5';
		|es_ES = 'No se pueden guardar los cambios. Para ""%1"", el %6 fue cambiado desde %2 hasta %3 
		|Las entradas contables ya están registradas para ""%1"" en el período desde %4 hasta%5';
		|es_CO = 'No se pueden guardar los cambios. Para ""%1"", el %6 fue cambiado desde %2 hasta %3 
		|Las entradas contables ya están registradas para ""%1"" en el período desde %4 hasta%5';
		|tr = 'Değişiklikler kaydedilemiyor. ""%1"" için %6, %2 değerinden %3 değerine değiştirildi 
		|%4 - %5 döneminde ""%1"" için kayıtlı muhasebe girişleri var';
		|it = 'Impossibile salvare le modifiche. Per ""%1"" il %6è stato modificato da %2 a %3
		|Le voci di contabilità sono già registrate per ""%1"" nel periodo da %4 a %5';
		|de = 'Fehler beim Speichern von Änderungen. Für ""%1"", war %6 vom %2 auf %3 geändert. 
		|Buchungen sind bereits für ""%1"" im Zeitraum vom %4 bis zum %5 eingetragen'");
	
EndFunction

Function GetAccountingPolicyAlredyRecordedAccountingInOpenPeriodErrorText() Export
	
	Return NStr("en='Cannot save the changes. For ""%1"", the %4 was changed to %2 
		|Accounting entries are already recorded for ""%1"" in the period from %3'; 
		|ru = 'Не удалось сохранить изменения. Для ""%1"" %4 был изменен на %2 
		|Для ""%1"" уже сделаны бухгалтерские проводки в период с %3';
		|pl = 'Nie można zapisać zmian. Dla ""%1"", %4 został zmieniony na%2 
		|Wpisy księgowe są już zapisane dla ""%1"" w okresie od %3';
		|es_ES = 'No se pueden guardar los cambios. Para ""%1"", el %4 fue cambiado hasta %2 
		|Las entradas contables ya están registradas para ""%1"" en el periodo desde %3';
		|es_CO = 'No se pueden guardar los cambios. Para ""%1"", el %4 fue cambiado hasta %2 
		|Las entradas contables ya están registradas para ""%1"" en el periodo desde %3';
		|tr = 'Değişiklikler kaydedilemiyor. ""%1"" için %4, %2 olarak değiştirildi 
		|%3 ile başlayan dönemde ""%1"" için kayıtlı muhasebe girişleri var';
		|it = 'Impossibile salvare le modifiche. Per ""%1"", %4è stato modificato in %2
		|le Voci di contabilità sono già state registrate per ""%1"" nel periodo da %3';
		|de = 'Fehler beim Speichern von Änderungen. Für ""%1"", war %4 auf %2geändert. 
		|Buchungen sind bereits für ""%1"" im Zeitraum vom %3eingetragen'");
	
EndFunction

Function GetAccountingPolicyAlredyRecordedAccountingFromDateErrorText() Export
	
	Return NStr("en='Cannot save the changes. Accounting entries are already recorded for ""%1"" in the period starting from %2'; ru = 'Не удалось сохранить изменения. Для ""%1"" уже сделаны бухгалтерские проводки в период с %2';pl = 'Nie można zapisać zmian. Wpisy księgowe są już zapisane dla ""%1"" w okresie zaczynając od %2';es_ES = 'No se pueden guardar los cambios. Las entradas contables ya están registradas para ""%1"" en el período que comienza desde %2';es_CO = 'No se pueden guardar los cambios. Las entradas contables ya están registradas para ""%1"" en el período que comienza desde %2';tr = 'Değişiklikler kaydedilemiyor. %2 ile başlayan dönemde ""%1"" için kayıtlı muhasebe girişleri var';it = 'Impossibile salvare le modifiche. Le voci di contabilità sono già registrate per ""%1"" nel periodo a partire da %2';de = 'Fehler beim Speichern von Änderungen. Buchungen sind bereits für ""%1"" im Zeitraum beginnend mit %2 eingetragen'");
	
EndFunction

Function GetAccountingPolicyAlredyPostedDocumentsErrorText() Export
	
	Return NStr("en='For ""%1"", the %6 was changed from %2 to %3 
		|Accounting source documents are already posted in the period from %4 to %5
		|To record accounting entries, repost these documents.'; 
		|ru = 'Для ""%1"", %6 было изменено с %2 на %3 
		|Первичные бухгалтерские документы, уже были проведены в периоде с %4 по %5
		|Чтобы сформировать бухгалтерские проводки, перепроведите эти документы.';
		|pl = 'Dla ""%1"", %6 został zmieniony od %2 do %3 
		|Źródłowe dokumenty księgowe są już zatwierdzone w okresie od %4 do %5
		|Aby zapisać wpisy księgowe, zatwierdź te dokumenty.';
		|es_ES = 'Para ""%1"", el %6 fue cambiado desde %2 hasta %3
		|Los documentos de fuente de contabilidad ya están contabilizados en el periodo desde %4 hasta%5
		| Para registrar las entradas contables, vuelve a contabilizar estos documentos.';
		|es_CO = 'Para ""%1"", el %6 fue cambiado desde %2 hasta %3
		|Los documentos de fuente de contabilidad ya están contabilizados en el periodo desde %4 hasta%5
		| Para registrar las entradas contables, vuelve a contabilizar estos documentos.';
		|tr = '""%1"" için %6, %2 değerinden %3 değerine değiştirildi 
		|%4 - %5 döneminde kayıtlı muhasebe kaynak belgeleri var 
		|Muhasebe girişleri kaydetmek için bu belgeleri tekrar kaydedin.';
		|it = 'Per ""%1"", %6 è stato modificato da %2 a %3
		|i Documenti di fonte contabilità sono già stati pubblicati nel periodo da %4 a %5
		|Per registrare le voci di contabilità, ripubblicare questi documenti.';
		|de = 'Für ""%1"", war %6 vom %2 auf %3 geändert
		|Die Buchhaltungsquelldokumente sind bereits im Zeitraum vom %4 bis zum %5eingetragen. 
		|Um Buchungen einzutragen, buchen Sie diese Dokumente neu.'");
	
EndFunction

Function GetAccountingPolicyAlredyPostedDocumentsTemplateError(PostingOption) Export
	
	If PostingOption = PredefinedValue("Enum.AccountingEntriesRegisterOptions.SourceDocuments") Then
		TemplateMessage = NStr("en='Documents are already posted in the period starting from %1. To record accounting entries, create a list of Accounting source documents and repost the documents included in this list.'; ru = 'Документы уже были проведены в периоде с %1. Чтобы сформировать бухгалтерские проводки, создайте список первичных бухгалтерских документов и перепроведите документы из этого списка.';pl = 'Dokumenty są już zatwierdzone w okresie zaczynając od %1. Aby zapisać wpisy księgowe, utwórz listę źródłowych dokumentów księgowych i zatwierdź dokumenty, zawarte na tej liście.';es_ES = 'Los documentos ya están contabilizados en el período que comienza desde %1. Para registrar entradas contables, crea una lista de documentos de fuente de contabilidad y vuelve a contabilizar los documentos incluidos en esta lista.';es_CO = 'Los documentos ya están contabilizados en el período que comienza desde %1. Para registrar entradas contables, crea una lista de documentos de fuente de contabilidad y vuelve a contabilizar los documentos incluidos en esta lista.';tr = '%1 ile başlayan dönemde kayıtlı belgeler var. Muhasebe girişleri kaydetmek için, Muhasebe kaynak belgeleri listesi oluşturun ve bu listede yer alan belgeleri yeniden kaydedin.';it = 'I documenti sono già pubblicati nel periodo a partire da %1. Per registrare le voci di contabilità, creare un elenco di documenti fonte di contabilità e ripubblicare i documenti inclusi nell''elenco.';de = 'Dokumente sind bereits im Beginn des Zeitraums vom %1 gebucht. Um Buchungen einzutragen, erstellen Sie eine Liste von Buchhaltungsquelldokumente und buchen Sie die Dokumente aus dieser Liste neu.'");
	Else
		TemplateMessage = NStr("en='Documents are already posted in the period starting from %1. To record accounting entries, first, create a list of Accounting source documents and specify the Accounting transaction generation settings. Then repost the documents included in the created list.'; ru = 'Документы уже были проведены в периоде с %1. Чтобы сформировать бухгалтерские проводки, сначала создайте список первичных бухгалтерских документов и укажите параметры формированию бухгалтерских проводок. Затем перепроведите документы из созданного списка.';pl = 'Dokumentu są już zatwierdzone w okresie, zaczynając od %1. Aby zapisać wpisy księgowe, najpierw, utwórz listę źródłowych dokumentów księgowych i określ Ustawienia generowania transakcji księgowych. Zatem zatwierdź dokumenty, zawarte na tej liście.';es_ES = 'Los documentos ya están contabilizados en el período que comienza desde %1. Para registrar las entradas contables, primero, crea una lista de documentos de fuente de contabilidad y especifica las configuraciones de generación de transacciones contables. A continuación, vuelve a contabilizar los documentos incluidos en la lista creada.';es_CO = 'Los documentos ya están contabilizados en el período que comienza desde %1. Para registrar las entradas contables, primero, crea una lista de documentos de fuente de contabilidad y especifica las configuraciones de generación de transacciones contables. A continuación, vuelve a contabilizar los documentos incluidos en la lista creada.';tr = '%1 ile başlayan dönemde kayıtlı belgeler var. Muhasebe girişleri kaydetmek için, Muhasebe kaynak belgeleri listesi oluşturun ve Muhasebe işlemi oluşturma ayarlarını belirtin. Ardından, oluşturulan listede yer alan belgeleri yeniden kaydedin.';it = 'I documenti sono già pubblicati nel periodo a partire da %1. Per registrare le voci di contabilità, innanzitutto creare un elenco di documenti fonte di contabilità e indicare le impostazioni di creazione della transazione di contabilità. Poi ripubblicare i documenti inclusi nella lista creata.';de = 'Dokumente sind bereits im Zeitraum vom %1 gebucht. Um die Buchungen einzutragen, erstellen Sie eine Liste von Buchhaltungsquelldokumente und geben Sie die Einstellungen der Buchhaltungstransaktionsgenerierung ein. Dann buchen Sie die Dokumente aus der erstellten Liste neu.'");
	EndIf;
	
	Return TemplateMessage;
	
EndFunction

Function GetAccountingPolicyDuplicateItems() Export
	
	Return NStr("en = 'Cannot save the Accounting policy. List of types of accounting contains duplicate items: %1.'; ru = 'Не удалось сохранить учетную политику. Список типов бухгалтерского учета содержит дублирующиеся элементы: %1.';pl = 'Nie można zapisać Polityki rachunkowości. Lista typów rachunkowości zawiera zduplikowane elementy: %1.';es_ES = 'No se puede guardar la política de contabilidad. La lista de tipos de contabilidad contiene elementos duplicados: %1';es_CO = 'No se puede guardar la política de contabilidad. La lista de tipos de contabilidad contiene elementos duplicados: %1';tr = 'Muhasebe politikası kaydedilemiyor. Muhasebe türleri listesi tekrarlayan öğeler içeriyor: %1.';it = 'Impossibile salvare la Politica contabile. L''elenco dei tipi di contabilità contiene elementi duplicati: %1.';de = 'Fehler beim Speichern von Bilanzierungsrichtlinien. Liste der Typen der Buchhaltung enthält verdoppelte Elemente: %1.'");
	
EndFunction

Function GetAccountingPolicyEffectiveDateAlredyExistsErrorText() Export
	
	Return NStr("en = 'Cannot change the Effective date to %1. The accounting policy with this date already exists.'; ru = 'Не удалось изменить дату начала действия на %1. Учетная политика с этой датой уже существует.';pl = 'Nie można zmienić Daty wejścia w życie na %1. Polityka rachunkowości z tą datą już istnieje.';es_ES = 'No se puede cambiar la Fecha efectiva a %1. La política de contabilidad con esta fecha ya existe.';es_CO = 'No se puede cambiar la Fecha efectiva a %1. La política de contabilidad con esta fecha ya existe.';tr = 'Yürürlük tarihi %1 olarak değiştirilemiyor. Bu tarihli muhasebe politikası mevcut.';it = 'Impossibile modificare la Data effettiva in %1. Una politica contabile con questa data esiste già.';de = 'Fehler beim Ändern von  Stichtag auf %1. Die Bilanzierungsrichtlinien mit diesem Datum bestehen bereits.'");

EndFunction

Function GetAccountingPolicyEffectiveDateClosedPeriodErrorText() Export
	
	Return NStr("en = 'The Effective date %1 is within the closed period. Change the Effective date.'; ru = 'Дата начала действия %1 относится к закрытому периоду. Измените дату начала действия.';pl = 'Data wejścia w życie %1 mieści się w zamkniętym okresie. Zmień datę wejścia w życie.';es_ES = 'La Fecha efectiva %1 está dentro del periodo cerrado. Cambie la Fecha efectiva.';es_CO = 'La Fecha efectiva %1 está dentro del periodo cerrado. Cambie la Fecha efectiva.';tr = '%1 yürürlük tarihi, kapanış dönemi içinde. Yürürlük tarihini değiştirin.';it = 'La Data effettiva %1 è inclusa nel periodo chiuso. Modificare la Data effettiva.';de = 'Der Stichtag%1 liegt im geschlossenen Zeitraum. Ändern Sie den Stichtag.'");
	
EndFunction

Function GetUniversalReportInapplicableCombinationErrorText() Export
	
	Return NStr("en = 'Cannot generate the report. The report filter pane contains an inapplicable combination of parameter values. For ""%1"", select another value instead of ""%2"". Then try again.'; ru = 'Не удалось сформировать отчет. Панель отборов отчета содержит неприменимую комбинацию значений параметров. Выберите другое значение вместо ""%2"" для ""%1"" и повторите попытку.';pl = 'Nie można wygenerować raportu. Filtr raportu zawiera nieodpowiednią kombinację wartości parametru. Dla ""%1"", wybierz inną wartość zamiast ""%2"". Zatem spróbuj ponownie.';es_ES = 'No se puede generar el informe. El panel de filtros del informe contiene una combinación inaplicable de valores de parámetros. Para ""%1"", seleccione otro valor en lugar de ""%2"". Inténtelo de nuevo.';es_CO = 'No se puede generar el informe. El panel de filtros del informe contiene una combinación inaplicable de valores de parámetros. Para ""%1"", seleccione otro valor en lugar de ""%2"". Inténtelo de nuevo.';tr = 'Rapor filtre bölmesi uygulanamaz parametre kombinasyonu içeriyor. ""%1"" için, ""%2"" yerine başka bir değer seçip tekrar deneyin.';it = 'Impossibile creare il report. Il pannello filtro report contiene una combinazione inapplicabile di valori di parametro. Per ""%1"" selezionare un altro valore invece di ""%2"", poi riprovare.';de = 'Fehler beim Generieren des Berichts. Der Berichtsfilter enthält eine nicht verwendbare Kombination von Parameterwerten. Für ""%1"", wählen Sie einen anderen Wert statt ""%2"" aus. Dann versuchen Sie erneut.'");
	
EndFunction

Function GetRestrictedDuplicatesErrorText() Export
	Return NStr("en = 'Duplicates are restricted.'; ru = 'Дубликаты запрещены.';pl = 'Duplikaty są ograniczone.';es_ES = 'Los duplicados están restringidos.';es_CO = 'Los duplicados están restringidos.';tr = 'Tekrarlar kısıtlı.';it = 'I duplicati sono limitati.';de = 'Duplikate sind eingeschränkt.'");
EndFunction

Function GetDataChangedQueryText() Export
	
	Return NStr("en = 'Data was changed or deleted by another user or in another session.
		|You need to re-read the data and start editing again.
		|(in this case your changes will be lost)'; 
		|ru = 'Данные были изменены или удалены другим пользователем или в другом сеансе.
		|Перечитайте данные и повторите редактирование.
		|(ваши предыдущие изменения будут потеряны)';
		|pl = 'Dane zostały zmienione lub usunięte przez innego użytkownika lub w innej sesji.
		|Trzeba ponownie wczytać dane i zacząć edytować je od nowa.
		|(w tym przypadku twoje zmiany zostaną utracone)';
		|es_ES = 'Los datos fueron modificados o borrados por otro usuario o en otra sesión.
		| Usted debe volver a leer los datos y comenzar a editarlos de nuevo. 
		|(en este caso sus cambios se perderán).';
		|es_CO = 'Los datos fueron modificados o borrados por otro usuario o en otra sesión.
		| Usted debe volver a leer los datos y comenzar a editarlos de nuevo. 
		|(en este caso sus cambios se perderán).';
		|tr = 'Veriler başka bir kullanıcı tarafından veya başka bir oturumda değiştirildi veya silindi.
		|Verileri tekrar okumanız ve düzenlemeye tekrar başlamanız gerekiyor.
		|(bu durumda değişiklikler kaybolur)';
		|it = 'I dati sono stati modificati o eliminati da un altro utente in un''altra sessione.
		| Devi rileggere i dati ed iniziare nuovamente la modifica.
		|(in questo caso, le modifiche andranno perse)';
		|de = 'Datum war durch einen Benutzer oder in einer anderen Sitzung geändert oder gelöscht.
		|Sie brauchen das Datum neu lesen und Bearbeitung wieder beginnen.
		|(in diesem Falle werden Ihre Änderungen verloren)'");
	
EndFunction

Function GetPostingErrorText() Export
	
	Return NStr("en = 'Cannot post this document.'; ru = 'Не удалось провести документ.';pl = 'Nie można zatwierdzić tego dokumentu.';es_ES = 'No se puede contabilizar este documento.';es_CO = 'No se puede contabilizar este documento.';tr = 'Bu belge kaydedilemiyor.';it = 'Impossibile pubblicare questo documento.';de = 'Fehler beim Buchen dieses Dokuments.'");
	
EndFunction

Function GetDiscountOnChangeText() Export
	
	Return NStr("en = 'The counterparty contract allows for the kind of prices and discount other than prescribed in the document. 
		|Recalculate the document according to the contract?'; 
		|ru = 'Договор с контрагентом предусматривает тип цен и скидку, отличные от установленных в документе. 
		|Пересчитать документ в соответствии с договором?';
		|pl = 'Kontrakt kontrahenta dopuszcza rodzaj cen i rabatu, który różni się od ustawionego w dokumencie. 
		|Przeliczyć dokument zgodnie z kontraktem?';
		|es_ES = 'El contrato de la contraparte permite para el tipo de precios y descuento distinto al pre-inscrito en el documento.
		|¿Recalcular el documento según el contrato?';
		|es_CO = 'El contrato de la contraparte permite para el tipo de precios y descuento distinto al pre-inscrito en el documento.
		|¿Recalcular el documento según el contrato?';
		|tr = 'Cari hesap sözleşmesi, belgede belirtilenden farklı türde fiyat ve indirimlere izin veriyor. 
		|Belge, sözleşmeye göre yeniden hesaplansın mı?';
		|it = 'Il contratto con la controparte permette una tipologia di prezzi e sconti diversi da quelli indicati nel documento.
		|Ricalcolare il documento secondo il contratto?';
		|de = 'Der Geschäftspartnervertrag sieht die Art der Preise und Rabatte vor, die nicht im Dokument vorgeschrieben sind.
		|Das Dokument gemäß dem Vertrag neu berechnen?'");
	
EndFunction

#Region TemplateTesting

Function GetTemplateTestingCommonErrorText() Export
	
	Return NStr("en = 'Error will occur during entry posting. For more details, see Messages window.'; ru = 'При формирования проводки произойдет ошибка. Подробнее см. в окне ""Сообщения"".';pl = 'Podczas zatwierdzenia wpisu wystąpi błąd. Więcej szczegółów możesz zobaczyć w oknie Wiadomości.';es_ES = 'Se producirá un error durante la contabilización de la entrada de diario. Para más detalles, consulte la ventana de Mensajes.';es_CO = 'Se producirá un error durante la contabilización de la entrada de diario. Para más detalles, consulte la ventana de Mensajes.';tr = 'Giriş kaydetme hatası. Ayrıntılar için Mesajlar penceresine bakın.';it = 'Si verificherà un errore durante la registrazione della voce. Per maggiori dettagli, vedere la finestra Messaggi.';de = 'Ein Fehler wird beim Buchen der Buchung auftreten. Für weitere Informationen lesen Sie das Fenster Nachrichten.'");
	
EndFunction

Function GetTemplateTestingInvalidPeriodErrorText() Export
	
	Return NStr("en = 'Cannot generate entries for this template. The source document date is not within the template validity period.'; ru = 'Не удалось сформировать проводки для этого шаблона. Дата первичного документа не входит в срок действия шаблона.';pl = 'Nie można wygenerować wpisów dla tego szablonu. Data dokumentu źródłowego nie mieści się w okresie ważności szablonu.';es_ES = 'No se pueden generar entradas de diario para esta plantilla. La fecha del documento de fuente no está dentro del periodo de validez de la plantilla.';es_CO = 'No se pueden generar entradas de diario para esta plantilla. La fecha del documento de fuente no está dentro del periodo de validez de la plantilla.';tr = 'Bu şablon için giriş oluşturulamıyor. Kaynak belgenin tarihi şablonun geçerlilik dönemi içinde değil.';it = 'Impossibile generare voci per questo modello. La data del documento di origine non rientra nel periodo di validità del modello.';de = 'Fehler beim Generieren von Buchungen für diese Vorlage. Das Quelldokumentdatum liegt nicht in der Gültigkeitsdauer der Vorlage.'");
	
EndFunction

Function GetTemplateTestingInvalidParametersErrorText() Export
	
	Return NStr("en = 'Cannot generate entries for this template. The source document does not meet the template parameters.'; ru = 'Не удалось сформировать проводки для этого шаблона. Первичный документ не соответствует параметрам шаблона.';pl = 'Nie można wygenerować wpisów dla tego szablonu. Dokument źródłowy nie spełnia parametrów szablonu.';es_ES = 'No se pueden generar entradas de diario para esta plantilla. El documento de fuente no cumple los parámetros de la plantilla.';es_CO = 'No se pueden generar entradas de diario para esta plantilla. El documento de fuente no cumple los parámetros de la plantilla.';tr = 'Bu şablon için giriş oluşturulamıyor. Kaynak belge, şablon parametrelerini karşılamıyor.';it = 'Impossibile generare voci per questo modello. Il documento di origine non soddisfa i parametri del modello.';de = 'Fehler beim Generieren von Buchungen für diese Vorlage. Das Quelldokument stimmt mit den Vorlagenparametern nicht überein.'");
	
EndFunction

#EndRegion

#Region EventLog

Function GetRestoreOriginalEntriesErrorText(DefaultLanguageCode) Export
	
	Return NStr("en = 'An error occurred while restoring the accounting entries status for document %1 due to %2.'; ru = 'При восстановлении статуса бухгалтерских проводок в документе %1 произошла ошибка. Причина: %2.';pl = 'Wystąpił błąd podczas przywrócenia statusu wpisów księgowych dla dokumentu %1 z powodu %2.';es_ES = 'Ha ocurrido un error al restablecer el estado de entradas contables para el documento%1 a causa de %2.';es_CO = 'Ha ocurrido un error al restablecer el estado de entradas contables para el documento%1 a causa de %2.';tr = '%1 belgesi için muhasebe girişleri durumu geri yüklenirken %2 sebebiyle hata oluştu.';it = 'Si è verificato un errore durante il ripristino dello stato delle voci di contabilità per il documento %1 a causa di %2.';de = 'Ein Fehler trat auf beim Ändern des Buchhaltungsstatus für Dokument %1 aufgrund von %2.'", DefaultLanguageCode);
	
EndFunction

Function GetRestoreOriginalEntriesEventName(DefaultLanguageCode) Export
	
	Return NStr("en = 'Restore the original accounting entries'; ru = 'Восстановить первичные бухгалтерские проводки';pl = 'Przywróć oryginalne wpisy księgowe';es_ES = 'Restablecer las entradas contables originales';es_CO = 'Restablecer las entradas contables originales';tr = 'Orijinal muhasebe girişlerini geri yükle';it = 'Ripristinare gli inserimenti contabili originali';de = 'Originalbuchhaltungseinträge wiederherstellen'", DefaultLanguageCode);
	
EndFunction

#EndRegion

#EndRegion

#EndRegion