
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("Owner") Then
		
		ProductsOwner = Parameters.Filter.Owner;
		UseSerialNumbers = ProductsOwner.UseSerialNumbers;
		
		If NOT ValueIsFilled(ProductsOwner)
			OR NOT ProductsOwner.ProductsType = Enums.ProductsTypes.InventoryItem Then
			
			AutoTitle = False;
			Title = NStr("en = 'Serial numbers are stored only for inventories'; ru = 'Серийные номера хранятся только для запасов';pl = 'Numery seryjne są przechowywane tylko dla zapasów';es_ES = 'Números de serie se almacenan solo para los inventarios';es_CO = 'Números de serie se almacenan solo para los inventarios';tr = 'Seri numaraları sadece stoklar için saklanır';it = 'I numeri di serie vengono memorizzati solo per gli inventari';de = 'Seriennummern werden nur für Inventare gespeichert'");
			
			Items.List.ReadOnly = True;
		EndIf;
		
		If NOT ProductsOwner.UseSerialNumbers Then
			Items.SearchByBarcodeForm.Enabled = False;
			Items.ShowSold.Enabled = False;
		EndIf;
		
	EndIf;
	
	If Parameters.Property("ShowSold") Then
	    ShowSold = Parameters.ShowSold;
	Else	
		ShowSold = False;
	EndIf;
	
	List.Parameters.SetParameterValue("ShowSold", ShowSold);
	Items.Sold.Visible = ShowSold;
	
	// Peripherals
	UsePeripherals = DriveReUse.UsePeripherals();
	// End Peripherals
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure

&AtClient
Procedure SoldOnChange(Item)
	
	Items.Sold.Visible = ShowSold;
	List.Parameters.SetParameterValue("ShowSold", ShowSold);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals" Then
		If EventName = "ScanData" Then
			// Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1)); // Get barcode from the main data
			Else
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1)); // Get barcode from additional data
			EndIf;
			
			BarcodesReceived(Data);
		EndIf;
	EndIf;
	// End Peripherals
	
EndProcedure

#Region Peripherals

// Procedure processes the received barcodes.
//
&AtClient
Procedure BarcodesReceived(BarcodesData) Export
	
	If NOT UseSerialNumbers Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'The product is not serialized.
		                    |Select the ""Use serial numbers"" check box in products card'; 
		                    |ru = 'Для номенклатуры не ведется учет по серийным номерам!
		                    |Установите флаг ""Использовать серийные номера"" в карточке номенклатуры';
		                    |pl = 'Produkt nie jest seryjny.
		                    |Zaznacz pole wyboru ""Użycie numerów seryjnych"" na karcie produktu';
		                    |es_ES = 'El producto no está seriado.
		                    |Seleccionar la casilla de verificación ""Utilizar números de serie"" en la tarjeta de productos';
		                    |es_CO = 'El producto no está seriado.
		                    |Seleccionar la casilla de verificación ""Utilizar números de serie"" en la tarjeta de productos';
		                    |tr = 'Ürün seri hale getirilmez. 
		                    |Ürün kartındaki ""Seri numaraları kullan "" onay kutusunu seçin';
		                    |it = 'Il prodotto non è serializzato.
		                    |Selezionare la casella di controlo ""Utilizzare numeri di serie"" nella scheda articolo';
		                    |de = 'Das Produkt wird nicht serialisiert.
		                    |Aktivieren Sie das Kontrollkästchen ""Seriennummern verwenden"" in der Produktkarte'");
		Message.Message();
		Return;
	EndIf;
	
	Barcode = BarcodesData[0].Barcode;
	
	For Each FilterItem In List.Filter.Items Do
		If FilterItem.LeftValue = New DataCompositionField("Owner") Then
			ProductsOwner = FilterItem.RightValue;
			Break;
		EndIf;
	EndDo;
	If NOT ValueIsFilled(ProductsOwner) AND Items.List.CurrentData<>Undefined Then
		ProductsOwner = Items.List.CurrentData.Owner;
	EndIf;
	If NOT ValueIsFilled(ProductsOwner) Then
		Return;
	EndIf;
	
	SerialNumber = GetSerialNumberByBarcode(BarcodesData, ProductsOwner);
	If ValueIsFilled(SerialNumber) Then
		
		Items.List.CurrentRow = SerialNumber;
		OpenForm("Catalog.SerialNumbers.ObjectForm",New Structure("Key",SerialNumber),ThisObject);
	Else
		
		MissingBarcodes		= FillByBarcodesData(BarcodesData);
		UnknownBarcodes		= MissingBarcodes.UnknownBarcodes;
		IncorrectBarcodesType	= MissingBarcodes.IncorrectBarcodesType;
		
		ReceivedIncorrectBarcodesType(IncorrectBarcodesType);
		
		If UnknownBarcodes.Count() > 0 Then
			
			Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisObject, UnknownBarcodes);
			
			OpenForm(
				"InformationRegister.Barcodes.Form.BarcodesRegistration",
				New Structure("UnknownBarcodes", UnknownBarcodes), ThisObject,,,,Notification
			);
			
			Return;
			
		EndIf;
		
		BarcodesAreReceivedFragment(UnknownBarcodes);
	EndIf;
	
EndProcedure

&AtClient
Function FillByBarcodesData(BarcodesData)
	
	UnknownBarcodes = New Array;
	IncorrectBarcodesType = New Array;
	
	If TypeOf(BarcodesData) = Type("Array") Then
		BarcodesArray = BarcodesData;
	Else
		BarcodesArray = New Array;
		BarcodesArray.Add(BarcodesData);
	EndIf;
	
	StructureData = New Structure();
	StructureData.Insert("BarcodesArray", BarcodesArray);
	StructureData.Insert("FilterProductsType", PredefinedValue("Enum.ProductsTypes.InventoryItem"));

	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
		   
		    CurBarcode.Insert("Products", ProductsOwner);
			UnknownBarcodes.Add(CurBarcode);
			
		ElsIf StructureData.FilterProductsType <> BarcodeData.ProductsType Then
			IncorrectBarcodesType.Add(New Structure("Barcode,Products,ProductsType", CurBarcode.Barcode, BarcodeData.Products, BarcodeData.ProductsType));
		ElsIf BarcodeData.Products = ProductsOwner Then
			
			If NOT ValueIsFilled(BarcodeData.SerialNumber) Then
				NewSerialNumber = CreateSerialNumber(CurBarcode.Barcode, ProductsOwner);
				If ValueIsFilled(NewSerialNumber) Then
					NotifyChanged(NewSerialNumber);
				EndIf;
				
				Items.List.CurrentRow = NewSerialNumber;
			Else
				Items.List.CurrentRow = BarcodeData.SerialNumber;
			EndIf;
			
		EndIf;
	EndDo;
	
	Return New Structure("UnknownBarcodes, IncorrectBarcodesType",UnknownBarcodes, IncorrectBarcodesType);
	
EndFunction

&AtServer
Function CreateSerialNumber(SerialNumberString, ProductsOwner)

	Ob = Catalogs.SerialNumbers.CreateItem();
	Ob.Owner = ProductsOwner;
	Ob.Description = SerialNumberString;
	
	Try
		Ob.Write();
		
		MessageString = NStr("en = 'Created serial number: %1%'; ru = 'Создан серийный номер: %1%';pl = 'Utworzony numer seryjny: %1%';es_ES = 'Número de serie creado: %1%';es_CO = 'Número de serie creado: %1%';tr = 'Oluşturulan seri numarası: %1%';it = 'Creato il numero di serie: %1%';de = 'Erstellte Seriennummer: %1%'");
		MessageString = StrReplace(MessageString, "%1%", SerialNumberString);
		CommonClientServer.MessageToUser(MessageString);
	Except
		CommonClientServer.MessageToUser(ErrorDescription());
	EndTry;
	
	Return Ob.Ref;
	
EndFunction

&AtServerNoContext
Procedure GetDataByBarCodes(StructureData)
	
	DataByBarCodes = InformationRegisters.Barcodes.GetDataByBarCodes(StructureData.BarcodesArray);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		BarcodeData = DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() <> 0 Then
			
			If NOT ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit  = BarcodeData.Products.MeasurementUnit;
			EndIf;
			BarcodeData.Insert("ProductsType", BarcodeData.Products.ProductsType);
			If ValueIsFilled(BarcodeData.MeasurementUnit)
				AND TypeOf(BarcodeData.MeasurementUnit) = Type("CatalogRef.UOM") Then
				BarcodeData.Insert("Ratio", BarcodeData.MeasurementUnit.Ratio);
			Else
				BarcodeData.Insert("Ratio", 1);
			EndIf;
		EndIf;
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure

&AtServerNoContext
Function GetSerialNumberByBarcode(BarcodeData, ProductsOwner)

	BarcodeString = BarcodeData[0].Barcode;
	SNData = InformationRegisters.Barcodes.GetDataByBarCodes(BarcodeData);
	
	WrittenBarcodeData = SNData[BarcodeString];
	If WrittenBarcodeData.Count() = 0 Then
		
		Return Undefined;
	ElsIf WrittenBarcodeData.Products = ProductsOwner Then
		
		Return WrittenBarcodeData.SerialNumber;
	Else	
		MessageString = NStr("en = 'Entered barcode %1% is bound to other product (serial number): %2%'; ru = 'Введенный штрихкод %1% привязан к другой номенклатуре (серийному номеру): %2%';pl = 'Wprowadzony kod kreskowy %1% jest powiązany z innym produktem (numerem seryjnym): %2%';es_ES = 'Código de barras introducido %1% está vinculado con otro producto (número de serie): %2%';es_CO = 'Código de barras introducido %1% está vinculado con otro producto (número de serie): %2%';tr = 'Girilen %1% barkodu başka ürüne bağlı (seri numarası): %2%';it = 'Il codice a barre inserito %1% è assegnato a un''altra nomenclatura (numero di serie): %2%';de = 'Eingegebener Barcode %1% ist an ein anderes Produkt (Seriennummer) gebunden: %2%'");
		MessageString = StrReplace(MessageString, "%1%", BarcodeString);
		MessageString = StrReplace(MessageString, "%2%", WrittenBarcodeData.Products);
		CommonClientServer.MessageToUser(MessageString);
		
		Return Undefined;
	EndIf;
	
EndFunction

// Procedure - command handler of the tabular section command panel.
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en = 'Enter barcode'; ru = 'Введите штрихкод';pl = 'Wprowadź kod kreskowy';es_ES = 'Introducir el código de barras';es_CO = 'Introducir el código de barras';tr = 'Barkod girin';it = 'Inserisci codice a barre';de = 'Geben Sie den Barcode ein'"));
	Modified = False;
	
EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, ExtendedParameters) Export
    
    CurBarcode = ?(Result = Undefined, ExtendedParameters.CurBarcode, Result);
    
    If NOT IsBlankString(CurBarcode) Then
		BarcodesArray = New Array;
		BarcodesArray.Add(New Structure("Barcode, Quantity", TrimAll(CurBarcode), 1));
		BarcodesReceived(BarcodesArray);
    EndIf;

EndProcedure

&AtClient
Procedure BarcodesAreReceivedEnd(ReturnParameters, Parameters) Export
	
	UnknownBarcodes = Parameters;
	
	If ReturnParameters <> Undefined Then
		
		BarcodesArray = New Array;
		
		For Each ArrayElement In ReturnParameters.RegisteredBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		For Each ArrayElement In ReturnParameters.ReceivedNewBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		MissingBarcodes		= FillByBarcodesData(BarcodesArray);
		UnknownBarcodes		= MissingBarcodes.UnknownBarcodes;
		IncorrectBarcodesType	= MissingBarcodes.IncorrectBarcodesType;
		ReceivedIncorrectBarcodesType(IncorrectBarcodesType);
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedFragment(UnknownBarcodes) Export
	
	For Each CurUndefinedBarcode In UnknownBarcodes Do
		
		MessageString = NStr("en = 'Barcode data is not found: %1%; quantity: %2%'; ru = 'Данные по штрихкоду не найдены: %1%; количество: %2%';pl = 'Nie znaleziono danych kodu kreskowego: %1%; ilość: %2%';es_ES = 'Datos del código de barras no encontrados: %1%; cantidad: %2%';es_CO = 'Datos del código de barras no encontrados: %1%; cantidad: %2%';tr = 'Barkod verisi bulunamadı: %1%; miktar: %2%';it = 'Il codice a barre non è stato trovato: %1%; quantità: %2%';de = 'Barcode-Daten wurden nicht gefunden: %1%; Menge: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Count);
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ReceivedIncorrectBarcodesType(IncorrectBarcodesType) Export
	
	For Each CurhInvalidBarcode In IncorrectBarcodesType Do
		
		MessageString = NStr("en = 'Product %2% founded by barcode %1% have type %3% which is not suitable for this table section'; ru = 'Найденная по штрихкоду %1% номенклатура ""%2%"" имеет тип %3%, который не подходит для этой табличной части';pl = 'Towar %2% znaleziony na podstawie kodu kreskowego %1% ma typ %3%, który nie odpowiada tej sekcji tabeli';es_ES = 'Producto %2% encontrado por el código de barras %1% tiene el tipo %3% que no conviene a esta sección de tablas';es_CO = 'Producto %2% encontrado por el código de barras %1% tiene el tipo %3% que no conviene a esta sección de tablas';tr = '%2% barkod ile bulunan %1% ürün, bu tablo bölümü için uygun olmayan%3% tipine sahiptir.';it = 'L''articolo %2%  trovato con il codice a barre -%1%- è di tipologia %3%, che non è adatta per questa area di tabella';de = 'Produkt %2%, das vom Barcode %1% gegründet wurde, hat den Typ %3%, der für diesen Tabellenabschnitt nicht geeignet ist'");
		MessageString = StrReplace(MessageString, "%1%", CurhInvalidBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurhInvalidBarcode.Products);
		MessageString = StrReplace(MessageString, "%3%", CurhInvalidBarcode.ProductsType);
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

#EndRegion //Peripherals

#Region LibrariesHandlers

// StandardSubsystems.SearchAndDeleteDuplicates

&AtClient
Procedure MergeSelected(Command)
	FindAndDeleteDuplicatesDuplicatesClient.MergeSelectedItems(Items.List);
EndProcedure

&AtClient
Procedure ShowUsage(Command)
	FindAndDeleteDuplicatesDuplicatesClient.ShowUsageInstances(Items.List);
EndProcedure

// End StandardSubsystems.SearchAndDeleteDuplicates

#EndRegion
