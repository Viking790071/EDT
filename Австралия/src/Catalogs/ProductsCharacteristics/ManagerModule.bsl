#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Event handler procedure ChoiceDataGetProcessor.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") AND TypeOf(Parameters.Filter.Owner) = Type("CatalogRef.Products") Then
		// If selection parameter link by products and
		// services value is set, then add selection parameters by the owner filter - product group.
		
		Products 		 = Parameters.Filter.Owner;
		ProductsCategory = Parameters.Filter.Owner.ProductsCategory;
		
		MessageText = "";
		If Not ValueIsFilled(Products) Then
			MessageText = NStr("en = 'Product is required.'; ru = 'Укажите номенклатуру.';pl = 'Wymagany jest produkt.';es_ES = 'Se requiere un producto.';es_CO = 'Se requiere un producto.';tr = 'Ürün gerekli.';it = 'È richiesto l''articolo.';de = 'Produkte ist ein Pflichtfeld.'");
		ElsIf Parameters.Property("ThisIsReceiptDocument") AND Products.ProductsType = Enums.ProductsTypes.Service Then
			MessageText = NStr("en = 'Accounting by variants is not kept for services of external counterparties.'; ru = 'Для услуг сторонних контрагентов не ведется учет по вариантам!';pl = 'Dla kontrahentów zewnętrznych nie jest prowadzona ewidencja według wariantów.';es_ES = 'Contabilidad por variantes no se ha guardado para los servicios de las contrapartes externas.';es_CO = 'Contabilidad por variantes no se ha guardado para los servicios de las contrapartes externas.';tr = 'Harici cari hesapların hizmetleri için değişkenler bazında muhasebe yapılmaz.';it = 'La contabilità per varianti non è gestita per servizi di controparti esterne.';de = 'Die Abrechnung nach Varianten erfolgt nicht für Dienstleistungen externer Geschäftspartner.'");
		ElsIf Not Products.UseCharacteristics Then
			MessageText = NStr("en = 'Inventory tracking by variant is disabled.
				|To turn it on, go to Settings > Purchases/Warehouse,
				|and under ""Inventory (Products)"", select ""Inventory accounting by variants"".'; 
				|ru = 'Учет запасов по вариантам отключен.
				|Чтобы включить его, перейдите в меню Настройки > Закупки/Склад
				|и в разделе ""Запасы (номенклатура)"" установите флажок ""Учет запасов в разрезе вариантов"".';
				|pl = 'Śledzenie zapasów według wariantów jest wyłączone.
				|W celu włączenia przejdź do Ustawienia > Zakup/Magazyn,
				|i w ""Zapasy (Produkty)"", zaznacz ""Ewidencja zapasów według wariantów"".';
				|es_ES = 'El rastreo de inventario por variantes está desactivado.
				|Para activarlo, ir a Configuraciones > Compras/Almacenes,
				|y en ""Inventario (productos)"", seleccione ""Contabilidad de inventario por variantes"".';
				|es_CO = 'El rastreo de inventario por variantes está desactivado.
				|Para activarlo, ir a Configuraciones > Compras/Almacenes,
				|y en ""Inventario (productos)"", seleccione ""Contabilidad de inventario por variantes"".';
				|tr = 'Varyantlara göre stok takibi kapalı.
				|Açmak için, Ayarlar > Satın alma / Ambar sayfasının
				|""Stok (Ürünler)"" bölümünde ""Varyantlara göre envanter muhasebesi""ni seçin.';
				|it = 'Il tracciamento delle scorte per variante è disattivato.
				|Per attivarlo, andare in Impostazioni > Acquisti/Magazzino,
				|e in ""Scorte (Articoli)"", selezionare ""Contabilità scorte secondo varianti"".';
				|de = 'Bestandsverfolgung nach Variante ist deaktiviert. Um sie zu aktivieren:
				|. Gehen Sie zu Einstellungen > Einkäufe / Lager,
				| und aktivieren Sie ""Bestandsbuchhaltung nach Varianten"" unter ""Bestand (Produkte)"".'");
		EndIf;
		
		If Not IsBlankString(MessageText) Then
			If Not UsersClientServer.IsExternalUserSession() Then
				CommonClientServer.MessageToUser(MessageText);
			EndIf;
			StandardProcessing = False;
			Return;
		EndIf;
		
		FilterArray = New Array;
		FilterArray.Add(Products);
		FilterArray.Add(ProductsCategory);
		
		Parameters.Filter.Insert("Owner", FilterArray);
		
	EndIf;
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.ProductsCharacteristics);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#Region CloneProductRelatedData

Procedure MakeRelatedProductVariants(ProductReceiver, ProductSource) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ProductsCharacteristics.Ref AS ProductVariant
		|FROM
		|	Catalog.ProductsCharacteristics AS ProductsCharacteristics
		|WHERE
		|	ProductsCharacteristics.Owner = &ProductSource";
	
	Query.SetParameter("ProductSource", ProductSource);
	
	QueryResult = Query.Execute();
	
	SelectionVariants = QueryResult.Select();
	
	While SelectionVariants.Next() Do
		ProductVariantReceiver = SelectionVariants.ProductVariant.Copy();
		ProductVariantReceiver.Owner = ProductReceiver;
		ProductVariantReceiver.Write();
	EndDo;
	
EndProcedure

#EndRegion

#EndIf