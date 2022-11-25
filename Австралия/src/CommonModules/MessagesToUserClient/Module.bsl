#Region Public

#Region MessageBoxes

#Region Selections

Procedure ShowMessageSelectBaseDocument(NotifyDescription = Undefined) Export
	
	ShowMessageBox(NotifyDescription, NStr("en = 'Please select a base document.'; ru = 'Не выбран документ-основание.';pl = 'Wybierz dokument źródłowy.';es_ES = 'Por favor, seleccione un documento base.';es_CO = 'Por favor, seleccione un documento base.';tr = 'Lütfen, temel belge seçin.';it = 'Selezionare un documento di base.';de = 'Bitte wählen Sie ein Basisdokument aus.'"));
	
EndProcedure

Procedure ShowMessageSelectConsignee(NotifyDescription = Undefined) Export
	
	ShowMessageBox(NotifyDescription, NStr("en = 'Please select a consignee.'; ru = 'Выберите комиссионера.';pl = 'Wybierz komisanta.';es_ES = 'Por favor, seleccione un destinatario.';es_CO = 'Por favor, seleccione un destinatario.';tr = 'Lütfen, mal alıcısını seçin.';it = 'Selezionare un agente in conto vendita.';de = 'Bitte wählen Sie einen Kommissionär aus.'"));
	
EndProcedure

Procedure ShowMessageSelectConsignor(NotifyDescription = Undefined) Export
	
	ShowMessageBox(NotifyDescription, NStr("en = 'Please select a consignor.'; ru = 'Выберите комитента.';pl = 'Wybierz komitenta.';es_ES = 'Por favor, seleccione un remitente.';es_CO = 'Por favor, seleccione un remitente.';tr = 'Lütfen, gönderici seçin.';it = 'Selezionare un committente.';de = 'Bitte wählen Sie einen Kommittenten aus.'"));
	
EndProcedure

Procedure ShowMessageSelectOrder(NotifyDescription = Undefined) Export
	
	ShowMessageBox(NotifyDescription, NStr("en = 'Please select an order.'; ru = 'Выберите заказ.';pl = 'Wybierz zamówienie.';es_ES = 'Por favor, seleccione una orden.';es_CO = 'Por favor, seleccione una orden.';tr = 'Lütfen, sipariş seçin.';it = 'Selezionare un ordine.';de = 'Bitte wählen Sie einen Ordner aus.'"));
	
EndProcedure

Procedure ShowMessageSelectWorkInProgress(NotifyDescription = Undefined) Export
	
	ShowMessageBox(NotifyDescription, NStr("en = 'Please select the document ""Work-in-progress"".'; ru = 'Выберите документ ""Незавершенное производство"".';pl = 'Wybierz dokument ""Praca w toku"".';es_ES = 'Por favor, seleccione el documento ""Trabajo en progreso"".';es_CO = 'Por favor, seleccione el documento ""Trabajo en progreso"".';tr = 'Lütfen, ""İşlem bitişi"" belgesini seçin.';it = 'Selezionare il documento ""Lavoro in corso"".';de = 'Bitte wählen Sie das Dokument ""Arbeit in Bearbeitung"" aus.'"));
	
EndProcedure

Procedure ShowMessageSelectRFQResponse(NotifyDescription = Undefined) Export
	
	ShowMessageBox(NotifyDescription, NStr("en = 'Please select the document ""RFQ response"".'; ru = 'Выберите документ ""Ответ на запрос коммерческого предложения"".';pl = 'Wybierz dokument ""Odpowiedź na zapytanie ofertowe"".';es_ES = 'Por favor, seleccione el documento ""Respuesta de RFQ"".';es_CO = 'Por favor, seleccione el documento ""Respuesta de RFQ"".';tr = 'Lütfen, ""Satın alma teklifi"" belgesini seçin.';it = 'Selezionare il documento ""Offerta fornitore"".';de = 'Bitte wählen Sie das Dokument ""Angebotsanfrage-Antwort"" aus.'"));
	
EndProcedure

Procedure ShowMessageSelectBOM(NotifyDescription = Undefined) Export
	
	ShowMessageBox(NotifyDescription, NStr("en = 'Please select a bill of materials.'; ru = 'Выберите спецификацию.';pl = 'Wybierz specyfikację materiałową.';es_ES = 'Por favor, seleccione una lista de materiales.';es_CO = 'Por favor, seleccione una lista de materiales.';tr = 'Lütfen, ürün reçetesi seçin.';it = 'Selezionare una distinta base.';de = 'Bitte wählen Sie eine Stückliste aus.'"));
	
EndProcedure

Procedure ShowMessageCannotOpenInventoryReservationWindow(NotifyDescription = Undefined) Export
	
	ShowMessageBox(NotifyDescription, NStr("en = 'Cannot open the Inventory reservation window. First, post the document.
		|Then try again.'; 
		|ru = 'Не удалось открыть окно ""Резервирование запасов"". Проведите документ и повторите попытку.
		|';
		|pl = 'Nie można otworzyć okna Rezerwacja zapasów Najpierw, zatwierdź dokument.
		|Zatem spróbuj ponownie.';
		|es_ES = 'No se puede abrir la ventana de reserva de stock. Primero, contabilice el documento. 
		|Inténtelo de nuevo.';
		|es_CO = 'No se puede abrir la ventana de reserva de stock. Primero, contabilice el documento. 
		|Inténtelo de nuevo.';
		|tr = 'Stok rezervasyonu penceresi açılamıyor. Önce belgeyi kaydedin.
		|Ardından tekrar deneyin.';
		|it = 'Impossibile aprire la finestra della Riserva delle scorte. Innanzitutto pubblicare il documento,
		| poi riprovare.';
		|de = 'Fehler beim Öffnen des Fensters Bestandsreservierung. Buchen Sie das Dokument zuerst.
		|Dann versuchen Sie erneut.'"));
	
EndProcedure

Function MessageCleaningWarningInventoryReservation(Ref) Export

	Return StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'In ""%1"", the product quantity was changed.
		|Reposting the document will clear the reserved product quantity specified manually. The new product quantity will be reserved and allocated automatically.'; 
		|ru = 'В ""%1"" изменено количество номенклатуры.
		|Перепроведение документа приведет к удалению зарезервированного количества номенклатуры, указанного вручную. Новое количество номенклатуры будет зарезервировано и распределено автоматически.';
		|pl = 'W ""%1"", została zmieniona ilość produktu.
		|Ponowne zatwierdzenie dokumentu usunie zarezerwowaną ilość produktu, określoną ręcznie. Nowa ilość produktu zostanie zarezerwowana i przydzielona automatycznie.';
		|es_ES = 'En ""%1"" se ha cambiado la cantidad del producto. 
		|Al reenviar el documento se borrará la cantidad del producto reservado especificada manualmente. La nueva cantidad del producto se reservará y asignará automáticamente.';
		|es_CO = 'En ""%1"" se ha cambiado la cantidad del producto. 
		|Al reenviar el documento se borrará la cantidad del producto reservado especificada manualmente. La nueva cantidad del producto se reservará y asignará automáticamente.';
		|tr = 'Ürün miktarı şurada değişti: ""%1"".
		|Belgeyi yeniden kaydetmek manuel olarak belirtilmiş rezerve ürün miktarını silecek. Yeni ürün miktarı otomatik olarak rezerve ve tahsis edilecek.';
		|it = 'In ""%1"" è stata modificata la quantità di articoli. 
		|Ripubblicando il documento saranno cancellate le quantità di prodotti riservati indicate manualmente. La nuova quantità di prodotto sarà riservata e allocata automaticamente.';
		|de = 'In ""%1"", ist die Produktmenge geändert.
		|Neubuchung des Dokuments wird die reservierte manuell angegebene Produktmenge löschen. Die neue Produktmenge wird reserviert und automatisch zugeordnet.'"), Ref);

	
EndFunction

#EndRegion

#EndRegion

#Region MessageTexts

#Region TabularSections

Function TabularSectionWillBeCleared(TabularSectionName = "", Refill = False) Export 
	
	If IsBlankString(TabularSectionName) Then
		
		If Refill Then
			Return NStr("en = 'Tabular section will be cleared and filled in again. Continue?'; ru = 'Табличная часть будет очищена и повторно заполнена. Продолжить?';pl = 'Sekcja tabelaryczna zostanie wyczyszczona i wypełniona ponownie. Kontynuować?';es_ES = 'Sección tabular se eliminará y rellenará de nuevo. ¿Continuar?';es_CO = 'Sección tabular se eliminará y rellenará de nuevo. ¿Continuar?';tr = 'Tablo bölümü silinip tekrar doldurulacak. Devam edilsin mi?';it = 'La parte tabellare sarà cancellata e ricompilata, continuare?';de = 'Der Tabellenabschnitt wird gelöscht und erneut ausgefüllt. Fortsetzen?'");
		Else
			Return NStr("en = 'Tabular section will be cleared. Continue?'; ru = 'Табличная часть будет очищена. Продолжить выполнение операции?';pl = 'Sekcja tabelaryczna zostanie wyczyszczona. Kontynuować?';es_ES = 'Sección tabular se vaciará. ¿Continuar?';es_CO = 'Sección tabular se vaciará. ¿Continuar?';tr = 'Tablo bölümü silinecek. Devam edilsin mi?';it = 'La parte tabellare sarà cancellata, continuare?';de = 'Der Tabellenabschnitt wird gelöscht. Fortsetzen?'");
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

#Region Reservation

Procedure ShowMessageNoProductsToReserve() Export
	
	MessageToUserText = NStr("en = 'There are no products to reserve.'; ru = 'Табличная часть ""Товары"" не заполнена!';pl = 'Brak produktów do zarezerwowania.';es_ES = 'No hay productos para reservar.';es_CO = 'No hay productos para reservar.';tr = 'Rezerve edilecek ürün yok.';it = 'Non ci sono articoli da riservare.';de = 'Es gibt keine Produkte zu reservieren.'");
	CommonClientServer.MessageToUser(MessageToUserText);
	
EndProcedure

Procedure ShowMessageNothingToClearAtReserve() Export
	
	MessageToUserText = NStr("en = 'There is nothing to clear.'; ru = 'Невозможно очистить колонку ""Резерв"", потому что табличная часть не заполнена.';pl = 'Nie ma nic do wyczyszczenia.';es_ES = 'No hay nada para liquidar.';es_CO = 'No hay nada para liquidar.';tr = 'Temizlenecek bir şey yok.';it = 'Non c''è nulla da cancellare.';de = 'Es gibt nichts zu löschen.'");
	CommonClientServer.MessageToUser(MessageToUserText);
	
EndProcedure

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
	
	Return NStr("en = 'The contract currency has changed. Check the document currency. If required, change it. Then, if you want to recalculate the prices according to the new document currency, select the ""Recalculate prices according to the document currency rate"" checkbox.'; ru = 'Изменилась валюта договора. Проверьте валюту документа и при необходимости измените ее. Затем, если вы хотите пересчитать цены в соответствии с новой валютой документа, установите флажок ""Пересчитать цены по курсу валюты документа"".';pl = 'Waluta kontraktu została zmieniona. Sprawdź walutę dokumentu. W razie konieczności, zmień ją. Następnie, jeśli chcesz przeliczyć ceny zgodnie z nową walutą dokumentu, zaznacz pole wyboru ""Przelicz ceny zgodnie z kursem waluty dokumentu"".';es_ES = 'La moneda del contrato ha cambiado. Compruebe la moneda del documento. Si es necesario, cámbiela. A continuación, si desea recalcular los precios según la nueva moneda del documento, seleccione la casilla de verificación ""Recalcular los precios según el tipo de moneda del documento"".';es_CO = 'La moneda del contrato ha cambiado. Compruebe la moneda del documento. Si es necesario, cámbiela. A continuación, si desea recalcular los precios según la nueva moneda del documento, seleccione la casilla de verificación ""Recalcular los precios según el tipo de moneda del documento"".';tr = 'Sözleşme para birimi değiştirildi. Belge para birimini kontrol edip, gerekirse değiştirin. Ardından, yeni belge para birimine göre fiyatları yeniden hesaplamak istiyorsanız ""Fiyatları belge para birimine göre yeniden hesapla"" onay kutusunu işaretleyin.';it = 'La valuta del contratto è stata modificata. Verificare la valuta del documento. Se richiesto, modificarla. Poi, per ricalcolare i prezzi in base alla nuova valuta del documento, selezionare la casella di controllo ""Ricalcolare i prezzi in base al tasso di valuta del documento""';de = 'Die Vertragswährung wurde verändert. Überprüfen Sie die Belegwährung. Ggf. ändern Sie sie. Dann aktivieren Sie das Kontrollkästchen ""Preise in Übereinstimmung mit dem Kurs der Belegwährung neu berechnen"" wenn Sie die Preise in Übereinstimmung mit dem Kurs der Belegwährung neu berechnen möchten.'");
	
EndFunction

Function GetApplyRatesOnNewDateQuestionText() Export
	
	Return NStr("en = 'The document date has changed. Do you want to apply the exchange rates effective on the new date?'; ru = 'Изменилась дата документа. Установить курс валюты в соответствии с курсом на новую дату?';pl = 'Data dokumentu uległa zmianie. Czy chcesz zastosować kurs waluty, obowiązujący na nową datę?';es_ES = 'La fecha del documento se ha cambiado. ¿Quiere aplicar los tipos de cambio vigentes en la nueva fecha?';es_CO = 'La fecha del documento se ha cambiado. ¿Quiere aplicar los tipos de cambio vigentes en la nueva fecha?';tr = 'Belge tarihi değiştirildi. Yeni tarihte geçerli olan döviz kurlarını uygulamak ister misiniz?';it = 'La data del documento è stata modificata. Applicare il tasso di cambio effetivo alla nuova data?';de = 'Das Datum des Dokuments wurde verändert. Möchten Sie die Wechselkurse für das neue Datum verwenden?'");
	
EndFunction

#EndRegion

#EndRegion