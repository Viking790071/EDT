
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	StructureSupplierProduct = GetStructureSupplierProduct(CommandParameter);
	
	If ValueIsFilled(StructureSupplierProduct.Characteristic) Then
		
		MessageText = NStr("en = 'Cannot set the selected product cross-reference as default. 
			|Select a cross-reference that does not include a product variant.'; 
			|ru = 'Невозможно сделать данную номенклатуру поставщика ссылкой по умолчанию. 
			|Выберите номенклатуру поставщика, у которой нет вариантов.';
			|pl = 'Nie można ustawić wybranych powiązanych informacji o produkcie jako domyślnych. 
			|Wybierz powiązane informacje, które nie zawierają wariantu produktu.';
			|es_ES = 'No se puede establecer la referencia cruzada del producto seleccionado por defecto.
			|Seleccione una referencia cruzada que no incluya una característica de producto.';
			|es_CO = 'No se puede establecer la referencia cruzada del producto seleccionado por defecto.
			|Seleccione una referencia cruzada que no incluya una característica de producto.';
			|tr = 'Seçilen ürün çapraz referansı varsayılan olarak ayarlanamıyor.
			|Ürün varyantı içermeyen bir çapraz referans seçin.';
			|it = 'Impossibile impostare il riferimento incrociato dell''articolo selezionato come predefinito. 
			|Selezionare un riferimento incrociato che non includa una variante di articolo.';
			|de = 'Kann die ausgewählte Produktherstellartikelnummer nicht als Standard festlegen. 
			|Wählen Sie eine Herstellartikelnummer, die keine Produktvariante enthält.'");
		CommonClientServer.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	If Not ValueIsFilled(StructureSupplierProduct.SKU) Then
		
		MessageText = NStr("en = 'Cannot set the selected product cross-reference as default.
			|Select a product cross-reference with Item # specified.'; 
			|ru = 'Невозможно сделать данную номенклатуру поставщика ссылкой по умолчанию. 
			|Выберите номенклатуру поставщика с указанным артикулом.';
			|pl = 'Nie można ustawić wybranych powiązanych informacji o produkcie jako domyślnych.
			|Wybierz powiązane informacje z określonym numerem pozycji.';
			|es_ES = 'No se puede establecer la referencia cruzada del producto seleccionado por defecto.
			|Seleccione una referencia cruzada del producto con el artículo # especificado.';
			|es_CO = 'No se puede establecer la referencia cruzada del producto seleccionado por defecto.
			|Seleccione una referencia cruzada del producto con el artículo # especificado.';
			|tr = 'Seçilen ürün çapraz referansı varsayılan olarak ayarlanamıyor.
			|Öğe numarası belirtilmiş bir ürün çapraz referansı seçin.';
			|it = 'Impossibile impostare il riferimento incrociato dell''articolo selezionato come predefinito. 
			|Selezionare il riferimento incrociato dell''articolo con Elemento # specificato.';
			|de = 'Die ausgewählte Produktherstellartikelnummer kann nicht als Standard festgelegt werden.
			|Wählen Sie eine Produktherstellartikelnummer mit der angegebenen Artikel-Nr. aus.'");
		CommonClientServer.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	StructureCommandParameter = New Structure("CrossReference, StructureSupplierProduct", 
		CommandParameter, 
		StructureSupplierProduct);
	Notification = New NotifyDescription("EndQuestionSetProductCrossReferenceByDefault", ThisObject, StructureCommandParameter);
	
	TextQuestion = NStr("en = 'The product''s Supplier and Supplier item # will be automatically 
		|re-defined according to the settings of the default product cross-reference. 
		|Do you want to continue?'; 
		|ru = 'Поставщик и артикул номенклатуры поставщика будут автоматически перезаполнены из
		|настроек перекрестной ссылки товара по умолчанию.
		|Продолжить?';
		|pl = 'Dostawca produktu i numer pozycji dostawcy automatycznie 
		| zostaną ponownie określone zgodnie z ustawieniami domyślnych powiązanych informacji o produkcie. 
		|Czy chcesz kontynuować?';
		|es_ES = 'El proveedor del producto y el artículo # del proveedor se 
		|redefinirán automáticamente de acuerdo con la configuración de la referencia cruzada del producto por defecto. 
		|¿Quiere continuar?';
		|es_CO = 'El proveedor del producto y el artículo # del proveedor se 
		|redefinirán automáticamente de acuerdo con la configuración de la referencia cruzada del producto por defecto. 
		|¿Quiere continuar?';
		|tr = 'Ürünün tedarikçisi ve Tedarikçi öğesi numarası varsayılan ürün 
		|çapraz referansının ayarlarına göre otomatik olarak yeniden tanımlanacak.
		|Devam etmek istiyor musunuz?';
		|it = 'Il Fornitore prodotto e l''elemento # del Fornitore saranno 
		|ridefiniti automaticamente in base alle impostazioni del riferimento incrociato predefinito dell''articolo. 
		|Continuare?';
		|de = 'Der Lieferant des Produkts und die Lieferanten-Produkt-Id werden automatisch 
		| nach den Einstellungen der Standardproduktherstellartikelnummer neu definiert. 
		|Möchten Sie fortfahren?'"); 
	
	Mode = QuestionDialogMode.YesNo;
	ShowQueryBox(Notification, TextQuestion, Mode, 0);
	
EndProcedure

&AtServer
Function GetStructureSupplierProduct(CrossReference)
	
	Return Common.ObjectAttributesValues(CrossReference, "Products, SKU, Characteristic, Owner");
	
EndFunction

&AtClient
Procedure EndQuestionSetProductCrossReferenceByDefault(Result, StructureCommandParameter) Export
	
	If Result = DialogReturnCode.Yes Then
		
		If SetProductCrossReferenceByDefault(StructureCommandParameter) Then
		
			Notify("SupplierProductSetAsDefault", StructureCommandParameter.StructureSupplierProduct.Products);
		
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
// Procedure - writes new value in product
Function SetProductCrossReferenceByDefault(StructureCommandParameter)
	
	StructureSupplierProduct	= StructureCommandParameter.StructureSupplierProduct;
	NewSupplierProductByDefault	= StructureCommandParameter.CrossReference;
	
	ProductObject 							= StructureSupplierProduct.Products.GetObject();
	ProductObject.ProductCrossReference		= NewSupplierProductByDefault;
	ProductObject.UseDefaultCrossReference	= True;
	ProductObject.Vendor					= StructureSupplierProduct.Owner;
	
	Try
		
		ProductObject.Write();
		Result = True;
		
	Except
		
		MessageText = NStr("en = 'Cannot change the default product cross-reference. Close all windows and try again.'; ru = 'Не удалось изменить значение номенклатуры поставщика по умолчанию. Закройте все окна и попробуйте снова.';pl = 'Nie można zmienić domyślnych powiązanych informacji o produkcie. Zamknij wszystkie okna i spróbuj ponownie.';es_ES = 'No se puede cambiar la referencia cruzada del producto por defecto. Cierre todas las ventanas e inténtelo de nuevo.';es_CO = 'No se puede cambiar la referencia cruzada del producto por defecto. Cierre todas las ventanas e inténtelo de nuevo.';tr = 'Varsayılan ürün çapraz referansı değiştirilemiyor. Tüm pencereleri kapatın ve tekrar deneyin.';it = 'Impossibile modificare il riferimento incrociato predefinito dell''articolo. Chiudere tutte le finestre e riprovare.';de = 'Der Standardproduktquerverweis kann nicht geändert werden. Schließen Sie alle Fenster und versuchen Sie es erneut.'");
		CommonClientServer.MessageToUser(MessageText); 
		Result = False;
		
	EndTry;
	
	Return Result;
	
EndFunction

#EndRegion
