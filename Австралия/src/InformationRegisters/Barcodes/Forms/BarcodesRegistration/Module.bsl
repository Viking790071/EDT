#Region Variables

&AtClient
Var ClosingProcessing;

&AtServer
Var UnknownBarcodes;

#EndRegion

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	UsePeripherals = DriveReUse.UsePeripherals();
	
	For Each RowOfBarcode In Parameters.UnknownBarcodes Do
		NewBarcode = Barcodes.Add();
		NewBarcode.Barcode = RowOfBarcode.Barcode;
		NewBarcode.Quantity = RowOfBarcode.Quantity;
	EndDo;
	
	UnknownBarcodes = Parameters.UnknownBarcodes;
	
	//Conditional appearance
	SetConditionalAppearance();
	
EndProcedure

&AtServer
Procedure RegisterBarcodesAtServer()
	
	For Each RowOfBarcode In Barcodes Do
		
		If RowOfBarcode.Registered OR Not ValueIsFilled(RowOfBarcode.Products) Then
			Continue;
		EndIf;
		
		Try
			
			RecordManager = InformationRegisters.Barcodes.CreateRecordManager();
			RecordManager.Products = RowOfBarcode.Products;
			RecordManager.Characteristic = RowOfBarcode.Characteristic;
			RecordManager.Batch = RowOfBarcode.Batch;
			RecordManager.Barcode = RowOfBarcode.Barcode;
			RecordManager.Write();
			
			RowOfBarcode.RegisteredByProcessing = True;
			
		Except
		
		EndTry
		
	EndDo;
	
EndProcedure

&AtClient
Procedure MoveIntoDocument(Command)
	
	ClearMessages();
	
	If CheckFilling() Then
		
		RegisterBarcodesAtServer();
		
		FoundUnregisteredGoods = Barcodes.FindRows(New Structure("Registered, RegisteredByProcessing", False, False));
		If FoundUnregisteredGoods.Count() > 0 Then
			
			QuestionText = NStr("en = 'Some new barcodes do not linked to products.
			                    |The products will not be written to the document.
			                    |Put them aside as not scanned.'; 
			                    |ru = 'Не для всех новых штрихкодов указана соответствующая номенклатура.
			                    |Эти товары не будут перенесены в документ.
			                    |Отложите их в сторону как неотсканированные.';
			                    |pl = 'Niektóre nowe kody kreskowe nie są powiązane z produktami.
			                    |Produkty nie zostaną zapisane w dokumencie.
			                    |Odłóż je, jako niezeskanowane.';
			                    |es_ES = 'Algunos códigos de barras no están vinculados a los productos.
			                    |Los productos no se grabarán en el documento.
			                    |Colocarlos aparte como no escaneados.';
			                    |es_CO = 'Algunos códigos de barras no están vinculados a los productos.
			                    |Los productos no se grabarán en el documento.
			                    |Colocarlos aparte como no escaneados.';
			                    |tr = 'Bazı yeni barkodlar ürünlere bağlı değildir. 
			                    | Ürünler belgeye yazılmayacak. 
			                    | Taranmamış olarak ayırın.';
			                    |it = 'Alcuni nuovi codici a barre non legati ai prodotti.
			                    |il prodotto non verrà scritto nel documento.
			                    |Metteteli da parte non essendo stati scansionati.';
			                    |de = 'Einige neue Barcodes sind nicht an Produkte gebunden.
			                    |Die Produkte werden nicht in das Dokument geschrieben.
			                    |Legen Sie sie als nicht gescannt beiseite.'"
			);
			
			QuestionResult = Undefined;
			
			ShowQueryBox(New NotifyDescription("TransferToDocumentEnd", ThisObject), QuestionText, QuestionDialogMode.OKCancel);
			Return;
			
		EndIf;
		
		TransferToDocumentFragment();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TransferToDocumentEnd(Result, AdditionalParameters) Export
	
	QuestionResult = Result;
	If QuestionResult = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	
	TransferToDocumentFragment();
	
EndProcedure

&AtClient
Procedure TransferToDocumentFragment()
	
	Var RegisteredBarcodes, FoundsRegisteredBarcodes, FoundDeferredProducts, FoundsBarcodes, DeferredProducts, ClosingParameter, ReceivedNewBarcodes, RowOfBarcode;
	
	RegisteredBarcodes = New Array;
	FoundsRegisteredBarcodes = Barcodes.FindRows(New Structure("RegisteredByProcessing", True));
	For Each RowOfBarcode In FoundsRegisteredBarcodes Do
		RegisteredBarcodes.Add(New Structure("Barcode, Quantity", RowOfBarcode.Barcode, RowOfBarcode.Quantity));
	EndDo;
	
	DeferredProducts = New Array;
	FoundDeferredProducts = Barcodes.FindRows(New Structure("Registered, RegisteredByProcessing", False, False));
	For Each RowOfBarcode In FoundDeferredProducts Do
		DeferredProducts.Add(New Structure("Barcode, Quantity", RowOfBarcode.Barcode, RowOfBarcode.Quantity));
	EndDo;
	
	ReceivedNewBarcodes = New Array;
	FoundsBarcodes = Barcodes.FindRows(New Structure("Registered", True));
	For Each RowOfBarcode In FoundsBarcodes Do
		ReceivedNewBarcodes.Add(New Structure("Barcode, Quantity", RowOfBarcode.Barcode, RowOfBarcode.Quantity));
	EndDo;
	
	ClosingParameter = New Structure("DeferredProducts, RegisteredBarcodes, ReceivedNewBarcodes", DeferredProducts, RegisteredBarcodes, ReceivedNewBarcodes);
	ClosingProcessing = True;
	Close(ClosingParameter);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	#If Not WebClient Then
	Beep();
	#EndIf
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
	ClosingProcessing = False;
	CurrentItem = Items.Products;
	
EndProcedure

&AtServerNoContext
Function GetBarcodeData(Barcode)

	Query = New Query;
	Query.Text = 
	"SELECT
	|	Barcodes.Products,
	|	Barcodes.Characteristic,
	|	Barcodes.Batch
	|FROM
	|	InformationRegister.Barcodes AS Barcodes
	|WHERE
	|	Barcodes.Barcode = &Barcode";
	
	Query.SetParameter("Barcode", Barcode);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		BarcodeData = New Structure("Products, Characteristic, Batch");
		FillPropertyValues(BarcodeData, Selection);
		Return BarcodeData;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Peripherals
&AtClient
Function BarcodesReceived(BarcodesData)
	
	Modified = True;
	
	For Each DataItem In BarcodesData Do
		FoundStrings = Barcodes.FindRows(New Structure("Barcode", DataItem.Barcode));
		If FoundStrings.Count() > 0 Then
			FoundStrings[0].Quantity = FoundStrings[0].Quantity + DataItem.Quantity;
		Else
			BarcodeData = GetBarcodeData(DataItem.Barcode);
			If BarcodeData = Undefined Then
				NewBarcode = Barcodes.Add();
				NewBarcode.Barcode = DataItem.Barcode;
				NewBarcode.Quantity = DataItem.Quantity;
			Else
				NewBarcode = Barcodes.Add();
				NewBarcode.Barcode   = DataItem.Barcode;
				NewBarcode.Quantity = DataItem.Quantity;
				FillPropertyValues(NewBarcode, BarcodeData);
				NewBarcode.Registered = True;
			EndIf;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction
// End Peripherals

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

&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	Barcodes.Barcode AS Barcode,
	|	Barcodes.Products AS Products,
	|	Barcodes.Characteristic AS Characteristic,
	|	Barcodes.Batch AS Batch,
	|	Barcodes.Products.Description AS ProductsPresentation,
	|	Barcodes.Characteristic.Description AS CharacteristicPresentation,
	|	Barcodes.Batch.Description AS BatchPresentation
	|FROM
	|	InformationRegister.Barcodes AS Barcodes
	|WHERE
	|	Barcodes.Barcode IN(&Barcodes)";
	
	Query.SetParameter("Barcodes", Barcodes.Unload(New Structure("Registered", False),"Barcode").UnloadColumn("Barcode"));
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then // Barcode is already written in the database
		
		TSRow = Barcodes.FindRows(New Structure("Barcode", Selection.Barcode))[0];
		
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
		
		CommonClientServer.MessageToUser(ErrorDescription,, "Barcodes["+Barcodes.IndexOf(TSRow)+"].Barcode",, Cancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Cancel(Command, Cancel = False)
	
	If Not ClosingProcessing Then
		
		NotifyDescription = New NotifyDescription("CancelEnd", ThisObject);
		
		QuestionText = NStr("en = 'All products will not be written to the document.
		                    |Put them aside as not scanned.'; 
		                    |ru = 'Все товары не будут перенесены в документ.
		                    |Отложите их в сторону как неотсканированные.';
		                    |pl = 'Wszystkie produkty nie zostaną zapisane w dokumencie.
		                    |Odłóż je, jako niezeskanowane.';
		                    |es_ES = 'Todos los productos no se grabarán en el documento.
		                    |Colocarlos aparte como no escaneados.';
		                    |es_CO = 'Todos los productos no se grabarán en el documento.
		                    |Colocarlos aparte como no escaneados.';
		                    |tr = 'Tüm ürünler belgeye aktarılmaz. 
		                    |Taranmamış olarak ayırın.';
		                    |it = 'Tutti gli articoli non saranno trasferiti sul documento."
"Mettili da parte come non scansionati.';
		                    |de = 'Alle Produkte werden nicht in das Dokument geschrieben.
		                    |Legen Sie sie als nicht gescannt beiseite.'");
		
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.OKCancel);
		Return;
		
	EndIf;
	
	DeferredProducts = New Array;
	For Each RowOfBarcode In Barcodes Do
		DeferredProducts.Add(New Structure("Barcode, Quantity", RowOfBarcode.Barcode, RowOfBarcode.Quantity));
	EndDo;
	
	ClosingParameter = New Structure("DeferredProducts, RegisteredBarcodes, ReceivedNewBarcodes", DeferredProducts, New Array, New Array);
	ClosingProcessing = True;
	Close(ClosingParameter);
	
EndProcedure

&AtClient
Procedure CancelEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	DeferredProducts = New Array;
	For Each RowOfBarcode In Barcodes Do
		DeferredProducts.Add(New Structure("Barcode, Quantity", RowOfBarcode.Barcode, RowOfBarcode.Quantity));
	EndDo;
	
	ClosingParameter = New Structure("DeferredProducts, RegisteredBarcodes, ReceivedNewBarcodes", DeferredProducts, New Array, New Array);
	ClosingProcessing = True;
	Try
		Close(ClosingParameter);
	Except
	EndTry;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	If Not ClosingProcessing Then
		Cancel(Undefined, Cancel);
	EndIf;
	
EndProcedure

&AtClient
Procedure BarcodesBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure

#Region Private

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	//Products, Characteristic, Batch
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Barcodes.Registered");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("ReadOnly", True);
		
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("Products");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("Characteristic");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("Batch");
	FieldAppearance.Use = True;
	
	//State
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Barcodes.Registered");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Font", StyleFonts.FontDialogAndMenu);
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = 'New'; ru = 'Новая';pl = 'Nowy';es_ES = 'Nuevo';es_CO = 'Nuevo';tr = 'Yeni';it = 'Nuovo';de = 'Neu'"));
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("State");
	FieldAppearance.Use = True;
	
	//State
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Barcodes.Registered");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = 'Registered'; ru = 'Зарегистрирован';pl = 'Data rejestracji firmy';es_ES = 'Registrado';es_CO = 'Registrado';tr = 'Kayıtlı';it = 'Registrato';de = 'Anmeldedatum'"));
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("State");
	FieldAppearance.Use = True;
	
EndProcedure

#EndRegion