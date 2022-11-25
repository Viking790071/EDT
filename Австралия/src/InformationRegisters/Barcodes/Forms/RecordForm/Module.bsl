#Region ServiceProceduresAndFunctions

// Creates Barcode EAN13.
//
&AtServerNoContext
Function GenerateBarcodeEAN13()
	
	Return InformationRegisters.Barcodes.GenerateBarcodeEAN13();
	
EndFunction

&AtServerNoContext
Function GenerateBarcodeEAN13TransportWeightGood(WeightProductPrefix = "1")
	
	Return InformationRegisters.Barcodes.GenerateBarcodeTransportWeightGoodsEAN13(WeightProductPrefix);
	
EndFunction

&AtServer
Procedure SetUOMVisible(Products)
	
	If ValueIsFilled(Products) Then
		
		UnitsList = Catalogs.UOM.GetChoiceData(
			New Structure("Filter", New Structure("Owner", Products)));
		
		If UnitsList.Count() > 1 Then
			
			UnitsChoiceList = Items.MeasurementUnit.ChoiceList;
			UnitsChoiceList.Clear();
			
			For Each UnitValue In UnitsList Do
				If TypeOf(UnitValue.Value) = Type("CatalogRef.UOM") Then
					UnitsChoiceList.Add(UnitValue.Value, UnitValue.Presentation);
				Else
					UnitsChoiceList.Add(Catalogs.UOM.EmptyRef(), UnitValue.Presentation);
				EndIf;
			EndDo;
			
			Items.MeasurementUnit.Visible = True;
			
		Else
		
			Items.MeasurementUnit.Visible = False;
		
		EndIf;
		
	Else
		
		Items.MeasurementUnit.Visible = False;
		
	EndIf;
	
EndProcedure

// Peripherals
&AtClient
Function BarcodesReceived(BarcodesData)
	
	Modified = True;
	
	If BarcodesData.Count() > 0 Then
		Record.Barcode = BarcodesData[BarcodesData.Count() - 1].Barcode;
	EndIf;
	
	Return True;
	
EndFunction
// End Peripherals

// Procedure command handler  NewBarcode.
//
&AtClient
Procedure NewBarcode(Command)
	
	If UseOfflineExchangeWithPeripherals Then
		WeightProductPrefix = 1;
		ShowInputNumber(New NotifyDescription("NewBarcodeEnd", ThisObject, New Structure("WeightProductPrefix", WeightProductPrefix)), WeightProductPrefix, NStr("en = 'If the goods are sold by weight, enter prefix of the goods or click Cancel'; ru = 'Если товар весовой, то введите префикс весового товара или нажмите кнопку Отмена';pl = 'Jeśli towary są sprzedawane na wagę, wprowadź prefiks towaru lub kliknij Anuluj';es_ES = 'Si las mercancías se han vendido por peso, introducir el prefijo de las mercancías o hacer clic en Cancelar';es_CO = 'Si las mercancías se han vendido por peso, introducir el prefijo de las mercancías o hacer clic en Cancelar';tr = 'Mallar ağırlıkla satılıyorsa, malların önekini girin veya İptal''i tıklayın.';it = 'Se il prodotto è venduto a peso, immettere il prefisso del prodotto o fare clic su Annulla';de = 'Wenn die Waren nach Gewicht verkauft werden, geben Sie das Präfix der Waren ein oder klicken Sie auf Abbrechen'"), 1, 0);
	Else
		Record.Barcode = GenerateBarcodeEAN13();
	EndIf;
	
EndProcedure

&AtClient
Procedure NewBarcodeEnd(Result1, AdditionalParameters) Export
    
    WeightProductPrefix = ?(Result1 = Undefined, AdditionalParameters.WeightProductPrefix, Result1);
    
    
    Result = (Result1 <> Undefined);
    If Result Then
        Record.Barcode = GenerateBarcodeEAN13TransportWeightGood(WeightProductPrefix);
    Else
        Record.Barcode = GenerateBarcodeEAN13();
    EndIf;

EndProcedure

#EndRegion

#Region FormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetUOMVisible(Record.Products);
	
	// Peripherals
	UsePeripherals = DriveReUse.UsePeripherals();
	UseOfflineExchangeWithPeripherals = GetFunctionalOption("UseOfflineExchangeWithPeripherals");
	// End Peripherals
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
EndProcedure

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure

// Procedure - event handler NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() Then
		If EventName = "ScanData" Then
			// Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1)); // Get a barcode from the additional data
			EndIf;

			BarcodesReceived(Data);
		ElsIf EventName = "DataCollectionTerminal" Then
			BarcodesReceived(Parameter);
		EndIf;
	EndIf;
	// End Peripherals
	
EndProcedure

// Procedure - event handler FillCheckProcessingAtServer.
//
&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	Barcodes.Barcode,
	|	Barcodes.Products,
	|	Barcodes.Characteristic,
	|	Barcodes.Batch,
	|	PRESENTATION(Barcodes.Products) AS ProductsPresentation,
	|	PRESENTATION(Barcodes.Characteristic) AS CharacteristicPresentation,
	|	PRESENTATION(Barcodes.Batch) AS BatchPresentation
	|FROM
	|	InformationRegister.Barcodes AS Barcodes
	|WHERE
	|	Barcodes.Barcode = &Barcode";
	
	Query.SetParameter("Barcode", Record.Barcode);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() // Barcode is already written in the database
		AND Record.SourceRecordKey.Barcode <> Record.Barcode Then
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'This barcode is already specified for product %1'; ru = 'Такой штрихкод уже назначен для номенклатуры %1';pl = 'Ten kod kreskowy jest już przypisany do produktu %1';es_ES = 'El código de barras ya está especificado para el producto %1';es_CO = 'El código de barras ya está especificado para el producto %1';tr = 'Bu barkod zaten%1 ürünü için belirlenmiş';it = 'Il codice a barre è già specificato per l''articolo %1';de = 'Dieser Barcode ist bereits für das Produkt %1angegeben'"),
				Selection.ProductsPresentation)
			+ ?(ValueIsFilled(Selection.Characteristic), " " + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Variant: %1'; ru = 'Вариант: %1';pl = 'Wariant: %1';es_ES = 'Variante: %1';es_CO = 'Variante: %1';tr = 'Varyant: %1';it = 'Variante: %1';de = 'Variante: %1'"), 
				Selection.CharacteristicPresentation),
				"")
			+ ?(ValueIsFilled(Selection.Batch), " " + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Batch: %1'; ru = 'Партия: %1';pl = 'Partia: %1';es_ES = 'Paquete: %1';es_CO = 'Paquete: %1';tr = 'Parti: %1';it = 'Lotto: %1';de = 'Charge: %1'"),
				Selection.BatchPresentation), 
				"");
		
		DriveServer.ShowMessageAboutError(ThisForm, ErrorDescription, , , "Record.Barcode", Cancel);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProductsOnChangeAtServer()
	SetUOMVisible(Record.Products);
EndProcedure

&AtClient
Procedure ProductsOnChange(Item)
	ProductsOnChangeAtServer();
EndProcedure

#EndRegion
