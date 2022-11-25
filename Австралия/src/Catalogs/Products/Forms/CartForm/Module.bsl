
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("CartAddress") And ValueIsFilled(Parameters.CartAddress) Then
		TableToLoad = GetFromTempStorage(Parameters.CartAddress);
		Cart.Load(TableToLoad);
	EndIf;
	
	If Parameters.Property("FilterPriceType") Then
		FilterPriceType = Parameters.FilterPriceType;
	EndIf;
	
	Items.SaveVariant.Enabled = (Cart.Count() > 0);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RefreshLabelSelectedProducts();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	If Not AllowClosing Then
		Cancel = True;
		AttachIdleHandler("CloseFormAndMoveToDocument", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure CartOnChange(Item)
	
	Items.SaveVariant.Enabled = (Cart.Count() > 0);
	RefreshLabelSelectedProducts();
	
EndProcedure

&AtClient
Procedure CartQuantityOnChange(Item)
	
	CartLine = Items.Cart.CurrentData;
	CartLine.Amount = CartLine.Quantity * CartLine.Price;
	DriveClient.CalculateVATAmount(CartLine, True);
	
	RefreshLabelSelectedProducts();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ClearCart(Command)
	
	Cart.Clear();
	Close();
	
EndProcedure

&AtClient
Procedure SaveVariant(Command)
	
	SaveVariantAtServer();
	AllowClosing = True;
	Close("SaveVariant");
	
EndProcedure

&AtClient
Procedure BackToList(Command)
	
	CloseParameter = New Structure("Cart, MoveToDocument", Cart, MoveToDocument);
	Close(CloseParameter);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure CloseFormAndMoveToDocument()
	
	AllowClosing = True;
	If MoveToDocument Then
		Close("MoveToDocument");
	Else
		CloseParameter = New Structure("Cart", Cart);
		Close(CloseParameter);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshLabelSelectedProducts() Export
	
	ProductsQuantity = Cart.Total("Quantity");
	ProductsAmount = Cart.Total("Amount");
	LabelSelectedProducts = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Quantity: %1; Total: %2 %3'; ru = 'Количество: %1; Итого: %2 %3';pl = 'Ilość: %1; Łącznie: %2 %3';es_ES = 'Cantidad: %1; Total: %2 %3';es_CO = 'Cantidad: %1; Total: %2 %3';tr = 'Miktar: %1; Toplam:%2 %3';it = 'Quantità: %1; Totale: %2 %3';de = 'Menge: %1; Gesamt: %2 %3'"),
		ProductsQuantity,
		Format(ProductsAmount, "NFD=2; NZ=0"),
		?(ValueIsFilled(FilterPriceType),
			PriceTypeCurrency(FilterPriceType),
			""));
	
EndProcedure

&AtServerNoContext
Function PriceTypeCurrency(PriceType)
	
	Return Common.ObjectAttributeValue(PriceType, "PriceCurrency");
	
EndFunction

&AtServer
Procedure SaveVariantAtServer()
	
	ObjectKeyName = "ProductsCart";
	
	SettingsString = ValueToStringInternal(Cart.Unload());
	VariantText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Variant: %1 items, %2 %3'; ru = 'Вариант: %1 единиц, %2 %3';pl = 'Wariant: %1 pozycji, %2 %3';es_ES = 'Variante: %1 unidades, %2 %3';es_CO = 'Variante: %1 unidades, %2 %3';tr = 'Varyant: %1 öğe, %2 %3';it = 'Variante: %1 elementi, %2, %3';de = 'Variante: %1 Positionen, %2 %3'"),
		Cart.Total("Quantity"),
		Format(Cart.Total("Amount"), "NFD=2; NZ=0"),
		?(ValueIsFilled(FilterPriceType),
				PriceTypeCurrency(FilterPriceType),
				""));
		
	SettingDescription = VariantText + Chars.LF + New UUID;
	
	FormDataSettingsStorage.Save(ObjectKeyName, SettingDescription, SettingsString);
	Cart.Clear();
	
EndProcedure

#EndRegion
