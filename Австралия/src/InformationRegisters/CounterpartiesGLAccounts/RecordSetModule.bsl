#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("Structure") Then
		FillPropertyValues(ThisObject[0], FillingData);
	EndIf;

	Contract = ThisObject[0].Contract;
	
	If ValueIsFilled(Contract)
		And Not (ValueIsFilled(ThisObject[0].Company) And ValueIsFilled(ThisObject[0].Counterparty)) Then
		ContractDataStructure = Common.ObjectAttributesValues(Contract, "Company, Owner");
		ThisObject[0].Company		= ContractDataStructure.Company;
		ThisObject[0].Counterparty	= ContractDataStructure.Owner;
	EndIf;

	If Not ValueIsFilled(ThisObject[0].TaxCategory) And ValueIsFilled(ThisObject[0].Counterparty) Then
		ThisObject[0].TaxCategory = Common.ObjectAttributeValue(ThisObject[0].Counterparty, "VATTaxation");
	EndIf;

EndProcedure

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(ThisObject.Filter.Company.Value)
		And Not ValueIsFilled(ThisObject.Filter.TaxCategory.Value)
		And Not ValueIsFilled(ThisObject.Filter.Counterparty.Value)
		And Not ValueIsFilled(ThisObject.Filter.Contract.Value) Then
		
		If ThisObject.Count() = 0 And ThisObject.Modified() Then
			Cancel = True;
			Raise NStr("en = 'Cannot delete the item with blank Company, Tax category, Counterparty and Contract.
					|It includes generic GL account settings applicable to all counterparties. They are required for creating and prefilling custom Counterparty GL accounts.'; 
					|ru = 'Не удалось удалить позицию с пустыми полями Организация, Налогообложение, Контрагент и Договор.
					|Она включает общие настройки счетов учета, применимые ко всем контрагентам. Заполните поля для создания и предварительного заполнения пользовательских Счетов учета контрагентов.';
					|pl = 'Nie można usunąć pozycji z pustymi polami Firma, Rodzaj opodatkowania VAT, Kontrahent i Kontrakt.
					|Zawiera ogólne ustawienia konta księgowego, mającego zastosowanie do wszystkich kontrahentów. Są one wymagane do tworzenia i wstępnego wypełnienia niestandardowych kont księgowych kontrahenta.';
					|es_ES = 'No se puede eliminar el artículo con Compañía, Categoría de impuestos, Contraparte y Contrato en blanco.
					|Incluye configuraciones de cuenta de libro mayor genéricas aplicables a todas las contrapartes. Son necesarios para crear y rellenar previamente cuentas de libro mayor de contraparte personalizadas.';
					|es_CO = 'No se puede eliminar el artículo con Compañía, Categoría de impuestos, Contraparte y Contrato en blanco.
					|Incluye configuraciones de cuenta de libro mayor genéricas aplicables a todas las contrapartes. Son necesarios para crear y rellenar previamente cuentas de libro mayor de contraparte personalizadas.';
					|tr = 'Boş İş yeri, Vergi kategorisi, Cari hesap ve Sözleşme içeren öğe silinemiyor.
					|Tüm cari hesaplara uygulanabilecek jenerik muhasebe ayarları içeriyor. Özel Cari hesap muhasebe hesaplarının oluşturulması ve önceden doldurulması için bunlar gerekli.';
					|it = 'Impossibile eliminare l''elemento con Azienda, Categoria fiscale, Controparte e Contratto vuoti.
					|Include impostazioni generiche di conto mastro a tutte le controparti. Sono richieste per la creazione e precompilazione dei conti di conto mastro personalizzati.';
					|de = 'Fehler beim Löschen der Position mit leerer Firma, Steuerkategorie, Geschäftspartner und Vertrag.
					|Sie enthält für alle Geschäftspartner verwendbare Ober-Einstellungen des Hauptbuch-Kontos. Sie sind für Erstellung und Vorauffüllung benutzerdefinierten Hauptbuch-Konten des Geschäftspartners.'");
		EndIf;
	
	EndIf;
	
EndProcedure

#EndRegion

#EndIf