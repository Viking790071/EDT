
#Region ServiceProceduresAndFunctions
//

&AtServer
// Procedure fills the decoration with the list of product types
//
Procedure FillProductsTypeLabel(ProductsType)
	
	For Each ItemOfList In ProductsType Do
		
		Items.DecorationProductsTypeContent.Title = Items.DecorationProductsTypeContent.Title + ?(IsBlankString(Items.DecorationProductsTypeContent.Title), "", ", ") + ItemOfList.Value;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers
//

&AtServer
// Procedure - handler of the OnCreateAtServer event
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Parameters.Property("DiscountsMarkupsVisible") Then
		Raise NStr("en = 'Cannot open the product selection form this way. Open it from a business document.
				|For instance, in a Sales invoice, click Select > Goods.'; 
				|ru = 'Не удалось открыть форму выбора номенклатуры таким способом. Откройте ее из коммерческого документа.
				|Например, в инвойсе покупателю нажмите Выбрать > Товары.';
				|pl = 'W ten sposób nie można otworzyć formularza wyboru produktu. Otwórz go z dokumentu biznesowego.
				|Na przykład, w fakturze sprzedaży, kliknij Wybierz > Towary.';
				|es_ES = 'No se puede abrir el formulario de selección de productos de esta manera. Ábralo desde un documento comercial.
				|Por ejemplo, en una Factura de venta, haga clic en Seleccionar > Bienes.';
				|es_CO = 'No se puede abrir el formulario de selección de productos de esta manera. Ábralo desde un documento comercial.
				|Por ejemplo, en una Factura de venta, haga clic en Seleccionar > Bienes.';
				|tr = 'Ürün seçim formu bu şekilde açılamıyor. Formu bir ticari belgeden açın.
				|Örneğin, bir satış faturasında Seç > Mallar''a tıklayın.';
				|it = 'Impossibile aprire il modulo di selezione articolo in questo modo. Aprirlo da documento aziendale.
				|Ad esempio, in Fattura di vendita, cliccare su Seleziona > Merci.';
				|de = 'Fehler beim Öffnen des Formulars der Produktauswahl auf diesem Weg. Öffnen Sie es aus einem Geschäftsdokument.
				|Z. B., klicken Sie in einer Verkaufsrechnung auf Auswählen > Waren.'"); 
	EndIf;
	
	FillPropertyValues(Object, Parameters);
	
	FillProductsTypeLabel(Object.ProductsType);
	
	CommonClientServer.SetFormItemProperty(Items, "Company", "Visible", GetFunctionalOption("UseSeveralCompanies"));
	CommonClientServer.SetFormItemProperty(Items, "StructuralUnit", "Visible", GetFunctionalOption("UseSeveralWarehouses"));
	CommonClientServer.SetFormItemProperty(Items, "DiscountMarkupKind", "Visible", Parameters.DiscountsMarkupsVisible);
	
EndProcedure
 

#EndRegion
