#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	If Not Constants.ForeignExchangeAccounting.Get() Then
		For Each TabularSectionRow In AccountingRecords Do
			If TabularSectionRow.AccountDr.Currency Then
				TabularSectionRow.CurrencyDr = Constants.FunctionalCurrency.Get();
				TabularSectionRow.AmountCurDr = TabularSectionRow.Amount;
			EndIf;
			If TabularSectionRow.AccountCr.Currency Then
				TabularSectionRow.CurrencyCr = Constants.FunctionalCurrency.Get();
				TabularSectionRow.AmountCurCr = TabularSectionRow.Amount;
			EndIf;
		EndDo;
	EndIf;
	
	DocumentAmount = AccountingRecords.Total("Amount");
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("Posted", Posted);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	For Each TSRow In AccountingRecords Do
		If TSRow.AccountDr.Currency
		AND Not ValueIsFilled(TSRow.CurrencyDr) Then
			MessageText = StrTemplate(NStr("en = 'The ""Currency Dr"" column is not populated for the currency account in the %1 line of the ""Postings"" list.'; ru = 'Не заполнена колонка ""Валюта Дт"" для валютного счета в строке %1 списка ""Проводки"".';pl = 'Nie wypełniono kolumny ""Waluta dłużnika"" dla rachunku walutowego w wierszu %1 listy ""Księgowanie"".';es_ES = 'La columna ""Moneda de Débito"" no está poblada para la cuenta de monedas en la línea %1 de la lista ""Envíos"".';es_CO = 'La columna ""Moneda de Débito"" no está poblada para la cuenta de monedas en la línea %1 de la lista ""Envíos"".';tr = '""Para Birimi"" sütunu, ""Onaylar"" listesinin %1 satırındaki para birimi hesabı için doldurulmadı.';it = 'La colonna ""Valuta Debt"" non è compilata per il conto valuta nella riga %1 dell''elenco ""Pubblicazioni"".';de = 'Die Spalte ""Währung Soll"" wird für das Währungskonto in der %1 Zeile der Liste ""Buchungen"" nicht ausgefüllt.'"), String(TSRow.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"AccountingRecords",
				TSRow.LineNumber,
				"CurrencyDr",
				Cancel
			);
		EndIf;
		If TSRow.AccountDr.Currency
		AND Not ValueIsFilled(TSRow.AmountCurDr) Then
			MessageText = StrTemplate(NStr("en = 'The ""Amount (cur.) Dr"" column is not populated for currency account in the %1 line of the ""Postings"" list.'; ru = 'Не заполнена колонка ""Сумма (вал.) Дт"" для валютного счета в строке %1 списка ""Проводки"".';pl = 'Nie wypełniono kolumny ""Kwota (waluta) dłużnika"" dla rachunku walutowego w wierszu %1 listy ""Księgowanie"".';es_ES = 'La columna del ""Importe (actual) de débito"" no está poblada para la cuenta de monedas en la %1 líneas de la lista de ""Envíos"".';es_CO = 'La columna del ""Importe (actual) de débito"" no está poblada para la cuenta de monedas en la %1 líneas de la lista de ""Envíos"".';tr = '""Tutar (döviz)"" sütunu, ""Onaylar"" listesinin %1 satırındaki para birimi hesabı için doldurulmadı.';it = 'La colonna ""Importo (val.) Debt"" non è compilata per il conto di valuta nella linea %1 dell''elenco ""Pubblicazioni"".';de = 'Die Spalte ""Betrag (aktuell) Soll"" wird für das Währungskonto in der %1 Zeile ""Buchungen"" nicht ausgefüllt.'"), String(TSRow.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"AccountingRecords",
				TSRow.LineNumber,
				"AmountCurDr",
				Cancel
			);
		EndIf;
		If TSRow.AccountCr.Currency
		AND Not ValueIsFilled(TSRow.CurrencyCr) Then
			MessageText = StrTemplate(NStr("en = 'Column ""Currency Kt"" is not filled for currency account in string %1 of list ""Posting"".'; ru = 'Не заполнена колонка ""Валюта Кт"" для валютного счета в строке %1 списка ""Проводки"".';pl = 'Nie wypełniono kolumny ""Waluta pożyczkodawcy"" dla rachunku walutowego w wierszu %1 listy ""Księgowanie"".';es_ES = 'Columna ""Moneda Kt"" no está rellenada para la cuenta de monedas en la línea %1 de la lista ""Envíos"".';es_CO = 'Columna ""Moneda Kt"" no está rellenada para la cuenta de monedas en la línea %1 de la lista ""Envíos"".';tr = '""Para birimi Kt"" sütunu ""Onay"" listesinin %1 dizesinde para birimi hesabı için doldurulmadı.';it = 'La colonna ""Valuta Cred"" non è compilata per il conto valuta nella stringa %1 dell''elenco ""Pubblicazioni"".';de = 'Die Spalte ""Währung Kt"" ist für das Währungskonto in der Zeichenfolge %1 der Liste ""Buchung"" nicht ausgefüllt.'"), String(TSRow.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"AccountingRecords",
				TSRow.LineNumber,
				"CurrencyCr",
				Cancel
			);
		EndIf;
		If TSRow.AccountCr.Currency
		AND Not ValueIsFilled(TSRow.AmountCurCr) Then
			MessageText = StrTemplate(NStr("en = 'Column ""Currency Kt"" is not filled for currency account in string %1 of list ""Posting"".'; ru = 'Не заполнена колонка ""Валюта Кт"" для валютного счета в строке %1 списка ""Проводки"".';pl = 'Nie wypełniono kolumny ""Waluta pożyczkodawcy"" dla rachunku walutowego w wierszu %1 listy ""Księgowanie"".';es_ES = 'Columna ""Moneda Kt"" no está rellenada para la cuenta de monedas en la línea %1 de la lista ""Envíos"".';es_CO = 'Columna ""Moneda Kt"" no está rellenada para la cuenta de monedas en la línea %1 de la lista ""Envíos"".';tr = '""Para birimi Kt"" sütunu ""Onay"" listesinin %1 dizesinde para birimi hesabı için doldurulmadı.';it = 'La colonna ""Valuta Cred"" non è compilata per il conto valuta nella stringa %1 dell''elenco ""Pubblicazioni"".';de = 'Die Spalte ""Währung Kt"" ist für das Währungskonto in der Zeichenfolge %1 der Liste ""Buchung"" nicht ausgefüllt.'"), String(TSRow.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"AccountingRecords",
				TSRow.LineNumber,
				"AmountCurCr",
				Cancel
			);
		EndIf;
	EndDo;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.Operation.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
EndProcedure

#EndRegion

#EndIf