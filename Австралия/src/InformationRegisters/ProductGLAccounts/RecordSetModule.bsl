#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(ThisObject.Filter.Company.Value)
		And Not ValueIsFilled(ThisObject.Filter.Product.Value)
		And Not ValueIsFilled(ThisObject.Filter.ProductCategory.Value)
		And Not ValueIsFilled(ThisObject.Filter.StructuralUnit.Value) Then
		
		If ThisObject.Count() = 0 And ThisObject.Modified() Then
			Cancel = True;
			Raise NStr("en = 'Cannot delete the item with blank Company, Product, Product category and Warehouse.
					|It includes generic GL account settings applicable to all counterparties. They are required for creating and prefilling custom Product GL accounts.
					|For instance, counterparty- or warehouse-specific Product GL accounts.'; 
					|ru = 'Не удалось удалить позицию с пустыми полями Организация, Номенклатура, Налогообложение и Склад.
					|Она включает общие настройки счетов учета, применимые ко всем контрагентам. Заполните поля для создания и предварительного заполнения пользовательских Счетов учета номенклатуры.
					|Например, Счета учета номенклатуры для контрагента или склада.';
					|pl = 'Nie można usunąć pozycji z pustymi polami Firma, Produkt, Kategoria produktu i Magazyn.
					|Zawiera ogólne ustawienia konta księgowego, mającego zastosowanie do wszystkich kontrahentów. Są one wymagane do tworzenia i wstępnego wypełnienia niestandardowych kont księgowych produktu.
					|Na przykład, konta księgowe produktów, specyficznych dla kontrahenta, lub magazynu.';
					|es_ES = 'No se puede eliminar el artículo con Compañía, Producto, Categoría de producto y Almacén en blanco.
					|Incluye configuraciones de cuenta del libro mayor genéricas aplicables a todas las contrapartes. Son necesarios para crear y rellenar previamente cuentas del libro mayor de productos personalizadas.
					|Por ejemplo, cuentas del libro mayor de productos específicas de contraparte o almacén.';
					|es_CO = 'No se puede eliminar el artículo con Compañía, Producto, Categoría de producto y Almacén en blanco.
					|Incluye configuraciones de cuenta del libro mayor genéricas aplicables a todas las contrapartes. Son necesarios para crear y rellenar previamente cuentas del libro mayor de productos personalizadas.
					|Por ejemplo, cuentas del libro mayor de productos específicas de contraparte o almacén.';
					|tr = 'Boş İş yeri, Ürün, Ürün kategorisi ve Ambar içeren öğe silinemiyor.
					|Tüm cari hesaplara uygulanabilecek jenerik muhasebe hesapları içeriyor. Özel Ürün muhasebe hesaplarının oluşturulması ve önceden doldurulması için bunlar gerekli.
					|Örneğin, cari hesaba veya ambara özel Ürün muhasebe hesapları.';
					|it = 'Impossibile eliminare l''elemento con Azienda, Articolo, Categoria articolo e Magazzino vuoti.
					|Include impostazioni generiche di conto mastro applicabili a tutte le controparti. Sono richieste per la creazione e precompilazione di conti mastro personalizzati.
					|Ad esempio, per specifici conti mastro di controparti (o magazzini).';
					|de = 'Fehler beim Löschen der Position mit leerer Firma, Produkt, Produktkategorie und Lager.
					|Sie enthält für alle Geschäftspartner verwendbare Ober-Einstellungen des Hauptbuch-Kontos. Sie sind für Erstellung und Vorauffüllung benutzerdefinierten Hauptbuch-Konten des Geschäftspartners.
					|Y. B., spezifische für Geschäftspartner oder Lager Produkt-Hauptbuch-Konten.'");
		EndIf;
	
	EndIf;
	
EndProcedure

#EndRegion

#EndIf