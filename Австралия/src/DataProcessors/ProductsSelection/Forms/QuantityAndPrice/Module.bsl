
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Products = Parameters.Products;
	Quantity = Parameters.Quantity;
	MeasurementUnit = Parameters.MeasurementUnit;
	Factor = Parameters.Factor;
	Price = Parameters.Price;
	
	SetFormItemsProperties(Parameters.SelectionSettingsCache);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AmountCalculation();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandler

&AtClient
Procedure QuantityOnChange(Item)
	
	AmountCalculation();
	
EndProcedure

&AtClient
Procedure MeasurementUnitOnChange(Item)
	
	If TypeOf(MeasurementUnit) = Type("CatalogRef.UOM")
		AND ValueIsFilled(MeasurementUnit) Then
		
		NewFactor = GetUOMFactor(MeasurementUnit);
		
	Else
		
		NewFactor = 1;
		
	EndIf;
	
	If Factor <> 0 AND Price <> 0 Then
		
		Price = Price * NewFactor / Factor;
		
	EndIf;
	
	Factor = NewFactor;
	
	AmountCalculation();
	
EndProcedure

&AtClient
Procedure PriceOnChange(Item)
	
	AmountCalculation();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	Result = New Structure;
	
	Result.Insert("Quantity", Quantity);
	Result.Insert("MeasurementUnit", MeasurementUnit);
	Result.Insert("Factor", Factor);
	Result.Insert("Price", Price);
	
	Close(Result);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetFormItemsProperties(SelectionSettingsCache)
	
	PriceEnabled = (SelectionSettingsCache.RequestPrice AND SelectionSettingsCache.AllowedToChangeAmount);
	
	CommonClientServer.SetFormItemProperty(Items, "QuantityGroup", "Enabled", SelectionSettingsCache.RequestQuantity);
	CommonClientServer.SetFormItemProperty(Items, "Price", "Enabled", PriceEnabled);
	
	If SelectionSettingsCache.RequestQuantity Then
		If PriceEnabled Then
			TitleText = NStr("en = 'Input quantity and price'; ru = 'Введите количество и цену';pl = 'Wprowadź ilość i cenę';es_ES = 'Cantidad de entrada y precio';es_CO = 'Cantidad de entrada y precio';tr = 'Miktar ve fiyat gir';it = 'Inserite quantità e prezzo';de = 'Eingangsmenge und Preis'");
		Else
			TitleText = NStr("en = 'Input quantity'; ru = 'Введите количество';pl = 'Wprowadź ilość';es_ES = 'Cantidad de entrada';es_CO = 'Cantidad de entrada';tr = 'Miktar gir';it = 'Inserite quantità';de = 'Menge eingeben'");
		EndIf;
	Else
		TitleText = NStr("en = 'Input price'; ru = 'Введите цену';pl = 'Wprowadź cenę';es_ES = 'Precio de entrada';es_CO = 'Precio de entrada';tr = 'Fiyat gir';it = 'Inserimento prezzo';de = 'Preis eingeben'");
	EndIf;
	
	Title = TitleText;
	
EndProcedure

&AtClient
Procedure AmountCalculation()
	Amount = Quantity * Price;
EndProcedure

&AtServerNoContext
Function GetUOMFactor(MeasurementUnit)
	
	Return MeasurementUnit.Factor;
	
EndFunction

#EndRegion